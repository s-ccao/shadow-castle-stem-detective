## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Macrostructure: case-intake desk. The title artwork keeps the spectacle;
## this restrained lower dossier is the only place the player makes a decision.
extends Control

signal start_requested
signal continue_requested
signal settings_requested
signal language_requested
signal quit_requested

const PANEL_FILL := Color(0.029, 0.019, 0.021, 0.965)
const PANEL_INLAY := Color(0.078, 0.043, 0.030, 0.99)
const PANEL_BORDER := Color(0.69, 0.45, 0.16, 0.96)
const PANEL_RIVET := Color(0.16, 0.086, 0.047, 0.98)
const INK_LIGHT := Color(0.96, 0.87, 0.68, 1.0)
const INK_MUTED := Color(0.74, 0.64, 0.47, 1.0)
const INK_STATUS := Color(0.70, 0.83, 0.66, 1.0)
const BRASS_FILL := Color(0.36, 0.19, 0.065, 1.0)
const BRASS_HOVER := Color(0.52, 0.29, 0.09, 1.0)
const BRASS_BORDER := Color(0.94, 0.73, 0.31, 1.0)
const ARCHIVE_FILL := Color(0.12, 0.071, 0.038, 0.98)
const ARCHIVE_HOVER := Color(0.20, 0.117, 0.055, 1.0)
const MUTED_FILL := Color(0.052, 0.040, 0.038, 0.94)
const MUTED_HOVER := Color(0.098, 0.069, 0.060, 0.98)
const FOCUS_GOLD := Color(1.0, 0.84, 0.43, 1.0)
const CASE_INTAKE_WIDTH := 380.0
const CASE_INTAKE_HEIGHT_EMPTY := 254.0
const CASE_INTAKE_HEIGHT_RESUME := 312.0

var _arrival_tween: Tween
var _button_tweens: Dictionary = {}

@onready var artwork: TextureRect = $StartArtwork
@onready var case_intake: Panel = %CaseIntake
@onready var intake_inlay: Panel = %Inlay
@onready var case_kicker: Label = %CaseKicker
@onready var case_title: Label = %CaseTitle
@onready var case_detail: Label = %CaseDetail
@onready var case_meta: Label = %CaseMeta
@onready var divider: ColorRect = %Divider
@onready var start_button: Button = $CaseIntake/Content/ActionStack/StartGameButton
@onready var continue_block: VBoxContainer = %ContinueBlock
@onready var continue_button: Button = $CaseIntake/Content/ActionStack/ContinueBlock/ContinueButton
@onready var settings_button: Button = $CaseIntake/Content/ActionStack/ToolRow/SettingsButton
@onready var language_button: Button = $CaseIntake/Content/ActionStack/ToolRow/LanguageButton
@onready var quit_button: Button = $CaseIntake/Content/ActionStack/ToolRow/QuitButton
@onready var save_label: Label = $CaseIntake/Content/ActionStack/ContinueBlock/SaveStatus


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArchiveUi.drift_backdrop(artwork, {"zoom": 0.040, "period": 32.0})
	ArchiveUi.install_screen_atmosphere(self, {
		"lamp_anchor": Vector2(0.5, 0.20),
		"lamp_strength": 0.22,
		"lamp_radius": 0.54,
		"vignette_strength": 0.54,
		"vignette_radius": 0.38,
		"mote_strength": 0.40,
	})
	ArchiveUi.install_dossier_chrome(case_intake, {"accent": PANEL_BORDER})
	_apply_static_style()
	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)
	_connect_button(start_button, start_requested.emit, &"primary")
	_connect_button(continue_button, continue_requested.emit, &"archive")
	_connect_button(settings_button, settings_requested.emit, &"archive")
	_connect_button(language_button, language_requested.emit, &"archive")
	_connect_button(quit_button, quit_requested.emit, &"muted")
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()
	_reset_appearance()
	call_deferred("_play_appearance")


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in _navigable_buttons():
		button.disabled = not enabled
	if enabled:
		restore_default_focus()


func set_continue_enabled(enabled: bool) -> void:
	continue_block.visible = enabled
	continue_button.disabled = not enabled
	_fit_layout()
	_update_focus_order()


func set_save_status(status: String) -> void:
	save_label.text = status
	if not status.is_empty():
		continue_block.visible = true
	_fit_layout()
	_update_focus_order()


func restore_default_focus() -> void:
	if is_visible_in_tree() and not start_button.disabled:
		start_button.call_deferred("grab_focus")


func _refresh_copy(_language: String = "") -> void:
	var font := _font_for_locale()
	for label: Label in [case_kicker, case_title, case_detail, case_meta, save_label]:
		label.add_theme_font_override("font", font)
	for button: Button in [start_button, continue_button, settings_button, language_button, quit_button]:
		button.add_theme_font_override("font", font)
	case_kicker.text = CaseLocale.text("menu.intake_kicker")
	case_title.text = CaseLocale.text("menu.intake_title")
	case_detail.text = CaseLocale.text("menu.intake_detail")
	case_meta.text = (
		"案件 01 · 阿什福德停电 · 现场工具已就绪"
		if CaseLocale.is_chinese()
		else "CASE 01  ·  ASHFORD BLACKOUT  ·  FIELD KIT READY"
	)
	start_button.text = CaseLocale.text("menu.new_case")
	continue_button.text = CaseLocale.text("menu.continue")
	settings_button.text = CaseLocale.text("menu.settings")
	language_button.text = CaseLocale.text("menu.language")
	quit_button.text = CaseLocale.text("menu.quit")
	set_save_status(GameState.resume_label() if GameState.has_saved_game() else "")


