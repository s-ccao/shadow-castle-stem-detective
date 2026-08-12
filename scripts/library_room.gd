extends Node2D

## Library — 图书馆/奥术档案馆（用户提供 9a790883 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/library_archive.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "library"
const RETURN_SPAWN_ID: String = "library_door"

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const RECIPE_INTERACT_RADIUS: float = 80.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"storage_cabinet": NodePath("Worldsort/StorageCabinet"),
	"tall_cabinet_a": NodePath("Worldsort/TallCabinetA"),
	"tall_cabinet_b": NodePath("Worldsort/TallCabinetB"),
	"chest_cabinet": NodePath("Worldsort/ChestCabinet"),
	"writing_desk": NodePath("Worldsort/WritingDesk"),
	"upper_panel_cabinet": NodePath("Worldsort/UpperPanelCabinet"),
	"upper_shelf_cabinet": NodePath("Worldsort/UpperShelfCabinet"),
	"upper_chest_cabinet": NodePath("Worldsort/UpperChestCabinet"),
	"upper_drawer_cabinet": NodePath("Worldsort/UpperDrawerCabinet"),
	"upper_apothecary_cabinet": NodePath("Worldsort/UpperApothecaryCabinet"),
	"lower_panel_a": NodePath("Worldsort/LowerPanelA"),
	"lower_panel_b": NodePath("Worldsort/LowerPanelB"),
	"lower_storage": NodePath("Worldsort/LowerStorage"),
	"lower_globe_desk": NodePath("Worldsort/LowerGlobeDesk"),
	"lower_study_table": NodePath("Worldsort/LowerStudyTable"),
	"topleft_chest_a": NodePath("Worldsort/TopLeftChestA"),
	"topleft_cabinet_b": NodePath("Worldsort/TopLeftCabinetB"),
	"topleft_cabinet_c": NodePath("Worldsort/TopLeftCabinetC"),
	"topleft_cabinet_d": NodePath("Worldsort/TopLeftCabinetD"),
	"topleft_tall_case": NodePath("Worldsort/TopLeftTallCase")
}
const PROP_OCCLUSION_PATHS: Array[NodePath] = [
	NodePath("Worldsort/StorageCabinet"),
	NodePath("Worldsort/TallCabinetA"),
	NodePath("Worldsort/TallCabinetB"),
	NodePath("Worldsort/ChestCabinet"),
	NodePath("Worldsort/WritingDesk"),
	NodePath("Worldsort/UpperPanelCabinet"),
	NodePath("Worldsort/UpperShelfCabinet"),
	NodePath("Worldsort/UpperChestCabinet"),
	NodePath("Worldsort/UpperDrawerCabinet"),
	NodePath("Worldsort/UpperApothecaryCabinet"),
	NodePath("Worldsort/LowerPanelA"),
	NodePath("Worldsort/LowerPanelB"),
	NodePath("Worldsort/LowerStorage"),
	NodePath("Worldsort/LowerGlobeDesk"),
	NodePath("Worldsort/LowerStudyTable"),
	NodePath("Worldsort/TopLeftChestA"),
	NodePath("Worldsort/TopLeftCabinetB"),
	NodePath("Worldsort/TopLeftCabinetC"),
	NodePath("Worldsort/TopLeftCabinetD"),
	NodePath("Worldsort/TopLeftTallCase")
]
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "recipe_swift_scroll",
		"label": "the bottle-scroll",
		"position": Vector2(1060.0, 320.0),
		"message": (
			"A rolled scroll tucked between alchemical volumes. "
			+ "It holds the recipe for the Swiftness Potion."
		)
	},
	{
		"name": "recipe_vision_scroll",
		"label": "the lens-scroll",
		"position": Vector2(300.0, 480.0),
		"message": (
			"A scroll hidden inside an old atlas. "
			+ "It holds the recipe for the Vision Potion."
		)
	},
	{
		"name": "research_desk",
		"label": "the research desk",
		"position": Vector2(724.0, 560.0),
		"message": (
			"An open illuminated book lies on the desk beside a magnifying "
			+ "glass. The pages are dense with notes and diagrams."
		)
	},
	{
		"name": "rgb_red_filter",
		"label": "the red filter",
		"position": Vector2(664.0, 650.0),
		"message": "A red filter rests in the small optical stand. The Library Knowledge note says the three light colors must be applied in sequence."
	},
	{
		"name": "rgb_green_filter",
		"label": "the green filter",
		"position": Vector2(724.0, 650.0),
		"message": "A green filter rests in the small optical stand."
	},
	{
		"name": "rgb_blue_filter",
		"label": "the blue filter",
		"position": Vector2(784.0, 650.0),
		"message": "A blue filter rests in the small optical stand."
	},
	{
		"name": "chained_cabinet",
		"label": "the chained cabinet",
		"position": Vector2(250.0, 170.0),
		"message": (
			"A heavy cabinet bound by a chain and a gold padlock. "
			+ "Whatever it guards, it was meant to stay sealed."
		)
	},
	{
		"name": "drawer_bank",
		"label": "the drawer bank",
		"position": Vector2(1180.0, 260.0),
		"message": (
			"A tall bank of drawers with brass handles. One drawer is "
			+ "slightly open, papers peeking out."
		)
	},
	{
		"name": "storage_cabinet",
		"label": "the reinforced cabinet",
		"position": Vector2(1057.0, 830.0),
		"message": (
			"A reinforced storage cabinet. Its shelves hold rolled scrolls "
			+ "and odd brass instruments."
		)
	},
	{
		"name": "tall_cabinet_a",
		"label": "the compass cabinet",
		"position": Vector2(1165.0, 980.0),
		"message": (
			"A tall cabinet of dark wood, marked with a compass-like "
			+ "emblem. Its door will not budge."
		)
	},
	{
		"name": "tall_cabinet_b",
		"label": "the hourglass cabinet",
		"position": Vector2(889.0, 1010.0),
		"message": (
			"A narrow cabinet. A circular lock with an hourglass mark "
			+ "guards whatever lies within."
		)
	},
	{
		"name": "chest_cabinet",
		"label": "the chest of books",
		"position": Vector2(1323.0, 1015.0),
		"message": (
			"A broad chest-cabinet packed with books and bundled scrolls. "
			+ "The bindings are worn with age."
		)
	},
	{
		"name": "writing_desk",
		"label": "the writing desk",
		"position": Vector2(1310.0, 735.0),
		"message": (
			"A writing desk. An open book, pinned parchment and an inkwell "
			+ "rest on its worn surface."
		)
	},
	{
		"name": "upper_panel_cabinet",
		"label": "the ring-marked cabinet",
		"position": Vector2(980.0, 348.0),
		"message": (
			"A tall ring-marked cabinet. Its lower emblem is scratched "
			+ "with a symbol that matches no library catalogue."
		)
	},
	{
		"name": "upper_shelf_cabinet",
		"label": "the upper book shelf",
		"position": Vector2(1060.0, 248.0),
		"message": (
			"An open shelf of dusty volumes and sealed containers. "
			+ "Several spines have been deliberately turned around."
		)
	},
	{
		"name": "upper_chest_cabinet",
		"label": "the chained book chest",
		"position": Vector2(1100.0, 418.0),
		"message": (
			"A chained chest-cabinet. The lock is intact, but the books "
			+ "inside have been disturbed recently."
		)
	},
	{
		"name": "upper_drawer_cabinet",
		"label": "the archive drawers",
		"position": Vector2(1015.0, 568.0),
		"message": (
			"Rows of archive drawers filled with brittle notes, labels "
			+ "and fragments of old casework."
		)
	},
	{
		"name": "upper_apothecary_cabinet",
		"label": "the apothecary cabinet",
		"position": Vector2(1160.0, 568.0),
		"message": (
			"A cabinet of bottles, powders and sealed jars. The dust "
			+ "around one vial has been recently disturbed."
		)
	},
	{
		"name": "lower_panel_a",
		"label": "the wheel-marked panel",
		"position": Vector2(320.0, 678.0),
		"message": (
			"A tall wooden panel with a wheel-like mechanism. Its symbols "
			+ "look designed to be turned in a precise order."
		)
	},
	{
		"name": "lower_panel_b",
		"label": "the ring-lock cabinet",
		"position": Vector2(460.0, 678.0),
		"message": (
			"A narrow cabinet with two ring handles and a heavy lower clasp. "
			+ "The lock has been opened and closed many times."
		)
	},
	{
		"name": "lower_storage",
		"label": "the purple archive cabinet",
		"position": Vector2(350.0, 818.0),
		"message": (
			"A storage cabinet packed with dark violet volumes and sealed "
			+ "drawers. One compartment is empty."
		)
	},
	{
		"name": "lower_globe_desk",
		"label": "the globe desk",
		"position": Vector2(470.0, 818.0),
		"message": (
			"A desk with an antique globe, an oil lamp and an open book. "
			+ "The lamp is still warm."
		)
	},
	{
		"name": "lower_study_table",
		"label": "the detective table",
		"position": Vector2(350.0, 958.0),
		"message": (
			"A detective's work table covered in papers, candles and a "
			+ "magnifying glass. The notes point toward the lower hall."
		)
	},
	{
		"name": "topleft_chest_a",
		"label": "the divided storage chest",
		"position": Vector2(200.0, 268.0),
		"message": (
			"A divided storage chest filled with banded books, scrolls and "
			+ "small sealed bundles."
		)
	},
	{
		"name": "topleft_cabinet_b",
		"label": "the three-tier bookcase",
		"position": Vector2(300.0, 408.0),
		"message": (
			"A three-tier bookcase. The top surface still holds an open "
			+ "book and several small cases."
		)
	},
	{
		"name": "topleft_cabinet_c",
		"label": "the reinforced archive cabinet",
		"position": Vector2(300.0, 548.0),
		"message": (
			"A reinforced archive cabinet with deep shelves and brass "
			+ "fasteners. Its contents are carefully sorted."
		)
	},
	{
		"name": "topleft_cabinet_d",
		"label": "the emblem cabinet",
		"position": Vector2(440.0, 458.0),
		"message": (
			"A dark cabinet bearing a circular crossed emblem. The lower "
			+ "handle is polished from frequent use."
		)
	},
	{
		"name": "topleft_tall_case",
		"label": "the tall ring case",
		"position": Vector2(180.0, 628.0),
		"message": (
			"A narrow two-part case with ring handles and reinforced "
			+ "straps. Something rattles behind the lower panel."
		)
	}
]

