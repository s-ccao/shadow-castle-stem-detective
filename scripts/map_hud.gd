extends CanvasLayer

## MapHub — 真实 Castle Hall 地图。
## 底图来自用户提供的 1448×1086 地图；黑色探索层与大厅行走状态绑定。

const MAP_TEXTURE_PATH: String = (
	"res://assets/backgrounds/hall_map_hub.png"
)
const MAP_IMAGE_SIZE: Vector2 = Vector2(1448.0, 1086.0)
const MAP_PANEL_POSITION: Vector2 = Vector2(62.0, 72.0)
const MAP_PANEL_SIZE: Vector2 = Vector2(900.0, 675.0)
const HALL_WORLD_SIZE: Vector2 = Vector2(1920.0, 1280.0)
const HALL_CELL_SIZE: float = 32.0
const MAP_TO_PANEL: Vector2 = Vector2(
	MAP_PANEL_SIZE.x / MAP_IMAGE_SIZE.x,
	MAP_PANEL_SIZE.y / MAP_IMAGE_SIZE.y
)

# 房门交互点使用 game_world.gd 的真实世界坐标，不使用抽象布局坐标。
const ROOM_IDS: Array[String] = [
	"wake_room",
	"chemistry_room",
	"greenhouse_room",
	"circuit_room",
	"final_deduction_room",
	"library",
	"dining_hall"
]
const ROOM_LABELS: Array[String] = [
	"Wake Room",
	"Chemistry Room",
	"Greenhouse",
	"Circuit Room",
	"Final Room",
	"Library",
	"Dining Hall"
]
const ROOM_KEY_IDS: Array[String] = [
	"",
	"chemistry_room_key",
	"greenhouse_room_key",
	"circuit_room_key",
	"final_room_key",
	"library_room_key",
	"dining_hall_key"
]
const ROOM_WORLD_POSITIONS: Array[Vector2] = [
	Vector2(258.0, 1050.0),
	Vector2(283.0, 162.0),
	Vector2(219.0, 409.0),
	Vector2(168.0, 691.0),
	Vector2(955.0, 138.0),
	Vector2(1676.0, 285.0),
	Vector2(1774.0, 715.0)
]

const WALK_REVEAL_RADIUS_MAP: float = 28.0
const ROOM_REVEAL_RADIUS_MAP: float = 88.0
const WAKE_REVEAL_RADIUS_MAP: float = 105.0

var map_entry_button: Button
var overlay: Control
var map_panel: Panel
var map_texture_rect: TextureRect
var fog_texture_rect: TextureRect
var fog_image: Image
var fog_texture: ImageTexture
var map_detail: Label
var room_points: Array[Panel] = []
var room_labels: Array[Label] = []
var _known_explored_count: int = -1
var _drawn_explored: Dictionary = {}
var _paused_before_map: bool = false
var repair_overlay: Control


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_map_entry()
	_create_map_overlay()
	if not GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.connect(_on_game_state_changed)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)
	_sync_map_state()


func _process(_delta: float) -> void:
	# 增量去雾：只画新增的探索格，避免玩家行走时全量重建大图。
	var explored: Dictionary = GameState.hall_explored_cells
	var has_new: bool = false
	for cell_key: Variant in explored.keys():
		if not _drawn_explored.has(cell_key):
			_draw_explored_cell(cell_key)
			_drawn_explored[cell_key] = true
			has_new = true
	if has_new:
		fog_texture.update(fog_image)
	_known_explored_count = explored.size()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_U and GameState.is_map_hub_unlocked():
		toggle_map()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and repair_overlay != null and repair_overlay.visible:
		close_repair_map()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and overlay.visible:
		close_map()
		get_viewport().set_input_as_handled()


