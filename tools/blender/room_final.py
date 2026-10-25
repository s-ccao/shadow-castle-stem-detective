"""The Final Room, where Mrs. Lin was found, for the Blender room prototype.
tools/blender/room_prototype.py imports it as room_final and calls build()
on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). The room is
1448 x 1086 and the game's camera follows the player through it, zoomed in.
It is built from the painted room (assets/backgrounds/final_room_arcane.png
and assets/props/FinalRoom/) as the Chemistry Room is: dark slate walls,
flagstones laid one by one, old oak and brass, every piece at a real size
against the detective (about 1.4 m, 90 px):

  north   the vault door (VaultDoorVisual) between two tall glazed cabinets
          and two brass wall lanterns; either side a lancet of violet glass
          between colonnettes, and a violet crystal lantern under a brass
          rosette; in each corner an arched alcove of scroll racks over a
          chest of drawers
  west    scroll presses and drawers along the wall, a glass vitrine and a
          long table of papers before them, a cabinet lit violet from inside,
          and a great packing crate turned askew in the south-west corner
  middle  the Ashford analysis table (FinalAnalysisBoardVisual): a round
          table 3.2 m across, its eight slate evidence panels linked by brass
          to an inner hoop, ringed on the floor by a circle of brass inlay
  east    the Knowledge Engine (KnowledgeEngineVisual): a brass armillary
          on a drum, on an octagonal stepped dais, its console glowing; scroll
          presses, two vitrines, a writing table and a chest of drawers
  south   the floor ends at a coping over the dark; the way back to the Hall
          is the painting's great door, a violet core in a brass ring between
          its leaves and the four rooms' emblems round it, between columns and
          violet lamps on tall piers; the player walks up to it and behind
          it, showing through it as in the Hall
  floor   flagstones with brass lines let into them and iron grates glowing
          violet from below; Mrs. Lin (MrsLinBody) lies where the game draws
          her, the cast's Tripo Dr. Lin posed where she fell, her notebook
          (NotebookVisual) by her hand

The table and the engine are given their real footprints, and the furniture
the painted room lets the player walk through (the west vitrine and table,
the crate and the east table) footprints of its own: the preview swaps them
into the collision while the HD room is staged.
"""
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

import character_motion as motion
import hall_prototype as hall
import room_chemistry as chem
import room_greenhouse as gh
import room_wake as wake

RP = None
MODELS = None

# The back wall stands behind the window bays; the masonry, the cabinets and
# the vault door stand out from it to FRONT_Y, where the painted floor begins.
BACK_Y = 150.0
FRONT_Y = 207.0
WALL_H = 178.0
LEAN = 40.0
LEFT_X, RIGHT_X = 52.0, 1396.0
NEAR = 1086.0 + WALL_H
CANDLE = (1.0, 0.6, 0.28)
VIOLET = (0.58, 0.3, 1.0)
ORB = (0.6, 0.8, 1.0)
ROUND = wake.ROUND
SIN = hall.SIN_ALPHA
BAYS = ((342.0, 472.0), (975.0, 1103.0))
LANCETS = ((391.0, 423.0), (1023.0, 1055.0))
LANCET_SILL, LANCET_SPRING, LANCET_APEX = 30.0, 88.0, 110.0
# The analysis table: its centre on the floor, its radius (3.2 m across) and
# its height (81 cm). The circle of brass round it.
TABLE = (725.0, 548.0)
TABLE_R = 160.0
TABLE_TOP = 52.0
CIRCLE_R = 255.0
# The Knowledge Engine's dais: its centre and the radius to its flats.
ENGINE = (1085.0, 458.0)
ENGINE_R = 120.0
NOTEBOOK = (306.0, 655.0)
# Mrs. Lin (MrsLinBody): the cast's Tripo Dr. Lin, laid where the game lays
# her body. Her floor centre is the body's FurnitureCollision's; she stands
# as tall as the cast against the detective (cm); her long axis turns from due
# east toward the south as the painted figure's does, and she rolls toward the
# room so her face and coat show.
LIN_GLB = os.path.join("prototypes", "blender_chars", "source", "dr_lin_anims.glb")
LIN_FLOOR = (346.0, 611.0)
# Her HD footprint (x0, x1, y0, y1): the painted body's north edge, her own
# width, and at the south the lowest edge she shows (her render's foot, 627.5)
# so the room offers her to a player who comes up from the south.
LIN_FOOTPRINT = (272.0, 420.0, 576.0, 630.0)
LIN_HEIGHT = 140.0
LIN_TURN = -18.0
# She has fallen forward onto her front: the model's eyes are painted open,
# so her face is down on the flagstones and the room sees her hair, her coat's
# back and her reaching arm. Laid on her right side, then rolled this far.
LIN_ROLL = 72.0
# Her limbs as they lie, in the room (x east, y north, z up; south is toward
# the camera): her lower arm reaching along the floor toward the notebook to
# the south-west, her upper hand down on the floor before her hip, holding the
# torn violet cuff, and her knees drawn up toward the room, the upper one
# further.
LIN_POSE = (
    ("RightArm", (-0.55, -0.80, -0.20)),
    ("RightForeArm", (-0.45, -0.88, -0.15)),
    ("RightHand", (-0.40, -0.90, -0.15)),
    ("LeftArm", (0.50, -0.75, -0.40)),
    ("LeftForeArm", (0.60, -0.70, -0.35)),
    ("LeftHand", (0.55, -0.75, -0.30)),
    ("LeftUpLeg", (0.55, -0.80, -0.20)),
    ("LeftLeg", (0.85, 0.45, -0.10)),
    ("RightUpLeg", (0.95, -0.25, -0.10)),
    ("RightLeg", (0.90, 0.35, -0.10)),
)
LIN_CURL = {"Right": 25.0, "Left": 65.0}
# A soft warm light over her that lights only her (light linking), so her dark
# coat reads on the dark flagstones as the painted figure does; the room's
# own light is unchanged.
LIN_KEY_POWER = 13.0
LIN_KEY_HEIGHT = 150.0
GRATES = ((203.0, 258.0), (371.0, 259.0), (1238.0, 256.0), (380.0, 628.0), (1070.0, 632.0))
# The floor's south edge either side of the gate, its corners rounding up to
# the side walls as the painted room's do. The gate's piers stand over it.
EDGE_Y = 879.0
EDGE_WEST = ((LEFT_X, 770.0), (57.0, 800.0), (69.0, 826.0), (90.0, 847.0), (120.0, 863.0), (160.0, 873.0),
             (210.0, EDGE_Y), (450.0, EDGE_Y))
EDGE_EAST = ((1000.0, EDGE_Y), (1238.0, EDGE_Y), (1288.0, 873.0), (1328.0, 863.0), (1358.0, 847.0),
             (1379.0, 826.0), (1391.0, 800.0), (RIGHT_X, 770.0))
# The gate: its piers' south faces, its leaves' face and its centre.
GATE_X = 725.0
GATE_FACE = 988.0
DOOR_FACE = 980.0
# The gate's base seen from the room, west to east: the north faces of its
# piers, bays, columns, jambs and leaves. The floor runs up to it, and the HD
# room's collision ends there, so the player walks up to the gate and behind
# it, where it stands between him and the camera.
GATE_BACK = ((458.0, 942.0), (520.0, 942.0), (520.0, 928.0), (578.0, 928.0), (578.0, 954.0), (608.0, 954.0),
             (608.0, 950.0), (622.0, 950.0), (622.0, 974.0), (828.0, 974.0), (828.0, 950.0), (842.0, 950.0),
             (842.0, 954.0), (872.0, 954.0), (872.0, 928.0), (930.0, 928.0), (930.0, 942.0), (992.0, 942.0))
# Flagstones a little larger than the Chemistry Room's, as the painting lays
# them, tipped less, so the brass let in among them sits flush.
FLAG_ROW = (28.0, 36.0)
FLAG_LENGTH = (28.0, 46.0)
FLAG_JOINT = 1.6
FILL_POWER = 50.0
SUN_POWER = 0.3
INLAY_H = 0.45


def lancet(x0, x1):
    return gh.lancet_outline(x0, x1, LANCET_SILL, LANCET_SPRING, LANCET_APEX)


SPEC = {
    "back": {"y": BACK_Y, "base": (LEFT_X, RIGHT_X), "top": (LEFT_X - LEAN, RIGHT_X + LEAN), "height": WALL_H,
             "openings": [{"outline": lancet(x0, x1), "depth": 10.0} for x0, x1 in LANCETS]},
    "left": {"base": ((LEFT_X, BACK_Y), (LEFT_X, 1000.0)), "near": NEAR},
    "right": {"base": ((RIGHT_X, BACK_Y), (RIGHT_X, 1000.0)), "near": NEAR},
    "floor": {"x": (-60.0, 1508.0), "y": (100.0, 768.0)},
    "cap": 120.0,
}


# ---------------------------------------------------------------- geometry


def plan_point(cx, cy, radius, degrees):
    """A point `radius` cm from (cx, cy) on the floor at `degrees` (0 east,
    90 south), its plan y foreshortened as the floor's is."""
    angle = math.radians(degrees)
    return cx + radius * math.cos(angle), cy + radius * math.sin(angle) * ROUND


def plan_circle(cx, cy, radius, steps=48, start=0.0, end=360.0):
    full = abs(end - start) >= 360.0
    count = steps if full else steps + 1
    return [plan_point(cx, cy, radius, start + (end - start) * index / steps) for index in range(count)]


def octagon(cx, cy, flats):
    """A regular octagon round (cx, cy) with flats facing the four winds."""
    corner = flats / math.cos(math.radians(22.5))
    return [plan_point(cx, cy, corner, 22.5 + 45.0 * index) for index in range(8)]


def prism(shape, outline, h0, h1):
    """A block into `shape`: the plan outline (x, y) from h0 up to h1."""
    bottom = [shape.verts.new((x, y, h0)) for x, y in outline]
    top = [shape.verts.new((x, y, h1)) for x, y in outline]
    shape.faces.new(top)
    shape.faces.new(list(reversed(bottom)))
    for index in range(len(outline)):
        following = (index + 1) % len(outline)
        shape.faces.new((bottom[index], bottom[following], top[following], top[index]))


def sector(shape, cx, cy, r0, r1, a0, a1, h0, h1, steps=6):
    """A piece of a ring from `a0` to `a1` degrees, r0 to r1 cm out."""
    outer = [plan_point(cx, cy, r1, a0 + (a1 - a0) * index / steps) for index in range(steps + 1)]
    inner = [plan_point(cx, cy, r0, a1 - (a1 - a0) * index / steps) for index in range(steps + 1)]
    prism(shape, outer + inner, h0, h1)


def clip(polygon, nx, ny, offset):
    """The part of `polygon` where nx * x + ny * y >= offset."""
    kept = []
    for index, (x, y) in enumerate(polygon):
        px, py = polygon[index - 1]
        here, there = nx * x + ny * y - offset, nx * px + ny * py - offset
        if (here >= 0.0) != (there >= 0.0):
            t = there / (there - here)
            kept.append((px + (x - px) * t, py + (y - py) * t))
        if here >= 0.0:
            kept.append((x, y))
    return kept


def real_box(kit, part, cx, cy, h0, h1, width, depth, turn, material, bevel=0.3, uv="box"):
    """A block `width` x `depth` cm centred (cx, cy) on the floor, turned
    `turn` degrees as a rigid thing turns: its plan is foreshortened after the
    turn, so it stays square (gh.turned_box turns the plan and shears)."""
    shape = bmesh.new()
    bmesh.ops.create_cube(shape, size=1.0, matrix=(
        Matrix.Translation((cx, cy, (h0 + h1) / 2.0)) @ Matrix.Diagonal((1.0, ROUND, 1.0, 1.0))
        @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Diagonal((width, depth, max(h1 - h0, 0.05), 1.0))))
    return kit.shape(part, shape, material, bevel=bevel, uv=uv)


def turned(cx, cy, dx, dy, turn):
    """(cx, cy) moved dx, dy cm along a thing turned `turn` degrees."""
    cosine, sine = math.cos(math.radians(turn)), math.sin(math.radians(turn))
    return cx + dx * cosine - dy * sine, cy + (dx * sine + dy * cosine) * ROUND


def face_ring(kit, part, cx, y, ch, radius, tube, material, segments=48, sides=8):
    """A ring on a south face, round on screen as the painting draws its
    dials (the Hall hangs things in screen proportions): its centre line a
    circle in (x, h) at plan y, its section `tube` px."""
    shape = bmesh.new()
    rings = []
    for index in range(segments):
        turn = 2.0 * math.pi * index / segments
        ring = []
        for side in range(sides):
            phase = 2.0 * math.pi * side / sides
            reach = radius + tube * math.cos(phase)
            ring.append(shape.verts.new((cx + reach * math.cos(turn), y - tube * math.sin(phase),
                                         ch + reach * math.sin(turn))))
        rings.append(ring)
    for index in range(segments):
        here, there = rings[index], rings[(index + 1) % segments]
        for side in range(sides):
            following = (side + 1) % sides
            shape.faces.new((here[side], there[side], there[following], here[following]))
    return kit.shape(part, shape, material, smooth=True, sharp_angle=80.0)


def face_disc(kit, part, cx, y0, y1, ch, radius, material, steps=36):
    """A disc on a south face, round on screen, from plan y0 to y1."""
    outline = [(cx + radius * math.cos(2.0 * math.pi * index / steps),
                ch + radius * math.sin(2.0 * math.pi * index / steps)) for index in range(steps)]
    return kit.slab(part, outline, y0, y1, material)


def edge_y(x):
    """The floor's south edge at x."""
    for line in (EDGE_WEST, EDGE_EAST):
        for (x0, y0), (x1, y1) in zip(line[:-1], line[1:]):
            if x0 <= x <= x1:
                return y0 + (y1 - y0) * (x - x0) / max(x1 - x0, 1e-6)
    if x < EDGE_WEST[0][0]:
        return EDGE_WEST[0][1]
    if x > EDGE_EAST[-1][0]:
        return EDGE_EAST[-1][1]
    return EDGE_Y


def floor_south(x):
    """How far south the floor runs at x: to its edge, or between the gate's
    piers to the gate's base."""
    if GATE_BACK[0][0] <= x <= GATE_BACK[-1][0]:
        for (x0, y0), (x1, y1) in zip(GATE_BACK[:-1], GATE_BACK[1:]):
            if min(x0, x1) <= x <= max(x0, x1) and y0 == y1:
                return y0
        # On a step: the nearer of the two faces it joins.
        return min(y for px, y in GATE_BACK if abs(px - x) < 1e-6)
    return edge_y(x)


# ---------------------------------------------------------------- materials


def oak():
    return chem.aged_oak()


