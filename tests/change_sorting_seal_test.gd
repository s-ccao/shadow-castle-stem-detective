extends SceneTree

## 封盘按钮的两条回归。
##
## 1. 每帧那道“隐藏或已结束”的守卫不能碰任何 UI。MinigameShell._ready() 让
##    面板先隐藏，封盘按钮要等 build_level() 才建；_finish() 又会清空并释放
##    内容。守卫里只要碰一下按钮，挂上但还没 start() 的面板、关掉后留着的
##    面板，每一帧都会报错。
## 2. 每次真正跑完的验样都要把按钮从“正在验样…”换回“封盘”。判错之后托盘
##    还开着、玩家要重试，按钮不能一直写着“正在验样…”。


## Script errors raised from the minigame's own files, as Godot logs them.
class ErrorCatcher:
	extends Logger

	const WATCHED: Array[String] = ["change_sorting_minigame.gd", "minigame_shell.gd"]

	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == ERROR_TYPE_WARNING or not _is_watched(file, script_backtraces):
			return
		_lock.lock()
		errors.append(
			"%s:%d %s: %s" % [file.get_file(), line, function, code if rationale.is_empty() else rationale]
		)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_lock.lock()
		var taken := errors.duplicate()
		errors.clear()
		_lock.unlock()
		return taken

	func _is_watched(file: String, script_backtraces: Array[ScriptBacktrace]) -> bool:
		var files: Array[String] = [file]
		for backtrace: ScriptBacktrace in script_backtraces:
			for frame: int in backtrace.get_frame_count():
				files.append(backtrace.get_frame_file(frame))
		for path: String in files:
			for watched: String in WATCHED:
				if path.ends_with(watched):
					return true
		return false


const MINIGAME_PATH := "res://scripts/change_sorting_minigame.gd"
const CHECKS := 3

var failures: Array[String] = []
var catcher := ErrorCatcher.new()
## Checks that ran to their end. A script error aborts a check before its
## assertions, which would otherwise read as a pass.
var completed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.add_logger(catcher)
	root.get_node("CaseLocale").call("set_language", "en")
	await _check_unstarted_shell_is_left_alone()
	await _check_finished_shell_is_left_alone()
	await _check_every_seal_resets_the_button()
	OS.remove_logger(catcher)
	_expect(completed == CHECKS, "Every check ran to its end (%d of %d)" % [completed, CHECKS])
	if failures.is_empty():
		print("change_sorting_seal_test: PASS")
		quit(0)
	else:
		printerr("change_sorting_seal_test: FAIL (%d)" % failures.size())
		quit(1)


## Mounted but never started: the shell is hidden and has no seal button yet.
func _check_unstarted_shell_is_left_alone() -> void:
	# Loaded at run time: the class needs the autoloads, which a script run
	# from the command line only has once it is running.
	var game: Node = (load(MINIGAME_PATH) as GDScript).new()
	root.add_child(game)
	await _frames(6)
	game.call("_process", 0.016)
	_expect(
		not bool(game.get("visible")) and game.get("_submit") == null,
		"An unstarted shell is hidden and has no seal button yet"
	)
	_expect_no_errors("An unstarted shell runs its frames without touching UI")
	game.queue_free()
	await process_frame
	completed += 1


## Closed in the middle of a verification and left in the tree: the content
## and its seal button are gone.
func _check_finished_shell_is_left_alone() -> void:
	var game := _open()
	await _frames(4)
	_choose_all(game, true)
	game.call("_on_submit")
	await _frames(2)
	game.call("_on_close_pressed")
	await _frames(6)
	game.call("_process", 0.016)
	_expect(
		bool(game.get("_finished")) and not bool(game.get("visible"))
		and game.get("_submit") == null and not bool(game.get("_running")),
		"Closing mid-verification leaves a finished, hidden shell with its content freed"
	)
	_expect_no_errors("A finished shell runs its frames without touching UI")
	game.queue_free()
	await process_frame
	completed += 1


## A failed seal and then a good one: each verification ends with the button
## back on its own label.
func _check_every_seal_resets_the_button() -> void:
	var game := _open()
	await _frames(4)
	var submit := game.get("_submit") as Button
	var label := submit.text
	_choose_all(game, false)
	game.call("_on_submit")
	_expect(submit.text != label, "Sealing shows the tray being verified (%s)" % submit.text)
	_run_seal(game)
	_expect(
		not bool(game.get("_finished")) and bool(game.get("visible")) and not bool(game.get("_running")),
		"A failed seal keeps the tray open for a retry"
	)
	_expect(
		submit.text == label,
		"After a failed seal the button reads \"%s\" again, not \"%s\"" % [label, submit.text]
	)
	_choose_all(game, true)
	_expect(not submit.disabled, "Every sample filed again, the retry can be sealed")
	game.call("_on_submit")
	_run_seal(game)
	_expect(int(game.call("levels_cleared")) == 1, "The retry clears the stage")
	_expect(
		submit.text == label,
		"After the retry seals, the button reads \"%s\" again, not \"%s\"" % [label, submit.text]
	)
	_expect_no_errors("Sealing, failing and retrying raise no script errors")
	game.queue_free()
	await process_frame
	completed += 1


func _open() -> Node:
	var game: Node = (load(MINIGAME_PATH) as GDScript).new()
	root.add_child(game)
	game.call("configure", "Material Observation Lab", "Samples", Color(0.86, 0.52, 0.98))
	game.call("start")
	return game


## Files every sample, all correctly or all wrongly.
func _choose_all(game: Node, correct: bool) -> void:
	for sample_id: String in game.get("_order"):
		var expected := str(game.call("_expected", sample_id))
		var wrong := "physical" if expected == "chemical" else "chemical"
		game.call("_on_pick", sample_id, expected if correct else wrong)


## Steps the verification through to its verdict, as its frames would.
func _run_seal(game: Node) -> void:
	for _step: int in range(200):
		if not bool(game.get("_running")):
			return
		game.call("_process", 0.05)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame


func _expect_no_errors(description: String) -> void:
	var errors := catcher.take()
	_expect(errors.is_empty(), "%s %s" % [description, errors if not errors.is_empty() else ""])


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)
