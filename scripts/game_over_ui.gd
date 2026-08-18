## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Macrostructure: Long Document / final case dossier. The original case-closed
## illustration carries the spectacle; this panel carries the actual finding,
## the unresolved-or-complete status, and one unambiguous next action.
extends Control

signal continue_requested
signal view_conclusion_requested
signal main_menu_requested

const DOSSIER_FILL := Color(0.042, 0.026, 0.023, 0.972)
const DOSSIER_INLAY := Color(0.087, 0.047, 0.032, 0.985)
const DOSSIER_BORDER := Color(0.70, 0.47, 0.17, 0.96)
const DOSSIER_RIVET := Color(0.15, 0.088, 0.052, 0.98)
const INK_LIGHT := Color(0.96, 0.87, 0.68, 1.0)
const INK_MUTED := Color(0.74, 0.64, 0.47, 1.0)
const INK_STATUS := Color(0.72, 0.85, 0.66, 1.0)
const VIOLET_SEAL := Color(0.35, 0.17, 0.56, 1.0)
const VIOLET_SEAL_HOVER := Color(0.48, 0.25, 0.73, 1.0)
const VIOLET_BORDER := Color(0.78, 0.64, 1.0, 1.0)
const ARCHIVE_FILL := Color(0.12, 0.071, 0.038, 0.98)
const ARCHIVE_HOVER := Color(0.19, 0.112, 0.054, 1.0)
const RETURN_FILL := Color(0.058, 0.042, 0.039, 0.94)
const RETURN_HOVER := Color(0.112, 0.078, 0.069, 0.98)
const FOCUS_GOLD := Color(1.0, 0.84, 0.43, 1.0)

var _true_case := false
var _arrival_tween: Tween
var _button_tweens: Dictionary = {}
var resolution_stamp: Panel
var atmosphere: ColorRect
var dossier_chrome: Control

@onready var artwork: TextureRect = $CaseClosedArtwork
@onready var veil: ColorRect = %Veil
@onready var case_dossier: Panel = %CaseDossier
@onready var dossier_inlay: Panel = %DossierInlay
@onready var record_mark: ColorRect = %RecordMark
@onready var record_kicker: Label = %RecordKicker
@onready var finding_title: Label = %FindingTitle
@onready var record_rule: ColorRect = %RecordRule
@onready var finding_summary: Label = %FindingSummary
@onready var record_status: Label = %RecordStatus
@onready var continue_button: Button = %ContinueButton
@onready var view_conclusion_button: Button = %ViewConclusionButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArchiveUi.drift_backdrop(artwork, {"zoom": 0.036, "period": 36.0})
	atmosphere = ArchiveUi.install_screen_atmosphere(self, {
		"lamp_anchor": Vector2(0.5, 0.22),
		"lamp_radius": 0.58,
		"vignette_strength": 0.50,
		"vignette_radius": 0.40,
		"mote_strength": 0.46,
	})
	dossier_chrome = ArchiveUi.install_dossier_chrome(case_dossier, {"accent": DOSSIER_BORDER})
	resolution_stamp = ArchiveUi.create_status_stamp(
		case_dossier,
		"ResolutionStamp",
		"ARCHIVE OPEN",
		ArchiveUi.ROLE_ARCANE
	)
	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)
	visibility_changed.connect(_on_visibility_changed)
	_apply_static_style()
	_connect_button(continue_button, continue_requested.emit, &"sealed")
	_connect_button(view_conclusion_button, view_conclusion_requested.emit, &"archive")
	_connect_button(main_menu_button, main_menu_requested.emit, &"return")
	continue_button.focus_neighbor_bottom = view_conclusion_button.get_path()
	view_conclusion_button.focus_neighbor_top = continue_button.get_path()
	view_conclusion_button.focus_neighbor_right = main_menu_button.get_path()
	main_menu_button.focus_neighbor_top = continue_button.get_path()
	main_menu_button.focus_neighbor_left = view_conclusion_button.get_path()
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()
	_reset_appearance()
	if visible:
		call_deferred("_play_appearance")


