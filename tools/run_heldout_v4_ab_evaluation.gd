extends SceneTree

## Conditions A and B over the annotated held-out v4 set.
##
## Same harness shape as `run_heldout_v3_ab_evaluation.gd`, pointed at the v4
## freeze. A and B are called exactly as frozen and nothing about them is
## changed; their sources hash to the same values they had for v3, so the two
## runs measure the same two selectors.
##
##   * AdaptiveHintSelector.select_condition_a   -- Condition A-4
##   * AdaptiveHintSelector.select_adaptive      -- Condition B
##   * AdaptiveHintData.state_violations         -- hard prerequisites
##   * AdaptiveHintSelector.is_redundant         -- PKM redundancy
##   * AdaptiveHintSelector.teaches_pkm_concept  -- RedundantWhenTeachable denominator
##
## `select_static` is deliberately NOT called: the selector's own docstring marks
## it superseded dead-code replication and says it is not Condition A.
##
## The decision trace is RECONSTRUCTED rather than reported by the selector, then
## checked against what the selector actually returned. A trace that disagrees
## with the real output aborts the run.
##
## This program writes RAW PER-SCENARIO ROWS ONLY. Every metric, every stratum
## split and every statistical test is computed separately, in Python, from these
## rows -- the harness agreeing with itself would prove nothing. The one thing it
## does aggregate is a small count block, kept purely so the two languages can be
## compared against each other.
##
## Run:
##   godot --headless --path . --script tools/run_heldout_v4_ab_evaluation.gd

const Selector := preload("res://scripts/adaptive_hint_selector.gd")
const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")

const ANNOTATED := "res://docs/heldout/heldout_v4_annotated.json"
const RAW_OUT := "res://docs/heldout/heldout_v4_ab_raw.json"

const EXPECTED_COUNT := 72

