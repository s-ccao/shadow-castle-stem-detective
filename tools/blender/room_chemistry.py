"""The Chemistry Room, Mrs. Lin's laboratory, for the Blender room prototype.
tools/blender/room_prototype.py imports it as room_chemistry and calls build()
on the room's exported collision (layout.json).

Positions are game px: x across, y the plan's y (south positive) and h screen
px up, so a thing at (x, y, h) shows at screen (x, y - h). The room is
1305 x 1206 and the game's camera follows the player through it. It is built
the way the Hall and the Wake Room are built (dark slate walls with mossy,
broken tops outlined in lit stone, flagstones, worn oak, the Hall's moonlight)
on the floor its collision blocks, so movement and every interaction stay the
game's own:

  north   the doorway to the Hall: the Hall's Chemistry portal (flask emblem,
          green fan glass) round a deep arch, its oak doors at the back where
          the player arrives, between two great candle pillars; the potion
          cabinet (Worldsort/ChemistryPotionCabinet) to the west and an open
          rack of jars and brassware to the east, crates stacked before it
  west    shelves of potions along the wall, a niche of herbs, a round candle
          table, a barrel and a sea chest, and the herb bed in the corner
  middle  the alchemy table (Worldsort/ChemistryLabTable): a great flask on a
          ring stand, an alembic still, a candelabra, a mortar, papers and
          broken glassware, a cloth slipping off its front; to its east the
          red stain spreads across the floor
  east    a work counter under shelves of jars along the wall, an alembic and
          green distillates on it
  south   a cauldron on a brick furnace where the painting has its arch,
          crates and barrels at either side, a purple runner

Furniture is built here or from CC0 Poly Haven models (crates, barrels, a sea
chest, brass candelabra and goblets, a clock, a lantern, apothecary vessels and
plants; tools/blender/cc0_models.json).
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import hall_prototype as hall
import room_wake as wake

RP = None
MODELS = None

BACK_Y = 187.0
WALL_H = 180.0
LEAN = 60.0
LEFT_BASE = ((200.0, BACK_Y), (150.0, 1150.0))
RIGHT_X = 1246.0
# The painted south wall runs from y 1134 (east) to 1200 (west); the cut-away
# wall stands between, and storage fills the strip behind it.
SOUTH_Y = 1172.0
NEAR = 1206.0 + WALL_H
# The doorway: as wide as the alcove the player arrives in, its doors at the
# alcove's back (the collision's y 121), its arch in the wall's face. The arch
# is a half ellipse, so the leaves stand taller than the detective (about 90
# px) under a wall 180 px high.
DOOR_X = (664.0, 828.0)
DOOR_SPRING = 100.0
DOOR_RISE = 45.0
DOOR_BACK = 121.0
DOOR_CENTRE = (DOOR_X[0] + DOOR_X[1]) / 2.0
DOOR_HALF = (DOOR_X[1] - DOOR_X[0]) / 2.0
GREEN = hall.DOOR_THEMES["Chemistry"][1]
CANDLE = (1.0, 0.6, 0.28)
VIOLET = (0.62, 0.36, 1.0)
ROUND = wake.ROUND
POTIONS = ((0.62, 0.3, 1.0), (1.0, 0.16, 0.22), (1.0, 0.5, 0.12), (0.3, 1.0, 0.45), (0.25, 0.55, 1.0),
           (1.0, 0.38, 0.75), (0.95, 0.8, 0.25))
# The alchemy table at a great work table's size (3.9 m by 2.2 m, 81 cm
# high), well inside the painted one's footprint: its plan rect, which the
# preview makes its collision, and its height. The rug under it.
TABLE = (425.0, 815.0, 445.0, 610.0)
TABLE_TOP = 52.0
RUG = (330.0, 910.0, 392.0, 688.0)
RUG_H = 0.5


def ellipse(cx, cz, rx, rz, start, end, steps):
    """Points along an ellipse in (x, h) screen px, `start` to `end` degrees."""
    return [(cx + rx * math.cos(math.radians(start + (end - start) * index / steps)),
             cz + rz * math.sin(math.radians(start + (end - start) * index / steps))) for index in range(steps + 1)]


def door_outline():
    """The doorway in the back wall, in (x, h): sill just off the floor so the
    opening stays a hole, a half-elliptical arch."""
    return [(DOOR_X[0], 0.5), (DOOR_X[1], 0.5)] + ellipse(DOOR_CENTRE, DOOR_SPRING, DOOR_HALF, DOOR_RISE, 0.0, 180.0,
                                                          30)


SPEC = {
    "back": {"y": BACK_Y, "base": (LEFT_BASE[0][0], RIGHT_X), "top": (LEFT_BASE[0][0] - LEAN, RIGHT_X + LEAN),
             "height": WALL_H, "openings": [{"outline": door_outline(), "depth": BACK_Y - DOOR_BACK}]},
    "left": {"base": LEFT_BASE, "near": NEAR},
    "right": {"base": ((RIGHT_X, BACK_Y), (RIGHT_X, 1150.0)), "near": NEAR},
    "south": {"y": SOUTH_Y, "height": 26.0, "depth": 70.0},
    "floor": {"x": (-60.0, 1365.0), "y": (100.0, 1300.0)},
    # The wall tops run on to the image's edges, so nothing outside shows.
    "cap": 160.0,
}


# ---------------------------------------------------------------- materials


def laid(name, asset, repeat, value, tint, saturation=0.6, per_island=False, variety=0.16, wear=0.0, ao=0.25,
         roughness=1.0, coat=0.0, coat_roughness=0.2, bevel=0.0):
    """A CC0 photo for pieces laid or built one by one (flagstones, boards, a
    table's parts), after the Greenhouse's laid_photo: each piece, a mesh
    island or with `per_island` False an object, shows its own part of the
    photo in its own shade, so no two read as one slab cut up. With `wear`
    its upper rims are worn paler; `ao` grimes its corners; `coat` lays a
    waxed or polished sheen over it that catches the candles; `bevel` (m)
    rounds its edges in the shading."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        if per_island:
            chance = nodes.new("ShaderNodeNewGeometry").outputs["Random Per Island"]
        else:
            chance = nodes.new("ShaderNodeObjectInfo").outputs["Random"]
        if RP.TEXTURES is None or not os.path.exists(RP.TEXTURES._path(asset, "diff")):
            low = tuple(channel * min(value, 1.0) * 0.2 for channel in tint)
            high = tuple(channel * min(value, 1.0) * 0.32 for channel in tint)
            hall._principled(nodes, links, hall._mix(nodes, links, chance, low, high), roughness=0.8)
            return
        maps = RP.TEXTURES.sample(nodes, links, asset, repeat=repeat)
        coords = next(node for node in nodes if node.type == "TEX_COORD")
        mapping = next(node for node in nodes if node.type == "MAPPING")
        width, height = next(node.image for node in nodes if node.type == "TEX_IMAGE").size
        if width and height and width != height:
            scale = mapping.inputs["Scale"].default_value
            mapping.inputs["Scale"].default_value = (scale[0], scale[1] * width / height, scale[2])
        shift = nodes.new("ShaderNodeCombineXYZ")
        links.new(op("MULTIPLY", chance, 7.31), shift.inputs["X"])
        links.new(op("MULTIPLY", chance, 3.77), shift.inputs["Y"])
        moved = nodes.new("ShaderNodeVectorMath")
        moved.operation = "ADD"
        links.new(coords.outputs["UV"], moved.inputs[0])
        links.new(shift.outputs[0], moved.inputs[1])
        links.new(moved.outputs[0], mapping.inputs["Vector"])
        color = hall._grade(nodes, links, maps["diff"], value, tint, saturation=saturation)
        tone = op("ADD", 1.0 - variety, op("MULTIPLY", chance, 2.0 * variety))
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
            pale = hall._mix(nodes, links, 1.0, color, (1.9, 1.85, 1.75), blend="MULTIPLY")
            color = hall._mix(nodes, links, op("MULTIPLY", rim, wear), color, pale)
        if ao > 0.0:
            color = hall._ao_multiply(nodes, links, color, distance=ao, floor_value=0.4)
        rough = maps["rough"]
        if roughness != 1.0:
            rough = op("MINIMUM", op("MULTIPLY", rough, roughness), 1.0)
        normal_in = maps["normal"] if bevel <= 0.0 else hall._bevelled(nodes, links, maps["normal"], bevel)
        shader = hall._principled(nodes, links, color, roughness=rough, normal=normal_in)
        if coat > 0.0:
            shader.inputs["Coat Weight"].default_value = coat
            shader.inputs["Coat Roughness"].default_value = coat_roughness
    return hall._material(name, build)


def aged_oak():
    """Mrs. Lin's furniture as the painting draws it: old, worn oak, dark and
    warm, each piece its own part and shade of a worn tabletop photo, its
    edges worn paler by hands and years, grime in its corners, under a
    waxed sheen that catches the candles."""
    return laid("ChemAgedOak", "wood_table", 1.0, 0.8, (0.94, 0.82, 0.7), saturation=0.78, variety=0.18,
                wear=0.4, ao=0.3, roughness=0.9, coat=0.32, coat_roughness=0.24, bevel=0.012)


def flagstone():
    """The floor's stones: worn grey rock (a 2 m photo), each stone its own
    part and shade of it, lavender as the painting grades them, its rim worn
    paler, faintly polished by feet."""
    return laid("ChemFlagstone", "rock_surface", 1.11, 1.0, (0.86, 0.82, 0.92), saturation=0.25, per_island=True,
                variety=0.3, wear=0.6, ao=0.12, roughness=0.9, coat=0.12, coat_roughness=0.32)


def grout():
    """The joints between the flagstones: dark mortar and the dirt in it."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=300.0, detail=6.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, (0.02, 0.018, 0.024), (0.055, 0.048, 0.052)),
                         roughness=0.95)
    return hall._material("ChemGrout", build)


def brick():
    """Old red castle brick (a 1.5 m photo), dimmed to the room's night."""
    return RP.textured("ChemBrick", "castle_brick_02_red", 0.83, 0.62, (0.92, 0.74, 0.66), saturation=0.72, ao=0.3)


def dressed_stone():
    return RP.textured("ChemDressedStone", "large_grey_tiles", 0.5, 0.82, (0.8, 0.76, 0.84), ao=0.15)


def tinted_glass(name, color, density=0.35):
    """Bottle glass with a colour of its own, as old apothecary glass has."""
    def build(nodes, links):
        shader = hall._principled(nodes, links, tuple(0.4 + 0.6 * c for c in color), roughness=0.06)
        shader.inputs["Transmission Weight"].default_value = 1.0
        shader.inputs["IOR"].default_value = 1.2
    return hall._material("ChemGlass" + name, build)


def potion(color, strength=0.45):
    """A coloured liquid; `strength` is how much it glows (shelf stock barely)."""
    return hall._liquid("ChemPotion%d%d%d_%d" % (tuple(int(c * 9) for c in color) + (int(strength * 100),)), color,
                        strength)


def ring_stain():
    """A dried ring where a wet vessel stood, UVs -1..1 across it."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        r = op("SQRT", op("ADD", op("MULTIPLY", u, u), op("MULTIPLY", v, v)))
        broken = hall._noise(nodes, links, coords.outputs["UV"], scale=3.0, detail=4.0)
        ring = op("MULTIPLY", op("LESS_THAN", op("ABSOLUTE", op("SUBTRACT", r, 0.8)), 0.07),
                  op("GREATER_THAN", broken, 0.38))
        shader = hall._principled(nodes, links, (0.05, 0.025, 0.012), roughness=0.5)
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", ring, 0.75))
    return hall._material("ChemRingStain", build)


def scorch():
    """A burn on the wood, black at its heart, fading out raggedly; UVs -1..1."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        r = op("SQRT", op("ADD", op("MULTIPLY", u, u), op("MULTIPLY", v, v)))
        ragged = hall._noise(nodes, links, coords.outputs["UV"], scale=2.5, detail=6.0)
        heat = hall._ramp(nodes, links, op("ADD", r, op("MULTIPLY", op("SUBTRACT", ragged, 0.5), 0.5)), 0.95, 0.2)
        shader = hall._principled(nodes, links, (0.012, 0.008, 0.006), roughness=0.85)
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", heat, 0.92))
    return hall._material("ChemScorch", build)


def powder(color):
    """Ground salts, dried herbs or crystals seen through a jar's glass."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=180.0, detail=3.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, color, tuple(c * 0.6 for c in color)),
                         roughness=0.9)
    return hall._material("ChemPowder%d%d%d" % tuple(int(c * 9) for c in color), build)


def slate():
    """Dark slate, a heat-proof slab under the burner."""
    return RP.textured("ChemSlate", "castle_wall_slates", 0.45, 0.32, (0.7, 0.7, 0.78), saturation=0.4, ao=0.1)


def cork():
    return hall._material("ChemCork", lambda nodes, links: hall._principled(nodes, links, (0.36, 0.24, 0.13),
                                                                            roughness=0.85))


def embers():
    """Coals glowing through a grate: hottest in the cracks."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords = nodes.new("ShaderNodeTexCoord")
        cells = nodes.new("ShaderNodeTexVoronoi")
        cells.feature = "DISTANCE_TO_EDGE"
        cells.inputs["Scale"].default_value = 120.0
        links.new(coords.outputs["Object"], cells.inputs["Vector"])
        crack = hall._ramp(nodes, links, cells.outputs["Distance"], 0.08, 0.0)
        flicker = hall._noise(nodes, links, coords.outputs["Object"], scale=60.0, detail=3.0)
        heat = op("MULTIPLY", crack, op("ADD", 0.4, flicker))
        color = hall._mix(nodes, links, heat, (1.0, 0.18, 0.02), (1.0, 0.62, 0.2))
        hall._principled(nodes, links, (0.03, 0.02, 0.02), roughness=0.9, emission=color,
                         emission_strength=op("MULTIPLY", heat, 6.0))
    return hall._material("ChemEmbers", build)


def brew():
    """The cauldron's murky green brew, a glow from deep in it."""
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        swirl = hall._noise(nodes, links, coords.outputs["Object"], scale=40.0, detail=5.0)
        color = hall._mix(nodes, links, hall._ramp(nodes, links, swirl, 0.42, 0.72), (0.03, 0.2, 0.06),
                          (0.35, 0.95, 0.4))
        hall._principled(nodes, links, (0.01, 0.05, 0.02), roughness=0.06, emission=color, emission_strength=0.32)
    return hall._material("ChemBrew", build)


def splatter(name, color, radius, spikes=13, seed=0.0, droplets=1.0, throw=None, carry=0.0):
    """Liquid splashed and drying on the flagstones, UVs in px from where it
    landed: a pool whose edge wanders, darker in a ring where it dried first
    (solute carried to the rim as it evaporates), a few short streaks thrown
    out from it and satellite drops round it. Wet and glossy only where it is
    still thick. A splash `throw`n one way (degrees, 0 east, 90 north) streaks
    up to `carry` radii further that way, as liquid flung from a falling
    flask does."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        uv = coords.outputs["UV"]
        r = op("DIVIDE", op("SQRT", op("ADD", op("MULTIPLY", u, u), op("MULTIPLY", v, v))), radius)
        wander = hall._noise(nodes, links, uv, scale=1.6 / radius, detail=3.0, roughness=0.5)
        ragged = hall._noise(nodes, links, uv, scale=6.0 / radius, detail=6.0, roughness=0.65)
        edge = op("ADD", op("ADD", r, op("MULTIPLY", op("SUBTRACT", wander, 0.5), 0.6)),
                  op("MULTIPLY", op("SUBTRACT", ragged, 0.5), 0.3))
        pool = op("LESS_THAN", edge, 0.62)
        # Streaks: in some of `spikes` directions, short and tapering.
        theta = op("ARCTAN2", v, u)
        bend = hall._noise(nodes, links, uv, scale=2.2 / radius, detail=2.0)
        angle = op("ADD", op("ADD", op("MULTIPLY", theta, spikes / (2.0 * math.pi)), seed),
                   op("MULTIPLY", op("SUBTRACT", bend, 0.5), 0.5))
        lane = op("ABSOLUTE", op("SUBTRACT", op("FRACT", angle), 0.5))
        lane_noise = nodes.new("ShaderNodeTexWhiteNoise")
        lane_noise.noise_dimensions = "1D"
        links.new(op("FLOOR", angle), lane_noise.inputs["W"])
        reach = op("ADD", 0.55, op("MULTIPLY", lane_noise.outputs["Value"], 0.5))
        if throw is not None:
            lane_middle = op("DIVIDE", op("SUBTRACT", op("ADD", op("FLOOR", angle), 0.5), seed),
                             spikes / (2.0 * math.pi))
            facing = op("MAXIMUM", op("COSINE", op("SUBTRACT", lane_middle, math.radians(throw))), 0.0)
            reach = op("ADD", reach, op("MULTIPLY", op("MULTIPLY", facing, facing),
                                        op("MULTIPLY", lane_noise.outputs["Value"], carry)))
        taper = op("SUBTRACT", 1.0, op("DIVIDE", op("ADD", r, op("MULTIPLY", op("SUBTRACT", ragged, 0.5), 0.2)), reach))
        spike = op("MULTIPLY", op("LESS_THAN", lane, op("MULTIPLY", taper, 0.15 / max(1.0, 1.0 + carry * 0.4))),
                   op("GREATER_THAN", taper, 0.0))
        # Toward its end a streak breaks into a run of drops.
        beads = hall._noise(nodes, links, uv, scale=9.0 / radius, detail=1.0)
        spike = op("MULTIPLY", spike, op("GREATER_THAN", beads, op("SUBTRACT", 0.62, op("MULTIPLY", taper, 0.9))))
        # Satellite drops, most just outside the pool, smaller further out.
        cells = nodes.new("ShaderNodeTexVoronoi")
        cells.inputs["Scale"].default_value = 9.0 / radius
        cells.inputs["Randomness"].default_value = 1.0
        links.new(uv, cells.inputs["Vector"])
        near = op("SUBTRACT", 1.0, op("MINIMUM", op("ABSOLUTE", op("SUBTRACT", r, 0.85)), 1.0))
        chosen = op("LESS_THAN", cells.outputs["Color"], op("MULTIPLY", near, 0.5 * droplets))
        size = op("MULTIPLY", op("SUBTRACT", 1.5, op("MINIMUM", r, 1.4)), 0.22)
        drop = op("MULTIPLY", op("LESS_THAN", cells.outputs["Distance"], size), chosen)
        wet = op("MINIMUM", op("ADD", op("ADD", pool, spike), drop), 1.0)
        # The dried ring at the pool's edge; the thick middle stays wet.
        rim = op("MULTIPLY", pool, op("GREATER_THAN", edge, 0.5))
        middle = hall._ramp(nodes, links, edge, 0.5, 0.15)
        tone = hall._mix(nodes, links, middle, tuple(c * 0.8 for c in color), tuple(min(c * 1.3, 1.0) for c in color))
        tone = hall._mix(nodes, links, rim, tone, tuple(c * 0.45 for c in color))
        roughness = op("ADD", 0.07, op("MULTIPLY", op("SUBTRACT", 1.0, middle), 0.45))
        shader = hall._principled(nodes, links, tone, roughness=roughness,
                                  normal=hall._bump(nodes, links, op("ADD", rim, op("MULTIPLY", middle, 0.4)), 0.25))
        shader.inputs["Coat Weight"].default_value = 0.35
        hall._alpha_cut(nodes, links, shader, op("MULTIPLY", wet, op("ADD", 0.82, op("MULTIPLY", rim, 0.15))))
    return hall._material("ChemSplatter" + name, build)


# ---------------------------------------------------------------- small things


def vial(kit, part, x, y, h, color, tall=9.0, radius=1.6, glow=0.45):
    """A stoppered test vial: a glass tube, its potion and a cork."""
    glass = kit.lathe(part + "Glass", x, y, [(radius * 0.8, h), (radius, h + 0.8), (radius, h + tall),
                                             (radius * 1.15, h + tall + 0.6)], wake.jar_glass(), plan=ROUND,
                      segments=12, close=False)
    glass.visible_shadow = False
    kit.lathe(part + "Fill", x, y, [(0.0, h + 0.5), (radius * 0.85, h + 0.9), (radius * 0.85, h + tall * 0.7),
                                    (0.0, h + tall * 0.7)], potion(color, glow), plan=ROUND, segments=12)
    kit.lathe(part + "Cork", x, y, [(0.0, h + tall - 0.6), (radius * 0.9, h + tall - 0.6),
                                    (radius * 1.05, h + tall + 2.2), (0.0, h + tall + 2.2)], cork(), plan=ROUND,
              segments=10)


def jar(kit, part, x, y, h, contents, tall=12.0, radius=5.0):
    """A wide-mouthed storage jar with a waxed lid: salts, herbs, crystals."""
    glass = kit.lathe(part + "Glass", x, y, [(radius * 0.92, h), (radius, h + 1.0), (radius, h + tall - 2.0),
                                             (radius * 0.86, h + tall)], wake.jar_glass(), plan=ROUND, segments=18,
                      close=False)
    glass.visible_shadow = False
    kit.lathe(part + "Fill", x, y, [(0.0, h + 0.4), (radius * 0.9, h + 0.6), (radius * 0.9, h + tall * 0.62),
                                    (0.0, h + tall * 0.66)], powder(contents), plan=ROUND, segments=18)
    kit.lathe(part + "Lid", x, y, [(0.0, h + tall), (radius * 0.98, h + tall), (radius * 0.98, h + tall + 1.6),
                                   (radius * 0.6, h + tall + 2.4), (0.0, h + tall + 2.4)], cork(), plan=ROUND,
              segments=18)


# Old apothecary glass: amber, brown, bottle green, oxblood, cobalt, violet,
# olive and clear with a straw-coloured tincture; bright potions are rarer.
SHELF_GLASS = ((0.55, 0.28, 0.06), (0.36, 0.17, 0.05), (0.1, 0.3, 0.12), (0.42, 0.06, 0.07), (0.12, 0.18, 0.36),
               (0.3, 0.13, 0.44), (0.32, 0.33, 0.1), (0.6, 0.52, 0.3))
def flask(kit, part, x, y, h, kind, color, size=1.0, glow=0.12):
    """The Wake Room's flask with a liquid that glows only as much as asked:
    plain tinctures barely, the brewing ones more."""
    vessel = wake.flask(kit, part, x, y, h, kind, color, size=size)
    kit.made[-2].data.materials[0] = potion(color, glow)
    return vessel


JAR_CONTENTS = ((0.55, 0.42, 0.25), (0.82, 0.8, 0.72), (0.3, 0.38, 0.2), (0.62, 0.15, 0.12), (0.35, 0.3, 0.42))


def vessel_spec(rng, scale=1.0):
    """A random vessel for a shelf, sized before it is placed: a flask, a
    stoppered vial or a lidded jar, with how wide (x px) and how deep (plan
    px) it stands."""
    roll = rng.random()
    color = rng.choice(POTIONS) if rng.random() < 0.18 else rng.choice(SHELF_GLASS)
    if roll < 0.42:
        kind = rng.choice(("round", "cone", "bottle", "bottle"))
        size = rng.uniform(0.75, 1.15) * scale
        width = {"round": 14.0, "cone": 15.0, "bottle": 8.0}[kind] * size
        return {"kind": kind, "size": size, "color": color, "width": width, "depth": width * 0.6}
    if roll < 0.68:
        return {"kind": "vial", "tall": rng.uniform(8.0, 12.0) * scale, "radius": 1.6 * scale, "color": color,
                "width": 4.0 * scale, "depth": 4.0 * scale * ROUND}
    radius = rng.uniform(4.0, 5.5) * scale
    return {"kind": "jar", "radius": radius, "tall": rng.uniform(10.0, 14.0) * scale,
            "contents": rng.choice(JAR_CONTENTS), "width": radius * 2.0 + 0.5, "depth": radius * 2.0 * ROUND + 0.5}


def make_vessel(kit, part, x, y, h, spec, glow=0.08):
    """Shelf stock: its liquids barely glow, as stored tinctures do not."""
    if spec["kind"] == "vial":
        vial(kit, part, x, y, h, spec["color"], tall=spec["tall"], radius=spec["radius"], glow=glow)
    elif spec["kind"] == "jar":
        jar(kit, part, x, y, h, spec["contents"], tall=spec["tall"], radius=spec["radius"])
    else:
        flask(kit, part, x, y, h, spec["kind"], spec["color"], size=spec["size"], glow=glow)


def stock_shelf(kit, part, x0, x1, y, h, rng, scale=1.0, gaps=0.15):
    """Vessels side by side along a shelf from x0 to x1, their middles on
    plan y."""
    x, index = x0, 0
    while True:
        if rng.random() < gaps:
            x += rng.uniform(4.0, 10.0)
        spec = vessel_spec(rng, scale)
        if x + spec["width"] > x1:
            break
        make_vessel(kit, "%s%d" % (part, index), x + spec["width"] / 2.0, y + rng.uniform(-2.0, 2.0), h, spec)
        x += spec["width"] + rng.uniform(1.0, 3.5)
        index += 1


def stock_column(kit, part, x_of, y0, y1, h, rng, scale=1.0, gaps=0.15, jitter=1.5, books=0.0, depth=14.0):
    """Vessels one behind another along plan y from y0 to y1, each centred
    across at x_of(y): a shelf or a bench along a side wall; a share
    `books` of the places hold a few books lying flat instead."""
    y, index = y0, 0
    while True:
        if rng.random() < gaps:
            y += rng.uniform(6.0, 14.0)
        if rng.random() < books and y + 22.0 < y1:
            x = x_of(y + 11.0)
            for layer in range(rng.randint(1, 3)):
                wake.closed_book(kit, "%sBook%d_%d" % (part, index, layer), x - depth / 2.0 + rng.uniform(0.0, 1.5),
                                 x + depth / 2.0 - rng.uniform(0.0, 1.5), y + rng.uniform(0.0, 2.0),
                                 y + 20.0 - rng.uniform(0.0, 2.0), h + layer * 4.0, 4.0,
                                 rng.choice(wake.BOOK_COLOURS))
            y += 24.0
            index += 1
            continue
        spec = vessel_spec(rng, scale)
        if y + spec["depth"] > y1:
            break
        middle = y + spec["depth"] / 2.0
        make_vessel(kit, "%s%d" % (part, index), x_of(middle) + rng.uniform(-jitter, jitter), middle, h, spec)
        y += spec["depth"] + rng.uniform(3.0, 8.0)
        index += 1


# The candleholder models' prickets, cm from the foot's centre (x east, y
# north, z up), measured on the meshes.
CUPS = {
    "brass_candleholder_01": ((0.0, 0.0, 36.6),),
    "brass_candleholder_02": ((-10.6, 0.0, 38.3), (0.0, 0.0, 40.1), (10.6, 0.0, 38.2)),
    "brass_candleholder_03": ((0.0, 0.0, 83.5), (-8.8, -14.8, 75.7), (8.8, -15.3, 75.7), (-8.7, 14.2, 75.7),
                              (9.0, 14.8, 75.7)),
}


def holder(kit, part, name, x, y, h, scale=1.0, turn=0.0, tall=9.0, radius=1.3, power=1.6):
    """A CC0 brass candleholder with a lit candle on each of its prickets."""
    MODELS.place(kit, "brass_candleholders", name, x, y, h, scale=scale, turn=turn)
    cos_t, sin_t = math.cos(math.radians(turn)), math.sin(math.radians(turn))
    for index, (dx, dy, dz) in enumerate(CUPS[name]):
        east, north = (dx * cos_t - dy * sin_t) * scale, (dx * sin_t + dy * cos_t) * scale
        kit.candle("%s%d" % (part, index), x + east, y - north / RP.STRETCH, h + (dz - 2.5) * scale * RP.SIN,
                   height=tall, radius=radius, power=power)


def model_top(asset, scale=1.0):
    """How high (screen px) an asset placed as a group stands."""
    objects = MODELS.load(asset).values()
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (max(c.z for c in corners) - min(c.z for c in corners)) / RP.PX * RP.SIN * scale


def copper():
    return hall._prop_metal("ChemCopper", (0.72, 0.36, 0.2), 0.32)


def soil():
    def build(nodes, links):
        coords = nodes.new("ShaderNodeTexCoord")
        grain = hall._noise(nodes, links, coords.outputs["Object"], scale=90.0, detail=8.0)
        hall._principled(nodes, links, hall._mix(nodes, links, grain, (0.045, 0.032, 0.024), (0.11, 0.08, 0.05)),
                         roughness=0.95, normal=hall._bump(nodes, links, grain, 0.5))
    return hall._material("ChemSoil", build)


def balance(kit, part, x, y, h):
    """A brass balance: a foot, a post, a beam and two pans on chains."""
    brass = hall._brass()
    kit.lathe(part + "Foot", x, y, [(0.0, h), (6.0, h), (6.0, h + 1.2), (2.0, h + 2.4), (0.0, h + 2.4)], brass,
              plan=ROUND)
    kit.rod(part + "Post", (x, y, h + 2.0), (x, y, h + 22.0), 0.8, brass)
    kit.ball(part + "Finial", x, y, h + 23.0, 1.3, brass)
    kit.rod(part + "Beam", (x - 11.0, y, h + 20.5), (x + 11.0, y, h + 20.5), 0.6, brass)
    for side in (-1.0, 1.0):
        px = x + side * 10.0
        for lean in (-1.0, 1.0):
            kit.rod(part + "Chain", (px, y, h + 20.5), (px + lean * 3.6, y, h + 10.6), 0.18, brass, segments=6)
        kit.lathe(part + "Pan", px, y, [(0.0, h + 9.6), (3.0, h + 9.9), (4.4, h + 10.8), (4.6, h + 11.1),
                                        (4.2, h + 11.0), (0.0, h + 10.2)], brass, plan=ROUND, segments=20)


def tube_rack(kit, part, x, y, h, colors, along="x"):
    """A wooden rack of test tubes, coloured as `colors` (None leaves a hole)."""
    oak = aged_oak()
    count = len(colors)
    if along == "x":
        kit.box(part + "Base", x - count * 2.6, x + count * 2.6, y - 3.0, y + 3.0, h, h + 2.0, oak, bevel=0.4)
        kit.box(part + "Shelf", x - count * 2.6, x + count * 2.6, y - 2.4, y + 2.4, h + 6.0, h + 7.4, oak, bevel=0.3)
        spots = [(x - count * 2.6 + 2.6 + 5.2 * index, y) for index in range(count)]
    else:
        kit.box(part + "Base", x - 3.0, x + 3.0, y - count * 2.0, y + count * 2.0, h, h + 2.0, oak, bevel=0.4)
        kit.box(part + "Shelf", x - 2.4, x + 2.4, y - count * 2.0, y + count * 2.0, h + 6.0, h + 7.4, oak, bevel=0.3)
        spots = [(x, y - count * 2.0 + 2.0 + 4.0 * index) for index in range(count)]
    for index, ((sx, sy), color) in enumerate(zip(spots, colors)):
        if color is not None:
            vial(kit, "%sTube%d" % (part, index), sx, sy, h + 1.0, color, tall=10.0, radius=1.4, glow=0.12)


def shards(kit, part, cx, cy, h, reach, count, rng):
    """Splinters of a broken flask lying round (cx, cy)."""
    glass = wake.jar_glass()
    for index in range(count):
        angle, distance = rng.uniform(0.0, 2.0 * math.pi), reach * math.sqrt(rng.random())
        x, y = cx + distance * math.cos(angle), cy + distance * math.sin(angle) * ROUND
        size, turn = rng.uniform(1.5, 4.0), rng.uniform(0.0, 2.0 * math.pi)
        points = [(x + size * math.cos(turn + offset) * stretch, y + size * math.sin(turn + offset) * stretch * ROUND)
                  for offset, stretch in ((0.0, 1.0), (2.3, rng.uniform(0.4, 0.8)), (3.9, rng.uniform(0.3, 0.7)))]
        shard = kit.slab("%s%d" % (part, index), points, h + 0.05, h + 0.35, glass, plane="floor")
        shard.visible_shadow = False


def shelf_unit(kit, part, x0, x1, back, front, height, levels, wood, plinth=6.0, crown=True, back_panel=True):
    """An open shelf case: plinth, sides, shelves at `levels`, top and crown."""
    kit.box(part + "Plinth", x0 - 1.0, x1 + 1.0, back, front + 1.5, 0.0, plinth, wood, bevel=0.8, uv="box")
    for side, (a, b) in (("W", (x0, x0 + 5.0)), ("E", (x1 - 5.0, x1))):
        kit.box(part + "Side" + side, a, b, back, front, plinth, height, wood, bevel=0.8, uv="box_up")
    if back_panel:
        kit.box(part + "Back", x0 + 5.0, x1 - 5.0, back, back + 1.8, plinth, height, wood, bevel=0.0, uv="box_up")
    for index, level in enumerate(levels):
        kit.box("%sShelf%d" % (part, index), x0 + 5.0, x1 - 5.0, back + 1.8, front - 0.5, level - 3.0, level, wood,
                bevel=0.5, uv="box")
        kit.box("%sLip%d" % (part, index), x0 + 5.0, x1 - 5.0, front - 2.0, front, level - 3.4, level + 0.6, wood,
                bevel=0.6, uv="box")
    kit.box(part + "Top", x0 - 1.0, x1 + 1.0, back - 0.5, front + 1.0, height, height + 3.0, wood, bevel=0.8,
            uv="box")
    if crown:
        kit.box(part + "Crown", x0 - 3.0, x1 + 3.0, back - 1.5, front + 3.0, height + 3.0, height + 6.5, wood,
                bevel=1.1, uv="box")


def lying_bottle(kit, part, x, y, length, radius, turn, color, h=0.0, spilled=True):
    """A bottle fallen on its side, neck toward `turn` degrees (0 east, 90
    south), its potion run out of it where it is `spilled`. Its length and
    radius are true sizes (x px), so it lies as long whichever way it points."""
    direction = Vector((math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND, 0.0))
    lift = radius * RP.SIN
    start = Vector((x, y, h + lift))
    body_end = start + direction * length * 0.7
    neck_end = start + direction * length
    glass = tinted_glass("Bottle%d%d%d" % tuple(int(c * 9) for c in color), color)
    kit.rod(part + "Body", tuple(start), tuple(body_end), radius, glass, segments=14).visible_shadow = False
    kit.rod(part + "Neck", tuple(body_end), tuple(neck_end), radius * 0.38, glass, segments=10).visible_shadow = False
    fill = 0.25 if spilled else 0.8
    low = Vector((0.0, 0.0, -lift * (1.0 - fill)))
    kit.rod(part + "Left", tuple(start + low), tuple(start + direction * length * 0.62 + low), radius * fill,
            potion(color, 0.3), segments=10)


# ---------------------------------------------------------------- the north wall


def doorway():
    """The way back to the Hall, built as the Hall's Chemistry portal is: a
    keyed stone arch round the opening, a dark enamel plaque with the flask in
    green on its keystone, and at the back of the deep reveal, where the
    player arrives, the oak double doors under a fanlight of green glass. The
    frame is flush with the wall's face: the floor before it is walkable. The
    reveal is deep, so the camera sees the doors' lower half through it."""
    kit = RP.Kit("Doorway")
    stone, pale, iron = dressed_stone(), hall._portal_stone(pale=True), hall._cast_iron()
    face = BACK_Y + 0.4
    x0, x1, centre, half, spring, rise = DOOR_X[0], DOOR_X[1], DOOR_CENTRE, DOOR_HALF, DOOR_SPRING, DOOR_RISE
    # Quoins up each side, alternately long and short, and the imposts.
    levels = (0.0, 20.0, 40.0, 60.0, 80.0, spring - 3.0)
    for side, edge in ((-1.0, x0), (1.0, x1)):
        for index, (low, high) in enumerate(zip(levels[:-1], levels[1:])):
            wide = 18.0 if index % 2 == 0 else 12.0
            a, b = (edge - wide, edge) if side < 0 else (edge, edge + wide)
            kit.box("Quoin", a + 0.4, b - 0.4, face - 8.0, face, low + 0.4, high - 0.4, stone, bevel=1.0, uv="box")
        a, b = (edge - 19.0, edge + 2.0) if side < 0 else (edge - 2.0, edge + 19.0)
        kit.box("Impost", a, b, face - 8.0, face + 0.3, spring - 3.0, spring + 1.0, pale, bevel=0.8, uv="box")
    # Eleven voussoirs round the half ellipse; the middle one is the
    # keystone, larger and paler.
    count = 11
    for index in range(count):
        low, high = 180.0 * index / count + 0.5, 180.0 * (index + 1) / count - 0.5
        key = index == count // 2
        reach = 24.0 if key else 15.0
        outline = ellipse(centre, spring, half, rise, low, high, 4) + list(reversed(
            ellipse(centre, spring, half + reach, rise + reach, low, high, 4)))
        kit.slab("Voussoir%d" % index, outline, face - 8.0, face + (0.4 if key else 0.0), pale if key else stone,
                 bevel=0.8)
    # The flask on a dark enamel plaque on the keystone.
    plaque = spring + rise + 12.0
    portal = hall.PropKit("ChemDoorCrest", {"centre": centre, "feet": face + 1.0, "width": 40.0, "height": 40.0,
                                            "depth": 4.0}, RP.STRETCH)
    portal.disc("Plaque", 0.0, 0.0, plaque, 7.5, 0.6, hall._painted("ChemPlaqueEnamel", (0.025, 0.022, 0.04)))
    portal.ring("PlaqueRim", 0.0, -0.3, plaque, 7.5, 0.5, hall._brass())
    hall._emblem(portal, "flask", GREEN, 0.0, plaque, 5.2, -0.5)
    for obj in portal.made:
        kit.keep(obj)
    RP.glow("crystal", centre, face, plaque, GREEN, 9.0)
    kit.box("Threshold", x0 - 2.0, x1 + 2.0, BACK_Y - 6.0, BACK_Y + 0.5, 0.0, 1.4, pale, bevel=0.6, uv="box")
    # The doors at the back of the reveal, and the fanlight over them.
    back = DOOR_BACK + 1.0
    oak = aged_oak()
    leaf_h = spring - 1.0
    for side, (a, b) in (("W", (x0 + 0.5, centre - 0.4)), ("E", (centre + 0.4, x1 - 0.5))):
        planks = 4
        width = (b - a) / planks
        for index in range(planks):
            kit.box("Leaf%sPlank%d" % (side, index), a + width * index + 0.25, a + width * (index + 1) - 0.25,
                    back - 2.4, back, 0.6, leaf_h, oak, bevel=0.5, uv="box_up")
        for low in (10.0, 44.0, leaf_h - 14.0):
            kit.box("Leaf%sStrap" % side, a + 1.0, b - 1.0, back, back + 0.7, low, low + 3.4, iron, bevel=0.3)
            for index in range(int((b - a - 4.0) / 9.0) + 1):
                kit.ball("Leaf%sStud" % side, a + 3.0 + index * 9.0, back + 0.9, low + 1.7, 0.8, iron, plan=0.5)
        pull = b - 9.0 if side == "W" else a + 9.0
        kit.ring("Leaf%sRing" % side, (pull, back + 1.6, 52.0), (0.0, 1.0, 0.0), 3.6, 0.7, iron, segments=24,
                 sides=8)
        kit.ball("Leaf%sBoss" % side, pull, back + 1.2, 55.6, 1.6, iron, plan=0.5)
    kit.box("Transom", x0, x1, back - 1.0, back + 1.0, spring - 1.5, spring + 1.5, iron, bevel=0.3)
    fan = RP.polygon_mesh("ChemFanGlass", ellipse(centre, spring, half - 1.0, rise - 1.0, 0.0, 180.0, 24), [],
                          lambda u, v: (u, back - 1.5, v), hall.material_fan_glass("FanGlassChemistry", GREEN))
    kit.keep(fan)
    kit.slab("FanRing", ellipse(centre, spring, half, rise, 0.0, 180.0, 24) + list(reversed(
        ellipse(centre, spring, half - 2.0, rise - 2.0, 0.0, 180.0, 24))), back - 1.2, back + 0.6, iron)
    for turn in (30.0, 60.0, 90.0, 120.0, 150.0):
        tip = ellipse(centre, spring, half - 1.5, rise - 1.5, turn, turn, 1)[0]
        kit.rod("FanBar", (centre, back, spring + 4.0), (tip[0], back, tip[1]), 0.7, iron, segments=8)
    kit.light("FanGlow", centre, back + 10.0, spring + 20.0, GREEN, 0.6, radius=0.2)
    # A lamp hangs in the passage, out of sight above the arch.
    kit.light("AlcoveLamp", centre, DOOR_BACK + 34.0, spring + 12.0, CANDLE, 5.0, radius=0.06)
    return kit


def open_sill():
    """The shell runs the doorway's reveal round its sill too, a face just
    over the floor; the sill is the floor, so those faces go and the room's
    flagstones show through the doorway."""
    reveal = bpy.data.objects.get("RoomReveal0")
    if reveal is None:
        return
    shape = bmesh.new()
    shape.from_mesh(reveal.data)
    low = [face for face in shape.faces
           if all(RP.game(reveal.matrix_world @ vert.co).z < 1.0 for vert in face.verts)]
    bmesh.ops.delete(shape, geom=low, context="FACES")
    shape.to_mesh(reveal.data)
    shape.free()


def door_sconces():
    """Iron candle bowls on stone pilasters either side of the doorway, where
    the painting has its candle pillars: the floor before the wall is walkable,
    so they hang from the wall rather than stand on it."""
    kit = RP.Kit("DoorSconces")
    stone, iron = dressed_stone(), hall._cast_iron()
    for index, x in enumerate((620.0, 872.0)):
        kit.box("Pilaster%d" % index, x - 18.0, x + 18.0, BACK_Y - 4.0, BACK_Y + 0.6, 0.0, WALL_H - 18.0, stone,
                bevel=1.0, uv="box_up")
        kit.box("PilasterBase%d" % index, x - 21.0, x + 21.0, BACK_Y - 4.0, BACK_Y + 0.8, 0.0, 10.0, stone,
                bevel=1.0, uv="box")
        kit.box("PilasterCap%d" % index, x - 21.0, x + 21.0, BACK_Y - 4.0, BACK_Y + 0.8, WALL_H - 22.0,
                WALL_H - 16.0, stone, bevel=1.0, uv="box")
        bowl_h = 112.0
        out = BACK_Y + 13.0
        kit.box("Plate%d" % index, x - 5.0, x + 5.0, BACK_Y + 0.5, BACK_Y + 1.6, bowl_h - 16.0, bowl_h + 2.0, iron,
                bevel=0.4)
        kit.rod("Arm%d" % index, (x, BACK_Y + 1.0, bowl_h - 10.0), (x, out, bowl_h - 3.0), 1.4, iron)
        kit.lathe("Bowl%d" % index, x, out, [(0.0, bowl_h - 6.0), (3.0, bowl_h - 6.0), (8.5, bowl_h - 1.0),
                                             (10.0, bowl_h + 1.5), (9.0, bowl_h + 1.8), (0.0, bowl_h - 1.0)], iron,
                  plan=ROUND)
        for part, (dx, dy, tall) in enumerate(((-3.0, 0.0, 15.0), (3.2, 1.0, 11.0), (0.0, 3.0, 8.0))):
            kit.candle("Candle%d_%d" % (index, part), x + dx, out + dy, bowl_h - 1.0, height=tall, radius=2.6,
                       power=11.0 if part == 0 else 1.5)
    return kit


def potion_cabinet():
    """The potion cabinet the game asks the player to search
    (Worldsort/ChemistryPotionCabinet): a tall oak dresser, cupboards below, a
    counter, and above it open shelves crowded with Mrs. Lin's potions."""
    kit = RP.Kit("PotionCabinet", prop="ChemistryPotionCabinet")
    oak, brass = aged_oak(), hall._brass()
    rng = random.Random(1801)
    x0, x1, back, front = 262.0, 582.0, 189.0, 231.0
    upper_front = 222.0
    kit.box("Plinth", x0 - 1.0, x1 + 1.0, back, front + 1.5, 0.0, 6.0, oak, bevel=0.8, uv="box")
    kit.box("Base", x0, x1, back, front, 6.0, 42.0, oak, bevel=0.8, uv="box")
    doors = 4
    width = (x1 - x0 - 8.0) / doors
    for index in range(doors):
        a = x0 + 4.0 + width * index
        kit.box("Door%d" % index, a + 1.0, a + width - 1.0, front, front + 1.4, 9.0, 39.0, oak, bevel=0.9,
                uv="box_up")
        kit.box("DoorPanel%d" % index, a + 7.0, a + width - 7.0, front + 1.2, front + 2.2, 14.0, 34.0, oak,
                bevel=1.2, uv="box_up")
        kit.ball("DoorKnob%d" % index, a + (width - 6.0 if index % 2 == 0 else 6.0), front + 2.4, 24.0, 1.6, brass)
    kit.box("Counter", x0 - 2.0, x1 + 2.0, back, front + 2.0, 42.0, 46.0, oak, bevel=1.0, uv="box")
    shelf_unit(kit, "Hutch", x0 + 4.0, x1 - 4.0, back, upper_front, 140.0, (78.0, 110.0), oak, plinth=46.0)
    for index, x in enumerate((x0 + 107.0, x0 + 213.0)):
        kit.box("Divider%d" % index, x - 2.0, x + 2.0, back + 1.8, upper_front, 46.0, 140.0, oak, bevel=0.6,
                uv="box_up")
    for level, scale in ((46.0, 1.0), (78.0, 0.95), (110.0, 0.95)):
        for bay in range(3):
            a = x0 + 10.0 + bay * 106.5
            stock_shelf(kit, "Potion%d_%d" % (int(level), bay), a, a + 96.0, (back + upper_front) / 2.0 + 1.0,
                        level, rng, scale=scale)
    # On the counter's lip, before the hutch: a few things set down to hand.
    vial(kit, "CounterVial", 300.0, 227.0, 46.0, POTIONS[1], tall=9.0)
    jar(kit, "CounterJar", 540.0, 226.0, 46.0, (0.82, 0.8, 0.72), tall=10.0, radius=4.5)
    # Potions glow faintly in the hutch: their colour on the wood.
    for index, (x, color) in enumerate(((330.0, POTIONS[0]), (440.0, POTIONS[2]), (520.0, POTIONS[3]))):
        kit.light("PotionGlow%d" % index, x, 214.0, 96.0, color, 0.35, radius=0.1)
    return kit


def north_east_rack():
    """An open rack of jars, bottles and brassware against the wall east of
    the doorway, and before it (on the collision) a crate with a box on it
    and a lantern on the floor."""
    kit = RP.Kit("NorthEastRack")
    oak, rng = aged_oak(), random.Random(77)
    x0, x1, back, front = 906.0, 1138.0, 189.0, 227.0
    shelf_unit(kit, "Rack", x0, x1, back, front, 150.0, (44.0, 80.0, 116.0), oak)
    for level in (6.0, 44.0, 80.0):
        stock_shelf(kit, "Rack%d" % int(level), x0 + 8.0, x1 - 8.0, (back + front) / 2.0, level, rng, gaps=0.25)
    for index, x in enumerate((922.0, 940.0, 958.0)):
        MODELS.place(kit, "brass_goblets", "brass_goblet_0%d" % (index + 1), x, 210.0, 116.0, scale=0.9)
    MODELS.place(kit, "brass_vase_03", None, 984.0, 210.0, 116.0, scale=1.2)
    MODELS.place(kit, "antique_ceramic_vase_01", None, 1014.0, 210.0, 116.0, scale=0.72)
    MODELS.group(kit, "Lantern_01", 1050.0, 211.0, 116.0, scale=1.1)
    kit.light("RackLantern", 1050.0, 211.0, 116.0 + 9.5 * 1.1 * RP.SIN, CANDLE, 2.5, radius=0.02)
    RP.glow("lantern", 1050.0, 211.0, 122.0, CANDLE, 12.0)
    MODELS.place(kit, "ceramic_vase_04", None, 1084.0, 210.0, 116.0, scale=0.85)
    jar(kit, "RackJar", 1116.0, 209.0, 116.0, JAR_CONTENTS[1], tall=13.0, radius=5.5)
    top = 156.5
    MODELS.group(kit, "mantel_clock_01", 952.0, 207.0, top, scale=1.0)
    for index, (x, colour) in enumerate(((1030.0, wake.BOOK_COLOURS[0]), (1033.0, wake.BOOK_COLOURS[2]),
                                         (1029.0, wake.BOOK_COLOURS[3]))):
        wake.closed_book(kit, "RackBook%d" % index, x, x + 32.0, 197.0, 219.0, top + index * 5.0, 5.0, colour)
    wake.candlestick(kit, "RackCandle", 1096.0, 208.0, top, wax_height=10.0, radius=2.2, power=4.0, stick=7.0)
    # Before it: a long crate on its side, a box on that, a lantern by them.
    crate_h = model_top("wooden_crate_02")
    MODELS.group(kit, "wooden_crate_02", 1056.0, 290.0, scale=1.0, turn=90.0)
    MODELS.group(kit, "wooden_crate_01", 1046.0, 289.0, h=crate_h, scale=0.9, turn=4.0)
    jar(kit, "CrateJar", 1092.0, 291.0, crate_h, JAR_CONTENTS[0], tall=12.0, radius=5.0)
    MODELS.group(kit, "wooden_lantern_01", 1100.0, 320.0, scale=0.9, turn=-20.0)
    kit.light("CrateLantern", 1100.0, 320.0, 8.0, CANDLE, 3.5, radius=0.02)
    RP.glow("lantern", 1100.0, 320.0, 10.0, CANDLE, 16.0)
    return kit


# ---------------------------------------------------------------- the west wall


def west_counter(shell):
    """A long apothecary counter down the west wall where the painting has
    its shelves, as deep as the floor before it allows (its back follows
    the wall's slant), crowded with jars, bottles, books and a balance, and
    two shelves on the leaning wall over it."""
    kit = RP.Kit("WestCounter")
    oak, rng = aged_oak(), random.Random(5150)
    y0, y1, front, top = 192.0, 553.0, 245.0, 46.0

    def wall(y, h=0.0):
        return shell.side_x("left", y, h)

    def run(part, x_front, ya, yb, low, high, material, inset=0.0, bevel=0.8):
        outline = [(wall(ya, low) + inset, ya), (x_front, ya), (x_front, yb), (wall(yb, low) + inset, yb)]
        piece = kit.slab(part, outline, low, high, material, plane="floor", bevel=bevel)
        RP.project_uvs(piece, "box")
        return piece

    run("Plinth", front - 3.0, y0 + 2.0, y1 - 2.0, 0.0, 5.0, oak)
    run("Body", front - 1.5, y0, y1, 5.0, top - 4.0, oak)
    run("Top", front + 1.5, y0 - 1.5, y1 + 1.5, top - 4.0, top, oak, bevel=1.0)
    # The end the camera sees: a panelled door.
    kit.box("EndDoor", wall(y1) + 6.0, front - 6.0, y1, y1 + 1.3, 9.0, top - 8.0, oak, bevel=0.9, uv="box_up")
    kit.box("EndPanel", wall(y1) + 11.0, front - 11.0, y1 + 1.1, y1 + 2.1, 14.0, top - 13.0, oak, bevel=1.2,
            uv="box_up")
    kit.ball("EndKnob", front - 10.0, y1 + 2.4, top / 2.0, 1.4, hall._brass())
    # Along the back, tall bottles and jars; along the front, the things in use.
    stock_column(kit, "Back", lambda y: wall(y, top) + 8.0, y0 + 4.0, y1 - 4.0, top, rng, gaps=0.2, books=0.12)
    wake.candlestick(kit, "CounterCandle", front - 9.0, 214.0, top, wax_height=9.0, radius=2.2, power=4.5, stick=6.0)
    for index, (colour, lift) in enumerate(((wake.BOOK_COLOURS[1], 0.0), (wake.BOOK_COLOURS[0], 5.0),
                                            (wake.BOOK_COLOURS[6], 9.5))):
        wake.closed_book(kit, "CounterBook%d" % index, front - 26.0 + index, front - 4.0 + index * 0.5, 246.0,
                         270.0 - index, top + lift, 5.0 - index * 0.5, colour)
    balance(kit, "Balance", front - 15.0, 312.0, top)
    stone = wake.stone()
    kit.lathe("Mortar", front - 12.0, 366.0, [(0.0, top), (4.6, top), (6.6, top + 4.0), (6.2, top + 7.0),
                                              (5.4, top + 7.0), (0.0, top + 2.0)], stone, plan=ROUND)
    kit.rod("Pestle", (front - 13.0, 366.0, top + 4.0), (front - 6.0, 360.0, top + 13.0), 1.2, stone)
    tube_rack(kit, "CounterTubes", front - 12.0, 404.0, top, (POTIONS[3], POTIONS[0], None, POTIONS[1], POTIONS[3]),
              along="y")
    MODELS.place(kit, "wicker_basket_01", "wicker_basket_01", front - 16.0, 446.0, top, scale=0.62, turn=90.0)
    for index in range(5):
        kit.ball("BasketHerb%d" % index, front - 20.0 + index * 2.2, 441.0 + (index % 3) * 4.0, top + 6.0, 3.2,
                 hall._cloth("ChemDriedHerb", (0.2, 0.24, 0.1)), plan=0.7, squash=0.6)
    for part, (a, b) in (("L", (478.0, 492.0)), ("R", (492.6, 506.0))):
        kit.box("BookPages" + part, front - 32.0, front - 6.0, a, b, top, top + 2.0, wake.parchment(), bevel=0.3)
    kit.quad("BookText", [(front - 32.0, 506.0, top + 2.05), (front - 6.0, 506.0, top + 2.05),
                          (front - 6.0, 478.0, top + 2.05), (front - 32.0, 478.0, top + 2.05)],
             wake.writing("ChemCounterBook", lines=8.0, gutter=True))
    wake.candlestick(kit, "CounterCandle2", front - 10.0, 532.0, top, wax_height=6.0, radius=2.2, power=4.0, stick=6.0)
    # Two shelves on the wall over it, on iron brackets.
    iron = hall._cast_iron()
    for shelf, level in enumerate((104.0,)):
        outline = [(wall(y0 + 6.0, level) - 2.0, y0 + 6.0), (wall(y0 + 6.0, level) + 16.0, y0 + 6.0),
                   (wall(y1 - 6.0, level) + 16.0, y1 - 6.0), (wall(y1 - 6.0, level) - 2.0, y1 - 6.0)]
        plank = kit.slab("Shelf%d" % shelf, outline, level - 3.0, level, oak, plane="floor", bevel=0.6)
        RP.project_uvs(plank, "box")
        for y in (y0 + 30.0, (y0 + y1) / 2.0, y1 - 30.0):
            x = wall(y, level)
            kit.rod("Bracket%d" % shelf, (x - 1.0, y, level - 16.0), (x + 13.0, y, level - 3.5), 0.9, iron)
        stock_column(kit, "Shelf%dVessel" % shelf, lambda y, level=level: wall(y, level) + 8.0, y0 + 10.0,
                     y1 - 10.0, level, rng, scale=0.85, gaps=0.35, books=0.18)
    return kit


def pedestal():
    """A stone pedestal in the corner by the counter's end, a great flask on
    it glowing violet: the room's strangest experiment."""
    kit = RP.Kit("Pedestal")
    rock = dressed_stone()
    x, y = 201.0, 585.0
    kit.box("Base", x - 17.0, x + 17.0, y - 22.0, y + 22.0, 0.0, 6.0, rock, uv="box")
    kit.box("Shaft", x - 13.0, x + 13.0, y - 17.0, y + 17.0, 6.0, 34.0, rock, uv="box_up")
    kit.box("Cap", x - 16.0, x + 16.0, y - 21.0, y + 21.0, 34.0, 39.0, rock, uv="box")
    kit.ring("StandRing", (x, y, 46.0), (0.0, 0.0, 1.0), 9.0, 0.7, hall._brass(), segments=28, sides=6)
    for turn in (90.0, 210.0, 330.0):
        dx, dy = math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND
        kit.rod("StandLeg", (x + dx * 9.0, y + dy * 9.0, 46.0), (x + dx * 12.0, y + dy * 12.0, 39.0), 0.6,
                hall._brass())
    flask(kit, "Great", x, y, 40.0, "round", VIOLET, size=1.9, glow=0.2)
    kit.light("GreatGlow", x, y, 52.0, VIOLET, 0.8, radius=0.05)
    RP.glow("crystal", x, y, 54.0, VIOLET, 24.0)
    return kit


def wall_sconces(shell):
    kit = RP.Kit("WallSconces")
    iron = hall._cast_iron()
    for index, (side, y) in enumerate((("left", 642.0), ("left", 930.0), ("right", 884.0))):
        frame = shell.mount(side, y)
        wall = frame.to_g(0.0, 100.0, 0.0)
        cup = frame.to_g(0.0, 96.0, 13.0)
        kit.box("Plate%d" % index, wall.x - 1.4, wall.x + 1.4, y - 4.0, y + 4.0, wall.z - 9.0, wall.z + 9.0, iron,
                bevel=0.4)
        kit.rod("Arm%d" % index, (wall.x, y, wall.z - 2.0), (cup.x, cup.y, cup.z), 1.0, iron)
        kit.lathe("Cup%d" % index, cup.x, cup.y, [(0.0, cup.z - 2.0), (2.0, cup.z - 2.0), (4.6, cup.z),
                                                    (4.6, cup.z + 1.4), (0.0, cup.z + 1.4)], iron)
        kit.candle("Sconce%d" % index, cup.x, cup.y, cup.z + 1.4, height=14.0, radius=2.8, power=13.0)
    return kit


def candle_table():
    """The round candle table by the niche, the painting's candles on it in
    a three-branched brass holder."""
    kit = RP.Kit("CandleTable")
    oak = aged_oak()
    cx, cy, radius, top = 214.0, 702.0, 37.0, 38.0
    kit.lathe("Top", cx, cy, [(0.0, top - 3.0), (radius, top - 3.0), (radius + 0.6, top - 1.5), (radius, top),
                              (0.0, top)], oak, plan=ROUND, segments=48, uv="box")
    kit.lathe("Column", cx, cy, [(0.0, 4.0), (5.0, 4.0), (3.0, 8.0), (2.6, 14.0), (4.2, 20.0), (2.6, 27.0),
                                 (3.4, top - 3.0), (0.0, top - 3.0)], oak, plan=ROUND, uv="box_up")
    for turn in (90.0, 210.0, 330.0):
        dx, dy = math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND
        kit.rod("Foot", (cx, cy, 5.0), (cx + dx * 18.0, cy + dy * 18.0, 0.8), 1.7, oak)
    holder(kit, "Candles", "brass_candleholder_02", cx - 2.0, cy - 4.0, top, scale=1.1, power=5.0)
    wake.closed_book(kit, "Book", cx + 8.0, cx + 30.0, cy + 6.0, cy + 22.0, top, 4.5, wake.BOOK_COLOURS[2])
    vial(kit, "Vial", cx - 24.0, cy + 10.0, top, POTIONS[1], tall=10.0)
    return kit


def west_storage():
    """A barrel, a bucket and a sea chest along the wall south of the table."""
    kit = RP.Kit("WestStorage")
    MODELS.group(kit, "wine_barrel_01", 284.0, 760.0, scale=0.9)
    lid = 83.7 * 0.9 * RP.SIN
    jar(kit, "BarrelJar", 276.0, 756.0, lid, JAR_CONTENTS[2], tall=12.0, radius=5.0)
    vial(kit, "BarrelVial", 292.0, 762.0, lid, POTIONS[5], tall=9.0)
    MODELS.group(kit, "wooden_bucket_01", 290.0, 813.0, scale=0.8, turn=20.0)
    MODELS.group(kit, "treasure_chest", 270.0, 862.0, scale=0.85)
    return kit


def herb_bed(shell):
    """A raised bed of herbs in the south-west corner: plank sides round
    dark earth, rows of the greenhouse's plants, a trowel left in it."""
    kit = RP.Kit("HerbBed")
    boards, earth = wake.planks(), soil()
    y0, y1, x1, rim = 958.0, SOUTH_Y - 2.0, 356.0, 22.0

    def wall(y):
        return shell.side_x("left", y)

    for part, (a, b, c, d) in (("North", (wall(y0), x1, y0, y0 + 5.0)), ("East", (x1 - 5.0, x1, y0, y1)),
                               ("South", (wall(y1), x1, y1 - 5.0, y1))):
        kit.box(part, a, b, c, d, 0.0, rim, boards, bevel=0.8, uv="box")
        kit.box(part + "Cap", a - 0.8, b + 0.8, c - 0.8, d + 0.8, rim, rim + 2.4, boards, bevel=0.7, uv="box")
    kit.slab("Earth", [(wall(y0 + 5.0) + 1.0, y0 + 5.0), (x1 - 5.0, y0 + 5.0), (x1 - 5.0, y1 - 5.0),
                       (wall(y1 - 5.0) + 1.0, y1 - 5.0)], 0.0, rim - 3.0, earth, plane="floor")
    rng = random.Random(1717)
    earth_h = rim - 3.0
    for row, y in enumerate(range(int(y0) + 16, int(y1) - 8, 15)):
        for column, x in enumerate(range(int(wall(y)) + 16, int(x1) - 10, 17)):
            if rng.random() < 0.06:
                continue
            px, py = x + rng.uniform(-4.0, 4.0) + (row % 2) * 8.0, y + rng.uniform(-3.0, 3.0)
            if px > x1 - 12.0:
                continue
            kind = rng.random()
            if kind < 0.3:
                asset, name = "periwinkle_plant", "periwinkle_plant_0%d_LOD0" % rng.randint(1, 6)
            elif kind < 0.5:
                asset, name = "nettle_plant", rng.choice(("nettle_plant_tall_a_LOD0", "nettle_plant_tall_b_LOD0",
                                                          "nettle_plant_medium_a_LOD0"))
            elif kind < 0.7:
                asset, name = "flower_heliophila", "flower_heliophila_small"
            elif kind < 0.85:
                asset, name = "flower_ursinia", "flower_ursinia_%s_LOD0" % rng.choice("abcd")
            else:
                asset, name = "weed_plant_02", "weed_plant_02_%s_LOD0" % rng.choice("abc")
            MODELS.place(kit, asset, name, px, py, earth_h, scale=rng.uniform(1.2, 1.7), turn=rng.uniform(0.0, 360.0))
    MODELS.place(kit, "trowel_01", "trowel_01", 322.0, 1110.0, earth_h, scale=1.0, turn=35.0)
    return kit


def runner():
    """The painting's purple runner on the floor between the bed and the crates."""
    kit = RP.Kit("Runner", depth=False)
    x0, x1, y0, y1 = 364.0, 414.0, 968.0, 1146.0
    length, width = y1 - y0, x1 - x0
    kit.box("Backing", x0 + 0.5, x1 - 0.5, y0 + 2.0, y1 - 2.0, 0.0, 0.7, hall._cloth("ChemRugBacking",
                                                                                       (0.07, 0.03, 0.09)), bevel=0.0)
    kit.quad("Rug", [(x0, y1, 0.8), (x1, y1, 0.8), (x1, y0, 0.8), (x0, y0, 0.8)], wake.rug_material(length, width),
             uvs=((length, 0.0), (length, width), (0.0, width), (0.0, 0.0)))
    return kit


def carpet(name, length, width):
    """The great rug under the table: a burgundy field with a lattice of
    small diamonds, a crimson medallion ringed in gold, an indigo border of
    running diamonds between gold guard stripes, indigo corners, knotted
    fringes at its ends; worn paler where feet cross it. UVs are px: u along
    its length (east), v across it (south)."""
    def build(nodes, links):
        op = hall._MathBuilder(nodes, links)
        coords, u, v = hall._uv_parts(nodes, links)
        to_end = op("MINIMUM", u, op("SUBTRACT", length, u))
        to_side = op("MINIMUM", v, op("SUBTRACT", width, v))
        edge = op("MINIMUM", op("SUBTRACT", to_end, 5.0), to_side)
        guard = op("MAXIMUM", op("LESS_THAN", edge, 4.0), op.between(edge, 30.0, 34.0))
        border = op("MULTIPLY", op("GREATER_THAN", edge, 5.5), op("LESS_THAN", edge, 28.5))
        diagonal_a = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("ADD", u, v), 17.0)), 0.5))
        diagonal_b = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", op("SUBTRACT", u, v), 17.0)), 0.5))
        running = op("MULTIPLY", border, op("LESS_THAN", op("ADD", diagonal_a, diagonal_b), 0.22))
        lattice_u = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", u, 14.0)), 0.5))
        lattice_v = op("ABSOLUTE", op("SUBTRACT", op("FRACT", op("DIVIDE", v, 14.0)), 0.5))
        field = op("GREATER_THAN", edge, 34.0)
        lattice = op("MULTIPLY", field, op("LESS_THAN", op("ADD", lattice_u, lattice_v), 0.14))
        across = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", v, width / 2.0)), width / 2.0 - 40.0)
        along = op("DIVIDE", op("ABSOLUTE", op("SUBTRACT", u, length / 2.0)), length / 2.0 - 40.0)
        lozenge = op("ADD", across, along)
        medallion = op("MULTIPLY", field, op("LESS_THAN", lozenge, 0.36))
        rings = op("MULTIPLY", field, op("MAXIMUM", op.between(lozenge, 0.36, 0.385), op.between(lozenge, 0.22, 0.235)))
        heart = op("MULTIPLY", field, op("LESS_THAN", lozenge, 0.08))
        corners = op("MULTIPLY", field, op("GREATER_THAN", lozenge, 1.82))
        color = hall._mix(nodes, links, lattice, (0.19, 0.03, 0.05), (0.28, 0.07, 0.06))
        color = hall._mix(nodes, links, op("MAXIMUM", medallion, corners), color, (0.05, 0.035, 0.12))
        color = hall._mix(nodes, links, op("MULTIPLY", medallion, op("LESS_THAN", lozenge, 0.22)), color,
                          (0.22, 0.03, 0.05))
        color = hall._mix(nodes, links, border, color, (0.045, 0.035, 0.11))
        color = hall._mix(nodes, links, op("MINIMUM", op("ADD", op("ADD", guard, rings), op("ADD", running, heart)),
                                           1.0), color, (0.46, 0.32, 0.1))
        weave = hall._noise(nodes, links, coords.outputs["UV"], scale=0.012, detail=5.0)
        path = op("SUBTRACT", 1.0, op("MINIMUM", op("ABSOLUTE", op("SUBTRACT", v, width * 0.82)), 40.0))
        wear = hall._ramp(nodes, links, op("ADD", weave, op("MULTIPLY", path, 0.006)), 0.58, 0.9)
        color = hall._mix(nodes, links, op("MULTIPLY", wear, 0.45), color, (0.3, 0.25, 0.22))
        fringe = op("LESS_THAN", to_end, 5.0)
        threads = op("LESS_THAN", op("FRACT", op("DIVIDE", v, 1.8)), 0.55)
        color = hall._mix(nodes, links, fringe, color, (0.52, 0.45, 0.34))
        roughness, normal = 0.95, None
        if RP.TEXTURES is not None and RP.TEXTURES.available():
            pile = RP.TEXTURES.sample(nodes, links, "dirty_carpet", repeat=40.0)
            fibres = hall._grade(nodes, links, pile["diff"], 2.6, (1.0, 1.0, 1.0), saturation=0.0)
            color = hall._mix(nodes, links, 0.55, color, hall._mix(nodes, links, 1.0, color, fibres, blend="MULTIPLY"))
            roughness, normal = pile["rough"], pile["normal"]
        shader = hall._principled(nodes, links, color, roughness=roughness, normal=normal)
        hall._alpha_cut(nodes, links, shader, op("SUBTRACT", 1.0, op("MULTIPLY", fringe, op("SUBTRACT", 1.0, threads))))
    return hall._material(name, build)


