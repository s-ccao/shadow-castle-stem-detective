"""Fetch the CC0 Poly Haven models the Blender room prototype uses.

    python3 tools/blender/fetch_models.py

Reads tools/blender/cc0_models.json and downloads every file of every model
(the glTF, its buffer and its textures) that is missing or whose SHA-256 does
not match, into <destination>/<asset>/, then verifies each file against the
manifest. The models are CC0 (public domain); authors and source pages are
recorded in the manifest and copied beside the models as sources.json. Poly
Haven asks API clients to send an identifying User-Agent.
"""

import hashlib
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "blender", "cc0_models.json")
USER_AGENT = "ShadowCastleSTEMDetective-prototype/1.0 (local model fetch for a Blender test render)"


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    with open(MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)
    destination = os.path.join(ROOT, manifest["destination"])
    failures = 0
    for asset in manifest["assets"]:
        for relative, entry in asset["files"].items():
            path = os.path.join(destination, asset["asset"], relative)
            if os.path.exists(path) and sha256(path) == entry["sha256"]:
                print("ok      ", asset["asset"], relative)
                continue
            os.makedirs(os.path.dirname(path), exist_ok=True)
            request = urllib.request.Request(entry["url"], headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            with open(path, "wb") as handle:
                handle.write(data)
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                print("MISMATCH", asset["asset"], relative)
                failures += 1
            else:
                print("fetched ", asset["asset"], relative)
    with open(os.path.join(destination, "sources.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest["assets"], handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