func _create_map_entry() -> void:
	map_entry_button = Button.new()
	map_entry_button.name = "MapHubEntry"
	map_entry_button.text = "MAP"
	# 左上角 Hub 顺序：BAG(18) → KEY(106) → NOTE(194) → MAP(282)，间距 16px。
	map_entry_button.position = Vector2(282.0, 22.0)
	map_entry_button.size = Vector2(64.0, 44.0)
	map_entry_button.visible = false
	map_entry_button.tooltip_text = "route map"
	map_entry_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_entry_button.add_theme_font_size_override("font_size", 12)
	_apply_entry_style()
	map_entry_button.pressed.connect(toggle_map)
	add_child(map_entry_button)


func _apply_entry_style() -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.035, 0.025, 0.045, 0.94)
	normal_style.border_color = Color(0.65, 0.48, 0.20, 0.88)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(5)
	map_entry_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.13, 0.085, 0.045, 0.98)
	hover_style.border_color = Color(0.96, 0.76, 0.34, 1.0)
	hover_style.set_border_width_all(2)
	map_entry_button.add_theme_stylebox_override("hover", hover_style)
	map_entry_button.add_theme_color_override(
		"font_color",
		Color(0.90, 0.70, 0.32, 1.0)
	)
	map_entry_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.92, 0.64, 1.0)
	)


func _create_map_overlay() -> void:
	overlay = Control.new()
	overlay.name = "MapHubOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "MapHubDarkBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.002, 0.002, 0.006, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var title: Label = Label.new()
	title.name = "MapTitle"
	title.position = Vector2(76.0, 16.0)
	title.size = Vector2(620.0, 30.0)
	title.text = "MRS. LIN'S ROUTE MAP"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.94, 0.72, 0.31, 1.0))
	overlay.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "MapSubtitle"
	subtitle.position = Vector2(78.0, 43.0)
	subtitle.size = Vector2(760.0, 22.0)
	subtitle.text = "The hall reveals itself only where you have walked."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48, 1.0))
	overlay.add_child(subtitle)

	map_panel = Panel.new()
	map_panel.name = "RealCastleHallMap"
	map_panel.position = MAP_PANEL_POSITION
	map_panel.size = MAP_PANEL_SIZE
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var map_style: StyleBoxFlat = StyleBoxFlat.new()
	map_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	map_style.border_color = Color(0.66, 0.48, 0.20, 0.92)
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(6)
	map_style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	map_style.shadow_size = 16
	map_panel.add_theme_stylebox_override("panel", map_style)
	overlay.add_child(map_panel)

	map_texture_rect = TextureRect.new()
	map_texture_rect.name = "HallMapTexture"
	map_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture_rect.texture = load(MAP_TEXTURE_PATH) as Texture2D
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map_texture_rect)

	fog_texture_rect = TextureRect.new()
	fog_texture_rect.name = "HallExplorationDarkness"
	fog_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	fog_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(fog_texture_rect)
	_create_fog_texture()

	var close_button: Button = Button.new()
	close_button.name = "MapCloseButton"
	close_button.text = "×"
	close_button.position = Vector2(910.0, 78.0)
	close_button.size = Vector2(40.0, 38.0)
	close_button.add_theme_font_size_override("font_size", 27)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_color_override("font_color", Color(0.92, 0.68, 0.28, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.58, 1.0))
	close_button.pressed.connect(close_map)
	overlay.add_child(close_button)

	for index: int in range(ROOM_IDS.size()):
		_create_room_point(index)

	map_detail = Label.new()
	map_detail.name = "MapDetail"
	map_detail.position = Vector2(78.0, 748.0)
	map_detail.size = Vector2(820.0, 20.0)
	map_detail.text = "Wake Room is the only light you can trust."
	map_detail.add_theme_font_size_override("font_size", 13)
	map_detail.add_theme_color_override("font_color", Color(0.68, 0.60, 0.46, 1.0))
	overlay.add_child(map_detail)


