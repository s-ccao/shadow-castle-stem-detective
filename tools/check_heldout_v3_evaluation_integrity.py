#!/usr/bin/env python3
"""Integrity proofs for the held-out v3 Condition A/B evaluation.

Answers two separate questions.

First, provenance: did anything that was frozen move? The evaluation is only
meaningful if the selector, the scenario states, and the human labels were all
fixed before the selector was ever run against them, and stayed fixed while it
ran. That is proved against the two annotated tags, not against the working
tree alone.

Second, arithmetic: does the metrics artifact actually follow from the raw
per-scenario rows? The Godot harness wrote both files, so agreeing with itself
proves nothing. This script recomputes every metric from the raw rows in a
different language and refuses to accept a number it cannot reproduce.

Run:
    python3 tools/check_heldout_v3_evaluation_integrity.py
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HELDOUT = REPO / "docs" / "heldout"

SOURCE = HELDOUT / "heldout_v3_scenarios.json"
ANNOTATED = HELDOUT / "heldout_v3_annotated.json"
RAW = HELDOUT / "heldout_v3_ab_raw.json"
METRICS = HELDOUT / "heldout_v3_ab_metrics.json"

PRE_TAG = "heldout-v3-pre-annotation"
POST_TAG = "heldout-v3-post-annotation"

## Recorded when each tag was cut. The tag OBJECT sha is checked, not just the
## commit: an annotated tag can be re-pointed at the same commit with different
## metadata, and a freeze that can be silently re-cut is not a freeze.
PRE_TAG_OBJECT = "ade5a78d935d25bb2398689e358878a94b5fdbf4"
PRE_TAG_COMMIT = "65cd6ed7d0cd052f813cadcd1016e708bce250e7"
POST_TAG_OBJECT = "56f1c7d074df9c055fda54c19debef113f0761b2"
POST_TAG_COMMIT = "43cb0212f1e7565891220d3168085777eb528331"

SOURCE_SHA256 = "dc093e987571d58bd22186c0ea15356df2354c29e99bca4386d1c3063754cd78"
ANNOTATED_SHA256 = "9d7285c794b824753af3f6a221cef3bc754bc542fe9d0cae52cb2cd09644dc9e"
ANNOTATION_FINGERPRINT = (
    "fbf9c16ed31a0fc58e9cd754bb2df7e77ad1e0f8ab40b3ea76db3ce8d704381a"
)

## The selector as it stood at both tags. Condition A and Condition B live in
## these three files and nowhere else.
SELECTOR_SOURCES = (
    "scripts/adaptive_hint_selector.gd",
    "scripts/adaptive_hint_data.gd",
    "scripts/player_knowledge_model.gd",
)
SELECTOR_SHA256 = {
    "scripts/adaptive_hint_selector.gd":
        "c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
    "scripts/adaptive_hint_data.gd":
        "a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
    "scripts/player_knowledge_model.gd":
        "55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
}

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, capture_output=True, text=True, check=True
    ).stdout.strip()


def blob_sha256(ref: str, path: str) -> str:
    blob = subprocess.run(
        ["git", "cat-file", "blob", f"{ref}:{path}"],
        cwd=REPO, capture_output=True, check=True,
    ).stdout
    return hashlib.sha256(blob).hexdigest()


def annotation_fingerprint(scenarios: list[dict]) -> str:
    """Labels only -- the same function the materializer froze."""
    return hashlib.sha256(json.dumps(
        [{"id": s["id"], "valid_hints": s["valid_hints"],
          "annotation_rationale": s["annotation_rationale"],
          "ambiguity_note": s["ambiguity_note"]} for s in scenarios],
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")).hexdigest()


def check_tags_unmoved() -> None:
    """3, 4. Neither freeze tag was re-pointed or re-cut."""
    for tag, obj, commit in (
        (PRE_TAG, PRE_TAG_OBJECT, PRE_TAG_COMMIT),
        (POST_TAG, POST_TAG_OBJECT, POST_TAG_COMMIT),
    ):
        actual_obj = git("rev-parse", tag)
        actual_commit = git("rev-parse", f"{tag}^{{commit}}")
        if actual_obj != obj:
            fail(f"{tag} object is {actual_obj}, freeze recorded {obj}")
        if actual_commit != commit:
            fail(f"{tag} commit is {actual_commit}, freeze recorded {commit}")

    # The pre-annotation source must be byte-identical at both tags, or the
    # labels were applied to a state set that had already drifted.
    pre = blob_sha256(PRE_TAG, "docs/heldout/heldout_v3_scenarios.json")
    post = blob_sha256(POST_TAG, "docs/heldout/heldout_v3_scenarios.json")
    if pre != SOURCE_SHA256:
        fail(f"{PRE_TAG} scenario source hashes to {pre}")
    if post != pre:
        fail("the scenario source differs between the two freeze tags")


def check_artifacts_unchanged() -> None:
    """1, 2. The annotated artifact and its label-only fingerprint stand."""
    on_disk = hashlib.sha256(ANNOTATED.read_bytes()).hexdigest()
    if on_disk != ANNOTATED_SHA256:
        fail(f"annotated artifact hashes to {on_disk}, freeze recorded "
             f"{ANNOTATED_SHA256}")
    at_tag = blob_sha256(POST_TAG, "docs/heldout/heldout_v3_annotated.json")
    if at_tag != ANNOTATED_SHA256:
        fail(f"annotated artifact at {POST_TAG} hashes to {at_tag}")

    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        fail("the pre-annotation scenario source changed on disk")

    payload = json.loads(ANNOTATED.read_text())
    recomputed = annotation_fingerprint(payload["scenarios"])
    if recomputed != ANNOTATION_FINGERPRINT:
        fail(f"annotation-only fingerprint is now {recomputed}, freeze "
             f"recorded {ANNOTATION_FINGERPRINT}")
    if payload["annotation_fingerprint_sha256"] != ANNOTATION_FINGERPRINT:
        fail("the artifact's own recorded fingerprint no longer matches")
    if payload.get("selector_was_run", True):
        fail("the annotated artifact now claims selector_was_run")


def check_selector_unchanged() -> None:
    """5. Condition A and B were byte-identical throughout the evaluation."""
    metrics = json.loads(METRICS.read_text())
    for path in SELECTOR_SOURCES:
        expected = SELECTOR_SHA256[path]
        on_disk = hashlib.sha256((REPO / path).read_bytes()).hexdigest()
        if on_disk != expected:
            fail(f"{path} hashes to {on_disk}, freeze recorded {expected}")
        for tag in (PRE_TAG, POST_TAG):
            at_tag = blob_sha256(tag, path)
            if at_tag != expected:
                fail(f"{path} at {tag} hashes to {at_tag}")
        recorded = metrics["selector_sha256"].get(path)
        if recorded != expected:
            fail(f"the metrics artifact attributes {path} to {recorded}")


def check_evaluation_scope() -> None:
    """Condition C must not have been run, and state must not have moved."""
    raw = json.loads(RAW.read_text())
    metrics = json.loads(METRICS.read_text())
    for name, payload in (("raw", raw), ("metrics", metrics)):
        if payload["conditions_run"] != ["A", "B"]:
            fail(f"{name} artifact reports conditions_run "
                 f"{payload['conditions_run']}")
        if payload["condition_c_run"]:
            fail(f"{name} artifact reports Condition C was run")

    annotated = {s["id"]: s for s in json.loads(ANNOTATED.read_text())["scenarios"]}
    if len(raw["scenarios"]) != 48:
        fail(f"raw artifact has {len(raw['scenarios'])} scenarios, expected 48")
    for row in raw["scenarios"]:
        source = annotated.get(row["scenario_id"])
        if source is None:
            fail(f"{row['scenario_id']} is not an annotated scenario")
            continue
        for field in ("npc", "room", "stage", "evidence_items"):
            if row[field] != source[field]:
                fail(f"{row['scenario_id']}: evaluation row's '{field}' differs "
                     "from the frozen annotation")
        if row["human_valid_hints"] != source["valid_hints"]:
            fail(f"{row['scenario_id']}: evaluation row's labels differ from "
                 "the frozen annotation")


def recompute(rows: list[dict], cond: str) -> dict:
    delivered = [r for r in rows if not r[cond]["silence"]]
    teaching = [r for r in delivered if r[cond]["teaches_pkm_concept"]]
    return {
        "RelevantHintRate": (
            sum(1 for r in delivered if r[cond]["relevant"]), len(rows)),
        "Coverage": (len(delivered), len(rows)),
        "StateViolationRate": (
            sum(1 for r in delivered if r[cond]["state_violation"]), len(delivered)),
        "RedundantHintRate": (
            sum(1 for r in delivered if r[cond]["redundant"]), len(delivered)),
        "RedundantWhenTeachable": (
            sum(1 for r in teaching if r[cond]["redundant"]), len(teaching)),
    }


def check_metrics_follow_from_raw() -> None:
    """The metrics artifact must be derivable from the raw rows, not asserted."""
    raw = json.loads(RAW.read_text())
    metrics = json.loads(METRICS.read_text())
    rows = raw["scenarios"]

    buckets = {"overall": rows}
    for npc in sorted({r["npc"] for r in rows}):
        buckets[f"by_npc/{npc}"] = [r for r in rows if r["npc"] == npc]

    for label, subset in buckets.items():
        reported = (metrics["overall"] if label == "overall"
                    else metrics["by_npc"][label.split("/", 1)[1]])
        for cond in ("A", "B"):
            for key, (num, den) in recompute(subset, cond).items():
                got = reported[cond]["rates"][key]
                if [got["numerator"], got["denominator"]] != [num, den]:
                    fail(f"{label} {cond} {key}: artifact says "
                         f"{got['numerator']}/{got['denominator']}, "
                         f"recomputed {num}/{den}")
                    continue
                if den == 0:
                    if got["rate"] is not None:
                        fail(f"{label} {cond} {key}: zero denominator carries "
                             f"rate {got['rate']}")
                    if got.get("report") != "N/A (0 teaching hints delivered)":
                        fail(f"{label} {cond} {key}: zero denominator reported "
                             f"as {got.get('report')!r}")
                elif abs(float(got["rate"]) - num / den) > 1e-9:
                    fail(f"{label} {cond} {key}: rate {got['rate']} does not "
                         f"match {num}/{den}")

    divergent = sorted(r["ordinal"] for r in rows
                       if r["A"]["selected_hint_id"] != r["B"]["selected_hint_id"])
    reported = sorted(d["ordinal"] for d in metrics["divergent_scenarios"])
    if divergent != reported:
        fail(f"divergent ordinals recomputed as {divergent}, artifact says "
             f"{reported}")


def main() -> int:
    for path in (SOURCE, ANNOTATED, RAW, METRICS):
        if not path.exists():
            print(f"FAIL: {path.relative_to(REPO)} is missing")
            return 1

    check_tags_unmoved()
    check_artifacts_unchanged()
    check_selector_unchanged()
    check_evaluation_scope()
    check_metrics_follow_from_raw()

    print("Held-out v3 — evaluation integrity proofs")
    print(f"  {PRE_TAG:<30} {PRE_TAG_OBJECT} -> {PRE_TAG_COMMIT}")
    print(f"  {POST_TAG:<30} {POST_TAG_OBJECT} -> {POST_TAG_COMMIT}")
    print(f"  annotated artifact      {ANNOTATED_SHA256}")
    print(f"  annotation fingerprint  {ANNOTATION_FINGERPRINT}")
    for path in SELECTOR_SOURCES:
        print(f"  {path:<38} {SELECTOR_SHA256[path]}")
    print("  Condition C: not run")
    print("  metrics recomputed from raw rows, overall and per NPC")

    if failures:
        print(f"\ncheck_heldout_v3_evaluation_integrity: FAIL ({len(failures)})")
        for failure in failures:
            print("  - " + failure)
        return 1

    print("\ncheck_heldout_v3_evaluation_integrity: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
