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

Gameplay. Each wall column run (a vertical run of wall px) shows a top cap
and a south face. Its height is chosen so the two together cover exactly the
run on screen: the rendered walls match the collision, so nothing about
movement, doors or the Guardian changes, and the player is always correctly
drawn in front of every wall. The collision is a 4 px raster whose diagonals
are stairs; the walls follow a smoothed copy that stays within 2 px of it.
"""

import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

CELL = 1
# The wall collision is a 4 px raster traced from the old art, so its
# diagonals are 4 px stairs. Geometry is built per game px from a lightly
# smoothed copy: straight edges stay exact, stairs become slopes, and no edge
# moves more than SMOOTH_TOLERANCE_PX from the collision.
SOURCE_CELL = 4
SMOOTH_SIGMA_PX = 2.5
SMOOTH_TOLERANCE_PX = 2
# Blender units per game px. 1 unit = 100 px keeps light falloff in sane ranges.
PX = 0.01
ALPHA_DEGREES = 40.0
# Tallest south face on screen, and the least top cap a run keeps.
FACE_PX = 44
CAP_MIN_PX = 12
# Neighbouring columns whose south edges differ by at most this much belong to
# one face and share its height, so a sloped wall keeps a level top.
EDGE_SLACK_PX = 3
# Large wall masses get a stone rim around a sunken machinery gallery,
# echoing the existing art's pale outlines around dark machinery. Ordinary
# walls stay solid: a gallery narrower than this reads as a crack.
RIM_PX = 12
GALLERY_MIN_WIDTH_PX = 28
GALLERY_MIN_AREA_PX = 2240
PIT_SCREEN_PX = 12
# Enclosed floor pockets this small, in 4 px collision cells, sit inside wall
# masses where the collision decomposition left a gap. No body fits or reaches
# them; drawn as floor they become black crevices across the wall tops, so
# they are drawn as wall.
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
LAMP_CLEARANCE_PX = 16
LAMP_HEIGHT_PX = 36

CLASS_FLOOR, CLASS_CAP, CLASS_FACE, CLASS_PIT, CLASS_PIT_WALL, CLASS_GATE, CLASS_CAP_EDGE = range(7)
# Wall tops are dark so the lit corridors read as the space to explore. A
# capstone lip catches the light: deep along the south edge the camera faces,
# a thin line on the other edges so every mass keeps its outline.
CAP_EDGE_PX = 8
CAP_RIM_PX = 3
SEED = 1307


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


def _gaussian(field, sigma):
    """Separable Gaussian blur with edge padding."""
    radius = int(math.ceil(sigma * 3.0))
    offsets = np.arange(-radius, radius + 1, dtype=np.float32)
    kernel = np.exp(-0.5 * (offsets / sigma) ** 2)
    kernel /= kernel.sum()
    rows, columns = field.shape
    padded = np.pad(field, ((radius, radius), (0, 0)), mode="edge")
    field = sum(weight * padded[index:index + rows, :] for index, weight in enumerate(kernel))
    padded = np.pad(field, ((0, 0), (radius, radius)), mode="edge")
    return sum(weight * padded[:, index:index + columns] for index, weight in enumerate(kernel))


def _erode(mask, times):
    """Shrink by `times` px, 4-neighbour; beyond the array counts as outside."""
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


def _clearance(mask, limit):
    """How far each px of `mask` is from its edge, by octagonal erosion, up to `limit`."""
    result = np.zeros(mask.shape, dtype=np.int32)
    current = mask.copy()
    for step in range(1, limit + 1):
        result[current] = step
        shrunk = _erode(current, 1)
        if step % 2 == 0:
            shrunk[1:, 1:] &= current[:-1, :-1]
            shrunk[:-1, :-1] &= current[1:, 1:]
            shrunk[1:, :-1] &= current[:-1, 1:]
            shrunk[:-1, 1:] &= current[1:, :-1]
        current = shrunk
        if not current.any():
            break
    return result


def _block_any(mask, size):
    rows, columns = mask.shape[0] // size, mask.shape[1] // size
    return mask[:rows * size, :columns * size].reshape(rows, size, columns, size).any(axis=(1, 3))


def _upsample(grid, size, shape):
    return np.kron(grid, np.ones((size, size), dtype=grid.dtype))[:shape[0], :shape[1]]


def _flood_labels(mask):
    """4-connected components: a label per cell (0 for none) and each label's size."""
    labels = np.zeros(mask.shape, dtype=np.int32)
    sizes = [0]
    rows, columns = mask.shape
    for row, column in zip(*np.nonzero(mask)):
        if labels[row, column]:
            continue
        label = len(sizes)
        labels[row, column] = label
        stack = [(row, column)]
        size = 0
        while stack:
            r, c = stack.pop()
            size += 1
            for nr, nc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                if 0 <= nr < rows and 0 <= nc < columns and mask[nr, nc] and not labels[nr, nc]:
                    labels[nr, nc] = label
                    stack.append((nr, nc))
        sizes.append(size)
    return labels, np.array(sizes)


def _runs(valid, *keys):
    """Start and end of each maximal run where `valid` holds and every key stays equal."""
    count = len(valid)
    if count == 0:
        empty = np.zeros(0, dtype=np.int64)
        return empty, empty
    same = valid[1:] == valid[:-1]
    for key in keys:
        same &= key[1:] == key[:-1]
    starts = np.flatnonzero(np.concatenate(([True], ~same)))
    ends = np.append(starts[1:], count)
    keep = valid[starts]
    return starts[keep], ends[keep]


