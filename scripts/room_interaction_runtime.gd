class_name RoomInteractionRuntime
extends Node

## Reusable room interaction Module.
##
## Its Interface is deliberately small: configure it once, refresh it each frame,
## present room-authored feedback, and optionally expose collision debug visuals.
## The owning room keeps its own puzzle rules and narrative consequences.

const DEFAULT_HINT_PANEL_POSITION := Vector2(238.0, 686.0)
const DEFAULT_HINT_PANEL_SIZE := Vector2(500.0, 68.0)
const ITEM_PROMPT_OFFSET := Vector2(0.0, -18.0)
const EXIT_PROMPT_OFFSET := Vector2(0.0, -85.0)
const FOCUS_PADDING := Vector2(10.0, 10.0)

var room: Node2D
var player: Node2D
var items: Array[Dictionary] = []
var prop_node_paths: Dictionary = {}
var prop_occlusion_paths: Array[NodePath] = []
var room_display_name := "Room"
var exit_position := Vector2.ZERO
var exit_radius := 80.0
var exit_rect := Rect2()
var interaction_contact_margin := RoomSpatialRuntime.DEFAULT_INTERACTION_MARGIN
var legacy_contact_radius := 20.0
var interaction_front_offset := Vector2(0.0, 28.0)
var gameplay_camera_zoom := Vector2.ONE
var developer_camera_zoom := Vector2.ONE
var room_size := Vector2.ZERO
var prop_front_z := -20
var prop_back_z := 20
var occlusion_mode := "collision_rect"

var follow_camera: Camera2D
var interaction_focus: WorldInteractionFocus
var interaction_hint_panel: Panel
var interact_label: Label
var prop_collision_bodies: Dictionary = {}
var _texture_opaque_rect_cache: Dictionary = {}
var spatial := RoomSpatialRuntime.new()
var _feedback_text := ""
var _prompt_position := Vector2.ZERO
var _prompt_offset := ITEM_PROMPT_OFFSET


func configure(
	configured_room: Node2D,
	configured_player: Node2D,
	config: Dictionary
) -> void:
	room = configured_room
	player = configured_player
	items = config.get("items", [])
	prop_node_paths = config.get("prop_node_paths", {})
	var configured_occlusion_paths: Array = config.get("prop_occlusion_paths", [])
	for configured_path: Variant in configured_occlusion_paths:
		prop_occlusion_paths.append(configured_path as NodePath)
	room_display_name = str(config.get("room_display_name", "Room"))
	exit_position = config.get("exit_position", Vector2.ZERO)
	exit_radius = float(config.get("exit_radius", exit_radius))
	exit_rect = config.get("exit_rect", exit_rect)
	if exit_rect.size.x <= 0.0 or exit_rect.size.y <= 0.0:
		exit_rect = Rect2(
			exit_position - Vector2.ONE * exit_radius * 0.5,
			Vector2.ONE * exit_radius
		)
	interaction_contact_margin = float(
		config.get("interaction_contact_margin", interaction_contact_margin)
	)
	legacy_contact_radius = float(
		config.get("legacy_contact_radius", legacy_contact_radius)
	)
	interaction_front_offset = config.get(
		"interaction_front_offset",
		interaction_front_offset
	)
	gameplay_camera_zoom = config.get("gameplay_camera_zoom", gameplay_camera_zoom)
	developer_camera_zoom = config.get("developer_camera_zoom", developer_camera_zoom)
	room_size = config.get("room_size", room_size)
	prop_front_z = int(config.get("prop_front_z", prop_front_z))
	prop_back_z = int(config.get("prop_back_z", prop_back_z))
	occlusion_mode = str(config.get("occlusion_mode", occlusion_mode))

	if prop_occlusion_paths.is_empty():
		for prop_path: Variant in prop_node_paths.values():
			prop_occlusion_paths.append(prop_path as NodePath)

	_create_prop_collisions()
	_sync_scene_interaction_points()
	if config.has("preferred_spawn"):
		var preferred_spawn := config.get("preferred_spawn", player.global_position) as Vector2
		player.global_position = spatial.resolve_safe_spawn(
			player as CharacterBody2D,
			preferred_spawn,
			Rect2(Vector2.ZERO, room_size)
		)
	_create_room_ui(str(config.get("ui_layer_name", room_display_name + "UI")))
	_create_follow_camera()
	_create_interaction_focus()


