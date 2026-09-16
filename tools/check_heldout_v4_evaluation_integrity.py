#!/usr/bin/env python3
"""Independent integrity check for the frozen heldout-v4 A/B/C evaluation.

`compute_heldout_v4_metrics.py` derived the numbers. This program re-derives
them from the joined table without importing that module or reusing its
constants, and additionally audits the things a metric cannot see: that the
one-shot Condition C run really was one shot, that the frozen inputs did not
move while the evaluation ran, and that no selector output was written back into
the ground truth.

  1  frozen inputs still hash to their freeze values
  2  the joined table is 72 rows, ordinals 1-72, CORE 1-48 and STRESS 49-72
  3  human labels in the table are the frozen labels, scenario by scenario
  4  every metric in the metrics file recomputes from the table
  5  every McNemar result recomputes from the table
  6  Condition C ran exactly once per scenario -- the append-only log holds 72
     entries, no scenario id twice, and each log entry agrees with the raw file
  7  no condition selected a hint outside its own hard-eligible set
  8  the annotated artifact carries no evaluation output

    python3 tools/check_heldout_v4_evaluation_integrity.py
    python3 tools/check_heldout_v4_evaluation_integrity.py --fault-test
"""

from __future__ import annotations

import copy
import hashlib
import json
import sys
from collections import Counter
from math import comb
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HELDOUT = REPO / "docs" / "heldout"

ANNOTATED = HELDOUT / "heldout_v4_annotated.json"
AB_RAW = HELDOUT / "heldout_v4_ab_raw.json"
C_RAW = HELDOUT / "heldout_v4_c_raw.json"
C_LOG = HELDOUT / "heldout_v4_c_run.jsonl"
TABLE = HELDOUT / "heldout_v4_evaluation_table.json"
METRICS = HELDOUT / "heldout_v4_metrics.json"

## Restated independently of every other tool: these are the values the freeze
## commits published, and the point is to compare belief against them.
FROZEN = {
    "docs/heldout/heldout_v4_annotated.json":
        "cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c",
    "docs/heldout/heldout_v4_scenarios.json":
        "1bb1535f64168fe4c5e6fe767aabe841761d5bc248a2e17234d29942c3a0a23d",
    "scripts/adaptive_hint_selector.gd":
        "c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
    "scripts/adaptive_hint_data.gd":
        "a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
    "scripts/player_knowledge_model.gd":
        "55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
    "scripts/condition_c_selector.gd":
        "f2cab2d0d3c9bb204724bd9ffe94301744fc81eff77bf0c3c6752279208f7e2d",
    "scripts/condition_c_client.gd":
        "d9071a9a8321f777a05c4c3c309f7b2ab244d90f74a55ec8d08f1a586bb5b107",
    "prompts/condition_c_selector_v1.txt":
        "c4848c52329d625efef4b4cd2b237787d02c5e2e1e015cc195aa6ff3976a9d93",
    "config/condition_c_model_v2.json":
        "9889a63f56b7d0e8416217aed106948274ed73558039201b32b81380c256be1e",
    "tools/condition_c_claude_invoke.sh":
        "c8ab07a1bec297adab89fc159273a766f1987efad73121cfe0f2d6b48af7229e",
}

CONDS = ("A", "B", "C")

FORBIDDEN_IN_GROUND_TRUTH = (
    "condition_a", "condition_b", "condition_c", "selected_hint",
    "selected_hint_id", "relevance", "model_output", "selector_output",
    "appropriate_action", "mcnemar",
)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_two_sided(b: int, c: int):
    """Same statistic as the metrics tool, written from the definition here."""
    n = b + c
    if n == 0:
        return None
    lo = min(b, c)
    tail = sum(comb(n, k) for k in range(lo + 1)) / float(2 ** n)
    return min(1.0, 2.0 * tail)


def walk_keys(node):
    if isinstance(node, dict):
        for k, v in node.items():
            yield k
            yield from walk_keys(v)
    elif isinstance(node, list):
        for item in node:
            yield from walk_keys(item)


def check_frozen_inputs(problems: list[str]) -> dict:
    """1 -- nothing the evaluation depended on moved."""
    seen = {}
    for rel, expected in FROZEN.items():
        path = REPO / rel
        if not path.exists():
            problems.append(f"frozen input missing: {rel}")
            continue
        actual = sha256_file(path)
        seen[rel] = actual
        if actual != expected:
            problems.append(f"{rel} is {actual}, frozen at {expected}")
    return seen


