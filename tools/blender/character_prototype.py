"""HD characters for the Blender Hall prototype, as 8-direction walk sheets.

Each character is a rigged, walking 3D model from Tripo (the GLB and its
provenance are in prototypes/blender_chars/source/, see sources.json). This
script renders the model's walk cycle in each of the game's 8 directions
into a sheet whose rows are the game's walk animations. The sheets replace
the pixel sprites' frames in the playable preview only.

Frame 0 of every direction is the standing pose, because the game shows its
idle by stopping a walk on frame 0. It is the walk cycle's mean pose (legs
under the body, arms hanging), set down on the walk's floor; frames 1-7 are
the rest of the cycle, which starts at the right foot passing the left, the
pose nearest to standing.

A character is a sprite standing on one point, not part of the floor plan,
so unlike the Hall it is not stretched: it is a plain orthographic figure
seen from --angle degrees off straight down, the near-front view the pixel
sprites use. Every standing figure is drawn `height` px tall, about twice
the size the preview shows it, so the game scales it down smoothly.

    Blender -b --factory-startup -P tools/blender/character_prototype.py -- \
        --character detective --out prototypes/blender_chars/ [--angle 72] \
        [--samples 64] [--turnaround] [--zoom N]
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hall_prototype as hall  # noqa: E402

# The game's walk animations, top to bottom in every sheet, and the way each
# faces: degrees turned from facing the camera, counter-clockwise from above.
DIRECTIONS = (
    ("walk_down", 0.0), ("walk_down_right", 45.0), ("walk_right", 90.0), ("walk_up_right", 135.0),
    ("walk_up", 180.0), ("walk_up_left", 225.0), ("walk_left", 270.0), ("walk_down_left", 315.0),
)
FRAMES = 8
SOURCE = os.path.join("prototypes", "blender_chars", "source")
# Each character's model, and how its sheet is laid out. The Guardian's
# copies the pixel Guardian's sheet (128 x 156 cells, boots on row 134, a
# 100 px figure), so the game's own scale and foot anchor still fit it.
CHARACTERS = {
    "detective": {"glb": "detective_walk.glb", "height": 100.0, "cell": (128, 128), "feet": 114},
    # The Guardian's visor and core glow violet, as in Tripo's own viewer.
    "guardian": {"glb": "guardian_walk.glb", "height": 100.0, "cell": (128, 156), "feet": 134, "glow": 4.0},
}
FEET = ("mixamorig:LeftFoot", "mixamorig:RightFoot")
TOES = ("mixamorig:LeftToeBase", "mixamorig:RightToeBase")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"character": "detective", "out": "prototypes/blender_chars/", "angle": 72.0, "samples": 64,
               "turnaround": False, "zoom": 1}
    index = 0
    while index < len(argv):
        key = argv[index]
        if key == "--turnaround":
            options["turnaround"] = True
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
    """The imported model: its armature (which carries the walk), its skinned
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
        self.action = self.armature.animation_data.action
        self.start = int(round(self.action.frame_range[0]))
        # Set once the cycle is known: times then wrap into one cycle.
        self.period = None
        self.turn = bpy.data.objects.new("CharTurn", None)
        bpy.context.scene.collection.objects.link(self.turn)
        self.armature.parent = self.turn

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


