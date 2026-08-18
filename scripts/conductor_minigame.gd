class_name ConductorMinigame
extends MinigameShell

## 线路房：接通电路。
##
## 教的是线路房知识展品那句话——导体让电荷通过，断开的电路不通电。但只教
## "金属导电"太单薄，所以材料表里放进了石墨（铅笔芯，导电）和盐水（导电）
## 这类反直觉的导体，以及陶瓷、干木头这些看着结实其实绝缘的材料。
##
## 玩法：一条断了若干处的线路，每个缺口挑一种材料填上，全部填成导体才通电。
## 后面的关卡库存里导体不够、必须精确挑，最后一关只剩石墨可用。

## conductive = true 才导电。
const MATERIALS: Dictionary = {
	"copper": {"en": "Copper strip", "zh": "铜片", "conductive": true},
	"iron_nail": {"en": "Iron nail", "zh": "铁钉", "conductive": true},
	"graphite": {"en": "Pencil lead (graphite)", "zh": "铅笔芯（石墨）", "conductive": true},
	"salt_water": {"en": "Salt water cell", "zh": "盐水槽", "conductive": true},
	"aluminium": {"en": "Aluminium foil", "zh": "铝箔", "conductive": true},
	"rubber": {"en": "Rubber grommet", "zh": "橡胶垫圈", "conductive": false},
	"dry_wood": {"en": "Dry wood peg", "zh": "干木栓", "conductive": false},
	"glass": {"en": "Glass rod", "zh": "玻璃棒", "conductive": false},
	"ceramic": {"en": "Ceramic bead", "zh": "陶瓷珠", "conductive": false},
	"plastic": {"en": "Plastic clip", "zh": "塑料夹", "conductive": false},
	"pure_water": {"en": "Distilled water vial", "zh": "蒸馏水瓶", "conductive": false},
}

## gaps 缺口数，bag 本关可用材料。bag 里导体数量必须 >= gaps，
## 这一点由测试脚本逐关验证。
const LEVELS: Array[Dictionary] = [
	{"gaps": 1, "bag": ["copper", "rubber"]},
	{"gaps": 2, "bag": ["copper", "iron_nail", "glass", "dry_wood"]},
	{"gaps": 2, "bag": ["graphite", "rubber", "aluminium", "plastic"]},
	{"gaps": 3, "bag": ["copper", "graphite", "iron_nail", "ceramic", "glass"]},
	{
		"gaps": 3,
		"bag": ["salt_water", "pure_water", "aluminium", "copper", "dry_wood"],
	},
	{
		"gaps": 4,
		"bag": [
			"graphite", "salt_water", "copper", "iron_nail",
			"ceramic", "plastic", "pure_water",
		],
	},
	{
		"gaps": 4,
		"bag": [
			"aluminium", "graphite", "salt_water", "iron_nail",
			"glass", "rubber", "dry_wood", "pure_water",
		],
	},
	{
		"gaps": 5,
		"bag": [
			"graphite", "graphite", "graphite", "graphite", "graphite",
			"ceramic", "plastic", "glass", "pure_water",
		],
	},
]

