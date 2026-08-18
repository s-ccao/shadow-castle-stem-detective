extends Node

## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Genre: atmospheric. Tone: luxury-austere magical detective archive.
## Structural family: intake dossier · field-kit rail · physical workbench ·
## evidence wall · interruption report · sealed resolution record.
## ArchiveUi is the one visual Module for archive-facing screens. Its Interface
## is deliberately small: apply a semantic button/label and refresh a screen.
## The deeper Implementation owns generated brass mechanisms, type roles, focus
## visibility, and short mechanical feedback so callers never duplicate those decisions.

const PIXEL_FONT: FontFile = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
const ARCHIVE_FONT: FontFile = preload("res://assets/fonts/source-han-sans-sc-regular.otf")
const CASE_FRAME: Texture2D = preload("res://assets/ui/frames/menu_banner_frame.png")
const SCREEN_ATMOSPHERE_SHADER: Shader = preload("res://assets/ui/screen_atmosphere.gdshader")

const COLOR_GOLD := Color(0.98, 0.82, 0.45, 1.0)
const COLOR_PARCHMENT := Color(0.95, 0.88, 0.70, 1.0)
const COLOR_ARCANE := Color(0.84, 0.72, 1.0, 1.0)
# Violet remains reserved for Vision, final activation, and hazardous choices.
# Red is feedback-only (for example, a contradictory evidence connection), not a
# competing primary-button language.
const COLOR_DANGER := Color(0.84, 0.72, 1.0, 1.0)
const COLOR_DISABLED := Color(0.47, 0.44, 0.49, 0.88)
const COLOR_FOCUS := Color(0.94, 0.82, 0.44, 1.0)
const COLOR_SUCCESS := Color(0.68, 0.86, 0.62, 1.0)
const COLOR_VOID := Color(0.008, 0.006, 0.016, 0.96)
const COLOR_PANEL := Color(0.045, 0.026, 0.020, 0.985)
const COLOR_PANEL_INLAY := Color(0.090, 0.048, 0.028, 0.985)
const COLOR_BRASS := Color(0.78, 0.52, 0.18, 0.98)
const COLOR_VIOLET := Color(0.48, 0.27, 0.74, 1.0)

# Generated controls are for menus, archives and unpainted UI. When the room art
# already supplies a physical recess, that surface stays visible beneath a small
# interaction layer instead of receiving a second, generic button skin.
const BUTTON_ARCHIVE_FILL := Color(0.075, 0.043, 0.026, 0.98)
const BUTTON_ARCHIVE_BORDER := Color(0.50, 0.31, 0.13, 0.96)
const BUTTON_ACTION_FILL := Color(0.24, 0.115, 0.030, 0.99)
const BUTTON_ACTION_BORDER := Color(0.84, 0.58, 0.21, 0.98)
const BUTTON_ARCANE_FILL := Color(0.115, 0.045, 0.19, 0.99)
const BUTTON_ARCANE_BORDER := Color(0.57, 0.38, 0.86, 0.98)
const BUTTON_DANGER_FILL := Color(0.20, 0.043, 0.043, 0.99)
const BUTTON_DANGER_BORDER := Color(0.70, 0.26, 0.25, 0.98)
const BUTTON_MUTED_FILL := Color(0.042, 0.031, 0.031, 0.96)
const BUTTON_MUTED_BORDER := Color(0.29, 0.22, 0.18, 0.94)

const ROLE_ACTION := &"action"
const ROLE_ARCHIVE := &"archive"
const ROLE_ARCANE := &"arcane"
const ROLE_DANGER := &"danger"
const ROLE_MUTED := &"muted"

var _grabber_texture: Texture2D = null


func panel_style(
	fill: Color = COLOR_PANEL,
	border: Color = COLOR_BRASS,
	border_width: int = 2,
	radius: int = 6,
	shadow_size: int = 14
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.86)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 5.0)
	return style


func create_status_stamp(
	parent: Node,
	stamp_name: String,
	text: String,
	role: StringName = ROLE_ARCHIVE
) -> Panel:
	var stamp := Panel.new()
	stamp.name = stamp_name
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.set_meta("archive_ui_stamp_role", role)
	parent.add_child(stamp)
	var label := Label.new()
	label.name = "StampText"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_for_role(&"button"))
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(label)
	set_status_stamp(stamp, text, role)
	return stamp


