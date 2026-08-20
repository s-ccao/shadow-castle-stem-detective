extends CanvasLayer

## 触摸操作层：手机浏览器上的虚拟摇杆。
##
## 一份网页版要同时服务手机和电脑，所以这一层是自己决定去留的：检测到触摸就
## 出现，检测到键盘就退场，中途换设备也会跟着切。桌面玩家永远看不到它。
##
## 只做移动这一件事。交互、开面板、选物品在手机上全都靠点——游戏本来就有
## “点物品 → 走过去 → 自动交互”的那条路（wake_room.gd 的
## pending_mouse_interaction），而触摸会被模拟成鼠标，所以那条路本身就是通的。
##
## 摇杆不碰玩家速度，而是按住 move_* 这四个动作。player.gd 读的是
## Input.get_vector(...) 并且对结果做了 normalized()，所以这里只要方向对，
## 移动、动画、药水加速全都沿用原来的那一条路径，一行都不用改。

## 层号要低于所有 UI（房间 UI 是 30，最低的面板是 20），高于世界（1）。
## 摇杆被面板盖住是对的：面板开着时本来也不该走路。
const TOUCH_LAYER := 15

const STICK_CENTER := Vector2(150.0, 612.0)
const STICK_RADIUS := 84.0
const STICK_KNOB_RADIUS := 34.0
## 可抓取范围比画出来的圆大一圈：手机上拇指落点很少精准，按图形大小判定
## 会经常抓空。
const STICK_GRAB_RADIUS := 122.0
const STICK_DEADZONE := 0.17

const MOVE_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
]

const GOLD := Color(1.0, 0.84, 0.43)
const INK := Color(0.035, 0.026, 0.052)

## 压得很低的不透明度：摇杆压在场景美术上面，找得到就够了，不该抢戏。
## 按住时略微提亮，是“抓住了”的唯一反馈。
const FILL_ALPHA_IDLE := 0.14
const FILL_ALPHA_LIVE := 0.20
const RIM_ALPHA_IDLE := 0.22
const RIM_ALPHA_LIVE := 0.44
const KNOB_FILL_ALPHA_IDLE := 0.10
const KNOB_FILL_ALPHA_LIVE := 0.20
const KNOB_RIM_ALPHA_IDLE := 0.30
const KNOB_RIM_ALPHA_LIVE := 0.60

var touch_mode := false
var stick_finger := -1
var stick_vector := Vector2.ZERO
var painter: Control


func _ready() -> void:
	layer = TOUCH_LAYER
	# 面板打开时游戏是暂停的，这一层要能在暂停中把自己收起来，否则摇杆会压在
	# 背包上。它只翻译输入、不驱动世界，所以 ALWAYS 不会让守卫动起来。
	process_mode = Node.PROCESS_MODE_ALWAYS
	painter = _Painter.new()
	painter.host = self
	painter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painter)
	_set_touch_mode(DisplayServer.is_touchscreen_available())


func _process(_delta: float) -> void:
	# 暂停时收起来：面板铺满屏幕，摇杆既没用又挡路。菜单和过场里没有人可以
	# 操控，同样不该出现。
	var wanted: bool = touch_mode and not get_tree().paused and _has_player()
	if painter.visible == wanted:
		return
	painter.visible = wanted
	if not wanted:
		_release_stick()


