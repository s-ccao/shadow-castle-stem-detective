extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/wake_room.tscn") as PackedScene
	_expect(packed_scene != null, "Wake Room scene loads")
	if packed_scene == null:
		_finish()
		return

	var wake_room := packed_scene.instantiate()
	root.add_child(wake_room)
	await process_frame
	await process_frame

	var game_state := root.get_node_or_null("GameState")
	var debug_path := wake_room.get_node_or_null("DebugAStarPath") as Line2D
	_expect(game_state != null, "GameState autoload is available")
	_expect(debug_path != null, "Wake Room creates its optional debug path")
	if game_state == null or debug_path == null:
		wake_room.queue_free()
		await process_frame
		_finish()
		return

	var sample_path := PackedVector2Array([
		Vector2(500.0, 550.0),
		Vector2(620.0, 550.0),
	])

	game_state.developer_mode = false
	wake_room.call("show_debug_room_path", sample_path)
	_expect(
		not debug_path.visible,
		"Normal play keeps the A* debug path hidden"
	)

	game_state.developer_mode = true
	wake_room.call("show_debug_room_path", sample_path)
	_expect(
		debug_path.visible,
		"Developer mode can still display the A* debug path"
	)

	var props := wake_room.get("props") as Dictionary
	var player := wake_room.get_node_or_null("player") as CharacterBody2D
	var bookshelf := props.get("bookshelf", {}) as Dictionary
	var bookshelf_rect := bookshelf.get("interaction_rect", Rect2()) as Rect2
	_expect(
		bookshelf_rect.size.x >= 150.0 and bookshelf_rect.size.y >= 150.0,
		"Wake bookshelf preserves its authored collision-sized interaction boundary"
	)
	if player != null and not bookshelf.is_empty():
		player.global_position = bookshelf.get("position", Vector2.ZERO) as Vector2
		wake_room.call("update_interaction_prompt")
		_expect(
			str(wake_room.get("current_interaction")) == "prop:bookshelf",
			"Wake bookshelf is selected from its computed reachable interaction point "
			+ "(point=%s rect=%s selected=%s)" % [
				player.global_position,
				bookshelf_rect,
				str(wake_room.get("current_interaction")),
			]
		)

	# The Chemistry key used to be missable: the exit only checked its own lock, so
	# a player could walk into the hall without the key the next room needs.
	wake_room.set("desk_briefing_read", true)
	wake_room.set("first_lock_rule_learned", true)
	wake_room.set("exit_door_unlocked", true)
	(game_state.get("key_items") as Array).clear()
	var outstanding: Array = wake_room.call("unclaimed_room_items")
	_expect(
		outstanding.size() >= 1,
		"Wake Room still owes the player its keys before the exit opens (%s)" % [outstanding]
	)
	game_state.call("add_key", "wake_room_key")
	game_state.call("add_key", "chemistry_room_key")
	outstanding = wake_room.call("unclaimed_room_items")
	_expect(
		outstanding.is_empty(),
		"A fully searched Wake Room lets the player leave (%s)" % [outstanding]
	)

	game_state.developer_mode = false
	wake_room.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("wake_room_debug_path_test: PASS")
		quit(0)
		return
	printerr(
		"wake_room_debug_path_test: FAIL (%d assertion(s))" % failures.size()
	)
	quit(1)
