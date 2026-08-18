class_name SampleDishView
extends Control

## 变化分拣里的一只样本皿。
##
## 整个视图建立在一条规则上：**颜色代表物质，纹理代表状态**。冰和水同色异
## 纹，因为它们是同一种物质的两个状态；铁和锈异色，因为锈是另一种物质。于是
## "封盘之后皿里有没有出现新的颜色"和"有没有生成新物质"是同一件事——不是
## 近似，是等价。这条编码和脚本里原有的 chemical 标注逐条核对过，16 条全中。
##
## 所以判据不需要写在提示里：封盘之后新物质会自己亮起来，玩家看见的就是
## 化学变化的定义。

enum Phase {
	BEFORE,   ## 还没封盘：只显示变化前的样子
	CHANGING, ## 正在演变
	AFTER,    ## 演完了，新物质亮起来
}

## 物质色板。同一种物质在任何样本里都必须用同一个键，"同色即同物"这条
## 规则才立得住。
const SUBSTANCE: Dictionary = {
	"paper": Color(0.90, 0.86, 0.74),
	"ash": Color(0.32, 0.30, 0.28),
	"smoke": Color(0.56, 0.54, 0.51),
	"water": Color(0.42, 0.72, 0.95),
	"glass": Color(0.68, 0.86, 0.88),
	"sugar": Color(0.96, 0.94, 0.88),
	"iron": Color(0.60, 0.62, 0.66),
	"rust": Color(0.78, 0.42, 0.18),
	"wax": Color(0.94, 0.88, 0.70),
	"vinegar": Color(0.86, 0.80, 0.52),
	"co2": Color(0.58, 0.92, 0.72),
	"egg_raw": Color(0.90, 0.88, 0.68),
	"egg_set": Color(0.98, 0.97, 0.95),
	"cloth": Color(0.78, 0.64, 0.46),
	"silver": Color(0.86, 0.87, 0.90),
	"tarnish": Color(0.24, 0.22, 0.24),
	"milk": Color(0.96, 0.95, 0.90),
	"curd": Color(0.90, 0.84, 0.56),
	"salt": Color(0.95, 0.95, 0.93),
	"soda": Color(0.88, 0.92, 0.86),
	"fume": Color(0.72, 0.86, 0.52),
	"bronze": Color(0.80, 0.58, 0.28),
	"heat": Color(1.00, 0.62, 0.26),
	"steel": Color(0.70, 0.72, 0.76),
}

const DISH := Color(0.55, 0.62, 0.66, 0.85)
const DISH_FILL := Color(0.09, 0.10, 0.11, 0.80)
const NEW_MARK := Color(1.00, 0.82, 0.38, 1.0)
const RIGHT := Color(0.55, 0.92, 0.52, 1.0)
const WRONG := Color(1.00, 0.44, 0.34, 1.0)

const CHANGE_TIME: float = 0.85

## 每项写成 "物质:纹理"，纹理取 solid/liquid/grains/pieces/fibre/gas/coil/bar/glow。
var before: PackedStringArray = PackedStringArray()
var after: PackedStringArray = PackedStringArray()
## -1 未判定，0 分错，1 分对。
var verdict: int = -1

var _phase: int = Phase.BEFORE
var _phase_time: float = 0.0
var _time: float = 0.0
var _jitter: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(24):
		_jitter.append(rng.randf())


func play() -> void:
	_phase = Phase.CHANGING
	_phase_time = 0.0


func reset_dish() -> void:
	_phase = Phase.BEFORE
	_phase_time = 0.0
	verdict = -1


func is_playing() -> bool:
	return _phase == Phase.CHANGING


