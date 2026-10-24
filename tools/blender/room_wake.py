"""The Wake Room, the guest chamber the game opens in, for the Blender room
prototype. tools/blender/room_prototype.py imports it as room_wake and calls
build() on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). Everything stands
where the painted room has it and on the floor the collision blocks:

  west    the bed (Props/Bed), its nightstand, two candle sconces
  north   the bookshelf (Props/Bookshelf), the moonlit window seat with the
          candle note, the study desk (Props/Desk) with Mrs. Lin's candles
          under glass and the maps pinned above it
  east    the Wake gate (Props/Door): the Hall's own portal, seen from inside,
          between two violet crystal lamps
  south   a side table with an oil lamp, a travelling trunk, the alchemy
          bench and the crates with the armillary sphere
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, bvhtree

import hall_prototype as hall

RP = None
RNG = random.Random(2207)

BACK_Y = 222.0
WALL_H = 184.0
WINDOW_X = (456.0, 546.0)
WINDOW_SILL = 24.0
WINDOW_SPRING = 115.0
WINDOW_GLASS_Y = BACK_Y - 30.0
SEAT_H = 25.0
# The Wake gate: the Hall's portal at 3.25 times its Hall size (the room shows
# its figures about 2.6 times as large; the gate is made grander), standing a
# little proud of the east wall so its leaves sit in front of the wall's face.
DOOR_Y = 465.0
DOOR_SCALE = 3.25
DOOR_PROUD = 3.0
CRYSTAL_Y = (372.0, 562.0)
VIOLET = (0.62, 0.36, 1.0)
# A lathe's plan squash for a true circle (the plan is foreshortened by the
# camera's tilt), so turned wood and brass are round in 3D as well as on screen.
ROUND = math.cos(math.radians(hall.ALPHA_DEGREES))
CANDLE = (1.0, 0.6, 0.28)
MOON = (0.55, 0.68, 1.0)


def window_outline():
    x0, x1 = WINDOW_X
    radius = (x1 - x0) / 2.0
    centre = (x0 + x1) / 2.0
    arc = [(centre + radius * math.cos(math.radians(angle)), WINDOW_SPRING + radius * math.sin(math.radians(angle)))
           for angle in range(0, 181, 9)]
    return [(x0, WINDOW_SILL), (x1, WINDOW_SILL)] + arc


SPEC = {
    "back": {"y": BACK_Y, "base": (149.0, 876.0), "top": (52.0, 950.0), "height": WALL_H,
             "openings": [{"outline": window_outline()}]},
    "left": {"base": ((149.0, BACK_Y), (118.0, 716.0)), "near": 924.0},
    "right": {"base": ((876.0, BACK_Y), (909.0, 716.0)), "near": 924.0},
    "south": {"y": 716.0, "height": 22.0, "depth": 70.0},
    "floor": {"x": (-60.0, 1084.0), "y": (150.0, 800.0)},
    "cap": 40.0,
}


# ---------------------------------------------------------------- materials


def oak():
    """Worn, waxed oak with a figured grain, warm as the painted room's
    furniture: the bed, the bookcase, the desk and the tables."""
    return RP.textured("WakeOak", "wood_table_worn", 0.42, 1.0, (0.96, 0.8, 0.64), saturation=0.92, ao=0.25)


def planks():
    """Rough boards for the crates and the travelling trunk."""
    return RP.textured("WakePlanks", "wood_cabinet_worn_long", 0.6, 0.8, (0.92, 0.76, 0.62), saturation=0.9,
                       ao=0.25)


def _sheen(material, tint, weight=1.0, roughness=0.35):
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Sheen Weight"].default_value = weight
            node.inputs["Sheen Roughness"].default_value = roughness
            node.inputs["Sheen Tint"].default_value = tint + (1.0,)
    return material


def velvet():
    material = RP.textured("WakeVelvet", "velour_velvet", 0.3, 0.95, (0.38, 0.15, 0.6), saturation=0.0, ao=0.3)
    # Velvet's pile catches light at grazing angles.
    return _sheen(material, (0.75, 0.55, 1.0))


def damask():
    """The bed's coverlet: plum silk damask, its woven pattern catching the light."""
    material = RP.textured("WakeDamask", "floral_jacquard", 0.75, 1.55, (0.46, 0.2, 0.64), saturation=0.0, ao=0.35)
    return _sheen(material, (0.85, 0.7, 1.0), weight=0.7, roughness=0.3)


def sheet_linen():
    return RP.textured("WakeSheet", "cotton_jersey", 0.25, 1.05, (0.92, 0.9, 0.84), saturation=0.1, ao=0.35)


def throw_cloth():
    return RP.textured("WakeThrow", "cotton_jersey", 0.25, 1.0, (0.88, 0.78, 0.58), saturation=0.2, ao=0.35)


def gold_weave():
    return RP.textured("WakeGoldWeave", "cotton_jersey", 0.15, 0.9, (0.66, 0.46, 0.16), saturation=0.3, ao=0.3)


# Bindings of an old library: oxblood, bottle green, navy, tan, brown, black,
# plum and ochre, all darkened with age.
BOOK_COLOURS = ((0.25, 0.05, 0.045), (0.05, 0.12, 0.07), (0.05, 0.07, 0.16), (0.36, 0.22, 0.1),
                (0.15, 0.085, 0.045), (0.04, 0.035, 0.035), (0.17, 0.06, 0.14), (0.4, 0.27, 0.09))


def book_leather(color=None):
    """Aged leather: the photo's grain and creases, coloured either by
    `color` or, for shelved books, each book its own colour from BOOK_COLOURS."""
    def build(nodes, links):
        if RP.TEXTURES is None or not RP.TEXTURES.available():
            hall._principled(nodes, links, color or (0.15, 0.08, 0.05), roughness=0.55)
            return
        maps = RP.TEXTURES.sample(nodes, links, "fabric_leather_02", repeat=0.12)
        grain = hall._grade(nodes, links, maps["diff"], 1.9, (1.0, 1.0, 1.0), saturation=0.0)
        if color is None:
            info = nodes.new("ShaderNodeObjectInfo")
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            elements = ramp.color_ramp.elements
            while len(elements) < len(BOOK_COLOURS):
                elements.new(0.5)
            for index, (element, colour) in enumerate(zip(elements, BOOK_COLOURS)):
                element.position = index / len(BOOK_COLOURS)
                element.color = colour + (1.0,)
            links.new(info.outputs["Random"], ramp.inputs["Fac"])
            tint = ramp.outputs["Color"]
        else:
            tint = color
        shaded = hall._mix(nodes, links, 1.0, grain, tint, blend="MULTIPLY")
        hall._principled(nodes, links, shaded, roughness=maps["rough"], normal=maps["normal"])
    name = "WakeBookLeather" if color is None else "WakeBookLeather_%d_%d_%d" % tuple(int(c * 100) for c in color)
    return hall._material(name, build)


def gilt():
    """Gold leaf on a spine: brighter and smoother than the brass fittings."""
    return hall._prop_metal("WakeGilt", (0.74, 0.55, 0.22), 0.28)


def linen():
    return RP.textured("WakeLinen", "cotton_jersey", 0.25, 1.0, (0.9, 0.84, 0.74), saturation=0.15, ao=0.3)


def stone():
    return RP.textured("WakeStone", "large_grey_tiles", 0.5, 0.62, (0.72, 0.68, 0.8), saturation=0.55, ao=0.15)


def jar_glass():
    """Thin blown glass: a bell jar or a flask wall, barely bending what is behind."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.9, 0.95, 0.93), roughness=0.03)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.06
    return hall._material("WakeJarGlass", build)


def parchment():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        stain = hall._noise(nodes, links, coords.outputs["Object"], scale=14.0, detail=5.0)
        hall._principled(nodes, links, hall._mix(nodes, links, stain, (0.46, 0.37, 0.23), (0.7, 0.6, 0.42)),
                         roughness=0.86)
    return hall._material("WakeParchment", build)


def writing(name="WakeWriting", lines=10.0, gutter=False):
    """Parchment written in brown ink, UVs 0..1 across the sheet."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        stain = hall._noise(nodes, links, coords.outputs["UV"], scale=5.0, detail=5.0)
        words = hall._noise(nodes, links, coords.outputs["UV"], scale=34.0, detail=1.0)
        row = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", v, lines)), 0.5))
        ink = op("MULTIPLY", op("LESS_THAN", row, 0.13), op("GREATER_THAN", words, 0.44))
        if gutter:
            page = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", u, 2.0)), 0.5))
            inside = op("MULTIPLY", op("LESS_THAN", page, 0.38), op.between(v, 0.1, 0.9))
        else:
            inside = op("MULTIPLY", op.between(u, 0.12, 0.88), op.between(v, 0.12, 0.9))
        ink = op("MULTIPLY", ink, inside)
        color = hall._mix(nodes, links, stain, (0.5, 0.41, 0.26), (0.74, 0.64, 0.46))
        if gutter:
            fold = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", u, 0.5)), 0.04)
            color = hall._mix(nodes, links, op("MULTIPLY", fold, 0.55), color, (0.18, 0.12, 0.07))
        color = hall._mix(nodes, links, ink, color, (0.12, 0.07, 0.05))
        hall._principled(nodes, links, color, roughness=0.86)
    return hall._material(name, build)


def leather(name, color):
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=90.0, detail=4.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, color, tuple(c * 0.65 for c in color)),
                         roughness=0.55)
    return hall._material(name, build)


