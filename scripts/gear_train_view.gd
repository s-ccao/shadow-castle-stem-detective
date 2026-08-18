class_name GearTrainView
extends Control

## 知识引擎的传动链示意图。
##
## 齿轮半径按齿数等比例画，所以"小齿轮带大齿轮会变慢"是可以直接看出来的，
## 不必先做除法。每一级的转向用箭头标出，相邻两级方向必然相反——把"每啮合
## 一次反向一次"这条规则画成了可以逐级数过去的东西。

const BRASS := Color(0.85, 0.68, 0.34, 1.0)
const BRASS_DIM := Color(0.45, 0.38, 0.24, 1.0)
const HUB := Color(0.20, 0.16, 0.10, 1.0)
const ARROW := Color(0.98, 0.86, 0.45, 1.0)
const EMPTY := Color(0.55, 0.30, 0.26, 0.9)
const PLATE := Color(0.06, 0.05, 0.04, 0.75)

## 齿数换算成半径的比例，以及半径的上下限。
const TEETH_TO_RADIUS: float = 0.62
const MIN_RADIUS: float = 15.0
const MAX_RADIUS: float = 40.0

var input_teeth: int = 12
var stages: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _radius(teeth: int) -> float:
	return clampf(float(teeth) * TEETH_TO_RADIUS, MIN_RADIUS, MAX_RADIUS)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLATE)
	if size.x <= 0.0:
		return

	var all: Array[int] = [input_teeth]
	for teeth: Variant in stages:
		all.append(int(teeth))

	var mid: float = size.y * 0.52
	var gap: float = 14.0
	var total: float = 0.0
	for index: int in range(all.size()):
		total += _radius(all[index]) * 2.0
	total += gap * float(maxi(all.size() - 1, 0))
	var x: float = (size.x - total) * 0.5

	for index: int in range(all.size()):
		var teeth: int = all[index]
		var empty: bool = teeth <= 0
		var radius: float = _radius(maxi(teeth, 12))
		var centre := Vector2(x + radius, mid)

		if empty:
			# 空位画成虚线圈，一眼看出传动链在哪里断了。
			for step: int in range(16):
				var a0: float = TAU * float(step) / 16.0
				var a1: float = a0 + TAU / 32.0
				draw_arc(centre, radius, a0, a1, 4, EMPTY, 2.0, true)
			x += radius * 2.0 + gap
			continue

		var tint: Color = BRASS if index == 0 else BRASS
		draw_circle(centre, radius, Color(tint.r, tint.g, tint.b, 0.16))
		draw_arc(centre, radius, 0.0, TAU, 48, tint, 3.0, true)
		draw_circle(centre, radius * 0.22, HUB)

		# 轮齿：数量按真实齿数画，多了会糊成一圈，所以上限 24 个可视齿。
		var visible_teeth: int = clampi(teeth, 6, 24)
		for tooth: int in range(visible_teeth):
			var angle: float = TAU * float(tooth) / float(visible_teeth)
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(centre + dir * radius, centre + dir * (radius + 5.0), tint, 2.0)

		# 转向箭头：主动轮顺时针，之后每级反向一次。
		var clockwise: bool = index % 2 == 0
		var start: float = -PI * 0.55
		var end: float = PI * 0.15
		draw_arc(centre, radius * 0.58, start, end, 20, ARROW, 2.0, true)
		var tip_angle: float = end if clockwise else start
		var tip: Vector2 = centre + Vector2(
			cos(tip_angle), sin(tip_angle)
		) * radius * 0.58
		var wing: float = 0.55 if clockwise else -0.55
		draw_line(tip, tip + Vector2(cos(tip_angle + wing + PI * 0.5),
			sin(tip_angle + wing + PI * 0.5)) * 7.0, ARROW, 2.0)
		draw_line(tip, tip + Vector2(cos(tip_angle + wing - PI * 0.2),
			sin(tip_angle + wing - PI * 0.2)) * 7.0, ARROW, 2.0)

		var label: String = str(teeth)
		draw_string(
			ThemeDB.fallback_font, centre + Vector2(-8.0, radius + 18.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BRASS
		)

		x += radius * 2.0 + gap

	# 输入端标记
	draw_line(Vector2(4.0, mid), Vector2(14.0, mid), BRASS_DIM, 3.0)
