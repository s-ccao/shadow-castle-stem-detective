extends Node2D

## Final Room — 最终推理室/奥术实验室（用户提供 c4ccbf91 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/final_room_arcane.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "final_deduction_room"
const RETURN_SPAWN_ID: String = "final_room_door"
const CASE_CLOSED_SCREEN_PATH: String = "res://assets/ui/screens/case_closed.png"
const GAME_OVER_UI_SCENE_PATH: String = "res://scenes/ui/game_over_ui.tscn"
const FINAL_ARCHIVE_DOCUMENT_UI_PATH: String = "res://assets/props/FinalRoom/final_archive_document.png"
const FINAL_CASE_BOARD_SCENE: PackedScene = preload("res://scenes/ui/final_case_board.tscn")

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const INTERACT_RADIUS: float = 90.0

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)
const CAMERA_ZOOM_SPEED: float = 7.0

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "mrs_lin_body",
		"label": "Mrs. Lin's body",
		"position": Vector2(724.0, 780.0),
		"message": "Mrs. Lin lies beside the analysis table. She is already dead. Her notebook is still held against her coat. A torn violet cuff fragment with a copper-thread cross-stitch remains in her hand."
	},
	{
		"name": "mrs_lin_notebook",
		"label": "Mrs. Lin's notebook",
		"position": Vector2(850.0, 780.0),
		"message": "The final pages do not name a culprit. They ask you to connect the staged Chemistry scene, the Greenhouse maintenance route, the deliberate blackout, the Dining timeline, and the personalized glove match before choosing a suspect."
	},
	{
		"name": "deduction_platform",
		"label": "the Ashford analysis table",
		"position": Vector2(724.0, 560.0),
		"message": "The circular Ashford analysis table has five radial evidence links: staged scene, maintenance route, deliberate blackout, Dining opportunity, and the personalized glove match. It is waiting for the final deduction.",
	},
	{
		"name": "vault_cabinet",
		"label": "the vault cabinet",
		"position": Vector2(724.0, 110.0),
		"message": "The Vault Door's central violet core is connected to the Master Archive route. Under Vision, its frozen symbols record the maintenance circuit used to reach Mrs. Lin's final room."
	},
	{
		"name": "knowledge_engine",
		"label": "the Knowledge Engine",
		"position": Vector2(1150.0, 480.0),
		"message": "The Knowledge Engine's brass orrery links the violet circuit to the Master Archive. Its central sphere remains sealed until the Vault symbols confirm the route."
	}
]

const AUTHORED_INTERACTION_NODE_PATHS: Dictionary = {
	"mrs_lin_body": NodePath("MrsLinBody"),
	"mrs_lin_notebook": NodePath("NotebookVisual"),
	"deduction_platform": NodePath("FinalAnalysisBoardVisual"),
	"knowledge_engine": NodePath("KnowledgeEngineVisual"),
	"vault_cabinet": NodePath("VaultDoorVisual"),
}

const AUTHORED_INTERACTION_FRONT_OFFSETS: Dictionary = {
	"mrs_lin_body": Vector2(0.0, 92.0),
	"mrs_lin_notebook": Vector2(0.0, 58.0),
	"deduction_platform": Vector2(0.0, 210.0),
	"knowledge_engine": Vector2(0.0, 190.0),
	"vault_cabinet": Vector2(0.0, 140.0),
}

const AUTHORED_OCCLUSION_NODE_PATHS: Array[NodePath] = [
	NodePath("MrsLinBody"),
	NodePath("NotebookVisual"),
	NodePath("FinalAnalysisBoardVisual"),
	NodePath("KnowledgeEngineVisual"),
	NodePath("VaultDoorVisual"),
]
const OCCLUSION_FRONT_Z: int = 18
const OCCLUSION_BACK_Z: int = -18