@export var debug_print_click_position := false

var player: Node2D
var follow_camera: Camera2D
var camera_target_zoom: Vector2 = GAMEPLAY_CAMERA_ZOOM
var scene_transitioning := false
var room_input_enabled := true
var current_interaction := ""
var item_message := ""
var interact_label: Label
var interaction_hint_panel: Panel
var ui_layer: CanvasLayer
var interaction_focus: WorldInteractionFocus
var prop_collision_bodies: Dictionary = {}
var rgb_filter_visuals: Array[Node] = []
var archive_book_visual: Sprite2D
var _texture_opaque_rect_cache: Dictionary = {}
var _last_debug_mouse_position := Vector2(-100000, -100000)


func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = ROOM_ID
	GameState.set_room_visited(ROOM_ID)
	player = $Worldsort/player
	player.position = PLAYER_SPAWN_POSITION
	player.set_physics_process(true)
	_create_prop_collisions()
	_sync_scene_interaction_points()
	create_room_ui()
	create_follow_camera()
	create_interaction_focus()
	_create_rgb_filter_stand()
	archive_book_visual = get_node_or_null("ArchiveBookVisual") as Sprite2D
	if archive_book_visual != null:
		archive_book_visual.visible = GameState.has_story_flag("library_archive_record_found")
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID


func _process(_delta: float) -> void:
	_sync_scene_interaction_points()
	_update_prop_occlusion_layers()
	if room_input_enabled:
		update_interaction_prompt()
		update_interaction_focus()
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


## 显式补偿嵌套 Node2D 的 Y-sort：
## 玩家在锚点下方时，物品降到玩家后面；玩家在锚点上方时，物品升到玩家前面。
func _update_prop_occlusion_layers() -> void:
	if player == null:
		return
	for prop_path: NodePath in PROP_OCCLUSION_PATHS:
		var prop: Node2D = get_node_or_null(prop_path) as Node2D
		if prop == null or prop.get_child_count() == 0:
			continue
		var visual_anchor: Vector2 = _get_prop_visual_anchor(prop)
		var target_z: int = (
			PROP_BACK_Z
			if player.global_position.y < visual_anchor.y
			else PROP_FRONT_Z
		)
		# 父节点保留普通层级，真正的 Sprite 使用绝对 z-index，
		# 避免 Worldsort/Y-sort 的父子绘制顺序重新盖回玩家。
		prop.z_index = 0
		var prop_visual: CanvasItem = prop.get_child(0) as CanvasItem
		prop_visual.z_as_relative = false
		prop_visual.z_index = target_z


## 读取当前 Sprite2D 的真实可见像素矩形。
## 以用户在 Inspector 手动调整后的 Sprite 位置、缩放、offset、centered
## 和纹理 alpha 包围盒为准，不把透明留白算进家具范围。
func _get_prop_visual_rect(prop: Node2D) -> Rect2:
	if prop.get_child_count() == 0:
		return Rect2(prop.global_position, Vector2.ZERO)
	var sprite: Sprite2D = prop.get_child(0) as Sprite2D
	if sprite == null or sprite.texture == null:
		return Rect2(prop.global_position, Vector2.ZERO)
	var texture_size: Vector2 = sprite.texture.get_size()
	var opaque_rect: Rect2i = _get_texture_opaque_rect(sprite.texture)
	var opaque_size: Vector2 = Vector2(
		float(opaque_rect.size.x) * absf(sprite.scale.x),
		float(opaque_rect.size.y) * absf(sprite.scale.y)
	)
	var local_top_left: Vector2 = sprite.position + sprite.offset * sprite.scale
	if sprite.centered:
		local_top_left += Vector2(
			(float(opaque_rect.position.x) - texture_size.x * 0.5) * sprite.scale.x,
			(float(opaque_rect.position.y) - texture_size.y * 0.5) * sprite.scale.y
		)
	else:
		local_top_left += Vector2(
			float(opaque_rect.position.x) * sprite.scale.x,
			float(opaque_rect.position.y) * sprite.scale.y
		)
	return Rect2(prop.to_global(local_top_left), opaque_size)