func _create_room_point(index: int) -> void:
	var map_position: Vector2 = _world_to_map(
		ROOM_WORLD_POSITIONS[index]
	)
	var panel_position: Vector2 = map_position * MAP_TO_PANEL

	var point: Panel = Panel.new()
	point.name = "RoomKeyLight_%s" % ROOM_IDS[index]
	point.position = panel_position - Vector2(9.0, 9.0)
	point.size = Vector2(18.0, 18.0)
	point.mouse_filter = Control.MOUSE_FILTER_IGNORE
	point.add_theme_stylebox_override("panel", _make_point_style())
	map_panel.add_child(point)
	room_points.append(point)

	var label: Label = Label.new()
	label.name = "RoomLabel_%s" % ROOM_IDS[index]
	label.position = panel_position + Vector2(14.0, -11.0)
	label.size = Vector2(180.0, 24.0)
	label.text = ROOM_LABELS[index]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.43, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(label)
	room_labels.append(label)


func _create_fog_texture() -> void:
	fog_image = Image.create(
		int(MAP_IMAGE_SIZE.x),
		int(MAP_IMAGE_SIZE.y),
		false,
		Image.FORMAT_RGBA8
	)
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog_texture_rect.texture = fog_texture
	_refresh_fog_texture()


func _draw_explored_cell(cell_key: Variant) -> void:
	var parts: PackedStringArray = str(cell_key).split(",")
	if parts.size() != 2:
		return
	var cell: Vector2 = Vector2(
		float(parts[0]),
		float(parts[1])
	)
	var world_center: Vector2 = (
		cell + Vector2(0.5, 0.5)
	) * HALL_CELL_SIZE
	_clear_map_circle(
		_world_to_map(world_center),
		WALK_REVEAL_RADIUS_MAP
	)


func _refresh_fog_texture() -> void:
	if fog_image == null or fog_texture == null:
		return
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))

	# 追逐模式时地图窗口也保持全黑；玩家只能依靠游戏世界中的手电筒视野。
	if GameState.chase_mode:
		fog_texture.update(fog_image)
		_known_explored_count = GameState.hall_explored_cells.size()
		return

	# Wake Room 的真实入口区域始终可见。
	_clear_map_circle(
		_world_to_map(ROOM_WORLD_POSITIONS[0]),
		WAKE_REVEAL_RADIUS_MAP
	)

	# 大厅中玩家真实走过的 32px 探索格。
	for cell_key: Variant in GameState.hall_explored_cells.keys():
		_draw_explored_cell(cell_key)

	# 进入过的房间区域解除黑暗。
	for index: int in range(ROOM_IDS.size()):
		if _is_room_visited(ROOM_IDS[index]):
			_clear_map_circle(
				_world_to_map(ROOM_WORLD_POSITIONS[index]),
				ROOM_REVEAL_RADIUS_MAP
			)

	fog_texture.update(fog_image)
	_known_explored_count = GameState.hall_explored_cells.size()
	_drawn_explored.clear()
	for cell_key: Variant in GameState.hall_explored_cells.keys():
		_drawn_explored[cell_key] = true


func _clear_map_circle(center: Vector2, radius: float) -> void:
	# 用 C++ 批量 fill_rect 代替逐像素 set_pixel：
	# 大厅探索格最多 2400 个，逐像素重建是百万次引擎调用（卡死根源），
	# fill_rect 一次调用填充整个矩形，速度提升几个数量级。
	var rect := Rect2i(
		int(center.x - radius),
		int(center.y - radius),
		int(radius * 2.0),
		int(radius * 2.0)
	)
	rect = rect.intersection(
		Rect2i(0, 0, int(MAP_IMAGE_SIZE.x), int(MAP_IMAGE_SIZE.y))
	)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	fog_image.fill_rect(rect, Color(0.0, 0.0, 0.0, 0.0))


func _world_to_map(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x * MAP_IMAGE_SIZE.x / HALL_WORLD_SIZE.x,
		world_position.y * MAP_IMAGE_SIZE.y / HALL_WORLD_SIZE.y
	)


func _is_room_visited(room_id: String) -> bool:
	return (
		room_id == "wake_room"
		or GameState.is_room_visited(room_id)
	)


func _make_point_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.68, 0.25, 1.0)
	style.border_color = Color(1.0, 0.91, 0.55, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.94, 0.53, 0.12, 0.92)
	style.shadow_size = 12
	return style


