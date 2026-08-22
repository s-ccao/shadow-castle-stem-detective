extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.set("game_started", true)
	game_state.set_story_flag("wake_room_arrival_complete")

	var scene := load("res://scenes/wake_room.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	await process_frame
	await process_frame

	var player := room.get_node("player") as CharacterBody2D
	player.global_position = room.get("door_position") as Vector2
	var hover_state := room.get("mouse_over_prop") as Dictionary
	hover_state["desk"] = true
	room.call("update_interaction_prompt")
	_expect(
		str(room.get("current_interaction")) == "door",
		"A remote mouse hover cannot replace the interaction beside the player"
	)
	_expect(
		str(room.call("_wake_tutorial_target_interaction")) == "door",
		"Wake tutorial begins at the locked door"
	)
	game_state.set_story_flag("wake_tutorial_door_checked")
	_expect(
		str(room.call("_wake_tutorial_target_interaction")) == "prop:desk",
		"Wake tutorial sends the player from the door to the desk"
	)
	room.set("desk_briefing_read", true)
	_expect(
		str(room.call("_wake_tutorial_target_interaction")) == "prop:bed",
		"Wake tutorial teaches key collection after the desk"
	)
	game_state.add_key("wake_room_key")
	_expect(
		str(room.call("_wake_tutorial_target_interaction")) == "prop:bookshelf",
		"Wake tutorial teaches finding the lock answer after the key"
	)
	room.set("first_lock_rule_learned", true)
	_expect(
		str(room.call("_wake_tutorial_target_interaction")) == "door",
		"Wake tutorial returns to the door for the knowledge lock"
	)

	room.queue_free()
	await process_frame
	game_state.set("game_started", false)
	game_state.set("_loading_save", false)
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("wake_interaction_priority_test: PASS")
		quit(0)
		return
	printerr(
		"wake_interaction_priority_test: FAIL (%d assertion(s))"
		% failures.size()
	)
	quit(1)
