extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-power-restoration"

var failures: Array[String] = []
var game_state: Node
var active_scene: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create power-restoration evidence directory")
		_finish()
		return
	await _capture_circuit_impact(output_directory)
	await _capture_hall_scan(output_directory)
	_cleanup_scene()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	_finish()


func _capture_circuit_impact(output_directory: String) -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.call("grant_wake_room_toolkit")
	game_state.current_room_id = "circuit_room"
	var packed := load("res://scenes/floor_1/circuit_room.tscn") as PackedScene
	if packed == null:
		_fail("Circuit Room scene could not load")
		return
	active_scene = packed.instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	var player := active_scene.get_node_or_null("Worldsort/player") as CharacterBody2D
	if player == null:
		_fail("Circuit player is unavailable")
		return
	player.global_position = Vector2(870.0, 800.0)
	player.set_physics_process(false)
	_focus_camera(player, Vector2(0.78, 0.78))
	var items := active_scene.get("INTERACT_ITEMS") as Array
	# Each plate is released by clearing its own bench first. This harness
	# documents the restoration milestone, so the benches are pre-cleared here;
	# they carry their own contract and their own captures.
	for bench_flag: String in (active_scene.get("BENCH_FOR_SWITCH") as Dictionary).values():
		game_state.call("set_story_flag", bench_flag)
	for switch_id: String in ["switch_left", "switch_right", "master_switch"]:
		var item := _find_item(items, switch_id)
		active_scene.call("_handle_switch_interaction", switch_id, item)
	await create_timer(0.36).timeout
	_expect(active_scene.find_child("GeneratorPowerImpact", true, false) != null, "Generator impact is visible")
	_expect(active_scene.find_child("PowerRestorationFlash", true, false) != null, "Power light flicker is visible")
	await _capture(output_directory.path_join("01-master-switch-generator-impact.png"))
	_cleanup_scene()
	await process_frame
	await process_frame


func _capture_hall_scan(output_directory: String) -> void:
	game_state.current_room_id = "floor_1_hub"
	game_state.hall_arrival_seen = true
	game_state.return_spawn_id = "circuit_door"
	for x: int in range(4, 48):
		var y := 21 + int(round(4.0 * sin(float(x) * 0.34)))
		game_state.hall_explored_cells["%d,%d" % [x, y]] = true
	var packed := load("res://scenes/game_world.tscn") as PackedScene
	if packed == null:
		_fail("Castle Hall scene could not load")
		return
	active_scene = packed.instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	await create_timer(0.48).timeout
	_expect(active_scene.get("power_route_scan_active") == true, "Route-memory scan is active in the partial capture")
	await _capture(output_directory.path_join("02-hall-route-memory-scanning.png"))
	await create_timer(0.82).timeout
	var title := active_scene.get("power_restoration_title") as Label
	_expect(title != null and title.text.contains("POWER RESTORED · ROUTE MEMORY ONLINE"), "Route-memory-online prompt is visible")
	await _capture(output_directory.path_join("03-hall-route-memory-online.png"))
	var map_hud := root.get_node("MapHud")
	map_hud.call("open_map")
	await process_frame
	_expect(
		(map_hud.get("overlay") as Control).visible and map_hud.visible,
		"Powered Map reward opens visibly (layer=%s overlay=%s unlocked=%s)" % [
			str(map_hud.visible),
			str((map_hud.get("overlay") as Control).visible),
			str(game_state.is_map_hub_unlocked()),
		]
	)
	await _capture(output_directory.path_join("04-powered-map-reward.png"))
	map_hud.call("close_map")
	paused = false


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item: Dictionary in items:
		if str(item.get("name", "")) == item_name:
			return item
	return {}


func _focus_camera(player: Node2D, zoom: Vector2) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.zoom = zoom
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
		print("power_restoration_visual_capture: PASS")
		quit(0)
		return
	printerr("power_restoration_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