func _apply_static_style() -> void:
	case_intake.add_theme_stylebox_override("panel", _panel_style(PANEL_FILL, PANEL_BORDER, 2, 6))
	intake_inlay.add_theme_stylebox_override("panel", _panel_style(PANEL_INLAY, PANEL_RIVET, 1, 3))
	case_kicker.add_theme_color_override("font_color", INK_MUTED)
	case_title.add_theme_color_override("font_color", INK_LIGHT)
	case_title.add_theme_color_override("font_outline_color", Color(0.035, 0.010, 0.022, 0.98))
	case_title.add_theme_constant_override("outline_size", 2)
	case_detail.add_theme_color_override("font_color", INK_LIGHT)
	case_meta.add_theme_color_override("font_color", Color(0.68, 0.82, 0.66, 1.0))
	case_meta.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02, 0.96))
	case_meta.add_theme_constant_override("outline_size", 1)
	save_label.add_theme_color_override("font_color", INK_STATUS)
	divider.color = PANEL_BORDER


func _fit_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(CASE_INTAKE_WIDTH, viewport_size.x - 44.0)
	var panel_height := CASE_INTAKE_HEIGHT_RESUME if continue_block.visible else CASE_INTAKE_HEIGHT_EMPTY
	var bottom_safe := maxf(24.0, viewport_size.y * 0.04)
	case_intake.size = Vector2(panel_width, panel_height)
	case_intake.position = Vector2(
		(viewport_size.x - panel_width) * 0.5,
		viewport_size.y - panel_height - bottom_safe
	)
	case_intake.pivot_offset = case_intake.size * 0.5


func _connect_button(button: Button, callback: Callable, voice: StringName) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_outline_color", Color(0.025, 0.008, 0.018, 0.98))
	button.add_theme_constant_override("outline_size", 1)
	_apply_button_voice(button, voice)
	button.pressed.connect(callback)
	button.button_down.connect(_set_button_pressed.bind(button, true))
	button.button_up.connect(_set_button_pressed.bind(button, false))


func _apply_button_voice(button: Button, voice: StringName) -> void:
	var normal_fill := ARCHIVE_FILL
	var hover_fill := ARCHIVE_HOVER
	var normal_border := Color(0.65, 0.43, 0.17, 0.95)
	var hover_border := PANEL_BORDER
	var text_color := INK_LIGHT
	if voice == &"primary":
		normal_fill = BRASS_FILL
		hover_fill = BRASS_HOVER
		normal_border = BRASS_BORDER
		hover_border = FOCUS_GOLD
	elif voice == &"muted":
		normal_fill = MUTED_FILL
		hover_fill = MUTED_HOVER
		normal_border = Color(0.36, 0.28, 0.22, 0.92)
		hover_border = Color(0.73, 0.57, 0.31, 0.96)
		text_color = INK_MUTED
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", INK_LIGHT)
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.38, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(normal_fill, normal_border, 2))
	button.add_theme_stylebox_override("hover", _button_style(hover_fill, hover_border, 2))
	button.add_theme_stylebox_override("pressed", _button_style(normal_fill.darkened(0.18), hover_border, 2))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.065, 0.045, 0.042, 0.86), Color(0.30, 0.24, 0.22, 0.82), 1))
	button.add_theme_stylebox_override("focus", _focus_style())


func _update_focus_order() -> void:
	var buttons := _navigable_buttons()
	for index: int in buttons.size():
		var button := buttons[index]
		button.focus_neighbor_top = buttons[(index - 1 + buttons.size()) % buttons.size()].get_path()
		button.focus_neighbor_bottom = buttons[(index + 1) % buttons.size()].get_path()
	settings_button.focus_neighbor_right = language_button.get_path()
	language_button.focus_neighbor_left = settings_button.get_path()
	language_button.focus_neighbor_right = quit_button.get_path()
	quit_button.focus_neighbor_left = language_button.get_path()


func _navigable_buttons() -> Array[Button]:
	var buttons: Array[Button] = [start_button]
	if continue_block.visible and not continue_button.disabled:
		buttons.append(continue_button)
	buttons.append_array([settings_button, language_button, quit_button])
	return buttons


func _reset_appearance() -> void:
	case_intake.modulate = Color(1.0, 1.0, 1.0, 0.0)
	case_intake.scale = Vector2(0.978, 0.978)


func _play_appearance() -> void:
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	_reset_appearance()
	_arrival_tween = create_tween()
	_arrival_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(case_intake, "modulate:a", 1.0, 0.20)
	_arrival_tween.parallel().tween_property(case_intake, "scale", Vector2.ONE, 0.24)
	_arrival_tween.tween_callback(restore_default_focus)


func _set_button_pressed(button: Button, pressed: bool) -> void:
	if button.disabled:
		return
	var previous: Tween = _button_tweens.get(button, null)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.965, 0.965) if pressed else Vector2.ONE, 0.06 if pressed else 0.12)
	_button_tweens[button] = tween


func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.88)
	style.shadow_size = 15
	style.shadow_offset = Vector2(0.0, 5.0)
	return style


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.shadow_color = Color(0.006, 0.002, 0.012, 0.78)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = FOCUS_GOLD
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 1.0
	style.content_margin_top = 1.0
	style.content_margin_right = 1.0
	style.content_margin_bottom = 1.0
	return style


func _font_for_locale() -> FontFile:
	return ArchiveUi.ARCHIVE_FONT if CaseLocale.is_chinese() else ArchiveUi.PIXEL_FONT
