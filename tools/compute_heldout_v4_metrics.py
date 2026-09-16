#!/usr/bin/env python3
"""Metrics for the frozen heldout-v4 A/B/C evaluation.

The Godot harnesses wrote raw per-scenario rows and deliberately computed no
metric. This program joins those rows to the frozen annotations and derives
every number reported: the frozen metric family, the CORE/STRESS split, exact
paired McNemar tests, and the descriptive breakdowns.

It does not trust the harness. Relevance, silence and appropriate-action are
RECOMPUTED here from the frozen `valid_hints` and the recorded selection, then
compared against the flags GDScript wrote. A disagreement between the two
languages is a failure, not a footnote.

FROZEN DEFINITIONS, reproduced exactly as preregistered:

  RelevantHintRate   (PRIMARY)     relevant delivered hints / all attempted
                                   SILENCE IS ALWAYS A FAILURE, including on
                                   scenarios whose valid_hints is empty.
  AppropriateActionRate (SECONDARY, prospective, new in v4)
                                   (delivered AND selected in valid_hints)
                                   OR (SILENCE AND valid_hints is empty),
                                   over all attempted.
  CorrectSilenceRate (DESCRIPTIVE) SILENCE on valid_hints-empty scenarios /
                                   number of valid_hints-empty scenarios.
                                   N/A when the denominator is zero.
  Coverage                         delivered / attempted
  StateViolationRate               violations / delivered
  RedundantHintRate                redundant / delivered
  RedundantWhenTeachable           redundant-and-teaching / teaching delivered
                                   N/A when no teaching hint was delivered.

CORE is ordinals 1-48 and carries the confirmatory conclusions. STRESS is
ordinals 49-72 and is secondary robustness analysis. They are never merged into
a headline number; the all-72 block exists and is labelled descriptive only.

No composite score is computed and no system is ranked by an invented overall
score.

    python3 tools/compute_heldout_v4_metrics.py
"""

from __future__ import annotations

import hashlib
import json
import sys
from collections import Counter, defaultdict
from math import comb
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HELDOUT = REPO / "docs" / "heldout"

ANNOTATED = HELDOUT / "heldout_v4_annotated.json"
AB_RAW = HELDOUT / "heldout_v4_ab_raw.json"
C_RAW = HELDOUT / "heldout_v4_c_raw.json"

TABLE_OUT = HELDOUT / "heldout_v4_evaluation_table.json"
METRICS_OUT = HELDOUT / "heldout_v4_metrics.json"

FROZEN_ANNOTATED_SHA256 = (
    "cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c"
)

CORE_ORDINALS = range(1, 49)
STRESS_ORDINALS = range(49, 73)
CONDITIONS = ("A", "B", "C")
AMBIGUITY_LEVELS = ("LOW", "MEDIUM", "HIGH")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

def mcnemar_exact(x: list[bool], y: list[bool]) -> dict:
    """Exact two-sided paired McNemar for two binary outcome vectors.

    Only the discordant pairs carry information. Under the null the number of
    discordances favouring one side is Binomial(n_discordant, 0.5), so the exact
    two-sided p is twice the smaller tail, capped at 1. No continuity
    correction and no chi-square approximation: with counts this small the
    approximation is the thing that would need defending.
    """
    if len(x) != len(y):
        raise ValueError("paired vectors must be the same length")
    # b: x right and y wrong. c: x wrong and y right.
    b = sum(1 for a, d in zip(x, y) if a and not d)
    c = sum(1 for a, d in zip(x, y) if d and not a)
    n = b + c
    if n == 0:
        return {
            "b_first_only": 0, "c_second_only": 0, "n_discordant": 0,
            "p_value": None,
            "p_value_report": "N/A (no discordant pairs)",
            "test": "exact binomial (McNemar), two-sided",
        }
    tail = sum(comb(n, k) for k in range(0, min(b, c) + 1)) / (2 ** n)
    p = min(1.0, 2.0 * tail)
    return {
        "b_first_only": b, "c_second_only": c, "n_discordant": n,
        "p_value": p,
        "p_value_report": f"{p:.6f}",
        "test": "exact binomial (McNemar), two-sided",
    }


# ---------------------------------------------------------------------------
# Metric family
# ---------------------------------------------------------------------------

def rate(num: int, den: int) -> dict:
    return {
        "numerator": num,
        "denominator": den,
        "rate": (num / den) if den else None,
        "report": (f"{num}/{den} = {num / den:.4f}" if den
                   else f"N/A (denominator is 0)"),
    }


