"""The Greenhouse, the castle's glasshouse wing, for the Blender room
prototype. tools/blender/room_prototype.py imports it as room_greenhouse and
calls build() on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). The room is two
screens tall (1024 x 1536) and the game's camera follows the player through
it. Everything stands where the painted room has it, on the floor its
collision blocks, built the way the Hall is built: dark slate walls with
mossy, broken tops outlined in lit stone, flagstones, iron lanterns, the
Hall's moonlight, and the Hall's own Greenhouse portal for its gate.

  north   a gothic window in the back wall throws moonlit tracery onto the
          floor, between two lancets; lanterns on stone pedestals, hanging
          baskets and ivy
  west    the long blue blossom bed (painted in the game's art, so part of the
          render) with its ironvine trellis and the brass valves for light,
          water and air; lancets, lanterns and ivy on the wall
  east    the moonleaf bed with its silver pods and the mineral patch
  middle  the great stone planter (Worldsort/MagicPlanter): a ring of
          dressed stone round a glowing flower, blue blossom to the north,
          dewcap in the shaded west, emberroot in the sunlit east, a lantern
          on each of its three posts; the gardener's potting bench
          (Worldsort/Workbench) with its seedling trays, drying rack and
          handbook, and his stool
  south   the two clusters of pots (Worldsort/PlantPotsA, PlantPotsB) and
          the gate (Worldsort/ArchDoor): the Hall's Greenhouse portal, as the
          door looks from inside

Plants and the gardener's tools are CC0 Poly Haven models
(tools/blender/cc0_models.json, fetched by tools/blender/fetch_models.py),
placed at their real size: one game px across is a centimetre.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import hall_prototype as hall

RP = None
RNG = random.Random(4127)
MODELS = os.path.join("prototypes", "blender_rooms", "models")

BACK_Y = 310.0
WALL_H = 270.0
LEAN = 70.0
LEFT_X, RIGHT_X = 88.0, 914.0
SOUTH_Y = 1433.0
SOUTH_DEPTH = 70.0
SOUTH_H = 30.0
# The gate, as the painting draws it, on the south wall's outer face: a deep
# round arch springing from two square plinth blocks. GATE_OPEN is half its
# opening, GATE_RING the arch's ring, GATE_DEEP how far its vault runs back
# into the wall (plan px) and GATE_PLINTH the plinths' outer half width; the
# south wall stops at the plinths (GATE_X).
GATE_CX = 512.0
GATE_FACE_Y = SOUTH_Y + SOUTH_DEPTH
GATE_OPEN = 64.0
GATE_RING = 27.0
GATE_SPRING = 62.0
GATE_DEEP = 26.0
GATE_PLINTH = 104.0
GATE_SILL = 12.0
GATE_X = (GATE_CX - GATE_PLINTH, GATE_CX + GATE_PLINTH)
# Lanterns on posts on the south wall, close either side of the plinths.
GATE_LAMPS = (GATE_X[0] - 22.0, GATE_X[1] + 22.0)
# The floor, as the painting lays it: slate pavers in north-south columns of
# mixed widths and lengths, their joints staggered.
PAVE_COLUMN = (36.0, 48.0)
PAVE_LENGTH = (38.0, 92.0)
PAVE_JOINT = 2.6
PAVE_SOUTH = 1544.0
# The great window: a pointed arch over two lancets and an oculus.
WINDOW_X = (392.0, 632.0)
WINDOW_SILL = 34.0
WINDOW_SPRING = 92.0
WINDOW_GLASS_Y = BACK_Y - 30.0
# Lancets either side of it in the back wall.
FLANK_LANCETS = ((168.0, 236.0), (788.0, 856.0))
# The round planter on its collision: centre and radius on the floor.
PLANTER = (513.0, 579.0)
PLANTER_R = 166.0
PLANTER_RIM_H = 34.0
# The potting bench on its collision: top footprint, top height and stool.
# The potting bench at a real bench's size (2.5 m by 1.0 m, 78 cm high),
# its front where the painting's is: the preview swaps its footprint into
# the room's collision (the painted bench's is 1.85 m deep).
BENCH = (386.0, 640.0, 971.0, 1048.0)
BENCH_TOP = 50.0
STOOL = (482.0, 1052.0)
# The long beds, outlined as the game's collision outlines them.
LEFT_BED = [(90.0, 318.0), (238.0, 318.0), (257.0, 346.0), (244.0, 1110.0), (218.0, 1140.0), (101.0, 1137.0),
            (90.0, 1124.0)]
RIGHT_BED = [(784.0, 318.0), (912.0, 318.0), (912.0, 1124.0), (900.0, 1138.0), (791.0, 1134.0), (766.0, 1105.0),
             (762.0, 346.0)]
KERB = 13.0
KERB_H = 26.0
SOIL_H = 21.0
# A lathe's plan squash for a true circle, as in the other rooms.
ROUND = math.cos(math.radians(hall.ALPHA_DEGREES))
CANDLE = (1.0, 0.6, 0.28)
MOON = (0.55, 0.68, 1.0)
VIOLET = (0.62, 0.36, 1.0)
LEAF_LIGHT = hall.DOOR_THEMES["Greenhouse"][1]
EMBER = (1.0, 0.42, 0.12)
DEW = (0.55, 0.95, 1.0)


def pointed_arch(x0, x1, spring, apex, steps=14):
    """A pointed arch over x0..x1 from `spring` to `apex` (screen px), two
    arcs meeting at the top, as (x, h) from the west springing to the east."""
    half = (x1 - x0) / 2.0
    rise = apex - spring
    # Each arc is centred on the springing line `offset` inside the far side.
    offset = (rise * rise - half * half) / (2.0 * half)
    radius = half + offset
    centre = (x0 + x1) / 2.0
    west = []
    east = []
    # The apex, seen from the west arc's centre.
    top = math.atan2(rise, -offset)
    for index in range(steps + 1):
        angle = math.pi - (math.pi - top) * index / steps
        west.append((centre + offset + radius * math.cos(angle), spring + radius * math.sin(angle)))
        east.append((centre - offset - radius * math.cos(angle), spring + radius * math.sin(angle)))
    return west + list(reversed(east))[1:]


def window_outline():
    x0, x1 = WINDOW_X
    return [(x0, WINDOW_SILL), (x1, WINDOW_SILL)] + list(reversed(pointed_arch(x0, x1, WINDOW_SPRING, 258.0)))


def lancet_outline(x0, x1, sill, spring, apex):
    return [(x0, sill), (x1, sill)] + list(reversed(pointed_arch(x0, x1, spring, apex, steps=10)))


SPEC = {
    "back": {"y": BACK_Y, "base": (LEFT_X, RIGHT_X), "top": (LEFT_X - LEAN, RIGHT_X + LEAN), "height": WALL_H,
             "openings": [{"outline": window_outline()}]
             + [{"outline": lancet_outline(x0, x1, 72.0, 168.0, 228.0)} for x0, x1 in FLANK_LANCETS]},
    "left": {"base": ((LEFT_X, BACK_Y), (LEFT_X, 1500.0)), "near": 1536.0 + WALL_H},
    "right": {"base": ((RIGHT_X, BACK_Y), (RIGHT_X, 1500.0)), "near": 1536.0 + WALL_H},
    "south": {"y": SOUTH_Y, "height": SOUTH_H, "depth": SOUTH_DEPTH},
    "floor": {"x": (-60.0, 1084.0), "y": (240.0, PAVE_SOUTH)},
    "cap": 40.0,
}


# ---------------------------------------------------------------- materials


def oak():
    """Worn, waxed oak, warm as the other rooms' furniture."""
    return RP.textured("GreenhouseOak", "wood_table_worn", 0.42, 0.95, (0.96, 0.8, 0.64), saturation=0.92, ao=0.25)


def planks():
    return RP.textured("GreenhousePlanks", "wood_cabinet_worn_long", 0.6, 0.8, (0.92, 0.76, 0.62), saturation=0.9,
                       ao=0.25)


def kerb_stone():
    """Dressed grey stone for the beds' kerbs and the planter, paler than the walls."""
    return RP.textured("GreenhouseKerb", "large_grey_tiles", 0.45, 0.8, (0.76, 0.74, 0.8), saturation=0.5, ao=0.2)


def plinth_stone():
    return RP.textured("GreenhousePlinth", "large_grey_tiles", 0.55, 0.66, (0.72, 0.68, 0.78), ao=0.2)


def soil():
    """Dark, damp potting earth with drier crumbs and a little moss."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        crumbs = hall._noise(nodes, links, coords.outputs["Object"], scale=180.0, detail=8.0, roughness=0.7)
        clods = hall._noise(nodes, links, coords.outputs["Object"], scale=26.0, detail=4.0)
        moss = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=7.0, detail=3.0),
                          0.6, 0.72)
        color = hall._mix(nodes, links, crumbs, (0.022, 0.014, 0.01), (0.075, 0.05, 0.032))
        color = hall._mix(nodes, links, hall._ramp(nodes, links, clods, 0.55, 0.75), color, (0.1, 0.075, 0.05))
        color = hall._mix(nodes, links, moss, color, (0.03, 0.06, 0.02))
        hall._principled(nodes, links, color, roughness=0.92,
                         normal=hall._bump(nodes, links, crumbs, 0.6, distance=0.01))
    return hall._material("GreenhouseSoil", build)


def iron():
    return hall._cast_iron()


def gothic_glass(name, x0, x1, sill, apex, bright=1.0):
    """Leaded diamond quarries lit by the moonlit sky behind, each its own
    shade of sea green, brightest toward the moon in the north-east and up the
    arch; UVs are the opening's own (x, h) in px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        across_px = op("SUBTRACT", u, (x0 + x1) / 2.0)
        # Diamonds 13 px wide and 17 px tall: two families of diagonal leads.
        a = op("ADD", op("DIVIDE", across_px, 13.0), op("DIVIDE", v, 17.0))
        b = op("SUBTRACT", op("DIVIDE", across_px, 13.0), op("DIVIDE", v, 17.0))
        lead_a = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", a), 0.5)), 0.06)
        lead_b = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", b), 0.5)), 0.06)
        lead = op("MAXIMUM", op("SUBTRACT", 1.0, op("MAXIMUM", lead_a, lead_b)), 0.0)
        # Each quarry its own glass: a hash of its cell.
        cell = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("FLOOR", a), cell.inputs["X"])
        links.new(op("FLOOR", b), cell.inputs["Y"])
        tone = nodes.new("ShaderNodeTexWhiteNoise")
        tone.noise_dimensions = "3D"
        links.new(cell.outputs[0], tone.inputs["Vector"])
        streak = hall._noise(nodes, links, coords.outputs["UV"], scale=0.06, detail=3.0)
        across = op("DIVIDE", op("SUBTRACT", u, x0), max(x1 - x0, 1.0))
        up = op("DIVIDE", op("SUBTRACT", v, sill), max(apex - sill, 1.0))
        sky = op("ADD", 0.3, op("MULTIPLY", op("ADD", op("MULTIPLY", up, 0.6), op("MULTIPLY", across, 0.3)), 0.8))
        sky = op("MULTIPLY", sky, op("ADD", 0.75, op("MULTIPLY", streak, 0.5)))
        tint = hall._mix(nodes, links, tone.outputs["Value"], (0.07, 0.24, 0.3), (0.22, 0.52, 0.5))
        glass = op("MULTIPLY", op("MULTIPLY", sky, lead), op("ADD", 0.7, op("MULTIPLY", tone.outputs["Value"], 0.5)))
        hall._principled(nodes, links, (0.012, 0.016, 0.02), roughness=0.3, emission=tint,
                         emission_strength=op("MULTIPLY", glass, 1.35 * bright))
    return hall._material(name, build)


def petal_material(name, inner, outer, glow):
    """A petal: `inner` at its base glowing faintly, fading to `outer`."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        along = hall._ramp(nodes, links, v, 0.0, 1.0)
        color = hall._mix(nodes, links, along, inner, outer)
        vein = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", u, 0.5)), 0.035), 0.35)
        color = hall._mix(nodes, links, vein, color, tuple(channel * 1.3 for channel in inner))
        shader = hall._principled(nodes, links, color, roughness=0.38, emission=inner,
                                  emission_strength=op("MULTIPLY", op("SUBTRACT", 1.0, along), glow))
        shader.inputs["Subsurface Weight"].default_value = 0.4
        shader.inputs["Subsurface Radius"].default_value = (1.0, 0.4, 0.8)
        shader.inputs["Subsurface Scale"].default_value = 0.01
        shader.inputs["Sheen Weight"].default_value = 0.4
    return hall._material(name, build)


def stem_material():
    return hall._material("GreenhouseStem", lambda nodes, links: hall._principled(
        nodes, links, (0.03, 0.09, 0.025), roughness=0.55))


def laid_photo(name, asset, repeat, value, tint, saturation=0.6, per_island=True, variety=0.16, wear=0.0, ao=0.2,
               coat=0.0, coat_roughness=0.2, roughness=1.0, bevel=0.0):
    """A CC0 photo for pieces laid one by one (pavers, boards, voussoirs):
    each piece, a mesh island or with `per_island` False an object, shows its
    own part of the photo in its own shade, so no two read as one slab cut
    up, and with `wear` its rims, where the surface turns down from level,
    are worn paler, as the painting draws its stones and boards. `coat` lays
    a waxed sheen over it that catches the lamps, `roughness` scales the
    photo's, and `bevel` (m) rounds its edges in the shading."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        if per_island:
            random = nodes.new("ShaderNodeNewGeometry").outputs["Random Per Island"]
        else:
            random = nodes.new("ShaderNodeObjectInfo").outputs["Random"]
        if RP.TEXTURES is None or not os.path.exists(RP.TEXTURES._path(asset, "diff")):
            low = tuple(channel * min(value, 1.0) * 0.2 for channel in tint)
            high = tuple(channel * min(value, 1.0) * 0.32 for channel in tint)
            hall._principled(nodes, links, hall._mix(nodes, links, random, low, high), roughness=0.8)
            return
        maps = RP.TEXTURES.sample(nodes, links, asset, repeat=repeat)
        coords = next(node for node in nodes if node.type == "TEX_COORD")
        mapping = next(node for node in nodes if node.type == "MAPPING")
        width, height = next(node.image for node in nodes if node.type == "TEX_IMAGE").size
        if width and height and width != height:
            scale = mapping.inputs["Scale"].default_value
            mapping.inputs["Scale"].default_value = (scale[0], scale[1] * width / height, scale[2])
        shift = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("MULTIPLY", random, 7.31), shift.inputs["X"])
        links.new(op("MULTIPLY", random, 3.77), shift.inputs["Y"])
        moved = nodes.new("ShaderNodeVectorMath")
        moved.operation = "ADD"
        links.new(coords.outputs["UV"], moved.inputs[0])
        links.new(shift.outputs[0], moved.inputs[1])
        links.new(moved.outputs[0], mapping.inputs["Vector"])
        color = hall._grade(nodes, links, maps["diff"], value, tint, saturation=saturation)
        tone = op("ADD", 1.0 - variety, op("MULTIPLY", random, 2.0 * variety))
        shade = nodes.new("ShaderNodeCombineColor")
        for socket in ("Red", "Green", "Blue"):
            links.new(tone, shade.inputs[socket])
        color = hall._mix(nodes, links, 1.0, color, shade.outputs["Color"], blend="MULTIPLY")
        if wear > 0.0:
            geometry = nodes.new("ShaderNodeNewGeometry")
            normal = nodes.new("ShaderNodeSeparateXYZ")
            links.new(geometry.outputs["True Normal"], normal.inputs[0])
            up = normal.outputs["Z"]
            rim = op("MULTIPLY", hall._ramp(nodes, links, up, 0.995, 0.75), op("GREATER_THAN", up, 0.15))
            pale = hall._mix(nodes, links, 1.0, color, (2.2, 2.2, 2.1), blend="MULTIPLY")
            color = hall._mix(nodes, links, op("MULTIPLY", rim, wear), color, pale)
        if ao > 0.0:
            color = hall._ao_multiply(nodes, links, color, distance=ao, floor_value=0.45)
        rough = maps["rough"] if roughness == 1.0 else op("MINIMUM", op("MULTIPLY", maps["rough"], roughness), 1.0)
        normal = maps["normal"] if bevel <= 0.0 else hall._bevelled(nodes, links, maps["normal"], bevel)
        shader = hall._principled(nodes, links, color, roughness=rough, normal=normal)
        if coat > 0.0:
            shader.inputs["Coat Weight"].default_value = coat
            shader.inputs["Coat Roughness"].default_value = coat_roughness
    return hall._material(name, build)


