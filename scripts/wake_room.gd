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
var message_scroll: ScrollContainer
var button_box: HBoxContainer
var interact_label: Label
var puzzle_panel: Panel
var puzzle_question_label: Label
var puzzle_button_box: VBoxContainer
var puzzle_open := false
var top_left_bar: HBoxContainer
var notes_button: Button

var knowledge_panel: Panel
var knowledge_label: Label
var knowledge_panel_open := false
var notes_unlocked := false
var notes_tutorial_seen := false
var dr_lin_position := Vector2(610, 360)

# These are invisible interaction hotspots.
# Adjust these numbers later to match the final background image.
var door_position := Vector2(900, 430)
var clue_position := Vector2(720, 185)

const LIN_INTERACT_RADIUS := 75.0
const DOOR_INTERACT_RADIUS := 150.0
const CLUE_INTERACT_RADIUS := 140.0
const SHOW_INTERACTION_MARKERS := true

var dialogue_active := false
var current_interaction := ""

var first_lock_rule_learned := false
var exit_door_unlocked := false

var clue_node: ColorRect
var door_marker_node: ColorRect


func _ready():
	create_room()
	create_dr_lin()
	create_door()
	create_first_room_clue()
	create_ui()

	player.position = Vector2(360, 390)
	show_wake_dialogue()

func _process(delta):
	if Input.is_action_just_pressed("knowledge_journal"):
		if notes_unlocked:
			toggle_knowledge_panel()
		return

	if dialogue_active or puzzle_open or knowledge_panel_open:
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

	if SHOW_INTERACTION_MARKERS:
		door_marker_node = ColorRect.new()
		door_marker_node.name = "DoorInteractionMarker"
		door_marker_node.color = Color(0.75, 0.45, 1.0, 0.75)
		door_marker_node.size = Vector2(18, 18)
		door_marker_node.position = door_position - door_marker_node.size / 2
		door_marker_node.z_index = 20
		add_child(door_marker_node)


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


