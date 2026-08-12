extends CanvasLayer

## ============================================================
## DoorPuzzleUI — 可复用的全屏知识锁答题界面（多门共用模板）
##
## 场景：scenes/door_puzzle_ui.tscn（CanvasLayer，PROCESS_MODE_ALWAYS）
## 布局：严格 Container 布局（PanelContainer 居中 800×600，零手动 offset）
## 风格：黑石金边 + 羊皮纸问题框 + 木质选项（StyleBoxFlat，无贴图依赖）
##
## 用法（每扇门在代码里设置自己的问题/选项/答案）：
##   DoorPuzzleUI.open(
##       "What has keys but no locks?",
##       ["A piano", "A map", "A clock", "A book"],
##       0,
##       _on_puzzle_answered
##   )
##   # 回调：func _on_puzzle_answered(is_correct: bool)
##   #   true  = 答对（UI 自动关闭，游戏恢复）
##   #   false = 点退出/按 ESC（UI 已关闭）
##
## 答错：面板横向抖动 + 红色提示，留在界面内可重试；
## 答对：面板金色闪光 + 金色提示，0.5s 后回调并关闭。
## ============================================================

# 主题色：黑石、旧木、羊皮纸、旧金属与知识符文
const COLOR_GOLD := Color("#c9a84c")
const COLOR_STONE := Color("#292736")
const COLOR_WOOD := Color("#3d2f20")
const COLOR_PARCHMENT := Color("#e8d5b5")
const COLOR_RUNE := Color("#7188ad")

# 节点引用
@onready var overlay: ColorRect = $Overlay
@onready var main_panel: PanelContainer = $MainPanel/DialogFrame
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var question_text: RichTextLabel = %QuestionText
@onready var feedback_label: Label = %FeedbackLabel
@onready var submit_btn: Button = %SubmitBtn
@onready var exit_btn: Button = %ExitBtn

# 选项按钮数组（OptionA~OptionD 的 Button 节点）
var _option_buttons: Array[Button] = []
# 选项单选指示器（圆形 ColorRect）
var _indicators: Array[Panel] = []
# 当前选中项：-1 = 未选
var _selected_index := -1
# 正确答案索引
var _correct_index := 0
# 答题回调（func(result: bool) -> void）
var _callback: Callable = Callable()

