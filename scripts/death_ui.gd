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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_button(retry_button, func() -> void: retry_requested.emit())
	_connect_button(checkpoint_button, func() -> void: checkpoint_requested.emit())
	_connect_button(main_menu_button, func() -> void: main_menu_requested.emit())


func _connect_button(button: Button, callback: Callable) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.96, 0.78, 0.42, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.42, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.46, 0.48, 0.82))
	_style_button(button)
	button.pressed.connect(callback)


func set_ui_enabled(enabled: bool) -> void:
	for button: Button in [retry_button, checkpoint_button, main_menu_button]:
		button.disabled = not enabled


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_texture_style(button_normal_texture))
	button.add_theme_stylebox_override("hover", _make_texture_style(button_hover_texture))
	button.add_theme_stylebox_override("pressed", _make_texture_style(button_pressed_texture))
	button.add_theme_stylebox_override("disabled", _make_texture_style(button_disabled_texture))


func _make_texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 20.0
	style.texture_margin_right = 20.0
	style.texture_margin_top = 8.0
	style.texture_margin_bottom = 8.0
	return style
