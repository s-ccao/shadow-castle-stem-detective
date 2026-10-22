"""Blender 3D prototype of the Castle Hall, rendered as a 2D game image.

Usage (Blender 5.2, from the project root):

    blender -b --factory-startup -P tools/blender/hall_prototype.py -- \
        --data prototypes/blender_hall --out prototypes/blender_hall/render.png \
        [--samples 128] [--scale 2] [--silhouette path.png] [--save-blend path]

Inputs come from tools/blender/export_hall_region.gd: the real wall collision
(wall_mask.png), the floor outside the castle (outside_mask.png) and
region.json. Beside the render it writes <out>-glows.json: the lanterns,
candles, crystals and other glows the playable preview animates.

Projection. The camera is orthographic and tilted ALPHA_DEGREES from looking
straight down. The scene's Y axis is stretched by 1/cos(ALPHA), so the floor
lands 1:1 on game coordinates and a height z shows as z*sin(ALPHA) screen px.

Gameplay. Walls stand on the collision: every wall px is the base of a
block FACE_PX tall on screen, so movement, doors and the Guardian are
unchanged, and a wall's top rises above its base the way a real wall's would.
A character north of a wall is behind it; <out>-depth.png gives, per screen
px, how far south the wall seen there stands, and the preview hides the part
of a character the wall covers. The collision is a 4 px raster whose
diagonals are stairs; the walls follow a smoothed copy within 2 px of it.
"""

import json
import math
import os
import struct
import sys
import time
import zlib

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
# Wall height on screen, and so how much floor behind a wall its top covers.
# The user found 24 px walls too low beside a 66 px figure; at 40 px beside a
# 50 px figure they read as walls. The feet stay in view on 74% of the opening
# route, and the preview shows whatever a wall hides as a faint ghost.
FACE_PX = 40
PLAYER_BODY_PX = (14, 8)
# A prop that stands inside a wall mass gets a floor-level niche this deep.
ALCOVE_DEPTH_PX = 18
# The Wake Room stair: half width, how far south of the door it runs, and
# its treads.
STAIR_HALF_WIDTH_PX = 15
STAIR_RUN_PX = 40
STAIR_TREAD_PX = 6
STAIR_DROP_PX = 3
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

CLASS_FLOOR, CLASS_CAP, CLASS_FACE, CLASS_PIT, CLASS_PIT_WALL, CLASS_GATE, CLASS_CAP_EDGE, CLASS_STAIRS = range(8)
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
    """Per-px heights (game px of 3D height) and material classes.

    Every wall px is the base of a block FACE_PX tall on screen: the collision
    is where the walls stand, and their tops rise above it. Standing north of
    a wall, a character is behind it, and the depth map lets the preview hide
    the part of them the wall's top covers.
    """

    def __init__(self, collision, outside, sin_alpha, spawn=None, door_center=None, alcoves=()):
        self.collision = collision
        filled, self.filled_pockets = self._fill_pockets(collision, outside)
        self.pockets = filled & ~collision
        smooth = self._smooth(filled)
        self.unreachable = self._enclosed_floor(smooth, outside, spawn)
        self.wall = smooth | self.unreachable
        self.outside = outside & ~self.wall
        self.rows, self.columns = self.wall.shape
        self.sin_alpha = sin_alpha
        self.footprint = self.wall.copy()
        self.height = np.where(self.wall, FACE_PX / sin_alpha, 0.0)
        self.face_px = np.where(self.wall, FACE_PX, 0).astype(np.int32)
        self.kind = np.where(self.wall, CLASS_CAP, CLASS_FLOOR).astype(np.int8)
        self.pit = np.zeros(self.wall.shape, dtype=bool)
        self.carved = np.zeros(self.wall.shape, dtype=bool)
        self.gate_face_y = None
        self.gate_runs = {}
        self.galleries = []
        self.stairs = None
        self._galleries()
        self._cap_edges()
        for rect in alcoves:
            self._carve_alcove(rect)
        if door_center is not None:
            self._cut_stairs(door_center)

    @staticmethod
    def _enclosed_floor(wall, outside, spawn, step=2):
        """Floor no player can reach and no reachable floor touches.

        The old art drew walled-off strips as floor. Seen past a wall, they
        read as somewhere the player should be able to go, so they are drawn
        as castle mass instead.
        """
        if spawn is None:
            return np.zeros_like(wall)
        rows, columns = wall.shape
        cell_rows, cell_columns = rows // step, columns // step
        solid = (wall | outside)[:cell_rows * step, :cell_columns * step]
        solid = solid.reshape(cell_rows, step, cell_columns, step).any(axis=(1, 3))
        up, half = PLAYER_BODY_PX[1] // step, PLAYER_BODY_PX[0] // (2 * step)
        row = np.arange(cell_rows)[:, None]
        column = np.arange(cell_columns)[None, :]
        left = np.clip(column - half, 0, cell_columns)
        right = np.clip(column + half + 1, 0, cell_columns)

        def box_sum(mask, top, bottom):
            table = np.pad(mask.astype(np.int32).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
            return table[bottom, right] - table[top, right] - table[bottom, left] + table[top, left]

        # Feet cells whose 14 x 8 px body, above the feet, is clear.
        valid = box_sum(solid, np.clip(row - up, 0, cell_rows), np.clip(row + 1, 0, cell_rows)) == 0
        seed = (int(spawn[1]) // step, int(spawn[0]) // step)
        reach = np.zeros_like(valid)
        reach[seed] = valid[seed]
        frontier = reach.copy()
        while frontier.any():
            grown = np.zeros_like(frontier)
            grown[1:] |= frontier[:-1]
            grown[:-1] |= frontier[1:]
            grown[:, 1:] |= frontier[:, :-1]
            grown[:, :-1] |= frontier[:, 1:]
            grown &= valid & ~reach
            reach |= grown
            frontier = grown
        # Floor some reachable body covers: a reachable feet cell within
        # rows r..r+up and columns c-half..c+half.
        covered = box_sum(reach, np.clip(row, 0, cell_rows), np.clip(row + up + 1, 0, cell_rows)) > 0
        covered_px = np.zeros_like(wall)
        covered_px[:cell_rows * step, :cell_columns * step] = np.kron(covered, np.ones((step, step), dtype=bool))
        floor = ~wall & ~outside
        unreached = floor & ~covered_px
        labels, _sizes = _flood_labels(unreached)
        touching = np.unique(labels[_dilate(covered_px & floor, 1) & unreached])
        enclosed = (labels > 0) & ~np.isin(labels, touching)
        print("ENCLOSED floor drawn as wall: %d px" % int(enclosed.sum()))
        return enclosed

    def _carve_alcove(self, rect, margin=3):
        """A floor-level niche in the wall for a prop that stands inside the mass."""
        x, y, width, height = rect
        feet = int(round(y + height))
        rows = slice(max(feet - ALCOVE_DEPTH_PX, 0), min(feet + 1, self.rows))
        columns = slice(max(int(x) - margin, 0), min(int(math.ceil(x + width)) + margin, self.columns))
        inside = self.wall[rows, columns] & self.footprint[rows, columns]
        self.height[rows, columns][inside] = 0.0
        self.kind[rows, columns][inside] = CLASS_FLOOR
        self.footprint[rows, columns][inside] = False
        self.carved[rows, columns][inside] = True
        print("ALCOVE %d px under the prop at (%.0f, %.0f)" % (int(inside.sum()), x, y))

    def _cut_stairs(self, door):
        """The Wake Room door, seen from the side the player stands on.

        The player reaches the door from the north, and a north-facing door
        is invisible to this camera. So the way back reads as a stair that
        drops south through the wall and runs under the mass beyond it.
        """
        door_x, door_y = int(door[0]), int(door[1])

        def north_edge(column):
            above = self.wall[:door_y + 1, column]
            if not above[door_y]:
                return None
            open_rows = np.flatnonzero(~above)
            return int(open_rows[-1]) + 1 if len(open_rows) else 0

        top = north_edge(door_x)
        if top is None:
            return
        columns = [door_x]
        for direction in (-1, 1):
            column = door_x + direction
            while abs(column - door_x) <= STAIR_HALF_WIDTH_PX:
                edge = north_edge(column)
                if edge is None or abs(edge - top) > 6:
                    break
                columns.append(column)
                column += direction
        columns.sort()
        bottom = min(door_y + STAIR_RUN_PX, self.rows)
        for column in columns:
            for row in range(north_edge(column), bottom):
                if not self.wall[row, column]:
                    continue
                step = 1 + max(row - top, 0) // STAIR_TREAD_PX
                self.height[row, column] = -step * STAIR_DROP_PX / self.sin_alpha
                self.kind[row, column] = CLASS_STAIRS
                self.footprint[row, column] = False
                self.carved[row, column] = True
        self.stairs = {"left": columns[0], "right": columns[-1] + 1, "top": top, "bottom": bottom}
        print("STAIRS x %d-%d from y %d" % (columns[0], columns[-1] + 1, top))

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
    # Only the hall's own stone occludes: floor decals and props hovering
    # above the stone must not darken it in squares.
    ao.only_local = True
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


def material_cap_textured(textures, lit=True):
    material = bpy.data.materials.new("WallCapLip" if lit else "WallTopDark")
    nodes, links = _nodes(material)
    maps = textures.sample(nodes, links, "large_grey_tiles", repeat=0.75)
    if lit:
        color = _grade(nodes, links, maps["diff"], 0.95, (0.88, 0.84, 0.86))
    else:
        color = _grade(nodes, links, maps["diff"], 0.46, (0.62, 0.58, 0.72), saturation=0.6)
        coords = nodes.new("ShaderNodeTexCoord")
        moss = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=2.2, detail=6.0), 0.56, 0.68)
        speckle = _noise(nodes, links, coords.outputs["Object"], scale=40.0, detail=3.0)
        green = _mix(nodes, links, speckle, (0.02, 0.05, 0.018), (0.06, 0.11, 0.035))
        color = _mix(nodes, links, moss, color, green)
        cracks = nodes.new("ShaderNodeTexVoronoi")
        cracks.feature = "DISTANCE_TO_EDGE"
        cracks.inputs["Scale"].default_value = 2.2
        links.new(coords.outputs["Object"], cracks.inputs["Vector"])
        # Only some cell edges crack: a broken network, not a tiled grid.
        broken = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=5.0, detail=3.0), 0.5, 0.62)
        crack = nodes.new("ShaderNodeMath")
        crack.operation = "MULTIPLY"
        links.new(_ramp(nodes, links, cracks.outputs["Distance"], 0.014, 0.0), crack.inputs[0])
        links.new(broken, crack.inputs[1])
        color = _mix(nodes, links, crack.outputs[0], color, (0.008, 0.006, 0.01))
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


def material_stairs(textures=None):
    """Worn treads dropping toward the Wake Room's violet light."""
    material = bpy.data.materials.new("WakeStairs")
    nodes, links = _nodes(material)
    if textures is not None and textures.available():
        maps = textures.sample(nodes, links, "large_grey_tiles", repeat=0.75)
        color = _grade(nodes, links, maps["diff"], 0.4, (0.8, 0.76, 0.84))
        roughness, normal = maps["rough"], maps["normal"]
    else:
        color, roughness, normal = (0.2, 0.19, 0.2), 0.8, None
    op = _MathBuilder(nodes, links)
    coords = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], separate.inputs[0])
    deep = op("MINIMUM", op("MAXIMUM", op("DIVIDE", separate.outputs["Z"], -0.4), 0.0), 1.0)
    shader = _principled(nodes, links, color, roughness=roughness, normal=normal)
    shader.inputs["Emission Color"].default_value = (0.55, 0.3, 1.0, 1.0)
    links.new(op("MULTIPLY", op("POWER", deep, 1.5), 0.7), shader.inputs["Emission Strength"])
    return material


