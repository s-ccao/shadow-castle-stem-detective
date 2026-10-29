import { addTicker, onScroll, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { addPainter, wakeLight } from "./light.js";
import { ACTIVE, TAU, heroCovers, lowPower, rgba, skyLayer, sprite } from "./kit.js";
import { CASES } from "./castles.js";

// The potion. A bottle stands in the open space at the start of every chapter, each
// holding one case's potion. As the page scrolls, the potion pours out of one bottle
// and runs down through the night behind the content, winding through the gaps, and
// thins into the dark as it goes: only the bottle's mouth, the flowing front, the
// pointer's light and lightning show the whole stream. Follow it and it pours into the
// next bottle, which fills with the next case's colour. Touch a bottle and its stopper
// lifts; click it and its potion answers in its own way, as does the stream under the
// pointer.
const READ = 0.62; // the reading line, as a share of the screen height
const FLOW = 1100; // px per second, faster when it has far to catch up
const SHAPES = ["flask", "erlenmeyer", "vial", "round"];
const TEXT = "h1, h2, h3, h4, p, li, dt, dd, figcaption, blockquote, label, a, button, input, select, textarea, .stamp";
const MEDIA = "img, video, canvas, figure, table, form, iframe, .case-card, .case-hero__art, .night-numeral";
const KIND = {
  "shadow-castle": "lantern",
  "evidence-rush": "luminol",
  "prism-lab": "prism",
  "echo-corridor": "echo",
  "time-echo": "time",
  "alchemy-shift": "transmute",
  "rune-defense": "ward",
};
const RUNES = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛞᛟ";
const RUNE_FONT = "'Apple Symbols', 'Segoe UI Historic', 'Noto Sans Runic', serif";

// What the lightning (runes.js) needs to know, in viewport coordinates.
const api = { head: null, bottles: [], light() {}, flash() {} };
export const potionHead = () => api.head;
export const potionBottles = () => api.bottles;
export const lightBottle = (k) => api.light(k);
export const flashPotion = () => api.flash();

const mix = (a, b, f) => a.map((v, i) => Math.round(v + (b[i] - v) * f));
const approach = (v, target, step) => v + Math.sign(target - v) * Math.min(Math.abs(target - v), step);
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (list) => list[Math.floor(Math.random() * list.length)];

// A bottle's glass, centred on the origin, mouth up.
function bottleShape(shape, w, h) {
  const outline = new Path2D();
  const nw = w * (shape === "vial" ? 0.62 : 0.3);
  const top = -h / 2;
  if (shape === "flask" || shape === "round") {
    const r = shape === "flask" ? w * 0.5 : w * 0.46;
    const cy = h / 2 - r;
    const theta = Math.asin(Math.min(0.95, nw / 2 / r));
    const jy = cy - r * Math.cos(theta);
    outline.moveTo(-nw / 2, top);
    outline.lineTo(-nw / 2, jy);
    outline.arc(0, cy, r, -Math.PI / 2 - theta, -Math.PI / 2 + theta, true);
    outline.lineTo(nw / 2, top);
    return { outline, fillTop: jy + (shape === "flask" ? 0 : r * 0.1), neck: nw };
  }
  if (shape === "erlenmeyer") {
    const shoulder = -h * 0.1;
    const rad = w * 0.12;
    outline.moveTo(-nw / 2, top);
    outline.lineTo(-nw / 2, shoulder);
    outline.lineTo(-w / 2 + rad * 0.4, h / 2 - rad);
    outline.quadraticCurveTo(-w / 2, h / 2, -w / 2 + rad, h / 2);
    outline.lineTo(w / 2 - rad, h / 2);
    outline.quadraticCurveTo(w / 2, h / 2, w / 2 - rad * 0.4, h / 2 - rad);
    outline.lineTo(nw / 2, shoulder);
    outline.lineTo(nw / 2, top);
    return { outline, fillTop: shoulder + h * 0.04, neck: nw };
  }
  const r = nw / 2;
  outline.moveTo(-r, top);
  outline.lineTo(-r, h / 2 - r);
  outline.arc(0, h / 2 - r, r, Math.PI, 0, true);
  outline.lineTo(r, top);
  return { outline, fillTop: top + h * 0.16, neck: nw };
}

// The largest empty square in a region of the page, preferring the region's top.
function freeSpot(region, blockers, minSide) {
  const C = 16;
  const cols = Math.floor((region.right - region.left) / C);
  const rows = Math.floor((region.bottom - region.top) / C);
  if (cols < 2 || rows < 2) return null;
  const blocked = new Uint8Array(cols * rows);
  for (const r of blockers) {
    if (r.bottom < region.top || r.top > region.bottom) continue;
    const c0 = Math.max(0, Math.floor((r.left - 14 - region.left) / C));
    const c1 = Math.min(cols - 1, Math.floor((r.right + 14 - region.left) / C));
    const r0 = Math.max(0, Math.floor((r.top - 14 - region.top) / C));
    const r1 = Math.min(rows - 1, Math.floor((r.bottom + 14 - region.top) / C));
    for (let row = r0; row <= r1; row += 1) if (c0 <= c1) blocked.fill(1, row * cols + c0, row * cols + c1 + 1);
  }
  const run = new Uint16Array(cols * rows);
  let best = null;
  let bestScore = 0;
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const i = row * cols + col;
      if (blocked[i]) continue;
      run[i] = 1 + Math.min(row ? run[i - cols] : 0, col ? run[i - 1] : 0, row && col ? run[i - cols - 1] : 0);
      const side = run[i] * C;
      if (side < minSide) continue;
      const y = region.top + (row + 1) * C - side / 2;
      const score = side * (1.2 - (0.5 * (y - region.top)) / (region.bottom - region.top));
      if (score > bestScore) {
        bestScore = score;
        best = { x: region.left + (col + 1) * C - side / 2, y, side };
      }
    }
  }
  return best;
}

// A* over a grid of cell costs, eight ways. Returns cell indices from start to goal.
const STEPS = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, Math.SQRT2], [-1, 1, Math.SQRT2], [1, -1, Math.SQRT2], [-1, -1, Math.SQRT2]];
function route(cost, cols, rows, start, goal) {
  const n = cols * rows;
  const g = new Float32Array(n).fill(Infinity);
  const came = new Int32Array(n).fill(-1);
  const done = new Uint8Array(n);
  const heap = [];
  const push = (f, i) => {
    heap.push([f, i]);
    let c = heap.length - 1;
    while (c > 0) {
      const p = (c - 1) >> 1;
      if (heap[p][0] <= heap[c][0]) break;
      [heap[p], heap[c]] = [heap[c], heap[p]];
      c = p;
    }
  };
  const pop = () => {
    const top = heap[0];
    const last = heap.pop();
    if (heap.length) {
      heap[0] = last;
      let c = 0;
      for (;;) {
        const l = 2 * c + 1;
        const r = l + 1;
        let m = c;
        if (l < heap.length && heap[l][0] < heap[m][0]) m = l;
        if (r < heap.length && heap[r][0] < heap[m][0]) m = r;
        if (m === c) break;
        [heap[m], heap[c]] = [heap[c], heap[m]];
        c = m;
      }
    }
    return top;
  };
  const gc = goal % cols;
  const gr = Math.floor(goal / cols);
  const h = (i) => Math.hypot((i % cols) - gc, Math.floor(i / cols) - gr);
  g[start] = 0;
  push(h(start), start);
  while (heap.length) {
    const [, cur] = pop();
    if (done[cur]) continue;
    done[cur] = 1;
    if (cur === goal) break;
    const cc = cur % cols;
    const cr = Math.floor(cur / cols);
    for (const [dc, dr, step] of STEPS) {
      const nc = cc + dc;
      const nr = cr + dr;
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      const ni = nr * cols + nc;
      if (done[ni]) continue;
      const next = g[cur] + (step * (cost[cur] + cost[ni])) / 2;
      if (next < g[ni]) {
        g[ni] = next;
        came[ni] = cur;
        push(next + h(ni), ni);
      }
    }
  }
  const path = [];
  for (let i = goal; i !== -1; i = came[i]) {
    path.push(i);
    if (i === start) break;
  }
  return path[path.length - 1] === start ? path.reverse() : null;
}

