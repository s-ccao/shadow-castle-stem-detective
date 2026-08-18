extends Control

const DIALOG_FILL := Color(0.038, 0.023, 0.020, 0.985)
const DIALOG_INLAY := Color(0.085, 0.046, 0.028, 0.99)
const DIALOG_BORDER := Color(0.76, 0.51, 0.18, 0.98)
const DIALOG_RIVET := Color(0.21, 0.12, 0.060, 0.98)

@onready var start_ui: Control = $StartUI

var menu_dialog_layer: CanvasLayer
var menu_dialog_overlay: ColorRect
var menu_dialog_frame: Panel
var menu_dialog_inlay: Panel
var menu_dialog_title: Label
var menu_dialog_text: Label
var menu_dialog_close_button: Button
var menu_dialog_english_button: Button
var menu_dialog_chinese_button: Button
var menu_dialog_guidance_button: Button
var volume_controls: Array[Control] = []
var active_dialog := ""
var case_archive_button: Button
var case_archive_ui: CaseArchiveUi


func _ready() -> void:
	_connect_start_ui()
	create_menu_dialog()
	_create_case_archive_entry()


## A finished case stays readable. The entry only exists once an ending has been
## reached, and the archive itself is built on demand so the menu stays light.
func _create_case_archive_entry() -> void:
	case_archive_button = Button.new()
	case_archive_button.name = "CaseArchiveButton"
	case_archive_button.position = Vector2(36.0, 700.0)
	case_archive_button.size = Vector2(240.0, 44.0)
	ArchiveUi.apply_button(case_archive_button, ArchiveUi.ROLE_ARCANE)
	case_archive_button.pressed.connect(_open_case_archive)
	add_child(case_archive_button)
	_refresh_case_archive_entry()


func _refresh_case_archive_entry() -> void:
	if case_archive_button == null:
		return
	case_archive_button.visible = CaseArchiveUi.is_unlocked()
	case_archive_button.text = "案件档案" if CaseLocale.is_chinese() else "CASE ARCHIVE"


func _open_case_archive() -> void:
	if case_archive_ui == null or not is_instance_valid(case_archive_ui):
		case_archive_ui = CaseArchiveUi.new()
		add_child(case_archive_ui)
		case_archive_ui.archive_closed.connect(_on_case_archive_closed)
	if start_ui != null:
		start_ui.call("set_ui_enabled", false)
	case_archive_ui.open_archive()


func _on_case_archive_closed() -> void:
	if start_ui != null:
		start_ui.call("set_ui_enabled", true)
	if case_archive_button != null and case_archive_button.visible:
		case_archive_button.call_deferred("grab_focus")


func _connect_start_ui() -> void:
	if start_ui == null:
		push_error("StartUI scene instance is missing from MainMenu.")
		return
	if start_ui.has_method("set_continue_enabled"):
		start_ui.call("set_continue_enabled", GameState.has_saved_game())
	if start_ui.has_method("set_save_status"):
		start_ui.call(
			"set_save_status",
			GameState.resume_label() if GameState.has_saved_game() else ""
		)
	start_ui.start_requested.connect(start_game)
	start_ui.continue_requested.connect(_continue_game)
	start_ui.settings_requested.connect(_show_settings_dialog)
	start_ui.language_requested.connect(_show_language_dialog)
	start_ui.quit_requested.connect(quit_game)
	CaseLocale.locale_changed.connect(_refresh_copy)

