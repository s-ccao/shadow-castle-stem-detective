## In-game pause and settings dossier.
##
## Esc (or a controller's Start button) opens it only while play is genuinely free.
## Hubs, minigames, dossiers, door questions and room transitions already pause the
## tree or consume Esc first, and a room can veto the menu for its own panels or
## cinematics through `can_open_pause_menu()`. While open, this menu owns the pause
## and swallows room and Hub shortcuts so nothing advances or opens underneath it.
extends CanvasLayer

signal opened
signal closed

const MENU_LAYER := 94
const ACTION := &"pause_menu"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const FRAME_SIZE := Vector2(780.0, 556.0)
const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX"]
## The closing key stays "just pressed" for its own frame. Resuming one frame later
## keeps room scripts that poll Esc from acting on the same press.
const RESUME_DELAY_FRAMES := 2

## Tests replace this so the quit path can be verified without closing the engine.
var quit_handler: Callable
## A browser tab cannot close itself: there, quitting returns the visitor to the
## website's case files (see `onExit` in web/shell/loading_shell.html), and the
## confirmation says so. Tests set this to check that copy on a desktop build.
var quit_returns_to_site := OS.has_feature("web")

var _open := false
var _confirm_kind := ""
var _resume_frames := 0
var _free_last_frame := false
var _previous_focus: Control
var _open_tween: Tween

var _root: Control
var _frame: Panel
var _kicker: Label
var _title: Label
var _save_status: Label
var _main_page: HBoxContainer
var _confirm_page: VBoxContainer
var _resume_button: Button
var _menu_button: Button
var _quit_button: Button
var _resume_hint: Label
var _sound_heading: Label
var _mute_button: Button
var _volume_sliders: Dictionary = {}
var _volume_captions: Dictionary = {}
var _volume_values: Dictionary = {}
var _guidance_heading: Label
var _guidance_button: Button
var _controls_heading: Label
var _controls_text: Label
var _confirm_title: Label
var _confirm_body: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	quit_handler = func() -> void: GameExit.quit(get_tree())
	_bind_controller_start()
	_build()
	_wire_focus()
	CaseLocale.locale_changed.connect(_on_locale_changed)
	get_tree().scene_changed.connect(_on_scene_changed)


func is_open() -> bool:
	return _open


## True when Esc would open the menu right now.
func can_open() -> bool:
	return not _open and _resume_frames == 0 and _free_last_frame and _play_is_free()


func open() -> void:
	if _open:
		return
	_open = true
	_resume_frames = 0
	_previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	_refresh_copy()
	visible = true
	_show_main_page(_resume_button)
	_play_open_motion()
	opened.emit()


func resume() -> void:
	if not _open:
		return
	_open = false
	_confirm_kind = ""
	visible = false
	_resume_frames = RESUME_DELAY_FRAMES
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()


func _process(_delta: float) -> void:
	var tree := get_tree()
	if _open:
		# Own the pause while visible: process-always timers must not resume play beneath it.
		if not tree.paused:
			tree.paused = true
		_free_last_frame = false
		return
	if _resume_frames > 0:
		_resume_frames -= 1
		if _resume_frames == 0:
			tree.paused = false
		_free_last_frame = false
		return
	# Sampled before the next input event: a panel that Esc closes this frame was
	# still open last frame, so the same press can never also open this menu.
	_free_last_frame = _play_is_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if _handle_menu_input(event) or _open:
		# Hub and room shortcuts must not act beneath the paused menu.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		return
	if _handle_menu_input(event):
		get_viewport().set_input_as_handled()


func _handle_menu_input(event: InputEvent) -> bool:
	if not (event.is_action_pressed(ACTION) or (_open and event.is_action_pressed(&"ui_cancel"))):
		return false
	if not _open:
		if not can_open():
			return false
		open()
		GameAudio.play(&"ui_select")
		return true
	if _confirm_kind.is_empty():
		resume()
	else:
		_show_main_page()
	GameAudio.play(&"ui_back")
	return true


func _play_is_free() -> bool:
	var tree := get_tree()
	if tree.paused or tree.current_scene == null:
		return false
	# Menus and cutscenes have no detective to pause.
	if tree.get_first_node_in_group(&"player") == null:
		return false
	var scene := tree.current_scene
	return not scene.has_method("can_open_pause_menu") or bool(scene.call("can_open_pause_menu"))


func _bind_controller_start() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		InputMap.action_add_event(ACTION, escape)
	for existing: InputEvent in InputMap.action_get_events(ACTION):
		var joypad := existing as InputEventJoypadButton
		if joypad != null and joypad.button_index == JOY_BUTTON_START:
			return
	var start := InputEventJoypadButton.new()
	start.device = -1
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event(ACTION, start)