def table_rug():
    """The great rug the alchemy table stands on, east-west across the room's
    middle: the warmth in a stone room, and its frame."""
    kit = RP.Kit("TableRug", depth=False)
    x0, x1, y0, y1 = RUG
    length, width = x1 - x0, y1 - y0
    kit.box("Backing", x0 + 5.5, x1 - 5.5, y0 + 1.0, y1 - 1.0, -0.2, RUG_H - 0.1, hall._cloth("ChemRugBack",
                                                                                              (0.06, 0.02, 0.03)),
            bevel=0.0)
    kit.quad("Rug", [(x0, y1, RUG_H), (x1, y1, RUG_H), (x1, y0, RUG_H), (x0, y0, RUG_H)],
             carpet("ChemTableRug", length, width), uvs=((0.0, width), (length, width), (length, 0.0), (0.0, 0.0)))
    return kit


# ---------------------------------------------------------------- the south


def south_west_crates():
    kit = RP.Kit("SouthWestCrates")
    crate_h = model_top("wooden_crate_02")
    MODELS.group(kit, "wooden_crate_02", 455.0, 1098.0, scale=1.0)
    MODELS.group(kit, "wooden_crate_01", 457.0, 1086.0, h=crate_h, scale=0.85, turn=90.0)
    MODELS.group(kit, "wooden_crate_01", 540.0, 1124.0, scale=0.92, turn=-3.0)
    small_h = model_top("wooden_crate_01", 0.92)
    jar(kit, "CrateJar", 520.0, 1120.0, small_h, JAR_CONTENTS[1], tall=12.0, radius=5.0)
    MODELS.place(kit, "ceramic_vase_04", None, 556.0, 1122.0, small_h, scale=0.8)
    return kit


