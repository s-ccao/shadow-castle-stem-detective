## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## A failed chase becomes a filed interruption report: evidence survives, the
## recovery action is unmistakable, and the player can resume without friction.
extends Control

signal retry_requested
signal checkpoint_requested
signal main_menu_requested

const PANEL_FILL := Color(0.055, 0.031, 0.020, 0.975)
const PANEL_INLAY := Color(0.105, 0.055, 0.026, 0.98)
const PANEL_BORDER := Color(0.72, 0.48, 0.17, 0.96)
const PANEL_RIVET := Color(0.17, 0.105, 0.056, 0.98)
const INK_LIGHT := Color(0.96, 0.86, 0.66, 1.0)
const INK_MUTED := Color(0.73, 0.63, 0.46, 1.0)
const INK_DANGER := Color(0.97, 0.54, 0.38, 1.0)
const ACTION_FILL := Color(0.27, 0.145, 0.046, 1.0)
const ACTION_HOVER := Color(0.40, 0.225, 0.066, 1.0)
const SECONDARY_FILL := Color(0.105, 0.056, 0.029, 0.98)
const SECONDARY_HOVER := Color(0.18, 0.100, 0.043, 1.0)
const RETURN_FILL := Color(0.064, 0.045, 0.039, 0.92)
const RETURN_HOVER := Color(0.118, 0.080, 0.070, 0.98)
const FOCUS_GOLD := Color(1.0, 0.84, 0.42, 1.0)

var _arrival_tween: Tween
var _button_tweens: Dictionary = {}
var _checkpoint_available := false
var _checkpoint_room_id := ""
var recovery_stamp: Panel

@onready var artwork: TextureRect = $DeathArtwork
@onready var veil: ColorRect = $Veil
@onready var case_file_panel: Panel = $CaseFilePanel
@onready var case_file_inlay: Panel = %CaseFileInlay
@onready var report_kicker: Label = %ReportKicker
@onready var reason_title: Label = %DeathReasonTitle
@onready var reason_body: Label = %DeathReasonBody
@onready var retention_line: Label = %RetentionLine
@onready var report_rule: ColorRect = %ReportRule
@onready var checkpoint_button: Button = %CheckpointButton
@onready var retry_button: Button = %RetryButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArchiveUi.drift_backdrop(artwork, {"zoom": 0.052, "period": 24.0})
	ArchiveUi.install_screen_atmosphere(self, {
		"lamp_anchor": Vector2(0.5, 0.24),
		"lamp_tint": Color(1.0, 0.62, 0.34, 1.0),
		"lamp_strength": 0.16,
		"lamp_radius": 0.42,
		"vignette_strength": 0.70,
		"vignette_radius": 0.28,
		"mote_strength": 0.30,
		"grain_strength": 0.042,
		"unrest": 0.85,
	})
	ArchiveUi.install_dossier_chrome(case_file_panel, {"accent": PANEL_BORDER})
	recovery_stamp = ArchiveUi.create_status_stamp(
		case_file_panel,
		"RecoveryStamp",
		"EVIDENCE SAFE",
		ArchiveUi.ROLE_ACTION
	)
	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)
	visibility_changed.connect(_on_visibility_changed)
	_apply_static_style()
	_connect_button(checkpoint_button, checkpoint_requested.emit, &"action")
	_connect_button(retry_button, retry_requested.emit, &"secondary")
	_connect_button(main_menu_button, main_menu_requested.emit, &"return")
	_update_recovery_layout()
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()
	_reset_appearance()
	if visible:
		call_deferred("_play_appearance")


func configure_recovery(checkpoint_available: bool, checkpoint_room_id: String = "") -> void:
	_checkpoint_available = checkpoint_available
	_checkpoint_room_id = checkpoint_room_id
	if not is_node_ready():
		return
	_update_recovery_layout()
	_refresh_copy()
	if visible:
		call_deferred("_focus_primary_action")


