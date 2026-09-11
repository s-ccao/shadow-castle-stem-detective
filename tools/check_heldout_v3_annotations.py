#!/usr/bin/env python3
"""Integrity validation for the frozen held-out v3 annotations.

Runs the full pre-evaluation check list against
`docs/heldout/heldout_v3_annotated.json` and the frozen pre-annotation source
it was derived from.

This program imports no selector, calls no scoring function, and consults no
Condition A / B / C logic. It answers only "is this artifact a faithful,
complete, internally consistent annotation of the frozen state set?" -- never
"did the selector get it right?". Running it therefore leaves the held-out
selector behaviour unobserved, which is the whole point of annotating before
evaluating.

It is deliberately a different program from the materializer. It re-derives
every fact from the two JSON files and the GDScript catalogue on disk; the only
thing it takes from the materializer is the human manifest's ordinal-to-id
claim, which is the claim it exists to cross-check.

Run:
    python3 tools/check_heldout_v3_annotations.py
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from materialize_heldout_v3_annotations import (  # noqa: E402
    MANIFEST,
    SOURCE_FILE_SHA256,
    SOURCE_STATE_FINGERPRINT,
    STATE_FIELDS,
    annotation_fingerprint,
)
from render_annotation_worksheet import parse_catalogue  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
HELDOUT = REPO / "docs" / "heldout"
SOURCE = HELDOUT / "heldout_v3_scenarios.json"
ANNOTATED = HELDOUT / "heldout_v3_annotated.json"

## Every held-out artifact that must still declare an unrun selector. The
## annotated copy is included: annotation happens before evaluation, so the
## flag must survive the freeze.
PRE_EVALUATION_ARTIFACTS = (
    HELDOUT / "heldout_v1_scenarios.json",
    HELDOUT / "heldout_v2_scenarios.json",
    SOURCE,
    ANNOTATED,
)

## The scenarios the annotator labelled NONE, by ordinal. Recorded here so the
## count is asserted rather than merely counted: a NONE that quietly appeared
## or disappeared would otherwise read as a normal annotation.
EXPECTED_NONE_ORDINALS = (6, 7, 8, 9, 10, 39)

AMBIGUITY_LEVELS = ("LOW", "MEDIUM", "HIGH")

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def check_catalogue(hints: dict[str, dict]) -> None:
    """4. The shared catalogue is the frozen 11, unchanged."""
    if len(hints) != 11:
        fail(f"expected the shared 11-hint catalogue, parsed {len(hints)}")

    # parse_catalogue does not extract `requires_concept`, and no hint declares
    # one today. If that ever changes, prerequisite checking below would skip a
    # real constraint, so refuse rather than under-check. Scanned per hint body
    # with the parser's own entry pattern, because the name also appears in
    # AdaptiveHintData.state_violations(), which reads the field rather than
    # declaring it.
    catalogue_src = (REPO / "scripts" / "adaptive_hint_data.gd").read_text()
    for match in re.finditer(r'^\t"(h_[a-z_]+)":\s*\{(.*?)^\t\},', catalogue_src, re.S | re.M):
        if '"requires_concept"' in match.group(2):
            fail(
                f"{match.group(1)} declares requires_concept; prerequisite "
                "checking in this script does not read it and must be extended"
            )


def check_state_preserved(source: dict, annotated: dict) -> None:
    """8. No scenario-state field changed between the frozen copy and this one."""
    if annotated["state_fingerprint_sha256"] != SOURCE_STATE_FINGERPRINT:
        fail("annotated copy carries a different state fingerprint")

    src_by_id = {s["id"]: s for s in source["scenarios"]}
    for entry in annotated["scenarios"]:
        original = src_by_id.get(entry["id"])
        if original is None:
            fail(f"{entry['id']} does not exist in the frozen source")
            continue
        for field in STATE_FIELDS:
            if entry[field] != original[field]:
                fail(f"{entry['id']}: state field '{field}' differs from the freeze")

    # A field the generator emitted must not have been dropped, and a new state
    # field must not have been smuggled in alongside the annotations.
    allowed_new = {"valid_hints", "annotation_rationale", "ambiguity_note"}
    for entry in annotated["scenarios"]:
        original = src_by_id.get(entry["id"])
        if original is None:
            continue
        added = set(entry) - set(original)
        if added - allowed_new:
            fail(f"{entry['id']} gained non-annotation fields: {sorted(added)}")
        if set(original) - set(entry):
            fail(f"{entry['id']} lost fields: {sorted(set(original) - set(entry))}")


def check_annotations(annotated: dict, hints: dict[str, dict]) -> dict[str, int]:
    """1, 2, 3, 5, 6 -- completeness, identity, ownership, prerequisites, NONE."""
    scenarios = annotated["scenarios"]

    if len(scenarios) != 48:
        fail(f"expected 48 scenario annotations, found {len(scenarios)}")
    if len(MANIFEST) != 48:
        fail(f"expected 48 manifest entries, found {len(MANIFEST)}")

    ambiguity_counts = {level: 0 for level in AMBIGUITY_LEVELS}
    none_ordinals: list[int] = []

    for (ordinal, expected_id, *_), entry in zip(MANIFEST, scenarios):
        sid = entry["id"]
        if sid != expected_id:
            fail(f"ordinal {ordinal} is '{sid}', manifest expects '{expected_id}'")

        rationale = entry["annotation_rationale"]
        ambiguity = entry["ambiguity_note"]

        # An annotated scenario is one with both a rationale and an ambiguity
        # level. This is what separates an annotated NONE from a blank.
        if not rationale.strip():
            fail(f"{sid} has no annotation rationale")
        if ambiguity not in AMBIGUITY_LEVELS:
            fail(f"{sid} has ambiguity '{ambiguity}', expected one of {AMBIGUITY_LEVELS}")
        else:
            ambiguity_counts[ambiguity] += 1

        valid = entry["valid_hints"]
        if not valid:
            none_ordinals.append(ordinal)
        if len(set(valid)) != len(valid):
            fail(f"{sid} repeats a hint in valid_hints")

        for hint_id in valid:
            if hint_id not in hints:
                fail(f"{sid} references '{hint_id}', which is not in the catalogue")
                continue
            if hints[hint_id]["npc"] != entry["npc"]:
                fail(
                    f"{sid} is a {entry['npc']} scenario but references "
                    f"'{hint_id}', which belongs to {hints[hint_id]['npc']}"
                )
            if hint_id not in entry["candidate_hints"]:
                fail(f"{sid} references '{hint_id}', not among its candidate hints")

            for problem in prerequisite_violations(hint_id, hints[hint_id], entry):
                fail(f"{sid}: {problem}")

    if tuple(none_ordinals) != EXPECTED_NONE_ORDINALS:
        fail(
            f"NONE scenarios are {tuple(none_ordinals)}, "
            f"expected {EXPECTED_NONE_ORDINALS}"
        )

    return ambiguity_counts


def prerequisite_violations(hint_id: str, hint: dict, entry: dict) -> list[str]:
    """5. A labelled hint must satisfy its own HARD prerequisite metadata.

    Mirrors AdaptiveHintData.state_violations(). Eligibility never establishes
    relevance -- that is the annotator's call -- but a hint whose stated
    conditions do not hold could not be delivered at all, so labelling it
    valid would be an error of fact rather than of judgement.

    `preferred_when_demonstrated` is deliberately not checked: it is a soft
    preference, and the rubric is explicit that leaving it unsatisfied does not
    invalidate a hint.
    """
    problems: list[str] = []
    for evidence_id in hint["requires_evidence"]:
        if evidence_id not in entry["evidence_items"]:
            problems.append(
                f"{hint_id} requires evidence '{evidence_id}', which is not held"
            )
    for evidence_id in hint["requires_evidence_absent"]:
        if evidence_id in entry["evidence_items"]:
            problems.append(
                f"{hint_id} requires '{evidence_id}' absent, but the player holds it"
            )
    for flag_id in hint["requires_story_flags"]:
        if flag_id not in entry["story_flags"]:
            problems.append(
                f"{hint_id} requires story flag '{flag_id}', which is not set"
            )
    return problems


def check_selector_unrun() -> None:
    """9. No pre-evaluation artifact may claim a selector was run."""
    for path in PRE_EVALUATION_ARTIFACTS:
        payload = json.loads(path.read_text())
        if payload.get("selector_was_run", True):
            fail(f"{path.name} has selector_was_run true")


def main() -> int:
    raw_source = SOURCE.read_bytes()
    source_sha = hashlib.sha256(raw_source).hexdigest()
    if source_sha != SOURCE_FILE_SHA256:
        print(f"FAIL: pre-annotation source hashes to {source_sha}")
        print(f"      the freeze recorded {SOURCE_FILE_SHA256}")
        return 1

    source = json.loads(raw_source)
    if source["annotations_present"]:
        fail("the pre-annotation source now claims annotations_present")

    raw_annotated = ANNOTATED.read_bytes()
    annotated = json.loads(raw_annotated)
    if not annotated["annotations_present"]:
        fail("the annotated copy does not set annotations_present")

    hints = parse_catalogue()
    check_catalogue(hints)
    check_state_preserved(source, annotated)
    ambiguity_counts = check_annotations(annotated, hints)
    check_selector_unrun()

    recomputed = annotation_fingerprint(annotated["scenarios"])
    if annotated["annotation_fingerprint_sha256"] != recomputed:
        fail("the recorded annotation fingerprint does not match its contents")

    print("Held-out v3 — annotation integrity validation")
    print(f"source:    {SOURCE.relative_to(REPO)}")
    print(f"annotated: {ANNOTATED.relative_to(REPO)}\n")
    print(f"annotations:            {len(annotated['scenarios'])}/48")
    print(f"state fingerprint:      {annotated['state_fingerprint_sha256']}")
    print(f"annotation fingerprint: {recomputed}")
    print(f"artifact sha256:        {hashlib.sha256(raw_annotated).hexdigest()}")
    print(
        "ambiguity:              "
        + "  ".join(f"{k} {ambiguity_counts[k]}" for k in AMBIGUITY_LEVELS)
    )
    print(f"NONE:                   {len(annotated['none_scenario_ids'])}")
    for ordinal in EXPECTED_NONE_ORDINALS:
        print(f"  {ordinal:>2}. {MANIFEST[ordinal - 1][1]}")
    print("selector_was_run false in all pre-evaluation artifacts")

    if failures:
        print(f"\ncheck_heldout_v3_annotations: FAIL ({len(failures)})")
        for failure in failures:
            print("  - " + failure)
        return 1

    print("\ncheck_heldout_v3_annotations: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
