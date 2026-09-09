#!/usr/bin/env python3
"""Generate the held-out v1 scenario set for the adaptive-guidance experiment.

Deterministic: no RNG. Re-running produces byte-identical output, so the
dataset can be regenerated and checksummed independently.

CRITICAL — this script never runs a selector.

Scenario states are built from progression stages and evidence combinations
derived from the game's own source. Candidate hint lists are built from the
static `npc` field of the hint catalogue, i.e. "which hints belong to this
character", NOT "which hint would a selector pick". No Condition A / B / B-PKM
/ LLM logic is imported, called, or consulted anywhere in this file.

Ground truth is deliberately absent. `valid_hints`, `annotation_rationale` and
`ambiguity_note` are emitted empty for the annotator to fill.

    python3 tools/generate_heldout_v1.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

PROTOCOL_VERSION = "heldout-v1"
REPO = Path(__file__).resolve().parent.parent
OUT_JSON = REPO / "docs" / "heldout" / "heldout_v1_scenarios.json"

# --------------------------------------------------------------------------
# Progression stages.
#
# Every stage satisfies the reachability rules in
# scripts/adaptive_hint_data.gd:REACHABILITY_RULES, plus these additional
# prerequisites read directly from the game and applied here by construction:
#
#   * butler_challenge_complete requires fake_red_stain
#       chemistry_room.gd:1485 gates the test behind holding the stain.
#   * chemistry_change_sorted requires mrs_lin_lab_note_seen
#       chemistry_room.gd:492 opens the tray only after the note is read.
#   * library_<c>_filter_earned requires library_<c>_knowledge_learned
#       library_room.gd:810 locks the terminal until the record is filed.
#   * circuit_bench_*_cleared requires door_circuit_unlocked
#       the benches are inside the circuit room.
#
# The old 72-state sweep never set a single PKM DEMONSTRATED flag: it used the
# library *_knowledge_learned exposure flags but no *_filter_earned, no
# butler_challenge_complete, no chemistry_change_sorted and no
# circuit_bench_*_cleared. Demonstration depth is therefore the axis that makes
# this set genuinely new rather than a reshuffle.
# --------------------------------------------------------------------------

BASE = ["dual_lock_rule_taught"]

STAGES: list[dict] = [
    {
        "id": "chem_intro",
        "summary": "Read Mrs. Lin's lab note; nothing demonstrated yet.",
        "knowledge": [],
        "flags": BASE + ["mrs_lin_lab_note_seen"],
        "requires_evidence": [],
    },
    {
        "id": "chem_sorted",
        "summary": "Cleared the sample tray; classification demonstrated.",
        "knowledge": [],
        "flags": BASE + ["mrs_lin_lab_note_seen", "chemistry_change_sorted"],
        "requires_evidence": [],
    },
    {
        "id": "chem_butler",
        "summary": "Passed the Butler's test; indicator reaction demonstrated.",
        "knowledge": [],
        "flags": BASE + ["mrs_lin_lab_note_seen", "butler_challenge_complete"],
        # chemistry_room.gd:1485 — the test is unreachable without the stain.
        "requires_evidence": ["fake_red_stain"],
    },
    {
        "id": "chem_both",
        "summary": "Both chemistry checks completed.",
        "knowledge": [],
        "flags": BASE
        + [
            "mrs_lin_lab_note_seen",
            "chemistry_change_sorted",
            "butler_challenge_complete",
        ],
        "requires_evidence": ["fake_red_stain"],
    },
    {
        "id": "circuit_studied",
        "summary": "Studied the repair map on site; no bench cleared.",
        "knowledge": [],
        "flags": BASE + ["door_circuit_unlocked", "circuit_repair_map_studied"],
        "requires_evidence": [],
    },
    {
        "id": "circuit_one_bench",
        "summary": "Cleared Junction Bench I only; continuity demonstrated.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_circuit_unlocked",
            "circuit_repair_map_studied",
            "circuit_bench_continuity_cleared",
        ],
        "requires_evidence": [],
    },
    {
        "id": "circuit_regulation",
        "summary": "Cleared Bench II; regulation demonstrated, fault isolation not.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_circuit_unlocked",
            "circuit_repair_map_studied",
            "circuit_bench_continuity_cleared",
            "circuit_bench_regulator_cleared",
        ],
        "requires_evidence": [],
    },
    {
        "id": "circuit_all_benches",
        "summary": "All three benches cleared; power restored.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_circuit_unlocked",
            "circuit_repair_map_studied",
            "circuit_bench_continuity_cleared",
            "circuit_bench_regulator_cleared",
            "circuit_bench_diagnostic_cleared",
            "circuit_power_restored",
        ],
        "requires_evidence": [],
    },
    {
        "id": "library_reflection_filed",
        "summary": "Filed the reflection record; challenge not attempted.",
        "knowledge": [],
        "flags": BASE
        + ["door_library_unlocked", "library_reflection_knowledge_learned"],
        "requires_evidence": [],
    },
    {
        "id": "library_reflection_solved",
        "summary": "Solved the reflection challenge; green filter recovered.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_library_unlocked",
            "library_reflection_knowledge_learned",
            "library_green_filter_earned",
        ],
        "requires_evidence": [],
    },
    {
        "id": "library_two_filed_one_solved",
        "summary": "Spectrum and reflection filed; only spectrum solved.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_library_unlocked",
            "library_spectrum_knowledge_learned",
            "library_reflection_knowledge_learned",
            "library_red_filter_earned",
        ],
        "requires_evidence": [],
    },
    {
        "id": "library_spectrum_filed",
        "summary": "Filed the spectrum record only; challenge not attempted.",
        "knowledge": [],
        "flags": BASE
        + ["door_library_unlocked", "library_spectrum_knowledge_learned"],
        "requires_evidence": [],
    },
    {
        "id": "library_all_filed_none_solved",
        "summary": "All three records filed; no challenge solved yet.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_library_unlocked",
            "library_spectrum_knowledge_learned",
            "library_reflection_knowledge_learned",
            "library_additive_knowledge_learned",
            "library_rgb_puzzle_solved",
        ],
        "requires_evidence": [],
    },
    {
        "id": "library_additive_filed_reflection_solved",
        "summary": "Additive filed but unsolved; reflection filed and solved.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_library_unlocked",
            "library_additive_knowledge_learned",
            "library_reflection_knowledge_learned",
            "library_green_filter_earned",
        ],
        "requires_evidence": [],
    },
    {
        "id": "library_all_solved",
        "summary": "All three library concepts filed and all three solved.",
        "knowledge": [],
        "flags": BASE
        + [
            "door_library_unlocked",
            "library_spectrum_knowledge_learned",
            "library_reflection_knowledge_learned",
            "library_additive_knowledge_learned",
            "library_rgb_puzzle_solved",
            "library_red_filter_earned",
            "library_green_filter_earned",
            "library_blue_filter_earned",
        ],
        "requires_evidence": [],
    },
]

# --------------------------------------------------------------------------
# Evidence combinations.
#
# The old 72-state sweep used only the empty set or exactly one item. Every
# multi-item combination below is new.
#
# deliberate_short_circuit always travels with blackout_deliberate, because
# circuit_room.gd:609-610 sets them on adjacent lines.
# --------------------------------------------------------------------------

EVIDENCE_SETS: list[dict] = [
    {"id": "none", "evidence": [], "extra_flags": []},
    {"id": "stain", "evidence": ["fake_red_stain"], "extra_flags": []},
    {"id": "pollen", "evidence": ["greenhouse_pollen"], "extra_flags": []},
    {
        "id": "short_circuit",
        "evidence": ["deliberate_short_circuit"],
        "extra_flags": ["blackout_deliberate"],
    },
    {
        "id": "stain_pollen",
        "evidence": ["fake_red_stain", "greenhouse_pollen"],
        "extra_flags": [],
    },
    {
        "id": "stain_circuit",
        "evidence": ["fake_red_stain", "deliberate_short_circuit"],
        "extra_flags": ["blackout_deliberate"],
    },
    {
        "id": "pollen_circuit",
        "evidence": ["greenhouse_pollen", "deliberate_short_circuit"],
        "extra_flags": ["blackout_deliberate"],
    },
    {
        "id": "all_three",
        "evidence": [
            "fake_red_stain",
            "greenhouse_pollen",
            "deliberate_short_circuit",
        ],
        "extra_flags": ["blackout_deliberate"],
    },
]

NPCS = ["butler", "gardener", "mechanic"]

# Static hint ownership, transcribed from scripts/adaptive_hint_data.gd. Used
# only to tell the annotator which hints exist for a character. This is the
# `npc` field of each hint, not a selector decision.
HINTS_BY_NPC: dict[str, list[str]] = {
    "butler": ["h_butler_no_evidence", "h_butler_stain", "h_butler_knows_rule"],
    "gardener": [
        "h_gardener_no_evidence",
        "h_gardener_pollen",
        "h_gardener_knows_reflection",
    ],
    "mechanic": [
        "h_mechanic_no_evidence",
        "h_mechanic_short_circuit",
        "h_mechanic_knows_resistance",
    ],
}

# PKM v1 concept map, transcribed from scripts/player_knowledge_model.gd so the
# annotator can see knowledge state without running any code.
PKM_CONCEPTS: dict[str, dict] = {
    "indicator_reaction": {
        "learning_flags": ["mrs_lin_lab_note_seen"],
        "learning_evidence": ["fake_red_stain"],
        "demonstrated_flags": ["butler_challenge_complete"],
    },
    "physical_chemical_change": {
        "learning_flags": ["mrs_lin_lab_note_seen"],
        "learning_evidence": [],
        "demonstrated_flags": ["chemistry_change_sorted"],
    },
    "spectrum": {
        "learning_flags": ["library_spectrum_knowledge_learned"],
        "learning_evidence": [],
        "demonstrated_flags": ["library_red_filter_earned"],
    },
    "reflection": {
        "learning_flags": ["library_reflection_knowledge_learned"],
        "learning_evidence": [],
        "demonstrated_flags": ["library_green_filter_earned"],
    },
    "additive": {
        "learning_flags": ["library_additive_knowledge_learned"],
        "learning_evidence": [],
        "demonstrated_flags": ["library_blue_filter_earned"],
    },
    "circuit_continuity": {
        "learning_flags": ["circuit_repair_map_studied"],
        "learning_evidence": [],
        "demonstrated_flags": ["circuit_bench_continuity_cleared"],
    },
    "circuit_regulation": {
        "learning_flags": ["circuit_repair_map_studied"],
        "learning_evidence": [],
        "demonstrated_flags": ["circuit_bench_regulator_cleared"],
    },
    "circuit_fault_isolation": {
        "learning_flags": ["circuit_repair_map_studied"],
        "learning_evidence": [],
        "demonstrated_flags": ["circuit_bench_diagnostic_cleared"],
    },
}


def pkm_state(concept: str, flags: list[str], evidence: list[str]) -> str:
    """Derive a PKM v1 state. Mirrors player_knowledge_model.state_of().

    Reimplemented here rather than imported because this generator is Python
    and the model is GDScript. The mapping is transcribed above; the GDScript
    remains authoritative and is unchanged.
    """
    spec = PKM_CONCEPTS[concept]
    if any(f in flags for f in spec["demonstrated_flags"]):
        return "DEMONSTRATED"
    if any(f in flags for f in spec["learning_flags"]):
        return "LEARNING"
    if any(e in evidence for e in spec["learning_evidence"]):
        return "LEARNING"
    return "UNSEEN"


# --------------------------------------------------------------------------
# Pairing.
#
# Each NPC receives 16 (stage, evidence) pairs. The pairing walks the evidence
# list at a per-NPC offset and stride so the three characters do not all
# receive the same evidence for the same stage, while remaining fully
# deterministic.
# --------------------------------------------------------------------------

PAIRINGS: dict[str, list[tuple[int, int]]] = {
    # (stage_index, evidence_index)
    #
    # Butler: eight pairs deliberately withhold fake_red_stain so the annotator
    # sees states where the authored line's declared precondition holds, and
    # eight supply it so they see the contrasting case.
    "butler": [
        (0, 0), (0, 4), (1, 2), (1, 5),
        (2, 1), (3, 5), (4, 0), (5, 2),
        (6, 6), (7, 3), (8, 0), (9, 2),
        (11, 3), (12, 0), (14, 7), (13, 6),
    ],
    # Gardener: eight pairs withhold greenhouse_pollen while a reflection
    # record is filed or solved.
    #
    # (8, 4) replaces an earlier (8, 0): that combination reproduced the
    # existing hand-authored scenario s07_gardener_knows_reflection exactly,
    # and the deduplication check rejected it.
    "gardener": [
        (0, 1), (0, 5), (1, 0), (1, 3),
        (8, 4), (8, 1), (9, 0), (9, 5),
        (10, 3), (13, 0), (13, 1), (12, 3),
        (14, 2), (11, 6), (7, 2), (5, 6),
    ],
    # Mechanic: the authored line's precondition is unsatisfiable under the
    # frozen rules (see the design note in docs/EVALUATION_PROTOCOL.md), so no
    # attempt is made to manufacture it. Coverage instead spans circuit
    # demonstration depth and evidence combinations.
    "mechanic": [
        (0, 3), (0, 7), (1, 2), (1, 6),
        (4, 0), (5, 0), (6, 0), (7, 0),
        (4, 3), (5, 7), (6, 4), (7, 2),
        (12, 3), (14, 4), (10, 0), (9, 6),
    ],
}


def build() -> list[dict]:
    scenarios: list[dict] = []
    for npc in NPCS:
        for stage_index, evidence_index in PAIRINGS[npc]:
            stage = STAGES[stage_index]
            evidence_set = EVIDENCE_SETS[evidence_index]

            evidence = sorted(set(evidence_set["evidence"]))
            flags = list(stage["flags"]) + list(evidence_set["extra_flags"])

            # Source-derived prerequisite: a stage may require evidence the
            # chosen evidence set does not supply. Add it rather than emit an
            # unreachable state.
            for required in stage["requires_evidence"]:
                if required not in evidence:
                    evidence.append(required)
            evidence = sorted(set(evidence))

            # Keep the circuit pair consistent in both directions.
            if "deliberate_short_circuit" in evidence:
                if "blackout_deliberate" not in flags:
                    flags.append("blackout_deliberate")

            flags = sorted(set(flags))

            concepts = {
                name: pkm_state(name, flags, evidence) for name in PKM_CONCEPTS
            }

            scenarios.append(
                {
                    "id": "h_%s_%s_%s" % (stage["id"], evidence_set["id"], npc),
                    "npc": npc,
                    "room": "castle_hall",
                    "stage": stage["id"],
                    "stage_summary": stage["summary"],
                    "evidence_set": evidence_set["id"],
                    "knowledge_items": sorted(stage["knowledge"]),
                    "story_flags": flags,
                    "evidence_items": evidence,
                    "pkm_states": concepts,
                    "candidate_hints": HINTS_BY_NPC[npc],
                    # Left empty on purpose. The annotator fills these.
                    "valid_hints": [],
                    "annotation_rationale": "",
                    "ambiguity_note": "",
                }
            )
    return scenarios


def fingerprint(scenarios: list[dict]) -> str:
    """Checksum of state only, excluding annotation fields.

    Lets the state set be frozen and verified independently of the annotations
    that will be added later.
    """
    state_only = [
        {
            "id": s["id"],
            "npc": s["npc"],
            "knowledge_items": s["knowledge_items"],
            "story_flags": s["story_flags"],
            "evidence_items": s["evidence_items"],
        }
        for s in sorted(scenarios, key=lambda s: s["id"])
    ]
    blob = json.dumps(state_only, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def main() -> int:
    scenarios = build()
    scenarios.sort(key=lambda s: s["id"])

    payload = {
        "protocol_version": PROTOCOL_VERSION,
        "generated_by": "tools/generate_heldout_v1.py",
        "deterministic": True,
        "selector_was_run": False,
        "annotations_present": False,
        "scenario_count": len(scenarios),
        "state_fingerprint_sha256": fingerprint(scenarios),
        "notes": [
            "State only. No ground truth, no selector output, no expected results.",
            "candidate_hints lists every hint declared for that NPC in the static "
            "catalogue. It is not a prediction and was not produced by a selector.",
            "valid_hints / annotation_rationale / ambiguity_note are intentionally "
            "empty and must be filled by the human annotator.",
        ],
        "scenarios": scenarios,
    }

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"wrote {OUT_JSON.relative_to(REPO)}")
    print(f"scenarios: {len(scenarios)}")
    print(f"fingerprint: {payload['state_fingerprint_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
