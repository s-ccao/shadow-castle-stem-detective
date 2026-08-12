extends Control

signal start_requested
signal continue_requested
signal settings_requested
signal language_requested
signal quit_requested

@export var button_normal_texture: Texture2D
@export var button_hover_texture: Texture2D
@export var button_pressed_texture: Texture2D
@export var button_disabled_texture: Texture2D

@onready var artwork: TextureRect = $StartArtwork
@onready var start_button: Button = $StartGameButton
@onready var continue_button: Button = $ContinueButton
@onready var settings_button: Button = $SettingsButton
@onready var language_button: Button = $LanguageButton
@onready var quit_button: Button = $QuitButton
@onready var save_label: Label = $SaveStatus


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_button(start_button, func() -> void: start_requested.emit(), ArchiveUi.ROLE_ACTION)
	_connect_button(continue_button, func() -> void: continue_requested.emit(), ArchiveUi.ROLE_ARCHIVE)
	_connect_button(settings_button, func() -> void: settings_requested.emit(), ArchiveUi.ROLE_ARCHIVE)
	_connect_button(language_button, func() -> void: language_requested.emit(), ArchiveUi.ROLE_ARCANE)
	_connect_button(quit_button, func() -> void: quit_requested.emit(), ArchiveUi.ROLE_DANGER)
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()


func _connect_button(button: Button, callback: Callable, role: StringName) -> void:
	button.add_theme_font_size_override("font_size", 13)
	ArchiveUi.apply_button(button, role)
	button.pressed.connect(callback)


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [start_button, continue_button, settings_button, language_button, quit_button]:
		button.disabled = not enabled


func set_continue_enabled(enabled: bool) -> void:
	continue_button.disabled = not enabled
	if save_label != null:
		save_label.visible = enabled


func set_save_status(status: String) -> void:
	if save_label != null:
		save_label.text = status
		save_label.visible = not status.is_empty()


func _refresh_copy(_language: String = "") -> void:
	ArchiveUi.apply_label(save_label, &"muted")
	start_button.text = CaseLocale.text("menu.new_case")
	continue_button.text = CaseLocale.text("menu.continue")
	settings_button.text = CaseLocale.text("menu.settings")
	language_button.text = CaseLocale.text("menu.language")
	quit_button.text = CaseLocale.text("menu.quit")
	set_save_status(GameState.resume_label() if GameState.has_saved_game() else "")
