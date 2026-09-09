#!/usr/bin/env python3
"""Render the blind annotation worksheet for a held-out scenario set.

This script reads ONLY the scenario JSON and the static hint catalogue. It
imports no selector, calls no scoring function, and writes no `valid_hints`
value. Every annotation field it emits is blank by construction.

Usage:
    python3 tools/render_annotation_worksheet.py docs/heldout/heldout_v2_scenarios.json
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOGUE = REPO / "scripts" / "adaptive_hint_data.gd"

BATCH_SIZE = 8


def parse_catalogue() -> dict[str, dict]:
    """Extract hint metadata from the GDScript catalogue.

    Parsed rather than duplicated so the worksheet cannot drift from the
    catalogue the experiment actually uses.
    """
    src = CATALOGUE.read_text()
    hints: dict[str, dict] = {}

    # Each entry looks like:  "h_id": { ... },  at one indent level.
    for match in re.finditer(r'^\t"(h_[a-z_]+)":\s*\{(.*?)^\t\},', src, re.S | re.M):
        hint_id, body = match.group(1), match.group(2)

        def field(name: str) -> str:
            m = re.search(rf'"{name}":\s*"((?:[^"\\]|\\.)*)"', body)
            return m.group(1).replace('\\"', '"') if m else ""

        def arr(name: str) -> list[str]:
            m = re.search(rf'"{name}":\s*\[(.*?)\]', body, re.S)
            if not m:
                return []
            return re.findall(r'"([^"]+)"', m.group(1))

        hints[hint_id] = {
            "npc": field("npc"),
            "text": field("text"),
            "source": field("source"),
            "teaches": arr("teaches"),
            "requires_evidence": arr("requires_evidence"),
            "requires_evidence_absent": arr("requires_evidence_absent"),
            "requires_story_flags": arr("requires_story_flags"),
            "preferred_when_demonstrated": arr("preferred_when_demonstrated"),
        }
    return hints


def cell(values: list[str]) -> str:
    return ", ".join(f"`{v}`" for v in values) if values else "—"


def render(data: dict, hints: dict[str, dict]) -> str:
    protocol = data["protocol_version"]
    scenarios = data["scenarios"]
    out: list[str] = []

    out.append(f"# Held-out {protocol} — annotation worksheet\n")
    out.append(
        f"**Protocol:** `{protocol}` · **Scenarios:** {len(scenarios)} · "
        f"**State fingerprint:** `{data['state_fingerprint_sha256']}`\n"
    )
    out.append(
        "> **No selector was run to build this file.** `Candidate hints` lists every\n"
        "> hint declared for that character in the static catalogue — it is *not* a\n"
        "> prediction, and no Condition A / B / C logic was consulted.\n>\n"
        "> Fill in **Valid hints**, **Rationale** and **Ambiguity** yourself. Ground\n"
        "> truth may contain **one or more** hint ids, and answers *\"which hints are\n"
        "> reasonable for this player state?\"* — not *\"which one should the selector\n"
        "> pick?\"*\n"
    )
    out.append(
        "> **Why v2 supersedes v1.** A source audit found that heldout-v1 placed every\n"
        "> scenario in `castle_hall`, where no NPC is reachable: `game_world.gd` spawns\n"
        "> the three characters but has no interaction dispatch for them, and commit\n"
        "> `505f008` deleted the dialogue it once called. v2 places each character in\n"
        "> the room where their dialogue is actually reachable and adds the door flag\n"
        "> that entering that room requires. **No evidence and no knowledge state was\n"
        "> changed to improve balance.** heldout-v1 is preserved byte-identical and\n"
        "> marked `PRE-EVALUATION SUPERSEDED`; it was never annotated and no selector\n"
        "> was ever run against it.\n"
    )

    out.append("\n## Hint reference\n")
    out.append(
        "| Hint | NPC | Source | Teaches (PKM) | Requires evidence | Requires ABSENT "
        "| Requires story flag | Soft preference |"
    )
    out.append("|---|---|---|---|---|---|---|---|")
    for hint_id in sorted(hints):
        h = hints[hint_id]
        out.append(
            f"| `{hint_id}` | {h['npc']} | {h['source']} | {cell(h['teaches'])} "
            f"| {cell(h['requires_evidence'])} | {cell(h['requires_evidence_absent'])} "
            f"| {cell(h['requires_story_flags'])} "
            f"| {cell(h['preferred_when_demonstrated'])} |"
        )

    out.append(
        "\n> **`teaches`** names a real PKM v1 concept only where the hint text\n"
        "> genuinely explains it. **Soft preference** "
        "(`preferred_when_demonstrated`) marks a hint as *especially* appropriate\n"
        "> once a concept is DEMONSTRATED. It is **not** a prerequisite: an\n"
        "> unsatisfied preference never makes a hint invalid and is never a state\n"
        "> violation. Condition A ignores it entirely.\n"
        ">\n"
        "> **Story flags constrain contextual appropriateness only.** Satisfying one\n"
        "> implies nothing about comprehension.\n"
    )

    out.append("\n### Hint text\n")
    for hint_id in sorted(hints):
        out.append(f'- **`{hint_id}`** — "{hints[hint_id]["text"]}"')

    for start in range(0, len(scenarios), BATCH_SIZE):
        batch = scenarios[start : start + BATCH_SIZE]
        n = start // BATCH_SIZE + 1
        total = (len(scenarios) + BATCH_SIZE - 1) // BATCH_SIZE
        out.append(
            f"\n---\n\n## Batch {n} of {total}  ·  scenarios "
            f"{start + 1}–{start + len(batch)}\n"
        )
        for entry in batch:
            out.append(f"### `{entry['id']}`\n")
            out.append(f"- **NPC:** {entry['npc']}  ·  **Room:** `{entry['room']}`")
            out.append(f"- **Evidence:** {cell(entry['evidence_items'])}")
            out.append(f"- **Knowledge items:** {cell(entry['knowledge_items'])}")
            # PKM state is derived from flags, never stored. Annotators need it
            # to judge whether a teaching hint would be redundant, so the
            # non-UNSEEN concepts are surfaced here rather than left implicit.
            pkm = entry.get("pkm_states", {})
            active = [f"`{c}`={st}" for c, st in sorted(pkm.items()) if st != "UNSEEN"]
            out.append(
                "- **PKM (non-UNSEEN):** "
                + (", ".join(active) if active else "— (all UNSEEN)")
            )
            out.append(f"- **Story flags:** {cell(entry['story_flags'])}")
            out.append(f"- **Candidate hints:** {cell(entry['candidate_hints'])}")
            out.append("")
            out.append("| Field | Value |")
            out.append("|---|---|")
            out.append("| **Valid hints** | |")
            out.append("| **Rationale** | |")
            out.append("| **Ambiguity (low/med/high)** | |")
            out.append("")

    return "\n".join(out) + "\n"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1]).resolve()
    data = json.loads(path.read_text())

    if data.get("annotations_present"):
        print("refusing to overwrite: annotations_present is true")
        return 1

    hints = parse_catalogue()
    if len(hints) != 11:
        print(f"expected 11 catalogue entries, parsed {len(hints)}")
        return 1

    out_path = path.parent / f"ANNOTATION_WORKSHEET_{data['protocol_version']}.md"
    out_path.write_text(render(data, hints))
    print(f"wrote {out_path.relative_to(REPO)}")
    print(f"hints: {len(hints)}  scenarios: {len(data['scenarios'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
