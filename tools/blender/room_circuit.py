"""The Circuit Room, the castle's electrical workshop, for the Blender room
prototype. tools/blender/room_prototype.py imports it as room_circuit and calls
build() on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). The room is 1448 x
1086 and the game's camera follows the player through it, so the render is the
whole room at 2 px per game px. Everything stands where the painted workshop
(assets/backgrounds/circuit_room_workshop.png) has it. The player walks over
all open floor, so only flat things lie there (grates, pipes, stains, the
runner); everything that stands up stands on floor the collision blocks:

  north   the switchboard along the back wall: feeder switches, regulator,
          resistor coils, a fuse bank and the burnt bus section, arcing where
          the game's BROKEN_BUS_POSITION expects it; the maintenance door left
          ajar under the Circuit emblem; the castle's banners
  west    the equipment cabinet (Worldsort/Cabinet): a padlocked locker door
          beside a fixed switchgear panel and its loose access panel
  middle  the oak workbench (Worldsort/Workbench): its shadow board with one
          tool missing, the diagnostic console, the journal, the glove and
          the oil lantern
  east    the dynamo (Worldsort/Generator): flywheel, field magnets, armature
          and commutator, the regulator housing and the arc chamber
  sides   moonlit lancet windows, caged bulb lamps
  south   the low wall and the doorway out to the Hall between two piers

The three junction plates (scripts/circuit_layout.gd) are drawn by the game
over flush covers left exactly where each plate goes, so a surveyed plate sits
on the housing that hid it. The game's own light rig (wall lamps, bench
lantern, chamber glow and both arc emitters) is carried onto these fixtures by
the preview: build() lists each move as render.json "fixtures".
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

import hall_prototype as hall

RP = None

BACK_Y = 214.0
WALL_H = 184.0
SOUTH_Y = 970.0
DOOR_GAP = (635.0, 762.0)
PIER_H = 58.0
# The switchboard stands on the collision's slanted front, (230, 262) to (1071, 276).
BOARD_X = (229.0, 1072.0)
BOARD_FRONT = ((230.0, 262.0), (1071.0, 276.0))
PANEL_INSET = 12.0
# The maintenance door's arched opening in the back wall.
HATCH_X = (1110.0, 1214.0)
HATCH_SPRING = 96.0
WINDOW_Y = 605.0
SIN = math.sin(math.radians(hall.ALPHA_DEGREES))
# A lathe's plan squash for a true circle, so turned brass is round in 3D.
ROUND = math.cos(math.radians(hall.ALPHA_DEGREES))
BULB = (1.0, 0.52, 0.2)
WARM = (1.0, 0.62, 0.3)
ARC = (0.55, 0.82, 1.0)
VIOLET = (0.62, 0.36, 1.0)
MOON = (0.55, 0.68, 1.0)
EXIT_BLUE = (0.5, 0.78, 1.0)
# Brown-out: the bulbs glow low until the master switch feeds the building.
LAMP_POWER = 34.0


def hatch_outline():
    x0, x1 = HATCH_X
    radius = (x1 - x0) / 2.0
    centre = (x0 + x1) / 2.0
    arc = [(centre + radius * math.cos(math.radians(angle)), HATCH_SPRING + radius * math.sin(math.radians(angle)))
           for angle in range(0, 181, 9)]
    # A sliver above the floor: an opening may not touch the wall's own edge.
    return [(x0, 0.4), (x1, 0.4)] + arc


SPEC = {
    "back": {"y": BACK_Y, "base": (71.0, 1373.0), "top": (6.0, 1442.0), "height": WALL_H,
             "openings": [{"outline": hatch_outline()}]},
    "left": {"base": ((71.0, BACK_Y), (71.0, SOUTH_Y)), "near": 1300.0},
    "right": {"base": ((1373.0, BACK_Y), (1393.0, SOUTH_Y)), "near": 1300.0},
    "south": {"y": SOUTH_Y, "height": 26.0, "depth": 124.0, "openings": [DOOR_GAP]},
    "floor": {"x": (-60.0, 1510.0), "y": (150.0, 1130.0)},
    "cap": 40.0,
}


# ---------------------------------------------------------------- geometry


def board_front(x):
    """The switchboard's front edge on the floor at x: the collision's line."""
    (x0, y0), (x1, y1) = BOARD_FRONT
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def circle(cx, ch, radius, segments=32, start=0.0):
    return [(cx + radius * math.cos(start + 2.0 * math.pi * index / segments),
             ch + radius * math.sin(start + 2.0 * math.pi * index / segments)) for index in range(segments)]


def uv_box(obj, mode="box"):
    RP.project_uvs(obj, mode)
    return obj


def face_disc(kit, part, cx, front, ch, radius, thick, material, segments=32, bevel=0.4):
    """A disc facing the camera, round on screen as the Hall's dials are: its
    face in (x, h) on plan y `front`, `thick` plan px deep behind it."""
    return kit.slab(part, circle(cx, ch, radius, segments), front - thick, front, material, bevel=bevel)


def face_dial(kit, part, cx, y, ch, radius, material, segments=40):
    """A flat disc facing the camera with UVs 0..1 across it: a dial's face."""
    shape = bmesh.new()
    layer = shape.loops.layers.uv.verify()
    centre = shape.verts.new((cx, y, ch))
    rim = [shape.verts.new((cx + radius * math.cos(2.0 * math.pi * index / segments), y,
                            ch + radius * math.sin(2.0 * math.pi * index / segments))) for index in range(segments)]
    for index in range(segments):
        face = shape.faces.new((centre, rim[index], rim[(index + 1) % segments]))
        for loop in face.loops:
            point = loop.vert.co
            loop[layer].uv = (0.5 + (point.x - cx) / (2.0 * radius), 0.5 + (point.z - ch) / (2.0 * radius))
    return kit.keep(RP.mesh_from(kit.name + part, shape, material, facing=RP.TOWARD_CAMERA))


def face_ring(kit, part, cx, y, ch, radius, tube, material, segments=48, sides=10):
    """A torus facing the camera, round on screen: a bezel, a rim, a coil."""
    shape = bmesh.new()
    rings = []
    for index in range(segments):
        turn = 2.0 * math.pi * index / segments
        ring = []
        for side in range(sides):
            bend = 2.0 * math.pi * side / sides
            reach = radius + tube * math.cos(bend)
            ring.append(shape.verts.new((cx + reach * math.cos(turn), y + tube * math.sin(bend),
                                         ch + reach * math.sin(turn))))
        rings.append(ring)
    for index in range(segments):
        here, there = rings[index], rings[(index + 1) % segments]
        for side in range(sides):
            following = (side + 1) % sides
            shape.faces.new((here[side], there[side], there[following], here[following]))
    return kit.shape(part, shape, material, smooth=True, sharp_angle=80.0)


def face_gear(kit, part, cx, front, ch, radius, thick, teeth, material, phase=0.0):
    """A cog facing the camera, round on screen."""
    outline = []
    for index in range(teeth * 4):
        turn = phase + 2.0 * math.pi * index / (teeth * 4)
        reach = radius if index % 4 in (1, 2) else radius * 0.86
        outline.append((cx + reach * math.cos(turn), ch + reach * math.sin(turn)))
    return kit.slab(part, outline, front - thick, front, material)


def cable(kit, part, points, radius, material, resolution=10):
    """A lead or a cable through game points (x, y, h), smoothly between them."""
    curve = bpy.data.curves.new(kit.name + part, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius * RP.PX
    curve.bevel_resolution = 3
    curve.resolution_u = resolution
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, (x, y, h) in zip(spline.bezier_points, points):
        point.co = RP.world(x, y, h)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    curve.materials.append(material)
    return kit.keep(RP._link(bpy.data.objects.new(kit.name + part, curve)))


def plate(kit, part, corners, back, fronts, material):
    """A plate through four (x, h) corners from plan y `back` to each corner's
    own front plan y: a panel that sits askew or lifts at one corner."""
    shape = bmesh.new()
    rear = [shape.verts.new((x, back, h)) for x, h in corners]
    face = [shape.verts.new((x, front, h)) for (x, h), front in zip(corners, fronts)]
    shape.faces.new(rear)
    shape.faces.new(list(reversed(face)))
    for index in range(4):
        following = (index + 1) % 4
        shape.faces.new((rear[index], rear[following], face[following], face[index]))
    return uv_box(kit.shape(part, shape, material, bevel=0.4))


def lying_pipe(kit, part, path, radius, material, strap_material, strap_every=72.0):
    """A pipe lying on the floor through plan points, elbowed at each turn,
    coupled by flanged collars and strapped down along its runs."""
    lift = radius * SIN
    for index, ((x0, y0), (x1, y1)) in enumerate(zip(path[:-1], path[1:])):
        kit.rod("%sRun%d" % (part, index), (x0, y0, lift), (x1, y1, lift), radius, material)
        length = math.hypot(x1 - x0, y1 - y0)
        ux, uy = (x1 - x0) / length, (y1 - y0) / length
        straps = int(length // strap_every)
        for strap in range(1, straps + 1):
            t = strap / (straps + 1.0)
            sx, sy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if strap % 2:
                kit.rod("%sCollar%d_%d" % (part, index, strap), (sx - ux * 2.6, sy - uy * 2.6, lift),
                        (sx + ux * 2.6, sy + uy * 2.6, lift), radius * 1.32, strap_material)
                continue
            if abs(x1 - x0) >= abs(y1 - y0):
                box = (sx - 1.8, sx + 1.8, sy - radius - 1.4, sy + radius + 1.4)
            else:
                box = (sx - radius - 1.4, sx + radius + 1.4, sy - 1.8, sy + 1.8)
            kit.box("%sStrap%d_%d" % (part, index, strap), *box, 0.0, lift * 2.0 + 0.5, strap_material, bevel=0.3)
    for index, (x, y) in enumerate(path[1:-1]):
        kit.ball("%sElbow%d" % (part, index), x, y, lift, radius * 1.3, material, plan=ROUND, squash=SIN)


# ---------------------------------------------------------------- materials


def _set(material, **values):
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            for key, value in values.items():
                node.inputs[key.replace("_", " ")].default_value = value
    return material


def oak():
    """Worn, waxed oak, warm as the Wake Room's furniture: the workbench."""
    return RP.textured("CircuitOak", "wood_table_worn", 0.42, 1.0, (0.96, 0.8, 0.64), saturation=0.92, ao=0.25)


def planks():
    return RP.textured("CircuitPlanks", "wood_cabinet_worn_long", 0.6, 0.8, (0.92, 0.76, 0.62), saturation=0.9,
                       ao=0.25)


def green_iron():
    """Enamelled iron gone dark with oil and age, bottle green under the
    grime: the cabinet, the console and the dynamo's housings."""
    return RP.textured("CircuitGreenIron", "green_metal_rust", 0.45, 0.72, (0.62, 0.76, 0.72), saturation=0.42,
                       ao=0.25)


def dark_plate():
    """Worn dark steel plate, its seams and scratches: plinths, frames, bedplate."""
    return _set(RP.textured("CircuitPlate", "metal_plate_02", 0.5, 0.95, (0.82, 0.8, 0.88), saturation=0.45,
                            ao=0.25), Metallic=0.55)


def slate():
    """Polished blue-grey slate, as old switchboards were panelled."""
    return RP.textured("CircuitSlate", "slate_floor", 0.8, 1.05, (0.66, 0.68, 0.78), saturation=0.3, ao=0.15)


def stone():
    return RP.textured("CircuitStone", "large_grey_tiles", 0.5, 0.66, (0.74, 0.7, 0.82), saturation=0.55, ao=0.15)


def flagstones():
    """Castle flagstones of every size laid in courses (CC0 `rock_tile_floor`),
    graded into the castle's dark violet grey, with a slow patchiness so no two
    stretches of floor read alike."""
    if RP.TEXTURES is None or not os.path.exists(RP.TEXTURES._path("rock_tile_floor", "diff")):
        return RP.textured("CircuitFloor", "large_floor_tiles_02", 1.6, 0.64, (0.74, 0.7, 0.8), ao=0.25)

    def build(nodes, links):
        maps = RP.TEXTURES.sample(nodes, links, "rock_tile_floor", repeat=2.1)
        color = hall._grade(nodes, links, maps["diff"], 0.6, (0.72, 0.69, 0.8), saturation=0.5)
        coords = nodes.new("ShaderNodeTexCoord")
        patches = hall._ramp(nodes, links, hall._noise(nodes, links, coords.outputs["Object"], scale=0.32, detail=3.0),
                             0.32, 0.68)
        darker = hall._mix(nodes, links, 1.0, color, (0.7, 0.68, 0.72), blend="MULTIPLY")
        color = hall._mix(nodes, links, patches, color, darker)
        color = hall._ao_multiply(nodes, links, color, distance=0.25, floor_value=0.4)
        hall._principled(nodes, links, color, roughness=maps["rough"], normal=maps["normal"])
    return hall._material("CircuitFlagstones", build)


def porcelain():
    return hall._material("CircuitPorcelain", lambda nodes, links: hall._principled(
        nodes, links, (0.8, 0.76, 0.68), roughness=0.16))


def glazed_insulator():
    """Brown-glazed stoneware, the colour of old insulators."""
    return hall._material("CircuitInsulator", lambda nodes, links: hall._principled(
        nodes, links, (0.26, 0.11, 0.05), roughness=0.12))


def rubber():
    return hall._material("CircuitRubber", lambda nodes, links: hall._principled(
        nodes, links, (0.02, 0.018, 0.02), roughness=0.55))


def red_grip():
    return hall._material("CircuitRedGrip", lambda nodes, links: hall._principled(
        nodes, links, (0.32, 0.04, 0.03), roughness=0.5))


def enamel():
    return hall._material("CircuitEnamel", lambda nodes, links: hall._principled(
        nodes, links, (0.05, 0.12, 0.08), roughness=0.3))


def bulb_glass():
    return hall._glow_material("CircuitBulbGlass", BULB, 6.0, (0.9, 0.6, 0.35))


def arc_glow():
    return hall._glow_material("CircuitArc", ARC, 16.0, (0.8, 0.92, 1.0))


def ember():
    return hall._glow_material("CircuitEmber", (1.0, 0.36, 0.08), 5.0, (0.3, 0.08, 0.02))


def core_glow():
    return hall._glow_material("CircuitCore", (0.55, 0.3, 1.0), 1.1, (0.24, 0.1, 0.5))


def emblem_glow():
    return hall._glow_material("CircuitEmblem", EXIT_BLUE, 1.6, (0.55, 0.7, 0.85))


def clear_glass():
    def build(nodes, links):
        shader = hall._principled(nodes, links, (0.86, 0.9, 0.95), roughness=0.04)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.1
    return hall._material("CircuitGlass", build)


def smoked_glass():
    """A blown fuse: its glass blackened from inside."""
    return hall._material("CircuitSmokedGlass", lambda nodes, links: hall._principled(
        nodes, links, (0.03, 0.025, 0.025), roughness=0.2))


def dead_red_glass():
    return hall._material("CircuitPilotGlass", lambda nodes, links: hall._principled(
        nodes, links, (0.22, 0.02, 0.02), roughness=0.08))


def winding():
    """Copper wire wound in close turns, dark lacquer between them."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        bands = nodes.new("ShaderNodeTexWave")
        bands.wave_type = "BANDS"
        bands.bands_direction = "Z"
        bands.inputs["Scale"].default_value = 9.0
        bands.inputs["Distortion"].default_value = 0.0
        links.new(coords.outputs["Object"], bands.inputs["Vector"])
        color = hall._mix(nodes, links, bands.outputs["Fac"], (0.24, 0.08, 0.03), (0.66, 0.34, 0.15))
        hall._principled(nodes, links, color, roughness=0.32, metallic=1.0,
                         normal=hall._bump(nodes, links, bands.outputs["Fac"], 0.35))
    return hall._material("CircuitWinding", build)


def braid(name, color):
    """Cloth-braided cable: a fine diagonal weave."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        weave = nodes.new("ShaderNodeTexWave")
        weave.wave_type = "BANDS"
        weave.bands_direction = "DIAGONAL"
        weave.inputs["Scale"].default_value = 30.0
        links.new(coords.outputs["Object"], weave.inputs["Vector"])
        hall._principled(nodes, links, hall._mix(nodes, links, weave.outputs["Fac"], tuple(c * 0.55 for c in color),
                                                 color), roughness=0.85,
                         normal=hall._bump(nodes, links, weave.outputs["Fac"], 0.25))
    return hall._material(name, build)


def violet_weave():
    """The castle's violet insulating weave (cable wraps, the glove's cuff)."""
    return braid("CircuitVioletWeave", (0.3, 0.12, 0.5))


def leather(name, color):
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=90.0, detail=4.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, color, tuple(c * 0.62 for c in color)),
                         roughness=0.55)
    return hall._material(name, build)


