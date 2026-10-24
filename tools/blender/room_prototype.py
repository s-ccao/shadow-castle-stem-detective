"""Interior rooms for the Blender prototype, rendered to replace a room's art.

Each room is rebuilt in 3D on its own collision, so movement and every
interaction stay exactly as the game has them, and rendered as one HD image
for the playable preview (tools/blender/play_prototype.gd). The rooms share
the Hall's projection, materials and lighting language
(tools/blender/hall_prototype.py, imported here as a library):

  Projection. An orthographic camera tilted ALPHA_DEGREES from straight down
  and a 1/cos(ALPHA) plan stretch, so the floor lands 1:1 on game px and a
  height h shows h screen px up. Positions are given in game px as
  (x, y, h): x across, y the plan's y (south positive), h screen px up.

  Forced perspective. A single-screen room reads as a room only if its side
  walls show their faces, as the painted rooms draw them; an orthographic
  camera sees a vertical side wall edge-on. So the walls flare: the back wall
  is vertical with a top wider than its base, and each side wall leans out
  along a lean vector until its top meets the back wall's top corner. Seen
  from the camera this is the painted room's box, built as a stage set.

  Depth. Walls and fixed furniture hide whatever stands behind them. A second
  pass renders every surface's own plan y (a horizontal surface its own y, a
  vertical one the y of its base) into <render>-depth.png at one px per game
  px, the format the Hall's depth shader reads (R high byte, G low byte of
  the plan y; A where a surface is seen). The floor, rugs and the room's
  interactive props stay out of it: the game y-sorts those props itself.

  Interactive props. The props a room's scene lists under Props/ (the bed,
  the desk, ...) are rendered alone, cropped to the px they show and listed
  in <render>-props.json, so the preview can draw each in its node's Visual
  sprite: the game's focus box, prompt range and y-sort then follow the HD
  prop. They stay out of the room render but cast their shadows into it.

A room's furniture, lights and dressing live in tools/blender/room_<name>.py.

    Blender -b --factory-startup -P tools/blender/room_prototype.py -- \\
        --room wake_room --out prototypes/blender_rooms/wake_room/render.png \\
        [--samples 128] [--preview] [--props-only] [--save-blend file.blend]
"""
import importlib
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, geometry

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hall_prototype as hall  # noqa: E402

PX = hall.PX
SIN = hall.SIN_ALPHA
STRETCH = 1.0 / math.cos(math.radians(hall.ALPHA_DEGREES))
RENDER_SCALE = 2.0
PROP_MARGIN_PX = 6
# A room's figure is shown 2x the Hall's base size, so its stone, wood and
# cloth are drawn at about 1.8x the Hall's texel size.
ROOM_TEXTURE_SCALE = 1.8
GLOWS = []
TEXTURES = None


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"room": "wake_room", "out": None, "samples": 128, "preview": False, "props_only": False,
               "save_blend": None, "textures": os.path.join("prototypes", "blender_hall", "textures")}
    index = 0
    while index < len(argv):
        key = argv[index]
        if key in ("--preview", "--props-only"):
            options[key[2:].replace("-", "_")] = True
            index += 1
            continue
        value = argv[index + 1]
        if key == "--samples":
            options["samples"] = int(value)
        elif key in ("--room", "--out", "--textures"):
            options[key[2:]] = value
        elif key == "--save-blend":
            options["save_blend"] = value
        else:
            raise SystemExit("Unknown option: " + key)
        index += 2
    if options["out"] is None:
        options["out"] = os.path.join("prototypes", "blender_rooms", options["room"], "render.png")
    return options


def world(x, y, h):
    """Game px (x across, y plan south, h screen px up) to Blender units."""
    return Vector((x * PX, -y * PX * STRETCH, h / SIN * PX))


def game(point):
    """A Blender-space point back to game px (x, y, h)."""
    return Vector((point.x / PX, -point.y / (PX * STRETCH), point.z / PX * SIN))


def to_screen(point):
    """A Blender-space point to screen game px."""
    x = point.x / PX
    y = -point.y / (PX * STRETCH)
    h = point.z / PX * SIN
    return x, y - h


def glow(kind, x, y, h, color, radius):
    """A living light for the preview's halos, at screen px (x, y - h)."""
    GLOWS.append({"kind": kind, "x": round(float(x), 2), "y": round(float(y - h), 2),
                  "color": [round(float(channel), 3) for channel in color], "radius": float(radius)})


# ---------------------------------------------------------------- meshes


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# Toward the camera: what a visible face's normal points along.
TOWARD_CAMERA = Vector((0.0, -math.sin(math.radians(hall.ALPHA_DEGREES)), math.cos(math.radians(hall.ALPHA_DEGREES))))


