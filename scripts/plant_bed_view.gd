class_name PlantBedView
extends Control

## 光合平衡里的那一畦苗。
##
## 三种供给在这里不是三根抽象的柱子，而是三样看得见的东西：顶上那盏灯的亮度
## 和光锥宽度是光照，土里那层水位是水分，空气里飘的颗粒是二氧化碳。苗的高度
## 就是三者里**最矮**的那一项。
##
## 这个视图存在的全部理由是那条停滞线：按下培育之后，苗一路往上长，然后在
## 最短那项供给的高度上停住，那里会横过来一条短板颜色的线。"限制因子"这四个
## 字讲一百遍，都不如让玩家看着自己的苗在水位那么高的地方停下来一次。

enum Phase {
	IDLE,    ## 还没培育：土里只有一粒种子
	GROWING, ## 正在长高
	SETTLED, ## 长到头了，停滞线和花都出来了
}

const SKY := Color(0.07, 0.09, 0.08, 1.0)
const PLANTER := Color(0.52, 0.31, 0.22, 1.0)
const PLANTER_RIM := Color(0.66, 0.41, 0.28, 1.0)
const SOIL := Color(0.20, 0.15, 0.11, 1.0)
const SOIL_TOP := Color(0.28, 0.21, 0.15, 1.0)
const WATER := Color(0.42, 0.76, 1.00, 1.0)
const LIGHT := Color(1.00, 0.86, 0.42, 1.0)
const CARBON := Color(0.62, 0.94, 0.58, 1.0)
const STEM := Color(0.40, 0.68, 0.32, 1.0)
const LEAF := Color(0.46, 0.78, 0.36, 1.0)
const LEAF_DEEP := Color(0.30, 0.56, 0.26, 1.0)
const BELL := Color(0.58, 0.52, 0.92, 1.0)
const BELL_LIP := Color(0.76, 0.72, 1.00, 1.0)
const TARGET_LINE := Color(0.98, 0.86, 0.45, 0.95)
const SEED := Color(0.72, 0.60, 0.36, 1.0)

const GROW_TIME: float = 1.5
## 空气里同时飘的颗粒上限，二氧化碳给满时才用得到这么多。
const MOTE_COUNT: int = 16

var light: int = 0
var water: int = 0
var carbon: int = 0
## 三项共用的绘制标尺，取本关三个 cap 里的最大值。
var scale_max: int = 6
var target: int = 1
## 短板通道名，与 PhotosynthesisMinigame.CHANNELS 一致。
var limiting: String = "light"

var _phase: int = Phase.IDLE
var _phase_time: float = 0.0
var _time: float = 0.0
var _grown: float = 0.0
var _motes: Array[Dictionary] = []
## 土粒：xy 是花槽内的归一化位置，z 是半径。只摇一次，逐帧重摇会闪。
var _specks: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	for index: int in range(MOTE_COUNT):
		_motes.append(_new_mote(_rng.randf()))
	for index: int in range(26):
		_specks.append(Vector3(
			_rng.randf(), _rng.randf(), _rng.randf_range(1.0, 2.1)
		))


func _new_mote(life: float) -> Dictionary:
	return {
		"life": life,
		"x": _rng.randf(),
		"speed": _rng.randf_range(0.09, 0.20),
		"sway": _rng.randf() * TAU,
		"size": _rng.randf_range(1.4, 2.8),
	}


## 生长值就是三项供给里最小的那一项——这条规则本身就是本关要教的东西。
func growth() -> int:
	return mini(light, mini(water, carbon))


func cultivate() -> void:
	_phase = Phase.GROWING
	_phase_time = 0.0
	_grown = 0.0


func reset_plant() -> void:
	_phase = Phase.IDLE
	_phase_time = 0.0
	_grown = 0.0