## 变化后才出现的物质。这个集合非空 <=> 生成了新物质 <=> 化学变化。
##
## glow 不参与计数：发光发热是反应的现象，不是反应生成的物质。把它算进去会
## 让"新物质"这枚色标名不副实，而这枚色标就是本关的判据。
func new_substances() -> PackedStringArray:
	var had := {}
	for entry: String in before:
		had[entry.get_slice(":", 0)] = true
	var fresh := PackedStringArray()
	for entry: String in after:
		if entry.get_slice(":", 1) == "glow":
			continue
		var key: String = entry.get_slice(":", 0)
		if not had.has(key) and not fresh.has(key):
			fresh.append(key)
	return fresh


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	if _phase == Phase.CHANGING and _phase_time >= CHANGE_TIME:
		_phase = Phase.AFTER
		_phase_time = 0.0
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 12.0 or h <= 12.0:
		return

	var bowl := Rect2(4.0, 4.0, w - 8.0, h - 8.0)
	draw_rect(bowl, DISH_FILL)

	var mix: float = 0.0
	if _phase == Phase.CHANGING:
		mix = clampf(_phase_time / CHANGE_TIME, 0.0, 1.0)
	elif _phase == Phase.AFTER:
		mix = 1.0

	if mix < 1.0:
		_draw_contents(bowl, before, 1.0 - mix)
	if mix > 0.0:
		_draw_contents(bowl, after, mix)

	var edge: Color = DISH
	if verdict == 1:
		edge = RIGHT
	elif verdict == 0:
		edge = WRONG
	draw_rect(bowl, edge, false, 2.0)

	if _phase == Phase.AFTER:
		_draw_new_marks(bowl)


func _draw_contents(bowl: Rect2, items: PackedStringArray, alpha: float) -> void:
	if alpha <= 0.02:
		return
	# 液体铺底，固体压在上面，气体升在最上层——顺序错了会看成气泡在皿底。
	for pass_index: int in range(3):
		for slot: int in range(items.size()):
			var entry: String = items[slot]
			var key: String = entry.get_slice(":", 0)
			var texture: String = entry.get_slice(":", 1)
			var layer: int = 1
			if texture == "liquid":
				layer = 0
			elif texture == "gas" or texture == "glow":
				layer = 2
			if layer != pass_index:
				continue
			var tint: Color = SUBSTANCE.get(key, Color.WHITE)
			_draw_texture_kind(bowl, texture, tint, alpha, slot)


