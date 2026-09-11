extends SceneTree

## Condition A vs Condition B over the annotated held-out v3 set.
##
## This is the FIRST time any selector has been run against heldout-v3. It runs
## Conditions A and B only; Condition C is not invoked.
##
## The harness calls the frozen selector and changes nothing about it. Every
## number it reports is derived from:
##
##   * AdaptiveHintSelector.select_condition_a   -- Condition A-4
##   * AdaptiveHintSelector.select_adaptive      -- Condition B
##   * AdaptiveHintData.state_violations         -- hard prerequisites
##   * AdaptiveHintSelector.is_redundant         -- PKM redundancy
##   * AdaptiveHintSelector.teaches_pkm_concept  -- RedundantWhenTeachable denominator
##
## `select_static` is deliberately NOT called: the selector's own docstring
## marks it superseded dead-code replication and says it is not Condition A.
##
## The decision trace is RECONSTRUCTED rather than reported by the selector,
## then checked against what the selector actually returned. A trace that
## disagrees with the real output is a harness failure, not a footnote -- an
## explanation you cannot falsify is not evidence.
##
## Run:
##   godot --headless --path . --script tools/run_heldout_v3_ab_evaluation.gd

const Selector := preload("res://scripts/adaptive_hint_selector.gd")
const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")

const ANNOTATED := "res://docs/heldout/heldout_v3_annotated.json"
const RAW_OUT := "res://docs/heldout/heldout_v3_ab_raw.json"
const METRICS_OUT := "res://docs/heldout/heldout_v3_ab_metrics.json"

