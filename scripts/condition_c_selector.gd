extends RefCounted

## CONDITION C -- LLM + Player Knowledge Model adaptive hint selection.
##
## Frozen specification: docs/CONDITION_C_SPEC.md
## Frozen prompt:        prompts/condition_c_selector_v1.txt
## Frozen model config:  config/condition_c_model_v2.json
##
## C selects; it does not write. It is shown the same 11 authored hints as
## Conditions A and B, filtered by the same hard-prerequisite predicate, and must
## return one catalogue identifier or SILENCE. It cannot emit player-facing prose:
## the only thing that ever reaches a player is the authored text the returned id
## names.
##
## TEN STANDING COMMITMENTS, and where each is enforced rather than promised:
##   1  same shared catalogue        `Data.all_hints()` -- the same call A and B make
##   2  C generates no hint prose    only an id crosses the boundary; `_validate`
##   3  id or SILENCE only           `_validate`, `DECISION_SILENCE`
##   4  same hard-prerequisite test  `_hard_eligible` -> `Data.state_violations`
##   5  may use canonical PKM        `_pkm_snapshot` -> `PKM.state_in`
##   6  soft metadata never gates    `preferred_when_demonstrated` is rendered into
##                                   the prompt and read by NO predicate here
##   7  evidence/story stay hard     `Data.state_violations`, re-checked post-output
##   8  never sees human labels      `INPUT_FIELDS` allowlist; `build_request`
##   9  never sees A/B output        this file references neither selector; the
##                                   fallback is SILENCE, not A
##  10  never sees benchmark identity `INPUT_FIELDS` excludes id/ordinal/stage-index
##
## On (9): this file must contain no call to `select_condition_a` or
## `select_adaptive`, and its retry-exhausted fallback is SILENCE. Falling back to
## A would make C a superset of A and turn the A-vs-C contrast into a measurement
## of how often C declined to answer. Under protocol section 6 a silence scores as
## not-relevant, so the fallback can never flatter C. `condition_c_selector_test`
## asserts both the behaviour and the absence of those call sites in this source.
##
## Nothing here runs a model by itself. Construct with a client; tests inject
## `ConditionCClient.Stub`, which is why the whole decision path is exercised
## offline and deterministically.

const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")
const ClientScript := preload("res://scripts/condition_c_client.gd")

const SPEC_VERSION := "condition-c-v1"
const TEMPLATE_PATH := "res://prompts/condition_c_selector_v1.txt"
const CONFIG_PATH := "res://config/condition_c_model_v2.json"

const DECISION_SILENCE := "SILENCE"

## The ONLY state fields that may reach the model. An allowlist, not a denylist:
## a field added to a scenario file in future is excluded by default rather than
## leaking until someone notices. Human labels, A/B outputs, scenario ids,
## ordinals and evaluation metrics are absent and cannot be added by accident.
const INPUT_FIELDS: Array[String] = [
	"npc", "room", "stage", "evidence_items", "story_flags", "knowledge_items",
]

## Rejection classes. These are the only reasons a model reply is refused, and
## the only strings the frozen retry note can quote back.
const INVALID_UNPARSEABLE := "the reply was not a single JSON object"
const INVALID_NO_DECISION := "the reply had no string `decision` field"
const INVALID_UNKNOWN_ID := "`decision` was not a known hint identifier"
const INVALID_NOT_OFFERED := "`decision` named a hint that was not offered"
const INVALID_INELIGIBLE := "`decision` named a hint whose preconditions do not hold"

var client
var config: Dictionary
var template: Dictionary
var log_full_prompts: bool = false


func _init(
	model_client,
	config_override: Dictionary = {},
	template_override: Dictionary = {}
) -> void:
	client = model_client
	config = config_override if not config_override.is_empty() else load_config()
	template = template_override if not template_override.is_empty() else load_template()


# ---------------------------------------------------------------------------
# Frozen assets
# ---------------------------------------------------------------------------

static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}


## Splits the frozen template into its SYSTEM, USER and RETRY_NOTE blocks.
## The file is the single source: nothing about the wording lives in this script.
static func load_template(path: String = TEMPLATE_PATH) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	var blocks := {"system": "", "user": "", "retry_note": ""}
	var current := ""
	for line: String in raw.split("\n"):
		match line.strip_edges():
			"===== SYSTEM =====":
				current = "system"
				continue
			"===== USER =====":
				current = "user"
				continue
			"===== RETRY_NOTE =====":
				current = "retry_note"
				continue
		if current.is_empty():
			continue
		blocks[current] = str(blocks[current]) + line + "\n"
	for key: String in blocks:
		blocks[key] = str(blocks[key]).strip_edges()
	blocks["version"] = SPEC_VERSION
	blocks["sha256"] = FileAccess.get_sha256(path)
	return blocks


