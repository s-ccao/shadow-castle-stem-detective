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
# RoomSpatialRuntime's margin for a Hall door prompt: the body's gap to the
# prompt rect.
PROMPT_MARGIN_PX = 14
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
# Doors are stone portals standing on the face. Each doorway is
# DOORWAY_HALF_PX either side of the door's x and recessed DOORWAY_DEPTH_PX
# into the wall, so its two leaves can swing in. The surround reaches
# PORTAL_HALF_PX either side. The Wake gate's doorway is a little narrower,
# to fit the corner it stands in.
DOORWAY_HALF_PX = 12
DOORWAY_DEPTH_PX = 14
PORTAL_HALF_PX = 20
WAKE_GATE_HALF_PX = 11
# Lamps hang over open floor, never against the stone they would wash out.
LAMP_CLEARANCE_PX = 16
LAMP_HEIGHT_PX = 36
LANTERN_SPACING_PX = 130
# Dressing counts were tuned on a 1024 x 512 region; larger regions scale them.
DENSITY_AREA_PX = 1024 * 512
DENSITY = 1.0

CLASS_FLOOR, CLASS_CAP, CLASS_FACE, CLASS_PIT, CLASS_PIT_WALL, CLASS_GATE, CLASS_CAP_EDGE, CLASS_STAIRS = range(8)
# Wall tops are dark so the lit corridors read as the space to explore. A
# capstone lip catches the light: deep along the south edge the camera faces,
# a thin line on the other edges so every mass keeps its outline.
CAP_EDGE_PX = 8
CAP_RIM_PX = 3
SEED = 1307
# Gallery works: the longest a pipe run may be, the clear gap between runs on
# one lane, and the pit area each further pipe, gear or crystal cluster needs.
PIPE_MAX_PX = 170
PIPE_GAP_PX = 36
GALLERY_PIPE_AREA_PX = 26000
GALLERY_GEAR_AREA_PX = 9000
GALLERY_CRYSTAL_AREA_PX = 32000


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
        elif key == "--props-only":
            # Iteration: render only the HD props, not the Hall behind them.
            options["props_only"] = True
            index += 1
            continue
        elif key == "--doors-only":
            # Iteration: render only the doors' opening sequences.
            options["doors_only"] = True
            index += 1
            continue
        elif key == "--prop":
            options.setdefault("only", []).append(argv[index + 1])
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

    def __init__(self, collision, outside, sin_alpha, spawn=None, doors=(), alcoves=()):
        self.collision = collision
        filled, self.filled_pockets = self._fill_pockets(collision, outside)
        self.pockets = filled & ~collision
        smooth = self._smooth(filled)
        self.unreachable, self.cover, self.reach = self._enclosed_floor(smooth, outside, spawn)
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
        self.stairs = []
        self.face_doors = []
        self._galleries()
        self._cap_edges()
        for rect in alcoves:
            self._carve_alcove(rect)
        for name, point, prompt in doors:
            side = self._door_side(point, prompt)
            if side == "north":
                self._cut_stairs(point)
            elif side == "south":
                self._face_door(name, point)
            print("DOOR %s: the player stands %s of it" % (name, side))

    def _door_side(self, point, prompt=None, reach=120):
        """Which side of its wall a door is used from.

        The Hall art draws every arch on the camera-facing south face, and the
        player uses it from there whenever they can stand south of it, even
        where the wall has floor on both sides (Greenhouse, Library, Circuit).
        Only a door with no standing room south of it (Wake) is used from the
        north, and there it becomes a stair down. Standing room is where the
        game shows the door's prompt: feet whose body comes within
        PROMPT_MARGIN_PX of the prompt rect (else within `reach` of the door).
        """
        x, y = int(point[0]), int(point[1])
        if prompt:
            side = PROMPT_MARGIN_PX + PLAYER_BODY_PX[0] // 2
            left, right = prompt[0] - side, prompt[0] + prompt[2] + side
            top, bottom = prompt[1] - PROMPT_MARGIN_PX, prompt[1] + prompt[3] + PROMPT_MARGIN_PX + PLAYER_BODY_PX[1]
        else:
            left, right, top, bottom = x - reach, x + reach, y - reach, y + reach
        top, left = max(int(top), 0), max(int(left), 0)
        ys = np.nonzero(self.reach[top:int(bottom) + 1, left:int(right) + 1])[0] + top
        if len(ys) == 0:
            return None
        return "south" if (ys > y).any() else "north"

    def _face_door(self, name, point):
        """A door on the south face of the wall it is drawn in.

        The face is cut back to one straight line across the portal's width:
        smoothing leaves it a few px ragged, and a portal must sit flush.
        Behind the face a doorway is recessed into the wall, for the leaves
        to swing into. Only drawn wall is removed, never added over floor
        the player walks on.
        """
        x, y = int(point[0]), int(point[1])
        below = np.flatnonzero(~self.wall[y:, x])
        if len(below) == 0:
            return
        own = y + int(below[0])
        half = PORTAL_HALF_PX + 2
        faces = {}
        for column in range(max(x - half, 0), min(x + half + 1, self.columns)):
            free = np.flatnonzero(~self.wall[y:, column])
            if len(free) and abs(y + int(free[0]) - own) <= 6:
                faces[column] = y + int(free[0])
        face_y = min(faces.values())
        for column, column_face in faces.items():
            cut = slice(face_y, column_face)
            self.height[cut, column] = 0.0
            self.kind[cut, column] = CLASS_FLOOR
            self.footprint[cut, column] = False
            self.carved[cut, column] = True
        recess = (slice(face_y - DOORWAY_DEPTH_PX, face_y), slice(x - DOORWAY_HALF_PX, x + DOORWAY_HALF_PX))
        inside = self.wall[recess]
        self.height[recess][inside] = 0.0
        self.kind[recess][inside] = CLASS_FLOOR
        self.footprint[recess][inside] = False
        self.carved[recess][inside] = True
        self.face_doors.append({"name": name.split("_")[0].title(), "x": float(x), "face_y": float(face_y),
                                "half": float(DOORWAY_HALF_PX), "opens": "in"})

    @staticmethod
    def _enclosed_floor(wall, outside, spawn, step=2):
        """Floor no player can reach and no reachable floor touches.

        The old art drew walled-off strips as floor. Seen past a wall, they
        read as somewhere the player should be able to go, so they are drawn
        as castle mass instead.
        """
        if spawn is None:
            free = ~wall & ~outside
            return np.zeros_like(wall), free, free
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
        feet_px = np.zeros_like(wall)
        feet_px[:cell_rows * step, :cell_columns * step] = np.kron(reach, np.ones((step, step), dtype=bool))
        floor = ~wall & ~outside
        unreached = floor & ~covered_px
        labels, _sizes = _flood_labels(unreached)
        touching = np.unique(labels[_dilate(covered_px & floor, 1) & unreached])
        enclosed = (labels > 0) & ~np.isin(labels, touching)
        print("ENCLOSED floor drawn as wall: %d px" % int(enclosed.sum()))
        return enclosed, covered_px & floor, feet_px

    def _carve_alcove(self, rect, margin=3):
        """A floor-level niche in the wall for a prop that stands inside the mass."""
        x, y, width, height = rect
        feet = int(round(y + height))
        # Only a prop whose base stands inside a wall mass needs a niche;
        # one on open floor simply stands in front of the walls.
        if not self.wall[max(feet - 4, 0), min(int(x + width / 2.0), self.columns - 1)]:
            return
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
        is invisible to this camera. So the way back is a stairwell dropping
        south into the wall, with an arched double door at its head: across
        the stairwell the camera sees the door's face, and the player behind
        it once it opens. The gate stands where the floor's edge is
        straightest near the old stair; the few px of wall between that edge
        and the gate's line become a landing. Only wall is cut, never floor
        the player walks on.
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
        middle = (min(columns) + max(columns) + 1) // 2
        best = None
        for centre in range(middle - 12, middle + 13):
            edges = [north_edge(column)
                     for column in range(centre - WAKE_GATE_HALF_PX - 1, centre + WAKE_GATE_HALF_PX + 1)]
            if None in edges:
                continue
            score = (max(edges) - min(edges), abs(centre - middle))
            if best is None or score < best[0]:
                best = (score, centre, max(edges))
        if best is None:
            return
        (spread, _offset), centre, line = best
        left, right = centre - WAKE_GATE_HALF_PX - 1, centre + WAKE_GATE_HALF_PX + 1
        deepest = line
        for column in range(left, right):
            # Stop short of the wall's south face: the stair runs under the
            # mass, it does not break through it.
            below = np.flatnonzero(~self.wall[door_y:, column])
            run_end = door_y + int(below[0]) if len(below) else self.rows
            bottom = min(door_y + STAIR_RUN_PX, run_end - 8)
            deepest = max(deepest, bottom)
            for row in range(north_edge(column), bottom):
                if not self.wall[row, column]:
                    continue
                if row < line:
                    # The landing behind the gate, level with the floor.
                    self.height[row, column] = 0.0
                    self.kind[row, column] = CLASS_FLOOR
                else:
                    step = 1 + (row - line) // STAIR_TREAD_PX
                    self.height[row, column] = -step * STAIR_DROP_PX / self.sin_alpha
                    self.kind[row, column] = CLASS_STAIRS
                self.footprint[row, column] = False
                self.carved[row, column] = True
        self.stairs.append({"left": left, "right": right, "top": line, "bottom": deepest})
        self.face_doors.append({"name": "Wake", "x": float(centre), "face_y": float(line),
                                "half": float(WAKE_GATE_HALF_PX), "opens": "out"})
        print("STAIRS x %d-%d from y %d; Wake gate at x %d (floor edge spread %d px)" % (
            left, right, line, centre, spread))

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


# ---------------------------------------------------------------- doors
#
# Every Hall door is a stone portal on the camera-facing face of its wall:
# quoin jambs, a voussoir arch with a violet gem in its keystone, a cornice
# and a crest bearing the room's emblem, over a doorway recessed into the
# wall. Two oak leaves hang in it on hinges. The Hall render shows the portal
# and, behind the leaves, the passage lit in the room's colour; the leaves are
# rendered apart, as an opening sequence the playable preview animates. The
# Wake gate is the same portal at the head of its stairwell, seen from the
# stair: its leaves open toward the camera.

PORTAL_SPRING_PX = 30.0
PORTAL_JAMB_PX = 6.0
DOOR_LEAF_THICK_PX = 1.2
# The room each door leads to: its emblem and the colour of its light.
DOOR_THEMES = {
    "Chemistry": ("flask", (0.35, 1.0, 0.5)),
    "Greenhouse": ("leaf", (0.45, 1.0, 0.3)),
    "Library": ("book", (1.0, 0.76, 0.42)),
    "Dining": ("clock", (1.0, 0.6, 0.3)),
    "Final": ("star", (0.66, 0.4, 1.0)),
    "Circuit": ("bolt", (0.5, 0.78, 1.0)),
    "Wake": ("moon", (0.62, 0.38, 1.0)),
}
# The leaves' angle in each frame of the opening sequence, in degrees. Frame
# DOOR_RATTLE_FRAME is a locked door rattling, DOOR_AJAR_FRAME a door left
# ajar for the player walking up to it, the last one open: at 72 degrees,
# not 90, so the leaves still show along the doorway's sides rather than
# turning edge-on to the camera.
DOOR_ANGLES = (0.0, 3.0, 8.0, 15.0, 23.0, 32.0, 42.0, 52.0, 62.0, 72.0)
DOOR_RATTLE_FRAME = 1
DOOR_AJAR_FRAME = 4


def _arc(cx, cz, radius, start, end, steps):
    """Points along a circle in screen px, from `start` to `end` degrees."""
    return [(cx + radius * math.cos(math.radians(start + (end - start) * index / steps)),
             cz + radius * math.sin(math.radians(start + (end - start) * index / steps)))
            for index in range(steps + 1)]


def _portal_stone(pale=False):
    """Dressed limestone: the portal's blocks, paler for the keystone and crest."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = _noise(nodes, links, coords.outputs["Object"], scale=55.0, detail=7.0)
        low, high = ((0.36, 0.34, 0.32), (0.58, 0.55, 0.51)) if pale else ((0.24, 0.225, 0.225), (0.42, 0.4, 0.385))
        _principled(nodes, links, _mix(nodes, links, grain, low, high), roughness=0.82,
                    normal=_bump(nodes, links, grain, 0.25, normal=_bevel(nodes, 0.005)))
    return _material("PortalStonePale" if pale else "PortalStone", build)


def _door_oak():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexWave")
        grain.wave_type = "BANDS"
        grain.bands_direction = "X"
        grain.inputs["Scale"].default_value = 60.0
        grain.inputs["Distortion"].default_value = 8.0
        grain.inputs["Detail"].default_value = 4.0
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        _principled(nodes, links, _mix(nodes, links, grain.outputs["Fac"], (0.1, 0.05, 0.025), (0.24, 0.13, 0.06)),
                    roughness=0.58, normal=_bevel(nodes, 0.003))
    return _material("DoorOak", build)


def material_passage(name, color):
    """The passage behind a doorway: dark, with the room's light pooling low
    in the middle, where the floor runs on toward it."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        across = op("MAXIMUM", op("SUBTRACT", 1.0, op("MULTIPLY", op("ABSOLUTE", op("SUBTRACT", u, 0.5)), 1.8)), 0.0)
        low = op("POWER", op("SUBTRACT", 1.0, v), 2.4)
        light = op("MULTIPLY", across, op("ADD", 0.06, op("MULTIPLY", low, 0.94)))
        _principled(nodes, links, (0.015, 0.013, 0.017), roughness=0.9, emission=color,
                    emission_strength=op("MULTIPLY", light, 0.75))
    return _material(name, build)


def material_fan_glass(name, color):
    """Stained glass in a door's fanlight, lit from the room behind it."""
    return _material(name, lambda nodes, links: _principled(
        nodes, links, tuple(channel * 0.25 for channel in color), roughness=0.2, emission=color,
        emission_strength=1.1))


def _emblem(k, kind, color, x, z, scale, front):
    """A room's emblem on its door's crest, `scale` px across its unit circle."""
    brass = _brass()
    glow = _glow_material("Emblem" + kind.title(), color, 4.0, tuple(channel * 0.35 for channel in color))
    if kind == "clock":
        k.dial("EmblemClock", x, front, z, scale * 0.95, material_dial("ClockFace", "clock"))
        k.ring("EmblemRim", x, front - 0.4, z, scale, 0.35, brass)
        return
    pieces = []
    if kind == "star":
        pieces.append(([(math.cos(math.radians(90.0 + 36.0 * index)) * (1.0 if index % 2 == 0 else 0.42),
                         math.sin(math.radians(90.0 + 36.0 * index)) * (1.0 if index % 2 == 0 else 0.42))
                        for index in range(10)], glow))
    elif kind == "bolt":
        pieces.append(([(0.32, 1.0), (-0.42, 0.05), (-0.02, 0.05), (-0.34, -1.0), (0.46, 0.12), (0.06, 0.12)], glow))
    elif kind == "moon":
        centre = 0.42
        radius = math.hypot(0.5 - centre, math.sin(math.radians(60.0)))
        start = math.degrees(math.atan2(-math.sin(math.radians(60.0)), 0.5 - centre))
        outer = _arc(0.0, 0.0, 1.0, 60.0, 300.0, 18)
        inner = _arc(centre, 0.0, radius, start, -360.0 - start, 18)
        pieces.append((outer + inner[1:-1], glow))
    elif kind == "leaf":
        right = [(0.5 * max(math.cos(along * math.pi / 2.0), 0.0) ** 0.8, along)
                 for along in (-1.0 + 2.0 * index / 12.0 for index in range(13))]
        outline = right + [(-across, along) for across, along in reversed(right)][1:-1]
        turn = math.radians(-30.0)
        pieces.append(([(px * math.cos(turn) - pz * math.sin(turn), px * math.sin(turn) + pz * math.cos(turn))
                        for px, pz in outline], glow))
    elif kind == "book":
        for side in (-1.0, 1.0):
            pieces.append(([(side * 0.06, -0.72), (side * 1.05, -0.55), (side * 1.05, 0.86), (side * 0.06, 0.68)],
                           _parchment()))
        pieces.append(([(-0.06, -0.78), (0.06, -0.78), (0.06, 0.74), (-0.06, 0.74)], brass))
    elif kind == "flask":
        glass = _glow_material("EmblemFlaskGlass", (0.72, 0.84, 0.78), 0.5, (0.5, 0.56, 0.53))
        pieces.append(([(-0.2, 1.0)] + _arc(0.0, -0.3, 0.68, 107.1, 432.9, 26) + [(0.2, 1.0)], glass))
        pieces.append((_arc(0.0, -0.3, 0.54, 190.0, 350.0, 12), glow))
    for index, (outline, material) in enumerate(pieces):
        k.slab("Emblem%d" % index, [(x + px * scale, z + pz * scale) for px, pz in outline], front - 0.15 * index,
               0.5, material)


