import { finePointer, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { addPainter, wakeLight } from "./light.js";
import { TAU, rgba, sprite } from "./kit.js";

// The prism trail. The pointer drags a beam of white light that disperses into the
// spectrum behind it: a slow hand keeps a tight beam, a quick one fans it into a
// rainbow, and glints shed from the beam. Drawn in the pointer's light (light.js).
const TRAIL_MS = 640;
const BUCKETS = 8; // strokes are batched by brightness, per colour band

function catmull(p0, p1, p2, p3, t) {
  const t2 = t * t;
  const t3 = t2 * t;
  const f = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
  return [f(p0.x, p1.x, p2.x, p3.x), f(p0.y, p1.y, p2.y, p3.y), p1.t + (p2.t - p1.t) * t, p1.v + (p2.v - p1.v) * t];
}

function glintSprite(rgb) {
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, rgba(rgb, 1));
  grad.addColorStop(0.12, rgba(rgb, 0.7));
  grad.addColorStop(1, rgba(rgb, 0));
  g.fillStyle = grad;
  g.beginPath();
  for (let i = 0; i < 8; i += 1) {
    const a = (i / 8) * TAU;
    const r = i % 2 ? 4 : 32;
    g.lineTo(32 + Math.cos(a) * r, 32 + Math.sin(a) * r);
  }
  g.fill();
  return c;
}

export function initTrail() {
  if (!finePointer.matches) return;
  const root = document.documentElement;
  const bands = [1, 2, 3, 4, 5, 6, 7].map((n) => rgba(tokenRgb(`--color-spectrum-${n}`), 1));
  const light = tokenRgb("--color-ink");
  const white = rgba(light, 1);
  const head = sprite(light, 96);
  const glint = glintSprite(light);
  const haloes = [1, 2, 3, 4, 5, 6, 7].map((n) => sprite(tokenRgb(`--color-spectrum-${n}`), 32));
  const trail = [];
  const glints = [];
  const pen = { x: -1e4, y: -1e4, on: false, travel: 0, last: 0 };

  addPainter((g, now, dt) => {
    g.lineCap = "round";
    g.lineJoin = "round";
    while (trail.length && now - trail[0].t > TRAIL_MS) trail.shift();

    if (trail.length > 1) {
      // Smooth the raw samples, then fan each colour band out along the normal.
      const pts = [];
      for (let i = 0; i < trail.length - 1; i += 1) {
        const p1 = trail[i];
        const p2 = trail[i + 1];
        const pieces = Math.max(1, Math.min(8, Math.ceil(Math.hypot(p2.x - p1.x, p2.y - p1.y) / 7)));
        for (let k = 0; k < pieces; k += 1) pts.push(catmull(trail[Math.max(0, i - 1)], p1, p2, trail[Math.min(trail.length - 1, i + 2)], k / pieces));
      }
      const last = trail[trail.length - 1];
      pts.push([last.x, last.y, last.t, last.v]);
      const n = pts.length;
      const nx = new Float32Array(n);
      const ny = new Float32Array(n);
      const age = new Float32Array(n);
      const spread = new Float32Array(n);
      for (let i = 0; i < n; i += 1) {
        const a = pts[Math.max(0, i - 1)];
        const b = pts[Math.min(n - 1, i + 1)];
        const len = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
        nx[i] = -(b[1] - a[1]) / len;
        ny[i] = (b[0] - a[0]) / len;
        age[i] = Math.min(1, (now - pts[i][2]) / TRAIL_MS);
        spread[i] = age[i] ** 1.15 * (5 + Math.min(pts[i][3], 4) * 15);
      }
      bands.forEach((color, band) => {
        const offset = (band - 3) / 3;
        const paths = Array.from({ length: BUCKETS }, () => new Path2D());
        const used = new Uint8Array(BUCKETS);
        for (let i = 1; i < n; i += 1) {
          const bucket = Math.min(BUCKETS - 1, Math.floor((1 - age[i]) ** 1.4 * BUCKETS));
          paths[bucket].moveTo(pts[i - 1][0] + nx[i - 1] * spread[i - 1] * offset, pts[i - 1][1] + ny[i - 1] * spread[i - 1] * offset);
          paths[bucket].lineTo(pts[i][0] + nx[i] * spread[i] * offset, pts[i][1] + ny[i] * spread[i] * offset);
          used[bucket] = 1;
        }
        g.strokeStyle = color;
        for (let b = 0; b < BUCKETS; b += 1) {
          if (!used[b]) continue;
          g.globalAlpha = ((b + 0.5) / BUCKETS) * 0.55;
          g.lineWidth = 1 + (b / BUCKETS) * 2.6;
          g.stroke(paths[b]);
        }
      });
      // The undivided white core near the head.
      const core = new Path2D();
      for (let i = 1; i < n; i += 1) {
        if (age[i] > 0.32) continue;
        core.moveTo(pts[i - 1][0], pts[i - 1][1]);
        core.lineTo(pts[i][0], pts[i][1]);
      }
      g.globalAlpha = 0.7;
      g.strokeStyle = white;
      g.lineWidth = 2.2;
      g.stroke(core);
    }

    if (pen.on && now - pen.last < TRAIL_MS) {
      g.globalAlpha = 0.8 * (1 - (now - pen.last) / TRAIL_MS);
      g.drawImage(head, pen.x - 15, pen.y - 15, 30, 30);
    }

    for (let i = glints.length - 1; i >= 0; i -= 1) {
      const s = glints[i];
      const life = (now - s.t) / s.life;
      if (life >= 1) {
        glints.splice(i, 1);
        continue;
      }
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      const size = s.size * (1 - life * 0.5);
      g.globalAlpha = Math.sin(life * Math.PI) * 0.9;
      g.drawImage(glint, s.x - size / 2, s.y - size / 2, size, size);
      g.globalAlpha *= 0.6;
      g.drawImage(s.halo, s.x - size, s.y - size, size * 2, size * 2);
    }
    return trail.length > 0 || glints.length > 0;
  });

  window.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !motionOn()) return;
      const now = performance.now();
      const prev = trail[trail.length - 1];
      const dist = prev ? Math.hypot(event.clientX - prev.x, event.clientY - prev.y) : 0;
      const speed = prev ? dist / Math.max(4, now - pen.last) : 0; // px per ms
      trail.push({ x: event.clientX, y: event.clientY, t: now, v: prev ? prev.v * 0.6 + speed * 0.4 : 0 });
      if (trail.length > 90) trail.shift();
      pen.x = event.clientX;
      pen.y = event.clientY;
      pen.on = true;
      pen.last = now;
      pen.travel += dist;
      if (pen.travel > 34 && glints.length < 70) {
        pen.travel = 0;
        glints.push({
          x: event.clientX + (Math.random() - 0.5) * 16,
          y: event.clientY + (Math.random() - 0.5) * 16,
          vx: (Math.random() - 0.5) * 0.03,
          vy: 0.01 + Math.random() * 0.02,
          size: 7 + Math.random() * 9,
          t: now,
          life: 600 + Math.random() * 500,
          halo: haloes[Math.floor(Math.random() * haloes.length)],
        });
      }
      wakeLight();
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => (pen.on = false));
  document.addEventListener("sc:motionchange", () => {
    if (motionOn()) return;
    trail.length = 0;
    glints.length = 0;
  });
}