def make_materials(door_x, sin_alpha, textures=None):
    full_height = FACE_PX / sin_alpha * PX
    gate_height = GATE_FACE_PX / sin_alpha * PX
    if textures is not None and textures.available():
        print("MATERIALS CC0 photo textures from", textures.directory)
        return [material_floor_textured(textures), material_cap_textured(textures, lit=False),
                material_face_textured(textures, full_height), material_pit_textured(textures),
                material_pit_wall(), material_gate(door_x, sin_alpha, gate_height, textures),
                material_cap_textured(textures, lit=True), material_stairs(textures)]
    print("MATERIALS procedural")
    return [material_floor(), material_cap(), material_face(full_height), material_pit(),
            material_pit_wall(), material_gate(door_x, sin_alpha, gate_height), material_cap(), material_stairs()]


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
    up = 1.0 / SIN_ALPHA
    iron = _iron_material()
    _box(name + "Arm", (x, face_y + 2.2, z + 8.2 * up), (1.0, 4.4, 1.0 * up), iron, stretch)
    _box(name + "Roof", (x, y, z + 4.0 * up), (5.4, 5.4, 1.3 * up), iron, stretch)
    _box(name + "Base", (x, y, z - 3.9 * up), (4.8, 4.8, 1.0 * up), iron, stretch)
    for offset in (-2.1, 2.1):
        _box(name + "Post", (x + offset, y + 2.1, z), (0.6, 0.6, 7.2 * up), iron, stretch)
    glass = _box(name + "Glass", (x, y, z), (4.0, 4.0, 6.8 * up), _lantern_glass(), stretch)
    shape = bmesh.new()
    bmesh.ops.create_uvsphere(shape, u_segments=10, v_segments=8, radius=1.0 * PX,
                              matrix=Matrix.Diagonal((1.0, 1.0, 1.6 * up, 1.0)))
    flame = _prop(name + "Flame", shape, _glow_material("LanternFlame", (1.0, 0.8, 0.45), 24.0, (1.0, 0.8, 0.5)),
                  world_point(x, y, z - 0.8 * up, stretch), stretch)
    # The light sits inside: glass and flame must not shadow it.
    glass.visible_shadow = False
    flame.visible_shadow = False
    add_point_light(name, (x, y), z, (1.0, 0.6, 0.28), 3.6, 0.012, stretch)
    _glow("lantern", x, y, z, (1.0, 0.62, 0.3), 26.0)


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
        # The gate's painted lanterns and keystone, in screen px above the door's foot.
        for side in (-1.0, 1.0):
            _glow("lantern", door[0] + side * (DOOR_HALF_WIDTH_PX + 12.0), face_y, 30.0 / SIN_ALPHA,
                  (1.0, 0.64, 0.3), 14.0)
        _glow("crystal", door[0], face_y, (DOOR_SPRING_PX * 0.6 + DOOR_HALF_WIDTH_PX + 3.0) / SIN_ALPHA,
              violet, 10.0)
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
    _glow("crystal", x, y, z + room * 0.5, (0.62, 0.4, 1.0), 16.0)


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


BANNER_WIDTH_PX = 14.0
BANNER_DROP_PX = 28.0
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
    return placed


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
        _glow("grate", x, y, 0.0, (0.6, 0.38, 1.0), 18.0)
        print("GRATE at (%.0f, %.0f)" % (x, y))


# ---------------------------------------------------------------- wall dressing
#
# Everything here hangs on a full-height south face, the side of a wall the
# camera sees, so it stays inside the wall's outline on screen. Positions are
# (x along the face, face_y = the face's foot, z = height up the face).

SIN_ALPHA = math.sin(math.radians(ALPHA_DEGREES))
# The camera shows heights at sin(alpha). Things hung on a face are drawn in
# screen proportions, as the gate's arch is, so a clock reads round.
UPRIGHT = Matrix.Diagonal((1.0, 1.0, 1.0 / SIN_ALPHA, 1.0))
# Glows the playable preview animates over the render: lantern and candle
# flicker, crystal and grate pulses. Screen-space game px.
GLOWS = []


def _glow(kind, x, plan_y, z, color, radius):
    GLOWS.append({"kind": kind, "x": round(float(x), 2), "y": round(float(plan_y - z * SIN_ALPHA), 2),
                  "color": [round(float(channel), 3) for channel in color], "radius": float(radius)})


def _face_plane(name, x, face_y, z0, z1, width, material, stretch, out=0.3, uvs=None):
    """A flat panel just in front of a south face, UVs 0..1 unless given."""
    half = width / 2.0
    y = face_y + out
    corners = [(x - half, y, z0), (x + half, y, z0), (x + half, y, z1), (x - half, y, z1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(world_point(*corner, stretch)) for corner in corners], [], [(0, 1, 2, 3)])
    layer = mesh.uv_layers.new(name="UVMap")
    for loop, uv in zip(layer.data, uvs or ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))):
        loop.uv = uv
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _frame(name, x, face_y, z0, z1, width, bar, depth, material, stretch):
    """Four bars around a panel `width` wide spanning z0..z1."""
    height = z1 - z0
    bar_z = bar / SIN_ALPHA
    centre_z = (z0 + z1) / 2.0
    y = face_y + depth / 2.0
    _box(name + "Top", (x, y, z1 + bar_z / 2.0), (width + 2.0 * bar, depth, bar_z), material, stretch)
    _box(name + "Bottom", (x, y, z0 - bar_z / 2.0), (width + 2.0 * bar, depth, bar_z), material, stretch)
    for side in (-1.0, 1.0):
        _box(name + "Side", (x + side * (width + bar) / 2.0, y, centre_z), (bar, depth, height), material, stretch)


def _alpha_cut(nodes, links, shader, keep):
    """Route the material through a transparent mix: `keep` 1 shows the surface."""
    output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
    cut = nodes.new("ShaderNodeMixShader")
    links.new(keep, cut.inputs["Fac"])
    links.new(nodes.new("ShaderNodeBsdfTransparent").outputs["BSDF"], cut.inputs[1])
    links.new(shader.outputs["BSDF"], cut.inputs[2])
    links.new(cut.outputs["Shader"], output.inputs["Surface"])


def _wood():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexWave")
        grain.wave_type = "BANDS"
        grain.bands_direction = "X"
        grain.inputs["Scale"].default_value = 30.0
        grain.inputs["Distortion"].default_value = 6.0
        grain.inputs["Detail"].default_value = 3.0
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        color = _mix(nodes, links, grain.outputs["Fac"], (0.07, 0.035, 0.02), (0.16, 0.085, 0.045))
        _principled(nodes, links, color, roughness=0.62)
    return _material("DarkOak", build)


def material_portrait(name, coat):
    """A darkened oil portrait: head and shoulders, cracked varnish, eyes that catch the light."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)

        def ellipse(centre_u, centre_v, radius_u, radius_v):
            du = op("DIVIDE", op("SUBTRACT", u, centre_u), radius_u)
            dv = op("DIVIDE", op("SUBTRACT", v, centre_v), radius_v)
            return op("LESS_THAN", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)), 1.0)

        head = ellipse(0.5, 0.56, 0.22, 0.2)
        hair = op("MULTIPLY", ellipse(0.5, 0.62, 0.25, 0.2), op("GREATER_THAN", v, 0.6))
        shoulders = ellipse(0.5, 0.02, 0.46, 0.36)
        collar = op("MULTIPLY", op.between(v, 0.24, 0.38),
                    op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", u, 0.5)), op("MULTIPLY", op("SUBTRACT", 0.4, v), 0.9)))
        eyes = op("MAXIMUM", ellipse(0.43, 0.55, 0.035, 0.022), ellipse(0.57, 0.55, 0.035, 0.022))
        light = op("ADD", 0.55, op("MULTIPLY", u, 0.7))
        background = _mix(nodes, links, v, (0.02, 0.018, 0.014), (0.075, 0.065, 0.045))
        color = _mix(nodes, links, shoulders, background, coat)
        color = _mix(nodes, links, collar, color, (0.42, 0.4, 0.34))
        color = _mix(nodes, links, op("MULTIPLY", head, op("SUBTRACT", 1.0, hair)), color, (0.36, 0.27, 0.21))
        color = _mix(nodes, links, hair, color, (0.05, 0.035, 0.025))
        color = _mix(nodes, links, op("MULTIPLY", head, op("SUBTRACT", 1.0, op("MINIMUM", light, 1.0))), color,
                     (0.06, 0.045, 0.035))
        color = _mix(nodes, links, eyes, color, (0.02, 0.01, 0.012))
        cracks = nodes.new("ShaderNodeTexVoronoi")
        cracks.feature = "DISTANCE_TO_EDGE"
        cracks.inputs["Scale"].default_value = 26.0
        links.new(coords.outputs["UV"], cracks.inputs["Vector"])
        color = _mix(nodes, links, op("MULTIPLY", op("LESS_THAN", cracks.outputs["Distance"], 0.025), 0.45), color,
                     (0.0, 0.0, 0.0))
        shader = _principled(nodes, links, color, roughness=0.34)
        shader.inputs["Emission Color"].default_value = (1.0, 0.25, 0.32, 1.0)
        links.new(op("MULTIPLY", eyes, 1.6), shader.inputs["Emission Strength"])
    return _material(name, build)


PORTRAIT_COATS = ((0.05, 0.08, 0.06), (0.11, 0.03, 0.04), (0.04, 0.05, 0.1))


def add_portrait(name, x, face_y, wall_height, stretch, rng):
    width, screen_height = 13.0, 17.0
    centre = wall_height * 0.52
    half = screen_height / SIN_ALPHA / 2.0
    coat = PORTRAIT_COATS[int(rng.integers(len(PORTRAIT_COATS)))]
    _face_plane(name, x, face_y, centre - half, centre + half, width,
                material_portrait("Portrait%d" % PORTRAIT_COATS.index(coat), coat), stretch, out=0.9)
    _frame(name + "Frame", x, face_y, centre - half, centre + half, width, 1.8, 1.6,
           _metal("GiltFrame", (0.62, 0.46, 0.18), 0.32), stretch)
    _glow("eyes", x, face_y + 0.9, centre + (0.55 - 0.5) * 2.0 * half, (1.0, 0.3, 0.38), 5.0)


def material_niche():
    """A round-headed alcove: dark recess, pale stone surround, soot above."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        across = op("ABSOLUTE", op("SUBTRACT", u, 0.5))
        aspect = 20.0 / 14.0

        def arch(half_width, spring):
            dv = op("MULTIPLY", op("SUBTRACT", v, spring), aspect)
            rounded = op("LESS_THAN", op("ADD", op("MULTIPLY", across, across), op("MULTIPLY", dv, dv)),
                         half_width * half_width)
            return op("MAXIMUM", op("MULTIPLY", op("LESS_THAN", across, half_width), op("LESS_THAN", v, spring)),
                      rounded)

        recess = op("MULTIPLY", arch(0.31, 0.56), op("GREATER_THAN", v, 0.1))
        surround = op("MAXIMUM", arch(0.46, 0.56), op("MULTIPLY", op("LESS_THAN", v, 0.1),
                                                       op("LESS_THAN", across, 0.5)))
        soot = op("MULTIPLY", recess, op("MULTIPLY", v, 0.8))
        stone = _mix(nodes, links, op("MULTIPLY", v, 0.6), (0.3, 0.28, 0.27), (0.12, 0.1, 0.1))
        color = _mix(nodes, links, recess, stone, (0.03, 0.022, 0.02))
        color = _mix(nodes, links, soot, color, (0.006, 0.005, 0.005))
        shader = _principled(nodes, links, color, roughness=0.85)
        _alpha_cut(nodes, links, shader, surround)
    return _material("CandleNiche", build)


def add_candle_niche(name, x, face_y, wall_height, stretch, rng):
    width, screen_height = 14.0, 20.0
    bottom = wall_height * 0.2
    top = bottom + screen_height / SIN_ALPHA
    _face_plane(name, x, face_y, bottom, top, width, material_niche(), stretch, out=0.25)
    sill = bottom + 0.1 * (top - bottom)
    _box(name + "Sill", (x, face_y + 1.3, sill - 0.6), (width - 2.0, 2.6, 1.2),
         _material("NicheSill", lambda nodes, links: _principled(nodes, links, (0.26, 0.24, 0.23), roughness=0.8)),
         stretch)
    wax = _material("CandleWax", lambda nodes, links: _principled(nodes, links, (0.8, 0.73, 0.58), roughness=0.5))
    flame = _glow_material("CandleFlame", (1.0, 0.72, 0.32), 18.0, (1.0, 0.8, 0.5))
    for offset, tall in ((-2.4, rng.uniform(3.0, 4.5)), (0.0, rng.uniform(6.0, 8.0)), (2.2, rng.uniform(2.5, 4.0))):
        shape = bmesh.new()
        _cylinder(shape, 0.8, tall, segments=10)
        _prop(name + "Candle", shape, wax, world_point(x + offset, face_y + 1.4, sill + tall / 2.0, stretch), stretch)
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=8, v_segments=6, radius=0.5 * PX,
                                  matrix=Matrix.Diagonal((1.0, 1.0, 1.8 / SIN_ALPHA, 1.0)))
        tip = _prop(name + "Flame", shape, flame, world_point(x + offset, face_y + 1.4, sill + tall + 0.9, stretch),
                    stretch)
        tip.visible_shadow = False
        _glow("candle", x + offset, face_y + 1.4, sill + tall + 0.9, (1.0, 0.68, 0.32), 8.0)
    add_point_light(name + "Light", (x, face_y + 2.4), sill + 7.0, (1.0, 0.62, 0.3), 0.45, 0.01, stretch)