const FINAL_DEDUCTION_STEPS: Array[Dictionary] = [
	{
		"question": "Was the Chemistry Room attack scene genuine?",
		"options": ["No — the red stain was staged", "Yes — it proves an attack", "There is not enough evidence"],
		"correct": 0,
	},
	{
		"question": "What connects the Greenhouse to the hidden route?",
		"options": ["Pollen on maintenance equipment", "The gardener's uniform alone", "The color of the flowers"],
		"correct": 0,
	},
	{
		"question": "What caused the castle blackout?",
		"options": ["A storm", "Old wiring", "A deliberate short circuit"],
		"correct": 2,
	},
	{
		"question": "What does the Dining Hall timeline prove?",
		"options": ["The stopped clock, fresh ash, and meal state show the midnight timing was manipulated and someone used the missing interval", "The feast ended exactly at midnight", "The fireplace proves the Gardener was present"],
		"correct": 0,
	},
	{
		"question": "Who had the knowledge, tools, access, and route required to connect all three events?",
		"options": ["Butler", "Gardener", "Mechanic"],
		"correct": 2,
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
var deduction_layer: CanvasLayer
var deduction_panel: Panel
var deduction_title: Label
var deduction_question: Label
var deduction_status: Label
var deduction_options: VBoxContainer
var deduction_token_row: HBoxContainer
var deduction_relation_row: HBoxContainer
var deduction_connection_button: Button
var deduction_token_buttons: Array[TextureButton] = []
var deduction_token_order: Array[int] = []
var deduction_step_index: int = 0
var deduction_open: bool = false
var final_case_board: FinalCaseBoard
var interact_label: Label
var interaction_hint_panel: Panel
var self_dialogue_layer: CanvasLayer
var self_dialogue_panel: Panel
var self_dialogue_text: Label
var ui_layer: CanvasLayer
var interaction_focus: WorldInteractionFocus
var inspection_overlay_layer: CanvasLayer
var inspection_overlay_panel: Panel
var inspection_overlay_title: Label
var inspection_overlay_image: TextureRect
var inspection_overlay_description: Label
var inspection_overlay_close_button: Button
var inspection_overlay_action_button: Button
var _inspection_overlay_action: Callable
var ending_layer: CanvasLayer
var ending_screen_root: Control
var archive_reader_layer: CanvasLayer
var archive_reader_root: Control
var _last_debug_mouse_position := Vector2(-100000, -100000)


func _ready() -> void:
	GameState.current_room_id = ROOM_ID
	# 单独点击 Final Room 场景调试时，自动预置完整前置状态；正式流程不触发。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.sync_knowledge_notes_from_flags()
	GameState.set_room_visited(ROOM_ID)
	player = $Worldsort/player
	player.position = PLAYER_SPAWN_POSITION
	player.set_physics_process(true)
	_sync_authored_interaction_positions()
	create_room_ui()
	create_self_dialogue_ui()
	_create_final_case_board()
	create_inspection_overlay()
	create_ending_overlay()
	create_final_archive_reader_ui()
	create_follow_camera()
	create_interaction_focus()
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID


func _create_final_case_board() -> void:
	final_case_board = FINAL_CASE_BOARD_SCENE.instantiate() as FinalCaseBoard
	final_case_board.ordinary_case_closed.connect(_on_ordinary_case_closed)
	final_case_board.true_case_closed.connect(_on_true_case_closed)
	final_case_board.case_closed.connect(_on_final_case_board_closed)
	add_child(final_case_board)


func _on_final_case_board_closed() -> void:
	deduction_open = false
	room_input_enabled = true
	get_tree().paused = false
	if player != null:
		player.set_physics_process(true)


func _on_ordinary_case_closed() -> void:
	if NoteHud != null and not NoteHud.has_clue("ordinary_case_butler_note"):
		NoteHud.add_clue("ordinary_case_butler_note", {
			"title": "Ordinary Case Closure — The Butler",
			"content": "The five conclusions identify the Butler as the executor: he had the service access, reached the analysis table, and operated the prepared apparatus. Yet the glove evidence only proves contact with the maintenance chain. The original instruction remains unaccounted for.",
			"category": "investigation",
		})
	_show_ending_overlay()


func _on_true_case_closed() -> void:
	if NoteHud != null and not NoteHud.has_clue("true_case_mechanic_note"):
		NoteHud.add_clue("true_case_mechanic_note", {
			"title": "True Case Closure — The Mechanic",
			"content": "The Butler operated the apparatus under a forged emergency order. The three sealed archives reveal the author: the Mechanic exploited the Butler's pressure, forged the Mechanical Office instruction, and silenced Dr. Lin after she refused him funding and access to the Knowledge Engine plans.",
			"category": "investigation",
		})
	_show_true_ending_overlay()


func _sync_authored_interaction_positions() -> void:
	for item: Dictionary in INTERACT_ITEMS:
		var item_name: String = str(item["name"])
		if not AUTHORED_INTERACTION_NODE_PATHS.has(item_name):
			continue
		var authored_node: Node2D = get_node_or_null(
			AUTHORED_INTERACTION_NODE_PATHS[item_name]
		) as Node2D
		if authored_node == null:
			push_warning("Final Room authored interaction node missing: " + item_name)
			continue
		# 只读取 Inspector 中的场景位置；交互点在可站立的物件前方，不改 Sprite2D。
		var front_offset: Vector2 = AUTHORED_INTERACTION_FRONT_OFFSETS.get(
			item_name,
			Vector2.ZERO
		) as Vector2
		item["position"] = authored_node.global_position + front_offset


func _process(delta: float) -> void:
	_update_camera_zoom(delta)
	_update_authored_prop_occlusion_layers()
	if room_input_enabled:
		update_interaction_prompt()
		update_interaction_focus()
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


func _update_camera_zoom(delta: float) -> void:
	if follow_camera == null:
		return
	camera_target_zoom = GameState.get_room_camera_zoom(
		GAMEPLAY_CAMERA_ZOOM,
		DEVELOPER_CAMERA_ZOOM
	)
	var interpolation_weight: float = clampf(
		delta * CAMERA_ZOOM_SPEED,
		0.0,
		1.0
	)
	follow_camera.zoom = follow_camera.zoom.lerp(
		camera_target_zoom,
		interpolation_weight
	)


func _update_authored_prop_occlusion_layers() -> void:
	if player == null:
		return
	for node_path: NodePath in AUTHORED_OCCLUSION_NODE_PATHS:
		var authored_node: Node2D = get_node_or_null(node_path) as Node2D
		if authored_node == null:
			continue
		authored_node.z_as_relative = false
		authored_node.z_index = (
			OCCLUSION_FRONT_Z
			if player.global_position.y < authored_node.global_position.y
			else OCCLUSION_BACK_Z
		)


func create_room_ui() -> void:
	# UI 独立图层：交互提示跟随交互物在世界中的位置投影到屏幕，
	# 相机移动时提示始终贴在物品旁边（跟随玩家视角）。
	ui_layer = CanvasLayer.new()
	ui_layer.name = "FinalRoomUI"
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


func create_deduction_ui() -> void:
	deduction_layer = CanvasLayer.new()
	deduction_layer.name = "FinalDeductionUI"
	deduction_layer.layer = 60
	deduction_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(deduction_layer)
	deduction_panel = Panel.new()
	deduction_panel.name = "FinalDeductionPanel"
	deduction_panel.position = Vector2(120, 82)
	deduction_panel.size = Vector2(784, 604)
	deduction_panel.visible = false
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.02, 0.04, 0.97)
	panel_style.border_color = Color(0.72, 0.55, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	deduction_panel.add_theme_stylebox_override("panel", panel_style)
	deduction_layer.add_child(deduction_panel)

	deduction_title = Label.new()
	deduction_title.position = Vector2(28, 22)
	deduction_title.size = Vector2(728, 42)
	deduction_title.text = "FINAL DEDUCTION"
	deduction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction_title.add_theme_font_size_override("font_size", 26)
	deduction_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38, 1.0))
	deduction_panel.add_child(deduction_title)

	deduction_question = Label.new()
	deduction_question.position = Vector2(42, 92)
	deduction_question.size = Vector2(700, 110)
	deduction_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deduction_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deduction_question.add_theme_font_size_override("font_size", 20)
	deduction_question.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82, 1.0))
	deduction_panel.add_child(deduction_question)

	deduction_status = Label.new()
	deduction_status.position = Vector2(42, 210)
	deduction_status.size = Vector2(700, 50)
	deduction_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deduction_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction_status.add_theme_font_size_override("font_size", 15)
	deduction_status.add_theme_color_override("font_color", Color(0.76, 0.68, 0.50, 1.0))
	deduction_panel.add_child(deduction_status)

	deduction_token_row = HBoxContainer.new()
	deduction_token_row.name = "DeductionTokenRow"
	deduction_token_row.position = Vector2(62, 264)
	deduction_token_row.size = Vector2(660, 122)
	deduction_token_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deduction_token_row.add_theme_constant_override("separation", 8)
	deduction_token_row.visible = false
	deduction_panel.add_child(deduction_token_row)
	var token_names: Array[String] = ["Evidence", "Person", "Location", "Timeline"]
	for token_index: int in range(token_names.size()):
		if token_index > 0:
			var arrow_label: Label = Label.new()
			arrow_label.name = "DeductionArrow_%d" % token_index
			arrow_label.custom_minimum_size = Vector2(22, 104)
			arrow_label.text = "→"
			arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow_label.add_theme_font_size_override("font_size", 20)
			arrow_label.add_theme_color_override("font_color", Color(0.78, 0.60, 0.25, 1.0))
			arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deduction_token_row.add_child(arrow_label)
		var token_button: TextureButton = TextureButton.new()
		token_button.name = "DeductionToken_%s" % token_names[token_index]
		token_button.custom_minimum_size = Vector2(142, 108)
		token_button.ignore_texture_size = true
		token_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		token_button.texture_normal = _make_deduction_token_texture(token_index)
		token_button.tooltip_text = token_names[token_index]
		token_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		token_button.pressed.connect(func() -> void: _select_deduction_token(token_index))
		var token_caption: Label = Label.new()
		token_caption.name = "TokenCaption"
		token_caption.position = Vector2(8, 76)
		token_caption.size = Vector2(126, 26)
		token_caption.text = token_names[token_index]
		token_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		token_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		token_caption.clip_text = true
		token_caption.add_theme_font_size_override("font_size", 12)
		token_caption.add_theme_color_override("font_color", Color(0.98, 0.84, 0.48, 1.0))
		token_caption.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 1.0))
		token_caption.add_theme_constant_override("outline_size", 3)
		token_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token_button.add_child(token_caption)
		deduction_token_row.add_child(token_button)
		deduction_token_buttons.append(token_button)

	deduction_relation_row = HBoxContainer.new()
	deduction_relation_row.name = "DeductionRelationState"
	deduction_relation_row.position = Vector2(120, 518)
	deduction_relation_row.size = Vector2(544, 52)
	deduction_relation_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deduction_relation_row.add_theme_constant_override("separation", 8)
	deduction_relation_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deduction_relation_row.visible = false
	deduction_panel.add_child(deduction_relation_row)
	for relation_index:int in range(4, 8):
		var relation_visual: TextureRect = TextureRect.new()
		relation_visual.name = ["InactiveConnector", "ActiveConnector", "LinkingSegment", "FinalConclusion"][relation_index - 4]
		relation_visual.custom_minimum_size = Vector2(58, 46)
		relation_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		relation_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		relation_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relation_visual.texture = _make_deduction_token_texture(relation_index)
		relation_visual.visible = relation_index == 4
		deduction_relation_row.add_child(relation_visual)

	deduction_connection_button = Button.new()
	deduction_connection_button.name = "ActivateDeductionConnectionButton"
	deduction_connection_button.text = "ACTIVATE CONNECTION: Evidence → Person → Location → Timeline"
	deduction_connection_button.position = Vector2(72, 402)
	deduction_connection_button.size = Vector2(640, 48)
	deduction_connection_button.add_theme_font_size_override("font_size", 12)
	deduction_connection_button.disabled = true
	deduction_connection_button.visible = false
	deduction_connection_button.pressed.connect(_complete_deduction_connection)
	deduction_panel.add_child(deduction_connection_button)

	deduction_options = VBoxContainer.new()
	deduction_options.name = "DeductionOptions"
	deduction_options.position = Vector2(62, 286)
	deduction_options.size = Vector2(660, 240)
	deduction_options.add_theme_constant_override("separation", 10)
	deduction_panel.add_child(deduction_options)


