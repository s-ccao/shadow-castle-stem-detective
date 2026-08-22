extends SceneTree

## The first crossing of the Hall is a set piece, not a skill check. Whether the
## player sprints straight to Chemistry or wanders the maze reading every label,
## the Guardian has to stay a believable threat behind them and must not end the
## run. The near-miss at the Chemistry door is the payoff, and it has to happen
## on both playstyles.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)

	await _test_dawdling_player_is_never_caught(game_state)
	await _test_pace_tracks_the_player(game_state)
	await _test_near_miss_fires_at_the_door(game_state)

	game_state.reset_new_game()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	_finish()


func _new_hall(game_state: Node) -> Node:
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.call("grant_wake_room_toolkit")
	game_state.call("add_key", "wake_room_key")
	game_state.set("return_spawn_id", "wake_room_first_arrival")
	game_state.set("current_room_id", "floor_1_hub")
	var hall_scene := load("res://scenes/game_world.tscn") as PackedScene
	var hall: Node = hall_scene.instantiate() if hall_scene != null else null
	# A scene that fails to load makes every later assertion silently skip,
	# which reports green while proving nothing.
	_expect(hall != null, "Castle Hall scene instantiates")
	if hall == null:
		return null
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	_expect(
		hall.has_method("_begin_hall_arrival_route"),
		"Hall script compiled and exposes the guided route"
	)
	if not hall.has_method("_begin_hall_arrival_route"):
		return hall
	# Skip the reveal cinematic and drop straight into the guided route, in the
	# same state the cinematic hands back: the Guardian is live and lethal.
	hall.set("guardian_entry_sequence_played", true)
	hall.call("_begin_hall_arrival_route")
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	if guardian != null:
		guardian.call("set_cinematic_hold", false)
		guardian.call("set_catch_enabled", true)
		guardian.call("set_behavior", 1)
	await process_frame
	return hall


func _drop_hall(hall: Node) -> void:
	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame


## The failure the player reported: a newcomer who does not know the maze gets
## run down before they ever reach the first door.
func _test_dawdling_player_is_never_caught(game_state: Node) -> void:
	var hall := await _new_hall(game_state)
	if hall == null:
		return
	var player := hall.get_node_or_null("player") as CharacterBody2D
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	_expect(player != null and guardian != null, "Hall has a player and a Guardian")
	if player == null or guardian == null:
		await _drop_hall(hall)
		return

	# Stand perfectly still for a long beat, the worst case for a newcomer, and
	# then let the Guardian walk right onto them.
	player.set_physics_process(false)
	for _step: int in range(120):
		await physics_frame
	_expect(
		bool(guardian.get("catch_enabled")),
		"Guardian is live during the guided crossing (otherwise this proves nothing)"
	)
	guardian.global_position = player.global_position
	guardian.call("check_player_collision")
	await process_frame

	_expect(
		not bool(hall.get("game_over")),
		"A player who never moves survives the guided first crossing"
	)
	_expect(
		int(game_state.player_health) > 0,
		"The guided first crossing does not drain health"
	)
	await _drop_hall(hall)


## Pace has to answer the player. Falling behind should speed the Guardian up;
## crowding the player should slow it down, so the chase reads as pressure
## rather than as a coin flip.
func _test_pace_tracks_the_player(game_state: Node) -> void:
	var hall := await _new_hall(game_state)
	if hall == null:
		return
	var player := hall.get_node_or_null("player") as CharacterBody2D
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	if player == null or guardian == null:
		await _drop_hall(hall)
		return
	_expect(
		hall.has_method("_update_guardian_tutorial_pace"),
		"Hall exposes guided-crossing pacing"
	)
	if not hall.has_method("_update_guardian_tutorial_pace"):
		await _drop_hall(hall)
		return

	guardian.global_position = hall.call(
		"_nearest_guardian_walkable_position",
		player.global_position + Vector2(96.0, 0.0)
	) as Vector2
	hall.call("_update_guardian_tutorial_pace", 0.1)
	var crowding_speed := float(game_state.call("get_guardian_chase_speed"))

	guardian.global_position = hall.call(
		"_nearest_guardian_walkable_position",
		hall.get("ENEMY_START_POSITION")
	) as Vector2
	hall.call("_update_guardian_tutorial_pace", 0.1)
	var trailing_speed := float(game_state.call("get_guardian_chase_speed"))

	_expect(
		trailing_speed > crowding_speed,
		"Guardian closes when it falls behind and eases when it crowds (%.0f vs %.0f)" % [
			trailing_speed, crowding_speed
		]
	)
	_expect(
		crowding_speed < float(player.get("speed")),
		"A crowding Guardian is slower than the player it is chasing (%.0f vs %.0f)" % [
			crowding_speed, float(player.get("speed"))
		]
	)

	# Settle the tether at both extremes. The single-step numbers above only
	# prove direction; the guarantee the player feels is the steady state.
	var player_speed := float(player.get("speed"))
	guardian.global_position = hall.call(
		"_nearest_guardian_walkable_position",
		hall.get("ENEMY_START_POSITION")
	) as Vector2
	for _settle: int in range(60):
		hall.call("_update_guardian_tutorial_pace", 0.1)
	var settled_far := float(game_state.call("get_guardian_chase_speed"))
	_expect(
		settled_far > player_speed,
		"A trailing Guardian outruns the player so it can close the gap (%.0f vs %.0f)" % [
			settled_far, player_speed
		]
	)

	guardian.global_position = hall.call(
		"_nearest_guardian_walkable_position",
		player.global_position + Vector2(64.0, 0.0)
	) as Vector2
	for _settle: int in range(60):
		hall.call("_update_guardian_tutorial_pace", 0.1)
	var settled_near := float(game_state.call("get_guardian_chase_speed"))
	_expect(
		settled_near < player_speed * 0.75,
		"A crowding Guardian falls well behind a moving player (%.0f vs %.0f)" % [
			settled_near, player_speed
		]
	)
	await _drop_hall(hall)


## The payoff beat: it must fire for the player who runs straight there, and it
## must only fire once.
func _test_near_miss_fires_at_the_door(game_state: Node) -> void:
	var hall := await _new_hall(game_state)
	if hall == null:
		return
	var player := hall.get_node_or_null("player") as CharacterBody2D
	if player == null:
		await _drop_hall(hall)
		return

	# Walk the guided route to its final step, then open the door.
	game_state.call("set_story_flag", "hall_first_route_core_studied")
	hall.call("_set_hall_arrival_step", 3)
	await process_frame

	var fired := (
		bool(hall.call("_try_guardian_near_miss"))
		if hall.has_method("_try_guardian_near_miss")
		else false
	)
	_expect(fired, "Entering Chemistry triggers the Guardian near-miss")
	if not fired:
		await _drop_hall(hall)
		return
	await process_frame
	_expect(
		hall.get_node_or_null("GuardianNearMissCamera") != null
		or bool(hall.get("guardian_near_miss_active")),
		"Near-miss takes over the camera for its beat"
	)
	_expect(
		not bool(hall.call("_try_guardian_near_miss")),
		"Near-miss is a one-time beat"
	)
	await _drop_hall(hall)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("guardian_tutorial_chase_test: PASS")
		quit(0)
	else:
		printerr(
			"guardian_tutorial_chase_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
