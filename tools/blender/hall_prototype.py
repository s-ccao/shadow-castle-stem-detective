"""Blender 3D prototype of the Castle Hall, rendered as a 2D game image.

Usage (Blender 5.2, from the project root):

    blender -b --factory-startup -P tools/blender/hall_prototype.py -- \
        --data prototypes/blender_hall --out prototypes/blender_hall/render.png \
        [--samples 128] [--scale 2] [--silhouette path.png] [--save-blend path]

Inputs come from tools/blender/export_hall_region.gd: the real wall collision
(wall_mask.png), the floor outside the castle (outside_mask.png) and
region.json.

Projection. The camera is orthographic and tilted ALPHA_DEGREES from looking
straight down. The scene's Y axis is stretched by 1/cos(ALPHA), so the floor
lands 1:1 on game coordinates and a height z shows as z*sin(ALPHA) screen px.

Gameplay. Each wall column run (a vertical run of collision cells) shows a
top cap and a south face. Its height is chosen so the two together cover
exactly the run's cells on screen: the rendered walls match the collision, so
nothing about movement, doors or the Guardian changes, and the player is
always correctly drawn in front of every wall.
"""

import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

CELL = 4
# Blender units per game px. 1 unit = 100 px keeps light falloff in sane ranges.
PX = 0.01
ALPHA_DEGREES = 40.0
# Tallest south face on screen, and the least top cap a run keeps.
FACE_PX = 44
CAP_MIN_PX = 12
# Large wall masses get a stone rim around a sunken machinery gallery,
# echoing the existing art's pale outlines around dark machinery. Ordinary
# walls stay solid: a gallery narrower than this reads as a crack.
RIM_CELLS = 3
GALLERY_MIN_WIDTH_CELLS = 7
GALLERY_MIN_CELLS = 140
PIT_SCREEN_PX = 10
# Enclosed floor pockets this small sit inside wall masses where the collision
# decomposition left a gap. No body fits or reaches them; drawn as floor they
# become black crevices across the wall tops, so they are drawn as wall.
POCKET_MAX_CELLS = 24
# Margin of geometry built around the rendered region, for shadows cast in.
MARGIN_PX = 192
# The Wake Room gate: a taller gatehouse section of the wall whose south face,
# the side the camera sees, carries the arched door.
GATE_HALF_WIDTH_PX = 40
GATE_FACE_PX = 84
DOOR_HALF_WIDTH_PX = 17
DOOR_SPRING_PX = 52
# Lamps hang over open floor, never against the stone they would wash out.
LAMP_CLEARANCE_CELLS = 4
LAMP_HEIGHT_PX = 36

CLASS_FLOOR, CLASS_CAP, CLASS_FACE, CLASS_PIT, CLASS_PIT_WALL, CLASS_GATE = range(6)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {"samples": 128, "scale": 2, "silhouette": "", "save_blend": "", "preview": False,
               "textures": ""}
    index = 0
    while index < len(argv):
        key = argv[index]
        if key == "--data":
            options["data"] = argv[index + 1]
        elif key == "--out":
            options["out"] = argv[index + 1]
        elif key == "--samples":
            options["samples"] = int(argv[index + 1])
        elif key == "--scale":
            options["scale"] = float(argv[index + 1])
        elif key == "--silhouette":
            options["silhouette"] = argv[index + 1]
        elif key == "--save-blend":
            options["save_blend"] = argv[index + 1]
        elif key == "--textures":
            options["textures"] = argv[index + 1]
        elif key == "--preview":
            options["preview"] = True
            index += 1
            continue
        else:
            raise SystemExit("Unknown option: " + key)
        index += 2
    return options


def load_mask(path):
    image = bpy.data.images.load(os.path.abspath(path))
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    # Blender stores rows bottom-up; the game's y runs down.
    return pixels.reshape(height, width, 4)[::-1, :, 0] > 0.5


