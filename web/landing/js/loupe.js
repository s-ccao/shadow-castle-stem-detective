import { addTicker, finePointer, onScroll } from "./loop.js";
import { motionOn } from "./prefs.js";
import { t } from "./i18n.js";

// The loupe: over a game capture or the case painting, the magnifier cursor really
// magnifies. Pixel captures land on a whole multiple of their native pixels so they
// stay crisp. Held still, the lens scans and then locks the evidence, numbered by
// the capture's place on the page. It only appears with the custom cursor (fine
// pointer, full motion) and never through text or controls laid over a picture.
const TARGETS = ".feature-capture img, .room-shot img, main > .hero > img, .hero__image";
const HALF = 86; // half the lens's inner width, in CSS px

export function initLoupe() {
  const root = document.documentElement;
  const images = [...document.querySelectorAll(TARGETS)];
  if (!images.length || !finePointer.matches) return;

  const el = document.createElement("div");
  el.className = "loupe";
  el.setAttribute("aria-hidden", "true");
  const view = document.createElement("div");
  view.className = "loupe__view";
  const read = document.createElement("span");
  read.className = "loupe__read";
  el.append(view, read);
  document.body.append(el);
  const s = { img: null, x: 0, y: 0, lastMove: 0, scan: 0, locked: false, stop: null };

  // Look through decorative overlays (the hero's shade and rain), never through
  // text or controls.
  function imageAt(x, y, target) {
    if (!target || target.closest?.("a, button, p, h1, h2, h3, figcaption, label, dialog")) return null;
    if (images.includes(target)) return target;
    if (!target.closest?.("[aria-hidden='true'], .hero__shade")) return null;
    return document.elementsFromPoint(x, y).find((candidate) => images.includes(candidate)) || null;
  }

  function aimAt(img) {
    if (img === s.img) return;
    s.img = img;
    s.scan = 0;
    s.locked = false;
    el.classList.toggle("is-on", !!img);
    el.classList.remove("is-locked");
    root.classList.toggle("is-looking", !!img);
    if (!img) return;
    el.classList.toggle("is-pixel", !!img.closest(".feature-capture, .room-shot"));
    view.style.backgroundImage = `url("${img.currentSrc || img.src}")`;
  }

  function paint() {
    const img = s.img;
    if (!img || !img.naturalWidth) return;
    const box = img.getBoundingClientRect();
    const nw = img.naturalWidth;
    const nh = img.naturalHeight;
    // object-fit: cover crops the picture to its box; the lens must see the same crop.
    const fitScale = getComputedStyle(img).objectFit === "cover" ? Math.max(box.width / nw, box.height / nh) : box.width / nw;
    const offX = (box.width - nw * fitScale) / 2;
    const offY = (box.height - nh * fitScale) / 2;
    const k = el.classList.contains("is-pixel") ? Math.max(2, Math.round(fitScale * 2.6)) : fitScale * 2.4;
    const u = (s.x - box.left - offX) / fitScale;
    const v = (s.y - box.top - offY) / fitScale;
    view.style.backgroundSize = `${nw * k}px ${nh * k}px`;
    view.style.backgroundPosition = `${(HALF - u * k).toFixed(1)}px ${(HALF - v * k).toFixed(1)}px`;
    el.style.translate = `${s.x}px ${s.y}px`;
    const number = String(images.indexOf(img) + 1).padStart(2, "0");
    read.textContent = s.locked
      ? `${t("loupe.locked", "EVIDENCE LOCKED")} · E-${number}`
      : `×${(k / fitScale).toFixed(1)} · ${t("loupe.scan", "SCAN")} ${Math.round(s.scan * 100)}%`;
    view.style.setProperty("--scan", `${(s.scan * 400) % 100}%`);
    view.style.setProperty("--scan-a", s.locked ? "0" : "0.9");
  }

  function tick(now, dt) {
    if (!s.img) {
      s.stop = null;
      return false;
    }
    if (!s.locked) s.scan = now - s.lastMove > 140 ? Math.min(1, s.scan + dt / 900) : Math.max(0, s.scan - dt / 300);
    if (s.scan >= 1 && !s.locked) {
      s.locked = true;
      el.classList.add("is-locked");
    }
    paint();
    return true;
  }
  const kick = () => {
    if (!s.stop) s.stop = addTicker(tick);
  };

  document.addEventListener(
    "pointermove",
    (event) => {
      if (event.pointerType !== "mouse" || !motionOn() || !root.classList.contains("has-cursor")) {
        aimAt(null);
        return;
      }
      s.x = event.clientX;
      s.y = event.clientY;
      s.lastMove = performance.now();
      if (s.locked) {
        s.locked = false;
        s.scan = 0.4;
        el.classList.remove("is-locked");
      }
      aimAt(imageAt(event.clientX, event.clientY, event.target));
      if (s.img) kick();
    },
    { passive: true },
  );
  root.addEventListener("pointerleave", () => aimAt(null));
  document.addEventListener("sc:motionchange", () => !motionOn() && aimAt(null));
  onScroll(
    () => {
      if (!s.img) return;
      aimAt(imageAt(s.x, s.y, document.elementFromPoint(s.x, s.y)));
      if (s.img) kick();
    },
    { immediate: false },
  );
}
