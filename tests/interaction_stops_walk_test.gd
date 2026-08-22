extends SceneTree

## Interacting is a decision to stop and look at something. A click-move that is
## still running underneath it walks the detective away on its own, which reads
## as the character moving while the player is not touching anything.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.call("unlock_all_hubs")
	game_state.call("grant_wake_room_toolkit")

	await _test_hall_interaction_stops_the_walk(game_state)
	await _test_chemistry_interaction_stops_the_walk(game_state)
	await _test_every_room_entry_point_stops_the_walk(game_state)
	_test_inline_interact_branches_stop_the_walk()

	game_state.reset_new_game()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	_finish()


func _test_hall_interaction_stops_the_walk(game_state: Node) -> void:
	game_state.set("hall_arrival_seen", true)
	game_state.set("return_spawn_id", "chemistry_door")
	game_state.set("current_room_id", "floor_1_hub")

	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame

	var player := hall.get_node_or_null("player") as CharacterBody2D
	_expect(player != null, "Hall player exists")
	if player == null:
		hall.queue_free()
		await process_frame
		return

	# Walk somewhere, then inspect something on the way — the classic case.
	player.call("move_to_point", player.global_position + Vector2(220.0, 0.0))
	_expect(
		bool(player.get("click_movement_active")),
		"Hall walk is running before the interaction"
	)
	hall.set("current_interaction", "hall_knowledge:ChemistryRoomKnowledge")
	hall.call("try_investigate_clue")
	await process_frame
	_expect(
		not bool(player.get("click_movement_active")),
		"Interacting in the Hall stops the walk instead of drifting on"
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame


func _test_chemistry_interaction_stops_the_walk(game_state: Node) -> void:
	game_state.set("return_spawn_id", "chemistry_start")
	game_state.set("current_room_id", "chemistry_room")

	var room := (
		load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
	).instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame

	var player := room.get_node_or_null("Worldsort/player") as CharacterBody2D
	_expect(player != null, "Chemistry player exists")
	if player == null:
		room.queue_free()
		await process_frame
		return

	player.call("move_to_point", player.global_position + Vector2(180.0, 0.0))
	_expect(
		bool(player.get("click_movement_active")),
		"Chemistry walk is running before the interaction"
	)
	room.set("current_interaction", "cabinet")
	room.call("handle_interaction")
	await process_frame
	_expect(
		not bool(player.get("click_movement_active")),
		"Interacting in Chemistry stops the walk instead of drifting on"
	)

	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame


## Every room that reads the interact key owns this rule. Covering only the two
## rooms the player meets first would let the other four drift again.
func _test_every_room_entry_point_stops_the_walk(game_state: Node) -> void:
	var rooms: Array = [
		["res://scenes/floor_1/circuit_room.tscn", "circuit_room", "try_interact"],
		["res://scenes/floor_1/library_room.tscn", "library", "try_interact"],
		["res://scenes/floor_1/dining_hall_room.tscn", "dining_hall", "try_interact"],
		["res://scenes/floor_1/final_room.tscn", "final_deduction_room", "try_interact"],
	]
	for entry: Array in rooms:
		var scene_path := str(entry[0])
		var room_id := str(entry[1])
		var method := str(entry[2])
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		game_state.set("current_room_id", room_id)
		var room := packed.instantiate()
		root.add_child(room)
		current_scene = room
		await process_frame
		await process_frame

		var player := _find_player(room)
		if player == null:
			_expect(false, "%s exposes a player body" % room_id)
		else:
			player.call("move_to_point", player.global_position + Vector2(160.0, 0.0))
			if not bool(player.get("click_movement_active")):
				# Some rooms clamp movement to walkable floor; nudge the other way.
				player.call("move_to_point", player.global_position - Vector2(160.0, 0.0))
			var was_walking := bool(player.get("click_movement_active"))
			room.set("current_interaction", "exit")
			room.call(method)
			await process_frame
			_expect(
				was_walking and not bool(player.get("click_movement_active")),
				"Interacting in %s stops the walk (was walking: %s)" % [room_id, was_walking]
			)

		if current_scene == room:
			current_scene = null
		room.queue_free()
		await process_frame


## The Greenhouse and Wake Room answer the interact key inline inside their
## prompt loop rather than through one entry function, so there is no seam to
## call. Guard the shape of those branches instead: every one of them has to
## stop the walk before it opens anything.
func _test_inline_interact_branches_stop_the_walk() -> void:
	var inline_rooms: Dictionary = {
		"res://scripts/greenhouse_room.gd": "_stop_walking_to_interact",
		"res://scripts/wake_room.gd": "cancel_pending_mouse_interaction",
	}
	for script_path: String in inline_rooms:
		var stopper := str(inline_rooms[script_path])
		var source := FileAccess.get_file_as_string(script_path)
		_expect(not source.is_empty(), "Read %s" % script_path)
		if source.is_empty():
			continue
		var lines := source.split("\n")
		var unguarded := 0
		var branches := 0
		for index: int in range(lines.size()):
			if not lines[index].contains("is_action_just_pressed(\"interact\")"):
				continue
			# Prompt-only guards read the key to decide whether to show a hint;
			# only branches that actually act on it need to stop the walk.
			var window := ""
			for look: int in range(index, mini(index + 7, lines.size())):
				window += lines[look] + "\n"
			if not window.contains("("):
				continue
			branches += 1
			if not window.contains(stopper):
				unguarded += 1
		_expect(
			branches > 0,
			"%s still answers the interact key" % script_path.get_file()
		)
		_expect(
			unguarded == 0,
			"%s stops the walk in every interact branch (%d unguarded of %d)" % [
				script_path.get_file(), unguarded, branches
			]
		)


func _find_player(room: Node) -> CharacterBody2D:
	var direct := room.get_node_or_null("player") as CharacterBody2D
	if direct != null:
		return direct
	return room.get_node_or_null("Worldsort/player") as CharacterBody2D


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("interaction_stops_walk_test: PASS")
		quit(0)
	else:
		printerr(
			"interaction_stops_walk_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
