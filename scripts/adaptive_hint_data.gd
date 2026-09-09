class_name AdaptiveHintData
extends RefCounted

## Hint catalogue and concept map for the adaptive-guidance experiment.
##
## Every id here is real. Evidence ids, story flags and knowledge ids were
## audited out of the shipped game; see docs/ADAPTIVE_HINTS_AUDIT.md for where
## each one is set and how to re-derive the lists.
##
## Nothing in this file is wired into gameplay. It is read by the experiment
## harness (tests/adaptive_hint_baseline_test.gd) only.


## The audit's central finding: "what the player has demonstrated" is split
## across two stores. Only current_resistance reaches GameState.knowledge_items;
## the library's three concepts are recorded as story flags by
## library_room.gd:740, and several other concepts are marked by teaching flags.
##
## A selector that reads knowledge_items alone sees one concept out of eleven.
const CONCEPTS: Dictionary = {
	"dual_lock_rule": {
		"label": "A door needs both a key and an answer",
		"flag": "dual_lock_rule_taught",
	},
	"spectrum": {
		"label": "Visible spectrum and wavelength",
		"flag": "library_spectrum_knowledge_learned",
	},
	"reflection": {
		"label": "Reflection, absorption and colour",
		"flag": "library_reflection_knowledge_learned",
	},
	"additive": {
		"label": "Additive colour mixing",
		"flag": "library_additive_knowledge_learned",
	},
	"current_resistance": {
		"label": "Current, resistance and conductors",
		"knowledge_item": "current_resistance",
	},
	"refining": {
		"label": "Refining procedure",
		"flag": "greenhouse_refining_learned",
	},
	"circuit_map": {
		"label": "The castle circuit map",
		"flag": "gardener_circuit_map_explained",
	},
	"blackout_deliberate": {
		"label": "The blackout was deliberate",
		"flag": "blackout_deliberate",
	},
	"dining_timeline": {
		"label": "Timeline reconstruction",
		"flag": "dining_timeline_reconstructed",
	},
	"repair_map": {
		"label": "The circuit repair map",
		"flag": "circuit_repair_map_studied",
	},
	"first_route": {
		"label": "The opening route",
		"flag": "hall_first_route_core_studied",
	},
}

## The matched experimental hint catalogue -- 11 hints, shared UNCHANGED by
## Conditions A, B and C so that any measured difference is attributable to
## selection policy rather than to content.
##
## PROVENANCE MATTERS HERE. These six lines are quoted verbatim from
## game_world.gd, but a source audit established that the functions containing
## them -- show_butler_dialogue() (:4258), show_gardener_dialogue() (:4378) and
## show_mechanic_dialogue() (:4501) -- have NO callers. Commit 505f008 deleted
## the dispatch that invoked them, the same commit that orphaned
## show_clue_intro() and show_circuit_learning_note().
##
## They are therefore `legacy-grounded`: the wording is real and
## source-grounded, but the code path is unreachable. They must NEVER be
## described as shipped, live, or current product behaviour. The reachable
## NPC dialogue lives in chemistry_room.gd:1461, greenhouse_room.gd:1105 and
## circuit_room.gd:544, and is tracked separately as R (Live Product
## Reference), which is descriptive context only.
const LEGACY_GROUNDED_HINTS: Dictionary = {
	"h_butler_no_evidence": {
		"npc": "butler",
		"source": "legacy_grounded",
		"requires_evidence_absent": ["fake_red_stain"],
		## NOTE: dual_lock_rule is NOT a PKM v1 concept, so this entry can never
		## make the hint redundant under PKM semantics. It is retained because
		## the text genuinely does re-teach that rule; removing it would be
		## metadata not following semantics. The consequence -- that Butler
		## contributes no teaching-redundancy signal -- is accepted and
		## documented rather than papered over.
		"teaches": ["dual_lock_rule"],
		"text": "I was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms.",
	},
	"h_butler_stain": {
		"npc": "butler",
		"source": "legacy_grounded",
		"requires_evidence": ["fake_red_stain"],
		"teaches": [],
		"text": "I already told you, I only cleaned the hallway. That red stain has nothing to do with me.",
	},
	"h_gardener_no_evidence": {
		"npc": "gardener",
		"source": "legacy_grounded",
		"requires_evidence_absent": ["greenhouse_pollen"],
		"teaches": [],
		"text": "I was working near the greenhouse earlier. I did not enter the locked rooms.",
	},
	"h_gardener_pollen": {
		"npc": "gardener",
		"source": "legacy_grounded",
		"requires_evidence": ["greenhouse_pollen"],
		"teaches": [],
		"text": "Pollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything.",
	},
	"h_mechanic_no_evidence": {
		"npc": "mechanic",
		"source": "legacy_grounded",
		"requires_evidence_absent": ["deliberate_short_circuit"],
		"teaches": [],
		"text": "The lights in this castle fail all the time. Old wiring, old walls, old problems.",
	},
	"h_mechanic_short_circuit": {
		"npc": "mechanic",
		"source": "legacy_grounded",
		"requires_evidence": ["deliberate_short_circuit"],
		"teaches": [],
		"text": "A short circuit? I maintain the castle wiring, but anyone could have damaged that panel.",
	},
}

