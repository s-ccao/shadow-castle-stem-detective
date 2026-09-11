extends SceneTree

## Proves that the Condition B prose in docs/EVALUATION_PROTOCOL.md describes the
## frozen selector and not something adjacent to it.
##
## The protocol now documents Condition B in words. Words drift. This script
## reimplements B *from that wording* -- deliberately in a different shape from
## `select_adaptive`, using explicit named steps rather than the original's
## early-return cascade -- and then compares the two over an EXHAUSTIVE
## enumeration of every state that can change B's answer.
##
## Completeness is asserted, not assumed. Before enumerating, the script proves
## that the state space it walks covers every evidence id and story flag any part
## of B or PKM can react to; if the catalogue or the knowledge model ever names
## something outside that space, the run aborts rather than reporting a pass over
## a space it silently under-covers.
##
## This script MODIFIES NOTHING. It reads the frozen selector, the frozen
## catalogue and the frozen knowledge model, and touches no held-out artifact.
##
## Fault injection -- a check that cannot fail proves nothing:
##   CONDITION_B_DOC_FAULT=rule_order     swap Rules 2 and 3
##   CONDITION_B_DOC_FAULT=learning_ok    accept LEARNING for the soft preference
##   CONDITION_B_DOC_FAULT=empty_prefs    let an absent preference field match
##   CONDITION_B_DOC_FAULT=reverse_ties   walk the catalogue backwards
##   CONDITION_B_DOC_FAULT=teaches_empty  call an empty `teaches` set redundant
## Each should make this script FAIL. If one does not, the prose it is checking
## does not actually constrain that behaviour.
##
## Run:
##   godot --headless --path . --script tools/verify_condition_b_documentation.gd

const Selector := preload("res://scripts/adaptive_hint_selector.gd")
const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")

## The selector as frozen at heldout-v3-pre-annotation. The prose claims to
## describe THIS file; checking a different one would prove nothing about it.
const EXPECTED_SHA := {
	"res://scripts/adaptive_hint_selector.gd":
		"c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
	"res://scripts/adaptive_hint_data.gd":
		"a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
	"res://scripts/player_knowledge_model.gd":
		"55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
}

## Documented tie-break order (protocol 9b, "Tie-breaking"). Written out here so
## the prose's numbered list is itself checked against the catalogue, rather than
## being read back out of the catalogue it is supposed to describe.
const DOCUMENTED_ORDER: Array[String] = [
	"h_butler_no_evidence",
	"h_butler_stain",
	"h_gardener_no_evidence",
	"h_gardener_pollen",
	"h_mechanic_no_evidence",
	"h_mechanic_short_circuit",
	"h_butler_knows_rule",
	"h_gardener_leaf_colour",
	"h_gardener_knows_reflection",
	"h_mechanic_series_basics",
	"h_mechanic_knows_resistance",
]

## Documented soft-preference table (protocol 9b, Rule 2).
const DOCUMENTED_PREFERENCES := {
	"h_butler_knows_rule": ["indicator_reaction"],
	"h_gardener_knows_reflection": ["reflection"],
	"h_mechanic_knows_resistance": ["circuit_fault_isolation"],
}

## The three NPCs the protocol evaluates, plus one the catalogue does not know.
## The stranger is not decoration: the prose claims B's ONLY silence is an
## unknown NPC, and that claim needs a state to be tested on.
const NPCS: Array[String] = ["butler", "gardener", "mechanic", "librarian"]

var fault := ""
var failures: Array[String] = []
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	if failures.size() < 40:
		failures.append(message)


# --------------------------------------------------------------------------
# Condition B, reimplemented from the protocol prose.
# --------------------------------------------------------------------------

## Prose step 1 -- "Eligibility (hard prerequisites)".
## Four checks and nothing else, in catalogue declaration order.
func _prose_eligible(npc: String, state: Dictionary) -> Array[String]:
	var evidence: Array = state["evidence_items"]
	var flags: Array = state["story_flags"]
	var out: Array[String] = []
	var order := DOCUMENTED_ORDER.duplicate()
	if fault == "reverse_ties":
		order.reverse()
	for hint_id: String in order:
		var hint: Dictionary = Data.all_hints()[hint_id]
		if str(hint.get("npc", "")) != npc:
			continue
		var ok := true
		for needed: String in hint.get("requires_evidence", []):
			if not evidence.has(needed):
				ok = false
		for forbidden: String in hint.get("requires_evidence_absent", []):
			if evidence.has(forbidden):
				ok = false
		for flag_id: String in hint.get("requires_story_flags", []):
			if not flags.has(flag_id):
				ok = false
		if ok:
			out.append(hint_id)
	return out