def _book_material():
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        info = nodes.new("ShaderNodeObjectInfo")
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        palette = ((0.2, 0.035, 0.045), (0.05, 0.07, 0.16), (0.06, 0.13, 0.07), (0.32, 0.22, 0.07),
                   (0.17, 0.1, 0.06), (0.22, 0.19, 0.15))
        elements = ramp.color_ramp.elements
        while len(elements) < len(palette):
            elements.new(0.5)
        for index, (element, color) in enumerate(zip(elements, palette)):
            element.position = index / len(palette)
            element.color = color + (1.0,)
        links.new(info.outputs["Random"], ramp.inputs["Fac"])
        coords = nodes.new("ShaderNodeTexCoord")
        separate = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Generated"], separate.inputs[0])
        bands = op("MAXIMUM", op.between(separate.outputs["Z"], 0.8, 0.85), op.between(separate.outputs["Z"], 0.14, 0.18))
        color = _mix(nodes, links, bands, ramp.outputs["Color"], (0.6, 0.45, 0.18))
        shader = _principled(nodes, links, color, roughness=op("SUBTRACT", 0.75, op("MULTIPLY", bands, 0.4)))
        links.new(bands, shader.inputs["Metallic"])
    return _material("BookCloth", build)


def _flask_glass():
    def build(nodes, links):
        shader = _principled(nodes, links, (0.85, 0.9, 0.88), roughness=0.05)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.47
    return _material("FlaskGlass", build)


POTIONS = (("PotionGreen", (0.25, 1.0, 0.45)), ("PotionViolet", (0.62, 0.32, 1.0)), ("PotionAmber", (1.0, 0.55, 0.15)))


def add_bookshelf(name, x, face_y, wall_height, stretch, rng):
    width = 28.0
    shelf = wall_height * 0.42
    wood = _wood()
    _box(name + "Plank", (x, face_y + 1.9, shelf - 0.6), (width, 3.8, 1.2), wood, stretch)
    for side in (-1.0, 1.0):
        _box(name + "Bracket", (x + side * (width / 2.0 - 3.0), face_y + 1.2, shelf - 2.8), (0.9, 2.4, 3.2),
             _iron_material(), stretch)
    books = _book_material()
    cursor = x - width / 2.0 + 0.8
    end = x + width / 2.0 - 7.5
    while cursor < end:
        thick = float(rng.uniform(1.1, 2.2))
        if rng.random() < 0.08:
            cursor += 1.4
            continue
        tall = float(rng.uniform(7.0, 11.5))
        deep = float(rng.uniform(2.3, 3.2))
        lean = float(rng.uniform(-0.3, 0.3)) if rng.random() < 0.12 else 0.0
        shape = bmesh.new()
        bmesh.ops.create_cube(shape, size=1.0, matrix=(
            Matrix.Rotation(lean, 4, "Y") @ Matrix.Translation((0.0, 0.0, tall / 2.0 * PX))
            @ Matrix.Diagonal((thick * PX, deep * PX, tall * PX, 1.0))))
        _prop(name + "Book", shape, books, world_point(cursor + thick / 2.0, face_y + deep / 2.0 + 0.2, shelf, stretch),
              stretch)
        cursor += thick + (abs(lean) * 4.0)
    for index, offset in enumerate((width / 2.0 - 5.2, width / 2.0 - 2.0)[:int(rng.integers(1, 3))]):
        potion_name, potion = POTIONS[int(rng.integers(len(POTIONS)))]
        bulb = 1.5 if index == 0 else 1.15
        centre = (x + offset, face_y + 2.0, shelf + bulb / SIN_ALPHA)
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=12, v_segments=8, radius=bulb * PX, matrix=UPRIGHT)
        _cylinder(shape, 0.45, 2.4, segments=8, matrix=UPRIGHT @ Matrix.Translation((0.0, 0.0, (bulb + 0.9) * PX)))
        glass = _prop(name + "Flask", shape, _flask_glass(), world_point(*centre, stretch), stretch)
        glass.visible_shadow = False
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=10, v_segments=6, radius=bulb * 0.8 * PX, matrix=UPRIGHT)
        _prop(name + "Potion", shape, _glow_material(potion_name, potion, 2.5, tuple(c * 0.4 for c in potion)),
              world_point(*centre, stretch), stretch)
        _glow("potion", centre[0], centre[1], centre[2], potion, 6.0)


def material_chalkboard():
    """Slate with lines of chalk working and a ringed diagram, half rubbed out."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        haze = _noise(nodes, links, coords.outputs["UV"], scale=4.0, detail=4.0)
        writing = None
        for row, (level, seed) in enumerate(((0.8, 1.3), (0.62, 4.1), (0.44, 7.7), (0.26, 2.9))):
            line = op.between(v, level - 0.045, level + 0.045)
            words_input = nodes.new("ShaderNodeCombineXYZ")
            links.new(op("MULTIPLY", u, 9.0), words_input.inputs["X"])
            words_input.inputs["Y"].default_value = seed
            words = op("GREATER_THAN", _noise(nodes, links, words_input.outputs[0], scale=1.0, detail=1.0), 0.47)
            strokes = op("LESS_THAN", op("FRACT", op("MULTIPLY", u, 70.0 + row * 9.0)), 0.45)
            span = op("LESS_THAN", u, 0.62 if row < 3 else 0.5)
            mark = op("MULTIPLY", op("MULTIPLY", line, words), op("MULTIPLY", strokes, span))
            writing = mark if writing is None else op("MAXIMUM", writing, mark)
        aspect = 15.0 / 24.0
        du = op("SUBTRACT", u, 0.8)
        dv = op("DIVIDE", op("SUBTRACT", v, 0.52), aspect)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        diagram = op("MAXIMUM", op.between(radius, 0.105, 0.12), op.between(radius, 0.035, 0.05))
        spoke = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", dv, op("MULTIPLY", du, 0.6))), 0.012),
                   op("LESS_THAN", radius, 0.2))
        chalk = op("MULTIPLY", op("MAXIMUM", op("MAXIMUM", writing, diagram), spoke),
                   op("ADD", 0.45, op("MULTIPLY", haze, 0.6)))
        slate = _mix(nodes, links, op("MULTIPLY", haze, 0.5), (0.025, 0.04, 0.035), (0.07, 0.085, 0.08))
        color = _mix(nodes, links, op("MINIMUM", chalk, 1.0), slate, (0.72, 0.74, 0.7))
        _principled(nodes, links, color, roughness=0.92)
    return _material("Chalkboard", build)


def add_chalkboard(name, x, face_y, wall_height, stretch, rng):
    width, screen_height = 24.0, 15.0
    centre = wall_height * 0.5
    half = screen_height / SIN_ALPHA / 2.0
    _face_plane(name, x, face_y, centre - half, centre + half, width, material_chalkboard(), stretch, out=0.7)
    _frame(name + "Frame", x, face_y, centre - half, centre + half, width, 1.4, 1.3, _wood(), stretch)
    _box(name + "Tray", (x, face_y + 1.6, centre - half - 1.2), (width - 6.0, 2.6, 0.8), _wood(), stretch)


def material_dial(name, kind, needle=0.33):
    """A brass gauge's dial or a clock face, drawn on the disc's own 0..1 UVs."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        du = op("SUBTRACT", u, 0.5)
        dv = op("SUBTRACT", v, 0.5)
        radius = op("MULTIPLY", op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))), 2.0)
        turn = op("DIVIDE", op("ADD", op("ARCTAN2", du, dv), math.pi), 2.0 * math.pi)

        def hand(angle_turns, length, width):
            direction = (math.sin(angle_turns * 2.0 * math.pi), math.cos(angle_turns * 2.0 * math.pi))
            along = op("ADD", op("MULTIPLY", du, direction[0]), op("MULTIPLY", dv, direction[1]))
            across = op("ABSOLUTE", op("SUBTRACT", op("MULTIPLY", du, direction[1]), op("MULTIPLY", dv, direction[0])))
            return op("MULTIPLY", op.between(along, -0.04, length / 2.0), op("LESS_THAN", across, width))

        if kind == "clock":
            ticks = op("MULTIPLY", op.between(radius, 0.72, 0.9),
                       op("LESS_THAN", op("FRACT", op("ADD", op("MULTIPLY", turn, 12.0), 0.06)), 0.12))
            # Eight minutes to midnight.
            hands = op("MAXIMUM", hand((11.0 + 52.0 / 60.0) / 12.0, 0.5, 0.035), hand(52.0 / 60.0, 0.78, 0.02))
            face = (0.66, 0.6, 0.46)
            red = None
        else:
            sweep = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", turn, 0.5)), 0.375)
            ticks = op("MULTIPLY", op("MULTIPLY", op.between(radius, 0.68, 0.86), sweep),
                       op("LESS_THAN", op("FRACT", op("MULTIPLY", turn, 32.0)), 0.18))
            red = op("MULTIPLY", op.between(radius, 0.68, 0.86), op.between(turn, 0.72, 0.875))
            hands = hand(needle, 0.7, 0.025)
            face = (0.72, 0.68, 0.56)
        color = _mix(nodes, links, ticks, face, (0.04, 0.035, 0.03))
        if red is not None:
            color = _mix(nodes, links, red, color, (0.5, 0.06, 0.04))
        color = _mix(nodes, links, hands, color, (0.03, 0.025, 0.02))
        color = _mix(nodes, links, op("LESS_THAN", radius, 0.08), color, (0.5, 0.36, 0.15))
        _principled(nodes, links, color, roughness=0.28)
    return _material(name, build)


def _dial_disc(name, x, y, z, radius, material, stretch):
    shape = bmesh.new()
    shape.loops.layers.uv.new("UVMap")
    bmesh.ops.create_circle(shape, cap_ends=True, cap_tris=False, segments=40, radius=radius * PX,
                            matrix=UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X"), calc_uvs=True)
    return _prop(name, shape, material, world_point(x, y, z, stretch), stretch)


def add_gauge(name, x, face_y, wall_height, stretch, rng):
    brass = _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3)
    pipe = bmesh.new()
    _cylinder(pipe, 1.2, wall_height * 0.86, segments=12)
    _prop(name + "Riser", pipe, brass, world_point(x - 3.0, face_y + 1.4, wall_height * 0.43, stretch), stretch)
    centre = wall_height * 0.5
    turn = UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X")
    body = bmesh.new()
    _cylinder(body, 3.9, 1.6, segments=28, matrix=turn)
    _prop(name + "Body", body, brass, world_point(x + 1.0, face_y + 2.4, centre, stretch), stretch)
    _dial_disc(name + "Dial", x + 1.0, face_y + 3.25, centre, 3.3, material_dial("GaugeDial", "gauge"), stretch)
    wheel = bmesh.new()
    _cylinder(wheel, 2.0, 0.6, segments=16, matrix=turn)
    _prop(name + "Valve", wheel, _metal("ValveRed", (0.45, 0.07, 0.05), 0.4),
          world_point(x - 3.0, face_y + 3.0, wall_height * 0.24, stretch), stretch)


