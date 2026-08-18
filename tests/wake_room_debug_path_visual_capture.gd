extends SceneTree

const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-13-opening-flow"
const VIEWPORT_SIZE := Vector2i(1024, 768)

var failures: Array[String] = []


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_fail("GameState autoload is unavailable")
		_finish()
		return
	game_state.set("_loading_save", true)
	# Reproduce the normal New Case runtime without writing or replacing a save.
	game_state.game_started = true
	game_state.developer_mode = false

	var packed_scene := load("res://scenes/wake_room.tscn") as PackedScene
	if packed_scene == null:
		_fail("Wake Room scene could not be loaded")
		_finish()
		return

	var wake_room := packed_scene.instantiate()
	root.add_child(wake_room)
	await process_frame
	await process_frame

	var debug_path := wake_room.get_node_or_null("DebugAStarPath") as Line2D
	if debug_path == null:
		_fail("Wake Room runtime dependencies are unavailable")
		wake_room.queue_free()
		await process_frame
		_finish()
		return

	var sample_path := PackedVector2Array([
		Vector2(500.0, 550.0),
		Vector2(560.0, 510.0),
		Vector2(640.0, 475.0),
		Vector2(720.0, 430.0),
	])

	game_state.developer_mode = false
	wake_room.call("show_debug_room_path", sample_path)
	if debug_path.visible:
		_fail("Normal-play capture unexpectedly exposes the debug path")
	await _capture_viewport(
		EVIDENCE_DIRECTORY + "/01-wake-room-normal-path-hidden.png"
	)

	game_state.developer_mode = true
	wake_room.call("show_debug_room_path", sample_path)
	if not debug_path.visible:
		_fail("Developer capture could not display the debug path")
	await _capture_viewport(
		EVIDENCE_DIRECTORY + "/02-wake-room-developer-path-visible.png"
	)

	game_state.developer_mode = false
	wake_room.call("show_debug_room_path", sample_path)
	var player := wake_room.get_node_or_null("player") as CharacterBody2D
	var props := wake_room.get("props") as Dictionary
	var bookshelf := props.get("bookshelf", {}) as Dictionary
	if player == null or bookshelf.is_empty():
		_fail("Wake bookshelf runtime data is unavailable")
	else:
		player.global_position = bookshelf.get("position", Vector2.ZERO) as Vector2
		player.set_physics_process(false)
		wake_room.call("update_interaction_prompt")
		wake_room.call("update_interaction_focus")
		if str(wake_room.get("current_interaction")) != "prop:bookshelf":
			_fail("Wake bookshelf is not selectable from its reachable point")
		await _capture_viewport(
			EVIDENCE_DIRECTORY + "/03-wake-bookshelf-interaction-restored.png"
		)

	wake_room.queue_free()
	await process_frame
	_finish()


func _capture_viewport(project_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		_fail("Viewport capture was empty: " + project_path)
		return
	if image.get_size() != VIEWPORT_SIZE:
		_fail(
			"Viewport capture was %s instead of %s" % [
				image.get_size(),
				VIEWPORT_SIZE,
			]
		)
		return
	var absolute_path := ProjectSettings.globalize_path(project_path)
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("Could not save viewport capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("wake_room_debug_path_visual_capture: PASS")
		quit(0)
		return
	printerr(
		"wake_room_debug_path_visual_capture: FAIL (%d issue(s))" % failures.size()
	)
	quit(1)
