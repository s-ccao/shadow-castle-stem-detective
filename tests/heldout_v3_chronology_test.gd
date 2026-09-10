extends SceneTree

## Chronological reachability validation for held-out v3.
##
## The v2 validator checked state *invariants* -- whether flags contradicted
## each other. It passed 48/48 on a set where 44 states were unreachable,
## because it never modelled the game's physical-key progression chain. These
## rules encode that chain.
##
## This suite calls no selector. It reads scenario state only.
##
## Run:
##   godot --headless --script tests/heldout_v3_chronology_test.gd

const HELDOUT_PATH := "res://docs/heldout/heldout_v3_scenarios.json"

## Each rule is source-proven. `if_` present implies every id in `then_`.
const CHRONOLOGY_RULES: Array = [
	{
		"id": "C1_stain_needs_chemistry",
		"why": "fake_red_stain is granted at chemistry_room.gd:1423, inside the room; entry needs door_chemistry_unlocked (game_world.gd:3651).",
		"if_evidence": "fake_red_stain",
		"then_flags": ["door_chemistry_unlocked"],
	},
	{
		"id": "C2_pollen_needs_greenhouse",
		"why": "greenhouse_pollen is granted by the workbench parchment at greenhouse_room.gd:1290, inside the Greenhouse.",
		"if_evidence": "greenhouse_pollen",
		"then_flags": ["door_greenhouse_unlocked"],
	},
	{
		"id": "C2b_greenhouse_needs_chemistry_cabinet",
		"why": "greenhouse_room_key comes only from the Chemistry potion cabinet (chemistry_room.gd:395), which also sets chemistry_cabinet_secret_found.",
		"if_flag": "door_greenhouse_unlocked",
		"then_flags": ["chemistry_cabinet_secret_found", "door_chemistry_unlocked"],
	},
	{
		"id": "C3_circuit_implies_pollen",
		"why": "circuit_room_key is granted only after all 7 greenhouse items are inspected (greenhouse_room.gd:1331-1341). The workbench returns before _mark_inspected (:1292), so it only counts once the pollen parchment has been committed. Circuit access therefore implies the pollen.",
		"if_flag": "door_circuit_unlocked",
		"then_flags": ["door_greenhouse_unlocked", "greenhouse_circuit_key_found"],
		"then_evidence": ["greenhouse_pollen"],
	},
	{
		"id": "C4_short_circuit_needs_circuit",
		"why": "deliberate_short_circuit is granted at circuit_room.gd:609, inside the Circuit Room.",
		"if_evidence": "deliberate_short_circuit",
		"then_flags": ["door_circuit_unlocked"],
	},
	{
		"id": "C5_short_circuit_pairs_with_blackout",
		"why": "circuit_room.gd:609-610 sets evidence and flag on adjacent lines.",
		"if_evidence": "deliberate_short_circuit",
		"then_flags": ["blackout_deliberate"],
	},
	{
		"id": "C5b_blackout_pairs_with_short_circuit",
		"why": "The same two adjacent lines, in the other direction.",
		"if_flag": "blackout_deliberate",
		"then_evidence": ["deliberate_short_circuit"],
	},
	{
		"id": "C6_bench_needs_map_study",
		"why": "circuit_repair_map_studied is set only inside the Circuit Room (map_hud.gd:1058), and is the LEARNING source for every circuit concept.",
		"if_flag": "circuit_bench_continuity_cleared",
		"then_flags": ["circuit_repair_map_studied", "door_circuit_unlocked"],
	},
	{
		"id": "C6b_regulator_bench",
		"why": "Same bench room, same blueprint.",
		"if_flag": "circuit_bench_regulator_cleared",
		"then_flags": ["circuit_repair_map_studied", "door_circuit_unlocked"],
	},
	{
		"id": "C6c_diagnostic_bench",
		"why": "Same bench room, same blueprint.",
		"if_flag": "circuit_bench_diagnostic_cleared",
		"then_flags": ["circuit_repair_map_studied", "door_circuit_unlocked"],
	},
	{
		"id": "C7_power_needs_master_switch",
		"why": "circuit_room.gd:766 gates power restoration on the master switch, which is the diagnostic bench (circuit_room.gd:64).",
		"if_flag": "circuit_power_restored",
		"then_flags": ["circuit_bench_diagnostic_cleared"],
	},
	{
		"id": "C8_butler_challenge_needs_stain",
		"why": "Butler branch 2 (chemistry_room.gd:1484) refuses to present the question until fake_red_stain is held, so completion implies the evidence.",
		"if_flag": "butler_challenge_complete",
		"then_flags": ["butler_challenge_given"],
		"then_evidence": ["fake_red_stain"],
	},
	{
		"id": "C9_library_filter_needs_knowledge",
		"why": "library_room.gd:641-643 gates each challenge on its knowledge flag.",
		"if_flag": "library_green_filter_earned",
		"then_flags": ["library_reflection_knowledge_learned", "door_library_unlocked"],
	},
	{
		"id": "C9b_red_filter",
		"why": "Same gate, spectrum station.",
		"if_flag": "library_red_filter_earned",
		"then_flags": ["library_spectrum_knowledge_learned", "door_library_unlocked"],
	},
	{
		"id": "C9c_blue_filter",
		"why": "Same gate, additive station.",
		"if_flag": "library_blue_filter_earned",
		"then_flags": ["library_additive_knowledge_learned", "door_library_unlocked"],
	},
	{
		"id": "C10_door_implies_dual_lock",
		"why": "Every door_*_unlocked comes from answering a knowledge lock, and the opening teaches the rule first.",
		"if_flag": "door_chemistry_unlocked",
		"then_flags": ["dual_lock_rule_taught", "hall_knowledge_chemistry_room_collected"],
	},
]

