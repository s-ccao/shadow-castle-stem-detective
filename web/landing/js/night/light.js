import { addTicker } from "../loop.js";
import { adoptOverlay } from "../overlay.js";
import { lowPower } from "./kit.js";

// The pointer's light: one canvas above the page and under the magnifier, screened
// onto whatever lies beneath. Painters (the lantern's glow, the prism trail, camera
// flashes, shock rings) draw into it in the order they were added; each returns
// whether it still has light to show, and the canvas stops redrawing when none do.
// It follows the cursor into an open modal dialog (js/overlay.js).
const painters = [];
const view = { w: 0, h: 0, dpr: 1 };
let canvas = null;
let ctx = null;
let stop = null;
let dirty = false;

function size() {
  view.dpr = Math.min(window.devicePixelRatio || 1, lowPower ? 1 : 1.5);
  view.w = window.innerWidth;
  view.h = window.innerHeight;
  canvas.width = Math.round(view.w * view.dpr);
  canvas.height = Math.round(view.h * view.dpr);
}

function frame(now, dt) {
  ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  ctx.globalCompositeOperation = "source-over";
  ctx.globalAlpha = 1;
  ctx.clearRect(0, 0, view.w, view.h);
  let busy = false;
  for (const paint of painters) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    try {
      if (paint(ctx, now, dt, view)) busy = true;
    } catch (error) {
      console.error(error);
    }
    ctx.restore();
  }
  dirty = busy;
  if (!busy) stop = null;
  return busy;
}

export function addPainter(paint) {
  if (!canvas) {
    canvas = document.createElement("canvas");
    canvas.className = "night-light";
    canvas.setAttribute("aria-hidden", "true");
    ctx = canvas.getContext("2d");
    size();
    window.addEventListener("resize", () => {
      size();
      if (dirty) wakeLight();
    });
    adoptOverlay(canvas);
  }
  painters.push(paint);
  return () => {
    const index = painters.indexOf(paint);
    if (index >= 0) painters.splice(index, 1);
  };
}

// Painters call this when they have something new to draw.
export function wakeLight() {
  if (canvas && !stop) stop = addTicker(frame);
}
