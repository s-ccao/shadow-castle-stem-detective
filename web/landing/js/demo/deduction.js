import { pick, t, translate } from "../i18n.js";
import { motionOn } from "../prefs.js";

// The hub's demo case: link each piece of evidence to the statement it speaks
// to until one link will not hold. A mouse can drag a card onto a statement;
// any pointer can pick a card and then a statement; on the keyboard, Enter or
// Space picks and links, Escape puts the evidence down.
const SVG = "http://www.w3.org/2000/svg";
const SLOP = 6;
const ICONS = {
  drop: "M12 3.5c3.4 4.3 5.4 7.4 5.4 10a5.4 5.4 0 0 1-10.8 0c0-2.6 2-5.7 5.4-10z",
  cup: "M5 9h11v4a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5zM16 10h1.5a2.5 2.5 0 0 1 0 5H16M4 21h14",
  lock: "M7.5 11V8a4.5 4.5 0 0 1 9 0v3M5.5 11h13v9h-13zM12 14.5V17",
  lamp: "M8 20h8M12 20v-3M7.5 17h9l-1.5-4h-6zM12 13c-1.6-1.2-1.8-2.8 0-5.5 1.8 2.7 1.6 4.3 0 5.5z",
};

const esc = (text) => String(text).replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);

function styles() {
  if (document.querySelector('link[href="/css/demo.css"]')) return Promise.resolve();
  return new Promise((resolve) => {
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = "/css/demo.css";
    link.onload = link.onerror = resolve;
    document.head.append(link);
  });
}

export async function initDemo() {
  const section = document.querySelector("[data-demo]");
  const mount = section?.querySelector("[data-demo-board]");
  if (!mount) return;
  const [data] = await Promise.all([
    fetch(section.dataset.demo).then((response) => {
      if (!response.ok) throw new Error(`demo case returned ${response.status}`);
      return response.json();
    }),
    styles(),
  ]);
  board(mount, data);
}

const statementHTML = (s) => `
  <li><button type="button" class="demo-statement" data-statement="${esc(s.id)}" aria-describedby="demo-help">
  <span class="demo-statement__who"></span>
  <span class="demo-statement__text"></span>
  <span class="demo-statement__tags"></span>
  </button></li>`;

const evidenceHTML = (e) => `
  <li><button type="button" class="demo-evidence" data-evidence="${esc(e.id)}" aria-pressed="false" aria-describedby="demo-help">
  <svg class="demo-evidence__icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${ICONS[e.icon] || ICONS.drop}"/></svg>
  <span class="demo-evidence__name"></span>
  <span class="demo-evidence__text"></span>
  </button></li>`;

