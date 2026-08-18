class_name LibraryLightChallengeUI
extends CanvasLayer

signal completed(challenge_id: String)
signal closed

const BLUE_TARGETS: Array[Dictionary] = [
	{"name_en": "CYAN", "name_zh": "青光", "channels": ["green", "blue"]},
	{"name_en": "MAGENTA", "name_zh": "品红光", "channels": ["red", "blue"]},
	{"name_en": "WHITE", "name_zh": "白光", "channels": ["red", "green", "blue"]},
]
const CHANNEL_COLORS: Dictionary = {
	"red": Color(0.62, 0.20, 0.17, 1.0),
	"green": Color(0.20, 0.52, 0.28, 1.0),
	"blue": Color(0.20, 0.34, 0.65, 1.0),
}

var challenge_id := ""
var knowledge_reference_only := true
var red_sequence: Array[String] = []
var green_responses: Dictionary = {"red": "unknown", "green": "unknown", "blue": "unknown"}
var blue_channels: Array[String] = []
var blue_round := 0
var challenge_completed := false
var root_control: Control
var frame: Panel
var title_label: Label
var subtitle_label: Label
var concept_label: Label
var instruction_label: Label
var challenge_area: Control
var red_group: Control
var red_sequence_label: Label
var red_token_buttons: Dictionary = {}
var green_group: Control
var green_response_buttons: Dictionary = {}
var blue_group: Control
var blue_target_label: Label
var blue_preview: ColorRect
var blue_channel_buttons: Dictionary = {}
var status_label: Label
var progress_label: Label
var reward_badge: Panel
var reward_badge_label: Label
var submit_button: Button
var reset_button: Button
var close_button: Button


func _ready() -> void:
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	visible = false
	root_control.visible = false


func open_challenge(next_challenge_id: String) -> void:
	challenge_id = next_challenge_id
	challenge_completed = false
	_reset_state()
	_refresh_copy()
	_refresh_controls()
	visible = true
	root_control.visible = true
	root_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	frame.scale = Vector2(0.97, 0.97)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, 0.22)
	call_deferred("_focus_first_control")


func close() -> void:
	if not visible:
		return
	visible = false
	root_control.visible = false
	closed.emit()


func choose_spectrum_token(channel: String) -> void:
	if challenge_id != "red" or challenge_completed or red_sequence.has(channel):
		return
	red_sequence.append(channel)
	status_label.text = _text("Sequence recorded. Submit when all three slots are filled.", "顺序已记录。填满三个槽位后提交。")
	_refresh_red_controls()


func set_reflection_response(channel: String, response: String) -> void:
	if challenge_id != "green" or challenge_completed or not green_responses.has(channel):
		return
	if response not in ["unknown", "reflect", "absorb"]:
		return
	green_responses[channel] = response
	_refresh_green_controls()


func set_mixer_channels(channels: Array) -> void:
	if challenge_id != "blue" or challenge_completed:
		return
	blue_channels.clear()
	for channel_variant: Variant in channels:
		var channel := str(channel_variant)
		if CHANNEL_COLORS.has(channel) and not blue_channels.has(channel):
			blue_channels.append(channel)
	_refresh_blue_controls()


