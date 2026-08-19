#!/usr/bin/env python3
"""Catch the errors that gdparse does not.

gdparse only checks that a file is syntactically well-formed. Godot rejects
more than that, and some things it accepts still misbehave at runtime. Those
only surface when you press Play -- a slow and unpleasant way to find them,
especially after a merge. Every class below has actually broken this project:

1. Duplicate dictionary keys. A merge that brings the same block of entries in
   twice parses fine but makes Godot refuse to load the script. The whole game
   dies here because the offending file is usually an autoload.
2. Duplicate top-level definitions. Same story: valid syntax, redefinition
   error at load.
3. res:// paths pointing at files that no longer exist. Deleting a script
   during a merge without updating the scenes that reference it leaves scenes
   that cannot be instantiated.
4. `"a %s" + "b" % args`. `%` binds tighter than `+`, so the format is applied
   to the last literal only. When the placeholders live in an earlier segment
   the call fails at runtime and Godot returns the string unformatted, so the
   player reads a literal "%s". Long prose in this project is nearly always a
   concatenation chain, which makes this easy to write and easy to miss.
5. `**bold**` in a string. Every label here is a plain Label, so the asterisks
   reach the player as asterisks. Rich text uses BBCode.
6. A minigame completion handler that underscores both of its parameters. It is
   saying it does not care whether the player played, so opening the panel and
   closing it immediately collects the reward.
7. A hall door whose interaction rect sits so far inside the wall art that no
   walkable tile comes within the interaction margin. The same rect positions
   the focus bracket and gates the prompt, so tidying the bracket can silently
   make a room unenterable.
8. A hall knowledge exhibit placed where no walkable tile comes within the
   interaction margin. The sprite draws over the masonry perfectly happily, so
   nothing looks wrong, but the knowledge behind it can never be collected and
   the door it teaches stays locked.
9. The same failure for the hall props, which is worse: three of them hold a
   third of the Final Room Key each, so one sealed into the wall ends the run
   rather than costing a collectable.

Exits non-zero when anything is found, so it can gate CI.
"""

from __future__ import annotations

import math
import os
import re
import sys
import zlib
from collections.abc import Callable

SKIP_DIRS = {".git", ".godot", "__pycache__", ".import"}

# A res:// path may point at any of these; anything else (a folder, a
# sub-resource id) is not something we can check on disk.
RESOURCE_HOSTS = (".tscn", ".tres", ".godot", ".cfg")


def iter_files(root: str, suffixes: tuple[str, ...]) -> list[str]:
    found: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in sorted(filenames):
            if name.endswith(suffixes):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


def strip_comment(line: str) -> str:
    """Remove a trailing comment, ignoring '#' that sits inside a string.

    Colour literals ("#7a2e2e") are common in this project's text, so a naive
    split on '#' would truncate real code.
    """
    out: list[str] = []
    quote: str | None = None
    index = 0
    while index < len(line):
        char = line[index]
        if quote is not None:
            out.append(char)
            if char == "\\":
                if index + 1 < len(line):
                    out.append(line[index + 1])
                    index += 1
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
            out.append(char)
        elif char == "#":
            break
        else:
            out.append(char)
        index += 1
    return "".join(out)


def check_duplicate_keys(path: str) -> list[str]:
    """Report string keys used twice inside the same dictionary literal.

    Braces are tracked to a depth stack so that nested dictionaries -- which
    this project uses heavily for {"en": ..., "zh": ...} entries -- each get
    their own namespace.
    """
    problems: list[str] = []
    stack: list[dict[str, int]] = []
    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, start=1):
            code = strip_comment(raw)
            entry = re.match(r'\s*"([^"]*)"\s*:', code)
            if entry is not None and stack:
                key = entry.group(1)
                first = stack[-1].get(key)
                if first is not None:
                    problems.append(
                        f"{path}:{number}: duplicate dictionary key "
                        f'"{key}" (first used on line {first})'
                    )
                else:
                    stack[-1][key] = number
            for char in code:
                if char == "{":
                    stack.append({})
                elif char == "}" and stack:
                    stack.pop()
    return problems


def check_duplicate_definitions(path: str) -> list[str]:
    """Report top-level func/const/signal/enum names declared twice."""
    patterns = {
        "func": re.compile(r"^func\s+(\w+)\s*\("),
        "const": re.compile(r"^const\s+(\w+)"),
        "signal": re.compile(r"^signal\s+(\w+)"),
        "enum": re.compile(r"^enum\s+(\w+)"),
    }
    seen: dict[tuple[str, str], int] = {}
    problems: list[str] = []
    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, start=1):
            for kind, pattern in patterns.items():
                match = pattern.match(raw)
                if match is None:
                    continue
                key = (kind, match.group(1))
                first = seen.get(key)
                if first is not None:
                    problems.append(
                        f"{path}:{number}: duplicate {kind} "
                        f"{match.group(1)} (first declared on line {first})"
                    )
                else:
                    seen[key] = number
    return problems