func create_menu_dialog() -> void:
	menu_dialog_layer = CanvasLayer.new()
	menu_dialog_layer.name = "MainMenuDialogLayer"
	menu_dialog_layer.layer = 20
	menu_dialog_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_dialog_layer)

	menu_dialog_overlay = ColorRect.new()
	menu_dialog_overlay.name = "MainMenuDialogOverlay"
	menu_dialog_overlay.color = Color(0.0, 0.0, 0.02, 0.72)
	menu_dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_dialog_overlay.visible = false
	menu_dialog_layer.add_child(menu_dialog_overlay)

	menu_dialog_frame = Panel.new()
	menu_dialog_frame.name = "MainMenuDialogFrame"
	menu_dialog_frame.position = Vector2(220, 176)
	menu_dialog_frame.size = Vector2(584, 416)
	menu_dialog_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_dialog_frame.add_theme_stylebox_override(
		"panel",
		_dialog_panel_style(DIALOG_FILL, DIALOG_BORDER, 2, 7)
	)
	menu_dialog_overlay.add_child(menu_dialog_frame)

	menu_dialog_inlay = Panel.new()
	menu_dialog_inlay.name = "MainMenuDialogInlay"
	menu_dialog_inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_dialog_inlay.offset_left = 4.0
	menu_dialog_inlay.offset_top = 4.0
	menu_dialog_inlay.offset_right = -4.0
	menu_dialog_inlay.offset_bottom = -4.0
	menu_dialog_inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_dialog_inlay.add_theme_stylebox_override(
		"panel",
		_dialog_panel_style(DIALOG_INLAY, DIALOG_RIVET, 1, 4)
	)
	menu_dialog_frame.add_child(menu_dialog_inlay)
	ArchiveUi.install_dossier_chrome(menu_dialog_frame, {"accent": DIALOG_BORDER})

	menu_dialog_title = Label.new()
	menu_dialog_title.position = Vector2(262, 220)
	menu_dialog_title.size = Vector2(500, 42)
	menu_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_dialog_title.add_theme_font_size_override("font_size", 27)
	ArchiveUi.apply_label(menu_dialog_title, &"title")
	menu_dialog_overlay.add_child(menu_dialog_title)

	menu_dialog_text = Label.new()
	menu_dialog_text.name = "MainMenuDialogText"
	menu_dialog_text.position = Vector2(266, 288)
	menu_dialog_text.size = Vector2(492, 148)
	menu_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_dialog_text.add_theme_font_size_override("font_size", 15)
	ArchiveUi.apply_label(menu_dialog_text, &"body")
	menu_dialog_overlay.add_child(menu_dialog_text)

	menu_dialog_close_button = Button.new()
	menu_dialog_close_button.name = "CloseMainMenuDialogButton"
	menu_dialog_close_button.text = CaseLocale.text("menu.close")
	menu_dialog_close_button.position = Vector2(530, 518)
	menu_dialog_close_button.size = Vector2(170, 42)
	ArchiveUi.apply_button(menu_dialog_close_button, ArchiveUi.ROLE_ARCHIVE)
	menu_dialog_close_button.pressed.connect(_hide_menu_dialog)
	menu_dialog_overlay.add_child(menu_dialog_close_button)

	menu_dialog_english_button = Button.new()
	menu_dialog_english_button.name = "EnglishLanguageButton"
	menu_dialog_english_button.position = Vector2(316, 518)
	menu_dialog_english_button.size = Vector2(170, 42)
	ArchiveUi.apply_button(menu_dialog_english_button, ArchiveUi.ROLE_ACTION)
	menu_dialog_english_button.pressed.connect(func() -> void:
		CaseLocale.set_language(CaseLocale.ENGLISH)
		_hide_menu_dialog()
	)
	menu_dialog_overlay.add_child(menu_dialog_english_button)

	menu_dialog_chinese_button = Button.new()
	menu_dialog_chinese_button.name = "ChineseLanguageButton"
	menu_dialog_chinese_button.position = Vector2(538, 518)
	menu_dialog_chinese_button.size = Vector2(170, 42)
	ArchiveUi.apply_button(menu_dialog_chinese_button, ArchiveUi.ROLE_ARCANE)
	menu_dialog_chinese_button.pressed.connect(func() -> void:
		CaseLocale.set_language(CaseLocale.CHINESE)
		_hide_menu_dialog()
	)
	menu_dialog_overlay.add_child(menu_dialog_chinese_button)
	menu_dialog_english_button.focus_neighbor_right = menu_dialog_chinese_button.get_path()
	menu_dialog_chinese_button.focus_neighbor_left = menu_dialog_english_button.get_path()

	menu_dialog_guidance_button = Button.new()
	menu_dialog_guidance_button.name = "FieldPromptsToggleButton"
	menu_dialog_guidance_button.position = Vector2(324, 518)
	menu_dialog_guidance_button.size = Vector2(190, 42)
	ArchiveUi.apply_button(menu_dialog_guidance_button, ArchiveUi.ROLE_ACTION)
	menu_dialog_guidance_button.pressed.connect(func() -> void:
		PlayerPreferences.toggle_field_prompts()
		_show_settings_dialog()
	)
	menu_dialog_overlay.add_child(menu_dialog_guidance_button)
	menu_dialog_guidance_button.focus_neighbor_right = menu_dialog_close_button.get_path()
	menu_dialog_close_button.focus_neighbor_left = menu_dialog_guidance_button.get_path()

	_create_volume_sliders()


func _create_volume_sliders() -> void:
	# Music and effects get separate faders because they fail the player in
	# different ways: the score can outstay its welcome long before the feedback
	# sounds do, and a player who mutes everything to fix one of them loses the
	# other. Master stays on the bus layout as the single hardware-style trim.
	var rows: Array[Dictionary] = [
		{"bus": GameAudio.MUSIC_BUS, "label_en": "MUSIC", "label_zh": "音乐", "y": 438},
		{"bus": GameAudio.SFX_BUS, "label_en": "EFFECTS", "label_zh": "音效", "y": 476},
	]
	for row: Dictionary in rows:
		var bus: StringName = row["bus"]
		var caption := Label.new()
		caption.name = "VolumeLabel_" + String(bus)
		caption.position = Vector2(324, float(row["y"]))
		caption.size = Vector2(96, 28)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ArchiveUi.apply_label(caption, &"body")
		caption.text = String(row["label_zh"]) if CaseLocale.is_chinese() else String(row["label_en"])
		menu_dialog_overlay.add_child(caption)

		var slider := HSlider.new()
		slider.name = "VolumeSlider_" + String(bus)
		slider.position = Vector2(428, float(row["y"]) + 3)
		slider.size = Vector2(272, 24)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameAudio.get_bus_volume_linear(bus)
		slider.focus_mode = Control.FOCUS_ALL
		ArchiveUi.apply_slider(slider)
		slider.value_changed.connect(func(value: float) -> void:
			GameAudio.set_bus_volume_linear(bus, value)
			# The fader has to be audible while it is being dragged, otherwise the
			# player is adjusting a number instead of a sound.
			if bus == GameAudio.SFX_BUS:
				GameAudio.play(&"ui_select")
		)
		menu_dialog_overlay.add_child(slider)
		volume_controls.append(caption)
		volume_controls.append(slider)