func submit_current_challenge() -> void:
	if challenge_completed:
		close()
		return
	match challenge_id:
		"red":
			_submit_red_sequence()
		"green":
			_submit_green_matrix()
		"blue":
			_submit_blue_mix()


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "LibraryLightChallengeRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var veil := ColorRect.new()
	veil.name = "ChallengeVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.006, 0.016, 0.93)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(veil)

	frame = Panel.new()
	frame.name = "ChallengeFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -430.0
	frame.offset_top = -310.0
	frame.offset_right = 430.0
	frame.offset_bottom = 310.0
	frame.pivot_offset = Vector2(430.0, 310.0)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", _frame_style())
	root_control.add_child(frame)

	title_label = _make_label("ChallengeTitle", Vector2(42.0, 24.0), Vector2(776.0, 40.0), 24, Color(0.96, 0.78, 0.38, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title_label)
	subtitle_label = _make_label("ChallengeSubtitle", Vector2(62.0, 65.0), Vector2(736.0, 24.0), 11, Color(0.70, 0.64, 0.52, 1.0))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(subtitle_label)

	var divider := ColorRect.new()
	divider.position = Vector2(46.0, 98.0)
	divider.size = Vector2(768.0, 2.0)
	divider.color = Color(0.62, 0.45, 0.20, 0.82)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(divider)

	var concept_panel := Panel.new()
	concept_panel.name = "ConceptCard"
	concept_panel.position = Vector2(46.0, 116.0)
	concept_panel.size = Vector2(248.0, 382.0)
	concept_panel.add_theme_stylebox_override("panel", _card_style(Color(0.10, 0.065, 0.035, 0.96), Color(0.57, 0.41, 0.18, 0.88)))
	frame.add_child(concept_panel)
	var concept_kicker := _make_label("ConceptKicker", Vector2(18.0, 16.0), Vector2(212.0, 22.0), 10, Color(0.91, 0.71, 0.34, 1.0))
	concept_kicker.text = _text("FILED REFERENCE", "已归档参考")
	concept_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	concept_panel.add_child(concept_kicker)
	concept_label = _make_label("ConceptText", Vector2(22.0, 50.0), Vector2(204.0, 294.0), 14, Color(0.90, 0.84, 0.70, 1.0))
	concept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	concept_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	concept_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	concept_panel.add_child(concept_label)

	var experiment_panel := Panel.new()
	experiment_panel.name = "ExperimentPanel"
	experiment_panel.position = Vector2(312.0, 116.0)
	experiment_panel.size = Vector2(502.0, 382.0)
	experiment_panel.add_theme_stylebox_override("panel", _card_style(Color(0.037, 0.030, 0.055, 0.98), Color(0.47, 0.34, 0.68, 0.86)))
	frame.add_child(experiment_panel)
	instruction_label = _make_label("Instruction", Vector2(24.0, 18.0), Vector2(454.0, 54.0), 14, Color(0.93, 0.86, 0.68, 1.0))
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	experiment_panel.add_child(instruction_label)
	challenge_area = Control.new()
	challenge_area.name = "ChallengeArea"
	challenge_area.position = Vector2(22.0, 82.0)
	challenge_area.size = Vector2(458.0, 276.0)
	experiment_panel.add_child(challenge_area)
	_build_red_group()
	_build_green_group()
	_build_blue_group()

	status_label = _make_label("ChallengeStatus", Vector2(50.0, 510.0), Vector2(610.0, 48.0), 12, Color(0.82, 0.74, 0.58, 1.0))
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(status_label)
	progress_label = _make_label("ChallengeProgress", Vector2(664.0, 510.0), Vector2(150.0, 48.0), 11, Color(0.72, 0.61, 0.88, 1.0))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(progress_label)
	reward_badge = Panel.new()
	reward_badge.name = "RecoveredFilterBadge"
	reward_badge.position = Vector2(306.0, 512.0)
	reward_badge.size = Vector2(248.0, 44.0)
	reward_badge.visible = false
	reward_badge.add_theme_stylebox_override("panel", _card_style(Color(0.08, 0.16, 0.09, 0.98), Color(0.50, 0.82, 0.42, 0.96)))
	frame.add_child(reward_badge)
	reward_badge_label = _make_label("RecoveredFilterLabel", Vector2(8.0, 5.0), Vector2(232.0, 34.0), 11, Color(0.74, 0.96, 0.64, 1.0))
	reward_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_badge.add_child(reward_badge_label)

	reset_button = Button.new()
	reset_button.name = "ResetChallengeButton"
	reset_button.text = _text("RESET", "重置")
	reset_button.position = Vector2(50.0, 568.0)
	reset_button.size = Vector2(132.0, 36.0)
	_apply_button_style(reset_button, Color(0.48, 0.34, 0.17, 1.0))
	reset_button.pressed.connect(_reset_current_challenge)
	frame.add_child(reset_button)
	submit_button = Button.new()
	submit_button.name = "SubmitChallengeButton"
	submit_button.position = Vector2(570.0, 568.0)
	submit_button.size = Vector2(178.0, 36.0)
	_apply_button_style(submit_button, Color(0.45, 0.28, 0.66, 1.0))
	submit_button.pressed.connect(submit_current_challenge)
	frame.add_child(submit_button)
	close_button = Button.new()
	close_button.name = "CloseLightChallengeButton"
	close_button.text = "×"
	close_button.position = Vector2(766.0, 22.0)
	close_button.size = Vector2(44.0, 44.0)
	_apply_button_style(close_button, Color(0.52, 0.34, 0.14, 1.0))
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(close)
	frame.add_child(close_button)


func _build_red_group() -> void:
	red_group = Control.new()
	red_group.name = "SpectrumSequencer"
	red_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_area.add_child(red_group)
	red_sequence_label = _make_label("SpectrumSlots", Vector2(25.0, 14.0), Vector2(408.0, 70.0), 20, Color(0.96, 0.80, 0.46, 1.0))
	red_sequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	red_sequence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	red_group.add_child(red_sequence_label)
	var channels: Array[String] = ["red", "green", "blue"]
	for index: int in range(channels.size()):
		var channel := channels[index]
		var button := Button.new()
		button.name = "SpectrumToken_" + channel
		button.text = channel.to_upper()
		button.position = Vector2(40.0 + float(index) * 132.0, 108.0)
		button.size = Vector2(112.0, 72.0)
		_apply_button_style(button, CHANNEL_COLORS[channel] as Color)
		button.pressed.connect(choose_spectrum_token.bind(channel))
		red_group.add_child(button)
		red_token_buttons[channel] = button


func _build_green_group() -> void:
	green_group = Control.new()
	green_group.name = "ReflectionMatrix"
	green_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_area.add_child(green_group)
	var channels: Array[String] = ["red", "green", "blue"]
	for index: int in range(channels.size()):
		var channel: String = channels[index]
		var channel_label := _make_label("ReflectionChannel_" + channel, Vector2(34.0, 22.0 + float(index) * 72.0), Vector2(110.0, 48.0), 14, CHANNEL_COLORS[channel] as Color)
		channel_label.text = channel.to_upper() + " LIGHT"
		channel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		green_group.add_child(channel_label)
		var response := Button.new()
		response.name = "ReflectionResponse_" + channel
		response.position = Vector2(170.0, 26.0 + float(index) * 72.0)
		response.size = Vector2(246.0, 42.0)
		_apply_button_style(response, Color(0.38, 0.31, 0.20, 1.0))
		response.pressed.connect(_cycle_reflection_response.bind(channel))
		green_group.add_child(response)
		green_response_buttons[channel] = response


func _build_blue_group() -> void:
	blue_group = Control.new()
	blue_group.name = "AdditiveRelay"
	blue_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_area.add_child(blue_group)
	blue_target_label = _make_label("MixerTarget", Vector2(18.0, 4.0), Vector2(422.0, 44.0), 16, Color(0.88, 0.78, 1.0, 1.0))
	blue_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blue_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blue_group.add_child(blue_target_label)
	blue_preview = ColorRect.new()
	blue_preview.name = "MixerPreview"
	blue_preview.position = Vector2(174.0, 58.0)
	blue_preview.size = Vector2(110.0, 68.0)
	blue_preview.color = Color(0.035, 0.028, 0.048, 1.0)
	blue_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blue_group.add_child(blue_preview)
	var channels: Array[String] = ["red", "green", "blue"]
	for index: int in range(channels.size()):
		var channel: String = channels[index]
		var button := Button.new()
		button.name = "MixerChannel_" + channel
		button.text = channel.to_upper()
		button.position = Vector2(42.0 + float(index) * 132.0, 156.0)
		button.size = Vector2(112.0, 54.0)
		_apply_button_style(button, CHANNEL_COLORS[channel] as Color)
		button.pressed.connect(_toggle_mixer_channel.bind(channel))
		blue_group.add_child(button)
		blue_channel_buttons[channel] = button


func _reset_state() -> void:
	red_sequence.clear()
	green_responses = {"red": "unknown", "green": "unknown", "blue": "unknown"}
	blue_channels.clear()
	blue_round = 0
	status_label.text = _text("Study the knowledge card, then operate the apparatus.", "阅读知识档案，然后操作装置。")
	status_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.58, 1.0))
	if reward_badge != null:
		reward_badge.visible = false


