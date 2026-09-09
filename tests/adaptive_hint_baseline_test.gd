extends SceneTree

## Weeks 1-2 DEVELOPMENT harness: the earlier static-vs-adaptive comparison.
## No language model is involved.
##
## SUPERSEDED for the frozen research design. This file exercises
## `select_static` -- which replicated dialogue that commit 505f008 made
## unreachable -- over the 20 hand-written + 72 synthetic DEVELOPMENT
## scenarios. It is retained because its drift detectors and reachability
## checks still guard the source transcription.
##
## The frozen Condition A-4 and the 11-hint matched catalogue are covered by
## tests/matched_catalogue_test.gd, not this file.
##
## Two things are measured over a scenario table of real game states:
##
##   RedundantHintRate -- the NPC delivered a hint whose entire teaching
##                        content the player had already demonstrated.
##   RepetitionRate    -- the NPC delivered the same line twice running.
##
## Run:
##   godot --headless --script tests/adaptive_hint_baseline_test.gd

const SelectorScript := preload("res://scripts/adaptive_hint_selector.gd")
const DataScript := preload("res://scripts/adaptive_hint_data.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


## Scenario table.
##
## Every id is real. States are built to be reachable: notably
## blackout_deliberate is never set without deliberate_short_circuit, because
## circuit_room.gd:609-610 sets them on adjacent lines and a scenario that
## separated them would be testing a state no player can occupy.
##
## 20 scenarios. The plan calls for growing this to 50 from playtest traces
## rather than from a desk.
func _scenarios() -> Array:
	return [
		# --- Opening: the player has just been taught the dual-lock rule. ---
		{
			"id": "s01_hall_after_opening_butler",
			"room": "castle_hall",
			"reachability_basis": [
				"wake room: read desk and bookshelf",
				"answer the wake-room knowledge lock (sets dual_lock_rule_taught)",
				"cross into the hall",
				"approach the Butler",
			],
			"npc": "butler",
			"knowledge_items": [],
			"story_flags": ["dual_lock_rule_taught", "hall_orientation_completed"],
			"evidence_items": [],
		},
		{
			"id": "s02_hall_after_opening_gardener",
			"room": "castle_hall",
			"reachability_basis": [
				"wake room: answer the knowledge lock",
				"cross into the hall",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": [],
			"story_flags": ["dual_lock_rule_taught"],
			"evidence_items": [],
		},
		{
			"id": "s03_hall_after_opening_mechanic",
			"room": "castle_hall",
			"reachability_basis": [
				"wake room: answer the knowledge lock",
				"cross into the hall",
				"approach the Mechanic",
			],
			"npc": "mechanic",
			"knowledge_items": [],
			"story_flags": ["dual_lock_rule_taught"],
			"evidence_items": [],
		},
		# --- Evidence gathered; the shipped branch flips. ---
		{
			"id": "s04_butler_with_stain",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"inspect the red stain in the hall",
				"answer Mrs. Lin (collect_red_stain_evidence)",
				"approach the Butler",
			],
			"npc": "butler",
			"knowledge_items": [],
			"story_flags": ["dual_lock_rule_taught"],
			"evidence_items": ["fake_red_stain"],
		},
		{
			"id": "s05_gardener_with_pollen",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"inspect the pollen on the door handle",
				"answer Mrs. Lin (collect_pollen_evidence)",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": [],
			"story_flags": ["dual_lock_rule_taught"],
			"evidence_items": ["greenhouse_pollen"],
		},
		{
			"id": "s06_mechanic_with_short_circuit",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"inspect the burnt wall panel",
				"answer Mrs. Lin (collect_circuit_evidence, also sets blackout_deliberate)",
				"approach the Mechanic",
			],
			"npc": "mechanic",
			"knowledge_items": [],
			"story_flags": [
				"dual_lock_rule_taught",
				"blackout_deliberate",
			],
			"evidence_items": ["deliberate_short_circuit"],
		},
		# --- Library concepts recorded (story flags, not knowledge_items). ---
		{
			"id": "s07_gardener_knows_reflection",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"answer the library knowledge lock (door_library_unlocked)",
				"read the violet reflection cabinet and press record",
				"return to the hall",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": [],
			"story_flags": [
				"door_library_unlocked",
				"dual_lock_rule_taught",
				"library_reflection_knowledge_learned",
			],
			"evidence_items": [],
		},
		{
			"id": "s08_butler_knows_spectrum_only",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"answer the library knowledge lock",
				"read the tall wavelength case and press record",
				"return to the hall",
				"approach the Butler",
			],
			"npc": "butler",
			"knowledge_items": [],
			"story_flags": [
				"door_library_unlocked",
				"dual_lock_rule_taught",
				"library_spectrum_knowledge_learned",
			],
			"evidence_items": [],
		},
		{
			"id": "s09_gardener_all_library_concepts",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"answer the library knowledge lock",
				"record spectrum, reflection and additive",
				"solve the RGB filter puzzle (library_rgb_archive_layer)",
				"return to the hall",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": [],
			"story_flags": [
				"door_library_unlocked",
				"dual_lock_rule_taught",
				"library_spectrum_knowledge_learned",
				"library_reflection_knowledge_learned",
				"library_additive_knowledge_learned",
				"library_rgb_puzzle_solved",
			],
			"evidence_items": ["library_rgb_archive_layer"],
		},
		# --- Circuit bench cleared: current_resistance in knowledge_items. ---
		{
			"id": "s10_mechanic_knows_resistance",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"answer the circuit knowledge lock (door_circuit_unlocked)",
				"restore power at the bench",
				"read the circuit learning note (add_knowledge_item current_resistance)",
				"return to the hall",
				"approach the Mechanic",
			],
			"npc": "mechanic",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"dual_lock_rule_taught",
				"circuit_power_restored",
				"door_circuit_unlocked",
			],
			"evidence_items": [],
		},
		{
			"id": "s11_mechanic_resistance_and_evidence",
			"room": "castle_hall",
			"reachability_basis": [
				"as s10",
				"also inspect the burnt panel and answer Mrs. Lin",
				"approach the Mechanic",
			],
			"npc": "mechanic",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"door_circuit_unlocked",
				"dual_lock_rule_taught",
				"circuit_power_restored",
				"blackout_deliberate",
			],
			"evidence_items": ["deliberate_short_circuit"],
		},
		{
			"id": "s12_butler_resistance_irrelevant",
			"room": "castle_hall",
			"reachability_basis": [
				"as s10",
				"approach the Butler instead — the circuit concept has no bearing on him",
			],
			"npc": "butler",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"dual_lock_rule_taught",
				"door_circuit_unlocked",
			],
			"evidence_items": [],
		},
		# --- Cold-start controls: the rule has NOT been taught. ---
		{
			"id": "s13_butler_cold_start",
			"room": "castle_hall",
			"reachability_basis": [
				"control: reach the Butler with no flags set",
				"used to confirm teaching the rule is correct when it is genuinely unknown",
			],
			"npc": "butler",
			"knowledge_items": [],
			"story_flags": [],
			"evidence_items": [],
		},
		{
			"id": "s14_gardener_cold_start",
			"room": "castle_hall",
			"reachability_basis": [
				"control: reach the Gardener with no flags set",
			],
			"npc": "gardener",
			"knowledge_items": [],
			"story_flags": [],
			"evidence_items": [],
		},
		{
			"id": "s15_mechanic_cold_start",
			"room": "castle_hall",
			"reachability_basis": [
				"control: reach the Mechanic with no flags set",
			],
			"npc": "mechanic",
			"knowledge_items": [],
			"story_flags": [],
			"evidence_items": [],
		},
		# --- Mid and late game. ---
		{
			"id": "s16_butler_mid_game",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"unlock greenhouse and circuit doors",
				"learn refining in the greenhouse",
				"collect the pollen",
				"read the circuit note",
				"approach the Butler",
			],
			"npc": "butler",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"dual_lock_rule_taught",
				"door_greenhouse_unlocked",
				"door_circuit_unlocked",
				"greenhouse_refining_learned",
			],
			"evidence_items": ["greenhouse_pollen"],
		},
		{
			"id": "s17_gardener_mid_game",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"unlock circuit and library doors",
				"record reflection",
				"have the Gardener explain the circuit map",
				"collect the red stain",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"door_library_unlocked",
				"door_circuit_unlocked",
				"dual_lock_rule_taught",
				"library_reflection_knowledge_learned",
				"gardener_circuit_map_explained",
			],
			"evidence_items": ["fake_red_stain"],
		},
		{
			"id": "s18_mechanic_dining_progress",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"reconstruct the dining timeline",
				"collect the stopped clock",
				"approach the Mechanic",
			],
			"npc": "mechanic",
			"knowledge_items": [],
			"story_flags": [
				"dual_lock_rule_taught",
				"dining_timeline_reconstructed",
			],
			"evidence_items": ["dining_timeline", "stopped_midnight_clock"],
		},
		{
			"id": "s19_butler_late_game",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"unlock circuit and library doors",
				"record all three colour concepts",
				"collect stain, pollen and short circuit",
				"find Mrs. Lin",
				"approach the Butler",
			],
			"npc": "butler",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"door_library_unlocked",
				"door_circuit_unlocked",
				"dual_lock_rule_taught",
				"library_spectrum_knowledge_learned",
				"library_reflection_knowledge_learned",
				"library_additive_knowledge_learned",
				"blackout_deliberate",
				"mrs_lin_found_dead",
			],
			"evidence_items": [
				"fake_red_stain",
				"greenhouse_pollen",
				"deliberate_short_circuit",
			],
		},
		{
			"id": "s20_gardener_late_game_no_pollen",
			"room": "castle_hall",
			"reachability_basis": [
				"complete the opening",
				"unlock circuit and library doors",
				"record reflection",
				"collect stain and short circuit but never the pollen",
				"approach the Gardener",
			],
			"npc": "gardener",
			"knowledge_items": ["current_resistance"],
			"story_flags": [
				"door_library_unlocked",
				"door_circuit_unlocked",
				"dual_lock_rule_taught",
				"library_reflection_knowledge_learned",
				"blackout_deliberate",
			],
			"evidence_items": ["fake_red_stain", "deliberate_short_circuit"],
		},
	]