func is_running() -> bool:
	return _phase == Phase.GROWING


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta

	for mote: Dictionary in _motes:
		mote["life"] = float(mote["life"]) + delta * float(mote["speed"])
		if float(mote["life"]) >= 1.0:
			var fresh: Dictionary = _new_mote(0.0)
			for key: String in fresh:
				mote[key] = fresh[key]

	if _phase == Phase.GROWING:
		var progress: float = clampf(_phase_time / GROW_TIME, 0.0, 1.0)
		# 收尾放慢，苗是"顶到头"而不是"撞到头"。
		_grown = float(growth()) * (1.0 - pow(1.0 - progress, 2.2))
		if progress >= 1.0:
			_phase = Phase.SETTLED
			_phase_time = 0.0
	elif _phase == Phase.SETTLED:
		_grown = float(growth())
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 16.0 or h <= 16.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), SKY)

	var planter_h: float = clampf(h * 0.26, 34.0, 54.0)
	var soil_y: float = h - planter_h
	var canopy: float = 18.0
	var span: float = soil_y - canopy
	if span <= 8.0:
		return
	var unit: float = span / float(maxi(scale_max, 1))
	var stem_x: float = w * 0.5

	_draw_carbon(w, canopy, soil_y)
	_draw_lamp(w, canopy, soil_y)
	_draw_planter(w, soil_y, planter_h)
	_draw_target(w, soil_y, unit)
	_draw_plant(stem_x, soil_y, unit)
	_draw_ceiling(w, soil_y, unit)


## 灯：亮度、光锥宽度和射线条数都随光照走。光照为 0 时灯是灭的，
## 这样"我一点光都没给"是看得出来的，而不是只体现在一个数字上。
func _draw_lamp(w: float, canopy: float, soil_y: float) -> void:
	var strength: float = clampf(float(light) / float(maxi(scale_max, 1)), 0.0, 1.0)
	var at := Vector2(w * 0.5, canopy * 0.55)

	draw_line(Vector2(at.x, 0.0), Vector2(at.x, at.y - 4.0), Color(0.42, 0.36, 0.26), 2.0)
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-13.0, -5.0), at + Vector2(13.0, -5.0),
			at + Vector2(8.0, 6.0), at + Vector2(-8.0, 6.0),
		]),
		Color(0.46, 0.38, 0.24)
	)
	if strength <= 0.01:
		return

	var flicker: float = 1.0 + 0.05 * sin(_time * 5.3)
	# 光锥：越亮越宽越白，一直洒到土面上。
	var spread: float = w * (0.10 + 0.30 * strength)
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-8.0, 6.0), at + Vector2(8.0, 6.0),
			Vector2(at.x + spread, soil_y), Vector2(at.x - spread, soil_y),
		]),
		Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.05 + 0.13 * strength)
	)
	var bulb: float = (4.0 + 4.0 * strength) * flicker
	for step: int in range(8):
		var k: float = float(step) / 7.0
		draw_circle(
			at + Vector2(0.0, 6.0),
			bulb * (1.0 + k * 2.6),
			Color(LIGHT.r, LIGHT.g, LIGHT.b, strength * pow(1.0 - k, 2.0) * 0.16)
		)
	draw_circle(at + Vector2(0.0, 6.0), bulb, Color(1.0, 0.96, 0.80, 0.55 + 0.45 * strength))
	# 射线条数直接等于光照点数，可以数。
	for ray: int in range(light):
		var t: float = (float(ray) + 0.5) / float(maxi(light, 1))
		var x: float = at.x + (t - 0.5) * spread * 1.7
		draw_line(
			Vector2(at.x + (t - 0.5) * 14.0, at.y + 8.0),
			Vector2(x, soil_y - 3.0),
			Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.10 + 0.16 * strength),
			1.5
		)