# ---------------------------------------------------------------- actions


func _ask_confirm(kind: String) -> void:
	_confirm_kind = kind
	_refresh_confirm_copy()
	_main_page.visible = false
	_confirm_page.visible = true
	# The safe choice is focused, so a stray Enter never leaves the case.
	_cancel_button.grab_focus()


func _show_main_page(focus: Control = null) -> void:
	var returning_from := _confirm_kind
	_confirm_kind = ""
	_confirm_page.visible = false
	_main_page.visible = true
	var target := focus
	if target == null:
		target = _resume_button
		if returning_from == "quit":
			target = _quit_button
		elif returning_from == "menu":
			target = _menu_button
	target.grab_focus()


func _on_confirm_pressed() -> void:
	match _confirm_kind:
		"menu":
			_return_to_main_menu()
		"quit":
			_quit_game()


func _return_to_main_menu() -> void:
	_dismiss()
	var tree := get_tree()
	# The transition snapshots this as the pause state to restore on the main menu.
	tree.paused = false
	ArchiveUi.play_main_menu_transition(func() -> void:
		# Never serialize a dead player or an active chase for the next Continue.
		GameState.recover_from_interruption()
		var change_error := tree.change_scene_to_file(MAIN_MENU_SCENE)
		if change_error != OK:
			push_error("Failed to return to main menu. Error: " + str(change_error))
	)


func _quit_game() -> void:
	_dismiss()
	GameState.recover_from_interruption()
	# The queued autosave is deferred and would not run once the engine quits.
	GameState.save_to_disk()
	quit_handler.call()


## Leaves without the resume delay; the caller decides what happens to the pause.
func _dismiss() -> void:
	_open = false
	_confirm_kind = ""
	_resume_frames = 0
	visible = false
	_previous_focus = null
	closed.emit()


func _on_mute_pressed() -> void:
	GameAudio.toggle_muted()
	_refresh_toggles()


func _on_guidance_pressed() -> void:
	PlayerPreferences.toggle_field_prompts()
	_refresh_toggles()


func _on_volume_changed(value: float, bus: StringName) -> void:
	GameAudio.set_bus_volume_linear(bus, value)
	(_volume_values[bus] as Label).text = "%d%%" % roundi(value * 100.0)
	# An effects fader must be audible while it is dragged.
	if bus == &"SFX":
		GameAudio.play(&"ui_select")


func _on_locale_changed(_language: String) -> void:
	if visible:
		_refresh_copy()


func _on_scene_changed() -> void:
	# A scene swap underneath an open menu would otherwise strand its pause.
	if _open or _resume_frames > 0:
		_dismiss()
		get_tree().paused = false
	_free_last_frame = false


func _quit_supported() -> bool:
	# iOS apps must not quit themselves. In a browser, quitting takes the visitor
	# back to the case files instead of closing the tab.
	return not OS.has_feature("ios")


# ------------------------------------------------------------------ copy


func _refresh_copy() -> void:
	var room := _room_label(GameState.current_room_id)
	if room.is_empty():
		_kicker.text = CaseLocale.text("pause.kicker_plain")
	else:
		_kicker.text = CaseLocale.text("pause.kicker", {"room": room})
	_title.text = CaseLocale.text("menu.settings_title")
	_save_status.text = GameState.resume_label()
	_resume_button.text = CaseLocale.text("pause.resume")
	_menu_button.text = CaseLocale.text("pause.main_menu")
	_quit_button.text = CaseLocale.text("pause.quit")
	_resume_hint.text = CaseLocale.text("pause.resume_hint")
	_sound_heading.text = CaseLocale.text("pause.sound")
	_guidance_heading.text = CaseLocale.text("pause.guidance")
	_controls_heading.text = CaseLocale.text("pause.controls")
	_controls_text.text = CaseLocale.text("menu.settings_body")
	(_volume_captions[&"Music"] as Label).text = CaseLocale.text("pause.music")
	(_volume_captions[&"SFX"] as Label).text = CaseLocale.text("pause.effects")
	for bus: StringName in VOLUME_BUSES:
		# Re-read on open: the main menu may have moved these faders.
		var level: float = GameAudio.get_bus_volume_linear(bus)
		(_volume_sliders[bus] as HSlider).set_value_no_signal(level)
		(_volume_values[bus] as Label).text = "%d%%" % roundi(level * 100.0)
	_cancel_button.text = CaseLocale.text("pause.cancel")
	_refresh_toggles()
	if not _confirm_kind.is_empty():
		_refresh_confirm_copy()
	ArchiveUi.refresh_tree(_root)


