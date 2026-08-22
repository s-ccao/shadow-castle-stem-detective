extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var notice := root.get_node("UpdateNotice") as CanvasLayer
	_expect(notice != null, "Update notice is globally available")
	notice.call("_show_notice")
	await process_frame
	_expect(paused, "Update announcement pauses the entire game")
	_expect(notice.visible, "Update announcement is visible while paused")
	var blocker := notice.get("overlay") as ColorRect
	_expect(
		blocker.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Update announcement blocks world pointer input"
	)
	var restart := notice.get("restart_button") as Button
	var later := notice.get("later_button") as Button
	_expect(
		not restart.text.is_empty() and not later.text.is_empty(),
		"Update announcement offers restart and later choices"
	)
	notice.call("_dismiss_for_later")
	await process_frame
	_expect(not paused, "Later restores the game's previous running state")

	paused = true
	notice.call("_show_notice")
	notice.call("_dismiss_for_later")
	_expect(paused, "Later preserves a game that was already paused")
	paused = false

	var shell := FileAccess.get_file_as_string(
		"res://web/shell/loading_shell.html"
	)
	_expect(
		shell.contains("window.shadowCastleUpdate.setWaiting(worker)"),
		"Installed web updates are handed to the in-game announcement"
	)
	_expect(
		shell.contains("snoozedUntil = Date.now()"),
		"Later snoozes the current update instead of permanently hiding it"
	)
	_expect(
		not shell.contains("RELOADED_FOR_UPDATE"),
		"Web updates no longer force an automatic restart"
	)
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("update_notice_test: PASS")
		quit(0)
		return
	printerr(
		"update_notice_test: FAIL (%d assertion(s))" % failures.size()
	)
	quit(1)