func _draw_texture_kind(
	bowl: Rect2, kind: String, tint: Color, alpha: float, slot: int
) -> void:
	var shade := Color(tint.r, tint.g, tint.b, alpha)
	var base: float = bowl.position.y + bowl.size.y
	var mid_x: float = bowl.position.x + bowl.size.x * 0.5
	var wobble: float = float(slot) * 0.7

	match kind:
		"liquid":
			var depth: float = bowl.size.y * 0.34
			draw_rect(
				Rect2(bowl.position.x + 3.0, base - depth - 3.0,
					bowl.size.x - 6.0, depth),
				Color(shade.r, shade.g, shade.b, alpha * 0.62)
			)
			var top: float = base - depth - 3.0
			var line := PackedVector2Array()
			for step: int in range(9):
				var t: float = float(step) / 8.0
				line.append(Vector2(
					bowl.position.x + 3.0 + (bowl.size.x - 6.0) * t,
					top + sin(_time * 2.0 + t * 5.0 + wobble) * 1.2
				))
			draw_polyline(line, Color(shade.r, shade.g, shade.b, alpha * 0.9), 1.5)
		"solid":
			var block := Rect2(
				mid_x - bowl.size.x * 0.20 + float(slot) * 9.0,
				base - bowl.size.y * 0.62,
				bowl.size.x * 0.40, bowl.size.y * 0.56
			)
			draw_rect(block, shade)
			draw_rect(block, Color(shade.r * 0.6, shade.g * 0.6, shade.b * 0.6, alpha), false, 1.5)
		"grains":
			for grain: int in range(14):
				var j: float = _jitter[grain % _jitter.size()]
				var k: float = _jitter[(grain * 5 + 3) % _jitter.size()]
				draw_circle(
					Vector2(
						bowl.position.x + 8.0 + j * (bowl.size.x - 16.0),
						base - 6.0 - k * bowl.size.y * 0.30
					),
					1.6 + k * 1.4, shade
				)
		"dissolved":
			# 溶解掉的物质仍然在皿里，必须画得出来。看不见它，"盐本来就在
			# 水里"这条解释就和画面对不上，玩家会以为析出的盐是新物质。
			for speck: int in range(18):
				var j: float = _jitter[(speck * 3 + slot) % _jitter.size()]
				var k: float = _jitter[(speck * 7 + 1) % _jitter.size()]
				draw_circle(
					Vector2(
						bowl.position.x + 8.0 + j * (bowl.size.x - 16.0),
						base - 8.0 - k * bowl.size.y * 0.28
					),
					1.0, Color(shade.r, shade.g, shade.b, alpha * 0.75)
				)
		"cling":
			# 铁钉被吸到磁棒下缘：位置变了，物质没变。
			for nail: int in range(4):
				var j: float = _jitter[(nail * 5 + slot) % _jitter.size()]
				var x: float = bowl.position.x + bowl.size.x * (0.36 + j * 0.26)
				var y: float = bowl.position.y + bowl.size.y * 0.26
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(x, y), Vector2(x + 4.0, y + bowl.size.y * 0.22),
						Vector2(x - 3.0, y + bowl.size.y * 0.22),
					]),
					shade
				)
		"pieces":
			for shard: int in range(4):
				var j: float = _jitter[(shard * 7 + slot) % _jitter.size()]
				var x: float = bowl.position.x + 10.0 + j * (bowl.size.x - 24.0)
				var y: float = base - 6.0 - j * bowl.size.y * 0.20
				var s: float = bowl.size.y * (0.18 + j * 0.12)
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(x, y - s), Vector2(x + s * 0.7, y),
						Vector2(x - s * 0.5, y),
					]),
					shade
				)
		"fibre":
			for strand: int in range(5):
				var line := PackedVector2Array()
				var y0: float = base - 8.0 - float(strand) * bowl.size.y * 0.10
				for step: int in range(9):
					var t: float = float(step) / 8.0
					line.append(Vector2(
						bowl.position.x + 8.0 + (bowl.size.x - 16.0) * t,
						y0 + sin(t * 6.0 + float(strand)) * 2.0
					))
				draw_polyline(line, shade, 1.5)
		"coil":
			var turns: int = 7
			var line2 := PackedVector2Array()
			var stretch: float = 1.0 + 0.35 * sin(_time * 1.8)
			for step: int in range(turns * 4 + 1):
				var t: float = float(step) / float(turns * 4)
				line2.append(Vector2(
					bowl.position.x + 10.0 + (bowl.size.x - 20.0) * t * clampf(stretch, 0.6, 1.0),
					base - bowl.size.y * 0.36
					+ sin(t * TAU * float(turns)) * bowl.size.y * 0.16
				))
			draw_polyline(line2, shade, 2.0)
		"bar":
			draw_rect(
				Rect2(bowl.position.x + bowl.size.x * 0.34, bowl.position.y + 5.0,
					bowl.size.x * 0.32, bowl.size.y * 0.20),
				shade
			)
		"gas":
			for mote: int in range(7):
				var j: float = _jitter[(mote * 3 + slot) % _jitter.size()]
				var life: float = fmod(_time * 0.55 + j, 1.0)
				var x: float = (
					bowl.position.x + 10.0 + j * (bowl.size.x - 20.0)
					+ sin(_time * 1.6 + j * 6.0) * 3.0
				)
				var y: float = base - 8.0 - (bowl.size.y - 14.0) * life
				draw_circle(
					Vector2(x, y), 1.6 + j * 1.6,
					Color(shade.r, shade.g, shade.b, alpha * sin(life * PI) * 0.85)
				)
		"glow":
			for step: int in range(6):
				var k: float = float(step) / 5.0
				draw_circle(
					Vector2(mid_x, base - bowl.size.y * 0.40),
					bowl.size.y * (0.14 + k * 0.30),
					Color(shade.r, shade.g, shade.b, alpha * pow(1.0 - k, 2.0) * 0.22)
				)


## 变化之后才出现的物质，各给一枚亮起来的色标。空排 = 没有新物质 = 物理变化。
## 这排色标就是判据本身，所以它只在封盘之后出现——提前给出来等于报答案。
func _draw_new_marks(bowl: Rect2) -> void:
	var fresh: PackedStringArray = new_substances()
	if fresh.is_empty():
		return
	var pulse: float = 0.65 + 0.35 * sin(_time * 4.0)
	var chip: float = 7.0
	var x: float = bowl.position.x + 6.0
	var y: float = bowl.position.y + 6.0
	for key: String in fresh:
		var tint: Color = SUBSTANCE.get(key, Color.WHITE)
		draw_circle(Vector2(x + chip, y + chip), chip + 2.5,
			Color(NEW_MARK.r, NEW_MARK.g, NEW_MARK.b, pulse))
		draw_circle(Vector2(x + chip, y + chip), chip, tint)
		x += chip * 2.0 + 6.0
