#!/usr/bin/env python3
"""Verify `docs/HELDOUT_V4_GENERATION_SPEC.md` against the repository.

A specification frozen before the data exists is only worth what checking it
costs. Every number in that document was derived from files on disk, and every
one of those derivations can silently rot: a hint gains a prerequisite, a
synthetic fixture moves into a live room, a chronology rule is renamed, and the
spec keeps asserting something that stopped being true.

This recomputes the derivations rather than trusting them:

  * the pinned hashes, including the four closed heldout-v3 artifacts, so "v3 was
    not touched" fails loudly instead of being promised;
  * the strata arithmetic, in both the prose and the machine-readable block;
  * the catalogue facts the feature encoding rests on -- hint ownership, the
    derived concept sets, and the eligible-count collinearity;
  * the PKM concept list, parsed from the GDScript model rather than restated;
  * the 16 chronology rule ids, read out of the v3 test;
  * the contamination exclusion set and its digest, rebuilt from disk, plus the
    room-partition argument that covers the synthetic fixtures;
  * the progression-bucket thresholds, recomputed from the legal candidate pool;
  * that no forbidden selection feature appears in the frozen objective;
  * that the metric definitions still say silence is never relevant;
  * that no v4 artifact exists and no condition has been run.

Run with `--fault-test` to check the checks: each one is re-run against a
deliberately corrupted copy of its input and must report the corruption. A check
that cannot fail proves nothing.

    python3 tools/check_heldout_v4_spec.py
    python3 tools/check_heldout_v4_spec.py --fault-test
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SPEC = REPO / "docs" / "HELDOUT_V4_GENERATION_SPEC.md"
PROTOCOL = REPO / "docs" / "EVALUATION_PROTOCOL.md"
CSPEC = REPO / "docs" / "CONDITION_C_SPEC.md"

NPCS = ("butler", "gardener", "mechanic")

# The task's allowed sampling features, as feature names in the spec's encoding.
ALLOWED_FEATURES = {
    "stage", "progression_bucket", "own_evidence", "other_major_count",
    "eligible_count", "associated_concept_states", "pkm_profile",
    "room_investigation_complete", "destination_reached",
    "prior_npc_interaction", "evidence_shape", "shape_x_associated",
}

# Substrings that must not appear in the frozen objective's feature names. The
# spec NAMES these in its own prohibition table and in Appendix A's
# `forbidden_selection_features` list, which is the point of scanning only the
# objective rather than the whole document.
FORBIDDEN_SUBSTRINGS = (
    "condition_a", "condition_b", "condition_c", "selector", "valid_hints",
    "relevan", "redundan", "winner", "disagree", "annotat", "label", "v3_",
)

FORBIDDEN_GENERATOR_SYMBOLS = (
    "select_condition_a", "select_adaptive", "adaptive_hint_selector",
    "CONDITION_A_TIERS", "condition_c_selector", "condition_c_client",
)

V3_CLOSED = (
    "docs/heldout/heldout_v3_scenarios.json",
    "docs/heldout/heldout_v3_annotated.json",
    "docs/heldout/heldout_v3_ab_raw.json",
    "docs/heldout/heldout_v3_ab_metrics.json",
)

C_FREEZE_TAG = "condition-c-pre-v4-freeze-v2"


# --------------------------------------------------------------------------
# loading


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fenced_json(text: str, after_heading: str) -> dict:
    """The first ```json block following a heading."""
    start = text.find(after_heading)
    if start < 0:
        raise ValueError(f"heading not found: {after_heading!r}")
    m = re.search(r"```json\n(.*?)\n```", text[start:], re.S)
    if m is None:
        raise ValueError(f"no json block under {after_heading!r}")
    return json.loads(m.group(1))


def python_code_only(source: str) -> str:
    """Python source with docstrings and whole-line comments removed.

    Both are prose, and a generator is expected to record in prose which calls
    it is forbidden to make. Scanning raw text would read that commitment as the
    violation it promises not to commit.
    """
    stripped = re.sub(r'"""(?:.|\n)*?"""', "", source)
    stripped = re.sub(r"'''(?:.|\n)*?'''", "", stripped)
    return "\n".join(
        line for line in stripped.splitlines() if not line.strip().startswith("#")
    )


def parse_catalogue(source: str) -> dict:
    """Hard-prerequisite and structural metadata, parsed from the GDScript.

    Parsed rather than transcribed: a copy of this table in Python would be a
    second source of truth, and the drift it hid would be exactly the drift this
    checker exists to catch.
    """
    entry = re.compile(r'^\t"([a-z_0-9]+)":\s*\{(.*?)^\t\},', re.S | re.M)

    def slist(body: str, key: str) -> list[str]:
        m = re.search(rf'"{key}":\s*\[(.*?)\]', body, re.S)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []

    hints: dict[str, dict] = {}
    for const in ("LEGACY_GROUNDED_HINTS", "AUTHORED_HINTS"):
        m = re.search(rf"const {const}[^=]*=\s*\{{(.*?)^\}}", source, re.S | re.M)
        if m is None:
            raise ValueError(f"catalogue block not found: {const}")
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


def state_fingerprint(npc, room, evidence, knowledge, flags) -> str:
    return sha256_bytes(json.dumps({
        "npc": npc, "room": room,
        "evidence_items": sorted(evidence),
        "knowledge_items": sorted(knowledge),
        "story_flags": sorted(flags),
    }, sort_keys=True, separators=(",", ":")).encode())


def load_world() -> dict:
    spec_text = SPEC.read_text()
    params = fenced_json(spec_text, "## Appendix A")
    pins = fenced_json(spec_text, "## Appendix B")

    files = {rel: (REPO / rel).read_bytes() for rel in pins if (REPO / rel).exists()}

    sys.path.insert(0, str(REPO / "tools"))
    import pkm_reference  # noqa: E402

    chrono = (REPO / "tests" / "heldout_v3_chronology_test.gd").read_text()

    exclusion: set[str] = set()
    for rel in params["exclusion"]["sources"]:
        for s in json.loads((REPO / rel).read_text())["scenarios"]:
            exclusion.add(state_fingerprint(
                s["npc"], s["room"], s["evidence_items"],
                s.get("knowledge_items", []), s["story_flags"]))

    synthetic_rooms: dict[str, Counter] = {}
    for rel in ("tests/condition_c_selector_test.gd",
                "tests/condition_c_transport_test.gd",
                "tools/condition_c_live_smoke.gd",
                "tests/adaptive_hint_baseline_test.gd"):
        p = REPO / rel
        synthetic_rooms[rel] = Counter(
            re.findall(r'"room"\s*:\s*"([a-z_]+)"', p.read_text())) if p.exists() else Counter()
    v1 = REPO / "docs" / "heldout" / "heldout_v1_scenarios.json"
    if v1.exists():
        doc = json.loads(v1.read_text())
        synthetic_rooms["docs/heldout/heldout_v1_scenarios.json"] = Counter(
            s["room"] for s in (doc["scenarios"] if isinstance(doc, dict) else doc))

    at_tag = subprocess.run(
        ["git", "-C", str(REPO), "show", f"{C_FREEZE_TAG}:docs/EVALUATION_PROTOCOL.md"],
        capture_output=True)

    return {
        "spec_text": spec_text,
        "params": params,
        "pins": pins,
        "files": files,
        "hints": parse_catalogue((REPO / "scripts" / "adaptive_hint_data.gd").read_text()),
        "concepts": pkm_reference.load_concepts(),
        "chrono_ids": re.findall(r'"id":\s*"(C[0-9][0-9a-z_]*)"', chrono),
        "exclusion": exclusion,
        "synthetic_rooms": synthetic_rooms,
        "protocol_text": PROTOCOL.read_text(),
        "protocol_bytes": PROTOCOL.read_bytes(),
        "protocol_at_tag": at_tag.stdout if at_tag.returncode == 0 else None,
        "c_manifest": json.loads(
            (REPO / "docs" / "condition_c_freeze_manifest.json").read_text()),
        "cspec_text": CSPEC.read_text() if CSPEC.exists() else "",
        "generator_source": None,
        "v4_artifacts": sorted(
            p.name for p in (REPO / "docs" / "heldout").glob("*v4*")),
    }


_POOL_CACHE: dict | None = None


def load_pool() -> dict:
    """Per-NPC witness-path length extremes over the legal candidate pool."""
    global _POOL_CACHE
    if _POOL_CACHE is not None:
        return _POOL_CACHE
    sys.path.insert(0, str(REPO / "tools"))
    import generate_heldout_v3 as g  # main() is under __main__; nothing is written

    per: dict[str, list[int]] = defaultdict(list)
    fps: set[str] = set()
    for c in g.build_pool():
        per[c["npc"]].append(len(c["witness_path"]))
        fps.add(state_fingerprint(c["npc"], c["room"], c["evidence_items"],
                                 c["knowledge_items"], c["story_flags"]))
    _POOL_CACHE = {
        "per_npc": {n: len(v) for n, v in per.items()},
        "total": sum(len(v) for v in per.values()),
        "lengths": {n: (min(v), max(v)) for n, v in per.items()},
        "fingerprints": fps,
        "steps": g.STEPS,
        "room_steps": {
            "butler": set(g.CHEM_OPT) | {"chem_cabinet"},
            "gardener": set(g.GREEN_OPT),
            "mechanic": set(g.CIRCUIT_OPT),
        },
    }
    return _POOL_CACHE


# --------------------------------------------------------------------------
# checks


def check_pins(w, problems) -> int:
    for rel, expected in w["pins"].items():
        data = w["files"].get(rel)
        if data is None:
            problems.append(f"pinned file is missing: {rel}")
            continue
        actual = sha256_bytes(data)
        if actual != expected:
            kind = "CLOSED v3 ARTIFACT" if rel in V3_CLOSED else "pinned file"
            problems.append(f"{kind} changed: {rel}\n    spec    {expected}\n"
                            f"    on disk {actual}")
    for rel in V3_CLOSED:
        if rel not in w["pins"]:
            problems.append(f"the spec no longer pins the closed v3 artifact {rel}")
    return len(w["pins"])


def check_strata(w, problems) -> None:
    s = w["params"]["strata"]
    if s["CORE"]["per_npc"] * 3 != s["CORE"]["total"]:
        problems.append(f"CORE: {s['CORE']['per_npc']} x 3 != {s['CORE']['total']}")
    if s["STRESS"]["per_npc"] * 3 != s["STRESS"]["total"]:
        problems.append(f"STRESS: {s['STRESS']['per_npc']} x 3 != {s['STRESS']['total']}")
    if s["CORE"]["total"] + s["STRESS"]["total"] != s["TOTAL"]:
        problems.append("strata totals do not sum to TOTAL")
    if (s["CORE"]["total"], s["STRESS"]["total"], s["TOTAL"]) != (48, 24, 72):
        problems.append("strata sizes are not the required 48 / 24 / 72")

    # The prose must agree with the machine-readable block, or the document has
    # two sources of truth.
    prose = w["spec_text"]
    for phrase in ("CORE (n = 48)", "STRESS (n = 24)",
                   "## 8. CORE selection (48 = 16 + 16 + 16)",
                   "## 7. STRESS selection (24 = 8 + 8 + 8)"):
        if phrase not in prose:
            problems.append(f"the prose no longer states {phrase!r}")

    if w["params"]["selection_order"] != ["STRESS", "CORE"]:
        problems.append("the frozen selection order is no longer STRESS then CORE")


def check_catalogue(w, problems) -> None:
    hints, params = w["hints"], w["params"]
    if len(hints) != 11:
        problems.append(f"catalogue has {len(hints)} hints, expected 11")

    by_npc = defaultdict(list)
    for hid, h in sorted(hints.items()):
        if h["npc"] not in NPCS:
            problems.append(f"{hid}: unknown npc {h['npc']!r}")
        by_npc[h["npc"]].append(hid)

    # The derived concept sets the STRESS bins and feature F6 rest on.
    for npc in NPCS:
        derived = sorted({
            c for hid in by_npc[npc]
            for c in hints[hid]["teaches"] + hints[hid]["preferred_when_demonstrated"]
            if c in w["concepts"]
        })
        if derived != params["associated_concepts"].get(npc):
            problems.append(
                f"associated_concepts[{npc}]: spec {params['associated_concepts'].get(npc)}, "
                f"catalogue {derived}")

    # Eligible-count collinearity: the spec's §5.8 disclosure, and the reason
    # two of the objective's features carry one bit between them.
    gated = [hid for hid, h in hints.items()
             if h["requires_story_flags"] or h["requires_concept"]]
    collinear = not gated
    if collinear != params.get("eligible_count_collinear_with_own_evidence"):
        problems.append(
            f"eligible_count collinearity: spec says "
            f"{params.get('eligible_count_collinear_with_own_evidence')}, but hints "
            f"{gated or 'none'} declare flag/concept prerequisites")
    if gated:
        problems.append(
            "a hint now declares requires_story_flags or requires_concept; spec "
            "§5.8 and the eligible-count encoding must be re-derived")

    # And the collinearity itself, computed rather than asserted.
    majors = {"butler": "fake_red_stain", "gardener": "greenhouse_pollen",
              "mechanic": "deliberate_short_circuit"}
    for npc in NPCS:
        counts = {}
        for own in (False, True):
            ev = {majors[npc]} if own else set()
            counts[own] = sum(
                1 for hid in by_npc[npc]
                if all(e in ev for e in hints[hid]["requires_evidence"])
                and not any(e in ev for e in hints[hid]["requires_evidence_absent"]))
        if counts[False] == counts[True]:
            problems.append(
                f"{npc}: eligible_count does not separate own-evidence states "
                f"({counts[False]} either way); the spec claims it does")


def check_pkm(w, problems) -> None:
    concepts = w["concepts"]
    if len(concepts) != 8:
        problems.append(f"PlayerKnowledgeModel has {len(concepts)} concepts, expected 8")
    for npc, cs in w["params"]["associated_concepts"].items():
        for c in cs:
            if c not in concepts:
                problems.append(f"associated_concepts[{npc}] names a non-PKM concept {c!r}")
    if w["params"].get("pkm_serialization") != "canonical":
        problems.append("the spec no longer requires canonical PKM serialization")
    if "pkm_serialization" not in w["spec_text"] or '"canonical"' not in w["spec_text"]:
        problems.append("the spec no longer names the canonical serialization stamp")


def check_chronology(w, problems) -> None:
    ids = w["chrono_ids"]
    params = w["params"]
    if len(ids) != params["chronology_rule_count"]:
        problems.append(
            f"chronology rules: v3 test has {len(ids)}, spec claims "
            f"{params['chronology_rule_count']}")
    missing = [i for i in ids if i not in w["spec_text"]]
    if missing:
        problems.append(f"the spec does not list chronology rules: {missing}")
    if params["chronology_rule_source"] != "tests/heldout_v3_chronology_test.gd":
        problems.append("the spec no longer sources the rules from the v3 test")


def check_exclusion(w, problems) -> None:
    params = w["params"]["exclusion"]
    excl = w["exclusion"]
    if len(excl) != params["count"]:
        problems.append(f"exclusion set: rebuilt {len(excl)}, spec claims {params['count']}")
    digest = sha256_bytes("\n".join(sorted(excl)).encode())
    if digest != params["digest"]:
        problems.append(f"exclusion digest\n    spec    {params['digest']}\n"
                        f"    rebuilt {digest}")
    if digest not in w["spec_text"]:
        problems.append("the spec prose no longer carries the exclusion digest")
    if params.get("id_included") is not False:
        problems.append("the fingerprint definition no longer excludes the scenario id")
    if "id" in params["fingerprint_fields"]:
        problems.append("the fingerprint fields include an identifier")


def check_room_partition(w, problems) -> None:
    """No synthetic or development state may sit in a live NPC room."""
    live = set(w["params"]["npc_rooms"].values())
    total = 0
    for rel, rooms in w["synthetic_rooms"].items():
        if not rooms:
            problems.append(f"{rel}: no room literals found; the partition scan may "
                            f"be passing vacuously")
            continue
        total += sum(rooms.values())
        for room, n in rooms.items():
            if room in live:
                problems.append(
                    f"{rel} places {n} synthetic state(s) in the live room {room!r}; "
                    f"spec §4.4's partition argument no longer holds and the "
                    f"exclusion set must be extended")
    if total == 0:
        problems.append("the room-partition scan examined nothing")


def check_features(w, problems) -> None:
    params = w["params"]
    objective = params["core_objective_features"]
    if len(set(objective)) != len(objective):
        problems.append("the objective repeats a feature")
    for f in objective:
        if f not in ALLOWED_FEATURES:
            problems.append(f"objective feature {f!r} is not on the allowed list")
        for bad in FORBIDDEN_SUBSTRINGS:
            if bad in f:
                problems.append(f"objective feature {f!r} contains forbidden term {bad!r}")
    for f in params["required_coverage_features"]:
        if f not in objective:
            problems.append(f"required-coverage feature {f!r} is not in the objective")
    if params.get("feature_weights") != "uniform":
        problems.append("feature weights are no longer uniform")
    if len(params["forbidden_selection_features"]) < 11:
        problems.append("the forbidden-feature list has shrunk below the task's 11")
    # The forbidden list must be a list of things NOT used -- its terms must not
    # leak into the objective.
    for f in params["forbidden_selection_features"]:
        if f in objective:
            problems.append(f"{f!r} is both forbidden and in the objective")


def check_buckets(w, problems) -> None:
    pool = load_pool()
    params = w["params"]
    for npc in NPCS:
        lo, hi = pool["lengths"][npc]
        spec = params["progression_bucket"][npc]
        if (lo, hi) != (spec["lo"], spec["hi"]):
            problems.append(
                f"{npc}: pool path length {lo}..{hi}, spec says "
                f"{spec['lo']}..{spec['hi']}")
            continue
        span = hi - lo
        def bucket(L: int) -> str:
            x = 3 * (L - lo)
            return "early" if x < span else ("middle" if x < 2 * span else "late")
        early_max = max(L for L in range(lo, hi + 1) if bucket(L) == "early")
        middle_max = max(L for L in range(lo, hi + 1) if bucket(L) == "middle")
        if (early_max, middle_max) != (spec["early_max"], spec["middle_max"]):
            problems.append(
                f"{npc}: recomputed bucket edges ({early_max}, {middle_max}) != spec "
                f"({spec['early_max']}, {spec['middle_max']})")
        for name in ("early", "middle", "late"):
            if not any(bucket(L) == name for L in range(lo, hi + 1)):
                problems.append(f"{npc}: bucket {name!r} is empty")

    if pool["total"] != params["pool"]["total"]:
        problems.append(f"pool size: measured {pool['total']}, spec says "
                        f"{params['pool']['total']}")
    for npc in NPCS:
        if pool["per_npc"][npc] != params["pool"]["per_npc"][npc]:
            problems.append(f"pool[{npc}]: measured {pool['per_npc'][npc]}, spec says "
                            f"{params['pool']['per_npc'][npc]}")
    if len(pool["fingerprints"]) != pool["total"]:
        problems.append(
            f"pool fingerprints are not distinct ({len(pool['fingerprints'])} for "
            f"{pool['total']} candidates); the tie-break in spec §9 is not a total order")
    hit = len(pool["fingerprints"] & w["exclusion"])
    if hit != params["exclusion"]["pool_intersection"]:
        problems.append(f"pool n exclusion: measured {hit}, spec says "
                        f"{params['exclusion']['pool_intersection']}")


def check_destination_flags(w, problems) -> None:
    pool = load_pool()
    steps, room_steps = pool["steps"], pool["room_steps"]
    for npc, flag in w["params"]["destination_flags"].items():
        owners = [k for k, s in steps.items() if flag in s.get("flags", [])]
        if not owners:
            problems.append(f"destination flag {flag!r} ({npc}) is set by no step")
            continue
        stray = [o for o in owners if o not in room_steps[npc]]
        if stray:
            problems.append(
                f"destination flag {flag!r} ({npc}) is set outside that NPC's room "
                f"by {stray}")


def check_stress_bins(w, problems) -> None:
    params = w["params"]
    bins = params["stress_bins"]
    if len(bins) != 8:
        problems.append(f"{len(bins)} STRESS bins, expected 8")
    if len(set(bins)) != len(bins):
        problems.append("a STRESS bin id is repeated")
    for b in bins:
        if b not in w["spec_text"]:
            problems.append(f"STRESS bin {b!r} is not described in the prose")
    for npc, empty in params["stress_empty_bins"].items():
        for b in empty:
            if b not in bins:
                problems.append(f"stress_empty_bins[{npc}] names unknown bin {b!r}")
    # No bin may name silence: §7.2 is explicit that no predicate decides a state
    # "should be" silent.
    for b in bins:
        if "silen" in b.lower():
            problems.append(f"STRESS bin {b!r} names silence")


def check_tie_break(w, problems) -> None:
    tb = w["params"]["tie_break"]
    if tb[-1] != "state_fingerprint_lexicographic_ascending":
        problems.append("the tie-break no longer ends in the fingerprint, so it is "
                        "not guaranteed total")
    if len(set(tb)) != len(tb):
        problems.append("the tie-break repeats a criterion")
    if len(tb) < 2:
        problems.append("the tie-break has no structural preference before the hash")


def check_metrics(w, problems) -> None:
    m = w["params"]["metrics"]
    if m.get("silence_is_relevant") is not False:
        problems.append("the spec no longer states that silence is never relevant")
    if "RelevantHintRate" not in m["primary"]:
        problems.append("RelevantHintRate is not primary")
    if sorted(m.get("new_in_v4", [])) != ["AppropriateActionRate", "CorrectSilenceRate"]:
        problems.append("the new-in-v4 metric list has changed")
    if "AppropriateActionRate" in m["primary"]:
        problems.append("AppropriateActionRate must be SECONDARY, not primary")
    if "CorrectSilenceRate" not in m["descriptive"]:
        problems.append("CorrectSilenceRate must be descriptive only")
    if m.get("composite_score") is not False or m.get("strata_combined") is not False:
        problems.append("the spec no longer forbids a composite / combined score")

    inf = w["params"]["inference"]
    if inf["primary_outcome"] != "RelevantHintRate":
        problems.append("the primary inferential outcome has changed")
    if inf["secondary_outcome"] != "AppropriateActionRate":
        problems.append("the secondary inferential outcome has changed")
    if inf["test"] != "exact_mcnemar" or not inf.get("paired"):
        problems.append("the preregistered test is no longer a paired exact McNemar")
    if [sorted(p) for p in inf["comparisons"]] != [["A", "B"], ["A", "C"], ["B", "C"]]:
        problems.append("the preregistered comparison family has changed")
    if inf["stratum"] != "CORE":
        problems.append("the confirmatory analysis is no longer on CORE")
    if not (REPO / inf["implementation"]).exists():
        problems.append(f"the preregistered test implementation is missing: "
                        f"{inf['implementation']}")

    # The frozen v3 rule, still in the protocol, still saying the same thing.
    p = w["protocol_text"]
    for phrase in ("**Silence counts as failure**",
                   "## 12. Held-out v4 — prospective evaluation plan",
                   "**SILENCE is never relevant**",
                   "`AppropriateActionRate` — SECONDARY",
                   "`CorrectSilenceRate` — DESCRIPTIVE ONLY",
                   "v3 is **not** recomputed"):
        if phrase not in p:
            problems.append(f"the protocol no longer contains {phrase!r}")
    if w["cspec_text"] and "C cannot improve its score by abstaining" not in w["cspec_text"]:
        problems.append("the frozen Condition C spec no longer states that C cannot "
                        "improve its score by abstaining")

    c = w["params"]["condition_c"]
    if c["primary_inferences_per_scenario"] != 1 or c.get("reruns_allowed") is not False:
        problems.append("the Condition C run discipline has been loosened")
    if c.get("transport_retry_is_new_sample") is not False:
        problems.append("a transport retry would now count as a new model sample")
    if c.get("requested_model") != "claude-opus-5":
        problems.append("the requested model has changed")


def check_generator_integrity(w, problems) -> str:
    """Scan the v4 generator for forbidden calls -- or report the scan deferred."""
    # Self-test first: a scanner that cannot see a violation would pass on any
    # file, including one that really calls the selector.
    planted = python_code_only(
        '"""A docstring naming select_condition_a, which is prose."""\n'
        "x = select_adaptive(npc, state)\n"
    )
    if "select_condition_a" in planted:
        problems.append("the scanner's comment stripping does not remove docstrings")
    if "select_adaptive" not in planted:
        problems.append("the scanner would not see a real call; it cannot fail")

    gen = REPO / "tools" / "generate_heldout_v4.py"
    source = w["generator_source"]
    if source is None and gen.exists():
        source = gen.read_text()
    if source is None:
        return "DEFERRED (tools/generate_heldout_v4.py does not exist yet)"
    code = python_code_only(source)
    for symbol in FORBIDDEN_GENERATOR_SYMBOLS:
        if symbol in code:
            problems.append(f"tools/generate_heldout_v4.py calls {symbol!r}")
    return "scanned"


def check_protocol_append_only(w, problems) -> None:
    """The protocol grew by appending; nothing written before the C freeze moved.

    `check_condition_c_freeze.py` verifies the same property against a byte count
    recorded in the freeze manifest. This verifies it against the git object
    store, so the recorded count itself has to be right -- a mistyped offset
    would satisfy the manifest's own arithmetic and fail here.
    """
    at_tag = w["protocol_at_tag"]
    if at_tag is None:
        problems.append(
            f"cannot read docs/EVALUATION_PROTOCOL.md at {C_FREEZE_TAG}; the "
            f"append-only claim behind §12 is unverifiable")
        return
    entry = w["c_manifest"]["supporting_hashes"]["evaluation_protocol"]
    if entry.get("frozen_prefix_bytes") != len(at_tag):
        problems.append(
            f"the C freeze manifest pins a {entry.get('frozen_prefix_bytes')}-byte "
            f"protocol prefix, but the protocol at {C_FREEZE_TAG} is "
            f"{len(at_tag)} bytes")
    if entry["sha256"] != sha256_bytes(at_tag):
        problems.append(
            f"the C freeze manifest's protocol hash is not the hash of the "
            f"protocol at {C_FREEZE_TAG}")
    current = w["protocol_bytes"]
    if not current.startswith(at_tag):
        offset = next((i for i, (p, q) in enumerate(zip(current, at_tag)) if p != q),
                      min(len(current), len(at_tag)))
        problems.append(
            f"docs/EVALUATION_PROTOCOL.md is no longer an extension of its state "
            f"at {C_FREEZE_TAG}; it first diverges at byte {offset}. The v4 "
            f"section must be appended, not woven into the closed v3 protocol")


def check_no_v4_yet(w, problems) -> None:
    if w["v4_artifacts"]:
        problems.append(f"a v4 artifact already exists: {w['v4_artifacts']}")
    for rel in ("docs/heldout/heldout_v3_ab_metrics.json",
                "docs/heldout/heldout_v3_ab_raw.json"):
        doc = json.loads(w["files"][rel])
        if doc.get("condition_c_run") is not False:
            problems.append(f"{rel} no longer records that C was not run on v3")
        conds = doc.get("conditions_run")
        if conds != ["A", "B"]:
            problems.append(f"{rel}: conditions_run is {conds}, expected ['A', 'B']")


# --------------------------------------------------------------------------
# fault injection


def _fault_cases():
    """(label, check, mutation) -- each mutation must make its check complain."""

    def set_in(path, value):
        def mutate(w):
            node = w
            for k in path[:-1]:
                node = node[k]
            node[path[-1]] = value
        return mutate

    return [
        ("pinned hash drift", check_pins,
         lambda w: w["files"].__setitem__(V3_CLOSED[0], b"tampered")),
        ("closed v3 artifact unpinned", check_pins,
         lambda w: w["pins"].pop(V3_CLOSED[1])),
        ("strata arithmetic", check_strata,
         set_in(["params", "strata", "CORE", "per_npc"], 15)),
        ("strata total", check_strata,
         set_in(["params", "strata", "TOTAL"], 96)),
        ("selection order reversed", check_strata,
         set_in(["params", "selection_order"], ["CORE", "STRESS"])),
        ("associated concept drift", check_catalogue,
         set_in(["params", "associated_concepts", "gardener"], ["spectrum"])),
        ("hint gains a flag prerequisite", check_catalogue,
         lambda w: w["hints"]["h_gardener_pollen"].__setitem__(
             "requires_story_flags", ["some_flag"])),
        ("hint count", check_catalogue,
         lambda w: w["hints"].pop("h_butler_stain")),
        ("pkm concept removed", check_pkm,
         lambda w: w["concepts"].pop("reflection")),
        ("associated concept is not a PKM concept", check_pkm,
         set_in(["params", "associated_concepts", "butler"], ["dual_lock_rule"])),
        ("canonical stamp dropped", check_pkm,
         set_in(["params", "pkm_serialization"], "legacy")),
        ("chronology rule renamed", check_chronology,
         lambda w: w["chrono_ids"].__setitem__(0, "C1_renamed")),
        ("chronology rule count", check_chronology,
         lambda w: w["chrono_ids"].pop()),
        ("exclusion digest drift", check_exclusion,
         set_in(["params", "exclusion", "digest"], "0" * 64)),
        ("exclusion member removed", check_exclusion,
         lambda w: w["exclusion"].pop()),
        ("fingerprint gains an id", check_exclusion,
         set_in(["params", "exclusion", "fingerprint_fields"],
                ["id", "npc", "room", "evidence_items", "knowledge_items", "story_flags"])),
        ("synthetic fixture in a live room", check_room_partition,
         lambda w: w["synthetic_rooms"]["tests/condition_c_selector_test.gd"].update(
             {"chemistry_room": 1})),
        ("room scan finds nothing", check_room_partition,
         lambda w: w["synthetic_rooms"].__setitem__(
             "tools/condition_c_live_smoke.gd", Counter())),
        ("forbidden feature in the objective", check_features,
         lambda w: w["params"]["core_objective_features"].append("condition_a_output")),
        ("required feature not in the objective", check_features,
         lambda w: w["params"]["core_objective_features"].remove("own_evidence")),
        ("weights no longer uniform", check_features,
         set_in(["params", "feature_weights"], {"own_evidence": 3})),
        ("bucket edge drift", check_buckets,
         set_in(["params", "progression_bucket", "butler", "early_max"], 99)),
        ("pool size drift", check_buckets,
         set_in(["params", "pool", "total"], 1)),
        ("pool intersection drift", check_buckets,
         set_in(["params", "exclusion", "pool_intersection"], 0)),
        ("destination flag is not a real flag", check_destination_flags,
         set_in(["params", "destination_flags", "mechanic"], "no_such_flag")),
        ("destination flag outside the NPC's room", check_destination_flags,
         set_in(["params", "destination_flags", "gardener"], "circuit_power_restored")),
        ("stress bin count", check_stress_bins,
         lambda w: w["params"]["stress_bins"].pop()),
        ("stress bin names silence", check_stress_bins,
         lambda w: w["params"]["stress_bins"].__setitem__(0, "B1_should_be_silence")),
        ("tie-break not total", check_tie_break,
         set_in(["params", "tie_break"], ["witness_path_length_ascending"])),
        ("silence becomes relevant", check_metrics,
         set_in(["params", "metrics", "silence_is_relevant"], True)),
        ("AppropriateActionRate promoted to primary", check_metrics,
         lambda w: w["params"]["metrics"]["primary"].append("AppropriateActionRate")),
        ("comparison family changed", check_metrics,
         set_in(["params", "inference", "comparisons"], [["A", "C"]])),
        ("test swapped for an approximation", check_metrics,
         set_in(["params", "inference", "test"], "chi_square")),
        ("protocol section deleted", check_metrics,
         lambda w: w.__setitem__("protocol_text",
                                 w["protocol_text"].replace(
                                     "## 12. Held-out v4 — prospective evaluation plan", ""))),
        ("C rerun discipline loosened", check_metrics,
         set_in(["params", "condition_c", "reruns_allowed"], True)),
        ("protocol edited, not appended to", check_protocol_append_only,
         lambda w: w.__setitem__("protocol_bytes",
                                 b"x" + w["protocol_bytes"][1:])),
        ("protocol truncated below the frozen prefix", check_protocol_append_only,
         lambda w: w.__setitem__("protocol_bytes", w["protocol_at_tag"][:100])),
        ("manifest prefix offset mistyped", check_protocol_append_only,
         lambda w: w["c_manifest"]["supporting_hashes"]["evaluation_protocol"]
                    .__setitem__("frozen_prefix_bytes", 38197)),
        ("tag unreadable", check_protocol_append_only,
         lambda w: w.__setitem__("protocol_at_tag", None)),
        ("generator calls the selector", check_generator_integrity,
         lambda w: w.__setitem__("generator_source",
                                 "import x\nh = select_condition_a(npc, state)\n")),
        ("a v4 artifact exists", check_no_v4_yet,
         lambda w: w["v4_artifacts"].append("heldout_v4_scenarios.json")),
        ("C recorded as run on v3", check_no_v4_yet,
         lambda w: w["files"].__setitem__(
             "docs/heldout/heldout_v3_ab_metrics.json",
             json.dumps({"condition_c_run": True,
                         "conditions_run": ["A", "B", "C"]}).encode())),
    ]


def run_fault_tests(base) -> int:
    print("fault injection -- every check is run against a corrupted input")
    print("and must report the corruption\n")
    missed = []
    for label, check, mutate in _fault_cases():
        w = copy.deepcopy(base)
        w["files"] = dict(base["files"])
        mutate(w)
        problems: list[str] = []
        try:
            check(w, problems)
        except Exception as exc:               # a raise is also a detection
            problems.append(f"raised {type(exc).__name__}: {exc}")
        status = "caught" if problems else "MISSED"
        if not problems:
            missed.append(label)
        print(f"  {status:>6}  {label}")
    print()
    if missed:
        print(f"check_heldout_v4_spec --fault-test: FAIL ({len(missed)} undetected)")
        for m in missed:
            print("  - " + m)
        return 1
    print(f"check_heldout_v4_spec --fault-test: PASS "
          f"({len(_fault_cases())} faults, all detected)")
    return 0


# --------------------------------------------------------------------------


def main() -> int:
    world = load_world()
    problems: list[str] = []

    pinned = check_pins(world, problems)
    check_strata(world, problems)
    check_catalogue(world, problems)
    check_pkm(world, problems)
    check_chronology(world, problems)
    check_exclusion(world, problems)
    check_room_partition(world, problems)
    check_features(world, problems)
    check_stress_bins(world, problems)
    check_tie_break(world, problems)
    check_metrics(world, problems)
    check_protocol_append_only(world, problems)
    check_no_v4_yet(world, problems)
    check_buckets(world, problems)
    check_destination_flags(world, problems)
    generator = check_generator_integrity(world, problems)

    mcnemar = subprocess.run(
        [sys.executable, str(REPO / "tools" / "mcnemar_exact.py"), "--self-test"],
        capture_output=True, text=True)
    if mcnemar.returncode != 0:
        problems.append("tools/mcnemar_exact.py self-test failed:\n" + mcnemar.stdout)

    pool = load_pool()
    p = world["params"]
    print(f"heldout-v4 generation spec — {SPEC.relative_to(REPO)}")
    print(f"  spec sha256    {sha256_bytes(SPEC.read_bytes())}")
    print(f"  strata         CORE {p['strata']['CORE']['total']} "
          f"({p['strata']['CORE']['per_npc']}/NPC) + STRESS "
          f"{p['strata']['STRESS']['total']} ({p['strata']['STRESS']['per_npc']}/NPC) "
          f"= {p['strata']['TOTAL']}")
    print(f"  candidate pool {pool['total']} legal states, all fingerprints distinct")
    print(f"  exclusion      {len(world['exclusion'])} fingerprints, "
          f"{len(pool['fingerprints'] & world['exclusion'])} present in the pool")
    print(f"  features       {len(p['core_objective_features'])} structural, "
          f"weights {p['feature_weights']}, 0 selector-derived")
    print(f"  chronology     {len(world['chrono_ids'])} rules from "
          f"{p['chronology_rule_source']}")
    print(f"  metrics        primary {', '.join(p['metrics']['primary'])}; "
          f"silence relevant: {p['metrics']['silence_is_relevant']}")
    print(f"  inference      {p['inference']['test']} on "
          f"{p['inference']['primary_outcome']} (CORE), "
          f"{len(p['inference']['comparisons'])} preregistered pairs")
    print(f"  pinned hashes  {pinned} recomputed")
    print(f"  generator scan {generator}")
    print(f"  v4 artifacts   {world['v4_artifacts'] or 'none — v4 has not been generated'}")

    if problems:
        print(f"\ncheck_heldout_v4_spec: FAIL ({len(problems)})")
        for problem in problems:
            print("  - " + problem)
        return 1
    print("\ncheck_heldout_v4_spec: PASS")
    return 0


if __name__ == "__main__":
    if "--fault-test" in sys.argv:
        sys.exit(run_fault_tests(load_world()))
    sys.exit(main())
