extends Control

const MAIN_MENU_SCREEN_PATH: String = "res://assets/ui/screens/main_menu.png"
const MENU_WOOD_FRAME_PATH: String = "res://assets/ui/frames/menu_wood_frame.png"
const MENU_PURPLE_FRAME_PATH: String = "res://assets/ui/frames/menu_purple_frame.png"
const MENU_BANNER_FRAME_PATH: String = "res://assets/ui/frames/menu_banner_frame.png"
const MENU_EMPTY_FRAME_PATH: String = "res://assets/ui/frames/menu_empty_frame.png"

var menu_dialog_layer: CanvasLayer
var menu_dialog_overlay: ColorRect
var menu_dialog_frame: TextureRect
var menu_dialog_title: Label
var menu_dialog_text: Label
var menu_dialog_close_button: Button


func _ready() -> void:
	_connect_start_ui()
	create_menu_dialog()


func _connect_start_ui() -> void:
	var start_ui: Node = get_node_or_null("StartUI")
	if start_ui == null:
		push_error("StartUI scene instance is missing from MainMenu.")
		return
	if start_ui.has_method("set_continue_enabled"):
		start_ui.call("set_continue_enabled", GameState.has_saved_game())
	start_ui.start_requested.connect(start_game)
	start_ui.continue_requested.connect(_continue_game)
	start_ui.settings_requested.connect(_show_settings_dialog)
	start_ui.language_requested.connect(_show_language_dialog)
	start_ui.quit_requested.connect(quit_game)

func create_menu_dialog() -> void:
	menu_dialog_layer = CanvasLayer.new()
	menu_dialog_layer.name = "MainMenuDialogLayer"
	menu_dialog_layer.layer = 20
	menu_dialog_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_dialog_layer)

	menu_dialog_overlay = ColorRect.new()
	menu_dialog_overlay.name = "MainMenuDialogOverlay"
	menu_dialog_overlay.color = Color(0.0, 0.0, 0.02, 0.72)
	menu_dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_dialog_overlay.visible = false
	menu_dialog_layer.add_child(menu_dialog_overlay)

	menu_dialog_frame = TextureRect.new()
	menu_dialog_frame.name = "MainMenuDialogFrame"
	menu_dialog_frame.position = Vector2(96, 218)
	menu_dialog_frame.size = Vector2(832, 326)
	menu_dialog_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_dialog_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_dialog_frame.texture = load(MENU_EMPTY_FRAME_PATH) as Texture2D
	menu_dialog_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_dialog_overlay.add_child(menu_dialog_frame)

	menu_dialog_title = Label.new()
	menu_dialog_title.position = Vector2(180, 276)
	menu_dialog_title.size = Vector2(664, 42)
	menu_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_dialog_title.add_theme_font_size_override("font_size", 27)
	menu_dialog_title.add_theme_color_override("font_color", Color(0.96, 0.79, 0.38, 1.0))
	menu_dialog_overlay.add_child(menu_dialog_title)

	menu_dialog_text = Label.new()
	menu_dialog_text.position = Vector2(210, 338)
	menu_dialog_text.size = Vector2(604, 90)
	menu_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_dialog_text.add_theme_font_size_override("font_size", 17)
	menu_dialog_text.add_theme_color_override("font_color", Color(0.85, 0.78, 0.64, 1.0))
	menu_dialog_overlay.add_child(menu_dialog_text)

	menu_dialog_close_button = Button.new()
	menu_dialog_close_button.name = "CloseMainMenuDialogButton"
	menu_dialog_close_button.text = "Close"
	menu_dialog_close_button.position = Vector2(424, 468)
	menu_dialog_close_button.size = Vector2(176, 42)
	menu_dialog_close_button.pressed.connect(_hide_menu_dialog)
	menu_dialog_overlay.add_child(menu_dialog_close_button)


func _show_menu_dialog(title: String, text: String, frame_path: String) -> void:
	menu_dialog_frame.texture = load(frame_path) as Texture2D
	menu_dialog_title.text = title
	menu_dialog_text.text = text
	menu_dialog_overlay.visible = true


func _show_continue_dialog() -> void:
	_show_menu_dialog(
		"CONTINUE",
		"No saved investigation was found. Choose Start Game to begin a new case.",
		MENU_BANNER_FRAME_PATH
	)


func _continue_game() -> void:
	if not GameState.load_saved_game():
		_show_continue_dialog()
		return
	var resume_path: String = GameState.resume_scene_path
	if not ResourceLoader.exists(resume_path):
		resume_path = "res://scenes/wake_room.tscn"
	get_tree().change_scene_to_file(resume_path)


func _show_settings_dialog() -> void:
	_show_menu_dialog(
		"SETTINGS",
		"The current investigation uses the cinematic Shadow Castle presentation. Gameplay controls remain WASD, E, B and O.",
		MENU_WOOD_FRAME_PATH
	)


func _show_language_dialog() -> void:
	_show_menu_dialog(
		"LANGUAGE",
		"English is the current story language. The castle records and STEM clues use the same language consistently.",
		MENU_PURPLE_FRAME_PATH
	)


func _hide_menu_dialog() -> void:
	menu_dialog_overlay.visible = false


func start_game() -> void:
	_hide_menu_dialog()
	GameState.delete_saved_game()
	GameState.reset_new_game()
	if NoteHud != null:
		NoteHud.reset()
	GameState.mark_game_started()

	get_tree().change_scene_to_file(
		"res://scenes/intro_cutscene.tscn"
	)


func quit_game() -> void:
	get_tree().quit()
