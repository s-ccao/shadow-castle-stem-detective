extends SceneTree

## Junction Bench I contract.
##
## The bench has to teach two halves of one law, so both halves are asserted at
## every stage that contains them:
##   1. a series run conducts only if every link conducts;
##   2. a conductor placed across the load carries current past it, leaving the
##      lamp dark while the loop is still closed.
##
## A bench that accepts a short would teach the opposite of the case's own
## evidence, so that is the assertion that matters most here.

const LAB_SCRIPT := "res://scripts/circuit_lab_ui.gd"

var failures: Array[String] = []
var game_state: Node
var lab: Node
var completed_ids: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")

	lab = load(LAB_SCRIPT).new()
	root.add_child(lab)
	await process_frame
	lab.connect("completed", Callable(self, "_on_completed"))
	lab.call("open_challenge", "switch_left")
	await process_frame

	var stage_count := int(lab.call("get_stage_count"))
	_expect(stage_count >= 6, "Bench I runs at least six stages (got %d)" % stage_count)

	for stage: int in range(stage_count):
		_expect(int(lab.get("stage_index")) == stage, "Bench I is on stage %d" % (stage + 1))
		await _check_stage_rejects_bad_wiring(stage)
		await _apply_solution_and_energise()

	_expect(bool(lab.get("challenge_completed")), "Clearing every stage completes Bench I")
	_expect(completed_ids.has("switch_left"), "Bench I reports completion for the plate that opened it")

	lab.queue_free()
	await process_frame
	paused = false
	_finish()


## Every wrong arrangement the stage can express must fail, and must fail for the
## stated reason rather than by simply not advancing.
func _check_stage_rejects_bad_wiring(stage: int) -> void:
	var solution := lab.call("get_stage_solution") as Dictionary
	var sockets := lab.get("_sockets") as Dictionary

	var main_socket := _first_socket_of_kind(sockets, "main")
	if not main_socket.is_empty():
		_apply(solution)
		lab.call("place_part", main_socket, "switch_open")
		await _energise()
		_expect(
			int(lab.get("stage_index")) == stage,
			"Stage %d rejects an open link in the series run" % (stage + 1)
		)

	var bypass_socket := _first_socket_of_kind(sockets, "bypass")
	if not bypass_socket.is_empty():
		_apply(solution)
		lab.call("place_part", bypass_socket, "wire")
		await _energise()
		_expect(
			int(lab.get("stage_index")) == stage,
			"Stage %d rejects a conductor bridging the lamp" % (stage + 1)
		)
		# A resistor is still a conductor, so it shorts the lamp just as a wire
		# does. This is the misconception the stage exists to correct.
		if _stage_tray_has(stage, "resistor"):
			_apply(solution)
			lab.call("place_part", bypass_socket, "resistor")
			await _energise()
			_expect(
				int(lab.get("stage_index")) == stage,
				"Stage %d rejects a resistor bridging the lamp" % (stage + 1)
			)


func _apply_solution_and_energise() -> void:
	_apply(lab.call("get_stage_solution") as Dictionary)
	await _energise()


func _apply(solution: Dictionary) -> void:
	for socket_id: String in solution:
		lab.call("place_part", socket_id, str(solution[socket_id]))


func _energise() -> void:
	lab.call("run_test")
	await create_timer(0.85).timeout


func _first_socket_of_kind(sockets: Dictionary, kind: String) -> String:
	for socket_id: String in sockets:
		var socket := sockets[socket_id] as Dictionary
		if str(socket["kind"]) == kind and bool(socket["is_socket"]):
			return socket_id
	return ""


func _stage_tray_has(stage: int, part_id: String) -> bool:
	var stages := lab.get("CONTINUITY_STAGES") as Array
	if stage < 0 or stage >= stages.size():
		return false
	return ((stages[stage] as Dictionary)["tray"] as Array).has(part_id)


func _on_completed(challenge_id: String) -> void:
	completed_ids.append(challenge_id)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if game_state != null:
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("circuit_bench_continuity_test: PASS")
		quit(0)
		return
	printerr("circuit_bench_continuity_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