def metrics_for(rows: list[dict], cond: str) -> dict:
    attempted = len(rows)
    delivered = sum(1 for r in rows if r[cond]["delivered_hint"])
    silent = sum(1 for r in rows if r[cond]["silence"])
    relevant = sum(1 for r in rows if r[cond]["relevant"])
    appropriate = sum(1 for r in rows if r[cond]["appropriate_action"])
    violations = sum(1 for r in rows
                     if r[cond]["delivered_hint"] and r[cond]["state_violation"])
    redundant = sum(1 for r in rows
                    if r[cond]["delivered_hint"] and r[cond]["redundant"])
    teaching = sum(1 for r in rows
                   if r[cond]["delivered_hint"] and r[cond]["teaches_pkm_concept"])
    teaching_redundant = sum(
        1 for r in rows
        if r[cond]["delivered_hint"] and r[cond]["teaches_pkm_concept"]
        and r[cond]["redundant"]
    )

    none_rows = [r for r in rows if r["human_valid_hints_empty"]]
    correct_silence = sum(1 for r in none_rows if r[cond]["silence"])

    return {
        "counts": {
            "attempted": attempted,
            "delivered": delivered,
            "silence": silent,
            "relevant": relevant,
            "appropriate_action": appropriate,
            "state_violations": violations,
            "redundant": redundant,
            "teaching_delivered": teaching,
            "teaching_and_redundant": teaching_redundant,
            "none_scenarios": len(none_rows),
            "silence_on_none_scenarios": correct_silence,
        },
        "PRIMARY_RelevantHintRate": rate(relevant, attempted),
        "SECONDARY_AppropriateActionRate": rate(appropriate, attempted),
        "DESCRIPTIVE_CorrectSilenceRate": rate(correct_silence, len(none_rows)),
        "Coverage": rate(delivered, attempted),
        "StateViolationRate": rate(violations, delivered),
        "RedundantHintRate": rate(redundant, delivered),
        "RedundantWhenTeachable": rate(teaching_redundant, teaching),
        "silence_ordinals": [r["ordinal"] for r in rows if r[cond]["silence"]],
        "irrelevant_ordinals": [r["ordinal"] for r in rows
                                if not r[cond]["relevant"]],
        "state_violation_ordinals": [r["ordinal"] for r in rows
                                     if r[cond]["delivered_hint"]
                                     and r[cond]["state_violation"]],
        "redundant_ordinals": [r["ordinal"] for r in rows
                               if r[cond]["delivered_hint"]
                               and r[cond]["redundant"]],
    }


def block(rows: list[dict], label: str, role: str) -> dict:
    out = {"stratum": label, "role": role, "n": len(rows)}
    for cond in CONDITIONS:
        out[cond] = metrics_for(rows, cond)
    return out


def pairwise(rows: list[dict], field: str, label: str) -> dict:
    out = {"outcome": field, "label": label, "n": len(rows)}
    for first, second in (("A", "B"), ("A", "C"), ("B", "C")):
        x = [bool(r[first][field]) for r in rows]
        y = [bool(r[second][field]) for r in rows]
        result = mcnemar_exact(x, y)
        result["first"] = first
        result["second"] = second
        result["first_successes"] = sum(x)
        result["second_successes"] = sum(y)
        result["b_meaning"] = f"{first} correct, {second} wrong"
        result["c_meaning"] = f"{second} correct, {first} wrong"
        out[f"{first}_vs_{second}"] = result
    return out


# ---------------------------------------------------------------------------
# Join and verification
# ---------------------------------------------------------------------------

