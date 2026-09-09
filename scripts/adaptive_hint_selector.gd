class_name AdaptiveHintSelector
extends RefCounted

## Preloaded rather than referenced by its global class_name: this script is
## loaded directly by a --script harness, which can run before the editor has
## registered class_name globals for a newly added file.
const Data := preload("res://scripts/adaptive_hint_data.gd")
const PlayerKnowledgeModelScript := preload("res://scripts/player_knowledge_model.gd")

## Conditions A and B of the adaptive-guidance experiment.
##
## Neither is wired into gameplay. Both are pure functions of player state, so
## the harness can drive them over a scenario table without running a scene.
##
## Condition A is `select_condition_a` below (policy A-4). Condition B is
## `select_adaptive`, which is deterministic and uses no model: if a handful of
## rules already removes the redundancy, that is the finding, and it should not
## be hidden.


## Major suspect evidence. The three items that mark investigative depth, one
## belonging to each questionable character.
const MAJOR_EVIDENCE: Array[String] = [
	"fake_red_stain",
	"greenhouse_pollen",
	"deliberate_short_circuit",
]

## Which major evidence item belongs to which character.
const OWN_EVIDENCE: Dictionary = {
	"butler": "fake_red_stain",
	"gardener": "greenhouse_pollen",
	"mechanic": "deliberate_short_circuit",
}

## Condition A-4 selection table, frozen. Tier 3 is the character's
## introductory line: the foundational teaching hint where one exists, and the
## generic deflection for the Butler, who deliberately has none.
const CONDITION_A_TIERS: Dictionary = {
	"butler": {
		1: "h_butler_stain",
		2: "h_butler_knows_rule",
		3: "h_butler_no_evidence",
	},
	"gardener": {
		1: "h_gardener_pollen",
		2: "h_gardener_knows_reflection",
		3: "h_gardener_leaf_colour",
	},
	"mechanic": {
		1: "h_mechanic_short_circuit",
		2: "h_mechanic_knows_resistance",
		3: "h_mechanic_series_basics",
	},
}


## CONDITION A-4 -- Evidence-depth Static Baseline. FROZEN.
##
## Tier 1: the character's own major evidence is in hand   -> evidence response
## Tier 2: their evidence is absent but another major item
##         is held, so the investigation has moved on      -> higher-level line
## Tier 3: no major evidence at all, i.e. early            -> introductory line
##
## Properties this function must keep, and which the test suite pins:
##   * never reads PlayerKnowledgeModel, in any form;
##   * never reads `preferred_when_demonstrated`;
##   * deterministic and stateless -- no delivery history, so scenario
##     iteration order cannot change its output;
##   * no tunable threshold or free parameter.
##
## An earlier candidate policy keyed on `door_circuit_unlocked`, which the
## heldout-v2 room repair makes universal for the Mechanic; that policy would
## have degenerated to a single branch. A-4 keys only on evidence, which the
## room repair never touches, so it is immune to that class of failure.
static func select_condition_a(npc: String, state: Dictionary) -> String:
	if not CONDITION_A_TIERS.has(npc):
		return ""
	var evidence: Array = state.get("evidence_items", [])
	var tiers := CONDITION_A_TIERS[npc] as Dictionary

	if evidence.has(str(OWN_EVIDENCE[npc])):
		return str(tiers[1])
	for evidence_id: String in MAJOR_EVIDENCE:
		if evidence.has(evidence_id):
			return str(tiers[2])
	return str(tiers[3])


## Superseded baseline, retained for development-history continuity only.
##
## This replicated the branching in game_world.gd:4258/:4378/:4501, which a
## source audit later showed to be unreachable dead code -- commit 505f008
## removed the dispatch. It is NOT Condition A. Use `select_condition_a`.
static func select_static(npc: String, state: Dictionary) -> String:
	var evidence: Array = state.get("evidence_items", [])
	match npc:
		"butler":
			return (
				"h_butler_stain"
				if evidence.has("fake_red_stain")
				else "h_butler_no_evidence"
			)
		"gardener":
			return (
				"h_gardener_pollen"
				if evidence.has("greenhouse_pollen")
				else "h_gardener_no_evidence"
			)
		"mechanic":
			return (
				"h_mechanic_short_circuit"
				if evidence.has("deliberate_short_circuit")
				else "h_mechanic_no_evidence"
			)
	return ""


