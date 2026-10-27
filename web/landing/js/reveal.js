import { addTicker, clamp, onScroll } from "./loop.js";
import { motionOn } from "./prefs.js";

// Scroll storytelling. Nothing is hidden unless JavaScript runs, motion is on,
// and the element starts below the fold, so a failure never leaves content invisible.
const RISE = [
  ".section-head",
  ".featured__frame",
  ".featured__copy",
  ".case-card",
  ".open-desk__list li",
  ".case-premise",
  ".case-planned",
  ".other-cases__head",
  ".brief__statement",
  ".case-facts",
  ".section-heading",
  ".feature-capture",
  ".science__intro",
  ".development__heading",
  ".milestones li",
  ".history-link",
  ".network__body > *",
].join(",");
const SWEEP = [
  ".section-head h2",
  ".featured__title",
  ".case-premise h2",
  ".case-planned h2",
  ".other-cases__head h2",
  ".brief__statement h2",
  ".section-heading h2",
  ".science__intro h2",
  ".development__heading h2",
].join(",");
const DEVELOP = "[data-develop], .feature-capture";
const COUNT = "[data-countup], .case-facts dt";

const root = document.documentElement;

function belowFold(el) {
  const box = el.getBoundingClientRect();
  return box.top > window.innerHeight * 0.9 || box.bottom < 0;
}

function once(selector, options, onEnter) {
  const io = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      io.unobserve(entry.target);
      onEnter(entry.target);
    }
  }, options);
  const items = [...document.querySelectorAll(selector)];
  items.forEach((el) => io.observe(el));
  return items;
}

function countUp(el) {
  const final = el.dataset.final || el.textContent.trim();
  el.dataset.final = final;
  const match = /^(\D*)(\d+)(.*)$/.exec(final);
  if (!match || !motionOn()) {
    el.textContent = final;
    return;
  }
  const [, before, digits, after] = match;
  const target = Number(digits);
  const start = performance.now();
  addTicker((now) => {
    const k = clamp((now - start) / 1300, 0, 1);
    const eased = 1 - Math.pow(1 - k, 4);
    el.textContent = k < 1 ? `${before}${Math.round(target * eased)}${after}` : final;
    return k < 1;
  });
}

function progressThread() {
  const thread = document.createElement("div");
  thread.className = "scroll-thread";
  thread.setAttribute("aria-hidden", "true");
  document.body.append(thread);
  onScroll((y) => {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    thread.style.transform = `scaleX(${max > 0 ? clamp(y / max, 0, 1).toFixed(4) : 0})`;
  });
}

// The development milestones: a brass thread runs down the list and lights each seal.
function milestoneThread() {
  const list = document.querySelector(".milestones");
  if (!list) return;
  const items = [...list.children];
  list.classList.add("is-threaded");
  onScroll(() => {
    const mark = window.innerHeight * 0.6;
    const box = list.getBoundingClientRect();
    list.style.setProperty("--thread", clamp((mark - box.top) / box.height, 0, 1).toFixed(4));
    for (const item of items) item.classList.toggle("is-lit", item.getBoundingClientRect().top + 24 < mark);
  });
}

export function initReveal() {
  root.classList.add("js-ready");
  progressThread();
  milestoneThread();
  if (!("IntersectionObserver" in window)) return;
  const full = motionOn();

  const rising = new Set();
  if (full) {
    for (const el of document.querySelectorAll(RISE)) {
      if (belowFold(el)) rising.add(el);
    }
    for (const el of rising) {
      const peers = [...el.parentElement.children].filter((peer) => rising.has(peer));
      el.style.setProperty("--d", String(Math.max(0, peers.indexOf(el)) % 4));
      el.classList.add("rv");
    }
    once(".rv", { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }, (el) => el.classList.add("is-in"));

    for (const el of document.querySelectorAll(DEVELOP)) {
      if (belowFold(el)) el.classList.add("develop");
    }
    once(".develop", { threshold: 0.25 }, (el) => el.classList.add("is-developed"));
  }

  once(SWEEP, { threshold: 0.6 }, (el) => {
    if (!motionOn()) return;
    el.classList.add("is-sweeping");
    el.addEventListener("animationend", () => el.classList.remove("is-sweeping"), { once: true });
  });
  once(COUNT, { threshold: 0.6 }, countUp);

  // Turning motion off mid-page shows everything that was still waiting.
  document.addEventListener("sc:motionchange", () => {
    if (motionOn()) return;
    document.querySelectorAll(".rv:not(.is-in)").forEach((el) => el.classList.add("is-in"));
    document.querySelectorAll(".develop:not(.is-developed)").forEach((el) => el.classList.add("is-developed"));
  });
}
