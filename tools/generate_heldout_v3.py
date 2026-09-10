#!/usr/bin/env python3
"""Generate the held-out v3 scenario set from real gameplay progression paths.

heldout-v2 was retired because its generator modelled *state invariants* but not
the game's physical-key progression chain: 44 of its 48 states could not be
reached by any real player. This generator inverts the construction. It never
invents a state vector and then checks it. It walks a legal witness path from a
new game, applies only interactions whose prerequisites the path has already
satisfied, and derives the final state from the path that produced it.

Chronology is therefore a property of construction, not a post-hoc filter.

No selector is imported, called, or consulted anywhere in this file.

Usage:
    python3 tools/generate_heldout_v3.py
"""

from __future__ import annotations

import hashlib
import itertools
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OUT_JSON = REPO / "docs" / "heldout" / "heldout_v3_scenarios.json"
PROTOCOL_VERSION = "heldout-v3"

# ---------------------------------------------------------------------------
# The progression model, transcribed from the live source.
#
# Every entry cites the file and line that proves it. Nothing here is inferred
# from genre convention; where the source did not prove a dependency, no
# dependency is encoded.
# ---------------------------------------------------------------------------

# Each room needs a physical key AND a correct knowledge-lock answer
# (game_world.gd:3651 _try_enter_locked_room). Crucially the keys chain: each
# room hands out the next room's key, so room order is forced.
#
#   Wake -> Chemistry -> Greenhouse -> Circuit -> Dining      (Library is off-chain)
#
#   chemistry_room_key   wake_room.gd:1009
#   greenhouse_room_key  chemistry_room.gd:395   (potion cabinet)
#   circuit_room_key     greenhouse_room.gd:1339 (ALL 7 items inspected)
#   library_room_key     game_world.gd:3762      (hall - off-chain)