def check_table(table: list[dict], problems: list[str]) -> None:
    """2 and 3 -- shape, strata, and labels equal to the frozen annotations."""
    if len(table) != 72:
        problems.append(f"table has {len(table)} rows, expected 72")
    if [r["ordinal"] for r in table] != list(range(1, len(table) + 1)):
        problems.append("table ordinals are not 1..N in order")

    annotated = json.loads(ANNOTATED.read_text())
    by_id = {s["id"]: s for s in annotated["scenarios"]}
    for r in table:
        source = by_id.get(r["scenario_id"])
        if source is None:
            problems.append(f"{r['scenario_id']}: not a frozen scenario")
            continue
        if list(r["human_valid_hints"]) != list(source["valid_hints"]):
            problems.append(f"{r['scenario_id']}: valid_hints differ from frozen")
        if r["human_ambiguity"] != source["annotation"]["ambiguity_note"]:
            problems.append(f"{r['scenario_id']}: ambiguity differs from frozen")
        if r["stratum"] != source["stratum"]:
            problems.append(f"{r['scenario_id']}: stratum differs from frozen")
        expected_stratum = "CORE" if r["ordinal"] <= 48 else "STRESS"
        if r["stratum"] != expected_stratum:
            problems.append(
                f"{r['scenario_id']}: ordinal {r['ordinal']} implies "
                f"{expected_stratum} but stratum is {r['stratum']}")
        # 7 -- a selection must come from that scenario's hard-eligible set.
        for cond in CONDS:
            sel = r[cond]["selected_hint_id"]
            if sel and sel not in r["hard_eligible_hints"]:
                problems.append(
                    f"{r['scenario_id']} {cond}: selected {sel}, not hard-eligible")


def recompute_block(rows: list[dict], cond: str) -> dict:
    n = len(rows)
    delivered = [r for r in rows if r[cond]["selected_hint_id"] != ""]
    silent = [r for r in rows if r[cond]["selected_hint_id"] == ""]
    relevant = [r for r in delivered
                if r[cond]["selected_hint_id"] in r["human_valid_hints"]]
    appropriate = len(relevant) + sum(
        1 for r in silent if not r["human_valid_hints"])
    none_rows = [r for r in rows if not r["human_valid_hints"]]
    correct_silence = sum(1 for r in none_rows
                          if r[cond]["selected_hint_id"] == "")
    viol = [r for r in delivered if r[cond]["state_violation"]]
    redund = [r for r in delivered if r[cond]["redundant"]]
    teach = [r for r in delivered if r[cond]["teaches_pkm_concept"]]
    teach_red = [r for r in teach if r[cond]["redundant"]]
    return {
        "PRIMARY_RelevantHintRate": (len(relevant), n),
        "SECONDARY_AppropriateActionRate": (appropriate, n),
        "DESCRIPTIVE_CorrectSilenceRate": (correct_silence, len(none_rows)),
        "Coverage": (len(delivered), n),
        "StateViolationRate": (len(viol), len(delivered)),
        "RedundantHintRate": (len(redund), len(delivered)),
        "RedundantWhenTeachable": (len(teach_red), len(teach)),
    }


def check_metrics(table: list[dict], metrics: dict, problems: list[str]) -> None:
    """4 -- every published metric recomputes from the table."""
    strata = {
        "CORE": [r for r in table if r["ordinal"] <= 48],
        "STRESS": [r for r in table if r["ordinal"] > 48],
        "ALL_72_DESCRIPTIVE_ONLY": table,
    }
    for name, rows in strata.items():
        published = metrics.get(name, {})
        if published.get("n") != len(rows):
            problems.append(f"{name}: published n={published.get('n')}, "
                            f"table has {len(rows)}")
        for cond in CONDS:
            mine = recompute_block(rows, cond)
            for key, (num, den) in mine.items():
                got = published.get(cond, {}).get(key, {})
                if got.get("numerator") != num or got.get("denominator") != den:
                    problems.append(
                        f"{name} {cond} {key}: published "
                        f"{got.get('numerator')}/{got.get('denominator')}, "
                        f"recomputed {num}/{den}")