def check_format_precedence(path: str) -> list[str]:
    """Report `"a %s" + "b" % args`, where only the last literal is formatted.

    A chain is recognised by a line that starts with `%` (the formatting is
    written under the concatenation it was meant to apply to). If any earlier
    line in that chain carries a placeholder and the last one does not, the
    format call has no placeholder to fill and Godot leaves the string raw.
    """
    problems: list[str] = []
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    placeholder = re.compile(r"%[sdfxXov]")
    for number, line in enumerate(lines, start=1):
        # The argument may be an array literal, a parenthesised expression or
        # a plain identifier -- all three appear in this repository.
        if re.match(r"^\s*%\s*[\[(\w\"]", line) is None:
            continue
        chain: list[str] = []
        index = number - 2
        while index >= 0 and len(chain) < 16:
            above = lines[index]
            if not (above.rstrip().endswith('"') or above.lstrip().startswith("+")):
                break
            chain.insert(0, above)
            index -= 1
        if not chain:
            continue
        earlier = "\n".join(chain[:-1])
        if placeholder.search(earlier) and not placeholder.search(chain[-1]):
            problems.append(
                f"{path}:{number}: '%' applies only to the last literal of "
                "this concatenation, but the placeholders are in an earlier "
                "one -- wrap the chain in parentheses"
            )
    return problems


def check_markdown_emphasis(path: str) -> list[str]:
    """Report `**bold**` inside a string literal.

    Labels here are plain Label nodes, so markdown is not interpreted and the
    asterisks reach the player verbatim. Rich text in this project uses BBCode
    (`[b]`), so `**` in a string is always a mistake.
    """
    problems: list[str] = []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            code = strip_comment(line)
            if '"' in code and "**" in code:
                problems.append(
                    f"{path}:{number}: '**' in a string literal -- Label does "
                    "not render markdown, use BBCode or quotation marks"
                )
    return problems


def check_minigame_rewards(path: str) -> list[str]:
    """Report a minigame completion handler that ignores both its arguments.

    `MinigameLauncher` hands the room `cleared_all` and the number of stages
    actually beaten. A handler that underscores both is saying it does not care
    whether the player played, so opening the panel and closing it immediately
    collects the reward — and if the handler also sets a flag the room reads to
    decide whether to offer the minigame, the minigame disappears for good.
    That shipped in the wake room and is invisible from the code: the handler
    looks complete, because underscoring a parameter is how you say you meant
    to ignore it.
    """
    problems: list[str] = []
    handler = re.compile(
        r"^func\s+(_on_\w*(?:finished|completed))\s*\(([^)]*)\)"
    )
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            match = handler.match(line)
            if match is None:
                continue
            params = [p.strip() for p in match.group(2).split(",") if p.strip()]
            if len(params) < 2:
                continue
            if all(p.startswith("_") for p in params):
                problems.append(
                    f"{path}:{number}: {match.group(1)} ignores both "
                    "cleared_all and the stage count, so closing the panel "
                    "immediately collects the reward"
                )
    return problems


def check_resource_paths(root: str) -> list[str]:
    """Report res:// references whose target file is absent."""
    problems: list[str] = []
    for path in iter_files(root, RESOURCE_HOSTS):
        try:
            text = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            for match in re.finditer(r'"(res://[^"]*)"', line):
                target = match.group(1)
                # "res://foo.tscn::Sub" addresses a sub-resource, and a bare
                # directory reference has no file to stat.
                if "::" in target or target.endswith("/"):
                    continue
                on_disk = os.path.join(root, target[len("res://"):])
                if not os.path.exists(on_disk):
                    problems.append(
                        f"{path}:{number}: missing resource {target}"
                    )
    return problems


# The hall's player body: a 14x8 box whose centre sits 4px above the node
# position, so its top-left corner is (x - 7, y - 8).
PLAYER_HALF_WIDTH = 7
PLAYER_HEIGHT = 8
# RoomSpatialRuntime.is_actor_near_rect's default margin for hall interactions.
INTERACTION_MARGIN = 14.0
HALL_SIZE = (1920.0, 1280.0)
# RoomSpatialRuntime.VISIBLE_ALPHA_THRESHOLD, as a byte.
OPAQUE_ALPHA_THRESHOLD = 12