class Layout:
    """Per-px heights (game px of 3D height) and material classes."""

    def __init__(self, collision, outside, door_center, sin_alpha):
        self.collision = collision
        filled, self.filled_pockets = self._fill_pockets(collision, outside)
        self.pockets = filled & ~collision
        self.wall = self._smooth(filled)
        self.outside = outside & ~self.wall
        self.rows, self.columns = self.wall.shape
        self.height = np.zeros(self.wall.shape, dtype=np.float64)
        self.kind = np.full(self.wall.shape, CLASS_FLOOR, dtype=np.int8)
        self.footprint = np.zeros(self.wall.shape, dtype=bool)
        self.face_px = np.zeros(self.wall.shape, dtype=np.int32)
        self.pit = np.zeros(self.wall.shape, dtype=bool)
        self.sin_alpha = sin_alpha
        self.gate_face_y = None
        self.gate_runs = {}
        self.galleries = []
        self._columns_to_runs(door_center)
        self._galleries()
        self._cap_edges()
        self.kind[self.wall & ~self.footprint] = CLASS_FLOOR

    @staticmethod
    def _fill_pockets(collision, outside):
        """Wall in the small enclosed floor pockets of the 4 px collision raster."""
        half = SOURCE_CELL // 2
        wall = collision[half::SOURCE_CELL, half::SOURCE_CELL]
        floor = ~wall & ~outside[half::SOURCE_CELL, half::SOURCE_CELL]
        labels, sizes = _flood_labels(floor)
        pocket = sizes <= POCKET_MAX_CELLS
        pocket[0] = False
        pocket[np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))] = False
        cells = pocket[labels]
        print("POCKETS filled %d enclosed floor cells" % int(cells.sum()))
        return collision | _upsample(cells, SOURCE_CELL, collision.shape), int(cells.sum())

    @staticmethod
    def _smooth(wall):
        """Round off the 4 px stairs; straight edges stay where they are."""
        field = _gaussian(wall.astype(np.float32), SMOOTH_SIGMA_PX)
        smooth = (field >= 0.5) | _erode(wall, 1)
        return smooth & _dilate(wall, SMOOTH_TOLERANCE_PX)

    def _columns_to_runs(self, door_center):
        """Split every column into runs, then pick each run's face height.

        Runs whose south edges continue from column to column form one face.
        They share one height, the face's median wish, clamped per column to
        what that run can show: per-column heights stepped wherever a wall's
        north edge stepped, and the steps cast slits of shadow across the caps.
        """
        gate_row = int(door_center[1]) if door_center is not None else -1
        runs = []
        by_column = []
        for column in range(self.columns):
            padded = np.concatenate(([False], self.wall[:, column], [False])).astype(np.int8)
            steps = np.diff(padded)
            in_gate = door_center is not None and abs(column + 0.5 - door_center[0]) <= GATE_HALF_WIDTH_PX
            here = []
            for start, end in zip(np.flatnonzero(steps == 1), np.flatnonzero(steps == -1)):
                gate = bool(in_gate and start <= gate_row < end)
                tallest = GATE_FACE_PX if gate else FACE_PX
                wish = min(tallest, max(int(end - start) - CAP_MIN_PX, 1))
                here.append(len(runs))
                runs.append((column, int(start), int(end), wish, gate))
            by_column.append(here)
        chain_of = [-1] * len(runs)
        chains = []
        for column in range(self.columns):
            taken = set()
            for index in by_column[column]:
                _column, start, end, _wish, gate = runs[index]
                link = -1
                for previous in (by_column[column - 1] if column else ()):
                    _p, p_start, p_end, _w, p_gate = runs[previous]
                    chain = chain_of[previous]
                    if (p_gate == gate and abs(p_end - end) <= EDGE_SLACK_PX and p_start < end
                            and start < p_end and chain not in taken):
                        link = chain
                        break
                if link < 0:
                    link = len(chains)
                    chains.append([])
                taken.add(link)
                chains[link].append(index)
                chain_of[index] = link
        for chain in chains:
            shared = int(np.median([runs[index][3] for index in chain]))
            for index in chain:
                column, start, end, _wish, gate = runs[index]
                self._apply_run(column, start, end, shared, gate)

    def _apply_run(self, column, start, end, shared_face, gate):
        depth = end - start
        if depth <= 1:
            # A 1 px sliver cannot show both a cap and a face. It becomes a
            # low lip that overhangs its px by one px.
            face, lift = 0, 1
        else:
            face = max(1, min(shared_face, depth - 1))
            lift = face
        top = start + face
        self.footprint[top:end, column] = True
        self.height[top:end, column] = lift / self.sin_alpha
        self.face_px[start:end, column] = face
        self.kind[top:end, column] = CLASS_CAP
        if gate:
            self.gate_face_y = end
            self.gate_runs[column] = end

    def _galleries(self):
        inner = _erode(self.footprint, RIM_PX)
        # Opening: anything narrower than the minimum width disappears.
        half = GALLERY_MIN_WIDTH_PX // 2
        inner = _dilate(_erode(inner, half), half) & inner
        for column in self.gate_runs:
            inner[:, column] = False
        # Components are found on the coarse collision grid; the opening above
        # has already given their edges a smooth shape.
        coarse, _sizes = _flood_labels(_block_any(inner, SOURCE_CELL))
        labels = _upsample(coarse, SOURCE_CELL, inner.shape)
        labels[~inner] = 0
        areas = np.bincount(labels.ravel())
        keep = np.zeros_like(inner)
        for label in np.flatnonzero(areas >= GALLERY_MIN_AREA_PX):
            if label == 0:
                continue
            rows, columns = np.nonzero(labels == label)
            top, left = int(rows.min()), int(columns.min())
            mask = np.zeros((rows.max() - top + 1, columns.max() - left + 1), dtype=bool)
            mask[rows - top, columns - left] = True
            self.galleries.append({"top": top, "left": left, "mask": mask})
            keep[rows, columns] = True
        self.pit = keep
        self.height[keep] = np.maximum(self.height[keep] - PIT_SCREEN_PX / self.sin_alpha, 2.0)
        self.kind[keep] = CLASS_PIT
        print("GALLERIES %d" % len(self.galleries))

    def _cap_edges(self):
        south = np.zeros_like(self.footprint)
        for depth in range(1, CAP_EDGE_PX + 1):
            behind = np.zeros_like(self.footprint)
            behind[:-depth, :] = self.footprint[depth:, :]
            south |= self.footprint & ~behind
        solid = self.footprint & ~self.pit
        rim = solid & ~_erode(solid, CAP_RIM_PX)
        self.kind[(south | rim) & (self.kind == CLASS_CAP)] = CLASS_CAP_EDGE


# Merged quads stay within tiles this size: long thin slivers would make the
# ray tracer's bounding boxes overlap across whole rows.
GEOMETRY_TILE_PX = 32


def build_geometry(layout, crop, stretch):
    """Merged quads: tops as tile-sized rectangles, wall faces as runs of equal steps."""
    row_lo, row_hi, column_lo, column_hi = crop
    # One px of context around the crop; beyond the map counts as open floor.
    first_row, first_column = row_lo - 1, column_lo - 1
    shape = (row_hi - row_lo + 2, column_hi - column_lo + 2)
    source = (slice(max(first_row, 0), min(row_hi + 1, layout.rows)),
              slice(max(first_column, 0), min(column_hi + 1, layout.columns)))
    target = (slice(source[0].start - first_row, source[0].stop - first_row),
              slice(source[1].start - first_column, source[1].stop - first_column))

    def window(array, fill):
        out = np.full(shape, fill, dtype=array.dtype)
        out[target] = array[source]
        return out

    height = window(layout.height, 0.0)
    kind = window(layout.kind, CLASS_FLOOR).astype(np.int16)
    outside = window(layout.outside, False)
    built = np.zeros(shape, dtype=bool)
    built[1:-1, 1:-1] = True
    built &= ~outside
    pit = kind == CLASS_PIT
    gate_end = np.full(shape[1], -1, dtype=np.int64)
    for column, end in layout.gate_runs.items():
        if 0 <= column - first_column < shape[1]:
            gate_end[column - first_column] = end
    column_tiles = (first_column + np.arange(shape[1])) // GEOMETRY_TILE_PX
    row_tiles = (first_row + np.arange(shape[0])) // GEOMETRY_TILE_PX
    corners = []
    materials = []

    def emit(points, material):
        corners.append(np.stack([np.column_stack(point) for point in points], axis=1))
        materials.append(np.asarray(material, dtype=np.int32))

    # Tops: runs along each row, stacked into rectangles while the run below
    # matches and stays in the same tile band.
    rectangles = []
    growing = {}
    for row in range(1, shape[0] - 1):
        starts, ends = _runs(built[row], height[row], kind[row], column_tiles)
        continuing = {}
        for start, end in zip(starts.tolist(), ends.tolist()):
            key = (start, end, float(height[row, start]), int(kind[row, start]))
            rectangle = growing.pop(key, None)
            if rectangle is not None and row_tiles[rectangle[0]] == row_tiles[row]:
                rectangle[1] = row + 1
            else:
                if rectangle is not None:
                    rectangles.append(key + tuple(rectangle))
                rectangle = [row, row + 1]
            continuing[key] = rectangle
        rectangles.extend(key + tuple(rectangle) for key, rectangle in growing.items())
        growing = continuing
    rectangles.extend(key + tuple(rectangle) for key, rectangle in growing.items())
    tops = np.array(rectangles, dtype=np.float64)
    x0, x1 = first_column + tops[:, 0], first_column + tops[:, 1]
    z = tops[:, 2]
    y0, y1 = first_row + tops[:, 4], first_row + tops[:, 5]
    emit(((x0, y1, z), (x1, y1, z), (x1, y0, z), (x0, y0, z)), tops[:, 3].astype(np.int32))

    for upper in range(shape[0] - 1):
        lower = upper + 1
        high, low = height[upper], height[lower]
        side = np.where(pit[upper] | pit[lower], CLASS_PIT_WALL, CLASS_FACE)
        south = np.where((gate_end == first_row + lower) & (side == CLASS_FACE), CLASS_GATE, side)
        for facing_south in (True, False):
            if facing_south:
                starts, ends = _runs((high > low) & built[upper], high, low, south, column_tiles)
                bottom, top, material = low, high, south
            else:
                starts, ends = _runs((low > high) & built[lower], high, low, side, column_tiles)
                bottom, top, material = high, low, side
            if len(starts) == 0:
                continue
            x0, x1 = first_column + starts + 0.0, first_column + ends + 0.0
            y = np.full(len(starts), first_row + lower + 0.0)
            z0, z1 = bottom[starts], top[starts]
            if facing_south:
                emit(((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)), material[starts])
            else:
                emit(((x1, y, z0), (x0, y, z0), (x0, y, z1), (x1, y, z1)), material[starts])

    for left in range(shape[1] - 1):
        right = left + 1
        high, low = height[:, left], height[:, right]
        side = np.where(pit[:, left] | pit[:, right], CLASS_PIT_WALL, CLASS_FACE)
        for facing_east in (True, False):
            if facing_east:
                starts, ends = _runs((high > low) & built[:, left], high, low, side, row_tiles)
                bottom, top = low, high
            else:
                starts, ends = _runs((low > high) & built[:, right], high, low, side, row_tiles)
                bottom, top = high, low
            if len(starts) == 0:
                continue
            y0, y1 = first_row + starts + 0.0, first_row + ends + 0.0
            x = np.full(len(starts), first_column + right + 0.0)
            z0, z1 = bottom[starts], top[starts]
            if facing_east:
                emit(((x, y1, z0), (x, y0, z0), (x, y0, z1), (x, y1, z1)), side[starts])
            else:
                emit(((x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)), side[starts])

    quads = np.concatenate(corners)
    points = quads.reshape(-1, 3) * PX
    points[:, 1] *= -1.0
    unique, inverse = np.unique(np.round(points, 6), axis=0, return_inverse=True)
    faces = np.asarray(inverse).reshape(-1, 4)
    mesh = bpy.data.meshes.new("HallPrototype")
    mesh.from_pydata(unique.tolist(), [], faces.tolist())
    mesh.update()
    mesh.polygons.foreach_set("material_index", np.concatenate(materials))
    _project_uvs(mesh)
    obj = bpy.data.objects.new("HallPrototype", mesh)
    obj.scale = (1.0, stretch, 1.0)
    bpy.context.scene.collection.objects.link(obj)
    print("GEOMETRY vertices=%d faces=%d" % (len(unique), len(faces)))
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