# 主题样式（StyleBoxFlat，代码统一创建，避免 tscn 里重复粘贴）
var _style_option_normal: StyleBoxFlat
var _style_option_hover: StyleBoxFlat
var _style_option_selected: StyleBoxFlat
var _style_indicator_off: StyleBoxFlat
var _style_indicator_on: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_styles()

	# 收集选项按钮与指示器（模板固定 4 个选项）
	_option_buttons = [
		%OptionA as Button,
		%OptionB as Button,
		%OptionC as Button,
		%OptionD as Button,
	]
	_indicators = [
		%IndicatorA as Panel,
		%IndicatorB as Panel,
		%IndicatorC as Panel,
		%IndicatorD as Panel,
	]

	for i in _option_buttons.size():
		_option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
		_option_buttons[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_option_buttons[i].focus_mode = Control.FOCUS_ALL
		_option_buttons[i].add_theme_stylebox_override("normal", _style_option_normal)
		_option_buttons[i].add_theme_stylebox_override("hover", _style_option_hover)
		_option_buttons[i].add_theme_stylebox_override("pressed", _style_option_selected)
		_indicators[i].add_theme_stylebox_override("panel", _style_indicator_off)

	submit_btn.pressed.connect(_on_submit_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)


func _build_styles() -> void:
	_style_option_normal = StyleBoxFlat.new()
	_style_option_normal.bg_color = COLOR_WOOD
	_style_option_normal.border_color = Color("#80613b")
	_style_option_normal.set_border_width_all(2)
	_style_option_normal.set_corner_radius_all(6)
	_style_option_normal.shadow_color = Color(0.01, 0.005, 0.01, 0.35)
	_style_option_normal.shadow_size = 5
	_style_option_normal.shadow_offset = Vector2(0, 2)

	_style_option_hover = StyleBoxFlat.new()
	_style_option_hover.bg_color = COLOR_WOOD.lightened(0.10)
	_style_option_hover.border_color = COLOR_GOLD
	_style_option_hover.set_border_width_all(2)
	_style_option_hover.set_corner_radius_all(6)
	_style_option_hover.shadow_color = Color(0.78, 0.52, 0.20, 0.28)
	_style_option_hover.shadow_size = 8
	_style_option_hover.shadow_offset = Vector2(0, 2)

	_style_option_selected = StyleBoxFlat.new()
	_style_option_selected.bg_color = Color("#554329")
	_style_option_selected.border_color = Color("#e0b85a")
	_style_option_selected.set_border_width_all(2)
	_style_option_selected.set_corner_radius_all(6)
	_style_option_selected.shadow_color = Color(0.90, 0.60, 0.22, 0.38)
	_style_option_selected.shadow_size = 10
	_style_option_selected.shadow_offset = Vector2(0, 2)

	_style_indicator_off = StyleBoxFlat.new()
	_style_indicator_off.bg_color = Color("#211e27")
	_style_indicator_off.border_color = Color("#8a7040")
	_style_indicator_off.set_border_width_all(2)
	_style_indicator_off.set_corner_radius_all(5)

	_style_indicator_on = StyleBoxFlat.new()
	_style_indicator_on.bg_color = COLOR_RUNE
	_style_indicator_on.border_color = Color("#e0b85a")
	_style_indicator_on.set_border_width_all(2)
	_style_indicator_on.set_corner_radius_all(5)
	_style_indicator_on.shadow_color = Color(0.42, 0.58, 0.82, 0.45)
	_style_indicator_on.shadow_size = 6
	_style_indicator_on.shadow_offset = Vector2(0, 0)


## ============================================================
## 公共 API
## ============================================================

## 打开答题界面
## question: 问题文本（BBCode 可用）
## options:  恰好 4 个选项字符串
## correct_index: 0=A, 1=B, 2=C, 3=D
## callback: func(result: bool) -> void（true=答对，false=退出）
func open(
	question: String,
	options: Array,
	correct_index: int,
	callback: Callable
) -> void:
	# 重置状态
	_selected_index = -1
	_correct_index = clampi(correct_index, 0, 3)
	_callback = callback

	question_text.text = question
	for i in 4:
		var text_label: Label = _option_buttons[i].get_node("HBox/TextLabel")
		text_label.text = options[i] if i < options.size() else ""

	_reset_selection_visual()
	feedback_label.text = ""
	feedback_label.visible = false

	visible = true
	overlay.visible = true
	# 直接显示，不做淡入：paused=true 后若 tween 因任何原因不跑，
	# 面板会停在 modulate.a=0 变成全透明 → 玩家只见黑屏以为卡死。
	main_panel.modulate.a = 1.0
	get_tree().paused = true


## 关闭界面（淡出 + 恢复游戏）
func close() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(main_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		visible = false
		overlay.visible = false
		get_tree().paused = false
	)


## ============================================================
## 内部逻辑
## ============================================================

func _on_option_pressed(index: int) -> void:
	_selected_index = index
	_reset_selection_visual()
	feedback_label.visible = false


## 刷新所有选项的选中视觉（单选）
func _reset_selection_visual() -> void:
	for i in _option_buttons.size():
		var is_selected: bool = i == _selected_index
		_option_buttons[i].add_theme_stylebox_override(
			"normal",
			_style_option_selected if is_selected else _style_option_normal
		)
		_option_buttons[i].add_theme_stylebox_override(
			"hover",
			_style_option_selected if is_selected else _style_option_hover
		)
		_indicators[i].add_theme_stylebox_override(
			"panel",
			_style_indicator_on if is_selected else _style_indicator_off
		)


func _on_submit_pressed() -> void:
	if _selected_index == -1:
		# 未选择 → 选项区抖动 + 提示
		_shake(options_container, 8.0)
		_show_feedback("Choose a seal to answer.", Color("#7a2e2e"))
		return

	if _selected_index == _correct_index:
		# 答对 → 金色闪光 + 提示，0.5s 后回调并关闭
		_show_feedback("The lock accepts your answer.", COLOR_GOLD)
		var flash := create_tween()
		flash.tween_property(main_panel, "modulate", Color(1.25, 1.15, 0.8), 0.15)
		flash.tween_property(main_panel, "modulate", Color.WHITE, 0.15)
		await get_tree().create_timer(0.5).timeout
		var cb := _callback
		close()
		cb.call(true)
	else:
		# 答错 → 面板抖动 + 红色提示，留在界面重试
		_shake(main_panel, 10.0)
		_show_feedback("The knowledge lock remains sealed.", Color("#7a2e2e"))


func _on_exit_pressed() -> void:
	# 退出/ESC → 回调 false 并关闭
	var cb := _callback
	close()
	if cb.is_valid():
		cb.call(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()


## 水平抖动动画（幅度 ±amp px）
func _shake(node: Control, amp: float) -> void:
	var base_pos: Vector2 = node.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(node, "position", base_pos + Vector2(amp, 0), 0.05)
		tw.tween_property(node, "position", base_pos - Vector2(amp, 0), 0.05)
	tw.tween_property(node, "position", base_pos, 0.05)


func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.visible = true
