class_name ClueTimelineView
extends Control

## 餐厅时间推演里的证据板。
##
## 每条线索都是"某个量以稳定速度在变"，所以它自己就能算出一个小时数。这一关
## 真正要教的不是那道除法，而是**几条互相独立的线索彼此印证、把对不上的那条
## 丢掉**——而"彼此印证"本来就是一件用眼睛比的事，原来却只能靠读五行文字心算。
##
## 所以答题前每条线索只给出自己单位下的证据（烧掉几厘米、融了几毫米、降了
## 几度），长度互相之间没有可比性；答完之后所有条一起**重新标定到同一根小时
## 轴上**——这个动画本身就是在做那道除法。落在同一格的挤成一簇，落单的那条
## 就是说谎的那个。

enum Phase {
	EVIDENCE, ## 答题前：各自单位下的证据
	RESOLVE,  ## 正在重新标定到小时轴
	RESOLVED, ## 标定完成，簇与离群值都露出来了
}

const PLATE := Color(0.06, 0.05, 0.04, 0.70)
const AXIS := Color(0.62, 0.56, 0.40, 0.90)
const AXIS_TEXT := Color(0.82, 0.76, 0.58, 1.0)
const BAR := Color(0.72, 0.66, 0.46, 1.0)
const AGREE := Color(0.55, 0.92, 0.52, 1.0)
const OUTLIER := Color(1.00, 0.44, 0.34, 1.0)
const NAME := Color(0.92, 0.88, 0.74, 1.0)
const RATE := Color(0.74, 0.70, 0.56, 1.0)

const RESOLVE_TIME: float = 1.1
## 左侧留给图标和名字的宽度，右边才是证据条的地方。
const GUTTER: float = 168.0

## 每条 {id, rate, amount, reliable, name, unit, rate_text}。
var clues: Array[Dictionary] = []
## 小时轴的上限，取所有线索算出来的最大小时数。
var hour_span: float = 8.0

var _phase: int = Phase.EVIDENCE
var _phase_time: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func resolve() -> void:
	_phase = Phase.RESOLVE
	_phase_time = 0.0


func reset_board() -> void:
	_phase = Phase.EVIDENCE
	_phase_time = 0.0


func is_resolving() -> bool:
	return _phase == Phase.RESOLVE


func is_resolved() -> bool:
	return _phase == Phase.RESOLVED


func hours_of(clue: Dictionary) -> float:
	var rate: float = float(clue.get("rate", 0.0))
	if is_zero_approx(rate):
		return 0.0
	return float(clue.get("amount", 0.0)) / rate


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	if _phase == Phase.RESOLVE and _phase_time >= RESOLVE_TIME:
		_phase = Phase.RESOLVED
		_phase_time = 0.0
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= GUTTER + 40.0 or h <= 24.0 or clues.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), PLATE)

	var mix: float = 0.0
	if _phase == Phase.RESOLVE:
		var raw: float = clampf(_phase_time / RESOLVE_TIME, 0.0, 1.0)
		mix = 1.0 - pow(1.0 - raw, 2.4)
	elif _phase == Phase.RESOLVED:
		mix = 1.0

	var row_h: float = h / float(clues.size())
	var track_x: float = GUTTER
	# 右边要留出条头后面那行读数的位置，否则最长的一条会把自己的标签顶出画面。
	var track_w: float = w - GUTTER - 62.0

	if mix > 0.0:
		_draw_hour_axis(track_x, track_w, h, mix)

	# 证据条的最大值，答题前各条按各自单位铺开，长度之间不可比——本来也不该比。
	var widest: float = 1.0
	for clue: Dictionary in clues:
		widest = maxf(widest, float(clue.get("amount", 0.0)))

	for index: int in range(clues.size()):
		_draw_clue_row(
			clues[index], Rect2(0.0, row_h * float(index), w, row_h),
			track_x, track_w, widest, mix
		)


## 小时刻度。它只在答题之后出现——提前画出来，玩家把每条对着刻度一比就有
## 答案了，那道除法和那次比对就都不用做了。
func _draw_hour_axis(track_x: float, track_w: float, h: float, mix: float) -> void:
	var alpha: float = clampf(mix * 1.6, 0.0, 1.0)
	var span: float = maxf(hour_span, 1.0)
	var font := ThemeDB.fallback_font
	for hour: int in range(int(ceilf(span)) + 1):
		var x: float = track_x + track_w * float(hour) / span
		draw_line(
			Vector2(x, 2.0), Vector2(x, h - 12.0),
			Color(AXIS.r, AXIS.g, AXIS.b, alpha * (0.30 if hour % 2 else 0.55)),
			1.0
		)
		if hour % 2 == 0:
			draw_string(
				font, Vector2(x - 4.0, h - 2.0), str(hour),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(AXIS_TEXT.r, AXIS_TEXT.g, AXIS_TEXT.b, alpha)
			)


