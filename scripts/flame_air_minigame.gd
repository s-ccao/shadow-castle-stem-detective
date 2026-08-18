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
var _confirm: Button


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

	set_instruction(_text(
		"A flame burns only while air still reaches it. More air lasts "
		+ "longer; sealed goes out first; a vent keeps feeding it. "
		+ "Tap the jars in the order their flames die — first to go out first.",
		"火焰只有在还够得着空气时才烧得下去。空气越多烧得越久，密封的最先灭，"
		+ "而通气孔会一直补进新的空气。按火焰熄灭的先后点选罐子——最先灭的先点。"
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
	var reset := make_button(_text("Start over", "重排"))
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
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
	view.custom_minimum_size = Vector2(112.0, 150.0)
	lane.add_child(view)

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


func _on_pick(jar_index: int) -> void:
	if _order.has(jar_index):
		return
	_order.append(jar_index)
	_refresh()


func _on_reset() -> void:
	_order = []
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
	if _confirm != null:
		_confirm.disabled = _order.size() < _jars.size()


func _on_confirm() -> void:
	var expected: Array[int] = _correct_order()
	if _order == expected:
		report_level_cleared(_text(
			"Every flame went out exactly when you said it would.",
			"每一支火焰，都在你说的那一刻熄灭了。"
		))
		return
	var first_wrong: int = 0
	for place: int in range(_order.size()):
		if _order[place] != expected[place]:
			first_wrong = place
			break
	var should_be: Dictionary = _jars[expected[first_wrong]]
	report_level_failed(_text(
		"Not that order. The jar with air %s and vents %s outlasts the rest "
		+ "of your guess — a vent keeps feeding the flame, so a small vented "
		+ "jar can beat a large sealed one."
			% [_num(float(should_be["air"])), _num(float(should_be["vents"]))],
		"顺序不对。空气 %s、通气 %s 的那只罐子，比你排的撑得久——"
		+ "通气孔会一直补进空气，所以带孔的小罐可以赢过密封的大罐。"
			% [_num(float(should_be["air"])), _num(float(should_be["vents"]))]
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