def walk_cycle(character):
    """The walk's period in frames and the frame its cycle starts on: the
    right foot passing the left. The clip may hold several cycles."""
    start, end = (int(round(value)) for value in character.action.frame_range)
    track = []
    for frame in range(start, end + 1):
        character.set_time(frame)
        track.append([tuple(character.bone_world(name)) for name in FEET])
    track = np.array(track)
    best, period = None, end - start
    for lag in range(8, (end - start) // 1 + 1):
        if end - start - lag < 4:
            break
        error = float(np.mean((track[lag:] - track[:-lag]) ** 2))
        if best is None or error < best * 0.5:
            best, period = error, lag
            if error < 1e-8:
                break
    # Passing: the feet level front to back while the right one swings.
    left, right = track[:period, 0], track[:period, 1]
    swinging = right[:, 2] > left[:, 2]
    gap = np.abs(right[:, 1] - left[:, 1]) + np.where(swinging, 0.0, 1.0)
    return period, start + int(np.argmin(gap))


def cycle_pose(character, first, period):
    """The cycle's mean pose, bone by bone, and where the feet stand on
    average: the point the sprite stands on."""
    samples = {bone.name: ([], [], []) for bone in character.armature.pose.bones}
    anchor = Vector((0.0, 0.0, 0.0))
    for frame in range(first, first + period):
        character.set_time(frame)
        for bone in character.armature.pose.bones:
            rotations, locations, scales = samples[bone.name]
            rotations.append(bone.rotation_quaternion.copy())
            locations.append(bone.location.copy())
            scales.append(bone.scale.copy())
        for foot, toe in zip(FEET, TOES):
            anchor += (character.bone_world(foot) + character.bone_world(toe)) / 2.0
    mean = {}
    for name, (rotations, locations, scales) in samples.items():
        reference = rotations[0]
        total = Quaternion((0.0, 0.0, 0.0, 0.0))
        for rotation in rotations:
            total += rotation if rotation.dot(reference) >= 0.0 else -rotation
        total.normalize()
        mean[name] = (total, sum(locations, Vector()) / period, sum(scales, Vector()) / period)
    anchor /= 2.0 * period
    return mean, Vector((anchor.x, anchor.y, 0.0))


def hold_pose(character, pose):
    """Stops the walk and holds `pose` instead."""
    character.armature.animation_data.action = None
    for bone in character.armature.pose.bones:
        rotation, location, scale = pose[bone.name]
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = rotation
        bone.location = location
        bone.scale = scale
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
    zoom = options["zoom"]
    cell, feet_row, angle = (spec["cell"][0] * zoom, spec["cell"][1] * zoom), spec["feet"] * zoom, options["angle"]
    os.makedirs(options["out"], exist_ok=True)
    camera = setup_scene(angle, options["samples"], cell)
    character = Character(os.path.join(SOURCE, spec["glb"]))
    if spec.get("glow"):
        character.add_glow(spec["glow"])
    period, first = walk_cycle(character)
    character.period = period
    standing, anchor = cycle_pose(character, first, period)
    # The walk's floor: the lowest any foot reaches over the cycle.
    walk_times = [first + period * index / FRAMES for index in range(FRAMES)]
    floor = None
    for time in walk_times:
        character.set_time(time)
        lowest = float(character.points()[:, 2].min())
        floor = lowest if floor is None else min(floor, lowest)
    character.armature.location = (-anchor.x, -anchor.y, -floor)
    print("WALK %s: a %d-frame cycle from frame %d, feet at (%.3f, %.3f), floor %.4f" % (
        name, period, first, anchor.x, anchor.y, floor))
    frames = (0, 2) if options["turnaround"] else tuple(range(FRAMES))
    cells = {}
    scene = bpy.context.scene

    def render(direction, frame):
        path = os.path.join(options["out"], "_cell.png")
        scene.render.filepath = os.path.abspath(path)
        bpy.ops.render.render(write_still=True)
        cells[(direction, frame)] = hall._read_rgba(path)
        os.remove(path)

    # The walk frames first, while the walk still drives the armature.
    extents = {}
    for direction, (_animation, degrees) in enumerate(DIRECTIONS):
        character.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
        for frame in frames:
            if frame:
                character.set_time(walk_times[frame])
                extents[(direction, frame)] = screen_extent(character.points(), angle)
    # Then the standing pose, set down on the walk's floor.
    hold_pose(character, standing)
    character.turn.rotation_euler = (0.0, 0.0, 0.0)
    character.armature.location.z -= float(character.points()[:, 2].min())
    scale = screen_extent(character.points(), angle)[3] / (spec["height"] * zoom)
    frame_camera(camera, angle, scale, cell, feet_row)
    for direction, (_animation, degrees) in enumerate(DIRECTIONS):
        character.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
        extents[(direction, 0)] = screen_extent(character.points(), angle)
        if 0 in frames:
            render(direction, 0)
    # Everything must stay inside the cell whichever way the figure turns.
    for (direction, frame), (left, right, low, high) in sorted(extents.items()):
        left, right, low, high = (value / scale for value in (left, right, low, high))
        if (-left > cell[0] / 2 - 2 or right > cell[0] / 2 - 2 or high > feet_row - 2
                or -low > cell[1] - feet_row - 2):
            print("WARNING %s %d: figure px %.1f..%.1f wide, %.1f..%.1f high leaves the cell" % (
                DIRECTIONS[direction][0], frame, left, right, low, high))
    print("FRAMING %s at %.0f degrees: %.5f units a px, standing %.1f px" % (name, angle, scale, spec["height"] * zoom))
    # Back to the walk for its frames.
    character.armature.animation_data.action = character.action
    character.armature.location.z = -floor
    for direction, (_animation, degrees) in enumerate(DIRECTIONS):
        character.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
        for frame in frames:
            if frame:
                character.set_time(walk_times[frame])
                render(direction, frame)
    rows = [np.concatenate([cells[(direction, frame)] for frame in frames], axis=1)
            for direction in range(len(DIRECTIONS))]
    if options["turnaround"]:
        image = os.path.join(options["out"], "%s_turnaround_%d%s.png" % (
            name, int(angle), "_x%d" % zoom if zoom > 1 else ""))
        hall._write_png(image, np.ascontiguousarray(np.concatenate(rows, axis=1)))
        print("TURNAROUND", image)
        return
    sheet = np.ascontiguousarray(np.concatenate(rows, axis=0))
    image = os.path.join(options["out"], "%s_walk_8dir.png" % name)
    hall._write_png(image, sheet)
    meta = {"generator": "tools/blender/character_prototype.py", "source": os.path.join(SOURCE, spec["glb"]),
            "image": os.path.basename(image), "cell": list(cell), "feet": [cell[0] / 2.0, feet_row],
            "frames": FRAMES, "angle": angle, "height": spec["height"],
            "rows": {animation: row for row, (animation, _d) in enumerate(DIRECTIONS)}}
    with open(os.path.join(options["out"], "%s.json" % name), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)
    print("SHEET %s: %d x %d cells of %dx%d" % (image, FRAMES, len(DIRECTIONS), cell[0], cell[1]))


if __name__ == "__main__":
    main()
