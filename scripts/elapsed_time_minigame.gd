class_name ElapsedTimeMinigame
extends MinigameShell

## 餐厅：时间推演。
##
## 教的是餐厅知识展品那句话——用变化速度稳定的量去推算过了多久，而且
## **一处观察远远不够，要比对几个互相独立的线索**。所以每关都故意混进一条
## 坏掉的线索（停摆的钟、被重新点过的蜡烛、挪过位置的日影），玩家必须发现
## 多数线索彼此吻合、把那个离群值丢掉。
##
## 这正是这个房间在剧情里要做的事：从餐桌现场推断案发时刻。

## 每条线索：rate 每小时变化量，amount 观测到的变化量，
## 于是它给出的时间 = amount / rate。reliable=false 的那条是离群值。
const LEVELS: Array[Dictionary] = [
	{
		"answer": 3,
		"clues": [
			{"id": "candle", "rate": 2.0, "amount": 6.0, "reliable": true},
			{"id": "ice", "rate": 4.0, "amount": 12.0, "reliable": true},
			{"id": "clock", "rate": 1.0, "amount": 8.0, "reliable": false},
		],
	},
	{
		"answer": 2,
		"clues": [
			{"id": "tea", "rate": 9.0, "amount": 18.0, "reliable": true},
			{"id": "candle", "rate": 2.5, "amount": 5.0, "reliable": true},
			{"id": "clock", "rate": 1.0, "amount": 7.0, "reliable": false},
		],
	},
	{
		"answer": 4,
		"clues": [
			{"id": "ice", "rate": 3.0, "amount": 12.0, "reliable": true},
			{"id": "ash", "rate": 1.5, "amount": 6.0, "reliable": true},
			{"id": "candle", "rate": 2.0, "amount": 3.0, "reliable": false},
		],
	},
	{
		"answer": 5,
		"clues": [
			{"id": "candle", "rate": 1.4, "amount": 7.0, "reliable": true},
			{"id": "tea", "rate": 6.0, "amount": 30.0, "reliable": true},
			{"id": "ash", "rate": 2.0, "amount": 10.0, "reliable": true},
			{"id": "shadow", "rate": 5.0, "amount": 45.0, "reliable": false},
		],
	},
	{
		"answer": 3,
		"clues": [
			{"id": "ice", "rate": 5.0, "amount": 15.0, "reliable": true},
			{"id": "ash", "rate": 2.5, "amount": 7.5, "reliable": true},
			{"id": "clock", "rate": 1.0, "amount": 11.0, "reliable": false},
			{"id": "tea", "rate": 8.0, "amount": 24.0, "reliable": true},
		],
	},
	{
		"answer": 6,
		"clues": [
			{"id": "candle", "rate": 1.5, "amount": 9.0, "reliable": true},
			{"id": "ash", "rate": 1.0, "amount": 6.0, "reliable": true},
			{"id": "shadow", "rate": 4.0, "amount": 12.0, "reliable": false},
			{"id": "ice", "rate": 2.0, "amount": 12.0, "reliable": true},
		],
	},
	{
		"answer": 2,
		"clues": [
			{"id": "tea", "rate": 11.0, "amount": 22.0, "reliable": true},
			{"id": "ice", "rate": 6.5, "amount": 13.0, "reliable": true},
			{"id": "candle", "rate": 3.0, "amount": 6.0, "reliable": true},
			{"id": "clock", "rate": 1.0, "amount": 9.0, "reliable": false},
			{"id": "ash", "rate": 4.0, "amount": 8.0, "reliable": true},
		],
	},
	{
		"answer": 7,
		"clues": [
			{"id": "candle", "rate": 1.2, "amount": 8.4, "reliable": true},
			{"id": "ash", "rate": 0.5, "amount": 3.5, "reliable": true},
			{"id": "tea", "rate": 5.0, "amount": 35.0, "reliable": true},
			{"id": "shadow", "rate": 3.0, "amount": 6.0, "reliable": false},
			{"id": "ice", "rate": 1.5, "amount": 10.5, "reliable": true},
		],
	},
]

