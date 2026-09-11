extends SceneTree

## Transport and isolation contract tests for Condition C.
##
## NO NETWORK, NO CREDENTIALS, NO COST. The frozen wrapper really runs, but the
## binary it launches is a fake `claude` written by this suite, which records
## every byte that crossed the process boundary and prints a canned CLI
## envelope. So these are not assertions about a mock of the transport: the real
## wrapper builds the real sanitized environment and the real argument list, and
## the suite reads what actually arrived.
##
## HOW THIS DIFFERS FROM `condition_c_selector_test.gd`. That suite proves what
## the selector DECIDES, using a scripted in-process stub. This one proves what
## the selector SENDS, over the actual subprocess path. A payload leak is
## invisible to a stub -- the stub is handed the request and never has to keep a
## secret from anything. Only a real process boundary can be measured.
##
## WHAT IT CANNOT COVER, and where that is covered instead. Whether the model
## can actually reach a file, an MCP server or a CLAUDE.md is a question about
## the real CLI, and no offline test can answer it: this suite can only prove
## the isolation flags are passed. That they WORK is proven behaviourally, with
## planted bait and a leaking negative control, by
## `tests/condition_c_isolation_canary.sh`, which costs two live calls and is
## therefore kept out of the default battery.
##
## NO HELD-OUT DATA IS TOUCHED. Every canary below is minted at runtime by this
## file. No heldout-v3 value, no human annotation and no A/B output is read,
## planted or asserted on, so a failure here cannot disclose benchmark material.
##
## Run:
##   godot --headless --script tests/condition_c_transport_test.gd

const Data := preload("res://scripts/adaptive_hint_data.gd")
const Client := preload("res://scripts/condition_c_client.gd")

const SELECTOR_SOURCE := "res://scripts/condition_c_selector.gd"
const CLIENT_SOURCE := "res://scripts/condition_c_client.gd"
const WRAPPER_SOURCE := "res://tools/condition_c_claude_invoke.sh"
const CANARY_SUITE := "res://tests/condition_c_isolation_canary.sh"

const SANDBOX := "user://condition_c_transport_test"

## The only variables the frozen wrapper forwards, plus the handful `sh` adds to
## any child it execs. Anything outside this set reached the CLI by accident.
const ALLOWED_ENV := [
	"PATH", "HOME", "TMPDIR",
	"ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
	"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
	"PWD", "OLDPWD", "SHLVL", "_",
]

## A check that cannot fail proves nothing. Each fault breaks exactly one
## transport guarantee, and the suite must notice:
##
##   wrapper_enables_tools               the model regains file and shell tools
##   wrapper_forwards_whole_env          the parent environment leaks in
##   wrapper_allows_direct_api           api.anthropic.com stops being refused
##   wrapper_keeps_sessions              turns become resumable on disk
##   wrapper_loads_project_instructions  CLAUDE.md and settings load again
##   wrapper_runs_in_caller_cwd          the child starts inside the repository
##   client_leaks_repository_path        a repository path joins the argv
##   client_adds_api_fallback            a direct endpoint reappears in the code
##
## Run one with:
##   CONDITION_C_TRANSPORT_FAULT=wrapper_enables_tools godot --headless \
##     --script tests/condition_c_transport_test.gd
const FAULTS := {
	"wrapper_enables_tools": {"target": "wrapper", "pairs": [
		["\t\t--tools \"\" \\\n", ""],
	]},
	"wrapper_forwards_whole_env": {"target": "wrapper", "pairs": [
		["env -i \\\n\tPATH=/usr/bin:/bin \\", "env \\\n\tPATH=/usr/bin:/bin \\"],
	]},
	"wrapper_allows_direct_api": {"target": "wrapper", "pairs": [
		["if [ \"$BASE_HOST\" = \"api.anthropic.com\" ]; then", "if false; then"],
	]},
	"wrapper_keeps_sessions": {"target": "wrapper", "pairs": [
		["\t\t--no-session-persistence \\\n", ""],
	]},
	"wrapper_loads_project_instructions": {"target": "wrapper", "pairs": [
		["\t\t--safe-mode \\\n", ""],
		["\t\t--restricted \\\n", ""],
		["\t\t--setting-sources \"\" \\\n", ""],
	]},
	"wrapper_runs_in_caller_cwd": {"target": "wrapper", "pairs": [
		["cd \"$SANDBOX/work\"\n", ""],
	]},
	"client_leaks_repository_path": {"target": "client", "pairs": [
		[
			"\t\t\tsystem_path, user_path, str(config.get(\"model\", \"\")),\n",
			"\t\t\tsystem_path, user_path, str(config.get(\"model\", \"\")),\n"
			+ "\t\t\tProjectSettings.globalize_path(SELECTOR_FOR_FAULT),\n",
		],
	]},
	"client_adds_api_fallback": {"target": "client", "pairs": [
		[
			"\tvar config: Dictionary\n",
			"\tconst FALLBACK := \"https://api.anthropic.com/v1/messages\"\n"
			+ "\tvar config: Dictionary\n",
		],
	]},
}