def parchment():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        stain = hall._noise(nodes, links, coords.outputs["Object"], scale=14.0, detail=5.0)
        hall._principled(nodes, links, hall._mix(nodes, links, stain, (0.46, 0.37, 0.23), (0.7, 0.6, 0.42)),
                         roughness=0.86)
    return hall._material("CircuitParchment", build)


def journal_pages():
    """Two pages of wiring notes in brown ink, an oil smudge on the right one.
    UVs 0..1 across the open spread."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        stain = hall._noise(nodes, links, coords.outputs["UV"], scale=5.0, detail=5.0)
        words = hall._noise(nodes, links, coords.outputs["UV"], scale=34.0, detail=1.0)
        row = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", v, 11.0)), 0.5))
        page = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("MULTIPLY", u, 2.0)), 0.5))
        inside = op("MULTIPLY", op("LESS_THAN", page, 0.38), op.between(v, 0.1, 0.9))
        ink = op("MULTIPLY", op("MULTIPLY", op("LESS_THAN", row, 0.13), op("GREATER_THAN", words, 0.44)), inside)
        # A small circuit sketched on the left page: a box and its leads.
        sketch = op("MULTIPLY", op.between(u, 0.12, 0.36), op.between(v, 0.52, 0.8))
        frame = op("SUBTRACT", sketch, op("MULTIPLY", op.between(u, 0.14, 0.34), op.between(v, 0.55, 0.77)))
        color = hall._mix(nodes, links, stain, (0.52, 0.42, 0.27), (0.76, 0.66, 0.48))
        fold = op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", u, 0.5)), 0.03)
        color = hall._mix(nodes, links, op("MULTIPLY", fold, 0.55), color, (0.18, 0.12, 0.07))
        color = hall._mix(nodes, links, op("MAXIMUM", ink, op("MAXIMUM", frame, 0.0)), color, (0.12, 0.07, 0.05))
        smudge_u, smudge_v = op("SUBTRACT", u, 0.72), op("MULTIPLY", op("SUBTRACT", v, 0.36), 1.4)
        smudge = hall._ramp(nodes, links, op("ADD", op("SQRT", op("ADD", op("MULTIPLY", smudge_u, smudge_u),
                                                                        op("MULTIPLY", smudge_v, smudge_v))),
                                                     op("MULTIPLY", op("SUBTRACT", stain, 0.5), 0.12)), 0.17, 0.08)
        color = hall._mix(nodes, links, op("MULTIPLY", smudge, 0.8), color, (0.06, 0.045, 0.035))
        hall._principled(nodes, links, color, roughness=op("SUBTRACT", 0.86, op("MULTIPLY", smudge, 0.6)))
    return hall._material("CircuitJournalPages", build)


def lancet_glass(name):
    """Diamond-leaded panes lit by the night sky; UVs are px across (u) and up (v)."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        a = op("DIVIDE", op("ADD", u, op("MULTIPLY", v, 0.6)), 11.0)
        b = op("DIVIDE", op("SUBTRACT", u, op("MULTIPLY", v, 0.6)), 11.0)
        lead = op("MAXIMUM", op("GREATER_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", a), 0.5)), 0.43),
                  op("GREATER_THAN", op("ABSOLUTE", op("SUBTRACT", op("FRACT", b), 0.5)), 0.43))
        pane = nodes.new("ShaderNodeTexVoronoi")
        pane.inputs["Scale"].default_value = 0.09
        links.new(coords.outputs["UV"], pane.inputs["Vector"])
        sky = op("ADD", 0.35, op("MULTIPLY", op("DIVIDE", v, 160.0), 0.75))
        tint = hall._mix(nodes, links, pane.outputs["Distance"], (0.14, 0.26, 0.58), (0.3, 0.5, 0.86))
        hall._principled(nodes, links, (0.02, 0.02, 0.03), roughness=0.25, emission=tint,
                         emission_strength=op("MULTIPLY", op("MULTIPLY", sky, op("SUBTRACT", 1.0, lead)), 1.25))
    return hall._material(name, build)


def runner(width):
    """The castle's purple runner: gold border, a chain of lozenges, worn
    along its middle. UVs are px: u along it, v across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        border = op("MAXIMUM", op("LESS_THAN", to_side, 6.5), op.between(to_side, 8.5, 10.0))
        across = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0 - 12.0)
        along = op("MULTIPLY", op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", u, 56.0)), 0.5)), 2.0)
        lozenge = op("ADD", across, along)
        motif = op("MAXIMUM", op.between(lozenge, 0.62, 0.7), op("LESS_THAN", lozenge, 0.16))
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=0.7, detail=6.0)
        wear = hall._ramp(nodes, links, op("ADD", weave, op("MULTIPLY", op("SUBTRACT", 0.45, across), 0.4)), 0.6,
                          0.95)
        color = hall._mix(nodes, links, op("MULTIPLY", motif, op("GREATER_THAN", to_side, 11.0)),
                          (0.1, 0.035, 0.15), (0.2, 0.07, 0.27))
        color = hall._mix(nodes, links, border, color, (0.42, 0.3, 0.1))
        color = hall._mix(nodes, links, op("MULTIPLY", wear, 0.4), color, (0.3, 0.26, 0.24))
        roughness, normal = 0.95, None
        if RP.TEXTURES is not None and RP.TEXTURES.available():
            pile = RP.TEXTURES.sample(nodes, links, "dirty_carpet", repeat=40.0)
            fibres = hall._grade(nodes, links, pile["diff"], 2.6, (1.0, 1.0, 1.0), saturation=0.0)
            color = hall._mix(nodes, links, 0.55, color, hall._mix(nodes, links, 1.0, color, fibres,
                                                                    blend="MULTIPLY"))
            roughness, normal = pile["rough"], pile["normal"]
        hall._principled(nodes, links, color, roughness=roughness, normal=normal)
    return hall._material("CircuitRunner", build)


def smudge(name, color, gloss, strength, scale=4.0):
    """A soft-edged stain on its quad's 0..1 UVs: soot, an oil patch."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        du = op("MULTIPLY", op("SUBTRACT", u, 0.5), 2.0)
        dv = op("MULTIPLY", op("SUBTRACT", v, 0.5), 2.0)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        cloud = hall._noise(nodes, links, coords.outputs["UV"], scale=scale, detail=6.0)
        body = op("SUBTRACT", 1.0, op("ADD", radius, op("MULTIPLY", op("SUBTRACT", cloud, 0.5), 0.9)))
        density = op("MINIMUM", op("MULTIPLY", op("MAXIMUM", body, 0.0), strength), 1.0)
        shader = hall._principled(nodes, links, color, roughness=gloss)
        hall._alpha_cut(nodes, links, shader, density)
    return hall._material(name, build)


def bootprint():
    """A dusty boot sole on its quad's 0..1 UVs, toe toward v = 1."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        su, sv = op("DIVIDE", op("SUBTRACT", u, 0.5), 0.44), op("DIVIDE", op("SUBTRACT", v, 0.66), 0.32)
        sole = op("LESS_THAN", op("ADD", op("MULTIPLY", su, su), op("MULTIPLY", sv, sv)), 1.0)
        hu, hv = op("DIVIDE", op("SUBTRACT", u, 0.5), 0.36), op("DIVIDE", op("SUBTRACT", v, 0.17), 0.14)
        heel = op("LESS_THAN", op("ADD", op("MULTIPLY", hu, hu), op("MULTIPLY", hv, hv)), 1.0)
        grit = hall._noise(nodes, links, coords.outputs["UV"], scale=16.0, detail=3.0)
        mark = op("MULTIPLY", op("MAXIMUM", sole, heel), op("GREATER_THAN", grit, 0.4))
        shader = hall._principled(nodes, links, (0.3, 0.29, 0.31), roughness=0.95)
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", mark, 0.26))
    return hall._material("CircuitBootprint", build)


def pegboard():
    """Hardboard drilled every 9 px; UVs are px across and up it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        across = op("SUBTRACT", op("FRACT", op("DIVIDE", u, 9.0)), 0.5)
        up = op("SUBTRACT", op("FRACT", op("DIVIDE", v, 9.0)), 0.5)
        hole = op("LESS_THAN", op("ADD", op("MULTIPLY", across, across), op("MULTIPLY", up, up)), 0.03)
        board = hall._noise(nodes, links, coords.outputs["UV"], scale=0.05, detail=4.0)
        color = hall._mix(nodes, links, board, (0.035, 0.05, 0.042), (0.06, 0.08, 0.068))
        hall._principled(nodes, links, hall._mix(nodes, links, hole, color, (0.015, 0.01, 0.008)), roughness=0.85)
    return hall._material("CircuitPegboard", build)


def paint_lines(name, segments, width, color=(0.6, 0.55, 0.42), alpha=1.0, grain=0.0):
    """Paint along line segments in a quad's 0..1 UVs, `width` wide: a tool's
    outline on a shadow board, a chalk drawing (`grain` breaks it up)."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        paint = None
        for (ax, ay), (bx, by) in segments:
            dx, dy = bx - ax, by - ay
            reach = op("DIVIDE", op("ADD", op("MULTIPLY", op("SUBTRACT", u, ax), dx),
                                    op("MULTIPLY", op("SUBTRACT", v, ay), dy)), dx * dx + dy * dy)
            reach = op("MINIMUM", op("MAXIMUM", reach, 0.0), 1.0)
            px = op("SUBTRACT", u, op("ADD", ax, op("MULTIPLY", reach, dx)))
            py = op("SUBTRACT", v, op("ADD", ay, op("MULTIPLY", reach, dy)))
            near = op("LESS_THAN", op("ADD", op("MULTIPLY", px, px), op("MULTIPLY", py, py)), width * width)
            paint = near if paint is None else op("MAXIMUM", paint, near)
        if grain > 0.0:
            dust = hall._noise(nodes, links, coords.outputs["UV"], scale=60.0, detail=3.0)
            paint = op("MULTIPLY", paint, op("GREATER_THAN", dust, grain))
        shader = hall._principled(nodes, links, color, roughness=0.85)
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", paint, alpha))
    return hall._material(name, build)


def shadow_paint(name, segments, width):
    return paint_lines(name, segments, width, color=(0.72, 0.68, 0.54), alpha=0.85)


def chalk_schematic():
    """Chalk on the flagstones: the workshop circuit worked out by hand, a
    cell, an open switch, a resistor and a lamp, and a cross at the break."""
    segments = [((0.08, 0.2), (0.4, 0.2)), ((0.62, 0.2), (0.92, 0.2)), ((0.92, 0.2), (0.92, 0.4)),
                ((0.92, 0.6), (0.92, 0.8)), ((0.42, 0.8), (0.92, 0.8)), ((0.08, 0.8), (0.28, 0.8)),
                ((0.08, 0.2), (0.08, 0.44)), ((0.08, 0.56), (0.08, 0.8)),
                ((0.28, 0.8), (0.4, 0.93)),
                ((0.0, 0.44), (0.16, 0.44)), ((0.03, 0.56), (0.13, 0.56)),
                ((0.4, 0.2), (0.43, 0.27)), ((0.43, 0.27), (0.48, 0.13)), ((0.48, 0.13), (0.53, 0.27)),
                ((0.53, 0.27), (0.58, 0.13)), ((0.58, 0.13), (0.62, 0.2)),
                ((0.6, 0.86), (0.68, 0.96)), ((0.68, 0.86), (0.6, 0.96))]
    lamp = [(0.92 + 0.1 * math.cos(2.0 * math.pi * k / 14.0), 0.5 + 0.1 * math.sin(2.0 * math.pi * k / 14.0))
            for k in range(15)]
    segments += list(zip(lamp[:-1], lamp[1:]))
    segments += [((0.85, 0.43), (0.99, 0.57)), ((0.85, 0.57), (0.99, 0.43))]
    return paint_lines("CircuitChalk", segments, 0.011, color=(0.7, 0.68, 0.64), alpha=0.3, grain=0.46)


def grate_material(length, width):
    """An iron floor grille, the castle's violet light faint in the duct
    below. UVs are px: u along it, v across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        to_edge = op("MINIMUM", op("MINIMUM", u, op("SUBTRACT", length, u)),
                     op("MINIMUM", v, op("SUBTRACT", width, v)))
        bars = op("MAXIMUM", op("LESS_THAN", op("FRACT", op("DIVIDE", u, 5.0)), 0.42),
                  op("LESS_THAN", op("FRACT", op("DIVIDE", v, 12.5)), 0.22))
        iron = op("MAXIMUM", op("LESS_THAN", to_edge, 3.0), bars)
        depth = op("SUBTRACT", 1.0, op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0))
        color = hall._mix(nodes, links, iron, (0.005, 0.004, 0.01), (0.075, 0.07, 0.078))
        shader = hall._principled(nodes, links, color, roughness=op("ADD", 0.35, op("MULTIPLY", iron, 0.25)))
        links.new(op("MULTIPLY", iron, 0.8), shader.inputs["Metallic"])
        shader.inputs["Emission Color"].default_value = (0.42, 0.28, 0.78, 1.0)
        links.new(op("MULTIPLY", op("SUBTRACT", 1.0, iron), op("MULTIPLY", depth, 0.15)),
                  shader.inputs["Emission Strength"])
    return hall._material("CircuitGrate", build)


def commutator():
    """The commutator's face: brass bars split by dark mica round a steel boss."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        _coords, u, v = hall._uv_parts(nodes, links)
        du, dv = op("SUBTRACT", u, 0.5), op("SUBTRACT", v, 0.5)
        radius = op("MULTIPLY", op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv))), 2.0)
        turn = op("DIVIDE", op("ADD", op("ARCTAN2", dv, du), math.pi), 2.0 * math.pi)
        bars = op("MULTIPLY", op.between(radius, 0.5, 0.97), op("GREATER_THAN", op("FRACT", op("MULTIPLY", turn, 24.0)),
                                                                 0.14))
        color = hall._mix(nodes, links, bars, (0.03, 0.025, 0.03), (0.66, 0.42, 0.16))
        color = hall._mix(nodes, links, op("LESS_THAN", radius, 0.32), color, (0.32, 0.32, 0.34))
        shader = hall._principled(nodes, links, color, roughness=0.3)
        links.new(op("MAXIMUM", bars, op("LESS_THAN", radius, 0.32)), shader.inputs["Metallic"])
    return hall._material("CircuitCommutator", build)


def prism_dust():
    """Prism Dust in the maintenance tray: violet grit that catches the light."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        grains = nodes.new("ShaderNodeTexVoronoi")
        grains.inputs["Scale"].default_value = 260.0
        links.new(coords.outputs["Object"], grains.inputs["Vector"])
        spark = op("LESS_THAN", grains.outputs["Distance"], 0.12)
        shader = hall._principled(nodes, links, hall._mix(nodes, links, spark, (0.14, 0.09, 0.22), (0.7, 0.55, 1.0)),
                                  roughness=0.35)
        shader.inputs["Emission Color"].default_value = (0.7, 0.5, 1.0, 1.0)
        links.new(op("MULTIPLY", spark, 4.0), shader.inputs["Emission Strength"])
    return hall._material("CircuitPrismDust", build)