func create_inspection_overlay() -> void:
	inspection_overlay_layer = CanvasLayer.new()
	inspection_overlay_layer.name = "FinalRoomInspectionOverlay"
	inspection_overlay_layer.layer = 55
	inspection_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inspection_overlay_layer)

	inspection_overlay_panel = Panel.new()
	inspection_overlay_panel.name = "FinalRoomInspectionPanel"
	inspection_overlay_panel.position = Vector2(64, 32)
	inspection_overlay_panel.size = Vector2(896, 704)
	inspection_overlay_panel.visible = false
	inspection_overlay_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.012, 0.02, 0.985)
	panel_style.border_color = Color(0.78, 0.60, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	inspection_overlay_panel.add_theme_stylebox_override("panel", panel_style)
	inspection_overlay_layer.add_child(inspection_overlay_panel)

	inspection_overlay_title = Label.new()
	inspection_overlay_title.position = Vector2(32, 18)
	inspection_overlay_title.size = Vector2(832, 38)
	inspection_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspection_overlay_title.add_theme_font_size_override("font_size", 24)
	inspection_overlay_title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.40, 1.0))
	inspection_overlay_panel.add_child(inspection_overlay_title)

	inspection_overlay_image = TextureRect.new()
	inspection_overlay_image.name = "InspectionOverlayImage"
	inspection_overlay_image.position = Vector2(150, 70)
	inspection_overlay_image.size = Vector2(596, 520)
	inspection_overlay_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspection_overlay_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspection_overlay_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspection_overlay_panel.add_child(inspection_overlay_image)

	inspection_overlay_description = Label.new()
	inspection_overlay_description.position = Vector2(58, 596)
	inspection_overlay_description.size = Vector2(780, 42)
	inspection_overlay_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_overlay_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspection_overlay_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inspection_overlay_description.add_theme_font_size_override("font_size", 14)
	inspection_overlay_description.add_theme_color_override("font_color", Color(0.78, 0.70, 0.52, 1.0))
	inspection_overlay_panel.add_child(inspection_overlay_description)

	inspection_overlay_close_button = Button.new()
	inspection_overlay_close_button.name = "CloseInspectionOverlayButton"
	inspection_overlay_close_button.text = "Close"
	inspection_overlay_close_button.position = Vector2(704, 650)
	inspection_overlay_close_button.size = Vector2(136, 38)
	inspection_overlay_close_button.add_theme_font_size_override("font_size", 15)
	inspection_overlay_close_button.pressed.connect(_close_inspection_overlay)
	inspection_overlay_panel.add_child(inspection_overlay_close_button)

	inspection_overlay_action_button = Button.new()
	inspection_overlay_action_button.name = "InspectionOverlayActionButton"
	inspection_overlay_action_button.text = "Open Final Deduction"
	inspection_overlay_action_button.position = Vector2(500, 650)
	inspection_overlay_action_button.size = Vector2(188, 38)
	inspection_overlay_action_button.add_theme_font_size_override("font_size", 15)
	inspection_overlay_action_button.visible = false
	inspection_overlay_action_button.pressed.connect(_run_inspection_overlay_action)
	inspection_overlay_panel.add_child(inspection_overlay_action_button)


