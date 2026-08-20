extends CanvasLayer

## InventoryHud — 使用正式像素素材组装的 Bag Hub。
## BagHub 使用四份严格档案：ALL / POTIONS / MATERIALS / PAPERS。
## KeyHub 负责钥匙，NoteHud 负责线索与知识，三者保持独立。

const BAG_ICON_PATH: String = "res://assets/ui/inventory/bag_satchel_icon.png"
const BOARD_TEXTURE_PATH: String = "res://assets/ui/inventory/bag_inventory_board.png"
## 详情框 bag_detail_frame.png 的内腔，实测为设计坐标 x 568..799、y 200..456。
## 框里的标签原本一律是 526 起、316 宽，比内腔宽出 85px，于是无论中英文，
## 长一点的描述都会从装饰边框里戳出去。这两个常量把它们收回腔内并留 10px 余量。
const DETAIL_TEXT_X: float = 578.0
const DETAIL_TEXT_W: float = 211.0

const DETAIL_FRAME_PATH: String = "res://assets/ui/inventory/bag_detail_frame.png"
const SLOT_FRAME_A_PATH: String = "res://assets/ui/inventory/bag_square_frame_a.png"
const SLOT_FRAME_B_PATH: String = "res://assets/ui/inventory/bag_square_frame_b.png"

# 主板原图为 1536×1024，960×640 保持 1.5:1 比例，避免像素装饰变形。
const BOARD_POSITION: Vector2 = Vector2(32.0, 64.0)
const BOARD_SIZE: Vector2 = Vector2(960.0, 640.0)
const BOARD_SCALE: float = 0.625
const SLOT_SIZE: Vector2 = Vector2(54.0, 53.0)
const SLOT_CENTERS_X: Array[float] = [227.0, 325.0, 422.0, 520.0, 618.0, 716.0]
const SLOT_CENTERS_Y: Array[float] = [250.0, 345.0, 441.0, 536.0, 632.0]
# These are the four filing recesses painted into the 1536×1024 source board,
# converted to the 960×640 display frame. They are intentionally explicit:
# changing category count or using an auto-layout container would create a
# second grid that can drift away from the authored metal tabs.
const CATEGORY_BUTTON_RECTS: Array[Rect2] = [
	Rect2(127.0, 76.0, 102.0, 31.0),
	Rect2(235.0, 76.0, 102.0, 31.0),
	Rect2(343.0, 76.0, 102.0, 31.0),
	Rect2(451.0, 76.0, 102.0, 31.0),
]

const ENTRY_POSITION: Vector2 = Vector2(20.0, 14.0)
const ENTRY_SIZE: Vector2 = Vector2(64.0, 64.0)

var icon_button: TextureButton
var entry_backplate: Panel
var hover_halo: Panel
var hover_plate: Panel
var hover_label: Label
var entry_label: Label
var overlay: Control
var board_panel: Control
var slot_layer: Control
var detail_layer: Control
var detail_frame: TextureRect
var detail_icon_frame: TextureRect
var detail_icon_texture: TextureRect
var detail_icon_label: Label
var detail_title: Label
var detail_category: Label
var detail_description: Label
var detail_quantity: Label
var detail_requirements: Label
var detail_use_button: Button
var bottom_status: Label
var feature_panel: Panel
var feature_title: Label
var feature_description: Label
var feature_tween: Tween
var open_tween: Tween
var inspection_tween: Tween
var close_button: Button
var category_buttons: Dictionary = {}
var category_count_labels: Dictionary = {}
var category_grid: Control
var slot_nodes: Array[Control] = []
var entries: Array[Dictionary] = []
var active_category: String = "all"
var selected_index: int = -1
var _open: bool = false
var _hovered: bool = false
var _paused_before_bag: bool = false
var _had_inventory: bool = false
var _entry_suppressed: bool = false
var _pending_feature_unlock: bool = false


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_entry_button()
	_create_overlay()
	_create_feature_panel()
	_had_inventory = _has_stored_items()
	if not GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.connect(_on_game_state_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# B 键属于大厅证据板（evidence_board 映射），背包使用 Tab 避免冲突。
	if key_event.keycode == KEY_TAB and not _entry_suppressed:
		toggle_bag()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _open:
		close_bag()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _pending_feature_unlock and _can_show_feature_unlock():
		_pending_feature_unlock = false
		show_feature_unlock(
			"BAG HUB AWAKENED",
			"Your potions and materials are stored in the satchel. Click BAG or press Tab to open it."
		)


func _create_entry_button() -> void:
	entry_backplate = Panel.new()
	entry_backplate.name = "InventoryHubEntryBackplate"
	entry_backplate.position = Vector2(18.0, 10.0)
	entry_backplate.size = Vector2(72.0, 72.0)
	entry_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_backplate.z_index = -2
	var backplate_style: StyleBoxFlat = StyleBoxFlat.new()
	backplate_style.bg_color = Color(0.20, 0.12, 0.05, 0.90)
	backplate_style.border_color = Color(0.95, 0.72, 0.28, 0.96)
	backplate_style.set_border_width_all(1)
	backplate_style.set_corner_radius_all(44)
	backplate_style.shadow_color = Color(0.65, 0.35, 0.08, 0.34)
	backplate_style.shadow_size = 8
	entry_backplate.add_theme_stylebox_override("panel", backplate_style)
	add_child(entry_backplate)

	icon_button = TextureButton.new()
	icon_button.name = "InventoryHubEntry"
	icon_button.ignore_texture_size = true
	icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_button.texture_normal = load(BAG_ICON_PATH) as Texture2D
	icon_button.position = ENTRY_POSITION
	icon_button.size = ENTRY_SIZE
	icon_button.tooltip_text = "Case satchel  ·  Tab"
	icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_button.modulate = Color(1.0, 0.92, 0.70, 1.0)
	icon_button.mouse_entered.connect(_on_entry_mouse_entered)
	icon_button.mouse_exited.connect(_on_entry_mouse_exited)
	icon_button.pressed.connect(toggle_bag)
	add_child(icon_button)

	hover_halo = Panel.new()
	hover_halo.name = "BagHoverHalo"
	hover_halo.position = Vector2(16.0, 10.0)
	hover_halo.size = Vector2(76.0, 76.0)
	hover_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_halo.z_index = -1
	hover_halo.visible = false
	var halo_style: StyleBoxFlat = StyleBoxFlat.new()
	halo_style.bg_color = Color(0.32, 0.42, 0.78, 0.14)
	halo_style.border_color = Color(0.55, 0.68, 1.0, 0.62)
	halo_style.set_border_width_all(1)
	halo_style.set_corner_radius_all(46)
	halo_style.shadow_color = Color(0.30, 0.48, 1.0, 0.34)
	halo_style.shadow_size = 8
	hover_halo.add_theme_stylebox_override("panel", halo_style)
	add_child(hover_halo)

	hover_plate = Panel.new()
	hover_plate.name = "BagHoverPlate"
	hover_plate.position = Vector2(22.0, 82.0)
	hover_plate.size = Vector2(60.0, 24.0)
	hover_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_plate.visible = false
	var plate_style: StyleBoxFlat = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.035, 0.03, 0.055, 0.92)
	plate_style.border_color = Color(0.72, 0.58, 0.30, 0.76)
	plate_style.set_border_width_all(1)
	plate_style.set_corner_radius_all(5)
	hover_plate.add_theme_stylebox_override("panel", plate_style)
	add_child(hover_plate)

	hover_label = Label.new()
	hover_label.text = CaseLocale.line("SATCHEL")
	hover_label.position = Vector2(2.0, 1.0)
	hover_label.size = Vector2(56.0, 22.0)
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.add_theme_font_size_override("font_size", 12)
	hover_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72, 1.0))
	hover_label.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.05, 1.0))
	hover_label.add_theme_constant_override("outline_size", 2)
	hover_plate.add_child(hover_label)

	entry_label = Label.new()
	entry_label.name = "BagEntryLabel"
	entry_label.text = CaseLocale.line("BAG")
	entry_label.position = Vector2(22.0, 82.0)
	entry_label.size = Vector2(60.0, 20.0)
	entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_label.add_theme_font_size_override("font_size", 11)
	entry_label.add_theme_color_override("font_color", Color(0.98, 0.80, 0.38, 1.0))
	entry_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.01, 1.0))
	entry_label.add_theme_constant_override("outline_size", 3)
	add_child(entry_label)


