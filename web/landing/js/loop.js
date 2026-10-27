// One requestAnimationFrame for every animated system on the page, and one
// rAF-batched scroll pass. Loops stop when nothing is ticking or the tab is hidden.
const tickers = new Set();
const scrollers = new Set();
let frame = 0;
let last = 0;
let scrollQueued = false;

function run(now) {
  frame = 0;
  const dt = Math.min(64, now - (last || now));
  last = now;
  for (const tick of [...tickers]) {
    let keep;
    try {
      keep = tick(now, dt);
    } catch (error) {
      keep = false;
      console.error(error);
    }
    if (keep === false) tickers.delete(tick);
  }
  if (tickers.size && !document.hidden) frame = requestAnimationFrame(run);
  else last = 0;
}

// A ticker runs every frame until it returns false or its remover is called.
export function addTicker(tick) {
  tickers.add(tick);
  wake();
  return () => tickers.delete(tick);
}

export function wake() {
  if (!frame && tickers.size && !document.hidden) frame = requestAnimationFrame(run);
}

function flushScroll() {
  scrollQueued = false;
  const y = window.scrollY;
  for (const fn of scrollers) {
    try {
      fn(y);
    } catch (error) {
      console.error(error);
    }
  }
}

function queueScroll() {
  if (scrollQueued) return;
  scrollQueued = true;
  requestAnimationFrame(flushScroll);
}

export function onScroll(fn, { immediate = true } = {}) {
  scrollers.add(fn);
  if (immediate) fn(window.scrollY);
  return () => scrollers.delete(fn);
}

window.addEventListener("scroll", queueScroll, { passive: true });
window.addEventListener("resize", queueScroll);

document.addEventListener("visibilitychange", () => {
  if (!document.hidden) wake();
});

export const finePointer = matchMedia("(hover: hover) and (pointer: fine)");

export function clamp(value, min, max) {
  return value < min ? min : value > max ? max : value;
}

export function lerp(from, to, amount) {
  return from + (to - from) * amount;
}

// Frame-rate independent smoothing: rate is "per second", dt in milliseconds.
export function damp(from, to, rate, dt) {
  return lerp(from, to, 1 - Math.exp((-rate * dt) / 1000));
}
