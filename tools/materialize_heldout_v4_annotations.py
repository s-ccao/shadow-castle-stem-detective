#!/usr/bin/env python3
"""Materialize the frozen human relevance annotations for held-out v4.

This script writes ground truth. It is therefore the one tool in the held-out
chain that must be trusted least and checked hardest, so it does three things
and nothing else:

1. It refuses to run unless the pre-annotation source still hashes to the
   frozen value, so annotations can never be attached to a drifted state set.
2. It copies every state field through verbatim and asserts equality
   afterwards, so materialization cannot quietly edit a scenario.
3. It fills `valid_hints` and the reserved `annotation` object from the
   manifest below and from nowhere else.

It imports no selector, calls no scoring function and consults no Condition A /
B / C logic. The labels in MANIFEST are human decisions transcribed verbatim;
this file is their record, not their author. Nothing here derives a label from
state -- a label that could be computed would not be ground truth.

Following the v3 precedent, the pre-annotation artifact is **not** modified.
`docs/heldout/heldout_v4_scenarios.json` stays byte-identical at `1bb1535f...`
with `annotations_present: false`, so the state set remains verifiable without
reference to the labels, and `tools/check_heldout_v4_acceptance.py` keeps
passing against it unchanged. The annotated copy is a separate file.

Verification lives in `tools/check_heldout_v4_annotations.py`, deliberately a
separate program: the thing that writes the artifact should not also be the
only thing that vouches for it.

Run:
    python3 tools/materialize_heldout_v4_annotations.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "docs" / "heldout" / "heldout_v4_scenarios.json"
OUT_JSON = REPO / "docs" / "heldout" / "heldout_v4_annotated.json"

## The frozen pre-annotation source, pinned by tag, commit and content hash.
## A mismatch on any of these means the annotations below describe a different
## state set than the one on disk, which is a stop condition, not a warning.
SOURCE_TAG = "heldout-v4-pre-annotation"
SOURCE_COMMIT = "3cf6e83610a7939bec91d93155242aa4505b5379"
SOURCE_FILE_SHA256 = (
    "1bb1535f64168fe4c5e6fe767aabe841761d5bc248a2e17234d29942c3a0a23d"
)
SOURCE_STATE_AGGREGATE = (
    "03d2c7443932da408eda1774b404207224c4e729dc761d6b8d4f44206ec769f2"
)

## Every field the v4 generator produces that describes player state, scenario
## identity or mechanical hint eligibility. All of these must survive
## materialization value-for-value. The only two fields deliberately absent are
## `valid_hints` and `annotation`, which are what annotation fills.
STATE_FIELDS = (
    "id",
    "ordinal",
    "npc",
    "room",
    "stage",
    "stratum",
    "stress_bin",
    "bin_empty",
    "progression_bucket",
    "witness_path",
    "evidence_items",
    "knowledge_items",
    "story_flags",
    "pkm_states",
    "candidate_hints",
    "eligible_hints",
    "eligible_hint_count",
    "structural_features",
    "state_fingerprint_sha256",
)

AMBIGUITY_LEVELS = ("LOW", "MEDIUM", "HIGH")

## Human blind relevance annotation, heldout-v4, all 72 scenarios.
##
## Ordinal is the scenario's 1-based position in the frozen file. The id is
## pinned alongside it so that a reordering of the source cannot silently shift
## a label onto the wrong scenario: the ordinal locates the entry, the id proves
## it is the intended one.
##
## An empty hint tuple is the NONE label -- a real annotation meaning no hint
## provides meaningful help, not a missing one. The rubric (EVALUATION_PROTOCOL
## section 8b) makes NONE a valid answer, and the non-empty rationale and
## ambiguity level below are what distinguish an annotated NONE from an
## unannotated blank.
##
## The hint tuples and ambiguity levels are the human ground truth, transcribed
## exactly as supplied. The rationale strings are normalized English prose for
## the same decisions: they record the state facts the annotator was looking at
## and the decision reached. They are editorial only and never a derivation --
## several scenarios share an identical (npc, evidence, eligible-hint) shape and
## still carry different labels, so no rule is claimed or implied here.
##
## (ordinal, scenario id, valid hints, ambiguity, rationale)
MANIFEST: tuple[tuple[int, str, tuple[str, ...], str, str], ...] = (
    # ---- CORE / Butler -------------------------------------------------
    (
        1,
        "v4_core_butler_01",
        ("h_butler_knows_rule", "h_butler_no_evidence"),
        "LOW",
        "No fake_red_stain is held, so both no-evidence Butler lines are "
        "eligible, and no Butler interaction flag is set. The annotator "
        "accepted both.",
    ),
    (
        2,
        "v4_core_butler_02",
        (),
        "LOW",
        "fake_red_stain is held, but the Butler challenge is complete and "
        "chemistry_butler_interviewed is set; greenhouse_circuit_key_found is "
        "set and the player has advanced to the circuit stage. The annotator "
        "recorded NONE.",
    ),
    (
        3,
        "v4_core_butler_03",
        ("h_butler_stain",),
        "LOW",
        "All three majors are held, yet no Butler interaction flag is set: the "
        "challenge has neither been given nor completed and the Butler has not "
        "been interviewed. The annotator accepted the evidence-specific stain "
        "response.",
    ),
    (
        4,
        "v4_core_butler_04",
        ("h_butler_stain",),
        "LOW",
        "fake_red_stain is held early with no Butler interaction recorded. The "
        "annotator accepted the evidence-specific stain response.",
    ),
    (
        5,
        "v4_core_butler_05",
        (),
        "LOW",
        "No fake_red_stain is held, so both no-evidence Butler lines are "
        "eligible. The player holds greenhouse_pollen mid-case with reflection "
        "DEMONSTRATED. The annotator recorded NONE.",
    ),
    (
        6,
        "v4_core_butler_06",
        ("h_butler_no_evidence",),
        "MEDIUM",
        "No fake_red_stain is held and the player has reached the circuit "
        "stage. The annotator accepted only the Butler's self-explanation with "
        "the knowledge-lock rule; MEDIUM records that this was a close call.",
    ),
    (
        7,
        "v4_core_butler_07",
        ("h_butler_knows_rule",),
        "LOW",
        "No fake_red_stain is held and the Butler challenge has been given but "
        "not completed. The annotator accepted only the room-direction report.",
    ),
    (
        8,
        "v4_core_butler_08",
        ("h_butler_stain",),
        "LOW",
        "fake_red_stain is held and no Butler interaction flag is set. The "
        "annotator accepted the evidence-specific stain response.",
    ),
    (
        9,
        "v4_core_butler_09",
        (),
        "LOW",
        "All three majors are held late in the case, with the Butler challenge "
        "complete and chemistry_butler_interviewed set. The annotator recorded "
        "NONE.",
    ),
    (
        10,
        "v4_core_butler_10",
        ("h_butler_stain",),
        "LOW",
        "fake_red_stain is held. The Butler challenge is complete but "
        "chemistry_butler_interviewed is not set. The annotator accepted the "
        "evidence-specific stain response.",
    ),
    (
        11,
        "v4_core_butler_11",
        ("h_butler_no_evidence",),
        "MEDIUM",
        "No fake_red_stain is held and no Butler interaction flag is set. The "
        "annotator accepted only the self-explanation with the knowledge-lock "
        "rule; MEDIUM records that the room-direction report was a close call "
        "in this state.",
    ),
    (
        12,
        "v4_core_butler_12",
        ("h_butler_no_evidence",),
        "MEDIUM",
        "No fake_red_stain is held and the player has reached the circuit "
        "stage. The annotator accepted only the self-explanation with the "
        "knowledge-lock rule; MEDIUM records the closeness of that call.",
    ),
    (
        13,
        "v4_core_butler_13",
        ("h_butler_knows_rule", "h_butler_no_evidence"),
        "LOW",
        "No evidence is held at all and every concept is UNSEEN; the Butler "
        "challenge has been given but not completed. The annotator accepted "
        "both no-evidence Butler lines.",
    ),
    (
        14,
        "v4_core_butler_14",
        ("h_butler_stain",),
        "LOW",
        "fake_red_stain is held with no Butler interaction recorded. The "
        "annotator accepted the evidence-specific stain response.",
    ),
    (
        15,
        "v4_core_butler_15",
        ("h_butler_stain",),
        "MEDIUM",
        "fake_red_stain is held and the Butler challenge is complete, but "
        "chemistry_butler_interviewed is not set. The annotator accepted the "
        "stain response; MEDIUM records that late progression made this a "
        "close call.",
    ),
    (
        16,
        "v4_core_butler_16",
        (),
        "LOW",
        "fake_red_stain is held late in the case, with the Butler challenge "
        "complete and chemistry_butler_interviewed set. The annotator recorded "
        "NONE.",
    ),
    # ---- CORE / Gardener -----------------------------------------------
    (
        17,
        "v4_core_gardener_01",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "greenhouse_pollen is held early, every concept is UNSEEN and "
        "greenhouse_circuit_key_found is not yet set. The annotator accepted "
        "both the evidence-specific pollen response and the reflection "
        "explanation.",
    ),
    (
        18,
        "v4_core_gardener_02",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "greenhouse_pollen is held and reflection is LEARNING. The annotator "
        "accepted both the evidence-specific pollen response and the "
        "reflection explanation.",
    ),
    (
        19,
        "v4_core_gardener_03",
        (),
        "LOW",
        "All three majors are held late in the case, the greenhouse key has "
        "been found, the player has advanced to the circuit stage and "
        "reflection is DEMONSTRATED. The annotator recorded NONE for both "
        "eligible Gardener lines.",
    ),
    (
        20,
        "v4_core_gardener_04",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "No evidence is held, so all three no-evidence Gardener lines are "
        "eligible, and reflection is UNSEEN. The annotator accepted all three.",
    ),
    (
        21,
        "v4_core_gardener_05",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "greenhouse_pollen is absent, so all three Gardener lines are "
        "eligible, and reflection is UNSEEN. The annotator accepted all three.",
    ),
    (
        22,
        "v4_core_gardener_06",
        ("h_gardener_leaf_colour",),
        "MEDIUM",
        "greenhouse_pollen is held, the greenhouse key has been found, the "
        "player has advanced to the circuit stage and reflection is "
        "DEMONSTRATED. The annotator accepted only the reflection explanation; "
        "MEDIUM records that the evidence-specific pollen response was a close "
        "call.",
    ),
    (
        23,
        "v4_core_gardener_07",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "greenhouse_pollen is held early, reflection is UNSEEN and "
        "greenhouse_circuit_key_found is not yet set. The annotator accepted "
        "both eligible Gardener lines.",
    ),
    (
        24,
        "v4_core_gardener_08",
        (),
        "LOW",
        "All three majors are held, the greenhouse key has been found and the "
        "player has advanced to the circuit stage. The annotator recorded NONE "
        "for both eligible Gardener lines.",
    ),
    (
        25,
        "v4_core_gardener_09",
        ("h_gardener_leaf_colour",),
        "LOW",
        "All three majors are held and reflection is LEARNING. The annotator "
        "accepted only the reflection explanation.",
    ),
    (
        26,
        "v4_core_gardener_10",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "No evidence is held, so all three Gardener lines are eligible, and "
        "reflection is LEARNING. The annotator accepted all three.",
    ),
    (
        27,
        "v4_core_gardener_11",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "greenhouse_pollen is absent and reflection is LEARNING. The annotator "
        "accepted all three eligible Gardener lines.",
    ),
    (
        28,
        "v4_core_gardener_12",
        (),
        "LOW",
        "greenhouse_pollen is held late in the case, with the greenhouse key "
        "found, the player advanced to the circuit stage and reflection "
        "DEMONSTRATED. The annotator recorded NONE.",
    ),
    (
        29,
        "v4_core_gardener_13",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "MEDIUM",
        "No evidence is held, so all three Gardener lines are eligible, and "
        "reflection is already DEMONSTRATED. The annotator accepted all three; "
        "MEDIUM records that the demonstrated concept made this a close call.",
    ),
    (
        30,
        "v4_core_gardener_14",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "MEDIUM",
        "greenhouse_pollen is absent and reflection is DEMONSTRATED. The "
        "annotator accepted all three eligible Gardener lines; MEDIUM records "
        "the closeness of that call.",
    ),
    (
        31,
        "v4_core_gardener_15",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "greenhouse_pollen is held and reflection is LEARNING. The annotator "
        "accepted both the evidence-specific pollen response and the "
        "reflection explanation.",
    ),
    (
        32,
        "v4_core_gardener_16",
        ("h_gardener_pollen", "h_gardener_leaf_colour"),
        "LOW",
        "greenhouse_pollen is held, reflection is LEARNING and "
        "greenhouse_circuit_key_found is not yet set. The annotator accepted "
        "both eligible Gardener lines.",
    ),
    # ---- CORE / Mechanic -----------------------------------------------
    (
        33,
        "v4_core_mechanic_01",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "deliberate_short_circuit is absent, so all three no-evidence Mechanic "
        "lines are eligible; every circuit concept is UNSEEN and no circuit "
        "bench has been cleared. The annotator accepted all three.",
    ),
    (
        34,
        "v4_core_mechanic_02",
        ("h_mechanic_short_circuit",),
        "LOW",
        "deliberate_short_circuit is held, all three circuit concepts are "
        "DEMONSTRATED, every circuit bench is cleared and power is restored. "
        "The annotator accepted only the evidence-specific short-circuit "
        "response.",
    ),
    (
        35,
        "v4_core_mechanic_03",
        ("h_mechanic_short_circuit",),
        "LOW",
        "deliberate_short_circuit is held and circuit_continuity is "
        "DEMONSTRATED. The annotator accepted only the evidence-specific "
        "short-circuit response.",
    ),
    (
        36,
        "v4_core_mechanic_04",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "deliberate_short_circuit is absent, all three circuit concepts are "
        "LEARNING and no circuit bench has been cleared. The annotator "
        "accepted all three eligible Mechanic lines.",
    ),
    (
        37,
        "v4_core_mechanic_05",
        ("h_mechanic_no_evidence", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent; circuit_fault_isolation is "
        "DEMONSTRATED while circuit_continuity is LEARNING. The annotator "
        "accepted the general wiring-failure line and the series-basics "
        "explanation, and excluded the maintenance-route claim.",
    ),
    (
        38,
        "v4_core_mechanic_06",
        ("h_mechanic_no_evidence", "h_mechanic_knows_resistance"),
        "LOW",
        "deliberate_short_circuit is absent and circuit_continuity is already "
        "DEMONSTRATED. The annotator accepted the general wiring-failure line "
        "and the maintenance-route claim, and excluded the series-basics "
        "explanation.",
    ),
    (
        39,
        "v4_core_mechanic_07",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "deliberate_short_circuit is absent and every concept is UNSEEN. The "
        "annotator accepted all three eligible Mechanic lines.",
    ),
    (
        40,
        "v4_core_mechanic_08",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "deliberate_short_circuit is absent and all three circuit concepts are "
        "LEARNING. The annotator accepted all three eligible Mechanic lines.",
    ),
    (
        41,
        "v4_core_mechanic_09",
        ("h_mechanic_knows_resistance",),
        "MEDIUM",
        "deliberate_short_circuit is absent; circuit_continuity is "
        "DEMONSTRATED while circuit_fault_isolation is LEARNING. The annotator "
        "accepted only the maintenance-route claim; MEDIUM records that the "
        "other two eligible lines were close calls.",
    ),
    (
        42,
        "v4_core_mechanic_10",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "deliberate_short_circuit is absent; circuit_continuity is "
        "DEMONSTRATED while fault isolation and regulation are LEARNING. The "
        "annotator accepted all three eligible Mechanic lines.",
    ),
    (
        43,
        "v4_core_mechanic_11",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is held and circuit_continuity is LEARNING. "
        "The annotator accepted both the evidence-specific short-circuit "
        "response and the series-basics explanation.",
    ),
    (
        44,
        "v4_core_mechanic_12",
        ("h_mechanic_short_circuit",),
        "LOW",
        "deliberate_short_circuit is held, circuit_continuity is DEMONSTRATED "
        "and power has been restored. The annotator accepted only the "
        "evidence-specific short-circuit response.",
    ),
    (
        45,
        "v4_core_mechanic_13",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is held early, every circuit concept is "
        "UNSEEN and no circuit bench has been cleared. The annotator accepted "
        "both the evidence-specific short-circuit response and the "
        "series-basics explanation.",
    ),
    (
        46,
        "v4_core_mechanic_14",
        ("h_mechanic_series_basics",),
        "LOW",
        "deliberate_short_circuit is held and circuit_continuity is LEARNING. "
        "The annotator accepted only the series-basics explanation.",
    ),
    (
        47,
        "v4_core_mechanic_15",
        ("h_mechanic_short_circuit", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is held, yet every circuit concept is still "
        "UNSEEN. The annotator accepted both the evidence-specific "
        "short-circuit response and the series-basics explanation.",
    ),
    (
        48,
        "v4_core_mechanic_16",
        ("h_mechanic_no_evidence", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent; circuit_fault_isolation is "
        "DEMONSTRATED while circuit_continuity is LEARNING. The annotator "
        "accepted the general wiring-failure line and the series-basics "
        "explanation, and excluded the maintenance-route claim.",
    ),
    # ---- STRESS / Butler -----------------------------------------------
    (
        49,
        "v4_stress_butler_01",
        (),
        "LOW",
        "B1_very_early Butler bin: no evidence is held, every concept is "
        "UNSEEN, and the only flags set are dual_lock_rule_taught, "
        "hall_knowledge_chemistry_room_collected and door_chemistry_unlocked. "
        "The annotator recorded NONE for both eligible Butler lines.",
    ),
    (
        50,
        "v4_stress_butler_02",
        (),
        "LOW",
        "B2_very_late Butler bin: all 28 story flags are set, every concept is "
        "DEMONSTRATED, and the Butler challenge is complete with "
        "chemistry_butler_interviewed set. The annotator recorded NONE.",
    ),
    (
        51,
        "v4_stress_butler_03",
        (),
        "LOW",
        "fake_red_stain is held, but the Butler challenge is complete and "
        "chemistry_butler_interviewed is set. The annotator recorded NONE. The "
        "bin name B3_max_candidates_pref_active is a slot label backfilled "
        "under generation spec 7.5; the Butler B3 bin is empty, so the name is "
        "not a property of this state.",
    ),
    (
        52,
        "v4_stress_butler_04",
        (),
        "LOW",
        "fake_red_stain is held with the Butler challenge complete and "
        "chemistry_butler_interviewed set. The annotator recorded NONE.",
    ),
    (
        53,
        "v4_stress_butler_05",
        ("h_butler_knows_rule",),
        "LOW",
        "No evidence is held, indicator_reaction is LEARNING and no Butler "
        "interaction flag is set. The annotator accepted only the "
        "room-direction report.",
    ),
    (
        54,
        "v4_stress_butler_06",
        ("h_butler_no_evidence", "h_butler_knows_rule"),
        "LOW",
        "No evidence is held and no Butler interaction flag is set. The "
        "annotator accepted both eligible Butler lines.",
    ),
    (
        55,
        "v4_stress_butler_07",
        (),
        "LOW",
        "fake_red_stain is held after greenhouse_circuit_key_found is set, and "
        "the Butler challenge is complete with chemistry_butler_interviewed "
        "set. The annotator recorded NONE.",
    ),
    (
        56,
        "v4_stress_butler_08",
        (),
        "LOW",
        "fake_red_stain is held, but the Butler challenge is complete and "
        "chemistry_butler_interviewed is set. The annotator recorded NONE.",
    ),
    # ---- STRESS / Gardener ---------------------------------------------
    (
        57,
        "v4_stress_gardener_01",
        ("h_gardener_knows_reflection", "h_gardener_leaf_colour"),
        "LOW",
        "B1_very_early Gardener bin: no evidence is held, every concept is "
        "UNSEEN and greenhouse_circuit_key_found is not set. The annotator "
        "accepted the deep-room pollen observation and the reflection "
        "explanation, and excluded the whereabouts denial.",
    ),
    (
        58,
        "v4_stress_gardener_02",
        ("h_gardener_pollen",),
        "HIGH",
        "B2_very_late Gardener bin: all 28 story flags are set, every concept "
        "is DEMONSTRATED and greenhouse_pollen is held. The annotator accepted "
        "only the evidence-specific pollen response. HIGH because the frozen "
        "state model records no Gardener interaction-history flags, so whether "
        "this exact response has already been delivered is not represented in "
        "the state, and the label depends materially on that unrepresented "
        "fact.",
    ),
    (
        59,
        "v4_stress_gardener_03",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "No evidence is held and reflection is DEMONSTRATED. The annotator "
        "accepted all three eligible Gardener lines.",
    ),
    (
        60,
        "v4_stress_gardener_04",
        ("h_gardener_pollen",),
        "HIGH",
        "greenhouse_pollen is held with greenhouse_circuit_key_found set and "
        "reflection DEMONSTRATED. The annotator accepted only the "
        "evidence-specific pollen response. HIGH because the frozen state "
        "model records no Gardener interaction-history flags, so whether this "
        "exact response has already been delivered is not represented in the "
        "state, and the label depends materially on that unrepresented fact.",
    ),
    (
        61,
        "v4_stress_gardener_05",
        ("h_gardener_leaf_colour",),
        "LOW",
        "greenhouse_pollen is held and reflection is LEARNING. The annotator "
        "accepted only the reflection explanation.",
    ),
    (
        62,
        "v4_stress_gardener_06",
        (
            "h_gardener_no_evidence",
            "h_gardener_knows_reflection",
            "h_gardener_leaf_colour",
        ),
        "LOW",
        "No evidence is held and reflection is LEARNING. The annotator "
        "accepted all three eligible Gardener lines.",
    ),
    (
        63,
        "v4_stress_gardener_07",
        ("h_gardener_leaf_colour",),
        "LOW",
        "greenhouse_pollen is held with greenhouse_circuit_key_found set and "
        "reflection LEARNING. The annotator accepted only the reflection "
        "explanation.",
    ),
    (
        64,
        "v4_stress_gardener_08",
        ("h_gardener_leaf_colour",),
        "LOW",
        "greenhouse_pollen is held with greenhouse_circuit_key_found set, "
        "physical_chemical_change DEMONSTRATED and reflection LEARNING. The "
        "annotator accepted only the reflection explanation.",
    ),
    # ---- STRESS / Mechanic ---------------------------------------------
    (
        65,
        "v4_stress_mechanic_01",
        (
            "h_mechanic_no_evidence",
            "h_mechanic_knows_resistance",
            "h_mechanic_series_basics",
        ),
        "LOW",
        "B1_very_early Mechanic bin: deliberate_short_circuit is absent, every "
        "concept is UNSEEN and no circuit bench has been cleared. The "
        "annotator accepted all three eligible Mechanic lines.",
    ),
    (
        66,
        "v4_stress_mechanic_02",
        (),
        "LOW",
        "B2_very_late Mechanic bin: all 28 story flags are set, every concept "
        "is DEMONSTRATED, every circuit bench is cleared and power is "
        "restored. The annotator recorded NONE.",
    ),
    (
        67,
        "v4_stress_mechanic_03",
        ("h_mechanic_knows_resistance", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent. circuit_fault_isolation is "
        "DEMONSTRATED but the maintenance-route statement still carries "
        "investigative information, and circuit_continuity is LEARNING so the "
        "series-basics explanation still applies. The annotator accepted those "
        "two and excluded the general wiring-failure line.",
    ),
    (
        68,
        "v4_stress_mechanic_04",
        ("h_mechanic_knows_resistance", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent. circuit_fault_isolation is "
        "DEMONSTRATED but the maintenance-route statement still carries "
        "investigative information, and circuit_continuity is LEARNING so the "
        "series-basics explanation still applies. The annotator accepted those "
        "two and excluded the general wiring-failure line.",
    ),
    (
        69,
        "v4_stress_mechanic_05",
        ("h_mechanic_knows_resistance", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent, and circuit_continuity and "
        "circuit_fault_isolation are both LEARNING. The annotator accepted the "
        "maintenance-route claim and the series-basics explanation, and "
        "excluded the general wiring-failure line.",
    ),
    (
        70,
        "v4_stress_mechanic_06",
        ("h_mechanic_knows_resistance", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent, and circuit_continuity and "
        "circuit_fault_isolation are both LEARNING. The annotator accepted the "
        "maintenance-route claim and the series-basics explanation, and "
        "excluded the general wiring-failure line.",
    ),
    (
        71,
        "v4_stress_mechanic_07",
        (),
        "LOW",
        "deliberate_short_circuit is held with every circuit bench cleared, "
        "power restored and all three circuit concepts DEMONSTRATED. The "
        "annotator recorded NONE.",
    ),
    (
        72,
        "v4_stress_mechanic_08",
        ("h_mechanic_knows_resistance", "h_mechanic_series_basics"),
        "LOW",
        "deliberate_short_circuit is absent. circuit_fault_isolation is "
        "DEMONSTRATED but the maintenance-route statement still carries "
        "investigative information, and circuit_continuity is LEARNING so the "
        "series-basics explanation still applies -- the same annotation rule "
        "already applied to Scenarios 67-70. The annotator accepted those two "
        "and excluded the general wiring-failure line.",
    ),
)

## Annotation-level notes the human annotator attached to the batch as a whole.
## They are preserved verbatim in the artifact and in EVALUATION_PROTOCOL so
## that a later reader sees the stated scope of the labels, not just the labels.
ANNOTATION_NOTES: tuple[str, ...] = (
    "Scenario 58 and Scenario 60 are HIGH ambiguity because the progression "
    "model has no Gardener interaction-history flags. Whether h_gardener_pollen "
    "is relevant depends materially on whether the player has already heard "
    "that exact response.",
    "Gardener and Mechanic interaction history generally is not represented by "
    "the frozen state model. Do not invent prior-conversation facts.",
    "Scenario 72's final label follows the same human annotation rule already "
    "applied to Scenarios 67-70: circuit_fault_isolation is DEMONSTRATED but "
    "the maintenance-route statement can still provide investigative "
    "information, while circuit_continuity is LEARNING and the series-basics "
    "explanation remains useful.",
    "The VALID_HINTS labels are the human ground truth. Rationale wording in "
    "this file is normalized editorial prose and does not alter any label.",
)


def canonical(value: object) -> str:
    """The project's canonical JSON form: sorted keys, no whitespace."""
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def state_content_hash(scenarios: list[dict]) -> str:
    """SHA-256 over every state field and nothing else.

    Excludes `valid_hints` and `annotation`, so the same value is produced by
    the pre-annotation file and the annotated copy. That equality is the proof
    that annotation edited no state.
    """
    return sha256_text(
        canonical([{f: s[f] for f in STATE_FIELDS} for s in scenarios])
    )


