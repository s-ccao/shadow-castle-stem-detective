extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 60
const MAP_HEIGHT := 40
const MAP_PIXEL_WIDTH := MAP_WIDTH * CELL_SIZE
const MAP_PIXEL_HEIGHT := MAP_HEIGHT * CELL_SIZE

# Fog uses smaller cells than the wall grid.
# Walls are 32x32, but fog is 16x16, so the light looks more circular.
const FOG_CELL_SIZE := 16
const FOG_COLS := MAP_PIXEL_WIDTH / FOG_CELL_SIZE
const FOG_ROWS := MAP_PIXEL_HEIGHT / FOG_CELL_SIZE

const VISION_RADIUS_PIXELS := 210.0
const CLEAR_RADIUS_PIXELS := 90.0
const EDGE_DARKNESS := 0.62
const DISCOVERED_DARKNESS := 0.68
var intro_seen := false
var intro_reviewing_objectives := false
@onready var player = $player

var wall_cells := {}
var fog_cells := {}
var door_cells := {}
var door_nodes := {}
var learned_circuit_rule := false
var circuit_note_position := Vector2.ZERO
var circuit_note_node: ColorRect
var circuit_door_open := false
var circuit_door_position := Vector2.ZERO
var discovered_fog_cells := {}
var visible_fog_cells := {}
var visible_fog_distances := {}
@onready var enemy = get_node_or_null("enemy")
var follow_camera: Camera2D

var astar_grid := AStarGrid2D.new()
var game_over := false
var game_over_label: Label
var reputation := 0
var evidence_collected := false
var clue_position := Vector2.ZERO
var clue_node: ColorRect

var ui_layer: CanvasLayer
var message_panel: Panel
var message_label: Label
var button_box: VBoxContainer
var message_scroll: ScrollContainer
var button_scroll: ScrollContainer
var dialogue_action_row: HBoxContainer
var dialogue_continue_button: Button
var dialogue_speaker_label: Label
var dialogue_portrait_box: Panel
var dialogue_portrait_color: ColorRect
var dialogue_portrait_name: Label
var reputation_label: Label
var interact_label: Label
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
var butler_node: ColorRect
var current_interaction := ""

var pollen_collected := false
var pollen_position := Vector2.ZERO
var pollen_node: ColorRect

var gardener_position := Vector2.ZERO
var gardener_node: ColorRect
var circuit_collected := false
var circuit_position := Vector2.ZERO
var circuit_node: ColorRect

var mechanic_position := Vector2.ZERO
var mechanic_node: ColorRect

var final_room_position := Vector2.ZERO
var final_room_node: ColorRect
var culprit_id := "mechanic"
var knowledge_items: Array[String] = []
var knowledge_panel: Panel
var knowledge_panel_open := false
var knowledge_list_label: Label
func _ready():
	create_floor()
	create_castle_walls()
	build_navigation_grid()
	create_locked_circuit_door()
	create_circuit_learning_note()
	create_red_stain_clue()
	create_pollen_clue()
	create_circuit_clue()
	create_butler_npc()
	create_gardener_npc()
	create_mechanic_npc()
	create_final_room()
	create_fog_cells()
	create_game_ui()
	create_game_over_ui()
	move_player_to_cell(Vector2i(2, 2))
	create_follow_camera()
	setup_enemy()
	#show_intro_dialogue()


func _process(delta):
	if Input.is_action_just_pressed("restart_game"):
		restart_current_game()
		return

	if Input.is_action_just_pressed("return_menu"):
		return_to_main_menu()
		return

	if Input.is_action_just_pressed("objective_panel"):
		toggle_objective_panel()
		return
	if Input.is_action_just_pressed("knowledge_journal"):
		toggle_knowledge_journal()
		return

	if game_over:
		return

	if dialogue_active:
		update_fog_of_war()
		return

	if objective_panel_open:
		update_fog_of_war()
		return

	update_fog_of_war()
	update_interaction_prompt()

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


