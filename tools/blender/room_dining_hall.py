"""The Dining Hall, where the last dinner was served, for the Blender room
prototype. tools/blender/room_prototype.py imports it as room_dining_hall and
calls build() on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). The room is
1448 x 1086 and the game's camera follows the player through it. Everything
is built as the painted room draws it (dining_hall_banquet.png and the
props in assets/props/DiningHall/), on the floor its collision blocks, in
the Hall's materials and light, as the Greenhouse was:

  north   the stone fireplace with its chimney, mantel candles, clock and a
          shield on its hood (Worldsort/Fireplace), its fire tools and logs;
          a portrait each side; two gothic windows between red velvet
          curtains; three-candle sconces; the barred wall door
          (Worldsort/WallDoor) and a serving table in the north-east corner
  middle  the long banquet table (Worldsort/DiningTable) laid for eight,
          wine spilt and a chair pushed back at each end, on a red rug; the
          wheel chandelier over it (ChandelierSprite), drawn above everyone
  west    the dresser of plates (Worldsort/Cabinet) and its jug table
  east    the longcase clock stopped at midnight (Worldsort/GrandfatherClock)
          and the laden sideboard with its torn red cloth (Worldsort/Sideboard)
  south   the arched double door (Worldsort/MainDoor) between stone pillars
          and two torches
  floor   grey flagstones in courses, muddy boot prints from the wall door
          toward the clock and from the table to the main door

Stone, boards and pavers are laid piece by piece from CC0 photos, each its
own shade (room_greenhouse.laid_photo); tableware, wine and fruit are CC0
Poly Haven models (tools/blender/cc0_models.json). The Greenhouse's helpers
are imported as a library, as the rooms import hall_prototype and room_wake.

The furniture is a real room's size by the room standard (the detective is
1.4 m): the painting draws its table, clock, sideboard and serving table
far larger, so their loads are laid out on the painted ones and drawn in,
and build() returns the real footprints in place of the painted ones.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import hall_prototype as hall
import room_greenhouse as gh
import room_wake as wake

RP = None
MODEL = None

BACK_Y = 252.0
WALL_H = 222.0
LEAN = 18.0
LEFT_BASE = ((56.0, BACK_Y), (46.0, 980.0))
RIGHT_BASE = ((1391.0, BACK_Y), (1415.0, 980.0))
# The south wall as the painting draws it, seen from the room over its top:
# a low wall, its face on the door's line, rising to a parapet round the
# door with a dark recess each side, a torch block proud of it each side,
# and a pilaster each side of the arched double door.
SOUTH_Y = 1037.0
DOOR_FACE_Y = 1052.0
SOUTH_H = 52.0
PARAPET_X = (440.0, 1012.0)
PARAPET_H = 87.0
RECESSES = ((465.0, 527.0), (920.0, 988.0))
DOOR_X = (658.0, 790.0)
DOOR_CX = (DOOR_X[0] + DOOR_X[1]) / 2.0
DOOR_EAVE = 77.0
DOOR_APEX = 104.0
PILASTERS = ((641.0, DOOR_X[0]), (DOOR_X[1], 807.0))
PILASTER_H = 80.0
TORCH_BLOCKS = ((527.0, 600.0), (848.0, 920.0))
TORCH_BLOCK_H = 102.0
TORCH_X = (563.5, 884.0)
# The windows: pointed arches over two lights, between the curtains.
WINDOWS = ((457.0, 547.0), (900.0, 990.0))
WINDOW_SILL = 36.0
WINDOW_SPRING = 148.0
WINDOW_APEX = 196.0
WINDOW_GLASS_Y = BACK_Y - 28.0
CURTAINS = ((360.0, 447.0), (556.0, 643.0), (806.0, 893.0), (1000.0, 1087.0))
CURTAIN_TOP = 214.0
TIEBACK_H = 74.0
# The fireplace: hearth, firebox surround and mantel at the front, the hood
# and chimney stack set back above it.
FIRE_X = (66.0, 282.0)
FIRE_CX = (FIRE_X[0] + FIRE_X[1]) / 2.0
FIRE_FACE_Y = 345.0
HEARTH_Y = 357.0
MANTEL_H = 115.0
HOOD_Y = 302.0
CHIMNEY_TOP = 286.0
# The banquet table at a real table's size by the room standard (3.2 m by
# 1.15 m and 76 cm high against the 1.4 m detective), where the painting
# draws one 5.1 by 2.8 m and 53 cm high, on the painted table's middle. Its
# places, candles and wine are laid out on the painted table and drawn in
# onto the real one (on_table); its rug lies under it and its chairs.
PAINTED_TABLE = (435.0, 946.0, 468.0, 681.0)
TABLE = (530.7, 850.7, 530.3, 618.3)
TABLE_TOP = 49.0
TABLE_RUG = (428.0, 954.0, 466.0, 706.0)
CHANDELIER = (725.0, 470.0)
CHANDELIER_H = 226.0
CHANDELIER_R = 72.0
WALL_DOOR = (1166.0, 1285.0)
WALL_DOOR_FACE = 271.0
# The clock is modelled on the painting's (86 cm wide, 3.6 m tall) and scaled
# about the middle of its foot to a real longcase clock's: 52 cm wide, 2.1 m,
# its east side by the east wall as the painted one stands.
CLOCK = (1327.0, 1413.0, 556.0, 589.0)
CLOCK_SCALE = 0.6
# The sideboard back to the east wall at a real size: 2.2 m long and 60 cm
# deep with its raised back shelf (east of GALLERY_X), 87 cm high, where the
# painting draws it 4.1 m by 1.6 m. Its load is laid out on the painted one
# and drawn in (on_sideboard).
PAINTED_SIDEBOARD = (1222.0, 1378.0, 655.0, 972.0)
PAINTED_GALLERY_X = 1320.0
SIDEBOARD = (1342.0, 1402.0, 729.0, 898.0)
SIDEBOARD_TOP = 56.0
GALLERY_X = 1386.0
# The serving table in the north-east corner, 55 cm deep against the north
# wall (the painting's is 1.25 m, the notch the room's wall collision leaves).
SERVING = (1302.0, 1386.0, 254.0, 296.0)
# The dresser stands by the west wall turned toward the room, as the
# painting draws it: its front's middle on the floor, and how far its front
# is turned from facing south toward the east (in the room, not on screen).
DRESSER = (150.0, 784.0)
DRESSER_TURN = math.radians(31.0)
# The hall's furnishings (stage 67), on the floor the real-size furniture
# leaves open, each clear of every prompt's floor, the arrival and the boot
# prints: a bench under each window (in front of its sill), two chairs and a
# low table at the hearth, a heraldic trophy between the wall door and the
# clock, a chest in the south-west corner, two casks against the south wall
# in the east, and two floor candelabra either side of the way in.
WINDOW_BENCH_X = (502.0, 945.0)
BENCH_HALF = 50.0
BENCH_Y = (BACK_Y + 8.0, BACK_Y + 39.0)
FIRESIDE_CHAIRS = ((112.0, 448.0), (236.0, 448.0))
FIRESIDE_TABLE = (174.0, 425.0)
TROPHY = (1330.0, 430.0)
CHEST = (158.0, 950.0)
CASKS = ((1110.0, 946.0), (1188.0, 946.0))
CANDELABRA = ((606.0, 900.0), (842.0, 900.0))
ROUND = math.cos(math.radians(hall.ALPHA_DEGREES))
CANDLE = (1.0, 0.6, 0.28)
FIRE = (1.0, 0.42, 0.14)
MOON = (0.55, 0.68, 1.0)
WINE = (0.42, 0.02, 0.03)
# The grade and the flagstones' shade, by the room standard against the
# painting; each can be overridden from the environment to tune it.
DINING_EXPOSURE = float(os.environ.get("DINING_EXPOSURE", "0.35"))
DINING_WHITE_BALANCE = float(os.environ.get("DINING_WHITE_BALANCE", "7400"))
FLOOR_VALUE = float(os.environ.get("DINING_FLOOR_VALUE", "1.7"))


def window_outline(x0, x1):
    return gh.lancet_outline(x0, x1, WINDOW_SILL, WINDOW_SPRING, WINDOW_APEX)


SPEC = {
    "back": {"y": BACK_Y, "base": (LEFT_BASE[0][0], RIGHT_BASE[0][0]),
             "top": (LEFT_BASE[0][0] - LEAN, RIGHT_BASE[0][0] + LEAN), "height": WALL_H,
             "openings": [{"outline": window_outline(x0, x1)} for x0, x1 in WINDOWS]},
    "left": {"base": LEFT_BASE, "near": 1086.0 + WALL_H},
    "right": {"base": RIGHT_BASE, "near": 1086.0 + WALL_H},
    "south": {"y": SOUTH_Y, "height": SOUTH_H, "depth": DOOR_FACE_Y - SOUTH_Y},
    "floor": {"x": (-60.0, 1508.0), "y": (180.0, 1120.0)},
    "cap": 40.0,
}


# ---------------------------------------------------------------- materials


def oak():
    """The table's and chairs' oak: worn, warm, each board its own part of
    the photo, its rims worn paler."""
    return gh.laid_photo("DiningOak", "wood_table_worn", 0.5, 0.86, (0.94, 0.9, 0.44), saturation=0.85,
                         variety=0.14, wear=0.12)


def walnut():
    """The dresser's, clock's and sideboard's darker wood: brown, as the
    painting's, not the red of a mahogany photo."""
    return gh.laid_photo("DiningWalnut", "wood_table", 0.45, 0.6, (1.0, 0.92, 0.5), saturation=0.85,
                         variety=0.14, wear=0.25)


def planks():
    """The doors' rough boards."""
    return gh.laid_photo("DiningPlanks", "wood_cabinet_worn_long", 0.42, 1.3, (0.92, 0.96, 0.9),
                         saturation=0.85, variety=0.18)


def ashlar():
    """Dressed grey stone for the fireplace, the door surrounds and pillars,
    each block its own shade."""
    return gh.laid_photo("DiningAshlar", "seaside_rock", 0.7, 1.55, (0.8, 0.74, 0.6), saturation=0.3,
                         variety=0.2, wear=0.35, ao=0.15)


def velvet():
    """The curtains' and chairs' red velvet, its pile catching the light."""
    material = RP.textured("DiningVelvet", "velour_velvet", 0.3, 1.0, (0.36, 0.05, 0.026), saturation=0.0, ao=0.3)
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Sheen Weight"].default_value = 0.45
            node.inputs["Sheen Roughness"].default_value = 0.35
            node.inputs["Sheen Tint"].default_value = (1.0, 0.55, 0.32, 1.0)
    return material


def pewter():
    return hall._prop_metal("DiningPewter", (0.4, 0.4, 0.41), 0.34)


def silver():
    return hall._prop_metal("DiningSilver", (0.72, 0.71, 0.69), 0.2)


def gilt():
    return wake.gilt()


def linen():
    return hall._material("DiningLinen", lambda nodes, links: hall._principled(
        nodes, links, (0.3, 0.26, 0.19), roughness=0.85))


def wine_material():
    def build(nodes, links):
        shader = hall._principled(nodes, links, WINE, roughness=0.05)
        shader.inputs["Transmission Weight"].default_value = 0.4
    return hall._material("DiningWine", build)


def night_glass(name, x0, x1):
    """Leaded panes on the night sky, the moon to the upper east: dark blue,
    paler toward the arch's head. UVs are the opening's own (x, h) in px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        column = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("SUBTRACT", u, x0), 11.25)), 0.5))
        row = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", v, 13.0)), 0.5))
        lead = op("MAXIMUM", op("GREATER_THAN", column, 0.44), op("GREATER_THAN", row, 0.45))
        pane = nodes.new("ShaderNodeTexVoronoi")
        pane.inputs["Scale"].default_value = 0.1
        links.new(coords.outputs["UV"], pane.inputs["Vector"])
        across = op("DIVIDE", op("SUBTRACT", u, x0), max(x1 - x0, 1.0))
        up = op("DIVIDE", op("SUBTRACT", v, WINDOW_SILL), WINDOW_APEX - WINDOW_SILL)
        sky = op("ADD", 0.32, op("MULTIPLY", op("ADD", op("MULTIPLY", up, 0.7), op("MULTIPLY", across, 0.3)), 0.7))
        tint = hall._mix(nodes, links, pane.outputs["Distance"], (0.04, 0.07, 0.2), (0.12, 0.18, 0.4))
        glass = op("MULTIPLY", sky, op("SUBTRACT", 1.0, lead))
        hall._principled(nodes, links, (0.008, 0.009, 0.014), roughness=0.25, emission=tint,
                         emission_strength=op("MULTIPLY", glass, 0.13))
    return hall._material(name, build)


def rug_material(name, length, width, border=14.0):
    """A banquet rug: a deep red field, a gold border between two fine lines,
    corner and middle ornaments, worn where feet go. UVs are px: u along its
    length, v across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        to_end = op("MINIMUM", u, op("SUBTRACT", length, u))
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        edge = op("MINIMUM", to_end, to_side)
        band = op.between(edge, border * 0.35, border)
        lines = op("MAXIMUM", op.between(edge, border * 0.18, border * 0.28), op.between(edge, border * 1.12,
                                                                                         border * 1.22))
        # A running scroll in the gold band.
        scroll_along = op("ADD", op("MULTIPLY", op("LESS_THAN", to_side, to_end), u),
                          op("MULTIPLY", op("GREATER_THAN", to_side, to_end), v))
        scroll = op("MULTIPLY", band, op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op(
            "FRACT", op("DIVIDE", op("ADD", scroll_along, op("MULTIPLY", edge, 1.4)), border * 1.6)), 0.5)), 0.12))
        du = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", u, length / 2.0)), length / 2.0 - border * 1.5)
        dv = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0 - border * 1.5)
        # A scroll in each corner of the field: a quarter ring round its
        # corner and a boss inside it.
        ex = op("SUBTRACT", to_end, border * 1.5)
        ey = op("SUBTRACT", to_side, border * 1.5)
        reach = op("SQRT", op("ADD", op("MULTIPLY", ex, ex), op("MULTIPLY", ey, ey)))
        bx, by = op("SUBTRACT", ex, border * 0.9), op("SUBTRACT", ey, border * 0.9)
        boss = op("LESS_THAN", op("ADD", op("MULTIPLY", bx, bx), op("MULTIPLY", by, by)), (border * 0.38) ** 2)
        corner = op("MULTIPLY", op("MULTIPLY", op("GREATER_THAN", ex, 0.0), op("GREATER_THAN", ey, 0.0)),
                    op("MAXIMUM", op.between(reach, border * 1.7, border * 1.95), boss))
        lozenge = op("ADD", op("MULTIPLY", du, 1.0), op("MULTIPLY", dv, 0.6))
        medallion = op("MAXIMUM", op.between(lozenge, 0.22, 0.25), op("LESS_THAN", lozenge, 0.08))
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=0.35, detail=6.0)
        wear = hall._ramp(nodes, links, op("ADD", weave, op("MULTIPLY", op("SUBTRACT", 0.6, dv), 0.3)), 0.62, 0.95)
        field = hall._mix(nodes, links, weave, (0.09, 0.019, 0.012), (0.145, 0.034, 0.02))
        gold = (0.25, 0.14, 0.045)
        color = hall._mix(nodes, links, band, field, (0.05, 0.018, 0.011))
        color = hall._mix(nodes, links, op("MINIMUM", op("ADD", op("ADD", lines, op("MULTIPLY", scroll, 0.35)),
                                                          op("ADD", corner, medallion)), 1.0), color, gold)
        color = hall._mix(nodes, links, op("MULTIPLY", wear, 0.35), color, (0.2, 0.12, 0.1))
        fringe = op("LESS_THAN", to_end, 2.6)
        threads = op("LESS_THAN", op("FRACT", op("DIVIDE", v, 1.6)), 0.55)
        color = hall._mix(nodes, links, fringe, color, (0.5, 0.42, 0.3))
        roughness, normal = 0.95, None
        if RP.TEXTURES is not None and RP.TEXTURES.available():
            pile = RP.TEXTURES.sample(nodes, links, "dirty_carpet", repeat=40.0)
            fibres = hall._grade(nodes, links, pile["diff"], 2.6, (1.0, 1.0, 1.0), saturation=0.0)
            color = hall._mix(nodes, links, 0.55, color, hall._mix(nodes, links, 1.0, color, fibres,
                                                                    blend="MULTIPLY"))
            roughness, normal = pile["rough"], pile["normal"]
        shader = hall._principled(nodes, links, color, roughness=roughness, normal=normal)
        hall._alpha_cut(nodes, links, shader, op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0,
                                                                                            threads))))
    return hall._material(name, build)


def mud_print():
    """A muddy boot print, UVs 0..1 with v toward the toe: a broad sole and a
    heel, tread in the mud, its edge thinning into the stone."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)

        def ellipse(cu, cv, ru, rv):
            du = op("DIVIDE", op("SUBTRACT", u, cu), ru)
            dv = op("DIVIDE", op("SUBTRACT", v, cv), rv)
            return op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))

        sole = op("LESS_THAN", ellipse(0.5, 0.66, 0.38, 0.33), 1.0)
        heel = op("LESS_THAN", ellipse(0.5, 0.15, 0.3, 0.14), 1.0)
        grain = hall._noise(nodes, links, coords.outputs["UV"], scale=9.0, detail=4.0)
        tread = op("LESS_THAN", op("FRACT", op("MULTIPLY", v, 9.0)), 0.6)
        keep = op("MULTIPLY", op("MAXIMUM", sole, heel), op("GREATER_THAN", grain, 0.3))
        keep = op("MULTIPLY", keep, op("ADD", 0.55, op("MULTIPLY", tread, 0.35)))
        shader = hall._principled(nodes, links, hall._mix(nodes, links, grain, (0.025, 0.017, 0.01),
                                                          (0.06, 0.042, 0.025)), roughness=0.9)
        hall._alpha_cut(nodes, links, shader, keep)
    return hall._material("DiningMudPrint", build)


def splash(name, color, gloss=0.06):
    """A spill: an irregular glossy pool, droplets round it, thinning at the
    rim. UVs 0..1 across."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        du = op("MULTIPLY", op("SUBTRACT", u, 0.5), 2.0)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.5), 2.0)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        wobble = hall._noise(nodes, links, coords.outputs["UV"], scale=3.0, detail=4.0)
        pool = op("LESS_THAN", op("ADD", radius, op("MULTIPLY", op("SUBTRACT", wobble, 0.5), 0.9)), 0.55)
        drops = op("MULTIPLY", op("LESS_THAN", hall._noise(nodes, links, coords.outputs["UV"], scale=13.0,
                                                           detail=2.0), 0.28), op("LESS_THAN", radius, 0.95))
        shader = hall._principled(nodes, links, color, roughness=gloss)
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", op("MAXIMUM", pool, drops), 0.92))
    return hall._material(name, build)