func _set_hovered(is_over: bool) -> void:
	if _entry_suppressed:
		is_over = false
	_hovered = is_over
	hover_halo.visible = is_over
	hover_plate.visible = is_over
	var target_scale: Vector2 = Vector2(1.08, 1.08) if is_over else Vector2.ONE
	var target_color: Color = Color(1.0, 0.98, 0.84, 1.0) if is_over else Color(1.0, 0.92, 0.70, 1.0)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_button, "scale", target_scale, 0.12)
	tween.parallel().tween_property(icon_button, "modulate", target_color, 0.12)


func _on_entry_mouse_entered() -> void:
	_set_hovered(true)


func _on_entry_mouse_exited() -> void:
	_set_hovered(false)


func _create_overlay() -> void:
	overlay = Control.new()
	overlay.name = "InventoryHubOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.006, 0.018, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	ArchiveUi.install_screen_atmosphere(overlay, {
		"lamp_anchor": Vector2(0.50, 0.42),
		"lamp_strength": 0.19,
		"lamp_radius": 0.66,
		"vignette_strength": 0.62,
		"vignette_radius": 0.34,
		"mote_strength": 0.30,
		"grain_strength": 0.022,
	})

	board_panel = Control.new()
	board_panel.name = "InventoryBoard"
	board_panel.position = BOARD_POSITION
	board_panel.size = BOARD_SIZE
	board_panel.pivot_offset = BOARD_SIZE * 0.5
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(board_panel)

	var board_texture: TextureRect = TextureRect.new()
	board_texture.name = "InventoryBoardTexture"
	board_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_texture.texture = load(BOARD_TEXTURE_PATH) as Texture2D
	board_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_texture.stretch_mode = TextureRect.STRETCH_SCALE
	board_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_texture.set_meta("hub_artwork_fit", "full_frame")
	board_panel.add_child(board_texture)

	var title: Label = Label.new()
	title.name = "InventoryTitle"
	title.text = CaseLocale.line("CASE SATCHEL")
	title.position = Vector2(286.0, 16.0)
	title.size = Vector2(420.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "InventorySubtitle"
	subtitle.text = CaseLocale.line("FIELD ARCHIVE  ·  RECOVERED MATERIALS")
	subtitle.position = Vector2(286.0, 47.0)
	subtitle.size = Vector2(420.0, 16.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.66, 0.59, 0.45, 1.0))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(subtitle)

	close_button = Button.new()
	close_button.name = "InventoryHubCloseButton"
	close_button.text = "×"
	# × 提到 overlay 顶层（全局坐标），保证永远可点击。
	close_button.position = Vector2(904.0, 84.0)
	close_button.size = Vector2(42.0, 36.0)
	close_button.z_index = 20
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	close_button.pressed.connect(_on_close_button_pressed)
	overlay.add_child(close_button)

	_create_category_buttons()

	slot_layer = Control.new()
	slot_layer.name = "InventorySlotLayer"
	slot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(slot_layer)

	detail_layer = Control.new()
	detail_layer.name = "InventoryDetailLayer"
	detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(detail_layer)

	_create_detail_panel()
	_create_bottom_status()
	ArchiveUi.decorate_hub(board_panel, {
		"role": "satchel",
		"accent": Color(0.90, 0.62, 0.24, 0.92),
		"rule_y": 14.0,
		"stamp_rect": Rect2(52.0, 20.0, 212.0, 26.0),
		"stamp": CaseLocale.line("FIELD KIT · FOUR FILES"),
		"protocol_rect": Rect2(112.0, 598.0, 736.0, 24.0),
		"protocol": CaseLocale.line("1 · CHOOSE FILE    2 · INSPECT ITEM    3 · USE / OPEN"),
	})


