class_name FlameAirMinigame
extends MinigameShell

## 苏醒室：烛火与空气。
##
## 教的正是苏醒室那道知识锁问的东西——火焰要持续燃烧，需要空气里的氧气。
## 但只答"需要氧气"太浅，所以这里把它推到可量化的一步：**空气越多，烧得
## 越久；完全密封，最先灭**。通气孔会持续补气，所以一只小罐配通气孔，可以
## 比一只密封的大罐烧得更久——这一点几乎每个孩子都会先猜错。
##
## 玩法：几只罩着蜡烛的玻璃罐，参数各不相同，把它们按"谁先灭"排出顺序。
## 这是全部小游戏里唯一的**预测排序**题：不需要操作，只需要先想明白再落子。
## 苏醒室是开场教学，所以它也是最短、最不惩罚的一个。

## 燃烧时间 = 罐内空气 + 通气孔每刻补气 × 燃烧时长，解得
## ticks = air / max(burn - vents, 0.001)；vents >= burn 表示永不熄灭。
const NEVER: float = 9999.0

## 点火演示的节奏。按下"点火"之后不直接判分，而是真的把火点着、让气层往下
## 掉、让火焰按真实先后一支支灭掉——玩家的预测是被演出来的。判分放在演完
## 之后，所以"我排错了"这件事是眼睛先看见，再由文字确认。
const IGNITE_LEAD: float = 0.40
## 最长的那只罐子从点着到烧尽占多少秒；其余按真实时长等比例缩放。
const BURN_WINDOW: float = 1.90
## 两次熄灭之间至少隔这么久，否则时长接近的罐子会看起来同时灭。
const MIN_GAP: float = 0.30
## 最后一支灭掉之后停留多久再判分。
const SETTLE_HOLD: float = 0.85

## 每关的罐子：air 罐内空气量，vents 通气孔补气速率，burn 蜡烛耗氧速率。
const LEVELS: Array[Array] = [
	[
		{"air": 4.0, "vents": 0.0, "burn": 1.0},
		{"air": 8.0, "vents": 0.0, "burn": 1.0},
	],
	[
		{"air": 6.0, "vents": 0.0, "burn": 1.0},
		{"air": 6.0, "vents": 0.0, "burn": 2.0},
	],
	[
		{"air": 9.0, "vents": 0.0, "burn": 1.0},
		{"air": 4.0, "vents": 0.0, "burn": 1.0},
		{"air": 6.0, "vents": 0.0, "burn": 1.0},
	],
	[
		{"air": 6.0, "vents": 0.5, "burn": 1.0},
		{"air": 6.0, "vents": 0.0, "burn": 1.0},
		{"air": 10.0, "vents": 0.0, "burn": 2.0},
	],
	[
		{"air": 4.0, "vents": 0.75, "burn": 1.0},
		{"air": 12.0, "vents": 0.0, "burn": 1.0},
		{"air": 8.0, "vents": 0.5, "burn": 2.0},
	],
	[
		{"air": 10.0, "vents": 0.0, "burn": 2.0},
		{"air": 3.0, "vents": 0.5, "burn": 1.0},
		{"air": 9.0, "vents": 0.25, "burn": 1.0},
		{"air": 7.0, "vents": 0.0, "burn": 1.0},
	],
	[
		{"air": 5.0, "vents": 1.0, "burn": 1.0},
		{"air": 20.0, "vents": 0.0, "burn": 2.0},
		{"air": 8.0, "vents": 0.5, "burn": 1.0},
		{"air": 4.0, "vents": 0.0, "burn": 1.0},
	],
	[
		{"air": 12.0, "vents": 0.5, "burn": 2.0},
		{"air": 3.0, "vents": 0.25, "burn": 1.0},
		{"air": 30.0, "vents": 0.0, "burn": 3.0},
		{"air": 2.0, "vents": 1.5, "burn": 1.0},
		{"air": 7.0, "vents": 0.0, "burn": 1.0},
	],
]

var _order: Array[int] = []
var _jars: Array = []
var _slots: Array[Button] = []
var _views: Array[FlameJarView] = []
var _confirm: Button
var _reset: Button

## 点火演示的运行状态。
var _running: bool = false
var _run_time: float = 0.0
var _expected: Array[int] = []
var _death_at: Array[float] = []
var _dead: Array[bool] = []
var _deaths_seen: int = 0
var _finish_at: float = 0.0