## Refresh collision-based interactions, UI focus, camera projection and occlusion.
## `priority_interaction` is for a room-owned actor that should take precedence
## over ordinary furniture, such as the Circuit Room mechanic.
func refresh(input_enabled: bool, priority_interaction: Dictionary = {}) -> String:
	_sync_scene_interaction_points()
	_update_prop_occlusion_layers()
	if not input_enabled:
		_clear_interaction()
		return ""

	if not priority_interaction.is_empty():
		return _show_priority_interaction(priority_interaction)

	for item: Dictionary in items:
		# A concealed device is not simply invisible: it must not offer a prompt,
		# a focus box or a contact band either, or the player can feel for it.
		if bool(item.get("concealed", false)):
			continue
		if _is_player_touching_item(item):
			var item_name := str(item["name"])
			var item_label := str(item["label"])
			var prompt := _feedback_text
			if prompt.is_empty():
				prompt = CaseLocale.line("Press E to inspect ") + CaseLocale.line(item_label)
			_show_prompt(prompt, _get_item_prompt_anchor(item), ITEM_PROMPT_OFFSET)
			_show_item_focus(item)
			return item_name

	if (
		player != null
		and spatial.is_actor_near_rect(
			player as CharacterBody2D,
			exit_rect,
			interaction_contact_margin
		)
	):
		_show_prompt(
			CaseLocale.line("Press E to return to the Castle Hall"),
			Vector2(exit_rect.get_center().x, exit_rect.position.y),
			EXIT_PROMPT_OFFSET
		)
		_show_exit_focus()
		return "exit"

	_clear_interaction()
	return ""


func present_feedback(text: String) -> void:
	# 在出口处翻译：房间里几百个 present_feedback("...") 调用点保持原样，
	# 也就不存在"漏改一处就永远是英文"的问题。
	text = CaseLocale.line(text)
	_feedback_text = text
	_show_prompt(text, _prompt_position, _prompt_offset)


func set_debug_collision_visibility(visible: bool) -> void:
	if room != null:
		room.get_tree().debug_collisions_hint = visible


func _show_priority_interaction(priority_interaction: Dictionary) -> String:
	var interaction_id := str(priority_interaction.get("id", ""))
	var label := str(priority_interaction.get("label", interaction_id))
	var position: Vector2 = priority_interaction.get("position", Vector2.ZERO)
	var interaction_rect: Rect2 = priority_interaction.get("interaction_rect", Rect2())
	var prompt := str(priority_interaction.get("prompt", CaseLocale.line("Press E to inspect ") + label))
	var offset: Vector2 = priority_interaction.get("prompt_offset", ITEM_PROMPT_OFFSET)
	if interaction_rect.size.x > 0.0 and interaction_rect.size.y > 0.0:
		position = Vector2(interaction_rect.get_center().x, interaction_rect.position.y)
	_show_prompt(prompt, position, offset)
	if interaction_focus != null:
		if interaction_rect.size.x > 0.0 and interaction_rect.size.y > 0.0:
			var focus_rect := spatial.grow_rect(interaction_rect, FOCUS_PADDING)
			interaction_focus.set_focus(
				focus_rect.get_center(),
				label,
				true,
				focus_rect.size
			)
		else:
			interaction_focus.set_focus(position, label, true)
	return interaction_id


func _clear_interaction() -> void:
	_feedback_text = ""
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = false
	if interaction_focus != null:
		interaction_focus.clear_focus()


func _show_prompt(text: String, world_position: Vector2, screen_offset: Vector2) -> void:
	if interaction_hint_panel == null or interact_label == null:
		return
	_prompt_position = world_position
	_prompt_offset = screen_offset
	interact_label.text = text
	interaction_hint_panel.visible = true
	_update_hint_screen_position(world_position, screen_offset)


func _show_item_focus(item: Dictionary) -> void:
	if interaction_focus == null:
		return
	var focus_rect := _get_item_focus_rect(item)
	interaction_focus.set_focus(
		focus_rect.get_center(),
		str(item["label"]),
		true,
		focus_rect.size
	)


func _show_exit_focus() -> void:
	if interaction_focus != null:
		var focus_rect := spatial.grow_rect(exit_rect, FOCUS_PADDING)
		interaction_focus.set_focus(
			focus_rect.get_center(),
			"Castle Hall exit",
			true,
			focus_rect.size
		)


