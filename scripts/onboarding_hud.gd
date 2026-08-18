## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Component: first-run field card. It stops at the two actions the player needs
## now; the full control ledger stays in Settings instead of overwhelming entry.
extends CanvasLayer

const PANEL_FILL := Color(0.043, 0.026, 0.018, 0.985)
const PANEL_INLAY := Color(0.086, 0.049, 0.025, 0.98)
const PANEL_BORDER := Color(0.75, 0.52, 0.20, 0.98)
const MUTED_INK := Color(0.73, 0.64, 0.47, 1.0)
const LIGHT_INK := Color(0.96, 0.88, 0.70, 1.0)

var overlay: Control
var veil: ColorRect
var field_card: Panel
var inlay: Panel
var field_kicker_label: Label
var title_label: Label
var intro_label: Label
var move_detail_label: Label
var inspect_detail_label: Label
var first_lead_label: Label
var first_lead_kicker_label: Label
var begin_button: Button
var move_keycaps: Array[Label] = []
var inspect_keycap: Label
var _arrival_tween: Tween
var _paused_before_open := false


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_overlay()
	CaseLocale.locale_changed.connect(_refresh_copy)
	PlayerPreferences.guidance_changed.connect(_on_guidance_changed)


func show_wake_orientation() -> void:
	if not PlayerPreferences.field_prompts_enabled:
		return
	if GameState.has_story_flag("wake_orientation_completed"):
		return
	if overlay.visible:
		return
	_refresh_copy()
	_paused_before_open = get_tree().paused
	get_tree().paused = true
	overlay.visible = true
	_reset_appearance()
	call_deferred("_play_appearance")


func _create_overlay() -> void:
	overlay = Control.new()
	overlay.name = "FieldOrientationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	veil = ColorRect.new()
	veil.name = "ArchiveVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.005, 0.016, 0.62)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(veil)

	field_card = Panel.new()
	field_card.name = "FieldOrientationCard"
	field_card.mouse_filter = Control.MOUSE_FILTER_STOP
	field_card.add_theme_stylebox_override("panel", _panel_style(PANEL_FILL, PANEL_BORDER, 2, 8))
	overlay.add_child(field_card)

	inlay = Panel.new()
	inlay.name = "FiledCardInlay"
	inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inlay.offset_left = 4.0
	inlay.offset_top = 4.0
	inlay.offset_right = -4.0
	inlay.offset_bottom = -4.0
	inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inlay.add_theme_stylebox_override("panel", _panel_style(PANEL_INLAY, Color(0.22, 0.13, 0.066, 0.96), 1, 5))
	field_card.add_child(inlay)

	field_kicker_label = _make_label("FieldGuideKicker", 10, MUTED_INK)
	field_kicker_label.position = Vector2(30.0, 22.0)
	field_kicker_label.size = Vector2(300.0, 18.0)
	field_card.add_child(field_kicker_label)

	title_label = _make_label("FieldGuideTitle", 28, LIGHT_INK)
	title_label.position = Vector2(30.0, 43.0)
	title_label.size = Vector2(350.0, 34.0)
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.012, 0.006, 0.96))
	title_label.add_theme_constant_override("outline_size", 2)
	field_card.add_child(title_label)

	var left_rule := ColorRect.new()
	left_rule.color = PANEL_BORDER
	left_rule.position = Vector2(30.0, 86.0)
	left_rule.size = Vector2(310.0, 1.0)
	left_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_card.add_child(left_rule)

	intro_label = _make_label("FieldGuideIntro", 15, LIGHT_INK)
	intro_label.position = Vector2(30.0, 98.0)
	intro_label.size = Vector2(310.0, 40.0)
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field_card.add_child(intro_label)

	var move_key_names: Array[String] = ["W", "A", "S", "D"]
	for index: int in move_key_names.size():
		var keycap := _make_keycap("MoveKey_%s" % move_key_names[index], move_key_names[index])
		keycap.position = Vector2(30.0 + index * 43.0, 150.0)
		field_card.add_child(keycap)
		move_keycaps.append(keycap)

	move_detail_label = _make_label("MoveDetail", 13, MUTED_INK)
	move_detail_label.position = Vector2(206.0, 151.0)
	move_detail_label.size = Vector2(134.0, 30.0)
	move_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field_card.add_child(move_detail_label)

	inspect_keycap = _make_keycap("InspectKey", "E")
	inspect_keycap.position = Vector2(30.0, 195.0)
	field_card.add_child(inspect_keycap)

	inspect_detail_label = _make_label("InspectDetail", 13, MUTED_INK)
	inspect_detail_label.position = Vector2(73.0, 197.0)
	inspect_detail_label.size = Vector2(267.0, 28.0)
	inspect_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field_card.add_child(inspect_detail_label)

	var separator := ColorRect.new()
	separator.color = Color(0.45, 0.29, 0.12, 0.86)
	separator.position = Vector2(370.0, 26.0)
	separator.size = Vector2(1.0, 202.0)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_card.add_child(separator)

	first_lead_kicker_label = _make_label("FirstLeadKicker", 10, MUTED_INK)
	first_lead_kicker_label.position = Vector2(402.0, 42.0)
	first_lead_kicker_label.size = Vector2(270.0, 18.0)
	field_card.add_child(first_lead_kicker_label)

	first_lead_label = _make_label("FirstLead", 18, LIGHT_INK)
	first_lead_label.position = Vector2(402.0, 71.0)
	first_lead_label.size = Vector2(264.0, 96.0)
	first_lead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first_lead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	field_card.add_child(first_lead_label)

	begin_button = Button.new()
	begin_button.name = "BeginSearchButton"
	begin_button.position = Vector2(402.0, 188.0)
	begin_button.size = Vector2(264.0, 42.0)
	begin_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	begin_button.focus_mode = Control.FOCUS_ALL
	begin_button.add_theme_font_size_override("font_size", 13)
	ArchiveUi.apply_button(begin_button, ArchiveUi.ROLE_ACTION)
	begin_button.pressed.connect(_complete_orientation)
	field_card.add_child(begin_button)

	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)


