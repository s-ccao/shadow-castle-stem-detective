#!/usr/bin/env python3
"""Materialize the frozen human relevance annotations for held-out v3.

This script writes ground truth. It is therefore the one tool in the held-out
chain that must be trusted least and checked hardest, so it does three things
and nothing else:

1. It refuses to run unless the pre-annotation source still hashes to the
   frozen value, so annotations can never be attached to a drifted state set.
2. It copies every state field through verbatim and asserts equality
   afterwards, so materialization cannot quietly edit a scenario.
3. It fills `valid_hints`, `annotation_rationale` and `ambiguity_note` from the
   manifest below and from nowhere else.

It imports no selector, calls no scoring function and consults no Condition A /
B / C logic. The labels in MANIFEST are human decisions transcribed verbatim;
this file is their record, not their author. Nothing here derives a label from
state -- a label that could be computed would not be ground truth.

Verification lives in `tools/check_heldout_v3_annotations.py`, deliberately a
separate program: the thing that writes the artifact should not also be the
only thing that vouches for it.

Run:
    python3 tools/materialize_heldout_v3_annotations.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "docs" / "heldout" / "heldout_v3_scenarios.json"
OUT_JSON = REPO / "docs" / "heldout" / "heldout_v3_annotated.json"

## The frozen pre-annotation source, pinned by tag, commit and content hash.
## A mismatch on any of these means the annotations below describe a different
## state set than the one on disk, which is a stop condition, not a warning.
SOURCE_TAG = "heldout-v3-pre-annotation"
SOURCE_COMMIT = "65cd6ed7d0cd052f813cadcd1016e708bce250e7"
SOURCE_FILE_SHA256 = "dc093e987571d58bd22186c0ea15356df2354c29e99bca4386d1c3063754cd78"
SOURCE_STATE_FINGERPRINT = (
    "1b934b73123561d0e88daf14bfc8044dba0e72781f3a7a8192095c939a961c5d"
)

## Every field the generator produces that describes player state or scenario
## identity. All of these must survive materialization value-for-value.
STATE_FIELDS = (
    "id",
    "npc",
    "room",
    "stage",
    "witness_path",
    "evidence_items",
    "knowledge_items",
    "story_flags",
    "pkm_states",
    "candidate_hints",
)

## Human blind relevance annotation, heldout-v3, all 48 scenarios.
##
## Ordinal is the scenario's 1-based position in the frozen file, which the
## generator sorts by id. The id is pinned alongside it so that a reordering of
## the source cannot silently shift a label onto the wrong scenario: the
## ordinal locates the entry, the id proves it is the intended one.
##
## An empty hint tuple is the NONE label -- a real annotation meaning no hint
## provides meaningful help, not a missing one. The rubric (EVALUATION_PROTOCOL
## section 8b) makes NONE a valid answer, and the non-empty rationale and
## ambiguity level below are what distinguish an annotated NONE from an
## unannotated blank.
##
## (ordinal, scenario id, valid hints, ambiguity, rationale)
MANIFEST: tuple[tuple[int, str, tuple[str, ...], str, str], ...] = (
    (
        1,
        "v3_chemi_butler_f_dem_libl_08",
        ("h_butler_stain",),
        "LOW",
        "Player holds fake_red_stain; the hint directly responds to that "
        "evidence and explains the Butler's relationship to it.",
    ),
    (
        2,
        "v3_chemi_butler_f_uns_libn_03",
        ("h_butler_stain",),
        "LOW",
        "Same decision basis as Scenario 1; direct evidence-specific Butler "
        "response.",
    ),
    (
        3,
        "v3_chemi_butler_none_lea_libd_08",
        ("h_butler_no_evidence", "h_butler_knows_rule"),
        "MEDIUM",
        "No fake_red_stain is held. The background response has some value, "
        "while the glass-breaking/heavy-footsteps clue gives a stronger new "
        "direction toward the Greenhouse.",
    ),
    (
        4,
        "v3_chemi_butler_none_lea_libd_08_2",
        ("h_butler_no_evidence", "h_butler_knows_rule"),
        "MEDIUM",
        "Same relevance structure as Scenario 3; the player's demonstrated "
        "reflection knowledge does not materially change these Butler hints.",
    ),
    (
        5,
        "v3_chemi_butler_none_lea_libd_08_3",
        ("h_butler_no_evidence", "h_butler_knows_rule"),
        "MEDIUM",
        "Same relevance structure as Scenarios 3–4; demonstrated spectrum "
        "knowledge does not materially change these Butler hints.",
    ),
    (
        6,
        "v3_circu_butler_dfg_dem_libl_17",
        (),
        "MEDIUM",
        "The player has progressed through Greenhouse and into Circuit; the "
        "stain denial no longer provides enough new investigative value and "
        "is stale.",
    ),
    (
        7,
        "v3_circu_butler_dg_uns_libn_13",
        (),
        "LOW",
        "The generic Butler background and Greenhouse-direction clue provide "
        "no meaningful new guidance after the player has already completed "
        "the Greenhouse direction and progressed into Circuit.",
    ),
    (
        8,
        "v3_circu_butler_fg_dem_libd_19",
        (),
        "MEDIUM",
        "The Butler stain denial is still state-eligible but adds no "
        "meaningful new information after the related challenge and later "
        "progression.",
    ),
    (
        9,
        "v3_circu_butler_fg_lea_libd_14",
        (),
        "LOW",
        "The player has already progressed to Circuit; repeating the Butler "
        "stain denial provides no useful new direction or knowledge.",
    ),
    (
        10,
        "v3_circu_butler_g_lea_libd_14",
        (),
        "LOW",
        "The generic Butler background is not useful at this late state, and "
        "the Greenhouse-direction clue is already stale.",
    ),
    (
        11,
        "v3_circu_gardener_dfg_dem_libd_14",
        ("h_gardener_pollen",),
        "LOW",
        "The pollen response directly addresses held greenhouse_pollen and "
        "explains the Gardener's position. The reflection teaching is "
        "redundant because reflection is already DEMONSTRATED.",
    ),
    (
        12,
        "v3_circu_gardener_dfg_uns_libn_13",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "MEDIUM",
        "The pollen response addresses evidence. Reflection is UNSEEN, so the "
        "leaf-colour explanation provides new, non-redundant teaching even "
        "though the player has already visited the Greenhouse.",
    ),
    (
        13,
        "v3_circu_gardener_fg_dem_libd_13",
        ("h_gardener_pollen",),
        "LOW",
        "The pollen response remains directly relevant to held evidence. The "
        "reflection teaching is redundant because reflection is DEMONSTRATED.",
    ),
    (
        14,
        "v3_circu_gardener_fg_lea_libl_14",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "The pollen response addresses evidence. Reflection is only LEARNING, "
        "so applying it to leaf colour provides useful contextual "
        "reinforcement rather than redundant teaching.",
    ),
    (
        15,
        "v3_circu_gardener_g_dem_libd_13",
        ("h_gardener_pollen",),
        "LOW",
        "The pollen response directly explains held evidence; reflection "
        "teaching is redundant because reflection is DEMONSTRATED.",
    ),
    (
        16,
        "v3_circu_gardener_g_dem_libd_14",
        ("h_gardener_pollen",),
        "LOW",
        "Same decision basis as Scenario 15.",
    ),
    (
        17,
        "v3_circu_gardener_g_dem_libd_14_2",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "MEDIUM",
        "The pollen response is directly relevant. Although reflection is "
        "already DEMONSTRATED, applying it in the Greenhouse can reinforce "
        "transfer to a new context; it is still redundant under the "
        "predefined redundancy metric.",
    ),
    (
        18,
        "v3_circu_gardener_g_lea_libd_18",
        ("h_gardener_leaf_colour",),
        "LOW",
        "The pollen defence is no longer useful this late in progression. "
        "Reflection is still LEARNING, so leaf-colour teaching remains useful "
        "and non-redundant.",
    ),
    (
        19,
        "v3_circu_mechanic_dfg_dem_libd_16",
        ("h_mechanic_short_circuit",),
        "LOW",
        "The hint directly responds to deliberate_short_circuit and explains "
        "the Mechanic's suspicion. Series-basics teaching is redundant "
        "because circuit_continuity is DEMONSTRATED.",
    ),
    (
        20,
        "v3_circu_mechanic_dfg_lea_libl_14",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "One hint directly addresses the short-circuit evidence; the other "
        "provides timely circuit-continuity teaching while the concept is "
        "still LEARNING.",
    ),
    (
        21,
        "v3_circu_mechanic_dfg_lea_libl_14_2",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "Same decision basis as Scenario 20.",
    ),
    (
        22,
        "v3_circu_mechanic_dg_dem_libd_18",
        ("h_mechanic_short_circuit",),
        "LOW",
        "This is the first recorded Mechanic interaction after obtaining "
        "deliberate_short_circuit, so the evidence-specific response remains "
        "useful. Series basics are redundant after all three Circuit checks.",
    ),
    (
        23,
        "v3_circu_mechanic_dg_dem_libd_18_2",
        ("h_mechanic_short_circuit",),
        "LOW",
        "Same decision basis as Scenario 22.",
    ),
    (
        24,
        "v3_circu_mechanic_dg_lea_libd_15",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "The Mechanic response explains the short-circuit evidence, while "
        "circuit_continuity is only LEARNING, so the teaching hint is timely.",
    ),
    (
        25,
        "v3_circu_mechanic_dg_lea_libd_15_2",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "The short-circuit response provides investigation-specific "
        "explanation and series basics provide useful teaching while "
        "continuity is still LEARNING.",
    ),
    (
        26,
        "v3_circu_mechanic_fg_dem_libn_12",
        ("h_mechanic_no_evidence",),
        "LOW",
        "With no deliberate_short_circuit evidence, the old-wiring "
        "explanation is a reasonable response to the blackout. Other eligible "
        "hints are less appropriate to the current need.",
    ),
    (
        27,
        "v3_circu_mechanic_fg_dem_libn_12_2",
        ("h_mechanic_no_evidence", "h_mechanic_knows_resistance"),
        "LOW",
        "The old-wiring explanation reasonably addresses the blackout, while "
        "the maintenance-route hint adds useful concrete investigative "
        "direction. Series basics are redundant because continuity is "
        "DEMONSTRATED.",
    ),
    (
        28,
        "v3_circu_mechanic_fg_lea_libd_14",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_series_basics",
            "h_mechanic_knows_resistance",
        ),
        "LOW",
        "The three hints respectively provide a reasonable explanation, "
        "timely non-redundant teaching while continuity is LEARNING, and a "
        "concrete new investigation direction.",
    ),
    (
        29,
        "v3_circu_mechanic_fg_lea_libd_14_2",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_series_basics",
            "h_mechanic_knows_resistance",
        ),
        "LOW",
        "Same decision basis as Scenario 28.",
    ),
    (
        30,
        "v3_circu_mechanic_g_dem_libd_15",
        ("h_mechanic_no_evidence", "h_mechanic_knows_resistance"),
        "LOW",
        "The old-wiring explanation remains reasonable and the "
        "maintenance-route clue adds investigation value. Series basics are "
        "redundant because continuity is DEMONSTRATED.",
    ),
    (
        31,
        "v3_circu_mechanic_g_dem_libd_15_2",
        ("h_mechanic_no_evidence", "h_mechanic_knows_resistance"),
        "LOW",
        "Same decision basis as Scenario 30.",
    ),
    (
        32,
        "v3_circu_mechanic_g_dem_libd_15_3",
        ("h_mechanic_no_evidence", "h_mechanic_knows_resistance"),
        "LOW",
        "Same decision basis as Scenarios 30–31.",
    ),
    (
        33,
        "v3_circu_mechanic_g_uns_libd_13",
        ("h_mechanic_no_evidence", "h_mechanic_series_basics"),
        "LOW",
        "At initial Circuit entry, the old-wiring explanation is reasonable "
        "and continuity is UNSEEN, making series-basics teaching timely. The "
        "fault-isolation clue is premature.",
    ),
    (
        34,
        "v3_circu_mechanic_g_uns_libd_13_2",
        ("h_mechanic_no_evidence", "h_mechanic_series_basics"),
        "LOW",
        "Same decision basis as Scenario 33.",
    ),
    (
        35,
        "v3_green_butler_f_dem_libd_12",
        ("h_butler_stain",),
        "LOW",
        "The stain response remains a reasonable evidence-specific "
        "explanation of the Butler's relationship to fake_red_stain.",
    ),
    (
        36,
        "v3_green_butler_f_lea_libd_11",
        ("h_butler_stain",),
        "LOW",
        "The player holds fake_red_stain and has no earlier Butler "
        "conversation in this witness path; the hint directly addresses the "
        "evidence and helps explain his suspicion.",
    ),
    (
        37,
        "v3_green_butler_fg_dem_libl_11",
        ("h_butler_stain",),
        "LOW",
        "Earlier live Butler interactions do not deliver this specific "
        "normalized stain-denial hint, so it still provides a new "
        "evidence-specific explanation rather than merely repeating the same "
        "statement.",
    ),
    (
        38,
        "v3_green_butler_fg_lea_libd_11",
        ("h_butler_stain",),
        "LOW",
        "The player holds fake_red_stain and the path shows no earlier Butler "
        "conversation; the hint is a direct and reasonable evidence-specific "
        "explanation.",
    ),
    (
        39,
        "v3_green_butler_g_uns_libn_06",
        (),
        "LOW",
        "The player has already entered the Greenhouse and obtained "
        "greenhouse_pollen. The Butler background is generic and the "
        "Greenhouse-direction clue no longer adds enough useful value.",
    ),
    (
        40,
        "v3_green_butler_none_lea_libd_11",
        ("h_butler_knows_rule",),
        "LOW",
        "The player has not yet entered the Greenhouse and holds no evidence; "
        "the glass-breaking/heavy-footsteps clue gives a concrete and timely "
        "next investigation direction.",
    ),
    (
        41,
        "v3_green_gardener_f_dem_libd_10",
        (
            "h_gardener_no_evidence",
            "h_gardener_leaf_colour",
            "h_gardener_knows_reflection",
        ),
        "MEDIUM",
        "The three hints provide a reasonable self-explanation, contextual "
        "reflection reinforcement, and a concrete new dark-pollen/deep-room "
        "clue. Leaf-colour teaching is redundant under the predefined metric "
        "because reflection is already DEMONSTRATED.",
    ),
    (
        42,
        "v3_green_gardener_f_uns_libn_06",
        (
            "h_gardener_no_evidence",
            "h_gardener_leaf_colour",
            "h_gardener_knows_reflection",
        ),
        "LOW",
        "The hints provide self-explanation, new non-redundant reflection "
        "teaching while reflection is UNSEEN, and a concrete investigative "
        "clue. The unsatisfied soft preference does not invalidate the clue.",
    ),
    (
        43,
        "v3_green_gardener_fg_dem_libd_10",
        ("h_gardener_pollen",),
        "LOW",
        "The pollen response directly addresses newly obtained "
        "greenhouse_pollen. Reflection teaching is less relevant because "
        "reflection is already DEMONSTRATED.",
    ),
    (
        44,
        "v3_green_gardener_fg_lea_libl_09",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "The pollen response explains current evidence, while reflection is "
        "only LEARNING, so leaf-colour teaching is timely and non-redundant.",
    ),
    (
        45,
        "v3_green_gardener_g_dem_libd_10",
        ("h_gardener_pollen",),
        "LOW",
        "fake_red_stain does not materially affect the Gardener decision. The "
        "pollen response directly addresses current evidence; reflection "
        "teaching is redundant because reflection is DEMONSTRATED.",
    ),
    (
        46,
        "v3_green_gardener_g_lea_libd_11",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "The pollen response directly addresses current evidence and "
        "reflection is still LEARNING, so the teaching hint remains useful "
        "and non-redundant.",
    ),
    (
        47,
        "v3_green_gardener_none_dem_libd_10",
        (
            "h_gardener_no_evidence",
            "h_gardener_leaf_colour",
            "h_gardener_knows_reflection",
        ),
        "MEDIUM",
        "All three are relevant. The dark-pollen/deep-room clue is strongest "
        "because it provides concrete new investigative direction before "
        "greenhouse_pollen is collected. Reflection teaching can still "
        "provide contextual reinforcement despite being redundant under the "
        "predefined metric.",
    ),
    (
        48,
        "v3_green_gardener_none_lea_libd_11",
        (
            "h_gardener_no_evidence",
            "h_gardener_leaf_colour",
            "h_gardener_knows_reflection",
        ),
        "LOW",
        "All three are relevant. Reflection is still LEARNING, so leaf-colour "
        "teaching is non-redundant. The dark-pollen clue remains useful, but "
        "its priority is lower than in Scenario 47 because its "
        "preferred_when_demonstrated condition is not yet satisfied.",
    ),
)


def annotation_fingerprint(scenarios: list[dict]) -> str:
    """SHA-256 over the ground truth alone, excluding every state field.

    The state fingerprint lets the state set be verified without seeing the
    labels. This is the mirror: it lets the labels be verified without
    re-hashing the states, so a later claim that "the annotations are the ones
    that were frozen" can be checked on its own.

    Canonical form matches the generator's: sorted keys, no whitespace,
    scenarios in the file's existing id order.
    """
    return hashlib.sha256(
        json.dumps(
            [
                {
                    "id": s["id"],
                    "valid_hints": s["valid_hints"],
                    "annotation_rationale": s["annotation_rationale"],
                    "ambiguity_note": s["ambiguity_note"],
                }
                for s in scenarios
            ],
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8")
    ).hexdigest()


def main() -> int:
    raw = SOURCE.read_bytes()
    actual_sha = hashlib.sha256(raw).hexdigest()
    if actual_sha != SOURCE_FILE_SHA256:
        print(f"refusing to annotate: {SOURCE.name} hashes to {actual_sha}")
        print(f"expected the frozen {SOURCE_TAG} value {SOURCE_FILE_SHA256}")
        return 1

    source = json.loads(raw)
    if source["state_fingerprint_sha256"] != SOURCE_STATE_FINGERPRINT:
        print("refusing to annotate: state fingerprint does not match the freeze")
        return 1
    if source["annotations_present"] or source["selector_was_run"]:
        print("refusing to annotate: source is not a clean pre-annotation file")
        return 1

    scenarios = source["scenarios"]
    if len(scenarios) != len(MANIFEST):
        print(f"manifest covers {len(MANIFEST)} scenarios, file has {len(scenarios)}")
        return 1

    annotated: list[dict] = []
    for (ordinal, expected_id, hints, ambiguity, rationale), source_entry in zip(
        MANIFEST, scenarios
    ):
        if source_entry["id"] != expected_id:
            print(
                f"ordinal {ordinal} is '{source_entry['id']}', "
                f"but the manifest annotates '{expected_id}'"
            )
            return 1

        entry = dict(source_entry)
        entry["valid_hints"] = list(hints)
        entry["annotation_rationale"] = rationale
        entry["ambiguity_note"] = ambiguity

        # Belt and braces: prove the copy above changed nothing else.
        for field in STATE_FIELDS:
            if entry[field] != source_entry[field]:
                print(f"{expected_id}: materialization altered '{field}'")
                return 1
        annotated.append(entry)

    ambiguity_counts = {level: 0 for level in ("LOW", "MEDIUM", "HIGH")}
    for entry in annotated:
        ambiguity_counts[entry["ambiguity_note"]] += 1

    payload = {
        "protocol_version": source["protocol_version"],
        "generated_by": "tools/materialize_heldout_v3_annotations.py",
        "deterministic": True,
        "selector_was_run": False,
        "annotations_present": True,
        "annotation_method": "human blind relevance annotation",
        "annotated_from": {
            "tag": SOURCE_TAG,
            "commit": SOURCE_COMMIT,
            "file": str(SOURCE.relative_to(REPO)),
            "file_sha256": SOURCE_FILE_SHA256,
        },
        "scenario_count": len(annotated),
        "annotation_count": len(annotated),
        "state_fingerprint_sha256": source["state_fingerprint_sha256"],
        "annotation_fingerprint_sha256": annotation_fingerprint(annotated),
        "ambiguity_counts": ambiguity_counts,
        "none_scenario_ids": [e["id"] for e in annotated if not e["valid_hints"]],
        "notes": source["notes"][:3]
        + [
            "valid_hints / annotation_rationale / ambiguity_note carry the "
            "human ground truth. A scenario is annotated when its rationale "
            "and ambiguity are both non-empty; an empty valid_hints array "
            "alongside them is the NONE label, not a missing annotation.",
            "No selector has been run against these states. Conditions A, B "
            "and C remain unobserved on heldout-v3.",
        ],
        "scenarios": annotated,
    }

    OUT_JSON.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote {OUT_JSON.relative_to(REPO)}")
    print(f"annotations: {len(annotated)}")
    print(f"state fingerprint:      {payload['state_fingerprint_sha256']}")
    print(f"annotation fingerprint: {payload['annotation_fingerprint_sha256']}")
    print(f"ambiguity: {ambiguity_counts}")
    print(f"NONE: {len(payload['none_scenario_ids'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
