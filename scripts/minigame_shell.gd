class_name MinigameShell
extends CanvasLayer

## 房间小游戏的共用外壳：面板底纹、标题、关卡进度、指示语、结果反馈、
## 过关特效和收尾流程都在这里，具体玩法只需要往 content 里塞控件。
##
## 之所以做成基类而不是每个房间各写一套，是因为每个房间都要配小游戏：
## 共用外壳保证它们看起来是同一个游戏里的东西（深棕描金、和背包/日志同一
## 套配色），也避免把过关判定、关卡推进这类容易写错的流程复制七遍。
##
## 全部用代码搭建，不依赖 .tscn，这样新增小游戏不需要开编辑器。

signal finished(cleared_all: bool)

const SHELL_LAYER: int = 68

## 面板配色沿用背包 / 日志：深棕底 + 描金边。
const PANEL_BG := Color(0.055, 0.045, 0.035, 0.97)
const PANEL_BORDER := Color(0.72, 0.58, 0.30, 0.90)
const DIM_BG := Color(0.006, 0.005, 0.014, 0.86)
const GOLD := Color(0.96, 0.78, 0.36, 1.0)
const PARCHMENT := Color(0.94, 0.90, 0.76, 1.0)
const SUCCESS := Color(0.55, 0.92, 0.52, 1.0)
const FAILURE := Color(1.0, 0.48, 0.38, 1.0)
const INK_OUTLINE := Color(0.09, 0.05, 0.02, 1.0)

const PANEL_SIZE := Vector2(820.0, 560.0)

## 过关后停留多久再切下一关，让特效播完。
const LEVEL_CLEAR_DELAY: float = 0.9
## 全部通关后停留得久一点，这是整局最值得看的一下。
const FINAL_CLEAR_DELAY: float = 1.5

var content: Control
var accent: Color = GOLD

var _root: Control
var _panel: Panel
var _title_label: Label
var _subtitle_label: Label
var _progress_label: Label
var _instruction_label: Label
var _banner: Label
var _footer: HBoxContainer
var _close_button: Button
var _level_index: int = 0
var _cleared_count: int = 0
## 过关特效播放期间为真，用来挡住重复过关。
var _advancing: bool = false
## finished 只应发一次；收尾延时期间关闭按钮仍然是可按的。
var _finished: bool = false
var _banner_tween: Tween


func _ready() -> void:
	layer = SHELL_LAYER
	# 小游戏期间房间被暂停，外壳自己必须继续响应输入。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_chrome()
	visible = false


func _build_chrome() -> void:
	_root = Control.new()
	_root.name = "MinigameRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_SIZE.x * 0.5
	_panel.offset_right = PANEL_SIZE.x * 0.5
	_panel.offset_top = -PANEL_SIZE.y * 0.5
	_panel.offset_bottom = PANEL_SIZE.y * 0.5
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0
	column.offset_right = -24.0
	column.offset_top = 18.0
	column.offset_bottom = -18.0
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	_title_label = _make_label("", 22, GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_progress_label = _make_label("", 15, PARCHMENT)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_progress_label)

	_subtitle_label = _make_label("", 13, Color(0.80, 0.74, 0.58, 1.0))
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_subtitle_label)

	column.add_child(_make_rule())

	_instruction_label = _make_label("", 15, PARCHMENT)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.custom_minimum_size = Vector2(0.0, 44.0)
	column.add_child(_instruction_label)

	content = Control.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(content)

	_banner = _make_label("", 17, SUCCESS)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.custom_minimum_size = Vector2(0.0, 26.0)
	_banner.modulate.a = 0.0
	column.add_child(_banner)

	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 10)
	column.add_child(_footer)

	_close_button = make_button("Close")
	_close_button.pressed.connect(_on_close_pressed)
	_footer.add_child(_close_button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 10
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_rule() -> Panel:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.58, 0.30, 0.45)
	rule.add_theme_stylebox_override("panel", style)
	return rule


