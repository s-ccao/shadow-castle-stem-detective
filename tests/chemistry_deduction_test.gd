extends SceneTree

const ROOM := "res://scenes/floor_1/chemistry_room.tscn"

var failures: Array[String] = []
var game: Node
var room: Node
var model: RefCounted
var case_ui: CanvasLayer
var capture := false
var capture_directory := ""
var route_digest := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	var isolated_root := ProjectSettings.globalize_path("res://.godot/")
	if not OS.get_user_data_dir().begins_with(isolated_root):
		printerr("FAIL: run with HOME=$PWD/.godot/chemistry-deduction/home")
		quit(1)
		return
	capture = OS.get_cmdline_user_args().has("--capture")
	if capture:
		capture_directory = OS.get_environment("CHEMISTRY_DEDUCTION_ARTIFACT_DIR")
		if not capture_directory.is_absolute_path() or not DirAccess.dir_exists_absolute(capture_directory):
			printerr("FAIL: set CHEMISTRY_DEDUCTION_ARTIFACT_DIR to an existing absolute session-artifact directory")
			quit(1)
			return
	route_digest = FileAccess.get_sha256("res://data/hall_tutorial_route.json")
	game = root.get_node("GameState")
	game.set("_loading_save", true)
	game.call("reset_new_game")
	game.set("game_started", true)
	game.set("hall_arrival_seen", true)
	game.call("grant_wake_room_toolkit")
	game.call("add_key", "wake_room_key")
	root.get_node("CaseLocale").call("set_language", "en")
	game.call("save_room_checkpoint", ROOM, "chemistry_room")
	await _load_room()
	await _observations_and_hypotheses()
	await _notebook_and_experiment()
	await _interview()
	await _rewards_and_persistence()
	await _legacy()
	await _room_return()
	await _hall_chemistry_progression()
	_expect(FileAccess.get_sha256("res://data/hall_tutorial_route.json") == route_digest, "Authored Hall tutorial route is unchanged")
	_finish()


func _load_room() -> void:
	paused = false
	_expect(change_scene_to_file(ROOM) == OK, "Chemistry scene loads")
	await create_timer(0.4).timeout
	room = current_scene
	model = room.get("chemistry_case")
	case_ui = room.get("chemistry_case_ui")


