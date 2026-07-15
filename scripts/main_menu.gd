extends Control


func _ready():
	print("MAIN MENU READY")
	create_menu_ui()


func create_menu_ui():
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0

	var background = ColorRect.new()
	background.color = Color(0.03, 0.03, 0.06, 1.0)
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var title = Label.new()
	title.text = "Shadow Castle: STEM Detective"
	title.position = Vector2(210, 110)
	title.size = Vector2(620, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	add_child(title)

	var story = Label.new()
	story.text = "Lord Ashford believed knowledge was the only true key.\nMany doors in this castle open through STEM knowledge locks."
	story.position = Vector2(240, 210)
	story.size = Vector2(560, 100)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 22)
	add_child(story)

	var controls = Label.new()
	controls.text = "WASD - Move\nE - Interact\nB - Evidence Board\nO - Objectives\nR - Restart\nM - Main Menu"
	controls.position = Vector2(380, 330)
	controls.size = Vector2(300, 160)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 20)
	add_child(controls)

	var start_button = Button.new()
	start_button.text = "Start Investigation"
	start_button.position = Vector2(330, 540)
	start_button.size = Vector2(380, 56)
	start_button.pressed.connect(start_game)
	add_child(start_button)

	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.position = Vector2(330, 610)
	quit_button.size = Vector2(380, 48)
	quit_button.pressed.connect(quit_game)
	add_child(quit_button)


func start_game():
	get_tree().change_scene_to_file("res://scenes/intro_cutscene.tscn")


func quit_game():
	get_tree().quit()