def hearth():
    """A brick hearth against the south wall where the painting has its arch:
    a half ring of old brick capped with stone round a bed of embers, and on
    them, on three short legs, the iron cauldron, its brew glowing green."""
    kit = RP.Kit("Hearth")
    bricks, cap, iron = brick(), dressed_stone(), hall._cast_iron()
    cx, cy, rx, ry, wall_h = 700.0, SOUTH_Y + 2.0, 92.0, 40.0, 24.0
    inner_rx, inner_ry = rx - 13.0, ry - 10.0

    def point(r_x, r_y, angle):
        return (cx + r_x * math.cos(math.radians(angle)), cy - r_y * math.sin(math.radians(angle)))

    steps = 16
    for index in range(steps):
        a0, a1 = 180.0 * index / steps, 180.0 * (index + 1) / steps
        ring = kit.slab("Wall%d" % index, [point(inner_rx, inner_ry, a0), point(rx, ry, a0), point(rx, ry, a1),
                                           point(inner_rx, inner_ry, a1)], 0.0, wall_h, bricks, plane="floor")
        RP.project_uvs(ring, "box")
        stone = kit.slab("Cap%d" % index, [point(inner_rx - 1.5, inner_ry - 1.2, a0 + 0.5),
                                           point(rx + 1.5, ry + 1.2, a0 + 0.5), point(rx + 1.5, ry + 1.2, a1 - 0.5),
                                           point(inner_rx - 1.5, inner_ry - 1.2, a1 - 0.5)], wall_h,
                         wall_h + 3.0, cap, plane="floor", bevel=0.6)
        RP.project_uvs(stone, "box")
    kit.slab("Embers", [point(inner_rx, inner_ry, angle) for angle in range(0, 181, 10)], 0.0, 6.0, embers(),
             plane="floor")
    pot_x, pot_y = cx, cy - 20.0
    for turn in (90.0, 210.0, 330.0):
        dx, dy = math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND
        kit.rod("PotLeg", (pot_x + dx * 18.0, pot_y + dy * 18.0, 13.0), (pot_x + dx * 22.0, pot_y + dy * 22.0, 5.0),
                2.0, iron)
    kit.lathe("Cauldron", pot_x, pot_y, [(0.0, 9.0), (12.6, 10.0), (22.6, 14.0), (27.1, 21.0), (28.0, 27.0),
                                         (26.2, 34.0), (23.5, 38.0), (24.0, 40.0), (25.8, 41.0), (25.8, 42.0),
                                         (23.0, 42.0), (21.7, 39.0)], iron, plan=ROUND, segments=48, close=False)
    kit.lathe("Brew", pot_x, pot_y, [(0.0, 37.6), (22.2, 37.6), (22.2, 36.6), (0.0, 36.6)], brew(), plan=ROUND,
              segments=48)
    rng = random.Random(4)
    for index in range(7):
        angle, distance = rng.uniform(0.0, 2.0 * math.pi), rng.uniform(0.0, 16.0)
        kit.ball("Bubble%d" % index, pot_x + distance * math.cos(angle),
                 pot_y + distance * math.sin(angle) * ROUND, 37.8, rng.uniform(1.2, 2.8), brew(), plan=ROUND,
                 squash=0.55)
    for side in (-1.0, 1.0):
        kit.ring("Handle", (pot_x + side * 26.5, pot_y, 36.0), (0.0, 1.0, 0.0), 3.6, 0.8, iron, segments=20, sides=6)
    kit.light("Fire", cx, cy - 16.0, 12.0, (1.0, 0.42, 0.12), 110.0, radius=0.3)
    kit.light("FireLow", cx - 40.0, cy - 10.0, 6.0, (1.0, 0.35, 0.08), 28.0, radius=0.2)
    kit.light("Brew", pot_x, pot_y, 48.0, GREEN, 6.0, radius=0.15)
    RP.glow("candle", cx, cy - 16.0, 8.0, (1.0, 0.45, 0.14), 70.0)
    RP.glow("crystal", pot_x, pot_y, 40.0, GREEN, 36.0)
    return kit


