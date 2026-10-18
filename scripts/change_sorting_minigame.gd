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
		"why_en": "Heating changes the egg proteins and makes them coagulate; this is not just a change of state.",
		"why_zh": "加热使蛋白质发生变化并凝固，并不只是简单的状态变化。",
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

const SEAL_HOLD: float = 0.7
const SAMPLE_LABELS := {
	"burning_paper": ["Paper", "纸张"], "melting_ice": ["Ice", "冰块"],
	"breaking_glass": ["Glass", "玻璃"], "dissolving_sugar": ["Sugar", "白糖"],
	"rusting_iron": ["Iron", "铁片"], "melting_wax": ["Wax", "蜡"],
	"baking_soda_vinegar": ["Soda + vinegar", "苏打与醋"], "boiling_water": ["Water", "水"],
	"cooking_egg": ["Egg", "蛋清"], "tearing_cloth": ["Cloth", "布料"],
	"silver_tarnish": ["Silver", "银器"], "magnet_attracting": ["Magnet", "磁铁"],
	"milk_souring": ["Milk", "牛奶"], "salt_crystallising": ["Salt", "盐"],
	"bronze_reaction": ["Bronze core", "青铜核心"], "stretching_spring": ["Spring", "弹簧"],
}
const SAMPLE_CONDITIONS := {
	"burning_paper": ["Ignited paper burns in air; residue stays in the dish.", "纸张被点燃后在空气中燃烧，残留物留在盘内。"],
	"melting_ice": ["Room-temperature heat melts ice; no impact is applied.", "冰在室温下吸热融化，没有受到撞击。"],
	"breaking_glass": ["A short drop ends in impact; fragments lose energy.", "玻璃下落后碰撞破裂，碎片逐渐耗散动能。"],
	"dissolving_sugar": ["Sugar disperses into water, not into escaping gas.", "糖逐渐分散到水中，不是变成气体逸出。"],
	"rusting_iron": ["Iron is exposed to both moisture and oxygen.", "铁片与水分、氧气接触，变化需要时间。"],
	"melting_wax": ["Gentle heating softens wax; no wick is lit.", "温和加热使蜡软化，演示中没有点燃灯芯。"],
	"baking_soda_vinegar": ["Soda contacts vinegar; gas rises and escapes.", "小苏打与醋接触，生成的气体上升逸出。"],
	"boiling_water": ["Boiling needs heat; mist is condensed water droplets.", "持续加热维持沸腾；上方白雾是冷凝的小水滴。"],
	"cooking_egg": ["Heat spreads through the egg white as it sets.", "热量传入蛋清，凝固逐渐向内部发展。"],
	"tearing_cloth": ["Opposing pulls tension the cloth before it tears.", "两端向相反方向拉伸，织物先受力再撕裂。"],
	"silver_tarnish": ["Sulfur compounds in air slowly affect the surface.", "空气中的含硫物质缓慢作用于银器表面。"],
	"magnet_attracting": ["An external magnetic field pulls the nails.", "外加磁场吸引铁钉，接触后停止运动。"],
	"milk_souring": ["Microbial acid production takes time to sour milk.", "微生物产酸使牛奶变质，这一过程需要时间。"],
	"salt_crystallising": ["Water evaporates; crystals grow at nucleation sites.", "水分蒸发后，盐晶体从不同晶核逐渐生长。"],
	"bronze_reaction": ["Fictional device diagram, not a real bronze model.", "虚构装置的原理示意，并非真实青铜反应模型。"],
	"stretching_spring": ["An elastic spring is pulled, released, then settles.", "弹簧在弹性范围内拉伸，释放后振动衰减。"],
}

var _choice: Dictionary = {}
var _cards: Dictionary = {}
var _submit: Button
var _order: Array[String] = []
var _running: bool = false
var _run_time: float = 0.0
var _active_sample := ""
var _hero: SampleDishView
var _sample_title: Label
var _observation_status: Label
var _observation_progress: ProgressBar
var _condition_note: Label
var _pending_observation_sound: StringName = &""
var _observation_sound_at := 0.0
var _replay: Button
var _choice_stack: VBoxContainer
var _wrong_samples: Dictionary = {}
var _verdicts_shown := false


