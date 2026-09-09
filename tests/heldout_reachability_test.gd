extends SceneTree

## Reachability validation for the held-out v2 scenario set.
##
## This script calls ONLY AdaptiveHintData.reachability_violations(), which is
## pure state validation. It does NOT call select_static(), select_adaptive(),
## is_redundant(), or any other selector or scoring function, and it prints no
## hint. Running it therefore does not expose any selector's behaviour on the
## held-out states, which must stay unobserved until the ground truth is
## annotated and frozen.
##
## Run:
##   godot --headless --script tests/heldout_reachability_test.gd

const DataScript := preload("res://scripts/adaptive_hint_data.gd")
const HELDOUT_PATH := "res://docs/heldout/heldout_v2_scenarios.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw := FileAccess.get_file_as_string(HELDOUT_PATH)
	if raw.is_empty():
		print("FAIL: could not read %s" % HELDOUT_PATH)
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("FAIL: held-out file is not a JSON object")
		quit(1)
		return

	var payload := parsed as Dictionary
	var scenarios: Array = payload.get("scenarios", [])

	print("Held-out v2 — reachability validation")
	print("file: %s" % HELDOUT_PATH)
	print("protocol: %s" % str(payload.get("protocol_version", "?")))
	print("scenarios: %d\n" % scenarios.size())

	if scenarios.size() != 48:
		failures.append("expected 48 scenarios, found %d" % scenarios.size())

	# The dataset must ship without ground truth.
	if bool(payload.get("annotations_present", true)):
		failures.append("annotations_present should be false before annotation")
	if bool(payload.get("selector_was_run", true)):
		failures.append("selector_was_run should be false")

	var per_npc: Dictionary = {}
	var seen_ids: Dictionary = {}

	for entry_variant: Variant in scenarios:
		var entry := entry_variant as Dictionary
		var id := str(entry.get("id", ""))

		if seen_ids.has(id):
			failures.append("duplicate scenario id: %s" % id)
		seen_ids[id] = true

		var npc := str(entry.get("npc", ""))
		per_npc[npc] = int(per_npc.get(npc, 0)) + 1

		# No ground truth may be present.
		if not (entry.get("valid_hints", []) as Array).is_empty():
			failures.append("%s already carries valid_hints" % id)
		if str(entry.get("annotation_rationale", "")) != "":
			failures.append("%s already carries an annotation rationale" % id)

		# No fabricated ASSISTED state.
		for concept_id: String in (entry.get("pkm_states", {}) as Dictionary):
			var state := str((entry["pkm_states"] as Dictionary)[concept_id])
			if state == "ASSISTED":
				failures.append(
					"%s claims ASSISTED for %s, which PKM v1 cannot produce"
					% [id, concept_id]
				)

		# v2 room semantics: each NPC is only talkable in its own live room, and
		# entering that room requires its door flag (game_world.gd:5460-5463).
		var live_room := {
			"butler": ["chemistry_room", "door_chemistry_unlocked"],
			"gardener": ["greenhouse_room", "door_greenhouse_unlocked"],
			"mechanic": ["circuit_room", "door_circuit_unlocked"],
		}
		if live_room.has(npc):
			var expected: Array = live_room[npc]
			if str(entry.get("room", "")) != str(expected[0]):
				failures.append(
					"%s is in room '%s' but %s is only talkable in %s"
					% [id, str(entry.get("room", "")), npc, str(expected[0])]
				)
			if not (entry.get("story_flags", []) as Array).has(str(expected[1])):
				failures.append(
					"%s lacks %s, so the player could not be in that room"
					% [id, str(expected[1])]
				)

		# The live Butler chain issues the test before it can be passed.
		var sf: Array = entry.get("story_flags", [])
		if sf.has("butler_challenge_complete") and not sf.has("butler_challenge_given"):
			failures.append(
				"%s has butler_challenge_complete without butler_challenge_given" % id
			)

		# The actual reachability check.
		var problems: Array = DataScript.reachability_violations(
			entry.get("knowledge_items", []),
			entry.get("story_flags", []),
			entry.get("evidence_items", [])
		)
		for problem: String in problems:
			failures.append("%s is unreachable: %s" % [id, problem])

	print("per NPC: %s" % str(per_npc))

	if failures.is_empty():
		print("\nall 48 states pass the reachability validator")
		print("no ground truth present, no ASSISTED fabricated")
		print("heldout_reachability_test: PASS")
		quit(0)
	else:
		print("\nheldout_reachability_test: FAIL (%d)" % failures.size())
		for failure: String in failures:
			print("  - " + failure)
		quit(1)
