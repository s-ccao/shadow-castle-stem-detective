#!/usr/bin/env python3
"""Check web/landing before it is deployed. Exits 1 on any error.

  * generated files match their sources (tools/site_build.py --check)
  * every data-i18n key and every t("key") in JavaScript has a Chinese string,
    and data-i18n elements are leaves (their text is replaced wholesale)
  * ids are unique per page; internal links, #fragments and assets resolve
  * images carry alt text and intrinsic size; pages carry a title, a
    description and a canonical URL
  * JavaScript module imports and stylesheet url()s resolve
  * the game catalogue keeps its promises: nothing offers a play link unless
    it is playable, every player-facing field exists in both languages,
    reserved platform features stay switched off until they are built
"""
from __future__ import annotations

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import site_build  # noqa: E402

SITE = site_build.SITE
ROOT = site_build.ROOT
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
STATUSES = {"playable", "in-development", "coming-soon"}
KINDS = {"flagship", "standalone", "mini"}
RESERVED = ("embed", "scores", "leaderboard")


class Page(HTMLParser):
    def __init__(self, path: Path) -> None:
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids: list[str] = []
        self.keys: list[str] = []
        self.urls: list[tuple[str, str]] = []
        self.errors: list[str] = []
        self.has_title = False
        self.has_description = False
        self.has_canonical = False
        self.stack: list[tuple[str, str | None]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.visit(tag, dict(attrs))
        if tag not in VOID:
            self.stack.append((tag, dict(attrs).get("data-i18n")))

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.visit(tag, dict(attrs))

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break

    def visit(self, tag: str, a: dict[str, str | None]) -> None:
        for open_tag, key in self.stack:
            if key:
                self.errors.append(f'<{open_tag} data-i18n="{key}"> wraps a <{tag}>; translated text would erase it')
        if a.get("id"):
            self.ids.append(a["id"])
        for name in ("data-i18n", "data-i18n-html"):
            if a.get(name):
                self.keys.append(a[name])
        for pair in (a.get("data-i18n-attr") or "").split(";"):
            if ":" in pair:
                self.keys.append(pair.split(":", 1)[1].strip())
        if tag == "title":
            self.has_title = True
        if tag == "meta" and a.get("name") == "description" and a.get("content"):
            self.has_description = True
        if tag == "link" and a.get("rel") == "canonical" and a.get("href"):
            self.has_canonical = True
        if tag == "img":
            if "alt" not in a:
                self.errors.append(f"<img src=\"{a.get('src')}\"> has no alt attribute")
            if not (a.get("width") and a.get("height")):
                self.errors.append(f"<img src=\"{a.get('src')}\"> has no intrinsic width/height")
        rel = (a.get("rel") or "").split()
        if tag in {"a", "use"} or (tag == "link" and not {"preconnect", "dns-prefetch"} & set(rel)):
            if a.get("href"):
                self.urls.append((tag, a["href"]))
        for name in ("src", "poster", "data-src", "data-zh-src", "data-demo"):
            if a.get(name):
                self.urls.append((tag, a[name]))
        for name in ("srcset", "data-srcset", "data-zh-srcset"):
            for candidate in (a.get(name) or "").split(","):
                if candidate.strip():
                    self.urls.append((tag, candidate.strip().split()[0]))


def parse(path: Path) -> Page:
    page = Page(path)
    page.feed(path.read_text(encoding="utf-8"))
    page.close()
    return page


def deployable_pages() -> list[Path]:
    pages = [SITE / name for name in site_build.HAND_WRITTEN]
    if (SITE / "404.html").exists() and SITE / "404.html" not in pages:
        pages.append(SITE / "404.html")
    pages += sorted((SITE / "games").glob("*.html"))
    return pages


def resolve(url: str, page: Path) -> tuple[Path | None, str]:
    """Map a site URL to the file Vercel would serve (cleanUrls), plus its fragment."""
    split = urlsplit(url)
    if split.scheme or split.netloc or url.startswith(("mailto:", "tel:", "data:", "blob:", "javascript:")):
        return None, ""
    if not split.path:
        return page, split.fragment
    if split.path.startswith("/"):
        base = SITE / split.path.lstrip("/")
    else:
        base = (page.parent / split.path).resolve()
    if split.path.startswith("/api/"):
        target = SITE / "api" / (Path(split.path).name + ".js")
        return (target if target.exists() else base), ""
    if split.path == "/":
        return SITE / "index.html", split.fragment
    for candidate in (base, base.with_name(base.name + ".html"), base / "index.html"):
        if candidate.is_file():
            return candidate, split.fragment
    return base, split.fragment


def check_pages(errors: list[str], used_keys: set[str]) -> None:
    pages = {path: parse(path) for path in deployable_pages()}
    cache: dict[Path, Page] = dict(pages)
    for path, page in pages.items():
        name = path.relative_to(SITE)
        errors.extend(f"{name}: {message}" for message in page.errors)
        seen: set[str] = set()
        for ident in page.ids:
            if ident in seen:
                errors.append(f"{name}: duplicate id '{ident}'")
            seen.add(ident)
        for flag, label in ((page.has_title, "<title>"), (page.has_description, "meta description"), (page.has_canonical, "canonical link")):
            if not flag:
                errors.append(f"{name}: missing {label}")
        used_keys.update(page.keys)
        for tag, url in page.urls:
            target, fragment = resolve(url, path)
            if target is None:
                continue
            if not target.exists():
                errors.append(f"{name}: <{tag}> points at {url}, which does not exist")
                continue
            if fragment and target.suffix == ".html":
                if target not in cache:
                    cache[target] = parse(target)
                if fragment not in cache[target].ids:
                    errors.append(f"{name}: <{tag}> points at {url}, but #{fragment} is not on that page")


def check_scripts(errors: list[str], used_keys: set[str]) -> None:
    imports = re.compile(r"""(?:from\s+|import\s*\(\s*|import\s+)["'](\.{1,2}/[^"']+|/js/[^"']+)["']""")
    # Any string literal shaped like a dictionary key ("community.tab.all") counts as a
    # use, whether it is passed to t() directly or kept in a table first.
    keys = re.compile(r"""["']([a-z][a-z0-9_]*(?:\.[a-z0-9_-]+)+)["']""")
    scripts = sorted((SITE / "js").rglob("*.js")) + sorted(SITE.glob("*.js"))
    for script in scripts:
        text = script.read_text(encoding="utf-8")
        for target in imports.findall(text):
            resolved = SITE / target.lstrip("/") if target.startswith("/") else (script.parent / target).resolve()
            if not resolved.exists():
                errors.append(f"{script.relative_to(SITE)}: import {target} does not resolve")
        used_keys.update(key for key in keys.findall(text) if not key.endswith((".js", ".json", ".css", ".html")))
        # Markup built in JavaScript can translate attributes too.
        for pairs in re.findall(r'data-i18n-attr="([^"]+)"', text):
            found = (pair.split(":", 1)[1].strip() for pair in pairs.split(";") if ":" in pair)
            used_keys.update(key for key in found if "." in key)


def check_styles(errors: list[str]) -> None:
    urls = re.compile(r"""url\(\s*["']?(/[^"')]+)["']?\s*\)""")
    for sheet in sorted(SITE.glob("*.css")) + sorted((SITE / "css").glob("*.css")):
        for url in urls.findall(sheet.read_text(encoding="utf-8")):
            if not (SITE / url.lstrip("/").split("?")[0]).exists():
                errors.append(f"{sheet.relative_to(SITE)}: url({url}) does not exist")


def bilingual(value, where: str, errors: list[str]) -> None:
    if not (isinstance(value, dict) and str(value.get("en", "")).strip() and str(value.get("zh", "")).strip()):
        errors.append(f"data/games.json: {where} needs non-empty 'en' and 'zh' text")


def check_catalogue(errors: list[str]) -> None:
    if not site_build.CATALOGUE.exists():
        return
    tokens = (SITE / "tokens.css").read_text(encoding="utf-8")
    sprite = (SITE / "src" / "partials" / "emblems.html").read_text(encoding="utf-8")
    games = json.loads(site_build.CATALOGUE.read_text(encoding="utf-8"))["games"]
    seen: set[str] = set()
    for game in games:
        slug = game.get("slug", "")
        where = f"game '{slug or '?'}'"
        if "internal" in game:
            errors.append(f"data/games.json: {where} publishes its private 'internal' notes")
        if f'id="emblem-{game.get("emblem")}"' not in sprite:
            errors.append(f"data/games.json: {where} emblem {game.get('emblem')!r} is not in the sprite")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug):
            errors.append(f"data/games.json: {where} has an invalid slug")
        if slug in seen:
            errors.append(f"data/games.json: {where} appears twice")
        seen.add(slug)
        if game.get("status") not in STATUSES:
            errors.append(f"data/games.json: {where} has unknown status {game.get('status')!r}")
        if game.get("kind") not in KINDS:
            errors.append(f"data/games.json: {where} has unknown kind {game.get('kind')!r}")
        for field in ("name", "tagline", "genre", "session", "premise"):
            bilingual(game.get(field), f"{where} field '{field}'", errors)
        for index, feature in enumerate(game.get("plannedFeatures", [])):
            bilingual(feature, f"{where} plannedFeatures[{index}]", errors)
        play = (game.get("links") or {}).get("play")
        if game.get("status") == "playable" and not play:
            errors.append(f"data/games.json: {where} is playable but has no play link")
        if game.get("status") != "playable" and play:
            errors.append(f"data/games.json: {where} is not playable, so it must not carry a play link")
        accent = game.get("accent", "")
        if not re.search(rf"{re.escape(accent)}\s*:", tokens):
            errors.append(f"data/games.json: {where} accent {accent!r} is not defined in tokens.css")
        for name in RESERVED:
            if (game.get(name) or {}).get("enabled") is not False:
                errors.append(f"data/games.json: {where} '{name}' must stay {{'enabled': false}} until it is built")
        media = game.get("media") or {}
        for image in [media.get("cover")] + list(media.get("stills") or []):
            if not image:
                continue
            for key in ("src", "small", "fallback"):
                value = image.get(key) or {}
                for path in [value] if isinstance(value, str) else value.values():
                    if not (SITE / path.lstrip("/")).exists():
                        errors.append(f"data/games.json: {where} media file {path} does not exist")
                if isinstance(value, dict) and value and set(value) != {"en", "zh"}:
                    errors.append(f"data/games.json: {where} media {key} needs exactly 'en' and 'zh' paths")
            bilingual(image.get("alt"), f"{where} media alt text", errors)
            if image.get("kind") == "concept" and image.get("label") != "concept":
                errors.append(f"data/games.json: {where} concept art must be labelled as concept art")
        vignette = media.get("vignette")
        if vignette and not (re.fullmatch(r"[a-z0-9-]+", vignette) and (SITE / "js" / "vignettes" / f"{vignette}.js").exists()):
            errors.append(f"data/games.json: {where} vignette {vignette!r} has no js/vignettes/{vignette}.js")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        stale = site_build.build(write=False)
    except site_build.BuildError as error:
        errors.append(f"site_build: {error}")
        stale = []
    errors.extend(f"{path.relative_to(ROOT)} is stale; run python3 tools/site_build.py" for path in stale)

    used_keys: set[str] = set()
    check_pages(errors, used_keys)
    check_scripts(errors, used_keys)
    check_styles(errors)
    check_catalogue(errors)

    zh = json.loads((SITE / "i18n" / "zh.json").read_text(encoding="utf-8"))
    for key in sorted(used_keys - zh.keys()):
        errors.append(f"i18n: '{key}' has no Chinese string")
    # Keys chosen by catalogue data (game copy, statuses) are not expected to appear literally.
    generated_prefixes = ("game.", "status.", "case.status.")
    for key in sorted(zh.keys() - used_keys):
        if not key.startswith(generated_prefixes):
            warnings.append(f"i18n: '{key}' is never used")

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}")
    pages = len(deployable_pages())
    print(f"check_site: {pages} pages, {len(used_keys)} i18n keys, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