func create_ending_overlay() -> void:
	ending_layer = CanvasLayer.new()
	ending_layer.name = "CaseClosedEndingUI"
	ending_layer.layer = 70
	ending_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ending_layer)

	var game_over_scene: PackedScene = load(GAME_OVER_UI_SCENE_PATH) as PackedScene
	if game_over_scene == null:
		push_error("Game Over UI scene could not be loaded: " + GAME_OVER_UI_SCENE_PATH)
		return
	ending_screen_root = game_over_scene.instantiate() as Control
	if ending_screen_root == null:
		push_error("Game Over UI scene root must be a Control.")
		return
	ending_screen_root.name = "GameOverUI"
	ending_screen_root.visible = false
	ending_layer.add_child(ending_screen_root)
	ending_screen_root.connect("continue_requested", Callable(self, "_continue_from_ending_screen"))
	ending_screen_root.connect("view_conclusion_requested", Callable(self, "_view_ending_conclusion"))
	ending_screen_root.connect("main_menu_requested", Callable(self, "_return_to_main_menu_from_ending"))


func create_final_archive_reader_ui() -> void:
	archive_reader_layer = CanvasLayer.new()
	archive_reader_layer.name = "FinalArchiveDocumentUI"
	archive_reader_layer.layer = 80
	archive_reader_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(archive_reader_layer)

	archive_reader_root = Control.new()
	archive_reader_root.name = "FinalArchiveDocumentReader"
	archive_reader_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	archive_reader_root.visible = false
	archive_reader_layer.add_child(archive_reader_root)

	var background: ColorRect = ColorRect.new()
	background.name = "ArchiveReaderBackground"
	background.color = Color(0.008, 0.006, 0.012, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_reader_root.add_child(background)

	var title: Label = Label.new()
	title.name = "ArchiveReaderTitle"
	title.text = "FINAL ARCHIVE DOCUMENT — LORD ASHFORD RECORD"
	title.position = Vector2(80, 22)
	title.size = Vector2(864, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.40, 1.0))
	archive_reader_root.add_child(title)

	var document: TextureRect = TextureRect.new()
	document.name = "FinalArchiveDocumentArtwork"
	document.texture = load(FINAL_ARCHIVE_DOCUMENT_UI_PATH) as Texture2D
	document.position = Vector2(210, 72)
	document.size = Vector2(604, 610)
	document.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	document.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	document.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_reader_root.add_child(document)

	var description: Label = Label.new()
	description.name = "ArchiveReaderDescription"
	description.text = "A post-case record of Ashford's research network, the Knowledge Engine and the hidden archive route."
	description.position = Vector2(160, 684)
	description.size = Vector2(704, 28)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.78, 0.70, 0.52, 1.0))
	archive_reader_root.add_child(description)

	var close_button: Button = Button.new()
	close_button.name = "CloseArchiveReaderButton"
	close_button.text = "Close"
	close_button.position = Vector2(690, 720)
	close_button.size = Vector2(130, 32)
	close_button.pressed.connect(_close_final_archive_document_ui)
	archive_reader_root.add_child(close_button)

	var menu_button: Button = Button.new()
	menu_button.name = "ArchiveReaderMainMenuButton"
	menu_button.text = "Main Menu"
	menu_button.position = Vector2(500, 720)
	menu_button.size = Vector2(176, 32)
	menu_button.pressed.connect(_archive_reader_to_main_menu)
	archive_reader_root.add_child(menu_button)


