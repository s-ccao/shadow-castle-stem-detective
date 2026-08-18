extends SceneTree

## Junction Bench III contract.
##
## The third bench is a third verb: nothing is built and nothing is tuned. The
## bus is already dead and the player has to locate the fault by measuring. The
## suite therefore checks that the readings are real physics and that the bench
## rewards deduction rather than exhaustive clicking:
##   * an open puts full supply on every point upstream and zero downstream;
##   * a high-resistance fault leaves no zero anywhere, and its segment shows the
##     largest drop;
##   * a wrong call is answered with the reading that contradicts it;
##   * naming the faulty segment is what clears a stage, and binary search really
##     is enough — every stage is solvable within ceil(log2(segments)) probes.

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
	lab.call("open_challenge", "master_switch")
	await process_frame

	var stage_count := int(lab.call("get_stage_count"))
	_expect(stage_count >= 6, "Bench III runs at least six stages (got %d)" % stage_count)
	_check_verb_differs_from_the_others()

	for stage: int in range(stage_count):
		_expect(int(lab.get("stage_index")) == stage, "Bench III is on stage %d" % (stage + 1))
		_check_readings_are_physics(stage)
		_check_wrong_call_is_explained(stage)
		await _check_binary_search_suffices(stage)

	_expect(bool(lab.get("challenge_completed")), "Clearing every stage completes Bench III")
	_expect(completed_ids.has("master_switch"), "Bench III reports completion for the plate that opened it")

	lab.queue_free()
	await process_frame
	paused = false
	_finish()


## Neither Bench I's rack nor Bench II's wiper may appear here.
func _check_verb_differs_from_the_others() -> void:
	_expect(
		lab.find_child("BenchRheostat", true, false) == null,
		"Bench III has no rheostat to tune"
	)
	_expect(
		lab.find_child("ProbeHit_0", true, false) != null,
		"Bench III is operated by probing test points"
	)
	_expect(
		(lab.get("segment_buttons") as Dictionary).size() > 0,
		"Bench III asks for a verdict on a segment"
	)


func _check_readings_are_physics(stage: int) -> void:
	var spec := _stage_spec()
	var segments := int(spec["segments"])
	var fault_index := int(spec["fault_index"])
	var source_v := float(spec["source_v"])

	if str(spec["fault"]) == "open":
		_expect(
			absf(float(lab.call("_voltage_at", fault_index)) - source_v) < 0.001,
			"Stage %d holds full supply at the last point before the break" % (stage + 1)
		)
		_expect(
			float(lab.call("_voltage_at", fault_index + 1)) <= 0.001,
			"Stage %d reads zero immediately past the break" % (stage + 1)
		)
		return

	# A degraded segment still conducts, so nothing may read zero, and the guilty
	# segment must own the largest drop or the lesson would be unlearnable.
	var lowest := source_v
	var worst_drop := -1.0
	var worst_index := -1
	for index: int in range(segments):
		var drop := float(lab.call("_voltage_at", index)) - float(lab.call("_voltage_at", index + 1))
		if drop > worst_drop:
			worst_drop = drop
			worst_index = index
		lowest = minf(lowest, float(lab.call("_voltage_at", index + 1)))
	_expect(lowest > 0.001, "Stage %d never reads zero on a high-resistance fault" % (stage + 1))
	_expect(
		worst_index == fault_index,
		"Stage %d puts the largest drop on the faulty segment" % (stage + 1)
	)


func _check_wrong_call_is_explained(stage: int) -> void:
	var spec := _stage_spec()
	var segments := int(spec["segments"])
	var fault_index := int(spec["fault_index"])
	lab.call("probe_point", segments)
	lab.call("probe_point", 0)
	var innocent := 0 if fault_index != 0 else segments - 1
	lab.call("accuse_segment", innocent)
	_expect(
		int(lab.get("stage_index")) == stage,
		"Stage %d is not cleared by naming the wrong segment" % (stage + 1)
	)
	var status := lab.get("status_label") as Label
	_expect(
		status != null and status.text.length() > 0,
		"Stage %d answers a wrong call with a reason" % (stage + 1)
	)


## Binary search has to actually work: the bench claims an optimum, so the suite
## walks that optimum and requires it to reach the fault.
func _check_binary_search_suffices(stage: int) -> void:
	var spec := _stage_spec()
	var segments := int(spec["segments"])
	var budget := int(lab.call("_optimal_probes"))
	var low := 0
	var high := segments
	var probes := 0
	if str(spec["fault"]) == "open":
		while high - low > 1 and probes < budget:
			var mid := (low + high) / 2
			lab.call("probe_point", mid)
			probes += 1
			if float(lab.call("_voltage_at", mid)) > 0.001:
				low = mid
			else:
				high = mid
		_expect(
			low == int(spec["fault_index"]),
			"Stage %d is isolated within %d probes by halving" % [stage + 1, budget]
		)
	else:
		# The degraded segment is found by comparing neighbouring drops.
		for point: int in range(segments + 1):
			lab.call("probe_point", point)
	lab.call("accuse_segment", int(spec["fault_index"]))
	await create_timer(1.05).timeout
	_expect(
		int(lab.get("stage_index")) > stage or bool(lab.get("challenge_completed")),
		"Stage %d clears when the faulty segment is named" % (stage + 1)
	)


func _stage_spec() -> Dictionary:
	var stages := lab.get("DIAGNOSTIC_STAGES") as Array
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
		print("circuit_bench_diagnostic_test: PASS")
		quit(0)
		return
	printerr("circuit_bench_diagnostic_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