func set_status_stamp(
	stamp: Panel,
	text: String,
	role: StringName = ROLE_ARCHIVE
) -> void:
	if stamp == null:
		return
	stamp.set_meta("archive_ui_stamp_role", role)
	var palette := _button_palette(role, &"default")
	var fill: Color = palette["fill"]
	var border: Color = palette["border"]
	var label := stamp.get_node_or_null("StampText") as Label
	stamp.add_theme_stylebox_override(
		"panel",
		panel_style(
			Color(fill.r, fill.g, fill.b, 0.96),
			border,
			1,
			3,
			3
		)
	)
	if label != null:
		label.text = text
		label.add_theme_font_override("font", _font_for_role(&"button"))
		label.add_theme_color_override("font_color", palette["text"] as Color)
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.02, 0.94))
		label.add_theme_constant_override("outline_size", 1)


func wire_focus_cycle(buttons: Array[Button]) -> void:
	var active: Array[Button] = []
	for button: Button in buttons:
		if button != null and button.visible and not button.disabled:
			active.append(button)
	if active.is_empty():
		return
	for index: int in range(active.size()):
		active[index].focus_neighbor_top = active[(index - 1 + active.size()) % active.size()].get_path()
		active[index].focus_neighbor_bottom = active[(index + 1) % active.size()].get_path()


func set_hub_entries_suppressed(suppressed: bool) -> void:
	if suppressed:
		var dismissal_methods: Dictionary = {
			"InventoryHud": "dismiss_feature_unlock",
			"KeyHud": "dismiss_unlock_toast",
			"NoteHud": "hide_feature_unlock",
			"ItemRewardHud": "dismiss_for_overlay",
		}
		for hud_name: String in dismissal_methods:
			var transient_hud := get_node_or_null("/root/" + hud_name)
			var method_name: String = str(dismissal_methods[hud_name])
			if transient_hud != null and transient_hud.has_method(method_name):
				transient_hud.call(method_name)
	for hub_name: String in ["InventoryHud", "KeyHud", "NoteHud", "MapHud"]:
		var hub := get_node_or_null("/root/" + hub_name)
		if hub != null and hub.has_method("set_entry_suppressed"):
			hub.call("set_entry_suppressed", suppressed)


func decorate_hub(frame: Control, config: Dictionary) -> Control:
	if frame == null:
		return Control.new()
	var existing := frame.get_node_or_null("ArchiveHubChrome") as Control
	if existing != null:
		return existing
	var chrome := Control.new()
	chrome.name = "ArchiveHubChrome"
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.z_index = int(config.get("z_index", 24))
	chrome.set_meta("hub_role", str(config.get("role", "archive")))
	chrome.set_meta("accent", config.get("accent", COLOR_BRASS) as Color)
	frame.add_child(chrome)

	for corner_id: String in ["TL", "TR", "BL", "BR"]:
		var bracket := Line2D.new()
		bracket.name = "HubCorner" + corner_id
		bracket.width = 2.0
		bracket.default_color = config.get("accent", COLOR_BRASS) as Color
		chrome.add_child(bracket)

	var rule := ColorRect.new()
	rule.name = "HubIdentityRule"
	rule.position = Vector2(float(config.get("rule_left", 24.0)), float(config.get("rule_y", 16.0)))
	rule.size = Vector2(maxf(8.0, frame.size.x - float(config.get("rule_left", 24.0)) - float(config.get("rule_right", 24.0))), 2.0)
	var accent := config.get("accent", COLOR_BRASS) as Color
	rule.color = Color(accent.r, accent.g, accent.b, 0.56)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(rule)

	var stamp_rect := config.get("stamp_rect", Rect2()) as Rect2
	if stamp_rect.size.x > 0.0:
		var stamp := create_status_stamp(
			chrome,
			"HubModeStamp",
			str(config.get("stamp", "FIELD ARCHIVE")),
			StringName(str(config.get("stamp_role", ROLE_ARCHIVE)))
		)
		stamp.position = stamp_rect.position
		stamp.size = stamp_rect.size

	var protocol_rect := config.get("protocol_rect", Rect2()) as Rect2
	if protocol_rect.size.x > 0.0:
		var protocol := Panel.new()
		protocol.name = "HubProtocolRail"
		protocol.position = protocol_rect.position
		protocol.size = protocol_rect.size
		protocol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		protocol.add_theme_stylebox_override(
			"panel",
			panel_style(
				Color(0.025, 0.018, 0.030, 0.90),
				Color(accent.r, accent.g, accent.b, 0.68),
				1,
				4,
				4
			)
		)
		chrome.add_child(protocol)
		var protocol_label := Label.new()
		protocol_label.name = "HubProtocolText"
		protocol_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		protocol_label.text = str(config.get("protocol", "1 · SELECT    2 · REVIEW    3 · ACT"))
		protocol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		protocol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		protocol_label.add_theme_font_override("font", PIXEL_FONT)
		protocol_label.add_theme_font_size_override("font_size", int(config.get("protocol_font_size", 9)))
		protocol_label.add_theme_color_override("font_color", COLOR_PARCHMENT)
		protocol_label.add_theme_color_override("font_outline_color", COLOR_VOID)
		protocol_label.add_theme_constant_override("outline_size", 2)
		protocol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		protocol.add_child(protocol_label)

	frame.resized.connect(_layout_hub_chrome.bind(frame, chrome))
	call_deferred("_layout_hub_chrome", frame, chrome)
	return chrome


