"""Fetch the CC0 Poly Haven textures the Blender Hall prototype uses.

    python3 tools/blender/fetch_textures.py

Reads tools/blender/cc0_textures.json, downloads every map that is missing or
whose SHA-256 does not match, and verifies each file against the manifest.
The textures are CC0 (public domain); authors and source pages are recorded in
the manifest. Poly Haven asks API clients to send an identifying User-Agent.
"""

import hashlib
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "blender", "cc0_textures.json")
USER_AGENT = "ShadowCastleSTEMDetective-prototype/1.0 (local texture fetch for a Blender test render)"


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    with open(MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)
    destination = os.path.join(ROOT, manifest["destination"])
    os.makedirs(destination, exist_ok=True)
    failures = 0
    for asset in manifest["assets"]:
        for kind, entry in asset["maps"].items():
            path = os.path.join(destination, entry["file"])
            if os.path.exists(path) and sha256(path) == entry["sha256"]:
                print("ok      ", entry["file"])
                continue
            request = urllib.request.Request(entry["url"], headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
            with open(path, "wb") as handle:
                handle.write(data)
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                print("MISMATCH", entry["file"], "(%s %s)" % (asset["asset"], kind))
                failures += 1
            else:
                print("fetched ", entry["file"])
    with open(os.path.join(destination, "sources.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest["assets"], handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
