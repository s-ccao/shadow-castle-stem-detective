extends CanvasLayer

## 开发者模式的全局开关与屏幕角标。
##
## 之前 F3 只绑在线路室里，别的房间按了没反应，所以调试碰撞、跳小游戏这些
## 事只能在那一个房间做。开关本身（GameState.toggle_developer_mode）一直是
## 全局的，缺的只是一个到处都收得到的按键入口。
##
## 用数字 0 而不是 F3：macOS 默认把 F3 交给调度中心，游戏根本收不到那一下，
## 于是这个开关在开发机上等于不存在。0 在本项目里没有任何其他用途
## （InputMap 只绑了方向键、interact 和 evidence_board）。
##
## 单独做成 autoload 而不是塞进 GameState，是因为小游戏会把整棵树暂停：
## 只有 PROCESS_MODE_ALWAYS 的节点还收得到输入，而 GameState 改成 ALWAYS
## 会连带改掉它自己那些逻辑的暂停语义。

const TOGGLE_KEY: Key = KEY_0
## 小键盘的 0 一并接受，外接键盘上顺手。
const TOGGLE_KEY_ALT: Key = KEY_KP_0
const BADGE_LAYER: int = 96

var _badge: Label


func _ready() -> void:
	layer = BADGE_LAYER
	# 小游戏面板期间树是暂停的，按键和角标都要照常工作。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_badge()
	if not GameState.state_changed.is_connected(_sync_badge):
		GameState.state_changed.connect(_sync_badge)
	_sync_badge()


func _build_badge() -> void:
	_badge = Label.new()
	_badge.name = "DeveloperBadge"
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35, 1.0))
	_badge.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 1.0))
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_badge.offset_left = 12.0
	_badge.offset_top = -28.0
	_badge.offset_bottom = -8.0
	# 角标只是状态提示，不能挡住它下面的任何交互。
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	add_child(_badge)


func _sync_badge() -> void:
	if _badge == null or not is_instance_valid(_badge):
		return
	# 角标同时是这个开关的唯一说明书，所以按键名写在上面，而不是只画个点。
	_badge.text = (
		"● 开发者模式　按 0 关闭"
		if CaseLocale != null and CaseLocale.is_chinese()
		else "● DEV MODE　press 0 to exit"
	)
	_badge.visible = GameState.developer_mode


func is_enabled() -> bool:
	return GameState.developer_mode


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != TOGGLE_KEY and key.keycode != TOGGLE_KEY_ALT:
		return
	# 数字键比功能键容易误触：只要焦点在能收字符的控件上就让开，
	# 否则在输入框里打一个 0 会顺手把开发者模式切掉。
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	GameState.toggle_developer_mode()
	get_viewport().set_input_as_handled()
