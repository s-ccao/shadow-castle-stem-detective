extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-guardian-awareness"

var failures: Array[String] = []
var active_scene: Node
var player: CharacterBody2D
var guardian: CharacterBody2D


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create evidence directory")
		_finish()
		return
	_seed_state()
	await _open_hall()
	if not failures.is_empty():
		_cleanup_scene()
		_finish()
		return
	await _capture_tracking_serum(output_directory)
	await _capture_stakeout(output_directory)
	await _capture_sighted(output_directory)
	await _capture_searching(output_directory)
	await _capture_shrouded(output_directory)
	await _capture_stunned(output_directory)
	await _capture_counterplay_bag(output_directory)
	_cleanup_scene()
	paused = false
	_finish()


func _seed_state() -> void:
	var game_state := root.get_node("GameState")
	var note_hud := root.get_node("NoteHud")
	game_state.reset_new_game()
	note_hud.call("reset")
	game_state.game_started = false
	game_state.grant_wake_room_toolkit()
	for key_id: String in ["wake_room_key", "chemistry_room_key", "library_room_key"]:
		game_state.add_key(key_id)
	for recipe_id: String in ["recipe_purification", "recipe_daze", "recipe_shroud"]:
		game_state.call("add_recipe", recipe_id)
	for potion_id: String in ["purification_potion", "daze_potion", "shroud_potion"]:
		game_state.call("add_inventory_item", potion_id)
	note_hud.call("unlock")
	game_state.hall_arrival_seen = true
	game_state.return_spawn_id = "hall_entrance"
	game_state.current_room_id = "floor_1_hub"
	game_state.game_started = true


func _open_hall() -> void:
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
	player = active_scene.get_node_or_null("player") as CharacterBody2D
	guardian = active_scene.get_node_or_null("CastleGuardian") as CharacterBody2D
	if player == null or guardian == null:
		_fail("Hall actors are unavailable")
		return
	var route: Array[Vector2] = _guardian_route()
	if route.size() < 4:
		_fail("Guardian patrol route is unavailable")
		return
	player.global_position = route[0]
	player.set_physics_process(false)
	guardian.set_physics_process(false)
	_focus_camera(player)


func _place_guardian(offset: Vector2) -> void:
	guardian.global_position = active_scene.call(
		"_nearest_guardian_walkable_position", player.global_position + offset
	) as Vector2
	root.get_node("GameState").call("update_guardian_hall_position", guardian.global_position)


func _refresh_awareness() -> void:
	guardian.call("_update_awareness")
	active_scene.call("_update_guardian_awareness_readout")


func _capture_tracking_serum(output_directory: String) -> void:
	_place_guardian(Vector2(-190.0, 0.0))
	_refresh_awareness()
	await _capture(output_directory.path_join("01-tracking-serum-omniscient-chase.png"))


func _capture_stakeout(output_directory: String) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("purify_tracking_serum")
	_place_guardian(Vector2(-260.0, -40.0))
	guardian.set("facing_direction", Vector2.LEFT)
	_refresh_awareness()
	game_state.set("guardian_search_remaining", 0.0)
	game_state.call("begin_guardian_patrol")
	guardian.call("set_behavior", game_state.call("get_guardian_mode"))
	active_scene.call("_update_guardian_awareness_readout")
	await _capture(output_directory.path_join("02-purified-stakeout-slow-patrol.png"))


func _capture_sighted(output_directory: String) -> void:
	_place_guardian(Vector2(-150.0, 0.0))
	guardian.set("facing_direction", Vector2.RIGHT)
	_refresh_awareness()
	await _capture(output_directory.path_join("03-sight-cone-reacquired-chase.png"))


func _capture_searching(output_directory: String) -> void:
	guardian.set("facing_direction", Vector2.LEFT)
	_place_guardian(Vector2(-520.0, 0.0))
	_refresh_awareness()
	await _capture(output_directory.path_join("04-lost-sight-search-sweep.png"))


func _capture_shrouded(output_directory: String) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("apply_potion_effect", "shroud", 12.0)
	_place_guardian(Vector2(-150.0, 0.0))
	guardian.set("facing_direction", Vector2.RIGHT)
	_refresh_awareness()
	await _capture(output_directory.path_join("05-shroud-potion-breaks-line-of-sight.png"))


func _capture_stunned(output_directory: String) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("stun_guardian", 7.0)
	_refresh_awareness()
	await _capture(output_directory.path_join("06-daze-potion-stuns-guardian.png"))


func _capture_counterplay_bag(output_directory: String) -> void:
	var inventory_hud := root.get_node_or_null("InventoryHud") as CanvasLayer
	if inventory_hud == null:
		_fail("InventoryHud autoload is unavailable")
		return
	inventory_hud.call("open_bag")
	await process_frame
	await create_timer(0.35).timeout
	await _capture(output_directory.path_join("07-bag-counterplay-potions.png"))
	inventory_hud.call("close_bag")
	paused = false
	await process_frame


func _guardian_route() -> Array[Vector2]:
	var route: Array[Vector2] = []
	var raw_route: Variant = root.get_node("GameState").call("get_guardian_patrol_route")
	if raw_route is Array:
		for point: Variant in raw_route:
			if point is Vector2:
				route.append(point as Vector2)
	return route


func _focus_camera(target: Node2D) -> void:
	for node: Node in target.find_children("*", "Camera2D", true, false):
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
	if image.save_png(absolute_path) != OK:
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
		print("guardian_awareness_visual_capture: PASS")
		quit(0)
		return
	printerr("guardian_awareness_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