def mesh_from(name, shape, materials, smooth=False, sharp_angle=40.0, uv=None, facing=None):
    """A mesh object from a bmesh built in game px, converted to Blender space.
    `uv` projects UVs: "floor" (x, y), "front" (x, h) or "side" (y, h), in
    game px over 100 * ROOM_TEXTURE_SCALE. Closed shapes get outward normals;
    an open sheet given `facing` turns its faces to look along it."""
    if uv:
        layer = shape.loops.layers.uv.verify()
        size = 100.0 * ROOM_TEXTURE_SCALE
        shape.normal_update()
        for face in shape.faces:
            plane = uv
            if uv in ("box", "box_up"):
                # Each face takes the projection it faces most: a box of
                # boards keeps its grain on every side.
                nx, ny, nh = (abs(component) for component in face.normal)
                plane = "floor" if nh >= max(nx, ny) else ("front" if ny >= nx else "side")
            for loop in face.loops:
                x, y, h = loop.vert.co
                if plane == "floor":
                    u, v = x, -y
                elif plane == "front":
                    u, v = x, h
                else:
                    u, v = y, h
                if uv == "box_up" and plane != "floor":
                    u, v = v, u
                loop[layer].uv = (u / size, v / size)
    for vert in shape.verts:
        vert.co = world(*vert.co)
    # The plan stretch flips y, so windings built in game px turn inside out.
    bmesh.ops.recalc_face_normals(shape, faces=shape.faces[:])
    if facing is not None:
        shape.normal_update()
        backwards = [face for face in shape.faces if face.normal.dot(facing) < 0.0]
        if backwards:
            bmesh.ops.reverse_faces(shape, faces=backwards)
    mesh = bpy.data.meshes.new(name)
    shape.to_mesh(mesh)
    shape.free()
    for material in materials if isinstance(materials, (list, tuple)) else [materials]:
        mesh.materials.append(material)
    if smooth:
        mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(sharp_angle))
    return _link(bpy.data.objects.new(name, mesh))


def polygon_mesh(name, outline, holes, to_point, material, uv_of=None):
    """A flat face over `outline` minus `holes`, given in a plane's own 2D
    coordinates; `to_point(u, v)` places a 2D point in game px (x, y, h)."""
    loops = [[Vector((u, v, 0.0)) for u, v in outline]] + [[Vector((u, v, 0.0)) for u, v in hole]
                                                           for hole in holes]
    flat = [point for loop in loops for point in loop]
    triangles = geometry.tessellate_polygon(loops)
    shape = bmesh.new()
    verts = [shape.verts.new(to_point(point.x, point.y)) for point in flat]
    layer = shape.loops.layers.uv.verify()
    for triangle in triangles:
        try:
            face = shape.faces.new([verts[index] for index in triangle])
        except ValueError:
            continue
        for loop, index in zip(face.loops, triangle):
            point = flat[index]
            loop[layer].uv = uv_of(point.x, point.y) if uv_of else (point.x / 180.0, point.y / 180.0)
    return mesh_from(name, shape, material, facing=TOWARD_CAMERA)


def project_uvs(obj, mode="box", scale=1.0):
    """Box-projected UVs for a mesh built elsewhere (a Hall PropKit part),
    from where its faces stand in game px now, so a photo texture keeps its
    size on it; `scale` is how much a later map enlarges it. "box_up" turns
    the grain upright on its sides."""
    mesh = obj.data
    points = [game(obj.matrix_world @ vertex.co) for vertex in mesh.vertices]
    layer = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    size = 100.0 * ROOM_TEXTURE_SCALE / scale
    for polygon in mesh.polygons:
        corners = [points[index] for index in polygon.vertices]
        normal = Vector((0.0, 0.0, 0.0))
        for index, corner in enumerate(corners):
            following = corners[(index + 1) % len(corners)]
            normal += Vector(((corner.y - following.y) * (corner.z + following.z),
                              (corner.z - following.z) * (corner.x + following.x),
                              (corner.x - following.x) * (corner.y + following.y)))
        nx, ny, nh = (abs(component) for component in normal)
        plane = "floor" if nh >= max(nx, ny) else ("front" if ny >= nx else "side")
        for loop_index in polygon.loop_indices:
            x, y, h = points[mesh.loops[loop_index].vertex_index]
            u, v = (x, -y) if plane == "floor" else ((x, h) if plane == "front" else (y, h))
            if mode == "box_up" and plane != "floor":
                u, v = v, u
            layer.data[loop_index].uv = (u / size, v / size)


class Frame:
    """An affine frame on a wall: u along it, v up it, w out of it into the
    room, each a unit vector in game px. to_g(u, v, w) gives (x, y, h)."""

    def __init__(self, origin, along, up, out):
        self.origin = Vector(origin)
        self.along = Vector(along).normalized()
        self.up = Vector(up).normalized()
        self.out = Vector(out).normalized()

    def to_g(self, u, v, w=0.0):
        return self.origin + self.along * u + self.up * v + self.out * w

    def matrix(self, scale=1.0):
        """The game-px affine map from a virtual south face (x across, h up,
        y toward the camera) onto this frame, as a 4x4 in game px."""
        columns = (self.along * scale, self.out * scale, self.up * scale)
        return Matrix((
            (columns[0].x, columns[1].x, columns[2].x, self.origin.x),
            (columns[0].y, columns[1].y, columns[2].y, self.origin.y),
            (columns[0].z, columns[1].z, columns[2].z, self.origin.z),
            (0.0, 0.0, 0.0, 1.0),
        ))


G_TO_WORLD = Matrix.Diagonal((PX, -PX * STRETCH, PX / SIN, 1.0))


def place_on_frame(objects, frame, virtual_centre, virtual_feet, scale=1.0, name="Placed"):
    """Moves objects built with the Hall's PropKit on a virtual south face
    (centred at x virtual_centre, its face on plan y virtual_feet) onto
    `frame`, scaled by `scale`: one affine map, so their parts keep their
    shapes, hinges and texture space. A wall that leans shears the map, and
    Blender keeps a shear only between a scaled parent and a turned child, so
    the map is split (SVD) into two empties every top-level object hangs from.
    Returns the map in game px, for the glows."""
    in_game = frame.matrix(scale) @ Matrix.Translation((-virtual_centre, -virtual_feet, 0.0))
    mapped = G_TO_WORLD @ in_game @ G_TO_WORLD.inverted()
    turn_out, sigma, turn_in = np.linalg.svd(np.array(mapped.to_3x3()))
    if np.linalg.det(turn_out) < 0.0:
        turn_out[:, 2] *= -1.0
        turn_in[2, :] *= -1.0
    outer = _link(bpy.data.objects.new(name + "Map", None))
    outer.matrix_world = (Matrix.Translation(mapped.translation) @ Matrix(turn_out.tolist()).to_4x4()
                          @ Matrix.Diagonal((float(sigma[0]), float(sigma[1]), float(sigma[2]), 1.0)))
    inner = _link(bpy.data.objects.new(name + "MapTurn", None))
    inner.parent = outer
    inner.matrix_parent_inverse = Matrix.Identity(4)
    inner.matrix_basis = Matrix(turn_in.tolist()).to_4x4()
    for obj in objects:
        if obj.parent is None:
            basis = obj.matrix_basis.copy()
            obj.parent = inner
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = basis
    bpy.context.view_layer.update()
    return in_game


