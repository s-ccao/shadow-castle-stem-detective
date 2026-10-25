"""HD characters for the Blender Hall prototype, as 8-direction gait sheets.

Each character is a rigged 3D model from Tripo with its preset clips (the GLB
and its provenance are in prototypes/blender_chars/source/, see
sources.json). This script renders three gaits in each of the game's 8
directions, one sheet each, whose rows are the game's walk animations:

  idle  a standing loop: breathing, a sway and a look around;
  walk  one walk cycle in 8 frames;
  run   one run cycle in 8 frames.

character_motion.py keeps each clip's legs and restyles the rest so it reads
on a 50 px chibi figure. A walk or run cycle starts on the right foot's
contact, so the preview can switch between them mid-stride. Each sheet's
"stride" in <character>.json is the ground one cycle covers, in sheet px,
which is what lets the preview play a cycle exactly as fast as the body
moves.

A character is a sprite standing on one point, not part of the floor plan,
so unlike the Hall it is not stretched: it is a plain orthographic figure
seen from --angle degrees off straight down, the near-front view the pixel
sprites use. The standing figure is drawn `height` px tall, about twice the
size the preview shows it, so the game scales it down smoothly.

    Blender -b --factory-startup -P tools/blender/character_prototype.py -- \\
        --character detective --out prototypes/blender_chars/ [--angle 72] \\
        [--samples 64] [--preview] [--zoom N]

--preview writes a quick contact sheet of every gait instead of the sheets.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import character_motion as motion  # noqa: E402
import hall_prototype as hall  # noqa: E402

# The game's walk animations, top to bottom in every sheet, and the way each
# faces: degrees turned from facing the camera, counter-clockwise from above.
DIRECTIONS = (
    ("walk_down", 0.0), ("walk_down_right", 45.0), ("walk_right", 90.0), ("walk_up_right", 135.0),
    ("walk_up", 180.0), ("walk_up_left", 225.0), ("walk_left", 270.0), ("walk_down_left", 315.0),
)
GAITS = ("idle", "walk", "run")
SOURCE = os.path.join("prototypes", "blender_chars", "source")
# Each character's model, and how its sheets are laid out. The Guardian's
# copy the pixel Guardian's sheet (128 x 156 cells, boots on row 134, a
# 100 px figure), so the game's own scale and foot anchor still fit them.
CHARACTERS = {
    "detective": {"glb": "detective_anims.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
    # The Guardian's visor and core glow violet, as in Tripo's own viewer.
    "guardian": {"glb": "guardian_anims.glb", "height": 100.0, "cell": (128, 156), "feet": 134, "glow": 4.0},
    # The rooms' cast, each drawn as tall as the detective: the pixel NPCs
    # all stand about 90 px in their rooms, as he does.
    "butler": {"glb": "butler_anims.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
    "gardener": {"glb": "gardener_anims.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
    "mechanic": {"glb": "mechanic_anims.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
    "dr_lin": {"glb": "dr_lin_anims.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
}
FEET = (motion.bone("LeftFoot"), motion.bone("RightFoot"))
# Fine samples a cycle is measured on; a multiple of the frames drawn.
SAMPLES = 64
# How far the arms swing behind the legs, as a share of the cycle.
ARM_LAG = 0.07


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"character": "detective", "out": "prototypes/blender_chars/", "angle": 72.0, "samples": 64,
               "preview": False, "zoom": 1}
    index = 0
    while index < len(argv):
        key = argv[index]
        if key == "--preview":
            options["preview"] = True
            index += 1
            continue
        value = argv[index + 1]
        if key == "--angle":
            options["angle"] = float(value)
        elif key == "--zoom":
            options["zoom"] = int(value)
        elif key == "--samples":
            options["samples"] = int(value)
        elif key in ("--character", "--out"):
            options[key[2:]] = value
        else:
            raise SystemExit("Unknown option: " + key)
        index += 2
    return options


class Character:
    """The imported model: its armature (which carries the clips), its skinned
    meshes, and a turn pivot on the floor under its feet."""

    def __init__(self, path):
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
        self.armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
        self.meshes = [obj for obj in bpy.context.scene.objects
                       if obj.type == "MESH" and obj.parent == self.armature]
        # Tripo's export carries a stray untextured icosphere around the
        # origin, which would hide the figure.
        for obj in list(bpy.context.scene.objects):
            if obj.type == "MESH" and obj not in self.meshes:
                bpy.data.objects.remove(obj, do_unlink=True)
        # The importer stacks every clip on the NLA; only the one in use plays.
        for track in self.armature.animation_data.nla_tracks:
            track.mute = True
        self.start = 0
        self.period = None
        self.glow_nodes = []
        self.shoes = self._shoes()
        self.turn = bpy.data.objects.new("CharTurn", None)
        bpy.context.scene.collection.objects.link(self.turn)
        self.armature.parent = self.turn

    def _shoes(self):
        """Each side's shoe: the vertices mostly skinned to its foot bones,
        as indices into points()."""
        shoes = {side: [] for side, _sign in motion.SIDES}
        offset = 0
        for obj in self.meshes:
            names = {group.index: group.name for group in obj.vertex_groups}
            for vertex in obj.data.vertices:
                share = {side: 0.0 for side in shoes}
                for element in vertex.groups:
                    name = names.get(element.group, "")
                    for side in shoes:
                        if name in [motion.bone(side + part) for part in motion.FOOT_BONES]:
                            share[side] += element.weight
                for side, weight in share.items():
                    if weight > 0.5:
                        shoes[side].append(offset + vertex.index)
            offset += len(obj.data.vertices)
        return [np.array(shoes[side]) for side, _sign in motion.SIDES]

    def soles(self):
        """Each shoe's lowest point and the middle of its sole (x, y, z), as
        posed now."""
        points = self.points()
        result = []
        for indices in self.shoes:
            shoe = points[indices]
            low = float(shoe[:, 2].min())
            sole = shoe[shoe[:, 2] < low + 0.01]
            result.append((low, tuple(sole.mean(axis=0))))
        return result

    def use(self, clip, period=None):
        action = bpy.data.actions[clip]
        self.armature.animation_data.action = action
        self.start = int(round(action.frame_range[0]))
        self.period = period
        return action

    def add_glow(self, strength):
        """Lights the violet texels: blue well above green, which no steel,
        bronze or cloth texel is."""
        for obj in self.meshes:
            for material in obj.data.materials:
                nodes, links = material.node_tree.nodes, material.node_tree.links
                shader = next(node for node in nodes if node.bl_idname == "ShaderNodeBsdfPrincipled")
                color = shader.inputs["Base Color"].links[0].from_socket
                channels = nodes.new("ShaderNodeSeparateColor")
                links.new(color, channels.inputs["Color"])
                violet = nodes.new("ShaderNodeMath")
                violet.operation = "SUBTRACT"
                links.new(channels.outputs["Blue"], violet.inputs[0])
                links.new(channels.outputs["Green"], violet.inputs[1])
                mask = nodes.new("ShaderNodeMapRange")
                mask.clamp = True
                mask.inputs["From Min"].default_value = 0.06
                mask.inputs["From Max"].default_value = 0.25
                mask.inputs["To Max"].default_value = strength
                links.new(violet.outputs["Value"], mask.inputs["Value"])
                links.new(color, shader.inputs["Emission Color"])
                links.new(mask.outputs["Result"], shader.inputs["Emission Strength"])
                self.glow_nodes.append(mask)

    def set_glow(self, strength):
        for node in self.glow_nodes:
            node.inputs["To Max"].default_value = strength

    def bone_world(self, name):
        return self.armature.matrix_world @ self.armature.pose.bones[name].head

    def set_time(self, frame):
        if self.period:
            frame = self.start + (frame - self.start) % self.period
        whole = math.floor(frame)
        bpy.context.scene.frame_set(int(whole), subframe=frame - whole)

    def points(self):
        """Every skinned vertex as it is posed now, in world space."""
        depsgraph = bpy.context.evaluated_depsgraph_get()
        chunks = []
        for obj in self.meshes:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            coords = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
            mesh.vertices.foreach_get("co", coords)
            matrix = np.array(evaluated.matrix_world)
            evaluated.to_mesh_clear()
            coords = coords.reshape(-1, 3)
            chunks.append(coords @ matrix[:3, :3].T + matrix[:3, 3])
        return np.concatenate(chunks)


def find_cycle(character, rig, clip):
    """A clip's cycle: its period in frames, the frame the right foot comes
    down on (most forward), and the left arm's swing over the cycle (-1..1:
    forward while the right foot leads), sampled SAMPLES times."""
    action = character.use(clip)
    start, end = (int(round(value)) for value in action.frame_range)
    track = []
    for step in range((end - start) * 4 + 1):
        character.set_time(start + step / 4.0)
        track.append([tuple(character.bone_world(name)) for name in FEET])
    track = np.array(track)
    lags = range(32, len(track) - 16)
    errors = np.array([float(np.mean((track[lag:] - track[:-lag]) ** 2)) for lag in lags])
    # The first lag that repeats as well as any: a clip may hold two cycles.
    good = np.flatnonzero(errors <= errors.min() * 1.5 + 1e-8)
    lag = lags[int(good[0])]
    while lag + 1 < lags[-1] and errors[lag + 1 - lags[0]] < errors[lag - lags[0]]:
        lag += 1
    period = lag / 4.0
    cycle = track[:lag]
    first = start + int(np.argmin(cycle[:, 1, 1])) / 4.0
    character.use(clip, period)
    lead = []
    for step in range(SAMPLES):
        character.set_time(first + period * step / SAMPLES)
        left, right = (character.bone_world(name) for name in FEET)
        lead.append(left.y - right.y)
    lead = np.array(lead)
    lead /= np.abs(lead).max()
    return period, first, lead


def swing_at(lead, phase):
    """The left arm's swing at `phase`, a beat behind the legs."""
    position = ((phase - ARM_LAG) % 1.0) * len(lead)
    index = int(position)
    weight = position - index
    return float(lead[index % len(lead)] * (1.0 - weight) + lead[(index + 1) % len(lead)] * weight)


