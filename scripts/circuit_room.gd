extends Node2D

## Circuit Room — 机械工坊（用户提供 b552a085 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。
## 物品坐标可先用 [MOUSE] 输出校准后填入 INTERACT_ITEMS。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/circuit_room_workshop.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "circuit_room"
const RETURN_SPAWN_ID: String = "circuit_door"

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const MECHANIC_POSITION: Vector2 = Vector2(930.0, 850.0)
const MECHANIC_INTERACT_RADIUS: float = 88.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"workbench": NodePath("Worldsort/Workbench"),
	"generator": NodePath("Worldsort/Generator"),
	"cabinet": NodePath("Worldsort/Cabinet")
}

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "workbench",
		"label": "the workbench",
		"position": Vector2(635.0, 700.0),
		"message": (
			"A cluttered workbench. Tools, coils and an open journal cover "
			+ "the surface. The last entry is cut off mid-sentence."
		)
	},
	{
		"name": "generator",
		"label": "the arcane generator",
		"position": Vector2(1120.0, 700.0),
		"message": (
			"A massive arcane generator. Blue arcs crackle behind its glass "
			+ "chamber. The mechanism still hums."
		)
	},
	{
		"name": "cabinet",
		"label": "the equipment cabinet",
		"position": Vector2(250.0, 660.0),
		"message": (
			"A reinforced equipment cabinet. Its padlock is firmly shut, "
			+ "but the keyhole glints as if recently used."
		)
	},
	{
		"name": "switch_left",
		"label": "the left power switch",
		"position": Vector2(210.0, 535.0),
		"message": "A left-side power switch. Its purpose is unclear."
	},
	{
		"name": "switch_right",
		"label": "the right power switch",
		"position": Vector2(1210.0, 595.0),
		"message": "A right-side power switch. Its purpose is unclear."
	},
	{
		"name": "master_switch",
		"label": "the master switch",
		"position": Vector2(705.0, 595.0),
		"message": "A large master power switch. Its purpose is unclear."
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
var _investigated_items: Array[String] = []
var _switch_states: Dictionary = {
	"switch_left": false,
	"switch_right": false,
	"master_switch": false,
}
var _switch_sequence_index: int = 0
var interact_label: Label
var interaction_hint_panel: Panel
var ui_layer: CanvasLayer
var interaction_focus: WorldInteractionFocus
var mechanic_npc: AnimatedNpc
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
	create_mechanic_npc()
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID
	_sync_debug_collision_visibility()
	if not GameState.state_changed.is_connected(_on_debug_state_changed):
		GameState.state_changed.connect(_on_debug_state_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
		GameState.toggle_developer_mode()
		_sync_debug_collision_visibility()
		get_viewport().set_input_as_handled()


func _on_debug_state_changed() -> void:
	_sync_debug_collision_visibility()


func _sync_debug_collision_visibility() -> void:
	get_tree().debug_collisions_hint = GameState.developer_mode


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
	ui_layer.name = "CircuitRoomUI"
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
			push_warning("Circuit Room manual furniture collision missing: " + item_name)
			continue
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("prop_name", item_name)
		prop_collision_bodies[item_name] = body


## 读取当前 Sprite2D 的真实可见像素矩形。
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
				push_warning("Circuit Room interaction prop missing: " + item_name)
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


func create_mechanic_npc() -> void:
	if mechanic_npc != null:
		return
	mechanic_npc = AnimatedNpc.new()
	mechanic_npc.name = "MechanicNPC"
	mechanic_npc.position = MECHANIC_POSITION
	mechanic_npc.z_index = 6
	mechanic_npc.configure(
		"Mechanic",
		"res://assets/characters/animated_pixel_v3/mechanic_walk.png",
		0.20,
		Vector2(18.0, 0.0),
		10.0,
		&"right"
	)
	$Worldsort.add_child(mechanic_npc)


func update_interaction_focus() -> void:
	if interaction_focus == null:
		return
	if current_interaction.is_empty():
		interaction_focus.clear_focus()
		return
	if current_interaction == "exit":
		interaction_focus.set_focus(EXIT_POSITION, "Castle Hall exit", true)
		return
	if current_interaction == "mechanic":
		interaction_focus.set_focus(MECHANIC_POSITION, "Mechanic", true)
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
	if mechanic_npc != null and player.global_position.distance_to(mechanic_npc.global_position) <= MECHANIC_INTERACT_RADIUS:
		current_interaction = "mechanic"
		interact_label.text = "Press E to talk to the Mechanic"
		interaction_hint_panel.visible = true
		_update_hint_screen_position(MECHANIC_POSITION, Vector2(0.0, -72.0))
		return

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
	if current_interaction == "mechanic":
		item_message = (
			"Mechanic: The blackout did not start here. Someone used the workshop's "
			+ "maintenance route, then left the generators to take the blame."
		)
		interact_label.text = item_message
		interaction_hint_panel.visible = true
		_update_hint_screen_position(MECHANIC_POSITION, Vector2(0.0, -72.0))
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			var item_name: String = str(item["name"])
			var item_message_override: String = ""
			if item_name == "switch_left" or item_name == "switch_right" or item_name == "master_switch":
				_handle_switch_interaction(item_name, item)
				return
			if item_name == "workbench" and not GameState.has_story_flag("circuit_distilled_water_found"):
				GameState.set_story_flag("circuit_distilled_water_found")
				GameState.add_material("distilled_water", 2)
				item_message_override = "A sealed flask of Distilled Water is tucked beneath the circuit journal."
			if item_name == "cabinet" and not GameState.has_story_flag("circuit_iron_salt_found"):
				GameState.set_story_flag("circuit_iron_salt_found")
				GameState.add_material("iron_salt")
				item_message_override = "A packet of Iron Salt rests behind the equipment cabinet's loose panel."
			if item_name == "cabinet" and not GameState.has_story_flag("violet_insulating_fiber_identified"):
				GameState.set_story_flag("violet_insulating_fiber_identified")
				GameState.add_evidence("violet_insulating_fiber")
				if NoteHud != null and not NoteHud.has_clue("violet_insulating_fiber_note"):
					NoteHud.add_clue("violet_insulating_fiber_note", {
						"title": "Violet Insulating Weave",
						"icon": "icon_note",
						"content": "The castle's electrical maintenance gloves and cable wraps use a distinctive violet insulating weave. It is a maintenance material, not proof that one particular worker committed a crime.",
						"category": "investigation",
					})
			if item_name == "cabinet" and not GameState.has_story_flag("mechanic_missing_glove_record_seen"):
				GameState.set_story_flag("mechanic_missing_glove_record_seen")
				GameState.add_evidence("mechanic_missing_glove")
				item_message_override = "A maintenance record is clipped behind the cabinet panel. It lists one pair of gloves assigned to the Mechanic. The right glove had a distinctive copper-thread cross-stitch repair and is missing after the blackout."
				if NoteHud != null and not NoteHud.has_clue("mechanic_missing_glove_record"):
					NoteHud.add_clue("mechanic_missing_glove_record", {
						"title": "Mechanic's Maintenance Glove Record",
						"icon": "icon_note",
						"content": "One pair of maintenance gloves was assigned to the Mechanic. The right glove had previously been repaired with a distinctive copper-thread cross-stitch. The right glove is now missing after the blackout. The same access log records the Mechanic's statement that he was checking the west-side electrical system during the blackout; the Dining timeline will test whether that account is possible.",
						"category": "investigation",
					})
			if item_name == "generator" and not GameState.has_story_flag("circuit_prism_dust_found"):
				GameState.set_story_flag("circuit_prism_dust_found")
				GameState.add_material("prism_dust")
				item_message_override = "Prism Dust glitters in the generator's maintenance tray."
			# 剧情：首次交互工作台 → 沾污的笔记页（故意短路证据）。
			if item_name == "workbench" and not NoteHud.has_clue("circuit_short_note"):
				NoteHud.add_clue("circuit_short_note", {
					"title": "A Stained Note Page",
					"icon": "icon_note",
					"content": (
						"[center][b]A Stained Note Page[/b][/center]\n\n"
						+ "A page smudged with oil and ash, tucked inside the workbench journal:\n\n"
						+ "\"...I checked the junction box myself. The burn pattern is [color=#7a2e2e]not accidental[/color].\n\n"
						+ "A deliberate [color=#7a2e2e]short circuit[/color] cut the power exactly when the castle went dark. Someone wanted the blackout...\""
					),
					"category": "investigation",
				})
				GameState.add_evidence("deliberate_short_circuit")
				GameState.set_story_flag("blackout_deliberate")
			item_message = item_message_override if not item_message_override.is_empty() else str(item["message"])
			_mark_circuit_investigation(item_name)
			interact_label.text = item_message
			interaction_hint_panel.visible = true
			_update_hint_screen_position(
				_get_item_prompt_anchor(item),
				Vector2(0.0, -18.0)
			)
			return


func _handle_switch_interaction(item_name: String, item: Dictionary) -> void:
	var sequence: Array[String] = ["switch_left", "switch_right", "master_switch"]
	var expected: String = sequence[_switch_sequence_index]
	if item_name != expected:
		_switch_sequence_index = 0
		for switch_id: String in sequence:
			_switch_states[switch_id] = false
			_update_switch_visual(switch_id, false)
		item_message = "Wrong sequence. The circuit resets. Follow the repair map from step 1."
	else:
		_switch_states[item_name] = true
		_switch_sequence_index += 1
		_update_switch_visual(item_name, true)
		if item_name == "master_switch":
			_update_switch_puzzle_state()
			item_message = "The master switch engages. The workshop power is restored."
		else:
			item_message = "The switch clicks into position. Continue to the next numbered switch."
	interact_label.text = item_message
	interaction_hint_panel.visible = true
	_update_hint_screen_position(_get_item_prompt_anchor(item), Vector2(0.0, -18.0))


func _update_switch_visual(switch_name: String, active: bool) -> void:
	if not active:
		return
	var node_name: String = (
		"SwitchLeft" if switch_name == "switch_left"
		else "SwitchRight" if switch_name == "switch_right"
		else "MasterSwitch"
	)
	var switch_node: Node2D = get_node_or_null("Worldsort/" + node_name) as Node2D
	if switch_node == null:
		return
	var plate: Polygon2D = switch_node.get_node_or_null("SwitchPlate") as Polygon2D
	if plate != null:
		plate.color = Color(0.20, 0.21, 0.20, 0.0)


func _update_switch_puzzle_state() -> void:
	if not bool(_switch_states["master_switch"]):
		return
	if GameState.learned_circuit_rule and GameState.circuit_door_open:
		return
	GameState.set_learned_circuit_rule(true)
	GameState.set_circuit_door_open(true)
	GameState.set_story_flag("circuit_power_restored")


func _mark_circuit_investigation(item_name: String) -> void:
	if not _investigated_items.has(item_name):
		_investigated_items.append(item_name)
	for required_item: String in ["workbench", "generator", "cabinet"]:
		if not _investigated_items.has(required_item):
			return
	if GameState.has_story_flag("circuit_dining_key_found"):
		return
	GameState.set_story_flag("circuit_dining_key_found")
	GameState.add_key("dining_hall_key")
	item_message = (
		"The three clues align: the blackout was deliberate, the generator "
		+ "was tampered with, and the equipment cabinet concealed a Dining Hall Key."
	)


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