def check_mcnemar(table: list[dict], metrics: dict, problems: list[str]) -> None:
    """5 -- every published test statistic recomputes from the table."""
    core = [r for r in table if r["ordinal"] <= 48]
    stress = [r for r in table if r["ordinal"] > 48]
    jobs = [
        ("CORE_mcnemar_PRIMARY_RelevantHintRate", core, "relevant"),
        ("CORE_mcnemar_SECONDARY_AppropriateActionRate", core,
         "appropriate_action"),
        ("STRESS_mcnemar_RelevantHintRate_secondary", stress, "relevant"),
    ]
    for block_name, rows, field in jobs:
        published = metrics.get(block_name, {})
        for first, second in (("A", "B"), ("A", "C"), ("B", "C")):
            b = sum(1 for r in rows if r[first][field] and not r[second][field])
            c = sum(1 for r in rows if r[second][field] and not r[first][field])
            p = exact_two_sided(b, c)
            got = published.get(f"{first}_vs_{second}", {})
            if got.get("b_first_only") != b or got.get("c_second_only") != c:
                problems.append(
                    f"{block_name} {first}v{second}: published b/c "
                    f"{got.get('b_first_only')}/{got.get('c_second_only')}, "
                    f"recomputed {b}/{c}")
            gp = got.get("p_value")
            if p is None:
                if gp is not None:
                    problems.append(f"{block_name} {first}v{second}: published "
                                    f"a p-value with no discordant pairs")
            elif gp is None or abs(float(gp) - p) > 1e-12:
                problems.append(
                    f"{block_name} {first}v{second}: published p={gp}, "
                    f"recomputed p={p}")


def check_one_shot(table: list[dict], problems: list[str]) -> dict:
    """6 -- Condition C ran exactly once per scenario.

    The append-only log is the audit trail: it is written before the next
    scenario starts and is never rewritten, so a scenario that was sampled twice
    would appear twice here even if the summary file showed one row.
    """
    if not C_LOG.exists():
        problems.append("the Condition C run log is missing")
        return {}
    entries = [json.loads(line) for line in C_LOG.read_text().splitlines()
               if line.strip()]
    ids = [e["scenario_id"] for e in entries]
    repeats = {k: v for k, v in Counter(ids).items() if v > 1}
    if repeats:
        problems.append(f"Condition C sampled scenarios more than once: {repeats}")
    if len(entries) != 72:
        problems.append(f"the C log holds {len(entries)} entries, expected 72")

    c_raw = json.loads(C_RAW.read_text())
    if c_raw.get("aborted"):
        problems.append(f"the C run aborted: {c_raw.get('abort_reason')}")
    if not c_raw.get("complete"):
        problems.append("the C run did not complete")
    raw_by_id = {r["scenario_id"]: r for r in c_raw["scenarios"]}
    for entry in entries:
        raw = raw_by_id.get(entry["scenario_id"])
        if raw is None:
            problems.append(f"{entry['scenario_id']}: in the log, not in the raw file")
            continue
        if raw["C"]["selected_hint_id"] != entry["C"]["selected_hint_id"]:
            problems.append(
                f"{entry['scenario_id']}: the log and the raw file disagree "
                f"about what C selected")

    table_by_id = {r["scenario_id"]: r for r in table}
    for entry in entries:
        row = table_by_id.get(entry["scenario_id"])
        if row and row["C"]["selected_hint_id"] != entry["C"]["selected_hint_id"]:
            problems.append(
                f"{entry['scenario_id']}: the joined table disagrees with the "
                f"C run log")

    attempts = sum(len(e["record"].get("attempts", [])) for e in entries)
    schema_retries = sum(int(e["record"].get("retry_count", 0)) for e in entries)
    transport_failures = sum(
        1 for e in entries for a in e["record"].get("attempts", [])
        if "transport_error" in a)
    return {
        "log_entries": len(entries),
        "unique_scenarios": len(set(ids)),
        "duplicate_scenarios": repeats,
        "total_model_attempts": attempts,
        "total_schema_retries": schema_retries,
        "transport_failures": transport_failures,
        "subprocess_invocations": sum(
            int(e.get("transport_invocations", 0)) for e in entries),
        "silence_count": sum(1 for e in entries if e["C"]["silence"]),
        "resolved_models": dict(Counter(
            e.get("resolved_model", "") for e in entries)),
    }


def check_ground_truth_clean(problems: list[str]) -> None:
    """8 -- the evaluation wrote nothing back into the labels."""
    doc = json.loads(ANNOTATED.read_text())
    if doc.get("selector_was_run") is not False:
        problems.append("the annotated artifact now claims selector_was_run")
    present = sorted({k for k in walk_keys(doc)
                      if k in FORBIDDEN_IN_GROUND_TRUTH})
    if present:
        problems.append(f"evaluation output leaked into the labels: {present}")


