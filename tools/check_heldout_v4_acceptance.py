#!/usr/bin/env python3
"""Acceptance checks A-G for the generated heldout-v4 benchmark.

The generator asserts a great deal on its way to writing the artifact. This
program asserts the same things about the file that actually landed on disk,
which is a different claim: a generator that believed it was correct and a
benchmark that is correct are not the same object.

  A  size and balance                  §2, §8.1
  B  uniqueness and non-contamination  §4.1, §4.2, §4.4
  C  chronology                        §12 -- run in Godot, recorded here
  D  canonical PKM                     §13 -- 72 x 8 exact matches
  E  CORE structural coverage          §8.4, with unreachable values named
  F  STRESS bin occupancy              §7.1, §7.5 including preregistered backfill
  G  selector isolation                §14

The structural feature definitions come from `generate_heldout_v4` rather than
being restated, so this file cannot drift from the generator's notion of a
feature. Everything else -- fingerprints, counts, coverage, labels -- is
recomputed from the JSON on disk.

    python3 tools/check_heldout_v4_acceptance.py
    python3 tools/check_heldout_v4_acceptance.py --fault-test
"""

from __future__ import annotations

import copy
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import generate_heldout_v4 as gen
import pkm_reference

ARTIFACT = REPO / "docs" / "heldout" / "heldout_v4_scenarios.json"
AUDIT = REPO / "docs" / "heldout" / "heldout_v4_generation_audit.json"

# spec §14 -- keys that would mean a label or a condition's output leaked in.
FORBIDDEN_KEYS = ("relevance", "redundancy", "predicted_winner", "rationale",
                  "ambiguity", "condition_a", "condition_b", "condition_c",
                  "selected_hint", "model_output", "human_label")


def load() -> dict:
    doc = json.loads(ARTIFACT.read_text())
    doc["_audit"] = json.loads(AUDIT.read_text())
    return doc


def check_a(doc, problems) -> dict:
    """Size and balance."""
    scen = doc["scenarios"]
    if len(scen) != 72:
        problems.append(f"A: {len(scen)} scenarios, expected 72")
    per = Counter((s["stratum"], s["npc"]) for s in scen)
    for stratum, want in (("CORE", 16), ("STRESS", 8)):
        for npc in gen.NPCS:
            got = per[(stratum, npc)]
            if got != want:
                problems.append(f"A: {stratum}/{npc} has {got}, expected {want}")
    ordinals = [s["ordinal"] for s in scen]
    if ordinals != list(range(1, len(scen) + 1)):
        problems.append("A: ordinals are not 1..N in file order")
    strata_order = [s["stratum"] for s in scen]
    if strata_order != ["CORE"] * 48 + ["STRESS"] * 24:
        problems.append("A: CORE does not precede STRESS in file order")
    return {"total": len(scen),
            "per_stratum_npc": {f"{k[0]}/{k[1]}": v for k, v in sorted(per.items())}}


def check_b(doc, problems) -> dict:
    """Uniqueness, and no overlap with anything previously shown or synthetic."""
    scen = doc["scenarios"]
    ids = [s["id"] for s in scen]
    if len(set(ids)) != len(ids):
        dupe = [i for i, n in Counter(ids).items() if n > 1]
        problems.append(f"B: duplicate ids {dupe}")

    # Recomputed from the state fields, not read back from the file: a stored
    # fingerprint that no longer describes its own state must not pass.
    recomputed = []
    for s in scen:
        fp = gen.fingerprint(s["npc"], s["room"], s["evidence_items"],
                             s["knowledge_items"], s["story_flags"])
        if fp != s["state_fingerprint_sha256"]:
            problems.append(f"B: {s['id']} does not hash to its recorded fingerprint")
        recomputed.append(fp)
    if len(set(recomputed)) != len(recomputed):
        collide = [f for f, n in Counter(recomputed).items() if n > 1]
        problems.append(f"B: {len(collide)} states appear more than once")

    exclusion, info = gen.load_exclusion()
    overlap = sorted(set(recomputed) & exclusion)
    if overlap:
        problems.append(f"B: {len(overlap)} states were already shown in v2/v3")

    # §4.4 -- every synthetic and dev fixture lives in castle_hall, and v4 uses
    # no castle_hall state, so the two sets cannot intersect.
    rooms = Counter(s["room"] for s in scen)
    if "castle_hall" in rooms:
        problems.append(f"B: {rooms['castle_hall']} states are in castle_hall, "
                        f"where every synthetic fixture lives")
    return {"unique_ids": len(set(ids)), "unique_fingerprints": len(set(recomputed)),
            "exact_duplicates": len(recomputed) - len(set(recomputed)),
            "exclusion_size": info["count"], "exclusion_digest": info["digest"],
            "intersection_with_exclusion": len(overlap),
            "intersection_with_synthetic_fixtures": rooms.get("castle_hall", 0),
            "rooms": dict(sorted(rooms.items()))}