def tread_plate():
    """Diamond tread plate in dark steel, its raised treads worn bright. UVs
    are the box projection's (px / 180)."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        px, py = op("MULTIPLY", u, 180.0), op("MULTIPLY", v, 180.0)
        du = op("SUBTRACT", op("FRACT", op("DIVIDE", px, 9.0)), 0.5)
        dv = op("SUBTRACT", op("FRACT", op("DIVIDE", py, 9.0)), 0.5)
        odd = op("GREATER_THAN", op("FRACT", op("DIVIDE", op("ADD", op("FLOOR", op("DIVIDE", px, 9.0)),
                                                            op("FLOOR", op("DIVIDE", py, 9.0))), 2.0)), 0.25)
        a, b = op("ADD", du, dv), op("SUBTRACT", du, dv)
        even = op("SUBTRACT", 1.0, odd)
        across = op("ABSOLUTE", op("ADD", op("MULTIPLY", a, odd), op("MULTIPLY", b, even)))
        along = op("ABSOLUTE", op("ADD", op("MULTIPLY", b, odd), op("MULTIPLY", a, even)))
        tread = op("MAXIMUM", op("SUBTRACT", 1.0, op("ADD", op("DIVIDE", across, 0.14), op("DIVIDE", along, 0.66))),
                   0.0)
        grime = hall._noise(nodes, links, coords.outputs["Object"], scale=8.0, detail=5.0)
        color = hall._mix(nodes, links, grime, (0.03, 0.03, 0.034), (0.085, 0.083, 0.09))
        color = hall._mix(nodes, links, op("MULTIPLY", op("GREATER_THAN", tread, 0.05), 0.6), color,
                          (0.17, 0.165, 0.17))
        hall._principled(nodes, links, color, roughness=0.55, metallic=0.6,
                         normal=hall._bump(nodes, links, tread, 0.6))
    return hall._material("CircuitTreadPlate", build)


def junction_cover(kit, part, x0, x1, h0, h1, face, material):
    """A flush junction cover where the game draws a plate once surveyed: a
    thin seam, four screws, nothing that stands out for a hand to find."""
    uv_box(kit.box(part, x0, x1, face - 0.4, face + 0.7, h0, h1, material, bevel=0.35))
    steel = hall._steel()
    for index, (x, h) in enumerate(((x0 + 3.2, h0 + 3.2), (x1 - 3.2, h0 + 3.2), (x0 + 3.2, h1 - 3.2),
                                    (x1 - 3.2, h1 - 3.2))):
        face_disc(kit, "%sScrew%d" % (part, index), x, face + 1.2, h, 1.3, 0.5, steel, segments=10, bevel=0.0)


# ---------------------------------------------------------------- the room's dressing


GRATES = ((388.0, 355.0), (393.0, 803.0), (1088.0, 342.0), (1068.0, 856.0))


def floor_dressing():
    """Flat things on the open floor (the player walks over all of them):
    grates breathing the castle's violet light, the copper mains the painting
    lays along the floor, soot, oil, dusty boot prints from the maintenance
    door to the burnt bus, and the runner out through the doorway."""
    kit = RP.Kit("Floor", depth=False)
    iron, copper = hall._cast_iron(), hall._copper()
    for index, (cx, cy) in enumerate(GRATES):
        length, width = 64.0, 50.0
        x0, x1, y0, y1 = cx - length / 2.0, cx + length / 2.0, cy - width / 2.0, cy + width / 2.0
        kit.quad("Grate%d" % index, [(x0, y1, 0.35), (x1, y1, 0.35), (x1, y0, 0.35), (x0, y0, 0.35)],
                 grate_material(length, width), uvs=((0.0, 0.0), (length, 0.0), (length, width), (0.0, width)))
        for part, box in (("N", (x0 - 2.5, x1 + 2.5, y0 - 2.5, y0)), ("S", (x0 - 2.5, x1 + 2.5, y1, y1 + 2.5)),
                          ("W", (x0 - 2.5, x0, y0, y1)), ("E", (x1, x1 + 2.5, y0, y1))):
            kit.box("Grate%dFrame%s" % (index, part), *box, 0.0, 1.6, iron, bevel=0.3)
        RP.glow("grate", cx, cy, 0.0, VIOLET, 30.0)
    # The circuit worked out in chalk in front of the switchboard.
    kit.quad("Chalk", [(522.0, 438.0, 0.3), (662.0, 438.0, 0.3), (662.0, 298.0, 0.3), (522.0, 298.0, 0.3)],
             chalk_schematic())
    # The mains: from the board's ends to the cabinet and the dynamo, along
    # the walls to the doorway's piers.
    for index, path in enumerate((
            [(236.0, 272.0), (150.0, 272.0), (150.0, 600.0)],
            [(178.0, 652.0), (178.0, 934.0), (526.0, 934.0)],
            [(1066.0, 284.0), (1300.0, 284.0), (1300.0, 640.0)],
            [(1214.0, 814.0), (1214.0, 940.0), (868.0, 940.0)],
            [(1214.0, 940.0), (1362.0, 940.0)])):
        lying_pipe(kit, "Main%d" % index, path, 5.6, copper, iron)
    kit.quad("Soot", [(886.0, 330.0, 0.2), (1066.0, 330.0, 0.2), (1066.0, 276.0, 0.2), (886.0, 276.0, 0.2)],
             smudge("CircuitFloorSoot", (0.012, 0.01, 0.009), 0.95, 0.9))
    for index, (cx, cy, rx, ry) in enumerate(((1012.0, 834.0, 46.0, 16.0), (868.0, 760.0, 22.0, 9.0),
                                              (330.0, 690.0, 16.0, 7.0))):
        kit.quad("Oil%d" % index, [(cx - rx, cy + ry, 0.25), (cx + rx, cy + ry, 0.25), (cx + rx, cy - ry, 0.25),
                                   (cx - rx, cy - ry, 0.25)], smudge("CircuitOil", (0.025, 0.022, 0.02), 0.1, 0.75,
                                                                     scale=3.0))
    # Porcelain shards fallen from the shattered insulator.
    rng = random.Random(5)
    for index in range(5):
        x, y = rng.uniform(1004.0, 1052.0), rng.uniform(282.0, 304.0)
        kit.box("Shard%d" % index, x, x + rng.uniform(1.2, 2.4), y, y + rng.uniform(0.8, 1.6), 0.0, 0.8, porcelain(),
                bevel=0.2)
    # Prints in the dust: someone came in by the maintenance door.
    prints = bootprint()
    start, end = (1158.0, 236.0), (1010.0, 318.0)
    for index in range(7):
        t = (index + 0.5) / 7.0
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        heading = math.atan2(end[1] - start[1], end[0] - start[0])
        side = 4.5 if index % 2 else -4.5
        x += -math.sin(heading) * side
        y += math.cos(heading) * side
        along, across = (math.cos(heading), math.sin(heading)), (-math.sin(heading), math.cos(heading))
        corners = []
        for du, dv in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
            corners.append((x + across[0] * du * 5.6 + along[0] * dv * 12.5,
                            y + across[1] * du * 5.6 + along[1] * dv * 12.5, 0.3))
        kit.quad("Print%d" % index, corners, prints)
    # The runner, out between the piers.
    x0, x1, y0, y1 = 652.0, 744.0, 862.0, 1074.0
    width = x1 - x0
    kit.quad("Runner", [(x0, y1, 0.8), (x1, y1, 0.8), (x1, y0, 0.8), (x0, y0, 0.8)], runner(width),
             uvs=((y1 - y0, 0.0), (y1 - y0, width), (0.0, width), (0.0, 0.0)))
    return kit


def back_wall_dressing():
    """The back wall either side of the switchboard: banners at its corners,
    the Circuit emblem over the maintenance door, a vent, conduits rising to
    the wall top and insulated mains strung along it."""
    kit = RP.Kit("BackWall")
    face = BACK_Y + 0.6
    brass, iron, copper = hall._brass(), hall._cast_iron(), hall._copper()
    for index, (x0, x1) in enumerate(((66.0, 108.0), (1298.0, 1340.0))):
        low, high = 78.0, 170.0
        kit.quad("Banner%d" % index, [(x0, face + 0.6, low), (x1, face + 0.6, low), (x1, face + 0.6, high),
                                      (x0, face + 0.6, high)],
                 hall.material_banner("CircuitBanner", (0.2, 0.06, 0.34), (high - low) / (x1 - x0)))
        kit.rod("BannerRod%d" % index, (x0 - 5.0, face + 2.4, high + 1.6), (x1 + 5.0, face + 2.4, high + 1.6), 1.1,
                brass)
        for x in (x0 - 5.6, x1 + 5.6):
            kit.ball("BannerFinial%d" % index, x, face + 2.4, high + 1.6, 1.8, brass)
    for part, (x0, x1), right in (("CobwebWest", (30.0, 70.0), False), ("CobwebEast", (1376.0, 1416.0), True)):
        kit.quad(part, [(x0, face + 0.9, 146.0), (x1, face + 0.9, 146.0), (x1, face + 0.9, 182.0),
                        (x0, face + 0.9, 182.0)], hall.material_cobweb(right))
    # The Circuit emblem, as the Hall's portal crest shows it, over the door.
    cx = (HATCH_X[0] + HATCH_X[1]) / 2.0
    face_disc(kit, "CrestPlate", cx, face + 2.0, 168.0, 12.5, 2.0, brass)
    face_ring(kit, "CrestRim", cx, face + 2.2, 168.0, 12.5, 1.2, brass)
    bolt = [(2.6, 8.6), (-3.6, -0.6), (0.2, -0.6), (-2.6, -8.6), (3.8, 1.2), (0.0, 1.2)]
    kit.slab("CrestBolt", [(cx + x, 168.0 + h) for x, h in bolt], face + 2.0, face + 3.4, emblem_glow())
    RP.glow("runes", cx, face + 3.0, 168.0, EXIT_BLUE, 18.0)
    # The vent beside the door.
    face_disc(kit, "VentBack", 1262.0, face + 0.8, 104.0, 15.5, 0.8, hall._bakelite(), bevel=0.0)
    face_ring(kit, "VentRim", 1262.0, face + 2.2, 104.0, 16.0, 2.4, iron)
    for index in range(-2, 3):
        x = 1262.0 + index * 5.4
        reach = math.sqrt(max(15.5 ** 2 - (index * 5.4) ** 2, 0.0))
        kit.rod("VentBar%d" % index, (x, face + 1.6, 104.0 - reach), (x, face + 1.6, 104.0 + reach), 0.8, iron)
    for index, turn in enumerate((45.0, 135.0, 225.0, 315.0)):
        x, h = 1262.0 + 20.0 * math.cos(math.radians(turn)), 104.0 + 20.0 * math.sin(math.radians(turn))
        kit.ball("VentBolt%d" % index, x, face + 1.6, h, 1.5, brass)
    # Conduits rising from the switchboard into the wall top, and a fuse box.
    for index, x in enumerate((236.0, 1080.0)):
        kit.rod("Riser%d" % index, (x, face + 4.0, 0.0), (x, face + 4.0, 184.0), 3.4, copper)
        for h in (40.0, 100.0, 160.0):
            kit.box("RiserClip%d" % index, x - 4.6, x + 4.6, face, face + 6.0, h - 1.6, h + 1.6, iron, bevel=0.3)
    kit.box("FuseBox", 1236.0, 1288.0, face, face + 9.0, 22.0, 66.0, green_iron(), bevel=0.8, uv="box")
    kit.box("FuseBoxLid", 1238.0, 1286.0, face + 9.0, face + 10.0, 24.0, 64.0, green_iron(), bevel=0.4, uv="box")
    kit.ball("FuseBoxLatch", 1280.0, face + 10.6, 44.0, 1.6, brass)
    kit.rod("FuseBoxLead", (1262.0, face + 4.0, 66.0), (1262.0, face + 4.0, 84.0), 1.6, copper)
    # Insulated mains along the wall top, on porcelain bobbins.
    tops = []
    for index, x in enumerate((96.0, 330.0, 560.0, 790.0, 1020.0, 1250.0, 1386.0)):
        y = BACK_Y - 9.0
        kit.cylinder("BobbinPin%d" % index, x, y, WALL_H, WALL_H + 5.0, 1.0, iron, plan=1.0 * ROUND, segments=8)
        kit.lathe("Bobbin%d" % index, x, y, [(0.0, WALL_H + 4.0), (3.6, WALL_H + 4.0), (4.2, WALL_H + 6.0),
                                             (2.8, WALL_H + 8.0), (3.6, WALL_H + 10.0), (0.0, WALL_H + 11.0)],
                  porcelain(), plan=ROUND)
        tops.append((x, y, WALL_H + 8.0))
    points = []
    for (xa, ya, ha), (xb, _yb, _hb) in zip(tops[:-1], tops[1:]):
        points += [(xa, ya, ha), ((xa + xb) / 2.0, ya, ha - 4.0)]
    points.append(tops[-1])
    cable(kit, "Mains", points, 0.7, copper, resolution=6)
    return kit


def hatch():
    """The maintenance door in its arched opening, riveted iron, left ajar on
    its west hinges: the route the Mechanic says someone used."""
    kit = RP.Kit("Hatch")
    x0, x1 = HATCH_X
    cx, radius = (x0 + x1) / 2.0, (x1 - x0) / 2.0 - 1.0
    leaf_y = BACK_Y - 18.0
    iron, brass, steel = hall._cast_iron(), hall._brass(), hall._steel()
    outline = [(x0 + 1.0, 0.8), (x1 - 1.0, 0.8)] + [(cx + radius * math.cos(math.radians(a)),
                                                    HATCH_SPRING + radius * math.sin(math.radians(a)))
                                                   for a in range(0, 181, 9)]
    before = len(kit.made)
    uv_box(kit.slab("Leaf", outline, leaf_y - 5.0, leaf_y, dark_plate(), bevel=0.6))
    for index, h in enumerate((26.0, 74.0)):
        uv_box(kit.box("Strap%d" % index, x0 + 2.0, x1 - 3.0, leaf_y, leaf_y + 1.4, h - 4.0, h + 4.0, iron, bevel=0.4))
    for index, (x, h) in enumerate([(x, hh) for x in (x0 + 7.0, x1 - 7.0) for hh in range(12, 96, 14)]
                                   + [(x, hh) for x in range(int(x0) + 18, int(x1) - 10, 14) for hh in (22.0, 30.0,
                                                                                                         70.0, 78.0)]):
        kit.ball("Rivet%d" % index, float(x), leaf_y + 1.2, float(h), 1.1, steel)
    kit.box("Grille", cx - 14.0, cx + 14.0, leaf_y - 0.6, leaf_y + 0.4, 102.0, 128.0, hall._bakelite(), bevel=0.0)
    for index in range(4):
        x = cx - 10.5 + index * 7.0
        kit.rod("GrilleBar%d" % index, (x, leaf_y + 0.8, 102.0), (x, leaf_y + 0.8, 128.0), 0.9, iron)
    face_ring(kit, "Wheel", x1 - 20.0, leaf_y + 3.0, 56.0, 9.0, 1.3, brass)
    for spoke in range(3):
        turn = math.radians(spoke * 60.0)
        kit.rod("WheelSpoke%d" % spoke, (x1 - 20.0 - 9.0 * math.cos(turn), leaf_y + 3.0, 56.0 - 9.0 * math.sin(turn)),
                (x1 - 20.0 + 9.0 * math.cos(turn), leaf_y + 3.0, 56.0 + 9.0 * math.sin(turn)), 0.7, brass)
    leaf = kit.made[before:]
    # Ajar: the leaf turns about its west hinge, its free edge toward the room.
    hinge = bpy.data.objects.new("HatchHinge", None)
    RP._link(hinge)
    hinge.location = RP.world(x0 + 1.0, leaf_y - 2.5, 0.0)
    bpy.context.view_layer.update()
    for obj in leaf:
        world_matrix = obj.matrix_world.copy()
        obj.parent = hinge
        obj.matrix_parent_inverse = hinge.matrix_world.inverted()
        obj.matrix_world = world_matrix
    hinge.rotation_euler = (0.0, 0.0, math.radians(-17.0))
    for index, h in enumerate((20.0, 82.0)):
        kit.cylinder("Hinge%d" % index, x0 + 1.5, leaf_y - 2.0, h - 7.0, h + 7.0, 2.4, iron, plan=2.4 * ROUND,
                     segments=12)
    kit.box("Sill", x0 - 4.0, x1 + 4.0, BACK_Y - 40.0, BACK_Y + 6.0, 0.0, 1.6, iron, bevel=0.4, uv="box")
    # Cold air from the passage behind.
    kit.light("Draft", cx + 26.0, BACK_Y - 34.0, 40.0, (0.42, 0.5, 0.92), 0.8, radius=0.1)
    return kit


def bulb_lamp(kit, part, wall, normal, reach=15.0, power=LAMP_POWER):
    """A caged bulb under a green enamel shade on a brass bracket. `wall` is
    the bracket's foot on the wall face (x, y, h), `normal` the level way out
    of the wall into the room. Returns the bulb's centre."""
    brass, iron = hall._brass(), hall._cast_iron()
    wx, wy, wh = wall
    nx, ny = normal
    kit.ball(part + "Rose", wx + nx * 0.8, wy + ny * 0.8, wh, 3.4, brass, plan=0.45)
    elbow = (wx + nx * reach, wy + ny * reach, wh + 5.0)
    kit.rod(part + "Arm", (wx + nx * 1.2, wy + ny * 1.2, wh), elbow, 1.0, brass)
    x, y, top = elbow
    kit.lathe(part + "Socket", x, y, [(0.0, top + 1.0), (2.2, top + 1.0), (2.4, top - 6.0), (0.0, top - 6.0)], brass,
              plan=ROUND)
    kit.lathe(part + "Shade", x, y, [(2.0, top - 2.0), (6.0, top - 4.5), (10.0, top - 9.0), (10.6, top - 10.4)],
              enamel(), plan=ROUND, close=False)
    bulb_h = top - 14.5
    bulb = kit.ball(part + "Bulb", x, y, bulb_h, 4.0, bulb_glass(), plan=ROUND)
    bulb.visible_shadow = False
    for index, h in enumerate((bulb_h - 5.0, bulb_h + 1.5)):
        kit.ring(part + "Hoop%d" % index, (x, y, h), (0.0, 0.0, 1.0), 6.2, 0.32, iron, segments=24, sides=6)
    for index in range(4):
        turn = math.pi / 4.0 + index * math.pi / 2.0
        bx, by = x + 6.2 * math.cos(turn), y + 6.2 * ROUND * math.sin(turn)
        kit.rod(part + "Bar%d" % index, (bx, by, bulb_h - 5.0), (bx, by, top - 9.6), 0.3, iron)
    kit.light(part + "Light", x, y + 1.0, bulb_h, BULB, power, radius=0.02)
    return (x, y, bulb_h)


