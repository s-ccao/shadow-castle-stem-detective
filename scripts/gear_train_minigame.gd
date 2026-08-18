class_name GearTrainMinigame
extends MinigameShell

## 终局档案室：知识引擎。
##
## 剧情里写着知识引擎有一台黄铜星象仪，金库门要等符号确认路线才会开。这里
## 把那台机构变成可以操作的东西，教的是**齿轮传动比**——全游戏唯一一个机械
## 主题，和其它房间的化学、生物、电学、光学、时间推算都不重叠。
##
## 两条规则，都能在画面上直接看出来：
##   · 两个啮合的齿轮**转向相反**，所以链条上每多一级就反一次。
##   · 输出转速 = 输入转速 × (主动轮齿数 ÷ 从动轮齿数)。小齿轮带大齿轮会
##     变慢，大带小会变快。中间的惰轮只改变转向，不改变最终速比。
##
## 最后那条是这个游戏真正的考点：孩子几乎必然以为多插一个齿轮会改变速度。
##
## 玩法是唯一的**机构配比**题：从备选齿数里给每一级挑一个齿轮，
## 让末级同时满足目标转速和目标转向。

## 座位可以留空不装（BYPASS，皮带直接传过去）。这一条很关键：如果每关的
## 齿轮数是固定的，转向就完全由关卡决定，玩家永远不可能选错方向，那条
## 转向规则也就白教了。能跳过之后，"要不要多加一个惰轮"变成真正的决策——
## 它不改速比，只改转向。
##
## 每关：input 主动轮齿数，stages 座位数，choices 可选齿数，
## bypass 是否允许留空，target_ratio 目标速比，target_cw 末级是否顺时针。
const BYPASS: int = -1
const LEVELS: Array[Dictionary] = [
	{
		"input": 12, "stages": 1, "choices": [12, 24], "bypass": false,
		"target_ratio": 0.5, "target_cw": false,
	},
	{
		"input": 24, "stages": 1, "choices": [12, 24, 48], "bypass": false,
		"target_ratio": 2.0, "target_cw": false,
	},
	{
		"input": 12, "stages": 2, "choices": [12, 24], "bypass": false,
		"target_ratio": 0.5, "target_cw": true,
	},
	{
		"input": 24, "stages": 2, "choices": [12, 24, 36], "bypass": false,
		"target_ratio": 1.0, "target_cw": true,
	},
	{
		"input": 36, "stages": 2, "choices": [12, 18, 36], "bypass": false,
		"target_ratio": 3.0, "target_cw": true,
	},
	{
		"input": 12, "stages": 2, "choices": [12, 24], "bypass": true,
		"target_ratio": 0.5, "target_cw": false,
	},
	{
		"input": 48, "stages": 3, "choices": [12, 16, 24, 48], "bypass": true,
		"target_ratio": 4.0, "target_cw": false,
	},
	{
		"input": 12, "stages": 3, "choices": [12, 24, 36, 48], "bypass": true,
		"target_ratio": 0.25, "target_cw": true,
	},
]
var _level: Dictionary = {}
var _picked: Array[int] = []
var _stage_buttons: Array[Button] = []
var _selected_stage: int = 0
var _train: GearTrainView
var _readout: Label


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	_level = LEVELS[index]
	_picked = []
	_stage_buttons = []
	_selected_stage = 0
	for stage: int in range(int(_level["stages"])):
		_picked.append(0)

	set_instruction(_text(
		"Meshed gears turn opposite ways. Output speed is input speed times "
		+ "driver teeth over driven teeth — and a gear in the middle only "
		+ "flips direction, it never changes the final ratio.",
		"啮合的两个齿轮转向相反。输出转速 = 输入转速 × 主动轮齿数 ÷ 从动轮齿数——"
		+ "而夹在中间的齿轮只会改变转向，它**不会**改变最终速比。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	content.add_child(column)

	var goal := _make_label(_goal_text(), 15, GOLD)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(goal)

	_train = GearTrainView.new()
	_train.custom_minimum_size = Vector2(0.0, 132.0)
	column.add_child(_train)

	_readout = _make_label("", 15, PARCHMENT)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_readout)

	var stages_row := HBoxContainer.new()
	stages_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stages_row.add_theme_constant_override("separation", 10)
	column.add_child(stages_row)
	for stage: int in range(int(_level["stages"])):
		var button := make_button("")
		button.custom_minimum_size = Vector2(132.0, 30.0)
		button.pressed.connect(_on_select_stage.bind(stage))
		stages_row.add_child(button)
		_stage_buttons.append(button)

	var choice_row := HBoxContainer.new()
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.add_theme_constant_override("separation", 8)
	column.add_child(choice_row)
	for teeth: int in _level["choices"]:
		var button := make_button(
			_text("%d teeth" % teeth, "%d 齿" % teeth)
		)
		button.custom_minimum_size = Vector2(104.0, 32.0)
		button.pressed.connect(_on_pick_gear.bind(teeth))
		choice_row.add_child(button)
	if bool(_level.get("bypass", false)):
		var skip := make_button(_text("leave empty", "留空"))
		skip.custom_minimum_size = Vector2(112.0, 32.0)
		skip.pressed.connect(_on_pick_gear.bind(BYPASS))
		choice_row.add_child(skip)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var engage := make_button(_text("Engage the engine", "启动引擎"))
	engage.custom_minimum_size = Vector2(180.0, 34.0)
	engage.pressed.connect(_on_engage)
	confirm_row.add_child(engage)
	column.add_child(confirm_row)

	_refresh()


func _goal_text() -> String:
	var spin: String = (
		_text("clockwise", "顺时针") if bool(_level["target_cw"])
		else _text("counter-clockwise", "逆时针")
	)
	return _text(
		"Target: last gear turns %s at %s of the input speed"
			% [spin, _ratio_text(float(_level["target_ratio"]))],
		"目标：末级齿轮%s转动，转速为输入的 %s"
			% [spin, _ratio_text(float(_level["target_ratio"]))]
	)


func _ratio_text(ratio: float) -> String:
	if is_equal_approx(ratio, roundf(ratio)):
		return "%dx" % int(roundf(ratio))
	return "%.2fx" % ratio


## 速比只由首末齿数决定：中间每一级都以"从动"身份除一次、再以"主动"身份
## 乘一次，恰好互相抵消。这正是本关要让玩家亲眼验证的那条规律。
func _ratio() -> float:
	var driver: float = float(_level["input"])
	var ratio: float = 1.0
	for teeth: int in _picked:
		if teeth == BYPASS:
			continue
		if teeth <= 0:
			return 0.0
		ratio *= driver / float(teeth)
		driver = float(teeth)
	return ratio


## 每啮合一级反向一次；主动轮恒为顺时针。跳过的座位不参与计数。
func _gear_count() -> int:
	var total: int = 0
	for teeth: int in _picked:
		if teeth > 0:
			total += 1
	return total


func _is_clockwise() -> bool:
	return _gear_count() % 2 == 0


func _on_select_stage(stage: int) -> void:
	_selected_stage = stage
	_refresh()


func _on_pick_gear(teeth: int) -> void:
	if _selected_stage < 0 or _selected_stage >= _picked.size():
		return
	_picked[_selected_stage] = teeth
	for offset: int in range(_picked.size()):
		var candidate: int = (_selected_stage + 1 + offset) % _picked.size()
		if _picked[candidate] == 0:
			_selected_stage = candidate
			break
	_refresh()


func _refresh() -> void:
	for stage: int in range(_stage_buttons.size()):
		var teeth: int = _picked[stage]
		var seat_text: String = _text(
			"Seat %d — choose" % (stage + 1), "第 %d 位 — 待选" % (stage + 1)
		)
		if teeth == BYPASS:
			seat_text = _text(
				"Seat %d — belt through" % (stage + 1),
				"第 %d 位 — 直接传过" % (stage + 1)
			)
		elif teeth > 0:
			seat_text = _text(
				"Seat %d: %d" % [stage + 1, teeth],
				"第 %d 位：%d 齿" % [stage + 1, teeth]
			)
		_stage_buttons[stage].text = seat_text
		_stage_buttons[stage].modulate = (
			Color(1.0, 0.86, 0.45) if stage == _selected_stage else Color.WHITE
		)
	if _train != null:
		_train.input_teeth = int(_level["input"])
		_train.stages = _picked.duplicate()
		_train.queue_redraw()
	if _readout != null:
		if _picked.has(0):
			_readout.text = _text(
				"The train is incomplete.", "传动链还没装完。"
			)
		else:
			var spin: String = (
				_text("clockwise", "顺时针") if _is_clockwise()
				else _text("counter-clockwise", "逆时针")
			)
			_readout.text = _text(
				"Output: %s, %s" % [_ratio_text(_ratio()), spin],
				"输出：%s，%s" % [_ratio_text(_ratio()), spin]
			)


func _on_engage() -> void:
	if _picked.has(0):
		report_level_failed(_text(
			"A seat is still undecided — put a gear in it or belt through it.",
			"还有座位没定下来——要么装个齿轮，要么让它直接传过去。"
		))
		return
	if _gear_count() == 0:
		report_level_failed(_text(
			"Every seat is bypassed. Nothing meshes, so nothing changes.",
			"所有座位都被跳过了。没有任何啮合，也就什么都不会变。"
		))
		return
	var ratio_ok: bool = is_equal_approx(_ratio(), float(_level["target_ratio"]))
	var spin_ok: bool = _is_clockwise() == bool(_level["target_cw"])
	if ratio_ok and spin_ok:
		report_level_cleared(_text(
			"The orrery turns true. The vault symbols line up.",
			"星象仪转得分毫不差。金库的符号对齐了。"
		))
		return
	if not ratio_ok:
		# 拼接必须先用括号收口再取 %：% 绑定得比 + 紧，不加括号的话格式化只
		# 作用在最后一段字面量上，而占位符在第一段里，玩家读到的会是字面
		# 的 "%s" 而不是真正的速比。
		var numbers: Array = [
			_ratio_text(_ratio()),
			_ratio_text(float(_level["target_ratio"])),
		]
		report_level_failed(_text(
			(
				"Ratio is %s, not %s. Only the first and last gear set the "
				+ "speed — the ones between them just pass it along."
			) % numbers,
			(
				"速比是 %s，不是 %s。定速度的只有首末两个齿轮——"
				+ "夹在中间的那些只是把转动传过去而已。"
			) % numbers
		))
		return
	report_level_failed(_text(
		"Right speed, wrong direction. Each mesh reverses the spin, so an "
		+ "odd number of gears turns the output the other way.",
		"速度对了，方向错了。每啮合一次就反向一次——所以齿轮数为奇数时，"
		+ "末级的转向会跟输入相反。"
	))
