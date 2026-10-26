"""The Library, the castle's archive of light, for the Blender room prototype.
tools/blender/room_prototype.py imports it as room_library and calls build()
on the room's exported layout (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). Every piece stands
where the game's collision has it. The scene's twenty Worldsort/ pieces are
modelled to stand their fronts on their collision's south edge, as deep and
tall as the painted cut-outs showed them, and to look like what the game says
when each is inspected. They stay in the room render and its depth map
("in_room"), so a player behind a case shows through it as a ghost, and each
is rendered alone as well, for the game's prompt boxes.

  north   a two-storey wall: bookcases under a gallery that walks on them,
          shelves above it, great windows of stained glass at either end and,
          in the middle, the reading dais behind its balustrade, with a
          spiral stair up to the gallery, two armchairs, a clock and the
          spectrum window, whose seven lights lay a rainbow down the stairs
  middle  the research desk with the optical array on its front, and south
          of it the floor medallion of three overlapping circles
  west    the globe desk (the Additive Relay) and the archive cases
  east    the writing desk (the Reflection Matrix), the apothecary cabinet,
          the additive-light archive and the chained book chest
  south   the floor's edge on a pale coping over a wall dropping into the
          dark, and at the corridor's end the gatehouse the painting draws:
          piers, banners, candles, a gabled hood over a pair of oak doors in
          a pointed arch, and steps down toward the Hall

The floor is laid as the painting lays it, flag by flag in courses, with
cobbles at the foot of the dais stair; its rugs carry the painted ones'
gold rosettes and borders.

Two states. The dormant archive (render.png), and with LIBRARY_STATE=awakened
the archive once its three filters are seated (render-awakened.png): pale
light from the optical array, the medallion's circles adding red, green and
blue light up to white, the cases' brass marks lit, and the hidden archive
text glowing on the floor and round the spectrum window. The awakened run
renders no props: the preview takes their prompt boxes from the dormant run.

    Blender -b --factory-startup -P tools/blender/room_prototype.py -- \\
        --room library_room --out prototypes/blender_rooms/library_room/render.png
    LIBRARY_STATE=awakened Blender -b --factory-startup -P tools/blender/room_prototype.py -- \\
        --room library_room --out prototypes/blender_rooms/library_room/render-awakened.png

Both runs also write prototypes/blender_rooms/library_room/render-library.json: the
window shafts, the station lamps, the optical array and the medallion, for the
preview's living light (tools/blender/prototype_library.gd).
"""
import json
import math
import os
import random
import re

import bmesh
import bpy
from mathutils import Matrix, Vector, geometry

import hall_prototype as hall
import room_chemistry as chem
import room_wake as wake

RP = None
AWAKENED = os.environ.get("LIBRARY_STATE", "").strip().lower() == "awakened"
SCENE = os.path.join("scenes", "floor_1", "library_room.tscn")
DATA = os.path.join("prototypes", "blender_rooms", "library_room")

BACK_Y = 166.0
WALL_H = 150.0
WEST_X = 44.0
# The east wall stands behind the alcoves the collision leaves open (to x
# 1422); the strips between them are filled with low cabinets.
EAST_X = 1424.0
BAY = (548.0, 906.0)
DAIS_H = 14.0
DAIS_FRONT = 261.0
STAIR_X = (678.0, 776.0)
STAIR_FRONT = 275.0
GALLERY_H = 112.0
GALLERY_FRONT = 206.0
GALLERIES = ((292.0, 548.0), (906.0, 1101.0))
GREAT_WINDOWS = ((84.0, 130.0), (170.0, 216.0), (1128.0, 1174.0), (1268.0, 1314.0))
WINDOW_SILL, WINDOW_SPRING = 30.0, 92.0
SPECTRUM_WINDOW = (683.0, 771.0)
SPECTRUM_SILL, SPECTRUM_SPRING = 42.0, 100.0
# The south front, as the painting draws it: the floor ends at the room's
# south edge on a pale coping, and the wall's face drops below it into the
# dark. Each run (x0, x1, plan y of the edge) follows the collision; under
# the gatehouse the edge is hidden by its walls.
SOUTH_EDGE = ((-120.0, 115.0, 947.0), (115.0, 503.0, 966.0), (503.0, 913.0, 948.0), (913.0, 1333.0, 966.0),
              (1333.0, 1570.0, 959.0))
COPING_DROP, FACE_DROP = 18.0, 62.0
# The gatehouse stands forward of the edge at the corridor's end, its face at
# plan y GATE_FACE, the threshold at the floor's height and steps going down
# toward the camera; screen y is GATE_FACE - h on its face.
GATE_FACE = 1027.0
GATE_X = (503.0, 913.0)
GATE_BASE = -33.0
DOOR_SPAN = (667.0, 747.0)
DOOR_SPRING, DOOR_APEX = 60.0, 86.0
MOSAIC = (711.0, 820.0, 82.0)
# The flagstones' tops lie FLOOR_TOP px over the floor; rugs, the medallion
# and the awakened writing lie over them.
FLOOR_TOP = (1.0, 1.5)
RUG_H = 2.2
# The cobbles at the foot of the dais stair, as the painting lays them.
COBBLES = (684.0, 772.0, 280.0, 346.0)
# The game's optical array (library_room.gd _create_rgb_filter_stand) draws its
# lenses at screen y 650 and its scanner at (724, 612), and the player walks
# over it: the HD array is a plate let into the floor, its lens beds at plan y
# CONSOLE_Y on a CONSOLE_H px rim, the scanner on the research desk's front.
CONSOLE_Y, CONSOLE_H = 652.5, 2.5
LENS_X = (664.0, 724.0, 784.0)
SCANNER = (724.0, 651.5, 38.0)
# Moonlight through the north windows travels south, a little east, and down
# at MOON_ELEVATION in game px (h px per plan px is its tangent).
MOON_ELEVATION = 28.0
MOON_DRIFT = 0.1
VIOLET = (0.62, 0.36, 1.0)
CANDLE = (1.0, 0.6, 0.28)
STATION = {"red": (1.0, 0.22, 0.14), "green": (0.32, 1.0, 0.42), "blue": (0.3, 0.5, 1.0)}
SPECTRUM = ((1.0, 0.07, 0.05), (1.0, 0.4, 0.04), (1.0, 0.85, 0.1), (0.14, 0.9, 0.2), (0.08, 0.38, 1.0),
            (0.22, 0.1, 0.85), (0.56, 0.12, 0.92))
ROUND = math.cos(math.radians(hall.ALPHA_DEGREES))
# The archive is lit by many small flames; each of its candles and lamps burns
# this much brighter than the Wake Room's, so their light carries across it.
WARMTH = 1.7
# The view: exposure (the awakened archive a little brighter, as it always
# was) and white balance (K; lower is cooler), measured against the painting.
LIBRARY_EXPOSURE = float(os.environ.get("LIBRARY_EXPOSURE", "-0.2"))
AWAKENED_LIFT = 0.08
LIBRARY_WHITE_BALANCE = float(os.environ.get("LIBRARY_WHITE_BALANCE", "6350"))

SHAFTS = []
LAMPS = {}


def collision_rects():
    """Each Worldsort piece's collision (x0, y0, x1, y1) in px, read from the
    room's scene: the node's position, its FurnitureCollision's and its
    FurnitureShape's, with the rectangle's size."""
    with open(SCENE, encoding="utf-8") as handle:
        text = handle.read()
    sizes = {match.group(1): (float(match.group(2)), float(match.group(3))) for match in re.finditer(
        r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\nsize = Vector2\(([^,]+), ([^)]+)\)', text)}
    offsets, shapes = {}, {}
    for block in re.split(r"\n(?=\[node )", text):
        head = re.match(r'\[node name="([^"]+)"(?: type="[^"]+")? parent="([^"]+)"', block)
        if head is None:
            continue
        name, parent = head.groups()
        found = re.search(r"\nposition = Vector2\(([^,]+), ([^)]+)\)", block)
        position = Vector((float(found.group(1)), float(found.group(2)))) if found else Vector((0.0, 0.0))
        path = parent + "/" + name
        offsets[path] = position
        if name == "FurnitureShape":
            shapes[path] = sizes[re.search(r'shape = SubResource\("([^"]+)"\)', block).group(1)]
    rects = {}
    for path, (width, height) in shapes.items():
        parts = path.split("/")
        centre = Vector((0.0, 0.0))
        for depth in range(2, len(parts) + 1):
            centre += offsets.get("/".join(parts[:depth]), Vector((0.0, 0.0)))
        rects[parts[1]] = (centre.x - width / 2.0, centre.y - height / 2.0,
                           centre.x + width / 2.0, centre.y + height / 2.0)
    return rects


# ---------------------------------------------------------------- materials


def oak():
    """The archive's furniture by the room standard: old waxed oak, each piece
    its own part and shade of a worn photo, rims worn paler, grime in the
    corners (the Chemistry Room's aged_oak)."""
    return chem.aged_oak()


def dark_oak():
    """Darkened oak: the tall archive towers and the emblem cabinet. The same
    waxed oak laid piece by piece, older and darker."""
    return chem.laid("LibraryDarkOak", "wood_table", 1.0, 0.6, (0.9, 0.76, 0.66), saturation=0.75, variety=0.18,
                     wear=0.35, ao=0.32, roughness=0.9, coat=0.26, coat_roughness=0.26, bevel=0.012)


def violet_lacquer():
    return RP.textured("LibraryViolet", "wood_table_worn", 0.42, 0.66, (0.56, 0.34, 0.86), saturation=0.2, ao=0.25)


def dais_stone():
    """Pale dressed stone for the dais and its stair: it shows the rainbow."""
    return RP.textured("LibraryDaisStone", "large_grey_tiles", 0.9, 0.9, (0.84, 0.8, 0.84), saturation=0.4, ao=0.2)


def carved_stone():
    return RP.textured("LibraryCarvedStone", "large_grey_tiles", 0.5, 0.78, (0.78, 0.74, 0.82), ao=0.15)


def brass():
    return hall._brass()


def iron():
    return hall._cast_iron()


def emblem_brass():
    """The cases' brass marks. Awakened, the archive's light wakes them gold."""
    if not AWAKENED:
        return hall._brass()
    return hall._material("LibraryEmblemLit", lambda nodes, links: hall._principled(
        nodes, links, (0.7, 0.52, 0.24), roughness=0.3, metallic=1.0, emission=(1.0, 0.7, 0.32),
        emission_strength=0.45))


def polished_brass():
    return hall._prop_metal("LibraryPolishedBrass", (0.86, 0.66, 0.3), 0.14)


def velvet():
    return wake.velvet()


def chair_velvet():
    """The reading chairs' worn plum velvet: duller than the Wake Room's bed."""
    return wake._sheen(RP.textured("LibraryChairVelvet", "velour_velvet", 0.3, 0.62, (0.34, 0.15, 0.42),
                                   saturation=0.0, ao=0.35), (0.7, 0.55, 0.85), weight=0.45, roughness=0.5)


def mirror():
    return hall._material("LibraryMirror", lambda nodes, links: hall._principled(
        nodes, links, (0.86, 0.88, 0.92), roughness=0.04, metallic=1.0))


def glass():
    return wake.jar_glass()


def leather_top(name, color):
    return wake.leather(name, color)


def glow(name, color, strength, base=None):
    return hall._glow_material(name, color, strength, base or tuple(channel * 0.3 for channel in color))


def knowledge_glow():
    """The one filed volume left in each knowledge case: its tag catches the eye."""
    strength = 4.0 if AWAKENED else 1.6
    return glow("LibraryKnowledgeTag" + ("Lit" if AWAKENED else ""), (0.78, 0.6, 1.0), strength, (0.3, 0.16, 0.5))


def laid_stone(name, asset, repeat, value, tint, warm=None, saturation=0.45, variety=0.2, wear=0.0, ao=0.2,
               fade=None, mottle=0.0):
    """Stone laid piece by piece, as the painting lays its flags and blocks:
    each piece (a mesh island) shows its own part of a CC0 photo in its own
    shade, between `tint` and `warm`, so no two read as one slab cut up.
    With `wear` the rims of its top, where it turns down from level, are worn
    paler; with `fade` (h0, h1 in screen px) it darkens below h1 to almost
    nothing at h0, as a wall dropping into the dark does; `mottle` clouds
    each piece with darker and lighter patches a few px across."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        island = nodes.new("ShaderNodeNewGeometry").outputs["Random Per Island"]
        if RP.TEXTURES is None or not os.path.exists(RP.TEXTURES._path(asset, "diff")):
            low = tuple(channel * min(value, 1.0) * 0.2 for channel in tint)
            high = tuple(channel * min(value, 1.0) * 0.34 for channel in tint)
            hall._principled(nodes, links, hall._mix(nodes, links, island, low, high), roughness=0.8)
            return
        maps = RP.TEXTURES.sample(nodes, links, asset, repeat=repeat)
        coords = next(node for node in nodes if node.type == "TEX_COORD")
        mapping = next(node for node in nodes if node.type == "MAPPING")
        shift = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("MULTIPLY", island, 7.31), shift.inputs["X"])
        links.new(op("MULTIPLY", island, 3.77), shift.inputs["Y"])
        moved = nodes.new("ShaderNodeVectorMath")
        moved.operation = "ADD"
        links.new(coords.outputs["UV"], moved.inputs[0])
        links.new(shift.outputs[0], moved.inputs[1])
        links.new(moved.outputs[0], mapping.inputs["Vector"])
        hue = op("FRACT", op("MULTIPLY", island, 13.7))
        tone = hall._mix(nodes, links, hue, tint, warm or tint)
        color = hall._grade(nodes, links, maps["diff"], value, (1.0, 1.0, 1.0), saturation=saturation)
        color = hall._mix(nodes, links, 1.0, color, tone, blend="MULTIPLY")
        shade = op("ADD", 1.0 - variety, op("MULTIPLY", op("FRACT", op("MULTIPLY", island, 5.3)), 2.0 * variety))
        greys = nodes.new("ShaderNodeCombineColor")
        for socket in ("Red", "Green", "Blue"):
            links.new(shade, greys.inputs[socket])
        color = hall._mix(nodes, links, 1.0, color, greys.outputs["Color"], blend="MULTIPLY")
        if mottle > 0.0:
            clouds = hall._noise(nodes, links, moved.outputs[0], scale=2.2, detail=3.0, roughness=0.5)
            patch = op("ADD", 1.0 - mottle, op("MULTIPLY", clouds, 2.0 * mottle))
            tones = nodes.new("ShaderNodeCombineColor")
            for socket in ("Red", "Green", "Blue"):
                links.new(patch, tones.inputs[socket])
            color = hall._mix(nodes, links, 1.0, color, tones.outputs["Color"], blend="MULTIPLY")
        geometry = nodes.new("ShaderNodeNewGeometry")
        if wear > 0.0:
            normal = nodes.new("ShaderNodeSeparateXYZ")
            links.new(geometry.outputs["True Normal"], normal.inputs[0])
            up = normal.outputs["Z"]
            rim = op("MULTIPLY", hall._ramp(nodes, links, up, 0.995, 0.8), op("GREATER_THAN", up, 0.2))
            pale = hall._mix(nodes, links, 1.0, color, (2.0, 1.95, 1.9), blend="MULTIPLY")
            color = hall._mix(nodes, links, op("MULTIPLY", rim, wear), color, pale)
        if fade is not None:
            position = nodes.new("ShaderNodeSeparateXYZ")
            links.new(geometry.outputs["Position"], position.inputs[0])
            low, high = (h / RP.SIN * RP.PX for h in fade)
            dark = op("ADD", 0.06, op("MULTIPLY", hall._ramp(nodes, links, position.outputs["Z"], low, high), 0.94))
            dim = nodes.new("ShaderNodeCombineColor")
            for socket in ("Red", "Green", "Blue"):
                links.new(dark, dim.inputs[socket])
            color = hall._mix(nodes, links, 1.0, color, dim.outputs["Color"], blend="MULTIPLY")
        if ao > 0.0:
            color = hall._ao_multiply(nodes, links, color, distance=ao, floor_value=0.45)
        hall._principled(nodes, links, color, roughness=maps["rough"], normal=maps["normal"])
    return hall._material(name, build)


def flagstone_material():
    """The archive's flags: dark slate-grey stone, some warmer, some cooler,
    their rims worn pale by the readers' feet."""
    return laid_stone("LibraryFlagstone", "seaside_rock", 0.32, 1.5, (0.8, 0.77, 0.76), warm=(0.94, 0.8, 0.66),
                      variety=0.3, wear=0.1, ao=0.2, mottle=0.3)


def joint_material():
    """The floor between the flags: dark grit, nearly black."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grit = hall._noise(nodes, links, coords.outputs["Object"], scale=160.0, detail=6.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grit, (0.011, 0.01, 0.01), (0.026, 0.022, 0.02)),
                         roughness=0.95)
    return hall._material("LibraryJoints", build)


def void_material():
    """Below the south front: the dark the wall drops into."""
    return hall._material("LibraryVoid", lambda nodes, links: hall._principled(
        nodes, links, (0.003, 0.0025, 0.004), roughness=1.0))


def pale_stone(name="LibraryPaleStone", fade=None):
    """The pale dressed stone of the coping and the piers' caps."""
    return laid_stone(name, "large_grey_tiles", 0.55, 0.62, (0.82, 0.8, 0.84), warm=(0.9, 0.84, 0.78), variety=0.14,
                      ao=0.12, fade=fade)


def dressed_stone(name="LibraryDressedStone", fade=None):
    """The gatehouse's pilasters, hood and door frame: dressed stone between
    the pale caps and the dark ashlar."""
    return laid_stone(name, "large_grey_tiles", 0.55, 0.42, (0.78, 0.76, 0.8), warm=(0.86, 0.8, 0.74), variety=0.16,
                      ao=0.14, fade=fade)


def ashlar_stone(name="LibraryAshlar", fade=None):
    """The gatehouse's and the south wall's dark ashlar."""
    return laid_stone(name, "large_grey_tiles", 0.6, 0.36, (0.7, 0.68, 0.76), warm=(0.8, 0.72, 0.66), variety=0.24,
                      ao=0.15, fade=fade)


def gate_oak():
    """The gatehouse doors: weathered oak laid board by board, unwaxed."""
    return chem.laid("LibraryGateOak", "wood_table_worn", 1.0, 0.72, (0.92, 0.74, 0.6), saturation=0.8, variety=0.2,
                     wear=0.45, ao=0.3, roughness=0.95)


def banner_material(name):
    """A Library banner as the painting hangs them: deep blue, edged in gold,
    pointed at its foot, a gold cross in a ring on it. UVs 0..1, v up."""
    aspect = 2.4

    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        edge = op("ABSOLUTE", op("SUBTRACT", u, 0.5))
        hem = op("SUBTRACT", v, op("MULTIPLY", op("SUBTRACT", 0.5, edge), 0.44))
        trim = op("MAXIMUM", op("MAXIMUM", op("GREATER_THAN", edge, 0.4), op("LESS_THAN", hem, 0.045)),
                  op("GREATER_THAN", v, 0.95))
        sx = op("DIVIDE", op("SUBTRACT", u, 0.5), 0.4)
        sy = op("DIVIDE", op("MULTIPLY", op("SUBTRACT", v, 0.56), aspect), 0.4)
        radius = op("SQRT", op("ADD", op("MULTIPLY", sx, sx), op("MULTIPLY", sy, sy)))
        upright = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", sx), 0.1), op("LESS_THAN", op("ABSOLUTE", sy), 0.78))
        across = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", sy), 0.1), op("LESS_THAN", op("ABSOLUTE", sx), 0.58))
        ring = op.between(radius, 0.36, 0.48)
        tips = None
        for tx, ty in ((0.0, 0.86), (0.0, -0.86), (0.66, 0.0), (-0.66, 0.0)):
            tip = op("LESS_THAN", op("ADD", op("ABSOLUTE", op("SUBTRACT", sx, tx)),
                                     op("ABSOLUTE", op("SUBTRACT", sy, ty))), 0.16)
            tips = tip if tips is None else op("MAXIMUM", tips, tip)
        gold = op("MAXIMUM", op("MAXIMUM", trim, op("MAXIMUM", upright, across)), op("MAXIMUM", ring, tips))
        folds = op("ADD", 0.74, op("MULTIPLY", 0.26, op("SINE", op("MULTIPLY", u, 2.0 * math.pi * 2.0))))
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=70.0, detail=2.0)
        cloth = hall._mix(nodes, links, weave, (0.026, 0.04, 0.15), (0.016, 0.024, 0.09))
        color = hall._mix(nodes, links, op("SUBTRACT", 1.0, folds), cloth, (0.0, 0.0, 0.0))
        color = hall._mix(nodes, links, gold, color, (0.7, 0.5, 0.2))
        shader = hall._principled(nodes, links, color, roughness=op("SUBTRACT", 0.9, op("MULTIPLY", gold, 0.55)))
        links.new(op("MULTIPLY", gold, 0.9), shader.inputs["Metallic"])
        if AWAKENED:
            shader.inputs["Emission Color"].default_value = (1.0, 0.7, 0.32, 1.0)
            links.new(op("MULTIPLY", gold, 0.35), shader.inputs["Emission Strength"])
        hall._alpha_cut(nodes, links, shader, op("GREATER_THAN", hem, 0.0))
    return hall._material(name + ("Lit" if AWAKENED else ""), build)


def stained_glass(name, palette, cells=0.11, light=0.62, lit=1.3):
    """Leaded glass with the moon behind it: each pane takes a colour from
    `palette` and the light passing it takes the pane's colour, so the
    window lays its pattern on the floor. UVs are the opening's (x, h) px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, _u, _v = hall._uv_parts(nodes, links)
        panes = nodes.new("ShaderNodeTexVoronoi")
        panes.inputs["Scale"].default_value = cells
        links.new(coords.outputs["UV"], panes.inputs["Vector"])
        pick = nodes.new("ShaderNodeSeparateColor")
        links.new(panes.outputs["Color"], pick.inputs[0])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        elements = ramp.color_ramp.elements
        while len(elements) < len(palette):
            elements.new(0.5)
        for index, (element, colour) in enumerate(zip(elements, palette)):
            element.position = index / len(palette)
            element.color = tuple(colour) + (1.0,)
        links.new(pick.outputs[0], ramp.inputs["Fac"])
        edges = nodes.new("ShaderNodeTexVoronoi")
        edges.feature = "DISTANCE_TO_EDGE"
        edges.inputs["Scale"].default_value = cells
        links.new(coords.outputs["UV"], edges.inputs["Vector"])
        lead = op("LESS_THAN", edges.outputs["Distance"], 0.07)
        shade = hall._noise(nodes, links, coords.outputs["UV"], scale=0.35, detail=3.0)
        colour = hall._mix(nodes, links, op("MULTIPLY", shade, 0.35), ramp.outputs["Color"], (1.0, 1.0, 1.0))
        emission = nodes.new("ShaderNodeEmission")
        links.new(colour, emission.inputs["Color"])
        emission.inputs["Strength"].default_value = lit
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        links.new(colour, transparent.inputs["Color"])
        pane = nodes.new("ShaderNodeMixShader")
        pane.inputs["Fac"].default_value = light
        links.new(emission.outputs["Emission"], pane.inputs[1])
        links.new(transparent.outputs["BSDF"], pane.inputs[2])
        came = nodes.new("ShaderNodeBsdfPrincipled")
        came.inputs["Base Color"].default_value = (0.03, 0.028, 0.03, 1.0)
        came.inputs["Metallic"].default_value = 0.6
        came.inputs["Roughness"].default_value = 0.5
        mix = nodes.new("ShaderNodeMixShader")
        links.new(lead, mix.inputs["Fac"])
        links.new(pane.outputs["Shader"], mix.inputs[1])
        links.new(came.outputs["BSDF"], mix.inputs[2])
        output = nodes.new("ShaderNodeOutputMaterial")
        links.new(mix.outputs["Shader"], output.inputs["Surface"])
    return hall._material(name, build)


def spectrum_glass():
    """The spectrum window's glass: seven lights, red to violet, under a head
    of pale moon-white glass. UVs are the opening's (x, h) px."""
    x0, x1 = SPECTRUM_WINDOW

    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        elements = ramp.color_ramp.elements
        while len(elements) < len(SPECTRUM):
            elements.new(0.5)
        for index, (element, colour) in enumerate(zip(elements, SPECTRUM)):
            element.position = index / len(SPECTRUM)
            element.color = colour + (1.0,)
        links.new(op("DIVIDE", op("SUBTRACT", u, x0), x1 - x0), ramp.inputs["Fac"])
        head = op("GREATER_THAN", v, SPECTRUM_SPRING)
        ripple = hall._noise(nodes, links, coords.outputs["UV"], scale=0.4, detail=3.0)
        light = hall._mix(nodes, links, op("MULTIPLY", ripple, 0.25), ramp.outputs["Color"], (1.0, 1.0, 1.0))
        colour = hall._mix(nodes, links, head, light, (0.78, 0.84, 1.0))
        emission = nodes.new("ShaderNodeEmission")
        links.new(colour, emission.inputs["Color"])
        emission.inputs["Strength"].default_value = 1.5
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        links.new(colour, transparent.inputs["Color"])
        mix = nodes.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = 0.72
        links.new(emission.outputs["Emission"], mix.inputs[1])
        links.new(transparent.outputs["BSDF"], mix.inputs[2])
        output = nodes.new("ShaderNodeOutputMaterial")
        links.new(mix.outputs["Shader"], output.inputs["Surface"])
    return hall._material("LibrarySpectrumGlass", build)


