"""HD characters for the Blender Hall prototype, as 8-direction walk sheets.

Each character is modelled from smooth primitives, rigged with plain pivots
and walked through an 8-frame cycle in each of the game's 8 directions. The
sheets replace the pixel sprites' frames in the playable preview only.
Frame 0 of every direction is the standing pose, because the game shows its
idle by stopping the walk on frame 0.

A character is a sprite standing on one point, not part of the floor plan,
so unlike the Hall it is not stretched: it is a plain orthographic figure
seen from --angle degrees off straight down, the angle chosen for how the
figure reads. Every standing figure is drawn `height` px tall, about twice
the size the preview shows it, so the game scales it down smoothly.

    Blender -b --factory-startup -P tools/blender/character_prototype.py -- \
        --character detective --out prototypes/blender_chars/ [--angle 65] \
        [--samples 64] [--turnaround]
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hall_prototype as hall  # noqa: E402

PX = hall.PX
# The game's walk animations, top to bottom in every sheet, and the way each
# faces: degrees turned from facing the camera, counter-clockwise from above.
DIRECTIONS = (
    ("walk_down", 0.0), ("walk_down_right", 45.0), ("walk_right", 90.0), ("walk_up_right", 135.0),
    ("walk_up", 180.0), ("walk_up_left", 225.0), ("walk_left", 270.0), ("walk_down_left", 315.0),
)
FRAMES = 8
STRIDE_DEGREES = 24.0
KNEE_DEGREES = 40.0
ARM_SWING = 0.8
ARM_SPLAY_DEGREES = 9.0


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"character": "detective", "out": "prototypes/blender_chars/", "angle": 65.0, "samples": 64,
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


def radius_at(profile, z):
    """A lathe profile's radius at height z, between its (z, r) rings."""
    for (z0, r0), (z1, r1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return profile[0][1] if z < profile[0][0] else profile[-1][1]


def on_front(centre, radii, x, z):
    """The front (-y) of an ellipsoid at (x, z), and the outward normal there."""
    a, b, c = radii
    inside = max(1.0 - ((x - centre[0]) / a) ** 2 - ((z - centre[2]) / c) ** 2, 0.0)
    y = centre[1] - b * math.sqrt(inside)
    normal = Vector(((x - centre[0]) / a ** 2, (y - centre[1]) / b ** 2, (z - centre[2]) / c ** 2))
    return Vector((x, y, z)), normal.normalized()


class Rig:
    """A character's parts, each hung from a pivot so the walk can turn it.
    Model units are px of a figure `height` px tall before framing."""

    def __init__(self, name):
        self.name = name
        self.made = []
        self.turn = self.empty("Turn", None)
        self.body = self.empty("Body", self.turn)

    def empty(self, name, parent, location=(0.0, 0.0, 0.0)):
        obj = bpy.data.objects.new(self.name + name, None)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = Vector(location) * PX
        return obj

    def part(self, name, shape, materials, parent, location=(0.0, 0.0, 0.0), smooth=True):
        """A mesh built around its origin, hung at `location` from `parent`."""
        for face in shape.faces:
            face.smooth = smooth
        mesh = bpy.data.meshes.new(self.name + name)
        shape.to_mesh(mesh)
        shape.free()
        if smooth:
            mesh.set_sharp_from_angle(angle=math.radians(55.0))
        for material in materials if isinstance(materials, (list, tuple)) else (materials,):
            mesh.materials.append(material)
        obj = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = Vector(location) * PX
        self.made.append(obj)
        return obj

    def ball(self, name, centre, axes, material, parent, segments=24, normal=None):
        """An ellipsoid of radii `axes`; given `normal`, its -y axis faces along it."""
        matrix = Matrix.Diagonal((axes[0], axes[1], axes[2], 1.0))
        if normal is not None:
            matrix = Vector(normal).to_track_quat("-Y", "Z").to_matrix().to_4x4() @ matrix
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=segments, v_segments=max(segments // 2, 8), radius=PX,
                                  matrix=matrix)
        return self.part(name, shape, material, parent, centre)

    def tube(self, name, top, bottom, radius_top, radius_bottom, material, parent, flat=1.0, segments=20):
        """A tapered cylinder from `top` to `bottom`, `flat` squashing its depth."""
        top, bottom = Vector(top), Vector(bottom)
        length = (top - bottom).length
        align = (top - bottom).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        shape = bmesh.new()
        bmesh.ops.create_cone(shape, cap_ends=True, cap_tris=False, segments=segments, radius1=radius_bottom * PX,
                              radius2=radius_top * PX, depth=length * PX,
                              matrix=align @ Matrix.Diagonal((1.0, flat, 1.0, 1.0)))
        return self.part(name, shape, material, parent, (top + bottom) / 2.0)

    def lathe(self, name, profile, flat, material, parent, gap=None, segments=40, centre=(0.0, 0.0), hem=None):
        """A surface of revolution through `profile` [(z, r)], each ring an
        ellipse r wide and r*flat deep about `centre` (x, y). `gap(z)` opens
        its front that many degrees either side of -y, leaving an open shell;
        `hem(angle)` raises the lowest ring there, for a tattered edge."""
        shape = bmesh.new()
        rings = []
        for index, (z, r) in enumerate(profile):
            if gap is None:
                angles = [360.0 * k / segments for k in range(segments)]
            else:
                opening = gap(z)
                angles = [opening + (360.0 - 2.0 * opening) * k / segments for k in range(segments + 1)]
            rings.append([shape.verts.new(Vector((
                centre[0] + r * math.sin(math.radians(a)), centre[1] - r * flat * math.cos(math.radians(a)),
                z + (hem(a) if hem is not None and index == 0 else 0.0))) * PX) for a in angles])
        count = len(rings[0])
        for lower, upper in zip(rings, rings[1:]):
            for k in range(count if gap is None else count - 1):
                following = (k + 1) % count
                shape.faces.new((lower[k], lower[following], upper[following], upper[k]))
        if gap is None:
            shape.faces.new(rings[0][::-1])
            shape.faces.new(rings[-1])
        return self.part(name, shape, material, parent)

    def patch(self, name, profile, flat, z_range, angles, lift, material, parent, rows=8, columns=6, hem=None,
              origin=(0.0, 0.0, 0.0)):
        """A thin piece lying `lift` off a lathe's surface, from z_range[0] to
        z_range[1], between the angles (degrees from the front) `angles(z)`
        gives; `hem(angle)` raises its lowest edge. `origin` is where `parent`
        hangs in body space, for a piece that swings with a limb."""
        shape = bmesh.new()
        grid = []
        origin = Vector(origin)
        for i in range(rows + 1):
            z = z_range[0] + (z_range[1] - z_range[0]) * i / rows
            r = radius_at(profile, z) + lift
            first, last = angles(z)
            row = []
            for k in range(columns + 1):
                degrees = first + (last - first) * k / columns
                a = math.radians(degrees)
                lifted = hem(degrees) if hem is not None and i == 0 else 0.0
                row.append(shape.verts.new((Vector((r * math.sin(a), -r * flat * math.cos(a), z + lifted))
                                            - origin) * PX))
            grid.append(row)
        for i in range(rows):
            for k in range(columns):
                shape.faces.new((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]))
        return self.part(name, shape, material, parent)

    def shell(self, name, centre, radii, material, parent, keep=None, segments=40):
        """An ellipsoid; each `keep` plane (point, normal) cuts away all behind it."""
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=segments, v_segments=segments // 2, radius=PX,
                                  matrix=Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0)))
        planes = [] if keep is None else [keep] if isinstance(keep[0][0], (int, float)) else keep
        for point, normal in planes:
            bmesh.ops.bisect_plane(shape, geom=shape.verts[:] + shape.edges[:] + shape.faces[:],
                                   plane_co=(Vector(point) - Vector(centre)) * PX,
                                   plane_no=Vector(normal).normalized(), clear_inner=True)
        return self.part(name, shape, material, parent, centre)

    def lock(self, name, shell, start, end, width, thick, lift, material, parent, curl=0.0, rings=12,
             segments=8):
        """A lock of hair lying on the ellipsoid `shell` (centre, radii) from
        `start` to `end`, each (azimuth from the front toward +x, angle down
        from the top) in degrees: round at the root, pointed at the tip, which
        stands `lift` off the shell. It runs the short way over the shell;
        `curl` bows it sideways, in degrees."""
        centre, radii = Vector(shell[0]), Vector(shell[1])

        def unit_of(azimuth, polar):
            azimuth, polar = math.radians(azimuth), math.radians(polar)
            return Vector((math.sin(polar) * math.sin(azimuth), -math.sin(polar) * math.cos(azimuth),
                           math.cos(polar)))

        first, last = unit_of(*start), unit_of(*end)
        arc = first.angle(last)
        across = first.cross(last).normalized() if arc > 1e-4 else Vector((0.0, 0.0, 0.0))

        def surface(t):
            if arc > 1e-4:
                unit = (first * math.sin((1.0 - t) * arc) + last * math.sin(t * arc)) / math.sin(arc)
            else:
                unit = first.copy()
            unit = (unit + across * math.tan(math.radians(curl)) * math.sin(math.pi * t)).normalized()
            point = centre + Vector((unit.x * radii.x, unit.y * radii.y, unit.z * radii.z))
            return point, Vector((unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)).normalized()

        shape = bmesh.new()
        loops = []
        for i in range(rings + 1):
            t = i / rings
            point, normal = surface(t)
            tangent = (surface(min(t + 0.02, 1.0))[0] - surface(max(t - 0.02, 0.0))[0]).normalized()
            side = tangent.cross(normal).normalized()
            out = side.cross(tangent).normalized()
            spread = width * min(1.0, math.sqrt(t / 0.15)) * (1.0 - t) ** 0.8
            depth = thick * spread / width
            middle = point + out * (depth * 0.6 + lift * t * t)
            if spread < 1e-4:
                loops.append([shape.verts.new(middle * PX)])
                continue
            loops.append([shape.verts.new((middle + side * (math.cos(a) * spread) + out * (math.sin(a) * depth))
                                          * PX) for a in (2.0 * math.pi * k / segments for k in range(segments))])
        for lower, upper in zip(loops, loops[1:]):
            if len(lower) == 1:
                for k in range(segments):
                    shape.faces.new((lower[0], upper[(k + 1) % segments], upper[k]))
            elif len(upper) == 1:
                for k in range(segments):
                    shape.faces.new((lower[k], lower[(k + 1) % segments], upper[0]))
            else:
                for k in range(segments):
                    shape.faces.new((lower[k], lower[(k + 1) % segments], upper[(k + 1) % segments], upper[k]))
        bmesh.ops.recalc_face_normals(shape, faces=shape.faces[:])
        return self.part(name, shape, material, parent)


