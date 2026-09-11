#!/usr/bin/env python3
"""Generate the held-out v4 benchmark from the frozen generation specification.

This program implements `docs/HELDOUT_V4_GENERATION_SPEC.md` and nothing else.
Every threshold, quota, predicate, bin and tie-break below is a transcription of
a section of that document, cited inline. Where the specification also published
a *measured* number -- pool sizes, bucket edges, bin populations, reachable value
counts -- this program recomputes it and aborts on disagreement rather than
trusting it. A frozen number that is never recomputed is decoration.

WHAT THIS PROGRAM MUST NOT DO
-----------------------------
It must not import or call `select_condition_a`, `select_adaptive`, any part of
Condition C, any relevance scorer, or any redundancy scorer based on a selector
decision. It must not read human annotations, v3 A/B raw rows, or v3 A/B metrics.
It must never ask which hint any condition would select.

(The names in the paragraph above are prose. `check_heldout_v4_spec.py` strips
docstrings and whole-line comments before scanning, so recording the commitment
does not violate it -- and that scan runs here, against this file, before the
benchmark is written.)

The shared hint catalogue is read for exactly four things, per spec §14: hard
prerequisite metadata, hard-eligible candidate count, hint-to-NPC identity, and
`teaches` / `preferred_when_demonstrated` to build the structural concept bins.
Hard *eligibility* is a property of the state and the catalogue. Which eligible
hint is *best* is a selector's judgement, and is never computed here.

    python3 tools/generate_heldout_v4.py            # generate
    python3 tools/generate_heldout_v4.py --dry-run  # verify, write nothing
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import generate_heldout_v3 as walker          # progression model + witness paths
import pkm_reference                          # canonical PKM serialization
from check_heldout_v4_spec import (           # the frozen integrity scan
    FORBIDDEN_GENERATOR_SYMBOLS,
    python_code_only,
)

SPEC = REPO / "docs" / "HELDOUT_V4_GENERATION_SPEC.md"
OUT_JSON = REPO / "docs" / "heldout" / "heldout_v4_scenarios.json"
OUT_AUDIT = REPO / "docs" / "heldout" / "heldout_v4_generation_audit.json"

NPCS = ("butler", "gardener", "mechanic")
BUCKETS = ("early", "middle", "late")
MAJOR = ("fake_red_stain", "greenhouse_pollen", "deliberate_short_circuit")
OWN = {"butler": "fake_red_stain",
       "gardener": "greenhouse_pollen",
       "mechanic": "deliberate_short_circuit"}

# spec §5.6 -- terminal progression marker of each NPC's own room thread.
DESTINATION_FLAGS = {"butler": "butler_challenge_complete",
                     "gardener": "greenhouse_circuit_key_found",
                     "mechanic": "circuit_power_restored"}

# spec §5.7 -- real NPC-interaction flags. Only the Butler has any.
INTERACTION_FLAGS = {
    "butler": ("butler_challenge_given", "butler_challenge_complete",
               "chemistry_butler_interviewed"),
    "gardener": (),
    "mechanic": (),
}

# spec §5.5 / §3.3 -- the steps that happen inside each NPC's own room.
ROOM_STEPS = {
    "butler": set(walker.CHEM_OPT) | {"chem_cabinet"},
    "gardener": set(walker.GREEN_OPT),
    "mechanic": set(walker.CIRCUIT_OPT),
}

STRESS_BINS = ("B1_very_early", "B2_very_late", "B3_max_candidates_pref_active",
               "B4_associated_demonstrated", "B5_associated_learning",
               "B6_no_own_evidence_plain", "B7_evidence_after_progression",
               "B8_destination_reached")

FEATURES = ("stage", "progression_bucket", "own_evidence", "other_major_count",
            "eligible_count", "associated_concept_states", "pkm_profile",
            "room_investigation_complete", "destination_reached",
            "prior_npc_interaction", "evidence_shape", "shape_x_associated")

# spec §8.4 -- the four dimensions whose full coverage is a hard gate.
REQUIRED_COVERAGE = ("progression_bucket", "own_evidence", "eligible_count",
                     "associated_concept_states")

# ---------------------------------------------------------------------------
# Frozen published measurements. Recomputed below; a mismatch aborts.

FROZEN_POOL = {"butler": 19440, "gardener": 18792, "mechanic": 16848}
FROZEN_POOL_TOTAL = 55080
FROZEN_AFTER_EXCLUSION = {"butler": 19424, "gardener": 18776, "mechanic": 16832}
FROZEN_EXCLUSION_COUNT = 96
FROZEN_EXCLUSION_DIGEST = \
    "27ae5ddb750dec4c04ee3338f239ef44cd242b5f919747356c1297706eb32ecf"
FROZEN_POOL_INTERSECTION = 48

# spec §5.4
FROZEN_BUCKETS = {
    "butler": {"lo": 5, "hi": 32, "early_max": 13, "middle_max": 22,
               "pop": (567, 8937, 9936)},
    "gardener": {"lo": 8, "hi": 32, "early_max": 15, "middle_max": 23,
                 "pop": (630, 10815, 7347)},
    "mechanic": {"lo": 12, "hi": 32, "early_max": 18, "middle_max": 25,
                 "pop": (760, 13191, 2897)},
}

# spec §5.2
FROZEN_ASSOCIATED = {"butler": ["indicator_reaction"],
                     "gardener": ["reflection"],
                     "mechanic": ["circuit_continuity", "circuit_fault_isolation"]}

# spec §5.8 -- (own evidence absent, own evidence present)
FROZEN_ELIGIBLE = {"butler": (2, 1), "gardener": (3, 2), "mechanic": (3, 2)}

# spec §5.9 -- reachable value counts over the post-exclusion pool.
FROZEN_REACHABLE = {
    "stage": (3, 2, 1), "progression_bucket": (3, 3, 3), "own_evidence": (2, 2, 2),
    "other_major_count": (3, 3, 2), "eligible_count": (2, 2, 2),
    "associated_concept_states": (3, 3, 5), "pkm_profile": (45, 45, 45),
    "room_investigation_complete": (2, 2, 2), "destination_reached": (2, 2, 2),
    "prior_npc_interaction": (2, 1, 1), "evidence_shape": (6, 5, 4),
    "shape_x_associated": (12, 15, 20),
}

# spec §7.4 -- bin populations over the FULL pool, before exclusion.
FROZEN_BIN_POP = {
    "B1_very_early": (1, 1, 1),
    "B2_very_late": (1, 1, 1),
    "B3_max_candidates_pref_active": (0, 216, 5184),
    "B4_associated_demonstrated": (6480, 6264, 12960),
    "B5_associated_learning": (9720, 6264, 2592),
    "B6_no_own_evidence_plain": (6480, 432, 3240),
    "B7_evidence_after_progression": (783, 17496, 648),
    "B8_destination_reached": (6480, 17496, 5184),
}

# spec §8.1 -- post-exclusion, pre-STRESS bucket populations and the extra slot.
FROZEN_QUOTA_POP = {"butler": (560, 8929, 9935), "gardener": (622, 10807, 7347),
                    "mechanic": (747, 13188, 2897)}


class GenerationFailure(RuntimeError):
    """Raised when the specification's own assertions do not hold.

    Every raise site is a case where the specification published a claim that
    turned out to be false. Generation stops; nothing is written; nothing is
    repaired.
    """


def fail(message: str) -> None:
    raise GenerationFailure(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------------------
# Catalogue (spec §5.2, §14)


def parse_catalogue() -> dict:
    """Hard-prerequisite and concept metadata, parsed from the GDScript.

    Parsed, not transcribed: a second copy of this table in Python is a second
    thing to keep in sync, and the repository has already been bitten once by
    exactly that (see tools/pkm_reference.py).
    """
    source = (REPO / "scripts" / "adaptive_hint_data.gd").read_text()
    entry = re.compile(r'^\t"([a-z_0-9]+)":\s*\{(.*?)^\t\},', re.S | re.M)

    def slist(body: str, key: str) -> list[str]:
        m = re.search(rf'"{key}":\s*\[(.*?)\]', body, re.S)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []

    hints: dict[str, dict] = {}
    for const in ("LEGACY_GROUNDED_HINTS", "AUTHORED_HINTS"):
        m = re.search(rf"const {const}[^=]*=\s*\{{(.*?)^\}}", source, re.S | re.M)
        if m is None:
            fail(f"catalogue block not found: {const}")
        for hid, body in entry.findall(m.group(1)):
            npc = re.search(r'"npc":\s*"([^"]+)"', body)
            hints[hid] = {
                "npc": npc.group(1) if npc else "",
                "requires_evidence": slist(body, "requires_evidence"),
                "requires_evidence_absent": slist(body, "requires_evidence_absent"),
                "requires_story_flags": slist(body, "requires_story_flags"),
                "requires_concept": slist(body, "requires_concept"),
                "teaches": slist(body, "teaches"),
                "preferred_when_demonstrated": slist(body, "preferred_when_demonstrated"),
            }
    return hints


def derived_concept_sets(hints: dict, concepts: dict) -> tuple[dict, dict]:
    """`associated_concepts(npc)` and `preferred_when_demonstrated(npc)`, spec §5.2."""
    associated: dict[str, list[str]] = {}
    preferred: dict[str, list[str]] = {}
    for npc in NPCS:
        owned = [h for h in hints.values() if h["npc"] == npc]
        associated[npc] = sorted({
            c for h in owned
            for c in h["teaches"] + h["preferred_when_demonstrated"]
            if c in concepts})
        preferred[npc] = sorted({
            c for h in owned for c in h["preferred_when_demonstrated"]
            if c in concepts})
    if associated != FROZEN_ASSOCIATED:
        fail(f"spec §5.2 associated concepts changed: {associated}")
    return associated, preferred


def hard_eligible(hints: dict, npc: str, evidence: set, flags: set,
                  pkm: dict) -> list[str]:
    """Catalogue hints owned by `npc` whose HARD prerequisites the state meets.

    This is eligibility, not preference: it answers "could this hint legally be
    said here", never "which one should be said". Spec §14 permits the former
    and forbids the latter.
    """
    out = []
    for hid in sorted(hints):
        h = hints[hid]
        if h["npc"] != npc:
            continue
        if not set(h["requires_evidence"]) <= evidence:
            continue
        if set(h["requires_evidence_absent"]) & evidence:
            continue
        if not set(h["requires_story_flags"]) <= flags:
            continue
        if any(pkm.get(c) != "DEMONSTRATED" for c in h["requires_concept"]):
            continue
        out.append(hid)
    return out


# ---------------------------------------------------------------------------
# Candidate pool (spec §3, §4)


def fingerprint(npc: str, room: str, evidence, knowledge, flags) -> str:
    """Spec §4.1. Carries no identifier and no label, by design."""
    return sha256_bytes(json.dumps({
        "npc": npc,
        "room": room,
        "evidence_items": sorted(evidence),
        "knowledge_items": sorted(knowledge),
        "story_flags": sorted(flags),
    }, sort_keys=True, separators=(",", ":")).encode())


def load_exclusion() -> tuple[set, dict]:
    """Spec §4.2/§4.3. Recomputed from disk; the published digest must match."""
    sources = ["docs/heldout/heldout_v2_scenarios.json",
               "docs/heldout/heldout_v3_scenarios.json"]
    per_source, excl = {}, set()
    for rel in sources:
        got = set()
        for s in json.loads((REPO / rel).read_text())["scenarios"]:
            got.add(fingerprint(s["npc"], s["room"], s["evidence_items"],
                                s.get("knowledge_items", []), s["story_flags"]))
        per_source[rel] = len(got)
        excl |= got
    digest = sha256_bytes("\n".join(sorted(excl)).encode())
    if len(excl) != FROZEN_EXCLUSION_COUNT:
        fail(f"exclusion set is {len(excl)} fingerprints, spec §4.2 says "
             f"{FROZEN_EXCLUSION_COUNT}")
    if digest != FROZEN_EXCLUSION_DIGEST:
        fail(f"exclusion digest {digest} != spec §4.2 {FROZEN_EXCLUSION_DIGEST}")
    return excl, {"sources": per_source, "count": len(excl), "digest": digest}


def assert_destination_flags() -> None:
    """Spec §5.6: a renamed flag must fail generation, not go quietly constant."""
    for npc, flag in DESTINATION_FLAGS.items():
        owners = [k for k, s in walker.STEPS.items() if flag in s.get("flags", [])]
        if not owners:
            fail(f"destination flag {flag!r} ({npc}) is set by no step")
        outside = [o for o in owners if o not in ROOM_STEPS[npc]]
        if outside:
            fail(f"destination flag {flag!r} ({npc}) is set outside that room "
                 f"by {outside}")


def room_requirements() -> dict:
    """Spec §5.5, derived from STEPS rather than restated."""
    req = {}
    for npc, steps in ROOM_STEPS.items():
        flags, evidence = set(), set()
        for s in steps:
            flags |= set(walker.STEPS[s].get("flags", []))
            evidence |= set(walker.STEPS[s].get("evidence", []))
        req[npc] = (flags, evidence)
    return req


def build_candidates(hints: dict, concepts: dict, associated: dict) -> list[dict]:
    """The full legal pool with canonical PKM and every structural feature."""
    pool = walker.build_pool()
    if len(pool) != FROZEN_POOL_TOTAL:
        fail(f"pool is {len(pool)}, spec §3.4 says {FROZEN_POOL_TOTAL}")

    room_req = room_requirements()
    lengths = defaultdict(list)
    for c in pool:
        lengths[c["npc"]].append(len(c["witness_path"]))

    # spec §5.4 -- lo/hi over the FULL pool, so exclusion cannot move an edge.
    edges = {}
    for npc in NPCS:
        lo, hi = min(lengths[npc]), max(lengths[npc])
        frozen = FROZEN_BUCKETS[npc]
        if (lo, hi) != (frozen["lo"], frozen["hi"]):
            fail(f"{npc}: path length range {lo}..{hi}, spec §5.4 says "
                 f"{frozen['lo']}..{frozen['hi']}")
        edges[npc] = (lo, hi - lo)

    def bucket_of(npc: str, length: int) -> str:
        lo, span = edges[npc]
        x = 3 * (length - lo)
        return "early" if x < span else ("middle" if x < 2 * span else "late")

    out = []
    for c in pool:
        npc = c["npc"]
        flags, evidence = set(c["story_flags"]), set(c["evidence_items"])
        # spec §13 -- canonical serialization, never the v3 flags-only table.
        pkm = pkm_reference.serialize([], c["story_flags"], c["evidence_items"])
        eligible = hard_eligible(hints, npc, evidence, flags, pkm)
        own = OWN[npc] in evidence
        others = len((evidence & set(MAJOR)) - {OWN[npc]})
        assoc = tuple(pkm[k] for k in associated[npc])
        need_flags, need_evidence = room_req[npc]
        counts = Counter(pkm.values())
        features = {
            "stage": c["depth"],
            "progression_bucket": bucket_of(npc, len(c["witness_path"])),
            "own_evidence": own,
            "other_major_count": others,
            "eligible_count": len(eligible),
            "associated_concept_states": assoc,
            "pkm_profile": (counts["UNSEEN"], counts["LEARNING"],
                            counts["DEMONSTRATED"]),
            "room_investigation_complete": (need_flags <= flags
                                            and need_evidence <= evidence),
            "destination_reached": DESTINATION_FLAGS[npc] in flags,
            "prior_npc_interaction": bool(set(INTERACTION_FLAGS[npc]) & flags),
            "evidence_shape": (own, others),
            "shape_x_associated": (own, others, assoc),
        }
        out.append({
            **c,
            "pkm_states": pkm,
            "eligible_hints": eligible,
            "features": features,
            "path_length": len(c["witness_path"]),
            "fingerprint": fingerprint(npc, c["room"], c["evidence_items"],
                                       c["knowledge_items"], c["story_flags"]),
        })

    if len({c["fingerprint"] for c in out}) != len(out):
        fail("pool fingerprints are not distinct; spec §9 step 4 is not a total order")
    per_npc = Counter(c["npc"] for c in out)
    for npc in NPCS:
        if per_npc[npc] != FROZEN_POOL[npc]:
            fail(f"pool[{npc}] is {per_npc[npc]}, spec §3.4 says {FROZEN_POOL[npc]}")
    return out


def verify_published_tables(pool: list[dict], surviving: list[dict],
                            preferred: dict) -> dict:
    """Recompute every measured table the specification published."""
    report: dict = {}

    # §5.4 bucket edges and populations.
    for npc in NPCS:
        cands = [c for c in pool if c["npc"] == npc]
        pop = Counter(c["features"]["progression_bucket"] for c in cands)
        got = (pop["early"], pop["middle"], pop["late"])
        if got != FROZEN_BUCKETS[npc]["pop"]:
            fail(f"{npc}: bucket populations {got}, spec §5.4 says "
                 f"{FROZEN_BUCKETS[npc]['pop']}")
        lo, hi = FROZEN_BUCKETS[npc]["lo"], FROZEN_BUCKETS[npc]["hi"]
        span = hi - lo
        edge_e = max(L for L in range(lo, hi + 1) if 3 * (L - lo) < span)
        edge_m = max(L for L in range(lo, hi + 1) if 3 * (L - lo) < 2 * span)
        if (edge_e, edge_m) != (FROZEN_BUCKETS[npc]["early_max"],
                                FROZEN_BUCKETS[npc]["middle_max"]):
            fail(f"{npc}: recomputed bucket edges ({edge_e}, {edge_m}) disagree "
                 f"with spec §5.4")
    report["bucket_populations_match_spec_5_4"] = True

    # §5.8 eligible-count collinearity.
    for i, npc in enumerate(NPCS):
        cands = [c for c in pool if c["npc"] == npc]
        by_own = defaultdict(set)
        for c in cands:
            by_own[c["features"]["own_evidence"]].add(c["features"]["eligible_count"])
        if len(by_own[False]) != 1 or len(by_own[True]) != 1:
            fail(f"{npc}: eligible_count is no longer a function of own_evidence; "
                 f"spec §5.8 is false")
        got = (next(iter(by_own[False])), next(iter(by_own[True])))
        if got != FROZEN_ELIGIBLE[npc]:
            fail(f"{npc}: eligible counts {got}, spec §5.8 says {FROZEN_ELIGIBLE[npc]}")
    report["eligible_collinearity_matches_spec_5_8"] = True

    # §5.9 reachable value counts over the POST-EXCLUSION pool.
    reachable: dict[str, dict[str, int]] = {}
    for i, npc in enumerate(NPCS):
        cands = [c for c in surviving if c["npc"] == npc]
        reachable[npc] = {}
        for f in FEATURES:
            n = len({c["features"][f] for c in cands})
            reachable[npc][f] = n
            if n != FROZEN_REACHABLE[f][i]:
                fail(f"{npc}: {f} has {n} reachable values, spec §5.9 says "
                     f"{FROZEN_REACHABLE[f][i]}")
    report["reachable_values"] = reachable
    return report


# ---------------------------------------------------------------------------
# Tie-break (spec §9)


def tie_break(c: dict) -> tuple:
    """Spec §9. Step 4 is total because all pool fingerprints are distinct."""
    return (c["path_length"], len(c["story_flags"]), len(c["evidence_items"]),
            c["fingerprint"])


# ---------------------------------------------------------------------------
# STRESS (spec §7)


def bin_predicates(c: dict, npc_min_len: int, npc_max_len: int,
                   npc_max_eligible: int, preferred: list[str]) -> dict:
    """The eight bin predicates of spec §7.1, evaluated for one candidate."""
    f = c["features"]
    pkm = c["pkm_states"]
    assoc = f["associated_concept_states"]
    pref_demonstrated = any(pkm[k] == "DEMONSTRATED" for k in preferred)
    return {
        "B1_very_early": c["path_length"] == npc_min_len,
        "B2_very_late": c["path_length"] == npc_max_len,
        "B3_max_candidates_pref_active": (f["eligible_count"] == npc_max_eligible
                                          and pref_demonstrated),
        "B4_associated_demonstrated": "DEMONSTRATED" in assoc,
        "B5_associated_learning": ("LEARNING" in assoc
                                   and "DEMONSTRATED" not in assoc),
        "B6_no_own_evidence_plain": (not f["own_evidence"]) and not pref_demonstrated,
        "B7_evidence_after_progression": (f["own_evidence"]
                                          and f["room_investigation_complete"]),
        "B8_destination_reached": f["destination_reached"],
    }


def select_stress(pool: list[dict], surviving: list[dict], preferred: dict) -> tuple:
    """Spec §7. Eight bins per NPC, filled B1..B8, ranked by boundary load."""
    chosen: dict[str, list[dict]] = {}
    trace: dict[str, list[dict]] = {}
    empties: dict[str, list[str]] = {}
    populations: dict[str, dict[str, int]] = {}

    for i, npc in enumerate(NPCS):
        full = [c for c in pool if c["npc"] == npc]
        full_min = min(c["path_length"] for c in full)
        full_max = max(c["path_length"] for c in full)
        max_elig = max(c["features"]["eligible_count"] for c in full)

        # §7.3 -- boundary load is computed against the NPC's FULL pool, so it is
        # a property of the state rather than of the order bins were filled.
        for c in full:
            preds = bin_predicates(c, full_min, full_max, max_elig, preferred[npc])
            c["_bins_full"] = preds
            c["_load"] = sum(1 for v in preds.values() if v)

        pop = {b: sum(1 for c in full if c["_bins_full"][b]) for b in STRESS_BINS}
        populations[npc] = pop
        for b in STRESS_BINS:
            if pop[b] != FROZEN_BIN_POP[b][i]:
                fail(f"{npc} {b}: population {pop[b]}, spec §7.4 says "
                     f"{FROZEN_BIN_POP[b][i]}")

        remaining = [c for c in surviving if c["npc"] == npc]
        picks: list[dict] = []
        steps: list[dict] = []
        empty_bins: list[str] = []

        for b in STRESS_BINS:
            # §7.1 -- B1/B2 membership is relative to the REMAINING candidates,
            # so no exclusion or earlier pick can empty them.
            rmin = min(c["path_length"] for c in remaining)
            rmax = max(c["path_length"] for c in remaining)
            if b == "B1_very_early":
                members = [c for c in remaining if c["path_length"] == rmin]
            elif b == "B2_very_late":
                members = [c for c in remaining if c["path_length"] == rmax]
            else:
                members = [c for c in remaining if c["_bins_full"][b]]

            empty = not members
            if empty:
                # §7.5 backfill -- boundary-load ranking over the entire
                # remaining pool. Preregistered, not invented here.
                empty_bins.append(b)
                members = list(remaining)

            ranked = sorted(members, key=lambda c: (-c["_load"], tie_break(c)))
            pick = ranked[0]
            top_load = ranked[0]["_load"]
            contenders = [c for c in members if c["_load"] == top_load]
            steps.append({
                "bin": b,
                "bin_empty": empty,
                "candidates_in_bin": 0 if empty else len(members),
                "boundary_load": pick["_load"],
                "load_tied_contenders": len(contenders),
                "tie_break_applied": len(contenders) > 1,
                "chose": pick["fingerprint"],
                "why": (f"bin {b} had no remaining candidate; filled from the "
                        f"boundary-load ranking over the NPC's remaining pool "
                        f"(spec §7.5)"
                        if empty else
                        f"highest boundary load ({pick['_load']}/8) among "
                        f"{len(members)} candidates in {b}"
                        + (f"; {len(contenders)} tied on load, resolved by the "
                           f"§9 tie-break" if len(contenders) > 1 else "")),
            })
            picks.append(pick)
            remaining = [c for c in remaining if c is not pick]

        chosen[npc] = picks
        trace[npc] = steps
        empties[npc] = empty_bins

    return chosen, trace, empties, populations


# ---------------------------------------------------------------------------
# CORE (spec §8)


def cells(c: dict) -> set:
    return {(f, c["features"][f]) for f in FEATURES}


def select_core(surviving: list[dict], stress_ids: set) -> tuple:
    """Spec §8. Bucket quota, then round-robin greedy max-coverage."""
    chosen: dict[str, list[dict]] = {}
    trace: dict[str, list[dict]] = {}
    quotas: dict[str, dict[str, int]] = {}

    for i, npc in enumerate(NPCS):
        avail = [c for c in surviving
                 if c["npc"] == npc and c["fingerprint"] not in stress_ids]
        pop = Counter(c["features"]["progression_bucket"] for c in avail)

        # §8.1 published the pre-STRESS populations; recompute and check.
        pre = Counter(c["features"]["progression_bucket"]
                      for c in surviving if c["npc"] == npc)
        got = (pre["early"], pre["middle"], pre["late"])
        if got != FROZEN_QUOTA_POP[npc]:
            fail(f"{npc}: pre-STRESS bucket populations {got}, spec §8.1 says "
                 f"{FROZEN_QUOTA_POP[npc]}")

        # §8.1 -- 5/5/5, sixteenth slot to the largest surviving population,
        # ties by bucket name ascending.
        quota = {b: 5 for b in BUCKETS}
        extra = min(BUCKETS, key=lambda b: (-pop[b], b))
        quota[extra] += 1
        quotas[npc] = {"quota": dict(quota), "extra_slot": extra,
                       "populations": {b: pop[b] for b in BUCKETS}}
        for b in BUCKETS:
            if pop[b] < quota[b]:
                fail(f"{npc}: bucket {b} has {pop[b]} candidates for "
                     f"{quota[b]} slots")

        covered: set = set()
        picks: list[dict] = []
        steps: list[dict] = []
        left = dict(quota)
        cycle_pos = 0
        by_bucket = {b: [c for c in avail if c["features"]["progression_bucket"] == b]
                     for b in BUCKETS}

        for slot in range(1, 17):
            # §8.2 -- round-robin, skipping exhausted buckets.
            for _ in range(len(BUCKETS)):
                bucket = BUCKETS[cycle_pos % len(BUCKETS)]
                cycle_pos += 1
                if left[bucket] > 0:
                    break
            else:
                fail(f"{npc}: no bucket with quota remaining at slot {slot}")

            cands = by_bucket[bucket]
            gains = [len(cells(c) - covered) for c in cands]
            best = max(gains)
            reset = best == 0
            if reset:
                # §8.2 -- saturated: begin a second coverage layer.
                covered = set()
                gains = [len(cells(c) - covered) for c in cands]
                best = max(gains)
            winners = [c for c, g in zip(cands, gains) if g == best]
            pick = min(winners, key=tie_break)

            new_pairs = sorted(f"{f}={v}" for f, v in cells(pick) - covered)
            steps.append({
                "slot": slot,
                "bucket": bucket,
                "candidates_considered": len(cands),
                "coverage_gain": best,
                "coverage_reset": reset,
                "tied_at_max_gain": len(winners),
                "tie_break_applied": len(winners) > 1,
                "newly_covered": new_pairs,
                "chose": pick["fingerprint"],
                "why": (("coverage set saturated, reset to a second layer; " if reset
                         else "")
                        + f"largest coverage gain ({best} new feature-value pairs) "
                        + f"among {len(cands)} {bucket} candidates"
                        + (f"; {len(winners)} tied, resolved by the §9 tie-break"
                           if len(winners) > 1 else "")),
            })
            picks.append(pick)
            covered |= cells(pick)
            left[bucket] -= 1
            by_bucket[bucket] = [c for c in cands if c is not pick]

        chosen[npc] = picks
        trace[npc] = steps
    return chosen, trace, quotas


def core_acceptance(core: dict, surviving: list[dict]) -> dict:
    """Spec §8.4. Generation fails unless every reachable value is covered."""
    report: dict = {}
    for npc in NPCS:
        avail = [c for c in surviving if c["npc"] == npc]
        per_feature = {}
        for f in FEATURES:
            reach = {c["features"][f] for c in avail}
            cov = {c["features"][f] for c in core[npc]}
            per_feature[f] = {"covered": len(cov), "reachable": len(reach),
                              "complete": cov >= reach}
            if f in REQUIRED_COVERAGE and not cov >= reach:
                fail(f"{npc}: CORE does not cover every reachable value of {f} "
                     f"({sorted(map(str, reach - cov))} missing) — spec §8.4")
        report[npc] = per_feature
    return report


# ---------------------------------------------------------------------------
# Integrity scan (spec §14)


def forbidden_symbol_scan() -> dict:
    """Spec §14, run against this file before anything is written."""
    # The planted violation is built from the frozen list at runtime rather than
    # written out, so this file can be scanned by the very scanner it is testing.
    banned = FORBIDDEN_GENERATOR_SYMBOLS[0]
    planted = python_code_only(f'"""prose naming {banned}, which cannot count."""\n'
                               f"x = {banned}(npc, state)\n")
    if planted.count(banned) != 1:
        fail("the forbidden-symbol scanner is broken; it cannot be trusted to fail")

    code = python_code_only(Path(__file__).read_text())
    hits = [s for s in FORBIDDEN_GENERATOR_SYMBOLS if s in code]
    if hits:
        fail(f"this generator references forbidden symbols {hits} in code")
    return {"scanner_self_test": "passed",
            "symbols_checked": list(FORBIDDEN_GENERATOR_SYMBOLS),
            "violations": []}


# ---------------------------------------------------------------------------


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    scan = forbidden_symbol_scan()
    print("forbidden-symbol scan: PASS "
          f"({len(scan['symbols_checked'])} symbols, scanner self-tested)")

    spec_sha = sha256_bytes(SPEC.read_bytes())
    hints = parse_catalogue()
    concepts = pkm_reference.load_concepts()
    associated, preferred = derived_concept_sets(hints, concepts)
    assert_destination_flags()

    pool = build_candidates(hints, concepts, associated)
    exclusion, exclusion_info = load_exclusion()
    surviving = [c for c in pool if c["fingerprint"] not in exclusion]
    hit = len(pool) - len(surviving)
    if hit != FROZEN_POOL_INTERSECTION:
        fail(f"pool ∩ exclusion is {hit}, spec §4.2 says {FROZEN_POOL_INTERSECTION}")
    per_npc_after = Counter(c["npc"] for c in surviving)
    for npc in NPCS:
        if per_npc_after[npc] != FROZEN_AFTER_EXCLUSION[npc]:
            fail(f"{npc}: {per_npc_after[npc]} after exclusion, spec §4.2 says "
                 f"{FROZEN_AFTER_EXCLUSION[npc]}")
    print(f"pool: {len(pool)}  exclusion: {len(exclusion)}  "
          f"intersection: {hit}  surviving: {len(surviving)}")

    tables = verify_published_tables(pool, surviving, preferred)
    print("published tables §5.4 / §5.8 / §5.9: all recomputed and matching")

    # §6 -- STRESS first, so CORE draws from the ordinary bulk.
    stress, stress_trace, empties, bin_pop = select_stress(pool, surviving, preferred)
    print("published table §7.4 (bin populations): recomputed and matching")
    stress_ids = {c["fingerprint"] for npc in NPCS for c in stress[npc]}
    if len(stress_ids) != 24:
        fail(f"STRESS produced {len(stress_ids)} distinct states, expected 24")

    core, core_trace, quotas = select_core(surviving, stress_ids)
    coverage = core_acceptance(core, surviving)
    print("published table §8.1 (bucket populations): recomputed and matching")
    print("CORE acceptance §8.4: every required dimension fully covered")

    # ---- assemble, in the frozen order of §10 --------------------------------
    scenarios = []
    ordinal = 0
    for stratum, picked in (("CORE", core), ("STRESS", stress)):
        for npc in NPCS:
            for n, c in enumerate(picked[npc], start=1):
                ordinal += 1
                bin_id = STRESS_BINS[n - 1] if stratum == "STRESS" else None
                scenarios.append({
                    "id": f"v4_{stratum.lower()}_{npc}_{n:02d}",
                    "ordinal": ordinal,
                    "stratum": stratum,
                    "stress_bin": bin_id,
                    "bin_empty": bool(bin_id and bin_id in empties[npc]),
                    "npc": npc,
                    "room": c["room"],
                    "stage": c["features"]["stage"],
                    "progression_bucket": c["features"]["progression_bucket"],
                    "evidence_items": c["evidence_items"],
                    "knowledge_items": c["knowledge_items"],
                    "story_flags": c["story_flags"],
                    "pkm_states": c["pkm_states"],
                    "witness_path": c["witness_path"],
                    "candidate_hints": sorted(
                        h for h in hints if hints[h]["npc"] == npc),
                    "eligible_hints": c["eligible_hints"],
                    "eligible_hint_count": len(c["eligible_hints"]),
                    "state_fingerprint_sha256": c["fingerprint"],
                    "structural_features": {
                        f: (list(c["features"][f])
                            if isinstance(c["features"][f], tuple)
                            else c["features"][f])
                        for f in FEATURES},
                    "valid_hints": [],
                    "annotation": None,
                })

    ids = [s["id"] for s in scenarios]
    prints = [s["state_fingerprint_sha256"] for s in scenarios]
    if len(set(ids)) != 72 or len(set(prints)) != 72:
        fail(f"uniqueness: {len(set(ids))} ids, {len(set(prints))} fingerprints")
    if set(prints) & exclusion:
        fail("a selected state is in the contamination exclusion set")
    rooms = {s["room"] for s in scenarios}
    if "castle_hall" in rooms:
        fail("a v4 state is in castle_hall; the §4.4 partition is violated")

    # spec §12 layer 3 is run in Godot; the Python side re-derives every state's
    # PKM independently of the value carried in the artifact.
    for s in scenarios:
        again = pkm_reference.serialize([], s["story_flags"], s["evidence_items"])
        if again != s["pkm_states"]:
            fail(f"{s['id']}: pkm_states is not canonical")

    aggregate = sha256_bytes(json.dumps(
        [{k: s[k] for k in ("npc", "room", "evidence_items", "knowledge_items",
                            "story_flags")} for s in scenarios],
        sort_keys=True, separators=(",", ":")).encode())

    payload = {
        "version": "heldout-v4",
        "spec": "docs/HELDOUT_V4_GENERATION_SPEC.md",
        "spec_sha256": spec_sha,
        "spec_tag": "heldout-v4-generation-pre-freeze",
        "generated_by": "tools/generate_heldout_v4.py",
        "deterministic": True,
        "pkm_serialization": "canonical",
        "pkm_model_source": "scripts/player_knowledge_model.gd",
        "pkm_model_sha256": pkm_reference.model_sha256(),
        "exclusion_digest": exclusion_info["digest"],
        "exclusion_count": exclusion_info["count"],
        "state_aggregate_sha256": aggregate,
        "strata": {"CORE": 48, "STRESS": 24},
        "scenario_count": len(scenarios),
        "selector_was_run": False,
        "annotations_present": False,
        "coverage_report": {
            npc: {f: {"covered": coverage[npc][f]["covered"],
                      "reachable": coverage[npc][f]["reachable"]}
                  for f in FEATURES} for npc in NPCS},
        "stress_bin_report": {
            npc: {b: {"empty": b in empties[npc]} for b in STRESS_BINS}
            for npc in NPCS},
        "notes": [
            "Generated mechanically from the frozen specification at tag "
            "heldout-v4-generation-pre-freeze. No selector was run and no model "
            "was called.",
            "valid_hints and annotation are empty by construction and must be "
            "filled only by the human annotation step, after this file is frozen.",
            "candidate_hints lists every hint declared for the NPC; "
            "eligible_hints lists those whose HARD prerequisites this state "
            "meets. Neither is a prediction and neither came from a selector.",
        ],
        "scenarios": scenarios,
    }

    artifact_text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    artifact_sha = sha256_bytes(artifact_text.encode())

    audit = {
        "version": "heldout-v4-generation-audit",
        "spec_sha256": spec_sha,
        "artifact": "docs/heldout/heldout_v4_scenarios.json",
        "artifact_sha256": artifact_sha,
        "generated_by": "tools/generate_heldout_v4.py",
        "generator_sha256": sha256_bytes(Path(__file__).read_bytes()),
        "spec_checker_sha256": sha256_bytes(
            (REPO / "tools" / "check_heldout_v4_spec.py").read_bytes()),
        "pkm_model_sha256": pkm_reference.model_sha256(),
        "catalogue_sha256": sha256_bytes(
            (REPO / "scripts" / "adaptive_hint_data.gd").read_bytes()),
        "progression_model_sha256": sha256_bytes(
            (REPO / "tools" / "generate_heldout_v3.py").read_bytes()),
        "forbidden_symbol_scan": scan,
        "candidates": {
            "initial": len(pool),
            "per_npc": {npc: FROZEN_POOL[npc] for npc in NPCS},
            "exclusion_set_size": exclusion_info["count"],
            "exclusion_sources": exclusion_info["sources"],
            "exclusion_digest": exclusion_info["digest"],
            "excluded_from_pool": hit,
            "surviving": len(surviving),
            "surviving_per_npc": {npc: per_npc_after[npc] for npc in NPCS},
        },
        "published_tables_recomputed": tables,
        "selection_order": ["STRESS", "CORE"],
        "stress": {
            "bin_populations_full_pool": bin_pop,
            "empty_bins": empties,
            "trace": stress_trace,
        },
        "core": {
            "bucket_quotas": quotas,
            "feature_coverage": coverage,
            "trace": core_trace,
        },
        "contamination": {
            "exclusion_intersection_with_selection": 0,
            "exclusion_intersection_with_pool": hit,
            "v4_rooms": sorted(rooms),
            "castle_hall_partition_holds": "castle_hall" not in rooms,
        },
        "pkm_validation": {
            "python_recomputation": "72/72 states re-derived, all identical",
            "godot_cross_check": "tests/pkm_serialization_canonical_test.gd",
        },
        "integrity": {
            "selector_was_run": False,
            "annotations_present": False,
            "condition_a_called": False,
            "condition_b_called": False,
            "condition_c_called": False,
            "llm_called": False,
            "relevance_labels_present": False,
        },
        "notes": [
            "This audit records WHY the deterministic procedure chose each "
            "state, in structural terms only. It contains no judgement about "
            "hint relevance, and no condition was consulted to produce it.",
        ],
    }

    if dry_run:
        print(f"\n--dry-run: all checks passed, nothing written"
              f"\n  artifact sha256 would be {artifact_sha}")
        return 0

    OUT_JSON.write_text(artifact_text)
    OUT_AUDIT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    if sha256_bytes(OUT_JSON.read_bytes()) != artifact_sha:
        fail("the artifact on disk does not hash to the value pinned in the audit")
    print(f"\nwrote {OUT_JSON.relative_to(REPO)}")
    print(f"      {OUT_AUDIT.relative_to(REPO)}")
    print(f"  scenarios          {len(scenarios)} (CORE 48, STRESS 24)")
    print(f"  artifact sha256    {artifact_sha}")
    print(f"  state aggregate    {aggregate}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except GenerationFailure as exc:
        print(f"\ngenerate_heldout_v4: ABORTED\n  {exc}")
        raise SystemExit(1)