## Hints authored by this project, grounded strictly in LIVE reachable content.
##
## Two kinds appear here:
##
##   * FOUNDATIONAL -- carries `teaches` naming a real PKM v1 concept, because
##     the text genuinely explains that concept. These are the only hints that
##     can ever be judged redundant under PKM semantics.
##   * HIGHER-LEVEL -- carries `preferred_when_demonstrated`, a SOFT preference
##     meaning the line is especially apt once the concept is demonstrated. It
##     is not a prerequisite: the text asserts nothing about the player, so it
##     stays factually true whatever the PKM state.
##
## An earlier draft of these lines asserted player experience ("you have been
## reading...", "you have had your hands on the bench..."), which was false in
## states where the concept was not demonstrated, and one invented a wet
## hallway floor that exists nowhere in the game. Both faults are removed: every
## line below is a first-person observation by the character about the world.
const AUTHORED_HINTS: Dictionary = {
	## Butler has NO foundational teaching hint, deliberately. He personally
	## administers the indicator_reaction comprehension check
	## (chemistry_room.gd:1534), so a Butler who explains the answer as a
	## fallback would defeat his own test. Symmetry is not a sufficient reason
	## to manufacture one.
	"h_butler_knows_rule": {
		"npc": "butler",
		"source": "authored",
		"requires_evidence_absent": ["fake_red_stain"],
		"preferred_when_demonstrated": ["indicator_reaction"],
		"teaches": [],
		## Grounds: chemistry_room.gd:1514-1516 -- "I heard glass break in this
		## room, and footsteps -- quick, heavy ones -- heading toward the
		## greenhouse wing." Corroborated by the stain evidence, which records a
		## broken bottle (game_world.gd:4527).
		##
		## "in this room" is deictic and correct only when delivered in the
		## Chemistry Room, which heldout-v2 room semantics guarantee.
		"text": "I heard glass break in this room, followed by quick, heavy footsteps heading toward the greenhouse wing.",
	},
	"h_gardener_leaf_colour": {
		"npc": "gardener",
		"source": "authored",
		## No hard prerequisites: the science is true regardless of evidence, so
		## gating it would be metadata not following semantics.
		"teaches": ["reflection"],
		## Grounds: library_knowledge_shelf_ui.gd:27 -- "A healthy green leaf
		## contains pigments that absorb much of the red and blue light... More
		## green light is reflected toward the observer, so the leaf appears
		## green. Visible color is evidence of reflection -- not absorption."
		##
		## Deliberately omits the operational "RED: absorb / GREEN: reflect /
		## BLUE: absorb" field reference, which is the Reflection Matrix answer
		## key. The terminal is gated on having filed the record
		## (library_room.gd:810), so no puzzle bypass is created.
		"text": "You want to know why my beds look the way they do? A healthy leaf takes in the red and blue light and throws the green back at you. What reaches your eye is the light it did not keep.",
	},
	"h_gardener_knows_reflection": {
		"npc": "gardener",
		"source": "authored",
		"requires_evidence_absent": ["greenhouse_pollen"],
		"preferred_when_demonstrated": ["reflection"],
		"teaches": [],
		## Grounds: greenhouse_room.gd:1110-1112 -- "That dark pollen does not
		## [belong]... who carried deep-room traces into my greenhouse"; and the
		## torn note (case_script_zh.gd:37) -- "the deep-room kind, not from any
		## plant here -- clings to the tool handles."
		"text": "That dark pollen is the wrong kind for anything I grow here. Something carried deep-room traces onto my tools.",
	},
	"h_mechanic_series_basics": {
		"npc": "mechanic",
		"source": "authored",
		## No hard prerequisites, for the same reason as the Gardener's.
		"teaches": ["circuit_continuity"],
		## Grounds: circuit_lab_ui.gd:616 -- "A series run conducts only if every
		## link conducts"; and :623 -- "A resistor limits current. It is still a
		## conductor." Stating a principle gives no bench stage solution, so
		## there is no premature-answer risk.
		"text": "Castle wiring runs in series. Every link has to conduct or the whole run stays dark — and a resistor still counts as a conductor, it only slows the current. That is the first thing anyone learns at my bench.",
	},
	"h_mechanic_knows_resistance": {
		"npc": "mechanic",
		"source": "authored",
		"requires_evidence_absent": ["deliberate_short_circuit"],
		## Semantically correct rather than experimentally tidy: this line is a
		## fault-LOCALISATION claim ("did not start here"), which is Bench III's
		## skill (circuit_lab_ui.gd:721, :726) -- not the continuity taught by
		## h_mechanic_series_basics. Aligning the two for a cleaner contrast
		## would be metadata bending to the experiment.
		##
		## The id is HISTORICAL and now misleading: the hint no longer concerns
		## knowledge of resistance. It is retained so earlier development
		## results remain traceable to the same identifier.
		"preferred_when_demonstrated": ["circuit_fault_isolation"],
		"teaches": [],
		## Grounds: circuit_room.gd:545-547, verbatim. The generator is a real
		## circuit-room object (circuit_room.gd:30, :107-111).
		"text": "The blackout did not start at these generators. Someone came through the workshop's maintenance route and left them to take the blame.",
	},
}


