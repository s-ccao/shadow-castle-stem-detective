extends SceneTree

## Contract tests for Condition C — LLM + PKM adaptive hint selection.
##
## NO MODEL IS CALLED. Every response is scripted through
## `ConditionCClient.Stub`, so the suite is offline, deterministic, needs no API
## key, and exercises the real selector rather than a rehearsal of it.
##
## NO HELD-OUT DATA IS TOUCHED. Every state below is hand-constructed inline.
## Condition C is frozen BEFORE the holdout it will be scored on is generated;
## running these tests reveals nothing about C's behaviour on any benchmark, and
## no assertion here was chosen by looking at one.
##
## The suite checks two different kinds of claim, and the distinction matters:
##
##   BEHAVIOURAL — drive the selector with a scripted reply and assert the
##     decision. These prove what C does.
##   STRUCTURAL — read the selector's own source and assert what it cannot do.
##     These prove what C cannot be made to do by a future edit. "C never falls
##     back to Condition A" is not observable from any single run: A and C can
##     agree by coincidence. It is observable from the absence of the call.
##
## Run:
##   godot --headless --script tests/condition_c_selector_test.gd

const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")
const Client := preload("res://scripts/condition_c_client.gd")

const SELECTOR_SOURCE := "res://scripts/condition_c_selector.gd"
const CLIENT_SOURCE := "res://scripts/condition_c_client.gd"

## The implementation under test. Normally the frozen selector; under
## CONDITION_C_FAULT it is a deliberately broken copy of that selector, compiled
## from mutated source at runtime. The frozen file is never written to.
##
## A check that cannot fail proves nothing. Each mutation below breaks exactly one
## standing commitment, and the suite must notice:
##
##   skip_eligibility_recheck  commitment 7 — hard prerequisites re-checked
##   accept_unoffered          commitments 3, 4 — id must be one that was offered
##   leak_inputs               commitments 8, 10 — allowlisted state only
##   stale_pkm                 commitment 5 — PKM derived, not defaulted
##   unbounded_retries         frozen config — exactly one schema retry
##   fallback_to_condition_a   commitment 9 — exhaustion is SILENCE, never A
##   deliver_model_prose       commitments 2, 3 — an id crosses the boundary, not text
##
## Run a fault with:
##   CONDITION_C_FAULT=stale_pkm godot --headless --script <this file>
const FAULTS := {
	"skip_eligibility_recheck": [[
		"	if not problems.is_empty():",
		"	if not problems.is_empty() and false:",
	]],
	"accept_unoffered": [
		["	if not candidates.has(decision):", "	if false:"],
		[
			"	if str((Data.all_hints()[decision] as Dictionary).get(\"npc\", \"\")) != npc:",
			"	if false:",
		],
	],
	"leak_inputs": [[
		"	for field: String in INPUT_FIELDS:",
		"	for field: String in raw_state.keys():",
	]],
	"stale_pkm": [[
		"		out[concept_id] = PKM.state_name(PKM.state_in(",
		"		out[concept_id] = \"UNSEEN\"\n		var _unused: int = (PKM.state_in(",
	]],
	"unbounded_retries": [
		[
			"			schema_retries += 1\n			if schema_retries > max_retries:",
			"			schema_retries += 1\n			if schema_retries > max_retries + 3:",
		],
		[
			"		schema_retries += 1\n		if schema_retries > max_retries:",
			"		schema_retries += 1\n		if schema_retries > max_retries + 3:",
		],
	],
	"fallback_to_condition_a": [[
		"	return _record(npc, request, attempts, schema_retries - 1, \"\", false, \"\", true)",
		"	var pool: Array = request.get(\"candidates\", [])\n"
		+ "	return _record(npc, request, attempts, schema_retries - 1,"
		+ " \"\" if pool.is_empty() else str(pool[0]), false, \"\", true)",
	]],
	"deliver_model_prose": [[
		"					\"\" if bool(verdict[\"silence\"]) else str(verdict[\"hint_id\"]),",
		"					str(parsed[\"reason\"]),",
	]],
}

var C: GDScript = load(SELECTOR_SOURCE)
var fault: String = ""

var failures: Array[String] = []


## A mutated selector, compiled in memory. Every anchor must be present exactly
## once: a mutation that silently failed to apply would make the fault run pass
## and report a false all-clear, which is the precise failure this harness exists
## to rule out.
func _mutant(name: String) -> GDScript:
	if not FAULTS.has(name):
		push_error("unknown fault '%s'; known: %s" % [name, str(FAULTS.keys())])
		quit(2)
		return null
	var source := FileAccess.get_file_as_string(SELECTOR_SOURCE)
	for pair: Array in FAULTS[name]:
		var anchor := str(pair[0])
		var occurrences := source.count(anchor)
		if occurrences != 1:
			push_error("fault '%s': anchor occurs %d times, expected 1:\n%s"
				% [name, occurrences, anchor])
			quit(2)
			return null
		source = source.replace(anchor, str(pair[1]))
	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	if err != OK:
		push_error("fault '%s' did not compile: %d" % [name, err])
		quit(2)
		return null
	return script


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
		"npc": "", "room": "castle_hall", "stage": "chemistry",
		"evidence_items": evidence, "story_flags": flags,
		"knowledge_items": knowledge,
	}