## 二氧化碳：空气里飘的颗粒，数量正比于供给。给 0 的时候空气是空的。
func _draw_carbon(w: float, canopy: float, soil_y: float) -> void:
	var shown: int = clampi(
		int(round(float(MOTE_COUNT) * float(carbon) / float(maxi(scale_max, 1)))),
		0, MOTE_COUNT
	)
	for index: int in range(shown):
		var mote: Dictionary = _motes[index]
		var life: float = clampf(float(mote["life"]), 0.0, 1.0)
		var x: float = (
			float(mote["x"]) * (w - 24.0) + 12.0
			+ sin(_time * 0.8 + float(mote["sway"])) * 7.0
		)
		var y: float = soil_y - (soil_y - canopy) * life
		draw_circle(
			Vector2(x, y),
			float(mote["size"]),
			Color(CARBON.r, CARBON.g, CARBON.b, sin(life * PI) * 0.55)
		)


## 花槽与土。水位画在土里，越高说明水越足；水为 0 时土是干的。
func _draw_planter(w: float, soil_y: float, planter_h: float) -> void:
	var half: float = w * 0.34
	var inner := Rect2(w * 0.5 - half, soil_y, half * 2.0, planter_h)

	draw_rect(inner, PLANTER)
	draw_rect(Rect2(inner.position.x - 6.0, soil_y - 6.0, inner.size.x + 12.0, 8.0), PLANTER_RIM)

	var soil := Rect2(inner.position.x + 4.0, soil_y, inner.size.x - 8.0, planter_h - 5.0)
	draw_rect(soil, SOIL)
	draw_rect(Rect2(soil.position.x, soil.position.y, soil.size.x, 3.0), SOIL_TOP)

	var wet: float = clampf(float(water) / float(maxi(scale_max, 1)), 0.0, 1.0)
	if wet > 0.005:
		var depth: float = soil.size.y * wet
		draw_rect(
			Rect2(soil.position.x, soil.position.y + soil.size.y - depth, soil.size.x, depth),
			Color(WATER.r, WATER.g, WATER.b, 0.34)
		)
		# 水面的一道亮线，让"水位"读起来是水位而不是一块蓝色。
		var line_y: float = soil.position.y + soil.size.y - depth
		draw_line(
			Vector2(soil.position.x, line_y),
			Vector2(soil.position.x + soil.size.x, line_y),
			Color(WATER.r, WATER.g, WATER.b, 0.80), 1.5
		)
	# 土粒压在水色上面。少了这一层，蓄满水的花槽会读成一缸水而不是湿土。
	for speck: Vector3 in _specks:
		draw_circle(
			Vector2(
				soil.position.x + speck.x * soil.size.x,
				soil.position.y + speck.y * soil.size.y
			),
			speck.z,
			Color(SOIL.r * 0.66, SOIL.g * 0.66, SOIL.b * 0.66, 0.60)
		)
	draw_rect(inner, PLANTER_RIM, false, 2.0)


## 目标高度：一条金色虚线。苗有没有够到它，一眼就知道。
func _draw_target(w: float, soil_y: float, unit: float) -> void:
	if target <= 0:
		return
	var y: float = soil_y - unit * float(target)
	var dash: float = 7.0
	var x: float = 8.0
	while x < w - 8.0:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, w - 8.0), y), TARGET_LINE, 1.5)
		x += dash * 2.0
	var font := ThemeDB.fallback_font
	draw_string(
		font, Vector2(w - 46.0, y - 4.0), "目标",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TARGET_LINE
	)