func _create_category_buttons() -> void:
	var filing_label := Label.new()
	filing_label.name = "SatchelFilingLabel"
	filing_label.text = CaseLocale.line("CASE FILES")
	# The tab row owns this heading, so it sits directly above the first authored
	# recess instead of sharing a baseline with the centred case caption.
	filing_label.position = Vector2(127.0, 56.0)
	filing_label.size = Vector2(160.0, 16.0)
	filing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	filing_label.add_theme_font_size_override("font_size", 10)
	filing_label.add_theme_color_override("font_color", Color(0.67, 0.57, 0.38, 1.0))
	filing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(filing_label)
	category_grid = Control.new()
	category_grid.name = "SatchelCategoryGrid"
	category_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	category_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_grid.set_meta("fit_strategy", "four_authored_recesses")
	board_panel.add_child(category_grid)
	var categories: Array[Dictionary] = [
		{"id": "all", "text": "ALL"},
		{"id": "potions", "text": "POTIONS"},
		{"id": "materials", "text": "MATERIALS"},
		{"id": "papers", "text": "PAPERS"},
	]
	for category_index: int in range(categories.size()):
		var category: Dictionary = categories[category_index]
		var button: Button = Button.new()
		var category_id: String = str(category["id"])
		button.name = "Category_" + category_id
		button.text = CaseLocale.line(str(category["text"]))
		button.position = CATEGORY_BUTTON_RECTS[category_index].position
		button.size = CATEGORY_BUTTON_RECTS[category_index].size
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = false
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("base_label", CaseLocale.line(str(category["text"])))
		button.set_meta("authored_recess", CATEGORY_BUTTON_RECTS[category_index])
		button.add_theme_font_size_override("font_size", 10)
		if str(category["text"]).length() >= 9:
			button.add_theme_font_size_override("font_size", 9)
		button.add_theme_color_override("font_color", Color(0.78, 0.66, 0.42, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.60, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.72, 1.0))
		button.add_theme_stylebox_override("normal", _make_category_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
		button.add_theme_stylebox_override("hover", _make_category_style(Color(0.20, 0.10, 0.02, 0.30), Color(0.90, 0.68, 0.26, 0.74)))
		button.add_theme_stylebox_override("pressed", _make_category_style(Color(0.24, 0.12, 0.02, 0.42), Color(1.0, 0.78, 0.32, 0.88)))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", _make_category_style(Color(0.03, 0.02, 0.02, 0.28), Color(0.32, 0.26, 0.18, 0.45)))
		button.pressed.connect(_on_category_pressed.bind(category_id))
		category_buttons[category_id] = button
		category_grid.add_child(button)
		var count_label := Label.new()
		count_label.name = "CategoryCount"
		count_label.position = Vector2(80.0, 4.0)
		count_label.size = Vector2(17.0, 19.0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 9)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))
		count_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 1.0))
		count_label.add_theme_constant_override("outline_size", 2)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
		category_count_labels[category_id] = count_label


func _make_category_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_right = 19.0
	return style


