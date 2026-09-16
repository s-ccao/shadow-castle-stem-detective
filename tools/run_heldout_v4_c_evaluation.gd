extends SceneTree

## Condition C over the annotated held-out v4 set. ONE SHOT.
##
## This is the first and only Condition C run against heldout-v4. Every call
## reaches a live model through the frozen isolated transport, so a scenario that
## completes is experimental data and is never repeated: not to improve an
## answer, not because an answer looks wrong, not to smooth a run. The only thing
## that may be retried is a reply that failed the schema (once, by the frozen
## selector) or a transport failure (twice, by the frozen budget).
##
## Nothing here re-implements Condition C. The decision path -- prompt rendering,
## the INPUT_FIELDS allowlist, hard-eligibility filtering, parsing, validation,
## the single schema retry, the SILENCE fallback -- is entirely
## `scripts/condition_c_selector.gd`, frozen at f2cab2d0. This file supplies a
## client, walks the scenarios in order, and writes down what happened.
##
## DURABILITY. Each scenario is appended to a JSONL log the instant it returns,
## before the next one starts. If the run aborts at scenario 40, the first 39 are
## already on disk and are not re-run: `--resume` reads the log back and skips
## them, loudly. A restart that pretended nothing had happened would silently
## resample completed scenarios, which is the one thing a one-shot run must not
## do.
##
## ISOLATION, all inherited rather than re-asserted here:
##   fresh process per scenario   `ClaudeCodeCLI.complete` spawns one per call
##   no tools / MCP / repo / session   frozen wrapper flags, env -i, fresh HOME
##   no human labels in the prompt     `INPUT_FIELDS` allowlist in the selector
##   no A/B output in the prompt       this file passes neither to the selector
##   no API fallback                   there is no HTTP client anywhere to fall to
##
## Run:
##   godot --headless --path . --script tools/run_heldout_v4_c_evaluation.gd
##   godot --headless --path . --script tools/run_heldout_v4_c_evaluation.gd -- --resume

const CSelector := preload("res://scripts/condition_c_selector.gd")
const ClientScript := preload("res://scripts/condition_c_client.gd")
const Data := preload("res://scripts/adaptive_hint_data.gd")
const Selector := preload("res://scripts/adaptive_hint_selector.gd")
const PKM := preload("res://scripts/player_knowledge_model.gd")

const ANNOTATED := "res://docs/heldout/heldout_v4_annotated.json"
const RAW_OUT := "res://docs/heldout/heldout_v4_c_raw.json"
const RUN_LOG := "res://docs/heldout/heldout_v4_c_run.jsonl"

const EXPECTED_COUNT := 72

const EXPECTED_SHA := {
	"res://docs/heldout/heldout_v4_annotated.json":
		"cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c",
	"res://scripts/condition_c_selector.gd":
		"f2cab2d0d3c9bb204724bd9ffe94301744fc81eff77bf0c3c6752279208f7e2d",
	"res://scripts/condition_c_client.gd":
		"d9071a9a8321f777a05c4c3c309f7b2ab244d90f74a55ec8d08f1a586bb5b107",
	"res://prompts/condition_c_selector_v1.txt":
		"c4848c52329d625efef4b4cd2b237787d02c5e2e1e015cc195aa6ff3976a9d93",
	"res://config/condition_c_model_v2.json":
		"9889a63f56b7d0e8416217aed106948274ed73558039201b32b81380c256be1e",
	"res://tools/condition_c_claude_invoke.sh":
		"c8ab07a1bec297adab89fc159273a766f1987efad73121cfe0f2d6b48af7229e",
	"res://scripts/adaptive_hint_data.gd":
		"a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
	"res://scripts/player_knowledge_model.gd":
		"55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
	"res://scripts/adaptive_hint_selector.gd":
		"c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
}

var failures: Array[String] = []

## `--dry-run` walks all 72 scenarios with the frozen deterministic Stub client
## instead of the live transport, writing to throwaway paths. It exercises the
## hash gates, the artifact field access, the record shape, the append-only log
## and the summary -- everything except the model. A one-shot run should not
## discover a harness bug at scenario 40, and this is the only way to find one
## without spending experimental data to do it.
var dry_run := false
var raw_out := RAW_OUT
var run_log := RUN_LOG