func show_true_case() -> void:
	_true_case = true
	_refresh_copy()


func show_ordinary_case() -> void:
	_true_case = false
	_refresh_copy()


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [continue_button, view_conclusion_button, main_menu_button]:
		button.disabled = not enabled


func _fit_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var dossier_width := clampf(viewport_size.x * 0.635, 500.0, 680.0)
	var dossier_height := clampf(viewport_size.y * 0.365, 258.0, 300.0)
	var bottom_safe := maxf(32.0, viewport_size.y * 0.05)
	case_dossier.size = Vector2(dossier_width, dossier_height)
	case_dossier.position = Vector2(
		(viewport_size.x - dossier_width) * 0.5,
		minf(viewport_size.y * 0.515, viewport_size.y - dossier_height - bottom_safe)
	)
	case_dossier.pivot_offset = case_dossier.size * 0.5

	var side := clampf(dossier_width * 0.052, 26.0, 36.0)
	var content_width := dossier_width - side * 2.0
	record_mark.position = Vector2(side, 20.0)
	record_kicker.position = Vector2(side + 15.0, 14.0)
	record_kicker.size = Vector2(content_width - 15.0, 23.0)
	finding_title.position = Vector2(side, 39.0)
	finding_title.size = Vector2(content_width, 32.0)
	record_rule.position = Vector2(side, 80.0)
	record_rule.size = Vector2(content_width, 1.0)
	finding_summary.position = Vector2(side, 91.0)
	finding_summary.size = Vector2(content_width, 40.0)
	record_status.position = Vector2(side, 137.0)
	record_status.size = Vector2(maxf(120.0, content_width - 172.0), 19.0)
	if resolution_stamp != null:
		resolution_stamp.position = Vector2(side + content_width - 158.0, 132.0)
		resolution_stamp.size = Vector2(158.0, 26.0)

	var primary_height := 42.0
	var secondary_height := 34.0
	var secondary_y := dossier_height - secondary_height - 18.0
	var primary_y := secondary_y - primary_height - 8.0
	continue_button.position = Vector2(side, primary_y)
	continue_button.size = Vector2(content_width, primary_height)
	var gutter := 12.0
	var secondary_width := (content_width - gutter) * 0.5
	view_conclusion_button.position = Vector2(side, secondary_y)
	view_conclusion_button.size = Vector2(secondary_width, secondary_height)
	main_menu_button.position = Vector2(side + secondary_width + gutter, secondary_y)
	main_menu_button.size = Vector2(secondary_width, secondary_height)
	for button: Button in [continue_button, view_conclusion_button, main_menu_button]:
		button.pivot_offset = button.size * 0.5


func _apply_static_style() -> void:
	case_dossier.add_theme_stylebox_override("panel", _panel_style(DOSSIER_FILL, DOSSIER_BORDER, 2, 6))
	dossier_inlay.add_theme_stylebox_override("panel", _panel_style(DOSSIER_INLAY, DOSSIER_RIVET, 1, 3))
	for label: Label in [record_kicker, finding_title, finding_summary, record_status]:
		label.add_theme_font_override("font", _font_for_locale())
	record_kicker.add_theme_color_override("font_color", INK_MUTED)
	finding_title.add_theme_color_override("font_color", INK_LIGHT)
	finding_title.add_theme_color_override("font_outline_color", Color(0.045, 0.012, 0.035, 0.98))
	finding_title.add_theme_constant_override("outline_size", 2)
	finding_summary.add_theme_color_override("font_color", INK_LIGHT)
	record_status.add_theme_color_override("font_color", INK_STATUS)
	record_rule.color = DOSSIER_BORDER


func _connect_button(button: Button, callback: Callable, voice: StringName) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_override("font", _font_for_locale())
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_outline_color", Color(0.025, 0.008, 0.018, 0.98))
	button.add_theme_constant_override("outline_size", 1)
	_apply_button_voice(button, voice)
	button.pressed.connect(callback)
	button.button_down.connect(_set_button_pressed.bind(button, true))
	button.button_up.connect(_set_button_pressed.bind(button, false))


