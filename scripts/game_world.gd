extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 60
const MAP_HEIGHT := 40
const MAP_PIXEL_WIDTH := MAP_WIDTH * CELL_SIZE
const MAP_PIXEL_HEIGHT := MAP_HEIGHT * CELL_SIZE
const DISABLE_FOG_DURING_ALIGNMENT := true
# Fog uses smaller cells than the wall grid.
# Walls are 32x32, but fog is 16x16, so the light looks more circular.
const FOG_CELL_SIZE := 16
const FOG_COLS := MAP_PIXEL_WIDTH / FOG_CELL_SIZE
const FOG_ROWS := MAP_PIXEL_HEIGHT / FOG_CELL_SIZE

# ============================================================
# Castle Hall visual assets (user-provided GPT art).
# 两张图由 scenes/wall_collisions.tscn 直接引用，不在代码里加载：
#   hall_floor_bg.png - 地板与氛围层，1448x1086 拉伸铺满 1920x1280。
#   hall_walls.png    - 墙体层，1536x1024 按 x1.25 均匀缩放铺满。
# 注意：两张图的迷宫布局并不相同，只有 hall_walls.png 与 Wall_*
# 碰撞多边形同源。墙体视觉必须取自 hall_walls.png 并保持 x1.25，
# 否则玩家看到的墙会和实际碰撞、视线遮挡错位。
# ============================================================
const GAME_OVER_SCREEN_PATH: String = "res://assets/ui/screens/game_over.png"
const DEATH_UI_SCENE_PATH: String = "res://scenes/ui/death_ui.tscn"
const NPC_DIALOGUE_PORTRAITS: Dictionary = {
	"Mrs. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Dr. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Mrs. Lin's Letter": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Butler": "res://assets/characters/portraits_pixel_v2/butler.png",
	"Gardener": "res://assets/characters/portraits_pixel_v2/gardener.png",
	"Mechanic": "res://assets/characters/portraits_pixel_v2/mechanic.png",
	"Castle Guardian": "res://assets/characters/portraits_pixel_v2/castle_guardian.png",
}

# ============================================================
# Castle Hall layout (60x40 string map, one char per 32px cell)
# '#' = wall, 'K' = knowledge-lock door cells, '.' = floor.
# This matches the original castle_floor_1_bg.png layout, with
# fixes: red stain (12,8) and circuit clue (14,22) are reachable,
# all 1-cell gaps are sealed or widened, lock door at (21..23,8).
# ============================================================
# Castle Hall layout (60x40 string map, one char per 32px cell)
# '#' = wall, '.' = floor. Generated from hall_walls.png: a cell
# is a wall when >=20% of it is covered by light stone-wall pixels
# (luminance >= 130); tiny wall islands and floor holes cleaned;
# outer border sealed. Main walkable region: ~66.7% of the map.
# ============================================================
const CASTLE_LAYOUT: Array[String] = [
"############################################################",
"#..............................####........................#",
"#...............................##.........#####...........#",
"#...............................###........................#",
"#.....................................#.#..................#",
"#...#...#.......#..#........#.##......#.###................#",
"#...#...###....###.##......######.....#...#####............#",
"#...#...##........###...#...#..##.....#...#..#.....##......#",
"#......####.....##..#.####......#.....#......#...######....#",
"#.............####.#...##.....#.#...................####...#",
"#.......#.......#####...##....#.####..........#.....##.....#",
"#.......##......##..#.#.##..###..#.#.......####.....#......#",
"#.......#...#.#.#...####...#####.....###.....#.#.###.......#",
"#.##..##..#.#.####.#...#....#.###............#.##..........#",
"#.#...#####.#####..#...##...#..###...###.##..#.#....#......#",
"#.#..###.##.....#.##....#...#..#######.#.####..####.##....##",
"#....#...###....####..#.#...#......##..#.........#...#..####",
"#........###.....###..#.............##.#..#.###......####.##",
"#.........##.....##...#.........#....##...#.#.#.......#....#",
"#...####...#........#.#.#......###.......##.......#...#....#",
"#...###....#.......##...#...###...................###.##...#",
"#...##...#........####..#...###......##........#....#..##..#",
"#........#......#.......##..#.#...#...##.......##..........#",
"#...####.###....#.....##.#....#..##...#........###..####...#",
"#....##..#.....######..#......##.##............##....#.....#",
"#.######.........##....##......#......##..#....#....#......#",
"#....###..##.#....#..#......####..##...#..##........#......#",
"#....###...#.####.#..#........##.####.............###....#.#",
"#....###..##.####.##.#.###.....#.#####.....###...........#.#",
"#....###..##.###.......#.###.....####..#.....#...........#.#",
"#....###..##...#.......#...#.....###...##....#...........#.#",
"#..##.#......#.#####...#..##.......#...#.....#.............#",
"#..##...#....#.#...#..............##.........#.###.........#",
"#..###..##...#.#............#..#####.........##.##.........#",
"#........##..#..............#....................#.........#",
"#.........##.............##.###................###.........#",
"#..........#.............#...................#..#..........#",
"#...........................................##.............#",
"#..........................................................#",
"############################################################",
]
const CIRCUIT_DOOR_INTERACT_RADIUS: float = 110.0
const VISION_RADIUS_PIXELS := 320.0
const CLEAR_RADIUS_PIXELS := 130.0
const EDGE_DARKNESS := 0.62
const DISCOVERED_DARKNESS := 0.68
const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(
	2,
	2
)

const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(
	0.75,
	0.75
)

const CAMERA_ZOOM_CHANGE_SPEED: float = 7.0

# 开发期间先设为 true。
# 正式发布时改成 false。


var camera_target_zoom: Vector2 = (
	DEVELOPER_CAMERA_ZOOM
)

var developer_mode_label: Label
var intro_seen := false
var intro_reviewing_objectives := false
@onready var player = $player

var wall_cells := {}
var sight_blockers := {}
var fog_cells := {}
var fog_sprite: Sprite2D
var fog_image: Image
var fog_texture: ImageTexture
var learned_circuit_rule := false
var circuit_note_position := Vector2.ZERO
var circuit_note_node: ColorRect
var circuit_door_position := Vector2.ZERO
var discovered_fog_cells := {}
var visible_fog_cells := {}
var visible_fog_distances := {}
@onready var enemy = get_node_or_null("CastleGuardian")
var follow_camera: Camera2D

var astar_grid := AStarGrid2D.new()
var use_authored_wall_collision_probe: bool = false
var game_over := false
var game_over_canvas: CanvasLayer
var game_over_screen_root: Control
var game_over_label: Label
var reputation := 0
var evidence_collected := false
var clue_position := Vector2.ZERO
var clue_node: ColorRect

var ui_layer: CanvasLayer
var message_panel: Panel
var message_label: Label
var avatar_panel: Panel
var avatar_portrait: TextureRect
var avatar_name_label: Label
var button_box: HBoxContainer
var message_scroll: ScrollContainer
var button_scroll: ScrollContainer
var dialogue_action_row: HBoxContainer
var dialogue_continue_button: Button
var reputation_label: Label
var interact_label: Label
var interaction_hint_panel: Panel
var interaction_focus: WorldInteractionFocus
var dialogue_active := false
var evidence_items: Array[String] = []
var evidence_panel: Panel
var evidence_board_open := false
var evidence_hint_label: Label
var objective_summary_label: Label
var objective_panel: Panel
var objective_detail_label: Label
var objective_panel_open := false

var evidence_title_label: Label
var evidence_list_scroll: ScrollContainer
var evidence_list_box: VBoxContainer

var evidence_detail_scroll: ScrollContainer
var evidence_detail_label: Label
var evidence_back_button: Button

var butler_position := Vector2.ZERO
var butler_node: AnimatedNpc
var current_interaction := ""

var pollen_collected := false
var pollen_position := Vector2.ZERO
var pollen_node: ColorRect

var gardener_position := Vector2.ZERO
var gardener_node: AnimatedNpc
var circuit_collected := false
var circuit_position := Vector2.ZERO
var circuit_node: ColorRect

var mechanic_position := Vector2.ZERO
var mechanic_node: AnimatedNpc

var final_room_position := Vector2.ZERO
var final_room_node: ColorRect
var culprit_id := "mechanic"
var knowledge_items: Array[String] = []
var knowledge_panel: Panel
var knowledge_panel_open := false
var knowledge_list_label: Label
const USE_CASTLE_IMAGE_BACKGROUND := true
const CHEMISTRY_ROOM_SCENE_PATH: String = \
	"res://scenes/floor_1/chemistry_room.tscn"
const GREENHOUSE_ROOM_SCENE_PATH: String = \
	"res://scenes/floor_1/greenhouse_room.tscn"

# 用户手动确认的大厅房间入口坐标。交互点和视觉焦点使用同一坐标，
# 不再用旧底图推算值覆盖用户调整。
const CHEMISTRY_ROOM_DOOR_POSITION: Vector2 = Vector2(283, 162)
const CHEMISTRY_ROOM_DOOR_FOCUS_POSITION: Vector2 = Vector2(283, 162)
const CHEMISTRY_ROOM_RETURN_POSITION: Vector2 = Vector2(283, 162)
const CHEMISTRY_ROOM_DOOR_RADIUS: float = 100.0
const GREENHOUSE_ROOM_DOOR_POSITION: Vector2 = Vector2(219, 409)
const GREENHOUSE_ROOM_DOOR_FOCUS_POSITION: Vector2 = Vector2(219, 409)
const GREENHOUSE_ROOM_DOOR_RADIUS: float = 100.0
const LIBRARY_DOOR_POSITION: Vector2 = Vector2(1676, 285)
const DINING_HALL_DOOR_POSITION: Vector2 = Vector2(1774, 715)
const HALL_ENEMY_START_POSITION := Vector2(1611, 1070)

# 新房间场景（用户 2026-08-05 提供的四张 1448×1086 房间图）。
const CIRCUIT_ROOM_SCENE_PATH: String = (
	"res://scenes/floor_1/circuit_room.tscn"
)
const DINING_HALL_ROOM_SCENE_PATH: String = (
	"res://scenes/floor_1/dining_hall_room.tscn"
)
const LIBRARY_ROOM_SCENE_PATH: String = (
	"res://scenes/floor_1/library_room.tscn"
)
const FINAL_ROOM_SCENE_PATH: String = (
	"res://scenes/floor_1/final_room.tscn"
)
const FINAL_ROOM_DOOR_POSITION: Vector2 = Vector2(955, 138)
const FINAL_ROOM_DOOR_FOCUS_POSITION: Vector2 = Vector2(955, 138)
const FINAL_ROOM_DOOR_RADIUS: float = 100.0

# Mrs. Lin 撕落的走廊笔记碎片（在大厅拼凑，指引 Final Room）。
const CORRIDOR_FRAGMENT_POSITIONS: Array[Vector2] = [
	Vector2(256, 992),
	Vector2(192, 384),
	Vector2(192, 672)
]
const CORRIDOR_FRAGMENT_RADIUS: float = 100.0

# 可选支线：Library Room Key 藏在大厅右下角储物架（不拿也能继续主线，拿了补全信息）。
const HIDDEN_LIBRARY_KEY_POSITION: Vector2 = Vector2(1587, 967)
const HIDDEN_LIBRARY_KEY_RADIUS: float = 100.0

# Final Room Key 碎片：大厅三台机器各藏 1/3（节点 WallCollisions/FinalKeyMachine1..3）。
const FINAL_KEY_MACHINE_PATHS: Array[NodePath] = [
	NodePath("WallCollisions/FinalKeyMachine1"),
	NodePath("WallCollisions/FinalKeyMachine2"),
	NodePath("WallCollisions/FinalKeyMachine3"),
]
const FINAL_KEY_MACHINE_RADIUS: float = 110.0

# ============================================================
# Service Corridor (merged into the hall — no separate scene)
# 服务通道并入大厅：Dining Hall 拿到 Service Corridor Key 后，
# 大厅东侧墙门解锁，墙门后是服务通道调查区（拖痕/纤维/维修面板），
# 第 4 片 Final Room Key 碎片藏在维修面板后。
# ============================================================
const SERVICE_WALL_DOOR_POSITION: Vector2 = Vector2(1306, 757)
const SERVICE_WALL_DOOR_RADIUS: float = 100.0
const SERVICE_DARK_TRAIL_POSITION: Vector2 = Vector2(1210, 930)
const SERVICE_FIBER_POSITION: Vector2 = Vector2(1256, 672)
const SERVICE_PANEL_POSITION: Vector2 = Vector2(1170, 770)
const SERVICE_INVESTIGATION_RADIUS: float = 100.0

# ============================================================
# Hall knowledge exhibits — player-provided pixel-art props.
# 大厅知识展品：调查后把 STEM 知识收藏进 NoteHub，作为后续门锁题的学习线索。
# ============================================================
const HALL_KNOWLEDGE_ITEMS: Array[Dictionary] = [
	{
		"id": "DiningHallKnowledge",
		"texture": "res://assets/props/DiningHall/dining_grandfather_clock.png",
		"title": "Dining Hall Knowledge",
		"prompt": "the Dining Hall knowledge exhibit",
		"note_id": "hall_knowledge_dining_timeline",
		"knowledge_flag": "hall_knowledge_dining_hall_collected",
		"knowledge": (
			"When a process changes at a reasonably steady rate, measuring how much it "
			+ "has changed can help estimate elapsed time. One observation is rarely "
			+ "enough; compare several independent indicators before drawing a conclusion."
		),
	},
	{
		"id": "CircuitRoomKnowledge",
		"texture": "res://assets/props/hall_knowledge/hall_knowledge_gauge_machine.png",
		"title": "Circuit Room Knowledge",
		"prompt": "the Circuit Room knowledge exhibit",
		"note_id": "hall_knowledge_electricity",
		"knowledge_flag": "hall_knowledge_circuit_room_collected",
		"knowledge": (
			"The two gauges measure a closed electrical circuit. "
			+ "A conductor lets charge move through the circuit; metal is usually a "
			+ "better conductor than rubber, dry wood, or glass. A broken circuit "
			+ "cannot carry current."
		),
	},
	{
		"id": "ChemistryRoomKnowledge",
		"texture": "res://assets/props/hall_knowledge/hall_knowledge_bronze_core.png",
		"title": "Chemistry Room Knowledge",
		"prompt": "the Chemistry Room knowledge exhibit",
		"note_id": "hall_knowledge_chemical_change",
		"knowledge_flag": "hall_knowledge_chemistry_room_collected",
		"knowledge": (
			"The core is warm because a reaction is taking place inside it. "
			+ "A chemical change creates new substances: burning paper is chemical, "
			+ "while melting ice, breaking glass, and dissolving sugar are physical "
			+ "changes. The difference is whether a new substance forms."
		),
	},
	{
		"id": "GreenhouseRoomKnowledge",
		"texture": "res://assets/props/hall_knowledge/hall_knowledge_green_construct.png",
		"title": "Greenhouse Room Knowledge",
		"prompt": "the Greenhouse Room knowledge exhibit",
		"note_id": "hall_knowledge_photosynthesis",
		"knowledge_flag": "hall_knowledge_greenhouse_room_collected",
		"knowledge": (
			"The living panels are imitating photosynthesis. Plants absorb carbon "
			+ "dioxide from the air and use light and water to make food. Oxygen is "
			+ "released as a product. This is why the greenhouse keeps a supply of "
			+ "light, water, and carbon dioxide."
		),
	},
	{
		"id": "LibraryRoomKnowledge",
		"texture": "res://assets/props/hall_knowledge/hall_knowledge_glowing_console.png",
		"title": "Library Knowledge",
		"prompt": "the Library knowledge exhibit",
		"note_id": "hall_knowledge_light",
		"knowledge_flag": "hall_knowledge_library_collected",
		"knowledge": (
			"The console mixes light, not paint. The primary colors of light are "
			+ "red, green, and blue. Combining light adds energy and produces brighter "
			+ "colors; this is different from mixing pigments, which usually removes "
			+ "light."
		),
	},
]
var hall_knowledge_items: Array[Dictionary] = []
var hall_knowledge_sprites: Dictionary = {}