def add_clock(name, x, face_y, wall_height, stretch, rng):
    centre = wall_height * 0.55
    rim = bmesh.new()
    _cylinder(rim, 7.0, 1.8, segments=40, matrix=UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X"))
    _prop(name + "Rim", rim, _metal("GiltFrame", (0.62, 0.46, 0.18), 0.32),
          world_point(x, face_y + 1.0, centre, stretch), stretch)
    _dial_disc(name + "Face", x, face_y + 1.95, centre, 6.0, material_dial("ClockFace", "clock"), stretch)


def material_cobweb(corner_right):
    """Old silk in a corner: radial threads and sagging rings, fading outward."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        du = op("SUBTRACT", 1.0, u) if corner_right else u
        dv = op("SUBTRACT", 1.0, v)
        reach = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        angle = op("DIVIDE", op("ARCTAN2", dv, du), math.pi / 2.0)
        threads = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", angle, 6.0)), 0.5)), 0.035)
        sag = op("MULTIPLY", op("SINE", op("MULTIPLY", angle, math.pi * 6.0)), 0.025)
        rings = op("LESS_THAN", op("FRACT", op("ADD", op("MULTIPLY", reach, 7.0), sag)), 0.07)
        frayed = op("GREATER_THAN", _noise(nodes, links, coords.outputs["UV"], scale=9.0, detail=3.0), 0.42)
        silk = op("MULTIPLY", op("MULTIPLY", op("MAXIMUM", threads, rings), frayed),
                  op("MULTIPLY", op("SUBTRACT", 1.0, op("MINIMUM", reach, 1.0)), 0.9))
        shader = _principled(nodes, links, (0.8, 0.8, 0.82), roughness=0.6)
        _alpha_cut(nodes, links, shader, silk)
    return _material("CobwebRight" if corner_right else "CobwebLeft", build)


def add_cobweb(name, x, face_y, wall_height, corner_right, stretch):
    size = 11.0
    top = wall_height * 0.98
    _face_plane(name, x, face_y, top - size / SIN_ALPHA, top, size, material_cobweb(corner_right), stretch, out=0.4)


CASE_NOTES = (
    # centre x, centre y, width, height (screen px on a 26x16 board), tilt, is_photo
    (5.0, 11.0, 7.0, 5.0, -0.12, False), (13.5, 11.6, 6.0, 6.5, 0.08, True),
    (21.0, 10.6, 7.0, 5.0, 0.15, False), (7.8, 4.4, 7.0, 4.6, 0.1, False),
    (19.2, 4.2, 6.4, 5.0, -0.1, True),
)
CASE_STRINGS = ((0, 1), (1, 2), (1, 4), (3, 1))


def material_caseboard():
    """A detective's cork board: pinned notes and photographs tied by red string."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        x = op("MULTIPLY", u, 26.0)
        y = op("MULTIPLY", v, 16.0)
        speckle = _noise(nodes, links, coords.outputs["UV"], scale=60.0, detail=2.0)
        color = _mix(nodes, links, speckle, (0.2, 0.12, 0.06), (0.36, 0.23, 0.11))
        pins = []
        for centre_x, centre_y, width, height, tilt, photo in CASE_NOTES:
            dx = op("SUBTRACT", x, centre_x)
            dy = op("SUBTRACT", y, centre_y)
            across = op("ADD", op("MULTIPLY", dx, math.cos(tilt)), op("MULTIPLY", dy, math.sin(tilt)))
            along = op("SUBTRACT", op("MULTIPLY", dy, math.cos(tilt)), op("MULTIPLY", dx, math.sin(tilt)))
            inside = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", across), width / 2.0),
                        op("LESS_THAN", op("ABSOLUTE", along), height / 2.0))
            if photo:
                sitter = op("LESS_THAN", op("ADD", op("MULTIPLY", across, across),
                                            op("MULTIPLY", op("ADD", along, 0.4), op("ADD", along, 0.4))), 2.6)
                note = _mix(nodes, links, sitter, (0.1, 0.1, 0.1), (0.42, 0.4, 0.36))
                border = op("GREATER_THAN", op("MAXIMUM", op("SUBTRACT", op("ABSOLUTE", across), width / 2.0 - 0.6),
                                                op("SUBTRACT", op("ABSOLUTE", along), height / 2.0 - 0.6)), 0.0)
                note = _mix(nodes, links, border, note, (0.78, 0.76, 0.7))
            else:
                lines = op("MULTIPLY", op("LESS_THAN", op("FRACT", op("MULTIPLY", along, 1.1)), 0.3),
                           op("LESS_THAN", op("ABSOLUTE", across), width / 2.0 - 1.0))
                note = _mix(nodes, links, lines, (0.74, 0.7, 0.58), (0.32, 0.3, 0.27))
            color = _mix(nodes, links, inside, color, note)
            pins.append((centre_x - math.sin(tilt) * (height / 2.0 - 0.9),
                         centre_y + math.cos(tilt) * (height / 2.0 - 0.9)))
        for first, second in CASE_STRINGS:
            (ax, ay), (bx, by) = pins[first], pins[second]
            length_sq = (bx - ax) ** 2 + (by - ay) ** 2
            t = op("MINIMUM", op("MAXIMUM", op("DIVIDE", op("ADD", op("MULTIPLY", op("SUBTRACT", x, ax), bx - ax),
                                                             op("MULTIPLY", op("SUBTRACT", y, ay), by - ay)),
                                              length_sq), 0.0), 1.0)
            gap_x = op("SUBTRACT", x, op("ADD", ax, op("MULTIPLY", t, bx - ax)))
            gap_y = op("SUBTRACT", y, op("ADD", ay, op("MULTIPLY", t, by - ay)))
            string = op("LESS_THAN", op("ADD", op("MULTIPLY", gap_x, gap_x), op("MULTIPLY", gap_y, gap_y)), 0.12)
            color = _mix(nodes, links, string, color, (0.62, 0.05, 0.04))
        for pin_x, pin_y in pins:
            head = op("LESS_THAN", op("ADD", op("MULTIPLY", op("SUBTRACT", x, pin_x), op("SUBTRACT", x, pin_x)),
                                      op("MULTIPLY", op("SUBTRACT", y, pin_y), op("SUBTRACT", y, pin_y))), 0.36)
            color = _mix(nodes, links, head, color, (0.75, 0.08, 0.06))
        _principled(nodes, links, color, roughness=0.85)
    return _material("CaseBoard", build)


def add_caseboard(name, x, face_y, wall_height, stretch, rng):
    width, screen_height = 26.0, 16.0
    centre = wall_height * 0.5
    half = screen_height / SIN_ALPHA / 2.0
    _face_plane(name, x, face_y, centre - half, centre + half, width, material_caseboard(), stretch, out=0.7)
    _frame(name + "Frame", x, face_y, centre - half, centre + half, width, 1.3, 1.3, _wood(), stretch)


def add_sconce(name, x, face_y, wall_height, stretch, rng):
    """A single candle on an iron wall bracket."""
    up = 1.0 / SIN_ALPHA
    z = wall_height * float(rng.uniform(0.48, 0.6))
    iron = _iron_material()
    _box(name + "Plate", (x, face_y + 0.3, z), (2.4, 0.6, 4.0 * up), iron, stretch)
    _box(name + "Arm", (x, face_y + 1.6, z - 1.4 * up), (0.9, 2.6, 0.8 * up), iron, stretch)
    cup = bmesh.new()
    _cylinder(cup, 1.3, 0.8 * up, segments=10)
    _prop(name + "Cup", cup, iron, world_point(x, face_y + 2.9, z - 1.4 * up, stretch), stretch)
    tall = float(rng.uniform(2.2, 3.6)) * up
    wax = bmesh.new()
    _cylinder(wax, 0.7, tall, segments=8)
    _prop(name + "Candle", wax, _material("CandleWax", lambda n, l: _principled(n, l, (0.8, 0.73, 0.58), roughness=0.5)),
          world_point(x, face_y + 2.9, z - 1.0 * up + tall / 2.0, stretch), stretch)
    tip_z = z - 1.0 * up + tall + 0.9 * up
    flame = bmesh.new()
    bmesh.ops.create_uvsphere(flame, u_segments=8, v_segments=6, radius=0.5 * PX,
                              matrix=Matrix.Diagonal((1.0, 1.0, 1.8 * up, 1.0)))
    tip = _prop(name + "Flame", flame, _glow_material("CandleFlame", (1.0, 0.72, 0.32), 18.0, (1.0, 0.8, 0.5)),
                world_point(x, face_y + 2.9, tip_z, stretch), stretch)
    tip.visible_shadow = False
    add_point_light(name + "Light", (x, face_y + 4.0), tip_z, (1.0, 0.62, 0.3), 0.3, 0.01, stretch)
    _glow("candle", x, face_y + 2.9, tip_z, (1.0, 0.68, 0.32), 7.0)


def _framed(name, x, face_y, wall_height, width, screen_height, centre_ratio, material, frame_material, bar, stretch,
            out=0.7):
    centre = wall_height * centre_ratio
    half = screen_height / SIN_ALPHA / 2.0
    _face_plane(name, x, face_y, centre - half, centre + half, width, material, stretch, out=out)
    if frame_material is not None:
        _frame(name + "Frame", x, face_y, centre - half, centre + half, width, bar, out + 0.6, frame_material, stretch)
    return centre, half


def material_blueprint():
    """A draughtsman's sheet: grid, a gear in elevation, crosshairs and dimensions."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        aspect = 12.0 / 16.0
        grid = op("MAXIMUM", op("LESS_THAN", op("FRACT", op("MULTIPLY", u, 12.0)), 0.05),
                  op("LESS_THAN", op("FRACT", op("MULTIPLY", v, 9.0)), 0.06))
        du = op("SUBTRACT", u, 0.4)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.52), aspect)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        teeth = op("GREATER_THAN", op("COSINE", op("MULTIPLY", op("ARCTAN2", dv, du), 10.0)), 0.2)
        gear = op("MAXIMUM", op("MAXIMUM", op.between(radius, 0.19, 0.205), op.between(radius, 0.05, 0.062)),
                  op("MULTIPLY", op.between(radius, 0.205, 0.25), op("MULTIPLY", teeth, op.between(radius, 0.24, 0.25))))
        teeth_sides = op("MULTIPLY", op.between(radius, 0.205, 0.25),
                         op("LESS_THAN", op("ABSOLUTE", op("COSINE", op("MULTIPLY", op("ARCTAN2", dv, du), 10.0))), 0.25))
        cross = op("MULTIPLY", op("LESS_THAN", radius, 0.31),
                   op("MAXIMUM", op("LESS_THAN", op("ABSOLUTE", du), 0.004), op("LESS_THAN", op("ABSOLUTE", dv), 0.004)))
        dimension = op("MULTIPLY", op.between(v, 0.1, 0.115), op.between(u, 0.15, 0.65))
        box = op("MULTIPLY", op.between(u, 0.7, 0.9), op.between(v, 0.28, 0.76))
        box_edge = op("SUBTRACT", box, op("MULTIPLY", op.between(u, 0.71, 0.89), op.between(v, 0.295, 0.745)))
        lines = op("MAXIMUM", op("MAXIMUM", gear, teeth_sides), op("MAXIMUM", op("MAXIMUM", cross, dimension), box_edge))
        color = _mix(nodes, links, op("MULTIPLY", grid, 0.35), (0.03, 0.08, 0.22), (0.2, 0.32, 0.55))
        color = _mix(nodes, links, op("MINIMUM", lines, 1.0), color, (0.72, 0.8, 0.9))
        _principled(nodes, links, color, roughness=0.82)
    return _material("Blueprint", build)


def add_blueprint(name, x, face_y, wall_height, stretch, rng):
    _framed(name, x, face_y, wall_height, 16.0, 12.0, float(rng.uniform(0.5, 0.58)), material_blueprint(),
            _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3), 1.0, stretch)


def material_map():
    """An old parchment map: coastlines, a dotted route and a red cross."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        stain = _noise(nodes, links, coords.outputs["UV"], scale=5.0, detail=5.0)
        land = _noise(nodes, links, coords.outputs["UV"], scale=3.2, detail=3.0)
        coast = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", land, 0.5)), 0.012)
        path_v = op("ADD", 0.48, op("MULTIPLY", op("SINE", op("MULTIPLY", u, 7.0)), 0.14))
        route = op("MULTIPLY", op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", v, path_v)), 0.02),
                                  op("LESS_THAN", op("FRACT", op("MULTIPLY", u, 22.0)), 0.45)), op.between(u, 0.08, 0.7))
        cross_u = op("SUBTRACT", u, 0.74)
        cross_v = op("MULTIPLY", op("SUBTRACT", v, 0.62), 14.0 / 20.0)
        cross = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", cross_u), 0.045),
                   op("MAXIMUM", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", cross_u, cross_v)), 0.012),
                      op("LESS_THAN", op("ABSOLUTE", op("ADD", cross_u, cross_v)), 0.012)))
        edge = op("MINIMUM", op("MINIMUM", u, op("SUBTRACT", 1.0, u)), op("MINIMUM", v, op("SUBTRACT", 1.0, v)))
        torn = op("GREATER_THAN", edge, op("MULTIPLY", stain, 0.05))
        color = _mix(nodes, links, stain, (0.42, 0.33, 0.2), (0.6, 0.5, 0.33))
        color = _mix(nodes, links, op("LESS_THAN", edge, 0.06), color, (0.3, 0.22, 0.12))
        color = _mix(nodes, links, coast, color, (0.18, 0.12, 0.07))
        color = _mix(nodes, links, route, color, (0.35, 0.1, 0.06))
        color = _mix(nodes, links, cross, color, (0.6, 0.06, 0.04))
        shader = _principled(nodes, links, color, roughness=0.9)
        _alpha_cut(nodes, links, shader, torn)
    return _material("OldMap", build)