def build_table(problems: list[str]) -> tuple[list[dict], dict]:
    annotated = json.loads(ANNOTATED.read_text())
    ab = json.loads(AB_RAW.read_text())
    c = json.loads(C_RAW.read_text())

    actual = sha256_file(ANNOTATED)
    if actual != FROZEN_ANNOTATED_SHA256:
        problems.append(f"annotated artifact is {actual}, frozen at "
                        f"{FROZEN_ANNOTATED_SHA256}")
    for name, doc in (("A/B", ab), ("C", c)):
        if doc["source_artifact_sha256"] != FROZEN_ANNOTATED_SHA256:
            problems.append(f"{name} raw cites a different source artifact")

    if not c.get("complete", False) or c.get("aborted", False):
        problems.append(
            f"Condition C run is not complete: "
            f"{c['scenario_count']}/{c['expected_scenario_count']}, "
            f"aborted={c.get('aborted')}"
        )

    ann_by_id = {s["id"]: s for s in annotated["scenarios"]}
    c_by_id = {r["scenario_id"]: r for r in c["scenarios"]}

    table: list[dict] = []
    for row in ab["scenarios"]:
        sid = row["scenario_id"]
        source = ann_by_id.get(sid)
        c_row = c_by_id.get(sid)
        if source is None:
            problems.append(f"{sid}: not in the frozen annotations")
            continue
        if c_row is None:
            problems.append(f"{sid}: no Condition C result")
            continue
        if c_row["ordinal"] != row["ordinal"]:
            problems.append(f"{sid}: A/B ordinal {row['ordinal']} vs C "
                            f"{c_row['ordinal']}")

        valid = list(source["valid_hints"])
        joined = {
            "ordinal": row["ordinal"],
            "scenario_id": sid,
            "stratum": row["stratum"],
            "stress_bin": row["stress_bin"],
            "progression_bucket": row["progression_bucket"],
            "npc": row["npc"],
            "room": row["room"],
            "stage": row["stage"],
            "evidence_items": row["evidence_items"],
            "story_flags": row["story_flags"],
            "knowledge_items": row["knowledge_items"],
            "pkm_states": source["pkm_states"],
            "hard_eligible_hints": row["hard_eligible_hints"],
            "human_valid_hints": valid,
            "human_valid_hints_empty": not valid,
            "human_ambiguity": source["annotation"]["ambiguity_note"],
        }

        for cond, src in (("A", row["A"]), ("B", row["B"]), ("C", c_row["C"])):
            selected = src["selected_hint_id"]
            silence = selected == ""
            # Recomputed here from the frozen labels, not copied from the
            # harness. The harness's own flags are checked against these below.
            recomputed_relevant = (not silence) and selected in valid
            recomputed_appropriate = (
                recomputed_relevant if not silence else not valid
            )
            if bool(src["relevant"]) != recomputed_relevant:
                problems.append(
                    f"{sid} {cond}: harness relevant={src['relevant']} but "
                    f"recomputation says {recomputed_relevant}")
            if bool(src["silence"]) != silence:
                problems.append(
                    f"{sid} {cond}: harness silence={src['silence']} but "
                    f"selected={selected!r}")
            if bool(src["appropriate_action"]) != recomputed_appropriate:
                problems.append(
                    f"{sid} {cond}: harness appropriate_action disagrees with "
                    f"recomputation")
            if selected and selected not in row["hard_eligible_hints"]:
                problems.append(
                    f"{sid} {cond}: selected {selected} is not hard-eligible")

            joined[cond] = {
                "selected_hint_id": selected,
                "action": "SILENCE" if silence else selected,
                "delivered_hint": not silence,
                "silence": silence,
                "relevant": recomputed_relevant,
                "appropriate_action": recomputed_appropriate,
                "state_violation": bool(src["state_violation"]),
                "state_violation_detail": src.get("state_violation_detail", []),
                "redundant": bool(src["redundant"]),
                "teaches_pkm_concept": bool(src["teaches_pkm_concept"]),
            }

        joined["all_three_agree"] = (
            joined["A"]["action"] == joined["B"]["action"] == joined["C"]["action"]
        )
        joined["disagreement"] = sorted({
            joined["A"]["action"], joined["B"]["action"], joined["C"]["action"]
        })
        table.append(joined)

    if len(table) != 72:
        problems.append(f"joined table has {len(table)} rows, expected 72")

    provenance = {
        "annotated_sha256": actual,
        "ab_raw_sha256": sha256_file(AB_RAW),
        "c_raw_sha256": sha256_file(C_RAW),
        "annotation_fingerprint_sha256":
            annotated["annotation_fingerprint_sha256"],
        "engine_version": ab.get("engine_version", ""),
        "catalogue_order": ab.get("catalogue_order", []),
        "selector_sha256": ab.get("selector_sha256", {}),
        "condition_c_transport_manifest": c.get("transport_manifest", {}),
        "condition_c_complete": c.get("complete", False),
        "condition_c_aborted": c.get("aborted", False),
        "condition_c_resumed": c.get("resumed", False),
    }
    return table, provenance