func _reset_current_challenge() -> void:
	if challenge_completed:
		return
	match challenge_id:
		"red":
			red_sequence.clear()
		"green":
			green_responses = {"red": "unknown", "green": "unknown", "blue": "unknown"}
		"blue":
			blue_channels.clear()
	status_label.text = _text("Apparatus reset. No progress was lost.", "装置已重置，进度没有损失。")
	_refresh_controls()


func _submit_red_sequence() -> void:
	if red_sequence == ["red", "green", "blue"]:
		_complete_challenge(_text("Spectrum aligned: red has the longest wavelength here; blue the shortest.", "光谱已对齐：红光波长最长，蓝光最短。"))
		return
	red_sequence.clear()
	status_label.text = _text("Not aligned. Recall: visible-light wavelength decreases from warm red toward cool blue.", "尚未对齐。提示：可见光波长从暖红向冷蓝逐渐变短。")
	_refresh_red_controls()


func _submit_green_matrix() -> void:
	var correct := (
		str(green_responses["red"]) == "absorb"
		and str(green_responses["green"]) == "reflect"
		and str(green_responses["blue"]) == "absorb"
	)
	if correct:
		_complete_challenge(_text("Reflection model verified: reflected green reaches the eye; red and blue are mostly absorbed.", "反射模型验证完成：绿色光被反射进入眼睛，红光和蓝光大多被吸收。"))
		return
	status_label.text = _text("The model does not explain a green leaf. An object's visible color is the light it reflects, not the light it absorbs.", "该模型无法解释绿色叶片。物体呈现的颜色来自它反射的光，而不是吸收的光。")


