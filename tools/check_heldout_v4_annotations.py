#!/usr/bin/env python3
"""Verification for the frozen heldout-v4 human annotations.

The materializer wrote the labels; this program checks the file that landed on
disk. It deliberately shares no code and no constants with
`materialize_heldout_v4_annotations.py` -- it re-reads the frozen
pre-annotation artifact and re-derives hint eligibility from the GDScript
catalogue, so a mistake in the writer cannot be echoed back as a pass.

  1  the pre-annotation source is still byte-identical to the freeze
  2  exactly 72 scenarios, in ordinal order, ids matching the source
  3  all 72 carry a real annotation (rationale and ambiguity both present)
  4  every valid_hints entry is hard-eligible, re-derived from the catalogue
  5  state, path, PKM and eligible-hint data are unchanged, field by field
  6  the state-only content hash matches the pre-annotation states exactly
  7  no selector ran and no Condition A/B/C output is present
  8  hashes and distributions, reported

NONE -- an empty `valid_hints` alongside a real rationale and ambiguity -- is a
legitimate label and is never treated as a missing annotation.

    python3 tools/check_heldout_v4_annotations.py
    python3 tools/check_heldout_v4_annotations.py --fault-test
"""

from __future__ import annotations

import copy
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import generate_heldout_v4 as gen

SOURCE = REPO / "docs" / "heldout" / "heldout_v4_scenarios.json"
ANNOTATED = REPO / "docs" / "heldout" / "heldout_v4_annotated.json"

## Independently restated here rather than imported: this is the value the
## freeze commit and the `heldout-v4-pre-annotation` tag published, and the
## point of the check is to compare the writer's belief against it.
FROZEN_SOURCE_SHA256 = (
    "1bb1535f64168fe4c5e6fe767aabe841761d5bc248a2e17234d29942c3a0a23d"
)

STATE_FIELDS = (
    "id", "ordinal", "npc", "room", "stage", "stratum", "stress_bin",
    "bin_empty", "progression_bucket", "witness_path", "evidence_items",
    "knowledge_items", "story_flags", "pkm_states", "candidate_hints",
    "eligible_hints", "eligible_hint_count", "structural_features",
    "state_fingerprint_sha256",
)

AMBIGUITY_LEVELS = ("LOW", "MEDIUM", "HIGH")

# Keys that would mean a selector's output, or a condition's, leaked into the
# ground truth. Same list the generation acceptance check uses for §14, minus
# the two fields annotation legitimately fills.
FORBIDDEN_KEYS = (
    "relevance", "redundancy", "predicted_winner", "condition_a", "condition_b",
    "condition_c", "selected_hint", "model_output", "selector_choice",
    "selector_output", "predicted_hints", "score", "scores",
)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def canonical(value: object) -> str:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )


def state_content_hash(scenarios: list[dict]) -> str:
    return sha256_text(
        canonical([{f: s[f] for f in STATE_FIELDS} for s in scenarios])
    )


def annotation_fingerprint(scenarios: list[dict]) -> str:
    return sha256_text(
        canonical([
            {
                "id": s["id"],
                "valid_hints": s["valid_hints"],
                "annotation_rationale": s["annotation"]["annotation_rationale"],
                "ambiguity_note": s["annotation"]["ambiguity_note"],
            }
            for s in scenarios
        ])
    )


