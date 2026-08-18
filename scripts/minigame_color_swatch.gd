class_name MinigameColorSwatch
extends Control

## 光的叠加游戏里的色块。
##
## 颜色不是查表来的，而是把亮着的灯**逐通道相加**再钳位——这样画面本身就是
## 加色模型的演示：红+绿真的会算出黄，三色齐开真的会算出白。如果改成查一张
## 美术调色表，就有可能出现"画面颜色"和"物理原理"对不上的情况。

const LAMP_RGB: Dictionary = {
	"red": Vector3(1.0, 0.0, 0.0),
	"green": Vector3(0.0, 1.0, 0.0),
	"blue": Vector3(0.0, 0.0, 1.0),
}
const BORDER := Color(0.72, 0.58, 0.30, 0.85)
const EMPTY_BG := Color(0.02, 0.02, 0.03, 1.0)

var lamps: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 逐通道相加后钳位到 1，即加色混合。
func mixed_color() -> Color:
	var total := Vector3.ZERO
	for lamp: Variant in lamps:
		var key: String = str(lamp)
		if LAMP_RGB.has(key):
			total += LAMP_RGB[key] as Vector3
	return Color(
		minf(total.x, 1.0),
		minf(total.y, 1.0),
		minf(total.z, 1.0),
		1.0
	)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, EMPTY_BG)
	if not lamps.is_empty():
		draw_rect(box.grow(-3.0), mixed_color())
		# 中心加一层高光，让"叠加越多越亮"在画面上也成立。
		var glow: float = clampf(float(lamps.size()) * 0.14, 0.0, 0.45)
		draw_rect(
			box.grow(-14.0),
			Color(1.0, 1.0, 1.0, glow)
		)
	draw_rect(box, BORDER, false, 2.0)
