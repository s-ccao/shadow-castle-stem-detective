class_name ChangeSortingMinigame
extends MinigameShell

## 化学室：变化分拣。
##
## 教的正是化学室知识展品那句话——判断化学变化的唯一标准是**有没有生成
## 新物质**，而不是"看起来变化大不大"。所以题目里故意混进"铁生锈"（看着
## 只是变色，其实是化学变化）和"蜡烛熔化"（看着剧烈，其实只是物理变化）
## 这类反直觉的样本。
##
## 玩法：把每份样本拨到「化学」或「物理」，全部拨对才算过关。答错时只标出
## 错的那几张并给出原因，不清空进度——错误本身是教学的一部分。

## chemical = true 表示生成了新物质。
const SAMPLES: Dictionary = {
	"burning_paper": {
		"en": "Paper burning to ash", "zh": "纸张烧成灰烬", "chemical": true,
		"why_en": "Ash is a new substance; the paper is gone.",
		"why_zh": "灰烬是新物质，纸已经不存在了。",
	},
	"melting_ice": {
		"en": "Ice melting into water", "zh": "冰块融化成水", "chemical": false,
		"why_en": "Still water, only a different state.",
		"why_zh": "还是水，只是状态变了。",
	},
	"breaking_glass": {
		"en": "Glass shattering", "zh": "玻璃摔碎", "chemical": false,
		"why_en": "Smaller pieces, same glass.",
		"why_zh": "碎成小块，仍然是玻璃。",
	},
	"dissolving_sugar": {
		"en": "Sugar dissolving in water", "zh": "白糖溶解在水里", "chemical": false,
		"why_en": "The sugar is still sugar; boil the water off and it returns.",
		"why_zh": "糖还是糖，把水蒸干它就回来了。",
	},
	"rusting_iron": {
		"en": "Iron rusting", "zh": "铁生锈", "chemical": true,
		"why_en": "Rust is a new substance, not iron with a coat of paint.",
		"why_zh": "锈是新物质，不是铁表面刷了层颜色。",
	},
	"melting_wax": {
		"en": "Candle wax melting", "zh": "蜡烛的蜡熔化", "chemical": false,
		"why_en": "Melted wax is still wax. Only the burning wick is chemical.",
		"why_zh": "熔化的蜡还是蜡。真正的化学变化是烛芯在燃烧。",
	},
	"baking_soda_vinegar": {
		"en": "Baking soda fizzing in vinegar", "zh": "小苏打遇到醋冒泡", "chemical": true,
		"why_en": "The bubbles are a new gas that was not there before.",
		"why_zh": "冒出的气泡是原来没有的新气体。",
	},
	"boiling_water": {
		"en": "Water boiling into steam", "zh": "水沸腾变成水蒸气", "chemical": false,
		"why_en": "Steam is still water.",
		"why_zh": "水蒸气还是水。",
	},
	"cooking_egg": {
		"en": "An egg white turning solid in the pan", "zh": "蛋清在锅里变白凝固", "chemical": true,
		"why_en": "It never turns runny again; a new substance formed.",
		"why_zh": "它再也变不回流动的样子了——生成了新物质。",
	},
	"tearing_cloth": {
		"en": "Cloth torn in half", "zh": "布被撕成两半", "chemical": false,
		"why_en": "Two pieces, same cloth.",
		"why_zh": "两片，还是同一种布。",
	},
	"silver_tarnish": {
		"en": "Silver darkening in air", "zh": "银器在空气中发黑", "chemical": true,
		"why_en": "The dark layer is a new compound with the air.",
		"why_zh": "那层黑是银和空气生成的新化合物。",
	},
	"magnet_attracting": {
		"en": "A magnet picking up nails", "zh": "磁铁吸起铁钉", "chemical": false,
		"why_en": "The nails are unchanged once you pull them off.",
		"why_zh": "把钉子拿下来，它一点没变。",
	},
	"milk_souring": {
		"en": "Milk turning sour", "zh": "牛奶发酸变质", "chemical": true,
		"why_en": "New acids were produced; it cannot be undone.",
		"why_zh": "产生了新的酸性物质，而且回不去了。",
	},
	"salt_crystallising": {
		"en": "Salt crystals forming as seawater dries", "zh": "海水晒干析出盐粒",
		"chemical": false,
		"why_en": "The salt was dissolved in there all along.",
		"why_zh": "盐本来就溶在水里，只是重新析出来。",
	},
	"bronze_reaction": {
		"en": "The warm bronze core reacting inside", "zh": "青铜核心内部正在反应",
		"chemical": true,
		"why_en": "The heat comes from a reaction making new substances.",
		"why_zh": "热量来自一场生成新物质的反应。",
	},
	"stretching_spring": {
		"en": "A spring stretched and released", "zh": "弹簧被拉长后弹回", "chemical": false,
		"why_en": "Shape changed, substance did not.",
		"why_zh": "形状变了，物质没变。",
	},
}

