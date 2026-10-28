import { addTicker, clamp, damp, finePointer } from "./loop.js";
import { adoptOverlay } from "./overlay.js";
import { motionOn } from "./prefs.js";

// The pointer layer: a brass magnifier cursor that frames what it can open,
// magnetic primary buttons, and tilting case cards. (The light the pointer casts,
// the lantern and the prism trail, lives in js/night/.) All of it is decoration;
// the native cursor returns for text entry, touch, forced colours, reduced motion,
// and on any error.
const root = document.documentElement;
const forcedColors = matchMedia("(forced-colors: active)");
const INTERACTIVE = "a[href], button, [role='button'], [role='switch'], summary, label, select, .case-card, .win";
const NATIVE = "input, textarea, select, [contenteditable='true'], [data-native-cursor]";

function cursorAllowed() {
  return finePointer.matches && motionOn() && !forcedColors.matches;
}

// ---------- Cursor ----------
function createCursor() {
  const el = document.createElement("div");
  el.className = "sc-cursor";
  el.setAttribute("aria-hidden", "true");
  el.innerHTML =
    '<span class="sc-cursor__lens"></span><span class="sc-cursor__dot"></span>' +
    '<span class="sc-cursor__frame"><i></i><i></i><i></i><i></i></span>';
  adoptOverlay(el);
  const [lens, dot, frame] = el.children;
  const s = { x: -99, y: -99, lx: -99, ly: -99, fx: 0, fy: 0, fw: 0, fh: 0, fa: 0, target: null, frameable: false, seen: false };
  let stop = null;

  const enabled = () => root.classList.contains("has-cursor");

  function setEnabled(on) {
    root.classList.toggle("has-cursor", on);
    if (!on) el.classList.remove("is-on");
  }

  function aim(node) {
    if (!node || !node.closest) return;
    if (node.closest(NATIVE)) {
      s.target = null;
      el.classList.remove("is-on", "is-hot");
      return;
    }
    if (s.seen) el.classList.add("is-on");
    let target = node.closest(INTERACTIVE);
    // A case card's stretched title link covers the card: frame the whole card.
    if (target && target.matches(".case-card__link")) target = target.closest(".case-card");
    if (target !== s.target) {
      s.target = target;
      if (target) {
        const box = target.getBoundingClientRect();
        s.frameable = box.width <= 640 && box.height <= 560;
        const accent = getComputedStyle(target).getPropertyValue("--case-accent").trim();
        el.style.setProperty("--frame-color", accent || "");
        if (s.fa < 0.05) {
          s.fx = s.lx - 15;
          s.fy = s.ly - 15;
          s.fw = 30;
          s.fh = 30;
        }
      }
    }
    el.classList.toggle("is-hot", !!target && !s.frameable);
  }

  function frameBox() {
    const target = s.target;
    if (!target || !target.isConnected || !s.frameable) return null;
    const box = (target.matches(".win") ? target.querySelector(".win__pane") : target).getBoundingClientRect();
    return { x: box.left - 6, y: box.top - 6, w: box.width + 12, h: box.height + 12 };
  }

  function tick(now, dt) {
    try {
      s.lx = damp(s.lx, s.x, 30, dt);
      s.ly = damp(s.ly, s.y, 30, dt);
      const box = frameBox();
      const goal = box || { x: s.lx - 15, y: s.ly - 15, w: 30, h: 30 };
      s.fx = damp(s.fx, goal.x, 22, dt);
      s.fy = damp(s.fy, goal.y, 22, dt);
      s.fw = damp(s.fw, goal.w, 20, dt);
      s.fh = damp(s.fh, goal.h, 20, dt);
      s.fa = damp(s.fa, box ? 1 : 0, 16, dt);
      // Position with `translate`, not `transform`: the press and hover `scale` in CSS
      // applies after `translate` but before `transform`, so it would scale the offset
      // too and throw the lens towards the page's corner.
      lens.style.translate = `${s.lx.toFixed(1)}px ${s.ly.toFixed(1)}px`;
      lens.style.opacity = (1 - s.fa).toFixed(3);
      dot.style.transform = `translate3d(${s.x.toFixed(1)}px, ${s.y.toFixed(1)}px, 0)`;
      frame.style.transform = `translate3d(${s.fx.toFixed(1)}px, ${s.fy.toFixed(1)}px, 0)`;
      frame.style.width = `${s.fw.toFixed(1)}px`;
      frame.style.height = `${s.fh.toFixed(1)}px`;
      frame.style.opacity = s.fa.toFixed(3);
      const settled = Math.abs(s.lx - s.x) < 0.2 && Math.abs(s.ly - s.y) < 0.2 && !box && s.fa < 0.01;
      if (settled) stop = null;
      return !settled;
    } catch (error) {
      console.error(error);
      setEnabled(false);
      stop = null;
      return false;
    }
  }

  const kick = () => {
    if (!stop && enabled()) stop = addTicker(tick);
  };

  document.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse") {
        el.classList.remove("is-on");
        return;
      }
      if (!enabled()) return;
      s.x = event.clientX;
      s.y = event.clientY;
      if (!s.seen) {
        s.seen = true;
        s.lx = s.x;
        s.ly = s.y;
      }
      aim(event.target);
      kick();
    },
    { passive: true },
  );
  document.addEventListener("pointerdown", () => el.classList.add("is-pressed"));
  for (const type of ["pointerup", "pointercancel", "blur"]) {
    window.addEventListener(type, () => el.classList.remove("is-pressed"));
  }
  root.addEventListener("pointerleave", () => el.classList.remove("is-on"));
  root.addEventListener("pointerenter", () => {
    if (s.seen && enabled()) el.classList.add("is-on");
  });
  // Scrolling moves the page under a still pointer: aim again at what is there now.
  let queued = false;
  window.addEventListener(
    "scroll",
    () => {
      if (queued || !s.seen || !enabled()) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        aim(document.elementFromPoint(s.x, s.y));
        kick();
      });
    },
    { passive: true },
  );

  const sync = () => setEnabled(cursorAllowed());
  document.addEventListener("sc:motionchange", sync);
  finePointer.addEventListener("change", sync);
  forcedColors.addEventListener("change", sync);
  sync();
}