func _fit_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_width := clampf(viewport_size.x * 0.58, 460.0, 600.0)
	var panel_height := clampf(viewport_size.y * 0.355, 270.0, 326.0)
	var bottom_safe := maxf(32.0, viewport_size.y * 0.055)
	case_file_panel.size = Vector2(panel_width, panel_height)
	case_file_panel.position = Vector2(
		(viewport_size.x - panel_width) * 0.5,
		minf(viewport_size.y * 0.52, viewport_size.y - panel_height - bottom_safe)
	)
	case_file_panel.pivot_offset = case_file_panel.size * 0.5

	var side := clampf(panel_width * 0.054, 26.0, 34.0)
	var content_width := panel_width - side * 2.0
	$CaseFilePanel/StatusMark.position = Vector2(side, 21.0)
	report_kicker.position = Vector2(side + 14.0, 14.0)
	report_kicker.size = Vector2(content_width - 14.0, 24.0)
	reason_title.position = Vector2(side, 39.0)
	reason_title.size = Vector2(content_width, 35.0)
	report_rule.position = Vector2(side, 82.0)
	report_rule.size = Vector2(content_width, 1.0)
	reason_body.position = Vector2(side, 92.0)
	reason_body.size = Vector2(content_width, 35.0)
	retention_line.position = Vector2(side, 131.0)
	retention_line.size = Vector2(maxf(120.0, content_width - 172.0), 20.0)
	if recovery_stamp != null:
		recovery_stamp.position = Vector2(side + content_width - 158.0, 126.0)
		recovery_stamp.size = Vector2(158.0, 26.0)

	var primary_height := 44.0
	var secondary_height := 34.0
	var primary_y := panel_height - secondary_height - primary_height - 24.0
	var secondary_y := primary_y + primary_height + 8.0
	_layout_recovery_actions(side, content_width, primary_y, secondary_y, primary_height, secondary_height)


func _layout_recovery_actions(
	side: float,
	content_width: float,
	primary_y: float,
	secondary_y: float,
	primary_height: float,
	secondary_height: float
) -> void:
	checkpoint_button.visible = _checkpoint_available
	if _checkpoint_available:
		checkpoint_button.position = Vector2(side, primary_y)
		checkpoint_button.size = Vector2(content_width, primary_height)
		var gutter := 12.0
		var secondary_width := (content_width - gutter) * 0.5
		retry_button.position = Vector2(side, secondary_y)
		retry_button.size = Vector2(secondary_width, secondary_height)
		main_menu_button.position = Vector2(side + secondary_width + gutter, secondary_y)
		main_menu_button.size = Vector2(secondary_width, secondary_height)
	else:
		retry_button.position = Vector2(side, primary_y)
		retry_button.size = Vector2(content_width, primary_height)
		main_menu_button.position = Vector2(side, secondary_y)
		main_menu_button.size = Vector2(content_width, secondary_height)
	for button: Button in [checkpoint_button, retry_button, main_menu_button]:
		button.pivot_offset = button.size * 0.5


func _update_recovery_layout() -> void:
	checkpoint_button.visible = _checkpoint_available
	checkpoint_button.disabled = not _checkpoint_available
	_apply_button_voice(retry_button, &"secondary" if _checkpoint_available else &"action")
	if _checkpoint_available:
		checkpoint_button.focus_neighbor_bottom = retry_button.get_path()
		retry_button.focus_neighbor_top = checkpoint_button.get_path()
		retry_button.focus_neighbor_right = main_menu_button.get_path()
		main_menu_button.focus_neighbor_top = checkpoint_button.get_path()
		main_menu_button.focus_neighbor_left = retry_button.get_path()
	else:
		retry_button.focus_neighbor_top = main_menu_button.get_path()
		retry_button.focus_neighbor_bottom = main_menu_button.get_path()
		main_menu_button.focus_neighbor_top = retry_button.get_path()
		main_menu_button.focus_neighbor_bottom = retry_button.get_path()
		main_menu_button.focus_neighbor_left = retry_button.get_path()
		main_menu_button.focus_neighbor_right = retry_button.get_path()
	_fit_layout()


func _apply_static_style() -> void:
	case_file_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_FILL, PANEL_BORDER, 2, 7))
	case_file_inlay.add_theme_stylebox_override("panel", _panel_style(PANEL_INLAY, PANEL_RIVET, 1, 4))
	for label: Label in [report_kicker, reason_title, reason_body, retention_line]:
		label.add_theme_font_override("font", _font_for_locale())
	report_kicker.add_theme_color_override("font_color", INK_MUTED)
	reason_title.add_theme_color_override("font_color", INK_DANGER)
	reason_title.add_theme_color_override("font_outline_color", Color(0.08, 0.018, 0.012, 0.98))
	reason_title.add_theme_constant_override("outline_size", 2)
	reason_body.add_theme_color_override("font_color", INK_LIGHT)
	retention_line.add_theme_color_override("font_color", Color(0.72, 0.85, 0.62, 1.0))
	report_rule.color = PANEL_BORDER