def gold():
    """The room's brass as the painting draws it, polished and catching the
    lamps: a little less metallic than bare brass, which in a dark room
    mirrors only the dark, so it reads gold as polished brass does by lamp
    light; tarnished in its hollows."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        tarnish = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=45.0, detail=6.0),
                             0.42, 0.72)
        base = hall._mix(nodes, links, tarnish, (0.7, 0.44, 0.15), (0.34, 0.2, 0.07))
        shader = hall._principled(nodes, links, base, roughness=0.32, metallic=0.68, normal=hall._bevel(nodes, 0.004),
                                  emission=(0.62, 0.42, 0.16), emission_strength=0.04)
        shader.inputs["Coat Weight"].default_value = 0.3
    return hall._material("FinalGold", build)


def flagstone():
    """The floor's stones: worn grey rock, each stone its own part and shade
    of it, a cool grey as the painting grades them, its rim worn paler."""
    return chem.laid("FinalFlagstone", "rock_surface", 1.11, 0.56, (0.84, 0.84, 0.88), saturation=0.2,
                     per_island=True, variety=0.28, wear=0.5, ao=0.12, roughness=0.9, coat=0.1, coat_roughness=0.32)


def scroll_papers():
    """Old rolled paper and vellum, darker than a fresh sheet."""
    return tuple(hall._material("FinalScroll%d" % index, lambda nodes, links, color=color: hall._principled(
        nodes, links, color, roughness=0.85)) for index, color in enumerate(((0.36, 0.29, 0.19), (0.3, 0.24, 0.15),
                                                                              (0.42, 0.35, 0.24))))


def wall_stone():
    return RP.textured("FinalWall", "castle_wall_slates", 1.5, 0.36, (0.74, 0.7, 0.8), ao=0.3)


def dressed_stone():
    """The gate's and the piers' dressed blocks, a shade darker than the
    Chemistry Room's."""
    return RP.textured("FinalDressedStone", "large_grey_tiles", 0.5, 0.58, (0.78, 0.75, 0.84), ao=0.18)


def slate():
    """The evidence panels: dark honed slate."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=6.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, (0.025, 0.027, 0.032), (0.05, 0.052, 0.06)),
                         roughness=0.42)
    return hall._material("FinalSlate", build)


def brass_inlay():
    """Brass let into the floor, polished by feet: the painting draws its
    lines bright, so they catch every light."""
    return hall._material("FinalInlay", lambda nodes, links: hall._principled(
        nodes, links, (0.62, 0.42, 0.17), roughness=0.34, metallic=0.6, emission=(0.62, 0.42, 0.16),
        emission_strength=0.05))


def amber_lanterns():
    """The lanterns' glass, amber rather than blown white: its glow lowered
    after gh.lantern made it (the Hall's lantern glass, shared by name)."""
    material = bpy.data.materials.get("LanternGlass")
    if material is None:
        return
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Emission Strength"].default_value = 0.45
            node.inputs["Emission Color"].default_value = (1.0, 0.42, 0.12, 1.0)


def lens_glass(name="FinalLens", strength=0.06):
    """An instrument's glass: dark, faintly blue, lit a little from within."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.05, 0.07, 0.1), roughness=0.08, emission=ORB,
                                  emission_strength=strength)
        shader.inputs["Coat Weight"].default_value = 0.8
    return hall._material(name, build)


def orb_glass():
    """The engine's sealed orb: clear blown glass with a blue cast."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.75, 0.86, 1.0), roughness=0.04)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.3
    return hall._material("FinalOrbGlass", build)


def crystal_glow(name="FinalCrystal", strength=0.5):
    """A crystal that glows violet: near black and without a sheen, so the
    lamp light beside it cannot bleach it white; its colour is its glow."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.012, 0.004, 0.02), roughness=0.6, emission=(0.48, 0.18, 1.0),
                                  emission_strength=strength)
        shader.inputs["Specular IOR Level"].default_value = 0.1
    return hall._material(name, build)


def orb_glow(name="FinalOrb", strength=0.9):
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.01, 0.012, 0.02), roughness=0.6, emission=ORB,
                                  emission_strength=strength)
        shader.inputs["Specular IOR Level"].default_value = 0.1
    return hall._material(name, build)


def dark_glass():
    """A cabinet's panes: dark old glass, glossy, the shelves behind lost."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.012, 0.012, 0.016), roughness=0.06)
        shader.inputs["Coat Weight"].default_value = 0.6
    return hall._material("FinalDarkGlass", build)


def violet_glass():
    """A lancet's leaded glass, violet as the painting's: diamond quarries of
    two tints in lead cames, lit by the night outside. UVs are the opening's
    own (x, h) in px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        a = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("ADD", u, v), 9.0)), 0.5))
        b = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("SUBTRACT", u, v), 9.0)), 0.5))
        lead = op("MAXIMUM", op("GREATER_THAN", a, 0.44), op("GREATER_THAN", b, 0.44))
        pane = nodes.new("ShaderNodeTexVoronoi")
        pane.inputs["Scale"].default_value = 0.16
        links.new(coords.outputs["UV"], pane.inputs["Vector"])
        tint = hall._mix(nodes, links, pane.outputs["Distance"], (0.3, 0.1, 0.62), (0.62, 0.32, 0.95))
        glass = op("MULTIPLY", op("SUBTRACT", 1.0, lead), op("ADD", 0.7, op("DIVIDE", v, 260.0)))
        hall._principled(nodes, links, (0.02, 0.015, 0.03), roughness=0.25, emission=tint,
                         emission_strength=op("MULTIPLY", glass, 0.3))
    return hall._material("FinalVioletGlass", build)


def drop_stone():
    """The face the floor's edge drops by into the dark: stone fading to
    black, as the painting ends its floor. UVs: u along, v 0 at the top to 1."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, _u, v = hall._uv_parts(nodes, links)
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=40.0, detail=6.0)
        fade = op("POWER", op("MAXIMUM", op("SUBTRACT", 1.0, v), 0.0), 2.2)
        color = hall._mix(nodes, links, grain, (0.035, 0.032, 0.042), (0.07, 0.064, 0.08))
        color = hall._mix(nodes, links, 1.0, color, nodes_color(nodes, links, fade), blend="MULTIPLY")
        hall._principled(nodes, links, color, roughness=0.9)
    return hall._material("FinalDropStone", build)


def nodes_color(nodes, links, value):
    """A grey colour from a shader value."""
    combine = nodes.new("ShaderNodeCombineColor")
    for socket in ("Red", "Green", "Blue"):
        links.new(value, combine.inputs[socket])
    return combine.outputs["Color"]


def grate_iron(length, width):
    """An iron grate in the floor: bars and a frame, and in its gaps a faint
    violet light rising from below. UVs are px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        to_edge = op("MINIMUM", op("MINIMUM", u, op("SUBTRACT", length, u)),
                     op("MINIMUM", v, op("SUBTRACT", width, v)))
        bars = op("MAXIMUM", op("LESS_THAN", to_edge, 2.5), op("LESS_THAN", op("FRACT", op("DIVIDE", u, 4.0)), 0.45))
        bars = op("MAXIMUM", bars, op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), 0.8))
        deep = op("SUBTRACT", 1.0, op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0))
        color = hall._mix(nodes, links, bars, (0.012, 0.008, 0.02), (0.06, 0.055, 0.06))
        shader = hall._principled(nodes, links, color, roughness=op("ADD", 0.4, op("MULTIPLY", bars, 0.2)))
        links.new(op("MULTIPLY", bars, 0.8), shader.inputs["Metallic"])
        shader.inputs["Emission Color"].default_value = VIOLET + (1.0,)
        links.new(op("MULTIPLY", op("SUBTRACT", 1.0, bars), op("MULTIPLY", deep, 0.22)),
                  shader.inputs["Emission Strength"])
    return hall._material("FinalGrateIron", build)


def coping():
    return RP.textured("FinalCoping", "large_grey_tiles", 0.6, 0.9, (0.82, 0.8, 0.9), ao=0.1)


# ---------------------------------------------------------------- the north wall


def north_masonry():
    """The masonry standing out from the back wall to FRONT_Y: the corner
    blocks round the scroll alcoves' arches, the piers of the violet lamps
    and of the brass lanterns, and the stone lintel over the vault door and
    its cabinets."""
    kit = RP.Kit("NorthMasonry")
    stone, trim = wall_stone(), dressed_stone()
    for side, (outer, jamb_out, jamb_in, pier_out) in (("West", (LEFT_X, 62.0, 268.0, 342.0)),
                                                       ("East", (RIGHT_X, 1386.0, 1180.0, 1103.0))):
        lo, hi = sorted((outer, jamb_out))
        kit.box(side + "Jamb", lo, hi, BACK_Y, FRONT_Y, 0.0, WALL_H, stone, bevel=0.8, uv="box_up")
        lo, hi = sorted((jamb_in, pier_out))
        kit.box(side + "Pier", lo, hi, BACK_Y, FRONT_Y, 0.0, WALL_H, stone, bevel=0.8, uv="box_up")
        # The alcove's round arch, its spandrels and the wall over it.
        a, b = sorted((jamb_out, jamb_in))
        middle, half = (a + b) / 2.0, (b - a) / 2.0
        spring, rise = 112.0, 38.0
        curve = [(middle - half * math.cos(math.pi * index / 24), spring + rise * math.sin(math.pi * index / 24))
                 for index in range(25)]
        kit.slab(side + "Spandrel", [(a, WALL_H), (a, spring)] + curve[1:-1] + [(b, spring), (b, WALL_H)],
                 FRONT_Y - 10.0, FRONT_Y, stone, bevel=0.6)
        gh.band(kit, side + "Archivolt", [(a + 3.0, 0.0)] + curve[1:-1] + [(b - 3.0, 0.0)], 6.0, FRONT_Y - 1.0,
                FRONT_Y + 2.0, trim)
        # The violet lamp's pier: a sunk panel.
        lo, hi = sorted((jamb_in, pier_out))
        px = (lo + hi) / 2.0 + (4.0 if side == "West" else -4.0)
        kit.box(side + "PierPanel", px - 20.0, px + 20.0, FRONT_Y - 2.0, FRONT_Y + 1.0, 18.0, 158.0, trim, bevel=0.8,
                uv="box_up")
    # The lanterns' piers either side of the cabinets.
    for side, (lo, hi) in (("West", (472.0, 545.0)), ("East", (905.0, 975.0))):
        kit.box(side + "LanternPier", lo, hi, BACK_Y, FRONT_Y, 0.0, WALL_H, stone, bevel=0.8, uv="box_up")
        for edge in (lo + 4.0, hi - 10.0):
            kit.box(side + "Pilaster", edge, edge + 6.0, FRONT_Y - 1.0, FRONT_Y + 2.5, 6.0, 164.0, trim, bevel=0.8,
                    uv="box_up")
        kit.box(side + "Plinth", lo + 1.0, hi - 1.0, FRONT_Y - 1.0, FRONT_Y + 3.0, 0.0, 8.0, trim, bevel=0.8, uv="box")
    # The lintel over the cabinets and the vault door.
    kit.box("Lintel", 545.0, 905.0, BACK_Y, FRONT_Y, 166.0, WALL_H, stone, bevel=0.8, uv="box")
    kit.box("Cornice", 470.0, 977.0, FRONT_Y - 4.0, FRONT_Y + 3.0, 164.0, 170.0, trim, bevel=0.9, uv="box")
    # Each window bay's colonnettes, their capitals and the pointed hood over
    # the lancet.
    for index, ((x0, x1), (w0, w1)) in enumerate(zip(BAYS, LANCETS)):
        for x in (x0 + 22.0, x1 - 22.0):
            kit.lathe("Colonnette%d" % index, x, BACK_Y + 6.0, [(0.0, 0.0), (6.5, 0.0), (6.5, 5.0), (4.2, 8.0),
                                                                 (3.6, 100.0), (5.6, 104.0), (6.4, 110.0),
                                                                 (0.0, 110.0)], trim, plan=ROUND, segments=20)
        hood = gh.pointed_arch(w0 - 14.0, w1 + 14.0, LANCET_SPRING, LANCET_APEX + 20.0, steps=10)
        gh.band(kit, "Hood%d" % index, [(w0 - 14.0, LANCET_SILL - 6.0)] + hood + [(w1 + 14.0, LANCET_SILL - 6.0)],
                5.0, BACK_Y - 1.0, BACK_Y + 3.0, trim)
        kit.box("Sill%d" % index, w0 - 18.0, w1 + 18.0, BACK_Y - 2.0, BACK_Y + 6.0, LANCET_SILL - 6.0,
                LANCET_SILL - 1.0, trim, bevel=0.6, uv="box")
    return kit


def window_glass():
    """The lancets' violet glass in the back wall's openings, and the night
    behind each: a weak violet moon through it onto the bay's floor."""
    kit = RP.Kit("WindowGlass")
    for index, (x0, x1) in enumerate(LANCETS):
        glass = RP.polygon_mesh("FinalLancet%d" % index, lancet(x0, x1), [], lambda u, v: (u, BACK_Y - 6.0, v),
                                violet_glass(), uv_of=lambda u, v: (u, v))
        glass.visible_shadow = False
        kit.keep(glass)
        middle = (x0 + x1) / 2.0
        kit.box("Mullion%d" % index, middle - 1.2, middle + 1.2, BACK_Y - 7.0, BACK_Y - 4.0, LANCET_SILL,
                LANCET_SPRING + 6.0, hall._cast_iron(), bevel=0.2)
        direction = Vector((0.0, -math.cos(math.radians(40.0)), -math.sin(math.radians(40.0)))).normalized()
        data = bpy.data.lights.new("FinalMoon%d" % index, "SPOT")
        data.energy = 420.0
        data.color = (0.66, 0.5, 1.0)
        data.spot_size = math.radians(24.0)
        data.spot_blend = 0.4
        data.shadow_soft_size = 0.1
        moon = RP._link(bpy.data.objects.new("FinalMoon%d" % index, data))
        moon.location = RP.world(middle, BACK_Y, (LANCET_SILL + LANCET_APEX) / 2.0) - direction * 6.0
        moon.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        RP.glow("crystal", middle, BACK_Y, (LANCET_SILL + LANCET_APEX) / 2.0, VIOLET, 22.0)
    return kit


def scroll(kit, part, start, end, radius, material):
    """A rolled scroll lying or standing from `start` to `end` (x, y, h)."""
    kit.rod(part, start, end, radius, material, segments=12)