var fault: String = ""
var failures: Array[String] = []

var selector: GDScript = load(SELECTOR_SOURCE)
var transport: GDScript = load(CLIENT_SOURCE)
## Paths and sources actually under test. Under a fault these point at a mutated
## COPY; the frozen files are never written to.
var wrapper_path: String = ""
var wrapper_text: String = ""
var client_text: String = ""

var sandbox: String = ""
var fake_claude: String = ""
var record_dir: String = ""

## Canaries minted per run, so no expectation can be satisfied by a stale value.
var tok_api_key: String = ""
var tok_broker: String = ""
var tok_benchmark: String = ""
var tok_ordinal: String = ""
var tok_annotation: String = ""
var tok_a_output: String = ""
var tok_b_output: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _ok(label: String, value: bool) -> void:
	if not value:
		failures.append(label)


func _mint(prefix: String) -> String:
	return "CANARY-%s-%d%d" % [prefix, Time.get_ticks_usec(), randi() % 100000]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _write(path: String, contents: String, executable: bool = false) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		push_error("could not write %s" % path)
		quit(2)
		return
	handle.store_string(contents)
	handle.close()
	if executable:
		OS.execute("/bin/chmod", ["+x", ProjectSettings.globalize_path(path)])


## A stand-in for the Claude Code binary.
##
## It records its own argv, environment, working directory, directory listing
## and stdin, then prints whichever canned envelope is queued for this
## invocation. Everything it needs is baked into its source as an absolute path,
## because the wrapper's `env -i` means it cannot be told anything through the
## environment -- which is the property under test.
##
## Arguments are separated by U+001F rather than newlines: the system prompt is
## itself multi-line, so a newline-delimited argv could not be parsed back.
func _install_fake_claude() -> void:
	var dir := record_dir
	_write(fake_claude, "#!/bin/sh\n"
		+ "DIR='%s'\n" % dir
		+ "N=$(cat \"$DIR/counter\" 2>/dev/null || echo 0)\n"
		+ "N=$((N+1)); echo \"$N\" > \"$DIR/counter\"\n"
		+ "{\n"
		+ "  echo \"INVOCATION $N pid=$$\"\n"
		+ "  echo \"CWD=$(pwd)\"\n"
		+ "  echo 'LS_BEGIN'; ls -a 2>/dev/null; echo 'LS_END'\n"
		+ "  echo 'ARGV_BEGIN'\n"
		+ "  for a in \"$@\"; do printf '%s\\037' \"$a\"; done; printf '\\n'\n"
		+ "  echo 'ARGV_END'\n"
		+ "  echo 'ENV_BEGIN'; env; echo 'ENV_END'\n"
		+ "  echo 'STDIN_BEGIN'; cat; echo ''; echo 'STDIN_END'\n"
		+ "} >> \"$DIR/record.txt\"\n"
		+ "F=\"$DIR/reply_$N.json\"\n"
		+ "[ -f \"$F\" ] || F=\"$DIR/reply_default.json\"\n"
		+ "cat \"$F\"\n"
		+ "exit $(cat \"$DIR/exit_code\" 2>/dev/null || echo 0)\n",
		true)


func _reset_record() -> void:
	for name: String in ["record.txt", "counter", "exit_code"]:
		DirAccess.remove_absolute("%s/%s" % [record_dir, name])
	var listing := DirAccess.open(record_dir)
	if listing != null:
		for name: String in listing.get_files():
			if name.begins_with("reply_"):
				DirAccess.remove_absolute("%s/%s" % [record_dir, name])


## One CLI `--output-format json` envelope carrying `text` as the model's reply.
func _envelope(text: String) -> String:
	return JSON.stringify({
		"type": "result", "subtype": "success", "is_error": false,
		"num_turns": 1, "result": text, "session_id": "fake-session",
		"modelUsage": {"claude-opus-5": {"canonicalModel": "claude-opus-5"}},
	})


func _queue(replies: Array) -> void:
	var index := 1
	for reply: String in replies:
		_write("%s/reply_%d.json" % [record_dir, index], _envelope(reply))
		index += 1
	_write("%s/reply_default.json" % record_dir, _envelope(replies[-1] if not replies.is_empty() else ""))


func _record_text() -> String:
	return FileAccess.get_file_as_string("%s/record.txt" % record_dir)


## Every argument of invocation `index`, recovered from the U+001F-delimited
## block. Returns [] when that invocation never happened.
func _argv(index: int = 1) -> PackedStringArray:
	var blocks := _record_text().split("ARGV_BEGIN\n")
	if blocks.size() <= index:
		return PackedStringArray()
	var block := str(blocks[index])
	var end := block.rfind("\nARGV_END")
	if end < 0:
		return PackedStringArray()
	var args := block.substr(0, end).split(char(0x1F))
	var out := PackedStringArray()
	for arg: String in args:
		out.append(arg)
	out.remove_at(out.size() - 1)  # trailing separator yields one empty tail
	return out