## Frozen at heldout-v4-post-annotation. The run aborts if any of these moved, so
## a result can never be attributed to inputs that changed underneath it.
const EXPECTED_SHA := {
	"res://docs/heldout/heldout_v4_annotated.json":
		"cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c",
	"res://docs/heldout/heldout_v4_scenarios.json":
		"1bb1535f64168fe4c5e6fe767aabe841761d5bc248a2e17234d29942c3a0a23d",
	"res://scripts/adaptive_hint_selector.gd":
		"c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
	"res://scripts/adaptive_hint_data.gd":
		"a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
	"res://scripts/player_knowledge_model.gd":
		"55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


## `Data.state_violations` tests one field more than Condition B's eligibility
## filter does: `requires_concept`. The two predicates coincide only while no
## hint declares one. Assert that rather than assume it.
func _assert_eligibility_predicates_agree() -> void:
	var catalogue: Dictionary = Data.all_hints()
	if catalogue.size() != 11:
		failures.append("expected the shared 11-hint catalogue, found %d"
			% catalogue.size())
	for hint_id: String in catalogue:
		var requires: Array = (catalogue[hint_id] as Dictionary).get(
			"requires_concept", []
		)
		if not requires.is_empty():
			failures.append(
				"%s declares requires_concept %s, which state_violations checks "
				% [hint_id, str(requires)]
				+ "but Condition B's eligibility filter does not"
			)


func _hard_eligible(npc: String, state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var catalogue: Dictionary = Data.all_hints()
	for hint_id: String in catalogue:
		if str((catalogue[hint_id] as Dictionary).get("npc", "")) != npc:
			continue
		var problems: Array = Data.state_violations(
			hint_id,
			state.get("knowledge_items", []),
			state.get("story_flags", []),
			state.get("evidence_items", [])
		)
		if problems.is_empty():
			out.append(hint_id)
	return out


## Reconstructs Condition A-4's tier decision. Checked against the real call.
func _trace_a(npc: String, state: Dictionary) -> Dictionary:
	var evidence: Array = state.get("evidence_items", [])
	var own := str(Selector.OWN_EVIDENCE.get(npc, ""))
	if evidence.has(own):
		return {"tier": 1, "why": "holds own major evidence '%s'" % own}
	for evidence_id: String in Selector.MAJOR_EVIDENCE:
		if evidence.has(evidence_id):
			return {
				"tier": 2,
				"why": "own evidence '%s' absent; holds other major evidence '%s'"
					% [own, evidence_id],
			}
	return {"tier": 3, "why": "holds none of the three major evidence items"}


## Reconstructs Condition B's rule path. Checked against the real call.
func _trace_b(npc: String, state: Dictionary, eligible: Array[String]) -> Dictionary:
	var knowledge: Array = state.get("knowledge_items", [])
	var flags: Array = state.get("story_flags", [])
	var evidence: Array = state.get("evidence_items", [])
	var fallback := Selector.select_condition_a(npc, state)
	var catalogue: Dictionary = Data.all_hints()

	for hint_id: String in eligible:
		var prefs: Array = (catalogue[hint_id] as Dictionary).get(
			"preferred_when_demonstrated", []
		)
		if prefs.is_empty():
			continue
		var all_demonstrated := true
		for concept_id: String in prefs:
			if not PKM.is_demonstrated_in(concept_id, knowledge, flags, evidence):
				all_demonstrated = false
				break
		if all_demonstrated:
			return {
				"rule": 2,
				"why": "soft preference satisfied: %s is preferred when %s DEMONSTRATED"
					% [hint_id, str(prefs)],
				"predicted": hint_id,
			}

	if Selector.is_redundant(fallback, state):
		for hint_id: String in eligible:
			if hint_id != fallback and not Selector.is_redundant(hint_id, state):
				return {
					"rule": 3,
					"why": "A-4 fallback %s is redundant; first eligible "
						% fallback + "non-redundant alternative in catalogue order",
					"predicted": hint_id,
				}

	return {
		"rule": 4,
		"why": "no soft preference satisfied and A-4 fallback is not redundant",
		"predicted": fallback,
	}


func _pkm_snapshot(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for concept_id: String in PKM.CONCEPTS:
		out[concept_id] = PKM.state_name(PKM.state_in(
			concept_id,
			state.get("knowledge_items", []),
			state.get("story_flags", []),
			state.get("evidence_items", [])
		))
	return out


func _run() -> void:
	for path: String in EXPECTED_SHA:
		var actual := FileAccess.get_sha256(path)
		if actual != str(EXPECTED_SHA[path]):
			failures.append("%s hashes to %s, expected %s"
				% [path, actual, EXPECTED_SHA[path]])
	if not failures.is_empty():
		_bail("integrity gate")
		return

	var payload: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ANNOTATED)
	)
	if not bool(payload.get("annotations_present", false)):
		failures.append("annotated artifact does not declare annotations_present")
	if bool(payload.get("selector_was_run", true)):
		failures.append("annotated artifact already claims selector_was_run")
	var scenarios: Array = payload["scenarios"]
	if scenarios.size() != EXPECTED_COUNT:
		failures.append("expected %d scenarios, found %d"
			% [EXPECTED_COUNT, scenarios.size()])
	if not failures.is_empty():
		_bail("artifact gate")
		return

	_assert_eligibility_predicates_agree()
	if not failures.is_empty():
		_bail("catalogue gate")
		return

	var catalogue_order: Array = []
	for hint_id: String in Data.all_hints():
		catalogue_order.append(hint_id)

	var rows: Array = []
	var counts := {
		"A": {"delivered": 0, "silent": 0, "relevant": 0, "violations": 0,
			"redundant": 0, "teaching": 0},
		"B": {"delivered": 0, "silent": 0, "relevant": 0, "violations": 0,
			"redundant": 0, "teaching": 0},
	}

	for i in scenarios.size():
		var s: Dictionary = scenarios[i]
		var npc := str(s["npc"])
		var state := {
			"evidence_items": s["evidence_items"],
			"knowledge_items": s["knowledge_items"],
			"story_flags": s["story_flags"],
		}
		var valid: Array = s["valid_hints"]
		var eligible := _hard_eligible(npc, state)

		var row := {
			"ordinal": int(s["ordinal"]),
			"scenario_id": s["id"],
			"stratum": s["stratum"],
			"stress_bin": s.get("stress_bin", ""),
			"progression_bucket": s.get("progression_bucket", ""),
			"npc": npc,
			"room": s["room"],
			"stage": s["stage"],
			"evidence_items": s["evidence_items"],
			"story_flags": s["story_flags"],
			"knowledge_items": s["knowledge_items"],
			"hard_eligible_hints": eligible,
			"hard_eligible_count": eligible.size(),
			"human_valid_hints": valid,
			"human_valid_hint_count": valid.size(),
			"human_valid_hints_empty": valid.is_empty(),
			"human_ambiguity": s["annotation"]["ambiguity_note"],
			"pkm_states_derived": _pkm_snapshot(state),
		}

		if int(s["ordinal"]) != i + 1:
			failures.append("%s: ordinal %d at file position %d"
				% [s["id"], int(s["ordinal"]), i + 1])

		for cond: String in ["A", "B"]:
			var selected := ""
			var trace := {}
			if cond == "A":
				selected = Selector.select_condition_a(npc, state)
				trace = _trace_a(npc, state)
				trace["predicted"] = Selector.CONDITION_A_TIERS[npc][trace["tier"]]
			else:
				selected = Selector.select_adaptive(npc, state)
				trace = _trace_b(npc, state, eligible)

			# The trace must explain the output the selector really produced.
			if str(trace["predicted"]) != selected:
				failures.append(
					"%s %s: reconstructed trace predicts '%s' but %s returned '%s'"
					% [s["id"], cond, trace["predicted"], cond, selected]
				)

			var violations: Array = [] if selected.is_empty() else Data.state_violations(
				selected, state["knowledge_items"], state["story_flags"],
				state["evidence_items"]
			)
			var silence := selected.is_empty()
			var relevant := (not silence) and valid.has(selected)
			var redundant := (not silence) and Selector.is_redundant(selected, state)
			var teaches := (not silence) and Selector.teaches_pkm_concept(selected)

			row[cond] = {
				"condition": ("A-4 Evidence-depth Static Baseline" if cond == "A"
					else "B PKM-aware deterministic selector"),
				"selected_hint_id": selected,
				"selected": selected,
				"action": ("SILENCE" if silence else selected),
				"silence": silence,
				"delivered_hint": not silence,
				"decision_trace": trace,
				"relevant": relevant,
				# Frozen primary: SILENCE is never relevant, including where the
				# human label is NONE. The secondary metric is computed in Python
				# from these same two fields; it is not encoded here.
				"appropriate_action": (relevant if not silence
					else valid.is_empty()),
				"state_violation": not violations.is_empty(),
				"state_violation_detail": violations,
				"redundant": redundant,
				"teaches_pkm_concept": teaches,
			}

			var bucket: Dictionary = counts[cond]
			if silence:
				bucket["silent"] = int(bucket["silent"]) + 1
			else:
				bucket["delivered"] = int(bucket["delivered"]) + 1
				if relevant:
					bucket["relevant"] = int(bucket["relevant"]) + 1
				if not violations.is_empty():
					bucket["violations"] = int(bucket["violations"]) + 1
				if redundant:
					bucket["redundant"] = int(bucket["redundant"]) + 1
				if teaches:
					bucket["teaching"] = int(bucket["teaching"]) + 1

		rows.append(row)

	if not failures.is_empty():
		_bail("trace verification")
		return

	var raw := {
		"protocol_version": payload["protocol_version"],
		"conditions_run": ["A", "B"],
		"condition_c_run": false,
		"scenario_count": rows.size(),
		"source_artifact": ANNOTATED,
		"source_artifact_sha256": EXPECTED_SHA[ANNOTATED],
		"annotation_fingerprint_sha256": payload["annotation_fingerprint_sha256"],
		"catalogue_order": catalogue_order,
		"selector_sha256": {
			"scripts/adaptive_hint_selector.gd":
				EXPECTED_SHA["res://scripts/adaptive_hint_selector.gd"],
			"scripts/adaptive_hint_data.gd":
				EXPECTED_SHA["res://scripts/adaptive_hint_data.gd"],
			"scripts/player_knowledge_model.gd":
				EXPECTED_SHA["res://scripts/player_knowledge_model.gd"],
		},
		"engine_version": Engine.get_version_info()["string"],
		"harness_counts": counts,
		"scenarios": rows,
	}

	_write(RAW_OUT, raw)

	print("\n=== heldout-v4 Conditions A and B ===")
	print("scenarios: %d   engine: %s"
		% [rows.size(), Engine.get_version_info()["string"]])
	for cond: String in ["A", "B"]:
		var c: Dictionary = counts[cond]
		print("  %s  delivered %d  silent %d  relevant %d  violations %d  redundant %d  teaching %d"
			% [cond, c["delivered"], c["silent"], c["relevant"], c["violations"],
			   c["redundant"], c["teaching"]])
	print("\nwrote %s" % RAW_OUT)
	print("metrics are NOT computed here; see tools/compute_heldout_v4_metrics.py")
	quit(0)


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true) + "\n")
	f.close()


func _bail(stage: String) -> void:
	print("heldout_v4_ab_evaluation: ABORTED at %s (%d)" % [stage, failures.size()])
	for f: String in failures:
		print("  - " + f)
	quit(1)