RUNE_GLOW = (0.45, 0.3, 1.0)


def material_floor_textured(textures):
    material = bpy.data.materials.new("FloorFlagstone")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "large_floor_tiles_02", repeat=0.85)
    color = _grade(nodes, links, maps["diff"], 0.7, (0.7, 0.63, 0.7))
    color = _ao_multiply(nodes, links, color, distance=0.25, floor_value=0.4)
    _principled(nodes, links, color, roughness=maps["rough"], normal=maps["normal"])
    return material


def add_compass_inlay(inlay, stretch):
    """The compass rose: its own disc just above the flagstones, so only the
    disc pays for the rose's shader."""
    centre_x, centre_y, radius = inlay
    material = bpy.data.materials.new("CompassInlay")
    nodes, links = _nodes(material)
    op = _MathBuilder(nodes, links)
    coords = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], separate.inputs[0])
    # Object coordinates of the disc are centred on the rose.
    parts = _compass_inlay(op, separate.outputs["X"], separate.outputs["Y"], (0.0, 0.0, radius))
    stone = _noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=6.0)
    color = _mix(nodes, links, stone, (0.014, 0.012, 0.018), (0.03, 0.026, 0.036))
    color = _mix(nodes, links, parts["brass"], color, (0.64, 0.46, 0.2))
    color = _mix(nodes, links, parts["shade"], color, (0.3, 0.19, 0.08))
    shader = _principled(nodes, links, color, roughness=op("ADD", 0.12, op("MULTIPLY", parts["brass"], 0.18)))
    links.new(parts["brass"], shader.inputs["Metallic"])
    shader.inputs["Emission Color"].default_value = RUNE_GLOW + (1.0,)
    links.new(op("MULTIPLY", parts["glow"], 0.7), shader.inputs["Emission Strength"])
    shape = bmesh.new()
    bmesh.ops.create_circle(shape, cap_ends=True, cap_tris=False, segments=96, radius=radius * PX)
    inlay_object = _prop("CompassInlay", shape, material, world_point(centre_x, centre_y, 0.1, stretch), stretch)
    # Lies on the floor: the silhouette pass leaves it out like the floor.
    inlay_object["floor_decal"] = True


class _MathBuilder:
    """Shader math in one call: op("ADD", a, b) with sockets or numbers."""

    def __init__(self, nodes, links):
        self.nodes = nodes
        self.links = links

    def __call__(self, operation, a, b=None):
        node = self.nodes.new("ShaderNodeMath")
        node.operation = operation
        for index, value in enumerate((a, b)):
            if value is None:
                continue
            if isinstance(value, (int, float)):
                node.inputs[index].default_value = float(value)
            else:
                self.links.new(value, node.inputs[index])
        return node.outputs[0]

    def between(self, value, low, high):
        return self("MULTIPLY", self("GREATER_THAN", value, low), self("LESS_THAN", value, high))


def _ramp(nodes, links, value, low, high):
    """0 below `low`, 1 above `high`, linear between."""
    node = nodes.new("ShaderNodeMapRange")
    node.inputs["From Min"].default_value = low
    node.inputs["From Max"].default_value = high
    links.new(value, node.inputs["Value"])
    return node.outputs["Result"]


def _compass_inlay(op, x, y, inlay):
    """A brass compass rose set in a polished disc, ringed by faintly lit runes."""
    centre_x, centre_y, radius = inlay
    local_x = op("SUBTRACT", x, centre_x * PX)
    local_y = op("SUBTRACT", y, -centre_y * PX)
    square = op("ADD", op("MULTIPLY", local_x, local_x), op("MULTIPLY", local_y, local_y))
    r = op("DIVIDE", op("SQRT", square), radius * PX)
    safe = op("ADD", square, 1e-12)
    cos2 = op("DIVIDE", op("SUBTRACT", op("MULTIPLY", local_x, local_x), op("MULTIPLY", local_y, local_y)), safe)
    sin2 = op("DIVIDE", op("MULTIPLY", op("MULTIPLY", local_x, local_y), 2.0), safe)
    turn = op("DIVIDE", op("ADD", op("ARCTAN2", local_y, local_x), math.pi), 2.0 * math.pi)
    disc = op("LESS_THAN", r, 1.0)

    def ring(at, half_width):
        return op.between(r, at - half_width, at + half_width)

    rings = op("MAXIMUM", op("MAXIMUM", ring(0.965, 0.022), ring(0.83, 0.012)), ring(0.6, 0.012))
    ticks = op("MULTIPLY", op.between(r, 0.87, 0.94),
               op("LESS_THAN", op("FRACT", op("MULTIPLY", turn, 64.0)), 0.16))
    long_points = op("LESS_THAN", r, op("ADD", 0.07, op("MULTIPLY", 0.5, op("POWER", op("ABSOLUTE", cos2), 12.0))))
    short_points = op("LESS_THAN", r, op("ADD", 0.05, op("MULTIPLY", 0.3, op("POWER", op("ABSOLUTE", sin2), 12.0))))
    # Each point is split into a lit and a shaded half, as on a ship's compass.
    long_shade = op("MULTIPLY", long_points, op("GREATER_THAN", op("MULTIPLY", local_x, local_y), 0.0))
    short_shade = op("MULTIPLY", op("MULTIPLY", short_points, op("SUBTRACT", 1.0, long_points)),
                     op("GREATER_THAN", op("ABSOLUTE", local_x), op("ABSOLUTE", local_y)))
    hub = op("LESS_THAN", r, 0.06)
    brass = op("MAXIMUM", op("MAXIMUM", rings, ticks), op("MAXIMUM", long_points, short_points))
    shade = op("MULTIPLY", op("MAXIMUM", long_shade, short_shade), op("SUBTRACT", 1.0, hub))
    # A ring of runes between the inner rings: stems, bars and slants picked
    # per glyph slot, so no two neighbours repeat.
    across = op("DIVIDE", op("SUBTRACT", r, 0.64), 0.15)
    slot = op("MULTIPLY", turn, 18.0)
    along = op("FRACT", slot)
    index = op("FLOOR", slot)

    def coin(seed):
        return op("FRACT", op("MULTIPLY", op("SINE", op("ADD", op("MULTIPLY", index, 12.9898), seed)), 43758.5453))

    strokes = op("MULTIPLY", op.between(along, 0.45, 0.55), op("GREATER_THAN", coin(1.7), 0.25))
    for seed, low, high in ((3.1, 0.1, 0.24), (5.3, 0.43, 0.57), (7.9, 0.76, 0.9)):
        bar = op("MULTIPLY", op.between(across, low, high), op.between(along, 0.22, 0.78))
        strokes = op("MAXIMUM", strokes, op("MULTIPLY", bar, op("GREATER_THAN", coin(seed), 0.45)))
    slant = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("SUBTRACT", along, 0.5),
                                                op("MULTIPLY", op("SUBTRACT", across, 0.5), 0.7))), 0.06)
    strokes = op("MAXIMUM", strokes, op("MULTIPLY", slant, op("GREATER_THAN", coin(9.4), 0.55)))
    runes = op("MULTIPLY", op("MULTIPLY", op.between(across, 0.04, 0.96), op.between(along, 0.12, 0.88)),
               strokes)
    glow = op("MAXIMUM", runes, op("MULTIPLY", hub, 1.6))
    return {"disc": disc, "brass": brass, "shade": shade, "glow": glow}