func _env_names(index: int = 1) -> Array[String]:
	var blocks := _record_text().split("ENV_BEGIN\n")
	if blocks.size() <= index:
		return []
	var block := str(blocks[index])
	var names: Array[String] = []
	for line: String in block.substr(0, max(0, block.find("\nENV_END"))).split("\n"):
		var eq := line.find("=")
		if eq > 0:
			names.append(line.substr(0, eq))
	return names


## The USER payload of invocation `index`. This, not the argument list, is where
## the scenario lives: the wrapper pipes the user prompt in on stdin and hands
## the CLI no filesystem path whatsoever.
func _stdin(index: int = 1) -> String:
	var blocks := _record_text().split("STDIN_BEGIN\n")
	if blocks.size() <= index:
		return ""
	var block := str(blocks[index])
	var end := block.rfind("\nSTDIN_END")
	return block.substr(0, end) if end >= 0 else ""


func _state(evidence: Array) -> Dictionary:
	return {
		"npc": "", "room": "castle_hall", "stage": "chemistry",
		"evidence_items": evidence, "story_flags": [], "knowledge_items": [],
	}


## A scenario carrying every kind of material the model must never receive.
## These fields are not in the selector's INPUT_FIELDS allowlist, so a correct
## build drops them; the point is to prove the drop rather than assume it.
func _poisoned_state(evidence: Array) -> Dictionary:
	var state := _state(evidence)
	state["scenario_id"] = tok_benchmark
	state["benchmark"] = "synthetic-not-a-real-holdout"
	state["ordinal"] = tok_ordinal
	state["human_relevant"] = tok_annotation
	state["annotator_note"] = tok_annotation
	state["condition_a_selected"] = tok_a_output
	state["condition_b_selected"] = tok_b_output
	state["source_file"] = ProjectSettings.globalize_path(SELECTOR_SOURCE)
	return state


func _client() -> RefCounted:
	var cls: Variant = transport.get_script_constant_map()["ClaudeCodeCLI"]
	return cls.new(selector.load_config(), wrapper_path)


func _select(npc: String, state: Dictionary, replies: Array) -> Dictionary:
	_reset_record()
	_queue(replies)
	return selector.new(_client()).select(npc, state)


func _reply(decision: String, reason: String = "because") -> String:
	return JSON.stringify({"decision": decision, "reason": reason})


# ---------------------------------------------------------------------------
# 1. The frozen wrapper carries the isolation flags it claims to
# ---------------------------------------------------------------------------

func _test_wrapper_structure() -> void:
	for flag: String in [
		"--print", "--output-format json", "--no-session-persistence",
		"--tools \"\"", "--strict-mcp-config", "--safe-mode", "--restricted",
		"--setting-sources \"\"", "--disable-slash-commands",
	]:
		_ok("the wrapper passes %s" % flag, wrapper_text.contains(flag))

	# `--bare` is the CLI's strongest isolation switch and is deliberately NOT
	# used: under it the CLI authenticates strictly with ANTHROPIC_API_KEY or an
	# apiKeyHelper, which is the separately billed path this experiment forbids.
	# Isolation was bought with the flags above instead.
	_ok("the wrapper does not use --bare",
		not wrapper_text.contains("\t\t--bare"))

	# Nothing may hand the child an MCP server, a resumed session or a prior
	# transcript. Absence is the guarantee; a flag that is never passed cannot be
	# passed wrongly.
	for forbidden: String in [
		"--mcp-config", "--resume", "--continue", "--session-id",
		"--append-system-prompt", "--permission-mode",
	]:
		_ok("the wrapper never passes %s" % forbidden,
			not wrapper_text.contains(forbidden + " "))

	# The credential must never be handed to Anthropic directly, and the refusal
	# must be a gate rather than a comment.
	_ok("the wrapper refuses api.anthropic.com",
		wrapper_text.contains("if [ \"$BASE_HOST\" = \"api.anthropic.com\" ]; then"))
	_ok("the wrapper builds the child environment from nothing",
		wrapper_text.contains("env -i \\"))

	var start := wrapper_text.find("env -i \\")
	var block := wrapper_text.substr(start, max(0, wrapper_text.find("< \"$USR_FILE\"") - start))
	_ok("no API key is forwarded to the child",
		not block.contains("ANTHROPIC_API_KEY"))
	_ok("the environment block was actually located, not empty",
		block.contains("ANTHROPIC_AUTH_TOKEN"))


# ---------------------------------------------------------------------------
# 2. The environment the CLI really receives
# ---------------------------------------------------------------------------