func _get_prop_visual_anchor(prop: Node2D) -> Vector2:
	var visual_rect: Rect2 = _get_prop_visual_rect(prop)
	return visual_rect.position + Vector2(visual_rect.size.x * 0.5, visual_rect.size.y)


func _get_texture_opaque_rect(texture: Texture2D) -> Rect2i:
	var texture_id: int = texture.get_instance_id()
	if _texture_opaque_rect_cache.has(texture_id):
		return _texture_opaque_rect_cache[texture_id] as Rect2i
	var image: Image = texture.get_image()
	if image == null:
		return Rect2i(0, 0, int(texture.get_width()), int(texture.get_height()))
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	var opaque_rect: Rect2i
	if max_x < min_x or max_y < min_y:
		opaque_rect = Rect2i(0, 0, image.get_width(), image.get_height())
	else:
		opaque_rect = Rect2i(
			min_x,
			min_y,
			max_x - min_x + 1,
			max_y - min_y + 1
		)
	_texture_opaque_rect_cache[texture_id] = opaque_rect
	return opaque_rect


func create_room_ui() -> void:
	# UI 独立图层：交互提示跟随交互物在世界中的位置投影到屏幕，
	# 相机移动时提示始终贴在物品旁边（跟随玩家视角）。
	ui_layer = CanvasLayer.new()
	ui_layer.name = "LibraryRoomUI"
	ui_layer.layer = 30
	add_child(ui_layer)

	interaction_hint_panel = Panel.new()
	interaction_hint_panel.name = "InteractionHint"
	interaction_hint_panel.position = Vector2(238, 696)
	interaction_hint_panel.size = Vector2(500, 68)
	var hint_style: StyleBoxFlat = StyleBoxFlat.new()
	hint_style.bg_color = Color(0.02, 0.015, 0.03, 0.88)
	hint_style.border_color = Color(0.62, 0.45, 0.18, 0.85)
	hint_style.set_border_width_all(2)
	hint_style.set_corner_radius_all(8)
	interaction_hint_panel.add_theme_stylebox_override("panel", hint_style)
	interaction_hint_panel.visible = false
	ui_layer.add_child(interaction_hint_panel)

	interact_label = Label.new()
	interact_label.name = "InteractLabel"
	interact_label.position = Vector2(16, 7)
	interact_label.size = Vector2(468, 54)
	interact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 14)
	interact_label.add_theme_color_override(
		"font_color",
		Color(0.93, 0.82, 0.55, 1.0)
	)
	interaction_hint_panel.add_child(interact_label)