def annotation_fingerprint(scenarios: list[dict]) -> str:
    """SHA-256 over the ground truth alone, excluding every state field.

    The state hash lets the state set be verified without seeing the labels.
    This is the mirror: it lets the labels be verified without re-hashing the
    states. The hashed shape matches v3's exactly -- id, valid_hints,
    annotation_rationale, ambiguity_note -- so the two protocol versions'
    annotation-only hashes are computed the same way.
    """
    return sha256_text(
        canonical(
            [
                {
                    "id": s["id"],
                    "valid_hints": s["valid_hints"],
                    "annotation_rationale": s["annotation"][
                        "annotation_rationale"
                    ],
                    "ambiguity_note": s["annotation"]["ambiguity_note"],
                }
                for s in scenarios
            ]
        )
    )


def main() -> int:
    raw = SOURCE.read_text()
    actual_sha = sha256_text(raw)
    if actual_sha != SOURCE_FILE_SHA256:
        print("refusing to annotate: pre-annotation source has drifted")
        print(f"  expected {SOURCE_FILE_SHA256}")
        print(f"  actual   {actual_sha}")
        return 1

    source = json.loads(raw)
    if source["annotations_present"] or source["selector_was_run"]:
        print("refusing to annotate: source is not a clean pre-annotation file")
        return 1
    if source["state_aggregate_sha256"] != SOURCE_STATE_AGGREGATE:
        print("refusing to annotate: state aggregate does not match the freeze")
        return 1

    scenarios = source["scenarios"]
    if len(scenarios) != len(MANIFEST):
        print(f"manifest covers {len(MANIFEST)} scenarios, file has {len(scenarios)}")
        return 1

    source_state_hash = state_content_hash(scenarios)

    annotated: list[dict] = []
    for (ordinal, expected_id, hints, ambiguity, rationale), source_entry in zip(
        MANIFEST, scenarios
    ):
        if source_entry["ordinal"] != ordinal:
            print(
                f"manifest ordinal {ordinal} lands on file ordinal "
                f"{source_entry['ordinal']}"
            )
            return 1
        if source_entry["id"] != expected_id:
            print(
                f"ordinal {ordinal} is '{source_entry['id']}', "
                f"but the manifest annotates '{expected_id}'"
            )
            return 1
        if ambiguity not in AMBIGUITY_LEVELS:
            print(f"ordinal {ordinal}: ambiguity '{ambiguity}' is not a level")
            return 1
        if len(set(hints)) != len(hints):
            print(f"ordinal {ordinal}: valid_hints contains a duplicate")
            return 1

        # A label may only name a hint this state actually makes hard-eligible.
        # This is a transcription check, not a judgement: it catches a mistyped
        # id or a label attached to the wrong scenario, both of which would be
        # silent corruption of ground truth.
        eligible = set(source_entry["eligible_hints"])
        for hint in hints:
            if hint not in eligible:
                print(f"ordinal {ordinal}: '{hint}' is not hard-eligible here")
                return 1

        entry = dict(source_entry)
        entry["valid_hints"] = list(hints)
        entry["annotation"] = {
            "ambiguity_note": ambiguity,
            "annotation_rationale": rationale,
        }

        # Belt and braces: prove the copy above changed nothing else.
        for field in STATE_FIELDS:
            if entry[field] != source_entry[field]:
                print(f"{expected_id}: materialization altered '{field}'")
                return 1
        annotated.append(entry)

    if state_content_hash(annotated) != source_state_hash:
        print("materialization changed scenario state content")
        return 1

    ambiguity_counts = {level: 0 for level in AMBIGUITY_LEVELS}
    for entry in annotated:
        ambiguity_counts[entry["annotation"]["ambiguity_note"]] += 1

    none_entries = [e for e in annotated if not e["valid_hints"]]

    payload = {
        "version": "heldout-v4-annotated",
        "protocol_version": "heldout-v4",
        "generated_by": "tools/materialize_heldout_v4_annotations.py",
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
        "spec": source["spec"],
        "spec_sha256": source["spec_sha256"],
        "spec_tag": source["spec_tag"],
        "pkm_serialization": source["pkm_serialization"],
        "pkm_model_source": source["pkm_model_source"],
        "pkm_model_sha256": source["pkm_model_sha256"],
        "strata": source["strata"],
        "scenario_count": len(annotated),
        "annotation_count": len(annotated),
        "state_aggregate_sha256": source["state_aggregate_sha256"],
        "state_content_sha256": source_state_hash,
        "annotation_fingerprint_sha256": annotation_fingerprint(annotated),
        "ambiguity_counts": ambiguity_counts,
        "none_scenario_count": len(none_entries),
        "none_scenario_ordinals": [e["ordinal"] for e in none_entries],
        "none_scenario_ids": [e["id"] for e in none_entries],
        "annotation_notes": list(ANNOTATION_NOTES),
        "notes": list(source["notes"][:1])
        + [
            "valid_hints and annotation carry the human ground truth. A "
            "scenario is annotated when its rationale and ambiguity are both "
            "non-empty; an empty valid_hints array alongside them is the NONE "
            "label, not a missing annotation.",
            "candidate_hints lists every hint declared for the NPC; "
            "eligible_hints lists those whose HARD prerequisites this state "
            "meets. Neither is a prediction and neither came from a selector.",
            "No selector has been run against these states. Conditions A, B "
            "and C remain unobserved on heldout-v4.",
            "The pre-annotation file is unmodified and remains the state of "
            "record; this file adds labels only.",
        ],
        "scenarios": annotated,
    }

    OUT_JSON.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote {OUT_JSON.relative_to(REPO)}")
    print(f"annotations: {len(annotated)}/{len(annotated)}")
    print(f"state content hash:     {payload['state_content_sha256']}")
    print(f"state aggregate:        {payload['state_aggregate_sha256']}")
    print(f"annotation fingerprint: {payload['annotation_fingerprint_sha256']}")
    print(f"ambiguity: {ambiguity_counts}")
    print(f"NONE: {len(none_entries)} -> {payload['none_scenario_ordinals']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