def _scene_nodes(scene: str) -> dict[str, dict]:
    """Parse a .tscn into a node table keyed by scene path."""
    text = open(scene, encoding="utf-8").read()
    shapes: dict[str, dict] = {}
    for block in re.finditer(
        r'\[sub_resource type="(\w+)" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)',
        text,
        re.DOTALL,
    ):
        entry: dict = {"type": block.group(1)}
        size = re.search(r"^size = Vector2\(([^)]*)\)", block.group(3), re.M)
        if size:
            entry["size"] = _pair(size.group(1))
        radius = re.search(r"^radius = ([\d.e+-]+)", block.group(3), re.M)
        if radius:
            entry["radius"] = float(radius.group(1))
        shapes[block.group(2)] = entry

    nodes: dict[str, dict] = {}
    for block in re.finditer(
        r"\[node ([^\]]*)\]\n(.*?)(?=\n\[node |\n\[connection|\Z)", text, re.DOTALL
    ):
        header, body = block.group(1), block.group(2)
        name = re.search(r'name="([^"]+)"', header)
        if name is None:
            continue
        node_type = re.search(r'type="([^"]+)"', header)
        parent = re.search(r'parent="([^"]+)"', header)
        parent_path = parent.group(1) if parent else None
        position = re.search(r"^position = Vector2\(([^)]*)\)", body, re.M)
        scale = re.search(r"^scale = Vector2\(([^)]*)\)", body, re.M)
        rotation = re.search(r"^rotation = ([\d.e+-]+)", body, re.M)
        polygon = re.search(r"^polygon = PackedVector2Array\(([^)]*)\)", body, re.M)
        shape_ref = re.search(r'^shape = SubResource\("([^"]+)"\)', body, re.M)
        texture = re.search(r'^texture = ExtResource\("([^"]+)"\)', body, re.M)
        points = None
        if polygon:
            numbers = [float(n) for n in polygon.group(1).split(",") if n.strip()]
            points = list(zip(numbers[0::2], numbers[1::2]))
        key = (
            "."
            if parent_path is None
            else (
                name.group(1)
                if parent_path == "."
                else parent_path + "/" + name.group(1)
            )
        )
        nodes[key] = {
            "name": name.group(1),
            "type": node_type.group(1) if node_type else "",
            "parent": parent_path,
            "position": _pair(position.group(1)) if position else (0.0, 0.0),
            "scale": _pair(scale.group(1)) if scale else (1.0, 1.0),
            "rotation": float(rotation.group(1)) if rotation else 0.0,
            "polygon": points,
            "shape": shapes.get(shape_ref.group(1)) if shape_ref else None,
            "texture": texture.group(1) if texture else None,
            "centered": "centered = false" not in body,
        }
    return nodes


def _global_transform(
    nodes: dict[str, dict], path: str
) -> tuple[tuple[float, float], tuple[float, float], float]:
    chain = []
    current = path
    while current and current != ".":
        chain.append(current)
        node = nodes.get(current)
        if node is None or node["parent"] in (None, "."):
            break
        current = node["parent"]
    chain.reverse()
    ox = oy = 0.0
    sx = sy = 1.0
    rot = 0.0
    for key in chain:
        node = nodes.get(key)
        if node is None:
            continue
        px, py = node["position"][0] * sx, node["position"][1] * sy
        cos_r, sin_r = math.cos(rot), math.sin(rot)
        ox += px * cos_r - py * sin_r
        oy += px * sin_r + py * cos_r
        sx *= node["scale"][0]
        sy *= node["scale"][1]
        rot += node["rotation"]
    return (ox, oy), (sx, sy), rot


def _on_wall_layer(nodes: dict[str, dict], path: str) -> bool:
    """True when the shape's nearest physics-body ancestor is a StaticBody2D.

    The knowledge exhibits each carry an InteractionArea: an Area2D on layer 2,
    disabled besides. game_world queries walls with collision_mask 1 and
    collide_with_areas off, so those shapes stop nothing. Counting them walls
    the exhibits in and hides the very floor the player interacts from.
    """
    current = nodes.get(path)
    while current is not None:
        parent_path = current["parent"]
        if parent_path in (None, "."):
            return False
        parent = nodes.get(parent_path)
        if parent is None:
            return False
        if parent["type"] == "StaticBody2D":
            return True
        if parent["type"] in ("Area2D", "CharacterBody2D", "RigidBody2D"):
            return False
        current = parent
    return False


def _hall_wall_polygons(root: str) -> list[tuple[tuple[float, ...], list]]:
    """Everything on the hall's wall layer, as world-space polygons."""
    scene = os.path.join(root, "scenes", "wall_collisions.tscn")
    if not os.path.exists(scene):
        return []
    nodes = _scene_nodes(scene)
    polygons = []
    for key, node in nodes.items():
        if not _on_wall_layer(nodes, key):
            continue
        offset, scale, rot = _global_transform(nodes, key)
        points = None
        if node["type"] == "CollisionPolygon2D" and node["polygon"]:
            points = node["polygon"]
        elif node["type"] == "CollisionShape2D" and node["shape"]:
            shape = node["shape"]
            if shape["type"] == "RectangleShape2D" and "size" in shape:
                hw, hh = shape["size"][0] / 2.0, shape["size"][1] / 2.0
                points = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
            elif shape["type"] == "CircleShape2D" and "radius" in shape:
                r = shape["radius"]
                points = [
                    (
                        r * math.cos(step * math.pi / 8),
                        r * math.sin(step * math.pi / 8),
                    )
                    for step in range(16)
                ]
        if not points or len(points) < 3:
            continue
        world = [_apply_transform(p, offset, scale, rot) for p in points]
        xs = [p[0] for p in world]
        ys = [p[1] for p in world]
        polygons.append(((min(xs), min(ys), max(xs), max(ys)), world))
    return polygons