def main() -> int:
    problems: list[str] = []
    if not C_RAW.exists():
        print(f"missing {C_RAW.relative_to(REPO)} -- run the Condition C "
              f"harness first")
        return 1

    table, provenance = build_table(problems)

    core = [r for r in table if r["ordinal"] in CORE_ORDINALS]
    stress = [r for r in table if r["ordinal"] in STRESS_ORDINALS]
    if len(core) != 48 or len(stress) != 24:
        problems.append(f"strata are {len(core)} CORE and {len(stress)} STRESS, "
                        f"expected 48 and 24")
    for r in core:
        if r["stratum"] != "CORE":
            problems.append(f"{r['scenario_id']}: ordinal in 1-48 but stratum "
                            f"{r['stratum']}")
    for r in stress:
        if r["stratum"] != "STRESS":
            problems.append(f"{r['scenario_id']}: ordinal in 49-72 but stratum "
                            f"{r['stratum']}")

    # Per-NPC and per-ambiguity breakdowns, within CORE and within STRESS.
    def grouped(rows: list[dict], key: str) -> dict:
        buckets: dict[str, list[dict]] = defaultdict(list)
        for r in rows:
            buckets[str(r[key])].append(r)
        return {k: {c: metrics_for(v, c) for c in CONDITIONS}
                for k, v in sorted(buckets.items())}

    # Ambiguity sensitivity. Reported alongside the primary analysis, never
    # instead of it: the frozen protocol does not license excluding ambiguous
    # cases, so CORE-all remains the confirmatory result.
    low = [r for r in core if r["human_ambiguity"] == "LOW"]
    low_med = [r for r in core if r["human_ambiguity"] in ("LOW", "MEDIUM")]
    high_rows = [r for r in table if r["human_ambiguity"] == "HIGH"]

    disagreements = [
        {
            "ordinal": r["ordinal"], "scenario_id": r["scenario_id"],
            "stratum": r["stratum"], "npc": r["npc"],
            "A": r["A"]["action"], "B": r["B"]["action"], "C": r["C"]["action"],
            "human_valid_hints": r["human_valid_hints"],
            "human_ambiguity": r["human_ambiguity"],
            "relevant": {c: r[c]["relevant"] for c in CONDITIONS},
        }
        for r in table if not r["all_three_agree"]
    ]

    metrics = {
        "protocol_version": "heldout-v4",
        "conditions_run": list(CONDITIONS),
        "condition_c_run": True,
        "metric_definitions": {
            "PRIMARY_RelevantHintRate":
                "relevant delivered hints / all attempted scenarios; SILENCE is "
                "ALWAYS a failure, including where valid_hints is empty",
            "SECONDARY_AppropriateActionRate":
                "(delivered AND selected in valid_hints) OR (SILENCE AND "
                "valid_hints empty), over all attempted; prospective, new in v4",
            "DESCRIPTIVE_CorrectSilenceRate":
                "SILENCE on valid_hints-empty scenarios / number of such "
                "scenarios; N/A when the denominator is zero",
            "Coverage": "delivered / attempted",
            "StateViolationRate": "violations / delivered",
            "RedundantHintRate": "redundant / delivered",
            "RedundantWhenTeachable":
                "redundant-and-teaching / teaching delivered; N/A when zero",
            "redundancy_note":
                "Human relevance and non-redundancy are different properties. A "
                "hint can be human-labelled relevant and still be counted "
                "redundant when it teaches a concept already DEMONSTRATED. No "
                "human label was rewritten to resolve that difference.",
            "composite_score": "none computed; systems are not ranked by an "
                               "invented overall score",
        },
        "strata": {
            "CORE": {"ordinals": "1-48", "role": "PRIMARY CONFIRMATORY"},
            "STRESS": {"ordinals": "49-72", "role":
                       "SECONDARY robustness / boundary analysis"},
            "note": "CORE and STRESS are never merged into a headline result",
        },
        "provenance": provenance,
        "CORE": block(core, "CORE", "PRIMARY CONFIRMATORY"),
        "STRESS": block(stress, "STRESS", "SECONDARY robustness / boundary"),
        "ALL_72_DESCRIPTIVE_ONLY": block(
            table, "ALL", "DESCRIPTIVE ONLY -- not a confirmatory result"),
        "CORE_mcnemar_PRIMARY_RelevantHintRate":
            pairwise(core, "relevant", "PRIMARY confirmatory"),
        "CORE_mcnemar_SECONDARY_AppropriateActionRate":
            pairwise(core, "appropriate_action", "SECONDARY"),
        "STRESS_mcnemar_RelevantHintRate_secondary":
            pairwise(stress, "relevant",
                     "SECONDARY -- STRESS is not confirmatory"),
        "by_npc": {
            "CORE": grouped(core, "npc"),
            "STRESS": grouped(stress, "npc"),
        },
        "by_ambiguity": {
            "CORE": grouped(core, "human_ambiguity"),
            "ALL": grouped(table, "human_ambiguity"),
            "frozen_distribution": dict(
                Counter(r["human_ambiguity"] for r in table)),
        },
        "ambiguity_sensitivity_CORE": {
            "note": "Sensitivity only. The confirmatory CORE analysis uses all "
                    "48 frozen labels; ambiguous cases are NOT excluded.",
            "LOW_only": {"n": len(low),
                         **{c: metrics_for(low, c) for c in CONDITIONS}}
            if low else {"n": 0},
            "LOW_plus_MEDIUM": {"n": len(low_med),
                                **{c: metrics_for(low_med, c) for c in CONDITIONS}}
            if low_med else {"n": 0},
            "HIGH_cases_listed_separately": [
                {"ordinal": r["ordinal"], "scenario_id": r["scenario_id"],
                 "stratum": r["stratum"], "npc": r["npc"],
                 "human_valid_hints": r["human_valid_hints"],
                 "A": r["A"]["action"], "B": r["B"]["action"],
                 "C": r["C"]["action"],
                 "relevant": {c: r[c]["relevant"] for c in CONDITIONS}}
                for r in high_rows
            ],
        },
        "none_scenarios": {
            "ordinals": [r["ordinal"] for r in table
                         if r["human_valid_hints_empty"]],
            "count": sum(1 for r in table if r["human_valid_hints_empty"]),
            "note": "NONE is a real annotation, not a missing one. Under the "
                    "frozen PRIMARY metric a SILENCE here is still a relevance "
                    "failure; under the SECONDARY metric it is correct. The "
                    "distinction is intentional.",
            "per_condition": {
                c: {
                    "silence_on_none": [
                        r["ordinal"] for r in table
                        if r["human_valid_hints_empty"] and r[c]["silence"]],
                    "delivered_on_none": [
                        r["ordinal"] for r in table
                        if r["human_valid_hints_empty"] and r[c]["delivered_hint"]],
                } for c in CONDITIONS
            },
        },
        "disagreements": disagreements,
        "disagreement_count": len(disagreements),
    }

    TABLE_OUT.write_text(json.dumps(
        {"protocol_version": "heldout-v4", "scenario_count": len(table),
         "provenance": provenance, "scenarios": table},
        indent=2, sort_keys=True) + "\n")
    METRICS_OUT.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")

    # ----------------------------------------------------------------- report
    print("heldout-v4 evaluation metrics\n")
    for name in ("CORE", "STRESS", "ALL_72_DESCRIPTIVE_ONLY"):
        b = metrics[name]
        print(f"{name}  (n={b['n']}, {b['role']})")
        for key in ("PRIMARY_RelevantHintRate", "SECONDARY_AppropriateActionRate",
                    "DESCRIPTIVE_CorrectSilenceRate", "Coverage",
                    "StateViolationRate", "RedundantHintRate",
                    "RedundantWhenTeachable"):
            cells = "   ".join(
                f"{c} {b[c][key]['report']:>18s}" for c in CONDITIONS)
            print(f"  {key:34s} {cells}")
        print()

    print("CORE exact paired McNemar -- PRIMARY RelevantHintRate")
    for pair in ("A_vs_B", "A_vs_C", "B_vs_C"):
        m = metrics["CORE_mcnemar_PRIMARY_RelevantHintRate"][pair]
        print(f"  {pair:8s} b={m['b_first_only']:2d} ({m['b_meaning']})  "
              f"c={m['c_second_only']:2d} ({m['c_meaning']})  "
              f"n_disc={m['n_discordant']:2d}  p={m['p_value_report']}")
    print("\nCORE exact paired McNemar -- SECONDARY AppropriateActionRate")
    for pair in ("A_vs_B", "A_vs_C", "B_vs_C"):
        m = metrics["CORE_mcnemar_SECONDARY_AppropriateActionRate"][pair]
        print(f"  {pair:8s} b={m['b_first_only']:2d}  c={m['c_second_only']:2d}  "
              f"n_disc={m['n_discordant']:2d}  p={m['p_value_report']}")

    print(f"\nA/B/C disagreements: {len(disagreements)}")
    print(f"wrote {TABLE_OUT.relative_to(REPO)}")
    print(f"wrote {METRICS_OUT.relative_to(REPO)}")

    if problems:
        print(f"\ncompute_heldout_v4_metrics: FAIL ({len(problems)})")
        for p in problems:
            print("  - " + p)
        return 1
    print("\ncompute_heldout_v4_metrics: PASS -- harness flags and independent "
          "recomputation agree on all 72 scenarios x 3 conditions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
