class_name FlameJarView
extends Control

## 烛火与空气里的一只玻璃罐。
##
## 把三个参数画成看得见的东西：罐内空气画成底部的浅色气层，通气孔画成罐颈
## 两侧的开口和向内的气流，灯芯倍率画成火焰的大小。这样"带孔的小罐能赢过
## 密封的大罐"是可以用眼睛比出来的，而不必先做除法。
##
## 火焰不是一张静止的图形：它每帧按几组不互相整除的正弦重新生成轮廓，所以
## 摇曳看不出循环；每只罐子有自己的相位，一排罐子不会齐步闪。罐子被点选时
## 地面浮起一圈法阵，点火后气层真的会往下掉，掉空的那一刻火焰会挣扎两下再
## 熄灭并冒烟——玩家的预测是被"演"出来的，不是被判分的。

signal picked

enum Phase {
	COLD,     ## 未点火：只有余烬般的微光
	IGNITING, ## 点火瞬间的爆燃
	BURNING,  ## 正常燃烧，气层随剩余空气下降
	GUTTERING,## 空气耗尽，火焰挣扎
	DEAD,     ## 已熄灭，只剩烟
}

const GLASS := Color(0.62, 0.78, 0.86, 0.55)
const GLASS_FILL := Color(0.30, 0.45, 0.55, 0.18)
const AIR := Color(0.55, 0.82, 1.00, 0.34)
const WAX := Color(0.92, 0.88, 0.74, 1.0)
const VENT := Color(0.98, 0.80, 0.38, 1.0)
const SIGIL := Color(1.00, 0.82, 0.38, 1.0)
const SIGIL_RIGHT := Color(0.55, 0.95, 0.55, 1.0)
const SIGIL_WRONG := Color(1.00, 0.44, 0.34, 1.0)

## 火焰由外到内四层，越靠内越白越不透明。
const FLAME_LAYERS: Array[Dictionary] = [
	{"color": Color(1.00, 0.42, 0.10, 0.20), "scale": 1.34, "width": 1.55},
	{"color": Color(1.00, 0.55, 0.16, 0.72), "scale": 1.00, "width": 1.00},
	{"color": Color(1.00, 0.80, 0.32, 0.88), "scale": 0.66, "width": 0.60},
	{"color": Color(1.00, 0.97, 0.86, 1.00), "scale": 0.34, "width": 0.34},
]

## 空气量画成气层高度时的换算上限，超过这个值就画满。
const AIR_FULL: float = 30.0
const EMBER_COUNT: int = 7
const IGNITE_TIME: float = 0.42
const GUTTER_TIME: float = 0.55
const SMOKE_TIME: float = 1.30

var air: float = 6.0
var vents: float = 0.0
var burn: float = 1.0

## 剩余空气比例，1 = 满，0 = 耗尽。点火后由小游戏逐帧写入。
var fuel: float = 1.0
## 点选顺序，-1 表示未选。
var pick_order: int = -1
## 点火后揭晓这一格预测是否正确；-1 未判定，0 错，1 对。
var verdict: int = -1
## 通气速率不小于耗氧速率的罐子永不熄灭，画成稳定的亮焰。
var eternal: bool = false

var _phase: int = Phase.COLD
var _time: float = 0.0
var _phase_time: float = 0.0
var _seed: float = 0.0
var _pick_pop: float = 0.0
var _hover: float = 0.0
var _embers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	# 每只罐子一个固定相位，否则一排火焰会整整齐齐地同时摇同时闪。
	_seed = _rng.randf() * TAU
	for index: int in range(EMBER_COUNT):
		_embers.append(_new_ember(_rng.randf()))


func _new_ember(life_start: float) -> Dictionary:
	return {
		"life": life_start,
		"speed": _rng.randf_range(0.55, 1.05),
		"drift": _rng.randf_range(-1.0, 1.0),
		"size": _rng.randf_range(0.8, 2.0),
		"phase": _rng.randf() * TAU,
	}


func ignite() -> void:
	_phase = Phase.IGNITING
	_phase_time = 0.0
	fuel = 1.0


