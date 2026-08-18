extends Node2D

const ROOM_WIDTH := 1024
const ROOM_HEIGHT := 768
const MRS_LIN_ID: String = "mrs_lin"
const MRS_LIN_DISPLAY_NAME: String = "Mrs. Lin"
const WALL_THICKNESS := 32
const NPC_DIALOGUE_PORTRAITS: Dictionary = {
	"Mrs. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Dr. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Mrs. Lin's Letter": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Butler": "res://assets/characters/portraits_pixel_v2/butler.png",
	"Gardener": "res://assets/characters/portraits_pixel_v2/gardener.png",
	"Mechanic": "res://assets/characters/portraits_pixel_v2/mechanic.png",
	"Castle Guardian": "res://assets/characters/portraits_pixel_v2/castle_guardian.png",
}

const USE_IMAGE_BACKGROUND := true
const WAKE_ROOM_BACKGROUND := "res://assets/backgrounds/wake_room_bg.png"

const SHOW_DEBUG_OBJECTS := false
const WALKABLE_MASK_PATH := \
	"res://assets/navigation/wake_room_walkable.png"

const PATH_CELL_SIZE := 16
const DIRECT_PATH_SAMPLE_STEP := 8.0
const PLAYER_CLEARANCE_RADIUS := 14.0
const SHOW_DEBUG_WALKABLE_MASK := false
const SHOW_DEBUG_PATH := true
@onready var player = $player

var ui_layer: CanvasLayer
var message_panel: Panel
var message_label: Label
var avatar_panel: Panel
var avatar_portrait: TextureRect
var avatar_name_label: Label
var message_scroll: ScrollContainer
var message_close_button: Button
var button_box: HBoxContainer
var interact_label: Label
var interaction_hint_panel: Panel
var interaction_focus: WorldInteractionFocus
var puzzle_panel: Panel
var puzzle_close_button: Button
var puzzle_question_label: Label
var puzzle_button_box: VBoxContainer
var puzzle_open := false
var top_left_bar: HBoxContainer
var notes_button: Button
var clue_journal: Node

var knowledge_panel: Panel
var knowledge_label: Label
var knowledge_panel_open := false
var notes_unlocked := false
var notes_tutorial_seen := false

# These are invisible interaction hotspots.
# Scene coords = room art pixels x 0.7072 (1024/1448 scale).
var door_position := Vector2(884, 438)
var clue_position := Vector2(509, 131)
var clue_approach_position := Vector2(509, 237)

# New room art (scholar chamber): interactable props
var bed_position := Vector2(503, 354)
var desk_position := Vector2(778, 212)
var bookshelf_position := Vector2(283, 177)
var window_position := Vector2(460, 127)

const DOOR_INTERACT_RADIUS := 150.0
const CLUE_INTERACT_RADIUS := 165.0
const PROP_INTERACT_RADIUS := 75.0
const SHOW_INTERACTION_MARKERS := false

@export var interaction_hint_position: Vector2 = Vector2(238, 696)
@export var interaction_hint_size: Vector2 = Vector2(548, 68)

## 调试开关：默认关闭。需要校准时可在 Inspector 勾选 Debug Print Click Position。
@export var debug_print_click_position := false
var _last_debug_mouse_position := Vector2(-100000, -100000)

# Interactable props: id -> {position, prompt, texture, description}
var props := {}
var mouse_over_prop := {}
var inspect_panel: Panel
var inspect_texture: TextureRect
var inspect_label: Label
var inspect_close_button: Button
var inspect_confirm_button: Button
var inspect_on_confirm: Callable
var current_inspect_confirm := ""
var scroll_panel: Panel
var scroll_texture: TextureRect
var scroll_label: Label
var scroll_close_button: Button
var scroll_continue_button: Button
var book_panel: Panel
var book_texture: TextureRect
var book_label_left: Label
var book_label_right: Label
var book_close_button: Button
var book_continue_button: Button
var book_rule_learned := false

const WAKE_ROOM_KEY_ID: String = "wake_room_key"
const WAKE_ROOM_KEY_TEXTURE: String = (
	"res://assets/ui/keyhub/wake_room_key.png"
)

const CHEMISTRY_ROOM_KEY_ID: String = "chemistry_room_key"
const CHEMISTRY_ROOM_KEY_TEXTURE: String = (
	"res://assets/ui/keyhub/chemistry_room_key.png"
)

var dialogue_active := false
var current_interaction := ""
var pending_mouse_interaction := ""
var click_marker: Node2D
var click_marker_tween: Tween
var first_lock_rule_learned := false
var exit_door_unlocked := false

var clue_node: ColorRect
var door_marker_node: ColorRect

var clue_click_area: Area2D
var mouse_over_clue := false
var door_click_area: Area2D

var mouse_over_door := false
var temporary_prompt_text := ""
var temporary_prompt_time_left := 0.0
var room_astar := AStarGrid2D.new()
var debug_path_line: Line2D
var walkable_mask_image: Image
var _user_collision_polys: Array = []
var debug_walkable_overlay: Sprite2D
func _ready():
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = "wake_room"
	GameState.set_room_visited("wake_room")

	# 你原来的代码继续……

	player.click_target_reached.connect(
		on_player_click_target_reached
	)

	player.ground_move_started.connect(
		on_player_ground_move_started
	)

	player.click_movement_cancelled.connect(
		on_player_click_movement_cancelled
	)

	player.click_movement_blocked.connect(
		on_player_click_movement_blocked
	)


	create_room()
	_collect_user_collisions()
	setup_room_pathfinding()
	create_debug_path_line()

	create_click_marker()
	create_door()
	create_first_room_clue()
	create_prop_interactions()
	create_interaction_focus()
	create_ui()
	create_inspect_ui()
	create_scroll_ui()
	create_book_ui()
	create_clue_journal()

	# 解锁状态持久化：从大厅返回时门保持解锁，不用再答题。
	exit_door_unlocked = GameState.wake_room_door_unlocked

	# 从大厅返回时出现在门内侧（door_position 附近）；
	# 首次进入才播放开场引导对话。
	if GameState.return_spawn_id == "wake_room_door":
		player.position = door_position + Vector2(-46, 0)
		if exit_door_unlocked and door_marker_node != null:
			door_marker_node.color = Color(0.25, 0.95, 0.45, 0.85)
	else:
		player.position = Vector2(500, 550)
		show_wake_dialogue()

func _process(delta):
	if temporary_prompt_time_left > 0.0:
		temporary_prompt_time_left = max(
			0.0,
		temporary_prompt_time_left - delta
	)

		if temporary_prompt_time_left <= 0.0:
			temporary_prompt_text = ""
	if Input.is_action_just_pressed("knowledge_journal"):
		if notes_unlocked:
			toggle_knowledge_panel()
		hide_interaction_feedback()
		return

	# E / ESC：任何交互面板打开时都可以随时关闭（防卡死）。
	# 必须放在 dialogue_active 检查之前：书/卷轴/检查面板打开时
	# dialogue_active=true，若不先处理关闭，玩家会被永久锁死。
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
		if _close_any_open_panel():
			hide_interaction_feedback()
			return

	if dialogue_active or puzzle_open or knowledge_panel_open:
		hide_interaction_feedback()
		return

	update_interaction_prompt()
	update_interaction_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = interact_label.visible

	if Input.is_action_just_pressed("interact"):
		cancel_pending_mouse_interaction()

		if current_interaction == "room_clue":
			show_first_room_clue()
		elif current_interaction == "door":
			handle_exit_door()
		elif current_interaction.begins_with("prop:"):
			var prop_id: String = current_interaction.trim_prefix("prop:")
			if props.has(prop_id):
				show_inspect(prop_id)


func _close_any_open_panel() -> bool:
	# 优先关闭最上层的交互面板；返回 true 表示已关闭。
	# 顺序：书（layer36）> 卷轴（layer35）> 检查 > 消息 > 谜题 > 知识面板。
	if book_panel != null and book_panel.visible:
		_on_book_close_pressed()
		return true
	if scroll_panel != null and scroll_panel.visible:
		_on_scroll_close_pressed()
		return true
	if inspect_panel != null and inspect_panel.visible:
		_on_inspect_close_pressed()
		return true
	if message_panel != null and message_panel.visible:
		close_message_panel()
		return true
	if puzzle_open:
		close_puzzle_overlay()
		return true
	if knowledge_panel_open:
		close_knowledge_panel()
		return true
	return false


func create_room():
	if USE_IMAGE_BACKGROUND:
		create_room_background()
	else:
		var floor = ColorRect.new()
		floor.color = Color(0.09, 0.085, 0.10, 1.0)
		floor.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
		floor.z_index = -10
		add_child(floor)

	# 物理碰撞全部由编辑器里的 CollisionPolygon2D 手动画出，
	# 代码不再生成任何碰撞体（参考大厅 wall_collisions.tscn 模式）。
	if SHOW_DEBUG_OBJECTS:
		var bed = ColorRect.new()
		bed.color = Color(0.18, 0.16, 0.22, 1.0)
		bed.position = Vector2(260, 320)
		bed.size = Vector2(150, 90)
		add_child(bed)

		var bed_label = Label.new()
		bed_label.text = "Wake Point"
		bed_label.position = Vector2(285, 290)
		bed_label.add_theme_font_size_override("font_size", 14)
		add_child(bed_label)

		var desk = ColorRect.new()
		desk.color = Color(0.20, 0.14, 0.08, 1.0)
		desk.position = Vector2(160, 160)
		desk.size = Vector2(150, 55)
		add_child(desk)

		var note = Label.new()
		note.text = "Old Notes"
		note.position = Vector2(190, 130)
		note.add_theme_font_size_override("font_size", 14)
		add_child(note)

func setup_room_pathfinding():
	if not load_walkable_mask():
		return

	var column_count := int(
		ceil(
			float(ROOM_WIDTH)
			/ PATH_CELL_SIZE
		)
	)

	var row_count := int(
		ceil(
			float(ROOM_HEIGHT)
			/ PATH_CELL_SIZE
		)
	)

	room_astar.region = Rect2i(
		0,
		0,
		column_count,
		row_count
	)

	room_astar.cell_size = Vector2(
		PATH_CELL_SIZE,
		PATH_CELL_SIZE
	)

	room_astar.offset = Vector2(
		PATH_CELL_SIZE / 2.0,
		PATH_CELL_SIZE / 2.0
	)

	room_astar.diagonal_mode = (
		AStarGrid2D
		.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	)

	room_astar.update()

	for x in range(column_count):
		for y in range(row_count):
			var cell := Vector2i(x, y)

			var cell_center := Vector2(
				x * PATH_CELL_SIZE
					+ PATH_CELL_SIZE / 2.0,
				y * PATH_CELL_SIZE
					+ PATH_CELL_SIZE / 2.0
			)

			var cell_is_blocked := (
				not is_player_position_walkable(
					cell_center
				)
			)

			room_astar.set_point_solid(
				cell,
				cell_is_blocked
			)
	if SHOW_DEBUG_WALKABLE_MASK:
		create_debug_walkable_overlay()