func _connect_button(button: Button, callback: Callable, voice: StringName) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_override("font", _font_for_locale())
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.018, 0.006, 0.98))
	button.add_theme_constant_override("outline_size", 1)
	_apply_button_voice(button, voice)
	button.pressed.connect(callback)
	button.button_down.connect(_set_button_pressed.bind(button, true))
	button.button_up.connect(_set_button_pressed.bind(button, false))


func _apply_button_voice(button: Button, voice: StringName) -> void:
	var normal_fill := ACTION_FILL
	var hover_fill := ACTION_HOVER
	var normal_border := PANEL_BORDER
	var hover_border := FOCUS_GOLD
	var text_color := INK_LIGHT
	if voice == &"secondary":
		normal_fill = SECONDARY_FILL
		hover_fill = SECONDARY_HOVER
		normal_border = Color(0.54, 0.35, 0.15, 0.92)
		hover_border = PANEL_BORDER
	elif voice == &"return":
		normal_fill = RETURN_FILL
		hover_fill = RETURN_HOVER
		normal_border = Color(0.34, 0.27, 0.20, 0.88)
		hover_border = Color(0.70, 0.55, 0.29, 0.96)
		text_color = INK_MUTED
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", INK_LIGHT)
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.40, 0.35, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(normal_fill, normal_border, 2))
	button.add_theme_stylebox_override("hover", _button_style(hover_fill, hover_border, 2))
	button.add_theme_stylebox_override("pressed", _button_style(normal_fill.darkened(0.22), hover_border, 2))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.07, 0.05, 0.04, 0.85), Color(0.30, 0.25, 0.20, 0.82), 1))
	button.add_theme_stylebox_override("focus", _focus_style())


func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.006, 0.003, 0.008, 0.84)
	style.shadow_size = 14
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
	style.shadow_color = Color(0.006, 0.003, 0.008, 0.76)
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


func _refresh_copy(_language: String = "") -> void:
	var font := _font_for_locale()
	for label: Label in [report_kicker, reason_title, reason_body, retention_line]:
		label.add_theme_font_override("font", font)
	for button: Button in [checkpoint_button, retry_button, main_menu_button]:
		button.add_theme_font_override("font", font)
	report_kicker.text = CaseLocale.text("death.kicker")
	reason_title.text = CaseLocale.text("death.reason_title")
	reason_body.text = CaseLocale.text("death.reason_body")
	retention_line.text = (
		CaseLocale.text("death.retention_ready", {
			"room": CaseLocale.room_name(_checkpoint_room_id)
		})
		if _checkpoint_available
		else CaseLocale.text("death.retention_missing")
	)
	ArchiveUi.set_status_stamp(
		recovery_stamp,
		(
			"检查点可用" if CaseLocale.is_chinese() else "CHECKPOINT READY"
		) if _checkpoint_available else (
			"无检查点" if CaseLocale.is_chinese() else "NO CHECKPOINT"
		),
		ArchiveUi.ROLE_ACTION if _checkpoint_available else ArchiveUi.ROLE_MUTED
	)
	checkpoint_button.text = CaseLocale.text("death.retry_checkpoint")
	retry_button.text = CaseLocale.text("death.retry_room")
	main_menu_button.text = CaseLocale.text("death.main_menu")


func _on_visibility_changed() -> void:
	if visible:
		call_deferred("_play_appearance")
	else:
		_reset_appearance()


func _reset_appearance() -> void:
	veil.modulate.a = 0.0
	case_file_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	case_file_panel.scale = Vector2(0.982, 0.982)


func _play_appearance() -> void:
	if not visible:
		return
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	_reset_appearance()
	_arrival_tween = create_tween()
	_arrival_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(veil, "modulate:a", 1.0, 0.16)
	_arrival_tween.parallel().tween_property(case_file_panel, "modulate:a", 1.0, 0.16)
	_arrival_tween.parallel().tween_property(case_file_panel, "scale", Vector2.ONE, 0.18)
	_arrival_tween.tween_callback(_focus_primary_action)


func _focus_primary_action() -> void:
	(checkpoint_button if _checkpoint_available else retry_button).grab_focus()


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


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [checkpoint_button, retry_button, main_menu_button]:
		button.disabled = not enabled
