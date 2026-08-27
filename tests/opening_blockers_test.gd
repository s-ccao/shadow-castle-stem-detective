extends SceneTree

## Two reported blockers, both of which make the opening unplayable.
##
## 1. Work done in the Wake Room — eight stages of the flame lesson, the key,
##    the book — produced no resume point. State reached disk, but the room only
##    recorded a checkpoint on the way out, so a player who stopped partway was
##    sent back to re-enter rather than resumed where they stood.
##
## 2. Leaving the Wake Room was a guaranteed death. The Guardian's stale-hold
##    watchdog fires six seconds into the arrival dialogue, which is less time
##    than it takes to read it. It armed a lethal Guardian without starting the
##    guided route, so the tutorial protection that makes the first crossing
##    survivable was never in force.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_wake_room_progress_is_resumable()
	await _test_arrival_dialogue_never_arms_an_unprotected_guardian()
	_finish()


func _test_wake_room_progress_is_resumable() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.game_started = true

	var wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await process_frame
	await process_frame

	# Finish the flame lesson exactly as clearing all eight stages does.
	wake.call("_on_flame_minigame_finished", true, 8)
	await process_frame

	_expect(
		bool(gs.get("checkpoint_valid")),
		"Clearing the Wake Room lesson records a checkpoint"
	)
	_expect(
		str(gs.get("resume_scene_path")).ends_with("wake_room.tscn"),
		"A player who stops here resumes in the Wake Room, not at the start (got '%s')" % gs.get("resume_scene_path")
	)
	_expect(
		str(gs.get("checkpoint_room_id")) == "wake_room",
		"The checkpoint names the Wake Room (got '%s')" % gs.get("checkpoint_room_id")
	)

	if current_scene == wake:
		current_scene = null
	wake.queue_free()
	await process_frame


func _test_arrival_dialogue_never_arms_an_unprotected_guardian() -> void:
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

	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	_expect(guardian != null, "Hall has a Guardian")
	if guardian == null:
		_finish()
		return

	# Read the arrival dialogue at a human pace. The watchdog timeout is six
	# seconds, so this is the exact window that was killing first-time players.
	var waited := 0.0
	while waited < 11.0:
		await create_timer(0.5).timeout
		waited += 0.5
		var lethal := bool(guardian.get("catch_enabled"))
		var protected := bool(hall.call("_is_hall_arrival_active"))
		if lethal and not protected:
			_expect(
				false,
				"Guardian became lethal with no guided protection after %.1fs of reading" % waited
			)
			break
	if not (
		bool(guardian.get("catch_enabled")) and not bool(hall.call("_is_hall_arrival_active"))
	):
		_expect(
			true,
			"Reading the arrival dialogue never arms an unprotected Guardian"
		)

	# And if the watchdog does have to recover a genuinely stuck cinematic, it
	# must hand back a protected state rather than a lethal one.
	hall.call("_force_end_guardian_cinematic")
	await process_frame
	_expect(
		not bool(guardian.get("catch_enabled"))
		or bool(hall.call("_is_hall_arrival_active")),
		"Cinematic recovery leaves the guided protection in force"
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	await _test_the_first_crossing_is_actually_winnable()
	gs.call("reset_new_game")
	gs.game_started = false


## The reported symptom was that the crossing could not be won at any speed.
## Run it: walk the guided route at full speed and require arrival alive.
func _test_the_first_crossing_is_actually_winnable() -> void:
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
		_expect(false, "Hall provides a player and a Guardian for the crossing")
		return

	# Hand over exactly as the reveal does, then run the guided route.
	hall.set("guardian_entry_sequence_played", true)
	hall.call("_begin_hall_arrival_route")
	guardian.call("set_cinematic_hold", false)
	guardian.call("set_catch_enabled", true)
	guardian.call("set_behavior", 1)
	await process_frame

	var raw: Array = hall.call(
		"_get_hall_route_path",
		player.global_position,
		hall.get("CHEMISTRY_ROOM_DOOR_FOCUS_POSITION")
	)
	_expect(raw.size() >= 2, "The guided route to Chemistry exists (%d points)" % raw.size())
	if raw.size() < 2:
		return

	var speed: float = float(player.get("speed"))
	var index := 0
	var elapsed := 0.0
	while elapsed < 45.0 and index < raw.size():
		await physics_frame
		elapsed += 1.0 / 60.0
		var step := speed / 60.0
		while step > 0.0 and index < raw.size():
			var waypoint: Vector2 = raw[index] as Vector2
			var gap: float = player.global_position.distance_to(waypoint)
			if gap <= step:
				player.global_position = waypoint
				step -= gap
				index += 1
			else:
				player.global_position += (
					waypoint - player.global_position
				).normalized() * step
				step = 0.0
		if bool(hall.get("game_over")):
			break

	_expect(
		index >= raw.size(),
		"A player running the guided route reaches the Chemistry door (%d/%d)" % [index, raw.size()]
	)
	_expect(
		not bool(hall.get("game_over")),
		"The first crossing does not end the run"
	)
	_expect(
		int(gs.get("player_health")) > 0,
		"The first crossing does not drain the player's health"
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("opening_blockers_test: PASS")
		quit(0)
	else:
		printerr("opening_blockers_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