func _show_final_archive_document_ui() -> void:
	GameState.set_story_flag("final_archive_document_read")
	GameState.add_evidence("final_archive_document")
	if NoteHud != null and not NoteHud.has_clue("final_archive_document_note"):
		NoteHud.add_clue("final_archive_document_note", {
			"title": "Final Archive Document — Lord Ashford Record",
			"content": "The sealed record describes Ashford's research wings as a verification network: Matter, Life, Energy and Access. It names the Knowledge Engine as the castle's central research system and records unauthorized copies of its engineering diagrams and irregular maintenance-level archive requests. The document identifies the target and the route, but it does not name the person responsible.",
			"category": "lore",
		})
	ending_screen_root.visible = false
	if deduction_panel != null:
		deduction_panel.visible = false
	archive_reader_root.visible = true
	room_input_enabled = false
	if player != null:
		player.set_physics_process(false)
	get_tree().paused = true


func _close_final_archive_document_ui() -> void:
	archive_reader_root.visible = false
	if deduction_panel != null:
		deduction_panel.visible = true
	room_input_enabled = false
	get_tree().paused = true


func _archive_reader_to_main_menu() -> void:
	archive_reader_root.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _show_ending_overlay() -> void:
	if ending_screen_root == null:
		return
	if ending_screen_root.has_method("show_ordinary_case"):
		ending_screen_root.call("show_ordinary_case")
	ending_screen_root.visible = true
	room_input_enabled = false
	if player != null:
		player.set_physics_process(false)
	get_tree().paused = true


func _show_true_ending_overlay() -> void:
	if ending_screen_root == null:
		return
	if ending_screen_root.has_method("show_true_case"):
		ending_screen_root.call("show_true_case")
	ending_screen_root.visible = true
	room_input_enabled = false
	if player != null:
		player.set_physics_process(false)
	get_tree().paused = true


func _continue_from_ending_screen() -> void:
	ending_screen_root.visible = false
	if final_case_board != null:
		final_case_board.show_sealed_archive_prompt()
	room_input_enabled = false
	get_tree().paused = true


func _view_ending_conclusion() -> void:
	ending_screen_root.visible = false
	if final_case_board != null:
		final_case_board.open_case()
	room_input_enabled = false
	get_tree().paused = true


func _return_to_main_menu_from_ending() -> void:
	ending_screen_root.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _make_deduction_token_texture(token_index: int) -> AtlasTexture:
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = load(
		"res://assets/props/FinalRoom/deduction_connection_tokens.png"
	) as Texture2D
	var cell_size := Vector2(313.5, 627.0)
	var cell_position := Vector2(
		float(token_index % 4) * cell_size.x,
		float(token_index / 4) * cell_size.y
	)
	atlas_texture.region = Rect2(cell_position, cell_size)
	return atlas_texture


func _select_deduction_token(token_index: int) -> void:
	if deduction_step_index != 4 or deduction_token_row == null:
		return
	var expected_token_index: int = deduction_token_order.size()
	if token_index != expected_token_index:
		deduction_token_order.clear()
		deduction_connection_button.disabled = true
		_refresh_deduction_token_visuals()
		deduction_status.text = "The connection reset. Start with Evidence, then Person, Location and Timeline."
		return
	deduction_token_order.append(token_index)
	_refresh_deduction_token_visuals()
	if deduction_token_order.size() == 4:
		deduction_connection_button.disabled = false
		deduction_status.text = "Connection ready: Evidence → Person → Location → Timeline. Activate it to compare suspects."
	else:
		deduction_status.text = "Connection %d/4: choose %s next." % [deduction_token_order.size(), ["Person", "Location", "Timeline"][deduction_token_order.size() - 1]]


func _refresh_deduction_token_visuals() -> void:
	for token_index: int in range(deduction_token_buttons.size()):
		var token_button: TextureButton = deduction_token_buttons[token_index]
		if deduction_token_order.has(token_index):
			token_button.modulate = Color(1.0, 0.88, 0.52, 1.0)
		else:
			token_button.modulate = Color(0.68, 0.68, 0.68, 1.0)


func _complete_deduction_connection() -> void:
	if deduction_token_order != [0, 1, 2, 3]:
		return
	GameState.set_story_flag("deduction_connection_completed")
	if NoteHud != null and not NoteHud.has_clue("deduction_connection_note"):
		NoteHud.add_clue("deduction_connection_note", {
			"title": "Final Deduction Connection",
			"content": "The final table connects Evidence to Person, Person to Location, and Location to Timeline. The chain identifies the Mechanic's access, route and opportunity before the suspect comparison.",
			"category": "investigation",
		})
	deduction_token_row.visible = false
	deduction_connection_button.visible = false
	deduction_options.visible = true
	_show_deduction_step()


func _set_deduction_relation_state(completed: bool) -> void:
	if deduction_relation_row == null:
		return
	deduction_relation_row.visible = true
	deduction_relation_row.get_child(0).visible = not completed
	deduction_relation_row.get_child(1).visible = completed
	deduction_relation_row.get_child(2).visible = true
	deduction_relation_row.get_child(3).visible = completed


func _show_final_visual(
	title: String,
	texture_path: String,
	description: String,
	show_deduction_action: bool = false
) -> void:
	if inspection_overlay_panel == null:
		return
	inspection_overlay_title.text = title
	inspection_overlay_image.texture = load(texture_path) as Texture2D
	inspection_overlay_description.text = description
	inspection_overlay_action_button.visible = show_deduction_action
	_inspection_overlay_action = Callable(self, "_open_deduction_after_overlay") if show_deduction_action else Callable()
	inspection_overlay_panel.visible = true
	room_input_enabled = false
	if player != null:
		player.set_physics_process(false)
	get_tree().paused = true