def add_map(name, x, face_y, wall_height, stretch, rng):
    centre, half = _framed(name, x, face_y, wall_height, 20.0, 14.0, float(rng.uniform(0.5, 0.56)), material_map(),
                           None, 0.0, stretch, out=0.5)
    brass = _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3)
    for dx in (-8.5, 8.5):
        tack = bmesh.new()
        _cylinder(tack, 0.6, 0.8, segments=8, matrix=UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X"))
        _prop(name + "Tack", tack, brass, world_point(x + dx, face_y + 0.9, centre + half * 0.8, stretch), stretch)


def material_mirror():
    """An oval looking-glass in a gilt frame; something pale stands in it."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        du = op("MULTIPLY", op("SUBTRACT", u, 0.5), 2.0)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.5), 2.0)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        frame = op.between(radius, 0.8, 1.0)
        head = op("LESS_THAN", op("ADD", op("MULTIPLY", op("DIVIDE", du, 0.2), op("DIVIDE", du, 0.2)),
                                  op("MULTIPLY", op("DIVIDE", op("SUBTRACT", dv, 0.12), 0.17),
                                     op("DIVIDE", op("SUBTRACT", dv, 0.12), 0.17))), 1.0)
        body = op("LESS_THAN", op("ADD", op("MULTIPLY", op("DIVIDE", du, 0.42), op("DIVIDE", du, 0.42)),
                                  op("MULTIPLY", op("DIVIDE", op("ADD", dv, 0.62), 0.5),
                                     op("DIVIDE", op("ADD", dv, 0.62), 0.5))), 1.0)
        ghost = op("MULTIPLY", op("MAXIMUM", head, body), op("LESS_THAN", radius, 0.8))
        color = _mix(nodes, links, frame, (0.5, 0.52, 0.56), (0.62, 0.46, 0.18))
        shader = _principled(nodes, links, color, roughness=op("ADD", 0.04, op("MULTIPLY", frame, 0.28)), metallic=1.0)
        shader.inputs["Emission Color"].default_value = (0.62, 0.68, 0.8, 1.0)
        links.new(op("MULTIPLY", ghost, 0.22), shader.inputs["Emission Strength"])
        _alpha_cut(nodes, links, shader, op("LESS_THAN", radius, 1.0))
    return _material("Mirror", build)


def add_mirror(name, x, face_y, wall_height, stretch, rng):
    _framed(name, x, face_y, wall_height, 11.0, 16.0, 0.55, material_mirror(), None, 0.0, stretch, out=0.6)


def material_tapestry():
    """A woven star chart: constellations and a crescent on deep blue, gold border, fringed hem."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        aspect = 28.0 / 20.0
        border = op("MAXIMUM", op("MAXIMUM", op("LESS_THAN", u, 0.06), op("GREATER_THAN", u, 0.94)),
                    op("MAXIMUM", op("GREATER_THAN", v, 0.95), op.between(v, 0.08, 0.12)))
        fringe = op("LESS_THAN", v, 0.08)
        threads = op("LESS_THAN", op("FRACT", op("MULTIPLY", u, 30.0)), 0.5)
        sky = op("MULTIPLY", u, 1.0)
        stars = nodes.new("ShaderNodeTexVoronoi")
        stars.inputs["Scale"].default_value = 9.0
        star_coords = nodes.new("ShaderNodeCombineXYZ")
        links.new(sky, star_coords.inputs["X"])
        links.new(op("MULTIPLY", v, aspect), star_coords.inputs["Y"])
        links.new(star_coords.outputs[0], stars.inputs["Vector"])
        star = op("LESS_THAN", stars.outputs["Distance"], 0.07)
        points = ((0.25, 0.7), (0.38, 0.78), (0.5, 0.66), (0.62, 0.72), (0.35, 0.42), (0.55, 0.36))
        lines = None
        for (ax, ay), (bx, by) in zip(points[:-1], points[1:]):
            t = op("MINIMUM", op("MAXIMUM", op("DIVIDE", op("ADD", op("MULTIPLY", op("SUBTRACT", u, ax), bx - ax),
                                                            op("MULTIPLY", op("MULTIPLY", op("SUBTRACT", v, ay), by - ay),
                                                               aspect * aspect)),
                                             (bx - ax) ** 2 + ((by - ay) * aspect) ** 2), 0.0), 1.0)
            gx = op("SUBTRACT", u, op("ADD", ax, op("MULTIPLY", t, bx - ax)))
            gy = op("MULTIPLY", op("SUBTRACT", v, op("ADD", ay, op("MULTIPLY", t, by - ay))), aspect)
            segment = op("LESS_THAN", op("ADD", op("MULTIPLY", gx, gx), op("MULTIPLY", gy, gy)), 0.00012)
            lines = segment if lines is None else op("MAXIMUM", lines, segment)
        mu = op("SUBTRACT", u, 0.72)
        mv = op("MULTIPLY", op("SUBTRACT", v, 0.84), aspect)
        moon = op("MULTIPLY", op("LESS_THAN", op("ADD", op("MULTIPLY", mu, mu), op("MULTIPLY", mv, mv)), 0.006),
                  op("GREATER_THAN", op("ADD", op("MULTIPLY", op("SUBTRACT", mu, 0.03), op("SUBTRACT", mu, 0.03)),
                                         op("MULTIPLY", op("SUBTRACT", mv, 0.02), op("SUBTRACT", mv, 0.02))), 0.005))
        weave = _noise(nodes, links, coords.outputs["UV"], scale=80.0, detail=2.0)
        color = _mix(nodes, links, weave, (0.018, 0.025, 0.07), (0.04, 0.05, 0.12))
        color = _mix(nodes, links, op("MAXIMUM", op("MAXIMUM", star, lines), moon), color, (0.7, 0.6, 0.32))
        color = _mix(nodes, links, border, color, (0.5, 0.36, 0.13))
        color = _mix(nodes, links, fringe, color, (0.45, 0.35, 0.16))
        shader = _principled(nodes, links, color, roughness=0.9)
        _alpha_cut(nodes, links, shader, op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0, threads))))
    return _material("StarTapestry", build)


def add_tapestry(name, x, face_y, wall_height, stretch, rng):
    width, drop = 20.0, 28.0
    top = wall_height * 0.84
    _face_plane(name, x, face_y, top - drop / SIN_ALPHA, top, width, material_tapestry(), stretch, out=0.8)
    _box(name + "Rod", (x, face_y + 1.2, top + 0.8), (width + 3.0, 1.2, 1.2),
         _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3), stretch)


def material_rift():
    """A crack in the stone with violet light seeping through it."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        wander_in = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("MULTIPLY", v, 3.0), wander_in.inputs["X"])
        wander_in.inputs["Y"].default_value = 2.7
        wander = _noise(nodes, links, wander_in.outputs[0], scale=1.0, detail=6.0)
        centre = op("ADD", 0.5, op("MULTIPLY", op("SUBTRACT", wander, 0.5), 0.9))
        taper = op("MULTIPLY", op("SUBTRACT", 1.0, op("ABSOLUTE", op("SUBTRACT", op("MULTIPLY", v, 2.0), 1.0))), 0.07)
        gap = op("ABSOLUTE", op("SUBTRACT", u, centre))
        crack = op("LESS_THAN", gap, taper)
        core = op("LESS_THAN", gap, op("MULTIPLY", taper, 0.45))
        soot = op("MULTIPLY", op("LESS_THAN", gap, op("ADD", taper, 0.08)), 0.55)
        color = _mix(nodes, links, crack, (0.03, 0.02, 0.03), (0.01, 0.005, 0.015))
        shader = _principled(nodes, links, color, roughness=0.9)
        shader.inputs["Emission Color"].default_value = (0.6, 0.32, 1.0, 1.0)
        links.new(op("MULTIPLY", core, 3.0), shader.inputs["Emission Strength"])
        _alpha_cut(nodes, links, shader, op("MAXIMUM", crack, soot))
    return _material("Rift", build)


def add_rift(name, x, face_y, wall_height, stretch, rng):
    centre, half = _framed(name, x, face_y, wall_height, 10.0, 24.0, 0.48, material_rift(), None, 0.0, stretch,
                           out=0.25)
    _glow("crystal", x, face_y, centre, (0.62, 0.36, 1.0), 9.0)


DECOR = {
    "shelf": (30.0, add_bookshelf), "portrait": (17.0, add_portrait), "niche": (14.0, add_candle_niche),
    "chalkboard": (27.0, add_chalkboard), "clock": (16.0, add_clock), "gauge": (11.0, add_gauge),
    "caseboard": (29.0, add_caseboard), "sconce": (7.0, add_sconce), "blueprint": (19.0, add_blueprint),
    "map": (22.0, add_map), "mirror": (13.0, add_mirror), "tapestry": (23.0, add_tapestry), "rift": (12.0, add_rift),
}
# Wide gaps take the pieces that tell the castle's story; narrow gaps the small ones.
DECOR_BIG = ("caseboard", "shelf", "tapestry", "chalkboard", "map", "portrait", "shelf", "blueprint", "tapestry",
             "clock")
DECOR_SMALL = ("niche", "portrait", "sconce", "mirror", "gauge", "blueprint", "rift", "clock", "niche", "sconce")
DECOR_CAPS = {"caseboard": 2, "shelf": 4, "tapestry": 3, "chalkboard": 2, "map": 2, "portrait": 5, "blueprint": 3,
              "clock": 3, "niche": 8, "sconce": 8, "mirror": 2, "gauge": 4, "rift": 3}
DECOR_SLOT_PX = 30.0
COBWEBS_MAX = 14


def face_segments(layout, meta, minimum=14):
    """Full-height south faces in the region: foot row, x span and wall height."""
    faces = _south_faces(layout)
    x0, y0, width, height = meta["region"]
    segments = []
    for row in range(y0, min(y0 + height, layout.rows)):
        starts, ends = _runs(faces[row, x0:x0 + width])
        for start, end in zip(starts, ends):
            if end - start >= minimum:
                segments.append((float(x0 + start), float(x0 + end), row + 1.0,
                                 float(layout.height[row, x0 + int(start)])))
    return segments


def dress_faces(layout, meta, stretch, taken):
    """Shelves, portraits, alcoves, boards, gauges and a clock in the free stretches
    of the south faces, around the lanterns and banners in `taken` (x, face_y, half width)."""
    rng = np.random.default_rng(SEED + 7)
    door = meta.get("doors", {}).get("WAKE_ROOM_DOOR_FOCUS_POSITION")
    turns = {DECOR_BIG: 0, DECOR_SMALL: 0}
    placed = {kind: 0 for kind in DECOR}
    webs = 0
    for start, end, face_y, wall_height in sorted(face_segments(layout, meta), key=lambda item: item[0] - item[1]):
        if door is not None and abs(face_y - door[1]) < 70 and start < door[0] + 90 and end > door[0] - 90:
            continue
        free = [(start + 3.0, end - 3.0)]
        for x, other_y, half in taken:
            if abs(other_y - face_y) > 3.0:
                continue
            cut = []
            for a, b in free:
                left, right = x - half - 5.0, x + half + 5.0
                if right <= a or left >= b:
                    cut.append((a, b))
                    continue
                if left > a:
                    cut.append((a, left))
                if right < b:
                    cut.append((right, b))
            free = cut
        for a, b in free:
            room = b - a
            slots = max(1, int(room // DECOR_SLOT_PX))
            slot = room / slots
            pool = DECOR_BIG if slot >= 30.0 else DECOR_SMALL
            for index in range(slots):
                fits = [pool[(turns[pool] + step) % len(pool)] for step in range(len(pool))]
                fits = [kind for kind in fits if DECOR[kind][0] <= slot - 3.0 and placed[kind] < DECOR_CAPS[kind]]
                if not fits:
                    continue
                kind = fits[0]
                turns[pool] += 1
                _width, builder = DECOR[kind]
                builder("Decor%s%d" % (kind.title(), placed[kind]), a + (index + 0.5) * slot, face_y, wall_height,
                        stretch, rng)
                placed[kind] += 1
        for corner_right, corner_x in ((False, start), (True, end)):
            near_free = any(a - 4.0 <= corner_x + (-7.0 if corner_right else 7.0) <= b + 4.0 for a, b in free)
            if near_free and webs < COBWEBS_MAX and end - start >= 24.0 and rng.random() < 0.3:
                add_cobweb("Cobweb%d" % webs, corner_x + (-5.5 if corner_right else 5.5), face_y, wall_height,
                           corner_right, stretch)
                webs += 1
    print("DECOR %s cobwebs=%d" % (" ".join("%s=%d" % item for item in placed.items()), webs))


def material_floor_crack(glowing):
    """Cracked flagstone: a jagged split with branches; some leak violet light."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        marks = None
        for seed, (start, end, slope) in enumerate(((0.08, 0.92, 0.0), (0.45, 0.85, 0.7), (0.3, 0.6, -0.9))):
            wander_in = nodes.new("ShaderNodeCombineXYZ")
            links.new(op("MULTIPLY", u, 4.0), wander_in.inputs["X"])
            wander_in.inputs["Y"].default_value = 3.1 + seed * 5.3
            wander = _noise(nodes, links, wander_in.outputs[0], scale=1.0, detail=6.0)
            line_v = op("ADD", op("ADD", 0.5, op("MULTIPLY", op("SUBTRACT", u, 0.5), slope)),
                        op("MULTIPLY", op("SUBTRACT", wander, 0.5), 0.35))
            span = op.between(u, start, end)
            middle = (start + end) / 2.0
            width = op("MULTIPLY", op("SUBTRACT", 1.0, op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", u, middle)),
                                                            (end - start) / 2.0)), 0.014 if seed == 0 else 0.008)
            mark = op("MULTIPLY", span, op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", v, line_v)), width))
            marks = mark if marks is None else op("MAXIMUM", marks, mark)
        shader = _principled(nodes, links, (0.008, 0.006, 0.01), roughness=0.95)
        if glowing:
            shader.inputs["Emission Color"].default_value = (0.58, 0.3, 1.0, 1.0)
            shader.inputs["Emission Strength"].default_value = 0.55
        _alpha_cut(nodes, links, shader, marks)
    return _material("FloorCrackGlow" if glowing else "FloorCrack", build)


def _open_spots(layout, meta, room_px, count, avoid, spacing, rng, near_wall=None, clear_of=None):
    """Spread spots over open floor in the region: `clear_of` px from `avoid`
    (default `spacing`) and `spacing` px from each other."""
    clear_of = spacing if clear_of is None else clear_of
    x0, y0, width, height = meta["region"]
    window = (slice(y0, y0 + height), slice(x0, x0 + width))
    open_floor = ~layout.wall[window] & ~layout.outside[window]
    allowed = _clearance(open_floor, room_px + 1) >= room_px
    if near_wall is not None:
        allowed &= _dilate(layout.wall[window], near_wall) & ~_dilate(layout.wall[window], max(near_wall - 4, 1))
    rows, columns = np.nonzero(allowed)
    order = rng.permutation(len(rows))
    chosen = []
    for index in order:
        point = (x0 + columns[index] + 0.5, y0 + rows[index] + 0.5)
        if any((point[0] - other[0]) ** 2 + (point[1] - other[1]) ** 2 < clear_of ** 2 for other in avoid):
            continue
        if any((point[0] - other[0]) ** 2 + (point[1] - other[1]) ** 2 < spacing ** 2 for other in chosen):
            continue
        chosen.append(point)
        if len(chosen) >= count:
            break
    return chosen


def add_floor_details(layout, meta, stretch, avoid):
    """Cracked flagstones, flush with the floor; a few leak violet light."""
    rng = np.random.default_rng(SEED + 11)
    cracks = _open_spots(layout, meta, 10, 12, avoid, 70.0, rng)
    for index, (x, y) in enumerate(cracks):
        size = float(rng.uniform(18.0, 28.0))
        turn = float(rng.uniform(0.0, math.pi))
        corners = [(x + size / 2.0 * (math.cos(turn) * sx - math.sin(turn) * sy),
                    y + size / 2.0 * (math.sin(turn) * sx + math.cos(turn) * sy))
                   for sx, sy in ((-1.0, 1.0), (1.0, 1.0), (1.0, -1.0), (-1.0, -1.0))]
        glowing = index % 4 == 1
        _decal("FloorCrack%d" % index, corners, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)],
               material_floor_crack(glowing), stretch, z=0.12)
        if glowing:
            _glow("grate", x, y, 0.0, (0.58, 0.3, 1.0), 12.0)
    print("FLOOR cracks=%d" % len(cracks))


