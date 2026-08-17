class_name MoonleafPod
extends Control

## 月光采收里的一株月叶。
##
## 花苞按自己的周期开合：画成一圈随相位张开的花瓣 + 中心的银芯。开到
## 阈值以上才算"成熟"，此时描金边并亮起微光，这是玩家唯一的下手信号。
## 荆棘株用紫红描边并画倒刺，逼玩家先看清再点。

signal pod_pressed(pod: MoonleafPod)

const PETAL_COUNT: int = 6
const LEAF_TINT := Color(0.78, 0.88, 1.00, 1.0)
const CORE_TINT := Color(0.94, 0.97, 1.00, 1.0)
const THORN_TINT := Color(0.86, 0.42, 0.78, 1.0)
const RIPE_RING := Color(0.98, 0.86, 0.45, 1.0)
const PLATE_BG := Color(0.07, 0.09, 0.11, 0.92)

## 张开度达到多少算成熟可采。
const RIPE_THRESHOLD: float = 0.72

var period: float = 3.0
var phase_offset: float = 0.0
var is_thorn: bool = false
var harvested: bool = false

var _phase: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(92.0, 92.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func advance(delta: float) -> void:
	if harvested:
		return
	_phase = fmod(_phase + delta / maxf(period, 0.05), 1.0)
	queue_redraw()


func reset_phase() -> void:
	_phase = fmod(phase_offset, 1.0)


## 0 = 完全闭合，1 = 完全张开。用正弦让开合是平滑的呼吸而不是突变，
## 玩家可以预判到"快开了"。
func openness() -> float:
	return 0.5 - 0.5 * cos((_phase + phase_offset) * TAU)


func is_ripe() -> bool:
	return not harvested and openness() >= RIPE_THRESHOLD


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			pod_pressed.emit(self)
			accept_event()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.42
	draw_circle(center, radius + 4.0, PLATE_BG)

	if harvested:
		draw_arc(
			center, radius, 0.0, TAU, 40,
			Color(0.45, 0.50, 0.45, 0.55), 2.0, true
		)
		# 采完留一个空的叶托，玩家一眼看出这株已经收过。
		draw_arc(
			center, radius * 0.32, 0.0, TAU, 24,
			Color(0.55, 0.62, 0.58, 0.45), 2.0, true
		)
		return

	var open: float = openness()
	var petal_tint: Color = THORN_TINT if is_thorn else LEAF_TINT

	for index: int in range(PETAL_COUNT):
		var angle: float = TAU * float(index) / float(PETAL_COUNT)
		var reach: float = radius * lerpf(0.22, 1.0, open)
		var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * reach
		var width: float = lerpf(5.0, 2.5, open)
		draw_line(
			center,
			tip,
			Color(petal_tint.r, petal_tint.g, petal_tint.b, lerpf(0.45, 1.0, open)),
			width
		)
		draw_circle(
			tip,
			lerpf(2.0, 4.5, open),
			Color(petal_tint.r, petal_tint.g, petal_tint.b, lerpf(0.35, 0.95, open))
		)

	draw_circle(
		center,
		lerpf(4.0, 8.0, open),
		Color(CORE_TINT.r, CORE_TINT.g, CORE_TINT.b, lerpf(0.5, 1.0, open))
	)

	if is_thorn:
		# 倒刺：一圈向外的短针，和月叶的圆润花瓣区分开。
		for index: int in range(PETAL_COUNT * 2):
			var angle: float = TAU * float(index) / float(PETAL_COUNT * 2) + 0.26
			var base: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.72
			var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 1.02
			draw_line(base, tip, Color(THORN_TINT.r, THORN_TINT.g, THORN_TINT.b, 0.9), 2.0)
		draw_arc(center, radius, 0.0, TAU, 40, THORN_TINT, 2.0, true)
		return

	if is_ripe():
		draw_arc(center, radius, 0.0, TAU, 48, RIPE_RING, 3.0, true)
		draw_arc(
			center, radius + 3.0, 0.0, TAU, 48,
			Color(RIPE_RING.r, RIPE_RING.g, RIPE_RING.b, 0.35), 2.0, true
		)