func _layout_hub_chrome(frame: Control, chrome: Control) -> void:
	if frame == null or chrome == null or not is_instance_valid(chrome):
		return
	var length := 28.0
	var inset := 10.0
	var layouts: Dictionary = {
		"HubCornerTL": PackedVector2Array([Vector2(inset, inset + length), Vector2(inset, inset), Vector2(inset + length, inset)]),
		"HubCornerTR": PackedVector2Array([Vector2(frame.size.x - inset - length, inset), Vector2(frame.size.x - inset, inset), Vector2(frame.size.x - inset, inset + length)]),
		"HubCornerBL": PackedVector2Array([Vector2(inset, frame.size.y - inset - length), Vector2(inset, frame.size.y - inset), Vector2(inset + length, frame.size.y - inset)]),
		"HubCornerBR": PackedVector2Array([Vector2(frame.size.x - inset - length, frame.size.y - inset), Vector2(frame.size.x - inset, frame.size.y - inset), Vector2(frame.size.x - inset, frame.size.y - inset - length)]),
	}
	for bracket_name: String in layouts:
		var bracket := chrome.get_node_or_null(bracket_name) as Line2D
		if bracket != null:
			bracket.points = layouts[bracket_name] as PackedVector2Array
	var rule := chrome.get_node_or_null("HubIdentityRule") as ColorRect
	if rule != null:
		rule.size.x = maxf(8.0, frame.size.x - rule.position.x - 24.0)


## One lit-room pass for full-screen records. Callers describe a mood with a few
## scalars; the Module owns the vignette, the lamp flicker, the drifting dust and
## the emulsion grain so intake / interruption / resolution / archive never each
## invent a different overlay stack.
func install_screen_atmosphere(host: Control, config: Dictionary = {}) -> ColorRect:
	if host == null:
		return null
	var existing := host.get_node_or_null("ArchiveScreenAtmosphere") as ColorRect
	if existing != null:
		return existing
	var layer := ColorRect.new()
	layer.name = "ArchiveScreenAtmosphere"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.color = Color(1.0, 1.0, 1.0, 1.0)
	var material := ShaderMaterial.new()
	material.shader = SCREEN_ATMOSPHERE_SHADER
	for parameter_name: String in [
		"edge_tint",
		"lamp_tint",
		"mote_tint",
		"lamp_anchor",
		"vignette_strength",
		"vignette_radius",
		"lamp_strength",
		"lamp_radius",
		"mote_strength",
		"grain_strength",
		"unrest",
	]:
		if config.has(parameter_name):
			material.set_shader_parameter(parameter_name, config[parameter_name])
	layer.material = material
	host.add_child(layer)
	# The atmosphere belongs above the painted backdrop and below every veil,
	# dossier and control, so the room is lit but the reading surface is not.
	host.move_child(layer, clampi(int(config.get("layer_index", 1)), 0, host.get_child_count() - 1))
	layer.resized.connect(_sync_atmosphere_aspect.bind(layer))
	call_deferred("_sync_atmosphere_aspect", layer)
	return layer