func create_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)

	interact_label = Label.new()
	interact_label.text = ""
	interact_label.position = Vector2(310, 725)
	interact_label.visible = false
	interact_label.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(interact_label)

	message_panel = Panel.new()
	message_panel.position = Vector2(70, 420)
	message_panel.size = Vector2(880, 280)
	message_panel.visible = false
	ui_layer.add_child(message_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	message_panel.add_theme_stylebox_override("panel", style)

	# Text area: fixed at the top.
	message_scroll = ScrollContainer.new()
	message_scroll.position = Vector2(24, 20)
	message_scroll.size = Vector2(832, 180)
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_panel.add_child(message_scroll)

	message_label = Label.new()
	message_label.text = ""
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	message_label.custom_minimum_size = Vector2(810, 260)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.add_child(message_label)

	# Button row: fixed at the very bottom of the dialogue box.
	button_box = HBoxContainer.new()
	button_box.position = Vector2(24, 220)
	button_box.size = Vector2(832, 42)
	button_box.add_theme_constant_override("separation", 8)
	message_panel.add_child(button_box)

	create_top_left_hud()
	create_knowledge_panel_ui()
	create_puzzle_overlay_ui()

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
	if lin_distance < LIN_INTERACT_RADIUS:
		current_interaction = "dr_lin"
		interact_label.text = "Press E to talk to Dr. Lin"
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
	reset_dialogue_scrolls()
	add_dialogue_button("I'll search the room.", close_message_panel)


func show_first_room_clue():
	start_dialogue_pause()
	clear_buttons()

	first_lock_rule_learned = true
	unlock_notes_tool()
	update_knowledge_panel_text()
	if clue_node != null:
		clue_node.color = Color(0.45, 0.38, 0.12, 0.7)

	message_panel.visible = true
	message_label.text = "Candle Note:\n\n\"A flame cannot keep burning without oxygen from the air. If the air supply is blocked, the flame weakens and dies.\"\n\nDr. Lin:\nThat's the clue we needed. The lock asked what a flame needs from the air.\n\nConcept learned: Fire needs oxygen to keep burning."
	reset_dialogue_scrolls()
	add_dialogue_button("Return to the door.", close_message_panel)


func show_first_door_question():
	open_puzzle_overlay()
	clear_puzzle_buttons()

	puzzle_question_label.text = "Question:\n\n\"What does a flame need from the air to keep burning?\"\n\nUse the clue you found in the room. You can check your notes before answering."

	add_puzzle_answer_button("A. Oxygen", true)
	add_puzzle_answer_button("B. Stone dust", false)
	add_puzzle_answer_button("C. Purple paint", false)
	add_puzzle_answer_button("D. Silence", false)

	
	add_puzzle_action_button("Let me think", close_puzzle_overlay)

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

	if door_marker_node != null:
		door_marker_node.color = Color(0.25, 0.95, 0.45, 0.85)

	puzzle_panel.visible = false
	puzzle_open = false
	clear_puzzle_buttons()

	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Correct.\n\nDr. Lin:\nYes. Fire needs oxygen from the air. The knowledge lock recognized the answer.\n\nThe door unlocks with a heavy click.\n\nYou can enter the castle hall now, or stay here and review the room first."
	reset_dialogue_scrolls()

	add_dialogue_button("Stay in this room", close_message_panel)
	add_dialogue_button("Enter the Castle Hall", leave_wake_room)


func on_first_lock_wrong():
	puzzle_panel.visible = false
	puzzle_open = false
	clear_puzzle_buttons()

	start_dialogue_pause()
	clear_buttons()

	message_panel.visible = true
	message_label.text = "Not quite.\n\nDr. Lin:\nThink back to the candle note. It said a flame needs something from the air to keep burning.\n\nYou can try again, review your notes, or take more time to think."

	add_dialogue_button("Try Again", show_first_door_question)
	add_dialogue_button("Review Notes", open_knowledge_panel_from_dialogue)
	add_dialogue_button("Let me think", close_message_panel)

func leave_wake_room():
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func add_dialogue_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	button_box.add_child(button)


func clear_buttons():
	for child in button_box.get_children():
		child.queue_free()

	if message_scroll != null:
		message_scroll.scroll_vertical = 0
		message_scroll.set_deferred("scroll_vertical", 0)


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
	
func reset_dialogue_scrolls():
	if message_scroll != null:
		message_scroll.scroll_vertical = 0
		message_scroll.set_deferred("scroll_vertical", 0)

	
func create_puzzle_overlay_ui():
	puzzle_panel = Panel.new()
	puzzle_panel.position = Vector2(170, 120)
	puzzle_panel.size = Vector2(680, 500)
	puzzle_panel.visible = false
	puzzle_panel.z_index = 50
	ui_layer.add_child(puzzle_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.055, 0.97)
	style.border_color = Color(0.85, 0.68, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	puzzle_panel.add_theme_stylebox_override("panel", style)

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
	puzzle_panel.z_index = 50
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

	puzzle_question_label.text = "Knowledge Notes:\n\nCandle Note:\n\"A flame cannot keep burning without oxygen from the air. If the air supply is blocked, the flame weakens and dies.\"\n\nDr. Lin's Explanation:\nThe lock asks what a flame needs from the air. The note tells us that the important substance is oxygen.\n\nConcept:\nFire needs oxygen to keep burning."

	add_puzzle_action_button("Back to Question", show_first_door_question)
	add_puzzle_action_button("Let me think", close_puzzle_overlay)
func show_first_lock_notes_from_dialogue():
	message_panel.visible = false
	clear_buttons()
	open_puzzle_overlay()
	show_first_lock_notes()
func create_top_left_hud():
	top_left_bar = HBoxContainer.new()
	top_left_bar.position = Vector2(18, 18)
	top_left_bar.size = Vector2(340, 44)
	top_left_bar.z_index = 300
	top_left_bar.add_theme_constant_override("separation", 8)
	ui_layer.add_child(top_left_bar)

	notes_button = Button.new()
	notes_button.text = "Notes [K]"
	notes_button.custom_minimum_size = Vector2(115, 38)
	notes_button.add_theme_font_size_override("font_size", 15)
	notes_button.pressed.connect(toggle_knowledge_panel)
	notes_button.visible = false
	notes_button.disabled = true
	top_left_bar.add_child(notes_button)
func create_knowledge_panel_ui():
	knowledge_panel = Panel.new()
	knowledge_panel.position = Vector2(160, 95)
	knowledge_panel.size = Vector2(720, 560)
	knowledge_panel.visible = false
	knowledge_panel.z_index = 200
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
func toggle_knowledge_panel():
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

	player.set_physics_process(false)

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
		text += "Candle Note\n\n"
		text += "Observation:\nA note near the candle explains that a flame cannot keep burning without oxygen from the air.\n\n"
		text += "Science Concept:\nFire needs oxygen to keep burning. If oxygen is removed or blocked, the flame weakens and goes out.\n\n"
		text += "How to Apply It:\nIf the knowledge lock asks what a flame needs from the air, the answer is oxygen."

	knowledge_label.text = text
func open_knowledge_panel_from_dialogue():
	message_panel.visible = false
	clear_buttons()
	open_knowledge_panel()
func unlock_notes_tool():
	if notes_unlocked:
		return

	notes_unlocked = true

	if notes_button != null:
		notes_button.visible = true
		notes_button.disabled = false
