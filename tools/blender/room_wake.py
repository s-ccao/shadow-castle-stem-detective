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

import bpy
from mathutils import Matrix, Vector

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


def dark_wood():
    return RP.textured("WakeDarkWood", "dark_wood", 0.5, 0.6, (0.8, 0.6, 0.5), saturation=0.85, ao=0.2)


def worn_wood():
    return RP.textured("WakeWornWood", "wood_table_worn", 0.3, 0.62, (0.82, 0.66, 0.52), saturation=0.8, ao=0.2)


def velvet():
    material = RP.textured("WakeVelvet", "velour_velvet", 0.3, 0.95, (0.38, 0.15, 0.6), saturation=0.0, ao=0.3)
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            # Velvet's pile catches light at grazing angles.
            node.inputs["Sheen Weight"].default_value = 1.0
            node.inputs["Sheen Roughness"].default_value = 0.35
            node.inputs["Sheen Tint"].default_value = (0.75, 0.55, 1.0, 1.0)
    return material


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
        shader = hall._principled(nodes, links, color, roughness=0.95)
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
    """A book lying shut: boards, spine and the block of pages between."""
    cover = leather("WakeLeather_%d_%d_%d" % tuple(int(channel * 100) for channel in color), color)
    kit.box(part + "Pages", x0 + 0.7, x1 - 0.2, y0 + 0.7, y1 - 0.7, h + 0.6, h + thick - 0.6, parchment(),
            bevel=0.2)
    kit.box(part + "Lower", x0, x1, y0, y1, h, h + 0.7, cover, bevel=0.25)
    kit.box(part + "Upper", x0, x1, y0, y1, h + thick - 0.7, h + thick, cover, bevel=0.25)
    kit.box(part + "Spine", x0, x0 + 1.0, y0, y1, h, h + thick, cover, bevel=0.35)


def standing_books(kit, x0, x1, front, h0, h1, rng, depth=(15.0, 19.0), lean_end=True):
    """Books shelved spine out between x0 and x1, the last few leaning."""
    material = hall._book_material()
    x = x0
    while x < x1 - 3.0:
        width = rng.uniform(3.0, 6.4)
        if x + width > x1:
            break
        tall = (h1 - h0) * rng.uniform(0.6, 0.93)
        deep = rng.uniform(*depth)
        kit.box("Book", x, x + width, front - 1.2 - deep, front - 1.2, h0, h0 + tall, material, bevel=0.3)
        x += width + rng.uniform(0.0, 0.35)
    if lean_end and x < x1 - 8.0:
        width = rng.uniform(3.5, 5.5)
        tall = (h1 - h0) * rng.uniform(0.7, 0.85)
        obj = kit.box("Book", x + 1.0, x + 1.0 + width, front - 18.0, front - 1.2, h0, h0 + tall, material, bevel=0.3)
        lean(obj, Vector((x + 1.0 + width, front - 9.0, h0)), -math.radians(rng.uniform(16.0, 24.0)))
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
    brass, walnut = hall._brass(), dark_wood()
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
    wood, iron = worn_wood(), hall._cast_iron()
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
    wood = dark_wood()
    kit.box("Plinth", 154.0, 238.0, 237.0, 277.0, 0.0, 4.0, wood, bevel=0.6, uv="box")
    kit.box("Body", 156.0, 236.0, 238.0, 274.0, 4.0, 42.0, wood, bevel=0.8, uv="box")
    kit.box("Top", 152.0, 240.0, 235.0, 278.0, 42.0, 46.0, wood, bevel=1.0, uv="box")
    kit.box("Drawer", 162.0, 230.0, 274.0, 275.4, 27.0, 38.0, wood, bevel=0.6, uv="box")
    kit.ball("Knob", 196.0, 276.0, 32.5, 1.7, hall._brass())
    candlestick(kit, "Bedside", 222.0, 254.0, 46.0, wax_height=11.0, radius=2.6, power=3.6)
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
    wood, brass = worn_wood(), hall._brass()
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
    iron = hall._cast_iron()
    kit.box("Trunk", 114.0, 264.0, 664.0, 712.0, 0.0, 28.0, wood, bevel=0.9, uv="box")
    kit.box("TrunkLid", 112.0, 266.0, 662.0, 714.0, 26.0, 33.0, wood, bevel=1.4, uv="box")
    for x in (126.0, 189.0, 252.0):
        kit.box("TrunkBand", x - 1.6, x + 1.6, 661.4, 714.6, 0.0, 33.6, iron, bevel=0.3)
    kit.box("TrunkLock", 182.0, 196.0, 714.0, 715.2, 18.0, 30.0, brass, bevel=0.4)
    def cloth(x, y):
        fall = max(y - 713.0, 0.0) / 2.6
        ripple = (1.2 * math.sin(0.3 * x + 0.05 * y) + 0.8 * math.sin(0.16 * x - 0.21 * y + 1.0)
                  + 1.4 * math.exp(-((x - 222.0 - 0.3 * (y - 660.0)) / 4.0) ** 2))
        edge = max(204.0 - x, x - 256.0, 0.0) / 2.0
        return 37.0 + ripple - 18.0 * min(fall, 1.0) ** 0.8 - 14.0 * min(edge, 1.0) ** 0.8
    kit.sheet("TrunkCloth", 200.0, 260.0, 660.0, 716.0, cloth, velvet(), columns=30, rows=40)
    return kit


