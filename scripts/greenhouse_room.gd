extends Node2D


const PLAYER_SPAWN_POSITION: Vector2 = Vector2(
	512.0,
	1370.0
)

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(
	1.35,
	1.35
)

const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(
	0.90,
	0.90
)

const CAMERA_ZOOM_SPEED: float = 7.0

@export var interaction_hint_position: Vector2 = Vector2(238, 696)
@export var interaction_hint_size: Vector2 = Vector2(548, 68)

## 调试开关：默认关闭。需要校准时可在 Inspector 勾选 Debug Print Click Position。
@export var debug_print_click_position := false
var _last_debug_mouse_position := Vector2(-100000, -100000)

const EXIT_POSITION: Vector2 = Vector2(
	512.0,
	1440.0
)

const EXIT_RADIUS: float = 90.0
const GARDENER_POSITION: Vector2 = Vector2(780.0, 1000.0)
const GARDENER_INTERACT_RADIUS: float = 88.0

# 温室可交互物品（素材已去背景，Y-sort 遮挡由 Worldsort 处理）。
const ITEM_INTERACT_RADIUS: float = 90.0
const INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "magic_planter",
		"label": "the great stone planter",
		"position": Vector2(515, 640),
		"message": (
			"The great stone planter hums faintly. "
			+ "The flowers seem to turn toward you."
		)
	},
	{
		"name": "workbench",
		"label": "the gardener's workbench",
		"position": Vector2(515, 965),
		"message": (
			"A gardener's workbench. Tools, pots and an open handbook "
			+ "are spread across it."
		)
	},
	{
		"name": "plant_pots_a",
		"label": "the cluster of pots",
		"position": Vector2(200, 1270),
		"message": (
			"A cluster of flower pots. Blue blossoms peek from "
			+ "between the leaves."
		)
	},
	{
		"name": "plant_pots_b",
		"label": "the leafy potted plant",
		"position": Vector2(820, 1270),
		"message": (
			"A heavy leafy plant, with small blue flowers scattered "
			+ "through its stems."
		)
	},
	{
		"name": "arch_door",
		"label": "the greenhouse gate",
		"position": Vector2(512, 1300),
		"message": (
			"The greenhouse gate. Engraved emblems flank the arch."
		)
	}
]

@onready var player: CharacterBody2D = (
	$Worldsort/player
)

@onready var room_background: Sprite2D = (
	$RoomBackground
)


var follow_camera: Camera2D
var camera_target_zoom: Vector2
var ui_layer: CanvasLayer
var interact_label: Label
var interaction_hint_panel: Panel
var interaction_focus: WorldInteractionFocus
var current_interaction: String = ""
var message_panel: Panel
var message_label: Label
var message_button_box: HBoxContainer
var avatar_panel: Panel
var avatar_portrait: TextureRect
var avatar_name_label: Label
var gardener_npc: AnimatedNpc

var room_input_enabled: bool = false
var scene_transitioning: bool = false
var dialogue_active: bool = false

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

func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = (
		"greenhouse_room"
	)

	GameState.set_room_visited(
		"greenhouse_room"
	)

	player.position = (
		PLAYER_SPAWN_POSITION
	)

	if player.has_method(
		"set_visual_scale"
	):
		player.call(
			"set_visual_scale",
			1.0
		)

	create_follow_camera()
	create_exit_ui()
	create_interaction_focus()
	create_gardener_npc()

	await get_tree().process_frame

	room_input_enabled = true

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(
		"toggle_developer_mode"
	):
		toggle_developer_view()

	update_camera_zoom(delta)

	if not room_input_enabled:
		hide_interaction_feedback()
		return

	if scene_transitioning:
		hide_interaction_feedback()
		return

	update_exit_interaction()
	update_interaction_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = interact_label.visible


func create_gardener_npc() -> void:
	if gardener_npc != null:
		return
	gardener_npc = AnimatedNpc.new()
	gardener_npc.name = "GardenerNPC"
	gardener_npc.position = GARDENER_POSITION
	gardener_npc.z_index = 6
	gardener_npc.configure(
		"Gardener",
		"res://assets/characters/animated_pixel_v3/gardener_walk.png",
		0.20,
		Vector2(18.0, 0.0),
		10.0,
		&"left"
	)
	$Worldsort.add_child(gardener_npc)