func _close_inspection_overlay() -> void:
	if inspection_overlay_panel != null:
		inspection_overlay_panel.visible = false
	get_tree().paused = false
	room_input_enabled = true
	if player != null:
		player.set_physics_process(true)


func _run_inspection_overlay_action() -> void:
	if _inspection_overlay_action.is_valid():
		_inspection_overlay_action.call()


func _open_deduction_after_overlay() -> void:
	_close_inspection_overlay()
	show_final_deduction()


func _close_deduction_panel() -> void:
	if final_case_board != null and final_case_board.visible:
		final_case_board.close_case()
		return
	deduction_open = false
	if deduction_panel != null:
		deduction_panel.visible = false
	room_input_enabled = true
	get_tree().paused = false


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
			interaction_focus.set_focus(
				item["position"] as Vector2,
				str(item["label"]),
				true
			)
			return


## 把交互提示面板投影到交互物上方（世界坐标 → 屏幕坐标，跟随玩家视角）。
func _update_hint_screen_position(world_pos: Vector2) -> void:
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
		+ Vector2(0.0, -85.0)
	)


func create_self_dialogue_ui() -> void:
	self_dialogue_layer = CanvasLayer.new()
	self_dialogue_layer.name = "SelfDialogueLayer"
	self_dialogue_layer.layer = 35
	self_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(self_dialogue_layer)

	self_dialogue_panel = Panel.new()
	self_dialogue_panel.name = "SelfDialoguePanel"
	self_dialogue_panel.position = Vector2(72.0, 570.0)
	self_dialogue_panel.size = Vector2(880.0, 158.0)
	self_dialogue_panel.visible = false
	self_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.018, 0.025, 0.97)
	panel_style.border_color = Color(0.78, 0.60, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	self_dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	self_dialogue_layer.add_child(self_dialogue_panel)

	var speaker_label: Label = Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.position = Vector2(24.0, 12.0)
	speaker_label.size = Vector2(150.0, 26.0)
	speaker_label.text = "You"
	speaker_label.add_theme_font_size_override("font_size", 16)
	speaker_label.add_theme_color_override("font_color", Color(0.98, 0.78, 0.38, 1.0))
	speaker_label.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 1.0))
	speaker_label.add_theme_constant_override("outline_size", 3)
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_dialogue_panel.add_child(speaker_label)

	self_dialogue_text = Label.new()
	self_dialogue_text.name = "SelfDialogueText"
	self_dialogue_text.position = Vector2(24.0, 43.0)
	self_dialogue_text.size = Vector2(790.0, 78.0)
	self_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self_dialogue_text.clip_text = true
	self_dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	self_dialogue_text.add_theme_font_size_override("font_size", 15)
	self_dialogue_text.add_theme_color_override("font_color", Color(0.94, 0.88, 0.70, 1.0))
	self_dialogue_text.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 1.0))
	self_dialogue_text.add_theme_constant_override("outline_size", 2)
	self_dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_dialogue_panel.add_child(self_dialogue_text)

	var continue_button: Button = Button.new()
	continue_button.name = "ContinueSelfDialogueButton"
	continue_button.position = Vector2(700.0, 116.0)
	continue_button.size = Vector2(150.0, 30.0)
	continue_button.text = "Continue"
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.add_theme_font_size_override("font_size", 13)
	continue_button.add_theme_color_override("font_color", Color(0.98, 0.78, 0.38, 1.0))
	continue_button.pressed.connect(_close_self_dialogue)
	self_dialogue_panel.add_child(continue_button)


func _show_self_dialogue(message: String) -> void:
	if self_dialogue_panel == null or self_dialogue_text == null:
		return
	self_dialogue_text.text = message
	self_dialogue_panel.visible = true
	interaction_hint_panel.visible = false
	room_input_enabled = false
	if player != null:
		player.set_physics_process(false)
	get_tree().paused = true


func _close_self_dialogue() -> void:
	if self_dialogue_panel == null:
		return
	self_dialogue_panel.visible = false
	get_tree().paused = false
	room_input_enabled = true
	if player != null:
		player.set_physics_process(true)


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
		var distance: float = player.global_position.distance_to(
			item["position"] as Vector2
		)
		if distance <= INTERACT_RADIUS:
			current_interaction = str(item["name"])
			if item_message.is_empty():
				interact_label.text = (
					"Press E to inspect "
					+ str(item["label"])
				)
			else:
				interact_label.text = item_message
			interaction_hint_panel.visible = true
			_update_hint_screen_position(item["position"] as Vector2)
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
			item_message = str(item["message"])
			var item_name: String = str(item["name"])
			if item_name == "mrs_lin_body":
				_inspect_mrs_lin_body()
				return
			if item_name == "mrs_lin_notebook":
				_inspect_mrs_lin_notebook()
				return
			if item_name == "deduction_platform":
				_show_final_visual(
					"ASHFORD ANALYSIS TABLE",
					"res://assets/props/FinalRoom/final_analysis_board.png",
					"The circular Ashford verification table holds five brass slots. Build each claim from the raw records first; a glove can prove contact, but not yet the full command chain.",
					true
				)
				return
			if item_name == "knowledge_engine":
				_inspect_knowledge_engine()
				return
			# 真正制作并使用过 Vision Potion 后，即使定时效果在追逐中结束，
			# 本章节仍保留增强观察能力；Chemistry 样品演示不会设置 vision_mastered。
			if item_name == "vault_cabinet":
				var can_read_hidden_symbols: bool = (
					GameState.is_potion_active("vision")
					or GameState.has_story_flag("vision_mastered")
				)
				if can_read_hidden_symbols:
					item_message = (
						"The cabinet's dial glows under the wide lens of the Vision Potion. Between the two frozen symbols, a third symbol appears: a violet circuit mark — the same current that runs through the Circuit Room. The dial is not a lock; it is a recorder of the culprit's route."
					)
					GameState.add_evidence("vault_vision_symbols")
				else:
					item_message = (
						str(item["message"])
						+ "\n\nThe dial is too dim to read clearly. A Vision Potion might reveal more."
					)
				_show_final_visual(
					"ASHFORD VAULT",
					"res://assets/props/FinalRoom/final_vault_door.png",
					item_message
				)
				return


