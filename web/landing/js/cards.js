import { finePointer } from "./loop.js";
import { motionOn } from "./prefs.js";
import { t } from "./i18n.js";

// Card previews. A fine pointer that rests on a card for a moment plays its
// preview (Shadow Castle's stills, or an upcoming case's mechanic vignette);
// touch gets an explicit Preview button instead of autoplay.
const PREVIEWABLE = ".case-card[data-preview], .case-card[data-vignette]";
const INTENT_MS = 250;
const STEP_MS = 1600;
let timer = 0;
let cycle = 0;
let active = null;
let pending = null;
const vignettes = new WeakMap();

function stack(card) {
  let preview = card.querySelector(".case-card__preview");
  if (preview) return preview;
  const sources = JSON.parse(card.dataset.preview || "[]");
  preview = document.createElement("div");
  preview.className = "case-card__preview";
  preview.setAttribute("aria-hidden", "true");
  preview.innerHTML = sources.map((src) => `<img alt="" data-src="${src}" decoding="async" />`).join("");
  card.querySelector(".case-card__art").append(preview);
  return preview;
}

function vignette(card) {
  if (!vignettes.has(card)) {
    const mounting = import("./vignettes/stage.js").then((m) => m.mountVignette(stack(card), card.dataset.vignette));
    mounting.catch(() => vignettes.delete(card));
    vignettes.set(card, mounting);
  }
  return vignettes.get(card);
}

function play(card) {
  const pinned = card.classList.contains("is-pinned");
  stop();
  if (!motionOn() && !pinned) return;
  card.classList.toggle("is-pinned", pinned);
  active = card;
  if (card.dataset.vignette) {
    card.classList.add("is-previewing");
    vignette(card)
      .then((scene) => active === card && scene.play({ restart: true }))
      .catch((error) => {
        console.error(error);
        card.classList.remove("is-previewing");
      });
    return;
  }
  const images = [...stack(card).querySelectorAll("img")];
  if (!images.length) return;
  images.forEach((img) => {
    if (!img.src) img.src = img.dataset.src;
  });
  let shown = 0;
  images.forEach((img, i) => img.classList.toggle("is-shown", i === 0));
  card.classList.add("is-previewing");
  if (images.length < 2 || !motionOn()) return;
  cycle = setInterval(() => {
    images[shown].classList.remove("is-shown");
    shown = (shown + 1) % images.length;
    images[shown].classList.add("is-shown");
  }, STEP_MS);
}

function stop() {
  clearTimeout(timer);
  clearInterval(cycle);
  pending = null;
  if (active) {
    active.classList.remove("is-previewing", "is-pinned");
    vignettes.get(active)?.then((scene) => scene.pause(), () => {});
  }
  active = null;
}

function addTouchToggles() {
  if (finePointer.matches) return;
  document.querySelectorAll(PREVIEWABLE).forEach((card) => {
    if (card.querySelector(".case-card__preview-toggle")) return;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "case-card__preview-toggle";
    button.setAttribute("aria-pressed", "false");
    button.innerHTML = `<span aria-hidden="true">▶</span> <span>${t("cards.preview", "Preview")}</span>`;
    button.addEventListener("click", () => {
      const on = !card.classList.contains("is-previewing");
      document.querySelectorAll(".case-card__preview-toggle[aria-pressed='true']").forEach((other) => other.setAttribute("aria-pressed", "false"));
      if (on) {
        card.classList.add("is-pinned");
        play(card);
      } else {
        stop();
      }
      button.setAttribute("aria-pressed", String(on));
    });
    card.append(button);
  });
}

export function initCards() {
  document.addEventListener(
    "pointerover",
    (event) => {
      if (event.pointerType !== "mouse") return;
      const card = event.target.closest?.(PREVIEWABLE) || null;
      if (card === active || (card && card === pending)) return;
      stop();
      if (!card || !motionOn()) return;
      pending = card;
      timer = setTimeout(() => play(card), INTENT_MS);
    },
    { passive: true },
  );
  document.addEventListener("sc:motionchange", () => {
    if (!motionOn()) stop();
  });
  addTouchToggles();
}