def _apply_transform(
    point: tuple[float, float],
    offset: tuple[float, float],
    scale: tuple[float, float],
    rot: float,
) -> tuple[float, float]:
    x, y = point[0] * scale[0], point[1] * scale[1]
    cos_r, sin_r = math.cos(rot), math.sin(rot)
    return (offset[0] + x * cos_r - y * sin_r, offset[1] + x * sin_r + y * cos_r)


def _point_in_polygon(x: float, y: float, points: list) -> bool:
    inside = False
    count = len(points)
    for index in range(count):
        x0, y0 = points[index]
        x1, y1 = points[(index + 1) % count]
        if (y0 > y) != (y1 > y):
            if x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
                inside = not inside
    return inside


def _segments_cross(
    ax: float,
    ay: float,
    bx: float,
    by: float,
    cx: float,
    cy: float,
    dx: float,
    dy: float,
) -> bool:
    """Do segments AB and CD intersect?"""

    def orientation(px, py, qx, qy, rx, ry):
        value = (qy - py) * (rx - qx) - (qx - px) * (ry - qy)
        if value > 1e-9:
            return 1
        if value < -1e-9:
            return -1
        return 0

    o1 = orientation(ax, ay, bx, by, cx, cy)
    o2 = orientation(ax, ay, bx, by, dx, dy)
    o3 = orientation(cx, cy, dx, dy, ax, ay)
    o4 = orientation(cx, cy, dx, dy, bx, by)
    if o1 != o2 and o3 != o4:
        return True
    # Collinear overlap counts as touching, which is what a wall does.
    if o1 == 0 and min(ax, bx) <= cx <= max(ax, bx) and min(ay, by) <= cy <= max(ay, by):
        return True
    if o2 == 0 and min(ax, bx) <= dx <= max(ax, bx) and min(ay, by) <= dy <= max(ay, by):
        return True
    if o3 == 0 and min(cx, dx) <= ax <= max(cx, dx) and min(cy, dy) <= ay <= max(cy, dy):
        return True
    if o4 == 0 and min(cx, dx) <= bx <= max(cx, dx) and min(cy, dy) <= by <= max(cy, dy):
        return True
    return False


def _player_fits(x: float, y: float, polygons: list) -> bool:
    """Is the player's body clear of every wall with its ground point at (x, y)?

    This is a real rectangle-polygon overlap test rather than a handful of
    sample points. Sampling was close enough while the walls were a few dozen
    hand-drawn slabs, but the hall now has 163 generated patches, some only a
    few pixels wide, and a 14x8 body straddles those with every sample landing
    on open floor. That reports walkable floor inside a wall, which is exactly
    the mistake these checks exist to catch.
    """
    left, right = x - PLAYER_HALF_WIDTH, x + PLAYER_HALF_WIDTH
    top, bottom = y - PLAYER_HEIGHT, y
    if left < 0.0 or top < 0.0 or right > HALL_SIZE[0] or bottom > HALL_SIZE[1]:
        return False
    corners = ((left, top), (right, top), (right, bottom), (left, bottom))
    for bounds, points in polygons:
        min_x, min_y, max_x, max_y = bounds
        if right < min_x or left > max_x or bottom < min_y or top > max_y:
            continue
        # A polygon vertex inside the body, or the body's corner inside the
        # polygon, or any pair of edges crossing: all three mean overlap.
        for px, py in points:
            if left <= px <= right and top <= py <= bottom:
                return False
        for cx, cy in corners:
            if _point_in_polygon(cx, cy, points):
                return False
        count = len(points)
        for index in range(count):
            x0, y0 = points[index]
            x1, y1 = points[(index + 1) % count]
            for corner_index in range(4):
                rx0, ry0 = corners[corner_index]
                rx1, ry1 = corners[(corner_index + 1) % 4]
                if _segments_cross(x0, y0, x1, y1, rx0, ry0, rx1, ry1):
                    return False
    return True


def _door_focus_rects(path: str) -> list[tuple[str, tuple[float, ...]]]:
    """The rect each hall door draws its focus bracket on, from the source."""
    text = open(path, encoding="utf-8").read()
    constants = {
        name: (float(x), float(y))
        for name, x, y in re.findall(
            r"^const\s+(\w+):\s*Vector2\s*=\s*Vector2\(\s*"
            r"(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)",
            text,
            re.MULTILINE,
        )
    }
    body = re.search(
        r"^func get_interaction_rect.*?(?=^func )", text, re.MULTILINE | re.DOTALL
    )
    if body is None:
        return []
    flat = re.sub(r"\s+", " ", body.group(0))
    rects = []
    pattern = (
        r"Rect2\(\s*(\w*DOOR\w*)\s*-\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)\s*,"
        r"\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)\s*\)"
    )
    for name, off_x, off_y, width, height in re.findall(pattern, flat):
        if name not in constants:
            continue
        centre = constants[name]
        rects.append(
            (
                name,
                (
                    centre[0] - float(off_x),
                    centre[1] - float(off_y),
                    float(width),
                    float(height),
                ),
            )
        )
    return rects