STEPS: dict[str, dict] = {
    # ---- opening -----------------------------------------------------------
    "wake": {
        "requires": [],
        "flags": ["dual_lock_rule_taught"],
        "evidence": [],
        "keys": ["chemistry_room_key"],
        "mandatory": True,
        "witness": "Wake Room: read the briefing, take the Chemistry Room Key",
    },
    # ---- hall knowledge exhibits (gate each door question) ------------------
    "hall_chem": {
        "requires": ["wake"],
        "flags": ["hall_knowledge_chemistry_room_collected"],
        "mandatory": True,
        "witness": "Hall: study the chemistry exhibit",
    },
    "door_chem": {
        "requires": ["hall_chem"],
        "needs_keys": ["chemistry_room_key"],
        "flags": ["door_chemistry_unlocked"],
        "mandatory": True,
        "witness": "Hall: answer the Chemistry knowledge lock",
    },
    # ---- Chemistry Room ----------------------------------------------------
    # Entering requires door_chemistry_unlocked. Everything inside is optional
    # except the cabinet, which is the only source of the Greenhouse key.
    "chem_cabinet": {
        "requires": ["door_chem"],
        "flags": ["chemistry_cabinet_secret_found"],
        "keys": ["greenhouse_room_key"],
        "witness": "Chemistry: open the potion cabinet (Greenhouse Key)",
    },
    "chem_lab_note": {
        "requires": ["door_chem"],
        "flags": ["mrs_lin_lab_note_seen"],
        "witness": "Chemistry: read Mrs. Lin's lab note",
    },
    "chem_sorting": {
        "requires": ["door_chem"],
        "flags": ["chemistry_change_sorted"],
        "witness": "Chemistry: complete the sample-tray sorting",
    },
    "chem_red_stain": {
        "requires": ["door_chem"],
        "evidence": ["fake_red_stain"],
        "witness": "Chemistry: examine and record the red stain",
    },
    # Butler chain. Branch 1 issues the test; branch 2 REFUSES to continue
    # until fake_red_stain is held (chemistry_room.gd:1484); branch 3 is the
    # comprehension check. So challenge completion implies the stain.
    "butler_given": {
        "requires": ["door_chem"],
        "flags": ["butler_challenge_given"],
        "witness": "Chemistry: first words with the Butler (test issued)",
    },
    "butler_complete": {
        "requires": ["butler_given", "chem_red_stain"],
        "flags": ["butler_challenge_complete"],
        "witness": "Chemistry: answer the Butler's stain question correctly",
    },
    "butler_interviewed": {
        "requires": ["butler_complete"],
        "flags": ["chemistry_butler_interviewed"],
        "witness": "Chemistry: Butler shares what he saw",
    },
    # ---- Greenhouse --------------------------------------------------------
    "hall_green": {
        "requires": ["chem_cabinet"],
        "flags": ["hall_knowledge_greenhouse_room_collected"],
        "mandatory_for": "greenhouse",
        "witness": "Hall: study the greenhouse exhibit",
    },
    "door_green": {
        "requires": ["hall_green"],
        "needs_keys": ["greenhouse_room_key"],
        "flags": ["door_greenhouse_unlocked"],
        "witness": "Hall: answer the Greenhouse knowledge lock",
    },
    # The workbench shows a parchment and RETURNS before _mark_inspected
    # (greenhouse_room.gd:1292). The item only counts as inspected on a later
    # visit, gated on the note existing - which requires committing it, which
    # grants the evidence. Pollen is therefore mandatory, not optional.
    "green_workbench": {
        "requires": ["door_green"],
        "evidence": ["greenhouse_pollen"],
        "witness": "Greenhouse: workbench parchment (dark pollen evidence)",
    },
    "green_survey": {
        "requires": ["green_workbench"],
        "flags": ["greenhouse_circuit_key_found"],
        "keys": ["circuit_room_key"],
        "witness": "Greenhouse: inspect all 7 features (Circuit Room Key)",
    },
    # ---- Circuit Room ------------------------------------------------------
    "hall_circuit": {
        "requires": ["green_survey"],
        "flags": ["hall_knowledge_circuit_room_collected"],
        "witness": "Hall: study the circuit exhibit",
    },
    "door_circuit": {
        "requires": ["hall_circuit"],
        "needs_keys": ["circuit_room_key"],
        "flags": ["door_circuit_unlocked"],
        "witness": "Hall: answer the Circuit knowledge lock",
    },
    # map_hud.gd:1058 only sets this when current_room_id == "circuit_room".
    "circuit_map_study": {
        "requires": ["door_circuit"],
        "flags": ["circuit_repair_map_studied"],
        "witness": "Circuit: study the repair blueprint on site",
    },
    "circuit_bench_cont": {
        "requires": ["circuit_map_study"],
        "flags": ["circuit_bench_continuity_cleared"],
        "witness": "Circuit: clear the continuity bench",
    },
    "circuit_bench_reg": {
        "requires": ["circuit_map_study"],
        "flags": ["circuit_bench_regulator_cleared"],
        "witness": "Circuit: clear the regulator bench",
    },
    "circuit_bench_diag": {
        "requires": ["circuit_map_study"],
        "flags": ["circuit_bench_diagnostic_cleared"],
        "witness": "Circuit: clear the diagnostic (master switch) bench",
    },
    # circuit_room.gd:766 gates power restoration on the master switch, which is
    # the diagnostic bench (circuit_room.gd:64).
    "circuit_power": {
        "requires": ["circuit_bench_diag"],
        "flags": ["circuit_power_restored"],
        "witness": "Circuit: restore power",
    },
    # circuit_room.gd:609-610 sets evidence and flag on adjacent lines.
    "circuit_note": {
        "requires": ["door_circuit"],
        "evidence": ["deliberate_short_circuit"],
        "flags": ["blackout_deliberate"],
        "witness": "Circuit: workbench journal (deliberate short circuit)",
    },
    # ---- Library (off-chain branch) ----------------------------------------
    "hall_library": {
        "requires": ["wake"],
        "flags": ["hall_knowledge_library_collected"],
        "keys": ["library_room_key"],
        "witness": "Hall: find the Library key and study the library exhibit",
    },
    "door_library": {
        "requires": ["hall_library"],
        "needs_keys": ["library_room_key"],
        "flags": ["door_library_unlocked"],
        "witness": "Hall: answer the Library knowledge lock",
    },
    "lib_learn_spectrum": {
        "requires": ["door_library"],
        "flags": ["library_spectrum_knowledge_learned"],
        "witness": "Library: read the spectrum shelf",
    },
    "lib_learn_reflection": {
        "requires": ["door_library"],
        "flags": ["library_reflection_knowledge_learned"],
        "witness": "Library: read the reflection shelf",
    },
    "lib_learn_additive": {
        "requires": ["door_library"],
        "flags": ["library_additive_knowledge_learned"],
        "witness": "Library: read the additive shelf",
    },
    # library_room.gd:641-643 gates each challenge on its knowledge flag.
    "lib_earn_red": {
        "requires": ["lib_learn_spectrum"],
        "flags": ["library_red_filter_earned"],
        "witness": "Library: solve the Spectrum challenge",
    },
    "lib_earn_green": {
        "requires": ["lib_learn_reflection"],
        "flags": ["library_green_filter_earned"],
        "witness": "Library: solve the Reflection Matrix",
    },
    "lib_earn_blue": {
        "requires": ["lib_learn_additive"],
        "flags": ["library_additive_knowledge_learned", "library_blue_filter_earned"],
        "witness": "Library: solve the Additive Relay",
    },
}

