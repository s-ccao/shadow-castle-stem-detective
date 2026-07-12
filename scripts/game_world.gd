extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 32
const MAP_HEIGHT := 24
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

@onready var player = $player

var wall_cells := {}
var fog_cells := {}
var discovered_fog_cells := {}
var visible_fog_cells := {}
var visible_fog_distances := {}
@onready var enemy = get_node_or_null("enemy")

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
var reputation_label: Label
var interact_label: Label
var dialogue_active := false
var evidence_items: Array[String] = []
var evidence_panel: Panel
var evidence_label: Label
var evidence_board_open := false
var evidence_hint_label: Label

var butler_position := Vector2.ZERO
var butler_node: ColorRect
var current_interaction := ""
func _ready():
	create_floor()
	create_castle_walls()
	build_navigation_grid()
	create_red_stain_clue()
	create_butler_npc()
	create_fog_cells()
	create_game_ui()
	create_game_over_ui()
	move_player_to_cell(Vector2i(2, 2))
	setup_enemy()


func _process(delta):
	if game_over:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if dialogue_active:
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
	# Border walls
	for x in range(MAP_WIDTH):
		add_wall_cell(Vector2i(x, 0))
		add_wall_cell(Vector2i(x, MAP_HEIGHT - 1))

	for y in range(MAP_HEIGHT):
		add_wall_cell(Vector2i(0, y))
		add_wall_cell(Vector2i(MAP_WIDTH - 1, y))

	# Interior castle maze walls
	add_wall_rect(Vector2i(6, 1), Vector2i(6, 8))
	add_wall_rect(Vector2i(12, 3), Vector2i(12, 14))
	add_wall_rect(Vector2i(20, 2), Vector2i(20, 10))
	add_wall_rect(Vector2i(26, 6), Vector2i(26, 18))

	add_wall_rect(Vector2i(3, 5), Vector2i(10, 5))
	add_wall_rect(Vector2i(14, 8), Vector2i(23, 8))
	add_wall_rect(Vector2i(2, 12), Vector2i(9, 12))
	add_wall_rect(Vector2i(16, 15), Vector2i(27, 15))
	add_wall_rect(Vector2i(8, 19), Vector2i(22, 19))


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

		if is_wall(sample_cell):
			# The wall itself can be seen.
			# But anything behind the wall cannot be seen.
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

	enemy.position = cell_to_world(Vector2i(29, 21))
	enemy.setup(self, player)


func create_game_over_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER\nThe murderer caught you.\nPress R to restart."
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
	evidence_hint_label.text = "B: Evidence Board"
	evidence_hint_label.position = Vector2(20, 50)
	evidence_hint_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(evidence_hint_label)

	interact_label = Label.new()
	interact_label.text = "Press E to investigate"
	interact_label.position = Vector2(380, 700)
	interact_label.visible = false
	interact_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(interact_label)

	message_panel = Panel.new()
	message_panel.position = Vector2(190, 150)
	message_panel.size = Vector2(650, 430)
	message_panel.visible = false
	ui_layer.add_child(message_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(20, 20)
	margin.size = Vector2(610, 390)
	message_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.custom_minimum_size = Vector2(580, 170)
	layout.add_child(message_label)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 10)
	layout.add_child(button_box)

	create_evidence_board_ui()


func update_interaction_prompt():
	current_interaction = ""
	interact_label.visible = false

	if message_panel.visible or evidence_board_open:
		return

	if not evidence_collected:
		var clue_distance = player.global_position.distance_to(clue_position)

		if clue_distance < 55.0:
			current_interaction = "red_stain"
			interact_label.text = "Press E to investigate"
			interact_label.visible = true
			return

	var butler_distance = player.global_position.distance_to(butler_position)

	if butler_distance < 55.0:
		current_interaction = "butler"
		interact_label.text = "Press E to talk to Butler"
		interact_label.visible = true
		return


func try_investigate_clue():
	if current_interaction == "red_stain":
		show_clue_intro()
	elif current_interaction == "butler":
		show_butler_dialogue()


func show_clue_intro():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThis red liquid looks like blood at first glance, but a good detective never relies on color alone.\n\nWhat do you think caused the red color?"

	add_dialogue_button("I think I know.", show_red_stain_question)
	add_dialogue_button("I'm not sure. Please explain.", explain_red_stain_without_reward)


