extends SceneTree

## Junction Bench II contract.
##
## This bench is deliberately a different verb from Bench I: nothing is chosen
## from a rack. The resistance is continuous, the circuit is always live, and the
## stage is satisfied by holding a value rather than submitting one. The suite
## therefore checks the physics and the holding rule together:
##   * the reading is the divider, evaluated, not a table;
##   * sliding the wiper right always leaves the lamp less voltage;
##   * a value merely crossed does not clear the stage; a value held does;
##   * drifting stages actually move the target while the wiper stands still.

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
	lab.call("open_challenge", "switch_right")
	await process_frame

	var stage_count := int(lab.call("get_stage_count"))
	_expect(stage_count >= 6, "Bench II runs at least six stages (got %d)" % stage_count)

	_check_verb_differs_from_bench_one()
	_check_drift_moves_the_target()

	for stage: int in range(stage_count):
		_expect(int(lab.get("stage_index")) == stage, "Bench II is on stage %d" % (stage + 1))
		_check_divider_maths(stage)
		await _check_crossing_is_not_holding(stage)
		await _check_hold_clears(stage)

	_expect(bool(lab.get("challenge_completed")), "Clearing every stage completes Bench II")
	_expect(completed_ids.has("switch_right"), "Bench II reports completion for the plate that opened it")

	lab.queue_free()
	await process_frame
	paused = false
	_finish()


## The interaction must not regress into Bench I's "pick a part, fit it" loop.
func _check_verb_differs_from_bench_one() -> void:
	_expect(
		lab.find_child("BenchRheostat", true, false) != null,
		"Bench II is operated by a rheostat wiper"
	)
	_expect(
		(lab.get("part_buttons") as Dictionary).is_empty(),
		"Bench II offers no parts rack to pick from"
	)


## At least one stage must make the load move on its own, or "track it" is only
## a sentence in the lesson line.
func _check_drift_moves_the_target() -> void:
	var stages := lab.get("REGULATOR_STAGES") as Array
	var drifting := 0
	for stage: Dictionary in stages:
		if float(stage["drift_span"]) > 0.0:
			drifting += 1
	_expect(drifting >= 2, "At least two stages drift the load (got %d)" % drifting)


func _check_divider_maths(stage: int) -> void:
	var spec := _stage_spec()
	var source_v := float(spec["source_v"])
	var r_max := float(spec["r_max"])

	lab.call("set_rheostat", 0.4)
	var lamp_r := float(lab.call("_live_lamp_resistance"))
	var expected := source_v * lamp_r / (lamp_r + r_max * 0.4)
	_expect(
		absf(float(lab.call("_lamp_voltage")) - expected) < 0.001,
		"Stage %d reads the divider exactly (%.3f V)" % [stage + 1, expected]
	)

	lab.call("set_rheostat", 0.1)
	var high := float(lab.call("_lamp_voltage"))
	lab.call("set_rheostat", 0.9)
	var low := float(lab.call("_lamp_voltage"))
	_expect(low < high, "Stage %d drops the lamp voltage as the wiper moves right" % (stage + 1))

	_expect(
		not (lab.call("_solve_regulator") as Dictionary).is_empty(),
		"Stage %d has a reachable wiper position inside the band" % (stage + 1)
	)


## Touching the band for an instant must not be enough, or the bench would be
## testing luck rather than regulation.
func _check_crossing_is_not_holding(stage: int) -> void:
	var answer := lab.call("_solve_regulator") as Dictionary
	if answer.is_empty():
		return
	lab.call("set_rheostat", float(answer["ratio"]))
	await process_frame
	lab.call("set_rheostat", 0.0)
	await process_frame
	_expect(
		int(lab.get("stage_index")) == stage,
		"Stage %d is not cleared by crossing the band" % (stage + 1)
	)


func _check_hold_clears(stage: int) -> void:
	var hold := float(_stage_spec()["hold"])
	# Measured on the wall clock, not on a frame count: the bench accumulates its
	# hold from real delta, and a headless frame is far shorter than a rendered
	# one, so counting frames would time out before the bench ever saw its hold.
	var deadline_ms := int((hold + 6.0) * 1000.0)
	var started := Time.get_ticks_msec()
	# Drifting stages move the target, so the wiper is re-trimmed every frame,
	# which is exactly what the player is asked to do by hand.
	while Time.get_ticks_msec() - started < deadline_ms and int(lab.get("stage_index")) == stage:
		var answer := lab.call("_solve_regulator") as Dictionary
		if not answer.is_empty():
			lab.call("set_rheostat", float(answer["ratio"]))
		await process_frame
	_expect(
		int(lab.get("stage_index")) > stage or bool(lab.get("challenge_completed")),
		"Stage %d clears when the value is tracked and held" % (stage + 1)
	)


func _stage_spec() -> Dictionary:
	var stages := lab.get("REGULATOR_STAGES") as Array
	return stages[int(lab.get("stage_index"))] as Dictionary


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
		print("circuit_bench_regulator_test: PASS")
		quit(0)
		return
	printerr("circuit_bench_regulator_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
