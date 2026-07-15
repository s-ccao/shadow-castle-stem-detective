extends Control

var page_index := 0

var pages := [
	{
		"title": "Shadow Castle",
		"body": "The storm began before midnight.\n\nFar beyond the town, an old castle stood alone on the hill."
	},
	{
		"title": "Lord Ashford",
		"body": "The castle once belonged to Lord Ashford.\n\nHe was a scholar, inventor, and collector of scientific mysteries."
	},
	{
		"title": "The Knowledge Locks",
		"body": "Ashford believed knowledge was the only true key.\n\nSo he built doors that opened through questions instead of ordinary keys."
	},
	{
		"title": "The Night of the Case",
		"body": "Tonight, something went wrong.\n\nA crime scene was staged. The lights failed. Strange clues appeared in locked rooms."
	},
	{
		"title": "The Darkness",
		"body": "Someone is still moving inside the castle.\n\nYou are not only investigating a mystery. You are being hunted."
	},
	{
		"title": "You Wake Up",
		"body": "You wake inside the castle with no clear memory of how you arrived.\n\nNearby, Dr. Lin is waiting."
	},
	{
		"title": "Dr. Lin",
		"body": "Dr. Lin understands the castle's science.\n\nBut she cannot solve the case alone."
	},
	{
		"title": "Your Investigation Begins",
		"body": "Observe. Learn. Solve the locks. Collect evidence.\n\nThe answer to each puzzle is usually hidden nearby."
	}
]

var title_label: Label
var body_label: Label
var page_label: Label
var continue_button: Button
var skip_button: Button
var background: ColorRect
var castle_shadow: ColorRect
var moon: ColorRect


func _ready():
	create_cutscene_ui()
	show_page()


func create_cutscene_ui():
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0

	background = ColorRect.new()
	background.color = Color(0.015, 0.015, 0.035, 1.0)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	# Placeholder moon
	moon = ColorRect.new()
	moon.color = Color(0.82, 0.82, 0.68, 0.75)
	moon.position = Vector2(790, 70)
	moon.size = Vector2(90, 90)
	add_child(moon)

	# Castle silhouette placeholder
	castle_shadow = ColorRect.new()
	castle_shadow.color = Color(0.02, 0.02, 0.025, 1.0)
	castle_shadow.position = Vector2(120, 150)
	castle_shadow.size = Vector2(780, 260)
	add_child(castle_shadow)

	var tower_left = ColorRect.new()
	tower_left.color = Color(0.015, 0.015, 0.02, 1.0)
	tower_left.position = Vector2(170, 90)
	tower_left.size = Vector2(110, 320)
	add_child(tower_left)

	var tower_right = ColorRect.new()
	tower_right.color = Color(0.015, 0.015, 0.02, 1.0)
	tower_right.position = Vector2(730, 110)
	tower_right.size = Vector2(110, 300)
	add_child(tower_right)

	var text_panel = Panel.new()
	text_panel.position = Vector2(90, 440)
	text_panel.size = Vector2(850, 230)
	add_child(text_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.03, 0.045, 0.95)
	panel_style.border_color = Color(0.72, 0.58, 0.28, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	text_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.position = Vector2(24, 18)
	margin.size = Vector2(802, 194)
	text_panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.text = ""
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38, 1.0))
	layout.add_child(title_label)

	var body_scroll = ScrollContainer.new()
	body_scroll.custom_minimum_size = Vector2(800, 92)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(body_scroll)

	body_label = Label.new()
	body_label.text = ""
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	body_label.custom_minimum_size = Vector2(770, 90)
	body_scroll.add_child(body_label)

	var bottom_row = HBoxContainer.new()
	bottom_row.custom_minimum_size = Vector2(800, 38)
	layout.add_child(bottom_row)

	page_label = Label.new()
	page_label.text = ""
	page_label.add_theme_font_size_override("font_size", 15)
	page_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70, 1.0))
	bottom_row.add_child(page_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(100, 32)
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.pressed.connect(skip_cutscene)
	bottom_row.add_child(skip_button)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 32)
	continue_button.add_theme_font_size_override("font_size", 15)
	continue_button.pressed.connect(next_page)
	bottom_row.add_child(continue_button)


func show_page():
	var page = pages[page_index]

	title_label.text = page["title"]
	body_label.text = page["body"]
	page_label.text = str(page_index + 1) + " / " + str(pages.size())

	if page_index == pages.size() - 1:
		continue_button.text = "Begin"
	else:
		continue_button.text = "Continue"

	update_background_for_page()


func update_background_for_page():
	if page_index == 0:
		background.color = Color(0.015, 0.015, 0.035, 1.0)
	elif page_index == 1:
		background.color = Color(0.025, 0.018, 0.04, 1.0)
	elif page_index == 2:
		background.color = Color(0.035, 0.01, 0.018, 1.0)
	elif page_index == 3:
		background.color = Color(0.018, 0.025, 0.035, 1.0)
	else:
		background.color = Color(0.015, 0.025, 0.025, 1.0)


func next_page():
	if page_index < pages.size() - 1:
		page_index += 1
		show_page()
	else:
		go_to_game()


func skip_cutscene():
	go_to_game()


func go_to_game():
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")
