extends SceneTree

## Contract test for the frozen matched catalogue and Condition A-4.
##
## CRITICAL: this suite never touches the held-out set. Every state below is
## hand-constructed inline, so running it exposes no selector behaviour on
## heldout-v2, which must stay unobserved until ground truth is annotated.
##
## Run:
##   godot --headless --script tests/matched_catalogue_test.gd

const Data := preload("res://scripts/adaptive_hint_data.gd")
const Selector := preload("res://scripts/adaptive_hint_selector.gd")
const Model := preload("res://scripts/player_knowledge_model.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _ok(label: String, value: bool) -> void:
	if not value:
		failures.append(label)


func _state(evidence: Array, flags: Array = [], knowledge: Array = []) -> Dictionary:
	return {
		"evidence_items": evidence,
		"story_flags": flags,
		"knowledge_items": knowledge,
	}


func _run() -> void:
	print("Matched catalogue + Condition A-4 contract\n")

	var cat: Dictionary = Data.all_hints()

	# --- 1. Exactly 11 hints, with the frozen per-NPC split. ---
	_check("catalogue size", cat.size(), 11)
	var per_npc: Dictionary = {}
	for hint_id: String in cat:
		var npc := str((cat[hint_id] as Dictionary).get("npc", ""))
		per_npc[npc] = int(per_npc.get(npc, 0)) + 1
	_check("butler hint count", per_npc.get("butler", 0), 3)
	_check("gardener hint count", per_npc.get("gardener", 0), 4)
	_check("mechanic hint count", per_npc.get("mechanic", 0), 4)

	# --- 2. `teaches` may only name real PKM concepts, or dual_lock_rule. ---
	# dual_lock_rule is the one documented non-PKM entry: the legacy Butler line
	# genuinely re-teaches it, so removing it would be metadata bending to the
	# metric. It can never be DEMONSTRATED, hence never redundant.
	var teaching: Array = []
	for hint_id: String in cat:
		for concept_id: String in (cat[hint_id] as Dictionary).get("teaches", []):
			_ok(
				"hint '%s' teaches unknown concept '%s'" % [hint_id, concept_id],
				Model.CONCEPTS.has(concept_id) or concept_id == "dual_lock_rule"
			)
		if Selector.teaches_pkm_concept(hint_id):
			teaching.append(hint_id)
	teaching.sort()
	_check(
		"hints teaching a real PKM concept",
		teaching,
		["h_gardener_leaf_colour", "h_mechanic_series_basics"]
	)
	_ok(
		"h_butler_no_evidence must not count as PKM-teaching",
		not Selector.teaches_pkm_concept("h_butler_no_evidence")
	)

	# --- 3. No hint retains a hard requires_concept gate. ---
	for hint_id: String in cat:
		var spec := cat[hint_id] as Dictionary
		_ok(
			"hint '%s' still declares requires_concept" % hint_id,
			not spec.has("requires_concept")
				or (spec["requires_concept"] as Array).is_empty()
		)

	# --- 4. Foundational hints carry no hard prerequisites. ---
	for hint_id: String in ["h_gardener_leaf_colour", "h_mechanic_series_basics"]:
		var spec := cat[hint_id] as Dictionary
		_ok(
			"%s must have no evidence prerequisite" % hint_id,
			(spec.get("requires_evidence", []) as Array).is_empty()
				and (spec.get("requires_evidence_absent", []) as Array).is_empty()
		)
		_ok(
			"%s must have no story-flag prerequisite" % hint_id,
			(spec.get("requires_story_flags", []) as Array).is_empty()
		)

	# --- 5. Soft preference is never a StateViolation. ---
	# The three higher-level lines assert nothing about the player, so an
	# unsatisfied preference cannot make them factually inconsistent.
	var soft := {
		"h_butler_knows_rule": "indicator_reaction",
		"h_gardener_knows_reflection": "reflection",
		"h_mechanic_knows_resistance": "circuit_fault_isolation",
	}
	for hint_id: String in soft:
		var spec := cat[hint_id] as Dictionary
		_ok(
			"%s must declare its soft preference" % hint_id,
			(spec.get("preferred_when_demonstrated", []) as Array).has(
				str(soft[hint_id])
			)
		)
		# Evidence absent, concept NOT demonstrated -> eligible, no violation.
		var v: Array = Data.state_violations(hint_id, [], [], [])
		_ok(
			"%s must not violate state when its preference is unsatisfied" % hint_id,
			v.is_empty()
		)

	# --- 6. Condition A-4 tier selection. ---
	var expect := {
		"butler": ["h_butler_stain", "h_butler_knows_rule", "h_butler_no_evidence"],
		"gardener": [
			"h_gardener_pollen",
			"h_gardener_knows_reflection",
			"h_gardener_leaf_colour",
		],
		"mechanic": [
			"h_mechanic_short_circuit",
			"h_mechanic_knows_resistance",
			"h_mechanic_series_basics",
		],
	}
	var own := {
		"butler": "fake_red_stain",
		"gardener": "greenhouse_pollen",
		"mechanic": "deliberate_short_circuit",
	}
	var other := {
		"butler": "greenhouse_pollen",
		"gardener": "deliberate_short_circuit",
		"mechanic": "fake_red_stain",
	}
	for npc: String in expect:
		var want: Array = expect[npc]
		# Tier 1 -- own evidence present.
		_check(
			"A-4 %s tier 1" % npc,
			Selector.select_condition_a(npc, _state([str(own[npc])])),
			str(want[0])
		)
		# Tier 2 -- own absent, another major item held.
		_check(
			"A-4 %s tier 2" % npc,
			Selector.select_condition_a(npc, _state([str(other[npc])])),
			str(want[1])
		)
		# Tier 3 -- no major evidence at all.
		_check(
			"A-4 %s tier 3" % npc,
			Selector.select_condition_a(npc, _state([])),
			str(want[2])
		)
		# Tier 1 must win even when other evidence is also held.
		_check(
			"A-4 %s tier 1 dominates" % npc,
			Selector.select_condition_a(
				npc, _state([str(own[npc]), str(other[npc])])
			),
			str(want[0])
		)

	# --- 7. A-4 never reads PKM. ---
	# Setting every PKM demonstrated flag must not change any A-4 choice.
	var all_demonstrated: Array = []
	for concept_id: String in Model.CONCEPTS:
		var spec := Model.CONCEPTS[concept_id] as Dictionary
		for flag_id: String in spec.get("demonstrated_flags", []):
			all_demonstrated.append(flag_id)
	for npc: String in expect:
		for ev: Array in [[], [str(own[npc])], [str(other[npc])]]:
			_check(
				"A-4 %s must ignore PKM state (evidence=%s)" % [npc, str(ev)],
				Selector.select_condition_a(npc, _state(ev, all_demonstrated)),
				Selector.select_condition_a(npc, _state(ev, []))
			)

	# --- 8. A-4 is stateless and order-independent. ---
	# The signature takes no history, and repeated calls must agree.
	for npc: String in expect:
		var first := Selector.select_condition_a(npc, _state([]))
		for _i: int in range(5):
			_check(
				"A-4 %s must be deterministic" % npc,
				Selector.select_condition_a(npc, _state([])),
				first
			)

	# --- 9. Redundancy uses PKM, and only teaching hints can be redundant. ---
	_ok(
		"leaf colour is not redundant when reflection is unseen",
		not Selector.is_redundant("h_gardener_leaf_colour", _state([], []))
	)
	_ok(
		"leaf colour IS redundant once reflection is demonstrated",
		Selector.is_redundant(
			"h_gardener_leaf_colour", _state([], ["library_green_filter_earned"])
		)
	)
	_ok(
		"series basics is redundant once continuity is demonstrated",
		Selector.is_redundant(
			"h_mechanic_series_basics",
			_state([], ["circuit_bench_continuity_cleared"])
		)
	)
	# dual_lock_rule is not a PKM concept, so the Butler line can never be
	# redundant however many flags are set.
	_ok(
		"butler generic can never be redundant",
		not Selector.is_redundant(
			"h_butler_no_evidence", _state([], ["dual_lock_rule_taught"])
		)
	)

	# --- 10. Held-out v1 preserved; v2 carries no ground truth. ---
	var v1 := FileAccess.get_file_as_string(
		"res://docs/heldout/heldout_v1_scenarios.json"
	)
	_ok("heldout v1 must still exist", not v1.is_empty())
	_ok("heldout v1 must still declare protocol v1", v1.contains("heldout-v1"))

	var v2_raw := FileAccess.get_file_as_string(
		"res://docs/heldout/heldout_v2_scenarios.json"
	)
	var v2: Dictionary = JSON.parse_string(v2_raw)
	_check("v2 scenario count", (v2.get("scenarios", []) as Array).size(), 48)
	_ok("v2 annotations_present must be false", not bool(v2.get("annotations_present", true)))
	_ok("v2 selector_was_run must be false", not bool(v2.get("selector_was_run", true)))
	for entry_variant: Variant in (v2.get("scenarios", []) as Array):
		var entry := entry_variant as Dictionary
		_ok(
			"%s must carry no ground truth" % str(entry.get("id", "?")),
			(entry.get("valid_hints", []) as Array).is_empty()
		)

	if failures.is_empty():
		print("catalogue: 11 hints (butler 3, gardener 4, mechanic 4)")
		print("teaching hints: h_gardener_leaf_colour, h_mechanic_series_basics")
		print("A-4: tiers verified, PKM-blind, deterministic, stateless")
		print("soft preference: never a StateViolation")
		print("redundancy: PKM-based, varies with state")
		print("heldout v1 preserved; v2 unannotated, no selector run\n")
		print("matched_catalogue_test: PASS")
		quit(0)
	else:
		print("matched_catalogue_test: FAIL (%d)" % failures.size())
		for f: String in failures:
			print("  - " + f)
		quit(1)