func _draw_plant(stem_x: float, soil_y: float, unit: float) -> void:
	if _phase == Phase.IDLE:
		# 还没培育：土面上只有一粒种子。
		draw_circle(Vector2(stem_x, soil_y - 3.0), 4.5, SEED)
		draw_arc(Vector2(stem_x, soil_y - 3.0), 4.5, 0.0, TAU, 14, LEAF_DEEP, 1.0, true)
		return

	var height: float = _grown * unit
	if height <= 1.0:
		draw_circle(Vector2(stem_x, soil_y - 3.0), 4.5, SEED)
		return

	# 茎在风里微微摆，越靠顶端摆得越多。
	var top := Vector2(
		stem_x + sin(_time * 1.4) * 3.0 * (height / maxf(unit, 1.0)) * 0.12,
		soil_y - height
	)
	var stem := PackedVector2Array()
	var steps: int = 12
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		stem.append(Vector2(
			stem_x + (top.x - stem_x) * pow(t, 1.6),
			soil_y - height * t
		))
	draw_polyline(stem, STEM, 3.0)

	# 每长满一格生出一对叶子，所以叶子的对数就是生长值，可以数。
	var pairs: int = int(floor(_grown))
	for pair: int in range(pairs):
		var t: float = (float(pair) + 0.55) / float(maxi(pairs, 1))
		var node: Vector2 = Vector2(
			stem_x + (top.x - stem_x) * pow(t, 1.6), soil_y - height * t
		)
		var reach: float = unit * (1.15 - 0.35 * t)
		var droop: float = 0.30 + 0.12 * sin(_time * 1.1 + float(pair))
		_draw_leaf(node, reach, droop, 1.0)
		_draw_leaf(node, reach, droop, -1.0)

	if _phase == Phase.SETTLED and growth() >= target and target > 0:
		_draw_bells(top, unit)


func _draw_leaf(node: Vector2, reach: float, droop: float, side: float) -> void:
	var tip := node + Vector2(reach * side, reach * droop)
	var mid := node + Vector2(reach * 0.52 * side, -reach * 0.16)
	var low := node + Vector2(reach * 0.52 * side, reach * 0.44)
	draw_colored_polygon(
		PackedVector2Array([node, mid, tip, low]),
		LEAF if side > 0.0 else LEAF_DEEP
	)
	draw_line(node, tip, LEAF_DEEP if side > 0.0 else LEAF, 1.0)


## 够到目标才开花。蓝铃花是温室这一关要采的东西，开出来才算真的成了。
func _draw_bells(top: Vector2, unit: float) -> void:
	var bloom: float = clampf(_phase_time / 0.6, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - bloom, 2.4)
	var scale: float = maxf(4.0, unit * 0.42) * eased
	if scale <= 0.5:
		return
	for index: int in range(3):
		var angle: float = -PI * 0.5 + (float(index) - 1.0) * 0.85
		var hang: Vector2 = top + Vector2(cos(angle), sin(angle)) * scale * 1.5
		draw_line(top, hang, STEM, 1.5)
		var sway: float = sin(_time * 1.6 + float(index) * 1.3) * scale * 0.10
		var bell: Vector2 = hang + Vector2(sway, scale * 0.9)
		draw_colored_polygon(
			PackedVector2Array([
				hang + Vector2(-scale * 0.42, 0.0),
				hang + Vector2(scale * 0.42, 0.0),
				bell + Vector2(scale * 0.30, 0.0),
				bell + Vector2(-scale * 0.30, 0.0),
			]),
			BELL
		)
		draw_line(
			bell + Vector2(-scale * 0.34, 0.0), bell + Vector2(scale * 0.34, 0.0),
			BELL_LIP, 2.0
		)


## 停滞线：苗停在哪一格，就在那一格横一条短板颜色的线。这条线是整个
## 视图的目的——它把"限制因子"从一句话变成了画面上一个具体的高度。
func _draw_ceiling(w: float, soil_y: float, unit: float) -> void:
	if _phase != Phase.SETTLED:
		return
	var value: int = growth()
	if value >= target:
		return
	var y: float = soil_y - unit * float(value)
	var tint: Color = LIGHT
	if limiting == "water":
		tint = WATER
	elif limiting == "carbon":
		tint = CARBON
	var pulse: float = 0.55 + 0.30 * sin(_time * 3.4)
	draw_line(
		Vector2(6.0, y), Vector2(w - 6.0, y),
		Color(tint.r, tint.g, tint.b, pulse), 2.0
	)
	for step: int in range(7):
		var x: float = 10.0 + float(step) * (w - 20.0) / 6.0
		draw_line(
			Vector2(x, y), Vector2(x - 4.0, y + 5.0),
			Color(tint.r, tint.g, tint.b, pulse * 0.8), 1.5
		)
