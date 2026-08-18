class_name LibraryLightLabUI
extends CanvasLayer

## Ashford Optics Laboratory.
##
## Three self-contained light games share one arcade shell: an animated
## apparatus stage, a control deck, staged progression, scoring and hints.
## Each game escalates across five stages instead of ending after one answer.

signal completed(challenge_id: String)
signal closed

const LAB_BACKDROP_SHADER: Shader = preload(
	"res://assets/ui/library_lab_backdrop.gdshader"
)

const CHANNELS: Array = ["red", "green", "blue"]

const BAND_COLORS: Dictionary = {
	"red": Color(0.90, 0.24, 0.20, 1.0),
	"orange": Color(0.94, 0.53, 0.17, 1.0),
	"yellow": Color(0.94, 0.85, 0.28, 1.0),
	"green": Color(0.34, 0.78, 0.38, 1.0),
	"cyan": Color(0.30, 0.82, 0.84, 1.0),
	"blue": Color(0.28, 0.46, 0.92, 1.0),
	"violet": Color(0.58, 0.36, 0.88, 1.0),
}
const BAND_NAMES_ZH: Dictionary = {
	"red": "红",
	"orange": "橙",
	"yellow": "黄",
	"green": "绿",
	"cyan": "青",
	"blue": "蓝",
	"violet": "紫",
}
const BAND_NANOMETRES: Dictionary = {
	"red": 700,
	"orange": 620,
	"yellow": 580,
	"green": 530,
	"cyan": 490,
	"blue": 460,
	"violet": 410,
}
const SPECTRUM_ORDER: Array = ["red", "orange", "yellow", "green", "cyan", "blue", "violet"]

const SPECTRUM_STAGES: Array = [
	{"solution": ["red", "green", "blue"], "tray": ["green", "blue", "red"]},
	{"solution": ["red", "yellow", "green", "blue"], "tray": ["blue", "red", "green", "yellow"]},
	{
		"solution": ["red", "orange", "green", "blue", "violet"],
		"tray": ["violet", "green", "red", "blue", "orange"],
	},
	{
		"solution": ["red", "orange", "yellow", "green", "blue", "violet"],
		"tray": ["green", "violet", "red", "blue", "yellow", "orange"],
	},
	{
		"solution": ["red", "orange", "yellow", "green", "cyan", "blue", "violet"],
		"tray": ["cyan", "red", "blue", "yellow", "violet", "green", "orange"],
	},
]

const PIGMENT_STAGES: Array = [
	{
		"name_en": "GREEN LEAF",
		"name_zh": "绿色叶片",
		"reflect": ["green"],
		"color": Color(0.30, 0.62, 0.26, 1.0),
	},
	{
		"name_en": "RED APPLE",
		"name_zh": "红色苹果",
		"reflect": ["red"],
		"color": Color(0.78, 0.16, 0.16, 1.0),
	},
	{
		"name_en": "YELLOW LEMON",
		"name_zh": "黄色柠檬",
		"reflect": ["red", "green"],
		"color": Color(0.92, 0.83, 0.24, 1.0),
	},
	{
		"name_en": "WHITE CHALK",
		"name_zh": "白色石膏",
		"reflect": ["red", "green", "blue"],
		"color": Color(0.94, 0.93, 0.90, 1.0),
	},
	{
		"name_en": "BLACK SOOT",
		"name_zh": "黑色炭灰",
		"reflect": [],
		"color": Color(0.10, 0.10, 0.12, 1.0),
	},
]

const MIXER_STAGES: Array = [
	{"name_en": "CYAN", "name_zh": "青光", "levels": {"red": 0, "green": 2, "blue": 2}},
	{"name_en": "MAGENTA", "name_zh": "品红光", "levels": {"red": 2, "green": 0, "blue": 2}},
	{"name_en": "YELLOW", "name_zh": "黄光", "levels": {"red": 2, "green": 2, "blue": 0}},
	{"name_en": "WHITE", "name_zh": "白光", "levels": {"red": 2, "green": 2, "blue": 2}},
	{"name_en": "AMBER", "name_zh": "琥珀光", "levels": {"red": 2, "green": 1, "blue": 0}},
]

const LEVEL_LABELS_EN: Array = ["OFF", "50%", "100%"]
const LEVEL_LABELS_ZH: Array = ["关闭", "半亮", "全亮"]

const FRAME_SIZE := Vector2(900.0, 660.0)
const APPARATUS_SIZE := Vector2(844.0, 300.0)
const DECK_SIZE := Vector2(844.0, 156.0)

const COLOR_GOLD := Color(0.97, 0.80, 0.42, 1.0)
const COLOR_PARCHMENT := Color(0.91, 0.85, 0.71, 1.0)
const COLOR_MUTED := Color(0.70, 0.64, 0.53, 1.0)
const COLOR_SUCCESS := Color(0.60, 0.92, 0.56, 1.0)
const COLOR_WARN := Color(0.95, 0.72, 0.40, 1.0)
const COLOR_VIOLET := Color(0.72, 0.58, 0.95, 1.0)

var challenge_id := ""
var knowledge_reference_only := true
var stage_index := 0
var challenge_completed := false
var hints_used := 0
var score := 0

var spectrum_pick: Array = []
var reflection_state: Dictionary = {}
var mixer_levels: Dictionary = {"red": 0, "green": 0, "blue": 0}

var root_control: Control
var frame: Panel
var title_label: Label
var subtitle_label: Label
var stage_label: Label
var score_label: Label
var stage_pips: Array = []
var progress_fill: ColorRect
var reference_label: Label
var apparatus: Control
var deck: Control
var status_label: Label
var hint_button: Button
var reset_button: Button
var submit_button: Button
var close_button: Button
var reward_badge: Panel
var reward_label: Label
var ambient_layer: Control
var event_fx_layer: Control
var feedback_flash: ColorRect
var stage_banner: Panel
var stage_banner_label: Label
var stage_banner_detail: Label
var filter_reveal: Control
var filter_reveal_jewel: Node2D
var filter_reveal_frame: Polygon2D
var filter_reveal_core: Polygon2D
var filter_reveal_gloss: Polygon2D
var filter_reveal_facets: Line2D
var filter_reveal_rings: Array = []
var ambient_motes: Array = []
var effect_time := 0.0

var prism_stage: Control
var prism_beam: Line2D
var prism_glass: Polygon2D
var dispersion_rays: Array = []
var prism_reticle: Node2D
var prism_sockets: Array = []
var prism_socket_labels: Array = []
var prism_socket_beams: Array = []
var prism_caption: Label
var prism_tray: Control
var prism_tray_buttons: Array = []
var prism_readout: Label

var pigment_stage: Control
var pigment_specimen: Polygon2D
var pigment_specimen_label: Label
var pigment_in_beams: Dictionary = {}
var pigment_out_beams: Dictionary = {}
var pigment_swatch: ColorRect
var pigment_perceived_label: Label
var pigment_deck: Control
var pigment_reflect_buttons: Dictionary = {}
var pigment_absorb_buttons: Dictionary = {}
var pigment_notes: Dictionary = {}
var pigment_reticle: Node2D
var observer_scanner: Node2D
var observer_outer_ring: Line2D
var observer_inner_ring: Line2D
var observer_iris: Polygon2D
var observer_pupil: Polygon2D
var observer_scan_beam: Line2D
var observer_aperture_blades: Array = []

var mixer_stage: Control
var mixer_discs: Dictionary = {}
var mixer_emitters: Dictionary = {}
var mixer_emitter_positions: Dictionary = {}
var mixer_feed_beams: Dictionary = {}
var mixer_mix_swatch: ColorRect
var mixer_target_swatch: ColorRect
var mixer_target_label: Label
var mixer_match_fill: ColorRect
var mixer_match_label: Label
var mixer_deck: Control
var mixer_level_buttons: Dictionary = {}
var mixer_readouts: Dictionary = {}
var mixer_reticle: Node2D


func _ready() -> void:
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	visible = false
	root_control.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	effect_time += delta
	_update_ambient_motes(delta)
	_update_apparatus_idle()


# ---------------------------------------------------------------- public API


func open_challenge(next_challenge_id: String) -> void:
	challenge_id = next_challenge_id
	challenge_completed = false
	stage_index = 0
	hints_used = 0
	score = 0
	_reset_stage_state()
	_refresh_copy()
	_show_active_stage()
	_refresh_all()
	visible = true
	root_control.visible = true
	frame.set_meta("rest_position", frame.position)
	root_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	frame.scale = Vector2(0.965, 0.965)
	frame.modulate = Color.WHITE
	feedback_flash.modulate.a = 0.0
	stage_banner.visible = false
	filter_reveal.visible = false
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, 0.26)
	tween.tween_callback(_play_opening_sequence)
	call_deferred("_focus_first_control")


func close() -> void:
	if not visible:
		return
	visible = false
	root_control.visible = false
	closed.emit()


func get_stage_count() -> int:
	return _stage_list().size()


func get_stage_solution() -> Array:
	var stage := _current_stage()
	if stage.is_empty():
		return []
	match challenge_id:
		"red":
			return (stage["solution"] as Array).duplicate()
		"green":
			return (stage["reflect"] as Array).duplicate()
		"blue":
			return (stage["levels"] as Dictionary).keys()
	return []


func reset_current_stage() -> void:
	if challenge_completed:
		return
	_reset_stage_state()
	_set_status(
		_text("Apparatus reset. Stage progress is untouched.", "装置已重置，关卡进度不受影响。"),
		COLOR_MUTED
	)
	_refresh_all()


func request_hint() -> void:
	if challenge_completed:
		return
	hints_used += 1
	score = maxi(0, score - 20)
	_set_status(_stage_hint(), COLOR_WARN)
	_refresh_header()
	_play_hint_feedback()


func choose_spectrum_token(band: String) -> void:
	if challenge_id != "red" or challenge_completed:
		return
	if not BAND_COLORS.has(band) or spectrum_pick.has(band):
		return
	var stage := _current_stage()
	if stage.is_empty():
		return
	if spectrum_pick.size() >= (stage["solution"] as Array).size():
		return
	spectrum_pick.append(band)
	_set_status(
		_text(
			"Crystal seated in socket %d." % spectrum_pick.size(),
			"晶体已放入第 %d 号槽位。" % spectrum_pick.size()
		),
		COLOR_PARCHMENT
	)
	_refresh_all()
	var socket_index := spectrum_pick.size() - 1
	if socket_index >= 0 and socket_index < prism_sockets.size():
		var socket := prism_sockets[socket_index] as Control
		var socket_label := prism_socket_labels[socket_index] as Label
		socket.modulate.a = 0.0
		socket_label.modulate.a = 0.0
		var tray: Array = stage["tray"] as Array
		var tray_index := tray.find(band)
		var source_button := prism_tray_buttons[tray_index] as Control
		var source := _to_event_fx_local(source_button, source_button.size * 0.5)
		var target := _to_event_fx_local(socket, socket.size * 0.5)
		OpticalFxRuntime.launch_jewel(
			self,
			event_fx_layer,
			source,
			target,
			BAND_COLORS[band] as Color,
			0.30,
			_on_prism_jewel_arrived.bind(socket_index, band)
		)


func retract_spectrum_token(socket_index: int) -> void:
	if challenge_id != "red" or challenge_completed:
		return
	if socket_index < 0 or socket_index >= spectrum_pick.size():
		return
	spectrum_pick.remove_at(socket_index)
	_refresh_all()


