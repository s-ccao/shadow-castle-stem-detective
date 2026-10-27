import { motionOn, syncMotionSwitches } from "./prefs.js";
import { lang, pick, t, translate } from "./i18n.js";

// The case-file library: a modal over any page. Opened from [data-library-open]
// links (which fall back to /games), the castle's windows and #cases deep links.
// Selection follows hover and focus; nothing advances on its own.
const root = document.documentElement;
const STATUS = { playable: "Playable", "in-development": "In development", "coming-soon": "Coming soon" };
const NOTE = {
  "in-development": ["case.status.in-development", "In development and not playable yet."],
  "coming-soon": ["case.status.coming-soon", "Not playable yet. When the game is ready, this page will open it."],
};

let games = null;
let loading = null;
let dialog = null;
let ui = null;
let rows = [];
let current = -1;
let opener = null;
let pushed = false;
let slideTimer = 0;
let pointerType = "mouse";
let selectedAtPress = -1;

function escape(text) {
  return String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}

export function prefetch() {
  loading ||= fetch("/data/games.json")
    .then((response) => {
      if (!response.ok) throw new Error(`catalogue returned ${response.status}`);
      return response.json();
    })
    .then((data) => (games = [...data.games].sort((a, b) => a.order - b.order)))
    .catch((error) => {
      loading = null;
      throw error;
    });
  return loading;
}

function build() {
  dialog = document.createElement("dialog");
  dialog.className = "library";
  dialog.setAttribute("aria-labelledby", "library-title");
  dialog.innerHTML = `
    <div class="library__veil" data-library-close></div>
    <div class="library__panel">
      <div class="library__stage">
        <div class="library__media" aria-hidden="true"></div>
        <div class="library__shade" aria-hidden="true"></div>
        <div class="library__info">
          <p class="library__index" aria-hidden="true"><b></b> / <span></span></p>
          <span class="stamp library__stamp"></span>
          <h3 class="library__name"></h3>
          <p class="library__alt"></p>
          <p class="library__meta"></p>
          <p class="library__tagline"></p>
          <div class="library__actions"></div>
        </div>
      </div>
      <div class="library__side">
        <div class="library__head">
          <h2 id="library-title" data-i18n="library.title">Case files</h2>
          <p class="library__sub"></p>
        </div>
        <ul class="library__list"><li class="library__glider" aria-hidden="true"></li></ul>
        <div class="library__foot">
          <p class="library__hint" data-i18n="library.hint">↑↓ browse · Enter open · Esc close</p>
          <div class="library__tools">
            <button type="button" class="motion-switch" role="switch" aria-checked="true" data-motion-toggle>
              <span class="motion-switch__track" aria-hidden="true"><span class="motion-switch__knob"></span></span>
              <span data-i18n="prefs.motion">Animations</span>
            </button>
            <a class="library__link" href="/community" data-i18n="nav.community">Community</a>
          </div>
        </div>
      </div>
      <button type="button" class="library__close" data-library-close aria-label="Close case files" data-i18n-attr="aria-label:library.close">
        <span aria-hidden="true">✕</span>
      </button>
    </div>`;
  document.body.append(dialog);
  ui = {
    media: dialog.querySelector(".library__media"),
    info: dialog.querySelector(".library__info"),
    index: dialog.querySelector(".library__index b"),
    total: dialog.querySelector(".library__index span"),
    stamp: dialog.querySelector(".library__stamp"),
    name: dialog.querySelector(".library__name"),
    alt: dialog.querySelector(".library__alt"),
    meta: dialog.querySelector(".library__meta"),
    tagline: dialog.querySelector(".library__tagline"),
    actions: dialog.querySelector(".library__actions"),
    sub: dialog.querySelector(".library__sub"),
    list: dialog.querySelector(".library__list"),
    glider: dialog.querySelector(".library__glider"),
  };

  rows = games.map((game, index) => {
    const item = document.createElement("li");
    const row = document.createElement("a");
    row.className = "library__row";
    row.href = `/games/${game.slug}`;
    row.tabIndex = -1;
    row.style.setProperty("--row-accent", `var(${game.accent})`);
    row.style.setProperty("--k", String(index));
    const cover = game.media?.cover;
    const thumb = cover
      ? `<img src="${escape(cover.src)}" alt="" width="${cover.width}" height="${cover.height}" loading="lazy" decoding="async" />`
      : `<svg class="emblem" viewBox="0 0 64 64" focusable="false"><use href="#emblem-${escape(game.emblem)}"></use></svg>`;
    row.innerHTML = `
      <span class="library__thumb" aria-hidden="true">${thumb}</span>
      <span class="library__row-text">
        <span class="library__row-name"></span>
        <span class="library__row-meta"></span>
      </span>`;
    row.addEventListener("pointerenter", (event) => {
      if (event.pointerType === "mouse") select(index);
    });
    row.addEventListener("focus", () => select(index));
    row.addEventListener("pointerdown", () => {
      // The tap focuses (and so selects) the row before its click arrives: remember what was selected first.
      selectedAtPress = current;
    });
    row.addEventListener("click", (event) => {
      // On touch, the first tap shows the case; the second opens its page. Keyboard Enter always opens.
      if (event.detail !== 0 && pointerType !== "mouse" && selectedAtPress !== index) {
        event.preventDefault();
        select(index);
      }
    });
    item.append(row);
    ui.list.append(item);
    return row;
  });

  dialog.addEventListener("pointerdown", (event) => {
    pointerType = event.pointerType || "mouse";
  });
  dialog.addEventListener("click", (event) => {
    if (event.target.closest("[data-library-close]")) closeLibrary();
  });
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeLibrary();
  });
  ui.list.addEventListener("keydown", (event) => {
    const moves = { ArrowDown: current + 1, ArrowUp: current - 1, Home: 0, End: games.length - 1 };
    if (!(event.key in moves)) return;
    event.preventDefault();
    select(moves[event.key], { focus: true });
  });
  document.addEventListener("sc:langchange", () => {
    if (!dialog) return;
    renderText();
    if (current >= 0) renderInfo(games[current], false);
  });
  translate(dialog);
  syncMotionSwitches(dialog);
}