def rug_material(name, length, width, field, pattern, border, gold):
    """A runner or carpet as the painting draws them: a dark border band
    strung with gold dots between gold lines, a guard of small dots, and in
    the field gold rosettes down a runner's middle with sprigs between them,
    or a carpet's lozenge medallion, corner rosettes and a lattice of small
    flowers; a trodden middle and fringed ends. UVs are px: u along its
    length, v across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)

        def square(value):
            return op("MULTIPLY", value, value)

        def rosette(du, dv, radius):
            """A gold rosette of radius `radius` px about (du, dv) = 0: a ring,
            eight petals and a dark heart. Returns (gold, heart)."""
            reach = op("SQRT", op("ADD", square(du), square(dv)))
            petals = op("MULTIPLY", op("GREATER_THAN", op("COSINE", op("MULTIPLY", op("ARCTAN2", dv, du), 8.0)), 0.25),
                        op.between(reach, radius * 0.3, radius * 0.66))
            ring = op.between(reach, radius * 0.76, radius * 0.94)
            core = op("LESS_THAN", reach, radius * 0.22)
            return op("MAXIMUM", op("MAXIMUM", petals, ring), core), op.between(reach, radius * 0.22, radius * 0.3)

        to_end = op("MINIMUM", u, op("SUBTRACT", length, u))
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        edge = op("MINIMUM", to_side, to_end)
        on_side = op("LESS_THAN", to_side, to_end)
        along = op("ADD", op("MULTIPLY", u, on_side), op("MULTIPLY", v, op("SUBTRACT", 1.0, on_side)))
        band = op("LESS_THAN", edge, 7.5)
        cell = op("MULTIPLY", op("SUBTRACT", op("FRACT", op("DIVIDE", along, 5.0)), 0.5), 5.0)
        band_dots = op("MULTIPLY", band, op("LESS_THAN", op("ADD", square(cell), square(op("SUBTRACT", edge, 3.8))),
                                            1.6))
        lines = op("MAXIMUM", op.between(edge, 7.5, 8.8), op.between(edge, 13.2, 14.4))
        guard = op.between(edge, 8.8, 13.2)
        small = op("MULTIPLY", op("SUBTRACT", op("FRACT", op("DIVIDE", along, 4.0)), 0.5), 4.0)
        guard_dots = op("MULTIPLY", guard, op("LESS_THAN", op("ADD", square(small),
                                                              square(op("SUBTRACT", edge, 11.0))), 0.8))
        inside = op("GREATER_THAN", edge, 14.4)
        dv = op("SUBTRACT", v, width / 2.0)
        across = op("DIVIDE", op("ABSOLUTE", dv), width / 2.0 - 15.0)
        medallion = None
        if width < 100.0:
            period = 46.0
            radius = min(width * 0.3, 11.0)
            step = op("DIVIDE", op("SUBTRACT", u, length / 2.0), period)
            du = op("MULTIPLY", op("SUBTRACT", step, op("ROUND", step)), period)
            gold_rose, heart = rosette(du, dv, radius)
            room = op("GREATER_THAN", to_end, 16.0 + radius)
            gold_rose = op("MULTIPLY", gold_rose, room)
            half = op("ADD", step, 0.5)
            mid = op("MULTIPLY", op("SUBTRACT", half, op("ROUND", half)), period)
            sprig = op("MULTIPLY", op("LESS_THAN", op("ADD", op("ABSOLUTE", mid), op("ABSOLUTE", dv)), 3.4),
                       op("GREATER_THAN", to_end, 20.0))
            off = width / 2.0 - 21.0
            flowers = op("MAXIMUM", op("LESS_THAN", op("ADD", op("ABSOLUTE", mid),
                                                         op("ABSOLUTE", op("SUBTRACT", op("ABSOLUTE", dv), off))), 2.4),
                         op("MULTIPLY", heart, room))
            flowers = op("MULTIPLY", flowers, op("GREATER_THAN", to_end, 18.0))
            golds = op("MAXIMUM", gold_rose, sprig)
        else:
            lengthwise = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", u, length / 2.0)), length / 2.0 - 18.0)
            lozenge = op("ADD", across, lengthwise)
            medallion = op("MAXIMUM", op.between(lozenge, 0.5, 0.55), op.between(lozenge, 0.62, 0.64))
            centre_gold, _heart = rosette(op("SUBTRACT", u, length / 2.0), dv, min(width, length) * 0.14)
            corner_gold = None
            radius = 10.0
            for cu in (24.0, length - 24.0):
                for cv in (24.0, width - 24.0):
                    gold_corner, _ = rosette(op("SUBTRACT", u, cu), op("SUBTRACT", v, cv), radius)
                    corner_gold = gold_corner if corner_gold is None else op("MAXIMUM", corner_gold, gold_corner)
            lattice = op("LESS_THAN", op("ADD",
                                         op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", u, 18.0)), 0.5)),
                                         op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", v, 18.0)), 0.5))), 0.1)
            outside = op("GREATER_THAN", lozenge, 0.55)
            corners_clear = op("SUBTRACT", 1.0, corner_gold)
            flowers = op("MULTIPLY", op("MULTIPLY", lattice, outside), corners_clear)
            golds = op("MAXIMUM", op("MULTIPLY", centre_gold, op("LESS_THAN", lozenge, 0.5)), corner_gold)
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=0.7, detail=6.0)
        wear = hall._ramp(nodes, links, op("ADD", weave, op("MULTIPLY", op("SUBTRACT", 0.45, across), 0.4)), 0.6,
                          0.95)
        colour = hall._mix(nodes, links, op("MULTIPLY", flowers, inside), field, pattern)
        if medallion is not None:
            colour = hall._mix(nodes, links, op("MULTIPLY", medallion, inside), colour, border)
        colour = hall._mix(nodes, links, band, colour, border)
        colour = hall._mix(nodes, links, op("MULTIPLY", guard, 0.55), colour, (0.0, 0.0, 0.0))
        golden = op("MAXIMUM", op("MAXIMUM", lines, band_dots), guard_dots)
        golden = op("MAXIMUM", golden, op("MULTIPLY", golds, inside))
        golden = op("MAXIMUM", golden, op("LESS_THAN", edge, 1.6))
        colour = hall._mix(nodes, links, golden, colour, gold)
        colour = hall._mix(nodes, links, op("MULTIPLY", wear, 0.35), colour, (0.26, 0.24, 0.26))
        fringe = op("LESS_THAN", to_end, 3.0)
        threads = op("LESS_THAN", op("FRACT", op("DIVIDE", v, 1.7)), 0.55)
        colour = hall._mix(nodes, links, fringe, colour, (0.5, 0.44, 0.34))
        roughness, normal = 0.95, None
        if RP.TEXTURES is not None and RP.TEXTURES.available():
            pile = RP.TEXTURES.sample(nodes, links, "dirty_carpet", repeat=40.0)
            fibres = hall._grade(nodes, links, pile["diff"], 2.6, (1.0, 1.0, 1.0), saturation=0.0)
            colour = hall._mix(nodes, links, 0.55, colour, hall._mix(nodes, links, 1.0, colour, fibres,
                                                                      blend="MULTIPLY"))
            roughness, normal = pile["rough"], pile["normal"]
        shader = hall._principled(nodes, links, colour, roughness=roughness, normal=normal)
        hall._alpha_cut(nodes, links, shader,
                        op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0, threads))))
    return hall._material(name, build)


def mosaic_material(radius):
    """The floor medallion: three circles of smoked glass let into dark stone,
    each ringed in brass and overlapping as the archive's three lamps do, eight
    lens studs round them and a square brass border. Awakened, each circle
    shines in its lamp's colour, and where they overlap the light adds up:
    yellow, cyan and magenta, and white at the heart. UVs are px from its
    centre, v north."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        x, y = op("DIVIDE", u, radius), op("DIVIDE", v, radius)
        r = op("SQRT", op("ADD", op("MULTIPLY", x, x), op("MULTIPLY", y, y)))
        theta = op("ARCTAN2", y, x)
        inside, rims = [], []
        # The classic diagram: red to the north (toward the research desk),
        # green to the east and blue to the west, each 120 degrees apart.
        for angle in (90.0, 330.0, 210.0):
            cx, cy = 0.27 * math.cos(math.radians(angle)), 0.27 * math.sin(math.radians(angle))
            dx, dy = op("SUBTRACT", x, cx), op("SUBTRACT", y, cy)
            distance = op("SQRT", op("ADD", op("MULTIPLY", dx, dx), op("MULTIPLY", dy, dy)))
            inside.append(op("LESS_THAN", distance, 0.46))
            rims.append(op.between(distance, 0.448, 0.474))
        sector = op("DIVIDE", theta, math.pi / 4.0)
        offset = op("SUBTRACT", op("FRACT", sector), 0.5)
        along = op("MULTIPLY", op("MULTIPLY", offset, math.pi / 4.0), r)
        radial = op("SUBTRACT", r, 0.81)
        stud_d = op("SQRT", op("ADD", op("MULTIPLY", along, along), op("MULTIPLY", radial, radial)))
        stud = op("LESS_THAN", stud_d, 0.066)
        stud_rim = op.between(stud_d, 0.066, 0.084)
        rings = op("MAXIMUM", op("MAXIMUM", op.between(r, 0.95, 0.985), op.between(r, 0.885, 0.9)),
                   op.between(r, 0.7, 0.71))
        square = op("MAXIMUM", op("ABSOLUTE", x), op("ABSOLUTE", y))
        border = op("MAXIMUM", op.between(square, 1.0, 1.045), op.between(square, 1.07, 1.085))
        brass_mask = op("MINIMUM", op("ADD", op("ADD", op("MAXIMUM", op("MAXIMUM", rims[0], rims[1]), rims[2]), rings),
                                      op("ADD", stud_rim, border)), 1.0)
        open_glass = op("MULTIPLY", op("MAXIMUM", op("MAXIMUM", inside[0], inside[1]), inside[2]),
                        op("SUBTRACT", 1.0, brass_mask))
        lens = op("MULTIPLY", stud, op("SUBTRACT", 1.0, brass_mask))
        grain = hall._noise(nodes, links, coords.outputs["UV"], scale=0.12, detail=5.0)
        stone = hall._mix(nodes, links, grain, (0.03, 0.028, 0.04), (0.07, 0.064, 0.08))
        tint = nodes.new("ShaderNodeCombineColor")
        for channel, mask in zip(("Red", "Green", "Blue"), inside):
            links.new(op("ADD", 0.025, op("MULTIPLY", mask, 0.05)), tint.inputs[channel])
        colour = hall._mix(nodes, links, open_glass, stone, tint.outputs["Color"])
        colour = hall._mix(nodes, links, lens, colour, (0.06, 0.06, 0.09))
        colour = hall._mix(nodes, links, brass_mask, colour, (0.62, 0.45, 0.19))
        roughness = op("SUBTRACT", 0.85, op("ADD", op("MULTIPLY", brass_mask, 0.55),
                                            op("MULTIPLY", op("ADD", open_glass, lens), 0.75)))
        shader = hall._principled(nodes, links, colour, roughness=roughness)
        links.new(brass_mask, shader.inputs["Metallic"])
        if AWAKENED:
            light = nodes.new("ShaderNodeCombineColor")
            for channel, mask in zip(("Red", "Green", "Blue"), inside):
                glint = op("ADD", lens, op("MULTIPLY", brass_mask, 0.12))
                links.new(op("ADD", op("MULTIPLY", mask, open_glass), glint), light.inputs[channel])
            links.new(light.outputs["Color"], shader.inputs["Emission Color"])
            # Low enough that AgX keeps each lamp's colour: red, green and
            # blue, yellow, cyan and magenta where two meet, white at the heart.
            shader.inputs["Emission Strength"].default_value = 1.1
        keep = op("MAXIMUM", op("LESS_THAN", r, 0.99), op("LESS_THAN", square, 1.09))
        hall._alpha_cut(nodes, links, shader, keep)
    return hall._material("LibraryMosaic" + ("Lit" if AWAKENED else ""), build)


def glyph_line_material(name, colour, length):
    """Hidden writing on the stone that only the archive's pale light shows: a
    fine line of light strung with glyphs, pale at the medallion and taking
    its lamp's colour toward the lamp. UVs: u px along it from the medallion,
    v across it from -1 to 1."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        across = op("ABSOLUTE", v)
        core = op("LESS_THAN", across, 0.09)
        cell = op("FRACT", op("DIVIDE", u, 9.0))
        pick = hall._noise(nodes, links, coords.outputs["UV"], scale=0.11, detail=1.0)
        strokes = op("MULTIPLY", op.between(across, 0.42, 0.72),
                     op("MULTIPLY", op("LESS_THAN", cell, 0.45), op("GREATER_THAN", pick, 0.5)))
        ticks = op("MULTIPLY", op("LESS_THAN", across, 0.26), op("LESS_THAN", op("FRACT", op("DIVIDE", u, 23.0)), 0.06))
        mark = op("MINIMUM", op("ADD", op("ADD", core, strokes), ticks), 1.0)
        fade = op("SUBTRACT", 1.0, op("MULTIPLY", op("DIVIDE", u, length), 0.5))
        shade = hall._mix(nodes, links, op("MINIMUM", op("DIVIDE", u, length * 0.2), 1.0), (1.0, 0.96, 0.9),
                          colour)
        shader = hall._principled(nodes, links, (0.05, 0.05, 0.06), roughness=0.6, emission=shade,
                                  emission_strength=op("MULTIPLY", fade, 2.4))
        hall._alpha_cut(nodes, links, shader, mark)
    return hall._material(name, build)


def schematic_material(width, height, centre_x, centre_h):
    """The archive's hidden diagram round the spectrum window, drawn on the
    wall in light: rings, a toothed wheel, radial marks and rows of glyphs.
    UVs are the wall's (x, h) px."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        dx, dh = op("SUBTRACT", u, centre_x), op("SUBTRACT", v, centre_h)
        r = op("SQRT", op("ADD", op("MULTIPLY", dx, dx), op("MULTIPLY", dh, dh)))
        theta = op("ARCTAN2", dh, dx)
        rings = op("MAXIMUM", op("MAXIMUM", op.between(r, 61.0, 61.8), op.between(r, 73.0, 73.6)),
                   op.between(r, 92.0, 92.8))
        teeth = op("MULTIPLY", op.between(r, 61.8, 64.6),
                   op("GREATER_THAN", op("COSINE", op("MULTIPLY", theta, 36.0)), 0.5))
        ticks = op("MULTIPLY", op.between(r, 77.0, 86.0),
                   op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", theta, math.pi / 24.0)),
                                                                0.5)), 0.04))
        pick = hall._noise(nodes, links, coords.outputs["UV"], scale=0.16, detail=1.0)
        glyphs = op("MULTIPLY", op("MULTIPLY", op.between(r, 96.0, 102.0), op("GREATER_THAN", pick, 0.52)),
                    op("LESS_THAN", op("FRACT", op("DIVIDE", op("MULTIPLY", theta, r), 7.0)), 0.5))
        mark = op("MINIMUM", op("ADD", op("ADD", rings, teeth), op("ADD", ticks, glyphs)), 1.0)
        shader = hall._principled(nodes, links, (0.04, 0.04, 0.05), roughness=0.6, emission=(0.72, 0.52, 1.0),
                                  emission_strength=op("MULTIPLY", mark, 1.1))
        hall._alpha_cut(nodes, links, shader, mark)
    return hall._material("LibrarySchematic", build)


# ---------------------------------------------------------------- shapes


def prism(kit, part, outline, h0, h1, material, uv="box", bevel=0.0):
    """An upright prism over a plan outline (x, y), from h0 to h1: its caps are
    tessellated, so the outline may be concave."""
    shape = bmesh.new()
    bottom = [shape.verts.new((x, y, h0)) for x, y in outline]
    top = [shape.verts.new((x, y, h1)) for x, y in outline]
    for a, b, c in geometry.tessellate_polygon([[Vector((x, y, 0.0)) for x, y in outline]]):
        shape.faces.new((top[a], top[b], top[c]))
        shape.faces.new((bottom[c], bottom[b], bottom[a]))
    for index in range(len(outline)):
        following = (index + 1) % len(outline)
        shape.faces.new((bottom[index], bottom[following], top[following], top[index]))
    return kit.shape(part, shape, material, uv=uv, bevel=bevel)


def strip(kit, part, a, b, h, inward, width, material):
    """A flat band on top of a wall along its edge from `a` to `b` (plan px),
    reaching `width` px along `inward` into the wall: the lit lip."""
    a, b, inward = Vector(a), Vector(b), Vector(inward).normalized()
    corners = [a - inward * 0.5, b - inward * 0.5, b + inward * width, a + inward * width]
    return kit.quad(part, [(point.x, point.y, h) for point in corners], material)


def lancet(x0, x1, sill, spring, steps=12):
    """A pointed (equilateral) arch's opening, in (x, h)."""
    width = x1 - x0
    right = [(x0 + width * math.cos(math.radians(60.0 * step / steps)),
              spring + width * math.sin(math.radians(60.0 * step / steps))) for step in range(steps + 1)]
    left = [(x1 + width * math.cos(math.radians(120.0 + 60.0 * step / steps)),
             spring + width * math.sin(math.radians(120.0 + 60.0 * step / steps))) for step in range(1, steps + 1)]
    return [(x0, sill), (x1, sill)] + right + left


def round_head(x0, x1, sill, spring, steps=24):
    """A round-headed opening, in (x, h)."""
    radius, centre = (x1 - x0) / 2.0, (x0 + x1) / 2.0
    arc = [(centre + radius * math.cos(math.radians(180.0 * step / steps)),
            spring + radius * math.sin(math.radians(180.0 * step / steps))) for step in range(steps + 1)]
    return [(x0, sill), (x1, sill)] + arc


def screen(x, y, h):
    return [round(float(x), 2), round(float(y - h), 2)]


def moon_ray():
    """The window moonlight's direction in game px per plan px south."""
    return Vector((MOON_DRIFT, 1.0, -math.tan(math.radians(MOON_ELEVATION))))


def landing(x, y, h, floor=0.0):
    """Where window moonlight passing (x, y, h) meets a floor at height `floor`."""
    ray = moon_ray()
    t = (h - floor) / -ray.z
    return x + ray.x * t, y + ray.y * t


# ---------------------------------------------------------------- the shell


def library_shell(materials):
    """The room's floor and walls: the north wall carries the great windows
    and the spectrum window, the side walls lean out as the painted room's
    do, and the south front drops from the floor's edge into the dark."""
    openings = [{"outline": lancet(x0, x1, WINDOW_SILL, WINDOW_SPRING)} for x0, x1 in GREAT_WINDOWS]
    openings.append({"outline": round_head(*SPECTRUM_WINDOW, SPECTRUM_SILL, SPECTRUM_SPRING)})
    spec = {
        "back": {"y": BACK_Y, "base": (WEST_X, EAST_X), "top": (0.0, 1448.0), "height": WALL_H,
                 "openings": openings},
        "left": {"base": ((WEST_X, BACK_Y), (WEST_X, 950.0)), "near": 1300.0},
        "right": {"base": ((EAST_X, BACK_Y), (EAST_X, 950.0)), "near": 1300.0},
        "cap": 40.0,
    }

    class LibraryShell(RP.Shell):
        def _floor(self):
            floor_bed(self)

        def _south_wall(self):
            south_front(self)

    return LibraryShell(spec, materials)


def floor_bed(shell):
    """The bed the flags are laid in, out to the room's south edge: dark grit
    that shows in their joints."""
    outline = [(-80.0, 60.0), (1530.0, 60.0)]
    for x0, x1, y in reversed(SOUTH_EDGE):
        outline += [(min(x1, 1530.0), y), (max(x0, -80.0), y)]
    obj = RP.polygon_mesh("LibraryFloorBed", outline, [], lambda u, v: (u, v, 0.0), shell.materials["floor"],
                          uv_of=lambda u, v: (u / 100.0, -v / 100.0))
    shell._keep(obj, depth=False)


def south_front(shell):
    """The south front, as the painting draws it: the floor ends on a coping
    of pale dressed stone whose lit edge outlines the room, and below it the
    wall's dark ashlar drops into the dark. Under the corridor the gatehouse
    stands forward of it (gate()). The player walks along it from inside the
    room, so it hides no one (no depth)."""
    kit = RP.Kit("SouthFront", depth=False)
    rng = random.Random(947)
    backing, coping, face = [], [], []
    for x0, x1, y in SOUTH_EDGE:
        if (x0, x1) == GATE_X:
            continue
        backing.append((x0, x1, y - 9.0, y - 1.2, -FACE_DROP - 2.0, 0.0))
        x = x0
        while x < x1 - 0.5:
            end = min(x + rng.uniform(34.0, 50.0), x1)
            end = x1 if x1 - end < 14.0 else end
            coping.append((x + 0.7, end - 0.7, y - 5.0, y, -COPING_DROP, 1.3))
            x = end
        for course, (top, bottom) in enumerate(((-COPING_DROP, -40.0), (-40.0, -FACE_DROP))):
            x = x0 - (rng.uniform(8.0, 20.0) if course else 0.0)
            while x < x1 - 0.5:
                end = min(x + rng.uniform(24.0, 44.0), x1)
                end = x1 if x1 - end < 12.0 else end
                face.append((max(x, x0) + 0.6, end - 0.6, y - 6.0, y - 0.5, bottom + 0.6, top - 0.6))
                x = end
    kit.blocks("Backing", backing, joint_material(), bevel=0.0)
    kit.blocks("Coping", coping, pale_stone("LibraryCoping"), bevel=0.5, uv="box")
    kit.blocks("Face", face, ashlar_stone("LibrarySouthAshlar", fade=(-FACE_DROP, -COPING_DROP)), bevel=0.4,
               uv="box")
    depth = -FACE_DROP - 2.0
    kit.quad("Void", [(-300.0, 1500.0, depth), (1750.0, 1500.0, depth), (1750.0, 900.0, depth),
                      (-300.0, 900.0, depth)], void_material())
    for obj in kit.made:
        shell._keep(obj, depth=False)


def parapet():
    """Shadow only: the north wall carried up out of sight, so the window
    moonlight reaches the room through the windows alone."""
    kit = RP.Kit("Parapet", depth=False)
    plane = kit.quad("Plane", [(-400.0, BACK_Y - 1.0, WALL_H - 2.0), (1850.0, BACK_Y - 1.0, WALL_H - 2.0),
                               (1850.0, BACK_Y - 1.0, 1400.0), (-400.0, BACK_Y - 1.0, 1400.0)], hall._bakelite())
    plane.visible_camera = False
    plane.visible_diffuse = False
    plane.visible_glossy = False
    plane.visible_transmission = False
    return kit