// ---------- Magnetic primary buttons and tilting cards (delegated, so injected content works too) ----------
function createMagnetsAndTilt() {
  const states = new WeakMap();
  const stateOf = (el) => {
    if (!states.has(el)) states.set(el, { x: 0, y: 0, tx: 0, ty: 0, rx: 0, ry: 0, aimX: 0, aimY: 0, stop: null });
    return states.get(el);
  };

  function animate(el, apply) {
    const s = stateOf(el);
    if (s.stop) return;
    s.stop = addTicker((now, dt) => {
      const done = apply(s, dt);
      if (done) s.stop = null;
      return !done;
    });
  }

  const pull = (el) =>
    animate(el, (s, dt) => {
      s.x = damp(s.x, s.tx, 16, dt);
      s.y = damp(s.y, s.ty, 16, dt);
      const resting = s.tx === 0 && s.ty === 0 && Math.abs(s.x) < 0.05 && Math.abs(s.y) < 0.05;
      el.style.translate = resting ? "" : `${s.x.toFixed(2)}px ${s.y.toFixed(2)}px`;
      for (const child of el.children) child.style.translate = resting ? "" : `${(s.x * 0.35).toFixed(2)}px ${(s.y * 0.35).toFixed(2)}px`;
      return Math.abs(s.x - s.tx) < 0.05 && Math.abs(s.y - s.ty) < 0.05;
    });

  const lean = (el) =>
    animate(el, (s, dt) => {
      s.rx = damp(s.rx, s.aimX, 10, dt);
      s.ry = damp(s.ry, s.aimY, 10, dt);
      const resting = s.aimX === 0 && s.aimY === 0 && Math.abs(s.rx) < 0.02 && Math.abs(s.ry) < 0.02;
      el.style.transform = resting ? "" : `perspective(1000px) rotateX(${s.rx.toFixed(3)}deg) rotateY(${s.ry.toFixed(3)}deg)`;
      return Math.abs(s.rx - s.aimX) < 0.02 && Math.abs(s.ry - s.aimY) < 0.02;
    });

  let magnet = null;
  let card = null;
  const releaseMagnet = () => {
    if (!magnet) return;
    const s = stateOf(magnet);
    s.tx = 0;
    s.ty = 0;
    pull(magnet);
    magnet = null;
  };
  const releaseCard = () => {
    if (!card) return;
    const s = stateOf(card);
    s.aimX = 0;
    s.aimY = 0;
    card.classList.remove("is-tilting");
    lean(card);
    card = null;
  };

  document.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !motionOn() || !finePointer.matches) return;
      const nextMagnet = event.target.closest?.("[data-magnet]") || null;
      if (nextMagnet !== magnet) releaseMagnet();
      if (nextMagnet) {
        magnet = nextMagnet;
        const box = magnet.getBoundingClientRect();
        const s = stateOf(magnet);
        s.tx = clamp((event.clientX - (box.left + box.width / 2)) * 0.25, -6, 6);
        s.ty = clamp((event.clientY - (box.top + box.height / 2)) * 0.35, -4, 4);
        magnet.style.setProperty("--mx", `${(event.clientX - box.left).toFixed(0)}px`);
        magnet.style.setProperty("--my", `${(event.clientY - box.top).toFixed(0)}px`);
        pull(magnet);
      }

      const nextCard = event.target.closest?.("[data-tilt]") || null;
      if (nextCard !== card) releaseCard();
      if (nextCard) {
        card = nextCard;
        if (!card.querySelector(":scope > .tilt-glare")) {
          const glare = document.createElement("span");
          glare.className = "tilt-glare";
          glare.setAttribute("aria-hidden", "true");
          card.append(glare);
        }
        const box = card.getBoundingClientRect();
        const x = clamp((event.clientX - box.left) / box.width, 0, 1);
        const y = clamp((event.clientY - box.top) / box.height, 0, 1);
        const s = stateOf(card);
        s.aimX = -(y - 0.5) * 6;
        s.aimY = (x - 0.5) * 6;
        card.style.setProperty("--gx", `${(x * 100).toFixed(1)}%`);
        card.style.setProperty("--gy", `${(y * 100).toFixed(1)}%`);
        card.classList.add("is-tilting");
        lean(card);
      }
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => {
    releaseMagnet();
    releaseCard();
  });
  document.addEventListener("sc:motionchange", () => {
    if (motionOn()) return;
    releaseMagnet();
    releaseCard();
  });
}

export function initPointer() {
  createMagnetsAndTilt();
  createCursor();
}