## Guard against silent drift.
##
## Condition A is a reproduction of the shipped branch logic, so it is only a
## valid baseline while the shipped source still branches the way it assumes.
## If someone edits the dialogue functions, this fails loudly instead of
## quietly measuring a baseline that no longer exists.
func _check_shipped_logic_unchanged() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game_world.gd")
	if source.is_empty():
		failures.append("could not read game_world.gd to verify Condition A")
		return

	var expected := {
		"butler": "evidence_items.has(\"fake_red_stain\")",
		"gardener": "evidence_items.has(\"greenhouse_pollen\")",
		"mechanic": "evidence_items.has(\"deliberate_short_circuit\")",
	}
	for npc: String in expected:
		if not source.contains(str(expected[npc])):
			failures.append(
				"Condition A is stale: game_world.gd no longer branches on %s for the %s."
				% [expected[npc], npc]
			)

	# LEGACY_GROUNDED_HINTS are transcribed verbatim from game_world.gd. The
	# audit showed that dialogue is unreachable -- commit 505f008 removed the
	# dispatch -- but the text is still in the file, so this remains a valid
	# drift detector: if someone edits or deletes those strings, the
	# transcription in adaptive_hint_data.gd is no longer faithful.
	for hint_id: String in DataScript.LEGACY_GROUNDED_HINTS:
		var hint := DataScript.LEGACY_GROUNDED_HINTS[hint_id] as Dictionary
		var quoted := str(hint["text"])
		if not source.contains(quoted):
			failures.append(
				"Transcription drift: legacy text for %s is no longer in game_world.gd."
				% hint_id
			)