func _observations_and_hypotheses() -> void:
	_expect(not model.call("confirm"), "Cannot confirm without observation or analysis")
	room.call("on_butler_test_correct")
	_expect(not game.call("has_story_flag", "butler_challenge_complete"), "Legacy callback cannot bypass evidence gate")
	await _interact("butler")
	await _message("Compare his statement")
	_expect(game.call("has_any_key"), "Key Hub shortcut is available before testing modal ownership")
	for keycode: Key in [KEY_I, KEY_K, KEY_U]:
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = keycode
			event.physical_keycode = keycode
			event.pressed = down
			root.push_input(event)
			await process_frame
	_expect(not (root.get_node("KeyHud").get("overlay") as Control).visible
		and not (root.get_node("MapHud").get("overlay") as Control).visible
		and not bool(root.get_node("NoteHud").call("get_journal").visible),
		"Case panel blocks hidden Hub opening instead of creating nested pause owners")
	_expect(_case_button("follow_up").disabled, "Follow-up is locked before evidence")
	_expect(_case_button("present").disabled and str(case_ui.get("statement_id")).is_empty()
		and str(case_ui.get("evidence_id")).is_empty(), "The interview does not preselect the correct evidence link")
	_expect(not model.call("has", "linked"), "Uncollected report cannot link")
	await _click_case("close")
	_expect(not paused and not room.get("dialogue_active"), "Case close restores room input")

	await _interact("red_stain")
	await _message("Inspect the nearby traces")
	_expect(not game.call("has_evidence", "fake_red_stain"), "Inspection does not grant solved evidence")
	_expect(not str(room.get("message_label").text).contains("Someone staged"), "Observation does not announce staging")
	await _shot("01-observations.png")
	await _message("Record observations")
	_expect(model.call("has", "observed"), "Record button files observations")
	_expect(not game.call("has_evidence", "fake_red_stain"), "Recording observations still does not solve stain")
	_expect(_journal_body().contains("FACTS / OBSERVATIONS") and _journal_body().contains("CONFIRMED CONCLUSIONS"), "Notebook separates record types")
	_expect(not model.call("run_comparison", "control"), "Comparison is knowledge-gated")
	var notes := root.get_node("NoteHud")
	var original_record_count := (notes.call("get_saved_clues") as Dictionary).size()
	var observed_facts: String = model.call("facts", "en")
	await _click_case("hypothesis_reaction")
	_expect(not model.call("confirm") and not game.call("has_evidence", "fake_red_stain"), "Even a correct initial guess cannot become solved evidence")
	await _click_case("hypothesis_blood")
	_expect(model.call("hypothesis") == "blood", "Blood is a playable working hypothesis")
	_expect(_journal_body().contains("Blood explains the red"), "First proposal updates the actual journal body")
	await _click_case("hypothesis_dye")
	_expect(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "hypothesis_dye",
		"Revising a hypothesis retains the player's keyboard position")
	_expect(model.call("has", "revised") and model.call("hypothesis") == "dye", "Hypothesis is freely revisable")
	_expect(_journal_body().contains("Spilled dye; no reaction (revised)") and not _journal_body().contains("Blood explains the red"), "Revision replaces the old proposal in the same journal body")
	_expect((notes.call("get_saved_clues") as Dictionary).size() == original_record_count, "Revising never creates duplicate journal entries")
	_expect(str(model.call("facts", "en")) == observed_facts, "Changing a hypothesis does not rewrite observed facts")
	_expect(int(game.get("reputation")) == 0, "Wrong hypotheses cost no reputation")
	await _shot("02-revisable-hypothesis.png")
	await _round_trip("observed hypothesis")
	_expect(model.call("hypothesis") == "dye", "Revised hypothesis survives save/load")
	_expect(_journal_body().contains("Spilled dye; no reaction (revised)"), "Saved wrong hypothesis remains in the existing journal entry")
	await _click_case("close")
	await _load_room()
	await _interact("red_stain")
	_expect(model.call("hypothesis") == "dye" and not _case_button("hypothesis_blood").disabled, "Wrong-hypothesis save can be revisited and revised")
	_expect(not game.call("has_evidence", "fake_red_stain"), "Revisiting a wrong-hypothesis save does not grant solved evidence")
	await _click_case("close")


