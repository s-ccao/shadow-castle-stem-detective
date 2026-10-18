extends CanvasLayer

signal answered(option_index: int)
signal enter_requested
signal closed

var root_control: Control
var frame: PanelContainer
var question_label: Label
var feedback: Label
var choices: GridContainer
var enter_button: Button
var close_button: Button
var solved := false
var question_data: Dictionary = {}


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.01, 0.025, 0.92)
	root_control.add_child(veil)
	frame = PanelContainer.new()
	frame.name = "DoorQuestionFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -432
	frame.offset_right = 432
	frame.offset_top = -270
	frame.offset_bottom = 270
	frame.add_theme_stylebox_override("panel", ArchiveUi.panel_style(Color("#19151f"), Color("#bd995c"), 2, 5, 4))
	root_control.add_child(frame)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var title := Label.new()
	title.name = "DoorQuestionTitle"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ArchiveUi.COLOR_GOLD)
	column.add_child(title)
	question_label = Label.new()
	question_label.name = "ChemistryLockQuestion"
	question_label.add_theme_font_size_override("font_size", 24)
	question_label.add_theme_color_override("font_color", ArchiveUi.COLOR_PARCHMENT)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.custom_minimum_size.y = 72
	column.add_child(question_label)
	choices = GridContainer.new()
	choices.name = "DoorAnswers"
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 14)
	choices.add_theme_constant_override("v_separation", 14)
	column.add_child(choices)
	feedback = Label.new()
	feedback.name = "DoorAnswerFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 17)
	feedback.custom_minimum_size.y = 64
	feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(feedback)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	close_button = Button.new()
	close_button.name = "LeaveDoorQuestionButton"
	close_button.custom_minimum_size = Vector2(180, 46)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_MUTED)
	close_button.pressed.connect(close)
	actions.add_child(close_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	enter_button = Button.new()
	enter_button.name = "EnterChemistryButton"
	enter_button.custom_minimum_size = Vector2(270, 46)
	ArchiveUi.apply_button(enter_button, ArchiveUi.ROLE_ACTION)
	enter_button.pressed.connect(func() -> void: enter_requested.emit())
	actions.add_child(enter_button)
	visible = false
	root_control.hide()


func open_question(data: Dictionary) -> void:
	question_data = data
	solved = false
	for old: Node in choices.get_children():
		choices.remove_child(old)
		old.queue_free()
	(root_control.find_child("DoorQuestionTitle", true, false) as Label).text = CaseLocale.text("door.chemistry_title")
	question_label.text = CaseLocale.line(str(data["question"]))
	feedback.text = CaseLocale.text("door.chemistry_hint")
	feedback.add_theme_color_override("font_color", ArchiveUi.COLOR_PARCHMENT)
	close_button.text = CaseLocale.text("door.leave")
	enter_button.text = CaseLocale.text("hall.chemistry_enter")
	enter_button.hide()
	var order: Array[int] = [0, 1, 2, 3]
	order.shuffle()
	var focusable: Array[Button] = []
	for index: int in order:
		var choice := Button.new()
		choice.name = "DoorAnswer%d" % index
		choice.set_meta("answer_index", index)
		choice.text = CaseLocale.line(str(data["options"][index]))
		choice.custom_minimum_size = Vector2(392, 76)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ArchiveUi.apply_button(choice, ArchiveUi.ROLE_ARCHIVE)
		choice.add_theme_font_size_override("font_size", 17)
		choice.pressed.connect(_submit.bind(index))
		choices.add_child(choice)
		focusable.append(choice)
	focusable.append(close_button)
	ArchiveUi.wire_focus_cycle(focusable)
	visible = true
	root_control.show()
	focusable[0].grab_focus.call_deferred()


func _submit(index: int) -> void:
	if not solved:
		answered.emit(index)


func show_result(correct: bool) -> void:
	solved = correct
	feedback.text = CaseLocale.text("door.correct" if correct else "door.chemistry_wrong")
	feedback.add_theme_color_override("font_color", ArchiveUi.COLOR_SUCCESS if correct else Color("#f1b890"))
	if correct:
		for choice: Button in choices.get_children():
			choice.disabled = true
		enter_button.show()
		ArchiveUi.wire_focus_cycle([enter_button, close_button])
		enter_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	root_control.hide()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