# Where each character is actually talkable, and the door flag that room needs.
NPC_ROOM = {
    "butler": ("chemistry_room", "door_chem"),
    "gardener": ("greenhouse_room", "door_green"),
    "mechanic": ("circuit_room", "door_circuit"),
}

PKM = {
    "indicator_reaction": ("mrs_lin_lab_note_seen", "butler_challenge_complete"),
    "physical_chemical_change": ("mrs_lin_lab_note_seen", "chemistry_change_sorted"),
    "spectrum": ("library_spectrum_knowledge_learned", "library_red_filter_earned"),
    "reflection": ("library_reflection_knowledge_learned", "library_green_filter_earned"),
    "additive": ("library_additive_knowledge_learned", "library_blue_filter_earned"),
    "circuit_continuity": ("circuit_repair_map_studied", "circuit_bench_continuity_cleared"),
    "circuit_regulation": ("circuit_repair_map_studied", "circuit_bench_regulator_cleared"),
    "circuit_fault_isolation": ("circuit_repair_map_studied", "circuit_bench_diagnostic_cleared"),
}

HINTS_BY_NPC = {
    "butler": ["h_butler_no_evidence", "h_butler_stain", "h_butler_knows_rule"],
    "gardener": [
        "h_gardener_no_evidence",
        "h_gardener_pollen",
        "h_gardener_leaf_colour",
        "h_gardener_knows_reflection",
    ],
    "mechanic": [
        "h_mechanic_no_evidence",
        "h_mechanic_short_circuit",
        "h_mechanic_series_basics",
        "h_mechanic_knows_resistance",
    ],
}


def close(chosen: set[str]) -> set[str] | None:
    """Expand a chosen step set to include every prerequisite, transitively.

    Returns None when a step's key requirement cannot be met, which is how an
    illegal path is rejected during construction rather than after it.
    """
    # 1. Transitive prerequisite closure.
    need = set(chosen)
    frontier = set(chosen)
    while frontier:
        nxt: set[str] = set()
        for step in frontier:
            if step not in STEPS:
                return None
            for req in STEPS[step].get("requires", []):
                if req not in need:
                    need.add(req)
                    nxt.add(req)
        frontier = nxt

    # 2. Always include steps flagged mandatory for any run.
    for name, spec in STEPS.items():
        if spec.get("mandatory"):
            need.add(name)
    # Re-close after adding mandatory steps.
    frontier = set(need)
    while frontier:
        nxt = set()
        for step in frontier:
            for req in STEPS[step].get("requires", []):
                if req not in need:
                    need.add(req)
                    nxt.add(req)
        frontier = nxt

    # 3. The set must be topologically orderable (no cycle).
    ordered: list[str] = []
    remaining = set(need)
    while remaining:
        ready = [s for s in sorted(remaining)
                 if set(STEPS[s].get("requires", [])) <= set(ordered)]
        if not ready:
            return None
        ordered.extend(ready)
        remaining -= set(ready)

    # 4. Every key requirement must be granted by a step taken earlier.
    held: set[str] = set()
    for step in ordered:
        if not set(STEPS[step].get("needs_keys", [])) <= held:
            return None
        held |= set(STEPS[step].get("keys", []))
    return need


