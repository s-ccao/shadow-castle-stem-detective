#!/usr/bin/env python3
"""Write the heldout-v4 evaluation freeze manifest.

The evaluation produced five artifacts. This records what they are, what they
hash to, what produced them, and what a reader must not conclude from them --
so the freeze can be audited later without re-reading the whole run.

Regenerate with:
    python3 tools/write_heldout_v4_evaluation_manifest.py

It must be byte-stable: run twice on unchanged inputs, it writes the same file.
Nothing here is computed from the results, so the manifest cannot drift with
them; the numbers live in heldout_v4_metrics.json and are checked by
check_heldout_v4_evaluation_integrity.py.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "docs" / "heldout_v4_evaluation_manifest.json"

OUTPUTS = [
    ("conditions_a_and_b_raw", "docs/heldout/heldout_v4_ab_raw.json",
     "Per-scenario Condition A and Condition B output, with the decision trace "
     "reconstructed and verified against what the frozen selectors returned."),
    ("condition_c_raw", "docs/heldout/heldout_v4_c_raw.json",
     "Per-scenario Condition C output plus the transport manifest. One-shot: "
     "every row is a single live model call that is never repeated."),
    ("condition_c_run_log", "docs/heldout/heldout_v4_c_run.jsonl",
     "Append-only, one line per scenario, written before the next scenario "
     "started. The audit trail for one-shot execution: a resampled scenario "
     "would appear here twice."),
    ("joined_evaluation_table", "docs/heldout/heldout_v4_evaluation_table.json",
     "A, B and C joined per scenario against the frozen human labels, with "
     "enough metadata to recompute every metric independently."),
    ("metric_summary", "docs/heldout/heldout_v4_metrics.json",
     "CORE, STRESS and all-72 descriptive summaries, exact paired McNemar "
     "results, and the per-NPC and ambiguity breakdowns."),
]

INPUTS = [
    ("annotated_holdout", "docs/heldout/heldout_v4_annotated.json"),
    ("pre_annotation_scenarios", "docs/heldout/heldout_v4_scenarios.json"),
    ("condition_ab_selector", "scripts/adaptive_hint_selector.gd"),
    ("shared_catalogue", "scripts/adaptive_hint_data.gd"),
    ("pkm_implementation", "scripts/player_knowledge_model.gd"),
    ("condition_c_selector", "scripts/condition_c_selector.gd"),
    ("condition_c_client", "scripts/condition_c_client.gd"),
    ("condition_c_prompt", "prompts/condition_c_selector_v1.txt"),
    ("condition_c_config", "config/condition_c_model_v2.json"),
    ("condition_c_wrapper", "tools/condition_c_claude_invoke.sh"),
]

PRODUCERS = [
    ("tools/run_heldout_v4_ab_evaluation.gd", "Conditions A and B"),
    ("tools/run_heldout_v4_c_evaluation.gd", "Condition C, one shot"),
    ("tools/compute_heldout_v4_metrics.py", "all metrics and McNemar tests"),
    ("tools/check_heldout_v4_evaluation_integrity.py",
     "independent recomputation and fault suite"),
]


def sha256(rel: str) -> str:
    return hashlib.sha256((REPO / rel).read_bytes()).hexdigest()


def main() -> int:
    manifest = {
        "freeze": "heldout-v4-evaluation",
        "evaluated_freeze": "heldout-v4-post-annotation",
        "run": "first and only heldout-v4 evaluation",
        "conditions": {
            "A": "A-4 Evidence-depth Static Baseline (frozen)",
            "B": "PKM-aware deterministic selector (frozen)",
            "C": "LLM + PKM selector, condition-c-v1 (frozen)",
        },
        "selector_logic_changed": False,
        "human_labels_changed": False,
        "strata": {
            "CORE": "ordinals 1-48, PRIMARY CONFIRMATORY",
            "STRESS": "ordinals 49-72, secondary robustness and boundary "
                      "analysis",
            "note": "CORE and STRESS are not merged into a headline result. "
                    "The all-72 block is descriptive only.",
        },
        "primary_metric": "RelevantHintRate = relevant delivered hints / all "
                          "attempted scenarios. SILENCE is always a failure, "
                          "including where valid_hints is empty.",
        "secondary_metric": "AppropriateActionRate, prospective for v4. Not "
                            "applied retrospectively to v3.",
        "composite_score": "none. Systems are not ranked by an invented "
                           "overall score.",
        "redundancy_note": "Human relevance and non-redundancy are separate. A "
                           "hint can be labelled relevant by the annotator and "
                           "still count as redundant where it teaches a "
                           "concept already DEMONSTRATED. Human labels were "
                           "not rewritten to remove that tension.",
        "producers": [{"path": p, "produces": what} for p, what in PRODUCERS],
        "output_artifacts": {
            key: {"path": rel, "sha256": sha256(rel), "note": note}
            for key, rel, note in OUTPUTS
        },
        "frozen_inputs": {
            key: {"path": rel, "sha256": sha256(rel)} for key, rel in INPUTS
        },
        "limitations": [
            "CORE conclusions are confirmatory; STRESS is secondary robustness "
            "and boundary analysis.",
            "Gardener and Mechanic interaction history is not represented in "
            "the state model. Scenarios 58 and 60 are HIGH ambiguity for this "
            "reason.",
            "The v4 checker allowlist amendment occurred before evaluation and "
            "changed no frozen scenario selection, label, selector or "
            "Condition C behaviour.",
            "The annotator note on Scenarios 67-70 contains a descriptive "
            "imprecision: circuit_fault_isolation is LEARNING at 69 and 70, "
            "not DEMONSTRATED. Frozen scenario state and labels are "
            "authoritative.",
            "Scenario 72's final annotation was an assistant-proposed "
            "adjudication following the researcher's established rule and was "
            "accepted into the frozen set. Not all 72 labels originated "
            "independently with the researcher.",
            "v3 outcomes were not used to alter v4 evaluation or "
            "interpretation.",
            "Condition C output is not deterministic and is not claimed to be. "
            "Sampling parameters are not controllable through this transport, "
            "so re-running would not be expected to reproduce it exactly.",
            "config/condition_c_model_v2.json declares "
            "transport_retry.backoff_seconds but the frozen selector counts "
            "transport retries without sleeping. The delay was applied by a "
            "composition wrapper in the runner, changing no retry count, "
            "budget or abort condition. Recorded in the C transport manifest.",
        ],
    }
    OUT.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"wrote {OUT.relative_to(REPO)}")
    print(f"  {len(manifest['output_artifacts'])} output artifacts hashed")
    print(f"  {len(manifest['frozen_inputs'])} frozen inputs hashed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