func set_reflection_response(channel: String, response: String) -> void:
	if challenge_id != "green" or challenge_completed:
		return
	if not CHANNELS.has(channel):
		return
	if not ["unknown", "reflect", "absorb"].has(response):
		return
	reflection_state[channel] = response
	_refresh_all()
	_animate_reflection_response(channel, response)
	var selected := (
		pigment_reflect_buttons[channel] as Button
		if response == "reflect"
		else pigment_absorb_buttons[channel] as Button
	)
	_pop_control(selected, 1.06)
	_pop_canvas_item(pigment_specimen, 1.06)
	_spawn_sparks(
		apparatus.position + pigment_specimen.position,
		_channel_color(channel, 1.0),
		5,
		36.0
	)


func set_mixer_channels(channels: Array) -> void:
	if challenge_id != "blue" or challenge_completed:
		return
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		mixer_levels[channel] = 0
	for requested_variant: Variant in channels:
		var requested := str(requested_variant)
		if CHANNELS.has(requested):
			mixer_levels[requested] = 2
	_refresh_all()
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		_animate_mixer_charge(channel, int(mixer_levels[channel]))


func set_mixer_level(channel: String, level: int) -> void:
	if challenge_id != "blue" or challenge_completed:
		return
	if not CHANNELS.has(channel):
		return
	mixer_levels[channel] = clampi(level, 0, 2)
	_refresh_all()
	_animate_mixer_charge(channel, clampi(level, 0, 2))
	var key := "%s_%d" % [channel, clampi(level, 0, 2)]
	if mixer_level_buttons.has(key):
		_pop_control(mixer_level_buttons[key] as Control, 1.06)
	if mixer_discs.has(channel) and level > 0:
		var disc := mixer_discs[channel] as Polygon2D
		_pop_canvas_item(disc, 1.10)
		_spawn_sparks(
			apparatus.position + disc.position,
			_channel_color(channel, 1.0),
			5 + level * 2,
			32.0 + float(level) * 14.0
		)


func submit_current_challenge() -> void:
	if challenge_completed:
		close()
		return
	match challenge_id:
		"red":
			_submit_spectrum()
		"green":
			_submit_pigment()
		"blue":
			_submit_mixer()


# ------------------------------------------------------------ stage plumbing


func _stage_list() -> Array:
	match challenge_id:
		"red":
			return SPECTRUM_STAGES
		"green":
			return PIGMENT_STAGES
		"blue":
			return MIXER_STAGES
	return []


func _current_stage() -> Dictionary:
	var stages := _stage_list()
	if stage_index < 0 or stage_index >= stages.size():
		return {}
	return stages[stage_index] as Dictionary


func _reset_stage_state() -> void:
	spectrum_pick.clear()
	reflection_state = {"red": "unknown", "green": "unknown", "blue": "unknown"}
	mixer_levels = {"red": 0, "green": 0, "blue": 0}
	for beam_variant: Variant in prism_socket_beams:
		var socket_beam := beam_variant as Line2D
		if socket_beam != null:
			socket_beam.visible = false
	for beam_variant: Variant in pigment_out_beams.values():
		var reflected_beam := beam_variant as Line2D
		if reflected_beam != null:
			reflected_beam.visible = false
	for beam_variant: Variant in mixer_feed_beams.values():
		var feed := beam_variant as Line2D
		if feed != null:
			feed.visible = false


func _advance_stage(message: String) -> void:
	score += 100
	if stage_index + 1 < _stage_list().size():
		_play_stage_clear_feedback(stage_index + 1)
	stage_index += 1
	_reset_stage_state()
	if stage_index >= _stage_list().size():
		_complete_challenge()
		return
	_set_status(message, COLOR_SUCCESS)
	_refresh_all()
	_pulse_apparatus()
	_animate_current_stage_intro()


func _complete_challenge() -> void:
	if challenge_completed:
		return
	challenge_completed = true
	stage_index = _stage_list().size() - 1
	_set_status(_completion_line(), COLOR_SUCCESS)
	submit_button.text = _text("RETURN WITH FILTER", "携带滤镜返回")
	reset_button.disabled = true
	hint_button.disabled = true
	reward_label.text = _text(
		"%s FILTER RECOVERED  ·  SCORE %d" % [challenge_id.to_upper(), score],
		"已回收%s滤镜 · 得分 %d" % [_filter_name_zh(), score]
	)
	reward_badge.visible = true
	reward_badge.scale = Vector2(0.85, 0.85)
	reward_badge.pivot_offset = reward_badge.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_badge, "scale", Vector2.ONE, 0.30)
	_play_filter_recovery_feedback()
	completed.emit(challenge_id)
	_refresh_header()


func _submit_spectrum() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	var solution: Array = stage["solution"] as Array
	if spectrum_pick.size() < solution.size():
		_set_status(
			_text(
				"Fill every socket before running the prism.",
				"请先填满全部槽位，再启动棱镜。"
			),
			COLOR_WARN
		)
		_play_warning_feedback()
		return
	for index: int in range(solution.size()):
		if str(spectrum_pick[index]) != str(solution[index]):
			spectrum_pick.clear()
			_set_status(
				_text(
					"Dispersion rejected. The rail runs from the longest wavelength to the shortest.",
					"色散未通过。导轨要求从最长波长排到最短波长。"
				),
				COLOR_WARN
			)
			_refresh_all()
			_play_failure_feedback()
			return
	_advance_stage(
		_text(
			"Dispersion locked. The rail accepts a wider band next.",
			"色散锁定。导轨将接入更宽的谱段。"
		)
	)


func _submit_pigment() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		if str(reflection_state.get(channel, "unknown")) == "unknown":
			_set_status(
				_text(
					"Set every channel to REFLECT or ABSORB first.",
					"请先为每个光色选择“反射”或“吸收”。"
				),
				COLOR_WARN
			)
			_play_warning_feedback()
			return
	var reflect: Array = stage["reflect"] as Array
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		var expected := "reflect" if reflect.has(channel) else "absorb"
		if str(reflection_state[channel]) != expected:
			_set_status(
				_text(
					"That model does not produce this specimen's colour. What you see is the light it sends back.",
					"该模型无法产生此样本的颜色。你看见的是它送回的光。"
				),
				COLOR_WARN
			)
			_play_failure_feedback()
			return
	_advance_stage(
		_text("Specimen matched. A new sample is mounted.", "样本匹配。新的样本已装载。")
	)


func _submit_mixer() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	var target: Dictionary = stage["levels"] as Dictionary
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		if int(mixer_levels[channel]) != int(target[channel]):
			_set_status(
				_text(
					"Beam mismatch. Emitted light adds together — change which lamps burn, and how brightly.",
					"光束不匹配。发出的光会相加——调整点亮的灯以及它们的亮度。"
				),
				COLOR_WARN
			)
			_play_failure_feedback()
			return
	_advance_stage(
		_text("Target rendered. The relay loads a new colour.", "目标已还原。继电器载入新的颜色。")
	)


func _stage_hint() -> String:
	match challenge_id:
		"red":
			return _text(
				"Warm bands carry longer waves than cool bands; read the ruler under the prism.",
				"暖色谱段的波长比冷色谱段更长；请查看棱镜下方的标尺。"
			)
		"green":
			var stage := _current_stage()
			if stage.is_empty():
				return ""
			return _text(
				"Compare the specimen's own colour with the outgoing beams.",
				"把样本自身的颜色与射出的光束做对比。"
			)
		"blue":
			return _text(
				"Watch the live mix panel: add lamps until it matches the target swatch.",
				"观察实时混合面板：逐步加入灯光，直到与目标色块一致。"
			)
	return ""


func _completion_line() -> String:
	match challenge_id:
		"red":
			return _text(
				"Every band ordered. The crimson filter drops from the prism mount.",
				"全部谱段排序完成。绯红滤镜从棱镜座落下。"
			)
		"green":
			return _text(
				"Every specimen explained. The verdant filter is released.",
				"全部样本解释完成。翠绿滤镜已释放。"
			)
		"blue":
			return _text(
				"Every colour rendered. The cobalt filter is released.",
				"全部颜色还原完成。钴蓝滤镜已释放。"
			)
	return ""


func _filter_name_zh() -> String:
	match challenge_id:
		"red":
			return "红色"
		"green":
			return "绿色"
		"blue":
			return "蓝色"
	return ""


# ------------------------------------------------------------------ refresh


func _refresh_all() -> void:
	_refresh_header()
	match challenge_id:
		"red":
			_refresh_prism()
		"green":
			_refresh_pigment()
		"blue":
			_refresh_mixer()


func _refresh_header() -> void:
	var total := maxi(1, _stage_list().size())
	var cleared := _stage_list().size() if challenge_completed else stage_index
	stage_label.text = _text(
		"STAGE %d / %d" % [mini(stage_index + 1, total), total],
		"关卡 %d / %d" % [mini(stage_index + 1, total), total]
	)
	score_label.text = _text(
		"SCORE %d   HINTS %d" % [score, hints_used],
		"得分 %d   提示 %d" % [score, hints_used]
	)
	for index: int in range(stage_pips.size()):
		var pip := stage_pips[index] as ColorRect
		if index >= total:
			pip.visible = false
			continue
		pip.visible = true
		if index < cleared:
			pip.color = COLOR_SUCCESS
		elif index == stage_index:
			pip.color = COLOR_GOLD
		else:
			pip.color = Color(0.30, 0.25, 0.20, 1.0)
	var ratio := float(cleared) / float(total)
	progress_fill.size = Vector2(maxf(4.0, 840.0 * ratio), 6.0)


func _refresh_prism() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	var solution: Array = stage["solution"] as Array
	var tray: Array = stage["tray"] as Array
	for index: int in range(prism_sockets.size()):
		var socket := prism_sockets[index] as Panel
		var socket_label := prism_socket_labels[index] as Label
		var active := index < solution.size()
		socket.visible = active
		socket_label.visible = active
		if not active or index >= spectrum_pick.size():
			socket.modulate.a = 1.0
			socket_label.modulate.a = 1.0
			var stale_beam := prism_socket_beams[index] as Line2D
			stale_beam.visible = false
		if not active:
			continue
		if index < spectrum_pick.size():
			var band := str(spectrum_pick[index])
			socket.add_theme_stylebox_override(
				"panel", _panel_style(BAND_COLORS[band] as Color, COLOR_GOLD, 2, 8)
			)
			socket_label.text = "%d\n%d nm" % [index + 1, int(BAND_NANOMETRES[band])]
		else:
			socket.add_theme_stylebox_override(
				"panel",
				_panel_style(Color(0.055, 0.045, 0.075, 0.96), Color(0.42, 0.34, 0.24, 0.90), 2, 8)
			)
			socket_label.text = "%d" % (index + 1)
	_layout_prism_sockets(solution.size())
	for index: int in range(prism_tray_buttons.size()):
		var button := prism_tray_buttons[index] as Button
		if index >= tray.size():
			button.visible = false
			continue
		var band := str(tray[index])
		button.visible = true
		button.text = _band_label(band)
		button.disabled = spectrum_pick.has(band)
		_style_button(button, BAND_COLORS[band] as Color)
	_layout_prism_tray(tray.size())
	var readout := ""
	for band_variant: Variant in spectrum_pick:
		readout += ("  →  " if readout != "" else "") + _band_label(str(band_variant))
	prism_readout.text = readout if readout != "" else _text("— rail empty —", "— 导轨为空 —")
	prism_caption.text = _text(
		"LONGEST WAVELENGTH        →        SHORTEST WAVELENGTH",
		"最长波长        →        最短波长"
	)


