extends SceneTree

## The guided crossing is a rehearsal, not a chase the player can lose.
##
## Free-roaming pursuit during the tutorial produced two failures players hit
## immediately: the Guardian pathed through geometry the navigation grid and the
## wall polygons disagree about, and it could crowd the player into a state they
## could not escape. Both come from the same cause — the Guardian's position was
## decided independently of the player's progress.
##
## During the tutorial the Guardian is now placed relative to how far along the
## scripted route the player has actually walked. It advances when they advance,
## it cannot arrive early, and straying off the route returns both to the last
## checkpoint rather than ending the run.

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
	gs.call("add_key", "wake_room_key")
	gs.set("return_spawn_id", "wake_room_first_arrival")
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

	hall.set("guardian_entry_sequence_played", true)
	hall.call("_begin_hall_arrival_route")
	guardian.call("set_cinematic_hold", false)
	guardian.call("set_behavior", 1)
	# Dismiss the arrival dialogue. While it is open the player cannot move, so
	# the chase is deliberately idle — leaving it up would let every assertion
	# below pass against a Guardian that simply never ran.
	hall.call("close_message_panel")
	hall.set("dialogue_active", false)
	await process_frame
	_expect(
		not bool(hall.get("dialogue_active")),
		"The rehearsal is actually running (no dialogue holding it)"
	)

	var route: Array = hall.get("hall_tutorial_route")
	_expect(
		route.size() >= 4,
		"The guided crossing is broken into segments (%d waypoints)" % route.size()
	)
	if route.size() < 4:
		_finish()
		return

	# The Guardian starts behind the player and must not be able to arrive early.
	var opening_gap: float = player.global_position.distance_to(guardian.global_position)
	_expect(
		opening_gap > 200.0,
		"The Guardian opens the crossing at a safe distance (%.0f px)" % opening_gap
	)

	# Walk the route. The Guardian should follow, never lead, and never catch.
	var closest := 99999.0
	var index := 1
	while index < route.size():
		player.global_position = route[index] as Vector2
		for _settle: int in range(6):
			await physics_frame
		closest = minf(closest, player.global_position.distance_to(guardian.global_position))
		if bool(hall.get("game_over")):
			break
		index += 1

	_expect(
		not bool(hall.get("game_over")),
		"Walking the guided route never ends the run"
	)
	_expect(
		closest > 40.0,
		"The Guardian never closes to contact during the rehearsal (%.0f px)" % closest
	)

	# Straying off the route returns the player to the last checkpoint rather
	# than leaving them lost or dead.
	var checkpoint: Vector2 = hall.call("hall_tutorial_checkpoint_position")
	player.global_position = checkpoint + Vector2(900.0, 700.0)
	var recovered := false
	for _frame: int in range(180):
		await physics_frame
		if player.global_position.distance_to(checkpoint + Vector2(900.0, 700.0)) > 64.0:
			recovered = true
			break
	_expect(recovered, "Straying off the guided route returns the player to it")
	_expect(
		not bool(hall.get("game_over")),
		"Straying off the guided route does not end the run"
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
		print("guided_crossing_test: PASS")
		quit(0)
	else:
		printerr("guided_crossing_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