def check_d(doc, problems) -> dict:
    """Canonical PKM, re-derived for all 72 states. Zero tolerance."""
    matches = 0
    mismatches = []
    for s in doc["scenarios"]:
        derived = pkm_reference.serialize([], s["story_flags"], s["evidence_items"])
        stored = s["pkm_states"]
        if set(stored) != set(pkm_reference.CONCEPTS):
            problems.append(f"D: {s['id']} does not serialize all 8 concepts")
            continue
        for concept in sorted(pkm_reference.CONCEPTS):
            if stored[concept] == derived[concept]:
                matches += 1
            else:
                mismatches.append(f"{s['id']}/{concept}")
    if mismatches:
        problems.append(f"D: {len(mismatches)} PKM mismatches, "
                        f"beginning with {mismatches[0]}")
    expected = len(doc["scenarios"]) * len(pkm_reference.CONCEPTS)
    if matches != expected:
        problems.append(f"D: {matches} exact matches, expected {expected}")
    if doc.get("pkm_serialization") != pkm_reference.CANONICAL_MARKER_VALUE:
        problems.append("D: the artifact does not declare canonical serialization")
    if doc.get("pkm_model_sha256") != pkm_reference.model_sha256():
        problems.append("D: the artifact cites a different PlayerKnowledgeModel")
    return {"states": len(doc["scenarios"]), "concepts": len(pkm_reference.CONCEPTS),
            "exact_matches": matches, "mismatches": len(mismatches)}


def check_e(doc, problems, pool) -> dict:
    """CORE coverage against what is actually reachable after exclusion."""
    report = {}
    for npc in gen.NPCS:
        reachable = defaultdict(set)
        for c in pool:
            if c["npc"] == npc:
                for f in gen.FEATURES:
                    reachable[f].add(c["features"][f])
        core = [s for s in doc["scenarios"]
                if s["npc"] == npc and s["stratum"] == "CORE"]
        per_feature = {}
        for f in gen.FEATURES:
            covered = {_norm(s["structural_features"][f]) for s in core}
            reach = {_norm(v) for v in reachable[f]}
            missing = sorted(str(v) for v in reach - covered)
            per_feature[f] = {
                "covered": len(covered & reach), "reachable": len(reach),
                "complete": not missing,
                "unreachable_values_not_covered": missing if f not in
                gen.REQUIRED_COVERAGE else [],
            }
            if f in gen.REQUIRED_COVERAGE and missing:
                problems.append(f"E: {npc} CORE misses {f} values {missing}")
        report[npc] = per_feature
    return report


def _norm(value):
    """JSON turns the feature tuples into lists; compare them as tuples."""
    return tuple(_norm(v) for v in value) if isinstance(value, (list, tuple)) else value


def check_f(doc, problems) -> dict:
    """STRESS bin occupancy, including the preregistered backfill."""
    report = {}
    backfilled = []
    for npc in gen.NPCS:
        rows = [s for s in doc["scenarios"]
                if s["npc"] == npc and s["stratum"] == "STRESS"]
        bins = [s["stress_bin"] for s in rows]
        if bins != list(gen.STRESS_BINS):
            problems.append(f"F: {npc} STRESS bins are {bins}, expected B1..B8 "
                            f"in order")
        report[npc] = {}
        for s in rows:
            report[npc][s["stress_bin"]] = {
                "id": s["id"], "bin_empty": s["bin_empty"],
                "stage": s["stage"], "progression_bucket": s["progression_bucket"],
                "state_fingerprint_sha256": s["state_fingerprint_sha256"][:16],
            }
            if s["bin_empty"]:
                backfilled.append(f"{npc}/{s['stress_bin']}")

    # §7.5 predicted exactly one empty bin, before any state was selected.
    expected = ["butler/B3_max_candidates_pref_active"]
    if backfilled != expected:
        problems.append(f"F: backfilled bins are {backfilled}, but §7.5 "
                        f"preregistered {expected}")
    return {"bins": report, "backfilled": backfilled,
            "preregistered_backfill": expected}


