class_name PotionAuraOverlay
extends Control

## 药水生效期间贴在屏幕四周的呼吸光晕。
##
## 颜色取自药水图标本身投出的光晕色相（迅捷 13°、洞察 213°、绿药 87°），
## 只把饱和度提到低透明度下仍能看清的程度，所以屏幕边缘的颜色和玩家在
## 背包里看到的那瓶药是同一个色调。
##
## 用嵌套描边矩形手工画渐变而不是着色器：这样不依赖任何 .gdshader 资源，
## 也能在 GL Compatibility 后端上稳定工作。

const BAND_COUNT: int = 24
## 光晕向内延伸的深度，占屏幕短边的比例。
const DEPTH_RATIO: float = 0.18
## 最外圈的不透明度上限。药水一喝就是 20 秒，浓度必须"一眼看得见但不挡路"：
## 逐档对比过 0.42/0.34/0.26/0.20，0.20 容易被忽略、0.42 长时间看着累。
const PEAK_ALPHA: float = 0.34
## 呼吸节奏（次/秒）与深浅范围。
const PULSE_HZ: float = 0.55
const PULSE_MIN: float = 0.72

var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

## 0 = 完全不显示，1 = 满强度。淡入淡出由外部 tween 驱动。
var strength: float = 0.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()

var _pulse_time: float = 0.0


func _ready() -> void:
	name = "PotionAuraOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0


func _process(delta: float) -> void:
	if strength <= 0.001:
		return
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if strength <= 0.001:
		return
	var view: Vector2 = size
	if view.x <= 0.0 or view.y <= 0.0:
		return

	var pulse: float = lerpf(
		PULSE_MIN,
		1.0,
		0.5 + 0.5 * sin(_pulse_time * TAU * PULSE_HZ)
	)
	var depth: float = minf(view.x, view.y) * DEPTH_RATIO
	# 每圈都比上一圈厚一点点，避免相邻描边之间出现未覆盖的缝。
	var band_width: float = depth / float(BAND_COUNT) + 1.0

	for band: int in range(BAND_COUNT):
		var t: float = float(band) / float(BAND_COUNT)
		var inset: float = depth * t
		var falloff: float = pow(1.0 - t, 2.6)
		var alpha: float = PEAK_ALPHA * falloff * strength * pulse
		if alpha <= 0.002:
			continue
		draw_rect(
			Rect2(
				inset,
				inset,
				view.x - inset * 2.0,
				view.y - inset * 2.0
			),
			Color(tint.r, tint.g, tint.b, alpha),
			false,
			band_width
		)