# ---------------------------------------------------------------------------
# Input construction
# ---------------------------------------------------------------------------

## The state C is allowed to see, built by allowlist from an arbitrary scenario
## dictionary. Anything not in INPUT_FIELDS is dropped here and can never reach
## the prompt, the log or the model.
static func filter_state(raw_state: Dictionary) -> Dictionary:
	var out := {}
	for field: String in INPUT_FIELDS:
		match field:
			"evidence_items", "story_flags", "knowledge_items":
				out[field] = (raw_state.get(field, []) as Array).duplicate()
			_:
				out[field] = str(raw_state.get(field, ""))
	return out


## Hard eligibility -- the SAME predicate Conditions A and B are filtered by,
## reached through the catalogue's own checker rather than reimplemented.
##
## `Data.state_violations` additionally reads `requires_concept`, which Condition
## B's inline filter does not. The two coincide only while no hint declares one.
## `assert_predicate_parity` proves that rather than assuming it.
static func hard_eligible(npc: String, state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var catalogue: Dictionary = Data.all_hints()
	for hint_id: String in catalogue:
		if str((catalogue[hint_id] as Dictionary).get("npc", "")) != npc:
			continue
		var problems: Array = Data.state_violations(
			hint_id,
			state.get("knowledge_items", []),
			state.get("story_flags", []),
			state.get("evidence_items", [])
		)
		if problems.is_empty():
			out.append(hint_id)
	return out


## Non-empty only when the catalogue has drifted away from the assumption that
## makes C's eligibility identical to B's.
static func assert_predicate_parity() -> Array[String]:
	var problems: Array[String] = []
	var catalogue: Dictionary = Data.all_hints()
	if catalogue.size() != 11:
		problems.append("catalogue holds %d hints, the freeze records 11"
			% catalogue.size())
	for hint_id: String in catalogue:
		var requires: Array = (catalogue[hint_id] as Dictionary).get(
			"requires_concept", []
		)
		if not requires.is_empty():
			problems.append(
				"%s declares requires_concept %s, which Condition B's eligibility "
				% [hint_id, str(requires)]
				+ "filter does not read; C and B no longer share a predicate"
			)
	return problems


## Canonical PKM for all eight concepts, derived through PlayerKnowledgeModel.
## A serialized `pkm_states` block from a dataset is never consulted: it is
## descriptive, and it has already disagreed with the model once.
static func pkm_snapshot(state: Dictionary) -> Dictionary:
	var out := {}
	for concept_id: String in PKM.CONCEPTS:
		out[concept_id] = PKM.state_name(PKM.state_in(
			concept_id,
			state.get("knowledge_items", []),
			state.get("story_flags", []),
			state.get("evidence_items", [])
		))
	return out


static func _bullets(items: Array, empty_text: String) -> String:
	if items.is_empty():
		return "  (%s)" % empty_text
	var lines: Array[String] = []
	for item: Variant in items:
		lines.append("  - %s" % str(item))
	return "\n".join(lines)


static func _render_pkm(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	for concept_id: String in snapshot:
		var label := str((PKM.CONCEPTS[concept_id] as Dictionary).get("label", concept_id))
		lines.append("  %-24s %-13s %s"
			% [concept_id, str(snapshot[concept_id]), label])
	return "\n".join(lines)


## Candidate block: identifier, exact authored text, `teaches`, and the soft
## `preferred_when_demonstrated` note. Nothing else about a hint is disclosed.
static func _render_candidates(candidates: Array[String]) -> String:
	var catalogue: Dictionary = Data.all_hints()
	var lines: Array[String] = []
	for hint_id: String in candidates:
		var hint := catalogue[hint_id] as Dictionary
		var teaches: Array = hint.get("teaches", [])
		var prefers: Array = hint.get("preferred_when_demonstrated", [])
		lines.append("- identifier: %s" % hint_id)
		lines.append("  text: \"%s\"" % str(hint.get("text", "")))
		lines.append("  teaches: %s" % ("(nothing)" if teaches.is_empty()
			else ", ".join(teaches)))
		lines.append("  especially apt once DEMONSTRATED: %s"
			% ("(no authoring note)" if prefers.is_empty() else ", ".join(prefers)))
		lines.append("")
	if lines.is_empty():
		return "  (no line is valid for this character in this state)"
	return "\n".join(lines).strip_edges()


## The rendered request. `raw_state` may be any scenario dictionary; only
## INPUT_FIELDS survive `filter_state`, so a caller cannot widen C's inputs by
## passing a richer object.
func build_request(
	npc: String, raw_state: Dictionary, error_class: String = ""
) -> Dictionary:
	var state := filter_state(raw_state)
	var candidates := hard_eligible(npc, state)
	var snapshot := pkm_snapshot(state)

	var retry_note := ""
	if not error_class.is_empty():
		retry_note = "\n" + str(template["retry_note"]).replace(
			"{{ERROR_CLASS}}", error_class
		)

	var user := str(template["user"])
	for pair: Array in [
		["{{NPC}}", npc],
		["{{ROOM}}", str(state["room"])],
		["{{STAGE}}", str(state["stage"])],
		["{{EVIDENCE}}", _bullets(state["evidence_items"], "the player is carrying no evidence")],
		["{{STORY_FLAGS}}", _bullets(state["story_flags"], "no story progress recorded")],
		["{{PKM}}", _render_pkm(snapshot)],
		["{{CANDIDATES}}", _render_candidates(candidates)],
		["{{RETRY_NOTE}}", retry_note],
	]:
		user = user.replace(str(pair[0]), str(pair[1]))

	return {
		"system": str(template["system"]),
		"user": user,
		"npc": npc,
		"candidates": candidates,
		"pkm_states": snapshot,
		"state": state,
		"template_version": str(template["version"]),
		"template_sha256": str(template["sha256"]),
	}


# ---------------------------------------------------------------------------
# Output parsing and validation
# ---------------------------------------------------------------------------

## Parses a raw model reply into `{ok, decision, reason, error}`.
##
## A single surrounding ```json fence is tolerated. That is transport cleanup,
## not leniency about the answer: the fence is a formatting habit of chat models
## and stripping it changes no decision. Nothing else is repaired -- no id is
## extracted from prose, no near-miss is corrected to the nearest candidate.
##
## `reason` is captured for the research log and returned alongside the decision.
## No predicate below reads it.
static func parse_decision(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	if text.begins_with("```"):
		var first := text.find("\n")
		var last := text.rfind("```")
		if first != -1 and last > first:
			text = text.substr(first + 1, last - first - 1).strip_edges()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "decision": "", "reason": "", "error": INVALID_UNPARSEABLE}
	var payload := parsed as Dictionary
	if not payload.has("decision") or typeof(payload["decision"]) != TYPE_STRING:
		return {"ok": false, "decision": "", "reason": "", "error": INVALID_NO_DECISION}
	return {
		"ok": true,
		"decision": str(payload["decision"]).strip_edges(),
		"reason": str(payload.get("reason", "")),
		"error": "",
	}


## Post-output validation. Four gates, in order:
##   SILENCE is always acceptable;
##   otherwise the id must exist in the shared catalogue;
##   it must have been among the candidates offered for THIS npc (which is what
##     makes a cross-NPC id impossible, since candidates are npc-filtered);
##   and its hard prerequisites must STILL hold, re-checked against the state
##     rather than trusted from the candidate list.
##
## The last gate is redundant while the candidate list is built correctly. It is
## kept because "redundant" and "unnecessary" are different words: it is the only
## check that would survive a bug in candidate construction, and a state-violating
## hint reaching a player is the failure this whole protocol exists to measure.
static func validate(
	decision: String, npc: String, state: Dictionary, candidates: Array[String]
) -> Dictionary:
	if decision == DECISION_SILENCE:
		return {"ok": true, "silence": true, "hint_id": "", "error": ""}
	if not Data.all_hints().has(decision):
		return {"ok": false, "silence": false, "hint_id": "",
			"error": INVALID_UNKNOWN_ID}
	if not candidates.has(decision):
		return {"ok": false, "silence": false, "hint_id": "",
			"error": INVALID_NOT_OFFERED}
	var problems: Array = Data.state_violations(
		decision,
		state.get("knowledge_items", []),
		state.get("story_flags", []),
		state.get("evidence_items", [])
	)
	if not problems.is_empty():
		return {"ok": false, "silence": false, "hint_id": "",
			"error": INVALID_INELIGIBLE}
	if str((Data.all_hints()[decision] as Dictionary).get("npc", "")) != npc:
		return {"ok": false, "silence": false, "hint_id": "",
			"error": INVALID_NOT_OFFERED}
	return {"ok": true, "silence": false, "hint_id": decision, "error": ""}


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## One scenario, start to finish.
##
## Returns the reproducibility record the protocol requires: model identifier,
## template version and hash, candidates supplied, canonical PKM supplied, every
## raw response verbatim, the parsed decision, the retry count, and the final
## validated decision. No human ground truth is present in this record, and none
## may be merged into it before scoring.
func select(npc: String, raw_state: Dictionary) -> Dictionary:
	var parity := assert_predicate_parity()
	if not parity.is_empty():
		return _record(npc, {}, [], 0, "", true, "predicate parity: %s" % str(parity))

	var max_retries := int((config.get("schema_retry", {}) as Dictionary).get(
		"max_retries", 1
	))
	var max_transport := int((config.get("transport_retry", {}) as Dictionary).get(
		"max_retries", 2
	))

	var attempts: Array = []
	var error_class := ""
	## Two independent budgets. A network outage is not a badly formatted answer,
	## so a transport failure must not silently consume the single schema retry
	## and leave a malformed reply with nowhere to go.
	var schema_retries := 0
	var transport_failures := 0
	var request := build_request(npc, raw_state)

	while true:
		request = build_request(npc, raw_state, error_class)
		var response: Dictionary = client.complete(request)

		if not bool(response.get("ok", false)):
			if bool(response.get("transport_error", false)):
				transport_failures += 1
				attempts.append({
					"attempt": attempts.size(),
					"transport_error": str(response.get("error", "")),
				})
				if transport_failures > max_transport:
					return _record(npc, request, attempts, schema_retries, "", true,
						"transport failed %d times: %s"
						% [transport_failures, str(response.get("error", ""))])
				continue
			error_class = str(response.get("error", INVALID_UNPARSEABLE))
			attempts.append({"attempt": attempts.size(), "raw": "",
				"error": error_class})
			schema_retries += 1
			if schema_retries > max_retries:
				break
			continue

		var raw := str(response.get("text", ""))
		var parsed := parse_decision(raw)
		var record := {"attempt": attempts.size(), "raw": raw,
			"parsed_decision": str(parsed["decision"]),
			"reason": str(parsed["reason"]), "error": ""}

		if bool(parsed["ok"]):
			var verdict := validate(
				str(parsed["decision"]), npc, request["state"], request["candidates"]
			)
			record["error"] = str(verdict["error"])
			attempts.append(record)
			if bool(verdict["ok"]):
				return _record(npc, request, attempts, schema_retries,
					"" if bool(verdict["silence"]) else str(verdict["hint_id"]),
					false, "")
			error_class = str(verdict["error"])
		else:
			error_class = str(parsed["error"])
			record["error"] = error_class
			attempts.append(record)

		schema_retries += 1
		if schema_retries > max_retries:
			break

	# Retries exhausted. SILENCE -- never Condition A, never Condition B.
	return _record(npc, request, attempts, schema_retries - 1, "", false, "", true)


func _record(
	npc: String,
	request: Dictionary,
	attempts: Array,
	retries: int,
	hint_id: String,
	aborted: bool,
	abort_reason: String,
	fell_back: bool = false
) -> Dictionary:
	var out := {
		"condition": "C LLM + PKM adaptive selector",
		"spec_version": SPEC_VERSION,
		"npc": npc,
		"model": str(config.get("model", "")),
		"provider": str(config.get("provider", "")),
		"temperature": config.get("temperature"),
		"max_tokens": config.get("max_tokens"),
		"samples_per_scenario": config.get("samples_per_scenario", 1),
		"prompt_template_version": str(request.get("template_version", "")),
		"prompt_template_sha256": str(request.get("template_sha256", "")),
		"rendered_prompt_sha256": _prompt_hash(request),
		"candidates_supplied": request.get("candidates", []),
		"pkm_states_supplied": request.get("pkm_states", {}),
		"attempts": attempts,
		"retry_count": retries,
		"selected_hint_id": hint_id,
		"silence": hint_id.is_empty() and not aborted,
		"fallback_used": fell_back,
		"fallback_policy": "SILENCE (never Condition A or B)",
		"aborted": aborted,
		"abort_reason": abort_reason,
	}
	if log_full_prompts:
		out["rendered_system"] = str(request.get("system", ""))
		out["rendered_user"] = str(request.get("user", ""))
	return out


static func _prompt_hash(request: Dictionary) -> String:
	var joined := str(request.get("system", "")) + "\n" + str(request.get("user", ""))
	return joined.sha256_text()