func _create_room_ui(layer_name: String) -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = layer_name
	ui_layer.layer = 30
	room.add_child(ui_layer)

	interaction_hint_panel = Panel.new()
	interaction_hint_panel.name = "InteractionHint"
	interaction_hint_panel.position = DEFAULT_HINT_PANEL_POSITION
	interaction_hint_panel.size = DEFAULT_HINT_PANEL_SIZE
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.02, 0.015, 0.03, 0.88)
	hint_style.border_color = Color(0.62, 0.45, 0.18, 0.85)
	hint_style.set_border_width_all(2)
	hint_style.set_corner_radius_all(8)
	interaction_hint_panel.add_theme_stylebox_override("panel", hint_style)
	interaction_hint_panel.visible = false
	ui_layer.add_child(interaction_hint_panel)

	interact_label = Label.new()
	interact_label.name = "InteractLabel"
	interact_label.position = Vector2(16.0, 7.0)
	interact_label.size = Vector2(468.0, 54.0)
	interact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 14)
	interact_label.add_theme_color_override("font_color", Color(0.93, 0.82, 0.55, 1.0))
	interaction_hint_panel.add_child(interact_label)


func _create_interaction_focus() -> void:
	interaction_focus = WorldInteractionFocus.new()
	interaction_focus.name = "WorldInteractionFocus"
	room.add_child(interaction_focus)


func _create_follow_camera() -> void:
	follow_camera = Camera2D.new()
	follow_camera.name = "RoomFollowCamera"
	follow_camera.position = Vector2.ZERO
	follow_camera.zoom = GameState.get_room_camera_zoom(
		gameplay_camera_zoom,
		developer_camera_zoom
	)
	follow_camera.enabled = true
	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0
	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = int(room_size.x)
	follow_camera.limit_bottom = int(room_size.y)
	follow_camera.limit_smoothed = false
	player.add_child(follow_camera)
	follow_camera.make_current()


func _create_prop_collisions() -> void:
	for item_name_variant: Variant in prop_node_paths.keys():
		var item_name := str(item_name_variant)
		var prop := room.get_node_or_null(prop_node_paths[item_name]) as Node2D
		if prop == null:
			continue
		var body := prop.get_node_or_null("FurnitureCollision") as StaticBody2D
		var collision_shape: CollisionShape2D
		if body != null:
			collision_shape = body.get_node_or_null("FurnitureShape") as CollisionShape2D
		if body == null or collision_shape == null or collision_shape.shape == null:
			push_warning(room_display_name + " manual furniture collision missing: " + item_name)
			continue
		body.collision_layer = 1
		body.collision_mask = 1
		body.set_meta("prop_name", item_name)
		prop_collision_bodies[item_name] = body


func _sync_scene_interaction_points() -> void:
	for item: Dictionary in items:
		var item_name := str(item["name"])
		if not prop_node_paths.has(item_name):
			continue
		var prop := room.get_node_or_null(prop_node_paths[item_name]) as Node2D
		if prop == null:
			push_warning(room_display_name + " interaction prop missing: " + item_name)
			continue
		var visual_anchor := _get_prop_visual_anchor(prop)
		item["focus_position"] = visual_anchor
		item["position"] = visual_anchor + interaction_front_offset


func _update_prop_occlusion_layers() -> void:
	if player == null:
		return
	_update_visual_foot_occlusion_layers()


func _update_visual_foot_occlusion_layers() -> void:
	for item_name_variant: Variant in prop_node_paths.keys():
		var item_name := str(item_name_variant)
		var prop := room.get_node_or_null(prop_node_paths[item_name]) as Node2D
		if prop == null:
			continue
		prop.z_index = 0
		spatial.update_occlusion(
			player as CharacterBody2D,
			prop,
			prop_back_z,
			prop_front_z
		)


func _find_prop_sprite(prop: Node2D) -> Sprite2D:
	return spatial.find_visual_node(prop) as Sprite2D


func _get_prop_visual_rect(prop: Node2D) -> Rect2:
	return spatial.get_visual_rect(prop)


func _get_prop_visual_anchor(prop: Node2D) -> Vector2:
	return spatial.get_visual_feet(prop)