def joints_material():
    """The floor between the pavers: dark earth in the joints, greening with
    moss toward the beds, as the painting greens the floor's edges."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        geometry = nodes.new("ShaderNodeNewGeometry")
        position = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geometry.outputs["Position"], position.inputs[0])
        # Metres either side of the aisle's middle: the beds start near 2.5.
        aside = op("ABSOLUTE", op("SUBTRACT", position.outputs["X"], GATE_CX * RP.PX))
        bedside = hall._ramp(nodes, links, aside, 1.7, 2.6)
        patches = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=5.0, detail=4.0),
                             0.45, 0.62)
        crumbs = hall._noise(nodes, links, coords.outputs["Object"], scale=150.0, detail=6.0)
        earth = hall._mix(nodes, links, crumbs, (0.006, 0.006, 0.006), (0.024, 0.022, 0.02))
        moss = hall._mix(nodes, links, crumbs, (0.01, 0.026, 0.008), (0.035, 0.08, 0.022))
        green = op("MINIMUM", op("ADD", op("MULTIPLY", patches, 0.5), op("MULTIPLY", bedside, 0.7)), 1.0)
        hall._principled(nodes, links, hall._mix(nodes, links, green, earth, moss), roughness=0.95)
    return hall._material("GreenhouseJoints", build)


# ---------------------------------------------------------------- the shell


class GreenhouseShell:
    """RP.Shell with the gate's gap left in its south wall; built by wrapping
    a Shell so the shared class stays as it is."""

    def __init__(self, spec, materials):
        self.shell = RP.Shell(spec, materials)
        self.shell._south_wall = self._south_wall

    def build(self):
        return self.shell.build()

    def side_point(self, side, u, v):
        """The side wall's face at u px along it from the back wall and v
        screen px up it, in game px (x, y, h)."""
        frame = self.shell.frames[side]
        return frame.origin + frame.along * u + frame.lean * (v / self.shell.height)

    def _south_wall(self):
        """The low south wall in two stretches, either side of the gate."""
        shell = self.shell
        south = shell.spec["south"]
        y0, y1 = south["y"], south["y"] + south.get("depth", 70.0)
        kit = RP.Kit("RoomSouth")
        for stretch, (west, east) in (("West", ("left", GATE_X[0])), ("East", (GATE_X[1], "right"))):
            def x_at(end, y, h):
                return shell.side_x(end, y, h) if isinstance(end, str) else end
            for part, (front, back), (low, high), material in (
                    ("Wall", (y0, y1), (0.0, south["height"]), shell.materials["cap"]),
                    ("Lip", (y0 - 0.5, y0 + 3.0), (south["height"], south["height"] + 0.8), shell.materials["lip"])):
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


def band(kit, part, points, width, y0, y1, material, closed=False):
    """A stone bar following `points` (x, h) in a wall plane from plan y0
    (its back) to y1 (its face): tracery, mullions, hood moulds."""
    shape = bmesh.new()
    count = len(points)
    rings = []
    for index, (x, h) in enumerate(points):
        if closed:
            before, after = points[index - 1], points[(index + 1) % count]
        else:
            before, after = points[max(index - 1, 0)], points[min(index + 1, count - 1)]
        tx, th = after[0] - before[0], after[1] - before[1]
        length = math.hypot(tx, th) or 1.0
        nx, nh = -th / length * width / 2.0, tx / length * width / 2.0
        rings.append([shape.verts.new((x + sx * nx, y, h + sx * nh)) for sx, y in ((-1, y1), (1, y1), (1, y0),
                                                                                    (-1, y0))])
    segments = range(count) if closed else range(count - 1)
    for index in segments:
        here, there = rings[index], rings[(index + 1) % count]
        for side in range(4):
            following = (side + 1) % 4
            shape.faces.new((here[side], there[side], there[following], here[following]))
    if not closed:
        shape.faces.new(list(reversed(rings[0])))
        shape.faces.new(rings[-1])
    return kit.shape(part, shape, material, bevel=0.0, uv="front")


def circle_points(cx, ch, radius, steps=32, start=0.0, end=360.0):
    return [(cx + radius * math.cos(math.radians(start + (end - start) * index / steps)),
             ch + radius * math.sin(math.radians(start + (end - start) * index / steps)))
            for index in range(steps + (0 if end - start >= 360.0 else 1))]


def tube(kit, part, points, radius, material, tip=None, segments=8):
    """A round stem through game points (x, y, h), smooth between them, true
    round in Blender space, tapering to `tip` at its end."""
    tip = radius if tip is None else tip
    path = [RP.world(*point) for point in points]
    dense = []
    for index in range(len(path) - 1):
        p0 = path[max(index - 1, 0)]
        p1, p2 = path[index], path[index + 1]
        p3 = path[min(index + 2, len(path) - 1)]
        for step in range(6):
            t = step / 6.0
            dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
                                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
    dense.append(path[-1])
    shape = bmesh.new()
    rings = []
    normal = Vector((0.0, 0.0, 1.0))
    for index, point in enumerate(dense):
        ahead = dense[min(index + 1, len(dense) - 1)] - dense[max(index - 1, 0)]
        ahead.normalize()
        if abs(ahead.dot(normal)) > 0.95:
            normal = Vector((1.0, 0.0, 0.0))
        first = ahead.cross(normal).normalized()
        second = ahead.cross(first).normalized()
        r = (radius + (tip - radius) * index / (len(dense) - 1)) * RP.PX
        rings.append([shape.verts.new(RP.game(point + (first * math.cos(2.0 * math.pi * k / segments)
                                                       + second * math.sin(2.0 * math.pi * k / segments)) * r))
                      for k in range(segments)])
    for lower, upper in zip(rings[:-1], rings[1:]):
        for k in range(segments):
            following = (k + 1) % segments
            shape.faces.new((lower[k], lower[following], upper[following], upper[k]))
    return kit.shape(part, shape, material, smooth=True, sharp_angle=70.0)


def lantern(kit, part, x, y, h, size=1.0, power=4.0, hang=False):
    """An iron lantern, the Hall's: a cage of four posts round amber glass, a
    pyramid roof with a ring, and the flame inside lighting the room."""
    s = size
    metal = iron()
    glass = hall._lantern_glass()
    kit.box(part + "Base", x - 5.5 * s, x + 5.5 * s, y - 4.2 * s, y + 4.2 * s, h, h + 2.2 * s, metal, bevel=0.4)
    for dx in (-4.6, 4.6):
        for dy in (-3.4, 3.4):
            kit.box(part + "Post", x + dx * s - 0.6 * s, x + dx * s + 0.6 * s, y + dy * s - 0.6 * s,
                    y + dy * s + 0.6 * s, h + 2.2 * s, h + 15.0 * s, metal, bevel=0.2)
    pane = kit.box(part + "Glass", x - 4.2 * s, x + 4.2 * s, y - 3.0 * s, y + 3.0 * s, h + 2.2 * s, h + 15.0 * s,
                   glass, bevel=0.0)
    pane.visible_shadow = False
    kit.box(part + "Eave", x - 6.2 * s, x + 6.2 * s, y - 4.8 * s, y + 4.8 * s, h + 15.0 * s, h + 16.6 * s, metal,
            bevel=0.4)
    kit.lathe(part + "Roof", x, y, [(6.0 * s, h + 16.6 * s), (1.2 * s, h + 22.0 * s), (0.0, h + 22.5 * s)], metal,
              plan=0.75, segments=8)
    kit.ring(part + "Ring", (x, y, h + 25.0 * s), (0.0, 1.0, 0.0), 2.2 * s, 0.5 * s, metal, segments=16, sides=6)
    flame = kit.ball(part + "Flame", x, y, h + 7.0 * s, 1.6 * s,
                     hall._glow_material("LanternFlame", (1.0, 0.8, 0.45), 24.0, (1.0, 0.8, 0.5)), plan=0.8,
                     squash=1.6)
    flame.visible_shadow = False
    kit.light(part + "Light", x, y + 0.5, h + 9.0 * s, CANDLE, power, radius=0.02 * s)
    RP.glow("lantern", x, y, h + 9.0 * s, (1.0, 0.62, 0.3), 26.0 * s)
    if hang:
        kit.rod(part + "Hook", (x, y, h + 25.0 * s), (x, y, h + 32.0 * s), 0.5 * s, metal)


def stone_post(kit, part, x, y, height, radius, material, base=0.0):
    """A turned stone post: a stepped foot, a shaft and a capital, true round,
    standing at screen height `base`."""
    profile = [(0.0, 0.0), (radius * 1.25, 0.0), (radius * 1.25, 4.0), (radius * 1.05, 6.0), (radius, 8.0),
               (radius * 0.92, height - 6.0), (radius * 1.15, height - 3.5), (radius * 1.25, height - 1.0),
               (radius * 1.25, height), (0.0, height)]
    kit.lathe(part, x, y, [(r, h + base) for r, h in profile], material, plan=ROUND, segments=24, uv="box_up")


# ---------------------------------------------------------------- models


class Models:
    """CC0 models imported once each and placed as linked copies, at their
    real size (one game px across is a centimetre) times `scale`."""

    def __init__(self):
        self.templates = {}
        self.hidden = bpy.data.collections.new("GreenhouseModelTemplates")

    def load(self, asset):
        if asset in self.templates:
            return self.templates[asset]
        folder = os.path.join(MODELS, asset)
        found = {}
        if os.path.isdir(folder):
            name = next((entry for entry in os.listdir(folder) if entry.endswith(".gltf")), None)
            if name:
                before = set(bpy.data.objects)
                bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.path.join(folder, name)))
                for obj in [obj for obj in bpy.data.objects if obj not in before]:
                    for collection in list(obj.users_collection):
                        collection.objects.unlink(obj)
                    self.hidden.objects.link(obj)
                    if obj.type == "MESH":
                        found[obj.name] = obj
        else:
            print("MODEL MISSING %s (run tools/blender/fetch_models.py)" % asset)
        self.templates[asset] = found
        return found

    def variants(self, asset, contains=""):
        return sorted(name for name in self.load(asset) if contains in name)

    def place(self, kit, asset, name, x, y, h=0.0, scale=1.0, turn=0.0, tilt=(0.0, 0.0), materials=None,
              depth=False, anchor=None):
        """A copy of `asset`'s object `name` with its foot's centre at game
        (x, y, h), turned `turn` radians about the vertical. `materials`
        swaps materials by name. `anchor` names another part of the model
        whose top centre stands at (x, y, h) instead (a potted plant's own
        soil), so the model's parts keep their places. Returns the copy, or
        None if missing."""
        template = self.load(asset).get(name)
        if template is None:
            return None
        reference = self.load(asset).get(anchor, template) if anchor else template
        corners = [reference.matrix_world @ Vector(corner) for corner in reference.bound_box]
        foot = Vector(((min(c.x for c in corners) + max(c.x for c in corners)) / 2.0,
                       (min(c.y for c in corners) + max(c.y for c in corners)) / 2.0,
                       max(c.z for c in corners) if anchor else min(c.z for c in corners)))
        copy = template.copy()
        bpy.context.scene.collection.objects.link(copy)
        copy.parent = None
        copy.matrix_world = (Matrix.Translation(RP.world(x, y, h)) @ Matrix.Rotation(turn, 4, "Z")
                             @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
                             @ Matrix.Scale(scale, 4) @ Matrix.Translation(-foot) @ template.matrix_world)
        if materials:
            copy.data = copy.data.copy()
            for index, material in enumerate(copy.data.materials):
                if material is not None and material.name in materials:
                    copy.data.materials[index] = materials[material.name]
        kit.keep(copy)
        if not depth:
            copy["no_depth"] = True
        return copy

    def group(self, kit, asset, x, y, h=0.0, scale=1.0, turn=0.0, depth=False):
        """Every part of `asset` as it was modelled (a bucket and its handle),
        the centre of their joint foot at game (x, y, h). Returns the copies."""
        parts = list(self.load(asset).values())
        if not parts:
            return []
        corners = [part.matrix_world @ Vector(corner) for part in parts for corner in part.bound_box]
        foot = Vector(((min(c.x for c in corners) + max(c.x for c in corners)) / 2.0,
                       (min(c.y for c in corners) + max(c.y for c in corners)) / 2.0,
                       min(c.z for c in corners)))
        placed = (Matrix.Translation(RP.world(x, y, h)) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Scale(scale, 4)
                  @ Matrix.Translation(-foot))
        copies = []
        for part in parts:
            copy = part.copy()
            bpy.context.scene.collection.objects.link(copy)
            copy.parent = None
            copy.matrix_world = placed @ part.matrix_world
            kit.keep(copy)
            if not depth:
                copy["no_depth"] = True
            copies.append(copy)
        return copies


MODEL = None


# ---------------------------------------------------------------- the north end


def back_wall():
    """The great window's tracery and sill, the lancets' frames, the plinth
    under the window and the hood mouldings, in the Hall's stone."""
    kit = RP.Kit("BackWall")
    stone = plinth_stone()
    face = BACK_Y
    x0, x1 = WINDOW_X
    centre = (x0 + x1) / 2.0
    glass_y = WINDOW_GLASS_Y
    outline = window_outline()
    glass = RP.polygon_mesh("GreenhouseWindowGlass", outline, [], lambda u, v: (u, glass_y, v),
                            gothic_glass("GreenhouseWindowGlass", x0, x1, WINDOW_SILL, 258.0),
                            uv_of=lambda u, v: (u, v))
    glass.visible_shadow = False
    kit.keep(glass)
    # Tracery: a mullion, two lancet heads, an oculus with a quatrefoil, all
    # standing in the glass plane.
    back, front = glass_y - 3.0, glass_y + 4.0
    band(kit, "Mullion", [(centre, WINDOW_SILL), (centre, 176.0)], 6.0, back, front, stone)
    for side, (a, b) in (("West", (x0, centre)), ("East", (centre, x1))):
        head = pointed_arch(a + 2.0, b - 2.0, 150.0, 196.0, steps=12)
        band(kit, "Lancet" + side, [(a + 2.0, WINDOW_SILL)] + head + [(b - 2.0, WINDOW_SILL)], 4.5, back, front, stone)
        band(kit, "Transom" + side, [(a, 112.0), (b, 112.0)], 3.5, back, front, stone)
    band(kit, "Oculus", circle_points(centre, 222.0, 25.0, steps=40), 4.5, back, front, stone, closed=True)
    for index in range(4):
        angle = math.radians(45.0 + 90.0 * index)
        band(kit, "Foil%d" % index, circle_points(centre + 11.0 * math.cos(angle), 222.0 + 11.0 * math.sin(angle),
                                                   9.5, steps=20), 2.4, back, front, stone, closed=True)
    # The hood moulding round the arch, standing proud of the wall's face.
    hood = pointed_arch(x0 - 9.0, x1 + 9.0, WINDOW_SPRING, 270.0, steps=20)
    band(kit, "Hood", [(x0 - 9.0, WINDOW_SPRING - 10.0)] + hood + [(x1 + 9.0, WINDOW_SPRING - 10.0)], 7.0, face,
         face + 4.0, stone)
    for x in (x0 - 9.0, x1 + 9.0):
        kit.box("HoodStop", x - 6.0, x + 6.0, face, face + 5.0, WINDOW_SPRING - 18.0, WINDOW_SPRING - 8.0, stone,
                bevel=0.8, uv="box")
    # The sill and the two-step plinth in front of it, on the collision.
    kit.box("Sill", x0 - 10.0, x1 + 10.0, face - 2.0, face + 8.0, WINDOW_SILL - 5.0, WINDOW_SILL, stone, bevel=1.0,
            uv="box")
    kit.box("PlinthLow", 376.0, 648.0, face - 1.0, 350.0, 0.0, 9.0, stone, bevel=1.2, uv="box")
    kit.box("PlinthHigh", 384.0, 640.0, face - 1.0, 334.0, 9.0, 19.0, stone, bevel=1.2, uv="box")
    for x0_, x1_ in FLANK_LANCETS:
        lancet = RP.polygon_mesh("GreenhouseFlankGlass%d" % int(x0_), lancet_outline(x0_, x1_, 72.0, 168.0, 228.0),
                                 [], lambda u, v: (u, glass_y, v),
                                 gothic_glass("GreenhouseFlankGlass%d" % int(x0_), x0_, x1_, 72.0, 228.0, bright=0.85),
                                 uv_of=lambda u, v: (u, v))
        lancet.visible_shadow = False
        kit.keep(lancet)
        hood = pointed_arch(x0_ - 6.0, x1_ + 6.0, 168.0, 238.0, steps=12)
        band(kit, "LancetHood%d" % int(x0_), [(x0_ - 6.0, 160.0)] + hood + [(x1_ + 6.0, 160.0)], 5.0, face,
             face + 3.0, stone)
        kit.box("LancetSill%d" % int(x0_), x0_ - 7.0, x1_ + 7.0, face - 2.0, face + 6.0, 66.0, 72.0, stone,
                bevel=0.8, uv="box")
        middle = (x0_ + x1_) / 2.0
        band(kit, "LancetMullion%d" % int(x0_), [(middle, 72.0), (middle, 200.0)], 3.0, glass_y - 2.0,
             glass_y + 3.0, stone)
    # The great window's moon, through the glass only: a spot behind it.
    direction = Vector((-0.12, -math.cos(math.radians(52.0)), -math.sin(math.radians(52.0)))).normalized()
    target = RP.world(centre, BACK_Y, 150.0)
    data = bpy.data.lights.new("GreenhouseMoon", "SPOT")
    data.energy = 6000.0
    data.color = MOON
    data.spot_size = math.radians(34.0)
    data.spot_blend = 0.3
    data.shadow_soft_size = 0.1
    moon = RP._link(bpy.data.objects.new("GreenhouseMoon", data))
    moon.location = target - direction * 10.0
    moon.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    for index, (a, b) in enumerate(FLANK_LANCETS):
        mid = (a + b) / 2.0
        data = bpy.data.lights.new("GreenhouseLancetMoon%d" % index, "SPOT")
        data.energy = 1400.0
        data.color = MOON
        data.spot_size = math.radians(16.0)
        data.spot_blend = 0.3
        data.shadow_soft_size = 0.1
        light = RP._link(bpy.data.objects.new("GreenhouseLancetMoon%d" % index, data))
        light.location = RP.world(mid, BACK_Y, 160.0) - direction * 10.0
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return kit