func _create_detail_panel() -> void:
	detail_frame = TextureRect.new()
	detail_frame.name = "InventoryDetailFrame"
	detail_frame.position = Vector2(504.0, 120.0)
	detail_frame.size = Vector2(359.0, 420.0)
	detail_frame.texture = load(DETAIL_FRAME_PATH) as Texture2D
	detail_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_frame.stretch_mode = TextureRect.STRETCH_SCALE
	detail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_frame)

	detail_icon_frame = TextureRect.new()
	detail_icon_frame.name = "SelectedItemFrame"
	detail_icon_frame.position = Vector2(614.0, 150.0)
	detail_icon_frame.size = Vector2(140.0, 140.0)
	detail_icon_frame.texture = load(SLOT_FRAME_A_PATH) as Texture2D
	detail_icon_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_frame.stretch_mode = TextureRect.STRETCH_SCALE
	detail_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_icon_frame)

	detail_icon_texture = TextureRect.new()
	detail_icon_texture.name = "SelectedItemArtwork"
	detail_icon_texture.position = Vector2(626.0, 162.0)
	detail_icon_texture.size = Vector2(116.0, 116.0)
	detail_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_icon_texture.visible = false
	detail_layer.add_child(detail_icon_texture)

	detail_icon_label = Label.new()
	detail_icon_label.name = "SelectedItemGlyph"
	detail_icon_label.position = Vector2(649.0, 184.0)
	detail_icon_label.size = Vector2(70.0, 60.0)
	detail_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_icon_label.add_theme_font_size_override("font_size", 38)
	detail_icon_label.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	detail_icon_label.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 1.0))
	detail_icon_label.add_theme_constant_override("outline_size", 5)
	detail_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_icon_label)

	var inspection_label := Label.new()
	inspection_label.name = "InspectionLabel"
	inspection_label.text = CaseLocale.line("ITEM INSPECTION")
	inspection_label.position = Vector2(548.0, 128.0)
	inspection_label.size = Vector2(270.0, 18.0)
	inspection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspection_label.add_theme_font_size_override("font_size", 10)
	inspection_label.add_theme_color_override("font_color", Color(0.70, 0.61, 0.42, 1.0))
	inspection_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(inspection_label)

	detail_title = Label.new()
	detail_title.name = "SelectedItemTitle"
	detail_title.position = Vector2(DETAIL_TEXT_X, 286.0)
	detail_title.size = Vector2(DETAIL_TEXT_W, 40.0)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title.clip_text = true
	detail_title.add_theme_font_size_override("font_size", 16)
	detail_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42, 1.0))
	detail_title.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 1.0))
	detail_title.add_theme_constant_override("outline_size", 4)
	detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_title)

	detail_category = Label.new()
	detail_category.name = "SelectedItemCategory"
	detail_category.position = Vector2(DETAIL_TEXT_X, 328.0)
	detail_category.size = Vector2(DETAIL_TEXT_W, 16.0)
	detail_category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_category.clip_text = true
	detail_category.add_theme_font_size_override("font_size", 10)
	detail_category.add_theme_color_override("font_color", Color(0.70, 0.66, 0.56, 1.0))
	detail_category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_category)

	detail_description = Label.new()
	detail_description.name = "SelectedItemDescription"
	detail_description.position = Vector2(DETAIL_TEXT_X, 348.0)
	detail_description.size = Vector2(DETAIL_TEXT_W, 84.0)
	detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.clip_text = true
	detail_description.max_lines_visible = 6
	detail_description.add_theme_font_size_override("font_size", 11)
	detail_description.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68, 1.0))
	detail_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_description)

	detail_quantity = Label.new()
	detail_quantity.name = "SelectedItemQuantity"
	# The plaque painted into the board ends here; the count has to read as part
	# of the plaque, not as a line balanced on its lower edge.
	detail_quantity.position = Vector2(DETAIL_TEXT_X, 436.0)
	detail_quantity.size = Vector2(DETAIL_TEXT_W, 18.0)
	detail_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_quantity.add_theme_font_size_override("font_size", 10)
	detail_quantity.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	detail_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_quantity)

	detail_requirements = Label.new()
	detail_requirements.name = "SelectedItemRequirements"
	detail_requirements.position = Vector2(526.0, 478.0)
	detail_requirements.size = Vector2(316.0, 24.0)
	detail_requirements.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_requirements.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_requirements.clip_text = true
	detail_requirements.add_theme_font_size_override("font_size", 10)
	detail_requirements.add_theme_color_override("font_color", Color(0.78, 0.70, 0.54, 1.0))
	detail_requirements.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(detail_requirements)

	detail_use_button = Button.new()
	detail_use_button.name = "SelectedItemUseButton"
	detail_use_button.text = CaseLocale.line("USE")
	detail_use_button.position = Vector2(612.0, 508.0)
	detail_use_button.size = Vector2(144.0, 32.0)
	detail_use_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	detail_use_button.focus_mode = Control.FOCUS_ALL
	detail_use_button.add_theme_font_size_override("font_size", 13)
	detail_use_button.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42, 1.0))
	detail_use_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	detail_use_button.add_theme_stylebox_override("normal", _make_action_style(false))
	detail_use_button.add_theme_stylebox_override("hover", _make_action_style(true))
	detail_use_button.pressed.connect(_use_selected_item)
	detail_layer.add_child(detail_use_button)


func _make_action_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.20, 0.11, 0.025, 0.98)
		if is_hovered else Color(0.075, 0.040, 0.012, 0.94)
	)
	style.border_color = (
		Color(1.0, 0.78, 0.30, 1.0)
		if is_hovered else Color(0.72, 0.49, 0.16, 0.92)
	)
	style.set_border_width_all(2 if is_hovered else 1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.76, 0.42, 0.06, 0.22 if is_hovered else 0.10)
	style.shadow_size = 6 if is_hovered else 2
	return style


func _create_bottom_status() -> void:
	bottom_status = Label.new()
	bottom_status.name = "InventoryBottomStatus"
	bottom_status.position = Vector2(190.0, 550.0)
	bottom_status.size = Vector2(580.0, 32.0)
	bottom_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_status.add_theme_font_size_override("font_size", 12)
	bottom_status.add_theme_color_override("font_color", Color(0.74, 0.62, 0.40, 1.0))
	bottom_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(bottom_status)


func _create_feature_panel() -> void:
	feature_panel = Panel.new()
	feature_panel.name = "InventoryFeatureUnlock"
	feature_panel.position = Vector2(240.0, 0.0)
	feature_panel.size = Vector2(350.0, 88.0)
	feature_panel.visible = false
	feature_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feature_panel.z_index = 10
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.055, 0.96)
	style.border_color = Color(0.76, 0.59, 0.28, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.01, 0.005, 0.02, 0.55)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	feature_panel.add_theme_stylebox_override("panel", style)
	add_child(feature_panel)

	var pointer: Label = Label.new()
	pointer.text = "◀"
	pointer.position = Vector2(-18.0, 30.0)
	pointer.size = Vector2(22.0, 28.0)
	pointer.add_theme_font_size_override("font_size", 18)
	pointer.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	feature_panel.add_child(pointer)

	var content: VBoxContainer = VBoxContainer.new()
	content.position = Vector2(16.0, 8.0)
	content.size = Vector2(320.0, 72.0)
	content.add_theme_constant_override("separation", 3)
	feature_panel.add_child(content)

	feature_title = Label.new()
	feature_title.add_theme_font_size_override("font_size", 15)
	feature_title.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	content.add_child(feature_title)

	feature_description = Label.new()
	feature_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feature_description.add_theme_font_size_override("font_size", 13)
	feature_description.add_theme_color_override("font_color", Color(0.90, 0.86, 0.74, 1.0))
	content.add_child(feature_description)


func _on_game_state_changed() -> void:
	var has_inventory: bool = _has_stored_items()
	if has_inventory and not _had_inventory:
		if _can_show_feature_unlock():
			show_feature_unlock("BAG HUB AWAKENED", "Your potions and materials are stored in the satchel. Click BAG or press Tab to open it.")
		else:
			_pending_feature_unlock = true
	_had_inventory = has_inventory
	if _open:
		_rebuild_inventory()