def window_glass():
    """Leaded panes lit by the night sky, a rose of lead in the arch's head.
    UVs are the opening's own (x, h) in px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        centre = (WINDOW_X[0] + WINDOW_X[1]) / 2.0
        du = op("SUBTRACT", u, centre)
        dv = op("SUBTRACT", v, WINDOW_SPRING + 6.0)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        rose = op("LESS_THAN", radius, 30.0)
        turn = op("DIVIDE", op("ARCTAN2", dv, du), 2.0 * math.pi / 12.0)
        spokes = op("MULTIPLY", op("GREATER_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", turn), 0.5)), 0.43),
                    op("GREATER_THAN", radius, 9.0))
        rose_lead = op("MAXIMUM", op("MAXIMUM", op.between(radius, 28.5, 31.0), op.between(radius, 8.0, 10.0)), spokes)
        column = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", du, 10.0)), 0.5))
        row = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", v, 12.5)), 0.5))
        lattice = op("MAXIMUM", op("GREATER_THAN", column, 0.43), op("GREATER_THAN", row, 0.44))
        lead = hall._mix(nodes, links, rose, lattice, rose_lead)
        pane = nodes.new("ShaderNodeTexVoronoi")
        pane.inputs["Scale"].default_value = 0.11
        links.new(coords.outputs["UV"], pane.inputs["Vector"])
        # The moon stands to the upper east: the panes there are brightest.
        sky = op("ADD", 0.45, op("MULTIPLY", op("ADD", op("DIVIDE", v, 160.0), op("DIVIDE", du, 120.0)), 0.6))
        tint = hall._mix(nodes, links, pane.outputs["Distance"], (0.16, 0.3, 0.62), (0.3, 0.52, 0.86))
        glass = op("MULTIPLY", sky, op("SUBTRACT", 1.0, lead))
        hall._principled(nodes, links, (0.02, 0.02, 0.03), roughness=0.25, emission=tint,
                         emission_strength=op("MULTIPLY", glass, 1.3))
    return hall._material("WakeWindowGlass", build)


def rug_material(length, width):
    """A purple runner: gold border, a lozenge medallion, a worn middle.
    UVs are px: u along its length, v across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        to_end = op("MINIMUM", u, op("SUBTRACT", length, u))
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        border = op("MAXIMUM", op("LESS_THAN", to_side, 6.5), op("LESS_THAN", to_end, 9.0))
        stripe = op("MAXIMUM", op.between(to_side, 8.0, 9.5),
                    op("MULTIPLY", op.between(to_end, 10.5, 12.0), op("GREATER_THAN", to_side, 8.0)))
        across = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0 - 11.0)
        along = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", u, length / 2.0)), length / 2.0 - 14.0)
        lozenge = op("ADD", across, along)
        medallion = op("MAXIMUM", op.between(lozenge, 0.5, 0.56), op("LESS_THAN", lozenge, 0.16))
        lattice = op("LESS_THAN", op("ADD",
                                     op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", u, 12.0)), 0.5)),
                                     op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", v, 12.0)), 0.5))), 0.1)
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=0.7, detail=6.0)
        wear = hall._ramp(nodes, links, op("ADD", weave, op("MULTIPLY", op("SUBTRACT", 0.45, across), 0.4)), 0.6, 0.95)
        field = hall._mix(nodes, links, op("MULTIPLY", lattice, op("GREATER_THAN", lozenge, 0.56)),
                          (0.09, 0.03, 0.14), (0.16, 0.06, 0.22))
        color = hall._mix(nodes, links, op("MINIMUM", op("ADD", medallion, op("MAXIMUM", border, 0.0)), 1.0),
                          field, (0.2, 0.07, 0.27))
        color = hall._mix(nodes, links, op("MAXIMUM", stripe, op("MULTIPLY", border, op("LESS_THAN", to_side, 2.5))),
                          color, (0.42, 0.3, 0.1))
        color = hall._mix(nodes, links, op("MULTIPLY", wear, 0.4), color, (0.3, 0.26, 0.24))
        fringe = op("LESS_THAN", to_end, 3.0)
        threads = op("LESS_THAN", op("FRACT", op("DIVIDE", v, 1.7)), 0.55)
        color = hall._mix(nodes, links, fringe, color, (0.5, 0.44, 0.34))
        roughness, normal = 0.95, None
        if RP.TEXTURES is not None and RP.TEXTURES.available():
            # The pile: a carpet photo's fibres shade the woven pattern.
            pile = RP.TEXTURES.sample(nodes, links, "dirty_carpet", repeat=40.0)
            fibres = hall._grade(nodes, links, pile["diff"], 2.6, (1.0, 1.0, 1.0), saturation=0.0)
            color = hall._mix(nodes, links, 0.55, color, hall._mix(nodes, links, 1.0, color, fibres,
                                                                    blend="MULTIPLY"))
            roughness, normal = pile["rough"], pile["normal"]
        shader = hall._principled(nodes, links, color, roughness=roughness, normal=normal)
        hall._alpha_cut(nodes, links, shader, op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0, threads))))
    return hall._material("WakeRug", build)


