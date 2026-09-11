#!/usr/bin/env python3
"""Canonical PKM serialization for held-out dataset generators.

WHY THIS EXISTS
---------------
`tools/generate_heldout_v3.py` carries its own PKM table:

    PKM = {concept: (learning_flag, demonstrated_flag)}

That shape can only express flags, so `pkm_of()` never consults a concept's
`learning_evidence`. Exactly one concept has one -- `indicator_reaction`, which
is LEARNING whenever the player holds `fake_red_stain` -- and exactly that
concept drifted, in 16 of the 48 heldout-v3 states. The drift was inert for
Conditions A and B (both test only DEMONSTRATED, and the one hint naming the
concept was hard-ineligible in all 16), and heldout-v3 is frozen and is NOT
repaired. But a second model of the same semantics is a second thing to keep in
sync, and it already fell out of sync once.

This module removes the second model. It does not restate the concept table: it
PARSES `scripts/player_knowledge_model.gd`, so the GDScript stays the single
source of truth and a concept added there cannot be silently missed here. The
resolution order below is transcribed from `PlayerKnowledgeModel.state_in`.

FOR FUTURE DATASETS ONLY
------------------------
Any generator producing a new held-out set must serialize `pkm_states` through
`serialize()` and stamp `"pkm_serialization": "canonical"` on the artifact.
`tests/pkm_serialization_canonical_test.gd` then proves, in Godot, that the
serialized values equal `PlayerKnowledgeModel` derivation for every concept in
every state -- a check run by a different program in a different language from
the one that wrote the file. Datasets v1, v2 and v3 predate this and are
grandfathered with their exact recorded drift pinned, not rewritten.

Run standalone to print the parsed concept table:
    python3 tools/pkm_reference.py
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Iterable, Sequence

REPO = Path(__file__).resolve().parents[1]
MODEL_SOURCE = REPO / "scripts" / "player_knowledge_model.gd"

## Stamp a generated artifact with this key so the canonical-serialization test
## knows to hold it to the strict standard.
CANONICAL_MARKER_KEY = "pkm_serialization"
CANONICAL_MARKER_VALUE = "canonical"

UNSEEN = "UNSEEN"
LEARNING = "LEARNING"
DEMONSTRATED = "DEMONSTRATED"

## `PlayerKnowledgeModel.Mastery` also declares ASSISTED, which PKM v1 leaves
## deliberately unreachable (`ASSISTED_REQUIRES_NEW_STATE = true`). It is listed
## so a reader does not mistake its absence for an oversight; `state_in` cannot
## return it, so `derive()` cannot either.
MASTERY_STATES = (UNSEEN, LEARNING, DEMONSTRATED)

_CONCEPT_RE = re.compile(r'^\t"([a-z_]+)":\s*\{(.*?)^\t\},', re.S | re.M)
_LIST_RE = r'"%s":\s*\[([^\]]*)\]'


def _string_list(body: str, key: str) -> list[str]:
    match = re.search(_LIST_RE % key, body)
    if match is None:
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def _concepts_block(source: str) -> str:
    """The body of `const CONCEPTS`, isolated from the rest of the file.

    Scoping matters: `learning_flags` and friends are also named in `state_in`
    and in the file's prose, and matching against the whole file would pick up
    text that declares nothing.
    """
    start = source.index("const CONCEPTS: Dictionary = {")
    end = source.index("\n}\n", start)
    return source[start:end]


def load_concepts(path: Path | None = None) -> dict[str, dict[str, list[str]]]:
    """Parse `PlayerKnowledgeModel.CONCEPTS` in declaration order."""
    source = (path or MODEL_SOURCE).read_text()
    block = _concepts_block(source)
    concepts: dict[str, dict[str, list[str]]] = {}
    for match in _CONCEPT_RE.finditer(block):
        name, body = match.group(1), match.group(2)
        concepts[name] = {
            "learning_flags": _string_list(body, "learning_flags"),
            "learning_evidence": _string_list(body, "learning_evidence"),
            "demonstrated_flags": _string_list(body, "demonstrated_flags"),
        }
    if not concepts:
        raise RuntimeError(f"parsed no concepts from {path or MODEL_SOURCE}")
    return concepts


CONCEPTS = load_concepts()


def derive(
    concept_id: str,
    knowledge_items: Sequence[str],
    story_flags: Sequence[str],
    evidence_items: Sequence[str],
) -> str:
    """One concept's mastery, mirroring `PlayerKnowledgeModel.state_in`.

    Resolution order is load-bearing and is the model's, not this module's: the
    comprehension check is tested BEFORE exposure, so clearing a bench without
    filing its record still reports DEMONSTRATED.

    `knowledge_items` is accepted and ignored, exactly as the model ignores it.
    It is dead state (`IGNORED_STATE_NOTE`); the parameter is kept so call sites
    read the same as the GDScript and so a future model that does read it needs
    no signature change here.
    """
    spec = CONCEPTS.get(concept_id)
    if spec is None:
        return UNSEEN

    flags = set(story_flags)
    evidence = set(evidence_items)

    if any(flag in flags for flag in spec["demonstrated_flags"]):
        return DEMONSTRATED
    if any(flag in flags for flag in spec["learning_flags"]):
        return LEARNING
    if any(item in evidence for item in spec["learning_evidence"]):
        return LEARNING
    return UNSEEN


def serialize(
    knowledge_items: Iterable[str],
    story_flags: Iterable[str],
    evidence_items: Iterable[str],
) -> dict[str, str]:
    """The `pkm_states` block for one scenario. Every concept, no omissions."""
    knowledge = list(knowledge_items)
    flags = list(story_flags)
    evidence = list(evidence_items)
    return {
        concept_id: derive(concept_id, knowledge, flags, evidence)
        for concept_id in CONCEPTS
    }


def model_sha256(path: Path | None = None) -> str:
    """Hash of the knowledge model this module parsed its table out of."""
    return hashlib.sha256((path or MODEL_SOURCE).read_bytes()).hexdigest()


# ---------------------------------------------------------------------------
# Fixture emission
# ---------------------------------------------------------------------------
#
# `tests/pkm_serialization_canonical_test.gd` validates every generated dataset
# that declares canonical serialization. Until heldout-v4 exists there is no such
# dataset, so the check would be vacuous -- it would pass because it examined
# nothing. The fixture below closes that gap: it is written by THIS module, the
# module a future generator will call, and validated in Godot by the real
# `PlayerKnowledgeModel`. If the two disagree the test fails today, not after the
# next holdout is already frozen.

FIXTURE = REPO / "docs" / "heldout" / "pkm_reference_fixture.json"

## The three major evidence items. Only `fake_red_stain` reaches a concept, but
## sweeping all three keeps the fixture honest if `learning_evidence` grows.
FIXTURE_EVIDENCE = ("fake_red_stain", "greenhouse_pollen", "deliberate_short_circuit")

## How many extra pseudo-random states to append after the covering set. Fixed,
## so the fixture is byte-reproducible.
FIXTURE_SAMPLES = 240


def _all_flags() -> list[str]:
    seen: dict[str, None] = {}
    for spec in CONCEPTS.values():
        for key in ("learning_flags", "demonstrated_flags"):
            for flag in spec[key]:
                seen[flag] = None
    return sorted(seen)


def _subset(items: Sequence[str], mask: int) -> list[str]:
    return [item for i, item in enumerate(items) if mask & (1 << i)]


def _coverage_keys(flags: list[str], evidence: list[str]) -> set[tuple]:
    """Which (concept, its own inputs) combinations a state exercises.

    A concept's mastery is a function of three things and nothing else: which of
    its demonstrated flags are set, which of its learning flags are set, and
    which of its learning evidence is held. Covering every distinct value of that
    triple, for every concept, covers every branch of `derive()`.
    """
    flag_set, evidence_set = set(flags), set(evidence)
    keys = set()
    for concept_id, spec in CONCEPTS.items():
        keys.add((
            concept_id,
            tuple(f for f in spec["demonstrated_flags"] if f in flag_set),
            tuple(f for f in spec["learning_flags"] if f in flag_set),
            tuple(e for e in spec["learning_evidence"] if e in evidence_set),
        ))
    return keys


def build_fixture() -> dict:
    """A small state set that provably exercises every branch of `derive()`.

    Two parts. First a greedy covering set over the full flag x evidence space,
    which guarantees per-concept exhaustiveness. Then a deterministic stride
    through the same space, which exercises concepts in combination -- the
    covering set alone tends to hold one concept interesting and the rest blank.
    """
    flags = _all_flags()
    space = 1 << len(flags)
    required: set[tuple] = set()
    for flag_mask in range(space):
        for evidence_mask in range(1 << len(FIXTURE_EVIDENCE)):
            required |= _coverage_keys(
                _subset(flags, flag_mask), _subset(FIXTURE_EVIDENCE, evidence_mask)
            )

    states: list[tuple[list[str], list[str]]] = []
    uncovered = set(required)
    for flag_mask in range(space):
        if not uncovered:
            break
        for evidence_mask in range(1 << len(FIXTURE_EVIDENCE)):
            chosen_flags = _subset(flags, flag_mask)
            chosen_evidence = _subset(FIXTURE_EVIDENCE, evidence_mask)
            gained = _coverage_keys(chosen_flags, chosen_evidence) & uncovered
            if gained:
                uncovered -= gained
                states.append((chosen_flags, chosen_evidence))
    if uncovered:
        raise RuntimeError(f"{len(uncovered)} concept input combinations uncovered")

    # A fixed odd stride is coprime with the power-of-two space, so it visits
    # every flag mask before repeating -- a deterministic spread, not a sample.
    stride, cursor = 2731, 0
    for i in range(FIXTURE_SAMPLES):
        cursor = (cursor + stride) % space
        states.append((
            _subset(flags, cursor), _subset(FIXTURE_EVIDENCE, i % 8)
        ))

    scenarios = [
        {
            "id": f"pkmref_{i:04d}",
            "knowledge_items": [],
            "story_flags": chosen_flags,
            "evidence_items": chosen_evidence,
            "pkm_states": serialize([], chosen_flags, chosen_evidence),
        }
        for i, (chosen_flags, chosen_evidence) in enumerate(states)
    ]

    return {
        "generated_by": "tools/pkm_reference.py",
        "purpose": (
            "Proves tools/pkm_reference.py agrees with PlayerKnowledgeModel for "
            "every concept in every state. Validated by "
            "tests/pkm_serialization_canonical_test.gd. Not a held-out set: no "
            "labels, no NPCs, no selector is ever run against it."
        ),
        "deterministic": True,
        "selector_was_run": False,
        "annotations_present": False,
        CANONICAL_MARKER_KEY: CANONICAL_MARKER_VALUE,
        "model_source": "scripts/player_knowledge_model.gd",
        "model_sha256": model_sha256(),
        "concept_count": len(CONCEPTS),
        "concept_input_combinations_covered": len(required),
        "scenario_count": len(scenarios),
        "scenarios": scenarios,
    }


def _write_fixture() -> int:
    import json

    payload = build_fixture()
    FIXTURE.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote {FIXTURE.relative_to(REPO)}")
    print(f"  scenarios                    {payload['scenario_count']}")
    print(f"  concept input combinations   "
          f"{payload['concept_input_combinations_covered']} (all covered)")
    print(f"  model sha256                 {payload['model_sha256']}")
    return 0


def main() -> int:
    import sys

    if "--emit-fixture" in sys.argv:
        return _write_fixture()

    print(f"PlayerKnowledgeModel   {MODEL_SOURCE.relative_to(REPO)}")

    print(f"sha256                 {model_sha256()}")
    print(f"concepts               {len(CONCEPTS)}\n")
    for concept_id, spec in CONCEPTS.items():
        print(f"  {concept_id}")
        for key in ("learning_flags", "learning_evidence", "demonstrated_flags"):
            if spec[key]:
                print(f"    {key:<20} {spec[key]}")
    evidence_backed = [c for c, s in CONCEPTS.items() if s["learning_evidence"]]
    print(
        f"\nconcepts whose LEARNING state can be reached by evidence alone: "
        f"{evidence_backed or 'none'}"
    )
    print("a flags-only serializer disagrees with the model on exactly these.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
