import { addTicker, damp, onScroll, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { TAU, heroCovers, lowPower, rgba, sprite } from "./kit.js";

// One castle per case, standing on the hills at the foot of every page. Each is
// drawn once, as a moonlit silhouette, and its windows burn in the case's accent:
// Shadow Castle, the playable case, is lit; the others glow faintly until they come
// into focus. The skyline turns to the case being read (its page, or the card under
// the pointer on the hub) and drifts with the scroll elsewhere. Lightning (runes.js)
// strikes the spires; a struck castle's windows flare.
export const CASES = ["shadow-castle", "evidence-rush", "prism-lab", "echo-corridor", "time-echo", "alchemy-shift", "rune-defense"];
const PLAYABLE = new Set(["shadow-castle"]);

// Each design draws in units of the castle's height, x from its left edge, y up from
// the ground. `beacon` is where lightning strikes.
const DESIGNS = {
  "shadow-castle": {
    width: 1.5,
    draw(d) {
      d.block(0.1, 1.3, 0.3);
      d.crenels(0.1, 1.3, 0.3, 13);
      d.block(0.06, 0.22, 0.62);
      d.cone(0.17, 0.3, 0.62, 0.3);
      d.block(1.22, 0.2, 0.54);
      d.cone(1.32, 0.28, 0.54, 0.27);
      d.block(0.5, 0.5, 0.7);
      d.crenels(0.5, 0.5, 0.7, 6);
      d.block(0.68, 0.14, 0.94);
      d.cone(0.75, 0.2, 0.94, 0.34);
      d.block(0.47, 0.09, 0.82);
      d.cone(0.515, 0.13, 0.82, 0.14);
      d.block(0.94, 0.09, 0.82);
      d.cone(0.985, 0.13, 0.82, 0.14);
      d.flag(1.32, 0.81);
      d.win(0.17, 0.48, 0.05, 0.08);
      d.win(0.17, 0.32, 0.05, 0.07);
      d.win(1.32, 0.42, 0.05, 0.08);
      d.win(0.6, 0.5, 0.05, 0.09);
      d.win(0.9, 0.5, 0.05, 0.09);
      d.win(0.75, 0.82, 0.04, 0.07);
      d.win(0.32, 0.17, 0.04, 0.06);
      d.win(1.08, 0.17, 0.04, 0.06);
      d.gate(0.75, 0.13, 0.2);
      d.round(0.75, 0.56, 0.06, "rose");
      d.beacon(0.75, 1.28);
    },
  },
  "evidence-rush": {
    width: 1.3,
    draw(d) {
      d.block(0.05, 0.15, 0.5);
      d.crenels(0.05, 0.15, 0.5, 3);
      d.block(1.1, 0.15, 0.5);
      d.crenels(1.1, 0.15, 0.5, 3);
      d.block(0.18, 0.94, 0.42);
      d.cone(0.65, 1.0, 0.42, 0.13);
      d.block(0.56, 0.18, 0.86);
      d.cone(0.65, 0.24, 0.86, 0.2);
      for (let i = 0; i < 6; i += 1) d.win(0.26 + i * 0.156 + (i > 2 ? 0.0 : 0), 0.2, 0.04, 0.14);
      d.win(0.12, 0.3, 0.04, 0.07);
      d.win(1.17, 0.3, 0.04, 0.07);
      d.round(0.65, 0.72, 0.065, "clock");
      d.beacon(0.65, 1.06);
    },
  },
  "prism-lab": {
    width: 1.25,
    draw(d) {
      d.block(0.12, 1.0, 0.22);
      const spires = [[0.24, 0.2, 0.58], [0.42, 0.24, 0.84], [0.62, 0.28, 1.06], [0.83, 0.22, 0.74], [1.02, 0.16, 0.48]];
      for (const [cx, w, h] of spires) d.cone(cx, w, 0.2, h - 0.2);
      for (const [cx, , h] of spires) d.facet(cx, 0.24, h - 0.08);
      d.win(0.62, 0.12, 0.05, 0.08);
      d.win(0.35, 0.1, 0.04, 0.06);
      d.win(0.9, 0.1, 0.04, 0.06);
      d.round(0.62, 1.06, 0.02, "prism");
      d.beacon(0.62, 1.08);
    },
  },
  "echo-corridor": {
    width: 1.6,
    draw(d) {
      d.block(0.04, 0.14, 0.4);
      d.crenels(0.04, 0.14, 0.4, 3);
      d.block(0.12, 1.16, 0.27);
      d.crenels(0.12, 1.16, 0.27, 12);
      for (let i = 0; i < 7; i += 1) d.gate(0.24 + i * 0.145, 0.08, 0.16, 0.04);
      d.block(1.24, 0.26, 0.62);
      d.dome(1.37, 0.3, 0.62, 0.15);
      d.win(1.37, 0.45, 0.05, 0.09);
      d.win(1.37, 0.3, 0.04, 0.07);
      d.round(1.37, 0.79, 0.02, "echo");
      d.beacon(1.37, 0.8);
    },
  },
  "time-echo": {
    width: 1.25,
    draw(d) {
      d.block(0.08, 1.08, 0.3);
      d.crenels(0.08, 1.08, 0.3, 11);
      d.block(0.17, 0.13, 0.5);
      d.cone(0.235, 0.18, 0.5, 0.18);
      d.block(0.95, 0.13, 0.5);
      d.cone(1.015, 0.18, 0.5, 0.18);
      d.block(0.5, 0.25, 0.9);
      d.poly([[0.5, 0.9], [0.75, 0.9], [0.66, 0.99], [0.75, 1.08], [0.5, 1.08], [0.59, 0.99]]);
      d.cone(0.625, 0.08, 1.08, 0.14);
      d.round(0.625, 0.74, 0.085, "clock");
      d.win(0.625, 0.48, 0.05, 0.09);
      d.win(0.235, 0.36, 0.04, 0.07);
      d.win(1.015, 0.36, 0.04, 0.07);
      d.win(0.38, 0.14, 0.04, 0.06);
      d.win(0.86, 0.14, 0.04, 0.06);
      d.beacon(0.625, 1.22);
    },
  },
  "alchemy-shift": {
    width: 1.35,
    draw(d) {
      d.block(0.08, 1.16, 0.24);
      d.crenels(0.08, 1.16, 0.24, 11);
      d.block(0.36, 0.34, 0.64);
      d.onion(0.53, 0.4, 0.64, 0.28);
      d.cone(0.53, 0.03, 0.9, 0.12);
      d.block(0.92, 0.14, 0.3);
      d.circle(0.99, 0.42, 0.15);
      d.block(0.96, 0.06, 0.66);
      d.win(0.45, 0.42, 0.05, 0.09);
      d.win(0.61, 0.42, 0.05, 0.09);
      d.win(0.53, 0.22, 0.05, 0.08);
      d.win(0.2, 0.12, 0.04, 0.06);
      d.round(0.99, 0.42, 0.08, "potion");
      d.smoke(0.99, 0.67);
      d.beacon(0.53, 1.02);
    },
  },
  "rune-defense": {
    width: 1.4,
    draw(d) {
      d.poly([[0.02, 0], [0.12, 0.36], [1.28, 0.36], [1.38, 0]]);
      d.block(0.1, 0.22, 0.56);
      d.crenels(0.1, 0.22, 0.56, 4);
      d.block(1.08, 0.22, 0.56);
      d.crenels(1.08, 0.22, 0.56, 4);
      d.block(0.54, 0.32, 0.52);
      d.crenels(0.54, 0.32, 0.52, 5);
      d.flag(0.21, 0.6);
      d.flag(1.19, 0.6);
      d.win(0.21, 0.4, 0.04, 0.07);
      d.win(1.19, 0.4, 0.04, 0.07);
      d.round(0.7, 0.3, 0.085, "rune");
      d.beacon(0.7, 0.62);
    },
  },
  generic: {
    width: 1.1,
    draw(d) {
      d.block(0.1, 0.9, 0.3);
      d.crenels(0.1, 0.9, 0.3, 9);
      d.block(0.4, 0.3, 0.66);
      d.cone(0.55, 0.36, 0.66, 0.24);
      d.win(0.55, 0.42, 0.05, 0.09);
      d.beacon(0.55, 0.92);
    },
  },
};

function buildCastle(slug, H, tones) {
  const design = DESIGNS[slug] || DESIGNS.generic;
  const pad = Math.ceil(H * 0.06);
  const top = Math.ceil(H * 1.32);
  const canvas = document.createElement("canvas");
  canvas.width = Math.ceil(design.width * H) + pad * 2;
  canvas.height = top + 2;
  const g = canvas.getContext("2d");
  const X = (x) => pad + x * H;
  const Y = (y) => top - y * H;
  const body = new Path2D();
  const parts = { windows: [], rounds: [], beacon: null, smoke: null };
  const d = {
    block(x, w, h, y0 = 0) {
      body.rect(X(x), Y(y0 + h), w * H, h * H + 1);
    },
    poly(points) {
      body.moveTo(X(points[0][0]), Y(points[0][1]));
      for (const [px, py] of points.slice(1)) body.lineTo(X(px), Y(py));
      body.closePath();
    },
    cone(cx, w, y, h) {
      d.poly([[cx - w / 2, y - 0.004], [cx, y + h], [cx + w / 2, y - 0.004]]);
    },
    dome(cx, w, y, h) {
      body.moveTo(X(cx - w / 2), Y(y - 0.004));
      body.ellipse(X(cx), Y(y), (w * H) / 2, h * H, 0, Math.PI, TAU);
      body.closePath();
    },
    onion(cx, w, y, h) {
      const a = w / 2;
      body.moveTo(X(cx - a * 0.62), Y(y - 0.004));
      body.bezierCurveTo(X(cx - a * 1.2), Y(y + h * 0.26), X(cx - a * 0.9), Y(y + h * 0.64), X(cx), Y(y + h));
      body.bezierCurveTo(X(cx + a * 0.9), Y(y + h * 0.64), X(cx + a * 1.2), Y(y + h * 0.26), X(cx + a * 0.62), Y(y - 0.004));
      body.closePath();
    },
    circle(cx, cy, r) {
      body.moveTo(X(cx + r), Y(cy));
      body.arc(X(cx), Y(cy), r * H, 0, TAU);
    },
    crenels(x, w, y, n) {
      const step = w / n;
      for (let i = 0; i < n; i += 1) if (i % 2 === 0) d.block(x + i * step, step, 0.045, y - 0.002);
    },
    flag(x, y) {
      d.block(x - 0.005, 0.01, 0.14, y);
      d.poly([[x, y + 0.14], [x + 0.1, y + 0.115], [x, y + 0.09]]);
    },
    win(cx, cy, w, h) {
      parts.windows.push({ x: X(cx - w / 2), y: Y(cy + h / 2), w: w * H, h: h * H, phase: Math.random() * TAU, rate: 0.6 + Math.random() * 1.6 });
    },
    gate(cx, w, h, y0 = 0) {
      parts.windows.push({ x: X(cx - w / 2), y: Y(y0 + h), w: w * H, h: h * H, gate: true, phase: Math.random() * TAU, rate: 0.4 });
    },
    facet(cx, y0, y1) {
      parts.windows.push({ x: X(cx) - 0.8, y: Y(y1), w: 1.6, h: (y1 - y0) * H, facet: true, phase: Math.random() * TAU, rate: 0.9 });
    },
    round(cx, cy, r, kind) {
      parts.rounds.push({ x: X(cx), y: Y(cy), r: r * H, kind });
    },
    beacon(cx, cy) {
      parts.beacon = { x: X(cx), y: Y(cy) };
    },
    smoke(cx, cy) {
      parts.smoke = { x: X(cx), y: Y(cy) };
    },
  };
  design.draw(d);
  // The moon is up and to the left: a sliver of rim light shows on those edges.
  g.fillStyle = tones.rim;
  g.translate(-Math.max(1, H / 160), -Math.max(1, H / 200));
  g.fill(body);
  g.setTransform(1, 0, 0, 1, 0, 0);
  g.fillStyle = tones.body;
  g.fill(body);
  // Window recesses, lit at draw time.
  g.fillStyle = tones.recess;
  for (const w of parts.windows) {
    if (w.facet) continue;
    g.beginPath();
    g.roundRect(w.x, w.y, w.w, w.h, [w.w / 2, w.w / 2, 0, 0]);
    g.fill();
  }
  return { slug, canvas, pad, top, width: canvas.width, ...parts };
}

// Viewport points lightning can strike, for runes.js.
let spires = [];
export function castleSpires() {
  return spires;
}

export function initCastles() {
  const canvas = document.createElement("canvas");
  canvas.className = "night-layer night-layer--castles";
  canvas.setAttribute("aria-hidden", "true");
  document.body.append(canvas);
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const accent = Object.fromEntries(CASES.map((slug) => [slug, tokenRgb(`--game-${slug}`)]));
  const tones = {
    body: rgba(tokenRgb("--color-keep"), 1),
    far: rgba(tokenRgb("--color-keep-far"), 1),
    rim: rgba(tokenRgb("--color-keep-edge"), 0.9),
    recess: rgba(tokenRgb("--color-night"), 1),
  };
  const hill = tokenRgb("--color-hill");
  const near = tokenRgb("--color-near");
  const moon = tokenRgb("--color-moon");
  const spectrum = [1, 2, 3, 4, 5, 6, 7].map((n) => rgba(tokenRgb(`--color-spectrum-${n}`), 1));
  const glow = Object.fromEntries(CASES.map((slug) => [slug, sprite(accent[slug], 64)]));
  const smoke = sprite(accent["alchemy-shift"], 32);
  const covered = heroCovers();
  const pageCase = document.querySelector("main[data-case]")?.dataset.case || null;

  let view = { w: 0, h: 0, dpr: 1, band: 0 };
  let castles = [];
  const state = { offset: 0, target: 0, hover: null, flare: new Map(), lastScroll: 0 };

  function layout() {
    const dpr = Math.min(window.devicePixelRatio || 1, lowPower ? 1 : 1.5);
    const w = window.innerWidth;
    const h = window.innerHeight;
    const narrow = w < 700;
    const H = Math.round(Math.max(narrow ? 84 : 120, Math.min(narrow ? 132 : 250, h * (narrow ? 0.16 : 0.24))));
    const band = Math.round(H * 1.5);
    view = { w, h, dpr, band, H };
    canvas.style.top = "auto";
    canvas.style.bottom = "0";
    canvas.style.height = `${band}px`;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(band * dpr);
    // Near and far castles alternate, so the skyline has depth.
    let x = H * 0.35;
    castles = CASES.map((slug, i) => {
      const far = i % 2 === 1;
      const scale = far ? 0.74 : 1;
      const built = buildCastle(slug, Math.round(H * scale), { ...tones, body: far ? tones.far : tones.body });
      const item = { ...built, scale, far, x, center: x + built.width / 2 };
      x += built.width + H * (far ? 0.12 : 0.2);
      return item;
    });
    state.target = targetOffset();
    if (!motionOn() || !state.laidOut) state.offset = state.target;
    state.laidOut = true;
  }

  function centerOn(slug) {
    const castle = castles.find((c) => c.slug === slug);
    return castle ? view.w / 2 - castle.center : null;
  }

  function targetOffset() {
    if (!castles.length) return 0;
    // The strip may slide far enough to bring either end's castle to the middle.
    const first = view.w / 2 - castles[0].center;
    const last = view.w / 2 - castles[castles.length - 1].center;
    const clampOffset = (o) => Math.min(first, Math.max(last, o));
    const focus = state.hover || pageCase;
    if (focus) {
      const centered = centerOn(focus);
      if (centered !== null) return clampOffset(centered);
    }
    const max = document.documentElement.scrollHeight - view.h;
    const progress = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    return first + (last - first) * progress;
  }

  function draw(now) {
    const { w, band, dpr, H } = view;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, w, band);
    spires = [];
    if (covered()) return;
    const t = now / 1000;
    const top = window.innerHeight - band; // the band's top, in viewport coordinates
    const ground = band - H * 0.08;

    // Far hills, catching the moon on their crests.
    ctx.fillStyle = rgba(hill, 0.85);
    ctx.beginPath();
    ctx.moveTo(0, band);
    for (let x = 0; x <= w + 40; x += 40) {
      const wx = x - state.offset * 0.5;
      ctx.lineTo(x, ground - H * (0.18 + 0.08 * Math.sin(wx * 0.004) + 0.05 * Math.sin(wx * 0.011 + 1.3)));
    }
    ctx.lineTo(w, band);
    ctx.fill();

    for (const c of castles) {
      const x = c.x + state.offset;
      if (x > w || x + c.width < 0) continue;
      const y = ground - c.top + (c.far ? -H * 0.05 : 0);
      const center = x + c.width / 2;
      const focus = Math.exp(-(((center - w / 2) / (w * 0.32)) ** 2));
      const flare = Math.min(1, Math.max(0, 1 - (now - (state.flare.get(c.slug) || -1e9)) / 900));
      const lit = PLAYABLE.has(c.slug) ? 0.9 : 0.22 + 0.5 * focus;
      const hue = accent[c.slug];

      // A halo of the case's light behind the castle in focus.
      if (focus > 0.05 || flare > 0) {
        ctx.globalCompositeOperation = "lighter";
        ctx.globalAlpha = 0.14 * focus + 0.35 * flare;
        const r = c.width * 0.75;
        ctx.drawImage(glow[c.slug], center - r, y + c.top * 0.35 - r * 0.7, r * 2, r * 1.4);
        ctx.globalCompositeOperation = "source-over";
      }
      ctx.globalAlpha = c.far ? 0.92 : 1;
      ctx.drawImage(c.canvas, x, y);
      ctx.globalAlpha = 1;

      // Windows, each with its own slow flicker.
      ctx.globalCompositeOperation = "lighter";
      for (const win of c.windows) {
        const flicker = 0.82 + 0.18 * Math.sin(t * win.rate + win.phase);
        const a = Math.min(1, (lit + flare * 0.9) * flicker * (win.gate ? 0.55 : 1));
        ctx.globalAlpha = a;
        ctx.fillStyle = rgba(hue, 1);
        if (win.facet) {
          ctx.fillRect(x + win.x, y + win.y, win.w, win.h);
          continue;
        }
        ctx.beginPath();
        ctx.roundRect(x + win.x, y + win.y, win.w, win.h, [win.w / 2, win.w / 2, 0, 0]);
        ctx.fill();
        ctx.globalAlpha = a * 0.5;
        const gr = Math.max(win.w, win.h) * 2.2;
        ctx.drawImage(glow[c.slug], x + win.x + win.w / 2 - gr, y + win.y + win.h / 2 - gr, gr * 2, gr * 2);
      }
      for (const rd of c.rounds) {
        const cx = x + rd.x;
        const cy = y + rd.y;
        const a = Math.min(1, lit + flare);
        ctx.globalAlpha = a * 0.55;
        ctx.drawImage(glow[c.slug], cx - rd.r * 3, cy - rd.r * 3, rd.r * 6, rd.r * 6);
        ctx.globalAlpha = a;
        ctx.strokeStyle = rgba(hue, 1);
        ctx.lineWidth = Math.max(1, rd.r * 0.16);
        if (rd.kind === "clock" || rd.kind === "rose" || rd.kind === "rune" || rd.kind === "potion") {
          ctx.beginPath();
          ctx.arc(cx, cy, rd.r, 0, TAU);
          ctx.stroke();
        }
        if (rd.kind === "clock") {
          const turn = motionOn() ? t * 0.35 : 1.1;
          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.lineTo(cx + Math.cos(turn) * rd.r * 0.75, cy + Math.sin(turn) * rd.r * 0.75);
          ctx.moveTo(cx, cy);
          ctx.lineTo(cx + Math.cos(turn * 12) * rd.r * 0.5, cy + Math.sin(turn * 12) * rd.r * 0.5);
          ctx.stroke();
        } else if (rd.kind === "rose") {
          for (let k = 0; k < 8; k += 1) {
            const a2 = (k / 8) * TAU;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(a2) * rd.r, cy + Math.sin(a2) * rd.r);
            ctx.stroke();
          }
        } else if (rd.kind === "rune") {
          ctx.font = `${Math.round(rd.r * 1.3)}px 'Apple Symbols', 'Segoe UI Historic', 'Noto Sans Runic', serif`;
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.fillStyle = rgba(hue, 1);
          ctx.fillText("ᛟ", cx, cy + rd.r * 0.05);
        } else if (rd.kind === "potion") {
          ctx.fillStyle = rgba(hue, 0.55);
          ctx.beginPath();
          ctx.arc(cx, cy, rd.r * 0.8, 0.15, Math.PI - 0.15);
          ctx.fill();
        } else if (rd.kind === "prism") {
          // A prism catches the moon and throws a little spectrum.
          for (let k = 0; k < spectrum.length; k += 1) {
            ctx.strokeStyle = spectrum[k];
            ctx.globalAlpha = a * (0.35 + 0.25 * Math.sin(t * 1.4 + k));
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + H * 0.16, cy - H * 0.05 + k * H * 0.018);
            ctx.stroke();
          }
        } else if (rd.kind === "echo" && motionOn()) {
          for (let k = 0; k < 3; k += 1) {
            const p = (t * 0.45 + k / 3) % 1;
            ctx.globalAlpha = a * (1 - p) * 0.8;
            ctx.beginPath();
            ctx.arc(cx, cy, H * 0.05 + p * H * 0.3, Math.PI * 1.15, Math.PI * 1.85);
            ctx.stroke();
          }
        }
      }
      if (c.smoke && motionOn()) {
        for (let k = 0; k < 6; k += 1) {
          const p = (t * 0.18 + k / 6) % 1;
          const s = H * (0.04 + p * 0.12);
          ctx.globalAlpha = (1 - p) * 0.35 * (0.4 + 0.6 * focus);
          ctx.drawImage(smoke, x + c.smoke.x - s + Math.sin(t + k * 2) * H * 0.04 * p, y + c.smoke.y - p * H * 0.5 - s, s * 2, s * 2);
        }
      }
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 1;
      if (c.beacon) spires.push({ slug: c.slug, x: x + c.beacon.x, y: top + y + c.beacon.y });
    }

    // The ground in front hides the castles' feet; a thin moonlit line along the top.
    ctx.fillStyle = rgba(near, 1);
    ctx.beginPath();
    ctx.moveTo(0, band);
    for (let x = 0; x <= w + 30; x += 30) {
      const wx = x - state.offset;
      ctx.lineTo(x, ground + H * (0.02 + 0.025 * Math.sin(wx * 0.009 + 0.6)));
    }
    ctx.lineTo(w, band);
    ctx.fill();
    ctx.strokeStyle = rgba(moon, 0.12);
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  let stop = null;
  let lastDraw = 0;
  function tick(now, dt) {
    state.target = targetOffset();
    const moving = Math.abs(state.offset - state.target) > 0.4;
    state.offset = damp(state.offset, state.target, 3.2, dt);
    // Idle, the windows only flicker: thirty frames a second is plenty.
    if (!moving && now - lastDraw < 33 && now - state.lastScroll > 200) return true;
    lastDraw = now;
    draw(now);
    return true;
  }
  const run = () => {
    stop?.();
    stop = null;
    if (motionOn()) stop = addTicker(tick);
    else {
      state.offset = targetOffset();
      draw(0);
    }
  };

  layout();
  window.addEventListener("resize", () => {
    layout();
    if (!motionOn()) draw(0);
  });
  onScroll(() => {
    state.lastScroll = performance.now();
    if (!motionOn()) {
      state.offset = targetOffset();
      draw(0);
    }
  });
  // On the hub, a case card under the pointer (or keyboard focus) brings its castle forward.
  const pick = (event) => {
    const card = event.target.closest?.(".case-card[data-slug], .library__row[data-slug]");
    state.hover = card && CASES.includes(card.dataset.slug) ? card.dataset.slug : null;
    if (!motionOn()) {
      state.offset = targetOffset();
      draw(0);
    }
  };
  document.addEventListener("pointerover", pick, { passive: true });
  document.addEventListener("focusin", pick);
  document.addEventListener("sc:strike", (event) => {
    const slug = event.detail?.castle;
    if (slug) state.flare.set(slug, performance.now());
  });
  document.addEventListener("sc:motionchange", run);
  run();
}
