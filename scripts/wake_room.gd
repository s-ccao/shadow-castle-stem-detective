extends Node2D

const ROOM_WIDTH := 1024
const ROOM_HEIGHT := 768
const WALL_THICKNESS := 32

const USE_IMAGE_BACKGROUND := true
const WAKE_ROOM_BACKGROUND := "res://assets/backgrounds/wake_room_bg.png"

const SHOW_DEBUG_OBJECTS := false
const SHOW_DEBUG_WALLS := false

@onready var player = $player

var ui_layer: CanvasLayer
var message_panel: Panel
var message_label: Label
var button_box: VBoxContainer
var interact_label: Label

var dr_lin_position := Vector2(610, 360)
var door_position := Vector2(930, 360)

var dialogue_active := false
var current_interaction := ""

var first_lock_rule_learned := false
var exit_door_unlocked := false

var clue_position := Vector2(210, 185)
var clue_node: ColorRect


func _ready():
	create_room()
	create_dr_lin()
	create_door()
	create_first_room_clue()
	create_ui()

	player.position = Vector2(360, 390)
	show_wake_dialogue()


func _process(delta):
	if dialogue_active:
		return

	update_interaction_prompt()

	if Input.is_action_just_pressed("interact"):
		if current_interaction == "dr_lin":
			show_dr_lin_guidance()
		elif current_interaction == "room_clue":
			show_first_room_clue()
		elif current_interaction == "door":
			handle_exit_door()


func create_room():
	if USE_IMAGE_BACKGROUND:
		create_room_background()
	else:
		var floor = ColorRect.new()
		floor.color = Color(0.09, 0.085, 0.10, 1.0)
		floor.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
		floor.z_index = -10
		add_child(floor)

	add_wall(Vector2(ROOM_WIDTH / 2, WALL_THICKNESS / 2), Vector2(ROOM_WIDTH, WALL_THICKNESS))
	add_wall(Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT - WALL_THICKNESS / 2), Vector2(ROOM_WIDTH, WALL_THICKNESS))
	add_wall(Vector2(WALL_THICKNESS / 2, ROOM_HEIGHT / 2), Vector2(WALL_THICKNESS, ROOM_HEIGHT))
	add_wall(Vector2(ROOM_WIDTH - WALL_THICKNESS / 2, ROOM_HEIGHT / 2), Vector2(WALL_THICKNESS, ROOM_HEIGHT))

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


func create_room_background():
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


func add_wall(center_position: Vector2, size: Vector2):
	var wall = StaticBody2D.new()
	wall.position = center_position

	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)

	if SHOW_DEBUG_WALLS:
		var visual = ColorRect.new()
		visual.color = Color(0.20, 0.16, 0.27, 0.45)
		visual.size = size
		visual.position = -size / 2
		wall.add_child(visual)

	add_child(wall)


func create_dr_lin():
	var dr_lin = ColorRect.new()
	dr_lin.name = "DrLin"
	dr_lin.color = Color(0.25, 0.55, 0.95, 1.0)
	dr_lin.size = Vector2(28, 36)
	dr_lin.position = dr_lin_position - dr_lin.size / 2
	dr_lin.z_index = 5
	add_child(dr_lin)

	var label = Label.new()
	label.text = "Dr. Lin"
	label.position = dr_lin_position + Vector2(-25, -50)
	label.add_theme_font_size_override("font_size", 15)
	label.z_index = 10
	add_child(label)


func create_door():
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


func create_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	interact_label = Label.new()
	interact_label.text = ""
	interact_label.position = Vector2(330, 690)
	interact_label.visible = false
	interact_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(interact_label)

	message_panel = Panel.new()
	message_panel.position = Vector2(70, 440)
	message_panel.size = Vector2(880, 250)
	message_panel.visible = false
	ui_layer.add_child(message_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	message_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 20)
	margin.size = Vector2(832, 210)
	message_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 19)
	message_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	message_label.custom_minimum_size = Vector2(820, 120)
	layout.add_child(message_label)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 8)
	layout.add_child(button_box)


func show_wake_dialogue():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Dr. Lin:\nYou're awake. Good.\n\nListen carefully. We are inside Shadow Castle. I found you unconscious in this room, and something is moving outside.\n\nBefore we leave, make sure you can move. Use WASD to walk, and press E when you need to interact."

	add_dialogue_button("I understand.", close_message_panel)