def wall_lamps(shell):
    """The five wall lamps in the order of the game's WALL_LAMP_POSITIONS:
    the back wall's west end, then each side wall high and low. Each keeps a
    soft warm pool on the floor below it, as the Hall's lanterns do."""
    kit = RP.Kit("WallLamps")
    spots = [bulb_lamp(kit, "Back", (147.0, BACK_Y, 112.0), (0.0, 1.0))]
    for side, y, h in (("left", 430.0, 122.0), ("left", 950.0, 68.0), ("right", 430.0, 122.0),
                       ("right", 950.0, 68.0)):
        out = shell.mount(side, y).out
        spots.append(bulb_lamp(kit, "%s%d" % (side.title(), int(y)), (shell.side_x(side, y, h), y, h),
                               (out.x, out.y)))
    for index, (x, y, _h) in enumerate(spots):
        pool_x = min(max(x, 110.0), 1340.0)
        pool_y = min(max(y + 40.0, 300.0), 900.0)
        kit.light("Pool%d" % index, pool_x, pool_y, 45.0, (1.0, 0.62, 0.32), 16.0, radius=0.3, mirrored=False)
    return kit, spots


def window(shell, side):
    """A lancet window in a side wall: diamond-leaded glass lit by the moon,
    a stone surround, mullion and sill, and the moonlight falling in."""
    kit = RP.Kit("Window" + side.title())
    frame = shell.mount(side, WINDOW_Y)
    rise = shell.frames[side].lean.length / WALL_H

    def at(u, h, w):
        return tuple(frame.to_g(u, h * rise, w))

    half, sill, spring = 34.0, 60.0, 118.0

    def arch(reach, low):
        return [(-reach, low), (reach, low)] + [(reach * math.cos(math.radians(a)), spring + reach * math.sin(
            math.radians(a))) for a in range(0, 181, 10)]

    rock = stone()
    glass = RP.polygon_mesh(kit.name + "Glass", arch(half, sill), [], lambda u, h: at(u, h, 0.6),
                            lancet_glass("CircuitLancet"), uv_of=lambda u, h: (u + half, h - sill))
    glass.visible_shadow = False
    kit.keep(glass)
    kit.keep(RP.polygon_mesh(kit.name + "Surround", arch(half + 8.0, sill - 6.0), [arch(half, sill)],
                             lambda u, h: at(u, h, 1.6), rock))
    for part, (u0, u1, h0, h1) in (("Mullion", (-1.8, 1.8, sill, spring + half - 3.0)),
                                   ("Transom", (-half, half, 100.0, 103.5))):
        kit.keep(RP.polygon_mesh(kit.name + part, [(u0, h0), (u1, h0), (u1, h1), (u0, h1)], [],
                                 lambda u, h: at(u, h, 1.9), rock))
    kit.keep(RP.polygon_mesh(kit.name + "SillTop", [(-half - 9.0, 0.0), (half + 9.0, 0.0), (half + 9.0, 7.0),
                                                    (-half - 9.0, 7.0)], [],
                             lambda u, w: at(u, sill - 6.0, w), rock))
    kit.keep(RP.polygon_mesh(kit.name + "SillFront", [(-half - 9.0, sill - 11.0), (half + 9.0, sill - 11.0),
                                                      (half + 9.0, sill - 6.0), (-half - 9.0, sill - 6.0)], [],
                             lambda u, h: at(u, h, 7.0), rock))
    data = bpy.data.lights.new(kit.name + "Moon", "AREA")
    data.energy = 18.0
    data.color = MOON
    data.shape = "RECTANGLE"
    data.size, data.size_y = 0.5, 1.1
    moon = RP._link(bpy.data.objects.new(kit.name + "Moon", data))
    moon.location = RP.world(*at(0.0, 110.0, 8.0))
    aim = RP.world(*at(0.0, 0.0, 150.0)) - moon.location
    moon.rotation_euler = aim.normalized().to_track_quat("-Z", "Y").to_euler()
    moon.visible_glossy = False
    # The moonbeam the window lets fall across the flagstones, slanting past
    # the furniture in front of it onto open floor.
    data = bpy.data.lights.new(kit.name + "Beam", "SPOT")
    data.energy = 480.0 if side == "left" else 300.0
    data.color = MOON
    data.spot_size = math.radians(34.0)
    data.spot_blend = 0.55
    data.shadow_soft_size = 0.08
    beam = RP._link(bpy.data.objects.new(kit.name + "Beam", data))
    beam.location = RP.world(*at(0.0, 150.0, 3.0))
    target = (230.0, 770.0) if side == "left" else (1200.0, 885.0)
    aim = RP.world(target[0], target[1], 0.0) - beam.location
    beam.rotation_euler = aim.normalized().to_track_quat("-Z", "Y").to_euler()
    beam.visible_glossy = False
    return kit


def pier_lantern(kit, part, x, y, h):
    """An iron lantern on a pier, as the Hall hangs one beside each door:
    roof, posts, glass and the flame lighting it from inside."""
    iron, brass = hall._cast_iron(), hall._brass()
    kit.box(part + "Base", x - 6.0, x + 6.0, y - 6.0 * ROUND, y + 6.0 * ROUND, h, h + 2.4, iron, bevel=0.5)
    for dx in (-4.6, 4.6):
        for dy in (-4.6 * ROUND, 4.6 * ROUND):
            kit.rod(part + "Post", (x + dx, y + dy, h + 2.4), (x + dx, y + dy, h + 19.0), 0.6, iron)
    glass = kit.box(part + "Glass", x - 4.2, x + 4.2, y - 4.2 * ROUND, y + 4.2 * ROUND, h + 2.6, h + 18.8,
                    hall._lantern_glass(), bevel=0.0)
    glass.visible_shadow = False
    kit.lathe(part + "Roof", x, y, [(0.0, h + 19.0), (7.4, h + 19.0), (7.0, h + 20.6), (2.0, h + 25.0),
                                    (1.2, h + 27.0), (0.0, h + 27.0)], iron, plan=ROUND)
    kit.ring(part + "Bail", (x, y, h + 29.0), (0.0, 1.0, 0.0), 2.2, 0.45, brass, segments=16, sides=6)
    kit.flame(part, x, y, h + 6.0, size=1.4, power=5.0, color=WARM)
    RP.GLOWS[-1]["kind"] = "lantern"


def offset_outline(outline, distance):
    """A convex outline (x, y), wound either way, moved `distance` px out."""
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(outline, outline[1:] + outline[:1]))
    sign = 1.0 if area > 0.0 else -1.0
    lines = []
    for (x0, y0), (x1, y1) in zip(outline, outline[1:] + outline[:1]):
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        nx, ny = sign * dy / length, -sign * dx / length
        lines.append(((x0 + nx * distance, y0 + ny * distance), (dx, dy)))
    result = []
    for ((ax, ay), (adx, ady)), ((bx, by), (bdx, bdy)) in zip(lines[-1:] + lines[:-1], lines):
        cross = adx * bdy - ady * bdx
        t = ((bx - ax) * bdy - (by - ay) * bdx) / cross
        result.append((ax + adx * t, ay + ady * t))
    return result


# Each pillar's footprint: its north edge on the collision's own line, its
# south face on the low wall's.
PIERS = (
    ("West", [(538.0, 928.3), (634.0, 916.2), (634.0, SOUTH_Y), (538.0, SOUTH_Y)]),
    ("East", [(763.0, 920.2), (809.0, 926.2), (828.0, 930.2), (851.0, 930.2), (857.5, 958.0), (857.5, SOUTH_Y),
              (763.0, SOUTH_Y)]),
)


def exit_piers():
    """The doorway out to the Hall: two stone pillars where the south wall
    breaks, standing from the collision's edge to the wall's line, each with a
    moulded capstone and an iron lantern, the castle's banner on the face that
    shows above the wall, and the cold light of the Hall's passage beyond."""
    kit = RP.Kit("Piers")
    rock = RP.textured("CircuitPierStone", "castle_wall_slates", 1.2, 0.6, (0.74, 0.7, 0.8), ao=0.25)
    cap_stone = stone()
    banner = hall.material_banner("CircuitPierBanner", (0.2, 0.06, 0.34), 34.0 / 30.0)
    brass = hall._brass()
    for name, outline in PIERS:
        xs = [x for x, _y in outline]
        cx = (min(xs) + max(xs)) / 2.0
        north = max(y for x, y in outline if y < SOUTH_Y - 1.0)
        for part, shape, (low, high), material, bevel in (
                ("Plinth", offset_outline(outline, 1.5), (0.0, 8.0), cap_stone, 0.8),
                ("", outline, (8.0, PIER_H), rock, 0.6),
                ("Collar", offset_outline(outline, 1.5), (PIER_H - 7.0, PIER_H - 4.0), cap_stone, 0.6),
                ("Cap", offset_outline(outline, 3.5), (PIER_H, PIER_H + 6.0), cap_stone, 1.4),
                ("CapTop", offset_outline(outline, -4.0), (PIER_H + 6.0, PIER_H + 8.0), cap_stone, 1.0)):
            uv_box(kit.slab(name + part, shape, low, high, material, plane="floor", bevel=bevel),
                   "box_up" if part == "" else "box")
        # The banner on the face the low wall leaves showing, on a brass rod.
        low, high = 28.0, PIER_H - 9.0
        kit.quad(name + "Banner", [(cx - 15.0, SOUTH_Y + 0.6, low), (cx + 15.0, SOUTH_Y + 0.6, low),
                                   (cx + 15.0, SOUTH_Y + 0.6, high), (cx - 15.0, SOUTH_Y + 0.6, high)], banner)
        kit.rod(name + "BannerRod", (cx - 19.0, SOUTH_Y + 2.0, high + 1.2), (cx + 19.0, SOUTH_Y + 2.0, high + 1.2), 0.9,
                brass)
        pier_lantern(kit, name + "Lantern", cx, (north + SOUTH_Y) / 2.0, PIER_H + 8.0)
    return kit


# The gate out to the Hall: the Hall's portal at 2.8 times its size, its
# doorway 14 Hall px each side, standing across the passage with its foot
# just past the room's south edge. Its top (151 px above the foot on screen)
# then clears a player coming in at the spawn (724, 930) and the shadow at
# their feet, and no player walks out in front of it.
GATE_X = 698.5
GATE_Y = 1090.0
GATE_SCALE = 2.8
GATE_HALF = 14.0


def exit_gate():
    """The gate out to the Hall, the Circuit Room's own door: the Hall's stone
    portal (hall_prototype.build_portal) and its blue fanlight, closed by two
    leaves of riveted steel plate under a brass seal bearing the Circuit bolt,
    with porcelain insulators on its jambs carrying a copper bus over the
    arch and blue indicator lamps. It faces
    the camera as the Hall draws a door reached from the north: a player at it
    is seen behind it, as at the Wake gate. Its crest is left off and its foot
    stands past the room's edge, so a player coming in is never hidden behind
    it. Bolt, insulators and lamps are added
    in the portal's own frame before the map, so they scale with it."""
    kit = RP.Kit("Gate")
    color = hall.DOOR_THEMES["Circuit"][1]
    before = set(bpy.data.objects)
    recorded = []
    saved = hall._glow
    hall._glow = lambda *glow: recorded.append(glow)
    try:
        stand = {"centre": 0.0, "feet": 0.0, "width": 40.0, "height": 64.0, "depth": 6.0}
        portal = hall.PropKit("CircuitGate", stand, RP.STRETCH)
        hall.build_portal(portal, {"name": "Circuit", "half": GATE_HALF, "opens": "in", "x": 0.0, "face_y": 0.0})
        brass, iron, copper = hall._brass(), hall._cast_iron(), hall._copper()
        # The seal over the leaves' meeting: a brass roundel, the bolt on enamel.
        portal.disc("SealPlate", 0.0, -1.9, 21.0, 5.0, 0.6, brass)
        portal.disc("SealEnamel", 0.0, -2.05, 21.0, 4.1, 0.2, hall._painted("SealEnamel", (0.02, 0.025, 0.04)))
        portal.ring("SealRim", 0.0, -2.1, 21.0, 5.0, 0.35, brass)
        hall._emblem(portal, "bolt", color, 0.0, 21.0, 3.0, -2.3)
        portal.glow("crystal", 0.0, -2.4, 21.0, color, 6.0)
        portal.rod("LockBar", -11.0, 11.0, -1.9, 10.5, 0.55, brass)
        for side in (-1.0, 1.0):
            jamb = side * (GATE_HALF + hall.PORTAL_JAMB_PX / 2.0)
            # An iron bracket and a porcelain insulator on each jamb.
            portal.box("InsulatorBracket", jamb, 23.6, 3.0, 1.0, -6.4, 3.2, iron)
            for index, (radius, low, tall) in enumerate(((1.7, 24.6, 1.1), (1.35, 25.7, 1.0), (1.05, 26.7, 1.0))):
                portal.cylinder("Insulator%d" % index, jamb, -5.0, low, radius, tall, porcelain())
            portal.ball("InsulatorCap", jamb, -5.0, 28.1, 0.75, brass, plan=0.6)
            # A blue indicator lamp in a brass cup below it.
            portal.cylinder("LampCup", jamb, -4.6, 11.0, 1.2, 1.2, brass)
            portal.ball("Lamp", jamb, -4.8, 13.1, 1.15, hall._glow_material("GateLamp", color, 2.2, (0.2, 0.32, 0.45)),
                        plan=0.6)
            portal.glow("bulb", jamb, -4.8, 13.1, color, 4.5)
        # The copper bus from insulator to insulator over the arch.
        reach = GATE_HALF + hall.PORTAL_JAMB_PX + 4.2
        arc = [(reach * math.cos(math.radians(angle)), -5.4, hall.PORTAL_SPRING_PX + reach * math.sin(math.radians(angle)))
               for angle in range(165, 14, -15)]
        west, east = -(GATE_HALF + hall.PORTAL_JAMB_PX / 2.0), GATE_HALF + hall.PORTAL_JAMB_PX / 2.0
        portal.wire("Bus", [(west, -5.0, 28.6), (west - 1.2, -5.3, 31.0)] + arc + [(east + 1.2, -5.3, 31.0),
                                                                                      (east, -5.0, 28.6)], 0.42, copper)
        for angle in (50.0, 130.0):
            x = reach * math.cos(math.radians(angle))
            z = hall.PORTAL_SPRING_PX + reach * math.sin(math.radians(angle))
            portal.ball("BusStandoff", x, -5.0, z - 0.4, 0.7, porcelain(), plan=0.6)
    finally:
        hall._glow = saved
    made = [obj for obj in bpy.data.objects if obj not in before]
    # Shut, with no crest: the lit passage, its roof and the crest are left out.
    for obj in list(made):
        if obj.name == "CircuitGateEmblem0" or any(part in obj.name for part in ("Passage", "RecessRoof", "Crest",
                                                                                   "Plaque")):
            made.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)
    plaque_z = hall.PORTAL_SPRING_PX + GATE_HALF + hall.PORTAL_JAMB_PX + 0.5 + 3.0 + 4.6
    recorded = [glow for glow in recorded if abs(glow[3] * hall.SIN_ALPHA - plaque_z) > 0.5]
    swaps = {
        "PortalStone": (RP.textured("CircuitGateStone", "large_grey_tiles", 0.45, 0.82, (0.8, 0.76, 0.84), ao=0.15),
                        "box"),
        "PortalStonePale": (RP.textured("CircuitGateStonePale", "large_grey_tiles", 0.45, 1.05, (0.88, 0.84, 0.86),
                                        ao=0.15), "box"),
        "DoorOak": (dark_plate(), "box_up"),
    }
    for obj in made:
        if obj.type != "MESH":
            continue
        chosen = [swaps[material.name] for material in obj.data.materials if material.name in swaps]
        if not chosen:
            continue
        RP.project_uvs(obj, chosen[0][1], scale=GATE_SCALE)
        for index, material in enumerate(obj.data.materials):
            if material.name in swaps:
                obj.data.materials[index] = swaps[material.name][0]
    # Glows sized for the Hall flare at nearly three times the size: matte, and dimmer.
    for name, factor in (("FaceDoorGem", 0.2), ("FanGlassCircuit", 0.3), ("EmblemBolt", 0.5)):
        material = bpy.data.materials.get(name)
        for node in material.node_tree.nodes if material else ():
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Emission Strength"].default_value *= factor
                node.inputs["Roughness"].default_value = 0.7
                node.inputs["Specular IOR Level"].default_value = 0.15
    frame = RP.Frame((GATE_X, GATE_Y, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0))
    in_game = RP.place_on_frame(made, frame, 0.0, 0.0, scale=GATE_SCALE, name="CircuitGate")
    RP.map_glows(recorded, in_game, GATE_SCALE)
    for obj in made:
        if obj.type == "MESH" or obj.type == "CURVE":
            kit.keep(obj)
    # Lit by the moon and a soft warm key from the floor in front, the Hall's
    # blue showing through the fanlight.
    for name, at, aim, energy, light_color in (
            ("GateKey", (600.0, GATE_Y + 94.0, 210.0), (GATE_X, GATE_Y, 70.0), 70.0, (1.0, 0.82, 0.62)),
            ("GateFill", (790.0, GATE_Y + 84.0, 120.0), (GATE_X, GATE_Y, 50.0), 22.0, EXIT_BLUE)):
        data = bpy.data.lights.new(name, "SPOT")
        data.energy = energy
        data.color = light_color
        data.spot_size = math.radians(50.0)
        data.spot_blend = 0.6
        data.shadow_soft_size = 0.35
        light = RP._link(bpy.data.objects.new(name, data))
        light.location = RP.world(*at)
        light.rotation_euler = (RP.world(*aim) - light.location).normalized().to_track_quat("-Z", "Y").to_euler()
        light.visible_glossy = False
    fan = in_game @ Vector((0.0, 0.0, hall.PORTAL_SPRING_PX + GATE_HALF * 0.45))
    RP.glow("crystal", fan.x, fan.y, fan.z, EXIT_BLUE, 34.0)
    return kit