def windows():
    """Stained glass in the north wall's openings: cobalt and violet in the
    west pair, emerald and gold in the east, and the spectrum window over the
    dais. Each records the shaft its moonlight makes, for the preview."""
    kit = RP.Kit("Windows")
    rock = carved_stone()
    glass_y = BACK_Y - 16.0
    palettes = {
        "west": ((0.08, 0.2, 0.86), (0.3, 0.1, 0.72), (0.05, 0.46, 0.92), (0.82, 0.8, 1.0), (0.14, 0.08, 0.5)),
        "east": ((0.06, 0.6, 0.28), (0.92, 0.62, 0.12), (0.16, 0.44, 0.16), (0.9, 0.9, 0.7), (0.03, 0.34, 0.24)),
    }
    for index, (x0, x1) in enumerate(GREAT_WINDOWS):
        side = "west" if x0 < BAY[0] else "east"
        outline = lancet(x0, x1, WINDOW_SILL, WINDOW_SPRING)
        pane = RP.polygon_mesh("LibraryWindow%d" % index, outline, [], lambda u, w: (u, glass_y, w),
                               stained_glass("LibraryGlass" + side.title(), palettes[side]),
                               uv_of=lambda u, w: (u, w))
        kit.keep(pane)
        centre = (x0 + x1) / 2.0
        apex = WINDOW_SPRING + (x1 - x0) * math.sin(math.radians(60.0))
        kit.box("Mullion%d" % index, centre - 1.6, centre + 1.6, glass_y - 2.0, glass_y + 2.5, WINDOW_SILL,
                WINDOW_SPRING + 6.0, rock, bevel=0.4, uv="box_up")
        kit.box("Transom%d" % index, x0, x1, glass_y - 2.0, glass_y + 2.5, 60.0, 62.6, rock, bevel=0.4, uv="box")
        kit.ring("Oculus%d" % index, (centre, glass_y + 1.0, WINDOW_SPRING + 18.0), (0.0, 1.0, 0.0), 7.5, 1.3,
                 rock, segments=32, sides=8)
        kit.box("Sill%d" % index, x0 - 4.0, x1 + 4.0, glass_y - 2.0, BACK_Y + 5.0, WINDOW_SILL - 4.0, WINDOW_SILL,
                rock, bevel=0.6, uv="box")
        record_shaft("great", x0, x1, glass_y, WINDOW_SILL, apex, palettes[side][0])
    x0, x1 = SPECTRUM_WINDOW
    outline = round_head(x0, x1, SPECTRUM_SILL, SPECTRUM_SPRING)
    kit.keep(RP.polygon_mesh("LibrarySpectrumWindow", outline, [], lambda u, w: (u, glass_y, w), spectrum_glass(),
                             uv_of=lambda u, w: (u, w)))
    width = (x1 - x0) / len(SPECTRUM)
    for index in range(1, len(SPECTRUM)):
        x = x0 + width * index
        kit.box("SpectrumMullion%d" % index, x - 1.1, x + 1.1, glass_y - 2.0, glass_y + 2.2, SPECTRUM_SILL,
                SPECTRUM_SPRING, rock, bevel=0.3, uv="box_up")
    kit.box("SpectrumTransom", x0, x1, glass_y - 2.0, glass_y + 2.4, SPECTRUM_SPRING - 1.2, SPECTRUM_SPRING + 1.4,
            rock, bevel=0.4, uv="box")
    centre = (x0 + x1) / 2.0
    rose_h = SPECTRUM_SPRING + 20.0
    kit.ring("Rose", (centre, glass_y + 1.0, rose_h), (0.0, 1.0, 0.0), 14.0, 1.5, rock, segments=48, sides=8)
    kit.ring("RoseHeart", (centre, glass_y + 1.2, rose_h), (0.0, 1.0, 0.0), 4.0, 1.0, rock, segments=24, sides=8)
    # A ring round on the wall shows SIN as tall as wide: its spokes too.
    for turn in range(8):
        angle = math.radians(turn * 45.0)
        dx, dh = math.cos(angle), math.sin(angle) * RP.SIN
        kit.rod("RoseSpoke%d" % turn, (centre + 5.0 * dx, glass_y + 1.0, rose_h + 5.0 * dh),
                (centre + 13.0 * dx, glass_y + 1.0, rose_h + 13.0 * dh), 0.7, rock)
    kit.box("SpectrumSill", x0 - 6.0, x1 + 6.0, glass_y - 2.0, BACK_Y + 6.0, SPECTRUM_SILL - 4.0, SPECTRUM_SILL,
            rock, bevel=0.6, uv="box")
    for index, colour in enumerate(SPECTRUM):
        record_shaft("spectrum", x0 + width * index, x0 + width * (index + 1), glass_y, SPECTRUM_SILL,
                     SPECTRUM_SPRING, colour, near_floor=DAIS_H)
    record_shaft("rose", x0, x1, glass_y, SPECTRUM_SPRING, SPECTRUM_SPRING + (x1 - x0) / 2.0, (0.8, 0.86, 1.0))
    return kit


def record_shaft(kind, x0, x1, glass_y, low, high, colour, near_floor=0.0):
    """The moonlight a window lets in, for the preview's light shafts. Where it
    lands is cast through the built room at the end (write_meta): the cases
    standing before the great windows catch most of their light."""
    SHAFTS.append({"kind": kind, "x0": x0, "x1": x1, "glass_y": glass_y, "low": low, "high": high,
                   "near_floor": near_floor, "color": [round(float(channel), 3) for channel in colour]})


def cast_moonlight(x, y, h, near_floor):
    """Where window moonlight passing (x, y, h) first lands in the built room,
    as (x, plan y, h) in game px: the floor, the dais or a case in its way. It
    is followed from just inside the wall's face, past the window's frame."""
    ray = moon_ray()
    step = (BACK_Y + 1.0 - y) / ray.y
    start = Vector((x, y, h)) + ray * step
    direction = (RP.world(*ray) - RP.world(0.0, 0.0, 0.0)).normalized()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, location, _normal, _index, _obj, _matrix = bpy.context.scene.ray_cast(depsgraph, RP.world(*start), direction)
    if hit:
        point = RP.game(location)
        return point.x, point.y, point.z
    lx, ly = landing(x, y, h, near_floor)
    return lx, ly, near_floor


def resolve_shafts():
    """Each shaft's window and the pool its light makes, in screen px. A corner
    ray that slips between two cases to land far beyond the rest is stopped at
    1.25 times the corners' median reach, so a shaft keeps its shape."""
    bpy.context.view_layer.update()
    resolved = []
    for shaft in SHAFTS:
        x0, x1, glass_y, low, high = shaft["x0"], shaft["x1"], shaft["glass_y"], shaft["low"], shaft["high"]
        corners = [(x, h) for x, h in ((x0, high), (x1, high), (x1, low), (x0, low))]
        hits = [Vector(cast_moonlight(x, glass_y, h, shaft["near_floor"])) for x, h in corners]
        starts = [Vector((x, glass_y, h)) for x, h in corners]
        reaches = [(hit - start).length for hit, start in zip(hits, starts)]
        ordered = sorted(reaches)
        limit = 1.25 * (ordered[1] + ordered[2]) / 2.0
        pool = []
        for hit, start, reach in zip(hits, starts, reaches):
            if reach > limit:
                hit = start + (hit - start) * (limit / reach)
            pool.append(screen(hit.x, hit.y, hit.z))
        resolved.append({
            "kind": shaft["kind"], "color": shaft["color"],
            "window": [screen(x0, glass_y, high), screen(x1, glass_y, high), screen(x1, glass_y, low),
                       screen(x0, glass_y, low)],
            "pool": pool,
        })
    return resolved


# ---------------------------------------------------------------- the floor


VIOLET_RUG = ((0.09, 0.04, 0.14), (0.17, 0.08, 0.26), (0.21, 0.07, 0.25))
NAVY_RUG = ((0.05, 0.06, 0.17), (0.1, 0.12, 0.3), (0.13, 0.06, 0.21))
WINE_RUG = ((0.15, 0.035, 0.04), (0.27, 0.07, 0.06), (0.1, 0.02, 0.05))
RUGS = (
    # x0, x1, y0, y1, (field, pattern, border)
    (590.0, 858.0, 440.0, 722.0, VIOLET_RUG),
    (238.0, 284.0, 336.0, 556.0, NAVY_RUG),
    (100.0, 214.0, 482.0, 562.0, WINE_RUG),
    (116.0, 180.0, 690.0, 930.0, NAVY_RUG),
    (352.0, 418.0, 724.0, 934.0, NAVY_RUG),
    (968.0, 1034.0, 724.0, 934.0, NAVY_RUG),
    (1214.0, 1380.0, 560.0, 756.0, WINE_RUG),
    (1228.0, 1366.0, 322.0, 548.0, NAVY_RUG),
)


def floor_dressing():
    """The rugs, lying on the flags, and the medallion let in among them."""
    kit = RP.Kit("Floor", depth=False)
    gold = (0.48, 0.34, 0.12)
    for index, (x0, x1, y0, y1, (field, pattern, border)) in enumerate(RUGS):
        length, width = y1 - y0, x1 - x0
        kit.box("RugUnder%d" % index, x0 + 0.5, x1 - 0.5, y0 + 2.0, y1 - 2.0, 0.0, RUG_H - 0.1,
                hall._cloth("LibraryRugBacking", (0.04, 0.03, 0.06)), bevel=0.0)
        kit.quad("Rug%d" % index, [(x0, y1, RUG_H), (x1, y1, RUG_H), (x1, y0, RUG_H), (x0, y0, RUG_H)],
                 rug_material("LibraryRug%d" % index, length, width, field, pattern, border, gold),
                 uvs=((length, 0.0), (length, width), (0.0, width), (0.0, 0.0)))
    cx, cy, radius = MOSAIC
    reach = radius * 1.1
    top = FLOOR_TOP[0] + 0.2
    kit.quad("Medallion", [(cx - reach, cy + reach, top), (cx + reach, cy + reach, top),
                           (cx + reach, cy - reach, top), (cx - reach, cy - reach, top)], mosaic_material(radius),
             uvs=((-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)))
    return kit


def free_spans(x0, x1, blocked):
    """What is left of x0..x1 once every (a, b) in `blocked` is taken out."""
    spans = [(x0, x1)]
    for a, b in sorted(blocked):
        left = []
        for s0, s1 in spans:
            if b <= s0 or a >= s1:
                left.append((s0, s1))
                continue
            if a > s0 + 0.5:
                left.append((s0, a))
            if b < s1 - 0.5:
                left.append((b, s1))
        spans = left
    return spans


def lay_courses(x0, x1, y0, y1, rng, breaks=(), obstacles=(), widths=(18.0, 56.0), rows=(15.0, 26.0),
                double=0.12):
    """Flags laying x0..x1 by y0..y1, each (x0, x1, y0, y1), as the painting
    lays them: courses of mixed heights, each of stones of mixed widths, a
    few big flags two courses deep, every joint staggered. A course always
    ends at each of `breaks`; `obstacles` (x0, x1, y0, y1), each between two
    breaks, are left bare. No course is less than 8 px deep."""
    edges = [y0]
    forced = sorted(b for b in breaks if y0 + 0.5 < b < y1 - 0.5)
    y = y0
    while y < y1 - 0.5:
        stop = next((b for b in forced if b > y + 0.5), y1)
        target = y + rng.uniform(*rows)
        if target >= stop - 8.0:
            target = stop
        edges.append(target)
        y = target
    courses = list(zip(edges[:-1], edges[1:]))
    taken = [[] for _course in courses]

    def blocked_in(index):
        top, bottom = courses[index]
        return [(a, b) for a, b, c, d in obstacles if c < bottom - 0.5 and d > top + 0.5] + taken[index]

    laid = []
    for index, (top, bottom) in enumerate(courses):
        for a, b in free_spans(x0, x1, blocked_in(index)):
            x = a
            while x < b - 0.5:
                end = min(x + rng.uniform(*widths), b)
                end = b if b - end < 12.0 else end
                deep = bottom
                if index + 1 < len(courses) and end - x > 26.0 and rng.random() < double and all(
                        end <= c or x >= d for c, d in blocked_in(index + 1)):
                    deep = courses[index + 1][1]
                    taken[index + 1].append((x, end))
                laid.append((x, end, top, deep))
                x = end
    return laid


