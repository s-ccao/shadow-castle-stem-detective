extends CanvasLayer

## ParchmentHud — 羊皮纸笔记弹窗（屏幕中间）
##
## 所有 Mrs. Lin 留下的 note 在首次交互时以羊皮纸样式显示在屏幕中间，
## 与 wake_room 书桌卷轴一致；确认后收进侦探笔记（Note Hub）。
##
## 用法：
##   ParchmentHud.show_parchment(title, content, note_id, note_data)
##   - title：羊皮纸标题
##   - content：正文（支持 BBCode）
##   - note_id：收进笔记本的线索 id（空字符串则不收录）
##   - note_data：{title, icon, content, category} 传给 NoteHud.add_clue

signal parchment_committed(note_id: String)

const PANEL_SIZE: Vector2 = Vector2(500.0, 750.0)
const PARCHMENT_TEXTURE: String = "res://assets/ui/ui_note_parchment.png"

var _panel: Panel
var _dim: ColorRect
var _title_label: Label
var _content_label: Label
var confirm_button: Button
var close_button: Button
var _pending_note_id: String = ""
var _pending_note_data: Dictionary = {}
var _paused_before: bool = false


func _ready() -> void:
	layer = 52
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func _build_panel() -> void:
	# 全屏暗色遮罩：提高羊皮纸文字对比度。
	_dim = ColorRect.new()
	_dim.name = "ParchmentDim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.58)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	_panel = Panel.new()
	_panel.name = "ParchmentPanel"
	_panel.position = Vector2.ZERO
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)

	# 羊皮纸背景贴图
	var parchment: TextureRect = TextureRect.new()
	parchment.name = "ParchmentTexture"
	parchment.position = Vector2.ZERO
	parchment.size = PANEL_SIZE
	parchment.texture = load(PARCHMENT_TEXTURE) as Texture2D
	parchment.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(parchment)

	# 标题
	_title_label = Label.new()
	_title_label.name = "ParchmentTitle"
	_title_label.position = Vector2(150.0, 96.0)
	_title_label.size = Vector2(190.0, 40.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06, 1.0))
	_panel.add_child(_title_label)

	# 正文（羊皮纸纸面中央）
	_content_label = Label.new()
	_content_label.name = "ParchmentContent"
	_content_label.position = Vector2(154.0, 148.0)
	_content_label.size = Vector2(218.0, 440.0)
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.add_theme_font_size_override("font_size", 14)
	_content_label.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06, 1.0))
	_panel.add_child(_content_label)

	# 收进笔记本按钮
	confirm_button = Button.new()
	confirm_button.name = "ParchmentConfirmButton"
	confirm_button.text = "Add to Notebook"
	confirm_button.position = Vector2(144.0, 596.0)
	confirm_button.size = Vector2(212.0, 42.0)
	confirm_button.add_theme_font_size_override("font_size", 14)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.05, 0.96)
	style.border_color = Color(0.82, 0.62, 0.24, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	confirm_button.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.19, 0.13, 0.06, 0.98)
	hover_style.border_color = Color(0.96, 0.76, 0.34, 1.0)
	confirm_button.add_theme_stylebox_override("hover", hover_style)
	confirm_button.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	confirm_button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.65, 1.0))
	confirm_button.pressed.connect(_on_confirm_pressed)
	_panel.add_child(confirm_button)

	# 右上角 X
	close_button = Button.new()
	close_button.name = "ParchmentCloseButton"
	close_button.text = "X"
	close_button.position = Vector2(352.0, 92.0)
	close_button.size = Vector2(36.0, 36.0)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_on_confirm_pressed)
	_panel.add_child(close_button)


## 显示羊皮纸：暂停游戏；确认/关闭时收进笔记本并恢复。
func show_parchment(title: String, content: String, note_id: String, note_data: Dictionary = {}) -> void:
	_pending_note_id = note_id
	_pending_note_data = note_data
	_title_label.text = title
	_content_label.text = content

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(
		(viewport_size.x - PANEL_SIZE.x) / 2.0,
		(viewport_size.y - PANEL_SIZE.y) / 2.0
	)
	_dim.visible = true
	_panel.visible = true
	_paused_before = get_tree().paused
	get_tree().paused = true


func _on_confirm_pressed() -> void:
	# 先关闭羊皮纸并恢复游戏，再发放奖励提示，避免奖励被羊皮纸盖住。
	var note_id_to_add: String = _pending_note_id
	var note_data_to_add: Dictionary = _pending_note_data.duplicate(true)
	_panel.visible = false
	_dim.visible = false
	get_tree().paused = _paused_before
	_pending_note_id = ""
	_pending_note_data = {}
	if not note_id_to_add.is_empty():
		call_deferred("_commit_note_reward", note_id_to_add, note_data_to_add)


func _commit_note_reward(note_id: String, note_data: Dictionary) -> void:
	# X / Continue 后才收录并显示 ItemRewardHud 奖励效果。
	var note_hud: Node = get_node_or_null("/root/NoteHud")
	if note_hud != null and not note_hud.has_clue(note_id):
		note_hud.call("add_clue", note_id, note_data)
	var evidence_id: String = str(note_data.get("evidence_id", ""))
	if not evidence_id.is_empty() and not GameState.has_evidence(evidence_id):
		GameState.add_evidence(evidence_id)
	parchment_committed.emit(note_id)


func is_open() -> bool:
	return _panel.visible