// Catmull-Rom through control points, sampled every `step` px.
function smooth(ctrl, step) {
  const out = [];
  for (let i = 0; i < ctrl.length - 1; i += 1) {
    const p0 = ctrl[Math.max(0, i - 1)];
    const p1 = ctrl[i];
    const p2 = ctrl[i + 1];
    const p3 = ctrl[Math.min(ctrl.length - 1, i + 2)];
    const n = Math.max(1, Math.ceil(Math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step));
    for (let k = 0; k < n; k += 1) {
      const t = k / n;
      const t2 = t * t;
      const t3 = t2 * t;
      const f = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
      out.push([f(p0[0], p1[0], p2[0], p3[0]), f(p0[1], p1[1], p2[1], p3[1])]);
    }
  }
  out.push(ctrl[ctrl.length - 1]);
  return out;
}

function indexAt(seg, len) {
  let lo = 0;
  let hi = seg.cum.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (seg.cum[mid] < len) lo = mid + 1;
    else hi = mid;
  }
  return lo;
}

function pointAt(seg, len) {
  const i = Math.max(1, indexAt(seg, len));
  const a = seg.pts[i - 1];
  const b = seg.pts[i];
  const f = Math.min(1, Math.max(0, (len - seg.cum[i - 1]) / (seg.cum[i] - seg.cum[i - 1] || 1)));
  return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
}

// How far along a stream the reading line has reached: the first point below it.
function goal(seg, line) {
  const p = seg.pts;
  if (p[0][1] > line) return 0;
  for (let i = 1; i < p.length; i += 1) {
    if (p[i][1] > line) {
      const f = (line - p[i - 1][1]) / (p[i][1] - p[i - 1][1] || 1);
      return seg.cum[i - 1] + (seg.cum[i] - seg.cum[i - 1]) * Math.min(1, Math.max(0, f));
    }
  }
  return seg.L;
}

