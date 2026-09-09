class_name PlayerKnowledgeModel
extends RefCounted

## PKM v1 — a read-only interpretation layer over state the game already tracks.
##
## Nothing here is stored. Every value is DERIVED on demand from
## GameState.story_flags / evidence_items, so this adds no save field, needs no
## migration, and cannot desynchronise from the systems it reads. Deleting this
## file would change no gameplay.
##
## It answers one question the shipped state cannot answer directly: has the
## player completed the game's designated comprehension check for a concept, or
## merely passed through the content?
##
##
## WHAT "DEMONSTRATED" MEANS HERE — READ THIS BEFORE QUOTING ANY RESULT
##
## DEMONSTRATED means the player has successfully completed the game's existing
## designated comprehension check for that concept.
##
## It does NOT mean:
##   * first-attempt correctness
##   * independent mastery
##   * validated learning
##   * long-term retention
##
## It is an OPERATIONAL GAME-STATE PROXY, not a validated measure of
## educational mastery. Every check in this project allows unlimited retries
## with fixed content, and most reveal the governing rule on failure:
##
##   * chemistry sorting  — prints the authored `why_en` for a wrong item
##                          (change_sorting_minigame.gd:367)
##   * library challenges — the failure message states the rule
##                          (library_light_challenge_ui.gd:352, :365, :372)
##   * circuit benches    — the stage lesson is permanently on screen
##                          (circuit_lab_ui.gd:2180)
##   * butler test        — no hint, but 4 options and unlimited retries
##                          (door_puzzle_ui.gd:234)
##
## No challenge in the project records attempts, timings, or assistance. These
## are DOCUMENTED LIMITATIONS of PKM v1, not defects to be fixed here. See
## docs/ADAPTIVE_HINTS_PLAN.md "Future work" for the assessment redesign that
## would be needed to make a mastery claim.


enum Mastery {
	UNSEEN,        ## no recorded contact with the concept
	LEARNING,      ## contacted or filed, but no comprehension check completed
	DEMONSTRATED,  ## the game's designated comprehension check was completed
	ASSISTED,      ## allowed to continue after help, without completing a check
}

## ASSISTED IS CURRENTLY UNREACHABLE, AND THAT IS INTENTIONAL.
##
## A source audit found no challenge that writes any state on a wrong answer,
## and no hint / explain-then-continue path that records itself:
##
##   * Butler test        — wrong answer writes nothing (chemistry_room.gd:1553)
##   * Sorting minigame   — partial clear writes nothing (chemistry_room.gd:477)
##   * Door locks         — wrong answer writes nothing (game_world.gd:5646)
##   * Library challenges — no failure signal exists (library_light_challenge_ui.gd:4-5)
##   * Circuit benches    — no failure signal
##
## The one historical fail-forward path, explain_red_stain_without_reward()
## (game_world.gd:4037), is unreachable — orphaned by commit 505f008.
##
## So the enum reserves ASSISTED and no mapping produces it. Inferring it from
## existing flags would be inventing data.
const ASSISTED_REQUIRES_NEW_STATE: bool = true