def flagstone(shape, x0, x1, y0, y1, top, rng):
    """One flag into `shape`: a flat slab with a narrow chamfer, a corner
    now and then chipped, tipped a hair at random so no two catch the light
    alike."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    slope_x, slope_y = rng.uniform(-0.004, 0.004), rng.uniform(-0.004, 0.004)
    cuts = [rng.uniform(0.2, 0.9) if rng.random() > 0.08 else rng.uniform(2.0, 3.6) for _corner in range(4)]

    def ring(inset, drop):
        a0, a1, b0, b1 = x0 + inset, x1 - inset, y0 + inset, y1 - inset
        c = [max(cut - inset * 0.5, 0.15) for cut in cuts]
        outline = ((a0 + c[0], b0), (a1 - c[1], b0), (a1, b0 + c[1]), (a1, b1 - c[2]), (a1 - c[2], b1),
                   (a0 + c[3], b1), (a0, b1 - c[3]), (a0, b0 + c[0]))
        return [shape.verts.new((px, py, top - drop + (px - cx) * slope_x + (py - cy) * slope_y))
                for px, py in outline]

    outer = ring(0.0, 0.35)
    inner = ring(0.5, 0.0)
    bottom = [shape.verts.new((vert.co.x, vert.co.y, 0.0)) for vert in outer]
    shape.faces.new(inner)
    shape.faces.new(list(reversed(bottom)))
    for upper, lower in ((inner, outer), (outer, bottom)):
        for index in range(8):
            following = (index + 1) % 8
            shape.faces.new((lower[index], lower[following], upper[following], upper[index]))


def flagstones():
    """The archive's floor, as the painting lays it: dark flags in courses,
    out to the coping at the south edge, around the optical array's plate,
    the medallion and the cobbles at the stair's foot. Flags the cases, the
    dais or the stair stand on altogether are left out; a few are cracked."""
    kit = RP.Kit("Flagstones", depth=False)
    rng = random.Random(4441)
    cx, cy, radius = MOSAIC
    reach = radius * 1.1
    obstacles = [COBBLES, (612.0, 836.0, 621.0, 692.0), (cx - reach, cx + reach, cy - reach, cy + reach)]
    breaks = [y for _x0, _x1, y0, y1 in obstacles for y in (y0, y1)]
    main_end = 932.0
    laid = lay_courses(WEST_X - 4.0, EAST_X + 4.0, BACK_Y - 4.0, main_end, rng, breaks=breaks, obstacles=obstacles,
                       widths=(24.0, 62.0), rows=(18.0, 32.0), double=0.2)
    for x0, x1, edge in SOUTH_EDGE:
        a, b = max(x0, WEST_X - 4.0), min(x1, EAST_X + 4.0)
        if b > a:
            laid += lay_courses(a, b, main_end, edge - 5.0, rng, widths=(24.0, 62.0), rows=(14.0, 22.0), double=0.0)
    under = [(x0 + 2.0, y0 + 2.0, x1 - 2.0, y1 - 2.0) for x0, y0, x1, y1 in collision_rects().values()]
    under += [(BAY[0], BACK_Y - 10.0, BAY[1], 230.0), (574.0, 228.0, 880.0, DAIS_FRONT - 1.0),
              (STAIR_X[0] - 2.0, DAIS_FRONT - 4.0, STAIR_X[1] + 2.0, STAIR_FRONT)]
    shape = bmesh.new()
    cracks = []
    count = 0
    for x0, x1, y0, y1 in laid:
        if any(x0 >= u0 and x1 <= u1 and y0 >= v0 and y1 <= v1 for u0, v0, u1, v1 in under):
            continue
        top = rng.uniform(*FLOOR_TOP)
        flagstone(shape, x0 + 0.5, x1 - 0.5, y0 + 0.5, y1 - 0.5, top, rng)
        count += 1
        if x1 - x0 > 30.0 and y1 - y0 > 16.0 and rng.random() < 0.08:
            cracks.append((x0 + 4.0, x1 - 4.0, y0 + 3.0, y1 - 3.0, top + 0.35))
    kit.shape("Stones", shape, flagstone_material(), uv="box")
    crack = hall.material_floor_crack(False)
    for index, (x0, x1, y0, y1, h) in enumerate(cracks):
        corners = [(x0, y1, h), (x1, y1, h), (x1, y0, h), (x0, y0, h)]
        if rng.random() < 0.5:
            corners = corners[1:] + corners[:1]
        obj = kit.quad("Crack%d" % index, corners, crack)
        obj["floor_decal"] = True
    print("LIBRARY FLOOR %d flags, %d cracked" % (count, len(cracks)))
    return kit


def clip_half(polygon, point, normal):
    """`polygon` (a list of (x, y)) cut to the side of the line through
    `point` that `normal` points away from."""
    kept = []
    count = len(polygon)
    for index in range(count):
        a, b = polygon[index], polygon[(index + 1) % count]
        da = (a[0] - point[0]) * normal[0] + (a[1] - point[1]) * normal[1]
        db = (b[0] - point[0]) * normal[0] + (b[1] - point[1]) * normal[1]
        if da <= 0.0:
            kept.append(a)
        if (da < 0.0) != (db < 0.0):
            t = da / (da - db)
            kept.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return kept


def cobbles():
    """The worn cobbles at the foot of the dais stair, as the painting lays
    them: irregular stones packed close, brown and grey, each a low dome with
    a thin dark joint round it. The rainbow from the spectrum window falls
    on them."""
    kit = RP.Kit("Cobbles", depth=False)
    rng = random.Random(3307)
    x0, x1, y0, y1 = COBBLES
    seeds = []
    row, y = 0, y0 + 4.0
    while y < y1 + 2.0:
        x = x0 + (5.0 if row % 2 else 0.0)
        while x < x1 + 5.0:
            seeds.append((x + rng.uniform(-3.0, 3.0), y + rng.uniform(-2.6, 2.6)))
            x += rng.uniform(9.0, 12.0)
        y += rng.uniform(8.0, 10.0)
        row += 1
    shape = bmesh.new()
    for index, seed in enumerate(seeds):
        cell = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        for other_index, other in enumerate(seeds):
            if other_index == index or abs(other[0] - seed[0]) > 26.0 or abs(other[1] - seed[1]) > 26.0:
                continue
            middle = ((seed[0] + other[0]) / 2.0, (seed[1] + other[1]) / 2.0)
            cell = clip_half(cell, middle, (other[0] - seed[0], other[1] - seed[1]))
            if len(cell) < 3:
                break
        if len(cell) < 3:
            continue
        cx = sum(point[0] for point in cell) / len(cell)
        cy = sum(point[1] for point in cell) / len(cell)
        reach = sum(math.hypot(point[0] - cx, point[1] - cy) for point in cell) / len(cell)
        if reach < 2.0:
            continue
        rings = []
        for inset, h in ((0.7, 0.3), (1.5, 1.05), (reach * 0.5, rng.uniform(1.45, 1.8))):
            scale = max(1.0 - inset / reach, 0.15)
            rings.append([shape.verts.new((cx + (px - cx) * scale, cy + (py - cy) * scale, h)) for px, py in cell])
        base = [shape.verts.new((vert.co.x, vert.co.y, 0.0)) for vert in rings[0]]
        count = len(cell)
        for lower, upper in ((base, rings[0]), (rings[0], rings[1]), (rings[1], rings[2])):
            for k in range(count):
                shape.faces.new((lower[k], lower[(k + 1) % count], upper[(k + 1) % count], upper[k]))
        shape.faces.new(rings[2])
        shape.faces.new(list(reversed(base)))
    kit.shape("Stones", shape, laid_stone("LibraryCobble", "rock_surface", 0.9, 0.42, (0.46, 0.45, 0.48),
                                          warm=(0.88, 0.62, 0.36), variety=0.34, wear=0.2, ao=0.12, mottle=0.2),
              smooth=True, uv="box")
    return kit


def optical_array():
    """The optical array before the research desk: a walnut plate let into
    the floor, as wide as the game's stand, with three brass lens beds where
    the game seats the recovered filters, and the scanner's hexagonal housing
    on the desk's front. The player walks over the plate, so it stays out of
    the depth map. The game draws the filters, beams and light over it."""
    kit = RP.Kit("OpticalArray", depth=False)
    walnut, metal = oak(), brass()
    back, front, x0, x1 = 621.0, 692.0, 612.0, 836.0
    kit.box("Plate", x0 + 1.5, x1 - 1.5, back + 1.5, front - 1.5, 0.0, CONSOLE_H - 0.6, walnut, bevel=0.4, uv="box")
    for part, (a, b, c, d) in (("N", (x0, x1, back, back + 2.5)), ("S", (x0, x1, front - 2.5, front)),
                               ("W", (x0, x0 + 2.5, back, front)), ("E", (x1 - 2.5, x1, back, front))):
        kit.box("Rim" + part, a, b, c, d, 0.0, CONSOLE_H, metal, bevel=0.4)
    bed = glow("LibraryLensBed" + ("Lit" if AWAKENED else ""), (0.9, 0.9, 1.0), 3.0 if AWAKENED else 0.0,
               (0.02, 0.02, 0.03))
    top = CONSOLE_H - 0.6
    for index, x in enumerate(LENS_X):
        y = CONSOLE_Y
        kit.box("LensBed%d" % index, x - 22.0, x + 22.0, y - 14.0, y + 14.0, top - 0.3, top + 0.2, bed, bevel=0.0)
        for part, (a, b, c, d) in (("N", (x - 27.0, x + 27.0, y - 19.0, y - 14.0)),
                                   ("S", (x - 27.0, x + 27.0, y + 14.0, y + 19.0)),
                                   ("W", (x - 27.0, x - 22.0, y - 14.0, y + 14.0)),
                                   ("E", (x + 22.0, x + 27.0, y - 14.0, y + 14.0))):
            kit.box("LensFrame%d%s" % (index, part), a, b, c, d, top, top + 1.0, metal, bevel=0.3)
        for corner in ((x - 24.5, y - 16.5), (x + 24.5, y - 16.5), (x - 24.5, y + 16.5), (x + 24.5, y + 16.5)):
            kit.ball("LensRivet", corner[0], corner[1], top + 1.2, 0.8, metal)
    # Inlaid brass lines from each bed to the scanner, as the game's beams run.
    for index, x in enumerate(LENS_X):
        start, end = Vector((x, CONSOLE_Y - 19.0)), Vector((SCANNER[0], back + 3.0))
        if (end - start).length > 1.0:
            rail_along(kit, "Inlay%d" % index, tuple(start), tuple(end), 1.2, top - 0.1, top + 0.15, metal, bevel=0.0)
    sx, sy, sh = SCANNER
    hexagon = [(sx + 15.0 * math.cos(math.radians(90.0 + 60.0 * step)),
                sh + 18.0 * math.sin(math.radians(90.0 + 60.0 * step))) for step in range(6)]
    kit.slab("ScannerHousing", hexagon, sy - 1.0, sy + 1.6, metal, bevel=0.4)
    lens = glow("LibraryScannerLens" + ("Lit" if AWAKENED else ""), (0.92, 0.9, 1.0), 6.0 if AWAKENED else 0.25,
                (0.02, 0.025, 0.05))
    inner = [(sx + 9.5 * math.cos(math.radians(90.0 + 60.0 * step)),
              sh + 11.5 * math.sin(math.radians(90.0 + 60.0 * step))) for step in range(6)]
    kit.slab("ScannerLens", inner, sy + 1.4, sy + 2.0, lens)
    return kit


# ---------------------------------------------------------------- small things


def open_book(kit, part, x0, x1, y0, y1, h, cover=(0.2, 0.08, 0.05)):
    """A book lying open, its two pages written in brown ink."""
    kit.box(part + "Cover", x0, x1, y0, y1, h, h + 1.0, wake.leather(part + "Cover", cover), bevel=0.3)
    middle = (x0 + x1) / 2.0
    for side, (a, b) in (("L", (x0 + 1.0, middle - 0.4)), ("R", (middle + 0.4, x1 - 1.0))):
        kit.box(part + "Pages" + side, a, b, y0 + 1.0, y1 - 1.0, h + 1.0, h + 2.6, wake.parchment(), bevel=0.3)
    kit.quad(part + "Text", [(x0 + 1.0, y1 - 1.0, h + 2.65), (x1 - 1.0, y1 - 1.0, h + 2.65),
                             (x1 - 1.0, y0 + 1.0, h + 2.65), (x0 + 1.0, y0 + 1.0, h + 2.65)],
             wake.writing("LibraryBookPages", lines=9.0, gutter=True))


def lantern(kit, part, x, y, h, power=3.0):
    """A small brass lantern: a cage round a glass chimney and its flame."""
    metal = brass()
    kit.lathe(part + "Base", x, y, [(0.0, h), (4.4, h), (4.6, h + 1.4), (3.6, h + 2.2), (0.0, h + 2.2)], metal,
              plan=ROUND)
    for turn in range(4):
        angle = math.radians(45.0 + 90.0 * turn)
        dx, dy = 3.8 * math.cos(angle), 3.8 * ROUND * math.sin(angle)
        kit.rod(part + "Bar", (x + dx, y + dy, h + 2.0), (x + dx, y + dy, h + 13.0), 0.45, metal)
    chimney = kit.lathe(part + "Glass", x, y, [(2.6, h + 2.2), (3.2, h + 5.0), (3.2, h + 10.0), (2.4, h + 12.6)],
                        glass(), plan=ROUND, close=False)
    chimney.visible_shadow = False
    kit.lathe(part + "Cap", x, y, [(0.0, h + 12.6), (4.4, h + 12.6), (2.0, h + 15.6), (0.8, h + 16.4),
                                   (0.0, h + 16.4)], metal, plan=ROUND)
    kit.ring(part + "Hoop", (x, y, h + 18.2), (0.0, 1.0, 0.0), 1.6, 0.4, metal, segments=16, sides=6)
    kit.flame(part, x, y, h + 4.0, size=1.1, power=power * WARMTH, color=(1.0, 0.64, 0.3))
    RP.GLOWS[-1]["kind"] = "lantern"


def candelabrum(kit, part, x, y, h, arms=1, spread=7.0, power=2.6, stem=10.0):
    """A brass candlestick, or with `arms` a branched candelabrum."""
    metal = brass()
    kit.lathe(part + "Foot", x, y, [(0.0, h), (4.8, h), (5.0, h + 1.2), (2.4, h + 2.6), (1.4, h + stem * 0.6),
                                    (1.8, h + stem * 0.7), (1.2, h + stem), (0.0, h + stem)], metal, plan=ROUND)
    if arms <= 1:
        wake.candlestick(kit, part + "Stick", x, y, h + stem, wax_height=10.0, radius=2.3, power=power * WARMTH,
                         stick=4.0)
        return
    top = h + stem
    kit.rod(part + "Arm", (x - spread, y, top + 3.0), (x + spread, y, top + 3.0), 0.7, metal)
    for index, dx in enumerate([-spread, spread] + ([0.0] if arms > 2 else [])):
        cup = top + (6.0 if dx == 0.0 else 3.0)
        if dx == 0.0:
            kit.rod(part + "Stem", (x, y, top), (x, y, cup), 0.8, metal)
        kit.lathe(part + "Cup%d" % index, x + dx, y, [(0.0, cup - 1.0), (2.8, cup - 1.0), (3.2, cup + 0.6),
                                                      (0.0, cup + 0.6)], metal, plan=ROUND)
        kit.candle(part + "Candle%d" % index, x + dx, y, cup + 0.6, height=9.0, radius=1.9, power=power * WARMTH)


def book_row(kit, x0, x1, front, h0, h1, rng, deep=9.0):
    """Small books on an upper shelf: one block each, cloth-bound with gilt
    bands, for the shelves seen far off over the gallery."""
    books = hall._book_material()
    x = x0
    while x < x1 - 2.0:
        width = rng.uniform(2.2, 4.2)
        if x + width > x1:
            break
        tall = (h1 - h0) * rng.uniform(0.7, 0.95)
        set_back = rng.uniform(0.0, 1.6)
        kit.box("UpperBook", x, x + width, front - deep - set_back, front - set_back, h0, h0 + tall, books, bevel=0.2)
        x += width + rng.uniform(0.0, 0.3)


def rail_along(kit, part, a, b, width, h0, h1, material, bevel=0.6):
    """A straight member from `a` to `b` in plan, `width` px thick."""
    a, b = Vector(a), Vector(b)
    normal = Vector((-(b - a).y, (b - a).x)).normalized() * (width / 2.0)
    outline = [tuple(a + normal), tuple(b + normal), tuple(b - normal), tuple(a - normal)]
    return prism(kit, part, outline, h0, h1, material, bevel=bevel)


# ---------------------------------------------------------------- the north wall


def gallery_bookcase(kit, x0, x1, front, rng, extra=None):
    """A bookcase standing under the gallery, the deck resting on its head:
    three rows of books in bays between its posts."""
    wood = oak()
    back, top = BACK_Y, GALLERY_H - 4.0
    kit.box("Plinth", x0, x1, back, front + 2.0, 0.0, 6.0, wood, bevel=0.8, uv="box")
    for part, (a, b) in (("SideW", (x0, x0 + 5.0)), ("SideE", (x1 - 5.0, x1))):
        kit.box(part, a, b, back, front + 1.0, 6.0, top, wood, bevel=0.8, uv="box_up")
    bays = max(1, int(round((x1 - x0 - 10.0) / 58.0)))
    width = (x1 - x0 - 10.0) / bays
    for index in range(1, bays):
        x = x0 + 5.0 + width * index
        kit.box("Post", x - 2.4, x + 2.4, back, front + 1.0, 6.0, top, wood, bevel=0.8, uv="box_up")
    kit.box("Back", x0, x1, back, back + 2.0, 6.0, top, wood, bevel=0.0, uv="box_up")
    kit.box("Head", x0, x1, back, front + 2.0, top - 6.0, top, wood, bevel=0.8, uv="box")
    rows = ((6.0, 36.0), (39.0, 66.0), (69.0, top - 6.0))
    for h0, _h1 in rows[1:]:
        kit.box("Shelf", x0 + 5.0, x1 - 5.0, back + 2.0, front - 1.0, h0 - 3.0, h0, wood, bevel=0.6, uv="box")
        kit.box("ShelfLip", x0 + 5.0, x1 - 5.0, front - 2.5, front, h0 - 3.5, h0 + 0.4, wood, bevel=0.8, uv="box")
    for index in range(bays):
        a = x0 + 5.0 + width * index + (2.6 if index else 0.4)
        b = x0 + 5.0 + width * (index + 1) - (2.6 if index < bays - 1 else 0.4)
        for row, (h0, h1) in enumerate(rows):
            if extra == "reading" and row == 1 and index == bays // 2:
                # A reading slide drawn out under an open book.
                kit.box("Slide", a + 2.0, b - 2.0, front - 12.0, front + 4.0, h0 - 1.6, h0, wood, bevel=0.6, uv="box")
                open_book(kit, "SlideBook", a + 6.0, b - 6.0, front - 10.0, front + 2.0, h0)
                wake.shelf_run(kit, a, b, front - 14.0, h0 + 2.0, h1, rng, lean_end=False)
                continue
            if extra == "jars" and row == 2 and index % 2 == 0:
                sealed_jars(kit, a, b, front - 6.0, h0, rng)
                continue
            wake.shelf_run(kit, a, b, front - 2.0, h0, h1, rng, lean_end=rng.random() < 0.5)


def sealed_jars(kit, x0, x1, y, h, rng):
    """Stoneware jars with waxed linen tied over their mouths."""
    x = x0 + 4.0
    stoneware = hall._painted("LibraryStoneware", (0.3, 0.26, 0.2))
    wax = hall._painted("LibrarySealWax", (0.4, 0.05, 0.04))
    while x < x1 - 7.0:
        radius = rng.uniform(3.4, 5.2)
        tall = rng.uniform(10.0, 17.0)
        cx = x + radius
        kit.lathe("Jar", cx, y, [(0.0, h), (radius * 0.85, h), (radius, h + tall * 0.3), (radius, h + tall * 0.75),
                                 (radius * 0.6, h + tall * 0.92), (radius * 0.62, h + tall), (0.0, h + tall)],
                  stoneware, plan=ROUND)
        kit.lathe("JarCloth", cx, y, [(radius * 0.7, h + tall * 0.86), (radius * 0.78, h + tall + 0.6),
                                      (radius * 0.3, h + tall + 1.6), (0.0, h + tall + 1.8)],
                  wake.linen(), plan=ROUND)
        kit.ball("JarSeal", cx, y + radius * ROUND * 0.7, h + tall * 0.9, 1.2, wax)
        x += radius * 2.0 + rng.uniform(1.0, 3.0)


def galleries():
    """The gallery that walks on the north bookcases, its rail, the shelves
    above it and a library ladder on each wing."""
    kit = RP.Kit("Gallery")
    wood, metal = oak(), brass()
    rng = random.Random(61)
    rail_y = GALLERY_FRONT
    for index, (x0, x1) in enumerate(GALLERIES):
        kit.box("Deck%d" % index, x0, x1, BACK_Y, GALLERY_FRONT + 2.0, GALLERY_H - 4.0, GALLERY_H, wood, bevel=0.8,
                uv="box")
        kit.box("Fascia%d" % index, x0, x1, GALLERY_FRONT + 0.5, GALLERY_FRONT + 3.5, GALLERY_H - 10.0,
                GALLERY_H - 0.5, wood, bevel=0.8, uv="box")
        kit.box("Corbel%d" % index, x0, x1, GALLERY_FRONT - 1.0, GALLERY_FRONT + 2.5, GALLERY_H - 13.0,
                GALLERY_H - 10.0, metal, bevel=0.4)
        count = int((x1 - x0 - 8.0) / 6.5)
        for step in range(count + 1):
            x = x0 + 4.0 + (x1 - x0 - 8.0) * step / count
            kit.lathe("Baluster", x, rail_y, [(0.0, GALLERY_H), (1.5, GALLERY_H), (1.5, GALLERY_H + 1.4),
                                              (0.8, GALLERY_H + 3.2), (1.4, GALLERY_H + 7.0), (0.7, GALLERY_H + 11.0),
                                              (1.0, GALLERY_H + 14.4), (0.0, GALLERY_H + 14.4)],
                      wood, plan=ROUND, segments=10, uv="box_up")
        kit.box("Rail%d" % index, x0, x1, rail_y - 2.2, rail_y + 2.2, GALLERY_H + 14.0, GALLERY_H + 17.5, wood,
                bevel=0.9, uv="box")
        for x in (x0 + 3.0, x1 - 3.0):
            kit.box("Newel", x - 3.2, x + 3.2, rail_y - 3.2, rail_y + 3.2, GALLERY_H, GALLERY_H + 21.0, wood,
                    bevel=0.9, uv="box_up")
            kit.ball("NewelFinial", x, rail_y, GALLERY_H + 23.4, 2.8, metal)
        # The upper shelves stand on the deck against the wall.
        upper_front = BACK_Y + 12.0
        kit.box("UpperBack%d" % index, x0, x1, BACK_Y, BACK_Y + 1.5, GALLERY_H, WALL_H - 6.0, wood, bevel=0.0,
                uv="box_up")
        posts = max(2, int((x1 - x0) / 48.0) + 1)
        for step in range(posts):
            x = x0 + 2.0 + (x1 - x0 - 4.0) * step / (posts - 1)
            kit.box("UpperPost", x - 1.8, x + 1.8, BACK_Y, upper_front + 0.5, GALLERY_H, WALL_H - 6.0, wood,
                    bevel=0.5, uv="box_up")
        for h in (GALLERY_H + 17.0, WALL_H - 9.0):
            kit.box("UpperShelf", x0, x1, BACK_Y, upper_front + 0.5, h - 2.0, h, wood, bevel=0.5, uv="box")
        book_row(kit, x0 + 4.0, x1 - 4.0, upper_front, GALLERY_H, GALLERY_H + 15.0, rng)
        book_row(kit, x0 + 4.0, x1 - 4.0, upper_front, GALLERY_H + 17.0, WALL_H - 11.0, rng)
        # The library ladder, hooked to a brass rail along the bookcases' heads.
        # Its foot stays inside the bookcases' collision (y 198-202), so the
        # player never walks through it: it stands almost upright.
        rail_h, rail_y = GALLERY_H - 15.0, 200.0
        kit.rod("LadderRail%d" % index, (x0 + 4.0, rail_y, rail_h), (x1 - 4.0, rail_y, rail_h), 0.8, metal)
        lx = x0 + 34.0 if index == 0 else x1 - 30.0
        foot_y = 202.0
        for side in (0.0, 13.0):
            kit.rod("LadderSide", (lx + side, foot_y, 0.0), (lx + side, rail_y + 0.5, rail_h + 1.0), 0.9, wood)
        for rung in range(1, 11):
            t = rung / 11.0
            y = foot_y + (rail_y + 0.5 - foot_y) * t
            h = (rail_h + 1.0) * t
            kit.rod("LadderRung", (lx, y, h), (lx + 13.0, y, h), 0.6, wood)
        for side in (0.0, 13.0):
            kit.ring("LadderHook", (lx + side, rail_y, rail_h + 1.0), (1.0, 0.0, 0.0), 1.6, 0.4, metal, segments=12,
                     sides=6)
        for x in (x0 + (x1 - x0) * 0.3, x0 + (x1 - x0) * 0.72):
            lantern(kit, "GalleryLantern", x, GALLERY_FRONT + 4.0, GALLERY_H - 30.0, power=2.4)
            kit.rod("LanternChain", (x, GALLERY_FRONT + 4.0, GALLERY_H - 11.8), (x, GALLERY_FRONT + 4.0,
                                                                                 GALLERY_H - 13.0), 0.3, metal)
            pool(kit, "GalleryLantern", x, GALLERY_FRONT + 26.0, power=1.8)
    # The bookcases under the gallery that the game does not list.
    gallery_bookcase(kit, GALLERIES[0][0], 370.2, 198.0, random.Random(62))
    gallery_bookcase(kit, 1064.6, GALLERIES[1][1], 198.0, random.Random(63))
    return kit


def back_wall_sconce(kit, part, x, h, arms=2, power=3.6):
    """A candle sconce on the north wall: a brass plate, its arms and candles."""
    metal = brass()
    face = BACK_Y + 0.6
    kit.box(part + "Plate", x - 4.0, x + 4.0, face, face + 1.6, h - 9.0, h + 9.0, metal, bevel=0.5)
    kit.rod(part + "Arm", (x, face + 1.0, h - 2.0), (x, face + 10.0, h - 4.0), 0.9, metal)
    spread = 6.5 if arms > 1 else 0.0
    if arms > 1:
        kit.rod(part + "Cross", (x - spread, face + 10.0, h - 4.0), (x + spread, face + 10.0, h - 4.0), 0.8, metal)
    for index, dx in enumerate((-spread, spread) if arms > 1 else (0.0,)):
        cup = h - 3.0
        kit.lathe(part + "Cup%d" % index, x + dx, face + 10.0, [(0.0, cup - 1.6), (2.6, cup - 1.4), (3.4, cup),
                                                                (3.4, cup + 0.8), (0.0, cup + 0.8)], metal, plan=ROUND)
        kit.candle(part + "Candle%d" % index, x + dx, face + 10.0, cup + 0.8, height=11.0, radius=2.0,
                   power=power * WARMTH)


def north_dressing():
    """Sconces between the great windows, the chained chest in the west
    corner (the game's "chained cabinet") and the floor globe in the east."""
    kit = RP.Kit("NorthDressing")
    metal, ironwork = brass(), iron()
    for x in (150.0, 1221.0):
        back_wall_sconce(kit, "Sconce%d" % int(x), x, 96.0)
    # The chained chest: iron-bound, two chains crossed over its lid.
    wood = wake.planks()
    x0, x1, y0, y1 = 238.0, 284.0, 192.0, 229.0
    kit.box("Chest", x0, x1, y0, y1, 0.0, 26.0, wood, bevel=0.9, uv="box")
    kit.box("ChestLid", x0 - 1.0, x1 + 1.0, y0 - 1.0, y1 + 1.0, 24.0, 31.0, wood, bevel=1.3, uv="box")
    for x in (x0 + 5.0, x1 - 5.0):
        kit.box("ChestBand", x - 1.4, x + 1.4, y0 - 1.4, y1 + 1.4, 0.0, 31.4, ironwork, bevel=0.3)
    for y in (y0 + 1.0, y1 - 1.0):
        for x in (x0 + 1.0, x1 - 1.0):
            kit.box("ChestCorner", x - 2.2, x + 2.2, y - 2.2, y + 2.2, 0.0, 31.6, ironwork, bevel=0.3)
    chain(kit, "ChestChainA", (x0 + 2.0, y1 + 1.6, 4.0), (x1 - 2.0, y1 + 1.6, 29.0), ironwork)
    chain(kit, "ChestChainB", (x1 - 2.0, y1 + 1.6, 4.0), (x0 + 2.0, y1 + 1.6, 29.0), ironwork)
    padlock(kit, "ChestLock", (x0 + x1) / 2.0, y1 + 2.6, 15.0)
    # The floor globe on its tripod.
    cx, cy = 1348.0, 214.0
    for turn in range(3):
        angle = math.radians(90.0 + 120.0 * turn)
        kit.rod("GlobeLeg", (cx, cy, 30.0), (cx + 13.0 * math.cos(angle), cy + 9.0 * math.sin(angle), 0.0), 1.0,
                metal)
    kit.lathe("GlobeStem", cx, cy, [(0.0, 28.0), (2.6, 28.0), (2.0, 36.0), (0.0, 36.0)], metal, plan=ROUND)
    kit.ball("Globe", cx, cy, 50.0, 14.0, hall._painted("LibraryGlobeOcean", (0.08, 0.16, 0.22)), plan=ROUND)
    kit.ring("GlobeMeridian", (cx, cy, 50.0), (1.0, 0.0, 0.0), 15.6, 0.7, metal)
    kit.ring("GlobeHorizon", (cx, cy, 50.0), (0.0, 0.0, 1.0), 16.4, 0.8, metal)
    return kit


def chain(kit, part, start, end, material, link=2.4):
    """An iron chain from `start` to `end` (game px), its links turning in turn."""
    a, b = RP.world(*start), RP.world(*end)
    span = (b - a)
    count = max(2, int(span.length / (link * 1.6 * RP.PX)))
    direction = span.normalized()
    side = direction.cross(Vector((0.0, 1.0, 0.0))).normalized()
    for index in range(count + 1):
        point = RP.game(a + span * (index / count))
        axis = side if index % 2 else direction.cross(side).normalized()
        kit.ring(part, tuple(point), tuple(axis), link * 0.6, 0.38, material, segments=12, sides=6)


def padlock(kit, part, x, y, h):
    gold = polished_brass()
    kit.box(part + "Body", x - 4.0, x + 4.0, y - 1.6, y + 1.6, h - 5.0, h + 1.5, gold, bevel=0.8)
    kit.ring(part + "Shackle", (x, y, h + 2.4), (0.0, 1.0, 0.0), 2.6, 0.6, gold, segments=20, sides=6)
    kit.box(part + "Keyhole", x - 0.5, x + 0.5, y + 1.5, y + 1.8, h - 3.0, h - 0.5, hall._bakelite(), bevel=0.0)


# ---------------------------------------------------------------- the reading dais


def glass_prism(kit, part, x0, x1, y, h, side):
    """A triangular glass prism lying along x, a side of `side` px."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.95, 0.97, 1.0), roughness=0.02)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.5
    shape = bmesh.new()
    triangle = [(y - side / 2.0, h), (y + side / 2.0, h), (y, h + side * 0.87)]
    west = [shape.verts.new((x0, py, ph)) for py, ph in triangle]
    east = [shape.verts.new((x1, py, ph)) for py, ph in triangle]
    shape.faces.new(west)
    shape.faces.new(list(reversed(east)))
    for index in range(3):
        following = (index + 1) % 3
        shape.faces.new((west[index], west[following], east[following], east[index]))
    obj = kit.shape(part, shape, hall._material("LibraryPrismGlass", build))
    obj.visible_shadow = False
    return obj


def armchair(kit, part, x, y, h):
    """A wingback chair in plum velvet, facing the room."""
    fabric, wood = chair_velvet(), dark_oak()
    for dx in (-14.0, 14.0):
        for dy in (-9.0, 9.0):
            kit.lathe(part + "Leg", x + dx, y + dy, [(0.0, h), (1.5, h), (1.9, h + 3.0), (1.3, h + 7.0),
                                                     (0.0, h + 7.0)],
                      wood, plan=ROUND, segments=10, uv="box_up")
    kit.box(part + "Seat", x - 17.0, x + 17.0, y - 12.0, y + 12.0, h + 6.0, h + 14.0, fabric, bevel=2.2, uv="box")
    kit.box(part + "Cushion", x - 13.0, x + 13.0, y - 8.0, y + 12.5, h + 13.0, h + 18.0, fabric, bevel=2.4, uv="box")
    kit.box(part + "Back", x - 16.0, x + 16.0, y - 14.0, y - 7.0, h + 13.0, h + 50.0, fabric, bevel=3.0, uv="box")
    for side in (-1.0, 1.0):
        kit.box(part + "Wing", x + side * 12.0 - 3.0, x + side * 12.0 + 3.0, y - 14.0, y - 2.0, h + 26.0, h + 47.0,
                fabric, bevel=2.4, uv="box")
        kit.box(part + "Arm", x + side * 15.0 - 3.5, x + side * 15.0 + 3.5, y - 12.0, y + 12.5, h + 13.0, h + 27.0,
                fabric, bevel=3.0, uv="box")
    for dx in (-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0):
        kit.ball(part + "Stud", x + dx, y + 12.8, h + 10.0, 0.6, brass())


def side_table(kit, part, x, y, h, top=24.0, radius=9.0):
    wood = oak()
    kit.lathe(part + "Foot", x, y, [(0.0, h), (6.0, h), (6.2, h + 1.6), (2.0, h + 3.0), (1.4, h + top * 0.4),
                                    (2.2, h + top * 0.5), (1.4, h + top - 2.0), (0.0, h + top - 2.0)], wood,
              plan=ROUND, uv="box_up")
    kit.lathe(part + "Top", x, y, [(0.0, h + top - 2.0), (radius, h + top - 2.0), (radius + 0.6, h + top - 1.0),
                                   (radius, h + top), (0.0, h + top)], wood, plan=ROUND, uv="box")
    return h + top


def clock(kit, x0, x1, y0, y1, h):
    """A long-case clock at the east end of the dais."""
    wood, metal = dark_oak(), brass()
    kit.box("ClockPlinth", x0 - 1.0, x1 + 1.0, y0 - 1.0, y1 + 1.5, h, h + 9.0, wood, bevel=0.8, uv="box")
    kit.box("ClockTrunk", x0 + 2.0, x1 - 2.0, y0 + 1.0, y1, h + 9.0, h + 64.0, wood, bevel=0.8, uv="box_up")
    kit.box("ClockDoor", x0 + 5.0, x1 - 5.0, y1 - 0.5, y1 + 0.8, h + 18.0, h + 60.0, wood, bevel=0.8, uv="box_up")
    kit.quad("ClockWindow", [(x0 + 8.0, y1 + 0.9, h + 26.0), (x1 - 8.0, y1 + 0.9, h + 26.0),
                             (x1 - 8.0, y1 + 0.9, h + 56.0), (x0 + 8.0, y1 + 0.9, h + 56.0)],
             hall._painted("LibraryClockDark", (0.02, 0.018, 0.02)))
    kit.rod("ClockPendulum", ((x0 + x1) / 2.0, y1 + 1.0, h + 55.0), ((x0 + x1) / 2.0, y1 + 1.0, h + 34.0), 0.4,
            metal)
    kit.ring("ClockBob", ((x0 + x1) / 2.0, y1 + 1.1, h + 31.0), (0.0, 1.0, 0.0), 3.0, 0.9, metal, segments=20,
             sides=6)
    kit.box("ClockHood", x0, x1, y0, y1 + 1.5, h + 64.0, h + 92.0, wood, bevel=1.0, uv="box")
    kit.quad("ClockDial", [(x0 + 4.0, y1 + 1.6, h + 67.0), (x1 - 4.0, y1 + 1.6, h + 67.0),
                           (x1 - 4.0, y1 + 1.6, h + 89.0), (x0 + 4.0, y1 + 1.6, h + 89.0)],
             hall.material_dial("LibraryClockFace", "clock"))
    kit.box("ClockCrest", x0 - 1.0, x1 + 1.0, y0 - 0.5, y1 + 2.5, h + 92.0, h + 96.0, wood, bevel=1.0, uv="box")
    for x in (x0 + 1.0, (x0 + x1) / 2.0, x1 - 1.0):
        kit.ball("ClockFinial", x, y1 + 1.0, h + 99.0, 2.4, metal)


def spiral_stair(kit, cx, cy, radius, low, high):
    """A cast-iron spiral stair from the dais up to the gallery's end, with
    a brass handrail winding round it."""
    ironwork, metal = iron(), brass()
    kit.cylinder("SpiralColumn", cx, cy, low, high + 20.0, 2.8, ironwork, plan=2.8 * ROUND)
    kit.ball("SpiralFinial", cx, cy, high + 22.0, 3.4, metal)
    treads = 16
    rise = (high - low) / treads
    rail_points = []
    for step in range(treads):
        middle = 180.0 - (treads - 1 - step) * 22.5
        h = low + rise * (step + 1)
        arc = [math.radians(middle - 11.5 + 23.0 * k / 6.0) for k in range(7)]
        outline = [(cx + 2.6 * math.cos(arc[0]), cy + 2.6 * ROUND * math.sin(arc[0]))]
        outline += [(cx + radius * math.cos(a), cy + radius * ROUND * math.sin(a)) for a in arc]
        outline.append((cx + 2.6 * math.cos(arc[-1]), cy + 2.6 * ROUND * math.sin(arc[-1])))
        prism(kit, "Tread%d" % step, outline, h - 1.8, h, ironwork, uv=None, bevel=0.3)
        outer = (cx + (radius - 1.5) * math.cos(math.radians(middle)),
                 cy + (radius - 1.5) * ROUND * math.sin(math.radians(middle)))
        kit.rod("SpiralPost%d" % step, (outer[0], outer[1], h), (outer[0], outer[1], h + 17.0), 0.45, ironwork)
        rail_points.append((outer[0], outer[1], h + 17.0))
    for index in range(len(rail_points) - 1):
        kit.rod("SpiralRail%d" % index, rail_points[index], rail_points[index + 1], 0.8, metal)


def bay():
    """The reading dais behind its balustrade: the spiral stair up to the
    gallery, two wingback chairs, a clock, a glass prism before the spectrum
    window and the candles either side of it."""
    kit = RP.Kit("Bay")
    stone, rock = dais_stone(), carved_stone()
    west, east = BAY
    outline = [(west, BACK_Y), (east, BACK_Y), (east, 230.0), (880.0, DAIS_FRONT), (574.0, DAIS_FRONT),
               (west, 230.0)]
    prism(kit, "Dais", outline, 0.0, DAIS_H, stone)
    sx0, sx1 = STAIR_X
    kit.box("StepUpper", sx0, sx1, DAIS_FRONT - 2.0, DAIS_FRONT + 8.0, 0.0, DAIS_H * 2.0 / 3.0, stone, bevel=0.7,
            uv="box")
    kit.box("StepLower", sx0 - 2.0, sx1 + 2.0, DAIS_FRONT - 2.0, STAIR_FRONT, 0.0, DAIS_H / 3.0, stone, bevel=0.7,
            uv="box")
    edge = DAIS_FRONT - 3.5
    runs = (((west + 3.0, 230.0), (576.0, edge)), ((576.0, edge), (sx0 - 6.0, edge)),
            ((sx1 + 6.0, edge), (878.0, edge)), ((878.0, edge), (east - 3.0, 230.0)))
    for index, (a, b) in enumerate(runs):
        rail_along(kit, "BalustradeBase%d" % index, a, b, 7.0, DAIS_H, DAIS_H + 3.0, rock)
        rail_along(kit, "BalustradeRail%d" % index, a, b, 7.6, DAIS_H + 17.0, DAIS_H + 21.0, rock)
        length = (Vector(b) - Vector(a)).length
        count = max(2, int(length / 8.0))
        for step in range(1, count):
            point = Vector(a).lerp(Vector(b), step / count)
            kit.lathe("Baluster", point.x, point.y, [(0.0, DAIS_H + 3.0), (2.1, DAIS_H + 3.0), (1.2, DAIS_H + 5.0),
                                                     (2.4, DAIS_H + 9.5), (1.1, DAIS_H + 14.0), (1.7, DAIS_H + 17.0),
                                                     (0.0, DAIS_H + 17.0)], rock, plan=ROUND, segments=12)
    newels = [(west + 3.0, 230.0, 26.0, DAIS_H), (576.0, edge, 26.0, DAIS_H), (878.0, edge, 26.0, DAIS_H),
              (east - 3.0, 230.0, 26.0, DAIS_H), (sx0 - 6.0, DAIS_FRONT + 1.5, 40.0, 0.0),
              (sx1 + 6.0, DAIS_FRONT + 1.5, 40.0, 0.0)]
    for index, (x, y, tall, foot) in enumerate(newels):
        kit.box("Newel%d" % index, x - 5.0, x + 5.0, y - 5.0, y + 5.0, foot, foot + tall - 3.0, rock, bevel=0.8,
                uv="box_up")
        kit.box("NewelCap%d" % index, x - 6.5, x + 6.5, y - 6.5, y + 6.5, foot + tall - 3.0, foot + tall, rock,
                bevel=0.9, uv="box")
        if foot == 0.0:
            candelabrum(kit, "StairLight%d" % index, x, y, tall, arms=3, spread=5.0, power=3.4, stem=7.0)
        else:
            kit.ball("NewelBall%d" % index, x, y, foot + tall + 3.2, 3.2, rock)
    spiral_stair(kit, 579.0, 202.0, 24.0, DAIS_H, GALLERY_H)
    kit.box("StairLanding", BAY[0] - 1.0, 562.0, BACK_Y, GALLERY_FRONT + 1.0, GALLERY_H - 4.0, GALLERY_H, oak(),
            bevel=0.8, uv="box")
    armchair(kit, "ChairW", 632.0, 190.0, DAIS_H)
    armchair(kit, "ChairE", 822.0, 190.0, DAIS_H)
    top = side_table(kit, "TableW", 663.0, 203.0, DAIS_H)
    candelabrum(kit, "TableCandle", 663.0, 201.0, top, power=2.6, stem=4.0)
    wake.closed_book(kit, "TableBook", 656.0, 670.0, 205.0, 212.0, top, 3.0, (0.2, 0.06, 0.06))
    top = side_table(kit, "TableE", 791.0, 203.0, DAIS_H)
    lamp_oil(kit, "TableLamp", 791.0, 201.0, top)
    # The prism on its brass stand before the spectrum window.
    metal = brass()
    kit.lathe("PrismStand", 727.0, 180.0, [(0.0, DAIS_H), (6.5, DAIS_H), (6.8, DAIS_H + 1.6), (2.0, DAIS_H + 3.2),
                                           (1.2, DAIS_H + 22.0), (2.6, DAIS_H + 24.0), (0.0, DAIS_H + 24.0)], metal,
              plan=ROUND)
    kit.box("PrismCradle", 715.0, 739.0, 177.0, 183.0, DAIS_H + 23.0, DAIS_H + 25.0, metal, bevel=0.4)
    glass_prism(kit, "Prism", 716.0, 738.0, 180.0, DAIS_H + 25.0, 9.0)
    clock(kit, 860.0, 890.0, 172.0, 194.0, DAIS_H)
    for x in (648.0, 806.0):
        back_wall_sconce(kit, "BaySconce%d" % int(x), x, 92.0)
    wake.closed_book(kit, "DaisStack0", 600.0, 622.0, 214.0, 230.0, DAIS_H, 4.0, (0.06, 0.12, 0.1))
    wake.closed_book(kit, "DaisStack1", 602.0, 620.0, 216.0, 229.0, DAIS_H + 4.0, 3.5, (0.3, 0.2, 0.08))
    return kit


def lamp_oil(kit, part, x, y, h, power=3.6):
    """A table oil lamp: a brass font, a glass chimney and its flame."""
    metal = brass()
    kit.lathe(part + "Foot", x, y, [(0.0, h), (5.0, h), (5.2, h + 1.2), (2.2, h + 2.6), (1.8, h + 4.0), (4.8, h + 6.4),
                                    (5.0, h + 8.8), (3.0, h + 11.0), (2.2, h + 12.0),
                                    (0.0, h + 12.0)], metal, plan=ROUND)
    chimney = kit.lathe(part + "Chimney", x, y, [(2.6, h + 12.0), (3.9, h + 15.0), (4.2, h + 18.0), (2.4, h + 22.0),
                                                 (2.1, h + 27.0)], glass(), plan=ROUND, close=False)
    chimney.visible_shadow = False
    kit.flame(part, x, y, h + 13.0, size=1.2, power=power * WARMTH, color=(1.0, 0.64, 0.3))
    RP.GLOWS[-1]["kind"] = "lantern"


# ---------------------------------------------------------------- furniture parts


def piece(name):
    """A kit for one of the game's Worldsort pieces, rendered alone as well
    for its prompt box (except in the awakened run, which renders no props)."""
    return RP.Kit(name, prop=None if AWAKENED else name)


def carcass(kit, x0, x1, front, depth, height, wood, plinth=6.0, side=5.0, crown=True):
    """A case's plinth, sides, back, top and crown, edged in brass as the
    painted cases are; returns its back's plan y."""
    back = front - depth
    metal = brass()
    kit.box("Plinth", x0 + 0.5, x1 - 0.5, back + 0.5, front + 1.0, 0.0, plinth, wood, bevel=0.8, uv="box")
    kit.box("PlinthMould", x0 - 0.5, x1 + 0.5, back, front + 2.0, plinth - 1.5, plinth + 1.0, wood, bevel=1.0, uv="box")
    for part, (a, b) in (("SideW", (x0, x0 + side)), ("SideE", (x1 - side, x1))):
        kit.box(part, a, b, back, front + 1.0, plinth + 1.0, height - 4.0, wood, bevel=0.9, uv="box_up")
    for x in (x0 - 0.2, x1 - 0.8):
        kit.box("EdgeTrim", x, x + 1.0, front + 0.9, front + 1.7, plinth + 1.0, height - 4.0, metal, bevel=0.2)
    kit.box("Back", x0 + side, x1 - side, back, back + 2.0, plinth + 1.0, height - 4.0, wood, bevel=0.0, uv="box_up")
    kit.box("Top", x0 - 0.5, x1 + 0.5, back - 0.5, front + 2.0, height - 4.0, height - 1.5, wood, bevel=0.8, uv="box")
    if crown:
        kit.box("Crown", x0 - 1.5, x1 + 1.5, back - 1.0, front + 3.0, height - 1.5, height, wood, bevel=1.0, uv="box")
        kit.box("CrownTrim", x0 - 1.5, x1 + 1.5, front + 2.7, front + 3.4, height - 1.3, height - 0.3, metal,
                bevel=0.2)
        kit.box("TopPanel", x0 + 6.0, x1 - 6.0, back + 5.0, front - 3.0, height, height + 0.7, wood, bevel=1.4,
                uv="box")
    return back


def pool(kit, part, x, y, power=2.4):
    """The soft pool a lantern or candle above throws on the floor before its
    case, as the Hall lights its corridors: a low warm light no reflection
    shows."""
    kit.light(part + "Pool", x, y, 30.0, (1.0, 0.66, 0.36), power * WARMTH, radius=0.2, mirrored=False)


def dress_top(kit, name, x0, x1, back, front, h, rng, light=None):
    """What lies on a case's broad top, which this camera shows whole: books
    lying in stacks, tied scrolls and archive boxes, and where `light` says, a
    candle or a lantern ("candle", "lantern") lighting the floor round it."""
    depth = front - back
    limit = x1 - (24.0 if light else 4.0)
    x = x0 + rng.uniform(4.0, 9.0)
    while x < limit - 10.0:
        kind = rng.choice(("stack", "stack", "scroll", "box", "gap"))
        room = limit - x
        if kind == "stack" and room >= 12.0:
            w = min(rng.uniform(15.0, 22.0), room)
            d = min(rng.uniform(11.0, 16.0), depth - 6.0)
            y0 = back + rng.uniform(3.0, max(3.5, depth - d - 3.0))
            top = h
            for _layer in range(rng.randint(1, 3)):
                thick = rng.uniform(3.0, 5.0)
                inset = rng.uniform(0.0, 1.6)
                wake.closed_book(kit, name + "TopBook", x + inset, x + w - inset, y0 + inset * 0.6,
                                 y0 + d - inset * 0.6, top, thick, rng.choice(wake.BOOK_COLOURS))
                top += thick
            x += w + rng.uniform(3.0, 9.0)
        elif kind == "scroll" and room >= 12.0:
            length = min(rng.uniform(16.0, 24.0), room)
            y = back + rng.uniform(4.0, max(4.5, depth - 4.0))
            kit.rod(name + "TopScroll", (x, y, h + 2.3), (x + length, y + rng.uniform(-2.0, 2.0), h + 2.3), 2.3,
                    wake.parchment())
            x += length + rng.uniform(4.0, 9.0)
        elif kind == "box" and room >= 9.0:
            w = min(rng.uniform(10.0, 14.0), room)
            y0 = back + rng.uniform(3.0, max(3.5, depth - 12.0))
            kit.box(name + "TopBox", x, x + w, y0, y0 + 9.0, h, h + 7.0,
                    wake.leather("LibraryArchiveBox", (0.17, 0.11, 0.08)), bevel=0.6)
            x += w + rng.uniform(3.0, 9.0)
        else:
            x += rng.uniform(10.0, 20.0)
    if light == "candle":
        candelabrum(kit, name + "TopCandle", x1 - 11.0, back + depth * 0.45, h, power=4.2, stem=4.0)
        pool(kit, name, x1 - 11.0, front + 24.0)
    elif light == "lantern":
        lantern(kit, name + "TopLantern", x1 - 11.0, back + depth * 0.5, h, power=4.0)
        pool(kit, name, x1 - 11.0, front + 24.0)


def shelf(kit, x0, x1, back, front, h, wood):
    kit.box("Shelf", x0, x1, back + 2.0, front - 1.0, h - 3.0, h, wood, bevel=0.6, uv="box")
    kit.box("ShelfLip", x0, x1, front - 2.5, front, h - 3.5, h + 0.4, wood, bevel=0.8, uv="box")


def sorted_run(kit, x0, x1, front, h0, h1, rng):
    """Books sorted by size, bound alike: the reinforced archive's order."""
    x = x0
    tall = (h1 - h0) * 0.86
    while x < x1 - 4.2:
        width = rng.uniform(3.6, 4.4)
        wake.shelf_book(kit, x, width, front - 1.0, h0, tall * rng.uniform(0.97, 1.0), 17.0, rng)
        x += width + 0.1


def disc_outline(x, h, radius, steps=32, squash=None):
    """A disc's outline about (x, h): round on the wall it stands on, so `squash`
    of its radius tall on screen (SIN, as a ring round in 3D shows, by
    default); on the floor pass 1 / STRETCH."""
    squash = RP.SIN if squash is None else squash
    return [(x + radius * math.cos(2.0 * math.pi * step / steps),
             h + radius * squash * math.sin(2.0 * math.pi * step / steps)) for step in range(steps)]


def emblem(kit, part, kind, x, face, h, r, material=None):
    """A brass mark on a case's front (facing the camera at plan y `face`),
    centred (x, h), `r` px across its ring: ring, compass, hourglass, wheel,
    crossed, moon, additive, scratched, handles or clasp. Like its rim, every
    mark is round on the wall, so SIN as tall as wide on screen."""
    metal = material or emblem_brass()
    enamel = hall._painted("LibraryEnamel", (0.025, 0.022, 0.04))
    s = RP.SIN
    if kind in ("ring", "compass", "hourglass", "wheel", "crossed", "moon", "additive"):
        kit.slab(part + "Plate", disc_outline(x, h, r * 0.96), face - 0.3, face + 0.5, enamel)
        kit.ring(part + "Rim", (x, face + 0.6, h), (0.0, 1.0, 0.0), r, r * 0.11, metal, segments=36, sides=8)
    if kind == "ring":
        kit.ring(part + "Inner", (x, face + 0.7, h), (0.0, 1.0, 0.0), r * 0.52, r * 0.08, metal, segments=28, sides=6)
        kit.slab(part + "Boss", disc_outline(x, h, r * 0.18, 16), face + 0.4, face + 1.0, metal)
    elif kind == "compass":
        star = []
        for step in range(16):
            reach = (0.86 if step % 4 == 0 else (0.5 if step % 2 == 0 else 0.2)) * r
            angle = math.radians(90.0 + step * 22.5)
            star.append((x + reach * math.cos(angle), h + reach * s * math.sin(angle)))
        kit.slab(part + "Star", star, face + 0.4, face + 1.0, metal)
    elif kind == "hourglass":
        kit.slab(part + "Glass", [(x - r * 0.42, h + r * 0.56 * s), (x + r * 0.42, h + r * 0.56 * s), (x + r * 0.07, h),
                                  (x + r * 0.42, h - r * 0.56 * s), (x - r * 0.42, h - r * 0.56 * s),
                                  (x - r * 0.07, h)],
                 face + 0.4, face + 1.0, metal)
        for dh in (r * 0.64 * s, -r * 0.64 * s):
            kit.box(part + "Bar", x - r * 0.52, x + r * 0.52, face + 0.3, face + 1.2, h + dh - r * 0.05,
                    h + dh + r * 0.05, metal, bevel=0.2)
    elif kind == "wheel":
        for step in range(6):
            angle = math.radians(step * 60.0)
            kit.rod(part + "Spoke", (x, face + 0.9, h), (x + r * 0.88 * math.cos(angle), face + 0.9,
                                                          h + r * 0.88 * s * math.sin(angle)), r * 0.06, metal)
        kit.ball(part + "Hub", x, face + 1.0, h, r * 0.18, metal, plan=0.5, squash=s)
        for step in range(8):
            angle = math.radians(22.5 + step * 45.0)
            sx, sh = x + r * 1.22 * math.cos(angle), h + r * 1.22 * s * math.sin(angle)
            shape = ([(sx - r * 0.1, sh - r * 0.07), (sx + r * 0.1, sh - r * 0.07), (sx, sh + r * 0.09)] if step % 2
                     else disc_outline(sx, sh, r * 0.1, 10))
            kit.slab(part + "Symbol", shape, face + 0.2, face + 0.9, metal)
    elif kind == "crossed":
        for sign in (-1.0, 1.0):
            kit.rod(part + "Cross", (x - r * 0.62, face + 0.9, h - sign * r * 0.62 * s),
                    (x + r * 0.62, face + 0.9, h + sign * r * 0.62 * s), r * 0.08, metal)
    elif kind == "moon":
        outer = [(x + r * 0.7 * math.cos(math.radians(a)), h + r * 0.7 * s * math.sin(math.radians(a)))
                 for a in range(60, 301, 15)]
        inner = [(x + r * 0.3 + r * 0.5 * math.cos(math.radians(a)), h + r * 0.5 * s * math.sin(math.radians(a)))
                 for a in range(240, 119, -15)]
        kit.slab(part + "Crescent", outer + inner, face + 0.4, face + 1.0, metal)
    elif kind == "additive":
        for step, colour in enumerate((STATION["red"], STATION["green"], STATION["blue"])):
            angle = math.radians(90.0 + 120.0 * step)
            cx, ch = x + r * 0.3 * math.cos(angle), h + r * 0.3 * s * math.sin(angle)
            kit.ring(part + "Circle%d" % step, (cx, face + 0.8, ch), (0.0, 1.0, 0.0), r * 0.42, r * 0.06, metal,
                     segments=28, sides=6)
            kit.slab(part + "Lens%d" % step, disc_outline(cx, ch, r * 0.36, 20), face + 0.5 + step * 0.05,
                     face + 0.6 + step * 0.05, glow("LibraryAdditiveLens%d" % step + ("Lit" if AWAKENED else ""),
                                                    colour, 2.5 if AWAKENED else 0.35))
    elif kind == "scratched":
        kit.slab(part + "Plate", disc_outline(x, h, r * 0.9), face - 0.3, face + 0.6,
                 hall._prop_metal("LibraryDullBrass", (0.42, 0.32, 0.16), 0.55))
        scratch = hall._painted("LibraryScratch", (0.06, 0.05, 0.04))
        rng = random.Random(int(x * 7 + h))
        for _step in range(7):
            angle = rng.uniform(0.0, math.pi)
            length = rng.uniform(0.3, 0.8) * r
            cx, ch = x + rng.uniform(-0.4, 0.4) * r, h + rng.uniform(-0.4, 0.4) * r * s
            dx, dh = math.cos(angle) * length / 2.0, math.sin(angle) * length / 2.0 * s
            kit.rod(part + "Scratch", (cx - dx, face + 0.7, ch - dh), (cx + dx, face + 0.7, ch + dh), 0.18, scratch)
        glyph = [(x - r * 0.3, h - r * 0.35 * s), (x, h + r * 0.4 * s), (x + r * 0.3, h - r * 0.35 * s),
                 (x - r * 0.38, h + r * 0.08 * s), (x + r * 0.38, h + r * 0.08 * s)]
        for index in range(len(glyph) - 1):
            kit.rod(part + "Glyph", (glyph[index][0], face + 0.8, glyph[index][1]),
                    (glyph[index + 1][0], face + 0.8, glyph[index + 1][1]), 0.32, scratch)
    elif kind == "handles":
        for dx in (-r * 0.62, r * 0.62):
            kit.slab(part + "Rose", disc_outline(x + dx, h + r * 0.2 * s, r * 0.22, 16), face - 0.2, face + 0.6, metal)
            kit.ring(part + "Pull", (x + dx, face + 1.0, h - r * 0.18 * s), (0.0, 1.0, 0.0), r * 0.36, r * 0.07, metal,
                     segments=24, sides=6)
    elif kind == "clasp":
        kit.box(part + "Hasp", x - r * 0.3, x + r * 0.3, face - 0.2, face + 1.0, h - r * 0.2 * s, h + r * 0.9 * s,
                iron(),
                bevel=0.4)
        kit.box(part + "Staple", x - r * 0.75, x + r * 0.75, face - 0.2, face + 1.2, h - r * 0.55 * s, h - r * 0.2 * s,
                iron(), bevel=0.4)
        padlock(kit, part + "Lock", x, face + 1.6, h - r * 0.45 * s)


def archive_tower(kit, x0, x1, front, depth, height, upper, lower, lid="ring", wood=None):
    """A tall lidded archive case as the painting draws them: a long lid with a
    brass medallion, brass corner caps and straps, and a front of two raised
    panels, each with its brass mark."""
    wood = wood or dark_oak()
    metal = brass()
    back = front - depth
    kit.box("Foot", x0 + 1.0, x1 - 1.0, back + 1.0, front + 0.6, 0.0, 5.0, wood, bevel=0.8, uv="box")
    kit.box("Body", x0 + 2.0, x1 - 2.0, back + 2.0, front - 1.0, 5.0, height - 9.0, wood, bevel=0.9, uv="box_up")
    kit.box("Lid", x0, x1, back, front + 1.2, height - 9.0, height - 4.0, wood, bevel=1.3, uv="box")
    kit.box("LidTrim", x0 - 0.3, x1 + 0.3, front + 1.1, front + 1.9, height - 8.4, height - 4.6, metal, bevel=0.2)
    kit.box("LidPanel", x0 + 6.0, x1 - 6.0, back + 6.0, front - 5.0, height - 4.0, height - 2.2, wood, bevel=1.4,
            uv="box")
    for x in (x0 + 2.4, x1 - 2.4):
        for y in (back + 2.4, front - 1.2):
            kit.box("LidCorner", x - 3.0, x + 3.0, y - 3.0, y + 3.0, height - 9.4, height - 3.4, metal, bevel=0.6)
    cx, cy = (x0 + x1) / 2.0, (back + front) / 2.0
    radius = min(x1 - x0, depth) * 0.22
    kit.ring("LidMedallion", (cx, cy, height - 1.4), (0.0, 0.0, 1.0), radius, 0.9, emblem_brass(), segments=36,
             sides=8)
    if lid == "ring":
        kit.ring("LidMedallionInner", (cx, cy, height - 1.5), (0.0, 0.0, 1.0), radius * 0.5, 0.6, emblem_brass(),
                 segments=28, sides=6)
    else:
        kit.lathe("LidBoss", cx, cy, [(0.0, height - 2.2), (radius * 0.35, height - 2.2), (0.0, height - 0.6)],
                  emblem_brass(), plan=ROUND)
    face = front - 1.0
    mid = height * 0.5
    for a, b in ((x0 + 2.0, x0 + 7.0), (x1 - 7.0, x1 - 2.0)):
        kit.box("Stile", a, b, face, face + 1.2, 5.0, height - 9.0, wood, bevel=0.6, uv="box_up")
    for low, high in ((5.0, 11.0), (mid - 2.5, mid + 2.5), (height - 15.0, height - 9.0)):
        kit.box("Rail", x0 + 7.0, x1 - 7.0, face, face + 1.2, low, high, wood, bevel=0.6, uv="box")
    for low, high in ((13.5, mid - 4.5), (mid + 4.5, height - 17.5)):
        kit.box("Panel", x0 + 9.5, x1 - 9.5, face + 0.2, face + 1.6, low, high, wood, bevel=1.6, uv="box_up")
    for x in (x0 + 1.0, x1 - 3.0):
        kit.box("Strap", x, x + 2.0, face - 1.0, face + 1.9, 5.0, height - 9.0, metal, bevel=0.4)
    r = min((x1 - x0) * 0.24, 13.0)
    emblem(kit, "Upper", upper, cx, face + 1.6, (mid + 4.5 + height - 17.5) / 2.0, r)
    emblem(kit, "Lower", lower, cx, face + 1.6, (13.5 + mid - 4.5) / 2.0, r * 0.82)
    # A lantern left on the lid's back corner, and a book or two at its front.
    rng = random.Random(int(x0 * 13 + front))
    lantern(kit, "LidLantern", x1 - 11.0, back + 12.0, height - 2.2, power=4.0)
    pool(kit, "Lid", x1 - 11.0, front + 22.0)
    top = height - 2.2
    for _layer in range(rng.randint(1, 2)):
        thick = rng.uniform(3.5, 5.0)
        wake.closed_book(kit, "LidBook", x0 + 7.0, x0 + 27.0, front - 22.0, front - 9.0, top, thick,
                         rng.choice(wake.BOOK_COLOURS))
        top += thick
    return back


def desk_chair(kit, part, x, y):
    """A ladder-back chair behind a desk, facing the room."""
    wood = oak()
    for dx in (-9.0, 9.0):
        for dy in (-7.0, 7.0):
            kit.box(part + "Leg", x + dx - 1.2, x + dx + 1.2, y + dy - 1.2, y + dy + 1.2, 0.0, 22.0 if dy > 0 else 48.0,
                    wood, bevel=0.4, uv="box_up")
    kit.box(part + "Seat", x - 11.0, x + 11.0, y - 9.0, y + 9.0, 20.0, 23.0, wood, bevel=0.8, uv="box")
    kit.box(part + "SeatPad", x - 9.5, x + 9.5, y - 7.5, y + 8.0, 23.0, 25.0, velvet(), bevel=1.0, uv="box")
    for h in (32.0, 39.0, 46.0):
        kit.box(part + "Slat", x - 9.0, x + 9.0, y - 8.0, y - 6.0, h - 1.5, h + 1.5, wood, bevel=0.5, uv="box")


def station_lamp(kit, part, name, x, y, h):
    """A banker's lamp whose glass shade is in its station's colour: the
    preview lights it as the station's challenge is primed and solved."""
    colour = STATION[name]
    metal = brass()
    kit.lathe(part + "Foot", x, y, [(0.0, h), (6.2, h), (6.4, h + 1.4), (2.2, h + 2.8), (1.4, h + 3.6), (0.0, h + 3.6)],
              metal, plan=ROUND)
    kit.rod(part + "Stem", (x, y, h + 3.2), (x, y, h + 15.0), 0.9, metal)
    kit.rod(part + "Arm", (x, y, h + 15.0), (x, y + 3.0, h + 16.6), 0.7, metal)
    shade = glow("LibraryShade" + name.title() + ("Lit" if AWAKENED else ""), colour, 2.6 if AWAKENED else 1.2,
                 tuple(channel * 0.35 for channel in colour))
    kit.rod(part + "Shade", (x - 9.0, y + 3.0, h + 19.0), (x + 9.0, y + 3.0, h + 19.0), 4.2, shade)
    for dx in (-9.4, 9.4):
        kit.ring(part + "Cap", (x + dx, y + 3.0, h + 19.0), (1.0, 0.0, 0.0), 3.8, 0.5, metal, segments=20, sides=6)
    kit.light(part + "Light", x, y + 6.0, h + 14.0, (1.0, 0.86, 0.6), 3.0 * WARMTH, radius=0.03)
    LAMPS[name] = screen(x, y + 3.0, h + 19.0)


def desk_top_paper(kit, part, x, y, h, angle, width=22.0, depth=15.0, lines=8.0):
    wake.paper(kit, part, x, y, h, width, depth, angle, wake.writing("LibraryLetter%d" % int(lines), lines=lines))


# ---------------------------------------------------------------- the game's pieces


def case_glass():
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.9, 0.94, 0.96), roughness=0.04)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.2
    return hall._material("LibraryCaseGlass", build)