func _refresh_pigment() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	pigment_specimen.color = stage["color"] as Color
	pigment_specimen_label.text = _text(str(stage["name_en"]), str(stage["name_zh"]))
	var perceived := Color(0.0, 0.0, 0.0, 1.0)
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		var response := str(reflection_state.get(channel, "unknown"))
		var out_beam := pigment_out_beams[channel] as Line2D
		out_beam.visible = response == "reflect"
		var in_beam := pigment_in_beams[channel] as Line2D
		in_beam.default_color = _channel_color(channel, 0.90 if response != "unknown" else 0.45)
		if response == "reflect":
			perceived += _channel_color(channel, 1.0)
		var reflect_button := pigment_reflect_buttons[channel] as Button
		var absorb_button := pigment_absorb_buttons[channel] as Button
		_style_button(
			reflect_button,
			Color(0.20, 0.52, 0.28, 1.0) if response == "reflect" else Color(0.16, 0.20, 0.16, 1.0)
		)
		_style_button(
			absorb_button,
			Color(0.44, 0.26, 0.62, 1.0) if response == "absorb" else Color(0.18, 0.15, 0.22, 1.0)
		)
		var note := pigment_notes[channel] as Label
		if response == "reflect":
			note.text = _text("returns to the observer", "返回观察者")
		elif response == "absorb":
			note.text = _text("converted to heat", "转化为热量")
		else:
			note.text = _text("undecided", "尚未判定")
	perceived.a = 1.0
	pigment_swatch.color = perceived
	pigment_perceived_label.text = _text(
		"PERCEIVED  ·  %s" % _describe_perceived(),
		"感知颜色 · %s" % _describe_perceived()
	)


func _refresh_mixer() -> void:
	var stage := _current_stage()
	if stage.is_empty():
		return
	var target_levels: Dictionary = stage["levels"] as Dictionary
	var mix := Color(0.0, 0.0, 0.0, 1.0)
	var target := Color(0.0, 0.0, 0.0, 1.0)
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		var level := int(mixer_levels[channel])
		var intensity := float(level) * 0.5
		var disc := mixer_discs[channel] as Polygon2D
		disc.color = _channel_color(channel, 1.0) * intensity
		disc.color.a = 1.0
		disc.visible = level > 0
		mix += _channel_color(channel, 1.0) * intensity
		target += _channel_color(channel, 1.0) * (float(int(target_levels[channel])) * 0.5)
		for level_option: int in range(3):
			var key := "%s_%d" % [channel, level_option]
			var button := mixer_level_buttons[key] as Button
			var chosen := level == level_option
			var accent := _channel_color(channel, 1.0) * (0.35 + 0.32 * float(level_option))
			accent.a = 1.0
			_style_button(button, accent if chosen else Color(0.14, 0.13, 0.18, 1.0))
		var readout := mixer_readouts[channel] as Label
		readout.text = _text(
			"%s  ·  %s" % [channel.to_upper(), str(LEVEL_LABELS_EN[level])],
			"%s · %s" % [str(BAND_NAMES_ZH[channel]), str(LEVEL_LABELS_ZH[level])]
		)
	mix.a = 1.0
	target.a = 1.0
	mixer_mix_swatch.color = mix
	mixer_target_swatch.color = target
	mixer_target_label.text = _text(
		"TARGET  ·  %s" % str(stage["name_en"]), "目标 · %s" % str(stage["name_zh"])
	)
	var distance := (
		absf(mix.r - target.r) + absf(mix.g - target.g) + absf(mix.b - target.b)
	)
	var match_ratio := clampf(1.0 - distance / 3.0, 0.0, 1.0)
	mixer_match_fill.size = Vector2(maxf(3.0, 220.0 * match_ratio), 10.0)
	mixer_match_fill.color = COLOR_SUCCESS if match_ratio > 0.999 else COLOR_VIOLET
	mixer_match_label.text = _text(
		"MATCH %d%%" % int(round(match_ratio * 100.0)), "匹配度 %d%%" % int(round(match_ratio * 100.0))
	)


func _describe_perceived() -> String:
	var reflected: Array = []
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		if str(reflection_state.get(channel, "unknown")) == "reflect":
			reflected.append(channel)
	if reflected.size() == 0:
		return _text("BLACK", "黑")
	if reflected.size() == 3:
		return _text("WHITE", "白")
	if reflected.size() == 1:
		var single := str(reflected[0])
		return _text(single.to_upper(), str(BAND_NAMES_ZH[single]))
	if reflected.has("red") and reflected.has("green"):
		return _text("YELLOW", "黄")
	if reflected.has("green") and reflected.has("blue"):
		return _text("CYAN", "青")
	return _text("MAGENTA", "品红")


func _show_active_stage() -> void:
	prism_stage.visible = challenge_id == "red"
	prism_tray.visible = challenge_id == "red"
	pigment_stage.visible = challenge_id == "green"
	pigment_deck.visible = challenge_id == "green"
	mixer_stage.visible = challenge_id == "blue"
	mixer_deck.visible = challenge_id == "blue"


func _pulse_apparatus() -> void:
	apparatus.pivot_offset = apparatus.size * 0.5
	apparatus.scale = Vector2(0.985, 0.985)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(apparatus, "scale", Vector2.ONE, 0.24)


func _play_opening_sequence() -> void:
	_play_opening_glint()
	_animate_current_stage_intro()


func _animate_current_stage_intro() -> void:
	match challenge_id:
		"red":
			var start := prism_beam.points[0]
			var finish := prism_beam.points[prism_beam.points.size() - 1]
			OpticalFxRuntime.trace_beam(
				self,
				prism_beam,
				start,
				finish,
				Color(0.98, 0.96, 0.90, 0.94),
				7.0,
				0.34
			)
			for index: int in range(dispersion_rays.size()):
				var ray := dispersion_rays[index] as Line2D
				ray.modulate.a = 0.0
				var ray_tween := create_tween()
				ray_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				ray_tween.tween_interval(0.22 + float(index) * 0.035)
				ray_tween.tween_property(ray, "modulate:a", 1.0, 0.18)
		"green":
			for index: int in range(CHANNELS.size()):
				var channel := str(CHANNELS[index])
				var beam := pigment_in_beams[channel] as Line2D
				var start := beam.points[0]
				var finish := beam.points[beam.points.size() - 1]
				OpticalFxRuntime.trace_beam(
					self,
					beam,
					start,
					finish,
					_channel_color(channel, 0.62),
					5.0,
					0.28,
					float(index) * 0.075
				)
			OpticalFxRuntime.pulse_ring(
				self,
				pigment_stage,
				observer_scanner.position,
				Color(0.44, 0.84, 1.0, 0.62),
				20.0,
				1.65,
				0.42
			)
		"blue":
			for channel_variant: Variant in CHANNELS:
				var channel := str(channel_variant)
				var emitter := mixer_emitters[channel] as Node2D
				_pop_canvas_item(emitter, 1.08)
				OpticalFxRuntime.pulse_ring(
					self,
					mixer_stage,
					emitter.position,
					_channel_color(channel, 0.72),
					13.0,
					1.7,
					0.34
				)


func _on_prism_jewel_arrived(socket_index: int, band: String) -> void:
	if socket_index < 0 or socket_index >= prism_sockets.size():
		return
	if socket_index >= spectrum_pick.size() or str(spectrum_pick[socket_index]) != band:
		return
	var socket := prism_sockets[socket_index] as Control
	var socket_label := prism_socket_labels[socket_index] as Label
	socket.modulate.a = 1.0
	socket_label.modulate.a = 1.0
	_pop_control(socket, 1.13)
	_pop_control(socket_label, 1.08)
	var socket_center := socket.position + socket.size * 0.5
	var band_node := prism_stage.get_node_or_null("DispersionBand_" + band) as Control
	var band_center := (
		band_node.position + band_node.size * 0.5
		if band_node != null
		else Vector2(336.0 + float(SPECTRUM_ORDER.find(band)) * 74.0, 75.0)
	)
	var beam := prism_socket_beams[socket_index] as Line2D
	OpticalFxRuntime.trace_beam(
		self,
		beam,
		socket_center,
		band_center,
		BAND_COLORS[band] as Color,
		3.2,
		0.24
	)
	OpticalFxRuntime.launch_packet(
		self,
		prism_stage,
		socket_center,
		band_center,
		BAND_COLORS[band] as Color,
		0.24,
		func() -> void:
			if band_node != null:
				_pop_control(band_node, 1.06)
	)
	OpticalFxRuntime.pulse_ring(
		self, prism_stage, socket_center, BAND_COLORS[band] as Color, 16.0, 1.85, 0.32
	)
	_spawn_sparks(
		_to_event_fx_local(socket, socket.size * 0.5), BAND_COLORS[band] as Color, 9, 48.0
	)


func _animate_reflection_response(channel: String, response: String) -> void:
	var beam := pigment_out_beams[channel] as Line2D
	var start := beam.get_meta("beam_start", Vector2.ZERO) as Vector2
	var finish := beam.get_meta("beam_end", Vector2.ZERO) as Vector2
	if response == "reflect":
		OpticalFxRuntime.trace_beam(
			self,
			beam,
			start,
			finish,
			_channel_color(channel, 0.96),
			5.2,
			0.26,
			0.08,
			_on_observer_acquired.bind(channel)
		)
		OpticalFxRuntime.launch_packet(
			self,
			pigment_stage,
			start,
			finish,
			_channel_color(channel, 1.0),
			0.28
		)
	elif response == "absorb":
		OpticalFxRuntime.fade_beam(self, beam, 0.14)
		OpticalFxRuntime.launch_packet(
			self,
			pigment_stage,
			start - Vector2(54.0, 0.0),
			pigment_specimen.position,
			_channel_color(channel, 0.88),
			0.19,
			func() -> void:
				OpticalFxRuntime.pulse_ring(
					self,
					pigment_stage,
					pigment_specimen.position,
					Color(0.92, 0.42, 0.20, 0.68),
					18.0,
					1.8,
					0.30
				)
		)
	else:
		OpticalFxRuntime.fade_beam(self, beam, 0.12)


func _on_observer_acquired(channel: String) -> void:
	if str(reflection_state.get(channel, "unknown")) != "reflect":
		return
	_pop_canvas_item(observer_scanner, 1.08)
	observer_iris.color = _channel_color(channel, 0.68)
	OpticalFxRuntime.pulse_ring(
		self,
		pigment_stage,
		observer_scanner.position,
		_channel_color(channel, 0.86),
		22.0,
		1.9,
		0.34
	)


func _animate_mixer_charge(channel: String, level: int) -> void:
	var disc := mixer_discs[channel] as Polygon2D
	var feed := mixer_feed_beams[channel] as Line2D
	var emitter := mixer_emitters[channel] as Node2D
	var emitter_core := emitter.get_node_or_null("EmitterCore") as Polygon2D
	var start := mixer_emitter_positions[channel] as Vector2
	var finish := disc.position
	if level <= 0:
		disc.set_meta("charging", false)
		feed.visible = false
		if emitter_core != null:
			emitter_core.color = _channel_color(channel, 0.24)
		return
	disc.visible = true
	disc.set_meta("charging", true)
	disc.modulate.a = 0.0
	disc.scale = Vector2(0.34, 0.34)
	if emitter_core != null:
		emitter_core.color = _channel_color(channel, 0.74 + 0.12 * float(level))
	_pop_canvas_item(emitter, 1.12)
	OpticalFxRuntime.trace_beam(
		self,
		feed,
		start,
		finish,
		_channel_color(channel, 0.72 + 0.12 * float(level)),
		3.2 + float(level),
		0.25,
		0.05,
		_on_mixer_charge_arrived.bind(channel, level)
	)
	OpticalFxRuntime.launch_packet(
		self, mixer_stage, start, finish, _channel_color(channel, 1.0), 0.28
	)