func _test_sanitized_environment() -> void:
	var result := _select("butler", _state(["fake_red_stain"]),
		[_reply("h_butler_stain")])
	_ok("the fake CLI was reached at all", not _record_text().is_empty())

	var names := _env_names()
	# Non-vacuity first: if the broker credential did NOT arrive, then every
	# absence below is explained by nothing arriving, and proves nothing.
	_ok("the broker credential IS forwarded (so the check can fail)",
		names.has("ANTHROPIC_AUTH_TOKEN"))
	_ok("the recorded environment is non-empty", names.size() >= 3)

	# This process deliberately sets a fake ANTHROPIC_API_KEY before running, to
	# prove the wrapper strips it. The value is a minted canary, is never sent
	# anywhere, and the fake CLI makes no network call.
	_ok("ANTHROPIC_API_KEY never reaches the CLI",
		not names.has("ANTHROPIC_API_KEY"))
	_ok("the API key canary appears nowhere in the recorded transcript",
		not _record_text().contains(tok_api_key))

	# And nothing else rides along: no agent-session variable, no editor
	# variable, no path pointing at a checkout.
	for name: String in names:
		_ok("unexpected variable '%s' reached the CLI" % name,
			ALLOWED_ENV.has(name))

	_check("the selector still got its answer", str(result["selected_hint_id"]),
		"h_butler_stain")


# ---------------------------------------------------------------------------
# 3. The argument list the CLI really receives
# ---------------------------------------------------------------------------

func _test_isolation_flags_reach_the_cli() -> void:
	_select("butler", _state(["fake_red_stain"]), [_reply("h_butler_stain")])
	var argv := _argv()
	_ok("an argument list was recorded", argv.size() > 5)

	for flag: String in [
		"--print", "--no-session-persistence", "--strict-mcp-config",
		"--safe-mode", "--restricted", "--disable-slash-commands",
	]:
		_ok("the CLI received %s" % flag, argv.has(flag))

	# A flag whose VALUE is the empty string is the whole point for these two;
	# asserting only the flag name would pass with `--tools Bash`.
	for pair: Array in [["--tools", ""], ["--setting-sources", ""],
			["--output-format", "json"], ["--model", "claude-opus-5"]]:
		var index := argv.find(str(pair[0]))
		_ok("%s is present" % str(pair[0]), index >= 0)
		if index >= 0 and index + 1 < argv.size():
			_check("%s value" % str(pair[0]), argv[index + 1], str(pair[1]))

	for forbidden: String in ["--resume", "--continue", "--session-id",
			"--mcp-config", "--permission-mode", "--bare"]:
		_ok("the CLI never received %s" % forbidden, not argv.has(forbidden))

	# The system prompt is passed as an argument, so the frozen SYSTEM block is
	# what governs the turn -- not a project file the CLI discovered.
	var index := argv.find("--system-prompt")
	_ok("the frozen system prompt is supplied explicitly", index >= 0)
	if index >= 0 and index + 1 < argv.size():
		_ok("the system prompt is not empty", argv[index + 1].length() > 50)

	# No argument is a filesystem path. The wrapper reads the two staged prompt
	# files itself and passes their CONTENTS -- the system block as an argument,
	# the user block on stdin -- so the CLI is never told where anything lives.
	for argument: String in argv:
		_ok("an argument looks like a path: %s" % argument,
			not argument.begins_with("/") and not argument.contains("res://"))


# ---------------------------------------------------------------------------
# 4. The working directory the CLI really starts in
# ---------------------------------------------------------------------------

func _test_clean_working_directory() -> void:
	_select("butler", _state(["fake_red_stain"]), [_reply("h_butler_stain")])
	var record := _record_text()
	var cwd_line := ""
	for line: String in record.split("\n"):
		if line.begins_with("CWD="):
			cwd_line = line.substr(4)
			break
	_ok("a working directory was recorded", not cwd_line.is_empty())
	_ok("the CLI does not start inside the repository",
		not cwd_line.begins_with(ProjectSettings.globalize_path("res://")))

	var listing := ""
	var start := record.find("LS_BEGIN\n")
	if start >= 0:
		listing = record.substr(start + 9, max(0, record.find("LS_END") - start - 9))
	# `ls -a` always reports `.` and `..`; anything else is material the model
	# could have opened had a tool been available.
	var entries: Array[String] = []
	for entry: String in listing.split("\n"):
		if not entry.strip_edges().is_empty() and entry != "." and entry != "..":
			entries.append(entry)
	_ok("the working directory is empty, found %s" % str(entries), entries.is_empty())


# ---------------------------------------------------------------------------
# 5. Nothing forbidden crosses the process boundary
# ---------------------------------------------------------------------------