func extinguish() -> void:
	if _phase == Phase.GUTTERING or _phase == Phase.DEAD:
		return
	_phase = Phase.GUTTERING
	_phase_time = 0.0


## 回到未点火状态。重排之后必须走这里，否则上一轮烧完的罐子会一直黑着。
func reset_flame() -> void:
	_phase = Phase.COLD
	_phase_time = 0.0
	fuel = 1.0
	verdict = -1


func is_lit() -> bool:
	return _phase == Phase.IGNITING or _phase == Phase.BURNING


func mark_picked(order: int) -> void:
	var was: int = pick_order
	pick_order = order
	if order >= 0 and was != order:
		_pick_pop = 1.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = 1.0
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = 0.0


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	_pick_pop = maxf(0.0, _pick_pop - delta * 2.2)

	if _phase == Phase.IGNITING and _phase_time >= IGNITE_TIME:
		_phase = Phase.BURNING
		_phase_time = 0.0
	elif _phase == Phase.GUTTERING and _phase_time >= GUTTER_TIME:
		_phase = Phase.DEAD
		_phase_time = 0.0

	if is_lit():
		for ember: Dictionary in _embers:
			ember["life"] = float(ember["life"]) + delta * float(ember["speed"])
			if float(ember["life"]) >= 1.0:
				var fresh: Dictionary = _new_ember(0.0)
				for key: String in fresh:
					ember[key] = fresh[key]
	queue_redraw()


## 火焰形状。t 从 0（灯芯）到 1（焰尖），宽度先鼓后收，中心线越靠焰尖
## 摆得越厉害，所以整支火焰是"根部稳、尖部飘"，而不是整体平移。
func _flame_polygon(
	base: Vector2, height: float, width: float, lean: float
) -> PackedVector2Array:
	var samples: int = 13
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	for index: int in range(samples + 1):
		var t: float = float(index) / float(samples)
		var profile: float = (
			pow(sin(PI * pow(t, 0.75)), 0.9) * pow(maxf(0.0, 1.0 - t), 0.30)
		)
		var wobble: float = (
			sin(_time * 6.3 + _seed + t * 3.1) * 0.55
			+ sin(_time * 9.7 + _seed * 1.7 + t * 5.3) * 0.30
			+ sin(_time * 15.1 + _seed * 2.3 + t * 8.7) * 0.15
		)
		var sway: float = wobble * pow(t, 1.8) * width * 0.44
		var centre: float = base.x + sway + lean * pow(t, 1.5) * width * 0.9
		var half: float = profile * width * 0.5
		var y: float = base.y - height * t
		right.append(Vector2(centre + half, y))
		left.append(Vector2(centre - half, y))
	left.reverse()
	return right + left


## 一团柔和的光晕：由大而淡到小而亮叠若干个圆，模拟火光的衰减。
## 步数少了会看出一圈圈同心环，所以取 16 步并把单步透明度压到很低，
## 叠加之后的总亮度不变，但边界糊掉了。
func _draw_glow(centre: Vector2, radius: float, tint: Color, strength: float) -> void:
	if strength <= 0.01 or radius <= 0.5:
		return
	var steps: int = 16
	for index: int in range(steps):
		var k: float = float(index) / float(steps - 1)
		var ring: float = radius * (1.0 - k * 0.82)
		var alpha: float = strength * pow(k, 1.9) * 0.095
		if alpha <= 0.002:
			continue
		draw_circle(centre, ring, Color(tint.r, tint.g, tint.b, alpha))


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var jar := Rect2(w * 0.15, h * 0.05, w * 0.70, h * 0.72)
	var base_y: float = jar.position.y + jar.size.y
	var centre_x: float = jar.position.x + jar.size.x * 0.5

	_draw_sigil(Vector2(centre_x, base_y + h * 0.085), jar.size.x * 0.52)
	_draw_air(jar, base_y)

	var candle_w: float = jar.size.x * 0.22
	var candle_h: float = jar.size.y * 0.30
	var wick := Vector2(centre_x, base_y - candle_h)
	_draw_flame(wick, jar)
	draw_rect(
		Rect2(centre_x - candle_w * 0.5, base_y - candle_h, candle_w, candle_h),
		WAX
	)
	_draw_wax_light(centre_x, base_y, candle_w, candle_h)
	_draw_embers(wick, jar)
	_draw_smoke(wick)
	_draw_glass(jar, base_y, wick)
	_draw_numeral(jar)