func create_castle_walls():
	# Outer castle border
	for x in range(MAP_WIDTH):
		add_wall_cell(Vector2i(x, 0))
		add_wall_cell(Vector2i(x, MAP_HEIGHT - 1))

	for y in range(MAP_HEIGHT):
		add_wall_cell(Vector2i(0, y))
		add_wall_cell(Vector2i(MAP_WIDTH - 1, y))

	# ============================================================
	# Castle Layout v2
	# The map is divided into rooms and corridors:
	# - Left top: crime hall
	# - Top middle: greenhouse trace area
	# - Middle: circuit room
	# - Right top: final deduction wing
	# - Bottom: chase maze / service corridors
	# ============================================================

	# --- Top room partitions ---
	# Wall between crime hall and greenhouse area, with a doorway at y=4-5
	add_wall_rect(Vector2i(13, 1), Vector2i(13, 3))
	add_wall_rect(Vector2i(13, 6), Vector2i(13, 17))

	# Wall between greenhouse area and central wing, with openings at y=5-6 and y=13-14
	add_wall_rect(Vector2i(28, 1), Vector2i(28, 4))
	add_wall_rect(Vector2i(28, 7), Vector2i(28, 12))
	add_wall_rect(Vector2i(28, 15), Vector2i(28, 17))

	# Wall between central wing and final deduction wing, with doorway at y=4-6
	add_wall_rect(Vector2i(43, 1), Vector2i(43, 3))
	add_wall_rect(Vector2i(43, 7), Vector2i(43, 17))

	# Horizontal wall separating top rooms from middle rooms, with door gaps
	add_wall_rect(Vector2i(1, 8), Vector2i(20, 8))
	add_wall_rect(Vector2i(24, 8), Vector2i(42, 8))
	add_wall_rect(Vector2i(46, 8), Vector2i(58, 8))

	# Horizontal wall separating middle rooms from lower corridors, with door gaps
	add_wall_rect(Vector2i(1, 18), Vector2i(10, 18))
	add_wall_rect(Vector2i(14, 18), Vector2i(30, 18))
	add_wall_rect(Vector2i(34, 18), Vector2i(49, 18))
	add_wall_rect(Vector2i(53, 18), Vector2i(58, 18))

	# --- Lower castle partitions ---
	# Vertical service corridor dividers, with gaps
	add_wall_rect(Vector2i(18, 19), Vector2i(18, 23))
	add_wall_rect(Vector2i(18, 26), Vector2i(18, 38))

	add_wall_rect(Vector2i(38, 19), Vector2i(38, 27))
	add_wall_rect(Vector2i(38, 31), Vector2i(38, 38))

	# Lower horizontal maze sections, with gaps
	add_wall_rect(Vector2i(1, 29), Vector2i(15, 29))
	add_wall_rect(Vector2i(21, 29), Vector2i(36, 29))
	add_wall_rect(Vector2i(40, 29), Vector2i(58, 29))

	# ============================================================
	# Room details / internal obstacles
	# These make rooms feel less empty without blocking key objects.
	# ============================================================

	# Crime hall details near red stain / Butler
	add_wall_rect(Vector2i(3, 6), Vector2i(8, 6))
	add_wall_rect(Vector2i(10, 2), Vector2i(10, 5))

	# Greenhouse trace area details
	add_wall_rect(Vector2i(16, 2), Vector2i(24, 2))
	add_wall_rect(Vector2i(20, 4), Vector2i(20, 6))
	add_wall_rect(Vector2i(23, 5), Vector2i(26, 5))

	# Central corridor details
	add_wall_rect(Vector2i(31, 3), Vector2i(39, 3))
	add_wall_rect(Vector2i(34, 5), Vector2i(34, 7))
	add_wall_rect(Vector2i(38, 6), Vector2i(41, 6))

	# Final deduction wing details
	add_wall_rect(Vector2i(48, 2), Vector2i(56, 2))
	add_wall_rect(Vector2i(48, 7), Vector2i(52, 7))
	add_wall_rect(Vector2i(56, 5), Vector2i(56, 7))

	# Circuit room details
	add_wall_rect(Vector2i(16, 11), Vector2i(21, 11))
	add_wall_rect(Vector2i(25, 10), Vector2i(25, 16))
	add_wall_rect(Vector2i(18, 15), Vector2i(21, 15))

	# Middle right storage / shadow corridor details
	add_wall_rect(Vector2i(32, 11), Vector2i(40, 11))
	add_wall_rect(Vector2i(36, 12), Vector2i(36, 16))
	add_wall_rect(Vector2i(45, 13), Vector2i(53, 13))
	add_wall_rect(Vector2i(49, 14), Vector2i(49, 17))

	# Lower left maze
	add_wall_rect(Vector2i(4, 22), Vector2i(14, 22))
	add_wall_rect(Vector2i(8, 23), Vector2i(8, 27))
	add_wall_rect(Vector2i(2, 35), Vector2i(12, 35))
	add_wall_rect(Vector2i(14, 31), Vector2i(14, 37))

	# Lower middle maze
	add_wall_rect(Vector2i(22, 21), Vector2i(33, 21))
	add_wall_rect(Vector2i(25, 22), Vector2i(25, 27))
	add_wall_rect(Vector2i(30, 24), Vector2i(36, 24))
	add_wall_rect(Vector2i(22, 34), Vector2i(34, 34))
	add_wall_rect(Vector2i(29, 31), Vector2i(29, 37))

	# Lower right chase maze / enemy area
	add_wall_rect(Vector2i(42, 22), Vector2i(55, 22))
	add_wall_rect(Vector2i(45, 23), Vector2i(45, 27))
	add_wall_rect(Vector2i(52, 25), Vector2i(57, 25))
	add_wall_rect(Vector2i(42, 34), Vector2i(55, 34))
	add_wall_rect(Vector2i(51, 31), Vector2i(51, 37))


func add_wall_rect(start_cell: Vector2i, end_cell: Vector2i):
	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):
			add_wall_cell(Vector2i(x, y))


func add_wall_cell(cell: Vector2i):
	var key = cell_key(cell)

	if wall_cells.has(key):
		return

	wall_cells[key] = true

	var wall = StaticBody2D.new()
	wall.name = "Wall"
	wall.position = cell_to_world(cell)

	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rectangle
	wall.add_child(shape)

	var visual = ColorRect.new()
	visual.color = Color(0.22, 0.18, 0.28)
	visual.size = Vector2(CELL_SIZE, CELL_SIZE)
	visual.position = Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2)
	wall.add_child(visual)

	add_child(wall)