def south_east_storage():
    """Barrels, crates and jars stored against the south-east walls."""
    kit = RP.Kit("SouthEastStorage")
    MODELS.group(kit, "wine_barrel_01", 1212.0, 1036.0, scale=0.85)
    MODELS.group(kit, "wine_barrel_01", 1155.0, 1070.0, scale=0.8, turn=40.0)
    MODELS.group(kit, "wine_barrel_01", 1214.0, 1118.0, scale=0.8, turn=75.0)
    crate_h = model_top("wooden_crate_02", 0.95)
    MODELS.group(kit, "wooden_crate_02", 1000.0, 1072.0, scale=0.95, turn=90.0)
    MODELS.group(kit, "wooden_crate_01", 990.0, 1070.0, h=crate_h, scale=0.85, turn=-5.0)
    MODELS.place(kit, "ceramic_vase_04", None, 1040.0, 1074.0, crate_h, scale=0.9)
    MODELS.place(kit, "antique_ceramic_vase_01", None, 1105.0, 1070.0, scale=0.75)
    MODELS.group(kit, "wooden_crate_02", 992.0, 1128.0, scale=0.9, turn=90.0)
    MODELS.group(kit, "wooden_crate_01", 1112.0, 1132.0, scale=0.9, turn=2.0)
    MODELS.group(kit, "wooden_crate_01", 905.0, 1140.0, scale=0.85)
    return kit


