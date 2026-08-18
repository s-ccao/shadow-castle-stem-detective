class_name AdditiveColorMinigame
extends MinigameShell

## 图书馆：光的叠加。
##
## 教的是图书馆知识展品那句话——光的三原色是红、绿、蓝，而且**混光是加法**
## （越叠越亮），和混颜料的减法正好相反。所以红+绿得到的是黄，不是棕色；
## 三色齐开得到白，不是黑。这一点小朋友几乎必然会先答错，正是要害。
##
## 玩法：光学台上三盏灯可以独立开关，实时预览合成色；把它调成目标色即可。
## 后半段引入"哪两盏灯坏了也能得到同一个颜色"这类只有理解加法才做得出的题。

const LAMPS: Array[String] = ["red", "green", "blue"]

const LAMP_COLOR: Dictionary = {
	"red": Color(1.0, 0.16, 0.16, 1.0),
	"green": Color(0.20, 1.0, 0.28, 1.0),
	"blue": Color(0.26, 0.42, 1.0, 1.0),
}

## 目标色一律用"哪几盏灯亮着"来定义，这样答案永远和加法模型一致，
## 不会出现美术调色和物理模型对不上的情况。
const MIXES: Dictionary = {
	"red": {"lamps": ["red"], "en": "RED", "zh": "红"},
	"green": {"lamps": ["green"], "en": "GREEN", "zh": "绿"},
	"blue": {"lamps": ["blue"], "en": "BLUE", "zh": "蓝"},
	"yellow": {"lamps": ["red", "green"], "en": "YELLOW", "zh": "黄"},
	"cyan": {"lamps": ["green", "blue"], "en": "CYAN", "zh": "青"},
	"magenta": {"lamps": ["red", "blue"], "en": "MAGENTA", "zh": "品红"},
	"white": {"lamps": ["red", "green", "blue"], "en": "WHITE", "zh": "白"},
	"dark": {"lamps": [], "en": "DARKNESS", "zh": "全暗"},
}

const LEVELS: Array[Dictionary] = [
	{"target": "red", "hint_en": "One lamp is enough.", "hint_zh": "开一盏就够了。"},
	{"target": "blue", "hint_en": "One lamp is enough.", "hint_zh": "开一盏就够了。"},
	{
		"target": "yellow",
		"hint_en": "Yellow is not a lamp here. Add two of them together.",
		"hint_zh": "这里没有黄灯。把两盏叠加起来。",
	},
	{
		"target": "cyan",
		"hint_en": "Adding light makes it brighter, never darker.",
		"hint_zh": "叠加光只会更亮，不会更暗。",
	},
	{
		"target": "magenta",
		"hint_en": "The two lamps at opposite ends of the bench.",
		"hint_zh": "光学台两端的那两盏。",
	},
	{
		"target": "white",
		"hint_en": "All three primaries of light together.",
		"hint_zh": "光的三原色全部叠加。",
	},
	{
		"target": "dark",
		"hint_en": "Mixing paint makes mud. Mixing light makes light. "
			+ "So what gives you nothing at all?",
		"hint_zh": "混颜料越混越脏，混光越混越亮。那什么才是彻底的黑？",
	},
	{
		"target": "cyan",
		"hint_en": "The red filament has burned out. Reach cyan without it.",
		"hint_zh": "红灯的灯丝烧断了。不用它也要调出青色。",
		"broken": "red",
	},
]