def faults():
    """Each mutation must be caught by the check it is paired with."""

    def flip_a_selection(table, metrics):
        table[0]["A"]["selected_hint_id"] = "h_butler_stain"
        table[0]["A"]["relevant"] = True

    def relabel(table, metrics):
        table[5]["human_valid_hints"] = ["h_butler_stain"]

    def wrong_stratum(table, metrics):
        table[50]["stratum"] = "CORE"

    def inflate_metric(table, metrics):
        metrics["CORE"]["C"]["PRIMARY_RelevantHintRate"]["numerator"] = 48

    def inflate_coverage(table, metrics):
        metrics["STRESS"]["B"]["Coverage"]["denominator"] = 999

    def forge_p(table, metrics):
        metrics["CORE_mcnemar_PRIMARY_RelevantHintRate"]["A_vs_C"]["p_value"] = 0.0001

    def forge_discordant(table, metrics):
        metrics["CORE_mcnemar_PRIMARY_RelevantHintRate"]["B_vs_C"]["b_first_only"] = 40

    def ineligible_pick(table, metrics):
        table[3]["C"]["selected_hint_id"] = "h_gardener_pollen"

    def drop_row(table, metrics):
        table.pop()

    return [
        ("a recorded selection is altered", check_metrics, flip_a_selection),
        ("a human label is rewritten", check_table, relabel),
        ("a stratum is reassigned", check_table, wrong_stratum),
        ("a CORE metric is inflated", check_metrics, inflate_metric),
        ("a denominator is inflated", check_metrics, inflate_coverage),
        ("a p-value is forged", check_mcnemar, forge_p),
        ("a discordant count is forged", check_mcnemar, forge_discordant),
        ("a pick outside hard eligibility", check_table, ineligible_pick),
        ("a scenario is dropped", check_table, drop_row),
    ]


def run_fault_test() -> int:
    table0 = json.loads(TABLE.read_text())["scenarios"]
    metrics0 = json.loads(METRICS.read_text())
    failures = []
    print("fault injection -- each mutation must be caught\n")
    for name, check, mutate in faults():
        table = copy.deepcopy(table0)
        metrics = copy.deepcopy(metrics0)
        mutate(table, metrics)
        problems: list[str] = []
        try:
            if check is check_table:
                check(table, problems)
            else:
                check(table, metrics, problems)
        except Exception as exc:
            problems.append(f"raised {type(exc).__name__}: {exc}")
        caught = bool(problems)
        print(f"  {'caught ' if caught else 'MISSED '} {name}")
        if not caught:
            failures.append(name)
    if failures:
        print(f"\nfault test: FAIL -- {len(failures)} not caught")
        return 1
    print(f"\nfault test: PASS -- {len(faults())}/{len(faults())} caught")
    return 0


def main() -> int:
    if "--fault-test" in sys.argv:
        return run_fault_test()

    for path in (TABLE, METRICS, C_RAW, AB_RAW):
        if not path.exists():
            print(f"missing {path.relative_to(REPO)}")
            return 1

    problems: list[str] = []
    hashes = check_frozen_inputs(problems)
    table = json.loads(TABLE.read_text())["scenarios"]
    metrics = json.loads(METRICS.read_text())

    check_table(table, problems)
    check_metrics(table, metrics, problems)
    check_mcnemar(table, metrics, problems)
    audit = check_one_shot(table, problems)
    check_ground_truth_clean(problems)

    print("heldout-v4 evaluation integrity\n")
    print(f"  frozen inputs verified   {len(hashes)}/{len(FROZEN)}")
    print(f"  table rows               {len(table)}")
    print(f"  CORE / STRESS            "
          f"{sum(1 for r in table if r['ordinal'] <= 48)} / "
          f"{sum(1 for r in table if r['ordinal'] > 48)}")
    if audit:
        print(f"\n  Condition C one-shot audit")
        for key in ("log_entries", "unique_scenarios", "duplicate_scenarios",
                    "subprocess_invocations", "total_model_attempts",
                    "total_schema_retries", "transport_failures",
                    "silence_count", "resolved_models"):
            print(f"    {key:26s} {audit[key]}")
    print(f"\n  output artifact sha256")
    for path in (TABLE, METRICS, AB_RAW, C_RAW, C_LOG):
        if path.exists():
            print(f"    {sha256_file(path)}  {path.relative_to(REPO)}")

    if problems:
        print(f"\ncheck_heldout_v4_evaluation_integrity: FAIL ({len(problems)})")
        for p in problems:
            print("  - " + p)
        return 1
    print("\ncheck_heldout_v4_evaluation_integrity: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