func _on_mixer_charge_arrived(channel: String, level: int) -> void:
	if int(mixer_levels.get(channel, 0)) != level or level <= 0:
		return
	var disc := mixer_discs[channel] as Polygon2D
	disc.set_meta("charging", false)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(disc, "scale", Vector2.ONE, 0.24)
	tween.parallel().tween_property(
		disc, "modulate:a", 0.78 + 0.10 * float(level), 0.20
	)
	OpticalFxRuntime.pulse_ring(
		self,
		mixer_stage,
		disc.position,
		_channel_color(channel, 0.78),
		28.0,
		2.25,
		0.36
	)


func _to_event_fx_local(item: CanvasItem, local_point: Vector2) -> Vector2:
	var global_point := item.get_global_transform_with_canvas() * local_point
	return event_fx_layer.get_global_transform_with_canvas().affine_inverse() * global_point


func _update_ambient_motes(delta: float) -> void:
	for mote_variant: Variant in ambient_motes:
		var mote_data := mote_variant as Dictionary
		var mote := mote_data["node"] as ColorRect
		if mote == null:
			continue
		var position := mote.position
		position.y -= float(mote_data["speed"]) * delta
		position.x += (
			sin(effect_time * 0.72 + float(mote_data["phase"]))
			* float(mote_data["drift"])
			* delta
		)
		if position.y < 8.0:
			position.y = FRAME_SIZE.y - 12.0
			position.x = 20.0 + fmod(position.x + 137.0, FRAME_SIZE.x - 40.0)
		mote.position = position
		mote.modulate.a = 0.56 + 0.34 * (
			0.5 + 0.5 * sin(effect_time * 0.90 + float(mote_data["phase"]))
		)


func _update_apparatus_idle() -> void:
	var breath := 0.5 + 0.5 * sin(effect_time * 2.15)
	progress_fill.modulate = Color(1.0, 1.0, 1.0, 0.76 + breath * 0.24)
	if not challenge_completed and stage_index >= 0 and stage_index < stage_pips.size():
		(stage_pips[stage_index] as ColorRect).modulate = Color(
			1.0, 1.0, 1.0, 0.72 + breath * 0.28
		)

	if challenge_id == "red" and prism_stage.visible:
		prism_reticle.rotation = effect_time * 0.18
		prism_beam.width = 6.2 + breath * 2.0
		prism_beam.default_color = Color(0.98, 0.96, 0.90, 0.76 + breath * 0.22)
		prism_glass.modulate = Color(1.0, 1.0, 1.0, 0.78 + breath * 0.22)
		for index: int in range(dispersion_rays.size()):
			var ray := dispersion_rays[index] as Line2D
			var band := str(SPECTRUM_ORDER[index])
			var band_color := BAND_COLORS[band] as Color
			var phase := 0.46 + 0.22 * (
				0.5 + 0.5 * sin(effect_time * 2.5 + float(index) * 0.72)
			)
			ray.default_color = Color(band_color.r, band_color.g, band_color.b, phase)
	elif challenge_id == "green" and pigment_stage.visible:
		pigment_reticle.rotation = -effect_time * 0.16
		observer_outer_ring.rotation = effect_time * 0.42
		observer_inner_ring.rotation = -effect_time * 0.68
		observer_scan_beam.rotation = sin(effect_time * 0.82) * 0.72
		observer_iris.scale = Vector2.ONE * (0.94 + breath * 0.08)
		observer_pupil.scale = Vector2.ONE * (0.82 + breath * 0.22)
		for blade_index: int in range(observer_aperture_blades.size()):
			var blade := observer_aperture_blades[blade_index] as Polygon2D
			blade.rotation = float(blade_index) * TAU / 6.0 + effect_time * 0.10
		pigment_specimen.modulate = Color(1.0, 1.0, 1.0, 0.88 + breath * 0.12)
		for channel_variant: Variant in CHANNELS:
			var channel := str(channel_variant)
			var beam := pigment_in_beams[channel] as Line2D
			beam.width = 4.2 + 1.3 * (
				0.5 + 0.5 * sin(effect_time * 2.8 + float(CHANNELS.find(channel)))
			)
			var reflected := pigment_out_beams[channel] as Line2D
			if reflected.visible:
				reflected.width = 4.4 + breath * 1.8
	elif challenge_id == "blue" and mixer_stage.visible:
		mixer_reticle.rotation = effect_time * 0.14
		for channel_variant: Variant in CHANNELS:
			var channel := str(channel_variant)
			var disc := mixer_discs[channel] as Polygon2D
			if disc.visible and not bool(disc.get_meta("charging", false)):
				disc.modulate = Color(
					1.0,
					1.0,
					1.0,
					0.82
					+ 0.18
					* (0.5 + 0.5 * sin(effect_time * 2.4 + float(CHANNELS.find(channel))))
				)


func _play_opening_glint() -> void:
	_flash(COLOR_GOLD, 0.055, 0.38)
	_spawn_sparks(Vector2(450.0, 48.0), COLOR_GOLD, 12, 96.0)


func _play_hint_feedback() -> void:
	_flash(COLOR_VIOLET, 0.045, 0.28)
	_pop_control(status_label, 1.025)
	_spawn_sparks(Vector2(105.0, 630.0), COLOR_VIOLET, 7, 48.0)


func _play_warning_feedback() -> void:
	_flash(COLOR_WARN, 0.035, 0.22)
	_pop_control(status_label, 1.018)


func _play_failure_feedback() -> void:
	_flash(Color(0.80, 0.20, 0.44, 1.0), 0.095, 0.30)
	_pop_control(status_label, 1.028)
	var origin: Vector2 = frame.get_meta("rest_position", frame.position) as Vector2
	frame.position = origin
	var shake := create_tween()
	shake.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shake.tween_property(frame, "position", origin + Vector2(5.0, 0.0), 0.035)
	shake.tween_property(frame, "position", origin + Vector2(-4.0, 0.0), 0.045)
	shake.tween_property(frame, "position", origin + Vector2(2.0, 0.0), 0.040)
	shake.tween_property(frame, "position", origin, 0.055)
	var tint := create_tween()
	tint.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tint.tween_property(apparatus, "modulate", Color(1.0, 0.64, 0.80, 1.0), 0.06)
	tint.tween_property(apparatus, "modulate", Color.WHITE, 0.20)


func _play_stage_clear_feedback(cleared_stage: int) -> void:
	stage_banner.position = Vector2(244.0, 206.0)
	_flash(COLOR_SUCCESS, 0.075, 0.38)
	_show_stage_banner(
		_text("STAGE %d CLEARED" % cleared_stage, "第 %d 关完成" % cleared_stage),
		_stage_success_detail()
	)
	_spawn_sparks(Vector2(450.0, 250.0), COLOR_GOLD, 20, 148.0)
	_spawn_expanding_ring(Vector2(450.0, 250.0), COLOR_SUCCESS, 72.0, 2.3)


func _play_filter_recovery_feedback() -> void:
	stage_banner.position = Vector2(244.0, 338.0)
	_flash(Color(1.0, 0.90, 0.62, 1.0), 0.16, 0.56)
	_show_stage_banner(
		_text("FILTER RECOVERED", "滤镜已回收"),
		_text("FIVE OPTICAL MODELS VERIFIED", "五组光学模型验证完成")
	)
	filter_reveal.visible = true
	filter_reveal.modulate.a = 1.0
	filter_reveal_core.color = (
		Color(0.94, 0.26, 0.20, 0.96)
		if challenge_id == "red"
		else Color(0.28, 0.86, 0.40, 0.96)
		if challenge_id == "green"
		else Color(0.26, 0.48, 0.98, 0.96)
	)
	filter_reveal_jewel.scale = Vector2(0.12, 0.12)
	filter_reveal_jewel.rotation = -0.34
	var core_tween := create_tween()
	core_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	core_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(filter_reveal_jewel, "scale", Vector2.ONE, 0.36)
	core_tween.parallel().tween_property(filter_reveal_jewel, "rotation", 0.0, 0.40)
	for ring_index: int in range(filter_reveal_rings.size()):
		var ring := filter_reveal_rings[ring_index] as Line2D
		ring.scale = Vector2(0.25, 0.25)
		ring.modulate.a = 1.0
		var ring_tween := create_tween()
		ring_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ring_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(
			ring, "scale", Vector2.ONE * (1.35 + float(ring_index) * 0.24), 0.62
		).set_delay(float(ring_index) * 0.06)
		ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.72)
	_spawn_sparks(Vector2(450.0, 232.0), filter_reveal_core.color, 34, 210.0)
	var retire := create_tween()
	retire.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	retire.tween_interval(1.05)
	retire.tween_property(filter_reveal, "modulate:a", 0.0, 0.35)
	retire.tween_callback(func() -> void: filter_reveal.visible = false)


func _stage_success_detail() -> String:
	match challenge_id:
		"red":
			return _text("DISPERSION RAIL LOCKED", "色散导轨已锁定")
		"green":
			return _text("SPECIMEN MODEL VERIFIED", "样本模型验证完成")
		"blue":
			return _text("TARGET COLOUR RENDERED", "目标颜色已还原")
	return ""


func _show_stage_banner(title: String, detail: String) -> void:
	stage_banner.visible = true
	stage_banner_label.text = title
	stage_banner_detail.text = detail
	stage_banner.modulate.a = 0.0
	stage_banner.scale = Vector2(0.78, 0.78)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stage_banner, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(stage_banner, "scale", Vector2.ONE, 0.22)
	tween.tween_interval(0.56)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(stage_banner, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func() -> void: stage_banner.visible = false)


func _flash(colour: Color, intensity: float, duration: float) -> void:
	feedback_flash.color = Color(colour.r, colour.g, colour.b, 1.0)
	feedback_flash.modulate.a = intensity
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback_flash, "modulate:a", 0.0, duration)


func _spawn_sparks(center: Vector2, colour: Color, count: int, radius: float) -> void:
	if event_fx_layer == null:
		return
	for index: int in range(count):
		var spark := ColorRect.new()
		var spark_size := 3.0 + float(index % 3) * 1.5
		spark.size = Vector2(spark_size, spark_size)
		spark.pivot_offset = spark.size * 0.5
		spark.rotation = PI * 0.25
		spark.position = center - spark.size * 0.5
		spark.color = colour.lightened(float(index % 4) * 0.08)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		event_fx_layer.add_child(spark)
		var angle := TAU * float(index) / float(maxi(1, count)) + float(index % 3) * 0.09
		var distance := radius * (0.48 + 0.52 * float((index * 7) % count) / float(maxi(1, count)))
		var destination := center + Vector2.from_angle(angle) * distance - spark.size * 0.5
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "position", destination, 0.38 + float(index % 5) * 0.035)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.46)
		tween.parallel().tween_property(spark, "scale", Vector2(0.18, 0.18), 0.46)
		tween.tween_callback(spark.queue_free)


func _spawn_expanding_ring(
	center: Vector2, colour: Color, radius: float, final_scale: float
) -> void:
	var ring := Line2D.new()
	ring.points = _circle_points(radius, 64)
	ring.closed = true
	ring.position = center
	ring.width = 3.0
	ring.default_color = colour
	ring.scale = Vector2(0.18, 0.18)
	event_fx_layer.add_child(ring)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * final_scale, 0.54)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.58)
	tween.tween_callback(ring.queue_free)


func _pop_control(control: Control, amount: float) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * amount
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.18)


func _pop_canvas_item(item: Node2D, amount: float) -> void:
	if item == null:
		return
	item.scale = Vector2.ONE * amount
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE, 0.20)