def knowledge_volume(kit, part, x, front, h, tall, colour):
    """The one filed volume a knowledge case still holds, a lit tag in its top."""
    rng = random.Random(int(x))
    made = wake.shelf_book(kit, x, 5.2, front, h, tall, 18.0, rng)
    for obj in made[:1]:
        obj.data.materials[0] = wake.book_leather(colour)
    kit.box(part + "Tag", x + 1.6, x + 3.6, front - 1.2, front + 0.4, h + tall - 2.0, h + tall + 7.0, knowledge_glow(),
            bevel=0.1)


def gallery_case(name, rng_seed, extra):
    def build(kit, x0, y0, x1, y1):
        gallery_bookcase(kit, x0, x1, y1, random.Random(rng_seed), extra=extra)
    return build


def reinforced_bookcase(kit, x0, y0, x1, y1):
    """TopLeftCabinetC: deep shelves held by iron brackets and brass studs,
    the books sorted by size."""
    wood, ironwork, metal = oak(), iron(), brass()
    front, height = y1, 115.0
    back = carcass(kit, x0, x1, front, 48.0, height, wood)
    rng = random.Random(73)
    rows = ((7.0, 40.0), (43.0, 76.0), (79.0, height - 5.0))
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, x1 - 5.0, back, front, h0, wood)
        for x in (x0 + 30.0, (x0 + x1) / 2.0, x1 - 30.0):
            kit.box("Label", x - 4.0, x + 4.0, front - 0.1, front + 0.5, h0 - 3.0, h0 - 0.4, metal, bevel=0.1)
    for h0, h1 in rows:
        sorted_run(kit, x0 + 5.5, x1 - 5.5, front - 2.0, h0, h1, rng)
    for x in (x0 - 0.6, x1 - 5.4):
        for h in (7.0, height - 13.0):
            kit.box("Bracket", x, x + 6.0, front + 0.6, front + 1.8, h, h + 6.0, ironwork, bevel=0.3)
    for h in range(14, int(height) - 8, 12):
        for x in (x0 + 2.5, x1 - 2.5):
            kit.ball("Stud", x, front + 1.6, float(h), 0.9, metal)
    dress_top(kit, "Reinforced", x0, x1, back, front, height + 0.7, random.Random(83), light="candle")