# ---------------------------------------------------------------- the switchboard


SECTIONS = ((238.0, 410.0), (418.0, 572.0), (580.0, 752.0), (760.0, 886.0), (894.0, 1064.0))


def board_box(kit, part, xa, xb, inset, h0, h1, material, back=BACK_Y, bevel=0.6):
    """A block of the switchboard from the wall to `inset` px behind its
    slanted front, so it stands exactly on the collision."""
    outline = [(xa, back), (xb, back), (xb, board_front(xb) - inset), (xa, board_front(xa) - inset)]
    return uv_box(kit.slab(part, outline, h0, h1, material, plane="floor", bevel=bevel))


def gauge(kit, part, x, y, h, radius, needle, small=False):
    brass = hall._brass()
    face_disc(kit, part + "Case", x, y + 1.2, h, radius + 0.6, 1.4, brass, segments=40)
    face_ring(kit, part + "Bezel", x, y + 1.6, h, radius, 1.2 if small else 1.7, brass)
    face_dial(kit, part + "Dial", x, y + 1.5, h, radius - 1.2, hall.material_dial("CircuitDial" + part, "gauge",
                                                                                   needle=needle))


def picture_light(kit, part, x):
    """A brass hood on a swan-neck arm from the board's crown, throwing its
    low amber light down over the panels."""
    brass = hall._brass()
    y = board_front(x) - PANEL_INSET + 3.0
    cable(kit, part + "Arm", [(x, y, 163.0), (x, y + 7.0, 176.0), (x, y + 16.0, 176.0), (x, y + 20.0, 172.0)], 1.0,
          brass, resolution=8)
    hood_y, hood_h = y + 21.0, 166.0
    kit.box(part + "Hood", x - 26.0, x + 26.0, hood_y - 5.0, hood_y + 4.0, hood_h, hood_h + 5.0, brass, bevel=1.2)
    for side in (-1.0, 1.0):
        kit.ball(part + "Cap", x + side * 26.0, hood_y - 0.5, hood_h + 2.5, 2.6, brass, plan=ROUND)
    strip = kit.box(part + "Glow", x - 23.0, x + 23.0, hood_y - 3.5, hood_y + 2.5, hood_h - 0.6, hood_h,
                    bulb_glass(), bevel=0.0)
    strip.visible_shadow = False
    data = bpy.data.lights.new(kit.name + part, "AREA")
    data.energy = 16.0
    data.color = BULB
    data.shape = "RECTANGLE"
    data.size, data.size_y = 0.44, 0.06
    light = RP._link(bpy.data.objects.new(kit.name + part, data))
    light.location = RP.world(x, hood_y, hood_h - 1.5)
    aim = RP.world(x, y - 8.0, 96.0) - light.location
    light.rotation_euler = aim.normalized().to_track_quat("-Z", "Y").to_euler()
    light.visible_glossy = False


def switchboard():
    """The castle's switchboard on the back wall: a steel base of louvred
    doors, a slate counter, and above it five framed slate sections."""
    kit = RP.Kit("Switchboard")
    plate_metal, panel, iron, brass, copper = dark_plate(), slate(), hall._cast_iron(), hall._brass(), hall._copper()
    x0, x1 = BOARD_X
    board_box(kit, "Plinth", x0, x1, 0.0, 0.0, 10.0, plate_metal)
    board_box(kit, "Base", x0 + 1.5, x1 - 1.5, 3.0, 10.0, 54.0, plate_metal)
    board_box(kit, "Counter", x0 - 1.0, x1 + 1.0, -0.5, 54.0, 59.0, panel, bevel=0.8)
    board_box(kit, "Panels", x0 + 1.0, x1 - 1.0, PANEL_INSET, 59.0, 156.0, panel)
    board_box(kit, "Crown", x0 - 1.0, x1 + 1.0, PANEL_INSET - 2.5, 156.0, 165.0, plate_metal, bevel=0.8)
    board_box(kit, "Rail", x0, x1, PANEL_INSET - 1.2, 59.0, 64.0, iron, bevel=0.4)
    stiles = [(x0, SECTIONS[0][0])] + [(a[1], b[0]) for a, b in zip(SECTIONS[:-1], SECTIONS[1:])] + [(SECTIONS[-1][1],
                                                                                                      x1)]
    for index, (a, b) in enumerate(stiles):
        board_box(kit, "Stile%d" % index, a, b, PANEL_INSET - 1.6, 59.0, 156.0, iron, bevel=0.4)
    # Louvred doors in the base, each with a brass pull.
    count = 8
    span = (x1 - x0 - 12.0) / count
    for index in range(count):
        a = x0 + 6.0 + index * span + 2.0
        b = a + span - 4.0
        board_box(kit, "Door%d" % index, a, b, 2.2, 14.0, 50.0, plate_metal, bevel=0.5)
        for slat in range(5):
            h = 22.0 + slat * 5.2
            board_box(kit, "Louvre%d_%d" % (index, slat), a + 8.0, b - 8.0, 1.2, h, h + 2.2, iron, bevel=0.3)
        kit.ball("Pull%d" % index, b - 5.0, board_front(b - 5.0) - 0.6, 42.0, 1.8, brass)
    face = lambda x: board_front(x) - PANEL_INSET  # noqa: E731 - the panel's face at x

    # Feeders: three gauges over three double-pole knife switches, thrown open.
    for index, x in enumerate((266.0, 324.0, 382.0)):
        y = face(x)
        gauge(kit, "Feeder%d" % index, x, y, 132.0, 15.0, (-0.36, -0.33, -0.37)[index])
        kit.box("FeederPlate%d" % index, x - 22.0, x + 22.0, y, y + 1.0, 112.0, 116.0, brass, bevel=0.3)
        kit.box("SwitchBase%d" % index, x - 12.0, x + 12.0, y, y + 1.6, 74.0, 108.0, hall._bakelite(), bevel=0.4)
        for pole in (-5.0, 5.0):
            for part, h in (("Hinge", 80.0), ("Jaw", 102.0)):
                kit.lathe("%s%d_%d" % (part, index, int(pole)), x + pole, y + 4.0,
                          [(0.0, h - 3.0), (2.2, h - 3.0), (2.6, h), (1.6, h + 2.4), (0.0, h + 2.6)], porcelain(),
                          plan=ROUND)
            kit.rod("Blade%d_%d" % (index, int(pole)), (x + pole, y + 5.0, 81.0), (x + pole, y + 17.0, 68.0), 0.8,
                    copper)
        kit.rod("Handle%d" % index, (x - 7.0, y + 17.0, 68.0), (x + 7.0, y + 17.0, 68.0), 1.0, copper)
        kit.ball("Grip%d" % index, x, y + 19.5, 66.0, 3.2, hall._bakelite(), plan=ROUND)
    # Regulator: two large gauges and a rheostat, a braided lead looped below.
    for index, x in enumerate((452.0, 538.0)):
        gauge(kit, "Regulator%d" % index, x, face(x), 130.0, 19.0, (-0.34, -0.31)[index])
    x, y = 495.0, face(495.0)
    face_disc(kit, "RheostatFace", x, y + 1.6, 90.0, 20.0, 1.6, panel)
    for stud in range(11):
        turn = math.radians(200.0 - stud * 22.0)
        face_disc(kit, "RheostatStud%d" % stud, x + 15.0 * math.cos(turn), y + 2.4, 90.0 + 15.0 * math.sin(turn),
                  1.7, 0.8, brass, segments=12, bevel=0.0)
    kit.rod("RheostatArm", (x, y + 3.2, 90.0), (x - 13.0, y + 3.2, 98.0), 1.1, brass)
    kit.ball("RheostatKnob", x - 13.0, y + 5.0, 98.0, 2.6, hall._bakelite(), plan=ROUND)
    face_disc(kit, "RheostatHub", x, y + 4.0, 90.0, 3.4, 1.6, brass)
    lead = braid("CircuitOrangeBraid", (0.6, 0.27, 0.09))
    for index, xa in enumerate((430.0, 560.0)):
        face_disc(kit, "LeadPost%d" % index, xa, face(xa) + 3.0, 74.0, 2.6, 3.0, brass, segments=12)
    cable(kit, "Lead", [(430.0, face(430.0) + 3.5, 74.0), (452.0, face(452.0) + 9.0, 64.0),
                        (495.0, face(495.0) + 12.0, 61.5), (538.0, face(538.0) + 9.0, 64.0),
                        (560.0, face(560.0) + 3.5, 74.0)], 1.6, lead)
    # Resistors: four coils on porcelain cores; six insulators on the counter.
    for index, x in enumerate((604.0, 646.0, 688.0, 730.0)):
        y = face(x) + 9.0
        kit.box("CoilBracket%d" % index, x - 3.0, x + 3.0, face(x), y, 100.0, 104.0, iron, bevel=0.3)
        kit.box("CoilBracketTop%d" % index, x - 3.0, x + 3.0, face(x), y, 150.0, 154.0, iron, bevel=0.3)
        kit.cylinder("CoilCore%d" % index, x, y, 102.0, 152.0, 7.0, porcelain(), plan=7.0 * ROUND)
        kit.cylinder("Coil%d" % index, x, y, 108.0, 146.0, 8.6, winding(), plan=8.6 * ROUND, segments=28)
        for h in (104.0, 146.0):
            kit.cylinder("CoilCap%d_%d" % (index, int(h)), x, y, h, h + 4.0, 9.6, brass, plan=9.6 * ROUND)
    kit.rod("CoilBus", (598.0, face(598.0) + 9.0, 156.5), (736.0, face(736.0) + 9.0, 156.5), 1.5, copper)
    for index, x in enumerate((596.0, 624.0, 652.0, 680.0, 708.0, 736.0)):
        y = board_front(x) - 5.0
        kit.lathe("Insulator%d" % index, x, y, [(0.0, 59.0), (4.4, 59.0), (4.6, 61.0), (3.0, 63.0), (5.6, 66.0),
                                                (5.8, 68.0), (3.0, 70.0), (4.6, 73.0), (4.4, 75.0), (2.6, 77.0),
                                                (2.2, 80.0), (0.0, 80.5)], glazed_insulator(), plan=ROUND)
        kit.rod("InsulatorLead%d" % index, (x, y, 80.0), (x, face(x) + 0.5, 92.0), 0.5, copper)
    # The fuse bank: five glass tubes in brass clips, one blown black.
    for index, x in enumerate((774.0, 797.0, 820.0, 843.0, 866.0)):
        y = face(x) + 6.0
        kit.box("FuseClipBase%d" % index, x - 6.0, x + 6.0, face(x), face(x) + 1.4, 86.0, 156.0, hall._bakelite(),
                bevel=0.3)
        blown = index == 3
        tube = kit.cylinder("Fuse%d" % index, x, y, 98.0, 144.0, 4.2, smoked_glass() if blown else clear_glass(),
                            plan=4.2 * ROUND, segments=20)
        tube.visible_shadow = False
        for h0, h1 in ((92.0, 99.0), (143.0, 150.0)):
            kit.cylinder("FuseCap%d_%d" % (index, int(h0)), x, y, h0, h1, 4.8, brass, plan=4.8 * ROUND)
        if not blown:
            kit.rod("FuseWire%d" % index, (x, y, 99.0), (x, y, 143.0), 0.35, hall._steel())
    # The burnt section: the slate cracked and sooted round a snapped bus.
    a, b = SECTIONS[-1]
    kit.quad("Soot", [(a + 2.0, face(a) + 0.4, 62.0), (b - 2.0, face(b) + 0.4, 62.0),
                      (b - 2.0, face(b) + 0.4, 156.0), (a + 2.0, face(a) + 0.4, 156.0)],
             smudge("CircuitPanelSoot", (0.01, 0.008, 0.008), 0.9, 1.7, scale=3.0))
    kit.quad("SootWall", [(900.0, BACK_Y + 0.8, 140.0), (1040.0, BACK_Y + 0.8, 140.0),
                          (1040.0, BACK_Y + 0.8, 184.0), (900.0, BACK_Y + 0.8, 184.0)],
             smudge("CircuitWallSoot", (0.01, 0.008, 0.008), 0.95, 1.2, scale=2.5))
    crack = [(948.0, 156.0), (952.0, 138.0), (946.0, 126.0), (957.0, 108.0), (950.0, 92.0), (958.0, 70.0),
             (961.0, 62.0)]
    for index, ((xa, ha), (xb, hb)) in enumerate(zip(crack[:-1], crack[1:])):
        kit.rod("Crack%d" % index, (xa, face(xa) + 0.2, ha), (xb, face(xb) + 0.2, hb), 0.7, hall._bakelite())
    y = face(950.0)
    for index, (xa, h_top, h_end) in enumerate(((934.0, 156.0, 126.0), (966.0, 156.0, 112.0))):
        kit.box("Bus%d" % index, xa - 3.6, xa + 3.6, y, y + 4.0, h_end, h_top, copper, bevel=0.6)
    # The west bar snapped and bent out toward the room; the arc jumps the gap.
    kit.rod("BusBent", (934.0, y + 2.0, 127.0), (941.0, y + 11.0, 118.0), 2.4, copper)
    kit.ball("BusBead", 941.5, y + 11.5, 117.5, 2.8, ember(), plan=ROUND)
    kit.ball("BusScorch", 966.0, y + 2.6, 112.0, 3.4, hall._bakelite(), plan=ROUND)
    bolt = [(942.0, y + 11.0, 118.0), (947.0, y + 9.0, 124.0), (951.0, y + 8.0, 117.0), (956.0, y + 6.0, 122.0),
            (961.0, y + 4.0, 114.0), (965.0, y + 3.0, 113.0)]
    arc = arc_glow()
    for index, (start, end) in enumerate(zip(bolt[:-1], bolt[1:])):
        segment = kit.rod("Arc%d" % index, start, end, 0.45, arc)
        segment.visible_shadow = False
    for index, (start, end) in enumerate((((947.0, y + 9.0, 124.0), (944.0, y + 10.0, 131.0)),
                                          ((956.0, y + 6.0, 122.0), (960.0, y + 6.5, 129.0)))):
        kit.rod("ArcFork%d" % index, start, end, 0.3, arc).visible_shadow = False
    arc_at = (953.0, y + 8.0, 120.0)
    kit.light("Arc", *arc_at, ARC, 7.0, radius=0.01)
    rng = random.Random(41)
    for index in range(12):
        kit.ball("Ember%d" % index, rng.uniform(912.0, 1000.0), face(950.0) + 0.6, rng.uniform(96.0, 150.0),
                 rng.uniform(0.5, 1.0), ember(), plan=0.4)
    for index, x in enumerate((1004.0, 1028.0, 1052.0)):
        tall = 20.0 if index != 1 else 9.0
        kit.lathe("Standoff%d" % index, x, face(x) + 5.0, [(0.0, 112.0), (5.0, 112.0), (5.4, 114.0), (3.2, 117.0)]
                  + [(5.6 - (step % 2) * 2.2, 117.0 + step * (tall - 5.0) / 6.0) for step in range(7)]
                  + [(0.0, 112.0 + tall)], porcelain(), plan=ROUND)
    # Bus bars along the board's top, on porcelain stand-offs.
    for row, inset in enumerate((24.0, 32.0, 40.0)):
        yb = BACK_Y + inset
        kit.box("TopBus%d" % row, 244.0, 1056.0, yb - 1.5, yb + 1.5, 169.0, 172.0, copper, bevel=0.4)
        for x in range(260, 1056, 160):
            kit.lathe("TopStandoff%d_%d" % (row, x), float(x), yb, [(0.0, 165.0), (2.8, 165.0), (3.2, 167.0),
                                                                    (2.2, 169.0), (0.0, 169.0)], porcelain(),
                      plan=ROUND)
    for index, x in enumerate((404.0, 748.0)):
        picture_light(kit, "PictureLight%d" % index, x)
    return kit, (arc_at[0], arc_at[1] - arc_at[2])