func create_fog_cells():
	for y in range(FOG_ROWS):
		for x in range(FOG_COLS):
			var fog_cell = Vector2i(x, y)

			var fog = ColorRect.new()
			fog.name = "Fog"
			fog.position = Vector2(x * FOG_CELL_SIZE, y * FOG_CELL_SIZE)
			fog.size = Vector2(FOG_CELL_SIZE, FOG_CELL_SIZE)
			fog.color = Color(0.0, 0.0, 0.0, 1.0)
			fog.z_index = 100
			fog.mouse_filter = Control.MOUSE_FILTER_IGNORE

			add_child(fog)
			fog_cells[fog_key(fog_cell)] = fog


func update_fog_of_war():
	visible_fog_cells.clear()
	visible_fog_distances.clear()

	var player_world = player.global_position

	var min_x = int(max(0, (player_world.x - VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var max_x = int(min(FOG_COLS - 1, (player_world.x + VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var min_y = int(max(0, (player_world.y - VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var max_y = int(min(FOG_ROWS - 1, (player_world.y + VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var fog_cell = Vector2i(x, y)
			var target_world = fog_cell_to_world_center(fog_cell)
			var distance = player_world.distance_to(target_world)

			if distance > VISION_RADIUS_PIXELS:
				continue

			if has_world_line_of_sight(player_world, target_world):
				var key = fog_key(fog_cell)
				visible_fog_cells[key] = true
				visible_fog_distances[key] = distance
				discovered_fog_cells[key] = true

	update_fog_visuals()


func update_fog_visuals():
	for key in fog_cells.keys():
		var fog = fog_cells[key]

		if visible_fog_cells.has(key):
			var distance = visible_fog_distances[key]

			var edge_amount = 0.0
			if distance > CLEAR_RADIUS_PIXELS:
				edge_amount = (distance - CLEAR_RADIUS_PIXELS) / (VISION_RADIUS_PIXELS - CLEAR_RADIUS_PIXELS)
				edge_amount = clamp(edge_amount, 0.0, 1.0)

			var alpha = edge_amount * EDGE_DARKNESS
			fog.color = Color(0.0, 0.0, 0.0, alpha)

		elif discovered_fog_cells.has(key):
			fog.color = Color(0.0, 0.0, 0.0, DISCOVERED_DARKNESS)

		else:
			fog.color = Color(0.0, 0.0, 0.0, 1.0)


func has_world_line_of_sight(start_world: Vector2, end_world: Vector2) -> bool:
	var target_map_cell = world_to_cell(end_world)

	var direction = end_world - start_world
	var distance = direction.length()

	if distance <= 0.0:
		return true

	direction = direction.normalized()

	# Smaller step = more accurate wall blocking.
	# 4 pixels is accurate enough for this prototype.
	var step_size := 4.0
	var steps = int(distance / step_size)

	for i in range(1, steps + 1):
		var sample_point = start_world + direction * float(i) * step_size
		var sample_cell = world_to_cell(sample_point)

		if not is_inside_map(sample_cell):
			return false

		if blocks_vision(sample_cell):
			return sample_cell == target_map_cell

	return true


func is_wall(cell: Vector2i) -> bool:
	return wall_cells.has(cell_key(cell))


func is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT


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

	for key in wall_cells.keys():
		var wall_cell = string_to_cell(key)
		astar_grid.set_point_solid(wall_cell, true)


func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array:
	if not is_inside_map(start_cell):
		return []

	if not is_inside_map(end_cell):
		return []

	if is_wall(start_cell) or is_wall(end_cell):
		return []

	return astar_grid.get_id_path(start_cell, end_cell)


func setup_enemy():
	if enemy == null:
		return

	enemy.position = cell_to_world(Vector2i(50, 32))
	enemy.setup(self, player)


func create_game_over_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER\nThe murderer caught you.\nPress R to restart.\nPress M for main menu."
	game_over_label.position = Vector2(300, 290)
	game_over_label.size = Vector2(460, 180)
	game_over_label.visible = false
	game_over_label.add_theme_font_size_override("font_size", 32)

	canvas.add_child(game_over_label)


func on_player_caught():
	if game_over:
		return

	game_over = true
	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	game_over_label.visible = true


func string_to_cell(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
func create_red_stain_clue():
	clue_position = cell_to_world(Vector2i(4, 3))

	clue_node = ColorRect.new()
	clue_node.name = "RedStainClue"
	clue_node.color = Color(0.75, 0.02, 0.04, 1.0)
	clue_node.size = Vector2(26, 18)
	clue_node.position = clue_position - clue_node.size / 2
	clue_node.z_index = 5

	add_child(clue_node)
	add_world_label(clue_node, "Red Stain", Vector2(-26, -24))


func create_game_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	reputation_label = Label.new()
	reputation_label.text = "Reputation: 0"
	reputation_label.position = Vector2(20, 20)
	reputation_label.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(reputation_label)

	evidence_hint_label = Label.new()
	evidence_hint_label.text = "B: Evidence   K: Knowledge   O: Objectives   R: Restart   M: Menu"
	evidence_hint_label.position = Vector2(20, 50)
	evidence_hint_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(evidence_hint_label)
	objective_summary_label = Label.new()
	objective_summary_label.text = ""
	objective_summary_label.position = Vector2(20, 82)
	objective_summary_label.size = Vector2(420, 28)
	objective_summary_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(objective_summary_label)

	create_objective_panel_ui()

	interact_label = Label.new()
	interact_label.text = "Press E to investigate"
	interact_label.position = Vector2(380, 700)
	interact_label.visible = false
	interact_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(interact_label)

	message_panel = Panel.new()
	message_panel.position = Vector2(26, 430)
	message_panel.size = Vector2(972, 286)
	message_panel.visible = false
	ui_layer.add_child(message_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(16, 16)
	margin.size = Vector2(940, 254)
	message_panel.add_child(margin)

	var main_layout = HBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 14)
	margin.add_child(main_layout)

	# Left portrait area
	dialogue_portrait_box = Panel.new()
	dialogue_portrait_box.custom_minimum_size = Vector2(128, 248)
	main_layout.add_child(dialogue_portrait_box)

	var portrait_layout = VBoxContainer.new()
	portrait_layout.position = Vector2(10, 10)
	portrait_layout.size = Vector2(108, 228)
	portrait_layout.add_theme_constant_override("separation", 8)
	dialogue_portrait_box.add_child(portrait_layout)

	dialogue_portrait_color = ColorRect.new()
	dialogue_portrait_color.color = Color(0.25, 0.55, 0.95, 1.0)
	dialogue_portrait_color.custom_minimum_size = Vector2(108, 160)
	portrait_layout.add_child(dialogue_portrait_color)

	dialogue_portrait_name = Label.new()
	dialogue_portrait_name.text = "Dr. Lin"
	dialogue_portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_portrait_name.add_theme_font_size_override("font_size", 15)
	portrait_layout.add_child(dialogue_portrait_name)

	# Right dialogue area
	var dialogue_layout = VBoxContainer.new()
	dialogue_layout.custom_minimum_size = Vector2(790, 248)
	dialogue_layout.add_theme_constant_override("separation", 6)
	main_layout.add_child(dialogue_layout)

	dialogue_speaker_label = Label.new()
	dialogue_speaker_label.text = "Dr. Lin"
	dialogue_speaker_label.add_theme_font_size_override("font_size", 20)
	dialogue_layout.add_child(dialogue_speaker_label)

	message_scroll = ScrollContainer.new()
	message_scroll.custom_minimum_size = Vector2(790, 108)
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_layout.add_child(message_scroll)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.custom_minimum_size = Vector2(760, 150)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.add_child(message_label)

	button_scroll = ScrollContainer.new()
	button_scroll.custom_minimum_size = Vector2(790, 70)
	button_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_layout.add_child(button_scroll)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 6)
	button_scroll.add_child(button_box)

	dialogue_action_row = HBoxContainer.new()
	dialogue_action_row.custom_minimum_size = Vector2(790, 34)
	dialogue_layout.add_child(dialogue_action_row)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_action_row.add_child(spacer)

	dialogue_continue_button = Button.new()
	dialogue_continue_button.text = "Continue"
	dialogue_continue_button.custom_minimum_size = Vector2(180, 34)
	dialogue_continue_button.add_theme_font_size_override("font_size", 15)
	dialogue_continue_button.visible = false
	dialogue_action_row.add_child(dialogue_continue_button)

	set_dialogue_speaker("Dr. Lin")
	apply_dialogue_visual_style()
	create_evidence_board_ui()
	create_knowledge_journal_ui()
	update_objective_text()
	


func update_interaction_prompt():
	current_interaction = ""
	interact_label.visible = false

	if message_panel.visible or evidence_board_open:
		return
	if not learned_circuit_rule:
		var note_distance = player.global_position.distance_to(circuit_note_position)

		if note_distance < 55.0:
			current_interaction = "circuit_note"
			interact_label.text = "Press E to read maintenance note"
			interact_label.visible = true
			return
	if not circuit_door_open:
		var door_distance = player.global_position.distance_to(circuit_door_position)

		if door_distance < 75.0:
			current_interaction = "circuit_door"
			interact_label.text = "Press E to solve locked door puzzle"
			interact_label.visible = true
			return
	if not evidence_collected:
		var clue_distance = player.global_position.distance_to(clue_position)

		if clue_distance < 55.0:
			current_interaction = "red_stain"
			interact_label.text = "Press E to investigate red stain"
			interact_label.visible = true
			return

	if not pollen_collected:
		var pollen_distance = player.global_position.distance_to(pollen_position)

		if pollen_distance < 55.0:
			current_interaction = "pollen"
			interact_label.text = "Press E to investigate pollen"
			interact_label.visible = true
			return

	if not circuit_collected:
		var circuit_distance = player.global_position.distance_to(circuit_position)

		if circuit_distance < 55.0:
			current_interaction = "circuit"
			interact_label.text = "Press E to investigate circuit"
			interact_label.visible = true
			return

	var butler_distance = player.global_position.distance_to(butler_position)

	if butler_distance < 55.0:
		current_interaction = "butler"
		interact_label.text = "Press E to talk to Butler"
		interact_label.visible = true
		return

	var gardener_distance = player.global_position.distance_to(gardener_position)

	if gardener_distance < 55.0:
		current_interaction = "gardener"
		interact_label.text = "Press E to talk to Gardener"
		interact_label.visible = true
		return

	var mechanic_distance = player.global_position.distance_to(mechanic_position)

	if mechanic_distance < 55.0:
		current_interaction = "mechanic"
		interact_label.text = "Press E to talk to Mechanic"
		interact_label.visible = true
		return

	var final_room_distance = player.global_position.distance_to(final_room_position)

	if final_room_distance < 60.0:
		current_interaction = "final_room"

		if has_all_evidence():
			interact_label.text = "Press E to make final deduction"
		else:
			interact_label.text = "Need more evidence before final deduction"

		interact_label.visible = true
		return

func try_investigate_clue():
	if current_interaction == "circuit_note":
		show_circuit_learning_note()
	elif current_interaction == "circuit_door":
		show_circuit_door_puzzle()
	elif current_interaction == "red_stain":
		show_clue_intro()
	elif current_interaction == "pollen":
		show_pollen_intro()
	elif current_interaction == "circuit":
		show_circuit_intro()
	elif current_interaction == "butler":
		show_butler_dialogue()
	elif current_interaction == "gardener":
		show_gardener_dialogue()
	elif current_interaction == "mechanic":
		show_mechanic_dialogue()
	elif current_interaction == "final_room":
		show_final_deduction()


func show_clue_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThis red liquid looks like blood at first glance, but a good detective never relies on color alone.\n\nWhat do you think caused the red color?"

	add_dialogue_button("I think I know.", show_red_stain_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_red_stain_without_reward)


func show_red_stain_question():
	clear_buttons()

	set_dialogue_text(
		"Dr. Lin",
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
	reputation += 10
	reputation_label.text = "Reputation: " + str(reputation)

	clear_buttons()
	message_label.text = "Correct.\n\nDr. Lin:\nExcellent reasoning. The red color is likely caused by an indicator reacting with a basic cleaning substance. This means the stain may have been staged, not left by the victim.\n\nEvidence added: Fake Red Stain"

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func on_red_stain_wrong():
	clear_buttons()
	message_label.text = "Not quite.\n\nDr. Lin:\nThe important clue is not just the color. If an indicator solution mixes with a basic cleaner, it can turn red or pink. This stain may be fake.\n\nEvidence added: Fake Red Stain"

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_red_stain_without_reward():
	clear_buttons()
	message_label.text = "Dr. Lin:\nThat's okay. A good detective knows when to ask for help.\n\nThe red color may come from an indicator solution reacting with a basic cleaner. So this does not prove it is blood. Someone may have staged the crime scene.\n\nEvidence added: Fake Red Stain"

	collect_red_stain_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_red_stain_evidence():
	evidence_collected = true

	if not evidence_items.has("fake_red_stain"):
		evidence_items.append("fake_red_stain")

	if clue_node != null:
		clue_node.color = Color(0.35, 0.02, 0.04, 0.7)

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
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
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

	if not game_over:
		player.set_physics_process(true)

		if enemy != null:
			enemy.set_physics_process(true)

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
	butler_position = cell_to_world(Vector2i(9, 3))

	butler_node = ColorRect.new()
	butler_node.name = "ButlerNPC"
	butler_node.color = Color(0.55, 0.35, 0.16, 1.0)
	butler_node.size = Vector2(24, 28)
	butler_node.position = butler_position - butler_node.size / 2
	butler_node.z_index = 6

	add_child(butler_node)
	add_world_label(butler_node, "Butler", Vector2(-18, -24))
func show_butler_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Butler")
	message_panel.visible = true

	if evidence_items.has("fake_red_stain"):
		message_label.text = "Butler:\nI already told you, I only cleaned the hallway. That red stain has nothing to do with me.\n\nDr. Lin:\nInteresting. The stain may involve a basic cleaning substance. Someone with access to cleaning supplies could explain part of this clue."
	else:
		message_label.text = "Butler:\nI was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms.\n\nDr. Lin:\nThat explains why many paths require scientific reasoning. We should collect physical evidence before making any accusation."

	show_continue_button("Continue", close_message_panel)
func create_pollen_clue():
	pollen_position = cell_to_world(Vector2i(17, 6))

	pollen_node = ColorRect.new()
	pollen_node.name = "PollenClue"
	pollen_node.color = Color(0.95, 0.78, 0.12, 1.0)
	pollen_node.size = Vector2(22, 22)
	pollen_node.position = pollen_position - pollen_node.size / 2
	pollen_node.z_index = 5

	add_child(pollen_node)
	add_world_label(pollen_node, "Pollen", Vector2(-16, -24))
func create_gardener_npc():
	gardener_position = cell_to_world(Vector2i(18, 4))

	gardener_node = ColorRect.new()
	gardener_node.name = "GardenerNPC"
	gardener_node.color = Color(0.1, 0.55, 0.18, 1.0)
	gardener_node.size = Vector2(24, 28)
	gardener_node.position = gardener_position - gardener_node.size / 2
	gardener_node.z_index = 6

	add_child(gardener_node)
	add_world_label(gardener_node, "Gardener", Vector2(-28, -24))
func show_pollen_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThere is yellow pollen on the door handle. That may not look important, but pollen can connect a person to a specific place.\n\nWhat do you think this clue tells us?"

	add_dialogue_button("I think I know.", show_pollen_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_pollen_without_reward)


func show_pollen_question():
	clear_buttons()

	set_dialogue_text(
		"Dr. Lin",
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
	reputation += 10
	reputation_label.text = "Reputation: " + str(reputation)

	clear_buttons()
	message_label.text = "Correct.\n\nDr. Lin:\nGood reasoning. Pollen grains can help identify where someone has been, especially if the pollen matches a plant from a specific room such as the greenhouse.\n\nEvidence added: Greenhouse Pollen"

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func on_pollen_wrong():
	clear_buttons()
	message_label.text = "Not quite.\n\nDr. Lin:\nPollen can act like biological trace evidence. If it matches a plant from the greenhouse, it may show that someone recently came from there.\n\nEvidence added: Greenhouse Pollen"

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_pollen_without_reward():
	clear_buttons()
	message_label.text = "Dr. Lin:\nThat's okay. Pollen is useful because different plants can produce different pollen patterns. If we match this pollen to the greenhouse, it can connect a suspect to that location.\n\nEvidence added: Greenhouse Pollen"

	collect_pollen_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_pollen_evidence():
	pollen_collected = true

	if not evidence_items.has("greenhouse_pollen"):
		evidence_items.append("greenhouse_pollen")

	if pollen_node != null:
		pollen_node.color = Color(0.45, 0.35, 0.05, 0.7)

	update_evidence_board_text()
	update_objective_text()
func show_gardener_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Gardener")
	message_panel.visible = true

	if evidence_items.has("greenhouse_pollen"):
		message_label.text = "Gardener:\nPollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything.\n\nDr. Lin:\nHe is right that pollen alone is not proof. But if it appears on a locked door handle, it may show that someone from the greenhouse touched it recently."
	else:
		message_label.text = "Gardener:\nI was working near the greenhouse earlier. I did not enter the locked rooms.\n\nDr. Lin:\nWe should look for biological trace evidence before deciding whether that is true."

	show_continue_button("Continue", close_message_panel)
func create_circuit_clue():
	circuit_position = cell_to_world(Vector2i(23, 13))

	circuit_node = ColorRect.new()
	circuit_node.name = "CircuitClue"
	circuit_node.color = Color(0.15, 0.65, 0.95, 1.0)
	circuit_node.size = Vector2(26, 20)
	circuit_node.position = circuit_position - circuit_node.size / 2
	circuit_node.z_index = 5

	add_child(circuit_node)
	add_world_label(circuit_node, "circuit", Vector2(-36, -24))


func create_mechanic_npc():
	mechanic_position = cell_to_world(Vector2i(23, 17))

	mechanic_node = ColorRect.new()
	mechanic_node.name = "MechanicNPC"
	mechanic_node.color = Color(0.25, 0.28, 0.75, 1.0)
	mechanic_node.size = Vector2(24, 28)
	mechanic_node.position = mechanic_position - mechanic_node.size / 2
	mechanic_node.z_index = 6

	add_child(mechanic_node)
	add_world_label(mechanic_node, "Mechanic", Vector2(-28, -24))
func show_circuit_intro():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThe wall panel has burn marks, and the lights went out right before the chase began.\n\nThis may not be an accident. What do you think caused the blackout?"

	add_dialogue_button("I think I know.", show_circuit_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_circuit_without_reward)


func show_circuit_question():
	clear_buttons()

	set_dialogue_text(
		"Dr. Lin",
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
	reputation += 10
	reputation_label.text = "Reputation: " + str(reputation)

	clear_buttons()
	message_label.text = "Correct.\n\nDr. Lin:\nExactly. A short circuit can allow too much current to flow, producing heat and burn marks. This suggests the blackout may have been caused deliberately.\n\nEvidence added: Deliberate Short Circuit"

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func on_circuit_wrong():
	clear_buttons()
	message_label.text = "Not quite.\n\nDr. Lin:\nThe burn marks suggest excess current and heat. A short circuit could explain the sudden blackout, which means someone may have caused it on purpose.\n\nEvidence added: Deliberate Short Circuit"

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func explain_circuit_without_reward():
	clear_buttons()
	message_label.text = "Dr. Lin:\nA short circuit creates a path with very low resistance. That can cause a large current, heat, and burn marks.\n\nSo the blackout may not be accidental. Someone may have used the circuit panel to create confusion.\n\nEvidence added: Deliberate Short Circuit"

	collect_circuit_evidence()
	show_continue_button("Continue", close_message_panel)


func collect_circuit_evidence():
	circuit_collected = true

	if not evidence_items.has("deliberate_short_circuit"):
		evidence_items.append("deliberate_short_circuit")

	if circuit_node != null:
		circuit_node.color = Color(0.05, 0.25, 0.35, 0.7)

	update_evidence_board_text()
	update_objective_text()
func show_mechanic_dialogue():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Mechanic")
	message_panel.visible = true

	if evidence_items.has("deliberate_short_circuit"):
		message_label.text = "Mechanic:\nA short circuit? I maintain the castle wiring, but anyone could have damaged that panel.\n\nDr. Lin:\nMaybe. But the burn pattern suggests the blackout was triggered intentionally. Someone who understands circuits would know exactly where to interfere."
	else:
		message_label.text = "Mechanic:\nThe lights in this castle fail all the time. Old wiring, old walls, old problems.\n\nDr. Lin:\nMaybe, but we should inspect the circuit panel before accepting that explanation."

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
	final_room_position = cell_to_world(Vector2i(54, 5))

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
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true

	if not has_all_evidence():
		message_label.text = "Dr. Lin:\nNot yet. We still need enough evidence before making a final accusation.\n\nCollected evidence:\n" + get_evidence_progress_text()
		add_dialogue_button("Continue", close_message_panel)
		return

	message_label.text = "Dr. Lin:\nWe have three major pieces of evidence now:\n\n1. The red stain may have been staged.\n2. The pollen links someone to the greenhouse area.\n3. The blackout was likely caused by a deliberate short circuit.\n\nWho do you accuse?"

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
	message_label.text = "CASE SOLVED\n\nYou accused the Mechanic.\n\nDr. Lin:\nCorrect. The strongest clue is the deliberate short circuit. The blackout gave the murderer time to move through the castle while everyone else was confused.\n\nThe staged red stain and greenhouse trace evidence were distractions, but together they helped reveal how the crime scene was manipulated.\n\nFinal Reputation: " + str(reputation) + "\n\nPress R to restart.\nPress M for main menu."


func show_wrong_accusation_ending(suspect_id: String):
	game_over = true

	player.set_physics_process(false)

	if enemy != null:
		enemy.set_physics_process(false)

	var suspect_name = suspect_id.capitalize()

	message_panel.visible = true
	message_label.text = "WRONG ACCUSATION\n\nYou accused the " + suspect_name + ".\n\nDr. Lin:\nThat does not fully explain the deliberate blackout. The evidence suggests someone with electrical knowledge used the circuit panel to create confusion.\n\nThe real culprit escaped in the darkness.\n\nFinal Reputation: " + str(reputation) + "\n\nPress R to restart.\nPress M for main menu."
func restart_current_game():
	get_tree().reload_current_scene()


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

	if has_all_evidence():
		objective_summary_label.text = "Objective: Go to Final Deduction Room   [O: Details]"
	else:
		objective_summary_label.text = "Objective: Evidence " + str(collected_count) + "/3   [O: Details]"

	if objective_detail_label == null:
		return

	var red_status = "✓" if red_done else "✗"
	var pollen_status = "✓" if pollen_done else "✗"
	var circuit_status = "✓" if circuit_done else "✗"

	var detail = "Current Mission:\n\n"
	if not circuit_door_open:
		detail += "Locked Door:\n"
		if learned_circuit_rule:
			detail += "✓ Circuit rule learned. Return to the locked door and solve the puzzle.\n\n"
		else:
			detail += "✗ Circuit rule unknown. Find and read the maintenance note near the locked door.\n\n"
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
func add_world_label(parent_node: Control, text: String, offset: Vector2):
	var label = Label.new()
	label.text = text
	label.position = offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(label)
	return label
func create_follow_camera():
	follow_camera = Camera2D.new()
	follow_camera.name = "FollowCamera"
	follow_camera.position = Vector2.ZERO
	follow_camera.zoom = Vector2(1.0, 1.0)
	follow_camera.enabled = true

	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0

	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = MAP_PIXEL_WIDTH
	follow_camera.limit_bottom = MAP_PIXEL_HEIGHT

	player.add_child(follow_camera)
	follow_camera.make_current()
func create_locked_circuit_door():
	# This door blocks a passage into the lower / circuit side of the castle.
	var cells = [
		Vector2i(21, 8),
		Vector2i(22, 8),
		Vector2i(23, 8)
	]

	circuit_door_position = cell_to_world(Vector2i(22, 8))

	for cell in cells:
		add_door_cell(cell)
func add_door_cell(cell: Vector2i):
	var key = cell_key(cell)

	if door_cells.has(key):
		return

	door_cells[key] = true

	var door = StaticBody2D.new()
	door.name = "LockedDoor"
	door.position = cell_to_world(cell)

	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rectangle
	door.add_child(shape)

	var visual = ColorRect.new()
	visual.color = Color(0.95, 0.48, 0.12, 1.0)
	visual.size = Vector2(CELL_SIZE, CELL_SIZE)
	visual.position = Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2)
	door.add_child(visual)

	add_child(door)
	door_nodes[key] = door

	# Make the door block A* navigation.
	astar_grid.set_point_solid(cell, true)
func is_door(cell: Vector2i) -> bool:
	return door_cells.has(cell_key(cell))


func blocks_vision(cell: Vector2i) -> bool:
	return is_wall(cell) or is_door(cell)
func show_circuit_door_puzzle():
	if not learned_circuit_rule:
		show_circuit_door_hint()
		return

	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	set_dialogue_text(
	"Dr. Lin",
	"Locked Door Puzzle:\nA metal door is controlled by a simple electric circuit.\n\nRemember the maintenance note:\nCurrent decreases when resistance increases.\n\nQuestion:\nWhich change would reduce current in the circuit?"
	)

	add_door_answer_button("A. Increase resistance", true)
	add_door_answer_button("B. Remove all resistance", false)
	add_door_answer_button("C. Add a short circuit", false)
	add_door_answer_button("D. Replace wires with water", false)
func add_door_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(780, 28)
	button.add_theme_font_size_override("font_size", 15)

	if is_correct:
		button.pressed.connect(on_door_puzzle_correct)
	else:
		button.pressed.connect(on_door_puzzle_wrong)

	button_box.add_child(button)
func on_door_puzzle_correct():
	reputation += 5
	reputation_label.text = "Reputation: " + str(reputation)

	clear_buttons()
	message_label.text = "Correct.\n\nDr. Lin:\nIncreasing resistance reduces current. The circuit stabilizes, and the door unlocks.\n\nDoor opened."

	open_circuit_door()
	show_continue_button("Continue", close_message_panel)
func on_door_puzzle_wrong():
	clear_buttons()
	message_label.text = "Not quite.\n\nDr. Lin:\nCurrent decreases when resistance increases. A short circuit would do the opposite by allowing too much current to flow.\n\nI will override the lock this time.\n\nDoor opened."

	open_circuit_door()
	show_continue_button("Continue", close_message_panel)
func open_circuit_door():
	circuit_door_open = true

	for key in door_nodes.keys():
		var door = door_nodes[key]
		if door != null:
			door.queue_free()

	for key in door_cells.keys():
		var cell = string_to_cell(key)
		astar_grid.set_point_solid(cell, false)

	door_nodes.clear()
	door_cells.clear()

	update_fog_of_war()
	update_objective_text()
func create_circuit_learning_note():
	circuit_note_position = cell_to_world(Vector2i(22, 7))

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
	set_dialogue_speaker("Dr. Lin")
	learned_circuit_rule = true
	add_knowledge_item("current_resistance")
	if circuit_note_node != null:
		circuit_note_node.color = Color(0.55, 0.52, 0.25, 0.75)

	message_panel.visible = true
	message_label.text = "Maintenance Note:\n\n\"The circuit lock overheats when current becomes too high. Increase resistance to reduce current flow. Never bypass the resistor.\"\n\nDr. Lin:\nThis note gives us the rule we need. If current is too high, increasing resistance can reduce it.\n\nConcept learned: Current decreases when resistance increases."

	update_objective_text()
	show_continue_button("Continue", close_message_panel)
func show_circuit_door_hint():
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThis lock uses an electrical rule, but we have not confirmed the rule yet.\n\nLook nearby for a maintenance note or circuit clue before forcing an answer."

	show_continue_button("Continue", close_message_panel)
func show_intro_dialogue():
	if intro_seen:
		return

	intro_seen = true
	start_dialogue_pause()
	clear_buttons()
	set_dialogue_speaker("Dr. Lin")
	message_panel.visible = true
	message_label.text = "Dr. Lin:\nDetective, you are inside Shadow Castle.\n\nThis castle once belonged to Lord Ashford, a scholar who believed knowledge was the only true key.\n\nHe designed many doors as knowledge locks. They do not open with ordinary keys. They open when someone understands the question written on them."

	show_continue_button("Continue", show_intro_dialogue_page_two)
func open_objectives_from_intro():
	intro_reviewing_objectives = true
	message_panel.visible = false
	clear_buttons()

	open_objective_panel()
func show_intro_dialogue_page_two():
	clear_buttons()

	set_dialogue_text(
		"Dr. Lin",
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
	subtitle.text = "Concepts you have learned from notes, clues, and Dr. Lin."
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
func add_knowledge_item(item_id: String):
	if not knowledge_items.has(item_id):
		knowledge_items.append(item_id)

	update_knowledge_journal_text()
	update_objective_text()
func update_knowledge_journal_text():
	if knowledge_list_label == null:
		return

	if knowledge_items.size() == 0:
		knowledge_list_label.text = "No concepts learned yet.\n\nExplore the castle, read notes, inspect clues, and listen to Dr. Lin to build your knowledge."
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
	if dialogue_speaker_label == null:
		return

	dialogue_speaker_label.text = speaker_name
	dialogue_portrait_name.text = speaker_name

	if speaker_name == "Dr. Lin":
		dialogue_portrait_color.color = Color(0.25, 0.55, 0.95, 1.0)
	elif speaker_name == "Detective":
		dialogue_portrait_color.color = Color(0.2, 0.75, 0.85, 1.0)
	elif speaker_name == "Butler":
		dialogue_portrait_color.color = Color(0.55, 0.35, 0.16, 1.0)
	elif speaker_name == "Gardener":
		dialogue_portrait_color.color = Color(0.1, 0.55, 0.18, 1.0)
	elif speaker_name == "Mechanic":
		dialogue_portrait_color.color = Color(0.25, 0.28, 0.75, 1.0)
	else:
		dialogue_portrait_color.color = Color(0.45, 0.45, 0.55, 1.0)
func set_dialogue_text(speaker_name: String, text: String):
	set_dialogue_speaker(speaker_name)
	message_label.text = text
	reset_dialogue_scrolls()
func show_continue_button(text: String, callback: Callable):
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

	if dialogue_portrait_box != null:
		dialogue_portrait_box.add_theme_stylebox_override(
			"panel",
			make_panel_style(Color(0.08, 0.08, 0.11, 0.98), Color(0.42, 0.33, 0.16, 1.0), 1, 8)
		)

	if dialogue_speaker_label != null:
		dialogue_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))

	if dialogue_portrait_name != null:
		dialogue_portrait_name.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))

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