## Format a rate, or "N/A" when the denominator was empty. Reporting an
## unmeasured metric as a number -- 0%, or a negative sentinel -- would invite
## reading it as a result.
static func _rate_or_na(rate: float) -> String:
	if rate < 0.0:
		return "N/A"
	return "%.1f%%" % (rate * 100.0)


func _measure(condition: String, scenarios: Array) -> Dictionary:
	var hints: Dictionary = DataScript.all_hints()
	var delivered: Array = []
	var redundant := 0
	var repeated := 0
	var relevant := 0
	var judged := 0
	var violations := 0
	var misses: Array = []
	var recent: Dictionary = {}

	for scenario: Dictionary in scenarios:
		var npc := str(scenario["npc"])
		var state := {
			"knowledge_items": scenario["knowledge_items"],
			"story_flags": scenario["story_flags"],
			"evidence_items": scenario["evidence_items"],
		}

		var history: Array = recent.get(npc, [])
		var hint_id := ""
		if condition == "static":
			hint_id = SelectorScript.select_static(npc, state)
		else:
			hint_id = SelectorScript.select_adaptive(npc, state, history)

		if hint_id.is_empty() or not hints.has(hint_id):
			# Counted as a coverage miss rather than a hard failure: staying
			# silent is a legitimate strategy, and the point of measuring
			# coverage is to catch a system that wins on redundancy by using it.
			continue

		if SelectorScript.is_redundant(hint_id, state):
			redundant += 1
		if not history.is_empty() and history.back() == hint_id:
			repeated += 1
		if not DataScript.state_violations(
			hint_id,
			scenario["knowledge_items"],
			scenario["story_flags"],
			scenario["evidence_items"]
		).is_empty():
			violations += 1
		if not VALID_HINTS_SUPERSEDED and VALID_HINTS.has(scenario["id"]):
			judged += 1
			if (VALID_HINTS[scenario["id"]] as Array).has(hint_id):
				relevant += 1
			else:
				misses.append(
					"%s: chose %s, expected one of %s"
					% [scenario["id"], hint_id, str(VALID_HINTS[scenario["id"]])]
				)

		history.append(hint_id)
		recent[npc] = history
		delivered.append(hint_id)

	var total := delivered.size()
	var attempted := scenarios.size()
	return {
		"delivered": total,
		"attempted": attempted,
		"redundant": redundant,
		"repeated": repeated,
		"relevant": relevant,
		"judged": judged,
		"violations": violations,
		"misses": misses,
		"redundant_rate": (float(redundant) / float(total)) if total > 0 else 0.0,
		"repetition_rate": (float(repeated) / float(total)) if total > 0 else 0.0,
		# Coverage guards the obvious way to game RedundantHintRate: a system
		# that says nothing is never redundant. If coverage falls, a lower
		# redundancy score means silence, not improvement.
		"coverage": (float(total) / float(attempted)) if attempted > 0 else 0.0,
		# Relevance is scored only where hand-assigned ground truth exists.
		"relevance": (float(relevant) / float(judged)) if judged > 0 else -1.0,
		"violation_rate": (float(violations) / float(total)) if total > 0 else 0.0,
	}