# ---------------------------------------------------------------- the interactive props
#
# Each prop fills its FurnitureCollision rectangle, which is also the painted
# sprite's rect: its front stands on the rect's bottom (the feet), its sides
# on the rect's sides and its top reaches the rect's top. The game reads the
# prop's feet, highlight box and walk-up band from the HD sprite, so each
# must meet its collision within the walk-up rule's 7.5 px.

CABINET = (98.5, 295.0, 390.14, 650.65)
WORKBENCH = (446.5, 827.3, 443.6, 739.41)
GENERATOR = (934.0, 1334.0, 373.0, 812.0)


def cabinet():
    """The equipment cabinet: a padlocked locker door beside a fixed
    switchgear panel. Plate 1 (210, 535) is drawn over its flush junction
    cover; its loose access panel hides the iron salt and the glove record."""
    kit = RP.Kit("Cabinet", prop="Cabinet")
    x0, x1, _top, feet = CABINET
    back, face = feet - 88.0, feet - 2.0
    paint, metal, brass, iron, steel = green_iron(), dark_plate(), hall._brass(), hall._cast_iron(), hall._steel()
    kit.box("Plinth", x0, x1, back + 1.0, feet, 0.0, 10.0, metal, bevel=0.8, uv="box")
    kit.box("Body", x0 + 2.0, x1 - 2.0, back + 3.0, face, 10.0, 164.0, paint, bevel=1.2, uv="box")
    kit.box("Lid", x0 + 1.0, x1 - 1.0, back + 1.0, face - 6.0, 164.0, 171.0, paint, bevel=1.0, uv="box")
    kit.box("Cornice", x0, x1, face - 7.0, face + 1.6, 164.0, 172.0, metal, bevel=1.0, uv="box")
    for index, h in enumerate(range(18, 160, 12)):
        for x in (x0 + 3.0, x1 - 3.0):
            kit.ball("Rivet%d_%d" % (index, int(x)), x, face + 1.4, float(h), 0.9, steel, plan=0.5)
    for index, x in enumerate(range(int(x0) + 10, int(x1) - 4, 14)):
        kit.ball("CorniceRivet%d" % index, float(x), face + 1.8, 168.0, 0.9, steel, plan=0.5)
    for x in (x0 + 3.0, x1 - 3.0):
        kit.box("Corner", x - 3.0, x + 3.0, face - 2.0, face + 1.0, 10.0, 164.0, metal, bevel=0.6, uv="box_up")
    # The locker door: raised panels, a lattice vent, hinges, a heavy padlock.
    d0, d1 = 108.0, 170.0
    kit.box("Door", d0, d1, face - 0.5, face + 1.4, 16.0, 158.0, paint, bevel=0.8, uv="box")
    for part, (h0, h1) in (("PanelLow", (24.0, 84.0)), ("PanelMid", (90.0, 112.0))):
        kit.box("Door" + part, d0 + 7.0, d1 - 7.0, face + 1.0, face + 2.0, h0, h1, paint, bevel=0.6, uv="box")
    kit.box("VentRecess", d0 + 8.0, d1 - 8.0, face + 1.0, face + 1.5, 120.0, 150.0, hall._bakelite(), bevel=0.0)
    for index in range(7):
        x = d0 + 12.0 + index * 6.5
        kit.rod("VentBar%d" % index, (x, face + 2.0, 120.5), (x, face + 2.0, 149.5), 0.55, iron)
    for index, h in enumerate((126.0, 135.0, 144.0)):
        kit.rod("VentRail%d" % index, (d0 + 8.5, face + 2.2, h), (d1 - 8.5, face + 2.2, h), 0.5, iron)
    for index, h in enumerate((30.0, 140.0)):
        kit.cylinder("Hinge%d" % index, d0 - 0.5, face + 1.6, h - 6.0, h + 6.0, 2.2, iron, plan=2.2 * ROUND,
                     segments=12)
    kit.box("Hasp", 162.0, 186.0, face + 1.2, face + 2.2, 61.0, 69.0, iron, bevel=0.3)
    kit.box("Staple", 176.0, 180.0, face + 1.2, face + 4.6, 58.0, 72.0, iron, bevel=0.3)
    kit.box("Padlock", 168.0, 184.0, face + 3.0, face + 7.0, 44.0, 60.0, brass, bevel=1.4)
    cable(kit, "Shackle", [(171.0, face + 5.0, 60.0), (171.5, face + 5.0, 66.5), (176.0, face + 5.0, 70.0),
                           (180.5, face + 5.0, 66.5), (181.0, face + 5.0, 60.0)], 1.1, steel, resolution=8)
    kit.box("Keyhole", 175.2, 176.8, face + 7.0, face + 7.3, 48.0, 53.0, hall._bakelite(), bevel=0.0)
    # Bright brass round the keyhole: scratched by a key, and recently.
    face_ring(kit, "KeyScratch", 176.0, face + 7.25, 51.0, 2.6, 0.35, hall._metal("CircuitBrightBrass",
                                                                                   (0.9, 0.72, 0.36), 0.18))
    # The switchgear panel: the flush junction cover under plate 1, a
    # voltmeter, a dead pilot lamp and a nameplate.
    kit.box("Stile", 170.0, 176.0, face - 0.4, face + 0.8, 16.0, 158.0, metal, bevel=0.4, uv="box_up")
    kit.box("Panel", 176.0, 290.0, face - 0.3, face + 0.9, 16.0, 158.0, paint, bevel=0.6, uv="box")
    junction_cover(kit, "Junction", 180.0, 240.0, 94.0, 138.0, face + 0.9, paint)
    gauge(kit, "Volts", 265.0, face + 0.9, 116.0, 13.0, -0.35, small=True)
    kit.ball("Pilot", 265.0, face + 2.6, 147.0, 3.2, dead_red_glass(), plan=ROUND)
    face_ring(kit, "PilotCollar", 265.0, face + 1.8, 147.0, 3.6, 0.8, brass, segments=24, sides=6)
    kit.box("Nameplate", 186.0, 234.0, face + 0.9, face + 1.6, 144.0, 152.0, brass, bevel=0.3)
    # The loose access panel: askew, its corner screw gone, lifting off.
    corners, fronts = [], []
    pivot, tilt = (235.0, 51.0), math.radians(-2.2)
    for (x, h), lift in (((186.0, 22.0), 0.0), ((284.0, 22.0), 1.6), ((284.0, 80.0), 0.2), ((186.0, 80.0), 0.0)):
        dx, dh = x - pivot[0], h - pivot[1]
        corners.append((pivot[0] + dx * math.cos(tilt) - dh * math.sin(tilt),
                        pivot[1] + dx * math.sin(tilt) + dh * math.cos(tilt)))
        fronts.append(face + 2.2 + lift)
    plate(kit, "AccessPanel", corners, face + 0.9, fronts, paint)
    for index, (x, h) in enumerate(corners):
        if index == 1:
            face_disc(kit, "ScrewHole", x - 3.0, face + 1.0, h + 3.0, 1.2, 0.3, hall._bakelite(), segments=10,
                      bevel=0.0)
            continue
        inward = (3.4 if index in (0, 3) else -3.4, 3.4 if index in (0, 1) else -3.4)
        face_disc(kit, "AccessScrew%d" % index, x + inward[0], face + 3.0, h + inward[1], 1.4, 0.6, steel,
                  segments=10, bevel=0.0)
    for index in range(6):
        h = 30.0 + index * 7.0
        kit.box("AccessLouvre%d" % index, 200.0, 270.0, face + 2.3, face + 3.3, h, h + 2.4, metal, bevel=0.3)
    # On top: a coil of violet-wrapped cable, a toolbox and an oil can.
    top = 172.0
    for index, (dx, dy, dh) in enumerate(((0.0, 0.0, 2.2), (3.0, -2.0, 5.6), (-2.0, 2.0, 9.0))):
        kit.ring("CableCoil%d" % index, (142.0 + dx, back + 44.0 + dy, top + dh), (0.0, 0.0, 1.0), 17.0, 2.6,
                 violet_weave(), segments=40, sides=8)
    kit.box("Toolbox", 186.0, 238.0, back + 24.0, back + 50.0, top, top + 12.0, planks(), bevel=0.8, uv="box")
    kit.box("ToolboxBand", 186.0, 238.0, back + 49.6, back + 50.6, top + 9.0, top + 11.0, iron, bevel=0.2)
    kit.rod("ToolboxHandle", (196.0, back + 37.0, top + 15.0), (228.0, back + 37.0, top + 15.0), 0.9, iron)
    for x in (196.0, 228.0):
        kit.rod("ToolboxPost", (x, back + 37.0, top + 12.0), (x, back + 37.0, top + 15.0), 0.7, iron)
    kit.lathe("OilCan", 266.0, back + 42.0, [(0.0, top), (8.4, top), (8.6, top + 1.4), (8.0, top + 8.0),
                                             (4.0, top + 12.0), (1.8, top + 13.0), (1.6, top + 16.0),
                                             (0.0, top + 16.0)], brass, plan=ROUND)
    kit.rod("OilCanSpout", (272.0, back + 42.0, top + 9.0), (283.0, back + 44.0, top + 17.0), 0.8, brass)
    return kit


# ---------------------------------------------------------------- the workbench


def oil_lantern(kit, part, x, y, h):
    """A hurricane lantern: brass font, glass globe, wire guards, a bail."""
    brass, iron = hall._brass(), hall._cast_iron()
    kit.lathe(part + "Font", x, y, [(0.0, h), (7.6, h), (8.0, h + 1.5), (7.6, h + 6.0), (4.2, h + 8.0),
                                    (0.0, h + 8.0)], brass, plan=ROUND)
    globe = kit.lathe(part + "Globe", x, y, [(3.8, h + 8.0), (6.0, h + 12.0), (6.8, h + 18.0), (5.8, h + 24.0),
                                             (3.4, h + 27.0)], clear_glass(), plan=ROUND, close=False)
    globe.visible_shadow = False
    for side in (-1.0, 1.0):
        kit.rod(part + "Guard", (x + side * 7.4, y, h + 7.0), (x + side * 7.4, y, h + 28.0), 0.45, iron)
    kit.ring(part + "GuardRing", (x, y, h + 18.0), (0.0, 0.0, 1.0), 7.4, 0.4, iron, segments=24, sides=6)
    kit.lathe(part + "Cap", x, y, [(0.0, h + 27.0), (6.2, h + 27.0), (5.0, h + 30.0), (2.0, h + 33.0),
                                   (0.0, h + 33.0)], iron, plan=ROUND)
    cable(kit, part + "Bail", [(x - 7.4, y, h + 27.0), (x - 6.0, y, h + 35.0), (x, y, h + 38.0),
                               (x + 6.0, y, h + 35.0), (x + 7.4, y, h + 27.0)], 0.5, iron, resolution=8)
    kit.flame(part, x, y, h + 11.0, size=1.6, power=7.0, color=WARM)
    return (x, y, h + 15.0)


def shift_uvs(obj, du, dv):
    """Moves an object's UVs, so boards cut from one photo show their own grain."""
    for loop in obj.data.uv_layers[0].data:
        loop.uv = (loop.uv[0] + du, loop.uv[1] + dv)
    return obj


def wedge(kit, part, x0, x1, y_front, y_back, h_base, h_front, h_back, material, bevel=0.5):
    """A block whose top slopes from h_front at its south edge to h_back at
    its north edge: a console's sloped desk."""
    shape = bmesh.new()
    corners = [(x0, y_front, h_base), (x1, y_front, h_base), (x1, y_back, h_base), (x0, y_back, h_base),
               (x0, y_front, h_front), (x1, y_front, h_front), (x1, y_back, h_back), (x0, y_back, h_back)]
    verts = [shape.verts.new(corner) for corner in corners]
    for face in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        shape.faces.new([verts[index] for index in face])
    return uv_box(kit.shape(part, shape, material, bevel=bevel))


def lying(kit, part, outline, cx, cy, turn, h0, h1, material, bevel=0.6):
    """A flat thing lying on a surface: `outline` in its own (across, along)
    px, its along pointing `turn` radians east of plan north, at (cx, cy)."""
    cos_t, sin_t = math.cos(turn), math.sin(turn)
    placed = [(cx + u * cos_t + v * sin_t, cy + u * sin_t - v * cos_t) for u, v in outline]
    return uv_box(kit.slab(part, placed, h0, h1, material, plane="floor", bevel=bevel))


# A right work glove lying palm down, fingers along +v, cuff at v = 0.
GLOVE = [(-10.0, 0.0), (10.0, 0.0), (10.6, 9.0), (11.0, 20.0), (11.2, 30.5), (10.4, 33.0), (8.8, 33.6),
         (7.6, 32.6), (7.2, 23.6), (6.4, 23.4), (6.3, 36.2), (5.4, 38.4), (3.7, 38.8), (2.5, 37.8), (2.2, 24.2),
         (1.4, 24.2), (1.2, 39.4), (0.1, 41.0), (-1.6, 41.2), (-2.8, 39.8), (-3.0, 24.2), (-3.8, 23.8),
         (-4.1, 37.6), (-5.2, 39.2), (-6.8, 39.0), (-7.8, 37.4), (-8.1, 22.2), (-9.4, 19.2), (-13.8, 26.6),
         (-16.0, 27.4), (-17.4, 25.8), (-16.8, 23.4), (-12.4, 14.0), (-11.0, 8.6)]


def glove(kit, part, x, y, h, turn, leather_material, cuff_material):
    """A leather work glove lying palm down, a stitched seam down its back and
    its cuff in the castle's violet insulating weave."""
    lying(kit, part + "Hand", GLOVE, x, y, turn, h, h + 3.6, leather_material, bevel=1.3)
    lying(kit, part + "Cuff", [(-11.6, -7.0), (11.6, -7.0), (11.0, 1.6), (-11.0, 1.6)], x, y, turn, h, h + 4.4,
          cuff_material, bevel=1.4)
    lying(kit, part + "Seam", [(-0.5, 3.0), (0.5, 3.0), (0.5, 20.0), (-0.5, 20.0)], x, y, turn, h + 3.6, h + 3.9,
          hall._copper(), bevel=0.0)


def pliers(kit, part, x, y, h, turn):
    """Insulated pliers lying open: steel jaws and pivot, red-gripped handles."""
    steel = hall._steel()
    lying(kit, part + "Jaws", [(-1.7, 0.0), (1.7, 0.0), (2.6, 10.0), (-2.6, 10.0)], x, y, turn, h, h + 2.0, steel,
          bevel=0.4)
    lying(kit, part + "Pivot", circle(0.0, 11.0, 2.8, 14), x, y, turn, h, h + 2.4, steel, bevel=0.4)
    for side in (-1.0, 1.0):
        lying(kit, part + "Handle%+d" % side, [(side * 0.6, 12.0), (side * 2.6, 12.0), (side * 7.4, 36.0),
                                               (side * 4.8, 36.6)], x, y, turn, h, h + 1.8, steel, bevel=0.3)
        lying(kit, part + "Grip%+d" % side, [(side * 1.4, 18.0), (side * 3.6, 18.0), (side * 7.8, 36.4),
                                             (side * 4.6, 37.2)], x, y, turn, h + 0.3, h + 2.8, red_grip(), bevel=0.7)


