extends SceneTree

const MIN_REACTION_SECONDS: float = 4.0
const MAX_SINGLE_DARK_HALL_SECONDS: float = 18.0
const MAX_FORCED_DARK_HALL_SECONDS: float = 45.0

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.current_room_id = "floor_1_hub"
	game_state.return_spawn_id = "wake_room_first_arrival"
	game_state.call("add_key", "wake_room_key")
	game_state.call("add_key", "chemistry_room_key")

	var packed := load("res://scenes/game_world.tscn") as PackedScene
	_expect(packed != null, "Hall scene loads for standard-flow pressure audit")
	if packed == null:
		_finish()
		return
	var hall := packed.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	hall.set_process(false)
	var player := hall.get_node_or_null("player") as CharacterBody2D
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	if player != null:
		player.set_physics_process(false)
	if guardian != null:
		guardian.set_physics_process(false)
	var constants := (hall.get_script() as GDScript).get_script_constant_map()
	var player_speed := float(player.get("speed")) if player != null else 0.0
	var minimum_entry_distance := float(constants["GUARDIAN_ENTRY_MIN_DISTANCE"])
	var catch_distance := float(constants["GUARDIAN_CATCH_DISTANCE"])
	var segments: Array[Dictionary] = [
		{
			"name": "Wake entrance → Chemistry",
			"from": constants["HALL_FIRST_ARRIVAL_POSITION"],
			"to": constants["CHEMISTRY_ROOM_RETURN_POSITION"],
			"grant": "",
		},
		{
			"name": "Chemistry return → Greenhouse",
			"from": constants["CHEMISTRY_ROOM_RETURN_POSITION"],
			"to": constants["GREENHOUSE_ROOM_DOOR_POSITION"],
			"grant": "greenhouse_room_key",
		},
		{
			"name": "Greenhouse return → Circuit",
			"from": constants["GREENHOUSE_ROOM_DOOR_POSITION"],
			"to": constants["CIRCUIT_DOOR_POSITION"],
			"grant": "circuit_room_key",
		},
	]
	var total_dark_hall_seconds := 0.0
	var minimum_reaction_seconds := INF
	for segment: Dictionary in segments:
		var grant := str(segment["grant"])
		if not grant.is_empty():
			game_state.call("add_key", grant)
		var start := hall.call("_nearest_guardian_walkable_position", segment["from"]) as Vector2
		var finish := hall.call("_nearest_guardian_walkable_position", segment["to"]) as Vector2
		var path := hall.call("_get_hall_route_path", start, finish) as Array
		var path_distance := _path_distance(path)
		var player_seconds := path_distance / maxf(player_speed, 1.0)
		var guardian_speed := float(game_state.call("get_guardian_chase_speed"))
		var reaction_seconds := maxf(minimum_entry_distance - catch_distance, 0.0) / maxf(guardian_speed, 1.0)
		total_dark_hall_seconds += player_seconds
		minimum_reaction_seconds = minf(minimum_reaction_seconds, reaction_seconds)
		print(
			"PRESSURE_AUDIT: %s | distance=%.0fpx player=%.2fs tier=%d guardian=%.1fpx/s entry_reaction=%.2fs"
			% [
				str(segment["name"]),
				path_distance,
				player_seconds,
				int(game_state.call("get_guardian_escalation_tier")),
				guardian_speed,
				reaction_seconds,
			]
		)
		_expect(not path.is_empty() and path_distance > 0.0, str(segment["name"]) + " has a valid A* route")
		_expect(player_speed > guardian_speed, str(segment["name"]) + " keeps the player faster than the Guardian")
		_expect(
			player_seconds <= MAX_SINGLE_DARK_HALL_SECONDS,
			str(segment["name"]) + " keeps one darkness exposure below eighteen seconds"
		)

	print(
		"PRESSURE_AUDIT_SUMMARY: forced_dark_hall=%.2fs minimum_reaction=%.2fs flashlight_radius=230px"
		% [total_dark_hall_seconds, minimum_reaction_seconds]
	)
	_expect(
		total_dark_hall_seconds <= MAX_FORCED_DARK_HALL_SECONDS,
		"Three safe-room-separated darkness exposures stay below forty-five seconds total"
	)
	_expect(
		minimum_reaction_seconds >= MIN_REACTION_SECONDS,
		"Every pre-Circuit Hall return gives at least four seconds before possible contact"
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	_finish()


func _path_distance(path: Array) -> float:
	var distance := 0.0
	for index: int in range(1, path.size()):
		distance += (path[index - 1] as Vector2).distance_to(path[index] as Vector2)
	return distance


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
		print("standard_flow_pressure_audit: PASS")
		quit(0)
		return
	printerr("standard_flow_pressure_audit: FAIL (%d assertion(s))" % failures.size())
	quit(1)
