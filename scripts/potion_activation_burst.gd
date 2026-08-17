class_name PotionActivationBurst
extends Control

## 喝下药水那一瞬间的爆发特效：屏幕闪光 + 两圈向外扩散的光环 + 一圈溅射的
## 光点。播完自动 queue_free()。
##
## 这是"我确实喝了药水"最直接的确认。之前整个流程只有一行 1.8 秒的小字。

const DURATION: float = 0.85
const RING_COUNT: int = 2
const SPARK_COUNT: int = 18
## 光环最终半径相对屏幕短边的比例。
const RING_MAX_RATIO: float = 0.62
const SPARK_MAX_RATIO: float = 0.46

var tint: Color = Color.WHITE
var accent: Color = Color.WHITE

var _elapsed: float = 0.0
var _spark_angles: PackedFloat32Array = PackedFloat32Array()
var _spark_scales: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	name = "PotionActivationBurst"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 光点方向固定随机一次，逐帧重摇会变成闪烁的噪点。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(SPARK_COUNT):
		_spark_angles.append(
			TAU * float(index) / float(SPARK_COUNT)
			+ rng.randf_range(-0.12, 0.12)
		)
		_spark_scales.append(rng.randf_range(0.62, 1.0))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var view: Vector2 = size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var progress: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	# 跟随相机时玩家基本恒在画面中心，所以爆发从中心发出。
	var origin: Vector2 = view * 0.5
	var reach: float = minf(view.x, view.y)

	# 起手的整屏闪光，衰减很快，避免长时间挡住画面。
	var flash_alpha: float = pow(1.0 - clampf(progress / 0.28, 0.0, 1.0), 2.0) * 0.34
	if flash_alpha > 0.002:
		draw_rect(
			Rect2(Vector2.ZERO, view),
			Color(tint.r, tint.g, tint.b, flash_alpha)
		)

	# 两圈错开出发的扩散光环。
	for ring: int in range(RING_COUNT):
		var delay: float = float(ring) * 0.16
		var local: float = clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
		if local <= 0.0:
			continue
		var eased: float = 1.0 - pow(1.0 - local, 3.0)
		var radius: float = reach * RING_MAX_RATIO * eased
		var alpha: float = pow(1.0 - local, 1.7) * 0.85
		if radius <= 1.0 or alpha <= 0.004:
			continue
		draw_arc(
			origin,
			radius,
			0.0,
			TAU,
			96,
			Color(accent.r, accent.g, accent.b, alpha),
			maxf(2.0, 7.0 * (1.0 - local)),
			true
		)

	# 向外飞散并淡出的光点。
	var spark_eased: float = 1.0 - pow(1.0 - progress, 2.4)
	var spark_alpha: float = pow(1.0 - progress, 1.5)
	if spark_alpha <= 0.004:
		return
	for index: int in range(SPARK_COUNT):
		var distance: float = (
			reach * SPARK_MAX_RATIO * spark_eased * _spark_scales[index]
		)
		var direction := Vector2(
			cos(_spark_angles[index]),
			sin(_spark_angles[index])
		)
		draw_circle(
			origin + direction * distance,
			maxf(1.5, 5.0 * (1.0 - progress) * _spark_scales[index]),
			Color(tint.r, tint.g, tint.b, spark_alpha)
		)
