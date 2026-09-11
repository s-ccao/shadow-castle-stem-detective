extends RefCounted

## Model transport for Condition C, behind an interface.
##
## The selector never speaks HTTP. It hands a rendered request to a client and
## receives a raw string back. That indirection is not abstraction for its own
## sake: it is what lets the entire Condition C decision path -- prompt
## rendering, parsing, validation, eligibility re-checking, retry, fallback -- be
## exercised offline by a scripted stub, with no network, no API key and no
## nondeterminism. The unit suite therefore tests the real selector, not a
## rehearsal of it.
##
## A client returns:
##   {"ok": bool, "text": String, "error": String, "transport_error": bool}
##
## `transport_error` separates "the network failed" from "the model answered
## badly". The first must abort a run; the second is a model decision and is
## retried once, then recorded as SILENCE. Conflating them would let an outage be
## scored as an abstention.


## Base interface. Subclasses override `complete`.
func complete(_request: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"text": "",
		"error": "ConditionCClient is abstract; use a concrete client",
		"transport_error": true,
	}


## Deterministic scripted client for tests and dry runs.
##
## Queue raw response strings; each `complete` pops the next. `always` repeats a
## single response forever, which is how the exhausted-retry path is exercised.
class Stub extends RefCounted:
	var responses: Array = []
	var always: Variant = null
	var transport_failures: int = 0
	var schema_failures: int = 0
	var requests: Array = []
	var calls: int = 0

	func _init(scripted: Array = [], repeat_forever: Variant = null) -> void:
		responses = scripted.duplicate()
		always = repeat_forever

	func complete(request: Dictionary) -> Dictionary:
		calls += 1
		requests.append(request)
		if transport_failures > 0:
			transport_failures -= 1
			return {
				"ok": false, "text": "", "error": "simulated transport failure",
				"transport_error": true,
			}
		## A refusal or an empty completion: the call succeeded, the answer did
		## not. This is a model decision, so it spends the schema retry rather
		## than the transport budget, and it must never abort a run.
		if schema_failures > 0:
			schema_failures -= 1
			return {
				"ok": false, "text": "", "error": "simulated non-transport failure",
				"transport_error": false,
			}
		if not responses.is_empty():
			return {"ok": true, "text": str(responses.pop_front()), "error": "",
				"transport_error": false}
		if always != null:
			return {"ok": true, "text": str(always), "error": "",
				"transport_error": false}
		return {
			"ok": false, "text": "", "error": "stub exhausted",
			"transport_error": true,
		}


