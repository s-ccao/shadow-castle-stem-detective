import { addTicker, tokenRgb } from "../loop.js";
import { motionOn } from "../prefs.js";

// Mechanic vignettes: each upcoming case's core verb as a short canvas loop.
// A scene is a pure function of loop progress p (0–1), drawn in a 160 × 100
// unit box centred on the origin, so pausing, resuming and the still frame
// shown with motion off need no state. Scenes load on demand from ./<name>.js.
const BOX_W = 160;
const BOX_H = 100;
const PIXEL_BUDGET = 1.6e6;
const NAME = /^[a-z0-9-]+$/;
const scenes = new Map();

export const kit = {
  seg: (p, a, b) => (p <= a ? 0 : p >= b ? 1 : (p - a) / (b - a)),
  ease: (p) => 1 - (1 - p) ** 3,
  inOut: (p) => (p < 0.5 ? 4 * p ** 3 : 1 - (2 - 2 * p) ** 3 / 2),
  bump: (p) => (p <= 0 || p >= 1 ? 0 : Math.sin(Math.PI * p)),
  mix: (a, b, k) => a.map((v, i) => Math.round(v + (b[i] - v) * k)),
  col: (rgb, a = 1) => `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${a})`,
  // Deterministic noise in [0, 1): particles replay identically every loop.
  rand(n) {
    let x = Math.imul((n | 0) ^ 0x9e3779b9, 0x85ebca6b);
    x = Math.imul(x ^ (x >>> 13), 0xc2b2ae35);
    return ((x ^ (x >>> 16)) >>> 0) / 4294967296;
  },
  halo(c, x, y, r, rgb, a) {
    if (a <= 0.004 || r <= 0) return;
    const g = c.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, kit.col(rgb, a));
    g.addColorStop(1, kit.col(rgb, 0));
    c.fillStyle = g;
    c.fillRect(x - r, y - r, r * 2, r * 2);
  },
  rrect(c, x, y, w, h, r) {
    c.beginPath();
    if (c.roundRect) c.roundRect(x, y, w, h, r);
    else c.rect(x, y, w, h);
  },
  line(c, x1, y1, x2, y2) {
    c.beginPath();
    c.moveTo(x1, y1);
    c.lineTo(x2, y2);
    c.stroke();
  },
  // Night backdrop with the case's accent glowing behind the action.
  backdrop(c, v, pal, x = 0, y = 0, r = 96, a = 0.16) {
    c.fillStyle = kit.col(pal.night);
    c.fillRect(v.x0, v.y0, v.x1 - v.x0, v.y1 - v.y0);
    kit.halo(c, x, y, r, pal.a, a);
  },
};

function palette(accent) {
  const rgb = (name) => tokenRgb(name);
  return {
    a: rgb(accent),
    moon: rgb("--color-moon"),
    ember: rgb("--color-ember"),
    bronze: rgb("--color-bronze"),
    arcane: rgb("--color-arcane"),
    ink: rgb("--color-ink"),
    dim: rgb("--color-muted"),
    stone: rgb("--color-keep-lit"),
    edge: rgb("--color-keep-edge"),
    night: rgb("--color-night"),
  };
}

class Vignette {
  constructor(host, scene, { accent, layout }) {
    this.scene = scene;
    this.layout = layout || {};
    this.pal = palette(accent);
    this.canvas = document.createElement("canvas");
    this.canvas.className = "vignette";
    this.canvas.setAttribute("aria-hidden", "true");
    host.append(this.canvas);
    this.ctx = this.canvas.getContext("2d");
    this.clock = 0;
    this.wanted = false;
    this.seen = true;
    this.untick = null;
    this.sync = this.sync.bind(this);
    document.addEventListener("sc:motionchange", this.sync);
    this.resizer = new ResizeObserver(() => {
      this.size();
      if (!this.untick) this.frame();
    });
    this.resizer.observe(this.canvas);
    this.seer = new IntersectionObserver(([entry]) => {
      this.seen = entry.isIntersecting;
      this.sync();
    });
    this.seer.observe(this.canvas);
    this.size();
  }

  size() {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (w * h * dpr * dpr > PIXEL_BUDGET) dpr = Math.max(1, Math.sqrt(PIXEL_BUDGET / (w * h)));
    this.w = w;
    this.h = h;
    this.dpr = dpr;
    this.canvas.width = Math.max(1, Math.round(w * dpr));
    this.canvas.height = Math.max(1, Math.round(h * dpr));
  }

  frame() {
    const { ctx: c, w, h, dpr, scene } = this;
    if (!c || !w || !h) return;
    const { fx = 0.5, fy = 0.5, fit = 1 } = typeof this.layout === "function" ? this.layout(w, h) : this.layout;
    const s = Math.min((w * fit) / BOX_W, (h * fit) / BOX_H);
    const cx = w * fx;
    const cy = h * fy;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.globalAlpha = 1;
    c.globalCompositeOperation = "source-over";
    c.clearRect(0, 0, this.canvas.width, this.canvas.height);
    c.setTransform(dpr * s, 0, 0, dpr * s, dpr * cx, dpr * cy);
    c.lineCap = "round";
    c.lineJoin = "round";
    const view = { x0: -cx / s, y0: -cy / s, x1: (w - cx) / s, y1: (h - cy) / s };
    const p = motionOn() ? (this.clock % scene.period) / scene.period : scene.still;
    scene.draw(c, kit, p, view, this.pal);
    this.canvas.classList.add("is-drawn");
  }

  sync() {
    const run = this.wanted && this.seen && motionOn();
    if (run && !this.untick) {
      this.untick = addTicker((now, dt) => {
        this.clock += dt;
        this.frame();
      });
    } else if (!run && this.untick) {
      this.untick();
      this.untick = null;
    }
    if (!run) this.frame();
  }

  play({ restart = false } = {}) {
    if (restart) this.clock = 0;
    this.wanted = true;
    this.sync();
  }

  pause() {
    this.wanted = false;
    this.sync();
  }

  destroy() {
    this.wanted = false;
    this.untick?.();
    this.untick = null;
    this.resizer.disconnect();
    this.seer.disconnect();
    document.removeEventListener("sc:motionchange", this.sync);
    this.canvas.remove();
  }
}

// Resolves to a paused vignette mounted in host; call play() to run it.
export function mountVignette(host, name, { accent = `--game-${name}`, layout } = {}) {
  if (!NAME.test(name)) return Promise.reject(new Error(`Unknown vignette "${name}"`));
  if (!scenes.has(name)) {
    scenes.set(
      name,
      import(`./${name}.js`).then(
        (module) => module.default,
        (error) => {
          scenes.delete(name);
          throw error;
        },
      ),
    );
  }
  return scenes.get(name).then((scene) => new Vignette(host, scene, { accent, layout }));
}

// Case pages: the hero's seal becomes a lens onto the case's mechanic.
export function initHeroVignettes() {
  document.querySelectorAll(".case-hero__art[data-vignette]").forEach((art) => {
    const lens = document.createElement("span");
    lens.className = "case-hero__lens";
    art.append(lens);
    mountVignette(lens, art.dataset.vignette, { layout: { fit: 0.84 } })
      .then((vignette) => {
        art.classList.add("has-vignette");
        vignette.play();
      })
      .catch((error) => {
        lens.remove();
        console.error(error);
      });
  });
}