def build_cycle(character, rig, styles, gait):
    """Every frame of a walk or run, styled and set on the floor."""
    style = styles[gait]
    period, first, lead = find_cycle(character, rig, style["clip"])
    times = [first + period * step / SAMPLES for step in range(SAMPLES)]
    means = motion.leg_means(rig, character, times)
    lean = []
    for time in times[::8]:
        rig.reset()
        character.set_time(time)
        bpy.context.view_layer.update()
        lean.append(motion.torso_lean(motion.Pose(rig, rig.capture())))
    unlean = float(np.mean(lean)) - style["lean"]

    def styled(time):
        rig.reset()
        character.set_time(time)
        pose = motion.Pose(rig, rig.capture())
        phase = ((time - first) / period) % 1.0
        swing = swing_at(lead, phase)
        motion.exaggerate(pose, means, style.get("stride", 1.0), style.get("knee", 1.0))
        motion.style_cycle(pose, style, phase, swing, unlean)
        motion.arms(pose, style, swing, styles["hand"])
        return pose.channels

    lifts, stride, anchor, airborne = motion.settle(rig, character, times, styled, style.get("air", 0.0))
    fps = bpy.context.scene.render.fps
    count = style["frames"]
    frames = []
    for index in range(count):
        sample = index * SAMPLES // count
        frames.append({"channels": styled(times[sample]), "lift": float(lifts[sample]),
                       "glow": 1.2 if gait == "run" else 1.0})
    print("CYCLE %s: %d frames from %.2f (%.3f s), lean %.1f -> %.1f deg, stride %.3f u a cycle, in the air %.0f%%" % (
        gait, round(period), first, period / fps, float(np.mean(lean)), style["lean"], stride, 100.0 * airborne))
    return {"frames": frames, "anchor": anchor, "stride": stride, "seconds": period / fps}


