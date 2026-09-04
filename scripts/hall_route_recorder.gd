class_name HallRouteRecorder
extends Node2D

## 开发者模式下把"你实际走的路"录成新手教程的路线。
##
## 这条路原来是 A* 现算的。A* 只保证能走到，不保证走得像话：它贴墙角切、
## 绕开看不见的碰撞体、在空地上走对角线，于是脚下的路标指向和玩家眼睛看到
## 的通路对不上——路线方位错乱就是这么来的。一条教学路线是设计决策，不是
## 寻路结果，所以应该由人走出来。
##
## 用法：按 0 打开开发者模式即开始录制，走到化学室门口的交互点自动定稿并
## 存盘。中途再按 0 关掉则放弃这次录制，原有路线不受影响。

signal route_saved(points: Array[Vector2])

## 采样间隔。地面路标每 96px 一个，这里取一半，保证转弯处不会被拉直。
const SAMPLE_DISTANCE: float = 48.0
## 离终点多近算走到了。和门口交互范围同量级。
const FINISH_RADIUS: float = 96.0
## 录制线的颜色：和路标的金色区分开，避免看混。
const TRAIL_COLOR := Color(0.35, 0.95, 1.0, 0.85)

var _player: Node2D
var _target: Vector2
var _points: Array[Vector2] = []
var _finished: bool = false
var _layer: CanvasLayer
var _status: Label


func setup(player_node: Node2D, target_position: Vector2) -> void:
	_player = player_node
	_target = target_position
	_points.clear()
	_finished = false
	if _player != null and is_instance_valid(_player):
		_points.append(_player.global_position)
	# 画在雾之上，否则自己录的线会被未探索区域盖住，等于看不见。
	z_index = 120
	_build_readout()
	_refresh_readout()
	queue_redraw()


func _build_readout() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 97
	add_child(_layer)
	_status = Label.new()
	_status.name = "RouteRecorderStatus"
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", TRAIL_COLOR)
	_status.add_theme_color_override(
		"font_outline_color", Color(0.06, 0.03, 0.01, 1.0)
	)
	_status.add_theme_constant_override("outline_size", 4)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 12.0
	_status.offset_top = -48.0
	_status.offset_bottom = -28.0
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_status)


func _refresh_readout() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	if _finished:
		_status.text = "路线已保存：%d 个点" % _points.size()
		return
	var remaining: float = 0.0
	if _player != null and is_instance_valid(_player):
		remaining = _player.global_position.distance_to(_target)
	_status.text = "录制中 %d 点　距化学室门 %dpx" % [_points.size(), roundi(remaining)]


func _process(_delta: float) -> void:
	if _finished or _player == null or not is_instance_valid(_player):
		return
	var here: Vector2 = _player.global_position
	if _points.is_empty() or here.distance_to(_points[_points.size() - 1]) >= SAMPLE_DISTANCE:
		_points.append(here)
		queue_redraw()
	_refresh_readout()
	if here.distance_to(_target) <= FINISH_RADIUS:
		_finish()


## 走到门口即定稿。终点补成门的交互点本身，而不是玩家停下的那一步——
## 守卫的收尾和路标的最后一格都以终点为准，差几十像素会让最后一个路标
## 落在门外。
func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _points.is_empty() or _points[_points.size() - 1].distance_to(_target) > 1.0:
		_points.append(_target)
	if _points.size() < 2:
		_refresh_readout()
		return
	if HallRouteStore.save_route(_points):
		route_saved.emit(_points)
	_refresh_readout()
	queue_redraw()


func recorded_points() -> Array[Vector2]:
	return _points


func is_finished() -> bool:
	return _finished


func _draw() -> void:
	if _points.size() >= 2:
		draw_polyline(PackedVector2Array(_points), TRAIL_COLOR, 3.0)
	for point: Vector2 in _points:
		draw_circle(point, 5.0, TRAIL_COLOR)
	# 终点画个圈，录制时才知道要走去哪里收尾。
	draw_arc(_target, FINISH_RADIUS, 0.0, TAU, 32, Color(1.0, 0.78, 0.32, 0.7), 2.0)