function renderText() {
  const open = games.filter((game) => game.status === "playable").length;
  ui.sub.textContent = t("library.sub", "{open} open · {soon} coming soon")
    .replace("{open}", String(open))
    .replace("{soon}", String(games.length - open));
  ui.total.textContent = String(games.length).padStart(2, "0");
  games.forEach((game, index) => {
    const row = rows[index];
    row.querySelector(".library__row-name").textContent = pick(game.short);
    row.querySelector(".library__row-meta").textContent = `${t(`status.${game.status}`, STATUS[game.status])} · ${pick(game.genre)}`;
  });
}

function layerFor(game, index) {
  let layer = ui.media.querySelector(`[data-layer="${index}"]`);
  if (layer) return layer;
  layer = document.createElement("div");
  layer.dataset.layer = String(index);
  layer.style.setProperty("--case-accent", `var(${game.accent})`);
  const stills = [game.media?.cover, ...(game.media?.stills || [])].filter(Boolean);
  if (stills.length) {
    layer.className = "library__layer library__layer--stills";
    layer.innerHTML = stills.map((still) => `<img alt="" data-src="${escape(still.src)}" decoding="async" />`).join("");
  } else {
    layer.className = "library__layer library__layer--case";
    layer.innerHTML = `
      <div class="library__case-art">
        <span class="library__case-halo"></span>
        <svg class="emblem library__case-emblem" viewBox="0 0 64 64" focusable="false"><use href="#emblem-${escape(game.emblem)}"></use></svg>
      </div>`;
  }
  ui.media.append(layer);
  return layer;
}

function playStills(layer) {
  clearInterval(slideTimer);
  const images = [...layer.querySelectorAll("img")];
  if (!images.length) return;
  images.forEach((img) => {
    if (!img.src) img.src = img.dataset.src;
  });
  let shown = 0;
  images.forEach((img, i) => img.classList.toggle("is-shown", i === 0));
  if (!motionOn() || images.length < 2) return;
  slideTimer = setInterval(() => {
    images[shown].classList.remove("is-shown");
    shown = (shown + 1) % images.length;
    images[shown].classList.add("is-shown");
  }, 3400);
}