func _sync_atmosphere_aspect(layer: ColorRect) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var material := layer.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("aspect", maxf(0.1, layer.size.x / maxf(1.0, layer.size.y)))


## Physical furniture for a record panel: brass corner brackets with rivets, a
## bound left spine and an inner hairline. The panel keeps owning its own copy
## and buttons; this only makes the surface read as an object on a desk.
func install_dossier_chrome(panel: Panel, config: Dictionary = {}) -> Control:
	if panel == null:
		return null
	var existing := panel.get_node_or_null("ArchiveDossierChrome") as Control
	if existing != null:
		return existing
	var accent: Color = config.get("accent", COLOR_BRASS)
	var chrome := Control.new()
	chrome.name = "ArchiveDossierChrome"
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.set_meta("archive_ui_chrome_accent", accent)
	panel.add_child(chrome)

	var hairline := Panel.new()
	hairline.name = "DossierHairline"
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hairline.add_theme_stylebox_override("panel", _hairline_style(accent))
	chrome.add_child(hairline)

	var spine := ColorRect.new()
	spine.name = "DossierSpine"
	spine.color = Color(accent.r, accent.g, accent.b, 0.40)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(spine)

	for stitch_index: int in range(5):
		var stitch := ColorRect.new()
		stitch.name = "DossierStitch%d" % stitch_index
		stitch.color = Color(accent.r, accent.g, accent.b, 0.84)
		stitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.add_child(stitch)

	for corner_id: String in ["TL", "TR", "BL", "BR"]:
		var bracket := Line2D.new()
		bracket.name = "DossierCorner" + corner_id
		bracket.width = 2.0
		bracket.default_color = accent
		bracket.joint_mode = Line2D.LINE_JOINT_SHARP
		chrome.add_child(bracket)
		var rivet := Panel.new()
		rivet.name = "DossierRivet" + corner_id
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rivet.add_theme_stylebox_override("panel", _rivet_style(accent))
		chrome.add_child(rivet)

	panel.resized.connect(_layout_dossier_chrome.bind(panel, chrome))
	call_deferred("_layout_dossier_chrome", panel, chrome)
	return chrome


func _layout_dossier_chrome(panel: Panel, chrome: Control) -> void:
	if panel == null or chrome == null or not is_instance_valid(chrome):
		return
	var width := panel.size.x
	var height := panel.size.y
	var inset := 7.0
	var arm := clampf(minf(width, height) * 0.075, 16.0, 26.0)
	var far_x := width - inset
	var far_y := height - inset
	var corners: Dictionary = {
		"TL": Vector2(inset, inset),
		"TR": Vector2(far_x, inset),
		"BL": Vector2(inset, far_y),
		"BR": Vector2(far_x, far_y),
	}
	var arms: Dictionary = {
		"TL": PackedVector2Array([Vector2(inset, inset + arm), Vector2(inset, inset), Vector2(inset + arm, inset)]),
		"TR": PackedVector2Array([Vector2(far_x - arm, inset), Vector2(far_x, inset), Vector2(far_x, inset + arm)]),
		"BL": PackedVector2Array([Vector2(inset, far_y - arm), Vector2(inset, far_y), Vector2(inset + arm, far_y)]),
		"BR": PackedVector2Array([Vector2(far_x - arm, far_y), Vector2(far_x, far_y), Vector2(far_x, far_y - arm)]),
	}
	for corner_id: String in corners:
		var bracket := chrome.get_node_or_null("DossierCorner" + corner_id) as Line2D
		if bracket != null:
			bracket.points = arms[corner_id] as PackedVector2Array
		var rivet := chrome.get_node_or_null("DossierRivet" + corner_id) as Panel
		if rivet != null:
			rivet.size = Vector2(6.0, 6.0)
			rivet.position = (corners[corner_id] as Vector2) - Vector2(3.0, 3.0)

	var hairline := chrome.get_node_or_null("DossierHairline") as Panel
	if hairline != null:
		hairline.position = Vector2(inset + 4.0, inset + 4.0)
		hairline.size = Vector2(
			maxf(8.0, width - (inset + 4.0) * 2.0),
			maxf(8.0, height - (inset + 4.0) * 2.0)
		)

	var spine_top := inset + arm + 8.0
	var spine_height := maxf(12.0, height - spine_top * 2.0)
	var spine := chrome.get_node_or_null("DossierSpine") as ColorRect
	if spine != null:
		spine.position = Vector2(inset - 3.0, spine_top)
		spine.size = Vector2(3.0, spine_height)
	for stitch_index: int in range(5):
		var stitch := chrome.get_node_or_null("DossierStitch%d" % stitch_index) as ColorRect
		if stitch == null:
			continue
		stitch.size = Vector2(8.0, 2.0)
		stitch.position = Vector2(
			inset - 5.5,
			spine_top + spine_height * (float(stitch_index) + 0.5) / 5.0 - 1.0
		)


