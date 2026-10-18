extends SceneTree

var failures: Array[String] = []
var hall: Node2D
var state: Node
var capture := false


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))
	state = root.get_node("GameState")
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.game_started = true
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	state.call("add_key", "chemistry_room_key")
	state.call("set_story_flag", "hall_knowledge_chemistry_room_collected")
	state.call("set_story_flag", "hall_first_route_core_studied")
	state.return_spawn_id = "chemistry_door"
	var locale := root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if "--zh" in OS.get_cmdline_user_args() else "en")
	hall = (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	hall.set("guardian_entry_sequence_played", true)
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	hall.set("guardian_entry_sequence_played", true)
	hall.set("guardian_entry_sequence_active", false)
	hall.call("close_message_panel")
	var player := hall.get_node("player") as CharacterBody2D
	var route: Array[Vector2] = hall.get("hall_tutorial_route")
	_expect(not route.is_empty(), "The filed-knowledge route reaches the Chemistry door")
	if not route.is_empty():
		player.global_position = route[-1]
	hall.call("update_interaction_prompt")
	_expect(str(hall.get("current_interaction")) == "arrival_chemistry_door", "The test uses the actual first-arrival door interaction")
	hall.call("try_investigate_clue")
	await process_frame
	var question := hall.get_node_or_null("ChemistryDoorQuestion") as CanvasLayer
	_expect(question != null and question.visible, "E at the first Chemistry door opens its question, not the escape scene")
	_expect(not state.call("has_story_flag", "door_chemistry_unlocked"), "Opening the door interaction does not grant an unlock")
	_expect(not bool(hall.get("guardian_near_miss_active")), "The near-miss waits until the knowledge question is answered")
	_expect(not str(locale.call("text", "hall.near_miss_title")).contains("IT HAS YOU"), "Near-miss copy does not falsely announce a capture")
	if question != null:
		var choices := question.find_child("DoorAnswers", true, false) as Control
		_expect(choices != null and choices.get_child_count() == 4, "All four answer choices are presented")
		await _capture("01-chemistry-question")
		var data: Dictionary = hall.get("DOOR_QUESTIONS")["chemistry"]
		var correct := int(data["correct"])
		var wrong := (correct + 1) % 4
		_choice(choices, wrong).pressed.emit()
		_expect(not state.call("has_story_flag", "door_chemistry_unlocked"), "A wrong answer keeps the lock closed")
		_expect(not bool(hall.get("guardian_near_miss_active")), "A wrong answer cannot start the near-miss")
		_expect(question.visible, "Wrong-answer feedback keeps the question available")
		await _capture("02-wrong-answer-feedback")
		_choice(choices, correct).pressed.emit()
		_expect(state.call("has_story_flag", "door_chemistry_unlocked"), "A correct answer unlocks Chemistry")
		_expect(state.call("has_story_flag", "door_chemistry_question_answered"), "The answer, not proximity, is persisted")
		_expect(not bool(hall.get("guardian_near_miss_active")), "Correct feedback precedes the explicit enter action")
		await _capture("03-correct-answer")
		var enter := question.find_child("EnterChemistryButton", true, false) as Button
		_expect(enter != null and enter.visible, "The solved lock offers entry")
		var health_before: int = state.player_health
		if enter != null:
			enter.pressed.emit()
			await process_frame
			var cg := hall.get_node_or_null("ChemistryNearMissCG") as CanvasLayer
			_expect(cg != null and cg.visible, "Entry shows a dedicated illustrated near-miss CG")
			if cg != null:
				_expect(cg.find_child("DetectiveCG", true, false) != null, "The CG contains a visible detective actor")
				_expect(cg.find_child("GuardianCG", true, false) != null, "The CG contains the approaching Guardian")
				var background := cg.find_child("BackgroundVisualCG", true, false) as Sprite2D
				_expect(background != null and background.z_index >= 0, "The CG background is not hidden beneath its matte")
				if capture:
					await create_timer(0.22).timeout
				await _capture("04-cg-approach")
				if capture:
					await create_timer(1.4).timeout
					await _capture("05-cg-near-miss")
					await create_timer(0.7).timeout
					await _capture("06-door-closes")
				else:
					paused = true
					cg.call("finish")
				await process_frame
				_expect(state.player_health == health_before, "The near-miss does not damage the detective")
				_expect(not is_instance_valid(hall) or not bool(hall.get("game_over")), "The near-miss is an escape, not a failure")
				for _frame: int in range(30):
					await create_timer(0.1).timeout
					if current_scene != hall:
						break
				_expect(state.current_room_id == "chemistry_room", "Finishing the CG enters Chemistry")
				paused = false
	_finish(previous_language)


func _choice(parent: Control, index: int) -> Button:
	for node: Node in parent.get_children():
		if node is Button and int(node.get_meta("answer_index", -1)) == index:
			return node as Button
	_expect(false, "Answer option exists: %d" % index)
	return null


func _capture(label: String) -> void:
	if not capture:
		return
	var directory := ProjectSettings.globalize_path("res://docs/evidence/2026-09-07-chemistry-entry")
	_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Evidence directory is writable")
	var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Entry evidence is native-sized")
	var suffix := "-zh" if root.get_node("CaseLocale").call("is_chinese") else ""
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label)


func _finish(previous_language: String) -> void:
	root.get_node("CaseLocale").call("set_language", previous_language)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	state.game_started = false
	if failures.is_empty():
		print("chemistry_entry_sequence_test: PASS")
		quit(0)
	else:
		printerr("chemistry_entry_sequence_test: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		printerr("FAIL: " + description)