def emblem_cabinet(kit, x0, y0, x1, y1):
    """TopLeftCabinetD: ebonised, shelves of books beside a door bearing a
    circular crossed emblem, the drawer's handle polished by use."""
    wood = dark_oak()
    front, height = y1, 118.0
    back = carcass(kit, x0, x1, front, min(44.0, y1 - y0), height, wood)
    split = x0 + (x1 - x0) * 0.64
    kit.box("Divider", split - 2.5, split + 2.5, back, front + 1.0, 7.0, height - 4.0, wood, bevel=0.8, uv="box_up")
    rng = random.Random(74)
    rows = ((7.0, 40.0), (43.0, 76.0), (79.0, height - 5.0))
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, split - 2.5, back, front, h0, wood)
    for h0, h1 in rows:
        wake.shelf_run(kit, x0 + 5.5, split - 3.0, front - 2.0, h0, h1, rng)
    middle = (split + x1) / 2.0
    kit.box("Door", split + 3.0, x1 - 5.0, front - 0.5, front + 1.2, 34.0, height - 7.0, wood, bevel=1.2, uv="box_up")
    kit.box("DoorPanel", split + 7.0, x1 - 9.0, front + 1.0, front + 2.0, 39.0, height - 12.0, wood, bevel=1.4,
            uv="box_up")
    emblem(kit, "Crossed", "crossed", middle, front + 2.0, 34.0 + (height - 41.0) / 2.0, 12.0)
    kit.box("Drawer", split + 3.0, x1 - 5.0, front - 0.5, front + 1.2, 8.0, 31.0, wood, bevel=1.0, uv="box")
    for dx in (-8.0, 8.0):
        kit.box("HandlePlate", middle + dx - 1.6, middle + dx + 1.6, front + 1.1, front + 1.6, 17.0, 22.0, brass(),
                bevel=0.2)
    kit.rod("Handle", (middle - 8.0, front + 3.0, 19.5), (middle + 8.0, front + 3.0, 19.5), 0.95, polished_brass())
    dress_top(kit, "Emblem", x0, x1, back, front, height + 0.7, random.Random(84))


def divided_chest(kit, x0, y0, x1, y1):
    """TopLeftChestA: compartments of banded books, tied scrolls and small
    sealed bundles, and the old atlas with a scroll hidden in it."""
    wood = oak()
    front, height = y1, 114.0
    back = carcass(kit, x0, x1, front, 46.0, height, wood)
    cols = 4
    width = (x1 - x0 - 10.0) / cols
    rows = ((7.0, 40.0), (43.0, 76.0), (79.0, height - 5.0))
    for index in range(1, cols):
        x = x0 + 5.0 + width * index
        kit.box("Divider", x - 1.6, x + 1.6, back, front + 0.6, 7.0, height - 4.0, wood, bevel=0.6, uv="box_up")
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, x1 - 5.0, back, front, h0, wood)
    rng = random.Random(75)
    linen, wax = wake.linen(), hall._painted("LibrarySealWax", (0.4, 0.05, 0.04))
    for row, (h0, h1) in enumerate(rows):
        for col in range(cols):
            a = x0 + 5.0 + width * col + (1.8 if col else 0.4)
            b = x0 + 5.0 + width * (col + 1) - (1.8 if col < cols - 1 else 0.4)
            kind = (row + col) % 3
            if row == 0 and col == 0:
                wake.closed_book(kit, "Atlas", a + 1.0, b - 1.0, front - 34.0, front - 4.0, h0, 6.0, (0.22, 0.14, 0.06))
                kit.rod("AtlasScroll", (a + 6.0, front - 10.0, h0 + 3.0), (b + 1.0, front - 10.0, h0 + 3.0), 2.3,
                        wake.parchment())
                kit.ring("AtlasScrollTie", (b - 6.0, front - 10.0, h0 + 3.0), (1.0, 0.0, 0.0), 2.5, 0.35,
                         hall._cloth("LibraryTie", (0.32, 0.05, 0.04)), segments=16, sides=6)
            elif kind == 0:
                wake.shelf_run(kit, a, b, front - 2.0, h0, h1, rng, lean_end=False)
                kit.box("Band", a, b - 2.0, front - 1.2, front + 0.2, h0 + (h1 - h0) * 0.36, h0 + (h1 - h0) * 0.46,
                        hall._cloth("LibraryBand", (0.16, 0.1, 0.06)), bevel=0.1)
            elif kind == 1:
                scroll_bundle(kit, a + 1.0, b - 1.0, front - 12.0, h0, rng)
            else:
                x = a + 1.5
                while x < b - 10.0:
                    size = rng.uniform(9.0, 13.0)
                    tall = rng.uniform(8.0, 14.0)
                    kit.box("Bundle", x, x + size, front - 26.0, front - 4.0, h0, h0 + tall, linen, bevel=1.4, uv="box")
                    kit.ball("BundleSeal", x + size / 2.0, front - 3.6, h0 + tall * 0.55, 1.4, wax)
                    x += size + rng.uniform(1.0, 2.5)
    dress_top(kit, "Divided", x0, x1, back, front, height + 0.7, random.Random(85), light="lantern")


def scroll_bundle(kit, x0, x1, y, h, rng):
    """Scrolls laid in a pile and tied."""
    paper = wake.parchment()
    radius = 2.4
    for layer, count in enumerate((3, 2, 1)):
        for index in range(count):
            offset = (index - (count - 1) / 2.0) * radius * 2.1
            kit.rod("Scroll", (x0 + rng.uniform(0.0, 3.0), y + offset * 0.4, h + radius + layer * radius * 1.7),
                    (x1 - rng.uniform(0.0, 3.0), y + offset * 0.4, h + radius + layer * radius * 1.7), radius, paper)
    for x in (x0 + (x1 - x0) * 0.3, x0 + (x1 - x0) * 0.7):
        kit.ring("ScrollTie", (x, y, h + radius * 2.2), (1.0, 0.0, 0.0), radius * 2.6, 0.35,
                 hall._cloth("LibraryTie", (0.32, 0.05, 0.04)), segments=20, sides=6)


def reflection_cabinet(kit, x0, y0, x1, y1):
    """LowerStorage, the violet reflection cabinet (knowledge II): violet
    compartments of archive boxes, one empty, one holding the last field guide
    on reflection beside a small round mirror."""
    lacquer, metal = violet_lacquer(), brass()
    front, height = y1, 131.0
    back = carcass(kit, x0, x1, front, 50.0, height, lacquer)
    cols = 3
    width = (x1 - x0 - 10.0) / cols
    rows = ((7.0, 47.0), (50.0, 89.0), (92.0, height - 5.0))
    for index in range(1, cols):
        x = x0 + 5.0 + width * index
        kit.box("Divider", x - 1.8, x + 1.8, back, front + 0.6, 7.0, height - 4.0, lacquer, bevel=0.6, uv="box_up")
        kit.box("DividerGilt", x - 0.6, x + 0.6, front + 0.5, front + 0.9, 7.0, height - 4.0, metal, bevel=0.0)
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, x1 - 5.0, back, front, h0, lacquer)
        kit.box("ShelfGilt", x0 + 5.0, x1 - 5.0, front + 0.3, front + 0.7, h0 - 2.4, h0 - 1.2, metal, bevel=0.0)
    boxes = wake.leather("LibraryArchiveBox", (0.17, 0.11, 0.08))
    rng = random.Random(76)
    for row, (h0, h1) in enumerate(rows):
        for col in range(cols):
            a = x0 + 5.0 + width * col + 2.2
            b = x0 + 5.0 + width * (col + 1) - 2.2
            kit.box("PlaqueGilt", (a + b) / 2.0 - 5.0, (a + b) / 2.0 + 5.0, front + 0.4, front + 0.9,
                    h0 - 6.0 if row else 8.0, h0 - 3.0 if row else 11.0, metal, bevel=0.1)
            if (row, col) == (1, 2):
                continue
            if (row, col) == (1, 1):
                knowledge_volume(kit, "Guide", (a + b) / 2.0 - 8.0, front - 3.0, h0, (h1 - h0) * 0.84,
                                 (0.14, 0.05, 0.2))
                mx, my = (a + b) / 2.0 + 8.0, front - 10.0
                kit.lathe("MirrorFoot", mx, my, [(0.0, h0), (3.4, h0), (0.8, h0 + 2.0), (0.6, h0 + 9.0),
                                                 (0.0, h0 + 9.0)],
                          metal, plan=ROUND)
                kit.slab("Mirror", disc_outline(mx, h0 + 16.0, 6.0, 24), my - 0.4, my + 0.4, mirror())
                kit.ring("MirrorRim", (mx, my + 0.4, h0 + 16.0), (0.0, 1.0, 0.0), 6.2, 0.6, metal, segments=28, sides=6)
                continue
            x = a + 0.5
            while x < b - 8.0:
                size = rng.uniform(9.0, 12.0)
                tall = (h1 - h0) * rng.uniform(0.6, 0.8)
                kit.box("ArchiveBox", x, x + size, front - 30.0, front - 3.0, h0, h0 + tall, boxes, bevel=0.6)
                kit.box("BoxLabel", x + size * 0.22, x + size * 0.78, front - 3.1, front - 2.6, h0 + tall * 0.45,
                        h0 + tall * 0.72, wake.parchment(), bevel=0.0)
                x += size + rng.uniform(0.6, 1.6)
    dress_top(kit, "Violet", x0, x1, back, front, height + 0.7, random.Random(86), light="candle")


def additive_archive(kit, x0, y0, x1, y1):
    """StorageCabinet, the reinforced additive-light archive (knowledge III):
    iron-strapped doors marked with three overlapping circles either side of
    shelves emptied but for one filed volume, three lenses on its crest."""
    wood, metal, ironwork = oak(), brass(), iron()
    front, height = y1, 152.0
    back = carcass(kit, x0, x1, front, 60.0, height, wood)
    side = 82.0
    middle0, middle1 = x0 + side, x1 - side
    for a, b in ((x0 + 4.0, middle0 - 3.0), (middle1 + 3.0, x1 - 4.0)):
        kit.box("Door", a, b, front - 0.5, front + 1.4, 8.0, height - 6.0, wood, bevel=1.2, uv="box_up")
        kit.box("DoorPanel", a + 6.0, b - 6.0, front + 1.2, front + 2.2, 14.0, height - 12.0, wood, bevel=1.6,
                uv="box_up")
        for h in (26.0, 74.0, 128.0):
            kit.box("Strap", a + 0.5, b - 0.5, front + 2.0, front + 2.9, h - 2.6, h + 2.6, ironwork, bevel=0.3)
            for x in (a + 4.0, (a + b) / 2.0, b - 4.0):
                kit.ball("StrapRivet", x, front + 3.0, h, 0.8, ironwork)
        emblem(kit, "Additive", "additive", (a + b) / 2.0, front + 2.4, 101.0, 15.0)
        kit.box("Escutcheon", (a + b) / 2.0 - 2.4, (a + b) / 2.0 + 2.4, front + 2.1, front + 2.7, 46.0, 54.0, metal,
                bevel=0.3)
    for x in (middle0, middle1):
        kit.box("Stile", x - 3.0, x + 3.0, back, front + 1.6, 7.0, height - 4.0, wood, bevel=0.8, uv="box_up")
    for h in (50.0, 96.0):
        shelf(kit, middle0 + 3.0, middle1 - 3.0, back, front, h, wood)
    knowledge_volume(kit, "Additive", (middle0 + middle1) / 2.0 - 2.6, front - 3.0, 50.0, 34.0, (0.06, 0.08, 0.2))
    wake.closed_book(kit, "Bookend", middle0 + 8.0, middle0 + 22.0, front - 22.0, front - 6.0, 96.0, 3.0,
                     (0.15, 0.085, 0.045))
    cx = (x0 + x1) / 2.0
    kit.box("CrestBar", cx - 24.0, cx + 24.0, front - 4.0, front, height, height + 3.0, metal, bevel=0.5)
    for step, colour in enumerate((STATION["red"], STATION["green"], STATION["blue"])):
        x = cx - 15.0 + 15.0 * step
        kit.ring("CrestRing%d" % step, (x, front - 1.0, height + 10.0), (0.0, 1.0, 0.0), 5.2, 0.7, metal, segments=24,
                 sides=6)
        kit.slab("CrestLens%d" % step, disc_outline(x, height + 10.0, 4.6, 20), front - 1.4, front - 0.6,
                 glow("LibraryCrestLens%d" % step + ("Lit" if AWAKENED else ""), colour, 3.0 if AWAKENED else 0.5))
    for x in (x0 - 0.5, x1 - 5.5):
        for h in (7.0, height - 13.0):
            kit.box("Bracket", x, x + 6.0, front + 0.6, front + 1.8, h, h + 6.0, ironwork, bevel=0.3)
    dress_top(kit, "AdditiveW", x0, cx - 28.0, back, front, height + 0.7, random.Random(87))
    dress_top(kit, "AdditiveE", cx + 28.0, x1, back, front, height + 0.7, random.Random(88), light="lantern")


def wavelength_case(kit, x0, y0, x1, y1):
    """TopLeftTallCase, the tall wavelength case (knowledge I): a narrow
    two-part case, its glazed upper part emptied but for one field study of
    visible wavelengths, a glass prism standing on its head."""
    wood, metal = oak(), brass()
    front, height = y1, 141.0
    back = front - 80.0
    kit.box("Foot", x0 + 0.5, x1 - 0.5, back + 1.0, front + 1.0, 0.0, 5.0, wood, bevel=0.8, uv="box")
    kit.box("Lower", x0 + 1.0, x1 - 1.0, back + 2.0, front - 0.5, 5.0, 58.0, wood, bevel=0.9, uv="box_up")
    for a, b in ((x0 + 4.0, (x0 + x1) / 2.0 - 0.8), ((x0 + x1) / 2.0 + 0.8, x1 - 4.0)):
        kit.box("LowerDoor", a, b, front - 0.6, front + 0.8, 9.0, 54.0, wood, bevel=1.2, uv="box_up")
    emblem(kit, "Pulls", "handles", (x0 + x1) / 2.0, front + 0.8, 36.0, 12.0)
    kit.box("Waist", x0 - 1.0, x1 + 1.0, back + 1.0, front + 2.0, 58.0, 62.0, wood, bevel=1.0, uv="box")
    ux0, ux1, uf = x0 + 3.0, x1 - 3.0, front - 10.0
    for a, b in ((ux0, ux0 + 4.0), (ux1 - 4.0, ux1)):
        kit.box("UpperSide", a, b, back + 3.0, uf, 62.0, height - 8.0, wood, bevel=0.8, uv="box_up")
    kit.box("UpperBack", ux0 + 4.0, ux1 - 4.0, back + 3.0, back + 5.0, 62.0, height - 8.0, wood, bevel=0.0, uv="box_up")
    kit.box("UpperTop", ux0 - 1.5, ux1 + 1.5, back + 2.0, uf + 1.5, height - 8.0, height - 4.0, wood, bevel=1.0,
            uv="box")
    kit.box("UpperCrown", ux0 - 3.0, ux1 + 3.0, back + 1.0, uf + 3.0, height - 4.0, height - 1.5, wood, bevel=1.0,
            uv="box")
    for h in (86.0, 110.0):
        kit.box("CaseShelf", ux0 + 4.0, ux1 - 4.0, back + 5.0, uf - 1.0, h - 2.4, h, wood, bevel=0.5, uv="box")
    knowledge_volume(kit, "Spectrum", (x0 + x1) / 2.0 - 2.6, uf - 4.0, 86.0, 21.0, (0.24, 0.05, 0.04))
    for a, b, low, high in ((ux0 + 4.0, ux1 - 4.0, 62.0, 65.0), (ux0 + 4.0, ux1 - 4.0, height - 11.0, height - 8.0),
                            (ux0 + 4.0, ux0 + 7.0, 62.0, height - 8.0), (ux1 - 7.0, ux1 - 4.0, 62.0, height - 8.0)):
        kit.box("GlazingFrame", a, b, uf - 0.6, uf + 1.0, low, high, wood, bevel=0.4, uv="box")
    pane = kit.quad("Glazing", [(ux0 + 7.0, uf + 0.2, 65.0), (ux1 - 7.0, uf + 0.2, 65.0),
                                (ux1 - 7.0, uf + 0.2, height - 11.0),
                                (ux0 + 7.0, uf + 0.2, height - 11.0)], case_glass())
    pane.visible_shadow = False
    cx = (x0 + x1) / 2.0
    kit.box("GlazingBar", cx - 0.6, cx + 0.6, uf + 0.2, uf + 0.9, 65.0, height - 11.0, metal, bevel=0.1)
    kit.box("GlazingBarH", ux0 + 7.0, ux1 - 7.0, uf + 0.2, uf + 0.9, 98.0, 99.2, metal, bevel=0.1)
    cy = (back + uf) / 2.0
    kit.lathe("PrismStand", cx, cy, [(0.0, height - 1.5), (5.0, height - 1.5), (1.0, height + 2.0), (0.8, height + 9.0),
                                     (0.0, height + 9.0)], metal, plan=ROUND)
    kit.box("PrismCradle", cx - 9.0, cx + 9.0, cy - 2.4, cy + 2.4, height + 8.5, height + 9.8, metal, bevel=0.3)
    glass_prism(kit, "Prism", cx - 8.0, cx + 8.0, cy, height + 9.8, 7.0)


def tower(upper, lower, depth, height, lid="ring"):
    def build(kit, x0, y0, x1, y1):
        archive_tower(kit, x0, x1, y1, depth, height, upper, lower, lid=lid)
    return build


def packed_bookcase(kit, x0, y0, x1, y1):
    """ChestCabinet, the chest of books: packed with worn books, the top row
    given to bundled scrolls."""
    wood = oak()
    front, height = y1, 127.0
    back = carcass(kit, x0, x1, front, 55.0, height, wood)
    rows = ((7.0, 42.0), (45.0, 82.0), (85.0, height - 5.0))
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, x1 - 5.0, back, front, h0, wood)
    rng = random.Random(77)
    middle = (x0 + x1) / 2.0
    for row, (h0, h1) in enumerate(rows):
        if row == 2:
            wake.shelf_run(kit, x0 + 5.5, middle - 4.0, front - 2.0, h0, h1, rng, lean_end=False)
            scroll_bundle(kit, middle, x1 - 7.0, front - 14.0, h0, rng)
        else:
            wake.shelf_run(kit, x0 + 5.5, x1 - 5.5, front - 2.0, h0, h1, rng, lean_end=row == 0)
    dress_top(kit, "Packed", x0, x1, back, front, height + 0.7, random.Random(89), light="lantern")


def chained_case(kit, x0, y0, x1, y1):
    """UpperChestCabinet, the chained book chest: brass-grilled doors over
    books lately disturbed, an iron chain crossed over them and a padlock."""
    wood, metal, ironwork = oak(), brass(), iron()
    front, height = y1, 110.0
    back = carcass(kit, x0, x1, front, 42.0, height, wood)
    rows = ((7.0, 40.0), (43.0, 74.0), (77.0, height - 5.0))
    for h0, _h1 in rows[1:]:
        shelf(kit, x0 + 5.0, x1 - 5.0, back, front, h0, wood)
    rng = random.Random(78)
    for row, (h0, h1) in enumerate(rows):
        x = wake.shelf_run(kit, x0 + 5.5, x0 + (x1 - x0) * (0.45 + 0.12 * row), front - 6.0, h0, h1, rng)
        wake.closed_book(kit, "Fallen%d" % row, x + 4.0, x + 30.0, front - 24.0, front - 8.0, h0, 4.5,
                         wake.BOOK_COLOURS[row])
        wake.shelf_run(kit, x + 36.0, x1 - 5.5, front - 6.0, h0, h1, rng)
    middle = (x0 + x1) / 2.0
    for a, b in ((x0 + 4.0, middle - 1.0), (middle + 1.0, x1 - 4.0)):
        for low, high in ((7.0, 10.0), (height - 9.0, height - 5.0)):
            kit.box("DoorRail", a, b, front - 1.0, front + 1.4, low, high, wood, bevel=0.6, uv="box")
        for c, d in ((a, a + 4.0), (b - 4.0, b)):
            kit.box("DoorStile", c, d, front - 1.0, front + 1.4, 7.0, height - 5.0, wood, bevel=0.6, uv="box_up")
        bars = int((b - a - 8.0) / 6.0)
        for step in range(1, bars + 1):
            x = a + 4.0 + (b - a - 8.0) * step / (bars + 1)
            kit.rod("Grille", (x, front + 0.4, 10.0), (x, front + 0.4, height - 9.0), 0.35, metal)
        for h in (height * 0.36, height * 0.68):
            kit.rod("GrilleH", (a + 4.0, front + 0.5, h), (b - 4.0, front + 0.5, h), 0.35, metal)
    chain(kit, "ChainA", (x0 + 7.0, front + 3.0, 12.0), (x1 - 7.0, front + 3.0, height - 14.0), ironwork)
    chain(kit, "ChainB", (x1 - 7.0, front + 3.0, 12.0), (x0 + 7.0, front + 3.0, height - 14.0), ironwork)
    padlock(kit, "Lock", middle, front + 4.6, height * 0.5)
    dress_top(kit, "Chained", x0, x1, back, front, height + 0.7, random.Random(90))


