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

	# --- 0. Structural gate. -------------------------------------------------
	# Later sections index the catalogue directly. If an entry is missing, those
	# lookups raise before quit() is reached and the SceneTree never exits, so
	# the process hangs instead of failing -- a hang in CI is worse than a
	# failure, because it looks like an infrastructure problem. Bail out
	# cleanly and immediately instead.
	var required_ids := [
		"h_butler_no_evidence", "h_butler_stain", "h_butler_knows_rule",
		"h_gardener_no_evidence", "h_gardener_pollen", "h_gardener_leaf_colour",
		"h_gardener_knows_reflection", "h_mechanic_no_evidence",
		"h_mechanic_short_circuit", "h_mechanic_series_basics",
		"h_mechanic_knows_resistance",
	]
	var missing_ids: Array[String] = []
	for hint_id: String in required_ids:
		if not cat.has(hint_id):
			missing_ids.append(hint_id)
	if not missing_ids.is_empty() or cat.size() != required_ids.size():
		print("matched_catalogue_test: FAIL (catalogue structure)")
		print("  - expected %d hints, found %d" % [required_ids.size(), cat.size()])
		if not missing_ids.is_empty():
			print("  - missing: " + ", ".join(missing_ids))
		for hint_id2: String in cat:
			if not required_ids.has(hint_id2):
				print("  - unexpected: " + hint_id2)
		quit(1)
		return

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

	# --- 9b. EXACT hard metadata for all 11 hints, pinned. ---
	# Previously only some hints had their prerequisites asserted, so a typo in
	# an unpinned hint passed silently. Every hint is now pinned exactly.
	var expected_meta := {
		"h_butler_no_evidence": {
			"npc": "butler", "re": [], "rea": ["fake_red_stain"], "rsf": [],
			"teaches": ["dual_lock_rule"], "soft": [],
		},
		"h_butler_stain": {
			"npc": "butler", "re": ["fake_red_stain"], "rea": [], "rsf": [],
			"teaches": [], "soft": [],
		},
		"h_butler_knows_rule": {
			"npc": "butler", "re": [], "rea": ["fake_red_stain"], "rsf": [],
			"teaches": [], "soft": ["indicator_reaction"],
		},
		"h_gardener_no_evidence": {
			"npc": "gardener", "re": [], "rea": ["greenhouse_pollen"], "rsf": [],
			"teaches": [], "soft": [],
		},
		"h_gardener_pollen": {
			"npc": "gardener", "re": ["greenhouse_pollen"], "rea": [], "rsf": [],
			"teaches": [], "soft": [],
		},
		"h_gardener_leaf_colour": {
			"npc": "gardener", "re": [], "rea": [], "rsf": [],
			"teaches": ["reflection"], "soft": [],
		},
		"h_gardener_knows_reflection": {
			"npc": "gardener", "re": [], "rea": ["greenhouse_pollen"], "rsf": [],
			"teaches": [], "soft": ["reflection"],
		},
		"h_mechanic_no_evidence": {
			"npc": "mechanic", "re": [], "rea": ["deliberate_short_circuit"],
			"rsf": [], "teaches": [], "soft": [],
		},
		"h_mechanic_short_circuit": {
			"npc": "mechanic", "re": ["deliberate_short_circuit"], "rea": [],
			"rsf": [], "teaches": [], "soft": [],
		},
		"h_mechanic_series_basics": {
			"npc": "mechanic", "re": [], "rea": [], "rsf": [],
			"teaches": ["circuit_continuity"], "soft": [],
		},
		"h_mechanic_knows_resistance": {
			"npc": "mechanic", "re": [], "rea": ["deliberate_short_circuit"],
			"rsf": [], "teaches": [], "soft": ["circuit_fault_isolation"],
		},
	}
	for hint_id: String in expected_meta:
		if not cat.has(hint_id):
			failures.append("catalogue is missing '%s'" % hint_id)
			continue
		var spec := cat[hint_id] as Dictionary
		var want := expected_meta[hint_id] as Dictionary
		_check("%s npc" % hint_id, str(spec.get("npc", "")), str(want["npc"]))
		_check("%s requires_evidence" % hint_id,
			spec.get("requires_evidence", []), want["re"])
		_check("%s requires_evidence_absent" % hint_id,
			spec.get("requires_evidence_absent", []), want["rea"])
		_check("%s requires_story_flags" % hint_id,
			spec.get("requires_story_flags", []), want["rsf"])
		_check("%s teaches" % hint_id, spec.get("teaches", []), want["teaches"])
		_check("%s preferred_when_demonstrated" % hint_id,
			spec.get("preferred_when_demonstrated", []), want["soft"])
	for hint_id: String in cat:
		if not expected_meta.has(hint_id):
			failures.append("catalogue has unpinned hint '%s'" % hint_id)

	# --- 9c. Every prerequisite id must exist in the shipped source. ---
	# Checked against the real game files rather than a hand-listed set, so a
	# typo cannot pass and the check cannot drift out of date silently.
	var sources := ""
	for path: String in [
		"res://scripts/game_world.gd",
		"res://scenes/floor_1/chemistry_room.gd",
		"res://scripts/greenhouse_room.gd",
		"res://scripts/circuit_room.gd",
		"res://scripts/library_room.gd",
		"res://scripts/map_hud.gd",
		"res://autoload/game_state.gd",
	]:
		sources += FileAccess.get_file_as_string(path)
	_ok("could not read shipped sources for id validation", sources.length() > 10000)
	for hint_id: String in cat:
		var spec2 := cat[hint_id] as Dictionary
		for field: String in [
			"requires_evidence", "requires_evidence_absent", "requires_story_flags"
		]:
			for prereq_id: String in spec2.get(field, []):
				_ok(
					"hint '%s' %s references unknown id '%s'"
						% [hint_id, field, prereq_id],
					sources.contains('"' + prereq_id + '"')
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
