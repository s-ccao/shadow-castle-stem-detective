import { addTicker, onScroll, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { TAU, heroCovers, lowPower, rgba, skyLayer, sprite } from "./kit.js";
import { CASES } from "./castles.js";

// The potion chain. A bottle stands in the margin at the start of every chapter; a
// glass tube runs from its tap down the page, across the gap between chapters and
// into the next bottle's mouth. The potion follows the reader: as the reading line
// moves down, it flows out of one bottle, along the tube, and fills the next, turning
// that bottle's colour on the way (each bottle holds one case's colour). Scrolling
// fast makes it rush. Smoke rises from the full bottles.
const READ = 0.62; // the reading line, as a share of the screen height
const FLOW = 1100; // px per second, faster when it has a long way to catch up
const SHAPES = ["flask", "erlenmeyer", "vial", "round"];

let head = null;
// Where the potion is flowing now, in viewport coordinates, for lightning (runes.js).
export function potionHead() {
  return head;
}

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
  // vial: a test tube with a round foot
  const r = nw / 2;
  outline.moveTo(-r, top);
  outline.lineTo(-r, h / 2 - r);
  outline.arc(0, h / 2 - r, r, Math.PI, 0, true);
  outline.lineTo(r, top);
  return { outline, fillTop: top + h * 0.16, neck: nw };
}