export function initPotion() {
  const root = document.documentElement;
  const chapters = [...document.querySelectorAll("main > section, body > .site-footer")].filter((el) => !el.matches(".hub-hero, .hero"));
  if (chapters.length < 2) return;
  const canvas = skyLayer("potion");
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const moon = tokenRgb("--color-moon");
  const night = tokenRgb("--color-night");
  const brass = tokenRgb("--color-bronze");
  const gold = tokenRgb("--color-accent");
  const ember = tokenRgb("--color-ember");
  const ink = tokenRgb("--color-ink");
  const spectrum = [1, 2, 3, 4, 5, 6, 7].map((n) => tokenRgb(`--color-spectrum-${n}`));
  const caseColor = Object.fromEntries(CASES.map((slug) => [slug, tokenRgb(`--game-${slug}`)]));
  const pageCase = document.querySelector("main[data-case]")?.dataset.case;
  const first = Math.max(0, CASES.indexOf(pageCase));
  const slugOf = (k) => CASES[(first + k) % CASES.length];
  const covered = heroCovers();
  const glows = new Map();
  const glowOf = (rgb) => {
    const key = rgb.join(",");
    if (!glows.has(key)) glows.set(key, sprite(rgb, 64));
    return glows.get(key);
  };
  const white = sprite(ink, 32);

  let view = { w: 0, h: 0, dpr: 1 };
  let bottles = [];
  let segments = [];
  let flashAt = -1e9;
  const pointer = { x: -1e4, y: -1e4, on: false };

  // ---------- particles: one list behind the page, one in the pointer's light ----------
  const cap = lowPower ? 150 : 320;
  const mist = [];
  const backFx = [];
  const frontFx = [];
  const P = (kind, x, y, o = {}) => ({ kind, x, y, vx: 0, vy: 0, ax: 0, ay: 0, rot: 0, vr: 0, size: 6, r0: 0, r1: 0, a: 1, color: gold, life: 800, t0: performance.now(), ...o });
  const add = (list, p) => {
    if (list.length < cap) list.push(p);
  };
  const mouthOf = (b) => [b.x, b.y - b.h / 2 - 4 * b.s];
  const towardPointer = (x, y, speed) => {
    const dx = pointer.x - x;
    const dy = pointer.y + window.scrollY - y;
    const d = Math.hypot(dx, dy) || 1;
    return [(dx / d) * speed, (dy / d) * speed];
  };

  // Each case's potion answers the pointer in its own way: over its bottle (hover),
  // along its stream (near), and when its bottle is clicked (click, drawn over the page).
  const EFFECTS = {
    lantern: {
      rate: 150,
      nearRate: 70,
      hover(b) {
        const [x, y] = mouthOf(b);
        for (let i = 0; i < 2; i += 1) add(backFx, P("ray", x, y, { rot: -Math.PI / 2 + rand(-0.6, 0.6), size: rand(50, 95) * b.s, life: 700, color: b.color, width: 2.4 }));
        add(backFx, P("spark", x, y, { vx: rand(-0.03, 0.03), vy: rand(-0.09, -0.04), life: 900, size: 4 * b.s, color: ember }));
      },
      near(x, y, color) {
        for (let i = 0; i < 2; i += 1) {
          const [vx, vy] = towardPointer(x, y, 0.07);
          add(backFx, P("spark", x + rand(-6, 6), y + rand(-6, 6), { vx: vx + rand(-0.02, 0.02), vy: vy + rand(-0.02, 0.02), life: 750, size: 4, color }));
        }
      },
      click(b) {
        add(frontFx, P("flash", b.x, b.y, { r0: 30, r1: 200 * b.s, life: 750, color: ember }));
        for (let i = 0; i < 18; i += 1) {
          const a = rand(0, TAU);
          const v = rand(0.12, 0.32);
          add(frontFx, P("spark", b.x, b.y, { vx: Math.cos(a) * v, vy: Math.sin(a) * v, ay: 0.0002, life: rand(600, 1050), size: 5, color: i % 3 ? ember : gold }));
        }
        // The lantern answers too: the wall around the bottle develops its evidence.
        document.dispatchEvent(new CustomEvent("sc:reveal", { detail: { x: b.x - window.scrollX, y: b.y, r: 340 } }));
      },
    },
    luminol: {
      rate: 180,
      nearRate: 90,
      hover(b) {
        add(backFx, P("drop", b.x + b.dir * b.neck * 0.55, b.y - b.h / 2, { vx: b.dir * 0.012, vy: 0.02, ay: 0.0004, life: 900, size: 2.6 * b.s, color: b.color }));
      },
      near(x, y, color) {
        add(backFx, P("splat", x + rand(-10, 10), y + rand(-10, 10), { size: rand(6, 11), life: 1700, color }));
        if (Math.random() < 0.5) add(backFx, P("drop", x, y, { vx: rand(-0.02, 0.02), vy: 0.01, ay: 0.0004, life: 700, size: 2, color }));
      },
      click(b) {
        for (let i = 0; i < 18; i += 1) {
          const a = rand(0, TAU);
          const v = rand(0.15, 0.36);
          add(frontFx, P("drop", b.x, b.y, { vx: Math.cos(a) * v, vy: Math.sin(a) * v - 0.08, ay: 0.0006, life: rand(900, 1300), size: rand(2, 3.6), color: b.color }));
        }
        for (let i = 0; i < 10; i += 1) {
          const a = rand(0, TAU);
          const d = rand(40, 150);
          add(frontFx, P("splat", b.x + Math.cos(a) * d, b.y + Math.sin(a) * d * 0.7, { size: rand(7, 14), life: 1900, t0: performance.now() + rand(120, 520), color: b.color }));
        }
      },
    },
    prism: {
      rate: 110,
      nearRate: 140,
      hover(b) {
        const [x, y] = mouthOf(b);
        const k = Math.floor(rand(0, spectrum.length));
        add(backFx, P("ray", x, y, { rot: -Math.PI / 2 + (k - 3) * 0.13, size: rand(70, 100) * b.s, life: 650, color: spectrum[k], width: 2.2 }));
      },
      near(x, y) {
        add(backFx, P("ray", x, y, { rot: rand(0, TAU), size: rand(26, 48), life: 520, color: pick(spectrum), width: 1.6 }));
      },
      click(b) {
        add(frontFx, P("flash", b.x, b.y, { r0: 20, r1: 140 * b.s, life: 600, color: ink }));
        const base = rand(0, TAU);
        for (let ring = 0; ring < 3; ring += 1) {
          spectrum.forEach((color, k) => add(frontFx, P("ray", b.x, b.y, { rot: base + ring * (TAU / 3) + (k - 3) * 0.07, size: rand(180, 240), life: 950, color, width: 2.6 })));
        }
        add(frontFx, P("ring", b.x, b.y, { r0: 10, r1: 150, life: 900, color: ink }));
      },
    },
    echo: {
      rate: 360,
      nearRate: 320,
      hover(b) {
        const [x, y] = mouthOf(b);
        add(backFx, P("ring", x, y, { r0: 4, r1: 48 * b.s, life: 1000, color: b.color }));
      },
      near(x, y, color) {
        add(backFx, P("ring", x, y, { r0: 4, r1: 72, life: 1100, color }));
      },
      click(b) {
        [0, 150, 300].forEach((delay, i) => add(frontFx, P("ring", b.x, b.y, { r0: 12, r1: 130 + i * 70, life: 1200, t0: performance.now() + delay, color: b.color, width: 2 })));
      },
    },
    time: {
      rate: 260,
      nearRate: 170,
      hover(b) {
        if (!backFx.some((p) => p.kind === "dial" && p.bottle === b.k)) add(backFx, P("dial", b.x, b.y, { size: b.h * 0.62, life: 1500, color: b.color, bottle: b.k, spin: -1 }));
        const [x, y] = mouthOf(b);
        for (let i = 0; i < 2; i += 1) add(backFx, P("grain", x + rand(-6, 6), y, { vx: rand(-0.008, 0.008), vy: rand(-0.025, -0.01), life: 2000, color: b.color }));
      },
      near(x, y, color) {
        for (let i = 0; i < 3; i += 1) add(backFx, P("grain", x + rand(-12, 12), y + rand(-12, 12), { vx: rand(-0.008, 0.008), vy: rand(-0.008, 0.008), life: 1900, color }));
        if (Math.random() < 0.2) add(backFx, P("dial", x, y, { size: 24, life: 1300, color, spin: -2 }));
      },
      click(b) {
        add(frontFx, P("dial", b.x, b.y, { size: 110 * b.s, life: 1500, color: b.color, spin: -3 }));
        add(frontFx, P("ring", b.x, b.y, { r0: 20, r1: 150, life: 1100, color: b.color }));
        for (let i = 0; i < 26; i += 1) {
          const a = rand(0, TAU);
          const d = rand(20, 120);
          add(frontFx, P("grain", b.x + Math.cos(a) * d, b.y + Math.sin(a) * d, { ay: 0.00022, life: rand(1400, 2000), color: b.color }));
        }
      },
    },
    transmute: {
      rate: 120,
      nearRate: 110,
      hover(b) {
        const [x, y] = mouthOf(b);
        for (let i = 0; i < 2; i += 1) add(backFx, P("bubble", x + rand(-1, 1) * b.neck * 0.3, y, { vx: rand(-0.01, 0.01), vy: rand(-0.06, -0.03), size: rand(2.5, 5) * b.s, life: rand(900, 1500), color: b.color }));
      },
      near(x, y, color) {
        for (let i = 0; i < 2; i += 1) add(backFx, P("bubble", x + rand(-8, 8), y, { vx: rand(-0.01, 0.01), vy: rand(-0.05, -0.025), size: rand(2, 4.5), life: rand(800, 1300), color }));
      },
      click(b) {
        b.cycle = performance.now();
        add(frontFx, P("flash", b.x, b.y, { r0: 20, r1: 150 * b.s, life: 700, color: b.color }));
        for (let i = 0; i < 20; i += 1) {
          const a = rand(0, TAU);
          const v = rand(0.07, 0.2);
          add(frontFx, P("bubble", b.x, b.y, { vx: Math.cos(a) * v, vy: Math.sin(a) * v - 0.04, size: rand(3, 7), life: rand(900, 1400), color: caseColor[pick(CASES)] }));
        }
      },
    },
    ward: {
      rate: 240,
      nearRate: 230,
      hover(b) {
        const [x, y] = mouthOf(b);
        add(backFx, P("glyph", x + rand(-6, 6), y, { vx: rand(-0.015, 0.015), vy: -0.035, vr: rand(-0.002, 0.002), size: rand(13, 18) * b.s, life: 1400, glyph: pick(RUNES), color: b.color }));
      },
      near(x, y, color) {
        add(backFx, P("glyph", x + rand(-8, 8), y + rand(-8, 8), { vy: -0.02, vr: rand(-0.002, 0.002), size: rand(12, 16), life: 1300, glyph: pick(RUNES), color }));
      },
      click(b) {
        add(frontFx, P("hex", b.x, b.y, { r0: 24, r1: 130 * b.s, life: 1150, rot: rand(0, TAU), glyphs: Array.from({ length: 6 }, () => pick(RUNES)), color: b.color }));
        for (let i = 0; i < 10; i += 1) {
          const a = rand(0, TAU);
          add(frontFx, P("spark", b.x, b.y, { vx: Math.cos(a) * 0.2, vy: Math.sin(a) * 0.2, life: 800, size: 5, color: b.color }));
        }
      },
    },
  };

  function drawParticles(g, list, now, dt, sy) {
    g.globalCompositeOperation = "lighter";
    g.lineCap = "round";
    for (let i = list.length - 1; i >= 0; i -= 1) {
      const p = list[i];
      if (now < p.t0) continue;
      const age = (now - p.t0) / p.life;
      if (age >= 1) {
        list.splice(i, 1);
        continue;
      }
      p.vx += p.ax * dt;
      p.vy += p.ay * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
      const x = p.x;
      const y = p.y - sy;
      const fade = Math.sin(age * Math.PI);
      const grow = 1 - (1 - age) ** 3;
      switch (p.kind) {
        case "mist": {
          const r = p.r0 + (p.r1 - p.r0) * age;
          g.globalAlpha = fade * p.a;
          g.drawImage(glowOf(p.color), x - r, y - r, r * 2, r * 2);
          break;
        }
        case "spark": {
          const r = p.size * (1 - age * 0.5);
          g.globalAlpha = 1 - age;
          g.drawImage(glowOf(p.color), x - r * 2, y - r * 2, r * 4, r * 4);
          g.drawImage(white, x - r * 0.6, y - r * 0.6, r * 1.2, r * 1.2);
          break;
        }
        case "drop": {
          g.globalAlpha = 1 - age * 0.7;
          g.fillStyle = rgba(p.color, 1);
          g.beginPath();
          g.arc(x, y, p.size, 0, TAU);
          g.fill();
          g.globalAlpha *= 0.55;
          g.drawImage(glowOf(p.color), x - p.size * 4, y - p.size * 4, p.size * 8, p.size * 8);
          break;
        }
        case "splat": {
          const r = p.size * (0.6 + 0.4 * Math.min(1, age * 6));
          g.globalAlpha = (1 - age) ** 1.5 * 0.85;
          g.save();
          g.translate(x, y);
          g.scale(1, 0.62);
          g.drawImage(glowOf(p.color), -r * 2, -r * 2, r * 4, r * 4);
          g.fillStyle = rgba(p.color, 0.7);
          g.beginPath();
          g.arc(0, 0, r * 0.55, 0, TAU);
          g.fill();
          g.restore();
          break;
        }
        case "bubble": {
          const bx = x + Math.sin(now * 0.008 + i) * 1.5;
          g.globalAlpha = fade * 0.85;
          g.strokeStyle = rgba(ink, 0.8);
          g.lineWidth = 1;
          g.beginPath();
          g.arc(bx, y, p.size, 0, TAU);
          g.stroke();
          g.globalAlpha = fade * 0.45;
          g.drawImage(glowOf(p.color), bx - p.size * 2.5, y - p.size * 2.5, p.size * 5, p.size * 5);
          break;
        }
        case "glyph": {
          g.globalAlpha = fade;
          g.save();
          g.translate(x, y);
          g.rotate(p.rot);
          g.drawImage(glowOf(p.color), -p.size * 1.4, -p.size * 1.4, p.size * 2.8, p.size * 2.8);
          g.fillStyle = rgba(mix(p.color, ink, 0.45), 1);
          g.font = `${Math.round(p.size)}px ${RUNE_FONT}`;
          g.textAlign = "center";
          g.textBaseline = "middle";
          g.fillText(p.glyph, 0, 0);
          g.restore();
          break;
        }
        case "ring": {
          g.globalAlpha = (1 - age) ** 1.5 * 0.85;
          g.strokeStyle = rgba(p.color, 1);
          g.lineWidth = p.width || 1.6;
          g.beginPath();
          g.arc(x, y, p.r0 + (p.r1 - p.r0) * grow, 0, TAU);
          g.stroke();
          break;
        }
        case "ray": {
          const len = p.size * (1 - (1 - age) ** 2);
          g.globalAlpha = (1 - age) * 0.9;
          g.strokeStyle = rgba(p.color, 1);
          g.lineWidth = p.width || 2;
          g.beginPath();
          g.moveTo(x, y);
          g.lineTo(x + Math.cos(p.rot) * len, y + Math.sin(p.rot) * len);
          g.stroke();
          break;
        }
        case "grain": {
          g.globalAlpha = fade * 0.9;
          g.fillStyle = rgba(p.color, 1);
          g.fillRect(x - 1, y - 1, 2.2, 2.2);
          break;
        }
        case "dial": {
          // A clock face whose hands run backwards.
          const r = p.size;
          g.globalAlpha = fade * 0.85;
          g.strokeStyle = rgba(p.color, 1);
          g.lineWidth = 1.4;
          g.beginPath();
          g.arc(x, y, r, 0, TAU);
          for (let k = 0; k < 12; k += 1) {
            const a = (k / 12) * TAU;
            g.moveTo(x + Math.cos(a) * r * 0.86, y + Math.sin(a) * r * 0.86);
            g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
          }
          const turn = age * TAU * (p.spin || -1);
          g.moveTo(x, y);
          g.lineTo(x + Math.cos(turn * 12 - Math.PI / 2) * r * 0.78, y + Math.sin(turn * 12 - Math.PI / 2) * r * 0.78);
          g.moveTo(x, y);
          g.lineTo(x + Math.cos(turn - Math.PI / 2) * r * 0.5, y + Math.sin(turn - Math.PI / 2) * r * 0.5);
          g.stroke();
          break;
        }
        case "hex": {
          // A rune ward: a hexagon with a rune at every corner.
          const r = p.r0 + (p.r1 - p.r0) * grow;
          g.globalAlpha = (1 - age) ** 1.2;
          g.strokeStyle = rgba(p.color, 1);
          g.lineWidth = 1.8;
          g.beginPath();
          for (let k = 0; k <= 6; k += 1) {
            const a = p.rot + (k / 6) * TAU;
            if (k) g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
            else g.moveTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
          }
          g.stroke();
          g.fillStyle = rgba(mix(p.color, ink, 0.45), 1);
          g.font = `16px ${RUNE_FONT}`;
          g.textAlign = "center";
          g.textBaseline = "middle";
          for (let k = 0; k < 6; k += 1) {
            const a = p.rot + (k / 6) * TAU;
            g.fillText(p.glyphs[k], x + Math.cos(a) * r, y + Math.sin(a) * r);
          }
          break;
        }
        case "flash": {
          const r = p.r0 + (p.r1 - p.r0) * grow;
          g.globalAlpha = (1 - age) ** 2 * 0.75;
          g.drawImage(glowOf(p.color), x - r, y - r, r * 2, r * 2);
          break;
        }
        default:
          break;
      }
    }
    g.globalAlpha = 1;
    g.globalCompositeOperation = "source-over";
  }

  // ---------- layout: where the bottles stand and which way the potion runs ----------
  let textMask = { cols: 0, rows: 0, cells: new Uint8Array(0) };
  const MASK = 16;

  function measure() {
    const sy = window.scrollY;
    const blockers = [];
    const rects = chapters.map((el) => {
      const box = el.getBoundingClientRect();
      let top = Infinity;
      let left = Infinity;
      let right = -Infinity;
      for (const node of el.querySelectorAll(`${TEXT}, ${MEDIA}`)) {
        const r = node.getBoundingClientRect();
        if (!r.width || !r.height) continue;
        blockers.push({ left: r.left, right: r.right, top: r.top + sy, bottom: r.bottom + sy, text: node.matches(TEXT) });
        if (node.matches(".night-numeral")) continue;
        top = Math.min(top, r.top + sy);
        left = Math.min(left, r.left);
        right = Math.max(right, r.right);
      }
      return {
        top: box.top + sy,
        bottom: box.bottom + sy,
        cTop: Number.isFinite(top) ? top : box.top + sy,
        gl: Number.isFinite(left) ? Math.max(0, left) : 16,
        gr: Number.isFinite(right) ? Math.max(0, view.w - right) : 16,
      };
    });
    // Where text lies, so the stream dims behind it and stays readable.
    const height = document.documentElement.scrollHeight;
    const cols = Math.ceil(view.w / MASK);
    const rows = Math.ceil(height / MASK);
    const cells = new Uint8Array(cols * rows);
    for (const b of blockers) {
      if (!b.text) continue;
      const c0 = Math.max(0, Math.floor(b.left / MASK));
      const c1 = Math.min(cols - 1, Math.floor(b.right / MASK));
      for (let r = Math.max(0, Math.floor(b.top / MASK)); r <= Math.min(rows - 1, Math.floor(b.bottom / MASK)); r += 1) {
        if (c0 <= c1) cells.fill(1, r * cols + c0, r * cols + c1 + 1);
      }
    }
    textMask = { cols, rows, cells };
    return { rects, blockers };
  }

  function placeBottles(rects, blockers) {
    const narrow = view.w < 700;
    const dock = matchMedia("(min-width: 60rem)").matches ? document.querySelector(".case-dock") : null;
    const dockW = dock ? dock.offsetWidth + 8 : 0;
    const old = bottles;
    return rects.map((ch, k) => {
      const region = { left: 6, right: view.w - dockW - 6, top: ch.top + 12, bottom: Math.min(ch.bottom - 12, ch.top + Math.max(560, view.h * 0.95)) };
      const spot = freeSpot(region, blockers, narrow ? 76 : 120);
      let x;
      let y;
      let h;
      if (spot) {
        h = Math.min(spot.side * 0.78, narrow ? 104 : 190);
        x = spot.x;
        y = spot.y + spot.side * 0.08;
      } else {
        // No open space: the wider margin, clear of the dock.
        const gr = ch.gr - dockW;
        const side = narrow || gr > ch.gl ? 1 : -1;
        const gutter = Math.max(0, side < 0 ? ch.gl : gr);
        h = Math.max(narrow ? 34 : 46, Math.min(96, gutter * 1.3));
        const inset = Math.max(h * 0.33 + 2, gutter / 2);
        x = side < 0 ? inset : view.w - dockW - inset;
        y = Math.max(ch.top + h * 0.6 + 20, ch.cTop + h * 0.5);
      }
      const s = h / 92;
      const w = 60 * s;
      const shape = SHAPES[k % SHAPES.length];
      const slug = slugOf(k);
      const prev = old[k];
      return {
        k,
        x,
        y,
        w,
        h,
        s,
        shape,
        slug,
        kind: KIND[slug],
        color: caseColor[slug],
        dir: x < view.w / 2 ? 1 : -1,
        ...bottleShape(shape, w, h),
        level: prev?.level ?? (k === 0 ? 1 : 0),
        want: prev?.want ?? (k === 0 ? 1 : 0),
        burstAt: prev?.burstAt ?? -1e9,
        lid: 0,
        tilt: 0,
        hover: false,
        flash: -1e9,
        cycle: -1e9,
        openUntil: 0,
        nextEmit: 0,
        nextVapor: 0,
        puffed: false,
      };
    });
  }

  // The stream's course: out over the lip, then the cheapest way down the page, where
  // text costs most, pictures a little (the potion passes behind them) and the page's
  // outer edges more, so it winds through the open night rather than the margin.
  function buildSegment(a, b, blockers, before) {
    const narrow = view.w < 700;
    const C = narrow ? 20 : 24;
    const lip = [a.x + a.dir * a.neck * 0.5, a.y - a.h / 2];
    const out1 = [lip[0] + a.dir * 24 * a.s, lip[1] + 10 * a.s];
    const out2 = [lip[0] + a.dir * 38 * a.s, a.y + a.h * 0.55];
    const mouth = [b.x, b.y - b.h / 2 - 2];
    const above = [b.x, mouth[1] - 70 * b.s];
    const top = Math.min(out2[1], above[1]) - 160;
    const bottom = Math.max(out2[1], above[1]) + 160;
    const cols = Math.max(2, Math.ceil(view.w / C));
    const rows = Math.max(2, Math.ceil((bottom - top) / C));
    const block = new Float32Array(cols * rows);
    for (const bl of blockers) {
      if (bl.bottom < top || bl.top > bottom) continue;
      const add = bl.text ? 7 : 1.5;
      const c0 = Math.max(0, Math.floor((bl.left - 6) / C));
      const c1 = Math.min(cols - 1, Math.floor((bl.right + 6) / C));
      const r0 = Math.max(0, Math.floor((bl.top - 6 - top) / C));
      const r1 = Math.min(rows - 1, Math.floor((bl.bottom + 6 - top) / C));
      for (let r = r0; r <= r1; r += 1) for (let c = c0; c <= c1; c += 1) block[r * cols + c] = Math.max(block[r * cols + c], add);
    }
    const edge = Math.max(2, Math.round(cols * 0.06));
    const rim = Math.max(1, Math.round(cols * 0.025));
    const cost = new Float32Array(cols * rows);
    for (let r = 0; r < rows; r += 1) {
      for (let c = 0; c < cols; c += 1) {
        const fromEdge = Math.min(c, cols - 1 - c);
        cost[r * cols + c] = 1 + block[r * cols + c] + (fromEdge < rim ? 5 : fromEdge < edge ? 2.5 : 0);
      }
    }
    const cell = ([x, y]) => Math.min(rows - 1, Math.max(0, Math.floor((y - top) / C))) * cols + Math.min(cols - 1, Math.max(0, Math.floor(x / C)));
    const path = route(cost, cols, rows, cell(out2), cell(above));
    const ctrl = [lip, out1, out2];
    if (path) {
      for (let i = 3; i < path.length - 3; i += 3) {
        const idx = path[i];
        ctrl.push([((idx % cols) + 0.5) * C, top + (Math.floor(idx / cols) + 0.5) * C]);
      }
    }
    ctrl.push(above);
    const pts = smooth(ctrl, 6);
    // A slow, living meander, pinned at both ends.
    const cumRaw = [0];
    for (let i = 1; i < pts.length; i += 1) cumRaw.push(cumRaw[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
    const total = cumRaw[cumRaw.length - 1] || 1;
    const phase = a.k * 1.7;
    const bent = pts.map(([x, y], i) => {
      const p0 = pts[Math.max(0, i - 1)];
      const p1 = pts[Math.min(pts.length - 1, i + 1)];
      const len = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]) || 1;
      const u = cumRaw[i];
      const pin = Math.min(1, u / 140, (total - u) / 140);
      const off = Math.sin(u * 0.011 + phase) * 9 * pin;
      return [x + (-(p1[1] - p0[1]) / len) * off, y + ((p1[0] - p0[0]) / len) * off];
    });
    // The last stretch falls straight into the next bottle's mouth.
    for (let k = 1; k <= 10; k += 1) bent.push([above[0], above[1] + ((mouth[1] - above[1]) * k) / 10]);
    const cum = new Float32Array(bent.length);
    const under = new Float32Array(bent.length);
    let minY = Infinity;
    let maxY = -Infinity;
    for (let i = 0; i < bent.length; i += 1) {
      if (i) cum[i] = cum[i - 1] + Math.hypot(bent[i][0] - bent[i - 1][0], bent[i][1] - bent[i - 1][1]);
      const mc = Math.floor(bent[i][0] / MASK);
      const mr = Math.floor(bent[i][1] / MASK);
      under[i] = mc >= 0 && mr >= 0 && mc < textMask.cols && mr < textMask.rows ? textMask.cells[mr * textMask.cols + mc] : 0;
      minY = Math.min(minY, bent[i][1]);
      maxY = Math.max(maxY, bent[i][1]);
    }
    const L = cum[cum.length - 1];
    return {
      k: a.k,
      a,
      b,
      pts: bent,
      cum,
      under,
      L,
      minY,
      maxY,
      fallFrom: bent.length - 11,
      fill: before ? Math.min(L, (before.fill / (before.L || 1)) * L) : 0,
      spent: before?.spent ?? 0,
      flowing: 0,
    };
  }

  function layout() {
    const dpr = Math.min(window.devicePixelRatio || 1, lowPower ? 1 : 1.5);
    view = { w: window.innerWidth, h: window.innerHeight, dpr };
    canvas.width = Math.round(view.w * dpr);
    canvas.height = Math.round(view.h * dpr);
    const { rects, blockers } = measure();
    bottles = placeBottles(rects, blockers);
    const old = segments;
    segments = [];
    for (let k = 0; k < bottles.length - 1; k += 1) segments.push(buildSegment(bottles[k], bottles[k + 1], blockers, old[k]));
  }

  // ---------- the flow, the bottles' state, and the pointer ----------
  const liquidColor = (b, now) => {
    const age = (now - b.cycle) / 1400;
    if (age < 0 || age >= 1) return b.color;
    // Transmutation: the potion runs through every case's colour and settles back.
    const f = age * CASES.length * 1.5;
    const i = Math.floor(f);
    const from = caseColor[CASES[i % CASES.length]];
    const to = age > 0.85 ? b.color : caseColor[CASES[(i + 1) % CASES.length]];
    return mix(from, to, Math.round((f - i) * 6) / 6);
  };
  const kindAt = (seg, u) => (u / seg.L < 0.5 ? seg.a : seg.b);
  // Colours come in eight steps between two potions, so the cache of glow sprites
  // stays small however long the stream.
  const colorAt = (seg, u) => {
    const f = Math.min(1, Math.max(0, (u / seg.L - 0.3) / 0.4));
    return mix(seg.a.color, seg.b.color, Math.round(f * f * (3 - 2 * f) * 8) / 8);
  };

  function bottleAt(x, docY) {
    for (const b of bottles) if (Math.abs(x - b.x) < b.w * 0.6 + 8 && Math.abs(docY - b.y) < b.h * 0.6 + 16) return b.k;
    return -1;
  }

  function step(now, dt, animate) {
    const line = window.scrollY + view.h * READ;
    for (const seg of segments) {
      const target = goal(seg, line);
      if (!animate) {
        seg.fill = target;
        continue;
      }
      const diff = target - seg.fill;
      const move = Math.sign(diff) * Math.min(Math.abs(diff), (Math.max(FLOW, Math.abs(diff) * 3) * dt) / 1000);
      seg.fill += move;
      if (Math.abs(move) > 0.15) seg.flowing = now;
    }
    for (const seg of segments) {
      const spent = seg.b.level >= 0.98 ? 1 : 0;
      seg.spent = animate ? approach(seg.spent, spent, dt / 1200) : spent;
    }
    const hovered = pointer.on && animate ? bottleAt(pointer.x, pointer.y + window.scrollY) : -1;
    bottles.forEach((b, k) => {
      const inflow = segments[k - 1];
      const out = segments[k];
      const want = k === 0 ? 1 : inflow && inflow.fill >= inflow.L - 1 ? 1 : 0;
      if (want === 1 && b.want !== 1 && b.level < 0.02) b.burstAt = now;
      b.want = want;
      b.level = animate ? approach(b.level, want, dt / 900) : want;
      b.hover = hovered === k;
      b.pouring = !!out && now - out.flowing < 260 && out.fill > 0.5 && out.fill < out.L - 0.5;
      const receiving = !!inflow && inflow.fill >= inflow.L - 1 && b.level < 0.98;
      const open = b.hover || b.pouring || receiving || now < b.openUntil;
      b.lid = animate ? approach(b.lid, open ? 1 : 0, dt / (open ? 240 : 420)) : 0;
      b.tilt = animate ? b.tilt + ((b.pouring ? b.dir * 0.22 : 0) - b.tilt) * Math.min(1, dt / 140) : 0;
      if (!animate) return;
      // Unstopped, the potion breathes out a little vapour.
      if (b.lid > 0.5 && !b.puffed) {
        b.puffed = true;
        const [x, y] = mouthOf(b);
        for (let i = 0; i < 6; i += 1) add(mist, P("mist", x + rand(-4, 4), y, { vx: rand(-0.02, 0.02), vy: rand(-0.05, -0.02), r0: 4 * b.s, r1: 30 * b.s, a: 0.3, life: rand(900, 1400), color: b.color }));
      }
      if (b.lid < 0.2) b.puffed = false;
      if (b.lid > 0.6 && b.level > 0.2 && now > b.nextVapor) {
        b.nextVapor = now + 320;
        const [x, y] = mouthOf(b);
        add(mist, P("mist", x + rand(-3, 3), y, { vx: rand(-0.008, 0.008), vy: rand(-0.03, -0.015), r0: 3 * b.s, r1: 26 * b.s, a: 0.22, life: rand(1600, 2400), color: b.color }));
      }
      if (b.hover && now > b.nextEmit) {
        b.nextEmit = now + EFFECTS[b.kind].rate;
        EFFECTS[b.kind].hover(b, now);
      }
    });
  }

  // The stream point nearest the pointer, within reach.
  function nearStream(sy) {
    if (!pointer.on) return null;
    const px = pointer.x;
    const py = pointer.y + sy;
    let best = null;
    for (const seg of segments) {
      if (seg.fill <= 1 || py < seg.minY - 150 || py > seg.maxY + 150) continue;
      const end = indexAt(seg, seg.fill);
      for (let i = 0; i <= end; i += 2) {
        const [x, y] = seg.pts[i];
        const d = Math.hypot(x - px, y - py);
        if (d < 150 && (!best || d < best.d)) best = { seg, i, d, x, y };
      }
    }
    return best;
  }

  // ---------- drawing ----------
  function drawStream(seg, now, sy, near, animate) {
    if (seg.fill <= 1) return;
    const { pts, cum, under } = seg;
    const fill = seg.fill;
    const full = fill >= seg.L - 0.5;
    const lo = sy - 90;
    const hi = sy + view.h + 90;
    const end = indexAt(seg, fill);
    const flash = Math.max(0, 1 - (now - flashAt) / 420);
    const reach = animate && pointer.on;
    const px = pointer.x;
    const py = pointer.y + sy;
    const s = (seg.a.s + seg.b.s) / 2;
    const keep = 1 - 0.78 * seg.spent;
    const buckets = Array.from({ length: 8 }, () => new Path2D());
    const used = new Uint8Array(8);
    for (let i = 1; i <= end; i += 1) {
      const [x0, y0] = pts[i - 1];
      const [x1, y1] = i === end ? pointAt(seg, fill) : pts[i];
      if ((y0 < lo && y1 < lo) || (y0 > hi && y1 > hi)) continue;
      const u = cum[i];
      // Bright where it pours, at its front and where it falls into the next bottle;
      // in between it sinks into the night, unless the pointer or lightning finds it.
      const shown = Math.max(1 - u / 300, full ? Math.exp(-(seg.L - u) / 170) : Math.exp(-(fill - u) / 220));
      const reveal = reach ? Math.exp(-((x1 - px) ** 2 + (y1 - py) ** 2) / 22500) : 0;
      const dry = i >= seg.fallFrom ? 1 - seg.spent : 1;
      const a = Math.min(1, (0.13 + 0.87 * shown ** 1.4) * keep + 0.9 * reveal + 0.75 * flash) * (1 - 0.55 * under[i]) * dry;
      if (a < 0.02) continue;
      const k = Math.min(7, Math.floor(a * 8));
      buckets[k].moveTo(x0, y0 - sy);
      buckets[k].lineTo(x1, y1 - sy);
      used[k] = 1;
    }
    const y0 = pts[0][1] - sy;
    const y1 = pts[pts.length - 1][1] - sy;
    const grad = ctx.createLinearGradient(0, y0, 0, Math.max(y0 + 1, y1));
    grad.addColorStop(0, rgba(seg.a.color, 1));
    grad.addColorStop(0.3, rgba(seg.a.color, 1));
    grad.addColorStop(0.7, rgba(seg.b.color, 1));
    grad.addColorStop(1, rgba(seg.b.color, 1));
    ctx.globalCompositeOperation = "lighter";
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = grad;
    for (let k = 0; k < 8; k += 1) {
      if (!used[k]) continue;
      const a = (k + 0.5) / 8;
      ctx.globalAlpha = a * 0.12;
      ctx.lineWidth = 28 * s;
      ctx.stroke(buckets[k]);
      ctx.globalAlpha = a * 0.34;
      ctx.lineWidth = 11 * s;
      ctx.stroke(buckets[k]);
      ctx.globalAlpha = a * 0.92;
      ctx.lineWidth = 4.2 * s;
      ctx.stroke(buckets[k]);
    }
    // The prism potion splits into its spectrum under the pointer.
    if (near && near.seg === seg && kindAt(seg, cum[near.i]).kind === "prism") {
      const bands = spectrum.map(() => new Path2D());
      for (let i = Math.max(1, near.i - 30); i <= Math.min(end, near.i + 30); i += 1) {
        const [xa, ya] = pts[i - 1];
        const [xb, yb] = pts[i];
        const len = Math.hypot(xb - xa, yb - ya) || 1;
        const prox = Math.exp(-((xb - px) ** 2 + (yb - py) ** 2) / 12100);
        bands.forEach((band, k) => {
          const off = (k - 3) * 3.4 * prox;
          band.moveTo(xa + (-(yb - ya) / len) * off, ya - sy + ((xb - xa) / len) * off);
          band.lineTo(xb + (-(yb - ya) / len) * off, yb - sy + ((xb - xa) / len) * off);
        });
      }
      ctx.lineWidth = 1.6;
      ctx.globalAlpha = 0.8;
      bands.forEach((band, k) => {
        ctx.strokeStyle = rgba(spectrum[k], 1);
        ctx.stroke(band);
      });
    }
    if (!animate) {
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      return;
    }
    // Light travelling down the stream, and the glow of its front.
    const t = now / 1000;
    for (let u = (t * 140) % 110; u < fill; u += 110) {
      const [x, y] = pointAt(seg, u);
      if (y < lo || y > hi) continue;
      const i = indexAt(seg, u);
      const shown = Math.max(1 - u / 300, Math.exp(-(fill - u) / 220));
      const reveal = reach ? Math.exp(-((x - px) ** 2 + (y - py) ** 2) / 22500) : 0;
      const a = Math.min(1, (0.1 + 0.9 * shown) * keep + reveal + 0.7 * flash) * (1 - 0.6 * under[i]) * (i >= seg.fallFrom ? 1 - seg.spent : 1);
      ctx.globalAlpha = a * 0.5;
      ctx.drawImage(glowOf(mix(colorAt(seg, u), ink, 0.5)), x - 9 * s, y - sy - 9 * s, 18 * s, 18 * s);
    }
    if (!full) {
      const [hx, hy] = pointAt(seg, fill);
      const color = colorAt(seg, fill);
      ctx.globalAlpha = 0.9;
      const r = 26 * s;
      ctx.drawImage(glowOf(color), hx - r, hy - sy - r, r * 2, r * 2);
      ctx.drawImage(white, hx - 5 * s, hy - sy - 5 * s, 10 * s, 10 * s);
    } else if (seg.b.level < 0.98) {
      // Pouring into the next bottle: a splash at its mouth.
      const [mx, my] = pts[pts.length - 1];
      ctx.fillStyle = rgba(seg.b.color, 0.85);
      for (let i = 0; i < 6; i += 1) {
        const p = (t * 2.4 + i / 6) % 1;
        const side = i % 2 ? 1 : -1;
        ctx.globalAlpha = 1 - p;
        ctx.beginPath();
        ctx.arc(mx + side * p * 12 * s, my - sy - Math.sin(p * Math.PI) * 10 * s, 1.5 * s, 0, TAU);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
  }

  function drawLid(b, now) {
    const o = b.lid * b.lid * (3 - 2 * b.lid);
    const s = b.s;
    const bob = Math.sin(now * 0.004 + b.k) * 1.5 * s * o;
    ctx.save();
    ctx.translate(-b.dir * 12 * s * o, -b.h / 2 - 20 * s * o + bob);
    ctx.rotate(-b.dir * 0.65 * o);
    const nw = b.neck;
    if (b.shape === "erlenmeyer") {
      // A ground-glass stopper with a round knob.
      ctx.fillStyle = rgba(moon, 0.2);
      ctx.strokeStyle = rgba(moon, 0.95);
      ctx.lineWidth = 1.4 * s;
      ctx.beginPath();
      ctx.rect(-nw * 0.42, -2 * s, nw * 0.84, 9 * s);
      ctx.fill();
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(0, -7 * s, 6 * s, 0, TAU);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = rgba(ink, 0.7);
      ctx.beginPath();
      ctx.arc(-2 * s, -9 * s, 1.6 * s, 0, TAU);
      ctx.fill();
    } else if (b.shape === "round") {
      // A brass cap.
      ctx.fillStyle = rgba(brass, 1);
      ctx.fillRect(-nw * 0.62, -6 * s, nw * 1.24, 10 * s);
      ctx.fillStyle = rgba(gold, 1);
      ctx.fillRect(-nw * 0.62, -6 * s, nw * 1.24, 2.2 * s);
    } else {
      // A cork.
      ctx.fillStyle = rgba(mix(brass, ember, 0.25), 1);
      ctx.beginPath();
      ctx.moveTo(-nw * 0.58, -9 * s);
      ctx.lineTo(nw * 0.58, -9 * s);
      ctx.lineTo(nw * 0.44, 6 * s);
      ctx.lineTo(-nw * 0.44, 6 * s);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = rgba(mix(brass, ink, 0.35), 1);
      ctx.fillRect(-nw * 0.58, -9 * s, nw * 1.16, 2 * s);
    }
    ctx.restore();
  }

  function drawBottle(b, now, sy, animate) {
    const t = now / 1000;
    const out = segments[b.k];
    const drained = out ? Math.min(1, out.fill / (out.L || 1)) : 0;
    const level = b.level * (1 - 0.7 * drained);
    const flash = Math.max(0, 1 - (now - b.flash) / 520);
    const burst = Math.max(0, 1 - (now - b.burstAt) / 900);
    const color = liquidColor(b, now);
    ctx.save();
    ctx.translate(b.x, b.y - sy);
    ctx.rotate(b.tilt);
    // The potion's light, stronger the fuller it is, when touched or struck.
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha = Math.min(1, 0.16 + 0.34 * level + 0.6 * burst + 0.8 * flash + (b.hover ? 0.3 : 0));
    const gr = b.w * (1.5 + burst * 0.8 + flash * 0.7 + (b.hover ? 0.25 : 0));
    ctx.drawImage(glowOf(color), -gr, -gr * 0.9, gr * 2, gr * 2);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.fillStyle = rgba(night, 0.6);
    ctx.fill(b.outline);
    if (level > 0.01) {
      ctx.save();
      ctx.clip(b.outline);
      const bottom = b.h / 2;
      const surface = bottom - level * (bottom - b.fillTop);
      const wave = animate ? (b.pouring || b.hover ? 2.6 : 1.1) * b.s : 0;
      const grad = ctx.createLinearGradient(0, surface, 0, bottom);
      grad.addColorStop(0, rgba(mix(color, ink, 0.35 + 0.3 * flash), 0.95));
      grad.addColorStop(1, rgba(mix(color, night, 0.25), 0.95));
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(-b.w, bottom + 2);
      for (let x = -b.w; x <= b.w; x += 4) ctx.lineTo(x, surface + Math.sin(x * 0.25 + t * 4) * wave);
      ctx.lineTo(b.w, bottom + 2);
      ctx.fill();
      if (animate) {
        ctx.fillStyle = rgba(ink, 0.6);
        const n = b.pouring || b.hover || burst > 0 ? 7 : 3;
        for (let i = 0; i < n; i += 1) {
          const p = (t * (0.35 + (i % 3) * 0.12) + i / n) % 1;
          ctx.beginPath();
          ctx.arc(Math.sin(i * 2.3 + t) * b.neck * 0.8, bottom - p * (bottom - surface), (0.8 + (i % 2)) * b.s, 0, TAU);
          ctx.fill();
        }
      }
      ctx.restore();
    }
    ctx.lineWidth = 1.8 * b.s;
    ctx.strokeStyle = rgba(moon, 0.62 + 0.38 * flash);
    ctx.stroke(b.outline);
    if (flash > 0) {
      // Lightning catches the glass.
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = flash;
      ctx.strokeStyle = rgba(ink, 1);
      ctx.lineWidth = 1.4 * b.s;
      ctx.stroke(b.outline);
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 1;
    }
    ctx.strokeStyle = rgba(ink, 0.35 + 0.4 * flash);
    ctx.lineWidth = 1.2 * b.s;
    ctx.beginPath();
    ctx.moveTo(-b.w * 0.28, b.h * 0.05);
    ctx.quadraticCurveTo(-b.w * 0.36, b.h * 0.25, -b.w * 0.22, b.h * 0.36);
    ctx.stroke();
    ctx.strokeStyle = rgba(moon, 0.8);
    ctx.lineWidth = 2 * b.s;
    ctx.beginPath();
    ctx.moveTo(-b.neck / 2 - 2 * b.s, -b.h / 2);
    ctx.lineTo(b.neck / 2 + 2 * b.s, -b.h / 2);
    ctx.stroke();
    drawLid(b, now);
    ctx.restore();
  }

  let lastNear = 0;
  const nearAt = {};
  function draw(now, dt = 16) {
    const animate = motionOn();
    step(now, dt, animate);
    const { w, h, dpr } = view;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, w, h);
    api.bottles = [];
    api.head = null;
    if (covered()) return;
    const sy = window.scrollY;
    const lo = sy - 120;
    const hi = sy + h + 120;
    const visible = segments.filter((seg) => seg.fill > 1 && seg.maxY >= lo && seg.minY <= hi);
    const near = animate ? nearStream(sy) : null;
    if (animate) {
      // The potion thins into mist as it runs, drifting off into the night.
      for (const seg of visible) {
        if (mist.length >= cap || Math.random() > (dt / 1000) * 16) continue;
        const u = rand(0, seg.fill);
        const [x, y] = pointAt(seg, u);
        if (y < sy || y > sy + h) continue;
        add(mist, P("mist", x + rand(-6, 6), y, { vx: rand(-0.012, 0.012), vy: rand(-0.018, -0.006), r0: 6 * seg.a.s, r1: 46 * seg.a.s, a: 0.13, life: rand(2600, 4200), color: colorAt(seg, u) }));
      }
      drawParticles(ctx, mist, now, dt, sy);
    }
    for (const seg of visible) drawStream(seg, now, sy, near, animate);
    for (const b of bottles) {
      if (b.y + b.h < lo || b.y - b.h > hi) continue;
      drawBottle(b, now, sy, animate);
      api.bottles.push({ k: b.k, x: b.x, y: b.y - sy, w: b.w, h: b.h, color: b.color });
    }
    if (!animate) return;
    // Along the stream, each potion answers the pointer in its own way.
    if (near && now - lastNear > 50) {
      lastNear = now;
      const owner = kindAt(near.seg, near.seg.cum[near.i]);
      const effect = EFFECTS[owner.kind];
      if (now - (nearAt[owner.kind] || 0) > effect.nearRate) {
        nearAt[owner.kind] = now;
        effect.near(near.x, near.y, colorAt(near.seg, near.seg.cum[near.i]), now);
      }
    }
    drawParticles(ctx, backFx, now, dt, sy);
    for (const seg of visible) {
      if (seg.fill >= seg.L - 0.5) continue;
      const [x, y] = pointAt(seg, seg.fill);
      if (y >= sy && y <= sy + h) api.head = { x, y: y - sy, color: colorAt(seg, seg.fill), flowing: now - seg.flowing < 160 };
    }
    if (!api.head) {
      for (const b of api.bottles) {
        if (b.y < 0 || b.y > h) continue;
        if (!api.head || Math.abs(b.y - h * READ) < Math.abs(api.head.y - h * READ)) api.head = { x: b.x, y: b.y, color: b.color, flowing: false };
      }
    }
  }

  // Click bursts are drawn over the page, in the pointer's light.
  addPainter((g, now, dt) => {
    if (!frontFx.length) return false;
    drawParticles(g, frontFx, now, dt, window.scrollY);
    return frontFx.length > 0;
  });

  api.light = (k) => {
    if (bottles[k]) bottles[k].flash = performance.now();
  };
  api.flash = () => {
    flashAt = performance.now();
  };

  window.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse") return;
      pointer.x = event.clientX;
      pointer.y = event.clientY;
      pointer.on = true;
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => (pointer.on = false));
  // Capture phase, so the lantern and the lightning can tell a click on a bottle apart.
  document.addEventListener(
    "pointerdown",
    (event) => {
      if (event.button !== 0 || event.target.closest?.(ACTIVE)) return;
      const k = bottleAt(event.clientX, event.clientY + window.scrollY);
      if (k < 0) return;
      event.scBottle = k;
      if (!motionOn()) return;
      const b = bottles[k];
      const now = performance.now();
      b.openUntil = now + 1600;
      b.burstAt = now;
      EFFECTS[b.kind].click(b, now);
      wakeLight();
    },
    true,
  );

  let stop = null;
  const run = () => {
    stop?.();
    stop = null;
    if (motionOn()) {
      stop = addTicker((now, dt) => {
        draw(now, dt);
        return true;
      });
    } else {
      mist.length = 0;
      backFx.length = 0;
      frontFx.length = 0;
      draw(performance.now());
    }
  };

  layout();
  // Relayout waits for idle time: measuring the page mid-scroll would cost a frame.
  let queued = false;
  const idle = window.requestIdleCallback ? (fn) => window.requestIdleCallback(fn, { timeout: 600 }) : (fn) => setTimeout(fn, 120);
  const relayout = () => {
    if (queued) return;
    queued = true;
    idle(() => {
      queued = false;
      layout();
      if (!motionOn()) draw(performance.now());
    });
  };
  window.addEventListener("resize", relayout);
  window.addEventListener("load", relayout);
  if ("ResizeObserver" in window) new ResizeObserver(relayout).observe(document.body);
  onScroll(() => {
    if (!motionOn()) draw(performance.now());
  });
  document.addEventListener("sc:motionchange", run);
  run();
}