def check_g(doc, problems) -> dict:
    """Selector isolation: no condition ran, no model ran, nothing is labelled."""
    if doc.get("selector_was_run") is not False:
        problems.append("G: selector_was_run is not false")
    if doc.get("annotations_present") is not False:
        problems.append("G: annotations_present is not false")

    labelled = [s["id"] for s in doc["scenarios"]
                if s.get("valid_hints") or s.get("annotation") is not None]
    if labelled:
        problems.append(f"G: {len(labelled)} scenarios carry a label, "
                        f"beginning with {labelled[0]}")

    blob = json.dumps({k: v for k, v in doc.items() if k != "_audit"}).lower()
    found = sorted({k for k in FORBIDDEN_KEYS if f'"{k}"' in blob})
    if found:
        problems.append(f"G: the artifact contains selector or label keys {found}")

    integrity = doc["_audit"]["integrity"]
    for key in ("selector_was_run", "annotations_present", "condition_a_called",
                "condition_b_called", "condition_c_called", "llm_called",
                "relevance_labels_present"):
        if integrity.get(key) is not False:
            problems.append(f"G: the audit does not record {key} as false")
    return {"labelled_scenarios": len(labelled), "forbidden_keys_found": found,
            "audit_integrity": integrity}


# ---------------------------------------------------------------------------
# fault injection -- a check that cannot fail proves nothing


def _fault_cases():
    def drop_scenario(doc):
        doc["scenarios"] = doc["scenarios"][:-1]

    def clone_state(doc):
        a, b = doc["scenarios"][0], doc["scenarios"][1]
        for key in ("npc", "room", "evidence_items", "knowledge_items",
                    "story_flags", "state_fingerprint_sha256"):
            b[key] = copy.deepcopy(a[key])

    def stale_fingerprint(doc):
        doc["scenarios"][0]["state_fingerprint_sha256"] = "0" * 64

    def reuse_v3(doc):
        v3 = json.loads(
            (REPO / "docs" / "heldout" / "heldout_v3_scenarios.json").read_text())
        old = v3["scenarios"][0]
        target = next(s for s in doc["scenarios"] if s["npc"] == old["npc"])
        for key in ("room", "evidence_items", "knowledge_items", "story_flags"):
            target[key] = copy.deepcopy(old[key])
        target["state_fingerprint_sha256"] = gen.fingerprint(
            target["npc"], target["room"], target["evidence_items"],
            target["knowledge_items"], target["story_flags"])

    def synthetic_room(doc):
        doc["scenarios"][0]["room"] = "castle_hall"
        doc["scenarios"][0]["state_fingerprint_sha256"] = gen.fingerprint(
            doc["scenarios"][0]["npc"], "castle_hall",
            doc["scenarios"][0]["evidence_items"],
            doc["scenarios"][0]["knowledge_items"],
            doc["scenarios"][0]["story_flags"])

    def wrong_pkm(doc):
        s = doc["scenarios"][0]
        s["pkm_states"]["indicator_reaction"] = "DEMONSTRATED"

    def drop_core_value(doc):
        # Replace every butler CORE early-bucket state with a copy of a late
        # one, so a required dimension loses a value it could have covered.
        core = [s for s in doc["scenarios"]
                if s["npc"] == "butler" and s["stratum"] == "CORE"]
        donor = next(s for s in core if s["progression_bucket"] == "late")
        for s in core:
            if s["progression_bucket"] == "early":
                s["progression_bucket"] = "late"
                s["structural_features"] = copy.deepcopy(donor["structural_features"])

    def unbackfill(doc):
        for s in doc["scenarios"]:
            if s["bin_empty"]:
                s["bin_empty"] = False

    def shuffle_bins(doc):
        rows = [s for s in doc["scenarios"]
                if s["npc"] == "gardener" and s["stratum"] == "STRESS"]
        rows[0]["stress_bin"], rows[1]["stress_bin"] = (
            rows[1]["stress_bin"], rows[0]["stress_bin"])

    def add_label(doc):
        doc["scenarios"][0]["valid_hints"] = ["chem_indicator_intro"]

    def add_relevance(doc):
        doc["scenarios"][0]["relevance"] = "RELEVANT"

    def selector_ran(doc):
        doc["selector_was_run"] = True

    def audit_lies(doc):
        doc["_audit"]["integrity"]["llm_called"] = True

    def bad_balance(doc):
        doc["scenarios"][0]["stratum"] = "STRESS"

    return [
        ("a scenario is missing", check_a, drop_scenario),
        ("strata are unbalanced", check_a, bad_balance),
        ("two scenarios share a state", check_b, clone_state),
        ("a fingerprint no longer matches its state", check_b, stale_fingerprint),
        ("a v3 state is reused", check_b, reuse_v3),
        ("a synthetic-fixture room is used", check_b, synthetic_room),
        ("a PKM value is wrong", check_d, wrong_pkm),
        ("a required CORE dimension loses a value", check_e, drop_core_value),
        ("the backfilled bin is hidden", check_f, unbackfill),
        ("STRESS bins are out of order", check_f, shuffle_bins),
        ("a scenario is labelled", check_g, add_label),
        ("a relevance judgement leaks in", check_g, add_relevance),
        ("the artifact records a selector run", check_g, selector_ran),
        ("the audit admits an LLM call", check_g, audit_lies),
    ]