## Concept map.
##
## Concept ids are chosen from the AUTHORED CONTENT of each check, not from the
## flag name. Every `demonstrated_flags` entry is a flag whose only writer is
## the successful completion of that specific check.
##
## Concepts are deliberately NARROW. Two checks are mapped to the same concept
## only when they assess the same authored material — which, in this project,
## never happens.
const CONCEPTS: Dictionary = {
	# ---------------------------------------------------------------- chemistry
	## The Butler's test asks one question about one stain:
	##   "What is that red stain by the alchemy table?"
	##   correct: "An indicator reacted with a basic cleaner"
	##   (chemistry_room.gd:1540-1546, correct index 1)
	## That is reaction identification for a specific observed residue. It is
	## NOT the physical/chemical classification rule, so it is a separate
	## concept from `physical_chemical_change` below.
	"indicator_reaction": {
		"label": "Identifying an indicator/base reaction",
		## Holding the stain is exposure: the live path grants it after three
		## button presses and asks nothing (chemistry_room.gd:1406-1422).
		"learning_flags": ["mrs_lin_lab_note_seen"],
		"learning_evidence": ["fake_red_stain"],
		## Written only in on_butler_test_correct() (chemistry_room.gd:1579),
		## reached only when DoorPuzzleUI reports the correct index
		## (door_puzzle_ui.gd:222 -> cb.call(true)).
		"demonstrated_flags": ["butler_challenge_complete"],
	},
	## The sorting tray states its own rule in the subtitle
	## (chemistry_room.gd:456): "A change is chemical only when a new substance
	## appears." Sixteen samples are classified across eight levels. This is the
	## classification rule, not one reaction.
	"physical_chemical_change": {
		"label": "Classifying physical vs chemical change",
		"learning_flags": ["mrs_lin_lab_note_seen"],
		## Written only when the minigame reports cleared_all
		## (chemistry_room.gd:469-470), which minigame_shell.gd:355 defines as
		## every level cleared.
		"demonstrated_flags": ["chemistry_change_sorted"],
	},

	# ------------------------------------------------------------------ library
	## Filing a shelf record is a button press, not an answer
	## (library_knowledge_shelf_ui.gd:86-91) -> exposure only.
	"spectrum": {
		"label": "Visible spectrum and wavelength",
		"learning_flags": ["library_spectrum_knowledge_learned"],
		## Emitted only from _complete_challenge(), reached only on a correct
		## submission (library_light_challenge_ui.gd:396), then written by
		## _on_light_challenge_completed() (library_room.gd:845).
		"demonstrated_flags": ["library_red_filter_earned"],
	},
	"reflection": {
		"label": "Reflection, absorption and colour",
		"learning_flags": ["library_reflection_knowledge_learned"],
		"demonstrated_flags": ["library_green_filter_earned"],
	},
	"additive": {
		"label": "Additive colour mixing",
		"learning_flags": ["library_additive_knowledge_learned"],
		"demonstrated_flags": ["library_blue_filter_earned"],
	},

	# ------------------------------------------------------------------ circuit
	## The three benches are separate authored checks with separate titles and
	## separate lesson sets (circuit_lab_ui.gd:2172-2177). Mapping any one of
	## them to a broad "current and resistance" concept would report a
	## demonstration the player never made, so each bench gets its own concept.
	##
	## Bench I — CONTINUITY. Lessons concern conduction and series paths:
	##   "A series run conducts only if every link conducts." (:616)
	##   "A blown fuse is not a component any more. It is a gap." (:630)
	"circuit_continuity": {
		"label": "Conductors, insulators and series continuity",
		"learning_flags": ["circuit_repair_map_studied"],
		## Written by _on_bench_completed() (circuit_room.gd:409-411) from the
		## lab's `completed` signal, emitted only after the final stage
		## (circuit_lab_ui.gd:2300).
		"demonstrated_flags": ["circuit_bench_continuity_cleared"],
	},
	## Bench II — REGULATION. This is the bench that actually concerns current
	## and resistance:
	##   "More resistance in series, less voltage at the lamp." (:667)
	##   "A hot filament changes its own resistance. Track the drift." (:685)
	"circuit_regulation": {
		"label": "Resistance, voltage and current regulation",
		"learning_flags": ["circuit_repair_map_studied"],
		"demonstrated_flags": ["circuit_bench_regulator_cleared"],
	},
	## Bench III — FAULT ISOLATION. The lessons describe a search strategy
	## rather than a circuit law:
	##   "Probe the middle first. Each measurement can halve what is left." (:726)
	##   "Compare drops between neighbours, not absolute readings." (:736)
	"circuit_fault_isolation": {
		"label": "Locating a fault by systematic measurement",
		"learning_flags": ["circuit_repair_map_studied"],
		"demonstrated_flags": ["circuit_bench_diagnostic_cleared"],
	},
}

