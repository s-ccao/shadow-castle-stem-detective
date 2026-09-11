extends SceneTree

## Proves that a generated dataset's serialized `pkm_states` is what
## `PlayerKnowledgeModel` actually derives -- for every concept, in every state.
##
## WHY. `tools/generate_heldout_v3.py` kept its own PKM table shaped
## `{concept: (learning_flag, demonstrated_flag)}`. That shape cannot express
## `learning_evidence`, so it never consulted one. Exactly one concept has one
## (`indicator_reaction`, LEARNING whenever the player holds `fake_red_stain`),
## and exactly that concept drifted, in 16 of heldout-v3's 384 concept
## assertions. Nothing downstream read the drifted values -- the selectors derive
## PKM themselves and test only DEMONSTRATED -- but a second model of the same
## semantics is a second thing to keep in sync, and it desynchronised.
##
## THE FIX IS FORWARD-ONLY. heldout-v3 is frozen and is NOT repaired here;
## rewriting a state set after its labels are known would be a far worse defect
## than the one being fixed. Instead:
##
##   * future generators serialize through `tools/pkm_reference.py`, which parses
##     the concept table out of the GDScript rather than restating it, and stamp
##     `"pkm_serialization": "canonical"` on the artifact;
##   * a stamped dataset must match the model EXACTLY here -- zero tolerance;
##   * v1, v2 and v3 are grandfathered with their drift PINNED to an exact count
##     and signature, so the known defect cannot quietly grow or vanish;
##   * an unstamped dataset that is not on the grandfathered list FAILS. A new
##     dataset cannot opt out of the check by omitting the stamp.
##
## This is deliberately a different program in a different language from the
## generator that writes the files. The Python side parses the model; this side
## calls it. Agreement across both is the claim.
##
## Fault injection:
##   PKM_SERIALIZATION_FAULT=ignore_evidence   drop `learning_evidence`, i.e.
##                                             reintroduce the original defect
##   PKM_SERIALIZATION_FAULT=exposure_first    test exposure before the check
## Either should make this test FAIL.
##
## Run:
##   godot --headless --path . --script tests/pkm_serialization_canonical_test.gd

const PKM := preload("res://scripts/player_knowledge_model.gd")

const HELDOUT_DIR := "res://docs/heldout"

const CANONICAL_MARKER_KEY := "pkm_serialization"
const CANONICAL_MARKER_VALUE := "canonical"

## Datasets frozen before canonical serialization existed. Each entry pins the
## EXACT drift: total mismatched concept assertions, and the one drift signature
## that accounts for them. A grandfathered file whose drift changes in either
## direction fails -- including a file that silently became correct, which would
## mean a frozen artifact had been edited.
const GRANDFATHERED := {
	"heldout_v1_scenarios.json": {"mismatches": 0, "signature": []},
	"heldout_v2_scenarios.json": {"mismatches": 0, "signature": []},
	"heldout_v3_scenarios.json": {
		"mismatches": 16,
		"signature": ["indicator_reaction: UNSEEN serialized, LEARNING derived x16"],
	},
	"heldout_v3_annotated.json": {
		"mismatches": 16,
		"signature": ["indicator_reaction: UNSEEN serialized, LEARNING derived x16"],
	},
}

var fault := ""
var failures: Array[String] = []
var examined := 0
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	if failures.size() < 30:
		failures.append(message)


## `PlayerKnowledgeModel.state_in`, reached through the model itself. The faults
## below do not patch the model -- they patch this call site, so a fault proves
## the TEST would notice a wrong serializer, not that the model can be broken.
func _derive(concept_id: String, state: Dictionary) -> String:
	var spec: Dictionary = PKM.CONCEPTS.get(concept_id, {})
	var flags: Array = state["story_flags"]
	var evidence: Array = state["evidence_items"]

	if fault == "ignore_evidence":
		for flag_id: String in spec.get("demonstrated_flags", []):
			if flags.has(flag_id):
				return "DEMONSTRATED"
		for flag_id: String in spec.get("learning_flags", []):
			if flags.has(flag_id):
				return "LEARNING"
		return "UNSEEN"

	if fault == "exposure_first":
		for flag_id: String in spec.get("learning_flags", []):
			if flags.has(flag_id):
				return "LEARNING"
		for evidence_id: String in spec.get("learning_evidence", []):
			if evidence.has(evidence_id):
				return "LEARNING"
		for flag_id: String in spec.get("demonstrated_flags", []):
			if flags.has(flag_id):
				return "DEMONSTRATED"
		return "UNSEEN"

	return PKM.state_name(PKM.state_in(
		concept_id, state["knowledge_items"], flags, evidence
	))


func _dataset_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(HELDOUT_DIR)
	if dir == null:
		_fail("cannot open %s" % HELDOUT_DIR)
		return out
	for name: String in dir.get_files():
		if name.ends_with(".json"):
			out.append(name)
	out.sort()
	return out