def compass_material(radius):
    """A brass compass rose let into the floor. UVs are px from its centre,
    v north; only the brass and the star's darker stone are drawn."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        r = op("DIVIDE", op("SQRT", op("ADD", op("MULTIPLY", u, u), op("MULTIPLY", v, v))), radius)
        theta = op("ARCTAN2", v, u)
        sector = op("DIVIDE", theta, math.pi / 4.0)
        nearest = op("FLOOR", op("ADD", sector, 0.5))
        offset = op("SUBTRACT", sector, nearest)
        cardinal = op("LESS_THAN", op("FRACT", op("DIVIDE", nearest, 2.0)), 0.25)
        tip = op("ADD", 0.48, op("MULTIPLY", cardinal, 0.4))
        edge = op("ADD", 0.11, op("MULTIPLY", op("SUBTRACT", tip, 0.11),
                                  op("SUBTRACT", 1.0, op("MULTIPLY", op("ABSOLUTE", offset), 2.0))))
        star = op("LESS_THAN", r, edge)
        outline = op("MULTIPLY", star, op("GREATER_THAN", r, op("SUBTRACT", edge, 0.016)))
        spine = op("MULTIPLY", star, op("LESS_THAN", op("ABSOLUTE", offset), op("DIVIDE", 0.012, op("MAXIMUM", r, 0.05))))
        rings = op("MAXIMUM", op("MAXIMUM", op.between(r, 0.955, 0.985), op.between(r, 0.9, 0.913)),
                   op("MAXIMUM", op.between(r, 0.6, 0.613), op.between(r, 0.05, 0.075)))
        ticks = op("MULTIPLY", op.between(r, 0.913, 0.955),
                   op("GREATER_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", theta, math.pi / 18.0)),
                                                         0.5)), 0.42))
        brass = op("MINIMUM", op("ADD", op("ADD", rings, ticks), op("ADD", outline, spine)), 1.0)
        light_half = op("GREATER_THAN", offset, 0.0)
        shade = op("MULTIPLY", star, op("ADD", 0.5, op("MULTIPLY", light_half, 0.25)))
        stone_color = hall._mix(nodes, links, light_half, (0.035, 0.03, 0.045), (0.09, 0.08, 0.1))
        color = hall._mix(nodes, links, brass, stone_color, (0.6, 0.43, 0.18))
        shader = hall._principled(nodes, links, color, roughness=op("SUBTRACT", 0.82, op("MULTIPLY", brass, 0.5)))
        links.new(brass, shader.inputs["Metallic"])
        hall._alpha_cut(nodes, links, shader, op("MAXIMUM", brass, shade))
    return hall._material("WakeCompassRose", build)


# ---------------------------------------------------------------- small things


def closed_book(kit, part, x0, x1, y0, y1, h, thick, color):
    """A book lying shut, spine to the west: its boards and spine in one
    piece, the page block between them showing on three sides."""
    cover = book_leather(color)
    board = min(0.6, thick * 0.18)
    kit.blocks(part + "Cover", [(x0, x1, y0, y1, h, h + board), (x0, x1, y0, y1, h + thick - board, h + thick),
                                (x0, x0 + 1.0, y0, y1, h, h + thick)], cover, bevel=0.25)
    kit.box(part + "Pages", x0 + 0.8, x1 - 0.35, y0 + 0.5, y1 - 0.5, h + board, h + thick - board, parchment(),
            bevel=0.15)


def shelf_book(kit, x0, width, front, h0, tall, deep, rng, turn=0.0):
    """A book shelved spine out, its spine `front` px south: two boards and a
    rounded spine in one piece (so one colour), the cream page block showing
    on top between the boards, and gilt bands and a label on the spine.
    `turn` leans it on its bottom-west edge, top to the west, in degrees."""
    board = 0.45
    back = front - deep
    made = [kit.blocks("Book", [(x0, x0 + board, back, front - 0.6, h0, h0 + tall),
                                (x0 + width - board, x0 + width, back, front - 0.6, h0, h0 + tall),
                                (x0, x0 + width, front - 1.1, front, h0, h0 + tall)], book_leather(), bevel=0.32),
            kit.box("BookPages", x0 + board, x0 + width - board, back + 0.25, front - 1.0, h0 + 0.3, h0 + tall - 0.55,
                    parchment(), bevel=0.12)]
    bands = []
    for fraction in (0.14, 0.86) if rng.random() < 0.7 else (0.14, 0.32, 0.86):
        middle = h0 + tall * fraction
        bands.append((x0 + 0.15, x0 + width - 0.15, front - 0.4, front + 0.3, middle - 0.45, middle + 0.45))
    if rng.random() < 0.6:
        label = h0 + tall * rng.uniform(0.55, 0.66)
        bands.append((x0 + 0.7, x0 + width - 0.7, front - 0.4, front + 0.2, label - 1.8, label + 1.8))
    made.append(kit.blocks("BookGilt", bands, gilt(), bevel=0.1))
    if turn:
        for obj in made:
            lean(obj, Vector((x0, front - deep / 2.0, h0)), -math.radians(turn))
    return made


def shelf_run(kit, x0, x1, front, h0, h1, rng, lean_end=True):
    """Books standing from x0 to x1 on a shelf h0..h1, of every height and
    depth, a few set back; the last leaning on the rest if there is room."""
    x = x0
    while x < x1 - 3.0:
        width = rng.uniform(2.8, 6.4)
        if x + width > x1:
            break
        tall = (h1 - h0) * rng.uniform(0.66, 0.94)
        deep = rng.uniform(15.0, 21.0)
        shelf_book(kit, x, width, front - rng.uniform(0.6, 3.2), h0, tall, deep, rng)
        x += width + rng.uniform(0.05, 0.45)
    if lean_end and x < x1 - 8.0:
        turn = rng.uniform(14.0, 22.0)
        tall = (h1 - h0) * rng.uniform(0.7, 0.84)
        width = rng.uniform(3.5, 5.2)
        # Its top rests on the last book standing.
        foot = x + tall / RP.SIN * math.sin(math.radians(turn)) + 0.2
        if foot + width < x1:
            shelf_book(kit, foot, width, front - 1.5, h0, tall, rng.uniform(15.0, 19.0), rng, turn=turn)
            x = foot + width
    return x


def lean(obj, pivot, angle):
    """Turns a kit-built object (its mesh in Blender space) about the plan
    axis through `pivot` (game px), as a book leans along a shelf."""
    centre = RP.world(*pivot)
    turn = Matrix.Translation(centre) @ Matrix.Rotation(angle, 4, "Y") @ Matrix.Translation(-centre)
    obj.data.transform(turn)


def paper(kit, part, cx, cy, h, width, depth, angle, material):
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    corners = []
    for dx, dy in ((-1.0, 1.0), (1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)):
        x, y = dx * width / 2.0, dy * depth / 2.0
        corners.append((cx + x * cos_a - y * sin_a, cy + x * sin_a + y * cos_a, h))
    return kit.quad(part, corners, material)


def candlestick(kit, part, x, y, h, wax_height=12.0, radius=2.4, power=0.6, stick=10.0):
    brass = hall._brass()
    top = h + stick
    kit.lathe(part + "Stick", x, y, [(0.0, h), (radius * 2.6, h), (radius * 2.6, h + 1.2), (radius * 1.2, h + 2.6),
                                     (radius * 0.75, h + stick * 0.55), (radius * 0.95, h + stick * 0.65),
                                     (radius * 0.7, top - 1.6), (radius * 1.6, top - 0.8), (radius * 1.6, top),
                                     (0.0, top)], brass)
    kit.candle(part, x, y, top, height=wax_height, radius=radius, power=power)


def crystal(kit, part, x, y, h, radius, height, material, tilt=0.0, turn=0.0):
    obj = kit.lathe(part, x, y, [(0.0, h - height * 0.25), (radius, h), (radius * 0.85, h + height * 0.55),
                                 (0.0, h + height)], material, plan=0.62, segments=6, smooth=False)
    obj.data.transform(Matrix.Translation(RP.world(x, y, h)) @ Matrix.Rotation(turn, 4, "Z")
                       @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Translation(-RP.world(x, y, h)))
    return obj


def flask(kit, part, x, y, h, kind, liquid_color, size=1.0):
    """A glass vessel with coloured contents: round, conical or a tall bottle."""
    glass = jar_glass()
    liquid = hall._liquid("WakeLiquid%d%d%d" % tuple(int(c * 9) for c in liquid_color), liquid_color, 0.45)
    s = size
    if kind == "round":
        body = [(0.0, h), (3.0 * s, h + 0.4 * s), (6.2 * s, h + 3.5 * s), (7.0 * s, h + 7.0 * s),
                (6.2 * s, h + 10.5 * s), (3.4 * s, h + 13.2 * s), (2.0 * s, h + 14.0 * s), (2.0 * s, h + 22.0 * s),
                (2.5 * s, h + 23.0 * s)]
        fill = [(0.0, h + 0.5 * s), (2.8 * s, h + 0.9 * s), (5.8 * s, h + 3.8 * s), (6.5 * s, h + 7.0 * s),
                (0.0, h + 7.0 * s)]
    elif kind == "cone":
        body = [(0.0, h), (7.0 * s, h), (7.4 * s, h + 1.2 * s), (2.4 * s, h + 15.0 * s), (2.4 * s, h + 21.0 * s),
                (2.9 * s, h + 22.0 * s)]
        fill = [(0.0, h + 0.5 * s), (6.6 * s, h + 0.5 * s), (6.8 * s, h + 1.4 * s), (4.6 * s, h + 7.8 * s),
                (0.0, h + 7.8 * s)]
    else:
        body = [(0.0, h), (3.6 * s, h), (3.8 * s, h + 1.0 * s), (3.8 * s, h + 15.0 * s), (2.0 * s, h + 18.5 * s),
                (1.6 * s, h + 24.0 * s), (2.0 * s, h + 25.0 * s)]
        fill = [(0.0, h + 0.5 * s), (3.4 * s, h + 0.5 * s), (3.4 * s, h + 11.0 * s), (0.0, h + 11.0 * s)]
    kit.lathe(part + "Liquid", x, y, fill, liquid, plan=0.58)
    vessel = kit.lathe(part + "Glass", x, y, body, glass, plan=0.6, close=False)
    vessel.visible_shadow = False
    return vessel


# ---------------------------------------------------------------- the shell's dressing


def floor_dressing():
    kit = RP.Kit("Floor", depth=False)
    x0, x1, y0, y1 = 254.0, 322.0, 362.0, 548.0
    length, width = y1 - y0, x1 - x0
    kit.box("RugUnder", x0 + 0.5, x1 - 0.5, y0 + 2.0, y1 - 2.0, 0.0, 0.7,
            hall._cloth("WakeRugBacking", (0.07, 0.03, 0.09)), bevel=0.0)
    kit.quad("Rug", [(x0, y1, 0.8), (x1, y1, 0.8), (x1, y0, 0.8), (x0, y0, 0.8)], rug_material(length, width),
             uvs=((length, 0.0), (length, width), (0.0, width), (0.0, 0.0)))
    cx, cy, radius = 506.0, 470.0, 104.0
    reach = radius + 4.0
    kit.quad("Compass", [(cx - reach, cy + reach, 0.15), (cx + reach, cy + reach, 0.15),
                         (cx + reach, cy - reach, 0.15), (cx - reach, cy - reach, 0.15)], compass_material(radius),
             uvs=((-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)))
    return kit


def back_wall_dressing():
    kit = RP.Kit("BackWall")
    face = BACK_Y + 0.6
    brass, walnut = hall._brass(), oak()
    # The castle's banner over the nightstand.
    x0, x1, low, high = 162.0, 228.0, 74.0, 170.0
    kit.quad("Banner", [(x0, face + 0.6, low), (x1, face + 0.6, low), (x1, face + 0.6, high), (x0, face + 0.6, high)],
             hall.material_banner("WakeBanner", (0.2, 0.06, 0.34), (high - low) / (x1 - x0)))
    kit.rod("BannerRod", (x0 - 5.0, face + 2.4, high + 1.6), (x1 + 5.0, face + 2.4, high + 1.6), 1.1, brass)
    for x in (x0 - 5.6, x1 + 5.6):
        kit.ball("BannerFinial", x, face + 2.4, high + 1.6, 1.8, brass)
    # Mrs. Lin's charts over the desk: a map, two framed plates, notes.
    kit.quad("Map", [(662.0, face + 0.4, 70.0), (768.0, face + 0.4, 70.0), (768.0, face + 0.4, 138.0),
                     (662.0, face + 0.4, 138.0)], hall.material_map())
    for x, h in ((666.0, 134.0), (764.0, 134.0), (666.0, 74.0), (764.0, 74.0)):
        kit.ball("Tack", x, face + 1.2, h, 1.3, brass)
    plates = ((606.0, 648.0, 102.0, 140.0, hall.material_blueprint()),
              (606.0, 648.0, 62.0, 96.0, hall.material_map()),
              (806.0, 860.0, 96.0, 138.0, hall.material_portrait("WakePortrait", (0.04, 0.05, 0.1))))
    for index, (left, right, low, high, material) in enumerate(plates):
        kit.quad("Plate%d" % index, [(left, face + 0.8, low), (right, face + 0.8, low), (right, face + 0.8, high),
                                     (left, face + 0.8, high)], material)
        bar = 2.6
        for part, (a, b, c, d) in (("Top", (left - bar, right + bar, high, high + bar)),
                                   ("Bottom", (left - bar, right + bar, low - bar, low)),
                                   ("Left", (left - bar, left, low, high)), ("Right", (right, right + bar, low, high))):
            kit.box("Frame%d%s" % (index, part), a, b, face, face + 2.2, c, d, walnut, bevel=0.5, uv="box")
    note = writing("WakeNote", lines=7.0)
    for index, (x, h, angle) in enumerate(((784.0, 120.0, 0.08), (790.0, 88.0, -0.1), (776.0, 72.0, 0.05))):
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        corners = [(x + dx * cos_a - dh * sin_a, face + 1.0 + index * 0.2, h + dx * sin_a + dh * cos_a)
                   for dx, dh in ((-9.0, -12.0), (9.0, -12.0), (9.0, 12.0), (-9.0, 12.0))]
        kit.quad("Note%d" % index, corners, note)
        kit.ball("NotePin%d" % index, x, face + 2.0 + index * 0.2, h + 9.0, 1.0, brass)
    return kit


def window():
    """The arched window: leaded glass in the reveal, a stone mullion, the seat
    below it with two candles and the candle note, and the moon behind."""
    kit = RP.Kit("Window")
    outline = window_outline()
    glass = RP.polygon_mesh("WakeWindowGlass", outline, [], lambda u, v: (u, WINDOW_GLASS_Y, v), window_glass(),
                            uv_of=lambda u, v: (u, v))
    glass.visible_shadow = False
    kit.keep(glass)
    rock = stone()
    centre = (WINDOW_X[0] + WINDOW_X[1]) / 2.0
    kit.box("Mullion", centre - 2.4, centre + 2.4, WINDOW_GLASS_Y - 3.0, WINDOW_GLASS_Y + 3.0, WINDOW_SILL,
            WINDOW_SPRING - 22.0, rock, bevel=0.6, uv="box_up")
    kit.box("Transom", WINDOW_X[0], WINDOW_X[1], WINDOW_GLASS_Y - 2.5, WINDOW_GLASS_Y + 2.5, 66.0, 70.0, rock,
            bevel=0.5, uv="box")
    kit.ring("Rose", (centre, WINDOW_GLASS_Y + 1.5, WINDOW_SPRING + 6.0), (0.0, 1.0, 0.0), 30.0, 1.8, rock,
             segments=48, sides=8)
    # The window seat and its sill run on into the room.
    kit.box("Seat", 438.0, 564.0, BACK_Y - 1.0, 234.0, 0.0, SEAT_H - 2.5, rock, bevel=0.6, uv="box")
    kit.box("SeatSlab", 436.0, 566.0, WINDOW_GLASS_Y + 3.0, 236.0, SEAT_H - 2.5, SEAT_H, rock, bevel=0.7, uv="box")
    for index, (x, y, tall) in enumerate(((474.0, 229.0, 15.0), (492.0, 227.5, 10.0))):
        kit.lathe("CandleDish%d" % index, x, y, [(0.0, SEAT_H), (5.4, SEAT_H), (5.8, SEAT_H + 1.2),
                                                 (5.0, SEAT_H + 1.6), (0.0, SEAT_H + 1.6)], hall._brass())
        kit.candle("SillCandle%d" % index, x, y, SEAT_H + 1.6, height=tall, radius=3.0, power=3.6)
    # The candle note, folded into a tent so it stands up to be read.
    note = writing("WakeCandleNote", lines=6.0)
    nx, ny = 520.0, 229.0
    kit.quad("NoteFront", [(nx - 9.0, ny + 3.0, SEAT_H + 0.2), (nx + 9.0, ny + 3.0, SEAT_H + 0.2),
                           (nx + 9.0, ny, SEAT_H + 9.0), (nx - 9.0, ny, SEAT_H + 9.0)], note)
    kit.quad("NoteBack", [(nx - 9.0, ny, SEAT_H + 9.0), (nx + 9.0, ny, SEAT_H + 9.0),
                          (nx + 9.0, ny - 3.0, SEAT_H + 0.2), (nx - 9.0, ny - 3.0, SEAT_H + 0.2)], parchment())
    closed_book(kit, "SeatBook", 538.0, 560.0, 223.0, 233.0, SEAT_H, 4.0, (0.16, 0.05, 0.08))
    # A small chest tucked under the seat's east end.
    wood, iron = oak(), hall._cast_iron()
    kit.box("Chest", 530.0, 563.0, 236.0, 250.0, 0.0, 15.0, wood, bevel=0.7, uv="box")
    kit.box("ChestLid", 529.0, 564.0, 235.0, 251.0, 13.0, 17.0, wood, bevel=0.8, uv="box")
    for x in (535.0, 557.0):
        kit.box("ChestBand", x - 1.0, x + 1.0, 234.6, 251.4, 0.0, 17.4, iron, bevel=0.2)
    kit.box("ChestLock", 544.0, 549.0, 251.0, 251.8, 8.0, 14.0, hall._brass(), bevel=0.3)
    # Moonlight: from the north-east and above, through the opening only.
    direction = Vector((-0.12, -math.cos(math.radians(36.0)), -math.sin(math.radians(36.0)))).normalized()
    target = RP.world(centre, BACK_Y, (WINDOW_SILL + WINDOW_SPRING) / 2.0 + 20.0)
    data = bpy.data.lights.new("WakeMoon", "SPOT")
    data.energy = 3600.0
    data.color = MOON
    data.spot_size = math.radians(26.0)
    data.spot_blend = 0.35
    data.shadow_soft_size = 0.12
    moon = RP._link(bpy.data.objects.new("WakeMoon", data))
    moon.location = target - direction * 9.0
    moon.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return kit


def nightstand():
    kit = RP.Kit("Nightstand")
    wood = oak()
    kit.box("Plinth", 154.0, 238.0, 237.0, 277.0, 0.0, 4.0, wood, bevel=0.6, uv="box")
    kit.box("Body", 156.0, 236.0, 238.0, 274.0, 4.0, 42.0, wood, bevel=0.8, uv="box")
    kit.box("Top", 152.0, 240.0, 235.0, 278.0, 42.0, 46.0, wood, bevel=1.0, uv="box")
    kit.box("Drawer", 162.0, 230.0, 274.0, 275.4, 27.0, 38.0, wood, bevel=0.6, uv="box")
    kit.ball("Knob", 196.0, 276.0, 32.5, 1.7, hall._brass())
    candlestick(kit, "Bedside", 222.0, 254.0, 46.0, wax_height=11.0, radius=2.6, power=6.0)
    closed_book(kit, "BedsideBook", 162.0, 194.0, 246.0, 268.0, 46.0, 5.0, (0.08, 0.1, 0.2))
    kit.lathe("Watch", 204.0, 270.0, [(0.0, 46.0), (4.6, 46.0), (4.8, 47.0), (4.4, 47.8), (0.0, 47.8)], hall._brass(),
              plan=0.62)
    kit.ring("WatchBow", (204.0, 267.4, 48.3), (0.0, 1.0, 0.0), 1.4, 0.35, hall._brass(), segments=16, sides=6)
    return kit


def sconces(shell):
    kit = RP.Kit("Sconces")
    iron = hall._cast_iron()
    for index, y in enumerate((330.0, 640.0)):
        frame = shell.mount("left", y)
        wall = frame.to_g(0.0, 96.0, 0.0)
        cup = frame.to_g(0.0, 92.0, 13.0)
        kit.box("Plate%d" % index, wall.x - 1.5, wall.x + 1.2, y - 4.0, y + 4.0, wall.z - 9.0, wall.z + 9.0, iron,
                bevel=0.4)
        kit.rod("Arm%d" % index, (wall.x, y, wall.z - 2.0), (cup.x, cup.y, cup.z), 1.0, iron)
        kit.lathe("Cup%d" % index, cup.x, cup.y, [(0.0, cup.z - 2.0), (2.0, cup.z - 2.0), (4.6, cup.z),
                                                    (4.6, cup.z + 1.4), (0.0, cup.z + 1.4)], iron)
        kit.candle("Sconce%d" % index, cup.x, cup.y, cup.z + 1.4, height=14.0, radius=2.8, power=4.8)
    return kit


def crystal_lamps(shell):
    kit = RP.Kit("CrystalLamps")
    rock = stone()
    glow_material = hall._glow_material("WakeCrystal", (0.42, 0.12, 1.0), 0.85, (0.22, 0.05, 0.5))
    for index, y in enumerate(CRYSTAL_Y):
        wall = shell.side_x("right", y)
        x0, x1 = 860.0, wall + 4.0
        kit.box("Base%d" % index, x0, x1, y - 12.0, y + 12.0, 0.0, 5.0, rock, bevel=0.8, uv="box")
        kit.box("Shaft%d" % index, x0 + 3.0, x1, y - 9.0, y + 9.0, 5.0, 32.0, rock, bevel=0.8, uv="box_up")
        kit.box("Cap%d" % index, x0 - 1.0, x1, y - 11.0, y + 11.0, 32.0, 36.0, rock, bevel=0.8, uv="box")
        cx = (x0 + x1) / 2.0
        for part, (dx, dy, radius, tall, tilt) in enumerate(((0.0, 0.0, 3.4, 22.0, 0.0), (-4.0, 2.0, 2.4, 14.0, -0.35),
                                                              (4.2, -1.0, 2.2, 12.0, 0.4), (1.0, 4.0, 1.8, 9.0, 0.2))):
            crystal(kit, "Crystal%d_%d" % (index, part), cx + dx, y + dy, 36.0, radius, tall, glow_material, tilt=tilt,
                    turn=part * 0.7)
        kit.light("Glow%d" % index, cx - 4.0, y + 2.0, 52.0, VIOLET, 4.2, radius=0.06)
        RP.glow("crystal", cx, y, 50.0, VIOLET, 26.0)
    return kit


def side_table():
    kit = RP.Kit("SideTable")
    wood, brass = oak(), hall._brass()
    x0, x1, y0, y1, top = 116.0, 246.0, 590.0, 650.0, 38.0
    for x, y in ((x0 + 4.0, y0 + 4.0), (x1 - 4.0, y0 + 4.0), (x0 + 4.0, y1 - 4.0), (x1 - 4.0, y1 - 4.0)):
        kit.box("Leg", x - 2.6, x + 2.6, y - 2.6, y + 2.6, 0.0, top - 4.0, wood, bevel=0.5, uv="box_up")
    kit.box("Apron", x0 + 3.0, x1 - 3.0, y0 + 3.0, y1 - 3.0, top - 9.0, top - 4.0, wood, bevel=0.5, uv="box")
    kit.box("Top", x0, x1, y0, y1, top - 4.0, top, wood, bevel=1.0, uv="box")
    # The oil lamp: a brass font, a glass chimney and the flame inside it.
    lx, ly = 150.0, 618.0
    kit.lathe("LampFoot", lx, ly, [(0.0, top), (7.0, top), (7.2, top + 1.4), (3.0, top + 3.0), (2.4, top + 5.0),
                                   (6.4, top + 8.0), (6.8, top + 11.0), (4.0, top + 14.0), (3.0, top + 15.0),
                                   (0.0, top + 15.0)], brass)
    chimney = kit.lathe("LampChimney", lx, ly, [(3.4, top + 15.0), (5.2, top + 19.0), (5.6, top + 23.0),
                                               (3.2, top + 28.0), (2.8, top + 34.0)], jar_glass(), close=False)
    chimney.visible_shadow = False
    kit.flame("Lamp", lx, ly, top + 17.0, size=1.5, power=5.6, color=(1.0, 0.64, 0.3))
    RP.GLOWS[-1]["kind"] = "lantern"
    closed_book(kit, "TableBook", 196.0, 230.0, 600.0, 626.0, top, 5.5, (0.22, 0.12, 0.05))
    closed_book(kit, "TableBook2", 198.0, 226.0, 603.0, 624.0, top + 5.5, 4.5, (0.06, 0.12, 0.1))
    paper(kit, "TableLetter", 186.0, 638.0, top + 0.2, 26.0, 16.0, 0.16, writing("WakeLetter", lines=8.0))
    # The travelling trunk below it, a purple cloth thrown over one end.
    iron, boards = hall._cast_iron(), planks()
    trunk = [kit.box("Trunk", 114.0, 264.0, 664.0, 712.0, 0.0, 28.0, boards, bevel=0.9, uv="box"),
             kit.box("TrunkLid", 112.0, 266.0, 662.0, 714.0, 26.0, 33.0, boards, bevel=1.4, uv="box")]
    for x in (126.0, 189.0, 252.0):
        kit.box("TrunkBand", x - 1.6, x + 1.6, 661.4, 714.6, 0.0, 33.6, iron, bevel=0.3)
    kit.box("TrunkLock", 182.0, 196.0, 714.0, 715.2, 18.0, 30.0, brass, bevel=0.4)
    cloth = kit.sheet("TrunkCloth", 200.0, 278.0, 656.0, 712.0, lambda x, y: 38.0 + 0.8 * math.sin(0.3 * x),
                      velvet(), columns=70, rows=56)
    centre = RP.world(239.0, 684.0, 0.0)
    cloth.data.transform(Matrix.Translation(centre) @ Matrix.Rotation(math.radians(12.0), 4, "Z")
                         @ Matrix.Translation(-centre))
    RP.simulate_cloth(cloth, trunk + [bpy.data.objects["RoomFloor"]], frames=44, mass=0.3, bending=1.0)
    fold(cloth, creases(random.Random(23), 200.0, 268.0, 656.0, 716.0, 8, 2.6, 2.4, (-50.0, 50.0)))
    thicken(cloth, 0.6)
    return kit


def alchemy_bench():
    kit = RP.Kit("AlchemyBench")
    wood, brass = oak(), hall._brass()
    x0, x1, y0, y1, top = 388.0, 620.0, 664.0, 712.0, 34.0
    for x in (x0 + 5.0, x1 - 5.0):
        for y in (y0 + 5.0, y1 - 5.0):
            kit.box("Leg", x - 3.0, x + 3.0, y - 3.0, y + 3.0, 0.0, top - 5.0, wood, bevel=0.5, uv="box_up")
    kit.box("Top", x0, x1, y0, y1, top - 5.0, top, wood, bevel=1.2, uv="box")
    # Flasks on a brass ring stand, a spirit burner, a mortar, the open book.
    kit.lathe("StandFoot", 420.0, 686.0, [(0.0, top), (6.0, top), (6.0, top + 1.0), (0.0, top + 1.0)], brass)
    kit.rod("StandPost", (426.0, 690.0, top), (426.0, 690.0, top + 30.0), 0.8, brass)
    flask(kit, "Round", 420.0, 686.0, top + 1.0, "round", (0.25, 0.55, 1.0), size=1.1)
    kit.ring("StandRing", (420.0, 686.0, top + 9.0), (0.0, 0.0, 1.0), 7.6, 0.6, brass, segments=28, sides=6)
    flask(kit, "Cone", 450.0, 692.0, top, "cone", VIOLET, size=1.05)
    flask(kit, "Bottle", 468.0, 680.0, top, "bottle", (0.35, 1.0, 0.5), size=0.95)
    kit.lathe("Burner", 496.0, 690.0, [(0.0, top), (5.2, top), (5.6, top + 4.0), (3.6, top + 7.0), (1.0, top + 7.6),
                                       (0.0, top + 7.6)], brass)
    kit.flame("Burner", 496.0, 690.0, top + 7.6, size=1.2, power=3.1, color=(1.0, 0.58, 0.32))
    kit.lathe("Mortar", 524.0, 692.0, [(0.0, top), (4.6, top), (6.6, top + 4.0), (6.2, top + 7.0), (5.4, top + 7.0),
                                       (0.0, top + 2.0)], stone(), plan=0.6)
    kit.rod("Pestle", (522.0, 692.0, top + 4.0), (530.0, 684.0, top + 13.0), 1.2, stone())
    kit.box("BookBoard", 546.0, 588.0, 676.0, 702.0, top, top + 1.0, leather("WakeAlchemyCover", (0.2, 0.08, 0.05)),
            bevel=0.3)
    for part, (a, b) in (("L", (547.0, 566.6)), ("R", (567.4, 587.0))):
        kit.box("Pages" + part, a, b, 677.0, 701.0, top + 1.0, top + 3.0, parchment(), bevel=0.3)
    kit.quad("BookText", [(547.0, 701.0, top + 3.05), (587.0, 701.0, top + 3.05), (587.0, 677.0, top + 3.05),
                          (547.0, 677.0, top + 3.05)], writing("WakeBookPages", lines=9.0, gutter=True))
    candlestick(kit, "Bench", 604.0, 684.0, top, wax_height=9.0, radius=2.6, power=3.4, stick=4.0)
    paper(kit, "Recipe", 446.0, 704.0, top + 0.2, 22.0, 12.0, -0.12, writing("WakeRecipe", lines=6.0))
    return kit


def crates():
    kit = RP.Kit("Crates")
    wood, brass, iron = planks(), hall._brass(), hall._cast_iron()
    for part, (x0, x1, y0, y1, tall) in (("Big", (786.0, 888.0, 612.0, 668.0, 54.0)),
                                         ("Small", (806.0, 894.0, 674.0, 712.0, 28.0))):
        kit.box(part, x0, x1, y0, y1, 0.0, tall, wood, bevel=0.8, uv="box")
        for x in (x0 + 2.5, x1 - 2.5):
            kit.box(part + "Batten", x - 2.5, x + 2.5, y1 - 0.4, y1 + 1.4, 0.0, tall, wood, bevel=0.5, uv="box_up")
        for h in (3.0, tall - 3.0):
            kit.box(part + "Rail", x0, x1, y1 - 0.4, y1 + 1.2, h - 2.4, h + 2.4, wood, bevel=0.5, uv="box")
        for x in (x0, x1):
            kit.box(part + "Corner", x - 1.2, x + 1.2, y1 - 3.0, y1 + 1.8, tall - 6.0, tall + 0.6, iron, bevel=0.3)
    # The armillary sphere on the big crate: three brass hoops round a globe.
    cx, cy, base = 836.0, 642.0, 54.0
    kit.lathe("ArmillaryFoot", cx, cy, [(0.0, base), (8.0, base), (8.0, base + 2.0), (2.4, base + 4.0),
                                        (1.6, base + 10.0), (3.0, base + 12.0), (0.0, base + 12.0)], brass)
    centre = (cx, cy, base + 30.0)
    kit.ring("Meridian", centre, (1.0, 0.0, 0.0), 17.0, 0.9, brass)
    kit.ring("Equator", centre, (0.0, 0.0, 1.0), 17.0, 0.9, brass)
    kit.ring("Ecliptic", centre, (0.0, math.sin(math.radians(23.4)), math.cos(math.radians(23.4))), 15.6, 0.7, brass)
    kit.ring("Horizon", centre, (math.sin(math.radians(40.0)), 0.0, math.cos(math.radians(40.0))), 18.6, 0.6, brass)
    kit.ball("Globe", cx, cy, base + 30.0, 5.0, hall._painted("WakeGlobe", (0.08, 0.16, 0.26)), plan=1.0)
    axis = Vector((0.0, -math.sin(math.radians(23.4)), math.cos(math.radians(23.4))))
    middle = RP.world(*centre)
    kit.rod("Axis", tuple(RP.game(middle - axis * 0.2)), tuple(RP.game(middle + axis * 0.2)), 0.5, brass)
    closed_book(kit, "CrateBook", 858.0, 882.0, 618.0, 640.0, 54.0, 5.0, (0.2, 0.05, 0.07))
    candlestick(kit, "Crate", 880.0, 690.0, 28.0, wax_height=10.0, radius=2.5, power=3.1, stick=6.0)
    return kit


# ---------------------------------------------------------------- the interactive props


def creases(rng, x0, x1, y0, y1, count, height, width, angles):
    """A field of soft creases over x0..x1, y0..y1: ridges along lines of
    random place and angle (degrees from the plan's y), fading at their ends.
    A sheet starts creased, and the cloth solver's bending keeps the creases
    as it falls: fabric remembers how it was pushed about."""
    lines = []
    for _index in range(count):
        angle = math.radians(rng.uniform(*angles))
        lines.append((rng.uniform(x0, x1), rng.uniform(y0, y1), math.sin(angle), math.cos(angle),
                      rng.uniform(0.35, 1.0) * (y1 - y0) * 0.35, rng.uniform(0.5, 1.0) * height,
                      rng.uniform(0.7, 1.3) * width))

    def field(x, y):
        total = 0.0
        for cx, cy, dx, dy, half, tall, wide in lines:
            along = (x - cx) * dx + (y - cy) * dy
            across = (x - cx) * dy - (y - cy) * dx
            if abs(along) < half:
                total += tall * math.exp(-(across / wide) ** 2) * math.cos(0.5 * math.pi * along / half) ** 2
        return total
    return field


def fold(obj, field, facing_up=0.55):
    """Raises soft folds into a simulated cloth where it lies face up: each
    vertex rises by field(x, y) screen px, fully where its normal points
    straight up and not at all where the cloth hangs. Fabric on a flat bed
    only buckles where it has been pushed about, which a short fall cannot
    show; the folds give the surface the camera sees its life."""
    mesh = obj.data
    for vertex in mesh.vertices:
        up = (vertex.normal.z - facing_up) / (1.0 - facing_up)
        if up <= 0.0:
            continue
        point = RP.game(obj.matrix_world @ vertex.co)
        # Only ever up: a fold pushed down would sink into what the cloth lies on.
        vertex.co.z += max(field(point.x, point.y), 0.0) / RP.SIN * RP.PX * min(up * 2.0, 1.0)
    mesh.update()
    return obj


def thicken(obj, px):
    """Gives a simulated cloth its thickness, so its edges read as fabric."""
    modifier = obj.modifiers.new("Solidify", "SOLIDIFY")
    modifier.thickness = px * RP.PX
    modifier.offset = 0.0
    modifier.use_even_offset = True
    return obj


def pillow(kit, part, cx, cy, h, half_x, half_y, top, bottom, angle, rng, dent=0.0):
    """A filled pillow resting at screen height h: a puffed top and a flatter
    underside sewn together at the seam, its corners pinched and wrinkled."""
    shape = bmesh.new()
    columns, rows = 40, 24
    phase = rng.uniform(0.0, math.tau)

    def bulge(u, v, power):
        return ((1.0 - abs(u) ** 2.6) * (1.0 - abs(v) ** 2.6)) ** power

    def place(u, v, z):
        across, along = half_x * u, half_y * v
        return (cx + across * math.cos(angle) - along * math.sin(angle),
                cy + across * math.sin(angle) + along * math.cos(angle), h + bottom + z)

    def wrinkle(u, v):
        edge = max(abs(u), abs(v))
        ripple = math.sin(7.0 * math.atan2(v, u) + phase) + 0.5 * math.sin(13.0 * math.atan2(v, u) - phase)
        return 0.55 * ripple * max(min((edge - 0.55) / 0.35, 1.0), 0.0) * (1.0 - edge ** 8)

    top_verts, bottom_verts = {}, {}
    for j in range(rows + 1):
        for i in range(columns + 1):
            u, v = -1.0 + 2.0 * i / columns, -1.0 + 2.0 * j / rows
            z = top * bulge(u, v, 0.5) + wrinkle(u, v)
            z -= dent * math.exp(-((u + 0.1) / 0.42) ** 2 - ((v - 0.05) / 0.5) ** 2)
            top_verts[i, j] = shape.verts.new(place(u, v, z))
            if 0 < i < columns and 0 < j < rows:
                bottom_verts[i, j] = shape.verts.new(place(u, v, -bottom * bulge(u, v, 0.15)))
            else:
                bottom_verts[i, j] = top_verts[i, j]
    for j in range(rows):
        for i in range(columns):
            corners = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            shape.faces.new([top_verts[key] for key in corners])
            shape.faces.new([bottom_verts[key] for key in reversed(corners)])
    return kit.shape(part, shape, sheet_linen(), smooth=True, sharp_angle=70.0, uv="floor")


def bed():
    """A four-poster as the painting has it, its bedding fallen into place:
    the coverlet and the throw are dropped onto the mattress with Blender's
    cloth solver, so every fold hangs as cloth does."""
    kit = RP.Kit("Bed", prop="Bed")
    wood, brass = oak(), hall._brass()
    x0, x1 = 130.0, 248.0
    head_y, foot_y = 290.0, 562.0
    rng = random.Random(7)
    colliders = []

    def post(part, x, y, tall):
        # A square block where the rails join, a turned column, a brass finial.
        colliders.append(kit.box(part + "Block", x - 4.6, x + 4.6, y - 4.6, y + 4.6, 0.0, 21.0, wood, bevel=0.9,
                                 uv="box_up"))
        kit.lathe(part, x, y, [(0.0, 21.0), (4.4, 21.0), (4.6, 22.2), (3.0, 23.8), (3.4, 25.2), (2.6, 28.0),
                               (3.0, tall * 0.62), (3.9, tall * 0.65), (2.8, tall * 0.69), (2.6, tall - 4.0),
                               (3.8, tall - 3.0), (4.0, tall - 1.2), (3.2, tall), (0.0, tall)], wood, plan=ROUND)
        kit.lathe(part + "Finial", x, y, [(0.0, tall), (1.6, tall), (1.4, tall + 1.0), (3.0, tall + 2.8),
                                          (3.3, tall + 4.4), (2.2, tall + 6.2), (0.9, tall + 7.2), (0.0, tall + 7.8)],
                  brass, plan=ROUND)

    for x in (x0 + 4.6, x1 - 4.6):
        post("HeadPost", x, head_y, 50.0)
        post("FootPost", x, foot_y, 36.0)

    def board(part, y, low, high, arch, panels):
        """A headboard or footboard: rails and stiles framing raised panels."""
        a, b = x0 + 9.2, x1 - 9.2

        def top_of(x):
            return high + arch * math.sin(math.pi * (x - a) / (b - a))
        steps = 24
        upper = [(a + (b - a) * step / steps, top_of(a + (b - a) * step / steps)) for step in range(steps + 1)]
        kit.slab(part + "Infill", [(a, low)] + [(b, low)] + list(reversed(upper)), y - 1.0, y + 1.0, wood)
        kit.slab(part + "TopRail", [(x, h - 4.5) for x, h in upper] + [(x, h + 0.8) for x, h in reversed(upper)],
                 y - 2.6, y + 2.6, wood, bevel=0.9)
        colliders.append(kit.box(part + "BottomRail", a, b, y - 2.6, y + 2.6, low, low + 4.5, wood, bevel=0.8,
                                 uv="box"))
        width = (b - a) / panels
        for index in range(panels + 1):
            x = a + width * index
            if 0 < index < panels:
                kit.box(part + "Stile", x - 2.0, x + 2.0, y - 2.2, y + 2.2, low + 4.5, top_of(x) - 3.5, wood,
                        bevel=0.6, uv="box_up")
        for index in range(panels):
            left, right = a + width * index + 3.6, a + width * (index + 1) - 3.6
            ceiling = min(top_of(left), top_of(right)) - 7.0
            kit.box(part + "Panel", left, right, y + 0.6, y + 2.0, low + 7.5, ceiling, wood, bevel=1.4, uv="box_up")

    board("Head", head_y, 17.0, 42.0, 7.0, 3)
    board("Foot", foot_y, 7.0, 27.0, 0.0, 2)
    for x in (x0 + 1.0, x1 - 8.0):
        colliders.append(kit.box("Rail", x, x + 7.0, head_y + 4.6, foot_y - 4.6, 8.0, 19.0, wood, bevel=0.8,
                                 uv="side"))
    mattress = kit.box("Mattress", x0 + 5.0, x1 - 5.0, head_y + 3.0, foot_y - 7.0, 13.0, 26.0,
                       RP.textured("WakeTicking", "cotton_jersey", 0.25, 0.92, (0.86, 0.8, 0.7), saturation=0.2,
                                   ao=0.3), bevel=2.4, uv="box")
    colliders.append(mattress)
    colliders.append(pillow(kit, "PillowWest", 162.0, 309.0, 26.0, 26.0, 13.0, 7.2, 1.4, -0.06, rng, dent=1.6))
    colliders.append(pillow(kit, "PillowEast", 214.5, 307.0, 26.0, 25.0, 12.5, 6.8, 1.4, 0.09, rng))

    # The coverlet, its head turned down in a band of white sheet, creased
    # where it was pushed down the bed and over the sleeper.
    folds = creases(random.Random(12), x0 + 10.0, x1 - 10.0, 350.0, foot_y - 24.0, 18, 2.4, 3.4, (-30.0, 30.0))
    turned = creases(random.Random(5), x0 + 10.0, x1 - 10.0, 336.0, 352.0, 6, 1.6, 2.2, (72.0, 108.0))

    def lain(x, y):
        return folds(x, y) + turned(x, y) + 0.5 * (1.0 + math.sin(0.08 * x + 0.05 * y))
    blanket = kit.sheet("Blanket", x0 - 13.0, x1 + 13.0, 330.0, foot_y - 6.0,
                        lambda x, y: 31.0 + 0.8 * math.sin(0.21 * x + 0.07 * y), [damask(), sheet_linen()],
                        columns=110, rows=170, material_of=lambda x, y: 1 if y < 341.0 else 0)
    RP.simulate_cloth(blanket, colliders, frames=48, mass=0.5, bending=1.5)
    fold(blanket, lain)

    # A cream throw with a woven gold border, thrown across the foot of the
    # bed and falling over its east side. It lands on the coverlet alone: the
    # coverlet already lies over the mattress and rails, and a cloth caught
    # between two colliders that touch tears itself apart. The coverlet gets
    # its thickness only after: a solidified collider would hold the throw a
    # px proud of the cloth the camera sees.
    # It starts a px above the coverlet, not dropped from a height: a fall
    # onto a cloth as thin as this one tunnels straight through it.
    surface = bvhtree.BVHTree.FromObject(blanket, bpy.context.evaluated_depsgraph_get())
    turn = math.radians(-10.0)
    tx0, tx1, ty0, ty1 = 146.0, 262.0, 448.0, 494.0
    middle = ((tx0 + tx1) / 2.0, (ty0 + ty1) / 2.0)
    edge = x1 - 1.0

    def resting(u, v):
        x = middle[0] + (u - middle[0]) * math.cos(turn) - (v - middle[1]) * math.sin(turn)
        y = middle[1] + (u - middle[0]) * math.sin(turn) + (v - middle[1]) * math.cos(turn)
        hit = surface.ray_cast(RP.world(min(x, edge), y, 80.0), Vector((0.0, 0.0, -1.0)))[0]
        return (RP.game(hit).z if hit is not None else 30.0) + 1.4
    throw = kit.sheet("Throw", tx0, tx1, ty0, ty1, resting, [throw_cloth(), gold_weave()], columns=120, rows=46,
                      material_of=lambda x, y: 1 if min(x - tx0, tx1 - x, y - ty0, ty1 - y) < 2.6 else 0)
    centre = RP.world(middle[0], middle[1], 0.0)
    throw.data.transform(Matrix.Translation(centre) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation(-centre))
    # Wool on silk damask grips: high friction holds it where it was thrown.
    RP.simulate_cloth(throw, [blanket, bpy.data.objects["RoomFloor"]] + colliders[:4], frames=36, quality=10,
                      mass=0.25, bending=1.0, distance=0.004, friction=60.0)
    fold(throw, creases(random.Random(31), 150.0, 260.0, 436.0, 506.0, 12, 2.6, 2.4, (-75.0, 75.0)))
    thicken(throw, 0.6)
    thicken(blanket, 0.7)
    # The brass key's bow, just showing under the west pillow.
    kit.ring("KeyBow", (182.0, 324.0, 26.6), (0.0, 0.0, 1.0), 2.4, 0.6, brass, segments=20, sides=6)
    return kit


def bookshelf():
    """A tall oak bookcase: plinth and crown mouldings, a cabinet of two
    drawers, and three shelves of old books, a few laid flat or leaning."""
    kit = RP.Kit("Bookshelf", prop="Bookshelf")
    wood, brass = oak(), hall._brass()
    # Its plinth's front is the shelf's collision edge (y 276.5) less the
    # 7.5 px the game's walk-up band needs, so the prompt reaches the player.
    x0, x1, back, front = 242.0, 404.0, 238.0, 266.0
    rng = random.Random(41)
    kit.box("Plinth", x0 - 1.0, x1 + 1.0, back, front + 5.0, 0.0, 6.0, wood, bevel=0.8, uv="box")
    kit.box("PlinthMould", x0 - 2.5, x1 + 2.5, back - 0.5, front + 6.0, 5.0, 8.5, wood, bevel=1.1, uv="box")
    for part, (a, b) in (("SideW", (x0, x0 + 7.0)), ("SideE", (x1 - 7.0, x1))):
        kit.box(part, a, b, back, front + 1.0, 8.5, 150.0, wood, bevel=0.9, uv="box_up")
    kit.box("Back", x0 + 7.0, x1 - 7.0, back, back + 2.0, 8.5, 150.0, wood, bevel=0.0, uv="box_up")
    kit.box("Top", x0 - 1.0, x1 + 1.0, back - 0.5, front + 2.0, 150.0, 153.5, wood, bevel=0.8, uv="box")
    for part, (grow, low, high) in (("Crown", (2.5, 153.5, 156.5)), ("CrownCove", (4.5, 156.5, 159.5)),
                                    ("CrownCap", (5.5, 159.5, 162.0))):
        kit.box(part, x0 - grow, x1 + grow, back - grow * 0.55, front + 1.0 + grow, low, high, wood, bevel=1.1,
                uv="box")
    # The cabinet: two drawers with escutcheons and ring pulls.
    kit.box("CabinetTop", x0 + 7.0, x1 - 7.0, back + 2.0, front + 1.5, 40.0, 44.0, wood, bevel=0.8, uv="box")
    kit.box("CabinetRail", x0 + 7.0, x1 - 7.0, front - 1.0, front + 1.0, 8.5, 11.0, wood, bevel=0.6, uv="box")
    middle = (x0 + x1) / 2.0
    kit.box("CabinetStile", middle - 2.0, middle + 2.0, front - 1.0, front + 1.0, 8.5, 40.0, wood, bevel=0.6,
            uv="box_up")
    for index, (a, b) in enumerate(((x0 + 8.0, middle - 2.5), (middle + 2.5, x1 - 8.0))):
        kit.box("Drawer%d" % index, a, b, front - 1.0, front + 1.5, 11.5, 39.0, wood, bevel=0.9, uv="box")
        kit.box("DrawerPanel%d" % index, a + 5.0, b - 5.0, front + 1.3, front + 2.3, 16.0, 34.5, wood, bevel=1.2,
                uv="box")
        cx = (a + b) / 2.0
        kit.box("Escutcheon%d" % index, cx - 2.2, cx + 2.2, front + 2.2, front + 2.7, 27.5, 33.0, brass, bevel=0.4)
        kit.box("Keyhole%d" % index, cx - 0.5, cx + 0.5, front + 2.6, front + 2.9, 29.0, 31.5, hall._bakelite(),
                bevel=0.0)
        kit.ring("Pull%d" % index, (cx, front + 3.2, 22.0), (0.0, 1.0, 0.0), 2.6, 0.45, brass, segments=24, sides=6)
    for index, h in enumerate((79.0, 114.5)):
        kit.box("Shelf%d" % index, x0 + 7.0, x1 - 7.0, back + 2.0, front - 1.0, h, h + 3.5, wood, bevel=0.6,
                uv="box")
        kit.box("ShelfLip%d" % index, x0 + 7.0, x1 - 7.0, front - 2.5, front, h - 0.5, h + 3.8, wood, bevel=0.9,
                uv="box")
    spine = front - 2.0
    # The lowest shelf: books, then two potions.
    shelf_run(kit, x0 + 7.5, 352.0, spine, 44.0, 79.0, rng)
    flask(kit, "ShelfPotion", 368.0, 254.0, 44.0, "bottle", VIOLET, size=1.0)
    flask(kit, "ShelfPotion2", 386.0, 256.0, 44.0, "round", (0.35, 1.0, 0.5), size=0.85)
    # The middle shelf: books, an hourglass, more books.
    shelf_run(kit, x0 + 7.5, 334.0, spine, 82.5, 114.5, rng)
    sand_low = 82.5
    for part, (low, high) in (("Hourglass", (sand_low, sand_low + 2.0)), ("HourglassTop", (106.0, 108.0))):
        kit.lathe(part, 352.0, 254.0, [(0.0, low), (6.0, low), (6.0, high), (0.0, high)], wood, plan=ROUND)
    hourglass = kit.lathe("HourglassGlass", 352.0, 254.0, [(4.4, sand_low + 2.0), (4.0, 91.0), (0.9, 95.0),
                                                           (4.0, 99.0), (4.4, 106.0)], jar_glass(), plan=ROUND,
                          close=False)
    hourglass.visible_shadow = False
    kit.lathe("HourglassSand", 352.0, 254.0, [(0.0, sand_low + 2.0), (3.8, sand_low + 2.0), (3.2, 88.0),
                                              (0.0, 88.5)], hall._painted("WakeSand", (0.62, 0.48, 0.28)), plan=ROUND)
    for x in (346.5, 357.5):
        kit.rod("HourglassPost", (x, 254.0, sand_low + 2.0), (x, 254.0, 106.0), 0.6, wood)
    shelf_run(kit, 368.0, x1 - 7.5, spine, 82.5, 114.5, rng, lean_end=False)
    # The top shelf: books, a stack laid flat with a scroll on it, books.
    shelf_run(kit, x0 + 7.5, 300.0, spine, 118.0, 150.0, rng)
    for index, (left, right, thick, colour) in enumerate(((304.0, 342.0, 5.5, BOOK_COLOURS[0]),
                                                          (306.0, 340.0, 4.5, BOOK_COLOURS[2]),
                                                          (305.0, 338.0, 5.0, BOOK_COLOURS[3]))):
        low = 118.0 + sum((5.5, 4.5, 5.0)[:index])
        closed_book(kit, "LyingBook%d" % index, left, right, 243.0 + index, 263.0 - index * 0.5, low, thick, colour)
    kit.rod("StackScroll", (308.0, 255.0, 133.0 + 2.6), (336.0, 257.0, 133.0 + 2.6), 2.6, parchment())
    kit.rod("StackScrollTie", (321.0, 253.0, 135.6), (321.0, 259.0, 135.6), 2.8, hall._cloth("WakeTie", (0.3, 0.05, 0.04)))
    shelf_run(kit, 360.0, x1 - 7.5, spine, 118.0, 150.0, rng, lean_end=False)
    # On top: a globe on its stand, two books and a scroll.
    kit.lathe("GlobeStand", 272.0, 250.0, [(0.0, 162.0), (6.5, 162.0), (6.5, 164.0), (2.0, 165.5), (1.4, 171.0),
                                           (0.0, 171.0)], wood, plan=ROUND)
    kit.ball("Globe", 272.0, 250.0, 181.0, 10.0, hall._painted("WakeGlobeTop", (0.12, 0.2, 0.17)), plan=ROUND)
    kit.ring("GlobeMeridian", (272.0, 250.0, 181.0), (1.0, 0.0, 0.0), 11.4, 0.6, brass)
    closed_book(kit, "TopBook0", 300.0, 336.0, 242.0, 262.0, 162.0, 5.5, BOOK_COLOURS[1])
    closed_book(kit, "TopBook1", 303.0, 333.0, 244.0, 260.0, 167.5, 4.5, BOOK_COLOURS[4])
    kit.rod("TopScroll", (356.0, 252.0, 164.6), (392.0, 254.0, 164.6), 2.6, parchment())
    return kit


def desk():
    kit = RP.Kit("Desk", prop="Desk")
    wood, brass = oak(), hall._brass()
    # Its front legs stand on the desk's collision edge, as the painted desk's.
    x0, x1, y0, y1, top = 594.0, 816.0, 228.0, 312.0, 45.0
    for x in (x0 + 9.0, x1 - 9.0):
        for y in (y0 + 10.0, y1 - 5.0):
            kit.lathe("Leg", x, y, [(0.0, 0.0), (3.8, 0.0), (3.8, 2.4), (2.8, 4.0), (3.2, 10.0), (2.2, 18.0),
                                    (3.4, 24.0), (3.4, top - 13.0), (0.0, top - 13.0)], wood, plan=0.6, uv="box_up")
    kit.box("Stretcher", x0 + 12.0, x1 - 12.0, 266.0, 276.0, 6.0, 9.0, wood, bevel=0.5, uv="box")
    kit.box("Apron", x0 + 5.0, x1 - 5.0, y0 + 5.0, y1 - 4.0, top - 14.0, top - 5.0, wood, bevel=0.8, uv="box")
    kit.box("Top", x0, x1, y0, y1, top - 5.0, top, wood, bevel=1.4, uv="box")
    for index, (a, b) in enumerate(((x0 + 12.0, 672.0), (676.0, 734.0), (738.0, x1 - 12.0))):
        kit.box("Drawer%d" % index, a, b, y1 - 4.2, y1 - 2.6, top - 13.0, top - 6.0, wood, bevel=0.5, uv="box")
        kit.ball("DrawerPull%d" % index, (a + b) / 2.0, y1 - 2.2, top - 9.5, 1.6, brass)
    # Mrs. Lin's candles under glass: three jars of three sizes on a brass tray.
    kit.box("Tray", 628.0, 720.0, 240.0, 262.0, top, top + 1.4, brass, bevel=0.4)
    for index, (x, radius, tall, candle) in enumerate(((644.0, 8.0, 22.0, 9.0), (672.0, 10.0, 30.0, 11.0),
                                                        (703.0, 12.5, 38.0, 13.0))):
        base = top + 1.4
        kit.candle("Jar%d" % index, x, 251.0, base, height=candle, radius=2.6, power=1.7)
        profile = [(radius, base), (radius, base + tall * 0.72)]
        for step in range(1, 9):
            angle = math.radians(90.0 * step / 8.0)
            profile.append((radius * math.cos(angle), base + tall * 0.72 + tall * 0.28 * math.sin(angle)))
        jar = kit.lathe("JarGlass%d" % index, x, 251.0, profile, jar_glass(), plan=0.6, close=False)
        jar.visible_shadow = False
        kit.ball("JarKnob%d" % index, x, 251.0, base + tall + 1.4, 2.0, jar_glass(), plan=0.6)
    # The scroll the game reads from the desk, and the open book beside it.
    kit.quad("Scroll", [(730.0, 294.0, top + 0.3), (784.0, 294.0, top + 0.3), (784.0, 270.0, top + 0.3),
                        (730.0, 270.0, top + 0.3)], writing("WakeScroll", lines=9.0))
    for x in (729.0, 785.0):
        kit.rod("ScrollRoll", (x, 267.0, top + 2.2), (x, 297.0, top + 2.2), 2.4, parchment())
        for y in (265.4, 298.6):
            kit.ball("ScrollKnob", x, y, top + 2.2, 1.4, oak(), plan=0.6)
    kit.box("BookCover", 650.0, 712.0, 268.0, 300.0, top, top + 1.0, leather("WakeDeskCover", (0.08, 0.1, 0.18)),
            bevel=0.3)
    for part, (a, b) in (("L", (651.0, 680.6)), ("R", (681.4, 711.0))):
        kit.box("BookPages" + part, a, b, 269.0, 299.0, top + 1.0, top + 3.4, parchment(), bevel=0.3)
    kit.quad("BookText", [(651.0, 299.0, top + 3.45), (711.0, 299.0, top + 3.45), (711.0, 269.0, top + 3.45),
                          (651.0, 269.0, top + 3.45)], writing("WakeDeskPages", lines=10.0, gutter=True))
    closed_book(kit, "Stack0", 600.0, 634.0, 236.0, 262.0, top, 6.0, (0.2, 0.06, 0.06))
    closed_book(kit, "Stack1", 602.0, 632.0, 238.0, 260.0, top + 6.0, 5.0, (0.06, 0.14, 0.1))
    closed_book(kit, "Stack2", 604.0, 630.0, 240.0, 259.0, top + 11.0, 4.6, (0.24, 0.17, 0.06))
    paper(kit, "Letter", 750.0, 246.0, top + 0.2, 30.0, 20.0, 0.12, writing("WakeDeskLetter", lines=8.0))
    paper(kit, "Sketch", 618.0, 286.0, top + 0.2, 26.0, 18.0, -0.2, hall.material_blueprint())
    # Ink, quill, a lens and the evening's candle.
    kit.lathe("Inkwell", 796.0, 284.0, [(0.0, top), (4.6, top), (5.0, top + 2.0), (4.6, top + 6.0), (2.4, top + 7.4),
                                        (2.2, top + 9.0), (0.0, top + 9.0)], hall._bakelite())
    kit.rod("Quill", (796.0, 284.0, top + 8.0), (812.0, 266.0, top + 36.0), 0.5, linen())
    vane = [(800.0, 280.0, top + 16.0), (805.6, 276.0, top + 21.0), (813.0, 266.0, top + 36.0),
            (806.0, 271.0, top + 26.0)]
    kit.quad("QuillVane", vane, linen())
    kit.ring("LensRim", (634.0, 292.0, top + 1.2), (0.0, 0.0, 1.0), 6.0, 0.8, brass, segments=32, sides=8)
    kit.rod("LensHandle", (640.0, 296.0, top + 1.2), (652.0, 303.0, top + 1.2), 1.1, wood)
    candlestick(kit, "DeskCandle", 804.0, 240.0, top, wax_height=13.0, radius=2.6, power=3.6)
    return kit


def door(shell):
    """The Wake gate: the Hall's own portal (hall_prototype.build_portal), its
    leaves shut under a violet seal, mapped onto the east wall with one affine
    map so every stone, hinge and emblem keeps its Hall shape. A stone step
    brings it out to where the gate's collision stops the player."""
    kit = RP.Kit("Door", prop="Door")
    before = set(bpy.data.objects)
    recorded = []
    saved = hall._glow
    hall._glow = lambda *glow: recorded.append(glow)
    try:
        stand = {"centre": 0.0, "feet": 0.0, "width": 40.0, "height": 64.0, "depth": 6.0}
        portal = hall.PropKit("WakeGate", stand, RP.STRETCH)
        hall.build_portal(portal, {"name": "Wake", "half": float(hall.WAKE_GATE_HALF_PX), "opens": "in",
                                   "x": 0.0, "face_y": 0.0})
        seal = hall._glow_material("WakeSeal", (0.5, 0.2, 1.0), 1.0, (0.12, 0.04, 0.24))
        portal.ring("SealRing", 0.0, -1.7, 15.0, 4.6, 0.32, seal)
        portal.ring("SealInner", 0.0, -1.75, 15.0, 2.6, 0.22, seal)
        for turn in range(6):
            angle = math.radians(turn * 60.0 + 30.0)
            x, z = 3.6 * math.cos(angle), 15.0 + 3.6 * math.sin(angle)
            portal.ball("SealRune", x, -1.8, z, 0.42, seal, plan=0.5)
        portal.glow("crystal", 0.0, -1.8, 15.0, VIOLET, 9.0)
    finally:
        hall._glow = saved
    made = [obj for obj in bpy.data.objects if obj not in before]
    # The door stays shut, so the lit passage behind it is left out.
    for obj in list(made):
        if "Passage" in obj.name or "RecessRoof" in obj.name:
            made.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)
    # Three times its Hall size, the Hall's procedural stone and oak read as
    # plaster: the room's photo stone and wood replace them, projected before
    # the map so they keep their size on the wall.
    swaps = {
        "PortalStone": (RP.textured("WakeGateStone", "large_grey_tiles", 0.45, 0.82, (0.8, 0.76, 0.84), ao=0.15),
                        "box"),
        "PortalStonePale": (RP.textured("WakeGateStonePale", "large_grey_tiles", 0.45, 1.05, (0.88, 0.84, 0.86),
                                        ao=0.15), "box"),
        "DoorOak": (RP.textured("WakeGateOak", "dark_wood", 0.45, 0.6, (0.82, 0.6, 0.48), saturation=0.85, ao=0.2),
                    "box_up"),
    }
    for obj in made:
        if obj.type != "MESH":
            continue
        chosen = [swaps[material.name] for material in obj.data.materials if material.name in swaps]
        if not chosen:
            continue
        RP.project_uvs(obj, chosen[0][1], scale=DOOR_SCALE)
        for index, material in enumerate(obj.data.materials):
            if material.name in swaps:
                obj.data.materials[index] = swaps[material.name][0]
    # Glows sized for the Hall flare at three times the size.
    # Matte too: under the room's key light their gloss would glare white.
    for name, factor in (("EmblemMoon", 0.05), ("FaceDoorGem", 0.2), ("FanGlassWake", 0.5), ("WakeSeal", 1.0)):
        material = bpy.data.materials.get(name)
        for node in material.node_tree.nodes if material else ():
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Emission Strength"].default_value *= factor
                node.inputs["Roughness"].default_value = 0.7
                node.inputs["Specular IOR Level"].default_value = 0.15
                node.inputs["Base Color"].default_value = (0.07, 0.035, 0.12, 1.0)
    in_game = RP.place_on_frame(made, shell.mount("right", DOOR_Y), 0.0, -DOOR_PROUD, scale=DOOR_SCALE,
                                name="WakeGate")
    RP.map_glows(recorded, in_game, DOOR_SCALE)
    for obj in made:
        if obj.type == "MESH":
            kit.keep(obj)
    seal_point = in_game @ Vector((0.0, 1.8, 15.0))
    kit.light("Seal", seal_point.x - 16.0, seal_point.y, seal_point.z, VIOLET, 0.3, radius=0.05)
    # The room's candlelight on the gate's face, from the floor in front of it.
    data = bpy.data.lights.new("WakeGateKey", "SPOT")
    data.energy = 110.0
    data.color = (1.0, 0.8, 0.6)
    data.spot_size = math.radians(55.0)
    data.spot_blend = 0.6
    data.shadow_soft_size = 0.4
    key = RP._link(bpy.data.objects.new("WakeGateKey", data))
    key.location = RP.world(720.0, DOOR_Y + 60.0, 150.0)
    aim = RP.world(888.0, DOOR_Y, 60.0) - key.location
    key.rotation_euler = aim.normalized().to_track_quat("-Z", "Y").to_euler()
    key.visible_glossy = False
    # The step up to the threshold, out to the gate's collision.
    wall = shell.side_x("right", DOOR_Y)
    rock = RP.textured("WakeStepStone", "large_grey_tiles", 0.6, 1.0, (0.86, 0.8, 0.84), ao=0.2)
    # Two half-round steps, worn into the floor in front of the threshold.
    for part, (reach, along, low, high) in (("Step", (wall - 851.0, 40.0, 0.0, 2.4)),
                                            ("StepUpper", (wall - 862.0, 32.0, 2.4, 4.4))):
        arc = [(wall - reach * math.cos(math.radians(angle)), DOOR_Y + along * math.sin(math.radians(angle)))
               for angle in range(-90, 91, 6)]
        kit.slab(part, [(wall + 2.0, DOOR_Y + along)] + list(reversed(arc)) + [(wall + 2.0, DOOR_Y - along)], low,
                 high, rock, plane="floor", bevel=0.8)
    return kit