func _selector(scripted: Array, repeat: Variant = null) -> RefCounted:
	return C.new(Client.Stub.new(scripted, repeat))


func _reply(decision: String, reason: String = "because") -> String:
	return JSON.stringify({"decision": decision, "reason": reason})


## GDScript source with whole-line comments removed, for structural greps.
## Only lines whose first non-blank character is `#` are dropped, so no executable
## token is ever discarded and no string literal is truncated.
func _code_only(source: String) -> String:
	var kept: Array[String] = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


# ---------------------------------------------------------------------------
# 1. Only hard-eligible hints are supplied
# ---------------------------------------------------------------------------

func _test_only_hard_eligible_supplied() -> void:
	var catalogue: Dictionary = Data.all_hints()
	var cases := [
		["butler", _state(["fake_red_stain"])],
		["butler", _state([])],
		["gardener", _state(["greenhouse_pollen"])],
		["gardener", _state([])],
		["mechanic", _state(["deliberate_short_circuit"])],
		["mechanic", _state(["fake_red_stain", "greenhouse_pollen"])],
	]
	for case: Array in cases:
		var npc := str(case[0])
		var state: Dictionary = case[1]
		var request: Dictionary = _selector([]).build_request(npc, state)
		var supplied: Array = request["candidates"]
		_ok("%s: at least one candidate in %s" % [npc, str(state["evidence_items"])],
			not supplied.is_empty())

		for hint_id: String in supplied:
			var problems: Array = Data.state_violations(
				hint_id, state["knowledge_items"], state["story_flags"],
				state["evidence_items"]
			)
			_ok("%s: supplied %s despite %s" % [npc, hint_id, str(problems)],
				problems.is_empty())

		# Nothing eligible may be withheld either: C must see the SAME pool, not
		# a subset chosen for it. A withheld hint would be a content advantage
		# for A and B, which section 9b forbids.
		for hint_id: String in catalogue:
			if str((catalogue[hint_id] as Dictionary).get("npc", "")) != npc:
				continue
			var problems: Array = Data.state_violations(
				hint_id, state["knowledge_items"], state["story_flags"],
				state["evidence_items"]
			)
			if problems.is_empty():
				_ok("%s: eligible %s was withheld from C" % [npc, hint_id],
					supplied.has(hint_id))

		# An ineligible hint must be absent from the rendered prompt entirely,
		# not merely absent from the candidate list.
		for hint_id: String in catalogue:
			if supplied.has(hint_id):
				continue
			_ok("%s: prompt mentions non-candidate %s" % [npc, hint_id],
				not str(request["user"]).contains(hint_id))


# ---------------------------------------------------------------------------
# 2. No cross-NPC hints
# ---------------------------------------------------------------------------

func _test_no_cross_npc_hints() -> void:
	var catalogue: Dictionary = Data.all_hints()
	for npc: String in ["butler", "gardener", "mechanic"]:
		var state := _state([])
		var request: Dictionary = _selector([]).build_request(npc, state)
		for hint_id: String in request["candidates"]:
			_check("%s candidate %s ownership" % [npc, hint_id],
				str((catalogue[hint_id] as Dictionary).get("npc", "")), npc)

	# Even if a foreign id is returned, it must be refused. `h_gardener_pollen`
	# is hard-eligible in this state for the gardener, so the ONLY thing wrong
	# with it is that the butler cannot say it.
	var gardener_state := _state(["greenhouse_pollen"])
	var verdict: Dictionary = C.validate(
		"h_gardener_pollen", "butler", gardener_state,
		C.hard_eligible("butler", gardener_state)
	)
	_ok("cross-NPC hint must be refused", not bool(verdict["ok"]))
	_check("cross-NPC rejection class", str(verdict["error"]), C.INVALID_NOT_OFFERED)

	var result: Dictionary = _selector([], _reply("h_gardener_pollen")).select(
		"butler", gardener_state
	)
	_check("cross-NPC selection falls back to silence",
		str(result["selected_hint_id"]), "")
	_ok("cross-NPC selection is recorded as a fallback", bool(result["fallback_used"]))


# ---------------------------------------------------------------------------
# 3. An invalid hint ID is rejected
# ---------------------------------------------------------------------------

