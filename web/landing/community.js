const feedList = document.querySelector("#feed-list");
const feedStatus = document.querySelector("#feed-status");
const feedTitle = document.querySelector("#feed-title");
const newPost = document.querySelector("#new-post");
const tabs = [...document.querySelectorAll(".network__tab")];
let activeRequest = null;

const categoryCopy = {
  all: {
    title: "Recent discussions",
    post: "general",
  },
  "q-a": {
    title: "Puzzle help",
    post: "q-a",
  },
  ideas: {
    title: "Theories & ideas",
    post: "ideas",
  },
  "show-and-tell": {
    title: "Investigator showcase",
    post: "show-and-tell",
  },
};

function formatDate(value) {
  return new Intl.DateTimeFormat(undefined, {
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
  meta.textContent = `${item.author} · updated ${formatDate(item.updated)} · open discussion ↗`;

  body.append(title, excerpt, meta);
  link.append(avatar, body);
  return link;
}

async function loadCategory(category, signal) {
  const copy = categoryCopy[category];
  feedTitle.textContent = copy.title;
  newPost.href =
    `https://github.com/s-ccao/shadow-castle-stem-detective/discussions/new?category=${copy.post}`;
  feedList.replaceChildren();
  feedStatus.hidden = false;
  feedStatus.textContent = "Opening the archive…";

  const response = await fetch(`/api/community?category=${encodeURIComponent(category)}`, { signal });
  if (!response.ok) {
    throw new Error(`Community archive returned ${response.status}.`);
  }
  const payload = await response.json();
  if (!Array.isArray(payload.discussions)) {
    throw new Error("Community archive returned an invalid response.");
  }
  if (payload.discussions.length === 0) {
    feedStatus.textContent = "No field notes here yet. Start the first one.";
    return;
  }
  feedStatus.hidden = true;
  feedList.replaceChildren(...payload.discussions.map(makeDiscussion));
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
    feedStatus.hidden = false;
    feedStatus.textContent = `${error.message} Open the full network to continue.`;
  } finally {
    if (activeRequest === request) {
      activeRequest = null;
    }
  }
}

tabs.forEach((tab) => {
  tab.addEventListener("click", () => selectCategory(tab.dataset.category));
});

selectCategory("all");
