extends SceneTree

var failures: Array[String] = []
var state: Node
var hall: Node2D
var player: CharacterBody2D
var guardian: CharacterBody2D


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))
	state = root.get_node("GameState")
	var locale := root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if "--zh" in OS.get_cmdline_user_args() else "en")
	state.set("_loading_save", true)
	await _new_hall()
	await _check_comfortable_approach()
	await _drop_hall()
	await _new_hall()
	await _check_knowledge_screen()
	await _drop_hall()
	await _new_hall()
	await _check_off_route_capture()
	await _drop_hall()
	state.call("reset_new_game")
	state.game_started = false
	state.set("_loading_save", false)
	locale.call("set_language", previous_language)
	if failures.is_empty():
		print("hall_learning_experience_test: PASS")
		quit(0)
	else:
		printerr("hall_learning_experience_test: FAIL (%d)" % failures.size())
		quit(1)


func _new_hall() -> void:
	state.call("reset_new_game")
	state.game_started = true
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	state.call("add_key", "chemistry_room_key")
	state.return_spawn_id = "wake_room_first_arrival"
	hall = (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	player = hall.get_node("player") as CharacterBody2D
	guardian = hall.get_node("CastleGuardian") as CharacterBody2D
	hall.set("guardian_entry_sequence_played", true)
	hall.call("close_message_panel")
	guardian.call("set_cinematic_hold", false)
	guardian.call("set_behavior", 1)


func _drop_hall() -> void:
	current_scene = null
	hall.queue_free()
	await process_frame
	await process_frame


func _check_comfortable_approach() -> void:
	var target: Rect2 = hall.call("get_interaction_rect", "arrival_chemistry_core")
	var spatial := RoomSpatialRuntime.new()
	var body := spatial.get_player_collision_rect(player)
	var route := HallRouteStore.load_route()
	var approach := Vector2.INF
	for index: int in range(route.size() - 1, -1, -1):
		var moved := Rect2(body.position + route[index] - player.global_position, body.size)
		var gap := spatial.rect_gap(moved, target)
		if gap >= 36.0 and gap <= 64.0 and hall.call("is_player_position_walkable", route[index]):
			approach = route[index]
			break
	_expect(approach.is_finite(), "A real route point exists 36-64px away from the visible knowledge")
	if not approach.is_finite():
		return
	player.global_position = approach
	player.call("move_to_point", approach + Vector2.UP * 80.0)
	hall.call("_process", 0.0)
	_expect(int(hall.get("hall_arrival_step")) == 2, "Approaching knowledge does not require touching the prop")
	_expect(not bool(player.get("click_movement_active")), "The broader approach zone stops the queued walk")
	hall.call("update_interaction_prompt")
	_expect(str(hall.get("current_interaction")) == "arrival_chemistry_core", "The stopped player can inspect from the comfortable distance")
	_expect(not state.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Approach alone never files knowledge")
	await _capture("01-comfortable-knowledge-stop")
	# A wall between the viewer and the exhibit must defeat the expanded range.
	hall.set_process(false)
	var barrier := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	var feet := Vector2(clampf(approach.x, target.position.x, target.end.x), target.end.y)
	var centre := approach.lerp(feet, 0.5)
	shape.polygon = PackedVector2Array([
		centre + Vector2(-40, -10), centre + Vector2(40, -10),
		centre + Vector2(40, 10), centre + Vector2(-40, 10),
	])
	barrier.add_child(shape)
	hall.get_node("WallCollisions").add_child(barrier)
	hall.call("build_sight_blockers")
	_expect(not hall.call("_is_near_hall_interaction", "arrival_chemistry_core"), "The expanded knowledge zone does not trigger through a wall")
	barrier.queue_free()
	await process_frame
	hall.call("build_sight_blockers")
	hall.set_process(true)


func _check_knowledge_screen() -> void:
	hall.call("_set_hall_arrival_step", 4)
	state.hall_arrival_seen = true
	hall.call("_inspect_hall_knowledge", "ChemistryRoomKnowledge")
	var dossier := hall.get_node_or_null("HallKnowledgeDossier") as CanvasLayer
	_expect(dossier != null and dossier.visible, "Inspecting a knowledge exhibit opens a dedicated knowledge screen")
	_expect(not state.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Opening knowledge shows content before awarding it")
	if dossier == null:
		hall.call("close_message_panel")
		return
	var principle := dossier.find_child("KnowledgePrinciple", true, false) as Label
	_expect(principle != null and principle.text.length() > 60, "The knowledge screen contains a substantive science principle")
	if principle != null and root.get_node("CaseLocale").call("is_chinese"):
		_expect(_has_chinese(principle.text), "The science principle is Chinese in the Chinese interface")
	var artwork := dossier.find_child("KnowledgeArtwork", true, false) as TextureRect
	_expect(artwork != null and artwork.texture != null, "The knowledge screen illustrates the actual exhibit")
	var examples := dossier.find_child("KnowledgeExamples", true, false) as Control
	_expect(examples != null and examples.get_child_count() >= 2, "Examples explain the idea rather than only announcing a reward")
	var file_button := dossier.find_child("FileKnowledgeButton", true, false) as Button
	_expect(file_button != null and file_button.visible, "A deliberate filing action is available")
	if file_button == null:
		return
	await process_frame
	await _capture("02-chemistry-knowledge-dossier")
	_click(file_button)
	await process_frame
	_expect(state.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Filing records the knowledge")
	_expect(root.get_node("NoteHud").call("has_clue", "hall_knowledge_chemical_change"), "The notebook contains the filed knowledge")
	hall.call("_inspect_hall_knowledge", "ChemistryRoomKnowledge")
	_expect(dossier.visible, "Already-collected knowledge can be reopened and reviewed")
	_expect(principle.text.length() > 60, "Review retains the actual lesson, not an already-obtained message")
	await _capture("03-filed-knowledge-review")
	var close_button := dossier.find_child("CloseKnowledgeButton", true, false) as Button
	if close_button != null:
		close_button.pressed.emit()
	for exhibit_id: String in ["CircuitRoomKnowledge", "GreenhouseRoomKnowledge", "DiningHallKnowledge", "LibraryRoomKnowledge"]:
		hall.call("_inspect_hall_knowledge", exhibit_id)
		_expect(dossier.visible and principle.text.length() > 60, "The full knowledge dossier also serves " + exhibit_id)
		if root.get_node("CaseLocale").call("is_chinese"):
			_expect(_has_chinese(principle.text), "The science principle is localized for " + exhibit_id)
		await _capture(exhibit_id)
		close_button.pressed.emit()


func _check_off_route_capture() -> void:
	var route: Array[Vector2] = hall.get("hall_tutorial_route")
	var away := Vector2.INF
	for y: int in range(160, 1184, 32):
		for x: int in range(160, 1760, 32):
			var point := Vector2(x, y)
			if not hall.call("is_player_position_walkable", point):
				continue
			var projection: Dictionary = hall.call("_project_onto_hall_route", route, point)
			var distance: float = projection["distance"]
			if distance >= 160.0 and distance <= 240.0:
				away = point
				break
		if away.is_finite():
			break
	_expect(away.is_finite(), "Off-route check uses real clear floor beyond the guide corridor")
	if not away.is_finite():
		return
	player.global_position = away
	hall.call("_update_hall_tutorial_chase")
	hall.call("_tick_hall_route_exposure", true, 1.5)
	hall.call("_update_hall_tutorial_chase")
	_expect(player.global_position.distance_to(away) < 1.0, "Leaving the guide no longer teleports the player back")
	_expect(bool(guardian.get("catch_enabled")), "Leaving the guide arms real Guardian capture")
	var guard_origin := guardian.global_position
	for _frame: int in range(45):
		await physics_frame
	_expect(guardian.global_position.distance_to(guard_origin) > 8.0, "The unprotected Guardian really pursues rather than remaining a scripted statue")
	await _capture("08-real-off-route-pursuit")
	guardian.global_position = player.global_position
	guardian.call("check_player_collision")
	await process_frame
	_expect(bool(hall.get("game_over")), "Actual off-route Guardian contact opens checkpoint recovery")


func _click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = position
	root.push_input(move, true)
	_expect(root.gui_get_hovered_control() == button, "The knowledge action is not covered by another UI surface")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _has_chinese(text: String) -> bool:
	for index: int in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x4e00 and code <= 0x9fff:
			return true
	return false


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var directory := ProjectSettings.globalize_path("res://docs/evidence/2026-09-07-learning-experience")
	_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Evidence directory is writable")
	var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var camera := hall.get("follow_camera") as Camera2D
	camera.reset_smoothing()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var dossier := hall.get_node_or_null("HallKnowledgeDossier") as CanvasLayer
	if dossier != null and dossier.visible:
		var frame := dossier.get("frame") as Control
		_expect(Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(frame.get_global_rect()), "The entire knowledge dossier fits the native viewport")
		var action := dossier.find_child("FileKnowledgeButton", true, false) as Button
		_expect(frame.get_global_rect().encloses(action.get_global_rect()), "The filing action stays inside its frame")
	var image := root.get_texture().get_image()
	var suffix := "-zh" if root.get_node("CaseLocale").call("is_chinese") else ""
	_expect(image.get_size() == Vector2i(1024, 768), "Evidence uses native 1024x768")
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label + suffix)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		printerr("FAIL: " + description)