func create_debug_walkable_overlay():
	if walkable_mask_image == null:
		return

	var overlay_image: Image = Image.create(
		walkable_mask_image.get_width(),
		walkable_mask_image.get_height(),
		false,
		Image.FORMAT_RGBA8
	)

	var image_width: int = walkable_mask_image.get_width()
	var image_height: int = walkable_mask_image.get_height()

	for x in range(image_width):
		for y in range(image_height):
			var mask_color: Color = walkable_mask_image.get_pixel(
				x,
				y
			)

			var is_floor: bool = (
				mask_color.a > 0.5
				and mask_color.r > 0.5
				and mask_color.g > 0.5
				and mask_color.b > 0.5
			)

			if is_floor:
				# Green means walkable floor.
				overlay_image.set_pixel(
					x,
					y,
					Color(0.1, 1.0, 0.25, 0.22)
				)
			else:
				# Red means blocked.
				overlay_image.set_pixel(
					x,
					y,
					Color(1.0, 0.1, 0.1, 0.18)
				)

	var overlay_texture: ImageTexture = ImageTexture.create_from_image(
		overlay_image
	)

	debug_walkable_overlay = Sprite2D.new()
	debug_walkable_overlay.name = "DebugWalkableOverlay"
	debug_walkable_overlay.texture = overlay_texture
	debug_walkable_overlay.centered = false
	debug_walkable_overlay.position = Vector2.ZERO
	debug_walkable_overlay.z_index = 15

	add_child(debug_walkable_overlay)


func create_room_background():
	# 背景已放入 wake_room.tscn（编辑器可见可编辑）时跳过代码创建。
	if get_node_or_null("WakeRoomBackground") != null:
		return

	var texture = load(WAKE_ROOM_BACKGROUND)

	if texture == null:
		push_warning("Wake room background image not found: " + WAKE_ROOM_BACKGROUND)

		var fallback_floor = ColorRect.new()
		fallback_floor.color = Color(0.09, 0.085, 0.10, 1.0)
		fallback_floor.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
		fallback_floor.z_index = -10
		add_child(fallback_floor)
		return

	var background = Sprite2D.new()
	background.name = "WakeRoomBackground"
	background.texture = texture
	background.centered = false
	background.position = Vector2.ZERO
	background.z_index = -100

	var texture_size = texture.get_size()
	background.scale = Vector2(
		float(ROOM_WIDTH) / texture_size.x,
		float(ROOM_HEIGHT) / texture_size.y
	)

	add_child(background)


func create_door():
	# 门交互位置跟随用户画的 CollisionPolygon2D（Props/Door）。
	var door_node: Node = get_node_or_null("Props/Door")
	if door_node is Area2D:
		var door_poly: CollisionPolygon2D = door_node.get_node_or_null(
			"CollisionPolygon2D"
		) as CollisionPolygon2D
		if door_poly != null and door_poly.polygon.size() >= 2:
			var world_poly := _get_world_polygon(door_poly)
			door_position = _get_reachable_point(world_poly)

	if SHOW_DEBUG_OBJECTS:
		var door = ColorRect.new()
		door.name = "ExitDoor"
		door.color = Color(0.75, 0.45, 0.16, 1.0)
		door.size = Vector2(34, 96)
		door.position = door_position - door.size / 2
		door.z_index = 4
		add_child(door)

		var label = Label.new()
		label.text = "Castle Door"
		label.position = door_position + Vector2(-42, -70)
		label.add_theme_font_size_override("font_size", 15)
		add_child(label)

	if SHOW_INTERACTION_MARKERS:
		door_marker_node = ColorRect.new()
		door_marker_node.name = "DoorInteractionMarker"
		door_marker_node.color = Color(0.75, 0.45, 1.0, 0.75)
		door_marker_node.size = Vector2(18, 18)
		door_marker_node.position = door_position - door_marker_node.size / 2
		door_marker_node.z_index = 20
		add_child(door_marker_node)

	# 鼠标热点始终存在；静态调试标记可以独立关闭。
	door_click_area = create_mouse_hotspot(
		"ExitDoorClickArea",
		door_position,
		Vector2(100, 160)
	)
	door_click_area.mouse_entered.connect(
		on_door_mouse_entered
	)
	door_click_area.mouse_exited.connect(
		on_door_mouse_exited
	)
	door_click_area.input_event.connect(
		on_door_input_event
	)

func create_prop_interactions():
	# 房间里的可交互物品（用户提供的道具插图）：
	# 床 / 书桌 / 书架。点击或靠近按 E 打开检查面板。
	props["bed"] = {
		"position": bed_position,
		"prompt": "the bed",
		"texture": WAKE_ROOM_KEY_TEXTURE,
		"description": "A narrow wooden bed with a rumpled purple blanket.\n\nSomething hard is tucked beneath the pillow: a brass key bearing a red Ashford seal. It may belong to the Wake Room exit.",
	}
	props["desk"] = {
		"position": desk_position,
		"prompt": "the study desk",
		"texture": "res://assets/sprites/wake_room/scroll_clue.png",
		"description": "A rolled parchment lies open on the desk.\n\nIt reads:\n\n\"The master of this castle is said to be a man who loved knowledge. They say every door in this castle holds a question — answer it correctly, and even without a key, the door will open.\"\n\n— Mrs. Lin\n\nYou always reach for an answer before checking the evidence. Do not do that here.\n\n(Clue added to your notes. Press K or click the Notes button to review all collected clues.)",
	}
	props["bookshelf"] = {
		"position": bookshelf_position,
		"prompt": "the bookshelf",
		"texture": "res://assets/sprites/wake_room/bookshelf.png",
		"description": "An old bookshelf packed with dusty volumes.\n\nOne book stands out: \"The Knowledge Locks of Ashford Castle.\"\n\nA passage is underlined:\n\n\"Every locked door holds a question, and the answer can always be found somewhere in the room before it.\"",
	}

	var props_root: Node = get_node_or_null("Props")

	for id in props.keys():
		var p: Dictionary = props[id]
		p["focus_position"] = p["position"]
		mouse_over_prop[id] = false

		var area: Area2D = null
		if props_root != null:
			# 场景节点名是首字母大写（Bed/Desk/Bookshelf），key 是小写。
			var scene_node: Node = props_root.get_node_or_null(id.capitalize())
			if scene_node is Area2D:
				# 复用 tscn 里的热点（编辑器可见可拖）。
				area = scene_node as Area2D
				var focus_point: Node2D = area.get_node_or_null(
					"InteractionFocusPoint"
				) as Node2D
				if focus_point != null:
					p["focus_position"] = focus_point.global_position
				else:
					p["focus_position"] = area.global_position
				# 交互位置 = 用户画的 CollisionPolygon2D 中心（世界坐标），
				# 这样交互点跟随用户设置的碰撞形状。
				var poly: CollisionPolygon2D = area.get_node_or_null(
					"CollisionPolygon2D"
				) as CollisionPolygon2D
				if poly != null and poly.polygon.size() >= 2:
					var world_poly := _get_world_polygon(poly)
					p["position"] = _get_reachable_point(world_poly)
				else:
					p["position"] = area.position

		if area == null:
			area = create_mouse_hotspot(
				id + "ClickArea",
				p["position"],
				Vector2(96, 96)
			)
		area.mouse_entered.connect(_on_prop_mouse_entered.bind(id))
		area.mouse_exited.connect(_on_prop_mouse_exited.bind(id))
		area.input_event.connect(_on_prop_input_event.bind(id))

		# tscn 节点自带 Visual（物品缩略图），无需再画调试标记。
		if area.get_node_or_null("Visual") == null and SHOW_INTERACTION_MARKERS:
			var marker := ColorRect.new()
			marker.name = id + "Marker"
			marker.color = Color(0.35, 0.9, 0.95, 0.6)
			marker.size = Vector2(14, 14)
			marker.position = (p["position"] as Vector2) - marker.size / 2
			marker.z_index = 20
			add_child(marker)


func _on_prop_mouse_entered(id: String):
	mouse_over_prop[id] = true
	update_world_cursor()


func _on_prop_mouse_exited(id: String):
	mouse_over_prop[id] = false
	update_world_cursor()


func _on_prop_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	id: String
):
	if dialogue_active or puzzle_open or knowledge_panel_open:
		# 面板开着时点物品：不自动关面板，等玩家主动取消（X / E / ESC）。
		return
	if inspect_panel != null and inspect_panel.visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			var p: Dictionary = props[id]
			if player.global_position.distance_to(p["position"]) <= PROP_INTERACT_RADIUS:
				show_inspect(id)
			else:
				# 走位前先确认可达，避免寻路失败导致交互卡死。
				if calculate_room_path(
					player.global_position,
					p["position"]
				).is_empty():
					temporary_prompt_text = "Can't reach that spot."
					temporary_prompt_time_left = 2.0
					return
				pending_mouse_interaction = id