func _test_invalid_hint_id_rejected() -> void:
	var state := _state(["fake_red_stain"])
	for bogus: String in ["h_butler_invented", "", "silence", "Silence",
			"h_butler_stain ", "HINT 3"]:
		var verdict: Dictionary = C.validate(
			bogus.strip_edges(), "butler", state, C.hard_eligible("butler", state)
		)
		if bogus.strip_edges() == "h_butler_stain":
			continue
		_ok("invalid id '%s' must be refused" % bogus, not bool(verdict["ok"]))
		_check("invalid id '%s' has no hint" % bogus, str(verdict["hint_id"]), "")

	# Lowercase "silence" is NOT the sentinel. Accepting near-misses would mean
	# the model's formatting, not its judgement, decided an abstention.
	_ok("lowercase 'silence' is not the sentinel",
		not bool(C.validate("silence", "butler", state, ["h_butler_stain"])["ok"]))

	var result: Dictionary = _selector([], _reply("h_butler_invented")).select("butler", state)
	_check("invented id yields silence", str(result["selected_hint_id"]), "")


# ---------------------------------------------------------------------------
# 4. A hard-INELIGIBLE returned ID is rejected
# ---------------------------------------------------------------------------

func _test_hard_ineligible_rejected() -> void:
	# The player HOLDS the stain, so `h_butler_no_evidence` (which requires it
	# absent) is a real catalogue hint, owned by the right NPC, that is simply
	# not valid here.
	var state := _state(["fake_red_stain"])
	var candidates: Array[String] = C.hard_eligible("butler", state)
	_ok("h_butler_no_evidence must not be a candidate here",
		not candidates.has("h_butler_no_evidence"))

	var verdict: Dictionary = C.validate("h_butler_no_evidence", "butler", state, candidates)
	_ok("ineligible hint must be refused", not bool(verdict["ok"]))

	# The post-output eligibility gate must fire even if the candidate list is
	# wrong. Hand validate() a list that wrongly includes the hint: the only
	# thing left to catch it is the re-check against state.
	var forced: Array[String] = ["h_butler_no_evidence"]
	var recheck: Dictionary = C.validate("h_butler_no_evidence", "butler", state, forced)
	_ok("post-output eligibility re-check must fire", not bool(recheck["ok"]))
	_check("re-check rejection class", str(recheck["error"]), C.INVALID_INELIGIBLE)

	var result: Dictionary = _selector([], _reply("h_butler_no_evidence")).select("butler", state)
	_check("ineligible selection yields silence", str(result["selected_hint_id"]), "")


# ---------------------------------------------------------------------------
# 5. SILENCE is accepted
# ---------------------------------------------------------------------------

func _test_silence_accepted() -> void:
	var state := _state(["greenhouse_pollen"])
	var result: Dictionary = _selector([_reply(C.DECISION_SILENCE, "nothing helps here")]).select(
		"gardener", state
	)
	_ok("SILENCE is accepted", not bool(result["aborted"]))
	_ok("SILENCE is recorded as silence", bool(result["silence"]))
	_check("SILENCE selects no hint", str(result["selected_hint_id"]), "")
	_check("SILENCE costs no retry", int(result["retry_count"]), 0)
	_ok("an accepted SILENCE is not a fallback", not bool(result["fallback_used"]))

	# Silence is a first-class decision and must be distinguishable in the log
	# from a fallback silence: one is a judgement, the other is a failure.
	var exhausted: Dictionary = _selector([], "not json at all").select("gardener", state)
	_ok("fallback silence is flagged", bool(exhausted["fallback_used"]))
	_ok("chosen and fallback silence differ in the record",
		result["fallback_used"] != exhausted["fallback_used"])


# ---------------------------------------------------------------------------
# 6. Malformed responses
# ---------------------------------------------------------------------------

func _test_malformed_response_behaviour() -> void:
	for junk: String in [
		"", "   ", "not json", "[1,2,3]", "\"h_butler_stain\"", "null",
		"{\"decision\": 7}", "{\"reason\": \"forgot the decision\"}",
		"{\"decision\": null}", "{\"hint\": \"h_butler_stain\"}",
		"{\"decision\": \"h_butler_stain\"", "Sure! Here is my answer:",
	]:
		var parsed: Dictionary = C.parse_decision(junk)
		_ok("malformed reply %s must not parse ok" % JSON.stringify(junk),
			not bool(parsed["ok"]))
		_ok("malformed reply %s must yield no decision" % JSON.stringify(junk),
			str(parsed["decision"]).is_empty())

	# A fenced object is transport noise, not a different answer. Accepting it
	# changes no decision; refusing it would burn the retry on punctuation.
	var fenced: Dictionary = C.parse_decision(
		"```json\n{\"decision\": \"h_butler_stain\", \"reason\": \"x\"}\n```"
	)
	_ok("a fenced JSON object parses", bool(fenced["ok"]))
	_check("fenced decision", str(fenced["decision"]), "h_butler_stain")

	# Prose wrapped around an object is NOT repaired. Digging an id out of
	# free text would mean accepting an answer the model did not format as one.
	_ok("prose around an object is not salvaged", not bool(C.parse_decision(
		"I think the answer is {\"decision\": \"h_butler_stain\"} — hope that helps!"
	)["ok"]))

	var result: Dictionary = _selector([], "complete nonsense").select(
		"butler", _state(["fake_red_stain"])
	)
	_ok("unparseable replies never abort the scenario", not bool(result["aborted"]))
	_check("unparseable replies end in silence", str(result["selected_hint_id"]), "")