class Layout:
    """Per-cell heights (game px of 3D height) and material classes."""

    def __init__(self, wall, outside, door_center, sin_alpha):
        self.collision = wall.copy()
        wall, self.filled_pockets = self._fill_pockets(wall, outside & ~wall)
        self.wall = wall
        self.outside = outside & ~wall
        self.rows, self.columns = wall.shape
        self.height = np.zeros(wall.shape, dtype=np.float64)
        self.kind = np.full(wall.shape, CLASS_FLOOR, dtype=np.int8)
        self.footprint = np.zeros(wall.shape, dtype=bool)
        self.face_px = np.zeros(wall.shape, dtype=np.int32)
        self.sin_alpha = sin_alpha
        self.gate_face_y = None
        self._columns_to_runs(door_center)
        self._galleries()
        self.kind[self.wall & ~self.footprint] = CLASS_FLOOR

    def _columns_to_runs(self, door_center):
        """Split every column into runs, then pick each run's face height.

        Runs that end on the same south edge in neighbouring columns form one
        face. They share one height, the face's median wish, clamped per column
        to what that run can show: per-column heights stepped wherever a wall's
        north edge stepped, and the steps cast slits of shadow across the caps.
        """
        gate_row = int(door_center[1] // CELL) if door_center is not None else -1
        runs = []
        for column in range(self.columns):
            padded = np.concatenate(([False], self.wall[:, column], [False])).astype(np.int8)
            steps = np.diff(padded)
            centre_x = (column + 0.5) * CELL
            in_gate = door_center is not None and abs(centre_x - door_center[0]) <= GATE_HALF_WIDTH_PX
            for start, end in zip(np.where(steps == 1)[0], np.where(steps == -1)[0]):
                gate = in_gate and start <= gate_row < end
                tallest = GATE_FACE_PX if gate else FACE_PX
                depth = (end - start) * CELL
                wish = min(tallest, max(depth - CAP_MIN_PX, CELL)) // CELL * CELL
                runs.append([column, int(start), int(end), wish, gate])
        by_edge = {}
        for run in runs:
            by_edge.setdefault((run[2], run[4]), []).append(run)
        self.gate_runs = {}
        for (end, gate), group in by_edge.items():
            group.sort(key=lambda run: run[0])
            segment = [group[0]]
            for run in group[1:] + [None]:
                if run is not None and run[0] == segment[-1][0] + 1:
                    segment.append(run)
                    continue
                shared = int(np.median([item[3] for item in segment])) // CELL * CELL
                for column, start, run_end, _wish, is_gate in segment:
                    self._apply_run(column, start, run_end, shared, is_gate)
                if run is not None:
                    segment = [run]

    def _apply_run(self, column, start, end, shared_face, gate):
        depth = (end - start) * CELL
        if depth <= CELL:
            # A one-cell sliver cannot show both a cap and a face. It becomes a
            # low lip that overhangs its cell by one cell.
            face, lift = 0, CELL
        else:
            face = max(CELL, min(shared_face, depth - CELL))
            lift = face
        top = start + face // CELL
        self.footprint[top:end, column] = True
        self.height[top:end, column] = lift / self.sin_alpha
        self.face_px[start:end, column] = face
        self.kind[top:end, column] = CLASS_CAP
        if gate:
            self.gate_face_y = end * CELL
            self.gate_runs[column] = end

    @staticmethod
    def _fill_pockets(wall, outside):
        floor = ~wall & ~outside
        rows, columns = floor.shape
        seen = np.zeros_like(floor)
        filled = wall.copy()
        count = 0
        for row, column in zip(*np.nonzero(floor)):
            if seen[row, column]:
                continue
            stack = [(row, column)]
            seen[row, column] = True
            component = []
            touches_edge = False
            while stack:
                r, c = stack.pop()
                component.append((r, c))
                if r in (0, rows - 1) or c in (0, columns - 1):
                    touches_edge = True
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < rows and 0 <= nc < columns and floor[nr, nc] and not seen[nr, nc]:
                        seen[nr, nc] = True
                        stack.append((nr, nc))
            if len(component) <= POCKET_MAX_CELLS and not touches_edge:
                for r, c in component:
                    filled[r, c] = True
                count += len(component)
        print("POCKETS filled %d enclosed floor cells" % count)
        return filled, count

    @staticmethod
    def _erode(mask, times):
        inner = mask.copy()
        for _ in range(times):
            shrunk = inner.copy()
            shrunk[1:, :] &= inner[:-1, :]
            shrunk[:-1, :] &= inner[1:, :]
            shrunk[:, 1:] &= inner[:, :-1]
            shrunk[:, :-1] &= inner[:, 1:]
            shrunk[0, :] = shrunk[-1, :] = False
            shrunk[:, 0] = shrunk[:, -1] = False
            inner = shrunk
        return inner

    @staticmethod
    def _dilate(mask, times):
        grown = mask.copy()
        for _ in range(times):
            wider = grown.copy()
            wider[1:, :] |= grown[:-1, :]
            wider[:-1, :] |= grown[1:, :]
            wider[:, 1:] |= grown[:, :-1]
            wider[:, :-1] |= grown[:, 1:]
            grown = wider
        return grown

    def _galleries(self):
        inner = self._erode(self.footprint, RIM_CELLS)
        # Opening: anything narrower than the minimum width disappears.
        half = GALLERY_MIN_WIDTH_CELLS // 2
        inner = self._dilate(self._erode(inner, half), half) & inner
        for column in self.gate_runs:
            inner[:, column] = False
        keep = np.zeros_like(inner)
        seen = np.zeros_like(inner)
        rows, columns = inner.shape
        for row, column in zip(*np.nonzero(inner)):
            if seen[row, column]:
                continue
            stack = [(row, column)]
            seen[row, column] = True
            component = []
            while stack:
                r, c = stack.pop()
                component.append((r, c))
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < rows and 0 <= nc < columns and inner[nr, nc] and not seen[nr, nc]:
                        seen[nr, nc] = True
                        stack.append((nr, nc))
            if len(component) >= GALLERY_MIN_CELLS:
                for r, c in component:
                    keep[r, c] = True
        self.pit = keep
        self.height[keep] = np.maximum(self.height[keep] - PIT_SCREEN_PX / self.sin_alpha, 2.0)
        self.kind[keep] = CLASS_PIT


def build_geometry(layout, crop, stretch):
    """Quads per cell: tops, the vertical steps between neighbours, and floor."""
    row_lo, row_hi, column_lo, column_hi = crop
    vertices = []
    lookup = {}
    faces = []
    materials = []

    def vertex(column_edge, row_edge, z):
        key = (column_edge, row_edge, round(z, 5))
        found = lookup.get(key)
        if found is None:
            found = len(vertices)
            lookup[key] = found
            vertices.append((column_edge * CELL * PX, -row_edge * CELL * PX, z * PX))
        return found

    height = layout.height
    kind = layout.kind
    gate_runs = layout.gate_runs
    for row in range(row_lo, row_hi):
        for column in range(column_lo, column_hi):
            if layout.outside[row, column]:
                continue
            z = height[row, column]
            cell_kind = int(kind[row, column])
            faces.append((
                vertex(column, row + 1, z), vertex(column + 1, row + 1, z),
                vertex(column + 1, row, z), vertex(column, row, z),
            ))
            materials.append(cell_kind)
            if z <= 0.0:
                continue
            for d_row, d_column in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                other_row, other_column = row + d_row, column + d_column
                if 0 <= other_row < height.shape[0] and 0 <= other_column < height.shape[1]:
                    other = height[other_row, other_column]
                    other_kind = int(kind[other_row, other_column])
                else:
                    other, other_kind = 0.0, CLASS_FLOOR
                if other >= z:
                    continue
                inner = other_kind == CLASS_PIT or cell_kind == CLASS_PIT
                side = CLASS_PIT_WALL if inner else CLASS_FACE
                if d_row == 1 and gate_runs.get(column) == row + 1 and not inner:
                    side = CLASS_GATE
                if d_row == 1:  # south neighbour: face looks south, at the camera
                    quad = (vertex(column, row + 1, other), vertex(column + 1, row + 1, other),
                            vertex(column + 1, row + 1, z), vertex(column, row + 1, z))
                elif d_row == -1:
                    quad = (vertex(column + 1, row, other), vertex(column, row, other),
                            vertex(column, row, z), vertex(column + 1, row, z))
                elif d_column == 1:
                    quad = (vertex(column + 1, row + 1, other), vertex(column + 1, row, other),
                            vertex(column + 1, row, z), vertex(column + 1, row + 1, z))
                else:
                    quad = (vertex(column, row, other), vertex(column, row + 1, other),
                            vertex(column, row + 1, z), vertex(column, row, z))
                faces.append(quad)
                materials.append(side)
    mesh = bpy.data.meshes.new("HallPrototype")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.polygons.foreach_set("material_index", materials)
    _project_uvs(mesh)
    obj = bpy.data.objects.new("HallPrototype", mesh)
    obj.scale = (1.0, stretch, 1.0)
    bpy.context.scene.collection.objects.link(obj)
    print("GEOMETRY vertices=%d faces=%d" % (len(vertices), len(faces)))
    return obj


def _project_uvs(mesh):
    """Planar UVs per face: ground plane for tops, along-and-up for walls.

    Cube projection from the vertex positions keeps coplanar neighbours
    continuous, and gives the normal maps a tangent frame that matches the
    face: +u east, +v north on tops, +v up on walls.
    """
    loops = len(mesh.loops)
    coords = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", coords)
    coords = coords.reshape(-1, 3)
    loop_vertex = np.empty(loops, dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loop_vertex)
    normals = np.empty(len(mesh.polygons) * 3, dtype=np.float64)
    mesh.polygons.foreach_get("normal", normals)
    normals = normals.reshape(-1, 3)
    totals = np.empty(len(mesh.polygons), dtype=np.int64)
    mesh.polygons.foreach_get("loop_total", totals)
    loop_normal = np.repeat(normals, totals, axis=0)
    position = coords[loop_vertex]
    uv = np.zeros((loops, 2), dtype=np.float64)
    top = np.abs(loop_normal[:, 2]) > 0.5
    across = ~top & (np.abs(loop_normal[:, 1]) > 0.5)
    sideways = ~top & ~across
    uv[top] = position[top][:, [0, 1]]
    facing = np.sign(-loop_normal[across, 1])
    uv[across, 0] = position[across, 0] * facing
    uv[across, 1] = position[across, 2]
    facing = np.sign(loop_normal[sideways, 0])
    uv[sideways, 0] = position[sideways, 1] * facing
    uv[sideways, 1] = position[sideways, 2]
    layer = mesh.uv_layers.new(name="UVMap")
    layer.data.foreach_set("uv", uv.astype(np.float32).ravel())


# ---------------------------------------------------------------- materials


def _nodes(material):
    material.use_nodes = True
    tree = material.node_tree
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    return tree.nodes, tree.links


def _object_coords(nodes, links, swizzle=None, scale=1.0):
    coords = nodes.new("ShaderNodeTexCoord")
    if swizzle is None and scale == 1.0:
        return coords.outputs["Object"]
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], separate.inputs[0])
    combine = nodes.new("ShaderNodeCombineXYZ")
    axes = swizzle or "XYZ"
    for target, source in zip("XYZ", axes):
        links.new(separate.outputs[source], combine.inputs[target])
    if scale != 1.0:
        multiply = nodes.new("ShaderNodeVectorMath")
        multiply.operation = "SCALE"
        multiply.inputs["Scale"].default_value = scale
        links.new(combine.outputs[0], multiply.inputs[0])
        return multiply.outputs[0]
    return combine.outputs[0]


