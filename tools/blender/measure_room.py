"""Measure a Blender room against its painting by the room standard
(docs/AGENT_HANDOFF.md, "Room standard"): the render's mean luminance and
warmth (mean R - B) with its props laid in, at the painting's size, and the
luminance spread of the open floor (stone-to-joint contrast) where the
collision leaves floor and no prop covers it. The standard asks for the
first two within about 15 % of the painting's; a floor spread near the
painting's or lower.

    python tools/blender/measure_room.py <room> <painting> [render.png]

  room      a folder under prototypes/blender_rooms/ (its render.json and
            collision.png come from there)
  painting  the painted background, from the project root
            (assets/backgrounds/dining_hall_banquet.png)
  render    another render of the room (a preview's --out), whose props are
            read from beside it when it wrote them there

Needs Pillow and numpy (not Blender).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) + "/"


def luminance(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    room, painting = sys.argv[1], sys.argv[2]
    data = ROOT + "prototypes/blender_rooms/%s/" % room
    render_path = sys.argv[3] if len(sys.argv) > 3 else data + "render.png"
    run = os.path.dirname(os.path.abspath(render_path)) + "/"
    base = os.path.splitext(os.path.basename(render_path))[0]
    if os.path.exists(run + base + "-props.json"):
        props_dir, props_json = run, run + base + "-props.json"
    else:
        props_dir, props_json = data, data + "render-props.json"
    meta = json.load(open(data + "render.json"))
    scale = float(meta.get("render_scale", 2.0))
    image = Image.open(render_path).convert("RGBA")
    covered = Image.new("L", image.size, 0)
    for prop in json.load(open(props_json))["props"]:
        layer = Image.open(props_dir + prop["image"]).convert("RGBA")
        at = (int(round(prop["rect"][0] * scale)), int(round(prop["rect"][1] * scale)))
        image.alpha_composite(layer, at)
        covered.paste(255, at, layer.split()[3].point(lambda a: 255 if a > 16 else 0))
    paint = Image.open(ROOT + painting).convert("RGB")
    size = paint.size
    hd = np.asarray(image.convert("RGB").resize(size, Image.LANCZOS)).astype(float)
    pt = np.asarray(paint).astype(float)
    walls = Image.open(data + "collision.png").convert("L").resize(size, Image.NEAREST)
    cover = covered.resize(size, Image.NEAREST)
    floor = (np.asarray(walls) < 128) & (np.asarray(cover) < 128)
    # Only the floor away from the walls' feet and the frame's dark margins.
    lp, lh = luminance(pt), luminance(hd)
    floor &= (lp > 8) & (lh > 8)
    warm_p, warm_h = (pt[..., 0] - pt[..., 2]).mean(), (hd[..., 0] - hd[..., 2]).mean()
    print("%-10s mean luminance %.1f   warmth %+.1f   floor spread %.1f   (%d floor px)" % (
        "painting", lp.mean(), warm_p, lp[floor].std(), floor.sum()))
    print("%-10s mean luminance %.1f   warmth %+.1f   floor spread %.1f" % (
        "render", lh.mean(), warm_h, lh[floor].std()))
    print("ratio      luminance %.2f   warmth %.2f   floor spread %.2f" % (
        lh.mean() / lp.mean(), warm_h / max(warm_p, 1e-6), lh[floor].std() / lp[floor].std()))


if __name__ == "__main__":
    main()