def scroll_alcoves():
    """In each corner's arched alcove, as the painting fills them: a press of
    cubbies stacked with rolled scrolls and, beside it, a chest of drawers
    with brass pulls and lock, scrolls standing on it."""
    kit = RP.Kit("ScrollAlcoves")
    wood, brass = oak(), gold()
    papers = scroll_papers()
    rng = random.Random(4413)
    for side, (press, chest) in (("West", ((64.0, 150.0), (154.0, 264.0))),
                                 ("East", ((1298.0, 1384.0), (1184.0, 1294.0)))):
        back, front = BACK_Y + 4.0, FRONT_Y - 3.0
        # The press: sides, shelves and a crown, its cubbies full of scrolls.
        x0, x1 = press
        levels = (6.0, 40.0, 74.0, 108.0, 142.0)
        chem.shelf_unit(kit, side + "Press", x0, x1, back, front, 148.0, levels[1:], wood, plinth=6.0, crown=True)
        kit.box(side + "PressDivider", (x0 + x1) / 2.0 - 1.5, (x0 + x1) / 2.0 + 1.5, back + 1.8, front - 1.0, 6.0,
                148.0, wood, bevel=0.4, uv="box_up")
        for level in levels[:-1]:
            for bay in range(2):
                a = x0 + 6.0 + bay * (x1 - x0 - 12.0) / 2.0
                b = a + (x1 - x0 - 12.0) / 2.0 - 3.0
                stack = 0
                h = level + 3.4
                while h < level + 28.0 and stack < 4:
                    for count in range(3 if stack % 2 == 0 else 2):
                        y = front - 6.0 - count * 9.0 - (4.5 if stack % 2 else 0.0)
                        if y < back + 5.0:
                            break
                        scroll(kit, "%sScroll%d_%d_%d_%d" % (side, int(level), bay, stack, count),
                               (a + rng.uniform(0.0, 3.0), y, h + 3.4), (b - rng.uniform(0.0, 3.0), y, h + 3.4),
                               3.4, rng.choice(papers))
                    h += 5.6
                    stack += 1
        # The chest: drawers in three rows, pulls, a lock plate; scrolls on it.
        x0, x1 = chest
        top = 74.0
        kit.box(side + "Chest", x0, x1, back, front, 4.0, top - 3.0, wood, bevel=0.8, uv="box")
        kit.box(side + "ChestTop", x0 - 1.5, x1 + 1.5, back - 1.0, front + 1.5, top - 3.0, top, wood, bevel=0.9,
                uv="box")
        kit.box(side + "ChestPlinth", x0 + 1.0, x1 - 1.0, back, front + 0.8, 0.0, 4.0, wood, bevel=0.6, uv="box")
        rows = ((8.0, 26.0), (28.0, 47.0), (49.0, 68.0))
        for row, (h0, h1) in enumerate(rows):
            for column in range(3):
                a = x0 + 3.0 + column * (x1 - x0 - 6.0) / 3.0
                b = a + (x1 - x0 - 6.0) / 3.0 - 2.0
                kit.box("%sDrawer%d_%d" % (side, row, column), a, b, front, front + 1.2, h0, h1, wood, bevel=0.7,
                        uv="box_up")
                kit.rod("%sPull%d_%d" % (side, row, column), ((a + b) / 2.0 - 4.0, front + 2.2, (h0 + h1) / 2.0),
                        ((a + b) / 2.0 + 4.0, front + 2.2, (h0 + h1) / 2.0), 0.7, brass, segments=8)
        middle = (x0 + x1) / 2.0
        kit.box(side + "LockPlate", middle - 6.0, middle + 6.0, front + 1.0, front + 2.0, 30.0, 44.0, brass,
                bevel=0.4)
        for index in range(9):
            x = x0 + 8.0 + index * (x1 - x0 - 16.0) / 8.0 + rng.uniform(-1.5, 1.5)
            y = (back + front) / 2.0 + rng.uniform(-8.0, 8.0)
            tall = rng.uniform(34.0, 48.0)
            scroll(kit, "%sStanding%d" % (side, index), (x, y, top), (x + rng.uniform(-1.0, 1.0), y, top + tall),
                   rng.uniform(3.2, 4.4), rng.choice(papers))
    return kit


def cabinet(kit, part, x0, x1, back, front, height, rng):
    """A tall glazed cabinet facing the room: plinth, two doors of small panes
    in brass glazing bars, a frieze and a cornice; dim shelves behind."""
    wood, brass, glass = oak(), gold(), dark_glass()
    kit.box(part + "Plinth", x0 - 1.0, x1 + 1.0, back, front + 1.5, 0.0, 8.0, wood, bevel=0.8, uv="box")
    kit.box(part + "Body", x0, x1, back, front - 2.0, 8.0, height - 10.0, wood, bevel=0.6, uv="box_up")
    kit.box(part + "Frieze", x0, x1, back, front + 0.5, height - 10.0, height - 4.0, wood, bevel=0.6, uv="box")
    kit.box(part + "Cornice", x0 - 3.0, x1 + 3.0, back - 1.0, front + 3.0, height - 4.0, height, wood, bevel=1.0,
            uv="box")
    middle = (x0 + x1) / 2.0
    for leaf, (a, b) in enumerate(((x0 + 3.0, middle - 1.0), (middle + 1.0, x1 - 3.0))):
        kit.blocks("%sStiles%d" % (part, leaf), [(a, a + 4.0, front - 2.5, front, 11.0, height - 13.0),
                                                 (b - 4.0, b, front - 2.5, front, 11.0, height - 13.0),
                                                 (a, b, front - 2.5, front, 11.0, 15.0),
                                                 (a, b, front - 2.5, front, height - 17.0, height - 13.0)], wood,
                   bevel=0.5)
        kit.box("%sPanes%d" % (part, leaf), a + 4.0, b - 4.0, front - 2.2, front - 1.6, 15.0, height - 17.0, glass,
                bevel=0.0)
        bars = [(a + 4.0 + (b - a - 8.0) * column / 3.0 - 0.5, a + 4.0 + (b - a - 8.0) * column / 3.0 + 0.5,
                 front - 1.7, front - 0.9, 15.0, height - 17.0) for column in (1, 2)]
        bars += [(a + 4.0, b - 4.0, front - 1.7, front - 0.9, h - 0.5, h + 0.5)
                 for h in [15.0 + (height - 32.0) * row / 6.0 for row in range(1, 6)]]
        kit.blocks("%sBars%d" % (part, leaf), bars, hall._cast_iron(), bevel=0.1)
        kit.ball("%sKnob%d" % (part, leaf), middle + (-3.0 if leaf == 0 else 3.0), front + 0.6, height * 0.5, 1.3,
                 brass)
    # Dim shelves behind the panes: book spines and bottles, barely seen.
    for level in (40.0, 78.0, 116.0):
        kit.box("%sShelf%d" % (part, int(level)), x0 + 4.0, x1 - 4.0, back + 2.0, front - 4.0, level - 2.0, level,
                wood, bevel=0.3, uv="box")
        wake.shelf_run(kit, x0 + 6.0, x1 - 6.0, front - 6.0, level, level + 30.0, rng)


def north_cabinets():
    kit = RP.Kit("NorthCabinets")
    rng = random.Random(5101)
    cabinet(kit, "West", 548.0, 652.0, BACK_Y + 10.0, FRONT_Y, 164.0, rng)
    cabinet(kit, "East", 798.0, 902.0, BACK_Y + 10.0, FRONT_Y, 164.0, rng)
    return kit


def north_lights():
    """The brass lanterns on the piers either side of the cabinets, and the
    violet crystal lanterns under brass rosettes on the alcoves' piers."""
    kit = RP.Kit("NorthLights")
    brass, iron = gold(), hall._cast_iron()
    for index, x in enumerate((508.0, 940.0)):
        shelf = 58.0
        kit.box("Bracket%d" % index, x - 8.0, x + 8.0, FRONT_Y, FRONT_Y + 14.0, shelf - 2.0, shelf, iron, bevel=0.3)
        kit.rod("Brace%d" % index, (x, FRONT_Y + 0.5, shelf - 16.0), (x, FRONT_Y + 12.0, shelf - 1.0), 0.9, iron)
        gh.lantern(kit, "Lantern%d" % index, x, FRONT_Y + 7.0, shelf, size=0.95, power=20.0)
    for index, x in enumerate((309.0, 1136.0)):
        # The rosette: a brass ring with eight spokes round a boss.
        ch = 136.0
        face_ring(kit, "Rosette%d" % index, x, FRONT_Y + 2.0, ch, 13.0, 1.4, brass)
        face_ring(kit, "RosetteInner%d" % index, x, FRONT_Y + 2.0, ch, 6.0, 0.9, brass)
        for spoke in range(8):
            turn = math.pi * spoke / 4.0
            kit.rod("RosetteSpoke%d_%d" % (index, spoke), (x + 6.0 * math.cos(turn), FRONT_Y + 2.0,
                                                           ch + 6.0 * math.sin(turn)),
                    (x + 13.0 * math.cos(turn), FRONT_Y + 2.0, ch + 13.0 * math.sin(turn)), 0.6, brass, segments=6)
        kit.ball("RosetteBoss%d" % index, x, FRONT_Y + 2.5, ch, 2.4, brass, plan=0.6)
        # The crystal lantern: an iron cage round a violet crystal on a bracket.
        cup = 70.0
        kit.rod("CrystalArm%d" % index, (x, FRONT_Y + 0.5, cup - 12.0), (x, FRONT_Y + 9.0, cup - 1.0), 0.9, iron)
        kit.lathe("CrystalCup%d" % index, x, FRONT_Y + 9.0, [(0.0, cup - 2.0), (3.0, cup - 2.0), (6.0, cup),
                                                            (6.0, cup + 1.4), (0.0, cup + 1.4)], iron, plan=ROUND)
        wake.crystal(kit, "Crystal%d" % index, x, FRONT_Y + 9.0, cup + 1.4, 4.2, 16.0, crystal_glow())
        for post in range(4):
            turn = math.pi / 4.0 + math.pi * post / 2.0
            px, py = x + 6.0 * math.cos(turn), FRONT_Y + 9.0 + 6.0 * math.sin(turn) * ROUND
            kit.rod("CrystalCage%d_%d" % (index, post), (px, py, cup + 1.4), (px, py, cup + 20.0), 0.45, iron,
                    segments=6)
        kit.lathe("CrystalRoof%d" % index, x, FRONT_Y + 9.0, [(7.0, cup + 20.0), (1.0, cup + 26.0), (0.0, cup + 26.5)],
                  iron, plan=ROUND)
        kit.light("CrystalLight%d" % index, x, FRONT_Y + 10.0, cup + 9.0, VIOLET, 7.0, radius=0.03)
        RP.glow("crystal", x, FRONT_Y + 9.0, cup + 9.0, VIOLET, 26.0)
    return kit


# ---------------------------------------------------------------- the side walls