# ShaderNodeMix keeps one socket per data type under the same name, so "A",
# "B" and "Result" by name are the float ones. The colour sockets are these.
MIX_COLOR_A, MIX_COLOR_B, MIX_COLOR_RESULT = 6, 7, 2


def _mix(nodes, links, factor, color_a, color_b, blend="MIX"):
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = blend
    if isinstance(factor, float):
        mix.inputs[0].default_value = factor
    else:
        links.new(factor, mix.inputs[0])
    for index, value in ((MIX_COLOR_A, color_a), (MIX_COLOR_B, color_b)):
        if isinstance(value, tuple):
            mix.inputs[index].default_value = value + (1.0,) if len(value) == 3 else value
        else:
            links.new(value, mix.inputs[index])
    return mix.outputs[MIX_COLOR_RESULT]


def _noise(nodes, links, vector, scale, detail=4.0, roughness=0.55):
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = roughness
    links.new(vector, noise.inputs["Vector"])
    return noise.outputs["Fac"]


def _bricks(nodes, links, vector, width, row, mortar, offset=0.5, frequency=2):
    brick = nodes.new("ShaderNodeTexBrick")
    brick.offset = offset
    brick.offset_frequency = frequency
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Brick Width"].default_value = width
    brick.inputs["Row Height"].default_value = row
    brick.inputs["Mortar Size"].default_value = mortar
    brick.inputs["Mortar Smooth"].default_value = 0.35
    brick.inputs["Bias"].default_value = 0.0
    brick.inputs["Color1"].default_value = (1.0, 1.0, 1.0, 1.0)
    brick.inputs["Color2"].default_value = (0.55, 0.55, 0.55, 1.0)
    brick.inputs["Mortar"].default_value = (0.0, 0.0, 0.0, 1.0)
    links.new(vector, brick.inputs["Vector"])
    return brick.outputs["Color"], brick.outputs["Fac"]


def _principled(nodes, links, color, roughness, metallic=0.0, normal=None, emission=None,
                emission_strength=0.0):
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    if isinstance(color, tuple):
        shader.inputs["Base Color"].default_value = color + (1.0,)
    else:
        links.new(color, shader.inputs["Base Color"])
    if isinstance(roughness, float):
        shader.inputs["Roughness"].default_value = roughness
    else:
        links.new(roughness, shader.inputs["Roughness"])
    shader.inputs["Metallic"].default_value = metallic
    if normal is not None:
        links.new(normal, shader.inputs["Normal"])
    if emission is not None:
        if isinstance(emission, tuple):
            shader.inputs["Emission Color"].default_value = emission + (1.0,)
        else:
            links.new(emission, shader.inputs["Emission Color"])
        if isinstance(emission_strength, float):
            shader.inputs["Emission Strength"].default_value = emission_strength
        else:
            links.new(emission_strength, shader.inputs["Emission Strength"])
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return shader


def _bump(nodes, links, height, strength, distance=0.004, normal=None):
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = distance
    links.new(height, bump.inputs["Height"])
    if normal is not None:
        links.new(normal, bump.inputs["Normal"])
    return bump.outputs["Normal"]


def _bevel(nodes, radius):
    bevel = nodes.new("ShaderNodeBevel")
    bevel.samples = 4
    bevel.inputs["Radius"].default_value = radius
    return bevel.outputs["Normal"]


def _ao_multiply(nodes, links, color, distance, floor_value=0.45):
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 4
    ao.inputs["Distance"].default_value = distance
    shaped = nodes.new("ShaderNodeMapRange")
    shaped.inputs["From Min"].default_value = 0.0
    shaped.inputs["From Max"].default_value = 1.0
    shaped.inputs["To Min"].default_value = floor_value
    shaped.inputs["To Max"].default_value = 1.0
    links.new(ao.outputs["AO"], shaped.inputs["Value"])
    return _mix(nodes, links, 1.0, color, shaped.outputs["Result"], blend="MULTIPLY")