func create_inspect_ui() -> void:
	# 物品检查对话框：屏幕下半 1/3，左侧物品图，右侧描述，
	# 右上角 X 退出交互状态。
	# create_ui() 已经创建并挂载了 ui_layer（layer=30）。
	# 这里必须复用同一个 CanvasLayer——若重新 new 一个未挂载的层，
	# inspect_panel 永远不在场景树中，visible=true 也不渲染（假卡死根因）。
	if ui_layer == null:
		push_error("Inspect UI could not be created because ui_layer is null.")
		return

	inspect_panel = Panel.new()
	inspect_panel.name = "InspectPanel"
	# 自适应视口：宽 = 视口宽 - 24，高 = 视口高 * 0.38（下限 280）。
	# 之前固定 1024×256，在小窗口（如 1022×767）右缘/底缘会被裁切，
	# 按钮文字显示不完整。
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = max(800.0, vp_size.x - 24.0)
	var panel_h: float = max(280.0, vp_size.y * 0.38)
	inspect_panel.size = Vector2(panel_w, panel_h)
	inspect_panel.position = Vector2(12, vp_size.y - panel_h - 12)
	inspect_panel.visible = false
	inspect_panel.z_index = 50

	ui_layer.add_child(inspect_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	inspect_panel.add_theme_stylebox_override("panel", style)

	inspect_texture = TextureRect.new()
	inspect_texture.name = "InspectTexture"
	inspect_texture.position = Vector2(24, 24)
	inspect_texture.size = Vector2(200, 200)
	inspect_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspect_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspect_panel.add_child(inspect_texture)

	inspect_label = Label.new()
	inspect_label.name = "InspectLabel"
	inspect_label.position = Vector2(244, 24)
	inspect_label.size = Vector2(panel_w - 284, panel_h - 110)
	inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_label.add_theme_font_size_override("font_size", 17)
	inspect_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	inspect_panel.add_child(inspect_label)

	inspect_close_button = Button.new()
	inspect_close_button.name = "InspectCloseButton"
	inspect_close_button.text = "X"
	inspect_close_button.position = Vector2(panel_w - 60, 14)
	inspect_close_button.size = Vector2(36, 36)
	inspect_close_button.add_theme_font_size_override("font_size", 20)
	inspect_close_button.pressed.connect(_on_inspect_close_pressed)
	inspect_panel.add_child(inspect_close_button)

	inspect_confirm_button = Button.new()
	inspect_confirm_button.name = "InspectConfirmButton"
	inspect_confirm_button.text = "Continue"
	# 右下角，加宽到 280 保证 "Approach the knowledge lock" 不裁切。
	inspect_confirm_button.position = Vector2(panel_w - 292, panel_h - 62)
	inspect_confirm_button.size = Vector2(280, 44)
	inspect_confirm_button.visible = false
	inspect_confirm_button.pressed.connect(_on_inspect_confirm_pressed)
	inspect_panel.add_child(inspect_confirm_button)


func show_inspect(id: String):
	if not props.has(id):
		return
	var p: Dictionary = props[id]

	# 床 → 第一把实体钥匙，钥匙拾取后 Key Hub 自动解锁。
	if id == "bed":
		show_wake_room_key_inspect()
		return

	# 书桌 → 先做一遍烛火实验，做完才给卷轴。苏醒室那道门问的就是
	# "火焰要从空气里得到什么"，这个练习把它从背答案变成想明白。
	if id == "desk":
		if GameState.has_story_flag("wake_flame_drilled"):
			show_scroll_clue()
		else:
			_open_flame_minigame()
		return

	# 书架 → 居中大书（知识剧情），知识点收进笔记。
	if id == "bookshelf":
		show_book_clue()
		return

	start_dialogue_pause()

	var texture: Texture2D = load(p["texture"])
	if texture != null:
		inspect_texture.texture = texture
	inspect_label.text = p["description"]
	inspect_confirm_button.visible = false
	_show_dialogue(inspect_panel)


func show_wake_room_key_inspect() -> void:
	start_dialogue_pause()
	current_inspect_confirm = "wake_room_key"
	var texture: Texture2D = load(WAKE_ROOM_KEY_TEXTURE) as Texture2D
	if texture != null:
		inspect_texture.texture = texture
	if GameState.has_key(WAKE_ROOM_KEY_ID):
		inspect_label.text = (
			"The pillow hides an empty space where the brass key was found.\n\n"
			+ "The key is already recorded in your Key Hub."
		)
		inspect_confirm_button.visible = false
	else:
		inspect_label.text = (
			"Beneath the pillow rests a brass key bearing a red Ashford seal.\n\n"
			+ "This is the key to the Wake Room exit. A small blue-gold glint appears at the edge of the room, as if a new place in your casework has awakened."
		)
		inspect_confirm_button.visible = true
		inspect_confirm_button.text = "Take the Wake Room Key"
	_show_dialogue(inspect_panel)


func show_chemistry_key_inspect() -> void:
	start_dialogue_pause()
	current_inspect_confirm = "chemistry_room_key"
	var texture: Texture2D = load(CHEMISTRY_ROOM_KEY_TEXTURE) as Texture2D
	if texture != null:
		inspect_texture.texture = texture
	if GameState.has_key(CHEMISTRY_ROOM_KEY_ID):
		inspect_label.text = (
			"The gap behind the book is empty now.\n\n"
			+ "The Chemistry Room key is already recorded in your Key Hub."
		)
		inspect_confirm_button.visible = false
	else:
		inspect_label.text = (
			"Behind the books, Mrs. Lin has left a heavy laboratory key.\n\n"
			+ "\"I am leaving the Chemistry Room key here. After you leave this room, follow the purple marks I left behind. Do not cross the middle of the hall — it is not safe.\n\n— Mrs. Lin\""
		)
		inspect_confirm_button.visible = true
		inspect_confirm_button.text = "Take the Chemistry Room Key"
	_show_dialogue(inspect_panel)


func show_door_inspect():
	# 知识锁门：先展示门图，再进入谜题流程。
	start_dialogue_pause()
	current_inspect_confirm = "door"

	var texture: Texture2D = load("res://assets/sprites/wake_room/door_magical.png")
	if texture != null:
		inspect_texture.texture = texture
	inspect_label.text = "A massive armored door bars the way into the castle hall.\n\nPurple crystals pulse along its frame, and a large golden lock wheel glows at its center.\n\nMrs. Lin:\nLord Ashford sealed every passage with a knowledge lock. The question will be written on the lock — the answer is always hidden somewhere in this room."
	inspect_confirm_button.visible = true
	inspect_confirm_button.text = "Approach the knowledge lock"
	_show_dialogue(inspect_panel)


func _on_inspect_close_pressed():
	inspect_panel.visible = false
	end_dialogue_pause()


func _on_inspect_confirm_pressed():
	inspect_panel.visible = false
	end_dialogue_pause()

	if current_inspect_confirm == "wake_room_key":
		GameState.add_key(WAKE_ROOM_KEY_ID)
		inspect_confirm_button.visible = false
		current_inspect_confirm = ""
		return

	if current_inspect_confirm == "chemistry_room_key":
		GameState.add_key(CHEMISTRY_ROOM_KEY_ID)
		inspect_confirm_button.visible = false
		current_inspect_confirm = ""
		return

	if current_inspect_confirm == "door":
		if not GameState.has_key(WAKE_ROOM_KEY_ID):
			show_no_key_hint()
		elif first_lock_rule_learned:
			show_first_door_question()
		else:
			show_locked_door_intro()


func create_scroll_ui():
	# 书桌卷轴：屏幕正中央的大卷轴图 + 右上角 X + 卷轴上的文字。
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)

	scroll_panel = Panel.new()
	scroll_panel.name = "ScrollPanel"
	# IGNORE：让点击穿透到场景（书桌/门 Area2D），
	# 否则开着卷轴时点门会被面板吞掉，配合 dialogue 自动关面板防卡死。
	scroll_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_panel.position = Vector2(262, 9)
	scroll_panel.size = Vector2(500, 750)
	scroll_panel.visible = false
	layer.add_child(scroll_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	scroll_panel.add_theme_stylebox_override("panel", style)

	scroll_texture = TextureRect.new()
	scroll_texture.name = "ScrollTexture"
	scroll_texture.position = Vector2.ZERO
	scroll_texture.size = scroll_panel.size
	scroll_texture.texture = load("res://assets/sprites/wake_room/scroll_clue.png")
	scroll_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scroll_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll_panel.add_child(scroll_texture)

	# 卷轴中央的书写区：文字集中在纸面内，不超出卷轴边缘。
	# 贴图 1024×1536 等比铺满 500×750 面板（比例一致无黑边），
	# 纸面实体位于面板 (129,85)-(397,650)；文字区留边距放在纸面中央。
	scroll_label = Label.new()
	scroll_label.name = "ScrollLabel"
	scroll_label.position = Vector2(154, 108)
	scroll_label.size = Vector2(218, 520)
	scroll_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll_label.add_theme_font_size_override("font_size", 16)
	scroll_label.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06, 1.0))
	scroll_panel.add_child(scroll_label)

	# 卷轴右上角 X：退出查看。
	scroll_close_button = Button.new()
	scroll_close_button.name = "ScrollCloseButton"
	scroll_close_button.text = "X"
	scroll_close_button.position = Vector2(444, 22)
	scroll_close_button.size = Vector2(36, 36)
	scroll_close_button.add_theme_font_size_override("font_size", 20)
	scroll_close_button.pressed.connect(_on_scroll_close_pressed)
	scroll_panel.add_child(scroll_close_button)

	# 书桌交互结束后，Continue 与 X 都会进入路线 MapHub。
	scroll_continue_button = Button.new()
	scroll_continue_button.name = "ScrollContinueButton"
	scroll_continue_button.text = "Continue to the route map"
	scroll_continue_button.position = Vector2(144.0, 672.0)
	scroll_continue_button.size = Vector2(212.0, 42.0)
	scroll_continue_button.add_theme_font_size_override("font_size", 14)
	scroll_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var map_continue_style: StyleBoxFlat = StyleBoxFlat.new()
	map_continue_style.bg_color = Color(0.13, 0.09, 0.05, 0.96)
	map_continue_style.border_color = Color(0.82, 0.62, 0.24, 1.0)
	map_continue_style.set_border_width_all(2)
	map_continue_style.set_corner_radius_all(8)
	scroll_continue_button.add_theme_stylebox_override("normal", map_continue_style)
	var map_continue_hover: StyleBoxFlat = map_continue_style.duplicate()
	map_continue_hover.bg_color = Color(0.19, 0.13, 0.06, 0.98)
	map_continue_hover.border_color = Color(0.96, 0.76, 0.34, 1.0)
	scroll_continue_button.add_theme_stylebox_override("hover", map_continue_hover)
	scroll_continue_button.add_theme_color_override(
		"font_color",
		Color(0.96, 0.76, 0.34, 1.0)
	)
	scroll_continue_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.93, 0.65, 1.0)
	)
	scroll_continue_button.pressed.connect(_on_scroll_continue_pressed)
	scroll_panel.add_child(scroll_continue_button)


func show_scroll_clue() -> void:
	# 书桌卷轴：居中大图 + 内容 + 线索系统激活。
	start_dialogue_pause()

	if not first_lock_rule_learned:
		first_lock_rule_learned = true
		unlock_notes_tool()
		update_knowledge_panel_text()
		if clue_journal != null:
			clue_journal.add_clue("scroll_clue")

	scroll_label.text = "To whoever finds this —\n\nThe master of this castle loved knowledge. His doors open neither for keys alone, nor for answers alone.\n\nFirst find the physical key that belongs to a door. Insert it, and only then will the knowledge lock awaken and pose its question.\n\nThe answer is always hidden nearby. Do not guess — read, observe, understand.\n\nIf you are reading this, I may already be gone.\n\n— Mrs. Lin"
	_show_dialogue(scroll_panel)


func _on_scroll_close_pressed():
	scroll_panel.visible = false
	end_dialogue_pause()
	if MapHud != null:
		MapHud.unlock_and_open()


func _on_scroll_continue_pressed() -> void:
	scroll_panel.visible = false
	end_dialogue_pause()
	if MapHud != null:
		MapHud.unlock_and_open()