# ============================================================
# Knowledge-lock questions for every room door (key + question).
# 每个房间门 = 实体钥匙 + 知识题双锁；答对一次后永久解锁。
# ============================================================
const DOOR_QUESTIONS: Dictionary = {
	"chemistry": {
		"question": "Which of these is a chemical change?",
		"options": ["Burning paper", "Melting ice", "Breaking glass", "Dissolving sugar"],
		"correct": 0,
		"knowledge_flag": "hall_knowledge_chemistry_room_collected",
	},
	"greenhouse": {
		"question": "Which gas do plants absorb from the air to make their food?",
		"options": ["Carbon dioxide", "Oxygen", "Nitrogen", "Argon"],
		"correct": 0,
		"knowledge_flag": "hall_knowledge_greenhouse_room_collected",
	},
	"circuit": {
		"question": "Which material usually allows electricity to flow most easily?",
		"options": ["Metal", "Rubber", "Dry wood", "Glass"],
		"correct": 0,
		"knowledge_flag": "hall_knowledge_circuit_room_collected",
	},
	"dining": {
		"question": "Which principle helps estimate elapsed time from a changing process?",
		"options": ["Measure a reasonably steady change and compare independent indicators", "Trust the first visible clue", "Use the color of one object", "Assume every process changes at the same rate"],
		"correct": 0,
		"knowledge_flag": "hall_knowledge_dining_hall_collected",
	},
	"library": {
		"question": "Which of these is a primary color of light?",
		"options": ["Red", "Yellow", "Purple", "Brown"],
		"correct": 0,
		"knowledge_flag": "hall_knowledge_library_collected",
	},
	"final": {
		"question": "Final synthesis lock",
		"options": [],
		"correct": 0,
	},
}

const FINAL_SYNTHESIS_QUESTIONS: Array[Dictionary] = [
	{
		"question": "A sheet of paper burns and leaves ash. Why is this evidence of a chemical change?",
		"options": ["A new substance forms", "The paper only changes shape", "The ash is the same substance as the paper", "Heat cannot change matter"],
		"correct": 0,
	},
	{
		"question": "If carbon dioxide is removed from a sealed greenhouse, which process is directly limited?",
		"options": ["Photosynthesis", "Condensation", "Magnetism", "Sound transmission"],
		"correct": 0,
	},
	{
		"question": "Which material is the best choice to reconnect a broken conducting path?",
		"options": ["Metal", "Rubber", "Dry wood", "Glass"],
		"correct": 0,
	},
	{
		"question": "Which combination provides the strongest estimate of elapsed time?",
		"options": ["Several independent indicators that changed at reasonably steady rates", "One clock reading by itself", "The color of one object", "A guess based on the first clue"],
		"correct": 0,
	},
]

# Wake Room return entrance: use the user's manually adjusted position.
const WAKE_ROOM_SCENE_PATH: String = \
	"res://scenes/wake_room.tscn"
const WAKE_ROOM_DOOR_POSITION: Vector2 = Vector2(258, 1050)
const WAKE_ROOM_DOOR_FOCUS_POSITION: Vector2 = Vector2(258, 1050)
const WAKE_ROOM_DOOR_INTERACT_RADIUS: float = 75.0
# ============================================================
# Floor 1 world positions
# ============================================================

# 用户手动确认的 Entrance / Wake Room 位置。
const HALL_ENTRANCE_POSITION: Vector2 = Vector2(240, 1040)

# Upper-left chemistry crime scene.
const RED_STAIN_POSITION: Vector2 = Vector2(410.7005, 273.7006)
const BUTLER_POSITION: Vector2 = Vector2(505.0796, 386.3819)

# Upper-right greenhouse.
const POLLEN_POSITION: Vector2 = Vector2(1509.753, 324.0475)
# Keep the NPC on the walkable tile beside the east wall.
const GARDENER_POSITION: Vector2 = Vector2(1648, 496)

# Lower entrance to the electrical machinery room.
# The old point (332,899) was inside a wall cell. Use the walkable
# threshold for interaction and keep the visual focus on the doorway.
const CIRCUIT_DOOR_POSITION: Vector2 = Vector2(168, 691)
const CIRCUIT_DOOR_FOCUS_POSITION: Vector2 = Vector2(168, 691)

# Maintenance note in the service corridor outside the locked door.
const CIRCUIT_NOTE_POSITION: Vector2 = Vector2(541.0419, 641.9716)

# Open floor on the right side of the large central machine.
const CIRCUIT_CLUE_POSITION: Vector2 = Vector2(476.587, 709.4276)

# Open floor near the lower part of the machinery room.
const MECHANIC_POSITION := Vector2(339.7926, 804.8627)

# Open floor to the left of the round deduction table.
const FINAL_ROOM_POSITION: Vector2 = Vector2(955, 138)

# 用户手动确认的敌人复活点。
const ENEMY_START_POSITION: Vector2 = Vector2(1611, 1070)
var hall_arrival_finished := false
var enemy_chase_started := false
var _damage_invincible_timer: float = 0.0
const CASTLE_FLOOR_1_BACKGROUND := \
	"res://assets/backgrounds/hall_floor_bg.png"
# 布局对齐模式已关闭：大厅使用真实网格碰撞（来自 hall_walls.png）+
# 两张用户提供的 GPT 素材图（地板 + 墙壁）。
const LAYOUT_ALIGNMENT_MODE := false
const SHOW_LAYOUT_MARKERS := true

@export var interaction_hint_position: Vector2 = Vector2(238, 696)
@export var interaction_hint_size: Vector2 = Vector2(548, 68)

## 调试开关：默认关闭。需要校准时可在 Inspector 勾选此项，
## 在输出面板打印鼠标所在的世界坐标。
@export var debug_print_click_position := false
var _last_debug_mouse_position := Vector2(-100000, -100000)

# Keep old wall collisions and navigation,
# but hide their colored prototype rectangles.
const SHOW_PROTOTYPE_WALL_VISUALS := false
var scene_transitioning: bool = false
func _ready():
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = "floor_1_hub"
	GameState.set_room_visited("floor_1_hub")
	GameState.set_resume_location(
		"res://scenes/game_world.tscn",
		"floor_1_hub",
		GameState.return_spawn_id
	)

	load_progress_from_game_state()
	circuit_door_position = CIRCUIT_DOOR_POSITION
	circuit_note_position = CIRCUIT_NOTE_POSITION
	# 大厅视觉：hall_floor_bg.png（地板）+ hall_walls.png（墙壁）。
	# CASTLE_LAYOUT 只保留给寻路/边界 fallback；玩家碰撞以
	# scenes/wall_collisions.tscn 的作者绘制多边形为准。
	if not LAYOUT_ALIGNMENT_MODE:
		create_castle_walls()

	# 大厅视觉（地板图 + 墙壁图 Sprite2D）随 wall_collisions.tscn
	# 一起加载：墙壁图与碰撞多边形同源同坐标系，编辑器 2D 视图里
	# 可直接看到并对照调节，不再由代码创建，避免双重显示与比例不一致。

	create_wall_collision_polygons()
	use_authored_wall_collision_probe = (
		get_node_or_null("WallCollisions") != null
	)
	# 必须在作者碰撞实例化之后建立寻路网格；否则 A* 会把旧的
	# CASTLE_LAYOUT 当成大厅的真实墙体，重新制造空气墙。
	if not LAYOUT_ALIGNMENT_MODE:
		build_navigation_grid()
	# 正常游玩不显示碰撞调试层；F3 开发者模式仍可手动开启。
	get_tree().debug_collisions_hint = GameState.developer_mode
	# 大厅墙体由 wall_collisions.tscn 提供；玩家移动使用其真实
	# StaticBody2D/CollisionPolygon2D 做形状查询，不再被粗略网格挡住。
	player.collision_mask = 0
	build_sight_blockers()
	sync_hall_knowledge_items()

	# 房间内部的线索/NPC 不在大厅生成：
	# Chemistry、Greenhouse、Circuit、Dining 等内容应归属于各自房间。
	# 大厅只保留房间入口、门锁和大厅专属内容。

	create_fog_cells()
	create_game_ui()
	create_interaction_focus()
	create_developer_mode_label()
	create_game_over_ui()
	apply_persistent_visual_state()
	player.position = get_floor_one_spawn_position()

	if player.has_method("set_visual_scale"):
		player.call(
			"set_visual_scale",
			1.0
		)

	var ground_move_callback: Callable = Callable(
		self,
		"on_player_ground_move_started"
	)

	if (
		player.has_signal("ground_move_started")
		and not player.is_connected(
			"ground_move_started",
			ground_move_callback
		)
	):
		player.connect(
			"ground_move_started",
			ground_move_callback
		)

	create_follow_camera()
	setup_enemy()

	if SHOW_LAYOUT_MARKERS:
		create_floor_one_layout_markers()

	if not GameState.hall_arrival_seen:
		show_castle_hall_arrival()
	else:
		resume_castle_hall_after_return()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(
		"toggle_developer_mode"
	):
		toggle_developer_mode()

	# 追逐模式计时与敌人启动。
	if _damage_invincible_timer > 0.0:
		_damage_invincible_timer -= delta
	update_enemy_chase_state()

	update_camera_zoom(delta)
	# MapHub 持久化大厅探索：玩家走过的 32px 区域会被记录，
	# 即使离开大厅，真实地图的黑暗也不会恢复。
	GameState.reveal_hall_position(player.global_position)

	# 下面保留你原来的代码。
	if Input.is_action_just_pressed(
		"restart_game"
	):
		restart_current_game()
		return

	if Input.is_action_just_pressed("return_menu"):
		return_to_main_menu()
		return

	if Input.is_action_just_pressed("objective_panel"):
		toggle_objective_panel()
		return
	if Input.is_action_just_pressed("knowledge_journal"):
		# 优先使用全局侦探笔记（NoteHud 书本图标）；未解锁时回退旧面板
		if NoteHud != null and NoteHud.is_unlocked():
			NoteHud.toggle()
		else:
			toggle_knowledge_journal()
		hide_interaction_feedback()
		return

	if game_over:
		hide_interaction_feedback()
		return

	if dialogue_active:
		if (
			Input.is_action_just_pressed("interact")
			and dialogue_continue_button != null
			and dialogue_continue_button.visible
		):
			dialogue_continue_button.pressed.emit()
		update_fog_of_war()
		hide_interaction_feedback()
		return

	if objective_panel_open:
		update_fog_of_war()
		hide_interaction_feedback()
		return

	update_fog_of_war()
	update_interaction_prompt()
	update_interaction_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = interact_label.visible

	if Input.is_action_just_pressed("interact"):
		try_investigate_clue()

	if Input.is_action_just_pressed("evidence_board"):
		toggle_evidence_board()

func create_floor():
	var floor = ColorRect.new()
	floor.color = Color(0.12, 0.12, 0.14)
	floor.size = Vector2(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)
	floor.z_index = -10
	add_child(floor)
func on_player_ground_move_started(
	target_position: Vector2
) -> void:
	var target_cell: Vector2i = world_to_cell(
		target_position
	)

	if not is_inside_map(target_cell):
		return

	if use_authored_wall_collision_probe:
		if has_authored_wall_collision(target_position):
			return
	elif is_wall(target_cell):
		return

	var start_cell: Vector2i = world_to_cell(
		player.global_position
	)

	var path: Array = find_path(
		start_cell,
		target_cell
	)

	if path.is_empty():
		return

	var path_points := PackedVector2Array()

	for cell in path:
		path_points.append(
			cell_to_world(cell)
		)

	if player.has_method("move_along_path"):
		player.call(
			"move_along_path",
			path_points
		)


func create_castle_background():
	var texture: Texture2D = load(
		CASTLE_FLOOR_1_BACKGROUND
	) as Texture2D

	if texture == null:
		push_warning(
			"Castle floor background not found: "
			+ CASTLE_FLOOR_1_BACKGROUND
		)

		create_floor()
		return

	var background := Sprite2D.new()
	background.name = "CastleFloor1Background"
	background.texture = texture
	background.centered = false
	background.position = Vector2.ZERO
	background.z_index = -100

	var texture_size: Vector2 = texture.get_size()

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		push_warning("Castle background has an invalid size.")
		create_floor()
		return

	background.scale = Vector2(
		float(MAP_PIXEL_WIDTH) / texture_size.x,
		float(MAP_PIXEL_HEIGHT) / texture_size.y
	)

	add_child(background)

func create_castle_walls():
	# Layout is stored as a 60x40 string map (same grid as the
	# original castle background art): '#' = wall. The old 'K'
	# knowledge-lock door cells are no longer built — every room
	# door is now an interaction-driven knowledge lock instead of
	# a physical grid door.
	for y in range(CASTLE_LAYOUT.size()):
		var row: String = CASTLE_LAYOUT[y]
		for x in range(row.length()):
			if row[x] == "#":
				add_wall_cell(Vector2i(x, y))


func add_wall_rect(start_cell: Vector2i, end_cell: Vector2i):
	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):
			add_wall_cell(Vector2i(x, y))


func add_wall_cell(cell: Vector2i):
	var key = cell_key(cell)

	if wall_cells.has(key):
		return

	wall_cells[key] = true

	# 物理碰撞统一由 scenes/wall_collisions.tscn 提供（编辑器里可见
	# 可编辑的 StaticBody2D 集合）；这里只为寻路/交互维护 wall_cells
	# 数据，不再为每个墙格创建网格碰撞体（避免与用户编辑的碰撞重复）。
	# var wall = StaticBody2D.new()
	# wall.name = "Wall"
	# wall.position = cell_to_world(cell)
	#
	# var shape = CollisionShape2D.new()
	# var rectangle = RectangleShape2D.new()
	# rectangle.size = Vector2(CELL_SIZE, CELL_SIZE)
	# shape.shape = rectangle
	# wall.add_child(shape)
	#
	# if SHOW_PROTOTYPE_WALL_VISUALS:
	# 	var visual := ColorRect.new()
	# 	visual.color = Color(0.22, 0.18, 0.28)
	# 	visual.size = Vector2(CELL_SIZE, CELL_SIZE)
	# 	visual.position = Vector2(
	# 		-CELL_SIZE / 2.0,
	# 		-CELL_SIZE / 2.0
	# 	)
	# 	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 	wall.add_child(visual)
	#
	# add_child(wall)


func create_wall_collision_polygons() -> void:
	# Collision polygons from assets/backgrounds/hall_walls.png,
	# exported to scenes/wall_collisions.tscn so every wall block is
	# visible and editable in the editor (Wall_000..Wall_205).
	var scene: PackedScene = load(
		"res://scenes/wall_collisions.tscn"
	) as PackedScene

	if scene == null:
		push_warning("wall_collisions.tscn not found")
		return

	var instance: Node2D = scene.instantiate()
	instance.name = "WallCollisions"
	add_child(instance)


func create_fog_cells():
	if LAYOUT_ALIGNMENT_MODE and DISABLE_FOG_DURING_ALIGNMENT:
		return

	# 迷雾改为单张 ImageTexture + 一个 Sprite2D（1 个 draw call）。
	# 旧实现是 9600 个 ColorRect，每帧全部重绘导致 M3 上每帧数秒。
	fog_image = Image.create(
		FOG_COLS,
		FOG_ROWS,
		false,
		Image.FORMAT_RGBA8
	)
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	fog_texture = ImageTexture.create_from_image(fog_image)

	fog_sprite = Sprite2D.new()
	fog_sprite.name = "FogOfWarSprite"
	fog_sprite.texture = fog_texture
	fog_sprite.centered = false
	fog_sprite.position = Vector2.ZERO
	fog_sprite.scale = Vector2(FOG_CELL_SIZE, FOG_CELL_SIZE)
	fog_sprite.z_index = 100
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fog_sprite)