const LEVELS: Array[Array] = [
	["burning_paper", "melting_ice"],
	["breaking_glass", "baking_soda_vinegar", "dissolving_sugar"],
	["rusting_iron", "boiling_water", "cooking_egg"],
	["melting_wax", "silver_tarnish", "tearing_cloth", "burning_paper"],
	["magnet_attracting", "milk_souring", "salt_crystallising", "rusting_iron"],
	["bronze_reaction", "stretching_spring", "melting_wax", "baking_soda_vinegar"],
	[
		"salt_crystallising", "silver_tarnish", "dissolving_sugar",
		"cooking_egg", "breaking_glass",
	],
	[
		"melting_wax", "rusting_iron", "magnet_attracting",
		"milk_souring", "boiling_water", "bronze_reaction",
	],
]

var _choice: Dictionary = {}
var _cards: Dictionary = {}
var _submit: Button


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_choice = {}
	_cards = {}
	set_instruction(_text(
		"A change is chemical only when a NEW substance appears. "
		+ "Sort every sample, then seal the tray.",
		"只有生成了「新物质」才算化学变化。把每份样本分好类，再封盘。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	content.add_child(column)

	for sample_id: String in LEVELS[index]:
		column.add_child(_build_card(sample_id))
		_choice[sample_id] = ""

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_submit = make_button(_text("Seal the tray", "封盘"))
	_submit.custom_minimum_size = Vector2(170.0, 34.0)
	_submit.pressed.connect(_on_submit)
	row.add_child(_submit)
	_refresh()


func _build_card(sample_id: String) -> Control:
	var sample: Dictionary = SAMPLES[sample_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := _make_label(
		_text(str(sample["en"]), str(sample["zh"])), 14, PARCHMENT
	)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var chemical := make_button(_text("Chemical", "化学"))
	chemical.custom_minimum_size = Vector2(104.0, 30.0)
	chemical.pressed.connect(_on_pick.bind(sample_id, "chemical"))
	row.add_child(chemical)

	var physical := make_button(_text("Physical", "物理"))
	physical.custom_minimum_size = Vector2(104.0, 30.0)
	physical.pressed.connect(_on_pick.bind(sample_id, "physical"))
	row.add_child(physical)

	_cards[sample_id] = {"label": label, "chemical": chemical, "physical": physical}
	return row


func _on_pick(sample_id: String, choice: String) -> void:
	_choice[sample_id] = choice
	_refresh()


func _refresh() -> void:
	for sample_id: String in _cards:
		var card: Dictionary = _cards[sample_id]
		var picked: String = str(_choice.get(sample_id, ""))
		# 选中的那一侧上金色，另一侧回到常态——不用额外文字就能读出当前选择。
		card["chemical"].modulate = (
			Color(1.0, 0.86, 0.45) if picked == "chemical" else Color.WHITE
		)
		card["physical"].modulate = (
			Color(1.0, 0.86, 0.45) if picked == "physical" else Color.WHITE
		)
	var all_answered: bool = true
	for sample_id: String in _choice:
		if str(_choice[sample_id]).is_empty():
			all_answered = false
			break
	if _submit != null:
		_submit.disabled = not all_answered


func _on_submit() -> void:
	var wrong: Array[String] = []
	for sample_id: String in _choice:
		var expected: String = (
			"chemical" if bool(SAMPLES[sample_id]["chemical"]) else "physical"
		)
		if str(_choice[sample_id]) != expected:
			wrong.append(sample_id)
	if wrong.is_empty():
		report_level_cleared(_text(
			"Every sample filed correctly. The tray seals.",
			"每一份都归对了类。托盘封好了。"
		))
		return
	# 只标错的那几张并解释原因，答对的保留——错误是教学的一部分。
	for sample_id: String in wrong:
		_cards[sample_id]["label"].add_theme_color_override("font_color", FAILURE)
		_choice[sample_id] = ""
	var first: Dictionary = SAMPLES[wrong[0]]
	report_level_failed(_text(
		"%d misfiled. %s — %s" % [
			wrong.size(), str(first["en"]), str(first["why_en"])
		],
		"有 %d 份放错了。%s —— %s" % [
			wrong.size(), str(first["zh"]), str(first["why_zh"])
		]
	))
	_refresh()