const CLUE_TEXT: Dictionary = {
	"candle": {
		"en": "Dining candle", "zh": "餐桌蜡烛",
		"unit_en": "cm burned", "unit_zh": "厘米已烧",
		"rate_en": "cm per hour", "rate_zh": "厘米/小时",
	},
	"ice": {
		"en": "Ice bucket", "zh": "冰桶",
		"unit_en": "mm melted", "unit_zh": "毫米已融",
		"rate_en": "mm per hour", "rate_zh": "毫米/小时",
	},
	"tea": {
		"en": "Cooling tea", "zh": "冷却的茶",
		"unit_en": "degrees dropped", "unit_zh": "度已降",
		"rate_en": "degrees per hour", "rate_zh": "度/小时",
	},
	"ash": {
		"en": "Fireplace ash", "zh": "壁炉灰烬",
		"unit_en": "mm of ash", "unit_zh": "毫米灰层",
		"rate_en": "mm per hour", "rate_zh": "毫米/小时",
	},
	"clock": {
		"en": "Grandfather clock", "zh": "落地大钟",
		"unit_en": "hours shown", "unit_zh": "小时（表面读数）",
		"rate_en": "hour per hour", "rate_zh": "小时/小时",
	},
	"shadow": {
		"en": "Window shadow", "zh": "窗前日影",
		"unit_en": "cm travelled", "unit_zh": "厘米位移",
		"rate_en": "cm per hour", "rate_zh": "厘米/小时",
	},
}


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	var level: Dictionary = LEVELS[index]
	set_instruction(_text(
		"Each indicator changes at a steady rate, so amount divided by rate "
		+ "gives the hours. One of them is lying — trust the answer the "
		+ "others agree on.",
		"每个指示物都以稳定速度变化，所以「变化量 ÷ 速度」就是小时数。"
		+ "其中有一条在说谎——相信多数线索一致指向的那个答案。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 5)
	content.add_child(column)

	for clue: Dictionary in level["clues"]:
		column.add_child(_build_clue_row(clue))

	var prompt := _make_label(
		_text("How long ago?", "距现在过了多久？"), 15, GOLD
	)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(prompt)

	var options := _answer_options(level)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for hours: int in options:
		var button := make_button(
			_text("%d hours" % hours, "%d 小时" % hours)
		)
		button.custom_minimum_size = Vector2(120.0, 34.0)
		button.pressed.connect(_on_answer.bind(hours, int(level["answer"])))
		row.add_child(button)
	column.add_child(row)


func _build_clue_row(clue: Dictionary) -> Control:
	var info: Dictionary = CLUE_TEXT[str(clue["id"])]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := _make_label(
		_text(str(info["en"]), str(info["zh"])), 14, PARCHMENT
	)
	name_label.custom_minimum_size = Vector2(180.0, 0.0)
	row.add_child(name_label)

	var detail := _make_label(
		_text(
			"%s %s, at %s %s" % [
				_trim(float(clue["amount"])), str(info["unit_en"]),
				_trim(float(clue["rate"])), str(info["rate_en"]),
			],
			"%s %s，速度 %s %s" % [
				_trim(float(clue["amount"])), str(info["unit_zh"]),
				_trim(float(clue["rate"])), str(info["rate_zh"]),
			]
		),
		13,
		Color(0.82, 0.76, 0.60, 1.0)
	)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	return row


func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


## 干扰项必须包含那条坏线索算出来的数值，否则玩家根本没机会掉进陷阱，
## "识别离群值"这个教学点就落空了——只看停摆的钟就会选到那个错答案。
func _answer_options(level: Dictionary) -> Array[int]:
	var answer: int = int(level["answer"])
	var options: Array[int] = [answer]
	for clue: Dictionary in level["clues"]:
		if bool(clue["reliable"]):
			continue
		var rate: float = float(clue["rate"])
		if is_zero_approx(rate):
			continue
		var hours: float = float(clue["amount"]) / rate
		var rounded: int = int(roundf(hours))
		if (
			rounded > 0
			and is_equal_approx(hours, float(rounded))
			and not options.has(rounded)
		):
			options.append(rounded)
	for candidate: int in [answer - 1, answer + 1, answer + 2, answer - 2]:
		if candidate > 0 and not options.has(candidate) and options.size() < 4:
			options.append(candidate)
	options.sort()
	return options


func _on_answer(picked: int, answer: int) -> void:
	if picked == answer:
		report_level_cleared(_text(
			"Three independent measures agree. The hour is fixed.",
			"几条互相独立的线索彼此吻合，时刻定下来了。"
		))
		return
	report_level_failed(_text(
		"That is what a single indicator says. Work out the hours from each "
		+ "one and take the value the majority share.",
		"那只是某一条线索的说法。把每条都算一遍，取多数一致的那个值。"
	))