def workbench():
    """The workbench: a heavy top of seven worn oak planks with a steel nosing
    and iron corner brackets, a vise, drawers, and a shadow board painted with
    each tool's outline, the insulated cutters' outline left empty. On it the
    instrument console holding the master junction plate (705, 595), the
    journal, a single glove, pliers, wire and the oil lantern, and a rag
    hanging over its front edge."""
    kit = RP.Kit("Workbench", prop="Workbench")
    x0, x1, _top, feet = WORKBENCH
    top, back = 52.0, feet - 150.0
    wood, brass, iron, steel, copper = oak(), hall._brass(), hall._cast_iron(), hall._steel(), hall._copper()
    rng = random.Random(29)
    for x in (x0 + 8.0, x1 - 8.0):
        for y in (back + 9.0, feet - 9.0):
            kit.box("Leg", x - 8.0, x + 8.0, y - 8.0, y + 8.0, 0.0, top - 9.0, wood, bevel=1.0, uv="box_up")
    kit.box("Shelf", x0 + 14.0, x1 - 14.0, back + 16.0, feet - 16.0, 8.0, 12.0, planks(), bevel=0.6, uv="box")
    kit.box("Frame", x0 + 2.0, x1 - 2.0, back + 2.0, feet - 2.0, top - 13.0, top - 1.4,
            hall._material("CircuitBenchShadow", lambda nodes, links: hall._principled(
                nodes, links, (0.02, 0.014, 0.01), roughness=0.9)), bevel=0.4)
    # Seven planks running east-west, each its own cut of the oak, a hairline apart.
    tones = [RP.textured("CircuitBenchOak%d" % index, "wood_table_worn", 0.42, value, (0.96, 0.8, 0.64),
                         saturation=0.92, ao=0.25) for index, value in enumerate((0.86, 1.0, 1.12))]
    count = 7
    span = (feet - back) / count
    for index in range(count):
        y0, y1 = back + index * span + 0.5, back + (index + 1) * span - 0.5
        board = kit.box("Plank%d" % index, x0, x1, y0, y1, top - 9.0, top + rng.uniform(-0.4, 0.3),
                        tones[rng.randrange(3)], bevel=0.9, uv="box")
        shift_uvs(board, rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0))
    for index, (cx, cy, rx, ry) in enumerate(((560.0, 640.0, 24.0, 12.0), (742.0, 712.0, 16.0, 8.0))):
        kit.quad("Stain%d" % index, [(cx - rx, cy + ry, top + 0.45), (cx + rx, cy + ry, top + 0.45),
                                     (cx + rx, cy - ry, top + 0.45), (cx - rx, cy - ry, top + 0.45)],
                 smudge("CircuitBenchStain", (0.03, 0.018, 0.012), 0.2, 0.9, scale=3.0))
    # The steel nosing along the front and iron brackets on the front corners.
    kit.box("Nosing", x0 - 0.4, x1 + 0.4, feet - 1.2, feet + 0.7, top - 9.4, top + 0.5, steel, bevel=0.3)
    for index, x in enumerate(range(int(x0) + 14, int(x1) - 8, 36)):
        kit.ball("NosingRivet%d" % index, float(x), feet + 0.8, top - 4.5, 0.9, iron, plan=0.5)
    for side, edge in ((1.0, x0), (-1.0, x1)):
        kit.box("Bracket", min(edge, edge + side * 24.0), max(edge, edge + side * 24.0), feet - 5.0, feet + 0.8,
                top + 0.2, top + 1.2, iron, bevel=0.3)
        kit.box("BracketSide", min(edge, edge + side * 5.0), max(edge, edge + side * 5.0), feet - 26.0, feet + 0.8,
                top + 0.2, top + 1.2, iron, bevel=0.3)
        kit.box("BracketDrop", min(edge, edge + side * 6.0), max(edge, edge + side * 6.0), feet + 0.6, feet + 1.6,
                top - 22.0, top + 1.0, iron, bevel=0.3)
        for bx, by in ((edge + side * 12.0, feet - 2.5), (edge + side * 2.5, feet - 14.0)):
            kit.ball("BracketBolt", bx, by, top + 1.6, 1.1, steel, plan=ROUND, squash=SIN)
    # Two banks of drawers under the top.
    for bank, (a, b) in enumerate(((470.0, 606.0), (668.0, 804.0))):
        kit.box("Bank%d" % bank, a, b, back + 22.0, feet - 2.0, 14.0, top - 9.0, wood, bevel=0.8, uv="box")
        for row, (h0, h1) in enumerate(((17.0, 28.0), (30.0, 41.0))):
            drawer = kit.box("Drawer%d_%d" % (bank, row), a + 4.0, b - 4.0, feet - 2.4, feet - 0.8, h0, h1,
                             tones[(bank + row) % 3], bevel=0.6, uv="box")
            shift_uvs(drawer, rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0))
            mid = (a + b) / 2.0
            kit.box("Pull%d_%d" % (bank, row), mid - 8.0, mid + 8.0, feet - 0.8, feet + 1.0, (h0 + h1) / 2.0 - 1.2,
                    (h0 + h1) / 2.0 + 1.2, brass, bevel=0.5)
            for px in (mid - 9.2, mid + 9.2):
                kit.ball("PullBolt%d_%d" % (bank, row), px, feet - 0.2, (h0 + h1) / 2.0, 0.9, brass, plan=0.5)
    kit.box("Crate", 614.0, 660.0, back + 60.0, feet - 20.0, 12.0, 34.0, planks(), bevel=0.8, uv="box")
    kit.ring("SpareCoil", (637.0, feet - 32.0, 35.0), (0.0, 0.0, 1.0), 12.0, 1.8, copper, segments=32, sides=6)
    # The vise on the front left corner.
    vx = 474.0
    kit.box("ViseBase", vx - 18.0, vx + 18.0, feet - 22.0, feet - 3.0, top, top + 3.0, iron, bevel=0.6)
    kit.box("ViseFixed", vx - 15.0, vx + 15.0, feet - 12.0, feet - 4.0, top + 3.0, top + 16.0, iron, bevel=0.8)
    kit.box("ViseMoving", vx - 15.0, vx + 15.0, feet + 1.5, feet + 7.0, top - 6.0, top + 16.0, iron, bevel=0.8)
    for part, (ya, yb) in (("JawFixed", (feet - 4.0, feet - 2.6)), ("JawMoving", (feet + 0.2, feet + 1.5))):
        kit.box("Vise" + part, vx - 14.0, vx + 14.0, ya, yb, top + 9.0, top + 15.0, steel, bevel=0.2)
    kit.rod("ViseScrew", (vx, feet - 2.6, top + 6.0), (vx, feet + 12.0, top + 6.0), 1.6, steel)
    kit.rod("ViseBar", (vx - 13.0, feet + 12.0, top + 6.0), (vx + 13.0, feet + 12.0, top + 6.0), 0.9, steel)
    for bx in (vx - 13.5, vx + 13.5):
        kit.ball("ViseKnob", bx, feet + 12.0, top + 6.0, 1.7, steel, plan=ROUND)
    # The shadow board: dark green paint, each tool hung on its pale outline.
    kit.box("BoardPostW", x0 + 3.0, x0 + 11.0, back, back + 8.0, top, 150.0, wood, bevel=0.6, uv="box_up")
    kit.box("BoardPostE", x1 - 11.0, x1 - 3.0, back, back + 8.0, top, 150.0, wood, bevel=0.6, uv="box_up")
    kit.box("BoardRail", x0 + 3.0, x1 - 3.0, back + 1.0, back + 8.0, 144.0, 150.0, wood, bevel=0.8, uv="box")
    kit.box("BoardBack", x0 + 11.0, x1 - 11.0, back + 2.0, back + 4.0, top, 144.0, wood, bevel=0.0)
    board_y = back + 4.1
    width, height = (x1 - 11.0) - (x0 + 11.0), 144.0 - top
    kit.quad("Pegboard", [(x0 + 11.0, board_y, top), (x1 - 11.0, board_y, top), (x1 - 11.0, board_y, 144.0),
                          (x0 + 11.0, board_y, 144.0)], pegboard(),
             uvs=((0.0, 0.0), (width, 0.0), (width, height), (0.0, height)))
    outlines = {
        "Spanner": [((0.5, 0.12), (0.5, 0.88))],
        "Hammer": [((0.5, 0.08), (0.5, 0.8)), ((0.14, 0.88), (0.86, 0.88))],
        "Driver": [((0.5, 0.06), (0.5, 0.94))],
        "Cutters": [((0.32, 0.05), (0.46, 0.6)), ((0.68, 0.05), (0.54, 0.6)), ((0.5, 0.58), (0.4, 0.95)),
                    ((0.5, 0.58), (0.6, 0.95))],
    }
    tools = (("Spanner", 484.0, 12.0, 70.0, 128.0), ("Spanner", 504.0, 12.0, 76.0, 124.0),
             ("Hammer", 536.0, 28.0, 72.0, 130.0), ("Driver", 566.0, 9.0, 80.0, 128.0),
             ("Driver", 582.0, 9.0, 84.0, 126.0), ("Cutters", 616.0, 30.0, 74.0, 130.0))
    for index, (kind, cx, wide, h0, h1) in enumerate(tools):
        kit.quad("Outline%d" % index, [(cx - wide / 2.0 - 2.0, board_y + 0.2, h0 - 2.0),
                                       (cx + wide / 2.0 + 2.0, board_y + 0.2, h0 - 2.0),
                                       (cx + wide / 2.0 + 2.0, board_y + 0.2, h1 + 2.0),
                                       (cx - wide / 2.0 - 2.0, board_y + 0.2, h1 + 2.0)],
                 shadow_paint("CircuitOutline" + kind, outlines[kind], 0.13 if kind not in ("Cutters", "Hammer")
                              else 0.07))
        hang = board_y + 2.0
        if kind == "Spanner":
            kit.box("Spanner%d" % index, cx - 2.0, cx + 2.0, hang, hang + 1.4, h0 + 8.0, h1 - 9.0, steel, bevel=0.4)
            face_ring(kit, "SpannerRing%d" % index, cx, hang + 0.7, h1 - 5.0, 3.6, 1.3, steel, segments=20, sides=6)
            kit.box("SpannerJaw%d" % index, cx - 4.4, cx + 4.4, hang, hang + 1.4, h0, h0 + 9.0, steel, bevel=0.6)
        elif kind == "Hammer":
            kit.rod("HammerHandle%d" % index, (cx, hang + 1.0, h0), (cx, hang + 1.0, h1 - 8.0), 1.8, hall._oak())
            kit.box("HammerHead%d" % index, cx - 12.0, cx + 12.0, hang, hang + 3.0, h1 - 9.0, h1, iron, bevel=0.8)
        elif kind == "Driver":
            kit.rod("DriverShaft%d" % index, (cx, hang + 1.0, h0 + 20.0), (cx, hang + 1.0, h1), 0.8, steel)
            kit.rod("DriverHandle%d" % index, (cx, hang + 1.0, h0), (cx, hang + 1.0, h0 + 21.0), 2.4, red_grip())
        for peg in ((cx - wide / 4.0, h1 - 2.0), (cx + wide / 4.0, h1 - 2.0)):
            kit.rod("Peg%d" % index, (peg[0], board_y, peg[1]), (peg[0], hang + 1.6, peg[1]), 0.5, steel)
    for index, (radius, tube) in enumerate(((13.0, 1.5), (10.6, 1.5), (8.2, 1.3))):
        face_ring(kit, "HangingCoil%d" % index, 650.0, board_y + 3.0 + index * 0.6, 120.0, radius, tube, copper,
                  segments=40, sides=6)
    kit.rod("SpoolRod", (676.0, board_y + 4.0, 134.0), (760.0, board_y + 4.0, 134.0), 1.0, iron)
    for index, (x, color) in enumerate(((692.0, (0.42, 0.18, 0.07)), (718.0, (0.3, 0.12, 0.5)),
                                        (744.0, (0.12, 0.1, 0.09)))):
        spool = braid("CircuitSpool%d" % index, color)
        face_disc(kit, "SpoolCore%d" % index, x, board_y + 10.0, 134.0, 7.0, 8.0, spool, segments=24)
        for side, offset in (("Back", 1.0), ("Front", 9.4)):
            uv_box(face_disc(kit, "Spool%s%d" % (side, index), x, board_y + offset + 0.8, 134.0, 9.8, 1.6, planks(),
                             segments=28))
    kit.quad("Diagram", [(778.0, board_y + 1.4, 92.0), (810.0, board_y + 1.4, 92.0), (810.0, board_y + 1.4, 138.0),
                         (778.0, board_y + 1.4, 138.0)], hall.material_blueprint())
    kit.box("DiagramClip", 788.0, 800.0, board_y + 1.4, board_y + 2.6, 134.0, 140.0, brass, bevel=0.3)
    # The instrument console: a walnut case round the master plate's flush
    # cover, a sloped desk of switches and a riser of dials.
    c0, c1, cback, cfront = 660.0, 750.0, 640.0, feet - 64.0
    walnut = RP.textured("CircuitWalnut", "wood_table_worn", 0.42, 0.52, (0.86, 0.6, 0.46), saturation=0.9, ao=0.25)
    paint = green_iron()
    kit.box("ConsoleCase", c0, c1, cback, cfront, top, 110.0, walnut, bevel=1.0, uv="box")
    kit.box("ConsoleFace", c0 + 3.0, c1 - 3.0, cfront - 0.2, cfront + 0.4, top + 3.0, 107.0, paint, bevel=0.3,
            uv="box")
    junction_cover(kit, "Master", 670.0, 740.0, 58.0, 106.0, cfront + 0.4, paint)
    for x in (c0 + 0.5, c1 - 0.5):
        kit.box("ConsoleCorner", x - 2.2, x + 2.2, cfront - 3.0, cfront + 0.9, top, 110.0, brass, bevel=0.5)
    wedge(kit, "ConsoleDesk", c0 - 2.0, c1 + 2.0, cfront + 1.5, cback - 2.0, 110.0, 110.0, 121.0, walnut, bevel=0.8)
    kit.box("ConsoleRiser", c0 + 4.0, c1 - 4.0, cback - 8.0, cback - 2.0, 120.0, 140.0, walnut, bevel=0.8, uv="box")
    for index, x in enumerate((684.0, 726.0)):
        gauge(kit, "ConsoleDial%d" % index, x, cback - 2.0, 130.0, 8.0, (-0.36, -0.3)[index], small=True)
    for index, x in enumerate((672.0, 690.0, 708.0, 726.0)):
        y = cfront - 14.0
        lift = 110.0 + 11.0 * (cfront + 1.5 - y) / (cfront + 1.5 - cback + 2.0)
        kit.cylinder("ToggleBoss%d" % index, x, y, lift, lift + 1.6, 2.4, brass, plan=2.4 * ROUND, segments=14)
        kit.rod("Toggle%d" % index, (x, y, lift + 1.6), (x, y + (3.0 if index % 2 else -3.0), lift + 6.0), 0.55,
                steel)
    for index, (x, color) in enumerate(((742.0, (0.36, 0.03, 0.02)), (742.0, (0.03, 0.2, 0.06)))):
        y = cfront - 8.0 - index * 12.0
        lift = 110.0 + 11.0 * (cfront + 1.5 - y) / (cfront + 1.5 - cback + 2.0)
        lamp = hall._material("CircuitPilot%d" % index, lambda nodes, links, c=color: hall._principled(
            nodes, links, c, roughness=0.15))
        kit.ball("Pilot%d" % index, x, y, lift + 1.6, 2.0, lamp, plan=ROUND)
    # On the top: the open journal, a glove, pliers, wire, the soldering iron, a tin of screws.
    jx0, jx1, jy0, jy1 = 516.0, 604.0, 682.0, 726.0
    kit.box("JournalCover", jx0 - 1.5, jx1 + 1.5, jy0 - 1.5, jy1 + 1.5, top + 0.4, top + 1.6,
            leather("CircuitJournalCover", (0.22, 0.08, 0.05)), bevel=0.4)
    for part, (a, b) in (("L", (jx0, (jx0 + jx1) / 2.0 - 0.8)), ("R", ((jx0 + jx1) / 2.0 + 0.8, jx1))):
        kit.box("JournalPages" + part, a, b, jy0, jy1, top + 1.6, top + 4.0, parchment(), bevel=0.6)
    kit.quad("JournalText", [(jx0, jy1, top + 4.05), (jx1, jy1, top + 4.05), (jx1, jy0, top + 4.05),
                             (jx0, jy0, top + 4.05)], journal_pages())
    kit.box("JournalRibbon", 566.0, 569.0, jy1 - 1.0, jy1 + 10.0, top + 0.6, top + 1.0,
            hall._cloth("CircuitRibbon", (0.38, 0.04, 0.05)), bevel=0.0)
    glove(kit, "Glove", 488.0, 690.0, top + 0.4, math.radians(-24.0),
          leather("CircuitGloveLeather", (0.3, 0.085, 0.05)), violet_weave())
    pliers(kit, "Pliers", 622.0, 708.0, top + 0.4, math.radians(64.0))
    for index, (dx, dh, radius) in enumerate(((0.0, 1.8, 15.0), (1.5, 4.4, 13.4), (-1.0, 7.0, 11.8))):
        kit.ring("WireCoil%d" % index, (548.0 + dx, 638.0, top + dh), (0.0, 0.0, 1.0), radius, 1.7, copper,
                 segments=40, sides=8)
    kit.lathe("IronStand", 612.0, 628.0, [(0.0, top), (7.0, top), (7.0, top + 1.6), (2.0, top + 3.0),
                                          (2.0, top + 6.0), (0.0, top + 6.0)], brass, plan=ROUND)
    kit.rod("SolderingIron", (606.0, 642.0, top + 2.0), (626.0, 620.0, top + 10.0), 1.0, steel)
    kit.rod("SolderingHandle", (592.0, 657.0, top + 1.2), (606.0, 642.0, top + 2.2), 2.6, hall._oak())
    kit.lathe("ScrewTin", 782.0, 712.0, [(0.0, top), (7.4, top), (7.4, top + 4.6), (6.8, top + 4.6),
                                         (6.8, top + 1.0), (0.0, top + 1.0)], hall._steel(), plan=ROUND)
    for index in range(6):
        turn = index * 1.05
        kit.ball("Screw%d" % index, 782.0 + 3.6 * math.cos(turn), 712.0 + 2.4 * math.sin(turn), top + 2.0, 1.2,
                 brass, plan=0.7)
    lantern = oil_lantern(kit, "Lantern", 796.0, back + 34.0, top)
    # The rag, dropped over the front edge.
    rag = kit.sheet("Rag", 548.0, 586.0, feet - 18.0, feet + 22.0, lambda x, y: top + 0.8,
                    RP.textured("CircuitRag", "cotton_jersey", 0.25, 0.62, (0.72, 0.68, 0.6), saturation=0.25,
                                ao=0.35), columns=34, rows=36)
    colliders = [obj for obj in kit.made if obj.name.startswith(("WorkbenchPlank", "WorkbenchNosing",
                                                                 "WorkbenchBank0", "WorkbenchDrawer0"))]
    RP.simulate_cloth(rag, colliders + [bpy.data.objects["RoomFloor"]], frames=40, mass=0.25, bending=0.8)
    solidify = rag.modifiers.new("Solidify", "SOLIDIFY")
    solidify.thickness = 0.5 * RP.PX
    solidify.offset = 0.0
    return kit, lantern