def map_glows(recorded, in_game, scale):
    """Glows the Hall's builders recorded on a virtual face, moved by a
    place_on_frame() map: (kind, x, plan y, world height px, colour, radius)."""
    for kind, x, plan_y, z, color, radius in recorded:
        point = in_game @ Vector((x, plan_y, z * SIN))
        glow(kind, point.x, point.y, point.z, color, radius * scale)


# ---------------------------------------------------------------- kits


class Kit:
    """Builds a piece of furniture in game px. Every object it makes is
    tagged: `prop` names the interactive prop it belongs to (rendered alone
    for the preview), `depth` False keeps it out of the depth map."""

    def __init__(self, name, prop=None, depth=True):
        self.name = name
        self.prop = prop
        self.depth = depth
        self.made = []
        self.lights = []

    def keep(self, obj):
        if self.prop:
            obj["room_prop"] = self.prop
        if not self.depth:
            obj["no_depth"] = True
        self.made.append(obj)
        return obj

    def shape(self, part, shape, material, smooth=False, bevel=0.0, uv=None, sharp_angle=40.0):
        obj = self.keep(mesh_from(self.name + part, shape, material, smooth=smooth or bevel > 0.0,
                                  sharp_angle=sharp_angle, uv=uv))
        if bevel > 0.0:
            modifier = obj.modifiers.new("Bevel", "BEVEL")
            modifier.width = bevel * PX
            modifier.segments = 2
            modifier.limit_method = "ANGLE"
            modifier.harden_normals = False
        return obj

    def box(self, part, x0, x1, y0, y1, h0, h1, material, bevel=0.8, uv=None):
        """An axis-aligned block: x0..x1 across, y0..y1 plan, h0..h1 screen px."""
        shape = bmesh.new()
        bmesh.ops.create_cube(shape, size=1.0, matrix=Matrix.Translation(
            ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h0 + h1) / 2.0)) @ Matrix.Diagonal(
            (max(x1 - x0, 0.05), max(y1 - y0, 0.05), max(h1 - h0, 0.05), 1.0)))
        return self.shape(part, shape, material, bevel=bevel, uv=uv)

    def cylinder(self, part, x, y, h0, h1, radius, material, plan=None, tip=None, segments=24, bevel=0.0):
        """Upright, centred (x, y); `plan` its north-south radius (0.55 of the
        radius by default, so its top reads as a 3/4 view), `tip` its top radius."""
        plan = radius * 0.55 if plan is None else plan
        shape = bmesh.new()
        bmesh.ops.create_cone(shape, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                              radius2=radius if tip is None else tip, depth=max(h1 - h0, 0.05),
                              matrix=Matrix.Translation((x, y, (h0 + h1) / 2.0)) @ Matrix.Diagonal(
                                  (1.0, plan / radius, 1.0, 1.0)))
        obj = self.shape(part, shape, material, smooth=True, bevel=bevel, sharp_angle=50.0)
        return obj

    def ball(self, part, x, y, h, radius, material, plan=0.6, squash=1.0, segments=16):
        """A sphere that reads round on screen: `plan` of its radius deep."""
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=segments, v_segments=max(segments // 2, 6), radius=1.0,
                                  matrix=Matrix.Translation((x, y, h)) @ Matrix.Diagonal(
                                      (radius, radius * plan, radius * squash, 1.0)))
        return self.shape(part, shape, material, smooth=True, sharp_angle=80.0)

    def rod(self, part, start, end, radius, material, segments=16, caps=True):
        """A round bar from `start` to `end` (game px), round in Blender space:
        a scroll's roller, a rail, a quill."""
        a, b = world(*start), world(*end)
        axis = b - a
        direction = axis.normalized()
        helper = Vector((0.0, 0.0, 1.0)) if abs(direction.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        first = direction.cross(helper).normalized()
        second = direction.cross(first).normalized()
        shape = bmesh.new()
        rings = []
        for end_point in (a, b):
            rings.append([shape.verts.new(game(end_point + (first * math.cos(2.0 * math.pi * index / segments)
                                                            + second * math.sin(2.0 * math.pi * index / segments))
                                               * radius * PX)) for index in range(segments)])
        for index in range(segments):
            following = (index + 1) % segments
            shape.faces.new((rings[0][index], rings[0][following], rings[1][following], rings[1][index]))
        if caps:
            shape.faces.new(list(reversed(rings[0])))
            shape.faces.new(rings[1])
        return self.shape(part, shape, material, smooth=True, sharp_angle=60.0)

    def lathe(self, part, x, y, profile, material, plan=0.55, segments=28, smooth=True, close=True, uv=None):
        """Turned around an upright axis at (x, y): `profile` lists (radius,
        h) from the bottom up; `plan` squashes it north-south, so its rims
        read as a 3/4 view like every round thing in the Hall."""
        shape = bmesh.new()
        rings = []
        for radius, h in profile:
            if radius <= 1e-4:
                rings.append([shape.verts.new((x, y, h))])
                continue
            rings.append([shape.verts.new((x + radius * math.cos(2.0 * math.pi * index / segments),
                                           y + radius * plan * math.sin(2.0 * math.pi * index / segments), h))
                          for index in range(segments)])
        for lower, upper in zip(rings[:-1], rings[1:]):
            if len(lower) == 1 and len(upper) == 1:
                continue
            for index in range(segments):
                following = (index + 1) % segments
                if len(lower) == 1:
                    shape.faces.new((lower[0], upper[index], upper[following]))
                elif len(upper) == 1:
                    shape.faces.new((lower[index], lower[following], upper[0]))
                else:
                    shape.faces.new((lower[index], lower[following], upper[following], upper[index]))
        if close:
            if len(rings[0]) > 1:
                shape.faces.new(list(reversed(rings[0])))
            if len(rings[-1]) > 1:
                shape.faces.new(rings[-1])
        return self.shape(part, shape, material, smooth=smooth, sharp_angle=50.0, uv=uv)

    def ring(self, part, centre, axis, radius, tube, material, segments=40, sides=10, tilt=None):
        """A torus round in Blender space about `axis` (a Blender-space
        direction) through `centre` (game px): a bezel, a hoop, an armillary
        ring. Sizes in x px."""
        middle = world(*centre)
        axis = Vector(axis).normalized()
        helper = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        first = axis.cross(helper).normalized() if tilt is None else Vector(tilt).normalized()
        second = axis.cross(first).normalized()
        shape = bmesh.new()
        rings = []
        for index in range(segments):
            turn = 2.0 * math.pi * index / segments
            spoke = first * math.cos(turn) + second * math.sin(turn)
            rings.append([shape.verts.new(game(middle + (spoke * (radius + tube * math.cos(2.0 * math.pi * side / sides))
                                                         + axis * tube * math.sin(2.0 * math.pi * side / sides)) * PX))
                          for side in range(sides)])
        for index in range(segments):
            here, there = rings[index], rings[(index + 1) % segments]
            for side in range(sides):
                following = (side + 1) % sides
                shape.faces.new((here[side], there[side], there[following], here[following]))
        return self.shape(part, shape, material, smooth=True, sharp_angle=80.0)

    def slab(self, part, outline, y0, y1, material, plane="front", bevel=0.0):
        """A plate through `outline`: in (x, h) facing the camera from plan y0
        to y1 (plane "front"), or in (x, y) lying from height y0 to y1
        ("floor")."""
        shape = bmesh.new()
        if plane == "front":
            bottom = [shape.verts.new((u, y1, v)) for u, v in outline]
            top = [shape.verts.new((u, y0, v)) for u, v in outline]
        else:
            bottom = [shape.verts.new((u, v, y0)) for u, v in outline]
            top = [shape.verts.new((u, v, y1)) for u, v in outline]
        shape.faces.new(top)
        shape.faces.new(list(reversed(bottom)))
        count = len(outline)
        for index in range(count):
            following = (index + 1) % count
            shape.faces.new((bottom[index], bottom[following], top[following], top[index]))
        return self.shape(part, shape, material, bevel=bevel)

    def sheet(self, part, x0, x1, y0, y1, height, material, columns=48, rows=48, smooth=True):
        """Cloth or any surface given as a height field: h = height(x, y) over
        x0..x1, y0..y1, UVs as the floor's."""
        shape = bmesh.new()
        verts = [[shape.verts.new((x0 + (x1 - x0) * i / columns, y0 + (y1 - y0) * j / rows,
                                   height(x0 + (x1 - x0) * i / columns, y0 + (y1 - y0) * j / rows)))
                  for i in range(columns + 1)] for j in range(rows + 1)]
        for j in range(rows):
            for i in range(columns):
                shape.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
        obj = self.keep(mesh_from(self.name + part, shape, material, smooth=smooth, sharp_angle=89.0, uv="floor",
                                  facing=TOWARD_CAMERA))
        return obj

    def quad(self, part, corners, material, uvs=((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))):
        """One face through four (x, y, h) corners, UVs 0..1 across it."""
        shape = bmesh.new()
        layer = shape.loops.layers.uv.verify()
        face = shape.faces.new([shape.verts.new(corner) for corner in corners])
        for loop, uv in zip(face.loops, uvs):
            loop[layer].uv = uv
        return self.keep(mesh_from(self.name + part, shape, material, facing=TOWARD_CAMERA))

    def light(self, part, x, y, h, color, power, radius=0.04, kind="POINT", mirrored=True):
        data = bpy.data.lights.new(self.name + part, kind)
        data.energy = power
        data.color = color
        data.shadow_soft_size = radius
        light = _link(bpy.data.objects.new(self.name + part, data))
        light.location = world(x, y, h)
        light.visible_glossy = mirrored
        self.lights.append(light)
        return light

    def flame(self, part, x, y, h, size=1.0, power=0.12, color=(1.0, 0.62, 0.28)):
        """A candle flame: a glowing teardrop, its light and its halo."""
        self.ball(part + "Flame", x, y, h + 2.2 * size, 1.1 * size, flame_material(), plan=0.6, squash=2.0,
                  segments=10)
        self.ball(part + "Core", x, y + 0.2, h + 1.6 * size, 0.55 * size, flame_material(core=True), plan=0.6,
                  squash=1.6, segments=8)
        self.light(part + "Light", x, y + 1.5, h + 4.0 * size, color, power, radius=0.012 * size)
        glow("candle", x, y, h + 2.5 * size, color, 16.0 * size)

    def candle(self, part, x, y, h, height=12.0, radius=2.2, power=0.12):
        wax = material_wax()
        self.cylinder(part + "Wax", x, y, h, h + height, radius, wax, segments=16)
        self.cylinder(part + "Drip", x, y, h + height - 1.0, h + height + 0.6, radius * 0.85, wax, tip=radius * 0.6,
                      segments=16)
        self.cylinder(part + "Wick", x, y, h + height + 0.4, h + height + 1.6, 0.25, hall._bakelite(), segments=6)
        self.flame(part, x, y, h + height + 1.0, size=radius / 2.2, power=power)

    def bounds(self):
        """The screen px rect the kit's meshes cover: left, top, right, bottom."""
        bpy.context.view_layer.update()
        xs, ys = [], []
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj in self.made:
            if obj.type != "MESH":
                continue
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            matrix = evaluated.matrix_world
            for vertex in mesh.vertices:
                sx, sy = to_screen(matrix @ vertex.co)
                xs.append(sx)
                ys.append(sy)
            evaluated.to_mesh_clear()
        return min(xs), min(ys), max(xs), max(ys)


# ---------------------------------------------------------------- materials


def _material(name, build):
    return hall._material(name, build)


def flame_material(core=False):
    color = (1.0, 0.86, 0.55) if core else (1.0, 0.55, 0.18)
    return hall._glow_material("RoomFlameCore" if core else "RoomFlame", color, 14.0 if core else 7.0, color)


def material_wax():
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.78, 0.7, 0.55), roughness=0.45)
        shader.inputs["Subsurface Weight"].default_value = 0.6
        shader.inputs["Subsurface Radius"].default_value = (1.0, 0.6, 0.35)
        shader.inputs["Subsurface Scale"].default_value = 0.02
    return _material("RoomWax", build)


