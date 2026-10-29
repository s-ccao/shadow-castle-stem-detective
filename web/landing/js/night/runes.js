import { addTicker, finePointer, onScroll, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { addPainter, wakeLight } from "./light.js";
import { TAU, fit, heroCovers, lowPower, rgba, skyLayer, sprite } from "./kit.js";
import { flashPotion, lightBottle, potionBottles, potionHead } from "./potion.js";
import { castleSpires } from "./castles.js";

// Rune lightning. Faint brass circuitry with rune pads is etched into the walls behind
// every page. Lightning answers the scroll, up to eleven strikes a second (some fork to
// a second target), and the storm also strikes on its own every second or two,
// hitting a potion bottle, the flowing potion, a castle's spire or a rune; strikes
// light up the potion's whole stream for a moment; over a hero they strike the
// castle's windows. Moving the pointer throws lightning at the nearest bottle, which
// lights up, or at a rune; a click bursts into a ring of runes and a surge through the
// circuitry, or, on a bottle, draws lightning into it. Each bolt is a thin line with a
// small glow, far below the area that makes a flash hazardous.
const G = 88; // circuitry grid pitch, in CSS px
const RUNES = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ";
const RUNE_FONT = "'Apple Symbols', 'Segoe UI Historic', 'Noto Sans Runic', serif";
const STRIKE_GAP = 90; // ms between the scroll's strikes
const STREAM_FLASH_GAP = 300; // the potion's whole course lights at most about three times a second
const LIT_MS = 900;

function hash(i, j, salt) {
  let h = Math.imul(i + 0x9e37, 0x85ebca6b) ^ Math.imul(j + 0x7f4a, 0xc2b2ae35) ^ Math.imul(salt + 1, 0x27d4eb2f);
  h = Math.imul(h ^ (h >>> 15), 0x2c1b3c6d);
  h = Math.imul(h ^ (h >>> 12), 0x297a2d39);
  return ((h ^ (h >>> 15)) >>> 0) / 4294967296;
}

// A jagged path between two points: midpoints pushed sideways, less at each level.
function jag(x1, y1, x2, y2, rough, depth) {
  let pts = [[x1, y1], [x2, y2]];
  let offset = Math.hypot(x2 - x1, y2 - y1) * rough;
  for (let d = 0; d < depth; d += 1) {
    const next = [pts[0]];
    for (let i = 0; i < pts.length - 1; i += 1) {
      const [ax, ay] = pts[i];
      const [bx, by] = pts[i + 1];
      const len = Math.hypot(bx - ax, by - ay) || 1;
      const push = (Math.random() * 2 - 1) * offset;
      next.push([(ax + bx) / 2 + (-(by - ay) / len) * push, (ay + by) / 2 + ((bx - ax) / len) * push], pts[i + 1]);
    }
    pts = next;
    offset *= 0.55;
  }
  return pts;
}

const mix = (a, b, f) => a.map((v, i) => Math.round(v + (b[i] - v) * f));

export function initRunes() {
  const root = document.documentElement;
  const wall = skyLayer("runes");
  const wctx = wall.getContext("2d");
  if (!wctx) return;
  let view = fit(wall, lowPower ? 1 : 1.5);
  const covered = heroCovers();
  const brass = tokenRgb("--color-bronze");
  const gold = tokenRgb("--color-accent");
  const arcane = tokenRgb("--color-arcane");
  const moon = tokenRgb("--color-moon");
  const ink = tokenRgb("--color-ink");
  const glows = new Map();
  const glowOf = (rgb) => {
    const key = rgb.join(",");
    if (!glows.has(key)) glows.set(key, sprite(rgb, 64));
    return glows.get(key);
  };

  // ---------- the circuitry, fixed in document space ----------
  let cols = 0;
  let x0 = 0;
  const layout = () => {
    cols = Math.ceil(view.w / G) + 1;
    x0 = (view.w - (cols - 1) * G) / 2;
  };
  layout();
  const has = (i, j) => i >= 0 && i < cols && j >= 0 && hash(i, j, 1) < 0.5;
  const right = (i, j) => has(i, j) && has(i + 1, j) && hash(i, j, 2) < 0.55;
  const down = (i, j) => has(i, j) && has(i, j + 1) && hash(i, j, 3) < 0.45;
  const diag = (i, j) => has(i, j) && has(i + 1, j + 1) && !right(i, j) && hash(i, j, 4) < 0.28;
  const pad = (i, j) => has(i, j) && hash(i, j, 6) < 0.12;
  const px = (i) => x0 + i * G;
  const py = (j) => j * G + G / 2;
  const key = (i, j) => i * 100000 + j;
  const lit = new Map(); // node -> time it was energized

  function neighbours(i, j) {
    const out = [];
    if (right(i, j)) out.push([i + 1, j]);
    if (right(i - 1, j)) out.push([i - 1, j]);
    if (down(i, j)) out.push([i, j + 1]);
    if (down(i, j - 1)) out.push([i, j - 1]);
    if (diag(i, j)) out.push([i + 1, j + 1]);
    if (diag(i - 1, j - 1)) out.push([i - 1, j - 1]);
    return out;
  }

  function nearest(x, docY, radius, padsOnly) {
    let best = null;
    const i0 = Math.round((x - x0) / G);
    const j0 = Math.round((docY - G / 2) / G);
    const reach = Math.ceil(radius / G);
    for (let j = j0 - reach; j <= j0 + reach; j += 1) {
      for (let i = i0 - reach; i <= i0 + reach; i += 1) {
        if (!(padsOnly ? pad(i, j) : has(i, j))) continue;
        const d = Math.hypot(px(i) - x, py(j) - docY);
        if (d <= radius && (!best || d < best.d)) best = { i, j, d };
      }
    }
    return best;
  }

  function energize(x, docY, radius = 140) {
    const now = performance.now();
    const i0 = Math.round((x - x0) / G);
    const j0 = Math.round((docY - G / 2) / G);
    const reach = Math.ceil(radius / G);
    for (let j = j0 - reach; j <= j0 + reach; j += 1) {
      for (let i = i0 - reach; i <= i0 + reach; i += 1) {
        if (has(i, j) && Math.hypot(px(i) - x, py(j) - docY) <= radius) lit.set(key(i, j), now);
      }
    }
    kickWall();
  }

  // A click's surge: rings of the network light up one after another.
  const surges = [];
  function surge(x, docY) {
    const start = nearest(x, docY, 220, false);
    if (!start) return;
    const seen = new Set([key(start.i, start.j)]);
    const steps = [];
    let frontier = [[start.i, start.j]];
    for (let d = 0; d < 9 && frontier.length; d += 1) {
      const next = [];
      for (const [i, j] of frontier) {
        for (const [a, b] of neighbours(i, j)) {
          if (seen.has(key(a, b))) continue;
          seen.add(key(a, b));
          next.push([a, b]);
        }
      }
      steps.push(frontier);
      frontier = next;
    }
    surges.push({ t: performance.now(), steps });
    kickWall();
  }

  function drawWall(now) {
    const { w, h, dpr } = view;
    wctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    wctx.globalCompositeOperation = "source-over";
    wctx.globalAlpha = 1;
    wctx.clearRect(0, 0, w, h);
    if (covered()) return false;
    const sy = window.scrollY;
    const jTop = Math.floor((sy - G) / G);
    const jBottom = Math.ceil((sy + h + G) / G);
    for (let s = surges.length - 1; s >= 0; s -= 1) {
      const sg = surges[s];
      const step = Math.max(0, Math.floor((now - sg.t) / 60));
      if (step >= sg.steps.length + 15) {
        surges.splice(s, 1);
        continue;
      }
      const ring = sg.steps[Math.min(step, sg.steps.length - 1)];
      if (step < sg.steps.length) for (const [i, j] of ring) lit.set(key(i, j), now);
    }
    const base = new Path2D();
    const hot = new Path2D();
    const charge = (i, j) => Math.max(0, 1 - (now - (lit.get(key(i, j)) ?? -1e9)) / LIT_MS);
    const edge = (i, j, a, b) => {
      const xa = px(i);
      const ya = py(j) - sy;
      const xb = px(a);
      const yb = py(b) - sy;
      base.moveTo(xa, ya);
      base.lineTo(xb, yb);
      if (Math.min(charge(i, j), charge(a, b)) > 0.05) {
        hot.moveTo(xa, ya);
        hot.lineTo(xb, yb);
      }
    };
    for (let j = jTop; j <= jBottom; j += 1) {
      for (let i = 0; i < cols; i += 1) {
        if (!has(i, j)) continue;
        if (right(i, j)) edge(i, j, i + 1, j);
        if (down(i, j)) edge(i, j, i, j + 1);
        if (diag(i, j)) edge(i, j, i + 1, j + 1);
      }
    }
    wctx.lineCap = "round";
    wctx.strokeStyle = rgba(brass, 0.04);
    wctx.lineWidth = 1.1;
    wctx.stroke(base);
    let busy = false;
    wctx.globalCompositeOperation = "lighter";
    wctx.strokeStyle = rgba(arcane, 0.55);
    wctx.lineWidth = 1.8;
    wctx.stroke(hot);
    wctx.font = `13px ${RUNE_FONT}`;
    wctx.textAlign = "center";
    wctx.textBaseline = "middle";
    for (let j = jTop; j <= jBottom; j += 1) {
      for (let i = 0; i < cols; i += 1) {
        if (!has(i, j)) continue;
        const c = charge(i, j);
        if (c > 0) busy = true;
        const x = px(i);
        const y = py(j) - sy;
        if (pad(i, j)) {
          wctx.globalCompositeOperation = "source-over";
          wctx.strokeStyle = rgba(c > 0.05 ? gold : brass, 0.09 + c * 0.82);
          wctx.lineWidth = 1.1;
          wctx.beginPath();
          wctx.arc(x, y, 11, 0, TAU);
          wctx.stroke();
          wctx.fillStyle = rgba(c > 0.05 ? gold : brass, 0.12 + c * 0.88);
          wctx.fillText(RUNES[Math.floor(hash(i, j, 7) * RUNES.length)], x, y + 0.5);
          if (c > 0.05) {
            wctx.globalCompositeOperation = "lighter";
            wctx.globalAlpha = c * 0.8;
            wctx.drawImage(glowOf(gold), x - 30, y - 30, 60, 60);
            wctx.globalAlpha = 1;
          }
        } else if (c > 0.05) {
          wctx.globalCompositeOperation = "lighter";
          wctx.globalAlpha = c;
          wctx.drawImage(glowOf(moon), x - 8, y - 8, 16, 16);
          wctx.globalAlpha = 1;
        }
      }
    }
    for (const [k, time] of lit) if (now - time > LIT_MS) lit.delete(k);
    wctx.globalCompositeOperation = "lighter";
    const sky = paintBolts(wctx, back.bolts, now) | paintFlares(wctx, back.flares, now);
    wctx.globalCompositeOperation = "source-over";
    wctx.globalAlpha = 1;
    return busy || surges.length > 0 || sky > 0;
  }

  let stopWall = null;
  function kickWall() {
    if (stopWall || !motionOn()) return;
    stopWall = addTicker((now) => {
      let busy = false;
      try {
        busy = drawWall(now);
      } catch (error) {
        console.error(error); // stop cleanly, so the next strike can start it again
      }
      if (!busy) stopWall = null;
      return busy;
    });
  }

  // ---------- lightning ----------
  // The pointer's lightning is drawn over the page, in its light (light.js). The
  // scroll's strikes fall behind it, onto the castles and the potion, so text under
  // a strike stays readable; only over a hero, which hides the walls, do they strike
  // in front.
  const front = { bolts: [], flares: [] };
  const back = { bolts: [], flares: [] };
  const rings = [];

  function strike(x1, y1, x2, y2, o = {}) {
    const now = performance.now();
    const len = Math.hypot(x2 - x1, y2 - y1);
    const rough = o.rough ?? 0.2;
    const depth = len > 280 ? 6 : len > 90 ? 5 : 4;
    const main = jag(x1, y1, x2, y2, rough, depth);
    const branches = [];
    for (let b = 0; b < (o.branches ?? 2); b += 1) {
      const [bx, by] = main[Math.floor(main.length * (0.2 + Math.random() * 0.5))];
      const angle = Math.atan2(y2 - y1, x2 - x1) + (Math.random() < 0.5 ? -1 : 1) * (0.35 + Math.random() * 0.55);
      const reach = len * (0.16 + Math.random() * 0.26);
      branches.push(jag(bx, by, bx + Math.cos(angle) * reach, by + Math.sin(angle) * reach, 0.3, depth - 1));
    }
    const set = o.back ? back : front;
    set.bolts.push({ main, branches, ends: [x1, y1, x2, y2], rough, depth, t: now, life: o.life ?? 260, width: o.width ?? 1, color: o.color ?? arcane, again: false });
    if (o.rune !== false) set.flares.push({ x: x2, y: y2, t: now, glyph: RUNES[Math.floor(Math.random() * RUNES.length)], color: o.color ?? arcane, size: o.flare ?? 1 });
    if (!covered()) energize(x2, y2 + window.scrollY, o.reach ?? 140);
    if (o.back) kickWall();
    else wakeLight();
  }

  function strokeBolt(g, pts, width, alpha, color) {
    g.beginPath();
    pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y)));
    g.lineJoin = "round";
    g.lineCap = "round";
    g.strokeStyle = rgba(color, 1);
    g.globalAlpha = alpha * 0.2;
    g.lineWidth = 9 * width;
    g.stroke();
    g.globalAlpha = alpha * 0.55;
    g.lineWidth = 3.2 * width;
    g.stroke();
    g.strokeStyle = rgba(ink, 1);
    g.globalAlpha = alpha * 0.95;
    g.lineWidth = 1.3 * width;
    g.stroke();
  }

  function paintBolts(g, bolts, now) {
    for (let i = bolts.length - 1; i >= 0; i -= 1) {
      const b = bolts[i];
      const age = Math.max(0, (now - b.t) / b.life);
      if (age >= 1) {
        bolts.splice(i, 1);
        continue;
      }
      // Lightning re-forks once while it lives, which is what makes it crackle.
      if (!b.again && age > 0.45) {
        b.again = true;
        b.main = jag(...b.ends, b.rough, b.depth);
      }
      const alpha = (age < 0.08 ? age / 0.08 : 1) * (1 - age) ** 1.3 * (0.78 + 0.22 * Math.random());
      strokeBolt(g, b.main, b.width, alpha, b.color);
      for (const branch of b.branches) strokeBolt(g, branch, b.width * 0.6, alpha * 0.7, b.color);
      const [, , x2, y2] = b.ends;
      const r = 26 * b.width;
      g.globalAlpha = alpha * 0.7;
      g.drawImage(glowOf(b.color), x2 - r, y2 - r, r * 2, r * 2);
    }
    return bolts.length;
  }

  function paintFlares(g, flares, now) {
    for (let i = flares.length - 1; i >= 0; i -= 1) {
      const f = flares[i];
      const age = Math.max(0, (now - f.t) / 650);
      if (age >= 1) {
        flares.splice(i, 1);
        continue;
      }
      const grow = 1 - (1 - Math.min(1, age * 3)) ** 3;
      const r = 13 * f.size * (0.7 + 0.4 * grow);
      const alpha = (1 - age) ** 1.4;
      g.globalAlpha = alpha * 0.6;
      g.drawImage(glowOf(f.color), f.x - r * 2.6, f.y - r * 2.6, r * 5.2, r * 5.2);
      g.globalAlpha = alpha;
      g.strokeStyle = rgba(mix(f.color, ink, 0.4), 1);
      g.lineWidth = 1.4;
      g.beginPath();
      g.arc(f.x, f.y, r, 0, TAU);
      g.stroke();
      g.fillStyle = rgba(mix(f.color, ink, 0.55), 1);
      g.font = `${Math.round(r * 1.25)}px ${RUNE_FONT}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillText(f.glyph, f.x, f.y + 0.5);
    }
    return flares.length;
  }

  addPainter((g, now) => {
    const live = paintBolts(g, front.bolts, now) + paintFlares(g, front.flares, now);
    for (let i = rings.length - 1; i >= 0; i -= 1) {
      const ring = rings[i];
      const age = Math.max(0, (now - ring.t) / 760);
      if (age >= 1) {
        rings.splice(i, 1);
        continue;
      }
      const ease = 1 - (1 - age) ** 3;
      const radius = 16 + ease * 92;
      const alpha = (1 - age) ** 1.6;
      g.globalAlpha = alpha * 0.8;
      g.strokeStyle = rgba(arcane, 1);
      g.lineWidth = 1.6;
      g.beginPath();
      g.arc(ring.x, ring.y, radius, 0, TAU);
      g.stroke();
      g.fillStyle = rgba(mix(arcane, ink, 0.5), 1);
      g.font = `14px ${RUNE_FONT}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      ring.glyphs.forEach((glyph, k) => {
        const a = ring.turn + age * 1.2 + (k / ring.glyphs.length) * TAU;
        g.fillText(glyph, ring.x + Math.cos(a) * radius, ring.y + Math.sin(a) * radius);
      });
    }
    return live > 0 || rings.length > 0;
  });

  // ---------- what calls the lightning ----------
  const accentOf = (slug) => tokenRgb(`--game-${slug}`);
  let lastStrike = -1e9;

  // While a hero fills most of the screen it hides the walls, so the scroll's lightning
  // strikes it from in front: a window of the hub's castle (each stands for a case) or
  // its flag, or the sky of the case painting.
  const hero = document.querySelector(".hub-hero, main > .hero");
  function heroInView() {
    const box = hero?.getBoundingClientRect();
    return box && box.bottom > window.innerHeight * 0.45 ? box : null;
  }
  function heroTarget(box) {
    const h = window.innerHeight;
    const marks = [...document.querySelectorAll(".hub-hero .win__pane, .hub-hero .keep-flag")]
      .map((el) => el.getBoundingClientRect())
      .filter((r) => r.width && r.top > 8 && r.top < h * 0.8);
    if (marks.length) {
      const r = marks[Math.floor(Math.random() * marks.length)];
      return [r.left + r.width / 2, r.top + r.height * 0.2];
    }
    const top = Math.max(0, box.top);
    return [box.left + box.width * (0.55 + Math.random() * 0.35), top + (Math.min(box.bottom, h) - top) * (0.12 + Math.random() * 0.22)];
  }

  let lastStreamFlash = -1e9;
  function scrollStrike(fork = false) {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const head = fork ? null : potionHead();
    const spires = castleSpires().filter((s) => s.x > 16 && s.x < w - 16 && s.y > 0 && s.y < h);
    const bottles = potionBottles().filter((b) => b.y > 0 && b.y < h);
    const roll = Math.random();
    let target = null;
    let color = arcane;
    let castle = null;
    let bottle = null;
    const over = heroInView();
    if (over) {
      target = heroTarget(over);
      color = mix(arcane, moon, 0.35);
    } else if (bottles.length && (roll < 0.32 || (!head && !spires.length))) {
      const b = bottles[Math.floor(Math.random() * bottles.length)];
      target = [b.x, b.y - b.h * 0.2];
      bottle = b.k;
      color = mix(arcane, b.color, 0.55);
    } else if (head && (roll < 0.68 || !spires.length)) {
      target = [head.x, head.y];
      color = mix(arcane, head.color, 0.55);
    } else if (spires.length) {
      const spire = spires[Math.floor(Math.random() * spires.length)];
      target = [spire.x, spire.y];
      castle = spire.slug;
      color = mix(arcane, accentOf(spire.slug), 0.5);
    } else {
      const node = nearest(w * Math.random(), window.scrollY + h * (0.3 + Math.random() * 0.4), 300, true);
      target = node ? [px(node.i), py(node.j) - window.scrollY] : [w * Math.random(), h * 0.5];
    }
    const behind = !over;
    const from = [Math.min(w - 10, Math.max(10, target[0] + (Math.random() - 0.5) * 260)), -12];
    strike(from[0], from[1], target[0], target[1], { color, width: 1.25, life: 320, branches: 3, flare: 1.15, reach: 180, back: behind });
    if (castle) document.dispatchEvent(new CustomEvent("sc:strike", { detail: { castle } }));
    if (bottle !== null) lightBottle(bottle);
    // The flash shows the potion's whole course for a moment.
    const now = performance.now();
    if (behind && now - lastStreamFlash > STREAM_FLASH_GAP) {
      lastStreamFlash = now;
      flashPotion();
    }
    // Some strikes fork, and a second bolt finds another target.
    if (!fork && behind && Math.random() < 0.4) scrollStrike(true);
    // A crackle along the glass where the potion runs.
    if (head && behind) {
      for (let k = 0; k < 2; k += 1) {
        const a = -Math.PI / 2 + (Math.random() - 0.5) * 1.6;
        const r = 28 + Math.random() * 36;
        strike(head.x, head.y, head.x + Math.cos(a) * r, head.y + Math.sin(a) * r, { color, width: 0.55, life: 200, branches: 0, rune: false, reach: 60, back: behind });
      }
    }
  }

  let lastY = window.scrollY;
  let lastScroll = 0;
  window.addEventListener(
    "scroll",
    () => {
      const now = performance.now();
      const y = window.scrollY;
      const speed = Math.abs(y - lastY) / Math.max(16, now - lastScroll);
      const fresh = now - lastScroll > 250;
      lastY = y;
      lastScroll = now;
      if (!motionOn() || now - lastStrike < STRIKE_GAP || (!fresh && speed < 0.02)) return;
      lastStrike = now;
      scrollStrike();
    },
    { passive: true },
  );

  // The storm never quite stops: a strike every second or two, even at rest. It
  // waits while the tab is hidden or the case files are open.
  const storm = () => {
    setTimeout(() => {
      if (motionOn() && !document.hidden && !document.querySelector("dialog[open]") && performance.now() - lastStrike > 400) {
        lastStrike = performance.now();
        scrollStrike();
      }
      storm();
    }, 700 + Math.random() * 1500);
  };
  storm();

  let travel = 0;
  let last = null;
  let lastArc = 0;
  window.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !finePointer.matches || !motionOn()) return;
      if (last) travel += Math.hypot(event.clientX - last[0], event.clientY - last[1]);
      last = [event.clientX, event.clientY];
      const now = performance.now();
      if (travel < 40 || now - lastArc < 55) return;
      if (event.target.closest?.("input, textarea, select, [contenteditable='true']")) return;
      travel = 0;
      lastArc = now;
      // The nearest bottle draws the lightning, and lights up.
      let bottle = null;
      for (const b of potionBottles()) {
        const d = Math.hypot(b.x - event.clientX, b.y - event.clientY);
        if (d < 320 && d > 20 && (!bottle || d < bottle.d)) bottle = { ...b, d };
      }
      if (bottle) {
        strike(event.clientX, event.clientY, bottle.x, bottle.y - bottle.h * 0.15, { width: 0.8, life: 230, branches: 1, flare: 0.8, reach: 100, color: mix(arcane, bottle.color, 0.5) });
        lightBottle(bottle.k);
        return;
      }
      const node = covered() ? null : nearest(event.clientX, event.clientY + window.scrollY, 170, true);
      if (node) {
        strike(event.clientX, event.clientY, px(node.i), py(node.j) - window.scrollY, { width: 0.7, life: 210, branches: 1, flare: 0.8, reach: 100 });
      } else {
        const a = Math.random() * TAU;
        const r = 45 + Math.random() * 45;
        strike(event.clientX, event.clientY, event.clientX + Math.cos(a) * r, event.clientY + Math.sin(a) * r, { width: 0.6, life: 180, branches: 0, rune: false, reach: 80 });
      }
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => (last = null));

  let lastBurst = -1e9;
  document.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || !motionOn()) return;
    const now = performance.now();
    if (event.scBottle !== undefined) {
      // A click on a bottle draws the lightning into it instead.
      const b = potionBottles().find((item) => item.k === event.scBottle);
      if (b) {
        for (let k = 0; k < 5; k += 1) {
          const a = Math.random() * TAU;
          const r = 130 + Math.random() * 90;
          strike(b.x + Math.cos(a) * r, b.y + Math.sin(a) * r, b.x, b.y, { width: 0.85, life: 280, branches: 1, rune: false, reach: 80, color: mix(arcane, b.color, 0.5) });
        }
        lightBottle(b.k);
      }
      return;
    }
    const strong = now - lastBurst > STRIKE_GAP;
    if (strong) lastBurst = now;
    const x = event.clientX;
    const y = event.clientY;
    const count = strong ? 6 : 3;
    const turn = Math.random() * TAU;
    for (let k = 0; k < count; k += 1) {
      const a = turn + (k / count) * TAU + (Math.random() - 0.5) * 0.4;
      const r = 80 + Math.random() * 90;
      strike(x, y, x + Math.cos(a) * r, y + Math.sin(a) * r, { width: strong ? 0.9 : 0.6, life: 260, branches: 1, rune: k % 2 === 0, flare: 0.7, reach: 90 });
    }
    rings.push({ x, y, t: now, turn, glyphs: Array.from({ length: 8 }, () => RUNES[Math.floor(Math.random() * RUNES.length)]) });
    if (!covered()) surge(x, y + window.scrollY);
  });

  window.addEventListener("resize", () => {
    view = fit(wall, lowPower ? 1 : 1.5);
    layout();
    drawWall(performance.now());
  });
  onScroll(() => {
    if (!stopWall) drawWall(performance.now());
  });
  document.addEventListener("sc:motionchange", () => {
    if (motionOn()) return;
    for (const set of [front, back]) {
      set.bolts.length = 0;
      set.flares.length = 0;
    }
    rings.length = 0;
    surges.length = 0;
    lit.clear();
    drawWall(performance.now());
  });
  drawWall(performance.now());
}