# ---------------------------------------------------------------- more life
#
# Flat floor dressing (notes, spills, chalk, loose gears) is walked over, so it
# lies flat and is tagged floor_decal. Candles on the wall tops and ivy on the
# faces stay inside the wall outline and are checked with it.


def _decal_quad(name, x, y, width, length, turn, material, stretch, z=0.14):
    cos_t, sin_t = math.cos(turn), math.sin(turn)
    corners = [(x + (sx * width * cos_t - sy * length * sin_t) / 2.0, y + (sx * width * sin_t + sy * length * cos_t) / 2.0)
               for sx, sy in ((-1.0, 1.0), (1.0, 1.0), (1.0, -1.0), (-1.0, -1.0))]
    return _decal(name, corners, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)], material, stretch, z=z)


def material_note():
    """A dropped page: parchment tone per page, ink lines, a dog-eared corner."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        info = nodes.new("ShaderNodeObjectInfo")
        lines = op("MULTIPLY", op("LESS_THAN", op("FRACT", op("MULTIPLY", v, 7.0)), 0.3),
                   op("MULTIPLY", op.between(u, 0.14, op("ADD", 0.6, op("MULTIPLY", info.outputs["Random"], 0.3))),
                      op.between(v, 0.12, 0.84)))
        corner = op("GREATER_THAN", op("ADD", u, v), 1.78)
        paper = _mix(nodes, links, info.outputs["Random"], (0.62, 0.56, 0.42), (0.78, 0.74, 0.64))
        color = _mix(nodes, links, op("MULTIPLY", lines, 0.8), paper, (0.12, 0.09, 0.08))
        color = _mix(nodes, links, corner, color, (0.42, 0.37, 0.27))
        _principled(nodes, links, color, roughness=0.88)
    return _material("DroppedNote", build)


def material_spill(name, color):
    """Spilled reagent: an irregular glossy pool that glows faintly."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        du = op("MULTIPLY", op("SUBTRACT", u, 0.5), 2.0)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.5), 2.0)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        wobble = _noise(nodes, links, coords.outputs["UV"], scale=3.0, detail=4.0)
        shape = op("LESS_THAN", op("ADD", radius, op("MULTIPLY", op("SUBTRACT", wobble, 0.5), 0.9)), 0.62)
        droplets = op("LESS_THAN", _noise(nodes, links, coords.outputs["UV"], scale=11.0, detail=2.0), 0.3)
        pool = op("MAXIMUM", shape, op("MULTIPLY", droplets, op("LESS_THAN", radius, 0.95)))
        depth = op("SUBTRACT", 1.0, op("MINIMUM", op("DIVIDE", radius, 0.7), 1.0))
        base = _mix(nodes, links, depth, tuple(channel * 0.05 for channel in color),
                    tuple(channel * 0.16 for channel in color))
        shader = _principled(nodes, links, base, roughness=0.04)
        shader.inputs["Emission Color"].default_value = color + (1.0,)
        links.new(op("MULTIPLY", op("POWER", depth, 2.0), 0.9), shader.inputs["Emission Strength"])
        # Thin at the rim: the pool fades into the stone rather than sitting on it.
        _alpha_cut(nodes, links, shader, op("MULTIPLY", pool, op("ADD", 0.55, op("MULTIPLY", depth, 0.45))))
    return _material(name, build)