func _inspect_mrs_lin_body() -> void:
	if GameState.has_story_flag("mrs_lin_found_dead"):
		if not GameState.has_evidence("mrs_lin_violet_fiber"):
			GameState.add_evidence("mrs_lin_violet_fiber")
		if not GameState.has_evidence("mrs_lin_glove_fragment"):
			GameState.add_evidence("mrs_lin_glove_fragment")
		item_message = "You have already recorded the scene. Mrs. Lin is dead, and her notebook is the only unfinished part of her investigation. A torn violet cuff fragment with a copper-thread cross-stitch remains in her hand."
		_show_self_dialogue(item_message)
		return
	GameState.set_story_flag("mrs_lin_found_dead")
	GameState.add_evidence("mrs_lin_body")
	GameState.add_evidence("mrs_lin_violet_fiber")
	GameState.add_evidence("mrs_lin_glove_fragment")
	if NoteHud != null:
		NoteHud.add_clue("mrs_lin_body_note", {
			"title": "Mrs. Lin Found in the Final Room",
			"content": "Mrs. Lin is dead beside the Ashford analysis table. There is no sign that she reached the final archive. Her notebook is still closed against her coat. A torn violet insulating fiber and a fragment of glove cuff are caught in her hand; the cuff carries a distinctive copper-thread cross-stitch that matches the repair described in the Circuit Room maintenance record.",
			"category": "investigation",
		})
	item_message = "Mrs. Lin is dead. A torn violet insulating fiber and glove cuff fragment are caught in her hand. The cuff carries the copper-thread repair pattern documented in the Circuit Room and echoed in the Service Area. Her last investigation ends here, but her notebook may still contain the reasoning she could not finish."
	_show_self_dialogue(item_message)


func _inspect_mrs_lin_notebook() -> void:
	if not GameState.has_story_flag("mrs_lin_found_dead"):
		item_message = "The notebook is held against a body in the dark. You need to examine the person beside the analysis table first."
		_show_self_dialogue(item_message)
		return
	if not GameState.has_story_flag("mrs_lin_notebook_found"):
		GameState.set_story_flag("mrs_lin_notebook_found")
		GameState.add_evidence("mrs_lin_notebook")
		if NoteHud != null:
			NoteHud.add_clue("mrs_lin_final_notebook", {
				"title": "Mrs. Lin's Final Notebook",
				"content": "The final pages do not name a culprit. They organize five questions: was the Chemistry scene staged, what links the Greenhouse to the service route, what caused the blackout, what does the Dining timeline prove, and who had the knowledge, tools, access, and route to connect them? The violet fiber and torn cuff in Mrs. Lin's hand are the final bridge to her last struggle.\n\nIf you are reading this, then I did not make it back. Do not finish this investigation for me. Finish it properly. Check every assumption. Connect the evidence. And do not guess.",
				"category": "investigation",
			})
	item_message = "Mrs. Lin's notebook turns the case into a final deduction: staged scene, maintenance pollen, deliberate blackout, manipulated timeline, violet fiber, and the person who could connect them."
	_show_self_dialogue(item_message)


func _inspect_knowledge_engine() -> void:
	if GameState.has_evidence("vault_vision_symbols"):
		GameState.set_story_flag("master_archive_route_found")
		if NoteHud != null and not NoteHud.has_clue("master_archive_route"):
			GameState.add_evidence("master_archive_route")
			NoteHud.add_clue("master_archive_route", {
				"title": "Knowledge Engine Route",
				"content": "The violet symbol in the vault matches the Knowledge Engine's maintenance circuit. The archive was the target, and the service route was the method.",
				"category": "investigation",
			})
		item_message = "The Knowledge Engine recognizes the violet circuit symbol. The hidden route was built to reach the Master Archive."
	else:
		item_message = "The Knowledge Engine is sealed behind a dark archive shell. A hidden symbol may be visible only after using the Vision Potion in the vault."
	interact_label.text = item_message
	_show_final_visual(
		"KNOWLEDGE ENGINE",
		"res://assets/props/FinalRoom/knowledge_engine_orrery.png",
		item_message
	)


func _required_final_evidence() -> Array[String]:
	return [
		"mrs_lin_body",
		"fake_red_stain",
		"greenhouse_pollen",
		"deliberate_short_circuit",
		"dining_timeline",
		"service_corridor_fiber",
		"mechanic_missing_glove",
		"mrs_lin_violet_fiber",
		"mrs_lin_glove_fragment",
		"mrs_lin_notebook",
	]


func show_final_deduction() -> void:
	if deduction_open:
		return
	if not GameState.has_story_flag("mrs_lin_notebook_found"):
		item_message = "The analysis table will not activate until you examine Dr. Lin's body and read her final notebook."
		interact_label.text = item_message
		return
	var missing: Array[String] = []
	for evidence_id: String in _required_final_evidence():
		if not GameState.has_evidence(evidence_id):
			missing.append(evidence_id)
	deduction_open = true
	room_input_enabled = false
	get_tree().paused = true
	if not missing.is_empty():
		item_message = "The notebook is clear, but the evidence chain is incomplete. Missing: " + ", ".join(missing)
		interact_label.text = item_message
		_close_deduction_panel()
		return
	if final_case_board != null:
		final_case_board.open_case()