func create_book_ui():
	# 书架知识书：屏幕正中央的展开古书 + 右上角 X + 书页上的知识文字。
	var layer := CanvasLayer.new()
	layer.layer = 36
	add_child(layer)

	book_panel = Panel.new()
	book_panel.name = "BookPanel"
	# IGNORE：让点击穿透到场景（书架/门 Area2D），防卡死（同卷轴）。
	book_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_panel.position = Vector2(62, 84)
	book_panel.size = Vector2(900, 600)
	book_panel.visible = false
	layer.add_child(book_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	book_panel.add_theme_stylebox_override("panel", style)

	book_texture = TextureRect.new()
	book_texture.name = "BookTexture"
	book_texture.position = Vector2.ZERO
	book_texture.size = book_panel.size
	book_texture.texture = load("res://assets/sprites/wake_room/book_clue.png")
	book_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	book_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book_panel.add_child(book_texture)

	# 书页书写区：贴图 1536×1024 等比铺满 900×600 面板（比例一致无黑边），
	# 书页浅色实体位于面板 (173,96)-(757,480)，中央书脊 x≈465；
	# 文字分左右两页，各留边距，不压到书脊与装订线。
	book_label_left = Label.new()
	book_label_left.name = "BookLabelLeft"
	book_label_left.position = Vector2(198, 122)
	book_label_left.size = Vector2(245, 335)
	book_label_left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book_label_left.add_theme_font_size_override("font_size", 19)
	book_label_left.add_theme_color_override("font_color", Color(0.20, 0.12, 0.05, 1.0))
	book_panel.add_child(book_label_left)

	book_label_right = Label.new()
	book_label_right.name = "BookLabelRight"
	book_label_right.position = Vector2(487, 122)
	book_label_right.size = Vector2(245, 335)
	book_label_right.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book_label_right.add_theme_font_size_override("font_size", 19)
	book_label_right.add_theme_color_override("font_color", Color(0.20, 0.12, 0.05, 1.0))
	book_panel.add_child(book_label_right)

	# 书右上角 X：退出查看。
	book_close_button = Button.new()
	book_close_button.name = "BookCloseButton"
	book_close_button.text = "X"
	book_close_button.position = Vector2(842, 14)
	book_close_button.size = Vector2(36, 36)
	book_close_button.add_theme_font_size_override("font_size", 20)
	book_close_button.pressed.connect(_on_book_close_pressed)
	book_panel.add_child(book_close_button)

	# 书架教学读完后：Continue 进入 Chemistry Room Key 领取。
	book_continue_button = Button.new()
	book_continue_button.name = "BookContinueButton"
	book_continue_button.text = "Continue"
	book_continue_button.position = Vector2(620, 536)
	book_continue_button.size = Vector2(180, 42)
	book_continue_button.visible = false
	book_continue_button.add_theme_font_size_override("font_size", 17)
	# 旧铜金风格：暗木底 + 金铜描边，悬停时提亮，符合城堡/魔法氛围。
	var continue_normal_style := StyleBoxFlat.new()
	continue_normal_style.bg_color = Color(0.13, 0.09, 0.05, 0.96)
	continue_normal_style.border_color = Color(0.82, 0.62, 0.24, 1.0)
	continue_normal_style.set_border_width_all(2)
	continue_normal_style.set_corner_radius_all(8)
	continue_normal_style.shadow_color = Color(0.01, 0.005, 0.02, 0.55)
	continue_normal_style.shadow_size = 6
	continue_normal_style.shadow_offset = Vector2(0, 2)
	book_continue_button.add_theme_stylebox_override("normal", continue_normal_style)
	var continue_hover_style: StyleBoxFlat = continue_normal_style.duplicate()
	continue_hover_style.bg_color = Color(0.19, 0.13, 0.06, 0.98)
	continue_hover_style.border_color = Color(0.96, 0.76, 0.34, 1.0)
	continue_hover_style.set_border_width_all(2)
	book_continue_button.add_theme_stylebox_override("hover", continue_hover_style)
	var continue_pressed_style: StyleBoxFlat = continue_normal_style.duplicate()
	continue_pressed_style.bg_color = Color(0.08, 0.055, 0.03, 0.98)
	continue_pressed_style.border_color = Color(0.96, 0.76, 0.34, 1.0)
	book_continue_button.add_theme_stylebox_override("pressed", continue_pressed_style)
	book_continue_button.add_theme_color_override(
		"font_color",
		Color(0.96, 0.76, 0.34, 1.0)
	)
	book_continue_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.93, 0.65, 1.0)
	)
	book_continue_button.add_theme_color_override(
		"font_pressed_color",
		Color(0.90, 0.70, 0.30, 1.0)
	)
	book_continue_button.pressed.connect(_on_book_continue_pressed)
	book_panel.add_child(book_continue_button)


func show_book_clue() -> void:
	# 书架知识书：居中大书 + 知识内容（解答门上的知识锁问题）+ 收进笔记。
	start_dialogue_pause()

	if not book_rule_learned:
		book_rule_learned = true
		# 书桌/书架任一交互后即可触发大门知识锁问题
		first_lock_rule_learned = true
		# 保险：确保笔记工具已解锁（书桌交互正常会先解锁；幂等）
		unlock_notes_tool()
		if NoteHud != null:
			NoteHud.add_clue("book_clue", {
				"title": "The Science of Flame",
				"icon": "icon_book",
				"content": "[center][b]The Science of Flame[/b][/center]\n\nA flame cannot keep burning without [color=#7a2e2e]oxygen[/color] from the air. If the air supply is blocked, the flame weakens and dies.\n\n[color=#4a306d]This answers the knowledge lock on the door: what does a flame need from the air to keep burning?[/color]",
				"category": "evidence",
			})

	book_label_left.text = "The Science of Flame\n\nEvery fire needs air to burn. But not all of the air — only one part of it: oxygen.\n\nWithout oxygen, no flame can keep burning."
	if GameState.has_key(CHEMISTRY_ROOM_KEY_ID):
		# 化学钥匙已领取：书页只保留教学，不再重复弹出钥匙流程。
		book_label_right.text = "The Knowledge Lock asks:\n\n\"What does a flame need from the air to keep burning?\"\n\nThe answer is oxygen.\n\n— Ashford Library, Shelf 3\n\n(Mrs. Lin's key behind the books has already been taken.)"
		book_continue_button.visible = false
	else:
		book_label_right.text = "The Knowledge Lock asks:\n\n\"What does a flame need from the air to keep burning?\"\n\nThe answer is oxygen.\n\n— Ashford Library, Shelf 3\n\nBehind these books, Mrs. Lin left something for you."
		book_continue_button.visible = true
	_show_dialogue(book_panel)


func _on_book_continue_pressed() -> void:
	book_panel.visible = false
	book_continue_button.visible = false
	end_dialogue_pause()
	show_chemistry_key_inspect()


func _on_book_close_pressed():
	book_panel.visible = false
	end_dialogue_pause()


func create_first_room_clue():
	if SHOW_DEBUG_OBJECTS:
		clue_node = ColorRect.new()
		clue_node.name = "CandleNoteClue"
		clue_node.color = Color(0.95, 0.85, 0.35, 1.0)
		clue_node.size = Vector2(28, 22)
		clue_node.position = clue_position - clue_node.size / 2
		clue_node.z_index = 8
		add_child(clue_node)

		var label = Label.new()
		label.text = "Note"
		label.position = clue_position + Vector2(-16, -34)
		label.add_theme_font_size_override("font_size", 14)
		add_child(label)

	if SHOW_INTERACTION_MARKERS:
		clue_node = ColorRect.new()
		clue_node.name = "ClueInteractionMarker"
		clue_node.color = Color(0.95, 0.82, 0.25, 0.85)
		clue_node.size = Vector2(16, 16)
		clue_node.position = clue_position - clue_node.size / 2
		clue_node.z_index = 20
		add_child(clue_node)

	create_candle_note_click_area()
func create_candle_note_click_area():
	clue_click_area = Area2D.new()
	clue_click_area.name = "CandleNoteClickArea"
	clue_click_area.position = clue_position
	clue_click_area.input_pickable = true
	clue_click_area.z_index = 30
	add_child(clue_click_area)

	var collision_shape = CollisionShape2D.new()

	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(90, 70)

	collision_shape.shape = rectangle
	clue_click_area.add_child(collision_shape)

	clue_click_area.mouse_entered.connect(on_candle_note_mouse_entered)
	clue_click_area.mouse_exited.connect(on_candle_note_mouse_exited)
	clue_click_area.input_event.connect(on_candle_note_input_event)
func on_candle_note_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
):
	if first_lock_rule_learned:
		return

	if dialogue_active or puzzle_open or knowledge_panel_open:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()

			var distance_to_clue = player.global_position.distance_to(
				clue_position
			)

			if distance_to_clue <= CLUE_INTERACT_RADIUS:
				cancel_pending_mouse_interaction()
				show_click_marker(clue_position)
				show_first_room_clue()
			else:
				begin_mouse_interaction_at_point(
					"room_clue",
					clue_position,
					clue_approach_position
	)
func on_candle_note_mouse_entered():
	if first_lock_rule_learned:
		return

	mouse_over_clue = true
	update_world_cursor()


func on_candle_note_mouse_exited():
	mouse_over_clue = false
	update_world_cursor()



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

	var target_position: Vector2 = Vector2.ZERO
	var focus_title: String = ""
	var is_primary: bool = false

	if current_interaction == "room_clue":
		target_position = clue_position
		focus_title = "Candle note"
		is_primary = true
	elif current_interaction == "door":
		target_position = door_position
		focus_title = "Knowledge lock"
		is_primary = true
	elif current_interaction.begins_with("prop:"):
		var prop_id: String = current_interaction.trim_prefix("prop:")
		if not props.has(prop_id):
			interaction_focus.clear_focus()
			return
		target_position = props[prop_id].get(
			"focus_position",
			props[prop_id]["position"]
		)
		focus_title = props[prop_id]["prompt"]
		is_primary = prop_id == "desk" or prop_id == "bookshelf"
	else:
		interaction_focus.clear_focus()
		return

	interaction_focus.set_focus(target_position, focus_title, is_primary)


func hide_interaction_feedback() -> void:
	if interaction_focus != null:
		interaction_focus.clear_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = false
	if interact_label != null:
		interact_label.visible = false


func create_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	# 近距离交互提示：深色旧铜面板 + E 操作文字，位置固定在屏幕底部中央。
	interaction_hint_panel = Panel.new()
	interaction_hint_panel.name = "InteractionHintPanel"
	interaction_hint_panel.position = interaction_hint_position
	interaction_hint_panel.size = interaction_hint_size
	interaction_hint_panel.visible = false
	interaction_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_hint_panel.z_index = 35
	var interaction_hint_style := StyleBoxFlat.new()
	interaction_hint_style.bg_color = Color(0.025, 0.025, 0.045, 0.90)
	interaction_hint_style.border_color = Color(0.72, 0.58, 0.28, 0.90)
	interaction_hint_style.set_border_width_all(1)
	interaction_hint_style.set_corner_radius_all(8)
	interaction_hint_style.shadow_color = Color(0.01, 0.005, 0.02, 0.55)
	interaction_hint_style.shadow_size = 8
	interaction_hint_style.shadow_offset = Vector2(0, 3)
	interaction_hint_panel.add_theme_stylebox_override("panel", interaction_hint_style)
	ui_layer.add_child(interaction_hint_panel)

	interact_label = Label.new()
	interact_label.name = "InteractionHintLabel"
	interact_label.text = ""
	interact_label.position = Vector2(16, 7)
	interact_label.size = Vector2(
		maxf(120.0, interaction_hint_size.x - 32.0),
		maxf(30.0, interaction_hint_size.y - 14.0)
	)
	interact_label.visible = false
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_label.add_theme_font_size_override("font_size", 18)
	interact_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.70, 1.0))
	interaction_hint_panel.add_child(interact_label)

	message_panel = Panel.new()
	message_panel.z_index = 40
	message_panel.position = Vector2(0, 512)
	message_panel.size = Vector2(1024, 256)
	message_panel.visible = false
	ui_layer.add_child(message_panel)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	message_panel.add_theme_stylebox_override("panel", style)

	# 右上角 X：退出交互状态（等同于关闭对话框）。
	message_close_button = Button.new()
	message_close_button.name = "MessageCloseButton"
	message_close_button.text = "X"
	message_close_button.position = Vector2(972, 14)
	message_close_button.size = Vector2(36, 36)
	message_close_button.z_index = 10
	message_close_button.add_theme_font_size_override("font_size", 20)
	message_close_button.pressed.connect(close_message_panel)
	message_panel.add_child(message_close_button)

	# 左侧像素头像框架。
	avatar_panel = Panel.new()
	avatar_panel.name = "DialogueAvatar"
	avatar_panel.position = Vector2(24, 24)
	avatar_panel.size = Vector2(120, 120)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.16, 0.22, 0.30, 0.95)
	avatar_style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	avatar_style.set_border_width_all(2)
	avatar_style.set_corner_radius_all(10)
	avatar_panel.add_theme_stylebox_override("panel", avatar_style)
	message_panel.add_child(avatar_panel)

	avatar_portrait = TextureRect.new()
	avatar_portrait.name = "DialogueAvatarPortrait"
	avatar_portrait.position = Vector2(4, 4)
	avatar_portrait.size = Vector2(112, 112)
	avatar_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_portrait.visible = false
	avatar_panel.add_child(avatar_portrait)

	avatar_name_label = Label.new()
	avatar_name_label.name = "DialogueAvatarName"
	avatar_name_label.position = Vector2(4, 92)
	avatar_name_label.size = Vector2(112, 24)
	avatar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_name_label.add_theme_font_size_override("font_size", 11)
	avatar_name_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.70, 1.0))
	avatar_name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1.0))
	avatar_name_label.add_theme_constant_override("outline_size", 3)
	avatar_name_label.z_index = 1
	avatar_panel.add_child(avatar_name_label)

	# Text area: fixed at the top.
	message_scroll = ScrollContainer.new()
	message_scroll.position = Vector2(164, 24)
	message_scroll.size = Vector2(800, 152)
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_panel.add_child(message_scroll)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	message_label.custom_minimum_size = Vector2(780, 260)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.add_child(message_label)

	# Button row: fixed at the very bottom of the dialogue box.
	button_box = HBoxContainer.new()
	button_box.position = Vector2(164, 196)
	button_box.size = Vector2(828, 42)
	button_box.add_theme_constant_override("separation", 8)
	message_panel.add_child(button_box)

	create_top_left_hud()
	create_knowledge_panel_ui()
	create_puzzle_overlay_ui()

