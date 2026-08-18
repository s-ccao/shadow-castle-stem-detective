class_name PhotosynthesisMinigame
extends MinigameShell

## 温室左侧长花坛：光合平衡（蓝铃花采收）。
##
## 教的是「限制因子」——生长速度由光照、水分、二氧化碳里**最短的那一块**
## 决定，而不是三者之和。所以把资源全砸在光照上毫无意义，只要水是 0，
## 苗就是不长。这正是大厅温室知识展品那段话的可操作版本。
##
## 玩法：每关给一笔补给点数，玩家分配到三条供给槽；生长值 = 三者最小值。
## 达到目标生长值即过关。后面的关卡加入「雨水已经给了 2 点」「二氧化碳
## 每点要花 2」「灯具上限 5」这些约束，逼玩家真正去算短板在哪。

const CHANNELS: Array[String] = ["light", "water", "carbon"]

const CHANNEL_TINT: Dictionary = {
	"light": Color(1.00, 0.86, 0.42, 1.0),
	"water": Color(0.42, 0.76, 1.00, 1.0),
	"carbon": Color(0.62, 0.94, 0.58, 1.0),
}

## 每关：budget 补给点数，target 目标生长值，free 已有的白送量，
## cost 每点花费，cap 该槽上限。全部关卡的可解性有测试脚本验证。
const LEVELS: Array[Dictionary] = [
	{
		"budget": 6, "target": 2,
		"free": {"light": 0, "water": 0, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 1},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 9, "target": 3,
		"free": {"light": 0, "water": 0, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 1},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 7, "target": 3,
		"free": {"light": 0, "water": 2, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 1},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 8, "target": 2,
		"free": {"light": 0, "water": 0, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 2},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 12, "target": 4,
		"free": {"light": 1, "water": 0, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 1},
		"cap": {"light": 5, "water": 8, "carbon": 8},
	},
	{
		"budget": 10, "target": 3,
		"free": {"light": 0, "water": 2, "carbon": 1},
		"cost": {"light": 1, "water": 1, "carbon": 2},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 17, "target": 5,
		"free": {"light": 2, "water": 1, "carbon": 0},
		"cost": {"light": 1, "water": 1, "carbon": 2},
		"cap": {"light": 6, "water": 6, "carbon": 6},
	},
	{
		"budget": 19, "target": 4,
		"free": {"light": 0, "water": 1, "carbon": 0},
		"cost": {"light": 2, "water": 1, "carbon": 2},
		"cap": {"light": 5, "water": 5, "carbon": 5},
	},
]

