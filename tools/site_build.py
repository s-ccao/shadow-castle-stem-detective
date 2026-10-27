#!/usr/bin/env python3
"""Build the static site in web/landing (shadowcastledetective.com).

Hand-written pages keep generated regions between markers:

    <!-- build:nav current="community" -->  ...generated...  <!-- /build:nav -->

Whole pages under games/ are generated from data/games.json and src/templates/,
and i18n/zh.json merges src/i18n/zh.json with the catalogue's Chinese copy.
Generated files are committed: Vercel uploads web/landing as-is and runs no
build, so the repository must always hold the built site.

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
CATALOGUE = SITE / "data" / "games.json"

PLAY_URL = "https://play.shadowcastledetective.com/"
SITE_URL = "https://shadowcastledetective.com"

# Pages written by hand whose marked regions the builder fills in.
HAND_WRITTEN = ["index.html", "community.html"]

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
    if not CATALOGUE.exists():
        return []
    data = json.loads(read(CATALOGUE))
    games = sorted(data["games"], key=lambda game: game["order"])
    return games


class Site:
    def __init__(self) -> None:
        self.games = load_catalogue()

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

    def region_nav(self, attrs: dict[str, str]) -> str:
        current = attrs.get("current", "")
        return Template(partial("nav")).substitute(
            tagline="STEM Detective",
            cases_link="",
            community_current=' aria-current="page"' if current == "community" else "",
        )

    def region_footer(self, attrs: dict[str, str]) -> str:
        return Template(partial("footer")).substitute(footer_links="")

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

    def zh_dictionary(self) -> str:
        merged = json.loads(read(SRC / "i18n" / "zh.json"))
        for key, value in self.game_strings().items():
            if key in merged and merged[key] != value:
                raise BuildError(f"i18n key '{key}' is defined twice with different text")
            merged[key] = value
        return json.dumps(merged, ensure_ascii=False, indent=0, sort_keys=True) + "\n"

    def game_strings(self) -> dict[str, str]:
        return {}

    def outputs(self) -> dict[Path, str]:
        files: dict[Path, str] = {}
        for name in HAND_WRITTEN:
            path = SITE / name
            files[path] = self.fill(read(path))
        files[SITE / "i18n" / "zh.json"] = self.zh_dictionary()
        return files


def build(write: bool) -> list[Path]:
    stale: list[Path] = []
    for path, content in Site().outputs().items():
        current = read(path) if path.exists() else None
        if current == content:
            continue
        stale.append(path)
        if write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
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