def material_cap_textured(textures, lit=True):
    material = bpy.data.materials.new("WallCapLip" if lit else "WallTopDark")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "large_grey_tiles", repeat=0.75)
    if lit:
        color = _grade(nodes, links, maps["diff"], 0.95, (0.88, 0.84, 0.86))
    else:
        color = _grade(nodes, links, maps["diff"], 0.3, (0.55, 0.5, 0.66), saturation=0.6)
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
    """Gallery floors: dark riveted plate under the brass works."""
    material = bpy.data.materials.new("GalleryFloor")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "metal_plate", repeat=0.5)
    plate = _grade(nodes, links, maps["diff"], 0.3, (0.55, 0.5, 0.62), saturation=0.5)
    plate = _ao_multiply(nodes, links, plate, distance=0.12, floor_value=0.25)
    shader = _principled(nodes, links, plate, roughness=maps["rough"], normal=maps["normal"])
    shader.inputs["Metallic"].default_value = 0.6
    return material


def make_materials(door_x, sin_alpha, textures=None):
    full_height = FACE_PX / sin_alpha * PX
    gate_height = GATE_FACE_PX / sin_alpha * PX
    if textures is not None and textures.available():
        print("MATERIALS CC0 photo textures from", textures.directory)
        return [material_floor_textured(textures), material_cap_textured(textures, lit=False),
                material_face_textured(textures, full_height), material_pit_textured(textures),
                material_pit_wall(), material_gate(door_x, sin_alpha, gate_height, textures),
                material_cap_textured(textures, lit=True)]
    print("MATERIALS procedural")
    return [material_floor(), material_cap(), material_face(full_height), material_pit(),
            material_pit_wall(), material_gate(door_x, sin_alpha, gate_height), material_cap()]


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
    return _erode(~layout.wall & ~layout.outside, LAMP_CLEARANCE_PX)


def _nearest(mask, x, y, reach):
    """Row and column of the `mask` px nearest (x, y), within `reach` px."""
    row_lo, row_hi = max(int(y) - reach, 0), min(int(y) + reach, mask.shape[0])
    column_lo, column_hi = max(int(x) - reach, 0), min(int(x) + reach, mask.shape[1])
    rows, columns = np.nonzero(mask[row_lo:row_hi, column_lo:column_hi])
    if len(rows) == 0:
        return None
    best = int(np.argmin((column_lo + columns + 0.5 - x) ** 2 + (row_lo + rows + 0.5 - y) ** 2))
    return int(row_lo + rows[best]), int(column_lo + columns[best])


def nearest_floor(layout, x, y, clear=None):
    found = _nearest(clear if clear is not None else (~layout.wall & ~layout.outside), x, y, 160)
    return (x, y) if found is None else (found[1] + 0.5, found[0] + 0.5)


def _south_faces(layout):
    """Px on the south edge of a full-height wall that look onto open floor."""
    open_below = np.zeros_like(layout.wall)
    open_below[:-1, :] = ~layout.wall[1:, :] & ~layout.outside[1:, :]
    capped = layout.footprint & ((layout.kind == CLASS_CAP) | (layout.kind == CLASS_CAP_EDGE))
    return capped & open_below & (layout.face_px >= FACE_PX)


def _wall_mount(layout, x, y, faces, reach=96):
    """The nearest full-height south face, in front of which a lantern can hang."""
    found = _nearest(faces, x, y, reach)
    if found is None:
        return None
    row, column = found
    return (column + 0.5, row + 1.0, float(layout.height[row, column]))


def add_point_light(name, position, height, color, power, radius, stretch, mirrored=True):
    data = bpy.data.lights.new(name, "POINT")
    data.energy = power
    data.color = color
    data.shadow_soft_size = radius
    light = bpy.data.objects.new(name, data)
    light.location = world_point(position[0], position[1], height, stretch)
    light.visible_glossy = mirrored
    bpy.context.scene.collection.objects.link(light)
    return light


# ---------------------------------------------------------------- props
#
# Props are built in game px and stretched like the hall, so a gear lying on
# the floor reads round on screen exactly as the floor does. Everything stays
# inside the walls' on-screen outline: hung on a south face, or sunk in a
# gallery no taller than its rim.


def _prop(name, shape, material, location, stretch):
    mesh = bpy.data.meshes.new(name)
    shape.to_mesh(mesh)
    shape.free()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.scale = (1.0, stretch, 1.0)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _box(name, centre, size, material, stretch):
    shape = bmesh.new()
    bmesh.ops.create_cube(shape, size=1.0,
                          matrix=Matrix.Diagonal((size[0] * PX, size[1] * PX, size[2] * PX, 1.0)))
    return _prop(name, shape, material, world_point(*centre, stretch), stretch)


def _cylinder(shape, radius, depth, segments=16, matrix=None, tip_radius=None):
    bmesh.ops.create_cone(shape, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius * PX, radius2=(radius if tip_radius is None else tip_radius) * PX,
                          depth=depth * PX, matrix=matrix if matrix is not None else Matrix.Identity(4))


def _material(name, build):
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        nodes, links = _nodes(material)
        build(nodes, links)
    return material


def _iron_material():
    return _material("LanternIron", lambda nodes, links: _principled(
        nodes, links, (0.04, 0.035, 0.035), roughness=0.45, metallic=0.9))


def _glow_material(name, color, strength, base):
    return _material(name, lambda nodes, links: _principled(
        nodes, links, base, roughness=0.3, emission=color, emission_strength=strength))


def _lantern_glass():
    def build(nodes, links):
        shader = _principled(nodes, links, (1.0, 0.78, 0.52), roughness=0.22,
                             emission=(1.0, 0.5, 0.18), emission_strength=1.4)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.45
    return _material("LanternGlass", build)


def _metal(name, color, roughness):
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        tarnish = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=45.0, detail=6.0),
                        0.42, 0.72)
        base = _mix(nodes, links, tarnish, color, tuple(channel * 0.42 for channel in color))
        _principled(nodes, links, base, roughness=roughness, metallic=1.0)
    return _material(name, build)