## 供具体玩法复用的按钮样式，保证所有小游戏的按钮长得一样。
func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(112.0, 34.0)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_outline_color", INK_OUTLINE)
	button.add_theme_constant_override("outline_size", 4)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.11, 0.07, 0.96)
	normal.border_color = Color(0.68, 0.54, 0.28, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.17, 0.10, 0.98)
	hover.border_color = GOLD
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.30, 0.23, 0.12, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.09, 0.08, 0.07, 0.85)
	disabled.border_color = Color(0.40, 0.34, 0.22, 0.5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	# 所有小游戏按钮共用同一个点击音，不必每个玩法各接一次。
	button.pressed.connect(_on_any_button_pressed)
	return button


func _on_any_button_pressed() -> void:
	GameAudio.play(&"ui_select")


func configure(title: String, subtitle: String, tint: Color) -> void:
	accent = tint
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", tint)
	_subtitle_label.text = subtitle
	var style: StyleBoxFlat = _panel_style()
	style.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	_panel.add_theme_stylebox_override("panel", style)
	_close_button.text = _text("Close", "关闭")


func set_instruction(text: String) -> void:
	_instruction_label.text = text


func current_level() -> int:
	return _level_index


## 已经通关的关卡数。房间据此按进度发奖励，中途退出也不会白玩。
func levels_cleared() -> int:
	return _cleared_count


## 打开并从第一关开始。房间调用这一个入口即可。
func start() -> void:
	visible = true
	_level_index = 0
	_cleared_count = 0
	_finished = false
	_enter_level()


func _enter_level() -> void:
	_clear_content()
	_advancing = false
	_set_content_interactive(true)
	_progress_label.text = _text(
		"Stage %d / %d" % [_level_index + 1, level_count()],
		"第 %d / %d 关" % [_level_index + 1, level_count()]
	)
	build_level(_level_index)


## 过关动画期间把内容区整体设为不可点，避免重复触发。
func _set_content_interactive(interactive: bool) -> void:
	if content == null:
		return
	content.mouse_filter = (
		Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	)
	_set_buttons_disabled(content, not interactive)


func _set_buttons_disabled(node: Node, disabled: bool) -> void:
	for child: Node in node.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = disabled
		_set_buttons_disabled(child, disabled)


## 供具体玩法重开当前关。必须走这里而不是直接调 build_level()，
## 否则旧的一整套控件会留在 content 里越叠越多。
func restart_level() -> void:
	_enter_level()


func _clear_content() -> void:
	for child: Node in content.get_children():
		child.queue_free()
		content.remove_child(child)


## 具体玩法在过关时调用；最后一关过掉会触发 finished(true)。
func report_level_cleared(message: String) -> void:
	# 过关到切下一关之间有 0.9 秒的特效时间，这期间控件仍然是活的，而且
	# 胜利条件依然成立——不挡住的话，连点获胜按钮会把关卡数和通关计数
	# 一起翻倍，一关能刷出满进度。
	if _advancing:
		return
	_advancing = true
	_set_content_interactive(false)
	GameAudio.play(&"bench_pass")
	show_banner(message, true)
	_spawn_clear_effect()
	_cleared_count += 1
	var is_last: bool = _level_index + 1 >= level_count()
	if not is_last:
		_level_index += 1
	# 留一点时间让过关特效播完再切下一关。最后一关同样要等——原来这里直接
	# _finish()，面板瞬间关闭，全通关那一下的横幅和光环玩家根本看不到，
	# 而那正是整局最该被看见的一刻。
	var timer: SceneTreeTimer = get_tree().create_timer(
		FINAL_CLEAR_DELAY if is_last else LEVEL_CLEAR_DELAY, true, false, true
	)
	if is_last:
		timer.timeout.connect(_finish.bind(true))
	else:
		timer.timeout.connect(_enter_level)


func report_level_failed(message: String) -> void:
	GameAudio.play(&"bench_fail")
	show_banner(message, false)


func show_banner(message: String, good: bool) -> void:
	_banner.text = message
	_banner.add_theme_color_override(
		"font_color", SUCCESS if good else FAILURE
	)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


## 过关时从面板中心扩散的光环，和药水特效同一套视觉语言。
func _spawn_clear_effect() -> void:
	var burst := PotionActivationBurst.new()
	burst.tint = accent
	burst.accent = accent.lerp(Color.WHITE, 0.35)
	burst.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(burst)


func _on_close_pressed() -> void:
	# 全部通关后的庆祝期间关闭按钮仍然可以按。这时成绩必须照样算通关，
	# 否则房间收到 cleared_all=false，完成标志不置位，玩家明明打通了却
	# 要把整个小游戏重来一遍。
	_finish(_cleared_count >= level_count())


func _finish(cleared_all: bool) -> void:
	# 全通关的收尾是延时触发的，那段时间里关闭按钮仍然可以按，会走到
	# 第二次 _finish。只发一次 finished，房间的奖励结算才不会重复执行。
	if _finished:
		return
	_finished = true
	visible = false
	_clear_content()
	finished.emit(cleared_all)


func _text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english


# ---- 具体玩法需要覆写的两个方法 ----


## 这个小游戏一共几关。
func level_count() -> int:
	return 1


## 搭建第 index 关的内容，控件加到 content 下。
func build_level(_index: int) -> void:
	pass
