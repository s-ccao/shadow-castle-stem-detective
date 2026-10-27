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
lazy("atmosphere", "[data-atmosphere]", () => import("./atmosphere.js").then((m) => m.initAtmosphere));

export { lazy, start };