## 罐内空气。分几层画出上浅下深的渐变，顶面随火焰轻轻起伏，看起来像
## 真的在被消耗，而不是一块贴上去的蓝色。
func _draw_air(jar: Rect2, base_y: float) -> void:
	draw_rect(jar, GLASS_FILL)
	var shown: float = clampf(air / AIR_FULL, 0.05, 1.0) * clampf(fuel, 0.0, 1.0)
	if eternal:
		shown = maxf(shown, clampf(air / AIR_FULL, 0.05, 1.0) * 0.9)
	var height: float = jar.size.y * shown
	if height <= 0.5:
		return
	var bands: int = 10
	for index: int in range(bands):
		var k: float = float(index) / float(bands)
		var top: float = base_y - height * (1.0 - k)
		# 每一层都从自己的顶边一直铺到罐底，越靠下叠得越多，于是渐变是叠出
		# 来的而不是拼出来的——分段画会在每条接缝上留下一道可见的横纹。
		var alpha: float = AIR.a * (0.42 if index == 0 else 0.085)
		draw_rect(
			Rect2(jar.position.x, top, jar.size.x, base_y - top),
			Color(AIR.r, AIR.g, AIR.b, alpha)
		)
	# 气层顶面的微澜。
	var surface: float = base_y - height
	var points := PackedVector2Array()
	var steps: int = 10
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		var y: float = surface + sin(_time * 2.4 + _seed + t * 6.0) * 1.4
		points.append(Vector2(jar.position.x + jar.size.x * t, y))
	draw_polyline(points, Color(0.78, 0.94, 1.0, 0.42), 1.5)


func _draw_flame(wick: Vector2, jar: Rect2) -> void:
	if _phase == Phase.DEAD or _phase == Phase.COLD:
		if _phase == Phase.COLD:
			# 未点火时留一点余烬的暗红，让罐子不像是空的。
			_draw_glow(wick + Vector2(0.0, -3.0), jar.size.x * 0.20,
				Color(1.0, 0.45, 0.18), 0.45)
			draw_circle(wick + Vector2(0.0, -2.0), 2.2,
				Color(1.0, 0.52, 0.22, 0.75))
		return

	var strength: float = clampf(burn, 0.0, 3.0)
	var height: float = jar.size.y * (0.16 + 0.055 * strength)
	var width: float = jar.size.x * 0.20 * (0.72 + 0.16 * strength)

	# 点火瞬间先爆一下再落回常态，这一下是"我按了点火"的确认。
	if _phase == Phase.IGNITING:
		var p: float = clampf(_phase_time / IGNITE_TIME, 0.0, 1.0)
		var flare: float = 1.0 + 1.5 * pow(1.0 - p, 2.4)
		height *= flare
		width *= 1.0 + 0.9 * pow(1.0 - p, 2.0)
	elif _phase == Phase.BURNING:
		# 空气见底时火焰自己会变小，玩家不用看数字也知道快了。
		var low: float = clampf(fuel / 0.30, 0.0, 1.0)
		height *= 0.45 + 0.55 * low
		width *= 0.60 + 0.40 * low
	elif _phase == Phase.GUTTERING:
		# 熄灭前的挣扎：两次回光返照，然后塌下去。
		var g: float = clampf(_phase_time / GUTTER_TIME, 0.0, 1.0)
		var struggle: float = absf(sin(g * PI * 2.4)) * pow(1.0 - g, 1.4)
		height *= 0.16 + 0.95 * struggle
		width *= 0.30 + 0.70 * struggle

	# 呼吸感：两组不同频率的抖动叠加，肉眼找不到周期。
	height *= (
		1.0 + 0.075 * sin(_time * 11.3 + _seed)
		+ 0.045 * sin(_time * 7.1 + _seed * 1.9)
	)
	width *= 1.0 + 0.06 * sin(_time * 8.9 + _seed * 1.3)
	if height <= 1.0 or width <= 0.5:
		return

	var lean: float = (
		sin(_time * 1.7 + _seed) * 0.12 + sin(_time * 0.9 + _seed * 2.1) * 0.08
	)
	if eternal and _phase == Phase.BURNING:
		# 通气孔持续补气，火苗被吹得偏向一侧且更稳。
		lean += 0.10
		height *= 1.06

	# 熄灭过程中整支火焰（含光晕）一起淡出，否则火没了光还在。
	var lit: float = 1.0
	if _phase == Phase.GUTTERING:
		lit = clampf(1.0 - _phase_time / GUTTER_TIME, 0.0, 1.0)
	_draw_glow(
		wick + Vector2(0.0, -height * 0.42),
		height * 1.55,
		Color(1.0, 0.62, 0.24),
		(0.85 + 0.35 * _hover) * lit
	)
	for layer: Dictionary in FLAME_LAYERS:
		var colour: Color = layer["color"]
		var polygon: PackedVector2Array = _flame_polygon(
			wick,
			height * float(layer["scale"]),
			width * float(layer["width"]),
			lean
		)
		draw_colored_polygon(
			polygon, Color(colour.r, colour.g, colour.b, colour.a * lit)
		)


