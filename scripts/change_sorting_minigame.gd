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
		"before": ["paper:solid"],
		"after": ["ash:grains", "smoke:gas"],
	},
	"melting_ice": {
		"en": "Ice melting into water", "zh": "冰块融化成水", "chemical": false,
		"why_en": "Still water, only a different state.",
		"why_zh": "还是水，只是状态变了。",
		"before": ["water:solid"],
		"after": ["water:liquid"],
	},
	"breaking_glass": {
		"en": "Glass shattering", "zh": "玻璃摔碎", "chemical": false,
		"why_en": "Smaller pieces, same glass.",
		"why_zh": "碎成小块，仍然是玻璃。",
		"before": ["glass:solid"],
		"after": ["glass:pieces"],
	},
	"dissolving_sugar": {
		"en": "Sugar dissolving in water", "zh": "白糖溶解在水里", "chemical": false,
		"why_en": "The sugar is still sugar; boil the water off and it returns.",
		"why_zh": "糖还是糖，把水蒸干它就回来了。",
		"before": ["water:liquid", "sugar:grains"],
		"after": ["water:liquid", "sugar:dissolved"],
	},
	"rusting_iron": {
		"en": "Iron rusting", "zh": "铁生锈", "chemical": true,
		"why_en": "Rust is a new substance, not iron with a coat of paint.",
		"why_zh": "锈是新物质，不是铁表面刷了层颜色。",
		"before": ["iron:solid"],
		"after": ["rust:solid"],
	},
	"melting_wax": {
		"en": "Candle wax melting", "zh": "蜡烛的蜡熔化", "chemical": false,
		"why_en": "Melted wax is still wax. Only the burning wick is chemical.",
		"why_zh": "熔化的蜡还是蜡。真正的化学变化是烛芯在燃烧。",
		"before": ["wax:solid"],
		"after": ["wax:liquid"],
	},
	"baking_soda_vinegar": {
		"en": "Baking soda fizzing in vinegar", "zh": "小苏打遇到醋冒泡", "chemical": true,
		"why_en": "The bubbles are a new gas that was not there before.",
		"why_zh": "冒出的气泡是原来没有的新气体。",
		"before": ["vinegar:liquid", "soda:grains"],
		"after": ["vinegar:liquid", "co2:gas"],
	},
	"boiling_water": {
		"en": "Water boiling into steam", "zh": "水沸腾变成水蒸气", "chemical": false,
		"why_en": "Steam is still water.",
		"why_zh": "水蒸气还是水。",
		"before": ["water:liquid"],
		"after": ["water:gas"],
	},
	"cooking_egg": {
		"en": "An egg white turning solid in the pan", "zh": "蛋清在锅里变白凝固", "chemical": true,
		"why_en": "It never turns runny again; a new substance formed.",
		"why_zh": "它再也变不回流动的样子了——生成了新物质。",
		"before": ["egg_raw:liquid"],
		"after": ["egg_set:solid"],
	},
	"tearing_cloth": {
		"en": "Cloth torn in half", "zh": "布被撕成两半", "chemical": false,
		"why_en": "Two pieces, same cloth.",
		"why_zh": "两片，还是同一种布。",
		"before": ["cloth:fibre"],
		"after": ["cloth:pieces"],
	},
	"silver_tarnish": {
		"en": "Silver darkening in air", "zh": "银器在空气中发黑", "chemical": true,
		"why_en": "The dark layer is a new compound with the air.",
		"why_zh": "那层黑是银和空气生成的新化合物。",
		"before": ["silver:solid"],
		"after": ["tarnish:solid"],
	},
	"magnet_attracting": {
		"en": "A magnet picking up nails", "zh": "磁铁吸起铁钉", "chemical": false,
		"why_en": "The nails are unchanged once you pull them off.",
		"why_zh": "把钉子拿下来，它一点没变。",
		"before": ["steel:bar", "iron:pieces"],
		"after": ["steel:bar", "iron:cling"],
	},
	"milk_souring": {
		"en": "Milk turning sour", "zh": "牛奶发酸变质", "chemical": true,
		"why_en": "New acids were produced; it cannot be undone.",
		"why_zh": "产生了新的酸性物质，而且回不去了。",
		"before": ["milk:liquid"],
		"after": ["curd:pieces", "milk:liquid"],
	},
	"salt_crystallising": {
		"en": "Salt crystals forming as seawater dries", "zh": "海水晒干析出盐粒",
		"chemical": false,
		"why_en": "The salt was dissolved in there all along.",
		"why_zh": "盐本来就溶在水里，只是重新析出来。",
		"before": ["water:liquid", "salt:dissolved"],
		"after": ["salt:grains"],
	},
	"bronze_reaction": {
		"en": "The warm bronze core reacting inside", "zh": "青铜核心内部正在反应",
		"chemical": true,
		"why_en": "The heat comes from a reaction making new substances.",
		"why_zh": "热量来自一场生成新物质的反应。",
		"before": ["bronze:solid"],
		"after": ["bronze:solid", "fume:gas", "heat:glow"],
	},
	"stretching_spring": {
		"en": "A spring stretched and released", "zh": "弹簧被拉长后弹回", "chemical": false,
		"why_en": "Shape changed, substance did not.",
		"why_zh": "形状变了，物质没变。",
		"before": ["steel:coil"],
		"after": ["steel:coil"],
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

## 封盘演示。原来按下"封盘"是当场判分，而每份样本只是一行字——"有没有生成
## 新物质"本来就是个用眼睛看的判断，却全靠读文字。现在封盘会把每份样本的
## 变化演一遍，变化后才出现的物质会亮起来：亮起来的就是化学变化。
const SEAL_STAGGER: float = 0.12
const SEAL_HOLD: float = 1.0

var _choice: Dictionary = {}
var _cards: Dictionary = {}
var _submit: Button
var _order: Array[String] = []
var _running: bool = false
var _run_time: float = 0.0


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_choice = {}
	_cards = {}
	_running = false
	set_instruction(_text(
		"A change is chemical only when a NEW substance appears. "
		+ "Sort every sample, then seal the tray.",
		"只有生成了「新物质」才算化学变化。把每份样本分好类，再封盘。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	content.add_child(column)

	_order = []
	for sample_id: String in LEVELS[index]:
		_order.append(sample_id)
		_choice[sample_id] = ""

	# 样本排成卡片网格而不是一行一条。原来每份样本只有一行文字，横着铺得开；
	# 现在每份都要画出变化前后的样子，得给它一块方形的地方。
	var grid := GridContainer.new()
	grid.columns = 2 if _order.size() <= 2 else 3
	if _order.size() == 4:
		grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for sample_id: String in _order:
		grid.add_child(_build_card(sample_id))

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
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.custom_minimum_size = Vector2(228.0, 0.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var dish := SampleDishView.new()
	dish.before = PackedStringArray(sample["before"])
	dish.after = PackedStringArray(sample["after"])
	dish.custom_minimum_size = Vector2(0.0, 58.0)
	dish.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(dish)

	var label := _make_label(
		_text(str(sample["en"]), str(sample["zh"])), 13, PARCHMENT
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 30.0)
	card.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	var chemical := make_button(_text("Chemical", "化学"))
	chemical.custom_minimum_size = Vector2(92.0, 28.0)
	chemical.pressed.connect(_on_pick.bind(sample_id, "chemical"))
	buttons.add_child(chemical)
	var physical := make_button(_text("Physical", "物理"))
	physical.custom_minimum_size = Vector2(92.0, 28.0)
	physical.pressed.connect(_on_pick.bind(sample_id, "physical"))
	buttons.add_child(physical)
	card.add_child(buttons)

	_cards[sample_id] = {
		"label": label, "chemical": chemical,
		"physical": physical, "dish": dish,
	}
	return card


func _on_pick(sample_id: String, choice: String) -> void:
	if _running:
		return
	_choice[sample_id] = choice
	# 改了归类，上一轮演过的变化就不作数了，皿收回封盘前的样子。
	var dish: SampleDishView = _cards[sample_id]["dish"]
	if is_instance_valid(dish):
		dish.reset_dish()
	_cards[sample_id]["label"].add_theme_color_override("font_color", PARCHMENT)
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
	if _running:
		return
	for sample_id: String in _choice:
		if str(_choice[sample_id]).is_empty():
			return
	_running = true
	_run_time = 0.0
	_set_buttons_disabled(content, true)
	GameAudio.play(&"potion_extract")
	# 依次开演而不是一起开，六只皿同时变化会看成一片闪烁。
	for slot: int in range(_order.size()):
		var dish: SampleDishView = _cards[_order[slot]]["dish"]
		if not is_instance_valid(dish):
			continue
		var timer: SceneTreeTimer = get_tree().create_timer(
			float(slot) * SEAL_STAGGER, true, false, true
		)
		timer.timeout.connect(dish.play)


func _process(delta: float) -> void:
	if not _running:
		return
	# 演示途中玩家可以直接关掉面板。_finish() 只清空内容并不释放面板本身，
	# 不拦的话演示会继续跑到判分，在一个已经结束的小游戏上再判一次。
	if not visible or _order.is_empty():
		_running = false
		return
	var lead: SampleDishView = _cards[_order[0]]["dish"]
	if not is_instance_valid(lead):
		_running = false
		return
	_run_time += delta
	var total: float = (
		SampleDishView.CHANGE_TIME
		+ float(maxi(_order.size() - 1, 0)) * SEAL_STAGGER
	)
	if _run_time < total:
		return
	if _run_time < total + SEAL_HOLD:
		_mark_verdicts()
		return
	_running = false
	_set_buttons_disabled(content, false)
	_judge()


## 演完之后每只皿亮出对错。判据本身已经画在皿里了——新物质会自己发光——
## 所以这里只是确认玩家读对了没有。
func _mark_verdicts() -> void:
	for sample_id: String in _order:
		var dish: SampleDishView = _cards[sample_id]["dish"]
		if not is_instance_valid(dish):
			continue
		if dish.verdict != -1:
			continue
		dish.verdict = 1 if str(_choice[sample_id]) == _expected(sample_id) else 0


func _expected(sample_id: String) -> String:
	return "chemical" if bool(SAMPLES[sample_id]["chemical"]) else "physical"


func _judge() -> void:
	var wrong: Array[String] = []
	for sample_id: String in _order:
		if str(_choice[sample_id]) != _expected(sample_id):
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