def build_portal(k, door):
    """A door's stone portal in its kit's frame: x across the doorway's centre,
    y north of the door's line, z screen px up. The doorway reaches
    door["half"] each side. Behind it is the recess its leaves swing into, or,
    for the Wake gate, the corridor the player comes from. Returns the leaves'
    hinges as (turn, side, objects)."""
    half, spring, jamb = door["half"], PORTAL_SPRING_PX, PORTAL_JAMB_PX
    outer = half + jamb
    top = spring + outer + 0.5
    stone, pale, iron = _portal_stone(), _portal_stone(pale=True), _cast_iron()
    kind, color = DOOR_THEMES.get(door["name"], ("star", (0.62, 0.38, 1.0)))
    inward = door["opens"] == "in"
    for side in (-1.0, 1.0):
        k.box("Plinth", side * (half + jamb / 2.0 + 0.3), 0.0, jamb + 1.6, 3.0, -3.8, 4.6, stone)
        levels = (3.0, 9.6, 16.2, 22.8, spring - 1.2)
        for index, (low, high) in enumerate(zip(levels[:-1], levels[1:])):
            wide = jamb + (0.9 if index % 2 == 0 else 0.0)
            k.box("Quoin", side * (half + wide / 2.0), low + 0.18, wide, high - low - 0.36, -3.0, 3.8, stone)
        k.box("Impost", side * (half + jamb / 2.0 + 0.2), spring - 1.2, jamb + 1.8, 1.8, -3.6, 4.2, pale)
    # Nine voussoirs; the middle one is the keystone, larger and paler.
    for index in range(9):
        low, high = index * 20.0 + 0.4, (index + 1) * 20.0 - 0.4
        key = index == 4
        reach = outer + (3.0 if key else 0.5)
        outline = _arc(0.0, spring, half, low, high, 4) + list(reversed(_arc(0.0, spring, reach, low, high, 4)))
        k.slab("Voussoir", outline, -4.2 if key else -3.2, 4.4 if key else 3.9, pale if key else stone)
    k.slab("SpandrelWest", [(-(outer + 1.5), spring), (-(outer + 1.5), top)]
           + _arc(0.0, spring, outer + 0.5, 90.0, 180.0, 12), -2.6, 3.0, stone)
    k.slab("SpandrelEast", [(outer + 1.5, top), (outer + 1.5, spring)]
           + _arc(0.0, spring, outer + 0.5, 0.0, 90.0, 12), -2.6, 3.0, stone)
    k.box("Frieze", 0.0, top - 0.9, 2.0 * (outer + 1.5), 0.9, -3.6, 4.0, stone)
    k.box("Cornice", 0.0, top, 2.0 * (outer + 3.0), 3.0, -4.6, 5.2, pale)
    crest = top + 3.0
    k.slab("Crest", _arc(0.0, crest, 9.5, 0.0, 180.0, 24), -3.4, 3.0, stone)
    k.slab("CrestRim", _arc(0.0, crest, 10.2, 0.0, 180.0, 24) + list(reversed(_arc(0.0, crest, 9.2, 0.0, 180.0, 24))),
           -3.8, 3.4, pale)
    plaque = crest + 4.6
    # A dark enamel plaque in a brass rim, so the emblem stands out on it.
    k.disc("Plaque", 0.0, -4.0, plaque, 5.6, 0.6, _painted("PlaqueEnamel", (0.025, 0.022, 0.04)))
    k.ring("PlaqueRim", 0.0, -4.3, plaque, 5.6, 0.4, _brass())
    _emblem(k, kind, color, 0.0, plaque, 3.9, -4.5)
    if kind != "book":
        k.glow("crystal", 0.0, -4.5, plaque, color, 7.0)
    gem = spring + half + 4.2
    k.ball("KeyGem", 0.0, -4.6, gem, 1.2, _glow_material("FaceDoorGem", (0.62, 0.36, 1.0), 3.0, (0.3, 0.12, 0.6)))
    k.glow("crystal", 0.0, -4.6, gem, (0.62, 0.36, 1.0), 6.0)
    # The fanlight over the leaves: an iron sunburst over stained glass.
    fan = 0.2 if inward else -0.2
    k.slab("FanGlass", _arc(0.0, spring, half - 0.5, 0.0, 180.0, 24), fan + 0.5, 0.2,
           material_fan_glass("FanGlass" + door["name"], color))
    k.slab("FanRing", _arc(0.0, spring, half, 0.0, 180.0, 24)
           + list(reversed(_arc(0.0, spring, half - 1.0, 0.0, 180.0, 24))), fan, 0.6, iron)
    for turn in (30.0, 60.0, 90.0, 120.0, 150.0):
        along = (math.cos(math.radians(turn)), math.sin(math.radians(turn)))
        across = (-along[1] * 0.28, along[0] * 0.28)
        k.slab("FanBar", [(along[0] * 2.0 + across[0], spring + along[1] * 2.0 + across[1]),
                          (along[0] * (half - 0.6) + across[0], spring + along[1] * (half - 0.6) + across[1]),
                          (along[0] * (half - 0.6) - across[0], spring + along[1] * (half - 0.6) - across[1]),
                          (along[0] * 2.0 - across[0], spring + along[1] * 2.0 - across[1])], fan, 0.6, iron)
    k.slab("FanHub", _arc(0.0, spring, 2.2, 0.0, 180.0, 10), fan - 0.1, 0.8, iron)
    k.box("Transom", 0.0, spring - 0.6, 2.0 * half, 1.2, fan - 0.1, 0.8, iron)
    if inward:
        k.box("Threshold", 0.0, 0.0, 2.0 * half + 3.0, 1.3, -4.5, 4.5, stone)
        depth = DOORWAY_DEPTH_PX
        k.box("RecessRoof", 0.0, 40.5, 2.0 * half + 1.0, 3.5, 1.0, depth - 1.0, stone)
        k.plane("Passage", 0.0, depth - 0.3, 0.0, spring + half + 1.0, 2.0 * half,
                material_passage("Passage" + door["name"], color))
        k.light("Passage", 0.0, depth * 0.55, 13.0, color, 0.12, radius=0.03)
    else:
        k.box("Threshold", 0.0, -0.9, 2.0 * half + 3.0, 1.0, -2.6, 2.6, stone)
    oak = _door_oak()
    return [_door_leaf(k, door, side, oak, iron) for side in (-1.0, 1.0)]


def _door_leaf(k, door, side, oak, iron):
    """One leaf of a double door, hung at its outer edge `side` (-1 west, +1
    east) and built in its hinge's frame. The hinge is two empties: the outer
    one stretches like every prop, the inner one turns, so the leaf swings in
    true plan space. Returns (turn, side, objects)."""
    half, height = door["half"], PORTAL_SPRING_PX - 0.5
    width = half - 0.06
    thick = DOOR_LEAF_THICK_PX
    inward = door["opens"] == "in"
    # A door opening in hangs from its back face, the Wake gate from its front.
    front = -thick if inward else 0.0
    up = 1.0 / SIN_ALPHA
    pivot = bpy.data.objects.new("%sHinge%+d" % (k.id, side), None)
    pivot.location = k.at(side * half, thick if inward else 0.0, 0.0)
    pivot.scale = (1.0, k.stretch, 1.0)
    turn = bpy.data.objects.new("%sTurn%+d" % (k.id, side), None)
    turn.parent = pivot
    for empty in (pivot, turn):
        bpy.context.scene.collection.objects.link(empty)
    wood, metal = bmesh.new(), bmesh.new()

    def block(shape, t0, t1, y0, y1, z0, z1):
        # t runs from the hinge toward the doorway's middle.
        bmesh.ops.create_cube(shape, size=1.0, matrix=(
            Matrix.Translation((-side * (t0 + t1) / 2.0 * PX, (y0 + y1) / 2.0 * PX, (z0 + z1) / 2.0 * up * PX))
            @ Matrix.Diagonal(((t1 - t0) * PX, (y1 - y0) * PX, (z1 - z0) * up * PX, 1.0))))

    for index in range(3):
        block(wood, index * width / 3.0 + 0.06, (index + 1) * width / 3.0 - 0.06, front, front + thick, 0.2, height)
    for low in (6.0, height - 8.2):
        block(metal, 0.3, width - 0.6, front - 0.28, front + 0.02, low, low + 1.2)
        for index in range(int((width - 1.2) / 2.6) + 1):
            bmesh.ops.create_uvsphere(metal, u_segments=8, v_segments=5, radius=0.32 * PX, matrix=(
                Matrix.Translation((-side * (1.0 + index * 2.6) * PX, (front - 0.32) * PX, (low + 0.6) * up * PX))
                @ Matrix.Diagonal((1.0, 0.6, 0.8 * up, 1.0))))
    block(metal, 0.2, width - 0.2, front - 0.16, front + 0.02, 0.2, 1.8)
    ring = width - 2.4
    _torus(metal, 1.3, 0.28, 24, 8, Matrix.Translation((-side * ring * PX, (front - 0.5) * PX,
                                                          height * 0.48 * up * PX)) @ FACE_ON)
    _cylinder(metal, 0.9, 0.3, segments=16, matrix=Matrix.Translation(
        (-side * ring * PX, (front - 0.15) * PX, (height * 0.48 + 1.3) * up * PX)) @ FACE_ON)
    made = []
    for shape, material, suffix in ((wood, oak, "Wood"), (metal, iron, "Iron")):
        mesh = bpy.data.meshes.new("%sLeaf%+d%s" % (k.id, side, suffix))
        shape.to_mesh(mesh)
        shape.free()
        mesh.materials.append(material)
        obj = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = turn
        obj["door_leaf"] = door["name"]
        made.append(obj)
    return turn, side, made


def _door_lanterns(layout, faces, door, stretch):
    """A lantern on the face either side of a portal, where the face allows."""
    x, face_y = door["x"], door["face_y"]
    row = int(face_y) - 1
    for side in (-1.0, 1.0):
        # The nearest face beside the portal: a smoothed face wanders a few
        # px, and a door by a corner has a face on one side only.
        for gap in range(5, 19):
            lamp_x = x + side * (PORTAL_HALF_PX + gap)
            if not 0 <= int(lamp_x) < layout.columns:
                break
            rows = np.flatnonzero(faces[max(row - 4, 0):row + 5, int(lamp_x)]) + max(row - 4, 0)
            if len(rows):
                face_row = int(rows[np.argmin(np.abs(rows - row))])
                if not _prop_on_face(lamp_x - 3.0, lamp_x + 3.0, face_row + 1.0):
                    add_lantern("Door%sLamp" % door["name"],
                                (lamp_x, face_row + 1.0, float(layout.height[face_row, int(lamp_x)])), stretch)
                break


def add_doors(layout, stretch):
    """A stone portal on every face door and at the head of the Wake stair,
    each with hinged leaves. The leaves stay out of the Hall render's camera
    but cast their shadows, closed; render_doors() animates them."""
    faces = _south_faces(layout)
    doors = []
    for door in layout.face_doors:
        stand = {"centre": door["x"], "feet": door["face_y"], "width": 2.0 * PORTAL_HALF_PX, "height": 64.0,
                 "depth": 6.0}
        kit = PropKit("Door" + door["name"], stand, stretch)
        hinges = build_portal(kit, door)
        for obj in kit.made:
            obj["door"] = door["name"]
        for _turn, _side, objects in hinges:
            for obj in objects:
                obj.visible_camera = False
        if door["opens"] == "in":
            _door_lanterns(layout, faces, door, stretch)
        else:
            # The Wake gate faces the stairwell, away from any lantern.
            kit.light("Key", 0.0, -24.0, 34.0, (1.0, 0.86, 0.7), 0.9, radius=0.15, mirrored=False)
        doors.append({"door": door, "kit": kit, "hinges": hinges})
    print("DOORS %d" % len(doors))
    return doors