def pedestals():
    """Lanterns on stone pedestals in the pockets beside the window plinth,
    where the collision juts out from the back wall."""
    kit = RP.Kit("Pedestals")
    stone = plinth_stone()
    for index, (x, y) in enumerate(((277.0, 326.0), (746.0, 322.0))):
        kit.box("Foot%d" % index, x - 15.0, x + 15.0, y - 15.0, y + 15.0, 0.0, 5.0, stone, bevel=1.0, uv="box")
        kit.box("Shaft%d" % index, x - 11.0, x + 11.0, y - 11.0, y + 11.0, 5.0, 44.0, stone, bevel=1.0, uv="box_up")
        kit.box("Cap%d" % index, x - 14.0, x + 14.0, y - 14.0, y + 14.0, 44.0, 49.0, stone, bevel=1.0, uv="box")
        lantern(kit, "Lantern%d" % index, x, y, 49.0, size=1.15, power=5.0)
    return kit


def side_lanterns(shell):
    """Iron lanterns on brackets between the side walls' lancets."""
    kit = RP.Kit("SideLanterns")
    metal = iron()
    for side in ("left", "right"):
        for index, u in enumerate((308.0, 628.0, 948.0)):
            wall = shell.side_point(side, u, 150.0)
            out = shell.shell.frames[side].out
            hang = wall + out * 14.0
            kit.box("%sPlate%d" % (side, index), wall.x - 1.5, wall.x + 1.5, wall.y - 5.0, wall.y + 5.0,
                    wall.z - 10.0, wall.z + 10.0, metal, bevel=0.4)
            kit.rod("%sArm%d" % (side, index), tuple(wall + Vector((0.0, 0.0, 6.0))),
                    tuple(hang + Vector((0.0, 0.0, 8.0))), 0.9, metal)
            lantern(kit, "%sLantern%d" % (side, index), hang.x, hang.y, hang.z - 26.0, size=1.0, power=4.2,
                    hang=True)
    return kit


# ---------------------------------------------------------------- beds


def bed_kerb(kit, part, outline, material):
    """A raised bed's kerb round `outline` (the bed's outer edge on the
    floor): a stone wall KERB thick, KERB_H tall, with a coping on top."""
    inner = inset(outline, KERB)
    for name, (low, high), ring_out, ring_in in (("Wall", (0.0, KERB_H - 3.0), outline, inner),
                                                  ("Coping", (KERB_H - 3.0, KERB_H),
                                                   inset(outline, -1.5), inset(outline, KERB + 1.0))):
        shape = bmesh.new()
        outer_low = [shape.verts.new((x, y, low)) for x, y in ring_out]
        outer_high = [shape.verts.new((x, y, high)) for x, y in ring_out]
        inner_low = [shape.verts.new((x, y, low)) for x, y in ring_in]
        inner_high = [shape.verts.new((x, y, high)) for x, y in ring_in]
        count = len(ring_out)
        for index in range(count):
            following = (index + 1) % count
            shape.faces.new((outer_low[index], outer_low[following], outer_high[following], outer_high[index]))
            shape.faces.new((inner_low[following], inner_low[index], inner_high[index], inner_high[following]))
            shape.faces.new((outer_high[index], outer_high[following], inner_high[following], inner_high[index]))
        kit.shape(part + name, shape, material, bevel=0.8, uv="box")
    shape = bmesh.new()
    verts = [shape.verts.new((x, y, SOIL_H)) for x, y in inner]
    shape.faces.new(verts)
    kit.shape(part + "Soil", shape, soil(), uv="floor")
    return inner


def inset(outline, distance):
    """`outline` (a convex-ish ring of (x, y)) moved `distance` px inward."""
    count = len(outline)
    area = sum(outline[i][0] * outline[(i + 1) % count][1] - outline[(i + 1) % count][0] * outline[i][1]
               for i in range(count))
    sign = 1.0 if area > 0.0 else -1.0
    lines = []
    for index in range(count):
        (ax, ay), (bx, by) = outline[index], outline[(index + 1) % count]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length * sign, dx / length * sign
        lines.append(((ax + nx * distance, ay + ny * distance), (dx, dy)))
    result = []
    for index in range(count):
        (p, d), (q, e) = lines[index - 1], lines[index]
        cross = d[0] * e[1] - d[1] * e[0]
        if abs(cross) < 1e-9:
            result.append(q)
            continue
        t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / cross
        result.append((p[0] + d[0] * t, p[1] + d[1] * t))
    return result


# ---------------------------------------------------------------- props


def planter():
    """The great stone planter: a ring of dressed stone on a step with moulded
    lips, a groove round its face that hums with a faint green light, a lantern
    on each of its posts, and its planting: the glowing flower at the heart,
    blue blossom to the north, dewcap in the shaded west, emberroot in the
    sunlit east (the herb plots greenhouse_room.gd lists there)."""
    kit = RP.Kit("MagicPlanter", prop="MagicPlanter")
    cx, cy = PLANTER
    stone = kerb_stone()
    r = PLANTER_R
    rim = PLANTER_RIM_H
    earth = rim - 6.0
    # On the floor the ring is the collision's circle, so it is round on screen.
    kit.lathe("Step", cx, cy, [(0.0, 0.0), (r + 3.0, 0.0), (r + 3.0, 4.0), (r + 1.0, 5.5), (0.0, 5.5)], stone,
              plan=1.0, segments=96, uv="box")
    kit.lathe("Ring", cx, cy, [(r - 4.0, 5.0), (r - 2.0, 7.0), (r - 2.0, 9.0), (r - 4.0, 10.0),
                               (r - 4.0, rim - 6.0), (r - 1.5, rim - 4.5), (r - 0.5, rim - 2.0), (r - 1.5, rim),
                               (r - 25.0, rim), (r - 26.0, rim - 2.0), (r - 24.0, rim - 4.0), (r - 24.0, 6.0)],
              stone, plan=1.0, segments=128, close=False, uv="box")
    kit.lathe("Earth", cx, cy, [(0.0, earth), (r - 24.0, earth)], soil(), plan=1.0, segments=96, close=False)
    groove = hall._glow_material("GreenhouseGroove", (0.4, 1.0, 0.45), 0.55, (0.02, 0.04, 0.02))
    kit.lathe("Groove", cx, cy, [(r - 3.4, 15.5), (r - 3.4, 17.5)], groove, plan=1.0, segments=128, close=False)
    # Each post stands on a square plinth, as the painting has them: the
    # collision's bumps round the ring are these plinths, so the south one's
    # front reaches the bump's edge and the planter's prompt reaches the
    # player stopped there.
    for index, (x, y) in enumerate(((337.0, 580.0), (689.0, 580.0), (512.0, 760.0))):
        kit.box("PostPlinth%d" % index, x - 14.0, x + 14.0, y - 14.0, y + 16.0, 0.0, 6.0, stone, bevel=1.0,
                uv="box")
        stone_post(kit, "Post%d" % index, x, y, 30.0, 10.0, stone, base=6.0)
        lantern(kit, "Lamp%d" % index, x, y, 36.0, size=1.05, power=4.4)
    rng = random.Random(77)
    inner = r - 30.0

    def in_ring(x, y, low=0.0, high=1.0):
        distance = math.hypot(x - cx, y - cy) / inner
        return low <= distance <= high

    magic_flower(kit, cx, cy - 6.0, earth)
    # Broad leaves round the flower's foot.
    for index, angle in enumerate((0.3, 1.9, 3.4, 4.9)):
        MODEL.place(kit, "anthurium_botany_01", rng.choice(("anthurium_botany_01_b", "anthurium_botany_01_c")),
                    cx + 30.0 * math.cos(angle), cy - 6.0 + 24.0 * math.sin(angle), earth, scale=0.95,
                    turn=angle + 1.2)
    blue = flower_material("periwinkle_plant", "GreenhouseBlueBlossom", petal_hue=0.62)
    white_blue = flower_material("flower_heliophila", "GreenhouseHeliophilaBlue", white_hue=0.6, white_sat=0.45)
    # North arc: blue blossom.
    for x, y in spots(rng, (cx - 136.0, cx + 136.0, cy - inner, cy - 30.0), 44, 13.0,
                      lambda x, y: in_ring(x, y, 0.4, 1.0)):
        MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")), x, y, earth,
                    scale=rng.uniform(1.9, 2.7), turn=rng.uniform(0.0, 6.28),
                    materials={"periwinkle_plant": blue})
    for x, y in spots(rng, (cx - 110.0, cx + 110.0, cy - inner, cy - 60.0), 3, 50.0,
                      lambda x, y: in_ring(x, y, 0.55, 0.9)):
        MODEL.place(kit, "flower_heliophila", "flower_heliophila_small", x, y, earth, scale=1.3,
                    turn=rng.uniform(0.0, 6.28), materials={"flower_heliophila": white_blue})
    # West arc, in the flower's shade: dewcap.
    for x, y in spots(rng, (cx - inner, cx - 40.0, cy - 40.0, cy + 120.0), 10, 22.0,
                      lambda x, y: in_ring(x, y, 0.42, 0.92)):
        dewcap(kit, "Dewcap%d" % int(x * 10 + y), x, y, earth, rng)
    for x, y in spots(rng, (cx - inner, cx - 30.0, cy - 40.0, cy + 130.0), 9, 24.0,
                      lambda x, y: in_ring(x, y, 0.45, 1.0)):
        MODEL.place(kit, "fern_02", rng.choice(("fern_02_a", "fern_02_d", "fern_02_c")), x, y, earth,
                    scale=rng.uniform(0.7, 0.9), turn=rng.uniform(0.0, 6.28))
    # East arc, where the moon falls: emberroot.
    for index, (x, y) in enumerate(spots(rng, (cx + 40.0, cx + inner, cy - 40.0, cy + 120.0), 5, 30.0,
                                         lambda x, y: in_ring(x, y, 0.42, 0.85))):
        emberroot(kit, "Emberroot%d" % index, x, y, earth, rng)
    for x, y in spots(rng, (cx + 30.0, cx + inner, cy - 40.0, cy + 130.0), 18, 15.0,
                      lambda x, y: in_ring(x, y, 0.45, 1.0)):
        MODEL.place(kit, "flower_ursinia", rng.choice(MODEL.variants("flower_ursinia")), x, y, earth,
                    scale=rng.uniform(1.5, 2.1), turn=rng.uniform(0.0, 6.28))
    # The south arc, toward the player: low ferns and blossom over the rim.
    for x, y in spots(rng, (cx - 130.0, cx + 130.0, cy + 30.0, cy + inner), 26, 15.0,
                      lambda x, y: in_ring(x, y, 0.4, 1.0)):
        if rng.random() < 0.55:
            MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")), x, y, earth,
                        scale=rng.uniform(1.8, 2.5), turn=rng.uniform(0.0, 6.28),
                        materials={"periwinkle_plant": blue})
        else:
            MODEL.place(kit, "weed_plant_02", rng.choice(MODEL.variants("weed_plant_02")), x, y, earth,
                        scale=rng.uniform(2.0, 2.8), turn=rng.uniform(0.0, 6.28))
    return kit


def magic_flower(kit, x, y, h):
    """The glowing flower at the planter's heart: three rings of violet petals
    opening round a bright core, on a stem, with tendrils curling out over the
    soil."""
    stem = stem_material()
    tube(kit, "FlowerStem", [(x, y, h), (x + 1.5, y - 1.0, h + 9.0), (x, y - 2.0, h + 18.0)], 2.0, stem, tip=1.6)
    centre = RP.world(x, y - 2.0, h + 19.0)
    rings = ((8, 0.30, 0.15, 0.2, 0.75, 0.05, petal_material("GreenhouseOuterPetal", (0.85, 0.35, 0.95),
                                                                (0.3, 0.08, 0.42), 1.6)),
             (7, 0.24, 0.12, 0.55, 1.1, 0.06, petal_material("GreenhouseMiddlePetal", (0.95, 0.45, 1.0),
                                                                 (0.48, 0.14, 0.6), 2.2)),
             (6, 0.16, 0.09, 0.95, 1.35, 0.05, petal_material("GreenhouseInnerPetal", (1.0, 0.62, 1.0),
                                                                  (0.66, 0.26, 0.8), 3.2)))
    for ring, (count, length, width, rise0, rise1, cup, material) in enumerate(rings):
        for index in range(count):
            angle = 2.0 * math.pi * index / count + ring * 0.45
            petal(kit, "Petal%d_%d" % (ring, index), centre, angle, length, width, rise0, rise1, cup, material)
    heart = hall._glow_material("GreenhouseFlowerHeart", (1.0, 0.75, 1.0), 9.0, (1.0, 0.8, 1.0))
    kit.ball("FlowerHeart", x, y - 2.0, h + 21.0, 3.2, heart, plan=0.8)
    for index in range(9):
        angle = 2.0 * math.pi * index / 9.0
        tip = (x + 4.2 * math.cos(angle), y - 2.0 + 3.2 * math.sin(angle), h + 28.0)
        kit.rod("Stamen%d" % index, (x, y - 2.0, h + 21.0), tip, 0.25, stem)
        kit.ball("Anther%d" % index, tip[0], tip[1], tip[2], 0.7, heart, plan=0.8)
    kit.light("FlowerGlow", x, y + 8.0, h + 30.0, (0.85, 0.45, 1.0), 9.0, radius=0.05)
    RP.glow("crystal", x, y - 2.0, h + 22.0, (0.85, 0.5, 1.0), 46.0)
    # Tendrils curl out from the flower's foot over the soil.
    rng = random.Random(5)
    for index in range(7):
        angle = 2.0 * math.pi * index / 7.0 + 0.3
        reach = rng.uniform(62.0, 96.0)
        points = []
        for step in range(7):
            t = step / 6.0
            turn = angle + 1.1 * t * t
            points.append((x + math.cos(turn) * reach * t, y + math.sin(turn) * reach * t * 0.85,
                           h + 3.0 + 9.0 * math.sin(math.pi * t) * (1.0 - t) + 1.0))
        end = points[-1]
        for step in range(1, 5):
            curl = angle + 1.1 + step * 1.3
            points.append((end[0] + 6.0 * math.cos(curl) * (1.0 - step / 5.0),
                           end[1] + 5.0 * math.sin(curl) * (1.0 - step / 5.0), end[2] + step * 1.2))
        tube(kit, "Tendril%d" % index, points, 1.5, stem, tip=0.35)