func _make_label(label_name: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _font_for_locale())
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_keycap(key_name: String, key_text: String) -> Label:
	var keycap := _make_label(key_name, 14, LIGHT_INK)
	keycap.text = key_text
	keycap.size = Vector2(34.0, 28.0)
	keycap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_theme_stylebox_override("normal", _keycap_style())
	return keycap


func _fit_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var card_size := Vector2(
		minf(744.0, viewport_size.x - 44.0),
		272.0
	)
	field_card.size = card_size
	field_card.position = Vector2(
		(viewport_size.x - card_size.x) * 0.5,
		clampf(viewport_size.y * 0.53, 164.0, viewport_size.y - card_size.y - 34.0)
	)
	field_card.pivot_offset = field_card.size * 0.5


func _refresh_copy(_language: String = "") -> void:
	var font := _font_for_locale()
	for label: Label in [field_kicker_label, title_label, intro_label, move_detail_label, inspect_detail_label, first_lead_kicker_label, first_lead_label]:
		if label != null:
			label.add_theme_font_override("font", font)
	for keycap: Label in move_keycaps:
		keycap.add_theme_font_override("font", font)
	if inspect_keycap != null:
		inspect_keycap.add_theme_font_override("font", font)
	field_kicker_label.text = CaseLocale.text("guide.field_kicker")
	title_label.text = CaseLocale.text("guide.field_title")
	intro_label.text = CaseLocale.text("guide.field_intro")
	move_detail_label.text = CaseLocale.text("guide.move_detail")
	inspect_detail_label.text = CaseLocale.text("guide.inspect_detail")
	first_lead_kicker_label.text = CaseLocale.text("guide.first_lead_kicker")
	first_lead_label.text = CaseLocale.text("guide.first_lead")
	if begin_button != null:
		begin_button.add_theme_font_override("font", font)
		begin_button.text = CaseLocale.text("guide.begin")


func _play_appearance() -> void:
	if not overlay.visible:
		return
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	_reset_appearance()
	_arrival_tween = create_tween()
	_arrival_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(veil, "modulate:a", 1.0, 0.14)
	_arrival_tween.parallel().tween_property(field_card, "modulate:a", 1.0, 0.16)
	_arrival_tween.parallel().tween_property(field_card, "scale", Vector2.ONE, 0.18)
	_arrival_tween.tween_callback(begin_button.grab_focus)


func _reset_appearance() -> void:
	veil.modulate.a = 0.0
	field_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	field_card.scale = Vector2(0.985, 0.985)


func _complete_orientation() -> void:
	GameState.set_story_flag("wake_orientation_completed")
	_close_orientation()


func _close_orientation() -> void:
	overlay.visible = false
	field_card.scale = Vector2.ONE
	# Never restore a captured `true`. If this opened while something else already
	# held the tree paused, handing that pause back strands the game with no panel
	# on screen to dismiss: the player can move nothing and interact with nothing.
	get_tree().paused = false
	_paused_before_open = false


func _on_guidance_changed(enabled: bool) -> void:
	if not enabled and overlay.visible:
		_close_orientation()


func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.88)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.075, 0.032, 1.0)
	style.border_color = Color(0.65, 0.43, 0.16, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _font_for_locale() -> FontFile:
	return ArchiveUi.ARCHIVE_FONT if CaseLocale.is_chinese() else ArchiveUi.PIXEL_FONT