def material_floor():
    """Worn flagstones: per-stone tone, ochre wear, grime, varied shine."""
    material = bpy.data.materials.new("FloorFlagstone")
    nodes, links = _nodes(material)
    coords = _object_coords(nodes, links)
    stone, mortar = _bricks(nodes, links, coords, width=0.2, row=0.15, mortar=0.016,
                            offset=0.43, frequency=1)
    cells = nodes.new("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 6.5
    links.new(coords, cells.inputs["Vector"])
    wear = _noise(nodes, links, coords, scale=3.5, detail=6.0)
    grime = _noise(nodes, links, coords, scale=14.0, detail=8.0, roughness=0.65)
    grain = _noise(nodes, links, coords, scale=70.0, detail=6.0)
    base = _mix(nodes, links, stone, (0.072, 0.062, 0.070), (0.125, 0.105, 0.108))
    base = _mix(nodes, links, cells.outputs["Color"], base, (0.11, 0.09, 0.085), blend="OVERLAY")
    ochre = nodes.new("ShaderNodeMapRange")
    ochre.inputs["From Min"].default_value = 0.52
    ochre.inputs["From Max"].default_value = 0.72
    ochre.inputs["To Max"].default_value = 0.55
    links.new(wear, ochre.inputs["Value"])
    base = _mix(nodes, links, ochre.outputs["Result"], base, (0.20, 0.12, 0.06))
    dirt = nodes.new("ShaderNodeMapRange")
    dirt.inputs["From Min"].default_value = 0.5
    dirt.inputs["From Max"].default_value = 0.75
    dirt.inputs["To Max"].default_value = 0.6
    links.new(grime, dirt.inputs["Value"])
    base = _mix(nodes, links, dirt.outputs["Result"], base, (0.03, 0.026, 0.03))
    base = _mix(nodes, links, mortar, base, (0.022, 0.018, 0.024))
    base = _ao_multiply(nodes, links, base, distance=0.25, floor_value=0.4)
    height = nodes.new("ShaderNodeMath")
    height.operation = "SUBTRACT"
    height.inputs[0].default_value = 1.0
    links.new(mortar, height.inputs[1])
    combined = nodes.new("ShaderNodeMath")
    combined.operation = "MULTIPLY_ADD"
    links.new(grain, combined.inputs[0])
    combined.inputs[1].default_value = 0.18
    links.new(height.outputs[0], combined.inputs[2])
    normal = _bump(nodes, links, combined.outputs[0], strength=0.5, distance=0.01)
    shine = nodes.new("ShaderNodeMapRange")
    shine.inputs["To Min"].default_value = 0.5
    shine.inputs["To Max"].default_value = 0.88
    links.new(grime, shine.inputs["Value"])
    _principled(nodes, links, base, roughness=shine.outputs["Result"], normal=normal)
    return material


def material_cap():
    """Weathered capstones: per-slab tone, stains, chipped edges."""
    material = bpy.data.materials.new("WallCapStone")
    nodes, links = _nodes(material)
    coords = _object_coords(nodes, links)
    stone, mortar = _bricks(nodes, links, coords, width=0.36, row=0.2, mortar=0.01,
                            offset=0.5, frequency=2)
    slabs = nodes.new("ShaderNodeTexVoronoi")
    slabs.inputs["Scale"].default_value = 4.0
    links.new(coords, slabs.inputs["Vector"])
    wear = _noise(nodes, links, coords, scale=6.0, detail=6.0)
    stain = _noise(nodes, links, coords, scale=1.8, detail=4.0)
    chips = _noise(nodes, links, coords, scale=38.0, detail=4.0)
    base = _mix(nodes, links, stone, (0.30, 0.285, 0.285), (0.43, 0.41, 0.395))
    base = _mix(nodes, links, slabs.outputs["Color"], base, (0.38, 0.36, 0.35), blend="OVERLAY")
    base = _mix(nodes, links, wear, base, (0.33, 0.30, 0.29))
    stain_mask = nodes.new("ShaderNodeMapRange")
    stain_mask.inputs["From Min"].default_value = 0.5
    stain_mask.inputs["From Max"].default_value = 0.72
    stain_mask.inputs["To Max"].default_value = 0.65
    links.new(stain, stain_mask.inputs["Value"])
    base = _mix(nodes, links, stain_mask.outputs["Result"], base, (0.17, 0.16, 0.16))
    base = _mix(nodes, links, mortar, base, (0.10, 0.10, 0.095))
    base = _ao_multiply(nodes, links, base, distance=0.12, floor_value=0.55)
    height = nodes.new("ShaderNodeMath")
    height.operation = "SUBTRACT"
    height.inputs[0].default_value = 1.0
    links.new(mortar, height.inputs[1])
    rough_top = nodes.new("ShaderNodeMath")
    rough_top.operation = "MULTIPLY_ADD"
    links.new(chips, rough_top.inputs[0])
    rough_top.inputs[1].default_value = 0.25
    links.new(height.outputs[0], rough_top.inputs[2])
    normal = _bump(nodes, links, rough_top.outputs[0], strength=0.45, distance=0.006,
                   normal=_bevel(nodes, 0.02))
    _principled(nodes, links, base, roughness=0.78, normal=normal)
    return material


def _z_band(nodes, links, low, high):
    """1 between two heights (object units) on the wall, 0 elsewhere."""
    coords = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], separate.inputs[0])
    above = nodes.new("ShaderNodeMath")
    above.operation = "GREATER_THAN"
    above.inputs[1].default_value = low
    links.new(separate.outputs["Z"], above.inputs[0])
    below = nodes.new("ShaderNodeMath")
    below.operation = "LESS_THAN"
    below.inputs[1].default_value = high
    links.new(separate.outputs["Z"], below.inputs[0])
    both = nodes.new("ShaderNodeMath")
    both.operation = "MULTIPLY"
    links.new(above.outputs[0], both.inputs[0])
    links.new(below.outputs[0], both.inputs[1])
    return both.outputs[0]


def material_face(full_height):
    material = bpy.data.materials.new("WallFaceBrick")
    nodes, links = _nodes(material)
    # Bricks lie in the wall plane: x along the wall, z up it.
    coords = _object_coords(nodes, links, swizzle="XZY")
    stone, mortar = _bricks(nodes, links, coords, width=0.19, row=0.105, mortar=0.014,
                            offset=0.5, frequency=2)
    wear = _noise(nodes, links, coords, scale=9.0)
    base = _mix(nodes, links, stone, (0.125, 0.112, 0.135), (0.205, 0.188, 0.215))
    base = _mix(nodes, links, wear, base, (0.16, 0.14, 0.15))
    base = _mix(nodes, links, mortar, base, (0.035, 0.030, 0.040))
    base = _ao_multiply(nodes, links, base, distance=0.3, floor_value=0.3)
    band = _z_band(nodes, links, full_height * 0.86, full_height * 0.91)
    base = _mix(nodes, links, band, base, (0.66, 0.46, 0.17))
    height = nodes.new("ShaderNodeMath")
    height.operation = "SUBTRACT"
    height.inputs[0].default_value = 1.0
    links.new(mortar, height.inputs[1])
    raised = nodes.new("ShaderNodeMath")
    raised.operation = "MULTIPLY_ADD"
    links.new(band, raised.inputs[0])
    raised.inputs[1].default_value = 0.6
    links.new(height.outputs[0], raised.inputs[2])
    normal = _bump(nodes, links, raised.outputs[0], strength=0.4, distance=0.006,
                   normal=_bevel(nodes, 0.014))
    shader = _principled(nodes, links, base, roughness=0.74, normal=normal)
    links.new(band, shader.inputs["Metallic"])
    return material