export function initPotion() {
  const chapters = [...document.querySelectorAll("main > section")].filter((el) => !el.matches(".hub-hero, .hero"));
  if (chapters.length < 2) return;
  const canvas = skyLayer("potion");
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const moon = tokenRgb("--color-moon");
  const night = tokenRgb("--color-night");
  const brass = tokenRgb("--color-bronze");
  const ink = tokenRgb("--color-ink");
  const pageCase = document.querySelector("main[data-case]")?.dataset.case;
  const first = Math.max(0, CASES.indexOf(pageCase));
  const colorOf = (k) => tokenRgb(`--game-${CASES[(first + k) % CASES.length]}`);
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
  const smoke = [];

  function layout() {
    const dpr = Math.min(window.devicePixelRatio || 1, lowPower ? 1 : 1.5);
    view = { w: window.innerWidth, h: window.innerHeight, dpr };
    canvas.width = Math.round(view.w * dpr);
    canvas.height = Math.round(view.h * dpr);
    const sy = window.scrollY;
    const narrow = view.w < 700;
    const items = chapters.map((el) => {
      const box = el.getBoundingClientRect();
      let left = Infinity;
      let right = -Infinity;
      let top = Infinity;
      let bottom = -Infinity;
      for (const child of el.children) {
        if (child.getAttribute("aria-hidden") === "true") continue;
        const r = child.getBoundingClientRect();
        if (!r.width || !r.height) continue;
        left = Math.min(left, r.left);
        right = Math.max(right, r.right);
        top = Math.min(top, r.top);
        bottom = Math.max(bottom, r.bottom);
      }
      if (!Number.isFinite(left)) {
        left = box.left + 16;
        right = box.right - 16;
        top = box.top;
        bottom = box.bottom;
      }
      return { top: box.top + sy, cTop: top + sy, cBottom: bottom + sy, gl: Math.max(0, left), gr: Math.max(0, view.w - right) };
    });
    // On wide screens the case-file dock is a tab on the right edge: keep clear of it.
    const dock = matchMedia("(min-width: 60rem)").matches ? document.querySelector(".case-dock") : null;
    const dockW = dock ? dock.offsetWidth + 6 : 0;
    const old = bottles;
    bottles = items.map((it, k) => {
      const room = { [-1]: it.gl, 1: it.gr - dockW };
      // Phones keep everything in the right margin, where ragged lines leave room.
      let side = narrow ? 1 : k % 2 === 0 ? -1 : 1;
      if (room[side] < 40 && room[-side] > room[side]) side = -side;
      const gutter = Math.max(0, room[side]);
      const s = Math.min(1.45, Math.max(narrow ? 0.34 : 0.5, gutter / 64));
      const w = 60 * s;
      const h = 92 * s;
      const inset = Math.max(w / 2 + 2, gutter / 2);
      const x = side < 0 ? inset : view.w - dockW - inset;
      const y = Math.max(it.top + h * 0.5 + 24 * s, it.cTop + h * 0.45);
      return {
        x,
        y,
        w,
        h,
        s,
        color: colorOf(k),
        ...bottleShape(SHAPES[k % SHAPES.length], w, h),
        level: old[k]?.level ?? (k === 0 ? 1 : 0),
        burstAt: old[k]?.burstAt ?? -1e9,
        nextSmoke: 0,
      };
    });
    const oldSegments = segments;
    segments = [];
    for (let k = 0; k < bottles.length - 1; k += 1) {
      const a = bottles[k];
      const b = bottles[k + 1];
      const start = [a.x, a.y + a.h / 2 + 9 * a.s];
      const end = [b.x, b.y - b.h / 2 - 16 * b.s];
      const pts = [start];
      if (end[1] - start[1] > 60) {
        const gap = Math.min(Math.max((items[k].cBottom + items[k + 1].cTop) / 2, start[1] + 24), end[1] - 24);
        pts.push([a.x, gap]);
        if (Math.abs(b.x - a.x) > 0.5) pts.push([b.x, gap]);
      } else if (Math.abs(b.x - a.x) > 0.5) {
        pts.push([b.x, start[1]]);
      }
      pts.push(end);
      const cum = [0];
      for (let i = 1; i < pts.length; i += 1) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
      const L = cum[cum.length - 1];
      const before = oldSegments[k];
      segments.push({ k, pts, cum, L, a, b, fill: before ? Math.min(L, (before.fill / (before.L || 1)) * L) : 0, flowing: 0 });
    }
  }

  // How much of a segment lies above the reading line: the liquid's goal.
  function goal(seg, line) {
    let len = 0;
    for (let i = 1; i < seg.pts.length; i += 1) {
      const [, y0] = seg.pts[i - 1];
      const [, y1] = seg.pts[i];
      const piece = seg.cum[i] - seg.cum[i - 1];
      if (Math.abs(y1 - y0) < 0.5) {
        if (line >= y0) len += piece;
        else break;
        continue;
      }
      if (line >= y1) {
        len += piece;
        continue;
      }
      if (line > y0) len += (piece * (line - y0)) / (y1 - y0);
      break;
    }
    return len;
  }

  function pointAt(seg, len) {
    for (let i = 1; i < seg.pts.length; i += 1) {
      if (len <= seg.cum[i] || i === seg.pts.length - 1) {
        const piece = seg.cum[i] - seg.cum[i - 1] || 1;
        const f = Math.min(1, Math.max(0, (len - seg.cum[i - 1]) / piece));
        return [seg.pts[i - 1][0] + (seg.pts[i][0] - seg.pts[i - 1][0]) * f, seg.pts[i - 1][1] + (seg.pts[i][1] - seg.pts[i - 1][1]) * f];
      }
    }
    return seg.pts[seg.pts.length - 1];
  }

  const mix = (a, b, f) => a.map((v, i) => Math.round(v + (b[i] - v) * f));

  function step(now, dt, animate) {
    const line = window.scrollY + view.h * READ;
    for (const seg of segments) {
      const target = goal(seg, line);
      if (!animate) {
        seg.fill = target;
        continue;
      }
      const diff = target - seg.fill;
      const speed = Math.max(FLOW, Math.abs(diff) * 3);
      const move = Math.sign(diff) * Math.min(Math.abs(diff), (speed * dt) / 1000);
      seg.fill += move;
      if (Math.abs(move) > 0.15) seg.flowing = now;
    }
    bottles.forEach((b, k) => {
      const inflow = segments[k - 1];
      const want = k === 0 ? 1 : inflow && inflow.fill >= inflow.L - 1 ? 1 : 0;
      if (want === 1 && b.level < 0.02 && want !== b.want) b.burstAt = now;
      b.want = want;
      b.level = animate ? b.level + Math.sign(want - b.level) * Math.min(Math.abs(want - b.level), dt / 900) : want;
    });
    // The head: where the potion is travelling now, else the bottle nearest the line.
    head = null;
    const sy = window.scrollY;
    for (const seg of segments) {
      if (seg.fill <= 0.5 || seg.fill >= seg.L - 0.5) continue;
      const [x, y] = pointAt(seg, seg.fill);
      const f = Math.min(1, Math.max(0, (y - seg.pts[0][1]) / (seg.pts[seg.pts.length - 1][1] - seg.pts[0][1] || 1)));
      head = { x, y: y - sy, color: mix(seg.a.color, seg.b.color, f), flowing: now - seg.flowing < 160 };
    }
    if (!head) {
      let best = null;
      for (const b of bottles) {
        const y = b.y - sy;
        if (y < 0 || y > view.h) continue;
        if (!best || Math.abs(y - view.h * READ) < Math.abs(best.y - view.h * READ)) best = { x: b.x, y, color: b.color, flowing: false };
      }
      head = best;
    }
  }

  function drawTube(seg, sy) {
    const path = new Path2D();
    seg.pts.forEach(([x, y], i) => (i ? path.lineTo(x, y - sy) : path.moveTo(x, y - sy)));
    const s = (seg.a.s + seg.b.s) / 2;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.strokeStyle = rgba(moon, 0.16);
    ctx.lineWidth = 10 * s;
    ctx.stroke(path);
    ctx.strokeStyle = rgba(night, 0.7);
    ctx.lineWidth = 6.5 * s;
    ctx.stroke(path);
    if (seg.fill <= 0.5) return;
    // The liquid, shading from this bottle's colour to the next one's.
    const filled = new Path2D();
    filled.moveTo(seg.pts[0][0], seg.pts[0][1] - sy);
    for (let i = 1; i < seg.pts.length; i += 1) {
      if (seg.fill >= seg.cum[i]) {
        filled.lineTo(seg.pts[i][0], seg.pts[i][1] - sy);
        continue;
      }
      const [x, y] = pointAt(seg, seg.fill);
      filled.lineTo(x, y - sy);
      break;
    }
    const y0 = seg.pts[0][1] - sy;
    const y1 = seg.pts[seg.pts.length - 1][1] - sy;
    const grad = ctx.createLinearGradient(0, y0, 0, Math.max(y0 + 1, y1));
    grad.addColorStop(0, rgba(seg.a.color, 1));
    grad.addColorStop(1, rgba(seg.b.color, 1));
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha = 0.22;
    ctx.strokeStyle = grad;
    ctx.lineWidth = 14 * s;
    ctx.stroke(filled);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 0.95;
    ctx.lineWidth = 4.2 * s;
    ctx.stroke(filled);
    ctx.globalAlpha = 1;
  }

  function drawFlow(seg, now, sy) {
    const s = (seg.a.s + seg.b.s) / 2;
    const t = now / 1000;
    const full = seg.fill >= seg.L - 0.5;
    if (!full && seg.fill > 0.5) {
      const [hx, hy] = pointAt(seg, seg.fill);
      const color = mix(seg.a.color, seg.b.color, Math.min(1, Math.max(0, (hy - seg.pts[0][1]) / (seg.pts[seg.pts.length - 1][1] - seg.pts[0][1] || 1))));
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = 0.85;
      const r = 18 * s;
      ctx.drawImage(glowOf(color), hx - r, hy - sy - r, r * 2, r * 2);
      ctx.globalAlpha = 0.9;
      ctx.drawImage(white, hx - 4 * s, hy - sy - 4 * s, 8 * s, 8 * s);
      ctx.globalCompositeOperation = "source-over";
    }
    // Bubbles riding the liquid towards its head.
    if (seg.fill > 20 && now - seg.flowing < 1400) {
      ctx.fillStyle = rgba(ink, 0.55);
      const span = Math.min(seg.fill, 320);
      for (let i = 0; i < 6; i += 1) {
        const at = seg.fill - ((t * 140 + i * 53) % span);
        const [bx, by] = pointAt(seg, at);
        ctx.beginPath();
        ctx.arc(bx + Math.sin(t * 9 + i) * 0.8, by - sy, 1.3 * s, 0, TAU);
        ctx.fill();
      }
    }
    // Pouring into the next bottle: a falling stream and a splash.
    if (full && seg.b.level < 0.98) {
      const b = seg.b;
      const [ex, ey] = seg.pts[seg.pts.length - 1];
      const surface = b.y + b.h / 2 - b.level * (b.h / 2 - b.fillTop);
      const grad = ctx.createLinearGradient(0, ey - sy, 0, surface - sy);
      grad.addColorStop(0, rgba(seg.b.color, 0.95));
      grad.addColorStop(1, rgba(seg.b.color, 0.6));
      ctx.strokeStyle = grad;
      ctx.lineWidth = 3 * s;
      ctx.beginPath();
      ctx.moveTo(ex, ey - sy);
      ctx.lineTo(ex + Math.sin(t * 14) * 0.6, surface - sy);
      ctx.stroke();
      ctx.fillStyle = rgba(seg.b.color, 0.8);
      for (let i = 0; i < 5; i += 1) {
        const p = (t * 2.2 + i / 5) % 1;
        const dir = i % 2 ? 1 : -1;
        ctx.beginPath();
        ctx.arc(ex + dir * p * 9 * s, surface - sy - Math.sin(p * Math.PI) * 8 * s, 1.2 * s * (1 - p), 0, TAU);
        ctx.fill();
      }
    }
  }

  function drawBottle(b, k, now, sy, animate) {
    const t = now / 1000;
    const out = segments[k];
    const draining = out && animate && now - out.flowing < 200 && out.fill < out.L - 0.5;
    const level = b.level * (1 - 0.6 * (out ? out.fill / (out.L || 1) : 0));
    const x = b.x;
    const y = b.y - sy;
    ctx.save();
    ctx.translate(x, y);
    if (draining) ctx.rotate(Math.sin(t * 7) * 0.04);

    // The case's light behind the glass, stronger the fuller it is.
    ctx.globalCompositeOperation = "lighter";
    const burst = Math.max(0, 1 - (now - b.burstAt) / 900);
    ctx.globalAlpha = 0.18 + 0.32 * level + 0.6 * burst;
    const gr = b.w * (1.3 + burst * 0.8);
    ctx.drawImage(glowOf(b.color), -gr, -gr * 0.9, gr * 2, gr * 2);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;

    // Glass, the potion inside it, bubbles, then the glass's edge and shine.
    ctx.fillStyle = rgba(night, 0.55);
    ctx.fill(b.outline);
    if (level > 0.01) {
      ctx.save();
      ctx.clip(b.outline);
      const bottom = b.h / 2;
      const surface = bottom - level * (bottom - b.fillTop);
      const wave = animate ? (draining ? 2.4 : 1.1) * b.s : 0;
      const grad = ctx.createLinearGradient(0, surface, 0, bottom);
      grad.addColorStop(0, rgba(mix(b.color, ink, 0.35), 0.95));
      grad.addColorStop(1, rgba(mix(b.color, night, 0.25), 0.95));
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(-b.w, bottom + 2);
      for (let px = -b.w; px <= b.w; px += 4) ctx.lineTo(px, surface + Math.sin(px * 0.25 + t * 4) * wave);
      ctx.lineTo(b.w, bottom + 2);
      ctx.fill();
      if (animate) {
        ctx.fillStyle = rgba(ink, 0.6);
        const n = draining || burst > 0 ? 7 : 3;
        for (let i = 0; i < n; i += 1) {
          const p = (t * (0.35 + (i % 3) * 0.12) + i / n) % 1;
          const by = bottom - p * (bottom - surface);
          ctx.beginPath();
          ctx.arc(Math.sin(i * 2.3 + t) * b.neck * 0.8, by, (0.8 + (i % 2)) * b.s, 0, TAU);
          ctx.fill();
        }
      }
      ctx.restore();
    }
    ctx.lineWidth = 1.6 * b.s;
    ctx.strokeStyle = rgba(moon, 0.7);
    ctx.stroke(b.outline);
    ctx.strokeStyle = rgba(ink, 0.35);
    ctx.lineWidth = 1.2 * b.s;
    ctx.beginPath();
    ctx.moveTo(-b.w * 0.28, b.h * 0.05);
    ctx.quadraticCurveTo(-b.w * 0.36, b.h * 0.25, -b.w * 0.22, b.h * 0.36);
    ctx.stroke();
    // A lip at the mouth and a brass tap at the foot.
    ctx.strokeStyle = rgba(moon, 0.8);
    ctx.lineWidth = 2 * b.s;
    ctx.beginPath();
    ctx.moveTo(-b.neck / 2 - 2 * b.s, -b.h / 2);
    ctx.lineTo(b.neck / 2 + 2 * b.s, -b.h / 2);
    ctx.stroke();
    if (out) {
      ctx.fillStyle = rgba(brass, 1);
      ctx.fillRect(-2 * b.s, b.h / 2 - 1, 4 * b.s, 9 * b.s);
      ctx.beginPath();
      ctx.arc(0, b.h / 2 + 4 * b.s, 3.2 * b.s, 0, TAU);
      ctx.fill();
    }
    ctx.restore();

    // Alchemical smoke from a full bottle's mouth.
    if (animate && level > 0.25 && now > b.nextSmoke && smoke.length < (lowPower ? 30 : 70)) {
      b.nextSmoke = now + 260 + Math.random() * 260;
      smoke.push({ x: b.x + (Math.random() - 0.5) * b.neck * 0.6, y: b.y - b.h / 2, vx: (Math.random() - 0.5) * 0.008, vy: -(0.018 + Math.random() * 0.018), r: 4 * b.s, t: now, life: 2200 + Math.random() * 1200, color: b.color, s: b.s });
    }
  }

  function draw(now, dt = 16) {
    const animate = motionOn();
    step(now, dt, animate);
    const { w, h, dpr } = view;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, w, h);
    if (covered()) return;
    const sy = window.scrollY;
    const lo = sy - 120;
    const hi = sy + h + 120;
    for (const seg of segments) {
      const top = seg.pts[0][1];
      const bottom = seg.pts[seg.pts.length - 1][1];
      if (bottom < lo || top > hi) continue;
      drawTube(seg, sy);
      if (animate) drawFlow(seg, now, sy);
    }
    bottles.forEach((b, k) => {
      if (b.y + b.h < lo || b.y - b.h > hi) return;
      drawBottle(b, k, now, sy, animate);
    });
    if (!animate) return;
    ctx.globalCompositeOperation = "lighter";
    for (let i = smoke.length - 1; i >= 0; i -= 1) {
      const p = smoke[i];
      const age = (now - p.t) / p.life;
      if (age >= 1) {
        smoke.splice(i, 1);
        continue;
      }
      p.x += p.vx * dt + Math.sin(now * 0.002 + i) * 0.05;
      p.y += p.vy * dt;
      const r = p.r * (1 + age * 3.5);
      ctx.globalAlpha = Math.sin(age * Math.PI) * 0.3;
      ctx.drawImage(glowOf(p.color), p.x - r, p.y - sy - r, r * 2, r * 2);
    }
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
  }

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
      smoke.length = 0;
      draw(performance.now());
    }
  };

  layout();
  let queued = false;
  const relayout = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
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