func _can_show_feature_unlock() -> bool:
	if _open or _entry_suppressed:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return true
	var dialogue_state: Variant = scene.get("dialogue_active")
	if dialogue_state is bool and dialogue_state:
		return false
	var scene_message: Variant = scene.get("message_panel")
	if scene_message is CanvasItem and (scene_message as CanvasItem).visible:
		return false
	return true


func _has_stored_items() -> bool:
	return (
		not GameState.inventory_items.is_empty()
		or not GameState.recipe_items.is_empty()
		or not GameState.map_items.is_empty()
		or not GameState.herb_counts.is_empty()
		or not GameState.material_counts.is_empty()
		or not GameState.dish_counts.is_empty()
		or not GameState.final_key_fragments.is_empty()
	)


func show_feature_unlock(title_text: String, message_text: String, duration: float = 4.5) -> void:
	feature_title.text = title_text
	feature_description.text = message_text
	feature_panel.visible = true
	if feature_tween != null and feature_tween.is_valid():
		feature_tween.kill()
	feature_tween = create_tween()
	feature_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	feature_tween.set_loops(4)
	feature_tween.tween_property(icon_button, "scale", Vector2(1.10, 1.10), 0.36)
	feature_tween.tween_property(icon_button, "scale", Vector2.ONE, 0.36)
	var timer: SceneTreeTimer = get_tree().create_timer(duration, true)
	timer.timeout.connect(_hide_feature_unlock)


func _hide_feature_unlock() -> void:
	feature_panel.visible = false
	if feature_tween != null and feature_tween.is_valid():
		feature_tween.kill()
	feature_tween = null
	if icon_button != null:
		icon_button.scale = Vector2.ONE


func dismiss_feature_unlock() -> void:
	_hide_feature_unlock()


func toggle_bag() -> void:
	if _open:
		close_bag()
	else:
		open_bag()


func open_bag() -> void:
	_paused_before_bag = get_tree().paused
	get_tree().paused = true
	_open = true
	_hide_feature_unlock()
	ArchiveUi.set_hub_entries_suppressed(true)
	overlay.visible = true
	_rebuild_inventory()
	_animate_bag_open()
	call_deferred("_focus_selected_slot")


func close_bag() -> void:
	_open = false
	overlay.visible = false
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	board_panel.scale = Vector2.ONE
	overlay.modulate = Color.WHITE
	get_tree().paused = _paused_before_bag
	ArchiveUi.set_hub_entries_suppressed(false)


func set_entry_suppressed(suppressed: bool) -> void:
	_entry_suppressed = suppressed
	if entry_backplate != null:
		entry_backplate.visible = not suppressed
	if icon_button != null:
		icon_button.visible = not suppressed
	if entry_label != null:
		entry_label.visible = not suppressed
	if hover_halo != null:
		hover_halo.visible = not suppressed and _hovered
	if hover_plate != null:
		hover_plate.visible = not suppressed and _hovered


func _on_close_button_pressed() -> void:
	close_bag()
	get_viewport().set_input_as_handled()


func _on_category_pressed(category_id: String) -> void:
	active_category = category_id
	selected_index = 0
	_rebuild_inventory()
	_play_inspection_feedback()


func _rebuild_inventory() -> void:
	entries = _build_entries(active_category)
	if entries.is_empty():
		selected_index = -1
	else:
		if selected_index < 0 or selected_index >= entries.size():
			selected_index = 0
	_rebuild_slots()
	_update_category_visuals()
	_update_detail_panel()
	_update_bottom_status()