var _on: Dictionary = {}
var _lamp_buttons: Dictionary = {}
var _preview: MinigameColorSwatch
var _target_swatch: MinigameColorSwatch
var _level: Dictionary = {}


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_level = LEVELS[index]
	_on = {}
	_lamp_buttons = {}
	for lamp: String in LAMPS:
		_on[lamp] = false

	set_instruction(_text(
		"The console mixes LIGHT, not paint. Adding light adds brightness. "
		+ "Set the lamps so the beam matches the target. "
		+ str(_level["hint_en"]),
		"这台控制台混的是**光**，不是颜料。叠加光会更亮。"
		+ "调整灯组，让光束和目标色一致。"
		+ str(_level["hint_zh"])
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	var swatches := HBoxContainer.new()
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	swatches.add_theme_constant_override("separation", 40)
	column.add_child(swatches)

	var target_box := VBoxContainer.new()
	var target_name: String = _text(
		str(MIXES[str(_level["target"])]["en"]),
		str(MIXES[str(_level["target"])]["zh"])
	)
	var target_title := _make_label(
		_text("TARGET  " + target_name, "目标  " + target_name), 14, GOLD
	)
	target_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_box.add_child(target_title)
	_target_swatch = MinigameColorSwatch.new()
	_target_swatch.custom_minimum_size = Vector2(150.0, 96.0)
	_target_swatch.lamps = _target_lamps()
	target_box.add_child(_target_swatch)
	swatches.add_child(target_box)

	var preview_box := VBoxContainer.new()
	var preview_title := _make_label(_text("BEAM", "当前光束"), 14, PARCHMENT)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(preview_title)
	_preview = MinigameColorSwatch.new()
	_preview.custom_minimum_size = Vector2(150.0, 96.0)
	preview_box.add_child(_preview)
	swatches.add_child(preview_box)

	var lamps_row := HBoxContainer.new()
	lamps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lamps_row.add_theme_constant_override("separation", 16)
	column.add_child(lamps_row)

	var broken: String = str(_level.get("broken", ""))
	for lamp: String in LAMPS:
		var button := make_button(_lamp_name(lamp))
		button.custom_minimum_size = Vector2(132.0, 38.0)
		if lamp == broken:
			button.disabled = true
			button.text = _lamp_name(lamp) + _text(" (burned out)", "（已烧断）")
		else:
			button.pressed.connect(_on_toggle.bind(lamp))
		lamps_row.add_child(button)
		_lamp_buttons[lamp] = button

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var confirm := make_button(_text("Read the plate", "读取字迹"))
	confirm.custom_minimum_size = Vector2(170.0, 34.0)
	confirm.pressed.connect(_on_confirm)
	confirm_row.add_child(confirm)
	column.add_child(confirm_row)

	_refresh()


func _lamp_name(lamp: String) -> String:
	match lamp:
		"red":
			return _text("RED", "红灯")
		"green":
			return _text("GREEN", "绿灯")
		_:
			return _text("BLUE", "蓝灯")


func _target_lamps() -> Array:
	return (MIXES[str(_level["target"])]["lamps"] as Array).duplicate()


func _active_lamps() -> Array:
	var active: Array = []
	for lamp: String in LAMPS:
		if bool(_on[lamp]):
			active.append(lamp)
	return active


func _on_toggle(lamp: String) -> void:
	_on[lamp] = not bool(_on[lamp])
	_refresh()


func _refresh() -> void:
	_preview.lamps = _active_lamps()
	_preview.queue_redraw()
	for lamp: String in LAMPS:
		var button: Button = _lamp_buttons[lamp]
		if button.disabled:
			continue
		button.modulate = (
			Color(1.0, 1.0, 1.0) if bool(_on[lamp]) else Color(0.62, 0.62, 0.62)
		)


func _on_confirm() -> void:
	var want: Array = _target_lamps()
	var have: Array = _active_lamps()
	want.sort()
	have.sort()
	if want == have:
		report_level_cleared(_text(
			"The beam matches. Hidden strokes rise out of the page.",
			"光束对上了。纸面浮出了隐藏的字迹。"
		))
		return
	report_level_failed(_text(
		"Not that colour. Remember: light ADDS — red and green give yellow, "
		+ "and all three give white.",
		"不是这个颜色。记住：光是**加法**——红加绿得到黄，三色齐开得到白。"
	))