## Endings change the accent of the same physical record rather than swapping in
## a different panel, so the resolution reads as one archive with two verdicts.
func retint_dossier_chrome(chrome: Control, accent: Color) -> void:
	if chrome == null or not is_instance_valid(chrome):
		return
	chrome.set_meta("archive_ui_chrome_accent", accent)
	for corner_id: String in ["TL", "TR", "BL", "BR"]:
		var bracket := chrome.get_node_or_null("DossierCorner" + corner_id) as Line2D
		if bracket != null:
			bracket.default_color = accent
		var rivet := chrome.get_node_or_null("DossierRivet" + corner_id) as Panel
		if rivet != null:
			rivet.add_theme_stylebox_override("panel", _rivet_style(accent))
	var hairline := chrome.get_node_or_null("DossierHairline") as Panel
	if hairline != null:
		hairline.add_theme_stylebox_override("panel", _hairline_style(accent))
	var spine := chrome.get_node_or_null("DossierSpine") as ColorRect
	if spine != null:
		spine.color = Color(accent.r, accent.g, accent.b, 0.40)
	for stitch_index: int in range(5):
		var stitch := chrome.get_node_or_null("DossierStitch%d" % stitch_index) as ColorRect
		if stitch != null:
			stitch.color = Color(accent.r, accent.g, accent.b, 0.84)


func _rivet_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.52 + 0.09, accent.g * 0.48 + 0.055, accent.b * 0.42 + 0.03, 1.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.94)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _hairline_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


## A painted backdrop that never moves reads as a menu screenshot. A very slow
## breath keeps the room alive without pulling attention off the record.
func drift_backdrop(artwork: Control, config: Dictionary = {}) -> void:
	if artwork == null or artwork.has_meta("archive_ui_drift"):
		return
	artwork.set_meta("archive_ui_drift", true)
	var zoom := absf(float(config.get("zoom", 0.045)))
	var period := maxf(6.0, float(config.get("period", 26.0)))
	_sync_backdrop_pivot(artwork)
	artwork.resized.connect(_sync_backdrop_pivot.bind(artwork))
	var drift := artwork.create_tween().set_loops()
	drift.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(artwork, "scale", Vector2.ONE * (1.0 + zoom), period * 0.5)
	drift.tween_property(artwork, "scale", Vector2.ONE, period * 0.5)


func _sync_backdrop_pivot(artwork: Control) -> void:
	if artwork != null and is_instance_valid(artwork):
		artwork.pivot_offset = artwork.size * 0.5


func apply_button(button: Button, role: StringName = ROLE_ACTION) -> void:
	button.set_meta("archive_ui_role", role)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_override("font", _font_for_role(&"button"))
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.01, 0.95))
	button.add_theme_constant_override("outline_size", 2)
	button.custom_minimum_size = button.custom_minimum_size.max(Vector2(44.0, 44.0))
	_apply_role(button, role)
	_connect_button_feedback(button)
	# Bound to the button's own signal rather than deferred: a deferred call that
	# still holds a freed button aborts with an argument-conversion error, which
	# any screen that rebuilds its controls would emit constantly.
	if not button.resized.is_connected(_center_button_pivot):
		button.resized.connect(_center_button_pivot.bind(button))
	_center_button_pivot(button)