static func burn_ticks(jar: Dictionary) -> float:
	var drain: float = float(jar["burn"]) - float(jar["vents"])
	if drain <= 0.0:
		return NEVER
	return float(jar["air"]) / drain


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_jars = LEVELS[index]
	_order = []
	_slots = []
	_views = []
	_running = false
	_deaths_seen = 0

	set_instruction(_text(
		"A flame burns only while air still reaches it. More air lasts "
		+ "longer; sealed goes out first; a vent keeps feeding it. "
		+ "Click the jars in the order their flames die — first to go out "
		+ "first — then light them and watch.",
		"火焰只有在还够得着空气时才烧得下去。空气越多烧得越久，密封的最先灭，"
		+ "而通气孔会一直补进新的空气。按火焰熄灭的先后点选罐子——最先灭的先"
		+ "点——然后点火，亲眼看着它们烧。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)

	for jar_index: int in range(_jars.size()):
		row.add_child(_build_jar(jar_index))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_reset = make_button(_text("Start over", "重排"))
	_reset.pressed.connect(_on_reset)
	buttons.add_child(_reset)
	_confirm = make_button(_text("Light them", "点火"))
	_confirm.custom_minimum_size = Vector2(150.0, 34.0)
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)
	column.add_child(buttons)

	_refresh()


func _build_jar(jar_index: int) -> Control:
	var jar: Dictionary = _jars[jar_index]
	var lane := VBoxContainer.new()
	lane.add_theme_constant_override("separation", 4)

	var view := FlameJarView.new()
	view.air = float(jar["air"])
	view.vents = float(jar["vents"])
	view.burn = float(jar["burn"])
	view.eternal = burn_ticks(jar) >= NEVER
	view.custom_minimum_size = Vector2(118.0, 172.0)
	view.picked.connect(_on_jar_clicked.bind(jar_index))
	lane.add_child(view)
	_views.append(view)

	var detail := _make_label(
		_text(
			"air %s\nvents %s\nwick x%s" % [
				_num(float(jar["air"])),
				_num(float(jar["vents"])),
				_num(float(jar["burn"])),
			],
			"空气 %s\n通气 %s\n灯芯 x%s" % [
				_num(float(jar["air"])),
				_num(float(jar["vents"])),
				_num(float(jar["burn"])),
			]
		),
		12,
		Color(0.82, 0.76, 0.60, 1.0)
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane.add_child(detail)

	var pick := make_button("")
	pick.custom_minimum_size = Vector2(112.0, 30.0)
	pick.pressed.connect(_on_pick.bind(jar_index))
	lane.add_child(pick)
	_slots.append(pick)
	return lane


func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


## 直接点罐子。罐子不是 Button，走不到 make_button 接的公共点击音，所以
## 这条路要自己补一声——放在 _on_pick 里会让点下方按钮的那条路响两次。
func _on_jar_clicked(jar_index: int) -> void:
	if _running or _order.has(jar_index):
		return
	GameAudio.play(&"ui_select")
	_on_pick(jar_index)


func _on_pick(jar_index: int) -> void:
	if _running or _order.has(jar_index):
		return
	_order.append(jar_index)
	_refresh()


func _on_reset() -> void:
	if _running:
		return
	_order = []
	for view: FlameJarView in _views:
		if is_instance_valid(view):
			view.reset_flame()
	_refresh()


func _refresh() -> void:
	for jar_index: int in range(_slots.size()):
		var place: int = _order.find(jar_index)
		if place == -1:
			_slots[jar_index].text = _text("pick", "点选")
			_slots[jar_index].modulate = Color.WHITE
		else:
			_slots[jar_index].text = _text(
				"out #%d" % (place + 1), "第 %d 灭" % (place + 1)
			)
			_slots[jar_index].modulate = Color(1.0, 0.86, 0.45)
		if jar_index < _views.size() and is_instance_valid(_views[jar_index]):
			_views[jar_index].mark_picked(place)
	if _confirm != null:
		_confirm.disabled = _order.size() < _jars.size()


## 点火。先算出每只罐子真实的熄灭时刻，再把它们映射到一段看得完的时间里，
## 然后交给 _process 逐帧演。等比例缩放保留了"谁比谁久多少"的直觉，而最小
## 间隔保证时长接近的两只不会看起来同时灭。
func _on_confirm() -> void:
	if _running or _order.size() < _jars.size():
		return
	_expected = _correct_order()
	_death_at = []
	_dead = []
	_deaths_seen = 0

	var longest: float = 1.0
	for jar: Dictionary in _jars:
		var ticks: float = burn_ticks(jar)
		if ticks < NEVER:
			longest = maxf(longest, ticks)
	for jar: Dictionary in _jars:
		var ticks: float = burn_ticks(jar)
		_dead.append(false)
		if ticks >= NEVER:
			_death_at.append(INF)
		else:
			_death_at.append(IGNITE_LEAD + ticks / longest * BURN_WINDOW)

	var previous: float = -INF
	var last: float = IGNITE_LEAD + BURN_WINDOW
	for jar_index: int in _expected:
		if is_inf(_death_at[jar_index]):
			continue
		_death_at[jar_index] = maxf(_death_at[jar_index], previous + MIN_GAP)
		previous = _death_at[jar_index]
		last = _death_at[jar_index]
	_finish_at = last + SETTLE_HOLD

	_running = true
	_run_time = 0.0
	_set_buttons_disabled(content, true)
	GameAudio.play(&"switch_throw")
	for view: FlameJarView in _views:
		if is_instance_valid(view):
			# 上一轮的判定必须清掉，否则重放时永燃罐会留着旧的对错颜色。
			view.verdict = -1
			view.ignite()


func _process(delta: float) -> void:
	if not _running:
		return
	# 演示途中玩家可以直接关掉面板。_finish() 只清空内容并不释放面板本身，
	# 所以这里不拦的话，演示会继续跑到 _settle()，在一个已经结束的小游戏上
	# 再判一次分、再放一次过关特效。
	if not visible or _views.is_empty() or not is_instance_valid(_views[0]):
		_running = false
		return
	_run_time += delta
	for jar_index: int in range(_views.size()):
		var view: FlameJarView = _views[jar_index]
		if not is_instance_valid(view):
			continue
		var death: float = _death_at[jar_index]
		if is_inf(death):
			# 通气量压过耗氧量的罐子永远烧下去，气层不掉。
			view.fuel = 1.0
			continue
		if _run_time >= death:
			if not _dead[jar_index]:
				_dead[jar_index] = true
				view.fuel = 0.0
				view.extinguish()
				_reveal(jar_index)
				GameAudio.play(&"ui_back")
			continue
		var span: float = maxf(0.001, death - IGNITE_LEAD)
		view.fuel = clampf(1.0 - (_run_time - IGNITE_LEAD) / span, 0.0, 1.0)
	if _run_time >= _finish_at:
		_running = false
		_settle()


## 一只罐子熄灭时，当场揭晓玩家对**它**的预测准不准：法阵和序号变绿或变红。
func _reveal(jar_index: int) -> void:
	var view: FlameJarView = _views[jar_index]
	if not is_instance_valid(view):
		return
	view.verdict = 1 if _order.find(jar_index) == _deaths_seen else 0
	_deaths_seen += 1


func _settle() -> void:
	# 永不熄灭的罐子没有"熄灭时刻"，它们的名次在演完之后一并揭晓。
	for jar_index: int in range(_views.size()):
		if not is_instance_valid(_views[jar_index]):
			continue
		if _views[jar_index].verdict == -1:
			_reveal(jar_index)

	if _order == _expected:
		report_level_cleared(_text(
			"Every flame went out exactly when you said it would.",
			"每一支火焰，都在你说的那一刻熄灭了。"
		))
		return

	_set_buttons_disabled(content, false)
	var first_wrong: int = 0
	for place: int in range(_order.size()):
		if _order[place] != _expected[place]:
			first_wrong = place
			break
	var should_be: Dictionary = _jars[_expected[first_wrong]]
	# 拼接必须先用括号收口再取 %：% 绑定得比 + 紧，不加括号的话格式化只作用
	# 在最后一段字面量上，而占位符在第一段里，玩家读到的会是字面的 "%s"。
	var numbers: Array = [
		_num(float(should_be["air"])), _num(float(should_be["vents"]))
	]
	report_level_failed(_text(
		(
			"Not that order. The jar with air %s and vents %s outlasts the "
			+ "rest of your guess — a vent keeps feeding the flame, so a "
			+ "small vented jar can beat a large sealed one."
		) % numbers,
		(
			"顺序不对。空气 %s、通气 %s 的那只罐子，比你排的撑得久——"
			+ "通气孔会一直补进空气，所以带孔的小罐可以赢过密封的大罐。"
		) % numbers
	))


## 按燃烧时长升序；同时长的按原始顺序，保证答案唯一。
func _correct_order() -> Array[int]:
	var indices: Array[int] = []
	for jar_index: int in range(_jars.size()):
		indices.append(jar_index)
	indices.sort_custom(
		func(a: int, b: int) -> bool:
			var ta: float = burn_ticks(_jars[a])
			var tb: float = burn_ticks(_jars[b])
			if is_equal_approx(ta, tb):
				return a < b
			return ta < tb
	)
	return indices