def thicken(obj, thickness, lining):
    """Gives an open shell `thickness` inward, its inside and edges `lining`."""
    modifier = obj.modifiers.new("Thick", "SOLIDIFY")
    modifier.thickness = thickness * PX
    modifier.offset = -1.0
    modifier.use_rim = True
    modifier.material_offset = 1
    modifier.material_offset_rim = 1
    obj.data.materials.append(lining)


def _linear(srgb):
    return tuple(((c / 255.0 + 0.055) / 1.055) ** 2.4 for c in srgb)


def _skin(name, srgb):
    def build(nodes, links):
        shader = hall._principled(nodes, links, _linear(srgb), roughness=0.55)
        shader.inputs["Subsurface Weight"].default_value = 0.2
        shader.inputs["Subsurface Radius"].default_value = (1.0, 0.4, 0.25)
        shader.inputs["Subsurface Scale"].default_value = 1.5 * PX
    return hall._material(name, build)


def _cloth(name, low, high, roughness=0.85, scale=1.4):
    """Woven cloth: a fine noise between two sRGB shades; `scale` per model px."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        weave = hall._noise(nodes, links, coords.outputs["Object"], scale=scale / PX, detail=4.0)
        hall._principled(nodes, links, hall._mix(nodes, links, weave, _linear(low), _linear(high)),
                         roughness=roughness)
    return hall._material(name, build)


def _hair(name, low, high):
    """Hair: streaks that run down the locks."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        stretch = nodes.new("ShaderNodeVectorMath")
        stretch.operation = "MULTIPLY"
        stretch.inputs[1].default_value = (1.0, 1.0, 0.25)
        links.new(coords.outputs["Object"], stretch.inputs[0])
        streaks = hall._noise(nodes, links, stretch.outputs["Vector"], scale=0.9 / PX, detail=3.0)
        hall._principled(nodes, links, hall._mix(nodes, links, streaks, _linear(low), _linear(high)), roughness=0.5)
    return hall._material(name, build)


