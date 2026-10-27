import { addTicker, clamp, damp, finePointer, onScroll, tokenRgb } from "./loop.js";
import { motionOn } from "./prefs.js";
import { lang, t } from "./i18n.js";

// Weather and depth for [data-atmosphere] heroes: the hub's castle scene ("hub")
// and the Shadow Castle case page's painting ("painting").
const STATUS = { playable: "Playable", "in-development": "In development", "coming-soon": "Coming soon" };

// ---------- Fog: one tileable value-noise texture per page ----------
let fogUrl = null;
function fogTexture() {
  if (fogUrl) return Promise.resolve(fogUrl);
  return new Promise((resolve) => {
    const w = 512;
    const h = 160;
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) return resolve(null);
    let seed = 1793;
    const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    const octaves = [
      [4, 0.5],
      [8, 0.27],
      [16, 0.15],
      [32, 0.08],
    ];
    const grids = octaves.map(([cells]) => {
      const rows = Math.max(3, Math.round((cells * h) / w) + 2);
      return { cells, rows, v: Float32Array.from({ length: cells * rows }, rand) };
    });
    const smooth = (x) => x * x * (3 - 2 * x);
    const [r, g, b] = tokenRgb("--color-moon");
    const image = ctx.createImageData(w, h);
    for (let y = 0; y < h; y += 1) {
      const envelope = Math.pow(Math.sin((Math.PI * (y + 0.5)) / h), 1.6);
      for (let x = 0; x < w; x += 1) {
        let v = 0;
        for (let i = 0; i < grids.length; i += 1) {
          const grid = grids[i];
          const gx = (x / w) * grid.cells;
          const gy = (y / h) * (grid.rows - 1);
          const x0 = Math.floor(gx);
          const y0 = Math.floor(gy);
          const fx = smooth(gx - x0);
          const fy = smooth(gy - y0);
          const xa = x0 % grid.cells;
          const xb = (x0 + 1) % grid.cells; // wraps: the texture tiles horizontally
          const yb = Math.min(y0 + 1, grid.rows - 1);
          const top = grid.v[y0 * grid.cells + xa] + (grid.v[y0 * grid.cells + xb] - grid.v[y0 * grid.cells + xa]) * fx;
          const bottom = grid.v[yb * grid.cells + xa] + (grid.v[yb * grid.cells + xb] - grid.v[yb * grid.cells + xa]) * fx;
          v += octaves[i][1] * (top + (bottom - top) * fy);
        }
        const o = (y * w + x) * 4;
        image.data[o] = r;
        image.data[o + 1] = g;
        image.data[o + 2] = b;
        image.data[o + 3] = clamp((v - 0.3) * 2.2, 0, 1) * envelope * 235;
      }
    }
    ctx.putImageData(image, 0, 0);
    canvas.toBlob((blob) => {
      fogUrl = blob ? URL.createObjectURL(blob) : null;
      resolve(fogUrl);
    }, "image/png");
  });
}