func _on_scene_changed() -> void:
	# MapHub 是 Autoload，不会随房间场景释放；切换房间时必须关闭大厅地图，
	# 否则新房间会显示在 Castle Hall 地图 Overlay 后面，造成画面混合。
	if overlay != null:
		overlay.visible = false
	if repair_overlay != null:
		repair_overlay.visible = false
	_paused_before_map = false
	get_tree().paused = false
	call_deferred("_sync_map_state")


func _on_game_state_changed() -> void:
	# 轻量同步：入口按钮与房间点。迷雾大图由 _process 检测
	# 探索格数量变化后增量重建，避免每帧重建 1448×1086 纹理。
	_sync_map_state_light()


func _sync_map_state_light() -> void:
	if map_entry_button == null:
		return
	map_entry_button.visible = (
		GameState.is_map_hub_unlocked()
		and GameState.current_room_id == "floor_1_hub"
	)
	if GameState.chase_mode:
		for index: int in range(ROOM_IDS.size()):
			room_labels[index].visible = false
			room_points[index].visible = false
		if map_detail != null:
			map_detail.text = "The map is blackened by the chase. Only your immediate surroundings are visible."
		return
	for index: int in range(ROOM_IDS.size()):
		var visited: bool = _is_room_visited(ROOM_IDS[index])
		room_labels[index].visible = visited
		var key_id: String = ROOM_KEY_IDS[index]
		var has_key: bool = (
			ROOM_IDS[index] == "wake_room"
			or (
				not key_id.is_empty()
				and GameState.has_key(key_id)
			)
		)
		room_points[index].visible = has_key
		if visited:
			room_points[index].modulate = Color(0.88, 0.68, 0.34, 1.0)
		else:
			room_points[index].modulate = Color.WHITE


func _sync_map_state() -> void:
	if map_entry_button == null:
		return
	map_entry_button.visible = (
		GameState.is_map_hub_unlocked()
		and GameState.current_room_id == "floor_1_hub"
	)
	if GameState.chase_mode:
		for index: int in range(ROOM_IDS.size()):
			room_labels[index].visible = false
			room_points[index].visible = false
		if map_detail != null:
			map_detail.text = "The map is blackened by the chase. Only your immediate surroundings are visible."
		return
	for index: int in range(ROOM_IDS.size()):
		var visited: bool = _is_room_visited(ROOM_IDS[index])
		room_labels[index].visible = visited
		var key_id: String = ROOM_KEY_IDS[index]
		var has_key: bool = (
			ROOM_IDS[index] == "wake_room"
			or (
				not key_id.is_empty()
				and GameState.has_key(key_id)
			)
		)
		room_points[index].visible = has_key
		if visited:
			room_points[index].modulate = Color(0.88, 0.68, 0.34, 1.0)
		else:
			room_points[index].modulate = Color.WHITE
	_refresh_fog_texture()

	if map_detail == null:
		return
	var explored_count: int = GameState.hall_explored_cells.size()
	map_detail.text = (
		"Hall explored cells: "
		+ str(explored_count)
		+ " / 2400. Gold lights mark keys; entering a room reveals its region."
	)


func unlock_and_open() -> void:
	GameState.unlock_map_hub()
	open_map()


func toggle_map() -> void:
	if not GameState.is_map_hub_unlocked():
		return
	if overlay.visible:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if not GameState.is_map_hub_unlocked():
		return
	_paused_before_map = get_tree().paused
	get_tree().paused = true
	overlay.visible = true
	_sync_map_state_light()
	_refresh_fog_texture()


func show_repair_map() -> void:
	if not GameState.has_map("circuit_repair_map"):
		return
	var bag_hud: Node = get_node_or_null("/root/InventoryHud")
	if bag_hud != null:
		var feature_panel: Panel = bag_hud.get("feature_panel") as Panel
		if feature_panel != null:
			feature_panel.visible = false
	var reward_hud: Node = get_node_or_null("/root/ItemRewardHud")
	if reward_hud != null:
		reward_hud.call("dismiss_for_overlay")
	if repair_overlay == null:
		_create_repair_overlay()
	_paused_before_map = get_tree().paused
	get_tree().paused = true
	overlay.visible = false
	repair_overlay.visible = true


