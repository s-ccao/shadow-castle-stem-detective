class_name FlameJarView
extends Control

## 烛火与空气里的一只玻璃罐。
##
## 把三个参数画成看得见的东西：罐内空气画成底部的浅色气层，通气孔画成罐颈
## 两侧的开口和向内的气流箭头，灯芯倍率画成火焰的大小。这样"带孔的小罐能
## 赢过密封的大罐"是可以用眼睛比出来的，而不必先做除法。

const GLASS := Color(0.62, 0.78, 0.86, 0.55)
const GLASS_FILL := Color(0.30, 0.45, 0.55, 0.18)
const AIR := Color(0.55, 0.82, 1.00, 0.34)
const FLAME_CORE := Color(1.00, 0.94, 0.62, 1.0)
const FLAME_OUTER := Color(1.00, 0.58, 0.18, 0.85)
const WAX := Color(0.92, 0.88, 0.74, 1.0)
const VENT := Color(0.98, 0.80, 0.38, 1.0)

## 空气量画成气层高度时的换算上限，超过这个值就画满。
const AIR_FULL: float = 30.0

var air: float = 6.0
var vents: float = 0.0
var burn: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var jar := Rect2(w * 0.16, h * 0.10, w * 0.68, h * 0.78)

	# 罐内空气：底部的一层浅蓝，高度随空气量增长。
	var fill: float = clampf(air / AIR_FULL, 0.05, 1.0)
	var air_height: float = jar.size.y * fill
	draw_rect(
		Rect2(jar.position.x, jar.position.y + jar.size.y - air_height,
			jar.size.x, air_height),
		AIR
	)
	draw_rect(jar, GLASS_FILL)

	# 蜡烛与火焰。火焰大小随灯芯倍率变化——耗氧越快，烧得越旺也越短命。
	var base_y: float = jar.position.y + jar.size.y
	var candle_w: float = jar.size.x * 0.22
	var candle_x: float = jar.position.x + (jar.size.x - candle_w) * 0.5
	var candle_h: float = jar.size.y * 0.34
	draw_rect(Rect2(candle_x, base_y - candle_h, candle_w, candle_h), WAX)

	var tip := Vector2(candle_x + candle_w * 0.5, base_y - candle_h)
	var flame_h: float = jar.size.y * (0.14 + 0.05 * clampf(burn, 0.0, 3.0))
	var flame_w: float = candle_w * (0.62 + 0.12 * clampf(burn, 0.0, 3.0))
	draw_colored_polygon(
		PackedVector2Array([
			tip + Vector2(0.0, -flame_h),
			tip + Vector2(flame_w * 0.5, -flame_h * 0.35),
			tip + Vector2(0.0, 2.0),
			tip + Vector2(-flame_w * 0.5, -flame_h * 0.35),
		]),
		FLAME_OUTER
	)
	draw_colored_polygon(
		PackedVector2Array([
			tip + Vector2(0.0, -flame_h * 0.58),
			tip + Vector2(flame_w * 0.22, -flame_h * 0.20),
			tip + Vector2(0.0, 1.0),
			tip + Vector2(-flame_w * 0.22, -flame_h * 0.20),
		]),
		FLAME_CORE
	)

	# 罐壁。有通气孔时颈部留出缺口，并画向内的箭头表示持续补气。
	var neck_y: float = jar.position.y + jar.size.y * 0.16
	if vents > 0.0:
		var gap: float = jar.size.y * 0.06
		draw_line(jar.position, Vector2(jar.position.x, neck_y - gap), GLASS, 3.0)
		draw_line(Vector2(jar.position.x, neck_y + gap),
			Vector2(jar.position.x, jar.position.y + jar.size.y), GLASS, 3.0)
		var right_x: float = jar.position.x + jar.size.x
		draw_line(Vector2(right_x, jar.position.y),
			Vector2(right_x, neck_y - gap), GLASS, 3.0)
		draw_line(Vector2(right_x, neck_y + gap),
			Vector2(right_x, jar.position.y + jar.size.y), GLASS, 3.0)
		draw_line(jar.position, Vector2(right_x, jar.position.y), GLASS, 3.0)
		# 补气箭头，数量随通气速率增加。
		var arrows: int = clampi(int(ceilf(vents * 2.0)), 1, 3)
		for step: int in range(arrows):
			var y: float = neck_y + float(step - arrows / 2) * 7.0
			draw_line(Vector2(jar.position.x - 12.0, y),
				Vector2(jar.position.x + 8.0, y), VENT, 2.0)
			draw_line(Vector2(right_x + 12.0, y),
				Vector2(right_x - 8.0, y), VENT, 2.0)
	else:
		draw_rect(jar, GLASS, false, 3.0)

	# 底座
	draw_line(
		Vector2(jar.position.x - 6.0, base_y),
		Vector2(jar.position.x + jar.size.x + 6.0, base_y),
		GLASS, 3.0
	)