func _build_entries(category_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if category_id == "all" and GameState.developer_mode:
		_append_developer_entries(result)
	if category_id == "all" or category_id == "potions":
		var potion_counts: Dictionary = {}
		for potion_id: String in GameState.inventory_items:
			potion_counts[potion_id] = int(potion_counts.get(potion_id, 0)) + 1
		for potion_key: Variant in potion_counts.keys():
			var potion_id_text: String = str(potion_key)
			var potion_info: Dictionary = GameState.POTION_INFO.get(potion_id_text, {})
			result.append({
				"id": potion_id_text,
				"kind": "potion",
				"name": str(potion_info.get("name", potion_id_text)),
				"description": str(potion_info.get("description", "")),
				"quantity": _dev_quantity(int(potion_counts[potion_key])),
				"effect": str(potion_info.get("effect", "")),
				"duration": float(potion_info.get("duration", 10.0)),
				"requirements": "Consumable item"
			})

	if category_id == "all" or category_id == "materials":
		# Edible supplies are physical stock, not a separate filing system.
		for dish_key: Variant in GameState.dish_counts.keys():
			var dish_id: String = str(dish_key)
			var dish_count: int = GameState.get_dish_count(dish_id)
			if dish_count <= 0:
				continue
			var dish_info: Dictionary = GameState.DISH_INFO.get(dish_id, {})
			result.append({
				"id": dish_id,
				"kind": "dish",
				"name": str(dish_info.get("name", dish_id)),
				"description": str(dish_info.get("description", "")),
				"quantity": _dev_quantity(dish_count),
				"requirements": "Kitchen dish"
			})

	if category_id == "all" or category_id == "papers":
		for recipe_id: String in GameState.recipe_items:
			var recipe_info: Dictionary = GameState.RECIPE_INFO.get(recipe_id, {})
			result.append({
				"id": recipe_id,
				"kind": "recipe",
				"name": str(recipe_info.get("name", recipe_id)),
				"description": str(recipe_info.get("description", "")),
				"quantity": _dev_quantity(1),
				"requirements": "Recipe blueprint"
			})

	if category_id == "all" or category_id == "materials":
		for herb_key: Variant in GameState.herb_counts.keys():
			var herb_id: String = str(herb_key)
			var herb_count: int = GameState.get_herb_count(herb_id)
			if herb_count <= 0:
				continue
			var herb_info: Dictionary = GameState.HERB_INFO.get(herb_id, {})
			result.append({
				"id": herb_id,
				"kind": "herb",
				"name": str(herb_info.get("name", herb_id)),
				"description": str(herb_info.get("description", "")),
				"quantity": _dev_quantity(herb_count),
				"requirements": "Greenhouse material"
			})

	if category_id == "all" or category_id == "materials":
		for material_key: Variant in GameState.material_counts.keys():
			var material_id: String = str(material_key)
			var material_count: int = GameState.get_material_count(material_id)
			if material_count <= 0:
				continue
			var material_info: Dictionary = GameState.MATERIAL_INFO.get(material_id, {})
			result.append({
				"id": material_id,
				"kind": "material",
				"name": str(material_info.get("name", material_id)),
				"description": str(material_info.get("description", "")),
				"quantity": _dev_quantity(material_count),
				"requirements": "Circuit Room material"
			})

	if category_id == "all" or category_id == "papers":
		for map_id: String in GameState.map_items:
			if map_id == GameState.DR_LIN_PARTIAL_HALL_MAP_ID:
				result.append({
					"id": map_id,
					"kind": "map",
					"name": "Dr. Lin's Partial Hall Map",
					"description": "A hand-drawn fragment from Dr. Lin's desk. It shows only the Wake Room and the hall paths you personally uncover.",
					"quantity": _dev_quantity(1),
					"requirements": "Open in Castle Hall to track explored routes"
				})
			elif map_id == "circuit_repair_map":
				result.append({
					"id": map_id,
					"kind": "map",
					"name": "Circuit Repair Map",
					"description": "A hand-drawn map marking the three Circuit Room switches and their repair order.",
					"quantity": _dev_quantity(1),
					"requirements": "Use to locate the Circuit Room switches"
				})

	if (category_id == "all" or category_id == "materials") and not GameState.has_key("final_room_key"):
		for fragment_index: int in GameState.final_key_fragments:
			result.append({
				"id": "final_key_fragment_%d" % fragment_index,
				"kind": "fragment",
				"name": "Final Room Key Fragment (%d/4)" % fragment_index,
				"description": "A torn piece of the Final Room Key. Four fragments must be found: three in the hall machines and one behind the service maintenance panel.",
				"quantity": _dev_quantity(1),
				"requirements": "Key fragment from a hall machine or service panel"
			})
	return result


func _dev_quantity(value: int) -> int:
	return -1 if GameState.developer_mode else value


func _append_developer_entries(result: Array[Dictionary]) -> void:
	var key_names: Dictionary = {
		"wake_room_key": "Wake Room Key",
		"chemistry_room_key": "Chemistry Room Key",
		"greenhouse_room_key": "Greenhouse Room Key",
		"circuit_room_key": "Circuit Room Key",
		"service_corridor_key": "Service Corridor Key",
		"final_room_key": "Final Room Key",
		"dining_hall_key": "Dining Hall Key",
		"library_room_key": "Library Room Key",
	}
	for key_id: String in GameState.DEV_KEY_IDS:
		result.append({
			"id": key_id,
			"kind": "key",
			"name": str(key_names.get(key_id, key_id)),
			"description": "Developer mode key. Available for testing every locked route.",
			"quantity": -1,
			"requirements": "Developer inventory",
		})
	var evidence_names: Dictionary = {
		"fake_red_stain": "Evidence: Fake Red Stain",
		"greenhouse_pollen": "Evidence: Greenhouse Pollen",
		"deliberate_short_circuit": "Evidence: Deliberate Short Circuit",
		"dining_timeline": "Evidence: Last Dinner Timeline",
		"stopped_midnight_clock": "Evidence: Stopped Clock",
		"dining_red_cloth": "Evidence: Torn Service Cloth",
	}
	for evidence_id: String in GameState.DEV_EVIDENCE_IDS:
		result.append({
			"id": evidence_id,
			"kind": "evidence",
			"name": str(evidence_names.get(evidence_id, evidence_id)),
			"description": "Developer mode evidence entry for testing investigations.",
			"quantity": -1,
			"requirements": "Developer inventory",
		})


func _rebuild_slots() -> void:
	for old_slot: Control in slot_nodes:
		old_slot.queue_free()
	slot_nodes.clear()
	for i: int in range(entries.size()):
		if i >= 30:
			break
		var row: int = int(i / 6)
		var column: int = i % 6
		var center: Vector2 = Vector2(SLOT_CENTERS_X[column] * BOARD_SCALE, SLOT_CENTERS_Y[row] * BOARD_SCALE)
		var slot: Control = _create_slot(i, center)
		slot_layer.add_child(slot)
		slot_nodes.append(slot)


func _create_slot(entry_index: int, center: Vector2) -> Control:
	var slot: Control = Control.new()
	slot.name = "InventorySlot_%02d" % entry_index
	slot.position = center - SLOT_SIZE * 0.5
	slot.size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_PASS

	var frame: TextureRect = TextureRect.new()
	frame.name = "SlotFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = load(SLOT_FRAME_B_PATH if entry_index == selected_index else SLOT_FRAME_A_PATH) as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1.0, 0.86, 0.55, 0.76)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)

	var entry: Dictionary = entries[entry_index]
	var icon_path: String = _item_icon_path(entry)
	if not icon_path.is_empty():
		var accent := GameState.get_item_accent(str(entry.get("id", "")))
		var model_plate := Panel.new()
		model_plate.name = "ItemModelPlate"
		model_plate.position = Vector2(4.0, 2.0)
		model_plate.size = Vector2(46.0, 45.0)
		model_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plate_style := StyleBoxFlat.new()
		plate_style.bg_color = Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.88)
		plate_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
		plate_style.set_border_width_all(1)
		plate_style.set_corner_radius_all(6)
		model_plate.add_theme_stylebox_override("panel", plate_style)
		slot.add_child(model_plate)

		var artwork: TextureRect = TextureRect.new()
		artwork.name = "ItemArtwork"
		artwork.position = Vector2(7.0, 4.0)
		artwork.size = Vector2(40.0, 40.0)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		artwork.texture = load(icon_path) as Texture2D
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.z_index = 2
		slot.add_child(artwork)
	var glyph: Label = Label.new()
	glyph.name = "ItemGlyph"
	glyph.text = _kind_glyph(str(entry["kind"]))
	glyph.position = Vector2(7.0, 2.0)
	glyph.size = Vector2(40.0, 40.0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 25)
	glyph.add_theme_color_override("font_color", _kind_color(str(entry["kind"])))
	glyph.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 1.0))
	glyph.add_theme_constant_override("outline_size", 4)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.visible = icon_path.is_empty()
	slot.add_child(glyph)

	var quantity: Label = Label.new()
	quantity.name = "ItemQuantity"
	quantity.text = "∞" if int(entry["quantity"]) < 0 else "×" + str(entry["quantity"])
	quantity.position = Vector2(26.0, 36.0)
	quantity.size = Vector2(25.0, 14.0)
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.add_theme_font_size_override("font_size", 10)
	quantity.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))
	quantity.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	quantity.add_theme_constant_override("outline_size", 3)
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(quantity)

	var hit_button: Button = Button.new()
	hit_button.name = "SlotButton"
	hit_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_button.flat = true
	hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit_button.focus_mode = Control.FOCUS_ALL
	hit_button.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
	hit_button.mouse_exited.connect(_on_slot_mouse_exited.bind(slot, entry_index))
	hit_button.pressed.connect(_on_slot_pressed.bind(entry_index))
	hit_button.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(hit_button)
	return slot