def clock_face():
    """The longcase clock's dial: cream enamel, a black chapter ring of hour
    strokes, and both hands at midnight, the minute hand bent off true."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        du, dv = op("SUBTRACT", u, 0.5), op("SUBTRACT", v, 0.5)
        radius = op("MULTIPLY", op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))), 2.0)
        turn = op("DIVIDE", op("ADD", op("ARCTAN2", du, dv), math.pi), 2.0 * math.pi)
        ring = op("MAXIMUM", op.between(radius, 0.9, 0.94), op.between(radius, 0.62, 0.65))
        hours = op("MULTIPLY", op.between(radius, 0.68, 0.86),
                   op("LESS_THAN", op("FRACT", op("ADD", op("MULTIPLY", turn, 12.0), 0.04)), 0.08))
        minutes = op("MULTIPLY", op.between(radius, 0.87, 0.9),
                     op("LESS_THAN", op("FRACT", op("ADD", op("MULTIPLY", turn, 60.0), 0.15)), 0.3))
        # Both hands up at twelve: the hour hand short and broad, the minute
        # hand long, kinked a little toward one past.
        hour = op("MULTIPLY", op.between(dv, -0.03, 0.26), op("LESS_THAN", op("ABSOLUTE", du), 0.035))
        bent = op("ADD", du, op("MULTIPLY", op("MAXIMUM", op("SUBTRACT", dv, 0.2), 0.0), -0.18))
        minute = op("MULTIPLY", op.between(dv, -0.05, 0.4), op("LESS_THAN", op("ABSOLUTE", bent), 0.016))
        marks = op("MINIMUM", op("ADD", op("ADD", ring, hours), minutes), 1.0)
        color = hall._mix(nodes, links, op("MULTIPLY", radius, 0.6), (0.54, 0.49, 0.37), (0.42, 0.37, 0.27))
        color = hall._mix(nodes, links, marks, color, (0.05, 0.04, 0.035))
        color = hall._mix(nodes, links, op("MAXIMUM", hour, minute), color, (0.02, 0.015, 0.012))
        color = hall._mix(nodes, links, op("LESS_THAN", radius, 0.06), color, (0.5, 0.36, 0.15))
        hall._principled(nodes, links, color, roughness=0.3)
    return hall._material("DiningClockFace", build)


def charred():
    """A burning log: black char, its underside glowing where the embers heat
    it and cracks glowing in its hot stretches. Object space is metres, so
    the cracks are a few cm across: big enough to read at 1 px a cm."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        cracks = nodes.new("ShaderNodeTexVoronoi")
        cracks.feature = "DISTANCE_TO_EDGE"
        cracks.inputs["Scale"].default_value = 14.0
        links.new(coords.outputs["Object"], cracks.inputs["Vector"])
        split = hall._ramp(nodes, links, cracks.outputs["Distance"], 0.07, 0.0)
        heat = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=5.0, detail=3.0),
                          0.55, 0.7)
        geometry = nodes.new("ShaderNodeNewGeometry")
        normal = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geometry.outputs["Normal"], normal.inputs["Vector"])
        below = hall._ramp(nodes, links, normal.outputs["Z"], 0.1, -0.6)
        char = hall._mix(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=40.0, detail=5.0),
                         (0.006, 0.005, 0.004), (0.022, 0.016, 0.012))
        hall._principled(nodes, links, char, roughness=0.85, emission=(1.0, 0.24, 0.04),
                         emission_strength=op("ADD", op("MULTIPLY", op("MULTIPLY", split, heat), 0.9),
                                              op("MULTIPLY", below, 1.6)))
    return hall._material("DiningCharredLog", build)


def embers(centre, radii):
    """The fire's bed: lumpy coals two or three cm across (object space is
    metres), each glowing at its own heat between dark seams, deep red to
    orange as the painted fire's are, ash where it has burnt out, and dying
    away to ash at the edge of the bed (an ellipse of `radii` m round
    `centre`)."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        seams = nodes.new("ShaderNodeTexVoronoi")
        seams.feature = "DISTANCE_TO_EDGE"
        cells = nodes.new("ShaderNodeTexVoronoi")
        for voronoi in (seams, cells):
            voronoi.inputs["Scale"].default_value = 38.0
            links.new(coords.outputs["Object"], voronoi.inputs["Vector"])
        inside = hall._ramp(nodes, links, seams.outputs["Distance"], 0.03, 0.2)
        heat = hall._ramp(nodes, links, cells.outputs["Color"], 0.3, 0.95)
        patches = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=8.0,
                                                       detail=3.0), 0.3, 0.55)
        offset = nodes.new("ShaderNodeVectorMath")
        offset.operation = "SUBTRACT"
        links.new(coords.outputs["Object"], offset.inputs[0])
        offset.inputs[1].default_value = tuple(centre)
        squash = nodes.new("ShaderNodeVectorMath")
        squash.operation = "MULTIPLY"
        links.new(offset.outputs["Vector"], squash.inputs[0])
        squash.inputs[1].default_value = (1.0 / radii[0], 1.0 / radii[1], 0.0)
        reach = nodes.new("ShaderNodeVectorMath")
        reach.operation = "LENGTH"
        links.new(squash.outputs["Vector"], reach.inputs[0])
        middle = hall._ramp(nodes, links, reach.outputs["Value"], 1.0, 0.7)
        ash = hall._mix(nodes, links, patches, (0.03, 0.025, 0.022), (0.012, 0.008, 0.006))
        hall._principled(nodes, links, ash, roughness=0.95,
                         normal=hall._bump(nodes, links, seams.outputs["Distance"], 0.5, distance=0.012),
                         emission=hall._mix(nodes, links, heat, (0.9, 0.1, 0.015), (1.0, 0.38, 0.07)),
                         emission_strength=op("MULTIPLY", op("MULTIPLY", inside, heat),
                                              op("MULTIPLY", op("MULTIPLY", patches, middle), 3.6)))
    return hall._material("DiningEmbers", build)


def soot():
    """The firebox's floor under the embers, blackened."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=6.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, (0.012, 0.01, 0.01), (0.04, 0.034, 0.03)),
                         roughness=0.95)
    return hall._material("DiningSoot", build)


def fire_stone():
    """The firebox's back and sides: the hearth's stone, smoked dark, which
    the fire lights orange as the painting's does."""
    return gh.laid_photo("DiningFireStone", "seaside_rock", 0.7, 0.5, (0.78, 0.6, 0.48), saturation=0.4,
                         variety=0.1, wear=0.2, ao=0.25)


def joints():
    """The floor between the flagstones: dark grout and dust."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        crumbs = hall._noise(nodes, links, coords.outputs["Object"], scale=150.0, detail=6.0)
        hall._principled(nodes, links, hall._mix(nodes, links, crumbs, (0.03, 0.027, 0.025),
                                                 (0.06, 0.054, 0.05)), roughness=0.95)
    return hall._material("DiningJoints", build)


# ---------------------------------------------------------------- the shell


class DiningShell:
    """RP.Shell with the door's gap left in its south wall; built by wrapping
    a Shell so the shared class stays as it is."""

    def __init__(self, spec, materials):
        self.shell = RP.Shell(spec, materials)
        self.shell._south_wall = self._south_wall

    def build(self):
        return self.shell.build()

    def _south_wall(self):
        shell = self.shell
        south = shell.spec["south"]
        y0, y1, top = south["y"], south["y"] + south["depth"], south["height"]
        kit = RP.Kit("RoomSouth")
        for stretch, (west, east) in (("West", ("left", PARAPET_X[0])), ("East", (PARAPET_X[1], "right"))):
            def x_at(end, y, h):
                return shell.side_x(end, y, h) if isinstance(end, str) else end
            for part, (front, back), (low, high), material in (
                    ("Wall", (y0, y1), (0.0, top - 5.0), shell.materials["wall"]),
                    ("Cap", (y0 - 1.0, y1 + 1.5), (top - 5.0, top), shell.materials["cap"]),
                    ("Lip", (y0 - 1.5, y0 + 2.5), (top, top + 0.8), shell.materials["lip"])):
                shape = bmesh.new()
                corners = {}
                for y in (front, back):
                    for h in (low, high):
                        corners[(y, h, "w")] = shape.verts.new((x_at(west, y, h), y, h))
                        corners[(y, h, "e")] = shape.verts.new((x_at(east, y, h), y, h))
                for quad in (((front, low, "w"), (front, low, "e"), (front, high, "e"), (front, high, "w")),
                             ((back, low, "w"), (back, high, "w"), (back, high, "e"), (back, low, "e")),
                             ((front, high, "w"), (front, high, "e"), (back, high, "e"), (back, high, "w")),
                             ((front, low, "w"), (back, low, "w"), (back, low, "e"), (front, low, "e")),
                             ((front, low, "w"), (front, high, "w"), (back, high, "w"), (back, low, "w")),
                             ((front, low, "e"), (back, low, "e"), (back, high, "e"), (front, high, "e"))):
                    shape.faces.new([corners[key] for key in quad])
                kit.shape(stretch + part, shape, material, uv="box")
        for obj in kit.made:
            shell._keep(obj)


# ---------------------------------------------------------------- helpers


class _Turn:
    """A turn about the upright through (cx, front_y), rigid in the room's
    space. RP.Frame's axes are unit vectors in game px, where the plan's y
    is foreshortened, so a frame turned off the axes would shear what it
    carries; this one's matrix (game px to game px, as RP.Frame.matrix) is
    a true turn once in the room."""

    def __init__(self, cx, front_y, angle):
        self.origin = Vector((cx, front_y, 0.0))
        self.angle = angle

    def matrix(self, scale=1.0):
        c, s = math.cos(self.angle) * scale, math.sin(self.angle) * scale
        return Matrix(((c, s * RP.STRETCH, 0.0, self.origin.x),
                       (-s / RP.STRETCH, c, 0.0, self.origin.y),
                       (0.0, 0.0, scale, self.origin.z),
                       (0.0, 0.0, 0.0, 1.0)))


def face_on(objects, cx, front_y, out, name):
    """Objects built facing south round x 0 with their front on y 0, turned
    to face `out` (east, south: a direction in the room, not on the screen)
    with their front's middle at (cx, front_y)."""
    return RP.place_on_frame(objects, _Turn(cx, front_y, math.atan2(out[0], out[1])), 0.0, 0.0, name=name)


def made_since(before):
    return [obj for obj in bpy.data.objects if obj not in before]


def cut_rectangle(x0, x1, y0, y1, cut):
    """A plan rectangle with its corners cut at 45 degrees on screen, as the
    painting cuts the table's: eight (x, y) points, clockwise on screen."""
    return [(x0 + cut, y0), (x1 - cut, y0), (x1, y0 + cut), (x1, y1 - cut), (x1 - cut, y1), (x0 + cut, y1),
            (x0, y1 - cut), (x0, y0 + cut)]


def clip_convex(subject, clip):
    """The part of polygon `subject` inside convex polygon `clip` (Sutherland
    and Hodgman), both (x, y) lists wound the same way."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(clip, clip[1:] + clip[:1]))

    def inside(point, a, b):
        return ((b[0] - a[0]) * (point[1] - a[1]) - (b[1] - a[1]) * (point[0] - a[0])) * area >= 0.0

    def crossing(p, q, a, b):
        d1 = (q[0] - p[0], q[1] - p[1])
        d2 = (b[0] - a[0], b[1] - a[1])
        t = ((a[0] - p[0]) * d2[1] - (a[1] - p[1]) * d2[0]) / (d1[0] * d2[1] - d1[1] * d2[0])
        return (p[0] + d1[0] * t, p[1] + d1[1] * t)

    points = list(subject)
    for a, b in zip(clip, clip[1:] + clip[:1]):
        source, points = points, []
        for index, current in enumerate(source):
            previous = source[index - 1]
            if inside(current, a, b):
                if not inside(previous, a, b):
                    points.append(crossing(previous, current, a, b))
                points.append(current)
            elif inside(previous, a, b):
                points.append(crossing(previous, current, a, b))
    return points


def floor_prism(shape, outline, h0, h1):
    """A plan (x, y) outline stood from height h0 to h1, into a bmesh."""
    low = [shape.verts.new((x, y, h0)) for x, y in outline]
    high = [shape.verts.new((x, y, h1)) for x, y in outline]
    shape.faces.new(high)
    shape.faces.new(list(reversed(low)))
    for index in range(len(outline)):
        following = (index + 1) % len(outline)
        shape.faces.new((low[index], low[following], high[following], high[index]))


def pewter_dark():
    """The worn well of a pewter plate, duller than its rim."""
    return hall._prop_metal("DiningPewterWell", (0.26, 0.25, 0.24), 0.45)


def plate(kit, part, x, y, h, radius, material, rim=0.2):
    """A plate lying flat, true round, its rim raised."""
    r = radius
    return kit.lathe(part, x, y, [(0.0, h), (r * 0.62, h), (r * 0.72, h + 0.5), (r, h + 1.3), (r * 0.97, h + 1.6),
                                  (r * 0.82, h + 0.9), (r * 0.62, h + 0.55), (0.0, h + 0.55)], material,
                     plan=ROUND, segments=32)


def goblet_glass(kit, part, x, y, h, size=1.0, wine=0.5, fallen=False):
    """A wine glass, true round: foot, stem, bowl, with wine in it."""
    s = size
    glass = wake.jar_glass()
    profile = [(0.0, h), (3.2 * s, h), (3.2 * s, h + 0.5), (0.6 * s, h + 1.4), (0.5 * s, h + 6.0),
               (1.6 * s, h + 7.4), (3.2 * s, h + 10.0), (3.0 * s, h + 13.5)]
    objects = [kit.lathe(part, x, y, profile, glass, plan=ROUND, segments=24, close=False)]
    objects[0].visible_shadow = False
    metal = silver()
    objects.append(kit.ring(part + "Rim", (x, y, h + 13.5), (0.0, 0.0, 1.0), 3.0 * s, 0.32 * s, metal, segments=24,
                            sides=6))
    objects.append(kit.lathe(part + "Foot", x, y, [(0.0, h), (3.3 * s, h), (3.3 * s, h + 0.6), (0.7 * s, h + 1.5),
                                                    (0.0, h + 1.5)], metal, plan=ROUND, segments=20))
    if wine > 0.0:
        top = h + 7.4 + wine * 4.5 * s
        objects.append(kit.lathe(part + "Wine", x, y, [(0.0, h + 7.0), (1.4 * s, h + 7.4), (2.6 * s, h + 9.2),
                                                       (2.8 * s, top), (0.0, top)], wine_material(), plan=ROUND,
                                 segments=20))
    if fallen:
        pivot = RP.world(x, y, h)
        turn = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(88.0), 4, "Y") @ Matrix.Translation(-pivot)
        for obj in objects:
            obj.matrix_world = turn @ obj.matrix_world
    return objects


def cutlery(kit, part, x, y, h, length, kind, turn=0.0):
    """A knife, fork or spoon lying flat, pointing north, turned `turn`."""
    metal = silver()
    handle = length * 0.58
    gh.turned_box(kit, part + "Handle", x, y + length * 0.21, h, h + 0.5, 1.1, handle, turn, metal, bevel=0.2)
    head_y = y - length * 0.29
    if kind == "knife":
        gh.turned_box(kit, part + "Blade", x, head_y, h, h + 0.35, 1.5, length * 0.42, turn, metal, bevel=0.1)
    elif kind == "fork":
        for prong in (-0.8, 0.0, 0.8):
            gh.turned_box(kit, part + "Tine", x + prong * math.cos(turn), head_y + prong * math.sin(turn), h,
                          h + 0.4, 0.4, length * 0.3, turn, metal, bevel=0.0)
    else:
        kit.ball(part + "Bowl", x, head_y, h + 0.4, 1.6, metal, plan=0.9, squash=0.35)


def candlestick(kit, part, x, y, h, tall=1.0, power=2.6):
    """A brass candlestick with a lit taper, its height `tall` times a
    table candlestick's."""
    wake.candlestick(kit, part, x, y, h, wax_height=14.0 * tall, radius=2.8, power=power, stick=19.0 * tall)


# ---------------------------------------------------------------- the north wall