func _test_no_forbidden_material_crosses() -> void:
	var result := _select("butler", _poisoned_state(["fake_red_stain"]),
		[_reply("h_butler_stain")])
	var crossed := _record_text()

	# Non-vacuity: legitimate scenario content MUST be in there. Otherwise the
	# absences below would be satisfied by an empty payload.
	_ok("the payload really does carry the scenario", crossed.contains("butler"))
	_ok("the payload really does carry a candidate", crossed.contains("h_butler_stain"))

	for canary: Array in [
		[tok_benchmark, "a benchmark identifier"],
		[tok_ordinal, "a scenario ordinal"],
		[tok_annotation, "human annotation content"],
		[tok_a_output, "Condition A output"],
		[tok_b_output, "Condition B output"],
	]:
		_ok("%s crossed the boundary" % str(canary[1]),
			not crossed.contains(str(canary[0])))

	# No repository path, in any argument or in either prompt. The prompt files
	# are staged under `user://`, which is outside the checkout.
	var repo := ProjectSettings.globalize_path("res://")
	_ok("a repository path crossed the boundary", not crossed.contains(repo))
	for fragment: String in ["res://", ".gd", "docs/heldout", "condition_c_selector"]:
		_ok("the payload mentions '%s'" % fragment, not crossed.contains(fragment))

	_check("the decision still came through", str(result["selected_hint_id"]),
		"h_butler_stain")

	# One boundary further up: the WRAPPER must be handed nothing beyond the two
	# staged prompt files and the model identifier. An extra argument is inert
	# only for as long as the wrapper ignores it, and "the shell script happens
	# not to read $4" is not a guarantee worth resting a leak on.
	var cls: Variant = transport.get_script_constant_map()["ClaudeCodeCLI"]
	var to_wrapper: PackedStringArray = cls.build_arguments(
		"/tmp/sys.txt", "/tmp/usr.txt", selector.load_config()
	)
	_check("the wrapper is handed exactly three arguments", to_wrapper.size(), 3)
	for argument: String in to_wrapper:
		_ok("argument '%s' carries a repository path" % argument,
			not argument.contains(repo) and not argument.contains("res://"))


# ---------------------------------------------------------------------------
# 6. One fresh process per scenario, with no thread between them
# ---------------------------------------------------------------------------

func _test_fresh_process_per_scenario() -> void:
	_reset_record()
	# SILENCE is valid for every NPC, so each scenario resolves in one call and
	# the process count measures scenarios rather than retries.
	_queue([_reply("SILENCE")])
	var client := _client()
	var chosen: RefCounted = selector.new(client)
	chosen.select("butler", _state(["fake_red_stain"]))
	chosen.select("gardener", _state(["greenhouse_pollen"]))
	chosen.select("mechanic", _state(["deliberate_short_circuit"]))

	var record := _record_text()
	_check("one CLI process per scenario", record.count("INVOCATION"), 3)
	_check("the client counted the same", client.invocations, 3)

	var pids: Dictionary = {}
	for line: String in record.split("\n"):
		if line.begins_with("INVOCATION"):
			pids[line.split("pid=")[-1]] = true
	_check("every scenario ran in its own process", pids.size(), 3)

	# A fresh process is only meaningful if nothing was carried in it. Each turn
	# must restate the whole frozen system prompt rather than continue a thread,
	# and no invocation may name a session.
	_check("every invocation restates the system prompt",
		record.count("--system-prompt"), 3)
	for index: int in [1, 2, 3]:
		var argv := _argv(index)
		for forbidden: String in ["--resume", "--continue", "--session-id"]:
			_ok("invocation %d resumed something (%s)" % [index, forbidden],
				not argv.has(forbidden))

	# Scenario N's answer cannot be scenario N+1's. The argument list is
	# deliberately IDENTICAL every time -- flags, model and the frozen system
	# prompt, and nothing scenario-specific -- so the whole per-scenario payload
	# is the stdin block, and that is what must differ.
	_check("every invocation gets the same isolation arguments",
		" ".join(_argv(1)), " ".join(_argv(3)))
	_ok("the first scenario is the butler's", _stdin(1).contains("butler"))
	_ok("the third scenario is the mechanic's", _stdin(3).contains("mechanic"))
	_ok("no two scenarios sent the same payload", _stdin(1) != _stdin(3))
	_ok("nothing of scenario 1 appears in scenario 3",
		not _stdin(3).contains("h_butler_stain"))


# ---------------------------------------------------------------------------
# 7. Fail closed: every unsafe transport refuses to run
# ---------------------------------------------------------------------------

func _run_wrapper_bare(system_text: String) -> int:
	var system_path := "%s/gate_sys.txt" % record_dir
	var user_path := "%s/gate_usr.txt" % record_dir
	_write(system_path, system_text)
	_write(user_path, "hello")
	var output: Array = []
	return OS.execute(wrapper_path, [system_path, user_path, "claude-opus-5"],
		output, true)


