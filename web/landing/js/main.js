import { initPrefs } from "./prefs.js";
import { initI18n } from "./i18n.js";
import { initNav } from "./nav.js";

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

start("prefs", initPrefs);
start("i18n", initI18n);
start("nav", initNav);

export { lazy, start };
