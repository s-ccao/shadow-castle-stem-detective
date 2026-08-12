extends Control

signal continue_requested
signal view_conclusion_requested
signal main_menu_requested

@export var button_normal_texture: Texture2D
@export var button_hover_texture: Texture2D
@export var button_pressed_texture: Texture2D
@export var button_disabled_texture: Texture2D

@onready var artwork: TextureRect = $GameOverArtwork
@onready var continue_button: Button = $ContinueButton
@onready var view_conclusion_button: Button = $ViewConclusionButton
@onready var main_menu_button: Button = $MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_button(continue_button, func() -> void: continue_requested.emit())
	_connect_button(view_conclusion_button, func() -> void: view_conclusion_requested.emit(), ArchiveUi.ROLE_ARCHIVE)
	_connect_button(main_menu_button, func() -> void: main_menu_requested.emit(), ArchiveUi.ROLE_DANGER)
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()


func _connect_button(button: Button, callback: Callable, role: StringName = ArchiveUi.ROLE_ACTION) -> void:
	button.add_theme_font_size_override("font_size", 14)
	ArchiveUi.apply_button(button, role)
	button.pressed.connect(callback)


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [continue_button, view_conclusion_button, main_menu_button]:
		button.disabled = not enabled


func _refresh_copy(_language: String = "") -> void:
	continue_button.text = CaseLocale.text("ending.continue")
	view_conclusion_button.text = CaseLocale.text("ending.review")
	main_menu_button.text = CaseLocale.text("ending.main_menu")