def _near_door(layout, x, face_y, reach=40.0):
    """Whether a face position is taken by a door or a stair's mouth."""
    for door in layout.face_doors:
        if abs(x - door["x"]) < reach and abs(face_y - door["face_y"]) < 30.0:
            return True
    for stairs in layout.stairs:
        if stairs["left"] - reach < x < stairs["right"] + reach and abs(face_y - stairs["top"]) < 90.0:
            return True
    return False


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
    """Iron lanterns along the faces that look onto open floor: the longest faces
    first, spaced so each corridor gets light and none crowd, clear of doors."""
    x0, y0, width, height = meta["region"]
    clear = _clear_floor(layout)
    faces = _south_faces(layout)
    segments = []
    for row in range(y0, min(y0 + height, layout.rows)):
        starts, ends = _runs(faces[row, x0:x0 + width])
        for start, end in zip(starts, ends):
            if end - start >= 30:
                segments.append((int(end - start), row, x0 + int(start), x0 + int(end)))
    segments.sort(reverse=True)
    mounts = []
    for length, row, start, end in segments:
        count = max(1, length // 150)
        for slot in range(count):
            face_y = row + 1.0
            # A prop on the face moves its lantern to hang just beside it.
            x = _beside_props(start + (slot + 0.5) * length / count, face_y, start, end, 4.0)
            if x is None or _near_door(layout, x, face_y, reach=48.0):
                continue
            if any((x - other[0]) ** 2 + (face_y - other[1]) ** 2 < LANTERN_SPACING_PX ** 2 for other in mounts):
                continue
            mount = (x, face_y, float(layout.height[row, int(x)]))
            mounts.append(mount)
            name = "Lamp%d" % len(mounts)
            add_lantern(name, mount, stretch)
            # A soft pool on the floor below keeps the corridor readable.
            add_point_light(name + "Fill", nearest_floor(layout, x, face_y + 24.0, clear), LAMP_HEIGHT_PX,
                            (1.0, 0.66, 0.36), 1.0, 0.2, stretch, mirrored=False)
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
        # The gaps between corridors join into pits up to the size of the
        # Hall: their works scale with them, so no stretch is left bare.
        area = int(mask.sum())
        pipe_count = min(2 + area // GALLERY_PIPE_AREA_PX, 12)
        gear_count = min(4 + area // GALLERY_GEAR_AREA_PX, 28)
        crystal_count = min(1 + area // GALLERY_CRYSTAL_AREA_PX, 8)
        for pipe in range(pipe_count):
            # Alternate the runs' direction so winding pits get both.
            horizontal = (columns >= rows) == (pipe % 2 == 0)
            lanes = clearance if horizontal else clearance.T
            lanes_used = used if horizontal else used.T
            best = None
            for lane in range(lanes.shape[0]):
                blocked = lanes_used[max(lane - 6, 0):lane + 7].any(axis=0)
                starts, ends = _runs((lanes[lane] >= 5) & ~blocked)
                if len(starts) == 0:
                    continue
                longest = int(np.argmax(ends - starts))
                length = int(ends[longest] - starts[longest])
                if best is None or length > best[0]:
                    best = (length, lane, int(starts[longest]), int(ends[longest]))
            if best is None or best[0] < 24:
                continue
            length, lane, start, end = best
            # A run no longer than a pipe could be: a lane across the whole
            # Hall reads as a ruled line, not plumbing.
            if length > PIPE_MAX_PX:
                start += int(rng.integers(0, length - PIPE_MAX_PX + 1))
                end = start + PIPE_MAX_PX
            lanes_used[max(lane - 6, 0):lane + 7, max(start - PIPE_GAP_PX, 0):end + PIPE_GAP_PX] = True
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
        yy, xx = np.ogrid[:rows, :columns]

        def disc(row, column, radius):
            return (yy - row) ** 2 + (xx - column) ** 2 <= radius ** 2

        placed, train = 0, 0
        while placed < gear_count:
            # The room the pit's edge and the works already set leave, so no
            # gear is laid through another.
            free = _clearance(mask & ~used, 24)
            row, column = np.unravel_index(int(np.argmax(free)), free.shape)
            radius = min((free[row, column] - 1) * 0.9 - 1.5, 15.0)
            if radius < 5.0:
                break
            # Mixed sizes: a narrow channel limits every gear alike.
            radius = max(radius * rng.uniform(0.6, 1.0), 5.0)
            others = used.copy()
            add_gear("Gear%d_%d_0" % (number, train), left + column + 0.5, top + row + 0.5,
                     float(floor[row, column]) + 0.6, radius, 2.4, rng.uniform(0.0, 2.0 * math.pi),
                     gears[int(rng.random() < 0.35)], stretch)
            used |= disc(row, column, radius + 3.0)
            placed += 1
            # One or two smaller gears whose teeth meet its rim: a train of
            # works, not a coin dropped on the floor.
            for companion in range(1, int(rng.integers(2, 4))):
                small = radius * rng.uniform(0.45, 0.7)
                turn = rng.uniform(0.0, 2.0 * math.pi)
                reach = 1.02 * (radius + small)
                y, x = row + reach * math.sin(turn), column + reach * math.cos(turn)
                ty, tx = int(round(y)), int(round(x))
                if (small < 3.5 or not (0 <= ty < rows and 0 <= tx < columns)
                        or clearance[ty, tx] < small + 1.5 or (others & disc(y, x, small + 1.5)).any()):
                    continue
                add_gear("Gear%d_%d_%d" % (number, train, companion), left + x + 0.5, top + y + 0.5,
                         float(floor[ty, tx]) + 0.6, small, 2.4, rng.uniform(0.0, 2.0 * math.pi),
                         gears[int(rng.random() < 0.35)], stretch)
                others |= disc(y, x, small + 1.0)
                used |= disc(y, x, small + 3.0)
                placed += 1
            train += 1
        counts["gears"] += placed
        for cluster in range(crystal_count):
            free = _clearance(mask & ~used, 24)
            row, column = np.unravel_index(int(np.argmax(free)), free.shape)
            if free[row, column] < 6:
                break
            add_crystals("Crystal%d_%d" % (number, cluster), left + column + 0.5, top + row + 0.5,
                         float(floor[row, column]), room, crystal, rng, stretch)
            used |= (yy - row) ** 2 + (xx - column) ** 2 <= 10 ** 2
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
    # Each run ends in an iron valve housing on the pit floor: plumbing
    # between works, not a pipe that stops in mid-air.
    ground = z - radius - 0.2
    for index, (x, y) in enumerate((start, end)):
        _box("%sValve%d" % (name, index), (x, y, ground + radius * 1.3),
             (radius * 3.0, radius * 3.0, radius * 2.6), flange_material, stretch)


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
            if _near_door(layout, x, face_y):
                continue
            if _prop_on_face(x - BANNER_WIDTH_PX / 2.0, x + BANNER_WIDTH_PX / 2.0, face_y):
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


def _cut_span(free, left, right):
    """The stretches (a, b) of `free` less left..right."""
    cut = []
    for a, b in free:
        if right <= a or left >= b:
            cut.append((a, b))
            continue
        if left > a:
            cut.append((a, left))
        if right < b:
            cut.append((right, b))
    return cut


def dress_faces(layout, meta, stretch, taken):
    """Shelves, portraits, alcoves, boards, gauges and a clock in the free stretches
    of the south faces, around the lanterns and banners in `taken` (x, face_y, half width)."""
    rng = np.random.default_rng(SEED + 7)
    turns = {DECOR_BIG: 0, DECOR_SMALL: 0}
    placed = {kind: 0 for kind in DECOR}
    webs = 0
    for start, end, face_y, wall_height in sorted(face_segments(layout, meta), key=lambda item: item[0] - item[1]):
        free = [(start + 3.0, end - 3.0)]
        for x, other_y, half in list(taken) + [(door["x"], door["face_y"], 26.0) for door in layout.face_doors] + [
                ((stairs["left"] + stairs["right"]) / 2.0, face_y, 60.0) for stairs in layout.stairs
                if abs(face_y - stairs["top"]) < 90.0]:
            if abs(other_y - face_y) <= 3.0:
                free = _cut_span(free, x - half - 5.0, x + half + 5.0)
        # A staged prop hides the face behind it, however ragged that face is.
        for stand in STANDS.values():
            if stand["face_min"] - 4.0 <= face_y <= stand["back"] + 4.0:
                free = _cut_span(free, stand["left"] - PROP_PAD_PX, stand["right"] + PROP_PAD_PX)
        for a, b in free:
            room = b - a
            slots = max(1, int(room // DECOR_SLOT_PX))
            slot = room / slots
            pool = DECOR_BIG if slot >= 30.0 else DECOR_SMALL
            for index in range(slots):
                fits = [pool[(turns[pool] + step) % len(pool)] for step in range(len(pool))]
                fits = [kind for kind in fits
                        if DECOR[kind][0] <= slot - 3.0 and placed[kind] < DECOR_CAPS[kind] * DENSITY]
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
    cracks = _open_spots(layout, meta, 10, int(round(12 * DENSITY)), avoid, 70.0, rng)
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
    clusters = _open_spots(layout, meta, 12, int(round(9 * DENSITY)), avoid, 90.0, rng, clear_of=40.0)
    notes = 0
    for cx, cy in clusters:
        for _page in range(int(rng.integers(2, 5))):
            x, y = cx + float(rng.uniform(-9.0, 9.0)), cy + float(rng.uniform(-7.0, 7.0))
            _decal_quad("Note%d" % notes, x, y, 6.0, 8.0, float(rng.uniform(0.0, math.pi)), note, stretch,
                        z=0.14 + notes * 0.002)
            notes += 1
    taken = avoid + clusters
    spills = _open_spots(layout, meta, 14, int(round(3 * DENSITY)), taken, 220.0, rng, clear_of=45.0)
    for index, (x, y) in enumerate(spills):
        name, color = (("SpillViolet", (0.6, 0.3, 1.0)), ("SpillGreen", (0.25, 1.0, 0.5)))[index % 2]
        size = float(rng.uniform(18.0, 26.0))
        _decal_quad("Spill%d" % index, x, y, size, size * 0.8, float(rng.uniform(0.0, math.pi)),
                    material_spill(name, color), stretch, z=0.13)
        _glow("potion", x, y, 0.0, color, size * 0.7)
    taken = taken + spills
    chalk = _open_spots(layout, meta, 24, int(round(2 * DENSITY)), taken, 260.0, rng, clear_of=50.0)
    for index, (x, y) in enumerate(chalk):
        _decal_quad("Chalk%d" % index, x, y, 44.0, 30.0, float(rng.uniform(-0.3, 0.3)), material_chalk_diagram(),
                    stretch, z=0.12)
    print("FLOOR STORY notes=%d spills=%d chalk=%d" % (notes, len(spills), len(chalk)))


def add_cap_candles(layout, meta, stretch, count=None):
    """Candles burning on the wall tops, near the camera-facing edge, inside the outline."""
    rng = np.random.default_rng(SEED + 31)
    count = int(round(10 * DENSITY)) if count is None else count
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
        if _behind_prop(x, y) or _behind_portal(layout, x, y):
            continue
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


def add_ivy(layout, meta, stretch, count=None):
    rng = np.random.default_rng(SEED + 41)
    count = int(round(6 * DENSITY)) if count is None else count
    segments = [segment for segment in face_segments(layout, meta, minimum=30)]
    rng.shuffle(segments)
    placed = 0
    for start, end, face_y, wall_height in segments:
        if placed >= count:
            break
        width = float(rng.uniform(12.0, 18.0))
        left_side = rng.random() < 0.5
        x = start + width / 2.0 + 1.0 if left_side else end - width / 2.0 - 1.0
        drop = float(rng.uniform(20.0, 32.0))
        if _prop_on_face(x - width / 2.0, x + width / 2.0, face_y) or any(
                abs(x - door["x"]) < PORTAL_HALF_PX + width / 2.0 + 2.0 and abs(face_y - door["face_y"]) <= 4.0
                for door in layout.face_doors):
            continue
        top = wall_height * 0.99
        _face_plane("Ivy%d" % placed, x, face_y, top - drop / SIN_ALPHA, top, width, material_ivy(), stretch, out=1.0)
        placed += 1
    print("IVY %d" % placed)


# ---------------------------------------------------------------- HD props
#
# The Hall's interactive props, modelled to stand in the HD Hall rather than
# float over it. Each backs onto a wall's camera-facing south face with open
# floor in front, and is rendered alone over transparency. The playable
# preview stages it there: it moves the prop's node by the offset from its
# place in the game and swaps its sprite for the render, so the game's feet,
# prompt, focus box and occlusion all follow the prop the player sees. The
# game's own scenes stay as they are.

# The preview shows figures at this scale, and props at it too, so props and
# figures keep the game's proportions.
FIGURE_SCALE = 1.1 / 1.45
# Each prop's stand: centre x, the face row it backs onto (give or take a few
# px), width and height on screen, and plan depth. Each was searched to back
# onto a straight stretch of face, with a wall's height of open floor in front
# (or the next wall's top would hide its foot) and floor to walk up to it that
# no door's prompt claims. Sizes are the pixel sprites' at FIGURE_SCALE; the
# workshop machine is remodelled narrower to fit its bay.
HD_PROP_STANDS = {
    "ChemistryRoomKnowledge": (634.5, 540, 25.6, 76.8, 8),
    "CircuitRoomKnowledge": (203.0, 728, 28.4, 70.2, 8),
    "LibraryRoomKnowledge": (1558.4, 196, 22.8, 64.5, 8),
    "GreenhouseRoomKnowledge": (262.2, 284, 28.4, 67.3, 8),
    "DiningHallKnowledge": (1718.2, 712, 30.3, 82.5, 8),
    "StorageRack": (1625.0, 991, 52.2, 49.3, 8),
    "FinalKeyMachine1": (342.1, 481, 32.2, 85.3, 8),
    "FinalKeyMachine2": (1395.6, 128, 105.3, 50.3, 6),
    "FinalKeyMachine3": (1275.0, 1148, 70.0, 80.0, 10),
}
# Free px kept beside a prop on its face, and how far past its stand each
# prop's render reaches before it is cropped to what it shows.
PROP_PAD_PX = 6.0
PROP_RENDER_MARGIN_PX = 8
# The game counts a sprite px as shown above this alpha (RoomSpatialRuntime).
VISIBLE_ALPHA = 0.05
# The stands measured on this layout, by prop. Set once the layout is built,
# before any dressing, so lanterns, decor and floor clutter leave them clear.
STANDS = {}


def prop_stands(layout, meta):
    """Each stand in the region, measured on the layout: the face row behind
    every column it covers, its feet, and the open floor in front of it."""
    x0, y0, width, height = meta["region"]
    stands = {}
    for name, (centre, near, wide, tall, depth) in HD_PROP_STANDS.items():
        left, right = int(round(centre - wide / 2.0)), int(round(centre + wide / 2.0))
        if not (x0 <= left and right <= x0 + width and y0 <= near - tall and near + depth <= y0 + height):
            continue
        faces = []
        for column in range(left, right):
            run = layout.wall[near - 14:near + 3, column]
            rows = [near - 13 + index for index in range(len(run) - 1) if run[index] and not run[index + 1]]
            faces.append(max(rows) if rows else None)
        if None in faces:
            print("STAND %s FAIL: no face behind part of columns %d..%d" % (name, left, right))
            continue
        back = max(faces)
        room = min(int(np.argmax(layout.wall[back:, column])) if layout.wall[back:, column].any()
                   else layout.rows - back for column in range(left, right))
        stands[name] = {"centre": float(centre), "left": float(left), "right": float(right), "width": float(wide),
                        "height": float(tall), "depth": float(depth), "face_min": float(min(faces)),
                        "back": float(back), "feet": float(back + depth)}
        print("STAND %s: x %d..%d, face %d..%d, feet %d, %d px open in front: %s" % (
            name, left, right, min(faces), back, back + depth, room,
            "OK" if room >= FACE_PX + depth + 6 else "FAIL"))
    return stands


def _prop_on_face(left, right, face_y, pad=PROP_PAD_PX):
    """Whether a span of the south face at `face_y` is taken by a staged prop."""
    return any(stand["face_min"] - 4.0 <= face_y <= stand["back"] + 4.0
               and left < stand["right"] + pad and right > stand["left"] - pad for stand in STANDS.values())


def _beside_props(x, face_y, start, end, half):
    """`x` on the face start..end where no staged prop takes it, else the
    nearest spot just beside the prop that does; None without room."""
    if not _prop_on_face(x - half, x + half, face_y):
        return x
    spots = []
    for stand in STANDS.values():
        spots += [stand["left"] - PROP_PAD_PX - half - 1.0, stand["right"] + PROP_PAD_PX + half + 1.0]
    for spot in sorted(spots, key=lambda spot: abs(spot - x)):
        if start + half <= spot <= end - half and not _prop_on_face(spot - half, spot + half, face_y):
            return spot
    return None


def _behind_prop(x, y):
    """Whether a wall-top spot lies behind a staged prop, which hides it on screen."""
    return any(stand["left"] - 10.0 < x < stand["right"] + 10.0 and stand["back"] - FACE_PX * 1.5 < y <= stand["back"]
               for stand in STANDS.values())


def _behind_portal(layout, x, y):
    """Whether a wall-top spot lies behind a door's portal, whose crest rises over it."""
    return any(abs(x - door["x"]) < PORTAL_HALF_PX + 8.0 and door["face_y"] - FACE_PX * 1.6 < y <= door["face_y"] + 2.0
               for door in layout.face_doors)


def _prop_floor():
    """Points along each staged prop's foot that floor clutter keeps clear of."""
    points = []
    for stand in STANDS.values():
        steps = max(int(math.ceil((stand["right"] - stand["left"]) / 12.0)), 1)
        points += [(stand["left"] + (stand["right"] - stand["left"]) * index / steps, stand["feet"] + 4.0)
                   for index in range(steps + 1)]
    return points


def _torus(shape, major, minor, segments=32, sides=10, matrix=None):
    """A ring around Z in the XY plane, sizes in game px."""
    matrix = matrix if matrix is not None else Matrix.Identity(4)
    rings = []
    for index in range(segments):
        turn = 2.0 * math.pi * index / segments
        ring = []
        for side in range(sides):
            bend = 2.0 * math.pi * side / sides
            reach = major + minor * math.cos(bend)
            ring.append(shape.verts.new(matrix @ Vector((reach * math.cos(turn) * PX, reach * math.sin(turn) * PX,
                                                         minor * math.sin(bend) * PX))))
        rings.append(ring)
    for index in range(segments):
        here, there = rings[index], rings[(index + 1) % segments]
        for side in range(sides):
            shape.faces.new((here[side], there[side], there[(side + 1) % sides], here[(side + 1) % sides]))
    bmesh.ops.recalc_face_normals(shape, faces=shape.faces[:])


# A disc or ring in the XY plane turned to face the camera, round on screen.
FACE_ON = UPRIGHT @ Matrix.Rotation(math.radians(90.0), 4, "X")


class PropKit:
    """Builds one prop on its stand, in game px: `x` across from the stand's
    centre, `y` plan px north of its feet (its front edge on the floor) toward
    the face it backs onto, `z` screen px up. A part shows on screen up to its
    y + z above the feet line, so the stand's height bounds that sum. Every
    object is tagged with the prop's id, so the prop can render alone."""

    def __init__(self, prop_id, stand, stretch):
        self.id = prop_id
        self.stand = stand
        self.cx = stand["centre"]
        self.feet = stand["feet"]
        self.stretch = stretch
        self.made = []
        self.lights = []

    def at(self, x, y, z):
        return world_point(self.cx + x, self.feet - y, z / SIN_ALPHA, self.stretch)

    def keep(self, obj):
        obj["hd_prop"] = self.id
        self.made.append(obj)
        return obj

    def mesh(self, name, shape, material, x, y, z, smooth=False):
        """`shape`, built around its origin in PX units, placed at (x, y, z)."""
        if smooth:
            shape.normal_update()
            for face in shape.faces:
                face.smooth = smooth is True or bool(smooth(face))
        return self.keep(_prop(self.id + name, shape, material, self.at(x, y, z), self.stretch))

    def box(self, name, x, z, width, height, front, depth, material):
        """A block from screen height z, its front `front` px north of the feet."""
        shape = bmesh.new()
        bmesh.ops.create_cube(shape, size=1.0, matrix=Matrix.Diagonal(
            (width * PX, depth * PX, height / SIN_ALPHA * PX, 1.0)))
        return self.mesh(name, shape, material, x, front + depth / 2.0, z + height / 2.0)

    def cylinder(self, name, x, y, z, radius, height, material, plan=None, tip=None, segments=24):
        """Upright from screen height z, centred `y` px north of the feet. `plan`
        is its north-south half depth: by default half its radius, so its top
        reads as a 3/4 view; `tip` narrows (or widens) its top."""
        plan = radius * 0.5 if plan is None else plan
        shape = bmesh.new()
        _cylinder(shape, radius, height / SIN_ALPHA, segments=segments, tip_radius=tip,
                  matrix=Matrix.Diagonal((1.0, plan / radius, 1.0, 1.0)))
        return self.mesh(name, shape, material, x, y, z + height / 2.0, smooth=lambda face: abs(face.normal.z) < 0.6)

    def rod(self, name, x0, x1, y, z, radius, material, plan=None, segments=20):
        """Lying along x from x0 to x1, its axis `y` px north of the feet at screen
        height z: `radius` on screen, `plan` its half depth (0.6 of it by default)."""
        plan = radius * 0.6 if plan is None else min(plan, radius * 0.95)
        lift = math.sqrt(radius ** 2 - plan ** 2) / SIN_ALPHA
        shape = bmesh.new()
        _cylinder(shape, 1.0, x1 - x0, segments=segments,
                  matrix=Matrix.Diagonal((1.0, plan, lift, 1.0)) @ Matrix.Rotation(math.radians(90.0), 4, "Y"))
        return self.mesh(name, shape, material, (x0 + x1) / 2.0, y, z, smooth=lambda face: abs(face.normal.x) < 0.6)

    def disc(self, name, x, y, z, radius, thick, material, tip=None, segments=32):
        """A disc facing the camera, round on screen, centred at screen height z
        with its front face `y` px north of the feet; `tip` is its front radius."""
        shape = bmesh.new()
        _cylinder(shape, radius, thick, segments=segments, tip_radius=tip, matrix=FACE_ON)
        return self.mesh(name, shape, material, x, y + thick / 2.0, z, smooth=lambda face: abs(face.normal.y) < 0.6)

    def dial(self, name, x, y, z, radius, material):
        """A flat disc facing the camera with UVs 0..1 across it: a dial, a lens."""
        shape = bmesh.new()
        shape.loops.layers.uv.new("UVMap")
        bmesh.ops.create_circle(shape, cap_ends=True, cap_tris=False, segments=40, radius=radius * PX,
                                matrix=FACE_ON, calc_uvs=True)
        return self.mesh(name, shape, material, x, y, z)

    def ring(self, name, x, y, z, radius, tube, material, segments=40):
        """A torus facing the camera: a bezel, a rim, a key's bow."""
        shape = bmesh.new()
        _torus(shape, radius, tube, segments, 10, FACE_ON)
        return self.mesh(name, shape, material, x, y + tube, z, smooth=True)

    def ball(self, name, x, y, z, radius, material, plan=0.6, segments=16):
        """A sphere that reads round on screen, `plan` of its radius deep north-south."""
        lift = math.sqrt(1.0 - plan ** 2) / SIN_ALPHA
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=segments, v_segments=max(segments // 2, 6), radius=radius * PX,
                                  matrix=Matrix.Diagonal((1.0, plan, lift, 1.0)))
        return self.mesh(name, shape, material, x, y, z, smooth=True)

    def dome(self, name, x, y, z, radius, rise, material, plan=None, segments=32):
        """The top half of an ellipsoid sitting at screen height z, `rise` tall."""
        plan = radius * 0.5 if plan is None else plan
        shape = bmesh.new()
        bmesh.ops.create_uvsphere(shape, u_segments=segments, v_segments=segments // 2, radius=PX,
                                  matrix=Matrix.Diagonal((radius, plan, rise / SIN_ALPHA, 1.0)))
        bmesh.ops.delete(shape, geom=[vert for vert in shape.verts if vert.co.z < -1e-7], context="VERTS")
        return self.mesh(name, shape, material, x, y, z, smooth=True)

    def crystal(self, name, x, y, z, radius, height, material, turn=0.3):
        """A six-sided double point, its waist at screen height z."""
        shape = bmesh.new()
        lift = height / SIN_ALPHA
        squash = Matrix.Diagonal((1.0, 0.6, 1.0, 1.0)) @ Matrix.Rotation(turn, 4, "Z")
        bmesh.ops.create_cone(shape, cap_ends=False, segments=6, radius1=radius * PX, radius2=0.0,
                              depth=lift * 0.62 * PX, matrix=squash @ Matrix.Translation((0.0, 0.0, lift * 0.31 * PX)))
        bmesh.ops.create_cone(shape, cap_ends=False, segments=6, radius1=0.0, radius2=radius * PX,
                              depth=lift * 0.38 * PX, matrix=squash @ Matrix.Translation((0.0, 0.0, -lift * 0.19 * PX)))
        bmesh.ops.remove_doubles(shape, verts=shape.verts[:], dist=1e-6)
        return self.mesh(name, shape, material, x, y, z)

    def _face_on(self, obj):
        # Built in the XY plane: stood up to face the camera, round on screen.
        obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        obj.scale = (1.0, 1.0 / SIN_ALPHA, self.stretch)
        return obj

    def gear(self, name, x, y, z, radius, thick, angle, material):
        """A cog facing the camera, its front face `y` px north of the feet."""
        shape = bmesh.new()
        body = radius * 0.82
        teeth = max(8, int(radius * 1.2))
        _cylinder(shape, body, thick, segments=max(24, teeth * 2))
        tooth_width = 2.0 * math.pi * body / teeth * 0.5
        for index in range(teeth):
            turn = angle + 2.0 * math.pi * index / teeth
            bmesh.ops.create_cube(shape, size=1.0, matrix=(
                Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation(((body + radius * 0.09) * PX, 0.0, 0.0))
                @ Matrix.Diagonal((radius * 0.2 * PX, tooth_width * PX, thick * 0.94 * PX, 1.0))))
        _cylinder(shape, radius * 0.22, thick * 1.6, segments=16)
        return self._face_on(self.mesh(name, shape, material, x, y + thick / 2.0, z))

    def wheel(self, name, x, y, z, radius, rim, spokes, thick, angle, material):
        """A spoked wheel facing the camera: rim, spokes and hub."""
        shape = bmesh.new()
        _torus(shape, radius - rim, rim, 48, 10, Matrix.Diagonal((1.0, 1.0, thick / (2.0 * rim), 1.0)))
        for face in shape.faces:
            face.smooth = True
        for index in range(spokes):
            turn = angle + 2.0 * math.pi * index / spokes
            bmesh.ops.create_cube(shape, size=1.0, matrix=(
                Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation(((radius - rim) / 2.0 * PX, 0.0, 0.0))
                @ Matrix.Diagonal(((radius - rim) * PX, rim * 0.7 * PX, thick * 0.6 * PX, 1.0))))
        _cylinder(shape, rim * 1.6, thick * 1.4, segments=20)
        return self._face_on(self.mesh(name, shape, material, x, y + thick / 2.0, z))

    def wire(self, name, points, radius, material):
        """A lead or pipe through (x, y, z) points of the prop's frame."""
        return self.keep(_wire(self.id + name, [(self.cx + x, self.feet - y, z / SIN_ALPHA) for x, y, z in points],
                               radius, material, self.stretch))

    def plane(self, name, x, y, z0, z1, width, material):
        """A flat panel facing the camera, UVs 0..1, `y` px north of the feet."""
        corners = [(x - width / 2.0, z0), (x + width / 2.0, z0), (x + width / 2.0, z1), (x - width / 2.0, z1)]
        mesh = bpy.data.meshes.new(self.id + name)
        mesh.from_pydata([tuple(self.at(across, y, up)) for across, up in corners], [], [(0, 1, 2, 3)])
        layer = mesh.uv_layers.new(name="UVMap")
        for loop, uv in zip(layer.data, ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))):
            loop.uv = uv
        mesh.materials.append(material)
        obj = bpy.data.objects.new(self.id + name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return self.keep(obj)

    def slab(self, name, outline, front, depth, material):
        """A flat piece facing the camera: `outline` is (x, z) points in screen
        px, extruded from `front` px north of the feet back by `depth`."""
        shape = bmesh.new()
        layers = [[shape.verts.new((across * PX, plan * PX, up / SIN_ALPHA * PX)) for across, up in outline]
                  for plan in (front, front + depth)]
        shape.faces.new(layers[0])
        shape.faces.new(list(reversed(layers[1])))
        for index in range(len(outline)):
            following = (index + 1) % len(outline)
            shape.faces.new((layers[0][index], layers[0][following], layers[1][following], layers[1][index]))
        bmesh.ops.recalc_face_normals(shape, faces=shape.faces[:])
        return self.mesh(name, shape, material, 0.0, 0.0, 0.0)

    def light(self, name, x, y, z, color, power, radius=0.03, mirrored=True):
        light = add_point_light(self.id + name, (self.cx + x, self.feet - y), z / SIN_ALPHA, color, power, radius,
                                self.stretch, mirrored)
        light["hd_prop"] = self.id
        self.lights.append(light)
        return light

    def glow(self, kind, x, y, z, color, radius):
        _glow(kind, self.cx + x, self.feet - y, z / SIN_ALPHA, color, radius)

    def key_light(self, power=1.4):
        """A soft key from the floor in front and to one side, so the prop reads
        as something to walk up to; it lights the floor at its foot as well. A
        wide prop gets one from each side."""
        width = self.stand["width"]
        sides = (-1.0, 1.0) if width > 60.0 else (1.0,)
        for side in sides:
            self.light("Key", side * min(width * 0.25 + 12.0, 30.0), -26.0, 34.0, (1.0, 0.86, 0.7),
                       power / len(sides) ** 0.5, radius=0.15, mirrored=False)


def _prop_metal(name, color, roughness):
    """Metal with worn, rounded edges that catch the light."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        tarnish = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=45.0, detail=6.0),
                        0.42, 0.72)
        base = _mix(nodes, links, tarnish, color, tuple(channel * 0.45 for channel in color))
        _principled(nodes, links, base, roughness=roughness, metallic=1.0, normal=_bevel(nodes, 0.004))
    return _material(name, build)


def _brass():
    return _prop_metal("PropBrass", (0.64, 0.46, 0.2), 0.3)


def _copper():
    return _prop_metal("PropCopper", (0.6, 0.31, 0.17), 0.34)


def _bronze():
    return _prop_metal("PropBronze", (0.42, 0.26, 0.12), 0.42)


def _steel():
    return _prop_metal("PropSteel", (0.55, 0.56, 0.6), 0.22)


def _cast_iron():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        rust = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=38.0, detail=6.0), 0.55, 0.8)
        color = _mix(nodes, links, rust, (0.07, 0.07, 0.08), (0.17, 0.085, 0.045))
        _principled(nodes, links, color, roughness=0.52, metallic=0.7, normal=_bevel(nodes, 0.004))
    return _material("PropCastIron", build)


def _painted(name, color):
    """Enamelled iron, chipped to dark metal along its worn edges."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        chips = _ramp(nodes, links, _noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=5.0), 0.62, 0.7)
        _principled(nodes, links, _mix(nodes, links, chips, color, (0.05, 0.05, 0.055)), roughness=0.45,
                    normal=_bevel(nodes, 0.004))
    return _material(name, build)


def _walnut():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexWave")
        grain.wave_type = "BANDS"
        grain.bands_direction = "Z"
        grain.inputs["Scale"].default_value = 40.0
        grain.inputs["Distortion"].default_value = 5.0
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        _principled(nodes, links, _mix(nodes, links, grain.outputs["Fac"], (0.16, 0.08, 0.04), (0.3, 0.16, 0.08)),
                    roughness=0.5, normal=_bevel(nodes, 0.003))
    return _material("CabinetWalnut", build)


def _bakelite():
    return _material("Bakelite", lambda nodes, links: _principled(nodes, links, (0.015, 0.012, 0.012), roughness=0.3))


def _oak():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexWave")
        grain.wave_type = "BANDS"
        grain.bands_direction = "X"
        grain.inputs["Scale"].default_value = 30.0
        grain.inputs["Distortion"].default_value = 6.0
        grain.inputs["Detail"].default_value = 3.0
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        color = _mix(nodes, links, grain.outputs["Fac"], (0.15, 0.085, 0.04), (0.32, 0.19, 0.09))
        _principled(nodes, links, color, roughness=0.6, normal=_bevel(nodes, 0.003))
    return _material("PropOak", build)


def _prop_stone():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = _noise(nodes, links, coords.outputs["Object"], scale=70.0, detail=8.0)
        color = _mix(nodes, links, grain, (0.12, 0.11, 0.13), (0.27, 0.25, 0.28))
        _principled(nodes, links, color, roughness=0.85, normal=_bump(nodes, links, grain, 0.3,
                                                                       normal=_bevel(nodes, 0.004)))
    return _material("PropStone", build)


def _parchment():
    return _material("Parchment", lambda nodes, links: _principled(nodes, links, (0.62, 0.53, 0.36), roughness=0.85))


def _cloth(name, color):
    return _material(name, lambda nodes, links: _principled(nodes, links, color, roughness=0.92))


def _liquid(name, color, strength):
    """Coloured contents seen through glass, glowing faintly."""
    return _material(name, lambda nodes, links: _principled(
        nodes, links, tuple(channel * 0.5 for channel in color), roughness=0.15, emission=color,
        emission_strength=strength))


def _clear_glass(objects):
    # Light passes the glass: lamps behind or inside it still reach the room.
    for obj in objects if isinstance(objects, (list, tuple)) else [objects]:
        obj.visible_shadow = False


def material_reaction():
    """A reaction seen through a porthole: churning orange heat, hottest at the centre."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)
        du, dv = op("SUBTRACT", u, 0.5), op("SUBTRACT", v, 0.5)
        radius = op("MULTIPLY", op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))), 2.0)
        churn = nodes.new("ShaderNodeTexNoise")
        churn.inputs["Scale"].default_value = 5.0
        churn.inputs["Detail"].default_value = 6.0
        churn.inputs["Distortion"].default_value = 2.5
        links.new(coords.outputs["UV"], churn.inputs["Vector"])
        heat = op("MULTIPLY", op("SUBTRACT", 1.15, radius), op("ADD", 0.45, churn.outputs["Fac"]))
        color = _mix(nodes, links, _ramp(nodes, links, heat, 0.3, 0.9), (1.0, 0.16, 0.02), (1.0, 0.62, 0.18))
        _principled(nodes, links, (0.05, 0.02, 0.01), roughness=0.4, emission=color,
                    emission_strength=op("MULTIPLY", heat, 3.6))
    return _material("ReactionGlow", build)


def material_light_mixing(aspect):
    """Frosted glass lit by red, green and blue lamps: where their light overlaps
    it adds up to yellow, cyan and magenta, and to white where all three meet.
    `aspect` is the panel's width over its height on screen."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        coords, u, v = _uv_parts(nodes, links)

        def spot(centre_u, centre_v):
            du = op("MULTIPLY", op("SUBTRACT", u, centre_u), aspect)
            dv = op("SUBTRACT", v, centre_v)
            distance = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
            return _ramp(nodes, links, op("SUBTRACT", 0.0, distance), -0.25, -0.21)

        # Three equal circles, each centre on the other two's rims.
        spread = 0.125
        light = nodes.new("ShaderNodeCombineColor")
        for channel, (across, up) in enumerate(((-1.0, 0.58), (1.0, 0.58), (0.0, -1.15))):
            links.new(spot(0.5 + across * spread / aspect, 0.5 + up * spread), light.inputs[channel])
        frost = _noise(nodes, links, coords.outputs["UV"], scale=40.0, detail=2.0)
        base = _mix(nodes, links, frost, (0.07, 0.07, 0.09), (0.13, 0.13, 0.16))
        _principled(nodes, links, base, roughness=0.6, emission=light.outputs[0], emission_strength=3.2)
    return _material("LightMixingPanel", build)


def material_leaf():
    """Leaves, each its own shade of green."""
    def build(nodes, links):
        geometry = nodes.new("ShaderNodeNewGeometry")
        color = _mix(nodes, links, geometry.outputs["Random Per Island"], (0.02, 0.09, 0.02), (0.13, 0.36, 0.06))
        _principled(nodes, links, color, roughness=0.42)
    return _material("PropLeaf", build)


def material_pegboard():
    """Hardboard drilled in a grid of peg holes."""
    def build(nodes, links):
        op = _MathBuilder(nodes, links)
        _coords, u, v = _uv_parts(nodes, links)
        across = op("SUBTRACT", op("FRACT", op("MULTIPLY", u, 15.0)), 0.5)
        up = op("SUBTRACT", op("FRACT", op("MULTIPLY", v, 11.0)), 0.5)
        hole = op("LESS_THAN", op("ADD", op("MULTIPLY", across, across), op("MULTIPLY", up, up)), 0.035)
        _principled(nodes, links, _mix(nodes, links, hole, (0.22, 0.15, 0.08), (0.02, 0.015, 0.01)), roughness=0.85)
    return _material("Pegboard", build)


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
    brass, copper, wood, bakelite = _brass(), _copper(), _walnut(), _bakelite()
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


def build_circuit_staged(k, rng):
    """The Circuit Room exhibit, modelled at its pixel sprite's size, then shown
    at the figures' scale and pressed to its stand's depth like the others."""
    width, height = 37.5, 92.5
    objects, bulb = build_circuit_exhibit((k.cx - width / 2.0, k.feet - height, width, height), k.stretch)
    deep = min(1.0, k.stand["depth"] / (16.0 * FIGURE_SCALE))
    pivot = world_point(k.cx, k.feet, 0.0, k.stretch)
    for obj in objects:
        offset = obj.location - pivot
        obj.location = pivot + Vector((offset.x * FIGURE_SCALE, offset.y * FIGURE_SCALE * deep,
                                       offset.z * FIGURE_SCALE))
        obj.scale = (obj.scale[0] * FIGURE_SCALE, obj.scale[1] * FIGURE_SCALE * deep, obj.scale[2] * FIGURE_SCALE)
        k.keep(obj)
    x = k.cx + (bulb[0] - k.cx) * FIGURE_SCALE
    y = k.feet + (bulb[1] - k.feet) * FIGURE_SCALE * deep
    z = bulb[2] * FIGURE_SCALE
    light = add_point_light(k.id + "Bulb", (x, y), z, (1.0, 0.66, 0.32), 0.8, 0.02, k.stretch)
    light["hd_prop"] = k.id
    k.lights.append(light)
    _glow("bulb", x, y, z, (1.0, 0.68, 0.32), 9.0)


def build_chemistry_core(k, rng):
    """The bronze reaction core: a riveted vessel on a stone plinth, the
    reaction glowing through its porthole and its heat venting up a flue."""
    stone, bronze, brass, copper, glass = _prop_stone(), _bronze(), _brass(), _copper(), _flask_glass()
    k.box("Plinth", 0.0, 0.0, 25.0, 6.0, 0.0, 8.0, stone)
    k.box("PlinthCap", 0.0, 6.0, 23.4, 1.6, 0.3, 7.5, brass)
    k.cylinder("Vessel", 0.0, 4.2, 7.6, 10.0, 43.0, bronze, plan=3.4, segments=40)
    for index, z in enumerate((8.4, 33.0, 47.6)):
        k.cylinder("Band%d" % index, 0.0, 4.2, z, 10.5, 2.2, brass, plan=3.75, segments=40)
        for step in range(-4, 5):
            turn = step * 0.33
            k.ball("Rivet%d" % index, 10.5 * math.sin(turn), 4.2 - 3.75 * math.cos(turn) - 0.1, z + 1.1, 0.5,
                   brass, segments=8)
    k.dome("Dome", 0.0, 4.2, 50.6, 10.0, 6.0, bronze, plan=3.4)
    k.cylinder("Flue", -3.5, 4.2, 54.0, 2.0, 15.0, copper, plan=1.4)
    k.cylinder("FlueCap", -3.5, 4.2, 67.6, 2.8, 2.6, copper, plan=1.9, tip=2.4)
    k.cylinder("Vent", 4.6, 4.2, 54.4, 1.2, 3.6, brass, plan=0.9)
    k.ball("VentKnob", 4.6, 4.2, 58.6, 1.1, brass)
    # The reaction itself, behind a bolted porthole.
    k.disc("PortBoss", 0.0, 0.4, 24.0, 7.0, 1.0, bronze)
    k.dial("Reaction", 0.0, 0.3, 24.0, 4.8, material_reaction())
    k.ring("Bezel", 0.0, -0.3, 24.0, 5.3, 0.85, brass)
    for index in range(8):
        turn = 2.0 * math.pi * (index + 0.5) / 8.0
        k.ball("Bolt", 6.4 * math.cos(turn), 0.15, 24.0 + 6.4 * math.sin(turn), 0.45, brass, segments=8)
    k.disc("GaugeBody", 5.8, 0.5, 41.5, 3.0, 1.4, brass)
    k.dial("Gauge", 5.8, 0.4, 41.5, 2.5, material_dial("CoreGauge", "gauge", needle=0.64))
    _clear_glass(k.cylinder("SightGlass", -7.6, 1.4, 12.0, 1.1, 12.0, glass, plan=0.6))
    k.cylinder("SightLevel", -7.6, 1.4, 12.2, 0.75, 7.5, _liquid("CoreLiquid", (1.0, 0.45, 0.1), 2.0), plan=0.4)
    for z in (11.2, 24.0):
        k.cylinder("SightCap", -7.6, 1.4, z, 1.4, 1.0, brass, plan=0.8)
    k.wire("Pipe", [(9.4, 3.8, 41.0), (11.0, 3.8, 41.0), (11.0, 3.8, 8.0), (8.8, 3.8, 8.0)], 0.9, copper)
    k.ring("Valve", 11.0, 2.2, 26.0, 1.4, 0.35, brass)
    k.light("Reaction", 0.0, -5.0, 24.0, (1.0, 0.5, 0.18), 0.3, radius=0.04)
    k.glow("lantern", 0.0, 0.3, 24.0, (1.0, 0.55, 0.2), 11.0)


def build_library_console(k, rng):
    """The light console: a walnut desk whose frosted panel shows red, green
    and blue lamplight adding up where the beams overlap."""
    walnut, brass = _walnut(), _brass()
    k.box("Plinth", 0.0, 0.0, 22.4, 2.0, 0.0, 8.0, walnut)
    k.box("Body", 0.0, 2.0, 21.2, 18.0, 0.6, 7.2, walnut)
    for index, (low, high) in enumerate(((3.6, 10.0), (11.4, 17.8))):
        k.box("Drawer%d" % index, 0.0, low, 17.6, high - low, 0.25, 0.5, walnut)
        k.ball("Pull%d" % index, 0.0, -0.3, (low + high) / 2.0, 0.85, brass, segments=10)
    k.box("Desk", 0.0, 20.0, 22.8, 1.6, 0.0, 8.0, walnut)
    k.box("DeskLip", 0.0, 20.3, 22.8, 0.8, -0.15, 0.3, brass)
    k.box("Back", 0.0, 21.6, 20.4, 30.4, 6.0, 2.0, walnut)
    low, high, wide = 25.0, 46.0, 17.0
    k.plane("Panel", 0.0, 5.9, low, high, wide, material_light_mixing(wide / (high - low)))
    for side in (-1.0, 1.0):
        k.box("Stile", side * (wide / 2.0 + 0.6), low - 1.0, 1.2, high - low + 2.0, 5.3, 0.7, brass)
    for z in (low - 1.0, high):
        k.box("Rail", 0.0, z, wide + 2.4, 1.0, 5.3, 0.7, brass)
    k.box("Crest", 0.0, 52.0, 21.4, 1.8, 5.6, 2.6, brass)
    k.disc("Arch", 0.0, 6.4, 53.8, 3.2, 1.0, brass)
    for x, name, color in ((-5.6, "Red", (1.0, 0.12, 0.08)), (0.0, "Blue", (0.14, 0.3, 1.0)),
                           (5.6, "Green", (0.12, 1.0, 0.22))):
        k.box("Arm" + name, x, 50.2, 0.6, 1.8, 2.6, 3.4, brass)
        k.cylinder("Hood" + name, x, 2.8, 47.8, 1.9, 2.4, brass, plan=1.0, tip=1.0)
        k.ball("Lens" + name, x, 2.8, 47.6, 1.05, _glow_material("Lens" + name, color, 12.0, color), plan=0.5)
        k.light(name, x, 1.2, 46.2, color, 0.1, radius=0.02)
        k.glow("bulb", x, 2.8, 47.4, color, 4.5)
    books = _book_material()
    k.box("Book0", 6.0, 21.6, 6.4, 1.1, 1.4, 4.4, books)
    k.box("Book1", 5.8, 22.7, 5.4, 1.0, 1.7, 3.8, books)
    ink = _material("InkGlass", lambda nodes, links: _principled(nodes, links, (0.02, 0.02, 0.04), roughness=0.08))
    k.cylinder("Inkwell", -6.6, 3.2, 21.6, 1.3, 1.6, ink, plan=0.8)
    k.light("Panel", 0.0, 1.0, 36.0, (0.85, 0.85, 1.0), 0.16, radius=0.08)
    k.glow("potion", 0.0, 5.9, 35.5, (0.85, 0.85, 1.0), 10.0)


def build_greenhouse_construct(k, rng):
    """The photosynthesis case: plants under glass around a glowing green core,
    a sun lamp over them, and a water tube where oxygen bubbles rise."""
    wood, brass, copper, glass = _oak(), _brass(), _copper(), _flask_glass()
    k.box("Planter", 0.0, 0.0, 25.0, 9.0, 0.0, 8.0, wood)
    for z in (1.0, 7.0):
        k.box("PlanterBand", 0.0, z, 25.4, 1.0, -0.15, 8.3, copper)
    half, front, back, low, high = 11.0, 0.8, 7.2, 9.0, 44.0
    for x in (-half, half):
        for y in (front, back):
            k.box("Post", x, low, 1.1, high - low + 1.4, y - 0.55, 1.1, brass)
        k.box("SideRail", x, high, 1.1, 1.4, front, back - front, brass)
    for y in (front, back):
        k.box("Rail", 0.0, high, half * 2.0 + 1.1, 1.4, y - 0.55, 1.1, brass)
        k.box("Sill", 0.0, low, half * 2.0 + 1.1, 1.0, y - 0.55, 1.1, brass)
    panes = [k.box("PaneFront", 0.0, low + 1.0, half * 2.0, high - low - 1.0, front - 0.15, 0.3, glass),
             k.box("PaneBack", 0.0, low + 1.0, half * 2.0, high - low - 1.0, back - 0.15, 0.3, glass),
             k.box("PaneTop", 0.0, high + 0.5, half * 2.0, 0.3, front, back - front, glass)]
    for x in (-half, half):
        panes.append(k.box("PaneSide", x, low + 1.0, 0.3, high - low - 1.0, front, back - front, glass))
    _clear_glass(panes)
    k.box("Roof", 0.0, high + 1.4, 10.0, 1.4, 2.6, 3.0, brass)
    # Leaves all round, kept off the glass and clear of the core's front.
    shape = bmesh.new()
    placed = 0
    while placed < 72:
        leaf_x = float(rng.uniform(-9.6, 9.6))
        leaf_z = low + 1.5 + float(rng.uniform(0.0, 1.0)) ** 0.85 * 31.0
        leaf_y = float(rng.uniform(2.0, 6.0))
        if abs(leaf_x) < 4.6 and abs(leaf_z - 26.0) < 5.2 and leaf_y < 4.2:
            continue
        size = float(rng.uniform(2.2, 3.8))
        matrix = (Matrix.Translation((leaf_x * PX, leaf_y * PX, leaf_z / SIN_ALPHA * PX))
                  @ Matrix.Diagonal((1.0, 0.6, 1.0 / SIN_ALPHA, 1.0))
                  @ Matrix.Rotation(float(rng.uniform(0.0, 2.0 * math.pi)), 4, "Z")
                  @ Matrix.Rotation(float(rng.uniform(-0.9, 0.9)), 4, "X")
                  @ Matrix.Diagonal((size, size * 0.42, 0.22, 1.0)))
        bmesh.ops.create_uvsphere(shape, u_segments=8, v_segments=5, radius=PX, matrix=matrix)
        placed += 1
    k.mesh("Leaves", shape, material_leaf(), 0.0, 0.0, 0.0, smooth=True)
    stem = _material("PropStem", lambda nodes, links: _principled(nodes, links, (0.05, 0.14, 0.03), roughness=0.6))
    for index in range(6):
        base_x = -7.5 + index * 3.0
        points = [(base_x, 4.0, low + 0.5)]
        for step in range(1, 4):
            points.append((base_x + float(rng.uniform(-2.0, 2.0)), float(rng.uniform(2.6, 5.8)), low + 0.5 + step * 9.5))
        k.wire("Stem%d" % index, points, 0.32, stem)
    k.cylinder("CoreStand", 0.0, 4.0, low, 0.6, 13.4, brass, plan=0.45)
    k.ball("Core", 0.0, 4.0, 26.0, 3.6, _glow_material("PhotosynthesisCore", (0.35, 1.0, 0.3), 7.0, (0.2, 0.5, 0.15)),
           plan=0.5)
    k.light("Core", 0.0, 1.4, 26.0, (0.35, 1.0, 0.4), 0.3, radius=0.03)
    k.glow("potion", 0.0, 4.0, 26.0, (0.35, 1.0, 0.4), 11.0)
    # The sun lamp, on an arm from the case's back corner.
    k.cylinder("LampPost", 10.2, 6.6, high + 1.4, 0.75, 13.6, brass, plan=0.5)
    k.rod("LampArm", -0.4, 10.6, 6.0, 58.6, 0.65, brass, plan=0.4)
    k.cylinder("LampStem", 0.0, 5.0, 56.4, 0.45, 2.2, brass, plan=0.35)
    k.cylinder("LampHood", 0.0, 4.4, 53.4, 4.2, 3.2, brass, plan=1.9, tip=1.3)
    k.ball("LampBulb", 0.0, 4.4, 53.0, 1.4, _glow_material("SunLampBulb", (1.0, 0.86, 0.6), 14.0, (1.0, 0.9, 0.7)),
           plan=0.5)
    k.light("Sun", 0.0, 3.4, 51.2, (1.0, 0.86, 0.62), 0.5, radius=0.03)
    k.glow("bulb", 0.0, 4.4, 53.0, (1.0, 0.85, 0.6), 7.0)
    # Oxygen bubbling up a water tube beside the case.
    _clear_glass(k.cylinder("Tube", -12.9, 3.6, low, 1.2, 32.0, glass, plan=0.8))
    k.cylinder("Water", -12.9, 3.6, low + 0.4, 0.95, 28.0, _liquid("TubeWater", (0.3, 0.75, 0.6), 0.5), plan=0.6)
    bubble = _glow_material("Bubble", (0.85, 1.0, 0.95), 2.0, (0.9, 1.0, 1.0))
    for z in (13.0, 17.4, 21.0, 25.8, 29.6, 33.8):
        k.ball("Bubble", -12.9 + float(rng.uniform(-0.35, 0.35)), 3.0, z, float(rng.uniform(0.3, 0.5)), bubble)
    k.cylinder("TubeFoot", -12.9, 3.6, low - 0.8, 1.3, 1.0, brass, plan=0.9)
    k.cylinder("TubeCap", -12.9, 3.6, low + 32.0, 1.5, 1.4, brass, plan=1.0)
    k.wire("TubePipe", [(-12.9, 3.6, low + 33.4), (-12.9, 3.6, low + 35.2), (-11.0, 3.6, low + 35.2)], 0.45, copper)


def build_dining_clock(k, rng):
    """A walnut longcase clock at eight minutes to midnight, with a candle clock
    and an hourglass beside it: time told three independent ways."""
    walnut, brass, glass, steel = _walnut(), _brass(), _flask_glass(), _steel()
    k.box("Skirt", 0.0, 0.0, 22.6, 2.4, 0.0, 8.0, walnut)
    k.box("Base", 0.0, 2.4, 21.0, 12.6, 0.6, 7.2, walnut)
    k.box("BasePanel", 0.0, 5.0, 14.6, 7.4, 0.3, 0.5, walnut)
    k.box("Waist", 0.0, 15.0, 22.0, 1.6, 0.2, 7.6, walnut)
    low, high = 16.6, 51.0
    for side in (-1.0, 1.0):
        k.box("TrunkSide", side * 7.6, low, 2.2, high - low, 1.2, 6.0, walnut)
    k.box("TrunkBack", 0.0, low, 13.4, high - low, 5.6, 1.6, walnut)
    k.box("Velvet", 0.0, low, 13.0, high - low, 5.45, 0.1, _cloth("ClockVelvet", (0.07, 0.02, 0.05)))
    for z in (low, high - 2.6):
        k.box("TrunkRail", 0.0, z, 13.4, 2.6, 1.2, 1.2, walnut)
    k.box("PendulumRod", 0.0, 25.0, 0.55, 23.0, 3.0, 0.4, brass)
    k.disc("Bob", 0.0, 2.7, 25.0, 3.3, 0.5, brass, tip=2.9)
    for side in (-1.0, 1.0):
        k.cylinder("Weight", side * 3.6, 3.8, 33.0, 1.05, 7.5, brass, plan=0.7)
        k.box("Chain", side * 3.6, 40.5, 0.3, 8.0, 3.7, 0.2, steel)
    _clear_glass(k.box("Glass", 0.0, low + 2.6, 13.4, high - low - 5.2, 1.0, 0.25, glass))
    k.box("Hood", 0.0, 51.0, 22.0, 18.0, 0.4, 7.6, walnut)
    for side in (-1.0, 1.0):
        k.cylinder("Column", side * 10.0, 1.0, 51.0, 0.95, 18.0, brass, plan=0.6)
    k.disc("DialPlate", 0.0, 0.2, 60.0, 8.2, 0.3, brass)
    k.dial("Dial", 0.0, 0.0, 60.0, 6.8, material_dial("ClockFace", "clock"))
    k.ring("Bezel", 0.0, -0.4, 60.0, 7.2, 0.6, brass)
    k.box("Cornice", 0.0, 69.0, 25.0, 2.0, 0.0, 8.0, walnut)
    k.disc("Pediment", 0.0, 4.0, 71.0, 5.2, 1.4, walnut, segments=40)
    k.ring("PedimentTrim", 0.0, 3.6, 71.0, 5.2, 0.45, brass)
    for side in (-1.0, 1.0):
        k.ball("Finial", side * 11.0, 3.5, 72.6, 1.3, brass)
    # A candle burning down past its hour marks.
    wax = _material("CandleWax", lambda nodes, links: _principled(nodes, links, (0.8, 0.73, 0.58), roughness=0.5))
    k.cylinder("CandleDish", -13.2, 2.6, 0.0, 1.9, 0.9, brass, plan=1.1)
    k.cylinder("CandleClock", -13.2, 2.6, 0.9, 1.05, 10.2, wax, plan=0.7)
    for z in (3.4, 5.9, 8.4):
        k.cylinder("HourMark", -13.2, 2.6, z, 1.1, 0.45, _cloth("HourRed", (0.45, 0.04, 0.03)), plan=0.74)
    flame = k.ball("CandleFlame", -13.2, 2.6, 12.2, 0.6,
                   _glow_material("CandleFlame", (1.0, 0.72, 0.32), 18.0, (1.0, 0.8, 0.5)), plan=0.5)
    flame.scale.z *= 1.7
    flame.visible_shadow = False
    k.light("Candle", -13.2, 1.0, 13.0, (1.0, 0.62, 0.3), 0.18, radius=0.01)
    k.glow("candle", -13.2, 2.6, 12.2, (1.0, 0.68, 0.32), 6.0)
    # And an hourglass running.
    sand = _material("Sand", lambda nodes, links: _principled(nodes, links, (0.62, 0.44, 0.2), roughness=0.9))
    for z in (0.0, 9.2):
        k.cylinder("GlassEnd", 13.2, 2.6, z, 1.9, 0.8, walnut, plan=1.1)
    for side in (-1.0, 1.0):
        k.cylinder("GlassPost", 13.2 + side * 1.55, 2.6, 0.8, 0.28, 8.4, brass, plan=0.28)
    _clear_glass([k.cylinder("GlassLow", 13.2, 2.6, 0.8, 1.45, 4.2, glass, plan=0.87, tip=0.2),
                  k.cylinder("GlassHigh", 13.2, 2.6, 5.0, 0.2, 4.2, glass, plan=0.12, tip=1.45)])
    k.cylinder("SandLow", 13.2, 2.6, 0.9, 1.2, 1.9, sand, plan=0.72, tip=0.35)
    k.cylinder("SandHigh", 13.2, 2.6, 6.1, 0.35, 2.2, sand, plan=0.21, tip=1.05)
    k.cylinder("SandStream", 13.2, 2.6, 2.8, 0.12, 3.4, sand, plan=0.1)


def build_storage_rack(k, rng):
    """Oak shelving crowded with crates, jars, bottles, books and rolled plans;
    one small vial among them glows violet."""
    oak, dark, brass, glass, iron = _oak(), _wood(), _brass(), _flask_glass(), _cast_iron()
    for x in (-25.0, 25.0):
        k.box("Upright", x, 0.0, 2.2, 41.0, 0.0, 8.0, oak)
        k.ball("Cap", x, 4.0, 42.2, 1.3, brass)
    k.box("Divider", 0.0, 0.0, 1.4, 41.0, 0.8, 7.0, oak)
    for index, z in enumerate((0.4, 13.5, 26.5, 39.4)):
        k.box("Shelf%d" % index, 0.0, z, 48.0, 1.6, 0.3, 7.6, oak)
    for index in range(6):
        k.box("Plank%d" % index, -20.0 + index * 8.0, 0.4, 7.7, 40.6, 7.1, 0.8, dark)
    floor = 2.0
    k.box("CrateA", -17.0, floor, 11.0, 8.0, 1.0, 6.2, oak)
    for z in (3.0, 5.6, 8.2):
        k.box("CrateSlat", -17.0, z, 11.4, 1.0, 0.8, 0.3, dark)
    k.box("CrateB", -6.5, floor, 8.0, 6.0, 1.4, 5.8, oak)
    k.box("CrateLid", -6.5, floor + 6.0, 8.4, 0.8, 1.2, 6.2, dark)
    k.ball("Sack", 8.0, 4.0, floor + 4.4, 4.4, _cloth("Sackcloth", (0.36, 0.28, 0.17)), plan=0.55)
    k.box("Tin", 17.5, floor, 7.0, 4.6, 1.6, 5.0, iron)
    k.box("TinLid", 17.5, floor + 4.6, 7.4, 0.7, 1.4, 5.4, brass)
    floor = 15.1
    for name, color, x, radius, tall in (("Amber", (1.0, 0.55, 0.15), -19.2, 2.6, 8.0),
                                         ("Green", (0.3, 0.9, 0.4), -13.2, 2.2, 6.5)):
        _clear_glass(k.cylinder("Jar" + name, x, 4.0, floor, radius, tall, glass, plan=radius * 0.6))
        k.cylinder("Fill" + name, x, 4.0, floor + 0.2, radius * 0.82, tall * 0.62, _liquid("Jar" + name, color, 0.6),
                   plan=radius * 0.5)
        k.cylinder("Lid" + name, x, 4.0, floor + tall, radius * 1.04, 1.0, brass, plan=radius * 0.63)
    bottle = _material("BottleGlass", lambda nodes, links: _principled(nodes, links, (0.03, 0.09, 0.04), roughness=0.08))
    cork = _cloth("Cork", (0.4, 0.26, 0.13))
    for index, (x, radius, tall) in enumerate(((-7.8, 1.4, 6.8), (-4.2, 1.2, 5.6))):
        k.cylinder("Bottle%d" % index, x, 4.4, floor, radius, tall, bottle, plan=radius * 0.7)
        k.cylinder("Neck%d" % index, x, 4.4, floor + tall, radius * 0.45, 2.6, bottle, plan=radius * 0.32,
                   tip=radius * 0.4)
        k.cylinder("Cork%d" % index, x, 4.4, floor + tall + 2.6, radius * 0.42, 0.9, cork, plan=radius * 0.3)
    _clear_glass([k.ball("Vial", 3.6, 3.6, floor + 1.9, 1.8, glass),
                  k.cylinder("VialNeck", 3.6, 3.6, floor + 3.5, 0.55, 2.2, glass, plan=0.4)])
    k.ball("VialGlow", 3.6, 3.6, floor + 1.8, 1.4, _glow_material("VialViolet", (0.62, 0.32, 1.0), 6.0, (0.3, 0.12, 0.6)))
    k.light("Vial", 3.6, 1.0, floor + 2.2, (0.62, 0.34, 1.0), 0.05, radius=0.01)
    k.glow("potion", 3.6, 3.6, floor + 1.9, (0.62, 0.32, 1.0), 5.0)
    paper, tie = _parchment(), _cloth("TieRed", (0.42, 0.05, 0.04))
    k.rod("Roll0", 7.6, 21.4, 2.8, floor + 1.4, 1.35, paper)
    k.rod("Roll1", 9.0, 20.4, 5.0, floor + 3.6, 1.25, paper)
    k.rod("Roll2", 8.4, 22.2, 4.0, floor + 5.9, 1.2, paper)
    k.rod("Tie", 14.2, 15.0, 2.7, floor + 1.4, 1.45, tie)
    floor = 28.1
    books = _book_material()
    x = -23.4
    while x < -7.0:
        thick = float(rng.uniform(1.2, 2.2))
        tall = float(rng.uniform(7.0, 10.0))
        deep = float(rng.uniform(5.0, 6.4))
        k.box("Book", x + thick / 2.0, floor, thick, tall, 7.4 - deep, deep, books)
        x += thick + 0.15
    for index in range(3):
        k.box("LyingBook%d" % index, -3.6, floor + index * 1.25, 5.6 - index * 0.6, 1.2, 1.6 + index * 0.3,
              5.0 - index * 0.4, books)
    k.box("Chest", 10.0, floor, 10.0, 5.6, 1.6, 5.4, oak)
    k.box("ChestLid", 10.0, floor + 5.6, 10.4, 1.6, 1.4, 5.8, dark)
    for x in (6.4, 13.6):
        k.box("ChestBand", x, floor, 0.8, 7.2, 1.3, 6.0, brass)
    k.box("ChestLock", 10.0, floor + 3.2, 1.6, 2.0, 1.2, 0.4, brass)
    k.box("LanternBase", 19.6, floor, 4.2, 0.9, 2.2, 4.0, iron)
    _clear_glass(k.box("LanternGlass", 19.6, floor + 0.9, 3.4, 5.0, 2.6, 3.2, glass))
    k.box("LanternRoof", 19.6, floor + 5.9, 4.6, 1.2, 2.0, 4.4, iron)
    k.ring("LanternHandle", 19.6, 3.6, floor + 8.6, 1.4, 0.3, iron)


def build_tower_machine(k, rng):
    """The tower machine: a furnace cabinet, brass and copper drums turned by
    meshing gears, and a glass cage at the top where a violet crystal glows."""
    iron, brass, copper, glass = _cast_iron(), _brass(), _copper(), _flask_glass()
    gear_brass, gear_copper = (_gear_material("GearBrass", (0.64, 0.46, 0.2)),
                               _gear_material("GearCopper", (0.6, 0.31, 0.17)))
    k.box("Plinth", 0.0, 0.0, 31.0, 3.0, 0.0, 8.0, iron)
    k.box("Cabinet", 0.0, 3.0, 28.0, 18.0, 0.6, 7.2, iron)
    for z in (4.2, 19.6):
        for index in range(9):
            k.ball("Rivet", -12.0 + index * 3.0, 0.45, z, 0.42, brass, segments=8)
    k.box("FireDoor", 0.0, 6.0, 13.0, 10.0, 0.2, 0.6, iron)
    k.box("FireSlit", 0.0, 9.2, 10.0, 1.8, 0.05, 0.3,
          _glow_material("FurnaceGlow", (1.0, 0.42, 0.1), 10.0, (0.5, 0.15, 0.03)))
    for x in (-3.0, 0.0, 3.0):
        k.box("FireBar", x, 8.6, 0.6, 3.0, -0.15, 0.3, iron)
    k.disc("GaugeBody", -9.5, 0.3, 14.5, 2.6, 1.0, brass)
    k.dial("Gauge", -9.5, 0.2, 14.5, 2.2, material_dial("TowerGauge", "gauge", needle=0.4))
    for index, (low, high, radius, metal) in enumerate(((21.0, 33.0, 12.5, brass), (33.0, 43.0, 10.5, copper))):
        k.cylinder("Drum%d" % index, 0.0, 4.0, low, radius, high - low, metal, plan=3.6, segments=40)
        for z in (low, high - 1.2):
            k.cylinder("DrumBand%d" % index, 0.0, 4.0, z, radius + 0.4, 1.2, iron, plan=3.9, segments=40)
    k.gear("GearA", -5.5, 0.1, 28.0, 6.4, 0.8, 0.1, gear_brass)
    k.gear("GearB", 4.0, -0.1, 31.5, 4.6, 0.8, 0.25, gear_copper)
    k.gear("GearC", -0.8, 0.3, 37.9, 3.4, 0.7, 0.0, gear_brass)
    k.cylinder("Neck", 0.0, 4.0, 43.0, 6.4, 4.0, iron, plan=2.8)
    k.cylinder("CageFloor", 0.0, 4.0, 47.0, 7.2, 1.4, brass, plan=3.2)
    _clear_glass(k.cylinder("Cage", 0.0, 4.0, 48.4, 6.2, 16.6, glass, plan=2.9))
    for x, y in ((-4.4, 1.9), (4.4, 1.9), (-4.4, 6.1), (4.4, 6.1)):
        k.cylinder("CagePost", x, y, 48.4, 0.55, 16.6, brass, plan=0.45)
    k.cylinder("CrystalSeat", 0.0, 4.0, 48.4, 2.6, 1.8, brass, plan=1.4, tip=1.6)
    k.crystal("Crystal", 0.0, 4.2, 55.5, 2.6, 10.0,
              _glow_material("KeyCrystal", (0.55, 0.22, 1.0), 2.6, (0.3, 0.12, 0.6)))
    k.cylinder("CapPlate", 0.0, 4.0, 65.0, 7.4, 1.6, brass, plan=3.3)
    k.dome("CapDome", 0.0, 4.0, 66.6, 5.6, 4.0, copper, plan=2.6)
    k.cylinder("Spire", 0.0, 4.0, 70.2, 0.9, 7.6, brass, plan=0.6, tip=0.1)
    k.ball("SpireBall", 0.0, 4.0, 72.2, 1.1, brass)
    k.wire("PipeRight", [(13.6, 3.6, 12.0), (14.6, 3.6, 12.0), (14.6, 3.6, 45.5), (11.0, 3.6, 49.5),
                         (7.2, 3.8, 49.5)], 0.9, copper)
    for z in (24.0, 38.0):
        k.cylinder("Flange", 14.6, 3.6, z, 1.3, 0.8, brass, plan=0.9)
    k.wire("PipeLeft", [(-13.6, 3.6, 17.0), (-15.0, 3.6, 17.0), (-15.0, 3.6, 30.0), (-12.6, 3.6, 30.0)], 0.75, copper)
    k.light("Furnace", 0.0, -3.0, 10.0, (1.0, 0.45, 0.12), 0.4, radius=0.04)
    k.light("Crystal", 0.0, 1.6, 56.0, (0.62, 0.34, 1.0), 0.3, radius=0.02)
    k.glow("lantern", 0.0, 0.0, 10.0, (1.0, 0.5, 0.15), 9.0)
    k.glow("crystal", 0.0, 4.2, 56.5, (0.62, 0.34, 1.0), 11.0)


def build_engine_machine(k, rng):
    """The engine machine: a riveted boiler fired from the left, a piston
    driving a heavy flywheel, and a brass winding key on its gearbox."""
    iron, brass, steel = _cast_iron(), _brass(), _steel()
    boiler = _painted("BoilerGreen", (0.05, 0.12, 0.08))
    fire = _glow_material("FurnaceGlow", (1.0, 0.42, 0.1), 10.0, (0.5, 0.15, 0.03))
    gear_brass = _gear_material("GearBrass", (0.64, 0.46, 0.2))
    k.box("Bed", 0.0, 0.0, 104.0, 5.0, 0.0, 6.0, iron)
    k.box("BedTrim", 0.0, 4.4, 104.4, 0.8, -0.1, 0.4, brass)
    k.box("Firebox", -47.2, 5.0, 10.4, 20.0, 0.4, 5.6, iron)
    k.box("FireDoor", -47.2, 8.0, 7.0, 8.4, 0.1, 0.4, iron)
    k.box("FireGrate", -47.2, 9.4, 5.2, 5.6, 0.0, 0.15, fire)
    for x in (-49.0, -47.2, -45.4):
        k.box("FireBar", x, 9.2, 0.5, 6.0, -0.12, 0.2, iron)
    k.rod("Boiler", -42.0, -12.0, 3.0, 16.5, 9.5, boiler, plan=2.8)
    for x in (-39.0, -31.0, -23.0, -15.0):
        k.rod("BoilerBand", x - 0.6, x + 0.6, 3.0, 16.5, 9.9, brass, plan=2.9)
    for x in (-36.0, -18.0):
        k.box("Saddle", x, 5.0, 4.0, 4.0, 0.6, 4.8, iron)
    k.cylinder("Chimney", -33.0, 3.0, 24.5, 2.6, 17.0, iron, plan=1.7)
    k.cylinder("ChimneyCrown", -33.0, 3.0, 41.0, 2.8, 3.0, iron, plan=1.9, tip=3.6)
    k.cylinder("SteamDome", -19.0, 3.0, 24.0, 3.4, 4.2, brass, plan=2.0)
    k.dome("SteamCap", -19.0, 3.0, 28.2, 3.4, 2.4, brass, plan=2.0)
    k.cylinder("Whistle", -16.6, 3.0, 25.5, 0.55, 6.0, brass, plan=0.4)
    k.disc("GaugeBack", -26.0, 0.1, 16.0, 3.2, 0.6, brass)
    k.dial("Gauge", -26.0, 0.0, 16.0, 2.7, material_dial("EngineGauge", "gauge", needle=0.68))
    k.ring("GaugeRim", -26.0, -0.3, 16.0, 3.0, 0.5, brass)
    # The piston, its crosshead and the flywheel it turns.
    k.rod("Cylinder", -11.0, -1.0, 3.0, 12.0, 4.6, iron, plan=2.6)
    for x in (-11.0, -1.6):
        k.rod("CylinderFlange", x, x + 0.9, 3.0, 12.0, 5.1, brass, plan=2.8)
    k.box("CylinderFoot", -6.0, 5.0, 8.0, 3.0, 1.0, 4.0, iron)
    k.rod("PistonRod", -1.0, 6.5, 3.0, 12.0, 0.7, steel)
    k.box("Crosshead", 7.4, 10.2, 2.6, 3.6, 1.6, 2.8, steel)
    for z in (9.6, 14.4):
        k.rod("Slide", 3.0, 11.5, 3.6, z, 0.45, steel)
    k.box("SlideFoot", 9.5, 5.0, 2.0, 4.4, 2.0, 2.4, iron)
    wheel_x, wheel_z, radius = 25.0, 21.0, 15.0
    k.box("Pedestal", wheel_x, 5.0, 5.0, 16.0, 4.0, 1.8, iron)
    k.wheel("Flywheel", wheel_x, 0.6, wheel_z, radius, 1.5, 6, 1.4, 0.2, iron)
    k.disc("Hub", wheel_x, -0.6, wheel_z, 2.2, 0.6, brass, tip=1.5)
    crank = math.radians(205.0)
    pin = (wheel_x + 6.2 * math.cos(crank), wheel_z + 6.2 * math.sin(crank))
    k.disc("CrankPin", pin[0], -0.9, pin[1], 0.9, 0.5, steel)
    k.wire("ConRod", [(8.6, -0.2, 12.0), (pin[0], -0.5, pin[1])], 0.7, steel)
    # The gearbox and the winding key that sets it going.
    k.box("Gearbox", 46.8, 5.0, 11.0, 15.0, 0.6, 5.2, iron)
    k.box("GearboxPlate", 46.8, 7.0, 8.4, 11.0, 0.35, 0.3, brass)
    k.gear("BoxGearA", 44.8, 0.0, 12.0, 3.4, 0.6, 0.0, gear_brass)
    k.gear("BoxGearB", 49.3, 0.0, 15.4, 2.3, 0.6, 0.3, gear_brass)
    k.cylinder("KeyCollar", 46.4, 3.0, 20.0, 1.6, 1.6, brass, plan=1.0)
    k.cylinder("KeyShaft", 46.4, 3.0, 21.6, 0.75, 4.4, brass, plan=0.55)
    k.box("KeyWeb", 46.4, 26.0, 1.4, 4.4, 2.2, 1.2, brass)
    for side in (-1.0, 1.0):
        k.ring("KeyBow", 46.4 + side * 2.9, 2.0, 29.2, 2.3, 0.85, brass)
    k.light("Fire", -47.2, -3.0, 12.0, (1.0, 0.45, 0.12), 0.45, radius=0.04)
    k.glow("lantern", -47.2, 0.0, 12.0, (1.0, 0.5, 0.15), 10.0)


def build_workshop_machine(k, rng):
    """The workshop machine: a workbench with a vise, tools on a pegboard and
    a gooseneck lamp, beside a drill press belted to its flywheel."""
    oak, iron, brass, copper, steel = _oak(), _cast_iron(), _brass(), _copper(), _steel()
    green = _painted("MachineGreen", (0.06, 0.15, 0.1))
    gear_brass = _gear_material("GearBrass", (0.64, 0.46, 0.2))
    bench_x = -15.0
    for x in (-32.6, 2.6):
        for front in (0.6, 7.6):
            k.box("Leg", x, 0.0, 2.0, 21.0, front, 1.8, oak)
    k.box("LowShelf", bench_x, 5.0, 36.4, 1.2, 1.0, 8.0, oak)
    k.box("Apron", bench_x, 18.0, 37.0, 3.0, 0.4, 9.0, oak)
    k.box("Top", bench_x, 21.0, 38.0, 2.6, 0.0, 10.0, oak)
    k.box("BoardBack", bench_x, 23.6, 38.0, 33.0, 9.0, 1.0, oak)
    k.plane("Pegboard", bench_x, 8.95, 25.0, 55.6, 35.6, material_pegboard())
    for x in (bench_x - 18.4, bench_x + 18.4):
        k.box("BoardStile", x, 23.6, 1.2, 33.0, 8.6, 0.6, oak)
    k.box("BoardRail", bench_x, 55.6, 38.0, 1.0, 8.6, 0.6, oak)
    # Tools hung on the pegboard.
    k.box("HammerHandle", -30.0, 31.0, 1.1, 11.0, 8.2, 0.6, oak)
    k.box("HammerHead", -30.0, 42.0, 5.4, 2.2, 7.9, 0.9, steel)
    k.box("WrenchShaft", -25.0, 32.0, 1.2, 11.0, 8.2, 0.5, steel)
    k.ring("WrenchHead", -25.0, 8.0, 44.6, 1.7, 0.55, steel)
    k.box("SawBlade", -16.0, 44.0, 10.0, 4.0, 8.5, 0.2, steel)
    k.box("SawHandle", -9.6, 43.2, 3.0, 5.6, 8.1, 0.8, oak)
    for index, (x, color) in enumerate(((-5.5, (0.45, 0.06, 0.04)), (-3.8, (0.5, 0.36, 0.06)),
                                        (-2.1, (0.05, 0.25, 0.25)))):
        k.cylinder("DriverShaft%d" % index, x, 8.4, 33.0, 0.32, 7.0, steel, plan=0.25)
        k.cylinder("DriverHandle%d" % index, x, 8.4, 40.0, 0.75, 4.2, _cloth("Handle%d" % index, color), plan=0.5)
    k.ring("WireCoil", -20.5, 7.8, 33.5, 2.6, 0.75, copper)
    k.ring("WireCoilInner", -20.5, 7.7, 33.5, 1.7, 0.6, copper)
    # The vise, a hammer and a gear left on the bench.
    k.box("ViseBase", -28.0, 23.6, 5.0, 1.6, 0.6, 4.4, iron)
    k.box("ViseBody", -28.0, 25.2, 4.2, 3.6, 0.8, 3.6, green)
    for offset in (-1.0, 1.0):
        k.box("ViseJaw", -28.0 + offset * 1.5, 28.8, 1.2, 2.4, 1.2, 3.0, steel)
    k.rod("ViseBar", -31.6, -24.4, 0.2, 26.8, 0.45, steel)
    for x in (-31.6, -24.4):
        k.ball("ViseKnob", x, 0.2, 26.8, 0.7, steel)
    k.rod("BenchHandle", -20.0, -13.0, 3.6, 24.3, 0.6, oak)
    k.box("BenchHead", -12.2, 23.6, 1.6, 2.4, 2.2, 2.8, steel)
    k.gear("BenchGear", -7.0, 6.4, 27.6, 3.6, 0.6, 0.2, gear_brass)
    k.box("Toolbox", -24.0, 6.2, 9.0, 4.4, 1.4, 6.0, _painted("ToolboxRed", (0.32, 0.05, 0.04)))
    k.box("ToolboxLid", -24.0, 10.6, 9.4, 0.8, 1.2, 6.4, _painted("ToolboxRed", (0.32, 0.05, 0.04)))
    k.rod("ToolboxHandle", -26.0, -22.0, 4.4, 12.2, 0.4, steel)
    k.cylinder("Bucket", -8.0, 4.6, 6.2, 3.0, 5.4, iron, plan=1.8, tip=3.4)
    # The gooseneck lamp.
    k.cylinder("LampFoot", -1.5, 6.2, 23.6, 2.2, 1.0, iron, plan=1.2)
    k.wire("LampNeck", [(-1.5, 6.2, 24.6), (-1.5, 6.0, 32.0), (-3.2, 5.4, 37.4), (-7.0, 4.6, 39.8)], 0.5, brass)
    k.cylinder("LampShade", -8.6, 4.4, 36.6, 3.2, 3.4, green, plan=1.6, tip=1.1)
    k.ball("LampBulb", -8.6, 4.4, 36.4, 1.1, _glow_material("WorkLampBulb", (1.0, 0.82, 0.55), 14.0, (1.0, 0.9, 0.7)))
    k.light("Lamp", -8.6, 3.2, 34.6, (1.0, 0.8, 0.52), 0.45, radius=0.02)
    k.glow("bulb", -8.6, 4.4, 36.0, (1.0, 0.8, 0.5), 7.0)
    # The drill press.
    k.box("PressBase", 21.5, 0.0, 20.0, 3.6, 0.8, 8.6, iron)
    k.cylinder("Column", 27.0, 6.6, 3.6, 1.9, 59.0, steel, plan=1.4)
    k.cylinder("TableCollar", 27.0, 6.6, 24.6, 2.7, 4.6, iron, plan=1.9)
    k.box("Table", 21.0, 27.0, 13.0, 1.8, 1.6, 6.0, green)
    k.box("Workpiece", 19.4, 28.8, 4.2, 2.0, 2.8, 3.0, brass)
    k.box("Head", 21.0, 47.6, 16.6, 14.0, 1.0, 8.0, green)
    k.cylinder("Quill", 18.0, 4.2, 40.6, 1.55, 7.0, steel, plan=1.1)
    k.cylinder("Chuck", 18.0, 4.2, 37.6, 1.5, 3.0, steel, plan=1.05, tip=0.9)
    k.cylinder("Bit", 18.0, 4.2, 32.0, 0.12, 5.6, steel, tip=0.38)
    k.disc("FeedHub", 30.0, 1.2, 54.0, 1.4, 1.0, steel)
    for turn in (40.0, 160.0, 280.0):
        end = (30.0 + 4.4 * math.cos(math.radians(turn)), 54.0 + 4.4 * math.sin(math.radians(turn)))
        k.wire("FeedArm", [(30.0, 1.0, 54.0), (end[0], 0.6, end[1])], 0.38, steel)
        k.ball("FeedKnob", end[0], 0.6, end[1], 0.85, _bakelite())
    rubber = _material("BeltRubber", lambda nodes, links: _principled(nodes, links, (0.02, 0.02, 0.02), roughness=0.7))
    k.rod("Motor", 14.0, 25.0, 7.6, 64.6, 3.0, green, plan=1.6)
    k.box("BeltGuard", 21.0, 61.6, 12.0, 2.4, 2.0, 5.0, green)
    k.wheel("Flywheel", 28.2, 0.4, 66.4, 6.2, 0.9, 5, 1.0, 0.3, iron)
    k.disc("FlywheelHub", 28.2, -0.4, 66.4, 1.2, 0.5, brass)
    k.disc("MotorPulley", 14.0, 0.6, 66.0, 2.2, 1.0, steel)
    k.wire("BeltTop", [(14.0, 0.9, 68.2), (28.2, 0.9, 72.6)], 0.4, rubber)
    k.wire("BeltLow", [(14.0, 1.4, 63.8), (21.0, 1.4, 61.8)], 0.4, rubber)


PROP_BUILDERS = {
    "ChemistryRoomKnowledge": build_chemistry_core,
    "CircuitRoomKnowledge": build_circuit_staged,
    "LibraryRoomKnowledge": build_library_console,
    "GreenhouseRoomKnowledge": build_greenhouse_construct,
    "DiningHallKnowledge": build_dining_clock,
    "StorageRack": build_storage_rack,
    "FinalKeyMachine1": build_tower_machine,
    "FinalKeyMachine2": build_engine_machine,
    "FinalKeyMachine3": build_workshop_machine,
}


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
    for number, stairs in enumerate(layout.stairs):
        _stair_lights(layout, stairs, number, stretch)


def _stair_lights(layout, stairs, number, stretch):
    centre = (stairs["left"] + stairs["right"]) / 2.0
    for index, fraction in enumerate((0.3, 0.6)):
        y = stairs["top"] + (stairs["bottom"] - stairs["top"]) * fraction
        z = float(layout.height[int(y), int(centre)]) + 6.0
        add_point_light("StairGlow%d_%d" % (number, index), (centre, y), z, (0.62, 0.38, 1.0), 0.5, 0.05, stretch, mirrored=False)
        _glow("crystal", centre, y, z, (0.62, 0.38, 1.0), 14.0)
    for side, x in (("West", stairs["left"] - 14.0), ("East", stairs["right"] + 14.0)):
        y = stairs["top"] + 8.0
        if layout.height[int(y), int(x)] > 0.0:
            _candle_group("StairCandles%d%s" % (number, side), x, y, float(layout.height[int(y), int(x)]), stretch)


def add_hd_props(meta, stretch, only=None):
    """Builds each staged prop on its stand, with its own lights. The props stay
    out of the Hall render's camera, yet cast their shadows and bounce their
    light into it, so each one stands in the room when laid over it."""
    props = {}
    for prop_id, stand in STANDS.items():
        if only and prop_id not in only:
            continue
        kit = PropKit(prop_id, stand, stretch)
        PROP_BUILDERS[prop_id](kit, np.random.default_rng(SEED + sum(map(ord, prop_id))))
        kit.key_light()
        for obj in kit.made:
            obj.visible_camera = False
        props[prop_id] = kit
        print("HD PROP %s: %d parts, %d lights" % (prop_id, len(kit.made), len(kit.lights)))
    return props


def _read_rgba(path):
    """An 8-bit PNG's px as stored, top row first."""
    image = bpy.data.images.load(os.path.abspath(path), check_existing=False)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return np.rint(pixels.reshape(height, width, 4)[::-1] * 255.0).astype(np.uint8)


def _crop_shown(path, left, top, size, scale, origin):
    """Crops a prop's render to the px the game counts as shown (alpha above
    VISIBLE_ALPHA); returns their rect on screen in game px. The render's
    top-left render px is (left, top) of the region's render."""
    rgba = _read_rgba(path)
    height, width = rgba.shape[:2]
    if (width, height) != tuple(size):
        print("WARNING prop render %s is %dx%d, expected %dx%d" % (path, width, height, size[0], size[1]))
    shown = rgba[..., 3] > VISIBLE_ALPHA * 255.0
    rows, columns = np.flatnonzero(shown.any(axis=1)), np.flatnonzero(shown.any(axis=0))
    if len(rows) == 0:
        raise SystemExit("Prop render %s shows nothing" % path)
    crop = np.ascontiguousarray(rgba[rows[0]:rows[-1] + 1, columns[0]:columns[-1] + 1])
    _write_png(path, crop)
    return [round(origin[0] + (left + int(columns[0])) / scale, 2), round(origin[1] + (top + int(rows[0])) / scale, 2),
            round(crop.shape[1] / scale, 2), round(crop.shape[0] / scale, 2)]


def render_props(props, out, meta, listed, scale):
    """Each staged prop alone over transparency, cropped to the px it shows, and
    <render>-props.json: per prop its node, its image, the rect it shows on
    screen and the move from its place in the game that stages it there."""
    scene = bpy.context.scene
    render = scene.render
    x0, y0, width, height = meta["region"]
    columns, rows = render.resolution_x, render.resolution_y
    shown = [obj for obj in scene.objects if obj.type in ("MESH", "CURVE")]
    camera_flags = {obj.name: obj.visible_camera for obj in shown}
    entries = []
    for prop_id, kit in props.items():
        stand = kit.stand
        for obj in shown:
            obj.visible_camera = obj.get("hd_prop") == prop_id
        margin = PROP_RENDER_MARGIN_PX
        left = max(int(math.floor((stand["left"] - margin - x0) * scale)), 0)
        right = min(int(math.ceil((stand["right"] + margin - x0) * scale)), columns)
        top = max(int(math.floor((stand["feet"] - stand["height"] - margin - y0) * scale)), 0)
        bottom = min(int(math.ceil((stand["feet"] + margin - y0) * scale)), rows)
        _set_border(render, left, top, right, bottom)
        render.film_transparent = True
        render.image_settings.color_mode = "RGBA"
        image = os.path.splitext(out)[0] + "-prop-%s.png" % prop_id
        render_to(image)
        rect = _crop_shown(image, left, top, (right - left, bottom - top), scale, (x0, y0))
        game = listed.get(prop_id) or {}
        entry = {"id": prop_id, "root": game.get("path", ""), "image": os.path.basename(image), "rect": rect}
        if game.get("rect"):
            old = game["rect"]
            entry["move"] = [round(rect[0] + rect[2] / 2.0 - (old[0] + old[2] / 2.0), 2),
                             round(rect[1] + rect[3] - (old[1] + old[3]), 2)]
        entries.append(entry)
        print("PROP %s shows %.1f x %.1f at (%.1f, %.1f): feet %.1f on a stand at %.1f, move %s" % (
            prop_id, rect[2], rect[3], rect[0], rect[1], rect[1] + rect[3], stand["feet"], entry.get("move")))
    render.use_border = False
    render.film_transparent = False
    render.image_settings.color_mode = "RGB"
    for obj in shown:
        obj.visible_camera = camera_flags[obj.name]
    path = os.path.splitext(out)[0] + "-props.json"
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/hall_prototype.py", "props": entries}, handle, indent=1)
    print("PROPS %d -> %s" % (len(entries), path))


def _set_border(render, left, top, right, bottom):
    """Render only render px left..right x top..bottom (top row first).
    Blender truncates the border to whole px: aim at px centres."""
    columns, rows = render.resolution_x, render.resolution_y
    render.use_border = True
    render.use_crop_to_border = True
    render.border_min_x = (left + 0.5) / columns
    render.border_max_x = (right + 0.5) / columns
    render.border_min_y = (rows - bottom + 0.5) / rows
    render.border_max_y = (rows - top + 0.5) / rows


def render_doors(doors, hall, out, meta, scale):
    """Each door's leaves through the opening sequence, alone over transparency,
    with the walls and the door's own portal as holdouts so stone in front
    cuts them. All frames are cropped to the px any of them shows and laid
    side by side in one sheet per door; <render>-doors.json lists the sheets."""
    scene = bpy.context.scene
    render = scene.render
    x0, y0, width, height = meta["region"]
    columns, rows = render.resolution_x, render.resolution_y
    shown = [obj for obj in scene.objects if obj.type in ("MESH", "CURVE")]
    camera_flags = {obj.name: obj.visible_camera for obj in shown}
    entries = []
    for record in doors:
        door, kit, hinges = record["door"], record["kit"], record["hinges"]
        name, inward = door["name"], door["opens"] == "in"
        leaves = {obj.name for _turn, _side, objects in hinges for obj in objects}
        held = {hall.name} | {obj.name for obj in kit.made}
        for obj in shown:
            obj.visible_camera = obj.name in leaves or obj.name in held
            obj.is_holdout = obj.name in held
        left = max(int(math.floor((door["x"] - PORTAL_HALF_PX - 4 - x0) * scale)), 0)
        right = min(int(math.ceil((door["x"] + PORTAL_HALF_PX + 4 - x0) * scale)), columns)
        top = max(int(math.floor((door["face_y"] - 50.0 - y0) * scale)), 0)
        bottom = min(int(math.ceil((door["face_y"] + 18.0 - y0) * scale)), rows)
        _set_border(render, left, top, right, bottom)
        render.film_transparent = True
        render.image_settings.color_mode = "RGBA"
        frames = []
        for index, angle in enumerate(DOOR_ANGLES):
            for turn, side, _objects in hinges:
                turn.rotation_euler = (0.0, 0.0, math.radians(angle) * (-side if inward else side))
            path = os.path.splitext(out)[0] + "-door-%s-%02d.png" % (name, index)
            render_to(path)
            frames.append(_read_rgba(path))
            os.remove(path)
        for turn, _side, _objects in hinges:
            turn.rotation_euler = (0.0, 0.0, 0.0)
        shown_any = np.zeros(frames[0].shape[:2], dtype=bool)
        for frame in frames:
            shown_any |= frame[..., 3] > VISIBLE_ALPHA * 255.0
        used_rows, used_columns = np.flatnonzero(shown_any.any(axis=1)), np.flatnonzero(shown_any.any(axis=0))
        crop = (slice(used_rows[0], used_rows[-1] + 1), slice(used_columns[0], used_columns[-1] + 1))
        sheet = np.ascontiguousarray(np.concatenate([frame[crop] for frame in frames], axis=1))
        image = os.path.splitext(out)[0] + "-door-%s.png" % name
        _write_png(image, sheet)
        frame_height, frame_width = frames[0][crop].shape[:2]
        rect = [round(x0 + (left + int(used_columns[0])) / scale, 2), round(y0 + (top + int(used_rows[0])) / scale, 2),
                round(frame_width / scale, 2), round(frame_height / scale, 2)]
        entries.append({"name": name, "image": os.path.basename(image), "frames": len(DOOR_ANGLES),
                        "angles": list(DOOR_ANGLES), "rattle": DOOR_RATTLE_FRAME, "ajar": DOOR_AJAR_FRAME,
                        "rect": rect, "x": door["x"], "line": door["face_y"], "opens": door["opens"],
                        "glow": list(DOOR_THEMES.get(name, ("", (0.62, 0.38, 1.0)))[1])})
        print("DOOR %s: %d frames of %.1f x %.1f at (%.1f, %.1f)" % (name, len(frames), rect[2], rect[3], rect[0],
                                                                      rect[1]))
    render.use_border = False
    render.film_transparent = False
    render.image_settings.color_mode = "RGB"
    for obj in shown:
        obj.visible_camera = camera_flags[obj.name]
        obj.is_holdout = False
    path = os.path.splitext(out)[0] + "-doors.json"
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"generator": "tools/blender/hall_prototype.py", "doors": entries}, handle, indent=1)
    print("DOORS %d -> %s" % (len(entries), path))


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


def _portal_depth(layout, meta, depth):
    """Each door's portal stands on its line and rises above the wall: a figure
    behind the line is hidden wherever its stone covers it. The doorway and
    fanlight stay open, so a figure behind the Wake gate shows through them."""
    x0, y0, width, height = meta["region"]
    for door in layout.face_doors:
        half, line, centre = door["half"], door["face_y"], door["x"]
        outer = half + PORTAL_JAMB_PX
        top = PORTAL_SPRING_PX + outer + 0.5
        left, right = max(int(centre - outer - 4) - x0, 0), min(int(centre + outer + 5) - x0, width)
        upper, lower = max(int(line - top - 15) - y0, 0), min(int(line + 6) - y0, height)
        if right <= left or lower <= upper:
            continue
        across = np.arange(left, right)[None, :] + x0 + 0.5 - centre
        solid = np.zeros((lower - upper, right - left), dtype=bool)
        # The portal's back stands on the line; its front is about 4 px nearer.
        for nearer in (0.0, 4.0):
            rise = line + nearer - (np.arange(upper, lower)[:, None] + y0 + 0.5)
            above = rise - PORTAL_SPRING_PX
            solid |= (np.abs(across) >= half) & (np.abs(across) <= outer + 1.0) & (rise >= -1.0) & (above <= 0.0)
            solid |= (above >= 0.0) & (rise <= top) & (np.abs(across) <= outer + 1.5) & (across ** 2 + above ** 2 >= half ** 2)
            solid |= (rise >= top) & (rise <= top + 3.0) & (np.abs(across) <= outer + 3.0)
            solid |= (rise >= top + 3.0) & (across ** 2 + (rise - top - 3.0) ** 2 <= 10.2 ** 2)
        window = depth[upper:lower, left:right]
        depth[upper:lower, left:right] = np.where(solid, np.maximum(window, int(line)), window)
    return depth


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
    depth = _portal_depth(layout, meta, depth)
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
    # A prop's own collision box and a stair's corner lie within the cuts made
    # for them on purpose; only a wall missing elsewhere is a fault.
    far_missing = collision & ~_dilate(carved, reach) & ~_dilate(seen, reach)
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
    global DENSITY
    x0, y0, width, height = meta["region"]
    DENSITY = width * height / DENSITY_AREA_PX
    listed = meta.get("props") or {name: {"rect": rect} for name, rect in (meta.get("exhibits") or {}).items()}
    # Staged props stand in front of the faces. Only a prop left where the game
    # has it, inside a wall mass, needs a niche cut for it.
    alcoves = [prop["rect"] for name, prop in listed.items()
               if name not in HD_PROP_STANDS and _rect_in_region(prop["rect"], meta)]
    doors = sorted((name, point, (meta.get("door_prompts") or {}).get(name))
                   for name, point in (meta.get("doors") or {}).items())
    layout = Layout(collision, outside, math.sin(alpha), spawn=meta.get("spawn"), doors=doors, alcoves=alcoves)
    print("LAYOUT built in %.1fs" % (time.time() - started))
    global STANDS
    STANDS = prop_stands(layout, meta)

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
    doors = add_doors(layout, stretch)
    mounts = add_lamps(layout, meta, stretch)
    add_stair_lights(layout, stretch)
    add_gallery_machinery(layout, meta, stretch)
    banners = add_banners(layout, meta, stretch, mounts)
    add_floor_grates(layout, meta, stretch, [mount[:2] for mount in mounts] + [tuple(meta.get("spawn", (0, 0)))]
                     + _prop_floor())
    dress_faces(layout, meta, stretch, [(mount[0], mount[1], 6.0) for mount in mounts]
                + [(x, y, BANNER_WIDTH_PX / 2.0 + 2.0) for x, y in banners])
    route = [tuple(point) for point in meta.get("opening_route") or []]
    thresholds = [(door["x"] + offset, door["face_y"] + 6.0) for door in layout.face_doors
                  for offset in (-12.0, 0.0, 12.0)]
    keep_clear = [mount[:2] for mount in mounts] + route + _prop_floor() + thresholds
    add_floor_details(layout, meta, stretch, keep_clear)
    add_floor_story(layout, meta, stretch, keep_clear)
    add_cap_candles(layout, meta, stretch)
    add_ivy(layout, meta, stretch)
    props = add_hd_props(meta, stretch, options.get("only"))
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
    if options.get("props_only"):
        render_props(props, options["out"], meta, listed, options["scale"])
        return
    if options.get("doors_only"):
        render_doors(doors, hall, options["out"], meta, options["scale"])
        return
    render_to(options["out"])
    render_props(props, options["out"], meta, listed, options["scale"])
    render_doors(doors, hall, options["out"], meta, options["scale"])
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