## 蜡烛被自己的火照亮的那一圈暖光，以及台面上的投影。
func _draw_wax_light(centre_x: float, base_y: float, cw: float, ch: float) -> void:
	if not is_lit():
		return
	var glow: float = 0.32 + 0.06 * sin(_time * 9.0 + _seed)
	draw_rect(
		Rect2(centre_x - cw * 0.5, base_y - ch, cw, ch * 0.45),
		Color(1.0, 0.72, 0.34, glow)
	)
	draw_rect(
		Rect2(centre_x - cw * 0.9, base_y - 2.0, cw * 1.8, 2.0),
		Color(1.0, 0.66, 0.28, 0.22)
	)


func _draw_embers(wick: Vector2, jar: Rect2) -> void:
	if not is_lit():
		return
	var rise: float = jar.size.y * 0.42
	for ember: Dictionary in _embers:
		var life: float = clampf(float(ember["life"]), 0.0, 1.0)
		var alpha: float = sin(life * PI) * 0.85
		if alpha <= 0.02:
			continue
		var drift: float = (
			float(ember["drift"]) * 9.0 * life
			+ sin(_time * 3.4 + float(ember["phase"])) * 3.4 * life
		)
		var point := Vector2(
			wick.x + drift, wick.y - 6.0 - rise * pow(life, 0.85)
		)
		# 罐口封着，火星不该穿过玻璃飞出去。
		point.y = maxf(point.y, jar.position.y + 4.0)
		draw_circle(
			point,
			float(ember["size"]) * (1.0 - life * 0.5),
			Color(1.0, 0.72 - 0.25 * life, 0.30, alpha)
		)


