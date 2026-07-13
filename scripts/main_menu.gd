extends Control


func _ready():
	create_menu_ui()


func create_menu_ui():
	var background = ColorRect.new()
	background.color = Color(0.04, 0.04, 0.07)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var layout = VBoxContainer.new()
	layout.custom_minimum_size = Vector2(620, 520)
	layout.add_theme_constant_override("separation", 18)
	center.add_child(layout)

	var title = Label.new()
	title.text = "Shadow Castle: STEM Detective"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	layout.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Solve scientific clues. Survive the darkness. Identify the murderer."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 22)
	layout.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(1, 24)
	layout.add_child(spacer)

	var controls = Label.new()
	controls.text = "Controls:\nWASD - Move\nE - Interact\nB - Evidence Board\nR - Restart after Game Over"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 22)
	layout.add_child(controls)

	var start_button = Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(420, 54)
	start_button.pressed.connect(start_game)
	layout.add_child(start_button)

	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(420, 48)
	quit_button.pressed.connect(quit_game)
	layout.add_child(quit_button)


func start_game():
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")


func quit_game():
	get_tree().quit()