def _plain(name, srgb, roughness, metallic=0.0, glow=0.0):
    color = _linear(srgb)
    return hall._material(name, lambda nodes, links: hall._principled(
        nodes, links, color, roughness=roughness, metallic=metallic,
        emission=color if glow else None, emission_strength=glow))


def _metal(name, low, high, roughness, metallic=0.7):
    """Worn plate: a broad noise between two sRGB shades."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        wear = hall._noise(nodes, links, coords.outputs["Object"], scale=0.35 / PX, detail=5.0)
        hall._principled(nodes, links, hall._mix(nodes, links, wear, _linear(low), _linear(high)),
                         roughness=roughness, metallic=metallic)
    return hall._material(name, build)


def tattered(depth, frequency, seed):
    """A torn hem: how far above the cut each angle (degrees) frays."""
    jitter = np.random.default_rng(seed).uniform(0.0, 1.0, 101)

    def raise_at(degrees):
        tooth = abs(math.sin(math.radians(degrees) * frequency))
        return depth * (0.75 * tooth ** 1.5 + 0.25 * float(jitter[int(round(degrees * 4.0)) % 101]))
    return raise_at


def build_detective(rig):
    """The young detective of the pixel sprite: messy brown hair with a heavy
    fringe, big dark eyes under serious brows, a long brown trench coat worn
    open over a vest, white shirt and gold-buckled belt, light rolled cuffs,
    charcoal trousers and brown shoes. Returns the walk's pivots."""
    skin = _skin("CharSkin", (242, 202, 168))
    coat = _cloth("CharCoat", (104, 72, 50), (124, 88, 62))
    coat_light = _cloth("CharCoatLight", (140, 100, 70), (156, 114, 80))
    lining = _cloth("CharLining", (58, 38, 26), (72, 48, 32))
    vest = _cloth("CharVest", (80, 54, 36), (94, 64, 42))
    cuffs = _cloth("CharCuffs", (150, 138, 124), (170, 158, 142))
    trousers = _cloth("CharTrousers", (40, 42, 48), (52, 54, 62))
    shirt = _cloth("CharShirt", (222, 214, 196), (236, 230, 214), roughness=0.75)
    shoes = _plain("CharShoes", (92, 58, 38), 0.35)
    belt = _plain("CharBelt", (44, 30, 22), 0.5)
    gold = _plain("CharGold", (226, 178, 70), 0.3, metallic=1.0)
    hair_base = _hair("CharHairBase", (66, 44, 30), (82, 56, 38))
    hair = _hair("CharHair", (88, 60, 42), (138, 100, 70))
    sclera = _plain("CharSclera", (236, 232, 226), 0.3)
    iris = _plain("CharIris", (66, 70, 86), 0.2)
    pupil = _plain("CharPupil", (18, 18, 24), 0.2)
    lash = _plain("CharLash", (36, 24, 18), 0.6)
    brow = _plain("CharBrow", (64, 40, 24), 0.7)
    shine = _plain("CharShine", (255, 255, 255), 0.2, glow=3.0)
    mouth = _plain("CharMouth", (150, 78, 66), 0.5)
    blush = _skin("CharBlush", (244, 176, 156))
    body = rig.body

    # Legs swing from the hips and bend at the knees, hidden under the coat.
    legs = []
    for side in (-1.0, 1.0):
        hip = rig.empty("Hip%+d" % side, body, (side * 5.2, 0.0, 25.0))
        rig.tube("Thigh", (0.0, 0.0, 0.0), (0.0, 0.0, -11.0), 5.2, 4.7, trousers, hip)
        knee = rig.empty("Knee%+d" % side, hip, (0.0, 0.0, -11.0))
        rig.ball("KneeJoint", (0.0, 0.0, 0.0), (4.7, 4.7, 4.7), trousers, knee, segments=16)
        rig.tube("Shin", (0.0, 0.0, 0.0), (0.0, 0.0, -10.0), 4.7, 4.1, trousers, knee)
        rig.ball("Shoe", (0.0, -2.2, -10.9), (4.4, 7.0, 3.1), shoes, knee)
        legs.append({"hip": hip, "knee": knee, "side": side, "thigh": 11.0, "shin": 14.0})

    # Under the coat: trousers to the belt, then the vest and shirt.
    hips_profile = [(20.0, 10.6), (24.0, 11.8), (29.0, 12.6), (33.0, 12.9)]
    rig.lathe("Seat", hips_profile, 0.82, trousers, body)
    belt_profile = [(31.4, 13.1), (34.2, 13.1)]
    rig.lathe("Belt", belt_profile, 0.83, belt, body)
    rig.ball("Buckle", (0.0, -11.0, 32.8), (2.4, 0.7, 2.0), gold, body, segments=12)
    vest_profile = [(33.0, 12.8), (40.0, 13.1), (47.0, 13.7), (52.0, 13.2), (55.5, 10.8), (57.5, 6.5)]
    rig.lathe("Vest", vest_profile, 0.8, vest, body)
    rig.patch("Shirt", vest_profile, 0.8, (49.5, 57.4), lambda z: (-(z - 49.0) * 3.4, (z - 49.0) * 3.4), 0.25,
              shirt, body, columns=4)
    for side in (-1.0, 1.0):
        rig.patch("ShirtCollar", vest_profile, 0.8, (54.0, 57.6),
                  lambda z, s=side: sorted((s * 4.0, s * (4.0 + (57.6 - z) * 7.0))), 0.6, shirt, body,
                  rows=3, columns=3)
    for z in (37.0, 41.0, 45.0):
        point, normal = on_front((0.0, 0.0, 0.0), (13.2, 13.2 * 0.8, 1000.0), 0.0, z)
        rig.ball("VestButton", point - normal * 0.2, (0.9, 0.5, 0.9), gold, body, segments=10)

    # The coat: an open shell from the shoulders to below the knees.
    coat_profile = [(17.6, 18.6), (19.0, 18.5), (23.0, 17.6), (28.0, 16.3), (33.0, 15.2), (37.0, 14.8),
                    (42.0, 15.0), (47.0, 15.6), (51.0, 15.4), (54.0, 14.2), (56.5, 11.2), (58.4, 7.4)]
    flat = 0.86

    def opening(z):
        return np.interp(z, (17.6, 23.0, 30.0, 36.0, 44.0, 50.0, 55.0, 58.4),
                         (33.0, 30.0, 22.0, 16.0, 12.0, 14.0, 21.0, 36.0))

    thicken(rig.lathe("Coat", coat_profile, flat, coat, body, gap=opening, segments=48), 0.9, lining)
    # Lapels fold back from the opening across the chest.
    for side in (-1.0, 1.0):
        def lapel(z, s=side):
            width = float(np.interp(z, (44.5, 50.0, 53.0, 56.0, 58.0), (0.5, 20.0, 27.0, 14.0, 6.0)))
            edge = float(opening(z))
            return (edge, edge + width) if s > 0 else (360.0 - edge - width, 360.0 - edge)
        rig.patch("Lapel", coat_profile, flat, (44.5, 58.0), lapel, 0.35, coat_light, body, rows=10, columns=4)
        rig.patch("Pocket", coat_profile, flat, (25.0, 27.6),
                  lambda z, s=side: (38.0, 66.0) if s > 0 else (294.0, 322.0), 0.3, lining, body, rows=2, columns=4)
    rig.patch("BackBelt", coat_profile, flat, (35.6, 38.2), lambda z: (140.0, 220.0), 0.3, lining, body,
              rows=2, columns=10)
    for azimuth in (150.0, 210.0):
        a = math.radians(azimuth)
        r = radius_at(coat_profile, 36.9) + 0.6
        rig.ball("BackButton", (r * math.sin(a), -r * flat * math.cos(a), 36.9), (0.9, 0.9, 0.9), lining, body,
                 segments=10)
    rig.tube("Collar", (0.0, 1.8, 60.4), (0.0, 1.8, 56.2), 9.0, 11.0, coat_light, body, flat=0.85, segments=28)

    # Arms hang from the shoulders, a little out from the coat.
    arms = []
    for side in (-1.0, 1.0):
        rig.ball("ShoulderPad", (side * 14.0, 0.3, 52.6), (6.0, 5.6, 5.2), coat, body)
        shoulder = rig.empty("Shoulder%+d" % side, body, (side * 15.6, 0.3, 52.2))
        rig.tube("Sleeve", (0.0, 0.0, 0.0), (0.0, 0.0, -16.4), 5.3, 4.6, coat, shoulder)
        rig.tube("Cuff", (0.0, 0.0, -14.0), (0.0, 0.0, -17.8), 4.9, 4.9, cuffs, shoulder)
        rig.ball("Hand", (0.0, -0.3, -20.6), (3.6, 3.3, 3.8), skin, shoulder)
        arms.append({"shoulder": shoulder, "side": side})

    # Head and face. Chibi: the head is about a third of the figure.
    head_centre, head_radii = (0.0, 0.0, 72.0), (15.6, 14.6, 15.6)
    rig.tube("Neck", (0.0, 0.5, 60.5), (0.0, 0.5, 54.5), 3.6, 3.7, skin, body)
    rig.ball("Head", head_centre, head_radii, skin, body, segments=40)
    for side in (-1.0, 1.0):
        rig.ball("Ear", (side * 15.1, 0.8, 69.5), (2.0, 2.9, 3.4), skin, body, segments=12)
        point, normal = on_front(head_centre, head_radii, side * 6.1, 69.0)
        rig.ball("Sclera", point - normal * 0.35, (3.3, 1.0, 4.3), sclera, body, segments=16, normal=normal)
        rig.ball("Iris", point + normal * 0.15 + Vector((-side * 0.3, 0.0, -0.3)), (2.6, 0.8, 3.7), iris, body,
                 segments=16, normal=normal)
        rig.ball("Pupil", point + normal * 0.55 + Vector((-side * 0.3, 0.0, -0.4)), (1.3, 0.5, 2.0), pupil,
                 body, segments=12, normal=normal)
        rig.ball("Shine", point + normal * 0.75 + Vector((-0.9, 0.0, 1.4)), (0.95, 0.4, 1.05), shine, body,
                 segments=10, normal=normal)
        lid, lid_normal = on_front(head_centre, head_radii, side * 5.9, 73.1)
        rig.ball("Lash", lid + lid_normal * 0.25, (3.8, 0.7, 0.95), lash, body, segments=14, normal=lid_normal)
        cheek, cheek_normal = on_front(head_centre, head_radii, side * 9.6, 64.0)
        rig.ball("Blush", cheek - cheek_normal * 0.15, (2.8, 0.5, 1.5), blush, body, segments=12,
                 normal=cheek_normal)
        inner, inner_normal = on_front(head_centre, head_radii, side * 2.8, 74.8)
        outer, outer_normal = on_front(head_centre, head_radii, side * 9.2, 76.2)
        rig.tube("Brow", outer + outer_normal * 0.5, inner + inner_normal * 0.5, 0.75, 0.95, brow, body,
                 flat=0.6, segments=10)
    point, normal = on_front(head_centre, head_radii, 0.0, 65.0)
    rig.ball("Nose", point - normal * 0.2, (1.0, 0.75, 0.85), skin, body, segments=10, normal=normal)
    point, normal = on_front(head_centre, head_radii, 0.0, 61.6)
    rig.ball("Mouth", point - normal * 0.05, (1.8, 0.4, 0.5), mouth, body, segments=12, normal=normal)

    # Hair: a dark cap cut above the face, and lighter locks laid over it
    # whose tips lift off for the sprite's messy outline.
    hair_shell = ((0.0, 1.0, 73.2), (17.1, 16.4, 17.0))
    rig.shell("HairCap", hair_shell[0], (16.6, 15.9, 16.5), hair_base, body,
              keep=((0.0, -16.4, 81.2), (0.0, 21.6, 34.9)))
    locks = [
        # Fringe, swept a little to the right, down to the brows; two
        # strands fall lower between the eyes.
        ((-56.0, 16.0), (-62.0, 80.0), 7.0, 1.0, 4.0), ((-40.0, 12.0), (-44.0, 84.0), 7.4, 0.9, 5.0),
        ((-24.0, 10.0), (-24.0, 81.0), 7.6, 1.1, 6.0), ((-9.0, 8.0), (-6.0, 88.0), 6.6, 0.8, 6.0),
        ((6.0, 8.0), (12.0, 83.0), 7.4, 1.0, 5.0), ((21.0, 10.0), (28.0, 86.0), 7.0, 0.9, 5.0),
        ((36.0, 12.0), (44.0, 80.0), 7.2, 1.2, 4.0), ((52.0, 16.0), (60.0, 79.0), 6.8, 1.3, 3.0),
        # Narrow sideburns, and locks flaring out over the tops of the ears,
        # which leave the face and ear clear in profile.
        ((-60.0, 30.0), (-62.0, 103.0), 4.2, 0.6, -3.0), ((60.0, 30.0), (62.0, 103.0), 4.2, 0.6, 3.0),
        ((-80.0, 28.0), (-84.0, 94.0), 6.6, 2.6, -3.0), ((80.0, 28.0), (84.0, 94.0), 6.6, 2.6, 3.0),
        ((-100.0, 30.0), (-106.0, 98.0), 6.8, 3.0, 0.0), ((100.0, 30.0), (106.0, 98.0), 6.8, 3.0, 0.0),
        # Down the back to the nape.
        ((-128.0, 30.0), (-130.0, 126.0), 7.6, 2.0, 0.0), ((128.0, 30.0), (130.0, 126.0), 7.6, 2.0, 0.0),
        ((-148.0, 28.0), (-146.0, 136.0), 7.8, 2.2, 0.0), ((148.0, 28.0), (146.0, 136.0), 7.8, 2.2, 0.0),
        ((-168.0, 26.0), (-170.0, 140.0), 7.8, 2.4, 0.0), ((168.0, 26.0), (170.0, 140.0), 7.8, 2.4, 0.0),
        ((180.0, 24.0), (180.0, 142.0), 8.0, 1.8, 0.0),
        # Messy crown: locks from the whorl whose tips stand up, the ones
        # toward the sides far enough to break the outline.
        ((180.0, 10.0), (-30.0, 48.0), 7.0, 4.5, 8.0), ((180.0, 10.0), (25.0, 46.0), 6.8, 5.0, -6.0),
        ((180.0, 10.0), (-75.0, 60.0), 6.6, 7.0, 0.0), ((180.0, 10.0), (75.0, 62.0), 6.6, 7.5, 0.0),
        ((180.0, 10.0), (130.0, 64.0), 7.0, 5.0, 0.0), ((180.0, 10.0), (-130.0, 62.0), 7.0, 5.0, 0.0),
        ((180.0, 10.0), (2.0, 38.0), 6.2, 5.0, 4.0),
        ((0.0, 20.0), (-60.0, 52.0), 6.4, 5.0, -5.0), ((0.0, 20.0), (60.0, 54.0), 6.4, 5.5, 5.0),
        ((150.0, 16.0), (-100.0, 48.0), 6.2, 6.0, 0.0), ((-150.0, 16.0), (100.0, 48.0), 6.2, 6.0, 0.0),
    ]
    for index, (start, end, width, lift, curl) in enumerate(locks):
        rig.lock("Lock%d" % index, hair_shell, start, end, width, 3.4, lift, hair, body, curl=curl)
    return {"legs": legs, "arms": arms}