def textured(name, asset, repeat, value, tint, saturation=0.75, roughness_scale=1.0, ao=0.3, bevel=0.0):
    """A CC0 photo texture graded into the castle's palette, or a procedural
    stand-in when the textures are missing."""
    def build(nodes, links):
        if TEXTURES is None or not os.path.exists(TEXTURES._path(asset, "diff")):
            coords = nodes.new("ShaderNodeTexCoord")
            grain = hall._noise(nodes, links, coords.outputs["UV"], scale=12.0, detail=6.0)
            low = tuple(channel * value * 0.4 for channel in tint)
            high = tuple(channel * value * 0.8 for channel in tint)
            hall._principled(nodes, links, hall._mix(nodes, links, grain, low, high), roughness=0.8)
            return
        maps = TEXTURES.sample(nodes, links, asset, repeat=repeat)
        color = hall._grade(nodes, links, maps["diff"], value, tint, saturation=saturation)
        if ao > 0.0:
            color = hall._ao_multiply(nodes, links, color, distance=ao, floor_value=0.42)
        normal = maps["normal"] if bevel <= 0.0 else hall._bevelled(nodes, links, maps["normal"], bevel)
        rough = maps["rough"]
        if roughness_scale != 1.0:
            scaled = nodes.new("ShaderNodeMath")
            scaled.operation = "MULTIPLY"
            scaled.use_clamp = True
            links.new(rough, scaled.inputs[0])
            scaled.inputs[1].default_value = roughness_scale
            rough = scaled.outputs[0]
        hall._principled(nodes, links, color, roughness=rough, normal=normal)
    return _material(name, build)


