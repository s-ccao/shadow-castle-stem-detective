// Small shared pieces for the night layers (sky.js, castles.js, potion.js, runes.js, lantern.js).
export const TAU = Math.PI * 2;

// Deterministic randomness, so the same page always hides the same evidence.
export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hashString(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i += 1) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  return h >>> 0;
}

export const rgba = (rgb, a) => `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${a})`;

// A soft round light, drawn once and stretched wherever it is needed.
export function sprite(rgb, size = 128, stops = [[0, 1], [0.35, 0.45], [1, 0]]) {
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  for (const [at, alpha] of stops) grad.addColorStop(at, rgba(rgb, alpha));
  g.fillStyle = grad;
  g.fillRect(0, 0, size, size);
  return c;
}

// A fixed, full-viewport canvas behind all content (see css/night.css for the order).
export function skyLayer(name) {
  const canvas = document.createElement("canvas");
  canvas.className = `night-layer night-layer--${name}`;
  canvas.setAttribute("aria-hidden", "true");
  document.body.append(canvas);
  return canvas;
}

export function fit(canvas, maxDpr = 1) {
  const dpr = Math.min(window.devicePixelRatio || 1, maxDpr);
  const w = window.innerWidth;
  const h = window.innerHeight;
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  return { w, h, dpr };
}

// True while a full-bleed hero (the hub's sky, the case painting) fills the screen:
// layers behind it skip drawing, while the pointer's light in front still runs.
export function heroCovers() {
  const cover = document.querySelector(".hub-hero, main > .hero");
  return () => !!cover && cover.getBoundingClientRect().bottom >= window.innerHeight;
}

// Elements a click acts on, rather than leaving a mark on the wall.
export const ACTIVE = "a[href], button, [role='button'], [role='switch'], summary, label, input, textarea, select, [contenteditable='true'], .case-card, .win";

// Low-end devices get fewer particles and smaller buffers.
export const lowPower = Math.min(screen.width, screen.height) < 700 || (navigator.hardwareConcurrency || 8) <= 4;