## Generated coverage sweep.
##
## The plan calls for 50 scenarios drawn from playtest traces. Those do not
## exist yet, and desk-writing another thirty would just be more of what the
## hand-written table already is.
##
## Instead this walks the game's real progression in order and emits a state at
## each milestone, for each NPC, crossed with the evidence the player may or may
## not have collected. Every state is built by *accumulating* prerequisites, so
## it satisfies the reachability rules by construction rather than by review.
##
## These are reported separately from the hand-written table: they cover more
## ground, but they are synthetic and cannot contain a state a designer would
## have thought of and a generator would not.
func _generated_scenarios() -> Array:
	var milestones := [
		{"name": "opening", "flags": ["dual_lock_rule_taught"], "knowledge": []},
		{
			"name": "circuit_open",
			"flags": ["dual_lock_rule_taught", "door_circuit_unlocked"],
			"knowledge": [],
		},
		{
			"name": "circuit_learned",
			"flags": [
				"dual_lock_rule_taught",
				"door_circuit_unlocked",
				"circuit_power_restored",
			],
			"knowledge": ["current_resistance"],
		},
		{
			"name": "library_open",
			"flags": [
				"dual_lock_rule_taught",
				"door_circuit_unlocked",
				"circuit_power_restored",
				"door_library_unlocked",
			],
			"knowledge": ["current_resistance"],
		},
		{
			"name": "library_reflection",
			"flags": [
				"dual_lock_rule_taught",
				"door_circuit_unlocked",
				"circuit_power_restored",
				"door_library_unlocked",
				"library_reflection_knowledge_learned",
			],
			"knowledge": ["current_resistance"],
		},
		{
			"name": "library_all",
			"flags": [
				"dual_lock_rule_taught",
				"door_circuit_unlocked",
				"circuit_power_restored",
				"door_library_unlocked",
				"library_spectrum_knowledge_learned",
				"library_reflection_knowledge_learned",
				"library_additive_knowledge_learned",
				"library_rgb_puzzle_solved",
			],
			"knowledge": ["current_resistance"],
		},
	]

	# Evidence sets, each internally consistent: deliberate_short_circuit always
	# travels with the blackout_deliberate flag, per circuit_room.gd:609-610.
	var evidence_sets := [
		{"name": "none", "evidence": [], "extra_flags": []},
		{"name": "stain", "evidence": ["fake_red_stain"], "extra_flags": []},
		{"name": "pollen", "evidence": ["greenhouse_pollen"], "extra_flags": []},
		{
			"name": "short_circuit",
			"evidence": ["deliberate_short_circuit"],
			"extra_flags": ["blackout_deliberate"],
		},
	]

	var generated: Array = []
	for milestone: Dictionary in milestones:
		for evidence_set: Dictionary in evidence_sets:
			for npc: String in ["butler", "gardener", "mechanic"]:
				var flags: Array = (milestone["flags"] as Array).duplicate()
				for extra: String in evidence_set["extra_flags"]:
					if not flags.has(extra):
						flags.append(extra)
				generated.append({
					"id": "g_%s_%s_%s" % [milestone["name"], evidence_set["name"], npc],
					"npc": npc,
					"knowledge_items": (milestone["knowledge"] as Array).duplicate(),
					"story_flags": flags,
					"evidence_items": (evidence_set["evidence"] as Array).duplicate(),
				})
	return generated