func _test_fail_closed_gates() -> void:
	var token := OS.get_environment("ANTHROPIC_AUTH_TOKEN")
	var base := OS.get_environment("ANTHROPIC_BASE_URL")
	var binary := OS.get_environment("CONDITION_C_CLAUDE_BIN")

	# Non-vacuity: the same wrapper, unmolested, must succeed. Otherwise every
	# refusal below could be the wrapper simply being broken.
	_reset_record()
	_queue([_reply("h_butler_stain")])
	_check("the wrapper runs when the broker is present", _run_wrapper_bare("S"), 0)

	OS.unset_environment("ANTHROPIC_AUTH_TOKEN")
	_check("no broker credential -> SUBSCRIPTION_TRANSPORT_UNAVAILABLE",
		_run_wrapper_bare("S"), 3)
	OS.set_environment("ANTHROPIC_AUTH_TOKEN", token)

	OS.unset_environment("ANTHROPIC_BASE_URL")
	_check("no broker URL -> DIRECT_API_REFUSED", _run_wrapper_bare("S"), 4)

	OS.set_environment("ANTHROPIC_BASE_URL", "https://api.anthropic.com")
	_check("a direct Anthropic endpoint -> DIRECT_API_REFUSED",
		_run_wrapper_bare("S"), 4)
	OS.set_environment("ANTHROPIC_BASE_URL", base)

	OS.set_environment("CONDITION_C_CLAUDE_BIN", "%s/not_a_binary" % record_dir)
	_check("a missing CLI -> CLAUDE_CLI_NOT_FOUND", _run_wrapper_bare("S"), 5)
	OS.set_environment("CONDITION_C_CLAUDE_BIN", binary)

	_write("%s/exit_code" % record_dir, "9")
	_check("a failing CLI -> CLAUDE_CLI_FAILED", _run_wrapper_bare("S"), 6)

	# Every one of those is a TRANSPORT error, and under the frozen policy a
	# transport error aborts the run. It must never be recorded as an
	# abstention: a broker outage scored as SILENCE is a fabricated data point.
	var result: Dictionary = selector.new(_client()).select("butler", _state(["fake_red_stain"]))
	DirAccess.remove_absolute("%s/exit_code" % record_dir)
	_ok("a dead transport aborts the run", bool(result["aborted"]))
	_ok("a dead transport is not scored as silence", not bool(result["silence"]))
	_ok("a dead transport does not fall back", not bool(result["fallback_used"]))
	_ok("the abort names the transport",
		str(result["abort_reason"]).contains("CLAUDE_CLI_FAILED"))


# ---------------------------------------------------------------------------
# 8. There is no path to a personally billed API
# ---------------------------------------------------------------------------

func _test_no_api_fallback_exists() -> void:
	var code := _code_only(client_text)
	for banned: String in [
		"api.anthropic.com", "ANTHROPIC_API_KEY", "https://", "http://",
		"HTTPClient", "HTTPRequest",
	]:
		_ok("the transport's code contains '%s'" % banned, not code.contains(banned))

	# The stripper must not be passing these by returning nothing.
	_ok("comment stripping kept the code", code.contains("func complete("))
	_ok("comment stripping removed something", code.length() < client_text.length())

	# And the selector has no second transport hidden behind the first.
	var selector_code := _code_only(FileAccess.get_file_as_string(SELECTOR_SOURCE))
	for banned: String in ["anthropic", "HTTPClient", "api_key", "API_KEY"]:
		_ok("the selector's code contains '%s'" % banned,
			not selector_code.contains(banned))


## GDScript with whole-line comments removed. Only lines whose first non-blank
## character is `#` are dropped, so no executable token is discarded.
func _code_only(source: String) -> String:
	var kept: Array[String] = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


# ---------------------------------------------------------------------------
# 9. The decision contract still holds over the real transport
# ---------------------------------------------------------------------------