def state_of(done: set[str]) -> tuple[list[str], list[str], list[str]]:
    flags: set[str] = set()
    evidence: set[str] = set()
    for s in done:
        flags |= set(STEPS[s].get("flags", []))
        evidence |= set(STEPS[s].get("evidence", []))
    witness = [STEPS[s]["witness"] for s in order_steps(done)]
    return sorted(flags), sorted(evidence), witness


def order_steps(done: set[str]) -> list[str]:
    """Topologically order the taken steps so the witness reads chronologically."""
    out: list[str] = []
    remaining = set(done)
    while remaining:
        ready = [s for s in sorted(remaining) if set(STEPS[s].get("requires", [])) <= set(out)]
        if not ready:
            out.extend(sorted(remaining))
            break
        out.extend(ready)
        remaining -= set(ready)
    return out


def pkm_of(flags: list[str]) -> dict[str, str]:
    f = set(flags)
    out = {}
    for c, (learn, dem) in PKM.items():
        out[c] = "DEMONSTRATED" if dem in f else ("LEARNING" if learn in f else "UNSEEN")
    return out


# Optional interactions the player may or may not perform, per stage.
CHEM_OPT = ["chem_lab_note", "chem_sorting", "chem_red_stain",
            "butler_given", "butler_complete", "butler_interviewed"]
GREEN_OPT = ["green_workbench", "green_survey"]
CIRCUIT_OPT = ["circuit_map_study", "circuit_bench_cont", "circuit_bench_reg",
               "circuit_bench_diag", "circuit_power", "circuit_note"]
LIB_OPT = ["lib_learn_spectrum", "lib_learn_reflection", "lib_learn_additive",
           "lib_earn_red", "lib_earn_green", "lib_earn_blue"]


def build_pool() -> list[dict]:
    """Enumerate legal paths and emit one candidate per (path, NPC)."""
    pool: list[dict] = []
    seen: set[tuple] = set()

    # Progression depth: how far along the forced room chain the player is.
    depth_anchor = {
        "chemistry": ["door_chem"],
        "greenhouse": ["door_green"],
        "circuit": ["door_circuit"],
    }

    for depth, anchor in depth_anchor.items():
        for n_chem in range(len(CHEM_OPT) + 1):
            for chem in itertools.combinations(CHEM_OPT, n_chem):
                for n_lib in range(len(LIB_OPT) + 1):
                    for lib in itertools.combinations(LIB_OPT, n_lib):
                        extra_sets = [()]
                        if depth == "greenhouse":
                            extra_sets = []
                            for n_g in range(len(GREEN_OPT) + 1):
                                extra_sets.extend(itertools.combinations(GREEN_OPT, n_g))
                        elif depth == "circuit":
                            extra_sets = []
                            for n_c in range(len(CIRCUIT_OPT) + 1):
                                extra_sets.extend(itertools.combinations(CIRCUIT_OPT, n_c))
                        for circ in extra_sets:
                            chosen = set(anchor) | set(chem) | set(lib) | set(circ)
                            done = close(chosen)
                            if done is None:
                                continue
                            flags, evidence, witness = state_of(done)
                            pkm = pkm_of(flags)
                            for npc, (room, door_step) in NPC_ROOM.items():
                                if door_step not in done:
                                    continue
                                sig = (npc, tuple(flags), tuple(evidence))
                                if sig in seen:
                                    continue
                                seen.add(sig)
                                pool.append({
                                    "npc": npc,
                                    "room": room,
                                    "depth": depth,
                                    "story_flags": flags,
                                    "evidence_items": evidence,
                                    "knowledge_items": [],
                                    "pkm_states": pkm,
                                    "witness_path": ["New game"] + witness
                                    + [f"Return to {room} and talk to the {npc}"],
                                })
    return pool