def build_guardian(rig):
    """The Castle Guardian of the pixel sprite: a knight in dark steel with
    bronze trim, a great helm whose visor slit glows violet, broad pauldrons,
    a violet core in the breastplate, gauntlets, a tattered brown cloth over
    the hips and a long tattered cloak. Returns the walk's pivots."""
    steel = _metal("GuardSteel", (88, 92, 108), (110, 114, 132), roughness=0.42, metallic=0.5)
    steel_dark = _metal("GuardSteelDark", (58, 60, 72), (72, 74, 88), roughness=0.45, metallic=0.5)
    bronze = _plain("GuardBronze", (180, 124, 74), 0.32, metallic=1.0)
    cloth = _cloth("GuardCloth", (90, 72, 54), (110, 88, 66))
    cloth_dark = _cloth("GuardClothDark", (56, 44, 34), (70, 56, 42))
    leather = _plain("GuardLeather", (70, 48, 34), 0.6)
    slit = _plain("GuardSlit", (10, 8, 14), 0.6)
    glow = _plain("GuardGlow", (150, 64, 255), 0.3, glow=1.3)
    body = rig.body

    # Armoured legs: cuisses, knee cops, greaves and sabatons.
    legs = []
    for side in (-1.0, 1.0):
        hip = rig.empty("Hip%+d" % side, body, (side * 8.0, 0.0, 47.0))
        rig.tube("Cuisse", (0.0, 0.0, 0.0), (0.0, 0.0, -20.0), 8.2, 7.4, steel, hip)
        knee = rig.empty("Knee%+d" % side, hip, (0.0, 0.0, -20.0))
        rig.ball("KneeCop", (0.0, -1.2, 0.0), (7.4, 6.6, 6.2), steel, knee, segments=20)
        rig.ball("KneeTrim", (0.0, -1.0, 0.0), (7.7, 6.3, 1.4), bronze, knee, segments=20)
        rig.tube("Greave", (0.0, 0.0, -1.0), (0.0, 0.0, -20.0), 7.0, 6.0, steel, knee)
        rig.ball("Sabaton", (0.0, -3.6, -23.2), (6.0, 9.6, 3.8), steel_dark, knee)
        legs.append({"hip": hip, "knee": knee, "side": side, "thigh": 20.0, "shin": 27.0})

    # Plated hips under a leather belt, and a breastplate with a bronze V
    # down to the glowing core.
    rig.lathe("Fauld", [(42.0, 15.4), (46.0, 16.4), (50.0, 16.6), (54.0, 16.0)], 0.8, steel, body)
    rig.lathe("FauldTrim", [(45.2, 16.9), (46.6, 16.9)], 0.8, bronze, body)
    rig.lathe("Belt", [(52.0, 16.8), (55.0, 16.6)], 0.8, leather, body)
    rig.ball("BeltBuckle", (0.0, -13.7, 53.5), (3.0, 1.0, 2.2), bronze, body, segments=12)
    chest = [(54.0, 15.6), (60.0, 16.8), (68.0, 18.4), (75.0, 18.8), (80.0, 17.2), (84.0, 13.0), (86.5, 9.0)]
    rig.lathe("Breastplate", chest, 0.78, steel, body, segments=48)
    rig.lathe("ChestTrim", [(55.0, 16.0), (57.0, 16.4)], 0.79, bronze, body)
    for side in (-1.0, 1.0):
        def v_trim(z, s=side):
            middle = float(np.interp(z, (70.0, 83.0), (7.0, 36.0)))
            return (middle - 2.2, middle + 2.2) if s > 0 else (-middle - 2.2, -middle + 2.2)
        rig.patch("ChestV", chest, 0.78, (70.0, 83.0), v_trim, 0.35, bronze, body, rows=8, columns=2)
    rig.ball("CoreRim", (0.0, -14.4, 69.0), (5.2, 1.8, 5.2), bronze, body, segments=24)
    rig.ball("Core", (0.0, -15.6, 69.0), (3.7, 1.4, 3.7), glow, body, segments=20)
    rig.lathe("Gorget", [(84.0, 11.4), (86.0, 11.6), (89.0, 10.4)], 0.9, steel_dark, body)

    # The great helm: a bronze ridge from brow to nape, a dark visor slit
    # under a bronze brow, and two violet eyes in the slit.
    helm = [(87.5, 10.6), (90.0, 11.6), (96.0, 12.0), (104.0, 12.0), (110.0, 11.6), (113.0, 10.4), (114.8, 7.8),
            (115.6, 3.8), (115.9, 0.3)]
    helm_flat = 0.95
    rig.lathe("Helm", helm, helm_flat, steel, body, segments=48)
    rig.lathe("HelmRim", [(87.2, 11.2), (89.0, 12.0)], helm_flat, bronze, body)
    rig.patch("VisorSlit", helm, helm_flat, (97.4, 100.4), lambda z: (-64.0, 64.0), 0.25, slit, body, rows=2,
              columns=16)
    rig.patch("VisorBrow", helm, helm_flat, (100.4, 102.2), lambda z: (-68.0, 68.0), 0.45, bronze, body, rows=2,
              columns=16)
    rig.patch("Ridge", helm, helm_flat, (88.0, 115.8), lambda z: (-5.0, 5.0), 0.55, bronze, body, rows=14,
              columns=2)
    rig.patch("RidgeBack", helm, helm_flat, (88.0, 115.8), lambda z: (175.0, 185.0), 0.55, bronze, body, rows=14,
              columns=2)
    for side in (-1.0, 1.0):
        a = math.radians(side * 17.0)
        r = radius_at(helm, 98.9) + 0.45
        rig.ball("Eye", (r * math.sin(a), -r * helm_flat * math.cos(a), 98.9), (2.6, 0.7, 1.0), glow, body,
                 segments=12, normal=(math.sin(a), -math.cos(a), 0.0))

    # Broad pauldrons in two lames, each edged in bronze.
    for side in (-1.0, 1.0):
        tilt = Vector((side * 0.35, 0.0, 1.0))
        centre = (side * 21.0, 0.5, 82.0)
        rig.shell("Pauldron", centre, (12.0, 11.4, 9.6), steel, body, keep=((side * 21.0, 0.5, 78.0), tilt))
        rig.shell("PauldronTrim", centre, (12.4, 11.8, 10.0), bronze, body,
                  keep=[((side * 21.0, 0.5, 78.0), tilt), ((side * 21.0, 0.5, 79.6), -tilt)])
        lower = (side * 23.0, 0.5, 77.0)
        rig.shell("PauldronLame", lower, (11.0, 10.6, 8.0), steel, body,
                  keep=((side * 23.0, 0.5, 73.2), Vector((side * 0.45, 0.0, 1.0))))
        rig.shell("PauldronLameTrim", lower, (11.4, 11.0, 8.4), bronze, body,
                  keep=[((side * 23.0, 0.5, 73.2), Vector((side * 0.45, 0.0, 1.0))),
                        ((side * 23.0, 0.5, 74.6), Vector((-side * 0.45, 0.0, -1.0)))])

    # Arms in plate, ending in dark gauntlets at the hips.
    arms = []
    for side in (-1.0, 1.0):
        shoulder = rig.empty("Shoulder%+d" % side, body, (side * 22.0, 0.5, 79.0))
        rig.tube("Rerebrace", (0.0, 0.0, 0.0), (0.0, 0.0, -16.0), 6.2, 5.6, steel, shoulder)
        rig.ball("Couter", (0.0, 0.6, -17.5), (5.9, 5.9, 5.4), steel, shoulder, segments=18)
        rig.tube("Vambrace", (0.0, 0.0, -18.5), (0.0, 0.0, -31.0), 5.8, 5.2, steel, shoulder)
        rig.tube("VambraceTrim", (0.0, 0.0, -29.6), (0.0, 0.0, -31.4), 5.6, 5.6, bronze, shoulder)
        rig.ball("Gauntlet", (0.0, -0.6, -35.0), (5.8, 5.4, 6.2), steel_dark, shoulder, segments=18)
        arms.append({"shoulder": shoulder, "side": side})

    # Tattered cloth: a front panel in two halves that swing with the legs,
    # and a long cloak down the back.
    skirt = [(20.0, 17.6), (34.0, 17.2), (46.0, 17.0), (52.0, 16.6)]
    for leg in legs:
        side = leg["side"]
        rig.patch("Tabard", skirt, 0.8, (21.0, 52.0),
                  lambda z, s=side: (0.0, 34.0) if s > 0 else (-34.0, 0.0), 0.6, cloth, leg["hip"], rows=8,
                  columns=8, hem=tattered(9.0, 9.0, 3 if side > 0 else 5), origin=(side * 8.0, 0.0, 47.0))
    cloak = [(6.0, 27.0), (24.0, 25.4), (44.0, 23.2), (64.0, 22.0), (76.0, 21.6), (84.0, 19.0), (87.5, 14.0)]
    thicken(rig.lathe("Cloak", cloak, 0.86, cloth, body, segments=40, centre=(0.0, 4.0),
                      gap=lambda z: float(np.interp(z, (6.0, 60.0, 87.5), (98.0, 106.0, 118.0))),
                      hem=tattered(14.0, 7.0, 11)), 0.8, cloth_dark)
    return {"legs": legs, "arms": arms, "stride": 20.0, "knee": 34.0, "arm_swing": 0.55, "splay": 5.0}