# ---------------------------------------------------------------- the east wall


def alembic(kit, part, x, y, h):
    """A copper alembic over a brazier: the pot, its head, and the beak
    running south down to a receiving flask of green distillate."""
    iron, metal = hall._cast_iron(), copper()
    kit.lathe(part + "Brazier", x, y, [(0.0, h), (9.0, h), (10.0, h + 1.5), (8.0, h + 7.0), (9.5, h + 8.5),
                                       (8.6, h + 9.0), (0.0, h + 4.0)], iron, plan=ROUND)
    kit.flame(part + "Fire", x, y, h + 5.0, size=1.6, power=4.0, color=(1.0, 0.5, 0.18))
    pot = h + 9.0
    kit.lathe(part + "Pot", x, y, [(0.0, pot), (6.0, pot + 0.5), (10.5, pot + 5.0), (11.5, pot + 11.0),
                                   (9.0, pot + 17.0), (5.0, pot + 20.0), (5.0, pot + 22.0)], metal, plan=ROUND,
              close=False)
    head = pot + 21.0
    kit.lathe(part + "Head", x, y, [(5.6, head), (8.0, head + 3.0), (8.4, head + 7.0), (6.0, head + 11.0),
                                    (2.0, head + 13.0), (1.0, head + 15.0), (0.0, head + 15.5)], metal, plan=ROUND)
    kit.rod(part + "Beak", (x, y + 4.0, head + 7.0), (x - 2.0, y + 40.0, h + 24.0), 1.3, metal)
    flask(kit, part + "Receiver", x - 2.0, y + 44.0, h, "round", (0.3, 1.0, 0.45), size=0.9, glow=0.25)