# ---------------------------------------------------------------------------
# 7. Retry behaviour
# ---------------------------------------------------------------------------

func _test_retry_behaviour() -> void:
	var state := _state(["fake_red_stain"])

	# One malformed reply, then a good one: recovered, with exactly one retry.
	var stub := Client.Stub.new(["garbage", _reply("h_butler_stain")])
	var selector: RefCounted = C.new(stub)
	var recovered: Dictionary = selector.select("butler", state)
	_check("recovered selection", str(recovered["selected_hint_id"]), "h_butler_stain")
	_check("recovery used one retry", int(recovered["retry_count"]), 1)
	_check("recovery made two model calls", stub.calls, 2)

	# The retry prompt must quote the error class and must not name an answer.
	var retry_prompt := str(stub.requests[1]["user"])
	var first_prompt := str(stub.requests[0]["user"])
	_ok("retry prompt carries the rejection class",
		retry_prompt.contains(C.INVALID_UNPARSEABLE))
	_ok("first prompt carries no retry note",
		not first_prompt.contains("previous reply was rejected"))
	_ok("the retry note disclaims any view on the choice",
		retry_prompt.contains("formatting correction only"))

	# Stronger than a phrase match: the retry note is the ONLY difference between
	# the two prompts, and it names no hint. A note that mentioned an identifier
	# would be steering the second answer rather than correcting its format.
	_ok("the retry prompt is the first prompt plus a note",
		retry_prompt.begins_with(first_prompt))
	var note := retry_prompt.substr(first_prompt.length())
	_ok("the retry note is not empty", not note.strip_edges().is_empty())
	for hint_id: String in Data.all_hints():
		_ok("the retry note names hint '%s'" % hint_id, not note.contains(hint_id))
	_ok("the retry note still permits SILENCE", note.contains("SILENCE"))

	# The retry must not change the candidate pool. A retry that re-derived a
	# different pool would make the second answer answer a different question.
	_check("retry keeps the same candidates",
		str(stub.requests[1]["candidates"]), str(stub.requests[0]["candidates"]))

	# The budget is exactly one schema retry: two bad replies, then silence.
	var exhausted_stub := Client.Stub.new(["garbage", "still garbage",
		_reply("h_butler_stain")])
	var exhausted: Dictionary = C.new(exhausted_stub).select("butler", state)
	_check("two bad replies exhaust the budget",
		str(exhausted["selected_hint_id"]), "")
	_check("the budget stops at two calls", exhausted_stub.calls, 2)
	_ok("exhaustion is flagged as a fallback", bool(exhausted["fallback_used"]))

	# A transport failure is not a schema failure and must not spend the retry.
	var flaky := Client.Stub.new(["garbage", _reply("h_butler_stain")])
	flaky.transport_failures = 1
	var survived: Dictionary = C.new(flaky).select("butler", state)
	_check("a transport blip does not consume the schema retry",
		str(survived["selected_hint_id"]), "h_butler_stain")

	# A call that succeeds without producing an answer — a refusal, an empty
	# completion — is a MODEL failure, not a network one. It spends the schema
	# retry, never the transport budget, and it must not abort the scenario.
	var refused := Client.Stub.new([_reply("h_butler_stain")])
	refused.schema_failures = 1
	var after_refusal: Dictionary = C.new(refused).select("butler", state)
	_ok("a model-side failure does not abort", not bool(after_refusal["aborted"]))
	_check("a model-side failure is retried once",
		str(after_refusal["selected_hint_id"]), "h_butler_stain")
	_check("a model-side failure costs one schema retry",
		int(after_refusal["retry_count"]), 1)

	# ...and it obeys the same budget: two of them exhaust it and yield silence.
	var refused_twice := Client.Stub.new([_reply("h_butler_stain")])
	refused_twice.schema_failures = 2
	var starved: Dictionary = C.new(refused_twice).select("butler", state)
	_check("two model-side failures exhaust the budget",
		str(starved["selected_hint_id"]), "")
	_ok("exhausted model-side failures are silence, not an abort",
		not bool(starved["aborted"]))
	_check("the budget stops at two calls after model-side failures",
		refused_twice.calls, 2)

	# Transport failure beyond its own budget ABORTS. Recording an outage as an
	# abstention would fabricate a data point.
	var dead := Client.Stub.new([])
	dead.transport_failures = 99
	var aborted: Dictionary = C.new(dead).select("butler", state)
	_ok("persistent transport failure aborts", bool(aborted["aborted"]))
	_ok("an aborted scenario is not scored as silence", not bool(aborted["silence"]))