def material_pit():
    """Sunken galleries: dark works, brass pipe runs, a few violet crystals."""
    material = bpy.data.materials.new("GalleryMachinery")
    nodes, links = _nodes(material)
    coords = _object_coords(nodes, links)
    plates, seams = _bricks(nodes, links, coords, width=0.3, row=0.18, mortar=0.006,
                            offset=0.0, frequency=1)
    pipes = nodes.new("ShaderNodeTexWave")
    pipes.wave_type = "BANDS"
    pipes.bands_direction = "Y"
    pipes.wave_profile = "SIN"
    pipes.inputs["Scale"].default_value = 3.2
    pipes.inputs["Distortion"].default_value = 0.0
    pipes.inputs["Detail"].default_value = 0.0
    links.new(coords, pipes.inputs["Vector"])
    pipe_mask = nodes.new("ShaderNodeMapRange")
    pipe_mask.inputs["From Min"].default_value = 0.8
    pipe_mask.inputs["From Max"].default_value = 0.88
    links.new(pipes.outputs["Fac"], pipe_mask.inputs["Value"])
    crystals = nodes.new("ShaderNodeTexVoronoi")
    crystals.inputs["Scale"].default_value = 5.0
    crystals.inputs["Randomness"].default_value = 1.0
    links.new(coords, crystals.inputs["Vector"])
    crystal_mask = nodes.new("ShaderNodeMapRange")
    crystal_mask.inputs["From Min"].default_value = 0.06
    crystal_mask.inputs["From Max"].default_value = 0.035
    links.new(crystals.outputs["Distance"], crystal_mask.inputs["Value"])
    works = _mix(nodes, links, plates, (0.020, 0.017, 0.026), (0.042, 0.035, 0.046))
    works = _mix(nodes, links, seams, works, (0.008, 0.006, 0.010))
    color = _mix(nodes, links, pipe_mask.outputs["Result"], works, (0.52, 0.36, 0.13))
    color = _mix(nodes, links, crystal_mask.outputs["Result"], color, (0.55, 0.36, 0.95))
    color = _ao_multiply(nodes, links, color, distance=0.15, floor_value=0.35)
    normal = _bump(nodes, links, pipes.outputs["Fac"], strength=0.8, distance=0.012)
    shader = _principled(nodes, links, color, roughness=0.4, normal=normal)
    links.new(pipe_mask.outputs["Result"], shader.inputs["Metallic"])
    shader.inputs["Emission Color"].default_value = (0.55, 0.32, 1.0, 1.0)
    strength = nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = 2.5
    links.new(crystal_mask.outputs["Result"], strength.inputs[0])
    links.new(strength.outputs[0], shader.inputs["Emission Strength"])
    return material


def material_pit_wall():
    material = bpy.data.materials.new("GalleryWall")
    nodes, links = _nodes(material)
    coords = _object_coords(nodes, links, swizzle="XZY")
    stone, mortar = _bricks(nodes, links, coords, width=0.16, row=0.09, mortar=0.012)
    base = _mix(nodes, links, stone, (0.05, 0.045, 0.055), (0.085, 0.075, 0.09))
    base = _mix(nodes, links, mortar, base, (0.015, 0.012, 0.018))
    base = _ao_multiply(nodes, links, base, distance=0.2, floor_value=0.3)
    _principled(nodes, links, base, roughness=0.8)
    return material


def material_gate(door_x, sin_alpha, full_height, textures=None):
    """The Wake Room gate face: an arched oak door in a pale stone frame.

    Shapes are laid out in screen proportions (height * sin(alpha)) so the arch
    reads round after the camera's tilt foreshortens the wall.
    """
    material = bpy.data.materials.new("WakeGate")
    nodes, links = _nodes(material)
    coords = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], separate.inputs[0])

    def math(operation, a, b=None):
        node = nodes.new("ShaderNodeMath")
        node.operation = operation
        for index, value in enumerate((a, b)):
            if value is None:
                continue
            if isinstance(value, (int, float)):
                node.inputs[index].default_value = float(value)
            else:
                links.new(value, node.inputs[index])
        return node.outputs[0]

    local_x = math("SUBTRACT", separate.outputs["X"], door_x)
    across = math("ABSOLUTE", local_x)
    up = math("MULTIPLY", separate.outputs["Z"], sin_alpha)
    half = DOOR_HALF_WIDTH_PX * PX
    spring = DOOR_SPRING_PX * PX * 0.6

    def arch(half_width, spring_height):
        straight = math("MULTIPLY", math("LESS_THAN", across, half_width),
                        math("LESS_THAN", up, spring_height))
        dz = math("SUBTRACT", up, spring_height)
        radius = math("SQRT", math("ADD", math("MULTIPLY", local_x, local_x),
                                    math("MULTIPLY", dz, dz)))
        curved = math("MULTIPLY", math("LESS_THAN", radius, half_width),
                      math("GREATER_THAN", up, spring_height - 0.0001))
        return math("MAXIMUM", straight, curved)

    door = arch(half, spring)
    frame = math("SUBTRACT", arch(half + 0.055, spring), door)
    planks = nodes.new("ShaderNodeTexWave")
    planks.wave_type = "BANDS"
    planks.bands_direction = "X"
    planks.inputs["Scale"].default_value = 26.0
    planks.inputs["Distortion"].default_value = 1.5
    planks.inputs["Detail"].default_value = 2.0
    links.new(coords.outputs["Object"], planks.inputs["Vector"])
    wood = _mix(nodes, links, planks.outputs["Fac"], (0.10, 0.055, 0.03), (0.23, 0.13, 0.065))
    if textures is not None and textures.available():
        oak = textures.sample(nodes, links, "rough_pine_door", repeat=0.36)
        wood = _grade(nodes, links, oak["diff"], 0.7, (0.95, 0.82, 0.7), saturation=0.9)
    straps = math("MAXIMUM",
                  math("MULTIPLY", math("GREATER_THAN", up, 0.075), math("LESS_THAN", up, 0.095)),
                  math("MULTIPLY", math("GREATER_THAN", up, 0.235), math("LESS_THAN", up, 0.255)))
    door_color = _mix(nodes, links, straps, wood, (0.62, 0.44, 0.17))
    edge_shadow = math("MULTIPLY", math("GREATER_THAN", across, half - 0.03), door)
    door_color = _mix(nodes, links, edge_shadow, door_color, (0.03, 0.02, 0.015))
    brick_coords = _object_coords(nodes, links, swizzle="XZY")
    stone, mortar = _bricks(nodes, links, brick_coords, width=0.19, row=0.105, mortar=0.014)
    wall_color = _mix(nodes, links, stone, (0.14, 0.125, 0.15), (0.22, 0.2, 0.23))
    wall_color = _mix(nodes, links, mortar, wall_color, (0.035, 0.03, 0.04))
    wall_color = _ao_multiply(nodes, links, wall_color, distance=0.3, floor_value=0.3)
    band = _z_band(nodes, links, full_height * 0.86, full_height * 0.91)
    wall_color = _mix(nodes, links, band, wall_color, (0.66, 0.46, 0.17))
    color = _mix(nodes, links, frame, wall_color, (0.62, 0.59, 0.6))
    color = _mix(nodes, links, door, color, door_color)
    keystone = math("LESS_THAN", math("SQRT", math("ADD",
        math("MULTIPLY", local_x, local_x),
        math("MULTIPLY", math("SUBTRACT", up, spring + half + 0.03),
             math("SUBTRACT", up, spring + half + 0.03)))), 0.03)
    lantern_left = math("LESS_THAN", math("SQRT", math("ADD",
        math("MULTIPLY", math("ADD", local_x, half + 0.12), math("ADD", local_x, half + 0.12)),
        math("MULTIPLY", math("SUBTRACT", up, 0.3), math("SUBTRACT", up, 0.3)))), 0.022)
    lantern_right = math("LESS_THAN", math("SQRT", math("ADD",
        math("MULTIPLY", math("SUBTRACT", local_x, half + 0.12),
             math("SUBTRACT", local_x, half + 0.12)),
        math("MULTIPLY", math("SUBTRACT", up, 0.3), math("SUBTRACT", up, 0.3)))), 0.022)
    lanterns = math("MAXIMUM", lantern_left, lantern_right)
    relief = math("SUBTRACT", math("MULTIPLY", frame, 0.8), math("MULTIPLY", door, 0.6))
    normal = _bump(nodes, links, relief, strength=0.9, distance=0.02, normal=_bevel(nodes, 0.012))
    shader = _principled(nodes, links, color, roughness=0.62, normal=normal)
    metal = math("MAXIMUM", math("MULTIPLY", straps, door), band)
    links.new(metal, shader.inputs["Metallic"])
    emission = _mix(nodes, links, lanterns, (0.62, 0.38, 1.0), (1.0, 0.66, 0.32))
    links.new(emission, shader.inputs["Emission Color"])
    links.new(math("ADD", math("MULTIPLY", keystone, 8.0), math("MULTIPLY", lanterns, 12.0)),
              shader.inputs["Emission Strength"])
    return material