# ---------------------------------------------------------------- the dynamo


def generator():
    """The arcane dynamo on its bedplate: a flywheel behind, two field
    magnets in copper windings bridged by an iron yoke, the armature and its
    commutator facing the room, the regulator housing holding plate 2
    (1210, 595), and the arc chamber with its violet core."""
    kit = RP.Kit("Generator", prop="Generator")
    _x0, _x1, _top, feet = GENERATOR
    metal, paint, brass, copper, iron, steel = (dark_plate(), green_iron(), hall._brass(), hall._copper(),
                                                hall._cast_iron(), hall._steel())
    # A stone foundation under the iron bedplate, as heavy machines are set.
    kit.box("Foundation", 936.0, 1332.0, 604.0, feet, 0.0, 9.0, stone(), bevel=1.0, uv="box")
    kit.box("Bedplate", 946.0, 1322.0, 612.0, feet - 12.0, 9.0, 18.0, tread_plate(), bevel=1.2, uv="box")
    for part, box in (("N", (946.0, 1322.0, 612.0, 616.0)), ("S", (946.0, 1322.0, feet - 16.0, feet - 12.0)),
                      ("W", (946.0, 950.0, 612.0, feet - 12.0)), ("E", (1318.0, 1322.0, 612.0, feet - 12.0))):
        kit.box("BedTrim" + part, *box, 18.0, 19.4, brass, bevel=0.4)
    for index, x in enumerate(range(960, 1316, 30)):
        face_disc(kit, "BedBolt%d" % index, float(x), feet - 11.2, 13.5, 2.0, 1.2, steel, segments=6, bevel=0.0)
    kit.box("Maker", 1098.0, 1178.0, feet - 12.0, feet - 11.2, 10.5, 16.5, brass, bevel=0.3)
    # A brass guard rail along the bedplate's front.
    rail_y = feet - 17.0
    for index, x in enumerate(range(956, 1320, 52)):
        kit.rod("RailPost%d" % index, (float(x), rail_y, 19.5), (float(x), rail_y, 44.0), 1.1, brass)
        kit.ball("RailKnob%d" % index, float(x), rail_y, 45.0, 1.9, brass, plan=ROUND)
    for index, h in enumerate((31.0, 43.0)):
        kit.rod("Rail%d" % index, (956.0, rail_y, h), (1320.0, rail_y, h), 0.8, brass)
    # The flywheel behind the machine.
    cx, wheel_y, wheel_h, wheel_r = 1058.0, 642.0, 152.0, 104.0
    face_ring(kit, "FlywheelRim", cx, wheel_y, wheel_h, wheel_r, 7.5, iron, segments=96, sides=12)
    face_ring(kit, "FlywheelLip", cx, wheel_y + 6.5, wheel_h, wheel_r - 8.5, 1.4, brass, segments=96, sides=8)
    for spoke in range(6):
        turn = math.radians(30.0 + 60.0 * spoke)
        kit.rod("Spoke%d" % spoke, (cx + 15.0 * math.cos(turn), wheel_y, wheel_h + 15.0 * math.sin(turn)),
                (cx + (wheel_r - 5.0) * math.cos(turn), wheel_y, wheel_h + (wheel_r - 5.0) * math.sin(turn)), 3.0,
                iron)
    face_disc(kit, "Hub", cx, wheel_y + 8.0, wheel_h, 17.0, 16.0, brass)
    face_disc(kit, "HubCap", cx, wheel_y + 10.0, wheel_h, 7.0, 2.0, steel)
    for side in (-1.0, 1.0):
        kit.box("Pedestal", cx + side * 64.0 - 9.0, cx + side * 64.0 + 9.0, wheel_y - 8.0, wheel_y + 8.0, 16.0, 70.0,
                iron, bevel=0.8)
    # Field magnets, yoke, pole pieces round the armature, the commutator.
    for index, x in enumerate((1004.0, 1112.0)):
        kit.cylinder("FieldCore%d" % index, x, 690.0, 18.0, 152.0, 18.0, iron, plan=18.0 * ROUND)
        kit.cylinder("FieldCoil%d" % index, x, 690.0, 34.0, 136.0, 24.0, winding(), plan=24.0 * ROUND, segments=36)
        for h0, h1 in ((28.0, 35.0), (135.0, 142.0)):
            kit.cylinder("FieldFlange%d_%d" % (index, int(h0)), x, 690.0, h0, h1, 27.0, brass, plan=27.0 * ROUND,
                         segments=36)
    kit.box("Yoke", 978.0, 1138.0, 676.0, 704.0, 150.0, 176.0, iron, bevel=1.4)
    kit.box("YokeBand", 978.0, 1138.0, 704.0, 705.4, 158.0, 166.0, brass, bevel=0.3)
    for index, x in enumerate((1004.0, 1112.0)):
        kit.lathe("OilCup%d" % index, x, 690.0, [(0.0, 176.0), (4.0, 176.0), (3.0, 179.0), (5.2, 184.0),
                                                 (5.6, 188.0), (4.6, 190.0), (0.0, 190.0)], brass, plan=ROUND)
    kit.ring("LiftingEye", (cx, 690.0, 184.0), (0.0, 1.0, 0.0), 5.0, 1.4, steel, segments=24, sides=8)
    kit.cylinder("LiftingEyeStem", cx, 690.0, 176.0, 179.5, 2.2, steel, plan=2.2 * ROUND, segments=12)
    for x in (990.0, 1018.0, 1098.0, 1126.0):
        face_disc(kit, "YokeBolt", x, 704.6, 163.0, 2.4, 1.0, steel, segments=6, bevel=0.0)
    for x0, x1 in ((1008.0, 1026.0), (1090.0, 1108.0)):
        kit.box("PolePiece", x0, x1, 684.0, 742.0, 30.0, 122.0, iron, bevel=1.0)
    kit.slab("Armature", circle(cx, 76.0, 38.0, 40), 692.0, 744.0, winding(), bevel=0.6)
    face_ring(kit, "ArmatureBand", cx, 744.5, 76.0, 36.0, 2.0, brass)
    face_dial(kit, "Commutator", cx, 746.0, 76.0, 24.0, commutator())
    face_disc(kit, "Boss", cx, 750.0, 76.0, 6.0, 4.0, steel)
    face_ring(kit, "Rocker", cx, 749.0, 76.0, 32.0, 1.3, brass)
    for index, turn in enumerate((math.radians(55.0), math.radians(125.0))):
        bx, bh = cx + 27.0 * math.cos(turn), 76.0 + 27.0 * math.sin(turn)
        kit.box("Brush%d" % index, bx - 3.0, bx + 3.0, 747.0, 752.0, bh - 4.0, bh + 4.0, hall._bakelite(), bevel=0.5)
        kit.rod("BrushSpring%d" % index, (bx, 750.0, bh + 4.0), (cx + 32.0 * math.cos(turn), 750.0,
                                                                 76.0 + 32.0 * math.sin(turn) + 6.0), 0.6, copper)
    # The regulator housing: plate 2's flush cover, louvres and a gauge.
    r0, r1, rback, rfront = 1166.0, 1246.0, 650.0, 720.0
    kit.box("Regulator", r0, r1, rback, rfront, 16.0, 160.0, paint, bevel=1.2, uv="box")
    kit.box("RegulatorCap", r0 - 2.0, r1 + 2.0, rback - 2.0, rfront + 1.8, 160.0, 166.0, metal, bevel=0.8, uv="box")
    kit.box("RegulatorBase", r0 - 3.0, r1 + 3.0, rback - 3.0, rfront + 2.4, 16.0, 24.0, metal, bevel=0.8, uv="box")
    junction_cover(kit, "Regulator", 1180.0, 1240.0, 103.0, 147.0, rfront, paint)
    for slat in range(6):
        h = 34.0 + slat * 9.0
        kit.box("RegulatorLouvre%d" % slat, r0 + 12.0, r1 - 12.0, rfront, rfront + 1.6, h, h + 3.4, metal,
                bevel=0.3)
    kit.box("RegulatorPlate", r0 + 20.0, r1 - 20.0, rfront, rfront + 0.8, 90.0, 97.0, brass, bevel=0.3)
    kit.box("GaugeStem", 1203.0, 1209.0, 700.0, 706.0, 166.0, 172.0, brass, bevel=0.3)
    gauge(kit, "Regulator", 1206.0, 707.0, 182.0, 11.0, -0.35, small=True)
    # The arc chamber: a glass drum on a brass pedestal, electrodes top and
    # bottom, the violet core between them, arcs jumping to it.
    ax, ay = 1288.0, 708.0
    kit.lathe("ChamberPedestal", ax, ay, [(0.0, 16.0), (30.0, 16.0), (30.0, 22.0), (25.0, 26.0), (23.0, 52.0),
                                          (28.0, 58.0), (28.0, 64.0), (0.0, 64.0)], brass, plan=ROUND)
    glass = kit.lathe("ChamberGlass", ax, ay, [(24.0, 64.0), (24.6, 66.0), (24.6, 194.0), (24.0, 196.0)],
                      clear_glass(), plan=ROUND, close=False, segments=36)
    glass.visible_shadow = False
    kit.lathe("ChamberCap", ax, ay, [(0.0, 196.0), (28.0, 196.0), (28.0, 202.0), (22.0, 208.0), (12.0, 214.0),
                                     (5.0, 216.0), (0.0, 216.0)], brass, plan=ROUND)
    for index, h in enumerate((70.0, 190.0)):
        kit.ring("ChamberRing%d" % index, (ax, ay, h), (0.0, 0.0, 1.0), 25.6, 1.4, brass, segments=40, sides=8)
    for index in range(4):
        turn = math.pi / 4.0 + index * math.pi / 2.0
        px, py = ax + 26.6 * math.cos(turn), ay + 26.6 * ROUND * math.sin(turn)
        kit.rod("ChamberStay%d" % index, (px, py, 64.0), (px, py, 196.0), 0.9, brass)
    kit.ball("Terminal", ax, ay, 222.0, 5.0, brass, plan=ROUND)
    kit.rod("TerminalStem", (ax, ay, 214.0), (ax, ay, 218.0), 1.4, brass)
    kit.rod("ElectrodeLow", (ax, ay, 64.0), (ax, ay, 100.0), 1.6, steel)
    kit.ball("ElectrodeLowBall", ax, ay, 103.0, 4.2, brass, plan=ROUND)
    kit.rod("ElectrodeHigh", (ax, ay, 160.0), (ax, ay, 196.0), 1.6, steel)
    kit.ball("ElectrodeHighBall", ax, ay, 157.0, 4.2, brass, plan=ROUND)
    core = kit.ball("Core", ax, ay, 130.0, 8.0, core_glow(), plan=ROUND)
    core.visible_shadow = False
    arc = arc_glow()
    rng = random.Random(9)
    for index, (start, end) in enumerate((((ax, ay, 107.0), (ax, ay, 122.0)), ((ax, ay, 153.0), (ax, ay, 138.0)))):
        points = [start]
        for step in range(1, 4):
            t = step / 4.0
            points.append((start[0] + rng.uniform(-4.5, 4.5), start[1] + rng.uniform(-2.0, 2.0),
                           start[2] + (end[2] - start[2]) * t))
        points.append(end)
        for part, (a, b) in enumerate(zip(points[:-1], points[1:])):
            kit.rod("ChamberArc%d_%d" % (index, part), a, b, 0.5, arc).visible_shadow = False
    kit.light("Chamber", ax, ay + 4.0, 130.0, (0.58, 0.5, 1.0), 14.0, radius=0.06)
    RP.glow("crystal", ax, ay, 130.0, VIOLET, 30.0)
    # Copper leads: magnets to the regulator, the regulator to the chamber.
    for index, points in enumerate((
            [(1112.0, 700.0, 120.0), (1140.0, 706.0, 128.0), (1166.0, 700.0, 132.0)],
            [(1246.0, 690.0, 140.0), (1258.0, 700.0, 172.0), (ax - 4.0, ay, 222.0)])):
        cable(kit, "Lead%d" % index, points, 1.8, copper)
    # The maintenance tray, Prism Dust glittering in it.
    kit.box("Tray", 958.0, 1004.0, 772.0, 794.0, 19.5, 22.5, brass, bevel=0.6)
    kit.box("TrayDust", 961.0, 1001.0, 775.0, 791.0, 21.5, 23.0, prism_dust(), bevel=0.4)
    RP.glow("potion", 981.0, 783.0, 22.0, (0.7, 0.55, 1.0), 12.0)
    return kit, (ax, ay, 130.0)


# ---------------------------------------------------------------- the room


def moon_sky():
    """The Hall's moonlight (hall_prototype.add_sun: its colour, strength and
    softness), from the south-south-west and high, as the Wake Room has it."""
    data = bpy.data.lights.new("CircuitMoonSky", "SUN")
    data.energy = 1.15
    data.color = (0.72, 0.74, 1.0)
    data.angle = math.radians(12.0)
    sun = RP._link(bpy.data.objects.new("CircuitMoonSky", data))
    sun.rotation_euler = Vector((0.12, 0.38, -0.92)).normalized().to_track_quat("-Z", "Y").to_euler()


def grade(scene):
    """The room's exposure, set after the shared Cycles setup."""
    scene.view_settings.exposure = 0.3


def build(rp, layout):
    global RP
    RP = rp
    textures = rp.TEXTURES.available()
    shell_materials = {
        # Flagstones and wall blocks at the Wake Room's size; the wall tops
        # and their lit edges are the Hall's own.
        "floor": flagstones(),
        "wall": rp.textured("CircuitWall", "castle_wall_slates", 1.5, 0.54, (0.7, 0.66, 0.78), ao=0.3),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if textures
                else rp.textured("CircuitCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if textures
                else rp.textured("CircuitLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("CircuitReveal", "castle_wall_slates", 1.5, 0.6, (0.72, 0.68, 0.8), ao=0.2),
    }
    shell = rp.Shell(SPEC, shell_materials)
    shell.build()
    floor_dressing()
    back_wall_dressing()
    _board, bus_at = switchboard()
    hatch()
    _lamps, lamp_spots = wall_lamps(shell)
    for side in ("left", "right"):
        window(shell, side)
    exit_piers()
    exit_gate()
    moon_sky()
    props = {"Cabinet": cabinet()}
    props["Workbench"], lantern_at = workbench()
    props["Generator"], chamber_at = generator()
    # Where the game's light rig (circuit_room.gd) stands each fixture in the
    # painted room, and where this room has it: the preview moves it there.
    extras = layout.get("extras", {})
    fixtures = [{"from": spot, "to": [round(x, 2), round(y - h, 2)]}
                for spot, (x, y, h) in zip(extras.get("wall_lamp_positions", []), lamp_spots)]
    for key, (x, y, h) in (("bench_lantern_position", lantern_at), ("generator_chamber_position", chamber_at)):
        if key in extras:
            fixtures.append({"from": extras[key], "to": [round(x, 2), round(y - h, 2)]})
    if "broken_bus_position" in extras:
        fixtures.append({"from": extras["broken_bus_position"], "to": [round(bus_at[0], 2), round(bus_at[1], 2)]})
    print("CIRCUIT ROOM built: %d objects, %d glows, %d fixtures" % (len(bpy.data.objects), len(rp.GLOWS),
                                                                    len(fixtures)))
    return {"props": props, "meta": {"fixtures": fixtures}}