def check_door_focus_reachable(root: str) -> list[str]:
    """Report a hall door whose prompt no player can ever stand close enough to.

    `get_interaction_rect` does double duty: it positions the focus bracket and
    it decides whether the player is near enough to interact. Aligning a door's
    bracket with the art therefore also moves the zone that offers the prompt,
    and pushing it too far into the wall makes the room unreachable. Two merges
    have already reset these constants; the damage is invisible in a diff and
    only shows up as a door that stops responding.

    Standable floor beside the door is necessary but not sufficient: the hall is
    a maze, and an edit to the walls can fence that floor off into a pocket the
    player cannot walk into. So the second half of this check asks whether the
    pocket is on the same island as the arrival spawn.
    """
    source = os.path.join(root, "scripts", "game_world.gd")
    if not os.path.exists(source):
        return []
    polygons = _hall_wall_polygons(root)
    if not polygons:
        return []
    problems: list[str] = []
    rects = _door_focus_rects(source)
    stranded: list[tuple[str, tuple[float, ...]]] = []
    for name, rect in rects:
        if not _reachable(rect, polygons):
            problems.append(
                f"scripts/game_world.gd: {name} puts the focus rect where no "
                "walkable tile comes within the interaction margin, so the "
                "prompt can never appear"
            )
        else:
            stranded.append((name, rect))
    spawn = _hall_arrival_spawn(source)
    if spawn is None or not stranded:
        return problems
    reachable = _connected_spans(polygons, spawn)
    if not reachable:
        return problems
    for name, rect in stranded:
        if not _connected(rect, reachable):
            problems.append(
                f"scripts/game_world.gd: {name} has standable floor beside it, "
                "but none of it connects to the hall arrival spawn, so the "
                "player can never walk to the prompt"
            )
    return problems


def _rect_gap(
    x: float, y: float, rect_x: float, rect_y: float, width: float, height: float
) -> float:
    horizontal = max(
        rect_x - (x + PLAYER_HALF_WIDTH), (x - PLAYER_HALF_WIDTH) - (rect_x + width)
    )
    vertical = max(rect_y - y, (y - PLAYER_HEIGHT) - (rect_y + height))
    if horizontal <= 0.0 and vertical <= 0.0:
        return 0.0
    if horizontal <= 0.0:
        return vertical
    if vertical <= 0.0:
        return horizontal
    return (horizontal * horizontal + vertical * vertical) ** 0.5


def _reachable(rect: tuple[float, float, float, float], polygons: list) -> bool:
    """Can the player's body get within the interaction margin of this rect?"""
    rect_x, rect_y, width, height = rect
    margin = INTERACTION_MARGIN + PLAYER_HEIGHT + 1.0
    y = rect_y - margin
    while y <= rect_y + height + margin:
        x = rect_x - margin
        while x <= rect_x + width + margin:
            if _player_fits(x, y, polygons) and _rect_gap(
                x, y, rect_x, rect_y, width, height
            ) <= INTERACTION_MARGIN:
                return True
            x += 2.0
        y += 2.0
    return False


def _fill_rows(polygons: list) -> list[int]:
    """The hall's walls as one bitmask per scanline; bit x means pixel x is wall.

    Scan-converted rather than sampled, so a slab one pixel wide still lands in
    the mask. Coverage is decided at the pixel centre, which makes this very
    slightly more permissive than `_player_fits` -- it is used to decide whether
    a route exists, and erring towards "open" means this never invents a wall
    that would fail the build for a corridor that is really there.
    """
    width, height = int(HALL_SIZE[0]), int(HALL_SIZE[1])
    rows = [0] * height
    for _bounds, points in polygons:
        ys = [point[1] for point in points]
        first = max(0, int(math.floor(min(ys))))
        last = min(height - 1, int(math.ceil(max(ys))))
        count = len(points)
        for row in range(first, last + 1):
            sample = row + 0.5
            crossings = []
            for index in range(count):
                ax, ay = points[index]
                bx, by = points[(index + 1) % count]
                if (ay > sample) != (by > sample):
                    crossings.append(ax + (sample - ay) * (bx - ax) / (by - ay))
            crossings.sort()
            for pair in range(0, len(crossings) - 1, 2):
                low = max(0, int(math.floor(crossings[pair] - 0.5)) + 1)
                high = min(width - 1, int(math.ceil(crossings[pair + 1] - 0.5)) - 1)
                if high >= low:
                    rows[row] |= ((1 << (high - low + 1)) - 1) << low
    return rows


