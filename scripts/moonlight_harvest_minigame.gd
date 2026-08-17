class_name MoonlightHarvestMinigame
extends MinigameShell

## 温室右侧长花坛：月光采收（月叶采收）。
##
## HERB_INFO 里写着月叶"只在紫光下张开"，这里把那句设定变成玩法：每株月叶
## 按自己的周期开合，只有张到七成以上才采得下来。教的是**周期与观察**——
## 每株的周期不同，玩家必须盯着节奏预判，而不能乱点。
##
## 刻意和左边花坛做成两种手感：左边是回合制的资源分配（算），这边是实时的
## 节奏观察（看）。同一个房间里两种完全不同的脑子。

const TIME_PENALTY: float = 1.5

## 每关：pods 每株的周期（秒），offsets 相位错开，thorns 哪几株是荆棘，
## limit 限时（秒）。周期各不相同才能逼出"预判"这件事。
const LEVELS: Array[Dictionary] = [
	{
		"pods": [3.0], "offsets": [0.0], "thorns": [], "limit": 14.0,
	},
	{
		"pods": [3.0, 4.0], "offsets": [0.0, 0.35], "thorns": [], "limit": 16.0,
	},
	{
		"pods": [2.6, 3.4, 4.2], "offsets": [0.0, 0.3, 0.6],
		"thorns": [], "limit": 18.0,
	},
	{
		"pods": [2.4, 3.0, 3.8], "offsets": [0.1, 0.5, 0.8],
		"thorns": [1], "limit": 18.0,
	},
	{
		"pods": [2.2, 2.8, 3.6, 4.4], "offsets": [0.0, 0.25, 0.5, 0.75],
		"thorns": [2], "limit": 20.0,
	},
	{
		"pods": [2.0, 2.6, 3.2, 3.8], "offsets": [0.15, 0.4, 0.65, 0.9],
		"thorns": [0, 3], "limit": 20.0,
	},
	{
		"pods": [1.8, 2.4, 3.0, 3.6, 4.2], "offsets": [0.0, 0.2, 0.4, 0.6, 0.8],
		"thorns": [1, 4], "limit": 24.0,
	},
	{
		"pods": [1.6, 2.2, 2.6, 3.2, 3.8], "offsets": [0.05, 0.3, 0.55, 0.7, 0.95],
		"thorns": [0, 2, 4], "limit": 26.0,
	},
]

var _pods: Array[MoonleafPod] = []
var _remaining_time: float = 0.0
var _running: bool = false
var _timer_label: Label
var _tally_label: Label
var _target_count: int = 0


func level_count() -> int:
	return LEVELS.size()


func build_level(index: int) -> void:
	var level: Dictionary = LEVELS[index]
	_pods = []
	_running = false
	_remaining_time = float(level["limit"])

	set_instruction(_text(
		"Moonleaf only parts under moonlight. Cut a bloom while it is fully "
		+ "open — every plant breathes on its own cycle. Never cut the "
		+ "thorned ones.",
		"月叶只在月光下张开。花苞完全绽开时才割得下来——每一株的开合周期都"
		+ "不一样。带刺的那些千万别碰。"
	))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	var readout := HBoxContainer.new()
	readout.add_theme_constant_override("separation", 20)
	column.add_child(readout)

	_timer_label = _make_label("", 15, GOLD)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.add_child(_timer_label)

	_tally_label = _make_label("", 15, PARCHMENT)
	_tally_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_child(_tally_label)

	var bed := HBoxContainer.new()
	bed.alignment = BoxContainer.ALIGNMENT_CENTER
	bed.add_theme_constant_override("separation", 18)
	bed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bed)

	var periods: Array = level["pods"]
	var offsets: Array = level["offsets"]
	var thorns: Array = level["thorns"]
	_target_count = 0
	for pod_index: int in range(periods.size()):
		var pod := MoonleafPod.new()
		pod.period = float(periods[pod_index])
		pod.phase_offset = float(offsets[pod_index])
		pod.is_thorn = thorns.has(pod_index)
		pod.reset_phase()
		pod.pod_pressed.connect(_on_pod_pressed)
		bed.add_child(pod)
		_pods.append(pod)
		if not pod.is_thorn:
			_target_count += 1

	_refresh_readout()
	_running = true


func _process(delta: float) -> void:
	if not _running or not visible:
		return
	for pod: MoonleafPod in _pods:
		pod.advance(delta)
	_remaining_time -= delta
	_refresh_readout()
	if _remaining_time <= 0.0:
		_running = false
		report_level_failed(_text(
			"The moon passes. The blooms close for the night — try the rhythm again.",
			"月亮偏过去了，花苞全部合拢——重新找一次节奏。"
		))
		# 超时不惩罚进度，直接重开本关，让玩家专注在"看懂节奏"上。
		var timer: SceneTreeTimer = get_tree().create_timer(1.4, true, false, true)
		timer.timeout.connect(_restart_level)


func _restart_level() -> void:
	if visible:
		build_level(current_level())


func _harvested_count() -> int:
	var total: int = 0
	for pod: MoonleafPod in _pods:
		if pod.harvested:
			total += 1
	return total


func _refresh_readout() -> void:
	if _timer_label == null or _tally_label == null:
		return
	_timer_label.text = _text(
		"Moonlight: %.1fs" % maxf(_remaining_time, 0.0),
		"月光剩余：%.1f 秒" % maxf(_remaining_time, 0.0)
	)
	_tally_label.text = _text(
		"Harvested %d / %d" % [_harvested_count(), _target_count],
		"已采 %d / %d" % [_harvested_count(), _target_count]
	)


func _on_pod_pressed(pod: MoonleafPod) -> void:
	if not _running or pod.harvested:
		return
	if pod.is_thorn:
		_remaining_time -= TIME_PENALTY
		report_level_failed(_text(
			"Thorns. That plant is not moonleaf — look before you cut.",
			"扎手。那株不是月叶——下刀前先看清楚。"
		))
		return
	if not pod.is_ripe():
		_remaining_time -= TIME_PENALTY
		report_level_failed(_text(
			"Still closed. Wait for the bloom to open fully.",
			"还没开。等花苞完全绽开再割。"
		))
		return
	pod.harvested = true
	pod.queue_redraw()
	_refresh_readout()
	if _harvested_count() >= _target_count:
		_running = false
		report_level_cleared(_text(
			"Every bloom cut at its peak. The bed is clean.",
			"每一株都在最盛时割下。这一畦收干净了。"
		))
