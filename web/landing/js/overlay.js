// Overlays drawn above the page (the magnifier cursor, the pointer's light) must not
// vanish when a modal <dialog> opens: a modal sits in the browser's top layer, above
// every z-index on the page. While one is open, the overlays live inside it; they
// return to <body> when it closes.
const root = document.documentElement;
const overlays = [];
let watching = false;

function topModal() {
  const open = document.querySelectorAll("dialog[open]");
  for (let i = open.length - 1; i >= 0; i -= 1) {
    try {
      if (open[i].matches(":modal")) return open[i];
    } catch {
      return open[i]; // no :modal support: an open dialog is the best guess
    }
  }
  return null;
}

export function rehomeOverlays() {
  try {
    const host = topModal() || document.body;
    for (const el of overlays) if (el.isConnected && el.parentElement !== host) host.append(el);
  } catch (error) {
    console.error(error);
    root.classList.remove("has-cursor"); // never leave the visitor without a pointer
  }
}

export function adoptOverlay(el) {
  overlays.push(el);
  document.body.append(el);
  rehomeOverlays();
  if (watching) return;
  watching = true;
  // showModal() and close() toggle the open attribute.
  new MutationObserver(rehomeOverlays).observe(document.body, { subtree: true, attributeFilter: ["open"] });
}

export function releaseOverlay(el) {
  const index = overlays.indexOf(el);
  if (index >= 0) overlays.splice(index, 1);
  el.remove();
}