def _gear_material(name, color):
    """Brass with dark spoke windows, laid out on the gear's own bounding box."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        separate = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Generated"], separate.inputs[0])
        gx = op("SUBTRACT", separate.outputs["X"], 0.5)
        gy = op("SUBTRACT", separate.outputs["Y"], 0.5)
        radius = op("MULTIPLY", op("SQRT", op("ADD", op("MULTIPLY", gx, gx), op("MULTIPLY", gy, gy))), 2.0)
        spoke = op("FRACT", op("DIVIDE", op("ADD", op("ARCTAN2", gy, gx), math.pi), 2.0 * math.pi / 5.0))
        window = op("MULTIPLY", op.between(radius, 0.34, 0.6), op.between(spoke, 0.16, 0.84))
        tarnish = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=45.0, detail=6.0),
                        0.42, 0.72)
        base = _mix(nodes, links, tarnish, color, tuple(channel * 0.45 for channel in color))
        base = _mix(nodes, links, window, base, (0.012, 0.01, 0.014))
        shader = _principled(nodes, links, base, roughness=0.38)
        links.new(op("MULTIPLY", op("SUBTRACT", 1.0, window), 0.8), shader.inputs["Metallic"])
    return _material(name, build)


def add_lantern(name, mount, stretch):
    """An iron wall lantern: arm, roof, posts, glass and a flame lighting it from inside."""
    x, face_y, wall_height = mount
    z = wall_height * 0.6
    y = face_y + 4.5
    iron = _iron_material()
    _box(name + "Arm", (x, face_y + 2.2, z + 6.2), (1.0, 4.4, 1.0), iron, stretch)
    _box(name + "Roof", (x, y, z + 4.1), (5.4, 5.4, 1.3), iron, stretch)
    _box(name + "Base", (x, y, z - 3.9), (4.8, 4.8, 1.0), iron, stretch)
    for offset in (-2.1, 2.1):
        _box(name + "Post", (x + offset, y + 2.1, z), (0.6, 0.6, 7.2), iron, stretch)
    glass = _box(name + "Glass", (x, y, z), (4.0, 4.0, 6.8), _lantern_glass(), stretch)
    shape = bmesh.new()
    bmesh.ops.create_uvsphere(shape, u_segments=10, v_segments=8, radius=1.0 * PX,
                              matrix=Matrix.Diagonal((1.0, 1.0, 1.9, 1.0)))
    flame = _prop(name + "Flame", shape, _glow_material("LanternFlame", (1.0, 0.8, 0.45), 24.0, (1.0, 0.8, 0.5)),
                  world_point(x, y, z - 0.8, stretch), stretch)
    # The light sits inside: glass and flame must not shadow it.
    glass.visible_shadow = False
    flame.visible_shadow = False
    add_point_light(name, (x, y), z, (1.0, 0.6, 0.28), 3.6, 0.012, stretch)


def add_lamps(layout, meta, stretch):
    x0, y0, width, height = meta["region"]
    violet = (0.62, 0.42, 1.0)
    clear = _clear_floor(layout)
    faces = _south_faces(layout)
    lanterns = [
        ("LampWest", (92.0, 852.0)), ("LampCentre", (440.0, 828.0)), ("LampNorth", (712.0, 860.0)),
        ("LampSpawn", (307.0, 1024.0)), ("LampHallway", (566.0, 960.0)), ("LampGallery", (740.0, 1088.0)),
        ("LampEast", (979.0, 980.0)), ("LampSouth", (874.0, 1236.0)),
    ]
    mounts = []
    for name, (x, y) in lanterns:
        if not (x0 - MARGIN_PX <= x <= x0 + width + MARGIN_PX and y0 - MARGIN_PX <= y <= y0 + height + MARGIN_PX):
            continue
        mount = _wall_mount(layout, x, y, faces)
        if mount is None or any(abs(mount[0] - other[0]) < 24 and abs(mount[1] - other[1]) < 24
                                for other in mounts):
            continue
        mounts.append(mount)
        add_lantern(name, mount, stretch)
        # A dim fill where the old lamp hung keeps the corridor readable.
        # A dim pool on the floor below keeps the corridor readable.
        add_point_light(name + "Fill", nearest_floor(layout, x, y + 24.0, clear), LAMP_HEIGHT_PX,
                        (1.0, 0.66, 0.36), 1.0, 0.2, stretch, mirrored=False)
    add_point_light("GlowCentre", nearest_floor(layout, 420.0, 880.0, clear), LAMP_HEIGHT_PX, violet, 1.6,
                    0.1, stretch, mirrored=False)
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    if door is not None and layout.gate_face_y is not None:
        face_y = layout.gate_face_y
        for side in (-1.0, 1.0):
            add_point_light("GateLantern", (door[0] + side * 30.0, face_y + 14.0), 46.0,
                            (1.0, 0.64, 0.3), 1.6, 0.04, stretch, mirrored=False)
        add_point_light("GateKeystone", (door[0], face_y + 10.0), 78.0, violet, 1.2, 0.03, stretch,
                        mirrored=False)
    print("LANTERNS %d" % len(mounts))
    return mounts


def _in_view(meta, left, top, right, bottom):
    x0, y0, width, height = meta["region"]
    return not (left > x0 + width + MARGIN_PX or right < x0 - MARGIN_PX
                or top > y0 + height + MARGIN_PX or bottom < y0 - MARGIN_PX)


def add_gallery_machinery(layout, meta, stretch):
    """Brass works in the sunken galleries: pipe runs, gears and shadow crystals."""
    rng = np.random.default_rng(SEED)
    brass = _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3)
    iron = _iron_material()
    gears = (_gear_material("GearBrass", (0.64, 0.46, 0.2)), _gear_material("GearCopper", (0.6, 0.31, 0.17)))
    crystal = _glow_material("ShadowCrystal", (0.5, 0.26, 1.0), 0.7, (0.16, 0.05, 0.36))
    room = PIT_SCREEN_PX / layout.sin_alpha - 1.5
    counts = {"pipes": 0, "gears": 0, "crystals": 0}
    for number, gallery in enumerate(layout.galleries):
        top, left, mask = gallery["top"], gallery["left"], gallery["mask"]
        rows, columns = mask.shape
        if not _in_view(meta, left, top, left + columns, top + rows):
            continue
        floor = layout.height[top:top + rows, left:left + columns]
        clearance = _clearance(mask, 24)
        used = np.zeros_like(mask)
        horizontal = columns >= rows
        lanes = clearance if horizontal else clearance.T
        lanes_used = used if horizontal else used.T
        for pipe in range(2):
            best = None
            for lane in range(lanes.shape[0]):
                if lanes_used[max(lane - 6, 0):lane + 7].any():
                    continue
                starts, ends = _runs(lanes[lane] >= 5)
                if len(starts) == 0:
                    continue
                longest = int(np.argmax(ends - starts))
                length = int(ends[longest] - starts[longest])
                if best is None or length > best[0]:
                    best = (length, lane, int(starts[longest]), int(ends[longest]))
            if best is None or best[0] < 24:
                break
            length, lane, start, end = best
            lanes_used[max(lane - 6, 0):lane + 7, start:end] = True
            if horizontal:
                a = (left + start + 1.0, top + lane + 0.5)
                b = (left + end - 1.0, top + lane + 0.5)
                base = float(floor[lane, start:end].min())
            else:
                a = (left + lane + 0.5, top + start + 1.0)
                b = (left + lane + 0.5, top + end - 1.0)
                base = float(floor[start:end, lane].min())
            add_pipe("Pipe%d_%d" % (number, pipe), a, b, base + 2.6, 2.4, brass, iron, stretch)
            counts["pipes"] += 1
        for gear in range(4):
            free = np.where(used, 0, clearance)
            row, column = np.unravel_index(int(np.argmax(free)), free.shape)
            radius = min((free[row, column] - 1) * 0.9 - 1.5, 15.0)
            if radius < 5.0:
                break
            radius *= rng.uniform(0.78, 1.0)
            add_gear("Gear%d_%d" % (number, gear), left + column + 0.5, top + row + 0.5,
                     float(floor[row, column]) + 0.6, radius, 2.4, rng.uniform(0.0, 2.0 * math.pi),
                     gears[int(rng.random() < 0.35)], stretch)
            yy, xx = np.ogrid[:rows, :columns]
            used |= (yy - row) ** 2 + (xx - column) ** 2 <= (radius + 3.0) ** 2
            counts["gears"] += 1
        free = np.where(used, 0, clearance)
        row, column = np.unravel_index(int(np.argmax(free)), free.shape)
        if free[row, column] >= 6:
            add_crystals("Crystal%d" % number, left + column + 0.5, top + row + 0.5,
                         float(floor[row, column]), room, crystal, rng, stretch)
            counts["crystals"] += 1
    print("MACHINERY pipes=%(pipes)d gears=%(gears)d crystal clusters=%(crystals)d" % counts)


def add_pipe(name, start, end, z, radius, material, flange_material, stretch):
    """A pipe lying on the gallery floor between two plan points, flanged along its run."""
    (x0, y0), (x1, y1) = start, end
    along_x = abs(x1 - x0) >= abs(y1 - y0)
    length = abs(x1 - x0) if along_x else abs(y1 - y0)
    turn = Matrix.Rotation(math.radians(90.0), 4, "Y" if along_x else "X")
    shape = bmesh.new()
    _cylinder(shape, radius, length, matrix=turn)
    _prop(name, shape, material, world_point((x0 + x1) / 2.0, (y0 + y1) / 2.0, z, stretch), stretch)
    flanges = bmesh.new()
    count = max(int(length // 18.0), 1)
    for index in range(count + 1):
        offset = -length / 2.0 + length * index / count
        shift = Vector((offset * PX, 0.0, 0.0)) if along_x else Vector((0.0, -offset * PX, 0.0))
        _cylinder(flanges, radius * 1.4, 1.8, matrix=Matrix.Translation(shift) @ turn)
    _prop(name + "Flanges", flanges, flange_material,
          world_point((x0 + x1) / 2.0, (y0 + y1) / 2.0, z, stretch), stretch)


def add_gear(name, x, y, z, radius, thickness, angle, material, stretch):
    """A flat cog: toothed disc and raised hub, its bottom resting at z."""
    shape = bmesh.new()
    body = radius * 0.82
    teeth = max(8, int(radius * 0.9))
    _cylinder(shape, body, thickness, segments=max(24, teeth * 2))
    tooth_width = 2.0 * math.pi * body / teeth * 0.5
    for index in range(teeth):
        turn = angle + 2.0 * math.pi * index / teeth
        bmesh.ops.create_cube(shape, size=1.0, matrix=(
            Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation(((body + radius * 0.09) * PX, 0.0, 0.0))
            @ Matrix.Diagonal((radius * 0.2 * PX, tooth_width * PX, thickness * 0.94 * PX, 1.0))))
    _cylinder(shape, radius * 0.22, thickness * 1.8, segments=16)
    _prop(name, shape, material, world_point(x, y, z + thickness / 2.0, stretch), stretch)


def add_crystals(name, x, y, z, room, material, rng, stretch):
    """A cluster of violet shards, lit from within, none taller than `room`."""
    shape = bmesh.new()
    for _shard in range(int(rng.integers(4, 7))):
        height = rng.uniform(0.45, 1.0) * room
        radius = rng.uniform(1.0, 1.9)
        tilt = rng.uniform(0.0, 0.45)
        heading = rng.uniform(0.0, 2.0 * math.pi)
        spot = Vector((rng.uniform(-2.5, 2.5) * PX, rng.uniform(-2.5, 2.5) * PX, 0.0))
        lean = Matrix.Rotation(heading, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
        _cylinder(shape, radius, height, segments=6, tip_radius=0.0,
                  matrix=Matrix.Translation(spot) @ lean @ Matrix.Translation((0.0, 0.0, height / 2.0 * PX)))
    shards = _prop(name, shape, material, world_point(x, y, z, stretch), stretch)
    shards.visible_shadow = False
    add_point_light(name + "Light", (x, y), z + room + 12.0, (0.62, 0.4, 1.0), 0.8, 0.03, stretch)


def material_banner(name, cloth, aspect):
    """A hanging banner: swallowtail hem, gold trim and the castle's gear-and-eye sigil."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        separate = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["UV"], separate.inputs[0])
        u, v = separate.outputs["X"], separate.outputs["Y"]
        edge = op("ABSOLUTE", op("SUBTRACT", u, 0.5))
        hem = op("SUBTRACT", v, op("MULTIPLY", op("SUBTRACT", 0.5, edge), 0.34))
        trim = op("MAXIMUM", op("MAXIMUM", op("GREATER_THAN", edge, 0.41), op("LESS_THAN", hem, 0.05)),
                  op("GREATER_THAN", v, 0.94))
        # The sigil is drawn in screen proportions: `aspect` is the banner's
        # on-screen height over its width.
        sx = op("DIVIDE", op("SUBTRACT", u, 0.5), 0.4)
        sy = op("DIVIDE", op("MULTIPLY", op("SUBTRACT", v, 0.6), aspect), 0.4)
        radius = op("SQRT", op("ADD", op("MULTIPLY", sx, sx), op("MULTIPLY", sy, sy)))
        teeth = op("GREATER_THAN", op("COSINE", op("MULTIPLY", op("ARCTAN2", sy, sx), 8.0)), 0.2)
        gear = op("MAXIMUM", op.between(radius, 0.72, 0.9), op("MULTIPLY", op.between(radius, 0.9, 1.06), teeth))

        def almond(half_width, half_height):
            bulge = op("SUBTRACT", 1.0, op("MULTIPLY", op("DIVIDE", sx, half_width), op("DIVIDE", sx, half_width)))
            return op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", sy), op("MULTIPLY", bulge, half_height)),
                      op("LESS_THAN", op("ABSOLUTE", sx), half_width))

        eye = op("SUBTRACT", almond(0.58, 0.36), almond(0.44, 0.22))
        pupil = op("LESS_THAN", radius, 0.15)
        gold = op("MAXIMUM", op("MAXIMUM", trim, gear), op("MAXIMUM", eye, 0.0))
        folds = op("ADD", 0.72, op("MULTIPLY", 0.28, op("SINE", op("MULTIPLY", u, 2.0 * math.pi * 2.5))))
        weave = _noise(nodes, links, coords.outputs["UV"], scale=70.0, detail=2.0)
        fabric = _mix(nodes, links, weave, cloth, tuple(channel * 0.6 for channel in cloth))
        color = _mix(nodes, links, op("SUBTRACT", 1.0, folds), fabric, (0.0, 0.0, 0.0))
        color = _mix(nodes, links, gold, color, (0.66, 0.48, 0.2))
        shader = _principled(nodes, links, color, roughness=op("SUBTRACT", 0.88, op("MULTIPLY", gold, 0.55)))
        links.new(gold, shader.inputs["Metallic"])
        shader.inputs["Emission Color"].default_value = (0.62, 0.38, 1.0, 1.0)
        links.new(op("MULTIPLY", pupil, 5.0), shader.inputs["Emission Strength"])
        output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        cut = nodes.new("ShaderNodeMixShader")
        links.new(op("GREATER_THAN", hem, 0.0), cut.inputs["Fac"])
        links.new(transparent.outputs["BSDF"], cut.inputs[1])
        links.new(shader.outputs["BSDF"], cut.inputs[2])
        links.new(cut.outputs["Shader"], output.inputs["Surface"])
    return _material(name, build)