def _walkable_rows(polygons: list) -> list[int]:
    """One bitmask per scanline; bit x means the player's body fits at (x, y).

    The body is the 14x8 box `_player_fits` uses, so a standing position is
    clear only when all 14x8 pixels behind it are. Both sweeps are done with
    whole-row integer shifts instead of per-pixel tests, which is what keeps a
    1920x1280 dilation affordable in a check that runs on every push.
    """
    width, height = int(HALL_SIZE[0]), int(HALL_SIZE[1])
    solid = _fill_rows(polygons)
    full = (1 << width) - 1
    spread = [0] * height
    for row in range(height):
        mask = solid[row]
        if mask == 0:
            continue
        merged = 0
        for shift in range(-PLAYER_HALF_WIDTH, PLAYER_HALF_WIDTH):
            merged |= (mask >> shift) if shift >= 0 else (mask << -shift)
        spread[row] = merged & full
    # Bits 0..6 and the last 7 columns can never hold a body: the box would
    # leave the map, which `_player_fits` rejects on the same bounds.
    inside = ((1 << (width - 2 * PLAYER_HALF_WIDTH + 1)) - 1) << PLAYER_HALF_WIDTH
    walkable = [0] * height
    for row in range(PLAYER_HEIGHT, height):
        blocked = 0
        for above in range(row - PLAYER_HEIGHT, row):
            blocked |= spread[above]
        walkable[row] = ~blocked & inside
    return walkable


def _row_spans(mask: int) -> list[tuple[int, int]]:
    """A row bitmask as half-open runs of set bits."""
    spans: list[tuple[int, int]] = []
    offset = 0
    while mask:
        low = (mask & -mask).bit_length() - 1
        mask >>= low
        offset += low
        run = (mask ^ (mask + 1)).bit_length() - 1
        spans.append((offset, offset + run))
        mask >>= run
        offset += run
    return spans


def _connected_spans(polygons: list, seed: tuple[float, float]) -> dict[int, list]:
    """The runs of standable floor the player can reach on foot from `seed`.

    Connectivity is resolved between whole runs rather than pixels: a hall row
    is a handful of runs, so labelling them and unioning vertical overlaps costs
    thousands of operations where a pixel flood fill costs hundreds of
    thousands.
    """
    walkable = _walkable_rows(polygons)
    rows = {y: _row_spans(mask) for y, mask in enumerate(walkable) if mask}
    parent: list[int] = []

    def find(node: int) -> int:
        while parent[node] != node:
            parent[node] = parent[parent[node]]
            node = parent[node]
        return node

    def union(left: int, right: int) -> None:
        left, right = find(left), find(right)
        if left != right:
            parent[right] = left

    labels: dict[int, list[int]] = {}
    previous_y = None
    for y in sorted(rows):
        spans = rows[y]
        ids = []
        for _span in spans:
            ids.append(len(parent))
            parent.append(len(parent))
        labels[y] = ids
        if previous_y == y - 1:
            above = rows[previous_y]
            above_ids = labels[previous_y]
            i = j = 0
            while i < len(spans) and j < len(above):
                if spans[i][0] < above[j][1] and above[j][0] < spans[i][1]:
                    union(ids[i], above_ids[j])
                if spans[i][1] < above[j][1]:
                    i += 1
                else:
                    j += 1
        previous_y = y

    seed_label = None
    best = None
    for y in sorted(rows):
        for index, (start, end) in enumerate(rows[y]):
            column = min(max(int(seed[0]), start), end - 1)
            distance = (column - seed[0]) ** 2 + (y - seed[1]) ** 2
            if best is None or distance < best:
                best = distance
                seed_label = find(labels[y][index])
    if seed_label is None:
        return {}

    reachable: dict[int, list] = {}
    for y in sorted(rows):
        kept = [
            span
            for index, span in enumerate(rows[y])
            if find(labels[y][index]) == seed_label
        ]
        if kept:
            reachable[y] = kept
    return reachable


def _hall_arrival_spawn(source: str) -> tuple[float, float] | None:
    """Where the player's feet land the first time they walk into the hall."""
    text = open(source, encoding="utf-8").read()
    found = re.search(
        r"^const\s+HALL_FIRST_ARRIVAL_POSITION\s*:?[^=]*=\s*Vector2\(\s*"
        r"(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)",
        text,
        re.MULTILINE,
    )
    return (float(found.group(1)), float(found.group(2))) if found else None


def _connected(
    rect: tuple[float, float, float, float], reachable: dict[int, list]
) -> bool:
    """Is any position that offers this rect's prompt on the player's own island?"""
    rect_x, rect_y, width, height = rect
    reach = INTERACTION_MARGIN + PLAYER_HEIGHT + 1.0
    first = int(rect_y - reach)
    last = int(rect_y + height + reach) + 1
    for y in range(max(0, first), min(int(HALL_SIZE[1]), last)):
        for start, end in reachable.get(y, ()):
            low = max(start, int(rect_x - reach - PLAYER_HALF_WIDTH))
            high = min(end, int(rect_x + width + reach + PLAYER_HALF_WIDTH) + 1)
            for x in range(low, high):
                if _rect_gap(x, y, rect_x, rect_y, width, height) <= INTERACTION_MARGIN:
                    return True
    return False