func _notebook_and_experiment() -> void:
	await _interact("alchemy_table")
	_expect(game.call("has_story_flag", "mrs_lin_lab_note_seen"), "Table exposes Lin's protocol")
	var parchment := root.get_node("ParchmentHud")
	await create_timer(0.5).timeout
	parchment.call("_on_confirm_pressed")
	await process_frame
	# The pre-existing Vision sample and one Swiftness reward still run.
	await _message("Continue")
	_expect(game.call("has_story_flag", "vision_demo_seen"), "Vision demo route remains intact")
	_expect(game.call("has_story_flag", "chemistry_first_reward_given"), "Existing first potion reward survives")
	_expect(not model.call("run_comparison", "control"), "Reading protocol alone does not bypass sample tray")
	await _interact("alchemy_table")
	var tray: Node
	for child: Node in room.get_children():
		if child.has_method("levels_cleared"):
			tray = child
	_expect(tray != null, "Real sample tray launches from table")
	if tray == null:
		return
	# Walk every authored stage through the real answer buttons and seal action.
	var total: int = tray.call("level_count")
	for stage: int in total:
		var cards: Dictionary = tray.get("_cards")
		if stage == 0:
			for sample: String in cards:
				var wrong := "physical" if str(tray.call("_expected", sample)) == "chemical" else "chemical"
				(cards[sample][wrong] as Button).pressed.emit()
			(tray.get("_submit") as Button).pressed.emit()
			await _wait_for_tray(tray)
			_expect(int(tray.call("levels_cleared")) == 0, "Wrong sample classification remains retryable")
		for sample: String in cards:
			var correct: String = tray.call("_expected", sample)
			(cards[sample][correct] as Button).pressed.emit()
		(tray.get("_submit") as Button).pressed.emit()
		await _wait_for_tray(tray)
		_expect(int(tray.call("levels_cleared")) == stage + 1, "Sample tray stage %d clears" % (stage + 1))
		(tray.get("_continue_button") as Button).pressed.emit()
		await process_frame
	_expect(game.call("has_story_flag", "chemistry_change_sorted"), "Full tray unlocks comparison")
	_expect(case_ui.visible and case_ui.get("mode") == "analysis", "Tray returns directly to the case comparison")
	_expect(_case_button("compare_reaction").disabled, "Separate control must precede combination")
	await _click_case("compare_control")
	_expect(model.call("has", "control"), "Separate control recorded through UI")
	_expect(not model.call("confirm"), "A control alone cannot solve the stain")
	await _click_case("close")
	_expect(not paused and not room.get("dialogue_active"), "Partial comparison can be left safely")
	await _interact("alchemy_table")
	await _message("Compare traces")
	_expect(model.call("has", "control"), "Reopening preserves the recorded control")
	await _round_trip("partial control")
	await _click_case("compare_reaction")
	_expect(model.call("results_ready"), "Both comparison records are available")
	_expect(not _case_button("confirm").disabled, "Players can test their interpretation without an answer-revealing disabled button")
	_expect(not str(model.call("hypothesis_review", "en")).contains("Reaction — SUPPORTED"),
		"The dossier does not pre-grade hypotheses before the player's interpretation")
	await _click_case("confirm")
	_expect(not model.call("has", "confirmed") and str(case_ui.get("feedback")).contains("not supported"),
		"Unsupported interpretation receives feedback instead of becoming a fact")
	_expect(not game.call("has_evidence", "fake_red_stain"), "Test results require player interpretation")
	await _click_case("section_hypotheses")
	await _shot("03-comparison-results.png")
	await _click_case("hypothesis_reaction")
	await _click_case("confirm")
	_expect(game.call("has_evidence", "fake_red_stain"), "Supported explanation grants original finale evidence ID")
	var conclusion: String = model.call("conclusion", "en")
	_expect(not conclusion.contains("Butler") and not conclusion.contains("Mechanic"), "Chemical result names no culprit")
	_expect(conclusion.contains("not a biological blood test"), "Result retains scientific limits")
	_expect(not game.call("has_story_flag", "chemistry_butler_interviewed"), "Analysis does not auto-complete interview")
	_check_finale_interview(false)
	await _shot("04-supported-conclusion.png")
	await _click_case("close")


func _interview() -> void:
	await _interact("butler")
	await _click_case("statement_supplies")
	await _click_case("evidence_glass")
	await _click_case("present")
	_expect(not model.call("has", "linked"), "Broken glass does not establish cleaner access")
	await _click_case("statement_glass")
	await _click_case("present")
	_expect(str(case_ui.get("feedback")).contains("consistent"), "Glass can corroborate without unlocking supply question")
	_expect(_case_button("follow_up").disabled, "Corroboration is not the requested evidence link")
	await _click_case("evidence_comparison")
	await _click_case("present")
	_expect(not model.call("has", "linked"), "Chemical report cannot establish sound or timing")
	await _click_case("statement_supplies")
	await _click_case("present")
	_expect(model.call("has", "linked"), "Matching report and supply statement unlock follow-up")
	await _shot("05-evidence-linked-follow-up.png")
	await _round_trip("linked testimony")
	await _click_case("follow_up")
	_expect(int(game.get("reputation")) == 10, "Follow-up grants original reward once")
	_expect(game.call("has_story_flag", "chemistry_butler_interviewed"), "Follow-up records interview without needing a second visit")
	_expect(str(case_ui.call("_filed_guidance")).contains("Continue exploring"),
		"Completed case guidance does not send the player into another mandatory interview")
	_check_finale_interview(true)
	_expect(bool((game.get("completed_rooms") as Dictionary).get("chemistry_room", false)), "Complete detective loop completes Chemistry")
	await _message("Record and continue")
	await _interact("butler")
	await _click_case("follow_up")
	_expect(int(game.get("reputation")) == 10, "Repeated follow-up cannot farm reputation")
	await _message("Record and continue")