# ---------------------------------------------------------------------------
# SELECTION CRITERIA - declared before selection, and independent of any
# selector, relevance label, or expected metric value.
#
# For each NPC we take 16 scenarios, choosing to maximise coverage of these
# structural cells in this fixed priority order:
#
#   1. progression depth        (chemistry / greenhouse / circuit)
#   2. own-evidence present     (the NPC's own major evidence held or not)
#   3. count of other major evidence held (0 / 1 / 2)
#   4. library participation    (none / LEARNING / DEMONSTRATED)
#   5. NPC-relevant PKM concept state (UNSEEN / LEARNING / DEMONSTRATED)
#
# Ties are broken by (fewest total flags, then scenario id) so the result is
# deterministic and reproducible. No RNG is used anywhere.
# ---------------------------------------------------------------------------

MAJOR = ["fake_red_stain", "greenhouse_pollen", "deliberate_short_circuit"]
OWN = {"butler": "fake_red_stain", "gardener": "greenhouse_pollen",
       "mechanic": "deliberate_short_circuit"}
FOCUS = {"butler": "indicator_reaction", "gardener": "reflection",
         "mechanic": "circuit_continuity"}


def cell(c: dict) -> tuple:
    ev = set(c["evidence_items"])
    npc = c["npc"]
    lib_states = [c["pkm_states"][k] for k in ("spectrum", "reflection", "additive")]
    lib = ("DEMONSTRATED" if "DEMONSTRATED" in lib_states
           else "LEARNING" if "LEARNING" in lib_states else "NONE")
    own = OWN[npc] in ev
    others = len((ev & set(MAJOR)) - {OWN[npc]})
    n_circuit_dem = sum(
        1 for k in ("circuit_continuity", "circuit_regulation",
                    "circuit_fault_isolation")
        if c["pkm_states"][k] == "DEMONSTRATED"
    )
    return (
        c["depth"],
        own,
        others,
        lib,
        c["pkm_states"][FOCUS[npc]],
        # Evidence shape as a combination, so a character whose own evidence is
        # usually present still gets states where it is absent but other major
        # evidence is held. Per-dimension coverage alone missed that cell.
        (own, others),
        n_circuit_dem,
        # Evidence shape combined with the character's focus concept. Without
        # this the selector-independent structure could still land every
        # no-evidence state on one side of DEMONSTRATED, which would freeze the
        # redundancy metric at a constant. Guaranteeing both sides exist is a
        # validity requirement -- a metric that cannot vary measures nothing --
        # and is decided here from state structure alone, never from any
        # condition's behaviour or score.
        (own, others, c["pkm_states"][FOCUS[npc]] == "DEMONSTRATED"),
    )


def select(pool: list[dict], per_npc: int = 16) -> list[dict]:
    chosen: list[dict] = []
    for npc in ("butler", "gardener", "mechanic"):
        cands = [c for c in pool if c["npc"] == npc]
        depths = sorted({c["depth"] for c in cands})
        # Even split across reachable depths; remainder goes to the later
        # (richer) depths so early stages are not over-represented.
        base, rem = divmod(per_npc, len(depths))
        quota = {d: base for d in depths}
        for d in depths[-rem:] if rem else []:
            quota[d] += 1

        picked: list[dict] = []
        for d in depths:
            sub = [c for c in cands if c["depth"] == d]
            sub.sort(key=lambda c: (len(c["story_flags"]), len(c["evidence_items"]),
                                    tuple(c["story_flags"])))
            buckets: dict[tuple, list[dict]] = {}
            for c in sub:
                buckets.setdefault(cell(c), []).append(c)
            want = quota[d]
            # Greedy max-coverage over structural cells. Picking buckets in
            # sorted order let one value of the first dimension consume every
            # slot, so instead each pick is the bucket that adds the most
            # (dimension, value) pairs not yet represented. Ties break on the
            # sorted cell key, keeping the result deterministic.
            dims = ["depth", "own_evidence", "other_major_count",
                    "library_state", "focus_pkm", "evidence_shape",
                    "circuit_demonstrated_count", "shape_x_focus_demonstrated"]
            covered: set[tuple] = set()
            taken: list[dict] = []
            while len(taken) < want:
                best_key = None
                best_gain = -1
                for key in sorted(buckets, key=lambda k: tuple(str(x) for x in k)):
                    if not buckets[key]:
                        continue
                    pairs = {(dims[i], key[i]) for i in range(len(dims))}
                    gain = len(pairs - covered)
                    if gain > best_gain:
                        best_gain, best_key = gain, key
                if best_key is None:
                    break
                taken.append(buckets[best_key].pop(0))
                covered |= {(dims[i], best_key[i]) for i in range(len(dims))}
                if best_gain == 0:
                    # Every dimension value is represented; reset so the
                    # remaining slots keep spreading rather than clumping.
                    covered = set()
            picked.extend(taken)

        # If a depth could not fill its quota, top up from anywhere unused.
        if len(picked) < per_npc:
            used = {id(x) for x in picked}
            for c in cands:
                if len(picked) >= per_npc:
                    break
                if id(c) not in used:
                    picked.append(c)
        chosen.extend(picked[:per_npc])
    return chosen