class TextureSet:
    """CC0 photo textures (Poly Haven), graded toward the game's palette."""

    def __init__(self, directory):
        self.directory = directory

    def available(self):
        if not self.directory or not os.path.isdir(self.directory):
            return False
        return all(
            os.path.exists(self._path(asset, "diff"))
            for asset in ("large_floor_tiles_02", "castle_wall_slates", "large_grey_tiles",
                          "metal_plate", "rough_pine_door")
        )

    def _path(self, asset, kind):
        for extension in (".jpg", ".png"):
            candidate = os.path.join(self.directory, "%s_%s_1k%s" % (asset, kind, extension))
            if os.path.exists(candidate):
                return candidate
        return os.path.join(self.directory, "%s_%s_1k.jpg" % (asset, kind))

    def sample(self, nodes, links, asset, repeat):
        """Graded colour, roughness and a tangent normal for one texture set."""
        coords = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0 / repeat, 1.0 / repeat, 1.0)
        links.new(coords.outputs["UV"], mapping.inputs["Vector"])
        result = {}
        for kind, non_color in (("diff", False), ("rough", True), ("nor_gl", True)):
            texture = nodes.new("ShaderNodeTexImage")
            texture.image = bpy.data.images.load(os.path.abspath(self._path(asset, kind)),
                                                 check_existing=True)
            if non_color:
                texture.image.colorspace_settings.name = "Non-Color"
            texture.interpolation = "Cubic"
            links.new(mapping.outputs["Vector"], texture.inputs["Vector"])
            result[kind] = texture.outputs["Color"]
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.space = "TANGENT"
        normal_map.uv_map = "UVMap"
        normal_map.inputs["Strength"].default_value = 1.0
        links.new(result["nor_gl"], normal_map.inputs["Color"])
        result["normal"] = normal_map.outputs["Normal"]
        return result


def _grade(nodes, links, color, value, tint, saturation=0.75):
    """Darken and tint a photo texture so it sits in the castle's palette."""
    hsv = nodes.new("ShaderNodeHueSaturation")
    hsv.inputs["Saturation"].default_value = saturation
    hsv.inputs["Value"].default_value = value
    links.new(color, hsv.inputs["Color"])
    return _mix(nodes, links, 1.0, hsv.outputs["Color"], tint, blend="MULTIPLY")


def _bevelled(nodes, links, normal, radius):
    bevel = nodes.new("ShaderNodeBevel")
    bevel.samples = 4
    bevel.inputs["Radius"].default_value = radius
    links.new(normal, bevel.inputs["Normal"])
    return bevel.outputs["Normal"]


def material_floor_textured(textures):
    material = bpy.data.materials.new("FloorFlagstone")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "large_floor_tiles_02", repeat=0.85)
    color = _grade(nodes, links, maps["diff"], 0.7, (0.7, 0.63, 0.7))
    color = _ao_multiply(nodes, links, color, distance=0.25, floor_value=0.4)
    _principled(nodes, links, color, roughness=maps["rough"], normal=maps["normal"])
    return material


def material_cap_textured(textures):
    material = bpy.data.materials.new("WallCapStone")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "large_grey_tiles", repeat=0.75)
    color = _grade(nodes, links, maps["diff"], 0.9, (0.86, 0.83, 0.9))
    color = _ao_multiply(nodes, links, color, distance=0.12, floor_value=0.55)
    normal = _bevelled(nodes, links, maps["normal"], 0.02)
    _principled(nodes, links, color, roughness=maps["rough"], normal=normal)
    return material


def material_face_textured(textures, full_height):
    material = bpy.data.materials.new("WallFaceStone")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "castle_wall_slates", repeat=0.8)
    color = _grade(nodes, links, maps["diff"], 0.62, (0.66, 0.6, 0.74))
    color = _ao_multiply(nodes, links, color, distance=0.3, floor_value=0.35)
    band = _z_band(nodes, links, full_height * 0.86, full_height * 0.91)
    color = _mix(nodes, links, band, color, (0.66, 0.46, 0.17))
    normal = _bevelled(nodes, links, maps["normal"], 0.014)
    shader = _principled(nodes, links, color, roughness=maps["rough"], normal=normal)
    links.new(band, shader.inputs["Metallic"])
    return material


def material_pit_textured(textures):
    """The galleries: dark plate works, brass pipe runs, a few violet crystals."""
    material = material_pit()
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    maps = textures.sample(nodes, links, "metal_plate", repeat=0.5)
    plate = _grade(nodes, links, maps["diff"], 0.35, (0.55, 0.5, 0.62), saturation=0.5)
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    base = shader.inputs["Base Color"].links[0].from_socket
    # Replace the flat works colour under the pipes and crystals with the plate.
    mix_nodes = [node for node in nodes if node.type == "MIX" and node.data_type == "RGBA"]
    works_mix = mix_nodes[0]
    links.new(plate, works_mix.inputs[MIX_COLOR_A])
    links.new(plate, works_mix.inputs[MIX_COLOR_B])
    del base
    return material


def make_materials(door_x, sin_alpha, textures=None):
    full_height = FACE_PX / sin_alpha * PX
    gate_height = GATE_FACE_PX / sin_alpha * PX
    if textures is not None and textures.available():
        print("MATERIALS CC0 photo textures from", textures.directory)
        return [material_floor_textured(textures), material_cap_textured(textures),
                material_face_textured(textures, full_height), material_pit_textured(textures),
                material_pit_wall(), material_gate(door_x, sin_alpha, gate_height, textures)]
    print("MATERIALS procedural")
    return [material_floor(), material_cap(), material_face(full_height), material_pit(),
            material_pit_wall(), material_gate(door_x, sin_alpha, gate_height)]


# ---------------------------------------------------------------- world, lights, camera


def world_point(x, y, z, stretch):
    return Vector((x * PX, -y * PX * stretch, z * PX))