static func all_hints() -> Dictionary:
	var merged: Dictionary = {}
	for hint_id: String in LEGACY_GROUNDED_HINTS:
		merged[hint_id] = LEGACY_GROUNDED_HINTS[hint_id]
	for hint_id: String in AUTHORED_HINTS:
		merged[hint_id] = AUTHORED_HINTS[hint_id]
	return merged


## True when the player holds a concept, checking whichever store the audit
## found it in. Unknown concept ids return false rather than throwing, so a
## typo degrades to "not known" instead of aborting an experiment run -- but
## `known_concepts` below is the safer entry point for that reason.
static func player_knows(
	concept_id: String,
	knowledge_items: Array,
	story_flags: Array
) -> bool:
	if not CONCEPTS.has(concept_id):
		return false
	var spec := CONCEPTS[concept_id] as Dictionary
	if spec.has("knowledge_item"):
		return knowledge_items.has(str(spec["knowledge_item"]))
	if spec.has("flag"):
		return story_flags.has(str(spec["flag"]))
	return false


static func known_concepts(knowledge_items: Array, story_flags: Array) -> Array:
	var known: Array = []
	for concept_id: String in CONCEPTS:
		if player_knows(concept_id, knowledge_items, story_flags):
			known.append(concept_id)
	return known


## Reachability rules, derived from where the game actually sets each piece of
## state. A scenario that violates one of these describes a save file no player
## can produce, so any metric measured on it is measuring nothing.
##
## This exists because the audit hit the problem for real: an early draft
## hypothesised a state with blackout_deliberate but no deliberate_short_circuit,
## which circuit_room.gd:609-610 makes impossible.
##
## Each rule is [description, required, implied_by] -- holding `implied_by`
## requires also holding everything in `required`.
const REACHABILITY_RULES: Array = [
	{
		"why": "circuit_room.gd:609-610 sets both on adjacent lines.",
		"if_flag": "blackout_deliberate",
		"then_evidence": ["deliberate_short_circuit"],
	},
	{
		"why": "The same two lines run together in the other direction.",
		"if_evidence": "deliberate_short_circuit",
		"then_flags": ["blackout_deliberate"],
	},
	{
		"why": "library_room.gd:740 records these only from the shelf UI, which exists inside the library; the library door is opened by its knowledge lock at game_world.gd:5636.",
		"if_flag": "library_spectrum_knowledge_learned",
		"then_flags": ["door_library_unlocked"],
	},
	{
		"why": "Same shelf, same door.",
		"if_flag": "library_reflection_knowledge_learned",
		"then_flags": ["door_library_unlocked"],
	},
	{
		"why": "Same shelf, same door.",
		"if_flag": "library_additive_knowledge_learned",
		"then_flags": ["door_library_unlocked"],
	},
	{
		"why": "library_room.gd gates the RGB puzzle behind all three colour concepts.",
		"if_flag": "library_rgb_puzzle_solved",
		"then_flags": [
			"library_spectrum_knowledge_learned",
			"library_reflection_knowledge_learned",
			"library_additive_knowledge_learned",
		],
	},
	{
		"why": "current_resistance is granted by show_circuit_learning_note() at game_world.gd:5717, reached through the circuit door opened at game_world.gd:5627.",
		"if_knowledge": "current_resistance",
		"then_flags": ["door_circuit_unlocked"],
	},
	{
		"why": "The opening teaches the dual-lock rule (wake_room.gd:2306) before any knowledge lock can be answered, and every door_*_unlocked flag comes from answering one (game_world.gd:5625-5638).",
		"if_flag": "door_library_unlocked",
		"then_flags": ["dual_lock_rule_taught"],
	},
	{
		"why": "Same reason: a door opens only by answering its knowledge lock.",
		"if_flag": "door_circuit_unlocked",
		"then_flags": ["dual_lock_rule_taught"],
	},
	{
		"why": "Same reason.",
		"if_flag": "door_greenhouse_unlocked",
		"then_flags": ["dual_lock_rule_taught"],
	},
]