func _refresh_copy() -> void:
	match challenge_id:
		"red":
			title_label.text = _text("PRISM CASCADE", "棱镜序列")
			subtitle_label.text = _text(
				"RESEARCH DESK  ·  OPTICS BAY I  ·  RECOVER THE CRIMSON FILTER",
				"研究桌 · 光学实验台 I · 回收绯红滤镜"
			)
			reference_label.text = _text(
				"FILED REFERENCE: VISIBLE SPECTRUM & WAVELENGTH — tall wavelength case",
				"已归档参考：《可见光谱与波长》— 高窄波长档案柜"
			)
		"green":
			title_label.text = _text("PIGMENT BENCH", "色料工作台")
			subtitle_label.text = _text(
				"EAST WRITING DESK  ·  OPTICS BAY II  ·  RECOVER THE VERDANT FILTER",
				"东侧写字桌 · 光学实验台 II · 回收翠绿滤镜"
			)
			reference_label.text = _text(
				"FILED REFERENCE: REFLECTION, ABSORPTION & COLOUR — violet reflection cabinet",
				"已归档参考：《反射、吸收与颜色》— 紫色反射档案柜"
			)
		"blue":
			title_label.text = _text("ADDITIVE RELAY", "加色继电器")
			subtitle_label.text = _text(
				"WEST GLOBE DESK  ·  OPTICS BAY III  ·  RECOVER THE COBALT FILTER",
				"西侧地球仪桌 · 光学实验台 III · 回收钴蓝滤镜"
			)
			reference_label.text = _text(
				"FILED REFERENCE: ADDITIVE COLOUR MIXING — reinforced light archive",
				"已归档参考：《加色混合》— 加固光学档案架"
			)
	submit_button.text = _text("RUN APPARATUS", "运行装置")
	hint_button.text = _text("HINT", "提示")
	reset_button.text = _text("RESET STAGE", "重置本关")
	reset_button.disabled = false
	hint_button.disabled = false
	reward_badge.visible = false
	_set_status(
		_text(
			"Apply your filed record. Wrong attempts cost nothing.",
			"运用你已归档的知识。答错不会损失任何进度。"
		),
		COLOR_MUTED
	)


func _set_status(message: String, colour: Color) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", colour)


# ------------------------------------------------------------- construction


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "LightLabRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var veil := ColorRect.new()
	veil.name = "LabVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.006, 0.005, 0.013, 0.94)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(veil)

	frame = Panel.new()
	frame.name = "LabFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -FRAME_SIZE.x * 0.5
	frame.offset_top = -FRAME_SIZE.y * 0.5
	frame.offset_right = FRAME_SIZE.x * 0.5
	frame.offset_bottom = FRAME_SIZE.y * 0.5
	frame.pivot_offset = FRAME_SIZE * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.021, 0.016, 0.031, 0.99), Color(0.78, 0.58, 0.25, 0.97), 3, 12, 26)
	)
	root_control.add_child(frame)

	_add_frame_gradient()
	_build_ambient_layer()
	_build_header()
	_build_apparatus()
	_build_deck()
	_build_footer()
	_build_event_fx_layer()


func _add_frame_gradient() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.10, 0.07, 0.16, 0.55))
	gradient.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 256
	texture.height = 256
	var glow := TextureRect.new()
	glow.name = "FrameGlow"
	glow.texture = texture
	glow.position = Vector2(6.0, 6.0)
	glow.size = FRAME_SIZE - Vector2(12.0, 12.0)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(glow)


func _build_ambient_layer() -> void:
	ambient_layer = Control.new()
	ambient_layer.name = "AmbientArchiveVFX"
	ambient_layer.position = Vector2.ZERO
	ambient_layer.size = FRAME_SIZE
	ambient_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ambient_layer)

	var corner_specs: Array = [
		{"position": Vector2(14.0, 14.0), "flip": Vector2(1.0, 1.0)},
		{"position": Vector2(FRAME_SIZE.x - 14.0, 14.0), "flip": Vector2(-1.0, 1.0)},
		{"position": Vector2(14.0, FRAME_SIZE.y - 14.0), "flip": Vector2(1.0, -1.0)},
		{
			"position": Vector2(FRAME_SIZE.x - 14.0, FRAME_SIZE.y - 14.0),
			"flip": Vector2(-1.0, -1.0),
		},
	]
	for spec_variant: Variant in corner_specs:
		var spec := spec_variant as Dictionary
		var bracket := Line2D.new()
		bracket.position = spec["position"] as Vector2
		var flip := spec["flip"] as Vector2
		bracket.points = PackedVector2Array(
			[
				Vector2(0.0, 32.0) * flip,
				Vector2(0.0, 8.0) * flip,
				Vector2(8.0, 0.0) * flip,
				Vector2(32.0, 0.0) * flip,
			]
		)
		bracket.width = 3.0
		bracket.default_color = Color(0.74, 0.52, 0.22, 0.88)
		ambient_layer.add_child(bracket)

	for index: int in range(22):
		var mote := ColorRect.new()
		mote.name = "ArchiveMote%02d" % index
		var mote_size := 2.0 + float(index % 3)
		mote.size = Vector2(mote_size, mote_size)
		mote.pivot_offset = mote.size * 0.5
		mote.rotation = PI * 0.25
		mote.color = (
			Color(0.96, 0.76, 0.35, 0.28 + float(index % 4) * 0.06)
			if index % 3 == 0
			else Color(0.67, 0.50, 0.92, 0.20 + float(index % 4) * 0.05)
		)
		var start := Vector2(
			24.0 + fmod(float(index * 97), FRAME_SIZE.x - 48.0),
			18.0 + fmod(float(index * 53), FRAME_SIZE.y - 36.0)
		)
		mote.position = start
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ambient_layer.add_child(mote)
		ambient_motes.append(
			{
				"node": mote,
				"speed": 4.0 + float(index % 5) * 1.6,
				"phase": float(index) * 0.73,
				"drift": 2.0 + float(index % 4),
			}
		)


func _add_apparatus_rails() -> void:
	for side: int in [-1, 1]:
		var rail := Line2D.new()
		rail.name = "BrassEnergyRail" + ("L" if side < 0 else "R")
		var x := 16.0 if side < 0 else APPARATUS_SIZE.x - 16.0
		rail.points = PackedVector2Array([Vector2(x, 22.0), Vector2(x, APPARATUS_SIZE.y - 22.0)])
		rail.width = 2.0
		rail.default_color = Color(0.66, 0.46, 0.20, 0.55)
		apparatus.add_child(rail)
		for rivet_index: int in range(5):
			var rivet := Polygon2D.new()
			rivet.name = "RailRivet_%d_%d" % [side, rivet_index]
			rivet.polygon = _circle_points(3.2, 16)
			rivet.position = Vector2(x, 34.0 + float(rivet_index) * 58.0)
			rivet.color = Color(0.82, 0.63, 0.30, 0.72)
			apparatus.add_child(rivet)


func _build_event_fx_layer() -> void:
	event_fx_layer = Control.new()
	event_fx_layer.name = "LaboratoryEventVFX"
	event_fx_layer.position = Vector2.ZERO
	event_fx_layer.size = FRAME_SIZE
	event_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(event_fx_layer)

	feedback_flash = ColorRect.new()
	feedback_flash.name = "FeedbackFlash"
	feedback_flash.position = Vector2(4.0, 4.0)
	feedback_flash.size = FRAME_SIZE - Vector2(8.0, 8.0)
	feedback_flash.color = Color.WHITE
	feedback_flash.modulate.a = 0.0
	feedback_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_fx_layer.add_child(feedback_flash)

	stage_banner = Panel.new()
	stage_banner.name = "StageClearBanner"
	stage_banner.position = Vector2(244.0, 206.0)
	stage_banner.size = Vector2(412.0, 92.0)
	stage_banner.pivot_offset = stage_banner.size * 0.5
	stage_banner.visible = false
	stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_banner.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.030, 0.022, 0.045, 0.97), Color(0.91, 0.69, 0.30, 0.98), 3, 9, 18)
	)
	event_fx_layer.add_child(stage_banner)
	stage_banner_label = _make_label(
		"StageClearTitle", Vector2(16.0, 14.0), Vector2(380.0, 34.0), 22, COLOR_GOLD
	)
	stage_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_banner.add_child(stage_banner_label)
	stage_banner_detail = _make_label(
		"StageClearDetail", Vector2(18.0, 50.0), Vector2(376.0, 24.0), 10, COLOR_PARCHMENT
	)
	stage_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_banner.add_child(stage_banner_detail)

	filter_reveal = Control.new()
	filter_reveal.name = "FilterRecoveryVFX"
	filter_reveal.position = Vector2.ZERO
	filter_reveal.size = FRAME_SIZE
	filter_reveal.visible = false
	filter_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_fx_layer.add_child(filter_reveal)
	for ring_index: int in range(3):
		var ring := Line2D.new()
		ring.name = "FilterHalo%d" % ring_index
		ring.points = _circle_points(58.0 + float(ring_index) * 17.0, 64)
		ring.closed = true
		ring.position = Vector2(450.0, 232.0)
		ring.width = 2.0
		ring.default_color = Color(0.95, 0.78, 0.38, 0.72 - float(ring_index) * 0.14)
		filter_reveal.add_child(ring)
		filter_reveal_rings.append(ring)
	filter_reveal_jewel = Node2D.new()
	filter_reveal_jewel.name = "RecoveredFilterJewel"
	filter_reveal_jewel.position = Vector2(450.0, 232.0)
	filter_reveal.add_child(filter_reveal_jewel)
	var jewel_shape := PackedVector2Array(
		[
			Vector2(0.0, -54.0),
			Vector2(40.0, -28.0),
			Vector2(48.0, 20.0),
			Vector2(0.0, 56.0),
			Vector2(-48.0, 20.0),
			Vector2(-40.0, -28.0),
		]
	)
	filter_reveal_frame = Polygon2D.new()
	filter_reveal_frame.name = "RecoveredFilterBrassFrame"
	filter_reveal_frame.polygon = jewel_shape
	filter_reveal_frame.scale = Vector2(1.13, 1.13)
	filter_reveal_frame.color = Color(0.82, 0.62, 0.27, 0.98)
	filter_reveal_jewel.add_child(filter_reveal_frame)
	filter_reveal_core = Polygon2D.new()
	filter_reveal_core.name = "RecoveredFilter"
	filter_reveal_core.polygon = jewel_shape
	filter_reveal_core.color = Color(0.82, 0.24, 0.20, 0.94)
	filter_reveal_jewel.add_child(filter_reveal_core)
	filter_reveal_gloss = Polygon2D.new()
	filter_reveal_gloss.name = "RecoveredFilterGloss"
	filter_reveal_gloss.polygon = PackedVector2Array(
		[
			Vector2(-33.0, -28.0),
			Vector2(0.0, -47.0),
			Vector2(31.0, -27.0),
			Vector2(0.0, -10.0),
		]
	)
	filter_reveal_gloss.color = Color(1.0, 0.96, 0.82, 0.28)
	filter_reveal_jewel.add_child(filter_reveal_gloss)
	filter_reveal_facets = Line2D.new()
	filter_reveal_facets.name = "RecoveredFilterFacets"
	filter_reveal_facets.points = PackedVector2Array(
		[
			Vector2(-40.0, -28.0),
			Vector2(0.0, -10.0),
			Vector2(40.0, -28.0),
			Vector2(0.0, -10.0),
			Vector2(48.0, 20.0),
			Vector2(0.0, 38.0),
			Vector2(-48.0, 20.0),
			Vector2(0.0, -10.0),
			Vector2(0.0, 38.0),
			Vector2(0.0, 56.0),
		]
	)
	filter_reveal_facets.width = 1.5
	filter_reveal_facets.default_color = Color(1.0, 0.95, 0.84, 0.44)
	filter_reveal_jewel.add_child(filter_reveal_facets)