# ---------------------------------------------------------------------------
# 8. Canonical PKM is supplied
# ---------------------------------------------------------------------------

func _test_canonical_pkm_supplied() -> void:
	var cases := [
		_state([], []),
		_state(["fake_red_stain"], []),
		_state([], ["mrs_lin_lab_note_seen"]),
		_state(["fake_red_stain"], ["butler_challenge_complete"]),
		_state(["greenhouse_pollen"], ["library_green_filter_earned",
			"circuit_repair_map_studied"]),
	]
	for state: Dictionary in cases:
		var request: Dictionary = _selector([]).build_request("butler", state)
		var supplied: Dictionary = request["pkm_states"]
		_check("all eight concepts supplied", supplied.size(), PKM.CONCEPTS.size())
		for concept_id: String in PKM.CONCEPTS:
			var canonical := PKM.state_name(PKM.state_in(
				concept_id, state["knowledge_items"], state["story_flags"],
				state["evidence_items"]
			))
			_check("%s in %s" % [concept_id, str(state["evidence_items"])],
				str(supplied.get(concept_id, "missing")), canonical)
			_ok("%s state reaches the prompt" % concept_id,
				str(request["user"]).contains(concept_id))

	# The evidence-derived LEARNING state is the one a flags-only serializer got
	# wrong. C derives through the model, so it must see LEARNING here.
	var stain := _state(["fake_red_stain"])
	var derived: Dictionary = _selector([]).build_request("butler", stain)["pkm_states"]
	_check("indicator_reaction is LEARNING when the stain is held",
		str(derived["indicator_reaction"]), "LEARNING")

	# A serialized pkm_states block on the input must be ignored, not trusted.
	var poisoned := _state(["fake_red_stain"])
	poisoned["pkm_states"] = {"indicator_reaction": "DEMONSTRATED"}
	var clean: Dictionary = _selector([]).build_request("butler", poisoned)["pkm_states"]
	_check("a serialized pkm_states block is never trusted",
		str(clean["indicator_reaction"]), "LEARNING")


# ---------------------------------------------------------------------------
# 9. The same 11-hint catalogue
# ---------------------------------------------------------------------------

func _test_same_shared_catalogue() -> void:
	var catalogue: Dictionary = Data.all_hints()
	_check("catalogue size", catalogue.size(), 11)
	_check("predicate parity with Condition B", str(C.assert_predicate_parity()), "[]")

	# Union of everything C can ever be offered, across every evidence subset,
	# must be the whole catalogue: no hint is structurally unreachable for C.
	var major := ["fake_red_stain", "greenhouse_pollen", "deliberate_short_circuit"]
	var reachable := {}
	for mask in 8:
		var evidence: Array = []
		for bit in 3:
			if mask & (1 << bit):
				evidence.append(major[bit])
		for npc: String in ["butler", "gardener", "mechanic"]:
			for hint_id: String in C.hard_eligible(npc, _state(evidence)):
				reachable[hint_id] = true
	for hint_id: String in catalogue:
		_ok("%s is unreachable for Condition C" % hint_id, reachable.has(hint_id))

	# The exact authored text must reach the model verbatim — C picks a written
	# line, so it must be shown the line it is picking.
	var state := _state([])
	var request: Dictionary = _selector([]).build_request("butler", state)
	for hint_id: String in request["candidates"]:
		_ok("%s text is not supplied verbatim" % hint_id,
			str(request["user"]).contains(
				str((catalogue[hint_id] as Dictionary).get("text", ""))
			))

	# Soft metadata is shown but never gates. `h_butler_knows_rule` prefers a
	# DEMONSTRATED concept the player has not demonstrated; it must still be
	# offered, and must still be accepted if chosen.
	var undemonstrated := _state([])
	var candidates: Array[String] = C.hard_eligible("butler", undemonstrated)
	_ok("soft preference must not remove a candidate",
		candidates.has("h_butler_knows_rule"))
	_check("indicator_reaction is not demonstrated here",
		PKM.state_name(PKM.state_in("indicator_reaction", [], [], [])), "UNSEEN")
	_ok("soft preference must not block acceptance", bool(C.validate(
		"h_butler_knows_rule", "butler", undemonstrated, candidates
	)["ok"]))


# ---------------------------------------------------------------------------
# 10. No generated prose is ever used as a player-facing hint
# ---------------------------------------------------------------------------

