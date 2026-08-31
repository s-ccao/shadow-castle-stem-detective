extends SceneTree

## Being caught must always end somewhere the player can act.
##
## The capture beat awaits four tweens and timers before it raises the recovery
## screen. None of its tweens were marked to run while the tree is paused, so
## anything that pauses — a hub, the update notice — left the sequence waiting
## forever with the player frozen under a black overlay, unable to retry or
## quit. That is the reported freeze.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.game_started = true
	gs.call("grant_wake_room_toolkit")
	# Past the tutorial: this is the ordinary hunt, where capture is real.
	gs.set("hall_arrival_seen", true)
	gs.call("set_story_flag", "hall_first_route_complete")
	gs.call(
		"save_room_checkpoint",
		"res://scenes/floor_1/chemistry_room.tscn",
		"chemistry_room",
		"chemistry_start"
	)
	gs.set("return_spawn_id", "chemistry_door")
	gs.set("current_room_id", "floor_1_hub")

	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame

	var player := hall.get_node_or_null("player") as CharacterBody2D
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	if player == null or guardian == null:
		_expect(false, "Hall provides a player and a Guardian")
		_finish()
		return

	gs.player_health = 3
	guardian.set_physics_process(false)
	guardian.call("set_behavior", 1)
	guardian.call("set_catch_enabled", true)
	guardian.global_position = player.global_position
	guardian.call("check_player_collision")
	_expect(bool(hall.get("game_over")), "Contact after the tutorial ends the run")

	# Pause the tree the way a hub or the update notice would, mid-capture.
	paused = true
	var waited := 0.0
	var screen: Control = null
	while waited < 6.0:
		await create_timer(0.2).timeout
		waited += 0.2
		screen = hall.get("game_over_screen_root") as Control
		if screen != null and screen.visible:
			break
	paused = false

	_expect(
		screen != null and screen.visible,
		"Capture reaches the recovery screen even while the tree is paused"
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	gs.call("reset_new_game")
	gs.game_started = false
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("capture_recovery_test: PASS")
		quit(0)
	else:
		printerr("capture_recovery_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
