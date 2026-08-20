const crypto = require("node:crypto");
const { promisify } = require("node:util");
const {
  BlobPreconditionFailedError,
  get: getBlob,
  put: putBlob,
} = require("@vercel/blob");

const scrypt = promisify(crypto.scrypt);
const ACCOUNT_SCHEMA = 1;
const SAVE_VERSION = 1;
const MAX_HISTORY = 8;
const MAX_BODY_BYTES = 512 * 1024;
const SESSION_SECONDS = 30 * 24 * 60 * 60;
const LOGIN_WINDOW_MS = 10 * 60 * 1000;
const LOGIN_ATTEMPT_LIMIT = 8;
const ACCOUNT_LOCK_SECONDS = 15 * 60;
const USERNAME_PATTERN = /^[a-z0-9][a-z0-9_-]{3,23}$/;

let storage = { get: getBlob, put: putBlob };
const loginAttempts = new Map();

function send(response, status, payload) {
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.status(status).json(payload);
}

function normalizeUsername(value) {
  return String(value || "").trim().toLowerCase();
}

function accountPath(username) {
  const id = crypto.createHash("sha256").update(username).digest("hex");
  return `cloud-saves/${id}.json`;
}

function loginRateKey(request, username) {
  const forwarded = String(request.headers["x-forwarded-for"] || "").split(",")[0].trim();
  const address = forwarded || String(request.socket?.remoteAddress || "unknown");
  return crypto.createHash("sha256").update(`${address}\0${username}`).digest("hex");
}

function consumeLoginAttempt(request, username) {
  const now = Date.now();
  const key = loginRateKey(request, username);
  const current = loginAttempts.get(key);
  if (!current || now - current.startedAt >= LOGIN_WINDOW_MS) {
    loginAttempts.set(key, { startedAt: now, count: 1 });
    return true;
  }
  current.count += 1;
  return current.count <= LOGIN_ATTEMPT_LIMIT;
}

function clearLoginAttempts(request, username) {
  loginAttempts.delete(loginRateKey(request, username));
}

function base64Url(value) {
  return Buffer.from(value).toString("base64url");
}

function sessionSecret() {
  const secret = process.env.CLOUD_SAVE_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error("CLOUD_SAVE_SECRET is missing or too short.");
  }
  return secret;
}

function signSession(username) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64Url(JSON.stringify({
    sub: accountPath(username),
    name: username,
    iat: now,
    exp: now + SESSION_SECONDS,
  }));
  const unsigned = `${header}.${payload}`;
  const signature = crypto
    .createHmac("sha256", sessionSecret())
    .update(unsigned)
    .digest("base64url");
  return `${unsigned}.${signature}`;
}

function verifySession(request) {
  const authorization = String(request.headers.authorization || "");
  if (!authorization.startsWith("Bearer ")) {
    return null;
  }
  const token = authorization.slice(7);
  const parts = token.split(".");
  if (parts.length !== 3) {
    return null;
  }
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = crypto
    .createHmac("sha256", sessionSecret())
    .update(unsigned)
    .digest();
  let actual;
  try {
    actual = Buffer.from(parts[2], "base64url");
  } catch {
    return null;
  }
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) {
    return null;
  }
  let payload;
  try {
    payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (
    typeof payload.name !== "string"
    || payload.sub !== accountPath(payload.name)
    || Number(payload.exp) <= Math.floor(Date.now() / 1000)
  ) {
    return null;
  }
  return payload;
}

async function passwordRecord(password) {
  const salt = crypto.randomBytes(16);
  const hash = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return { salt: salt.toString("base64"), hash: hash.toString("base64") };
}