func _test_decision_contract_over_real_transport() -> void:
	var catalogue: Dictionary = Data.all_hints()

	# Only an offered identifier may be accepted.
	var offered: Dictionary = selector.new(_client()).build_request(
		"butler", _state(["fake_red_stain"])
	)
	var candidates: Array = offered["candidates"]
	_ok("the butler has candidates to choose from", not candidates.is_empty())

	var unoffered := ""
	for hint_id: String in catalogue:
		if not candidates.has(hint_id):
			unoffered = hint_id
			break
	var rejected := _select("butler", _state(["fake_red_stain"]),
		[_reply(unoffered), _reply(unoffered)])
	_check("an unoffered id is refused", str(rejected["selected_hint_id"]), "")
	_ok("an unoffered id ends in silence, not a hint", bool(rejected["silence"]))

	# A hint belonging to another NPC is refused even if it exists.
	var cross := ""
	for hint_id: String in catalogue:
		if str((catalogue[hint_id] as Dictionary).get("npc", "")) == "gardener":
			cross = hint_id
			break
	var crossed := _select("butler", _state(["fake_red_stain"]),
		[_reply(cross), _reply(cross)])
	_check("a cross-NPC id is refused", str(crossed["selected_hint_id"]), "")

	# An invented identifier is refused.
	var invented := _select("butler", _state(["fake_red_stain"]),
		[_reply("h_not_a_real_hint"), _reply("h_not_a_real_hint")])
	_check("an invented id is refused", str(invented["selected_hint_id"]), "")

	# SILENCE is a legitimate answer, not a failure.
	var silent := _select("butler", _state(["fake_red_stain"]), [_reply("SILENCE")])
	_ok("SILENCE is accepted", bool(silent["silence"]))
	_check("SILENCE selects nothing", str(silent["selected_hint_id"]), "")
	_ok("SILENCE is not an abort", not bool(silent["aborted"]))
	_ok("SILENCE is not a fallback", not bool(silent["fallback_used"]))

	# Malformed output spends exactly one schema retry, then falls silent.
	var malformed := _select("butler", _state(["fake_red_stain"]),
		["not json at all", "still not json"])
	_check("a malformed reply is retried exactly once",
		int(malformed["retry_count"]), 1)
	_check("two CLI calls were made", _record_text().count("INVOCATION"), 2)
	_ok("exhausted retries end in silence", bool(malformed["fallback_used"]))
	_check("exhausted retries select nothing", str(malformed["selected_hint_id"]), "")

	# One malformed reply followed by a good one recovers.
	var recovered := _select("butler", _state(["fake_red_stain"]),
		["}{", _reply("h_butler_stain")])
	_check("a retry can recover", str(recovered["selected_hint_id"]), "h_butler_stain")
	_check("recovery took one retry", int(recovered["retry_count"]), 1)


# ---------------------------------------------------------------------------
# 10. The player never reads the model
# ---------------------------------------------------------------------------

func _test_player_facing_text_is_authored() -> void:
	var catalogue: Dictionary = Data.all_hints()
	var prose := "The butler is lying; check the stain again, detective."
	var result := _select("butler", _state(["fake_red_stain"]),
		[JSON.stringify({"decision": "h_butler_stain", "reason": prose})])

	var hint_id := str(result["selected_hint_id"])
	_check("the model's id was accepted", hint_id, "h_butler_stain")

	# What reaches a player is the authored line the id names. The model's own
	# sentence is kept in the log as evidence and goes nowhere else.
	var authored := str((catalogue[hint_id] as Dictionary).get("text", ""))
	_ok("the authored line exists", not authored.is_empty())
	_ok("the model's prose is not the authored line", authored != prose)
	_ok("the record carries no player-facing generated text",
		not result.has("text") and not result.has("hint_text"))

	# The reason is logged verbatim -- provenance, not delivery.
	_check("the model's reason is logged",
		str((result["attempts"][0] as Dictionary)["reason"]), prose)


# ---------------------------------------------------------------------------
# 11. Canonical PKM, derived not asserted
# ---------------------------------------------------------------------------

func _test_canonical_pkm_crosses() -> void:
	var state := _state(["fake_red_stain"])
	var request: Dictionary = selector.new(_client()).build_request("butler", state)
	var snapshot: Dictionary = request["pkm_states"]
	_ok("a PKM snapshot is supplied", not snapshot.is_empty())

	var PKM := load("res://scripts/player_knowledge_model.gd")
	for concept: String in snapshot:
		_check("PKM state for %s is canonical" % concept,
			str(snapshot[concept]),
			str(PKM.state_name(PKM.state_in(concept, state["knowledge_items"],
				state["story_flags"], state["evidence_items"]))))

	# And it actually crosses the boundary rather than being computed and dropped.
	_select("butler", state, [_reply("h_butler_stain")])
	var crossed := _record_text()
	var seen := 0
	for concept: String in snapshot:
		if crossed.contains(concept):
			seen += 1
	_check("every PKM concept reached the CLI", seen, snapshot.size())


# ---------------------------------------------------------------------------
# 12. The live half of the suite is committed and reachable
# ---------------------------------------------------------------------------

func _test_canary_suite_is_committed() -> void:
	# The wrapper's header points at this file as the proof that isolation works
	# rather than merely being requested. A dangling reference would make that
	# header a false claim.
	_ok("the isolation canary exists", FileAccess.file_exists(CANARY_SUITE))
	_ok("the wrapper points at it",
		wrapper_text.contains("tests/condition_c_isolation_canary.sh"))

	var canary := FileAccess.get_file_as_string(CANARY_SUITE)
	for claim: String in [
		"CANARY-REPOFILE", "CANARY-CLAUDEMD", "CANARY-HOMEMD",
		"CANARY-MCPCONF", "CANARY-SETTINGS", "CANARY-PROMPT",
	]:
		_ok("the canary plants %s bait" % claim, canary.contains(claim))
	_ok("the canary runs a negative control", canary.contains("run_exposed"))
	_ok("the canary guards against drifting from the wrapper",
		canary.contains("no longer tests the shipped invocation"))