func _clear_deduction_options() -> void:
	for child: Node in deduction_options.get_children():
		child.queue_free()


func _add_deduction_close_button() -> void:
	var close_button: Button = Button.new()
	close_button.text = "Return to investigation"
	close_button.custom_minimum_size = Vector2(660, 44)
	close_button.pressed.connect(_close_deduction_panel)
	deduction_options.add_child(close_button)


func _show_deduction_step() -> void:
	_clear_deduction_options()
	deduction_options.visible = true
	deduction_token_row.visible = false
	deduction_relation_row.visible = false
	deduction_connection_button.visible = false
	var step: Dictionary = FINAL_DEDUCTION_STEPS[deduction_step_index]
	deduction_title.text = "FINAL DEDUCTION — STEP %d/5" % (deduction_step_index + 1)
	deduction_question.text = str(step["question"])
	if deduction_step_index == 4:
		deduction_status.text = (
			"SUSPECT COMPARISON — unlocked after the first four deductions.\n\n"
			+ "BUTLER — cleaning and Dining access; common service cloth; no electrical expertise or glove match.\n"
			+ "GARDENER — Greenhouse access, pollen and a legitimate irrigation circuit map; no sabotage proof or glove match.\n"
			+ "MECHANIC — electrical expertise, maintenance access, Service route, missing right glove, copper repair match, and Archive access pattern."
		)
		if not GameState.has_story_flag("deduction_connection_completed"):
			deduction_options.visible = false
			deduction_token_order.clear()
			_refresh_deduction_token_visuals()
			deduction_connection_button.disabled = true
			deduction_token_row.visible = true
			deduction_connection_button.visible = true
			_set_deduction_relation_state(false)
			deduction_status.text = "Build the final relationship chain before comparing suspects: Evidence → Person → Location → Timeline."
			return
		_set_deduction_relation_state(true)
	else:
		deduction_status.text = "Use the evidence collected across Mrs. Lin's route."
	var options: Array = step["options"]
	for option_index: int in range(options.size()):
		var answer_index: int = option_index
		var option_text: String = str(options[option_index])
		var answer_button: Button = Button.new()
		answer_button.text = option_text
		answer_button.custom_minimum_size = Vector2(
			660.0,
			74.0 if option_text.length() > 80 else 48.0
		)
		answer_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer_button.clip_text = true
		answer_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer_button.add_theme_font_size_override("font_size", 13)
		answer_button.pressed.connect(func() -> void: _answer_final_deduction(answer_index))
		deduction_options.add_child(answer_button)


func _answer_final_deduction(answer_index: int) -> void:
	var step: Dictionary = FINAL_DEDUCTION_STEPS[deduction_step_index]
	if answer_index != int(step["correct"]):
		deduction_status.text = "That conclusion does not fit every piece of evidence. Re-read the notes and try again."
		return
	deduction_step_index += 1
	if deduction_step_index >= FINAL_DEDUCTION_STEPS.size():
		_finish_final_deduction()
		return
	_show_deduction_step()


func _finish_final_deduction() -> void:
	GameState.set_story_flag("final_deduction_solved")
	GameState.set_story_flag("normal_ending")
	var perfect: bool = (
		GameState.has_story_flag("perfect_ending_library_ready")
		and GameState.has_evidence("vault_vision_symbols")
		and GameState.has_evidence("ashford_archive_record")
		and GameState.has_evidence("master_archive_route")
	)
	if perfect:
		GameState.set_story_flag("perfect_ending")
		deduction_title.text = "PERFECT ENDING"
		deduction_question.text = "You identify the Mechanic as the person who staged the Chemistry scene, used the maintenance route, deliberately sabotaged the circuit, and confronted Mrs. Lin in the Final Room. The Library archive and Vision route reveal why: he had been copying restricted Ashford engineering records and needed the complete Knowledge Engine plans while keeping the unauthorized access hidden."
		deduction_status.text = "Mrs. Lin's investigation is complete — including the motive behind the crime."
	else:
		deduction_title.text = "NORMAL ENDING"
		deduction_question.text = "You identify the Mechanic as the person who orchestrated the sabotage, used the hidden maintenance route, and confronted Mrs. Lin in the Final Room. The full reason remains hidden because the unauthorized Ashford engineering records are still sealed in the Master Archive."
		deduction_status.text = "The core case is solved. The Library route could have revealed more."
	_clear_deduction_options()
	var ending_button: Button = Button.new()
	ending_button.text = "Close the case"
	ending_button.custom_minimum_size = Vector2(660, 48)
	ending_button.pressed.connect(_close_deduction_panel)
	deduction_options.add_child(ending_button)
	var archive_button: Button = Button.new()
	archive_button.name = "ViewFinalArchiveDocumentButton"
	archive_button.text = "View Final Archive Document"
	archive_button.custom_minimum_size = Vector2(660, 48)
	archive_button.pressed.connect(_show_final_archive_document_ui)
	deduction_options.add_child(archive_button)
	if NoteHud != null and not NoteHud.has_clue("final_deduction_note"):
		NoteHud.add_clue("final_deduction_note", {
			"title": "Final Deduction",
			"content": "The final deduction identifies the Mechanic through knowledge, tools, access, opportunity and route. The staged red stain, maintenance pollen, deliberate short circuit, missing right glove, copper repair thread and torn cuff fragment form one connected case.",
			"category": "investigation",
		})
	_show_ending_overlay()


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