func update_fog_of_war():
	if LAYOUT_ALIGNMENT_MODE and DISABLE_FOG_DURING_ALIGNMENT:
		return

	# 开发者模式（F3）：取消全部阴影，直接看全图。
	if GameState.developer_mode:
		if fog_image != null:
			fog_image.fill(Color(0.0, 0.0, 0.0, 0.0))
			fog_texture.update(fog_image)
		return

	visible_fog_cells.clear()
	visible_fog_distances.clear()

	if fog_image == null:
		return

	var player_world = player.global_position

	# 基础全黑。
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))

	# 曾经发现过、但当前视线不可达的格子：暗影轮廓。
	# 追逐模式：走过的地方不留记忆，保持全黑（只有手电筒范围可见）。
	if not GameState.chase_mode:
		for key: Variant in discovered_fog_cells.keys():
			var parts: PackedStringArray = str(key).split(",")
			if parts.size() != 2:
				continue
			var cell_x: int = int(parts[0])
			var cell_y: int = int(parts[1])
			if cell_x < 0 or cell_x >= FOG_COLS or cell_y < 0 or cell_y >= FOG_ROWS:
				continue
			fog_image.set_pixel(
				cell_x,
				cell_y,
				Color(0.0, 0.0, 0.0, DISCOVERED_DARKNESS)
			)

	# 追逐模式：手电筒式视野（更小的半径、更暗的边缘）。
	# Vision Potion 生效时扩大视野——药水降低追逐难度。
	var vision_radius: float = VISION_RADIUS_PIXELS
	var clear_radius: float = CLEAR_RADIUS_PIXELS
	var edge_darkness: float = EDGE_DARKNESS
	if GameState.chase_mode:
		vision_radius = 230.0
		clear_radius = 80.0
		edge_darkness = 0.85
		if GameState.is_potion_active("vision"):
			vision_radius = 430.0
			clear_radius = 160.0
			edge_darkness = 0.55

	var min_x = int(max(0, (player_world.x - vision_radius) / FOG_CELL_SIZE))
	var max_x = int(min(FOG_COLS - 1, (player_world.x + vision_radius) / FOG_CELL_SIZE))
	var min_y = int(max(0, (player_world.y - vision_radius) / FOG_CELL_SIZE))
	var max_y = int(min(FOG_ROWS - 1, (player_world.y + vision_radius) / FOG_CELL_SIZE))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var fog_cell = Vector2i(x, y)
			var target_world = fog_cell_to_world_center(fog_cell)
			var distance = player_world.distance_to(target_world)

			if distance > vision_radius:
				continue

			if has_world_line_of_sight(player_world, target_world):
				var key = fog_key(fog_cell)
				visible_fog_cells[key] = true
				visible_fog_distances[key] = distance
				discovered_fog_cells[key] = true

				var edge_amount = 0.0
				if distance > clear_radius:
					edge_amount = (distance - clear_radius) / (vision_radius - clear_radius)
					edge_amount = clamp(edge_amount, 0.0, 1.0)

				var alpha = edge_amount * edge_darkness
				fog_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

	fog_texture.update(fog_image)


func build_sight_blockers() -> void:
	# 从用户编辑的碰撞多边形（scenes/wall_collisions.tscn）光栅化
	# 出 16px 视线遮挡格：手电筒视野被真实墙壁遮挡，
	# 没有碰撞的装饰物不再挡视线。
	sight_blockers.clear()

	var wall_root: Node = get_node_or_null("WallCollisions")
	if wall_root == null:
		return

	for body: Node in wall_root.get_children():
		if not body is StaticBody2D:
			continue
		for shape_node: Node in body.get_children():
			if not shape_node is CollisionPolygon2D:
				continue
			var poly: PackedVector2Array = (shape_node as CollisionPolygon2D).polygon
			if poly.size() < 3:
				continue

			# 变换到世界坐标（用户可能在编辑器里移动过节点）
			var world_poly := PackedVector2Array()
			var xform: Transform2D = (shape_node as CollisionPolygon2D).global_transform
			for p: Vector2 in poly:
				world_poly.append(xform * p)

			var min_x := 1e9
			var min_y := 1e9
			var max_x := -1e9
			var max_y := -1e9
			for p: Vector2 in world_poly:
				min_x = minf(min_x, p.x)
				min_y = minf(min_y, p.y)
				max_x = maxf(max_x, p.x)
				max_y = maxf(max_y, p.y)

			var start_x := int(maxf(0.0, min_x) / FOG_CELL_SIZE)
			var end_x := int(minf(MAP_PIXEL_WIDTH, max_x) / FOG_CELL_SIZE)
			var start_y := int(maxf(0.0, min_y) / FOG_CELL_SIZE)
			var end_y := int(minf(MAP_PIXEL_HEIGHT, max_y) / FOG_CELL_SIZE)

			for gy in range(start_y, end_y + 1):
				for gx in range(start_x, end_x + 1):
					var center := Vector2(
						gx * FOG_CELL_SIZE + FOG_CELL_SIZE / 2.0,
						gy * FOG_CELL_SIZE + FOG_CELL_SIZE / 2.0
					)
					if Geometry2D.is_point_in_polygon(center, world_poly):
						sight_blockers[fog_key(Vector2i(gx, gy))] = true


func has_world_line_of_sight(start_world: Vector2, end_world: Vector2) -> bool:
	# 手电筒式视线遮挡：被真实碰撞多边形（wall_collisions.tscn 里
	# 用户编辑的 StaticBody2D）遮挡。使用 Bresenham 逐格扫描，
	# 薄墙/斜角都能可靠命中；终点是遮挡格（墙/家具）时视为可见，
	# 这样玩家能看到完整的墙壁轮廓，但墙和物品后面的区域不可见。
	var start_cell: Vector2i = Vector2i(
		int(start_world.x / FOG_CELL_SIZE),
		int(start_world.y / FOG_CELL_SIZE)
	)
	var end_cell: Vector2i = Vector2i(
		int(end_world.x / FOG_CELL_SIZE),
		int(end_world.y / FOG_CELL_SIZE)
	)

	if start_cell == end_cell:
		return true

	if sight_blockers.has(fog_key(end_cell)):
		return true

	var x0: int = start_cell.x
	var y0: int = start_cell.y
	var x1: int = end_cell.x
	var y1: int = end_cell.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy

	while true:
		if x0 == x1 and y0 == y1:
			break
		if sight_blockers.has(fog_key(Vector2i(x0, y0))):
			return false
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

	return true


func is_wall(cell: Vector2i) -> bool:
	return wall_cells.has(cell_key(cell))


func is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT


func is_player_position_walkable(world_position: Vector2) -> bool:
	# 地图边界和锁门仍由网格数据判断；墙体本身使用
	# wall_collisions.tscn 中可在 Inspector 编辑的真实多边形。
	var sample_offsets: Array[Vector2] = [
		Vector2(-8.0, -5.0),
		Vector2(8.0, -5.0),
		Vector2(-8.0, 5.0),
		Vector2(8.0, 5.0),
		Vector2.ZERO,
	]
	for sample_offset: Vector2 in sample_offsets:
		var cell: Vector2i = world_to_cell(world_position + sample_offset)
		if not is_inside_map(cell):
			return false

	if use_authored_wall_collision_probe:
		return not has_authored_wall_collision(world_position)

	# wall_collisions.tscn 不存在时才回退到旧网格，避免场景缺资源后
	# 把地图边界完全放开。
	for sample_offset: Vector2 in sample_offsets:
		var fallback_cell: Vector2i = world_to_cell(
			world_position + sample_offset
		)
		if is_wall(fallback_cell):
			return false
	return true


func has_authored_wall_collision(world_position: Vector2) -> bool:
	var player_body: CharacterBody2D = player as CharacterBody2D
	if player_body == null:
		return false

	var collision_shape: CollisionShape2D = player_body.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(
		player_body.global_rotation,
		world_position + collision_shape.position.rotated(
			player_body.global_rotation
		)
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var excluded_rids: Array[RID] = [player_body.get_rid()]
	query.exclude = excluded_rids

	var collisions: Array[Dictionary] = (
		get_world_2d().direct_space_state.intersect_shape(
			query,
			1
		)
	)
	return not collisions.is_empty()


func move_player_to_cell(cell: Vector2i):
	player.position = cell_to_world(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2,
		cell.y * CELL_SIZE + CELL_SIZE / 2
	)


func fog_cell_to_world_center(fog_cell: Vector2i) -> Vector2:
	return Vector2(
		fog_cell.x * FOG_CELL_SIZE + FOG_CELL_SIZE / 2,
		fog_cell.y * FOG_CELL_SIZE + FOG_CELL_SIZE / 2
	)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / CELL_SIZE),
		int(world_position.y / CELL_SIZE)
	)


func cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)


func fog_key(fog_cell: Vector2i) -> String:
	return str(fog_cell.x) + "," + str(fog_cell.y)
func build_navigation_grid():
	astar_grid.region = Rect2i(0, 0, MAP_WIDTH, MAP_HEIGHT)
	astar_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

	for y: int in range(MAP_HEIGHT):
		for x: int in range(MAP_WIDTH):
			var cell := Vector2i(x, y)
			var point_is_solid: bool = false
			if use_authored_wall_collision_probe:
				point_is_solid = has_authored_wall_collision(
					cell_to_world(cell)
				)
			else:
				point_is_solid = is_wall(cell)
			if point_is_solid:
				astar_grid.set_point_solid(cell, true)


func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array:
	if not is_inside_map(start_cell):
		return []

	if not is_inside_map(end_cell):
		return []

	if astar_grid.is_point_solid(start_cell) or astar_grid.is_point_solid(end_cell):
		return []

	return astar_grid.get_id_path(start_cell, end_cell)


func setup_enemy():
	if enemy == null:
		return

	enemy.position = ENEMY_START_POSITION
	enemy.setup(self, player)

	if LAYOUT_ALIGNMENT_MODE:
		enemy.visible = false
		enemy.set_physics_process(false)
		return

	enemy.visible = false
	enemy.set_physics_process(false)


## 追逐模式开启时让敌人出现并开始追击；结束后停止。
func update_enemy_chase_state() -> void:
	if enemy == null:
		return
	if GameState.chase_mode and not enemy_chase_started:
		enemy_chase_started = true
		enemy.position = ENEMY_START_POSITION
		enemy.visible = true
		enemy.set_physics_process(true)
	elif not GameState.chase_mode and enemy_chase_started:
		enemy_chase_started = false
		enemy.visible = false
		enemy.set_physics_process(false)


func create_game_over_ui() -> void:
	game_over_canvas = CanvasLayer.new()
	game_over_canvas.name = "GameOverUI"
	game_over_canvas.layer = 20
	game_over_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_over_canvas)

	var death_scene: PackedScene = load(DEATH_UI_SCENE_PATH) as PackedScene
	if death_scene == null:
		push_error("Death UI scene could not be loaded: " + DEATH_UI_SCENE_PATH)
		return
	game_over_screen_root = death_scene.instantiate() as Control
	if game_over_screen_root == null:
		push_error("Death UI scene root must be a Control.")
		return
	game_over_screen_root.name = "DeathUI"
	game_over_screen_root.visible = false
	game_over_canvas.add_child(game_over_screen_root)
	game_over_screen_root.connect("retry_requested", Callable(self, "restart_current_game"))
	game_over_screen_root.connect("checkpoint_requested", Callable(self, "restart_from_checkpoint"))
	game_over_screen_root.connect("main_menu_requested", Callable(self, "return_to_main_menu"))


func on_player_caught():
	if game_over:
		return
	# 受击后短暂无敌，避免连续扣血。
	if _damage_invincible_timer > 0.0:
		return

	var died: bool = GameState.take_damage()

	if not died:
		# 正常模式：3 次才死亡；受击后怪物重置，玩家获得喘息。
		_damage_invincible_timer = 2.0
		if enemy != null:
			enemy.position = ENEMY_START_POSITION
		player.position = get_floor_one_spawn_position()
		show_damage_feedback(GameState.player_health)
		return

	game_over = true
	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	if game_over_screen_root != null:
		game_over_screen_root.visible = true


## 受击反馈：显示剩余生命。
func show_damage_feedback(health_left: int) -> void:
	if health_left <= 0:
		return
	if interact_label == null or interaction_hint_panel == null:
		return
	interact_label.text = "The Castle Guardian strikes you! %d hits left before it finishes you." % health_left
	interaction_hint_panel.visible = true


func create_red_stain_clue():
	clue_position = RED_STAIN_POSITION

	clue_node = ColorRect.new()
	clue_node.name = "RedStainClue"
	clue_node.color = Color(0.75, 0.02, 0.04, 1.0)
	clue_node.size = Vector2(26, 18)
	clue_node.position = clue_position - clue_node.size / 2
	clue_node.z_index = 5

	add_child(clue_node)
	add_world_label(clue_node, "Red Stain", Vector2(-26, -24))


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

	if current_interaction.begins_with("hall_knowledge:"):
		var exhibit_id: String = current_interaction.trim_prefix("hall_knowledge:")
		for item: Dictionary in hall_knowledge_items:
			if str(item["id"]) == exhibit_id:
				interaction_focus.set_focus(
					item["position"] as Vector2,
					str(item["title"]),
					false
				)
				return

	match current_interaction:
		"chemistry_room_door":
			target_position = CHEMISTRY_ROOM_DOOR_FOCUS_POSITION
			focus_title = "Chemistry Room"
			is_primary = true
		"greenhouse_room_door":
			target_position = GREENHOUSE_ROOM_DOOR_FOCUS_POSITION
			focus_title = "Greenhouse Room"
			is_primary = true
		"library_door":
			target_position = LIBRARY_DOOR_POSITION
			focus_title = "Library"
			is_primary = true
		"dining_hall_door":
			target_position = DINING_HALL_DOOR_POSITION
			focus_title = "Dining Hall"
			is_primary = true
		"final_room_door":
			target_position = FINAL_ROOM_DOOR_FOCUS_POSITION
			focus_title = "Final Room"
			is_primary = true
		"wake_room_door":
			target_position = WAKE_ROOM_DOOR_FOCUS_POSITION
			focus_title = "Wake Room entrance"
			is_primary = true
		"circuit_door":
			target_position = CIRCUIT_DOOR_FOCUS_POSITION
			focus_title = "Circuit Room"
			is_primary = true
		"hidden_library_key":
			target_position = _get_storage_rack_position()
			focus_title = "Storage Rack"
			is_primary = false
		"final_key_machine_1":
			target_position = _get_final_key_machine_position(0)
			focus_title = "Tower Machine"
			is_primary = false
		"final_key_machine_2":
			target_position = _get_final_key_machine_position(1)
			focus_title = "Engine Machine"
			is_primary = false
		"final_key_machine_3":
			target_position = _get_final_key_machine_position(2)
			focus_title = "Workshop Machine"
			is_primary = false
		"service_wall_door":
			target_position = SERVICE_WALL_DOOR_POSITION
			focus_title = "Service Passage"
			is_primary = false
		"service_dark_trail":
			target_position = SERVICE_DARK_TRAIL_POSITION
			focus_title = "Dark Trail"
			is_primary = false
		"service_violet_fiber":
			target_position = SERVICE_FIBER_POSITION
			focus_title = "Violet Fiber"
			is_primary = false
		"service_maintenance_panel":
			target_position = SERVICE_PANEL_POSITION
			focus_title = "Maintenance Panel"
			is_primary = false
		_:
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


func create_game_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	# 左上角不再显示白色文字标签：Reputation / 按键提示 / 目标摘要
	# 全部由全局 NoteHud 承担。以下标签保留变量以兼容逻辑，
	# 但完全不创建（reputation_label 等保持 null，更新函数已有空保护）。
	reputation_label = null
	evidence_hint_label = null
	objective_summary_label = null

	create_objective_panel_ui()

	# 统一大厅交互提示：世界空间角标 + 屏幕底部旧铜 E 面板。
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
	interact_label.text = "Press E to investigate"
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
	var message_style := StyleBoxFlat.new()
	message_style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	message_style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	message_style.set_border_width_all(2)
	message_style.set_corner_radius_all(10)
	message_panel.add_theme_stylebox_override("panel", message_style)

	# 右上角 X：退出交互状态（等同于关闭对话框）。
	var message_close_button := Button.new()
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
	message_label.custom_minimum_size = Vector2(780, 150)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.add_child(message_label)

	button_scroll = ScrollContainer.new()
	button_scroll.position = Vector2(164, 184)
	button_scroll.size = Vector2(700, 52)
	button_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_panel.add_child(button_scroll)

	button_box = HBoxContainer.new()
	button_box.add_theme_constant_override("separation", 8)
	button_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	button_scroll.add_child(button_box)

	dialogue_action_row = HBoxContainer.new()
	dialogue_action_row.position = Vector2(740, 184)
	dialogue_action_row.size = Vector2(260, 52)
	dialogue_action_row.alignment = BoxContainer.ALIGNMENT_END
	message_panel.add_child(dialogue_action_row)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_action_row.add_child(spacer)

	dialogue_continue_button = Button.new()
	dialogue_continue_button.text = "Continue"
	dialogue_continue_button.custom_minimum_size = Vector2(180, 34)
	dialogue_continue_button.add_theme_font_size_override("font_size", 15)
	dialogue_continue_button.visible = false
	dialogue_action_row.add_child(dialogue_continue_button)

	set_dialogue_speaker("Mrs. Lin")
	apply_dialogue_visual_style()
	create_evidence_board_ui()
	create_knowledge_journal_ui()
	update_objective_text()
	


