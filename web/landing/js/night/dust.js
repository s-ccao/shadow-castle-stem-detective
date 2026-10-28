import { addTicker, damp, finePointer, onScroll, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { addPainter, wakeLight } from "./light.js";
import { TAU, fit, heroCovers, lowPower, rng, skyLayer } from "./kit.js";
import { PAINT, palette, sampleShape } from "./shapes.js";

// Moon dust: one fixed WebGL layer behind the page. As a chapter reaches the middle
// of the screen, the dust gathers into its subject (the castle, a magnifier, the
// evidence web, a flask, the seven case doors, each upcoming game's motif) in the
// largest open space between the page's content, so it is seen rather than hidden.
// The pointer parts the dust like a lens, a click sends a shockwave, fast scrolling
// draws it into rain. Without usable hardware WebGL, the CSS sky stands alone.
const SHARE = 0.74; // motes that join a formation; the rest drift as ambient dust
const MORPH_MS = 1900;

const CASE_SHAPE = {
  "shadow-castle": "castle",
  "evidence-rush": "fingerprint",
  "prism-lab": "prism",
  "echo-corridor": "waves",
  "time-echo": "hourglass",
  "alchemy-shift": "flask",
  "rune-defense": "runes",
};

// [chapter selector, subject, fallback anchor x (share of the width)]
const CHAPTERS = [
  [".hub-hero", "field"],
  [".featured", "castle", 0.7],
  [".upcoming", "doors"],
  [".demo", "web", 0.72],
  [".open-desk", "magnifier", 0.7],
  ["main > .hero", "moon", 0.72],
  [".brief", "magnifier", 0.74],
  [".fieldwork", "web"],
  [".science", "flask", 0.26],
  [".rooms", "castle"],
  [".development", "gears", 0.72],
  [".case-hero", "case"],
  [".case-premise", "keyhole", 0.74],
  [".case-planned", "gears", 0.72],
  [".other-cases", "doors"],
  [".archive-head", "keyhole", 0.72],
  [".archive", "doors"],
  [".network", "web", 0.72],
  [".site-footer", "moon"],
];

// What the dust must not sit behind: the page's content and fixed chrome.
const CONTENT =
  "main img, main video, main canvas, main svg, main figure, main p, main h1, main h2, main h3, main dl, main ul, main ol, main table, main .case-card, main .action, main form, .case-hero__art, .site-nav, .case-dock, .site-footer > *";

const VS = `
precision highp float;
attribute vec3 a_from;
attribute vec3 a_to;
attribute vec3 a_cfrom;
attribute vec3 a_cto;
attribute vec4 a_rnd;
attribute float a_amb;
uniform vec2 u_res;
uniform vec2 u_anchor;
uniform vec2 u_center;
uniform float u_scale, u_unit, u_dpr, u_time, u_mix, u_vel, u_bright;
uniform vec3 u_mouse;
uniform vec3 u_shock;
varying vec3 v_col;
varying float v_a;
varying float v_streak;
const float PI = 3.14159265;
void main() {
  float m = clamp((u_mix - a_rnd.y * 0.35) / 0.65, 0.0, 1.0);
  m = m * m * (3.0 - 2.0 * m);
  vec3 p = mix(a_from, a_to, m);
  float bulge = sin(m * PI) * (a_rnd.z - 0.5) * 0.7;
  p.xy += vec2(-p.y, p.x) * bulge;
  float t = u_time * (0.22 + a_rnd.w * 0.3);
  p.xy += vec2(sin(t + a_rnd.x * 37.0), cos(t * 1.3 + a_rnd.y * 41.0)) * 0.011;
  vec2 px = a_amb > 0.5 ? u_center + p.xy * u_unit : u_anchor + p.xy * u_scale;
  px.y -= u_vel * (0.5 + (p.z + 0.5) * 2.2);
  vec2 d = px - u_mouse.xy;
  float dist = length(d);
  vec2 dir = d / (dist + 0.001);
  float lens = u_mouse.z * smoothstep(175.0, 12.0, dist);
  px += dir * lens * 36.0 + vec2(-dir.y, dir.x) * lens * 16.0;
  vec2 ds = px - u_shock.xy;
  float dd = length(ds);
  float band = step(0.0, u_shock.z) * exp(-pow((dd - u_shock.z * 780.0) / 48.0, 2.0)) * exp(-u_shock.z * 2.2);
  px += ds / (dd + 0.001) * band * 56.0;
  vec2 clip = px / u_res * 2.0 - 1.0;
  gl_Position = vec4(clip.x, -clip.y, 0.0, 1.0);
  float size = (1.1 + a_rnd.x * 2.4) * (1.0 + p.z * 0.9);
  float streak = min(abs(u_vel) * 0.85, 16.0);
  gl_PointSize = (size + streak) * u_dpr;
  v_streak = streak / (size + streak);
  float twinkle = 0.6 + 0.4 * sin(u_time * (0.8 + a_rnd.x * 1.7) + a_rnd.y * 40.0);
  v_col = mix(a_cfrom, a_cto, m);
  v_a = u_bright * twinkle * (0.5 + a_rnd.w * 0.5) + lens * 0.9 + band * 1.4;
}`;

const FS = `
precision mediump float;
varying vec3 v_col;
varying float v_a;
varying float v_streak;
void main() {
  vec2 c = gl_PointCoord - 0.5;
  c.x /= max(0.06, 1.0 - v_streak);
  float a = smoothstep(1.0, 0.0, length(c) * 2.0);
  a = a * a * v_a * (1.0 - v_streak * 0.55);
  gl_FragColor = vec4(v_col * a, a);
}`;

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) || "shader failed");
  return shader;
}