func _draw_smoke(wick: Vector2) -> void:
	if _phase != Phase.DEAD:
		return

	# 熄灭那一下的光环。没有它，火焰只是慢慢淡掉；有了它，每一次"灭"都是
	# 一个能被数出来的节拍——玩家排的顺序对不对，是靠数这个节拍看出来的。
	var snuff: float = clampf(_phase_time / 0.28, 0.0, 1.0)
	if snuff < 1.0:
		draw_arc(
			wick + Vector2(0.0, -4.0),
			4.0 + snuff * 26.0,
			0.0, TAU, 28,
			Color(1.0, 0.72, 0.34, pow(1.0 - snuff, 1.4) * 0.70),
			maxf(1.0, 3.2 * (1.0 - snuff)),
			true
		)

	var t: float = clampf(_phase_time / SMOKE_TIME, 0.0, 1.0)
	if t >= 1.0:
		return
	var fade: float = pow(1.0 - t, 1.6)
	for index: int in range(5):
		var offset: float = float(index) * 0.18
		var local: float = clampf(t - offset, 0.0, 1.0)
		if local <= 0.0:
			continue
		var y: float = wick.y - 5.0 - local * 40.0
		var x: float = wick.x + sin(local * 4.0 + _seed + offset * 3.0) * 7.0 * local
		# 刚离开灯芯的一团还是热的，升上去才冷成灰色。
		var heat: float = pow(1.0 - local, 2.2)
		draw_circle(
			Vector2(x, y),
			2.5 + local * 8.0,
			Color(
				0.78 + 0.22 * heat,
				0.75 - 0.12 * heat,
				0.72 - 0.40 * heat,
				(0.40 + 0.30 * heat) * fade * (1.0 - local * 0.7)
			)
		)


## 罐壁。有通气孔时颈部留缺口并画出向内流动的气流；火在烧的时候玻璃会
## 被映出一道暖色的边光。
func _draw_glass(jar: Rect2, base_y: float, wick: Vector2) -> void:
	var right_x: float = jar.position.x + jar.size.x
	var neck_y: float = jar.position.y + jar.size.y * 0.16

	if vents > 0.0:
		var gap: float = jar.size.y * 0.06
		draw_line(jar.position, Vector2(jar.position.x, neck_y - gap), GLASS, 3.0)
		draw_line(Vector2(jar.position.x, neck_y + gap),
			Vector2(jar.position.x, base_y), GLASS, 3.0)
		draw_line(Vector2(right_x, jar.position.y),
			Vector2(right_x, neck_y - gap), GLASS, 3.0)
		draw_line(Vector2(right_x, neck_y + gap),
			Vector2(right_x, base_y), GLASS, 3.0)
		draw_line(jar.position, Vector2(right_x, jar.position.y), GLASS, 3.0)
		_draw_vent_flow(jar, neck_y, right_x)
	else:
		draw_rect(jar, GLASS, false, 3.0)

	# 玻璃上的高光。压得很短很淡，长了会读成一道划痕而不是反光。
	draw_line(
		Vector2(jar.position.x + jar.size.x * 0.13, jar.position.y + jar.size.y * 0.10),
		Vector2(jar.position.x + jar.size.x * 0.19, jar.position.y + jar.size.y * 0.32),
		Color(1.0, 1.0, 1.0, 0.11), 2.5
	)

	if is_lit():
		var warm: float = 0.26 + 0.08 * sin(_time * 7.7 + _seed)
		var top: float = maxf(jar.position.y, wick.y - jar.size.y * 0.34)
		draw_line(Vector2(jar.position.x, top), Vector2(jar.position.x, base_y),
			Color(1.0, 0.66, 0.28, warm), 3.0)
		draw_line(Vector2(right_x, top), Vector2(right_x, base_y),
			Color(1.0, 0.66, 0.28, warm), 3.0)

	draw_line(
		Vector2(jar.position.x - 6.0, base_y),
		Vector2(right_x + 6.0, base_y),
		GLASS, 3.0
	)


## 通气孔的气流：向内流动的短线，速率越高线越多越快。
func _draw_vent_flow(jar: Rect2, neck_y: float, right_x: float) -> void:
	var lanes: int = clampi(int(ceilf(vents * 2.0)), 1, 3)
	var speed: float = 1.1 + vents * 1.4
	for lane: int in range(lanes):
		var y: float = neck_y + (float(lane) - float(lanes - 1) * 0.5) * 7.0
		for step: int in range(2):
			var flow: float = fmod(_time * speed + float(step) * 0.5 + float(lane) * 0.23, 1.0)
			var travel: float = 20.0 * flow
			var alpha: float = sin(flow * PI) * 0.95
			draw_line(
				Vector2(jar.position.x - 16.0 + travel, y),
				Vector2(jar.position.x - 8.0 + travel, y),
				Color(VENT.r, VENT.g, VENT.b, alpha), 2.0
			)
			draw_line(
				Vector2(right_x + 16.0 - travel, y),
				Vector2(right_x + 8.0 - travel, y),
				Color(VENT.r, VENT.g, VENT.b, alpha), 2.0
			)