def alchemy_bench():
    kit = RP.Kit("AlchemyBench")
    wood, brass = worn_wood(), hall._brass()
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
    wood, brass, iron = worn_wood(), hall._brass(), hall._cast_iron()
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


def bed():
    kit = RP.Kit("Bed", prop="Bed")
    wood, brass = dark_wood(), hall._brass()
    x0, x1 = 130.0, 248.0
    head_y, foot_y = 290.0, 562.0

    def post(part, x, y, tall):
        kit.lathe(part, x, y, [(0.0, 0.0), (4.6, 0.0), (4.6, 3.0), (3.4, 5.0), (3.6, tall * 0.45), (4.4, tall * 0.5),
                               (3.4, tall * 0.56), (3.4, tall - 3.0), (4.6, tall - 2.0), (4.6, tall), (0.0, tall)],
                  wood, plan=0.6, uv="box_up")
        kit.ball(part + "Finial", x, y, tall + 3.2, 3.6, brass, plan=0.6, squash=0.95)

    for x in (x0 + 4.6, x1 - 4.6):
        post("HeadPost", x, head_y, 44.0)
        post("FootPost", x, foot_y, 34.0)
    arch = [(x0 + 8.0 + (x1 - x0 - 16.0) * step / 16.0,
             32.0 + 8.0 * math.sin(math.pi * step / 16.0)) for step in range(17)]
    kit.slab("Headboard", [(x0 + 8.0, 14.0), (x1 - 8.0, 14.0)] + list(reversed(arch)), head_y - 3.0, head_y + 3.0,
             wood, bevel=0.8)
    kit.slab("HeadPanel", [(x0 + 22.0, 18.0), (x1 - 22.0, 18.0), (x1 - 22.0, 31.0), (x0 + 22.0, 31.0)], head_y + 3.0,
             head_y + 4.0, wood, bevel=0.6)
    kit.slab("Footboard", [(x0 + 8.0, 10.0), (x1 - 8.0, 10.0), (x1 - 8.0, 28.0), (x0 + 8.0, 28.0)], foot_y - 3.0,
             foot_y + 3.0, wood, bevel=0.8)
    for x in (x0 + 2.0, x1 - 8.0):
        kit.box("Rail", x, x + 6.0, head_y + 2.0, foot_y - 2.0, 9.0, 19.0, wood, bevel=0.8, uv="side")
    kit.box("Mattress", x0 + 5.0, x1 - 5.0, head_y + 3.0, foot_y - 10.0, 15.0, 26.0, linen(), bevel=2.6, uv="box")
    def blanket(x, y):
        # On the mattress, falling over its sides; a hollow where the
        # sleeper lay and soft folds that run down toward the foot.
        side = max(x0 + 5.0 - x, x - (x1 - 5.0), 0.0)
        foot = max(y - (foot_y - 14.0), 0.0)
        sleeper = -2.6 * math.exp(-((x - 186.0) / 30.0) ** 2 - ((y - 430.0) / 80.0) ** 2)
        folds = (1.6 * math.sin(0.11 * x + 0.05 * y) * math.sin(0.035 * y + 1.3)
                 + 1.0 * math.sin(0.07 * x - 0.09 * y + 2.0) + 0.5 * math.sin(0.23 * x + 0.13 * y))
        # Long creases where the blanket was pushed aside.
        for start, slope, height in ((150.0, 0.32, 2.4), (214.0, -0.22, 1.8), (176.0, 0.12, 1.5)):
            folds += height * math.exp(-((x - start - slope * (y - 340.0)) / 5.0) ** 2) * min(max((y - 350.0) / 60.0, 0.0), 1.0)
        inside = 1.0 - min(side / 3.0, 1.0)
        top = max(33.5 + sleeper + folds * inside, 28.0)
        return top - 19.0 * min(side / 4.0, 1.0) ** 0.7 - 7.0 * min(foot / 10.0, 1.0) ** 1.2
    kit.sheet("Blanket", x0 + 1.0, x1 - 1.0, 338.0, foot_y - 3.0, blanket, velvet(), columns=60, rows=110)
    kit.box("SheetFold", x0 + 3.0, x1 - 3.0, 330.0, 344.0, 28.5, 33.0, linen(), bevel=2.2, uv="box")
    for x in (163.0, 215.0):
        kit.ball("Pillow", x, 312.0, 34.0, 23.0, linen(), plan=0.5, squash=0.3, segments=24)
    # A cream throw across the blanket, falling with it over the bed's sides.
    def throw(x, y):
        along = (x - x0) / (x1 - x0)
        lower = 452.0 + 18.0 * along
        upper = lower + 27.0 + 4.0 * math.sin(6.0 * along)
        inside = min(max(min(y - lower, upper - y) / 2.0 + 0.5, 0.0), 1.0)
        inside = inside * inside * (3.0 - 2.0 * inside)
        return blanket(x, y) - 3.0 + inside * (4.1 + 0.6 * math.sin(0.4 * x + 0.2 * y))
    kit.sheet("Throw", x0, x1, 440.0, 508.0, throw, linen(), columns=150, rows=110)
    # The brass key's bow, just showing under the west pillow.
    kit.ring("KeyBow", (184.0, 326.0, 34.5), (0.0, 0.0, 1.0), 2.4, 0.6, brass, segments=20, sides=6)
    return kit


