extends SceneTree

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	await _check_circuit_impact()
	await _check_hall_route_scan()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	_finish()


func _check_circuit_impact() -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.call("grant_wake_room_toolkit")
	game_state.current_room_id = "circuit_room"
	var packed := load("res://scenes/floor_1/circuit_room.tscn") as PackedScene
	_expect(packed != null, "Circuit Room scene loads for restoration milestone")
	if packed == null:
		return
	var circuit := packed.instantiate()
	root.add_child(circuit)
	current_scene = circuit
	await process_frame
	await process_frame

	var items := circuit.get("INTERACT_ITEMS") as Array
	# Each plate is released by clearing its own bench first. This suite is about
	# what happens after the sequence is thrown, so the benches are pre-cleared
	# rather than replayed here; the benches have their own contracts.
	for bench_flag: String in (circuit.get("BENCH_FOR_SWITCH") as Dictionary).values():
		game_state.call("set_story_flag", bench_flag)
	for switch_id: String in ["switch_left", "switch_right", "master_switch"]:
		var item := _find_item(items, switch_id)
		if item.is_empty():
			_fail("Circuit switch item missing: " + switch_id)
			continue
		circuit.call("_handle_switch_interaction", switch_id, item)

	_expect(
		game_state.has_story_flag("circuit_power_restored"),
		"Master switch restores canonical Circuit power state"
	)
	_expect(
		game_state.has_story_flag("power_restoration_sequence_pending"),
		"Master switch queues one Hall restoration sequence"
	)
	_expect(
		not game_state.has_story_flag("power_map_objective_active"),
		"Open-Map objective waits until the Hall route scan completes"
	)
	await create_timer(0.38).timeout
	var audio := circuit.get_node_or_null("PowerSurgeAudio") as AudioStreamPlayer
	_expect(
		audio != null and audio.stream != null and audio.playing,
		"Power restoration plays the original electric surge one-shot"
	)
	_expect(
		circuit.find_child("GeneratorPowerImpact", true, false) != null,
		"Power restoration creates a named generator impact"
	)
	_expect(
		circuit.find_child("PowerRestorationFlash", true, false) != null,
		"Power restoration creates a full-screen light flicker"
	)

	if current_scene == circuit:
		current_scene = null
	circuit.queue_free()
	await process_frame
	await process_frame


func _check_hall_route_scan() -> void:
	game_state.current_room_id = "floor_1_hub"
	game_state.hall_arrival_seen = true
	game_state.return_spawn_id = "circuit_door"
	for x: int in range(5, 30):
		game_state.hall_explored_cells["%d,%d" % [x, 20 + (x % 3)]] = true

	var packed := load("res://scenes/game_world.tscn") as PackedScene
	_expect(packed != null, "Castle Hall scene loads for route-memory scan")
	if packed == null:
		return
	var hall := packed.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	_expect(
		hall.get("power_route_scan_active") == true,
		"First powered Hall return starts the route-memory scan"
	)
	_expect(
		hall.get("guardian_entry_sequence_active") != true,
		"Route-memory scan resolves before the Guardian return reveal"
	)
	var total := _int_property(hall, "power_route_scan_total")
	await create_timer(0.48).timeout
	var partial := _int_property(hall, "power_route_scan_revealed")
	_expect(
		total > 4 and partial > 0 and partial < total,
		"Gray route memory returns progressively rather than in one frame"
	)
	await create_timer(1.10).timeout
	_expect(
		hall.get("power_route_scan_active") != true
		and _int_property(hall, "power_route_scan_revealed") == total,
		"Route-memory scan restores every recorded Hall cell"
	)
	_expect(
		game_state.has_story_flag("power_restoration_sequence_seen"),
		"Power restoration presentation is persisted as one-time"
	)
	_expect(
		game_state.has_story_flag("power_map_objective_active"),
		"Completed Hall scan activates the open-Map objective"
	)
	var restoration_panel := hall.get("power_restoration_panel") as Panel
	_expect(
		restoration_panel != null
		and restoration_panel.visible
		and str((hall.get("power_restoration_title") as Label).text).contains("POWER RESTORED · ROUTE MEMORY ONLINE"),
		"Hall shows the explicit route-memory-online prompt"
	)
	var route_panel := hall.get("hall_route_panel") as Panel
	var route_body := hall.get("hall_route_body") as Label
	_expect(
		route_panel != null and route_panel.visible and route_body.text.contains("Map"),
		"Hall objective immediately directs the player to open Map"
	)

	var map_hud := root.get_node("MapHud")
	_expect(
		map_hud.get("_entry_suppressed") != true,
		"Completed scan makes Map available during the reward prompt"
	)
	map_hud.call("open_map")
	await process_frame
	_expect(
		game_state.has_story_flag("power_map_reviewed"),
		"Opening Map completes the restoration objective"
	)
	_expect(
		not route_panel.visible,
		"Opening Map clears the temporary Hall objective"
	)
	map_hud.call("close_map")
	paused = false

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	await process_frame


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item: Dictionary in items:
		if str(item.get("name", "")) == item_name:
			return item
	return {}


func _int_property(node: Object, property_name: String) -> int:
	var value: Variant = node.get(property_name)
	return value as int if value is int else 0


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("power_restoration_milestone_test: PASS")
		quit(0)
		return
	printerr("power_restoration_milestone_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