## Applies the frozen transport backoff around the frozen transport client.
##
## `config/condition_c_model_v2.json` declares `transport_retry.backoff_seconds
## [2, 8]`, but `condition_c_selector.gd` -- which is frozen and must not be
## edited -- counts transport retries without sleeping between them. The delay is
## therefore applied here, at the transport layer where a backoff belongs, by
## composition: this wrapper holds the frozen client and forwards to it.
##
## It changes no retry count, no budget and no abort condition; the selector
## still sees exactly the same sequence of results it would have seen. The only
## difference is how long the harness waits before the next attempt, which is
## what the frozen policy asks for. Recorded as an amendment in the run manifest
## rather than left as an undocumented divergence.
class BackoffClient extends RefCounted:
	var inner
	var backoff: Array
	var consecutive_transport_failures: int = 0
	var delays_applied: Array = []

	func _init(wrapped, backoff_seconds: Array) -> void:
		inner = wrapped
		backoff = backoff_seconds.duplicate()

	func complete(request: Dictionary) -> Dictionary:
		if consecutive_transport_failures > 0 and not backoff.is_empty():
			var index := mini(consecutive_transport_failures - 1, backoff.size() - 1)
			var seconds := int(backoff[index])
			delays_applied.append(seconds)
			OS.delay_msec(seconds * 1000)
		var response: Dictionary = inner.complete(request)
		if bool(response.get("transport_error", false)):
			consecutive_transport_failures += 1
		else:
			consecutive_transport_failures = 0
		return response


func _initialize() -> void:
	call_deferred("_run")


func _resume_requested() -> bool:
	return OS.get_cmdline_user_args().has("--resume")


## Scenario ids already completed, read back from the append-only log.
func _completed_from_log() -> Dictionary:
	var done := {}
	if not FileAccess.file_exists(run_log):
		return done
	for line: String in FileAccess.get_file_as_string(run_log).split("\n"):
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			done[str((parsed as Dictionary).get("scenario_id", ""))] = parsed
	return done


func _append_log(entry: Dictionary) -> void:
	var handle: FileAccess
	if FileAccess.file_exists(run_log):
		handle = FileAccess.open(run_log, FileAccess.READ_WRITE)
		handle.seek_end()
	else:
		handle = FileAccess.open(run_log, FileAccess.WRITE)
	handle.store_string(JSON.stringify(entry) + "\n")
	handle.close()


