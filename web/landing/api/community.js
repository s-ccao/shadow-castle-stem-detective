const CATEGORY_SLUGS = new Set(["all", "q-a", "ideas", "show-and-tell"]);
const DISCUSSIONS_BASE =
  "https://github.com/s-ccao/shadow-castle-stem-detective/discussions";

function decodeXml(value) {
  return value
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&amp;", "&");
}

function textContent(xml, tag) {
  const match = xml.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</${tag}>`));
  return match ? decodeXml(match[1]).replace(/\s+/g, " ").trim() : "";
}

function attribute(xml, tag, name) {
  const match = xml.match(new RegExp(`<${tag}\\s[^>]*${name}="([^"]+)"[^>]*>`));
  return match ? decodeXml(match[1]) : "";
}

function excerptFromHtml(value) {
  const plain = decodeXml(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return plain.length > 220 ? `${plain.slice(0, 217).trimEnd()}…` : plain;
}

function parseFeed(xml) {
  const entries = xml.match(/<entry>[\s\S]*?<\/entry>/g) || [];
  return entries.map((entry) => {
    const rawContent = entry.match(/<content[^>]*>([\s\S]*?)<\/content>/)?.[1] || "";
    return {
      title: textContent(entry, "title"),
      url: attribute(entry, "link", "href"),
      author: textContent(entry, "name"),
      avatar: attribute(entry, "media:thumbnail", "url").replace(/([?&])s=\d+/, "$1s=96"),
      updated: textContent(entry, "updated"),
      excerpt: excerptFromHtml(rawContent),
    };
  });
}

module.exports = async function communityFeed(request, response) {
  if (request.method !== "GET") {
    response.setHeader("Allow", "GET");
    response.status(405).json({ error: "Method not allowed." });
    return;
  }

  const category = String(request.query.category || "all");
  if (!CATEGORY_SLUGS.has(category)) {
    response.status(400).json({ error: "Unknown community category." });
    return;
  }

  const feedUrl =
    category === "all"
      ? `${DISCUSSIONS_BASE}.atom`
      : `${DISCUSSIONS_BASE}/categories/${category}.atom`;
  let upstream;
  try {
    upstream = await fetch(feedUrl, {
      headers: { "User-Agent": "Shadow-Castle-Community/1.0" },
      signal: AbortSignal.timeout(6000),
    });
  } catch (error) {
    response.status(502).json({ error: `Community feed unavailable: ${error.message}` });
    return;
  }
  if (!upstream.ok) {
    response.status(502).json({ error: `Community feed returned ${upstream.status}.` });
    return;
  }

  const discussions = parseFeed(await upstream.text());
  response.setHeader("Cache-Control", "public, s-maxage=60, stale-while-revalidate=300");
  response.status(200).json({ discussions });
};
