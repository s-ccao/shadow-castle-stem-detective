#!/usr/bin/env python3
"""Build the static site in web/landing (shadowcastledetective.com).

Hand-written pages keep generated regions between markers:

    <!-- build:nav current="community" -->  ...generated...  <!-- /build:nav -->

The game catalogue lives in src/games.json. The builder publishes it as
data/games.json (minus the private "internal" notes), renders every case page
under games/ from src/templates/page.html, and merges the catalogue's Chinese
copy with src/i18n/zh.json into i18n/zh.json. Generated files are committed:
Vercel uploads web/landing as-is and runs no build, so the repository must
always hold the built site.

    python3 tools/site_build.py           write every generated file
    python3 tools/site_build.py --check   list stale files and change nothing
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "web" / "landing"
SRC = SITE / "src"
SOURCE_CATALOGUE = SRC / "games.json"
CATALOGUE = SITE / "data" / "games.json"
SITE_URL = "https://shadowcastledetective.com"
DEFAULT_OG_IMAGE = "/assets/hero-castle.jpg"

# Pages written by hand whose marked regions the builder fills in.
HAND_WRITTEN = ["index.html", "community.html", "404.html"]

STATUS_LABEL = {
    "playable": "Playable",
    "in-development": "In development",
    "coming-soon": "Coming soon",
}
STATUS_NOTE = {
    "in-development": "In development and not playable yet.",
    "coming-soon": "Not playable yet. When the game is ready, this page will open it.",
}

# A case card's art is at most about 25rem wide; on a phone it spans the column.
CARD_SIZES = "(min-width: 40rem) 25rem, 92vw"

# Lit windows on the hub's castle, one per catalogue entry in catalogue order:
# (x, y, width, height, shape) in the scene's 1600 x 900 viewBox. The flagship
# takes the keep's great window; a new game needs a new slot drawn here.
WINDOW_SLOTS = [
    (1000, 400, 26, 46, "arch"),  # the keep's great window
    (780, 430, 14, 26, "arch"),  # left tower
    (1145, 400, 14, 26, "arch"),  # right tower, the observatory
    (875, 540, 20, 40, "arch"),  # the great hall
    (1000, 240, 22, 22, "round"),  # the clock window of the upper keep
    (1315, 490, 12, 22, "arch"),  # the alchemist's turret
    (1235, 576, 16, 24, "arch"),  # above the gate
]

MARKER = re.compile(
    r"(?P<indent>[ \t]*)<!-- build:(?P<name>[a-z][a-z0-9-]*)(?P<attrs>(?:\s+[a-z][a-z0-9-]*=\"[^\"]*\")*)\s*-->"
    r".*?"
    r"<!-- /build:(?P=name) -->",
    re.S,
)
ATTR = re.compile(r'([a-z][a-z0-9-]*)="([^"]*)"')


class BuildError(Exception):
    pass


def esc(value) -> str:
    return html.escape(str(value), quote=True)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def partial(name: str) -> str:
    return read(SRC / "partials" / f"{name}.html")


def indent(block: str, prefix: str) -> str:
    lines = block.strip("\n").split("\n")
    return "\n".join(prefix + line if line.strip() else "" for line in lines)


def load_catalogue() -> list[dict]:
    data = json.loads(read(SOURCE_CATALOGUE))
    return sorted(data["games"], key=lambda game: game["order"])


def stamp(status: str) -> str:
    return f'<span class="stamp" data-status="{status}" data-i18n="status.{status}">{STATUS_LABEL[status]}</span>'


def emblem(name: str, cls: str = "emblem") -> str:
    return (
        f'<svg class="{cls}" viewBox="0 0 64 64" aria-hidden="true" focusable="false">'
        f'<use href="#emblem-{name}"></use></svg>'
    )


def alt_name(key: str, game: dict, cls: str, field: str = "name") -> str:
    # Shows the other language's name: Chinese under English, English under Chinese.
    suffix = "alt" if field == "name" else f"alt_{field}"
    return (
        f'<p class="{cls}" lang="zh-CN" data-i18n="{key}.{suffix}" data-i18n-attr="lang:meta.alt_lang">'
        f"{esc(game[field]['zh'])}</p>"
    )


def meta_line(key: str, game: dict, cls: str) -> str:
    return (
        f'<p class="{cls}"><span data-i18n="{key}.genre">{esc(game["genre"]["en"])}</span> '
        f'<span aria-hidden="true">·</span> <span data-i18n="{key}.session">{esc(game["session"]["en"])}</span></p>'
    )


def localized(value, lang: str) -> str:
    """A media path, or an {en, zh} pair of paths, resolved for one language."""
    return value if isinstance(value, str) else value[lang]


def shot(still: dict, alt_key: str, sizes: str) -> str:
    """An <img> for a catalogue still; the Chinese capture swaps in with the language."""
    sources = {}
    for lang in ("en", "zh"):
        src = localized(still["src"], lang)
        srcset = ""
        if still.get("small"):
            srcset = f'{localized(still["small"], lang)} {still["smallWidth"]}w, {src} {still["width"]}w'
        sources[lang] = (src, srcset)
    (src, srcset), (zh_src, zh_srcset) = sources["en"], sources["zh"]
    parts = [f'src="{esc(src)}"']
    if srcset:
        parts.append(f'srcset="{esc(srcset)}" sizes="{esc(sizes)}"')
    if zh_src != src:
        parts.append(f'data-zh-src="{esc(zh_src)}"')
        if zh_srcset:
            parts.append(f'data-zh-srcset="{esc(zh_srcset)}"')
    parts += [
        f'width="{still["width"]}" height="{still["height"]}"',
        f'alt="{esc(still["alt"]["en"])}" data-i18n-attr="alt:{alt_key}"',
        'loading="lazy" decoding="async"',
    ]
    return f"<img {' '.join(parts)} />"


def num(value: float) -> str:
    return f"{value:.1f}".rstrip("0").rstrip(".")


def window_pane(width: float, height: float, shape: str) -> str:
    if shape == "round":
        r = width / 2
        return f"M{num(-r)} 0a{num(r)} {num(r)} 0 1 0 {num(2 * r)} 0a{num(r)} {num(r)} 0 1 0 {num(-2 * r)} 0Z"
    hw, hh = width / 2, height / 2
    spring = -hh + width * 0.55
    tip = -hh + width * 0.08
    return (
        f"M{num(-hw)} {num(hh)}V{num(spring)}Q{num(-hw)} {num(tip)} 0 {num(-hh)}"
        f"Q{num(hw)} {num(tip)} {num(hw)} {num(spring)}V{num(hh)}Z"
    )


def window_bars(width: float, height: float, shape: str) -> str:
    if shape == "round":
        r = width / 2
        return f"M{num(-r)} 0H{num(r)}M0 {num(-r)}V{num(r)}"
    hw, hh = width / 2, height / 2
    return f"M0 {num(-hh + width * 0.4)}V{num(hh)}M{num(-hw)} {num(hh * 0.15)}H{num(hw)}"


class Site:
    def __init__(self) -> None:
        self.games = load_catalogue()
        self.by_slug = {game["slug"]: game for game in self.games}

    def game(self, slug: str) -> dict:
        if slug not in self.by_slug:
            raise BuildError(f"unknown game '{slug}'")
        return self.by_slug[slug]

    # ---------- shared regions ----------

    def region(self, name: str, attrs: dict[str, str]) -> str:
        renderer = getattr(self, f"region_{name.replace('-', '_')}", None)
        if renderer is None:
            raise BuildError(f"unknown build region '{name}'")
        return renderer(attrs)

    def region_boot(self, attrs: dict[str, str]) -> str:
        return partial("boot")

    def region_head(self, attrs: dict[str, str]) -> str:
        links = "".join(f'<link rel="stylesheet" href="{esc(href)}" />\n' for href in attrs.get("css", "").split())
        return Template(partial("head")).substitute(page_css=links)

    def region_emblems(self, attrs: dict[str, str]) -> str:
        return partial("emblems")

    def region_nav(self, attrs: dict[str, str]) -> str:
        current = attrs.get("current", "")

        def mark(name: str) -> str:
            return ' aria-current="page"' if current == name else ""

        cases = (
            f'      <a class="site-nav__cases" href="/games"{mark("cases")} data-library-open>'
            f'<span data-i18n="nav.cases">Case files</span> <b class="site-nav__count">{len(self.games)}</b></a>\n'
        )
        return Template(partial("nav")).substitute(
            tagline="Science-mystery games",
            cases_link=cases,
            community_current=mark("community"),
        )

    def region_footer(self, attrs: dict[str, str]) -> str:
        links = '        <a href="/games" data-i18n="nav.cases">Case files</a>\n'
        return Template(partial("footer")).substitute(footer_links=links)

    def region_scene(self, attrs: dict[str, str]) -> str:
        if len(self.games) > len(WINDOW_SLOTS):
            raise BuildError("the catalogue has more games than castle windows; add a slot to WINDOW_SLOTS")
        windows = []
        for index, (game, (x, y, width, height, shape)) in enumerate(zip(self.games, WINDOW_SLOTS)):
            lit = game["status"] == "playable"
            radius = max(width, height) * 1.7
            pane = window_pane(width, height, shape)
            windows.append(
                "".join(
                    [
                        f'<a class="win{" win--lit" if lit else ""}" href="/games/{game["slug"]}" tabindex="-1" '
                        f'data-game="{game["slug"]}" data-status="{game["status"]}" '
                        f'data-label-en="{esc(game["short"]["en"])}" data-label-zh="{esc(game["short"]["zh"])}" '
                        f'style="--win: var({game["accent"]}); --i: {index}" transform="translate({x} {y})">',
                        f'<circle class="win__halo" r="{num(radius)}" />',
                        f'<circle class="win__halo win__halo--2" r="{num(radius * 0.62)}" />',
                        f'<circle class="win__halo win__halo--3" r="{num(radius * 0.36)}" />',
                        f'<path class="win__pane" d="{pane}" />',
                        f'<path class="win__bars" d="{window_bars(width, height, shape)}" />',
                        f'<circle class="win__hit" r="{num(max(width, height) * 0.95)}" />',
                        "</a>",
                    ]
                )
            )
        return Template(partial("scene")).substitute(windows="\n".join(windows))

    def region_dock(self, attrs: dict[str, str]) -> str:
        dots = "".join(f'<i style="--c: var({game["accent"]})"></i>' for game in self.games)
        count = len(self.games)
        return "\n".join(
            [
                f'<a class="case-dock" href="/games" data-library-open aria-label="Open the case files" '
                'data-i18n-attr="aria-label:library.dock_label">',
                f'  <span class="case-dock__count" aria-hidden="true">{count}</span>',
                '  <span class="case-dock__label" data-i18n="nav.cases">Case files</span>',
                f'  <span class="case-dock__dots" aria-hidden="true">{dots}</span>',
                "</a>",
            ]
        )

    def region_featured(self, attrs: dict[str, str]) -> str:
        return self.featured(self.game(attrs["slug"]))

    def stills(self, attrs: dict[str, str]) -> list[tuple[int, dict]]:
        game = self.game(attrs.get("slug", ""))
        wanted = attrs.get("ids", "").split()
        found = [(index, still) for index, still in enumerate(game["media"]["stills"]) if still.get("id") in wanted]
        if len(found) != len(wanted):
            raise BuildError(f"stills {wanted} are not all in {game['slug']}'s catalogue entry")
        return sorted(found, key=lambda item: wanted.index(item[1]["id"]))

    def region_still(self, attrs: dict[str, str]) -> str:
        key = f"game.{attrs['slug']}"
        return "\n".join(shot(still, f"{key}.still.{index}.alt", attrs.get("sizes", "100vw")) for index, still in self.stills(attrs))

    def region_stills(self, attrs: dict[str, str]) -> str:
        key = f"game.{attrs['slug']}"
        figures = [
            "\n".join(
                [
                    '<figure class="feature-capture room-shot">',
                    f'  {shot(still, f"{key}.still.{index}.alt", attrs.get("sizes", "100vw"))}',
                    f'  <figcaption><strong data-i18n="{key}.still.{index}.caption">{esc(still["caption"]["en"])}</strong></figcaption>',
                    "</figure>",
                ]
            )
            for index, still in self.stills(attrs)
        ]
        return "\n".join(figures)

    def region_case_cards(self, attrs: dict[str, str]) -> str:
        status = attrs.get("status")
        games = [game for game in self.games if not status or game["status"] == status]
        return self.grid(games, attrs.get("heading", "h3"))

    # ---------- components ----------

    def card(self, game: dict, heading: str = "h3") -> str:
        slug, status = game["slug"], game["status"]
        key = f"game.{slug}"
        cover = (game.get("media") or {}).get("cover")
        if cover:
            src = localized(cover["src"], "en")
            srcset = ""
            if cover.get("small"):
                srcset = (
                    f' srcset="{esc(localized(cover["small"], "en"))} {cover["smallWidth"]}w, {esc(src)} {cover["width"]}w"'
                    f' sizes="{CARD_SIZES}"'
                )
            art = (
                f'<img class="case-card__image" src="{esc(src)}"{srcset} width="{cover["width"]}" '
                f'height="{cover["height"]}" alt="" loading="lazy" decoding="async" />'
            )
            # Generated art is never shown without saying so.
            if cover.get("kind") == "concept":
                art += '<span class="art-tag" data-i18n="art.concept">Concept art</span>'
        else:
            art = f'<span class="case-card__glow"></span>{emblem(game["emblem"], "emblem case-card__emblem")}'
        play = ""
        if status == "playable" and game["links"].get("play"):
            play = (
                f'<a class="btn btn--primary btn--sm case-card__play" href="{esc(game["links"]["play"])}" data-magnet>'
                '<span data-i18n="cards.play">Play</span> <span aria-hidden="true">▶</span></a>'
            )
        return "\n".join(
            [
                f'<article class="case-card" data-slug="{slug}" data-status="{status}" data-tilt{self.preview_attr(game)} '
                f'style="--case-accent: var({game["accent"]})">',
                f'  <div class="case-card__art" aria-hidden="true">{art}</div>',
                '  <div class="case-card__body">',
                f"    {stamp(status)}",
                f'    <{heading} class="case-card__name"><a class="case-card__link" href="/games/{slug}" '
                f'data-i18n="{key}.short">{esc(game["short"]["en"])}</a></{heading}>',
                f"    {alt_name(key, game, 'case-card__alt', 'short')}",
                f"    {meta_line(key, game, 'case-card__meta')}",
                f'    <p class="case-card__tagline" data-i18n="{key}.tagline">{esc(game["tagline"]["en"])}</p>',
                f'    <div class="case-card__foot">{play}<span class="case-card__more" aria-hidden="true">'
                '<span data-i18n="cards.open">Case file</span> →</span></div>',
                "  </div>",
                "</article>",
            ]
        )

    def preview_attr(self, game: dict) -> str:
        media = game.get("media") or {}
        stills = [
            {lang: localized(still.get("small") or still["src"], lang) for lang in ("en", "zh")} for still in media.get("stills") or []
        ]
        if stills:
            return f' data-preview="{esc(json.dumps(stills))}"'
        return f' data-vignette="{esc(media["vignette"])}"' if media.get("vignette") else ""

    def grid(self, games: list[dict], heading: str = "h3", cls: str = "case-grid") -> str:
        cards = "\n".join(self.card(game, heading) for game in games)
        return f'<div class="{cls}" data-cards="{len(games)}">\n{indent(cards, "  ")}\n</div>'

    def featured(self, game: dict) -> str:
        slug = game["slug"]
        key = f"game.{slug}"
        still = game["media"]["stills"][0]
        facts = "\n".join(
            f'    <div><dt data-countup>{esc(fact["value"])}</dt>'
            f'<dd data-i18n="{key}.fact.{index}">{esc(fact["label"]["en"])}</dd></div>'
            for index, fact in enumerate(game.get("facts", []))
        )
        return "\n".join(
            [
                '<div class="featured__media">',
                '  <figure class="featured__frame" data-develop>',
                f'    {shot(still, f"{key}.still.0.alt", "(min-width: 60rem) 46vw, 92vw")}',
                "  </figure>",
                "</div>",
                '<div class="featured__copy">',
                f"  {stamp(game['status'])}",
                f"  {meta_line(key, game, 'featured__meta')}",
                f'  <h2 class="featured__title" id="featured-title" data-i18n="{key}.name">{esc(game["name"]["en"])}</h2>',
                f"  {alt_name(key, game, 'featured__alt')}",
                f'  <p class="featured__premise" data-i18n="{key}.premise">{esc(game["premise"]["en"])}</p>',
                '  <dl class="featured__facts">',
                facts,
                "  </dl>",
                '  <div class="featured__actions">',
                f'    <a class="btn btn--primary" href="{esc(game["links"]["play"])}" data-magnet>'
                '<span data-i18n="cards.play_online">Play online</span> <span aria-hidden="true">▶</span></a>',
                f'    <a class="btn btn--ghost" href="/games/{slug}"><span data-i18n="cards.read_case">Read the case file</span> '
                '<span aria-hidden="true">→</span></a>',
                "  </div>",
                "</div>",
            ]
        )

    def case_main(self, game: dict) -> str:
        slug, status = game["slug"], game["status"]
        key = f"game.{slug}"
        if status == "playable":
            primary = (
                f'<a class="btn btn--primary" href="{esc(game["links"]["play"])}" data-magnet>'
                '<span data-i18n="cards.play_online">Play online</span> <span aria-hidden="true">▶</span></a>'
            )
        else:
            primary = f'<p class="case-hero__note" data-i18n="case.status.{status}">{STATUS_NOTE[status]}</p>'
        features = "\n".join(
            f'<li data-i18n="{key}.feature.{index}">{esc(feature["en"])}</li>'
            for index, feature in enumerate(game.get("plannedFeatures", []))
        )
        planned = ""
        if features:
            planned = "\n".join(
                [
                    '<section class="case-planned" aria-labelledby="planned-title">',
                    '  <h2 id="planned-title" data-i18n="case.planned_title">Planned features</h2>',
                    '  <ul class="case-planned__list">',
                    indent(features, "    "),
                    "  </ul>",
                    '  <p class="case-planned__note" data-i18n="case.planned_note">'
                    "Planned, not final: features may change while the game is built.</p>",
                    "</section>",
                ]
            )
        vignette = (game.get("media") or {}).get("vignette")
        lens = f' data-vignette="{esc(vignette)}"' if vignette else ""
        return "\n".join(
            [
                '<section class="case-hero" aria-labelledby="case-title">',
                f'  <div class="case-hero__art" aria-hidden="true"{lens}>',
                '    <span class="case-hero__halo"></span>',
                f"    {emblem(game['emblem'], 'emblem case-hero__emblem')}",
                "  </div>",
                '  <div class="case-hero__copy">',
                f"    {stamp(status)}",
                f'    <h1 class="case-hero__title" id="case-title"><span data-i18n="{key}.name">{esc(game["name"]["en"])}</span></h1>',
                f"    {alt_name(key, game, 'case-hero__alt')}",
                f"    {meta_line(key, game, 'case-hero__meta')}",
                f'    <p class="case-hero__tagline" data-i18n="{key}.tagline">{esc(game["tagline"]["en"])}</p>',
                '    <div class="case-hero__actions">',
                f"      {primary}",
                '      <a class="btn btn--ghost" href="/games"><span aria-hidden="true">←</span> '
                '<span data-i18n="case.back">All case files</span></a>',
                "    </div>",
                "  </div>",
                "</section>",
                '<div class="case-body">',
                '  <section class="case-premise" aria-labelledby="premise-title">',
                '    <h2 id="premise-title" data-i18n="case.premise_title">The case</h2>',
                f'    <p data-i18n="{key}.premise">{esc(game["premise"]["en"])}</p>',
                "  </section>",
                indent(planned, "  ") if planned else "",
                "</div>",
            ]
        )

    def other_cases(self, game: dict) -> str:
        others = [other for other in self.games if other["slug"] != game["slug"]]
        return "\n".join(
            [
                '<section class="other-cases" aria-labelledby="others-title">',
                '  <div class="other-cases__head">',
                '    <h2 id="others-title" data-i18n="case.others">Other case files</h2>',
                '    <a class="other-cases__all" href="/games"><span data-i18n="case.all">All case files</span> '
                '<span aria-hidden="true">→</span></a>',
                "  </div>",
                indent(self.grid(others, "h3", "case-strip"), "  "),
                "</section>",
            ]
        )

    # ---------- pages ----------

    def page(self, *, title: str, title_key: str, description: str, description_key: str, path: str,
             og_description: str, og_image: str, css: str, body_class: str, main: str,
             current: str = "", main_attrs: str = "", structured: str = "") -> str:
        head = self.region_head({"css": css}) + (f"\n{structured}" if structured else "")
        return Template(read(SRC / "templates" / "page.html")).substitute(
            boot=indent(partial("boot"), "    "),
            title=esc(title),
            title_key=title_key,
            description=esc(description),
            description_key=description_key,
            og_title=esc(title),
            og_description=esc(og_description),
            og_image=esc(SITE_URL + og_image),
            canonical=esc(SITE_URL + path),
            head=indent(head, "    "),
            body_class=body_class,
            emblems=indent(partial("emblems"), "    "),
            nav=indent(self.region_nav({"current": current}), "    "),
            main_attrs=main_attrs,
            main=indent(main, "      "),
            footer=indent(self.region_footer({}), "    "),
            dock=indent(self.region_dock({}), "    "),
        )

    def game_page(self, game: dict) -> str:
        slug = game["slug"]
        seo = game.get("seo") or {}
        title = (seo.get("title") or {}).get("en") or f"{game['name']['en']} · Shadow Castle case files"
        description = (seo.get("description") or {}).get("en") or game["premise"]["en"]
        if game.get("story"):
            body = self.fill(read(SRC / "stories" / f"{game['story']}.html"))
            css = "/styles.css /css/atmosphere.css /css/cards.css /css/game.css"
        else:
            body = self.case_main(game)
            css = "/css/cards.css /css/game.css"
        cover = (game.get("media") or {}).get("cover") or {}
        image = seo.get("image") or (localized(cover["src"], "en") if cover else DEFAULT_OG_IMAGE)
        return self.page(
            title=title,
            title_key=f"game.{slug}.seo.title",
            description=description,
            description_key=f"game.{slug}.seo.description",
            path=f"/games/{slug}",
            og_description=seo.get("ogDescription") or description,
            og_image=image,
            css=css,
            body_class=f"page-case page-case--{slug}",
            main=body.strip("\n") + "\n\n" + self.other_cases(game),
            current="cases",
            main_attrs=f' data-case="{slug}" style="--case-accent: var({game["accent"]})"',
            structured=self.structured(game, image, description),
        )

    def structured(self, game: dict, image: str, description: str) -> str:
        """schema.org VideoGame data, for games people can actually play."""
        if game["status"] != "playable":
            return ""
        links = game.get("links") or {}
        data = {
            "@context": "https://schema.org",
            "@type": "VideoGame",
            "name": game["name"]["en"],
            "alternateName": game["name"]["zh"],
            "url": f"{SITE_URL}/games/{game['slug']}",
            "description": description,
            "genre": game["genre"]["en"],
            "image": SITE_URL + image,
            "gamePlatform": "Web browser",
        }
        if game.get("languages"):
            data["inLanguage"] = game["languages"]
        if links.get("play"):
            data["potentialAction"] = {"@type": "PlayAction", "target": links["play"]}
        if links.get("source"):
            data["sameAs"] = [links["source"]]
        body = json.dumps(data, ensure_ascii=False, indent=2).replace("</", "<\\/")
        return f'<script type="application/ld+json">\n{body}\n</script>'

    def archive_page(self) -> str:
        main = "\n".join(
            [
                '<section class="archive-head" aria-labelledby="archive-title">',
                '  <p class="case-mark" data-i18n="archive.mark">Ashford Castle · Case archive</p>',
                '  <h1 id="archive-title" data-i18n="archive.title">Case files</h1>',
                '  <p class="archive-head__intro" data-i18n="archive.intro">'
                "Seven cases from Ashford Castle. One is open to play; six are being built in the open.</p>",
                "</section>",
                '<section class="archive" aria-labelledby="archive-title">',
                indent(self.archive_filter(), "  "),
                indent(self.grid(self.games, "h2"), "  "),
                "</section>",
            ]
        )
        return self.page(
            title="Case files · Shadow Castle",
            title_key="meta.archive.title",
            description="Every Shadow Castle case: one science-mystery game to play in your browser today, "
            "six more being built in the open.",
            description_key="meta.archive.description",
            path="/games",
            og_description="One case open to play, six more in the dark. The Shadow Castle case files.",
            og_image=DEFAULT_OG_IMAGE,
            css="/css/cards.css /css/game.css",
            body_class="page-archive",
            main=main,
            current="cases",
        )

    def archive_filter(self) -> str:
        # Hidden until js/archive.js runs, so it never shows as dead buttons.
        counts = {status: sum(game["status"] == status for game in self.games) for status in STATUS_LABEL}
        buttons = [
            f'<button type="button" aria-pressed="true" data-filter="all"><span data-i18n="archive.all">All</span> '
            f"<b>{len(self.games)}</b></button>"
        ] + [
            f'<button type="button" aria-pressed="false" data-filter="{status}"><span data-i18n="status.{status}">{label}</span> '
            f"<b>{counts[status]}</b></button>"
            for status, label in STATUS_LABEL.items()
            if counts[status]
        ]
        return "\n".join(
            [
                '<div class="archive-filter" role="group" aria-label="Filter case files by status" '
                'data-i18n-attr="aria-label:archive.filter" data-archive-filter hidden>',
                indent("\n".join(buttons), "  "),
                '  <p class="visually-hidden" role="status" data-archive-count></p>',
                "</div>",
            ]
        )

    # ---------- data ----------

    def sitemap(self) -> str:
        paths = ["/", "/games", *[f"/games/{game['slug']}" for game in self.games], "/community"]
        urls = "\n".join(f"  <url><loc>{SITE_URL}{path}</loc></url>" for path in paths)
        return f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}\n</urlset>\n'

    def robots(self) -> str:
        return f"User-agent: *\nAllow: /\n\nSitemap: {SITE_URL}/sitemap.xml\n"

    def public_catalogue(self) -> str:
        games = [{key: value for key, value in game.items() if key != "internal"} for game in self.games]
        return json.dumps({"version": 1, "games": games}, ensure_ascii=False, indent=1) + "\n"

    def game_strings(self) -> dict[str, str]:
        strings: dict[str, str] = {}
        for game in self.games:
            key = f"game.{game['slug']}"
            for field in ("name", "short", "tagline", "genre", "session", "premise"):
                strings[f"{key}.{field}"] = game[field]["zh"]
            strings[f"{key}.alt"] = game["name"]["en"]
            strings[f"{key}.alt_short"] = game["short"]["en"]
            for index, fact in enumerate(game.get("facts", [])):
                strings[f"{key}.fact.{index}"] = fact["label"]["zh"]
            for index, feature in enumerate(game.get("plannedFeatures", [])):
                strings[f"{key}.feature.{index}"] = feature["zh"]
            media = game.get("media") or {}
            if media.get("cover"):
                strings[f"{key}.cover.alt"] = media["cover"]["alt"]["zh"]
            for index, still in enumerate(media.get("stills") or []):
                strings[f"{key}.still.{index}.alt"] = still["alt"]["zh"]
                if still.get("caption"):
                    strings[f"{key}.still.{index}.caption"] = still["caption"]["zh"]
            seo = game.get("seo") or {}
            strings[f"{key}.seo.title"] = (seo.get("title") or {}).get("zh") or f"{game['name']['zh']} · 暗影城堡案件档案"
            strings[f"{key}.seo.description"] = (seo.get("description") or {}).get("zh") or game["premise"]["zh"]
        return strings

    def zh_dictionary(self) -> str:
        merged = json.loads(read(SRC / "i18n" / "zh.json"))
        for key, value in self.game_strings().items():
            if key in merged and merged[key] != value:
                raise BuildError(f"i18n key '{key}' is defined twice with different text")
            merged[key] = value
        return json.dumps(merged, ensure_ascii=False, indent=0, sort_keys=True) + "\n"

    # ---------- outputs ----------

    def fill(self, text: str) -> str:
        def replace(match: re.Match) -> str:
            prefix = match["indent"]
            name = match["name"]
            body = self.region(name, dict(ATTR.findall(match["attrs"])))
            start = f"{prefix}<!-- build:{name}{match['attrs']} -->"
            end = f"{prefix}<!-- /build:{name} -->"
            return f"{start}\n{indent(body, prefix)}\n{end}"

        return MARKER.sub(replace, text)

    def outputs(self) -> dict[Path, str]:
        files: dict[Path, str] = {}
        for name in HAND_WRITTEN:
            path = SITE / name
            if path.exists():
                files[path] = self.fill(read(path))
        files[CATALOGUE] = self.public_catalogue()
        files[SITE / "i18n" / "zh.json"] = self.zh_dictionary()
        files[SITE / "games" / "index.html"] = self.archive_page()
        files[SITE / "sitemap.xml"] = self.sitemap()
        files[SITE / "robots.txt"] = self.robots()
        for game in self.games:
            files[SITE / "games" / f"{game['slug']}.html"] = self.game_page(game)
        return files


def orphans(expected: set[Path]) -> list[Path]:
    # Generated case pages whose game left the catalogue; never deleted automatically.
    return [path for path in sorted((SITE / "games").glob("*.html")) if path not in expected]


def build(write: bool) -> list[Path]:
    site = Site()
    outputs = site.outputs()
    stale: list[Path] = []
    for path, content in outputs.items():
        current = read(path) if path.exists() else None
        if current == content:
            continue
        stale.append(path)
        if write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
    for path in orphans(set(outputs)):
        raise BuildError(f"{path.relative_to(ROOT)} has no catalogue entry; remove it by hand if the game is gone")
    return stale


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="report stale generated files without writing")
    args = parser.parse_args(argv)
    try:
        stale = build(write=not args.check)
    except (BuildError, KeyError, ValueError) as error:
        print(f"site_build: {error}", file=sys.stderr)
        return 2
    for path in stale:
        verb = "stale" if args.check else "wrote"
        print(f"{verb}: {path.relative_to(ROOT)}")
    if args.check and stale:
        print("Run python3 tools/site_build.py and commit the result.", file=sys.stderr)
        return 1
    if not stale:
        print("site_build: everything is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
