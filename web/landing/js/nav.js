import { onScroll } from "./loop.js";

// N10 navigation: transparent over the hero, a compact glass bar once the page
// scrolls, hidden while reading downward and back as soon as the reader scrolls up.
export function initNav() {
  const nav = document.querySelector("[data-nav]");
  if (!nav) return;
  const root = document.documentElement;
  let lastY = window.scrollY;
  let focused = false;

  const update = (y) => {
    nav.dataset.state = y > 24 ? "solid" : "top";
    const dy = y - lastY;
    if (focused || y < 160 || dy < -4 || root.classList.contains("library-open")) {
      nav.classList.remove("is-hidden");
    } else if (dy > 6) {
      nav.classList.add("is-hidden");
    }
    lastY = y;
  };

  nav.addEventListener("focusin", () => {
    focused = true;
    nav.classList.remove("is-hidden");
  });
  nav.addEventListener("focusout", (event) => {
    if (!nav.contains(event.relatedTarget)) focused = false;
  });
  onScroll(update);
}