func create_follow_camera() -> void:
	if follow_camera != null:
		return

	follow_camera = Camera2D.new()
	follow_camera.name = (
		"GreenhouseFollowCamera"
	)

	camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)

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

	player.add_child(
		follow_camera
	)

	follow_camera.make_current()


func get_room_world_bounds() -> Rect2:
	if room_background.texture == null:
		return Rect2(
			Vector2.ZERO,
			Vector2(
				1024.0,
				1536.0
			)
		)

	var texture_size: Vector2 = (
		room_background.texture.get_size()
	)

	var displayed_size: Vector2 = Vector2(
		texture_size.x
			* absf(room_background.scale.x),
		texture_size.y
			* absf(room_background.scale.y)
	)

	var top_left: Vector2 = (
		room_background.global_position
	)

	if room_background.centered:
		top_left -= (
			displayed_size / 2.0
		)

	return Rect2(
		top_left,
		displayed_size
	)


func toggle_developer_view() -> void:
	GameState.toggle_developer_mode()

	camera_target_zoom = GameState.get_room_camera_zoom(GAMEPLAY_CAMERA_ZOOM, DEVELOPER_CAMERA_ZOOM)



func update_camera_zoom(
	delta: float
) -> void:
	if follow_camera == null:
		return

	var interpolation_weight: float = clampf(
		delta * CAMERA_ZOOM_SPEED,
		0.0,
		1.0
	)

	follow_camera.zoom = (
		follow_camera.zoom.lerp(
			camera_target_zoom,
			interpolation_weight
		)
	)
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
	if current_interaction == "gardener":
		interaction_focus.set_focus(
			GARDENER_POSITION,
			"Gardener",
			true
		)
		return
	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			interaction_focus.set_focus(
				item["position"] as Vector2,
				str(item["label"]),
				true
			)
			return


func hide_interaction_feedback() -> void:
	current_interaction = ""
	if interaction_focus != null:
		interaction_focus.clear_focus()
	if interaction_hint_panel != null:
		interaction_hint_panel.visible = false
	if interact_label != null:
		interact_label.visible = false


func create_exit_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "GreenhouseUI"
	ui_layer.layer = 30
	add_child(ui_layer)

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
	interact_label.text = "Press E to return to the Castle Hall"
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

	create_dialogue_ui()


## 底部通栏对话框（wake_room 标准：金边圆角 + 头像 + 分段）。
func create_dialogue_ui() -> void:
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

	message_button_box = HBoxContainer.new()
	message_button_box.position = Vector2(164, 196)
	message_button_box.size = Vector2(828, 42)
	message_button_box.add_theme_constant_override("separation", 8)
	message_panel.add_child(message_button_box)


func show_message(speaker_name: String, body_text: String) -> void:
	_current_speaker = speaker_name
	_dialogue_segments = _split_dialogue_segments(body_text)
	_segment_index = 0
	_pending_buttons.clear()
	_set_avatar(speaker_name)
	# 先渲染 UI 再暂停：若渲染抛错，暂停不会已开启导致永久卡死。
	message_panel.visible = true
	_render_segment()
	start_dialogue_pause()


func _render_segment() -> void:
	message_label.text = "%s:\n%s" % [_current_speaker, _dialogue_segments[_segment_index]]
	clear_message_buttons(false)
	if _segment_index < _dialogue_segments.size() - 1:
		var continue_button := Button.new()
		continue_button.name = "SegmentContinueButton"
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(0, 38)
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func add_message_button(button_text: String, callback: Callable) -> void:
	if _segment_index < _dialogue_segments.size() - 1:
		_pending_buttons.append({"text": button_text, "callback": callback})
		return
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	message_button_box.add_child(button)


func clear_message_buttons(keep_continue: bool = true) -> void:
	for child: Node in message_button_box.get_children():
		if keep_continue and child.name == "SegmentContinueButton":
			continue
		child.queue_free()


func close_message_panel() -> void:
	message_panel.visible = false
	clear_message_buttons(false)
	end_dialogue_pause()


func start_dialogue_pause() -> void:
	dialogue_active = true
	current_interaction = ""
	if interact_label != null:
		interact_label.visible = false
	room_input_enabled = false
	if player != null:
		if player.has_method("cancel_click_movement"):
			player.call("cancel_click_movement")
		player.set_physics_process(false)


func end_dialogue_pause() -> void:
	dialogue_active = false
	room_input_enabled = true
	if player != null:
		player.set_physics_process(true)


