class_name MinigameSupplyBar
extends Control

## 光合平衡里的一根供给槽。
##
## 画三样东西：白送的底段（雨水之类，颜色压暗以示"不用花钱"）、玩家买来的
## 主段，以及横跨槽体的目标刻度线。当前槽是短板时描红边——限制因子这个概念
## 光靠数字不好读，得让它在画面上跳出来。

const TRACK_BG := Color(0.10, 0.09, 0.07, 0.92)
const TRACK_BORDER := Color(0.62, 0.52, 0.30, 0.75)
const LIMIT_BORDER := Color(1.0, 0.42, 0.34, 1.0)
const TARGET_LINE := Color(0.98, 0.86, 0.45, 0.95)
const CAP_LINE := Color(0.85, 0.42, 0.30, 0.75)

var tint: Color = Color.WHITE
## 该槽自身的上限（灯具功率之类的物理约束）。
var cap: int = 6
## 三根槽共用的绘制标尺。本游戏全靠"哪根最矮就是短板"来读，如果每根槽按
## 自己的 cap 缩放，每格的像素高度就不一样，矮的那根反而可能画得更高——
## 核心教学点会被画面直接讲反。所以高度一律按共用标尺算，各自的 cap 另外
## 画一条封顶线表示。
var scale_max: int = 6
var target: int = 1
var value: int = 0
var free_amount: int = 0
var is_limiting: bool = false
## 槽名画在槽内顶部。原来它是槽体上方的一个独立标签，三列各多占 20px，
## 整个内容区就装不下了。
var label: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, TRACK_BG)

	var units: int = maxi(scale_max, 1)
	var unit_height: float = size.y / float(units)

	# 每一格画一条淡淡的刻度，玩家能直接数出数量而不必去看数字。
	for step: int in range(1, units):
		var y: float = size.y - unit_height * float(step)
		draw_line(
			Vector2(2.0, y),
			Vector2(size.x - 2.0, y),
			Color(1.0, 1.0, 1.0, 0.07),
			1.0
		)

	var filled: int = clampi(value, 0, units)
	if filled > 0:
		var free_units: int = clampi(free_amount, 0, filled)
		var bought_units: int = filled - free_units
		if free_units > 0:
			var free_height: float = unit_height * float(free_units)
			draw_rect(
				Rect2(3.0, size.y - free_height, size.x - 6.0, free_height),
				Color(tint.r, tint.g, tint.b, 0.34)
			)
		if bought_units > 0:
			var bought_height: float = unit_height * float(bought_units)
			var top: float = size.y - unit_height * float(filled)
			draw_rect(
				Rect2(3.0, top, size.x - 6.0, bought_height),
				Color(tint.r, tint.g, tint.b, 0.88)
			)

	# 封顶线：这根槽自己加不上去的高度，用斜纹压暗区表示。
	if cap < units:
		var cap_y: float = size.y - unit_height * float(cap)
		draw_rect(
			Rect2(2.0, 2.0, size.x - 4.0, cap_y - 2.0),
			Color(0.0, 0.0, 0.0, 0.45)
		)
		draw_line(
			Vector2(0.0, cap_y),
			Vector2(size.x, cap_y),
			CAP_LINE,
			2.0
		)

	if target > 0 and target <= units:
		var target_y: float = size.y - unit_height * float(target)
		draw_line(
			Vector2(0.0, target_y),
			Vector2(size.x, target_y),
			TARGET_LINE,
			2.0
		)

	draw_rect(
		box,
		LIMIT_BORDER if is_limiting else TRACK_BORDER,
		false,
		3.0 if is_limiting else 2.0
	)

	if label.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size: int = 13
	var width: float = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var at := Vector2((size.x - width) * 0.5, 15.0)
	# 描一层深色底，槽填满时字压在亮色条上也要看得清。
	draw_string(font, at + Vector2(1.0, 1.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.04, 0.02, 0.9))
	draw_string(font, at, label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