def petal(kit, part, centre, angle, length, width, rise0, rise1, cup, material, steps=8, across=6):
    """One petal from `centre` (Blender space), pointing out at `angle` and
    curving up from elevation rise0 to rise1 (radians) along its `length`
    (metres), cupped by `cup`; UVs u across, v along."""
    radial = Vector((math.cos(angle), math.sin(angle), 0.0))
    side = Vector((-math.sin(angle), math.cos(angle), 0.0))
    shape = bmesh.new()
    layer = shape.loops.layers.uv.verify()
    grid = []
    point = centre.copy()
    for i in range(steps + 1):
        u = i / steps
        elevation = rise0 + (rise1 - rise0) * u
        direction = radial * math.cos(elevation) + Vector((0.0, 0.0, 1.0)) * math.sin(elevation)
        normal = side.cross(direction)
        if normal.z < 0.0:
            normal = -normal
        w = width * max(math.sin(math.pi * min(u, 0.97)) ** 0.7, 0.05) * (1.0 - 0.2 * u) / 2.0
        row = []
        for j in range(across + 1):
            v = -1.0 + 2.0 * j / across
            row.append(shape.verts.new(RP.game(point + side * (w * v) + normal * (cup * v * v * w / max(width, 1e-6)
                                                                                     * width))))
        grid.append(row)
        point = point + direction * (length / steps)
    for i in range(steps):
        for j in range(across):
            face = shape.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
            for loop, (a, b) in zip(face.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                loop[layer].uv = (a / across, b / steps)
    return kit.shape(part, shape, material, smooth=True, sharp_angle=80.0)


def dewcap(kit, part, x, y, h, rng):
    """A cluster of dewcap: pale caps on slender stems, gills faintly lit and a
    bead of condensed water on each."""
    cap = hall._material("GreenhouseDewcap", lambda nodes, links: _dewcap_shader(nodes, links))
    stalk = hall._material("GreenhouseDewcapStalk", lambda nodes, links: hall._principled(
        nodes, links, (0.55, 0.56, 0.5), roughness=0.6))
    drop = hall._material("GreenhouseDew", lambda nodes, links: _dew_shader(nodes, links))
    for index in range(rng.randint(2, 4)):
        dx, dy = rng.uniform(-8.0, 8.0), rng.uniform(-6.0, 6.0)
        tall = rng.uniform(7.0, 15.0)
        radius = rng.uniform(3.2, 5.6)
        cx, cy = x + dx, y + dy
        kit.lathe("%sStalk%d" % (part, index), cx, cy, [(0.0, h), (0.9, h), (0.7, h + tall), (0.0, h + tall)], stalk,
                  plan=ROUND, segments=10)
        kit.lathe("%sCap%d" % (part, index), cx, cy, [(0.0, h + tall - 1.0), (radius, h + tall - 0.6),
                                                      (radius * 0.95, h + tall + 0.6), (radius * 0.7, h + tall + 2.4),
                                                      (radius * 0.35, h + tall + 3.4), (0.0, h + tall + 3.7)], cap,
                  plan=ROUND, segments=18)
        kit.ball("%sDrop%d" % (part, index), cx + radius * 0.3, cy - radius * 0.2, h + tall + 3.6, 0.9, drop,
                 plan=0.8)
    RP.glow("crystal", x, y, h + 10.0, DEW, 10.0)


def _dewcap_shader(nodes, links):
    coords = nodes.new("ShaderNodeTexCoord")
    speck = hall._noise(nodes, links, coords.outputs["Object"], scale=300.0, detail=3.0)
    color = hall._mix(nodes, links, speck, (0.62, 0.68, 0.7), (0.82, 0.86, 0.84))
    shader = hall._principled(nodes, links, color, roughness=0.45, emission=DEW, emission_strength=0.25)
    shader.inputs["Subsurface Weight"].default_value = 0.5
    shader.inputs["Subsurface Scale"].default_value = 0.01


def _dew_shader(nodes, links):
    shader = hall._principled(nodes, links, (0.8, 0.95, 1.0), roughness=0.02, emission=DEW, emission_strength=1.6)
    shader.inputs["Transmission Weight"].default_value = 0.8
    shader.inputs["IOR"].default_value = 1.33


def emberroot(kit, part, x, y, h, rng):
    """Emberroot: knotted roots heaving out of the soil, their split bark
    glowing with the heat they store, and a few orange flowers above."""
    material = hall._material("GreenhouseEmberroot", lambda nodes, links: _ember_shader(nodes, links))
    for index in range(3):
        angle = rng.uniform(0.0, 6.28)
        length = rng.uniform(14.0, 24.0)
        points = []
        for step in range(6):
            t = step / 5.0
            points.append((x + math.cos(angle + 0.7 * t) * length * (t - 0.5),
                           y + math.sin(angle + 0.7 * t) * length * (t - 0.5) * 0.8,
                           h - 1.0 + 4.5 * math.sin(math.pi * t)))
        tube(kit, "%sRoot%d" % (part, index), points, rng.uniform(1.8, 2.6), material, tip=0.8)
    kit.light(part + "Heat", x, y + 4.0, h + 6.0, EMBER, 1.2, radius=0.03)
    RP.glow("candle", x, y, h + 3.0, EMBER, 14.0)


def _ember_shader(nodes, links):
    coords = nodes.new("ShaderNodeTexCoord")
    cracks = nodes.new("ShaderNodeTexVoronoi")
    cracks.feature = "DISTANCE_TO_EDGE"
    cracks.inputs["Scale"].default_value = 120.0
    links.new(coords.outputs["Object"], cracks.inputs["Vector"])
    split = hall._ramp(nodes, links, cracks.outputs["Distance"], 0.08, 0.0)
    bark = hall._mix(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=200.0, detail=4.0),
                     (0.05, 0.025, 0.015), (0.14, 0.06, 0.03))
    op = hall._MathBuilder(nodes, links)
    hall._principled(nodes, links, bark, roughness=0.7, emission=EMBER, emission_strength=op("MULTIPLY", split, 6.0))


def flower_material(source, name, petal_hue=None, white_hue=None, white_sat=0.5, hue_all=None, saturation=1.0,
                    value=1.0, shift=None):
    """A copy of an imported plant's material, graded: magenta petals turned
    to `petal_hue`, white petals tinted `white_hue`, the whole of it moved to
    `hue_all`, or (with `shift`) its hue turned by `shift`; a whole-material
    grade also scales saturation and value. Leaves keep their green unless the
    whole is graded. `source` is the model's asset name, which is also its
    material's."""
    MODEL.load(source)
    original = bpy.data.materials.get(source)
    if original is None:
        return None
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    material = original.copy()
    material.name = name
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    socket = shader.inputs["Base Color"]
    if not socket.links:
        return material
    colour = socket.links[0].from_socket
    op = hall._MathBuilder(nodes, links)
    split = nodes.new("ShaderNodeSeparateColor")
    split.mode = "HSV"
    links.new(colour, split.inputs["Color"])
    hue, sat, val = split.outputs["Red"], split.outputs["Green"], split.outputs["Blue"]
    joined = nodes.new("ShaderNodeCombineColor")
    joined.mode = "HSV"
    if hue_all is not None or shift is not None:
        if hue_all is not None:
            joined.inputs["Red"].default_value = hue_all
        else:
            links.new(op("FRACT", op("ADD", hue, shift)), joined.inputs["Red"])
        links.new(op("MULTIPLY", sat, saturation), joined.inputs["Green"])
        links.new(op("MINIMUM", op("MULTIPLY", val, value), 1.0), joined.inputs["Blue"])
        links.new(joined.outputs["Color"], socket)
        return material
    if petal_hue is not None:
        magenta = op("MAXIMUM", op("GREATER_THAN", hue, 0.7), op("LESS_THAN", hue, 0.03))
        mask = op("MULTIPLY", magenta, op("GREATER_THAN", sat, 0.25))
        joined.inputs["Red"].default_value = petal_hue
        links.new(sat, joined.inputs["Green"])
        links.new(op("MINIMUM", op("MULTIPLY", val, value), 1.0), joined.inputs["Blue"])
    else:
        mask = op("MULTIPLY", op("LESS_THAN", sat, 0.2), op("GREATER_THAN", val, 0.55))
        joined.inputs["Red"].default_value = white_hue
        joined.inputs["Green"].default_value = white_sat
        links.new(op("MULTIPLY", val, 0.85), joined.inputs["Blue"])
    links.new(hall._mix(nodes, links, mask, colour, joined.outputs["Color"]), socket)
    return material


def moonleaf_material():
    """Moonleaf: calathea's own silver bands, turned toward the moon's cyan."""
    return flower_material("calathea_orbifolia_01", "GreenhouseMoonleaf", shift=0.12, saturation=0.62, value=1.25)


def spots(rng, box, count, spacing, inside=None, tries=4000):
    """Up to `count` points in box (x0, x1, y0, y1) where inside(x, y) holds,
    at least `spacing` px apart."""
    x0, x1, y0, y1 = box
    chosen = []
    for _attempt in range(tries):
        if len(chosen) >= count:
            break
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if inside is not None and not inside(x, y):
            continue
        if any((x - a) ** 2 + (y - b) ** 2 < spacing * spacing for a, b in chosen):
            continue
        chosen.append((x, y))
    return chosen


def in_polygon(x, y, outline):
    inside = False
    count = len(outline)
    for index in range(count):
        (ax, ay), (bx, by) = outline[index], outline[(index + 1) % count]
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
    return inside


def leaf_mesh(kit, part, points, size, material, rng, droop=0.4):
    """Small leaves along `points` (game px): each a folded blade, turned at
    random, for vines the models do not have."""
    shape = bmesh.new()
    for x, y, h in points:
        base = RP.world(x, y, h)
        turn = rng.uniform(0.0, 6.28)
        out = Vector((math.cos(turn), math.sin(turn), -droop)).normalized()
        side = Vector((-math.sin(turn), math.cos(turn), 0.0))
        up = out.cross(side).normalized()
        length = size * rng.uniform(0.8, 1.2) * RP.PX
        tip = base + out * length
        width = length * 0.42
        verts = [shape.verts.new(RP.game(base)), shape.verts.new(RP.game(base + out * length * 0.45 + side * width
                                                                          + up * width * 0.3)),
                 shape.verts.new(RP.game(tip)), shape.verts.new(RP.game(base + out * length * 0.45 - side * width
                                                                        + up * width * 0.3))]
        shape.faces.new(verts[:3])
        shape.faces.new([verts[0], verts[2], verts[3]])
    return kit.shape(part, shape, material, smooth=True, sharp_angle=60.0)


# ---------------------------------------------------------------- the bench


def wood_boxes(kit, part, boxes, material, grain="x", photo_grain="u", bevel=0.5):
    """Wooden boxes as one object: each (x0, x1, y0, y1, h0, h1) or with a
    turn about the vertical (radians) as a seventh value, and each taking its
    own part of the photo (laid_photo, per island). The photo's grain, along
    its u or v (`photo_grain`), is laid along the world axis `grain`."""
    shape = bmesh.new()
    layer = shape.loops.layers.uv.verify()
    size = 100.0 * RP.ROOM_TEXTURE_SCALE
    for box in boxes:
        x0, x1, y0, y1, h0, h1 = box[:6]
        turn = box[6] if len(box) > 6 else 0.0
        made = bmesh.ops.create_cube(shape, size=1.0, matrix=(
            Matrix.Translation(((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h0 + h1) / 2.0)) @ Matrix.Rotation(turn, 4, "Z")
            @ Matrix.Diagonal((max(x1 - x0, 0.05), max(y1 - y0, 0.05), max(h1 - h0, 0.05), 1.0))))
        for face in {face for vert in made["verts"] for face in vert.link_faces}:
            face.normal_update()
            nx, ny, nh = (abs(component) for component in face.normal)
            plane = "h" if nh >= max(nx, ny) else ("y" if ny >= nx else "x")
            axes = {"h": ("x", "y"), "y": ("x", "h"), "x": ("y", "h")}[plane]
            order = (grain, axes[1] if axes[0] == grain else axes[0]) if grain in axes else axes
            if photo_grain == "v":
                order = (order[1], order[0])
            for loop in face.loops:
                position = dict(zip("xyh", loop.vert.co))
                loop[layer].uv = (position[order[0]] / size, position[order[1]] / size)
    return kit.shape(part, shape, material, bevel=bevel)


def turned_box(kit, part, cx, cy, h0, h1, width, depth, turn, material, bevel=0.3, uv="box"):
    """A block `width` x `depth` in plan, centred (cx, cy) and turned `turn`
    radians, from h0 to h1."""
    shape = bmesh.new()
    bmesh.ops.create_cube(shape, size=1.0, matrix=(
        Matrix.Translation((cx, cy, (h0 + h1) / 2.0)) @ Matrix.Rotation(turn, 4, "Z")
        @ Matrix.Diagonal((width, depth, max(h1 - h0, 0.05), 1.0))))
    return kit.shape(part, shape, material, bevel=bevel, uv=uv)


def turned_quad(kit, part, cx, cy, h, width, depth, turn, material):
    """A level sheet `width` x `depth` centred (cx, cy), turned `turn`
    radians, UVs 0..1 with v running north."""
    cosine, sine = math.cos(turn), math.sin(turn)
    corners = []
    for sx, sy in ((-1.0, 1.0), (1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)):
        dx, dy = sx * width / 2.0, sy * depth / 2.0
        corners.append((cx + dx * cosine - dy * sine, cy + dx * sine + dy * cosine, h))
    return kit.quad(part, corners, material)


