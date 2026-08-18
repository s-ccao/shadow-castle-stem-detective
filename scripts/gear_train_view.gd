class_name GearTrainView
extends Control

## 知识引擎的传动链。
##
## 齿轮是真的啮合、真的在转：半径严格正比于齿数（于是全链模数相同，齿一样
## 大），相邻两轮圆心距等于两半径之和，齿的相位由递推式算出来，保证一个轮
## 的齿永远落进另一个轮的齿槽里。转速按 ω_j = (-1)^j · N₀/N_j 给，所以
## "小齿轮带大齿轮会变慢"和"每啮合一次反向一次"都不是画上去的标注，而是
## 眼睛能直接看出来的运动。
##
## 这一点是这个小游戏的全部意义：它要教的"中间加一个齿轮不改变最终速比"，
## 只有在末级齿轮**真的转起来**、玩家能把它和输入轮的圈数对着数的时候，才
## 会从一句话变成一件亲眼见过的事。

const BRASS := Color(0.85, 0.68, 0.34, 1.0)
const BRASS_DEEP := Color(0.52, 0.40, 0.20, 1.0)
const BRASS_LIP := Color(1.00, 0.86, 0.52, 1.0)
const HUB := Color(0.16, 0.13, 0.08, 1.0)
const EMPTY := Color(0.62, 0.34, 0.29, 0.95)
const PLATE := Color(0.06, 0.05, 0.04, 0.75)
const INPUT_MARK := Color(0.60, 0.85, 1.00, 1.0)
const OUTPUT_MARK := Color(1.00, 0.62, 0.30, 1.0)
const BELT := Color(0.42, 0.36, 0.26, 1.0)

## 座位留空（皮带直接传过去）时存进 stages 的值，与 GearTrainMinigame 一致。
const BYPASS: int = -1
## 还没选齿轮的座位按这个齿数占位，免得每选一次整条链的排布都跳一下。
const PLACEHOLDER_TEETH: int = 24
## 齿高按标准齿轮取模数的 2.25 倍，模数 = 2 × 半径/齿数，全链相同。
const ADDENDUM: float = 2.0
const DEDENDUM: float = 2.5

var input_teeth: int = 12
var stages: Array = []
## 主动轮累计转过的弧度，由小游戏在运转时逐帧写入。
var drive: float = 0.0
## 运转中会给整条链加一层暖光，停机时是冷的黄铜色。
var running: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 参与啮合的一串齿轮：主动轮 + 所有装了齿轮的座位。留空的座位不在链上，
## 因为它两侧的齿轮是直接咬在一起的——这正是速比不变的原因。
func chain_teeth() -> Array[int]:
	var chain: Array[int] = [maxi(input_teeth, 1)]
	for entry: Variant in stages:
		var teeth: int = int(entry)
		if teeth == BYPASS:
			continue
		chain.append(PLACEHOLDER_TEETH if teeth <= 0 else teeth)
	return chain


## 每个座位是否已经装上真齿轮。没装满时不该让链条转起来。
func is_complete() -> bool:
	for entry: Variant in stages:
		if int(entry) == 0:
			return false
	return true