func sync_hall_knowledge_items() -> void:
	hall_knowledge_items.clear()
	hall_knowledge_sprites.clear()
	for template: Dictionary in HALL_KNOWLEDGE_ITEMS:
		var item: Dictionary = template.duplicate(true)
		var exhibit_id: String = str(item["id"])
		var exhibit_node: Node2D = get_node_or_null(
			"WallCollisions/KnowledgeExhibits/" + exhibit_id
		) as Node2D
		if exhibit_node == null:
			push_warning("Knowledge exhibit node missing: " + exhibit_id)
			continue
		# Inspector/tscn 是位置唯一来源；脚本不覆盖父节点 Transform。
		item["position"] = exhibit_node.global_position
		hall_knowledge_items.append(item)
		hall_knowledge_sprites[exhibit_id] = exhibit_node.get_node_or_null("Sprite")


func _get_storage_rack_position() -> Vector2:
	var rack: Node2D = get_node_or_null("WallCollisions/StorageRack") as Node2D
	if rack != null:
		return rack.global_position
	return HIDDEN_LIBRARY_KEY_POSITION


func _get_final_key_machine_position(index: int) -> Vector2:
	if index < 0 or index >= FINAL_KEY_MACHINE_PATHS.size():
		return Vector2.ZERO
	var machine: Node2D = get_node_or_null(FINAL_KEY_MACHINE_PATHS[index]) as Node2D
	if machine != null:
		return machine.global_position
	return Vector2.ZERO


func update_interaction_prompt() -> void:
	current_interaction = ""

	if interact_label == null:
		return

	interact_label.visible = false

	if message_panel.visible:
		return

	if evidence_board_open:
		return

	if objective_panel_open:
		return

	if knowledge_panel_open:
		return

	# ========================================================
	# Corridor note fragments (Mrs. Lin's torn pages)
	# ========================================================

	for index: int in range(CORRIDOR_FRAGMENT_POSITIONS.size()):
		var fragment_index: int = index + 1
		if not _is_corridor_fragment_active(fragment_index):
			continue
		var flag_id: String = "corridor_fragment_%d" % fragment_index
		if GameState.has_story_flag(flag_id):
			continue
		var fragment_distance: float = (
			player.global_position.distance_to(
				CORRIDOR_FRAGMENT_POSITIONS[index]
			)
		)
		if fragment_distance <= CORRIDOR_FRAGMENT_RADIUS:
			current_interaction = flag_id
			interact_label.text = "Press E to pick up a torn note"
			interact_label.visible = true
			return

	# ========================================================
	# Optional: Library Room Key hidden in the hall
	# ========================================================

	if not GameState.has_key("library_room_key"):
		var hidden_key_distance: float = (
			player.global_position.distance_to(_get_storage_rack_position())
		)
		if hidden_key_distance <= HIDDEN_LIBRARY_KEY_RADIUS:
			current_interaction = "hidden_library_key"
			interact_label.text = "Press E to search the storage rack"
			interact_label.visible = true
			return

	# ========================================================
	# Final Room Key fragments: 3 machines in the hall
	# ========================================================

	var machine_labels: Array[String] = [
		"Press E to search the tower machine",
		"Press E to search the engine machine",
		"Press E to search the workshop machine",
	]
	for machine_index: int in range(FINAL_KEY_MACHINE_PATHS.size()):
		var station_index: int = machine_index + 1
		if not _is_final_key_station_active(station_index):
			continue
		if GameState.has_final_key_fragment(station_index):
			continue
		var machine_distance: float = (
			player.global_position.distance_to(_get_final_key_machine_position(machine_index))
		)
		if machine_distance <= FINAL_KEY_MACHINE_RADIUS:
			current_interaction = "final_key_machine_%d" % station_index
			interact_label.text = machine_labels[machine_index]
			interact_label.visible = true
			return

	# ========================================================
	# Hall knowledge exhibits
	# ========================================================
	for item: Dictionary in hall_knowledge_items:
		var exhibit_id: String = str(item["id"])
		var collected_flag: String = str(
			item.get("knowledge_flag", "hall_knowledge_%s_collected" % exhibit_id)
		)
		if GameState.has_story_flag(collected_flag):
			continue
		var exhibit_distance: float = player.global_position.distance_to(
			item["position"] as Vector2
		)
		if exhibit_distance <= 100.0:
			current_interaction = "hall_knowledge:" + exhibit_id
			interact_label.text = "Press E to study " + str(item["prompt"])
			interact_label.visible = true
			return

	# ========================================================
	# Chemistry Room entrance
	# ========================================================

	var chemistry_door_distance: float = (
		player.global_position.distance_to(
			CHEMISTRY_ROOM_DOOR_POSITION
		)
	)

	if chemistry_door_distance <= (
		CHEMISTRY_ROOM_DOOR_RADIUS
	):
		current_interaction = "chemistry_room_door"
		if not GameState.has_key("chemistry_room_key"):
			interact_label.text = (
				"The Chemistry Room door is locked. A key must be hidden somewhere nearby."
			)
		elif not GameState.has_story_flag("door_chemistry_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = (
				"Press E to enter the Chemistry Room"
			)
		interact_label.visible = true
		return

	var greenhouse_door_distance: float = (
		player.global_position.distance_to(
			GREENHOUSE_ROOM_DOOR_POSITION
		)
	)

	if greenhouse_door_distance <= (
		GREENHOUSE_ROOM_DOOR_RADIUS
	):
		current_interaction = "greenhouse_room_door"
		if not GameState.has_key("greenhouse_room_key"):
			interact_label.text = (
				"The Greenhouse door is locked. A key must be hidden somewhere nearby."
			)
		elif not GameState.has_story_flag("door_greenhouse_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = (
				"Press E to enter the Greenhouse Room"
			)
		interact_label.visible = true
		return

	var library_door_distance: float = (
		player.global_position.distance_to(
			LIBRARY_DOOR_POSITION
		)
	)

	if library_door_distance <= GREENHOUSE_ROOM_DOOR_RADIUS:
		current_interaction = "library_door"
		if not GameState.has_key("library_room_key"):
			interact_label.text = (
				"The Library door is locked. A key must be hidden somewhere in the hall."
			)
		elif not GameState.has_story_flag("door_library_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = "Press E to enter the Library"
		interact_label.visible = true
		return

	var dining_hall_distance: float = (
		player.global_position.distance_to(
			DINING_HALL_DOOR_POSITION
		)
	)

	if dining_hall_distance <= GREENHOUSE_ROOM_DOOR_RADIUS:
		current_interaction = "dining_hall_door"
		if not GameState.has_key("dining_hall_key"):
			interact_label.text = (
				"The Dining Hall door is locked. A key must be hidden somewhere nearby."
			)
		elif not GameState.has_story_flag("door_dining_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = "Press E to enter the Dining Hall"
		interact_label.visible = true
		return

	var final_room_distance: float = (
		player.global_position.distance_to(
			FINAL_ROOM_DOOR_POSITION
		)
	)

	if final_room_distance <= FINAL_ROOM_DOOR_RADIUS:
		current_interaction = "final_room_door"
		if not GameState.has_key("final_room_key"):
			interact_label.text = (
				"The Final Room door is sealed. Four key fragments must be reassembled before it will open."
			)
		elif not GameState.has_story_flag("door_final_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = (
				"Press E to enter the Final Room"
			)
		interact_label.visible = true
		return

	# ========================================================
	# Service Corridor area (merged into the hall)
	# 服务通道墙门 + 墙门后的三个调查点（拖痕/纤维/维修面板）。
	# ========================================================

	if GameState.has_key("service_corridor_key"):
		if not GameState.has_story_flag("service_wall_door_open"):
			var service_door_distance: float = (
				player.global_position.distance_to(
					SERVICE_WALL_DOOR_POSITION
				)
			)
			if service_door_distance <= SERVICE_WALL_DOOR_RADIUS:
				current_interaction = "service_wall_door"
				interact_label.text = (
					"Press E to unlock the service passage"
				)
				interact_label.visible = true
				return
		else:
			if not GameState.has_evidence("service_corridor_dark_trail"):
				var blood_distance: float = (
					player.global_position.distance_to(SERVICE_DARK_TRAIL_POSITION)
				)
				if blood_distance <= SERVICE_INVESTIGATION_RADIUS:
					current_interaction = "service_dark_trail"
					interact_label.text = "Press E to inspect the dark trail"
					interact_label.visible = true
					return
			if not GameState.has_evidence("service_corridor_fiber"):
				var fiber_distance: float = (
					player.global_position.distance_to(SERVICE_FIBER_POSITION)
				)
				if fiber_distance <= SERVICE_INVESTIGATION_RADIUS:
					current_interaction = "service_violet_fiber"
					interact_label.text = "Press E to inspect the violet fiber"
					interact_label.visible = true
					return
			if not GameState.has_story_flag("service_maintenance_panel_opened"):
				var panel_distance: float = (
					player.global_position.distance_to(SERVICE_PANEL_POSITION)
				)
				if panel_distance <= SERVICE_INVESTIGATION_RADIUS:
					current_interaction = "service_maintenance_panel"
					interact_label.text = "Press E to open the maintenance panel"
					interact_label.visible = true
					return

	# ========================================================
	# Wake Room return door（答对知识锁解锁后可从大厅返回）
	# ========================================================

	var wake_room_door_distance: float = (
		player.global_position.distance_to(
			WAKE_ROOM_DOOR_POSITION
		)
	)

	if wake_room_door_distance <= (
		WAKE_ROOM_DOOR_INTERACT_RADIUS
	):
		current_interaction = "wake_room_door"
		interact_label.text = (
			"Press E to return to the Wake Room"
		)
		interact_label.visible = true
		return

	# ========================================================
	# Circuit knowledge-lock door
	# ========================================================

	# 与其余五扇房门一致：只按「钥匙 / 知识 / 已解锁」三种状态给提示。
	# 这里不能再用 circuit_door_open 作为门槛：那是旧原型实体门的标记，
	# 工坊合上总闸后会被置真（circuit_room.gd），从而让大厅永久失去
	# 线路房入口，玩家也就拿不到餐厅钥匙与线路证据。
	var door_distance: float = (
		player.global_position.distance_to(
			circuit_door_position
		)
	)

	if door_distance <= (
		CIRCUIT_DOOR_INTERACT_RADIUS
	):
		current_interaction = "circuit_door"
		if not GameState.has_key("circuit_room_key"):
			interact_label.text = (
				"The Circuit Room door is locked. A key must be hidden somewhere nearby."
			)
		elif not GameState.has_story_flag("door_circuit_unlocked"):
			interact_label.text = (
				"Press E to answer the knowledge lock"
			)
		else:
			interact_label.text = (
				"Press E to enter the Circuit Room"
			)
		interact_label.visible = true
		return

	# 房间内部线索（Maintenance Note / Pollen / Circuit / NPC / Final Deduction）
	# 不在大厅检测，进入对应房间后由房间脚本负责。

func _is_corridor_fragment_active(fragment_index: int) -> bool:
	if GameState.developer_mode:
		return true
	match fragment_index:
		1:
			return GameState.is_room_completed("chemistry_room")
		2:
			return GameState.is_room_completed("greenhouse_room")
		3:
			return GameState.has_story_flag("circuit_dining_key_found")
		_:
			return false


func _is_final_key_station_active(station_index: int) -> bool:
	if GameState.developer_mode:
		return true
	match station_index:
		1:
			return GameState.is_room_completed("chemistry_room")
		2:
			return GameState.is_room_completed("greenhouse_room")
		3:
			return GameState.has_story_flag("circuit_dining_key_found")
		_:
			return false


func try_investigate_clue() -> void:
	if current_interaction.begins_with("hall_knowledge:"):
		_inspect_hall_knowledge(
			current_interaction.trim_prefix("hall_knowledge:")
		)
		return
	match current_interaction:
		"corridor_fragment_1":
			_collect_corridor_fragment(1)

		"corridor_fragment_2":
			_collect_corridor_fragment(2)

		"corridor_fragment_3":
			_collect_corridor_fragment(3)

		"hidden_library_key":
			_collect_hidden_library_key()

		"final_key_machine_1":
			_inspect_final_key_machine(1)

		"final_key_machine_2":
			_inspect_final_key_machine(2)

		"final_key_machine_3":
			_inspect_final_key_machine(3)

		"chemistry_room_door":
			_try_enter_locked_room("chemistry", "chemistry_room_key", enter_chemistry_room)

		"greenhouse_room_door":
			_try_enter_locked_room("greenhouse", "greenhouse_room_key", enter_greenhouse_room)

		"library_door":
			_try_enter_locked_room("library", "library_room_key", enter_library_room)

		"dining_hall_door":
			_try_enter_locked_room("dining", "dining_hall_key", enter_dining_hall_room)

		"final_room_door":
			_try_enter_locked_room("final", "final_room_key", enter_final_room)

		"service_wall_door":
			_open_service_wall_door()

		"service_dark_trail":
			_investigate_service_dark_trail()

		"service_violet_fiber":
			_investigate_service_fiber()

		"service_maintenance_panel":
			_investigate_service_panel()

		"wake_room_door":
			enter_wake_room()

		"circuit_door":
			_try_enter_locked_room("circuit", "circuit_room_key", enter_circuit_room)

		_:
			pass


# ============================================================
# Hall knowledge exhibits
# ============================================================

func _inspect_hall_knowledge(exhibit_id: String) -> void:
	for item: Dictionary in hall_knowledge_items:
		if str(item["id"]) != exhibit_id:
			continue
		var collected_flag: String = str(
			item.get("knowledge_flag", "hall_knowledge_%s_collected" % exhibit_id)
		)
		if GameState.has_story_flag(collected_flag):
			return
		GameState.set_story_flag(collected_flag)
		if NoteHud != null:
			NoteHud.add_clue(str(item["note_id"]), {
				"title": str(item["title"]),
				"icon": "icon_book",
				"content": str(item["knowledge"]),
				"category": "knowledge",
			})
		start_dialogue_pause()
		clear_buttons()
		set_dialogue_speaker("You")
		message_panel.visible = true
		set_dialogue_text(
			"You",
			str(item["title"]) + "\n\n" + str(item["knowledge"]) + "\n\n"
			+ "This knowledge has been added to NoteHub."
		)
		show_continue_button("Continue", close_message_panel)
		return


## 收集大厅中 Mrs. Lin 撕落的走廊笔记碎片；集齐 3 张后拼凑出路线并得到 Final Room Key。
func _collect_hidden_library_key() -> void:
	if GameState.has_key("library_room_key"):
		return
	GameState.add_key("library_room_key")
	GameState.set_story_flag("hall_library_key_found")
	if NoteHud != null:
		NoteHud.add_clue("library_optional_route", {
			"title": "A Hidden Library Key",
			"content": "A slim brass key stamped with the library's spiral archive seal, hidden among the jars of the storage rack in the hall's south-east corner. The archive is optional — but it may hold information others wanted buried.",
			"category": "knowledge",
		})
	interact_label.text = "A slim brass key was hidden among the rack's jars. The Library is now open."
	interact_label.visible = true


# ============================================================
# Service Corridor (merged into the hall)
# 服务通道墙门解锁后，大厅东侧出现三个调查点；
# 维修面板后藏有第 4 片 Final Room Key 碎片。
# ============================================================

func _open_service_wall_door() -> void:
	if GameState.has_story_flag("service_wall_door_open"):
		return
	GameState.set_story_flag("service_wall_door_open")
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text(
		"Mrs. Lin",
		"The Service Corridor Key fits the hidden lock. The wall panel slides back, revealing a narrow passage behind the hall.\n\n"
		+ "The chase has gone quiet, but the silence feels worse than the footsteps. Whatever happened in this castle passed through here."
	)
	show_continue_button("Enter the passage", close_message_panel)


func _investigate_service_dark_trail() -> void:
	GameState.add_evidence("service_corridor_dark_trail")
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text(
		"Mrs. Lin",
		"A dark trail begins at the passage door and ends beside the maintenance panel.\n\n"
		+ "It is not a pool of blood: the edges contain violet grit and a sharp chemical smell. Something heavy was dragged through here after the blackout — equipment from the workshop."
	)
	show_continue_button("Continue", close_message_panel)
	if NoteHud != null:
		NoteHud.add_clue("service_corridor_dark_trail_note", {
			"title": "The Trail Behind the Banquet",
			"content": "The dark trail contains violet grit and a chemical smell. Something heavy was dragged from the workshop through the service passage.",
			"category": "investigation",
		})


func _investigate_service_fiber() -> void:
	GameState.add_evidence("service_corridor_fiber")
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text(
		"Mrs. Lin",
		"A violet thread is caught on the copper pipe.\n\n"
		+ "It matches the distinctive insulating weave identified on the Circuit Room maintenance gloves and cable wraps. A short strand of copper-colored repair thread is caught in the same material. It may have come from previously repaired maintenance gear, but it does not identify one worker by itself. The person who used this passage carried equipment from the workshop."
	)
	show_continue_button("Continue", close_message_panel)
	if NoteHud != null:
		NoteHud.add_clue("service_corridor_fiber_note", {
			"title": "Violet Fiber on the Pipe",
			"content": "A violet thread caught on the pipe matches the Circuit Room maintenance weave. A short copper-colored repair thread is caught in the same material; it may come from repaired maintenance gear, but it is not enough to identify one worker by itself.",
			"category": "investigation",
		})


func _investigate_service_panel() -> void:
	if GameState.has_story_flag("service_maintenance_panel_opened"):
		return
	GameState.set_story_flag("service_maintenance_panel_opened")
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text(
		"Mrs. Lin",
		"Behind the panel is a hand-drawn route: Dining Hall → service passage → Final Room. One line is circled twice: the gate will not open without the reassembled key.\n\n"
		+ "A fourth machine fragment is wedged behind the panel — the physical Access / Route seal, the final piece of the Final Room Key."
	)
	show_continue_button("Take the fragment", _take_service_key_fragment)
	if NoteHud != null:
		NoteHud.add_clue("service_corridor_panel_note", {
			"title": "Maintenance Route",
			"content": "Dining Hall → service passage → Final Room. The gate will not open without the reassembled key. The fourth fragment is the physical Access / Route seal, completing the Matter, Life, Energy and Access set.",
			"category": "investigation",
		})


func _take_service_key_fragment() -> void:
	if not GameState.has_final_key_fragment(4):
		GameState.collect_final_key_fragment(4)
	GameState.set_story_flag("service_corridor_investigated")
	set_dialogue_text(
		"You",
		"The fourth fragment locks into place. The Final Room Key is complete."
	)
	show_continue_button("Continue", close_message_panel)


## 调查三台机器之一：各藏 1/4 Final Room Key，集齐 4 片合成完整钥匙
## （第 4 片在服务通道维修面板后）。
## 提示与房间内一致：ItemRewardHud 屏幕中心奖励（item_acquired 信号自动触发）。
func _inspect_final_key_machine(machine_index: int) -> void:
	var station_label: String = ""
	var station_domain: String = ""
	match machine_index:
		1:
			station_label = "Seal I"
			station_domain = "Matter / Transformation"
		2:
			station_label = "Seal II"
			station_domain = "Life / Nature"
		3:
			station_label = "Seal III"
			station_domain = "Energy / Engineering"
		_:
			station_label = "Unknown Seal"
			station_domain = "Unknown verification domain"
	if not _is_final_key_station_active(machine_index):
		interact_label.text = (
			("The Ashford Verification Relay for %s is dormant. " % [station_label])
			+ "It is connected to one of the castle's research wings; complete that investigation before the indicator can respond."
		)
		interact_label.visible = true
		return
	GameState.set_story_flag("ashford_seal_station_%d_active" % machine_index)
	if not GameState.has_story_flag("ashford_relay_lore_seen"):
		GameState.set_story_flag("ashford_relay_lore_seen")
		if NoteHud != null:
			NoteHud.add_clue("ashford_verification_relay", {
				"title": "Ashford Verification Relay System",
				"content": "Lord Ashford wired the main research wings to mechanical and electrical verification relays in the Castle Hall. Chemistry verifies Matter / Transformation, Greenhouse verifies Life / Nature, and Circuit verifies Energy / Engineering. The Service Area supplies the physical Access / Route fragment; no magic is involved. Each completed investigation sends a verification signal to its station.",
				"category": "lore",
			})
	if GameState.has_final_key_fragment(machine_index):
		interact_label.text = "%s — %s is already empty. Only the cold metal remains." % [station_label, station_domain]
		interact_label.visible = true
		return
	var fragments: int = GameState.collect_final_key_fragment(machine_index)
	interact_label.text = "A relay clicks inside the wall. %s (%s) is active and releases its Final Room Key seal." % [station_label, station_domain]
	interact_label.visible = true

	if fragments >= 3:
		if NoteHud != null:
			NoteHud.add_clue("ashford_seal_stations", {
				"title": "Three Ashford Seal Stations",
				"content": "The three hall stations each held one Final Room Key seal. They are now empty, but the key is still incomplete. Matter, Life and Energy have been verified. Mrs. Lin's route points to the Service Corridor maintenance panel for the fourth Access / Route seal.",
				"category": "investigation",
			})


func _collect_corridor_fragment(index: int) -> void:
	var flag_id: String = "corridor_fragment_%d" % index
	if GameState.has_story_flag(flag_id):
		return
	GameState.set_story_flag(flag_id)
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Torn Note")
	message_panel.visible = true
	var fragment_texts: Array[String] = [
		"He is in the corridor. The footsteps stopped — he is listening.\n\n"
			+ "The service route is still open behind the east wall.",
		"The route is right. It leads out near the Final Room door.\n\n"
			+ "He is carrying something from the archive.",
		"If I do not make it out of here... the last answer is in my notebook.\n"
			+ "The final page.\n\n"
			+ "The route continues east. I was right about the maintenance access. I wish I had been wrong.",
	]
	set_dialogue_text(
		"Torn Note",
		"Fragment %d/%d:\n\n%s" % [index, CORRIDOR_FRAGMENT_POSITIONS.size(), fragment_texts[index - 1]]
	)
	var collected: int = 0
	for i: int in range(1, CORRIDOR_FRAGMENT_POSITIONS.size() + 1):
		if GameState.has_story_flag("corridor_fragment_%d" % i):
			collected += 1
	if collected >= CORRIDOR_FRAGMENT_POSITIONS.size():
		set_dialogue_text(
			"Torn Note",
			"The three fragments fit together:\n\n"
				+ "\"He uses the service corridor behind the west wall. "
				+ "The route ends at the Final Room door.\"\n\n"
				+ "The last page adds: the Final Room Key was split into "
				+ "three pieces and hidden inside the machines scattered across the hall."
		)
		if NoteHud != null:
			NoteHud.add_clue("corridor_fragments", {
				"title": "Corridor Fragments",
				"content": "Mrs. Lin's torn pages: someone uses the service corridor "
					+ "behind the east wall, and the route ends at the Final Room door. "
					+ "The complete Final Room Key is split into four seals: three in the hall stations and one behind the Service Corridor maintenance panel.",
				"category": "investigation",
			})
	show_continue_button("Close", close_message_panel)


func show_not_developed_prompt(room_name: String) -> void:
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Castle")
	message_panel.visible = true
	set_dialogue_text(
		"Castle",
		room_name
		+ "\n\nThis room is not developed yet."
	)
	show_continue_button("Close", close_message_panel)


func show_clue_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "This red liquid looks like blood at first glance, but a good detective never relies on color alone.\n\nWhat do you think caused the red color?")

	add_dialogue_button("I think I know.", show_red_stain_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_red_stain_without_reward)


func show_red_stain_question():
	clear_buttons()

	set_dialogue_text(
		"Mrs. Lin",
		"Question:\nWhat most likely caused the red color?\n\nUse what you observed. A good detective does not rely on color alone."
	)

	add_answer_button("A. Real blood exposed to oxygen", false)
	add_answer_button("B. Indicator solution reacting with a basic cleaner", true)
	add_answer_button("C. Rust dissolved in water", false)
	add_answer_button("D. Red paint from the wall", false)


func add_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)

	if is_correct:
		button.pressed.connect(on_red_stain_correct)
	else:
		button.pressed.connect(on_red_stain_wrong)

	button_box.add_child(button)