# ---------------------------------------------------------------- the shell


class Shell:
    """The room's walls and floor, from a room spec:

    "back": {"y", "base": (x0, x1), "top": (x0, x1), "height", "openings": [...]}
        The back wall: vertical on plan y, its base x0..x1 on the floor and its
        top x0..x1 at `height` screen px. Openings are outlines in (x, h).
    "left" / "right": {"base": ((x, y), (x, y)), "near": y}
        A side wall's base along the floor, north end first. It leans out to
        meet the back wall's top corner, and runs on south to plan y `near`
        at the top, so its near end reaches the bottom of the screen.
    "south": {"y", "height", "x": (x0, x1)}
        The low wall cut away toward the camera.
    "cap": thickness of the walls' tops in plan px.
    """

    def __init__(self, spec, materials):
        self.spec = spec
        self.materials = materials
        self.made = []
        back = spec["back"]
        self.back_y = back["y"]
        self.height = back["height"]
        self.frames = {}
        for side, top_x in (("left", back["top"][0]), ("right", back["top"][1])):
            (bx0, by0), (bx1, by1) = spec[side]["base"]
            lean = Vector((top_x - bx0, 0.0, self.height))
            along = Vector((bx1 - bx0, by1 - by0, 0.0))
            # Out of the wall is level and into the room: east for the left wall.
            out = Vector((along.y, -along.x, 0.0))
            if (out.x < 0.0) == (side == "left"):
                out = -out
            self.frames[side] = Frame((bx0, by0, 0.0), along, lean, out)
            self.frames[side].lean = lean
        self.frames["back"] = Frame((0.0, self.back_y, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0))

    def mount(self, side, at):
        """A frame for hanging things on a wall, as the Hall hangs them on a
        south face: u to the right of someone facing the wall, v up it, w
        level and out into the room. Its origin is on the wall's foot, at x
        `at` on the back wall or plan y `at` on a side wall. A side wall's
        frame is never mirrored, so a door keeps its handedness on it."""
        if side == "back":
            return Frame((at, self.back_y, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0))
        frame = self.frames[side]
        foot = Vector((self.side_x(side, at), at, 0.0))
        right = frame.along if side == "right" else -frame.along
        return Frame(foot, right, frame.up, frame.out)

    def side_x(self, side, y, h=0.0):
        """The side wall's x at plan y (on its base line) and screen height h."""
        frame = self.frames[side]
        base = frame.origin + frame.along * ((y - frame.origin.y) / frame.along.y)
        return base.x + frame.lean.x * (h / self.height)

    def build(self):
        self._floor()
        self._back_wall()
        for side in ("left", "right"):
            self._side_wall(side)
        self._caps()
        self._south_wall()
        return self.made

    def _keep(self, obj, depth=True):
        if not depth:
            obj["no_depth"] = True
        obj["room_shell"] = True
        self.made.append(obj)
        return obj

    def _floor(self):
        spec = self.spec
        x0, x1 = spec["floor"]["x"]
        y0, y1 = spec["floor"]["y"]
        shape = bmesh.new()
        columns, rows = 24, 16
        verts = [[shape.verts.new((x0 + (x1 - x0) * i / columns, y0 + (y1 - y0) * j / rows, 0.0))
                  for i in range(columns + 1)] for j in range(rows + 1)]
        for j in range(rows):
            for i in range(columns):
                shape.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
        obj = mesh_from("RoomFloor", shape, self.materials["floor"], uv="floor", facing=TOWARD_CAMERA)
        self._keep(obj, depth=False)

    def _back_wall(self):
        back = self.spec["back"]
        (base0, base1), (top0, top1) = back["base"], back["top"]
        height = self.height
        outline = [(base0, 0.0), (base1, 0.0), (top1, height), (top0, height)]
        holes = [list(opening["outline"]) for opening in back.get("openings", [])]
        y = self.back_y
        obj = polygon_mesh("RoomBackWall", outline, holes, lambda u, v: (u, y, v), self.materials["wall"],
                           uv_of=lambda u, v: (u / (100.0 * ROOM_TEXTURE_SCALE), v / SIN / (100.0 * ROOM_TEXTURE_SCALE)))
        self._keep(obj)
        depth = self.spec.get("cap", 40.0)
        for index, opening in enumerate(back.get("openings", [])):
            # The opening's reveal: its sides run back through the wall.
            outline_points = opening["outline"]
            shape = bmesh.new()
            front = [shape.verts.new((u, y, v)) for u, v in outline_points]
            rear = [shape.verts.new((u, y - depth, v)) for u, v in outline_points]
            count = len(outline_points)
            for point in range(count):
                following = (point + 1) % count
                shape.faces.new((front[point], front[following], rear[following], rear[point]))
            self._keep(mesh_from("RoomReveal%d" % index, shape, self.materials["reveal"], uv="side"))

    def _side_wall(self, side):
        frame = self.frames[side]
        near = self.spec[side]["near"]
        lean = frame.lean
        (bx0, by0), _ = self.spec[side]["base"]
        steps_along, steps_up = 24, 10
        span = (near - by0) / frame.along.y
        shape = bmesh.new()
        layer = shape.loops.layers.uv.verify()
        size = 100.0 * ROOM_TEXTURE_SCALE
        lean_length = lean.length
        verts, uvs = [], {}
        for j in range(steps_up + 1):
            row = []
            for i in range(steps_along + 1):
                point = frame.origin + frame.along * (span * i / steps_along) + lean * (j / steps_up)
                vert = shape.verts.new(point)
                uvs[vert] = (span * i / steps_along / size, lean_length * j / steps_up / size)
                row.append(vert)
            verts.append(row)
        for j in range(steps_up):
            for i in range(steps_along):
                face = shape.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
                for loop in face.loops:
                    loop[layer].uv = uvs[loop.vert]
        self._keep(mesh_from("RoomWall" + side.title(), shape, self.materials["wall"], facing=TOWARD_CAMERA))

    def _caps(self):
        depth = self.spec.get("cap", 40.0)
        height = self.height
        back = self.spec["back"]
        top0, top1 = back["top"]
        y = self.back_y
        material = self.materials["cap"]
        left_near, right_near = self.spec["left"]["near"], self.spec["right"]["near"]
        left_top = self.frames["left"].origin + self.frames["left"].lean
        right_top = self.frames["right"].origin + self.frames["right"].lean
        left_end = left_top + self.frames["left"].along * ((left_near - left_top.y) / self.frames["left"].along.y)
        right_end = right_top + self.frames["right"].along * ((right_near - right_top.y) / self.frames["right"].along.y)
        outline = [
            (left_end.x - depth, left_end.y), (left_top.x - depth, y - depth), (right_top.x + depth, y - depth),
            (right_end.x + depth, right_end.y), (right_end.x, right_end.y), (right_top.x, y), (left_top.x, y),
            (left_end.x, left_end.y),
        ]
        obj = polygon_mesh("RoomWallTops", outline, [], lambda u, v: (u, v, height), material,
                           uv_of=lambda u, v: (u / (100.0 * ROOM_TEXTURE_SCALE), -v / (100.0 * ROOM_TEXTURE_SCALE)))
        self._keep(obj)
        # A lit lip along the inner top edges, so the room keeps its outline.
        lip = self.materials["lip"]
        for name, start, end in (("Back", (left_top.x, y), (right_top.x, y)),
                                 ("Left", (left_top.x, y), (left_end.x, left_end.y)),
                                 ("Right", (right_top.x, y), (right_end.x, right_end.y))):
            shape = bmesh.new()
            direction = Vector((end[0] - start[0], end[1] - start[1], 0.0)).normalized()
            outward = Vector((-direction.y, direction.x, 0.0)) if name != "Right" else Vector(
                (direction.y, -direction.x, 0.0))
            if name == "Back":
                outward = Vector((0.0, -1.0, 0.0))
            corners = [Vector((start[0], start[1], height)), Vector((end[0], end[1], height)),
                       Vector((end[0], end[1], height)) + outward * 3.0,
                       Vector((start[0], start[1], height)) + outward * 3.0]
            verts = [shape.verts.new(corner + Vector((0.0, 0.0, 0.6))) for corner in corners]
            shape.faces.new(verts)
            self._keep(mesh_from("RoomLip" + name, shape, lip, facing=TOWARD_CAMERA))

    def _south_wall(self):
        """The low south wall, its ends cut along the leaning side walls."""
        south = self.spec["south"]
        y0, y1 = south["y"], south["y"] + south.get("depth", 70.0)
        kit = Kit("RoomSouth")
        for part, (front, back), (low, high), material in (
                ("Wall", (y0, y1), (0.0, south["height"]), self.materials["cap"]),
                ("Lip", (y0 - 0.5, y0 + 3.0), (south["height"], south["height"] + 0.8), self.materials["lip"])):
            shape = bmesh.new()
            corners = {}
            for y in (front, back):
                for h in (low, high):
                    corners[(y, h, "left")] = shape.verts.new((self.side_x("left", y, h), y, h))
                    corners[(y, h, "right")] = shape.verts.new((self.side_x("right", y, h), y, h))
            for quad in (((front, low, "left"), (front, low, "right"), (front, high, "right"), (front, high, "left")),
                         ((back, low, "left"), (back, high, "left"), (back, high, "right"), (back, low, "right")),
                         ((front, high, "left"), (front, high, "right"), (back, high, "right"), (back, high, "left")),
                         ((front, low, "left"), (back, low, "left"), (back, low, "right"), (front, low, "right")),
                         ((front, low, "left"), (front, high, "left"), (back, high, "left"), (back, low, "left")),
                         ((front, low, "right"), (back, low, "right"), (back, high, "right"), (front, high, "right"))):
                shape.faces.new([corners[key] for key in quad])
            kit.shape(part, shape, material, uv="box")
        for obj in kit.made:
            self._keep(obj)