func _show_dialogue(panel: Control) -> void:
	# 直接显示：不用 modulate alpha=0 + tween 淡入。
	# 若 tween 因任何原因（树暂停/process_mode）不跑，面板会停在
	# 全透明 → 玩家只见画面冻结、以为卡死（用户实机复现过）。
	panel.visible = true
	panel.modulate = Color(1, 1, 1, 1)


## ============================================================
## 分段式对话（wake_room 标准）
## ============================================================

const DIALOGUE_SEGMENT_MAX_CHARS: int = 140

var _dialogue_segments: Array[String] = []
var _segment_index: int = 0
var _current_speaker: String = ""
var _pending_dialogue_buttons: Array = []

## 分段显示对话：第一段 + Continue；逐段点击推进；最后一段显示选项按钮。
func show_dialogue(speaker: String, text: String) -> void:
	_current_speaker = speaker
	# 去掉文本开头的 "Speaker:" 前缀（头像已显示名字）。
	var body: String = text
	if body.begins_with(speaker + ":\n"):
		body = body.substr(speaker.length() + 2)
	_dialogue_segments = _split_dialogue_segments(body)
	_segment_index = 0
	_pending_dialogue_buttons.clear()
	_set_avatar(speaker)
	_show_dialogue(message_panel)
	_render_segment()


func _render_segment() -> void:
	message_label.text = "%s:\n%s" % [_current_speaker, _dialogue_segments[_segment_index]]
	clear_buttons(false)
	if _segment_index < _dialogue_segments.size() - 1:
		var continue_button := Button.new()
		continue_button.name = "SegmentContinueButton"
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(0, 38)
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_button.add_theme_font_size_override("font_size", 15)
		continue_button.pressed.connect(_advance_segment)
		button_box.add_child(continue_button)
	else:
		for entry: Dictionary in _pending_dialogue_buttons:
			add_dialogue_button(
				str(entry.get("text", "")),
				entry.get("callback")
			)


func _advance_segment() -> void:
	_segment_index += 1
	_render_segment()


## 按段落（\n\n）切分，每段不超过 max_chars。
func _split_dialogue_segments(
	text: String,
	max_chars: int = DIALOGUE_SEGMENT_MAX_CHARS
) -> Array[String]:
	var segments: Array[String] = []
	var paragraphs: PackedStringArray = text.split("\n\n")
	var current: String = ""
	for paragraph: String in paragraphs:
		if (
			current.length() > 0
			and current.length() + paragraph.length() + 2 >= max_chars
		):
			segments.append(current)
			current = paragraph
		else:
			current = current + ("\n\n" if current.length() > 0 else "") + paragraph
	if current.length() > 0:
		segments.append(current)
	if segments.is_empty():
		segments.append(text)
	return segments


## 对话头像：玩家保留色块，NPC 使用统一像素肖像。
func _set_avatar(speaker: String) -> void:
	if avatar_panel == null or avatar_portrait == null or avatar_name_label == null:
		return
	avatar_name_label.text = speaker
	var portrait_path := str(NPC_DIALOGUE_PORTRAITS.get(speaker, ""))
	avatar_portrait.texture = null
	if not portrait_path.is_empty():
		avatar_portrait.texture = load(portrait_path) as Texture2D
	avatar_portrait.visible = avatar_portrait.texture != null
	var is_player: bool = speaker == "You" or speaker == "Detective"
	var style: StyleBoxFlat = avatar_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = (
			Color(0.16, 0.22, 0.30, 0.95)
			if is_player
			else Color(0.20, 0.16, 0.10, 0.95)
		)
		avatar_panel.add_theme_stylebox_override("panel", style)


func show_wake_dialogue():
	start_dialogue_pause()
	clear_buttons()

	_show_dialogue(message_panel)
	# 开局不生成 Mrs. Lin 实体：玩家只读到她留下的信。
	# mrs_lin 是剧情内部 ID，Mrs. Lin 是信件和笔记的显示名称。
	if not GameState.has_story_flag("wake_dish_granted"):
		GameState.set_story_flag("wake_dish_granted")
		GameState.add_dish("castle_ration", 1)
	show_dialogue(
		"Mrs. Lin's Letter",
		"To the investigator who wakes in this room,\n\n"
		+ "When you read this, I may already be dead. Do not come looking for me until you have learned this castle's rules.\n\n"
		+ "Lord Ashford sealed the important doors with two locks: a physical key first, then a Knowledge Lock. The question will not appear until the correct key is used. The answer is always hidden nearby.\n\n"
		+ "I hid the Wake Room Key where you can reach it, and I left the Chemistry Room Key behind the books. The candle note explains the first rule you will need.\n\n"
		+ "Do not trust a scene just because it looks frightening. Observe the materials, record the evidence, and follow the route I marked.\n\n"
		+ "If I am gone, follow my notes — not my voice.\n\n"
		+ "— Mrs. Lin\n\n"
		+ "The Castle Ration in your satchel can restore your strength."
	)
	add_dialogue_button("Read the letter", close_message_panel)


func update_interaction_prompt():
	current_interaction = ""
	interact_label.visible = false
	if temporary_prompt_time_left > 0.0:
		interact_label.text = temporary_prompt_text
		interact_label.visible = true
		return
	if not pending_mouse_interaction.is_empty():
		match pending_mouse_interaction:
			"room_clue":
				interact_label.text = "Walking to the Candle Note..."

			"door":
				interact_label.text = "Walking to the castle door..."

		interact_label.visible = true
		return
	if mouse_over_clue and not first_lock_rule_learned:
		var mouse_clue_distance = player.global_position.distance_to(
			clue_position
		)

		if mouse_clue_distance <= CLUE_INTERACT_RADIUS:
			current_interaction = "room_clue"
			interact_label.text = "Click or press E to read the Candle Note"
		else:
			interact_label.text = "Move closer to inspect the Candle Note"

		interact_label.visible = true
		return

	if mouse_over_door:
		var mouse_door_distance = player.global_position.distance_to(
			door_position
		)

		if mouse_door_distance <= DOOR_INTERACT_RADIUS:
			current_interaction = "door"

			if exit_door_unlocked:
				interact_label.text = "Click or press E to enter the castle hall"
			elif first_lock_rule_learned:
				interact_label.text = "Click or press E to solve the knowledge lock"
			else:
				interact_label.text = "Click or press E to inspect the locked door"
		else:
			interact_label.text = "Move closer to inspect the door"

		interact_label.visible = true
		return
	for id in props.keys():
		if mouse_over_prop.get(id, false):
			var prop_distance = player.global_position.distance_to(
				props[id]["position"]
			)
			if prop_distance <= PROP_INTERACT_RADIUS:
				current_interaction = "prop:" + id
				interact_label.text = "Click or press E to inspect " + props[id]["prompt"]
			else:
				interact_label.text = "Move closer to inspect " + props[id]["prompt"]
			interact_label.visible = true
			return

	if not first_lock_rule_learned:
		var clue_distance = player.global_position.distance_to(clue_position)
		if clue_distance < CLUE_INTERACT_RADIUS:
			current_interaction = "room_clue"
			interact_label.text = "Press E to read the candle note"
			interact_label.visible = true
			return

	var door_distance = player.global_position.distance_to(door_position)
	if door_distance < DOOR_INTERACT_RADIUS:
		current_interaction = "door"

		if exit_door_unlocked:
			interact_label.text = "Press E to enter the castle hall"
		elif GameState.has_key(WAKE_ROOM_KEY_ID):
			interact_label.text = "Press E to solve the knowledge lock"
		else:
			interact_label.text = "Press E to inspect the locked door"

		interact_label.visible = true
		return

	for id in props.keys():
		var prop_distance = player.global_position.distance_to(
			props[id]["position"]
		)
		if prop_distance < PROP_INTERACT_RADIUS:
			current_interaction = "prop:" + id
			interact_label.text = "Press E to inspect " + props[id]["prompt"]
			interact_label.visible = true
			return


func handle_exit_door():
	if exit_door_unlocked:
		leave_wake_room()
		return

	# 钥匙优先：没有实体钥匙时不能激活知识锁问题。
	if not GameState.has_key(WAKE_ROOM_KEY_ID):
		show_no_key_hint()
		return

	if first_lock_rule_learned:
		show_door_inspect()
	else:
		show_door_locked_hint()


func show_no_key_hint():
	# 无钥匙时按 E：知识锁保持休眠，只提示先找钥匙。
	start_dialogue_pause()
	clear_buttons()

	_show_dialogue(message_panel)
	show_dialogue("Narrator", "The golden lock wheel stays dark and silent.\n\nThe knowledge lock remains dormant — a physical key is required before the question can appear.\n\nYou don't have this key yet. Search the room: the Wake Room key must be hidden somewhere nearby.")
	reset_dialogue_scrolls()
	add_dialogue_button("Search the room", close_message_panel)


