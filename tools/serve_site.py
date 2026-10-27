#!/usr/bin/env python3
"""Serve web/landing locally the way Vercel serves it.

    python3 tools/serve_site.py [--port 8765]

Emulates vercel.json: clean URLs (/community -> community.html, /games ->
games/index.html, *.html redirects to the clean path), no trailing slash, and
404.html for anything missing. Files Vercel never deploys (src/, dotfiles, the
.vercelignore list) are not served.

/api/community is a Vercel function. Locally it answers with a clearly
labelled fixture so the community page can be laid out offline.
"""
from __future__ import annotations

import argparse
import fnmatch
import http.server
import json
import mimetypes
import urllib.parse
from pathlib import Path

SITE = Path(__file__).resolve().parents[1] / "web" / "landing"

TYPES = {
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".avif": "image/avif",
    ".woff2": "font/woff2",
    ".xml": "application/xml; charset=utf-8",
    ".txt": "text/plain; charset=utf-8",
}

FIXTURE = {
    "discussions": [
        {
            "title": "Local preview: a sample field note",
            "url": "https://github.com/s-ccao/shadow-castle-stem-detective/discussions",
            "author": "serve_site.py",
            "avatar": "/assets/icon.svg",
            "updated": "2026-10-27T12:00:00Z",
            "excerpt": "This entry comes from tools/serve_site.py so the page can be laid out offline. "
            "The deployed site reads GitHub Discussions through /api/community.",
        }
    ]
}


def ignored_patterns() -> list[str]:
    path = SITE / ".vercelignore"
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    return [line.strip().strip("/") for line in lines if line.strip() and not line.startswith("#")]


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "ShadowCastleLocal/1.0"

    def do_GET(self) -> None:
        self.route(head=False)

    def do_HEAD(self) -> None:
        self.route(head=True)

    def route(self, head: bool) -> None:
        url = urllib.parse.urlsplit(self.path)
        path = urllib.parse.unquote(url.path)
        query = f"?{url.query}" if url.query else ""
        if path == "/api/community":
            self.send_bytes(json.dumps(FIXTURE).encode(), "application/json", 200, head, {"X-Local-Fixture": "1"})
            return
        if path.startswith("/api/"):
            self.send_bytes(b'{"error":"Not available on the local server."}', "application/json", 404, head)
            return
        if len(path) > 1 and path.endswith("/"):
            self.redirect(path.rstrip("/") + query)
            return
        if path.endswith(".html"):
            clean = path[: -len(".html")]
            if clean.endswith("/index"):
                clean = clean[: -len("index")].rstrip("/") or "/"
            self.redirect(clean + query)
            return
        target = self.lookup(path)
        if target is None:
            missing = SITE / "404.html"
            if missing.exists():
                self.send_file(missing, 404, head)
            else:
                self.send_bytes(b"Not found", "text/plain", 404, head)
            return
        self.send_file(target, 200, head)

    def lookup(self, path: str) -> Path | None:
        parts = [part for part in path.split("/") if part]
        if any(part.startswith(".") or part == ".." for part in parts):
            return None
        relative = "/".join(parts)
        for pattern in ignored_patterns():
            if fnmatch.fnmatch(relative, pattern) or relative.startswith(pattern + "/"):
                return None
        if parts and parts[0] in {"src", "api"}:
            return None
        if not parts:
            return SITE / "index.html"
        base = SITE.joinpath(*parts)
        if base.is_file():
            return base
        page = base.with_name(base.name + ".html")
        if page.is_file():
            return page
        index = base / "index.html"
        if index.is_file():
            return index
        return None

    def redirect(self, location: str) -> None:
        self.send_response(308)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def send_file(self, path: Path, status: int, head: bool) -> None:
        kind = TYPES.get(path.suffix) or mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self.send_bytes(path.read_bytes(), kind, status, head)

    def send_bytes(self, body: bytes, kind: str, status: int, head: bool, extra: dict | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        # Quiet on success; print client and server errors.
        if len(args) > 1 and str(args[1]).startswith(("4", "5")):
            super().log_message(fmt, *args)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--bind", default="127.0.0.1")
    args = parser.parse_args()
    server = http.server.ThreadingHTTPServer((args.bind, args.port), Handler)
    print(f"Serving {SITE} at http://{args.bind}:{args.port}/ (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