def run_fault_tests(doc, pool) -> int:
    print("fault injection -- every check is run against a corrupted artifact")
    undetected = []
    for label, check, mutate in _fault_cases():
        broken = copy.deepcopy(doc)
        mutate(broken)
        problems: list[str] = []
        if check is check_e:
            check(broken, problems, pool)
        else:
            check(broken, problems)
        if problems:
            print(f"  caught  {label}")
        else:
            undetected.append(label)
            print(f"  MISSED  {label}")
    if undetected:
        print(f"\ncheck_heldout_v4_acceptance --fault-test: FAIL "
              f"({len(undetected)} undetected)")
        return 1
    print(f"\ncheck_heldout_v4_acceptance --fault-test: PASS "
          f"({len(_fault_cases())} faults, all detected)")
    return 0


def main() -> int:
    doc = load()
    pool = gen.build_candidates(
        gen.parse_catalogue(), pkm_reference.load_concepts(),
        gen.derived_concept_sets(gen.parse_catalogue(),
                                 pkm_reference.load_concepts())[0])
    exclusion, _ = gen.load_exclusion()
    pool = [c for c in pool if c["fingerprint"] not in exclusion]

    if "--fault-test" in sys.argv:
        return run_fault_tests(doc, pool)

    problems: list[str] = []
    a = check_a(doc, problems)
    b = check_b(doc, problems)
    d = check_d(doc, problems)
    e = check_e(doc, problems, pool)
    f = check_f(doc, problems)
    g = check_g(doc, problems)

    print("heldout-v4 acceptance — docs/heldout/heldout_v4_scenarios.json")
    print(f"  A size       {a['total']} scenarios; "
          + ", ".join(f"{k} {v}" for k, v in a["per_stratum_npc"].items()))
    print(f"  B unique     {b['unique_ids']} ids, {b['unique_fingerprints']} "
          f"fingerprints, {b['exact_duplicates']} exact duplicates")
    print(f"    contamination  {b['intersection_with_exclusion']} of "
          f"{b['exclusion_size']} previously-shown states; "
          f"{b['intersection_with_synthetic_fixtures']} synthetic-fixture states")
    print(f"  C chronology tests/heldout_v4_chronology_test.gd (Godot; "
          f"16 rules x 3 layers)")
    print(f"  D pkm        {d['states']} x {d['concepts']} = "
          f"{d['exact_matches']} exact matches, {d['mismatches']} mismatches")
    print("  E coverage")
    for npc in gen.NPCS:
        need = [f"{k} {e[npc][k]['covered']}/{e[npc][k]['reachable']}"
                for k in gen.REQUIRED_COVERAGE]
        print(f"    {npc:9s} required: " + ", ".join(need))
    print("  F stress")
    for npc in gen.NPCS:
        empty = [k for k, v in f["bins"][npc].items() if v["bin_empty"]]
        print(f"    {npc:9s} 8 bins filled; backfilled: {empty or 'none'}")
    print(f"  G isolation  {g['labelled_scenarios']} labels, "
          f"{len(g['forbidden_keys_found'])} selector keys; "
          f"audit records every condition and the model as not called")

    unreachable_note = {
        npc: {k: v["reachable"] for k, v in e[npc].items() if not v["complete"]}
        for npc in gen.NPCS}
    print("\n  structurally not fully covered (reported, not required, §8.4):")
    for npc in gen.NPCS:
        print(f"    {npc:9s} " + ", ".join(
            f"{k} {e[npc][k]['covered']}/{e[npc][k]['reachable']}"
            for k in unreachable_note[npc]) or "    none")

    if problems:
        print(f"\ncheck_heldout_v4_acceptance: FAIL ({len(problems)})")
        for p in problems:
            print("  - " + p)
        return 1
    print("\ncheck_heldout_v4_acceptance: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