func show_door_locked_hint():
	# 新手教程：第一次点门 —— 打不开，提示去书桌找线索。
	start_dialogue_pause()
	clear_buttons()

	_show_dialogue(message_panel)
	show_dialogue("Mrs. Lin", "The massive armored door won't budge.\n\nNo handle, no keyhole — only a strange golden lock wheel with pulsing purple crystals.\n\nMrs. Lin:\nIt seems we don't have a key. But the master of this castle loved knowledge... maybe the study desk over there holds a clue about how these doors open.")
	reset_dialogue_scrolls()
	add_dialogue_button("Check the desk", close_message_panel)


func show_locked_door_intro():
	start_dialogue_pause()
	clear_buttons()

	show_dialogue("Mrs. Lin", "The exit door glows with a faint purple light.\n\nA question appears on the lock:\n\n\"What does a flame need from the air to keep burning?\"\n\nMrs. Lin:\nDo not guess. Lord Ashford designed these locks so the answer can be learned nearby. Search the room first. Look for notes, candles, or anything connected to the question.")
	reset_dialogue_scrolls()
	add_dialogue_button("I'll search the room.", close_message_panel)


func show_first_room_clue():
	start_dialogue_pause()
	clear_buttons()

	first_lock_rule_learned = true
	unlock_notes_tool()
	update_knowledge_panel_text()
	if clue_journal != null:
		clue_journal.add_clue("candle_note")
	mouse_over_clue = false
	update_world_cursor()

	if clue_click_area != null:
		clue_click_area.input_pickable = false
	if clue_node != null:
		clue_node.color = Color(0.45, 0.38, 0.12, 0.7)

	show_dialogue("Candle Note", "\"A flame cannot keep burning without oxygen from the air. If the air supply is blocked, the flame weakens and dies.\"\n\nMrs. Lin:\nThat's the clue we needed. The lock asked what a flame needs from the air.\n\nConcept learned: Fire needs oxygen to keep burning.")
	reset_dialogue_scrolls()
	add_dialogue_button("Return to the door.", close_message_panel)


func show_first_door_question():
	# 全屏知识锁答题（可复用 DoorPuzzleUI 模板）。
	# 书桌/书架交互过（first_lock_rule_learned）才能看到问题；
	# 答题界面打开时游戏暂停，答对回调解锁，答错留在界面重试。
	if DoorPuzzleUI == null:
		return
	DoorPuzzleUI.open(
		"[center]The knowledge lock asks:[/center]\n\n[center][b]\"What does a flame need from the air to keep burning?\"[/b][/center]",
		["Oxygen", "Stone dust", "Purple paint", "Silence"],
		0,
		_on_door_puzzle_answered
	)


## DoorPuzzleUI 回调：true=答对（解锁并出对话），false=退出（回到房间）
func _on_door_puzzle_answered(is_correct: bool):
	if is_correct:
		on_first_lock_correct()
	else:
		# 退出答题 → 简短提示，可随时再点门重试
		start_dialogue_pause()
		clear_buttons()
		_show_dialogue(message_panel)
		show_dialogue("Mrs. Lin", "The lock still glows. Whenever you are ready, approach the door again and answer its question.")
		reset_dialogue_scrolls()
		add_dialogue_button("OK", close_message_panel)

func add_first_lock_answer_button(text: String, is_correct: bool):

	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(820, 34)
	button.add_theme_font_size_override("font_size", 17)

	if is_correct:
		button.pressed.connect(on_first_lock_correct)
	else:
		button.pressed.connect(on_first_lock_wrong)

	button_box.add_child(button)


func on_first_lock_correct():
	exit_door_unlocked = true
	# 持久化：从大厅返回 wake_room 时门保持解锁，不用再答题。
	GameState.wake_room_door_unlocked = true

	if door_marker_node != null:
		door_marker_node.color = Color(0.25, 0.95, 0.45, 0.85)

	puzzle_panel.visible = false
	puzzle_open = false
	clear_puzzle_buttons()

	start_dialogue_pause()
	clear_buttons()

	_show_dialogue(message_panel)
	show_dialogue("Mrs. Lin", "Correct.\n\nMrs. Lin:\nYes. Fire needs oxygen from the air. The knowledge lock recognized the answer.\n\nThe door unlocks with a heavy click.\n\nYou can enter the castle hall now, or stay here and review the room first.")
	reset_dialogue_scrolls()

	add_dialogue_button("Stay in this room", close_message_panel)
	add_dialogue_button("Enter the Castle Hall", leave_wake_room)


func on_first_lock_wrong():
	puzzle_panel.visible = false
	puzzle_open = false
	clear_puzzle_buttons()

	start_dialogue_pause()
	clear_buttons()

	_show_dialogue(message_panel)
	show_dialogue("Mrs. Lin", "Not quite.\n\nMrs. Lin:\nThink back to the candle note. It said a flame needs something from the air to keep burning.\n\nYou can try again, review your notes, or take more time to think.")
	add_dialogue_button("Try Again", show_first_door_question)
	add_dialogue_button("Review Notes", open_knowledge_panel_from_dialogue)
	add_dialogue_button("Let me think", close_message_panel)

func leave_wake_room():
	# 记录返回点：进大厅后出现在大厅侧 wake_room 门旁（wake_room_door）。
	GameState.prepare_room_transition(
		"floor_1_hub",
		"res://scenes/game_world.tscn",
		"wake_room_door"
	)
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func add_dialogue_button(text: String, callback: Callable):
	# 分段显示中：选项按钮暂存，最后一段才真正加入。
	if _segment_index < _dialogue_segments.size() - 1:
		_pending_dialogue_buttons.append({"text": text, "callback": callback})
		return
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	button_box.add_child(button)


func clear_buttons(keep_continue: bool = true):
	for child in button_box.get_children():
		# 分段进行中：保留 Continue 按钮。
		if keep_continue and child.name == "SegmentContinueButton":
			continue
		child.queue_free()

	if message_scroll != null:
		message_scroll.scroll_vertical = 0
		message_scroll.set_deferred("scroll_vertical", 0)


func close_message_panel():
	message_panel.visible = false
	clear_buttons(false)
	end_dialogue_pause()


func start_dialogue_pause():
	dialogue_active = true
	current_interaction = ""

	if interact_label != null:
		interact_label.visible = false
	pending_mouse_interaction = ""

	player.cancel_click_movement()
	player.set_physics_process(false)
	update_world_cursor()

func end_dialogue_pause():
	
	dialogue_active = false
	player.set_physics_process(true)
	update_world_cursor()
func reset_dialogue_scrolls():
	if message_scroll != null:
		message_scroll.scroll_vertical = 0
		message_scroll.set_deferred("scroll_vertical", 0)

	