BANNER_WIDTH_PX = 16.0
BANNER_DROP_PX = 30.0
BANNER_MIN_FACE_PX = 40
BANNER_CLOTHS = (("BannerViolet", (0.2, 0.06, 0.34)), ("BannerTeal", (0.03, 0.15, 0.19)))


def add_banner(name, x, face_y, wall_height, sin_alpha, stretch, material):
    top = wall_height * 0.84
    bottom = top - BANNER_DROP_PX / sin_alpha
    y = face_y + 0.8
    half = BANNER_WIDTH_PX / 2.0
    corners = [(x - half, y, bottom), (x + half, y, bottom), (x + half, y, top), (x - half, y, top)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(world_point(*corner, stretch)) for corner in corners], [], [(0, 1, 2, 3)])
    layer = mesh.uv_layers.new(name="UVMap")
    for loop, uv in zip(layer.data, ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))):
        loop.uv = uv
    mesh.materials.append(material)
    bpy.context.scene.collection.objects.link(bpy.data.objects.new(name, mesh))
    _box(name + "Rod", (x, face_y + 1.2, top + 0.8), (BANNER_WIDTH_PX + 3.0, 1.2, 1.2),
         _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3), stretch)


def add_banners(layout, meta, stretch, mounts):
    """Banners on the long south faces, clear of lanterns, the gate and each other."""
    x0, y0, width, height = meta["region"]
    faces = _south_faces(layout)
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    segments = []
    for row in range(y0, min(y0 + height, layout.rows)):
        starts, ends = _runs(faces[row, x0:x0 + width])
        for start, end in zip(starts, ends):
            if end - start >= BANNER_MIN_FACE_PX:
                segments.append((int(end - start), row, x0 + int(start), x0 + int(end)))
    segments.sort(reverse=True)
    aspect = BANNER_DROP_PX / BANNER_WIDTH_PX
    placed = []
    margin = BANNER_WIDTH_PX / 2.0 + 4.0
    for length, row, start, end in segments:
        face_y = row + 1.0
        wanted = 2 if length >= 160 else 1
        centre = (start + end) / 2.0
        spots = sorted(np.arange(start + margin, end - margin + 0.1, 4.0), key=lambda spot: abs(spot - centre))
        for x in spots:
            if wanted == 0:
                break
            if door is not None and abs(x - door[0]) < 90 and abs(face_y - door[1]) < 60:
                continue
            if any(abs(x - mount[0]) < 34 and abs(face_y - mount[1]) < 30 for mount in mounts):
                continue
            if any(abs(x - other[0]) < 80 and abs(face_y - other[1]) < 40 for other in placed):
                continue
            wanted -= 1
            cloth_name, cloth = BANNER_CLOTHS[len(placed) % len(BANNER_CLOTHS)]
            add_banner("Banner%d" % len(placed), x, face_y, float(layout.height[row, int(x)]),
                       layout.sin_alpha, stretch, material_banner(cloth_name, cloth, aspect))
            placed.append((x, face_y))
    print("BANNERS %d" % len(placed))


