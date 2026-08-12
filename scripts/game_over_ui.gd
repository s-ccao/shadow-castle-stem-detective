extends Control

signal continue_requested
signal view_conclusion_requested
signal main_menu_requested

@export var button_normal_texture: Texture2D
@export var button_hover_texture: Texture2D
@export var button_pressed_texture: Texture2D
@export var button_disabled_texture: Texture2D

@onready var artwork: TextureRect = $GameOverArtwork
@onready var case_record: Label = $CaseRecord
@onready var continue_button: Button = $ContinueButton
@onready var view_conclusion_button: Button = $ViewConclusionButton
@onready var main_menu_button: Button = $MainMenuButton

var _true_case := false


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


func show_true_case() -> void:
	_true_case = true
	_refresh_copy()


func show_ordinary_case() -> void:
	_true_case = false
	_refresh_copy()


func _refresh_copy(_language: String = "") -> void:
	continue_button.text = CaseLocale.text("ending.true_continue" if _true_case else "ending.continue")
	view_conclusion_button.text = CaseLocale.text("ending.true_review" if _true_case else "ending.review")
	main_menu_button.text = CaseLocale.text("ending.main_menu")
	case_record.text = CaseLocale.text("ending.true_record" if _true_case else "ending.ordinary_record")