func _submit_blue_mix() -> void:
	var target := BLUE_TARGETS[blue_round]
	var expected: Array = target["channels"] as Array
	if not _same_channels(blue_channels, expected):
		status_label.text = _text("Additive mix mismatch. Light colors add energy: combine only the emitters needed for the target.", "加色混合不匹配。光色会叠加能量：只开启目标颜色所需的发光通道。")
		return
	blue_round += 1
	blue_channels.clear()
	if blue_round >= BLUE_TARGETS.size():
		_complete_challenge(_text("Relay calibrated: cyan, magenta, then white confirm additive RGB mixing.", "继电器校准完成：青、品红、白光验证了 RGB 加色混合。"))
		return
	status_label.text = _text("Target matched. The relay advances to the next additive mixture.", "目标匹配。继电器进入下一组加色混合。")
	_refresh_blue_controls()


func _complete_challenge(message: String) -> void:
	if challenge_completed:
		return
	challenge_completed = true
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(0.62, 0.90, 0.55, 1.0))
	submit_button.text = _text("RETURN WITH FILTER", "携带滤镜返回")
	reset_button.disabled = true
	reward_badge.visible = true
	reward_badge_label.text = _text(
		"%s FILTER RECOVERED" % challenge_id.to_upper(),
		"已回收%s滤镜" % ("红色" if challenge_id == "red" else "绿色" if challenge_id == "green" else "蓝色")
	)
	completed.emit(challenge_id)
	_refresh_controls()


func _cycle_reflection_response(channel: String) -> void:
	var current := str(green_responses.get(channel, "unknown"))
	var next := "reflect" if current == "unknown" else "absorb" if current == "reflect" else "unknown"
	set_reflection_response(channel, next)


func _toggle_mixer_channel(channel: String) -> void:
	if blue_channels.has(channel):
		blue_channels.erase(channel)
	else:
		blue_channels.append(channel)
	_refresh_blue_controls()


func _refresh_copy() -> void:
	match challenge_id:
		"red":
			title_label.text = _text("SPECTRUM SEQUENCER", "光谱排序器")
			subtitle_label.text = _text("RESEARCH DESK  ·  RECOVER THE CRIMSON FILTER", "研究桌 · 回收绯红滤镜")
			concept_label.text = _text("Required file: VISIBLE SPECTRUM & WAVELENGTH, recovered from the upper wavelength shelf. Apply the filed record here; this terminal does not display its solution.", "所需档案：从上层波长书架取得的《可见光谱与波长》。请在此应用已归档知识；本终端不会显示答案。")
			instruction_label.text = _text("Select RED, GREEN and BLUE from longest wavelength to shortest.", "按波长从长到短依次选择红、绿、蓝。")
		"green":
			title_label.text = _text("REFLECTION MATRIX", "反射矩阵")
			subtitle_label.text = _text("EAST WRITING DESK  ·  RECOVER THE VERDANT FILTER", "东侧写字桌 · 回收翠绿滤镜")
			concept_label.text = _text("Required file: REFLECTION, ABSORPTION & COLOR, recovered from the three-tier reflection shelf. Apply the filed record here; this terminal does not display its solution.", "所需档案：从三层反射书架取得的《反射、吸收与颜色》。请在此应用已归档知识；本终端不会显示答案。")
			instruction_label.text = _text("Model a green leaf. Set each channel to REFLECT or ABSORB.", "为绿色叶片建立模型。把每个光色设置为“反射”或“吸收”。")
		"blue":
			title_label.text = _text("ADDITIVE RELAY", "加色继电器")
			subtitle_label.text = _text("WEST GLOBE DESK  ·  RECOVER THE COBALT FILTER", "西侧地球仪桌 · 回收钴蓝滤镜")
			concept_label.text = _text("Required file: ADDITIVE COLOR MIXING, recovered from the reinforced light archive. Apply the filed record here; this terminal does not display its solution.", "所需档案：从加固光学档案架取得的《加色混合》。请在此应用已归档知识；本终端不会显示答案。")
			instruction_label.text = _text("Match three targets by switching the red, green and blue emitters.", "切换红、绿、蓝发光通道，依次匹配三个目标。")