# ---------------------------------------------------------------- the room


def moon_sky():
    """The Hall's moonlight (hall_prototype.add_sun: its colour, strength and
    softness), from the south-south-west and high, so the room's tall walls
    cast their shadows behind the furniture as the painting draws them."""
    data = bpy.data.lights.new("WakeMoonSky", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sun = RP._link(bpy.data.objects.new("WakeMoonSky", data))
    sun.rotation_euler = Vector((0.12, 0.38, -0.92)).normalized().to_track_quat("-Z", "Y").to_euler()


def grade(scene):
    """The room's exposure, set after the shared Cycles setup."""
    scene.view_settings.exposure = 0.35


def build(rp, layout):
    global RP
    RP = rp
    shell_materials = {
        # Flagstones and wall blocks at the painted room's size: tiles about
        # 70 px, courses about 35 px.
        "floor": rp.textured("WakeFloor", "large_floor_tiles_02", 1.6, 0.66, (0.76, 0.7, 0.8), ao=0.25),
        "wall": rp.textured("WakeWall", "castle_wall_slates", 1.5, 0.56, (0.72, 0.66, 0.78), ao=0.3),
        # The wall tops and their lit edges are the Hall's own: dark slate
        # with moss and broken cracks, outlined in lit stone.
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if rp.TEXTURES.available()
                else rp.textured("WakeCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if rp.TEXTURES.available()
                else rp.textured("WakeLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("WakeReveal", "castle_wall_slates", 1.5, 0.62, (0.74, 0.68, 0.8), ao=0.2),
    }
    shell = rp.Shell(SPEC, shell_materials)
    shell.build()
    floor_dressing()
    back_wall_dressing()
    window()
    nightstand()
    sconces(shell)
    crystal_lamps(shell)
    side_table()
    alchemy_bench()
    crates()
    moon_sky()
    props = {"Bed": bed(), "Bookshelf": bookshelf(), "Desk": desk(), "Door": door(shell)}
    print("WAKE ROOM built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    return {"props": props}
