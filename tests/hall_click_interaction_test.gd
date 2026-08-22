extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.hall_arrival_seen = true
	game_state.current_room_id = "floor_1_hub"

	var hall_scene := load("res://scenes/game_world.tscn") as PackedScene
	var hall := hall_scene.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame

	hall.set("current_interaction", "wake_room_door")
	var door_rect := hall.call(
		"get_interaction_rect",
		"wake_room_door"
	) as Rect2
	hall.call("on_player_ground_move_started", door_rect.get_center())
	_expect(
		bool(hall.get("scene_transitioning")),
		"Clicking the active Wake Room door starts its room transition"
	)
	_expect(
		hall.get("current_interaction") == "",
		"Door click is consumed as an interaction instead of a movement command"
	)

	game_state.game_started = false
	game_state.set("_loading_save", false)
	if failures.is_empty():
		print("hall_click_interaction_test: PASS")
		quit(0)
	else:
		printerr(
			"hall_click_interaction_test: FAIL (%d assertion(s))"
			% failures.size()
		)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)