func _apply_button_voice(button: Button, voice: StringName) -> void:
	var normal_fill := VIOLET_SEAL
	var hover_fill := VIOLET_SEAL_HOVER
	var normal_border := VIOLET_BORDER
	var hover_border := FOCUS_GOLD
	var text_color := Color(1.0, 0.94, 0.76, 1.0)
	if voice == &"archive":
		normal_fill = ARCHIVE_FILL
		hover_fill = ARCHIVE_HOVER
		normal_border = Color(0.65, 0.43, 0.17, 0.95)
		hover_border = DOSSIER_BORDER
	elif voice == &"return":
		normal_fill = RETURN_FILL
		hover_fill = RETURN_HOVER
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


func _refresh_copy(_language: String = "") -> void:
	var font := _font_for_locale()
	for label: Label in [record_kicker, finding_title, finding_summary, record_status]:
		label.add_theme_font_override("font", font)
	for button: Button in [continue_button, view_conclusion_button, main_menu_button]:
		button.add_theme_font_override("font", font)
	record_kicker.text = CaseLocale.text("ending.kicker_true" if _true_case else "ending.kicker_ordinary")
	finding_title.text = CaseLocale.text("ending.title_true" if _true_case else "ending.title_ordinary")
	finding_summary.text = CaseLocale.text("ending.summary_true" if _true_case else "ending.summary_ordinary")
	record_status.text = CaseLocale.text("ending.status_true" if _true_case else "ending.status_ordinary")
	ArchiveUi.set_status_stamp(
		resolution_stamp,
		(
			"真相档案" if CaseLocale.is_chinese() else "TRUE RECORD"
		) if _true_case else (
			"密封复查" if CaseLocale.is_chinese() else "SEALED REVIEW"
		),
		ArchiveUi.ROLE_ARCANE if _true_case else ArchiveUi.ROLE_ACTION
	)
	continue_button.text = CaseLocale.text("ending.true_continue" if _true_case else "ending.continue")
	view_conclusion_button.text = CaseLocale.text("ending.true_review" if _true_case else "ending.review")
	main_menu_button.text = CaseLocale.text("ending.main_menu")
	record_mark.color = VIOLET_SEAL if _true_case else DOSSIER_BORDER
	_apply_case_tone()


## The two endings are the same physical record filed under a different seal:
## brass lamplight for the sealed review, arcane violet for the true record.
func _apply_case_tone() -> void:
	var accent := VIOLET_BORDER if _true_case else DOSSIER_BORDER
	case_dossier.add_theme_stylebox_override("panel", _panel_style(DOSSIER_FILL, accent, 2, 6))
	record_rule.color = accent
	ArchiveUi.retint_dossier_chrome(dossier_chrome, accent)
	if atmosphere == null:
		return
	var material := atmosphere.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(
		"lamp_tint",
		Color(0.70, 0.53, 1.0, 1.0) if _true_case else Color(1.0, 0.76, 0.40, 1.0)
	)
	material.set_shader_parameter(
		"mote_tint",
		Color(0.85, 0.77, 1.0, 1.0) if _true_case else Color(1.0, 0.88, 0.58, 1.0)
	)
	material.set_shader_parameter("lamp_strength", 0.32 if _true_case else 0.24)


func _on_visibility_changed() -> void:
	if visible:
		call_deferred("_play_appearance")
	else:
		_reset_appearance()


func _reset_appearance() -> void:
	veil.modulate.a = 0.0
	case_dossier.modulate = Color(1.0, 1.0, 1.0, 0.0)
	case_dossier.scale = Vector2(0.978, 0.978)


func _play_appearance() -> void:
	if not visible:
		return
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	_reset_appearance()
	_arrival_tween = create_tween()
	_arrival_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(veil, "modulate:a", 1.0, 0.15)
	_arrival_tween.parallel().tween_property(case_dossier, "modulate:a", 1.0, 0.18)
	_arrival_tween.parallel().tween_property(case_dossier, "scale", Vector2.ONE, 0.20)
	_arrival_tween.tween_callback(continue_button.grab_focus)


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