# ---------------------------------------------------------------- passes


def render_to(path):
    hall.render_to(path)


def render_props(kits, out, size):
    """Each interactive prop alone over transparency, cropped to the px it
    shows, and <render>-props.json: per prop its node, image and rect."""
    scene = bpy.context.scene
    render = scene.render
    columns, rows = render.resolution_x, render.resolution_y
    shown = [obj for obj in scene.objects if obj.type in ("MESH", "CURVE")]
    camera_flags = {obj.name: obj.visible_camera for obj in shown}
    entries = []
    for prop, kit in kits.items():
        # The prop alone, cut where the room stands in front of it: the room
        # holds out, the other props (which the game sorts) are left out.
        for obj in shown:
            owner = obj.get("room_prop")
            obj.visible_camera = owner in (None, prop)
            obj.is_holdout = owner is None
        left, top, right, bottom = kit.bounds()
        margin = PROP_MARGIN_PX
        px_left = max(int(math.floor((left - margin) * RENDER_SCALE)), 0)
        px_right = min(int(math.ceil((right + margin) * RENDER_SCALE)), columns)
        px_top = max(int(math.floor((top - margin) * RENDER_SCALE)), 0)
        px_bottom = min(int(math.ceil((bottom + margin) * RENDER_SCALE)), rows)
        hall._set_border(render, px_left, px_top, px_right, px_bottom)
        render.film_transparent = True
        render.image_settings.color_mode = "RGBA"
        image = os.path.splitext(out)[0] + "-prop-%s.png" % prop
        render_to(image)
        rect = hall._crop_shown(image, px_left, px_top, (px_right - px_left, px_bottom - px_top), RENDER_SCALE,
                                (0.0, 0.0))
        entries.append({"id": prop, "root": "Props/" + prop, "image": os.path.basename(image), "rect": rect})
        print("PROP %s shows %.1f x %.1f at (%.1f, %.1f)" % (prop, rect[2], rect[3], rect[0], rect[1]))
    render.use_border = False
    render.film_transparent = False
    render.image_settings.color_mode = "RGB"
    for obj in shown:
        obj.visible_camera = camera_flags[obj.name]
        obj.is_holdout = False
    path = os.path.splitext(out)[0] + "-props.json"
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/room_prototype.py", "props": entries}, handle, indent=1)
    print("PROPS %d -> %s" % (len(entries), path))
    return entries