def windows():
    """Each window's leaded glass, tracery (a mullion parting two lights
    under an oculus), stone sill, and the moon behind it."""
    kit = RP.Kit("Windows")
    stone = ashlar()
    for index, (x0, x1) in enumerate(WINDOWS):
        cx = (x0 + x1) / 2.0
        glass = RP.polygon_mesh("DiningWindowGlass%d" % index, window_outline(x0, x1), [],
                                lambda u, v: (u, WINDOW_GLASS_Y, v), night_glass("DiningNightGlass%d" % index, x0, x1),
                                uv_of=lambda u, v: (u, v))
        glass.visible_shadow = False
        kit.keep(glass)
        back, front = WINDOW_GLASS_Y - 3.0, WINDOW_GLASS_Y + 4.0
        gh.band(kit, "Mullion%d" % index, [(cx, WINDOW_SILL), (cx, 160.0)], 5.0, back, front, stone)
        for side, (a, b) in (("W", (x0 + 2.0, cx)), ("E", (cx, x1 - 2.0))):
            head = gh.pointed_arch(a, b, 140.0, 168.0, steps=10)
            gh.band(kit, "Light%s%d" % (side, index), [(a, WINDOW_SILL)] + head + [(b, WINDOW_SILL)], 3.6, back, front,
                    stone)
        gh.band(kit, "Oculus%d" % index, gh.circle_points(cx, 181.0, 9.0, steps=28), 3.0, back, front, stone,
                closed=True)
        kit.box("Sill%d" % index, x0 - 8.0, x1 + 8.0, BACK_Y - 4.0, BACK_Y + 7.0, WINDOW_SILL - 6.0, WINDOW_SILL,
                stone, bevel=0.9, uv="box")
        hood = gh.pointed_arch(x0 - 7.0, x1 + 7.0, WINDOW_SPRING, WINDOW_APEX + 10.0, steps=16)
        gh.band(kit, "Hood%d" % index, [(x0 - 7.0, WINDOW_SPRING - 8.0)] + hood + [(x1 + 7.0, WINDOW_SPRING - 8.0)],
                5.0, BACK_Y, BACK_Y + 3.0, stone)
        direction = Vector((-0.15, -math.cos(math.radians(50.0)), -math.sin(math.radians(50.0)))).normalized()
        data = bpy.data.lights.new("DiningMoon%d" % index, "SPOT")
        data.energy = 900.0
        data.color = MOON
        data.spot_size = math.radians(22.0)
        data.spot_blend = 0.35
        data.shadow_soft_size = 0.1
        moon = RP._link(bpy.data.objects.new("DiningMoon%d" % index, data))
        moon.location = RP.world(cx, BACK_Y, 120.0) - direction * 10.0
        moon.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return kit


def curtain(kit, part, x0, x1, material, rng, folds=6):
    """A velvet drape from the rod to the floor, drawn in at its tieback and
    flaring below it, in folds that deepen where it hangs wide; it pools a
    little on the flagstones."""
    rows, columns = 40, folds * 10
    cx, width = (x0 + x1) / 2.0, x1 - x0
    phase = rng.uniform(0.0, 6.28)
    size = 100.0 * RP.ROOM_TEXTURE_SCALE
    shape = bmesh.new()
    layer = shape.loops.layers.uv.verify()
    grid = []
    for j in range(rows + 1):
        h = CURTAIN_TOP * (1.0 - j / rows)
        if h >= TIEBACK_H:
            t = (CURTAIN_TOP - h) / (CURTAIN_TOP - TIEBACK_H)
            w = width * (1.0 - 0.6 * t * t * (3.0 - 2.0 * t))
        else:
            t = (TIEBACK_H - h) / TIEBACK_H
            w = width * (0.4 + 0.48 * (t * t * (3.0 - 2.0 * t)) ** 0.8)
        depth = 2.0 + 6.5 * (w / width)
        row = []
        for i in range(columns + 1):
            u = i / columns
            fold = math.sin(2.0 * math.pi * folds * u + phase + 0.4 * math.sin(h * 0.04))
            y = BACK_Y + 8.0 + depth * 0.5 * (1.0 + fold) + 4.0 * math.sin(math.pi * u) * (w / width)
            if h < 6.0:
                y += (6.0 - h) * 1.8
            row.append((shape.verts.new((cx + (u - 0.5) * w, y, max(h, 0.4))), (u * width / size, h / size)))
        grid.append(row)
    for j in range(rows):
        for i in range(columns):
            corners = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
            face = shape.faces.new([corner[0] for corner in corners])
            for loop, corner in zip(face.loops, corners):
                loop[layer].uv = corner[1]
    obj = kit.keep(RP.mesh_from("DiningCurtain" + part, shape, material, smooth=True, sharp_angle=89.0,
                                facing=RP.TOWARD_CAMERA))
    # The tieback, a gold cord round the drawn-in waist, and its tassel.
    cord = gilt()
    waist = width * 0.4 / 2.0 + 1.5
    kit.ring(part + "Tie", (cx, BACK_Y + 13.0, TIEBACK_H), (0.0, 0.0, 1.0), waist, 1.0, cord, segments=28, sides=6)
    kit.rod(part + "Tassel", (cx + waist * 0.7, BACK_Y + 18.0, TIEBACK_H), (cx + waist * 0.8, BACK_Y + 19.0,
                                                                          TIEBACK_H - 9.0), 0.9, cord)
    kit.cylinder(part + "TasselEnd", cx + waist * 0.8, BACK_Y + 19.0, TIEBACK_H - 16.0, TIEBACK_H - 8.0, 2.0, cord,
                 tip=0.6, segments=12)
    return obj


def curtains():
    kit = RP.Kit("Curtains")
    rng = random.Random(311)
    cloth = velvet()
    brass = hall._brass()
    for index, (x0, x1) in enumerate(CURTAINS):
        curtain(kit, "%d" % index, x0, x1, cloth, rng)
    for index in range(2):
        left, right = CURTAINS[2 * index][0] - 10.0, CURTAINS[2 * index + 1][1] + 10.0
        rod_h, rod_y = CURTAIN_TOP + 3.0, BACK_Y + 12.0
        kit.rod("Rod%d" % index, (left, rod_y, rod_h), (right, rod_y, rod_h), 1.4, brass)
        for x in (left - 3.0, right + 3.0):
            kit.ball("Finial%d" % index, x, rod_y, rod_h, 2.6, brass, plan=0.8)
        for x in (left + 6.0, (left + right) / 2.0, right - 6.0):
            kit.rod("Bracket%d" % index, (x, BACK_Y, rod_h + 1.0), (x, rod_y, rod_h), 0.7, brass)
        for x0, x1 in CURTAINS[2 * index:2 * index + 2]:
            for k in range(7):
                x = x0 + 4.0 + (x1 - x0 - 8.0) * k / 6.0
                kit.ring("CurtainRing%d" % index, (x, rod_y, rod_h), (1.0, 0.0, 0.0), 2.1, 0.45, brass, segments=16,
                         sides=6)
    return kit


def portraits():
    """A portrait each side of the windows, as the painting hangs them, in
    gilt frames: a lady to the west, a gentleman to the east."""
    kit = RP.Kit("Portraits")
    frame = gilt()
    for index, (cx, coat) in enumerate(((317.0, (0.33, 0.24, 0.13)), (1128.0, (0.05, 0.05, 0.08)))):
        x0, x1, h0, h1 = cx - 25.0, cx + 25.0, 84.0, 152.0
        face = BACK_Y + 0.6
        canvas = hall.material_portrait("DiningPortrait%d" % index, coat)
        for node in canvas.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                for link in list(node.inputs["Emission Strength"].links):
                    canvas.node_tree.links.remove(link)
                node.inputs["Emission Strength"].default_value = 0.0
        kit.quad("Canvas%d" % index, [(x0, face + 1.8, h0), (x1, face + 1.8, h0), (x1, face + 1.8, h1),
                                      (x0, face + 1.8, h1)], canvas)
        bar = 5.0
        for part, (a, b, c, d) in (("Top", (x0 - bar, x1 + bar, h1, h1 + bar)),
                                   ("Bottom", (x0 - bar, x1 + bar, h0 - bar, h0)),
                                   ("Left", (x0 - bar, x0, h0, h1)), ("Right", (x1, x1 + bar, h0, h1))):
            kit.box("Frame%d%s" % (index, part), a, b, face, face + 3.2, c, d, frame, bevel=0.9)
        kit.box("FrameLip%d" % index, x0 - 1.2, x1 + 1.2, face + 0.5, face + 1.6, h0 - 1.2, h1 + 1.2, frame, bevel=0.3)
        kit.ball("FrameCrest%d" % index, cx, face + 2.0, h1 + bar + 2.0, 2.6, frame, plan=0.5)
    return kit


def sconce(kit, part, x, h, power=2.4):
    """A three-candle brass sconce on the back wall: an oval backplate, a
    scrolled arm, a bar with three drip pans and lit candles."""
    brass = hall._brass()
    face = BACK_Y + 0.5
    kit.lathe(part + "Plate", x, face + 1.0, [(0.0, h - 9.0), (3.2, h - 8.0), (4.0, h), (3.2, h + 8.0),
                                              (0.0, h + 9.0)], brass, plan=0.35, segments=20)
    out = face + 11.0
    kit.rod(part + "Arm", (x, face + 1.5, h - 2.0), (x, out, h - 6.0), 0.9, brass)
    kit.rod(part + "Bar", (x - 11.0, out, h - 6.0), (x + 11.0, out, h - 6.0), 0.8, brass)
    for dx in (-11.0, 0.0, 11.0):
        rise = 4.0 if dx == 0.0 else 0.0
        kit.rod(part + "Riser", (x + dx, out, h - 6.0), (x + dx, out, h - 2.0 + rise), 0.6, brass)
        kit.lathe(part + "Pan", x + dx, out, [(0.0, h - 2.0 + rise), (3.0, h - 2.0 + rise), (3.2, h - 0.8 + rise),
                                              (0.0, h - 0.8 + rise)], brass, plan=ROUND, segments=16)
        kit.candle(part + "Candle%d" % int(dx), x + dx, out, h - 0.8 + rise, height=8.0, radius=1.4, power=power)


def sconces():
    kit = RP.Kit("Sconces")
    for index, (x, h) in enumerate(((677.0, 116.0), (773.0, 116.0), (1330.0, 124.0))):
        sconce(kit, "Sconce%d" % index, x, h)
    return kit


# ---------------------------------------------------------------- the fireplace


def blocks_row(boxes, x0, x1, h0, h1, y0, y1, rng, widths=(26.0, 40.0)):
    """A course of stone blocks from x0 to x1, each its own box."""
    x = x0
    while x < x1 - 1.0:
        right = min(x + rng.uniform(*widths), x1)
        if x1 - right < widths[0] * 0.5:
            right = x1
        boxes.append((x + 0.5, right - 0.5, y0, y1 + rng.uniform(-0.6, 0.6), h0 + 0.5, h1 - 0.5))
        x = right


def fireplace():
    """The fireplace, as the painting draws it: a hearth slab, piers of
    dressed stone either side of a segmental arch over the firebox, a mantel
    shelf, and above it a hood tapering in dressed courses to a cornice past
    the wall's top; a red shield with a sword on the hood.
    In the firebox, logs burn on an iron grate over glowing embers."""
    kit = RP.Kit("Fireplace", prop="Fireplace")
    rng = random.Random(29)
    stone = ashlar()
    cx = FIRE_CX
    x0, x1 = FIRE_X
    back = HOOD_Y + 4.0
    kit.box("Hearth", x0 + 2.0, x1 - 2.0, HOOD_Y - 6.0, HEARTH_Y, 0.0, 5.0, stone, bevel=1.0, uv="box")
    # Piers, three courses each, bonded.
    boxes = []
    opening = (cx - 64.0, cx + 64.0)
    for course, (h0, h1) in enumerate(((5.0, 27.0), (27.0, 49.0), (49.0, 70.0))):
        shift = 8.0 if course % 2 else 0.0
        for a, b in ((x0 + 8.0, opening[0]), (opening[1], x1 - 8.0)):
            boxes.append((a + 0.5, a + 18.0 + shift - 0.5, back, FIRE_FACE_Y + rng.uniform(-0.5, 0.5), h0 + 0.5,
                          h1 - 0.5))
            boxes.append((a + 18.0 + shift + 0.5, b - 0.5, back, FIRE_FACE_Y + rng.uniform(-0.5, 0.5), h0 + 0.5,
                          h1 - 0.5))
    kit.blocks("Piers", boxes, stone, bevel=0.8, uv="box")
    # The segmental arch: nine voussoirs, the keystone proud.
    rise, half = 30.0, 64.0
    r0 = (half * half + rise * rise) / (2.0 * rise)
    centre = 70.0 + rise - r0
    r1 = r0 + 15.0
    start = math.degrees(math.atan2(70.0 - centre, half))
    for index in range(9):
        a0 = start + (180.0 - 2.0 * start) * index / 9.0 + 0.4
        a1 = start + (180.0 - 2.0 * start) * (index + 1) / 9.0 - 0.4
        key = index == 4
        gh.voussoir(kit, "Voussoir%d" % index, cx, centre, r0, r1 + (3.0 if key else 0.0), a0, a1, back,
                    FIRE_FACE_Y + (2.0 if key else 0.6), stone)
    # Spandrels up to the mantel.
    top = MANTEL_H
    for side in (-1.0, 1.0):
        arc = [(cx + r1 * math.cos(math.radians(angle)), centre + r1 * math.sin(math.radians(angle)))
               for angle in [start + (90.0 - start) * k / 10.0 for k in range(11)]]
        if side < 0:
            arc = [(2.0 * cx - x, h) for x, h in arc]
        edge = x0 + 8.0 if side < 0 else x1 - 8.0
        outline = [(edge, 70.0)] + arc + [(cx, top), (edge, top)]
        if side > 0:
            outline = list(reversed(outline))
        kit.slab("Spandrel%d" % int(side), outline, back, FIRE_FACE_Y - 0.4, stone)
    # The firebox: blackened back and sides, the hearth's floor inside.
    black, smoked = soot(), fire_stone()
    kit.box("FireBack", opening[0], opening[1], back - 2.0, back, 5.0, 100.0, smoked, bevel=0.0, uv="box")
    for x in opening:
        kit.box("FireSide", x - 1.0, x + 1.0, back, FIRE_FACE_Y - 0.5, 5.0, 72.0, smoked, bevel=0.0, uv="box")
    kit.box("FireFloor", opening[0], opening[1], back, FIRE_FACE_Y, 4.5, 5.2, black, bevel=0.0)
    fire(kit, cx, (back + FIRE_FACE_Y) / 2.0)
    # The mantel shelf on a moulded course.
    kit.box("MantelCourse", x0 + 4.0, x1 - 4.0, HOOD_Y - 2.0, FIRE_FACE_Y + 3.0, top - 1.0, top + 4.0, stone,
            bevel=1.0, uv="box")
    kit.box("Mantel", x0, x1, HOOD_Y - 4.0, FIRE_FACE_Y + 7.0, top + 4.0, top + 11.0, stone, bevel=1.2, uv="box")
    shelf = top + 11.0
    for index, x in enumerate((90.0, 102.0, 114.0)):
        candlestick(kit, "MantelCandle%d" % index, x, FIRE_FACE_Y - 6.0 - index * 2.0, shelf, tall=0.6 + 0.12 * index,
                    power=1.8)
    MODEL.group(kit, "mantel_clock_01", 232.0, FIRE_FACE_Y - 10.0, shelf, scale=0.9, depth=True)
    # The hood, as the painting draws it: one taper of dressed courses from
    # the mantel up past the wall's top, its sides slanting, under a cornice.
    hood = bmesh.new()
    bottom_half, top_half = (x1 - x0) / 2.0 - 10.0, 74.0
    h = shelf
    while h < CHIMNEY_TOP - 1.0:
        step = min(20.0, CHIMNEY_TOP - h)
        for outline in taper_course(cx, bottom_half, top_half, shelf, CHIMNEY_TOP, h, h + step, rng,
                                    widths=(30.0, 46.0)):
            prism(hood, outline, BACK_Y, HOOD_Y + rng.uniform(-0.5, 0.5))
        h += step
    kit.shape("Hood", hood, stone, bevel=0.8, uv="box")
    kit.box("Cornice", cx - top_half - 5.0, cx + top_half + 5.0, BACK_Y - 6.0, HOOD_Y + 3.0, CHIMNEY_TOP,
            CHIMNEY_TOP + 6.0, stone, bevel=1.0, uv="box")
    heraldic_shield(kit, cx, HOOD_Y + 1.0, 196.0)
    return kit


def taper_course(cx, bottom_half, top_half, h_bottom, h_top, h0, h1, rng, widths=(30.0, 46.0)):
    """A course of blocks (x, h outlines) across a taper narrowing from
    bottom_half at h_bottom to top_half at h_top: the end blocks slant with
    its sides, the joints between them stand plumb."""
    def half(level):
        return bottom_half + (top_half - bottom_half) * (level - h_bottom) / (h_top - h_bottom)
    a, b = h0 + 0.5, h1 - 0.5
    left_low, left_high = cx - half(a), cx - half(b)
    right_low, right_high = cx + half(a), cx + half(b)
    cuts = []
    x = left_high + rng.uniform(widths[0] * 0.5, widths[1] * 0.8)
    while x < right_high - widths[0] * 0.6:
        cuts.append(x)
        x += rng.uniform(*widths)
    outlines = []
    edges = [None] + cuts + [None]
    for left, right in zip(edges[:-1], edges[1:]):
        lo = [(left_low, a)] if left is None else [(left + 0.5, a)]
        hi = [(left_high, b)] if left is None else [(left + 0.5, b)]
        ro = [(right_low, a)] if right is None else [(right - 0.5, a)]
        ri = [(right_high, b)] if right is None else [(right - 0.5, b)]
        outlines.append(lo + ro + ri + hi)
    return outlines


def prism(shape, outline, y0, y1):
    """An (x, h) outline run back from plan y1 (its face) to y0, into a bmesh."""
    front = [shape.verts.new((u, y1, v)) for u, v in outline]
    back = [shape.verts.new((u, y0, v)) for u, v in outline]
    shape.faces.new(front)
    shape.faces.new(list(reversed(back)))
    for index in range(len(outline)):
        following = (index + 1) % len(outline)
        shape.faces.new((back[index], back[following], front[following], front[index]))