def _decal(name, corners_px, uv_px, material, stretch, z=0.15):
    """A flat floor decal; UVs in game px so its pattern keeps a fixed scale."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(world_point(x, y, z, stretch)) for x, y in corners_px], [], [(0, 1, 2, 3)])
    layer = mesh.uv_layers.new(name="UVMap")
    for loop, uv in zip(layer.data, uv_px):
        loop.uv = uv
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj["floor_decal"] = True
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _uv_parts(nodes, links):
    coords = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["UV"], separate.inputs[0])
    return coords, separate.outputs["X"], separate.outputs["Y"]


def material_rug(name, length, width):
    """A worn runner: fringed ends, ochre border, diamond field, a trodden centre."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        to_end = op("MINIMUM", u, op("SUBTRACT", length, u))
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        fringe = op("LESS_THAN", to_end, 3.0)
        threads = op("LESS_THAN", op("FRACT", op("DIVIDE", v, 1.6)), 0.55)
        border = op("MAXIMUM", op("LESS_THAN", to_side, 3.5), op("LESS_THAN", to_end, 6.5))
        pinstripe = op("MAXIMUM", op.between(to_side, 4.6, 5.6),
                       op("MULTIPLY", op.between(to_end, 7.6, 8.6), op("GREATER_THAN", to_side, 4.6)))
        diamond = op("ADD", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", u, 9.0)), 0.5)),
                     op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("SUBTRACT", v, width / 2.0), 9.0)), 0.5)))
        motif = op("LESS_THAN", diamond, 0.2)
        weave = _noise(nodes, links, coords.outputs["UV"], scale=0.9, detail=6.0)
        wear = _ramp(nodes, links, op("ADD", weave, op("MULTIPLY", op("SUBTRACT", 0.5, op("DIVIDE", op("ABSOLUTE",
                     op("SUBTRACT", v, width / 2.0)), width)), 0.6)), 0.55, 0.9)
        color = _mix(nodes, links, motif, (0.13, 0.022, 0.035), (0.21, 0.05, 0.045))
        color = _mix(nodes, links, op("MAXIMUM", border, pinstripe), color, (0.27, 0.18, 0.07))
        color = _mix(nodes, links, op("MULTIPLY", wear, 0.75), color, (0.11, 0.075, 0.07))
        color = _mix(nodes, links, fringe, color, (0.3, 0.26, 0.2))
        color = _mix(nodes, links, 1.0, color, op("ADD", 0.7, op("MULTIPLY", weave, 0.5)), blend="MULTIPLY")
        bump = _bump(nodes, links, weave, strength=0.25, distance=0.002)
        shader = _principled(nodes, links, color, roughness=0.95, normal=bump)
        output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
        cut = nodes.new("ShaderNodeMixShader")
        links.new(op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0, threads))), cut.inputs["Fac"])
        links.new(nodes.new("ShaderNodeBsdfTransparent").outputs["BSDF"], cut.inputs[1])
        links.new(shader.outputs["BSDF"], cut.inputs[2])
        links.new(cut.outputs["Shader"], output.inputs["Surface"])
    return _material(name, build)


def add_runner_rug(layout, start, end, stretch, widest=20, margin=5, inset=10):
    """A runner down a straight leg of the opening route, as wide as the corridor allows."""
    (x0, y0), (x1, y1) = start, end
    along_x = abs(x1 - x0) >= abs(y1 - y0)
    low, high = (min(x0, x1), max(x0, x1)) if along_x else (min(y0, y1), max(y0, y1))
    low, high = low + inset, high - inset
    centre = y0 if along_x else x0
    open_floor = ~layout.wall & ~layout.outside
    half = 0
    for candidate in range(widest, 7, -1):
        across = slice(int(centre - candidate - margin), int(centre + candidate + margin))
        span = slice(int(low), int(high))
        window = open_floor[across, span] if along_x else open_floor[span, across]
        if window.all():
            half = candidate
            break
    if not half:
        print("RUG skipped: corridor too narrow")
        return
    length = high - low
    if along_x:
        corners = [(low, centre + half), (high, centre + half), (high, centre - half), (low, centre - half)]
    else:
        corners = [(centre - half, high), (centre - half, low), (centre + half, low), (centre + half, high)]
    uvs = [(0.0, 0.0), (length, 0.0), (length, 2.0 * half), (0.0, 2.0 * half)]
    _decal("RunnerRug", corners, uvs, material_rug("RunnerRug", length, 2.0 * half), stretch)
    print("RUG %.0fx%d from (%.0f, %.0f) to (%.0f, %.0f)" % (length, 2 * half, x0, y0, x1, y1))