var _level: Dictionary = {}
var _gap_fill: Array[String] = []
var _gap_buttons: Array[Button] = []
var _selected_gap: int = 0
var _rail: MinigameCircuitRail


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_level = LEVELS[index]
	var gaps: int = int(_level["gaps"])
	_gap_fill = []
	_gap_buttons = []
	_selected_gap = 0
	for gap: int in range(gaps):
		_gap_fill.append("")

	set_instruction(_text(
		"Current only flows through a CLOSED path of conductors. "
		+ "Pick a gap, then choose what to bridge it with.",
		"电流只能沿着**完全闭合**的导体通路流动。先选一个缺口，再挑材料把它接上。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	_rail = MinigameCircuitRail.new()
	_rail.gap_count = gaps
	_rail.custom_minimum_size = Vector2(0.0, 84.0)
	column.add_child(_rail)

	var gap_row := HBoxContainer.new()
	gap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gap_row.add_theme_constant_override("separation", 10)
	column.add_child(gap_row)
	for gap: int in range(gaps):
		var button := make_button("")
		button.custom_minimum_size = Vector2(128.0, 32.0)
		button.pressed.connect(_on_select_gap.bind(gap))
		gap_row.add_child(button)
		_gap_buttons.append(button)

	var bag_label := _make_label(_text("SUPPLY BIN", "材料箱"), 14, GOLD)
	bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(bag_label)

	var bag := GridContainer.new()
	bag.columns = 3
	bag.add_theme_constant_override("h_separation", 8)
	bag.add_theme_constant_override("v_separation", 6)
	column.add_child(bag)
	var seen: Dictionary = {}
	for material_id: String in _level["bag"]:
		# 同种材料在箱子里出现多次时只显示一枚按钮，避免一排一样的东西。
		if seen.has(material_id):
			continue
		seen[material_id] = true
		var info: Dictionary = MATERIALS[material_id]
		var button := make_button(_text(str(info["en"]), str(info["zh"])))
		button.custom_minimum_size = Vector2(178.0, 32.0)
		button.pressed.connect(_on_pick_material.bind(material_id))
		bag.add_child(button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var test := make_button(_text("Close the switch", "合闸"))
	test.custom_minimum_size = Vector2(170.0, 34.0)
	test.pressed.connect(_on_test)
	row.add_child(test)
	column.add_child(row)

	_refresh()


func _on_select_gap(gap: int) -> void:
	_selected_gap = gap
	_refresh()


func _on_pick_material(material_id: String) -> void:
	if _selected_gap < 0 or _selected_gap >= _gap_fill.size():
		return
	_gap_fill[_selected_gap] = material_id
	# 填完自动跳到下一个还空着的缺口，省掉来回点选。
	for offset: int in range(_gap_fill.size()):
		var candidate: int = (_selected_gap + 1 + offset) % _gap_fill.size()
		if _gap_fill[candidate].is_empty():
			_selected_gap = candidate
			break
	_refresh()


func _refresh() -> void:
	var bridged: Array[bool] = []
	for gap: int in range(_gap_fill.size()):
		var material_id: String = _gap_fill[gap]
		var button: Button = _gap_buttons[gap]
		if material_id.is_empty():
			button.text = _text("Gap %d — empty" % (gap + 1), "缺口 %d — 空" % (gap + 1))
		else:
			var info: Dictionary = MATERIALS[material_id]
			button.text = _text(str(info["en"]), str(info["zh"]))
		button.modulate = (
			Color(1.0, 0.86, 0.45) if gap == _selected_gap else Color.WHITE
		)
		bridged.append(
			not material_id.is_empty()
			and bool(MATERIALS[material_id]["conductive"])
		)
	if _rail != null:
		_rail.bridged = bridged
		_rail.energised = not bridged.has(false)
		_rail.queue_redraw()


func _on_test() -> void:
	var empty: int = 0
	var blocked: String = ""
	for material_id: String in _gap_fill:
		if material_id.is_empty():
			empty += 1
		elif not bool(MATERIALS[material_id]["conductive"]):
			blocked = material_id
	if empty > 0:
		report_level_failed(_text(
			"%d gap(s) still open. An open circuit carries no current at all."
				% empty,
			"还有 %d 个缺口没接上。断开的电路一点电流也过不去。" % empty
		))
		return
	if not blocked.is_empty():
		var info: Dictionary = MATERIALS[blocked]
		report_level_failed(_text(
			"%s is an insulator — it stops the current dead."
				% str(info["en"]),
			"%s 是绝缘体——电流到这里就断了。" % str(info["zh"])
		))
		return
	report_level_cleared(_text(
		"The path closes and the lamps come up.",
		"通路闭合，灯全亮了。"
	))