## Frozen at heldout-v3-post-annotation. The run aborts if any of these moved,
## so results can never be attributed to a selector that changed underneath them.
const EXPECTED_SHA := {
	"res://docs/heldout/heldout_v3_annotated.json":
		"9d7285c794b824753af3f6a221cef3bc754bc542fe9d0cae52cb2cd09644dc9e",
	"res://docs/heldout/heldout_v3_scenarios.json":
		"dc093e987571d58bd22186c0ea15356df2354c29e99bca4386d1c3063754cd78",
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


## `Data.state_violations` is the catalogue's authoritative hard-prerequisite
## checker, but it tests one field more than Condition B's eligibility filter
## does: `requires_concept`. The two predicates coincide only while no hint
## declares one. Assert that rather than assume it, so the candidate pool this
## harness reports is provably the pool B actually filtered on.
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


## Hard eligibility, from the catalogue's own checker. Same definition for both
## conditions: A simply does not consult it, which is the point of the contrast.
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


func _blank_metrics() -> Dictionary:
	return {
		"attempted": 0, "delivered": 0, "relevant": 0, "silent": 0,
		"violations": 0, "redundant": 0, "teaching_delivered": 0,
		"teaching_redundant": 0,
		"silent_ordinals": [], "irrelevant_ordinals": [],
		"violation_ordinals": [], "redundant_ordinals": [],
	}


func _accumulate(bucket: Dictionary, row: Dictionary, cond: String) -> void:
	var sel := str(row[cond]["selected"])
	bucket["attempted"] = int(bucket["attempted"]) + 1
	if sel.is_empty():
		bucket["silent"] = int(bucket["silent"]) + 1
		bucket["silent_ordinals"].append(row["ordinal"])
		bucket["irrelevant_ordinals"].append(row["ordinal"])
		return
	bucket["delivered"] = int(bucket["delivered"]) + 1
	if bool(row[cond]["relevant"]):
		bucket["relevant"] = int(bucket["relevant"]) + 1
	else:
		bucket["irrelevant_ordinals"].append(row["ordinal"])
	if bool(row[cond]["state_violation"]):
		bucket["violations"] = int(bucket["violations"]) + 1
		bucket["violation_ordinals"].append(row["ordinal"])
	if bool(row[cond]["redundant"]):
		bucket["redundant"] = int(bucket["redundant"]) + 1
		bucket["redundant_ordinals"].append(row["ordinal"])
	if bool(row[cond]["teaches_pkm_concept"]):
		bucket["teaching_delivered"] = int(bucket["teaching_delivered"]) + 1
		if bool(row[cond]["redundant"]):
			bucket["teaching_redundant"] = int(bucket["teaching_redundant"]) + 1


func _rates(b: Dictionary) -> Dictionary:
	var n := int(b["attempted"])
	var d := int(b["delivered"])
	var t := int(b["teaching_delivered"])
	return {
		"RelevantHintRate": {
			"numerator": b["relevant"], "denominator": n,
			"rate": (float(b["relevant"]) / n) if n > 0 else 0.0,
		},
		"Coverage": {
			"numerator": d, "denominator": n,
			"rate": (float(d) / n) if n > 0 else 0.0,
		},
		"StateViolationRate": {
			"numerator": b["violations"], "denominator": d,
			"rate": (float(b["violations"]) / d) if d > 0 else 0.0,
		},
		"RedundantHintRate": {
			"numerator": b["redundant"], "denominator": d,
			"rate": (float(b["redundant"]) / d) if d > 0 else 0.0,
		},
		"RedundantWhenTeachable": {
			"numerator": b["teaching_redundant"], "denominator": t,
			"rate": (float(b["teaching_redundant"]) / t) if t > 0 else null,
			"report": ("N/A (0 teaching hints delivered)" if t == 0
				else "%d/%d" % [b["teaching_redundant"], t]),
		},
	}


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
	if scenarios.size() != 48:
		failures.append("expected 48 scenarios, found %d" % scenarios.size())
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
	var overall := {"A": _blank_metrics(), "B": _blank_metrics()}
	var by_npc: Dictionary = {}
	var divergent: Array = []

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
			"ordinal": i + 1,
			"scenario_id": s["id"],
			"npc": npc,
			"room": s["room"],
			"stage": s["stage"],
			"evidence_items": s["evidence_items"],
			"hard_eligible_hints": eligible,
			"human_valid_hints": valid,
			"human_ambiguity": s["ambiguity_note"],
			"pkm_states_derived": _pkm_snapshot(state),
		}

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
			row[cond] = {
				"condition": ("A-4 Evidence-depth Static Baseline" if cond == "A"
					else "B PKM-aware deterministic selector"),
				"selected_hint_id": selected,
				"selected": selected,
				"silence": selected.is_empty(),
				"decision_trace": trace,
				"relevant": (not selected.is_empty()) and valid.has(selected),
				"state_violation": not violations.is_empty(),
				"state_violation_detail": violations,
				"redundant": (not selected.is_empty())
					and Selector.is_redundant(selected, state),
				"teaches_pkm_concept": (not selected.is_empty())
					and Selector.teaches_pkm_concept(selected),
			}

		if str(row["A"]["selected"]) != str(row["B"]["selected"]):
			divergent.append({
				"ordinal": i + 1, "scenario_id": s["id"], "npc": npc,
				"A": row["A"]["selected"], "B": row["B"]["selected"],
				"human_valid_hints": valid,
			})

		if not by_npc.has(npc):
			by_npc[npc] = {"A": _blank_metrics(), "B": _blank_metrics()}
		for cond: String in ["A", "B"]:
			_accumulate(overall[cond], row, cond)
			_accumulate(by_npc[npc][cond], row, cond)
		rows.append(row)

	if not failures.is_empty():
		_bail("trace verification")
		return

	var metrics := {
		"protocol_version": payload["protocol_version"],
		"conditions_run": ["A", "B"],
		"condition_c_run": false,
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
		"overall": {
			"A": {"counts": overall["A"], "rates": _rates(overall["A"])},
			"B": {"counts": overall["B"], "rates": _rates(overall["B"])},
		},
		"by_npc": {},
		"divergent_scenarios": divergent,
	}
	for npc: String in by_npc:
		metrics["by_npc"][npc] = {
			"A": {"counts": by_npc[npc]["A"], "rates": _rates(by_npc[npc]["A"])},
			"B": {"counts": by_npc[npc]["B"], "rates": _rates(by_npc[npc]["B"])},
		}

	var raw := {
		"protocol_version": payload["protocol_version"],
		"conditions_run": ["A", "B"],
		"condition_c_run": false,
		"scenario_count": rows.size(),
		"source_artifact_sha256": EXPECTED_SHA[ANNOTATED],
		"scenarios": rows,
	}

	_write(RAW_OUT, raw)
	_write(METRICS_OUT, metrics)
	_report(overall, by_npc, divergent)
	quit(0)


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true) + "\n")
	f.close()