## 读取场景中可由 Inspector 手动调整的实体碰撞。
## 不在运行时重写 FurnitureShape 的 position 或 size。
func _create_prop_collisions() -> void:
	for item_name_variant: Variant in PROP_NODE_PATHS.keys():
		var item_name: String = str(item_name_variant)
		var prop: Node2D = get_node_or_null(PROP_NODE_PATHS[item_name]) as Node2D
		if prop == null:
			continue
		var body: StaticBody2D = prop.get_node_or_null("FurnitureCollision") as StaticBody2D
		var collision_shape: CollisionShape2D = null
		if body != null:
			collision_shape = body.get_node_or_null("FurnitureShape") as CollisionShape2D
		if body == null or collision_shape == null or collision_shape.shape == null:
			push_warning("Library manual furniture collision missing: " + item_name)
			continue
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("prop_name", item_name)
		prop_collision_bodies[item_name] = body


## 从场景中真实 Sprite2D 的可见位置生成交互点：
## 不使用外层 Node2D 的旧固定坐标；以当前 Sprite2D 的手动位置、缩放、
## offset、centered 和 alpha 可见像素底部中心为准。
func _sync_scene_interaction_points() -> void:
	for item: Dictionary in INTERACT_ITEMS:
		var item_name: String = str(item["name"])
		if PROP_NODE_PATHS.has(item_name):
			var prop: Node2D = get_node_or_null(PROP_NODE_PATHS[item_name]) as Node2D
			if prop == null:
				push_warning("Library interaction prop missing: " + item_name)
			else:
				var visual_anchor: Vector2 = _get_prop_visual_anchor(prop)
				item["focus_position"] = visual_anchor
				item["position"] = visual_anchor + INTERACTION_FRONT_OFFSET


func _get_item_focus_position(item: Dictionary) -> Vector2:
	if item.has("focus_position"):
		return item["focus_position"] as Vector2
	return item["position"] as Vector2


func _get_item_visual_rect(item: Dictionary) -> Rect2:
	var item_name: String = str(item["name"])
	if PROP_NODE_PATHS.has(item_name):
		var prop: Node2D = get_node_or_null(PROP_NODE_PATHS[item_name]) as Node2D
		if prop != null:
			var visual_rect: Rect2 = _get_prop_visual_rect(prop)
			if visual_rect.size.x > 0.0 and visual_rect.size.y > 0.0:
				return visual_rect
	var fallback_position: Vector2 = _get_item_focus_position(item)
	return Rect2(fallback_position - Vector2(56, 41), Vector2(112, 82))


func _get_item_focus_rect(item: Dictionary) -> Rect2:
	var visual_rect: Rect2 = _get_item_visual_rect(item)
	var padding: Vector2 = Vector2(24.0, 24.0)
	return Rect2(visual_rect.position - padding, visual_rect.size + padding * 2.0)


func _get_item_prompt_anchor(item: Dictionary) -> Vector2:
	var visual_rect: Rect2 = _get_item_visual_rect(item)
	return Vector2(visual_rect.get_center().x, visual_rect.position.y)