def scenario_id(c: dict) -> str:
    ev = "".join(sorted(e[0] for e in c["evidence_items"])) or "none"
    focus = c["pkm_states"][FOCUS[c["npc"]]][:3].lower()
    lib_states = [c["pkm_states"][k] for k in ("spectrum", "reflection", "additive")]
    lib = ("d" if "DEMONSTRATED" in lib_states
           else "l" if "LEARNING" in lib_states else "n")
    return f"v3_{c['depth'][:5]}_{c['npc']}_{ev}_{focus}_lib{lib}_{len(c['story_flags']):02d}"


def main() -> int:
    pool = build_pool()
    print(f"candidate pool: {len(pool)}")
    chosen = select(pool)

    used: dict[str, int] = {}
    out = []
    for c in sorted(chosen, key=lambda c: (c["npc"], len(c["story_flags"]))):
        base = scenario_id(c)
        used[base] = used.get(base, 0) + 1
        sid = base if used[base] == 1 else f"{base}_{used[base]}"
        out.append({
            "id": sid,
            "npc": c["npc"],
            "room": c["room"],
            "stage": c["depth"],
            "evidence_items": c["evidence_items"],
            "knowledge_items": [],
            "story_flags": c["story_flags"],
            "pkm_states": c["pkm_states"],
            "witness_path": c["witness_path"],
            "candidate_hints": HINTS_BY_NPC[c["npc"]],
            "valid_hints": [],
            "annotation_rationale": "",
            "ambiguity_note": "",
        })
    out.sort(key=lambda e: e["id"])

    fingerprint_src = json.dumps(
        [
            {k: e[k] for k in ("id", "npc", "room", "evidence_items",
                               "knowledge_items", "story_flags")}
            for e in out
        ],
        sort_keys=True, separators=(",", ":"),
    )
    payload = {
        "protocol_version": PROTOCOL_VERSION,
        "generated_by": "tools/generate_heldout_v3.py",
        "deterministic": True,
        "selector_was_run": False,
        "annotations_present": False,
        "scenario_count": len(out),
        "state_fingerprint_sha256": hashlib.sha256(
            fingerprint_src.encode("utf-8")
        ).hexdigest(),
        "notes": [
            "Every state is derived from a legal gameplay witness path, not "
            "generated and then repaired.",
            "witness_path lists the state-changing steps that produce the "
            "state, in chronological order.",
            "candidate_hints lists every hint declared for that NPC in the "
            "static catalogue. It is not a prediction and was not produced by "
            "a selector.",
            "valid_hints / annotation_rationale / ambiguity_note are "
            "intentionally empty and must be filled by the human annotator.",
        ],
        "scenarios": out,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote {OUT_JSON.relative_to(REPO)}")
    print(f"scenarios: {len(out)}")
    print(f"fingerprint: {payload['state_fingerprint_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
