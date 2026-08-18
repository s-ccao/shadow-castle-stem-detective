extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-power-blackout"

var failures: Array[String] = []
var game_state: Node
var hall: Node
var player: CharacterBody2D


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create blackout evidence directory")
		_finish()
		return
	_seed_state()
	await _open_hall()
	if not failures.is_empty():
		_finish()
		return
	await _capture_pre_power_world(output_directory)
	await _capture_pre_power_map(output_directory)
	await _capture_post_power_world(output_directory)
	await _capture_post_power_map(output_directory)
	_finish()


func _seed_state() -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.current_room_id = "floor_1_hub"
	game_state.call("grant_wake_room_toolkit")
	game_state.call("add_key", "wake_room_key")
	game_state.call("add_key", "chemistry_room_key")
	game_state.call("unlock_map_hub")
	game_state.call("set_story_flag", "circuit_power_restored", false)
	for cell_x: int in range(8, 23):
		game_state.hall_explored_cells["%d,30" % cell_x] = true


func _open_hall() -> void:
	var packed := load("res://scenes/game_world.tscn") as PackedScene
	if packed == null:
		_fail("Castle Hall scene could not load")
		return
	hall = packed.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	if bool(hall.get("guardian_entry_sequence_active")):
		await create_timer(2.75).timeout
	_expect(
		not bool(hall.get("guardian_entry_sequence_active")),
		"Blackout captures begin after the fog-suppressing Guardian reveal"
	)
	hall.set_process(false)
	player = hall.get_node_or_null("player") as CharacterBody2D
	if player == null:
		_fail("Castle Hall player is unavailable")
		return
	player.set_physics_process(false)
	player.global_position = Vector2(480.0, 976.0)
	_focus_camera()


func _capture_pre_power_world(output_directory: String) -> void:
	hall.call("update_fog_of_war")
	await _capture(output_directory.path_join("01-blackout-flashlight-only.png"))


func _capture_pre_power_map(output_directory: String) -> void:
	var map_hud := root.get_node("MapHud")
	map_hud.call("open_map")
	# The hub fades in over roughly a fifth of a second. Capturing before it
	# settles photographs a translucent field, and the hall art behind it bleeds
	# through as a building outline the running game never shows.
	await create_timer(0.45).timeout
	await _capture(output_directory.path_join("02-blackout-map-all-black.png"))
	_expect(
		await _survey_field_brightness() < 0.05,
		"Pre-power survey field stays dark instead of leaking the hall outline"
	)
	map_hud.call("close_map")
	paused = false
	await process_frame


func _capture_post_power_world(output_directory: String) -> void:
	game_state.call("set_story_flag", "circuit_power_restored", true)
	hall.call("update_fog_of_war")
	await _capture(output_directory.path_join("03-powered-walked-ground-gray.png"))


func _capture_post_power_map(output_directory: String) -> void:
	var map_hud := root.get_node("MapHud")
	map_hud.call("open_map")
	await _capture(output_directory.path_join("04-powered-map-memory.png"))
	map_hud.call("close_map")
	paused = false
	await process_frame


func _focus_camera() -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2(1.35, 1.35)
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


## Mean brightness of the survey field. Blackout secrecy is a rule the gate can
## measure, so it no longer depends on someone noticing a faint outline.
func _survey_field_brightness() -> float:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		return 1.0
	var total := 0.0
	var samples := 0
	for y: int in range(160, 600, 8):
		for x: int in range(70, 730, 8):
			var pixel := image.get_pixel(x, y)
			total += (pixel.r + pixel.g + pixel.b) / 3.0
			samples += 1
	return 1.0 if samples == 0 else total / float(samples)


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


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if hall != null and is_instance_valid(hall):
		if current_scene == hall:
			current_scene = null
		hall.queue_free()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("power_blackout_visual_capture: PASS")
		quit(0)
		return
	printerr("power_blackout_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