func _build_header() -> void:
	title_label = _make_label("LabTitle", Vector2(28.0, 16.0), Vector2(540.0, 38.0), 26, COLOR_GOLD)
	frame.add_child(title_label)
	subtitle_label = _make_label(
		"LabSubtitle", Vector2(30.0, 54.0), Vector2(540.0, 20.0), 11, COLOR_MUTED
	)
	frame.add_child(subtitle_label)

	stage_label = _make_label("LabStage", Vector2(596.0, 34.0), Vector2(248.0, 20.0), 12, COLOR_GOLD)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frame.add_child(stage_label)
	score_label = _make_label("LabScore", Vector2(596.0, 56.0), Vector2(248.0, 18.0), 10, COLOR_VIOLET)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frame.add_child(score_label)

	for index: int in range(7):
		var pip := ColorRect.new()
		pip.name = "StagePip%d" % index
		pip.position = Vector2(620.0 + float(index) * 32.0, 18.0)
		pip.size = Vector2(26.0, 8.0)
		pip.color = Color(0.30, 0.25, 0.20, 1.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pip)
		stage_pips.append(pip)

	var track := ColorRect.new()
	track.name = "ProgressTrack"
	track.position = Vector2(30.0, 84.0)
	track.size = Vector2(840.0, 6.0)
	track.color = Color(0.14, 0.11, 0.09, 1.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(track)
	progress_fill = ColorRect.new()
	progress_fill.name = "ProgressFill"
	progress_fill.position = Vector2(30.0, 84.0)
	progress_fill.size = Vector2(4.0, 6.0)
	progress_fill.color = COLOR_GOLD
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(progress_fill)


func _build_apparatus() -> void:
	apparatus = Panel.new()
	apparatus.name = "ApparatusStage"
	apparatus.position = Vector2(28.0, 100.0)
	apparatus.size = APPARATUS_SIZE
	apparatus.clip_contents = true
	apparatus.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.035, 0.030, 0.052, 0.99), Color(0.45, 0.33, 0.64, 0.85), 2, 9, 14)
	)
	frame.add_child(apparatus)

	var backdrop := ColorRect.new()
	backdrop.name = "AnimatedOpticsBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = LAB_BACKDROP_SHADER
	backdrop.material = material
	apparatus.add_child(backdrop)

	_add_apparatus_rails()
	_build_prism_stage()
	_build_pigment_stage()
	_build_mixer_stage()


func _build_prism_stage() -> void:
	prism_stage = Control.new()
	prism_stage.name = "PrismStage"
	prism_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prism_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apparatus.add_child(prism_stage)
	prism_reticle = _build_precision_reticle(
		prism_stage, Vector2(236.0, 82.0), 68.0, Color(0.70, 0.58, 0.92, 0.42)
	)

	prism_beam = Line2D.new()
	prism_beam.name = "WhiteBeam"
	prism_beam.points = PackedVector2Array([Vector2(46.0, 78.0), Vector2(196.0, 78.0)])
	prism_beam.width = 7.0
	prism_beam.default_color = Color(0.98, 0.96, 0.90, 0.92)
	prism_stage.add_child(prism_beam)

	prism_glass = Polygon2D.new()
	prism_glass.name = "PrismGlass"
	prism_glass.polygon = PackedVector2Array(
		[Vector2(196.0, 122.0), Vector2(276.0, 122.0), Vector2(236.0, 40.0)]
	)
	prism_glass.color = Color(0.66, 0.76, 0.94, 0.34)
	prism_stage.add_child(prism_glass)
	var prism_edge := Line2D.new()
	prism_edge.points = PackedVector2Array(
		[
			Vector2(196.0, 122.0),
			Vector2(276.0, 122.0),
			Vector2(236.0, 40.0),
			Vector2(196.0, 122.0),
		]
	)
	prism_edge.width = 2.0
	prism_edge.default_color = Color(0.80, 0.86, 0.98, 0.72)
	prism_stage.add_child(prism_edge)

	for index: int in range(SPECTRUM_ORDER.size()):
		var ray_band := str(SPECTRUM_ORDER[index])
		var ray := Line2D.new()
		ray.name = "DispersionRay_" + ray_band
		ray.points = PackedVector2Array(
			[Vector2(266.0, 100.0), Vector2(299.0, 56.0 + float(index) * 6.2)]
		)
		ray.width = 3.0
		ray.default_color = (BAND_COLORS[ray_band] as Color) * Color(1.0, 1.0, 1.0, 0.55)
		prism_stage.add_child(ray)
		dispersion_rays.append(ray)

	for index: int in range(SPECTRUM_ORDER.size()):
		var band := str(SPECTRUM_ORDER[index])
		var bar := ColorRect.new()
		bar.name = "DispersionBand_" + band
		bar.position = Vector2(300.0 + float(index) * 74.0, 52.0)
		bar.size = Vector2(72.0, 46.0)
		bar.color = (BAND_COLORS[band] as Color) * Color(1.0, 1.0, 1.0, 0.80)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prism_stage.add_child(bar)
		var nm := _make_label(
			"BandNm_" + band,
			Vector2(300.0 + float(index) * 74.0, 100.0),
			Vector2(72.0, 16.0),
			9,
			Color(0.74, 0.68, 0.56, 1.0)
		)
		nm.text = "%d nm" % int(BAND_NANOMETRES[band])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prism_stage.add_child(nm)

	for index: int in range(7):
		var socket_beam := Line2D.new()
		socket_beam.name = "SocketEmissionBeam%d" % index
		socket_beam.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		socket_beam.width = 3.0
		socket_beam.default_color = Color(0.85, 0.80, 0.70, 0.0)
		socket_beam.visible = false
		prism_stage.add_child(socket_beam)
		prism_socket_beams.append(socket_beam)
		var socket := Panel.new()
		socket.name = "PrismSocket%d" % index
		socket.size = Vector2(78.0, 78.0)
		socket.position = Vector2(0.0, 148.0)
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prism_stage.add_child(socket)
		prism_sockets.append(socket)
		var socket_label := _make_label(
			"PrismSocketLabel%d" % index, Vector2(0.0, 152.0), Vector2(78.0, 70.0), 11, COLOR_PARCHMENT
		)
		socket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		socket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prism_stage.add_child(socket_label)
		prism_socket_labels.append(socket_label)

	prism_caption = _make_label(
		"PrismCaption", Vector2(24.0, 238.0), Vector2(796.0, 22.0), 11, Color(0.78, 0.70, 0.56, 1.0)
	)
	prism_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prism_stage.add_child(prism_caption)
	prism_readout = _make_label(
		"PrismReadout", Vector2(24.0, 262.0), Vector2(796.0, 28.0), 14, COLOR_GOLD
	)
	prism_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prism_stage.add_child(prism_readout)


func _build_pigment_stage() -> void:
	pigment_stage = Control.new()
	pigment_stage.name = "PigmentStage"
	pigment_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pigment_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apparatus.add_child(pigment_stage)
	pigment_reticle = _build_precision_reticle(
		pigment_stage, Vector2(352.0, 150.0), 78.0, Color(0.82, 0.62, 0.28, 0.46)
	)

	var lamp := Polygon2D.new()
	lamp.name = "WhiteLamp"
	lamp.polygon = PackedVector2Array(
		[Vector2(64.0, 44.0), Vector2(150.0, 44.0), Vector2(166.0, 84.0), Vector2(48.0, 84.0)]
	)
	lamp.color = Color(0.42, 0.33, 0.16, 1.0)
	pigment_stage.add_child(lamp)
	var lamp_face := ColorRect.new()
	lamp_face.position = Vector2(52.0, 80.0)
	lamp_face.size = Vector2(110.0, 8.0)
	lamp_face.color = Color(0.98, 0.95, 0.86, 0.92)
	pigment_stage.add_child(lamp_face)
	var lamp_label := _make_label(
		"LampLabel", Vector2(38.0, 94.0), Vector2(140.0, 18.0), 10, Color(0.80, 0.72, 0.56, 1.0)
	)
	lamp_label.text = _text("WHITE SOURCE", "白光源")
	lamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pigment_stage.add_child(lamp_label)

	for index: int in range(CHANNELS.size()):
		var channel := str(CHANNELS[index])
		var in_beam := Line2D.new()
		in_beam.name = "InBeam_" + channel
		in_beam.points = PackedVector2Array(
			[Vector2(108.0, 90.0), Vector2(296.0, 150.0 + float(index - 1) * 16.0)]
		)
		in_beam.width = 5.0
		in_beam.default_color = _channel_color(channel, 0.45)
		pigment_stage.add_child(in_beam)
		pigment_in_beams[channel] = in_beam

	pigment_specimen = Polygon2D.new()
	pigment_specimen.name = "Specimen"
	pigment_specimen.polygon = _circle_points(58.0, 40)
	pigment_specimen.position = Vector2(352.0, 150.0)
	pigment_specimen.color = Color(0.30, 0.62, 0.26, 1.0)
	pigment_stage.add_child(pigment_specimen)
	var specimen_ring := Line2D.new()
	specimen_ring.points = _circle_points(60.0, 40)
	specimen_ring.position = Vector2(352.0, 150.0)
	specimen_ring.closed = true
	specimen_ring.width = 2.0
	specimen_ring.default_color = Color(0.72, 0.60, 0.34, 0.86)
	pigment_stage.add_child(specimen_ring)
	pigment_specimen_label = _make_label(
		"SpecimenLabel", Vector2(252.0, 218.0), Vector2(200.0, 22.0), 13, COLOR_PARCHMENT
	)
	pigment_specimen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pigment_stage.add_child(pigment_specimen_label)

	for index: int in range(CHANNELS.size()):
		var channel := str(CHANNELS[index])
		var out_beam := Line2D.new()
		out_beam.name = "OutBeam_" + channel
		out_beam.points = PackedVector2Array(
			[Vector2(412.0, 150.0 + float(index - 1) * 16.0), Vector2(626.0, 150.0)]
		)
		out_beam.set_meta("beam_start", out_beam.points[0])
		out_beam.set_meta("beam_end", out_beam.points[1])
		out_beam.width = 5.0
		out_beam.default_color = _channel_color(channel, 0.95)
		out_beam.visible = false
		pigment_stage.add_child(out_beam)
		pigment_out_beams[channel] = out_beam

	_build_observer_scanner()
	var eye_label := _make_label(
		"ObserverLabel", Vector2(586.0, 202.0), Vector2(148.0, 18.0), 10, Color(0.58, 0.88, 0.98, 1.0)
	)
	eye_label.text = _text("OPTICAL OBSERVER", "光学观察器")
	eye_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pigment_stage.add_child(eye_label)

	var swatch_frame := Panel.new()
	swatch_frame.position = Vector2(724.0, 96.0)
	swatch_frame.size = Vector2(96.0, 96.0)
	swatch_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.05, 0.04, 0.07, 1.0), Color(0.62, 0.46, 0.22, 0.94), 2, 6)
	)
	pigment_stage.add_child(swatch_frame)
	pigment_swatch = ColorRect.new()
	pigment_swatch.name = "PerceivedSwatch"
	pigment_swatch.position = Vector2(8.0, 8.0)
	pigment_swatch.size = Vector2(80.0, 80.0)
	pigment_swatch.color = Color(0.0, 0.0, 0.0, 1.0)
	pigment_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch_frame.add_child(pigment_swatch)
	pigment_perceived_label = _make_label(
		"PerceivedLabel", Vector2(676.0, 198.0), Vector2(160.0, 34.0), 10, Color(0.84, 0.76, 0.60, 1.0)
	)
	pigment_perceived_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pigment_perceived_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pigment_stage.add_child(pigment_perceived_label)