export function initDust() {
  const root = document.documentElement;
  const canvas = skyLayer("dust");
  const gl = canvas.getContext("webgl", { alpha: true, premultipliedAlpha: true, antialias: false, depth: false, stencil: false, powerPreference: "high-performance" });
  const info = gl && gl.getExtension("WEBGL_debug_renderer_info");
  const renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : "";
  if (!gl || /swiftshader|llvmpipe|software|basic render/i.test(renderer)) {
    canvas.remove(); // software rendering would cost more than the dust is worth
    return;
  }

  const N = lowPower ? 6000 : 14000;
  const C = palette();
  const r = rng(91);
  const rnd = new Float32Array(N * 4);
  for (let i = 0; i < N * 4; i += 1) rnd[i] = r();
  const ambient = new Uint8Array(N);
  const amb = new Float32Array(N);
  for (let i = 0; i < N; i += 1) amb[i] = ambient[i] = r() > SHARE ? 1 : 0;
  const shareCount = N - ambient.reduce((sum, v) => sum + v, 0);

  // Base layout: ambient dust spread over the screen (screen units: 1 = half the short
  // side); formation dust in a loose cloud (formation units) until a subject claims it.
  const field = { pos: new Float32Array(N * 3), col: new Float32Array(N * 3) };
  const dim = ["--color-moon", "--color-moon", "--color-moon-2", "--color-arcane", "--color-accent"].map((name) => tokenRgb(name).map((v) => v / 255));
  function layoutField() {
    const unit = Math.min(window.innerWidth, window.innerHeight) / 2;
    const halfX = (window.innerWidth / 2 / unit) * 1.08;
    const halfY = (window.innerHeight / 2 / unit) * 1.08;
    const fr = rng(17);
    for (let i = 0; i < N; i += 1) {
      const o = i * 3;
      if (ambient[i]) {
        field.pos[o] = (fr() * 2 - 1) * halfX;
        field.pos[o + 1] = (fr() * 2 - 1) * halfY;
      } else {
        const a = fr() * TAU;
        const d = Math.sqrt(fr()) * 1.25;
        field.pos[o] = Math.cos(a) * d * 1.3;
        field.pos[o + 1] = Math.sin(a) * d;
      }
      field.pos[o + 2] = fr() - 0.5;
      const c = dim[i % dim.length];
      const k = (ambient[i] ? 0.5 : 0.38) + fr() * 0.35;
      field.col[o] = c[0] * k;
      field.col[o + 1] = c[1] * k;
      field.col[o + 2] = c[2] * k;
    }
  }

  const formations = new Map();
  function formation(shape) {
    if (formations.has(shape)) return formations.get(shape);
    const pos = new Float32Array(field.pos);
    const col = new Float32Array(field.col);
    if (PAINT[shape]) {
      const sample = sampleShape(PAINT[shape], C, shareCount, rng(shape.length * 977 + 13));
      let k = 0;
      for (let i = 0; i < N && k < sample.n; i += 1) {
        if (ambient[i]) continue;
        pos.set(sample.pos.subarray(k * 3, k * 3 + 3), i * 3);
        col.set(sample.col.subarray(k * 3, k * 3 + 3), i * 3);
        k += 1;
      }
    }
    const result = { pos, col };
    formations.set(shape, result);
    return result;
  }

  // The largest empty square between the content, scored so a slightly smaller spot
  // near the middle beats a corner.
  function freeSpot() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const cols = 32;
    const rows = Math.max(8, Math.round((cols * h) / w));
    const cw = w / cols;
    const ch = h / rows;
    const blocked = new Uint8Array(cols * rows);
    for (const el of document.querySelectorAll(CONTENT)) {
      const box = el.getBoundingClientRect();
      if (!box.width || box.bottom < 0 || box.top > h || box.right < 0 || box.left > w) continue;
      const c0 = Math.max(0, Math.floor((box.left - 14) / cw));
      const c1 = Math.min(cols - 1, Math.floor((box.right + 14) / cw));
      const r0 = Math.max(0, Math.floor((box.top - 14) / ch));
      const r1 = Math.min(rows - 1, Math.floor((box.bottom + 14) / ch));
      for (let row = r0; row <= r1; row += 1) blocked.fill(1, row * cols + c0, row * cols + c1 + 1);
    }
    const run = new Uint16Array(cols * rows);
    let bestScore = 0;
    let spot = null;
    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < cols; col += 1) {
        const i = row * cols + col;
        if (blocked[i]) continue;
        run[i] = 1 + Math.min(row ? run[i - cols] : 0, col ? run[i - 1] : 0, row && col ? run[i - cols - 1] : 0);
        const side = run[i];
        const x = (col + 1 - side / 2) * cw;
        const y = (row + 1 - side / 2) * ch;
        const score = side * (1.15 - Math.hypot(x - w / 2, y - h / 2) / Math.hypot(w, h));
        if (score > bestScore) {
          bestScore = score;
          spot = { x, y, r: (side * Math.min(cw, ch)) / 2 };
        }
      }
    }
    return spot;
  }

  // ---------- GL ----------
  const from = new Float32Array(N * 3);
  const to = new Float32Array(N * 3);
  const cfrom = new Float32Array(N * 3);
  const cto = new Float32Array(N * 3);
  let program = null;
  let buffers = null;
  let loc = null;
  function setupGL() {
    program = gl.createProgram();
    gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, VS));
    gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, FS));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) || "link failed");
    gl.useProgram(program);
    loc = {};
    for (const name of ["u_res", "u_anchor", "u_center", "u_scale", "u_unit", "u_dpr", "u_time", "u_mix", "u_vel", "u_bright", "u_mouse", "u_shock"]) {
      loc[name] = gl.getUniformLocation(program, name);
    }
    buffers = {};
    const attach = (name, data, size, usage) => {
      const buffer = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
      gl.bufferData(gl.ARRAY_BUFFER, data, usage);
      const at = gl.getAttribLocation(program, name);
      gl.enableVertexAttribArray(at);
      gl.vertexAttribPointer(at, size, gl.FLOAT, false, 0, 0);
      buffers[name] = buffer;
    };
    attach("a_from", from, 3, gl.DYNAMIC_DRAW);
    attach("a_to", to, 3, gl.DYNAMIC_DRAW);
    attach("a_cfrom", cfrom, 3, gl.DYNAMIC_DRAW);
    attach("a_cto", cto, 3, gl.DYNAMIC_DRAW);
    attach("a_rnd", rnd, 4, gl.STATIC_DRAW);
    attach("a_amb", amb, 1, gl.STATIC_DRAW);
    gl.disable(gl.DEPTH_TEST);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE); // premultiplied, additive: light on the night
  }
  function upload() {
    for (const [name, data] of [["a_from", from], ["a_to", to], ["a_cfrom", cfrom], ["a_cto", cto]]) {
      gl.bindBuffer(gl.ARRAY_BUFFER, buffers[name]);
      gl.bufferSubData(gl.ARRAY_BUFFER, 0, data);
    }
  }

  // ---------- state ----------
  const short = () => Math.min(window.innerWidth, window.innerHeight);
  const state = {
    shape: null,
    morphAt: -1e9,
    ax: window.innerWidth / 2,
    ay: window.innerHeight / 2,
    tx: window.innerWidth / 2,
    ty: window.innerHeight / 2,
    sc: short() * 0.36,
    tsc: short() * 0.36,
    bright: 0.5,
    targetBright: 0.5,
    mx: -1e4,
    my: -1e4,
    hover: 0,
    hoverTarget: 0,
    shockX: 0,
    shockY: 0,
    shockAt: -1e9,
    vel: 0,
    lastY: window.scrollY,
  };
  let view = fit(canvas, 1.5);
  const mixAt = (now) => Math.min(1, Math.max(0, (now - state.morphAt) / MORPH_MS));

  function morphTo(shape, now, instant) {
    const target = formation(shape);
    if (state.shape === null && !instant) {
      // First arrival: the dust gathers out of a wide scatter.
      for (let i = 0; i < N * 3; i += 1) from[i] = field.pos[i] * (i % 3 === 2 ? 1 : 1.6);
      cfrom.set(field.col);
      state.morphAt = now;
    } else if (instant) {
      from.set(target.pos);
      cfrom.set(target.col);
      state.morphAt = now - MORPH_MS;
    } else {
      // Mid-flight: start the next journey from wherever each mote is now.
      const mix = mixAt(now);
      for (let i = 0; i < N; i += 1) {
        let m = Math.min(1, Math.max(0, (mix - rnd[i * 4 + 1] * 0.35) / 0.65));
        m = m * m * (3 - 2 * m);
        const o = i * 3;
        const x = from[o] + (to[o] - from[o]) * m;
        const y = from[o + 1] + (to[o + 1] - from[o + 1]) * m;
        const b = Math.sin(m * Math.PI) * (rnd[i * 4 + 2] - 0.5) * 0.7;
        from[o] = x - y * b;
        from[o + 1] = y + x * b;
        from[o + 2] += (to[o + 2] - from[o + 2]) * m;
        for (let c = 0; c < 3; c += 1) cfrom[o + c] += (cto[o + c] - cfrom[o + c]) * m;
      }
      state.morphAt = now;
    }
    to.set(target.pos);
    cto.set(target.col);
    state.shape = shape;
    canvas.dataset.shape = shape;
    upload();
  }

  // ---------- chapters ----------
  const slug = document.querySelector("main[data-case]")?.dataset.case;
  const chapters = CHAPTERS.flatMap(([selector, shape, ax = 0.5]) =>
    [...document.querySelectorAll(selector)].map((el) => ({
      el,
      shape: shape === "case" ? CASE_SHAPE[slug] || "keyhole" : shape,
      ax,
      art: el.querySelector(".case-hero__art"),
    })),
  );
  const covered = heroCovers();
  let active = null;
  let placedAt = 0;

  // Around the open space if there is one; else around a case emblem; else dimly
  // behind the content at the chapter's usual side.
  function place(chapter, instant) {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const spot = freeSpot();
    let open = true;
    if (spot && spot.r >= short() * 0.15) {
      state.tx = spot.x;
      state.ty = spot.y;
      state.tsc = Math.min(spot.r * 0.9, short() * 0.42);
    } else if (chapter.art) {
      const box = chapter.art.getBoundingClientRect();
      state.tx = box.left + box.width / 2;
      state.ty = box.top + box.height / 2;
      state.tsc = box.width * 0.95;
    } else {
      open = false;
      state.tx = w * (w >= 900 ? chapter.ax : 0.5);
      state.ty = h / 2;
      state.tsc = short() * (w >= 900 ? 0.36 : 0.42);
    }
    state.targetBright = chapter.shape === "field" ? 0.5 : open ? 0.95 : 0.42;
    canvas.dataset.place = `${Math.round(state.tx)},${Math.round(state.ty)},${Math.round(state.tsc)}`;
    if (instant) {
      state.ax = state.tx;
      state.ay = state.ty;
      state.sc = state.tsc;
    }
  }

  function pickChapter(now, instant) {
    const mid = window.innerHeight * 0.5;
    let best = null;
    for (const chapter of chapters) {
      const box = chapter.el.getBoundingClientRect();
      if (box.top <= mid && box.bottom >= mid) best = chapter;
    }
    if (!best) return;
    if (best === active) {
      if (now - placedAt > 300) {
        placedAt = now;
        place(best, instant);
      }
      return;
    }
    active = best;
    placedAt = now;
    place(best, instant);
    morphTo(best.shape, now, instant);
  }

  // ---------- frame ----------
  let stop = null;
  let cleared = false;
  function frame(now, dt = 16) {
    const moving = motionOn();
    if (covered()) {
      if (!cleared) {
        gl.clearColor(0, 0, 0, 0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        cleared = true;
      }
      return true;
    }
    cleared = false;
    if (active && now - placedAt > 1000) {
      placedAt = now; // reveals and late images move the content: look again
      place(active, !moving);
    }
    const y = window.scrollY;
    state.vel = moving ? damp(state.vel, Math.max(-40, Math.min(40, y - state.lastY)), 12, dt) : 0;
    state.lastY = y;
    state.ax = damp(state.ax, state.tx, 2.4, dt);
    state.ay = damp(state.ay, state.ty, 2.4, dt);
    state.sc = damp(state.sc, state.tsc, 2.4, dt);
    state.bright = damp(state.bright, state.targetBright, 3, dt);
    state.hover = damp(state.hover, moving ? state.hoverTarget : 0, 6, dt);
    const shockAge = (now - state.shockAt) / 1000;
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(program);
    gl.uniform2f(loc.u_res, view.w, view.h);
    gl.uniform2f(loc.u_anchor, state.ax, state.ay);
    gl.uniform2f(loc.u_center, view.w / 2, view.h / 2);
    gl.uniform1f(loc.u_scale, state.sc);
    gl.uniform1f(loc.u_unit, Math.min(view.w, view.h) / 2);
    gl.uniform1f(loc.u_dpr, view.dpr);
    gl.uniform1f(loc.u_time, moving ? now / 1000 : 0);
    gl.uniform1f(loc.u_mix, moving ? mixAt(now) : 1);
    gl.uniform1f(loc.u_vel, state.vel);
    gl.uniform1f(loc.u_bright, state.bright);
    gl.uniform3f(loc.u_mouse, state.mx, state.my, state.hover);
    gl.uniform3f(loc.u_shock, state.shockX, state.shockY, moving && shockAge < 2.5 ? shockAge : -1);
    gl.drawArrays(gl.POINTS, 0, N);
    return true;
  }
  // Under reduced motion the dust holds its shape and redraws only when asked.
  const still = () => {
    if (!motionOn()) frame(performance.now(), 1e4);
  };
  const run = () => {
    stop?.();
    stop = null;
    if (motionOn()) stop = addTicker(frame);
    else still();
  };

  try {
    setupGL();
  } catch (error) {
    canvas.remove();
    throw error;
  }
  layoutField();
  pickChapter(performance.now(), !motionOn());
  if (!active) morphTo("field", performance.now(), !motionOn());

  // The click's shock ring, drawn in the pointer's light so it shows over content too.
  const ring = tokenRgb("--color-moon");
  const rings = [];
  addPainter((ctx, now) => {
    for (let i = rings.length - 1; i >= 0; i -= 1) {
      const life = (now - rings[i].t) / 900;
      if (life >= 1) {
        rings.splice(i, 1);
        continue;
      }
      ctx.globalAlpha = (1 - life) ** 2 * 0.8;
      ctx.strokeStyle = `rgb(${ring.join(",")})`;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(rings[i].x, rings[i].y, 12 + (1 - (1 - life) ** 3) * 170, 0, TAU);
      ctx.stroke();
    }
    return rings.length > 0;
  });

  // ---------- input ----------
  window.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !finePointer.matches || !motionOn()) return;
      state.mx = event.clientX;
      state.my = event.clientY;
      state.hoverTarget = 1;
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => (state.hoverTarget = 0));
  document.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || !motionOn()) return;
    state.shockX = event.clientX;
    state.shockY = event.clientY;
    state.shockAt = performance.now();
    rings.push({ x: event.clientX, y: event.clientY, t: state.shockAt });
    wakeLight();
  });
  onScroll(() => {
    pickChapter(performance.now(), !motionOn());
    still();
  });
  window.addEventListener("resize", () => {
    view = fit(canvas, 1.5);
    layoutField();
    formations.clear();
    const shape = state.shape || "field";
    state.shape = null;
    active = null;
    pickChapter(performance.now(), true);
    if (!state.shape) morphTo(shape, performance.now(), true);
    still();
  });
  canvas.addEventListener("webglcontextlost", (event) => {
    event.preventDefault();
    stop?.();
    stop = null;
  });
  canvas.addEventListener("webglcontextrestored", () => {
    setupGL();
    upload();
    run();
  });
  document.addEventListener("sc:motionchange", run);
  run();
}
