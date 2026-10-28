import { addTicker, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";
import { TAU, fit, heroCovers, rgba, rng, skyLayer, sprite } from "./kit.js";

// The night behind every page. CSS paints the sky itself (html in css/site.css);
// this adds drifting fog banks and two breathing moon shafts that slide with the
// page at their own depths, then wakes the moon dust (dust.js) where WebGL can
// carry it. Under reduced motion the fog holds still and only follows the scroll.
const forcedColors = matchMedia("(forced-colors: active)");

function mountFog() {
  const canvas = skyLayer("fog");
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const moon = tokenRgb("--color-moon");
  const banks = { moon: sprite(moon, 256), arcane: sprite(tokenRgb("--color-arcane"), 256) };
  const covered = heroCovers();
  let view = fit(canvas);

  const r = rng(29);
  const fog = Array.from({ length: 10 }, () => ({
    x: r(),
    y: r(),
    rad: 280 + r() * 440,
    vx: (0.006 + r() * 0.012) * (r() < 0.5 ? -1 : 1),
    depth: 0.06 + r() * 0.3,
    tint: r() < 0.6 ? "moon" : "arcane",
    a: 0.07 + r() * 0.08,
    ph: r() * TAU,
  }));

  function draw(now) {
    const { w, h, dpr } = view;
    const t = now / 1000;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, w, h);
    if (covered()) return;
    const sy = window.scrollY;

    // Moon shafts falling from a high window at the upper left.
    ctx.globalCompositeOperation = "screen";
    for (const [x0, width, a, speed] of [[0.04, 210, 0.07, 0.21], [0.2, 110, 0.05, 0.29]]) {
      const breathe = a * (0.65 + 0.35 * Math.sin(t * speed + x0 * 9));
      ctx.save();
      ctx.translate(w * x0, -60);
      ctx.rotate(-0.5);
      const g = ctx.createLinearGradient(-width / 2, 0, width / 2, 0);
      g.addColorStop(0, rgba(moon, 0));
      g.addColorStop(0.5, rgba(moon, breathe));
      g.addColorStop(1, rgba(moon, 0));
      ctx.fillStyle = g;
      ctx.fillRect(-width / 2, 0, width, Math.hypot(w, h) * 1.3);
      ctx.restore();
    }

    // Fog banks drift sideways and slide with the page at their own depth.
    for (const f of fog) {
      const span = w + f.rad * 2;
      const x = ((((f.x * span + t * f.vx * w) % span) + span) % span) - f.rad;
      const vspan = h + f.rad * 2;
      const y = ((((f.y * vspan - sy * f.depth) % vspan) + vspan) % vspan) - f.rad + Math.sin(t * 0.12 + f.ph) * 26;
      ctx.globalAlpha = f.a;
      ctx.drawImage(banks[f.tint], x - f.rad, y - f.rad * 0.55, f.rad * 2, f.rad * 1.1);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
  }

  let stop = null;
  const run = () => {
    stop?.();
    stop = null;
    if (motionOn()) {
      stop = addTicker((now) => {
        draw(now);
        return true;
      });
    } else {
      draw(0);
    }
  };
  window.addEventListener("resize", () => {
    view = fit(canvas);
    if (!motionOn()) draw(0);
  });
  window.addEventListener("scroll", () => !motionOn() && draw(0), { passive: true });
  document.addEventListener("sc:motionchange", run);
  run();
}

export function initNight() {
  if (forcedColors.matches) return;
  mountFog();
  return import("./dust.js").then((m) => m.initDust());
}