def archive_drawers(kit, x0, y0, x1, y1):
    """UpperDrawerCabinet, the archive drawers: rows of labelled drawers (one
    drawn out, papers spilling, one lacquered violet with no pull at all),
    over a cubby of alchemical volumes with a bottled scroll tucked between
    them, and a shelf of casework on top."""
    wood, metal = oak(), brass()
    front, height = y1, 115.0
    back = carcass(kit, x0, x1, front, 50.0, height, wood)
    rng = random.Random(79)
    middle = (x0 + x1) / 2.0
    kit.box("CubbyShelf", x0 + 5.0, x1 - 5.0, back + 2.0, front - 1.0, 24.0, 27.0, wood, bevel=0.6, uv="box")
    for index, (a, b) in enumerate(((x0 + 8.0, middle - 22.0), (middle + 18.0, x1 - 8.0))):
        h = 7.0
        for layer in range(3):
            thick = rng.uniform(3.6, 5.0)
            wake.closed_book(kit, "Alchemy%d" % index, a + rng.uniform(0.0, 4.0), b - rng.uniform(0.0, 4.0),
                             front - 30.0, front - 6.0, h, thick, wake.BOOK_COLOURS[(index * 3 + layer) % 8])
            h += thick
    bottle = kit.lathe("ScrollBottle", middle - 2.0, front - 14.0, [(0.0, 8.0), (5.6, 8.0), (6.0, 9.0), (6.0, 20.0),
                                                                     (3.0, 23.0), (2.2, 27.0), (0.0, 27.0)],
                       glass(), plan=ROUND, close=False)
    bottle.visible_shadow = False
    kit.rod("BottledScroll", (middle - 2.0, front - 14.0, 10.0), (middle - 2.0, front - 14.0, 22.0), 3.4,
            wake.parchment())
    kit.lathe("BottleCork", middle - 2.0, front - 14.0, [(0.0, 26.0), (2.4, 26.0), (2.6, 29.5), (0.0, 29.5)],
              hall._painted("LibraryCork", (0.36, 0.24, 0.12)), plan=ROUND)
    cols, rows = 5, 3
    width, tall = (x1 - x0 - 10.0) / cols, (75.0 - 28.0) / rows
    violet = violet_lacquer()
    for col in range(cols):
        for row in range(rows):
            a, h = x0 + 5.0 + width * col, 28.0 + tall * row
            drawn = (col, row) == (3, 1)
            lacquered = (col, row) == (0, 2)
            out = 6.0 if drawn else 0.0
            kit.box("Drawer", a + 1.0, a + width - 1.0, front - 1.0 + out, front + 1.2 + out, h + 1.0, h + tall - 1.0,
                    violet if lacquered else wood, bevel=0.8, uv="box")
            centre = a + width / 2.0
            if drawn:
                kit.box("DrawerBox", a + 1.8, a + width - 1.8, front - 22.0 + out, front + out, h + 1.6, h + tall - 3.0,
                        wood, bevel=0.4, uv="box")
                for sheet in range(4):
                    x = a + 4.0 + sheet * (width - 10.0) / 3.0
                    lift = 4.0 + rng.uniform(0.0, 5.0)
                    kit.quad("Paper", [(x, front + out - 3.0, h + tall - 4.0),
                                       (x + 9.0, front + out - 2.0, h + tall - 4.0),
                                       (x + 9.5, front + out - 6.0, h + tall + lift),
                                       (x + 0.5, front + out - 7.0, h + tall + lift - 1.0)],
                             wake.writing("LibraryNotes", lines=7.0))
            if not lacquered:
                kit.box("LabelFrame", centre - 4.5, centre + 4.5, front + 1.0 + out, front + 1.6 + out,
                        h + tall * 0.52, h + tall * 0.82, metal, bevel=0.1)
                kit.box("LabelCard", centre - 3.5, centre + 3.5, front + 1.5 + out, front + 1.7 + out,
                        h + tall * 0.56, h + tall * 0.78, wake.parchment(), bevel=0.0)
                kit.ball("Knob", centre, front + 2.2 + out, h + tall * 0.3, 1.2, metal)
    shelf(kit, x0 + 5.0, x1 - 5.0, back, front, 78.0, wood)
    wake.shelf_run(kit, x0 + 5.5, x1 - 5.5, front - 2.0, 78.0, height - 5.0, rng)
    dress_top(kit, "Drawers", x0, x1, back, front, height + 0.7, random.Random(92), light="candle")


def apothecary(kit, x0, y0, x1, y1):
    """UpperApothecaryCabinet: a bank of small drawers with porcelain labels
    under a counter of bottles, powders and sealed jars, one vial clean of the
    dust the others wear."""
    wood, metal = oak(), brass()
    front, height = y1, 104.0
    back = front - 56.0
    counter = 62.0
    carcass(kit, x0, x1, front, 56.0, counter - 1.5, wood, crown=False)
    porcelain = hall._painted("LibraryPorcelain", (0.72, 0.7, 0.64))
    cols, rows = 8, 4
    width, tall = (x1 - x0 - 10.0) / cols, (counter - 12.0) / rows
    for col in range(cols):
        for row in range(rows):
            a, h = x0 + 5.0 + width * col, 8.0 + tall * row
            kit.box("Drawer", a + 0.8, a + width - 0.8, front - 1.0, front + 1.2, h + 0.8, h + tall - 0.8, wood,
                    bevel=0.7, uv="box")
            centre = a + width / 2.0
            kit.box("Label", centre - 5.0, centre + 5.0, front + 1.0, front + 1.5, h + tall * 0.55, h + tall * 0.85,
                    porcelain, bevel=0.2)
            kit.ball("Knob", centre, front + 2.0, h + tall * 0.32, 1.0, metal)
    kit.box("Counter", x0 - 1.5, x1 + 1.5, back - 0.5, front + 2.5, counter - 1.5, counter + 1.5, wood, bevel=1.0,
            uv="box")
    kit.box("StepLow", x0 + 2.0, x1 - 2.0, back, back + 22.0, counter + 1.5, counter + 14.0, wood, bevel=0.8, uv="box")
    kit.box("StepHigh", x0 + 2.0, x1 - 2.0, back, back + 11.0, counter + 14.0, counter + 28.0, wood, bevel=0.8,
            uv="box")
    kit.box("Riser", x0 + 2.0, x1 - 2.0, back, back + 2.5, counter + 28.0, height, wood, bevel=0.6, uv="box_up")
    rng = random.Random(80)
    colours = ((0.35, 1.0, 0.5), VIOLET, (0.25, 0.55, 1.0), (1.0, 0.5, 0.15), (0.9, 0.2, 0.25), (0.8, 0.8, 0.3))
    stoneware = hall._painted("LibraryStoneware", (0.3, 0.26, 0.2))
    x = x0 + 10.0
    while x < x1 - 14.0:
        if abs(x - (x0 + x1) / 2.0) < 10.0:
            wake.flask(kit, "CleanVial", x, front - 12.0, counter + 1.5, "bottle", (0.3, 1.0, 0.55), size=0.95)
            x += 14.0
            continue
        kind = rng.choice(("round", "cone", "bottle"))
        wake.flask(kit, "Bottle", x, front - 12.0 + rng.uniform(-3.0, 3.0), counter + 1.5, kind, rng.choice(colours),
                   size=rng.uniform(0.7, 0.95))
        x += rng.uniform(13.0, 19.0)
    x = x0 + 8.0
    while x < x1 - 10.0:
        radius = rng.uniform(3.2, 4.6)
        jar_h = rng.uniform(9.0, 14.0)
        kit.lathe("Jar", x + radius, back + 16.0, [(0.0, counter + 14.0), (radius, counter + 14.0),
                                                   (radius, counter + 14.0 + jar_h),
                                                   (radius * 0.7, counter + 15.0 + jar_h),
                                                   (0.0, counter + 15.0 + jar_h)], stoneware, plan=ROUND)
        kit.lathe("JarLid", x + radius, back + 16.0, [(0.0, counter + 15.0 + jar_h),
                                                      (radius * 0.8, counter + 15.0 + jar_h),
                                                      (radius * 0.6, counter + 17.0 + jar_h),
                                                      (0.0, counter + 17.5 + jar_h)],
                  hall._painted("LibraryCork", (0.36, 0.24, 0.12)), plan=ROUND)
        x += radius * 2.0 + rng.uniform(2.0, 5.0)
    x = x0 + 12.0
    while x < x1 - 8.0:
        wake.flask(kit, "Vial", x, back + 6.0, counter + 28.0, "bottle", rng.choice(colours), size=0.55)
        x += rng.uniform(8.0, 12.0)
    kit.lathe("Mortar", x1 - 30.0, front - 24.0, [(0.0, counter + 1.5), (4.6, counter + 1.5), (6.4, counter + 5.5),
                                                  (6.0, counter + 8.5), (5.2, counter + 8.5), (0.0, counter + 3.5)],
              wake.stone(), plan=ROUND)
    kit.rod("Pestle", (x1 - 31.0, front - 24.0, counter + 6.0), (x1 - 24.0, front - 30.0, counter + 15.0), 1.2,
            wake.stone())


def desk_body(kit, x0, x1, back, front, top, wood, drawers=3):
    """A writing table: turned legs, an apron of drawers and a leather top."""
    for x in (x0 + 5.0, x1 - 5.0):
        for y in (back + 5.0, front - 4.0):
            kit.lathe("Leg", x, y, [(0.0, 0.0), (3.4, 0.0), (3.4, 2.4), (2.6, 4.0), (3.0, 10.0), (2.0, 18.0),
                                    (3.2, 24.0),
                                    (3.2, top - 8.0), (0.0, top - 8.0)], wood, plan=0.6, uv="box_up")
    kit.box("Apron", x0 + 3.0, x1 - 3.0, back + 3.0, front - 2.0, top - 12.0, top - 4.0, wood, bevel=0.8, uv="box")
    kit.box("Top", x0 - 1.0, x1 + 1.0, back - 1.0, front + 1.5, top - 4.0, top, wood, bevel=1.2, uv="box")
    span = (x1 - x0 - 16.0) / drawers
    for index in range(drawers):
        a = x0 + 8.0 + span * index
        kit.box("Drawer", a + 1.0, a + span - 1.0, front - 2.6, front - 1.0, top - 11.0, top - 5.0, wood, bevel=0.5,
                uv="box")
        kit.ball("DrawerPull", a + span / 2.0, front - 0.6, top - 8.0, 1.4, brass())
    kit.box("Inlay", x0 + 5.0, x1 - 5.0, back + 4.0, front - 4.0, top, top + 0.3,
            wake.leather("LibraryDeskInlay", (0.08, 0.12, 0.07)), bevel=0.0)


def desk_things(kit, part, x, y, h, rng):
    """Ink, a quill and a sheet or two."""
    kit.lathe(part + "Ink", x, y, [(0.0, h), (4.0, h), (4.4, h + 2.0), (4.0, h + 5.4), (2.2, h + 6.6), (2.0, h + 8.0),
                                   (0.0, h + 8.0)], hall._bakelite(), plan=ROUND)
    kit.rod(part + "Quill", (x, y, h + 7.0), (x + 12.0, y - 14.0, h + 30.0), 0.5, wake.linen())
    kit.quad(part + "Vane", [(x + 3.0, y - 4.0, h + 14.0), (x + 7.6, y - 8.0, h + 19.0), (x + 12.0, y - 14.0, h + 30.0),
                             (x + 6.6, y - 9.0, h + 23.0)], wake.linen())
    for index in range(2):
        desk_top_paper(kit, part + "Sheet%d" % index, x - 22.0 - index * 9.0, y + rng.uniform(-6.0, 4.0),
                       h + 0.2 + 0.1 * index,
                       rng.uniform(-0.3, 0.3))


def reflection_desk(kit, x0, y0, x1, y1):
    """WritingDesk, the Reflection Matrix: a writing table under a brass frame
    of nine small mirrors, each turned its own way, the green lamp beside it."""
    wood, metal = oak(), brass()
    front, top = y1, 44.0
    back = front - 72.0
    desk_body(kit, x0 + 2.0, x1 - 2.0, back, front, top, wood)
    desk_chair(kit, "Chair", (x0 + x1) / 2.0, y0 + 18.0)
    fx0, fx1, fy = x0 + 18.0, x0 + 92.0, back + 16.0
    for x in (fx0, fx1):
        kit.rod("FramePost", (x, fy, top), (x, fy, top + 58.0), 1.1, metal)
        kit.ball("FrameFinial", x, fy, top + 59.5, 1.8, metal)
    for h in (top + 4.0, top + 57.0):
        kit.rod("FrameBar", (fx0, fy, h), (fx1, fy, h), 0.9, metal)
    rng = random.Random(81)
    for row in range(3):
        for col in range(3):
            mx = fx0 + (fx1 - fx0) * (col + 0.5) / 3.0
            mh = top + 12.0 + row * 15.5
            disc = kit.slab("MatrixMirror", disc_outline(mx, mh, 6.4, 24), fy - 0.4, fy + 0.4, mirror())
            ring = kit.ring("MatrixGimbal", (mx, fy + 0.4, mh), (0.0, 1.0, 0.0), 7.2, 0.5, metal, segments=28, sides=6)
            pivot = RP.world(mx, fy, mh)
            turn = (Matrix.Translation(pivot) @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Z")
                    @ Matrix.Rotation(rng.uniform(-0.35, 0.35), 4, "X") @ Matrix.Translation(-pivot))
            for obj in (disc, ring):
                obj.data.transform(turn)
            kit.rod("MatrixAxle", (mx - 7.4, fy, mh), (mx + 7.4, fy, mh), 0.35, metal)
    station_lamp(kit, "Lamp", "green", x1 - 24.0, back + 22.0, top)
    desk_things(kit, "Desk", x1 - 42.0, front - 16.0, top + 0.3, rng)
    candelabrum(kit, "Candle", x0 + 9.0, back + 9.0, top, power=2.4, stem=4.0)


def globe_desk(kit, x0, y0, x1, y1):
    """LowerGlobeDesk, the Additive Relay: a desk under a great globe with
    three emitters (red, green and blue) on brass arms trained on it, and
    the blue lamp."""
    wood, metal = oak(), brass()
    front, top = y1, 42.0
    back = front - 60.0
    desk_body(kit, x0 + 1.0, x1 - 1.0, back, front, top, wood, drawers=2)
    gx, gy = x0 + 30.0, back + 24.0
    kit.lathe("GlobeStand", gx, gy, [(0.0, top), (8.0, top), (8.2, top + 1.6), (2.4, top + 3.4), (1.6, top + 9.0),
                                     (0.0, top + 9.0)], metal, plan=ROUND)
    kit.ring("GlobeMeridian", (gx, gy, top + 28.0), (1.0, 0.0, 0.0), 20.0, 1.0, metal)
    kit.ball("Globe", gx, gy, top + 28.0, 17.5, globe_material(), plan=ROUND, segments=32)
    for index, (dx, dy, dh, name) in enumerate(((34.0, -12.0, 40.0, "red"), (40.0, 6.0, 26.0, "green"),
                                                (24.0, 22.0, 18.0, "blue"))):
        hx, hy, hh = gx + dx, gy + dy, top + dh
        kit.lathe("EmitterClamp%d" % index, hx + 4.0, hy, [(0.0, top), (3.0, top), (3.0, top + 2.0), (0.0, top + 2.0)],
                  metal, plan=ROUND)
        kit.rod("EmitterArm%d" % index, (hx + 4.0, hy, top + 2.0), (hx + 2.0, hy, hh), 0.7, metal)
        kit.rod("EmitterHead%d" % index, (hx + 4.0, hy, hh), (hx - 2.0, hy, hh + 0.6), 2.6, metal)
        kit.ball("EmitterLens%d" % index, hx - 2.4, hy, hh + 0.6, 1.9,
                 glow("LibraryEmitter" + name.title() + ("Lit" if AWAKENED else ""), STATION[name],
                      4.0 if AWAKENED else 0.6), plan=0.8)
    station_lamp(kit, "Lamp", "blue", x1 - 18.0, back + 20.0, top)
    open_book(kit, "Book", 112.0, 140.0, 452.0, 468.0, top + 0.3)
    candelabrum(kit, "Candle", x1 - 8.0, back + 8.0, top, power=2.4, stem=4.0)


