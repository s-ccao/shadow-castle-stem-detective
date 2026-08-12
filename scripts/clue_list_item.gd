extends TextureButton

## 线索卡片的轻量交互反馈：
## 不使用整张蓝色 selected 贴图，选中只显示左侧细金色标记，避免覆盖按钮内容。

@onready var hover_glow: Panel = $HoverGlow
@onready var selected_glow: Panel = $SelectedGlow
@onready var title_label: Label = $Layout/Title

var _selected := false
var _hovered := false
var _press_tween: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	hover_glow.visible = false
	selected_glow.visible = false


func set_selected(selected: bool) -> void:
	_selected = selected
	selected_glow.visible = selected
	if selected:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
	else:
		modulate = Color(0.98, 0.98, 0.98, 1.0)
		title_label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82, 1.0))


func _on_mouse_entered() -> void:
	_hovered = true
	hover_glow.visible = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color(1.06, 1.04, 1.0, 1.0), 0.12)


func _on_mouse_exited() -> void:
	_hovered = false
	hover_glow.visible = false
	var target := Color(1.0, 1.0, 1.0, 1.0) if _selected else Color(0.98, 0.98, 0.98, 1.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", target, 0.14)


func _on_button_down() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_press_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2(0.985, 0.985), 0.06)


func _on_button_up() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_press_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