def pose(joints, body, frame):
    """Frame `frame` of the walk; frame 0 stands still. The hip swing and the
    trailing knee's bend lift the swinging foot, and the body drops so the
    lowest foot stays on the floor."""
    phase = 2.0 * math.pi * frame / FRAMES
    stride = math.radians(joints.get("stride", STRIDE_DEGREES))
    knee = math.radians(joints.get("knee", KNEE_DEGREES))
    reach = 0.0
    swings = {}
    for leg in joints["legs"]:
        cycle = phase + (0.0 if leg["side"] < 0 else math.pi)
        swing = stride * math.sin(cycle)
        place = math.remainder(cycle, 2.0 * math.pi)
        bend = knee * max(0.0, -math.sin(2.0 * place)) if -math.pi / 2 < place < 0 else 0.0
        leg["hip"].rotation_euler = (-swing, 0.0, 0.0)
        leg["knee"].rotation_euler = (bend, 0.0, 0.0)
        reach = max(reach, leg["thigh"] * math.cos(swing) + leg["shin"] * math.cos(bend - swing))
        swings[leg["side"]] = swing
    swing_share = joints.get("arm_swing", ARM_SWING)
    splay = math.radians(joints.get("splay", ARM_SPLAY_DEGREES))
    for arm in joints["arms"]:
        arm["shoulder"].rotation_euler = (swing_share * swings[arm["side"]], -arm["side"] * splay, 0.0)
    full = joints["legs"][0]["thigh"] + joints["legs"][0]["shin"]
    body.location = (0.0, 0.0, -(full - reach) * PX)


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