func create_interaction_focus() -> void:
	interaction_focus = WorldInteractionFocus.new()
	interaction_focus.name = "WorldInteractionFocus"
	add_child(interaction_focus)


func update_interaction_focus() -> void:
	if interaction_focus == null:
		return
	if current_interaction.is_empty():
		interaction_focus.clear_focus()
		return
	if current_interaction == "exit":
		interaction_focus.set_focus(EXIT_POSITION, "Castle Hall exit", true)
		return
	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			var focus_rect: Rect2 = _get_item_focus_rect(item)
			interaction_focus.set_focus(
				focus_rect.get_center(),
				str(item["label"]),
				true,
				focus_rect.size
			)
			return


## 把交互提示面板投影到交互物上方（世界坐标 → 屏幕坐标，跟随玩家视角）。
func _update_hint_screen_position(
	world_pos: Vector2,
	screen_offset: Vector2 = Vector2(0.0, -85.0)
) -> void:
	if interaction_hint_panel == null:
		return
	if follow_camera == null:
		interaction_hint_panel.position = Vector2(238, 696)
		return
	var cam_center: Vector2 = follow_camera.get_screen_center_position()
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	interaction_hint_panel.position = (
		viewport_center
		+ (world_pos - cam_center) * follow_camera.zoom
		+ screen_offset
	)


func create_follow_camera() -> void:
	if follow_camera != null:
		return

	follow_camera = Camera2D.new()
	follow_camera.name = "RoomFollowCamera"
	follow_camera.position = Vector2.ZERO
	camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)
	follow_camera.zoom = camera_target_zoom
	follow_camera.enabled = true
	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0
	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = int(ROOM_WIDTH)
	follow_camera.limit_bottom = int(ROOM_HEIGHT)
	follow_camera.limit_smoothed = false
	player.add_child(follow_camera)
	follow_camera.make_current()


func _get_player_collision_rect() -> Rect2:
	if player == null:
		return Rect2()
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return Rect2(player.global_position, Vector2.ZERO)
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(player.global_position, Vector2.ZERO)
	var size: Vector2 = rectangle.size * collision_shape.global_scale.abs()
	return Rect2(collision_shape.global_position - size * 0.5, size)


func _get_furniture_collision_rect(item_name: String) -> Rect2:
	if not prop_collision_bodies.has(item_name):
		return Rect2()
	var body: StaticBody2D = prop_collision_bodies[item_name] as StaticBody2D
	if body == null:
		return Rect2()
	var collision_shape: CollisionShape2D = body.get_node_or_null("FurnitureShape") as CollisionShape2D
	if collision_shape == null:
		return Rect2()
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()
	var size: Vector2 = rectangle.size * collision_shape.global_scale.abs()
	return Rect2(collision_shape.global_position - size * 0.5, size)


func _rect_gap(first: Rect2, second: Rect2) -> float:
	var horizontal_gap: float = maxf(
		maxf(second.position.x - first.end.x, first.position.x - second.end.x),
		0.0
	)
	var vertical_gap: float = maxf(
		maxf(second.position.y - first.end.y, first.position.y - second.end.y),
		0.0
	)
	return Vector2(horizontal_gap, vertical_gap).length()


func _is_player_touching_item(item: Dictionary) -> bool:
	var item_name: String = str(item["name"])
	if prop_collision_bodies.has(item_name):
		var player_rect: Rect2 = _get_player_collision_rect()
		var furniture_rect: Rect2 = _get_furniture_collision_rect(item_name)
		if furniture_rect.size != Vector2.ZERO:
			return _rect_gap(player_rect, furniture_rect) <= INTERACTION_CONTACT_MARGIN
	# 图纸类小物件用较大的距离判定，便于玩家靠近拾取。
	if item_name.begins_with("recipe_"):
		return player.global_position.distance_to(item["position"] as Vector2) <= RECIPE_INTERACT_RADIUS
	return player.global_position.distance_to(item["position"] as Vector2) <= LEGACY_CONTACT_RADIUS