func _build_observer_scanner() -> void:
	observer_scanner = Node2D.new()
	observer_scanner.name = "AshfordOpticalObserver"
	observer_scanner.position = Vector2(660.0, 150.0)
	pigment_stage.add_child(observer_scanner)

	var housing_shadow := Polygon2D.new()
	housing_shadow.name = "ObserverHousingShadow"
	housing_shadow.position = Vector2(3.0, 5.0)
	housing_shadow.polygon = _hex_points(48.0, 34.0)
	housing_shadow.color = Color(0.0, 0.0, 0.0, 0.58)
	observer_scanner.add_child(housing_shadow)

	var housing := Polygon2D.new()
	housing.name = "ObserverBrassHousing"
	housing.polygon = _hex_points(48.0, 34.0)
	housing.color = Color(0.37, 0.25, 0.11, 1.0)
	observer_scanner.add_child(housing)

	var housing_inlay := Polygon2D.new()
	housing_inlay.name = "ObserverVoidInlay"
	housing_inlay.polygon = _hex_points(40.0, 28.0)
	housing_inlay.color = Color(0.025, 0.035, 0.060, 1.0)
	observer_scanner.add_child(housing_inlay)

	observer_outer_ring = Line2D.new()
	observer_outer_ring.name = "ObserverOuterScannerRing"
	observer_outer_ring.points = _circle_points(37.0, 64)
	observer_outer_ring.closed = true
	observer_outer_ring.width = 2.2
	observer_outer_ring.default_color = Color(0.34, 0.78, 0.96, 0.88)
	observer_scanner.add_child(observer_outer_ring)
	for tick_index: int in range(8):
		var tick := Line2D.new()
		tick.name = "ObserverTick%d" % tick_index
		var angle := TAU * float(tick_index) / 8.0
		tick.points = PackedVector2Array(
			[
				Vector2.from_angle(angle) * 31.0,
				Vector2.from_angle(angle) * (38.0 if tick_index % 2 == 0 else 35.0),
			]
		)
		tick.width = 2.0
		tick.default_color = Color(0.78, 0.63, 0.30, 0.90)
		observer_outer_ring.add_child(tick)

	observer_inner_ring = Line2D.new()
	observer_inner_ring.name = "ObserverIrisRing"
	observer_inner_ring.points = _circle_points(25.0, 48)
	observer_inner_ring.closed = true
	observer_inner_ring.width = 1.8
	observer_inner_ring.default_color = Color(0.70, 0.50, 0.94, 0.84)
	observer_scanner.add_child(observer_inner_ring)

	observer_iris = Polygon2D.new()
	observer_iris.name = "ObserverIrisGlow"
	observer_iris.polygon = _circle_points(21.0, 40)
	observer_iris.color = Color(0.16, 0.62, 0.82, 0.58)
	observer_scanner.add_child(observer_iris)

	for blade_index: int in range(6):
		var blade := Polygon2D.new()
		blade.name = "ObserverApertureBlade%d" % blade_index
		blade.polygon = PackedVector2Array(
			[Vector2(5.0, -3.0), Vector2(19.0, -10.0), Vector2(16.0, 2.0), Vector2(6.0, 6.0)]
		)
		blade.rotation = float(blade_index) * TAU / 6.0
		blade.color = Color(0.72, 0.76, 0.82, 0.30)
		observer_scanner.add_child(blade)
		observer_aperture_blades.append(blade)

	observer_pupil = Polygon2D.new()
	observer_pupil.name = "ObserverSensorCore"
	observer_pupil.polygon = _circle_points(8.0, 24)
	observer_pupil.color = Color(0.02, 0.055, 0.095, 1.0)
	observer_scanner.add_child(observer_pupil)
	var pupil_core := Polygon2D.new()
	pupil_core.name = "ObserverCoreLight"
	pupil_core.polygon = _circle_points(3.2, 18)
	pupil_core.color = Color(0.68, 0.94, 1.0, 1.0)
	observer_pupil.add_child(pupil_core)

	observer_scan_beam = Line2D.new()
	observer_scan_beam.name = "ObserverScanBeam"
	observer_scan_beam.points = PackedVector2Array([Vector2.ZERO, Vector2(33.0, 0.0)])
	observer_scan_beam.width = 1.2
	observer_scan_beam.default_color = Color(0.55, 0.92, 1.0, 0.72)
	observer_scanner.add_child(observer_scan_beam)


func _build_mixer_stage() -> void:
	mixer_stage = Control.new()
	mixer_stage.name = "MixerStage"
	mixer_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mixer_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apparatus.add_child(mixer_stage)
	mixer_reticle = _build_precision_reticle(
		mixer_stage, Vector2(328.0, 148.0), 116.0, Color(0.68, 0.52, 0.92, 0.40)
	)

	var centres := {
		"red": Vector2(268.0, 104.0),
		"green": Vector2(388.0, 104.0),
		"blue": Vector2(328.0, 192.0),
	}
	mixer_emitter_positions = {
		"red": Vector2(94.0, 70.0),
		"green": Vector2(94.0, 148.0),
		"blue": Vector2(94.0, 226.0),
	}
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		var emitter_position := mixer_emitter_positions[channel] as Vector2
		var feed := Line2D.new()
		feed.name = "EmitterFeed_" + channel
		feed.points = PackedVector2Array([emitter_position, emitter_position])
		feed.width = 4.0
		feed.default_color = _channel_color(channel, 0.0)
		feed.visible = false
		mixer_stage.add_child(feed)
		mixer_feed_beams[channel] = feed

		var emitter := Node2D.new()
		emitter.name = "OpticalEmitter_" + channel
		emitter.position = emitter_position
		mixer_stage.add_child(emitter)
		mixer_emitters[channel] = emitter
		var emitter_frame := Polygon2D.new()
		emitter_frame.polygon = _hex_points(33.0, 23.0)
		emitter_frame.color = Color(0.42, 0.30, 0.14, 1.0)
		emitter.add_child(emitter_frame)
		var emitter_inlay := Polygon2D.new()
		emitter_inlay.polygon = _hex_points(27.0, 18.0)
		emitter_inlay.color = Color(0.035, 0.030, 0.055, 1.0)
		emitter.add_child(emitter_inlay)
		var emitter_core := Polygon2D.new()
		emitter_core.name = "EmitterCore"
		emitter_core.polygon = _circle_points(9.0, 24)
		emitter_core.color = _channel_color(channel, 0.24)
		emitter.add_child(emitter_core)
		var emitter_label := _make_label(
			"EmitterLabel_" + channel,
			emitter_position + Vector2(-28.0, 28.0),
			Vector2(56.0, 16.0),
			9,
			_channel_color(channel, 0.82)
		)
		emitter_label.text = _text(channel.to_upper(), str(BAND_NAMES_ZH[channel]))
		emitter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mixer_stage.add_child(emitter_label)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for channel_variant: Variant in CHANNELS:
		var channel := str(channel_variant)
		var disc := Polygon2D.new()
		disc.name = "MixDisc_" + channel
		disc.polygon = _circle_points(76.0, 48)
		disc.position = centres[channel] as Vector2
		disc.color = _channel_color(channel, 1.0)
		disc.material = additive
		disc.visible = false
		mixer_stage.add_child(disc)
		mixer_discs[channel] = disc

	var stage_label_node := _make_label(
		"MixerStageLabel", Vector2(150.0, 276.0), Vector2(360.0, 20.0), 10, Color(0.78, 0.70, 0.56, 1.0)
	)
	stage_label_node.text = _text(
		"OVERLAPPING BEAMS ADD THEIR LIGHT", "重叠光束会把光相加"
	)
	stage_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mixer_stage.add_child(stage_label_node)

	var mix_frame := Panel.new()
	mix_frame.position = Vector2(560.0, 60.0)
	mix_frame.size = Vector2(116.0, 116.0)
	mix_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.05, 0.04, 0.07, 1.0), Color(0.55, 0.44, 0.72, 0.94), 2, 6)
	)
	mixer_stage.add_child(mix_frame)
	mixer_mix_swatch = ColorRect.new()
	mixer_mix_swatch.name = "MixSwatch"
	mixer_mix_swatch.position = Vector2(8.0, 8.0)
	mixer_mix_swatch.size = Vector2(100.0, 100.0)
	mixer_mix_swatch.color = Color(0.0, 0.0, 0.0, 1.0)
	mixer_mix_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mix_frame.add_child(mixer_mix_swatch)
	var mix_caption := _make_label(
		"MixCaption", Vector2(560.0, 180.0), Vector2(116.0, 18.0), 10, Color(0.82, 0.74, 0.58, 1.0)
	)
	mix_caption.text = _text("YOUR MIX", "当前混合")
	mix_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mixer_stage.add_child(mix_caption)

	var target_frame := Panel.new()
	target_frame.position = Vector2(700.0, 60.0)
	target_frame.size = Vector2(116.0, 116.0)
	target_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.05, 0.04, 0.07, 1.0), Color(0.72, 0.55, 0.24, 0.96), 2, 6)
	)
	mixer_stage.add_child(target_frame)
	mixer_target_swatch = ColorRect.new()
	mixer_target_swatch.name = "TargetSwatch"
	mixer_target_swatch.position = Vector2(8.0, 8.0)
	mixer_target_swatch.size = Vector2(100.0, 100.0)
	mixer_target_swatch.color = Color(0.0, 0.0, 0.0, 1.0)
	mixer_target_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.add_child(mixer_target_swatch)
	mixer_target_label = _make_label(
		"TargetCaption", Vector2(686.0, 180.0), Vector2(144.0, 18.0), 10, COLOR_GOLD
	)
	mixer_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mixer_stage.add_child(mixer_target_label)

	var match_track := ColorRect.new()
	match_track.position = Vector2(560.0, 216.0)
	match_track.size = Vector2(220.0, 10.0)
	match_track.color = Color(0.14, 0.12, 0.18, 1.0)
	mixer_stage.add_child(match_track)
	mixer_match_fill = ColorRect.new()
	mixer_match_fill.name = "MatchFill"
	mixer_match_fill.position = Vector2(560.0, 216.0)
	mixer_match_fill.size = Vector2(3.0, 10.0)
	mixer_match_fill.color = COLOR_VIOLET
	mixer_stage.add_child(mixer_match_fill)
	mixer_match_label = _make_label(
		"MatchLabel", Vector2(560.0, 230.0), Vector2(220.0, 18.0), 10, Color(0.82, 0.74, 0.58, 1.0)
	)
	mixer_match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mixer_stage.add_child(mixer_match_label)


func _build_deck() -> void:
	deck = Panel.new()
	deck.name = "ControlDeck"
	deck.position = Vector2(28.0, 412.0)
	deck.size = DECK_SIZE
	deck.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.075, 0.052, 0.030, 0.97), Color(0.58, 0.42, 0.19, 0.90), 2, 9)
	)
	frame.add_child(deck)
	_build_prism_tray()
	_build_pigment_deck()
	_build_mixer_deck()


func _build_prism_tray() -> void:
	prism_tray = Control.new()
	prism_tray.name = "PrismTray"
	prism_tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck.add_child(prism_tray)
	for index: int in range(7):
		var button := Button.new()
		button.name = "PrismCrystal%d" % index
		button.position = Vector2(0.0, 18.0)
		button.size = Vector2(96.0, 64.0)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_tray_slot_pressed.bind(index))
		prism_tray.add_child(button)
		prism_tray_buttons.append(button)
	var caption := _make_label(
		"TrayCaption", Vector2(20.0, 96.0), Vector2(804.0, 40.0), 11, Color(0.82, 0.74, 0.58, 1.0)
	)
	caption.text = _text(
		"Seat each crystal into the rail, longest wavelength first.",
		"按波长从长到短，把晶体依次放入导轨。"
	)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prism_tray.add_child(caption)