## 被点选的罐子脚下浮起的法阵：两圈反向旋转的椭圆加一圈刻度。
## 点火后按预测对错换色，所以"第几个灭"的判定是在罐子自己身上揭晓的。
func _draw_sigil(centre: Vector2, radius: float) -> void:
	if pick_order < 0:
		return
	var tint: Color = SIGIL
	if verdict == 1:
		tint = SIGIL_RIGHT
	elif verdict == 0:
		tint = SIGIL_WRONG

	# 半径连同点选时的放大都必须收在控件宽度内：Control 的 _draw 不裁剪，
	# 涨出去会盖到旁边那只罐子上。
	var pop: float = 1.0 + _pick_pop * 0.25
	var breathe: float = 1.0 + 0.04 * sin(_time * 3.1 + _seed)
	var scale: float = pop * breathe
	var rx: float = radius * scale
	var ry: float = radius * 0.30 * scale
	var alpha: float = 0.85 + 0.15 * sin(_time * 4.0 + _seed)

	_draw_ellipse_ring(centre, rx, ry, _time * 0.8,
		Color(tint.r, tint.g, tint.b, alpha), 2.0)
	_draw_ellipse_ring(centre, rx * 0.66, ry * 0.66, -_time * 1.25,
		Color(tint.r, tint.g, tint.b, alpha * 0.65), 1.5)

	# 刻度：数量等于序号，不用读数字也能一眼看出这是第几个。
	var ticks: int = pick_order + 1
	for index: int in range(ticks):
		var angle: float = TAU * float(index) / float(maxi(ticks, 1)) + _time * 0.8
		var inner := centre + Vector2(cos(angle) * rx * 0.72, sin(angle) * ry * 0.72)
		var outer := centre + Vector2(cos(angle) * rx * 1.06, sin(angle) * ry * 1.06)
		draw_line(inner, outer, Color(tint.r, tint.g, tint.b, alpha), 2.0)

	if _pick_pop > 0.0:
		_draw_ellipse_ring(centre, rx * (1.0 + (1.0 - _pick_pop) * 0.60),
			ry * (1.0 + (1.0 - _pick_pop) * 0.60), 0.0,
			Color(tint.r, tint.g, tint.b, _pick_pop * 0.8), 2.5)


func _draw_ellipse_ring(
	centre: Vector2, rx: float, ry: float, rotation: float,
	colour: Color, width: float
) -> void:
	if rx <= 0.5 or ry <= 0.2:
		return
	var points := PackedVector2Array()
	var steps: int = 36
	for index: int in range(steps + 1):
		var angle: float = TAU * float(index) / float(steps) + rotation
		points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polyline(points, colour, width)


## 序号写在罐子上半部的空白处，带一层描边保证在火光上也读得清。
func _draw_numeral(jar: Rect2) -> void:
	if pick_order < 0:
		return
	var tint: Color = SIGIL
	if verdict == 1:
		tint = SIGIL_RIGHT
	elif verdict == 0:
		tint = SIGIL_WRONG
	var font := ThemeDB.fallback_font
	var font_size: int = int(22.0 * (1.0 + _pick_pop * 0.30))
	var label: String = str(pick_order + 1)
	var width: float = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var at := Vector2(
		jar.position.x + jar.size.x * 0.5 - width * 0.5,
		jar.position.y + jar.size.y * 0.26
	)
	var halo: float = 0.30 + 0.16 * sin(_time * 4.0 + _seed)
	_draw_glow(
		at + Vector2(width * 0.5, -font_size * 0.32),
		float(font_size) * 1.1, tint, halo
	)
	draw_string(font, at + Vector2(1.5, 1.5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.06, 0.03, 0.01, 0.85))
	draw_string(font, at, label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