function board(mount, data) {
  const total = Object.values(data.links).filter((kind) => kind === "contradicts").length;
  const state = { held: null, links: new Map(), left: data.seconds, timer: 0, started: false, over: false };
  mount.innerHTML = `
  <div class="demo__hud">
  <span class="stamp demo__stamp" data-i18n="demo.stamp">Demo</span>
  <h3 class="demo__case"></h3>
  <p class="demo__chip" data-chip="time"><span data-i18n="demo.time">Time</span> <b></b></p>
  <p class="demo__chip" data-chip="links"><span data-i18n="demo.links">Links</span> <b></b></p>
  <p class="demo__chip" data-chip="found"><span data-i18n="demo.found">Contradictions</span> <b></b></p>
  <button type="button" class="demo__reset" data-reset><span data-i18n="demo.reset">Reset</span></button>
  </div>
  <p class="demo__brief"></p>
  <p class="visually-hidden" id="demo-help" data-i18n="demo.help">Choose a piece of evidence, then the statement it speaks to. Escape puts the evidence down.</p>
  <div class="demo__table">
  <svg class="demo__threads" aria-hidden="true"></svg>
  <div class="demo__col">
  <h4 class="demo__label" data-i18n="demo.statements">Statements</h4>
  <ul class="demo__statements">${data.statements.map(statementHTML).join("")}</ul>
  </div>
  <div class="demo__col">
  <h4 class="demo__label" data-i18n="demo.evidence">Evidence</h4>
  <ul class="demo__evidence">${data.evidence.map(evidenceHTML).join("")}</ul>
  </div>
  </div>
  <p class="demo__status" role="status"></p>
  <div class="demo__result" hidden></div>`;

  const $ = (selector) => mount.querySelector(selector);
  const table = $(".demo__table");
  const threads = $(".demo__threads");
  const status = $(".demo__status");
  const result = $(".demo__result");
  const chips = { time: $('[data-chip="time"]'), links: $('[data-chip="links"]'), found: $('[data-chip="found"]') };
  const statement = (id) => mount.querySelector(`[data-statement="${id}"]`);
  const evidence = (id) => mount.querySelector(`[data-evidence="${id}"]`);
  const find = (list, id) => list.find((item) => item.id === id);
  const say = (text) => {
    status.textContent = text;
  };

  function tags() {
    for (const s of data.statements) {
      statement(s.id).querySelector(".demo-statement__tags").innerHTML = [...state.links]
        .filter(([key]) => key.endsWith(`>${s.id}`))
        .map(([key, kind]) => {
          const label = kind === "contradicts" ? t("demo.tag_contradicts", "contradicts") : t("demo.tag_supports", "backs this");
          return `<span class="demo-tag" data-kind="${kind}">${esc(pick(find(data.evidence, key.split(">")[0]).name))} · ${esc(label)}</span>`;
        })
        .join("");
    }
  }

  function texts() {
    $(".demo__case").textContent = pick(data.title);
    $(".demo__brief").textContent = pick(data.brief);
    for (const s of data.statements) {
      statement(s.id).querySelector(".demo-statement__who").textContent = pick(s.who);
      statement(s.id).querySelector(".demo-statement__text").textContent = `“${pick(s.text)}”`;
    }
    for (const e of data.evidence) {
      evidence(e.id).querySelector(".demo-evidence__name").textContent = pick(e.name);
      evidence(e.id).querySelector(".demo-evidence__text").textContent = pick(e.text);
    }
    tags();
    if (state.over) showResult();
  }

  function hud(bump) {
    chips.time.querySelector("b").textContent = String(Math.max(0, state.left));
    chips.time.classList.toggle("is-low", state.started && !state.over && state.left <= 10);
    chips.links.querySelector("b").textContent = String(state.links.size);
    const found = [...state.links.values()].filter((kind) => kind === "contradicts").length;
    chips.found.querySelector("b").textContent = `${found}/${total}`;
    if (bump && motionOn()) {
      chips[bump].classList.remove("is-bump");
      void chips[bump].offsetWidth; // restart the bump
      chips[bump].classList.add("is-bump");
    }
  }

  // The clock starts with the first move and pauses while the tab is hidden.
  function run() {
    clearInterval(state.timer);
    if (!state.started || state.over || document.hidden) return;
    state.timer = setInterval(() => {
      state.left -= 1;
      hud();
      if (state.left === 10) say(t("demo.ten", "Ten seconds left."));
      if (state.left <= 0) finish(false);
    }, 1000);
  }

  function hold(id) {
    if (state.over) return;
    if (!state.started) {
      state.started = true;
      run();
    }
    state.held = id;
    mount.classList.add("is-holding");
    mount.querySelectorAll(".demo-evidence").forEach((node) => node.setAttribute("aria-pressed", String(node.dataset.evidence === id)));
    say(t("demo.held", "{name} picked up. Now choose a statement.").replace("{name}", pick(find(data.evidence, id).name)));
  }

  function release() {
    state.held = null;
    mount.classList.remove("is-holding");
    mount.querySelectorAll('.demo-evidence[aria-pressed="true"]').forEach((node) => node.setAttribute("aria-pressed", "false"));
  }

  // Threads run from the evidence card's inner edge to the statement's.
  function ends(e, s) {
    const box = table.getBoundingClientRect();
    const a = evidence(e).getBoundingClientRect();
    const b = statement(s).getBoundingClientRect();
    return [a.left - box.left, a.top + a.height / 2 - box.top, b.right - box.left, b.top + b.height / 2 - box.top];
  }

  function curve(x1, y1, x2, y2) {
    const dx = Math.max(24, (x1 - x2) / 2);
    return `M${x1} ${y1}C${x1 - dx} ${y1} ${x2 + dx} ${y2} ${x2} ${y2}`;
  }

  function place(path) {
    const [e, s] = path.dataset.key.split(">");
    path.setAttribute("d", curve(...ends(e, s)));
  }

  function draw(e, s, kind) {
    const path = document.createElementNS(SVG, "path");
    path.setAttribute("class", "demo-thread");
    path.setAttribute("pathLength", "1");
    path.dataset.key = `${e}>${s}`;
    path.dataset.kind = kind;
    threads.append(path);
    place(path);
    requestAnimationFrame(() => requestAnimationFrame(() => path.classList.add("is-drawn")));
    if (kind === "unrelated") setTimeout(() => path.remove(), motionOn() ? 1100 : 300);
  }

  function link(e, s) {
    release();
    if (state.over) return;
    const key = `${e}>${s}`;
    if (state.links.has(key)) {
      say(t("demo.already", "Those two are already linked."));
      return;
    }
    const kind = data.links[key] || "unrelated";
    draw(e, s, kind);
    if (kind === "unrelated") {
      const node = statement(s);
      node.classList.remove("is-wrong");
      void node.offsetWidth; // restart the shake
      node.classList.add("is-wrong");
      say(t("demo.unrelated", "No bearing: that evidence says nothing about this statement."));
      return;
    }
    state.links.set(key, kind);
    tags();
    hud(kind === "contradicts" ? "found" : "links");
    if (kind === "contradicts") {
      statement(s).classList.add("is-hit");
      evidence(e).classList.add("is-hit");
      finish(true);
    } else {
      say(t("demo.supports", "Consistent: the evidence backs the statement."));
    }
  }

  function showResult(focus = false) {
    const won = mount.classList.contains("is-solved");
    result.hidden = false;
    result.innerHTML = won
      ? `<h4 class="demo__result-title" tabindex="-1">${esc(t("demo.solved_title", "Contradiction found."))}</h4>
  <p>${esc(pick(data.solved))}</p>
  <p class="demo__result-note">${esc(t("demo.solved_note", "Evidence Rush will deal a fresh case like this every round. It is not playable yet."))}</p>
  <div class="demo__result-actions">
  <a class="btn btn--primary" href="${esc(data.next.play)}"><span>${esc(t("hub.play", "Play Shadow Castle"))}</span> <span aria-hidden="true">▶</span></a>
  <a class="btn btn--ghost" href="${esc(data.next.case)}"><span>${esc(t("demo.case_file", "Evidence Rush case file"))}</span> <span aria-hidden="true">→</span></a>
  <button type="button" class="btn btn--ghost" data-reset>${esc(t("demo.again", "Play the demo again"))}</button>
  </div>`
      : `<h4 class="demo__result-title" tabindex="-1">${esc(t("demo.timeout_title", "Time's up."))}</h4>
  <p>${esc(pick(data.hint))}</p>
  <div class="demo__result-actions">
  <button type="button" class="btn btn--primary" data-reset>${esc(t("demo.try_again", "Try again"))}</button>
  </div>`;
    if (!focus) return;
    say(won ? pick(data.solved) : `${t("demo.timeout_title", "Time's up.")} ${pick(data.hint)}`);
    result.querySelector(".demo__result-title").focus({ preventScroll: true });
    result.scrollIntoView({ block: "nearest", behavior: motionOn() ? "smooth" : "auto" });
  }

  function finish(won) {
    state.over = true;
    clearInterval(state.timer);
    release();
    mount.classList.add(won ? "is-solved" : "is-timeout");
    hud();
    showResult(true);
  }

  function reset() {
    clearInterval(state.timer);
    Object.assign(state, { held: null, left: data.seconds, started: false, over: false });
    state.links.clear();
    threads.replaceChildren();
    mount.classList.remove("is-solved", "is-timeout");
    mount.querySelectorAll(".is-hit").forEach((node) => node.classList.remove("is-hit"));
    result.hidden = true;
    result.replaceChildren();
    release();
    tags();
    hud();
    say("");
    mount.querySelector(".demo-evidence").focus({ preventScroll: true });
  }

  // A mouse or pen can drag; touch uses pick-then-place so the page still scrolls.
  let dragged = false;
  mount.addEventListener("pointerdown", (event) => {
    const card = event.target.closest(".demo-evidence");
    if (!card || state.over || event.button !== 0 || event.pointerType === "touch") return;
    const id = card.dataset.evidence;
    const from = card.getBoundingClientRect();
    const grab = [event.clientX - from.left, event.clientY - from.top];
    let ghost = null;
    let line = null;
    let over = null;
    const move = (ev) => {
      if (ev.pointerId !== event.pointerId) return;
      if (!ghost) {
        if (Math.hypot(ev.clientX - event.clientX, ev.clientY - event.clientY) < SLOP) return;
        hold(id);
        ghost = card.cloneNode(true);
        ghost.removeAttribute("data-evidence");
        ghost.removeAttribute("aria-describedby");
        ghost.setAttribute("aria-hidden", "true");
        ghost.classList.add("demo-ghost");
        ghost.style.width = `${from.width}px`;
        document.body.append(ghost);
        line = document.createElementNS(SVG, "path");
        line.setAttribute("class", "demo-thread demo-thread--live");
        threads.append(line);
      }
      ghost.style.translate = `${ev.clientX - grab[0]}px ${ev.clientY - grab[1]}px`;
      const target = document.elementFromPoint(ev.clientX, ev.clientY)?.closest(".demo-statement") || null;
      if (target !== over) {
        over?.classList.remove("is-over");
        over = target;
        over?.classList.add("is-over");
      }
      const box = table.getBoundingClientRect();
      const [x1, y1] = ends(id, data.statements[0].id);
      line.setAttribute("d", curve(x1, y1, ev.clientX - box.left, ev.clientY - box.top));
    };
    const end = (ev) => {
      if (ev.pointerId !== event.pointerId) return;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
      window.removeEventListener("pointercancel", end);
      if (!ghost) return;
      dragged = true;
      setTimeout(() => (dragged = false));
      ghost.remove();
      line.remove();
      over?.classList.remove("is-over");
      if (over && ev.type === "pointerup") link(id, over.dataset.statement);
      else {
        release();
        say(t("demo.released", "Evidence put down."));
      }
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", end);
    window.addEventListener("pointercancel", end);
  });

  mount.addEventListener("click", (event) => {
    if (dragged) return;
    if (event.target.closest("[data-reset]")) {
      reset();
      return;
    }
    const card = event.target.closest(".demo-evidence");
    const target = event.target.closest(".demo-statement");
    if (card && !state.over) {
      if (state.held === card.dataset.evidence) {
        release();
        say(t("demo.released", "Evidence put down."));
      } else {
        hold(card.dataset.evidence);
      }
    } else if (target && !state.over) {
      if (state.held) link(state.held, target.dataset.statement);
      else say(t("demo.pick_first", "Pick up a piece of evidence first."));
    }
  });

  mount.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || !state.held) return;
    event.stopPropagation();
    release();
    say(t("demo.released", "Evidence put down."));
  });

  new ResizeObserver(() => threads.querySelectorAll("path[data-key]").forEach(place)).observe(table);
  document.addEventListener("visibilitychange", run);
  document.addEventListener("sc:langchange", texts);
  translate(mount);
  texts();
  hud();
  mount.classList.add("is-live");
}
