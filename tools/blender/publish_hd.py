"""Publish the Blender HD look into the game.

The Blender pipeline renders into prototypes/ (gitignored work files: full
PNG renders, depth maps, layouts, captures). This copies what the game reads
at runtime into assets/hd/, where Godot imports it and the export packs it:

  assets/hd/hall/             the Hall: render, depth, glows, props, doors and
                              region.json (hall_prototype.py)
  assets/hd/rooms/<room>/     each room: render, render.json, depth, glows and
                              props (room_prototype.py); the Library also its
                              light (render-library.json) and awakened render
  assets/hd/characters/       each figure's idle, walk and run sheets and its
                              <character>.json (character_prototype.py)
  assets/hd/portraits/        the speakers' dialogue portraits and
                              portraits.json (portrait_prototype.py)
  assets/hd/maps/             the Map Hub's Hall map and the Circuit repair
                              map's board

Colour images are written as WebP at quality 92 and imported lossy (0.85), as
the painted backgrounds are, about a fifteenth of their PNG size in the pack;
alpha stays lossless. Depth maps stay lossless PNG, unfiltered and without
alpha-border fixing, since they carry numbers (each pixel's wall ground y).
Sheets, portraits and maps are imported with mipmaps, being drawn smaller
than their pixels. The JSON's image names are rewritten to the published
files. An idle sheet wider than 4096 px (36 frames of 128 px) is laid out in
bands of fewer columns, its JSON gaining "columns", so no texture passes the
4096 px some WebGL devices allow; the frame index in a Sprite2D grid is the
same. Portraits are drawn at 224 px (twice the 112 px dialogue box), and the
repair map is the Circuit Room's render with its props laid in, at the painted
board's 1448 x 1086. Files the look no longer uses are removed.

    /tmp/sc-img-venv/bin/python tools/blender/publish_hd.py

Run it after any render, then import (the headless editor) before playing or
capturing. Needs Pillow.
"""
import io
import json
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROTO = os.path.join(ROOT, "prototypes")
OUT = os.path.join(ROOT, "assets", "hd")
ROOMS = ("wake_room", "chemistry_room", "greenhouse_room", "library_room", "dining_hall_room", "circuit_room",
         "final_room")
CHARACTERS = ("detective", "guardian", "butler", "gardener", "mechanic", "dr_lin")
WEBP_QUALITY = 92
MAX_TEXTURE = 4096
PORTRAIT_PX = 224
MAP_SIZE = (1448, 1086)

# Godot's texture import settings by kind: renders and props lossy like the
# painted backgrounds; sheets, portraits and maps lossy with mipmaps; data
# maps lossless and untouched.
IMPORTS = {
    "colour": {"compress/mode": "1", "compress/lossy_quality": "0.85", "mipmaps/generate": "false",
               "process/fix_alpha_border": "true"},
    "mipmapped": {"compress/mode": "1", "compress/lossy_quality": "0.85", "mipmaps/generate": "true",
                  "process/fix_alpha_border": "true"},
    "data": {"compress/mode": "0", "compress/lossy_quality": "0.7", "mipmaps/generate": "false",
             "process/fix_alpha_border": "false"},
}
IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{source}"

[params]

compress/mode={compress/mode}
compress/high_quality=false
compress/lossy_quality={compress/lossy_quality}
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate={mipmaps/generate}
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border={process/fix_alpha_border}
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