def material_chalk_diagram():
    """Chalk on the flagstones: a circle, an inscribed triangle, arrows and working."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        aspect = 30.0 / 44.0
        du = op("SUBTRACT", u, 0.32)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.5), aspect)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        circle = op.between(radius, 0.24, 0.255)
        lines = circle
        corners = [(0.32 + 0.245 * math.cos(math.radians(a)), 0.5 + 0.245 * math.sin(math.radians(a)) / aspect)
                   for a in (90.0, 210.0, 330.0)]
        for (ax, ay), (bx, by) in zip(corners, corners[1:] + corners[:1]):
            length = (bx - ax) ** 2 + ((by - ay) * aspect) ** 2
            t = op("MINIMUM", op("MAXIMUM", op("DIVIDE", op("ADD", op("MULTIPLY", op("SUBTRACT", u, ax), bx - ax),
                                                         op("MULTIPLY", op("SUBTRACT", v, ay), (by - ay) * aspect * aspect)),
                                          length), 0.0), 1.0)
            gx = op("SUBTRACT", u, op("ADD", ax, op("MULTIPLY", t, bx - ax)))
            gy = op("MULTIPLY", op("SUBTRACT", v, op("ADD", ay, op("MULTIPLY", t, by - ay))), aspect)
            lines = op("MAXIMUM", lines, op("LESS_THAN", op("ADD", op("MULTIPLY", gx, gx), op("MULTIPLY", gy, gy)),
                                                         0.00006))
        arrow = op("MULTIPLY", op.between(v, 0.49, 0.51), op.between(u, 0.6, 0.78))
        head = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("ABSOLUTE", op("SUBTRACT", v, 0.5)),
                                                                        op("MULTIPLY", op("SUBTRACT", 0.78, u), 1.3))),
                                              0.012), op.between(u, 0.72, 0.78))
        words = None
        for level, seed in ((0.74, 2.3), (0.6, 5.1), (0.4, 8.7)):
            word_in = nodes.new("ShaderNodeCombineXYZ")
            links.new(op("MULTIPLY", u, 14.0), word_in.inputs["X"])
            word_in.inputs["Y"].default_value = seed
            letters = op("MULTIPLY", op("GREATER_THAN", _noise(nodes, links, word_in.outputs[0], scale=1.0, detail=1.0),
                                        0.46), op("LESS_THAN", op("FRACT", op("MULTIPLY", u, 90.0)), 0.5))
            row = op("MULTIPLY", op("MULTIPLY", op.between(v, level - 0.035, level + 0.035), op.between(u, 0.8, 0.97)),
                     letters)
            words = row if words is None else op("MAXIMUM", words, row)
        smudge = _noise(nodes, links, coords.outputs["UV"], scale=6.0, detail=3.0)
        chalk = op("MULTIPLY", op("MAXIMUM", op("MAXIMUM", lines, op("MAXIMUM", arrow, head)), words),
                   op("ADD", 0.15, op("MULTIPLY", smudge, 0.4)))
        shader = _principled(nodes, links, (0.78, 0.8, 0.76), roughness=0.95)
        _alpha_cut(nodes, links, shader, op("MINIMUM", chalk, 1.0))
    return _material("ChalkDiagram", build)


def add_floor_story(layout, meta, stretch, avoid):
    """Notes, spills and chalk working, all flat on the open floor."""
    rng = np.random.default_rng(SEED + 23)
    note = material_note()
    clusters = _open_spots(layout, meta, 12, 9, avoid, 90.0, rng, clear_of=40.0)
    notes = 0
    for cx, cy in clusters:
        for _page in range(int(rng.integers(2, 5))):
            x, y = cx + float(rng.uniform(-9.0, 9.0)), cy + float(rng.uniform(-7.0, 7.0))
            _decal_quad("Note%d" % notes, x, y, 6.0, 8.0, float(rng.uniform(0.0, math.pi)), note, stretch,
                        z=0.14 + notes * 0.002)
            notes += 1
    taken = avoid + clusters
    spills = _open_spots(layout, meta, 14, 3, taken, 220.0, rng, clear_of=45.0)
    for index, (x, y) in enumerate(spills):
        name, color = (("SpillViolet", (0.6, 0.3, 1.0)), ("SpillGreen", (0.25, 1.0, 0.5)))[index % 2]
        size = float(rng.uniform(18.0, 26.0))
        _decal_quad("Spill%d" % index, x, y, size, size * 0.8, float(rng.uniform(0.0, math.pi)),
                    material_spill(name, color), stretch, z=0.13)
        _glow("potion", x, y, 0.0, color, size * 0.7)
    taken = taken + spills
    chalk = _open_spots(layout, meta, 24, 2, taken, 260.0, rng, clear_of=50.0)
    for index, (x, y) in enumerate(chalk):
        _decal_quad("Chalk%d" % index, x, y, 44.0, 30.0, float(rng.uniform(-0.3, 0.3)), material_chalk_diagram(),
                    stretch, z=0.12)
    print("FLOOR STORY notes=%d spills=%d chalk=%d" % (notes, len(spills), len(chalk)))


def add_cap_candles(layout, meta, stretch, count=10):
    """Candles burning on the wall tops, near the camera-facing edge, inside the outline."""
    rng = np.random.default_rng(SEED + 31)
    x0, y0, width, height = meta["region"]
    window = (slice(y0, y0 + height), slice(x0, x0 + width))
    solid = layout.footprint[window] & (layout.kind[window] != CLASS_PIT)
    lip = solid & ~np.roll(solid, -5, axis=0)
    deep = np.zeros_like(solid)
    deep[14:, :] = solid[:-14, :]
    allowed = lip & deep & _erode(solid, 3)
    rows, columns = np.nonzero(allowed)
    wax = _material("CandleWax", lambda nodes, links: _principled(nodes, links, (0.8, 0.73, 0.58), roughness=0.5))
    flame = _glow_material("CandleFlame", (1.0, 0.72, 0.32), 18.0, (1.0, 0.8, 0.5))
    chosen = []
    for index in rng.permutation(len(rows)):
        x, y = x0 + columns[index] + 0.5, y0 + rows[index] + 0.5
        if any((x - a) ** 2 + (y - b) ** 2 < 70.0 ** 2 for a, b in chosen):
            continue
        chosen.append((x, y))
        base = float(layout.height[int(y), int(x)])
        for offset_x, offset_y, tall in ((-1.4, -1.0, 3.0), (1.0, 0.0, 4.4), (0.2, -2.2, 2.2))[:int(rng.integers(2, 4))]:
            body = bmesh.new()
            _cylinder(body, 0.75, tall, segments=10)
            _prop("CapCandle", body, wax, world_point(x + offset_x, y + offset_y, base + tall / 2.0, stretch), stretch)
            tip = bmesh.new()
            bmesh.ops.create_uvsphere(tip, u_segments=8, v_segments=6, radius=0.5 * PX,
                                      matrix=Matrix.Diagonal((1.0, 1.0, 1.8, 1.0)))
            lit = _prop("CapFlame", tip, flame, world_point(x + offset_x, y + offset_y, base + tall + 0.9, stretch),
                        stretch)
            lit.visible_shadow = False
            _glow("candle", x + offset_x, y + offset_y, base + tall + 0.9, (1.0, 0.68, 0.32), 6.0)
        add_point_light("CapCandleLight", (x, y + 1.0), base + 6.0, (1.0, 0.62, 0.3), 0.3, 0.01, stretch)
        if len(chosen) >= count:
            break
    print("CAP CANDLES %d" % len(chosen))


def material_ivy():
    """Ivy hanging from a wall's top: clustered leaves thinning out as they fall."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        leaves = nodes.new("ShaderNodeTexVoronoi")
        leaves.inputs["Scale"].default_value = 9.0
        links.new(coords.outputs["UV"], leaves.inputs["Vector"])
        leaf = op("LESS_THAN", leaves.outputs["Distance"], 0.36)
        reach_in = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("MULTIPLY", u, 4.0), reach_in.inputs["X"])
        reach_in.inputs["Y"].default_value = 1.9
        reach = op("ADD", 0.25, op("MULTIPLY", _noise(nodes, links, reach_in.outputs[0], scale=1.0, detail=3.0), 0.8))
        hang = op("GREATER_THAN", v, op("SUBTRACT", 1.0, reach))
        edges = op("MINIMUM", op("MULTIPLY", u, 6.0), op("MULTIPLY", op("SUBTRACT", 1.0, u), 6.0))
        keep = op("MULTIPLY", op("MULTIPLY", leaf, hang), op("GREATER_THAN", edges, _noise(nodes, links, coords.outputs["UV"],
                                                                                             scale=7.0, detail=2.0)))
        shade = _mix(nodes, links, leaves.outputs["Color"], (0.035, 0.09, 0.03), (0.09, 0.2, 0.06))
        shader = _principled(nodes, links, shade, roughness=0.6)
        _alpha_cut(nodes, links, shader, keep)
    return _material("Ivy", build)


def add_ivy(layout, meta, stretch, count=6):
    rng = np.random.default_rng(SEED + 41)
    segments = [segment for segment in face_segments(layout, meta, minimum=30)]
    rng.shuffle(segments)
    for index, (start, end, face_y, wall_height) in enumerate(segments[:count]):
        width = float(rng.uniform(12.0, 18.0))
        left_side = rng.random() < 0.5
        x = start + width / 2.0 + 1.0 if left_side else end - width / 2.0 - 1.0
        top = wall_height * 0.99
        _face_plane("Ivy%d" % index, x, face_y, top - float(rng.uniform(20.0, 32.0)) / SIN_ALPHA, top, width,
                    material_ivy(), stretch, out=1.0)
    print("IVY %d" % min(count, len(segments)))


# ---------------------------------------------------------------- HD props
#
# Interactive props keep their game sprite node: feet, focus point, occlusion
# and highlight all come from that sprite's on-screen rect. Each one is
# modelled to fill exactly that rect, rendered on its own over transparency,
# and the playable preview swaps the sprite's texture for the render.

PROP_SPRITES = {"CircuitRoomKnowledge": "WallCollisions/KnowledgeExhibits/CircuitRoomKnowledge/Sprite"}