## 齿相位递推：要让第 j 轮的齿落进第 j+1 轮的齿槽，两轮在接触射线上的齿
## 相位之和必须恒为半个齿距。解出来就是下面这一行。
func _phases(chain: Array[int]) -> PackedFloat32Array:
	var phases := PackedFloat32Array([0.0])
	for index: int in range(chain.size() - 1):
		phases.append(
			PI + PI / float(chain[index + 1])
			- phases[index] * float(chain[index]) / float(chain[index + 1])
		)
	return phases


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLATE)
	if size.x <= 8.0 or size.y <= 8.0:
		return

	var chain: Array[int] = chain_teeth()
	var total: int = 0
	var largest: int = 1
	for teeth: int in chain:
		total += teeth
		largest = maxi(largest, teeth)

	# 留空标记单独占底部一条带，否则它会和最大那个齿轮的齿数标签叠在一起。
	var has_bypass: bool = stages.has(BYPASS)
	var strip: float = 22.0 if has_bypass else 0.0
	var field: float = size.y - strip
	# 齿轮上方要留 2px 余量，下方要留一行齿数标签。把圆心放在这两个约束
	# 正好相等的位置，能画出来的齿轮才是最大的——居中放会白白浪费两成高度。
	var mid: float = (field - 13.0) * 0.5

	# 半径必须严格正比于齿数，否则齿距不同就咬不上。所以整条链能画多大是
	# 由最宽和最高两个约束里更紧的那个决定的。
	var pitch: float = minf(
		(size.x - 26.0) / float(2 * total + 4),
		(field - 17.0) * 0.5 / (float(largest) + 2.0)
	)
	if pitch <= 0.15:
		return

	var phases: PackedFloat32Array = _phases(chain)
	var span: float = 2.0 * pitch * float(total)
	var x: float = (size.x - span) * 0.5

	var centres := PackedVector2Array()
	for index: int in range(chain.size()):
		var radius: float = pitch * float(chain[index])
		centres.append(Vector2(x + radius, mid))
		x += radius * 2.0

	_draw_bypass_marks(centres, chain, pitch, field + strip * 0.5)

	# 需要知道哪些座位还空着，空位画成红色虚线圈而不是黄铜齿轮。
	var solid: Array[bool] = [true]
	for entry: Variant in stages:
		var teeth: int = int(entry)
		if teeth == BYPASS:
			continue
		solid.append(teeth > 0)

	for index: int in range(chain.size()):
		var teeth: int = chain[index]
		var radius: float = pitch * float(teeth)
		var angle: float = phases[index]
		if is_complete():
			# 转速 ω_j = (-1)^j · N₀/N_j：每啮合一级反向一次，齿数越多转得越慢。
			var direction: float = 1.0 if index % 2 == 0 else -1.0
			angle += direction * float(chain[0]) / float(teeth) * drive
		if index < solid.size() and not solid[index]:
			_draw_empty_seat(centres[index], radius)
			continue
		_draw_gear(centres[index], radius, teeth, angle, pitch)
		if index == 0:
			_draw_marker(centres[index], radius, angle, INPUT_MARK)
		elif index == chain.size() - 1:
			_draw_marker(centres[index], radius, angle, OUTPUT_MARK)

	# 输入端的传动轴。只画靠近主动轮的一小段并在末端加一个动力块——拉一条
	# 横贯整个面板的细线，只会把没用到的空白显得更空。
	var hub_x: float = centres[0].x - pitch * float(chain[0])
	var shaft: float = maxf(0.0, minf(38.0, hub_x - 10.0))
	if shaft > 4.0:
		draw_line(Vector2(hub_x - shaft, mid), Vector2(hub_x, mid), BELT, 4.0)
		draw_rect(
			Rect2(hub_x - shaft - 11.0, mid - 9.0, 11.0, 18.0),
			BELT.lerp(BRASS, 0.25)
		)
		draw_rect(
			Rect2(hub_x - shaft - 11.0, mid - 9.0, 11.0, 18.0),
			BRASS, false, 1.5
		)


## 一个齿轮：轮体圆盘 + 逐个画出的梯形轮齿 + 轮毂 + 两根辐条。
## 轮齿分开画成小凸多边形，而不是把整圈拼成一个凹多边形——后者要靠引擎
## 做三角剖分，齿数一多就容易画错。
func _draw_gear(
	centre: Vector2, radius: float, teeth: int, angle: float, pitch: float
) -> void:
	var root: float = maxf(radius - DEDENDUM * pitch, radius * 0.55)
	var tip: float = radius + ADDENDUM * pitch
	var body: Color = BRASS_DEEP if not running else BRASS_DEEP.lerp(BRASS, 0.30)
	var rim: Color = BRASS if not running else BRASS_LIP

	draw_circle(centre, root, Color(body.r, body.g, body.b, 0.95))

	var half_root: float = PI / float(teeth) * 0.78
	var half_tip: float = PI / float(teeth) * 0.44
	for tooth: int in range(teeth):
		var a: float = angle + TAU * float(tooth) / float(teeth)
		draw_colored_polygon(
			PackedVector2Array([
				centre + Vector2(cos(a - half_root), sin(a - half_root)) * root,
				centre + Vector2(cos(a - half_tip), sin(a - half_tip)) * tip,
				centre + Vector2(cos(a + half_tip), sin(a + half_tip)) * tip,
				centre + Vector2(cos(a + half_root), sin(a + half_root)) * root,
			]),
			rim
		)

	draw_arc(centre, root, 0.0, TAU, 48, Color(rim.r, rim.g, rim.b, 0.55), 1.5, true)
	# 辐条：没有它，一个圆盘转起来跟不转看着一样。
	for spoke: int in range(2):
		var a: float = angle + PI * float(spoke)
		draw_line(
			centre + Vector2(cos(a), sin(a)) * (radius * 0.24),
			centre + Vector2(cos(a), sin(a)) * (root * 0.92),
			Color(rim.r, rim.g, rim.b, 0.75),
			maxf(1.5, radius * 0.055)
		)
	draw_circle(centre, maxf(3.0, radius * 0.20), HUB)
	draw_arc(centre, maxf(3.0, radius * 0.20), 0.0, TAU, 20, rim, 1.5, true)

	var label: String = str(teeth)
	var font := ThemeDB.fallback_font
	var font_size: int = 12
	var width: float = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, centre + Vector2(-width * 0.5, tip + 12.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BRASS
	)


