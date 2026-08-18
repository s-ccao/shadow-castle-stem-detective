class_name MinigameCircuitRail
extends Control

## 接通电路里那条线路的示意图：左端电池、右端灯泡，中间是若干缺口。
##
## 接上导体的缺口画成实心铜色导线，绝缘或空着的缺口画成红色断口。只有**全部**
## 缺口都接通，整条线才会亮起来并点亮灯泡——闭合回路这个概念光靠文字讲不清，
## 必须让"差一个也不亮"在画面上直接发生。

const WIRE := Color(0.86, 0.66, 0.32, 1.0)
const WIRE_LIVE := Color(1.0, 0.90, 0.48, 1.0)
const BREAK := Color(0.92, 0.32, 0.26, 1.0)
const PLATE := Color(0.08, 0.07, 0.06, 0.85)
const LAMP_OFF := Color(0.32, 0.31, 0.28, 1.0)
const LAMP_ON := Color(1.0, 0.93, 0.55, 1.0)

var gap_count: int = 1
var bridged: Array[bool] = []
var energised: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLATE)
	if size.x <= 0.0 or gap_count <= 0:
		return

	var mid: float = size.y * 0.5
	var left: float = 46.0
	var right: float = size.x - 46.0
	if right <= left:
		return

	# 电池：左端两条粗细不同的极板。
	draw_line(Vector2(18.0, mid - 16.0), Vector2(18.0, mid + 16.0), WIRE, 4.0)
	draw_line(Vector2(28.0, mid - 9.0), Vector2(28.0, mid + 9.0), WIRE, 7.0)
	draw_line(Vector2(28.0, mid), Vector2(left, mid), WIRE, 3.0)

	var span: float = right - left
	var segments: int = gap_count * 2 + 1
	var seg_width: float = span / float(segments)
	var live: Color = WIRE_LIVE if energised else WIRE

	for index: int in range(segments):
		var x0: float = left + seg_width * float(index)
		var x1: float = x0 + seg_width
		var is_gap: bool = index % 2 == 1
		if not is_gap:
			draw_line(Vector2(x0, mid), Vector2(x1, mid), live, 4.0)
			continue
		var gap_index: int = (index - 1) / 2
		var ok: bool = gap_index < bridged.size() and bridged[gap_index]
		if ok:
			draw_line(Vector2(x0, mid), Vector2(x1, mid), live, 6.0)
			# 接上的缺口画一个铆接方块，和原生导线区分开。
			draw_rect(
				Rect2(x0 + 4.0, mid - 7.0, seg_width - 8.0, 14.0),
				Color(live.r, live.g, live.b, 0.45)
			)
		else:
			# 断口：两截翘起的线头，中间空着。
			draw_line(Vector2(x0, mid), Vector2(x0 + seg_width * 0.28, mid - 9.0), BREAK, 4.0)
			draw_line(Vector2(x1, mid), Vector2(x1 - seg_width * 0.28, mid + 9.0), BREAK, 4.0)

	draw_line(Vector2(right, mid), Vector2(size.x - 30.0, mid), live, 3.0)

	# 灯泡：只有整条回路闭合才亮。
	var bulb := Vector2(size.x - 20.0, mid)
	draw_circle(bulb, 11.0, LAMP_ON if energised else LAMP_OFF)
	if energised:
		draw_circle(bulb, 17.0, Color(LAMP_ON.r, LAMP_ON.g, LAMP_ON.b, 0.28))
	draw_arc(bulb, 11.0, 0.0, TAU, 28, WIRE, 2.0, true)