func _pct(v: Variant) -> String:
	return "n/a" if v == null else "%5.1f%%" % (float(v) * 100.0)


func _line(label: String, a: Dictionary, b: Dictionary, key: String) -> void:
	var ra: Dictionary = _rates(a)[key]
	var rb: Dictionary = _rates(b)[key]
	if int(ra["denominator"]) == 0 and int(rb["denominator"]) == 0:
		print("  %-24s A/B N/A (0 teaching hints delivered)" % label)
		return
	var delta := "   --"
	if ra["rate"] != null and rb["rate"] != null:
		delta = "%+5.1f" % ((float(rb["rate"]) - float(ra["rate"])) * 100.0)
	print("  %-24s A %s (%d/%d)   B %s (%d/%d)   B-A %s"
		% [label, _pct(ra["rate"]), ra["numerator"], ra["denominator"],
		   _pct(rb["rate"]), rb["numerator"], rb["denominator"], delta])


func _report(overall: Dictionary, by_npc: Dictionary, divergent: Array) -> void:
	print("\n=== Held-out v3 — Condition A vs Condition B ===")
	print("Condition C: NOT RUN\n")
	print("OVERALL (N=48)")
	for key: String in ["RelevantHintRate", "Coverage", "StateViolationRate",
			"RedundantHintRate", "RedundantWhenTeachable"]:
		_line(key, overall["A"], overall["B"], key)
	for cond: String in ["A", "B"]:
		var t := int(overall[cond]["teaching_delivered"])
		if t == 0:
			print("  %s RedundantWhenTeachable: N/A (0 teaching hints delivered)" % cond)

	for npc: String in by_npc:
		print("\n%s (N=%d)" % [npc.to_upper(), by_npc[npc]["A"]["attempted"]])
		for key: String in ["RelevantHintRate", "Coverage", "StateViolationRate",
				"RedundantHintRate", "RedundantWhenTeachable"]:
			_line(key, by_npc[npc]["A"], by_npc[npc]["B"], key)

	print("\nA vs B divergent selections: %d" % divergent.size())
	for d: Dictionary in divergent:
		print("  %2d %s  A=%s  B=%s  human=%s"
			% [d["ordinal"], d["scenario_id"], d["A"], d["B"],
			   str(d["human_valid_hints"])])

	for cond: String in ["A", "B"]:
		print("\nCondition %s" % cond)
		print("  irrelevant ordinals: %s" % str(overall[cond]["irrelevant_ordinals"]))
		print("  silent ordinals:     %s" % str(overall[cond]["silent_ordinals"]))
		print("  violation ordinals:  %s" % str(overall[cond]["violation_ordinals"]))
		print("  redundant ordinals:  %s" % str(overall[cond]["redundant_ordinals"]))

	print("\nwrote %s" % RAW_OUT)
	print("wrote %s" % METRICS_OUT)


func _bail(stage: String) -> void:
	print("heldout_v3_ab_evaluation: ABORTED at %s (%d)" % [stage, failures.size()])
	for f: String in failures:
		print("  - " + f)
	quit(1)