def fire(kit, cx, cy):
    """Logs burning on an iron grate over embers, flames licking up them."""
    metal = hall._cast_iron()
    for x in (cx - 42.0, cx + 42.0):
        kit.box("Firedog", x - 2.0, x + 2.0, cy - 14.0, cy + 14.0, 5.0, 10.0, metal, bevel=0.4)
        kit.rod("FiredogPost", (x, cy + 12.0, 5.0), (x, cy + 12.0, 22.0), 1.4, metal)
        kit.ball("FiredogKnob", x, cy + 12.0, 23.0, 2.2, metal, plan=0.8)
    for k in range(6):
        y = cy - 12.0 + k * 5.0
        kit.rod("GrateBar", (cx - 44.0, y, 10.0), (cx + 44.0, y, 10.0), 0.9, metal)
    # The ember bed fills the firebox's floor, heaped under the logs.
    bed = embers(RP.world(cx, cy, 0.0), (60.0 * RP.PX, 60.0 * 0.3 * RP.PX * RP.STRETCH))
    kit.lathe("Embers", cx, cy, [(0.0, 12.5), (50.0, 8.5), (60.0, 5.3)], bed, plan=0.3, segments=48, close=False)
    burning = charred()
    for index, ((ax, ay, ah), (bx, by, bh), radius) in enumerate((
            ((cx - 40.0, cy + 4.0, 13.0), (cx + 36.0, cy - 2.0, 15.0), 5.4),
            ((cx - 30.0, cy - 8.0, 16.0), (cx + 28.0, cy + 6.0, 21.0), 4.6),
            ((cx - 18.0, cy + 10.0, 21.0), (cx + 20.0, cy - 6.0, 27.0), 4.0))):
        kit.rod("Log%d" % index, (ax, ay, ah), (bx, by, bh), radius, burning, segments=14)
    # Low, broad licks of flame along the logs, deep orange to their cores,
    # as the painted fire's are: no tall white candle tongues.
    rng = random.Random(7)
    outer = hall._glow_material("DiningFireTongue", (1.0, 0.2, 0.03), 0.6, (0.02, 0.004, 0.0))
    core = hall._glow_material("DiningFireCore", (1.0, 0.32, 0.05), 0.9, (0.02, 0.006, 0.0))
    for k in range(9):
        x = cx - 40.0 + k * 10.0 + rng.uniform(-3.0, 3.0)
        y = cy + rng.uniform(-4.0, 6.0)
        h = 11.0 + rng.uniform(0.0, 6.0) - abs(x - cx) * 0.05
        s = rng.uniform(2.2, 3.2) * (1.0 - abs(x - cx) / 110.0)
        for part, material, scale in (("Tongue", outer, 1.0), ("TongueCore", core, 0.55)):
            obj = kit.lathe("Fire%s%d" % (part, k), x, y + (0.3 if scale < 1.0 else 0.0), [
                (0.0, h), (1.6 * s * scale, h + 0.7 * s), (1.8 * s * scale, h + 1.8 * s * scale),
                (1.1 * s * scale, h + 3.4 * s * scale), (0.4 * s * scale, h + 4.8 * s * scale),
                (0.0, h + 5.6 * s * scale)], material, plan=ROUND, segments=12)
            obj.visible_shadow = False
    # The embers light the firebox from within: its back, sides and arch.
    kit.light("FireGlow", cx, cy + 10.0, 16.0, (1.0, 0.36, 0.09), 26.0, radius=0.3, mirrored=False)
    light = kit.light("FireLight", cx, FIRE_FACE_Y - 3.0, 26.0, (1.0, 0.42, 0.14), 36.0, radius=0.2, kind="SPOT")
    light.data.spot_size = math.radians(150.0)
    light.data.spot_blend = 0.8
    light.rotation_euler = Vector((0.0, -math.cos(math.radians(18.0)), -math.sin(math.radians(18.0)))).to_track_quat(
        "-Z", "Y").to_euler()
    RP.glow("lantern", cx, cy, 24.0, FIRE, 64.0)


def heraldic_shield(kit, cx, y, ch):
    """A red heater shield with a gilt rim and a sword point down, on the
    hood, as the painting hangs it."""
    width, top, waist, point = 16.0, 18.0, 1.0, -22.0
    outline = [(-width + 2.0 * width * index / 10.0, top + 2.6 * math.sin(math.pi * index / 10.0))
               for index in range(11)]
    outline.append((width, waist))
    outline += [(width * math.cos(t * math.pi / 2.0), waist - (waist - point) * math.sin(t * math.pi / 2.0))
                for t in (index / 10.0 for index in range(1, 11))]
    outline += [(-width * math.cos(t * math.pi / 2.0), waist - (waist - point) * math.sin(t * math.pi / 2.0))
                for t in (index / 10.0 for index in range(9, -1, -1))]
    placed = [(cx + px, ch + pz) for px, pz in outline]
    enamel = hall._painted("DiningShieldField", (0.32, 0.03, 0.04))
    kit.slab("ShieldField", placed, y, y + 1.8, enamel)
    gh.band(kit, "ShieldRim", placed, 2.0, y + 1.0, y + 2.8, gilt(), closed=True)
    blade = [(cx - 1.2, ch + 11.0), (cx + 1.2, ch + 11.0), (cx + 1.2, ch - 12.0), (cx, ch - 16.0),
             (cx - 1.2, ch - 12.0)]
    kit.slab("ShieldBlade", blade, y + 1.8, y + 2.6, silver())
    kit.slab("ShieldGuard", [(cx - 7.0, ch + 9.0), (cx + 7.0, ch + 9.0), (cx + 7.0, ch + 11.0),
                             (cx - 7.0, ch + 11.0)], y + 1.8, y + 3.0, gilt())
    kit.slab("ShieldGrip", [(cx - 1.0, ch + 11.0), (cx + 1.0, ch + 11.0), (cx + 1.0, ch + 16.0),
                            (cx - 1.0, ch + 16.0)], y + 1.8, y + 2.8, hall._cloth("DiningGrip", (0.12, 0.05, 0.03)))
    kit.ball("ShieldPommel", cx, y + 2.6, ch + 17.0, 1.6, gilt(), plan=0.6)


def hearthside():
    """Beside the fireplace: a stack of split logs and an iron stand of fire
    tools, as the painting leans them against the wall."""
    kit = RP.Kit("Hearthside")
    bark = hall._material("DiningBark", lambda nodes, links: _bark_shader(nodes, links))
    rng = random.Random(41)
    x0, y0 = 296.0, 330.0
    for row, count in enumerate((3, 2, 1)):
        for k in range(count):
            x = x0 + k * 11.0 + row * 5.5
            h = 4.6 + row * 8.4
            kit.rod("Log%d_%d" % (row, k), (x, y0 - 18.0 + rng.uniform(-2.0, 2.0), h),
                    (x + rng.uniform(-1.5, 1.5), y0 + 14.0, h), 4.4, bark, segments=12)
    metal = hall._cast_iron()
    sx, sy = 336.0, 290.0
    kit.lathe("ToolBase", sx, sy, [(0.0, 0.0), (6.0, 0.0), (6.4, 1.2), (1.4, 2.4), (0.0, 2.4)], metal, plan=ROUND)
    kit.rod("ToolPost", (sx, sy, 2.0), (sx, sy, 46.0), 0.9, metal)
    kit.rod("ToolBar", (sx - 6.0, sy, 44.0), (sx + 6.0, sy, 44.0), 0.7, metal)
    for k, (dx, kind) in enumerate(((-5.0, "poker"), (0.0, "shovel"), (5.0, "tongs"))):
        kit.rod("Tool%d" % k, (sx + dx, sy + 1.0, 43.0), (sx + dx * 1.3, sy + 3.0, 6.0), 0.55, metal)
        if kind == "shovel":
            kit.box("ShovelBlade", sx - 3.0, sx + 3.0, sy + 2.5, sy + 3.5, 3.0, 9.0, metal, bevel=0.3)
        kit.ball("ToolHandle%d" % k, sx + dx, sy + 1.0, 44.5, 1.3, gilt(), plan=0.8)
    return kit


def _bark_shader(nodes, links):
    coords = nodes.new("ShaderNodeTexCoord")
    ridges = nodes.new("ShaderNodeTexWave")
    ridges.inputs["Scale"].default_value = 60.0
    ridges.inputs["Distortion"].default_value = 9.0
    links.new(coords.outputs["Object"], ridges.inputs["Vector"])
    color = hall._mix(nodes, links, ridges.outputs["Fac"], (0.04, 0.026, 0.016), (0.13, 0.085, 0.05))
    hall._principled(nodes, links, color, roughness=0.85,
                     normal=hall._bump(nodes, links, ridges.outputs["Fac"], 0.5, distance=0.006))


# ---------------------------------------------------------------- the north-east


def wall_door():
    """The barred wall door, as the painting draws it: big dressed blocks
    round a deep-set door of five boards with iron strap hinges and a lock
    plate, on a stone step."""
    kit = RP.Kit("WallDoor", prop="WallDoor")
    stone = ashlar()
    x0, x1 = WALL_DOOR
    face = WALL_DOOR_FACE
    rng = random.Random(53)
    boxes = []
    for course, (h0, h1) in enumerate(((0.0, 30.0), (30.0, 58.0), (58.0, 86.0), (86.0, 114.0))):
        shift = 3.0 if course % 2 else 0.0
        boxes.append((x0 + 0.5, x0 + 20.0 + shift, BACK_Y, face + rng.uniform(-0.5, 0.5), h0 + 0.5, h1 - 0.5))
        boxes.append((x1 - 20.0 - shift, x1 - 0.5, BACK_Y, face + rng.uniform(-0.5, 0.5), h0 + 0.5, h1 - 0.5))
    for a, b in ((x0 - 4.0, x0 + 38.0), (x0 + 38.0, x1 - 38.0), (x1 - 38.0, x1 + 4.0)):
        boxes.append((a + 0.5, b - 0.5, BACK_Y, face + 1.0, 114.5, 134.0))
    kit.blocks("Surround", boxes, stone, bevel=1.0, uv="box")
    door_x0, door_x1 = x0 + 21.0, x1 - 21.0
    door_face = face - 7.0
    boards = []
    for k in range(5):
        a = door_x0 + (door_x1 - door_x0) * k / 5.0
        b = door_x0 + (door_x1 - door_x0) * (k + 1) / 5.0
        boards.append((a + 0.25, b - 0.25, door_face - 3.0, door_face + rng.uniform(-0.3, 0.3), 2.0, 114.0))
    gh.wood_boxes(kit, "Boards", boards, planks(), grain="h", photo_grain="v", bevel=0.3)
    metal = hall._cast_iron()
    for h in (24.0, 92.0):
        kit.box("Strap%d" % int(h), door_x0 + 26.0, door_x1, door_face, door_face + 1.0, h - 2.2, h + 2.2, metal,
                bevel=0.3)
        kit.ball("StrapEnd%d" % int(h), door_x0 + 26.0, door_face + 0.6, h, 3.0, metal, plan=0.35)
        for along in (8.0, 20.0, 32.0, 44.0):
            kit.ball("StrapRivet", door_x1 - along, door_face + 1.1, h, 0.75, metal, plan=0.8)
    kit.box("LockPlate", door_x0 + 6.0, door_x0 + 14.0, door_face, door_face + 1.0, 50.0, 64.0, metal, bevel=0.3)
    kit.box("Keyhole", door_x0 + 9.4, door_x0 + 10.6, door_face + 0.9, door_face + 1.2, 53.0, 58.0,
            hall._bakelite(), bevel=0.0)
    kit.ring("Latch", (door_x0 + 10.0, door_face + 1.6, 47.0), (0.0, 1.0, 0.0), 2.6, 0.5, metal, segments=20,
             sides=6)
    kit.box("Step", x0 + 14.0, x1 - 14.0, door_face - 4.0, face + 5.0, 0.0, 2.6, stone, bevel=0.8, uv="box")
    return kit


def serving_table():
    """The serving cabinet in the north-east corner, as the painting draws
    it, against the wall at a real cabinet's depth and height: a drawer
    under its top, turned feet; a lit candlestick, a glass carafe, a stack
    of plates and a bowl on it."""
    kit = RP.Kit("ServingTable")
    wood = walnut()
    x0, x1, y0, y1 = SERVING
    top = 52.0
    lift = top - 46.0
    gh.wood_boxes(kit, "Body", [(x0 + 3.0, x1 - 3.0, y0 + 2.0, y1 - 3.0, 9.0, top - 5.0)], wood, grain="x")
    gh.wood_boxes(kit, "Top", [(x0, x1, y0, y1, top - 5.0, top)], wood, grain="x", bevel=1.0)
    gh.wood_boxes(kit, "Apron", [(x0 + 1.0, x1 - 1.0, y1 - 4.0, y1 - 2.0, 6.0, 10.0)], wood, grain="x")
    for x in (x0 + 5.0, x1 - 5.0):
        kit.lathe("Foot", x, y1 - 6.0, [(0.0, 0.0), (3.4, 0.0), (2.4, 3.0), (3.6, 6.0), (2.6, 9.0), (0.0, 9.0)], wood,
                  plan=ROUND, segments=14)
    gh.wood_boxes(kit, "Drawer", [(x0 + 10.0, x1 - 10.0, y1 - 3.6, y1 - 1.8, 18.0 + lift, 36.0 + lift)], wood,
                  grain="x", bevel=0.4)
    kit.box("DrawerPull", (x0 + x1) / 2.0 - 5.0, (x0 + x1) / 2.0 + 5.0, y1 - 2.0, y1 - 0.4, 26.0 + lift, 28.5 + lift,
            hall._brass(), bevel=0.4)
    candlestick(kit, "Candle", 1318.0, 270.0, top, tall=1.0, power=2.4)
    glass = wake.jar_glass()
    carafe = kit.lathe("Carafe", 1336.0, 262.0, [(0.0, top), (6.0, top), (7.0, top + 6.0), (5.4, top + 12.0),
                                                  (2.6, top + 16.0), (2.4, top + 22.0), (3.0, top + 23.0)], glass,
                       plan=ROUND, segments=24, close=False)
    carafe.visible_shadow = False
    metal = pewter()
    for k in range(4):
        plate(kit, "Plate%d" % k, 1362.0, 270.0, top + k * 1.8, 14.0, metal)
    bowl(kit, "Bowl", 1338.0, 284.0, top, 9.0, metal)
    return kit


def jug(kit, part, x, y, h, material, size=1.0):
    """A jug, true round, a lip and a looped handle."""
    s = size
    kit.lathe(part, x, y, [(0.0, h), (4.6 * s, h), (5.4 * s, h + 3.0 * s), (5.6 * s, h + 7.0 * s),
                           (4.0 * s, h + 11.0 * s), (3.0 * s, h + 13.0 * s), (3.4 * s, h + 15.0 * s),
                           (3.0 * s, h + 15.4 * s)], material, plan=ROUND, segments=28, close=False)
    kit.ring(part + "Handle", (x + 5.4 * s, y, h + 9.0 * s), (0.0, 1.0, 0.0), 3.2 * s, 0.7 * s, material,
             segments=20, sides=6)


# ---------------------------------------------------------------- the banquet


def on_table(x, y):
    """A point laid out on the painted table, on the real one: the places at
    the same reach in from its edges as the painting sets them on its own,
    the candles and the wine kept down the middle."""
    px0, px1 = PAINTED_TABLE[:2]
    x0, x1, y0, y1 = TABLE
    # The painting sets its end places at x 482 and 900 and its rows at y 496
    # and 640: here the ends are 25 px in, the rows 21 plan px in, so each
    # plate clears the frame round the boards.
    kx = ((x1 - x0) / 2.0 - 25.0) / ((px0 + px1) / 2.0 - 482.0)
    ky = ((y1 - y0) / 2.0 - 21.0) / (568.0 - 496.0)
    return ((x0 + x1) / 2.0 + (x - (px0 + px1) / 2.0) * kx, (y0 + y1) / 2.0 + (y - 568.0) * ky)


def on_sideboard(x, y):
    """A point laid out on the painted sideboard, on the real one: its top and
    its raised back shelf each drawn in to their own depth, its length to
    the real length, what stands on the shelf down its middle."""
    px0, px1, py0, py1 = PAINTED_SIDEBOARD
    x0, x1, y0, y1 = SIDEBOARD
    if x < PAINTED_GALLERY_X:
        x = x0 + (x - px0) * (GALLERY_X - x0) / (PAINTED_GALLERY_X - px0)
    else:
        x = (GALLERY_X + x1 + 3.0) / 2.0
    return x, (y0 + y1) / 2.0 + (y - (py0 + py1) / 2.0) * (y1 - y0) / (py1 - py0)