func _build_pigment_deck() -> void:
	pigment_deck = Control.new()
	pigment_deck.name = "PigmentDeck"
	pigment_deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck.add_child(pigment_deck)
	for index: int in range(CHANNELS.size()):
		var channel := str(CHANNELS[index])
		var row_y := 14.0 + float(index) * 46.0
		var channel_label := _make_label(
			"PigmentChannel_" + channel,
			Vector2(22.0, row_y),
			Vector2(168.0, 36.0),
			14,
			_channel_color(channel, 1.0)
		)
		channel_label.text = _text("%s LIGHT" % channel.to_upper(), "%s光" % str(BAND_NAMES_ZH[channel]))
		channel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pigment_deck.add_child(channel_label)

		var reflect_button := Button.new()
		reflect_button.name = "Reflect_" + channel
		reflect_button.text = _text("REFLECT", "反射")
		reflect_button.position = Vector2(200.0, row_y)
		reflect_button.size = Vector2(150.0, 36.0)
		reflect_button.add_theme_font_size_override("font_size", 12)
		reflect_button.pressed.connect(set_reflection_response.bind(channel, "reflect"))
		pigment_deck.add_child(reflect_button)
		pigment_reflect_buttons[channel] = reflect_button

		var absorb_button := Button.new()
		absorb_button.name = "Absorb_" + channel
		absorb_button.text = _text("ABSORB", "吸收")
		absorb_button.position = Vector2(362.0, row_y)
		absorb_button.size = Vector2(150.0, 36.0)
		absorb_button.add_theme_font_size_override("font_size", 12)
		absorb_button.pressed.connect(set_reflection_response.bind(channel, "absorb"))
		pigment_deck.add_child(absorb_button)
		pigment_absorb_buttons[channel] = absorb_button

		var note := _make_label(
			"PigmentNote_" + channel,
			Vector2(530.0, row_y),
			Vector2(292.0, 36.0),
			11,
			Color(0.78, 0.71, 0.58, 1.0)
		)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pigment_deck.add_child(note)
		pigment_notes[channel] = note


func _build_mixer_deck() -> void:
	mixer_deck = Control.new()
	mixer_deck.name = "MixerDeck"
	mixer_deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck.add_child(mixer_deck)
	for index: int in range(CHANNELS.size()):
		var channel := str(CHANNELS[index])
		var row_y := 14.0 + float(index) * 46.0
		var channel_label := _make_label(
			"MixerChannel_" + channel,
			Vector2(22.0, row_y),
			Vector2(150.0, 36.0),
			14,
			_channel_color(channel, 1.0)
		)
		channel_label.text = _text("%s LAMP" % channel.to_upper(), "%s灯" % str(BAND_NAMES_ZH[channel]))
		channel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mixer_deck.add_child(channel_label)
		for level_option: int in range(3):
			var button := Button.new()
			button.name = "MixerLevel_%s_%d" % [channel, level_option]
			button.text = _text(str(LEVEL_LABELS_EN[level_option]), str(LEVEL_LABELS_ZH[level_option]))
			button.position = Vector2(184.0 + float(level_option) * 118.0, row_y)
			button.size = Vector2(110.0, 36.0)
			button.add_theme_font_size_override("font_size", 12)
			button.pressed.connect(set_mixer_level.bind(channel, level_option))
			mixer_deck.add_child(button)
			mixer_level_buttons["%s_%d" % [channel, level_option]] = button
		var readout := _make_label(
			"MixerReadout_" + channel,
			Vector2(552.0, row_y),
			Vector2(270.0, 36.0),
			11,
			Color(0.78, 0.71, 0.58, 1.0)
		)
		readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mixer_deck.add_child(readout)
		mixer_readouts[channel] = readout


func _build_footer() -> void:
	reference_label = _make_label(
		"FiledReference", Vector2(30.0, 574.0), Vector2(840.0, 18.0), 10, Color(0.66, 0.58, 0.46, 1.0)
	)
	frame.add_child(reference_label)
	status_label = _make_label(
		"LabStatus", Vector2(30.0, 592.0), Vector2(840.0, 20.0), 12, COLOR_PARCHMENT
	)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(status_label)

	hint_button = Button.new()
	hint_button.name = "HintButton"
	hint_button.position = Vector2(30.0, 614.0)
	hint_button.size = Vector2(150.0, 34.0)
	hint_button.add_theme_font_size_override("font_size", 12)
	_style_button(hint_button, Color(0.36, 0.30, 0.16, 1.0))
	hint_button.pressed.connect(request_hint)
	frame.add_child(hint_button)

	reset_button = Button.new()
	reset_button.name = "ResetStageButton"
	reset_button.position = Vector2(192.0, 614.0)
	reset_button.size = Vector2(150.0, 34.0)
	reset_button.add_theme_font_size_override("font_size", 12)
	_style_button(reset_button, Color(0.44, 0.31, 0.16, 1.0))
	reset_button.pressed.connect(reset_current_stage)
	frame.add_child(reset_button)

	submit_button = Button.new()
	submit_button.name = "RunApparatusButton"
	submit_button.position = Vector2(686.0, 614.0)
	submit_button.size = Vector2(184.0, 34.0)
	submit_button.add_theme_font_size_override("font_size", 12)
	_style_button(submit_button, Color(0.45, 0.28, 0.66, 1.0))
	submit_button.pressed.connect(submit_current_challenge)
	frame.add_child(submit_button)

	reward_badge = Panel.new()
	reward_badge.name = "RecoveredFilterBadge"
	reward_badge.position = Vector2(354.0, 612.0)
	reward_badge.size = Vector2(300.0, 38.0)
	reward_badge.visible = false
	reward_badge.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.07, 0.15, 0.08, 0.99), Color(0.52, 0.84, 0.44, 0.97), 2, 7)
	)
	frame.add_child(reward_badge)
	reward_label = _make_label(
		"RecoveredFilterLabel", Vector2(8.0, 4.0), Vector2(284.0, 30.0), 11, COLOR_SUCCESS
	)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_badge.add_child(reward_label)

	close_button = Button.new()
	close_button.name = "CloseLightLabButton"
	close_button.text = "×"
	close_button.position = Vector2(848.0, 12.0)
	close_button.size = Vector2(40.0, 40.0)
	close_button.add_theme_font_size_override("font_size", 22)
	_style_button(close_button, Color(0.52, 0.34, 0.14, 1.0))
	close_button.pressed.connect(close)
	frame.add_child(close_button)


# ------------------------------------------------------------------ helpers


func _layout_prism_sockets(count: int) -> void:
	if count <= 0:
		return
	var total := float(count) * 78.0 + float(count - 1) * 8.0
	var start := (APPARATUS_SIZE.x - total) * 0.5
	for index: int in range(count):
		var x := start + float(index) * 86.0
		(prism_sockets[index] as Panel).position = Vector2(x, 148.0)
		(prism_socket_labels[index] as Label).position = Vector2(x, 152.0)


func _layout_prism_tray(count: int) -> void:
	if count <= 0:
		return
	var total := float(count) * 96.0 + float(count - 1) * 8.0
	var start := (DECK_SIZE.x - total) * 0.5
	for index: int in range(count):
		(prism_tray_buttons[index] as Button).position = Vector2(
			start + float(index) * 104.0, 18.0
		)


func _on_tray_slot_pressed(slot: int) -> void:
	var stage := _current_stage()
	if stage.is_empty() or challenge_id != "red":
		return
	var tray: Array = stage["tray"] as Array
	if slot < 0 or slot >= tray.size():
		return
	choose_spectrum_token(str(tray[slot]))


func _band_label(band: String) -> String:
	return _text(band.to_upper(), str(BAND_NAMES_ZH[band]))


func _channel_color(channel: String, alpha: float) -> Color:
	var base: Color = BAND_COLORS[channel] as Color
	return Color(base.r, base.g, base.b, alpha)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _hex_points(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(0.0, -height),
			Vector2(width, -height * 0.48),
			Vector2(width, height * 0.48),
			Vector2(0.0, height),
			Vector2(-width, height * 0.48),
			Vector2(-width, -height * 0.48),
		]
	)


func _build_precision_reticle(
	parent: Node, center: Vector2, radius: float, colour: Color
) -> Node2D:
	var root := Node2D.new()
	root.name = "PrecisionReticle"
	root.position = center
	parent.add_child(root)
	for quadrant: int in range(4):
		var arc := Line2D.new()
		arc.name = "ReticleArc%d" % quadrant
		var start := float(quadrant) * PI * 0.5 + 0.20
		var finish := start + PI * 0.5 - 0.40
		var points := PackedVector2Array()
		for step: int in range(13):
			var ratio := float(step) / 12.0
			var angle := lerpf(start, finish, ratio)
			points.append(Vector2.from_angle(angle) * radius)
		arc.points = points
		arc.width = 1.6
		arc.default_color = colour
		root.add_child(arc)
		var tick := Line2D.new()
		tick.name = "ReticleTick%d" % quadrant
		var tick_angle := float(quadrant) * PI * 0.5
		tick.points = PackedVector2Array(
			[
				Vector2.from_angle(tick_angle) * (radius - 8.0),
				Vector2.from_angle(tick_angle) * (radius + 8.0),
			]
		)
		tick.width = 2.0
		tick.default_color = colour.lightened(0.18)
		root.add_child(tick)
	return root


func _make_label(
	node_name: String, at: Vector2, of_size: Vector2, font_size: int, colour: Color
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = of_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.03, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(
	fill: Color, border: Color, border_width: int, radius: int, shadow: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if shadow > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0.0, 5.0)
	return style


func _style_button(button: Button, accent: Color) -> void:
	var normal := _panel_style(accent * Color(0.55, 0.55, 0.55, 1.0), accent, 2, 5)
	normal.bg_color.a = 1.0
	var hover := _panel_style(accent * Color(0.78, 0.78, 0.78, 1.0), accent.lightened(0.24), 2, 5)
	hover.bg_color.a = 1.0
	var pressed := _panel_style(accent * Color(0.40, 0.40, 0.40, 1.0), accent, 2, 5)
	pressed.bg_color.a = 1.0
	var disabled := _panel_style(
		Color(0.10, 0.09, 0.12, 1.0), Color(0.30, 0.27, 0.24, 0.85), 2, 5
	)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.51, 0.46, 1.0))
	_wire_button_motion(button)


func _wire_button_motion(button: Button) -> void:
	if bool(button.get_meta("lab_motion_wired", false)):
		return
	button.set_meta("lab_motion_wired", true)
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	button.focus_entered.connect(_on_button_hover.bind(button, true))
	button.focus_exited.connect(_on_button_hover.bind(button, false))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_hover(button: Button, hovering: bool) -> void:
	if button == null or button.disabled:
		return
	var target := Vector2(1.035, 1.035) if hovering else Vector2.ONE
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, 0.10)


func _on_button_down(button: Button) -> void:
	if button == null or button.disabled:
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.965, 0.965), 0.055)


func _on_button_up(button: Button) -> void:
	if button == null or button.disabled:
		return
	_pop_control(button, 1.045)


func _focus_first_control() -> void:
	if not visible:
		return
	if submit_button != null:
		submit_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		submit_current_challenge()
		get_viewport().set_input_as_handled()


func _text(english: String, chinese: String) -> String:
	var locale := get_node_or_null("/root/CaseLocale")
	return chinese if locale != null and bool(locale.call("is_chinese")) else english
