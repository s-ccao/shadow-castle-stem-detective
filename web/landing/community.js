import { lang, t } from "/js/i18n.js";

const feedList = document.querySelector("#feed-list");
const feedStatus = document.querySelector("#feed-status");
const feedTitle = document.querySelector("#feed-title");
const newPost = document.querySelector("#new-post");
const tabs = [...document.querySelectorAll(".network__tab")];
let activeRequest = null;
let activeCategory = "all";
// { kind: "loading" } | { kind: "ready", discussions } | { kind: "error", status?, invalid?, message? }
let state = { kind: "loading" };

const categoryCopy = {
  all: {
    title: ["community.feed_title.all", "Recent discussions"],
    post: "general",
  },
  "q-a": {
    title: ["community.feed_title.qa", "Puzzle help"],
    post: "q-a",
  },
  ideas: {
    title: ["community.feed_title.ideas", "Theories & ideas"],
    post: "ideas",
  },
  "show-and-tell": {
    title: ["community.feed_title.show", "Investigator showcase"],
    post: "show-and-tell",
  },
};

class FeedError extends Error {
  constructor(details) {
    super(details.message || "Community archive error.");
    this.details = details;
  }
}

function formatDate(value) {
  return new Intl.DateTimeFormat(lang() === "zh" ? "zh-CN" : undefined, {
    month: "short",
    day: "numeric",
    year: new Date(value).getFullYear() === new Date().getFullYear() ? undefined : "numeric",
  }).format(new Date(value));
}

function makeDiscussion(item) {
  const link = document.createElement("a");
  link.className = "discussion";
  link.href = item.url;

  const avatar = document.createElement("img");
  avatar.className = "discussion__avatar";
  avatar.src = item.avatar;
  avatar.alt = "";
  avatar.width = 48;
  avatar.height = 48;
  avatar.loading = "lazy";
  avatar.referrerPolicy = "no-referrer";

  const body = document.createElement("div");
  const title = document.createElement("h3");
  title.textContent = item.title;
  const excerpt = document.createElement("p");
  excerpt.textContent = item.excerpt;
  const meta = document.createElement("div");
  meta.className = "discussion__meta";
  meta.textContent = [
    item.author,
    `${t("community.meta.updated", "updated")} ${formatDate(item.updated)}`,
    t("community.meta.open", "open discussion ↗"),
  ].join(" · ");

  body.append(title, excerpt, meta);
  link.append(avatar, body);
  return link;
}

function errorText(details) {
  let reason = details.message || "";
  if (details.status) {
    reason = t("community.error.status", "Community archive returned {status}.").replace("{status}", details.status);
  } else if (details.invalid) {
    reason = t("community.error.invalid", "Community archive returned an invalid response.");
  }
  return `${reason} ${t("community.status.error", "Open the full network to continue.")}`.trim();
}

function render() {
  feedTitle.textContent = t(...categoryCopy[activeCategory].title);
  if (state.kind === "ready" && state.discussions.length > 0) {
    feedStatus.hidden = true;
    feedList.replaceChildren(...state.discussions.map(makeDiscussion));
    return;
  }
  feedList.replaceChildren();
  feedStatus.hidden = false;
  if (state.kind === "loading") {
    feedStatus.textContent = t("community.status.loading", "Opening the archive…");
  } else if (state.kind === "ready") {
    feedStatus.textContent = t("community.status.empty", "No field notes here yet. Start the first one.");
  } else {
    feedStatus.textContent = errorText(state);
  }
}

async function loadCategory(category, signal) {
  activeCategory = category;
  newPost.href =
    `https://github.com/s-ccao/shadow-castle-stem-detective/discussions/new?category=${categoryCopy[category].post}`;
  state = { kind: "loading" };
  render();

  const response = await fetch(`/api/community?category=${encodeURIComponent(category)}`, { signal });
  if (!response.ok) {
    throw new FeedError({ status: response.status });
  }
  const payload = await response.json();
  if (!Array.isArray(payload.discussions)) {
    throw new FeedError({ invalid: true });
  }
  state = { kind: "ready", discussions: payload.discussions };
  render();
}

async function selectCategory(category) {
  if (activeRequest) {
    activeRequest.abort();
  }
  activeRequest = new AbortController();
  const request = activeRequest;
  tabs.forEach((tab) => {
    const active = tab.dataset.category === category;
    tab.classList.toggle("is-active", active);
    tab.setAttribute("aria-pressed", String(active));
  });
  try {
    await loadCategory(category, request.signal);
  } catch (error) {
    if (error.name === "AbortError") {
      return;
    }
    state = { kind: "error", ...(error.details || { message: error.message }) };
    render();
  } finally {
    if (activeRequest === request) {
      activeRequest = null;
    }
  }
}

tabs.forEach((tab) => {
  tab.addEventListener("click", () => selectCategory(tab.dataset.category));
});

document.addEventListener("sc:langchange", render);

selectCategory("all");