def table():
    """The banquet table, as the painting draws it: a top of six boards
    running its length inside a moulded frame with its corners cut, an
    apron and six square legs, laid for eight with pewter, gilt candlesticks
    burning down its middle, a decanter knocked over and its wine spilt, a
    glass fallen at the west end, a napkin dropped and a spoon left where it
    fell."""
    kit = RP.Kit("DiningTable", prop="DiningTable")
    wood = oak()
    x0, x1, y0, y1 = TABLE
    top = TABLE_TOP
    rim = 10.0
    outer = cut_rectangle(x0, x1, y0, y1, 18.0)
    inner = cut_rectangle(x0 + rim, x1 - rim, y0 + rim, y1 - rim, 12.0)
    frame = bmesh.new()
    for index in range(8):
        following = (index + 1) % 8
        floor_prism(frame, [outer[index], outer[following], inner[following], inner[index]], top - 6.0, top + 0.7)
    kit.shape("Frame", frame, walnut(), bevel=0.6, uv="box")
    boards = bmesh.new()
    count = 6
    for k in range(count):
        b0 = y0 + rim + (y1 - y0 - 2.0 * rim) * k / count + 0.3
        b1 = y0 + rim + (y1 - y0 - 2.0 * rim) * (k + 1) / count - 0.3
        floor_prism(boards, clip_convex([(x0, b0), (x1, b0), (x1, b1), (x0, b1)], inner), top - 4.5, top)
    kit.shape("Boards", boards, wood, bevel=0.25, uv="box")
    gh.wood_boxes(kit, "Apron", [(x0 + 14.0, x1 - 14.0, y0 + 14.0, y0 + 19.0, top - 14.0, top - 6.0),
                                 (x0 + 14.0, x1 - 14.0, y1 - 19.0, y1 - 14.0, top - 14.0, top - 6.0)], wood, grain="x")
    gh.wood_boxes(kit, "Ends", [(x0 + 14.0, x0 + 19.0, y0 + 19.0, y1 - 19.0, top - 14.0, top - 6.0),
                                (x1 - 19.0, x1 - 14.0, y0 + 19.0, y1 - 19.0, top - 14.0, top - 6.0)], wood, grain="y")
    legs = []
    for x in (x0 + 22.0, (x0 + x1) / 2.0, x1 - 22.0):
        for y in (y0 + 20.0, y1 - 20.0):
            legs.append((x - 6.5, x + 6.5, y - 6.5, y + 6.5, 3.0, top - 6.0))
            legs.append((x - 8.0, x + 8.0, y - 8.0, y + 8.0, 0.0, 3.0))
    gh.wood_boxes(kit, "Legs", legs, wood, grain="h", bevel=0.6)
    gh.wood_boxes(kit, "Stretcher", [(x0 + 18.0, x1 - 18.0, (y0 + y1) / 2.0 - 3.0, (y0 + y1) / 2.0 + 3.0, 6.0, 10.0)],
                  wood, grain="x")
    # Eight places: north, south and an end each.
    metal = pewter()
    places = [(552.0, 496.0, 0.0), (686.0, 496.0, 0.0), (806.0, 496.0, 0.0), (566.0, 640.0, math.pi),
              (696.0, 640.0, math.pi), (482.0, 574.0, -math.pi / 2.0), (900.0, 574.0, math.pi / 2.0)]
    for index, (x, y, facing) in enumerate(places):
        x, y = on_table(x, y)
        plate(kit, "Plate%d" % index, x, y, top, 14.0, metal)
        kit.lathe("PlateWell%d" % index, x, y, [(0.0, top + 0.6), (8.4, top + 0.6), (8.4, top + 0.68),
                                                (0.0, top + 0.68)], pewter_dark(), plan=ROUND, segments=28)
        across = (math.cos(facing), math.sin(facing))
        for side, kind in ((-1.0, "fork"), (1.0, "knife"), (1.375, "spoon")):
            if index == 4 and kind == "spoon":
                continue
            reach = side * 20.0
            cutlery(kit, "Cutlery%d%s" % (index, kind), x + across[0] * reach, y + across[1] * reach, top + 0.1,
                    19.0, kind, turn=facing)
    # The eighth place: its napkin dropped, its spoon off on the cloth.
    napkin = linen()
    nx, ny = on_table(812.0, 640.0)
    shape = bmesh.new()
    corners = [shape.verts.new((nx - 13.0, ny + 7.0, top + 0.3)), shape.verts.new((nx + 13.0, ny + 8.0, top + 0.3)),
               shape.verts.new((nx + 1.0, ny - 11.0, top + 0.3))]
    shape.faces.new(corners)
    lifted = bmesh.ops.extrude_face_region(shape, geom=shape.faces[:])
    for vert in [element for element in lifted["geom"] if isinstance(element, bmesh.types.BMVert)]:
        vert.co.z += 1.2
    kit.shape("Napkin", shape, napkin, bevel=0.4)
    cutlery(kit, "LostSpoon", *on_table(866.0, 640.0), top + 0.1, 19.0, "spoon", turn=0.7)
    # Candlesticks down the middle, the tallest at the centre.
    for index, (x, y, tall) in enumerate(((546.0, 562.0, 1.0), (572.0, 568.0, 1.0), (700.0, 552.0, 1.35),
                                          (738.0, 576.0, 0.95), (766.0, 558.0, 1.1), (828.0, 566.0, 0.9))):
        candlestick(kit, "Candle%d" % index, *on_table(x, y), top, tall=tall, power=3.6)
    # Wine: glasses at three places, one fallen with its wine across the
    # boards; the decanter on its side, spilt toward the centre.
    goblet_glass(kit, "Glass0", *on_table(618.0, 504.0), top, size=1.5, wine=0.8)
    goblet_glass(kit, "Glass1", *on_table(862.0, 508.0), top, size=1.5, wine=0.7)
    goblet_glass(kit, "Glass2", *on_table(876.0, 540.0), top, size=1.5, wine=0.85)
    goblet_glass(kit, "FallenGlass", *on_table(514.0, 590.0), top + 4.5, size=1.5, wine=0.0, fallen=True)
    glass = wake.jar_glass()
    dx, dy = on_table(646.0, 548.0)
    decanter = kit.lathe("Decanter", dx, dy, [(0.0, top), (6.0, top), (7.5, top + 5.0), (6.5, top + 10.0),
                                                     (2.0, top + 15.0), (1.8, top + 21.0), (2.6, top + 22.0)], glass,
                         plan=ROUND, segments=28, close=False)
    decanter.visible_shadow = False
    wine_left = kit.lathe("DecanterWine", dx, dy, [(0.0, top + 0.5), (5.6, top + 0.6), (6.6, top + 4.0),
                                                          (0.0, top + 4.0)], wine_material(), plan=ROUND, segments=20)
    pivot = RP.world(dx, dy, top)
    tip = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-82.0), 4, "Y") @ Matrix.Translation(-pivot)
    shift = Matrix.Translation(RP.world(dx, dy, top + 7.0) - pivot)
    for obj in (decanter, wine_left):
        obj.matrix_world = shift @ tip @ obj.matrix_world
    kit.lathe("Stopper", *on_table(674.0, 552.0), [(0.0, top), (2.2, top + 0.6), (2.6, top + 2.4), (0.0, top + 3.6)], glass,
              plan=ROUND, segments=16)
    for index, (x, y, width, depth, turn) in enumerate(((664.0, 566.0, 40.0, 24.0, 0.3), (522.0, 606.0, 54.0, 38.0,
                                                                                             -0.4))):
        stain = gh.turned_quad(kit, "Spill%d" % index, *on_table(x, y), top + 0.32, width * 0.8, depth * 0.8, turn,
                               splash("DiningWineSpill", (0.15, 0.008, 0.012), gloss=0.04))
        stain.visible_shadow = False
    # A platter of fruit, picked over.
    px, py = on_table(762.0, 612.0)
    plate(kit, "Platter", px, py, top, 16.0, metal)
    MODEL.place(kit, "food_apple_01", "food_apple_01", px - 3.9, py - 1.3, top + 1.0, scale=0.62, turn=0.4)
    for k, part in enumerate(("food_pears_asian_01_b", "food_pears_asian_01_d")):
        MODEL.place(kit, "food_pears_asian_01", part, px + 3.2 + k * 4.6, py + 1.3 - k, top + 1.0, scale=0.85,
                    turn=k * 1.7)
    kit.lathe("Sauceboat", *on_table(640.0, 588.0), [(0.0, top), (4.0, top), (6.4, top + 4.0), (6.8, top + 6.0),
                                          (6.2, top + 6.0), (3.6, top + 1.6), (0.0, top + 1.6)], metal, plan=ROUND,
              segments=28)
    return kit


