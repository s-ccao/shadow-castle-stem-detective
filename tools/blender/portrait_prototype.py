"""HD dialogue portraits for the Blender prototype, rendered from the
characters' Tripo models (prototypes/blender_chars/source/, see sources.json).

The game shows the speaker's portrait at the left of each room's dialogue box:
a 112 px square over the frame's own colour, with the speaker's name across
its foot (assets/characters/portraits_pixel_v2/: head and shoulders on a
transparent ground). This script renders the same bust from each model:

  Pose. The standing idle the gait sheets use (character_motion.style_idle at
  rest), the body turned a little to the viewer's right, toward the dialogue
  text, and the head turned most of the way back to the camera.

  Light. The gait sheets' rig, a warm key from the upper left, a cool fill
  from the right and a violet rim from behind, so a portrait matches the
  figure it speaks for, a little stronger for a close bust, with a violet
  kicker so a dark coat stands off the dialogue frame's dark ground. The
  Guardian's visor and core glow as in his sheets.

  Lens. A portrait lens (85 mm on a 36 mm frame) a little above eye level.
  Each bust is framed on its own head: the crown 5 % below the top and the
  chin 57 % down, so the name across the foot covers only the chest (Dr. Lin's
  wide hair and the Guardian's helm on his armour are framed looser).

    Blender -b --factory-startup -P tools/blender/portrait_prototype.py -- \\
        [--character butler] [--out prototypes/blender_chars/portraits/] \\
        [--samples 128] [--size 1024] [--preview]

Writes <out>/<portrait>.png (RGBA, transparent ground) for each character and
<out>/portraits.json, which maps each game portrait the preview replaces to
its HD file (tools/blender/prototype_portraits.gd).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import character_motion as motion  # noqa: E402
import character_prototype as cp  # noqa: E402

GAME_PORTRAITS = "res://assets/characters/portraits_pixel_v2/"
# Each speaker the game gives a portrait: its model (character_prototype's
# CHARACTERS), the portrait it replaces, and the turn of the body and of the
# head back toward the camera (degrees, toward the viewer's right), with a
# tilt of the head for each one's manner. "chin" overrides CHIN where a head
# is framed otherwise: Dr. Lin's hair is wide, and the Guardian's helm sits
# high on an armoured body whose glowing core belongs in the picture.
PORTRAITS = {
    "butler": {"portrait": "butler.png", "turn": 16.0, "head": 11.0, "tilt": 0.0},
    "gardener": {"portrait": "gardener.png", "turn": 18.0, "head": 12.0, "tilt": -4.0},
    "mechanic": {"portrait": "mechanic.png", "turn": 14.0, "head": 8.0, "tilt": 3.0},
    "dr_lin": {"portrait": "dr_lin.png", "turn": 18.0, "head": 12.0, "tilt": -3.0, "chin": 0.53},
    "guardian": {"portrait": "castle_guardian.png", "turn": 14.0, "head": 6.0, "tilt": 0.0, "chin": 0.36},
}
LENS = 85.0
SENSOR = 36.0
# Degrees the camera looks down at the face.
PITCH = 5.0
# Where the crown and the chin sit, from the top of the frame (fractions).
CROWN = 0.05
CHIN = 0.57
# Where the middle of the head sits across the frame.
ACROSS = 0.5
# A bust is closer than a figure: the sheets' key and rim a little stronger,
# a violet kicker from behind the other shoulder so a dark coat stands off the
# dialogue frame's dark ground, and a low warm fill from the camera's side.
LIGHTS = {"Key": 1.2, "Rim": 1.5}
EXTRA_LIGHTS = (
    ("Kicker", (-0.65, 1.0, 0.55), 3.2, (0.8, 0.68, 1.0), 10.0),
    ("Front", (0.15, -1.0, 0.3), 0.55, (1.0, 0.9, 0.78), 30.0),
)
EXPOSURE = 0.2


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"character": None, "out": os.path.join("prototypes", "blender_chars", "portraits"),
               "samples": 128, "size": 1024, "preview": False}
    index = 0
    while index < len(argv):
        key = argv[index]
        if key == "--preview":
            options["preview"] = True
            index += 1
            continue
        value = argv[index + 1]
        if key in ("--samples", "--size"):
            options[key[2:]] = int(value)
        elif key in ("--character", "--out"):
            options[key[2:]] = value
        else:
            raise SystemExit("Unknown option: " + key)
        index += 2
    return options


def pose_bust(character, rig, spec):
    """The idle at rest, the body turned toward the viewer's right and the
    head turned back toward the camera."""
    styles = motion.STYLES[character.name]
    track = cp.build_idle(character, rig, styles)
    cp.place(character, rig, track, track["frames"][0], 0.0)
    pose = motion.Pose(rig, rig.capture())
    back = -spec["head"]
    pose.turn(motion.bone("Neck"), motion.rotation(motion.UP, back * 0.4))
    pose.turn(motion.bone("Head"), motion.rotation(motion.UP, back * 0.6))
    if spec["tilt"]:
        head_forward, _up, _left = pose.frame(motion.bone("Head"))
        pose.turn(motion.bone("Head"), motion.rotation(head_forward, spec["tilt"]))
    rig.apply(pose.channels)
    character.turn.rotation_euler = (0.0, 0.0, math.radians(spec["turn"]))
    bpy.context.view_layer.update()


def head_points(character):
    """The posed vertices above the chin (the Head bone's root): the head, its
    hair and its hat; and that root."""
    points = character.points()
    chin = character.bone_world(motion.bone("Head"))
    return points[points[:, 2] > chin.z], chin


def frame_bust(camera, character, chin_at):
    """Places the camera so the crown sits CROWN and the chin `chin_at` down
    the frame, the head ACROSS it; returns where they landed (frame
    fractions)."""
    scene = bpy.context.scene
    head, chin = head_points(character)
    crown = Vector(head[np.argmax(head[:, 2])])
    middle = Vector(head.mean(axis=0))
    pitch = math.radians(PITCH)
    forward = Vector((0.0, math.cos(pitch), -math.sin(pitch)))
    camera.rotation_euler = (math.radians(90.0) - pitch, 0.0, 0.0)
    fov = 2.0 * math.atan(SENSOR / 2.0 / LENS)
    span = (crown.z - chin.z) / (chin_at - CROWN)
    distance = span / 2.0 / math.tan(fov / 2.0)
    target = Vector((middle.x, middle.y, crown.z + CROWN * span - span / 2.0))
    sample = head[::7]

    def place():
        camera.location = target - forward * distance
        bpy.context.view_layer.update()

    def screen(point):
        view = world_to_camera_view(scene, camera, Vector(point))
        return view.x, 1.0 - view.y

    place()
    for _step in range(8):
        top = min(screen(point)[1] for point in sample)
        distance *= (screen(chin)[1] - top) / (chin_at - CROWN)
        place()
        visible = 2.0 * distance * math.tan(fov / 2.0)
        top = min(screen(point)[1] for point in sample)
        # The crown too low in the frame: lower the camera.
        target.z -= (top - CROWN) * visible
        xs = [screen(point)[0] for point in sample]
        target.x += ((min(xs) + max(xs)) / 2.0 - ACROSS) * visible
        place()
    top = min(screen(point)[1] for point in sample)
    xs = [screen(point)[0] for point in sample]
    return {"crown": round(top, 4), "chin": round(screen(chin)[1], 4),
            "head_width": round(max(xs) - min(xs), 4), "distance": round(distance, 4)}


def light_bust():
    """The gait sheets' rig, brightened for a close bust, with a kicker and a
    front fill."""
    for name, factor in LIGHTS.items():
        bpy.data.lights[name].energy *= factor
    for name, toward, strength, color, spread in EXTRA_LIGHTS:
        data = bpy.data.lights.new(name, "SUN")
        data.energy = strength
        data.color = color
        data.angle = math.radians(spread)
        light = bpy.data.objects.new(name, data)
        light.rotation_euler = (-Vector(toward)).normalized().to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(light)
    bpy.context.scene.view_settings.exposure = EXPOSURE


def render(name, options):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spec = PORTRAITS[name]
    model = cp.CHARACTERS[name]
    size = options["size"]
    samples = 16 if options["preview"] else options["samples"]
    camera = cp.setup_scene(72.0, samples, (size, size))
    light_bust()
    camera.data.type = "PERSP"
    camera.data.lens = LENS
    camera.data.sensor_width = SENSOR
    camera.data.sensor_fit = "HORIZONTAL"
    character = cp.Character(os.path.join(cp.SOURCE, model["glb"]))
    character.name = name
    rig = motion.Rig(character.armature)
    if model.get("glow"):
        character.add_glow(model["glow"])
    pose_bust(character, rig, spec)
    framing = frame_bust(camera, character, spec.get("chin", CHIN))
    out = os.path.join(options["out"], spec["portrait"])
    bpy.context.scene.render.filepath = os.path.abspath(out)
    bpy.ops.render.render(write_still=True)
    print("PORTRAIT %s -> %s %s" % (name, out, framing))
    return {"image": spec["portrait"], "character": name, "turn": spec["turn"], "head": spec["head"],
            "tilt": spec["tilt"], "framing": framing}


def main():
    options = parse_args()
    os.makedirs(options["out"], exist_ok=True)
    index_path = os.path.join(options["out"], "portraits.json")
    listed = {}
    if os.path.exists(index_path):
        with open(index_path, encoding="utf-8") as handle:
            listed = json.load(handle).get("portraits", {})
    names = [options["character"]] if options["character"] else list(PORTRAITS)
    for name in names:
        listed[GAME_PORTRAITS + PORTRAITS[name]["portrait"]] = render(name, options)
    meta = {"generator": "tools/blender/portrait_prototype.py", "size": options["size"], "lens": LENS,
            "pitch": PITCH, "portraits": listed}
    with open(index_path, "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)
    print("PORTRAITS %d -> %s" % (len(listed), index_path))


if __name__ == "__main__":
    main()