## Condition B -- deterministic adaptive selection.
##
## CONDITION B -- PKM-aware deterministic selector.
##
## B sees the exact same 11-hint catalogue as A and C. It differs from A only
## in that it may read PlayerKnowledgeModel state and the soft
## `preferred_when_demonstrated` field. That is the whole treatment: any
## measured A-vs-B difference is attributable to knowledge-awareness, not to
## content or eligibility.
##
## Rules, in order:
##   1. Consider only hints that are state-eligible (hard prerequisites hold).
##   2. Prefer a hint whose `preferred_when_demonstrated` concept the player has
##      actually DEMONSTRATED -- this is where PKM enters.
##   3. Avoid delivering a foundational hint whose entire `teaches` set the
##      player has already demonstrated; that is redundant guidance, and
##      avoiding it is the behaviour under test.
##   4. Otherwise fall back to the A-4 tier choice. Saying something slightly
##      imperfect beats saying nothing.
##
## Stateless like A: `recent_hint_ids` is accepted for call-site compatibility
## but is NOT used to choose, so scenario order cannot change B's output.
static func select_adaptive(
	npc: String,
	state: Dictionary,
	recent_hint_ids: Array = []
) -> String:
	var knowledge: Array = state.get("knowledge_items", [])
	var flags: Array = state.get("story_flags", [])
	var evidence: Array = state.get("evidence_items", [])
	var fallback := select_condition_a(npc, state)
	var catalogue: Dictionary = Data.all_hints()

	var eligible: Array = []
	for hint_id: String in catalogue:
		var hint := catalogue[hint_id] as Dictionary
		if str(hint.get("npc", "")) != npc:
			continue
		if not _evidence_matches(hint, evidence):
			continue
		if not _story_flags_match(hint, flags):
			continue
		eligible.append(hint_id)

	# Rule 2 -- the PKM treatment. A hint marked as especially apt once a
	# concept is demonstrated wins when that concept is in fact demonstrated.
	for hint_id: String in eligible:
		var hint := catalogue[hint_id] as Dictionary
		var prefs: Array = hint.get("preferred_when_demonstrated", [])
		if prefs.is_empty():
			continue
		var all_demonstrated := true
		for concept_id: String in prefs:
			if not PlayerKnowledgeModelScript.is_demonstrated_in(
				concept_id, knowledge, flags, evidence
			):
				all_demonstrated = false
				break
		if all_demonstrated:
			return hint_id

	# Rule 3 -- do not re-teach what the player has already demonstrated. If the
	# fallback would be redundant, look for an eligible alternative that is not.
	if _is_redundant(fallback, knowledge, flags, evidence):
		for hint_id: String in eligible:
			if hint_id != fallback and not _is_redundant(
				hint_id, knowledge, flags, evidence
			):
				return hint_id

	return fallback


static func _evidence_matches(hint: Dictionary, evidence: Array) -> bool:
	for evidence_id: String in hint.get("requires_evidence", []):
		if not evidence.has(evidence_id):
			return false
	for evidence_id: String in hint.get("requires_evidence_absent", []):
		if evidence.has(evidence_id):
			return false
	return true


## Story/context prerequisites, checked alongside evidence.
##
## A hint whose required story flag is unset is STATE-INELIGIBLE and must not be
## offered: a character cannot say "you already know how this castle works" to a
## player who never saw that tutorial.
##
## These are deliberately not knowledge concepts. Satisfying one says nothing
## about comprehension, and nothing here feeds redundancy analysis, which reads
## PlayerKnowledgeModel state only.
static func _story_flags_match(hint: Dictionary, flags: Array) -> bool:
	for flag_id: String in hint.get("requires_story_flags", []):
		if not flags.has(flag_id):
			return false
	return true


## REDUNDANCY -- judged by PlayerKnowledgeModel only, per the frozen protocol.
##
## A hint is redundant when every concept in its `teaches` set is already
## DEMONSTRATED. A hint that teaches nothing can be repetitive but is never
## redundant; the two are measured separately.
##
## Concepts outside PKM v1 -- notably `dual_lock_rule` -- can never be
## demonstrated, so a hint teaching only those is never redundant. That is why
## the Butler contributes no teaching-redundancy signal, which is an accepted
## and documented limitation rather than an oversight.
static func _is_redundant(
	hint_id: String,
	knowledge: Array,
	flags: Array,
	evidence: Array = []
) -> bool:
	var hints: Dictionary = Data.all_hints()
	if not hints.has(hint_id):
		return false
	var teaches: Array = (hints[hint_id] as Dictionary).get("teaches", [])
	if teaches.is_empty():
		return false
	for concept_id: String in teaches:
		if not PlayerKnowledgeModelScript.is_demonstrated_in(
			concept_id, knowledge, flags, evidence
		):
			return false
	return true


static func is_redundant(hint_id: String, state: Dictionary) -> bool:
	return _is_redundant(
		hint_id,
		state.get("knowledge_items", []),
		state.get("story_flags", []),
		state.get("evidence_items", [])
	)


## True when a hint's `teaches` set names at least one real PKM v1 concept.
## This is the denominator condition for the RedundantWhenTeachable sensitivity
## metric: it excludes hints that teach nothing, and hints whose only taught
## concept is outside PKM, so neither can dilute the measure.
static func teaches_pkm_concept(hint_id: String) -> bool:
	var hints: Dictionary = Data.all_hints()
	if not hints.has(hint_id):
		return false
	for concept_id: String in (hints[hint_id] as Dictionary).get("teaches", []):
		if PlayerKnowledgeModelScript.CONCEPTS.has(concept_id):
			return true
	return false