func create_puzzle_overlay_ui():
	puzzle_panel = Panel.new()
	puzzle_panel.position = Vector2(170, 120)
	puzzle_panel.size = Vector2(680, 500)
	puzzle_panel.visible = false
	puzzle_panel.z_index = 60
	ui_layer.add_child(puzzle_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.055, 0.97)
	style.border_color = Color(0.85, 0.68, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	puzzle_panel.add_theme_stylebox_override("panel", style)

	# 右上角 X：随时退出谜题，不会被卡住。
	puzzle_close_button = Button.new()
	puzzle_close_button.name = "PuzzleCloseButton"
	puzzle_close_button.text = "X"
	puzzle_close_button.position = Vector2(630, 14)
	puzzle_close_button.size = Vector2(36, 36)
	puzzle_close_button.add_theme_font_size_override("font_size", 20)
	puzzle_close_button.pressed.connect(close_puzzle_overlay)
	puzzle_panel.add_child(puzzle_close_button)

	var margin = MarginContainer.new()
	margin.position = Vector2(28, 26)
	margin.size = Vector2(624, 448)
	puzzle_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Knowledge Lock"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
	layout.add_child(title)

	var question_scroll = ScrollContainer.new()
	question_scroll.custom_minimum_size = Vector2(610, 150)
	question_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(question_scroll)

	puzzle_question_label = Label.new()
	puzzle_question_label.text = ""
	puzzle_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	puzzle_question_label.custom_minimum_size = Vector2(585, 180)
	puzzle_question_label.add_theme_font_size_override("font_size", 20)
	puzzle_question_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	question_scroll.add_child(puzzle_question_label)

	var choice_scroll = ScrollContainer.new()
	choice_scroll.custom_minimum_size = Vector2(610, 230)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(choice_scroll)

	puzzle_button_box = VBoxContainer.new()
	puzzle_button_box.add_theme_constant_override("separation", 10)
	puzzle_button_box.custom_minimum_size = Vector2(585, 0)
	choice_scroll.add_child(puzzle_button_box)
func open_puzzle_overlay():
	if puzzle_panel == null:
		create_puzzle_overlay_ui()

	puzzle_open = true
	puzzle_panel.visible = true
	puzzle_panel.z_index = 60
	start_dialogue_pause()


func close_puzzle_overlay():
	puzzle_open = false
	puzzle_panel.visible = false
	clear_puzzle_buttons()
	end_dialogue_pause()


func clear_puzzle_buttons():
	for child in puzzle_button_box.get_children():
		child.queue_free()
func add_puzzle_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(585, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if is_correct:
		button.pressed.connect(on_first_lock_correct)
	else:
		button.pressed.connect(on_first_lock_wrong)

	puzzle_button_box.add_child(button)


func add_puzzle_action_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(585, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	puzzle_button_box.add_child(button)
func show_first_lock_notes():
	if puzzle_panel == null:
		create_puzzle_overlay_ui()

	puzzle_open = true
	puzzle_panel.visible = true

	clear_puzzle_buttons()

	puzzle_question_label.text = "Knowledge Notes:\n\nCandle Note:\n\"A flame cannot keep burning without oxygen from the air. If the air supply is blocked, the flame weakens and dies.\"\n\nMrs. Lin's Explanation:\nThe lock asks what a flame needs from the air. The note tells us that the important substance is oxygen.\n\nConcept:\nFire needs oxygen to keep burning."

	add_puzzle_action_button("Back to Question", show_first_door_question)
	add_puzzle_action_button("Let me think", close_puzzle_overlay)
func show_first_lock_notes_from_dialogue():
	message_panel.visible = false
	clear_buttons()
	open_puzzle_overlay()
	show_first_lock_notes()
func create_top_left_hud():
	# 笔记入口已改为全局 NoteHud 书本图标（autoload，跨房间常驻），
	# 这里不再创建 "Notes [K]" 文字按钮。
	pass
func create_knowledge_panel_ui():
	knowledge_panel = Panel.new()
	knowledge_panel.position = Vector2(160, 95)
	knowledge_panel.size = Vector2(720, 560)
	knowledge_panel.visible = false
	knowledge_panel.z_index = 100
	ui_layer.add_child(knowledge_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.055, 0.97)
	style.border_color = Color(0.85, 0.68, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	knowledge_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.position = Vector2(28, 26)
	margin.size = Vector2(664, 508)
	knowledge_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Knowledge Notes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 1.0))
	layout.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650, 390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	knowledge_label = Label.new()
	knowledge_label.text = ""
	knowledge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_label.custom_minimum_size = Vector2(620, 520)
	knowledge_label.add_theme_font_size_override("font_size", 19)
	knowledge_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	scroll.add_child(knowledge_label)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(650, 40)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(close_knowledge_panel)
	layout.add_child(close_button)

	update_knowledge_panel_text()
func create_clue_journal():
	# 侦探笔记系统：全局 NoteHud（autoload）持有唯一实例，跨房间常驻。
	# 本房间直接复用，避免重复实例化导致数据丢失。
	if NoteHud != null:
		clue_journal = NoteHud.get_journal()


func toggle_knowledge_panel():
	# 打开笔记前先关闭其他交互面板并恢复玩家状态（防卡死）。
	if clue_journal != null and not clue_journal.visible:
		if _close_any_open_panel():
			pass
		if dialogue_active:
			end_dialogue_pause()
	if clue_journal != null:
		clue_journal.toggle()
		return
	if knowledge_panel_open:
		close_knowledge_panel()
	else:
		open_knowledge_panel()


func open_knowledge_panel():
	if not notes_unlocked:
		return

	if knowledge_panel == null:
		create_knowledge_panel_ui()

	knowledge_panel_open = true
	update_knowledge_panel_text()
	knowledge_panel.visible = true
	knowledge_panel.z_index = 200
	knowledge_panel.move_to_front()
	notes_tutorial_seen = true

	if interact_label != null:
		interact_label.visible = false
		player.cancel_click_movement()
	if interact_label != null:
		interact_label.visible = false

	player.cancel_click_movement()
	player.set_physics_process(false)
	update_world_cursor()
func close_knowledge_panel():
	knowledge_panel_open = false

	if knowledge_panel != null:
		knowledge_panel.visible = false

	if not dialogue_active and not puzzle_open:
		player.set_physics_process(true)
func update_knowledge_panel_text():
	if knowledge_label == null:
		return

	var text := ""

	if not notes_tutorial_seen:
		text += "Tutorial: Knowledge Notes\n\n"
		text += "This tool stores important knowledge you discover while exploring.\n\n"
		text += "Use it when a knowledge lock asks a question. You can open it from the top-left Notes button or by pressing K.\n\n"
		text += "As you progress, more tools may unlock here, such as Evidence, Objectives, Map, or Inventory.\n\n"
		text += "--------------------------------\n\n"

	if not first_lock_rule_learned:
		text += "No notes collected yet.\n\nExplore the room and inspect useful clues. Notes you discover will appear here."
	else:
		text += "Parchment Scroll (Study Desk)\n\n"
		text += "Observation:\nA parchment on the study desk says the master of this castle loved knowledge, and every door holds a question — answer it correctly and the door opens even without a key.\n\n"
		text += "Science Concept:\nKnowledge locks open when you answer their question correctly.\n\n"
		text += "How to Apply It:\nInspect the locked door to read its question, then search the room for the answer.\n\n"
		text += "--------------------------------\n\n"
		text += "Candle Note\n\n"
		text += "Observation:\nA note near the candle explains that a flame cannot keep burning without oxygen from the air.\n\n"
		text += "Science Concept:\nFire needs oxygen to keep burning. If oxygen is removed or blocked, the flame weakens and goes out.\n\n"
		text += "How to Apply It:\nIf the knowledge lock asks what a flame needs from the air, the answer is oxygen."

	knowledge_label.text = text
func open_knowledge_panel_from_dialogue():
	message_panel.visible = false
	clear_buttons()
	# 清除对话状态，避免笔记关闭后玩家仍被禁用。
	if dialogue_active:
		end_dialogue_pause()
	if clue_journal != null:
		clue_journal.open()
		return
	open_knowledge_panel()
func unlock_notes_tool():
	if notes_unlocked:
		return

	notes_unlocked = true

	if NoteHud != null:
		NoteHud.unlock()
		NoteHud.show_feature_unlock(
			"NEW NOTE FEATURE",
			"New clue added. Press K to review."
		)
func create_mouse_hotspot(
	hotspot_name: String,
	hotspot_position: Vector2,
	hotspot_size: Vector2
) -> Area2D:
	var area = Area2D.new()
	area.name = hotspot_name
	area.position = hotspot_position
	area.input_pickable = true
	area.z_index = 30
	add_child(area)

	var collision_shape = CollisionShape2D.new()

	var rectangle = RectangleShape2D.new()
	rectangle.size = hotspot_size

	collision_shape.shape = rectangle
	area.add_child(collision_shape)

	return area
func on_door_mouse_entered():
	mouse_over_door = true
	update_world_cursor()


func on_door_mouse_exited():
	mouse_over_door = false
	update_world_cursor()


func on_door_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
):
	if dialogue_active or puzzle_open or knowledge_panel_open:
		# 面板开着时点门：不吞事件也不自动关面板——面板由玩家主动取消
		# （X / E / ESC）。这里直接放行会让下面的距离检查与面板状态冲突，
		# 所以保持原样返回，玩家先取消面板再交互门。
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()

			var distance_to_door = player.global_position.distance_to(
				door_position
			)

			if distance_to_door <= DOOR_INTERACT_RADIUS:
				cancel_pending_mouse_interaction()
				show_click_marker(door_position)
				handle_exit_door()
			else:
				begin_mouse_interaction(
					"door",
					door_position,
					DOOR_INTERACT_RADIUS
				)
func update_world_cursor():
	var ui_is_blocking = (
		dialogue_active
		or puzzle_open
		or knowledge_panel_open
	)

	var over_interactable = (
		mouse_over_clue
		or mouse_over_door
	)

	if not ui_is_blocking and over_interactable:
		Input.set_default_cursor_shape(
			Input.CURSOR_POINTING_HAND
		)
	else:
		Input.set_default_cursor_shape(
			Input.CURSOR_ARROW
		)
func begin_mouse_interaction(
	interaction_name: String,
	object_position: Vector2,
	interaction_radius: float
):
	player.cancel_click_movement()

	pending_mouse_interaction = interaction_name

	show_click_marker(object_position)

	var approach_point = calculate_interaction_approach_point(
		object_position,
		interaction_radius
	)

	var path := calculate_room_path(
		player.global_position,
		approach_point
	)

	show_debug_room_path(path)

	if path.is_empty():
		pending_mouse_interaction = ""

		show_temporary_prompt(
			"I couldn't find a safe route to that object."
		)
		return

	player.move_along_path(path)

func begin_mouse_interaction_at_point(
	interaction_name: String,
	object_position: Vector2,
	approach_point: Vector2
):
	player.cancel_click_movement()

	pending_mouse_interaction = interaction_name

	show_click_marker(object_position)

	var path := calculate_room_path(
		player.global_position,
		approach_point
	)

	show_debug_room_path(path)

	if path.is_empty():
		pending_mouse_interaction = ""

		show_temporary_prompt(
			"I couldn't find a safe route to that object."
		)
		return

	player.move_along_path(path)
func hide_debug_room_path():
	if debug_path_line == null:
		return

	debug_path_line.clear_points()
	debug_path_line.visible = false
func calculate_interaction_approach_point(
	object_position: Vector2,
	interaction_radius: float
) -> Vector2:
	# Find the direction from the object toward the player.
	var direction_away_from_object = object_position.direction_to(
		player.global_position
	)

	if direction_away_from_object == Vector2.ZERO:
		direction_away_from_object = Vector2.LEFT

	# Stop inside the object's interaction radius,
	# rather than walking directly on top of it.
	var approach_distance = max(
		24.0,
		interaction_radius * 0.70
	)

	var approach_point = (
		object_position
		+ direction_away_from_object * approach_distance
	)

	# Keep the destination inside the room walls.
	approach_point.x = clamp(
		approach_point.x,
		WALL_THICKNESS + 24.0,
		ROOM_WIDTH - WALL_THICKNESS - 24.0
	)

	approach_point.y = clamp(
		approach_point.y,
		WALL_THICKNESS + 24.0,
		ROOM_HEIGHT - WALL_THICKNESS - 24.0
	)

	return approach_point
func on_player_click_target_reached():
	hide_debug_room_path()
	if pending_mouse_interaction.is_empty():
		return

	var interaction_to_run := pending_mouse_interaction
	pending_mouse_interaction = ""

	match interaction_to_run:
		"room_clue":
			if first_lock_rule_learned:
				return

			if player.global_position.distance_to(
				clue_position
			) <= CLUE_INTERACT_RADIUS:
				show_first_room_clue()
			else:
				show_failed_approach_message()

		"door":
			if player.global_position.distance_to(
				door_position
			) <= DOOR_INTERACT_RADIUS:
				handle_exit_door()
			else:
				show_failed_approach_message()

		_:
			if interaction_to_run.begins_with("prop:"):
				var prop_id: String = interaction_to_run.trim_prefix("prop:")
				if props.has(prop_id):
					if player.global_position.distance_to(
						props[prop_id]["position"]
					) <= PROP_INTERACT_RADIUS:
						show_inspect(prop_id)
					else:
						show_failed_approach_message()


func on_player_ground_move_started(
	target_position: Vector2
):
	pending_mouse_interaction = ""

	var path: PackedVector2Array = calculate_room_path(
		player.global_position,
		target_position
	)

	show_debug_room_path(path)

	if path.is_empty():
		player.cancel_click_movement()

		show_temporary_prompt(
			"That destination is not walkable."
		)
		return

	show_click_marker(target_position)
	player.move_along_path(path)


func on_player_click_movement_cancelled():
	pending_mouse_interaction = ""
	hide_debug_room_path()


func show_failed_approach_message():
	interact_label.text = (
		"I couldn't get close enough. Try approaching from another direction."
	)
	interact_label.visible = true
func cancel_pending_mouse_interaction():
	pending_mouse_interaction = ""
	player.cancel_click_movement()
func create_click_marker():
	click_marker = Node2D.new()
	click_marker.name = "ClickTargetMarker"
	click_marker.visible = false

	# Above the background, but below characters and objects.
	click_marker.z_index = -1
	add_child(click_marker)

	var outer_ring = Line2D.new()
	outer_ring.name = "OuterRing"
	outer_ring.width = 3.0
	outer_ring.default_color = Color(
		0.95,
		0.75,
		0.28,
		0.95
	)
	outer_ring.antialiased = true
	outer_ring.closed = true
	outer_ring.points = create_circle_points(
		18.0,
		32
	)
	click_marker.add_child(outer_ring)

	var inner_ring = Line2D.new()
	inner_ring.name = "InnerRing"
	inner_ring.width = 2.0
	inner_ring.default_color = Color(
		1.0,
		0.90,
		0.55,
		0.90
	)
	inner_ring.antialiased = true
	inner_ring.closed = true
	inner_ring.points = create_circle_points(
		8.0,
		24
	)
	click_marker.add_child(inner_ring)
func create_circle_points(
	radius: float,
	segment_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(segment_count):
		var angle = TAU * float(index) / float(
			segment_count
		)

		var point = Vector2(
			cos(angle),
			sin(angle)
		) * radius

		points.append(point)

	return points
func show_click_marker(world_position: Vector2):
	if click_marker == null:
		return

	if click_marker_tween != null:
		if click_marker_tween.is_valid():
			click_marker_tween.kill()

	click_marker.position = world_position
	click_marker.scale = Vector2(0.55, 0.55)
	click_marker.modulate = Color(1.0, 1.0, 1.0, 1.0)
	click_marker.visible = true

	click_marker_tween = create_tween()
	click_marker_tween.set_parallel(true)

	click_marker_tween.tween_property(
		click_marker,
		"scale",
		Vector2(1.25, 1.25),
		0.42
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	click_marker_tween.tween_property(
		click_marker,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		0.42
	)

	click_marker_tween.finished.connect(
		hide_click_marker
	)
func hide_click_marker():
	if click_marker != null:
		click_marker.visible = false
func on_player_click_movement_blocked(
	_target_position: Vector2
):
	pending_mouse_interaction = ""
	hide_debug_room_path()

	show_temporary_prompt(
		"That route is blocked. Try another destination."
	)
func show_temporary_prompt(
	text: String,
	duration: float = 1.8
):
	temporary_prompt_text = text
	temporary_prompt_time_left = duration
func world_position_to_grid_cell(
	world_position: Vector2
) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / PATH_CELL_SIZE)),
		int(floor(world_position.y / PATH_CELL_SIZE))
	)
