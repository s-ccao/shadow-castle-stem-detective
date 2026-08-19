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

Exits non-zero when anything is found, so it can gate CI.
"""

from __future__ import annotations

import os
import re
import sys

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


def _hall_wall_polygons(root: str) -> list[tuple[tuple[float, ...], list]]:
    """Every authored wall polygon, paired with its bounding box."""
    scene = os.path.join(root, "scenes", "wall_collisions.tscn")
    if not os.path.exists(scene):
        return []
    polygons = []
    text = open(scene, encoding="utf-8").read()
    for match in re.finditer(r"polygon = PackedVector2Array\(([^)]*)\)", text):
        numbers = [float(n) for n in match.group(1).split(",") if n.strip()]
        points = list(zip(numbers[0::2], numbers[1::2]))
        if len(points) < 3:
            continue
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        polygons.append(((min(xs), min(ys), max(xs), max(ys)), points))
    return polygons


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


def _player_fits(x: float, y: float, polygons: list) -> bool:
    left, right = x - PLAYER_HALF_WIDTH, x + PLAYER_HALF_WIDTH
    top, bottom = y - PLAYER_HEIGHT, y
    if left < 0.0 or top < 0.0 or right > HALL_SIZE[0] or bottom > HALL_SIZE[1]:
        return False
    # Walls are never thinner than a tile, so sampling the body's corners,
    # edge midpoints and centre cannot step over one.
    samples = [
        (sx, sy)
        for sx in (left, x, right)
        for sy in (top, y - PLAYER_HEIGHT / 2.0, bottom)
    ]
    for bounds, points in polygons:
        min_x, min_y, max_x, max_y = bounds
        if right < min_x or left > max_x or bottom < min_y or top > max_y:
            continue
        for sx, sy in samples:
            if _point_in_polygon(sx, sy, points):
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
    """
    source = os.path.join(root, "scripts", "game_world.gd")
    if not os.path.exists(source):
        return []
    polygons = _hall_wall_polygons(root)
    if not polygons:
        return []
    problems: list[str] = []
    for name, (rect_x, rect_y, width, height) in _door_focus_rects(source):
        margin = INTERACTION_MARGIN + PLAYER_HEIGHT + 1.0
        found = False
        y = rect_y - margin
        while y <= rect_y + height + margin and not found:
            x = rect_x - margin
            while x <= rect_x + width + margin:
                if _player_fits(x, y, polygons) and _rect_gap(
                    x, y, rect_x, rect_y, width, height
                ) <= INTERACTION_MARGIN:
                    found = True
                    break
                x += 4.0
            y += 4.0
        if not found:
            problems.append(
                f"scripts/game_world.gd: {name} puts the focus rect where no "
                "walkable tile comes within the interaction margin, so the "
                "prompt can never appear"
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
