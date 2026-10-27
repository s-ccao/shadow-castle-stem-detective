// Motion preference: the system setting, unless the visitor overrides it with a
// site switch. html[data-motion] is set before first paint by the inline boot script.
const root = document.documentElement;
const KEY = "sc-motion";
const systemReduce = matchMedia("(prefers-reduced-motion: reduce)");

function stored() {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
}

export function motionOn() {
  return root.dataset.motion !== "reduce";
}

export function syncMotionSwitches(scope = document) {
  const on = motionOn();
  scope.querySelectorAll("[data-motion-toggle]").forEach((el) => {
    el.setAttribute("aria-checked", String(on));
  });
}

function apply(forced) {
  const pref = stored();
  const reduce = forced ?? (pref === "reduce" || (pref !== "full" && systemReduce.matches));
  const next = reduce ? "reduce" : "full";
  const changed = root.dataset.motion !== next;
  root.dataset.motion = next;
  syncMotionSwitches();
  if (changed) {
    document.dispatchEvent(new CustomEvent("sc:motionchange", { detail: { motion: next } }));
  }
}

export function setMotion(on) {
  try {
    // Choosing what the system already asks for clears the override.
    if (on === !systemReduce.matches) localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, on ? "full" : "reduce");
    apply();
  } catch {
    apply(!on);
  }
}

export function initPrefs() {
  document.addEventListener("click", (event) => {
    const toggle = event.target.closest("[data-motion-toggle]");
    if (!toggle) return;
    setMotion(!motionOn());
  });
  systemReduce.addEventListener("change", () => apply());
  apply();
}