func _create_repair_overlay() -> void:
	repair_overlay = Control.new()
	repair_overlay.name = "CircuitRepairMapOverlay"
	repair_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repair_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	repair_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(repair_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	repair_overlay.add_child(shade)

	var panel: Panel = Panel.new()
	panel.position = Vector2(132.0, 20.0)
	panel.size = Vector2(760.0, 728.0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.045, 0.025, 0.98)
	panel_style.border_color = Color(0.78, 0.58, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	repair_overlay.add_child(panel)

	var title: Label = Label.new()
	title.text = "CIRCUIT REPAIR MAP"
	title.position = Vector2(34.0, 22.0)
	title.size = Vector2(600.0, 34.0)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38, 1.0))
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Restore power in this order: 1 AUXILIARY  →  2 REGULATOR  →  3 MASTER"
	subtitle.position = Vector2(34.0, 62.0)
	subtitle.size = Vector2(650.0, 30.0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66, 1.0))
	panel.add_child(subtitle)

	var map_board: TextureRect = TextureRect.new()
	map_board.position = Vector2(62.0, 100.0)
	map_board.size = Vector2(636.0, 478.0)
	map_board.texture = load("res://assets/backgrounds/circuit_room_workshop.png") as Texture2D
	map_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_board.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(map_board)

	var border: Panel = Panel.new()
	border.position = Vector2(62.0, 100.0)
	border.size = Vector2(636.0, 478.0)
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.border_color = Color(0.65, 0.48, 0.24, 0.9)
	border_style.set_border_width_all(2)
	border.add_theme_stylebox_override("panel", border_style)
	panel.add_child(border)

	var room_label: Label = Label.new()
	room_label.text = "CIRCUIT ROOM / ACTUAL SWITCH LOCATIONS"
	room_label.position = Vector2(192.0, 78.0)
	room_label.size = Vector2(360.0, 28.0)
	room_label.add_theme_font_size_override("font_size", 13)
	room_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.68, 1.0))
	panel.add_child(room_label)

	var markers: Array[Dictionary] = [
		{"text": "1", "pos": Vector2(133.0, 315.0), "name": "AUXILIARY / LEFT"},
		{"text": "2", "pos": Vector2(573.0, 341.0), "name": "REGULATOR / RIGHT"},
		{"text": "3", "pos": Vector2(351.0, 341.0), "name": "MASTER / CENTER"},
	]
	for marker: Dictionary in markers:
		var number: Label = Label.new()
		number.text = str(marker["text"])
		number.position = marker["pos"] as Vector2
		number.size = Vector2(42.0, 42.0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 22)
		number.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36, 1.0))
		panel.add_child(number)
		var name_label: Label = Label.new()
		name_label.text = str(marker["name"])
		name_label.position = Vector2((marker["pos"] as Vector2).x - 45.0, (marker["pos"] as Vector2).y + 42.0)
		name_label.size = Vector2(132.0, 24.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.84, 0.78, 0.58, 1.0))
		panel.add_child(name_label)

	var note: Label = Label.new()
	note.text = "Return to the room, stand at each numbered plate, and press E. The repair paint was removed from the physical panels."
	note.position = Vector2(48.0, 600.0)
	note.size = Vector2(650.0, 42.0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.78, 0.70, 0.55, 1.0))
	panel.add_child(note)

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.position = Vector2(574.0, 665.0)
	close_button.size = Vector2(120.0, 36.0)
	close_button.pressed.connect(close_repair_map)
	panel.add_child(close_button)


func close_repair_map() -> void:
	if repair_overlay != null:
		repair_overlay.visible = false
	get_tree().paused = _paused_before_map


func close_map() -> void:
	overlay.visible = false
	get_tree().paused = _paused_before_map