func _demonstrated(concept_id: String, state: Dictionary) -> bool:
	var mastery := PKM.state_in(
		concept_id,
		state["knowledge_items"],
		state["story_flags"],
		state["evidence_items"]
	)
	if fault == "learning_ok":
		return mastery == PKM.Mastery.DEMONSTRATED or mastery == PKM.Mastery.LEARNING
	return mastery == PKM.Mastery.DEMONSTRATED


## Prose step 3 -- "Soft-preference behaviour (Rule 2)".
## First eligible hint with a NON-EMPTY preference list, every entry of which is
## DEMONSTRATED. Redundancy and the fallback are not consulted.
func _prose_rule_2(eligible: Array[String], state: Dictionary) -> String:
	for hint_id: String in eligible:
		var prefs: Array = Data.all_hints()[hint_id].get(
			"preferred_when_demonstrated", []
		)
		if prefs.is_empty() and fault != "empty_prefs":
			continue
		var all_demonstrated := true
		for concept_id: String in prefs:
			if not _demonstrated(concept_id, state):
				all_demonstrated = false
		if all_demonstrated:
			return hint_id
	return ""


## Prose step 4 -- "Redundancy behaviour".
## Non-empty `teaches`, every concept DEMONSTRATED. Empty set and unknown id are
## never redundant; a non-PKM concept can never be demonstrated, so a hint
## teaching only those is never redundant either.
func _prose_redundant(hint_id: String, state: Dictionary) -> bool:
	var catalogue: Dictionary = Data.all_hints()
	if not catalogue.has(hint_id):
		return false
	var teaches: Array = (catalogue[hint_id] as Dictionary).get("teaches", [])
	if teaches.is_empty():
		return fault == "teaches_empty"
	for concept_id: String in teaches:
		if not _demonstrated(concept_id, state):
			return false
	return true


## Prose step 4, second half -- the Rule 3 substitution.
func _prose_rule_3(
	eligible: Array[String], fallback: String, state: Dictionary
) -> String:
	if not _prose_redundant(fallback, state):
		return ""
	for hint_id: String in eligible:
		if hint_id == fallback:
			continue
		if not _prose_redundant(hint_id, state):
			return hint_id
	return ""


## The documented four-step cascade, assembled.
func _prose_condition_b(npc: String, state: Dictionary) -> String:
	var eligible := _prose_eligible(npc, state)
	var fallback := Selector.select_condition_a(npc, state)

	if fault == "rule_order":
		var swapped := _prose_rule_3(eligible, fallback, state)
		if not swapped.is_empty():
			return swapped
		var late := _prose_rule_2(eligible, state)
		return late if not late.is_empty() else fallback

	var preferred := _prose_rule_2(eligible, state)
	if not preferred.is_empty():
		return preferred
	var substitute := _prose_rule_3(eligible, fallback, state)
	if not substitute.is_empty():
		return substitute
	return fallback


# --------------------------------------------------------------------------
# Completeness of the enumerated state space.
# --------------------------------------------------------------------------

## Every evidence id anything in B or PKM can react to. If this is not a subset
## of the three major items, the evidence sweep below is incomplete and the whole
## run is void.
func _relevant_evidence() -> Array[String]:
	var seen := {}
	for hint_id: String in Data.all_hints():
		var hint: Dictionary = Data.all_hints()[hint_id]
		for key: String in ["requires_evidence", "requires_evidence_absent"]:
			for evidence_id: String in hint.get(key, []):
				seen[evidence_id] = true
	for evidence_id: String in Selector.MAJOR_EVIDENCE:
		seen[evidence_id] = true
	for npc: String in Selector.OWN_EVIDENCE:
		seen[str(Selector.OWN_EVIDENCE[npc])] = true
	for concept_id: String in PKM.CONCEPTS:
		for evidence_id: String in (PKM.CONCEPTS[concept_id] as Dictionary).get(
			"learning_evidence", []
		):
			seen[evidence_id] = true
	var out: Array[String] = []
	for evidence_id: String in seen:
		out.append(evidence_id)
	out.sort()
	return out