def render_depth(out, size):
    """Every surface's own plan y, one px per game px, as the Hall's depth
    map: R high byte, G low byte, A where a surface hides what stands behind
    it. The floor, rugs and interactive props stay out."""
    scene = bpy.context.scene
    render = scene.render
    saved = {
        "samples": scene.cycles.samples, "adaptive": scene.cycles.use_adaptive_sampling,
        "denoise": scene.cycles.use_denoising, "filter": scene.cycles.filter_width,
        "x": render.resolution_x, "y": render.resolution_y, "transparent": render.film_transparent,
        "format": render.image_settings.file_format, "mode": render.image_settings.color_mode,
        "depth": render.image_settings.color_depth, "view": scene.view_settings.view_transform,
        "look": scene.view_settings.look, "exposure": scene.view_settings.exposure,
        "gamma": scene.view_settings.gamma,
    }
    material = bpy.data.materials.new("RoomDepthPlanY")
    nodes, links = hall._nodes(material)
    geometry_node = nodes.new("ShaderNodeNewGeometry")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geometry_node.outputs["Position"], separate.inputs[0])
    plan_y = nodes.new("ShaderNodeMath")
    plan_y.operation = "MULTIPLY"
    links.new(separate.outputs["Y"], plan_y.inputs[0])
    plan_y.inputs[1].default_value = -1.0 / (PX * STRETCH)
    combine = nodes.new("ShaderNodeCombineXYZ")
    for socket in ("X", "Y", "Z"):
        links.new(plan_y.outputs[0], combine.inputs[socket])
    emission = nodes.new("ShaderNodeEmission")
    links.new(combine.outputs[0], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.0
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    hidden = []
    for obj in scene.objects:
        if obj.type in ("MESH", "CURVE") and (obj.get("no_depth") or obj.get("room_prop")) and not obj.hide_render:
            obj.hide_render = True
            hidden.append(obj)
    layer = bpy.context.view_layer
    layer.material_override = material
    scene.cycles.samples = 1
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.cycles.filter_width = 0.01
    render.resolution_x, render.resolution_y = size
    render.film_transparent = True
    render.image_settings.file_format = "OPEN_EXR"
    render.image_settings.color_mode = "RGBA"
    render.image_settings.color_depth = "32"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    exr = os.path.splitext(out)[0] + "-depth.exr"
    render_to(exr)
    image = bpy.data.images.load(os.path.abspath(exr), check_existing=False)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    os.remove(exr)
    pixels = pixels.reshape(height, width, 4)[::-1]
    seen = pixels[..., 3] > 0.5
    value = np.clip(np.rint(pixels[..., 0]), 0, 65535).astype(np.uint32)
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    rgba[..., 0] = (value >> 8) & 255
    rgba[..., 1] = value & 255
    rgba[..., 3] = np.where(seen, 255, 0)
    rgba[~seen, :3] = 0
    path = os.path.splitext(out)[0] + "-depth.png"
    hall._write_png(path, np.ascontiguousarray(rgba))
    print("DEPTH %s: %d px of %d hide what stands behind them" % (path, int(seen.sum()), width * height))
    layer.material_override = None
    for obj in hidden:
        obj.hide_render = False
    scene.cycles.samples = saved["samples"]
    scene.cycles.use_adaptive_sampling = saved["adaptive"]
    scene.cycles.use_denoising = saved["denoise"]
    scene.cycles.filter_width = saved["filter"]
    render.resolution_x, render.resolution_y = saved["x"], saved["y"]
    render.film_transparent = saved["transparent"]
    render.image_settings.file_format = saved["format"]
    render.image_settings.color_mode = saved["mode"]
    render.image_settings.color_depth = saved["depth"]
    scene.view_settings.view_transform = saved["view"]
    scene.view_settings.look = saved["look"]
    scene.view_settings.exposure = saved["exposure"]
    scene.view_settings.gamma = saved["gamma"]
    return path


def add_camera(size):
    width, height = size
    alpha = math.radians(hall.ALPHA_DEGREES)
    data = bpy.data.cameras.new("RoomCamera")
    data.type = "ORTHO"
    data.ortho_scale = width * PX
    data.sensor_fit = "HORIZONTAL"
    data.clip_start = 0.01
    data.clip_end = 1000.0
    camera = _link(bpy.data.objects.new("RoomCamera", data))
    camera.rotation_euler = (alpha, 0.0, 0.0)
    target = world(width / 2.0, height / 2.0, 0.0)
    view = Vector((0.0, math.sin(alpha), -math.cos(alpha)))
    camera.location = target - view * 50.0
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x = int(round(width * RENDER_SCALE))
    scene.render.resolution_y = int(round(height * RENDER_SCALE))
    scene.render.resolution_percentage = 100
    return camera


def main():
    options = parse_args()
    started = time.time()
    room = importlib.import_module("room_" + options["room"].replace("_room", ""))
    data = os.path.join("prototypes", "blender_rooms", options["room"])
    with open(os.path.join(data, "layout.json"), encoding="utf-8") as handle:
        layout = json.load(handle)
    size = tuple(layout["size"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global TEXTURES
    TEXTURES = hall.TextureSet(options["textures"])
    hall.setup_world()
    built = room.build(sys.modules[__name__], layout)
    kits = built["props"]
    for material in bpy.data.materials:
        material.cycles.emission_sampling = "NONE"
    add_camera(size)
    hall.setup_cycles(options["samples"], options["preview"])
    if hasattr(room, "grade"):
        room.grade(bpy.context.scene)
    for kit in kits.values():
        for obj in kit.made:
            obj.visible_camera = False
    glows_path = os.path.splitext(options["out"])[0] + "-glows.json"
    with open(glows_path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/room_prototype.py", "region": [0, 0, size[0], size[1]],
                   "glows": GLOWS}, handle, indent=1)
    print("GLOWS %d -> %s" % (len(GLOWS), glows_path))
    if options["save_blend"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(options["save_blend"]))
    meta = {"generator": "tools/blender/room_prototype.py", "room": options["room"],
            "region": [0, 0, size[0], size[1]], "render_scale": RENDER_SCALE,
            "image": os.path.basename(options["out"]), "figure_scale": 1.0}
    if not options["props_only"]:
        render_to(options["out"])
        meta["depth"] = os.path.basename(render_depth(options["out"], size))
    for kit in kits.values():
        for obj in kit.made:
            obj.visible_camera = True
    meta["props"] = render_props(kits, options["out"], size)
    with open(os.path.splitext(options["out"])[0] + ".json", "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)
    print("ROOM %s rendered in %.1fs" % (options["room"], time.time() - started))


if __name__ == "__main__":
    main()