func _on_slot_mouse_entered(slot: Control) -> void:
	var frame: TextureRect = slot.get_node_or_null("SlotFrame") as TextureRect
	if frame != null:
		frame.modulate = Color(1.0, 0.96, 0.72, 1.0)


func _on_slot_mouse_exited(slot: Control, entry_index: int) -> void:
	var frame: TextureRect = slot.get_node_or_null("SlotFrame") as TextureRect
	if frame != null:
		frame.modulate = (
			Color(1.0, 0.94, 0.68, 1.0)
			if entry_index == selected_index else Color(1.0, 0.86, 0.55, 0.76)
		)


func _on_slot_pressed(entry_index: int) -> void:
	selected_index = entry_index
	_rebuild_slots()
	_update_detail_panel()
	_play_inspection_feedback()


func _item_icon_path(entry: Dictionary) -> String:
	var item_id: String = str(entry.get("id", ""))
	return GameState.get_item_texture_path(item_id)


func _kind_glyph(kind: String) -> String:
	match kind:
		"key":
			return "⚿"
		"evidence":
			return "✧"
		"potion":
			return "✦"
		"dish":
			return "☕"
		"recipe":
			return "▤"
		"herb":
			return "❧"
		"material":
			return "◆"
		"map":
			return "▧"
		"fragment":
			return "⚿"
	return "•"


func _kind_color(kind: String) -> Color:
	match kind:
		"key":
			return Color(0.96, 0.76, 0.28, 1.0)
		"evidence":
			return Color(0.82, 0.72, 0.94, 1.0)
		"potion":
			return Color(0.74, 0.42, 0.96, 1.0)
		"dish":
			return Color(0.93, 0.62, 0.30, 1.0)
		"recipe":
			return Color(0.95, 0.78, 0.36, 1.0)
		"herb":
			return Color(0.46, 0.82, 0.54, 1.0)
		"material":
			return Color(0.74, 0.68, 0.42, 1.0)
		"fragment":
			return Color(0.95, 0.78, 0.36, 1.0)
	return Color.WHITE


func _update_category_visuals() -> void:
	for category_id: Variant in category_buttons.keys():
		var button: Button = category_buttons[category_id] as Button
		var is_active: bool = str(category_id) == active_category
		var base_label: String = str(button.get_meta("base_label", button.text))
		var entry_count: int = _build_entries(str(category_id)).size()
		button.text = base_label
		var count_label := category_count_labels.get(category_id) as Label
		if count_label != null:
			count_label.text = str(entry_count)
			count_label.add_theme_color_override(
				"font_color",
				Color(1.0, 0.94, 0.70, 1.0) if is_active else Color(0.78, 0.66, 0.42, 1.0)
			)
		button.modulate = Color.WHITE
		button.add_theme_stylebox_override(
			"normal",
			_make_category_style(
				Color(0.28, 0.14, 0.025, 0.40) if is_active else Color(0.0, 0.0, 0.0, 0.0),
				Color(1.0, 0.74, 0.26, 0.78) if is_active else Color(0.0, 0.0, 0.0, 0.0)
			)
		)
		button.add_theme_color_override(
			"font_color",
			Color(1.0, 0.87, 0.58, 1.0) if is_active else Color(0.78, 0.66, 0.42, 1.0)
		)