func _test_no_generated_prose() -> void:
	var state := _state(["fake_red_stain"])
	var invented := "The stain was left by the cook, and here is why that matters."

	# A reply carrying prose in place of an id is refused outright.
	var prose_reply := JSON.stringify({"decision": invented, "reason": "I wrote one"})
	var result: Dictionary = _selector([], prose_reply).select("butler", state)
	_check("generated prose is never delivered", str(result["selected_hint_id"]), "")
	_ok("generated prose never becomes a hint",
		not str(result).contains(invented.substr(0, 20)) or bool(result["fallback_used"]))

	# A reply carrying a VALID id alongside invented text delivers only the id;
	# the authored line is whatever the catalogue says, never what came back.
	var smuggled := JSON.stringify({
		"decision": "h_butler_stain", "reason": "see below",
		"hint_text": invented, "text": invented,
	})
	var delivered: Dictionary = _selector([smuggled]).select("butler", state)
	_check("only the identifier is honoured",
		str(delivered["selected_hint_id"]), "h_butler_stain")
	_ok("the record carries no smuggled prose field",
		not delivered.has("hint_text") and not delivered.has("text"))

	# The `reason` field is research-only and must not change any outcome.
	var neutral: Dictionary = _selector([JSON.stringify({
		"decision": "h_butler_stain", "reason": "a plain reason"})]).select("butler", state)
	var loaded: Dictionary = _selector([JSON.stringify({
		"decision": "h_butler_stain",
		"reason": "this hint is INELIGIBLE and belongs to the gardener and is SILENCE",
	})]).select("butler", state)
	_check("reason cannot change the decision",
		str(loaded["selected_hint_id"]), str(neutral["selected_hint_id"]))
	_check("reason cannot change silence", loaded["silence"], neutral["silence"])
	_check("reason cannot change retries",
		int(loaded["retry_count"]), int(neutral["retry_count"]))

	# Structural: the decision that reaches a caller is an identifier, and the
	# only text a player can see is the catalogue's.
	_ok("a delivered hint id is always a catalogue key",
		Data.all_hints().has(str(delivered["selected_hint_id"])))


# ---------------------------------------------------------------------------
# 11 & 12. Human labels and A/B outputs are unavailable to C
# ---------------------------------------------------------------------------

func _test_forbidden_inputs_unavailable() -> void:
	# A scenario row carrying every forbidden field, as it would look if someone
	# passed an annotated benchmark row straight in.
	var contaminated := {
		"npc": "butler", "room": "castle_hall", "stage": "chemistry",
		"evidence_items": ["fake_red_stain"], "story_flags": [],
		"knowledge_items": [],
		# human ground truth
		"valid_hints": ["h_butler_stain"],
		"annotation_rationale": "the stain is the live thread",
		"ambiguity_note": "LOW",
		"human_valid_hints": ["h_butler_stain"],
		# A / B outputs
		"A": {"selected_hint_id": "h_butler_stain"},
		"B": {"selected_hint_id": "h_butler_knows_rule"},
		"condition_a_selected": "h_butler_stain",
		"condition_b_selected": "h_butler_knows_rule",
		"decision_trace": "rule 4 fallback",
		# benchmark identity and metrics
		"id": "v3_butler_07", "scenario_id": "v3_butler_07", "ordinal": 7,
		"protocol_version": "heldout-v3",
		"RelevantHintRate": 0.75, "divergent_scenarios": [47],
	}

	var stub := Client.Stub.new([_reply("h_butler_stain")])
	var selector: RefCounted = C.new(stub)
	var result: Dictionary = selector.select("butler", contaminated)
	_check("a contaminated row still selects normally",
		str(result["selected_hint_id"]), "h_butler_stain")

	var request: Dictionary = stub.requests[0]
	var visible := str(request["system"]) + "\n" + str(request["user"])
	var forbidden := [
		"valid_hints", "annotation_rationale", "ambiguity_note",
		"human_valid_hints", "the stain is the live thread",
		"condition_a_selected", "condition_b_selected", "decision_trace",
		"rule 4 fallback", "v3_butler_07", "ordinal", "protocol_version",
		"heldout-v3", "RelevantHintRate", "divergent_scenarios",
	]
	for needle: String in forbidden:
		_ok("forbidden input '%s' reached the prompt" % needle,
			not visible.contains(needle))

	# The filtered state must contain nothing but the allowlist.
	var filtered: Dictionary = C.filter_state(contaminated)
	_check("filtered state field count", filtered.size(), C.INPUT_FIELDS.size())
	for key: String in filtered:
		_ok("filtered state leaked '%s'" % key, C.INPUT_FIELDS.has(key))
	for banned: String in ["valid_hints", "A", "B", "id", "scenario_id", "ordinal"]:
		_ok("filtered state retained '%s'" % banned, not filtered.has(banned))

	# The research log must carry no ground truth either. Scoring happens later,
	# in a separate program, against a file C never reads.
	var record := str(result)
	for needle: String in ["valid_hints", "human", "the stain is the live thread",
			"ambiguity"]:
		_ok("the C record carries '%s'" % needle, not record.contains(needle))

	# The word "ordinal" must not appear as scenario identity. (`attempt` indices
	# are C's own, and carry no benchmark position.)
	_ok("the C record carries a benchmark ordinal", not record.contains("v3_butler"))


