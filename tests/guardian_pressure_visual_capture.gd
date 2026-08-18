extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-guardian-pressure"

var failures: Array[String] = []
var hall: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create Guardian pressure evidence directory")
		_finish()
		return
	_seed_state(game_state)
	var packed := load("res://scenes/game_world.tscn") as PackedScene
	if packed == null:
		_fail("Castle Hall scene could not load")
		_finish()
		return
	hall = packed.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	await create_timer(0.72).timeout

	_expect(bool(hall.get("guardian_entry_sequence_active")), "Guardian reveal is active for the close-up capture")
	_expect(hall.get_node_or_null("GuardianRevealCamera") != null, "Guardian reveal camera exists")
	await _capture(output_directory.path_join("01-guardian-close-up.png"))

	await create_timer(2.05).timeout
	_expect(not bool(hall.get("guardian_entry_sequence_active")), "Guardian reveal completes before pursuit capture")
	var player := hall.get_node_or_null("player") as CharacterBody2D
	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	if player == null or guardian == null:
		_fail("Hall actors missing from Guardian pressure capture")
		_finish()
		return
	player.set_physics_process(false)
	guardian.set_physics_process(false)
	hall.call("_update_guardian_countdown", 1.0)
	var countdown := hall.get("guardian_countdown_panel") as Panel
	_expect(countdown != null and countdown.visible, "Contact countdown is visible after the reveal")
	var mini_guardian := root.get_node("MapHud").find_child("MiniGuardianMarker", true, false) as Control
	root.get_node("MapHud").call("refresh_guardian_tracking")
	_expect(mini_guardian != null and mini_guardian.visible, "Live red Guardian marker is visible on the minimap")
	await _capture(output_directory.path_join("02-live-countdown-and-minimap.png"))

	player.global_position = Vector2(240.0, 984.0)
	var follow_camera := hall.get("follow_camera") as Camera2D
	if follow_camera != null:
		follow_camera.position_smoothing_enabled = false
		follow_camera.zoom = Vector2(0.75, 0.75)
		follow_camera.make_current()
		follow_camera.reset_smoothing()
	game_state.hall_arrival_seen = false
	hall.call("_set_hall_arrival_step", 1)
	await process_frame
	hall.set_process(false)
	countdown.visible = false
	var route_markers: Array = hall.get("hall_route_marker_nodes") as Array
	var corner_count := 0
	var diagonal_count := 0
	for marker_variant: Variant in route_markers:
		var marker := marker_variant as Node2D
		if marker == null:
			continue
		var kind := str(marker.get_meta("route_kind", ""))
		if kind == "corner_90":
			corner_count += 1
			var incoming := marker.get_meta("incoming_direction", Vector2.ZERO) as Vector2
			var outgoing := marker.get_meta("outgoing_direction", Vector2.ZERO) as Vector2
			if not is_zero_approx(incoming.dot(outgoing)):
				diagonal_count += 1
		elif kind == "straight" or kind == "destination":
			var direction := marker.get_meta("route_direction", Vector2.ZERO) as Vector2
			if not (is_zero_approx(direction.x) != is_zero_approx(direction.y)):
				diagonal_count += 1
	_expect(corner_count > 0, "Route capture includes explicit 90-degree corners")
	_expect(diagonal_count == 0, "Route capture contains no diagonal arrows")
	await _capture(output_directory.path_join("03-orthogonal-blue-route.png"))
	_finish()


func _seed_state(game_state: Node) -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.call("grant_wake_room_toolkit")
	game_state.call("add_key", "wake_room_key")
	game_state.call("add_key", "chemistry_room_key")
	game_state.hall_arrival_seen = true
	game_state.return_spawn_id = "chemistry_door"
	game_state.current_room_id = "floor_1_hub"
	game_state.developer_mode = false
	game_state.chase_mode = false
	game_state.enemy_chase_active = false


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid 1024x768 capture: " + absolute_path)
		return
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
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
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("guardian_pressure_visual_capture: PASS")
		quit(0)
		return
	printerr("guardian_pressure_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