func _rewards_and_persistence() -> void:
	await _interact("cabinet")
	await _message("Continue")
	_expect(game.call("has_key", "greenhouse_room_key"), "Hidden Greenhouse key route survives")
	await _interact("alchemy_table")
	await _message("Craft Potions")
	_expect((room.get("alchemy_workbench_ui") as CanvasLayer).visible, "Crafting remains accessible")
	room.call("close_craft_panel")
	await process_frame
	await _interact("alchemy_table")
	await _message("Compare traces")
	await _click_case("hypothesis_blood")
	_expect(model.call("has", "confirmed") and game.call("has_evidence", "fake_red_stain"), "Revising working hypothesis never erases established evidence")
	await _click_case("hypothesis_reaction")
	await _round_trip("completed case")
	_expect(game.call("has_key", "greenhouse_room_key"), "Key persists alongside case flags")
	root.get_node("CaseLocale").call("set_language", "zh")
	case_ui.call("render")
	await process_frame
	await _click_case("section_conclusions")
	await _shot("06-chinese-case.png")
	_expect(str(case_ui.get("dossier").text).contains("已确认结论"), "Case renders Chinese structured sections")
	_expect(str(case_ui.get("feedback")).is_empty(), "Language change does not leave stale English feedback")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	_expect(not case_ui.visible and not paused, "Escape closes modal and restores pause")
	room.call("_on_change_sorting_finished", false, 0)
	_expect(str(room.get("_current_speaker")) == "You" and str(room.get("message_label").text).begins_with("你:"), "Reasoning is the player's localized self-talk, not live Lin dialogue")
	await _shot("08-chinese-self-talk.png")
	await _message("继续")
	var notes := root.get_node("NoteHud")
	var journal: Node = notes.call("get_journal")
	journal.call("open")
	journal.call("_select_clue", "chemistry_room_note")
	await create_timer(0.3).timeout
	var entry: Dictionary = (notes.call("get_saved_clues") as Dictionary)["chemistry_room_note"]
	_expect(str(entry.get("room_id", "")) == "chemistry_room", "Case record associates with Chemistry on the Map")
	_expect(str(entry.get("observed_detail", "")) == "Red liquid, white powder, broken glass, and a vial.", "Journal observation accent contains only observed facts")
	_expect(str(journal.get("document_title").text) == "红渍调查", "Journal title follows current language")
	var rendered_body := str(journal.get("detail_text").text)
	_expect(rendered_body.contains("事实／观察") and rendered_body.contains("已确认结论") and not rendered_body.contains("FACTS / OBSERVATIONS"), "Journal displays the localized structured body")
	await _shot("07-notebook-record.png")
	journal.call("close")
	root.get_node("CaseLocale").call("set_language", "en")
	await _load_room()
	_expect(model.call("has", "confirmed") and model.call("has", "linked"), "Room reload retains completed case")


func _legacy() -> void:
	var legacy_flags: Dictionary = (game.get("story_flags") as Dictionary).duplicate(true)
	for id: String in legacy_flags.keys():
		if id.begins_with("chemistry_case_"):
			legacy_flags.erase(id)
	game.set("story_flags", legacy_flags)
	game.call("set_story_flag", "chemistry_butler_interviewed", false)
	game.call("set_story_flag", "mrs_lin_lab_note_seen", false)
	game.call("set_story_flag", "chemistry_change_sorted", false)
	await _load_room()
	_expect(model.call("has", "legacy") and model.call("has", "confirmed"), "Old solved-stain save restores confirmed evidence without redoing minigame")
	_check_finale_interview(true)
	await _interact("butler")
	await _message("Compare his statement")
	await _click_case("statement_supplies")
	await _click_case("evidence_comparison")
	await _click_case("present")
	await _click_case("follow_up")
	_expect(int(game.get("reputation")) == 10, "Old rewarded Butler save never grants reward twice")
	await _message("Record and continue")
	await _round_trip("legacy migration")
	await _load_room()
	await _interact("red_stain")
	await _click_case("hypothesis_dye")
	_expect(model.call("has", "confirmed") and game.call("has_evidence", "fake_red_stain"), "Completed legacy save stays solved when its working hypothesis is revised")
	_expect(_journal_body().contains("Spilled dye; no reaction (revised)"), "Legacy journal entry accepts later revisions")
	await _click_case("hypothesis_reaction")
	await _click_case("close")
	await _interact("butler")
	await _click_case("follow_up")
	_expect(int(game.get("reputation")) == 10, "Completed legacy save remains playable without repeating rewards")
	await _message("Record and continue")


