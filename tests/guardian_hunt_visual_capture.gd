extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-guardian-hunt"

var failures: Array[String] = []
var active_scene: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create evidence directory")
		_finish()
		return
	_seed_state()
	await _capture_hall_chase(output_directory)
	await _capture_room_patrol(output_directory)
	_cleanup_scene()
	paused = false
	_finish()


func _seed_state() -> void:
	var game_state := root.get_node_or_null("GameState")
	var note_hud := root.get_node_or_null("NoteHud")
	game_state.reset_new_game()
	note_hud.call("reset")
	game_state.game_started = false
	game_state.grant_wake_room_toolkit()
	game_state.add_key("wake_room_key")
	game_state.add_key("chemistry_room_key")
	note_hud.call("unlock")
	game_state.hall_arrival_seen = true
	game_state.return_spawn_id = "hall_entrance"
	game_state.current_room_id = "floor_1_hub"
	game_state.game_started = true


func _capture_hall_chase(output_directory: String) -> void:
	var scene := load("res://scenes/game_world.tscn") as PackedScene
	if scene == null:
		_fail("Hall scene could not load")
		return
	active_scene = scene.instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	await create_timer(0.45).timeout
	if bool(active_scene.get("guardian_entry_sequence_active")):
		await create_timer(2.25).timeout

	var player := active_scene.get_node_or_null("player") as CharacterBody2D
	var guardian := active_scene.get_node_or_null("CastleGuardian") as CharacterBody2D
	var route: Array[Vector2] = _guardian_route()
	if player == null or guardian == null or route.size() < 6:
		_fail("Hall chase actors or patrol route are unavailable")
		return
	player.global_position = route[0]
	guardian.global_position = active_scene.call(
		"_nearest_guardian_walkable_position",
		player.global_position + Vector2(-150.0, 0.0)
	) as Vector2
	player.set_physics_process(false)
	guardian.set_physics_process(false)
	root.get_node("GameState").call("update_guardian_hall_position", guardian.global_position)
	_focus_camera(player)
	root.get_node("MapHud").call("refresh_guardian_tracking")
	await _capture(output_directory.path_join("01-hall-pursuit-minimap.png"))

	var map_hud := root.get_node("MapHud") as CanvasLayer
	map_hud.call("open_map")
	# The hub fades in over roughly a fifth of a second. Capturing before it
	# settles photographs a translucent field, and the hall render behind it
	# bleeds through as an outline and stray HUD the running game never shows.
	await create_timer(0.45).timeout
	await _capture(output_directory.path_join("02-hall-pursuit-full-map.png"))
	map_hud.call("close_map")
	paused = false


func _capture_room_patrol(output_directory: String) -> void:
	var game_state := root.get_node("GameState")
	var guardian := active_scene.get_node_or_null("CastleGuardian") as Node2D
	if guardian != null:
		game_state.call("update_guardian_hall_position", guardian.global_position)
	game_state.call(
		"prepare_room_transition",
		"chemistry_room",
		"res://scenes/game_world.tscn",
		"chemistry_door"
	)
	_cleanup_scene()
	await process_frame
	await create_timer(0.75).timeout

	var scene := load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
	if scene == null:
		_fail("Chemistry scene could not load")
		return
	active_scene = scene.instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var player := active_scene.get_node_or_null("Worldsort/player") as CharacterBody2D
	if player == null:
		_fail("Chemistry player is unavailable")
		return
	player.global_position = Vector2(650.0, 780.0)
	player.set_physics_process(false)
	_focus_camera(player)
	root.get_node("MapHud").call("refresh_guardian_tracking")
	await _capture(output_directory.path_join("03-chemistry-safe-room-hall-patrol.png"))


func _guardian_route() -> Array[Vector2]:
	var route: Array[Vector2] = []
	var raw_route: Variant = root.get_node("GameState").call("get_guardian_patrol_route")
	if raw_route is Array:
		for point: Variant in raw_route:
			if point is Vector2:
				route.append(point as Vector2)
	return route


func _focus_camera(player: Node2D) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid viewport capture: " + absolute_path)
		return
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _cleanup_scene() -> void:
	if active_scene != null and is_instance_valid(active_scene):
		if current_scene == active_scene:
			current_scene = null
		active_scene.queue_free()
	active_scene = null


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("guardian_hunt_visual_capture: PASS")
		quit(0)
		return
	printerr("guardian_hunt_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
