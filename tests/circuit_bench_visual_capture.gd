extends SceneTree

## Native evidence for Junction Bench I. The two failure states are captured on
## purpose: an open run and, more importantly, the short — a closed loop with a
## dark lamp is the case's own crime, and it has to be legible in a screenshot.

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-15-circuit-benches"
const LAB_SCRIPT := "res://scripts/circuit_lab_ui.gd"

var failures: Array[String] = []
var game_state: Node
var lab: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")

	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create evidence directory")
		_finish()
		return

	lab = load(LAB_SCRIPT).new()
	root.add_child(lab)
	await process_frame
	lab.call("open_challenge", "switch_left")
	await process_frame
	await _capture(output_directory.path_join("01-bench-stage-1-empty.png"))

	lab.call("_on_part_pressed", "wire")
	await process_frame
	await _capture(output_directory.path_join("02-bench-part-selected.png"))

	# An open link: nothing conducts anywhere.
	lab.call("place_part", "main_0", "switch_open")
	lab.call("run_test")
	await create_timer(0.22).timeout
	await _capture(output_directory.path_join("03-bench-open-run.png"))
	await create_timer(0.70).timeout

	_solve_current_stage()
	lab.call("run_test")
	await create_timer(0.24).timeout
	await _capture(output_directory.path_join("04-bench-live-run.png"))
	await create_timer(0.80).timeout

	# Advance to the first stage that has a bypass, then short it deliberately.
	while int(lab.get("stage_index")) < 3:
		_solve_current_stage()
		lab.call("run_test")
		await create_timer(0.85).timeout
	await _capture(output_directory.path_join("05-bench-bypass-stage.png"))

	_solve_current_stage()
	lab.call("place_part", "bypass_0", "wire")
	await process_frame
	lab.call("run_test")
	await create_timer(0.26).timeout
	await _capture(output_directory.path_join("06-bench-short-traced.png"))
	await create_timer(0.70).timeout
	await _capture(output_directory.path_join("07-bench-short-explained.png"))

	while int(lab.get("stage_index")) < 5:
		_solve_current_stage()
		lab.call("run_test")
		await create_timer(0.85).timeout
	await _capture(output_directory.path_join("08-bench-final-stage.png"))

	_solve_current_stage()
	lab.call("run_test")
	await create_timer(0.85).timeout
	_expect(bool(lab.get("challenge_completed")), "Bench I completes from the native harness")
	await _capture(output_directory.path_join("09-bench-cleared.png"))

	# --- Bench II \u00b7 continuous regulation ----------------------------
	lab.call("open_challenge", "switch_right")
	await process_frame
	lab.call("set_rheostat", 0.0)
	await process_frame
	await _capture(output_directory.path_join("10-regulator-wiper-at-zero.png"))

	# Wiper far right: too much series resistance, the filament only dulls.
	lab.call("set_rheostat", 0.95)
	await create_timer(0.30).timeout
	await _capture(output_directory.path_join("11-regulator-under-volt.png"))

	# Wiper hard left: the needle runs into the red and the filament fails.
	lab.call("set_rheostat", 0.0)
	await create_timer(0.95).timeout
	await _capture(output_directory.path_join("12-regulator-burnout.png"))
	await create_timer(0.60).timeout

	_track_band(1.0)
	await _capture(output_directory.path_join("13-regulator-holding-in-band.png"))
	await _hold_until_stage(1, 8.0)
	await _capture(output_directory.path_join("14-regulator-next-stage.png"))

	# A drifting stage: the load moves while the wiper stands still.
	await _hold_until_stage(3, 14.0)
	await _capture(output_directory.path_join("15-regulator-drifting-load.png"))

	# --- Bench III \u00b7 fault isolation ---------------------------------
	lab.call("open_challenge", "master_switch")
	await process_frame
	await _capture(output_directory.path_join("16-diagnostic-dead-bus.png"))

	# Halving: probe the middle, then the middle of what is left.
	lab.call("probe_point", 2)
	await create_timer(0.30).timeout
	await _capture(output_directory.path_join("17-diagnostic-first-probe.png"))
	lab.call("probe_point", 3)
	await create_timer(0.30).timeout
	await _capture(output_directory.path_join("18-diagnostic-narrowed.png"))

	# A wrong call is answered with the reading that contradicts it.
	lab.call("accuse_segment", 0)
	await create_timer(0.25).timeout
	await _capture(output_directory.path_join("19-diagnostic-wrong-call.png"))

	lab.call("accuse_segment", 2)
	await create_timer(0.35).timeout
	await _capture(output_directory.path_join("20-diagnostic-fault-found.png"))
	await create_timer(0.70).timeout

	# A high-resistance stage: nothing reads zero, so drops must be compared.
	await _reach_diagnostic_stage(3, 12.0)
	for point: int in range(6):
		lab.call("probe_point", point)
		await process_frame
	await _capture(output_directory.path_join("21-diagnostic-high-resistance.png"))

	lab.queue_free()
	await process_frame
	_finish()


func _reach_diagnostic_stage(target_stage: int, timeout_seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while int(lab.get("stage_index")) < target_stage:
		if Time.get_ticks_msec() - started > int(timeout_seconds * 1000.0):
			_fail("Timed out reaching diagnostic stage %d" % (target_stage + 1))
			return
		var stages := lab.get("DIAGNOSTIC_STAGES") as Array
		var spec := stages[int(lab.get("stage_index"))] as Dictionary
		lab.call("accuse_segment", int(spec["fault_index"]))
		await create_timer(0.95).timeout


func _track_band(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		var answer := lab.call("_solve_regulator") as Dictionary
		if not answer.is_empty():
			lab.call("set_rheostat", float(answer["ratio"]))
		await process_frame


func _hold_until_stage(target_stage: int, timeout_seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while int(lab.get("stage_index")) < target_stage:
		if Time.get_ticks_msec() - started > int(timeout_seconds * 1000.0):
			_fail("Timed out reaching regulator stage %d" % (target_stage + 1))
			return
		var answer := lab.call("_solve_regulator") as Dictionary
		if not answer.is_empty():
			lab.call("set_rheostat", float(answer["ratio"]))
		await process_frame


func _solve_current_stage() -> void:
	var solution := lab.call("get_stage_solution") as Dictionary
	for socket_id: String in solution:
		lab.call("place_part", socket_id, str(solution[socket_id]))


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid viewport capture: " + absolute_path)
		return
	if image.save_png(absolute_path) != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if game_state != null:
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("circuit_bench_visual_capture: PASS")
		quit(0)
		return
	printerr("circuit_bench_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