def globe_material():
    """A terrestrial globe: aged ocean, ochre lands, a gilt meridian line."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        land = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=22.0, detail=4.0),
                          0.5, 0.53)
        colour = hall._mix(nodes, links, land, (0.06, 0.14, 0.2), (0.42, 0.32, 0.14))
        hall._principled(nodes, links, colour, roughness=0.42)
    return hall._material("LibraryGlobe", build)


def research_desk(kit, x0, y0, x1, y1):
    """LowerStudyTable, the research desk at the room's heart (the game's
    Spectrum Sequencer and detective table): a pedestal desk of papers,
    candles and a magnifying glass, with a brass spectroscope and the red
    lamp. The optical array stands on its front (optical_array)."""
    wood, metal = oak(), brass()
    front, top = y1, 46.0
    back = front - 136.0
    for a, b in ((x0 + 2.0, x0 + 46.0), (x1 - 46.0, x1 - 2.0)):
        kit.box("Pedestal", a, b, back + 2.0, front - 1.5, 4.0, top - 5.0, wood, bevel=0.9, uv="box_up")
        kit.box("PedestalFoot", a - 1.0, b + 1.0, back + 1.0, front - 0.5, 0.0, 4.0, wood, bevel=0.8, uv="box")
        for low, high in ((8.0, 21.0), (23.0, 37.0)):
            kit.box("PedestalPanel", a + 4.0, b - 4.0, front - 1.6, front - 0.4, low, high, wood, bevel=1.2, uv="box")
            kit.box("Keyhole", (a + b) / 2.0 - 1.6, (a + b) / 2.0 + 1.6, front - 0.5, front - 0.1,
                    (low + high) / 2.0 - 2.4,
                    (low + high) / 2.0 + 2.4, metal, bevel=0.2)
    kit.box("Modesty", x0 + 46.0, x1 - 46.0, front - 6.0, front - 2.0, 9.0, top - 5.0, wood, bevel=0.8, uv="box_up")
    kit.box("Top", x0, x1, back, front + 1.5, top - 5.0, top, wood, bevel=1.4, uv="box")
    kit.box("Inlay", x0 + 6.0, x1 - 6.0, back + 6.0, front - 6.0, top, top + 0.3,
            wake.leather("LibraryResearchInlay", (0.11, 0.035, 0.03)), bevel=0.0)
    desk_chair(kit, "Chair", (x0 + x1) / 2.0, y0 + 22.0)
    h = top + 0.3
    rng = random.Random(82)
    open_book(kit, "Book", 688.0, 734.0, 556.0, 590.0, h)
    for index, (x, y, angle) in enumerate(((668.0, 572.0, 0.25), (752.0, 584.0, -0.18), (705.0, 612.0, 0.1))):
        desk_top_paper(kit, "Paper%d" % index, x, y, h + 0.1 * index, angle)
    kit.ring("Magnifier", (660.0, 604.0, h + 1.2), (0.0, 0.0, 1.0), 6.0, 0.9, metal, segments=32, sides=8)
    kit.slab("MagnifierGlass", disc_outline(660.0, 604.0, 5.4, 24, squash=1.0 / RP.STRETCH), h + 0.9, h + 1.5,
             case_glass(), plane="floor")
    kit.rod("MagnifierHandle", (666.0, 608.0, h + 1.2), (678.0, 615.0, h + 1.2), 1.1, wood)
    desk_things(kit, "Ink", 770.0, 612.0, h, rng)
    candelabrum(kit, "Candles", 772.0, 528.0, h, arms=2, spread=6.0, power=3.0, stem=8.0)
    # The spectroscope: a brass prism table, its collimator and its telescope.
    sx, sy = 652.0, 538.0
    kit.lathe("SpectroTable", sx, sy, [(0.0, h), (7.0, h), (7.2, h + 1.6), (2.2, h + 3.0), (1.6, h + 12.0),
                                       (5.6, h + 13.0), (5.8, h + 14.2), (0.0, h + 14.2)], metal, plan=ROUND)
    glass_prism(kit, "SpectroPrism", sx - 4.0, sx + 4.0, sy, h + 14.2, 6.0)
    for name, angle in (("Collimator", 200.0), ("Telescope", 330.0)):
        dx, dy = math.cos(math.radians(angle)), math.sin(math.radians(angle)) * ROUND
        kit.rod(name, (sx + dx * 6.0, sy + dy * 6.0, h + 17.0), (sx + dx * 22.0, sy + dy * 22.0, h + 19.0), 1.8, metal)
        kit.rod(name + "Post", (sx + dx * 14.0, sy + dy * 14.0, h), (sx + dx * 14.0, sy + dy * 14.0, h + 17.0), 0.7,
                metal)
    station_lamp(kit, "Lamp", "red", 646.0, 622.0, h)
    kit.ball("Paperweight", 727.0, 626.0, h + 3.2, 3.4, glow("LibraryPaperweight", (0.12, 0.3, 0.9), 0.4,
                                                            (0.02, 0.06, 0.2)), plan=ROUND)
    for index, colour in enumerate(((0.2, 0.06, 0.06), (0.06, 0.14, 0.1), (0.24, 0.17, 0.06))):
        wake.closed_book(kit, "Stack%d" % index, 734.0 + index, 758.0 - index, 524.0 + index, 544.0 - index,
                         h + index * 4.5, 4.5, colour)


# Each Worldsort piece's builder, called with (kit, x0, y0, x1, y1), its collision.
PIECES = {
    "TopLeftCabinetB": gallery_case("TopLeftCabinetB", 71, "reading"),
    "UpperShelfCabinet": gallery_case("UpperShelfCabinet", 72, "jars"),
    "TopLeftCabinetC": reinforced_bookcase,
    "TopLeftCabinetD": emblem_cabinet,
    "TopLeftChestA": divided_chest,
    "LowerStorage": reflection_cabinet,
    "StorageCabinet": additive_archive,
    "TopLeftTallCase": wavelength_case,
    "UpperPanelCabinet": tower("ring", "scratched", 80.0, 137.0),
    "TallCabinetA": tower("compass", "ring", 90.0, 153.0, lid="boss"),
    "TallCabinetB": tower("ring", "hourglass", 88.0, 145.0, lid="boss"),
    "LowerPanelA": tower("wheel", "crossed", 86.0, 144.0),
    "LowerPanelB": tower("handles", "clasp", 92.0, 149.0, lid="boss"),
    "ChestCabinet": packed_bookcase,
    "UpperChestCabinet": chained_case,
    "UpperDrawerCabinet": archive_drawers,
    "UpperApothecaryCabinet": apothecary,
    "WritingDesk": reflection_desk,
    "LowerGlobeDesk": globe_desk,
    "LowerStudyTable": research_desk,
}


# ---------------------------------------------------------------- the sides and the south


def side_dressing(shell):
    """Candle sconces and framed charts on the leaning side walls, and what
    stands in the side walls' recesses: built-in cabinets, crates, a barrel of
    maps, a floor candelabrum and a lamp."""
    kit = RP.Kit("Sides")
    ironwork, wood, boards, metal = iron(), oak(), wake.planks(), brass()
    for side, places in (("left", (300.0, 760.0)), ("right", (300.0, 860.0))):
        for index, y in enumerate(places):
            frame = shell.mount(side, y)
            wall = frame.to_g(0.0, 96.0, 0.0)
            cup = frame.to_g(0.0, 92.0, 13.0)
            kit.box("SconcePlate%s%d" % (side, index), wall.x - 1.5, wall.x + 1.5, y - 4.0, y + 4.0, wall.z - 9.0,
                    wall.z + 9.0, ironwork, bevel=0.4)
            kit.rod("SconceArm%s%d" % (side, index), (wall.x, y, wall.z - 2.0), (cup.x, cup.y, cup.z), 1.0, ironwork)
            kit.lathe("SconceCup%s%d" % (side, index), cup.x, cup.y, [(0.0, cup.z - 2.0), (2.0, cup.z - 2.0),
                                                                      (4.6, cup.z), (4.6, cup.z + 1.4),
                                                                      (0.0, cup.z + 1.4)], ironwork)
            kit.candle("Sconce%s%d" % (side, index), cup.x, cup.y, cup.z + 1.4, height=14.0, radius=2.8,
                       power=4.6 * WARMTH)
            pool(kit, "Sconce%s%d" % (side, index), cup.x + (24.0 if side == "left" else -24.0), y, power=2.0)
    rng = random.Random(91)
    # West: a built-in cabinet of stacked books, crates, a barrel of maps.
    kit.box("NicheCabinet", WEST_X + 1.0, 88.0, 472.0, 650.0, 0.0, 40.0, wood, bevel=1.0, uv="box")
    kit.box("NicheTop", WEST_X, 89.5, 470.0, 652.0, 40.0, 43.0, wood, bevel=1.0, uv="box")
    for index, (y0, y1) in enumerate(((480.0, 506.0), (556.0, 584.0), (606.0, 634.0))):
        h = 43.0
        for layer in range(rng.randint(2, 4)):
            thick = rng.uniform(3.5, 5.5)
            wake.closed_book(kit, "NicheBook%d" % index, 50.0 + rng.uniform(0.0, 4.0), 84.0 - rng.uniform(0.0, 4.0),
                             y0, y1, h, thick, wake.BOOK_COLOURS[(index + layer) % 8])
            h += thick
    scroll_bundle(kit, 52.0, 84.0, 530.0, 43.0, rng)
    for index, (y0, y1, tall) in enumerate(((678.0, 728.0, 30.0), (732.0, 778.0, 24.0), (782.0, 826.0, 30.0))):
        kit.box("Crate%d" % index, WEST_X + 2.0, 86.0, y0, y1, 0.0, tall, boards, bevel=0.8, uv="box")
        for y in (y0 + 3.0, y1 - 3.0):
            kit.box("CrateBatten%d" % index, WEST_X + 2.0, 86.0, y - 2.0, y + 2.0, tall - 0.6, tall + 1.2, boards,
                    bevel=0.5, uv="box")
    wake.closed_book(kit, "CrateBook", 52.0, 80.0, 690.0, 716.0, 31.2, 5.0, wake.BOOK_COLOURS[2])
    lantern(kit, "CrateLantern", 66.0, 800.0, 31.2, power=2.6)
    kit.lathe("Barrel", 76.0, 878.0, [(0.0, 0.0), (15.0, 0.0), (17.5, 10.0), (18.0, 18.0), (17.5, 26.0), (15.0, 34.0),
                                      (13.6, 34.0), (13.6, 4.0), (0.0, 4.0)], boards, plan=ROUND, uv="box_up")
    for h in (6.0, 28.0):
        kit.ring("BarrelHoop", (76.0, 878.0, h), (0.0, 0.0, 1.0), 17.6, 0.7, ironwork, segments=40, sides=6)
    for index in range(7):
        angle = index * 2.4
        x, y = 76.0 + 7.5 * math.cos(angle) * (index % 3) / 2.0, 878.0 + 5.0 * math.sin(angle) * (index % 3) / 2.0
        kit.rod("BarrelMap", (x, y, 6.0), (x + rng.uniform(-3.0, 3.0), y, 44.0 + rng.uniform(0.0, 10.0)), 2.2,
                wake.parchment())
    kit.box("NicheChest", 56.0, 104.0, 906.0, 944.0, 0.0, 22.0, boards, bevel=0.9, uv="box")
    # East: low cabinets fill the strips the collision closes, between the
    # alcoves it leaves open, so the east wall stands behind open floor only
    # where the player can walk.
    tops = {}
    for index, (x0, y0, y1, tall) in enumerate(((1392.0, 170.0, 222.0, 64.0), (1392.0, 238.0, 396.0, 40.0),
                                                (1392.0, 421.0, 449.0, 30.0), (1392.0, 528.0, 645.0, 40.0),
                                                (1404.0, 740.0, 860.0, 46.0))):
        kit.box("EastCabinet%d" % index, x0, EAST_X - 1.0, y0, y1, 0.0, tall - 3.0, wood, bevel=0.9, uv="box")
        kit.box("EastCabinetTop%d" % index, x0 - 1.0, EAST_X, y0 - 1.0, y1 + 1.0, tall - 3.0, tall, wood, bevel=1.0,
                uv="box")
        kit.box("EastCabinetDoor%d" % index, x0 + 4.0, EAST_X - 5.0, y1 - 0.4, y1 + 1.0, 6.0, tall - 9.0, wood,
                bevel=1.0, uv="box_up")
        kit.ball("EastCabinetKnob%d" % index, (x0 + EAST_X) / 2.0, y1 + 1.6, tall * 0.55, 1.2, metal)
        tops[index] = tall
    for layer, (y0, y1) in enumerate(((176.0, 200.0), (178.0, 198.0), (177.0, 199.0))):
        wake.closed_book(kit, "CornerBook%d" % layer, 1396.0, 1419.0, y0, y1, tops[0] + layer * 4.5, 4.5,
                         wake.BOOK_COLOURS[layer + 1])
    for layer, (y0, y1) in enumerate(((248.0, 278.0), (250.0, 276.0))):
        wake.closed_book(kit, "EastBook%d" % layer, 1396.0, 1419.0, y0, y1, tops[1] + layer * 5.0, 5.0,
                         wake.BOOK_COLOURS[layer + 4])
    lantern(kit, "EastLantern", 1407.0, 320.0, tops[1], power=2.6)
    candelabrum(kit, "EastCandles", 1407.0, 368.0, tops[1], arms=3, spread=5.0, power=3.2, stem=6.0)
    kit.lathe("EastJar", 1407.0, 436.0, [(0.0, tops[2]), (4.6, tops[2]), (5.0, tops[2] + 8.0), (3.2, tops[2] + 12.0),
                                         (3.4, tops[2] + 14.0), (0.0, tops[2] + 14.0)],
              hall._painted("LibraryStoneware", (0.3, 0.26, 0.2)), plan=ROUND)
    lamp_oil(kit, "EastLamp", 1407.0, 560.0, tops[3], power=4.0)
    for layer, (y0, y1) in enumerate(((596.0, 628.0), (598.0, 626.0), (597.0, 627.0))):
        wake.closed_book(kit, "EastStack%d" % layer, 1396.0, 1419.0, y0, y1, tops[3] + layer * 4.6, 4.6,
                         wake.BOOK_COLOURS[(layer + 2) % 8])
    scroll_bundle(kit, 1408.0, 1420.0, 800.0, tops[4], rng)
    for layer, (y0, y1) in enumerate(((752.0, 780.0), (754.0, 778.0))):
        wake.closed_book(kit, "EastShelfBook%d" % layer, 1407.0, 1420.0, y0, y1, tops[4] + layer * 5.0, 5.0,
                         wake.BOOK_COLOURS[layer])
    return kit


def tudor_arch(x0, x1, spring, apex, corner=12.0, steps=6):
    """A door head from (x0, spring) over its point to (x1, spring), as the
    painted doors' heads are: a tight curve off each jamb, then straight up
    to the apex. Points in (x, h)."""
    middle = (x0 + x1) / 2.0
    right = [(x1 - corner + corner * math.cos(math.radians(55.0 * step / steps)),
              spring + corner * math.sin(math.radians(55.0 * step / steps))) for step in range(steps + 1)]
    left = [(2.0 * middle - x, h) for x, h in right]
    return left + [(middle, apex)] + list(reversed(right))


def ashlar(kit, part, x0, x1, h0, h1, face, rng, material, course=13.0):
    """Dressed blocks laid in courses over x0..x1 by h0..h1 on a face at plan
    y `face`, their joints staggered."""
    blocks = []
    h, row = h0, 0
    while h < h1 - 0.5:
        top = min(h + course, h1)
        top = h1 if h1 - top < 6.0 else top
        x = x0 - (rng.uniform(6.0, 16.0) if row % 2 else 0.0)
        while x < x1 - 0.5:
            end = min(x + rng.uniform(20.0, 36.0), x1)
            end = x1 if x1 - end < 10.0 else end
            blocks.append((max(x, x0) + 0.5, end - 0.5, face - 3.0, face + 0.4, h + 0.5, top - 0.5))
            x = end
        h, row = top, row + 1
    return kit.blocks(part, blocks, material, bevel=0.35, uv="box")


def gate():
    """The gatehouse at the corridor's end, as the painting draws it: two
    stout piers with pale caps and, outside them, lower ones; a Library
    banner on a brass rod between each pair; a twin-candle sconce either side
    of the door; slim pilasters carrying a gabled hood with the Library's
    book on it; and under the hood a pair of oak doors in a pointed arch,
    carved and mounted in brass, over a threshold and steps going down
    toward the camera. It stands on its own base, dropping into the dark
    like the wall either side. The player walks up to it from inside the
    room, so it hides no one (no depth): a player at the door shows before
    it, as the painted one does."""
    kit = RP.Kit("Gatehouse", depth=False)
    rng = random.Random(1027)
    face = GATE_FACE
    x0, x1 = GATE_X
    pale = pale_stone("LibraryGatePale")
    dressed = dressed_stone("LibraryGateDressed")
    ashlars = ashlar_stone("LibraryGateAshlar", fade=(GATE_BASE, 0.0))
    steps_stone = dressed_stone("LibraryGateSteps", fade=(-34.0, -2.0))
    joints = joint_material()
    metal, oak_wood = brass(), gate_oak()
    door0, door1 = DOOR_SPAN
    arch = tudor_arch(door0, door1, DOOR_SPRING, DOOR_APEX)
    outer = tudor_arch(door0 - 4.0, door1 + 4.0, DOOR_SPRING, DOOR_APEX + 5.0, corner=14.0)
    half = len(arch) // 2
    # The bed behind the blocks, dark in their joints, open where the doors
    # are and no higher than the outer piers over them.
    opening = [(door0, 0.0)] + arch + [(door1, 0.0)]
    silhouette = [(x0, GATE_BASE - 4.0), (x1, GATE_BASE - 4.0), (x1, 62.0), (x1 - 24.0, 62.0), (x1 - 24.0, 79.0),
                  (x0 + 24.0, 79.0), (x0 + 24.0, 62.0), (x0, 62.0)]
    kit.keep(RP.polygon_mesh("GatehouseBacking", silhouette, [opening], lambda u, v: (u, face - 3.2, v), joints))
    for index, (a, b, top) in enumerate(((527.0, 589.0, 62.0), (622.0, 644.0, 77.0), (770.0, 794.0, 77.0),
                                         (827.0, 889.0, 62.0))):
        ashlar(kit, "Wall%d" % index, a, b, GATE_BASE - 4.0, top, face, rng, ashlars)
        kit.box("WallCoping%d" % index, a - 1.0, b + 1.0, face - 4.0, face + 1.2, top, top + 3.0, pale, bevel=0.5,
                uv="box")
    # The piers: the inner ones stout, their pale caps level with the floor's
    # edge, the outer ones lower, their caps just below it.
    for name, (a, b), deep, top in (("InnerW", (592.0, 619.0), 23.0, 76.0), ("InnerE", (797.0, 824.0), 23.0, 76.0),
                                    ("OuterW", (503.0, 525.0), 19.0, 57.0), ("OuterE", (891.0, 913.0), 19.0, 57.0)):
        kit.box("Pier%sCore" % name, a + 1.0, b - 1.0, face - deep + 1.0, face + 0.8, GATE_BASE - 4.0, top, joints,
                bevel=0.0)
        courses = []
        h = GATE_BASE - 4.0
        while h < top - 0.5:
            upper = min(h + 17.0, top)
            upper = top if top - upper < 6.0 else upper
            courses.append((a, b, face - deep, face + 1.5, h + 0.4, upper - 0.4))
            h = upper
        kit.blocks("Pier%s" % name, courses, ashlars, bevel=0.6, uv="box")
        cap = 6.0 if name.startswith("Inner") else 5.0
        kit.box("Pier%sCap" % name, a - 2.0, b + 2.0, face - deep - 2.0, face + 3.0, top, top + cap, pale, bevel=0.9,
                uv="box")
    # Pilasters either side of the door, carrying the hood.
    for name, (a, b) in (("W", (646.0, 662.0)), ("E", (752.0, 768.0))):
        kit.box("PilasterBase" + name, a - 2.0, b + 2.0, face - 2.0, face + 3.5, 0.0, 4.5, dressed, bevel=0.6,
                uv="box")
        kit.box("Pilaster" + name, a, b, face - 2.0, face + 2.5, 4.5, 72.0, dressed, bevel=0.6, uv="box_up")
        kit.box("PilasterCap" + name, a - 4.0, b + 4.0, face - 2.0, face + 4.0, 72.0, 79.0, pale, bevel=0.8, uv="box")
    # The hood: two raking cornices meeting over the door, the stone under
    # them and round the door's head, the Library's book in brass on it.
    rise = 28.0 / 70.0
    kit.slab("HoodW", [(640.0, 79.0), (707.0, 106.0), (707.0, 100.0), (654.0, 79.0)], face - 3.0, face + 3.5, ashlars,
             bevel=0.5)
    kit.slab("HoodE", [(707.0, 106.0), (774.0, 79.0), (760.0, 79.0), (707.0, 100.0)], face - 3.0, face + 3.5, ashlars,
             bevel=0.5)
    for name, outline in (("W", [(641.0, 79.6), (707.0, 106.4), (707.0, 105.2), (643.0, 79.6)]),
                          ("E", [(707.0, 106.4), (773.0, 79.6), (771.0, 79.6), (707.0, 105.2)])):
        kit.slab("HoodLip" + name, outline, face + 3.4, face + 4.0, pale)
    eave = 79.0 + rise * (door0 - 4.0 - 640.0) - 6.0
    spandrel = [(door0 - 4.0, DOOR_SPRING)] + outer[1:-1] + [(door1 + 4.0, DOOR_SPRING), (door1 + 4.0, eave),
                                                              (707.0, 100.0), (door0 - 4.0, eave)]
    kit.slab("Spandrel", spandrel, face - 3.0, face + 0.2, ashlars)
    for side in (-1.0, 1.0):
        page = [(707.0, 94.5), (707.0 + side * 8.0, 93.0), (707.0 + side * 8.0, 98.5), (707.0, 100.0)]
        kit.slab("Book%d" % int(side), page if side > 0 else list(reversed(page)), face + 0.2, face + 1.0,
                 emblem_brass())
    band = [(door0 - 4.0, 0.0)] + outer + [(door1 + 4.0, 0.0), (door1, 0.0)] + list(reversed(arch)) + [(door0, 0.0)]
    kit.slab("Architrave", band, face - 1.2, face + 1.4, dressed, bevel=0.4)
    # The doors: two oak leaves under the pointed head, framed and panelled,
    # each with a brass ring above and a brass star below, studs along its
    # rails and a pull by the meeting stiles.
    leaf_back, leaf_front = face - 4.0, face - 2.4
    leaves = {
        "W": [(door0, 0.0), (707.0, 0.0), (707.0, DOOR_APEX)] + list(reversed(arch[:half])),
        "E": [(707.0, 0.0), (door1, 0.0)] + list(reversed(arch[half + 1:])) + [(707.0, DOOR_APEX)],
    }
    for name, outline in leaves.items():
        kit.slab("Leaf" + name, outline, leaf_back, leaf_front, oak_wood, bevel=0.3)
    front0, front1 = leaf_front - 0.1, leaf_front + 0.7
    frames = [(door0, door0 + 4.5, front0, front1, 0.0, DOOR_SPRING), (door1 - 4.5, door1, front0, front1, 0.0,
                                                                        DOOR_SPRING),
              (703.0, 711.0, front0, front1 + 0.2, 0.0, DOOR_APEX - 3.0)]
    for h0, h1 in ((0.0, 5.5), (30.0, 34.0)):
        frames.append((door0, door1, front0, front1, h0, h1))
    kit.blocks("DoorFrames", frames, oak_wood, bevel=0.3, uv="box_up")
    head = [(x + (3.0 if x < 707.0 else -3.0 if x > 707.0 else 0.0), h - 4.5) for x, h in arch]
    kit.slab("DoorHead", arch + list(reversed(head)), leaf_front - 0.1, leaf_front + 0.7, oak_wood, bevel=0.2)
    for x in (687.0, 727.0):
        emblem(kit, "DoorRing%d" % int(x), "ring", x, leaf_front, 51.0, 6.5)
        emblem(kit, "DoorStar%d" % int(x), "compass", x, leaf_front, 18.5, 6.0)
    handle = polished_brass()
    for x in (703.6, 710.4):
        kit.box("PullPlate%d" % int(x), x - 1.4, x + 1.4, leaf_front + 0.6, leaf_front + 1.1, 28.0, 46.0, handle,
                bevel=0.3)
        kit.rod("Pull%d" % int(x), (x, leaf_front + 1.9, 30.5), (x, leaf_front + 1.9, 43.5), 0.8, handle)
    studs = iron()
    for h in (2.7, 32.0):
        for x in [671.0 + 7.0 * k for k in range(5)] + [714.0 + 7.0 * k for k in range(5)]:
            kit.ball("Stud", x, leaf_front + 0.9, h, 0.75, studs, plan=0.6, segments=10)
    # The threshold and the steps down toward the camera, into the dark.
    kit.box("Threshold", door0 - 4.0, door1 + 4.0, face - 4.0, face + 3.0, -6.0, 1.4, dressed, bevel=0.6,
            uv="box")
    front = face + 3.0
    for step, (deep, drop, widen) in enumerate(((10.0, -8.0, 10.0), (9.0, -17.0, 20.0), (9.0, -26.0, 30.0)), 1):
        kit.box("Step%d" % step, door0 - 4.0 - widen, door1 + 4.0 + widen, front, front + deep, GATE_BASE - 12.0,
                drop, steps_stone, bevel=0.6, uv="box")
        front += deep
    for name, (a, b) in (("W", (x0 - 3.0, 642.0)), ("E", (772.0, x1 + 3.0))):
        kit.box("Base" + name, a, b, face - 2.0, face + 5.0, GATE_BASE - 4.0, -13.0, ashlars, bevel=0.6, uv="box")
    # A Library banner between each pair of piers, on a brass rod.
    cloth = banner_material("LibraryGateBanner")
    for name, (a, b) in (("W", (537.0, 570.0)), ("E", (846.0, 879.0))):
        kit.quad("Banner" + name, [(a, face + 1.2, -10.0), (b, face + 1.2, -10.0), (b, face + 1.2, 67.0),
                                   (a, face + 1.2, 67.0)], cloth)
        kit.rod("BannerRod" + name, (a - 6.0, face + 2.2, 68.5), (b + 6.0, face + 2.2, 68.5), 0.9, metal)
        for x in (a - 6.0, b + 6.0):
            kit.ball("BannerFinial" + name, x, face + 2.2, 68.5, 1.6, metal, plan=0.7)
        for x in (a + 1.5, b - 1.5):
            kit.box("BannerBracket" + name, x - 1.2, x + 1.2, face + 0.4, face + 2.6, 66.0, 71.0, metal, bevel=0.3)
    # A sconce of two candles either side of the door, lighting it warmly.
    for name, x in (("W", 633.0), ("E", 782.0)):
        kit.box("SconcePlate" + name, x - 3.4, x + 3.4, face + 0.4, face + 1.6, 18.0, 31.0, metal, bevel=0.5)
        kit.rod("SconceArm" + name, (x, face + 1.2, 23.0), (x, face + 7.0, 33.5), 0.8, metal)
        kit.lathe("SconcePan" + name, x, face + 7.5, [(0.0, 33.0), (2.0, 33.0), (5.8, 35.2), (6.0, 36.4), (0.0, 36.4)],
                  metal, plan=ROUND)
        kit.candle("SconceTall" + name, x - 2.6, face + 7.5, 36.4, height=19.0, radius=2.0, power=3.8 * WARMTH)
        kit.candle("SconceShort" + name, x + 2.8, face + 8.0, 36.4, height=14.0, radius=1.9, power=3.2 * WARMTH)
        kit.light("SconceWash" + name, x, face + 6.0, 36.0, (1.0, 0.55, 0.22), 1.6 * WARMTH, radius=0.15,
                  mirrored=False)
    return kit


# ---------------------------------------------------------------- light


def warm_fill():
    """The glow of the archive's many flames where no one flame reaches, as the
    painted room has it: broad, soft and warm, from high over its aisles. It
    shows in no reflection, so it lights without a source of its own."""
    kit = RP.Kit("WarmFill", depth=False)
    for x, y, power in ((430.0, 620.0, 75.0), (1050.0, 620.0, 75.0), (724.0, 800.0, 55.0), (230.0, 320.0, 50.0),
                        (1240.0, 330.0, 50.0), (724.0, 340.0, 40.0)):
        kit.light("Fill", x, y, 260.0, (1.0, 0.7, 0.45), power, radius=1.2, mirrored=False)
    return kit


def moonlight():
    """The Hall's moonlight (its colour, strength and softness) from the
    south-west, as the Wake Room has it, and the moon in the north that
    reaches the room through the windows alone (the parapet stops the rest)."""
    data = bpy.data.lights.new("LibraryMoonSky", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sky = RP._link(bpy.data.objects.new("LibraryMoonSky", data))
    sky.rotation_euler = Vector((0.12, 0.38, -0.92)).normalized().to_track_quat("-Z", "Y").to_euler()
    ray = moon_ray()
    direction = (RP.world(ray.x, ray.y, ray.z) - RP.world(0.0, 0.0, 0.0)).normalized()
    data = bpy.data.lights.new("LibraryWindowMoon", "SUN")
    data.energy = 5.5
    data.color = (0.82, 0.88, 1.0)
    data.angle = math.radians(1.2)
    window = RP._link(bpy.data.objects.new("LibraryWindowMoon", data))
    window.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def schematic_on_wall():
    """The awakened archive's diagram round the spectrum window."""
    kit = RP.Kit("Schematic", depth=False)
    x0, x1 = SPECTRUM_WINDOW
    centre = (x0 + x1) / 2.0
    rose = SPECTRUM_SPRING + 20.0
    material = schematic_material(1.0, 1.0, centre, rose)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    # Not over the window itself.
    op = hall._MathBuilder(nodes, links)
    _coords, u, v = hall._uv_parts(nodes, links)
    half = (x1 - x0) / 2.0 + 4.0
    du = op("SUBTRACT", u, centre)
    dv = op("SUBTRACT", v, SPECTRUM_SPRING)
    in_head = op("LESS_THAN", op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))), half)
    in_lights = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", du), half), op("LESS_THAN", v, SPECTRUM_SPRING))
    window = op("MAXIMUM", in_head, in_lights)
    mix = next(node for node in nodes if node.type == "MIX_SHADER")
    keep = op("MULTIPLY", mix.inputs["Fac"].links[0].from_socket, op("SUBTRACT", 1.0, window))
    links.new(keep, mix.inputs["Fac"])
    face = BACK_Y + 0.8
    kit.quad("Diagram", [(centre - 140.0, face, 18.0), (centre + 140.0, face, 18.0),
                         (centre + 140.0, face, WALL_H - 4.0),
                         (centre - 140.0, face, WALL_H - 4.0)], material,
             uvs=((centre - 140.0, 18.0), (centre + 140.0, 18.0), (centre + 140.0, WALL_H - 4.0),
                  (centre - 140.0, WALL_H - 4.0)))
    return kit


def awakening():
    """The archive once its three filters are seated: pale light from the
    optical array, its hidden writing on the floor running from the
    medallion to the three stations, and its diagram round the window."""
    kit = RP.Kit("Awakening", depth=False)
    kit.light("ArrayLight", 724.0, 664.0, 40.0, (1.0, 0.97, 0.92), 160.0, radius=0.25)
    kit.light("ArrayWash", 724.0, 560.0, 260.0, (0.96, 0.95, 1.0), 650.0, radius=1.4, mirrored=False)
    RP.glow("crystal", SCANNER[0], SCANNER[1], SCANNER[2], (1.0, 0.97, 0.9), 60.0)
    cx, cy, radius = MOSAIC
    targets = {"red": (724.0, 690.0), "green": (1229.0, 690.0), "blue": (155.0, 473.0)}
    for name, (tx, ty) in targets.items():
        start, end = Vector((cx, cy)), Vector((tx, ty))
        direction = (end - start).normalized()
        a, b = start + direction * radius * 0.99, end
        length = (b - a).length
        normal = Vector((-direction.y, direction.x)) * 4.5
        corners = [a - normal, b - normal, b + normal, a + normal]
        kit.quad("Line" + name.title(), [(point.x, point.y, RUG_H + 0.3) for point in corners],
                 glyph_line_material("LibraryLine" + name.title(), STATION[name], length),
                 uvs=((0.0, -1.0), (length, -1.0), (length, 1.0), (0.0, 1.0)))
        RP.glow("crystal", tx, ty, 2.0, STATION[name], 30.0)
    for angle, name in ((90.0, "red"), (330.0, "green"), (210.0, "blue")):
        x = cx + 0.27 * radius * math.cos(math.radians(angle))
        y = cy - 0.27 * radius * math.sin(math.radians(angle))
        RP.glow("crystal", x, y, 1.0, STATION[name], 46.0)
    RP.glow("crystal", cx, cy, 1.0, (1.0, 1.0, 1.0), 30.0)
    schematic_on_wall()
    return kit


def write_meta():
    """The preview's living light: where each window's moonlight falls, the
    station lamps, the optical array and the medallion, in screen px."""
    cx, cy, radius = MOSAIC
    meta = {
        "generator": "tools/blender/room_library.py",
        "scanner": screen(*SCANNER),
        "lenses": [screen(x, CONSOLE_Y, CONSOLE_H) for x in LENS_X],
        "lamps": LAMPS,
        "medallion": {"x": cx, "y": cy, "radius": radius},
        "shafts": resolve_shafts(),
    }
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, "render-library.json"), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=1)


def grade(scene):
    """The room's exposure and white balance, set after the shared Cycles
    setup: as dark and as warm as the painted archive (by the room standard,
    mean luminance and warmth within about 15 % of its painting's)."""
    scene.view_settings.exposure = LIBRARY_EXPOSURE + (AWAKENED_LIFT if AWAKENED else 0.0)
    scene.view_settings.use_white_balance = True
    scene.view_settings.white_balance_temperature = LIBRARY_WHITE_BALANCE


def build(rp, layout):
    global RP
    RP = rp
    wake.RP = rp
    chem.RP = rp
    SHAFTS.clear()
    LAMPS.clear()
    rects = collision_rects()
    missing = sorted(set(PIECES) - set(rects))
    if missing:
        raise SystemExit("Library pieces without a collision in the scene: " + ", ".join(missing))
    listed = set(layout.get("prop_info", {}))
    if listed and listed != set(PIECES):
        print("LIBRARY WARNING: layout lists %s, the room models %s" % (sorted(listed), sorted(PIECES)))
    textured = rp.TEXTURES.available()
    shell_materials = {
        "floor": joint_material(),
        "wall": rp.textured("LibraryWall", "castle_wall_slates", 1.5, 0.54, (0.72, 0.66, 0.78), ao=0.3),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if textured
                else rp.textured("LibraryCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if textured
                else rp.textured("LibraryLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("LibraryReveal", "castle_wall_slates", 1.5, 0.6, (0.74, 0.68, 0.8), ao=0.2),
    }
    shell = library_shell(shell_materials)
    shell.build()
    parapet()
    windows()
    flagstones()
    cobbles()
    floor_dressing()
    optical_array()
    galleries()
    bay()
    north_dressing()
    side_dressing(shell)
    gate()
    moonlight()
    warm_fill()
    if AWAKENED:
        awakening()
    pieces = {}
    for name, builder in PIECES.items():
        kit = piece(name)
        builder(kit, *rects[name])
        pieces[name] = kit
    write_meta()
    print("LIBRARY built (%s): %d objects, %d glows" % ("awakened" if AWAKENED else "dormant", len(bpy.data.objects),
                                                       len(rp.GLOWS)))
    # The awakened run renders no props: the preview takes their prompt boxes
    # from the dormant run. LIBRARY_ROOM_ONLY skips them for a quick look.
    if AWAKENED or os.environ.get("LIBRARY_ROOM_ONLY"):
        return {"props": {}}
    return {"props": pieces, "roots": {name: "Worldsort/" + name for name in pieces}, "in_room": list(pieces)}