def projected(rig, angle):
    """The rig's extent on screen in Blender units: (left, right, low, high),
    up being screen up from the feet."""
    bpy.context.view_layer.update()
    alpha = math.radians(angle)
    up = Vector((0.0, math.cos(alpha), math.sin(alpha)))
    xs, ups = [], []
    for obj in rig.made:
        matrix = obj.matrix_world
        for vertex in obj.data.vertices:
            point = matrix @ vertex.co
            xs.append(point.x)
            ups.append(point.dot(up))
    return min(xs), max(xs), min(ups), max(ups)


def frame_camera(camera, angle, scale, cell, feet_row):
    """Feet at (centre, feet_row) of the cell, `scale` Blender units a px."""
    alpha = math.radians(angle)
    camera.data.ortho_scale = max(cell) * scale
    up = Vector((0.0, math.cos(alpha), math.sin(alpha)))
    view = Vector((0.0, math.sin(alpha), -math.cos(alpha)))
    camera.location = up * (feet_row - cell[1] / 2.0) * scale - view * 5.0


CHARACTERS = {
    "detective": {"build": build_detective, "height": 100.0, "cell": (128, 128), "feet": 114},
    # Laid out like the pixel Guardian's sheet, boots on the same row and the
    # figure as tall, so the game's own scale and foot anchor still fit it.
    "guardian": {"build": build_guardian, "height": 100.0, "cell": (128, 156), "feet": 134},
}