## Isolated Claude Code subprocess client -- the ONLY live transport Condition C
## has.
##
## Every call spawns a FRESH one-shot `claude --print` process through the frozen
## wrapper `tools/condition_c_claude_invoke.sh`, which carries the isolation
## flags and the billing gates. Nothing is carried between calls: no session, no
## conversation, no working directory, no environment. Scenario N cannot reach
## scenario N+1, because there is no object between them that could hold it.
##
## The exact flag list deliberately lives in the wrapper, not here. It is one
## reviewable artifact with one hash, and GDScript is a poor place to hide a
## security-relevant argument. This class only chooses the model, hands over two
## prompt files, and interprets the exit code.
##
## THERE IS NO API FALLBACK. This file contains no HTTP client, no endpoint and
## no key lookup; when the company broker is unreachable the wrapper exits
## non-zero and that becomes a transport error, which under the frozen policy
## aborts the run rather than being recorded as an abstention. A silent retreat
## to a directly billed endpoint is not a behaviour that exists to be disabled --
## the code to do it is absent, which `condition_c_transport_test` asserts.
class ClaudeCodeCLI extends RefCounted:
	const WRAPPER_PATH := "res://tools/condition_c_claude_invoke.sh"

	## Wrapper exit codes. Every non-zero code is a TRANSPORT failure, never a
	## schema failure: the model did not answer badly, it was never reached.
	const ERROR_BY_EXIT := {
		3: "SUBSCRIPTION_TRANSPORT_UNAVAILABLE",
		4: "DIRECT_API_REFUSED",
		5: "CLAUDE_CLI_NOT_FOUND",
		6: "CLAUDE_CLI_FAILED",
		7: "CONDITION_C_TIMEOUT",
	}

	var config: Dictionary
	var wrapper: String
	## How many subprocesses this client has spawned. One per scenario attempt;
	## a test reads it to prove invocations are not being reused.
	var invocations: int = 0
	## The last CLI JSON envelope, kept so the run log can record the model
	## identity the CLI actually resolved rather than the one we asked for.
	var last_envelope: Dictionary = {}

	func _init(model_config: Dictionary, wrapper_override: String = "") -> void:
		config = model_config
		wrapper = wrapper_override if not wrapper_override.is_empty() \
			else ProjectSettings.globalize_path(WRAPPER_PATH)

	## The argv handed to the frozen wrapper: two prompt files and the model.
	##
	## Separated from the call so the invocation is unit-testable offline. Note
	## what is NOT here: no scenario id, no ordinal, no benchmark name, no
	## repository path, no git metadata. The wrapper cannot leak an identifier it
	## was never given.
	static func build_arguments(
		system_path: String, user_path: String, config: Dictionary
	) -> PackedStringArray:
		return PackedStringArray([
			system_path, user_path, str(config.get("model", "")),
		])

	## Pull the model's reply out of the CLI's `--output-format json` envelope.
	##
	## `is_error` is the CLI's own signal that the turn failed; it is treated as
	## transport, not as a malformed answer, because a refused or errored turn is
	## not the model choosing badly.
	static func parse_envelope(raw: String) -> Dictionary:
		var parsed: Variant = JSON.parse_string(raw.strip_edges())
		if typeof(parsed) != TYPE_DICTIONARY:
			return {"ok": false, "text": "", "envelope": {},
				"error": "the CLI did not emit a JSON envelope",
				"transport_error": true}
		var envelope := parsed as Dictionary
		if bool(envelope.get("is_error", false)):
			return {"ok": false, "text": str(envelope.get("result", "")),
				"envelope": envelope,
				"error": "the CLI reported is_error: %s"
					% str(envelope.get("subtype", "")),
				"transport_error": true}
		if not envelope.has("result"):
			return {"ok": false, "text": "", "envelope": envelope,
				"error": "the CLI envelope carried no `result`",
				"transport_error": true}
		return {"ok": true, "text": str(envelope["result"]), "envelope": envelope,
			"error": "", "transport_error": false}

	## The model identity the CLI actually billed, read back from the envelope.
	## Empty when the envelope did not report one.
	static func resolved_model(envelope: Dictionary) -> String:
		var usage: Dictionary = envelope.get("modelUsage", {})
		for name: String in usage:
			return str((usage[name] as Dictionary).get("canonicalModel", name))
		return ""

	func complete(request: Dictionary) -> Dictionary:
		invocations += 1
		last_envelope = {}

		## Prompt files live under `user://`, which is outside the repository.
		## The subprocess is handed these two paths and nothing else, so no
		## repository or benchmark path is ever an argument.
		var token := "%d_%d" % [Time.get_ticks_usec(), randi()]
		var system_path := "user://condition_c_sys_%s.txt" % token
		var user_path := "user://condition_c_usr_%s.txt" % token
		if not _write(system_path, str(request.get("system", ""))) \
				or not _write(user_path, str(request.get("user", ""))):
			return {"ok": false, "text": "", "error": "could not stage prompt files",
				"transport_error": true}

		var arguments := build_arguments(
			ProjectSettings.globalize_path(system_path),
			ProjectSettings.globalize_path(user_path),
			config
		)
		var output: Array = []
		var exit_code := OS.execute(wrapper, arguments, output, false)

		DirAccess.remove_absolute(ProjectSettings.globalize_path(system_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(user_path))

		if exit_code < 0:
			return {"ok": false, "text": "",
				"error": "SUBSCRIPTION_TRANSPORT_UNAVAILABLE: could not start %s"
					% wrapper,
				"transport_error": true}
		if exit_code != 0:
			return {"ok": false, "text": "",
				"error": str(ERROR_BY_EXIT.get(exit_code,
					"CLAUDE_CLI_FAILED: exit %d" % exit_code)),
				"transport_error": true}

		var result := parse_envelope("\n".join(PackedStringArray(output)))
		last_envelope = result.get("envelope", {})
		return {
			"ok": bool(result["ok"]),
			"text": str(result["text"]),
			"error": str(result["error"]),
			"transport_error": bool(result["transport_error"]),
			"resolved_model": resolved_model(last_envelope),
		}

	func _write(path: String, contents: String) -> bool:
		var handle := FileAccess.open(path, FileAccess.WRITE)
		if handle == null:
			return false
		handle.store_string(contents)
		handle.close()
		return true
