import { addTicker, damp, finePointer, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { lang, t } from "../i18n.js";
import { addPainter, wakeLight } from "./light.js";
import { ACTIVE, TAU, fit, hashString, heroCovers, rgba, rng, skyLayer, sprite } from "./kit.js";

// The lantern. The wall behind the page hides a detective's evidence: UV
// fingerprints, footprints, chalk formulas, circuit and prism sketches, alchemical
// seals, red thread between pins. The pointer carries a brass lantern whose light
// develops it; the marks sink back into the dark a moment after the light moves on.
// Holding still lets the eyes adjust and the pool widen. A click fires a camera
// flash that develops a wide circle, and on bare wall drops a numbered marker.
const CELL = 380; // evidence is painted in document-space cells, on demand
const SCALE = 4; // the reveal mask is drawn at a quarter of the viewport
const STEP = 12;
const TRAIL_LIFE = 1700;
const REST = 175;
const ADJUSTED = 330;

// Decorative chalk, drawn into the wall rather than read as text.
const FORMULAS = ["NaHCO₃ + H⁺ → CO₂↑", "pH 8.2", "λ = 589 nm", "V = I·R", "n₁ sin θ₁ = n₂ sin θ₂", "21:02", "00:10", "Cu²⁺ + 2e⁻ → Cu", "Q = mcΔT", "R = 220 Ω", "E = hν", "ΔG < 0"];
const NOTES = {
  en: ["Dr. Lin?", "blackout 21:02", "the Guardian", "who cut the light?", "third room", "contradiction!", "chain of proof", "where is the key?", "not an accident"],
  zh: ["林博士？", "停电 21:02", "守护者", "谁关的灯？", "第三个房间", "矛盾！", "证据链", "钥匙在哪？", "不是意外"],
};
const STAMPS = { en: ["ASHFORD · CASE 01", "EVIDENCE", "CLASSIFIED", "UNSOLVED"], zh: ["阿什福德 · 01号案", "证物", "机密档案", "未结案"] };
const GLYPHS = ["☉", "☽", "☿", "♀", "♂", "♃", "♄", "△", "▽", "✶"];

const pickFrom = (r, list) => list[Math.floor(r() * list.length)];

// ---------- the marks, each drawn around the origin ----------
function fingerprint(g, r, color) {
  g.strokeStyle = color;
  g.lineWidth = 1.5;
  const rx = 24 + r() * 8;
  const ry = rx * 1.32;
  for (let k = 0; k < 14; k += 1) {
    const s = 0.1 + k * 0.068;
    const start = r() * TAU;
    const gap = 0.25 + r() * 0.5;
    const cut = start + 0.8 + r() * (TAU - 2);
    g.beginPath();
    g.ellipse(0, k * 0.9, rx * s, ry * s, 0, start, cut);
    g.stroke();
    g.beginPath();
    g.ellipse(0, k * 0.9, rx * s, ry * s, 0, cut + gap, start + TAU - 0.2);
    g.stroke();
  }
}

function footprints(g, r, color) {
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 1.4;
  for (let step = 0; step < 2; step += 1) {
    g.save();
    g.translate(step ? 26 : -26, step ? -46 : 46);
    g.beginPath();
    g.ellipse(0, -20, 15, 25, 0, 0, TAU);
    g.stroke();
    g.beginPath();
    g.ellipse(0, 30, 11, 14, 0, 0, TAU);
    g.stroke();
    for (let row = -36; row <= -4; row += 7) {
      for (let col = -8; col <= 8; col += 8) g.fillRect(col - 2, row, 4, 2);
    }
    g.restore();
  }
}

function formula(g, r, color) {
  g.fillStyle = color;
  g.font = `italic ${17 + Math.round(r() * 8)}px Fraunces, Georgia, serif`;
  g.textAlign = "center";
  g.textBaseline = "middle";
  const text = pickFrom(r, FORMULAS);
  g.fillText(text, 0, 0);
  if (r() < 0.55) {
    const width = g.measureText(text).width;
    g.strokeStyle = color;
    g.lineWidth = 1.2;
    g.beginPath();
    for (let x = -width / 2; x <= width / 2; x += 6) g.lineTo(x, 15 + Math.sin(x * 0.4) * 1.6);
    g.stroke();
  }
}

function circuit(g, r, color) {
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 1.5;
  g.lineJoin = "round";
  g.beginPath();
  g.moveTo(-60, -6);
  g.lineTo(-60, -36);
  g.lineTo(-24, -36);
  for (let i = 0; i < 6; i += 1) g.lineTo(-20 + i * 7, i % 2 ? -42 : -30);
  g.lineTo(24, -36);
  g.lineTo(60, -36);
  g.lineTo(60, -12);
  g.moveTo(60, 12);
  g.lineTo(60, 36);
  g.lineTo(-60, 36);
  g.lineTo(-60, 8);
  g.moveTo(-72, -6);
  g.lineTo(-48, -6);
  g.moveTo(-66, 8);
  g.lineTo(-54, 8);
  g.stroke();
  g.beginPath();
  g.arc(60, 0, 12, 0, TAU);
  g.moveTo(52, -8);
  g.lineTo(68, 8);
  g.moveTo(68, -8);
  g.lineTo(52, 8);
  g.stroke();
  g.font = "12px 'IBM Plex Mono', monospace";
  g.fillText("I →", -8, 52);
  g.fillText("0.7 A", 16, -54);
}

function prism(g, r, color, spectrum) {
  g.strokeStyle = color;
  g.lineWidth = 1.6;
  g.beginPath();
  g.moveTo(0, -42);
  g.lineTo(38, 26);
  g.lineTo(-38, 26);
  g.closePath();
  g.stroke();
  g.lineWidth = 1.3;
  g.beginPath();
  g.moveTo(-96, -4);
  g.lineTo(-20, -6);
  g.lineTo(18, -2);
  g.stroke();
  spectrum.forEach((hue, i) => {
    g.strokeStyle = hue;
    g.beginPath();
    g.moveTo(18, -2);
    g.lineTo(100, -22 + i * 8);
    g.stroke();
  });
}

function seal(g, r, color) {
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 1.3;
  for (const radius of [46, 34]) {
    g.beginPath();
    g.arc(0, 0, radius, 0, TAU);
    g.stroke();
  }
  g.font = "13px 'Apple Symbols', 'Segoe UI Symbol', serif";
  g.textAlign = "center";
  g.textBaseline = "middle";
  const offset = r() * TAU;
  for (let i = 0; i < 7; i += 1) {
    const a = offset + (i / 7) * TAU;
    g.fillText(GLYPHS[(i + Math.floor(r() * 9)) % GLYPHS.length], Math.cos(a) * 40, Math.sin(a) * 40);
  }
  g.beginPath();
  for (let i = 0; i < 3; i += 1) {
    const a = -Math.PI / 2 + (i / 3) * TAU;
    g.lineTo(Math.cos(a) * 30, Math.sin(a) * 30);
  }
  g.closePath();
  g.stroke();
  g.beginPath();
  g.arc(0, 2, 4, 0, TAU);
  g.fill();
}

function note(g, r, color, zh) {
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 1.4;
  for (let pass = 0; pass < 2; pass += 1) {
    g.beginPath();
    for (let a = 0; a <= TAU + 0.5; a += 0.2) {
      const j = 1 + (r() - 0.5) * 0.08;
      g.lineTo(Math.cos(a) * 30 * j - 30, Math.sin(a) * 20 * j);
    }
    g.stroke();
  }
  g.beginPath();
  g.moveTo(4, -8);
  g.quadraticCurveTo(26, -30, 52, -26);
  g.moveTo(4, -8);
  g.lineTo(14, -10);
  g.moveTo(4, -8);
  g.lineTo(8, -17);
  g.stroke();
  g.font = zh ? "17px 'Songti SC', 'Noto Serif SC', serif" : "italic 18px Fraunces, Georgia, serif";
  g.textBaseline = "middle";
  g.fillText(pickFrom(r, NOTES[zh ? "zh" : "en"]), 56, -28);
}

function thread(g, r, color, pin) {
  const pins = Array.from({ length: 3 }, () => [(r() - 0.5) * 200, (r() - 0.5) * 170]);
  g.strokeStyle = color;
  g.lineWidth = 1.6;
  for (let i = 0; i < pins.length - 1; i += 1) {
    const [x1, y1] = pins[i];
    const [x2, y2] = pins[i + 1];
    g.beginPath();
    g.moveTo(x1, y1);
    g.quadraticCurveTo((x1 + x2) / 2, Math.max(y1, y2) + 18, x2, y2);
    g.stroke();
  }
  for (const [x, y] of pins) {
    g.fillStyle = pin;
    g.beginPath();
    g.arc(x, y, 5.5, 0, TAU);
    g.fill();
  }
}

function luminol(g, r, color) {
  g.fillStyle = color;
  for (let i = 0; i < 34; i += 1) {
    const a = r() * TAU;
    const d = r() ** 1.8 * 52;
    g.beginPath();
    g.arc(Math.cos(a) * d * 1.3, Math.sin(a) * d, 0.8 + r() * (4.5 - d / 16), 0, TAU);
    g.fill();
  }
}

function stamp(g, r, color, zh) {
  g.strokeStyle = color;
  g.fillStyle = color;
  g.lineWidth = 2;
  g.strokeRect(-78, -20, 156, 40);
  g.lineWidth = 1;
  g.strokeRect(-72, -14, 144, 28);
  g.font = zh ? "600 15px 'PingFang SC', sans-serif" : "600 13px 'IBM Plex Mono', monospace";
  g.textAlign = "center";
  g.textBaseline = "middle";
  g.fillText(pickFrom(r, STAMPS[zh ? "zh" : "en"]), 0, 1);
}

export function initLantern() {
  if (!finePointer.matches) return;
  const root = document.documentElement;
  const wall = skyLayer("evidence");
  const ctx = wall.getContext("2d");
  const mask = document.createElement("canvas");
  const mctx = mask.getContext("2d");
  if (!ctx || !mctx) return;
  let view = fit(wall, 1);
  const sizeMask = () => {
    mask.width = Math.ceil(view.w / SCALE);
    mask.height = Math.ceil(view.h / SCALE);
  };
  sizeMask();

  const tone = (name, a) => rgba(tokenRgb(name), a);
  const colors = {
    uv: tone("--color-clue", 0.95),
    moon: tone("--color-moon", 0.85),
    chalk: tone("--color-ink", 0.9),
    ember: tone("--color-ember", 0.95),
    arcane: tone("--color-arcane", 0.95),
    red: tone("--game-evidence-rush", 0.95),
    brass: tone("--color-accent", 1),
  };
  const spectrum = [1, 2, 3, 4, 5, 6, 7].map((n) => tone(`--color-spectrum-${n}`, 1));
  const ember = tokenRgb("--color-ember");
  const sprites = {
    // The reveal stays fully open across most of the pool, then falls off softly.
    reveal: sprite([255, 255, 255], 64, [[0, 1], [0.5, 0.96], [0.78, 0.45], [1, 0]]),
    ember: sprite(ember, 256),
    hot: sprite(tokenRgb("--color-ember-hot"), 128),
  };
  const KINDS = [
    [fingerprint, "uv", 3],
    [footprints, "moon", 2],
    [formula, "chalk", 4],
    [circuit, "moon", 2],
    [prism, "chalk", 1.5],
    [seal, "arcane", 2],
    [note, "ember", 2.5],
    [thread, "red", 2],
    [luminol, "uv", 1.5],
    [stamp, "red", 1],
  ];
  const totalWeight = KINDS.reduce((sum, kind) => sum + kind[2], 0);
  const seed = hashString(location.pathname);

  // ---------- evidence cells in document space, painted on demand ----------
  // Painting a cell (with its baked glow) costs a few milliseconds: at most two new
  // cells a frame, and the visible ones are painted ahead of time when the page idles.
  const cells = new Map();
  let fresh = 0;
  const cacheSize = () => Math.max(24, Math.ceil(view.w / CELL) * (Math.ceil(view.h / CELL) + 3));
  function cell(ix, iy, force = false) {
    const key = `${ix},${iy}`;
    let canvas = cells.get(key);
    if (canvas) {
      cells.delete(key);
      cells.set(key, canvas);
      return canvas;
    }
    if (!force && fresh >= 2) return null;
    fresh += 1;
    canvas = document.createElement("canvas");
    canvas.width = canvas.height = CELL;
    const g = canvas.getContext("2d");
    const r = rng(seed ^ Math.imul(ix + 7, 73856093) ^ Math.imul(iy + 13, 19349663));
    const zh = lang() === "zh";
    const placed = [];
    const count = 3 + Math.floor(r() * 2.5);
    for (let k = 0; k < count; k += 1) {
      let x = 0;
      let y = 0;
      for (let tries = 0; tries < 12; tries += 1) {
        x = 70 + r() * (CELL - 140);
        y = 70 + r() * (CELL - 140);
        if (!placed.some(([px, py]) => Math.hypot(px - x, py - y) < 120)) break;
      }
      placed.push([x, y]);
      let roll = r() * totalWeight;
      const [draw, hue] = KINDS.find((kind) => (roll -= kind[2]) <= 0) || KINDS[0];
      g.save();
      g.translate(x, y);
      g.rotate((r() - 0.5) * 0.7);
      g.scale(1.2, 1.2);
      g.shadowColor = colors[hue];
      g.shadowBlur = 7;
      const extra = draw === thread ? colors.brass : draw === prism ? spectrum : zh;
      draw(g, r, colors[hue], extra);
      g.restore();
    }
    cells.set(key, canvas);
    if (cells.size > cacheSize()) cells.delete(cells.keys().next().value);
    return canvas;
  }

  const idle = window.requestIdleCallback || ((fn) => setTimeout(() => fn({ timeRemaining: () => 8 }), 80));
  let warming = false;
  function warm() {
    if (warming || !motionOn() || covered()) return;
    const sy = window.scrollY;
    const todo = [];
    for (let iy = Math.floor(sy / CELL) - 1; iy <= Math.floor((sy + view.h) / CELL) + 1; iy += 1) {
      for (let ix = 0; ix * CELL < view.w; ix += 1) if (iy >= 0 && !cells.has(`${ix},${iy}`)) todo.push([ix, iy]);
    }
    if (!todo.length) return;
    warming = true;
    const step = (deadline) => {
      while (todo.length && deadline.timeRemaining() > 4) cell(...todo.shift(), true);
      if (todo.length) idle(step);
      else warming = false;
    };
    idle(step);
  }

  // ---------- the lantern ----------
  const points = []; // lit patches in document space
  const flashes = [];
  const lamp = { x: -1e4, y: -1e4, on: false, r: REST, lastMove: 0, sx: 0, sy: 0, stamped: false };
  const covered = heroCovers();
  let stop = null;
  let lastFlash = 0;
  let markers = 0;

  function stampTo(x, docY, now) {
    if (!lamp.stamped) {
      points.push({ x, y: docY, t: now, r: lamp.r, life: TRAIL_LIFE, a: 0.9 });
      lamp.sx = x;
      lamp.sy = docY;
      lamp.stamped = true;
      return;
    }
    const dx = x - lamp.sx;
    const dy = docY - lamp.sy;
    const steps = Math.floor(Math.hypot(dx, dy) / STEP);
    for (let i = 1; i <= steps; i += 1) {
      points.push({ x: lamp.sx + (dx * i) / steps, y: lamp.sy + (dy * i) / steps, t: now, r: lamp.r, life: TRAIL_LIFE, a: 0.9 });
    }
    if (steps) {
      lamp.sx = x;
      lamp.sy = docY;
    }
    if (points.length > 420) points.splice(0, points.length - 420);
  }

  const flicker = (now) => 0.93 + 0.04 * Math.sin(now * 0.011) + 0.03 * Math.sin(now * 0.027 + 1.7);

  // The wall: evidence, cut to the light that has passed over it.
  function drawWall(now, dt = 16) {
    const sy = window.scrollY;
    for (let i = points.length - 1; i >= 0; i -= 1) if (now - points[i].t > points[i].life) points.splice(i, 1);
    const still = now - lamp.lastMove > 380;
    lamp.r = damp(lamp.r, still && lamp.on ? ADJUSTED : REST, still ? 0.9 : 7, dt);

    const { w, h } = view;
    mctx.setTransform(1, 0, 0, 1, 0, 0);
    mctx.clearRect(0, 0, mask.width, mask.height);
    for (const p of points) {
      const age = (now - p.t) / p.life;
      const rad = (p.r * (1 + age * 0.12)) / SCALE;
      mctx.globalAlpha = p.a * (1 - age) ** 1.5;
      mctx.drawImage(sprites.reveal, p.x / SCALE - rad, (p.y - sy) / SCALE - rad, rad * 2, rad * 2);
    }
    if (lamp.on) {
      const rad = lamp.r / SCALE;
      mctx.globalAlpha = 1;
      mctx.drawImage(sprites.reveal, lamp.x / SCALE - rad, lamp.y / SCALE - rad, rad * 2, rad * 2);
    }

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, w, h);
    if (!covered() && (points.length || lamp.on)) {
      const top = Math.floor(sy / CELL);
      const bottom = Math.floor((sy + h) / CELL);
      fresh = 0;
      // Two passes: the second, additive, blooms the freshly developed marks.
      for (const [mode, alpha] of [["source-over", 1], ["lighter", 0.55]]) {
        ctx.globalCompositeOperation = mode;
        ctx.globalAlpha = alpha;
        for (let iy = top; iy <= bottom; iy += 1) {
          for (let ix = 0; ix * CELL < w; ix += 1) {
            const art = cell(ix, iy);
            if (art) ctx.drawImage(art, ix * CELL, iy * CELL - sy);
          }
        }
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "destination-in";
      ctx.drawImage(mask, 0, 0, mask.width * SCALE, mask.height * SCALE);
      if (lamp.on) {
        ctx.globalCompositeOperation = "lighter";
        ctx.globalAlpha = 0.34 * flicker(now);
        ctx.drawImage(sprites.ember, lamp.x - lamp.r * 1.4, lamp.y - lamp.r * 1.4, lamp.r * 2.8, lamp.r * 2.8);
      }
    }
    const busy = lamp.on || points.length > 0 || Math.abs(lamp.r - REST) > 1;
    if (!busy) stop = null;
    return busy;
  }

  // In front of the page: the lantern's warmth and the camera flashes.
  addPainter((g, now) => {
    for (let i = flashes.length - 1; i >= 0; i -= 1) if (now - flashes[i].t > 900) flashes.splice(i, 1);
    if (lamp.on) {
      const f = flicker(now);
      g.globalAlpha = 0.1 * f;
      g.drawImage(sprites.ember, lamp.x - lamp.r, lamp.y - lamp.r, lamp.r * 2, lamp.r * 2);
      g.globalAlpha = 0.2 * f;
      g.drawImage(sprites.hot, lamp.x - 26, lamp.y - 26, 52, 52);
    }
    for (const flash of flashes) {
      const age = (now - flash.t) / 900;
      const burst = Math.max(0, 1 - age * 2.6);
      g.globalAlpha = burst * burst * 0.75;
      const big = 70 + age * 260;
      g.drawImage(sprites.hot, flash.x - big, flash.y - big, big * 2, big * 2);
      g.globalAlpha = (1 - age) ** 2 * 0.7;
      g.strokeStyle = rgba(ember, 1);
      g.lineWidth = 1.5;
      g.beginPath();
      g.arc(flash.x, flash.y, 24 + (1 - (1 - age) ** 3) * 150, 0, TAU);
      g.stroke();
    }
    return lamp.on || flashes.length > 0;
  });

  const kick = () => {
    if (!motionOn()) return;
    if (!stop) stop = addTicker(drawWall);
    wakeLight();
  };

  function dropMarker(event, docY) {
    markers += 1;
    const marker = document.createElement("div");
    marker.className = "evidence-marker";
    marker.setAttribute("aria-hidden", "true");
    const number = document.createElement("b");
    number.textContent = String(markers).padStart(2, "0");
    const label = document.createElement("span");
    label.textContent = t("evidence.marker", "EVIDENCE");
    marker.append(number, document.createElement("i"), label);
    marker.style.left = `${event.clientX + window.scrollX}px`;
    marker.style.top = `${docY}px`;
    marker.addEventListener("animationend", () => marker.remove());
    document.body.append(marker);
    const live = document.querySelectorAll(".evidence-marker");
    if (live.length > 6) live[0].remove();
  }

  window.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !motionOn()) return;
      const now = performance.now();
      lamp.x = event.clientX;
      lamp.y = event.clientY;
      lamp.on = true;
      lamp.lastMove = now;
      stampTo(lamp.x, lamp.y + window.scrollY, now);
      kick();
    },
    { passive: true },
  );
  let warmTimer = 0;
  const warmSoon = () => {
    clearTimeout(warmTimer);
    warmTimer = setTimeout(warm, 220);
  };
  window.addEventListener(
    "scroll",
    () => {
      warmSoon();
      if (!lamp.on) return;
      stampTo(lamp.x, lamp.y + window.scrollY, performance.now());
      kick();
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => {
    lamp.on = false;
    lamp.stamped = false;
  });
  document.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || event.pointerType !== "mouse" || !motionOn()) return;
    const now = performance.now();
    const docY = event.clientY + window.scrollY;
    points.push({ x: event.clientX, y: docY, t: now, r: 320, life: 2800, a: 1 });
    if (now - lastFlash > 340) {
      lastFlash = now; // never more than three flashes a second
      flashes.push({ x: event.clientX, y: event.clientY, t: now });
    }
    kick();
    if (!event.target.closest?.(`${ACTIVE}, dialog`)) dropMarker(event, docY);
  });
  window.addEventListener("resize", () => {
    view = fit(wall, 1);
    sizeMask();
    kick();
    warmSoon();
  });
  document.addEventListener("sc:langchange", () => {
    cells.clear();
    warmSoon();
  });
  warmSoon();
  document.addEventListener("sc:motionchange", () => {
    if (motionOn()) return;
    lamp.on = false;
    points.length = 0;
    flashes.length = 0;
  });
}