func _update_detail_panel() -> void:
	if selected_index < 0 or selected_index >= entries.size():
		detail_icon_texture.visible = false
		detail_icon_label.text = "—"
		detail_title.text = CaseLocale.line("Select an item")
		detail_category.text = CaseLocale.line("EMPTY SATCHEL SLOT")
		detail_description.text = CaseLocale.line(
			"Choose a potion, material, or paper to inspect its details."
		)
		detail_quantity.text = ""
		detail_requirements.text = ""
		detail_use_button.visible = false
		detail_use_button.text = CaseLocale.line("USE")
		return

	var entry: Dictionary = entries[selected_index]
	var kind: String = str(entry["kind"])
	var icon_path: String = _item_icon_path(entry)
	detail_icon_frame.texture = load(SLOT_FRAME_B_PATH) as Texture2D
	detail_icon_frame.modulate = GameState.get_item_accent(str(entry.get("id", "")))
	detail_icon_label.text = _kind_glyph(kind)
	detail_icon_label.visible = icon_path.is_empty()
	detail_icon_label.add_theme_color_override("font_color", _kind_color(kind))
	detail_icon_texture.visible = not icon_path.is_empty()
	if not icon_path.is_empty():
		detail_icon_texture.texture = load(icon_path) as Texture2D
	detail_title.text = str(entry["name"])
	detail_title.add_theme_font_size_override(
		"font_size",
		14 if detail_title.text.length() > 24 else 16
	)
	detail_category.text = str(kind).to_upper()
	detail_description.text = str(entry["description"])
	detail_description.add_theme_font_size_override(
		"font_size",
		10 if detail_description.text.length() > 72 else 11
	)
	var count_label: String = CaseLocale.line("Quantity: ")
	detail_quantity.text = (
		count_label + "∞"
		if int(entry["quantity"]) < 0
		else count_label + "×" + str(entry["quantity"])
	)
	detail_requirements.text = str(entry["requirements"])
	detail_use_button.text = (
		CaseLocale.line("OPEN MAP") if kind == "map" else CaseLocale.line("USE")
	)
	var potion_effect: String = str(GameState.POTION_INFO.get(str(entry["id"]), {}).get("effect", ""))
	detail_use_button.visible = (
		(kind == "potion" and not potion_effect.is_empty())
		or kind == "dish"
		or kind == "map"
	)


func _update_bottom_status() -> void:
	var total_items: int = entries.size()
	bottom_status.text = CaseLocale.line(
		"FILED: %d  •  SELECT AN ITEM TO INSPECT  •  TAB / ESC: CLOSE"
	) % total_items


func _animate_bag_open() -> void:
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	board_panel.scale = Vector2(0.965, 0.965)
	open_tween = create_tween()
	open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(overlay, "modulate:a", 1.0, 0.16)
	open_tween.parallel().tween_property(board_panel, "scale", Vector2.ONE, 0.22)


func _play_inspection_feedback() -> void:
	if detail_layer == null:
		return
	if inspection_tween != null and inspection_tween.is_valid():
		inspection_tween.kill()
	detail_layer.pivot_offset = Vector2(684.0, 334.0)
	detail_layer.scale = Vector2(0.985, 0.985)
	inspection_tween = create_tween()
	inspection_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	inspection_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	inspection_tween.tween_property(detail_layer, "scale", Vector2.ONE, 0.18)


func _focus_selected_slot() -> void:
	if selected_index >= 0 and selected_index < slot_nodes.size():
		var selected_slot: Control = slot_nodes[selected_index]
		var selected_button: Button = selected_slot.get_node_or_null("SlotButton") as Button
		if selected_button != null:
			selected_button.grab_focus()


func _use_selected_item() -> void:
	if selected_index < 0 or selected_index >= entries.size():
		return
	var entry: Dictionary = entries[selected_index]
	if str(entry["kind"]) == "map":
		feature_panel.visible = false
		close_bag()
		var map_hud: Node = get_node_or_null("/root/MapHud")
		if map_hud != null:
			if str(entry["id"]) == GameState.DR_LIN_PARTIAL_HALL_MAP_ID:
				map_hud.call("open_map")
			else:
				map_hud.call("show_repair_map")
		return
	# 菜肴系统：食用恢复生命。
	if str(entry["kind"]) == "dish":
		var dish_id: String = str(entry["id"])
		if GameState.consume_dish(dish_id):
			_show_use_toast(str(entry["name"]) + " eaten — health restored")
			_rebuild_inventory()
		return
	if str(entry["kind"]) != "potion":
		return
	var potion_id: String = str(entry["id"])
	var potion_info: Dictionary = GameState.POTION_INFO.get(potion_id, {})
	var effect_id: String = str(potion_info.get("effect", ""))
	if effect_id.is_empty() or not GameState.has_inventory_item(potion_id):
		return
	match effect_id:
		"purify":
			# Permanent: it strips the tracking serum instead of buffing the
			# player, so it never enters the timed-effect table.
			GameState.purify_tracking_serum()
		"daze":
			# Thrown at the Guardian, not drunk. The duration belongs to the
			# Guardian's stun timer -- but registering it as a timed effect too
			# is what gives the throw a burst, a chip and a countdown. Without
			# it the bottle produced no feedback whatsoever, and a Guardian that
			# was off screen when it landed made the potion look like it did
			# nothing at all. Nothing reads is_potion_active("daze") for
			# gameplay, so this is display only.
			var daze_seconds: float = float(potion_info.get("duration", 7.0))
			GameState.stun_guardian(daze_seconds)
			GameState.apply_potion_effect("daze", daze_seconds)
		_:
			GameState.apply_potion_effect(
				effect_id,
				float(potion_info.get("duration", 10.0))
			)
	if potion_id == "vision_potion":
		# 真正制作并使用的 Vision Potion 解锁本章节的增强观察能力；
		# Chemistry Room 的一次性样品演示不会走到这里。
		GameState.set_story_flag("vision_mastered")
	GameState.remove_inventory_item(potion_id)
	_rebuild_inventory()
	close_bag()
	_show_use_toast(str(potion_info.get("name", potion_id)) + " used")


func _show_use_toast(text: String) -> void:
	var toast: Label = Label.new()
	toast.text = text
	toast.position = Vector2(320.0, 700.0)
	toast.size = Vector2(400.0, 36.0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
	toast.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.02, 1.0))
	toast.add_theme_constant_override("outline_size", 5)
	add_child(toast)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)