def build_idle(character, rig, styles):
    """The standing loop: the idle clip's first pose, breathing and looking."""
    style = styles["idle"]
    character.use(style["clip"])
    rig.reset()
    character.set_time(character.start)
    base = rig.capture()
    count = style["frames"]
    frames = []
    for index in range(count):
        pose = motion.Pose(rig, base)
        time = index / count
        breath = motion.style_idle(pose, style, time)
        motion.arms(pose, style, 0.35 * math.sin(2.0 * math.pi * time), styles["hand"])
        frames.append({"channels": pose.channels, "lift": 0.0, "glow": 0.85 + 0.3 * breath})
    character.armature.animation_data.action = None
    rig.apply(frames[0]["channels"])
    bpy.context.view_layer.update()
    anchor = np.mean([tuple(motion.foot_mid(rig, side)) for side, _s in motion.SIDES], axis=0)
    return {"frames": frames, "anchor": anchor, "stride": 0.0, "seconds": style["seconds"]}


def place(character, rig, track, frame, floor):
    """Holds `frame` of `track`, its feet centred on the turn pivot."""
    character.armature.animation_data.action = None
    rig.apply(frame["channels"])
    anchor = track["anchor"]
    character.armature.location = (-anchor[0], -anchor[1], frame["lift"] - floor)
    bpy.context.view_layer.update()