func calculate_room_path(
	start_position: Vector2,
	target_position: Vector2
) -> PackedVector2Array:
	var empty_path := PackedVector2Array()

	if walkable_mask_image == null:
		return empty_path

	if not is_player_position_walkable(
		start_position
	):
		return empty_path

	if not is_player_position_walkable(
		target_position
	):
		return empty_path

	# Most important rule:
	# use an exact straight path whenever possible.
	if is_direct_path_walkable(
		start_position,
		target_position
	):
		var direct_path := PackedVector2Array()
		direct_path.append(target_position)
		return direct_path

	var start_cell := world_position_to_grid_cell(
		start_position
	)

	var target_cell := world_position_to_grid_cell(
		target_position
	)

	if not room_astar.is_in_boundsv(start_cell):
		return empty_path

	if not room_astar.is_in_boundsv(target_cell):
		return empty_path

	if room_astar.is_point_solid(start_cell):
		return empty_path

	if room_astar.is_point_solid(target_cell):
		return empty_path

	var raw_path := room_astar.get_point_path(
		start_cell,
		target_cell
	)

	if raw_path.is_empty():
		return raw_path

	if raw_path[
		raw_path.size() - 1
	].distance_to(target_position) > 2.0:
		raw_path.append(target_position)

	return smooth_room_path(
		start_position,
		raw_path
	)
func create_debug_path_line():
	debug_path_line = Line2D.new()
	debug_path_line.name = "DebugAStarPath"
	debug_path_line.width = 4.0
	debug_path_line.default_color = Color(
		0.30,
		0.85,
		1.0,
		0.90
	)
	debug_path_line.antialiased = true
	debug_path_line.z_index = 25
	debug_path_line.visible = false
	add_child(debug_path_line)
func show_debug_room_path(
	path: PackedVector2Array
):
	if debug_path_line == null:
		return

	if not SHOW_DEBUG_PATH:
		debug_path_line.visible = false
		return

	if path.is_empty():
		debug_path_line.clear_points()
		debug_path_line.visible = false
		return

	debug_path_line.clear_points()

	# Always begin at the player's actual position.
	debug_path_line.add_point(
		player.global_position
	)

	for point: Vector2 in path:
		debug_path_line.add_point(point)

	debug_path_line.visible = true
func load_walkable_mask() -> bool:
	var mask_texture = load(
		WALKABLE_MASK_PATH
	) as Texture2D

	if mask_texture == null:
		push_error(
			"Walkable mask not found: "
			+ WALKABLE_MASK_PATH
		)
		return false

	walkable_mask_image = mask_texture.get_image()

	if walkable_mask_image == null:
		push_error(
			"Could not read walkable mask image."
		)
		return false

	if walkable_mask_image.is_empty():
		push_error(
			"Walkable mask image is empty."
		)
		return false

	return true
func is_mask_point_walkable(
	world_position: Vector2
) -> bool:
	if walkable_mask_image == null:
		return false

	if world_position.x < 0.0:
		return false

	if world_position.y < 0.0:
		return false

	if world_position.x >= ROOM_WIDTH:
		return false

	if world_position.y >= ROOM_HEIGHT:
		return false

	var image_size := walkable_mask_image.get_size()

	var pixel_x := int(
		world_position.x
		/ float(ROOM_WIDTH)
		* image_size.x
	)

	var pixel_y := int(
		world_position.y
		/ float(ROOM_HEIGHT)
		* image_size.y
	)

	pixel_x = clamp(
		pixel_x,
		0,
		image_size.x - 1
	)

	pixel_y = clamp(
		pixel_y,
		0,
		image_size.y - 1
	)

	var pixel_color := walkable_mask_image.get_pixel(
		pixel_x,
		pixel_y
	)

	# White means floor.
	return (
		pixel_color.a > 0.5
		and pixel_color.r > 0.5
		and pixel_color.g > 0.5
		and pixel_color.b > 0.5
	)
func _collect_user_collisions() -> void:
	# 收集用户手画的 CollisionPolygon2D（Collisions 墙 + Props 物品），
	# 寻路与物理碰撞完全一致 —— 没有隐形空气墙。
	_user_collision_polys.clear()

	var coll: Node = get_node_or_null("Collisions")
	if coll != null:
		for body in coll.get_children():
			if body is StaticBody2D:
				for child in body.get_children():
					if child is CollisionPolygon2D:
						_user_collision_polys.append(
							_get_world_polygon(child as CollisionPolygon2D)
						)

	var props_root: Node = get_node_or_null("Props")
	if props_root != null:
		for child in props_root.get_children():
			if child is Area2D:
				for sub in child.get_children():
					if sub is CollisionPolygon2D:
						_user_collision_polys.append(
							_get_world_polygon(sub as CollisionPolygon2D)
						)


func _get_world_polygon(shape: CollisionPolygon2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in shape.polygon:
		points.append(shape.global_transform * p)
	return points


func _get_reachable_point(poly_pts: PackedVector2Array) -> Vector2:
	# 交互点 = 碰撞多边形包围盒中"玩家可达"的边中点
	# （玩家能走到碰撞边缘触发交互，而不是被困在碰撞内部）。
	if poly_pts.size() < 2:
		return Vector2.ZERO

	var min_x := 1e9
	var max_x := -1e9
	var min_y := 1e9
	var max_y := -1e9
	for pt in poly_pts:
		min_x = min(min_x, pt.x)
		max_x = max(max_x, pt.x)
		min_y = min(min_y, pt.y)
		max_y = max(max_y, pt.y)

	var center := Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	# 边中点向外偏移 20px（玩家半径 14 + 余量），避免落在碰撞边界上。
	var candidates := [
		Vector2(center.x, min_y - 20.0),
		Vector2(center.x, max_y + 20.0),
		Vector2(min_x - 20.0, center.y),
		Vector2(max_x + 20.0, center.y),
	]
	for c in candidates:
		if is_player_position_walkable(c):
			return c

	# 四个边都不可达时退回中心（极少见，用户会调整碰撞）。
	return center


func _point_in_user_collision(world_position: Vector2) -> bool:
	for poly in _user_collision_polys:
		if Geometry2D.is_point_in_polygon(world_position, poly):
			return true
	return false


func is_player_position_walkable(
	world_position: Vector2
) -> bool:
	var diagonal_radius := (
		PLAYER_CLEARANCE_RADIUS * 0.707
	)

	var test_offsets := [
		Vector2.ZERO,

		Vector2(
			PLAYER_CLEARANCE_RADIUS,
			0.0
		),
		Vector2(
			-PLAYER_CLEARANCE_RADIUS,
			0.0
		),
		Vector2(
			0.0,
			PLAYER_CLEARANCE_RADIUS
		),
		Vector2(
			0.0,
			-PLAYER_CLEARANCE_RADIUS
		),

		Vector2(
			diagonal_radius,
			diagonal_radius
		),
		Vector2(
			-diagonal_radius,
			diagonal_radius
		),
		Vector2(
			diagonal_radius,
			-diagonal_radius
		),
		Vector2(
			-diagonal_radius,
			-diagonal_radius
		)
	]

	for offset in test_offsets:
		if not is_mask_point_walkable(
			world_position + offset
		):
			return false
		if _point_in_user_collision(world_position + offset):
			return false

	return true
func is_direct_path_walkable(
	start_position: Vector2,
	target_position: Vector2
) -> bool:
	var path_distance: float = start_position.distance_to(
		target_position
	)

	var sample_count: int = maxi(
		1,
		int(
			ceil(
				path_distance
				/ DIRECT_PATH_SAMPLE_STEP
			)
		)
	)

	for index in range(sample_count + 1):
		var progress: float = (
			float(index)
			/ float(sample_count)
		)

		var sample_position: Vector2 = start_position.lerp(
			target_position,
			progress
		)

		if not is_player_position_walkable(
			sample_position
		):
			return false

	return true
func smooth_room_path(
	start_position: Vector2,
	raw_path: PackedVector2Array
) -> PackedVector2Array:
	var smoothed_path := PackedVector2Array()

	if raw_path.is_empty():
		return smoothed_path

	var anchor_position := start_position
	var search_index := 0

	while search_index < raw_path.size():
		var farthest_visible_index := search_index

		for candidate_index in range(
			raw_path.size() - 1,
			search_index - 1,
			-1
		):
			if is_direct_path_walkable(
				anchor_position,
				raw_path[candidate_index]
			):
				farthest_visible_index = (
					candidate_index
				)
				break

		var selected_point := raw_path[
			farthest_visible_index
		]

		smoothed_path.append(
			selected_point
		)

		anchor_position = selected_point
		search_index = (
			farthest_visible_index + 1
		)

	return smoothed_path


## 桌上那排玻璃罩蜡烛。苏醒室是开场教学，所以这是全部小游戏里最短、
## 最不惩罚的一个：只需要预测熄灭顺序，不需要操作，也没有时间压力。
func _open_flame_minigame() -> void:
	var launched: bool = MinigameLauncher.launch(
		self,
		FlameAirMinigame.new(),
		_mg_text("Candle and Jar", "烛与罩"),
		_mg_text(
			"Mrs. Lin left a row of candles under glass. Work out which flame"
			+ " goes out first.",
			"林女士在桌上留了一排罩着玻璃的蜡烛。想清楚哪一支会最先熄灭。"
		),
		Color(1.0, 0.72, 0.35, 1.0),
		_on_flame_minigame_finished
	)
	if not launched:
		return


func _on_flame_minigame_finished(cleared_all: bool, stages: int) -> void:
	if cleared_all:
		GameState.set_story_flag("wake_flame_drilled")
		show_scroll_clue()
		return
	_show_flame_hint(stages)


func _show_flame_hint(stages: int) -> void:
	start_dialogue_pause()
	inspect_texture.texture = null
	inspect_label.text = _mg_text(
		"You predicted %d rows correctly before stepping away. The door will"
		% stages
		+ " ask what a flame needs from the air — work the candles until you"
		+ " can say why, not just what.",
		"你在离开前答对了 %d 排。门上那道题问的是火焰需要从空气里得到什么——"
		% stages
		+ "把这些蜡烛想透，说得出「为什么」，而不只是「是什么」。"
	)
	inspect_confirm_button.visible = false
	_show_dialogue(inspect_panel)


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english
