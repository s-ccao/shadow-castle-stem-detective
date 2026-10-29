import { initPrefs } from "./prefs.js";
import { initI18n } from "./i18n.js";
import { initNav } from "./nav.js";
import { initReveal } from "./reveal.js";

// Every system starts in isolation: one failure must never take the page down.
function start(name, fn) {
  try {
    const result = fn();
    if (result && typeof result.catch === "function") {
      result.catch((error) => console.error(`[${name}]`, error));
    }
  } catch (error) {
    console.error(`[${name}]`, error);
  }
}

// Page features load only where the page asks for them.
function lazy(name, selector, loader) {
  if (selector && !document.querySelector(selector)) return;
  loader()
    .then((init) => start(name, init))
    .catch((error) => console.error(`[${name}]`, error));
}

// Below-the-fold features load as their section comes within reach of the viewport.
function near(name, selector, loader) {
  const target = document.querySelector(selector);
  if (!target) return;
  if (!("IntersectionObserver" in window)) {
    lazy(name, null, loader);
    return;
  }
  const watcher = new IntersectionObserver(
    (entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      watcher.disconnect();
      lazy(name, null, loader);
    },
    { rootMargin: "600px 0px" },
  );
  watcher.observe(target);
}

// The case-file library loads on first intent; its triggers are plain links to /games.
function initLibraryLauncher() {
  let module = null;
  const load = () => (module ||= import("./library.js"));
  const caseOfPage = () => document.querySelector("main[data-case]")?.dataset.case;
  const warm = (event) => {
    if (event.target.closest?.("[data-library-open]")) load().then((m) => m.prefetch()).catch(() => {});
  };
  document.addEventListener("pointerover", warm, { passive: true });
  document.addEventListener("focusin", warm);
  document.addEventListener("click", (event) => {
    const trigger = event.target.closest("[data-library-open]");
    if (!trigger || event.defaultPrevented || event.button !== 0) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    load()
      .then((m) => m.openLibrary(trigger.dataset.slug || caseOfPage(), trigger))
      .catch(() => {
        location.href = trigger.href;
      });
  });
  document.addEventListener("sc:open-case", (event) => {
    event.preventDefault();
    load().then((m) => m.openLibrary(event.detail.slug, event.detail.from));
  });
  const deep = /^#cases(?:\/([a-z0-9-]+))?$/.exec(location.hash);
  if (deep) load().then((m) => m.openLibrary(deep[1] || caseOfPage()));
  const hero = document.querySelector(".hub-hero");
  if (hero && "IntersectionObserver" in window) {
    new IntersectionObserver(
      ([entry]) => document.documentElement.classList.toggle("past-hero", entry.intersectionRatio < 0.5),
      { threshold: 0.5 },
    ).observe(hero);
  }
  const footer = document.querySelector(".site-footer");
  if (footer && "IntersectionObserver" in window) {
    new IntersectionObserver(([entry]) => {
      document.documentElement.classList.toggle("footer-in-view", entry.isIntersecting);
    }).observe(footer);
  }
}

start("prefs", initPrefs);
start("i18n", initI18n);
start("nav", initNav);
start("reveal", initReveal);
start("library", initLibraryLauncher);
lazy("cards", ".case-card[data-preview], .case-card[data-vignette]", () => import("./cards.js").then((m) => m.initCards));
lazy("vignettes", ".case-hero__art[data-vignette]", () => import("./vignettes/stage.js").then((m) => m.initHeroVignettes));
lazy("pointer", null, () => import("./pointer.js").then((m) => m.initPointer));
lazy("night", null, () => import("./night/sky.js").then((m) => m.initNight));
lazy("story", "main", () => import("./story.js").then((m) => m.initStory));
// The pointer's light (the lantern) and the loupe need a mouse; rune lightning
// (js/night/runes.js) answers scrolls and taps everywhere and the mouse where there is one.
if (matchMedia("(hover: hover) and (pointer: fine)").matches) {
  lazy("lantern", null, () => import("./night/lantern.js").then((m) => m.initLantern));
  lazy("loupe", ".feature-capture img, .hero__image", () => import("./loupe.js").then((m) => m.initLoupe));
}
lazy("atmosphere", "[data-atmosphere]", () => import("./atmosphere.js").then((m) => m.initAtmosphere));
near("demo", "[data-demo]", () => import("./demo/deduction.js").then((m) => m.initDemo));
lazy("archive", "[data-archive-filter]", () => import("./archive.js").then((m) => m.initArchiveFilter));

export { lazy, start };