## Hand-assigned DEVELOPMENT ground truth: which hints a good NPC could give.
##
## Deliberately NOT derived from the selector's own rules. Deriving "valid"
## from the same logic under test would make HintRelevance circular -- it would
## report that the system agrees with itself.
##
## PRE-EVALUATION SUPERSEDED. These labels were assigned against the earlier
## 9-hint catalogue, in which the three higher-level hints were hard-gated by
## `requires_concept`. The frozen design replaces that with the soft
## `preferred_when_demonstrated` and adds two foundational teaching hints, so
## several labels no longer describe the catalogue they were written for.
##
## They are PRESERVED rather than rewritten: re-labelling them would mean
## authoring fresh ground truth to match a selector that already exists, which
## is precisely the circularity the note above warns about. Relevance is
## therefore reported as N/A for this superseded harness, and the labels stay
## on disk as provenance. Re-annotation is a principal-investigator decision.
const VALID_HINTS_SUPERSEDED := true
const VALID_HINTS: Dictionary = {
	"s01_hall_after_opening_butler": ["h_butler_knows_rule"],
	"s02_hall_after_opening_gardener": ["h_gardener_no_evidence"],
	"s03_hall_after_opening_mechanic": ["h_mechanic_no_evidence"],
	"s04_butler_with_stain": ["h_butler_stain"],
	"s05_gardener_with_pollen": ["h_gardener_pollen"],
	"s06_mechanic_with_short_circuit": ["h_mechanic_short_circuit"],
	"s07_gardener_knows_reflection": ["h_gardener_knows_reflection"],
	"s08_butler_knows_spectrum_only": ["h_butler_knows_rule"],
	"s09_gardener_all_library_concepts": ["h_gardener_knows_reflection"],
	"s10_mechanic_knows_resistance": ["h_mechanic_knows_resistance"],
	"s11_mechanic_resistance_and_evidence": ["h_mechanic_short_circuit"],
	"s12_butler_resistance_irrelevant": ["h_butler_knows_rule"],
	# Cold start: the rule has not been taught, so teaching it is correct.
	"s13_butler_cold_start": ["h_butler_no_evidence"],
	"s14_gardener_cold_start": ["h_gardener_no_evidence"],
	"s15_mechanic_cold_start": ["h_mechanic_no_evidence"],
	"s16_butler_mid_game": ["h_butler_knows_rule"],
	"s17_gardener_mid_game": ["h_gardener_knows_reflection"],
	"s18_mechanic_dining_progress": ["h_mechanic_no_evidence"],
	"s19_butler_late_game": ["h_butler_stain"],
	"s20_gardener_late_game_no_pollen": ["h_gardener_knows_reflection"],
}