func on_red_stain_correct():
	award_reputation(10)

	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Correct.\n\nExcellent reasoning. The red color is likely caused by an indicator reacting with a basic cleaning substance. This means the stain may have been staged, not left by the victim.\n\nEvidence added: Fake Red Stain")

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func on_red_stain_wrong():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Not quite.\n\nThe important clue is not just the color. If an indicator solution mixes with a basic cleaner, it can turn red or pink. This stain may be fake.\n\nEvidence added: Fake Red Stain")

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_red_stain_without_reward():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "That's okay. A good detective knows when to ask for help.\n\nThe red color may come from an indicator solution reacting with a basic cleaner. So this does not prove it is blood. Someone may have staged the crime scene.\n\nEvidence added: Fake Red Stain")

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_red_stain_evidence() -> void:
	GameState.add_evidence(
		"fake_red_stain"
	)

	evidence_items = GameState.evidence_items
	evidence_collected = true

	if clue_node != null:
		clue_node.color = Color(
			0.35,
			0.02,
			0.04,
			0.7
		)

	update_evidence_board_text()
	update_objective_text()


func close_message_panel():
	message_panel.visible = false
	clear_buttons()

	if interact_label != null:
		interact_label.visible = false

	end_dialogue_pause()


func clear_buttons():
	for child in button_box.get_children():
		child.queue_free()

	if dialogue_continue_button != null:
		dialogue_continue_button.visible = false

	reset_dialogue_scrolls()


func add_dialogue_button(text: String, callback: Callable):
	# 分段显示中：选项按钮暂存，最后一段才真正加入。
	if _segment_index < _dialogue_segments.size() - 1:
		_pending_dialogue_buttons.append({"text": text, "callback": callback})
		return
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(330, 34)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	button_box.add_child(button)
func start_dialogue_pause():
	dialogue_active = true
	current_interaction = ""

	if interact_label != null:
		interact_label.visible = false

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)


func end_dialogue_pause():
	dialogue_active = false

	if game_over:
		return

	player.set_physics_process(true)

	if enemy != null:
		enemy.set_physics_process(
			enemy_chase_started
		)

func create_evidence_board_ui():
	evidence_panel = Panel.new()
	evidence_panel.position = Vector2(230, 90)
	evidence_panel.size = Vector2(570, 560)
	evidence_panel.visible = false
	ui_layer.add_child(evidence_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 24)
	margin.size = Vector2(522, 512)
	evidence_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	evidence_title_label = Label.new()
	evidence_title_label.text = "Evidence Board"
	evidence_title_label.add_theme_font_size_override("font_size", 32)
	layout.add_child(evidence_title_label)

	# Evidence list view
	evidence_list_scroll = ScrollContainer.new()
	evidence_list_scroll.custom_minimum_size = Vector2(500, 380)
	evidence_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(evidence_list_scroll)

	evidence_list_box = VBoxContainer.new()
	evidence_list_box.add_theme_constant_override("separation", 10)
	evidence_list_scroll.add_child(evidence_list_box)

	# Evidence detail view
	evidence_detail_scroll = ScrollContainer.new()
	evidence_detail_scroll.custom_minimum_size = Vector2(500, 380)
	evidence_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	evidence_detail_scroll.visible = false
	layout.add_child(evidence_detail_scroll)

	evidence_detail_label = Label.new()
	evidence_detail_label.text = ""
	evidence_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_detail_label.custom_minimum_size = Vector2(480, 700)
	evidence_detail_label.add_theme_font_size_override("font_size", 21)
	evidence_detail_scroll.add_child(evidence_detail_label)

	evidence_back_button = Button.new()
	evidence_back_button.text = "Back to Evidence List"
	evidence_back_button.custom_minimum_size = Vector2(500, 42)
	evidence_back_button.visible = false
	evidence_back_button.pressed.connect(show_evidence_list)
	layout.add_child(evidence_back_button)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(500, 44)
	close_button.pressed.connect(close_evidence_board)
	layout.add_child(close_button)


func toggle_evidence_board():
	if message_panel.visible:
		return

	if evidence_board_open:
		close_evidence_board()
	else:
		open_evidence_board()


func open_evidence_board():
	evidence_board_open = true
	show_evidence_list()
	evidence_panel.visible = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)


func close_evidence_board():
	evidence_board_open = false
	evidence_panel.visible = false

	if not game_over and not dialogue_active:
		player.set_physics_process(true)

		if enemy != null:
			enemy.set_physics_process(true)


func update_evidence_board_text():
	if evidence_list_box == null:
		return

	for child in evidence_list_box.get_children():
		child.queue_free()

	if evidence_items.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No evidence collected yet.\n\nExplore the castle and investigate suspicious clues."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.custom_minimum_size = Vector2(480, 120)
		evidence_list_box.add_child(empty_label)
		return

	for evidence_id in evidence_items:
		var button = Button.new()
		button.text = get_evidence_title(evidence_id)
		button.custom_minimum_size = Vector2(480, 52)
		button.pressed.connect(func(): show_evidence_detail(evidence_id))
		evidence_list_box.add_child(button)
func create_butler_npc():
	butler_position = BUTLER_POSITION

	butler_node = AnimatedNpc.new()
	butler_node.name = "ButlerNPC"
	butler_node.position = butler_position
	butler_node.configure(
		"Butler",
		"res://assets/characters/animated_pixel_v3/butler_walk.png",
		0.20,
		Vector2(14.0, 0.0),
		11.0,
		&"down"
	)
	butler_node.z_index = 6

	add_child(butler_node)
	add_world_label(butler_node, "Butler", Vector2(-24, -74))
func show_butler_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Butler")
	message_panel.visible = true

	if evidence_items.has("fake_red_stain"):
		set_dialogue_text("Butler", "I already told you, I only cleaned the hallway. That red stain has nothing to do with me.\n\nMrs. Lin:\nInteresting. The stain may involve a basic cleaning substance. Someone with access to cleaning supplies could explain part of this clue.")
	else:
		set_dialogue_text("Butler", "I was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms.\n\nMrs. Lin:\nThat explains why many paths require scientific reasoning. We should collect physical evidence before making any accusation.")

	show_continue_button("Continue", close_message_panel)
func create_pollen_clue():
	pollen_position = POLLEN_POSITION

	pollen_node = ColorRect.new()
	pollen_node.name = "PollenClue"
	pollen_node.color = Color(0.95, 0.78, 0.12, 1.0)
	pollen_node.size = Vector2(22, 22)
	pollen_node.position = pollen_position - pollen_node.size / 2
	pollen_node.z_index = 5

	add_child(pollen_node)
	add_world_label(pollen_node, "Pollen", Vector2(-16, -24))
func create_gardener_npc():
	gardener_position = GARDENER_POSITION

	gardener_node = AnimatedNpc.new()
	gardener_node.name = "GardenerNPC"
	gardener_node.position = gardener_position
	gardener_node.configure(
		"Gardener",
		"res://assets/characters/animated_pixel_v3/gardener_walk.png",
		0.20,
		Vector2(14.0, 0.0),
		11.0,
		&"left"
	)
	gardener_node.z_index = 6

	add_child(gardener_node)
	add_world_label(gardener_node, "Gardener", Vector2(-30, -74))
func show_pollen_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "There is yellow pollen on the door handle. That may not look important, but pollen can connect a person to a specific place.\n\nWhat do you think this clue tells us?")

	add_dialogue_button("I think I know.", show_pollen_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_pollen_without_reward)


func show_pollen_question():
	clear_buttons()

	set_dialogue_text(
		"Mrs. Lin",
		"Question:\nWhat is the best scientific use of this pollen evidence?\n\nThink about how small traces can connect a suspect to a specific place."
	)


func add_pollen_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)
	if is_correct:
		button.pressed.connect(on_pollen_correct)
	else:
		button.pressed.connect(on_pollen_wrong)

	button_box.add_child(button)