func show_dr_lin_guidance():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Dr. Lin:\nThis castle was built around knowledge locks. Many doors will not open unless you understand the science behind them.\n\nDo not guess. Look for notes, clues, and evidence. I will help explain what we find.\n\nTry the door first. If the lock asks a question, search the room for the answer."

	add_dialogue_button("Continue", close_message_panel)


func update_interaction_prompt():
	current_interaction = ""
	interact_label.visible = false

	var lin_distance = player.global_position.distance_to(dr_lin_position)
	if lin_distance < 70:
		current_interaction = "dr_lin"
		interact_label.text = "Press E to talk to Dr. Lin"
		interact_label.visible = true
		return

	if not first_lock_rule_learned:
		var clue_distance = player.global_position.distance_to(clue_position)
		if clue_distance < 65:
			current_interaction = "room_clue"
			interact_label.text = "Press E to read the candle note"
			interact_label.visible = true
			return

	var door_distance = player.global_position.distance_to(door_position)
	if door_distance < 85:
		current_interaction = "door"

		if exit_door_unlocked:
			interact_label.text = "Press E to enter the castle hall"
		elif first_lock_rule_learned:
			interact_label.text = "Press E to solve the knowledge lock"
		else:
			interact_label.text = "Press E to inspect the locked door"

		interact_label.visible = true
		return


func handle_exit_door():
	if exit_door_unlocked:
		leave_wake_room()
		return

	if first_lock_rule_learned:
		show_first_door_question()
	else:
		show_locked_door_intro()


func show_locked_door_intro():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "The exit door glows with a faint purple light.\n\nA question appears on the lock:\n\n\"What does a flame need from the air to keep burning?\"\n\nDr. Lin:\nDo not guess. Lord Ashford designed these locks so the answer can be learned nearby. Search the room first. Look for notes, candles, or anything connected to the question."

	add_dialogue_button("I'll search the room.", close_message_panel)


func show_first_room_clue():
	start_dialogue_pause()
	clear_buttons()

	first_lock_rule_learned = true

	if clue_node != null:
		clue_node.color = Color(0.45, 0.38, 0.12, 0.7)

	message_panel.visible = true
	message_label.text = "Candle Note:\n\n\"A flame cannot keep burning without oxygen from the air. If the air supply is blocked, the flame weakens and dies.\"\n\nDr. Lin:\nThat's the clue we needed. The lock asked what a flame needs from the air.\n\nConcept learned: Fire needs oxygen to keep burning."

	add_dialogue_button("Return to the door.", close_message_panel)


func show_first_door_question():
	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Knowledge Lock:\n\nThe same question appears again:\n\n\"What does a flame need from the air to keep burning?\"\n\nDr. Lin:\nUse the candle note. What did it say?"

	add_first_lock_answer_button("A. Oxygen", true)
	add_first_lock_answer_button("B. Stone dust", false)
	add_first_lock_answer_button("C. Purple paint", false)
	add_first_lock_answer_button("D. Silence", false)


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

	clear_buttons()
	message_label.text = "Correct.\n\nDr. Lin:\nYes. Fire needs oxygen from the air. The knowledge lock recognized the answer.\n\nThe door unlocks with a heavy click.\n\nBeyond this room is the main castle hall. Stay alert."

	add_dialogue_button("Enter the Castle Hall", leave_wake_room)


func on_first_lock_wrong():
	clear_buttons()

	message_label.text = "Not quite.\n\nDr. Lin:\nThink back to the candle note. It said a flame needs something from the air to keep burning.\n\nTry again."

	add_dialogue_button("Try Again", show_first_door_question)
	add_dialogue_button("Review the clue again", show_first_room_clue)


func leave_wake_room():
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func add_dialogue_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(820, 36)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	button_box.add_child(button)


func clear_buttons():
	for child in button_box.get_children():
		child.queue_free()


func close_message_panel():
	message_panel.visible = false
	clear_buttons()
	end_dialogue_pause()


func start_dialogue_pause():
	dialogue_active = true
	current_interaction = ""

	if interact_label != null:
		interact_label.visible = false

	player.set_physics_process(false)


func end_dialogue_pause():
	dialogue_active = false
	player.set_physics_process(true)