func _input(event: InputEvent) -> void:
	# 只在这里判断该不该露面。设备可能中途换（手机接键盘、桌面碰触屏），
	# 所以这个判断不能只做一次。
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_touch_mode(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		_set_touch_mode(false)


## 摇杆走 _unhandled_input 而不是 _input：对话框、检查面板、小游戏都是会吃
## 输入的 Control，先经过它们，落在面板上的手指就不会再把角色推着走。
func _unhandled_input(event: InputEvent) -> void:
	if not painter.visible:
		return

	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _notification(what: int) -> void:
	# 切标签页、锁屏、退到后台都不会补发 touchend，不放手就会一直朝一个方向走。
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_stick()


## 供 player.gd 判断某个点击是不是落在摇杆上。落在上面的手指是在推摇杆，
## 不该同时被当成一次“走到那里去”的点地指令。
func blocks_world_point(point: Vector2) -> bool:
	if not is_instance_valid(painter) or not painter.visible:
		return false
	return point.distance_to(STICK_CENTER) <= STICK_GRAB_RADIUS


func _has_player() -> bool:
	return get_tree().get_first_node_in_group(&"player") != null


func _set_touch_mode(enabled: bool) -> void:
	if touch_mode == enabled:
		return
	touch_mode = enabled
	if not enabled:
		_release_stick()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if stick_finger == -1 and blocks_world_point(event.position):
			stick_finger = event.index
			_aim_stick(event.position)
			_handled()
		return
	if event.index == stick_finger:
		_release_stick()
		_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != stick_finger:
		return
	_aim_stick(event.position)
	_handled()


func _aim_stick(position: Vector2) -> void:
	var offset: Vector2 = position - STICK_CENTER
	if offset.length() / STICK_RADIUS <= STICK_DEADZONE:
		stick_vector = Vector2.ZERO
	else:
		# 只有方向会被用到，所以死区之外一律给满推力，免得贴着死区边缘时
		# get_vector 的重映射把方向压回零。
		stick_vector = offset.normalized()
	_apply_stick()


## 把摇杆方向写回 move_* 四个动作。分量取绝对值，正负由按哪一个动作决定。
func _apply_stick() -> void:
	if stick_vector == Vector2.ZERO:
		for action: StringName in MOVE_ACTIONS:
			Input.action_release(action)
		return
	_drive(&"move_left", maxf(0.0, -stick_vector.x))
	_drive(&"move_right", maxf(0.0, stick_vector.x))
	_drive(&"move_up", maxf(0.0, -stick_vector.y))
	_drive(&"move_down", maxf(0.0, stick_vector.y))


func _drive(action: StringName, strength: float) -> void:
	if strength <= 0.0:
		Input.action_release(action)
	else:
		Input.action_press(action, strength)


func _release_stick() -> void:
	stick_finger = -1
	stick_vector = Vector2.ZERO
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)


func _handled() -> void:
	get_viewport().set_input_as_handled()


func paint(canvas: Control) -> void:
	var live: bool = stick_finger != -1
	var fill: float = FILL_ALPHA_LIVE if live else FILL_ALPHA_IDLE
	var rim: float = RIM_ALPHA_LIVE if live else RIM_ALPHA_IDLE
	canvas.draw_circle(STICK_CENTER, STICK_RADIUS, Color(INK.r, INK.g, INK.b, fill))
	canvas.draw_arc(STICK_CENTER, STICK_RADIUS, 0.0, TAU, 48, _gold(rim), 2.0, true)

	var knob: Vector2 = STICK_CENTER + stick_vector * (STICK_RADIUS - STICK_KNOB_RADIUS)
	var knob_fill: float = KNOB_FILL_ALPHA_LIVE if live else KNOB_FILL_ALPHA_IDLE
	var knob_rim: float = KNOB_RIM_ALPHA_LIVE if live else KNOB_RIM_ALPHA_IDLE
	canvas.draw_circle(knob, STICK_KNOB_RADIUS, _gold(knob_fill))
	canvas.draw_arc(knob, STICK_KNOB_RADIUS, 0.0, TAU, 32, _gold(knob_rim), 2.0, true)


func _gold(alpha: float) -> Color:
	return Color(GOLD.r, GOLD.g, GOLD.b, alpha)


## 只负责画。输入统一由 CanvasLayer 的 _input 处理，这样摇杆和别处的点击才能
## 各走各的 —— 走 Control 的 GUI 事件只会拿到被模拟成鼠标的那一根手指。
class _Painter:
	extends Control

	var host: Node

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if host != null:
			host.paint(self)