func _refresh_toggles() -> void:
	var muted: bool = GameAudio.is_muted()
	_mute_button.text = CaseLocale.text("menu.mute_on" if muted else "menu.mute_off")
	ArchiveUi.apply_button(_mute_button, ArchiveUi.ROLE_ARCANE if muted else ArchiveUi.ROLE_ARCHIVE)
	_guidance_button.text = CaseLocale.text(
		"menu.guidance_on" if PlayerPreferences.field_prompts_enabled else "menu.guidance_off"
	)


func _refresh_confirm_copy() -> void:
	var quitting := _confirm_kind == "quit"
	var room := _room_label(GameState.resume_room_id)
	var body_key := "pause.quit_body" if quitting else "pause.menu_body"
	if quitting and quit_returns_to_site:
		body_key = "pause.quit_body_web"
	if room.is_empty():
		body_key += "_plain"
	_confirm_title.text = CaseLocale.text("pause.quit_title" if quitting else "pause.menu_title")
	_confirm_body.text = CaseLocale.text(body_key, {"room": room})
	_confirm_button.text = CaseLocale.text("pause.quit_confirm" if quitting else "pause.menu_confirm")
	var confirm_role := ArchiveUi.ROLE_DANGER if quitting else ArchiveUi.ROLE_ACTION
	ArchiveUi.apply_button(_confirm_button, confirm_role)


func _room_label(room_id: String) -> String:
	if room_id.is_empty():
		return ""
	var label := CaseLocale.room_name(room_id)
	return "" if label.begins_with("room.") else label


# ----------------------------------------------------------------- layout


func _build() -> void:
	_root = Control.new()
	_root.name = "PauseMenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var veil := ColorRect.new()
	veil.name = "PauseVeil"
	veil.color = Color(0.004, 0.003, 0.012, 0.76)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	_frame = Panel.new()
	_frame.name = "PauseDossier"
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.offset_left = -FRAME_SIZE.x * 0.5
	_frame.offset_top = -FRAME_SIZE.y * 0.5
	_frame.offset_right = FRAME_SIZE.x * 0.5
	_frame.offset_bottom = FRAME_SIZE.y * 0.5
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(
		"panel", ArchiveUi.panel_style(ArchiveUi.COLOR_PANEL, ArchiveUi.COLOR_BRASS, 2, 7, 18)
	)
	_root.add_child(_frame)

	var inlay := Panel.new()
	inlay.name = "PauseInlay"
	inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inlay.offset_left = 4.0
	inlay.offset_top = 4.0
	inlay.offset_right = -4.0
	inlay.offset_bottom = -4.0
	inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inlay_style := ArchiveUi.panel_style(
		ArchiveUi.COLOR_PANEL_INLAY, Color(0.21, 0.12, 0.06, 0.98), 1, 4, 0
	)
	inlay.add_theme_stylebox_override("panel", inlay_style)
	_frame.add_child(inlay)
	ArchiveUi.install_dossier_chrome(_frame, {"accent": ArchiveUi.COLOR_BRASS})

	var margin := MarginContainer.new()
	margin.name = "PauseContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	_frame.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "PauseColumn"
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	_kicker = _label("PauseKicker", &"muted", 12, column)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _label("PauseTitle", &"title", 28, column)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_status = _label("PauseAutosave", &"muted", 12, column)
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rule(0.46))

	_main_page = HBoxContainer.new()
	_main_page.name = "PauseMainPage"
	_main_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_page.add_theme_constant_override("separation", 26)
	column.add_child(_main_page)
	_build_actions(_main_page)
	var divider := _rule(0.30)
	divider.custom_minimum_size = Vector2(1.0, 0.0)
	_main_page.add_child(divider)
	_build_settings(_main_page)
	_build_confirm(column)


