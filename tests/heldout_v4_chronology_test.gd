extends SceneTree

## Chronological reachability validation for held-out v4.
##
## Spec §12 requires the v4 states to face the same sixteen rules v3 faced. The
## rules are not copied here: this script preloads the v3 suite and calls its
## `CHRONOLOGY_RULES` and `violations()` directly, so "the same rules" is an
## identity rather than a promise that two files stay in step.
##
## Three layers, per spec §12:
##   L1  construction -- enforced in the generator, by walking real steps.
##   L2  the sixteen rules, below, each proven able to fire.
##   L3  AdaptiveHintData.reachability_violations(), the shipped game's own
##       reachability model, applied to all 72 states.
##
## This suite calls no selector and reads no label. It reads scenario state only.
##
## Run:
##   godot --headless --script tests/heldout_v4_chronology_test.gd

const HELDOUT_PATH := "res://docs/heldout/heldout_v4_scenarios.json"
const V3 := preload("res://tests/heldout_v3_chronology_test.gd")
const DataScript := preload("res://scripts/adaptive_hint_data.gd")

const EXPECTED_SCENARIOS := 72
const EXPECTED_STRATA := {"CORE": 48, "STRESS": 24}

var failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	print("Held-out v4 — chronological reachability\n")

	var raw := FileAccess.get_file_as_string(HELDOUT_PATH)
	if raw.is_empty():
		print("cannot read " + HELDOUT_PATH)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(raw)
	var scenarios: Array = data.get("scenarios", [])

	print("version:   %s" % str(data.get("version", "?")))
	print("spec:      %s" % str(data.get("spec_sha256", "?")).substr(0, 16))
	print("scenarios: %d\n" % scenarios.size())

	if scenarios.size() != EXPECTED_SCENARIOS:
		failures.append("expected %d scenarios, found %d"
			% [EXPECTED_SCENARIOS, scenarios.size()])
	if bool(data.get("selector_was_run", true)):
		failures.append("selector_was_run must be false")
	if bool(data.get("annotations_present", true)):
		failures.append("annotations_present must be false")

	var rules: Array = V3.CHRONOLOGY_RULES
	if rules.size() != 16:
		failures.append("expected 16 v3 rules, reused %d" % rules.size())

	var per_stratum := {}
	var ids := {}
	var prints := {}
	var layer3 := 0

	for entry_variant: Variant in scenarios:
		var entry := entry_variant as Dictionary
		var id := str(entry.get("id", "?"))

		if ids.has(id):
			failures.append("duplicate id %s" % id)
		ids[id] = true
		var fp := str(entry.get("state_fingerprint_sha256", ""))
		if prints.has(fp):
			failures.append("%s duplicates the state of %s" % [id, str(prints[fp])])
		prints[fp] = id

		var stratum := str(entry.get("stratum", "?"))
		per_stratum[stratum] = int(per_stratum.get(stratum, 0)) + 1

		# ---- L2: the sixteen v3 rules, applied verbatim ------------------
		for v: String in V3.violations(entry):
			failures.append("%s -> %s" % [id, v])

		# The character must be in the room where they are actually talkable,
		# and that room's door flag must be present.
		var npc := str(entry.get("npc", ""))
		if V3.NPC_ROOM.has(npc):
			var want: Array = V3.NPC_ROOM[npc]
			if str(entry.get("room", "")) != str(want[0]):
				failures.append("%s: %s is not talkable in %s"
					% [id, npc, str(entry.get("room", ""))])
			if not (entry.get("story_flags", []) as Array).has(str(want[1])):
				failures.append("%s: missing %s for its room" % [id, str(want[1])])
		else:
			failures.append("%s: unknown npc %s" % [id, npc])

		# A witness path is what makes the state auditable.
		if (entry.get("witness_path", []) as Array).size() < 3:
			failures.append("%s: witness_path too short to prove reachability" % id)

		# No ground truth may exist yet.
		if not (entry.get("valid_hints", []) as Array).is_empty():
			failures.append("%s: valid_hints must be empty before annotation" % id)
		if entry.get("annotation") != null:
			failures.append("%s: annotation must be null before annotation" % id)

		# ---- L3: the shipped game's own reachability model ---------------
		var problems: Array = DataScript.reachability_violations(
			entry.get("knowledge_items", []),
			entry.get("story_flags", []),
			entry.get("evidence_items", [])
		)
		for problem: String in problems:
			failures.append("%s is unreachable: %s" % [id, problem])
		layer3 += 1

	for stratum: String in EXPECTED_STRATA:
		var want: int = EXPECTED_STRATA[stratum]
		var got: int = int(per_stratum.get(stratum, 0))
		if got != want:
			failures.append("stratum %s has %d scenarios, expected %d"
				% [stratum, got, want])

	# ---- FAULT INJECTION -------------------------------------------------
	# A rule that cannot fail proves nothing. For each rule we build a state
	# that satisfies its trigger but omits one consequence, and require the
	# checker to catch it. A rule that stays silent here is broken.
	var undetected: Array[String] = []
	var exercised := 0
	for rule_variant: Variant in rules:
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
		exercised += 1

		var probe := {"story_flags": flags, "evidence_items": evidence}
		var caught := false
		for v: String in V3.violations(probe):
			if v.begins_with(rid):
				caught = true
				break
		if not caught:
			undetected.append("%s did not fire when %s was removed" % [rid, removed])

	if exercised != rules.size():
		failures.append("fault injection exercised %d of %d rules"
			% [exercised, rules.size()])
	for u: String in undetected:
		failures.append("FAULT INJECTION: " + u)

	# Layer 3 is the other check that could pass by never running. The shipped
	# model must reject a state the rules above also reject, or its silence on
	# the real scenarios means nothing.
	var l3_probe: Array = DataScript.reachability_violations(
		[], ["door_circuit_unlocked"], ["deliberate_short_circuit"]
	)
	if l3_probe.is_empty():
		failures.append(
			"FAULT INJECTION: reachability_violations() accepted a state reached "
			+ "through no door; layer 3 may be passing vacuously"
		)

	if failures.is_empty():
		print("fault injection: all %d reused rules fire when violated" % exercised)
		print("layer 2: %d states satisfy every chronological rule" % scenarios.size())
		print("layer 3: %d states accepted by AdaptiveHintData.reachability_violations()"
			% layer3)
		print("strata:  CORE %d, STRESS %d"
			% [int(per_stratum.get("CORE", 0)), int(per_stratum.get("STRESS", 0))])
		print("%d unique ids, %d unique state fingerprints" % [ids.size(), prints.size()])
		print("no ground truth present, no selector run\n")
		print("heldout_v4_chronology_test: PASS")
		quit(0)
	else:
		print("heldout_v4_chronology_test: FAIL (%d)" % failures.size())
		for f: String in failures.slice(0, 25):
			print("  - " + f)
		quit(1)