def east_bench(shell):
    """The long work bench down the east wall (the painting's shelves): a
    stepped reagent rack along its back, and on its front an alembic,
    green distillates, a retort, test tubes, books and a lantern; two shelves
    of jars on the leaning wall over it."""
    kit = RP.Kit("EastBench")
    oak, rng = aged_oak(), random.Random(909)
    x0, x1, y0, y1, top = 1143.0, RIGHT_X + 2.0, 189.0, 764.0, 46.0
    kit.box("Plinth", x0 + 3.0, x1, y0, y1 - 2.0, 0.0, 5.0, oak, uv="box")
    kit.box("Body", x0 + 1.5, x1, y0, y1, 5.0, top - 4.0, oak, uv="box")
    kit.box("Top", x0 - 1.5, x1, y0, y1 + 1.5, top - 4.0, top, oak, bevel=1.0, uv="box")
    kit.box("EndDoor", x0 + 8.0, x1 - 10.0, y1, y1 + 1.3, 9.0, top - 8.0, oak, bevel=0.9, uv="box_up")
    kit.box("EndPanel", x0 + 13.0, x1 - 15.0, y1 + 1.1, y1 + 2.1, 14.0, top - 13.0, oak, bevel=1.2, uv="box_up")
    kit.ball("EndKnob", x0 + 12.0, y1 + 2.4, top / 2.0, 1.4, hall._brass())
    rack = 1206.0
    for step, (a, low, high) in enumerate(((rack, top, top + 18.0), (rack + 20.0, top + 18.0, top + 36.0))):
        kit.box("Step%d" % step, a, x1, y0, y1 - 6.0, low, high, oak, bevel=0.8, uv="box")
        stock_column(kit, "Step%dVessel" % step, lambda y, a=a: a + 10.0, y0 + 6.0, y1 - 12.0, high, rng, gaps=0.3,
                     books=0.1, depth=16.0)
    front = (x0 + rack) / 2.0
    alembic(kit, "Alembic", front + 4.0, 262.0, top)
    for index, (dx, y) in enumerate(((-10.0, 360.0), (6.0, 372.0), (-6.0, 388.0), (10.0, 398.0))):
        flask(kit, "Distillate%d" % index, front + dx, y, top, "bottle", (0.3, 1.0, 0.45), size=0.95, glow=0.15)
    tube_rack(kit, "BenchTubes", front, 436.0, top, (POTIONS[3], None, POTIONS[3], POTIONS[0], POTIONS[3], None))
    flask(kit, "Retort", front + 2.0, 486.0, top + 9.0, "round", POTIONS[2], size=1.1, glow=0.15)
    kit.lathe("RetortBurner", front + 2.0, 486.0, [(0.0, top), (5.2, top), (5.6, top + 4.0), (3.6, top + 7.0),
                                                   (1.0, top + 7.6), (0.0, top + 7.6)], hall._brass())
    kit.ring("RetortRing", (front + 2.0, 486.0, top + 9.5), (0.0, 0.0, 1.0), 6.5, 0.6, hall._brass(), segments=24,
             sides=6)
    kit.rod("RetortPost", (front + 12.0, 492.0, top), (front + 12.0, 492.0, top + 26.0), 0.8, hall._brass())
    for index, (colour, lift) in enumerate(((wake.BOOK_COLOURS[4], 0.0), (wake.BOOK_COLOURS[1], 5.5))):
        wake.closed_book(kit, "BenchBook%d" % index, front - 16.0, front + 12.0 - index * 2.0, 548.0 + index,
                         572.0, top + lift, 5.5, colour)
    MODELS.group(kit, "wooden_lantern_01", front, 610.0, top, scale=0.9, turn=15.0)
    kit.light("BenchLantern", front, 610.0, top + 8.0, CANDLE, 4.0, radius=0.02)
    RP.glow("lantern", front, 610.0, top + 10.0, CANDLE, 16.0)
    balance(kit, "BenchBalance", front, 670.0, top)
    wake.paper(kit, "BenchNote", front - 4.0, 720.0, top + 0.2, 24.0, 16.0, 0.2, wake.writing("ChemBenchNote",
                                                                                               lines=7.0))
    iron = hall._cast_iron()
    for shelf, level in enumerate((118.0,)):
        wall_a, wall_b = shell.side_x("right", y0 + 8.0, level), shell.side_x("right", y1 - 8.0, level)
        plank = kit.slab("Shelf%d" % shelf, [(wall_a - 16.0, y0 + 8.0), (wall_a + 2.0, y0 + 8.0),
                                             (wall_b + 2.0, y1 - 8.0), (wall_b - 16.0, y1 - 8.0)], level - 3.0,
                         level, oak, plane="floor", bevel=0.6)
        RP.project_uvs(plank, "box")
        for y in (y0 + 34.0, (y0 + y1) / 2.0, y1 - 34.0):
            x = shell.side_x("right", y, level)
            kit.rod("Bracket%d" % shelf, (x + 1.0, y, level - 16.0), (x - 13.0, y, level - 3.5), 0.9, iron)
        stock_column(kit, "Shelf%dVessel" % shelf, lambda y, level=level: shell.side_x("right", y, level) - 8.0,
                     y0 + 12.0, y1 - 12.0, level, rng, scale=0.85, gaps=0.35, books=0.18)
    return kit


# ---------------------------------------------------------------- the alchemy table


def decal(kit, part, cx, cy, h, radius, material, turn=0.0):
    """A round mark lying on a surface, UVs -1..1 across it, true to size."""
    corners = []
    for du, dv in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
        x = du * math.cos(turn) - dv * math.sin(turn)
        y = du * math.sin(turn) + dv * math.cos(turn)
        corners.append((cx + x * radius, cy - y * radius * ROUND, h))
    return kit.quad(part, corners, material, uvs=((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)))


def sphere_profile(radius, centre, start=-90.0, end=90.0, steps=16):
    """A lathe profile for a true sphere (x px radius) centred at screen
    height `centre`, from `start` to `end` degrees of latitude: with plan
    ROUND it is round in the 3D room, so the camera draws it as a circle."""
    return [(radius * math.cos(math.radians(start + (end - start) * index / steps)),
             centre + radius * math.sin(math.radians(start + (end - start) * index / steps)) * RP.SIN)
            for index in range(steps + 1)]


def spider_still(kit, part, x, y, h):
    """The painting's centrepiece: a great glass globe in a brass ring over a
    spirit burner, its neck stoppered, five glass arms running out of it and
    down into small receivers, a pale distillate glowing in it."""
    brass, glass = hall._brass(), wake.jar_glass()
    kit.lathe(part + "Burner", x, y, [(0.0, h), (6.0, h), (6.4, h + 3.5), (4.2, h + 7.0), (1.2, h + 8.0),
                                      (0.0, h + 8.0)], brass, plan=ROUND)
    kit.flame(part + "Burner", x, y, h + 8.0, size=1.4, power=2.6, color=(0.5, 0.7, 1.0))
    ring_h = h + 14.0
    kit.ring(part + "Ring", (x, y, ring_h), (0.0, 0.0, 1.0), 11.0, 0.8, brass, segments=36, sides=6)
    for turn in (90.0, 210.0, 330.0):
        dx, dy = math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND
        kit.rod(part + "Leg", (x + dx * 11.0, y + dy * 11.0, ring_h), (x + dx * 15.0, y + dy * 15.0, h), 0.8, brass)
    radius = 17.0
    centre = ring_h + radius * RP.SIN * 0.82
    globe = kit.lathe(part + "Globe", x, y, sphere_profile(radius, centre, -66.0, 78.0, 24)
                      + [(3.6, centre + radius * RP.SIN + 3.0), (3.2, centre + radius * RP.SIN + 16.0),
                         (4.0, centre + radius * RP.SIN + 17.0)], glass, plan=ROUND, segments=40, close=False)
    globe.visible_shadow = False
    kit.lathe(part + "Distillate", x, y, sphere_profile(radius - 1.0, centre, -62.0, -4.0, 12)
              + [(0.0, centre - 0.3)], potion((0.15, 0.6, 0.52), 0.12), plan=ROUND, segments=40)
    neck = centre + radius * RP.SIN + 17.0
    kit.lathe(part + "Stopper", x, y, [(0.0, neck - 2.0), (3.0, neck - 2.0), (3.6, neck + 1.0), (0.0, neck + 6.0)],
              tinted_glass("Stopper", (0.5, 0.75, 0.8)), plan=ROUND)
    for index, turn in enumerate((200.0, 250.0, 300.0, 345.0, 30.0)):
        dx, dy = math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND
        start = (x + dx * (radius - 1.0), y + dy * (radius - 1.0), centre + 1.0)
        bend = (x + dx * (radius + 14.0), y + dy * (radius + 14.0), centre + 4.0)
        foot = (x + dx * (radius + 19.0), y + dy * (radius + 19.0), h + 8.0)
        for piece, (a, b) in enumerate(((start, bend), (bend, foot))):
            arm = kit.rod("%sArm%d_%d" % (part, index, piece), a, b, 1.2, glass, segments=10)
            arm.visible_shadow = False
        bulb = kit.lathe("%sReceiver%d" % (part, index), foot[0], foot[1],
                         [(0.0, h)] + sphere_profile(4.2, h + 4.2 * RP.SIN, -70.0, 70.0, 8) + [(1.4, h + 8.6)],
                         glass, plan=ROUND, segments=16, close=False)
        bulb.visible_shadow = False
        kit.lathe("%sDrops%d" % (part, index), foot[0], foot[1], [(0.0, h + 0.5), (3.2, h + 1.0), (3.4, h + 2.4),
                                                                 (0.0, h + 2.4)],
                  potion((0.55, 0.95, 0.9), 0.4), plan=ROUND, segments=16)
    kit.light(part + "Glow", x, y + 22.0, centre + 10.0, (0.55, 0.95, 0.9), 0.9, radius=0.06)
    RP.glow("crystal", x, y, centre, (0.55, 0.95, 0.9), 30.0)


def globe_spire(kit, part, x, y, h, color):
    """A great glass globe with a tall pointed stopper, on a short foot."""
    glass = wake.jar_glass()
    radius = 12.5
    centre = h + 3.0 + radius * RP.SIN
    kit.lathe(part + "Foot", x, y, [(0.0, h), (6.5, h), (6.5, h + 1.2), (3.0, h + 3.4), (0.0, h + 3.4)],
              hall._brass(), plan=ROUND)
    globe = kit.lathe(part + "Globe", x, y, sphere_profile(radius, centre, -75.0, 80.0, 20)
                      + [(2.6, centre + radius * RP.SIN + 2.0)], glass, plan=ROUND, segments=36, close=False)
    globe.visible_shadow = False
    kit.lathe(part + "Fill", x, y, sphere_profile(radius - 0.8, centre, -72.0, -10.0, 10) + [(0.0, centre - 1.5)],
              potion(color, 0.12), plan=ROUND, segments=36)
    tip = centre + radius * RP.SIN + 2.0
    spire = kit.lathe(part + "Spire", x, y, [(0.0, tip - 1.0), (3.0, tip - 1.0), (3.4, tip + 2.0), (1.6, tip + 7.0),
                                             (1.1, tip + 16.0), (0.0, tip + 24.0)],
                      tinted_glass("Spire", (0.75, 0.75, 0.8)), plan=ROUND, segments=16)
    spire.visible_shadow = False