def workbench():
    """The gardener's potting bench, as the painting draws it: a top of six
    worn boards running across, bound at its corners with riveted iron, on
    square legs with a slatted shelf below, crowded with his work: a fern in
    a big pot, the lantern, seedlings in pots and in their tray, jars of seed,
    the open handbook, a mortar of crushed petals, moonleaf laid on a little
    drying rack, cut herbs and twigs, a trowel and the repair map, and the
    watering can on the shelf. His round stool is pushed in under the front.
    The tray and the rack lie where the game shows its glow for them on
    screen, at (440, 965) and (590, 965)."""
    kit = RP.Kit("Workbench", prop="Workbench")
    x0, x1, y0, y1 = BENCH
    top = BENCH_TOP
    rng = random.Random(31)
    wood = bench_wood()
    metal = iron()
    # The frame: legs, aprons under the top, low rails and the slatted shelf.
    legs = [(x - 6.0, x + 6.0, y - 6.0, y + 6.0, 0.0, top - 4.5) for x in (x0 + 9.0, x1 - 9.0)
            for y in (y0 + 9.0, y1 - 9.0)]
    wood_boxes(kit, "Legs", legs, wood, grain="h", bevel=0.8)
    wood_boxes(kit, "Aprons", [(x0 + 4.0, x1 - 4.0, y1 - 8.0, y1 - 3.0, top - 13.0, top - 4.5),
                               (x0 + 4.0, x1 - 4.0, y0 + 3.0, y0 + 8.0, top - 13.0, top - 4.5),
                               (x0 + 15.0, x1 - 15.0, y1 - 12.0, y1 - 6.0, 6.0, 11.0),
                               (x0 + 15.0, x1 - 15.0, y0 + 6.0, y0 + 12.0, 6.0, 11.0)], wood, grain="x", bevel=0.6)
    wood_boxes(kit, "SideAprons", [(x0 + 3.0, x0 + 8.0, y0 + 15.0, y1 - 15.0, top - 13.0, top - 4.5),
                                   (x1 - 8.0, x1 - 3.0, y0 + 15.0, y1 - 15.0, top - 13.0, top - 4.5)], wood,
               grain="y", bevel=0.6)
    # Slats 17 cm wide, 5 cm apart, centred between the rails.
    inner0, inner1 = y0 + 12.0, y1 - 12.0
    slats = int((inner1 - inner0 + 4.0) // 17.0)
    start = (inner0 + inner1 - 17.0 * slats + 4.0) / 2.0
    wood_boxes(kit, "Shelf", [(x0 + 15.0, x1 - 15.0, start + 17.0 * index, start + 17.0 * index + 13.0, 11.0, 13.5)
                              for index in range(slats)], wood, grain="x", bevel=0.4)
    # The top: six boards running across it, their ends and faces uneven.
    boards = []
    span = (y1 + 4.0) - (y0 - 4.0)
    for index in range(6):
        b0 = y0 - 4.0 + span * index / 6.0 + 0.6
        b1 = y0 - 4.0 + span * (index + 1) / 6.0 - 0.6
        lift = rng.uniform(-0.3, 0.3)
        boards.append((x0 - 5.0 + rng.uniform(-1.5, 1.5), x1 + 5.0 + rng.uniform(-1.5, 1.5), b0, b1,
                       top - 4.5 + lift, top + lift, math.radians(rng.uniform(-0.25, 0.25))))
    wood_boxes(kit, "Top", boards, wood, grain="x", bevel=0.7)
    # Riveted iron at its corners: an L on the top and a strap down the front.
    for edge_x, out_x in ((x0 - 4.0, 1.0), (x1 + 4.0, -1.0)):
        for edge_y, out_y in ((y0 - 3.0, 1.0), (y1 + 3.0, -1.0)):
            far_x, far_y = edge_x + out_x * 20.0, edge_y + out_y * 20.0
            kit.box("IronX", min(edge_x, far_x), max(edge_x, far_x), min(edge_y, edge_y + out_y * 4.0),
                    max(edge_y, edge_y + out_y * 4.0), top + 0.25, top + 0.9, metal, bevel=0.2)
            kit.box("IronY", min(edge_x, edge_x + out_x * 4.0), max(edge_x, edge_x + out_x * 4.0),
                    min(edge_y, far_y), max(edge_y, far_y), top + 0.25, top + 0.9, metal, bevel=0.2)
            for along in (7.0, 16.0):
                kit.ball("Rivet", edge_x + out_x * along, edge_y + out_y * 2.0, top + 1.0, 0.75, metal, plan=0.8)
                kit.ball("Rivet", edge_x + out_x * 2.0, edge_y + out_y * along, top + 1.0, 0.75, metal, plan=0.8)
            if out_y < 0.0:
                kit.box("FrontStrap", min(edge_x, edge_x + out_x * 4.0), max(edge_x, edge_x + out_x * 4.0),
                        y1 + 4.0, y1 + 4.8, top - 13.0, top + 0.6, metal, bevel=0.2)
    clutter(kit, top, rng)
    shelf_things(kit, rng)
    MODEL.place(kit, "wooden_stool_01", "wooden_stool_01", STOOL[0], STOOL[1], scale=1.0, turn=0.3, depth=True)
    return kit


def bench_wood():
    """The bench's weathered oak, as the painting draws it: rough-sawn boards
    from a worn tabletop photo, greyed by the damp (an albedo near sRGB 115,
    87, 70, as weathered oak's), each board its own part and shade of it, its
    rims worn paler by hands and soil in its corners; matte, as unfinished
    wood is."""
    return laid_photo("GreenhouseBench", "wood_table", 1.0, 1.4, (0.96, 0.86, 0.74), saturation=0.62, variety=0.2,
                      wear=0.4, ao=0.3, bevel=0.012)


def clutter(kit, top, rng):
    """What lies on the bench, placed as the painting places it."""
    wood = bench_wood()
    # The fern in its big pot and the lantern, at the back.
    scale = 1.15
    MODEL.place(kit, "planter_pot_clay", "planter_pot_clay", 566.0, 990.0, top, scale=scale, turn=0.5, depth=True)
    earth = top + 21.0 * scale * hall.SIN_ALPHA
    kit.lathe("FernEarth", 566.0, 990.0, [(0.0, earth), (11.6 * scale, earth)], soil(), plan=ROUND, segments=40,
              close=False)
    MODEL.place(kit, "fern_02", "fern_02_b", 566.0, 990.0, earth - 1.0, scale=0.62, turn=0.9)
    lantern(kit, "BenchLantern", 512.0, 996.0, top, size=1.1, power=18.0)
    # Seedlings in small pots in the back's east corner.
    for index, (x, y, scale) in enumerate(((610.0, 980.0, 0.6), (628.0, 987.0, 0.52), (622.0, 999.0, 0.45))):
        MODEL.place(kit, "planter_pot_clay", "planter_pot_clay", x, y, top, scale=scale, turn=index * 1.7)
        earth = top + 21.0 * scale * hall.SIN_ALPHA
        kit.lathe("SeedlingEarth%d" % index, x, y, [(0.0, earth), (11.6 * scale, earth)], soil(), plan=ROUND,
                  segments=24, close=False)
        MODEL.place(kit, "weed_plant_02", rng.choice(MODEL.variants("weed_plant_02")), x, y, earth - 0.5,
                    scale=rng.uniform(0.7, 0.9), turn=rng.uniform(0.0, 6.28))
    # Jars of seed and a small potted plant at the west end, a basket of
    # picked blossom beside them and a bowl of bulbs by the lantern.
    seed_jars(kit, 404.0, 983.0, top, scale=1.1)
    rim = top + 33.6 * 0.5 * hall.SIN_ALPHA
    for part in ("potted_plant_02_pot", "potted_plant_02_dirt", "potted_plant_02_leaves"):
        MODEL.place(kit, "potted_plant_02", part, 444.0, 988.0, rim, scale=0.42, anchor="potted_plant_02_pot")
    MODEL.place(kit, "wicker_basket_01", "wicker_basket_01", 474.0, 990.0, top, scale=0.5, turn=0.25)
    blue = flower_material("periwinkle_plant", "GreenhouseBlueBlossom", petal_hue=0.62)
    for _sprig in range(6):
        MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")),
                    474.0 + rng.uniform(-4.0, 4.0), 990.0 + rng.uniform(-2.5, 2.5), top + 2.5,
                    scale=rng.uniform(0.8, 1.0), turn=rng.uniform(0.0, 6.28), materials={"periwinkle_plant": blue})
    MODEL.place(kit, "wooden_bowl_01", "wooden_bowl_01", 540.0, 986.0, top, scale=0.42, turn=0.7)
    # The seedling tray, where the game marks the seedlings to pick.
    tx, ty = 440.0, 1015.0
    tray = laid_photo("GreenhouseTray", "wood_cabinet_worn_long", 0.4, 0.8, (0.9, 0.76, 0.64), saturation=0.8)
    wood_boxes(kit, "Tray", [(tx - 23.0, tx + 23.0, ty - 15.0, ty - 12.5, top, top + 5.0),
                             (tx - 23.0, tx + 23.0, ty + 12.5, ty + 15.0, top, top + 5.0),
                             (tx - 23.0, tx - 20.5, ty - 12.5, ty + 12.5, top, top + 5.0),
                             (tx + 20.5, tx + 23.0, ty - 12.5, ty + 12.5, top, top + 5.0),
                             (tx - 22.0, tx + 22.0, ty - 14.0, ty + 14.0, top, top + 1.0)], tray, grain="x",
               photo_grain="v", bevel=0.3)
    kit.box("TrayEarth", tx - 20.5, tx + 20.5, ty - 12.5, ty + 12.5, top + 1.0, top + 3.8, soil(), bevel=0.0)
    sprout = hall._material("GreenhouseSprout", lambda nodes, links: hall._principled(
        nodes, links, (0.12, 0.3, 0.07), roughness=0.5))
    shoots = []
    for row in range(4):
        for column in range(5):
            point = (tx - 15.0 + column * 7.5 + rng.uniform(-1.0, 1.0), ty - 9.5 + row * 6.4 + rng.uniform(-1.0, 1.0),
                     top + 3.8)
            kit.rod("Shoot%d_%d" % (row, column), point, (point[0], point[1], point[2] + 3.4), 0.3, sprout,
                    segments=6)
            shoots += [(point[0], point[1], point[2] + 3.4)] * 2
    leaf_mesh(kit, "Seedlings", shoots, 3.6, sprout, rng, droop=0.05)
    # The open handbook in the middle, a real one's size (46 by 31 cm).
    bx, by, turn = 517.0, 1028.0, math.radians(-5.0)
    turned_box(kit, "BookCover", bx, by, top, top + 1.0, 46.0, 24.0, turn,
               hall._cloth("GreenhouseBookCover", (0.16, 0.07, 0.04)))
    for side in (-1.0, 1.0):
        turned_box(kit, "BookPages%d" % int(side), bx + side * 11.3 * math.cos(turn), by + side * 11.3 * math.sin(turn),
                   top + 1.0, top + 2.8, 21.5, 22.0, turn, hall._parchment())
    turned_quad(kit, "BookText", bx, by, top + 2.85, 43.6, 21.6, turn, writing())
    # A stone mortar of crushed violet petals, its pestle leant in it.
    mx, my = 624.0, 1030.0
    stone = kerb_stone()
    kit.lathe("Mortar", mx, my, [(0.0, top), (5.6, top), (8.2, top + 4.0), (8.6, top + 8.2), (7.4, top + 8.6),
                                 (6.6, top + 5.4), (0.0, top + 3.4)], stone, plan=ROUND, segments=28)
    crushed = hall._material("GreenhouseCrushedPetals", lambda nodes, links: hall._principled(
        nodes, links, (0.42, 0.12, 0.5), roughness=0.5))
    for index in range(16):
        angle, reach = rng.uniform(0.0, 6.28), rng.uniform(0.0, 5.2)
        kit.ball("Crushed%d" % index, mx + reach * math.cos(angle), my + reach * math.sin(angle) * ROUND,
                 top + 6.4, rng.uniform(0.8, 1.4), crushed, plan=0.8, squash=0.4)
    kit.rod("Pestle", (mx - 2.0, my, top + 5.0), (mx + 7.0, my - 8.0, top + 17.0), 1.4, stone)
    # Moonleaf drying on a low rack, where the game marks the drying rack.
    rx, ry = 590.0, 1015.0
    wood_boxes(kit, "Rack", [(rx - 19.0, rx - 16.5, ry - 13.0, ry + 13.0, top, top + 6.0),
                             (rx + 16.5, rx + 19.0, ry - 13.0, ry + 13.0, top, top + 6.0)]
               + [(rx - 19.0, rx + 19.0, ry - 12.0 + 6.0 * slat, ry - 9.5 + 6.0 * slat, top + 6.0, top + 7.2)
                  for slat in range(5)], wood, grain="x", bevel=0.25)
    leaf = hall._material("GreenhouseDryingMoonleaf", lambda nodes, links: _drying_leaf_shader(nodes, links))
    blades(kit, "DryingLeaves", [(rx + rng.uniform(-12.0, 12.0), ry + rng.uniform(-8.0, 8.0), top + 7.6,
                                  rng.uniform(0.0, math.pi), rng.uniform(11.0, 14.0), rng.uniform(4.6, 5.6))
                                 for _leaf in range(8)], leaf)
    # Cut herbs and twigs, a bunch of dried flowers, the trowel and the map.
    twig = hall._material("GreenhouseTwig", lambda nodes, links: hall._principled(
        nodes, links, (0.09, 0.055, 0.03), roughness=0.7))
    for index in range(8):
        x, y = rng.uniform(444.0, 462.0), rng.uniform(1038.0, 1045.0)
        angle, length = rng.uniform(-0.35, 0.2), rng.uniform(12.0, 24.0)
        kit.rod("Twig%d" % index, (x, y, top + 0.8), (x + length * math.cos(angle), y + length * math.sin(angle),
                                                      top + 0.8), rng.uniform(0.35, 0.6), twig, segments=6)
    herbs = [(rng.uniform(466.0, 488.0), rng.uniform(1024.0, 1046.0), top + 1.4) for _leaf in range(10)]
    leaf_mesh(kit, "CutHerbs", herbs, 4.5, stem_material(), rng, droop=0.0)
    dried = hall._material("GreenhouseDriedFlowers", lambda nodes, links: hall._principled(
        nodes, links, (0.4, 0.14, 0.3), roughness=0.6))
    for index in range(6):
        end = (482.0 + rng.uniform(-3.0, 3.0), 1006.0 + rng.uniform(-2.5, 2.5), top + 1.0)
        kit.rod("DriedStem%d" % index, (468.0, 1016.0, top + 1.0), end, 0.35, twig, segments=6)
        kit.ball("DriedHead%d" % index, end[0], end[1], end[2] + 0.6, 1.4, dried, plan=0.8)
    MODEL.place(kit, "trowel_01", "trowel_01", 556.0, 1040.0, top, scale=1.0, turn=1.9)
    MODEL.place(kit, "planter_pot_clay", "planter_pot_clay", 552.0, 1006.0, top + 5.4, scale=0.5, turn=0.4,
                tilt=(0.0, 1.45))
    turned_quad(kit, "RepairMap", 420.0, 1041.0, top + 0.3, 30.0, 19.0, 0.12, hall.material_blueprint())
    kit.rod("MapRoll", (434.0, 1033.0, top + 2.2), (432.0, 1050.0, top + 2.2), 2.2, hall.material_blueprint())
    # Soil spilt from the pots, and petals.
    crumbs = bmesh.new()
    for x, y in spots(rng, (580.0, 640.0, 976.0, 1000.0), 18, 3.0) + spots(rng, (388.0, 414.0, 994.0, 1030.0), 12, 3.0):
        size = rng.uniform(0.6, 1.4)
        corners = [crumbs.verts.new((x + size * math.cos(angle), y + size * math.sin(angle), top + 0.35))
                   for angle in (0.3, 2.2, 4.1)]
        crumbs.faces.new(corners)
    kit.shape("Crumbs", crumbs, soil())
    petals = bmesh.new()
    for x, y in spots(rng, (598.0, 640.0, 1030.0, 1048.0), 12, 3.5):
        turn = rng.uniform(0.0, 6.28)
        size = rng.uniform(1.4, 2.2)
        corners = [petals.verts.new((x + size * along * math.cos(turn) - size * across * math.sin(turn),
                                     y + size * along * math.sin(turn) + size * across * math.cos(turn), top + 0.4))
                   for along, across in ((-1.0, 0.0), (0.0, 0.6), (1.0, 0.0), (0.0, -0.6))]
        petals.faces.new(corners)
    kit.shape("Petals", petals, crushed)


def blades(kit, part, placements, material):
    """Leaves laid flat, each (x, y, h, turn, length, width): a pointed oval
    with its midrib raised, UVs u across it and v along it."""
    shape = bmesh.new()
    layer = shape.loops.layers.uv.verify()
    for x, y, h, turn, length, width in placements:
        cosine, sine = math.cos(turn), math.sin(turn)

        def at(along, across, lift):
            return shape.verts.new((x + along * cosine - across * sine, y + along * sine + across * cosine, h + lift))

        steps = 6
        rib = [at(length * step / steps - length / 2.0, 0.0, 0.5 * math.sin(math.pi * step / steps))
               for step in range(steps + 1)]
        for side in (-1.0, 1.0):
            edge = [rib[0]] + [at(length * step / steps - length / 2.0,
                                  side * width / 2.0 * math.sin(math.pi * step / steps) ** 0.75, 0.0)
                               for step in range(1, steps)] + [rib[-1]]
            for step in range(steps):
                quad = [rib[step], rib[step + 1], edge[step + 1], edge[step]]
                if quad[2] is quad[1]:
                    quad = quad[:2] + quad[3:]
                elif quad[3] is quad[0]:
                    quad = quad[:3]
                face = shape.faces.new(quad if side > 0 else list(reversed(quad)))
                for loop in face.loops:
                    position = loop.vert.co
                    dx, dy = position.x - x, position.y - y
                    along = dx * cosine + dy * sine
                    across = -dx * sine + dy * cosine
                    loop[layer].uv = (0.5 + across / width, 0.5 + along / length)
    return kit.shape(part, shape, material, smooth=True, sharp_angle=80.0)


def _drying_leaf_shader(nodes, links):
    """Moonleaf drying: silver-green, its midrib and veins paler."""
    op = hall._MathBuilder(nodes, links)
    geometry = nodes.new("ShaderNodeNewGeometry")
    _coords, u, v = hall._uv_parts(nodes, links)
    middle = op("ABSOLUTE", op("SUBTRACT", u, 0.5))
    rib = op("LESS_THAN", middle, 0.04)
    veins = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("ADD", op("MULTIPLY", v, 6.0),
                                                                                         op("MULTIPLY", middle, 4.0))),
                                                                       0.5)), 0.06),
                op("GREATER_THAN", middle, 0.06))
    color = hall._mix(nodes, links, geometry.outputs["Random Per Island"], (0.13, 0.19, 0.17), (0.24, 0.32, 0.29))
    color = hall._mix(nodes, links, op("MAXIMUM", rib, op("MULTIPLY", veins, 0.6)), color, (0.42, 0.5, 0.46))
    hall._principled(nodes, links, color, roughness=0.45)


def shelf_things(kit, rng):
    """On the slatted shelf: a stack of pots, the watering can, a basket and a
    bucket."""
    shelf = 13.5
    for index, h in enumerate((shelf, shelf + 11.0)):
        MODEL.place(kit, "planter_pot_clay", "planter_pot_clay", 420.0, 1010.0, h, scale=0.85, turn=index * 0.9)
    MODEL.place(kit, "wicker_basket_01", "wicker_basket_01", 598.0, 1010.0, shelf, scale=0.8, turn=0.2)
    MODEL.place(kit, "watering_can_metal_01", "watering_can_metal_01", 478.0, 1010.0, shelf, scale=1.0, turn=1.6)
    MODEL.group(kit, "wooden_bucket_01", 540.0, 1012.0, shelf, scale=0.7, turn=rng.uniform(0.0, 6.28))


def seed_jars(kit, x, y, h, scale=1.0):
    glass = hall._material("GreenhouseJarGlass", lambda nodes, links: _jar_glass(nodes, links))
    seeds = (hall._cloth("GreenhouseSeedsDark", (0.09, 0.05, 0.03)), hall._cloth("GreenhouseSeedsPale",
                                                                                (0.4, 0.33, 0.18)))
    s = scale
    for index, (dx, dy, tall) in enumerate(((0.0, 0.0, 14.0), (10.0, 4.0, 11.0), (-8.0, 6.0, 9.0))):
        jx, jy, tall = x + dx * s, y + dy * s, tall * s
        jar = kit.lathe("Jar%d" % index, jx, jy, [(3.6 * s, h), (4.0 * s, h + 1.0), (4.0 * s, h + tall - 2.0),
                                                  (3.0 * s, h + tall), (3.0 * s, h + tall + 1.4)], glass,
                        plan=ROUND, segments=20, close=False)
        jar.visible_shadow = False
        kit.lathe("Seeds%d" % index, jx, jy, [(0.0, h + 0.5), (3.4 * s, h + 0.5), (3.4 * s, h + tall * 0.55),
                                              (0.0, h + tall * 0.6)], seeds[index % 2], plan=ROUND, segments=16)
        kit.lathe("Cork%d" % index, jx, jy, [(0.0, h + tall + 1.0), (3.2 * s, h + tall + 1.0),
                                             (3.4 * s, h + tall + 3.6), (0.0, h + tall + 3.6)],
                  hall._cloth("GreenhouseCork", (0.36, 0.24, 0.14)), plan=ROUND, segments=16)


def _jar_glass(nodes, links):
    shader = hall._principled(nodes, links, (0.9, 0.95, 0.93), roughness=0.05)
    shader.inputs["Transmission Weight"].default_value = 1.0
    shader.inputs["IOR"].default_value = 1.1


