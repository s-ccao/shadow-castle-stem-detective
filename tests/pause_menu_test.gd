extends SceneTree

## In-game Esc settings: Esc ownership, pause, mute/volume/guidance, safe return
## to the main menu and quit. Run with a project-local isolated HOME, for example
## HOME="$PWD/.godot/pause-menu-check/home". Add `-- --capture [--zh]` natively
## to save the evidence gallery.

const HOME_MARKER := "res://.godot/pause-menu-"
const CHEMISTRY := "res://scenes/floor_1/chemistry_room.tscn"
const WAKE := "res://scenes/wake_room.tscn"
const HALL := "res://scenes/game_world.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const EVIDENCE := "res://docs/evidence/2026-10-18-pause-menu/"

var failures: Array[String] = []
var checks := 0
var menu: CanvasLayer
var state: Node
var audio: Node
var locale: Node
var quit_calls := 0


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("Refusing pause-menu QA without project-local isolated HOME")
		quit(2)
		return
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))
	menu = root.get_node("PauseMenu") as CanvasLayer
	state = root.get_node("GameState")
	audio = root.get_node("GameAudio")
	locale = root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if "--zh" in OS.get_cmdline_user_args() else "en")
	menu.set("quit_handler", func() -> void: quit_calls += 1)
	_prepare_case()
	if "--preview" in OS.get_cmdline_user_args():
		# Playable isolated preview: real quit, real saves inside the test HOME.
		menu.set("quit_handler", Callable(self, "quit"))
		state.set("_loading_save", false)
		await _load_room(CHEMISTRY)
		DisplayServer.window_set_title("Shadow Castle - Esc settings preview")
		print("PAUSE_MENU_PREVIEW_READY: " + ProjectSettings.globalize_path("res://"))
		return

	await _chemistry_audit()
	await _wake_room_audit()
	await _hall_audit()
	await _main_menu_settings_audit()
	await _return_and_quit_audit()

	locale.call("set_language", previous_language)
	paused = false
	if current_scene != null:
		var scene := current_scene
		current_scene = null
		scene.queue_free()
	await process_frame
	state.set("game_started", false)
	if failures.is_empty():
		print("pause_menu_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		printerr("pause_menu_test: FAIL (%d of %d checks)" % [failures.size(), checks])
		quit(1)


func _prepare_case() -> void:
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.set("game_started", true)
	state.call("grant_wake_room_toolkit")
	state.set("hall_arrival_seen", true)
	for flag: String in [
		"wake_orientation_completed", "hall_orientation_completed",
		"wake_room_arrival_complete", "hall_first_route_complete",
	]:
		state.call("set_story_flag", flag)
	state.call("save_room_checkpoint", CHEMISTRY, "chemistry_room")
	state.set("current_room_id", "chemistry_room")


# ------------------------------------------------------------------ audits


func _chemistry_audit() -> void:
	await _load_room(CHEMISTRY)
	var ready_for_play := await _settle()
	_expect(ready_for_play, "Chemistry free play can open settings")
	_expect(not _is_open() and not paused, "Gameplay starts without the menu")

	var bag := root.get_node("InventoryHud")
	bag.call("open_bag")
	await process_frame
	_expect(bool(bag.get("_open")) and paused, "Control: the Bag is open and owns the pause")
	await _press(KEY_ESCAPE)
	_expect(not bool(bag.get("_open")), "Esc first closes the open Bag")
	_expect(not _is_open(), "The Bag's closing Esc does not also open settings")

	var free_after_bag := await _settle()
	_expect(free_after_bag, "Play is free again after the Bag closes")
	await _press(KEY_ESCAPE)
	_expect(_is_open() and menu.visible and paused, "Esc opens settings and pauses play")
	_expect(root.gui_get_focus_owner() == _find("ResumeButton"), "Resume receives keyboard focus")
	await _capture("01-pause-menu")
	await _audit_fit("Settings")

	await _press(KEY_TAB)
	_expect(not bool(bag.get("_open")), "Tab cannot open the Bag beneath settings")
	_expect(root.gui_get_focus_owner() == _find("MainMenuButton"), "Tab moves through settings controls")
	await _press(KEY_U)
	_expect(not (root.get_node("MapHud").get("overlay") as Control).visible, "Map shortcut cannot open beneath settings")

	await _sound_and_guidance_audit()
	await _confirm_page_audit()

	var press := _key_event(KEY_ESCAPE, true)
	root.push_input(press)
	_expect(not _is_open() and not menu.visible, "Esc closes settings")
	_expect(paused, "Play resumes after the closing key's frame, not during it")
	root.push_input(_key_event(KEY_ESCAPE, false))
	for _frame: int in range(3):
		await process_frame
	_expect(not paused, "Closing settings restores normal play")


func _sound_and_guidance_audit() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	var music_before := float(audio.call("get_bus_volume_linear", &"Music"))
	var master_before := float(audio.call("get_bus_volume_linear", &"Master"))
	var mute := _find("MuteToggle") as Button
	mute.pressed.emit()
	_expect(bool(audio.call("is_muted")) and AudioServer.is_bus_mute(master), "Mute silences the Master bus")
	_expect(mute.text == str(locale.call("text", "menu.mute_on")), "Mute toggle states that sound is muted")
	_expect(
		is_equal_approx(float(audio.call("get_bus_volume_linear", &"Music")), music_before)
		and is_equal_approx(float(audio.call("get_bus_volume_linear", &"Master")), master_before),
		"Mute keeps every fader position"
	)
	var config := ConfigFile.new()
	config.load("user://shadow_castle_preferences.cfg")
	_expect(bool(config.get_value("audio", "muted", false)), "Mute persists for the next session")
	await _capture("02-muted")
	mute.pressed.emit()
	_expect(not bool(audio.call("is_muted")) and not AudioServer.is_bus_mute(master), "Unmute restores the existing mix")

	var music := _find("PauseVolume_Music") as HSlider
	music.value = 0.4
	_expect(absf(float(audio.call("get_bus_volume_linear", &"Music")) - 0.4) < 0.02, "Music fader moves the Music bus")
	_expect((_find("VolumeValue_Music") as Label).text == "40%", "Music fader shows its level")
	audio.call("set_bus_volume_linear", &"Music", music_before)
	var effects := _find("PauseVolume_SFX") as HSlider
	var effects_before := float(audio.call("get_bus_volume_linear", &"SFX"))
	effects.value = 0.65
	_expect(absf(float(audio.call("get_bus_volume_linear", &"SFX")) - 0.65) < 0.02, "Effects fader moves the SFX bus")
	audio.call("set_bus_volume_linear", &"SFX", effects_before)

	var preferences := root.get_node("PlayerPreferences")
	var prompts_before := bool(preferences.get("field_prompts_enabled"))
	var guidance := _find("GuidanceToggle") as Button
	guidance.pressed.emit()
	_expect(bool(preferences.get("field_prompts_enabled")) != prompts_before, "Guidance prompts can be toggled in play")
	_expect(
		guidance.text == str(locale.call("text", "menu.guidance_off" if prompts_before else "menu.guidance_on")),
		"Guidance toggle states its new value"
	)
	guidance.pressed.emit()
	_expect(_is_open() and paused, "Changing settings keeps the game paused")


func _confirm_page_audit() -> void:
	(_find("MainMenuButton") as Button).pressed.emit()
	await process_frame
	_expect((_find("PauseConfirmPage") as Control).visible, "Main menu asks for confirmation")
	_expect(root.gui_get_focus_owner() == _find("CancelButton"), "Confirmation focuses the safe choice")
	await _capture("03-return-confirm")
	await _audit_fit("Return confirmation")
	await _press(KEY_ESCAPE)
	_expect(_is_open() and not (_find("PauseConfirmPage") as Control).visible, "Esc backs out of confirmation only")
	_expect(root.gui_get_focus_owner() == _find("MainMenuButton"), "Backing out returns focus to Main Menu")

	(_find("QuitButton") as Button).pressed.emit()
	await process_frame
	_expect((_find("ConfirmTitle") as Label).text == str(locale.call("text", "pause.quit_title")), "Quit asks for confirmation")
	await _capture("04-quit-confirm")
	await _audit_fit("Quit confirmation")
	(_find("CancelButton") as Button).pressed.emit()
	_expect(_is_open() and root.gui_get_focus_owner() == _find("QuitButton"), "Cancel returns to the main settings page")
	_expect(quit_calls == 0, "Opening quit confirmation does not quit")


func _wake_room_audit() -> void:
	state.set("current_room_id", "wake_room")
	var room := await _load_room(WAKE)
	var wake_ready := await _settle()
	_expect(wake_ready, "Wake Room free play can open settings")
	room.call("show_book_clue")
	await process_frame
	var book := room.get("book_panel") as Control
	_expect(book != null and book.visible, "Control: the Wake Room book is open")
	await process_frame
	_expect(not bool(room.call("can_open_pause_menu")), "An open Wake Room panel vetoes settings")
	await _press(KEY_ESCAPE, &"ui_cancel")
	_expect(not book.visible, "Esc closes the Wake Room book first")
	_expect(not _is_open(), "The book's closing Esc does not also open settings")
	var free_after_book := await _settle()
	_expect(free_after_book, "Wake Room play is free after closing the book")
	await _press(KEY_ESCAPE, &"ui_cancel")
	_expect(_is_open(), "The next Esc opens settings in the Wake Room")
	await _press(KEY_ESCAPE, &"ui_cancel")
	_expect(not _is_open(), "Esc resumes the Wake Room")


func _hall_audit() -> void:
	state.set("current_room_id", "floor_1_hub")
	var hall := await _load_room(HALL)
	for flag: String in ["guardian_entry_sequence_active", "guardian_near_miss_active", "power_route_scan_active", "game_over"]:
		var original: Variant = hall.get(flag)
		hall.set(flag, true)
		_expect(not bool(hall.call("can_open_pause_menu")), "Hall %s vetoes settings" % flag)
		hall.set(flag, original)
	var hall_ready := await _settle(8.0)
	_expect(hall_ready, "Hall free play becomes pausable after scripted moments")
	await _press(KEY_ESCAPE)
	_expect(_is_open() and paused, "Esc pauses Hall play")
	var guardian := hall.get_node_or_null("CastleGuardian") as Node2D
	var player := get_first_node_in_group(&"player") as Node2D
	var guardian_before := guardian.global_position if guardian != null else Vector2.ZERO
	var player_before := player.global_position if player != null else Vector2.ZERO
	await _capture("05-hall-pause")
	Input.action_press(&"return_menu")
	await _press(KEY_M)
	Input.action_release(&"return_menu")
	await create_timer(0.4, true, false, true).timeout
	_expect(guardian == null or guardian.global_position == guardian_before, "The Guardian is frozen beneath settings")
	_expect(player == null or player.global_position == player_before, "The detective is frozen beneath settings")
	await _press(KEY_ESCAPE)
	await process_frame
	_expect(not _is_open() and current_scene == hall, "Hall shortcuts pressed in settings do not leave the Hall")


func _main_menu_settings_audit() -> void:
	var main := await _open_title_screen()
	var title_screen_pausable := await _settle(0.4)
	_expect(not title_screen_pausable, "The main menu never offers in-game settings")
	await _press(KEY_ESCAPE)
	_expect(not _is_open(), "Esc on the main menu does not open in-game settings")
	main.call("_show_settings_dialog")
	await process_frame
	var mute := main.find_child("MuteAllToggleButton", true, false) as Button
	_expect(mute != null and mute.is_visible_in_tree(), "Main-menu settings can undo a mute")
	if mute == null:
		return
	_expect(_text_fits(mute), "Main-menu mute label fits")
	for button_name: String in ["FieldPromptsToggleButton", "CloseMainMenuDialogButton"]:
		var button := main.find_child(button_name, true, false) as Button
		_expect(button != null and _text_fits(button), "%s label fits" % button_name)
		if button != null:
			_expect(not button.get_global_rect().intersects(mute.get_global_rect()), "%s does not overlap Mute" % button_name)
	mute.pressed.emit()
	_expect(bool(audio.call("is_muted")) and mute.text == str(locale.call("text", "menu.mute_on")), "Main-menu mute uses the same setting")
	await _capture("06-main-menu-settings")
	mute.pressed.emit()
	_expect(not bool(audio.call("is_muted")), "Main-menu unmute restores sound")
	await _press(KEY_ESCAPE)
	_expect(not _is_open(), "Closing the main-menu dialog stays in the main menu")


func _return_and_quit_audit() -> void:
	state.set("_loading_save", false)
	state.set("current_room_id", "chemistry_room")
	await _load_room(CHEMISTRY)
	var ready_for_return := await _settle()
	_expect(ready_for_return, "Chemistry is ready for the return test")
	var resume_before := str(state.get("resume_room_id"))
	await _press(KEY_ESCAPE)
	(_find("MainMenuButton") as Button).pressed.emit()
	var resume_name := str(locale.call("room_name", resume_before))
	_expect((_find("ConfirmBody") as Label).text.contains(resume_name), "Confirmation names the real Continue room")
	(_find("ConfirmButton") as Button).pressed.emit()
	_expect(not _is_open() and not menu.visible, "Confirming hides settings before the transition")
	await create_timer(1.3, true, false, true).timeout
	_expect(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "Main Menu returns to the title screen")
	_expect(not paused, "The title screen is not left paused")
	_expect(bool(state.call("has_saved_game")), "The case is saved for Continue")
	_expect(str(state.call("_saved_resume_room_id")) == resume_before, "The saved Continue room is unchanged")
	_expect(
		not (root.get_node("InventoryHud") as CanvasLayer).visible
		and not (root.get_node("MapHud") as CanvasLayer).visible,
		"Returning hides field HUDs on the title screen"
	)
	await _capture("07-returned-title")

	state.set("current_room_id", "chemistry_room")
	await _load_room(CHEMISTRY)
	var ready_for_quit := await _settle()
	_expect(ready_for_quit, "Chemistry is ready for the quit test")
	var generation := int(state.get("save_generation"))
	await _press(KEY_ESCAPE)
	(_find("QuitButton") as Button).pressed.emit()
	(_find("ConfirmButton") as Button).pressed.emit()
	_expect(quit_calls == 1, "Quit confirmation requests one engine quit")
	_expect(int(state.get("save_generation")) > generation and bool(state.call("has_saved_game")), "Quit writes the autosave first")
	_expect(not _is_open(), "Quitting dismisses settings")
	paused = false


# ----------------------------------------------------------------- helpers


func _load_room(path: String) -> Node:
	if current_scene != null:
		var old := current_scene
		current_scene = null
		old.queue_free()
		await process_frame
	paused = false
	var room := (load(path) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for _frame: int in range(4):
		await process_frame
	return room


## The real scene change runs GameState's title-screen HUD visibility handoff.
func _open_title_screen() -> Node:
	paused = false
	change_scene_to_file(MAIN_MENU)
	for _frame: int in range(5):
		await process_frame
	return current_scene


func _settle(max_seconds: float = 3.0) -> bool:
	var waited := 0.0
	while not bool(menu.call("can_open")) and waited < max_seconds:
		await create_timer(0.05, true, false, true).timeout
		waited += 0.05
	return bool(menu.call("can_open"))


func _press(keycode: Key, polled_action: StringName = &"") -> void:
	# Viewport input drives event handlers; polled rooms read the Input singleton.
	if not polled_action.is_empty():
		Input.action_press(polled_action)
	root.push_input(_key_event(keycode, true))
	await process_frame
	if not polled_action.is_empty():
		Input.action_release(polled_action)
	root.push_input(_key_event(keycode, false))
	await process_frame


func _key_event(keycode: Key, pressed_state: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed_state
	return event


func _is_open() -> bool:
	return bool(menu.call("is_open"))


func _find(node_name: String) -> Node:
	return menu.find_child(node_name, true, false)


func _audit_fit(page: String) -> void:
	await process_frame
	await process_frame
	var frame := _find("PauseDossier") as Control
	var frame_rect := frame.get_global_rect()
	_expect(Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(frame_rect), "%s dossier fits 1024x768" % page)
	for node: Node in frame.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or not (control is Label or control is Button or control is Slider):
			continue
		_expect(frame_rect.grow(1.0).encloses(control.get_global_rect()), "%s: %s stays inside the dossier" % [page, control.name])
		_expect(_text_fits(control), "%s: %s text fits" % [page, control.name])


func _text_fits(control: Control) -> bool:
	if control is Button:
		var button := control as Button
		var style := button.get_theme_stylebox("normal")
		var available := button.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		return _widest_line(button.text, button) <= available + 0.5
	if control is Label:
		var label := control as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return label.get_line_count() * label.get_line_height() <= label.size.y + 1.0
		return _widest_line(label.text, label) <= label.size.x + 0.5
	return true


func _widest_line(text: String, control: Control) -> float:
	var font := control.get_theme_font("font")
	var font_size := control.get_theme_font_size("font_size")
	var widest := 0.0
	for line: String in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var directory := ProjectSettings.globalize_path(EVIDENCE)
	DirAccess.make_dir_recursive_absolute(directory)
	var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	await create_timer(0.25, true, false, true).timeout
	# An occluded native window can withhold frame_post_draw; draw explicitly.
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Capture uses native resolution")
	var suffix := "-zh" if bool(locale.call("is_chinese")) else ""
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
