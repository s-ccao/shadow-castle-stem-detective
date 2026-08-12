extends Node2D
class_name WorldInteractionFocus

## 世界空间交互焦点：只绘制四角角标和中心小符文，避免遮挡场景物品。
## 蓝灰色表示可发现/可交互，旧金色表示当前任务或关键线索。

var _active: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _focus_title: String = ""
var _is_primary: bool = false
var _pulse_time: float = 0.0
var _focus_size: Vector2 = Vector2(112, 82)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 22
	visible = false
	set_process(true)


func set_focus(
	target_position: Vector2,
	focus_title: String,
	is_primary: bool,
	custom_size: Vector2 = Vector2.ZERO
) -> void:
	var changed: bool = (
		not _active
		or _target_position != target_position
		or _focus_title != focus_title
		or _is_primary != is_primary
	)
	_target_position = target_position
	_focus_title = focus_title
	_is_primary = is_primary
	_focus_size = (
		custom_size
		if custom_size.x > 0.0 and custom_size.y > 0.0
		else (Vector2(142, 96) if is_primary else Vector2(112, 82))
	)
	position = target_position
	_active = true
	visible = true
	if changed:
		_pulse_time = 0.0
	queue_redraw()


func clear_focus() -> void:
	if not _active:
		return
	_active = false
	visible = false
	queue_redraw()


func is_focused() -> bool:
	return _active


func get_focus_title() -> String:
	return _focus_title


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 3.0)
	var cool_color: Color = Color(0.40, 0.82, 0.92, 0.64 + pulse * 0.16)
	var warm_color: Color = Color(0.90, 0.68, 0.30, 0.78 + pulse * 0.14)
	var outer_color: Color = warm_color if _is_primary else cool_color
	var inner_color: Color = Color(0.95, 0.78, 0.38, 0.58 + pulse * 0.12)
	var half: Vector2 = _focus_size * 0.5
	var outer_length: float = 18.0
	var inner_length: float = 9.0

	# 外层冷月色角标。
	_draw_corner(Vector2(-half.x, -half.y), Vector2(1, 1), outer_color, outer_length, 2.0)
	_draw_corner(Vector2(half.x, -half.y), Vector2(-1, 1), outer_color, outer_length, 2.0)
	_draw_corner(Vector2(-half.x, half.y), Vector2(1, -1), outer_color, outer_length, 2.0)
	_draw_corner(Vector2(half.x, half.y), Vector2(-1, -1), outer_color, outer_length, 2.0)

	# 内层细金线，让关键目标有旧铜/烛火质感。
	_draw_corner(Vector2(-half.x + 6, -half.y + 6), Vector2(1, 1), inner_color, inner_length, 1.4)
	_draw_corner(Vector2(half.x - 6, -half.y + 6), Vector2(-1, 1), inner_color, inner_length, 1.4)
	_draw_corner(Vector2(-half.x + 6, half.y - 6), Vector2(1, -1), inner_color, inner_length, 1.4)
	_draw_corner(Vector2(half.x - 6, half.y - 6), Vector2(-1, -1), inner_color, inner_length, 1.4)

	# 中心小符文：四点菱形，不覆盖被交互物品。
	var diamond_radius: float = 4.0 + pulse * 1.2
	var diamond := PackedVector2Array([
		Vector2(0, -diamond_radius),
		Vector2(diamond_radius, 0),
		Vector2(0, diamond_radius),
		Vector2(-diamond_radius, 0),
	])
	draw_colored_polygon(diamond, inner_color)


func _draw_corner(origin: Vector2, direction: Vector2, color: Color, length: float, width: float) -> void:
	var horizontal_end: Vector2 = origin + Vector2(direction.x * length, 0)
	var vertical_end: Vector2 = origin + Vector2(0, direction.y * length)
	draw_line(origin, horizontal_end, color, width, true)
	draw_line(origin, vertical_end, color, width, true)