def writing():
    """Parchment written in brown ink in two columns, UVs 0..1 across."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        stain = hall._noise(nodes, links, coords.outputs["UV"], scale=5.0, detail=5.0)
        words = hall._noise(nodes, links, coords.outputs["UV"], scale=40.0, detail=1.0)
        row = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", v, 11.0)), 0.5))
        page = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", u, 2.0)), 0.5))
        ink = op("MULTIPLY", op("MULTIPLY", op("LESS_THAN", row, 0.14), op("GREATER_THAN", words, 0.44)),
                 op("LESS_THAN", page, 0.4))
        color = hall._mix(nodes, links, stain, (0.5, 0.42, 0.27), (0.72, 0.63, 0.45))
        color = hall._mix(nodes, links, ink, color, (0.13, 0.08, 0.05))
        hall._principled(nodes, links, color, roughness=0.86)
    return hall._material("GreenhouseHandbook", build)


# ---------------------------------------------------------------- the long beds


def beds():
    """The two long raised beds, painted into the game's art (so part of the
    room render): stone kerbs, dark soil and their planting. West, blue
    blossom with the ironvine trellis and the valves for light, water and
    air; east, moonleaf with its silver pods and the mineral patch."""
    kit = RP.Kit("Beds")
    stone = kerb_stone()
    west = bed_kerb(kit, "West", LEFT_BED, stone)
    east = bed_kerb(kit, "East", RIGHT_BED, stone)
    rng = random.Random(911)
    blue = flower_material("periwinkle_plant", "GreenhouseBlueBlossom", petal_hue=0.62)
    white_blue = flower_material("flower_heliophila", "GreenhouseHeliophilaBlue", white_hue=0.6, white_sat=0.45)
    moon_leaf = moonleaf_material()
    # West: blue blossom thick in the upper rows, the ironvine trellis in the
    # middle, then blossom, ferns and nettles below, where the bench's light
    # falls. Low plants first along the aisle kerb, so the bed spills over it.
    inside_west = inset(west, 3.0)
    for x, y in spots(rng, (96.0, 244.0, 326.0, 570.0), 46, 13.0, lambda x, y: in_polygon(x, y, inside_west)):
        MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")), x, y, SOIL_H,
                    scale=rng.uniform(1.9, 2.7), turn=rng.uniform(0.0, 6.28), materials={"periwinkle_plant": blue})
    for x, y in spots(rng, (100.0, 240.0, 330.0, 560.0), 6, 34.0, lambda x, y: in_polygon(x, y, inset(west, 8.0))):
        MODEL.place(kit, "flower_heliophila", "flower_heliophila_small", x, y, SOIL_H, scale=1.6,
                    turn=rng.uniform(0.0, 6.28), materials={"flower_heliophila": white_blue})
    trellis(kit, "WestTrellis", 168.0, 586.0, 726.0, rng)
    for x, y in spots(rng, (96.0, 244.0, 576.0, 736.0), 14, 18.0,
                      lambda x, y: in_polygon(x, y, inside_west) and abs(x - 168.0) > 12.0):
        MODEL.place(kit, "weed_plant_02", rng.choice(MODEL.variants("weed_plant_02")), x, y, SOIL_H,
                    scale=rng.uniform(1.8, 2.4), turn=rng.uniform(0.0, 6.28))
    for x, y in spots(rng, (96.0, 244.0, 744.0, 1126.0), 40, 17.0, lambda x, y: in_polygon(x, y, inside_west)):
        choice = rng.random()
        if choice < 0.3:
            MODEL.place(kit, "fern_02", rng.choice(("fern_02_a", "fern_02_d", "fern_02_c")), x, y, SOIL_H,
                        scale=rng.uniform(0.7, 0.95), turn=rng.uniform(0.0, 6.28))
        elif choice < 0.8:
            MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")), x, y, SOIL_H,
                        scale=rng.uniform(1.8, 2.5), turn=rng.uniform(0.0, 6.28),
                        materials={"periwinkle_plant": blue})
        else:
            MODEL.place(kit, "nettle_plant", rng.choice(MODEL.variants("nettle_plant", "tall")), x, y, SOIL_H,
                        scale=rng.uniform(3.0, 3.8), turn=rng.uniform(0.0, 6.28))
    valves(kit, 232.0, (790.0, 850.0, 910.0))
    # East: moonleaf, its silver pods, the mineral patch, then moonleaf,
    # ferns and pods below.
    inside_east = inset(east, 3.0)
    for x, y in spots(rng, (776.0, 916.0, 326.0, 586.0), 20, 22.0, lambda x, y: in_polygon(x, y, inside_east)):
        MODEL.place(kit, "calathea_orbifolia_01", rng.choice(MODEL.variants("calathea_orbifolia_01", "_b")
                                                             + MODEL.variants("calathea_orbifolia_01", "_c")),
                    x, y, SOIL_H, scale=rng.uniform(1.0, 1.35), turn=rng.uniform(0.0, 6.28),
                    materials={"calathea_orbifolia_01": moon_leaf})
    for x, y in spots(rng, (780.0, 915.0, 330.0, 580.0), 14, 18.0, lambda x, y: in_polygon(x, y, inset(east, 8.0))):
        moon_pod(kit, "Pod%d" % int(x * 10 + y), x, y, SOIL_H, rng)
    mineral_patch(kit, (786.0, 908.0, 596.0, 724.0), rng)
    for x, y in spots(rng, (776.0, 916.0, 740.0, 1126.0), 34, 19.0, lambda x, y: in_polygon(x, y, inside_east)):
        choice = rng.random()
        if choice < 0.5:
            MODEL.place(kit, "calathea_orbifolia_01", rng.choice(MODEL.variants("calathea_orbifolia_01")), x, y,
                        SOIL_H, scale=rng.uniform(0.95, 1.3), turn=rng.uniform(0.0, 6.28),
                        materials={"calathea_orbifolia_01": moon_leaf})
        elif choice < 0.78:
            MODEL.place(kit, "fern_02", rng.choice(("fern_02_a", "fern_02_d", "fern_02_c")), x, y, SOIL_H,
                        scale=rng.uniform(0.7, 0.95), turn=rng.uniform(0.0, 6.28))
        else:
            moon_pod(kit, "LowPod%d" % int(x * 10 + y), x, y, SOIL_H, rng)
    return kit


def trellis(kit, part, x, y0, y1, rng):
    """An iron trellis down the bed's middle with ironvine climbing it: dark,
    metallic leaves on wiry stems."""
    metal = iron()
    for y in (y0, (y0 + y1) / 2.0, y1):
        kit.box("%sPost%d" % (part, int(y)), x - 1.6, x + 1.6, y - 1.6, y + 1.6, SOIL_H, SOIL_H + 92.0, metal,
                bevel=0.3)
        kit.ball("%sFinial%d" % (part, int(y)), x, y, SOIL_H + 94.0, 2.4, metal)
    for h in (36.0, 62.0, 88.0):
        kit.rod("%sRail%d" % (part, int(h)), (x, y0, SOIL_H + h), (x, y1, SOIL_H + h), 0.7, metal)
    for index in range(12):
        y = y0 + (y1 - y0) * (index + 0.5) / 12.0
        kit.rod("%sDiag%d" % (part, index), (x, y - 6.0, SOIL_H + 10.0), (x, y + 6.0, SOIL_H + 88.0), 0.45, metal)
    vine = hall._material("GreenhouseIronvine", lambda nodes, links: _ironvine_shader(nodes, links))
    stem = stem_material()
    leaves = []
    for strand in range(5):
        y = y0 + (y1 - y0) * strand / 4.0
        points = []
        for step in range(9):
            t = step / 8.0
            points.append((x + 4.0 * math.sin(t * 7.0 + strand), y + 18.0 * math.sin(t * 4.0 + strand * 1.7),
                           SOIL_H + 2.0 + 90.0 * t))
        tube(kit, "%sVine%d" % (part, strand), points, 1.0, stem, tip=0.4, segments=6)
        for point in points[1:]:
            for _leaf in range(9):
                leaves.append((point[0] + rng.uniform(-7.0, 7.0), point[1] + rng.uniform(-12.0, 12.0),
                               point[2] + rng.uniform(-8.0, 6.0)))
    leaf_mesh(kit, part + "Leaves", leaves, 9.0, vine, rng, droop=0.5)


def _ironvine_shader(nodes, links):
    geometry = nodes.new("ShaderNodeNewGeometry")
    color = hall._mix(nodes, links, geometry.outputs["Random Per Island"], (0.04, 0.07, 0.06), (0.1, 0.16, 0.13))
    hall._principled(nodes, links, color, roughness=0.32, metallic=0.55)


def valves(kit, x, ys):
    """Three brass valves on the west bed's kerb, a pipe feeding each: light
    (a lamp-glass bulb), water and air (a bellows), as its text says."""
    brass, copper = hall._brass(), hall._copper()
    for index, y in enumerate(ys):
        kit.rod("ValvePipe%d" % index, (x - 18.0, y, SOIL_H + 4.0), (x + 3.0, y, SOIL_H + 4.0), 1.6, copper)
        kit.cylinder("ValveBody%d" % index, x + 4.0, y, SOIL_H + 1.0, SOIL_H + 9.0, 3.2, brass, segments=16)
        kit.ring("ValveWheel%d" % index, (x + 4.0, y, SOIL_H + 13.0), (0.0, 0.0, 1.0), 4.2, 0.6, brass, segments=24,
                 sides=6)
        kit.rod("ValveStem%d" % index, (x + 4.0, y, SOIL_H + 9.0), (x + 4.0, y, SOIL_H + 13.0), 0.6, brass)
        if index == 0:
            bulb = hall._glow_material("GreenhouseValveLight", (1.0, 0.86, 0.6), 4.0, (1.0, 0.9, 0.7))
            kit.ball("ValveBulb", x + 4.0, y - 1.0, SOIL_H + 17.0, 2.0, bulb, plan=0.8)
            RP.glow("bulb", x + 4.0, y, SOIL_H + 17.0, (1.0, 0.85, 0.6), 9.0)
        elif index == 1:
            water = hall._glow_material("GreenhouseValveWater", (0.3, 0.75, 0.9), 1.2, (0.2, 0.5, 0.6))
            kit.ball("ValveWater", x + 4.0, y - 1.0, SOIL_H + 17.0, 1.8, water, plan=0.8)
        else:
            kit.ball("ValveAir", x + 4.0, y - 1.0, SOIL_H + 17.0, 2.0, hall._cloth("GreenhouseBellows",
                                                                                (0.25, 0.14, 0.08)), plan=0.8)


def moon_pod(kit, part, x, y, h, rng):
    """A moonleaf pod: a silver bud on a stem, half open, lit from within."""
    stem = stem_material()
    pod = hall._material("GreenhouseMoonPod", lambda nodes, links: _moon_pod_shader(nodes, links))
    tall = rng.uniform(16.0, 26.0)
    tube(kit, part + "Stem", [(x, y, h), (x + rng.uniform(-2.0, 2.0), y, h + tall * 0.6), (x, y, h + tall)], 0.6, stem,
         tip=0.5, segments=6)
    centre = RP.world(x, y, h + tall)
    for index in range(5):
        angle = 2.0 * math.pi * index / 5.0 + rng.uniform(0.0, 0.5)
        petal(kit, "%sLeaf%d" % (part, index), centre, angle, 0.1, 0.07, 1.0, 1.4, 0.03, pod, steps=5,
              across=4)
    kit.ball(part + "Bud", x, y, h + tall + 3.0, 2.2, pod, plan=0.8)
    RP.glow("crystal", x, y, h + tall + 4.0, (0.75, 0.85, 1.0), 9.0)


def _moon_pod_shader(nodes, links):
    op = hall._MathBuilder(nodes, links)
    _coords, _u, v = hall._uv_parts(nodes, links)
    color = hall._mix(nodes, links, v, (0.42, 0.48, 0.55), (0.82, 0.86, 0.9))
    hall._principled(nodes, links, color, roughness=0.3, metallic=0.4, emission=(0.7, 0.82, 1.0),
                     emission_strength=op("MULTIPLY", op("SUBTRACT", 1.0, v), 1.4))


def mineral_patch(kit, box, rng):
    """The mineral bed: pale grit and stones worked into the soil, a few
    crystals growing out of it and a hardy sorrel."""
    x0, x1, y0, y1 = box
    rock = kerb_stone()
    shape = bmesh.new()
    for x, y in spots(rng, box, 90, 4.5):
        radius = rng.uniform(1.6, 4.2)
        bmesh.ops.create_icosphere(shape, subdivisions=1, radius=1.0, matrix=Matrix.Translation(
            (x, y, SOIL_H + radius * 0.25)) @ Matrix.Rotation(rng.uniform(0.0, 6.28), 4, "Z")
            @ Matrix.Diagonal((radius, radius * rng.uniform(0.6, 0.9), radius * rng.uniform(0.35, 0.6), 1.0)))
    kit.shape("MineralStones", shape, rock, uv="box")
    shine = hall._glow_material("GreenhouseMineral", (0.55, 0.85, 1.0), 0.8, (0.3, 0.45, 0.6))
    for index, (x, y) in enumerate(spots(rng, (x0 + 10.0, x1 - 10.0, y0 + 10.0, y1 - 10.0), 6, 24.0)):
        for part in range(3):
            crystal(kit, "Mineral%d_%d" % (index, part), x + rng.uniform(-4.0, 4.0), y + rng.uniform(-3.0, 3.0),
                    SOIL_H, rng.uniform(1.8, 3.4), rng.uniform(8.0, 17.0), shine, rng.uniform(-0.5, 0.5))
        RP.glow("crystal", x, y, SOIL_H + 8.0, (0.55, 0.85, 1.0), 9.0)
    for x, y in spots(rng, box, 5, 26.0):
        MODEL.place(kit, "weed_plant_02", rng.choice(MODEL.variants("weed_plant_02")), x, y, SOIL_H,
                    scale=rng.uniform(1.8, 2.4), turn=rng.uniform(0.0, 6.28))


def crystal(kit, part, x, y, h, radius, height, material, tilt):
    """A six-sided crystal, its point up, leaning `tilt` radians."""
    shape = bmesh.new()
    bmesh.ops.create_cone(shape, cap_ends=True, cap_tris=False, segments=6, radius1=radius, radius2=radius * 0.8,
                          depth=height * 0.7, matrix=Matrix.Translation((0.0, 0.0, height * 0.35)))
    bmesh.ops.create_cone(shape, cap_ends=False, cap_tris=False, segments=6, radius1=radius * 0.8, radius2=0.0,
                          depth=height * 0.3, matrix=Matrix.Translation((0.0, 0.0, height * 0.85)))
    bmesh.ops.transform(shape, verts=shape.verts[:], matrix=Matrix.Translation((x, y, h))
                        @ Matrix.Diagonal((1.0, ROUND, 1.0, 1.0)) @ Matrix.Rotation(tilt, 4, "Y"))
    return kit.shape(part, shape, material)


# ---------------------------------------------------------------- the south


def pots(name, prop, big, small, plants):
    """A cluster of terracotta pots on the floor by the south wall: `big` and
    `small` (x, y, scale, turn) pots, each planted from `plants`."""
    kit = RP.Kit(name, prop=prop)
    rng = random.Random(len(name) * 17 + int(big[0][0]))
    for index, (x, y, scale, turn) in enumerate(list(big) + list(small)):
        MODEL.place(kit, "planter_pot_clay", "planter_pot_clay", x, y, scale=scale, turn=turn, depth=True)
        # The pot is 22.2 cm tall and 12.1 cm across its mouth; h is screen px.
        earth = (22.2 - 1.2) * scale * hall.SIN_ALPHA
        radius = 11.6 * scale
        kit.lathe("Earth%d" % index, x, y, [(0.0, earth), (radius, earth)], soil(), plan=ROUND, segments=40,
                  close=False)
        plants(kit, index, x, y, earth, radius, rng)
    return kit


def west_pots(kit, index, x, y, h, radius, rng):
    """Pots A: a broad-leaved plant with blue blossom spilling over its rim,
    the emberroot pot (glowing roots, its orange flowers) and a pot of fern."""
    blue = flower_material("periwinkle_plant", "GreenhouseBlueBlossom", petal_hue=0.62)
    if index == 1:
        emberroot(kit, "PotEmber", x, y, h, rng)
        for angle in (0.3, 1.6, 2.9, 4.2, 5.4):
            MODEL.place(kit, "flower_ursinia", rng.choice(MODEL.variants("flower_ursinia")),
                        x + radius * 0.6 * math.cos(angle), y + radius * 0.6 * math.sin(angle), h,
                        scale=rng.uniform(1.6, 2.1), turn=angle)
        return
    if index == 2:
        MODEL.place(kit, "fern_02", "fern_02_b", x, y, h, scale=0.5, turn=0.8)
        return
    MODEL.place(kit, "anthurium_botany_01", "anthurium_botany_01_a", x, y - 4.0, h, scale=1.15, turn=1.0)
    for _plant in range(16):
        angle = rng.uniform(0.0, 6.28)
        distance = math.sqrt(rng.uniform(0.3, 1.0)) * radius * 0.95
        MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")),
                    x + distance * math.cos(angle), y + distance * math.sin(angle), h,
                    scale=rng.uniform(2.2, 3.0), turn=rng.uniform(0.0, 6.28), materials={"periwinkle_plant": blue})


def east_pots(kit, index, x, y, h, radius, rng):
    """Pots B: the heavy leafy plant with small blue flowers through it."""
    blue = flower_material("periwinkle_plant", "GreenhouseBlueBlossom", petal_hue=0.62)
    if index == 0:
        for part in ("potted_plant_01_stem", "potted_plant_01_leaves"):
            MODEL.place(kit, "potted_plant_01", part, x, y, h, scale=1.7, turn=0.6, anchor="potted_plant_01_pebbles")
        for angle in (0.4, 2.5, 4.4):
            MODEL.place(kit, "calathea_orbifolia_01", "calathea_orbifolia_01_b", x + radius * 0.55 * math.cos(angle),
                        y + radius * 0.5 * math.sin(angle), h, scale=1.0, turn=angle)
    else:
        MODEL.place(kit, "fern_02", "fern_02_c", x, y, h, scale=0.62, turn=rng.uniform(0.0, 6.28))
    for _plant in range(max(int(radius / 5.0), 4)):
        angle = rng.uniform(0.0, 6.28)
        distance = rng.uniform(radius * 0.45, radius * 0.95)
        MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")),
                    x + distance * math.cos(angle), y + distance * math.sin(angle), h,
                    scale=rng.uniform(1.7, 2.3), turn=rng.uniform(0.0, 6.28), materials={"periwinkle_plant": blue})


def gate():
    """The gate, as the painting draws it: a deep round arch of dressed stone
    springing from two square plinth blocks cut with a diamond point, a bronze
    shield on its keystone, and in it an oak frame with a post down the
    middle and a door each side, glazed above a planked panel, on a stone
    threshold, with ivy climbing its east side."""
    kit = RP.Kit("ArchDoor", prop="ArchDoor")
    cx, face = GATE_CX, GATE_FACE_Y
    back = face - GATE_DEEP
    rng = random.Random(907)
    stone = laid_photo("GreenhouseGateStone", "seaside_rock", 0.7, 2.0, (0.86, 0.82, 0.8), saturation=0.4,
                       per_island=False, variety=0.18, ao=0.15)
    # The plinths, a stepped base under a block cut with a diamond point.
    for side in (-1.0, 1.0):
        a, b = sorted((cx + side * GATE_OPEN, cx + side * GATE_PLINTH))
        kit.box("PlinthBase", a - 2.0, b + 2.0, back - 3.0, face + 3.5, -0.5, 12.0, stone, bevel=1.2, uv="box")
        kit.box("PlinthBlock", a, b, back - 1.0, face + 1.0, 12.0, 54.0, stone, bevel=1.4, uv="box")
        diamond(kit, "PlinthPoint", a + 3.5, b - 3.5, 15.5, 50.5, face + 1.05, 4.0, stone)
        kit.box("PlinthCap", a - 2.5, b + 2.5, back - 3.0, face + 3.5, 54.0, GATE_SPRING, stone, bevel=1.4, uv="box")
    # The arch: eleven voussoirs, the keystone larger and proud of the rest.
    count = 11
    for index in range(count):
        key = index == count // 2
        a0 = 180.0 * index / count + 0.7
        a1 = 180.0 * (index + 1) / count - 0.7
        outer = GATE_OPEN + GATE_RING + (4.5 if key else rng.uniform(-0.8, 0.8))
        voussoir(kit, "Voussoir%d" % index, cx, GATE_SPRING, GATE_OPEN, outer, a0, a1, back + rng.uniform(0.0, 1.0),
                 face + (2.5 if key else 1.0), stone)
    kit.box("Threshold", cx - GATE_OPEN, cx + GATE_OPEN, back - 1.0, face + 3.5, -0.5, GATE_SILL, stone, bevel=1.0,
            uv="box")
    kit.box("Step", cx - 74.0, cx + 74.0, face + 3.5, face + 15.0, -1.0, 4.5, stone, bevel=1.0, uv="box")
    # The passage behind, dark, so nothing shows through the joints.
    passage = hall._material("GreenhouseGatePassage", lambda nodes, links: hall._principled(
        nodes, links, (0.004, 0.004, 0.005), roughness=0.9))
    kit.box("Passage", cx - GATE_OPEN - 2.0, cx + GATE_OPEN + 2.0, back - 6.0, back - 2.0, 0.0,
            GATE_SPRING + GATE_OPEN + 2.0, passage, bevel=0.0)
    doors(kit, cx, face, back)
    shield(kit, cx, face + 2.5, GATE_SPRING + GATE_OPEN + GATE_RING / 2.0 + 2.5)
    gate_ivy(kit, cx, face, rng)
    return kit


def diamond(kit, part, x0, x1, h0, h1, y, rise, material):
    """A diamond point cut on a block's face: a low four-sided pyramid over
    x0..x1 and h0..h1 on the face at plan y, its apex `rise` px proud."""
    shape = bmesh.new()
    base = [shape.verts.new((x0, y, h0)), shape.verts.new((x1, y, h0)), shape.verts.new((x1, y, h1)),
            shape.verts.new((x0, y, h1))]
    apex = shape.verts.new(((x0 + x1) / 2.0, y + rise, (h0 + h1) / 2.0))
    for index in range(4):
        shape.faces.new((base[index], base[(index + 1) % 4], apex))
    shape.faces.new(list(reversed(base)))
    return kit.shape(part, shape, material, uv="box")


def voussoir(kit, part, cx, spring, r0, r1, a0, a1, y0, y1, material, steps=4):
    """One block of an arch's ring between angles a0 and a1 (degrees from the
    east springing) and radii r0..r1 round (cx, spring) in the face's (x, h),
    from plan y0 (its back) to y1 (its face)."""
    shape = bmesh.new()
    rings = []
    for step in range(steps + 1):
        angle = math.radians(a0 + (a1 - a0) * step / steps)
        cosine, sine = math.cos(angle), math.sin(angle)
        rings.append([shape.verts.new((cx + r * cosine, y, spring + r * sine))
                      for r, y in ((r0, y1), (r1, y1), (r1, y0), (r0, y0))])
    for lower, upper in zip(rings[:-1], rings[1:]):
        for index in range(4):
            following = (index + 1) % 4
            shape.faces.new((lower[index], lower[following], upper[following], upper[index]))
    shape.faces.new(list(reversed(rings[0])))
    shape.faces.new(rings[-1])
    return kit.shape(part, shape, material, bevel=1.1, uv="box")


def doors(kit, cx, face, back):
    """The oak frame in the arch: a lining round it, jambs, a post down the
    middle, and a door each side, planked to the mid rail and glazed above
    it in small panes, with strap hinges and a ring to pull."""
    frame = laid_photo("GreenhouseGateFrame", "wood_table_worn", 0.45, 1.0, (0.95, 0.8, 0.66), saturation=0.9,
                       variety=0.12)
    boards = laid_photo("GreenhouseGateBoards", "wood_cabinet_worn_long", 0.42, 0.85, (0.92, 0.78, 0.66),
                        saturation=0.85, variety=0.15)
    metal = iron()
    glass = gate_glass()
    radius = GATE_OPEN - 6.0
    band(kit, "Lining", circle_points(cx, GATE_SPRING, GATE_OPEN - 3.0, steps=40, start=0.0, end=180.0), 6.0,
         back + 2.0, face - 4.0, frame)
    wood_boxes(kit, "Jambs", [(cx + side * GATE_OPEN - (6.0 if side > 0 else 0.0),
                               cx + side * GATE_OPEN + (0.0 if side > 0 else 6.0),
                               back + 2.0, face - 4.0, GATE_SILL, GATE_SPRING) for side in (-1.0, 1.0)], frame,
               grain="h", bevel=0.4)
    crown = GATE_SPRING + radius
    wood_boxes(kit, "Post", [(cx - 4.5, cx + 4.5, face - 13.0, face - 4.0, GATE_SILL, crown + 1.0)], frame,
               grain="h", bevel=0.5)
    for h in (22.0, 42.0, 62.0, 82.0, 102.0):
        kit.ball("PostStud", cx, face - 3.6, h, 1.1, metal, plan=0.8)
    plane = face - 13.5
    panel = 52.0
    for side in (-1.0, 1.0):
        inner, outer = cx + side * 4.5, cx + side * radius
        a, b = sorted((inner, outer))
        width = b - a
        # The planked panel, four boards up and down.
        wood_boxes(kit, "Panel%d" % int(side), [(a + width * k / 4.0 + 0.3, a + width * (k + 1) / 4.0 - 0.3,
                                                 plane - 3.0, plane, GATE_SILL, panel) for k in range(4)], boards,
                   grain="h", photo_grain="v", bevel=0.3)
        wood_boxes(kit, "Rails%d" % int(side), [(a, b, plane - 1.0, plane + 1.2, GATE_SILL, GATE_SILL + 5.0),
                                                (a, b, plane - 1.0, plane + 1.2, panel, panel + 6.0)], frame,
                   grain="x", bevel=0.4)
        stile = (b - 4.0, b) if side > 0 else (a, a + 4.0)
        wood_boxes(kit, "Stile%d" % int(side), [(stile[0], stile[1], plane - 1.0, plane + 1.2, GATE_SILL,
                                                 GATE_SPRING)], frame, grain="h", bevel=0.4)
        # The glazed head: glass to the arch, a curved rail and the glazing bars.
        top_angle = math.degrees(math.acos(4.5 / radius))
        arc = circle_points(cx, GATE_SPRING, radius, steps=16,
                            start=0.0 if side > 0 else 180.0, end=top_angle if side > 0 else 180.0 - top_angle)
        outline = [(inner, panel + 6.0), (outer, panel + 6.0)] + arc
        if side < 0:
            outline = list(reversed(outline))
        pane = RP.polygon_mesh("GreenhouseGateGlass%d" % int(side), outline, [],
                               lambda u, v: (u, plane - 1.5, v), glass, uv_of=lambda u, v: (u * 0.05, v * 0.05))
        kit.keep(pane)
        band(kit, "HeadRail%d" % int(side), circle_points(cx, GATE_SPRING, radius - 1.6, steps=16,
                                                           start=0.0 if side > 0 else 180.0,
                                                           end=top_angle if side > 0 else 180.0 - top_angle),
             3.2, plane - 1.0, plane + 1.0, frame)
        for k in (1, 2):
            x = inner + (outer - inner) * k / 3.0
            head = GATE_SPRING + math.sqrt(max(radius * radius - (x - cx) ** 2, 0.0)) - 1.0
            kit.box("Bar%d_%d" % (int(side), k), x - 0.8, x + 0.8, plane - 1.2, plane + 0.4, panel + 6.0, head, frame,
                    bevel=0.0)
        for h in (78.0, 100.0):
            reach = math.sqrt(max(radius * radius - max(h - GATE_SPRING, 0.0) ** 2, 0.0)) - 1.0
            a2, b2 = sorted((inner, cx + side * reach))
            kit.box("Bar%d_%d" % (int(side), int(h)), a2, b2, plane - 1.2, plane + 0.4, h - 0.8, h + 0.8, frame,
                    bevel=0.0)
        # Strap hinges from the jamb across the panel, riveted, and a ring.
        for h in (22.0, 42.0):
            near, far = outer - side * 1.0, outer - side * 34.0
            kit.box("Strap%d_%d" % (int(side), int(h)), min(near, far), max(near, far), plane, plane + 0.8,
                    h - 1.6, h + 1.6, metal, bevel=0.2)
            kit.ball("StrapEnd%d_%d" % (int(side), int(h)), far, plane + 0.5, h, 2.2, metal, plan=0.4)
            for along in (6.0, 16.0, 26.0):
                kit.ball("StrapRivet", outer - side * along, plane + 1.0, h, 0.7, metal, plan=0.8)
        kit.ball("RingPlate%d" % int(side), inner + side * 7.0, plane + 0.6, 40.0, 1.8, metal, plan=0.5)
        kit.ring("Ring%d" % int(side), (inner + side * 7.0, plane + 1.4, 36.0), (0.0, 1.0, 0.0), 3.0, 0.55, metal,
                 segments=24, sides=6)


def gate_glass():
    """Old green glass in the doors, dark against the passage behind and
    mottled pane by pane, catching the lanterns."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        mottle = hall._noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=3.0)
        color = hall._mix(nodes, links, mottle, (0.008, 0.016, 0.014), (0.022, 0.042, 0.032))
        shader = hall._principled(nodes, links, color, roughness=0.08, emission=LEAF_LIGHT,
                                  emission_strength=op("MULTIPLY", mottle, 0.035))
        shader.inputs["Coat Weight"].default_value = 1.0
        shader.inputs["Coat Roughness"].default_value = 0.04
    return hall._material("GreenhouseGateGlass", build)