func on_pollen_correct():
	award_reputation(10)

	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Correct.\n\nGood reasoning. Pollen grains can help identify where someone has been, especially if the pollen matches a plant from a specific room such as the greenhouse.\n\nEvidence added: Greenhouse Pollen")

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func on_pollen_wrong():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Not quite.\n\nPollen can act like biological trace evidence. If it matches a plant from the greenhouse, it may show that someone recently came from there.\n\nEvidence added: Greenhouse Pollen")

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_pollen_without_reward():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "That's okay. Pollen is useful because different plants can produce different pollen patterns. If we match this pollen to the greenhouse, it can connect a suspect to that location.\n\nEvidence added: Greenhouse Pollen")

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_pollen_evidence() -> void:
	GameState.add_evidence(
		"greenhouse_pollen"
	)

	evidence_items = GameState.evidence_items
	pollen_collected = true

	if pollen_node != null:
		pollen_node.color = Color(
			0.45,
			0.35,
			0.05,
			0.7
		)

	update_evidence_board_text()
	update_objective_text()
func show_gardener_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Gardener")
	message_panel.visible = true

	if evidence_items.has("greenhouse_pollen"):
		set_dialogue_text("Gardener", "Pollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything.\n\nMrs. Lin:\nHe is right that pollen alone is not proof. But if it appears on a locked door handle, it may show that someone from the greenhouse touched it recently.")
	else:
		set_dialogue_text("Gardener", "I was working near the greenhouse earlier. I did not enter the locked rooms.\n\nWe should look for biological trace evidence before deciding whether that is true.")

	show_continue_button("Continue", close_message_panel)
func create_circuit_clue():
	circuit_position = CIRCUIT_CLUE_POSITION

	circuit_node = ColorRect.new()
	circuit_node.name = "CircuitClue"
	circuit_node.color = Color(0.15, 0.65, 0.95, 1.0)
	circuit_node.size = Vector2(26, 20)
	circuit_node.position = circuit_position - circuit_node.size / 2
	circuit_node.z_index = 5

	add_child(circuit_node)
	add_world_label(circuit_node, "circuit", Vector2(-36, -24))


func create_mechanic_npc():
	mechanic_position = MECHANIC_POSITION

	mechanic_node = AnimatedNpc.new()
	mechanic_node.name = "MechanicNPC"
	mechanic_node.position = mechanic_position
	mechanic_node.configure(
		"Mechanic",
		"res://assets/characters/animated_pixel_v3/mechanic_walk.png",
		0.20,
		Vector2(14.0, 0.0),
		11.0,
		&"right"
	)
	mechanic_node.z_index = 6

	add_child(mechanic_node)
	add_world_label(mechanic_node, "Mechanic", Vector2(-30, -74))
func show_circuit_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "The wall panel has burn marks, and the lights went out right before the chase began.\n\nThis may not be an accident. What do you think caused the blackout?")

	add_dialogue_button("I think I know.", show_circuit_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_circuit_without_reward)


func show_circuit_question():
	clear_buttons()

	set_dialogue_text(
		"Mrs. Lin",
		"Question:\nWhat is the best explanation for the burned circuit panel?\n\nUse the burn marks and blackout as evidence."
	)


func add_circuit_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)

	if is_correct:
		button.pressed.connect(on_circuit_correct)
	else:
		button.pressed.connect(on_circuit_wrong)

	button_box.add_child(button)


func on_circuit_correct():
	award_reputation(10)

	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Correct.\n\nExactly. A short circuit can allow too much current to flow, producing heat and burn marks. This suggests the blackout may have been caused deliberately.\n\nEvidence added: Deliberate Short Circuit")

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func on_circuit_wrong():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "Not quite.\n\nThe burn marks suggest excess current and heat. A short circuit could explain the sudden blackout, which means someone may have caused it on purpose.\n\nEvidence added: Deliberate Short Circuit")

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_circuit_without_reward():
	clear_buttons()
	set_dialogue_text("Mrs. Lin", "A short circuit creates a path with very low resistance. That can cause a large current, heat, and burn marks.\n\nSo the blackout may not be accidental. Someone may have used the circuit panel to create confusion.\n\nEvidence added: Deliberate Short Circuit")

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_circuit_evidence() -> void:
	GameState.add_evidence(
		"deliberate_short_circuit"
	)

	evidence_items = GameState.evidence_items
	circuit_collected = true

	if circuit_node != null:
		circuit_node.color = Color(
			0.05,
			0.25,
			0.35,
			0.7
		)

	update_evidence_board_text()
	update_objective_text()
func show_mechanic_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mechanic")
	message_panel.visible = true

	if evidence_items.has("deliberate_short_circuit"):
		set_dialogue_text("Mechanic", "A short circuit? I maintain the castle wiring, but anyone could have damaged that panel.\n\nMrs. Lin:\nMaybe. But the burn pattern suggests the blackout was triggered intentionally. Someone who understands circuits would know exactly where to interfere.")
	else:
		set_dialogue_text("Mechanic", "The lights in this castle fail all the time. Old wiring, old walls, old problems.\n\nMrs. Lin:\nMaybe, but we should inspect the circuit panel before accepting that explanation.")

	show_continue_button("Continue", close_message_panel)
func get_evidence_title(evidence_id: String) -> String:
	if evidence_id == "fake_red_stain":
		return "Evidence 1: Fake Red Stain"

	if evidence_id == "greenhouse_pollen":
		return "Evidence 2: Greenhouse Pollen"

	if evidence_id == "deliberate_short_circuit":
		return "Evidence 3: Deliberate Short Circuit"

	return "Unknown Evidence"
func get_evidence_detail(evidence_id: String) -> String:
	if evidence_id == "fake_red_stain":
		return "Evidence 1: Fake Red Stain\n\n" + \
		"Observation:\nA red liquid was found near white powder and a broken bottle.\n\n" + \
		"Science:\nThe red color may come from an indicator solution reacting with a basic cleaner. Some indicators change color depending on whether the environment is acidic or basic.\n\n" + \
		"Reasoning:\nThis does not prove it is blood. Someone may have staged the crime scene using a chemical reaction.\n\n" + \
		"Suspect Link:\nThis could connect to someone with access to cleaning supplies or chemical materials, such as the Butler or someone familiar with basic substances."

	if evidence_id == "greenhouse_pollen":
		return "Evidence 2: Greenhouse Pollen\n\n" + \
		"Observation:\nYellow pollen was found on a locked door handle.\n\n" + \
		"Science:\nPollen grains can act as biological trace evidence. Different plants can produce different pollen patterns, which may connect a person to a specific location.\n\n" + \
		"Reasoning:\nIf this pollen matches plants from the greenhouse, someone who recently visited that area may have touched the locked door.\n\n" + \
		"Suspect Link:\nThis could connect to the Gardener or anyone who entered the greenhouse before the crime."

	if evidence_id == "deliberate_short_circuit":
		return "Evidence 3: Deliberate Short Circuit\n\n" + \
		"Observation:\nBurn marks were found on a wall circuit panel near the blackout area.\n\n" + \
		"Science:\nA short circuit can create a path with very low resistance. This can allow excess current to flow, producing heat and electrical damage.\n\n" + \
		"Reasoning:\nThe blackout may not have been accidental. Someone may have triggered it to create confusion or cover movement through the castle.\n\n" + \
		"Suspect Link:\nThis could connect to the Mechanic or anyone with electrical knowledge."

	return "No detail available."
func show_evidence_list():
	evidence_title_label.text = "Evidence Board"

	evidence_list_scroll.visible = true
	evidence_detail_scroll.visible = false
	evidence_back_button.visible = false

	update_evidence_board_text()


func show_evidence_detail(evidence_id: String):
	evidence_title_label.text = get_evidence_title(evidence_id)

	evidence_detail_label.text = get_evidence_detail(evidence_id)

	evidence_list_scroll.visible = false
	evidence_detail_scroll.visible = true
	evidence_back_button.visible = true
func create_final_room():
	final_room_position = FINAL_ROOM_POSITION

	final_room_node = ColorRect.new()
	final_room_node.name = "FinalDeductionRoom"
	final_room_node.color = Color(0.65, 0.45, 0.95, 1.0)
	final_room_node.size = Vector2(30, 30)
	final_room_node.position = final_room_position - final_room_node.size / 2
	final_room_node.z_index = 5

	add_child(final_room_node)
	add_world_label(final_room_node, "Final Deduction", Vector2(-48, -24))
func has_all_evidence() -> bool:
	return evidence_items.has("fake_red_stain") \
		and evidence_items.has("greenhouse_pollen") \
		and evidence_items.has("deliberate_short_circuit")
func show_final_deduction():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true

	if not has_all_evidence():
		set_dialogue_text("Mrs. Lin", "Not yet. We still need enough evidence before making a final accusation.\n\n" + get_evidence_progress_text())
		add_dialogue_button("Continue", close_message_panel)
		return

	set_dialogue_text("Mrs. Lin", "We have three major pieces of evidence now:\n\n1. The red stain may have been staged.\n2. The pollen links someone to the greenhouse area.\n3. The blackout was likely caused by a deliberate short circuit.\n\nWho do you accuse?")

	add_final_suspect_button("Butler", "butler")
	add_final_suspect_button("Gardener", "gardener")
	add_final_suspect_button("Mechanic", "mechanic")
	add_dialogue_button("I need to review evidence first.", close_message_panel)


func get_evidence_progress_text() -> String:
	var text = ""

	if evidence_items.has("fake_red_stain"):
		text += "- Fake Red Stain collected\n"
	else:
		text += "- Fake Red Stain missing\n"

	if evidence_items.has("greenhouse_pollen"):
		text += "- Greenhouse Pollen collected\n"
	else:
		text += "- Greenhouse Pollen missing\n"

	if evidence_items.has("deliberate_short_circuit"):
		text += "- Deliberate Short Circuit collected\n"
	else:
		text += "- Deliberate Short Circuit missing\n"

	return text


func add_final_suspect_button(display_name: String, suspect_id: String):
	var button = Button.new()
	button.text = display_name
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func(): resolve_final_accusation(suspect_id))
	button_box.add_child(button)


func resolve_final_accusation(suspect_id: String):
	clear_buttons()

	if suspect_id == culprit_id:
		show_victory_ending()
	else:
		show_wrong_accusation_ending(suspect_id)
func show_victory_ending():
	game_over = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	message_panel.visible = true
	message_label.text = "CASE SOLVED\n\nYou accused the Mechanic.\n\nMrs. Lin:\nCorrect. The strongest clue is the deliberate short circuit. The blackout gave the murderer time to move through the castle while everyone else was confused.\n\nThe staged red stain and greenhouse trace evidence were distractions, but together they helped reveal how the crime scene was manipulated.\n\nFinal Reputation: " + str(reputation) + "\n\nPress R to restart.\nPress M for main menu."


func show_wrong_accusation_ending(suspect_id: String):
	game_over = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	var suspect_name = suspect_id.capitalize()

	message_panel.visible = true
	message_label.text = "WRONG ACCUSATION\n\nYou accused the " + suspect_name + ".\n\nMrs. Lin:\nThat does not fully explain the deliberate blackout. The evidence suggests someone with electrical knowledge used the circuit panel to create confusion.\n\nThe real culprit escaped in the darkness.\n\nFinal Reputation: " + str(reputation) + "\n\nPress R to restart.\nPress M for main menu."
func restart_current_game():
	# Retry 只重载当前场景；玩家保留实时调查进度。
	GameState.player_health = 3
	GameState.end_chase_mode()
	GameState.enemy_chase_active = false
	var current_path: String = "res://scenes/game_world.tscn"
	if get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
		current_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_path)


func restart_from_checkpoint() -> void:
	# Load Checkpoint 回到最近一次进入房间时记录的场景。
	var checkpoint_path: String = "res://scenes/game_world.tscn"
	if GameState.load_room_checkpoint():
		checkpoint_path = GameState.checkpoint_scene_path
	get_tree().change_scene_to_file(checkpoint_path)


func return_to_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
func update_objective_text():
	if objective_summary_label == null:
		return

	var red_done = evidence_items.has("fake_red_stain")
	var pollen_done = evidence_items.has("greenhouse_pollen")
	var circuit_done = evidence_items.has("deliberate_short_circuit")

	var collected_count = 0
	if red_done:
		collected_count += 1
	if pollen_done:
		collected_count += 1
	if circuit_done:
		collected_count += 1

	if not hall_arrival_finished:
		objective_summary_label.text = (
			"Objective: Enter the First-Floor Castle Hall"
		)

	elif evidence_items.is_empty():
		objective_summary_label.text = (
			"Objective: Investigate the Castle Hall   [O: Details]"
		)

	elif has_all_evidence():
		objective_summary_label.text = (
			"Objective: Go to Final Deduction Room   [O: Details]"
		)

	else:
		objective_summary_label.text = (
			"Objective: Evidence "
			+ str(collected_count)
			+ "/3   [O: Details]"
		)

	if objective_detail_label == null:
		return

	var red_status = "✓" if red_done else "✗"
	var pollen_status = "✓" if pollen_done else "✗"
	var circuit_status = "✓" if circuit_done else "✗"

	var detail = "Current Mission:\n\n"
	# 线路房知识锁：按真实的「钥匙 / 知识 / 已解锁」状态播报。
	# 旧文案读的是原型标记 circuit_door_open / learned_circuit_rule，
	# 两个分支的内容还写反了（没学会规则时反而说“门已打开”）。
	if not GameState.has_story_flag("door_circuit_unlocked"):
		detail += "Circuit Room Door:\n"
		if not GameState.has_key("circuit_room_key"):
			detail += (
				"✗ The Circuit Room door is locked. "
				+ "Search the rooms you can already reach for its key.\n\n"
			)
		elif not GameState.has_story_flag(
			"hall_knowledge_circuit_room_collected"
		):
			detail += (
				"✗ The key fits, but the knowledge lock is still sealed. "
				+ "Study the Circuit Room Knowledge exhibit in Castle Hall "
				+ "and save it to NoteHub.\n\n"
			)
		else:
			detail += (
				"✓ Key and knowledge ready. "
				+ "Answer the knowledge lock at the Circuit Room door.\n\n"
			)
	elif not circuit_done:
		detail += "Circuit Room Door:\n"
		detail += (
			"✓ Circuit Room unlocked. "
			+ "Search inside for the workshop clues and circuit evidence.\n\n"
		)
	if has_all_evidence():
		detail += "You have collected all major STEM evidence.\n\n"
		detail += "Next Step:\nGo to the purple Final Deduction Room and accuse the culprit.\n\n"
	else:
		detail += "Collect three STEM evidence items before making a final accusation.\n\n"

	detail += red_status + " Fake Red Stain\n"
	detail += "Chemistry clue: Determine whether the red liquid is real blood or a staged chemical reaction.\n\n"

	detail += pollen_status + " Greenhouse Pollen\n"
	detail += "Biology clue: Use pollen as trace evidence to connect a suspect to a location.\n\n"

	detail += circuit_status + " Deliberate Short Circuit\n"
	detail += "Physics clue: Investigate whether the blackout was caused intentionally.\n\n"

	detail += "Controls:\n"
	detail += "WASD - Move\n"
	detail += "E - Interact\n"
	detail += "B - Evidence Board\n"
	detail += "K - Knowledge Journal\n"
	detail += "O - Mission Objectives\n"
	detail += "R - Restart\n"
	detail += "M - Main Menu\n"

	objective_detail_label.text = detail
func create_objective_panel_ui():
	objective_panel = Panel.new()
	objective_panel.position = Vector2(260, 120)
	objective_panel.size = Vector2(520, 480)
	objective_panel.visible = false
	ui_layer.add_child(objective_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 24)
	margin.size = Vector2(472, 432)
	objective_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Mission Objectives"
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 310)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	objective_detail_label = Label.new()
	objective_detail_label.text = ""
	objective_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_detail_label.custom_minimum_size = Vector2(440, 520)
	objective_detail_label.add_theme_font_size_override("font_size", 21)
	scroll.add_child(objective_detail_label)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(460, 44)
	close_button.pressed.connect(close_objective_panel)
	layout.add_child(close_button)
func toggle_objective_panel():
	if message_panel.visible:
		return

	if evidence_board_open:
		return

	if objective_panel_open:
		close_objective_panel()
	else:
		open_objective_panel()


func open_objective_panel():
	objective_panel_open = true
	update_objective_text()
	objective_panel.visible = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)


func close_objective_panel():
	objective_panel_open = false
	objective_panel.visible = false

	if intro_reviewing_objectives:
		intro_reviewing_objectives = false
		message_panel.visible = true
		show_intro_dialogue_page_two()
		return

	if not game_over and not dialogue_active and not evidence_board_open:
		player.set_physics_process(true)

		if enemy != null:
			enemy.set_physics_process(true)
func add_world_label(parent_node: Node, text: String, offset: Vector2):
	var label = Label.new()
	label.text = text
	label.position = offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(label)
	return label
func create_follow_camera() -> void:
	follow_camera = Camera2D.new()
	follow_camera.name = "FollowCamera"
	follow_camera.position = Vector2.ZERO

	camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)

	follow_camera.zoom = camera_target_zoom
	follow_camera.enabled = true

	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0

	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = MAP_PIXEL_WIDTH
	follow_camera.limit_bottom = MAP_PIXEL_HEIGHT

	# 防止镜头到达地图边缘时显示地图外区域。
	follow_camera.limit_smoothed = true
	follow_camera.position_smoothing_enabled = true

	player.add_child(follow_camera)
	follow_camera.make_current()


# ============================================================
# Knowledge-lock doors (key + question) — every room door.
# ============================================================

var _door_question_target: String = ""
var _final_synthesis_active: bool = false
var _final_synthesis_index: int = 0

## 统一双锁入口：无钥匙提示找钥匙；有钥匙未解锁弹出知识题；已解锁直接进入。
func _try_enter_locked_room(door_id: String, key_id: String, on_enter: Callable) -> void:
	var unlocked_flag: String = "door_%s_unlocked" % door_id
	if GameState.has_story_flag(unlocked_flag):
		on_enter.call()
		return
	if not GameState.has_key(key_id):
		start_dialogue_pause()
		clear_buttons()
		set_dialogue_speaker("Mrs. Lin")
		message_panel.visible = true
		set_dialogue_text(
			"Mrs. Lin",
			"The lock is dormant — a physical key is required before the question will appear.\n\nSearch the rooms you have already explored."
		)
		show_continue_button("Continue", close_message_panel)
		return
	if door_id == "final":
		_final_synthesis_active = true
		_final_synthesis_index = 0
		_show_final_synthesis_question()
		return
	var data: Dictionary = DOOR_QUESTIONS[door_id]
	var required_knowledge_flag: String = str(data.get("knowledge_flag", ""))
	if (
		not required_knowledge_flag.is_empty()
		and not GameState.has_story_flag(required_knowledge_flag)
	):
		var room_label: String = door_id.capitalize()
		if door_id == "final":
			room_label = "Final Room"
		elif door_id == "greenhouse":
			room_label = "Greenhouse Room"
		elif door_id == "circuit":
			room_label = "Circuit Room"
		elif door_id == "chemistry":
			room_label = "Chemistry Room"
		elif door_id == "dining":
			room_label = "Dining Hall"
		elif door_id == "library":
			room_label = "Library"
		start_dialogue_pause()
		clear_buttons()
		set_dialogue_speaker("Mrs. Lin")
		message_panel.visible = true
		set_dialogue_text(
			"Mrs. Lin",
			"The key fits, but the knowledge lock is still sealed.\n\n"
			+ "Study the " + room_label + " Knowledge exhibit in Castle Hall and save it to NoteHub before answering this question."
		)
		show_continue_button("Continue", close_message_panel)
		return
	_show_door_question(
		door_id,
		str(data["question"]),
		data["options"] as Array,
		int(data["correct"])
	)


func _show_final_synthesis_question() -> void:
	var step: Dictionary = FINAL_SYNTHESIS_QUESTIONS[_final_synthesis_index]
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text(
		"Mrs. Lin",
		"Final Synthesis Lock — Question %d/%d:\n\n%s" % [
			_final_synthesis_index + 1,
			FINAL_SYNTHESIS_QUESTIONS.size(),
			str(step["question"]),
		]
	)
	var options: Array = step["options"]
	var correct_index: int = int(step["correct"])
	var option_order: Array[int] = []
	for option_index: int in range(options.size()):
		option_order.append(option_index)
	option_order.shuffle()
	for option_index: int in option_order:
		add_door_answer_button(
			str(options[option_index]),
			option_index == correct_index
		)


func _on_final_synthesis_correct() -> void:
	_final_synthesis_index += 1
	if _final_synthesis_index < FINAL_SYNTHESIS_QUESTIONS.size():
		_show_final_synthesis_question()
		return
	_final_synthesis_active = false
	GameState.set_story_flag("final_synthesis_unlocked")
	GameState.set_story_flag("door_final_unlocked")
	award_reputation(5)
	clear_buttons()
	set_dialogue_text(
		"Mrs. Lin",
		"The final lock accepts the chain of knowledge.\n\n"
		+ "Matter, life, energy, and the passage of time all point to one connected investigation.\n\n"
		+ "The Final Room door is open."
	)
	show_continue_button("Continue", close_message_panel)


func _show_final_synthesis_wrong() -> void:
	clear_buttons()
	set_dialogue_text(
		"Mrs. Lin",
		"That answer does not fit the evidence you have learned.\n\n"
		+ "Review the corresponding room Knowledge note and try again."
	)
	var retry_button: Button = Button.new()
	retry_button.text = "Try Again"
	retry_button.custom_minimum_size = Vector2(780, 28)
	retry_button.add_theme_font_size_override("font_size", 15)
	retry_button.pressed.connect(_show_final_synthesis_question)
	button_box.add_child(retry_button)
	show_continue_button("Leave the lock", close_message_panel)


func _show_door_question(door_id: String, question: String, options: Array, correct_index: int) -> void:
	_door_question_target = door_id
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	var question_text: String = "Knowledge Lock:\n\n" + question + "\n"
	for i: int in range(options.size()):
		question_text += "\n" + str(i + 1) + ". " + str(options[i])
	set_dialogue_text("Mrs. Lin", question_text)
	var option_order: Array[int] = [0, 1, 2, 3]
	option_order.shuffle()
	for option_index: int in option_order:
		add_door_answer_button(
			str(options[option_index]),
			option_index == correct_index
		)


func add_door_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)

	if is_correct:
		button.pressed.connect(_on_door_question_correct)
	else:
		button.pressed.connect(_on_door_question_wrong)

	button_box.add_child(button)


func _on_door_question_correct() -> void:
	if _final_synthesis_active:
		_on_final_synthesis_correct()
		return
	var door_id: String = _door_question_target
	award_reputation(5)
	clear_buttons()
	match door_id:
		"circuit":
			GameState.set_story_flag("door_circuit_unlocked")
		"chemistry":
			GameState.set_story_flag("door_chemistry_unlocked")
		"greenhouse":
			GameState.set_story_flag("door_greenhouse_unlocked")
		"dining":
			GameState.set_story_flag("door_dining_unlocked")
		"library":
			GameState.set_story_flag("door_library_unlocked")
		"final":
			GameState.set_story_flag("door_final_unlocked")
	# 六扇门共用同一条解锁后刷新路径，目标面板才会立刻反映新状态。
	update_objective_text()
	set_dialogue_text(
		"Mrs. Lin",
		"Correct.\n\nThe knowledge lock accepts your answer.\n\nDoor opened."
	)
	show_continue_button("Continue", close_message_panel)


func _on_door_question_wrong() -> void:
	if _final_synthesis_active:
		_show_final_synthesis_wrong()
		return
	clear_buttons()
	set_dialogue_text(
		"Mrs. Lin",
		"Not quite.\n\nThe lock remains sealed. Think about the science behind the question and try again."
	)
	var retry_button := Button.new()
	retry_button.text = "Try Again"
	retry_button.custom_minimum_size = Vector2(780, 28)
	retry_button.add_theme_font_size_override("font_size", 15)
	retry_button.pressed.connect(_retry_door_question)
	button_box.add_child(retry_button)
	show_continue_button("Leave the lock", close_message_panel)


func _retry_door_question() -> void:
	if _final_synthesis_active:
		_show_final_synthesis_question()
		return
	var door_id: String = _door_question_target
	if door_id.is_empty() or not DOOR_QUESTIONS.has(door_id):
		return
	var data: Dictionary = DOOR_QUESTIONS[door_id]
	_show_door_question(
		door_id,
		str(data["question"]),
		data["options"] as Array,
		int(data["correct"])
	)


func create_circuit_learning_note():
	circuit_note_position = CIRCUIT_NOTE_POSITION

	circuit_note_node = ColorRect.new()
	circuit_note_node.name = "CircuitLearningNote"
	circuit_note_node.color = Color(0.95, 0.92, 0.55, 1.0)
	circuit_note_node.size = Vector2(24, 18)
	circuit_note_node.position = circuit_note_position - circuit_note_node.size / 2
	circuit_note_node.z_index = 5

	add_child(circuit_note_node)
	add_world_label(circuit_note_node, "Note", Vector2(-10, -24))
func show_circuit_learning_note():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	GameState.set_learned_circuit_rule(true)
	learned_circuit_rule = true

	add_knowledge_item("current_resistance")
	if circuit_note_node != null:
		circuit_note_node.color = Color(0.55, 0.52, 0.25, 0.75)

	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "\"The circuit lock overheats when current becomes too high. Increase resistance to reduce current flow. Never bypass the resistor.\"\n\nMrs. Lin:\nThis note gives us the rule we need. If current is too high, increasing resistance can reduce it.\n\nConcept learned: Current decreases when resistance increases.")

	update_objective_text()
	show_continue_button("Continue", close_message_panel)
func show_circuit_door_hint():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "This lock uses an electrical rule, but we have not confirmed the rule yet.\n\nLook nearby for a maintenance note or circuit clue before forcing an answer.")

	show_continue_button("Continue", close_message_panel)
func show_intro_dialogue():
	if intro_seen:
		return

	intro_seen = true
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true
	set_dialogue_text("Mrs. Lin", "Detective, you are inside Shadow Castle.\n\nThis castle once belonged to Lord Ashford, a scholar who believed knowledge was the only true key.\n\nHe designed many doors as knowledge locks. They do not open with ordinary keys. They open when someone understands the question written on them.")

	show_continue_button("Continue", show_intro_dialogue_page_two)
func open_objectives_from_intro():
	intro_reviewing_objectives = true
	message_panel.visible = false
	clear_buttons()

	open_objective_panel()
func show_intro_dialogue_page_two():
	clear_buttons()

	set_dialogue_text(
		"Mrs. Lin",
		"Tonight, a crime scene has been staged inside Shadow Castle, and the murderer is still moving through the halls.\n\n" +
		"This castle is not a normal building. Lord Ashford, the former owner, believed that knowledge was the only true key. He designed many doors as knowledge locks. They do not open with ordinary keys. They open only when someone understands the question written on them.\n\n" +
		"That means you should not guess randomly. Look around first. Read notes, inspect strange objects, talk to suspects, and pay attention to scientific clues. The answer to a locked door is usually hidden somewhere nearby.\n\n" +
		"Your investigation has three goals:\n\n" +
		"1. Explore the castle safely.\n" +
		"2. Learn from clues and use STEM knowledge to open locked paths.\n" +
		"3. Collect evidence, question suspects, and identify the real culprit.\n\n" +
		"Use the Evidence Board to review evidence. Use the Knowledge Journal to review concepts you have learned. Use Mission Objectives when you are unsure what to do next.\n\n" +
		"Controls:\n" +
		"WASD - Move\n" +
		"E - Interact\n" +
		"B - Evidence Board\n" +
		"K - Knowledge Journal\n" +
		"O - Mission Objectives\n" +
		"R - Restart\n" +
		"M - Main Menu"
	)

	add_dialogue_button("Review Mission Objectives", open_objectives_from_intro)
	show_continue_button("Start Investigation", start_investigation_from_intro)
func create_knowledge_journal_ui():
	knowledge_panel = Panel.new()
	knowledge_panel.position = Vector2(250, 100)
	knowledge_panel.size = Vector2(560, 540)
	knowledge_panel.visible = false
	ui_layer.add_child(knowledge_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 24)
	margin.size = Vector2(512, 492)
	knowledge_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Knowledge Journal"
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Concepts you have learned from notes, clues, and Mrs. Lin."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 19)
	layout.add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	knowledge_list_label = Label.new()
	knowledge_list_label.text = ""
	knowledge_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_list_label.custom_minimum_size = Vector2(480, 520)
	knowledge_list_label.add_theme_font_size_override("font_size", 21)
	scroll.add_child(knowledge_list_label)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(500, 44)
	close_button.pressed.connect(close_knowledge_journal)
	layout.add_child(close_button)

	update_knowledge_journal_text()
func toggle_knowledge_journal():
	if message_panel.visible:
		return

	if evidence_board_open:
		return

	if objective_panel_open:
		return

	if knowledge_panel_open:
		close_knowledge_journal()
	else:
		open_knowledge_journal()


func open_knowledge_journal():
	knowledge_panel_open = true
	update_knowledge_journal_text()
	knowledge_panel.visible = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)


func close_knowledge_journal():
	knowledge_panel_open = false
	knowledge_panel.visible = false

	if not game_over and not dialogue_active and not evidence_board_open and not objective_panel_open:
		player.set_physics_process(true)

		if enemy != null:
			enemy.set_physics_process(true)
func add_knowledge_item(
	item_id: String
) -> void:
	GameState.add_knowledge(item_id)
	knowledge_items = GameState.knowledge_items

	update_knowledge_journal_text()
	update_objective_text()
func update_knowledge_journal_text():
	if knowledge_list_label == null:
		return

	if knowledge_items.size() == 0:
		knowledge_list_label.text = "No concepts learned yet.\n\nExplore the castle, read notes, inspect clues, and listen to Mrs. Lin to build your knowledge."
		return

	var text = ""

	for item_id in knowledge_items:
		text += get_knowledge_detail(item_id) + "\n\n"

	knowledge_list_label.text = text
func get_knowledge_detail(item_id: String) -> String:
	if item_id == "current_resistance":
		return "Concept Card: Current and Resistance\n\n" + \
		"What you learned:\nIncreasing resistance reduces current flow.\n\n" + \
		"Why it matters:\nA circuit with too little resistance can allow too much current to flow, causing heat, damage, or a short circuit.\n\n" + \
		"How to apply it:\nIf a lock asks how to reduce current, choose the option that increases resistance."

	return "Unknown concept."
func set_dialogue_speaker(speaker_name: String):
	if avatar_name_label == null:
		return

	avatar_name_label.text = speaker_name
	_set_avatar_style(speaker_name)


## 对话头像：玩家保留色块，NPC 使用统一像素肖像。
func _set_avatar_style(speaker_name: String) -> void:
	if avatar_panel == null or avatar_portrait == null:
		return
	var portrait_path := str(NPC_DIALOGUE_PORTRAITS.get(speaker_name, ""))
	avatar_portrait.texture = null
	if not portrait_path.is_empty():
		avatar_portrait.texture = load(portrait_path) as Texture2D
	avatar_portrait.visible = avatar_portrait.texture != null
	var is_player: bool = speaker_name == "You" or speaker_name == "Detective"
	var style: StyleBoxFlat = avatar_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = (
			Color(0.16, 0.22, 0.30, 0.95)
			if is_player
			else Color(0.20, 0.16, 0.10, 0.95)
		)
		avatar_panel.add_theme_stylebox_override("panel", style)


func set_dialogue_text(speaker_name: String, text: String):
	_current_speaker = speaker_name
	_dialogue_segments = _split_dialogue_segments(text)
	_segment_index = 0
	_pending_dialogue_buttons.clear()
	_pending_continue = {}
	set_dialogue_speaker(speaker_name)
	message_panel.visible = true
	_render_dialogue_segment()


## ============================================================
## 分段式对话（wake_room 标准）
## ============================================================

const DIALOGUE_SEGMENT_MAX_CHARS: int = 140

var _dialogue_segments: Array[String] = []
var _segment_index: int = 0
var _current_speaker: String = ""
var _pending_dialogue_buttons: Array = []
var _pending_continue: Dictionary = {}


func _render_dialogue_segment() -> void:
	message_label.text = _dialogue_segments[_segment_index]
	reset_dialogue_scrolls()
	clear_buttons()
	_clear_continue_button()
	if _segment_index < _dialogue_segments.size() - 1:
		_show_continue_direct("Continue", _advance_dialogue_segment)
	else:
		for entry: Dictionary in _pending_dialogue_buttons:
			add_dialogue_button(
				str(entry.get("text", "")),
				entry.get("callback")
			)
		if not _pending_continue.is_empty():
			_show_continue_direct(
				str(_pending_continue.get("text", "")),
				_pending_continue.get("callback")
			)


func _advance_dialogue_segment() -> void:
	_segment_index += 1
	_render_dialogue_segment()


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


## 直接显示 continue 按钮（不走 pending，供分段渲染内部使用）。
func _show_continue_direct(text: String, callback: Callable) -> void:
	if dialogue_continue_button == null:
		return
	dialogue_continue_button.text = text
	dialogue_continue_button.visible = true
	style_dialogue_button(dialogue_continue_button, false)
	for connection in dialogue_continue_button.pressed.get_connections():
		dialogue_continue_button.pressed.disconnect(connection.callable)
	dialogue_continue_button.pressed.connect(callback)


func _clear_continue_button() -> void:
	if dialogue_continue_button != null:
		dialogue_continue_button.visible = false


func show_continue_button(text: String, callback: Callable):
	# 分段显示中：暂存，最后一段才显示。
	if _segment_index < _dialogue_segments.size() - 1:
		_pending_continue = {"text": text, "callback": callback}
		return
	if dialogue_continue_button == null:
		return

	dialogue_continue_button.text = text
	dialogue_continue_button.visible = true
	style_dialogue_button(dialogue_continue_button, false)

	for connection in dialogue_continue_button.pressed.get_connections():
		dialogue_continue_button.pressed.disconnect(connection.callable)

	dialogue_continue_button.pressed.connect(callback)
func make_panel_style(bg_color: Color, border_color: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func style_dialogue_button(button: Button, is_choice_button: bool):
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.10, 0.14, 0.96)
	normal_style.border_color = Color(0.45, 0.38, 0.22, 1.0)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.18, 0.16, 0.12, 0.98)
	hover_style.border_color = Color(0.83, 0.68, 0.32, 1.0)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(6)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.22, 0.18, 0.10, 1.0)
	pressed_style.border_color = Color(0.95, 0.78, 0.34, 1.0)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(6)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))

	if is_choice_button:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func apply_dialogue_visual_style():
	if message_panel != null:
		message_panel.add_theme_stylebox_override(
			"panel",
			make_panel_style(Color(0.04, 0.04, 0.06, 0.95), Color(0.72, 0.58, 0.28, 1.0), 2, 10)
		)

	if message_label != null:
		message_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))

	if dialogue_continue_button != null:
		style_dialogue_button(dialogue_continue_button, false)
func reset_dialogue_scrolls():
	if message_scroll != null:
		message_scroll.scroll_vertical = 0
		message_scroll.set_deferred("scroll_vertical", 0)

	if button_scroll != null:
		button_scroll.scroll_vertical = 0
		button_scroll.set_deferred("scroll_vertical", 0)
func start_investigation_from_intro():
	intro_reviewing_objectives = false
	message_panel.visible = false
	clear_buttons()
	end_dialogue_pause()
func show_castle_hall_arrival():
	start_dialogue_pause()
	clear_buttons()

	set_dialogue_speaker("Mrs. Lin")
	message_panel.visible = true

	set_dialogue_text(
		"Mrs. Lin",
		"The knowledge lock releases with a heavy click.\n\n"
		+ "You step through the doorway, and the door slams shut behind you.\n\n"
		+ "This is the first-floor Castle Hall. The room where you woke lies behind the sealed southern door.\n\n"
		+ "Stay close. This hall connects the major investigation areas of Shadow Castle."
	)

	show_continue_button(
		"Look around",
		show_castle_hall_arrival_page_two
	)
func show_castle_hall_arrival_page_two():
	clear_buttons()

	set_dialogue_text(
		"Mrs. Lin",
		"I can see several possible investigation areas from here.\n\n"
		+ "The laboratory wing lies to the northwest. The greenhouse is northeast, and the castle's electrical machinery is somewhere to the west.\n\n"
		+ "Do not rush to accuse anyone. Search for scientific evidence, read nearby notes, and use the knowledge locks carefully.\n\n"
		+ "Something else is moving inside the castle. We may not be alone."
	)

	show_continue_button(
		"Begin the investigation",
		start_castle_hall_exploration
	)
func start_castle_hall_exploration():
	GameState.hall_arrival_seen = true
	message_panel.visible = false
	clear_buttons()

	dialogue_active = false
	hall_arrival_finished = true

	player.set_physics_process(true)

	update_objective_text()

	# Give the player a moment to look around.
	if LAYOUT_ALIGNMENT_MODE:
		return

	await get_tree().create_timer(2.0).timeout

	if game_over or dialogue_active:
		return

	if enemy != null:
		enemy.visible = true
		enemy_chase_started = true
		enemy.set_physics_process(true)

func create_floor_one_layout_markers():
	# Actual clues and NPCs already create their own visual
	# markers and labels. Only mark positions that do not
	# otherwise have a visible object during alignment mode.

	create_layout_marker(
		"Entrance",
		WAKE_ROOM_DOOR_FOCUS_POSITION,
		Color(0.2, 0.8, 1.0, 0.9)
	)

	create_layout_marker(
		"Circuit Door",
		CIRCUIT_DOOR_FOCUS_POSITION,
		Color(1.0, 0.55, 0.15, 0.9)
	)

	create_layout_marker(
		"Enemy Start",
		ENEMY_START_POSITION,
		Color(1.0, 0.1, 0.1, 0.9)
	)
	create_layout_marker(
		"Chemistry Door",
		CHEMISTRY_ROOM_DOOR_FOCUS_POSITION,
		Color(0.95, 0.25, 0.85, 0.95)
	)
	create_layout_marker(
		"Greenhouse Door",
		GREENHOUSE_ROOM_DOOR_FOCUS_POSITION,
		Color(0.25, 0.85, 0.35, 0.95)
	)
	create_layout_marker(
		"Library Door",
		LIBRARY_DOOR_POSITION,
		Color(0.60, 0.30, 0.95, 0.95)
	)
	create_layout_marker(
		"Dining Hall Door",
		DINING_HALL_DOOR_POSITION,
		Color(0.95, 0.65, 0.25, 0.95)
	)
func create_layout_marker(
	marker_text: String,
	world_position: Vector2,
	marker_color: Color
):
	var marker := Node2D.new()
	marker.name = marker_text.replace(" ", "") + "Marker"
	marker.position = world_position
	marker.z_index = 80
	marker.add_to_group(
	"developer_marker"
	)

	marker.visible = GameState.developer_mode
	add_child(marker)

	var square := ColorRect.new()
	square.color = marker_color
	square.size = Vector2(18, 18)
	square.position = Vector2(-9, -9)
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(square)

	var label := Label.new()
	label.text = marker_text
	label.position = Vector2(-55, -35)
	label.size = Vector2(110, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
func load_progress_from_game_state() -> void:
	reputation = GameState.reputation

	# Arrays are shared with GameState.
	evidence_items = GameState.evidence_items
	knowledge_items = GameState.knowledge_items

	evidence_collected = GameState.has_evidence(
		"fake_red_stain"
	)

	pollen_collected = GameState.has_evidence(
		"greenhouse_pollen"
	)

	circuit_collected = GameState.has_evidence(
		"deliberate_short_circuit"
	)

	learned_circuit_rule = (
		GameState.learned_circuit_rule
	)
func award_reputation(amount: int) -> void:
	GameState.add_reputation(amount)
	reputation = GameState.reputation

	if reputation_label != null:
		reputation_label.text = (
			"Reputation: "
			+ str(reputation)
		)
func apply_persistent_visual_state() -> void:
	if reputation_label != null:
		reputation_label.text = (
			"Reputation: "
			+ str(reputation)
		)

	if evidence_collected and clue_node != null:
		clue_node.color = Color(
			0.35,
			0.02,
			0.04,
			0.7
		)

	if pollen_collected and pollen_node != null:
		pollen_node.color = Color(
			0.45,
			0.35,
			0.05,
			0.7
		)

	if circuit_collected and circuit_node != null:
		circuit_node.color = Color(
			0.05,
			0.25,
			0.35,
			0.7
		)

	if (
		learned_circuit_rule
		and circuit_note_node != null
	):
		circuit_note_node.color = Color(
			0.55,
			0.52,
			0.25,
			0.75
		)

	update_evidence_board_text()
	update_knowledge_journal_text()
	update_objective_text()
func enter_greenhouse_room() -> void:
	if scene_transitioning:
		return

	scene_transitioning = true
	current_interaction = ""

	var room_scene: PackedScene = load(
		GREENHOUSE_ROOM_SCENE_PATH
	) as PackedScene
	if room_scene == null:
		scene_transitioning = false
		show_not_developed_prompt("Greenhouse Room")
		return

	GameState.save_room_checkpoint(
		GREENHOUSE_ROOM_SCENE_PATH,
		"greenhouse_room",
		"greenhouse_start"
	)

	if interact_label != null:
		interact_label.visible = false
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)
	if enemy != null:
		enemy.set_physics_process(false)
	GameState.enemy_chase_active = false

	GameState.prepare_room_transition(
		"greenhouse_room",
		"res://scenes/game_world.tscn",
		"greenhouse_door"
	)

	var change_error: Error = get_tree().change_scene_to_packed(room_scene)
	if change_error != OK:
		scene_transitioning = false
		player.set_physics_process(true)
		push_error(
			"Failed to enter Greenhouse Room. Error: "
			+ str(change_error)
		)


func _enter_new_room(
	scene_path: String,
	room_id: String,
	spawn_id: String,
	failure_name: String
) -> void:
	if scene_transitioning:
		return

	scene_transitioning = true
	current_interaction = ""

	var room_scene: PackedScene = load(scene_path) as PackedScene
	if room_scene == null:
		scene_transitioning = false
		show_not_developed_prompt(failure_name)
		return

	GameState.save_room_checkpoint(scene_path, room_id, spawn_id)

	if interact_label != null:
		interact_label.visible = false
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)
	if enemy != null:
		enemy.set_physics_process(false)
	GameState.enemy_chase_active = false

	GameState.prepare_room_transition(
		room_id,
		"res://scenes/game_world.tscn",
		spawn_id
	)

	var change_error: Error = get_tree().change_scene_to_packed(room_scene)
	if change_error != OK:
		scene_transitioning = false
		player.set_physics_process(true)
		push_error(
			"Failed to enter "
			+ failure_name
			+ ". Error: "
			+ str(change_error)
		)


func enter_circuit_room() -> void:
	_enter_new_room(
		CIRCUIT_ROOM_SCENE_PATH,
		"circuit_room",
		"circuit_door",
		"Circuit Room"
	)


func enter_dining_hall_room() -> void:
	_enter_new_room(
		DINING_HALL_ROOM_SCENE_PATH,
		"dining_hall",
		"dining_hall_door",
		"Dining Hall"
	)


func enter_library_room() -> void:
	_enter_new_room(
		LIBRARY_ROOM_SCENE_PATH,
		"library",
		"library_door",
		"Library"
	)


func enter_final_room() -> void:
	_enter_new_room(
		FINAL_ROOM_SCENE_PATH,
		"final_deduction_room",
		"final_room_door",
		"Final Room"
	)


func enter_chemistry_room() -> void:
	if scene_transitioning:
		return

	scene_transitioning = true
	current_interaction = ""

	var scene_exists: bool = ResourceLoader.exists(
		CHEMISTRY_ROOM_SCENE_PATH
	)

	if not scene_exists:
		scene_transitioning = false

		push_error(
			"Chemistry Room scene does not exist at: "
			+ CHEMISTRY_ROOM_SCENE_PATH
		)
		return

	var room_scene: PackedScene = load(
		CHEMISTRY_ROOM_SCENE_PATH
	) as PackedScene

	if room_scene == null:
		scene_transitioning = false

		push_error(
			"Chemistry Room file exists but could not "
			+ "be loaded as a PackedScene."
		)
		return

	GameState.save_room_checkpoint(
		CHEMISTRY_ROOM_SCENE_PATH,
		"chemistry_room",
		"chemistry_start"
	)

	if interact_label != null:
		interact_label.visible = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	GameState.enemy_chase_active = false

	GameState.prepare_room_transition(
		"chemistry_room",
		"res://scenes/game_world.tscn",
		"chemistry_door"
	)

	var change_error: Error = (
		get_tree().change_scene_to_packed(
			room_scene
		)
	)

	if change_error != OK:
		scene_transitioning = false
		player.set_physics_process(true)

		push_error(
			"Failed to enter Chemistry Room. Error: "
			+ str(change_error)
		)


func enter_wake_room() -> void:
	# 从大厅返回 wake_room（门已解锁后始终可进出，不再答题）。
	if scene_transitioning:
		return

	scene_transitioning = true
	current_interaction = ""

	var room_scene: PackedScene = load(
		WAKE_ROOM_SCENE_PATH
	) as PackedScene

	if room_scene == null:
		scene_transitioning = false

		push_error(
			"Wake Room file exists but could not "
			+ "be loaded as a PackedScene."
		)
		return

	GameState.save_room_checkpoint(
		WAKE_ROOM_SCENE_PATH,
		"wake_room",
		"wake_room_start"
	)

	if interact_label != null:
		interact_label.visible = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	GameState.enemy_chase_active = false

	GameState.prepare_room_transition(
		"wake_room",
		"res://scenes/game_world.tscn",
		"wake_room_door"
	)

	var change_error: Error = (
		get_tree().change_scene_to_packed(
			room_scene
		)
	)

	if change_error != OK:
		scene_transitioning = false
		player.set_physics_process(true)

		push_error(
			"Failed to enter Wake Room. Error: "
			+ str(change_error)
		)
func get_floor_one_spawn_position() -> Vector2:
	match GameState.return_spawn_id:
		"chemistry_door":
			return (
				CHEMISTRY_ROOM_RETURN_POSITION
			)

		"greenhouse_door":
			return GREENHOUSE_ROOM_DOOR_POSITION

		"wake_room_door":
			return WAKE_ROOM_DOOR_POSITION

		"circuit_door":
			return CIRCUIT_DOOR_POSITION

		"dining_hall_door":
			return DINING_HALL_DOOR_POSITION

		"library_door":
			return LIBRARY_DOOR_POSITION

		"final_room_door":
			return FINAL_ROOM_DOOR_POSITION

		_:
			return HALL_ENTRANCE_POSITION


func resume_castle_hall_after_return() -> void:
	hall_arrival_finished = true
	dialogue_active = false
	scene_transitioning = false

	if message_panel != null:
		message_panel.visible = false

	clear_buttons()

	current_interaction = ""

	if interact_label != null:
		interact_label.visible = false

	player.set_physics_process(true)

	update_objective_text()

func toggle_developer_mode() -> void:
	GameState.toggle_developer_mode()

	if GameState.developer_mode:
		camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)
	else:
		camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)

	update_developer_mode_label()

	set_developer_markers_visible(
		GameState.developer_mode
	)

func update_camera_zoom(
	delta: float
) -> void:
	if follow_camera == null:
		return

	var interpolation_weight: float = clampf(
		delta
			* CAMERA_ZOOM_CHANGE_SPEED,
		0.0,
		1.0
	)

	follow_camera.zoom = (
		follow_camera.zoom.lerp(
			camera_target_zoom,
			interpolation_weight
		)
	)
func set_developer_markers_visible(
	should_show: bool
) -> void:
	var markers: Array[Node] = (
		get_tree().get_nodes_in_group(
			"developer_marker"
		)
	)

	for marker: Node in markers:
		if marker is CanvasItem:
			var canvas_item: CanvasItem = (
				marker as CanvasItem
			)

			canvas_item.visible = should_show
func create_developer_mode_label() -> void:
	if ui_layer == null:
		return

	developer_mode_label = Label.new()
	developer_mode_label.name = (
		"DeveloperModeLabel"
	)

	developer_mode_label.position = Vector2(
		730,
		18
	)

	developer_mode_label.size = Vector2(
		270,
		32
	)

	developer_mode_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	developer_mode_label.add_theme_font_size_override(
		"font_size",
		16
	)

	ui_layer.add_child(
		developer_mode_label
	)

	update_developer_mode_label()
func update_developer_mode_label() -> void:
	if developer_mode_label == null:
		return

	if GameState.developer_mode:
		developer_mode_label.text = (
			"DEVELOPER MODE — F3"
		)

		developer_mode_label.visible = true
	else:
		developer_mode_label.text = ""
		developer_mode_label.visible = false