## Does a delivered hint contradict the state it was delivered into?
##
## Every hint declares its own preconditions. A violation means the selector
## produced a line whose stated conditions do not hold -- the NPC saying "I
## haven't seen that stain" to a player holding the stain.
##
## This is the guard that catches a selector reaching for an authored hint
## because it scores well, without checking that the hint still applies. It
## complements Coverage: coverage catches saying too little, this catches
## saying something false.
static func state_violations(
	hint_id: String,
	knowledge_items: Array,
	story_flags: Array,
	evidence_items: Array
) -> Array:
	var hints := all_hints()
	if not hints.has(hint_id):
		return ["unknown hint '%s'" % hint_id]

	var hint := hints[hint_id] as Dictionary
	var problems: Array = []

	for evidence_id: String in hint.get("requires_evidence", []):
		if not evidence_items.has(evidence_id):
			problems.append(
				"%s requires evidence '%s', which the player does not hold"
				% [hint_id, evidence_id]
			)
	for evidence_id: String in hint.get("requires_evidence_absent", []):
		if evidence_items.has(evidence_id):
			problems.append(
				"%s requires evidence '%s' to be absent, but the player holds it"
				% [hint_id, evidence_id]
			)
	for concept_id: String in hint.get("requires_concept", []):
		if not player_knows(concept_id, knowledge_items, story_flags):
			problems.append(
				"%s requires concept '%s', which the player has not demonstrated"
				% [hint_id, concept_id]
			)
	## Story/context prerequisites. These constrain whether a line is
	## contextually appropriate — for example, a character may not say "you
	## already know how this castle works" to a player who never saw that
	## tutorial. They are deliberately NOT knowledge concepts: satisfying one
	## implies nothing about comprehension, and they take no part in redundancy
	## analysis, which reads PlayerKnowledgeModel state only.
	for flag_id: String in hint.get("requires_story_flags", []):
		if not story_flags.has(flag_id):
			problems.append(
				"%s requires story flag '%s', which is not set"
				% [hint_id, flag_id]
			)
	return problems


## Returns a list of human-readable violations; empty means reachable.
static func reachability_violations(
	knowledge_items: Array,
	story_flags: Array,
	evidence_items: Array
) -> Array:
	var problems: Array = []
	for rule: Dictionary in REACHABILITY_RULES:
		var triggered := false
		if rule.has("if_flag"):
			triggered = story_flags.has(str(rule["if_flag"]))
		elif rule.has("if_evidence"):
			triggered = evidence_items.has(str(rule["if_evidence"]))
		elif rule.has("if_knowledge"):
			triggered = knowledge_items.has(str(rule["if_knowledge"]))
		if not triggered:
			continue

		var trigger_name := str(
			rule.get("if_flag", rule.get("if_evidence", rule.get("if_knowledge", "?")))
		)
		for needed: String in rule.get("then_flags", []):
			if not story_flags.has(needed):
				problems.append(
					"holds '%s' but not story flag '%s' — %s"
					% [trigger_name, needed, rule["why"]]
				)
		for needed: String in rule.get("then_evidence", []):
			if not evidence_items.has(needed):
				problems.append(
					"holds '%s' but not evidence '%s' — %s"
					% [trigger_name, needed, rule["why"]]
				)
	return problems