def setup_world():
    world = bpy.data.worlds.new("HallNight")
    bpy.context.scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    ambient = nodes.new("ShaderNodeBackground")
    ambient.inputs["Color"].default_value = (0.05, 0.036, 0.085, 1.0)
    ambient.inputs["Strength"].default_value = 1.25
    void = nodes.new("ShaderNodeBackground")
    void.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    light_path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(light_path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(ambient.outputs["Background"], mix.inputs[1])
    links.new(void.outputs["Background"], mix.inputs[2])
    output = nodes.new("ShaderNodeOutputWorld")
    links.new(mix.outputs["Shader"], output.inputs["Surface"])


def add_sun():
    data = bpy.data.lights.new("Moonlight", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sun = bpy.data.objects.new("Moonlight", data)
    # From the south-west and above, so the south faces the camera sees are lit
    # and shadows fall north-east, partly behind the walls that cast them.
    direction = Vector((0.36, 0.3, -0.88)).normalized()
    sun.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(sun)


def _clear_floor(layout):
    open_floor = ~layout.wall & ~layout.outside
    clear = open_floor.copy()
    for _ in range(LAMP_CLEARANCE_CELLS):
        shrunk = clear.copy()
        shrunk[1:, :] &= clear[:-1, :]
        shrunk[:-1, :] &= clear[1:, :]
        shrunk[:, 1:] &= clear[:, :-1]
        shrunk[:, :-1] &= clear[:, 1:]
        clear = shrunk
    return clear


def nearest_floor(layout, x, y, clear=None):
    row, column = int(y // CELL), int(x // CELL)
    allowed = clear if clear is not None else (~layout.wall & ~layout.outside)
    best = None
    for radius in range(0, 40):
        for d_row in range(-radius, radius + 1):
            for d_column in range(-radius, radius + 1):
                if max(abs(d_row), abs(d_column)) != radius:
                    continue
                r, c = row + d_row, column + d_column
                if 0 <= r < layout.rows and 0 <= c < layout.columns:
                    if allowed[r, c]:
                        candidate = ((c + 0.5) * CELL, (r + 0.5) * CELL)
                        distance = (candidate[0] - x) ** 2 + (candidate[1] - y) ** 2
                        if best is None or distance < best[0]:
                            best = (distance, candidate)
        if best is not None:
            return best[1]
    return (x, y)


def add_point_light(name, position, height, color, power, radius, stretch):
    data = bpy.data.lights.new(name, "POINT")
    data.energy = power
    data.color = color
    data.shadow_soft_size = radius
    light = bpy.data.objects.new(name, data)
    light.location = world_point(position[0], position[1], height, stretch)
    bpy.context.scene.collection.objects.link(light)


def _lantern_material():
    material = bpy.data.materials.get("LanternGlass")
    if material is not None:
        return material
    material = bpy.data.materials.new("LanternGlass")
    nodes, links = _nodes(material)
    shader = _principled(nodes, links, (1.0, 0.7, 0.35), roughness=0.3,
                         emission=(1.0, 0.62, 0.28), emission_strength=22.0)
    del shader
    return material


def _iron_material():
    material = bpy.data.materials.get("LanternIron")
    if material is not None:
        return material
    material = bpy.data.materials.new("LanternIron")
    nodes, links = _nodes(material)
    _principled(nodes, links, (0.04, 0.035, 0.035), roughness=0.45, metallic=0.9)
    return material


def _wall_mount(layout, x, y, reach_cells=24):
    """The nearest south face, in front of which a lantern can hang."""
    row, column = int(y // CELL), int(x // CELL)
    best = None
    for r in range(max(row - reach_cells, 0), min(row + reach_cells, layout.rows - 1)):
        for c in range(max(column - reach_cells, 0), min(column + reach_cells, layout.columns)):
            if layout.kind[r, c] != CLASS_CAP or not layout.footprint[r, c]:
                continue
            below = r + 1
            if layout.wall[below, c] or layout.outside[below, c]:
                continue
            if layout.face_px[r, c] < FACE_PX:
                continue
            distance = (r - row) ** 2 + (c - column) ** 2
            if best is None or distance < best[0]:
                best = (distance, r, c)
    if best is None:
        return None
    _distance, r, c = best
    return ((c + 0.5) * CELL, (r + 1) * CELL, layout.height[r, c])


def add_lantern(name, mount, stretch):
    x, face_y, wall_height = mount
    z = wall_height * 0.6
    glass = bpy.data.meshes.new(name + "Glass")
    import bmesh
    shape = bmesh.new()
    bmesh.ops.create_uvsphere(shape, u_segments=12, v_segments=8, radius=3.4 * PX)
    shape.to_mesh(glass)
    shape.free()
    glass_object = bpy.data.objects.new(name + "Glass", glass)
    glass_object.location = world_point(x, face_y + 4.0, z, stretch)
    glass_object.data.materials.append(_lantern_material())
    bpy.context.scene.collection.objects.link(glass_object)
    bracket = bpy.data.meshes.new(name + "Bracket")
    shape = bmesh.new()
    bmesh.ops.create_cube(shape, size=1.0)
    shape.to_mesh(bracket)
    shape.free()
    bracket_object = bpy.data.objects.new(name + "Bracket", bracket)
    bracket_object.location = world_point(x, face_y + 1.5, z + 5.0, stretch)
    bracket_object.scale = (2.0 * PX, 3.0 * PX * stretch, 6.0 * PX)
    bracket_object.data.materials.append(_iron_material())
    bpy.context.scene.collection.objects.link(bracket_object)
    data = bpy.data.lights.new(name, "POINT")
    data.energy = 3.2
    data.color = (1.0, 0.62, 0.3)
    data.shadow_soft_size = 0.04
    light = bpy.data.objects.new(name, data)
    light.location = world_point(x, face_y + 10.0, z, stretch)
    bpy.context.scene.collection.objects.link(light)


def add_lamps(layout, meta, stretch):
    x0, y0, width, height = meta["region"]
    violet = (0.62, 0.42, 1.0)
    clear = _clear_floor(layout)
    lanterns = [
        ("LampWest", (130.0, 960.0)), ("LampSpawn", (300.0, 1010.0)),
        ("LampHallway", (540.0, 960.0)), ("LampGallery", (760.0, 1080.0)),
        ("LampNorth", (860.0, 860.0)),
    ]
    used = set()
    for name, (x, y) in lanterns:
        if not (x0 - MARGIN_PX <= x <= x0 + width + MARGIN_PX and y0 - MARGIN_PX <= y <= y0 + height + MARGIN_PX):
            continue
        mount = _wall_mount(layout, x, y)
        if mount is None or (round(mount[0]), round(mount[1])) in used:
            continue
        used.add((round(mount[0]), round(mount[1])))
        add_lantern(name, mount, stretch)
        # A dim fill where the old lamp hung keeps the corridor readable.
        add_point_light(name + "Fill", nearest_floor(layout, x, y, clear), LAMP_HEIGHT_PX,
                        (1.0, 0.66, 0.36), 1.4, 0.2, stretch)
    for name, (x, y) in (("GlowCentre", (420.0, 880.0)), ("GlowEast", (980.0, 1010.0))):
        add_point_light(name, nearest_floor(layout, x, y, clear), LAMP_HEIGHT_PX, violet, 3.0,
                        0.1, stretch)
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    if door is not None and layout.gate_face_y is not None:
        face_y = layout.gate_face_y
        for side in (-1.0, 1.0):
            add_point_light("GateLantern", (door[0] + side * 30.0, face_y + 14.0), 46.0,
                            (1.0, 0.64, 0.3), 1.6, 0.04, stretch)
        add_point_light("GateKeystone", (door[0], face_y + 10.0), 78.0, violet, 1.2, 0.03, stretch)


def add_camera(meta, alpha, stretch, scale):
    x0, y0, width, height = meta["region"]
    data = bpy.data.cameras.new("HallCamera")
    data.type = "ORTHO"
    data.ortho_scale = width * PX
    data.sensor_fit = "HORIZONTAL"
    data.clip_start = 0.01
    data.clip_end = 1000.0
    camera = bpy.data.objects.new("HallCamera", data)
    camera.rotation_euler = (alpha, 0.0, 0.0)
    target = world_point(x0 + width / 2.0, y0 + height / 2.0, 0.0, stretch)
    view = Vector((0.0, math.sin(alpha), -math.cos(alpha)))
    camera.location = target - view * 50.0
    bpy.context.scene.collection.objects.link(camera)
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x = int(round(width * scale))
    scene.render.resolution_y = int(round(height * scale))
    scene.render.resolution_percentage = 100
    return camera


def setup_cycles(samples, preview):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    preferences = bpy.context.preferences.addons["cycles"].preferences
    try:
        preferences.compute_device_type = "METAL"
        preferences.get_devices()
        for device in preferences.devices:
            device.use = device.type == "METAL"
        scene.cycles.device = "GPU"
    except Exception as error:  # noqa: BLE001 - fall back to the CPU
        print("GPU unavailable, rendering on CPU:", error)
        scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 2
    scene.cycles.transmission_bounces = 2
    scene.cycles.filter_width = 1.0
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    if preview:
        scene.cycles.samples = min(samples, 24)


def render_to(path):
    bpy.context.scene.render.filepath = os.path.abspath(path)
    started = time.time()
    bpy.ops.render.render(write_still=True)
    print("RENDERED %s in %.1fs" % (path, time.time() - started))


def render_silhouette(path, floor_free_object, meta, scale):
    """Flat white walls on transparent: the outline the camera sees."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1.0, 1.0, 1.0)
    scene.display.render_aa = "OFF"
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    floor_free_object.hide_render = False
    render_to(path)


def compare_silhouette(path, layout, meta, scale):
    image = bpy.data.images.load(os.path.abspath(path))
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    seen = pixels.reshape(height, width, 4)[::-1, :, 3] > 0.5
    x0, y0, region_w, region_h = meta["region"]
    factor = int(round(scale))
    window = (slice(y0 // CELL, (y0 + region_h) // CELL), slice(x0 // CELL, (x0 + region_w) // CELL))
    block = np.ones((CELL * factor, CELL * factor), dtype=bool)
    expected = np.kron(layout.collision[window], block)
    pockets = np.kron(layout.wall[window] & ~layout.collision[window], block)
    union = np.logical_or(seen, expected).sum()
    overlap = np.logical_and(seen, expected).sum()
    extra_mask = np.logical_and(seen, ~expected)
    extra = extra_mask.sum()
    extra_pockets = np.logical_and(extra_mask, pockets).sum()
    missing = np.logical_and(~seen, expected).sum()
    print("SILHOUETTE vs collision: iou=%.5f extra_px=%d (unreachable pockets %d, lips %d) "
          "missing_px=%d (render %dx%d, %d px per game px)" % (
              overlap / max(union, 1), extra, extra_pockets, extra - extra_pockets, missing,
              width, height, factor))
    diff = np.zeros((height, width, 4), dtype=np.float32)
    diff[..., 3] = 1.0
    diff[np.logical_and(seen, expected)] = (0.35, 0.35, 0.40, 1.0)
    diff[np.logical_and(seen, ~expected)] = (1.0, 0.2, 0.2, 1.0)
    diff[np.logical_and(~seen, expected)] = (0.2, 0.6, 1.0, 1.0)
    out = bpy.data.images.new("SilhouetteDiff", width, height, alpha=True)
    out.pixels.foreach_set(diff[::-1].ravel())
    out.filepath_raw = os.path.abspath(path.replace(".png", "-diff.png"))
    out.file_format = "PNG"
    out.save()


def main():
    options = parse_args()
    data = options["data"]
    with open(os.path.join(data, "region.json"), encoding="utf-8") as handle:
        meta = json.load(handle)
    alpha = math.radians(ALPHA_DEGREES)
    stretch = 1.0 / math.cos(alpha)
    wall_full = load_mask(os.path.join(data, "wall_mask.png"))
    outside_full = load_mask(os.path.join(data, "outside_mask.png"))
    half = CELL // 2
    wall = wall_full[half::CELL, half::CELL]
    outside = outside_full[half::CELL, half::CELL]
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    layout = Layout(wall, outside, door, math.sin(alpha))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    x0, y0, width, height = meta["region"]
    crop = (
        max((y0 - MARGIN_PX) // CELL, 0), min((y0 + height + MARGIN_PX) // CELL, layout.rows),
        max((x0 - MARGIN_PX) // CELL, 0), min((x0 + width + MARGIN_PX) // CELL, layout.columns),
    )
    hall = build_geometry(layout, crop, stretch)
    door_x = (door[0] if door is not None else 0.0) * PX
    textures = TextureSet(options["textures"] or os.path.join(data, "textures"))
    for material in make_materials(door_x, math.sin(alpha), textures):
        hall.data.materials.append(material)
    setup_world()
    add_sun()
    add_lamps(layout, meta, stretch)
    add_camera(meta, alpha, stretch, options["scale"])
    setup_cycles(options["samples"], options["preview"])
    if options["save_blend"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(options["save_blend"]))
    render_to(options["out"])
    if options["silhouette"]:
        # Floor quads would fill the outline; hide them by giving the silhouette
        # pass a walls-only copy.
        walls_only = hall.copy()
        walls_only.data = hall.data.copy()
        walls_only.name = "HallWallsOnly"
        bpy.context.scene.collection.objects.link(walls_only)
        hall.hide_render = True
        mesh = walls_only.data
        import bmesh
        edit = bmesh.new()
        edit.from_mesh(mesh)
        doomed = [face for face in edit.faces if face.material_index == CLASS_FLOOR]
        bmesh.ops.delete(edit, geom=doomed, context="FACES")
        edit.to_mesh(mesh)
        edit.free()
        render_silhouette(options["silhouette"], walls_only, meta, options["scale"])
        compare_silhouette(options["silhouette"], layout, meta, options["scale"])


if __name__ == "__main__":
    main()