func _ready() -> void:
	super._ready()
	var panel_size := Vector2(940, 704)
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_bottom = panel_size.y * 0.5


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_choice = {}
	_cards = {}
	_wrong_samples = {}
	_running = false
	_verdicts_shown = false
	_active_sample = ""
	set_instruction(_text(
		"Select a sample and observe its change. Replay as needed, classify each sample, then seal the tray.",
		"选择样本，观察变化过程；可以反复重播。判断每份样本后，再封盘验证。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	content.add_child(column)

	_order = []
	for sample_id: String in LEVELS[index]:
		_order.append(sample_id)
		_choice[sample_id] = ""

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_sample_title = _make_label("", 18, PARCHMENT)
	_sample_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sample_title.clip_text = true
	header.add_child(_sample_title)
	_replay = make_button(_text("Replay observation", "重播观察"))
	_replay.name = "ObservationReplay"
	_replay.custom_minimum_size = Vector2(164, 32)
	_replay.pressed.connect(_replay_observation)
	header.add_child(_replay)
	var bench := HBoxContainer.new()
	bench.add_theme_constant_override("separation", 16)
	bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bench)
	_hero = SampleDishView.new()
	_hero.name = "ExperimentHero"
	_hero.custom_minimum_size = Vector2(520, 212)
	_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bench.add_child(_hero)
	var judgment := VBoxContainer.new()
	judgment.custom_minimum_size.x = 232
	judgment.add_theme_constant_override("separation", 8)
	bench.add_child(judgment)
	_observation_status = _make_label("", 14, GOLD)
	_observation_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_observation_status.custom_minimum_size.y = 34
	judgment.add_child(_observation_status)
	_observation_progress = ProgressBar.new()
	_observation_progress.name = "ObservationProgress"
	_observation_progress.custom_minimum_size.y = 8
	_observation_progress.show_percentage = false
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#211b24")
	progress_track.border_color = Color("#765b39")
	progress_track.set_border_width_all(1)
	progress_track.set_corner_radius_all(3)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#cda26a")
	progress_fill.set_corner_radius_all(3)
	_observation_progress.add_theme_stylebox_override("background", progress_track)
	_observation_progress.add_theme_stylebox_override("fill", progress_fill)
	judgment.add_child(_observation_progress)
	var criterion := _make_label(_text(
		"Did a NEW substance form?\nAppearance alone is not enough.",
		"是否产生了新物质？\n外观改变，不一定是化学变化。"
	), 15, PARCHMENT)
	criterion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	criterion.custom_minimum_size = Vector2(232, 44)
	judgment.add_child(criterion)
	_condition_note = _make_label("", 13, PARCHMENT.darkened(0.12))
	_condition_note.name = "ObservationConditions"
	_condition_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_condition_note.custom_minimum_size = Vector2(232, 52)
	judgment.add_child(_condition_note)
	_choice_stack = VBoxContainer.new()
	_choice_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	judgment.add_child(_choice_stack)
	var selectors := HBoxContainer.new()
	selectors.name = "SampleSelectors"
	selectors.add_theme_constant_override("separation", 6)
	column.add_child(selectors)
	for sample_id: String in _order:
		selectors.add_child(_build_card(sample_id))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_submit = make_button(_text("Seal the tray", "封盘"))
	_submit.custom_minimum_size = Vector2(170.0, 34.0)
	_submit.pressed.connect(_on_submit)
	row.add_child(_submit)
	_select_sample(_order[0], true)
	_refresh()


func _build_card(sample_id: String) -> Control:
	var card := make_button("")
	card.name = "SampleSelect_" + sample_id
	card.custom_minimum_size = Vector2(112, 52)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", 12)
	card.pressed.connect(_select_sample.bind(sample_id, true))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_choice_stack.add_child(buttons)
	var chemical := make_button(_text("Chemical", "化学"))
	chemical.custom_minimum_size = Vector2(220, 36)
	chemical.pressed.connect(_on_pick.bind(sample_id, "chemical"))
	buttons.add_child(chemical)
	var physical := make_button(_text("Physical", "物理"))
	physical.custom_minimum_size = Vector2(220, 36)
	physical.pressed.connect(_on_pick.bind(sample_id, "physical"))
	buttons.add_child(physical)
	_cards[sample_id] = {
		"label": card, "chemical": chemical,
		"physical": physical, "choices": buttons,
	}
	return card


func _select_sample(sample_id: String, replay: bool = true) -> void:
	if _running or _advancing or _finished:
		return
	if _active_sample != sample_id:
		_pending_observation_sound = &""
		GameAudio.stop_sample_feedback()
		_active_sample = sample_id
		var sample: Dictionary = SAMPLES[sample_id]
		_hero.before = PackedStringArray(sample["before"])
		_hero.after = PackedStringArray(sample["after"])
		_hero.set("sample_id", sample_id)
		_hero.reset_dish()
		_sample_title.text = _text(str(sample["en"]), str(sample["zh"]))
		_condition_note.text = _text(SAMPLE_CONDITIONS[sample_id][0], SAMPLE_CONDITIONS[sample_id][1])
	for id: String in _cards:
		_cards[id]["choices"].visible = id == sample_id
	if replay:
		_replay_observation()
	_refresh()


func _replay_observation() -> void:
	if _running or _advancing or _finished or not is_instance_valid(_hero):
		return
	_hero.verdict = -1
	_hero.play()
	_queue_observation_audio()
	_update_observation_status()


func _queue_observation_audio() -> void:
	GameAudio.stop_sample_feedback()
	_pending_observation_sound = &""
	match _active_sample:
		"burning_paper": _pending_observation_sound = &"sample_fire"
		"baking_soda_vinegar", "boiling_water": _pending_observation_sound = &"sample_bubbles"
		"breaking_glass": _pending_observation_sound = &"sample_glass"
		"tearing_cloth": _pending_observation_sound = &"sample_grains"
		"stretching_spring", "magnet_attracting": _pending_observation_sound = &"sample_metal"
	_observation_sound_at = _hero.sound_onset_seconds()
	_update_observation_audio()


func _update_observation_audio() -> void:
	if _pending_observation_sound.is_empty():
		return
	if not is_instance_valid(_hero) or not _hero.is_playing():
		_pending_observation_sound = &""
		return
	if float(_hero.get("_phase_time")) < _observation_sound_at:
		return
	GameAudio.play(_pending_observation_sound)
	GameAudio.duck_music(0.5)
	_pending_observation_sound = &""


func _update_observation_status() -> void:
	if not is_instance_valid(_hero) or _observation_status == null:
		return
	var phase := int(_hero.get("_phase"))
	var prefix := _text("TIME-LAPSE · ", "加速演示 · ") if _hero.is_time_lapse() else ""
	var status := _text("Ready to observe", "准备观察")
	var progress := 0.0
	if _hero.is_playing():
		status = _text("Observing the change", "正在观察变化")
		progress = clampf(float(_hero.get("_phase_time")) / SampleDishView.CHANGE_TIME, 0.0, 1.0)
	elif phase == SampleDishView.Phase.AFTER:
		status = _text("Result ready · replay anytime", "结果已呈现 · 可随时重播")
		progress = 1.0
	_observation_status.text = prefix + status
	if _running:
		_observation_status.text = prefix + _text("Sealing · observe the result", "封盘验证 · 观察结果")
	_observation_progress.value = progress * 100.0


func _on_pick(sample_id: String, choice: String) -> void:
	if _running or _advancing or _finished:
		return
	clear_feedback()
	_select_sample(sample_id, false)
	_choice[sample_id] = choice
	_wrong_samples.erase(sample_id)
	_hero.verdict = -1
	_cards[sample_id]["label"].add_theme_color_override("font_color", PARCHMENT)
	_refresh()


func _refresh() -> void:
	for sample_id: String in _cards:
		var card: Dictionary = _cards[sample_id]
		var picked: String = str(_choice.get(sample_id, ""))
		var short_name := _text(SAMPLE_LABELS[sample_id][0], SAMPLE_LABELS[sample_id][1])
		var category := _text("Choose", "待判断") if picked.is_empty() else _text(
			"Chemical" if picked == "chemical" else "Physical", "化学" if picked == "chemical" else "物理"
		)
		card["label"].text = "%d · %s\n%s" % [_order.find(sample_id) + 1, short_name, category]
		card["label"].add_theme_color_override("font_color", FAILURE if _wrong_samples.has(sample_id) else (GOLD if sample_id == _active_sample else PARCHMENT))
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
	if _running or _advancing or _finished:
		return
	for sample_id: String in _choice:
		if str(_choice[sample_id]).is_empty():
			return
	clear_feedback()
	_running = true
	_run_time = 0.0
	_verdicts_shown = false
	_set_buttons_disabled(content, true)
	_submit.text = _text("Verifying...", "正在验样…")
	GameAudio.play(&"switch_throw")
	_hero.play()
	_queue_observation_audio()


func _process(delta: float) -> void:
	if not visible or _finished:
		_running = false
		_pending_observation_sound = &""
		return
	_update_observation_status()
	_update_observation_audio()
	if not _running:
		return
	# 演示途中玩家可以直接关掉面板。_finish() 只清空内容并不释放面板本身，
	# 不拦的话演示会继续跑到判分，在一个已经结束的小游戏上再判一次。
	if not visible or _order.is_empty():
		_running = false
		return
	if not is_instance_valid(_hero):
		_running = false
		return
	_run_time += delta
	var total: float = SampleDishView.CHANGE_TIME
	if _run_time < total:
		return
	if _run_time < total + SEAL_HOLD:
		_mark_verdicts()
		return
	_running = false
	_submit.text = _text("Seal the tray", "封盘")
	_set_buttons_disabled(content, false)
	_judge()


## Classification feedback is separate from the material's observable appearance.
func _mark_verdicts() -> void:
	if _verdicts_shown:
		return
	_verdicts_shown = true
	for sample_id: String in _order:
		var correct := str(_choice[sample_id]) == _expected(sample_id)
		_cards[sample_id]["label"].add_theme_color_override("font_color", SUCCESS if correct else FAILURE)
	_hero.verdict = 1 if str(_choice[_active_sample]) == _expected(_active_sample) else 0


func presentation_duration() -> float:
	return SampleDishView.CHANGE_TIME + SEAL_HOLD


func _clear_content() -> void:
	_running = false
	_pending_observation_sound = &""
	GameAudio.stop_sample_feedback()
	if is_instance_valid(_hero):
		_hero.reset_dish()
	_hero = null
	_submit = null
	super._clear_content()


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
		_wrong_samples[sample_id] = true
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