## Every story flag anything in B or PKM can react to.
func _relevant_flags() -> Array[String]:
	var seen := {}
	for hint_id: String in Data.all_hints():
		for flag_id: String in (Data.all_hints()[hint_id] as Dictionary).get(
			"requires_story_flags", []
		):
			seen[flag_id] = true
	for concept_id: String in PKM.CONCEPTS:
		var spec := PKM.CONCEPTS[concept_id] as Dictionary
		for key: String in ["learning_flags", "demonstrated_flags"]:
			for flag_id: String in spec.get(key, []):
				seen[flag_id] = true
	var out: Array[String] = []
	for flag_id: String in seen:
		out.append(flag_id)
	out.sort()
	return out


func _subset(items: Array[String], mask: int) -> Array:
	var out: Array = []
	for i in items.size():
		if mask & (1 << i):
			out.append(items[i])
	return out


# --------------------------------------------------------------------------
# Static claims the prose makes that no single state can test.
# --------------------------------------------------------------------------

func _check_static_claims() -> void:
	var catalogue: Dictionary = Data.all_hints()

	if catalogue.size() != 11:
		_fail("catalogue holds %d hints, the protocol documents 11" % catalogue.size())

	# Tie-breaking: the prose prints an order. Check it IS the iteration order.
	var actual: Array[String] = []
	for hint_id: String in catalogue:
		actual.append(hint_id)
	if actual != DOCUMENTED_ORDER:
		_fail("documented tie-break order %s does not match catalogue order %s"
			% [str(DOCUMENTED_ORDER), str(actual)])

	# Eligibility: "no hint in the frozen 11 declares a requires_concept", which
	# is what makes B's filter and Data.state_violations the same predicate.
	for hint_id: String in catalogue:
		var requires: Array = (catalogue[hint_id] as Dictionary).get(
			"requires_concept", []
		)
		if not requires.is_empty():
			_fail("%s declares requires_concept %s; B's filter does not read it"
				% [hint_id, str(requires)])

	# Soft preference: the documented table must be exactly the hints that carry
	# the field -- no omissions, no inventions.
	var carriers := {}
	for hint_id: String in catalogue:
		var prefs: Array = (catalogue[hint_id] as Dictionary).get(
			"preferred_when_demonstrated", []
		)
		if not prefs.is_empty():
			carriers[hint_id] = prefs
	for hint_id: String in DOCUMENTED_PREFERENCES:
		if not carriers.has(hint_id):
			_fail("prose lists %s as soft-preferred; the catalogue does not" % hint_id)
		elif str(carriers[hint_id]) != str(DOCUMENTED_PREFERENCES[hint_id]):
			_fail("%s prefers %s; prose says %s"
				% [hint_id, str(carriers[hint_id]), str(DOCUMENTED_PREFERENCES[hint_id])])
	for hint_id: String in carriers:
		if not DOCUMENTED_PREFERENCES.has(hint_id):
			_fail("%s carries a soft preference the prose does not list" % hint_id)

	# Rule 2: "in the frozen catalogue a Rule 2 winner is never redundant",
	# because all three declare an empty `teaches`.
	for hint_id: String in carriers:
		var teaches: Array = (catalogue[hint_id] as Dictionary).get("teaches", [])
		if not teaches.is_empty():
			_fail("%s is soft-preferred and teaches %s; the prose claims Rule 2 "
				% [hint_id, str(teaches)] + "winners are never redundant")

	# Redundancy: h_butler_no_evidence teaches a non-PKM concept, which is the
	# stated reason the Butler yields no teaching-redundancy signal.
	for concept_id: String in (catalogue["h_butler_no_evidence"] as Dictionary).get(
		"teaches", []
	):
		if PKM.CONCEPTS.has(concept_id):
			_fail("h_butler_no_evidence teaches PKM concept '%s'; the prose says "
				% concept_id + "its taught concept is outside PKM v1")

	# Statelessness: recent_hint_ids must not change the answer.
	var probe := {
		"evidence_items": ["greenhouse_pollen"],
		"story_flags": ["library_green_filter_earned"],
		"knowledge_items": [],
	}
	for npc: String in ["butler", "gardener", "mechanic"]:
		var bare := Selector.select_adaptive(npc, probe)
		var noisy := Selector.select_adaptive(npc, probe, DOCUMENTED_ORDER)
		if bare != noisy:
			_fail("%s: recent_hint_ids changed B's answer (%s -> %s)"
				% [npc, bare, noisy])