def _png_opaque_box(path: str) -> tuple[int, int, int, int, int, int] | None:
    """(left, top, right, bottom, width, height) of a PNG's non-transparent pixels.

    RoomSpatialRuntime crops every sprite to this box before it builds an
    interaction rect, so a checker that skips it measures a box far larger than
    the one the game uses. Only 8-bit RGBA, non-interlaced files are handled;
    anything else returns None and the caller skips the check rather than
    guessing.
    """
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError:
        return None
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    width = height = 0
    idat = bytearray()
    offset = 8
    while offset + 8 <= len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        kind = data[offset + 4 : offset + 8]
        body = data[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width = int.from_bytes(body[0:4], "big")
            height = int.from_bytes(body[4:8], "big")
            if body[8] != 8 or body[9] != 6 or body[12] != 0:
                return None
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        offset += 12 + length
    if width == 0 or height == 0 or not idat:
        return None
    try:
        raw = zlib.decompress(bytes(idat))
    except zlib.error:
        return None

    stride = width * 4
    if len(raw) < height * (stride + 1):
        return None
    # Undo the per-scanline filters, but only on the alpha channel. Every PNG
    # filter references the byte one pixel to the left, which at 4 bytes per
    # pixel is the previous alpha byte, so alpha reconstructs entirely from
    # itself and three quarters of the work can be skipped.
    previous = bytes(width)
    left = width
    top = height
    right = -1
    bottom = -1
    position = 0
    for row in range(height):
        filter_type = raw[position]
        line = bytearray(raw[position + 4 : position + 1 + stride : 4])
        position += 1 + stride
        if filter_type == 1:
            for i in range(1, width):
                line[i] = (line[i] + line[i - 1]) & 0xFF
        elif filter_type == 2:
            for i in range(width):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(width):
                a = line[i - 1] if i else 0
                line[i] = (line[i] + ((a + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(width):
                a = line[i - 1] if i else 0
                b = previous[i]
                c = previous[i - 1] if i else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                if pa <= pb and pa <= pc:
                    predictor = a
                elif pb <= pc:
                    predictor = b
                else:
                    predictor = c
                line[i] = (line[i] + predictor) & 0xFF
        elif filter_type != 0:
            return None
        row_left = -1
        row_right = -1
        for column, value in enumerate(line):
            if value > OPAQUE_ALPHA_THRESHOLD:
                if row_left < 0:
                    row_left = column
                row_right = column
        if row_left >= 0:
            left = min(left, row_left)
            right = max(right, row_right)
            top = min(top, row)
            bottom = max(bottom, row)
        previous = line
    if right < left or bottom < top:
        return (0, 0, width, height, width, height)
    return (left, top, right + 1, bottom + 1, width, height)


def _sprite_rects(
    root: str, wanted: Callable[[str], bool]
) -> list[tuple[str, tuple[float, float, float, float]]]:
    """Interaction rects for hall nodes, the way `get_visual_rect` computes them.

    `_sprite_visual_rect` measures the sprite's *opaque* box rather than its
    texture, so a prop padded with transparency has a much smaller prompt zone
    than its file size suggests. Reproducing that here is the whole point: a
    check against the padded rect would pass while the game refuses to offer
    the prompt.
    """
    scene = os.path.join(root, "scenes", "wall_collisions.tscn")
    if not os.path.exists(scene):
        return []
    text = open(scene, encoding="utf-8").read()
    textures = {
        match.group(2): match.group(1)
        for match in re.finditer(
            r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)"'
            r'\s+id="([^"]+)"\]',
            text,
        )
    }
    nodes = _scene_nodes(scene)

    rects = []
    for key, node in nodes.items():
        if node["texture"] is None or node["type"] != "Sprite2D":
            continue
        parent = node["parent"] or ""
        if not wanted(parent):
            continue
        relative = textures.get(node["texture"])
        if relative is None:
            continue
        box = _png_opaque_box(os.path.join(root, relative))
        if box is None:
            continue
        offset, scale, _rot = _global_transform(nodes, key)
        left, top, right, bottom, image_w, image_h = box
        origin_x = offset[0] - (image_w * scale[0] / 2.0 if node["centered"] else 0.0)
        origin_y = offset[1] - (image_h * scale[1] / 2.0 if node["centered"] else 0.0)
        rects.append(
            (
                parent.split("/")[-1],
                (
                    origin_x + left * scale[0],
                    origin_y + top * scale[1],
                    (right - left) * scale[0],
                    (bottom - top) * scale[1],
                ),
            )
        )
    return rects


def _exhibit_rects(root: str) -> list[tuple[str, tuple[float, float, float, float]]]:
    """The interaction rect of every hall exhibit, as the game computes it."""
    return _sprite_rects(root, lambda parent: parent.startswith("KnowledgeExhibits/"))


def _hall_prop_paths(source: str) -> list[str]:
    """Hall props whose interaction rect is read off a scene node, not a constant.

    Their `*_POSITION` constants are only the fallback for a missing node, so
    checking the constants proves nothing about the prompt the player is
    actually offered. The node names are taken from the source so that adding
    a prop puts it under this check without anyone remembering to.
    """
    if not os.path.exists(source):
        return []
    text = open(source, encoding="utf-8").read()
    names: list[str] = []
    # `Array[NodePath]` puts a bracket before the one that opens the literal,
    # so anchor on the assignment rather than on the first `[`.
    machines = re.search(
        r"^const FINAL_KEY_MACHINE_PATHS[^=\n]*=\s*\[(.*?)^\]",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if machines is not None:
        names += re.findall(r'NodePath\("WallCollisions/(\w+)"\)', machines.group(1))
    body = re.search(
        r"^func get_interaction_rect.*?(?=^func )", text, re.MULTILINE | re.DOTALL
    )
    if body is not None:
        names += re.findall(
            r'get_node_or_null\("WallCollisions/(\w+)"\)', body.group(0)
        )
    unique: list[str] = []
    for name in names:
        if name not in unique:
            unique.append(name)
    return unique


def _prop_rects(root: str) -> list[tuple[str, tuple[float, float, float, float]]]:
    """The interaction rect of every hall prop the player must walk up to."""
    names = set(_hall_prop_paths(os.path.join(root, "scripts", "game_world.gd")))
    if not names:
        return []
    return _sprite_rects(root, lambda parent: parent in names)


def _pair(text: str) -> tuple[float, float]:
    parts = [float(p) for p in text.split(",")]
    return (parts[0], parts[1])


def check_exhibit_reachable(root: str) -> list[str]:
    """Report a hall knowledge exhibit the player can never walk up to.

    Each exhibit teaches the answer to one door's knowledge lock, so an exhibit
    parked inside the masonry is not a cosmetic problem: the question it
    prepares becomes unanswerable and the run cannot continue. Two of the five
    shipped that way, and nothing about their placement looks wrong in the
    editor, because the sprite draws over the wall perfectly happily.
    """
    polygons = _hall_wall_polygons(root)
    if not polygons:
        return []
    source = os.path.join(root, "scripts", "game_world.gd")
    spawn = _hall_arrival_spawn(source) if os.path.exists(source) else None
    reachable = _connected_spans(polygons, spawn) if spawn else {}
    problems: list[str] = []
    for name, rect in _exhibit_rects(root):
        if not _reachable(rect, polygons):
            problems.append(
                f"scenes/wall_collisions.tscn: {name} sits where no walkable "
                "tile comes within the interaction margin, so its knowledge "
                "can never be collected and the door it teaches stays locked"
            )
        elif reachable and not _connected(rect, reachable):
            problems.append(
                f"scenes/wall_collisions.tscn: {name} has standable floor "
                "beside it, but none of it connects to the hall arrival spawn, "
                "so its knowledge can never be collected"
            )
    return problems


def check_prop_reachable(root: str) -> list[str]:
    """Report a hall prop the player can never walk up to.

    Three of these hide a third of the Final Room Key each, so a machine sealed
    behind the masonry does not cost the player a collectable — it ends the
    run, with no way to tell that anything is wrong. The storage rack is the
    optional Library key, which fails more quietly and is therefore easier to
    ship broken.

    These are checked separately from the exhibits because they are positioned
    differently: `get_interaction_rect` measures them off the scene node, so
    their `*_POSITION` constants can look perfectly sane while the node they
    fall back from sits in stone.
    """
    polygons = _hall_wall_polygons(root)
    if not polygons:
        return []
    source = os.path.join(root, "scripts", "game_world.gd")
    spawn = _hall_arrival_spawn(source) if os.path.exists(source) else None
    reachable = _connected_spans(polygons, spawn) if spawn else {}
    problems: list[str] = []
    for name, rect in _prop_rects(root):
        if not _reachable(rect, polygons):
            problems.append(
                f"scenes/wall_collisions.tscn: {name} sits where no walkable "
                "tile comes within the interaction margin, so what it holds "
                "can never be collected"
            )
        elif reachable and not _connected(rect, reachable):
            problems.append(
                f"scenes/wall_collisions.tscn: {name} has standable floor "
                "beside it, but none of it connects to the hall arrival spawn, "
                "so what it holds can never be collected"
            )
    return problems


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    problems: list[str] = []

    scripts = iter_files(root, (".gd",))
    for path in scripts:
        problems.extend(check_duplicate_keys(path))
        problems.extend(check_duplicate_definitions(path))
        problems.extend(check_format_precedence(path))
        problems.extend(check_markdown_emphasis(path))
        problems.extend(check_minigame_rewards(path))
    problems.extend(check_resource_paths(root))
    problems.extend(check_door_focus_reachable(root))
    problems.extend(check_exhibit_reachable(root))
    problems.extend(check_prop_reachable(root))

    for problem in problems:
        print(problem.replace(root + os.sep, ""))

    print()
    print(f"scripts scanned: {len(scripts)}")
    print(f"problems: {len(problems)}")
    if problems:
        print()
        print("gdparse accepts all of these. Godot does not, or the player")
        print("sees the damage at runtime.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