def setup_scene(angle, samples, cell):
    scene = bpy.context.scene
    hall.setup_cycles(samples, False)
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x, scene.render.resolution_y = cell
    world = bpy.data.worlds.new("CharWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.1, 0.09, 0.13, 1.0)
    background.inputs["Strength"].default_value = 1.0
    # A warm key from the upper left, a cool fill from the right and a violet
    # rim from behind, fixed to the camera as the figure turns.
    for name, toward, strength, color, spread in (
            ("Key", (-0.55, -0.75, 0.95), 3.8, (1.0, 0.94, 0.86), 12.0),
            ("Fill", (0.9, -0.5, 0.2), 0.7, (0.72, 0.8, 1.0), 25.0),
            ("Rim", (0.35, 1.0, 0.75), 3.6, (0.85, 0.74, 1.0), 8.0)):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = strength
        data.color = color
        data.angle = math.radians(spread)
        light = bpy.data.objects.new(name, data)
        light.rotation_euler = (-Vector(toward)).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)
    data = bpy.data.cameras.new("CharCamera")
    data.type = "ORTHO"
    data.clip_start = 0.01
    data.clip_end = 20.0
    camera = bpy.data.objects.new("CharCamera", data)
    camera.rotation_euler = (math.radians(angle), 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def screen_extent(points, angle):
    """(left, right, low, high) of `points` on screen, Blender units, up being
    screen up from the floor point under the turn pivot."""
    alpha = math.radians(angle)
    up = points[:, 1] * math.cos(alpha) + points[:, 2] * math.sin(alpha)
    return float(points[:, 0].min()), float(points[:, 0].max()), float(up.min()), float(up.max())


def frame_camera(camera, angle, scale, cell, feet_row):
    """Feet at (centre, feet_row) of the cell, `scale` Blender units a px."""
    alpha = math.radians(angle)
    camera.data.ortho_scale = max(cell) * scale
    up = Vector((0.0, math.cos(alpha), math.sin(alpha)))
    view = Vector((0.0, math.sin(alpha), -math.cos(alpha)))
    camera.location = up * (feet_row - cell[1] / 2.0) * scale - view * 5.0


def main():
    options = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    name = options["character"]
    spec = CHARACTERS[name]
    styles = motion.STYLES[name]
    zoom = options["zoom"]
    cell, feet_row, angle = (spec["cell"][0] * zoom, spec["cell"][1] * zoom), spec["feet"] * zoom, options["angle"]
    os.makedirs(options["out"], exist_ok=True)
    camera = setup_scene(angle, 16 if options["preview"] else options["samples"], cell)
    character = Character(os.path.join(SOURCE, spec["glb"]))
    rig = motion.Rig(character.armature)
    if spec.get("glow"):
        character.add_glow(spec["glow"])
    tracks = {"idle": build_idle(character, rig, styles)}
    for gait in ("walk", "run"):
        tracks[gait] = build_cycle(character, rig, styles, gait)
    # Each gait's floor: the lowest any part of it reaches over its frames.
    for gait, track in tracks.items():
        lowest = None
        for frame in track["frames"]:
            place(character, rig, track, frame, 0.0)
            low = float(character.points()[:, 2].min())
            lowest = low if lowest is None else min(lowest, low)
        track["floor"] = lowest
    # Scale: the standing figure is `height` px tall.
    character.turn.rotation_euler = (0.0, 0.0, 0.0)
    place(character, rig, tracks["idle"], tracks["idle"]["frames"][0], tracks["idle"]["floor"])
    scale = screen_extent(character.points(), angle)[3] / (spec["height"] * zoom)
    frame_camera(camera, angle, scale, cell, feet_row)
    print("FRAMING %s at %.0f degrees: %.5f units a px, standing %.1f px" % (name, angle, scale, spec["height"] * zoom))
    scene = bpy.context.scene

    def render():
        path = os.path.join(options["out"], "_cell_%s_%d.png" % (name, os.getpid()))
        scene.render.filepath = os.path.abspath(path)
        bpy.ops.render.render(write_still=True)
        image = hall._read_rgba(path)
        os.remove(path)
        return image

    if options["preview"]:
        rows = []
        for gait in GAITS:
            track = tracks[gait]
            picks = range(0, len(track["frames"]), max(1, len(track["frames"]) // 8))
            for degrees in (0.0, 45.0, 90.0, 180.0):
                character.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
                strip = []
                for index in list(picks)[:8]:
                    frame = track["frames"][index]
                    place(character, rig, track, frame, track["floor"])
                    character.set_glow(spec.get("glow", 0.0) * frame["glow"])
                    strip.append(render())
                rows.append(np.concatenate(strip, axis=1))
        image = os.path.join(options["out"], "%s_preview.png" % name)
        hall._write_png(image, np.ascontiguousarray(np.concatenate(rows, axis=0)))
        print("PREVIEW", image)
        return
    meta = {"generator": "tools/blender/character_prototype.py", "source": os.path.join(SOURCE, spec["glb"]),
            "cell": list(cell), "feet": [cell[0] / 2.0, feet_row], "angle": angle, "height": spec["height"],
            "rows": {animation: row for row, (animation, _d) in enumerate(DIRECTIONS)}, "gaits": {}}
    for gait in GAITS:
        track = tracks[gait]
        cells = {}
        for index, frame in enumerate(track["frames"]):
            place(character, rig, track, frame, track["floor"])
            character.set_glow(spec.get("glow", 0.0) * frame["glow"])
            for direction, (_animation, degrees) in enumerate(DIRECTIONS):
                character.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
                left, right, low, high = (value / scale for value in screen_extent(character.points(), angle))
                if (-left > cell[0] / 2 - 2 or right > cell[0] / 2 - 2 or high > feet_row - 2
                        or -low > cell[1] - feet_row - 2):
                    print("WARNING %s %s %d: figure px %.1f..%.1f wide, %.1f..%.1f high leaves the cell" % (
                        gait, DIRECTIONS[direction][0], index, left, right, low, high))
                cells[(direction, index)] = render()
        count = len(track["frames"])
        rows = [np.concatenate([cells[(direction, index)] for index in range(count)], axis=1)
                for direction in range(len(DIRECTIONS))]
        image = os.path.join(options["out"], "%s_%s_8dir.png" % (name, gait))
        hall._write_png(image, np.ascontiguousarray(np.concatenate(rows, axis=0)))
        entry = {"image": os.path.basename(image), "frames": count}
        if gait == "idle":
            entry["fps"] = count / track["seconds"]
        else:
            entry["stride"] = round(track["stride"] / scale, 2)
            entry["seconds"] = round(track["seconds"], 4)
        meta["gaits"][gait] = entry
        print("SHEET %s: %d x %d cells of %dx%d, %s" % (image, count, len(DIRECTIONS), cell[0], cell[1], entry))
    with open(os.path.join(options["out"], "%s.json" % name), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)


if __name__ == "__main__":
    main()