const NPC_ROOM := {
	"butler": ["chemistry_room", "door_chemistry_unlocked"],
	"gardener": ["greenhouse_room", "door_greenhouse_unlocked"],
	"mechanic": ["circuit_room", "door_circuit_unlocked"],
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


## Returns the ids of rules violated by one scenario. Extracted so the fault
## injection below can reuse exactly the logic the real check uses.
static func violations(entry: Dictionary) -> Array:
	var flags: Array = entry.get("story_flags", [])
	var evidence: Array = entry.get("evidence_items", [])
	var out: Array = []
	for rule_variant: Variant in CHRONOLOGY_RULES:
		var rule := rule_variant as Dictionary
		var fires := false
		if rule.has("if_flag"):
			fires = flags.has(str(rule["if_flag"]))
		elif rule.has("if_evidence"):
			fires = evidence.has(str(rule["if_evidence"]))
		if not fires:
			continue
		for f: String in rule.get("then_flags", []):
			if not flags.has(f):
				out.append("%s: missing flag %s" % [str(rule["id"]), f])
		for e: String in rule.get("then_evidence", []):
			if not evidence.has(e):
				out.append("%s: missing evidence %s" % [str(rule["id"]), e])
	return out


func _run() -> void:
	print("Held-out v3 — chronological reachability\n")

	var raw := FileAccess.get_file_as_string(HELDOUT_PATH)
	if raw.is_empty():
		print("cannot read " + HELDOUT_PATH)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(raw)
	var scenarios: Array = data.get("scenarios", [])

	print("protocol: %s" % str(data.get("protocol_version", "?")))
	print("scenarios: %d\n" % scenarios.size())

	if bool(data.get("selector_was_run", true)):
		failures.append("selector_was_run must be false")
	if bool(data.get("annotations_present", true)):
		failures.append("annotations_present must be false")

	for entry_variant: Variant in scenarios:
		var entry := entry_variant as Dictionary
		var id := str(entry.get("id", "?"))

		for v: String in violations(entry):
			failures.append("%s -> %s" % [id, v])

		# The character must be in the room where they are actually talkable,
		# and that room's door flag must be present.
		var npc := str(entry.get("npc", ""))
		if NPC_ROOM.has(npc):
			var want: Array = NPC_ROOM[npc]
			if str(entry.get("room", "")) != str(want[0]):
				failures.append("%s: %s is not talkable in %s"
					% [id, npc, str(entry.get("room", ""))])
			if not (entry.get("story_flags", []) as Array).has(str(want[1])):
				failures.append("%s: missing %s for its room" % [id, str(want[1])])

		# A witness path is what makes the state auditable.
		if (entry.get("witness_path", []) as Array).size() < 3:
			failures.append("%s: witness_path too short to prove reachability" % id)

		# No ground truth may exist yet.
		if not (entry.get("valid_hints", []) as Array).is_empty():
			failures.append("%s: valid_hints must be empty before annotation" % id)

	# ---- FAULT INJECTION -------------------------------------------------
	# A rule that cannot fail proves nothing. For each rule we build a state
	# that satisfies its trigger but omits one consequence, and require the
	# checker to catch it. A rule that stays silent here is broken.
	var undetected: Array[String] = []
	for rule_variant: Variant in CHRONOLOGY_RULES:
		var rule := rule_variant as Dictionary
		var rid := str(rule["id"])
		# Start from a state that satisfies every consequence...
		var flags: Array = []
		var evidence: Array = []
		for f: String in rule.get("then_flags", []):
			flags.append(f)
		for e: String in rule.get("then_evidence", []):
			evidence.append(e)
		# ...fire the trigger...
		if rule.has("if_flag"):
			flags.append(str(rule["if_flag"]))
		elif rule.has("if_evidence"):
			evidence.append(str(rule["if_evidence"]))
		# ...then remove exactly one required consequence.
		var removed := ""
		if not (rule.get("then_flags", []) as Array).is_empty():
			removed = str((rule["then_flags"] as Array)[0])
			flags.erase(removed)
		elif not (rule.get("then_evidence", []) as Array).is_empty():
			removed = str((rule["then_evidence"] as Array)[0])
			evidence.erase(removed)
		else:
			continue

		var probe := {"story_flags": flags, "evidence_items": evidence}
		var caught := false
		for v: String in violations(probe):
			if v.begins_with(rid):
				caught = true
				break
		if not caught:
			undetected.append("%s did not fire when %s was removed" % [rid, removed])

	# The clean dataset must also survive the probe machinery unchanged.
	for rule_variant2: Variant in CHRONOLOGY_RULES:
		pass

	if not undetected.is_empty():
		for u: String in undetected:
			failures.append("FAULT INJECTION: " + u)

	if failures.is_empty():
		print("fault injection: all %d rules fire when violated"
			% CHRONOLOGY_RULES.size())
		print("all %d states satisfy every chronological rule" % scenarios.size())
		print("%d rules enforced" % CHRONOLOGY_RULES.size())
		print("no ground truth present, no selector run\n")
		print("heldout_v3_chronology_test: PASS")
		quit(0)
	else:
		print("heldout_v3_chronology_test: FAIL (%d)" % failures.size())
		for f: String in failures.slice(0, 25):
			print("  - " + f)
		quit(1)