func update_exit_interaction() -> void:
	if interact_label == null:
		return

	current_interaction = ""
	if gardener_npc != null and player.global_position.distance_to(gardener_npc.global_position) <= GARDENER_INTERACT_RADIUS:
		current_interaction = "gardener"
		interact_label.text = "Press E to talk to the Gardener"
		interact_label.visible = true
		if Input.is_action_just_pressed("interact"):
			show_gardener_dialogue()
		return

	# 物品交互优先：靠近任意可交互物品时显示 Press E 提示。
	for item: Dictionary in INTERACT_ITEMS:
		var distance_to_item: float = (
			player.global_position.distance_to(
				item["position"] as Vector2
			)
		)
		if distance_to_item <= ITEM_INTERACT_RADIUS:
			current_interaction = str(item["name"])
			var item_name: String = str(item["name"])
			interact_label.text = "Press E to inspect " + str(item["label"])
			interact_label.visible = true
			if Input.is_action_just_pressed("interact"):
				_mark_inspected(item_name)
				_show_item_dialogue(item_name)
			return

	if player.global_position.distance_to(EXIT_POSITION) <= EXIT_RADIUS:
		current_interaction = "exit"
		interact_label.text = "Press E to return to the Castle Hall"
		interact_label.visible = true
		if Input.is_action_just_pressed("interact"):
			return_to_castle_hall()
		return

	interact_label.visible = false


func show_gardener_dialogue() -> void:
	start_dialogue_pause()
	show_message(
		"Gardener",
		"I have tended these rooms long enough to know what belongs here. "
		+ "That dark pollen does not.\n\n"
		+ "The irrigation pump shares a maintenance circuit with the lower halls. "
		+ "That explains the repair map on my bench, but it does not explain who carried deep-room traces into my greenhouse."
	)
	clear_message_buttons()
	add_message_button("Continue", close_message_panel)


var _inspected_items: Array[String] = []
var _gathered_plants: Array[String] = []


## 交互物 → 玩家独白对话框（分段 + 头像）。
func _show_item_dialogue(item_name: String) -> void:
	# 已解锁采集时，植物交互改为采集。
	if (
		(item_name == "plant_pots_a" or item_name == "plant_pots_b")
		and GameState.is_room_completed("greenhouse_room")
	):
		_gather_greenhouse_plant(item_name)
		return
	for item: Dictionary in INTERACT_ITEMS:
		if str(item["name"]) != item_name:
			continue
		var body: String = str(item["message"])
		# 剧情强化：石花盆 → 深色花粉痕迹（深室来源暗示）。
		if item_name == "magic_planter":
			body = (
				"The great stone planter hums faintly, and the flowers "
				+ "seem to turn toward you.\n\n"
				+ "Between the petals you spot a smear of "
				+ "[color=#3a2a4a]dark violet pollen[/color] — not from any "
				+ "plant in this greenhouse."
			)
		if item_name == "workbench":
			# 剧情：首次交互 → 羊皮纸显示 Mrs. Lin 撕落的笔记页。
			if not GameState.has_map("circuit_repair_map"):
				GameState.add_map("circuit_repair_map")
			if not NoteHud.has_clue("greenhouse_pollen_note"):
				var parchment: Node = get_node_or_null("/root/ParchmentHud")
				if parchment != null:
					parchment.call(
						"show_parchment",
						"Mrs. Lin's Greenhouse Notes",
						"Half a page of handwriting, torn across the middle:\n\n"
						+ "\"...the gardener swears the greenhouse was locked. "
						+ "Yet dark pollen — the deep-room kind, not from any "
						+ "plant here — clings to the tool handles. It does not "
						+ "prove the gardener used the route; it only proves that "
						+ "maintenance equipment entered the deep room.\n\n"
						+ "If that pollen came from outside, someone entered "
						+ "the greenhouse through the maintenance tunnel.\n\n"
						+ "The gardener is the obvious suspect. Obvious is not the same as proven. You know how often I say that.\"",
						"greenhouse_pollen_note",
						{
							"title": "Mrs. Lin's Greenhouse Notes",
							"icon": "icon_note",
							"content": (
								"[center][b]A Torn Note Page[/b][/center]\n\n"
								+ "Half a page of handwriting, torn across the middle:\n\n"
								+ "\"...the gardener swears the greenhouse was locked. "
								+ "Yet [color=#7a2e2e]dark pollen[/color] — the deep-room "
								+ "kind, not from any plant here — clings to the tool "
								+ "handles. It does not prove the gardener used the route; it only proves that maintenance equipment entered the deep room.\n\n"
								+ "If that pollen came from outside, someone entered "
								+ "the greenhouse through the maintenance tunnel.\n\n"
								+ "The gardener is the obvious suspect. Obvious is not the same as proven. You know how often I say that.\""
							),
							"category": "investigation",
							"evidence_id": "greenhouse_pollen",
						}
					)
				return
			if item_name == "workbench" and NoteHud.has_clue("greenhouse_pollen_note"):
				if not GameState.has_story_flag("gardener_circuit_map_explained"):
					GameState.set_story_flag("gardener_circuit_map_explained")
					if not NoteHud.has_clue("gardener_irrigation_record"):
						NoteHud.add_clue("gardener_irrigation_record", {
							"title": "Greenhouse Irrigation Record",
							"content": "The Gardener's irrigation pump shares part of the castle maintenance circuit. The circuit_repair_map was a legitimate copy kept for pump and water-control repairs. It explains why the map was on the workbench, but not the pollen on maintenance equipment.",
							"category": "investigation",
						})
				body = "A later irrigation entry explains the circuit map: the greenhouse pump shares part of the castle maintenance circuit. The Gardener had a legitimate reason to keep this copy. That explains the map, but not the unexpected pollen on the maintenance tools."
				show_message("You", body)
				return
			body = (
				"A gardener's workbench. Tools, pots and an open handbook "
				+ "are spread across it."
			)
		if item_name == "arch_door" and GameState.has_key("circuit_room_key"):
			body = (
				"The greenhouse gate clicks open just enough to reveal a hidden "
				+ "brass hook. A dark metal key threaded with violet current hangs "
				+ "from it.\n\n"
				+ "The Circuit Room Key. The next room is waiting beyond the "
				+ "greenhouse trail."
			)
		show_message("You", body)
		return