def screw_press(kit, part, x, y, h):
    """A small oak screw press for oils, iron-framed, its handle across."""
    oak, iron = aged_oak(), hall._cast_iron()
    kit.box(part + "Box", x - 16.0, x + 16.0, y - 8.0, y + 8.0, h, h + 14.0, oak, bevel=0.8, uv="box")
    kit.box(part + "Lid", x - 13.0, x + 13.0, y - 6.5, y + 6.5, h + 14.0, h + 16.0, oak, bevel=0.6, uv="box")
    for side in (-1.0, 1.0):
        kit.box(part + "Post", x + side * 14.0 - 1.4, x + side * 14.0 + 1.4, y - 1.4, y + 1.4, h + 14.0, h + 34.0,
                iron, bevel=0.3)
        kit.box(part + "Band", x + side * 12.0 - 1.0, x + side * 12.0 + 1.0, y - 8.4, y + 8.4, h + 0.5, h + 13.5, iron,
                bevel=0.2)
    kit.box(part + "Head", x - 16.0, x + 16.0, y - 2.0, y + 2.0, h + 34.0, h + 37.5, iron, bevel=0.4)
    kit.rod(part + "Screw", (x, y, h + 16.0), (x, y, h + 44.0), 1.4, iron)
    kit.rod(part + "Handle", (x - 13.0, y + 2.0, h + 42.0), (x + 13.0, y - 2.0, h + 42.0), 0.8, iron)
    for side in (-1.0, 1.0):
        kit.ball(part + "Knob", x + side * 13.6, y - side * 2.0, h + 42.0, 1.6, hall._brass())
    kit.box(part + "Spout", x - 3.0, x + 3.0, y + 8.0, y + 12.0, h + 2.0, h + 4.0, iron, bevel=0.3)


def tongs(kit, part, x, y, h, turn):
    """Iron crucible tongs lying open, `turn` degrees from east."""
    iron = hall._cast_iron()
    along = Vector((math.cos(math.radians(turn)), math.sin(math.radians(turn)) * ROUND, 0.0))
    across = Vector((-math.sin(math.radians(turn)), math.cos(math.radians(turn)) * ROUND, 0.0)) * 3.0
    pivot = Vector((x, y, h + 0.9))
    for side in (-1.0, 1.0):
        jaw = pivot + along * 14.0 + across * side * 0.6
        grip = pivot - along * 22.0 + across * side * 3.4
        kit.rod(part + "Jaw", tuple(pivot), tuple(jaw), 0.8, iron, segments=8)
        kit.rod(part + "Grip", tuple(pivot), tuple(grip), 0.8, iron, segments=8)
        kit.ring(part + "Bow", tuple(grip - along * 2.0), (0.0, 0.0, 1.0), 2.4, 0.6, iron, segments=16, sides=6)
    kit.ball(part + "Pivot", x, y, h + 1.2, 1.3, iron)


def beads(kit, part, rng, x0, x1, y0, y1, h, count):
    """Glass beads, drops and marbles strewn across the top."""
    glass = wake.jar_glass()
    for index in range(count):
        radius = rng.uniform(0.8, 2.0)
        bead = kit.ball("%s%d" % (part, index), rng.uniform(x0, x1), rng.uniform(y0, y1), h + radius * RP.SIN,
                        radius, glass if rng.random() < 0.7 else potion(rng.choice(POTIONS), 0.2), plan=ROUND,
                        squash=RP.SIN)
        bead.visible_shadow = False


def alchemy_table():
    """The alchemy table the game asks the player to search
    (Worldsort/ChemistryLabTable), as the painting draws it but at a real
    table's size: heavy worn oak on turned legs, a panelled drawer front
    with brass ring pulls and violet enamel, a top of boards between
    breadboard ends with a raised rim along its sides, a pot-board below.
    On it, as painted: the great glass still with its arms in the middle, an
    oil press, a tall flask, a dark flask, a three-candle candelabra and a
    spired globe along the back, yellow-green bottles, a rack of violet
    vials, tongs, strewn beads and glass, and at its south-east corner the
    red spill running over the edge to the floor. Someone's blue coat with
    a buckled strap hangs over the front edge."""
    kit = RP.Kit("AlchemyTable", prop="ChemistryLabTable")
    oak, brass = aged_oak(), hall._brass()
    rng = random.Random(2024)
    x0, x1, y0, y1 = TABLE
    top = TABLE_TOP
    # Legs: a block under the drawers and at the foot, turned between, on
    # bun feet; an H-stretcher and a pot-board between them.
    for lx in (x0 + 11.0, x1 - 11.0):
        for ly in (y0 + 10.0, y1 - 10.0):
            kit.lathe("LegFoot", lx, ly, [(0.0, 0.0), (7.2, 0.0), (8.0, 2.0), (6.8, 4.5), (0.0, 4.5)], oak, plan=ROUND,
                      segments=20, uv="box_up")
            kit.box("LegBlock", lx - 6.0, lx + 6.0, ly - 4.6, ly + 4.6, 4.5, 12.0, oak, bevel=0.8, uv="box_up")
            kit.lathe("LegTurn", lx, ly, [(0.0, 12.0), (5.0, 12.0), (6.0, 14.5), (3.8, 18.0), (5.6, 23.0),
                                          (6.2, 26.5), (4.2, 30.5), (3.6, top - 24.0), (5.2, top - 22.5),
                                          (0.0, top - 22.5)], oak, plan=ROUND, segments=20, uv="box_up")
            kit.box("LegTop", lx - 6.2, lx + 6.2, ly - 4.8, ly + 4.8, top - 23.0, top - 5.0, oak, bevel=0.8,
                    uv="box_up")
    for lx in (x0 + 11.0, x1 - 11.0):
        kit.box("EndStretcher", lx - 2.4, lx + 2.4, y0 + 14.0, y1 - 14.0, 6.0, 10.0, oak, bevel=0.6, uv="box")
    kit.box("PotBoard", x0 + 17.0, x1 - 17.0, y0 + 14.0, y1 - 14.0, 8.0, 10.0, oak, bevel=0.6, uv="box")
    # On the pot-board: books, a copper pan, a crate of bottles.
    for index, (bx, colour) in enumerate(((x0 + 30.0, wake.BOOK_COLOURS[0]), (x0 + 33.0, wake.BOOK_COLOURS[3]))):
        wake.closed_book(kit, "LowBook%d" % index, bx, bx + 28.0, y0 + 40.0, y0 + 62.0, 10.0 + index * 5.0, 5.0, colour)
    kit.lathe("LowPan", x0 + 120.0, (y0 + y1) / 2.0, [(0.0, 10.0), (13.0, 10.0), (14.5, 16.0), (15.0, 17.0),
                                                     (13.6, 16.6)], copper(), plan=ROUND, close=False)
    MODELS.group(kit, "wooden_crate_01", x1 - 80.0, (y0 + y1) / 2.0, h=10.0, scale=0.5, turn=3.0)
    for index in range(4):
        flask(kit, "LowBottle%d" % index, x1 - 98.0 + index * 11.0, (y0 + y1) / 2.0 - 2.0, 10.0 + 11.0, "bottle",
              rng.choice(SHELF_GLASS), size=0.8)
    # The drawers along the front, with ring pulls; violet enamel between.
    low, high = top - 21.0, top - 5.0
    front = y1 - 3.0
    kit.box("ApronFront", x0 + 6.0, x1 - 6.0, front - 3.0, front, low, high, oak, bevel=0.6, uv="box")
    kit.box("ApronBack", x0 + 6.0, x1 - 6.0, y0 + 6.0, y0 + 9.0, low, high, oak, bevel=0.6, uv="box")
    for side, x in (("W", x0 + 6.0), ("E", x1 - 9.0)):
        kit.box("ApronEnd" + side, x, x + 3.0, y0 + 9.0, front - 3.0, low, high, oak, bevel=0.6, uv="box")
    count, stile = 4, 9.0
    width = (x1 - x0 - 24.0 - stile * (count - 1)) / count
    middle = (low + high) / 2.0
    enamel = hall._painted("ChemEnamelViolet", (0.32, 0.12, 0.5))
    for index in range(count):
        a = x0 + 12.0 + index * (width + stile)
        b = a + width
        kit.box("Drawer%d" % index, a, b, front, front + 1.3, low + 2.0, high - 2.0, oak, bevel=0.7, uv="box")
        kit.box("DrawerPanel%d" % index, a + 5.0, b - 5.0, front + 1.1, front + 2.0, low + 4.6, high - 4.6, oak,
                bevel=0.9, uv="box")
        cx = (a + b) / 2.0
        kit.ball("PullBoss%d" % index, cx, front + 2.3, middle + 2.4, 1.3, brass, plan=0.5)
        kit.ring("Pull%d" % index, (cx, front + 2.6, middle - 0.4), (0.0, 1.0, 0.0), 2.6, 0.55, brass, segments=20,
                 sides=6)
        if index < count - 1:
            sx = b + stile / 2.0
            diamond = [(sx, middle + 4.2), (sx + 3.0, middle), (sx, middle - 4.2), (sx - 3.0, middle)]
            kit.slab("Lozenge%d" % index, diamond, front + 0.2, front + 1.2, enamel)
            rim = [(sx, middle + 5.0), (sx + 3.7, middle), (sx, middle - 5.0), (sx - 3.7, middle)]
            kit.slab("LozengeRim%d" % index, rim, front + 0.4, front + 0.9, brass)
    # The top: boards between breadboard ends, a raised rim along its sides,
    # brass caps on its corners.
    boards = []
    for side, (a, b) in (("W", (x0, x0 + 12.0)), ("E", (x1 - 12.0, x1))):
        boards.append(kit.box("TopEnd" + side, a, b, y0, y1, top - 5.0, top, oak, bevel=1.2, uv="box_up"))
    rows = 5
    depth = (y1 - y0) / rows
    for index in range(rows):
        boards.append(kit.box("TopBoard%d" % index, x0 + 12.3, x1 - 12.3, y0 + depth * index + 0.35,
                              y0 + depth * (index + 1) - 0.35, top - 5.0 - 0.15 * (index % 2), top - 0.15 * (index % 2),
                              oak, bevel=1.0, uv="box"))
    for side, (a, b) in (("North", (y0, y0 + 4.5)), ("South", (y1 - 4.5, y1))):
        kit.box("Rim" + side, x0 + 12.0, x1 - 12.0, a, b, top, top + 1.6, oak, bevel=0.6, uv="box")
    for cx in (x0 + 6.0, x1 - 6.0):
        for cy in (y0 + 5.0, y1 - 5.0):
            kit.box("CornerCap", cx - 6.4, cx + 6.4, cy - 5.4, cy + 5.4, top, top + 1.0, brass, bevel=0.4)
    # Marks on the oak: rings where wet glass stood, burns by the burners.
    marks = RP.Kit("AlchemyTableMarks", prop="ChemistryLabTable")
    for index in range(10):
        decal(marks, "Ring%d" % index, rng.uniform(x0 + 20.0, x1 - 20.0), rng.uniform(y0 + 12.0, y1 - 12.0),
              top + 0.04 + index * 0.002, rng.uniform(4.0, 7.0), ring_stain(), turn=rng.uniform(0.0, 6.28))
    for index, (cx, cy, radius) in enumerate(((616.0, 528.0, 20.0), (468.0, 520.0, 9.0))):
        decal(marks, "Scorch%d" % index, cx, cy, top + 0.03, radius, scorch(), turn=index * 1.7)
    for obj in marks.made:
        kit.keep(obj)
    # Along the back, west to east: a tall flask, the oil press, a dark
    # flask on its stand, the candelabra and the spired globe.
    flask(kit, "TallFlask", 450.0, 466.0, top, "round", (0.6, 0.34, 0.08), size=1.5)
    kit.rod("StirRod", (448.0, 466.0, top + 6.0), (457.0, 460.0, top + 44.0), 0.6, wake.jar_glass())
    screw_press(kit, "Press", 512.0, 466.0, top)
    kit.lathe("DarkStand", 672.0, 464.0, [(0.0, top), (7.0, top), (7.0, top + 1.4), (2.2, top + 3.0), (2.2, top + 8.0),
                                          (5.6, top + 9.0), (0.0, top + 9.0)], brass, plan=ROUND)
    flask(kit, "DarkFlask", 672.0, 464.0, top + 9.0, "round", (0.12, 0.08, 0.16), size=1.35, glow=0.05)
    holder(kit, "Candelabra", "brass_candleholder_02", 730.0, 462.0, top, scale=1.0, tall=11.0, radius=1.5,
           power=7.0)
    globe_spire(kit, "Spire", 786.0, 468.0, top, (0.85, 0.55, 0.2))
    # The still in the middle, on a slate slab.
    kit.box("HeatSlab", 586.0, 646.0, 506.0, 552.0, top, top + 1.4, slate(), bevel=0.5, uv="box")
    spider_still(kit, "Still", 616.0, 528.0, top + 1.4)
    # West: a round flask on a cork ring, the yellow-green bottles, tongs.
    kit.lathe("CorkRing", 462.0, 524.0, [(5.0, top), (8.0, top), (8.4, top + 1.6), (4.6, top + 1.6)], cork(),
              plan=ROUND, close=False)
    flask(kit, "RoundFlask", 462.0, 524.0, top + 0.6, "round", (0.12, 0.22, 0.62), size=1.45, glow=0.1)
    for index, (dx, dy, size) in enumerate(((0.0, 0.0, 1.0), (9.0, 4.0, 0.85), (-8.0, 6.0, 0.9), (4.0, 10.0, 0.75))):
        flask(kit, "Yellow%d" % index, 500.0 + dx, 560.0 + dy, top, "bottle", (0.72, 0.82, 0.16), size=size, glow=0.18)
    flask(kit, "YellowCone", 524.0, 572.0, top, "cone", (0.72, 0.82, 0.16), size=0.8, glow=0.18)
    tongs(kit, "Tongs", 452.0, 594.0, top, 200.0)
    # The front: violet vials in a rack, papers; beads strewn round the still.
    tube_rack(kit, "VioletVials", 572.0, 590.0, top, (VIOLET, VIOLET, None, VIOLET, VIOLET))
    note = wake.writing("ChemTableNotes", lines=8.0)
    for index, (cx, cy, angle) in enumerate(((548.0, 520.0, 0.3), (690.0, 560.0, -0.3), (770.0, 520.0, 0.15))):
        wake.paper(kit, "Note%d" % index, cx, cy, top + 0.2 + index * 0.05, 24.0, 17.0, angle, note)
    beads(kit, "Bead", rng, 560.0, 700.0, 500.0, 596.0, top, 14)
    flask(kit, "Decanter", 720.0, 540.0, top, "bottle", (0.55, 0.12, 0.6), size=1.05)
    wake.closed_book(kit, "TableBook", 770.0, 800.0, 500.0, 524.0, top, 5.0, wake.BOOK_COLOURS[3])
    # The red spill at the south-east corner, over the edge and down.
    spill = splatter("TableRed", (0.22, 0.015, 0.02), 22.0, spikes=11, seed=0.3, droplets=0.8, throw=330.0, carry=0.5)
    reach = 46.0
    kit.quad("RedSpill", [(774.0 - reach, 590.0 + reach * ROUND, top + 0.12), (774.0 + reach, 590.0 + reach * ROUND,
                                                                               top + 0.12),
                          (774.0 + reach, 590.0 - reach * ROUND, top + 0.12),
                          (774.0 - reach, 590.0 - reach * ROUND, top + 0.12)], spill,
             uvs=((-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)))
    red = potion((0.3, 0.02, 0.03), 0.0)
    for index, (dx, length) in enumerate(((-12.0, 26.0), (-4.0, 44.0), (3.0, 18.0), (9.0, 34.0))):
        x = 788.0 + dx
        kit.rod("RedDrip%d" % index, (x, y1 + 0.4, top + 0.6), (x + 0.4, front + 2.8, top - length * 0.55), 0.9, red,
                segments=8)
        kit.ball("RedBead%d" % index, x + 0.4, front + 2.8, top - length * 0.55, 1.4, red, plan=ROUND)
    lying_bottle(kit, "SpiltRed", 760.0, 578.0, 18.0, 4.2, 330.0, (1.0, 0.16, 0.22), h=top)
    shards(kit, "TableShard", 772.0, 590.0, top, 20.0, 9, random.Random(12))
    # The blue coat over the front edge, dropped with the cloth solver, a
    # leather strap across it.
    wool = RP.textured("ChemCoatWool", "cotton_jersey", 0.3, 0.75, (0.2, 0.28, 0.55), saturation=0.0, ao=0.35)
    strap = wake.book_leather((0.2, 0.11, 0.05))
    # Crumpled where it lies, waved across where it hangs, so the solver
    # drops it into folds rather than a flat sheet.

    def rumple(x, y):
        lying = top + 3.6 + 1.6 * (1.0 + math.sin(0.31 * x + 0.9 * math.sin(0.06 * y)))
        return lying + (2.6 * math.sin(0.42 * x) if y > y1 - 4.0 else 0.0)

    coat = kit.sheet("Coat", 664.0, 734.0, y1 - 74.0, y1 + 40.0, rumple, [wool, strap], columns=56, rows=80,
                     material_of=lambda x, y: 1 if 703.0 < x < 709.0 else 0)
    centre = RP.world(699.0, y1 - 10.0, 0.0)
    coat.data.transform(Matrix.Translation(centre) @ Matrix.Rotation(math.radians(-14.0), 4, "Z")
                        @ Matrix.Translation(-centre))
    collider = kit.box("SimTop", x0, x1, y0, y1, top - 5.0, top + 1.6, oak, bevel=0.0)
    RP.simulate_cloth(coat, [collider, bpy.data.objects["RoomFloor"]], frames=110, quality=8, mass=0.3, bending=0.5,
                      shear=3.0, friction=60.0)
    kit.made.remove(collider)
    bpy.data.objects.remove(collider)
    wake.fold(coat, wake.creases(random.Random(41), 650.0, 748.0, y1 - 80.0, y1, 7, 2.4, 2.6, (-50.0, 50.0)))
    wake.thicken(coat, 1.2).modifiers["Solidify"].use_even_offset = False
    # The buckle where the strap hangs over the edge.
    mesh = coat.data
    best = min(mesh.vertices, key=lambda vertex: (RP.game(coat.matrix_world @ vertex.co) - Vector(
        (708.0, y1 + 6.0, top - 14.0))).length)
    point = RP.game(coat.matrix_world @ best.co)
    kit.box("Buckle", point.x - 3.0, point.x + 3.0, point.y + 1.0, point.y + 1.8, point.z - 2.5, point.z + 2.5, brass,
            bevel=0.3)
    kit.box("BuckleBar", point.x - 0.5, point.x + 0.5, point.y + 1.6, point.y + 2.2, point.z - 2.0, point.z + 2.0,
            brass, bevel=0.2)
    return kit


