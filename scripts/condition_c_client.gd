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


## Anthropic Messages API client.
##
## Deliberately thin: it turns a rendered request plus the frozen model config
## into a request body, posts it, and returns the first text block. Every
## sampling parameter comes from the config file -- nothing is defaulted here, so
## the frozen configuration cannot be silently overridden by this code.
##
## `build_body` is separated from the network call so the request construction is
## unit-testable offline. The suite tests `build_body`; the POST itself is not
## exercised by tests and is not used anywhere in this freeze.
class Anthropic extends RefCounted:
	const ENDPOINT := "https://api.anthropic.com/v1/messages"
	const API_VERSION := "2023-06-01"

	var config: Dictionary
	var api_key: String

	func _init(model_config: Dictionary, key: String = "") -> void:
		config = model_config
		api_key = key if not key.is_empty() else OS.get_environment("ANTHROPIC_API_KEY")

	## Request body from the rendered prompt and the FROZEN config.
	##
	## Null-valued sampling parameters are omitted rather than sent as null: the
	## config records `top_p: null` to mean "this knob is not turned", and
	## transmitting an explicit null would be a different request.
	static func build_body(request: Dictionary, config: Dictionary) -> Dictionary:
		var body := {
			"model": str(config.get("model", "")),
			"max_tokens": int(config.get("max_tokens", 256)),
			"temperature": float(config.get("temperature", 0)),
			"system": str(request.get("system", "")),
			"messages": [
				{"role": "user", "content": str(request.get("user", ""))},
			],
		}
		for key: String in ["top_p", "top_k"]:
			if config.get(key) != null:
				body[key] = config[key]
		var stops: Array = config.get("stop_sequences", [])
		if not stops.is_empty():
			body["stop_sequences"] = stops
		return body

	func complete(request: Dictionary) -> Dictionary:
		if api_key.is_empty():
			return {"ok": false, "text": "", "error": "ANTHROPIC_API_KEY is unset",
				"transport_error": true}

		var http := HTTPClient.new()
		var body := JSON.stringify(build_body(request, config))
		var headers := PackedStringArray([
			"content-type: application/json",
			"anthropic-version: %s" % API_VERSION,
			"x-api-key: %s" % api_key,
		])

		var result := _post(http, body, headers)
		if not bool(result["ok"]):
			return result

		var parsed: Variant = JSON.parse_string(str(result["text"]))
		if typeof(parsed) != TYPE_DICTIONARY:
			return {"ok": false, "text": str(result["text"]),
				"error": "response was not a JSON object", "transport_error": true}
		var payload := parsed as Dictionary
		if payload.has("error"):
			return {"ok": false, "text": str(result["text"]),
				"error": str(payload["error"]), "transport_error": true}
		var content: Array = payload.get("content", [])
		for block_variant: Variant in content:
			var block := block_variant as Dictionary
			if str(block.get("type", "")) == "text":
				return {"ok": true, "text": str(block.get("text", "")),
					"error": "", "transport_error": false}
		return {"ok": false, "text": str(result["text"]),
			"error": "response carried no text block", "transport_error": true}

	func _post(
		http: HTTPClient, body: String, headers: PackedStringArray
	) -> Dictionary:
		var err := http.connect_to_host("api.anthropic.com", 443)
		if err != OK:
			return {"ok": false, "text": "", "error": "connect failed: %d" % err,
				"transport_error": true}
		while http.get_status() == HTTPClient.STATUS_CONNECTING \
				or http.get_status() == HTTPClient.STATUS_RESOLVING:
			http.poll()
			OS.delay_msec(20)
		if http.get_status() != HTTPClient.STATUS_CONNECTED:
			return {"ok": false, "text": "", "error": "not connected",
				"transport_error": true}

		err = http.request(HTTPClient.METHOD_POST, "/v1/messages", headers, body)
		if err != OK:
			return {"ok": false, "text": "", "error": "request failed: %d" % err,
				"transport_error": true}
		while http.get_status() == HTTPClient.STATUS_REQUESTING:
			http.poll()
			OS.delay_msec(20)

		var chunks := PackedByteArray()
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			chunks.append_array(http.read_response_body_chunk())
		var code := http.get_response_code()
		var text := chunks.get_string_from_utf8()
		if code < 200 or code >= 300:
			return {"ok": false, "text": text, "error": "HTTP %d" % code,
				"transport_error": true}
		return {"ok": true, "text": text, "error": "", "transport_error": false}