def shield(kit, cx, y, ch):
    """A bronze heater shield on the keystone, a brass rim round it and the
    Greenhouse's leaf on its field, faintly lit as the Hall's door emblem is."""
    width, top, waist, point = 14.0, 15.0, 1.0, -18.0
    outline = [(-width + 2.0 * width * index / 10.0, top + 2.4 * math.sin(math.pi * index / 10.0))
               for index in range(11)]
    outline.append((width, waist))
    outline += [(width * math.cos(t * math.pi / 2.0), waist - (waist - point) * math.sin(t * math.pi / 2.0))
                for t in (index / 10.0 for index in range(1, 11))]
    outline += [(-width * math.cos(t * math.pi / 2.0), waist - (waist - point) * math.sin(t * math.pi / 2.0))
                for t in (index / 10.0 for index in range(9, -1, -1))]
    placed = [(cx + px, ch + pz) for px, pz in outline]
    kit.slab("ShieldField", placed, y, y + 1.8, hall._bronze())
    band(kit, "ShieldRim", placed, 1.8, y + 1.0, y + 2.8, hall._brass(), closed=True)
    right = [(0.5 * max(math.cos(along * math.pi / 2.0), 0.0) ** 0.8, along)
             for along in (-1.0 + 2.0 * index / 12.0 for index in range(13))]
    leaf = right + [(-across, along) for across, along in reversed(right)][1:-1]
    turn = math.radians(-30.0)
    leaf = [(cx + 8.5 * (px * math.cos(turn) - pz * math.sin(turn)), ch - 1.5 + 8.5 * (px * math.sin(turn)
                                                                                       + pz * math.cos(turn)))
            for px, pz in leaf]
    kit.slab("ShieldLeaf", leaf, y + 1.8, y + 2.6,
             hall._glow_material("GreenhouseShieldLeaf", LEAF_LIGHT, 1.4, (0.1, 0.26, 0.07)))
    kit.ball("ShieldGem", cx, y + 3.0, ch + top - 3.0, 1.5,
             hall._glow_material("GreenhouseShieldGem", (0.55, 1.0, 0.6), 2.0, (0.2, 0.5, 0.25)), plan=0.6)
    RP.glow("crystal", cx, y + 3.0, ch - 1.5, LEAF_LIGHT, 12.0)


def gate_ivy(kit, cx, face, rng):
    """Ivy climbing the east plinth and over the east half of the arch."""
    ivy = hall._material("GreenhouseIvyLeaf", lambda nodes, links: _ivy_shader(nodes, links))
    points = [(cx + 98.0, face + 2.5, 2.0), (cx + 96.0, face + 2.5, 30.0), (cx + 92.0, face + 2.5, 58.0)]
    for angle in (10.0, 24.0, 38.0, 52.0, 64.0):
        r = GATE_OPEN + GATE_RING + 1.5
        points.append((cx + r * math.cos(math.radians(angle)), face + 2.5,
                       GATE_SPRING + r * math.sin(math.radians(angle))))
    tube(kit, "GateIvyStem", points, 0.9, stem_material(), tip=0.4, segments=6)
    leaves = []
    for x, y, h in points:
        for _leaf in range(8):
            leaves.append((x + rng.uniform(-7.0, 7.0), y + rng.uniform(0.5, 2.5), h + rng.uniform(-6.0, 6.0)))
    leaf_mesh(kit, "GateIvy", leaves, 6.5, ivy, rng, droop=0.7)


# ---------------------------------------------------------------- dressing


def wall_dressing(shell):
    """Ivy down the walls from their tops, hanging baskets and a copper pipe
    run along the back wall that feeds the beds' valves."""
    kit = RP.Kit("WallDressing")
    rng = random.Random(53)
    ivy = hall._material("GreenhouseIvyLeaf", lambda nodes, links: _ivy_shader(nodes, links))
    stem = stem_material()
    # Ivy hangs over the back wall's top between the windows.
    for index, x in enumerate((120.0, 300.0, 352.0, 668.0, 718.0, 900.0)):
        leaves = []
        points = []
        drop = rng.uniform(90.0, 170.0)
        for step in range(8):
            t = step / 7.0
            points.append((x + 6.0 * math.sin(t * 5.0 + index), BACK_Y + 2.0, WALL_H - drop * t))
        tube(kit, "IvyStem%d" % index, points, 0.8, stem, tip=0.4, segments=6)
        for px, py, ph in points:
            for _leaf in range(16):
                leaves.append((px + rng.uniform(-15.0, 15.0), py + rng.uniform(0.5, 3.0),
                               ph + rng.uniform(-11.0, 11.0)))
        leaf_mesh(kit, "Ivy%d" % index, leaves, 8.5, ivy, rng, droop=0.6)
    # And down the side walls.
    for side in ("left", "right"):
        for index, u in enumerate((160.0, 470.0, 800.0, 1080.0)):
            leaves = []
            points = []
            drop = rng.uniform(100.0, 190.0)
            for step in range(8):
                t = step / 7.0
                point = shell.side_point(side, u + 8.0 * math.sin(t * 4.0 + index), WALL_H - drop * t)
                out = shell.shell.frames[side].out
                points.append(tuple(point + out * 1.5))
            tube(kit, "Ivy%sStem%d" % (side, index), points, 0.8, stem, tip=0.4, segments=6)
            out = shell.shell.frames[side].out
            for px, py, ph in points:
                for _leaf in range(16):
                    offset = out * rng.uniform(0.5, 3.0)
                    leaves.append((px + offset.x, py + rng.uniform(-15.0, 15.0) + offset.y,
                                   ph + rng.uniform(-11.0, 11.0)))
            leaf_mesh(kit, "Ivy%s%d" % (side, index), leaves, 8.5, ivy, rng, droop=0.6)
    # Hanging baskets on brackets from the back wall's top.
    metal = iron()
    for index, x in enumerate((300.0, 724.0)):
        y = BACK_Y + 26.0
        top = WALL_H - 22.0
        kit.rod("BracketArm%d" % index, (x, BACK_Y, top + 6.0), (x, y, top + 6.0), 0.9, metal)
        kit.rod("BracketBrace%d" % index, (x, BACK_Y, top - 14.0), (x, y - 8.0, top + 6.0), 0.7, metal)
        for chain in range(3):
            angle = 2.0 * math.pi * chain / 3.0
            kit.rod("Chain%d_%d" % (index, chain), (x, y, top + 6.0),
                    (x + 9.0 * math.cos(angle), y + 6.0 * math.sin(angle), top - 34.0), 0.3, metal)
        MODEL.place(kit, "wicker_basket_01", "wicker_basket_01", x, y, top - 40.0, scale=0.55, turn=index)
        for _plant in range(4):
            MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")),
                        x + rng.uniform(-6.0, 6.0), y + rng.uniform(-4.0, 4.0), top - 36.0,
                        scale=rng.uniform(1.3, 1.7), turn=rng.uniform(0.0, 6.28),
                        materials={"periwinkle_plant": flower_material("periwinkle_plant", "GreenhouseBlueBlossom",
                                                                       petal_hue=0.62)})
        kit.light("BasketBounce%d" % index, x, y + 10.0, top - 50.0, (0.6, 0.7, 1.0), 0.6)
    # A copper pipe along the back wall's foot to the beds.
    copper = hall._copper()
    kit.rod("PipeWest", (100.0, BACK_Y + 3.0, 52.0), (380.0, BACK_Y + 3.0, 52.0), 1.6, copper)
    kit.rod("PipeEast", (646.0, BACK_Y + 3.0, 52.0), (912.0, BACK_Y + 3.0, 52.0), 1.6, copper)
    for x in (140.0, 260.0, 680.0, 860.0):
        kit.box("PipeClamp%d" % int(x), x - 1.6, x + 1.6, BACK_Y, BACK_Y + 5.0, 49.0, 55.0, hall._brass(),
                bevel=0.3)
    return kit