func _refresh_controls() -> void:
	red_group.visible = challenge_id == "red"
	green_group.visible = challenge_id == "green"
	blue_group.visible = challenge_id == "blue"
	reset_button.disabled = challenge_completed
	if not challenge_completed:
		submit_button.text = _text("VERIFY", "验证")
	_refresh_red_controls()
	_refresh_green_controls()
	_refresh_blue_controls()
	progress_label.text = (
		_text("FILTER RECOVERED", "滤镜已回收")
		if challenge_completed
		else _text("CHALLENGE 1 / 1", "挑战 1 / 1") if challenge_id != "blue"
		else _text("TARGET %d / 3" % (blue_round + 1), "目标 %d / 3" % (blue_round + 1))
	)


func _refresh_red_controls() -> void:
	if red_sequence_label == null:
		return
	var slots: Array[String] = []
	for index: int in range(3):
		slots.append(red_sequence[index].to_upper() if index < red_sequence.size() else "—")
	red_sequence_label.text = "  →  ".join(slots)
	for channel: String in red_token_buttons:
		(red_token_buttons[channel] as Button).disabled = challenge_completed or red_sequence.has(channel)


func _refresh_green_controls() -> void:
	for channel: String in green_response_buttons:
		var button := green_response_buttons[channel] as Button
		var response := str(green_responses[channel])
		button.text = _text("?  CHOOSE", "?  选择") if response == "unknown" else _text("REFLECT", "反射") if response == "reflect" else _text("ABSORB", "吸收")
		button.disabled = challenge_completed
		button.self_modulate = Color(0.78, 1.02, 0.80, 1.0) if response == "reflect" else Color(0.78, 0.76, 0.84, 1.0) if response == "absorb" else Color.WHITE


func _refresh_blue_controls() -> void:
	if blue_target_label == null:
		return
	var target_index := mini(blue_round, BLUE_TARGETS.size() - 1)
	var target := BLUE_TARGETS[target_index]
	blue_target_label.text = _text("TARGET %d / 3  ·  %s" % [target_index + 1, target["name_en"]], "目标 %d / 3 · %s" % [target_index + 1, target["name_zh"]])
	for channel: String in blue_channel_buttons:
		var button := blue_channel_buttons[channel] as Button
		button.button_pressed = blue_channels.has(channel)
		button.self_modulate = Color(1.18, 1.12, 0.82, 1.0) if blue_channels.has(channel) else Color(0.68, 0.68, 0.72, 1.0)
		button.disabled = challenge_completed
	blue_preview.color = _mixed_light_color(blue_channels)


func _mixed_light_color(channels: Array[String]) -> Color:
	if channels.is_empty():
		return Color(0.035, 0.028, 0.048, 1.0)
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	if channels.has("red"):
		red = 0.92
	if channels.has("green"):
		green = 0.92
	if channels.has("blue"):
		blue = 0.92
	return Color(red, green, blue, 1.0)


func _same_channels(first: Array[String], second: Array) -> bool:
	if first.size() != second.size():
		return false
	for channel: Variant in second:
		if not first.has(str(channel)):
			return false
	return true


func _focus_first_control() -> void:
	match challenge_id:
		"red":
			(red_token_buttons["red"] as Button).grab_focus()
		"green":
			(green_response_buttons["red"] as Button).grab_focus()
		"blue":
			(blue_channel_buttons["red"] as Button).grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _make_label(name: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = name
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.012, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_button_style(button: Button, accent: Color) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _button_style(accent, true, false))
	button.add_theme_stylebox_override("focus", _button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _button_style(accent.darkened(0.45), false, false))


func _button_style(accent: Color, highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.96)
	if highlighted:
		style.bg_color = style.bg_color.lightened(0.14)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.16)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.96 if highlighted else 0.72)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(accent.r * 0.20, accent.g * 0.20, accent.b * 0.20, 0.35)
	style.shadow_size = 7 if highlighted else 3
	return style


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.015, 0.030, 0.99)
	style.border_color = Color(0.75, 0.56, 0.24, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0.0, 7.0)
	return style


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _text(english: String, chinese: String) -> String:
	var locale := get_node_or_null("/root/CaseLocale")
	return chinese if locale != null and bool(locale.call("is_chinese")) else english
