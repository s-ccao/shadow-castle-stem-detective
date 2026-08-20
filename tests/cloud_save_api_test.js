const handler = require("../web/game/api/cloud-save.js");

process.env.CLOUD_SAVE_SECRET = "test-secret-at-least-thirty-two-characters-long";

const records = new Map();
let revision = 0;
const storage = {
  async get(path) {
    const value = records.get(path);
    if (!value) {
      return null;
    }
    return {
      stream: new Response(value.text).body,
      blob: { etag: value.etag },
    };
  },
  async put(path, text, options) {
    const previous = records.get(path);
    if (!options.allowOverwrite && previous) {
      throw new Error("Blob already exists.");
    }
    if (options.ifMatch && previous?.etag !== options.ifMatch) {
      throw new Error("Unexpected test write conflict.");
    }
    const etag = `etag-${++revision}`;
    records.set(path, { text, etag });
    return { etag };
  },
};
handler._test.setStorage(storage);

function request(body, token = "", address = "203.0.113.4") {
  return {
    method: "POST",
    body,
    headers: {
      authorization: token ? `Bearer ${token}` : "",
      "x-forwarded-for": address,
    },
  };
}

async function call(input) {
  const response = {
    setHeader() {},
    status(value) {
      this.statusCode = value;
      return this;
    },
    json(value) {
      this.body = value;
    },
  };
  await handler(input, response);
  return response;
}

async function run() {
  const username = "integration_detective";
  const password = "strong-case-passphrase";
  let response = await call(request({
    action: "register",
    username,
    password,
  }));
  if (response.statusCode !== 201 || !response.body.token || !response.body.revision) {
    throw new Error(`Registration failed: ${JSON.stringify(response.body)}`);
  }
  const token = response.body.token;
  const firstRevision = response.body.revision;
  const storedText = [...records.values()][0].text;
  if (storedText.includes(password)) {
    throw new Error("Cloud account stored the plaintext passphrase.");
  }

  response = await call(request({ action: "login", username, password: "incorrect-value" }));
  if (response.statusCode !== 401) {
    throw new Error("Incorrect passphrase was accepted.");
  }

  response = await call(request({ action: "login", username, password }));
  if (response.statusCode !== 200) {
    throw new Error(`Login failed: ${JSON.stringify(response.body)}`);
  }

  const save = {
    version: 1,
    save_generation: 7,
    saved_at: 1787263000,
    checkpoint_valid: true,
    resume_room_id: "wake_room",
  };
  response = await call(request({
    action: "push",
    save,
    base_revision: firstRevision,
  }, token));
  if (response.statusCode !== 200 || response.body.revision === firstRevision) {
    throw new Error(`First push failed: ${JSON.stringify(response.body)}`);
  }
  const secondRevision = response.body.revision;

  response = await call(request({
    action: "push",
    save: { ...save, save_generation: 8 },
    base_revision: firstRevision,
  }, token));
  if (response.statusCode !== 409 || response.body.code !== "write_conflict") {
    throw new Error("Stale device revision overwrote newer cloud progress.");
  }

  response = await call(request({ action: "pull" }, token));
  if (
    response.statusCode !== 200
    || response.body.cloud_save.save_generation !== 7
    || response.body.revision !== secondRevision
  ) {
    throw new Error(`Pull returned the wrong checkpoint: ${JSON.stringify(response.body)}`);
  }

  for (let attempt = 0; attempt < 8; attempt += 1) {
    await call(request({ action: "login", username, password: "wrong-again" }));
  }
  response = await call(request({ action: "login", username, password }));
  if (response.statusCode !== 429 || response.body.code !== "rate_limited") {
    throw new Error("Repeated login attempts were not rate limited.");
  }

  console.log("cloud_save_api_test: PASS");
}

run().catch((error) => {
  console.error(`cloud_save_api_test: FAIL\n${error.stack}`);
  process.exit(1);
});