async function passwordMatches(password, record) {
  if (!record || typeof record.salt !== "string" || typeof record.hash !== "string") {
    return false;
  }
  const expected = Buffer.from(record.hash, "base64");
  const actual = await scrypt(
    password,
    Buffer.from(record.salt, "base64"),
    expected.length,
    { N: 16384, r: 8, p: 1 },
  );
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

async function readAccount(path) {
  const result = await storage.get(path, { access: "private", useCache: false });
  if (!result) {
    return null;
  }
  const text = await new Response(result.stream).text();
  const account = JSON.parse(text);
  if (account.schema !== ACCOUNT_SCHEMA) {
    throw new Error("Unsupported cloud account schema.");
  }
  return { account, etag: result.blob.etag };
}

function validSave(save) {
  return save
    && typeof save === "object"
    && !Array.isArray(save)
    && Number(save.version) === SAVE_VERSION
    && save.checkpoint_valid === true
    && Number.isSafeInteger(Number(save.saved_at))
    && Number(save.saved_at) > 0;
}

function publicAccount(account, token) {
  return {
    token,
    username: account.username,
    cloud_save: account.save || null,
    history_count: Array.isArray(account.history) ? account.history.length : 0,
    revision: account.save_revision,
  };
}

async function register(body, response) {
  const username = normalizeUsername(body.username);
  const password = String(body.password || "");
  if (!USERNAME_PATTERN.test(username)) {
    send(response, 400, {
      error: "Investigator ID must be 4–24 letters, numbers, underscores, or hyphens.",
      code: "invalid_username",
    });
    return;
  }
  if (password.length < 10 || password.length > 128) {
    send(response, 400, {
      error: "Passphrase must contain 10–128 characters.",
      code: "invalid_password",
    });
    return;
  }

  const path = accountPath(username);
  if (await readAccount(path)) {
    send(response, 409, { error: "That Investigator ID is already registered.", code: "exists" });
    return;
  }
  const account = {
    schema: ACCOUNT_SCHEMA,
    username,
    password: await passwordRecord(password),
    created_at: Math.floor(Date.now() / 1000),
    updated_at: Math.floor(Date.now() / 1000),
    save_revision: crypto.randomUUID(),
    save: null,
    history: [],
  };
  try {
    await storage.put(path, JSON.stringify(account), {
      access: "private",
      addRandomSuffix: false,
      allowOverwrite: false,
      contentType: "application/json",
      cacheControlMaxAge: 60,
    });
  } catch (error) {
    if (error && /already exists|overwrite/i.test(String(error.message))) {
      send(response, 409, { error: "That Investigator ID is already registered.", code: "exists" });
      return;
    }
    throw error;
  }
  send(response, 201, publicAccount(account, signSession(username)));
}

async function updateLoginGuard(path, stored, failed, retries = 2) {
  const now = Math.floor(Date.now() / 1000);
  const previous = stored.account.login_guard || {};
  const windowStarted = Number(previous.window_started || 0);
  const sameWindow = now - windowStarted < ACCOUNT_LOCK_SECONDS;
  const failures = failed ? (sameWindow ? Number(previous.failures || 0) + 1 : 1) : 0;
  const account = {
    ...stored.account,
    login_guard: failed
      ? {
          window_started: sameWindow ? windowStarted : now,
          failures,
          blocked_until: failures >= LOGIN_ATTEMPT_LIMIT ? now + ACCOUNT_LOCK_SECONDS : 0,
        }
      : { window_started: 0, failures: 0, blocked_until: 0 },
  };
  try {
    const result = await storage.put(path, JSON.stringify(account), {
      access: "private",
      addRandomSuffix: false,
      allowOverwrite: true,
      ifMatch: stored.etag,
      contentType: "application/json",
      cacheControlMaxAge: 60,
    });
    return { account, etag: result.etag };
  } catch (error) {
    if (error instanceof BlobPreconditionFailedError) {
      if (retries <= 0) {
        return stored;
      }
      const latest = await readAccount(path);
      return latest ? updateLoginGuard(path, latest, failed, retries - 1) : stored;
    }
    throw error;
  }
}

async function login(request, body, response) {
  const username = normalizeUsername(body.username);
  const password = String(body.password || "");
  if (password.length > 128 || !consumeLoginAttempt(request, username)) {
    send(response, 429, {
      error: "Too many sign-in attempts. Try again in fifteen minutes.",
      code: "rate_limited",
    });
    return;
  }
  const stored = USERNAME_PATTERN.test(username)
    ? await readAccount(accountPath(username))
    : null;
  const blockedUntil = Number(stored?.account?.login_guard?.blocked_until || 0);
  if (blockedUntil > Math.floor(Date.now() / 1000)) {
    send(response, 429, {
      error: "Too many sign-in attempts. Try again in fifteen minutes.",
      code: "rate_limited",
    });
    return;
  }
  if (!stored || !(await passwordMatches(password, stored.account.password))) {
    if (stored) {
      await updateLoginGuard(accountPath(username), stored, true);
    }
    send(response, 401, { error: "Investigator ID or passphrase is incorrect.", code: "invalid_login" });
    return;
  }
  clearLoginAttempts(request, username);
  const refreshed = await updateLoginGuard(accountPath(username), stored, false);
  send(response, 200, publicAccount(refreshed.account, signSession(username)));
}

async function authenticated(request, response) {
  const session = verifySession(request);
  if (!session) {
    send(response, 401, { error: "Cloud session expired. Sign in again.", code: "session_expired" });
    return null;
  }
  const stored = await readAccount(session.sub);
  if (!stored) {
    send(response, 401, { error: "Cloud account no longer exists.", code: "account_missing" });
    return null;
  }
  return { session, ...stored };
}

async function pull(request, response) {
  const stored = await authenticated(request, response);
  if (!stored) {
    return;
  }
  send(response, 200, publicAccount(stored.account, null));
}

async function push(request, body, response) {
  const stored = await authenticated(request, response);
  if (!stored) {
    return;
  }
  const incoming = body.save;
  if (!validSave(incoming)) {
    send(response, 400, { error: "Cloud upload is not a valid checkpoint.", code: "invalid_save" });
    return;
  }
  if (Buffer.byteLength(JSON.stringify(incoming), "utf8") > MAX_BODY_BYTES) {
    send(response, 413, { error: "Save is too large for cloud storage.", code: "save_too_large" });
    return;
  }

  const current = stored.account.save;
  if (
    typeof body.base_revision !== "string"
    || body.base_revision !== stored.account.save_revision
  ) {
    send(response, 409, {
      error: "The cloud checkpoint changed on another device. Sync again.",
      code: "write_conflict",
      cloud_save: current || null,
      revision: stored.account.save_revision,
    });
    return;
  }
  if (JSON.stringify(current) === JSON.stringify(incoming)) {
    send(response, 200, publicAccount(stored.account, null));
    return;
  }

  const history = Array.isArray(stored.account.history) ? stored.account.history.slice() : [];
  if (validSave(current)) {
    history.unshift(current);
  }
  const account = {
    ...stored.account,
    updated_at: Math.floor(Date.now() / 1000),
    save_revision: crypto.randomUUID(),
    save: incoming,
    history: history.slice(0, MAX_HISTORY),
  };
  try {
    await storage.put(stored.session.sub, JSON.stringify(account), {
      access: "private",
      addRandomSuffix: false,
      allowOverwrite: true,
      ifMatch: stored.etag,
      contentType: "application/json",
      cacheControlMaxAge: 60,
    });
  } catch (error) {
    if (error instanceof BlobPreconditionFailedError) {
      send(response, 409, {
        error: "The cloud checkpoint changed on another device. Sync again.",
        code: "write_conflict",
      });
      return;
    }
    throw error;
  }
  send(response, 200, publicAccount(account, null));
}

async function handler(request, response) {
  if (request.method !== "POST") {
    response.setHeader("Allow", "POST");
    send(response, 405, { error: "Method not allowed." });
    return;
  }
  const body = request.body && typeof request.body === "object" ? request.body : {};
  try {
    switch (body.action) {
      case "register":
        await register(body, response);
        break;
      case "login":
        await login(request, body, response);
        break;
      case "pull":
        await pull(request, response);
        break;
      case "push":
        await push(request, body, response);
        break;
      default:
        send(response, 400, { error: "Unknown cloud-save action.", code: "invalid_action" });
    }
  } catch (error) {
    console.error("cloud-save request failed", error);
    send(response, 500, { error: "Cloud archive is temporarily unavailable.", code: "server_error" });
  }
}

handler._test = {
  accountPath,
  normalizeUsername,
  signSession,
  validSave,
  verifySession,
  setStorage(value) {
    storage = value;
  },
};

module.exports = handler;