function renderInfo(game, animate = true) {
  const name = pick(game.name);
  ui.index.textContent = String(current + 1).padStart(2, "0");
  ui.stamp.dataset.status = game.status;
  ui.stamp.textContent = t(`status.${game.status}`, STATUS[game.status]);
  ui.name.setAttribute("aria-label", name);
  ui.name.innerHTML = `<span aria-hidden="true">${[...name]
    .map((ch, i) => (ch === " " ? " " : `<span class="ch" style="--i:${i}">${escape(ch)}</span>`))
    .join("")}</span>`;
  const other = lang() === "zh" ? game.name.en : game.name.zh;
  ui.alt.textContent = other;
  ui.alt.lang = lang() === "zh" ? "en" : "zh-CN";
  ui.meta.textContent = `${pick(game.genre)} · ${pick(game.session)}`;
  ui.tagline.textContent = pick(game.tagline);
  const caseLink = `<a class="btn btn--ghost" href="/games/${escape(game.slug)}"><span>${escape(t("cards.read_case", "Read the case file"))}</span> <span aria-hidden="true">→</span></a>`;
  if (game.status === "playable" && game.links?.play) {
    ui.actions.innerHTML =
      `<a class="btn btn--primary" href="${escape(game.links.play)}" data-magnet><span>${escape(t("cards.play_online", "Play online"))}</span> <span aria-hidden="true">▶</span></a>` +
      caseLink;
  } else {
    const [key, english] = NOTE[game.status] || NOTE["coming-soon"];
    ui.actions.innerHTML = `<p class="library__note">${escape(t(key, english))}</p>${caseLink}`;
  }
  if (!animate) {
    ui.name.classList.add("is-in");
    ui.info.classList.add("is-in");
    return;
  }
  ui.name.classList.remove("is-in");
  ui.info.classList.remove("is-in");
  void ui.name.offsetWidth; // restart the ink-in for the new name
  requestAnimationFrame(() => {
    ui.name.classList.add("is-in");
    ui.info.classList.add("is-in");
  });
}

function placeGlider() {
  const row = rows[current];
  if (!row) return;
  const item = row.parentElement;
  ui.glider.style.height = `${item.offsetHeight}px`;
  ui.glider.style.translate = `0 ${item.offsetTop}px`;
}

function select(index, { focus = false } = {}) {
  index = (index + games.length) % games.length;
  if (index !== current) {
    current = index;
    const game = games[index];
    dialog.style.setProperty("--stage-accent", `var(${game.accent})`);
    rows.forEach((row, i) => {
      row.classList.toggle("is-selected", i === index);
      row.tabIndex = i === index ? 0 : -1;
    });
    placeGlider();
    const layer = layerFor(game, index);
    ui.media.querySelectorAll(".library__layer").forEach((other) => other.classList.toggle("is-on", other === layer));
    clearInterval(slideTimer);
    if (layer.classList.contains("library__layer--stills")) playStills(layer);
    renderInfo(game);
  }
  if (focus) rows[index].focus();
}

export async function openLibrary(slug, from) {
  try {
    await prefetch();
  } catch (error) {
    console.error(error);
    location.href = "/games";
    return;
  }
  if (!dialog) build();
  renderText();
  syncMotionSwitches(dialog);
  const wanted = games.findIndex((game) => game.slug === slug);
  if (!dialog.open) {
    opener = from || document.activeElement;
    dialog.showModal();
    root.classList.add("library-open");
    requestAnimationFrame(() => dialog.classList.add("is-open"));
    if (location.hash !== "#cases" && !location.hash.startsWith("#cases/")) {
      history.pushState({ scLibrary: true }, "", "#cases");
      pushed = true;
    }
  }
  select(wanted >= 0 ? wanted : Math.max(current, 0), { focus: true });
  requestAnimationFrame(placeGlider);
}

export function closeLibrary({ fromHistory = false } = {}) {
  if (!dialog?.open || dialog.classList.contains("is-closing")) return;
  dialog.classList.remove("is-open");
  dialog.classList.add("is-closing");
  clearInterval(slideTimer);
  const finish = () => {
    dialog.classList.remove("is-closing");
    dialog.close();
    root.classList.remove("library-open");
    if (opener && opener.isConnected && typeof opener.focus === "function") opener.focus({ preventScroll: true });
  };
  if (motionOn()) setTimeout(finish, 480);
  else finish();
  if (fromHistory) {
    pushed = false;
  } else if (pushed && history.state?.scLibrary) {
    pushed = false;
    history.back();
  } else if (location.hash.startsWith("#cases")) {
    history.replaceState(history.state, "", location.pathname + location.search);
  }
}

window.addEventListener("popstate", () => {
  const wantsOpen = location.hash.startsWith("#cases");
  if (dialog?.open && !wantsOpen) closeLibrary({ fromHistory: true });
  else if (!dialog?.open && wantsOpen) openLibrary(location.hash.split("/")[1]);
});