def chair(kit, part, wood, cloth):
    """A dining chair, as the painting draws them, built facing south round
    x 0 with its seat's front edge on y 0: square legs and rails, a red
    velvet seat, a tall back of velvet in a moulded frame between two posts
    with turned finials, under a carved crest rail."""
    w, d = 27.0, 40.0
    legs = [(-w, -w + 4.5, -5.0, -0.5, 0.0, 24.0), (w - 4.5, w, -5.0, -0.5, 0.0, 24.0),
            (-w, -w + 4.5, -d - 1.0, -d + 3.5, 0.0, 76.0), (w - 4.5, w, -d - 1.0, -d + 3.5, 0.0, 76.0)]
    gh.wood_boxes(kit, part + "Legs", legs, wood, grain="h", bevel=0.5)
    gh.wood_boxes(kit, part + "Rails", [(-w, w, -4.5, -0.5, 18.0, 24.0), (-w, w, -d - 0.5, -d + 3.0, 18.0, 24.0),
                                        (-w + 1.0, w - 1.0, -d * 0.55 - 1.5, -d * 0.55 + 1.5, 5.0, 8.0)], wood,
                  grain="x", bevel=0.4)
    gh.wood_boxes(kit, part + "SideRails", [(-w, -w + 3.5, -d, -4.0, 18.0, 24.0), (w - 3.5, w, -d, -4.0, 18.0, 24.0)],
                  wood, grain="y", bevel=0.4)
    kit.box(part + "Seat", -w + 0.5, w - 0.5, -d + 0.5, -0.2, 24.0, 29.5, cloth, bevel=2.0, uv="box")
    # The back: a velvet panel inside a moulded frame.
    kit.box(part + "Back", -w + 10.0, w - 10.0, -d - 0.2, -d + 2.4, 37.0, 64.0, cloth, bevel=1.4, uv="box")
    gh.wood_boxes(kit, part + "BackFrame", [(-w + 4.5, w - 4.5, -d - 0.6, -d + 3.2, 29.5, 37.0),
                                            (-w + 4.5, w - 4.5, -d - 0.6, -d + 3.2, 64.0, 69.0),
                                            (-w + 4.5, -w + 10.0, -d - 0.6, -d + 3.2, 37.0, 64.0),
                                            (w - 10.0, w - 4.5, -d - 0.6, -d + 3.2, 37.0, 64.0)], wood, grain="x",
                  bevel=0.6)
    crest = [(-w + 1.0, 69.0), (w - 1.0, 69.0), (w - 1.0, 74.0), (w - 7.0, 75.0)] + [
        (17.0 * math.cos(math.radians(a)), 75.0 + 5.5 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [
        (-w + 7.0, 75.0), (-w + 1.0, 74.0)]
    shape = bmesh.new()
    prism(shape, crest, -d - 1.2, -d + 3.6)
    kit.shape(part + "Crest", shape, wood, bevel=0.5, uv="box")
    for x in (-w + 2.25, w - 2.25):
        kit.lathe(part + "Finial", x, -d + 1.25, [(0.0, 76.0), (2.6, 76.0), (2.9, 77.6), (1.6, 79.0), (2.2, 80.6),
                                                  (0.0, 82.4)], wood, plan=ROUND, segments=14)


def chairs(table_kit):
    """Eight chairs round the table, as the painting sets them: three each
    side drawn up to it, and one at each end pushed back and turned toward
    the room. The south three and the two at the ends are part of the
    table's prop, as the painted table draws its chairs: its prompt box
    reaches the floor beyond them, where its footprint stops the player,
    as the painted one does."""
    kit = RP.Kit("Chairs")
    wood, cloth = oak(), velvet()
    west, east = math.radians(62.0), math.radians(-64.0)
    x0, x1, y0, y1 = TABLE
    cy = (y0 + y1) / 2.0

    def along(x):
        return on_table(x, 568.0)[0]

    # Drawn up under the table's edge on the north, pulled back a little on
    # the south and the ends, as the painting sets them round its table.
    seats = [(along(552.0), y0 + 8.0, (0.0, 1.0)), (along(686.0), y0 + 8.0, (0.0, 1.0)),
             (along(806.0), y0 + 8.0, (0.0, 1.0)), (along(561.0), y1 + 17.0, (0.0, -1.0)),
             (along(696.0), y1 + 17.0, (0.0, -1.0)), (along(839.0), y1 + 17.0, (0.0, -1.0)),
             (x0 - 35.0, cy + 31.5, (math.sin(west), math.cos(west))),
             (x1 + 36.0, cy + 25.5, (math.sin(east), math.cos(east)))]
    for index, (x, y, out) in enumerate(seats):
        before = set(bpy.data.objects)
        chair(table_kit if index >= 3 else kit, "Chair%d" % index, wood, cloth)
        face_on(made_since(before), x, y, out, "Chair%d" % index)
    return kit


def rugs():
    """The banquet rug under the table, and the small rugs before the hearth,
    the wall door and the dresser, laid over the flagstones."""
    kit = RP.Kit("Rugs", depth=False)
    backing = hall._cloth("DiningRugBacking", (0.05, 0.015, 0.02))
    for index, (x0, x1, y0, y1) in enumerate((TABLE_RUG, (90.0, 262.0, 362.0, 404.0),
                                              (1158.0, 1280.0, 280.0, 326.0))):
        length, width = x1 - x0, y1 - y0
        kit.box("RugUnder%d" % index, x0 + 1.0, x1 - 1.0, y0 + 2.0, y1 - 2.0, 2.6, 3.0, backing, bevel=0.0)
        rug = kit.quad("Rug%d" % index, [(x0, y1, 3.1), (x1, y1, 3.1), (x1, y0, 3.1), (x0, y0, 3.1)],
                       rug_material("DiningRug%d" % index, length, width, border=14.0 if index == 0 else 7.0),
                       uvs=((0.0, 0.0), (length, 0.0), (length, width), (0.0, width)))
        rug["floor_decal"] = True
    cx, cy, length, width, turn = 186.0, 872.0, 118.0, 52.0, 0.62
    cosine, sine = math.cos(turn), math.sin(turn)
    corners = [(cx + sx * length / 2.0 * cosine - sy * width / 2.0 * sine,
                cy + sx * length / 2.0 * sine + sy * width / 2.0 * cosine, 3.1)
               for sx, sy in ((-1.0, 1.0), (1.0, 1.0), (1.0, -1.0), (-1.0, -1.0))]
    rug = kit.quad("RugDresser", corners, rug_material("DiningRugDresser", length, width, border=7.0),
                   uvs=((0.0, 0.0), (length, 0.0), (length, width), (0.0, width)))
    rug["floor_decal"] = True
    return kit


def chain(kit, part, start, end, material, link=5.0, wire=0.55):
    """An iron chain from `start` to `end` (game px), its links true round in
    the room's space and turned a quarter each, as one mesh."""
    a, b = RP.world(*start), RP.world(*end)
    along = b - a
    length = along.length
    direction = along.normalized()
    helper = Vector((0.0, 0.0, 1.0)) if abs(direction.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    side = (direction.cross(helper).normalized(), None)
    side = (side[0], direction.cross(side[0]).normalized())
    step = link * RP.PX * 0.78
    count = max(int(length / step), 1)
    shape = bmesh.new()
    segments, sides = 12, 6
    for index in range(count):
        centre = a + direction * (step * (index + 0.5))
        across = side[index % 2]
        ring_long, ring_wide = link * RP.PX * 0.5, link * RP.PX * 0.3
        rings = []
        for k in range(segments):
            angle = 2.0 * math.pi * k / segments
            spine = centre + direction * (ring_long * math.cos(angle)) + across * (ring_wide * math.sin(angle))
            outward = (direction * (ring_long * math.cos(angle)) + across * (ring_wide * math.sin(angle))).normalized()
            normal = direction.cross(across).normalized()
            rings.append([shape.verts.new(RP.game(spine + (outward * math.cos(2.0 * math.pi * s / sides)
                                                          + normal * math.sin(2.0 * math.pi * s / sides))
                                                  * wire * RP.PX)) for s in range(sides)])
        for k in range(segments):
            here, there = rings[k], rings[(k + 1) % segments]
            for s in range(sides):
                following = (s + 1) % sides
                shape.faces.new((here[s], there[s], there[following], here[following]))
    return kit.shape(part, shape, material, smooth=True, sharp_angle=80.0)


def chandelier():
    """The wheel chandelier over the table, as the painting hangs it: an iron
    rim on eight spokes round a hub, a candle in a drip pan at each spoke's
    end, four chains up to a ring and the long chain to the ceiling, and a
    pendant under the hub."""
    kit = RP.Kit("Chandelier", prop="ChandelierSprite")
    metal = hall._cast_iron()
    bronze = hall._bronze()
    cx, cy = CHANDELIER
    h, r = CHANDELIER_H, CHANDELIER_R
    kit.ring("Rim", (cx, cy, h), (0.0, 0.0, 1.0), r, 3.4, bronze, segments=96, sides=10)
    kit.ring("RimInner", (cx, cy, h - 0.5), (0.0, 0.0, 1.0), r - 8.0, 1.8, metal, segments=80, sides=8)
    kit.lathe("Hub", cx, cy, [(0.0, h - 9.0), (6.0, h - 7.0), (9.0, h - 1.0), (9.0, h + 2.5), (5.0, h + 6.0),
                              (2.4, h + 8.0), (0.0, h + 8.5)], bronze, plan=ROUND, segments=24)
    kit.lathe("Pendant", cx, cy, [(0.0, h - 9.0), (3.6, h - 11.0), (4.4, h - 16.0), (2.0, h - 23.0),
                                  (0.0, h - 27.0)], bronze, plan=ROUND, segments=16)
    for k in range(8):
        angle = 2.0 * math.pi * (k + 0.5) / 8.0
        x, y = cx + r * math.cos(angle), cy + r * math.sin(angle) * ROUND
        kit.rod("Spoke%d" % k, (cx + 8.0 * math.cos(angle), cy + 8.0 * math.sin(angle) * ROUND, h), (x, y, h), 1.8,
                metal)
        kit.ball("Collar%d" % k, cx + (r - 8.0) * math.cos(angle), cy + (r - 8.0) * math.sin(angle) * ROUND, h, 2.8,
                 bronze, plan=ROUND)
        kit.lathe("Cup%d" % k, x, y, [(0.0, h + 2.0), (4.6, h + 2.0), (5.4, h + 3.8), (2.4, h + 5.0), (2.2, h + 7.0),
                                     (0.0, h + 7.0)], bronze, plan=ROUND, segments=16)
        kit.candle("Candle%d" % k, x, y, h + 7.0, height=11.0 + (k % 3) * 1.6, radius=2.0, power=2.6)
    crown_h = h + 64.0
    kit.ring("Crown", (cx, cy, crown_h), (0.0, 0.0, 1.0), 4.0, 1.0, metal, segments=24, sides=6)
    for k in range(4):
        angle = 2.0 * math.pi * k / 4.0 + math.pi / 4.0
        chain(kit, "Chain%d" % k, (cx + (r - 3.0) * math.cos(angle), cy + (r - 3.0) * math.sin(angle) * ROUND, h + 2.0),
              (cx, cy, crown_h), metal)
    chain(kit, "Drop", (cx, cy, crown_h + 3.0), (cx, cy, crown_h + 340.0), metal, link=6.0, wire=0.7)
    return kit


# ---------------------------------------------------------------- the east


def front_slab(kit, part, outline, y0, y1, material, uv="box", bevel=0.0):
    """A plate through `outline` in (x, h), from plan y0 (its back) to y1
    (its face), with projected UVs for a photo material."""
    shape = bmesh.new()
    front = [shape.verts.new((u, y1, v)) for u, v in outline]
    back = [shape.verts.new((u, y0, v)) for u, v in outline]
    shape.faces.new(front)
    shape.faces.new(list(reversed(back)))
    for index in range(len(outline)):
        following = (index + 1) % len(outline)
        shape.faces.new((back[index], back[following], front[following], front[index]))
    return kit.shape(part, shape, material, bevel=bevel, uv=uv)


def disc(kit, part, cx, y, ch, radius, material, steps=40):
    """A disc facing the camera, round on screen, UVs 0..1 across it."""
    points = gh.circle_points(cx, ch, radius, steps=steps)
    obj = RP.polygon_mesh("Dining" + part, points, [], lambda u, v: (u, y, v), material,
                          uv_of=lambda u, v: ((u - cx) / (2.0 * radius) + 0.5, (v - ch) / (2.0 * radius) + 0.5))
    return kit.keep(obj)


def clock():
    """The longcase clock, as the painting draws it, facing the room: a
    plinth and panelled base, a trunk whose glazed door shows the brass
    pendulum and weights hanging still, a hood on turned columns round the
    dial, stopped at midnight, and a carved crest with an urn finial."""
    kit = RP.Kit("GrandfatherClock", prop="GrandfatherClock")
    wood = gh.laid_photo("DiningClockWood", "wood_table", 0.45, 0.52, (1.0, 0.9, 0.5), saturation=0.85,
                         variety=0.06, wear=0.3)
    brass = hall._brass()
    x0, x1, back, face = CLOCK
    cx = (x0 + x1) / 2.0
    gh.wood_boxes(kit, "Plinth", [(x0 + 1.0, x1 - 1.0, back + 1.0, face, 0.0, 8.0)], wood, grain="x", bevel=0.8)
    gh.wood_boxes(kit, "Base", [(x0 + 5.0, x1 - 5.0, back + 3.0, face - 2.0, 8.0, 46.0)], wood, grain="h", bevel=0.6)
    gh.wood_boxes(kit, "BasePanel", [(x0 + 14.0, x1 - 14.0, face - 2.4, face - 1.2, 15.0, 39.0)], wood, grain="h",
                  bevel=0.6)
    gh.wood_boxes(kit, "BaseCap", [(x0 + 3.0, x1 - 3.0, back + 2.0, face - 1.0, 46.0, 51.0)], wood, grain="x",
                  bevel=0.6)
    trunk = (cx - 30.0, cx + 30.0)
    gh.wood_boxes(kit, "Trunk", [(trunk[0], trunk[1], back + 5.0, face - 4.0, 51.0, 120.0)], wood, grain="h",
                  bevel=0.5)
    door = (cx - 19.0, cx + 19.0, 57.0, 114.0)
    gh.wood_boxes(kit, "DoorFrame", [(door[0] - 3.0, door[0], face - 4.6, face - 3.4, door[2], door[3]),
                                     (door[1], door[1] + 3.0, face - 4.6, face - 3.4, door[2], door[3]),
                                     (door[0] - 3.0, door[1] + 3.0, face - 4.6, face - 3.4, door[2] - 3.0, door[2]),
                                     (door[0] - 3.0, door[1] + 3.0, face - 4.6, face - 3.4, door[3], door[3] + 3.0)],
                  wood, grain="h", bevel=0.3)
    kit.box("TrunkInside", door[0], door[1], back + 6.0, face - 8.0, door[2], door[3], wood, bevel=0.0, uv="box")
    kit.rod("PendulumRod", (cx, face - 3.4, 113.0), (cx, face - 3.4, 75.0), 0.7, brass)
    kit.ball("PendulumBob", cx, face - 2.6, 70.0, 8.0, gilt(), plan=0.28, segments=24)
    for dx in (-11.0, 11.0):
        kit.rod("WeightLine%d" % int(dx), (cx + dx, face - 4.4, 113.0), (cx + dx, face - 4.4, 104.0), 0.25, brass)
        kit.cylinder("Weight%d" % int(dx), cx + dx, face - 4.4, 84.0, 104.0, 3.2, brass, segments=16)
    gh.wood_boxes(kit, "Waist", [(x0 + 6.0, x1 - 6.0, back + 3.0, face - 1.5, 120.0, 126.0)], wood, grain="x",
                  bevel=0.6)
    hood = (cx - 36.0, cx + 36.0, 126.0, 188.0)
    gh.wood_boxes(kit, "Hood", [(hood[0], hood[1], back + 2.0, face - 2.0, hood[2], hood[3])], wood, grain="x",
                  bevel=0.6)
    for x in (hood[0] + 4.0, hood[1] - 4.0):
        kit.lathe("Column", x, face - 0.5, [(0.0, hood[2]), (3.2, hood[2]), (3.2, hood[2] + 3.0), (2.0, hood[2] + 5.0),
                                           (2.2, hood[3] - 6.0), (3.2, hood[3] - 3.0), (3.2, hood[3]), (0.0, hood[3])],
                  brass, plan=ROUND, segments=16)
    dial_h = 157.0
    gh.band(kit, "DialDoor", gh.circle_points(cx, dial_h, 25.0, steps=40), 3.6, face - 2.4, face - 0.4, wood,
            closed=True)
    gh.band(kit, "Bezel", gh.circle_points(cx, dial_h, 22.0, steps=40), 2.0, face - 1.6, face - 0.2, brass, closed=True)
    disc(kit, "Dial", cx, face - 1.2, dial_h, 21.0, clock_face())
    for corner in ((-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)):
        kit.ball("Spandrel", cx + corner[0] * 23.5, face - 1.4, dial_h + corner[1] * 22.5, 2.0, brass, plan=0.5)
    gh.wood_boxes(kit, "Cornice", [(hood[0] - 3.0, hood[1] + 3.0, back, face + 0.5, hood[3], hood[3] + 5.0)], wood,
                  grain="x", bevel=0.8)
    # The broken pediment: two swan necks rising to scrolls either side of a
    # plinth that carries the urn.
    base_h = hood[3] + 5.0
    for side in (-1.0, 1.0):
        neck = [(cx + side * (36.0 - 30.0 * k / 12.0), base_h + 4.0 + 19.0 * math.sin(math.pi / 2.0 * k / 12.0) ** 1.4)
                for k in range(13)]
        gh.band(kit, "Pediment%d" % int(side), [(cx + side * 38.0, base_h)] + neck, 5.0, face - 4.0, face - 0.5,
                wood)
        kit.ball("Scroll%d" % int(side), cx + side * 7.0, face - 1.5, base_h + 22.0, 3.6, wood, plan=0.5)
        kit.lathe("SideFinial%d" % int(side), cx + side * 33.0, face - 2.5, [
            (0.0, base_h), (2.4, base_h), (2.8, base_h + 3.0), (1.4, base_h + 5.0), (2.0, base_h + 7.0),
            (0.0, base_h + 9.0)], brass, plan=ROUND, segments=14)
    gh.wood_boxes(kit, "UrnPlinth", [(cx - 4.0, cx + 4.0, back + 6.0, face - 2.0, base_h, base_h + 22.0)], wood,
                  grain="h", bevel=0.5)
    kit.lathe("Finial", cx, face - 3.0, [(0.0, base_h + 22.0), (3.6, base_h + 22.0), (4.6, base_h + 26.0),
                                         (3.0, base_h + 29.0), (1.2, base_h + 32.0), (1.8, base_h + 34.0),
                                         (0.0, base_h + 36.0)], brass, plan=ROUND, segments=16)
    # Drawn in to a real clock's size about the middle of its foot: the room's
    # space is metric and the same every way, so this is a true rescale.
    pivot = RP.world(cx, face, 0.0)
    to_size = Matrix.Translation(pivot) @ Matrix.Scale(CLOCK_SCALE, 4) @ Matrix.Translation(-pivot)
    for obj in kit.made:
        obj.matrix_world = to_size @ obj.matrix_world
    return kit


def bowl(kit, part, x, y, h, radius, material, depth=None):
    """A wide bowl, true round, its rim rolled over."""
    r = radius
    d = r * 0.42 if depth is None else depth
    return kit.lathe(part, x, y, [(0.0, h), (r * 0.45, h), (r * 0.8, h + d * 0.45), (r, h + d), (r * 0.97, h + d + 0.6),
                                  (r * 0.9, h + d + 0.2), (r * 0.72, h + d * 0.5), (r * 0.4, h + 1.0), (0.0, h + 1.0)],
                     material, plan=ROUND, segments=36)


def sideboard():
    """The sideboard down the east wall, laden as the painting lays it: its
    top with brass bowls, goblets and a two-handled pot, its raised back
    shelf with goblets, a vase, a bowl and a candle burning; a cupboard door
    in its south end, a drawer pulled out of its west side with the silver
    in it, and a strip of red cloth caught on it, hanging torn over the
    south end."""
    kit = RP.Kit("Sideboard", prop="Sideboard")
    wood = walnut()
    brass = hall._brass()
    x0, x1, y0, y1 = SIDEBOARD
    top = SIDEBOARD_TOP
    shelf = top + 9.0
    gh.wood_boxes(kit, "Plinth", [(x0 + 4.0, x1 - 4.0, y0 + 4.0, y1 - 1.0, 0.0, 6.0)], wood, grain="y")
    gh.wood_boxes(kit, "Body", [(x0 + 2.0, x1 - 2.0, y0 + 2.0, y1 - 3.0, 6.0, top - 6.0)], wood, grain="y")
    slab = gh.wood_boxes(kit, "Top", [(x0 - 4.0, GALLERY_X + 1.0, y0 - 4.0, y1 + 4.0, top - 6.0, top)], wood,
                         grain="y", bevel=1.0)
    gh.wood_boxes(kit, "Gallery", [(GALLERY_X, x1 + 3.0, y0 - 3.0, y1 + 3.0, top - 6.0, shelf)], wood, grain="y",
                  bevel=1.0)
    # A cupboard door in its south end, under the top.
    a, b = x0 + 8.0, x1 - 8.0
    gh.wood_boxes(kit, "Door", [(a, b, y1 - 3.6, y1 - 2.2, 10.0, top - 11.0)], wood, grain="h", bevel=0.5)
    gh.wood_boxes(kit, "DoorPanel", [(a + 6.0, b - 6.0, y1 - 2.4, y1 - 1.4, 15.0, top - 16.0)], wood, grain="h",
                  bevel=0.6)
    kit.box("DoorPull", a + 2.0, a + 4.0, y1 - 1.6, y1 + 0.2, 20.0, 29.0, brass, bevel=0.4)
    # Three drawers along its west side, under the top.
    lift = top - 52.0
    span = (y1 - y0 - 28.0) / 3.0
    drawers = [(y0 + 8.0 + k * (span + 6.0), y0 + 8.0 + k * (span + 6.0) + span) for k in range(3)]
    for k, (d0, d1) in enumerate(drawers):
        if k == 1:
            continue
        gh.wood_boxes(kit, "Drawer%d" % k, [(x0 + 0.6, x0 + 2.2, d0, d1, 30.0 + lift, 42.0 + lift)], wood, grain="y",
                      bevel=0.4)
        kit.ball("DrawerPull%d" % k, x0, (d0 + d1) / 2.0, 36.0 + lift, 1.5, brass, plan=0.6)
    # The middle drawer, pulled out with the silver in it.
    d0, d1 = drawers[1]
    out = x0 - 34.0
    gh.wood_boxes(kit, "OpenDrawer", [(out, x0 + 6.0, d0, d0 + 2.4, 29.0 + lift, 40.0 + lift),
                                      (out, x0 + 6.0, d1 - 2.4, d1, 29.0 + lift, 40.0 + lift),
                                      (out, out + 2.4, d0, d1, 29.0 + lift, 40.0 + lift),
                                      (out, x0 + 6.0, d0, d1, 28.0 + lift, 29.5 + lift)],
                  wood, grain="y", bevel=0.3)
    kit.ball("OpenDrawerPull", out - 0.8, (d0 + d1) / 2.0, 35.0 + lift, 1.5, brass, plan=0.6)
    rng = random.Random(23)
    for k in range(11):
        x, y = rng.uniform(out + 6.0, x0 - 2.0), rng.uniform(d0 + 8.0, d1 - 8.0)
        cutlery(kit, "Silver%d" % k, x, y, 29.6 + lift, 16.0, ("knife", "fork", "spoon")[k % 3],
                turn=rng.uniform(-0.4, 0.4))
    for k in range(8):
        kit.lathe("Coin%d" % k, rng.uniform(out + 5.0, x0 - 4.0), rng.uniform(d0 + 6.0, d1 - 6.0),
                  [(0.0, 29.6 + lift), (2.0, 29.6 + lift), (2.0, 30.3 + lift), (0.0, 30.3 + lift)], silver(),
                  plan=ROUND, segments=14)
    # On its top, laid out on the painted one and drawn in.
    for k, (x, y, r) in enumerate(((1264.0, 718.0, 17.0), (1282.0, 766.0, 19.0), (1262.0, 818.0, 18.0),
                                   (1296.0, 690.0, 12.0))):
        bowl(kit, "Bowl%d" % k, *on_sideboard(x, y), top, r * 0.75, brass)
    MODEL.place(kit, "brass_goblets", "brass_goblet_01", *on_sideboard(1244.0, 752.0), top, scale=1.15, turn=0.3)
    MODEL.place(kit, "brass_goblets", "brass_goblet_03", *on_sideboard(1304.0, 830.0), top, scale=1.1, turn=1.4)
    MODEL.place(kit, "brass_goblets", "brass_goblet_02", *on_sideboard(1240.0, 688.0), top, scale=1.0, turn=2.6)
    MODEL.place(kit, "brass_pot_02", "brass_pot_02", *on_sideboard(1280.0, 860.0), top, scale=1.05, turn=0.15)
    # On the raised shelf behind.
    MODEL.place(kit, "wine_bottles_01", "wine_bottles_01_bordeaux", *on_sideboard(1356.0, 676.0), shelf, scale=1.0)
    MODEL.place(kit, "brass_goblets", "brass_goblet_02", *on_sideboard(1348.0, 714.0), shelf, scale=1.0, turn=2.2)
    MODEL.place(kit, "brass_vase_03", "brass_vase_03", *on_sideboard(1338.0, 760.0), shelf, scale=1.1, turn=0.5)
    bowl(kit, "ShelfBowl", *on_sideboard(1344.0, 806.0), shelf, 7.0, brass)
    candlestick(kit, "Candle", *on_sideboard(1340.0, 856.0), shelf, tall=1.25, power=3.4)
    MODEL.place(kit, "brass_goblets", "brass_goblet_01", *on_sideboard(1338.0, 904.0), shelf, scale=0.95, turn=0.9)
    cloth_strip(kit, slab)
    return kit


def cloth_strip(kit, slab):
    """The torn red cloth, dropped across the sideboard's south-west corner
    so it hangs over the front, its torn end ragged."""
    material = hall._material("DiningTornCloth", lambda nodes, links: _torn_cloth_shader(nodes, links))
    x0, x1, y0, y1 = SIDEBOARD
    # Most of it lies on the top, so the rough wool's grip holds the end
    # that hangs.
    cloth = kit.sheet("TornCloth", GALLERY_X - 44.0, GALLERY_X - 14.0, y1 - 44.0, y1 + 36.0,
                      lambda x, y: SIDEBOARD_TOP + 1.4, material, columns=24, rows=72)
    # Dropped askew: its end hangs east of where it lies, clear of the shelf.
    centre = RP.world(GALLERY_X - 29.0, y1 - 22.0, 0.0)
    cloth.data.transform(Matrix.Translation(centre) @ Matrix.Rotation(math.radians(20.0), 4, "Z")
                         @ Matrix.Translation(-centre))
    RP.simulate_cloth(cloth, [slab], frames=42, mass=0.25, bending=0.6, stiffness=12.0, friction=30.0)
    wake.thicken(cloth, 0.5)


def _torn_cloth_shader(nodes, links):
    """Red wool, its south end torn: ragged and fraying where it hangs."""
    op = hall._MathBuilder(nodes, links)
    coords, u, v = hall._uv_parts(nodes, links)
    fibre = hall._noise(nodes, links, coords.outputs["UV"], scale=900.0, detail=4.0)
    color = hall._mix(nodes, links, fibre, (0.075, 0.008, 0.006), (0.135, 0.016, 0.011))
    shader = hall._principled(nodes, links, color, roughness=0.9)
    shader.inputs["Sheen Weight"].default_value = 0.6
    # UVs are the sheet's floor px over 180: v grows north, so its south end
    # (the low v) is the torn end.
    ragged = hall._noise(nodes, links, coords.outputs["UV"], scale=60.0, detail=3.0)
    tear = op("SUBTRACT", v, op("ADD", (SIDEBOARD[3] + 30.0) / -180.0, op("MULTIPLY", ragged, 0.06)))
    hall._alpha_cut(nodes, links, shader, op("GREATER_THAN", tear, 0.0))


# ---------------------------------------------------------------- the west


def dresser():
    """The dresser, as the painting draws it, turned across the corner to
    face the room: a cupboard base with two panelled doors under a counter
    with a pewter basin and a folded cloth, and above it open shelves of
    plates stood on edge and laid in stacks, cups and a brass goblet, under a
    carved crest. Built facing south, then turned (face_on)."""
    kit = RP.Kit("Cabinet", prop="Cabinet")
    wood = walnut()
    metal = pewter()
    rng = random.Random(61)
    before = set(bpy.data.objects)
    w, d = 76.0, 44.0
    counter, hutch_top = 54.0, 146.0
    gh.wood_boxes(kit, "Plinth", [(-w + 2.0, w - 2.0, -d + 2.0, -1.0, 0.0, 6.0)], wood, grain="x")
    gh.wood_boxes(kit, "Base", [(-w + 3.0, w - 3.0, -d + 3.0, -2.0, 6.0, counter - 6.0)], wood, grain="x")
    gh.wood_boxes(kit, "Counter", [(-w, w, -d, 1.5, counter - 6.0, counter)], wood, grain="x", bevel=1.0)
    for a, b in ((-w + 8.0, -3.0), (3.0, w - 8.0)):
        gh.wood_boxes(kit, "Door", [(a, b, -2.4, -1.0, 11.0, counter - 10.0)], wood, grain="h", bevel=0.5)
        gh.wood_boxes(kit, "Panel", [(a + 6.0, b - 6.0, -1.2, -0.2, 16.0, counter - 15.0)], wood, grain="h",
                      bevel=0.6)
        kit.ball("Knob", b - 5.0 if a < 0.0 else a + 5.0, -0.2, 27.0, 1.6, hall._brass(), plan=0.6)
    hutch_front = -d + 22.0
    gh.wood_boxes(kit, "HutchBack", [(-w + 5.0, w - 5.0, -d + 2.0, -d + 5.0, counter, hutch_top)], wood, grain="h")
    gh.wood_boxes(kit, "HutchSides", [(-w + 5.0, -w + 9.0, -d + 2.0, hutch_front, counter, hutch_top),
                                      (w - 9.0, w - 5.0, -d + 2.0, hutch_front, counter, hutch_top)], wood, grain="h")
    shelves = (80.0, 104.0, 128.0)
    gh.wood_boxes(kit, "Shelves", [(-w + 9.0, w - 9.0, -d + 5.0, hutch_front, h - 2.5, h) for h in shelves], wood,
                  grain="x", bevel=0.4)
    gh.wood_boxes(kit, "Cornice", [(-w + 2.0, w - 2.0, -d, hutch_front + 3.0, hutch_top, hutch_top + 6.0)], wood,
                  grain="x", bevel=0.8)
    crest = [(-w + 6.0, hutch_top + 6.0), (w - 6.0, hutch_top + 6.0), (w - 6.0, hutch_top + 10.0)] + [
        (34.0 * math.cos(math.radians(a)), hutch_top + 10.0 + 8.0 * math.sin(math.radians(a)))
        for a in range(0, 181, 12)] + [(-w + 6.0, hutch_top + 10.0)]
    front_slab(kit, "Crest", crest, -d + 2.0, -d + 6.0, wood, bevel=0.5)
    # Plates stood on edge along the back of the two lower shelves, plates
    # stacked on the top one, cups and a goblet beside them.
    for row, shelf in enumerate(shelves[:2]):
        for k in range(6):
            x = -w + 20.0 + k * 21.0
            plate_obj = plate(kit, "StoodPlate%d_%d" % (row, k), x, -d + 10.0, shelf + 9.0, 9.5, silver())
            pivot = RP.world(x, -d + 10.0, shelf + 9.0)
            plate_obj.matrix_world = (Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(76.0), 4, "X")
                                      @ Matrix.Translation(-pivot) @ plate_obj.matrix_world)
    for k, x in enumerate((-48.0, -20.0, 14.0, 44.0)):
        for level in range(rng.randint(2, 4)):
            plate(kit, "StackPlate%d_%d" % (k, level), x, -d + 13.0, shelves[2] + level * 1.5, 8.5, metal)
    for k, x in enumerate((-58.0, -36.0, 36.0, 58.0)):
        kit.lathe("Cup%d" % k, x, -d + 16.0, [(0.0, shelves[0]), (2.4, shelves[0]), (3.2, shelves[0] + 5.0),
                                              (3.0, shelves[0] + 5.4)], metal, plan=ROUND, segments=16, close=False)
    MODEL.place(kit, "brass_goblets", "brass_goblet_02", 58.0, -d + 14.0, shelves[2], scale=0.5)
    # On the counter: the basin, a folded cloth, a jug.
    kit.lathe("Basin", -32.0, -18.0, [(0.0, counter), (6.0, counter), (12.0, counter + 4.0), (14.0, counter + 8.0),
                                       (13.0, counter + 8.4), (10.0, counter + 4.0), (5.0, counter + 1.5),
                                       (0.0, counter + 1.5)], metal, plan=ROUND, segments=36)
    kit.box("FoldedCloth", 22.0, 46.0, -26.0, -8.0, counter, counter + 4.0, linen(), bevel=1.2)
    kit.box("FoldedClothTop", 24.0, 44.0, -25.0, -9.0, counter + 4.0, counter + 6.4, linen(), bevel=1.0)
    face_on(made_since(before), DRESSER[0], DRESSER[1], (math.sin(DRESSER_TURN), math.cos(DRESSER_TURN)), "Dresser")
    # The jug table beside it, as the painting stands it, square to the room.
    tx, ty = 88.0, 884.0
    gh.wood_boxes(kit, "JugTable", [(tx - 20.0, tx + 20.0, ty - 15.0, ty + 15.0, 26.0, 30.0)], wood, grain="x",
                  bevel=0.6)
    gh.wood_boxes(kit, "JugTableLegs", [(x - 2.0, x + 2.0, y - 2.0, y + 2.0, 0.0, 26.0) for x in (tx - 16.0, tx + 16.0)
                                        for y in (ty - 11.0, ty + 11.0)], wood, grain="h")
    jug(kit, "JugTall", tx - 7.0, ty - 2.0, 30.0, metal, size=1.35)
    jug(kit, "JugSmall", tx + 9.0, ty + 3.0, 30.0, metal, size=0.95)
    return kit


# ---------------------------------------------------------------- the south


def door_arch(x0, x1, eave, apex, steps=12):
    """A flattened pointed (Tudor) arch over x0..x1, as the painting draws
    the doors': each half an arc of an ellipse rising plumb from its eave
    and meeting the other at a shallow point. (x, h) points west to east."""
    half = (x1 - x0) / 2.0
    stop = math.radians(55.0)
    a, b = half / (1.0 - math.cos(stop)), (apex - eave) / math.sin(stop)
    west = [(x0 + a * (1.0 - math.cos(stop * k / steps)), eave + b * math.sin(stop * k / steps))
            for k in range(steps + 1)]
    east = [(x1 - (x - x0), h) for x, h in reversed(west[:-1])]
    return west + east


def door_top(x):
    """The double door's top edge at x."""
    arch = door_arch(DOOR_X[0], DOOR_X[1], DOOR_EAVE, DOOR_APEX, steps=24)
    for (ax, ah), (bx, bh) in zip(arch[:-1], arch[1:]):
        if ax <= x <= bx and bx - ax > 1e-6:
            return ah + (bh - ah) * (x - ax) / (bx - ax)
    return DOOR_EAVE


def main_door():
    """The arched double door, as the painting draws it, on the south wall's
    face: two leaves of boards under a studded rim that rises to a shallow
    point, iron strap hinges with scrolled ends, ring pulls, a meeting stile
    with the Hall's clock on a brass boss; a stone threshold and the red
    runner out into the Hall."""
    kit = RP.Kit("MainDoor", prop="MainDoor")
    boards = planks()
    metal = hall._cast_iron()
    face = DOOR_FACE_Y
    rng = random.Random(71)
    for side, (a, b) in (("W", (DOOR_X[0], DOOR_CX - 1.2)), ("E", (DOOR_CX + 1.2, DOOR_X[1]))):
        for k in range(5):
            p0 = a + (b - a) * k / 5.0 + 0.3
            p1 = a + (b - a) * (k + 1) / 5.0 - 0.3
            outline = [(p0, 0.0), (p1, 0.0)] + [(p1 - (p1 - p0) * s / 4.0, door_top(p1 - (p1 - p0) * s / 4.0) - 2.0)
                                                 for s in range(5)]
            front_slab(kit, "Board%s%d" % (side, k), outline, face - 6.0, face - 2.0 + rng.uniform(-0.3, 0.3),
                       boards, bevel=0.3)
        outer = a if side == "W" else b
        inward = 1.0 if side == "W" else -1.0
        for h in (16.0, 44.0, 68.0):
            reach = 46.0 if h < 60.0 else 36.0
            kit.box("Strap%s%d" % (side, int(h)), min(outer, outer + inward * reach), max(outer, outer + inward * reach),
                    face - 2.0, face - 0.8, h - 2.6, h + 2.6, metal, bevel=0.3)
            end = outer + inward * reach
            kit.ball("StrapScroll%s%d" % (side, int(h)), end, face - 1.2, h, 3.4, metal, plan=0.35)
            kit.ball("StrapCurl%s%d" % (side, int(h)), end - inward * 3.0, face - 1.0, h + 3.6, 1.7, metal, plan=0.4)
            for along in (6.0, 16.0, 26.0, 36.0):
                if along < reach:
                    kit.ball("Rivet", outer + inward * along, face - 0.7, h, 0.85, metal, plan=0.8)
        ring_x = DOOR_CX - inward * 9.0
        kit.ball("RingBoss%s" % side, ring_x, face - 1.4, 44.0, 2.2, metal, plan=0.4)
        kit.ring("RingPull%s" % side, (ring_x, face - 0.4, 39.0), (0.0, 1.0, 0.0), 3.8, 0.75, metal, segments=24,
                 sides=6)
    gh.wood_boxes(kit, "MeetingStile", [(DOOR_CX - 2.8, DOOR_CX + 2.8, face - 5.0, face - 0.6, 0.0, DOOR_APEX - 6.0)],
                  boards, grain="h", photo_grain="v", bevel=0.4)
    for h in (10.0, 24.0, 58.0, 72.0):
        kit.ball("StileStud", DOOR_CX, face - 0.4, h, 1.1, metal, plan=0.8)
    # The rim round the arch, studded.
    arch = door_arch(DOOR_X[0], DOOR_X[1], DOOR_EAVE, DOOR_APEX, steps=14)
    rim = [(DOOR_X[0], 0.0)] + arch + [(DOOR_X[1], 0.0)]
    gh.band(kit, "ArchRim", rim, 3.6, face - 3.0, face + 0.6, boards)
    for x, h in arch[1:-1:2]:
        kit.ball("RimStud", x, face + 0.8, h, 1.0, hall._brass(), plan=0.7)
    kit.ball("DoorBoss", DOOR_CX, face, 90.0, 3.2, hall._brass(), plan=0.5)
    stone = ashlar()
    kit.box("Threshold", DOOR_X[0] - 4.0, DOOR_X[1] + 4.0, face - 6.0, face + 8.0, -1.0, 0.8, stone, bevel=0.8,
            uv="box")
    runner = kit.quad("Runner", [(DOOR_X[0] + 4.0, 1100.0, 0.9), (DOOR_X[1] - 4.0, 1100.0, 0.9),
                                 (DOOR_X[1] - 4.0, face + 8.5, 0.9), (DOOR_X[0] + 4.0, face + 8.5, 0.9)],
                      rug_material("DiningRunner", 1100.0 - face, DOOR_X[1] - DOOR_X[0] - 8.0, border=6.0),
                      uvs=((0.0, 0.0), (0.0, DOOR_X[1] - DOOR_X[0] - 8.0), (1100.0 - face, DOOR_X[1] - DOOR_X[0] - 8.0),
                           (1100.0 - face, 0.0)))
    runner["floor_decal"] = True
    return kit


def door_surround():
    """The south wall round the door, as the painting builds it, in dressed
    courses: the parapet with a dark recess each side, the torch blocks
    standing proud of it and the pilasters at the door's sides, each under a
    lighter cap; a step either side of the threshold, and a torch burning in
    an iron bracket on each torch block."""
    kit = RP.Kit("DoorSurround")
    stone = ashlar()
    dark = gh.laid_photo("DiningDarkCourse", "seaside_rock", 0.6, 0.9, (0.74, 0.66, 0.56), saturation=0.25,
                         variety=0.18, wear=0.2, ao=0.2)
    rng = random.Random(83)
    face = DOOR_FACE_Y
    lit, shade = [], []

    def coursed(boxes, x0, x1, height, y_face, widths=(26.0, 40.0), course=17.0):
        h = 0.0
        while h < height - 1.0:
            step = min(course, height - h)
            blocks_row(boxes, x0, x1, h, h + step, SOUTH_Y - 2.0, y_face, rng, widths=widths)
            h += step

    cap_h = 6.0
    # The parapet, with a recess each side cut back into it.
    spans = [(PARAPET_X[0], RECESSES[0][0]), (RECESSES[0][1], TORCH_BLOCKS[0][0]),
             (TORCH_BLOCKS[0][1], PILASTERS[0][0]), (PILASTERS[1][1], TORCH_BLOCKS[1][0]),
             (TORCH_BLOCKS[1][1], RECESSES[1][0]), (RECESSES[1][1], PARAPET_X[1])]
    for x0, x1 in spans:
        coursed(shade, x0, x1, PARAPET_H - cap_h, face)
    for x0, x1 in RECESSES:
        coursed(shade, x0, x1, PARAPET_H - cap_h - 9.0, face - 6.0, widths=(18.0, 26.0), course=12.0)
        shade.append((x0, x1, SOUTH_Y - 2.0, face - 1.0, PARAPET_H - cap_h - 9.0, PARAPET_H - cap_h))
    # The parapet's cap, cut where the door rises through it.
    caps = [(PARAPET_X[0] - 2.0, PILASTERS[0][0], SOUTH_Y - 3.0, face + 2.0, PARAPET_H - cap_h, PARAPET_H),
            (PILASTERS[1][1], PARAPET_X[1] + 2.0, SOUTH_Y - 3.0, face + 2.0, PARAPET_H - cap_h, PARAPET_H)]
    for x0, x1 in TORCH_BLOCKS:
        coursed(lit, x0, x1, TORCH_BLOCK_H - cap_h, face + 6.0, widths=(30.0, 44.0), course=20.0)
        caps.append((x0 - 2.5, x1 + 2.5, SOUTH_Y - 4.0, face + 8.5, TORCH_BLOCK_H - cap_h, TORCH_BLOCK_H))
    for x0, x1 in PILASTERS:
        coursed(lit, x0, x1, PILASTER_H - cap_h, face + 3.0, widths=(40.0, 40.0), course=19.0)
        caps.append((x0 - 1.5, x1 + 1.5, SOUTH_Y - 3.0, face + 5.0, PILASTER_H - cap_h, PILASTER_H))
    # A step either side of the threshold.
    for x0, x1 in ((580.0, PILASTERS[0][0] + 6.0), (PILASTERS[1][1] - 6.0, 868.0)):
        lit.append((x0, x1, face, face + 22.0, 0.0, 12.0))
    kit.blocks("Courses", shade, dark, bevel=0.7, uv="box")
    kit.blocks("LitCourses", lit, stone, bevel=0.8, uv="box")
    kit.blocks("Caps", caps, stone, bevel=1.0, uv="box")
    metal = hall._cast_iron()
    handle = hall._material("DiningTorchHandle", lambda nodes, links: _bark_shader(nodes, links))
    for index, x in enumerate(TORCH_X):
        y, h = face + 6.0, 64.0
        kit.box("TorchPlate%d" % index, x - 5.0, x + 5.0, y, y + 1.4, h - 9.0, h + 9.0, metal, bevel=0.3)
        kit.rod("TorchArm%d" % index, (x, y + 1.0, h - 4.0), (x, y + 9.0, h - 1.0), 1.0, metal)
        kit.ring("TorchCollar%d" % index, (x, y + 10.0, h), (0.0, 0.0, 1.0), 3.0, 0.7, metal, segments=16, sides=6)
        kit.rod("Torch%d" % index, (x, y + 10.0, h - 10.0), (x, y + 10.5, h + 10.0), 1.8, handle)
        kit.cylinder("TorchHead%d" % index, x, y + 10.5, h + 8.0, h + 15.0, 3.2, charred(), tip=3.8, segments=12)
        kit.flame("Torch%d" % index, x, y + 10.5, h + 15.0, size=2.6, power=7.0, color=(1.0, 0.5, 0.18))
        RP.GLOWS[-1]["kind"] = "lantern"
    # The Hall's lamplight beyond the door, on its boards and the runner.
    kit.light("HallLamp", DOOR_CX, 1150.0, 70.0, (1.0, 0.62, 0.32), 14.0, radius=0.3)
    return kit


# ---------------------------------------------------------------- the floor


def paving():
    """The floor, as the painting lays it: grey flagstones in rough east-west
    courses, each stone a slab of its own size with a worn chamfered rim
    (room_greenhouse._paver), some courses split into two smaller stones;
    stones the rug, the fireplace or the furniture would hide are left out."""
    kit = RP.Kit("Paving", depth=False)
    rng = random.Random(1907)
    shape = bmesh.new()
    hidden = ((TABLE_RUG[0] + 14.0, TABLE_RUG[1] - 14.0, TABLE_RUG[2] + 14.0, TABLE_RUG[3] - 14.0),
              (FIRE_X[0], FIRE_X[1], 0.0, HEARTH_Y - 4.0),
              (SIDEBOARD[0] + 6.0, SIDEBOARD[1] - 6.0, SIDEBOARD[2] + 6.0, SIDEBOARD[3] - 6.0),
              (SERVING[0] + 4.0, SERVING[1] - 4.0, SERVING[2] + 4.0, SERVING[3] - 4.0))
    laid = 0
    gap = 0.9

    def lay(a, b, c, d):
        nonlocal laid
        inside = any(p + 2.0 <= a and b <= q - 2.0 and r + 2.0 <= c and d <= s - 2.0 for p, q, r, s in hidden)
        d = min(d, SOUTH_Y + 6.0)
        if not inside and d - c > 6.0:
            gh._paver(shape, a + gap, b - gap, c + gap, d - gap, rng.uniform(1.9, 2.5), rng)
            laid += 1

    y = BACK_Y - 12.0
    while y < SOUTH_Y:
        y1 = y + rng.uniform(22.0, 34.0)
        x = LEFT_BASE[1][0] - 6.0 - rng.uniform(0.0, 30.0)
        while x < RIGHT_BASE[1][0] + 6.0:
            x1 = x + rng.uniform(28.0, 66.0)
            if rng.random() < 0.24 and y1 - y > 26.0:
                middle = y + (y1 - y) * rng.uniform(0.42, 0.58)
                split = x + (x1 - x) * rng.uniform(0.35, 0.65)
                lay(x, x1, y, middle)
                lay(x, split, middle, y1)
                lay(split, x1, middle, y1)
            else:
                lay(x, x1, y, y1)
            x = x1
        y = y1
    kit.shape("Flagstones", shape, gh.laid_photo("DiningFlagstone", "seaside_rock", 0.9, FLOOR_VALUE,
                                                 (1.0, 0.86, 0.62), saturation=0.22, variety=0.16, wear=0.24),
              uv="box")
    print("DINING PAVING %d stones" % laid)
    return kit


def boot_prints():
    """Muddy boot prints, as the painting tracks them: from the wall door
    across toward the clock, and from the table's south side to the main
    door."""
    kit = RP.Kit("BootPrints", depth=False)
    mud = mud_print()
    trails = ([(992.0, 300.0), (1040.0, 362.0), (1098.0, 430.0), (1160.0, 494.0), (1222.0, 552.0),
               (1284.0, 598.0)],
              [(816.0, 714.0), (806.0, 800.0), (782.0, 838.0), (758.0, 876.0), (736.0, 912.0)])
    count = 0
    for points in trails:
        length = sum(math.dist(p, q) for p, q in zip(points[:-1], points[1:]))
        step = 22.0
        for k in range(int(length / step)):
            along = k * step + 6.0
            for p, q in zip(points[:-1], points[1:]):
                segment = math.dist(p, q)
                if along <= segment:
                    t = along / segment
                    x, y = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
                    dx, dy = (q[0] - p[0]) / segment, (q[1] - p[1]) / segment
                    break
                along -= segment
            side = 4.6 if k % 2 else -4.6
            x, y = x - dy * side, y + dx * side
            turn = math.atan2(dy, dx) + math.pi / 2.0
            cos_t, sin_t = math.cos(turn), math.sin(turn)
            corners = []
            for u, v in ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)):
                ax, ay = (u - 0.5) * 9.0, (0.5 - v) * 15.0
                corners.append((x + ax * cos_t - ay * sin_t, y + ax * sin_t + ay * cos_t, 3.05))
            decal = kit.quad("Print%d" % count, corners, mud)
            decal["floor_decal"] = True
            count += 1
    return kit