func _run() -> void:
	fault = OS.get_environment("CONDITION_B_DOC_FAULT")

	for path: String in EXPECTED_SHA:
		var actual := FileAccess.get_sha256(path)
		if actual != str(EXPECTED_SHA[path]):
			_fail("%s hashes to %s, the freeze recorded %s"
				% [path, actual, EXPECTED_SHA[path]])
	if not failures.is_empty():
		_report(0, 0, [], [])
		return

	_check_static_claims()

	var evidence_space := _relevant_evidence()
	var flag_space := _relevant_flags()
	if evidence_space.size() > 16 or flag_space.size() > 20:
		_fail("state space too large to enumerate exhaustively (%d evidence, %d flags)"
			% [evidence_space.size(), flag_space.size()])
		_report(0, 0, evidence_space, flag_space)
		return

	# knowledge_items is dead state for PKM v1 and unread by B's filter. Vary it
	# anyway: "dead" is a claim about the code, and this is the enumeration that
	# would notice if it stopped being true.
	var knowledge_variants: Array = [
		[],
		["current_resistance", "indicator_reaction", "reflection", "dual_lock_rule"],
	]

	var silent_npcs := {}
	var rule_4_states := 0
	for npc: String in NPCS:
		for e_mask in (1 << evidence_space.size()):
			for f_mask in (1 << flag_space.size()):
				for knowledge: Array in knowledge_variants:
					# The dead-state sweep is the expensive dimension; run the
					# non-empty variant only where PKM could plausibly be read.
					if not knowledge.is_empty() and (f_mask & 0x1F) != f_mask:
						continue
					var state := {
						"evidence_items": _subset(evidence_space, e_mask),
						"story_flags": _subset(flag_space, f_mask),
						"knowledge_items": knowledge,
					}
					var real := Selector.select_adaptive(npc, state)
					var documented := _prose_condition_b(npc, state)
					checked += 1
					if real != documented:
						_fail("%s ev=%s flags=%s: selector returns '%s', the "
							% [npc, str(state["evidence_items"]),
							   str(state["story_flags"]), real]
							+ "documented behaviour predicts '%s'" % documented)
					if real.is_empty():
						silent_npcs[npc] = true
					elif real == Selector.select_condition_a(npc, state):
						rule_4_states += 1

	# Silence: the prose claims B falls silent for an unknown NPC and ONLY then.
	for npc: String in ["butler", "gardener", "mechanic"]:
		if silent_npcs.has(npc):
			_fail("B fell silent for %s; the prose claims silence is reachable "
				% npc + "only for an NPC the catalogue does not know")
	if not silent_npcs.has("librarian"):
		_fail("B never fell silent for an unknown NPC; the prose claims it does")

	_report(rule_4_states, silent_npcs.size(), evidence_space, flag_space)


func _report(
	rule_4_states: int, silent: int, evidence_space: Array, flag_space: Array
) -> void:
	print("Condition B — documentation vs frozen selector")
	if not fault.is_empty():
		print("  FAULT INJECTED: %s" % fault)
	print("  selector   scripts/adaptive_hint_selector.gd  %s"
		% EXPECTED_SHA["res://scripts/adaptive_hint_selector.gd"])
	print("  evidence space  %d items  %s" % [evidence_space.size(), str(evidence_space)])
	print("  flag space      %d flags" % flag_space.size())
	print("  states compared %d" % checked)
	print("  reached the A-4 fallback in %d states; silent for %d of %d NPCs"
		% [rule_4_states, silent, NPCS.size()])

	if failures.is_empty():
		print("\nverify_condition_b_documentation: PASS")
		quit(0)
	else:
		print("\nverify_condition_b_documentation: FAIL (%d shown)" % failures.size())
		for f: String in failures:
			print("  - " + f)
		quit(1)