// ---------- Rain: three depths of light drizzle, batched into three strokes ----------
function createRain(canvas) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;
  const [r, g, b] = tokenRgb("--color-moon");
  const WIND = 0.2;
  const SPEED = [0.5, 0.78, 1.15];
  const LENGTH = [10, 15, 24];
  const ALPHA = [0.16, 0.26, 0.38];
  const WIDTH = [0.8, 1, 1.4];
  let width = 0;
  let height = 0;
  let dpr = 1;
  let quality = 1;
  let slowFrames = 0;
  const drops = [];

  function spawn(drop, anywhere) {
    const layer = Math.random() < 0.5 ? 0 : Math.random() < 0.62 ? 1 : 2;
    drop.layer = layer;
    drop.v = SPEED[layer] * (0.85 + Math.random() * 0.3) * dpr;
    drop.len = LENGTH[layer] * (0.8 + Math.random() * 0.4) * dpr;
    drop.x = Math.random() * (width + height * WIND) - height * WIND;
    drop.y = anywhere ? Math.random() * height : -Math.random() * height * 0.25;
    return drop;
  }

  function resize() {
    const box = canvas.getBoundingClientRect();
    dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    width = canvas.width = Math.max(1, Math.round(box.width * dpr));
    height = canvas.height = Math.max(1, Math.round(box.height * dpr));
    const target = Math.round(clamp((box.width * box.height) / 7000, 50, 200) * quality);
    while (drops.length < target) drops.push(spawn({}, true));
    drops.length = target;
    drops.forEach((drop) => spawn(drop, true));
  }

  function tick(dt) {
    // Sustained slow frames thin the rain instead of dropping the page's frame rate.
    slowFrames = dt > 24 ? slowFrames + 1 : Math.max(0, slowFrames - 1);
    if (slowFrames > 45 && quality > 0.35) {
      quality *= 0.7;
      slowFrames = 0;
      resize();
    }
    for (const drop of drops) {
      drop.y += drop.v * dt;
      drop.x += drop.v * dt * WIND;
      if (drop.y - drop.len > height || drop.x - drop.len * WIND > width) spawn(drop, false);
    }
    ctx.clearRect(0, 0, width, height);
    for (let layer = 0; layer < 3; layer += 1) {
      ctx.beginPath();
      for (const drop of drops) {
        if (drop.layer !== layer) continue;
        ctx.moveTo(drop.x, drop.y);
        ctx.lineTo(drop.x - drop.len * WIND, drop.y - drop.len);
      }
      ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${ALPHA[layer]})`;
      ctx.lineWidth = WIDTH[layer] * dpr;
      ctx.stroke();
    }
  }

  return { resize, tick, clear: () => ctx.clearRect(0, 0, width, height) };
}

// ---------- One hero ----------
function setupHero(hero) {
  const isHub = hero.dataset.atmosphere === "hub";
  if (!isHub) injectPaintingWeather(hero);
  const scene = isHub ? hero.querySelector("[data-scene]") : hero;
  const copy = hero.querySelector(isHub ? ".hub-hero__copy" : ".hero__copy");
  const depthLayers = [...scene.querySelectorAll("[data-depth]")].map((el) => ({ el, depth: Number(el.dataset.depth) }));
  if (!isHub) {
    const image = hero.querySelector(".hero__image");
    if (image) depthLayers.unshift({ el: image, depth: 0.2 });
  }
  const rainCanvas = scene.querySelector(".scene-rain");
  const rain = rainCanvas ? createRain(rainCanvas) : null;
  const clues = hero.querySelector(".scene-layer--clues");
  const lantern = hero.querySelector(".scene-lantern");
  const state = { tx: 0, ty: 0, px: 0, py: 0, scroll: window.scrollY, visible: true, height: hero.offsetHeight };
  let stopRain = null;
  let stopDrift = null;
  let flashTimer = 0;

  fogTexture().then((url) => {
    if (url) scene.style.setProperty("--fog-image", `url("${url}")`);
  });

  function applyDepth() {
    const on = motionOn();
    for (const { el, depth } of depthLayers) {
      if (!on) {
        el.style.translate = "";
        continue;
      }
      const x = -state.px * 16 * depth;
      const y = -state.py * 9 * depth + Math.min(state.scroll, state.height) * 0.42 * (1 - depth);
      el.style.translate = `${x.toFixed(2)}px ${y.toFixed(2)}px`;
    }
    if (copy) {
      const y = Math.min(state.scroll, state.height);
      copy.style.translate = on && y > 0 ? `0 ${(y * 0.22).toFixed(1)}px` : "";
      copy.style.opacity = y > 0 ? String(clamp(1 - y / (state.height * 0.8), 0, 1)) : "";
    }
  }

  // Pointer depth eases toward its target; the loop stops once it settles.
  function drift() {
    if (stopDrift) return;
    stopDrift = addTicker((now, dt) => {
      state.px = damp(state.px, state.tx, 5, dt);
      state.py = damp(state.py, state.ty, 5, dt);
      applyDepth();
      if (Math.abs(state.px - state.tx) < 0.001 && Math.abs(state.py - state.ty) < 0.001) {
        stopDrift = null;
        return false;
      }
      return true;
    });
  }

  function startRain() {
    if (!rain || stopRain || !motionOn() || !state.visible) return;
    rain.resize();
    stopRain = addTicker((now, dt) => {
      if (!state.visible || !motionOn()) {
        rain.clear();
        stopRain = null;
        return false;
      }
      rain.tick(dt);
      return true;
    });
  }

  function scheduleFlash() {
    clearTimeout(flashTimer);
    if (!isHub || !motionOn()) return;
    flashTimer = setTimeout(() => {
      if (state.visible && motionOn() && !document.hidden) {
        hero.classList.add("is-flashing");
        setTimeout(() => hero.classList.remove("is-flashing"), 1000);
      }
      scheduleFlash();
    }, 14000 + Math.random() * 16000);
  }

  // Lantern: warm light under a fine pointer reveals the chalk clues on the walls.
  if (isHub && clues && lantern) {
    hero.addEventListener("pointermove", (event) => {
      if (event.pointerType !== "mouse" || !motionOn() || !finePointer.matches) return;
      const box = hero.getBoundingClientRect();
      lantern.style.setProperty("--gx", `${(event.clientX - box.left).toFixed(1)}px`);
      lantern.style.setProperty("--gy", `${(event.clientY - box.top).toFixed(1)}px`);
      const layer = clues.getBoundingClientRect();
      clues.style.setProperty("--cx", `${(event.clientX - layer.left).toFixed(1)}px`);
      clues.style.setProperty("--cy", `${(event.clientY - layer.top).toFixed(1)}px`);
      hero.classList.add("is-lantern");
    });
    hero.addEventListener("pointerleave", () => hero.classList.remove("is-lantern"));
  }

  hero.addEventListener("pointermove", (event) => {
    if (event.pointerType !== "mouse" || !motionOn()) return;
    const box = hero.getBoundingClientRect();
    state.tx = ((event.clientX - box.left) / box.width) * 2 - 1;
    state.ty = ((event.clientY - box.top) / box.height) * 2 - 1;
    drift();
  });
  hero.addEventListener("pointerleave", () => {
    state.tx = 0;
    state.ty = 0;
    drift();
  });

  onScroll((y) => {
    state.scroll = y;
    applyDepth();
  });
  window.addEventListener("resize", () => {
    state.height = hero.offsetHeight;
    if (stopRain) rain.resize();
    applyDepth();
  });

  new IntersectionObserver(([entry]) => {
    state.visible = entry.isIntersecting;
    hero.classList.toggle("is-paused", !state.visible);
    if (state.visible) startRain();
  }).observe(hero);

  document.addEventListener("sc:motionchange", () => {
    applyDepth();
    if (motionOn()) {
      startRain();
      scheduleFlash();
    } else {
      hero.classList.remove("is-lantern", "is-flashing");
      clearTimeout(flashTimer);
    }
  });

  if (isHub) setupWindows(hero);
  if (isHub && motionOn()) {
    hero.classList.add("is-sleeping");
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        hero.classList.add("is-waking");
        hero.classList.remove("is-sleeping");
        setTimeout(() => hero.classList.remove("is-waking"), 3200);
      }),
    );
  }
  applyDepth();
  startRain();
  scheduleFlash();
}

function injectPaintingWeather(hero) {
  const weather = document.createElement("div");
  weather.className = "atmo";
  weather.setAttribute("aria-hidden", "true");
  weather.innerHTML =
    '<div class="atmo__moonlight"></div>' +
    '<div class="fog fog--mid" data-depth="0.6"></div>' +
    '<div class="fog fog--near" data-depth="0.9"></div>' +
    '<canvas class="scene-rain"></canvas>';
  hero.insertBefore(weather, hero.querySelector(".hero__shade"));
}

// ---------- The seven windows ----------
function setupWindows(hero) {
  const label = hero.querySelector(".scene-label");
  if (!label) return;
  const name = label.querySelector(".scene-label__name");
  const status = label.querySelector(".scene-label__status");

  const show = (win) => {
    win.classList.add("is-hover");
    name.textContent = lang() === "zh" ? win.dataset.labelZh : win.dataset.labelEn;
    status.textContent = t(`status.${win.dataset.status}`, STATUS[win.dataset.status] || "");
    label.style.setProperty("--label-accent", getComputedStyle(win).getPropertyValue("--win").trim());
    const pane = win.querySelector(".win__pane").getBoundingClientRect();
    const box = hero.getBoundingClientRect();
    const x = clamp(pane.left + pane.width / 2 - box.left - label.offsetWidth / 2, 8, box.width - label.offsetWidth - 8);
    let y = pane.top - box.top - label.offsetHeight - 14;
    if (y < 76) y = pane.bottom - box.top + 14;
    label.style.setProperty("--tx", `${x.toFixed(1)}px`);
    label.style.setProperty("--ty", `${y.toFixed(1)}px`);
    label.classList.add("is-on");
  };
  const hide = (win) => {
    win.classList.remove("is-hover");
    label.classList.remove("is-on");
  };

  hero.querySelectorAll(".win").forEach((win) => {
    win.addEventListener("pointerenter", () => show(win));
    win.addEventListener("pointerleave", () => hide(win));
    win.addEventListener("click", (event) => {
      // The case-file library opens on this game when it is present; otherwise follow the link.
      const handled = !document.dispatchEvent(
        new CustomEvent("sc:open-case", { detail: { slug: win.dataset.game, from: win }, cancelable: true }),
      );
      if (handled) event.preventDefault();
      hide(win);
    });
  });
}

export function initAtmosphere() {
  document.querySelectorAll("[data-atmosphere]").forEach(setupHero);
}
