import { addTicker, onScroll } from "./loop.js";
import { motionOn } from "./prefs.js";

// The story layer, three small rituals of a case being opened:
//   - the first page of a visit opens like a door seen through its keyhole;
//   - chapter headings resolve out of alchemical and runic cipher as they arrive;
//   - Roman case numerals drift behind each chapter.
// Each is decoration only and stands down under reduced motion (the numerals stay,
// still). Headings keep their accessible name while they decode.
const LATIN = "☉☽☿♀♂♃♄△▽ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛞᛟ0123456789";
const CJK = "城影谜钥证月符炼光痕迹镜秘案锁烛";
const KEEP = /[\s.,!?;:'"’“”—–\-·()（）。，！？、：；]/;
const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
const SEEN = "sc-keyhole";

// Returns how long the keyhole holds the screen, so the first heading waits for it.
function keyhole() {
  const replay = /[?&]intro=1(&|$)/.test(location.search);
  try {
    if (!replay && sessionStorage.getItem(SEEN)) return 0;
    sessionStorage.setItem(SEEN, "1");
  } catch {
    return 0;
  }
  if (!motionOn() || window.scrollY > 40 || location.hash) return 0;
  const veil = document.createElement("div");
  veil.className = "night-keyhole";
  veil.setAttribute("aria-hidden", "true");
  veil.addEventListener("animationend", () => veil.remove());
  document.body.append(veil);
  setTimeout(() => veil.remove(), 2600);
  return 1300;
}

function decode(el, duration) {
  const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) if (walker.currentNode.nodeValue.trim()) nodes.push({ node: walker.currentNode, text: walker.currentNode.nodeValue });
  if (!nodes.length) return;
  const total = nodes.reduce((sum, item) => sum + item.text.length, 0);
  const hadLabel = el.hasAttribute("aria-label");
  if (!hadLabel) el.setAttribute("aria-label", el.textContent.trim());
  const height = el.style.minHeight;
  el.style.minHeight = `${el.getBoundingClientRect().height}px`;
  const began = performance.now();
  let swapped = 0;
  const finish = () => {
    for (const item of nodes) item.node.nodeValue = item.text;
    if (!hadLabel) el.removeAttribute("aria-label");
    el.style.minHeight = height;
  };
  addTicker((now) => {
    // A language switch replaces the text: the old nodes are gone, so stop here.
    if (!nodes[0].node.isConnected) {
      if (!hadLabel) el.removeAttribute("aria-label");
      el.style.minHeight = height;
      return false;
    }
    const progress = Math.min(1, (now - began) / duration);
    if (progress >= 1 || !motionOn()) {
      finish();
      return false;
    }
    if (now - swapped < 45) return true;
    swapped = now;
    const resolved = Math.floor(progress ** 0.8 * total);
    let offset = 0;
    for (const item of nodes) {
      let out = "";
      for (let i = 0; i < item.text.length; i += 1) {
        const ch = item.text[i];
        if (offset + i < resolved || KEEP.test(ch)) out += ch;
        else {
          const set = /[\u3400-\u9fff]/.test(ch) ? CJK : LATIN;
          out += set[Math.floor(Math.random() * set.length)];
        }
      }
      item.node.nodeValue = out;
      offset += item.text.length;
    }
    return true;
  });
}

function cipherHeadings(delay) {
  if (!motionOn() || !("IntersectionObserver" in window)) return;
  const watcher = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        watcher.unobserve(entry.target);
        const first = entry.target.matches("h1");
        setTimeout(() => decode(entry.target, first ? 1300 : 950), first ? delay : 0);
      }
    },
    { threshold: 0.6 },
  );
  document.querySelectorAll("main h1, main h2").forEach((heading) => watcher.observe(heading));
}

function caseNumerals() {
  const chapters = [...document.querySelectorAll("main > section")].filter(
    (section) => !section.matches(".hero, .hub-hero, .case-hero, .other-cases, .archive-head"),
  );
  if (chapters.length < 2) return;
  const numerals = chapters.slice(0, ROMAN.length).map((section, i) => {
    if (getComputedStyle(section).position === "static") section.style.position = "relative";
    section.style.isolation = "isolate";
    const numeral = document.createElement("span");
    numeral.className = "night-numeral";
    numeral.setAttribute("aria-hidden", "true");
    numeral.textContent = ROMAN[i];
    section.prepend(numeral);
    return numeral;
  });
  if ("IntersectionObserver" in window) {
    const shown = new IntersectionObserver(
      (entries) => entries.forEach((entry) => entry.isIntersecting && entry.target.classList.add("is-in")),
      { threshold: 0.15 },
    );
    numerals.forEach((numeral) => shown.observe(numeral));
  } else {
    numerals.forEach((numeral) => numeral.classList.add("is-in"));
  }
  onScroll(() => {
    const h = window.innerHeight;
    for (const numeral of numerals) {
      if (!motionOn()) {
        numeral.style.translate = "";
        continue;
      }
      const box = numeral.parentElement.getBoundingClientRect();
      if (box.bottom < -200 || box.top > h + 200) continue;
      numeral.style.translate = `0 ${((box.top - h * 0.3) * -0.16).toFixed(1)}px`;
    }
  });
}

export function initStory() {
  if (matchMedia("(forced-colors: active)").matches) return;
  const delay = keyhole();
  cipherHeadings(delay);
  caseNumerals();
}