def _wire(name, points, radius, material, stretch):
    """A copper lead through game points (x, plan y, z)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius * PX
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (x, y, z) in zip(spline.points, points):
        point.co = (x * PX, -y * PX * stretch, z * PX, 1.0)
    curve.materials.append(material)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_circuit_exhibit(rect, stretch):
    """The Circuit Room knowledge exhibit as an electrical cabinet: two meters on a
    closed circuit, as its text describes, with a knife switch, copper leads, a coil
    and a lit bulb. Returns its objects and the bulb's position."""
    x0, y0, width, height = rect
    cx = x0 + width / 2.0
    feet = y0 + height
    face = feet - 3.0
    back = feet - 16.0
    up = 1.0 / SIN_ALPHA
    brass = _metal("MachineBrass", (0.64, 0.46, 0.2), 0.3)
    copper = _metal("MachineCopper", (0.6, 0.31, 0.17), 0.34)

    def build_wood(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexWave")
        grain.wave_type = "BANDS"
        grain.bands_direction = "Z"
        grain.inputs["Scale"].default_value = 40.0
        grain.inputs["Distortion"].default_value = 5.0
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        _principled(nodes, links, _mix(nodes, links, grain.outputs["Fac"], (0.16, 0.08, 0.04), (0.3, 0.16, 0.08)),
                    roughness=0.5)
    wood = _material("CabinetWalnut", build_wood)
    bakelite = _material("Bakelite", lambda nodes, links: _principled(nodes, links, (0.015, 0.012, 0.012),
                                                                        roughness=0.3))
    made = []

    def box(suffix, centre_x, front, depth, low, high, wide, material):
        made.append(_box("Circuit" + suffix, (centre_x, front - depth / 2.0, (low + high) / 2.0 * up),
                         (wide, depth, (high - low) * up), material, stretch))

    def disc(suffix, centre_x, plan_y, z, radius, depth, material, segments=28):
        shape = bmesh.new()
        _cylinder(shape, radius, depth, segments=segments, matrix=UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X"))
        made.append(_prop("Circuit" + suffix, shape, material, world_point(centre_x, plan_y, z * up, stretch), stretch))

    # The game reads the prop's feet and highlight from the sprite's opaque
    # bounds, so the model touches all four sides of the rect: the plinth's
    # front edge is the feet line, the crest's arch reaches the top.
    box("Plinth", cx, feet, feet - back, 0.0, 5.0, width - 1.0, wood)
    box("Body", cx, face, face - back, 5.0, 64.0, width - 3.0, wood)
    for side in (-1.0, 1.0):
        box("Door", cx + side * 8.2, face + 0.6, 0.6, 8.0, 26.0, 14.5, wood)
        disc("Knob", cx + side * 1.8, face + 1.0, 17.0, 0.8, 0.8, brass, segments=10)
    box("Ledge", cx, face + 2.6, 2.6, 28.0, 30.5, width - 3.0, wood)
    box("Panel", cx, face + 0.3, 0.3, 33.0, 58.0, width - 7.0, bakelite)
    for index, side in enumerate((-1.0, 1.0)):
        disc("Bezel", cx + side * 8.2, face + 1.1, 46.0, 6.2, 1.6, brass)
        made.append(_dial_disc("CircuitDial", cx + side * 8.2, face + 1.95, 46.0 * up, 5.3,
                               material_dial("ExhibitDial%d" % index, "gauge", needle=(0.15, -0.08)[index]), stretch))
    box("SwitchBase", cx - 9.0, face + 2.4, 2.0, 30.5, 31.5, 8.0, bakelite)
    box("Blade", cx - 9.0, face + 1.6, 0.6, 31.6, 32.3, 7.0, copper)
    disc("Handle", cx - 13.2, face + 1.4, 32.0, 0.9, 1.4, bakelite, segments=10)
    for offset in (5.0, 8.5):
        post = bmesh.new()
        _cylinder(post, 0.7, 1.6 * up, segments=10)
        made.append(_prop("CircuitPost", post, brass, world_point(cx + offset, face + 1.4, 31.3 * up, stretch), stretch))
    coil = bmesh.new()
    _cylinder(coil, 1.0, 5.0 * up, segments=12)
    for turn in range(7):
        _cylinder(coil, 1.7, 0.45 * up, segments=14,
                  matrix=Matrix.Translation((0.0, 0.0, (-2.0 + turn * 0.66) * up * PX)))
    made.append(_prop("CircuitCoil", coil, copper, world_point(cx + 13.0, face + 1.3, 33.0 * up, stretch), stretch))
    box("Cornice", cx, face + 1.2, face + 1.2 - back, 62.0, 65.0, width, brass)
    crest_y = face - 4.0
    box("Crest", cx, crest_y + 0.6, 1.2, 65.0, 72.0, 20.0, brass)
    disc("Arch", cx, crest_y, 72.0, max(crest_y - 0.6 - 72.0 - y0, 6.0), 1.2, brass, segments=40)
    socket = bmesh.new()
    _cylinder(socket, 1.6, 2.0 * up, segments=12)
    made.append(_prop("CircuitSocket", socket, brass, world_point(cx, crest_y + 2.2, 69.0 * up, stretch), stretch))
    bulb_z = 73.5 * up
    glass = bmesh.new()
    bmesh.ops.create_uvsphere(glass, u_segments=14, v_segments=10, radius=2.9 * PX, matrix=UPRIGHT)
    bulb = _prop("CircuitBulb", glass, _flask_glass(), world_point(cx, crest_y + 2.2, bulb_z, stretch), stretch)
    bulb.visible_shadow = False
    made.append(bulb)
    filament = bmesh.new()
    bmesh.ops.create_cube(filament, size=1.0, matrix=Matrix.Diagonal((1.8 * PX, 0.4 * PX, 1.2 * up * PX, 1.0)))
    glow = _prop("CircuitFilament", filament, _glow_material("Filament", (1.0, 0.7, 0.32), 40.0, (1.0, 0.8, 0.5)),
                 world_point(cx, crest_y + 2.2, bulb_z, stretch), stretch)
    glow.visible_shadow = False
    made.append(glow)
    lead = face + 0.5
    made.append(_wire("CircuitLeadA", [(cx - 6.0, face + 1.4, 31.9 * up), (cx - 5.0, lead, 34.0 * up),
                                       (cx - 8.2, lead, 39.5 * up)], 0.35, copper, stretch))
    made.append(_wire("CircuitLeadB", [(cx - 8.2, lead, 52.5 * up), (cx - 4.0, lead, 55.5 * up),
                                       (cx + 4.0, lead, 55.5 * up), (cx + 8.2, lead, 52.5 * up)], 0.35, copper, stretch))
    made.append(_wire("CircuitLeadC", [(cx + 8.2, lead, 39.5 * up), (cx + 8.5, face + 1.4, 33.0 * up)], 0.35, copper, stretch))
    made.append(_wire("CircuitLeadD", [(cx + 13.0, face + 1.3, 36.0 * up), (cx + 14.5, lead, 50.0 * up),
                                       (cx + 13.0, lead, 61.0 * up), (cx + 3.0, crest_y + 2.2, 70.0 * up)], 0.3, copper, stretch))
    for obj in made:
        obj["hd_prop"] = "CircuitRoomKnowledge"
    return made, (cx, crest_y + 2.2, bulb_z)


def _rect_in_region(rect, meta):
    x0, y0, width, height = meta["region"]
    return x0 <= rect[0] and rect[0] + rect[2] <= x0 + width and y0 <= rect[1] and rect[1] + rect[3] <= y0 + height


def _candle_group(name, x, y, base, stretch, count=3):
    """Two or three candles burning on a surface `base` high."""
    wax = _material("CandleWax", lambda nodes, links: _principled(nodes, links, (0.8, 0.73, 0.58), roughness=0.5))
    flame = _glow_material("CandleFlame", (1.0, 0.72, 0.32), 18.0, (1.0, 0.8, 0.5))
    for offset_x, offset_y, tall in ((-1.4, -1.0, 3.0), (1.0, 0.0, 4.4), (0.2, -2.2, 2.2))[:count]:
        body = bmesh.new()
        _cylinder(body, 0.75, tall, segments=10)
        _prop(name + "Candle", body, wax, world_point(x + offset_x, y + offset_y, base + tall / 2.0, stretch), stretch)
        tip = bmesh.new()
        bmesh.ops.create_uvsphere(tip, u_segments=8, v_segments=6, radius=0.5 * PX,
                                  matrix=Matrix.Diagonal((1.0, 1.0, 1.8, 1.0)))
        lit = _prop(name + "Flame", tip, flame, world_point(x + offset_x, y + offset_y, base + tall + 0.9, stretch),
                    stretch)
        lit.visible_shadow = False
        _glow("candle", x + offset_x, y + offset_y, base + tall + 0.9, (1.0, 0.68, 0.32), 6.0)
    add_point_light(name + "Light", (x, y + 1.0), base + 6.0, (1.0, 0.62, 0.3), 0.3, 0.01, stretch)


def add_stair_lights(layout, stretch):
    """Violet light rising up the Wake Room stair; candles on the wall tops at its mouth."""
    stairs = layout.stairs
    if stairs is None:
        return
    centre = (stairs["left"] + stairs["right"]) / 2.0
    for index, fraction in enumerate((0.3, 0.6)):
        y = stairs["top"] + (stairs["bottom"] - stairs["top"]) * fraction
        z = float(layout.height[int(y), int(centre)]) + 6.0
        add_point_light("StairGlow%d" % index, (centre, y), z, (0.62, 0.38, 1.0), 0.5, 0.05, stretch, mirrored=False)
        _glow("crystal", centre, y, z, (0.62, 0.38, 1.0), 14.0)
    for side, x in (("West", stairs["left"] - 6.0), ("East", stairs["right"] + 6.0)):
        y = stairs["top"] + 8.0
        if layout.height[int(y), int(x)] > 0.0:
            _candle_group("StairCandles" + side, x, y, float(layout.height[int(y), int(x)]), stretch)


def add_hd_props(meta, stretch):
    """Builds every HD prop the region holds, hidden from the background render."""
    props = {}
    exhibits = meta.get("exhibits", {})
    x0, y0, width, height = meta["region"]
    rect = exhibits.get("CircuitRoomKnowledge")
    if rect is not None and x0 <= rect[0] and rect[0] + rect[2] <= x0 + width and y0 <= rect[1] \
            and rect[1] + rect[3] <= y0 + height:
        objects, bulb = build_circuit_exhibit(rect, stretch)
        # The bulb lights the wall behind the prop in the background render too,
        # and a soft key from the corridor side makes the exhibit read as the
        # thing to walk up to.
        add_point_light("CircuitBulbLight", bulb[:2], bulb[2], (1.0, 0.66, 0.32), 1.1, 0.02, stretch)
        add_point_light("CircuitKey", (rect[0] + rect[2] + 16.0, rect[1] + rect[3] + 26.0), 55.0, (1.0, 0.86, 0.7),
                        1.8, 0.15, stretch, mirrored=False)
        _glow("bulb", bulb[0], bulb[1], bulb[2], (1.0, 0.68, 0.32), 12.0)
        for obj in objects:
            obj.hide_render = True
        props["CircuitRoomKnowledge"] = (rect, objects)
    return props


def render_props(props, out, meta):
    """Each HD prop alone, cropped to its rect, over transparency; plus the swap list."""
    scene = bpy.context.scene
    x0, y0, width, height = meta["region"]
    entries = []
    for prop_id, (rect, objects) in props.items():
        others = [obj for obj in scene.objects if obj.type in ("MESH", "CURVE") and not obj.hide_render]
        for obj in others:
            obj.hide_render = True
        for obj in objects:
            obj.hide_render = False
        render = scene.render
        render.use_border = True
        render.use_crop_to_border = True
        render.border_min_x = (rect[0] - x0) / width
        render.border_max_x = (rect[0] + rect[2] - x0) / width
        render.border_min_y = 1.0 - (rect[1] + rect[3] - y0) / height
        render.border_max_y = 1.0 - (rect[1] - y0) / height
        render.film_transparent = True
        render.image_settings.color_mode = "RGBA"
        image = os.path.splitext(out)[0] + "-prop-%s.png" % prop_id
        render_to(image)
        render.use_border = False
        render.film_transparent = False
        render.image_settings.color_mode = "RGB"
        for obj in objects:
            obj.hide_render = True
        for obj in others:
            obj.hide_render = False
        entries.append({"id": prop_id, "node": PROP_SPRITES[prop_id], "image": os.path.basename(image),
                        "rect": list(rect)})
    path = os.path.splitext(out)[0] + "-props.json"
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/hall_prototype.py", "props": entries}, handle, indent=1)
    print("PROPS %d -> %s" % (len(entries), path))


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


def _write_png(path, rgba):
    """An 8-bit RGBA PNG, byte for byte: the depth map must not pass through
    any colour management."""
    height, width, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[row].tobytes() for row in range(height))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def export_depth(layout, meta, path):
    """Per screen px of the region, the ground y of the raised surface seen there.

    On one screen px, the surface with the larger ground y is the nearer one.
    So a character whose feet are at y is behind the wall drawn at a px
    exactly when the px's value is greater than y. R and G hold y's high and
    low byte; A marks px where a wall is seen at all.
    """
    x0, y0, width, height = meta["region"]
    lift = np.where(layout.height > 0.0, np.rint(layout.height * layout.sin_alpha), 0).astype(np.int32)
    tallest = int(lift.max())
    rows_needed = height + tallest + 1
    window = np.zeros((rows_needed, width), dtype=np.int32)
    available = lift[y0:min(y0 + rows_needed, layout.rows), x0:x0 + width]
    window[:available.shape[0]] = available
    ground = np.arange(y0, y0 + rows_needed)[:, None]
    depth = np.full((height, width), -1, dtype=np.int32)
    for k in range(tallest + 1):
        # A raised px at ground row y covers screen rows y - lift .. y.
        source = window[k:k + height]
        depth = np.maximum(depth, np.where(source >= max(k, 1), ground[k:k + height], -1))
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    seen = depth >= 0
    rgba[..., 0] = np.where(seen, depth // 256, 0)
    rgba[..., 1] = np.where(seen, depth % 256, 0)
    rgba[..., 3] = np.where(seen, 255, 0)
    _write_png(path, rgba)
    print("DEPTH %s: walls seen on %.1f%% of the region" % (path, 100.0 * seen.mean()))


def compare_footprint(path, layout, meta, scale):
    """The walls seen from straight above against the collision they stand on."""
    image = bpy.data.images.load(os.path.abspath(path))
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    seen = pixels.reshape(height, width, 4)[::-1, :, 3] > 0.5
    x0, y0, region_w, region_h = meta["region"]
    factor = int(round(scale))
    window = (slice(y0, y0 + region_h), slice(x0, x0 + region_w))
    block = np.ones((factor, factor), dtype=bool)
    raised = np.kron(layout.height[window] > 0.0, block)
    collision = np.kron(layout.collision[window], block)
    filled = np.kron((layout.pockets | layout.unreachable)[window], block)
    carved = np.kron(layout.carved[window], block)
    iou = np.logical_and(seen, raised).sum() / max(np.logical_or(seen, raised).sum(), 1)
    reach = (SMOOTH_TOLERANCE_PX + 1) * factor
    far_extra = seen & ~filled & ~_dilate(collision, reach)
    far_missing = collision & ~carved & ~_dilate(seen, reach)
    print("FOOTPRINT vs heightfield iou=%.5f; vs collision beyond %d game px: extra=%d missing=%d "
          "(filled unreachable+pockets %d px, carved %d px; render %dx%d)" % (
              iou, SMOOTH_TOLERANCE_PX + 1, far_extra.sum(), far_missing.sum(), filled.sum(), carved.sum(),
              width, height))
    diff = np.zeros((height, width, 4), dtype=np.float32)
    diff[..., 3] = 1.0
    diff[seen & collision] = (0.35, 0.35, 0.40, 1.0)
    diff[seen & filled] = (0.3, 0.24, 0.42, 1.0)
    diff[carved] = (0.2, 0.5, 0.3, 1.0)
    diff[far_extra] = (1.0, 0.2, 0.2, 1.0)
    diff[far_missing] = (0.2, 0.6, 1.0, 1.0)
    out = bpy.data.images.new("FootprintDiff", width, height, alpha=True)
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
    alcoves = [rect for prop_id, rect in (meta.get("exhibits") or {}).items()
               if prop_id in PROP_SPRITES and _rect_in_region(rect, meta)]
    layout = Layout(collision, outside, math.sin(alpha), spawn=meta.get("spawn"), door_center=door, alcoves=alcoves)
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
    route = meta.get("opening_route") or []
    if len(route) >= 4:
        add_runner_rug(layout, route[1], route[2], stretch)
    setup_world()
    add_sun()
    mounts = add_lamps(layout, meta, stretch)
    add_stair_lights(layout, stretch)
    add_gallery_machinery(layout, meta, stretch)
    banners = add_banners(layout, meta, stretch, mounts)
    add_floor_grates(layout, meta, stretch, [mount[:2] for mount in mounts] + [tuple(meta.get("spawn", (0, 0)))])
    dress_faces(layout, meta, stretch, [(mount[0], mount[1], 6.0) for mount in mounts]
                + [(x, y, BANNER_WIDTH_PX / 2.0 + 2.0) for x, y in banners])
    route = [tuple(point) for point in meta.get("opening_route") or []]
    keep_clear = [mount[:2] for mount in mounts] + route
    add_floor_details(layout, meta, stretch, keep_clear)
    add_floor_story(layout, meta, stretch, keep_clear)
    add_cap_candles(layout, meta, stretch)
    add_ivy(layout, meta, stretch)
    props = add_hd_props(meta, stretch)
    glows_path = os.path.splitext(options["out"])[0] + "-glows.json"
    with open(glows_path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/hall_prototype.py", "region": meta["region"], "glows": GLOWS},
                  handle, indent=1)
    print("GLOWS %d -> %s" % (len(GLOWS), glows_path))
    export_depth(layout, meta, os.path.splitext(options["out"])[0] + "-depth.png")
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
    render_props(props, options["out"], meta)
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
        doomed = [face for face in edit.faces if face.material_index in (CLASS_FLOOR, CLASS_STAIRS)]
        bmesh.ops.delete(edit, geom=doomed, context="FACES")
        edit.to_mesh(mesh)
        edit.free()
        # From straight above and unstretched, the walls must cover exactly
        # the collision they stand on. Only the walls take part.
        for obj in bpy.context.scene.objects:
            if obj is not walls_only and obj.type in ("MESH", "CURVE"):
                obj.hide_render = True
        walls_only.scale = (1.0, 1.0, 1.0)
        camera = bpy.context.scene.camera
        camera.rotation_euler = (0.0, 0.0, 0.0)
        camera.location = Vector(((x0 + width / 2.0) * PX, -(y0 + height / 2.0) * PX, 50.0))
        render_silhouette(options["silhouette"], walls_only, meta, options["scale"])
        compare_footprint(options["silhouette"], layout, meta, options["scale"])


if __name__ == "__main__":
    main()
