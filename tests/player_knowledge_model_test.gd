extends SceneTree

## Contract test for PKM v1, the derived knowledge-state layer.
##
## The layer stores nothing, so the thing worth testing is not persistence but
## its refusals:
##
##   * evidence possession must NOT read as DEMONSTRATED
##   * progression must NOT read as DEMONSTRATED
##   * dead state must NOT read as DEMONSTRATED
##   * two different checks must NOT collapse into one concept
##
## It also pins the audit findings the mapping rests on, so that if the game
## changes underneath, this fails loudly instead of silently reporting a
## demonstration the player never made.
##
## Run:
##   godot --headless --script tests/player_knowledge_model_test.gd

const Model := preload("res://scripts/player_knowledge_model.gd")
const DataScript := preload("res://scripts/adaptive_hint_data.gd")
const SelectorScript := preload("res://scripts/adaptive_hint_selector.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _state() -> Node:
	return root.get_node_or_null("GameState")


func _reset() -> void:
	var gs := _state()
	gs.set("story_flags", {})
	var empty: Array[String] = []
	gs.set("evidence_items", empty)
	var empty_knowledge: Array[String] = []
	gs.set("knowledge_items", empty_knowledge)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _check_true(label: String, value: bool) -> void:
	if not value:
		failures.append(label)


func _run() -> void:
	var gs := _state()
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	print("PKM v1 — derived knowledge-state contract\n")

	# --- 1. Evidence possession alone is never DEMONSTRATED. ---
	# fake_red_stain is granted by three button presses on the live path
	# (chemistry_room.gd:1406-1422) with no question asked.
	_reset()
	gs.call("add_evidence", "fake_red_stain")
	_check(
		"holding fake_red_stain",
		Model.state_name(Model.state_of("indicator_reaction")),
		"LEARNING"
	)
	for concept_id: String in Model.CONCEPTS:
		_check_true(
			"evidence alone must not demonstrate %s" % concept_id,
			not Model.is_demonstrated(concept_id)
		)

	# --- 2. Exposure maps to LEARNING. ---
	# Filing a library record asks no question
	# (library_knowledge_shelf_ui.gd:86-91).
	_reset()
	gs.call("set_story_flag", "library_spectrum_knowledge_learned")
	_check(
		"spectrum filed, check not completed",
		Model.state_name(Model.state_of("spectrum")),
		"LEARNING"
	)
	_reset()
	gs.call("set_story_flag", "circuit_repair_map_studied")
	for concept_id: String in [
		"circuit_continuity", "circuit_regulation", "circuit_fault_isolation"
	]:
		_check(
			"circuit map studied -> %s" % concept_id,
			Model.state_name(Model.state_of(concept_id)),
			"LEARNING"
		)

	# --- 3. Completing the designated check yields DEMONSTRATED. ---
	var check_for := {
		"indicator_reaction": "butler_challenge_complete",
		"physical_chemical_change": "chemistry_change_sorted",
		"spectrum": "library_red_filter_earned",
		"reflection": "library_green_filter_earned",
		"additive": "library_blue_filter_earned",
		"circuit_continuity": "circuit_bench_continuity_cleared",
		"circuit_regulation": "circuit_bench_regulator_cleared",
		"circuit_fault_isolation": "circuit_bench_diagnostic_cleared",
	}
	for concept_id: String in check_for:
		_reset()
		gs.call("set_story_flag", str(check_for[concept_id]))
		_check(
			"check completed -> %s" % concept_id,
			Model.state_name(Model.state_of(concept_id)),
			"DEMONSTRATED"
		)

	# --- 4. Chemistry concepts are no longer conflated. ---
	# The Butler test asks one question about one stain (chemistry_room.gd:1540).
	# The sorting tray classifies 16 samples against the new-substance rule
	# (chemistry_room.gd:456). Completing one must not demonstrate the other.
	_reset()
	gs.call("set_story_flag", "butler_challenge_complete")
	_check_true(
		"butler test must not demonstrate physical_chemical_change",
		not Model.is_demonstrated("physical_chemical_change")
	)
	_check_true(
		"butler test does demonstrate indicator_reaction",
		Model.is_demonstrated("indicator_reaction")
	)
	_reset()
	gs.call("set_story_flag", "chemistry_change_sorted")
	_check_true(
		"sorting must not demonstrate indicator_reaction",
		not Model.is_demonstrated("indicator_reaction")
	)
	_check_true(
		"sorting does demonstrate physical_chemical_change",
		Model.is_demonstrated("physical_chemical_change")
	)

	# --- 5. Circuit concepts are no longer conflated. ---
	# The three benches carry distinct titles and distinct lesson sets
	# (circuit_lab_ui.gd:2172-2177). Clearing one must not demonstrate another.
	var bench := {
		"circuit_continuity": "circuit_bench_continuity_cleared",
		"circuit_regulation": "circuit_bench_regulator_cleared",
		"circuit_fault_isolation": "circuit_bench_diagnostic_cleared",
	}
	for cleared_concept: String in bench:
		_reset()
		gs.call("set_story_flag", str(bench[cleared_concept]))
		for other_concept: String in bench:
			if other_concept == cleared_concept:
				continue
			_check_true(
				"%s must not demonstrate %s" % [cleared_concept, other_concept],
				not Model.is_demonstrated(other_concept)
			)

	# --- 6. knowledge_items can never produce DEMONSTRATED. ---
	# Its only writer sits in show_circuit_learning_note()
	# (game_world.gd:5717), which has zero callers repo-wide.
	_reset()
	gs.call("add_knowledge", "current_resistance")
	for concept_id: String in Model.CONCEPTS:
		_check_true(
			"dead knowledge_items must not demonstrate %s" % concept_id,
			not Model.is_demonstrated(concept_id)
		)

	# --- 7. ASSISTED remains unreachable. ---
	_reset()
	for concept_id: String in Model.CONCEPTS:
		var spec := Model.CONCEPTS[concept_id] as Dictionary
		_check_true(
			"%s must declare no assisted signal while none exists in source" % concept_id,
			not spec.has("assisted_flags")
		)
	_check_true(
		"model documents that ASSISTED needs a new signal",
		Model.ASSISTED_REQUIRES_NEW_STATE
	)

	# --- 8. Every DEMONSTRATED flag has a reachable writer in the game. ---
	# Guards against a mapping that silently stops matching reality, and
	# against reintroducing a dead signal such as current_resistance.
	var sources: String = ""
	for path: String in [
		"res://scripts/game_world.gd",
		"res://scripts/library_room.gd",
		"res://scripts/circuit_room.gd",
		"res://scripts/map_hud.gd",
		"res://scenes/floor_1/chemistry_room.gd",
	]:
		sources += FileAccess.get_file_as_string(path)
	for concept_id: String in Model.CONCEPTS:
		var spec := Model.CONCEPTS[concept_id] as Dictionary
		var mapped: Array = []
		mapped.append_array(spec.get("demonstrated_flags", []))
		mapped.append_array(spec.get("learning_flags", []))
		for flag_id: String in mapped:
			_check_true(
				"flag '%s' (%s) is no longer written in the game" % [flag_id, concept_id],
				sources.contains('"%s"' % flag_id)
			)
		# A DEMONSTRATED flag must have a real writer, not merely appear in a
		# lookup table. The three write patterns in this project are checked
		# explicitly, because an omnibus `or` over them is always true and
		# would silently assert nothing.
		for flag_id: String in spec.get("demonstrated_flags", []):
			var written := false
			# Pattern 1 — direct literal, e.g. chemistry_room.gd:1579.
			if sources.contains('set_story_flag("%s")' % flag_id):
				written = true
			# Pattern 2 — library filters, written via a local built from the
			# challenge id: library_room.gd:844-845 builds `earned_flag` as
			# "library_%s_filter_earned" and passes it to set_story_flag.
			elif flag_id.begins_with("library_") and flag_id.ends_with("_filter_earned"):
				written = (
					sources.contains('var earned_flag := "library_%s_filter_earned"')
					and sources.contains("set_story_flag(earned_flag)")
				)
			# Pattern 3 — circuit benches, written via the BENCH_FOR_SWITCH
			# lookup: circuit_room.gd:411 passes BENCH_FOR_SWITCH[switch_id].
			elif flag_id.begins_with("circuit_bench_"):
				written = (
					sources.contains('"%s"' % flag_id)
					and sources.contains("set_story_flag(BENCH_FOR_SWITCH[switch_id])")
				)
			_check_true(
				"flag '%s' (%s) has no verifiable writer" % [flag_id, concept_id],
				written
			)

	# --- 9. Progression alone never demonstrates anything. ---
	# door_*_unlocked is written only on a correct answer, but retry is
	# unlimited and unlogged (game_world.gd:5646-5670).
	_reset()
	for progression_flag: String in [
		"door_chemistry_unlocked", "door_greenhouse_unlocked",
		"door_circuit_unlocked", "door_library_unlocked",
		"door_dining_unlocked", "door_final_unlocked",
		"circuit_power_restored", "dining_timeline_reconstructed",
	]:
		gs.call("set_story_flag", progression_flag)
	for concept_id: String in Model.CONCEPTS:
		_check_true(
			"progression must not demonstrate %s" % concept_id,
			not Model.is_demonstrated(concept_id)
		)

	# --- 10. needs_teaching is true exactly when not demonstrated. ---
	_reset()
	_check_true("unseen needs teaching", Model.needs_teaching("spectrum"))
	gs.call("set_story_flag", "library_spectrum_knowledge_learned")
	_check_true("learning still needs teaching", Model.needs_teaching("spectrum"))
	gs.call("set_story_flag", "library_red_filter_earned")
	_check_true(
		"demonstrated does not need teaching",
		not Model.needs_teaching("spectrum")
	)

	# --- 11. Empty state is UNSEEN everywhere. ---
	_reset()
	for concept_id: String in Model.CONCEPTS:
		_check(
			"empty state / %s" % concept_id,
			Model.state_name(Model.state_of(concept_id)),
			"UNSEEN"
		)

	# --- 12. Pre-evaluation semantic correction (owner-approved, Option C). ---
	# h_mechanic_knows_resistance previously declared
	# "requires_concept": ["current_resistance"] — a concept resolving through
	# dead knowledge_items that PKM v1 ignores, so the precondition could never
	# hold. A source audit found the text combines a partial circuit_continuity
	# idea with a forensic inference no PKM concept covers, so the owner untied
	# it from PKM rather than re-keying it, which would have overstated the
	# match.
	#
	# These assertions pin that correction: the hint stays usable and
	# Mechanic-owned, but must never re-acquire a PKM concept.
	var catalogue: Dictionary = DataScript.all_hints()
	var mech_hint := "h_mechanic_knows_resistance"
	_check_true("%s must still exist" % mech_hint, catalogue.has(mech_hint))
	if catalogue.has(mech_hint):
		var spec_m := catalogue[mech_hint] as Dictionary
		_check_true(
			"%s must declare no PKM requires_concept" % mech_hint,
			not spec_m.has("requires_concept")
				or (spec_m["requires_concept"] as Array).is_empty()
		)
		_check("%s ownership" % mech_hint, str(spec_m.get("npc", "")), "mechanic")
		_check_true(
			"%s must still require deliberate_short_circuit absent" % mech_hint,
			(spec_m.get("requires_evidence_absent", []) as Array).has(
				"deliberate_short_circuit"
			)
		)
		_check_true(
			"%s must teach no concept" % mech_hint,
			(spec_m.get("teaches", []) as Array).is_empty()
		)

	# No hint may reference the dead concept. This catches a re-keying to a
	# stale id.
	for hint_id: String in catalogue:
		var spec_h := catalogue[hint_id] as Dictionary
		for concept_id: String in spec_h.get("requires_concept", []):
			_check_true(
				"hint '%s' requires dead concept '%s'" % [hint_id, concept_id],
				concept_id != "current_resistance"
			)

	# PKM itself must be untouched by this correction.
	_check("PKM concept count unchanged", Model.CONCEPTS.size(), 8)
	_check_true(
		"PKM must not have gained a current_resistance concept",
		not Model.CONCEPTS.has("current_resistance")
	)

	# --- 13. Story/context prerequisites are not knowledge (Option B). ---
	# dual_lock_rule_taught is written by pressing "Continue"
	# (wake_room.gd:2296 -> :2306) and has no comprehension check anywhere. It
	# records tutorial exposure, so it constrains contextual appropriateness
	# without ever implying comprehension.
	_check_true(
		"dual_lock_rule must not be a PKM concept",
		not Model.CONCEPTS.has("dual_lock_rule")
	)
	for concept_id: String in Model.CONCEPTS:
		var spec_k := Model.CONCEPTS[concept_id] as Dictionary
		var mapped_flags: Array = []
		mapped_flags.append_array(spec_k.get("demonstrated_flags", []))
		mapped_flags.append_array(spec_k.get("learning_flags", []))
		_check_true(
			"dual_lock_rule_taught must not feed PKM concept %s" % concept_id,
			not mapped_flags.has("dual_lock_rule_taught")
		)

	var butler_hint := "h_butler_knows_rule"
	_check_true("%s must still exist" % butler_hint, catalogue.has(butler_hint))
	if catalogue.has(butler_hint):
		var spec_b := catalogue[butler_hint] as Dictionary
		_check_true(
			"%s must declare no requires_concept" % butler_hint,
			not spec_b.has("requires_concept")
				or (spec_b["requires_concept"] as Array).is_empty()
		)
		# The rewritten line reports what the Butler heard. It no longer
		# mentions or presupposes the dual-lock tutorial, so requiring
		# dual_lock_rule_taught would be a prerequisite the text does not earn.
		_check_true(
			"%s must NOT require dual_lock_rule_taught" % butler_hint,
			not (spec_b.get("requires_story_flags", []) as Array).has(
				"dual_lock_rule_taught"
			)
		)
		# It carries a soft preference instead, which is not a prerequisite.
		_check_true(
			"%s must declare its soft preference" % butler_hint,
			(spec_b.get("preferred_when_demonstrated", []) as Array).has(
				"indicator_reaction"
			)
		)
		_check("%s ownership" % butler_hint, str(spec_b.get("npc", "")), "butler")
		_check_true(
			"%s must still require fake_red_stain absent" % butler_hint,
			(spec_b.get("requires_evidence_absent", []) as Array).has("fake_red_stain")
		)
		_check_true(
			"%s must teach no concept" % butler_hint,
			(spec_b.get("teaches", []) as Array).is_empty()
		)

	# The hint is eligible on a bare state: it asserts nothing about the player.
	var bare: Array = DataScript.state_violations(butler_hint, [], [], [])
	_check_true(
		"%s must be eligible with no flags at all" % butler_hint,
		bare.is_empty()
	)
	# An unsatisfied soft preference must never register as a violation, even
	# with every other kind of state present.
	var pref_unsatisfied: Array = DataScript.state_violations(
		butler_hint, [], ["dual_lock_rule_taught"], []
	)
	_check_true(
		"unsatisfied soft preference must not be a StateViolation",
		pref_unsatisfied.is_empty()
	)
	# The evidence prerequisite still bites: once the stain is in hand, the
	# Butler cannot be given the no-stain line.
	var stain_held: Array = DataScript.state_violations(
		butler_hint, [], [], ["fake_red_stain"]
	)
	_check_true(
		"%s must be ineligible while the stain is held" % butler_hint,
		not stain_held.is_empty()
	)

	# A story flag must never move PKM state.
	_reset()
	gs.call("set_story_flag", "dual_lock_rule_taught")
	for concept_id: String in Model.CONCEPTS:
		_check_true(
			"dual_lock_rule_taught must not demonstrate %s" % concept_id,
			not Model.is_demonstrated(concept_id)
		)
		_check(
			"dual_lock_rule_taught must leave %s UNSEEN" % concept_id,
			Model.state_name(Model.state_of(concept_id)),
			"UNSEEN"
		)

	# Story/context flags must not enter redundancy analysis. Redundancy is
	# defined over `teaches`, and this hint teaches nothing.
	var state_with_flag := {
		"knowledge_items": [],
		"story_flags": ["dual_lock_rule_taught"],
		"evidence_items": [],
	}
	_check_true(
		"%s must never be judged redundant via a story flag" % butler_hint,
		not SelectorScript.is_redundant(butler_hint, state_with_flag)
	)

	_reset()

	if failures.is_empty():
		print("concepts mapped: %d" % Model.CONCEPTS.size())
		print("evidence possession   -> LEARNING, never DEMONSTRATED")
		print("progression           -> never DEMONSTRATED")
		print("dead knowledge_items  -> ignored")
		print("chemistry concepts    -> separated (indicator vs classification)")
		print("circuit concepts      -> separated (continuity/regulation/fault)")
		print("ASSISTED              -> reserved, unreachable, documented\n")
		print("player_knowledge_model_test: PASS")
		quit(0)
	else:
		print("player_knowledge_model_test: FAIL (%d)" % failures.size())
		for failure: String in failures:
			print("  - " + failure)
		quit(1)