def debris():
    """Grit and pebbles kicked to the walls."""
    kit = RP.Kit("Debris", depth=False)
    rng = random.Random(97)
    shape = bmesh.new()
    for cx, cy, count in ((306.0, 370.0, 5), (893.0, 338.0, 4), (1150.0, 886.0, 6), (1031.0, 926.0, 3),
                          (930.0, 902.0, 3), (62.0, 420.0, 3)):
        for _stone in range(count):
            radius = rng.uniform(1.2, 2.8)
            bmesh.ops.create_icosphere(shape, subdivisions=1, radius=1.0, matrix=(
                Matrix.Translation((cx + rng.uniform(-9.0, 9.0), cy + rng.uniform(-6.0, 6.0), 2.4 + radius * 0.3))
                @ Matrix.Diagonal((radius, radius * rng.uniform(0.6, 0.9), radius * rng.uniform(0.4, 0.6), 1.0))))
    kit.shape("Pebbles", shape, ashlar(), uv="box")
    return kit


# ---------------------------------------------------------------- the furnishings


def top_h(obj):
    """The height (screen px up) of an object's highest point."""
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return max(corner.z for corner in corners) * RP.SIN / RP.PX


def window_benches():
    """A bench under each window as a window seat: four turned legs and a
    stretcher, a moulded apron, a velvet cushion, its seat just under the
    stone sill and clear of it."""
    kit = RP.Kit("WindowBenches")
    wood, cloth = oak(), velvet()
    y0, y1 = BENCH_Y
    for index, cx in enumerate(WINDOW_BENCH_X):
        x0, x1 = cx - BENCH_HALF, cx + BENCH_HALF
        part = "Bench%d" % index
        for x in (x0 + 5.0, x1 - 5.0):
            for y in (y0 + 4.0, y1 - 4.0):
                kit.lathe(part + "Leg", x, y, [(0.0, 0.0), (2.6, 0.0), (2.6, 2.0), (1.6, 4.0), (2.2, 9.0), (1.4, 14.0),
                                               (2.0, 19.0), (2.4, 21.0), (2.4, 26.0), (0.0, 26.0)], wood, plan=ROUND,
                          segments=14)
        gh.wood_boxes(kit, part + "Apron", [(x0 + 2.0, x1 - 2.0, y1 - 3.0, y1 - 1.0, 21.0, 26.0),
                                            (x0 + 2.0, x1 - 2.0, y0 + 1.0, y0 + 3.0, 21.0, 26.0)], wood, grain="x",
                      bevel=0.4)
        gh.wood_boxes(kit, part + "Ends", [(x0 + 2.0, x0 + 4.0, y0 + 3.0, y1 - 3.0, 21.0, 26.0),
                                           (x1 - 4.0, x1 - 2.0, y0 + 3.0, y1 - 3.0, 21.0, 26.0)], wood, grain="y",
                      bevel=0.4)
        middle = (y0 + y1) / 2.0
        gh.wood_boxes(kit, part + "Stretcher", [(x0 + 5.0, x1 - 5.0, middle - 1.2, middle + 1.2, 5.0, 7.5)], wood,
                      grain="x", bevel=0.3)
        gh.wood_boxes(kit, part + "Seat", [(x0, x1, y0, y1, 26.0, 28.5)], wood, grain="x", bevel=0.8)
        kit.box(part + "Cushion", x0 + 3.0, x1 - 3.0, y0 + 2.0, y1 - 2.0, 28.5, 32.0, cloth, bevel=1.6, uv="box")
    return kit


