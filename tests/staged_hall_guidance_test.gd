extends SceneTree

const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-09-07-staged-hall-guidance"

var failures: Array[String] = []
var hall: Node2D
var player: CharacterBody2D
var shipped_route_digest := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))
	var gs := root.get_node("GameState")
	var locale := root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if OS.get_cmdline_user_args().has("--zh") else "en")
	gs.set("_loading_save", true)
	shipped_route_digest = FileAccess.get_sha256(HallRouteStore.ROUTE_PATH)
	var authored := HallRouteStore.load_route()
	HallRouteStore.use_test_path("user://staged_hall_guidance_route.json")
	_expect(HallRouteStore.save_route(authored), "The route fixture is isolated from the shipped file")
	gs.call("reset_new_game")
	gs.game_started = true
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.call("add_key", "chemistry_room_key")
	gs.return_spawn_id = "wake_room_first_arrival"
	# Audit developer startup headlessly; native evidence starts as a normal player.
	var visual_run := OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--preview")
	gs.developer_mode = not visual_run
	hall = (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	player = hall.get_node("player") as CharacterBody2D
	var start_recorder: Node = hall.get("_hall_route_recorder")
	_expect(start_recorder == null, "Scene startup does not automatically record or bypass guidance")
	gs.developer_mode = true
	hall.set("_hall_route_recording_requested", true)
	hall.call("_sync_hall_route_recorder")
	start_recorder = hall.get("_hall_route_recorder")
	_expect(start_recorder != null, "Developer recording starts after Hall setup")
	if start_recorder != null:
		var recorded: Array[Vector2] = start_recorder.call("recorded_points")
		_expect(
			not recorded.is_empty() and recorded[0].is_equal_approx(player.global_position),
			"Recording starts at the resolved spawn, not the scene's 512,384 placeholder"
		)
	gs.call("toggle_developer_mode")
	_expect(not debug_collisions_hint, "Leaving developer mode also clears collision overlays")
	hall.set("guardian_entry_sequence_played", true)
	hall.call("close_message_panel")
	var guardian := hall.get_node("CastleGuardian") as CharacterBody2D
	guardian.call("set_cinematic_hold", false)
	guardian.call("set_behavior", 1)
	await process_frame
	if OS.get_cmdline_user_args().has("--preview"):
		DisplayServer.window_set_title("Shadow Castle - learning and pursuit preview")
		gs.call("save_room_checkpoint", "res://scenes/game_world.tscn", "floor_1_hub", "wake_room_first_arrival")
		await _capture("00-live-preview")
		print("GUIDANCE_PREVIEW_READY: " + ProjectSettings.globalize_path("res://"))
		return

	var core: Vector2 = hall.call("_get_hall_knowledge_position", "ChemistryRoomKnowledge")
	var knowledge_exhibit := hall.get_node("WallCollisions/KnowledgeExhibits/ChemistryRoomKnowledge")
	var visible_feet := RoomSpatialRuntime.new().get_visual_feet(knowledge_exhibit)
	_expect(core.distance_to(visible_feet) < 1.0, "The route targets the visible exhibit, including its edited child transform")
	var copy: Dictionary = hall.call("_hall_route_copy")
	_expect(
		(copy.get("target", Vector2.ZERO) as Vector2).distance_to(core) < 1.0,
		"The first stage guides to knowledge, not past it to the door"
	)
	var reversing_corners := 0
	var wall_markers := 0
	for marker: Node2D in hall.get("hall_route_marker_nodes"):
		if marker.get_meta("route_kind") != "destination" and not hall.call("is_player_position_walkable", marker.global_position):
			wall_markers += 1
			_expect(false, "A guidance marker lies inside a wall at %s" % marker.global_position)
		if marker.get_meta("route_kind") == "corner_90":
			var incoming: Vector2 = marker.get_meta("incoming_direction")
			var outgoing: Vector2 = marker.get_meta("outgoing_direction")
			if not is_zero_approx(incoming.dot(outgoing)):
				reversing_corners += 1
				_expect(false, "Reversing corner at %s: %s -> %s; route tail %s" % [
					marker.position, incoming, outgoing, (hall.get("hall_tutorial_route") as Array).slice(-7)
				])
	_expect(reversing_corners == 0, "The stage connector has no reversing footstep corners")
	_expect(wall_markers == 0, "Every travel marker is on physically walkable floor")
	if not player.has_method("set_movement_locked"):
		_expect(false, "The loaded player script includes the staged movement lock")
		await _finish_validation(gs, locale, previous_language)
		return
	_expect(authored.size() > 2, "The shipped authored route is available")
	if authored.size() > 2:
		var middle: Vector2 = authored[authored.size() / 2]
		var suffix: Array[Vector2] = hall.call(
			"_hall_route_points", middle, hall.get("CHEMISTRY_ROOM_DOOR_FOCUS_POSITION")
		)
		_expect(
			not suffix.is_empty() and suffix[0].distance_to(middle) < 1.0,
			"Refreshing midway starts at the player, never at the Hall entrance"
		)
		_expect(suffix.size() < authored.size(), "Completed footsteps are not replayed")

	await _capture("01-approach-knowledge")
	var travel_route: Array[Vector2] = hall.get("hall_tutorial_route")
	for index: int in range(1, travel_route.size()):
		_expect(
			hall.call("_hall_route_segment_is_walkable", travel_route[index - 1], travel_route[index]),
			"The route segment is physically clear: %s -> %s" % [travel_route[index - 1], travel_route[index]]
		)
	var retired_footprints := false
	player.call("move_along_path", PackedVector2Array(travel_route))
	for _tick: int in range(3600):
		if int(hall.get("hall_arrival_step")) == 2:
			break
		player.call("_physics_process", 1.0 / 60.0)
		hall.call("_process", 1.0 / 60.0)
		for marker: Node2D in hall.get("hall_route_marker_nodes"):
			if not marker.visible and marker.get_meta("route_kind") == "straight":
				retired_footprints = true
		if not bool(player.get("click_movement_active")) and int(hall.get("hall_arrival_step")) != 2:
			_expect(false, "The queued approach ended before the knowledge stop at %s" % player.global_position)
			break
	_expect(int(hall.get("hall_arrival_step")) == 2, "Following the actual floor route reaches the mandatory knowledge stop (at %s)" % player.global_position)
	_expect(retired_footprints, "Passed footsteps disappear as the player walks forward")
	var approach := _find_core_approach()
	_expect(approach != Vector2.ZERO, "The knowledge stop has a physically clear interaction point")
	if approach != Vector2.ZERO:
		player.global_position = approach
		player.call("move_to_point", approach + Vector2.DOWN * 60.0)
		hall.call("_process", 0.0)
		_expect(int(hall.get("hall_arrival_step")) == 2, "Proximity automatically starts the study stage")
		_expect(not bool(player.get("click_movement_active")), "The mandatory stop cancels the queued walk")
		_expect(not gs.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Proximity does not auto-file knowledge")
		var markers: Array = hall.get("hall_route_marker_nodes")
		_expect(markers.is_empty(), "No onward footsteps compete with the required interaction")
		hall.call("_on_case_locale_changed", "en")
		_expect((hall.get("hall_route_marker_nodes") as Array).is_empty(), "Refreshing localized UI cannot reveal the next stage early")
		var stopped_at := player.global_position
		Input.action_press("move_down")
		player.call("_physics_process", 0.1)
		Input.action_release("move_down")
		_expect(player.global_position.is_equal_approx(stopped_at), "Keyboard movement cannot bypass the knowledge stop")
		player.call("move_to_point", stopped_at + Vector2.DOWN * 60.0)
		_expect(not bool(player.get("click_movement_active")), "Direct navigation cannot queue movement during the stop")
		hall.call("_release_stale_guardian_hold", 10.0)
		_expect(not guardian.is_physics_processing(), "The Guardian stays still while the player studies")
		_expect(not bool(guardian.get("catch_enabled")), "The mandatory stop cannot become a lethal trap")
		var mini_map := root.get_node("MapHud").get("guardian_minimap") as Control
		_expect(not mini_map.visible, "Tracking chrome cannot cover the required filing button")
		var countdown := hall.get("guardian_countdown_panel") as Control
		_expect(not countdown.visible, "The stopped Guardian does not display a false urgent countdown")

		hall.call("update_interaction_prompt")
		_expect(str(hall.get("current_interaction")) == "arrival_chemistry_core", "The stopped player can interact immediately")
		await _capture("02-stop-and-interact")
		var core_rect: Rect2 = hall.call("get_interaction_rect", "arrival_chemistry_core")
		hall.call("on_player_ground_move_started", core_rect.get_center())
		_expect(bool(hall.get("dialogue_active")), "Clicking the highlighted core opens its knowledge")
		_expect(not gs.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Reading alone does not complete filing")
		var dossier := hall.get("knowledge_dossier") as CanvasLayer
		_expect(dossier != null and dossier.visible, "The tutorial opens the full illustrated knowledge dossier")
		if dossier == null:
			await _finish_validation(gs, locale, previous_language)
			return
		var principle := dossier.find_child("KnowledgePrinciple", true, false) as Label
		_expect(principle != null and principle.text.length() > 60, "Knowledge content is visible before filing")
		dossier.call("close")
		await process_frame
		await process_frame
		await process_frame
		_expect(bool(player.get("movement_locked")), "Closing without filing keeps the stop in force")
		hall.call("update_interaction_prompt")
		Input.action_press("interact")
		hall.call("_process", 0.0)
		Input.action_release("interact")
		await process_frame
		await process_frame
		_expect(bool(hall.get("dialogue_active")), "E can reopen the knowledge while movement is locked")
		var file_button := dossier.find_child("FileKnowledgeButton", true, false) as Button
		if file_button != null and file_button.visible:
			var file_text: String = root.get_node("CaseLocale").call("text", "knowledge.file")
			_expect(file_button.text == file_text, "The dossier explicitly offers filing after its content")
			await _capture("03-file-knowledge")
			await process_frame
			var click_position := file_button.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = click_position
			root.push_input(motion, true)
			var hovered := root.gui_get_hovered_control()
			_expect(
				hovered == file_button,
				"The filing button receives pointer input at %s (hovered %s)" % [
					click_position, str(hovered.get_path()) if hovered != null else "nothing"
				]
			)
			for pressed: bool in [true, false]:
				var click := InputEventMouseButton.new()
				click.position = click_position
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				root.push_input(click, true)
			await process_frame
			_expect(gs.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "A real mouse click on FILE KNOWLEDGE records the lesson")
			_expect(int(hall.get("hall_arrival_step")) == 3, "Filing unlocks the Chemistry route")
			_expect(mini_map.visible, "Guardian tracking returns after knowledge is filed")
			var note_hud := root.get_node("NoteHud")
			_expect(note_hud.call("has_clue", "hall_knowledge_chemical_change"), "The knowledge actually exists in the notebook")
			var final_path: Array[Vector2] = hall.get("hall_tutorial_route")
			_expect(not final_path.is_empty() and final_path[0].distance_to(player.global_position) < 1.0, "The final leg starts at the core")
			_expect(_path_length(final_path) < _path_length(authored) * 0.6, "The final leg does not replay the long Hall crossing (%.0f px)" % _path_length(final_path))
			stopped_at = player.global_position
			Input.action_press("move_down")
			player.call("_physics_process", 0.1)
			Input.action_release("move_down")
			_expect(player.global_position.distance_to(stopped_at) > 1.0, "Movement resumes after filing, on the same clear floor")
			await _capture("04-continue-to-chemistry")
			for marker: Node2D in hall.get("hall_route_marker_nodes"):
				_expect(hall.call("is_player_position_walkable", marker.global_position), "The onward marker is on clear floor at %s" % marker.global_position)
			player.call("move_along_path", PackedVector2Array(final_path))
			for _tick: int in range(3600):
				if not bool(player.get("click_movement_active")):
					break
				player.call("_physics_process", 1.0 / 60.0)
				hall.call("_process", 1.0 / 60.0)
			hall.call("update_interaction_prompt")
			_expect(str(hall.get("current_interaction")) == "arrival_chemistry_door", "Following the final footsteps reaches the usable Chemistry door")
		else:
			_expect(false, "Knowledge interaction exposes an explicit filing button")

	# Restoring at a room entrance must never preserve a remote movement lock.
	gs.hall_arrival_seen = false
	gs.call("set_story_flag", "hall_first_route_complete", false)
	gs.call("set_story_flag", "hall_knowledge_chemistry_room_collected", false)
	gs.call("set_story_flag", "hall_first_route_core_studied", false)
	gs.call("set_story_flag", "hall_first_route_door_reached", true)
	player.global_position = hall.get("HALL_FIRST_ARRIVAL_POSITION")
	hall.call("_restore_hall_arrival_route")
	_expect(int(hall.get("hall_arrival_step")) == 1, "An unfinished legacy save resumes the approach, not a remote freeze")
	_expect(not bool(player.get("movement_locked")), "Returning before filing remains movable")
	player.global_position = approach
	hall.call("_set_hall_arrival_step", 2)
	_toggle_recording_key(false)
	_expect(bool(gs.developer_mode), "The real 0 shortcut enables developer mode")
	_expect(bool(player.get("movement_locked")), "Developer mode alone cannot bypass the knowledge stop")
	_toggle_recording_key()
	_expect(bool(gs.developer_mode), "Shift+0 controls recording without toggling developer mode")
	_expect(not bool(player.get("movement_locked")), "Route recording can leave a mandatory study stop")
	gs.developer_mode = false
	hall.call("_on_developer_mode_changed")
	_expect(bool(player.get("movement_locked")), "Leaving route recording restores the study stop")
	gs.developer_mode = true
	hall.call("_on_developer_mode_changed")
	_toggle_recording_key()
	player.global_position = hall.get("HALL_FIRST_ARRIVAL_POSITION")
	gs.developer_mode = false
	hall.call("_on_developer_mode_changed")
	_expect(int(hall.get("hall_arrival_step")) == 1, "Cancelling recording away from the core restores the approach")
	_expect(not bool(player.get("movement_locked")), "Recording cannot strand the player with a remote interaction lock")
	player.global_position = approach
	hall.call("_set_hall_arrival_step", 2)
	gs.developer_mode = true
	hall.call("_on_developer_mode_changed")
	_toggle_recording_key()
	var recording_finish := _find_recording_finish()
	_expect(recording_finish != Vector2.ZERO, "Recording can finish on real floor beside the door")
	player.global_position = recording_finish
	var recorder: Node = hall.get("_hall_route_recorder")
	recorder.call("_process", 0.0)
	_expect(bool(recorder.call("is_finished")), "The recorder finishes at the door")
	_expect(not bool(player.get("movement_locked")), "Finishing a recording away from the core also remains movable")
	gs.developer_mode = false
	hall.call("_on_developer_mode_changed")
	HallRouteStore.save_route(authored)
	gs.call("set_story_flag", "hall_first_route_core_studied", true)
	hall.call("_restore_hall_arrival_route")
	_expect(int(hall.get("hall_arrival_step")) == 3, "An already-filed legacy save skips repeated study")
	_expect(not bool(player.get("movement_locked")), "Restoring filed knowledge releases movement")
	gs.call("set_story_flag", "hall_first_route_complete", true)
	hall.call("_restore_hall_arrival_route")
	_expect(int(hall.get("hall_arrival_step")) == 4, "A completed tutorial remains completed")
	_expect((hall.get("hall_route_marker_nodes") as Array).is_empty(), "Completed guidance removes all markers")
	await _finish_validation(gs, locale, previous_language)


func _finish_validation(gs: Node, locale: Node, previous_language: String) -> void:
	current_scene = null
	hall.queue_free()
	await process_frame
	gs.call("reset_new_game")
	gs.game_started = false
	gs.set("_loading_save", false)
	HallRouteStore.clear_route()
	HallRouteStore.clear_test_path()
	_expect(FileAccess.get_sha256(HallRouteStore.ROUTE_PATH) == shipped_route_digest, "The shipped route is byte-identical after testing")
	locale.call("set_language", previous_language)
	if failures.is_empty():
		print("staged_hall_guidance_test: PASS")
		quit(0)
	else:
		printerr("staged_hall_guidance_test: FAIL (%d)" % failures.size())
		quit(1)


func _find_core_approach() -> Vector2:
	if hall.call("_is_near_hall_interaction", "arrival_chemistry_core"):
		if hall.call("is_player_position_walkable", player.global_position + Vector2.DOWN * 24.0):
			return player.global_position
	var spatial := RoomSpatialRuntime.new()
	var rect: Rect2 = hall.call("get_interaction_rect", "arrival_chemistry_core")
	var body := spatial.get_player_collision_rect(player)
	for y: int in range(32, 0, -2):
		for x: int in range(-32, 33, 2):
			var point := Vector2(rect.get_center().x + x, rect.end.y + y)
			var moved := Rect2(body.position + point - player.global_position, body.size)
			if spatial.rect_gap(moved, rect) <= 14.0 and hall.call("is_player_position_walkable", point):
				if hall.call("is_player_position_walkable", point + Vector2.DOWN * 24.0):
					return point
	return Vector2.ZERO


func _toggle_recording_key(shifted: bool = true) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_0
		event.physical_keycode = KEY_0
		event.shift_pressed = shifted
		event.pressed = pressed
		root.push_input(event, true)


func _find_recording_finish() -> Vector2:
	var target: Vector2 = hall.get("CHEMISTRY_ROOM_DOOR_FOCUS_POSITION")
	var core_rect: Rect2 = hall.call("get_interaction_rect", "arrival_chemistry_core")
	var spatial := RoomSpatialRuntime.new()
	var body := spatial.get_player_collision_rect(player)
	for radius: int in range(16, 97, 8):
		for step: int in range(32):
			var point := target + Vector2.from_angle(float(step) * TAU / 32.0) * radius
			var moved := Rect2(body.position + point - player.global_position, body.size)
			if hall.call("is_player_position_walkable", point) and spatial.rect_gap(moved, core_rect) > float(hall.get("HALL_KNOWLEDGE_INTERACTION_MARGIN")):
				return point
	return Vector2.ZERO


func _path_length(points: Array[Vector2]) -> float:
	var length := 0.0
	for index: int in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var evidence_path := (
		"res://docs/evidence/2026-09-07-main-guidance"
		if OS.get_cmdline_user_args().has("--main-evidence") else EVIDENCE_DIRECTORY
	)
	if OS.get_cmdline_user_args().has("--presentation-evidence"):
		evidence_path = "res://docs/evidence/2026-09-07-presentation"
	var directory := ProjectSettings.globalize_path(evidence_path)
	_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Evidence directory is writable")
	var camera := hall.get("follow_camera") as Camera2D
	camera.reset_smoothing()
	await create_timer(0.25, true, false, true).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Capture uses the native viewport")
	var suffix := "-zh" if root.get_node("CaseLocale").call("is_chinese") else ""
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label + suffix)
	var record := FileAccess.open(directory.path_join("runtime" + suffix + ".json"), FileAccess.WRITE)
	_expect(record != null, "Runtime provenance is writable")
	if record != null:
		record.store_string(JSON.stringify({
			"project_path": ProjectSettings.globalize_path("res://"),
			"game_world_sha256": FileAccess.get_sha256("res://scripts/game_world.gd"),
			"route_sha256": FileAccess.get_sha256(HallRouteStore.ROUTE_PATH),
			"wall_scene_sha256": FileAccess.get_sha256("res://scenes/wall_collisions.tscn"),
			"knowledge_feet": str(hall.call("_get_hall_knowledge_position", "ChemistryRoomKnowledge")),
			"viewport": [1024, 768],
		}, "\t"))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		printerr("FAIL: " + description)