func show_red_stain_question():
	clear_buttons()

	message_label.text = "What most likely caused the red color?\n\nChoose carefully. You only get one attempt."

	add_answer_button("A. Real blood exposed to oxygen", false)
	add_answer_button("B. Indicator solution reacting with a basic cleaner", true)
	add_answer_button("C. Rust dissolved in water", false)
	add_answer_button("D. Red paint from the wall", false)


func add_answer_button(text: String, is_correct: bool):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(560, 42)

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
	add_dialogue_button("Continue", close_message_panel)


func on_red_stain_wrong():
	clear_buttons()
	message_label.text = "Not quite.\n\nDr. Lin:\nThe important clue is not just the color. If an indicator solution mixes with a basic cleaner, it can turn red or pink. This stain may be fake.\n\nEvidence added: Fake Red Stain"

	collect_red_stain_evidence()
	add_dialogue_button("Continue", close_message_panel)


func explain_red_stain_without_reward():
	clear_buttons()
	message_label.text = "Dr. Lin:\nThat's okay. A good detective knows when to ask for help.\n\nThe red color may come from an indicator solution reacting with a basic cleaner. So this does not prove it is blood. Someone may have staged the crime scene.\n\nEvidence added: Fake Red Stain"

	collect_red_stain_evidence()
	add_dialogue_button("Continue", close_message_panel)


func collect_red_stain_evidence():
	evidence_collected = true

	if not evidence_items.has("fake_red_stain"):
		evidence_items.append("fake_red_stain")

	if clue_node != null:
		clue_node.color = Color(0.35, 0.02, 0.04, 0.7)

	update_evidence_board_text()


func close_message_panel():
	message_panel.visible = false
	clear_buttons()
	end_dialogue_pause()


func clear_buttons():
	for child in button_box.get_children():
		child.queue_free()


func add_dialogue_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(560, 44)
	button.pressed.connect(callback)
	button_box.add_child(button)
func start_dialogue_pause():
	dialogue_active = true

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
	evidence_panel.position = Vector2(230, 110)
	evidence_panel.size = Vector2(570, 520)
	evidence_panel.visible = false
	ui_layer.add_child(evidence_panel)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 24)
	margin.size = Vector2(522, 472)
	evidence_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Evidence Board"
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	evidence_label = Label.new()
	evidence_label.text = "No evidence collected yet."
	evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_label.custom_minimum_size = Vector2(500, 340)
	evidence_label.add_theme_font_size_override("font_size", 21)
	layout.add_child(evidence_label)

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
	update_evidence_board_text()
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
	if evidence_items.size() == 0:
		evidence_label.text = "No evidence collected yet.\n\nExplore the castle and investigate suspicious clues."
		return

	var text = ""

	if evidence_items.has("fake_red_stain"):
		text += "Evidence 1: Fake Red Stain\n"
		text += "- Observation: A red liquid was found near white powder and a broken bottle.\n"
		text += "- Science: The color may come from an indicator reacting with a basic cleaner.\n"
		text += "- Reasoning: This does not prove it is blood. The scene may have been staged.\n"
		text += "- Suspect Link: Someone with access to cleaning supplies or chemical materials.\n\n"

	evidence_label.text = text
func create_butler_npc():
	butler_position = cell_to_world(Vector2i(9, 3))

	butler_node = ColorRect.new()
	butler_node.name = "ButlerNPC"
	butler_node.color = Color(0.55, 0.35, 0.16, 1.0)
	butler_node.size = Vector2(24, 28)
	butler_node.position = butler_position - butler_node.size / 2
	butler_node.z_index = 6

	add_child(butler_node)
func show_butler_dialogue():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true

	if evidence_items.has("fake_red_stain"):
		message_label.text = "Butler:\nI already told you, I only cleaned the hallway. That red stain has nothing to do with me.\n\nDr. Lin:\nInteresting. The stain may involve a basic cleaning substance. Someone with access to cleaning supplies could explain part of this clue."
	else:
		message_label.text = "Butler:\nI was only cleaning the hallway. I did not see anything unusual.\n\nDr. Lin:\nHe may know more than he is saying. We should collect physical evidence before making any accusation."

	add_dialogue_button("Continue", close_message_panel)