def side_press(kit, part, x0, x1, y0, y1, height, rng, papers, drawers=False):
    """A press against a side wall, its long side to the room: its top and
    its south end are what the camera sees, so scrolls and books lie on it
    and its south end shows cubbies of scroll ends (or drawers)."""
    wood, brass = oak(), gold()
    kit.box(part + "Plinth", x0 - 1.0, x1 + 1.0, y0, y1 + 1.0, 0.0, 6.0, wood, bevel=0.8, uv="box")
    kit.box(part + "Body", x0, x1, y0, y1, 6.0, height - 4.0, wood, bevel=0.8, uv="box_up")
    kit.box(part + "Top", x0 - 2.0, x1 + 2.0, y0 - 1.0, y1 + 1.5, height - 4.0, height, wood, bevel=1.0, uv="box")
    # Its south end: drawers, or cubbies of scroll ends.
    rows = max(int((height - 14.0) // 22.0), 1)
    for row in range(rows):
        h0 = 9.0 + row * (height - 16.0) / rows
        h1 = h0 + (height - 16.0) / rows - 2.0
        if drawers:
            kit.box("%sDrawer%d" % (part, row), x0 + 3.0, x1 - 3.0, y1, y1 + 1.2, h0, h1, wood, bevel=0.6, uv="box_up")
            kit.rod("%sPull%d" % (part, row), ((x0 + x1) / 2.0 - 4.0, y1 + 2.0, (h0 + h1) / 2.0),
                    ((x0 + x1) / 2.0 + 4.0, y1 + 2.0, (h0 + h1) / 2.0), 0.6, brass, segments=8)
            continue
        kit.box("%sCubby%d" % (part, row), x0 + 3.0, x1 - 3.0, y1 - 6.0, y1 - 0.5, h0, h1, wake.stone(), bevel=0.0)
        for index in range(int((x1 - x0 - 6.0) // 8.0)):
            x = x0 + 7.0 + index * 8.0
            kit.rod("%sEnd%d_%d" % (part, row, index), (x, y1 - 5.0, h0 + 4.0), (x, y1 + 0.6, h0 + 4.0), 3.2,
                    rng.choice(papers), segments=10)
    # On its top, scrolls lying along it and a few books.
    y = y0 + 6.0
    index = 0
    while y < y1 - 26.0:
        if rng.random() < 0.3:
            wake.closed_book(kit, "%sBook%d" % (part, index), x0 + 4.0, x1 - 4.0, y, y + 20.0, height,
                             rng.uniform(4.0, 7.0), rng.choice(wake.BOOK_COLOURS))
            y += 24.0
        else:
            for layer in range(rng.randint(1, 2)):
                for count in range(int((x1 - x0 - 8.0) // 9.0) - layer):
                    x = x0 + 8.0 + count * 9.0 + layer * 4.5
                    scroll(kit, "%sTopScroll%d_%d_%d" % (part, index, layer, count),
                           (x, y + rng.uniform(0.0, 3.0), height + 3.6 + layer * 6.0),
                           (x, y + rng.uniform(26.0, 32.0), height + 3.6 + layer * 6.0), 3.6, rng.choice(papers))
            y += 36.0
        index += 1


def wall_lantern(kit, part, shell, side, y, h=82.0, power=14.0):
    """A brass lantern on an iron bracket from a side wall."""
    iron = hall._cast_iron()
    frame = shell.mount(side, y)
    wall = frame.to_g(0.0, h - 14.0, 0.0)
    shelf = frame.to_g(0.0, h, 13.0)
    kit.box(part + "Plate", wall.x - 1.4, wall.x + 1.4, y - 5.0, y + 5.0, wall.z - 4.0, wall.z + 14.0, iron, bevel=0.4)
    kit.rod(part + "Brace", (wall.x, y, wall.z), (shelf.x, y, shelf.z - 1.0), 0.9, iron)
    kit.box(part + "Shelf", shelf.x - 7.0, shelf.x + 7.0, y - 6.0, y + 6.0, shelf.z - 2.0, shelf.z, iron, bevel=0.3)
    gh.lantern(kit, part + "Lantern", shelf.x, y, shelf.z, size=0.9, power=power)


def west_wall(shell):
    kit = RP.Kit("WestWall")
    rng = random.Random(6007)
    papers = scroll_papers()
    side_press(kit, "PressNorth", LEFT_X + 4.0, 132.0, 222.0, 298.0, 118.0, rng, papers)
    side_press(kit, "Drawers", LEFT_X + 4.0, 120.0, 306.0, 534.0, 74.0, rng, papers, drawers=True)
    wall_lantern(kit, "Lantern", shell, "left", 557.0)
    return kit


def east_wall(shell):
    kit = RP.Kit("EastWall")
    rng = random.Random(6011)
    papers = scroll_papers()
    side_press(kit, "PressNorth", 1312.0, RIGHT_X - 4.0, 222.0, 304.0, 118.0, rng, papers)
    side_press(kit, "PressMiddle", 1308.0, RIGHT_X - 4.0, 336.0, 540.0, 112.0, rng, papers)
    side_press(kit, "PressSouth", 1324.0, RIGHT_X - 4.0, 594.0, 740.0, 100.0, rng, papers)
    side_press(kit, "Drawers", 1270.0, 1380.0, 790.0, 860.0, 46.0, rng, papers, drawers=True)
    wall_lantern(kit, "Lantern", shell, "right", 566.0)
    return kit


def violet_cabinet():
    """The cabinet in the south-west the painting lights violet from inside:
    oak, a glass top over a bed of violet crystals that glow up through it."""
    kit = RP.Kit("VioletCabinet")
    wood, glass = oak(), wake.jar_glass()
    x0, x1, y0, y1, top = 74.0, 146.0, 582.0, 734.0, 62.0
    kit.box("Plinth", x0 - 1.0, x1 + 1.0, y0, y1 + 1.0, 0.0, 6.0, wood, bevel=0.8, uv="box")
    kit.box("Body", x0, x1, y0, y1, 6.0, top - 14.0, wood, bevel=0.8, uv="box_up")
    for part, (a, b, c, d) in (("North", (x0, x1, y0, y0 + 4.0)), ("South", (x0, x1, y1 - 4.0, y1)),
                               ("West", (x0, x0 + 4.0, y0, y1)), ("East", (x1 - 4.0, x1, y0, y1))):
        kit.box("Frame" + part, a, b, c, d, top - 14.0, top, wood, bevel=0.6, uv="box")
    lid = kit.box("Lid", x0 + 4.0, x1 - 4.0, y0 + 4.0, y1 - 4.0, top - 0.8, top, glass, bevel=0.0)
    lid.visible_shadow = False
    rng = random.Random(6101)
    bed = hall._cloth("FinalCrystalBed", (0.05, 0.02, 0.08))
    kit.box("Bed", x0 + 4.0, x1 - 4.0, y0 + 4.0, y1 - 4.0, top - 14.0, top - 10.0, bed, bevel=0.0)
    for index in range(16):
        x, y = rng.uniform(x0 + 10.0, x1 - 10.0), rng.uniform(y0 + 10.0, y1 - 10.0)
        wake.crystal(kit, "Crystal%d" % index, x, y, top - 10.0, rng.uniform(2.0, 3.6), rng.uniform(5.0, 8.0),
                     crystal_glow("FinalCabinetCrystal", 0.5), tilt=rng.uniform(-0.3, 0.3),
                     turn=rng.uniform(0.0, 6.28))
    kit.light("Glow", (x0 + x1) / 2.0, (y0 + y1) / 2.0, top + 8.0, VIOLET, 3.0, radius=0.3)
    RP.glow("crystal", (x0 + x1) / 2.0, (y0 + y1) / 2.0, top, VIOLET, 34.0)
    return kit


def vitrine(kit, part, x0, x1, y0, y1, rng, top=56.0):
    """A glass display case on an oak stand: drawers under it, a brass-edged
    glass case holding Mrs. Lin's instruments and notes."""
    wood, brass, glass = oak(), gold(), wake.jar_glass()
    base = top - 20.0
    for x in (x0 + 2.0, x1 - 6.0):
        for y in (y0 + 2.0, y1 - 6.0):
            kit.box("%sLeg%d_%d" % (part, int(x), int(y)), x, x + 4.0, y, y + 4.0, 0.0, base, wood, bevel=0.5,
                    uv="box_up")
    kit.box(part + "Stand", x0, x1, y0, y1, base - 12.0, base, wood, bevel=0.8, uv="box")
    kit.box(part + "Shelf", x0 + 2.0, x1 - 2.0, y0 + 2.0, y1 - 2.0, 8.0, 10.0, wood, bevel=0.4, uv="box")
    kit.box(part + "Drawer", x0 + 6.0, x1 - 6.0, y1, y1 + 1.0, base - 10.0, base - 2.0, wood, bevel=0.5, uv="box")
    kit.box(part + "Floor", x0 + 2.0, x1 - 2.0, y0 + 2.0, y1 - 2.0, base, base + 1.0,
            hall._cloth("FinalVitrineBaize", (0.035, 0.045, 0.055)), bevel=0.0)
    edges = []
    for x in (x0, x1 - 1.6):
        for y in (y0, y1 - 1.6):
            edges.append((x, x + 1.6, y, y + 1.6, base, top))
    for y in (y0, y1 - 1.6):
        edges.append((x0, x1, y, y + 1.6, top - 1.6, top))
    for x in (x0, x1 - 1.6):
        edges.append((x, x + 1.6, y0, y1, top - 1.6, top))
    kit.blocks(part + "BrassEdges", edges, brass, bevel=0.2)
    for name, box in (("Lid", (x0 + 1.6, x1 - 1.6, y0 + 1.6, y1 - 1.6, top - 0.8, top)),
                      ("SouthGlass", (x0 + 1.6, x1 - 1.6, y1 - 1.0, y1 - 0.4, base, top)),
                      ("WestGlass", (x0, x0 + 0.6, y0 + 1.6, y1 - 1.6, base, top)),
                      ("EastGlass", (x1 - 0.6, x1, y0 + 1.6, y1 - 1.6, base, top))):
        pane = kit.box(part + name, *box, glass, bevel=0.0)
        pane.visible_shadow = False
    # Inside, along its length: an astrolabe, a lens, a note, a bottle and a
    # sextant's arc.
    middle, length = (x0 + x1) / 2.0, y1 - y0
    spots = [y0 + length * share for share in (0.16, 0.4, 0.6, 0.84)]
    kit.lathe(part + "Astrolabe", middle, spots[0], [(0.0, base + 1.0), (10.0, base + 1.0), (10.0, base + 2.0),
                                                     (0.0, base + 2.0)], brass, plan=ROUND, segments=32)
    kit.ring(part + "AstrolabeRim", (middle, spots[0], base + 2.2), (0.0, 0.0, 1.0), 9.0, 0.6, brass)
    kit.ring(part + "Lens", (middle - 8.0, spots[1], base + 3.0), (0.0, 0.0, 1.0), 6.0, 0.8, brass)
    wake.paper(kit, part + "Note", middle + 6.0, spots[2], base + 1.2, 18.0, 15.0, rng.uniform(-0.3, 0.3),
               wake.writing("FinalVitrineNote", lines=8.0))
    chem.flask(kit, part + "Flask", middle - 9.0, spots[3], base + 1.0, "round", chem.POTIONS[0], size=0.8)
    kit.rod(part + "SextantArc", (middle + 2.0, spots[3] - 3.0, base + 2.0),
            (middle + 14.0, spots[3] + 4.0, base + 2.0), 0.7, brass)


def west_vitrine():
    kit = RP.Kit("WestVitrine")
    vitrine(kit, "Vitrine", 142.0, 210.0, 388.0, 540.0, random.Random(7001))
    return kit


def east_vitrines():
    kit = RP.Kit("EastVitrines")
    vitrine(kit, "North", 1238.0, 1302.0, 388.0, 540.0, random.Random(7003))
    vitrine(kit, "South", 1262.0, 1318.0, 650.0, 722.0, random.Random(7005))
    return kit


def table(kit, part, x0, x1, y0, y1, top, wood):
    """A plain oak table: turned legs, an apron, a top of boards."""
    for x in (x0 + 5.0, x1 - 5.0):
        for y in (y0 + 5.0, y1 - 5.0):
            kit.lathe("%sLeg%d_%d" % (part, int(x), int(y)), x, y, [(0.0, 0.0), (3.2, 0.0), (3.2, 4.0), (2.2, 8.0),
                                                                    (2.6, top - 14.0), (3.0, top - 10.0),
                                                                    (0.0, top - 10.0)], wood, plan=ROUND,
                      segments=12)
    kit.box(part + "Apron", x0 + 2.0, x1 - 2.0, y0 + 2.0, y1 - 2.0, top - 10.0, top - 3.0, wood, bevel=0.6, uv="box")
    boards = 4
    for index in range(boards):
        a = x0 + (x1 - x0) * index / boards
        kit.box("%sBoard%d" % (part, index), a + 0.3, a + (x1 - x0) / boards - 0.3, y0 - 2.0, y1 + 2.0, top - 3.0,
                top, wood, bevel=0.5, uv="box")


def west_table():
    """The long table of papers by the vitrine, as the painting lays it: a
    map pinned flat, notes, a lens, an inkwell and a quill."""
    kit = RP.Kit("WestTable")
    wood, brass = oak(), gold()
    x0, x1, y0, y1, top = 252.0, 328.0, 388.0, 538.0, 48.0
    table(kit, "Table", x0, x1, y0, y1, top, wood)
    rng = random.Random(7101)
    wake.paper(kit, "Map", 290.0, 430.0, top + 0.3, 56.0, 46.0, 0.06, hall.material_map())
    for index in range(5):
        wake.paper(kit, "Note%d" % index, rng.uniform(268.0, 312.0), rng.uniform(468.0, 524.0), top + 0.4 + index * 0.1,
                   rng.uniform(16.0, 22.0), rng.uniform(16.0, 22.0), rng.uniform(-0.5, 0.5),
                   wake.writing("FinalTableNote", lines=9.0))
    kit.ring("Lens", (306.0, 448.0, top + 0.8), (0.0, 0.0, 1.0), 5.0, 0.7, brass)
    kit.lathe("Inkwell", 316.0, 512.0, [(0.0, top), (3.6, top), (3.6, top + 3.0), (1.6, top + 4.2), (0.0, top + 4.2)],
              hall._cast_iron(), plan=ROUND, segments=16)
    kit.rod("Quill", (314.0, 511.0, top + 4.0), (300.0, 500.0, top + 14.0), 0.5, hall._parchment(), segments=6)
    wake.closed_book(kit, "Book", 262.0, 288.0, 498.0, 518.0, top, 5.0, wake.BOOK_COLOURS[2])
    return kit


def east_table():
    """The writing table east of the engine: papers, a box and a book."""
    kit = RP.Kit("EastTable")
    wood = oak()
    x0, x1, y0, y1, top = 1090.0, 1216.0, 750.0, 798.0, 48.0
    table(kit, "Table", x0, x1, y0, y1, top, wood)
    rng = random.Random(7203)
    for index in range(6):
        wake.paper(kit, "Note%d" % index, rng.uniform(1104.0, 1170.0), rng.uniform(760.0, 788.0),
                   top + 0.4 + index * 0.1, rng.uniform(16.0, 24.0), rng.uniform(14.0, 18.0), rng.uniform(-0.6, 0.6),
                   wake.writing("FinalTableNote", lines=9.0))
    kit.box("Box", 1176.0, 1204.0, 762.0, 784.0, top, top + 9.0, wood, bevel=0.8, uv="box")
    kit.box("BoxLid", 1175.0, 1205.0, 761.0, 785.0, top + 9.0, top + 11.0, wood, bevel=0.8, uv="box")
    kit.box("BoxClasp", 1188.0, 1192.0, 784.6, 785.4, top + 5.0, top + 10.0, gold(), bevel=0.2)
    wake.closed_book(kit, "Book", 1100.0, 1124.0, 778.0, 794.0, top, 5.0, wake.BOOK_COLOURS[0])
    return kit


# The crate: its centre, its size in cm and how far it is turned.
CRATE = (242.0, 754.0, 128.0, 96.0, 52.0, -30.0)


def crate():
    """The great packing crate turned askew in the south-west corner, its lid
    nailed down over battens, iron at its corners; a rug and papers by it."""
    kit = RP.Kit("Crate")
    pine = gh.laid_photo("FinalCratePine", "wood_cabinet_worn_long", 0.5, 0.72, (0.92, 0.82, 0.68), saturation=0.6,
                         variety=0.22, wear=0.3)
    iron = hall._cast_iron()
    cx, cy, width, depth, height, turn = CRATE
    real_box(kit, "Body", cx, cy, 2.0, height - 3.0, width - 4.0, depth - 4.0, turn, pine, bevel=0.6)
    for index in range(5):
        along = -width / 2.0 + width * (index + 0.5) / 5.0
        bx, by = turned(cx, cy, along, 0.0, turn)
        real_box(kit, "Lid%d" % index, bx, by, height - 3.0, height, width / 5.0 - 1.0, depth, turn, pine, bevel=0.5)
    for index, along in enumerate((-depth / 2.0 + 6.0, depth / 2.0 - 6.0)):
        bx, by = turned(cx, cy, 0.0, along, turn)
        real_box(kit, "Batten%d" % index, bx, by, height, height + 2.0, width - 6.0, 8.0, turn, pine, bevel=0.4)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bx, by = turned(cx, cy, sx * (width / 2.0 - 3.0), sy * (depth / 2.0 - 3.0), turn)
            real_box(kit, "Corner%d%d" % (int(sx), int(sy)), bx, by, 0.0, height + 0.6, 7.0, 7.0, turn, iron,
                     bevel=0.3)
    for index, (along, h) in enumerate(((-width / 4.0, 18.0), (width / 4.0, 34.0))):
        bx, by = turned(cx, cy, along, depth / 2.0 - 1.0, turn)
        real_box(kit, "Stencil%d" % index, bx, by, h, h + 8.0, 26.0, 1.0, turn,
                 hall._cloth("FinalStencil", (0.03, 0.025, 0.03)), bevel=0.0)
    return kit


def floor_dressing():
    """What lies on the floor: a worn violet rug in the south-west corner,
    papers fallen from the crate and the tables, and Mrs. Lin's pages."""
    kit = RP.Kit("FloorDressing", depth=False)
    x0, x1, y0, y1 = 92.0, 196.0, 790.0, 846.0
    length, width = x1 - x0, y1 - y0
    kit.box("RugBacking", x0 + 0.5, x1 - 0.5, y0 + 1.0, y1 - 1.0, 0.0, 0.6,
            hall._cloth("FinalRugBacking", (0.06, 0.03, 0.08)), bevel=0.0)
    kit.quad("Rug", [(x0, y1, 0.7), (x1, y1, 0.7), (x1, y0, 0.7), (x0, y0, 0.7)], wake.rug_material(length, width),
             uvs=((0.0, width), (length, width), (length, 0.0), (0.0, 0.0)))
    rng = random.Random(7307)
    note = wake.writing("FinalFloorNote", lines=9.0)
    spots = ((118.0, 812.0), (150.0, 826.0), (176.0, 806.0), (322.0, 690.0), (352.0, 712.0), (200.0, 640.0),
             (1150.0, 820.0), (1196.0, 836.0), (424.0, 664.0))
    for index, (x, y) in enumerate(spots):
        wake.paper(kit, "Paper%d" % index, x, y, 0.9 + index * 0.05, rng.uniform(16.0, 22.0), rng.uniform(15.0, 20.0),
                   rng.uniform(-0.8, 0.8), note)
    return kit


# ---------------------------------------------------------------- the floor


def _flag(shape, x0, x1, y0, y1, top, rng):
    """One flagstone (room_chemistry._flagstone), tipped less, so the brass
    let in among the stones sits flush with them."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    turn = math.radians(rng.uniform(-0.6, 0.6))
    slope_x, slope_y = rng.uniform(-0.004, 0.004), rng.uniform(-0.003, 0.003)
    cosine, sine = math.cos(turn), math.sin(turn)

    def ring(inset, drop):
        a0, a1, b0, b1 = x0 + inset, x1 - inset, y0 + inset, y1 - inset
        cut = max(2.2 - inset * 0.6, 0.7)
        outline = ((a0 + cut, b0), (a1 - cut, b0), (a1, b0 + cut), (a1, b1 - cut), (a1 - cut, b1), (a0 + cut, b1),
                   (a0, b1 - cut), (a0, b0 + cut))
        verts = []
        for px, py in outline:
            dx, dy = px - cx, py - cy
            verts.append(shape.verts.new((cx + dx * cosine - dy * sine, cy + dx * sine + dy * cosine,
                                          top - drop + dx * slope_x + dy * slope_y)))
        return verts

    outer = ring(0.0, 1.1)
    middle = ring(0.7, 0.35)
    inner = ring(1.5, 0.0)
    bottom = [shape.verts.new((vert.co.x, vert.co.y, -chem.JOINT_DEPTH - 1.0)) for vert in outer]
    shape.faces.new(inner)
    shape.faces.new(list(reversed(bottom)))
    for upper, lower in ((inner, middle), (middle, outer), (outer, bottom)):
        for index in range(8):
            following = (index + 1) % 8
            shape.faces.new((lower[index], lower[following], upper[following], upper[index]))


def flagstones():
    """The floor as the painting lays it: square-cut flagstones in rows of
    mixed lengths, their joints staggered, up to the south edge and, between
    the gate's piers, up to the gate; the room's dark floor shows in the
    joints."""
    kit = RP.Kit("Flagstones", depth=False)
    rng = random.Random(2711)
    shape = bmesh.new()
    cracks = []
    laid = 0
    deepest = max(y for _x, y in GATE_BACK)
    y = BACK_Y - 4.0
    while y < deepest - 4.0:
        y1 = y + rng.uniform(*FLAG_ROW)
        x = LEFT_X - 20.0 - rng.uniform(0.0, 30.0)
        while x < RIGHT_X + 8.0:
            length = rng.uniform(*FLAG_LENGTH)
            x1 = x + length
            # The floor's end under the whole stone, not just its two ends.
            south = min([y1] + [floor_south(min(max(x + length * step / 6.0, LEFT_X), RIGHT_X))
                                for step in range(7)])
            if south - y > 10.0:
                top = rng.uniform(-0.2, 0.1)
                _flag(shape, x + FLAG_JOINT / 2.0, x1 - FLAG_JOINT / 2.0, y + FLAG_JOINT / 2.0,
                      south - FLAG_JOINT / 2.0, top, rng)
                laid += 1
                if rng.random() < 0.05 and south - y > 30.0:
                    cracks.append(((x + x1) / 2.0, (y + south) / 2.0, length - 10.0, south - y - 10.0, top))
            x = x1
        y = y1
    stones = kit.shape("Stones", shape, flagstone(), uv="floor")
    stones.visible_shadow = True
    crack = hall.material_floor_crack(False)
    for index, (cx, cy, across, along, top) in enumerate(cracks):
        wake.paper(kit, "Crack%d" % index, cx, cy, top + 0.05, across, along, rng.uniform(-0.4, 0.4), crack)
    bpy.data.objects["RoomFloor"].location.z -= chem.JOINT_DEPTH / RP.SIN * RP.PX
    # The dark under the stones runs on from the shell's floor to the edge,
    # and between the gate's piers to the gate.
    outline = ([(LEFT_X - 40.0, 768.0), (RIGHT_X + 40.0, 768.0)] + list(reversed(EDGE_EAST))
               + [(GATE_BACK[-1][0], EDGE_Y)] + list(reversed(GATE_BACK)) + [(GATE_BACK[0][0], EDGE_Y)]
               + list(reversed(EDGE_WEST)))
    kit.slab("Under", outline, -chem.JOINT_DEPTH - 0.6, -chem.JOINT_DEPTH, chem.grout(), plane="floor")
    print("FLAGSTONES %d stones, %d cracked" % (laid, len(cracks)))
    return kit


def strip(shape, points, width, h, closed=False):
    """A flat band `width` cm wide along plan points, into `shape`."""
    count = len(points)
    for index in range(count if closed else count - 1):
        (x0, y0), (x1, y1) = points[index], points[(index + 1) % count]
        dx, dy = x1 - x0, (y1 - y0) / ROUND
        length = math.hypot(dx, dy)
        if length < 1e-6:
            continue
        nx, ny = -dy / length * width / 2.0, dx / length * width / 2.0 * ROUND
        # Each piece runs on a little past its ends, so the bends close.
        ex, ey = dx / length * width * 0.5, dy / length * width * 0.5 * ROUND
        corners = [(x0 - ex + nx, y0 - ey + ny), (x1 + ex + nx, y1 + ey + ny), (x1 + ex - nx, y1 + ey - ny),
                   (x0 - ex - nx, y0 - ey - ny)]
        shape.faces.new([shape.verts.new((x, y, h)) for x, y in corners])


def inlay():
    """The painting's lines of brass let into the floor: a border round the
    middle of the room, a double circle round the analysis table with a
    small compass rose at each of its eight points, lines from it to the
    vault door, the gate and the west tables, and an octagon round the
    engine's dais."""
    kit = RP.Kit("Inlay", depth=False)
    shape = bmesh.new()
    cx, cy = TABLE
    x0, x1, y0, y1, cut = 232.0, 1222.0, 236.0, 858.0, 22.0
    strip(shape, [(x0 + cut, y0), (x1 - cut, y0), (x1, y0 + cut), (x1, y1 - cut), (x1 - cut, y1), (x0 + cut, y1),
                  (x0, y1 - cut), (x0, y0 + cut)], 2.6, INLAY_H, closed=True)
    for radius, width in ((CIRCLE_R, 3.2), (CIRCLE_R - 24.0, 2.2)):
        strip(shape, plan_circle(cx, cy, radius, steps=96), width, INLAY_H, closed=True)
    north, south = cy - CIRCLE_R * ROUND, cy + CIRCLE_R * ROUND
    for line in (((cx, y0), (cx, north)), ((cx, south), (cx, y1)), ((x0, cy), (cx - CIRCLE_R, cy))):
        strip(shape, list(line), 2.6, INLAY_H)
    ex, ey = ENGINE
    strip(shape, octagon(ex, ey, ENGINE_R + 16.0), 2.2, INLAY_H, closed=True)
    kit.shape("Lines", shape, brass_inlay())
    for index in range(8):
        x, y = plan_point(cx, cy, CIRCLE_R, 22.5 + 45.0 * index)
        radius = 15.0
        kit.quad("Rose%d" % index, [(x - radius, y + radius * ROUND, INLAY_H + 0.1),
                                    (x + radius, y + radius * ROUND, INLAY_H + 0.1),
                                    (x + radius, y - radius * ROUND, INLAY_H + 0.1),
                                    (x - radius, y - radius * ROUND, INLAY_H + 0.1)],
                 wake.compass_material(radius), uvs=((-radius, -radius), (radius, -radius), (radius, radius),
                                                     (-radius, radius)))
    return kit


def grates():
    """Iron grates in brass frames let into the floor where the painting has
    them, violet light rising through them from below."""
    kit = RP.Kit("Grates", depth=False)
    brass = brass_inlay()
    length, width = 44.0, 30.0
    for index, (x, y) in enumerate(GRATES):
        corners = [(x - length / 2.0, y + width / 2.0, INLAY_H), (x + length / 2.0, y + width / 2.0, INLAY_H),
                   (x + length / 2.0, y - width / 2.0, INLAY_H), (x - length / 2.0, y - width / 2.0, INLAY_H)]
        kit.quad("Grate%d" % index, corners, grate_iron(length, width),
                 uvs=((0.0, 0.0), (length, 0.0), (length, width), (0.0, width)))
        shape = bmesh.new()
        strip(shape, [(c[0], c[1]) for c in corners], 3.0, INLAY_H + 0.05, closed=True)
        kit.shape("Frame%d" % index, shape, brass)
        kit.light("Glow%d" % index, x, y, 3.0, VIOLET, 0.3, radius=0.1, mirrored=False)
        RP.glow("grate", x, y, 0.0, VIOLET, 20.0)
    return kit


# ---------------------------------------------------------------- the south


def south_edge():
    """Where the painted floor ends: a pale coping along the edge and a face
    of stone dropping from it into the dark."""
    kit = RP.Kit("SouthEdge", depth=False)
    cope, drop = coping(), drop_stone()
    for name, line in (("West", EDGE_WEST), ("East", EDGE_EAST)):
        shape = bmesh.new()
        layer = shape.loops.layers.uv.verify()
        along = 0.0
        for (x0, y0), (x1, y1) in zip(line[:-1], line[1:]):
            step = math.hypot(x1 - x0, (y1 - y0) / ROUND)
            face = shape.faces.new([shape.verts.new(point) for point in ((x0, y0, 0.0), (x1, y1, 0.0),
                                                                        (x1, y1, -150.0), (x0, y0, -150.0))])
            for loop, uv in zip(face.loops, ((along, 0.0), (along + step, 0.0), (along + step, 1.0), (along, 1.0))):
                loop[layer].uv = uv
            along += step
        kit.keep(RP.mesh_from("FinalDrop" + name, shape, drop, facing=RP.TOWARD_CAMERA))
        shape = bmesh.new()
        inner = [(x, y - 9.0 * (1.0 if y >= EDGE_Y - 1.0 else 0.75)) for x, y in line]
        prism(shape, list(line) + list(reversed(inner)), -0.6, 1.4)
        kit.shape("Coping" + name, shape, cope, bevel=0.6, uv="floor")
    return kit


def emblem_outline(kind):
    """The four rooms' emblems on the gate, unit-sized, (x, h)."""
    if kind == "book":
        return [[(-1.0, -0.7), (-0.06, -0.55), (-0.06, 0.8), (-1.0, 0.65)],
                [(0.06, -0.55), (1.0, -0.7), (1.0, 0.65), (0.06, 0.8)]]
    if kind == "flask":
        neck = [(-0.18, 1.0), (-0.18, 0.35)]
        bowl = [(-0.18 + 0.0, 0.35)] + [(0.78 * math.cos(math.radians(a)), -0.25 + 0.6 * math.sin(math.radians(a)))
                                        for a in range(110, 431, 20)] + [(0.18, 0.35)]
        return [neck + bowl[1:] + [(0.18, 1.0)]]
    if kind == "bolt":
        return [[(0.3, 1.0), (-0.42, 0.05), (-0.02, 0.05), (-0.34, -1.0), (0.46, 0.12), (0.06, 0.12)]]
    right = [(0.5 * max(math.cos(along * math.pi / 2.0), 0.0) ** 0.8, along)
             for along in (-1.0 + 2.0 * index / 12.0 for index in range(13))]
    outline = right + [(-across, along) for across, along in reversed(right)][1:-1]
    turn = math.radians(-30.0)
    return [[(px * math.cos(turn) - pz * math.sin(turn), px * math.sin(turn) + pz * math.cos(turn))
             for px, pz in outline]]


def south_gate():
    """The way back to the Hall as the painting draws it: two great leaves of
    iron-banded oak under a round arch crowned with a brass sunburst, a violet
    core in a ring of brass where they meet, the Library's book, the
    Chemistry Room's flask, the Circuit's bolt and the Greenhouse's leaf round
    it; columns either side, violet lamps in the bays beyond and tall piers
    at the ends; a landing with a brass-framed mat before it. It stands in
    the depth map on its own base, and the floor runs up to that base
    (GATE_BACK): a player walking up to it goes behind it, and shows through
    it as the Hall's figures show through its walls."""
    kit = RP.Kit("SouthGate")
    stone, brass, iron = dressed_stone(), gold(), hall._cast_iron()
    leaf_wood = chem.laid("FinalGateOak", "wood_table", 1.0, 0.55, (0.9, 0.78, 0.68), saturation=0.7, variety=0.16,
                          wear=0.3, ao=0.25, roughness=0.9, coat=0.25, coat_roughness=0.3)
    for sign in (-1.0, 1.0):
        def at(offset):
            return GATE_X + sign * offset

        a, b = sorted((at(205.0), at(267.0)))
        kit.box("Pier%+d" % sign, a, b, GATE_FACE - 46.0, GATE_FACE, -150.0, 252.0, stone, bevel=1.0, uv="box_up")
        kit.box("PierCap%+d" % sign, a - 4.0, b + 4.0, GATE_FACE - 50.0, GATE_FACE + 4.0, 252.0, 262.0, stone,
                bevel=1.2, uv="box")
        kit.box("PierPanel%+d" % sign, a + 9.0, b - 9.0, GATE_FACE, GATE_FACE + 1.2, 30.0, 236.0, stone,
                bevel=0.8, uv="box_up")
        face_ring(kit, "PierRosette%+d" % sign, (a + b) / 2.0, GATE_FACE + 2.0, 214.0, 10.0, 1.2, brass)
        kit.ball("PierBoss%+d" % sign, (a + b) / 2.0, GATE_FACE + 2.2, 214.0, 2.6, brass, plan=0.6)
        # The bay between pier and column, its violet lamp.
        a, b = sorted((at(147.0), at(205.0)))
        kit.box("Bay%+d" % sign, a, b, GATE_FACE - 60.0, GATE_FACE - 12.0, -150.0, 236.0, stone, bevel=0.8,
                uv="box_up")
        lamp_x, lamp_y, lamp_h = (a + b) / 2.0, GATE_FACE - 4.0, 92.0
        kit.box("LampShelf%+d" % sign, lamp_x - 9.0, lamp_x + 9.0, GATE_FACE - 12.0, lamp_y + 4.0, lamp_h - 3.0, lamp_h,
                stone, bevel=0.6, uv="box")
        wake.crystal(kit, "LampCrystal%+d" % sign, lamp_x, lamp_y, lamp_h, 5.0, 20.0, crystal_glow())
        for post in range(4):
            turn = math.pi / 4.0 + math.pi * post / 2.0
            px, py = lamp_x + 7.5 * math.cos(turn), lamp_y + 7.5 * math.sin(turn) * ROUND
            kit.rod("LampCage%+d_%d" % (sign, post), (px, py, lamp_h), (px, py, lamp_h + 26.0), 0.5, iron, segments=6)
        kit.lathe("LampRoof%+d" % sign, lamp_x, lamp_y, [(9.0, lamp_h + 26.0), (1.2, lamp_h + 33.0),
                                                         (0.0, lamp_h + 33.5)], iron, plan=ROUND)
        kit.light("LampLight%+d" % sign, lamp_x, lamp_y + 2.0, lamp_h + 11.0, VIOLET, 16.0, radius=0.04)
        RP.glow("crystal", lamp_x, lamp_y, lamp_h + 11.0, VIOLET, 30.0)
        # The column by the door: base, shaft banded in brass, capital.
        column_x = at(131.0)
        kit.lathe("Column%+d" % sign, column_x, GATE_FACE - 18.0,
                  [(0.0, -6.0), (21.0, -6.0), (21.0, 4.0), (17.0, 9.0), (15.0, 12.0), (15.0, 184.0), (19.0, 190.0),
                   (21.0, 198.0), (0.0, 198.0)], stone, plan=ROUND, segments=28)
        for h in (40.0, 120.0):
            kit.lathe("ColumnBand%+d_%d" % (sign, int(h)), column_x, GATE_FACE - 18.0,
                      [(0.0, h), (15.8, h), (15.8, h + 4.0), (0.0, h + 4.0)], brass, plan=ROUND, segments=28)
        # The jamb.
        a, b = sorted((at(103.0), at(117.0)))
        kit.box("Jamb%+d" % sign, a, b, DOOR_FACE - 30.0, DOOR_FACE + 3.0, 0.0, 200.0, iron, bevel=0.6)
    # The arch over the door, its tympanum and the sunburst crest.
    half, spring, rise = 117.0, 196.0, 48.0
    curve = [(GATE_X - half * math.cos(math.pi * index / 32), spring + rise * math.sin(math.pi * index / 32))
             for index in range(33)]
    gh.band(kit, "Archivolt", curve, 10.0, DOOR_FACE - 2.0, DOOR_FACE + 4.0, brass)
    inner = [(GATE_X - (half - 14.0) * math.cos(math.pi * index / 32),
              spring + (rise - 12.0) * math.sin(math.pi * index / 32)) for index in range(33)]
    kit.slab("Tympanum", inner, DOOR_FACE - 6.0, DOOR_FACE - 1.0, leaf_wood)
    for ray in range(9):
        turn = math.pi * (ray + 0.5) / 9.0
        kit.rod("SunRay%d" % ray, (GATE_X, DOOR_FACE + 1.0, spring + 2.0),
                (GATE_X - 30.0 * math.cos(turn), DOOR_FACE + 1.0, spring + 2.0 + 24.0 * math.sin(turn)), 1.0, brass,
                segments=6)
    face_ring(kit, "SunDisc", GATE_X, DOOR_FACE + 1.5, spring + 4.0, 9.0, 1.6, brass)
    crest = [(GATE_X + 26.0 * math.cos(math.pi * index / 16),
              spring + rise + 6.0 + 18.0 * math.sin(math.pi * index / 16)) for index in range(17)]
    kit.slab("Crest", crest, DOOR_FACE - 2.0, DOOR_FACE + 3.0, brass, bevel=0.4)
    # The two leaves: boards, iron bands and studs.
    for index, (a, b) in enumerate(((GATE_X - 103.0, GATE_X - 0.8), (GATE_X + 0.8, GATE_X + 103.0))):
        boards = 5
        for board in range(boards):
            x0 = a + (b - a) * board / boards
            kit.box("Leaf%d_%d" % (index, board), x0 + 0.25, x0 + (b - a) / boards - 0.25, DOOR_FACE - 6.0,
                    DOOR_FACE, 0.0, 196.0, leaf_wood, bevel=0.5, uv="box_up")
        for h in (20.0, 176.0):
            kit.box("Band%d_%d" % (index, int(h)), a, b, DOOR_FACE, DOOR_FACE + 1.4, h - 4.0, h + 4.0, iron, bevel=0.3)
            for stud in range(6):
                kit.ball("Stud%d_%d_%d" % (index, int(h), stud), a + 8.0 + stud * (b - a - 16.0) / 5.0,
                         DOOR_FACE + 1.8, h, 1.3, brass, plan=0.6)
    for sign in (-1.0, 1.0):
        for index, (h0, h1) in enumerate(((30.0, 82.0), (126.0, 178.0))):
            a, b = sorted((GATE_X + sign * 14.0, GATE_X + sign * 94.0))
            gh.band(kit, "Tracery%+d_%d" % (sign, index), [(a, h0), (b, h0), (b, h1), (a, h1), (a, h0)], 1.6,
                    DOOR_FACE - 0.2, DOOR_FACE + 0.8, brass)
    for (kind, ex, eh) in (("book", GATE_X - 54.0, 150.0), ("flask", GATE_X + 54.0, 150.0),
                           ("bolt", GATE_X - 54.0, 50.0), ("leaf", GATE_X + 54.0, 50.0)):
        face_ring(kit, "EmblemRing" + kind.title(), ex, DOOR_FACE + 1.0, eh, 17.0, 1.2, brass)
        for piece, outline in enumerate(emblem_outline(kind)):
            kit.slab("Emblem%s%d" % (kind.title(), piece), [(ex + px * 11.0, eh + pz * 11.0) for px, pz in outline],
                     DOOR_FACE + 0.4, DOOR_FACE + 2.0, brass, bevel=0.2)
    # The violet core where the leaves meet: rings, spokes and a crystal.
    core_h = 104.0
    for radius, tube in ((40.0, 2.6), (30.0, 1.6), (20.0, 1.4)):
        face_ring(kit, "CoreRing%d" % int(radius), GATE_X, DOOR_FACE + 2.0, core_h, radius, tube, brass)
    for spoke in range(8):
        turn = math.pi * spoke / 4.0 + math.pi / 8.0
        kit.rod("CoreSpoke%d" % spoke,
                (GATE_X + 20.0 * math.cos(turn), DOOR_FACE + 2.0, core_h + 20.0 * math.sin(turn)),
                (GATE_X + 40.0 * math.cos(turn), DOOR_FACE + 2.0, core_h + 40.0 * math.sin(turn)), 1.0, brass,
                segments=6)
    face_disc(kit, "CoreBack", GATE_X, DOOR_FACE, DOOR_FACE + 2.0, core_h, 19.0, iron)
    gem = [(GATE_X, core_h + 15.0), (GATE_X + 11.0, core_h), (GATE_X, core_h - 15.0), (GATE_X - 11.0, core_h)]
    kit.slab("CoreGem", gem, DOOR_FACE + 2.0, DOOR_FACE + 6.0, crystal_glow("FinalCoreCrystal", 0.8), bevel=0.8)
    # The keyhole below the core, in its own brass plate.
    face_disc(kit, "Escutcheon", GATE_X, DOOR_FACE, DOOR_FACE + 1.6, 50.0, 9.0, brass)
    keyhole = ([(GATE_X + 4.0 * math.cos(math.radians(a)), 53.0 + 4.0 * math.sin(math.radians(a)))
                for a in range(-60, 241, 20)] + [(GATE_X - 3.0, 41.0), (GATE_X + 3.0, 41.0)])
    kit.slab("Keyhole", keyhole, DOOR_FACE + 1.4, DOOR_FACE + 2.2, crystal_glow("FinalKeyhole", 0.5))
    kit.light("CoreLight", GATE_X, DOOR_FACE + 12.0, core_h, VIOLET, 10.0, radius=0.05)
    RP.glow("crystal", GATE_X, DOOR_FACE + 2.0, core_h, VIOLET, 36.0)
    # The landing before the gate and its brass-framed mat.
    kit.box("Landing", GATE_X - 140.0, GATE_X + 140.0, GATE_FACE, 1110.0, -6.0, 0.0, stone, bevel=0.8, uv="floor")
    panel = RP.textured("FinalLandingPanel", "large_grey_tiles", 0.6, 0.5, (0.74, 0.72, 0.82), ao=0.1)
    kit.box("Panel", GATE_X - 90.0, GATE_X + 90.0, 1002.0, 1076.0, -0.4, 0.2, panel, bevel=0.0, uv="floor")
    shape = bmesh.new()
    strip(shape, [(GATE_X - 92.0, 1000.0), (GATE_X + 92.0, 1000.0), (GATE_X + 92.0, 1078.0),
                  (GATE_X - 92.0, 1078.0)], 3.0, 0.35, closed=True)
    for start, end in (((GATE_X - 86.0, 1006.0), (GATE_X + 86.0, 1072.0)), ((GATE_X - 86.0, 1072.0),
                                                                          (GATE_X + 86.0, 1006.0))):
        strip(shape, [start, end], 1.6, 0.3)
    kit.shape("PanelFrame", shape, brass_inlay())
    return kit


# ---------------------------------------------------------------- the props


def vault_door():
    """The vault door the game asks the player to inspect (VaultDoorVisual),
    as the painting draws it: a planked door in a heavy frame banded in
    brass, between banded iron columns, its great dial of brass rings round a
    keyhole in a boss, straps and rivets, a brass fan crest above."""
    kit = RP.Kit("VaultDoor", prop="VaultDoorVisual")
    wood = chem.laid("FinalVaultOak", "wood_table", 1.0, 0.55, (0.9, 0.78, 0.68), saturation=0.7, variety=0.16,
                     wear=0.25, ao=0.25, roughness=0.9, coat=0.25, coat_roughness=0.3)
    brass, iron = gold(), hall._cast_iron()
    x0, x1, face, back, top = 668.0, 782.0, FRONT_Y + 1.0, BACK_Y + 12.0, 136.0
    kit.box("Surround", x0 - 12.0, x1 + 12.0, back, face - 4.0, 0.0, top + 8.0, iron, bevel=0.6)
    for x in (x0 - 8.0, x1 + 8.0):
        kit.lathe("Column%d" % int(x), x, face - 3.0, [(0.0, 0.0), (7.5, 0.0), (7.5, 6.0), (5.4, 9.0), (5.0, top - 4.0),
                                                      (7.0, top), (7.5, top + 6.0), (0.0, top + 6.0)], iron,
                  plan=ROUND, segments=20)
        for h in (14.0, 44.0, 74.0, 104.0, 128.0):
            kit.lathe("ColumnBand%d_%d" % (int(x), int(h)), x, face - 3.0, [(0.0, h), (5.9, h), (5.9, h + 3.0),
                                                                          (0.0, h + 3.0)], brass, plan=ROUND,
                      segments=20)
    kit.box("Lintel", x0 - 16.0, x1 + 16.0, back, face + 2.0, top + 6.0, top + 14.0, iron, bevel=0.6)
    kit.box("LintelBand", x0 - 16.0, x1 + 16.0, face + 2.0, face + 3.0, top + 8.0, top + 12.0, brass, bevel=0.3)
    boards = 7
    for board in range(boards):
        a = x0 + (x1 - x0) * board / boards
        kit.box("Board%d" % board, a + 0.25, a + (x1 - x0) / boards - 0.25, face - 6.0, face - 1.0, 4.0, top + 6.0,
                wood, bevel=0.5, uv="box_up")
    straps = [(x0, x1, face - 1.0, face + 0.4, top + 1.0, top + 6.0), (x0, x1, face - 1.0, face + 0.4, 4.0, 9.0),
              (x0, x0 + 5.0, face - 1.0, face + 0.4, 4.0, top + 6.0),
              (x1 - 5.0, x1, face - 1.0, face + 0.4, 4.0, top + 6.0),
              ((x0 + x1) / 2.0 - 2.5, (x0 + x1) / 2.0 + 2.5, face - 1.0, face + 0.4, 4.0, top + 6.0),
              (x0, x1, face - 1.0, face + 0.4, 69.0, 73.0)]
    kit.blocks("Straps", straps, brass, bevel=0.3)
    middle, ch = (x0 + x1) / 2.0, 71.0
    for radius, tube in ((42.0, 2.0), (33.0, 1.4), (24.0, 1.2)):
        face_ring(kit, "DialRing%d" % int(radius), middle, face + 1.0, ch, radius, tube, brass)
    for spoke in range(8):
        turn = math.pi * spoke / 4.0 + math.pi / 8.0
        kit.rod("DialSpoke%d" % spoke, (middle + 13.0 * math.cos(turn), face + 1.0, ch + 13.0 * math.sin(turn)),
                (middle + 42.0 * math.cos(turn), face + 1.0, ch + 42.0 * math.sin(turn)), 0.8, brass, segments=6)
    face_disc(kit, "Boss", middle, face - 1.0, face + 3.0, ch, 13.0, brass)
    keyhole = ([(middle + 4.2 * math.cos(math.radians(a)), ch + 3.0 + 4.2 * math.sin(math.radians(a)))
                for a in range(-60, 241, 20)] + [(middle - 3.0, ch - 9.0), (middle + 3.0, ch - 9.0)])
    kit.slab("Keyhole", keyhole, face + 3.0, face + 3.6, crystal_glow("FinalVaultKeyhole", 0.45))
    kit.light("KeyholeGlow", middle, face + 6.0, ch, VIOLET, 1.2, radius=0.02)
    for row in (6.5, 71.0, top + 3.5):
        for index in range(9):
            kit.ball("Rivet%d_%d" % (int(row), index), x0 + 6.0 + index * (x1 - x0 - 12.0) / 8.0, face + 0.8, row,
                     1.0, brass, plan=0.6)
    # The crest: a brass fan with ribs and two scrolls.
    fan = [(middle + 30.0 * math.cos(math.pi * index / 18), top + 14.0 + 22.0 * math.sin(math.pi * index / 18))
           for index in range(19)]
    kit.slab("Fan", fan, face - 2.0, face + 1.0, brass, bevel=0.4)
    for rib in range(7):
        turn = math.pi * (rib + 0.5) / 7.0
        kit.rod("FanRib%d" % rib, (middle, face + 1.4, top + 15.0),
                (middle + 27.0 * math.cos(turn), face + 1.4, top + 15.0 + 20.0 * math.sin(turn)), 0.7, brass,
                segments=6)
    for sign in (-1.0, 1.0):
        face_ring(kit, "Volute%+d" % sign, middle + sign * 38.0, face, top + 20.0, 6.0, 1.6, brass)
    kit.box("Threshold", x0 - 6.0, x1 + 6.0, face - 8.0, face + 4.0, 0.0, 3.0, brass, bevel=0.4)
    kit.box("LockBox", middle - 9.0, middle + 9.0, face - 1.0, face + 2.0, 6.0, 18.0, brass, bevel=0.5)
    return kit


def analysis_table():
    """The Ashford analysis table the game's deduction is made at
    (FinalAnalysisBoardVisual), a round table at a real size, as the painting
    draws it: six turned legs and a pedestal under a ring of dark oak inside
    a heavy brass rim; on the ring a brass band carries eight slate evidence
    panels in raised brass bezels, each barred to a double brass hoop round a
    top of diagonal boards; studs between the bars and four silver-faced
    bosses between the panels."""
    kit = RP.Kit("AnalysisTable", prop="FinalAnalysisBoardVisual")
    cx, cy = TABLE
    radius, top = TABLE_R, TABLE_TOP
    wood = chem.laid("FinalTableOak", "wood_table", 1.0, 0.8, (0.94, 0.8, 0.68), saturation=0.75, per_island=True,
                     variety=0.2, wear=0.35, ao=0.25, roughness=0.85, coat=0.35, coat_roughness=0.22, bevel=0.01)
    centre = chem.laid("FinalTableCentre", "wood_table", 1.0, 0.55, (0.9, 0.74, 0.62), saturation=0.7,
                       per_island=True, variety=0.12, wear=0.15, ao=0.2, roughness=0.8, coat=0.4, coat_roughness=0.2)
    brass, iron, panel = gold(), hall._cast_iron(), slate()
    silver = hall._prop_metal("FinalSilver", (0.62, 0.64, 0.68), 0.25)
    hoop = 88.0
    legs = top - 12.0
    # Its legs stand out under the rim, so its front at the floor meets its
    # footprint and the game's walk-up band reaches it from the south.
    for index in range(6):
        lx, ly = plan_point(cx, cy, 148.0, 30.0 + 60.0 * index)
        kit.lathe("Leg%d" % index, lx, ly, [(0.0, 0.0), (6.5, 0.0), (6.5, 4.0), (4.5, 8.0), (5.6, 18.0), (3.8, 26.0),
                                            (4.8, legs - 4.0), (5.6, legs), (0.0, legs)], wood, plan=ROUND,
                  segments=16)
    kit.lathe("Pedestal", cx, cy, [(0.0, 0.0), (34.0, 0.0), (34.0, 5.0), (20.0, 10.0), (14.0, 20.0), (14.0, legs - 4.0),
                                   (22.0, legs), (0.0, legs)], wood, plan=ROUND, segments=40)
    shape = bmesh.new()
    for index in range(16):
        sector(shape, cx, cy, 142.0, 152.0, 22.5 * index + 0.6, 22.5 * (index + 1) - 0.6, legs, top - 4.0, steps=4)
    kit.shape("Apron", shape, wood, bevel=0.3, uv="floor")
    shape = bmesh.new()
    for index in range(16):
        sector(shape, cx, cy, hoop + 4.0, radius - 5.0, 22.5 * index + 0.25, 22.5 * (index + 1) - 0.25, top - 4.0,
               top, steps=4)
    kit.shape("Ring", shape, wood, bevel=0.4, uv="floor")
    for name, (r0, r1, h0, h1) in (("Rim", (radius - 5.5, radius + 2.5, top - 7.0, top + 1.4)),
                                   ("RimBead", (radius - 9.0, radius - 6.0, top - 0.2, top + 0.8)),
                                   ("Band", (128.0, 134.0, top - 0.2, top + 0.7)),
                                   ("Hoop", (hoop - 2.0, hoop + 4.0, top - 4.0, top + 2.0)),
                                   ("HoopInner", (hoop - 8.0, hoop - 5.5, top - 0.6, top + 0.6))):
        shape = bmesh.new()
        for half in (0.0, 180.0):
            sector(shape, cx, cy, r0, r1, half, half + 180.0, h0, h1, steps=48)
        kit.shape(name, shape, brass, bevel=0.2)
    disc = [((hoop - 2.0) * math.cos(2.0 * math.pi * index / 72), (hoop - 2.0) * math.sin(2.0 * math.pi * index / 72))
            for index in range(72)]
    shape = bmesh.new()
    diagonal = 1.0 / math.sqrt(2.0)
    for board in range(-7, 7):
        piece = clip(clip(disc, diagonal, diagonal, board * 13.0 + 0.3), -diagonal, -diagonal,
                     -(board + 1) * 13.0 + 0.3)
        if len(piece) >= 3:
            prism(shape, [(cx + x, cy + y * ROUND) for x, y in piece], top - 4.5, top - 0.6)
    kit.shape("Centre", shape, centre, bevel=0.3, uv="floor")
    for index in range(8):
        angle = -90.0 + 45.0 * index
        px, py = plan_point(cx, cy, 131.0, angle)
        real_box(kit, "Bezel%d" % index, px, py, top - 0.2, top + 1.6, 42.0, 42.0, angle, brass, bevel=0.5)
        real_box(kit, "Panel%d" % index, px, py, top + 1.6, top + 2.2, 33.0, 33.0, angle, panel, bevel=0.2)
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                stud_x, stud_y = turned(px, py, sx * 18.0, sy * 18.0, angle)
                kit.ball("BezelStud%d_%d%d" % (index, int(sx), int(sy)), stud_x, stud_y, top + 1.8, 1.3, brass,
                         plan=ROUND, squash=0.5)
        a = plan_point(cx, cy, hoop + 4.0, angle)
        b = plan_point(cx, cy, 110.0, angle)
        kit.rod("Bar%d" % index, (a[0], a[1], top + 1.4), (b[0], b[1], top + 1.4), 1.8, brass, segments=10)
        joint = plan_point(cx, cy, hoop + 6.0, angle)
        real_box(kit, "BarFoot%d" % index, joint[0], joint[1], top, top + 3.0, 5.0, 6.0, angle, brass, bevel=0.4)
        sx_, sy_ = plan_point(cx, cy, 104.0, angle + 22.5)
        kit.ball("Stud%d" % index, sx_, sy_, top + 0.6, 3.2, brass, plan=ROUND, squash=0.45)
        kit.ball("StudGem%d" % index, sx_, sy_, top + 1.6, 1.6, iron, plan=ROUND, squash=0.6)
        rx, ry = plan_point(cx, cy, 150.0, angle + 22.5)
        kit.ball("Rivet%d" % index, rx, ry, top + 0.6, 2.0, brass, plan=ROUND, squash=0.4)
    for index, angle in enumerate((-67.5, -112.5, 67.5, 112.5)):
        bx, by = plan_point(cx, cy, 131.0, angle)
        kit.lathe("Boss%d" % index, bx, by, [(0.0, top), (8.5, top), (8.5, top + 1.4), (7.0, top + 2.4),
                                             (0.0, top + 2.4)], brass, plan=ROUND, segments=24)
        kit.lathe("BossFace%d" % index, bx, by, [(0.0, top + 2.4), (5.6, top + 2.4), (5.6, top + 2.9),
                                                 (0.0, top + 2.9)], silver, plan=ROUND, segments=24)
    return kit


def knowledge_engine():
    """The Knowledge Engine the game guards the archive with
    (KnowledgeEngineVisual), as the painting draws it: on an octagonal dais of
    two steps edged in brass, an iron drum ribbed and banded in brass carries
    a great brass ring round an armillary of brass meridians, its sealed orb
    glowing in the middle and a spindle above; two wheeled instruments of
    glass on arms, copper gears to the south-west and a console of glowing
    gauges at its front."""
    kit = RP.Kit("KnowledgeEngine", prop="KnowledgeEngineVisual")
    cx, cy = ENGINE
    stone = RP.textured("FinalDaisStone", "large_grey_tiles", 0.6, 0.42, (0.74, 0.66, 0.66), ao=0.2)
    brass, copper, iron = gold(), chem.copper(), hall._bronze()
    dark = hall._cast_iron()
    for step, (flats, h0, h1) in enumerate(((ENGINE_R, 0.0, 9.0), (ENGINE_R - 22.0, 9.0, 18.0))):
        shape = bmesh.new()
        prism(shape, octagon(cx, cy, flats), h0, h1)
        kit.shape("Step%d" % step, shape, stone, bevel=0.6, uv="box")
        shape = bmesh.new()
        strip(shape, octagon(cx, cy, flats - 1.4), 2.4, h1 + 0.1, closed=True)
        kit.shape("Nosing%d" % step, shape, brass)
    kit.lathe("Drum", cx, cy, [(0.0, 18.0), (64.0, 18.0), (64.0, 22.0), (60.0, 24.0), (60.0, 54.0), (64.0, 56.0),
                               (64.0, 60.0), (0.0, 60.0)], dark, plan=ROUND, segments=48)
    for h in (20.0, 57.0):
        kit.lathe("DrumBand%d" % int(h), cx, cy, [(0.0, h), (64.6, h), (64.6, h + 2.6), (0.0, h + 2.6)], brass,
                  plan=ROUND, segments=48)
    for index in range(24):
        rx, ry = plan_point(cx, cy, 60.6, 15.0 * index)
        kit.rod("DrumRib%d" % index, (rx, ry, 24.0), (rx, ry, 54.0), 1.3, brass, segments=6)
    kit.lathe("Pillar", cx, cy, [(0.0, 60.0), (16.0, 60.0), (10.0, 66.0), (7.0, 96.0), (11.0, 104.0), (0.0, 104.0)],
              brass, plan=ROUND, segments=24)
    kit.ring("DrumRim", (cx, cy, 61.0), (0.0, 0.0, 1.0), 62.0, 2.2, brass, segments=72, sides=8)
    ch = 128.0
    kit.ring("Equator", (cx, cy, ch), (0.0, 0.0, 1.0), 80.0, 4.6, brass, segments=72, sides=10)
    kit.ring("EquatorOuter", (cx, cy, ch - 3.0), (0.0, 0.0, 1.0), 88.0, 1.8, brass, segments=72, sides=8)
    for index in range(4):
        angle = 45.0 + 90.0 * index
        bx, by = plan_point(cx, cy, 62.0, angle)
        tx, ty = plan_point(cx, cy, 80.0, angle)
        kit.rod("Post%d" % index, (bx, by, 60.0), (tx, ty, ch), 1.6, brass, segments=8)
    tilt = math.radians(23.4)
    for name, axis in (("MeridianA", (1.0, 0.0, 0.0)), ("MeridianB", (0.0, 1.0, 0.0)),
                       ("MeridianC", (math.cos(math.radians(45.0)), math.sin(math.radians(45.0)), 0.0)),
                       ("Ecliptic", (math.sin(tilt), 0.0, math.cos(tilt)))):
        kit.ring(name, (cx, cy, ch), axis, 50.0, 2.2, brass, segments=56, sides=8)
    orb = kit.ball("Orb", cx, cy, ch, 26.0, orb_glass(), plan=ROUND, squash=SIN, segments=32)
    orb.visible_shadow = False
    kit.ball("OrbCore", cx, cy, ch, 7.0, orb_glow("FinalOrbCore", 1.4), plan=ROUND, squash=SIN, segments=20)
    for name, axis in (("OrbBandA", (1.0, 0.0, 0.0)), ("OrbBandB", (0.0, 1.0, 0.0))):
        kit.ring(name, (cx, cy, ch), axis, 26.4, 0.7, brass, segments=48, sides=6)
    kit.light("OrbLight", cx, cy - 4.0, ch + 34.0, ORB, 3.0, radius=0.06)
    # The orrery's planets on their arms from the pillar, each at its own
    # radius and height: copper, silver, blue glass and a ringed one.
    silver = hall._prop_metal("FinalPlanetSilver", (0.6, 0.62, 0.66), 0.25)
    planets = ((60.0, 200.0, ch - 30.0, 4.4, copper),
               (68.0, 320.0, ch - 22.0, 5.2, lens_glass("FinalPlanetBlue", 0.15)),
               (74.0, 20.0, ch - 14.0, 3.6, silver), (64.0, 120.0, ch - 26.0, 6.0, brass))
    for index, (reach, angle, h, size, material) in enumerate(planets):
        px, py = plan_point(cx, cy, reach, angle)
        kit.rod("PlanetArm%d" % index, (cx, cy, 100.0 + index * 2.0), (px, py, h), 0.8, brass, segments=8)
        kit.ball("Planet%d" % index, px, py, h, size, material, plan=ROUND, squash=SIN, segments=20)
        if index == 3:
            kit.ring("PlanetRing%d" % index, (px, py, h), (0.3, 0.0, 1.0), size + 3.4, 0.6, brass, segments=32)
    RP.glow("crystal", cx, cy, ch, ORB, 34.0)
    kit.rod("Spindle", (cx, cy, ch + 30.0), (cx, cy, ch + 70.0), 1.4, brass, segments=10)
    kit.ball("Finial", cx, cy, ch + 72.0, 3.2, brass, plan=ROUND, squash=SIN)
    wheels = (("WestWheel", (cx - 98.0, cy - 30.0, 168.0, (cx - 52.0, cy - 8.0, ch + 18.0))),
              ("EastWheel", (cx + 104.0, cy - 6.0, 146.0, (cx + 78.0, cy, ch))))
    for name, (wx, wy, wh, reach_from) in wheels:
        kit.rod(name + "Arm", reach_from, (wx, wy, wh), 1.4, brass, segments=8)
        face_ring(kit, name, wx, wy, wh, 20.0, 1.8, brass)
        face_disc(kit, name + "Glass", wx, wy - 0.4, wy + 0.4, wh, 18.0, lens_glass())
        for spoke in range(8):
            turn = math.pi * spoke / 4.0
            kit.rod("%sSpoke%d" % (name, spoke), (wx, wy + 0.8, wh),
                    (wx + 24.0 * math.cos(turn), wy + 0.8, wh + 24.0 * math.sin(turn)), 0.6, brass, segments=6)
    for index, angle in enumerate((-157.5, -22.5, 22.5, 157.5)):
        px, py = octagon(cx, cy, ENGINE_R - 30.0)[(int((angle + 360.0) % 360.0 // 45.0)) % 8]
        kit.rod("Finial%d" % index, (px, py, 18.0), (px, py, 44.0), 1.4, brass, segments=8)
        kit.ball("FinialBall%d" % index, px, py, 46.0, 3.0, brass, plan=ROUND, squash=SIN)
    # The console at its front, its gauges glowing.
    y0, y1 = cy + 52.0, cy + 74.0
    kit.box("Console", cx - 46.0, cx + 46.0, y0, y1, 18.0, 40.0, iron, bevel=0.8)
    kit.slab("ConsoleDesk", [(cx - 46.0, 40.0), (cx + 46.0, 40.0), (cx + 46.0, 46.0), (cx - 46.0, 46.0)], y0, y1 - 8.0,
             brass, bevel=0.4)
    for index, gx in enumerate((cx - 28.0, cx, cx + 28.0)):
        face_disc(kit, "Gauge%d" % index, gx, y1 - 1.0, y1 + 0.6, 30.0, 7.0, lens_glass("FinalGauge", 0.18))
        face_ring(kit, "GaugeRim%d" % index, gx, y1 + 0.8, 30.0, 7.4, 0.9, brass)
        kit.rod("Needle%d" % index, (gx, y1 + 1.2, 30.0), (gx + 4.0, y1 + 1.2, 33.5), 0.35, iron, segments=6)
    for index, kx in enumerate((cx - 40.0, cx + 40.0)):
        kit.ball("Knob%d" % index, kx, y1 + 1.0, 24.0, 2.2, brass, plan=0.6)
    kit.light("ConsoleLight", cx, y1 + 12.0, 32.0, ORB, 1.2, radius=0.05)
    # Copper gears to the south-west, turned to face the room.
    for index, (gx, gh_, radius) in enumerate(((cx - 76.0, 34.0, 13.0), (cx - 58.0, 26.0, 8.0))):
        gy = cy + 48.0 + index * 4.0
        face_disc(kit, "Gear%d" % index, gx, gy - 2.0, gy + 2.0, gh_, radius, copper)
        teeth = int(radius * 1.4)
        for tooth in range(teeth):
            turn = 2.0 * math.pi * tooth / teeth
            tx, th = gx + (radius + 1.6) * math.cos(turn), gh_ + (radius + 1.6) * math.sin(turn)
            kit.box("Gear%dTooth%d" % (index, tooth), tx - 1.2, tx + 1.2, gy - 2.0, gy + 2.0, th - 1.2, th + 1.2,
                    copper, bevel=0.2)
        face_disc(kit, "GearHub%d" % index, gx, gy + 1.0, gy + 3.0, gh_, radius * 0.3, brass)
    return kit


def notebook():
    """Mrs. Lin's notebook by her hand (NotebookVisual), as the painting draws
    it: navy leather with brass corners and a star tooled on it, a buckled
    strap, a violet ribbon, loose pages under it; at a notebook's size."""
    kit = RP.Kit("Notebook", prop="NotebookVisual")
    x, y = NOTEBOOK
    turn = -24.0
    cover = wake.leather("FinalNotebookCover", (0.05, 0.065, 0.15))
    brass = gold()
    for index, (dx, dy, twist) in enumerate(((-5.0, 7.0, 12.0), (7.0, 4.0, -16.0))):
        px, py = turned(x, y, dx, dy, turn)
        real_box(kit, "Loose%d" % index, px, py, 0.0, 0.25, 21.0, 28.0, turn + twist,
                 wake.writing("FinalNotebookPage", lines=10.0), bevel=0.0)
    real_box(kit, "BackBoard", x, y, 0.3, 0.9, 22.0, 28.0, turn, cover, bevel=0.2)
    px, py = turned(x, y, 0.4, 0.0, turn)
    real_box(kit, "Pages", px, py, 0.9, 2.7, 21.0, 27.0, turn, wake.parchment(), bevel=0.1)
    real_box(kit, "FrontBoard", x, y, 2.7, 3.3, 22.0, 28.0, turn, cover, bevel=0.2)
    px, py = turned(x, y, -10.6, 0.0, turn)
    real_box(kit, "Spine", px, py, 0.3, 3.3, 1.6, 28.0, turn, cover, bevel=0.4)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            px, py = turned(x, y, sx * 9.5, sy * 12.5, turn)
            real_box(kit, "Corner%d%d" % (int(sx), int(sy)), px, py, 3.2, 3.6, 3.4, 3.4, turn, brass, bevel=0.1)
    px, py = turned(x, y, 8.5, 0.0, turn)
    real_box(kit, "Strap", px, py, 3.3, 3.7, 4.0, 28.6, turn, wake.leather("FinalNotebookStrap", (0.16, 0.08, 0.05)),
             bevel=0.1)
    px, py = turned(x, y, 8.5, 0.0, turn)
    real_box(kit, "Buckle", px, py, 3.7, 4.2, 5.0, 4.0, turn, brass, bevel=0.2)
    star = []
    for index in range(10):
        reach = 6.0 if index % 2 == 0 else 2.2
        angle = math.radians(-90.0 + 36.0 * index + turn)
        star.append((x - 1.0 + reach * math.cos(angle), y + reach * math.sin(angle) * ROUND))
    kit.slab("Star", star, 3.3, 3.5, brass, plane="floor")
    px, py = turned(x, y, -4.0, 16.0, turn)
    real_box(kit, "Ribbon", px, py, 0.4, 0.6, 1.6, 9.0, turn + 8.0, hall._cloth("FinalRibbon", (0.32, 0.06, 0.42)),
             bevel=0.0)
    return kit


def fallen_lin():
    """Mrs. Lin where she fell (MrsLinBody): the Tripo Dr. Lin posed from her
    rest pose, laid on her right side and rolled onto her front, and set on
    the flagstones at the body's footprint, the torn violet cuff in her upper
    hand."""
    kit = RP.Kit("MrsLin", prop="MrsLinBody")
    if not os.path.exists(LIN_GLB):
        print("MODEL MISSING " + LIN_GLB)
        return kit
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(LIN_GLB))
    new = [obj for obj in bpy.data.objects if obj not in before]
    armature = next(obj for obj in new if obj.type == "ARMATURE")
    meshes = [obj for obj in new if obj.type == "MESH" and obj.parent == armature]
    # Tripo's export carries a stray untextured icosphere round the origin.
    for obj in new:
        if obj.type == "MESH" and obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    if armature.animation_data is not None:
        for track in armature.animation_data.nla_tracks:
            track.mute = True
        armature.animation_data.action = None
    pivot = RP._link(bpy.data.objects.new("MrsLinPivot", None))
    armature.parent = pivot
    low, high = _lin_extent(meshes)
    height = high.z - low.z
    laid = (Matrix.Rotation(math.radians(LIN_TURN), 4, "Z") @ Matrix.Rotation(math.radians(LIN_ROLL), 4, "X")
            @ Matrix.Rotation(math.radians(-90.0), 4, "Y"))
    pivot.matrix_world = laid
    bpy.context.view_layer.update()
    # The room's directions in the armature's own frame, where the pose works.
    to_rig = armature.matrix_world.to_3x3().normalized().inverted()
    rig = motion.Rig(armature)
    rig.reset()
    pose = motion.Pose(rig, rig.capture())
    for name, degrees in (("Spine", 7.0), ("Spine1", 7.0), ("Spine2", 6.0)):
        pose.turn(motion.bone(name), motion.rotation(motion.LEFT, degrees))
    pose.turn(motion.bone("Head"), motion.rotation(motion.FORWARD, 14.0))
    for name, direction in LIN_POSE:
        pose.aim(motion.bone(name), to_rig @ Vector(direction))
    for side, curl in LIN_CURL.items():
        for finger in motion.FINGERS + ("Thumb",):
            for joint, share in ((1, 1.0), (2, 1.1), (3, 0.8)):
                name = motion.bone("%sHand%s%d" % (side, finger, joint))
                if name in pose.channels:
                    angle = curl * share * (0.55 if finger == "Thumb" else 1.0)
                    pose.set_rotation(name, Quaternion((1.0, 0.0, 0.0), math.radians(angle * rig.curl_sign[name])))
    rig.apply(pose.channels)
    laid = laid @ Matrix.Scale(LIN_HEIGHT * RP.PX / height, 4)
    pivot.matrix_world = laid
    low, high = _lin_extent(meshes)
    target = RP.world(LIN_FLOOR[0], LIN_FLOOR[1], 0.0)
    pivot.matrix_world = Matrix.Translation(Vector(((target.x - (low.x + high.x) / 2.0),
                                                    (target.y - (low.y + high.y) / 2.0), -low.z))) @ laid
    bpy.context.view_layer.update()
    low, high = _lin_extent(meshes)
    print("MRS LIN laid: %.0f x %.0f game px across the plan, %.1f cm high, centre (%.0f, %.0f)" % (
        (high.x - low.x) / RP.PX, (high.y - low.y) / (RP.PX * RP.STRETCH), (high.z - low.z) / RP.PX,
        RP.game((low + high) / 2.0).x, RP.game((low + high) / 2.0).y))
    for obj in meshes:
        kit.keep(obj)
    lit = meshes + _lin_cuff(kit, armature)
    _lin_key(lit)
    return kit


def _lin_extent(meshes):
    """The lowest and highest corner of every skinned vertex as posed now."""
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    chunks = []
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        coords = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", coords)
        matrix = np.array(evaluated.matrix_world)
        evaluated.to_mesh_clear()
        chunks.append(coords.reshape(-1, 3) @ matrix[:3, :3].T + matrix[:3, 3])
    points = np.concatenate(chunks)
    return Vector(points.min(axis=0).tolist()), Vector(points.max(axis=0).tolist())


def _lin_cuff(kit, armature):
    """The torn violet cuff, rolled in her upper hand: copper thread at its
    hem. Returns its objects."""
    hand = armature.pose.bones[motion.bone("LeftHand")]
    head = armature.matrix_world @ hand.head
    tail = armature.matrix_world @ hand.tail
    centre = head + (tail - head) * 0.9
    along = (tail - head).normalized().cross(Vector((0.0, 0.0, 1.0)))
    if along.length < 1e-6:
        along = Vector((1.0, 0.0, 0.0))
    along.normalize()
    made = []
    for part, radius, length, material in (
            ("Cuff", 2.4, 11.0, hall._cloth("FinalCuff", (0.32, 0.06, 0.42))),
            ("Thread", 2.6, 0.8, gold())):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius * RP.PX, depth=length * RP.PX,
                                            location=centre + along * (5.0 * RP.PX if part == "Thread" else 0.0))
        obj = bpy.context.active_object
        obj.name = "MrsLin" + part
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(along)
        obj.data.materials.append(material)
        made.append(kit.keep(obj))
    return made


def _lin_key(lit):
    """A soft warm light over Mrs. Lin that lights only `lit`."""
    receivers = bpy.data.collections.new("MrsLinLit")
    for obj in lit:
        receivers.objects.link(obj)
    data = bpy.data.lights.new("MrsLinKey", "AREA")
    data.energy = LIN_KEY_POWER
    data.color = (1.0, 0.86, 0.72)
    data.size = 80.0 * RP.PX
    light = RP._link(bpy.data.objects.new("MrsLinKey", data))
    x, y = LIN_FLOOR
    light.location = RP.world(x, y + 40.0, LIN_KEY_HEIGHT * RP.SIN)
    light.rotation_euler = (light.location - RP.world(x, y, 0.0)).to_track_quat("Z", "Y").to_euler()
    light.light_linking.receiver_collection = receivers


# ---------------------------------------------------------------- the room


def footprints():
    """The collision the HD room needs: the props' own footprints in place of
    the painted ones, footprints for the furniture the painted room lets the
    player walk through, and the south walls ending where the floor really
    does, at its edge and at the gate's base. The painted walls end at the
    top of the door as the painting draws it, which leaves an invisible wall
    across the floor before the gate."""
    def rect(x0, x1, y0, y1):
        return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]

    cx, cy = TABLE
    table_outline = [list(plan_point(cx, cy, TABLE_R + 1.0, 360.0 * index / 32)) for index in range(32)]
    ex, ey = ENGINE
    engine_outline = [list(point) for point in octagon(ex, ey, ENGINE_R + 3.0)]
    x, y = NOTEBOOK
    kx, ky, width, depth, _height, turn = CRATE
    crate_outline = [list(turned(kx, ky, sx * (width / 2.0 + 3.0), sy * (depth / 2.0 + 3.0), turn))
                     for sx, sy in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0))]
    # Split at the gate's middle, where the painted pair meet; each overlaps
    # the side wall it joins.
    door_y = floor_south(GATE_X)
    west = [p for p in GATE_BACK if p[0] < GATE_X]
    east = [p for p in GATE_BACK if p[0] > GATE_X]
    south_west = ([[206.0, EDGE_Y], [west[0][0], EDGE_Y]] + [list(p) for p in west]
                  + [[GATE_X, door_y], [GATE_X, 1100.0], [206.0, 1100.0]])
    south_east = ([[GATE_X, door_y]] + [list(p) for p in east]
                  + [[east[-1][0], EDGE_Y], [1062.0, EDGE_Y], [1062.0, 1100.0], [GATE_X, 1100.0]])
    return {
        "FinalAnalysisBoardVisual/FurnitureCollision/CollisionShape2D": table_outline,
        "KnowledgeEngineVisual/FurnitureCollision/CollisionShape2D": engine_outline,
        "VaultDoorVisual/FurnitureCollision/CollisionShape2D": rect(650.0, 800.0, BACK_Y + 10.0, FRONT_Y + 6.0),
        "NotebookVisual/FurnitureCollision/CollisionShape2D": rect(x - 16.0, x + 16.0, y - 12.0, y + 12.0),
        # Mrs. Lin's footprint ends at the south where she meets the floor, so
        # the player can come up to her from the room as the painted one lets.
        "MrsLinBody/FurnitureCollision/CollisionShape2D": rect(*LIN_FOOTPRINT),
        "RoomCollisions/HDWestVitrine": rect(140.0, 212.0, 386.0, 542.0),
        "RoomCollisions/HDWestTable": rect(250.0, 330.0, 384.0, 542.0),
        "RoomCollisions/HDCrate": crate_outline,
        "RoomCollisions/HDEastTable": rect(1088.0, 1218.0, 746.0, 800.0),
        "RoomCollisions/BottomLeftWall": south_west,
        "RoomCollisions/BottomRightWall": south_east,
    }


def ambience():
    """The room's even, warm light as the painting draws it, from no lamp in
    particular: a broad soft light high over the middle. Violet stays in the
    lamps, the windows and the grates."""
    data = bpy.data.lights.new("FinalFill", "AREA")
    data.energy = FILL_POWER
    data.color = (1.0, 0.87, 0.72)
    data.size = 900.0 * RP.PX
    light = RP._link(bpy.data.objects.new("FinalFill", data))
    light.location = RP.world(TABLE[0], TABLE[1] - 40.0, 420.0)
    data = bpy.data.lights.new("FinalWarmSky", "SUN")
    data.energy = SUN_POWER
    data.color = (1.0, 0.86, 0.7)
    data.angle = math.radians(30.0)
    sun = RP._link(bpy.data.objects.new("FinalWarmSky", data))
    sun.rotation_euler = Vector((0.08, 0.3, -0.95)).normalized().to_track_quat("-Z", "Y").to_euler()


def grade(scene):
    """The room's exposure and white balance, set after the shared Cycles
    setup: as dark and as warm as the painted room (mean luminance 26, red
    over blue +7)."""
    scene.view_settings.exposure = 0.3
    scene.view_settings.use_white_balance = True
    scene.view_settings.white_balance_temperature = 6800.0


def finish():
    amber_lanterns()


def build(rp, layout):
    global RP, MODELS
    RP = rp
    wake.RP = rp
    chem.RP = rp
    gh.RP = rp
    MODELS = rp.ModelSet()
    chem.MODELS = MODELS
    shell_materials = {
        "floor": chem.grout(),
        "wall": wall_stone(),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if rp.TEXTURES.available()
                else rp.textured("FinalCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if rp.TEXTURES.available()
                else rp.textured("FinalLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("FinalReveal", "castle_wall_slates", 1.5, 0.5, (0.72, 0.68, 0.8), ao=0.2),
    }
    shell = rp.Shell(SPEC, shell_materials)
    shell.build()
    north_masonry()
    window_glass()
    scroll_alcoves()
    north_cabinets()
    north_lights()
    west_wall(shell)
    east_wall(shell)
    violet_cabinet()
    west_vitrine()
    east_vitrines()
    west_table()
    east_table()
    crate()
    flagstones()
    inlay()
    grates()
    floor_dressing()
    south_edge()
    south_gate()
    ambience()
    wake.moon_sky()
    bpy.data.objects["WakeMoonSky"].data.energy = 0.45
    props = {"VaultDoorVisual": vault_door(), "FinalAnalysisBoardVisual": analysis_table(),
             "KnowledgeEngineVisual": knowledge_engine(), "NotebookVisual": notebook(),
             "MrsLinBody": fallen_lin()}
    finish()
    print("FINAL ROOM built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    return {"props": props, "roots": {name: name for name in props}, "collision": footprints()}
