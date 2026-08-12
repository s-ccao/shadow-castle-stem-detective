extends Node

## Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
## ArchiveUi is the one visual Module for archive-facing screens. Its Interface
## is deliberately small: apply a semantic button/label and refresh a screen.
## The deeper Implementation owns textures, type roles, focus visibility, and
## short mechanical feedback so callers never duplicate those decisions.

const PIXEL_FONT: FontFile = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
const ARCHIVE_FONT: FontFile = preload("res://assets/fonts/source-han-sans-sc-regular.otf")
const BUTTON_NORMAL: Texture2D = preload("res://assets/ui/panels/button_states/button_normal.png")
const BUTTON_HOVER: Texture2D = preload("res://assets/ui/panels/button_states/button_hover.png")
const BUTTON_PRESSED: Texture2D = preload("res://assets/ui/panels/button_states/button_pressed.png")
const BUTTON_DISABLED: Texture2D = preload("res://assets/ui/panels/button_states/button_disabled.png")
const CASE_FRAME: Texture2D = preload("res://assets/ui/frames/menu_banner_frame.png")

const COLOR_GOLD := Color(0.98, 0.82, 0.45, 1.0)
const COLOR_PARCHMENT := Color(0.95, 0.88, 0.70, 1.0)
const COLOR_ARCANE := Color(0.84, 0.72, 1.0, 1.0)
# Violet remains reserved for Vision, final activation, and hazardous choices.
# Red is feedback-only (for example, a contradictory evidence connection), not a
# competing primary-button language.
const COLOR_DANGER := Color(0.84, 0.72, 1.0, 1.0)
const COLOR_DISABLED := Color(0.47, 0.44, 0.49, 0.88)
const COLOR_FOCUS := Color(0.94, 0.82, 0.44, 1.0)

const ROLE_ACTION := &"action"
const ROLE_ARCHIVE := &"archive"
const ROLE_ARCANE := &"arcane"
const ROLE_DANGER := &"danger"


func apply_button(button: Button, role: StringName = ROLE_ACTION) -> void:
	button.set_meta("archive_ui_role", role)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.01, 0.95))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", _texture_style(BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", _texture_style(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_PRESSED))
	button.add_theme_stylebox_override("disabled", _texture_style(BUTTON_DISABLED))
	button.add_theme_stylebox_override("focus", _focus_style())
	if button.pivot_offset == Vector2.ZERO:
		button.pivot_offset = button.size * 0.5
	button.custom_minimum_size = button.custom_minimum_size.max(Vector2(44.0, 44.0))
	_apply_role(button, role)
	_connect_button_feedback(button)


func apply_label(label: Label, role: StringName = &"body") -> void:
	label.set_meta("archive_ui_label_role", role)
	label.add_theme_font_override("font", _font_for_role(role))
	if role == &"title":
		label.add_theme_color_override("font_color", COLOR_GOLD)
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 0.95))
		label.add_theme_constant_override("outline_size", 2)
	elif role == &"muted":
		label.add_theme_color_override("font_color", Color(0.73, 0.67, 0.55, 1.0))
	else:
		label.add_theme_color_override("font_color", COLOR_PARCHMENT)


func refresh_tree(root: Node) -> void:
	if root is Label and root.has_meta("archive_ui_label_role"):
		apply_label(root as Label, root.get_meta("archive_ui_label_role") as StringName)
	for child: Node in root.get_children():
		refresh_tree(child)


func set_button_status(button: Button, status: StringName) -> void:
	button.set_meta("archive_ui_status", status)
	var role: StringName = button.get_meta("archive_ui_role", ROLE_ACTION)
	_apply_role(button, role)


func play_case_open_transition(host: Node, on_complete: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CaseOpenTransition"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)

	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.01, 0.025, 0.94)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.modulate.a = 0.0
	layer.add_child(veil)

	var frame := TextureRect.new()
	frame.texture = CASE_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.position = Vector2(262.0, 300.0)
	frame.size = Vector2(500.0, 156.0)
	frame.modulate.a = 0.0
	layer.add_child(frame)

	var title := Label.new()
	title.text = CaseLocale.text("menu.case_opened")
	title.position = Vector2(310.0, 336.0)
	title.size = Vector2(404.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	apply_label(title, &"title")
	title.modulate.a = 0.0
	layer.add_child(title)

	var detail := Label.new()
	detail.text = CaseLocale.text("menu.case_opened_detail")
	detail.position = Vector2(310.0, 378.0)
	detail.size = Vector2(404.0, 26.0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 13)
	apply_label(detail, &"body")
	detail.modulate.a = 0.0
	layer.add_child(detail)

	var transition := layer.create_tween()
	transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transition.tween_property(veil, "modulate:a", 1.0, 0.16)
	transition.parallel().tween_property(frame, "modulate:a", 1.0, 0.18)
	transition.parallel().tween_property(title, "modulate:a", 1.0, 0.18)
	transition.parallel().tween_property(detail, "modulate:a", 1.0, 0.18)
	transition.tween_interval(0.22)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	transition.tween_property(layer, "modulate:a", 0.0, 0.16)
	transition.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		on_complete.call()
	)


func _font_for_role(role: StringName) -> FontFile:
	if role == &"title" or not CaseLocale.is_chinese():
		return PIXEL_FONT
	return ARCHIVE_FONT


func _apply_role(button: Button, role: StringName) -> void:
	var status: StringName = button.get_meta("archive_ui_status", &"default")
	var color := COLOR_GOLD
	match role:
		ROLE_ARCHIVE:
			color = COLOR_PARCHMENT
		ROLE_ARCANE:
			color = COLOR_ARCANE
		ROLE_DANGER:
			color = COLOR_DANGER
	if status == &"error":
		color = COLOR_DANGER
	elif status == &"success":
		color = Color(0.68, 0.92, 0.66, 1.0)
	elif status == &"loading":
		color = COLOR_ARCANE
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.14))
	button.add_theme_color_override("font_pressed_color", color.darkened(0.10))
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	button.self_modulate = Color.WHITE if not button.disabled else Color(0.72, 0.72, 0.76, 0.72)


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 20.0
	style.texture_margin_right = 20.0
	style.texture_margin_top = 8.0
	style.texture_margin_bottom = 8.0
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_FOCUS
	style.set_border_width_all(2)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _connect_button_feedback(button: Button) -> void:
	if button.has_meta("archive_ui_feedback_connected"):
		return
	button.set_meta("archive_ui_feedback_connected", true)
	button.set_meta("archive_ui_base_scale", button.scale)
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.focus_entered.connect(_on_button_focus.bind(button))


func _on_button_down(button: Button) -> void:
	if button.disabled:
		return
	var base: Vector2 = button.get_meta("archive_ui_base_scale", Vector2.ONE)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", base * 0.98, 0.08)


func _on_button_up(button: Button) -> void:
	var base: Vector2 = button.get_meta("archive_ui_base_scale", Vector2.ONE)
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", base, 0.12)


func _on_button_focus(button: Button) -> void:
	button.grab_click_focus()