def bookshelf():
    kit = RP.Kit("Bookshelf", prop="Bookshelf")
    wood, brass = dark_wood(), hall._brass()
    # Its plinth stands at the shelf's collision edge (y 276.5) less the 7.5 px
    # the game's walk-up band needs: the prompt reaches a player standing there.
    x0, x1, back, front = 242.0, 404.0, 238.0, 266.0
    kit.box("Plinth", x0 - 2.0, x1 + 2.0, back, front + 6.0, 0.0, 8.0, wood, bevel=0.8, uv="box")
    kit.box("Back", x0 + 4.0, x1 - 4.0, back, back + 2.0, 8.0, 154.0, wood, bevel=0.0, uv="box")
    for part, (a, b) in (("SideL", (x0, x0 + 6.0)), ("SideR", (x1 - 6.0, x1))):
        kit.box(part, a, b, back, front, 0.0, 156.0, wood, bevel=0.8, uv="box_up")
    kit.box("Cornice", x0 - 4.0, x1 + 4.0, back - 2.0, front + 4.0, 156.0, 164.0, wood, bevel=1.4, uv="box")
    kit.box("CabinetTop", x0 + 3.0, x1 - 3.0, back, front + 4.0, 42.0, 46.0, wood, bevel=0.8, uv="box")
    middle = (x0 + x1) / 2.0
    for index, (a, b) in enumerate(((x0 + 7.0, middle - 1.0), (middle + 1.0, x1 - 7.0))):
        kit.box("Door%d" % index, a, b, front, front + 2.0, 9.0, 41.0, wood, bevel=0.8, uv="box_up")
        kit.box("Panel%d" % index, a + 6.0, b - 6.0, front + 1.8, front + 2.8, 15.0, 35.0, wood, bevel=0.8,
                uv="box_up")
        kit.ball("Pull%d" % index, b - 5.0 if index == 0 else a + 5.0, front + 3.0, 25.0, 1.6, brass)
    for index, h in enumerate((80.0, 116.0)):
        kit.box("Shelf%d" % index, x0 + 6.0, x1 - 6.0, back + 2.0, front, h, h + 3.0, wood, bevel=0.5, uv="box")
    rng = random.Random(41)
    # Three shelves of books, each run broken by the odd curio.
    standing_books(kit, x0 + 7.0, 352.0, front, 46.0, 80.0, rng)
    flask(kit, "ShelfPotion", 368.0, 254.0, 46.0, "bottle", VIOLET, size=1.0)
    flask(kit, "ShelfPotion2", 384.0, 256.0, 46.0, "round", (0.35, 1.0, 0.5), size=0.85)
    standing_books(kit, x0 + 7.0, 330.0, front, 83.0, 116.0, rng)
    kit.lathe("Hourglass", 352.0, 254.0, [(0.0, 83.0), (6.0, 83.0), (6.0, 85.0), (0.0, 85.0)], wood)
    kit.lathe("HourglassTop", 352.0, 254.0, [(0.0, 107.0), (6.0, 107.0), (6.0, 109.0), (0.0, 109.0)], wood)
    hourglass = kit.lathe("HourglassGlass", 352.0, 254.0, [(4.4, 85.0), (4.0, 92.0), (0.9, 96.0), (4.0, 100.0),
                                                           (4.4, 107.0)], jar_glass(), close=False)
    hourglass.visible_shadow = False
    kit.lathe("HourglassSand", 352.0, 254.0, [(0.0, 85.0), (3.8, 85.0), (3.2, 89.0), (0.0, 89.5)],
              hall._painted("WakeSand", (0.62, 0.48, 0.28)))
    for x in (346.5, 357.5):
        kit.rod("HourglassPost", (x, 254.0, 85.0), (x, 254.0, 107.0), 0.6, wood)
    standing_books(kit, 372.0, x1 - 7.0, front, 83.0, 116.0, rng, lean_end=False)
    standing_books(kit, x0 + 7.0, 300.0, front, 119.0, 156.0, rng)
    kit.ball("Skull", 318.0, 252.0, 128.0, 8.5, hall._painted("WakeBone", (0.55, 0.5, 0.4)), plan=0.85, squash=0.85)
    for x in (314.0, 322.0):
        kit.ball("SkullEye", x, 259.0, 128.5, 2.0, hall._bakelite(), plan=0.5)
    closed_book(kit, "LyingBook", 336.0, 372.0, 244.0, 264.0, 119.0, 6.0, (0.12, 0.05, 0.06))
    closed_book(kit, "LyingBook2", 338.0, 368.0, 246.0, 262.0, 125.0, 5.0, (0.05, 0.08, 0.14))
    standing_books(kit, 376.0, x1 - 7.0, front, 119.0, 156.0, rng, lean_end=False)
    # On top: a globe on its stand and a scroll.
    kit.lathe("GlobeStand", 270.0, 250.0, [(0.0, 164.0), (6.0, 164.0), (6.0, 165.6), (1.4, 167.0), (1.2, 172.0),
                                           (0.0, 172.0)], brass)
    kit.ball("Globe", 270.0, 250.0, 182.0, 10.0, hall._painted("WakeGlobeTop", (0.1, 0.2, 0.18)), plan=1.0)
    kit.ring("GlobeMeridian", (270.0, 250.0, 182.0), (1.0, 0.0, 0.0), 11.6, 0.6, brass)
    kit.rod("TopScroll", (360.0, 252.0, 167.0), (392.0, 254.0, 167.0), 3.0, parchment())
    return kit


