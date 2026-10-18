extends Button

const ENTRY_SIZE := Vector2(72, 106)
const ICON_RECT := Rect2(0, 6, 72, 76)
const TOOLS := {
	"bag": ["BAG", "背包", "Tab", "BagEntryLabel", "satchel"],
	"key": ["KEY", "钥匙", "I", "KeyHubLabel", "key"],
	"note": ["NOTE", "笔记", "K", "NoteHubLabel", "notebook"],
	"map": ["MAP", "地图", "U", "MapHubLabel", "map"],
}

var tool_id := ""
var title_label: Label
var _icon: TextureRect
var _shadow: TextureRect
var _edge: TextureRect
var _keycap: Label
var _motion: Tween
var _hovered := false
var _controller_down := false


func _ready() -> void:
	custom_minimum_size = ENTRY_SIZE
	size = ENTRY_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("hub_toolbar_entry", tool_id)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var artwork := load("res://assets/ui/tool_belt/%s.png" % TOOLS[tool_id][4]) as Texture2D
	_shadow = _create_artwork("ToolShadow", artwork)
	_shadow.position += Vector2(0, 3)
	_shadow.modulate = Color(0, 0, 0, 0.68)
	_icon = _create_artwork("ToolArtwork", artwork)
	_edge = TextureRect.new()
	_edge.name = "SilhouetteEdge"
	_edge.texture = load("res://assets/ui/tool_belt/%s_edge.png" % TOOLS[tool_id][4]) as Texture2D
	_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.size = ICON_RECT.size
	_edge.modulate.a = 0.0
	_icon.add_child(_edge)

	title_label = Label.new()
	title_label.name = TOOLS[tool_id][3]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_override("font", ArchiveUi.ARCHIVE_FONT)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", ArchiveUi.COLOR_PARCHMENT)
	title_label.add_theme_color_override("font_outline_color", Color("#100d14"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.position = Vector2(0, 84)
	add_child(title_label)

	_keycap = Label.new()
	_keycap.name = "ToolShortcut"
	_keycap.text = TOOLS[tool_id][2]
	_keycap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap.add_theme_font_override("font", ArchiveUi.PIXEL_FONT)
	_keycap.add_theme_font_size_override("font_size", 11)
	_keycap.add_theme_color_override("font_outline_color", Color("#100d14"))
	_keycap.add_theme_constant_override("outline_size", 3)
	add_child(_keycap)
	_keycap.position = Vector2(46, 86)
	_keycap.size = Vector2(24, 16)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_update_feedback)
	button_up.connect(_update_feedback)
	visibility_changed.connect(_on_visibility_changed)
	CaseLocale.locale_changed.connect(_refresh_locale)
	_refresh_locale("")
	_update_feedback()


func _create_artwork(node_name: String, artwork: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = artwork
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	image.position = ICON_RECT.position
	image.size = ICON_RECT.size
	return image


func _gui_input(event: InputEvent) -> void:
	# This project's ui_accept is keyboard-only; keep the A-button fallback local.
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		if disabled or (not event.pressed and not _controller_down):
			return
		_controller_down = event.pressed
		_update_feedback()
		if not event.pressed:
			pressed.emit()
		accept_event()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_node("/root/InventoryHud").call("toggle_bag")
		accept_event()


func _refresh_locale(_language: String) -> void:
	title_label.text = TOOLS[tool_id][1 if CaseLocale.is_chinese() else 0]
	title_label.size = Vector2(44, 20)
	tooltip_text = ""
	ArchiveUi.refresh_hub_preview.call_deferred()


func _on_hover(hovered: bool) -> void:
	_hovered = hovered
	_update_feedback()
	if hovered:
		ArchiveUi.refresh_hub_preview(self)


func _on_focus_entered() -> void:
	_update_feedback()
	ArchiveUi.refresh_hub_preview(self)


func _on_focus_exited() -> void:
	_controller_down = false
	_update_feedback()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_hovered = false
		_controller_down = false
		if _motion != null and _motion.is_valid():
			_motion.kill()
		_icon.position = ICON_RECT.position
		_icon.modulate = Color.WHITE
		_edge.modulate.a = 0.0
		_shadow.modulate.a = 0.68
	else:
		_update_feedback()
	ArchiveUi.refresh_hub_toolbar.call_deferred()
	ArchiveUi.refresh_hub_preview.call_deferred()


func _update_feedback() -> void:
	if _icon == null:
		return
	var active := is_visible_in_tree() and (_hovered or has_focus()) and not disabled
	var down := is_pressed() or _controller_down
	set_meta("toolbar_visual_state", "unavailable" if disabled else ("pressed" if down else ("active" if active else "ready")))
	_keycap.add_theme_color_override("font_color", Color("#756c61") if disabled else (Color("#ffe1a0") if active else Color("#baa98a")))
	title_label.add_theme_color_override("font_color", Color("#756c61") if disabled else (Color("#fff0cf") if active else ArchiveUi.COLOR_PARCHMENT))
	if _motion != null and _motion.is_valid():
		_motion.kill()
	if not is_visible_in_tree():
		return
	_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var offset := Vector2(0, 2 if down else (-5 if active else 0))
	var tint := Color("#645d64") if disabled else Color.WHITE
	_motion.tween_property(_icon, "position", ICON_RECT.position + offset, 0.12)
	_motion.parallel().tween_property(_icon, "modulate", tint, 0.12)
	_motion.parallel().tween_property(_edge, "modulate:a", 1.0 if active else 0.0, 0.12)
	_motion.parallel().tween_property(_shadow, "modulate:a", 0.85 if down else (0.42 if active else 0.68), 0.12)
	ArchiveUi.refresh_hub_preview.call_deferred()