def fireside():
    """Two of the hall's chairs drawn up to the hearth and turned in toward
    the fire, a low Gothic table between them with a jug and a goblet."""
    kit = RP.Kit("Fireside")
    wood, cloth = oak(), velvet()
    turn = math.radians(25.0)
    for index, ((x, y), side) in enumerate(zip(FIRESIDE_CHAIRS, (1.0, -1.0))):
        before = set(bpy.data.objects)
        chair(kit, "FiresideChair%d" % index, wood, cloth)
        face_on(made_since(before), x, y, (side * math.sin(turn), -math.cos(turn)), "FiresideChair%d" % index)
    tx, ty = FIRESIDE_TABLE
    table = MODEL.place(kit, "gothic_coffee_table", "gothic_coffee_table", tx, ty, 0.0, scale=0.42, depth=True)
    if table is not None:
        # Its top is a tray inside a raised rim: stand things on the tray.
        top = top_h(table) - 0.8
        jug(kit, "FiresideJug", tx - 8.0, ty - 3.0, top, pewter(), size=0.9)
        MODEL.place(kit, "brass_goblets", "brass_goblet_01", tx + 9.0, ty + 3.0, top, scale=1.0, turn=1.2)
    return kit


def trophy():
    """A heraldic trophy by the east wall, between the wall door and the
    clock: a kite shield hung on an oak post over two swords crossed behind
    it, the post on a stone plinth."""
    kit = RP.Kit("Trophy")
    wood = oak()
    cx, cy = TROPHY
    kit.box("Plinth", cx - 20.0, cx + 20.0, cy - 15.0, cy + 15.0, 0.0, 8.0, ashlar(), bevel=1.0, uv="box")
    gh.wood_boxes(kit, "Post", [(cx - 3.5, cx + 3.5, cy - 3.0, cy + 3.0, 8.0, 108.0)], wood, grain="h", bevel=0.5)
    kit.lathe("PostCap", cx, cy, [(0.0, 108.0), (4.2, 108.0), (4.2, 109.5), (2.6, 111.0), (3.0, 113.5), (0.0, 116.0)],
              wood, plan=ROUND, segments=16)
    # Each sword stands on its pommel; leaned in the shield's plane about its
    # pommel, its middle lands behind the shield's middle.
    middle, half = 62.0, 74.5
    for index, side in enumerate((-1.0, 1.0)):
        lean = math.radians(32.0) * side
        MODEL.place(kit, "antique_estoc", "antique_estoc", cx - half * math.sin(lean),
                    cy + 10.0, middle - half * math.cos(lean) * RP.SIN, tilt=(0.0, lean), depth=True)
    MODEL.group(kit, "kite_shield", cx, cy + 22.0, 16.0, depth=True)
    return kit


def chest():
    """An iron-bound chest in the south-west corner, against the room's
    south edge, its lid shut and its lock toward the room."""
    kit = RP.Kit("Chest")
    MODEL.group(kit, "treasure_chest", *CHEST, 0.0, turn=math.pi, depth=True)
    return kit


def casks():
    """Two wine casks stood against the south wall in the east."""
    kit = RP.Kit("Casks")
    for index, (x, y) in enumerate(CASKS):
        MODEL.group(kit, "wine_barrel_01", x, y, 0.0, turn=0.7 + 1.9 * index, depth=True)
    return kit


def candelabra():
    """Two iron floor candelabra either side of the way in from the main
    door, taller than the detective, three candles each, throwing pools of
    candlelight on the flagstones."""
    kit = RP.Kit("Candelabra")
    iron = hall._cast_iron()
    for index, (x, y) in enumerate(CANDELABRA):
        part = "Candelabrum%d" % index
        for k in range(3):
            angle = math.radians(90.0 + 120.0 * k)
            fx, fy = x + 15.0 * math.cos(angle), y + 15.0 * math.sin(angle) / RP.STRETCH
            kit.rod(part + "Foot%d" % k, (x, y, 9.0), (fx, fy, 0.8), 1.5, iron)
            kit.ball(part + "Toe%d" % k, fx, fy, 1.0, 2.2, iron, plan=0.8)
        kit.lathe(part + "Shaft", x, y, [(0.0, 7.0), (3.6, 7.0), (4.0, 9.5), (2.0, 13.0), (1.8, 30.0), (2.8, 32.0),
                                         (1.8, 34.0), (1.7, 57.0), (3.4, 60.5), (1.8, 64.0), (1.6, 97.0),
                                         (0.0, 97.0)], iron, plan=ROUND, segments=16)
        kit.lathe(part + "Pan", x, y, [(0.0, 94.0), (9.0, 95.5), (10.0, 97.0), (9.2, 97.3), (0.0, 96.2)], iron,
                  plan=ROUND, segments=24)
        for k, (dx, lift) in enumerate(((-11.0, 0.0), (0.0, 6.0), (11.0, 0.0))):
            if dx:
                kit.rod(part + "Arm%d" % k, (x, y, 97.0), (x + dx, y, 100.0 + lift), 0.8, iron)
            kit.lathe(part + "Cup%d" % k, x + dx, y, [(0.0, 100.0 + lift), (2.8, 100.0 + lift), (3.2, 103.0 + lift),
                                                      (0.0, 102.4 + lift)], iron, plan=ROUND, segments=14)
            kit.candle(part + "Candle%d" % k, x + dx, y, 102.4 + lift, height=12.0, radius=2.0, power=2.6)
        # The three flames' light on the floor round the stand, as the
        # room's other lamps throw theirs.
        kit.light(part + "Pool", x, y + 2.0, 112.0, CANDLE, 16.0, radius=0.12)
    return kit


# ---------------------------------------------------------------- the room


def moon_sky():
    """The Hall's moonlight (hall_prototype.add_sun: its colour, strength and
    softness), from the south-south-west and high, as in the other rooms."""
    data = bpy.data.lights.new("DiningMoonSky", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sun = RP._link(bpy.data.objects.new("DiningMoonSky", data))
    sun.rotation_euler = Vector((0.12, 0.38, -0.92)).normalized().to_track_quat("-Z", "Y").to_euler()


def grade(scene):
    """The room's exposure and white balance, set after the shared Cycles
    setup: as bright and as warm as the painted hall (by the room standard,
    mean luminance and warmth within about 15 % of its painting's)."""
    scene.view_settings.exposure = DINING_EXPOSURE
    scene.view_settings.use_white_balance = True
    scene.view_settings.white_balance_temperature = DINING_WHITE_BALANCE


def build(rp, layout):
    global RP, MODEL
    RP = rp
    gh.RP = rp
    wake.RP = rp
    MODEL = gh.Models()
    gh.MODEL = MODEL
    shell_materials = {
        "floor": joints(),
        "wall": rp.textured("DiningWall", "castle_wall_slates", 1.5, 0.31, (0.8, 0.68, 0.56), ao=0.3),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if rp.TEXTURES.available()
                else rp.textured("DiningCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if rp.TEXTURES.available()
                else rp.textured("DiningLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("DiningReveal", "castle_wall_slates", 1.5, 0.46, (0.8, 0.7, 0.58), ao=0.2),
    }
    DiningShell(SPEC, shell_materials).build()
    windows()
    curtains()
    portraits()
    sconces()
    hearthside()
    serving_table()
    dining_table = table()
    chairs(dining_table)
    rugs()
    paving()
    boot_prints()
    debris()
    window_benches()
    fireside()
    trophy()
    chest()
    casks()
    candelabra()
    door_surround()
    moon_sky()
    props = {
        "Fireplace": fireplace(),
        "WallDoor": wall_door(),
        "DiningTable": dining_table,
        "ChandelierSprite": chandelier(),
        "GrandfatherClock": clock(),
        "Sideboard": sideboard(),
        "Cabinet": dresser(),
        "MainDoor": main_door(),
    }
    print("DINING HALL built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    roots = {name: "Worldsort/" + name for name in props}
    roots["ChandelierSprite"] = "ChandelierSprite"
    # Every prop but the chandelier stays in the room render and its depth
    # map: the player walks round the table and up to the rest, and is
    # hidden by each exactly where it stands in front of them. The
    # chandelier hangs over everyone, drawn above them as the game draws it.
    return {"props": props, "roots": roots, "in_room": [name for name in props if name != "ChandelierSprite"],
            "overhead": ["ChandelierSprite"], "collision": footprints()}


def footprints():
    """The collision the real-size furniture needs in place of the painted
    footprints: the table with its chairs round it, the clock, and the
    sideboard with its drawer pulled out; the north-east corner's wall notch
    drawn back to the serving table's real depth; and footprints for the
    furnishings the painting does not have (under RoomCollisions, freed when
    the painted room comes back)."""
    def rect(x0, x1, y0, y1):
        return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]

    x0, x1, y0, y1 = TABLE
    cx, face = (CLOCK[0] + CLOCK[1]) / 2.0, CLOCK[3]
    half = (CLOCK[1] - CLOCK[0]) / 2.0 * CLOCK_SCALE + 1.0
    s0, s1, t0, t1 = SIDEBOARD
    span = (t1 - t0 - 28.0) / 3.0
    drawer = (t0 + 8.0 + span + 6.0, t0 + 8.0 + 2.0 * span + 6.0)
    serving = SERVING[3]
    tx, ty = TROPHY
    furnishings = {
        "RoomCollisions/HDFireside": rect(62.0, 286.0, 400.0, 497.0),
        "RoomCollisions/HDTrophy": rect(tx - 44.0, tx + 44.0, ty - 16.0, ty + 28.0),
        "RoomCollisions/HDChest": rect(CHEST[0] - 51.0, CHEST[0] + 51.0, CHEST[1] - 22.0, CHEST[1] + 22.0),
        "RoomCollisions/HDCasks": rect(CASKS[0][0] - 39.0, CASKS[1][0] + 39.0, CASKS[0][1] - 31.0,
                                       CASKS[0][1] + 31.0),
    }
    for index, cx in enumerate(WINDOW_BENCH_X):
        furnishings["RoomCollisions/HDWindowBench%d" % index] = rect(cx - BENCH_HALF - 1.0, cx + BENCH_HALF + 1.0,
                                                                     BENCH_Y[0] - 1.0, BENCH_Y[1] + 1.0)
    for index, (x, y) in enumerate(CANDELABRA):
        furnishings["RoomCollisions/HDCandelabrum%d" % index] = rect(x - 17.0, x + 17.0, y - 13.0, y + 13.0)
    return furnishings | {
        # The end chairs' backs reach 95 px past the table's ends, the side
        # chairs' 41 plan px past their seats' fronts.
        "Worldsort/DiningTable/FurnitureCollision/FurnitureShape": rect(x0 - 97.0, x1 + 98.0, y0 - 35.0, y1 + 60.0),
        "Worldsort/GrandfatherClock/FurnitureCollision/FurnitureShape": rect(
            cx - half, cx + half, face - (face - CLOCK[2]) * CLOCK_SCALE - 2.0, face + 1.0),
        # The top's overhang, within the walk-up rule's 7.5 px of its foot.
        "Worldsort/Sideboard/FurnitureCollision/FurnitureShape": rect(s0 - 4.0, s1 + 3.0, t0 - 4.0, t1 + 4.0),
        "Worldsort/Sideboard/FurnitureCollision/HDOpenDrawer": rect(s0 - 36.0, s0, drawer[0] - 2.0, drawer[1] + 2.0),
        "RoomCollisions/RightWall": [[1398.0, 20.0], [1389.0, 206.0], [1300.0, 205.0], [1300.0, serving + 2.0],
                                     [1394.0, serving + 4.0], [1394.0, 356.0], [1418.0, 640.0], [1417.0, 980.0],
                                     [1417.0, 1000.0], [1436.0, 997.0], [1434.0, 225.0], [1418.0, 10.0]],
    }