## Faders are the one archive control that is dragged rather than pressed, so
## they need the same brass-on-walnut vocabulary as everything else or they read
## as an engine default dropped into the case file.
func apply_slider(slider: Slider) -> void:
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var groove := StyleBoxFlat.new()
	# Lifted off the dialog's own walnut rather than matched to it: an unfilled
	# groove that blends into the panel makes the fader look like it simply stops
	# at the current value instead of showing how much travel is left.
	groove.bg_color = Color(0.17, 0.12, 0.075, 0.96)
	groove.border_color = Color(0.42, 0.30, 0.14, 0.85)
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(3)
	groove.content_margin_top = 6.0
	groove.content_margin_bottom = 6.0
	slider.add_theme_stylebox_override("slider", groove)

	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(0.72, 0.52, 0.20, 0.92)
	filled.set_corner_radius_all(3)
	filled.content_margin_top = 6.0
	filled.content_margin_bottom = 6.0
	slider.add_theme_stylebox_override("grabber_area", filled)
	var filled_hover: StyleBoxFlat = filled.duplicate()
	filled_hover.bg_color = Color(0.92, 0.70, 0.30, 0.98)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled_hover)

	var grabber := _brass_grabber_texture()
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_icon_override("grabber_disabled", grabber)


func _brass_grabber_texture() -> Texture2D:
	if _grabber_texture != null:
		return _grabber_texture
	# Drawn once and shared: a small brass knob with a lit upper edge, matching
	# the rivets used on the dossier chrome.
	var size := 18
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre := Vector2(size, size) * 0.5 - Vector2(0.5, 0.5)
	var radius := float(size) * 0.5 - 1.0
	for y: int in range(size):
		for x: int in range(size):
			var offset := Vector2(float(x), float(y)) - centre
			var distance := offset.length()
			if distance > radius:
				continue
			var edge := clampf((radius - distance) / 1.6, 0.0, 1.0)
			var lift := clampf(0.5 - offset.y / (radius * 2.4), 0.0, 1.0)
			var body := Color(0.55, 0.38, 0.16).lerp(Color(0.98, 0.82, 0.44), lift)
			if distance > radius - 1.4:
				body = Color(0.30, 0.19, 0.07)
			image.set_pixel(x, y, Color(body.r, body.g, body.b, edge))
	_grabber_texture = ImageTexture.create_from_image(image)
	return _grabber_texture


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
	if root is Button and root.has_meta("archive_ui_role"):
		(root as Button).add_theme_font_override("font", _font_for_role(&"button"))
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


## A short in-world handoff for room changes. The layer lives under SceneTree.root,
## so it survives the scene swap at peak darkness and never exposes a one-frame cut.
func play_room_transition(
	on_midpoint: Callable,
	title_text: String,
	detail_text: String
) -> void:
	var layer := CanvasLayer.new()
	layer.name = "RoomTransition"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)

	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.006, 0.018, 0.97)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.modulate.a = 0.0
	layer.add_child(veil)

	var title := Label.new()
	title.text = title_text
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -230.0
	title.offset_top = -30.0
	title.offset_right = 230.0
	title.offset_bottom = 4.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	apply_label(title, &"title")
	title.modulate = Color(0.62, 0.82, 1.0, 0.0)
	layer.add_child(title)

	var detail := Label.new()
	detail.text = detail_text
	detail.set_anchors_preset(Control.PRESET_CENTER)
	detail.offset_left = -260.0
	detail.offset_top = 12.0
	detail.offset_right = 260.0
	detail.offset_bottom = 34.0
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 12)
	apply_label(detail, &"muted")
	detail.modulate.a = 0.0
	layer.add_child(detail)

	var transition := layer.create_tween()
	transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(veil, "modulate:a", 1.0, 0.16)
	transition.parallel().tween_property(title, "modulate:a", 1.0, 0.16)
	transition.parallel().tween_property(detail, "modulate:a", 1.0, 0.16)
	transition.tween_interval(0.16)
	transition.tween_callback(on_midpoint)
	transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition.tween_property(layer, "modulate:a", 0.0, 0.22)
	transition.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)


func _font_for_role(role: StringName) -> FontFile:
	if role == &"title" or not CaseLocale.is_chinese():
		return PIXEL_FONT
	return ARCHIVE_FONT


func _apply_role(button: Button, role: StringName) -> void:
	var status: StringName = button.get_meta("archive_ui_status", &"default")
	var palette := _button_palette(role, status)
	var text_color: Color = palette["text"]
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override("normal", _mechanism_style(role, status, &"normal"))
	button.add_theme_stylebox_override("hover", _mechanism_style(role, status, &"hover"))
	button.add_theme_stylebox_override("pressed", _mechanism_style(role, status, &"pressed"))
	button.add_theme_stylebox_override("disabled", _mechanism_style(role, status, &"disabled"))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.self_modulate = Color.WHITE if not button.disabled else Color(0.72, 0.72, 0.76, 0.72)