func _check_finale_interview(expected: bool) -> void:
	var script := load("res://scripts/final_case_board.gd") as GDScript
	var board: Node = script.new()
	var source: Dictionary = board.call("_source_by_id", "butler_service_account")
	_expect(bool(board.call("_source_available", source)) == expected,
		"Final deduction requires the new interview while retaining legacy record compatibility")
	var report: Dictionary = board.call("_source_by_id", "fake_red_stain")
	_expect(str(report["en"]) == "Red stain comparison", "Finale labels the raw report without pre-judging deliberate staging")
	board.free()


func _room_return() -> void:
	await _interact("exit")
	await create_timer(9.0).timeout
	_expect(current_scene != room, "Chemistry exit still changes scene through Hall transition")
	_expect(not paused, "Hall transition restores tree pause")
	_expect(game.call("has_story_flag", "chemistry_case_confirmed"), "Case flags survive Hall return")
	var player: Node = current_scene.get_node_or_null("player")
	_expect(player != null and player.is_physics_processing(), "Hall player movement resumes")


func _hall_chemistry_progression() -> void:
	var hall := current_scene
	var entered := {"value": false}
	var enter_probe := func() -> void: entered["value"] = true
	hall.call("_try_enter_locked_room", "chemistry", "chemistry_room_key", enter_probe)
	_expect(not entered["value"] and not game.call("has_story_flag", "door_chemistry_unlocked"), "Normal Chemistry door still requires its physical key")
	hall.call("close_message_panel")
	game.call("add_key", "chemistry_room_key")
	hall.call("_try_enter_locked_room", "chemistry", "chemistry_room_key", enter_probe)
	_expect(not entered["value"] and str(hall.get("_door_question_target")).is_empty(), "Key alone does not bypass the Chemistry knowledge exhibit")
	hall.call("close_message_panel")
	game.set("hall_arrival_seen", false)
	hall.call("_begin_hall_arrival_route")
	hall.set("current_interaction", "arrival_chemistry_door")
	hall.call("_try_hall_arrival_interaction")
	hall.call("_advance_to_hall_chemistry_core")
	hall.set("current_interaction", "arrival_chemistry_core")
	hall.call("_try_hall_arrival_interaction")
	var dossier := hall.get("knowledge_dossier") as CanvasLayer
	_expect(dossier != null and dossier.visible, "Tutorial presents knowledge before filing")
	if dossier == null:
		return
	(dossier.find_child("FileKnowledgeButton", true, false) as Button).pressed.emit()
	_expect(game.call("has_story_flag", "hall_knowledge_chemistry_room_collected"), "Tutorial brass core still grants Chemistry knowledge")
	_expect(root.get_node("NoteHud").call("has_clue", "hall_knowledge_chemical_change"), "Tutorial knowledge is filed under its original journal ID")
	hall.set("current_interaction", "arrival_chemistry_door")
	hall.call("_try_hall_arrival_interaction")
	var question := hall.get("chemistry_door_question") as CanvasLayer
	_expect(question != null and question.visible, "Tutorial Chemistry entry requires its question")
	if question == null:
		return
	var correct_index: int = hall.get("DOOR_QUESTIONS")["chemistry"]["correct"]
	for answer: Button in (question.find_child("DoorAnswers", true, false) as Control).get_children():
		if int(answer.get_meta("answer_index", -1)) == correct_index:
			answer.pressed.emit()
			break
	(question.find_child("EnterChemistryButton", true, false) as Button).pressed.emit()
	await create_timer(6.0).timeout
	_expect(current_scene != hall and str(current_scene.scene_file_path) == ROOM, "Tutorial Chemistry door enters the actual upgraded room")
	_expect(game.call("has_story_flag", "door_chemistry_unlocked") and bool(game.get("hall_arrival_seen")), "Tutorial completion and door unlock persist")
	_expect(str(game.get("checkpoint_scene_path")) == ROOM, "Hall entry preserves the Chemistry checkpoint route")
	_expect(not paused and (current_scene.get("player") as Node).is_physics_processing(), "Upgraded Chemistry accepts normal tutorial entry with usable input")