# ---------------------------------------------------------------------------
# Structural claims — what C cannot be made to do
# ---------------------------------------------------------------------------

func _test_structural_isolation_from_a_and_b() -> void:
	var source := FileAccess.get_file_as_string(SELECTOR_SOURCE)
	var client_source := FileAccess.get_file_as_string(CLIENT_SOURCE)

	# Condition C must not be able to consult A or B at all — not as a fallback,
	# not as a tie-break, not as a prior. A run cannot prove this: A and C may
	# agree by coincidence. The absence of the call site can.
	#
	# Comments are stripped first. Both files DO name `select_condition_a` and
	# `select_adaptive` in prose, precisely to record which calls are forbidden;
	# a grep that banned the words outright would force the commitment to go
	# unwritten in order to be kept. A call cannot hide in a comment, so removing
	# comment lines weakens nothing.
	for banned: String in ["select_condition_a", "select_adaptive",
			"adaptive_hint_selector", "CONDITION_A_TIERS"]:
		_ok("condition_c_selector.gd calls '%s'" % banned,
			not _code_only(source).contains(banned))
		_ok("condition_c_client.gd calls '%s'" % banned,
			not _code_only(client_source).contains(banned))

	# Confirm the stripper actually removed something, so the four checks above
	# are not passing because `_code_only` returned an empty string.
	_ok("comment stripping produced a shorter file",
		_code_only(source).length() < source.length())
	_ok("comment stripping kept the code", _code_only(source).contains("func select("))
	_ok("the banned names really are present in the prose",
		source.contains("select_condition_a"))

	# ...and confirm the check is not passing merely because the file is silent
	# on the point.
	_ok("the fallback policy is stated in the source",
		source.contains("never Condition A, never Condition B"))

	# The declared fallback must be silence, and must say so in the record.
	var result: Dictionary = _selector([], "nonsense").select("butler", _state(["fake_red_stain"]))
	_check("declared fallback policy", str(result["fallback_policy"]),
		"SILENCE (never Condition A or B)")

	# The frozen assets must be the ones the implementation names.
	_check("frozen template path", C.TEMPLATE_PATH,
		"res://prompts/condition_c_selector_v1.txt")
	_check("frozen config path", C.CONFIG_PATH,
		"res://config/condition_c_model_v2.json")
	_ok("the frozen template exists", FileAccess.file_exists(C.TEMPLATE_PATH))
	_ok("the frozen config exists", FileAccess.file_exists(C.CONFIG_PATH))


func _test_frozen_configuration() -> void:
	var config: Dictionary = C.load_config()
	_check("provider", str(config.get("provider", "")), "claude-code-cli")
	_check("api", str(config.get("api", "")), "cli-print-json")
	_check("model", str(config.get("model", "")), "claude-opus-5")
	_check("samples per scenario", int(config.get("samples_per_scenario", 0)), 1)
	_check("schema retries",
		int((config.get("schema_retry", {}) as Dictionary).get("max_retries", -1)), 1)
	_check("schema exhaustion policy",
		str((config.get("schema_retry", {}) as Dictionary).get("on_exhausted", "")),
		"SILENCE")
	_check("transport exhaustion policy",
		str((config.get("transport_retry", {}) as Dictionary).get("on_exhausted", "")),
		"ABORT_RUN")
	_check("config names the frozen template",
		str(config.get("prompt_template", "")), "prompts/condition_c_selector_v1.txt")

	# Sampling parameters are recorded as null and MUST stay null. The CLI
	# transport exposes no flag for any of them, so a number here would be a
	# claim the harness cannot honour -- a setting written down and never sent.
	# This is the one capability the transport change cost, and the config is
	# required to say so rather than carry a comforting leftover from v1.
	for uncontrollable: String in [
		"temperature", "top_p", "top_k", "max_tokens", "seed",
	]:
		_check("'%s' is not controllable through this transport" % uncontrollable,
			config.get(uncontrollable), null)
	_ok("the config explains the lost sampling control",
		(config.get("notes", {}) as Dictionary).has(
			"sampling_parameters_are_no_longer_controllable"))

	# The argv handed to the wrapper must come from the config, and must carry
	# NOTHING ELSE. Two prompt paths and a model identifier: no scenario id, no
	# ordinal, no benchmark name, no repository path. A leak cannot be fixed by
	# the wrapper if the wrapper was handed the secret.
	var arguments := Client.ClaudeCodeCLI.build_arguments(
		"/tmp/sys.txt", "/tmp/usr.txt", config
	)
	_check("the wrapper takes exactly three arguments", arguments.size(), 3)
	_check("argument 1 is the system prompt file", arguments[0], "/tmp/sys.txt")
	_check("argument 2 is the user prompt file", arguments[1], "/tmp/usr.txt")
	_check("argument 3 is the frozen model", arguments[2], "claude-opus-5")

	# The reply is read out of the CLI's JSON envelope, and a CLI-reported error
	# is transport, not a badly formed answer -- scoring an outage as an
	# abstention would fabricate a data point.
	var good := Client.ClaudeCodeCLI.parse_envelope(
		'{"is_error": false, "result": "REPLY", "modelUsage":'
		+ ' {"claude-opus-5": {"canonicalModel": "claude-opus-5"}}}'
	)
	_ok("a success envelope parses", bool(good["ok"]))
	_check("the reply is the envelope's result", str(good["text"]), "REPLY")
	_check("the resolved model is read back",
		Client.ClaudeCodeCLI.resolved_model(good["envelope"]), "claude-opus-5")
	for bad: String in [
		'{"is_error": true, "subtype": "error_during_execution", "result": "x"}',
		'{"subtype": "success"}',
		'not json at all',
	]:
		var parsed := Client.ClaudeCodeCLI.parse_envelope(bad)
		_ok("a broken envelope is refused", not bool(parsed["ok"]))
		_ok("a broken envelope counts as transport", bool(parsed["transport_error"]))