func _get_texture_opaque_rect(texture: Texture2D) -> Rect2i:
	var texture_id := texture.get_instance_id()
	if _texture_opaque_rect_cache.has(texture_id):
		return _texture_opaque_rect_cache[texture_id] as Rect2i
	var image := texture.get_image()
	if image == null:
		return Rect2i(0, 0, int(texture.get_width()), int(texture.get_height()))
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
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


func _get_item_focus_position(item: Dictionary) -> Vector2:
	if item.has("focus_position"):
		return item["focus_position"] as Vector2
	return item["position"] as Vector2


func _get_item_visual_rect(item: Dictionary) -> Rect2:
	if item.has("interaction_rect"):
		return item["interaction_rect"] as Rect2
	var item_name := str(item["name"])
	if prop_node_paths.has(item_name):
		var prop := room.get_node_or_null(prop_node_paths[item_name]) as Node2D
		if prop != null:
			var visual_rect := _get_prop_visual_rect(prop)
			if visual_rect.size.x > 0.0 and visual_rect.size.y > 0.0:
				return visual_rect
	var fallback_position := _get_item_focus_position(item)
	return Rect2(fallback_position - Vector2(56.0, 41.0), Vector2(112.0, 82.0))


func _get_item_focus_rect(item: Dictionary) -> Rect2:
	var visual_rect := _get_item_visual_rect(item)
	var padding := FOCUS_PADDING
	return Rect2(visual_rect.position - padding, visual_rect.size + padding * 2.0)


func _get_item_prompt_anchor(item: Dictionary) -> Vector2:
	var visual_rect := _get_item_visual_rect(item)
	return Vector2(visual_rect.get_center().x, visual_rect.position.y)


func _get_player_collision_rect() -> Rect2:
	return spatial.get_player_collision_rect(player as CharacterBody2D)


func _get_furniture_collision_rect(item_name: String) -> Rect2:
	if not prop_collision_bodies.has(item_name):
		return Rect2()
	var body := prop_collision_bodies[item_name] as StaticBody2D
	if body == null:
		return Rect2()
	var collision_shape := body.get_node_or_null("FurnitureShape") as CollisionShape2D
	if collision_shape == null:
		return Rect2()
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()
	var size := rectangle.size * collision_shape.global_scale.abs()
	return Rect2(collision_shape.global_position - size * 0.5, size)


## A device mounted on furniture cannot be stood on, so the surface the player
## reaches it from is not the surface that frames it. When a room declares an
## explicit contact band the player operates the device from walkable floor in
## front of it, while focus, prompt anchor and highlight still use the visible
## interaction rectangle.
func _get_item_contact_rect(item: Dictionary) -> Rect2:
	if item.has("contact_rect"):
		return item["contact_rect"] as Rect2
	return _get_item_visual_rect(item)


func _is_player_touching_item(item: Dictionary) -> bool:
	var target_rect := _get_item_contact_rect(item)
	if target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
		return spatial.is_actor_near_rect(
			player as CharacterBody2D,
			target_rect,
			interaction_contact_margin
		)
	var interaction_radius := float(item.get("interaction_radius", legacy_contact_radius))
	return player.global_position.distance_to(item["position"] as Vector2) <= interaction_radius


func _rect_gap(first: Rect2, second: Rect2) -> float:
	return spatial.rect_gap(first, second)


func _update_hint_screen_position(world_position: Vector2, screen_offset: Vector2) -> void:
	if interaction_hint_panel == null:
		return
	if follow_camera == null:
		interaction_hint_panel.position = DEFAULT_HINT_PANEL_POSITION
		return
	var camera_center := follow_camera.get_screen_center_position()
	var viewport_center := room.get_viewport().get_visible_rect().size / 2.0
	interaction_hint_panel.position = (
		viewport_center
		+ (world_position - camera_center) * follow_camera.zoom
		+ screen_offset
	)
	var viewport_size := room.get_viewport().get_visible_rect().size
	interaction_hint_panel.position.x = clampf(
		interaction_hint_panel.position.x,
		12.0,
		viewport_size.x - interaction_hint_panel.size.x - 12.0
	)
	interaction_hint_panel.position.y = clampf(
		interaction_hint_panel.position.y,
		12.0,
		viewport_size.y - interaction_hint_panel.size.y - 12.0
	)