func _round_trip(label: String) -> void:
	game.set("_loading_save", false)
	_expect(game.call("save_to_disk"), label + " writes real save")
	var expected_flags: Dictionary = (game.get("story_flags") as Dictionary).duplicate(true)
	var expected_notes: Dictionary = root.get_node("NoteHud").call("get_saved_clues")
	game.set("story_flags", {})
	_expect(game.call("load_saved_game"), label + " loads real save")
	_expect(game.get("story_flags") == expected_flags, label + " flags round-trip")
	_expect(root.get_node("NoteHud").call("get_saved_clues") == expected_notes, label + " notebook round-trips")
	game.set("_loading_save", true)


func _interact(id: String) -> void:
	var player := room.get("player") as CharacterBody2D
	var rect: Rect2 = room.call("get_interaction_rect", id)
	var points: Array[Vector2] = [
		Vector2(rect.get_center().x, rect.end.y + 10),
		Vector2(rect.position.x - 10, rect.get_center().y),
		Vector2(rect.end.x + 10, rect.get_center().y),
		rect.get_center(),
	]
	for point: Vector2 in points:
		player.position = point
		room.call("update_interaction_prompt")
		if str(room.get("current_interaction")) == id:
			break
	_expect(str(room.get("current_interaction")) == id, "World proximity selects " + id)
	room.call("handle_interaction")
	await process_frame


func _message(caption: String) -> void:
	for attempt: int in 30:
		await process_frame
		var box := room.get("message_button_box") as HBoxContainer
		var advanced := false
		for child: Node in box.get_children():
			if child.is_queued_for_deletion() or not child is Button:
				continue
			if str(child.name) == "SegmentContinueButton":
				(child as Button).pressed.emit()
				advanced = true
				break
			if (child as Button).text == caption:
				(child as Button).pressed.emit()
				await process_frame
				return
		if not advanced:
			break
	_expect(false, "Dialogue action available: " + caption)


func _case_button(id: String) -> Button:
	return case_ui.find_child(id, true, false) as Button


func _click_case(id: String) -> void:
	var button := _case_button(id)
	_expect(button != null and not button.disabled, "Case action available: " + id)
	if button != null and not button.disabled:
		button.grab_focus()
		await process_frame
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event)
			await process_frame
	await process_frame
	await process_frame


func _wait_for_tray(tray: Node) -> void:
	var remaining := 100
	while bool(tray.get("_running")) and remaining > 0:
		await create_timer(0.05).timeout
		remaining -= 1
	_expect(remaining > 0, "Sample animation finishes")


func _journal_body() -> String:
	var entries: Dictionary = root.get_node("NoteHud").call("get_saved_clues")
	return str((entries.get("chemistry_room_note", {}) as Dictionary).get("content", ""))


func _shot(filename: String) -> void:
	if case_ui.visible:
		_check_layout()
	if not capture:
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Native screenshot: " + filename)
	_expect(image.save_png(capture_directory.path_join(filename)) == OK, "Screenshot saved: " + filename)


func _check_layout() -> void:
	var board := case_ui.get("board") as Panel
	var feedback := case_ui.get("feedback_label") as Label
	_expect(Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(board.get_global_rect()), "Case board fits native viewport")
	_expect(board.get_global_rect().encloses(feedback.get_global_rect()), "Feedback stays inside the case board")
	var scroll := board.get_node("ActionScroll") as ScrollContainer
	_expect(scroll.get_global_rect().end.y < feedback.get_global_rect().position.y, "Actions and feedback do not overlap")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures.append(label)
		printerr("FAIL: " + label)


func _finish() -> void:
	if is_instance_valid(case_ui):
		case_ui.call("close")
	paused = false
	game.set("game_started", false)
	if current_scene != null:
		current_scene.queue_free()
	model = null
	# Allow the dummy audio server to release its three continuous music voices.
	root.get_node("GameAudio").queue_free()
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("chemistry_deduction_test: PASS")
		quit(0)
	else:
		printerr("chemistry_deduction_test: FAIL (%d)" % failures.size())
		quit(1)