def main():
    options = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spec = CHARACTERS[options["character"]]
    # --zoom renders the same framing larger, for close looks only.
    zoom = options["zoom"]
    cell, feet_row, angle = (spec["cell"][0] * zoom, spec["cell"][1] * zoom), spec["feet"] * zoom, options["angle"]
    os.makedirs(options["out"], exist_ok=True)
    camera = setup_scene(angle, options["samples"], cell)
    rig = Rig(options["character"].title())
    joints = spec["build"](rig)
    pose(joints, rig.body, 0)
    scale = projected(rig, angle)[3] / (spec["height"] * zoom)
    frame_camera(camera, angle, scale, cell, feet_row)
    # Everything must stay inside the cell whichever way the figure turns.
    for _animation, degrees in DIRECTIONS:
        rig.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
        for frame in range(FRAMES):
            pose(joints, rig.body, frame)
            left, right, low, high = (value / scale for value in projected(rig, angle))
            if (-left > cell[0] / 2 - 2 or right > cell[0] / 2 - 2 or high > feet_row - 2
                    or -low > cell[1] - feet_row - 2):
                print("WARNING %s %d: figure px %.1f..%.1f wide, %.1f..%.1f high leaves the cell" % (
                    _animation, frame, left, right, low, high))
    print("FRAMING %s at %.0f degrees: %.4f units a px, standing %.1f px" % (
        options["character"], angle, scale, spec["height"] * zoom))
    scene = bpy.context.scene
    if options["turnaround"]:
        # One standing pose and one stride per direction, for a quick look.
        frames = (0, 2)
    else:
        frames = tuple(range(FRAMES))
    rows = []
    for _animation, degrees in DIRECTIONS:
        rig.turn.rotation_euler = (0.0, 0.0, math.radians(degrees))
        cells = []
        for frame in frames:
            pose(joints, rig.body, frame)
            path = os.path.join(options["out"], "_cell.png")
            scene.render.filepath = os.path.abspath(path)
            bpy.ops.render.render(write_still=True)
            cells.append(hall._read_rgba(path))
            os.remove(path)
        rows.append(np.concatenate(cells, axis=1))
    name = options["character"]
    if options["turnaround"]:
        image = os.path.join(options["out"], "%s_turnaround_%d%s.png" % (name, int(angle), "_x%d" % zoom if zoom > 1 else ""))
        hall._write_png(image, np.ascontiguousarray(np.concatenate(rows, axis=1)))
        print("TURNAROUND", image)
        return
    sheet = np.ascontiguousarray(np.concatenate(rows, axis=0))
    image = os.path.join(options["out"], "%s_walk_8dir.png" % name)
    hall._write_png(image, sheet)
    meta = {"generator": "tools/blender/character_prototype.py", "image": os.path.basename(image),
            "cell": list(cell), "feet": [cell[0] / 2.0, feet_row], "frames": FRAMES, "angle": angle,
            "height": spec["height"], "rows": {animation: row for row, (animation, _d) in enumerate(DIRECTIONS)}}
    with open(os.path.join(options["out"], "%s.json" % name), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)
    print("SHEET %s: %d x %d cells of %dx%d" % (image, FRAMES, len(DIRECTIONS), cell[0], cell[1]))


if __name__ == "__main__":
    main()