## One dataset's drift, as a count and a sorted signature. A dataset with no
## `pkm_states` anywhere is not a state set and is skipped by the caller.
func _audit(payload: Dictionary, name: String) -> Dictionary:
	var counts := {}
	var mismatches := 0
	for entry_variant: Variant in (payload.get("scenarios", []) as Array):
		var entry := entry_variant as Dictionary
		var serialized: Dictionary = entry.get("pkm_states", {})
		var state := {
			"knowledge_items": entry.get("knowledge_items", []),
			"story_flags": entry.get("story_flags", []),
			"evidence_items": entry.get("evidence_items", []),
		}

		# Coverage: every concept present, nothing invented. A serializer that
		# simply omits the concept it gets wrong must not read as agreement.
		for concept_id: String in PKM.CONCEPTS:
			if not serialized.has(concept_id):
				_fail("%s %s omits concept '%s'"
					% [name, str(entry.get("id", "?")), concept_id])
		for concept_id: String in serialized:
			if not PKM.CONCEPTS.has(concept_id):
				_fail("%s %s serializes '%s', which PKM v1 does not define"
					% [name, str(entry.get("id", "?")), concept_id])

		for concept_id: String in PKM.CONCEPTS:
			if not serialized.has(concept_id):
				continue
			assertions += 1
			var written := str(serialized[concept_id])
			var derived := _derive(concept_id, state)
			if written == derived:
				continue
			mismatches += 1
			var key := "%s: %s serialized, %s derived" % [concept_id, written, derived]
			counts[key] = int(counts.get(key, 0)) + 1

	var signature: Array = []
	for key: String in counts:
		signature.append("%s x%d" % [key, int(counts[key])])
	signature.sort()
	return {"mismatches": mismatches, "signature": signature}


func _run() -> void:
	fault = OS.get_environment("PKM_SERIALIZATION_FAULT")

	var canonical_seen: Array[String] = []
	var legacy_seen: Array[String] = []

	for name: String in _dataset_files():
		var raw := FileAccess.get_file_as_string("%s/%s" % [HELDOUT_DIR, name])
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var payload := parsed as Dictionary
		var scenarios: Array = payload.get("scenarios", [])
		if scenarios.is_empty():
			continue
		if not (scenarios[0] as Dictionary).has("pkm_states"):
			continue

		examined += 1
		var result := _audit(payload, name)
		var stamped := str(payload.get(CANONICAL_MARKER_KEY, "")) == CANONICAL_MARKER_VALUE

		if stamped:
			canonical_seen.append(name)
			if int(result["mismatches"]) != 0:
				_fail("%s declares canonical PKM serialization but disagrees with "
					% name + "PlayerKnowledgeModel in %d place(s): %s"
					% [result["mismatches"], str(result["signature"])])
			continue

		legacy_seen.append(name)
		if not GRANDFATHERED.has(name):
			_fail("%s serializes pkm_states without '%s: %s' and is not "
				% [name, CANONICAL_MARKER_KEY, CANONICAL_MARKER_VALUE]
				+ "grandfathered. New datasets must serialize through "
				+ "tools/pkm_reference.py.")
			continue
		var expected: Dictionary = GRANDFATHERED[name]
		if int(result["mismatches"]) != int(expected["mismatches"]):
			_fail("%s has %d PKM mismatches; the pinned legacy drift is %d"
				% [name, result["mismatches"], expected["mismatches"]])
		if str(result["signature"]) != str(expected["signature"]):
			_fail("%s drift signature is %s; pinned as %s"
				% [name, str(result["signature"]), str(expected["signature"])])

	for name: String in GRANDFATHERED:
		if not legacy_seen.has(name):
			_fail("grandfathered dataset %s was not examined" % name)

	print("PKM serialization — generated datasets vs PlayerKnowledgeModel")
	if not fault.is_empty():
		print("  FAULT INJECTED: %s" % fault)
	print("  model     scripts/player_knowledge_model.gd  %s"
		% FileAccess.get_sha256("res://scripts/player_knowledge_model.gd"))
	print("  concepts  %d" % PKM.CONCEPTS.size())
	print("  datasets  %d examined, %d concept assertions"
		% [examined, assertions])
	print("  canonical %s" % (str(canonical_seen) if not canonical_seen.is_empty()
		else "(none yet — heldout-v4 will be the first)"))
	print("  legacy    %s" % str(legacy_seen))
	for name: String in GRANDFATHERED:
		print("    %-32s pinned drift %d" % [name, GRANDFATHERED[name]["mismatches"]])

	if failures.is_empty():
		print("\npkm_serialization_canonical_test: PASS")
		quit(0)
	else:
		print("\npkm_serialization_canonical_test: FAIL (%d)" % failures.size())
		for f: String in failures:
			print("  - " + f)
		quit(1)
