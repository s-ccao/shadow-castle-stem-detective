extends SceneTree

## The guided run is one unbroken chain: Wake Room teaches the controls and the
## six-step first lead, the Hall teaches escape, and Chemistry is the first room
## the player solves alone. Chemistry used to hand back no objective at all, so
## the tutorial ended the moment the door closed behind them.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true

	_test_wake_chain_covers_every_step(game_state)
	await _test_chemistry_guides_until_the_room_is_solved(game_state)

	game_state.reset_new_game()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	_finish()


## Every step must have real copy in both languages. A missing key renders as
## the raw id, which is worse than no card at all.
func _test_wake_chain_covers_every_step(game_state: Node) -> void:
	var case_locale := root.get_node("CaseLocale")
	var guided_keys: Array[String] = [
		"coach.move", "coach.interact",
		"guide.wake_first_door_title", "guide.wake_first_door_body",
		"guide.wake_search_title", "guide.wake_search_body",
		"guide.wake_answer_title", "guide.wake_answer_body",
		"guide.wake_exit_title", "guide.wake_exit_body",
		"guide.rule_title", "guide.rule_body", "guide.rule_continue",
		"hall.route_step_1_title", "hall.route_step_1_body",
		"hall.route_step_2_title", "hall.route_step_2_body",
		"hall.route_step_3_title", "hall.route_step_3_body",
		"guide.chem_stain_title", "guide.chem_stain_body",
		"guide.chem_butler_title", "guide.chem_butler_body",
		"guide.chem_exit_title", "guide.chem_exit_body",
	]
	for language: String in ["en", "zh"]:
		case_locale.call("set_language", language)
		var missing: Array[String] = []
		for key: String in guided_keys:
			var value := str(case_locale.call("text", key))
			if value.is_empty() or value == key:
				missing.append(key)
		_expect(
			missing.is_empty(),
			"Guided chain has %s copy for every step (missing: %s)" % [language, missing]
		)
	case_locale.call("set_language", "en")
	game_state.reset_new_game()
	game_state.game_started = true


func _test_chemistry_guides_until_the_room_is_solved(game_state: Node) -> void:
	var case_locale := root.get_node("CaseLocale")
	var preferences := root.get_node("PlayerPreferences")
	game_state.set("return_spawn_id", "chemistry_start")
	game_state.set("current_room_id", "chemistry_room")

	var packed := load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame

	var panel := room.get("case_objective_panel") as Panel
	var body := room.get("case_objective_body") as Label
	_expect(panel != null, "Chemistry Room shows a running objective card")
	if panel == null or body == null:
		room.queue_free()
		await process_frame
		return

	_expect(panel.visible, "Objective card is visible on arrival")
	_expect(
		body.text == str(case_locale.call("text", "guide.chem_stain_body")),
		"First Chemistry objective points at the red stain"
	)
	_expect(
		str(room.call("_case_objective_interaction")) == "red_stain",
		"World marker points at the red stain before it is recorded"
	)

	room.call("collect_red_stain_evidence")
	await process_frame
	_expect(
		body.text == str(case_locale.call("text", "guide.chem_butler_body")),
		"Recording the stain advances the objective to the Butler"
	)
	_expect(
		str(room.call("_case_objective_interaction")) == "butler",
		"World marker follows the objective to the Butler"
	)

	game_state.call("set_story_flag", "chemistry_butler_interviewed")
	room.call("_refresh_case_objective", false)
	_expect(
		body.text == str(case_locale.call("text", "guide.chem_exit_body")),
		"Clearing the Butler advances the objective to the exit"
	)
	_expect(
		str(room.call("_case_objective_interaction")) == "exit",
		"World marker finally points back at the Castle Hall exit"
	)
	room.call("update_room_completion")
	_expect(
		bool(game_state.call("is_room_completed", "chemistry_room")),
		"Room completion is recorded once both leads are done"
	)

	# Guidance is a setting everywhere else; this card must honour it too.
	preferences.call("set_field_prompts_enabled", false)
	room.call("_refresh_case_objective", false)
	_expect(
		not panel.visible,
		"Objective card hides when field guidance is switched off"
	)
	_expect(
		str(room.call("_case_objective_interaction")).is_empty(),
		"World objective marker also respects the guidance setting"
	)
	preferences.call("set_field_prompts_enabled", true)

	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("tutorial_chain_test: PASS")
		quit(0)
	else:
		printerr("tutorial_chain_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