func _build_actions(parent: Control) -> void:
	var actions := VBoxContainer.new()
	actions.name = "PauseActions"
	actions.custom_minimum_size.x = 232.0
	actions.add_theme_constant_override("separation", 12)
	parent.add_child(actions)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6.0
	actions.add_child(gap)
	_resume_button = _button("ResumeButton", ArchiveUi.ROLE_ACTION, actions, resume)
	_resume_button.custom_minimum_size.y = 54.0
	_menu_button = _button(
		"MainMenuButton", ArchiveUi.ROLE_ARCHIVE, actions, _ask_confirm.bind("menu")
	)
	_quit_button = _button("QuitButton", ArchiveUi.ROLE_DANGER, actions, _ask_confirm.bind("quit"))
	_quit_button.visible = _quit_supported()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_resume_hint = _label("ResumeHint", &"muted", 12, actions)
	_resume_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_settings(parent: Control) -> void:
	var settings := VBoxContainer.new()
	settings.name = "PauseSettings"
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 7)
	parent.add_child(settings)
	_sound_heading = _label("SoundHeading", &"muted", 12, settings)
	_mute_button = _button("MuteToggle", ArchiveUi.ROLE_ARCHIVE, settings, _on_mute_pressed)
	for bus: StringName in VOLUME_BUSES:
		_volume_row(bus, settings)
	_guidance_heading = _label("GuidanceHeading", &"muted", 12, settings)
	_guidance_button = _button(
		"GuidanceToggle", ArchiveUi.ROLE_ARCHIVE, settings, _on_guidance_pressed
	)
	_controls_heading = _label("ControlsHeading", &"muted", 12, settings)
	_controls_text = _label("ControlsReference", &"body", 13, settings)
	_controls_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_confirm(parent: Control) -> void:
	_confirm_page = VBoxContainer.new()
	_confirm_page.name = "PauseConfirmPage"
	_confirm_page.visible = false
	_confirm_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_page.add_theme_constant_override("separation", 22)
	parent.add_child(_confirm_page)
	_confirm_title = _label("ConfirmTitle", &"title", 24, _confirm_page)
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_body = _label("ConfirmBody", &"body", 15, _confirm_page)
	_confirm_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.custom_minimum_size.x = 540.0
	_confirm_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.name = "ConfirmActions"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_confirm_page.add_child(row)
	_confirm_button = _button("ConfirmButton", ArchiveUi.ROLE_ACTION, row, _on_confirm_pressed)
	_confirm_button.custom_minimum_size = Vector2(210.0, 50.0)
	_cancel_button = _button("CancelButton", ArchiveUi.ROLE_ARCHIVE, row, _show_main_page)
	_cancel_button.custom_minimum_size = Vector2(210.0, 50.0)


func _volume_row(bus: StringName, parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_" + String(bus)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var caption := _label("VolumeCaption_" + String(bus), &"body", 14, row)
	caption.custom_minimum_size = Vector2(86.0, 30.0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var slider := HSlider.new()
	slider.name = "PauseVolume_" + String(bus)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 24.0
	ArchiveUi.apply_slider(slider)
	slider.value_changed.connect(_on_volume_changed.bind(bus))
	row.add_child(slider)
	var value := _label("VolumeValue_" + String(bus), &"muted", 13, row)
	value.custom_minimum_size = Vector2(46.0, 30.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_volume_captions[bus] = caption
	_volume_sliders[bus] = slider
	_volume_values[bus] = value


func _wire_focus() -> void:
	var actions: Array[Control] = [_resume_button, _menu_button]
	if _quit_button.visible:
		actions.append(_quit_button)
	var settings: Array[Control] = [
		_mute_button, _volume_sliders[&"Music"], _volume_sliders[&"SFX"], _guidance_button,
	]
	_link_column(actions)
	_link_column(settings)
	for control: Control in actions:
		control.focus_neighbor_right = control.get_path_to(_mute_button)
	for control: Control in settings:
		# Left and right adjust a fader; only the toggles step back to the actions.
		if control is Button:
			control.focus_neighbor_left = control.get_path_to(_resume_button)
	var reading_order: Array[Control] = actions.duplicate()
	reading_order.append_array(settings)
	_link_tab_order(reading_order)
	var confirm_order: Array[Control] = [_confirm_button, _cancel_button]
	_link_tab_order(confirm_order)
	_confirm_button.focus_neighbor_right = _confirm_button.get_path_to(_cancel_button)
	_cancel_button.focus_neighbor_left = _cancel_button.get_path_to(_confirm_button)


func _link_column(controls: Array[Control]) -> void:
	var count := controls.size()
	for index: int in range(count):
		var control := controls[index]
		control.focus_neighbor_top = control.get_path_to(controls[(index - 1 + count) % count])
		control.focus_neighbor_bottom = control.get_path_to(controls[(index + 1) % count])


func _link_tab_order(controls: Array[Control]) -> void:
	var count := controls.size()
	for index: int in range(count):
		var control := controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % count])
		control.focus_previous = control.get_path_to(controls[(index - 1 + count) % count])


func _play_open_motion() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_root.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.tween_property(_root, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _label(node_name: String, role: StringName, font_size: int, parent: Control) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	ArchiveUi.apply_label(label, role)
	parent.add_child(label)
	return label


func _button(node_name: String, role: StringName, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	ArchiveUi.apply_button(button, role)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _rule(alpha: float) -> ColorRect:
	var rule := ColorRect.new()
	var brass := ArchiveUi.COLOR_BRASS
	rule.color = Color(brass.r, brass.g, brass.b, alpha)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule
