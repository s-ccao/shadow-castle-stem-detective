extends Node2D


# ============================================================
# Room layout
# ============================================================

const ROOM_WIDTH: int = 1305
const ROOM_HEIGHT: int = 1206
const WALL_THICKNESS: float = 32.0
const ROOM_BACKGROUND_PATH: String = \
	"res://assets/backgrounds/chemistry_room_alchemy_lab.png"
const CHEMISTRY_EVIDENCE_OVERVIEW_PATH: String = \
	"res://assets/props/Chemistry/chemistry_fake_stain_overview.png"
const ALCHEMY_WORKBENCH_UI_SCENE: PackedScene = preload("res://scenes/ui/alchemy_workbench_ui.tscn")
# 玩家从大厅进入 Chemistry Room 时出现在顶部大门内侧。
# 门楣碰撞在 y≈121 以上，所以出生点放在门洞内可站地面，
# 距大门交互点 (742,107) 约 33px，出生即可触发出口交互。
const PLAYER_SPAWN_POSITION: Vector2 = Vector2(
	742.0,
	140.0
)

# 顶部中央大门：交互点与出生点相同，玩家在大门处按 E 返回大厅。
const EXIT_POSITION: Vector2 = Vector2(
	742.0,
	107.0
)

const EXIT_INTERACT_RADIUS: float = 80.0

# 左上角大药柜：焦点在柜体中心，玩家在柜子下方地面触发。
const CABINET_POSITION: Vector2 = Vector2(
	422.0,
	140.0
)
const CABINET_INTERACTION_POSITION: Vector2 = Vector2(
	422.0,
	300.0
)
const CABINET_INTERACT_RADIUS: float = 90.0

# 新图右侧的大面积血迹中心。
const RED_STAIN_POSITION: Vector2 = Vector2(
	971.0,
	597.0
)

# 中央炼金桌的视觉焦点和桌前可走交互点分离。
const ALCHEMY_TABLE_POSITION: Vector2 = Vector2(
	620.0,
	520.0
)
const ALCHEMY_TABLE_INTERACTION_POSITION: Vector2 = Vector2(
	620.0,
	720.0
)
const ALCHEMY_TABLE_INTERACT_RADIUS: float = 150.0

const BUTLER_POSITION: Vector2 = Vector2(
	650.0,
	270.0
)
const BUTLER_VISUAL_SCALE: float = 2.10
const BUTLER_VISUAL_FOOT_ANCHOR: Vector2 = Vector2(0.0, -48.30)
const DR_LIN_ECHO_VISUAL_SCALE: float = 0.45
const DR_LIN_ECHO_VISUAL_FOOT_ANCHOR: Vector2 = Vector2(0.0, -44.55)
var room_input_enabled: bool = false
var scene_transitioning: bool = false

const CLUE_INTERACT_RADIUS: float = 65.0
const NPC_INTERACT_RADIUS: float = 70.0

# 交互面积与贴图范围一致：玩家靠近贴图任意一侧即触发。
const INTERACT_EDGE_DISTANCE: float = 40.0
# 大门交互区 = 门洞开口（y 100-155），门楣碰撞区（y<100）不误触。
const EXIT_RECT: Rect2 = Rect2(660, 100, 175, 55)
# 柜子交互区 = 柜体贴图 + 柜前地面（玩家站在柜前即可触发）。
const CABINET_RECT: Rect2 = Rect2(260, 45, 325, 255)
const ALCHEMY_TABLE_RECT: Rect2 = Rect2(375, 350, 485, 340)
# 血迹矩形只覆盖右侧血泊主体（x 900-1165）。
# 桌子矩形边缘扩展区（x 860-900）归桌子，两者完全分离。
const RED_STAIN_RECT: Rect2 = Rect2(900, 500, 265, 350)
const BUTLER_RECT: Rect2 = Rect2(620, 240, 60, 60)
const ROOM_COLLISION_MASK: int = 1
const CHEMISTRY_GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(
	1.35,
	1.35
)

const CHEMISTRY_DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(
	0.90,
	0.90
)

const CAMERA_ZOOM_CHANGE_SPEED: float = 7.0
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20
const OCCLUSION_PROP_PATHS: Array[NodePath] = [
	NodePath("Worldsort/ChemistryLabTable"),
	NodePath("Worldsort/ChemistryPotionCabinet"),
]

@export var interaction_hint_position: Vector2 = Vector2(238, 696)
@export var interaction_hint_size: Vector2 = Vector2(548, 68)

## 调试开关：默认关闭。需要校准时可在 Inspector 勾选 Debug Print Click Position。
@export var debug_print_click_position := false
var _last_debug_mouse_position := Vector2(-100000, -100000)
# ============================================================
# Nodes and state
# ============================================================

@onready var player: CharacterBody2D = $Worldsort/player
@onready var room_background: Sprite2D = $Background
var current_interaction: String = ""
var dialogue_active: bool = false

var clue_node: ColorRect
var butler_node: AnimatedNpc

var ui_layer: CanvasLayer
var reputation_label: Label
var interact_label: Label
var interaction_hint_panel: Panel
var interaction_focus: WorldInteractionFocus

var message_panel: Panel
var message_label: Label
var message_button_box: HBoxContainer
var avatar_panel: Panel
var avatar_portrait: TextureRect
var avatar_name_label: Label
var evidence_overview_preview: TextureRect
var red_stain_material_strip: Control

var follow_camera: Camera2D
var vision_demo_markers: Array[Node] = []
var vision_echo: AnimatedNpc
var spatial := RoomSpatialRuntime.new()


var camera_target_zoom: Vector2 = (
	CHEMISTRY_GAMEPLAY_CAMERA_ZOOM
)

# ============================================================
# Scene setup
# ============================================================

func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = "chemistry_room"
	GameState.set_room_visited("chemistry_room")

	# Background and collisions now come from the scene.
	create_exit_marker()
	create_red_stain_clue()
	create_butler_npc()
	create_butler_collision()

	create_room_ui()
	create_interaction_focus()
	var parchment: Node = get_node_or_null("/root/ParchmentHud")
	if parchment != null and parchment.has_signal("parchment_committed"):
		var parchment_callback: Callable = Callable(self, "_on_parchment_committed")
		if not parchment.is_connected("parchment_committed", parchment_callback):
			parchment.connect("parchment_committed", parchment_callback)

	player.position = spatial.resolve_safe_spawn(
		player,
		PLAYER_SPAWN_POSITION,
		get_room_world_bounds()
	)

	if player.has_method("set_room_visual_scale"):
		player.call(
			"set_room_visual_scale",
			"chemistry_room"
		)
	create_follow_camera()
	room_input_enabled = false

	await get_tree().create_timer(0.25).timeout

	room_input_enabled = true
	apply_persistent_state()

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


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(
		"toggle_developer_mode"
	):
		toggle_chemistry_developer_mode()

	update_camera_zoom(delta)
	_update_prop_occlusion_layers()

	if not room_input_enabled:
		hide_interaction_feedback()
		return

	if scene_transitioning:
		hide_interaction_feedback()
		return

	if dialogue_active:
		hide_interaction_feedback()
		return

	if alchemy_workbench_ui != null and alchemy_workbench_ui.visible:
		hide_interaction_feedback()
		return

	update_interaction_prompt()
	update_interaction_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = interact_label.visible

	if Input.is_action_just_pressed("interact"):
		handle_interaction()


func _update_prop_occlusion_layers() -> void:
	for prop_path: NodePath in OCCLUSION_PROP_PATHS:
		var prop := get_node_or_null(prop_path) as Node2D
		if prop == null:
			continue
		prop.z_index = 0
		spatial.update_occlusion(player, prop, PROP_BACK_Z, PROP_FRONT_Z)

func update_interaction_prompt() -> void:
	current_interaction = ""
	interact_label.visible = false

	# 所有交互面积与贴图范围一致：玩家碰撞框接近可见边缘
	# 14 px 时触发，不再使用物品中心点半径。
	if _is_near_interaction("exit"):
		current_interaction = "exit"
		interact_label.text = (
			"Press E to return to the Castle Hall"
		)
		interact_label.visible = true
		return

	if _is_near_interaction("cabinet"):
		current_interaction = "cabinet"
		interact_label.text = (
			"Press E to inspect the potion cabinet"
		)
		interact_label.visible = true
		return

	# 桌子优先于血迹：血迹矩形已收缩到 x≥850，
	# 玩家接触桌子主体/右缘时优先显示桌子交互。
	if _is_near_interaction("alchemy_table"):
		current_interaction = "alchemy_table"
		interact_label.text = (
			"Press E to inspect the alchemy table"
		)
		interact_label.visible = true
		return

	if _is_near_interaction("red_stain"):
		current_interaction = "red_stain"

		if GameState.has_evidence(
			"fake_red_stain"
		):
			interact_label.text = (
				"Press E to review the red stain"
			)
		else:
			interact_label.text = (
				"Press E to investigate the red stain"
			)

		interact_label.visible = true
		return

	if _is_near_interaction("butler"):
		current_interaction = "butler"
		interact_label.text = (
			"Press E to talk to the Butler"
		)
		interact_label.visible = true


func handle_interaction() -> void:
	match current_interaction:
		"exit":
			return_to_castle_hall()

		"cabinet":
			show_cabinet_dialogue()

		"alchemy_table":
			show_alchemy_table_dialogue()

		"red_stain":
			show_red_stain_intro()

		"butler":
			show_butler_dialogue()

		_:
			pass


# 点到矩形最近距离：用于把交互面积匹配到贴图范围。
func _distance_to_rect(
	point: Vector2,
	rect: Rect2
) -> float:
	var nearest: Vector2 = Vector2(
		clampf(
			point.x,
			rect.position.x,
			rect.position.x + rect.size.x
		),
		clampf(
			point.y,
			rect.position.y,
			rect.position.y + rect.size.y
		)
	)
	return point.distance_to(nearest)


func get_interaction_rect(interaction_id: String) -> Rect2:
	match interaction_id:
		"exit":
			return EXIT_RECT
		"cabinet":
			var cabinet := get_node_or_null("Worldsort/ChemistryPotionCabinet") as Node2D
			return spatial.get_visual_rect(cabinet) if cabinet != null else CABINET_RECT
		"alchemy_table":
			var table := get_node_or_null("Worldsort/ChemistryLabTable") as Node2D
			return spatial.get_visual_rect(table) if table != null else ALCHEMY_TABLE_RECT
		"red_stain":
			return RED_STAIN_RECT
		"butler":
			if butler_node != null:
				var butler_rect := spatial.get_visual_rect(butler_node)
				if butler_rect.size.x > 0.0 and butler_rect.size.y > 0.0:
					return butler_rect
			return BUTLER_RECT
	return Rect2()


func _is_near_interaction(interaction_id: String) -> bool:
	return spatial.is_actor_near_rect(
		player,
		get_interaction_rect(interaction_id),
		14.0
	)


# ============================================================
# Potion cabinet
# ============================================================

func show_cabinet_dialogue() -> void:
	# 剧情：首次交互药柜 → 发现暗格 → 获得温室钥匙。
	if not GameState.has_story_flag("chemistry_cabinet_secret_found"):
		GameState.set_story_flag("chemistry_cabinet_secret_found")
		GameState.add_key("greenhouse_room_key")
		if NoteHud != null and not NoteHud.has_clue("cabinet_secret_note"):
			NoteHud.add_clue("cabinet_secret_note", {
				"title": "The Hidden Compartment",
				"icon": "icon_note",
				"content": (
					"[center][b]The Hidden Compartment[/b][/center]\n\n"
					+ "Behind the reagent racks in the potion cabinet, a hidden compartment slides open.\n\n"
					+ "Inside rests a [color=#4a306d]green-stained key[/color] marked with a leaf-shaped crest — the Greenhouse Room Key.\n\n"
					+ "Someone hid the greenhouse key here, far away from the greenhouse itself. "
					+ "Whoever did this did not want the greenhouse visited."
				),
				"category": "investigation",
			})
		start_dialogue_pause()
		show_message(
			"You",
			"As you shift the reagent racks, a hidden compartment "
			+ "slides open inside the cabinet.\n\n"
			+ "A green-stained key marked with a leaf-shaped crest "
			+ "rests inside — the Greenhouse Room Key. "
			+ "It has been added to your Key Hub.\n\n"
			+ "Someone hid the greenhouse key here, far from the "
			+ "greenhouse itself. Whoever did this did not want "
			+ "that room visited."
		)
		clear_message_buttons()
		add_message_button(
			"Continue",
			close_message_panel
		)
		return
	start_dialogue_pause()
	show_message(
		"You",
		"This potion cabinet holds dozens of bottles, "
		+ "vials, and reagent flasks. Most are sealed, "
		+ "but a few have fresh fingerprints on the glass.\n\n"
		+ "The colourful liquids look like ordinary alchemy "
		+ "supplies. Nothing here matches the red stain "
		+ "by the table — the cabinet was probably not "
		+ "the source of that spill."
	)
	clear_message_buttons()
	add_message_button(
		"Continue",
		close_message_panel
	)


# ============================================================
# Alchemy table
# ============================================================

## 炼金台旁的变化分拣。化学室知识展品讲的是"生成新物质才叫化学变化"，
## 这个小游戏用铁生锈、蜡熔化这类反直觉样本把那条判据练到手。
func _open_change_sorting_minigame() -> void:
	var launched: bool = MinigameLauncher.launch(
		self,
		ChangeSortingMinigame.new(),
		_mg_text("Sample Tray", "样本分拣盘"),
		_mg_text(
			"Mrs. Lin left a tray of samples to be filed. A change is chemical"
			+ " only when a new substance appears.",
			"林女士留下了一盘待归档的样本。只有生成了新物质才算化学变化。"
		),
		Color(0.86, 0.52, 0.98, 1.0),
		_on_change_sorting_finished
	)
	if not launched:
		show_message("You", "The sample tray is already open.")


func _on_change_sorting_finished(cleared_all: bool, stages: int) -> void:
	if cleared_all:
		GameState.set_story_flag("chemistry_change_sorted")
		show_message(
			"You",
			"Every sample filed. The red stain belongs with the chemical"
			+ " changes — a new substance formed when the indicator met the"
			+ " cleaning powder. It was never blood."
		)
		return
	show_message(
		"You",
		"You filed %d trays before setting the samples down." % stages
	)


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english


func show_alchemy_table_dialogue() -> void:
	# 读完笔记本之后，炼金台先出一盘分拣练习再进配药界面。
	if (
		GameState.has_story_flag("mrs_lin_lab_note_seen")
		and not GameState.has_story_flag("chemistry_change_sorted")
	):
		_open_change_sorting_minigame()
		return
	# 剧情：首次交互炼金台 → Mrs. Lin 留下的笔记本（羊皮纸弹窗）。
	if not GameState.has_story_flag("mrs_lin_lab_note_seen"):
		GameState.set_story_flag("mrs_lin_lab_note_seen")
		var parchment: Node = get_node_or_null("/root/ParchmentHud")
		if parchment != null:
			parchment.call(
				"show_parchment",
				"Mrs. Lin's Lab Notebook",
				"From Mrs. Lin's notebook, left on this table:\n\n"
				+ "\"Red liquid test — not blood.\n\n"
				+ "Smell: rusty, metallic, with a sharp chemical undertone — "
				+ "cleaning powder.\n\n"
				+ "Do not taste unknown residue. Use a controlled indicator comparison instead; "
				+ "the white powder and the cleaning agent produce the same red response under "
				+ "this test.\n\n"
				+ "Conclusion: the stain was staged.\n\n"
				+ "I almost called it blood when I first saw it. You would have corrected me for jumping to conclusions. Perhaps I taught you something after all.\"",
				"mrs_lin_lab_note",
				{
					"title": "Mrs. Lin's Lab Notebook",
					"icon": "icon_note",
					"content": (
						"[center][b]Mrs. Lin's Lab Notebook[/b][/center]\n\n"
						+ "\"Red liquid test — not blood. Smell: rusty, metallic, "
						+ "with a sharp chemical undertone — cleaning powder. "
						+ "Do not taste unknown residue. Use a controlled indicator comparison: "
						+ "the white powder and cleaning agent produce the same red response under "
						+ "this test.\n\n"
						+ "Conclusion: the stain was [color=#7a2e2e]staged[/color] "
						+ "to look like a murder scene.\n\n"
						+ "I almost called it blood when I first saw it. You would have corrected me for jumping to conclusions. Perhaps I taught you something after all.\""
					),
					"category": "investigation",
				}
			)
		GameState.set_story_flag("chemistry_vision_demo_pending")
		if parchment == null:
			call_deferred("_play_vision_sample_demo")
		return
	# 首次交互炼金台：样品已经演示过，后续只允许打开制作界面。
	if not GameState.has_story_flag("chemistry_first_reward_given"):
		_grant_first_visit_swiftness()
		return
	start_dialogue_pause()
	show_message(
		"You",
		"The alchemy table is covered in broken glass, "
		+ "crystal residue, and spilled reagents.\n\n"
		+ "The damage is concentrated around the central "
		+ "vessel. Something happened here before the "
		+ "blood-like spill reached the floor."
	)
	clear_message_buttons()
	# 无论是否已经找到配方，都允许打开制作界面。
	# 配方检查延迟到点击具体制作按钮时。
	add_message_button(
		"Craft Potions",
		show_craft_panel
	)
	add_message_button(
		"Continue",
		close_message_panel
	)


# ============================================================
# Potion crafting (alchemy table)
# ============================================================

var craft_panel: Panel
var prototype_craft_ui: Control
var alchemy_workbench_ui: AlchemyWorkbenchUI
var craft_box: VBoxContainer
var selected_recipe_id: String = ""
var selected_recipe_label: Label
var synthesize_button: Button
var clear_selection_button: Button
var ingredient_slot_labels: Array[Label] = []
var ingredient_slot_images: Array[TextureRect] = []
var reference_product_image: TextureRect
var reference_product_name_label: Label
var reference_product_details_label: Label
var reference_description_label: Label
var reference_requirement_icons: HBoxContainer
var reference_requirement_text_label: Label
var reference_description_hint_label: Label
var reference_selected_material_image: TextureRect
var reference_selected_material_text: Label
var recipe_slot_buttons: Array[Button] = []
var recipe_slot_images: Array[TextureRect] = []
var recipe_slot_lights: Array[Panel] = []
const RECIPE_LIST_ORIGIN: Vector2 = Vector2(12, 330)
var recipe_slot_centers: Array[Vector2] = [
	Vector2(104, 38),
	Vector2(104, 86),
	Vector2(104, 133),
	Vector2(104, 181),
	Vector2(104, 228),
	Vector2(104, 276),
	Vector2(104, 323),
]

func create_craft_panel() -> void:
	if craft_panel != null:
		return
	craft_panel = Panel.new()
	craft_panel.name = "CraftPanel"
	craft_panel.position = Vector2.ZERO
	craft_panel.size = Vector2(1024, 768)
	craft_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	craft_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	craft_panel.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.97)
	style.border_color = Color(0.62, 0.45, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	craft_panel.add_theme_stylebox_override("panel", style)
	craft_panel.visible = false
	ui_layer.add_child(craft_panel)

	var alchemy_board: TextureRect = TextureRect.new()
	alchemy_board.name = "AlchemyWorkbenchArtwork"
	# 这是一张完整的正方形炼金界面，不能再缩成左半栏。
	alchemy_board.position = Vector2(220, 78)
	alchemy_board.size = Vector2(580, 580)
	alchemy_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alchemy_board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alchemy_board.texture = load("res://assets/ui/alchemy/alchemy_workbench_clean.png") as Texture2D
	alchemy_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_panel.add_child(alchemy_board)

	var recipe_list_art: TextureRect = TextureRect.new()
	recipe_list_art.name = "RecipeListArtwork"
	# CraftPanel 从屏幕 x=128 开始；负 x 让独立 List 放到主炼金图左侧。
	recipe_list_art.position = RECIPE_LIST_ORIGIN
	recipe_list_art.size = Vector2(168, 356)
	recipe_list_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recipe_list_art.stretch_mode = TextureRect.STRETCH_SCALE
	recipe_list_art.texture = load("res://assets/ui/alchemy/recipe_list_slots.png") as Texture2D
	recipe_list_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_list_art.z_index = 4
	craft_panel.add_child(recipe_list_art)

	var recipe_list_title := Label.new()
	recipe_list_title.name = "RecipeListTitle"
	recipe_list_title.text = "Recipe List"
	recipe_list_title.position = Vector2(8, 304)
	recipe_list_title.size = Vector2(176, 22)
	recipe_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_list_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recipe_list_title.add_theme_font_size_override("font_size", 11)
	recipe_list_title.add_theme_color_override("font_color", Color(0.30, 0.18, 0.10, 1.0))
	recipe_list_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_list_title.z_index = 6
	craft_panel.add_child(recipe_list_title)

	var title := Label.new()
	title.text = "Potion Crafting"
	title.position = Vector2(342, 18)
	title.size = Vector2(340, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.93, 0.87, 0.70))
	craft_panel.add_child(title)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.position = Vector2(968, 18)
	close_button.size = Vector2(44, 44)
	close_button.flat = true
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.z_index = 100
	close_button.add_theme_font_size_override("font_size", 23)
	close_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.82, 1.0))
	close_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.28, 1.0))
	close_button.pressed.connect(close_craft_panel)
	craft_panel.add_child(close_button)

	var scroll := ScrollContainer.new()
	# 旧的文字列表不再显示；RecipeListArtwork 上方由七个真实按钮格负责交互。
	scroll.position = RECIPE_LIST_ORIGIN
	scroll.size = Vector2(168, 356)
	scroll.visible = false
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.z_index = 7
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	craft_panel.add_child(scroll)
	_build_recipe_slot_controls()

	craft_box = VBoxContainer.new()
	craft_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_box.add_theme_constant_override("separation", 4)
	craft_box.custom_minimum_size = Vector2(190, 0)
	scroll.add_child(craft_box)

	selected_recipe_label = Label.new()
	selected_recipe_label.name = "SelectedRecipeLabel"
	selected_recipe_label.position = Vector2(386, 620)
	selected_recipe_label.size = Vector2(320, 40)
	selected_recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_recipe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_recipe_label.add_theme_font_size_override("font_size", 13)
	selected_recipe_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48, 1.0))
	selected_recipe_label.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 1.0))
	selected_recipe_label.add_theme_constant_override("outline_size", 3)
	selected_recipe_label.text = "Select a recipe to load ingredients"
	craft_panel.add_child(selected_recipe_label)

	ingredient_slot_labels.clear()
	ingredient_slot_images.clear()
	_create_ingredient_slot_label(Vector2(541, 258))
	_create_ingredient_slot_label(Vector2(479, 334))
	_create_ingredient_slot_label(Vector2(642, 334))
	_create_ingredient_slot_label(Vector2(542, 402))

	synthesize_button = Button.new()
	synthesize_button.name = "SynthesizeButton"
	synthesize_button.text = "Synthesize"
	synthesize_button.position = Vector2(836, 643)
	synthesize_button.size = Vector2(96, 36)
	synthesize_button.process_mode = Node.PROCESS_MODE_ALWAYS
	synthesize_button.mouse_filter = Control.MOUSE_FILTER_STOP
	synthesize_button.z_index = 100
	_apply_action_button_style(synthesize_button, Color(0.12, 0.38, 0.20, 0.98), Color(0.80, 0.64, 0.25, 1.0))
	synthesize_button.tooltip_text = "合成：检查配方和材料，并将成品放入背包"
	synthesize_button.add_theme_font_size_override("font_size", 13)
	synthesize_button.pressed.connect(_synthesize_selected_recipe)
	craft_panel.add_child(synthesize_button)

	clear_selection_button = Button.new()
	clear_selection_button.name = "ClearSelectionButton"
	clear_selection_button.text = "Clear"
	clear_selection_button.position = Vector2(948, 646)
	clear_selection_button.size = Vector2(64, 32)
	clear_selection_button.process_mode = Node.PROCESS_MODE_ALWAYS
	clear_selection_button.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_selection_button.z_index = 100
	_apply_action_button_style(clear_selection_button, Color(0.16, 0.10, 0.07, 0.98), Color(0.72, 0.52, 0.25, 1.0))
	clear_selection_button.tooltip_text = "清空当前选择的配方和材料槽"
	clear_selection_button.add_theme_font_size_override("font_size", 12)
	clear_selection_button.pressed.connect(_clear_recipe_selection)
	craft_panel.add_child(clear_selection_button)
	_build_reference_alchemy_panels()


func _build_reference_alchemy_panels() -> void:
	var materials_panel: Panel = _new_reference_panel("MaterialsPanel", Vector2(8, 82), Vector2(202, 215), Color(0.055, 0.035, 0.028, 0.96))
	craft_panel.add_child(materials_panel)
	var materials_title: Label = _reference_label("Materials", Vector2(14, 12), Vector2(174, 28), 17, Color(0.96, 0.78, 0.37, 1.0))
	materials_panel.add_child(materials_title)
	var materials_hint: Label = _reference_label("Inventory", Vector2(14, 40), Vector2(174, 20), 10, Color(0.72, 0.62, 0.48, 1.0))
	materials_panel.add_child(materials_hint)
	var grid: GridContainer = GridContainer.new()
	grid.name = "MaterialImageGrid"
	grid.position = Vector2(12, 70)
	grid.size = Vector2(178, 132)
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 6)
	materials_panel.add_child(grid)
	_add_material_card(grid, "moonleaf", "Herb", GameState.get_item_texture_path("moonleaf"), GameState.get_herb_count("moonleaf"))
	_add_material_card(grid, "blue_blossom", "Blossom", GameState.get_item_texture_path("blue_blossom"), GameState.get_herb_count("blue_blossom"))
	_add_material_card(grid, "mushrooms", "Mushroom", "res://assets/ui/alchemy/mushrooms.png", GameState.get_herb_count("moonleaf"))
	_add_material_card(grid, "swift_potion", "Red Potion", GameState.get_item_texture_path("swift_potion"), 1 if GameState.inventory_items.has("swift_potion") else 0)
	_add_material_card(grid, "green_potion", "Green Potion", GameState.get_item_texture_path("green_potion"), 1 if GameState.inventory_items.has("green_potion") else 0)
	_add_material_card(grid, "vision_potion", "Vision Potion", GameState.get_item_texture_path("vision_potion"), 1 if GameState.inventory_items.has("vision_potion") else 0)
	var selected_title: Label = _reference_label("Selected Material", Vector2(14, 370), Vector2(174, 24), 12, Color(0.90, 0.72, 0.34, 1.0))
	selected_title.visible = false
	materials_panel.add_child(selected_title)
	reference_selected_material_image = TextureRect.new()
	var selected_image: TextureRect = reference_selected_material_image
	selected_image.name = "SelectedMaterialImage"
	selected_image.position = Vector2(18, 402)
	selected_image.size = Vector2(64, 64)
	selected_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_image.texture = load(GameState.get_item_texture_path("moonleaf")) as Texture2D
	selected_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_image.visible = false
	materials_panel.add_child(selected_image)
	reference_selected_material_text = _reference_label("Green Herb\nRestores health +10\nNeutralizes toxins +5", Vector2(88, 402), Vector2(100, 74), 10, Color(0.82, 0.75, 0.62, 1.0))
	var selected_text: Label = reference_selected_material_text
	selected_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_text.visible = false
	materials_panel.add_child(selected_text)

	var product_panel: Panel = _new_reference_panel("ExpectedProductPanel", Vector2(804, 82), Vector2(212, 208), Color(0.055, 0.028, 0.075, 0.96))
	craft_panel.add_child(product_panel)
	product_panel.add_child(_reference_label("Expected Product", Vector2(8, 8), Vector2(196, 24), 13, Color(0.96, 0.78, 0.37, 1.0)))
	var product_frame: TextureRect = TextureRect.new()
	product_frame.name = "ExpectedProductFrameArtwork"
	product_frame.position = Vector2(61, 34)
	product_frame.size = Vector2(90, 102)
	product_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_frame.stretch_mode = TextureRect.STRETCH_SCALE
	product_frame.texture = load("res://assets/ui/alchemy/recipe_selected_frame.png") as Texture2D
	product_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_frame.z_index = 1
	product_panel.add_child(product_frame)
	reference_product_image = TextureRect.new()
	var product_image: TextureRect = reference_product_image
	product_image.name = "ExpectedPotionImage"
	product_image.position = Vector2(59, 36)
	product_image.size = Vector2(94, 94)
	product_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product_image.texture = load(GameState.get_item_texture_path("swift_potion")) as Texture2D
	product_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_panel.add_child(product_image)
	reference_product_name_label = _reference_label("Swiftness Potion", Vector2(8, 132), Vector2(196, 22), 12, Color(0.96, 0.86, 0.56, 1.0))
	product_panel.add_child(reference_product_name_label)
	reference_product_details_label = _reference_label("Speed +20s  |  Owned: 1", Vector2(8, 157), Vector2(196, 22), 9, Color(0.75, 0.68, 0.58, 1.0))
	product_panel.add_child(reference_product_details_label)
	var brewing_note: Label = _reference_label("Success Rate: 85%", Vector2(8, 181), Vector2(196, 20), 11, Color(0.40, 0.96, 0.55, 1.0))
	product_panel.add_child(brewing_note)

	var description_panel: Panel = _new_reference_panel("RecipeDescriptionPanel", Vector2(804, 448), Vector2(212, 175), Color(0.27, 0.18, 0.10, 0.96))
	description_panel.visible = false
	craft_panel.add_child(description_panel)
	description_panel.add_child(_reference_label("Recipe Description", Vector2(10, 10), Vector2(192, 24), 13, Color(0.98, 0.82, 0.48, 1.0)))
	reference_description_label = _reference_label("Select a recipe.\n\nRequired Materials:", Vector2(12, 36), Vector2(188, 48), 8, Color(0.87, 0.78, 0.64, 1.0))
	var description: Label = reference_description_label
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_panel.add_child(description)
	reference_requirement_icons = HBoxContainer.new()
	var requirement_icons: HBoxContainer = reference_requirement_icons
	requirement_icons.position = Vector2(12, 84)
	requirement_icons.size = Vector2(188, 48)
	requirement_icons.add_theme_constant_override("separation", 4)
	description_panel.add_child(requirement_icons)
	for icon_path: String in ["moonleaf.png", "blue_blossom.png", "mushrooms.png", "green_potion.png"]:
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/ui/alchemy/" + icon_path) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		requirement_icons.add_child(icon)
	reference_description_hint_label = _reference_label("Materials loaded.", Vector2(12, 157), Vector2(188, 14), 7, Color(0.72, 0.64, 0.53, 1.0))
	description_panel.add_child(reference_description_hint_label)
	reference_requirement_text_label = _reference_label("", Vector2(12, 130), Vector2(188, 28), 7, Color(0.88, 0.78, 0.60, 1.0))
	reference_requirement_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_panel.add_child(reference_requirement_text_label)

	var nav: Panel = _new_reference_panel("BottomNavigation", Vector2(8, 704), Vector2(1008, 56), Color(0.035, 0.025, 0.025, 0.98))
	craft_panel.add_child(nav)
	for index: int in range(4):
		var nav_button: Button = Button.new()
		nav_button.text = ["Materials", "Recipes", "Brewing", "Records"][index]
		nav_button.position = Vector2(12 + index * 150, 10)
		nav_button.size = Vector2(136, 36)
		nav_button.flat = true
		nav_button.process_mode = Node.PROCESS_MODE_ALWAYS
		nav_button.mouse_filter = Control.MOUSE_FILTER_STOP
		nav_button.z_index = 100
		nav_button.add_theme_font_size_override("font_size", 11)
		nav_button.tooltip_text = "Open " + nav_button.text + " category"
		nav_button.pressed.connect(_on_reference_navigation_pressed.bind(index))
		nav.add_child(nav_button)
	var action_bar: TextureRect = TextureRect.new()
	action_bar.name = "AlchemyActionBarArtwork"
	action_bar.position = Vector2(824, 632)
	action_bar.size = Vector2(184, 64)
	action_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_bar.stretch_mode = TextureRect.STRETCH_SCALE
	action_bar.texture = load("res://assets/ui/alchemy/alchemy_action_bar.png") as Texture2D
	action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_bar.z_index = 90
	craft_panel.add_child(action_bar)


func _new_reference_panel(panel_name: String, panel_position: Vector2, panel_size: Vector2, background: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.65, 0.43, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _reference_label(label_text: String, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.position = label_position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_action_button_style(button: Button, background: Color, border: Color) -> void:
	button.flat = false
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.18)
	hover.border_color = Color(1.0, 0.88, 0.48, 1.0)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.18)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.66, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.86, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.35, 1.0))


func _add_material_card(parent: GridContainer, item_id: String, item_name: String, texture_path: String, quantity: int) -> void:
	var card: Button = Button.new()
	card.name = "MaterialButton_" + item_id
	card.text = ""
	card.custom_minimum_size = Vector2(56, 60)
	card.flat = false
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Inspect " + item_name
	card.pressed.connect(_on_reference_material_selected.bind(item_id, item_name, texture_path, quantity))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.055, 0.98)
	style.border_color = Color(0.48, 0.32, 0.16, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.96, 0.76, 0.28, 1.0)
	hover_style.set_border_width_all(2)
	card.add_theme_stylebox_override("hover", hover_style)
	var pressed_style: StyleBoxFlat = hover_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.22, 0.14, 0.08, 1.0)
	card.add_theme_stylebox_override("pressed", pressed_style)
	parent.add_child(card)
	var image: TextureRect = TextureRect.new()
	image.position = Vector2(9, 4)
	image.size = Vector2(36, 34)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = load(texture_path) as Texture2D
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)
	var name_label: Label = _reference_label(item_name, Vector2(2, 39), Vector2(52, 16), 7, Color(0.85, 0.76, 0.62, 1.0))
	name_label.clip_text = true
	card.add_child(name_label)
	var quantity_label: Label = _reference_label("∞" if GameState.developer_mode else str(quantity), Vector2(34, 4), Vector2(18, 16), 9, Color(0.98, 0.82, 0.35, 1.0))
	card.add_child(quantity_label)


func _on_reference_material_selected(item_id: String, item_name: String, texture_path: String, quantity: int) -> void:
	if reference_selected_material_image == null or reference_selected_material_text == null:
		return
	reference_selected_material_image.texture = load(texture_path) as Texture2D
	reference_selected_material_text.text = "%s\nOwned: %s\nClick Select on a recipe to load its slots." % [item_name, "∞" if GameState.developer_mode else str(quantity)]


func _on_reference_navigation_pressed(index: int) -> void:
	if reference_selected_material_text == null:
		return
	var navigation_name: String = ["Materials", "Recipes", "Brewing", "Records"][index]
	reference_selected_material_text.text = "%s tab selected\nUse the controls in this panel." % navigation_name


func _create_ingredient_slot_label(slot_position: Vector2) -> void:
	var slot_label := Label.new()
	slot_label.name = "IngredientSlotLabel_%d" % ingredient_slot_labels.size()
	# slot_position 是截图校准后的槽位中心，不是左上角。
	slot_label.position = slot_position + Vector2(-43, 28)
	slot_label.size = Vector2(86, 26)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_label.add_theme_font_size_override("font_size", 8)
	slot_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.64, 1.0))
	slot_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02, 1.0))
	slot_label.add_theme_constant_override("outline_size", 3)
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_label.text = "Empty"
	craft_panel.add_child(slot_label)
	ingredient_slot_labels.append(slot_label)
	var slot_image: TextureRect = TextureRect.new()
	slot_image.name = "IngredientSlotImage_%d" % ingredient_slot_images.size()
	slot_image.position = slot_position + Vector2(-28, -26)
	slot_image.size = Vector2(56, 42)
	slot_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_panel.add_child(slot_image)
	ingredient_slot_images.append(slot_image)
	var slot_button: Button = Button.new()
	slot_button.name = "IngredientSlotButton_%d" % ingredient_slot_labels.size()
	slot_button.position = slot_position + Vector2(-25, -24)
	slot_button.size = Vector2(50, 48)
	slot_button.text = ""
	slot_button.flat = true
	slot_button.process_mode = Node.PROCESS_MODE_ALWAYS
	slot_button.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_button.z_index = 100
	slot_button.tooltip_text = "查看已加载材料；材料由 Select 配方自动放入"
	slot_button.pressed.connect(_on_ingredient_slot_pressed.bind(ingredient_slot_labels.size() - 1))
	craft_panel.add_child(slot_button)


func _on_ingredient_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ingredient_slot_labels.size():
		return
	if selected_recipe_id.is_empty():
		return
	var slot_text: String = ingredient_slot_labels[slot_index].text
	if slot_text == "Empty":
		return
	if reference_selected_material_text != null:
		reference_selected_material_text.text = "Loaded Ingredient\n%s" % slot_text.replace("\n", "  ")


func show_craft_panel() -> void:
	# The workbench is a dedicated UI scene; Chemistry Room owns only opening it.
	message_panel.visible = false
	var reward_hud: Node = get_node_or_null("/root/ItemRewardHud")
	if reward_hud != null and reward_hud.has_method("dismiss_for_overlay"):
		reward_hud.call("dismiss_for_overlay")
	var inventory_hud: Node = get_node_or_null("/root/InventoryHud")
	if inventory_hud != null and inventory_hud.get("feature_panel") != null:
		(inventory_hud.get("feature_panel") as Panel).visible = false
	hide_interaction_feedback()
	if alchemy_workbench_ui == null:
		alchemy_workbench_ui = ALCHEMY_WORKBENCH_UI_SCENE.instantiate() as AlchemyWorkbenchUI
		alchemy_workbench_ui.closed.connect(_on_alchemy_workbench_closed)
		add_child(alchemy_workbench_ui)
	alchemy_workbench_ui.open(self)


func close_craft_panel() -> void:
	if alchemy_workbench_ui != null:
		alchemy_workbench_ui.close()
		return
	if prototype_craft_ui != null:
		prototype_craft_ui.visible = false
	if craft_panel != null:
		craft_panel.visible = false
	end_dialogue_pause()


func _on_alchemy_workbench_closed() -> void:
	end_dialogue_pause()


func _rebuild_craft_list() -> void:
	for child: Node in craft_box.get_children():
		child.queue_free()
	_refresh_recipe_slot_controls()


func _build_recipe_slot_controls() -> void:
	recipe_slot_buttons.clear()
	recipe_slot_images.clear()
	recipe_slot_lights.clear()
	for index: int in range(recipe_slot_centers.size()):
		var center: Vector2 = recipe_slot_centers[index]
		var button: Button = Button.new()
		button.name = "RecipeSlotButton_%d" % index
		button.position = RECIPE_LIST_ORIGIN + center - Vector2(74, 18)
		button.size = Vector2(148, 36)
		button.text = ""
		button.flat = true
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_index = 100
		button.tooltip_text = "选择这个配方格"
		button.pressed.connect(_on_recipe_slot_pressed.bind(index))
		craft_panel.add_child(button)
		recipe_slot_buttons.append(button)
		var light: Panel = Panel.new()
		light.name = "RecipeSlotLight_%d" % index
		light.position = RECIPE_LIST_ORIGIN + Vector2(31, center.y - 10)
		light.size = Vector2(20, 20)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.z_index = 101
		var light_style: StyleBoxFlat = StyleBoxFlat.new()
		light_style.bg_color = Color(1.0, 0.78, 0.22, 0.98)
		light_style.border_color = Color(1.0, 0.95, 0.60, 1.0)
		light_style.set_border_width_all(2)
		light_style.set_corner_radius_all(10)
		light_style.shadow_color = Color(1.0, 0.62, 0.12, 0.85)
		light_style.shadow_size = 8
		light.add_theme_stylebox_override("panel", light_style)
		light.visible = false
		craft_panel.add_child(light)
		recipe_slot_lights.append(light)
		var potion_image: TextureRect = TextureRect.new()
		potion_image.name = "RecipeSlotPotion_%d" % index
		potion_image.position = RECIPE_LIST_ORIGIN + Vector2(86, center.y - 17)
		potion_image.size = Vector2(34, 34)
		potion_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		potion_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		potion_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion_image.z_index = 102
		potion_image.visible = false
		craft_panel.add_child(potion_image)
		recipe_slot_images.append(potion_image)
	_refresh_recipe_slot_controls()


func _refresh_recipe_slot_controls() -> void:
	for index: int in range(recipe_slot_buttons.size()):
		var available: bool = index < GameState.recipe_items.size()
		recipe_slot_buttons[index].visible = available
		recipe_slot_lights[index].visible = false
		recipe_slot_images[index].visible = false
		if not available:
			continue
		var recipe_id: String = GameState.recipe_items[index]
		recipe_slot_buttons[index].tooltip_text = str(GameState.RECIPE_INFO.get(recipe_id, {}).get("name", recipe_id))
		var potion_id: String = str(GameState.RECIPE_INFO.get(recipe_id, {}).get("produces", ""))
		recipe_slot_images[index].texture = load(_potion_texture_path(potion_id)) as Texture2D
		recipe_slot_images[index].visible = true
		if recipe_id == selected_recipe_id:
			recipe_slot_lights[index].visible = true
			recipe_slot_images[index].modulate = Color.WHITE
		else:
			recipe_slot_images[index].modulate = Color(0.62, 0.62, 0.62, 0.78)


func _on_recipe_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameState.recipe_items.size():
		return
	_select_recipe(GameState.recipe_items[slot_index])


func _select_recipe(recipe_id: String) -> void:
	if not GameState.has_recipe(recipe_id):
		return
	selected_recipe_id = recipe_id
	_update_selected_recipe_ui()
	_rebuild_craft_list()


func _clear_recipe_selection() -> void:
	selected_recipe_id = ""
	_update_selected_recipe_ui()
	_rebuild_craft_list()


func _update_selected_recipe_ui() -> void:
	if selected_recipe_label == null:
		return
	for slot_label: Label in ingredient_slot_labels:
		slot_label.text = "Empty"
	if selected_recipe_id.is_empty():
		for slot_image: TextureRect in ingredient_slot_images:
			slot_image.texture = null
		_update_reference_recipe_summary("")
		if GameState.recipe_items.is_empty():
			selected_recipe_label.text = (
				"No potion recipes discovered\n"
				+ "Find a recipe sheet before synthesizing."
			)
		else:
			selected_recipe_label.text = "Select a recipe to load ingredients"
		return
	var recipe_info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	selected_recipe_label.text = "Selected: %s" % str(recipe_info.get("name", selected_recipe_id))
	var ingredient_names: Array[String] = []
	var ingredient_ids: Array[String] = []
	var herb_cost: Dictionary = recipe_info.get("herb_cost", {})
	var material_cost: Dictionary = recipe_info.get("material_cost", {})
	for herb_id: String in herb_cost.keys():
		ingredient_ids.append(herb_id)
		ingredient_names.append(
			"%s\n%d/%d" % [
				str(GameState.HERB_INFO.get(herb_id, {}).get("name", herb_id)),
				GameState.get_herb_count(herb_id),
				int(herb_cost[herb_id])
			]
		)
	for material_id: String in material_cost.keys():
		ingredient_ids.append(material_id)
		ingredient_names.append(
			"%s\n%d/%d" % [
				str(GameState.MATERIAL_INFO.get(material_id, {}).get("name", material_id)),
				GameState.get_material_count(material_id),
				int(material_cost[material_id])
			]
		)
	for index: int in range(mini(ingredient_names.size(), ingredient_slot_labels.size())):
		ingredient_slot_labels[index].text = ingredient_names[index]
		ingredient_slot_images[index].texture = load(_ingredient_texture_path(ingredient_ids[index])) as Texture2D
	for empty_index: int in range(ingredient_names.size(), ingredient_slot_images.size()):
		ingredient_slot_images[empty_index].texture = null
	_update_reference_recipe_summary(selected_recipe_id)


func _ingredient_texture_path(item_id: String) -> String:
	return GameState.get_item_texture_path(item_id)


func _update_reference_recipe_summary(recipe_id: String) -> void:
	if reference_product_image == null or reference_description_label == null or reference_requirement_icons == null:
		return
	if recipe_id.is_empty() or not GameState.RECIPE_INFO.has(recipe_id):
		reference_product_image.texture = load(GameState.get_item_texture_path("swift_potion")) as Texture2D
		reference_product_name_label.text = "No recipe selected"
		reference_product_details_label.text = "Select a recipe to preview"
		reference_description_label.text = "Select a recipe.\n\nRequired Materials:"
		reference_requirement_text_label.text = ""
		reference_description_hint_label.text = "Materials load from the selected recipe."
	else:
		var recipe_info: Dictionary = GameState.RECIPE_INFO.get(recipe_id, {})
		var produces: String = str(recipe_info.get("produces", ""))
		var potion_info: Dictionary = GameState.POTION_INFO.get(produces, {})
		reference_product_image.texture = load(_potion_texture_path(produces)) as Texture2D
		reference_product_name_label.text = str(potion_info.get("name", produces))
		reference_product_details_label.text = "%s  |  Owned: %d" % [str(potion_info.get("effect", "Effect")), 1 if GameState.inventory_items.has(produces) else 0]
		reference_description_label.text = "%s.\n\nRequired Materials:" % str(recipe_info.get("name", recipe_id)).replace(" Recipe", "")
		var requirement_text: String = ""
		for herb_id: String in recipe_info.get("herb_cost", {}).keys():
			requirement_text += "%s %d/%d\n" % [str(GameState.HERB_INFO.get(herb_id, {}).get("name", herb_id)), GameState.get_herb_count(herb_id), int(recipe_info.get("herb_cost", {}).get(herb_id, 1))]
		for material_id: String in recipe_info.get("material_cost", {}).keys():
			requirement_text += "%s %d/%d\n" % [str(GameState.MATERIAL_INFO.get(material_id, {}).get("name", material_id)), GameState.get_material_count(material_id), int(recipe_info.get("material_cost", {}).get(material_id, 1))]
		reference_requirement_text_label.text = requirement_text.strip_edges()
		reference_description_hint_label.text = "Materials loaded."
	for child: Node in reference_requirement_icons.get_children():
		child.queue_free()
	var selected_info: Dictionary = GameState.RECIPE_INFO.get(recipe_id, {})
	var icon_ids: Array[String] = []
	for herb_id: String in selected_info.get("herb_cost", {}).keys():
		icon_ids.append(herb_id)
	for material_id: String in selected_info.get("material_cost", {}).keys():
		icon_ids.append(material_id)
	for item_id: String in icon_ids:
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(_ingredient_texture_path(item_id)) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reference_requirement_icons.add_child(icon)


func _potion_texture_path(potion_id: String) -> String:
	return GameState.get_item_texture_path(potion_id)


func _synthesize_selected_recipe() -> void:
	if selected_recipe_id.is_empty():
		if GameState.recipe_items.is_empty():
			_craft_without_recipe()
			return
		show_message("You", "Select a recipe before synthesizing.")
		clear_message_buttons()
		add_message_button("Back to Crafting", show_craft_panel)
		add_message_button("Close", close_message_panel)
		return
	var recipe_info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	_craft_potion(
		selected_recipe_id,
		str(recipe_info.get("produces", "")),
		recipe_info.get("herb_cost", {}),
		recipe_info.get("material_cost", {})
	)


func _craft_without_recipe() -> void:
	# 无配方时，点击制作才提示；制作界面本身可以正常打开。
	if craft_panel != null:
		craft_panel.visible = false
	show_message(
		"You",
		"You don't have a potion recipe yet. Find a recipe sheet before crafting."
	)
	clear_message_buttons()
	add_message_button("Back to Crafting", show_craft_panel)
	add_message_button("Close", close_message_panel)


func _craft_potion(recipe_id: String, produces: String, cost: Dictionary, material_cost: Dictionary = {}) -> void:
	if not GameState.has_recipe(recipe_id):
		show_message(
			"You",
			"You need the matching recipe sheet before you can craft this potion."
		)
		clear_message_buttons()
		add_message_button("Back", show_craft_panel)
		return
	for herb_id: String in cost.keys():
		var need: int = int(cost[herb_id])
		if GameState.get_herb_count(herb_id) < need:
			show_message(
				"You",
				"Not enough %s. Gather more in the greenhouse."
				% str(GameState.HERB_INFO.get(herb_id, {}).get("name", herb_id))
			)
			clear_message_buttons()
			add_message_button("Back", show_craft_panel)
			return
	for material_id: String in material_cost.keys():
		var material_need: int = int(material_cost[material_id])
		if GameState.get_material_count(material_id) < material_need:
			show_message(
				"You",
				"Not enough %s. Find the missing material in another room or corridor."
				% str(GameState.MATERIAL_INFO.get(material_id, {}).get("name", material_id))
			)
			clear_message_buttons()
			add_message_button("Back", show_craft_panel)
			return
	for herb_id: String in cost.keys():
		GameState.consume_herb(herb_id, int(cost[herb_id]))
	for material_id: String in material_cost.keys():
		GameState.consume_material(material_id, int(material_cost[material_id]))
	GameState.add_inventory_item(produces)
	end_dialogue_pause()


# ============================================================
# Chemistry clue
# ============================================================

func show_red_stain_intro() -> void:
	start_dialogue_pause()

	if GameState.has_evidence(
		"fake_red_stain"
	):
		show_message(
			"You",
			"I already examined this stain.\n\n"
			+ "It is not blood — the colour comes from an "
			+ "indicator reacting with a basic cleaner."
		)
		_show_red_stain_samples()

		clear_message_buttons()

		add_message_button(
			"Continue",
			close_message_panel
		)

		return

	show_message(
		"You",
		"I kneel beside the stain and inspect the edge with a clean swab.\n\n"
		+ "The smell is rusty and metallic, but underneath it "
		+ "there is something sharp and chemical, like the "
		+ "cleaning solution used to scrub this room.\n\n"
		+ "I will compare the powder, broken bottle, and indicator "
		+ "under controlled conditions. Do not taste unknown residue."
	)
	_show_red_stain_samples()

	clear_message_buttons()

	add_message_button(
		"Check the powder and the broken bottle",
		_on_red_stain_examined
	)


## 血迹独白后：检查白色粉末与碎瓶 → 获得证据与调查笔记。
func _on_red_stain_examined() -> void:
	show_message(
		"You",
		"Beside the stain lie white powder and a broken "
		+ "bottle — the cleaner's residue.\n\n"
		+ "Powder plus an indicator... the red colour is "
		+ "a reaction, not a wound. Someone staged this "
		+ "stain to look like blood."
	)
	_show_red_stain_samples()
	clear_message_buttons()
	add_message_button(
		"Record this finding",
		_on_red_stain_recorded
	)


func _on_red_stain_recorded() -> void:
	collect_red_stain_evidence()
	show_message(
		"You",
		"I have what I need. The Butler asked me to look "
		+ "at this stain — time to tell him what it really is."
	)
	_show_red_stain_samples()
	clear_message_buttons()
	add_message_button(
		"Talk to the Butler",
		close_message_panel
	)


func collect_red_stain_evidence() -> void:
	GameState.add_evidence(
		"fake_red_stain"
	)

	# 剧情：红渍调查笔记（一次性写入侦探笔记）。
	if NoteHud != null and not NoteHud.has_clue("chemistry_room_note"):
		NoteHud.add_clue("chemistry_room_note", {
			"title": "Chemistry Room Investigation Note",
			"icon": "icon_note",
			"content": (
				"[center][b]Chemistry Room Investigation Note[/b][/center]\n\n"
				+ "Mrs. Lin's note, written mid-investigation:\n\n"
				+ "The [color=#7a2e2e]red stain[/color] by the alchemy table is not blood. "
				+ "The colour matches an indicator reacting with a [color=#4a306d]basic cleaning substance[/color] — a staged stain.\n\n"
				+ "The shattered glass and scattered reagents suggest someone "
				+ "[color=#7a2e2e]deliberately destroyed the experiment[/color] to make the room look like the scene of a violent crime.\n\n"
				+ "Who would want this room to look like a murder scene?"
			),
			"category": "investigation",
		})

	if clue_node != null:
		clue_node.color = Color(
			0.38,
			0.04,
			0.06,
			0.72
		)

	update_reputation_label()
	update_room_completion()


# ============================================================
# Butler
# ============================================================

func show_butler_dialogue() -> void:
	start_dialogue_pause()

	# 分支 1：首次交互 → Butler 考验。
	if not GameState.has_story_flag("butler_challenge_given"):
		GameState.set_story_flag("butler_challenge_given")
		show_message(
			"Butler",
			"A detective? You? I have served this castle "
			+ "for twenty years, and I have never seen you "
			+ "before in my life.\n\n"
			+ "Very well — prove it. There is a red stain "
			+ "by the alchemy table. Go and look at it. "
			+ "Tell me what it really is, and then we can "
			+ "talk."
		)
		clear_message_buttons()
		add_message_button(
			"Examine the stain",
			close_message_panel
		)
		return

	# 分支 2：考验已给但还没看血迹。
	if not GameState.has_evidence("fake_red_stain"):
		show_message(
			"Butler",
			"Still here? The stain is by the alchemy "
			+ "table. Look at it — smell it, even. "
			+ "Then come back and tell me what it is."
		)
		clear_message_buttons()
		add_message_button(
			"Examine the stain",
			close_message_panel
		)
		return

	# 分支 3：看过血迹 → Butler 屏幕中心选择题。
	if not GameState.has_story_flag("butler_challenge_complete"):
		show_butler_red_stain_question()
		return

	# 分支 4：考验完成 → Butler 告知他知道的信息。
	GameState.set_story_flag("chemistry_butler_interviewed")
	show_message(
		"Butler",
		"You were right. That stain is a mixture of "
		+ "cleaning powder and indicator — it bleeds "
		+ "red for show.\n\n"
		+ "Then I will tell you what I know. That night, "
		+ "the master's study was already dark when the "
		+ "power failed. I heard glass break in this room, "
		+ "and footsteps — quick, heavy ones — heading "
		+ "toward the greenhouse wing.\n\n"
		+ "Whoever staged this knew the castle's cleaning "
		+ "supplies. I handle those supplies and supervise "
		+ "part of the Dining Hall service. The Service Passage "
		+ "should have been closed after service ended. The red "
		+ "cloth you may find there is common service uniform "
		+ "material, not mine alone. That is all I can say."
	)
	clear_message_buttons()
	add_message_button(
		"Continue",
		close_message_panel
	)

	update_room_completion()


## Butler 考验：屏幕中心选择题（wake_room 大门同款 DoorPuzzleUI）。
func show_butler_red_stain_question() -> void:
	message_panel.visible = false
	var door_puzzle: Node = get_node_or_null("/root/DoorPuzzleUI")
	if door_puzzle != null:
		door_puzzle.call(
			"open",
			"THE BUTLER'S TEST\n\nWhat is that red stain by the alchemy table?",
			[
				"It is real blood",
				"An indicator reacted with a basic cleaner",
				"Spilled wine from the feast",
				"Paint from the walls",
			],
			1,
			_on_butler_puzzle_answered
		)


## DoorPuzzleUI 回调：true=答对，false=玩家退出答题。
func _on_butler_puzzle_answered(is_correct: bool) -> void:
	if is_correct:
		on_butler_test_correct()
	else:
		start_dialogue_pause()
		show_message(
			"Butler",
			"Lost your nerve? The stain is still there. "
			+ "Observe the powder, the bottle, and the controlled "
			+ "test — then tell me what it truly is."
		)
		clear_message_buttons()
		add_message_button(
			"Answer the test",
			show_butler_red_stain_question
		)
		add_message_button(
			"Walk away",
			close_message_panel
		)


func on_butler_test_correct() -> void:
	# DoorPuzzleUI 关闭时会恢复暂停，这里重新暂停以显示消息面板。
	start_dialogue_pause()
	GameState.add_reputation(10)
	GameState.set_story_flag("butler_challenge_complete")

	show_message(
		"Butler",
		"...Hmph. You really are a detective.\n\n"
		+ "That stain is cleaning powder and indicator "
		+ "mixed to bleed red for show. I have served "
		+ "this castle long enough to know its tricks.\n\n"
		+ "Now listen: the night the lights went out, I "
		+ "heard glass break in this room, and footsteps "
		+ "heading toward the greenhouse wing. I handle "
		+ "cleaning supplies and part of the Dining Hall service; "
		+ "the Service Passage should have been closed after service. "
		+ "That red service cloth is common uniform material, not "
		+ "a personal mark.\n\n"
		+ "Reputation +10"
	)
	clear_message_buttons()
	add_message_button(
		"Continue",
		close_message_panel
	)

	update_room_completion()


func update_room_completion() -> void:
	var evidence_found: bool = (
		GameState.has_evidence(
			"fake_red_stain"
		)
	)

	var butler_interviewed: bool = (
		GameState.has_story_flag(
			"chemistry_butler_interviewed"
		)
	)

	if evidence_found and butler_interviewed:
		GameState.set_room_completed(
			"chemistry_room"
		)


# ============================================================
# Persistent state
# ============================================================

func apply_persistent_state() -> void:
	update_reputation_label()

	if GameState.has_evidence(
		"fake_red_stain"
	):
		clue_node.color = Color(
			0.38,
			0.04,
			0.06,
			0.72
		)

	update_room_completion()


## 首次实验台奖励一瓶可携带的 Swiftness Potion；Vision 只做一次性样品演示。
func _grant_first_visit_swiftness() -> void:
	if GameState.has_story_flag("chemistry_first_reward_given"):
		return
	GameState.set_story_flag("chemistry_first_reward_given")
	GameState.add_inventory_item("swift_potion")
	show_message(
		"You",
		"One sealed Swiftness Potion rests among the broken glass. "
		+ "It has been placed in your bag.\n\n"
		+ "It increases movement speed. A second vial beside Mrs. Lin's notes "
		+ "is not stable enough to carry — examine the note to see what happens."
	)
	clear_message_buttons()
	add_message_button(
		"Continue",
		close_message_panel
	)


func _on_parchment_committed(note_id: String) -> void:
	if note_id != "mrs_lin_lab_note":
		return
	if not GameState.has_story_flag("chemistry_vision_demo_pending"):
		return
	_play_vision_sample_demo()


func _play_vision_sample_demo() -> void:
	if GameState.has_story_flag("vision_demo_seen"):
		return
	GameState.set_story_flag("chemistry_vision_demo_pending", false)
	GameState.set_story_flag("vision_demo_seen")
	GameState.set_story_flag("vision_demo_consumed")
	if not GameState.has_story_flag("chemistry_first_reward_given"):
		GameState.set_story_flag("chemistry_first_reward_given")
		GameState.add_inventory_item("swift_potion")
	GameState.apply_potion_effect("vision", 10.0)
	camera_target_zoom = GameState.get_room_camera_zoom(
		CHEMISTRY_GAMEPLAY_CAMERA_ZOOM,
		CHEMISTRY_DEVELOPER_CAMERA_ZOOM
	)
	_create_vision_demo_markers()
	start_dialogue_pause()
	show_message(
		"You",
		"You reach for the small blue vial beside Mrs. Lin's notes.\n\n"
		+ "The loose stopper slips free. The sample spills across the workbench, "
		+ "and a pale-blue vapor flashes through the room.\n\n"
		+ "For a few seconds, faint markings that were invisible before appear along "
		+ "the glass and stone. Vision Potion. The unstable sample is completely "
		+ "consumed. A stable Swiftness Potion has been placed in your bag."
	)
	clear_message_buttons()
	add_message_button(
		"Continue",
		_finish_vision_sample_demo
	)


func _finish_vision_sample_demo() -> void:
	close_message_panel()
	get_tree().create_timer(10.0).timeout.connect(_clear_vision_demo_markers)


func _create_vision_demo_markers() -> void:
	_clear_vision_demo_markers()
	_create_vision_echo()
	var marker_positions: Array[Vector2] = [
		Vector2(468.0, 430.0),
		Vector2(720.0, 394.0),
		Vector2(884.0, 548.0),
	]
	for marker_position: Vector2 in marker_positions:
		var marker: Label = Label.new()
		marker.name = "VisionDemoMark"
		marker.text = "◇  ·  ◇"
		marker.position = marker_position
		marker.size = Vector2(120.0, 28.0)
		marker.add_theme_font_size_override("font_size", 18)
		marker.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0, 0.92))
		marker.z_index = 12
		add_child(marker)
		vision_demo_markers.append(marker)


func _create_vision_echo() -> void:
	vision_echo = AnimatedNpc.new()
	vision_echo.name = "DrLinMemoryEcho"
	vision_echo.position = Vector2(730.0, 394.0)
	vision_echo.modulate = Color(0.60, 0.78, 1.0, 0.72)
	vision_echo.z_index = 11
	vision_echo.configure(
		"Dr. Lin Memory Echo",
		"res://assets/characters/animated_pixel_v3/dr_lin_walk.png",
		DR_LIN_ECHO_VISUAL_SCALE,
		Vector2(18.0, 0.0),
		8.0,
		&"left"
	)
	vision_echo.set_visual_foot_anchor(DR_LIN_ECHO_VISUAL_FOOT_ANCHOR)
	add_child(vision_echo)


func _clear_vision_demo_markers() -> void:
	for marker: Node in vision_demo_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	vision_demo_markers.clear()
	if vision_echo != null and is_instance_valid(vision_echo):
		vision_echo.queue_free()
	vision_echo = null


func update_reputation_label() -> void:
	if reputation_label == null:
		return

	reputation_label.text = (
		"Reputation: "
		+ str(GameState.reputation)
	)


# ============================================================
# Dialogue UI
# ============================================================

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

	match current_interaction:
		"exit":
			target_position = EXIT_POSITION
			focus_title = "Castle Hall exit"
			is_primary = true
		"cabinet":
			target_position = CABINET_POSITION
			focus_title = "Potion cabinet"
			is_primary = true
		"alchemy_table":
			target_position = ALCHEMY_TABLE_POSITION
			focus_title = "Alchemy table"
			is_primary = true
		"red_stain":
			target_position = RED_STAIN_POSITION
			focus_title = "Red stain"
		"butler":
			target_position = BUTLER_POSITION
			focus_title = "Butler"
		_:
			interaction_focus.clear_focus()
			return

	var focus_rect := spatial.grow_rect(
		get_interaction_rect(current_interaction),
		Vector2(10.0, 10.0)
	)
	if focus_rect.size.x > 0.0 and focus_rect.size.y > 0.0:
		target_position = focus_rect.get_center()
	interaction_focus.set_focus(
		target_position,
		focus_title,
		is_primary,
		focus_rect.size
	)


func hide_interaction_feedback() -> void:
	if interaction_focus != null:
		interaction_focus.clear_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = false
	if interact_label != null:
		interact_label.visible = false


func create_room_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	# 左上角不再显示白色文字标签（Reputation / 房间名），
	# 全局 NoteHud 负责左上角的笔记本入口提示。

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
	interact_label.position = Vector2(16, 7)
	interact_label.size = Vector2(
		maxf(120.0, interaction_hint_size.x - 32.0),
		maxf(30.0, interaction_hint_size.y - 14.0)
	)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_label.add_theme_font_size_override("font_size", 18)
	interact_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.70, 1.0))
	interact_label.visible = false
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

	evidence_overview_preview = TextureRect.new()
	evidence_overview_preview.name = "ChemistryEvidenceOverviewPreview"
	evidence_overview_preview.position = Vector2(18, 18)
	evidence_overview_preview.size = Vector2(132, 132)
	evidence_overview_preview.texture = load(CHEMISTRY_EVIDENCE_OVERVIEW_PATH) as Texture2D
	evidence_overview_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	evidence_overview_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	evidence_overview_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evidence_overview_preview.visible = false
	evidence_overview_preview.z_index = 3
	message_panel.add_child(evidence_overview_preview)
	_create_red_stain_material_strip()

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

	# 文本区：固定在顶部。
	var message_scroll := ScrollContainer.new()
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

	# 按钮行：固定在对话框底部。
	message_button_box = HBoxContainer.new()
	message_button_box.position = Vector2(164, 196)
	message_button_box.size = Vector2(828, 42)
	message_button_box.add_theme_constant_override("separation", 8)
	message_panel.add_child(message_button_box)


func show_message(
	speaker_name: String,
	body_text: String
) -> void:
	body_text = CaseLocale.line(body_text)
	if evidence_overview_preview != null:
		evidence_overview_preview.visible = false
	if red_stain_material_strip != null:
		red_stain_material_strip.visible = false
	_current_speaker = speaker_name
	_dialogue_segments = _split_dialogue_segments(body_text)
	_segment_index = 0
	_pending_buttons.clear()
	_set_avatar(speaker_name)
	message_panel.visible = true
	_render_segment()


func _create_red_stain_material_strip() -> void:
	red_stain_material_strip = Panel.new()
	red_stain_material_strip.name = "RedStainTraceSamples"
	red_stain_material_strip.position = Vector2(14.0, 14.0)
	red_stain_material_strip.size = Vector2(138.0, 176.0)
	red_stain_material_strip.z_index = 6
	red_stain_material_strip.visible = false
	red_stain_material_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.055, 0.035, 0.040, 0.98)
	strip_style.border_color = Color(0.67, 0.48, 0.23, 0.94)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(7)
	strip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	strip_style.shadow_size = 7
	red_stain_material_strip.add_theme_stylebox_override("panel", strip_style)
	message_panel.add_child(red_stain_material_strip)

	var title := Label.new()
	title.name = "TraceSamplesTitle"
	title.text = "TRACE SAMPLES"
	title.position = Vector2(8.0, 6.0)
	title.size = Vector2(122.0, 18.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.92, 0.74, 0.40, 1.0))
	red_stain_material_strip.add_child(title)

	var samples: Array[Dictionary] = [
		{"id": "cleaning_powder_sample", "label": "POWDER"},
		{"id": "indicator_vial_sample", "label": "INDICATOR"},
		{"id": "broken_glass_sample", "label": "GLASS"},
	]
	for index: int in range(samples.size()):
		var sample := samples[index]
		var row := Panel.new()
		row.name = "TraceSample_" + str(sample["id"])
		row.position = Vector2(7.0, 27.0 + float(index) * 47.0)
		row.size = Vector2(124.0, 42.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var accent := GameState.get_item_accent(str(sample["id"]))
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.88)
		row_style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", row_style)
		red_stain_material_strip.add_child(row)

		var icon := TextureRect.new()
		icon.name = "SampleModel"
		icon.position = Vector2(3.0, 3.0)
		icon.size = Vector2(36.0, 36.0)
		icon.texture = load(GameState.get_item_texture_path(str(sample["id"]))) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var label := Label.new()
		label.name = "SampleLabel"
		label.text = str(sample["label"])
		label.position = Vector2(40.0, 4.0)
		label.size = Vector2(80.0, 34.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(0.90, 0.82, 0.66, 1.0))
		row.add_child(label)


func _show_red_stain_samples() -> void:
	if evidence_overview_preview != null:
		evidence_overview_preview.visible = false
	if red_stain_material_strip != null:
		red_stain_material_strip.visible = true


## ============================================================
## 分段式对话（wake_room 标准）
## ============================================================

const DIALOGUE_SEGMENT_MAX_CHARS: int = 140
const NPC_DIALOGUE_PORTRAITS: Dictionary = {
	"Mrs. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Dr. Lin": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Mrs. Lin's Letter": "res://assets/characters/portraits_pixel_v2/dr_lin.png",
	"Butler": "res://assets/characters/portraits_pixel_v2/butler.png",
	"Gardener": "res://assets/characters/portraits_pixel_v2/gardener.png",
	"Mechanic": "res://assets/characters/portraits_pixel_v2/mechanic.png",
	"Castle Guardian": "res://assets/characters/portraits_pixel_v2/castle_guardian.png",
}

var _dialogue_segments: Array[String] = []
var _segment_index: int = 0
var _current_speaker: String = ""
var _pending_buttons: Array = []


func _render_segment() -> void:
	message_label.text = "%s:\n%s" % [_current_speaker, _dialogue_segments[_segment_index]]
	clear_message_buttons(false)
	if _segment_index < _dialogue_segments.size() - 1:
		var continue_button := Button.new()
		continue_button.name = "SegmentContinueButton"
		continue_button.text = "Continue"
		continue_button.add_theme_font_size_override("font_size", 15)
		continue_button.pressed.connect(_advance_segment)
		message_button_box.add_child(continue_button)
	else:
		for entry: Dictionary in _pending_buttons:
			add_message_button(
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


func add_message_button(
	button_text: String,
	callback: Callable
) -> void:
	# 分段显示中：选项按钮暂存，最后一段才真正加入。
	if _segment_index < _dialogue_segments.size() - 1:
		_pending_buttons.append({"text": button_text, "callback": callback})
		return
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(
		330,
		34
	)
	button.pressed.connect(callback)
	message_button_box.add_child(button)


func clear_message_buttons(keep_continue: bool = true) -> void:
	for child: Node in (
		message_button_box.get_children()
	):
		# 分段进行中：保留 Continue 按钮。
		if keep_continue and child.name == "SegmentContinueButton":
			continue
		child.queue_free()


func close_message_panel() -> void:
	message_panel.visible = false
	if red_stain_material_strip != null:
		red_stain_material_strip.visible = false
	clear_message_buttons(false)
	end_dialogue_pause()


# ============================================================
# Pause and movement
# ============================================================

func start_dialogue_pause() -> void:
	dialogue_active = true
	current_interaction = ""
	interact_label.visible = false

	if player.has_method(
		"cancel_click_movement"
	):
		player.call(
			"cancel_click_movement"
		)

	player.set_physics_process(false)


func end_dialogue_pause() -> void:
	dialogue_active = false
	player.set_physics_process(true)


func on_player_ground_move_started(
	target_position: Vector2
) -> void:
	var room_bounds: Rect2 = (
		get_room_world_bounds()
	)

	var room_end: Vector2 = (
		room_bounds.position
		+ room_bounds.size
	)

	var edge_margin: float = 20.0

	var safe_target: Vector2 = Vector2(
		clampf(
			target_position.x,
			room_bounds.position.x
				+ edge_margin,
			room_end.x
				- edge_margin
		),
		clampf(
			target_position.y,
			room_bounds.position.y
				+ edge_margin,
			room_end.y
				- edge_margin
		)
	)

	if player.has_method("move_to_point"):
		player.call(
			"move_to_point",
			safe_target
		)
func return_to_castle_hall() -> void:
	if scene_transitioning:
		return

	scene_transitioning = true
	room_input_enabled = false

	if player.has_method(
		"cancel_click_movement"
	):
		player.call(
			"cancel_click_movement"
		)

	player.set_physics_process(false)

	GameState.prepare_return_to_hub(
		"chemistry_door"
	)

	var change_error: Error = (
		get_tree().change_scene_to_file(
			GameState.return_scene_path
		)
	)

	if change_error != OK:
		scene_transitioning = false
		room_input_enabled = true
		player.set_physics_process(true)

		push_error(
			"Failed to return to Castle Hall. Error: "
			+ str(change_error)
		)


# ============================================================
# Temporary room artwork
# ============================================================

func create_placeholder_room() -> void:
	var texture: Texture2D = load(
		ROOM_BACKGROUND_PATH
	) as Texture2D

	if texture != null:
		var background: Sprite2D = Sprite2D.new()
		background.name = "ChemistryRoomBackground"
		background.texture = texture
		background.centered = false
		background.position = Vector2.ZERO
		background.z_index = -100

		var texture_size: Vector2 = texture.get_size()

		if texture_size.x > 0.0 and texture_size.y > 0.0:
			background.scale = Vector2(
				float(ROOM_WIDTH) / texture_size.x,
				float(ROOM_HEIGHT) / texture_size.y
			)

		add_child(background)
	else:
		var floor: ColorRect = ColorRect.new()
		floor.name = "TemporaryChemistryFloor"
		floor.color = Color(
			0.11,
			0.09,
			0.12,
			1.0
		)
		floor.position = Vector2.ZERO
		floor.size = Vector2(
			ROOM_WIDTH,
			ROOM_HEIGHT
		)
		floor.z_index = -100
		floor.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		add_child(floor)

	add_room_wall(
		Vector2(
			ROOM_WIDTH / 2.0,
			WALL_THICKNESS / 2.0
		),
		Vector2(
			ROOM_WIDTH,
			WALL_THICKNESS
		)
	)

	add_room_wall(
		Vector2(
			ROOM_WIDTH / 2.0,
			ROOM_HEIGHT
				- WALL_THICKNESS / 2.0
		),
		Vector2(
			ROOM_WIDTH,
			WALL_THICKNESS
		)
	)

	add_room_wall(
		Vector2(
			WALL_THICKNESS / 2.0,
			ROOM_HEIGHT / 2.0
		),
		Vector2(
			WALL_THICKNESS,
			ROOM_HEIGHT
		)
	)

	add_room_wall(
		Vector2(
			ROOM_WIDTH
				- WALL_THICKNESS / 2.0,
			ROOM_HEIGHT / 2.0
		),
		Vector2(
			WALL_THICKNESS,
			ROOM_HEIGHT
		)
	)

	create_exit_marker()


func add_room_wall(
	center_position: Vector2,
	wall_size: Vector2
) -> void:
	var wall: StaticBody2D = (
		StaticBody2D.new()
	)
	wall.position = center_position

	var collision_shape: CollisionShape2D = (
		CollisionShape2D.new()
	)

	var rectangle: RectangleShape2D = (
		RectangleShape2D.new()
	)

	rectangle.size = wall_size
	collision_shape.shape = rectangle

	wall.add_child(collision_shape)
	add_child(wall)


func create_exit_marker() -> void:
	var marker: ColorRect = ColorRect.new()
	marker.color = Color(
		0.72,
		0.52,
		0.24,
		0.90
	)
	marker.size = Vector2(120, 28)
	marker.position = (
		EXIT_POSITION
		- marker.size / 2.0
	)
	marker.z_index = 5
	marker.visible = false
	marker.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(marker)

	add_world_label(
		marker,
		"Castle Hall",
		Vector2(-6, -32)
	)


func create_red_stain_clue() -> void:
	clue_node = ColorRect.new()
	clue_node.name = "RedStainClue"
	clue_node.color = Color(
		0.75,
		0.02,
		0.04,
		1.0
	)
	clue_node.size = Vector2(34, 24)
	clue_node.position = (
		RED_STAIN_POSITION
		- clue_node.size / 2.0
	)
	clue_node.z_index = 5
	clue_node.visible = false
	clue_node.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(clue_node)


func create_butler_npc() -> void:
	butler_node = AnimatedNpc.new()
	butler_node.name = "ButlerNPC"
	butler_node.position = BUTLER_POSITION
	butler_node.configure(
		"Butler",
		"res://assets/characters/animated_pixel_v5/butler_idle_8dir.png",
		BUTLER_VISUAL_SCALE,
		Vector2(14.0, 0.0),
		11.0,
		&"south",
		Vector2i(48, 68),
		8,
		true,
		true
	)
	butler_node.set_visual_foot_anchor(BUTLER_VISUAL_FOOT_ANCHOR)
	butler_node.z_index = 0

	$Worldsort.add_child(butler_node)


func add_world_label(
	parent_node: Node,
	label_text: String,
	offset: Vector2
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.position = offset
	label.size = Vector2(120, 24)
	label.add_theme_font_size_override(
		"font_size",
		15
	)
	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	parent_node.add_child(label)
func create_butler_collision() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "ButlerCollision"
	body.position = BUTLER_POSITION
	body.collision_layer = 1
	body.collision_mask = 0

	var collision: CollisionShape2D = (
		CollisionShape2D.new()
	)

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0

	collision.shape = circle
	body.add_child(collision)
	add_child(body)
func is_point_blocked(
	world_point: Vector2
) -> bool:
	var query: PhysicsPointQueryParameters2D = (
		PhysicsPointQueryParameters2D.new()
	)

	query.position = world_point
	query.collision_mask = ROOM_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [
		player.get_rid()
	]

	var hits: Array[Dictionary] = (
		get_world_2d()
		.direct_space_state
		.intersect_point(
			query,
			8
		)
	)

	return not hits.is_empty()
func create_follow_camera() -> void:
	if follow_camera != null:
		return

	follow_camera = Camera2D.new()
	follow_camera.name = (
		"ChemistryFollowCamera"
	)

	follow_camera.position = Vector2.ZERO

	camera_target_zoom = GameState.get_room_camera_zoom(CHEMISTRY_GAMEPLAY_CAMERA_ZOOM, CHEMISTRY_DEVELOPER_CAMERA_ZOOM)

	follow_camera.zoom = camera_target_zoom
	follow_camera.enabled = true

	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0

	var room_bounds: Rect2 = (
		get_room_world_bounds()
	)

	var room_end: Vector2 = (
		room_bounds.position
		+ room_bounds.size
	)

	follow_camera.limit_left = int(
		floor(room_bounds.position.x)
	)

	follow_camera.limit_top = int(
		floor(room_bounds.position.y)
	)

	follow_camera.limit_right = int(
		ceil(room_end.x)
	)

	follow_camera.limit_bottom = int(
		ceil(room_end.y)
	)

	follow_camera.limit_smoothed = false

	player.add_child(follow_camera)
	follow_camera.make_current()

func toggle_chemistry_developer_mode() -> void:
	GameState.toggle_developer_mode()

	if GameState.developer_mode:
		camera_target_zoom = (
			CHEMISTRY_DEVELOPER_CAMERA_ZOOM
		)
	else:
		camera_target_zoom = (
			CHEMISTRY_GAMEPLAY_CAMERA_ZOOM
		)

func update_camera_zoom(
	delta: float
) -> void:
	if follow_camera == null:
		return

	var weight: float = clampf(
		delta * CAMERA_ZOOM_CHANGE_SPEED,
		0.0,
		1.0
	)

	follow_camera.zoom = (
		follow_camera.zoom.lerp(
			camera_target_zoom,
			weight
		)
	)
func get_room_world_bounds() -> Rect2:
	if room_background == null:
		return Rect2(
			Vector2.ZERO,
			Vector2(
				ROOM_WIDTH,
				ROOM_HEIGHT
			)
		)

	if room_background.texture == null:
		return Rect2(
			Vector2.ZERO,
			Vector2(
				ROOM_WIDTH,
				ROOM_HEIGHT
			)
		)

	var texture_size: Vector2 = (
		room_background.texture.get_size()
	)

	var absolute_scale: Vector2 = Vector2(
		absf(room_background.scale.x),
		absf(room_background.scale.y)
	)

	var displayed_size: Vector2 = Vector2(
		texture_size.x * absolute_scale.x,
		texture_size.y * absolute_scale.y
	)

	var top_left: Vector2 = (
		room_background.global_position
	)

	if room_background.centered:
		top_left -= displayed_size / 2.0

	return Rect2(
		top_left,
		displayed_size
	)