func _test_reproducibility_record() -> void:
	var stub := Client.Stub.new([_reply("h_butler_stain", "the stain is live")])
	var result: Dictionary = C.new(stub).select("butler", _state(["fake_red_stain"]))
	for field: String in [
		"model", "provider", "temperature", "prompt_template_version",
		"prompt_template_sha256", "rendered_prompt_sha256", "candidates_supplied",
		"pkm_states_supplied", "attempts", "retry_count", "selected_hint_id",
		"silence", "fallback_used", "fallback_policy",
	]:
		_ok("the run record omits '%s'" % field, result.has(field))
	_check("template hash is recorded", str(result["prompt_template_sha256"]),
		FileAccess.get_sha256(C.TEMPLATE_PATH))
	_check("the raw response is logged verbatim",
		str((result["attempts"][0] as Dictionary)["raw"]),
		_reply("h_butler_stain", "the stain is live"))
	_check("the model's reason is logged",
		str((result["attempts"][0] as Dictionary)["reason"]), "the stain is live")
	_ok("full prompts are not logged by default", not result.has("rendered_user"))

	# Identical inputs must render an identical prompt: the harness is
	# deterministic even though the model is not.
	var a: Dictionary = C.new(Client.Stub.new([])).build_request("butler", _state(["fake_red_stain"]))
	var b: Dictionary = C.new(Client.Stub.new([])).build_request("butler", _state(["fake_red_stain"]))
	_check("prompt rendering is deterministic", str(a["user"]), str(b["user"]))


func _run() -> void:
	fault = OS.get_environment("CONDITION_C_FAULT")
	if not fault.is_empty():
		C = _mutant(fault)
		if C == null:
			return

	_test_only_hard_eligible_supplied()
	_test_no_cross_npc_hints()
	_test_invalid_hint_id_rejected()
	_test_hard_ineligible_rejected()
	_test_silence_accepted()
	_test_malformed_response_behaviour()
	_test_retry_behaviour()
	_test_canonical_pkm_supplied()
	_test_same_shared_catalogue()
	_test_no_generated_prose()
	_test_forbidden_inputs_unavailable()
	_test_structural_isolation_from_a_and_b()
	_test_frozen_configuration()
	_test_reproducibility_record()

	var label := "condition_c_selector_test"
	if not fault.is_empty():
		label += "[fault=%s]" % fault

	if failures.is_empty():
		if not fault.is_empty():
			print("%s: PASS — the fault was NOT detected. The suite is blind to it."
				% label)
			quit(1)
			return
		print("Condition C — contract tests")
		print("  no model was called; every response was a scripted stub")
		print("  no held-out scenario was read")
		print("  catalogue: the shared 11; eligibility: Data.state_violations")
		print("  PKM: derived through PlayerKnowledgeModel, never read from a file")
		print("  output: catalogue id or SILENCE; fallback: SILENCE, never A or B")
		print("  model: claude-opus-5 via an isolated one-shot Claude Code")
		print("         subprocess; sampling is not controllable, so determinism")
		print("         is NOT claimed. n=1, one schema retry.\n")
		print("condition_c_selector_test: PASS")
		quit(0)
	else:
		print("%s: FAIL (%d)" % [label, failures.size()])
		for f: String in failures:
			print("  - " + f)
		quit(0 if not fault.is_empty() else 1)