func _button_palette(role: StringName, status: StringName) -> Dictionary:
	var fill := BUTTON_ARCHIVE_FILL
	var border := BUTTON_ARCHIVE_BORDER
	var text_color := COLOR_PARCHMENT
	match role:
		ROLE_ACTION:
			fill = BUTTON_ACTION_FILL
			border = BUTTON_ACTION_BORDER
			text_color = COLOR_GOLD
		ROLE_ARCANE:
			fill = BUTTON_ARCANE_FILL
			border = BUTTON_ARCANE_BORDER
			text_color = COLOR_ARCANE
		ROLE_DANGER:
			fill = BUTTON_DANGER_FILL
			border = BUTTON_DANGER_BORDER
			text_color = COLOR_DANGER
		ROLE_MUTED:
			fill = BUTTON_MUTED_FILL
			border = BUTTON_MUTED_BORDER
			text_color = Color(0.74, 0.65, 0.53, 1.0)
	if status == &"loading":
		fill = BUTTON_ARCANE_FILL
		border = BUTTON_ARCANE_BORDER
		text_color = COLOR_ARCANE
	elif status == &"error":
		fill = BUTTON_DANGER_FILL
		border = BUTTON_DANGER_BORDER
		text_color = COLOR_DANGER
	elif status == &"success":
		fill = Color(0.085, 0.14, 0.085, 0.99)
		border = Color(0.49, 0.72, 0.40, 0.98)
		text_color = COLOR_SUCCESS
	return {"fill": fill, "border": border, "text": text_color}


func _mechanism_style(role: StringName, status: StringName, state: StringName) -> StyleBoxFlat:
	var palette := _button_palette(role, status)
	var fill: Color = palette["fill"]
	var border: Color = palette["border"]
	if state == &"hover":
		fill = fill.lightened(0.095)
		border = border.lightened(0.15)
	elif state == &"pressed":
		fill = fill.darkened(0.18)
		border = border.darkened(0.04)
	elif state == &"disabled":
		fill = Color(0.035, 0.028, 0.030, 0.90)
		border = Color(0.25, 0.22, 0.23, 0.88)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	# All states keep the same geometry so feedback reads as a metal mechanism
	# settling into place rather than a UI layout shifting under the player.
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0.006, 0.002, 0.008, 0.82 if state != &"disabled" else 0.36)
	style.shadow_size = 3 if state != &"pressed" else 1
	style.shadow_offset = Vector2(0.0, 2.0 if state != &"pressed" else 0.0)
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_FOCUS
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


func _connect_button_feedback(button: Button) -> void:
	if button.has_meta("archive_ui_feedback_connected"):
		return
	button.set_meta("archive_ui_feedback_connected", true)
	button.set_meta("archive_ui_base_scale", button.scale)
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.focus_entered.connect(_on_button_focus.bind(button))
	# Every archive-styled button in the game passes through here, so this is the
	# one place that has to know a press makes a sound. Wiring it per screen would
	# guarantee some screens were missed.
	button.pressed.connect(_on_button_sound.bind(button))


func _on_button_sound(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var role: StringName = button.get_meta("archive_ui_role", ROLE_ACTION)
	# Leaving or dismissing should not sound like committing to something.
	var retreating := role == ROLE_ARCHIVE or role == ROLE_MUTED
	GameAudio.play(&"ui_back" if retreating else &"ui_confirm")


func _center_button_pivot(button: Button) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _button_tween(button: Button, target_scale: Vector2, duration: float) -> void:
	var previous: Variant = button.get_meta("archive_ui_feedback_tween") if button.has_meta("archive_ui_feedback_tween") else null
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)
	button.set_meta("archive_ui_feedback_tween", tween)


func _on_button_down(button: Button) -> void:
	if button.disabled:
		return
	var base: Vector2 = button.get_meta("archive_ui_base_scale", Vector2.ONE)
	_button_tween(button, base * 0.965, 0.055)


func _on_button_up(button: Button) -> void:
	var base: Vector2 = button.get_meta("archive_ui_base_scale", Vector2.ONE)
	_button_tween(button, base, 0.11)


func _on_button_focus(button: Button) -> void:
	button.grab_click_focus()