## 输入轮和输出轮各带一个亮点。转起来之后可以直接对着数圈数——
## "输入转四圈，输出才转一圈"就是速比 0.25，不用相信任何数字。
## 尺寸有下限：数圈数全靠它，而末级常常是整条链上最小的那个齿轮。
func _draw_marker(
	centre: Vector2, radius: float, angle: float, tint: Color
) -> void:
	var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius * 0.70
	var dot: float = clampf(radius * 0.13, 3.0, 5.5)
	draw_circle(at, dot * 1.7, Color(tint.r, tint.g, tint.b, 0.28))
	draw_circle(at, dot + 1.2, Color(0.10, 0.07, 0.03, 0.85))
	draw_circle(at, dot, tint)


func _draw_empty_seat(centre: Vector2, radius: float) -> void:
	for step: int in range(18):
		var a0: float = TAU * float(step) / 18.0
		draw_arc(centre, radius, a0, a0 + TAU / 36.0, 4, EMPTY, 2.0, true)
	draw_circle(centre, maxf(2.5, radius * 0.12), Color(EMPTY.r, EMPTY.g, EMPTY.b, 0.65))


## 留空的座位画在链条下方的独立条带里：一个打叉的虚线小圈，两侧接皮带。
## 玩家要看得见"我确实把这一位空掉了"，否则齿轮凭空少一个只会让人以为
## 是 bug——而这一位空掉之后速比不变，正是本关要教的事。
##
## 两种排列必须单独处理：连续留空的几位落在同一个啮合缝上，不散开的话会
## 完全重叠成一个；留在最后一位的没有右邻，只能挂到末级齿轮的右边。
func _draw_bypass_marks(
	centres: PackedVector2Array, chain: Array[int], pitch: float, row_y: float
) -> void:
	if centres.is_empty():
		return
	var ring: float = clampf(pitch * 7.0, 6.0, 9.0)
	var meshed: int = 1
	var at_junction: int = 0
	for entry: Variant in stages:
		if int(entry) != BYPASS:
			meshed += 1
			at_junction = 0
			continue
		var left: int = clampi(meshed - 1, 0, centres.size() - 1)
		var base: float
		if meshed < centres.size():
			base = (centres[left].x + centres[meshed].x) * 0.5
		else:
			base = centres[left].x + pitch * float(chain[left]) + ring * 1.8
		_draw_one_bypass(
			Vector2(base + float(at_junction) * ring * 2.8, row_y), ring
		)
		at_junction += 1


func _draw_one_bypass(at: Vector2, ring: float) -> void:
	for step: int in range(12):
		var a0: float = TAU * float(step) / 12.0
		draw_arc(at, ring, a0, a0 + TAU / 24.0, 3, BELT, 1.5, true)
	var cross: float = ring * 0.62
	draw_line(at + Vector2(-cross, -cross), at + Vector2(cross, cross), BELT, 1.5)
	draw_line(at + Vector2(-cross, cross), at + Vector2(cross, -cross), BELT, 1.5)
	draw_line(
		Vector2(at.x - ring * 2.0, at.y), Vector2(at.x - ring, at.y), BELT, 2.0
	)
	draw_line(
		Vector2(at.x + ring, at.y), Vector2(at.x + ring * 2.0, at.y), BELT, 2.0
	)
