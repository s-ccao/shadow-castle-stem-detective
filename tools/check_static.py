#!/usr/bin/env python3
"""Catch the load-time errors that gdparse does not.

gdparse only checks that a file is syntactically well-formed. Godot itself
rejects several things gdparse accepts, and those only surface when you press
Play -- which is a slow and unpleasant way to find them, especially after a
merge. Three classes have actually broken this project:

1. Duplicate dictionary keys. A merge that brings the same block of entries in
   twice parses fine but makes Godot refuse to load the script. The whole game
   dies here because the offending file is usually an autoload.
2. Duplicate top-level definitions. Same story: valid syntax, redefinition
   error at load.
3. res:// paths pointing at files that no longer exist. Deleting a script
   during a merge without updating the scenes that reference it leaves scenes
   that cannot be instantiated.

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


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    problems: list[str] = []

    scripts = iter_files(root, (".gd",))
    for path in scripts:
        problems.extend(check_duplicate_keys(path))
        problems.extend(check_duplicate_definitions(path))
    problems.extend(check_resource_paths(root))

    for problem in problems:
        print(problem.replace(root + os.sep, ""))

    print()
    print(f"scripts scanned: {len(scripts)}")
    print(f"problems: {len(problems)}")
    if problems:
        print()
        print("These stop Godot from loading the file. gdparse cannot see them.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