def walk_keys(node: object):
    """Every key appearing anywhere in the document, at any depth."""
    if isinstance(node, dict):
        for key, value in node.items():
            yield key
            yield from walk_keys(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk_keys(item)


def check_source(problems: list[str]) -> dict:
    """1 -- the pre-annotation artifact must not have moved."""
    raw = SOURCE.read_text()
    actual = sha256_text(raw)
    if actual != FROZEN_SOURCE_SHA256:
        problems.append(
            f"source: heldout_v4_scenarios.json is {actual}, "
            f"frozen at {FROZEN_SOURCE_SHA256}"
        )
    doc = json.loads(raw)
    if doc["annotations_present"] is not False:
        problems.append("source: annotations_present is no longer false")
    if doc["selector_was_run"] is not False:
        problems.append("source: selector_was_run is no longer false")
    for s in doc["scenarios"]:
        if s["valid_hints"] or s["annotation"] is not None:
            problems.append(f"source: {s['id']} carries a label")
            break
    return {"sha256": actual, "unchanged": actual == FROZEN_SOURCE_SHA256}


def check_shape(doc: dict, source: dict, problems: list[str]) -> dict:
    """2 and 3 -- count, alignment, and a real annotation on every scenario."""
    scen = doc["scenarios"]
    if len(scen) != 72:
        problems.append(f"shape: {len(scen)} scenarios, expected 72")
    if doc["scenario_count"] != len(scen):
        problems.append("shape: scenario_count disagrees with the array")
    if doc["annotation_count"] != len(scen):
        problems.append("shape: annotation_count disagrees with the array")
    if doc["annotations_present"] is not True:
        problems.append("shape: annotations_present is not true")

    if [s["ordinal"] for s in scen] != list(range(1, len(scen) + 1)):
        problems.append("shape: ordinals are not 1..N in file order")
    if [s["id"] for s in scen] != [s["id"] for s in source["scenarios"]]:
        problems.append("shape: scenario ids do not match the source, in order")

    annotated = 0
    for s in scen:
        note = s.get("annotation")
        if not isinstance(note, dict):
            problems.append(f"annotation: {s['id']} has no annotation object")
            continue
        rationale = note.get("annotation_rationale")
        ambiguity = note.get("ambiguity_note")
        # An annotation is real when a human recorded both a reason and a
        # confidence. This -- not a non-empty hint list -- is what separates an
        # annotated NONE from a scenario nobody looked at.
        if not isinstance(rationale, str) or not rationale.strip():
            problems.append(f"annotation: {s['id']} has no rationale")
            continue
        if ambiguity not in AMBIGUITY_LEVELS:
            problems.append(
                f"annotation: {s['id']} ambiguity '{ambiguity}' is not a level"
            )
            continue
        if not isinstance(s.get("valid_hints"), list):
            problems.append(f"annotation: {s['id']} valid_hints is not a list")
            continue
        annotated += 1

    if annotated != len(scen):
        problems.append(f"annotation: {annotated}/{len(scen)} are annotated")
    return {"scenarios": len(scen), "annotated": annotated}


def check_eligibility(doc: dict, problems: list[str]) -> dict:
    """4 -- every label names a hint this state actually makes eligible.

    Eligibility is re-parsed from `scripts/adaptive_hint_data.gd` rather than
    read from the artifact's own `eligible_hints`, so a label can't be excused
    by a corrupted copy of the thing it is checked against.
    """
    hints = gen.parse_catalogue()
    offenders = []
    checked = 0
    for s in doc["scenarios"]:
        derived = gen.hard_eligible(
            hints,
            s["npc"],
            set(s["evidence_items"]),
            set(s["story_flags"]),
            s["pkm_states"],
        )
        if sorted(derived) != sorted(s["eligible_hints"]):
            problems.append(
                f"eligibility: {s['id']} eligible_hints disagrees with the "
                f"catalogue"
            )
        if len(set(s["valid_hints"])) != len(s["valid_hints"]):
            problems.append(f"eligibility: {s['id']} valid_hints has a duplicate")
        for hid in s["valid_hints"]:
            checked += 1
            if hid not in derived:
                offenders.append(f"{s['id']}:{hid}")
            elif hints[hid]["npc"] != s["npc"]:
                offenders.append(f"{s['id']}:{hid} (wrong npc)")
    if offenders:
        problems.append(
            f"eligibility: {len(offenders)} labels are not hard-eligible: "
            + ", ".join(offenders[:6])
        )
    return {"labels_checked": checked, "not_eligible": len(offenders)}


def check_state_preserved(doc: dict, source: dict, problems: list[str]) -> dict:
    """5 and 6 -- annotation changed nothing but the labels."""
    drifted = Counter()
    by_id = {s["id"]: s for s in source["scenarios"]}
    for s in doc["scenarios"]:
        origin = by_id.get(s["id"])
        if origin is None:
            problems.append(f"state: {s['id']} is not in the source")
            continue
        for field in STATE_FIELDS:
            if s[field] != origin[field]:
                drifted[field] += 1
        # Nothing beyond the two annotation fields may have been added either.
        extra = set(s) - set(origin)
        if extra:
            problems.append(f"state: {s['id']} gained keys {sorted(extra)}")
    if drifted:
        problems.append(f"state: fields changed {dict(drifted)}")

    theirs = state_content_hash(source["scenarios"])
    ours = state_content_hash(doc["scenarios"])
    if ours != theirs:
        problems.append("state: content hash differs from the pre-annotation set")
    if doc.get("state_content_sha256") != ours:
        problems.append("state: recorded state_content_sha256 is not the real one")
    if doc.get("state_aggregate_sha256") != source["state_aggregate_sha256"]:
        problems.append("state: state_aggregate_sha256 does not match the source")
    return {
        "state_content_sha256": ours,
        "matches_pre_annotation": ours == theirs,
        "fields_changed": sum(drifted.values()),
    }


def check_isolation(doc: dict, problems: list[str]) -> dict:
    """7 -- no selector ran, and no condition's output is in the file."""
    if doc.get("selector_was_run") is not False:
        problems.append("isolation: selector_was_run is not false")
    present = sorted({k for k in walk_keys(doc) if k in FORBIDDEN_KEYS})
    if present:
        problems.append(f"isolation: selector/condition keys present {present}")
    provenance = doc.get("annotated_from", {})
    if provenance.get("file_sha256") != FROZEN_SOURCE_SHA256:
        problems.append("isolation: annotated_from does not cite the frozen file")
    if provenance.get("tag") != "heldout-v4-pre-annotation":
        problems.append("isolation: annotated_from does not cite the freeze tag")
    if doc.get("annotation_method") != "human blind relevance annotation":
        problems.append("isolation: annotation_method is not the human protocol")
    return {"selector_was_run": doc.get("selector_was_run"),
            "forbidden_keys_found": present}


def check_distribution(doc: dict, problems: list[str]) -> dict:
    """8 -- counts and hashes, recomputed rather than read back."""
    scen = doc["scenarios"]
    counts = Counter(s["annotation"]["ambiguity_note"] for s in scen)
    ambiguity = {level: counts.get(level, 0) for level in AMBIGUITY_LEVELS}
    if doc.get("ambiguity_counts") != ambiguity:
        problems.append("distribution: recorded ambiguity_counts are wrong")

    none_rows = [s for s in scen if not s["valid_hints"]]
    if doc.get("none_scenario_ordinals") != [s["ordinal"] for s in none_rows]:
        problems.append("distribution: recorded NONE ordinals are wrong")
    if doc.get("none_scenario_ids") != [s["id"] for s in none_rows]:
        problems.append("distribution: recorded NONE ids are wrong")
    if doc.get("none_scenario_count") != len(none_rows):
        problems.append("distribution: recorded NONE count is wrong")

    fingerprint = annotation_fingerprint(scen)
    if doc.get("annotation_fingerprint_sha256") != fingerprint:
        problems.append("distribution: recorded annotation fingerprint is wrong")

    return {
        "ambiguity": ambiguity,
        "none_count": len(none_rows),
        "none_ordinals": [s["ordinal"] for s in none_rows],
        "labels": sum(len(s["valid_hints"]) for s in scen),
        "annotation_fingerprint_sha256": fingerprint,
        "artifact_sha256": sha256_text(ANNOTATED.read_text()),
        "per_npc": {
            npc: dict(Counter(
                s["annotation"]["ambiguity_note"]
                for s in scen if s["npc"] == npc))
            for npc in gen.NPCS
        },
    }


def faults() -> list[tuple[str, object, object]]:
    """Each mutation must be caught by the check it is paired with."""

    def uneligible_label(doc, source):
        for s in doc["scenarios"]:
            outside = set(s["candidate_hints"]) - set(s["eligible_hints"])
            if outside:
                s["valid_hints"] = [sorted(outside)[0]]
                return

    def foreign_hint(doc, source):
        doc["scenarios"][0]["valid_hints"] = ["h_gardener_pollen"]

    def blank_annotation(doc, source):
        doc["scenarios"][3]["annotation"]["annotation_rationale"] = "  "

    def bad_ambiguity(doc, source):
        doc["scenarios"][5]["annotation"]["ambiguity_note"] = "VERY LOW"

    def drop_annotation(doc, source):
        doc["scenarios"][7]["annotation"] = None

    def edit_state(doc, source):
        # Flip to a value the concept does not already hold -- writing back the
        # value that is already there would make this a no-op and the fault
        # test would pass by accident.
        pkm = doc["scenarios"][2]["pkm_states"]
        pkm["reflection"] = (
            "LEARNING" if pkm["reflection"] == "DEMONSTRATED" else "DEMONSTRATED"
        )

    def edit_path(doc, source):
        doc["scenarios"][9]["witness_path"] = doc["scenarios"][10]["witness_path"]

    def edit_eligibility(doc, source):
        doc["scenarios"][4]["eligible_hints"] = []

    def drop_scenario(doc, source):
        doc["scenarios"].pop()

    def selector_ran(doc, source):
        doc["selector_was_run"] = True

    def condition_output(doc, source):
        doc["scenarios"][0]["condition_a"] = {"selected": "h_butler_stain"}

    def miscount(doc, source):
        doc["ambiguity_counts"]["HIGH"] = 99

    def hide_none(doc, source):
        doc["none_scenario_ordinals"] = []

    def stale_fingerprint(doc, source):
        doc["annotation_fingerprint_sha256"] = "0" * 64

    def forge_provenance(doc, source):
        doc["annotated_from"]["file_sha256"] = "0" * 64

    return [
        ("a label is not hard-eligible", check_eligibility, uneligible_label),
        ("a label belongs to another NPC", check_eligibility, foreign_hint),
        ("eligible_hints is edited", check_eligibility, edit_eligibility),
        ("a rationale is blank", check_shape, blank_annotation),
        ("an ambiguity level is invented", check_shape, bad_ambiguity),
        ("an annotation is removed", check_shape, drop_annotation),
        ("a scenario is missing", check_shape, drop_scenario),
        ("a PKM value is edited", check_state_preserved, edit_state),
        ("a witness path is edited", check_state_preserved, edit_path),
        ("the artifact records a selector run", check_isolation, selector_ran),
        ("a condition's output leaks in", check_isolation, condition_output),
        ("provenance is forged", check_isolation, forge_provenance),
        ("ambiguity counts are wrong", check_distribution, miscount),
        ("the NONE list is hidden", check_distribution, hide_none),
        ("the annotation fingerprint is stale", check_distribution,
         stale_fingerprint),
    ]


def run_fault_test() -> int:
    source = json.loads(SOURCE.read_text())
    clean = json.loads(ANNOTATED.read_text())
    failures = []
    print("fault injection -- each mutation must be caught\n")
    for name, check, mutate in faults():
        doc = copy.deepcopy(clean)
        src = copy.deepcopy(source)
        mutate(doc, src)
        problems: list[str] = []
        try:
            if check is check_state_preserved:
                check(doc, src, problems)
            elif check is check_shape:
                check(doc, src, problems)
            else:
                check(doc, problems)
        except Exception as exc:  # a crash is a detection, but a noisy one
            problems.append(f"raised {type(exc).__name__}: {exc}")
        caught = bool(problems)
        print(f"  {'caught ' if caught else 'MISSED '} {name}")
        if not caught:
            failures.append(name)
    if failures:
        print(f"\nfault test: FAIL -- {len(failures)} mutation(s) not caught")
        return 1
    print(f"\nfault test: PASS -- {len(faults())}/{len(faults())} caught")
    return 0


def main() -> int:
    if "--fault-test" in sys.argv:
        return run_fault_test()

    if not ANNOTATED.exists():
        print(f"missing {ANNOTATED.relative_to(REPO)}")
        return 1

    problems: list[str] = []
    src_info = check_source(problems)
    source = json.loads(SOURCE.read_text())
    doc = json.loads(ANNOTATED.read_text())

    shape = check_shape(doc, source, problems)
    elig = check_eligibility(doc, problems)
    state = check_state_preserved(doc, source, problems)
    iso = check_isolation(doc, problems)
    dist = check_distribution(doc, problems)

    print("heldout-v4 annotation freeze\n")
    print(f"  source     heldout_v4_scenarios.json unchanged: "
          f"{src_info['unchanged']} ({src_info['sha256'][:16]}...)")
    print(f"  shape      {shape['annotated']}/{shape['scenarios']} annotated")
    print(f"  labels     {dist['labels']} hint labels over "
          f"{shape['scenarios']} scenarios; {elig['not_eligible']} not "
          f"hard-eligible")
    print(f"  state      unchanged: {state['matches_pre_annotation']}, "
          f"{state['fields_changed']} field(s) changed")
    print(f"  isolation  selector_was_run={iso['selector_was_run']}, "
          f"{len(iso['forbidden_keys_found'])} selector/condition keys")
    print(f"  ambiguity  " + ", ".join(
        f"{k} {v}" for k, v in dist["ambiguity"].items()))
    for npc in gen.NPCS:
        row = dist["per_npc"][npc]
        print(f"    {npc:9s} " + ", ".join(
            f"{k} {row.get(k, 0)}" for k in AMBIGUITY_LEVELS))
    print(f"  NONE       {dist['none_count']} scenarios: "
          f"{dist['none_ordinals']}")
    print(f"\n  annotated artifact sha256   {dist['artifact_sha256']}")
    print(f"  annotation-only  sha256     "
          f"{dist['annotation_fingerprint_sha256']}")
    print(f"  state-only       sha256     {state['state_content_sha256']}")

    if problems:
        print(f"\ncheck_heldout_v4_annotations: FAIL ({len(problems)})")
        for p in problems:
            print("  - " + p)
        return 1
    print("\ncheck_heldout_v4_annotations: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