func _create_rgb_filter_stand() -> void:
	if not rgb_filter_visuals.is_empty():
		return
	var stand: Node2D = Node2D.new()
	stand.name = "RGBFilterStand"
	stand.position = Vector2(724.0, 650.0)
	stand.z_index = 8
	add_child(stand)
	rgb_filter_visuals.append(stand)
	var colors: Array[Color] = [
		Color(0.82, 0.10, 0.10, 0.88),
		Color(0.18, 0.72, 0.24, 0.88),
		Color(0.16, 0.38, 0.92, 0.88),
	]
	for index: int in range(colors.size()):
		var filter: Polygon2D = Polygon2D.new()
		filter.name = ["RedFilter", "GreenFilter", "BlueFilter"][index]
		var x: float = -78.0 + float(index) * 60.0
		filter.polygon = PackedVector2Array([
			Vector2(x, -24.0),
			Vector2(x + 48.0, -24.0),
			Vector2(x + 48.0, 24.0),
			Vector2(x, 24.0),
		])
		filter.color = colors[index]
		stand.add_child(filter)
		rgb_filter_visuals.append(filter)
	var caption: Label = Label.new()
	caption.name = "RGBFilterCaption"
	caption.text = "R   G   B"
	caption.position = Vector2(-40.0, 32.0)
	caption.size = Vector2(80.0, 24.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 0.95))
	stand.add_child(caption)
	rgb_filter_visuals.append(caption)


func _use_rgb_filter(item_name: String) -> void:
	if GameState.has_story_flag("library_rgb_puzzle_solved"):
		item_message = "The red, green and blue filters remain active. Their combined pale light keeps the hidden archive text visible."
		interact_label.text = item_message
		return
	var flag_id: String = ""
	var color_name: String = ""
	match item_name:
		"rgb_red_filter":
			flag_id = "library_red_filter_active"
			color_name = "Red"
		"rgb_green_filter":
			flag_id = "library_green_filter_active"
			color_name = "Green"
		"rgb_blue_filter":
			flag_id = "library_blue_filter_active"
			color_name = "Blue"
		_:
			return
	if GameState.has_story_flag(flag_id):
		item_message = "%s light is already active in the optical stand." % color_name
		interact_label.text = item_message
		return
	GameState.set_story_flag(flag_id)
	var all_active: bool = (
		GameState.has_story_flag("library_red_filter_active")
		and GameState.has_story_flag("library_green_filter_active")
		and GameState.has_story_flag("library_blue_filter_active")
	)
	if all_active:
		GameState.set_story_flag("library_rgb_puzzle_solved")
		GameState.add_evidence("library_rgb_archive_layer")
		if NoteHud != null and not NoteHud.has_clue("library_rgb_archive_layer"):
			NoteHud.add_clue("library_rgb_archive_layer", {
				"title": "RGB Archive Filter",
				"content": "Red, green and blue light are all active in the optical stand. Their additive combination becomes a pale neutral light, revealing the layered diagram and the route to the Ashford Archive Record.",
				"category": "investigation",
			})
		item_message = "Red, green and blue combine into pale neutral light. The additive color key reveals the hidden archive text."
	else:
		item_message = "%s light is active. Activate the other two filters in any order; the archive will appear when all three colors overlap." % color_name
	interact_label.text = item_message


func update_interaction_prompt() -> void:
	current_interaction = ""
	interaction_hint_panel.visible = false

	for item: Dictionary in INTERACT_ITEMS:
		if _is_player_touching_item(item):
			current_interaction = str(item["name"])
			if item_message.is_empty():
				interact_label.text = (
					"Press E to inspect "
					+ str(item["label"])
				)
			else:
				interact_label.text = item_message
			interaction_hint_panel.visible = true
			_update_hint_screen_position(
				_get_item_prompt_anchor(item),
				Vector2(0.0, -18.0)
			)
			return

	if player.global_position.distance_to(EXIT_POSITION) <= EXIT_RADIUS:
		current_interaction = "exit"
		interact_label.text = "Press E to return to the Castle Hall"
		interaction_hint_panel.visible = true
		_update_hint_screen_position(EXIT_POSITION)
		return

	if not item_message.is_empty():
		item_message = ""