func _check_scenarios_reachable(scenarios: Array) -> void:
	for scenario: Dictionary in scenarios:
		var problems: Array = DataScript.reachability_violations(
			scenario["knowledge_items"],
			scenario["story_flags"],
			scenario["evidence_items"]
		)
		for problem: String in problems:
			failures.append("%s is unreachable: %s" % [scenario["id"], problem])


## Hand-written scenarios must carry the player-action path that produces them.
##
## The validator proves a state combination is *legal*; the basis records how a
## player actually gets there. Without it a scenario is a state vector nobody
## can review, and a reviewer cannot tell a considered case from a typo.
##
## Asserted rather than trusted, so the field cannot rot as scenarios are added.
func _check_reachability_basis(scenarios: Array) -> void:
	for scenario: Dictionary in scenarios:
		var basis: Array = scenario.get("reachability_basis", [])
		if basis.is_empty():
			failures.append(
				"%s has no reachability_basis — every hand-written state must record how a player reaches it"
				% scenario["id"]
			)
		if not scenario.has("room"):
			failures.append("%s does not say which room it happens in" % scenario["id"])


func _run() -> void:
	var scenarios := _scenarios()
	print("Adaptive guidance — Weeks 1-2 baseline")
	print("scenarios: %d   conditions: A (shipped static), B (rule-based adaptive)" % scenarios.size())
	print("no language model is involved in either condition\n")

	_check_shipped_logic_unchanged()
	_check_scenarios_reachable(scenarios)
	_check_reachability_basis(scenarios)

	var static_result := _measure("static", scenarios)
	var adaptive_result := _measure("adaptive", scenarios)

	print("%-28s %10s %10s" % ["metric", "A static", "B adaptive"])
	print("-".repeat(50))
	print(
		"%-28s %10d %10d"
		% ["hints delivered", static_result["delivered"], adaptive_result["delivered"]]
	)
	print(
		"%-28s %10d %10d"
		% ["redundant hints", static_result["redundant"], adaptive_result["redundant"]]
	)
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"RedundantHintRate",
			static_result["redundant_rate"] * 100.0,
			adaptive_result["redundant_rate"] * 100.0,
		]
	)
	print(
		"%-28s %10d %10d"
		% ["repeated hints", static_result["repeated"], adaptive_result["repeated"]]
	)
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"RepetitionRate",
			static_result["repetition_rate"] * 100.0,
			adaptive_result["repetition_rate"] * 100.0,
		]
	)
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"Coverage",
			static_result["coverage"] * 100.0,
			adaptive_result["coverage"] * 100.0,
		]
	)
	# A negative sentinel means "no ground truth was judged". Printing that as
	# a percentage would show -100.0%, which reads like a real measurement.
	print(
		"%-28s %9s %9s"
		% [
			"RelevantHintRate",
			_rate_or_na(static_result["relevance"]),
			_rate_or_na(adaptive_result["relevance"]),
		]
	)
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"StateViolationRate",
			static_result["violation_rate"] * 100.0,
			adaptive_result["violation_rate"] * 100.0,
		]
	)

	# A hint delivered where its own preconditions fail is a false statement to
	# the player. Neither condition should ever produce one.
	if static_result["violation_rate"] > 0.0:
		failures.append("Condition A produced a state violation")
	if adaptive_result["violation_rate"] > 0.0:
		failures.append("Condition B produced a state violation")

	# The remaining relevance misses are the next iteration's input, so print
	# them rather than leaving the reader to infer them from a percentage.
	if not adaptive_result["misses"].is_empty():
		print("\nCondition B relevance misses (%d):" % adaptive_result["misses"].size())
		for miss: String in adaptive_result["misses"]:
			print("  - " + miss)

	# A system that says nothing is never redundant. If Condition B's
	# redundancy fell while its coverage also fell, the improvement is silence
	# and the comparison is invalid.
	if adaptive_result["coverage"] < static_result["coverage"]:
		failures.append(
			"Condition B lowered Coverage (%.3f -> %.3f): a redundancy gain bought with silence is not a gain"
			% [static_result["coverage"], adaptive_result["coverage"]]
		)

	# The experiment's directional claim. Condition B must not be worse; if the
	# rules ever make guidance more redundant, that is a failure, not a result.
	if adaptive_result["redundant_rate"] > static_result["redundant_rate"]:
		failures.append(
			"Condition B increased RedundantHintRate (%.3f -> %.3f)"
			% [static_result["redundant_rate"], adaptive_result["redundant_rate"]]
		)

	print("\nCeiling check — see docs/ADAPTIVE_HINTS_AUDIT.md §G.")
	print(
		"Relevance is N/A: the development labels were written for the earlier"
		+ " 9-hint catalogue and are preserved, not rewritten. Redundancy is 0%"
		+ " here because this superseded harness scores `select_static`, whose"
		+ " reachable lines carry no PKM concept. The frozen catalogue moves"
		+ " teaching content into h_gardener_leaf_colour and"
		+ " h_mechanic_series_basics; see tests/matched_catalogue_test.gd."
	)
	var authored_used := 0
	for hint_id: String in DataScript.AUTHORED_HINTS:
		authored_used += 1
	print(
		"authored (non-shipped) hints available to Condition B: %d" % authored_used
	)

	# --- Generated coverage sweep, reported separately. ---
	var generated := _generated_scenarios()
	_check_scenarios_reachable(generated)
	var gen_static := _measure("static", generated)
	var gen_adaptive := _measure("adaptive", generated)

	print("\nGenerated sweep — %d states built by accumulating prerequisites" % generated.size())
	print("(synthetic, reachable by construction; reported apart from the hand-written table)")
	print("%-28s %10s %10s" % ["metric", "A static", "B adaptive"])
	print("-".repeat(50))
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"RedundantHintRate",
			gen_static["redundant_rate"] * 100.0,
			gen_adaptive["redundant_rate"] * 100.0,
		]
	)
	print(
		"%-28s %9.1f%% %9.1f%%"
		% [
			"RepetitionRate",
			gen_static["repetition_rate"] * 100.0,
			gen_adaptive["repetition_rate"] * 100.0,
		]
	)
	if gen_adaptive["redundant_rate"] > gen_static["redundant_rate"]:
		failures.append("Condition B increased RedundantHintRate on the generated sweep")

	if failures.is_empty():
		print("\nPASS")
		quit(0)
	else:
		print("\nFAIL (%d)" % failures.size())
		for failure: String in failures:
			print("  - " + failure)
		quit(1)
