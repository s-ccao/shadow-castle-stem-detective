extends Node2D

## Dining Hall — 宴会厅（用户提供 2a554008 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/dining_hall_banquet.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "dining_hall"
const RETURN_SPAWN_ID: String = "dining_hall_door"

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"dining_table": NodePath("Worldsort/DiningTable"),
	"fireplace": NodePath("Worldsort/Fireplace"),
	"wall_door": NodePath("Worldsort/WallDoor"),
	"grandfather_clock": NodePath("Worldsort/GrandfatherClock"),
	"sideboard": NodePath("Worldsort/Sideboard"),
	"cabinet": NodePath("Worldsort/Cabinet"),
	"main_door": NodePath("Worldsort/MainDoor")
}

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "dining_table",
		"label": "the banquet table",
		"position": Vector2(700.0, 660.0),
		"message": (
			"The long banquet table still bears the remnants of a feast. "
			+ "Wine stains and scattered cutlery tell a hurried story."
		)
	},
	{
		"name": "fireplace",
		"label": "the hearth",
		"position": Vector2(164.0, 390.0),
		"message": (
			"The hearth crackles warmly. Embers glow beneath the "
			+ "worn mantel."
		)
	},
	{
		"name": "wall_door",
		"label": "the barred door",
		"position": Vector2(1224.0, 300.0),
		"message": (
			"A heavy wooden door set in the stone wall. "
			+ "It is barred from the other side."
		)
	},
	{
		"name": "grandfather_clock",
		"label": "the grandfather clock",
		"position": Vector2(1330.0, 570.0),
		"message": (
			"The clock has stopped at midnight. Its pendulum hangs "
			+ "motionless."
		)
	},
	{
		"name": "sideboard",
		"label": "the laden sideboard",
		"position": Vector2(1283.0, 900.0),
		"message": (
			"A heavy sideboard laden with dishes and silver. "
			+ "A torn red cloth hangs over its front edge."
		)
	},
	{
		"name": "cabinet",
		"label": "the storage cabinet",
		"position": Vector2(138.0, 850.0),
		"message": (
			"A tall storage cabinet. Cookware and jugs crowd "
			+ "its dark shelves."
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
var _inspected_items: Array[String] = []
var interact_label: Label
var interaction_hint_panel: Panel
var ui_layer: CanvasLayer
var interaction_focus: WorldInteractionFocus
var prop_collision_bodies: Dictionary = {}
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


## 玩家在物品前方时物品降到玩家后面；玩家在物品后方时物品升到玩家前面。
## 直接设置实际 Sprite 的绝对 z-index，避免 Worldsort/Y-sort 父子顺序盖回玩家。
func _find_prop_sprite(prop: Node2D) -> Sprite2D:
	for child: Node in prop.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


func _update_prop_occlusion_layers() -> void:
	if player == null:
		return
	var player_rect: Rect2 = _get_player_collision_rect()
	for item_name_variant: Variant in PROP_NODE_PATHS.keys():
		var item_name: String = str(item_name_variant)
		var prop: Node2D = get_node_or_null(PROP_NODE_PATHS[item_name]) as Node2D
		if prop == null:
			continue
		var prop_visual: Sprite2D = _find_prop_sprite(prop)
		if prop_visual == null:
			continue
		var furn_rect: Rect2 = _get_furniture_collision_rect(item_name)
		if furn_rect.size == Vector2.ZERO:
			continue
		# 玩家脚底（碰撞盒底）低于家具碰撞盒顶 → 玩家在柜子前面/侧面，家具降层。
		# 玩家脚底高于家具碰撞盒顶 → 玩家在柜子后面，家具盖住玩家（正确的等距遮挡）。
		var target_z: int = (
			PROP_BACK_Z
			if player_rect.end.y <= furn_rect.position.y + 2.0
			else PROP_FRONT_Z
		)
		prop.z_index = 0
		prop_visual.z_as_relative = false
		prop_visual.z_index = target_z


func create_room_ui() -> void:
	# UI 独立图层：交互提示跟随交互物在世界中的位置投影到屏幕，
	# 相机移动时提示始终贴在物品旁边（跟随玩家视角）。
	ui_layer = CanvasLayer.new()
	ui_layer.name = "DiningRoomUI"
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
			push_warning("Dining Hall manual furniture collision missing: " + item_name)
			continue
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("prop_name", item_name)
		prop_collision_bodies[item_name] = body


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
		opaque_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_texture_opaque_rect_cache[texture_id] = opaque_rect
	return opaque_rect


## 从场景中真实 Sprite2D 的可见位置生成交互点。
func _sync_scene_interaction_points() -> void:
	for item: Dictionary in INTERACT_ITEMS:
		var item_name: String = str(item["name"])
		if PROP_NODE_PATHS.has(item_name):
			var prop: Node2D = get_node_or_null(PROP_NODE_PATHS[item_name]) as Node2D
			if prop == null:
				push_warning("Dining Hall interaction prop missing: " + item_name)
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
	return player.global_position.distance_to(item["position"] as Vector2) <= LEGACY_CONTACT_RADIUS


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


func _mark_dining_item(item_name: String) -> void:
	if _inspected_items.has(item_name):
		return
	_inspected_items.append(item_name)
	for item: Dictionary in INTERACT_ITEMS:
		if not _inspected_items.has(str(item["name"])):
			return
	if GameState.has_story_flag("dining_service_key_found"):
		return
	GameState.set_story_flag("dining_service_key_found")
	GameState.set_story_flag("dining_timeline_reconstructed")
	GameState.add_key("service_corridor_key")
	GameState.add_evidence("dining_timeline")
	_show_dining_note(
		"dining_timeline_reconstructed_note",
		"The Last Twenty Minutes",
		"The dining hall evidence reconstructs the missing interval: the meal ended, the clock was stopped by hand, the fire was disturbed, and someone used the service route after the blackout. Mrs. Lin's final note warns that the event was not an accident."
	)
	if NoteHud != null and not NoteHud.has_clue("mrs_lin_last_dining_note"):
		NoteHud.add_clue("mrs_lin_last_dining_note", {
			"title": "Mrs. Lin's Last Dining Note",
			"content": "\"The clock is a distraction. Follow the heat, the ash, and the service route. If the lights fail, do not trust the first person who claims to have been trapped. Someone knows I am following the route now. I can hear movement behind the wall. If you find this note, do not follow just because I did. Of course, you probably will.\"",
			"category": "investigation",
		})
	item_message = "The dining timeline is complete. Mrs. Lin's last note points toward the hidden service route. A cold key is hidden behind the wall door."


func _show_dining_note(note_id: String, title: String, content: String) -> void:
	if NoteHud.has_clue(note_id):
		return
	var parchment: Node = get_node_or_null("/root/ParchmentHud")
	if parchment != null:
		parchment.call(
			"show_parchment",
			title,
			content,
			note_id,
			{
				"title": title,
				"icon": "icon_note",
				"content": content,
				"category": "investigation",
			}
		)
		return
	NoteHud.add_clue(note_id, {
		"title": title,
		"icon": "icon_note",
		"content": content,
		"category": "investigation",
	})


func try_interact() -> void:
	if current_interaction == "exit":
		return_to_castle_hall()
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			var item_name: String = str(item["name"])
			if item_name == "dining_table":
				GameState.add_evidence("dining_timeline")
				_show_dining_note(
					"dining_timeline_note",
					"The Last Dinner Timeline",
					"The plates were cleared at 11:40. The clock stopped at midnight, but the fireplace ash is fresh. Someone moved through the hall during the missing twenty minutes."
				)
			if item_name == "grandfather_clock":
				GameState.add_evidence("stopped_midnight_clock")
				_show_dining_note(
					"dining_clock_note",
					"A Clock Stopped at Midnight",
					"The pendulum was stopped by hand. The minute hand is bent toward twelve, as if someone wanted the room to remember a false time."
				)
			if item_name == "sideboard":
				GameState.add_evidence("dining_red_cloth")
				_show_dining_note(
					"dining_red_cloth_note",
					"A Torn Red Cloth",
					"A strip of red fabric is caught on the silver drawer. Its threads match the service uniforms, not the table decorations."
				)
			if item_name == "fireplace":
				_show_dining_note(
					"dining_fireplace_note",
					"Fresh Ashes",
					"The fire is warm, but no log has burned evenly. Ash marks continue behind the hearth toward the barred wall door."
				)
			if item_name == "cabinet":
				_show_dining_note(
					"dining_cabinet_note",
					"The Service Passage Record",
					"A folded kitchen record names the service passage as the only route that bypasses the main corridor. The last entry is signed just before midnight."
				)
			_mark_dining_item(item_name)
			if item_name == "wall_door" and GameState.has_key("service_corridor_key"):
				item_message = "The Service Corridor Key fits the hidden lock. The passage lies behind the hall's east wall — the way back is marked in the Castle Hall."
				return_to_castle_hall()
				return
			else:
				item_message = str(item["message"])
			interact_label.text = item_message
			interaction_hint_panel.visible = true
			_update_hint_screen_position(
				_get_item_prompt_anchor(item),
				Vector2(0.0, -18.0)
			)
			return


func return_to_castle_hall() -> void:
	if scene_transitioning:
		return
	scene_transitioning = true
	room_input_enabled = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)

	# 调查完成后离开：敌人察觉玩家接近真相，进入追逐模式。
	if GameState.has_key("service_corridor_key"):
		GameState.set_story_flag("castle_guardian_activated")
		GameState.start_chase_mode()

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
