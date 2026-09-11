extends SceneTree

## Condition C — live one-scenario smoke test.
##
## Runs the WHOLE Condition C path once against the real company broker:
##
##   invented scenario -> hard-eligibility filter -> canonical PKM -> frozen
##   prompt -> isolated one-shot Claude Code subprocess -> raw reply -> parse ->
##   eligibility re-check -> validated decision
##
## THIS SPENDS COMPANY CREDITS. One call, occasionally two if the first reply is
## malformed and the single frozen schema retry fires. It is not part of the
## default battery; `tests/condition_c_transport_test.gd` covers the same path
## offline against a fake CLI.
##
## IT IS NOT AN EVALUATION. The scenario below is invented here and appears in no
## holdout. Nothing is scored: there is no ground truth to compare against and
## none is consulted. The only question asked is whether the plumbing carries a
## decision end to end, so the output must never be read as evidence that C
## chooses well or badly, and must never be used to adjust the frozen prompt.
##
## Run:
##   godot --headless --script tools/condition_c_live_smoke.gd

const Data := preload("res://scripts/adaptive_hint_data.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")
const Client := preload("res://scripts/condition_c_client.gd")
const Selector := preload("res://scripts/condition_c_selector.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Condition C — live one-scenario smoke test")
	print("  spends company credits; scores nothing; tunes nothing\n")

	if OS.get_environment("ANTHROPIC_AUTH_TOKEN").is_empty():
		print("SKIP: no company broker credential in the environment.")
		print("      The wrapper would refuse with SUBSCRIPTION_TRANSPORT_UNAVAILABLE,")
		print("      which is the correct fail-closed behaviour, not an error here.")
		quit(2)
		return

	# An invented mid-investigation state. It is not drawn from heldout-v3, from
	# any annotation, or from any A/B result: the player has found one piece of
	# evidence and has been told nothing yet.
	var npc := "butler"
	var state := {
		"npc": npc,
		"room": "castle_hall",
		"stage": "chemistry",
		"evidence_items": ["fake_red_stain"],
		"story_flags": [],
		"knowledge_items": [],
	}

	var config := Selector.load_config()
	var client: RefCounted = Client.ClaudeCodeCLI.new(config)
	var selector: RefCounted = Selector.new(client)

	var request: Dictionary = selector.build_request(npc, state)
	print("  npc                 %s" % npc)
	print("  candidates offered  %s" % str(request["candidates"]))
	print("  pkm states          %d concepts, canonical via PlayerKnowledgeModel"
		% (request["pkm_states"] as Dictionary).size())
	print("  model requested     %s" % str(config.get("model", "")))
	print("  transport           %s\n" % str(config.get("provider", "")))

	var started := Time.get_ticks_msec()
	var result: Dictionary = selector.select(npc, state)
	var elapsed := Time.get_ticks_msec() - started

	if bool(result["aborted"]):
		print("TRANSPORT FAILURE: %s" % str(result["abort_reason"]))
		print("  The run aborted rather than recording an abstention, which is the")
		print("  frozen policy: an outage scored as SILENCE is a fabricated point.")
		quit(1)
		return

	for attempt: Dictionary in result["attempts"]:
		print("  attempt %d" % int(attempt.get("attempt", 0)))
		print("    raw       %s" % str(attempt.get("raw", "")))
		if not str(attempt.get("error", "")).is_empty():
			print("    rejected  %s" % str(attempt.get("error", "")))

	var chosen := str(result["selected_hint_id"])
	print("")
	print("  resolved model      %s" % str(client.last_envelope.get("modelUsage", {}).keys()))
	print("  subprocesses        %d" % int(client.invocations))
	print("  schema retries      %d" % int(result["retry_count"]))
	print("  validated decision  %s" % ("SILENCE" if chosen.is_empty() else chosen))
	print("  elapsed             %d ms" % elapsed)

	# The decision must be an identifier that was actually offered, or silence.
	# This is the contract, re-checked here against the live reply rather than a
	# scripted one -- the one thing a live run can prove that an offline one cannot.
	var problems: Array[String] = []
	if not chosen.is_empty():
		if not (request["candidates"] as Array).has(chosen):
			problems.append("the model returned an id that was never offered: %s" % chosen)
		var violations: Array = Data.state_violations(
			chosen, state["knowledge_items"], state["story_flags"],
			state["evidence_items"]
		)
		if not violations.is_empty():
			problems.append("the accepted hint is not hard-eligible: %s" % str(violations))
		var authored := str((Data.all_hints()[chosen] as Dictionary).get("text", ""))
		if authored.is_empty():
			problems.append("the accepted id names no authored line")
		else:
			print("\n  player-facing line (authored, not generated):")
			print("    %s" % authored)
	if bool(result["fallback_used"]):
		print("\n  the reply never parsed; the frozen policy fell to SILENCE, never to A or B")

	print("")
	if problems.is_empty():
		print("condition_c_live_smoke: PASS — the pipeline carried a validated decision")
		print("  no relevance was scored and no prompt was changed")
		quit(0)
		return
	print("condition_c_live_smoke: FAIL")
	for problem: String in problems:
		print("  - %s" % problem)
	quit(1)
