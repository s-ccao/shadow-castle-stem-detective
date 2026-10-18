extends SceneTree

var failures: Array[String] = []
var room: Node
var game: Node
var state: Node
var launcher: GDScript
var sorting: GDScript


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	var test_root := ProjectSettings.globalize_path("res://.godot/chemistry-")
	if not isolated_home.begins_with(test_root) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("Refusing Chemistry QA without project-local isolated HOME")
		quit(2)
		return
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))
	state = root.get_node("GameState")
	launcher = load("res://scripts/minigame_launcher.gd") as GDScript
	sorting = load("res://scripts/change_sorting_minigame.gd") as GDScript
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.game_started = true
	state.current_room_id = "chemistry_room"
	var locale := root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if "--zh" in OS.get_cmdline_user_args() else "en")
	room = (load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	room.call("_open_change_sorting_minigame")
	await process_frame
	await process_frame
	game = launcher._active
	_expect(game != null and paused, "The actual Chemistry table launches the paused sample tray")
	if game == null:
		_finish(previous_language)
		return
	if "--preview" in OS.get_cmdline_user_args():
		if "--naturalness" in OS.get_cmdline_user_args():
			game.call("_select_sample", "melting_ice")
			game.get("_hero").call("reset_dish")
			game.call("_update_observation_status")
		DisplayServer.window_set_title("Shadow Castle - Material Observation Lab")
		print("CHEMISTRY_PREVIEW_READY: " + ProjectSettings.globalize_path("res://"))
		return
	_expect(int(game.call("level_count")) == 8, "The eight authored stages remain intact")
	await _capture("01-first-stage")
	if "--capture" in OS.get_cmdline_user_args() and game.has_method("_select_sample"):
		if "--naturalness" in OS.get_cmdline_user_args():
			await _naturalness_gallery()
		else:
			await _showcase(0, "burning_paper", "04-paper-chars-flame-smoke", 1.0)
			await _showcase(0, "melting_ice", "05-ice-pool-no-steam", 1.0)
			await _showcase(1, "baking_soda_vinegar", "06-gas-bubbles-and-foam", 1.0)
			await _showcase(1, "breaking_glass", "07-glass-fragments", 0.65)
			await _showcase(6, "salt_crystallising", "08-time-lapse-crystals", 1.55)
		game.set("_level_index", 0)
		game.call("_enter_level")
		await process_frame
		await process_frame
	var hero := game.find_child("ExperimentHero", true, false) as Control
	_expect(hero != null and hero.size.x >= 500 and hero.size.y >= 180, "A large experiment view replaces tiny color-block dishes")
	var replay := game.find_child("ObservationReplay", true, false) as Button
	_expect(replay != null and replay.visible, "The player can replay the phenomenon before judging")
	var tabs := game.find_child("SampleSelectors", true, false) as Container
	_expect(tabs != null and tabs.get_child_count() == 2, "Every sample is directly selectable")
	if hero == null or replay == null:
		game.set("_level_index", 7)
		game.call("_enter_level")
		await process_frame
		await _capture("02-final-stage")
		game.call("_on_close_pressed")
		await process_frame
		_finish(previous_language)
		return
	replay.pressed.emit()
	_expect(bool(hero.call("is_playing")), "Replay starts actual specimen animation")
	_expect(hero.get("sample_id") == "burning_paper", "The experiment view is wired to the selected real sample")
	var expected: String = game.call("_expected", "burning_paper")
	game.call("_on_pick", "burning_paper", expected)
	_expect(bool(hero.call("is_playing")), "Choosing a category does not erase the ongoing observation")
	_expect(int(game.call("levels_cleared")) == 0, "Watching or choosing does not award a stage")
	for _repeat: int in range(6):
		replay.pressed.emit()
	hero.call("_process", float(hero.call("sound_onset_seconds")) + 0.01)
	game.call("_update_observation_audio")
	var sample_voices := 0
	for voice: AudioStreamPlayer in root.get_node("GameAudio").get("_voices"):
		if voice.playing and str(voice.get_meta("event_id", "")).begins_with("sample_"):
			sample_voices += 1
	_expect(sample_voices == 1, "Repeated replay never stacks observation sounds")
	game.call("_on_pick", "melting_ice", "chemical")
	game.call("_on_submit")
	game.set("_run_time", float(game.call("presentation_duration")) + 0.1)
	game.call("_process", 0.0)
	_expect(int(game.call("levels_cleared")) == 0, "A wrong classification does not advance the stage")
	_expect((game.get("_submit") as Button).text == ("封盘" if locale.call("is_chinese") else "Seal the tray"), "Failed verification restores a usable retry label")
	_expect(game.get("_choice")["burning_paper"] == "chemical" and game.get("_choice")["melting_ice"] == "", "Correct choices survive a failed seal")
	await _audio_timing_audit()
	for stage: int in range(8):
		game.set("_level_index", stage)
		game.call("_enter_level")
		await process_frame
		var cards: Dictionary = game.get("_cards")
		_expect(cards.size() == (sorting.LEVELS[stage] as Array).size(), "All samples remain in stage %d" % (stage + 1))
		for sample_id: String in cards:
			(cards[sample_id]["label"] as Button).pressed.emit()
			await process_frame
			var conditions := game.find_child("ObservationConditions", true, false) as Label
			var expected_conditions: String = sorting.SAMPLE_CONDITIONS[sample_id][1 if locale.call("is_chinese") else 0]
			_expect(conditions != null and conditions.text == expected_conditions, "Physical conditions accompany " + sample_id)
			if conditions != null:
				var note_height := conditions.get_theme_font("font").get_height(conditions.get_theme_font_size("font_size")) * conditions.get_line_count()
				_expect(note_height <= conditions.size.y + 1.0, "Condition text fits for " + sample_id)
			var compressed := bool(game.get("_hero").call("is_time_lapse"))
			var status: String = game.get("_observation_status").text
			_expect(status.begins_with("加速演示" if locale.call("is_chinese") else "TIME-LAPSE") == compressed, "Compressed time is disclosed for " + sample_id)
			if sample_id in ["melting_ice", "dissolving_sugar", "milk_souring", "salt_crystallising"]:
				_expect(root.get_node("GameAudio").get("_sample_voice") == null and str(game.get("_pending_observation_sound")).is_empty(), "No invented material noise for " + sample_id)
			var answer: String = game.call("_expected", sample_id)
			(cards[sample_id][answer] as Button).pressed.emit()
		_expect(not (game.get("_submit") as Button).disabled, "Complete choices enable sealing in stage %d" % (stage + 1))
		if stage == 7:
			await _capture("02-final-stage")
	_expect(int(game.call("levels_cleared")) == 0, "Unsealed choices still do not grant rewards")
	game.call("_on_submit")
	await _capture("03-sealing")
	game.call("_on_close_pressed")
	await process_frame
	_expect(not launcher.is_busy() and not paused, "Closing during effects releases the real room and modal owner")
	_expect(not state.call("has_story_flag", "chemistry_change_sorted"), "Closing an unfinished effect does not grant completion")
	_expect(root.get_node("GameAudio").get("_sample_voice") == null, "Closing the experiment stops its owned sound")
	var retired: Node = sorting.new()
	root.add_child(retired)
	retired.call("configure", "Lifecycle", "Close during observation", Color.WHITE)
	retired.call("start")
	retired.set("_level_index", 1)
	retired.call("_enter_level")
	_expect(retired.get("_pending_observation_sound") == &"sample_glass", "A glass impact is pending before closing")
	retired.call("_on_close_pressed")
	await process_frame
	await process_frame
	retired.call("_process", 0.1)
	_expect(retired.get("_submit") == null, "A closed but retained minigame has no stale submit-control reference")
	_expect(str(retired.get("_pending_observation_sound")).is_empty(), "Retained closed games cannot emit a delayed impact")
	retired.queue_free()
	_finish(previous_language)


func _audio_timing_audit() -> void:
	game.set("_level_index", 1)
	game.call("_enter_level")
	await process_frame
	game.call("_replay_observation")
	var hero: Node = game.get("_hero")
	hero.set_process(false)
	var onset := float(hero.call("sound_onset_seconds"))
	_expect(onset > 0.0 and onset < float(game.call("presentation_duration")), "Fracture sound follows a real impact time")
	var audio := root.get_node("GameAudio")
	_expect(audio.get("_sample_voice") == null, "The falling glass is silent before contact")
	hero.call("_process", onset * 0.9)
	game.call("_update_observation_audio")
	_expect(audio.get("_sample_voice") == null, "Sound cannot lead the visible collision")
	hero.call("_process", onset * 0.1 + 0.001)
	game.call("_update_observation_audio")
	var voice := audio.get("_sample_voice") as AudioStreamPlayer
	_expect(voice != null and voice.playing and voice.get_meta("event_id") == &"sample_glass", "Contact triggers its fracture sound")
	game.call("_update_observation_audio")
	_expect(audio.get("_sample_voice") == voice and str(game.get("_pending_observation_sound")).is_empty(), "An impact triggers once per observation")
	game.call("_replay_observation")
	_expect(audio.get("_sample_voice") == null, "Replay stops the old impact before a new fall")
	game.call("_select_sample", "dissolving_sugar")
	hero.call("_process", onset + 0.01)
	game.call("_update_observation_audio")
	_expect(audio.get("_sample_voice") == null and str(game.get("_pending_observation_sound")).is_empty(), "Switching to a quiet process cancels the pending impact")


func _naturalness_gallery() -> void:
	await _showcase(0, "melting_ice", "04-ice-early", 0.35)
	await _showcase(0, "melting_ice", "05-ice-mid", 1.3)
	await _showcase(0, "melting_ice", "06-ice-water", 2.6)
	await _showcase(1, "breaking_glass", "07-glass-falling", 0.10)
	var impact := float(game.get("_hero").call("sound_onset_seconds"))
	await _showcase(1, "breaking_glass", "08-glass-impact", impact + 0.06)
	await _showcase(1, "breaking_glass", "09-glass-settled", 2.6)
	await _showcase(3, "melting_wax", "10-wax-slump", 1.4)
	await _showcase(3, "tearing_cloth", "11-cloth-tear", 1.1)
	await _showcase(4, "magnet_attracting", "12-magnet-contact", 1.7)
	await _showcase(6, "salt_crystallising", "13-crystal-nucleation", 1.8)
	await _showcase(4, "milk_souring", "14-milk-curds", 2.1)
	await _showcase(1, "baking_soda_vinegar", "15-gas-bubbles", 1.1)
	await _showcase(2, "boiling_water", "16-boiling", 1.1)
	await _showcase(0, "burning_paper", "17-burning", 1.1)


func _showcase(stage: int, sample_id: String, label: String, seconds: float) -> void:
	game.set("_level_index", stage)
	game.call("_enter_level")
	await process_frame
	await process_frame
	var tab := game.find_child("SampleSelect_" + sample_id, true, false) as Button
	_expect(tab != null, "The specimen has a real selector: " + sample_id)
	if tab == null:
		return
	tab.pressed.emit()
	await create_timer(seconds, true, false, true).timeout
	var hero := game.find_child("ExperimentHero", true, false) as Control
	_expect(hero != null and hero.get("sample_id") == sample_id, "The selected experiment drives its material view")
	_expect(not bool(hero.call("effect_snapshot")["observation_marks"]), "Observation does not reveal a classification badge")
	await _capture(label, 0.0)


func _capture(label: String, settling_seconds: float = 0.25) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var before := "--before" in OS.get_cmdline_user_args()
	var family := "2026-09-07-material-naturalness" if "--naturalness" in OS.get_cmdline_user_args() else "2026-09-07-chemistry-effects"
	var directory := ProjectSettings.globalize_path("res://docs/evidence/" + family + "/" + ("before" if before else "after"))
	DirAccess.make_dir_recursive_absolute(directory)
	var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	if settling_seconds > 0.0:
		await create_timer(settling_seconds, true, false, true).timeout
	# Occluded macOS windows can suppress frame_post_draw even during an observation.
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Capture uses native resolution")
	var suffix := "-zh" if root.get_node("CaseLocale").call("is_chinese") else ""
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label)


func _finish(previous_language: String) -> void:
	root.get_node("CaseLocale").call("set_language", previous_language)
	paused = false
	current_scene = null
	if is_instance_valid(room):
		room.queue_free()
	state.game_started = false
	if failures.is_empty():
		print("chemistry_presentation_test: PASS")
		quit(0)
	else:
		printerr("chemistry_presentation_test: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