func _mark_inspected(item_name: String) -> void:
	if _inspected_items.has(item_name):
		return
	_inspected_items.append(item_name)
	# 证据与笔记奖励统一延迟到羊皮纸关闭后发放。
	# 查看完全部交互物 → 温室调查完成，解锁草药采集。
	if GameState.is_room_completed("greenhouse_room"):
		return
	var all_seen: bool = true
	for item: Dictionary in INTERACT_ITEMS:
		if not _inspected_items.has(str(item["name"])):
			all_seen = false
			break
	if all_seen:
		GameState.set_room_completed("greenhouse_room")
		# 温室调查完成后，在拱门暗槽发现通往下一房间的钥匙。
		if not GameState.has_story_flag("greenhouse_circuit_key_found"):
			GameState.set_story_flag("greenhouse_circuit_key_found")
			GameState.add_key("circuit_room_key")
		interact_label.text = (
			"Greenhouse survey complete. "
			+ "You found the Circuit Room Key. You can now gather Blue Blossom and Moonleaf."
		)
		if NoteHud != null:
			NoteHud.add_clue("greenhouse_herbs", {
				"title": "Greenhouse Herbs",
				"content": "Blue Blossom can be gathered here and used "
					+ "at the Chemistry Room alchemy table to brew potions.",
				"category": "herb",
			})


func _gather_greenhouse_plant(plant_name: String) -> void:
	if _gathered_plants.has(plant_name):
		show_message(
			"You",
			"This plant has already been harvested. The other pot may still "
			+ "have Blue Blossom ready."
		)
		return
	_gathered_plants.append(plant_name)
	var herb_id: String = "blue_blossom" if plant_name == "plant_pots_a" else "moonleaf"
	var amount: int = 2 if plant_name == "plant_pots_a" else 3
	var herb_name: String = str(GameState.HERB_INFO.get(herb_id, {}).get("name", herb_id))
	GameState.add_herb(herb_id, amount)
	var gather_template: String = (
		"You gather %s from this plant.\n\n"
		+ "Gathered %d %s. Return to the Chemistry Room and use the matching recipe sheet at the alchemy table."
	)
	var gather_text: String = gather_template % [herb_name, amount, herb_name]
	show_message(
		"You",
		gather_text
	)
func return_to_castle_hall() -> void:
	if scene_transitioning:
		return

	scene_transitioning = true
	room_input_enabled = false

	if interact_label != null:
		interact_label.visible = false

	player.set_physics_process(false)

	GameState.prepare_return_to_hub(
		"greenhouse_door"
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
			"Failed to return to Castle Hall: "
			+ str(change_error)
		)