## Concepts that have exposure state but no comprehension check in the game.
##
## `current_resistance` was a concept in an earlier draft of this model, mapped
## to "any circuit bench cleared". The audit showed the three benches assess
## three different topics, so that mapping reported a demonstration the player
## may never have made. The concept is not resurrected here under a broader
## name; `circuit_regulation` is the check that exists.
##
## GameState.knowledge_items is NEVER consulted. Its only writer,
## add_knowledge_item("current_resistance") at game_world.gd:5717, sits inside
## show_circuit_learning_note(), which has zero callers repo-wide — its call
## site was deleted in commit 505f008 and never restored.
const IGNORED_STATE_NOTE: String = (
	"knowledge_items is dead state and is never read by this model"
)


static func _state_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null("GameState")


static func _flag(flag_id: String) -> bool:
	var state := _state_node()
	if state == null:
		return false
	return bool(state.call("has_story_flag", flag_id))


static func _evidence(evidence_id: String) -> bool:
	var state := _state_node()
	if state == null:
		return false
	return bool(state.call("has_evidence", evidence_id))


## Knowledge state for one concept, derived from live game state.
##
## Order matters: the comprehension check is tested before exposure, so
## completing a check without filing its record still reports DEMONSTRATED.
static func state_of(concept_id: String) -> Mastery:
	if not CONCEPTS.has(concept_id):
		return Mastery.UNSEEN
	var spec := CONCEPTS[concept_id] as Dictionary

	for flag_id: String in spec.get("demonstrated_flags", []):
		if _flag(flag_id):
			return Mastery.DEMONSTRATED

	for flag_id: String in spec.get("learning_flags", []):
		if _flag(flag_id):
			return Mastery.LEARNING
	for evidence_id: String in spec.get("learning_evidence", []):
		if _evidence(evidence_id):
			return Mastery.LEARNING

	return Mastery.UNSEEN


static func is_demonstrated(concept_id: String) -> bool:
	return state_of(concept_id) == Mastery.DEMONSTRATED


## Pure variant of `state_of` that evaluates an explicit state instead of the
## live GameState autoload.
##
## Added so redundancy analysis can be computed over a scenario table without a
## running game, while keeping the concept mapping single-sourced here. It
## duplicates no data and changes no existing behaviour: `state_of` above is
## untouched, and this returns the same answer for the same state.
static func state_in(
	concept_id: String,
	knowledge_items: Array,
	story_flags: Array,
	evidence_items: Array
) -> Mastery:
	if not CONCEPTS.has(concept_id):
		return Mastery.UNSEEN
	var spec := CONCEPTS[concept_id] as Dictionary

	for flag_id: String in spec.get("demonstrated_flags", []):
		if story_flags.has(flag_id):
			return Mastery.DEMONSTRATED

	for flag_id: String in spec.get("learning_flags", []):
		if story_flags.has(flag_id):
			return Mastery.LEARNING
	for evidence_id: String in spec.get("learning_evidence", []):
		if evidence_items.has(evidence_id):
			return Mastery.LEARNING

	return Mastery.UNSEEN


static func is_demonstrated_in(
	concept_id: String,
	knowledge_items: Array,
	story_flags: Array,
	evidence_items: Array
) -> bool:
	return state_in(
		concept_id, knowledge_items, story_flags, evidence_items
	) == Mastery.DEMONSTRATED


## True when the player has met the concept but not completed its check — the
## case where explaining it again is useful rather than redundant.
static func needs_teaching(concept_id: String) -> bool:
	var state := state_of(concept_id)
	return state == Mastery.UNSEEN or state == Mastery.LEARNING


static func state_name(state: Mastery) -> String:
	match state:
		Mastery.UNSEEN: return "UNSEEN"
		Mastery.LEARNING: return "LEARNING"
		Mastery.DEMONSTRATED: return "DEMONSTRATED"
		Mastery.ASSISTED: return "ASSISTED"
	return "UNKNOWN"


## Whole-model snapshot, for tests and debugging. Not used by gameplay.
static func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for concept_id: String in CONCEPTS:
		out[concept_id] = state_name(state_of(concept_id))
	return out