def desk():
    kit = RP.Kit("Desk", prop="Desk")
    wood, brass = dark_wood(), hall._brass()
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
            kit.ball("ScrollKnob", x, y, top + 2.2, 1.4, dark_wood(), plan=0.6)
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


def fill():
    """Light the open ceiling would let in: a dim, cool wash from overhead, so
    the floor and the leaning walls read between the candles' pools."""
    data = bpy.data.lights.new("WakeFill", "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = 9.0, 8.0
    data.energy = 95.0
    data.color = (0.82, 0.76, 0.9)
    light = RP._link(bpy.data.objects.new("WakeFill", data))
    light.location = RP.world(512.0, 470.0, 0.0) + Vector((0.0, 0.0, 7.0))
    light.visible_glossy = False


def grade(scene):
    """The room's exposure, set after the shared Cycles setup."""
    scene.view_settings.exposure = 1.2


def build(rp, layout):
    global RP
    RP = rp
    shell_materials = {
        # Flagstones and wall blocks at the painted room's size: tiles about
        # 70 px, courses about 35 px.
        "floor": rp.textured("WakeFloor", "large_floor_tiles_02", 1.6, 0.66, (0.76, 0.7, 0.8), ao=0.25),
        "wall": rp.textured("WakeWall", "castle_wall_slates", 1.5, 0.56, (0.72, 0.66, 0.78), ao=0.3),
        "cap": rp.textured("WakeCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6, ao=0.12),
        "lip": rp.textured("WakeLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1),
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
    fill()
    props = {"Bed": bed(), "Bookshelf": bookshelf(), "Desk": desk(), "Door": door(shell)}
    print("WAKE ROOM built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    return {"props": props}