def material_grate(name, length, width):
    """An iron floor grate; violet light rises through the gaps from below."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        to_edge = op("MINIMUM", op("MINIMUM", u, op("SUBTRACT", length, u)),
                     op("MINIMUM", v, op("SUBTRACT", width, v)))
        frame = op("LESS_THAN", to_edge, 2.0)
        bars = op("LESS_THAN", op("FRACT", op("DIVIDE", u, 3.0)), 0.6)
        iron = op("MAXIMUM", frame, bars)
        depth = op("SUBTRACT", 1.0, op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0))
        color = _mix(nodes, links, iron, (0.02, 0.012, 0.035), (0.05, 0.045, 0.05))
        shader = _principled(nodes, links, color, roughness=op("ADD", 0.35, op("MULTIPLY", iron, 0.2)))
        links.new(op("MULTIPLY", iron, 0.85), shader.inputs["Metallic"])
        shader.inputs["Emission Color"].default_value = (0.55, 0.3, 1.0, 1.0)
        links.new(op("MULTIPLY", op("SUBTRACT", 1.0, iron), op("MULTIPLY", depth, 0.8)),
                  shader.inputs["Emission Strength"])
    return _material(name, build)


def quiet_spots(layout, meta, count, room_px, avoid):
    """Open floor well off the opening route and away from `avoid` points."""
    x0, y0, width, height = meta["region"]
    window = (slice(y0, y0 + height), slice(x0, x0 + width))
    room = _clearance(~layout.wall[window] & ~layout.outside[window], room_px + 2)
    rows, columns = np.nonzero(room >= room_px)
    points = np.column_stack((x0 + columns + 0.5, y0 + rows + 0.5))
    route = np.asarray(meta.get("opening_route") or [], dtype=np.float64)
    off_route = np.full(len(points), 1e9)
    for a, b in zip(route[:-1], route[1:]):
        segment = b - a
        t = np.clip(((points - a) @ segment) / max(segment @ segment, 1e-9), 0.0, 1.0)
        off_route = np.minimum(off_route, np.hypot(*(points - (a + t[:, None] * segment)).T))
    chosen = []
    for _ in range(count):
        clear_of = np.full(len(points), 400.0)
        for other in list(avoid) + chosen:
            clear_of = np.minimum(clear_of, np.hypot(points[:, 0] - other[0], points[:, 1] - other[1]))
        score = np.minimum(off_route, 120.0) + 0.5 * np.minimum(clear_of, 160.0)
        score[clear_of < 120.0] = -1.0
        if len(score) == 0 or score.max() <= 0.0:
            break
        chosen.append(tuple(points[int(np.argmax(score))]))
    return chosen


def add_floor_grates(layout, meta, stretch, avoid, count=2, length=24.0, width=14.0):
    for index, (x, y) in enumerate(quiet_spots(layout, meta, count, int(length / 2) + 6, avoid)):
        corners = [(x - length / 2, y + width / 2), (x + length / 2, y + width / 2),
                   (x + length / 2, y - width / 2), (x - length / 2, y - width / 2)]
        uvs = [(0.0, 0.0), (length, 0.0), (length, width), (0.0, width)]
        _decal("FloorGrate%d" % index, corners, uvs, material_grate("FloorGrate", length, width), stretch)
        add_point_light("FloorGrate%dGlow" % index, (x, y), 4.0, (0.6, 0.38, 1.0), 0.35, 0.06, stretch,
                        mirrored=False)
        print("GRATE at (%.0f, %.0f)" % (x, y))


def find_inlay_spot(layout, near, reach=150, largest=46.0, smallest=22.0):
    """Open floor near the arrival with room for the compass inlay."""
    if not near:
        return None
    x, y = near
    margin = int(largest * 2)
    row_lo, row_hi = max(int(y) - reach - margin, 0), min(int(y) + reach + margin, layout.rows)
    column_lo, column_hi = max(int(x) - reach - margin, 0), min(int(x) + reach + margin, layout.columns)
    window = (slice(row_lo, row_hi), slice(column_lo, column_hi))
    room = _clearance(~layout.wall[window] & ~layout.outside[window], int(largest) + 12)
    rows, columns = np.mgrid[row_lo:row_hi, column_lo:column_hi]
    distance = np.hypot(columns + 0.5 - x, rows + 0.5 - y)
    radius = np.minimum((room - 1) * 0.9 - 4.0, largest)
    score = np.where(distance > reach, -1e9, radius - 0.12 * distance)
    best = np.unravel_index(int(np.argmax(score)), score.shape)
    if radius[best] < smallest:
        return None
    spot = (column_lo + best[1] + 0.5, row_lo + best[0] + 0.5, float(radius[best]))
    print("INLAY at (%.0f, %.0f) radius %.0f" % spot)
    return spot


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
    window = (slice(y0, y0 + region_h), slice(x0, x0 + region_w))
    block = np.ones((factor, factor), dtype=bool)
    target = np.kron(layout.wall[window], block)
    collision = np.kron(layout.collision[window], block)
    pockets = np.kron(layout.pockets[window], block)
    iou = np.logical_and(seen, target).sum() / max(np.logical_or(seen, target).sum(), 1)
    extra = seen & ~collision
    missing = collision & ~seen
    reach = (SMOOTH_TOLERANCE_PX + 1) * factor
    far_extra = extra & ~pockets & ~_dilate(collision, reach)
    far_missing = missing & ~_dilate(seen, reach)
    print("SILHOUETTE vs smoothed outline iou=%.5f; vs collision extra_px=%d (pockets %d) missing_px=%d; "
          "beyond %d game px: extra=%d missing=%d (render %dx%d, %d px per game px)" % (
              iou, extra.sum(), np.logical_and(extra, pockets).sum(), missing.sum(),
              SMOOTH_TOLERANCE_PX + 1, far_extra.sum(), far_missing.sum(), width, height, factor))
    diff = np.zeros((height, width, 4), dtype=np.float32)
    diff[..., 3] = 1.0
    diff[np.logical_and(seen, collision)] = (0.35, 0.35, 0.40, 1.0)
    diff[extra] = (0.55, 0.16, 0.16, 1.0)
    diff[missing] = (0.16, 0.36, 0.6, 1.0)
    diff[far_extra] = (1.0, 0.2, 0.2, 1.0)
    diff[far_missing] = (0.2, 0.6, 1.0, 1.0)
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
    collision = load_mask(os.path.join(data, "wall_mask.png"))
    outside = load_mask(os.path.join(data, "outside_mask.png"))
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    started = time.time()
    layout = Layout(collision, outside, door, math.sin(alpha))
    inlay = find_inlay_spot(layout, meta.get("spawn"))
    print("LAYOUT built in %.1fs" % (time.time() - started))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    x0, y0, width, height = meta["region"]
    crop = (
        max(y0 - MARGIN_PX, 0), min(y0 + height + MARGIN_PX, layout.rows),
        max(x0 - MARGIN_PX, 0), min(x0 + width + MARGIN_PX, layout.columns),
    )
    hall = build_geometry(layout, crop, stretch)
    door_x = (door[0] if door is not None else 0.0) * PX
    textures = TextureSet(options["textures"] or os.path.join(data, "textures"))
    for material in make_materials(door_x, math.sin(alpha), textures):
        hall.data.materials.append(material)
    if inlay is not None:
        add_compass_inlay(inlay, stretch)
    route = meta.get("opening_route") or []
    if len(route) >= 4:
        add_runner_rug(layout, route[1], route[2], stretch)
    setup_world()
    add_sun()
    mounts = add_lamps(layout, meta, stretch)
    add_gallery_machinery(layout, meta, stretch)
    add_banners(layout, meta, stretch, mounts)
    add_floor_grates(layout, meta, stretch, [mount[:2] for mount in mounts] + [tuple(meta.get("spawn", (0, 0)))])
    # Every glow here is decorative: the lanterns and crystals carry point
    # lights. Sampling glowing surfaces as lights would make each floor
    # triangle a light, since the runes drive the floor's emission.
    for material in bpy.data.materials:
        material.cycles.emission_sampling = "NONE"
    add_camera(meta, alpha, stretch, options["scale"])
    setup_cycles(options["samples"], options["preview"])
    if options["save_blend"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(options["save_blend"]))
    render_to(options["out"])
    if options["silhouette"]:
        # Floor quads would fill the outline; hide them by giving the silhouette
        # pass a walls-only copy. Props stay: they must fit inside the outline.
        walls_only = hall.copy()
        walls_only.data = hall.data.copy()
        walls_only.name = "HallWallsOnly"
        bpy.context.scene.collection.objects.link(walls_only)
        hall.hide_render = True
        for obj in bpy.context.scene.objects:
            if obj.get("floor_decal"):
                obj.hide_render = True
        mesh = walls_only.data
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
