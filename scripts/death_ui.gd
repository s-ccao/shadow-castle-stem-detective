extends Control

signal retry_requested
signal checkpoint_requested
signal main_menu_requested

@export var button_normal_texture: Texture2D
@export var button_hover_texture: Texture2D
@export var button_pressed_texture: Texture2D
@export var button_disabled_texture: Texture2D

@onready var artwork: TextureRect = $DeathArtwork
@onready var retry_button: Button = $RetryButton
@onready var checkpoint_button: Button = $LoadCheckpointButton
@onready var main_menu_button: Button = $MainMenuButton
@onready var reason_title: Label = $DeathReasonTitle
@onready var reason_body: Label = $DeathReasonBody


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_button(retry_button, func() -> void: retry_requested.emit(), ArchiveUi.ROLE_ACTION)
	_connect_button(checkpoint_button, func() -> void: checkpoint_requested.emit(), ArchiveUi.ROLE_ARCHIVE)
	_connect_button(main_menu_button, func() -> void: main_menu_requested.emit(), ArchiveUi.ROLE_DANGER)
	ArchiveUi.apply_label(reason_title, &"title")
	ArchiveUi.apply_label(reason_body, &"body")
	CaseLocale.locale_changed.connect(_refresh_copy)
	_refresh_copy()


func _connect_button(button: Button, callback: Callable, role: StringName) -> void:
	button.add_theme_font_size_override("font_size", 14)
	ArchiveUi.apply_button(button, role)
	button.pressed.connect(callback)


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [retry_button, checkpoint_button, main_menu_button]:
		button.disabled = not enabled


func _refresh_copy(_language: String = "") -> void:
	ArchiveUi.apply_label(reason_title, &"title")
	ArchiveUi.apply_label(reason_body, &"body")
	reason_title.text = CaseLocale.text("death.reason_title")
	reason_body.text = CaseLocale.text("death.reason_body")
	retry_button.text = CaseLocale.text("death.retry_room")
	checkpoint_button.text = CaseLocale.text("death.retry_checkpoint")
	main_menu_button.text = CaseLocale.text("death.main_menu")