func try_interact() -> void:
	if current_interaction == "exit":
		return_to_castle_hall()
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			# 图纸拾取：加入配方并记录到侦探笔记。
			var item_name: String = str(item["name"])
			if item_name.begins_with("recipe_"):
				_collect_recipe(item_name)
				return
			if item_name.begins_with("rgb_"):
				_use_rgb_filter(item_name)
				return
			if item_name == "research_desk":
				_collect_archive_record()
				return
			item_message = str(item["message"])
			interact_label.text = item_message
			interaction_hint_panel.visible = true
			_update_hint_screen_position(
				_get_item_prompt_anchor(item),
				Vector2(0.0, -18.0)
			)
			return


func _collect_archive_record() -> void:
	if not GameState.has_story_flag("library_rgb_puzzle_solved") and not GameState.developer_mode:
		item_message = "The archive text is split into three color layers. Use the red, green and blue filters before copying the record."
		interact_label.text = item_message
		interaction_hint_panel.visible = true
		return
	if GameState.has_story_flag("library_archive_record_found"):
		if archive_book_visual != null:
			archive_book_visual.visible = true
		item_message = "You already copied the Ashford archive record into your notes."
		interact_label.text = item_message
		interaction_hint_panel.visible = true
		return
	GameState.set_story_flag("library_archive_record_found")
	GameState.set_story_flag("perfect_ending_library_ready")
	if archive_book_visual != null:
		archive_book_visual.visible = true
	GameState.add_evidence("ashford_archive_record")
	if NoteHud != null:
		NoteHud.add_clue("ashford_archive_record", {
			"title": "Ashford Archive Record",
			"content": (
				"A restricted archive card describes the Knowledge Engine and the castle's security network. "
				+ "Lord Ashford restricted the complete Knowledge Engine plans to the Master Archive. "
				+ "Several maintenance copies of Ashford engineering diagrams were produced without authorization, "
				+ "and the archive access records contain irregular maintenance-level requests. "
				+ "The archive route is hidden behind the final vault, and the security system can be redirected "
				+ "through the maintenance circuit. Whoever made those requests needed technical access, "
				+ "a route through the service systems, and a reason to create a blackout."
			),
			"category": "lore",
		})
	item_message = "Archive record copied. It links the Knowledge Engine to the maintenance circuit and the hidden service route."
	interact_label.text = item_message
	interaction_hint_panel.visible = true


func _collect_recipe(recipe_id: String) -> void:
	## 把图书馆图纸加入配方表（recipe_id -> recipe_xxx）。
	var recipe_key: String = ""
	if recipe_id == "recipe_swift_scroll":
		recipe_key = "recipe_swift"
	elif recipe_id == "recipe_vision_scroll":
		recipe_key = "recipe_vision"
	if recipe_key.is_empty():
		return
	if GameState.has_recipe(recipe_key):
		item_message = "You already copied this recipe into your notes."
		interact_label.text = item_message
		interaction_hint_panel.visible = true
		return
	GameState.add_recipe(recipe_key)
	var rinfo: Dictionary = GameState.RECIPE_INFO.get(recipe_key, {})
	item_message = "Recipe learned: %s" % str(rinfo.get("name", recipe_key))
	interact_label.text = item_message
	interaction_hint_panel.visible = true
	if NoteHud != null:
		NoteHud.add_clue(recipe_key, {
			"title": str(rinfo.get("name", recipe_key)),
			"content": str(rinfo.get("description", "")),
			"category": "recipe",
		})


func return_to_castle_hall() -> void:
	if scene_transitioning:
		return
	scene_transitioning = true
	room_input_enabled = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)

	GameState.prepare_return_to_hub(RETURN_SPAWN_ID)

	var change_error: Error = get_tree().change_scene_to_file(
		GameState.return_scene_path
	)
	if change_error != OK:
		scene_transitioning = false
		room_input_enabled = true
		player.set_physics_process(true)
		push_error(
			"Failed to return to Castle Hall. Error: "
			+ str(change_error)
		)