def _ivy_shader(nodes, links):
    geometry = nodes.new("ShaderNodeNewGeometry")
    color = hall._mix(nodes, links, geometry.outputs["Random Per Island"], (0.025, 0.07, 0.025), (0.08, 0.18, 0.05))
    shader = hall._principled(nodes, links, color, roughness=0.5)
    shader.inputs["Subsurface Weight"].default_value = 0.2


def paving():
    """The floor, as the painting lays it: dark slate pavers in north-south
    columns of mixed widths and lengths, their joints staggered, each stone a
    slab whose chamfered rim catches the light and is worn paler, a few of
    them cracked. Stones the beds, the planter, the window's plinth, the
    bench top or the south wall would hide are left out."""
    kit = RP.Kit("Paving", depth=False)
    rng = random.Random(1709)
    shape = bmesh.new()
    cracks = []
    laid = 0

    def hidden(x0, x1, y0, y1):
        corners = ((x0, y0), (x1, y0), (x0, y1), (x1, y1))
        if any(all(in_polygon(x, y, bed) for x, y in corners) for bed in (LEFT_BED, RIGHT_BED)):
            return True
        if max(math.hypot(x - PLANTER[0], y - PLANTER[1]) for x, y in corners) < PLANTER_R - 4.0:
            return True
        if x0 > BENCH[0] + 6.0 and x1 < BENCH[1] - 6.0 and y0 > BENCH[2] + 6.0 and y1 < BENCH[3] - BENCH_TOP - 2.0:
            return True
        if y0 > SOUTH_Y + 2.0 and y1 < GATE_FACE_Y - 2.0:
            return True
        return x0 > 380.0 and x1 < 644.0 and y1 < 346.0

    x = LEFT_X - 4.0
    while x < RIGHT_X + 4.0:
        x1 = min(x + rng.uniform(*PAVE_COLUMN), RIGHT_X + 4.0)
        y = BACK_Y - rng.uniform(0.0, 70.0)
        while y < PAVE_SOUTH:
            length = rng.uniform(*PAVE_LENGTH)
            if rng.random() < 0.14:
                length *= 0.55
            y1 = y + length
            if not hidden(x, x1, y, y1):
                top = rng.uniform(1.9, 2.6)
                _paver(shape, x + PAVE_JOINT / 2.0, x1 - PAVE_JOINT / 2.0, y + PAVE_JOINT / 2.0,
                       y1 - PAVE_JOINT / 2.0, top, rng)
                laid += 1
                if rng.random() < 0.13 and length > 40.0:
                    cracks.append(((x + x1) / 2.0, (y + y1) / 2.0, x1 - x - 9.0, length - 12.0, top))
            y = y1
        x = x1
    kit.shape("Stones", shape, laid_photo("GreenhouseSlate", "seaside_rock", 0.9, 2.1, (0.66, 0.8, 0.78),
                                          saturation=0.3, variety=0.22, wear=0.5), uv="box")
    crack = hall.material_floor_crack(False)
    for index, (cx, cy, width, length, top) in enumerate(cracks):
        turn = rng.choice((0.0, math.pi / 2.0)) + rng.uniform(-0.3, 0.3)
        size = min(width, length) if abs(math.sin(turn)) > 0.5 else None
        across, along = (width, length) if size is None else (size, size)
        quad = turned_quad(kit, "Crack%d" % index, cx, cy, top + 0.45, across, along, turn, crack)
        quad["floor_decal"] = True
    print("PAVING %d stones, %d cracked" % (laid, len(cracks)))
    return kit


def _paver(shape, x0, x1, y0, y1, top, rng):
    """One paver into `shape`: an eight-sided slab, its corners cut, with a
    two-step chamfer round its top, turned and tipped a little at random so
    no two catch the light alike."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    turn = math.radians(rng.uniform(-1.0, 1.0))
    slope_x, slope_y = rng.uniform(-0.012, 0.012), rng.uniform(-0.01, 0.01)
    cosine, sine = math.cos(turn), math.sin(turn)

    def ring(inset, drop):
        a0, a1, b0, b1 = x0 + inset, x1 - inset, y0 + inset, y1 - inset
        cut = max(2.6 - inset * 0.6, 0.8)
        outline = ((a0 + cut, b0), (a1 - cut, b0), (a1, b0 + cut), (a1, b1 - cut), (a1 - cut, b1), (a0 + cut, b1),
                   (a0, b1 - cut), (a0, b0 + cut))
        verts = []
        for px, py in outline:
            dx, dy = px - cx, py - cy
            verts.append(shape.verts.new((cx + dx * cosine - dy * sine, cy + dx * sine + dy * cosine,
                                          top - drop + dx * slope_x + dy * slope_y)))
        return verts

    outer = ring(0.0, 1.2)
    middle = ring(0.8, 0.4)
    inner = ring(1.7, 0.0)
    bottom = [shape.verts.new((vert.co.x, vert.co.y, -0.8)) for vert in outer]
    shape.faces.new(inner)
    shape.faces.new(list(reversed(bottom)))
    for upper, lower in ((inner, middle), (middle, outer), (outer, bottom)):
        for index in range(8):
            following = (index + 1) % 8
            shape.faces.new((lower[index], lower[following], upper[following], upper[index]))


def floor_dressing():
    """What lies on the paving, as in the painting: petals near the beds and
    the pink blossom by the gate, a few fallen leaves along the kerbs, vines
    creeping out of the beds over the stones, and the gardener's spade and
    bucket against the kerbs."""
    kit = RP.Kit("FloorDressing", depth=False)
    rng = random.Random(61)
    stem = stem_material()
    ivy = hall._material("GreenhouseIvyLeaf", lambda nodes, links: _ivy_shader(nodes, links))
    starts = ((256.0, 470.0, 0.2), (250.0, 1010.0, -0.35), (246.0, 1102.0, 0.5), (764.0, 640.0, math.pi - 0.25),
              (768.0, 1076.0, math.pi + 0.3), (330.0, 1430.0, -1.25), (700.0, 1431.0, -1.95))
    for index, (x, y, heading) in enumerate(starts):
        reach = rng.uniform(40.0, 75.0)
        points = []
        for step in range(8):
            t = step / 7.0
            turn = heading + 0.9 * math.sin(t * 3.0 + index)
            points.append((x + math.cos(turn) * reach * t, y + math.sin(turn) * reach * t,
                           3.0 + 0.5 * math.sin(t * 9.0)))
        tube(kit, "FloorVine%d" % index, points, 0.8, stem, tip=0.3, segments=6)
        leaves = [(px + rng.uniform(-4.0, 4.0), py + rng.uniform(-4.0, 4.0), ph + 0.6) for px, py, ph in points[1:]
                  for _leaf in range(3)]
        leaf_mesh(kit, "FloorVineLeaves%d" % index, leaves, 5.0, ivy, rng, droop=-0.05)
    leaf = hall._material("GreenhouseFallenLeaf", lambda nodes, links: _fallen_leaf_shader(nodes, links))
    fallen = bmesh.new()
    for x, y in (spots(rng, (256.0, 290.0, 360.0, 1120.0), 12, 20.0)
                 + spots(rng, (730.0, 762.0, 360.0, 1120.0), 12, 20.0)):
        turn = rng.uniform(0.0, 6.28)
        size = rng.uniform(3.0, 4.6)
        corners = [fallen.verts.new((x + size * (along * math.cos(turn) - across * math.sin(turn)),
                                     y + size * (along * math.sin(turn) + across * math.cos(turn)), 3.0))
                   for along, across in ((-1.0, 0.0), (0.0, 0.45), (1.0, 0.0), (0.0, -0.45))]
        fallen.faces.new(corners)
    obj = kit.shape("FallenLeaves", fallen, leaf)
    obj["floor_decal"] = True
    petals = bmesh.new()
    groups = (((258.0, 300.0, 340.0, 1120.0), 30, (0, 2)), ((724.0, 762.0, 340.0, 1120.0), 22, (1, 0)),
              ((280.0, 420.0, 1350.0, 1428.0), 20, (0,)), ((604.0, 750.0, 1350.0, 1428.0), 20, (0,)),
              ((340.0, 690.0, 740.0, 800.0), 10, (1,)))
    for box, count, colours in groups:
        for x, y in spots(rng, box, count, 7.0,
                          lambda x, y: math.hypot(x - PLANTER[0], y - PLANTER[1]) > PLANTER_R + 4.0):
            turn = rng.uniform(0.0, 6.28)
            size = rng.uniform(1.6, 2.6)
            corners = [petals.verts.new((x + size * (along * math.cos(turn) - across * math.sin(turn)),
                                         y + size * (along * math.sin(turn) + across * math.cos(turn)), 3.1))
                       for along, across in ((-1.0, 0.0), (0.0, 0.6), (1.0, 0.0), (0.0, -0.6))]
            face = petals.faces.new(corners)
            face.material_index = rng.choice(colours)
    obj = kit.shape("Petals", petals, [
        hall._material("GreenhousePetalPink", lambda nodes, links: hall._principled(
            nodes, links, (0.75, 0.24, 0.4), roughness=0.5)),
        hall._material("GreenhousePetalViolet", lambda nodes, links: hall._principled(
            nodes, links, (0.5, 0.18, 0.66), roughness=0.5)),
        hall._material("GreenhousePetalBlue", lambda nodes, links: hall._principled(
            nodes, links, (0.12, 0.28, 0.8), roughness=0.5))])
    obj["floor_decal"] = True
    MODEL.place(kit, "rusted_spade_01", "rusted_spade_01", 284.0, 1180.0, 2.0, scale=0.9, turn=1.4,
                tilt=(0.0, -1.35))
    MODEL.group(kit, "wooden_bucket_01", 742.0, 1186.0, 2.0, scale=0.8, turn=0.9)
    return kit


def _fallen_leaf_shader(nodes, links):
    geometry = nodes.new("ShaderNodeNewGeometry")
    color = hall._mix(nodes, links, geometry.outputs["Random Per Island"], (0.08, 0.05, 0.015), (0.16, 0.13, 0.04))
    hall._principled(nodes, links, color, roughness=0.7)


def gate_dressing():
    """Either side of the gate, as the painting has them: an iron lantern on
    a stone post standing on the south wall, and pink blossom planted along
    the wall's top."""
    kit = RP.Kit("GateDressing")
    stone = plinth_stone()
    middle = SOUTH_Y + SOUTH_DEPTH / 2.0
    for index, x in enumerate(GATE_LAMPS):
        kit.box("PostFoot%d" % index, x - 9.0, x + 9.0, middle - 9.0, middle + 9.0, SOUTH_H, SOUTH_H + 4.0, stone,
                bevel=0.8, uv="box")
        kit.box("Post%d" % index, x - 6.0, x + 6.0, middle - 6.0, middle + 6.0, SOUTH_H + 4.0, SOUTH_H + 24.0,
                stone, bevel=0.8, uv="box_up")
        kit.box("PostCap%d" % index, x - 8.0, x + 8.0, middle - 8.0, middle + 8.0, SOUTH_H + 24.0, SOUTH_H + 27.0,
                stone, bevel=0.8, uv="box")
        lantern(kit, "GateLamp%d" % index, x, middle, SOUTH_H + 27.0, size=1.0, power=4.6)
    pink = flower_material("periwinkle_plant", "GreenhousePinkBlossom", petal_hue=0.93)
    rng = random.Random(83)
    for x0, x1 in ((236.0, 398.0), (626.0, 790.0)):
        kit.box("Trough%d" % int(x0), x0, x1, SOUTH_Y + 8.0, GATE_FACE_Y - 8.0, SOUTH_H, SOUTH_H + 1.2, soil(),
                bevel=0.0)
        for x, y in spots(rng, (x0 + 4.0, x1 - 4.0, SOUTH_Y + 12.0, GATE_FACE_Y - 12.0), 16, 13.0,
                          lambda x, y: min(abs(x - lamp) for lamp in GATE_LAMPS) > 12.0):
            MODEL.place(kit, "periwinkle_plant", rng.choice(MODEL.variants("periwinkle_plant")), x, y,
                        SOUTH_H + 1.0, scale=rng.uniform(2.0, 2.8), turn=rng.uniform(0.0, 6.28),
                        materials={"periwinkle_plant": pink})
    return kit


# ---------------------------------------------------------------- the room


def moon_sky():
    """The Hall's moonlight (hall_prototype.add_sun: its colour, strength and
    softness), from the south-south-west and high, as in the other rooms."""
    data = bpy.data.lights.new("GreenhouseMoonSky", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sun = RP._link(bpy.data.objects.new("GreenhouseMoonSky", data))
    sun.rotation_euler = Vector((0.12, 0.38, -0.92)).normalized().to_track_quat("-Z", "Y").to_euler()


def grade(scene):
    scene.view_settings.exposure = 0.35


def build(rp, layout):
    global RP, MODEL
    RP = rp
    MODEL = Models()
    shell_materials = {
        "floor": joints_material(),
        "wall": rp.textured("GreenhouseWall", "castle_wall_slates", 1.5, 0.56, (0.7, 0.67, 0.78), ao=0.3),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if rp.TEXTURES.available()
                else rp.textured("GreenhouseCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if rp.TEXTURES.available()
                else rp.textured("GreenhouseLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("GreenhouseReveal", "castle_wall_slates", 1.5, 0.62, (0.72, 0.7, 0.8), ao=0.2),
    }
    shell = GreenhouseShell(SPEC, shell_materials)
    shell.build()
    back_wall()
    pedestals()
    side_lanterns(shell)
    beds()
    wall_dressing(shell)
    paving()
    floor_dressing()
    gate_dressing()
    moon_sky()
    props = {
        "MagicPlanter": planter(),
        "Workbench": workbench(),
        "PlantPotsA": pots("PlantPotsA", "PlantPotsA", ((206.0, 1300.0, 4.4, 0.4),), ((132.0, 1330.0, 2.6, 1.9),
                                                                                      (262.0, 1338.0, 2.0, 0.7)),
                           west_pots),
        "PlantPotsB": pots("PlantPotsB", "PlantPotsB", ((800.0, 1300.0, 4.2, 2.2),), ((882.0, 1328.0, 2.8, 0.8),
                                                                                      (742.0, 1340.0, 2.0, 2.9)),
                           east_pots),
        "ArchDoor": gate(),
    }
    print("GREENHOUSE built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    # The planter is walked round and the gate is walked up to from behind:
    # both stay in the room render and its depth map, so a player behind
    # them shows as a ghost, as behind the Hall's portals.
    # The bench at a real bench's size: its footprint, with the stool's.
    x0, x1, y0, y1 = BENCH
    bench = [[x0 - 3.0, y0 - 3.0], [x1 + 2.0, y0 - 3.0], [x1 + 2.0, y1 + 2.0], [514.0, y1 + 2.0], [507.0, 1058.0],
             [505.0, 1065.0], [491.0, 1073.0], [477.0, 1073.0], [458.0, 1066.0], [451.0, 1056.0], [451.0, y1 + 2.0],
             [x0 - 3.0, y1 + 2.0]]
    return {"props": props, "roots": {name: "Worldsort/" + name for name in props},
            "in_room": ["MagicPlanter", "ArchDoor"], "collision": {"RoomCollisions/table": bench}}