func _unhandled_key_input(event: InputEvent) -> void:
	if not menu_dialog_overlay.visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_hide_menu_dialog()
			get_viewport().set_input_as_handled()


func _show_menu_dialog(title: String, text: String, language_picker: bool = false) -> void:
	menu_dialog_title.text = title
	menu_dialog_text.text = text
	ArchiveUi.apply_label(menu_dialog_title, &"title")
	ArchiveUi.apply_label(menu_dialog_text, &"body")
	menu_dialog_close_button.visible = not language_picker
	menu_dialog_english_button.visible = language_picker
	menu_dialog_chinese_button.visible = language_picker
	menu_dialog_guidance_button.visible = active_dialog == "settings"
	for control: Control in volume_controls:
		control.visible = active_dialog == "settings"
		if control is HSlider:
			# Re-read on open: the buses may have been changed elsewhere, and a fader
			# that lies about the current level is worse than no fader.
			var slider := control as HSlider
			var bus: StringName = StringName(slider.name.trim_prefix("VolumeSlider_"))
			slider.set_value_no_signal(GameAudio.get_bus_volume_linear(bus))
	if language_picker:
		menu_dialog_english_button.text = CaseLocale.text("language.english")
		menu_dialog_chinese_button.text = CaseLocale.text("language.chinese")
	menu_dialog_overlay.visible = true
	(
		menu_dialog_english_button
		if language_picker
		else menu_dialog_guidance_button
		if active_dialog == "settings"
		else menu_dialog_close_button
	).call_deferred("grab_focus")


func _show_continue_dialog() -> void:
	_show_menu_dialog(
		CaseLocale.text("menu.continue"),
		CaseLocale.text("save.none")
	)


func _continue_game() -> void:
	if not GameState.load_saved_game():
		_show_continue_dialog()
		return
	var resume_path: String = GameState.resume_scene_path
	if not ResourceLoader.exists(resume_path):
		resume_path = "res://scenes/wake_room.tscn"
	get_tree().change_scene_to_file(resume_path)


func _show_settings_dialog() -> void:
	active_dialog = "settings"
	menu_dialog_guidance_button.text = CaseLocale.text(
		"menu.guidance_on"
		if PlayerPreferences.field_prompts_enabled
		else "menu.guidance_off"
	)
	_show_menu_dialog(
		CaseLocale.text("menu.settings_title"),
		CaseLocale.text("menu.settings_body")
	)


func _show_language_dialog() -> void:
	active_dialog = "language"
	_show_menu_dialog(
		CaseLocale.text("menu.language_title"),
		CaseLocale.text("menu.language_body"),
		true
	)


func _hide_menu_dialog() -> void:
	active_dialog = ""
	menu_dialog_overlay.visible = false
	if start_ui != null and start_ui.has_method("restore_default_focus"):
		start_ui.call("restore_default_focus")


func start_game() -> void:
	_hide_menu_dialog()
	if start_ui != null and start_ui.has_method("set_ui_enabled"):
		start_ui.call("set_ui_enabled", false)
	GameState.delete_saved_game()
	GameState.reset_new_game()
	if NoteHud != null:
		NoteHud.reset()
	GameState.mark_game_started()

	ArchiveUi.play_case_open_transition(self, func() -> void:
		get_tree().change_scene_to_file("res://scenes/intro_cutscene.tscn")
	)


func quit_game() -> void:
	get_tree().quit()


func _refresh_copy(_language: String = "") -> void:
	if start_ui != null:
		start_ui.call("set_continue_enabled", GameState.has_saved_game())
		start_ui.call(
			"set_save_status",
			GameState.resume_label() if GameState.has_saved_game() else ""
		)
	ArchiveUi.refresh_tree(menu_dialog_layer)
	_refresh_case_archive_entry()
	menu_dialog_close_button.text = CaseLocale.text("menu.close")
	menu_dialog_guidance_button.text = CaseLocale.text(
		"menu.guidance_on"
		if PlayerPreferences.field_prompts_enabled
		else "menu.guidance_off"
	)
	ArchiveUi.apply_label(menu_dialog_title, &"title")
	ArchiveUi.apply_label(menu_dialog_text, &"body")
	if not menu_dialog_overlay.visible:
		return
	if active_dialog == "settings":
		_show_settings_dialog()
	elif active_dialog == "language":
		_show_language_dialog()


func _dialog_panel_style(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.88)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 6.0)
	return style