# ---------------------------------------------------------------- the floor


# The painting's flagstones: rows about 38 px deep, stones of mixed length.
FLAG_ROW = (35.0, 41.0)
FLAG_LENGTH = (30.0, 50.0)
FLAG_JOINT = 1.6
# How far the room's floor lies under the stones' tops: the joints' depth.
JOINT_DEPTH = 1.5


def flagstones(shell):
    """The floor as the painting lays it: square-cut flagstones in east-west
    rows, their lengths mixed so the joints stagger, each a slab whose
    chamfered rim catches the light and is worn paler, a few of them
    cracked. Their tops are the floor (h 0); the room's dark floor, lowered
    under them, shows in the joints."""
    kit = RP.Kit("Flagstones", depth=False)
    rng = random.Random(1609)
    shape = bmesh.new()
    cracks = []
    laid_count = 0
    y = DOOR_BACK - 6.0
    while y < SOUTH_Y + 10.0:
        y1 = y + rng.uniform(*FLAG_ROW)
        x = shell.side_x("left", min(y1, 1150.0)) - 24.0 - rng.uniform(0.0, 30.0)
        while x < RIGHT_X + 8.0:
            length = rng.uniform(*FLAG_LENGTH)
            x1 = x + length
            top = rng.uniform(-0.25, 0.15)
            _flagstone(shape, x + FLAG_JOINT / 2.0, x1 - FLAG_JOINT / 2.0, y + FLAG_JOINT / 2.0, y1 - FLAG_JOINT / 2.0,
                       top, rng)
            laid_count += 1
            if rng.random() < 0.06:
                cracks.append(((x + x1) / 2.0, (y + y1) / 2.0, length - 8.0, y1 - y - 8.0, top))
            x = x1
        y = y1
    stones = kit.shape("Stones", shape, flagstone(), uv="floor")
    stones.visible_shadow = True
    crack = hall.material_floor_crack(False)
    for index, (cx, cy, across, along, top) in enumerate(cracks):
        wake.paper(kit, "Crack%d" % index, cx, cy, top + 0.05, across, along, rng.uniform(-0.4, 0.4), crack)
    floor = bpy.data.objects["RoomFloor"]
    floor.location.z -= JOINT_DEPTH / RP.SIN * RP.PX
    print("FLAGSTONES %d stones, %d cracked" % (laid_count, len(cracks)))
    return kit


def _flagstone(shape, x0, x1, y0, y1, top, rng):
    """One flagstone into `shape`: its corners cut, a two-step chamfer round
    its top, turned and tipped a little at random so no two catch the light
    alike (the Greenhouse's paver, squared)."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    turn = math.radians(rng.uniform(-0.8, 0.8))
    slope_x, slope_y = rng.uniform(-0.01, 0.01), rng.uniform(-0.008, 0.008)
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
    bottom = [shape.verts.new((vert.co.x, vert.co.y, -JOINT_DEPTH - 1.0)) for vert in outer]
    shape.faces.new(inner)
    shape.faces.new(list(reversed(bottom)))
    for upper, lower in ((inner, middle), (middle, outer), (outer, bottom)):
        for index in range(8):
            following = (index + 1) % 8
            shape.faces.new((lower[index], lower[following], upper[following], upper[index]))


def tipped_flask(kit, part, x, y, kind, color, size, turn):
    """An empty flask lying on its side, mouth toward `turn` degrees (0 east,
    90 south): its potion is the puddle round it, a film of it still colours
    the glass."""
    wake.flask(kit, part, 0.0, 0.0, 0.0, kind, color, size=size)
    glass, liquid = kit.made[-1], kit.made[-2]
    glass.data.materials[0] = tinted_glass("Film%d%d%d" % tuple(int(c * 9) for c in color), color)
    kit.made.remove(liquid)
    bpy.data.objects.remove(liquid)
    belly = {"round": 7.0, "cone": 7.4, "bottle": 3.8}[kind] * size
    lie = (Matrix.Translation(RP.world(x, y, belly * RP.SIN)) @ Matrix.Rotation(math.radians(-turn), 4, "Z")
           @ Matrix.Rotation(math.radians(90.0), 4, "Y"))
    glass.data.transform(lie)
    glass.data.update()
    return glass


def red_crystal():
    return hall._glow_material("ChemRedCrystal", (0.75, 0.05, 0.08), 0.35, (0.28, 0.02, 0.03))


def floor_dressing():
    """Decals on the flagstones (out of the depth map): the red stain the
    player examines, thrown south-west from where the flask burst, broken red
    crystal south of it, and the trail of what fell from the table: green
    bottles, a purple flask on its side, glass and scattered notes."""
    kit = RP.Kit("ChemFloor", depth=False)
    for name, (cx, cy), colour, radius, spikes, seed, drops, throw, carry in (
            ("RedStain", (992.0, 624.0), (0.3, 0.018, 0.024), 96.0, 21, 0.0, 1.4, 225.0, 1.3),
            ("GreenSpill", (700.0, 796.0), (0.05, 0.26, 0.08), 22.0, 9, 0.35, 0.6, 200.0, 0.6),
            ("PurpleSpill", (590.0, 868.0), (0.18, 0.05, 0.3), 26.0, 9, 0.7, 0.7, 250.0, 0.8),
            ("PurpleDrip", (652.0, 732.0), (0.2, 0.05, 0.32), 16.0, 7, 0.2, 0.5, None, 0.0)):
        reach = radius * (1.55 + carry)
        lift = RUG_H + 0.4
        kit.quad(name, [(cx - reach, cy + reach * ROUND, lift), (cx + reach, cy + reach * ROUND, lift),
                        (cx + reach, cy - reach * ROUND, lift), (cx - reach, cy - reach * ROUND, lift)],
                 splatter(name, colour, radius, spikes=spikes, seed=seed, droplets=drops, throw=throw, carry=carry),
                 uvs=((-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)))
    green = (0.3, 1.0, 0.45)
    for index, (x, y, turn) in enumerate(((640.0, 772.0, 160.0), (712.0, 790.0, 20.0), (688.0, 852.0, 300.0),
                                          (764.0, 808.0, 210.0), (410.0, 818.0, 250.0))):
        lying_bottle(kit, "GreenBottle%d" % index, x, y, 20.0 + index % 2 * 4.0, 4.4, turn, green)
    lying_bottle(kit, "RedBottle", 1048.0, 704.0, 24.0, 5.0, 35.0, (1.0, 0.16, 0.22))
    tipped_flask(kit, "PurpleFlask", 578.0, 860.0, "round", VIOLET, 1.25, 205.0)
    crystal_material = red_crystal()
    rng = random.Random(1906)
    for index, (x, y) in enumerate(((870.0, 905.0), (935.0, 955.0), (1030.0, 882.0), (1086.0, 832.0),
                                    (1124.0, 838.0), (902.0, 862.0))):
        wake.crystal(kit, "RedCrystal%d" % index, x, y, 2.4, rng.uniform(3.6, 5.2), rng.uniform(7.0, 10.0),
                     crystal_material, tilt=rng.uniform(1.0, 1.4), turn=rng.uniform(0.0, 6.28))
    shards(kit, "StainShard", 992.0, 624.0, 0.0, 130.0, 22, rng)
    for index, (x, y, reach) in enumerate(((700.0, 800.0, 40.0), (590.0, 864.0, 26.0), (420.0, 820.0, 18.0))):
        shards(kit, "TrailShard%d" % index, x, y, 0.0, reach, 8, rng)
    note = wake.writing("ChemFloorNotes", lines=7.0)
    for index, (cx, cy, angle) in enumerate(((930.0, 520.0, 0.5), (1062.0, 566.0, -0.3), (506.0, 798.0, 0.2),
                                             (530.0, 818.0, -0.5), (366.0, 884.0, 0.35), (350.0, 866.0, -0.2))):
        wake.paper(kit, "FloorNote%d" % index, cx, cy, 0.3 + index * 0.05, 24.0, 17.0, angle, note)
    return kit


# ---------------------------------------------------------------- the room


GRADES = (
    ("wooden_crate_01", 0.7, 0.8), ("wooden_crate_02", 0.7, 0.8), ("wine_barrel_01", 0.72, 0.85),
    ("treasure_chest", 0.75, 0.85), ("wooden_bucket_01", 0.72, 0.85), ("wooden_lantern_01", 0.75, 0.85),
    ("wooden_bowl_01", 0.75, 0.85), ("wicker_basket_01", 0.75, 0.85), ("brass_candleholders", 0.85, 0.9),
    ("brass_goblets", 0.85, 0.9), ("brass_vase_03", 0.85, 0.9), ("Lantern_01", 0.85, 0.9),
    ("mantel_clock_01", 0.8, 0.85), ("antique_ceramic_vase_01", 0.78, 0.85), ("ceramic_vase_04", 0.78, 0.85),
    ("periwinkle_plant", 0.8, 0.9), ("nettle_plant", 0.8, 0.9), ("flower_heliophila", 0.8, 0.9),
    ("flower_ursinia", 0.8, 0.9), ("weed_plant_02", 0.8, 0.9), ("trowel_01", 0.8, 0.85),
)


def grade(scene):
    """The room's exposure and white balance, set after the shared Cycles
    setup: as bright and as warm as the painted laboratory (mean luminance
    44, red over blue +7), which its fire and candles light."""
    scene.view_settings.exposure = 0.9
    scene.view_settings.use_white_balance = True
    scene.view_settings.white_balance_temperature = 7100.0


def build(rp, layout):
    global RP, MODELS
    RP = rp
    wake.RP = rp
    MODELS = rp.ModelSet()
    for asset, value, saturation in GRADES:
        MODELS.grade(asset, value, saturation)
    shell_materials = {
        "floor": grout(),
        "wall": rp.textured("ChemWall", "castle_wall_slates", 1.5, 0.56, (0.72, 0.66, 0.78), ao=0.3),
        "cap": (hall.material_cap_textured(rp.TEXTURES, lit=False) if rp.TEXTURES.available()
                else rp.textured("ChemCap", "large_grey_tiles", 1.2, 0.44, (0.64, 0.6, 0.72), saturation=0.6)),
        "lip": (hall.material_cap_textured(rp.TEXTURES, lit=True) if rp.TEXTURES.available()
                else rp.textured("ChemLip", "large_grey_tiles", 1.2, 0.9, (0.86, 0.83, 0.9), ao=0.1)),
        "reveal": rp.textured("ChemReveal", "castle_wall_slates", 1.5, 0.62, (0.74, 0.68, 0.8), ao=0.2),
    }
    shell = rp.Shell(SPEC, shell_materials)
    shell.build()
    open_sill()
    flagstones(shell)
    doorway()
    door_sconces()
    north_east_rack()
    west_counter(shell)
    pedestal()
    wall_sconces(shell)
    candle_table()
    west_storage()
    herb_bed(shell)
    runner()
    table_rug()
    south_west_crates()
    hearth()
    south_east_storage()
    east_bench(shell)
    floor_dressing()
    wake.moon_sky()
    # No window lets the moon in here: it only fills what the fire and the
    # candles leave dark.
    bpy.data.objects["WakeMoonSky"].data.energy = 0.7
    props = {"ChemistryLabTable": alchemy_table(), "ChemistryPotionCabinet": potion_cabinet()}
    roots = {"ChemistryLabTable": "Worldsort/ChemistryLabTable",
             "ChemistryPotionCabinet": "Worldsort/ChemistryPotionCabinet"}
    # The table is a real table's size now, smaller than the painted one:
    # the preview swaps its footprint into the room's collision.
    x0, x1, y0, y1 = TABLE
    collision = {"RoomCollisions/AlchemyTableCollision": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}
    print("CHEMISTRY ROOM built: %d objects, %d glows" % (len(bpy.data.objects), len(rp.GLOWS)))
    return {"props": props, "roots": roots, "collision": collision}