class Publisher:
    def __init__(self):
        self.written = set()
        self.bytes = 0

    def _keep(self, path):
        self.written.add(os.path.abspath(path))
        self.bytes += os.path.getsize(path)

    def _import(self, path, kind):
        """Writes `path`'s .import with `kind`'s settings, or brings an
        existing one's settings in line, keeping its uid."""
        settings = IMPORTS[kind]
        import_path = path + ".import"
        self.written.add(os.path.abspath(import_path))
        if not os.path.exists(import_path):
            source = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
            with open(import_path, "w", encoding="utf-8") as handle:
                handle.write(IMPORT_TEMPLATE.format(source=source, **settings))
            return
        with open(import_path, encoding="utf-8") as handle:
            lines = handle.read().split("\n")
        changed = False
        for index, line in enumerate(lines):
            key = line.split("=", 1)[0]
            if key in settings and line != key + "=" + settings[key]:
                lines[index] = key + "=" + settings[key]
                changed = True
        if changed:
            with open(import_path, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))

    def _same(self, path, data):
        if not os.path.exists(path):
            return False
        with open(path, "rb") as handle:
            return handle.read() == data

    def image(self, image, path, kind="colour"):
        """`image` as WebP (colour) or PNG (data) at `path`; unchanged files
        are left alone so Godot does not reimport them."""
        buffer = io.BytesIO()
        if path.endswith(".png"):
            image.save(buffer, "PNG", optimize=True)
        else:
            image.save(buffer, "WEBP", quality=WEBP_QUALITY, method=6, alpha_quality=100)
        data = buffer.getvalue()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not self._same(path, data):
            with open(path, "wb") as handle:
                handle.write(data)
        self._keep(path)
        self._import(path, kind)

    def copy(self, source, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(source, "rb") as handle:
            data = handle.read()
        if not self._same(path, data):
            shutil.copyfile(source, path)
        self._keep(path)
        # A data image keeps its pixels exactly.
        if path.endswith(".png"):
            self._import(path, "data")

    def json(self, value, path):
        data = (json.dumps(value, indent=1, ensure_ascii=False) + "\n").encode("utf-8")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not self._same(path, data):
            with open(path, "wb") as handle:
                handle.write(data)
        self._keep(path)

    def prune(self):
        """Removes what earlier runs published and this one did not."""
        removed = 0
        for directory, _dirs, files in os.walk(OUT):
            for name in files:
                path = os.path.abspath(os.path.join(directory, name))
                if path not in self.written:
                    os.remove(path)
                    removed += 1
        for directory, dirs, files in sorted(os.walk(OUT), reverse=True):
            if directory != OUT and not os.listdir(directory):
                os.rmdir(directory)
        return removed


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def webp_name(name):
    return os.path.splitext(name)[0] + ".webp"


def publish_props(pub, source_dir, out_dir, props_file):
    """A render's props: each prop image as WebP, the JSON pointing at it."""
    listed = load_json(os.path.join(source_dir, props_file))
    for prop in listed.get("props", []):
        image = Image.open(os.path.join(source_dir, prop["image"]))
        prop["image"] = webp_name(prop["image"])
        pub.image(image, os.path.join(out_dir, prop["image"]))
    pub.json(listed, os.path.join(out_dir, props_file))
    return listed


def publish_room(pub, room):
    source = os.path.join(PROTO, "blender_rooms", room)
    out = os.path.join(OUT, "rooms", room)
    meta = load_json(os.path.join(source, "render.json"))
    image = meta.get("image", "render.png")
    pub.image(Image.open(os.path.join(source, image)).convert("RGB"), os.path.join(out, webp_name(image)))
    meta["image"] = webp_name(image)
    # render.json lists the props as well: name their published images.
    for prop in meta.get("props", []):
        prop["image"] = webp_name(prop["image"])
    depth = meta.get("depth", "render-depth.png")
    pub.copy(os.path.join(source, depth), os.path.join(out, depth))
    pub.json(meta, os.path.join(out, "render.json"))
    pub.copy(os.path.join(source, "render-glows.json"), os.path.join(out, "render-glows.json"))
    publish_props(pub, source, out, "render-props.json")
    if room == "library_room":
        pub.copy(os.path.join(source, "render-library.json"), os.path.join(out, "render-library.json"))
        pub.image(Image.open(os.path.join(source, "render-awakened.png")).convert("RGB"),
                  os.path.join(out, "render-awakened.webp"))
        pub.copy(os.path.join(source, "render-awakened-glows.json"),
                 os.path.join(out, "render-awakened-glows.json"))
    return meta


def publish_hall(pub):
    source = os.path.join(PROTO, "blender_hall")
    out = os.path.join(OUT, "hall")
    pub.image(Image.open(os.path.join(source, "render.png")).convert("RGB"), os.path.join(out, "render.webp"))
    pub.copy(os.path.join(source, "render-depth.png"), os.path.join(out, "render-depth.png"))
    pub.copy(os.path.join(source, "region.json"), os.path.join(out, "region.json"))
    pub.copy(os.path.join(source, "render-glows.json"), os.path.join(out, "render-glows.json"))
    publish_props(pub, source, out, "render-props.json")
    doors = load_json(os.path.join(source, "render-doors.json"))
    for door in doors.get("doors", []):
        image = Image.open(os.path.join(source, door["image"]))
        door["image"] = webp_name(door["image"])
        pub.image(image, os.path.join(out, door["image"]))
    pub.json(doors, os.path.join(out, "render-doors.json"))


def banded(image, cell, frames, rows):
    """An 8-facing sheet `frames` cells wide laid out in bands of fewer
    columns, each facing's frames running on across its bands, so the sheet
    fits MAX_TEXTURE. Returns (image, columns)."""
    width, height = cell
    columns = frames
    while columns * width > MAX_TEXTURE:
        columns = next(c for c in range(columns - 1, 0, -1) if frames % c == 0)
    if columns == frames:
        return image, frames
    bands = frames // columns
    out = Image.new(image.mode, (columns * width, rows * bands * height), (0, 0, 0, 0))
    for row in range(rows):
        for frame in range(frames):
            cell_image = image.crop((frame * width, row * height, (frame + 1) * width, (row + 1) * height))
            out.paste(cell_image, ((frame % columns) * width, (row * bands + frame // columns) * height))
    return out, columns


def publish_characters(pub):
    source = os.path.join(PROTO, "blender_chars")
    out = os.path.join(OUT, "characters")
    for character in CHARACTERS:
        meta = load_json(os.path.join(source, character + ".json"))
        cell = (int(meta["cell"][0]), int(meta["cell"][1]))
        rows = len(meta["rows"])
        for gait, entry in meta["gaits"].items():
            image = Image.open(os.path.join(source, entry["image"])).convert("RGBA")
            image, columns = banded(image, cell, int(entry["frames"]), rows)
            if columns != int(entry["frames"]):
                entry["columns"] = columns
            entry["image"] = webp_name(entry["image"])
            pub.image(image, os.path.join(out, entry["image"]), "mipmapped")
        # Where the model came from is the pipeline's business, not the game's.
        meta.pop("source", None)
        pub.json(meta, os.path.join(out, character + ".json"))


def publish_portraits(pub):
    source = os.path.join(PROTO, "blender_chars", "portraits")
    out = os.path.join(OUT, "portraits")
    index = load_json(os.path.join(source, "portraits.json"))
    for entry in index["portraits"].values():
        image = Image.open(os.path.join(source, entry["image"])).convert("RGBA")
        image = image.resize((PORTRAIT_PX, PORTRAIT_PX), Image.LANCZOS)
        entry["image"] = webp_name(entry["image"])
        pub.image(image, os.path.join(out, entry["image"]), "mipmapped")
    index["size"] = PORTRAIT_PX
    pub.json(index, os.path.join(out, "portraits.json"))


def publish_maps(pub):
    out = os.path.join(OUT, "maps")
    hall_map = Image.open(os.path.join(PROTO, "blender_hall", "map.png")).convert("RGB")
    pub.image(hall_map, os.path.join(out, "hall_map.webp"), "mipmapped")
    # The repair map's board: the Circuit Room's render with its props laid
    # back in where they stand, at the painted background's size.
    source = os.path.join(PROTO, "blender_rooms", "circuit_room")
    meta = load_json(os.path.join(source, "render.json"))
    scale = float(meta.get("render_scale", 2.0))
    board = Image.open(os.path.join(source, meta.get("image", "render.png"))).convert("RGBA")
    for prop in load_json(os.path.join(source, "render-props.json")).get("props", []):
        layer = Image.open(os.path.join(source, prop["image"])).convert("RGBA")
        at = (round(float(prop["rect"][0]) * scale), round(float(prop["rect"][1]) * scale))
        board.alpha_composite(layer, at)
    board = board.convert("RGB").resize(MAP_SIZE, Image.LANCZOS)
    pub.image(board, os.path.join(out, "circuit_repair.webp"), "mipmapped")


def main():
    pub = Publisher()
    publish_hall(pub)
    for room in ROOMS:
        publish_room(pub, room)
    publish_characters(pub)
    publish_portraits(pub)
    publish_maps(pub)
    removed = pub.prune()
    images = [path for path in pub.written if path.endswith((".webp", ".png"))]
    print("HD_PUBLISHED %d files (%d images), %.1f MB, %d stale removed -> %s" % (
        len([p for p in pub.written if not p.endswith(".import")]), len(images), pub.bytes / 1e6, removed, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