# ---------------------------------------------------------------------------

func _apply_fault() -> bool:
	if not FAULTS.has(fault):
		push_error("unknown fault '%s'; known: %s" % [fault, str(FAULTS.keys())])
		return false
	var spec: Dictionary = FAULTS[fault]
	var target := str(spec["target"])
	var source: String = wrapper_text if target == "wrapper" else client_text
	for pair: Array in spec["pairs"]:
		var anchor := str(pair[0])
		if source.count(anchor) != 1:
			push_error("fault '%s': anchor occurs %d times, expected 1:\n%s"
				% [fault, source.count(anchor), anchor])
			return false
		source = source.replace(anchor, str(pair[1]))

	if target == "wrapper":
		wrapper_text = source
		wrapper_path = "%s/mutant_wrapper.sh" % record_dir
		_write(wrapper_path, source, true)
		return true

	# The client fault needs a constant the frozen file does not define, so the
	# mutant declares it itself rather than the frozen source carrying test scaffolding.
	source = source.replace("extends RefCounted\n",
		"extends RefCounted\nconst SELECTOR_FOR_FAULT := \"%s\"\n" % SELECTOR_SOURCE, )
	client_text = source
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_error("fault '%s' did not compile" % fault)
		return false
	transport = script
	return true


func _run() -> void:
	# Credentials are replaced with canaries BEFORE anything is spawned, so no
	# real token can reach any child of this test, and so the API-key strip has
	# something to strip.
	tok_api_key = _mint("APIKEY")
	tok_broker = _mint("BROKER")
	tok_benchmark = _mint("BENCHID")
	tok_ordinal = _mint("ORDINAL")
	tok_annotation = _mint("ANNOTATION")
	tok_a_output = _mint("AOUTPUT")
	tok_b_output = _mint("BOUTPUT")
	OS.set_environment("ANTHROPIC_AUTH_TOKEN", tok_broker)
	OS.set_environment("ANTHROPIC_BASE_URL", "http://127.0.0.1:9/offline-test")
	OS.set_environment("ANTHROPIC_API_KEY", tok_api_key)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SANDBOX))
	sandbox = ProjectSettings.globalize_path(SANDBOX)
	record_dir = sandbox
	fake_claude = "%s/fake_claude.sh" % sandbox
	_install_fake_claude()
	OS.set_environment("CONDITION_C_CLAUDE_BIN", fake_claude)
	# Short, so a stray watchdog from any invocation expires promptly. The fake
	# CLI answers instantly; this never gates a real call.
	OS.set_environment("CONDITION_C_TIMEOUT_SECONDS", "15")

	wrapper_path = ProjectSettings.globalize_path(WRAPPER_SOURCE)
	wrapper_text = FileAccess.get_file_as_string(WRAPPER_SOURCE)
	client_text = FileAccess.get_file_as_string(CLIENT_SOURCE)

	fault = OS.get_environment("CONDITION_C_TRANSPORT_FAULT")
	if not fault.is_empty() and not _apply_fault():
		quit(2)
		return

	_test_wrapper_structure()
	_test_sanitized_environment()
	_test_isolation_flags_reach_the_cli()
	_test_clean_working_directory()
	_test_no_forbidden_material_crosses()
	_test_fresh_process_per_scenario()
	_test_fail_closed_gates()
	_test_no_api_fallback_exists()
	_test_decision_contract_over_real_transport()
	_test_player_facing_text_is_authored()
	_test_canonical_pkm_crosses()
	_test_canary_suite_is_committed()

	var label := "condition_c_transport_test"
	if not fault.is_empty():
		label += "[fault=%s]" % fault

	if failures.is_empty():
		if not fault.is_empty():
			print("%s: PASS — the fault was NOT detected. The suite is blind to it."
				% label)
			quit(1)
			return
		print("Condition C — transport and isolation contract tests")
		print("  no network, no credentials, no cost: the frozen wrapper ran")
		print("  against a fake CLI that recorded what crossed the boundary")
		print("  environment: env -i, six allowlisted variables, no API key")
		print("  working directory: freshly made and empty")
		print("  tools, MCP, settings, project instructions, sessions: off")
		print("  one process per scenario; transport failure aborts, never silences")
		print("  behavioural proof that the flags WORK: tests/condition_c_isolation_canary.sh")
		print("")
		print("%s: PASS" % label)
		quit(0)
		return

	if not fault.is_empty():
		print("%s: FAIL (%d) — detected, as required" % [label, failures.size()])
		for problem: String in failures:
			print("  - %s" % problem)
		quit(0)
		return

	print("%s: FAIL (%d)" % [label, failures.size()])
	for problem: String in failures:
		print("  - %s" % problem)
	quit(1)