func _run() -> void:
	dry_run = OS.get_cmdline_user_args().has("--dry-run")
	if dry_run:
		raw_out = "res://docs/heldout/.heldout_v4_c_dryrun_raw.json"
		run_log = "res://docs/heldout/.heldout_v4_c_dryrun.jsonl"
		print("condition_c_v4: DRY RUN -- stub client, no model is contacted, no")
		print("  experimental data is produced. Output goes to throwaway paths.\n")

	for path: String in EXPECTED_SHA:
		var actual := FileAccess.get_sha256(path)
		if actual != str(EXPECTED_SHA[path]):
			failures.append("%s hashes to %s, expected %s"
				% [path, actual, EXPECTED_SHA[path]])
	if not failures.is_empty():
		_bail("integrity gate")
		return

	var parity: Array = CSelector.assert_predicate_parity()
	if not parity.is_empty():
		for problem: String in parity:
			failures.append("predicate parity: %s" % problem)
		_bail("catalogue gate")
		return

	var payload: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ANNOTATED)
	)
	var scenarios: Array = payload["scenarios"]
	if scenarios.size() != EXPECTED_COUNT:
		failures.append("expected %d scenarios, found %d"
			% [EXPECTED_COUNT, scenarios.size()])
		_bail("artifact gate")
		return

	var resume := _resume_requested()
	if dry_run and FileAccess.file_exists(run_log):
		# A throwaway log from a previous dry run carries no experimental data.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_log))
	var already := _completed_from_log()
	if not already.is_empty() and not resume:
		print("condition_c_v4: REFUSING to start.")
		print("  %s already holds %d completed scenario(s)."
			% [run_log, already.size()])
		print("  This is a ONE-SHOT run: starting over would resample scenarios")
		print("  that have already produced experimental data. Pass -- --resume to")
		print("  continue from the log, or move the log aside deliberately.")
		quit(1)
		return
	if resume:
		print("condition_c_v4: RESUMING. %d scenario(s) already completed and will"
			% already.size())
		print("  NOT be re-run. This run is a continuation, not a restart.")

	var config: Dictionary = CSelector.load_config()
	var backoff: Array = (config.get("transport_retry", {}) as Dictionary).get(
		"backoff_seconds", [2, 8]
	)

	var rows: Array = []
	var aborted := false
	var abort_reason := ""
	var started_unix := int(Time.get_unix_time_from_system())
	var resolved_models := {}
	var total_invocations := 0

	for i in scenarios.size():
		var s: Dictionary = scenarios[i]
		var scenario_id := str(s["id"])
		var ordinal := int(s["ordinal"])
		var npc := str(s["npc"])

		if already.has(scenario_id):
			rows.append(already[scenario_id])
			print("  %2d/%d %-28s SKIPPED (already completed)"
				% [ordinal, scenarios.size(), scenario_id])
			continue

		## The raw scenario dictionary is handed over whole and the selector's own
		## INPUT_FIELDS allowlist narrows it. Passing a pre-narrowed object would
		## move the isolation guarantee out of the frozen file and into this one.
		var state := {
			"npc": npc,
			"room": s["room"],
			"stage": s["stage"],
			"evidence_items": s["evidence_items"],
			"story_flags": s["story_flags"],
			"knowledge_items": s["knowledge_items"],
		}

		## Fresh client and fresh selector for every scenario. The frozen client
		## already spawns one process per call; rebuilding both here means there
		## is additionally no object alive across scenarios that could carry
		## anything between them.
		var transport = null
		var client = null
		if dry_run:
			## The stub answers every scenario with SILENCE. What is being
			## exercised is the harness, not the model: a fixed answer makes the
			## record shape, the log and the summary observable without any
			## model contact at all.
			transport = ClientScript.Stub.new([], '{"decision": "SILENCE", "reason": "dry run"}')
			client = transport
		else:
			transport = ClientScript.ClaudeCodeCLI.new(config)
			client = BackoffClient.new(transport, backoff)
		var selector := CSelector.new(client)
		selector.log_full_prompts = true

		var t0 := Time.get_ticks_msec()
		var record: Dictionary = selector.select(npc, state)
		var elapsed := Time.get_ticks_msec() - t0

		var invocations := int(transport.get("invocations")) if not dry_run \
			else int(transport.get("calls"))
		var delays: Array = [] if dry_run else client.delays_applied
		total_invocations += invocations
		## Read back from the CLI envelope through the frozen helper, so the log
		## records the model identity the transport actually resolved rather than
		## the one this harness asked for.
		var resolved := "" if dry_run else ClientScript.ClaudeCodeCLI.resolved_model(
			transport.last_envelope
		)
		if not resolved.is_empty():
			resolved_models[resolved] = int(resolved_models.get(resolved, 0)) + 1

		var selected := str(record.get("selected_hint_id", ""))
		var silence := selected.is_empty() and not bool(record.get("aborted", false))
		var valid: Array = s["valid_hints"]
		## The same three-field state Conditions A and B are scored against, so
		## redundancy and violations are computed from identical inputs.
		var scoring_state := {
			"evidence_items": s["evidence_items"],
			"knowledge_items": s["knowledge_items"],
			"story_flags": s["story_flags"],
		}
		var violations: Array = [] if selected.is_empty() else Data.state_violations(
			selected, s["knowledge_items"], s["story_flags"], s["evidence_items"]
		)
		var relevant := (not selected.is_empty()) and valid.has(selected)

		var entry := {
			"ordinal": ordinal,
			"scenario_id": scenario_id,
			"stratum": s["stratum"],
			"stress_bin": s.get("stress_bin", ""),
			"progression_bucket": s.get("progression_bucket", ""),
			"npc": npc,
			"room": s["room"],
			"stage": s["stage"],
			"evidence_items": s["evidence_items"],
			"story_flags": s["story_flags"],
			"knowledge_items": s["knowledge_items"],
			"human_valid_hints": valid,
			"human_valid_hint_count": valid.size(),
			"human_valid_hints_empty": valid.is_empty(),
			"human_ambiguity": s["annotation"]["ambiguity_note"],
			"elapsed_ms": elapsed,
			"transport_invocations": invocations,
			"backoff_delays_applied": delays,
			"resolved_model": resolved,
			"C": {
				"condition": "C LLM + PKM adaptive selector",
				"selected_hint_id": selected,
				"selected": selected,
				"action": ("SILENCE" if silence else selected),
				"silence": silence,
				"delivered_hint": not selected.is_empty(),
				"relevant": relevant,
				"appropriate_action": (relevant if not selected.is_empty()
					else valid.is_empty()),
				"state_violation": not violations.is_empty(),
				"state_violation_detail": violations,
				"redundant": (not selected.is_empty())
					and Selector.is_redundant(selected, scoring_state),
				"teaches_pkm_concept": (not selected.is_empty())
					and Selector.teaches_pkm_concept(selected),
			},
			"record": record,
		}

		# On disk before the next scenario starts, so an abort loses nothing.
		_append_log(entry)
		rows.append(entry)

		var shown := "SILENCE" if silence else selected
		if bool(record.get("aborted", false)):
			shown = "ABORTED"
		print("  %2d/%d %-28s %-26s retries=%d invocations=%d %dms"
			% [ordinal, scenarios.size(), scenario_id, shown,
			   int(record.get("retry_count", 0)), invocations, elapsed])

		if bool(record.get("aborted", false)):
			aborted = true
			abort_reason = str(record.get("abort_reason", ""))
			print("\ncondition_c_v4: TRANSPORT ABORT at ordinal %d (%s)"
				% [ordinal, scenario_id])
			print("  reason: %s" % abort_reason)
			print("  %d scenario(s) completed and preserved in %s"
				% [rows.size() - 1, run_log])
			break

	var raw := {
		"protocol_version": payload["protocol_version"],
		"conditions_run": ["C"],
		"condition_c_run": true,
		"one_shot": true,
		"resumed": resume,
		"aborted": aborted,
		"abort_reason": abort_reason,
		"scenario_count": rows.size(),
		"expected_scenario_count": EXPECTED_COUNT,
		"complete": rows.size() == EXPECTED_COUNT and not aborted,
		"source_artifact": ANNOTATED,
		"source_artifact_sha256": EXPECTED_SHA[ANNOTATED],
		"annotation_fingerprint_sha256": payload["annotation_fingerprint_sha256"],
		"engine_version": Engine.get_version_info()["string"],
		"started_unix": started_unix,
		"finished_unix": int(Time.get_unix_time_from_system()),
		"transport_manifest": {
			"spec_version": CSelector.SPEC_VERSION,
			"prompt_template": CSelector.TEMPLATE_PATH,
			"prompt_template_sha256":
				EXPECTED_SHA["res://prompts/condition_c_selector_v1.txt"],
			"config": CSelector.CONFIG_PATH,
			"config_sha256": EXPECTED_SHA["res://config/condition_c_model_v2.json"],
			"wrapper": "tools/condition_c_claude_invoke.sh",
			"wrapper_sha256":
				EXPECTED_SHA["res://tools/condition_c_claude_invoke.sh"],
			"selector_sha256":
				EXPECTED_SHA["res://scripts/condition_c_selector.gd"],
			"client_sha256": EXPECTED_SHA["res://scripts/condition_c_client.gd"],
			"model_requested": str(config.get("model", "")),
			"models_resolved_by_cli": resolved_models,
			"provider": str(config.get("provider", "")),
			"samples_per_scenario": config.get("samples_per_scenario", 1),
			"temperature": config.get("temperature"),
			"max_tokens": config.get("max_tokens"),
			"schema_retry": config.get("schema_retry", {}),
			"transport_retry": config.get("transport_retry", {}),
			"total_subprocess_invocations": total_invocations,
			"process_per_scenario": true,
			"backoff_applied_by": "tools/run_heldout_v4_c_evaluation.gd :: BackoffClient",
			"backoff_amendment":
				"config declares transport_retry.backoff_seconds; the frozen "
				+ "selector counts retries without sleeping, so the delay is "
				+ "applied by a composition wrapper in the runner. No retry "
				+ "count, budget or abort condition is changed.",
			"determinism": "NOT claimed; sampling parameters are not controllable "
				+ "through this transport",
		},
		"scenarios": rows,
	}
	_write(raw_out, raw)

	var silent := 0
	var delivered := 0
	var relevant := 0
	var with_retry := 0
	for row: Dictionary in rows:
		if bool(row["C"]["silence"]):
			silent += 1
		if bool(row["C"]["delivered_hint"]):
			delivered += 1
		if bool(row["C"]["relevant"]):
			relevant += 1
		if int((row["record"] as Dictionary).get("retry_count", 0)) > 0:
			with_retry += 1

	print("\n=== heldout-v4 Condition C ===")
	print("completed %d/%d   aborted: %s" % [rows.size(), EXPECTED_COUNT, aborted])
	print("  delivered %d  silence %d  relevant %d  scenarios with a schema retry %d"
		% [delivered, silent, relevant, with_retry])
	print("  subprocess invocations: %d" % total_invocations)
	print("  models resolved by the CLI: %s" % str(resolved_models))
	print("\nwrote %s" % raw_out)
	print("wrote %s" % run_log)
	print("metrics are NOT computed here; see tools/compute_heldout_v4_metrics.py")
	quit(1 if aborted else 0)


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true) + "\n")
	f.close()


func _bail(stage: String) -> void:
	print("heldout_v4_c_evaluation: ABORTED at %s (%d)" % [stage, failures.size()])
	for f: String in failures:
		print("  - " + f)
	quit(1)