var _bought: Dictionary = {}
var _level: Dictionary = {}
var _bars: Dictionary = {}
var _value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _budget_label: Label
var _growth_label: Label
var _limiting_label: Label
var _cultivate_button: Button


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_level = LEVELS[index]
	_bought = {}
	for channel: String in CHANNELS:
		_bought[channel] = 0
	_bars = {}
	_value_labels = {}
	_plus_buttons = {}

	set_instruction(_text(
		"Growth is limited by whichever supply is lowest, not by the total. "
		+ "Spend the ration to reach the target growth.",
		"生长速度由三种供给里最低的那一项决定，不是看总量。"
		+ "把补给分配下去，让生长值达到目标。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	content.add_child(column)

	var readout := HBoxContainer.new()
	readout.add_theme_constant_override("separation", 24)
	column.add_child(readout)

	_budget_label = _make_label("", 15, GOLD)
	_budget_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.add_child(_budget_label)

	_growth_label = _make_label("", 15, PARCHMENT)
	_growth_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_growth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_child(_growth_label)

	_limiting_label = _make_label("", 15, FAILURE)
	_limiting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_limiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_child(_limiting_label)

	var lanes := HBoxContainer.new()
	lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_theme_constant_override("separation", 40)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(lanes)

	for channel: String in CHANNELS:
		lanes.add_child(_build_lane(channel))

	_cultivate_button = make_button(_text("Cultivate", "培育"))
	_cultivate_button.custom_minimum_size = Vector2(150.0, 36.0)
	_cultivate_button.pressed.connect(_on_cultivate)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_cultivate_button)
	column.add_child(row)

	_refresh()


func _build_lane(channel: String) -> Control:
	var lane := VBoxContainer.new()
	lane.add_theme_constant_override("separation", 6)
	lane.custom_minimum_size = Vector2(150.0, 0.0)

	var title := _make_label(_channel_name(channel), 15, CHANNEL_TINT[channel])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane.add_child(title)

	var bar := MinigameSupplyBar.new()
	bar.tint = CHANNEL_TINT[channel]
	bar.cap = int(_level["cap"][channel])
	bar.scale_max = _scale_max()
	bar.target = int(_level["target"])
	bar.custom_minimum_size = Vector2(140.0, 168.0)
	lane.add_child(bar)
	_bars[channel] = bar

	var value := _make_label("", 14, PARCHMENT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane.add_child(value)
	_value_labels[channel] = value

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	var minus := make_button("−")
	minus.custom_minimum_size = Vector2(52.0, 30.0)
	minus.pressed.connect(_on_adjust.bind(channel, -1))
	buttons.add_child(minus)
	var plus := make_button("+")
	plus.custom_minimum_size = Vector2(52.0, 30.0)
	plus.pressed.connect(_on_adjust.bind(channel, 1))
	buttons.add_child(plus)
	_plus_buttons[channel] = plus
	lane.add_child(buttons)

	var cost: int = int(_level["cost"][channel])
	var note := _make_label(
		_text("%d per unit" % cost, "每点 %d 补给" % cost),
		11,
		Color(0.78, 0.72, 0.56, 1.0)
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane.add_child(note)

	return lane


## 三根槽共用的绘制标尺，取本关三个 cap 里的最大值，这样条高可以直接比。
func _scale_max() -> int:
	var highest: int = 1
	for channel: String in CHANNELS:
		highest = maxi(highest, int(_level["cap"][channel]))
	return highest


func _channel_name(channel: String) -> String:
	match channel:
		"light":
			return _text("LIGHT", "光照")
		"water":
			return _text("WATER", "水分")
		_:
			return _text("CO2", "二氧化碳")


func _supply(channel: String) -> int:
	return int(_level["free"][channel]) + int(_bought[channel])


func _spent() -> int:
	var total: int = 0
	for channel: String in CHANNELS:
		total += int(_bought[channel]) * int(_level["cost"][channel])
	return total


func _growth() -> int:
	var lowest: int = 9999
	for channel: String in CHANNELS:
		lowest = mini(lowest, _supply(channel))
	return lowest


func _limiting_channel() -> String:
	var lowest: int = 9999
	var found: String = CHANNELS[0]
	for channel: String in CHANNELS:
		if _supply(channel) < lowest:
			lowest = _supply(channel)
			found = channel
	return found


func _on_adjust(channel: String, delta: int) -> void:
	var next: int = int(_bought[channel]) + delta
	if next < 0:
		return
	if int(_level["free"][channel]) + next > int(_level["cap"][channel]):
		return
	var previous: int = int(_bought[channel])
	_bought[channel] = next
	if _spent() > int(_level["budget"]):
		_bought[channel] = previous
		return
	_refresh()


func _refresh() -> void:
	var remaining: int = int(_level["budget"]) - _spent()
	_budget_label.text = _text(
		"Ration left: %d" % remaining, "剩余补给：%d" % remaining
	)
	var growth: int = _growth()
	var target: int = int(_level["target"])
	_growth_label.text = _text(
		"Growth %d / %d" % [growth, target], "生长 %d / %d" % [growth, target]
	)
	var limiting: String = _limiting_channel()
	_limiting_label.text = _text(
		"Limited by %s" % _channel_name(limiting),
		"短板：%s" % _channel_name(limiting)
	)
	for channel: String in CHANNELS:
		var supply: int = _supply(channel)
		var bar: MinigameSupplyBar = _bars[channel]
		bar.free_amount = int(_level["free"][channel])
		bar.value = supply
		bar.is_limiting = channel == limiting
		bar.queue_redraw()
		var free_units: int = int(_level["free"][channel])
		var suffix: String = ""
		if free_units > 0:
			suffix = _text(" (%d free)" % free_units, "（含 %d 白送）" % free_units)
		_value_labels[channel].text = "%d%s" % [supply, suffix]
		var cost: int = int(_level["cost"][channel])
		_plus_buttons[channel].disabled = (
			remaining < cost
			or supply >= int(_level["cap"][channel])
		)
	_cultivate_button.disabled = false


func _on_cultivate() -> void:
	var growth: int = _growth()
	var target: int = int(_level["target"])
	if growth >= target:
		report_level_cleared(_text(
			"The seedlings surge upward. Balance reached.",
			"幼苗猛地窜高。三项供给终于配平了。"
		))
		return
	var limiting: String = _limiting_channel()
	report_level_failed(_text(
		"Growth stalls at %d. %s is the limiting factor — raising the others will not help."
			% [growth, _channel_name(limiting)],
		"生长停在 %d。%s 才是限制因子——把别的调高没有用。"
			% [growth, _channel_name(limiting)]
	))