func _draw_clue_row(
	clue: Dictionary, row: Rect2, track_x: float, track_w: float,
	widest: float, mix: float
) -> void:
	var mid: float = row.position.y + row.size.y * 0.48
	var font := ThemeDB.fallback_font

	_draw_icon(str(clue.get("id", "")), Vector2(16.0, mid), row.size.y)

	draw_string(
		font, Vector2(38.0, mid - 1.0), str(clue.get("name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NAME
	)
	draw_string(
		font, Vector2(38.0, mid + 13.0), str(clue.get("rate_text", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RATE
	)

	# 条长从"自己单位下的占比"过渡到"小时轴上的位置"。这一段过渡就是那道除法。
	# 证据条最长只画到轴的 85%，同样是给单位标签留地方。
	var by_unit: float = 0.85 * float(clue.get("amount", 0.0)) / maxf(widest, 0.001)
	var by_hour: float = hours_of(clue) / maxf(hour_span, 1.0)
	var reach: float = track_w * lerpf(by_unit, by_hour, mix)

	var tint: Color = BAR
	if _phase == Phase.RESOLVED:
		tint = AGREE if bool(clue.get("reliable", true)) else OUTLIER
	var bar_h: float = clampf(row.size.y * 0.30, 7.0, 14.0)
	draw_rect(
		Rect2(track_x, mid - bar_h * 0.5, maxf(reach, 2.0), bar_h),
		Color(tint.r, tint.g, tint.b, 0.55)
	)
	draw_rect(
		Rect2(track_x, mid - bar_h * 0.5, maxf(reach, 2.0), bar_h),
		tint, false, 1.5
	)

	# 条头的标记。答完之后落在同一格的几条会挤成一簇，落单的那条一眼可见。
	var head := Vector2(track_x + reach, mid)
	draw_circle(head, bar_h * 0.62, Color(tint.r, tint.g, tint.b, 0.30))
	draw_circle(head, bar_h * 0.38, tint)

	if _phase == Phase.RESOLVED:
		var pulse: float = 0.6 + 0.4 * sin(_time * 3.2)
		draw_circle(head, bar_h * 0.38 + 3.0 * pulse,
			Color(tint.r, tint.g, tint.b, 0.35 * pulse))
		draw_string(
			font, head + Vector2(6.0, -6.0),
			"%s h" % _trim(hours_of(clue)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint
		)
	else:
		draw_string(
			font, head + Vector2(6.0, 4.0), str(clue.get("unit_text", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RATE
		)


func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


## 每条线索的小图标。全部按同一个尺寸画在行首，让人一眼认出这是哪一件东西
## ——蜡烛、冰桶、茶、灰、钟、日影，餐厅现场就是靠这几样东西定时刻的。
func _draw_icon(id: String, at: Vector2, row_h: float) -> void:
	var s: float = clampf(row_h * 0.30, 7.0, 11.0)
	match id:
		"candle":
			draw_rect(Rect2(at.x - s * 0.32, at.y - s * 0.5, s * 0.64, s * 1.3),
				Color(0.94, 0.88, 0.70))
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(at.x, at.y - s * 1.35),
					Vector2(at.x + s * 0.28, at.y - s * 0.6),
					Vector2(at.x - s * 0.28, at.y - s * 0.6),
				]),
				Color(1.0, 0.66, 0.24)
			)
		"ice":
			draw_rect(Rect2(at.x - s * 0.6, at.y - s * 0.4, s * 1.2, s * 1.2),
				Color(0.55, 0.68, 0.76))
			draw_rect(Rect2(at.x - s * 0.34, at.y - s * 0.85, s * 0.68, s * 0.6),
				Color(0.78, 0.92, 1.0))
		"tea":
			draw_rect(Rect2(at.x - s * 0.55, at.y - s * 0.35, s * 1.1, s * 1.05),
				Color(0.86, 0.84, 0.80))
			draw_rect(Rect2(at.x - s * 0.42, at.y - s * 0.2, s * 0.84, s * 0.5),
				Color(0.58, 0.36, 0.18))
			draw_line(Vector2(at.x, at.y - s * 0.6), Vector2(at.x, at.y - s * 1.2),
				Color(0.80, 0.80, 0.78, 0.7), 1.5)
		"ash":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(at.x - s * 0.75, at.y + s * 0.7),
					Vector2(at.x, at.y - s * 0.5),
					Vector2(at.x + s * 0.75, at.y + s * 0.7),
				]),
				Color(0.46, 0.44, 0.42)
			)
		"clock":
			draw_arc(at, s * 0.85, 0.0, TAU, 20, Color(0.80, 0.70, 0.42), 1.5, true)
			draw_line(at, at + Vector2(0.0, -s * 0.6), Color(0.80, 0.70, 0.42), 1.5)
			draw_line(at, at + Vector2(s * 0.45, 0.0), Color(0.80, 0.70, 0.42), 1.5)
		_:
			draw_arc(at + Vector2(0.0, -s * 0.3), s * 0.55, PI, TAU, 14,
				Color(1.0, 0.84, 0.40), 1.5, true)
			draw_rect(Rect2(at.x - s * 0.8, at.y + s * 0.35, s * 1.6, s * 0.32),
				Color(0.36, 0.34, 0.44))
