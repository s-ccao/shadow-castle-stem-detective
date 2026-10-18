class_name ChemistryCaseUI
extends CanvasLayer

signal closed
signal action_requested(action_id: String, value: String)

const BRASS := Color("#b59050")
const PARCHMENT := Color("#e6d6ae")
const VIOLET := Color("#af8bce")

var case_state: ChemistryCaseState
var mode := "inspect"
var statement_id := ""
var evidence_id := ""
var section := "facts"
var feedback := ""
var board: Panel
var action_column: VBoxContainer
var dossier: RichTextLabel
var feedback_label: Label
var buttons: Array[Button] = []
var _was_paused := false
var _opened := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	CaseLocale.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_language: String) -> void:
	feedback = ""
	if _opened:
		render()


func open(model: ChemistryCaseState, context: String) -> void:
	case_state = model
	mode = context
	section = "conclusions" if case_state.has("confirmed") else "facts"
	feedback = ""
	if not _opened:
		_was_paused = get_tree().paused
		_opened = true
		get_tree().paused = true
		ArchiveUi.set_hub_entries_suppressed(true)
	visible = true
	render(false)


func close() -> void:
	if not _opened:
		return
	_opened = false
	visible = false
	get_tree().paused = _was_paused
	ArchiveUi.set_hub_entries_suppressed(false)
	GameAudio.play(&"ui_back")
	closed.emit()


func _exit_tree() -> void:
	if _opened:
		get_tree().paused = _was_paused
		ArchiveUi.set_hub_entries_suppressed(false)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_TAB, KEY_I, KEY_U, KEY_J, KEY_K, KEY_B, KEY_N]:
		# Modal owns these keys; do not open another always-processing Hub beneath it.
		if event.keycode != KEY_TAB:
			get_viewport().set_input_as_handled()


func render(preserve_view: bool = true) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := str(focused.name) if preserve_view and is_instance_valid(board) and focused != null and board.is_ancestor_of(focused) else ""
	var old_scroll := board.get_node_or_null("ActionScroll") as ScrollContainer if preserve_view and is_instance_valid(board) else null
	var scroll_position := old_scroll.scroll_vertical if old_scroll != null else 0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.04, 0.85)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	board = Panel.new()
	board.name = "ChemistryCaseBoard"
	board.position = Vector2(52, 54)
	board.size = Vector2(920, 660)
	board.add_theme_stylebox_override("panel", _style(Color("#19131f"), BRASS))
	add_child(board)
	_label(board, _t("CHEMISTRY · FIELD CASE", "化学室 · 现场调查"), Vector2(28, 20), Vector2(770, 32), 24, PARCHMENT)
	_label(board, _t("Observe  →  Propose  →  Compare  →  Question", "观察  →  提出假设  →  比较  →  追问"), Vector2(28, 58), Vector2(850, 28), 15, VIOLET)
	var close_button := _button(_t("Close", "关闭"), "close", "", true)
	close_button.position = Vector2(804, 20)
	close_button.size = Vector2(88, 34)
	board.add_child(close_button)
	_build_specimens()
	var tabs: Array[String] = ["facts", "hypotheses", "conclusions"]
	var captions: Array[String] = [_t("FACTS", "事实"), _t("HYPOTHESES", "假设"), _t("CONFIRMED", "已确认")]
	for index: int in tabs.size():
		var tab := _button(captions[index], "section", tabs[index], true)
		tab.position = Vector2(26 + index * 140, 182)
		tab.size = Vector2(130, 44)
		tab.add_theme_font_size_override("font_size", 12)
		tab.modulate = Color.WHITE if section == tabs[index] else Color(0.76, 0.72, 0.80)
		board.add_child(tab)
	var page := Panel.new()
	page.position = Vector2(26, 238)
	page.size = Vector2(410, 320)
	page.add_theme_stylebox_override("panel", _style(PARCHMENT, BRASS))
	board.add_child(page)
	dossier = RichTextLabel.new()
	dossier.name = "CaseDossier"
	dossier.position = Vector2(16, 12)
	dossier.size = Vector2(378, 296)
	dossier.bbcode_enabled = true
	dossier.add_theme_color_override("default_color", Color("#33243d"))
	dossier.add_theme_font_size_override("normal_font_size", 16)
	dossier.add_theme_font_size_override("bold_font_size", 16)
	match section:
		"hypotheses":
			dossier.text = "[b]" + _t("HYPOTHESES — REVISABLE", "假设——可以修订") + "[/b]\n\n" + case_state.hypothesis_review()
		"conclusions":
			dossier.text = "[b]" + _t("CONFIRMED CONCLUSIONS", "已确认结论") + "[/b]\n\n" + case_state.conclusion()
		_:
			dossier.text = "[b]" + _t("FACTS / OBSERVATIONS", "事实／观察") + "[/b]\n\n" + case_state.facts()
	page.add_child(dossier)
	var action_scroll := ScrollContainer.new()
	action_scroll.name = "ActionScroll"
	action_scroll.position = Vector2(462, 100)
	action_scroll.size = Vector2(430, 456)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.follow_focus = true
	board.add_child(action_scroll)
	action_column = VBoxContainer.new()
	action_column.name = "CaseActions"
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_column.add_theme_constant_override("separation", 10)
	action_scroll.add_child(action_column)
	if mode == "interview":
		_build_interview()
	else:
		_build_investigation()
	feedback_label = _label(board, feedback, Vector2(28, 578), Vector2(864, 60), 16, PARCHMENT)
	feedback_label.name = "CaseFeedback"
	ArchiveUi.wire_focus_cycle(buttons)
	action_scroll.set_deferred("scroll_vertical", scroll_position)
	var retained := board.find_child(focus_name, true, false) as Button if not focus_name.is_empty() else null
	if retained != null and not retained.disabled:
		retained.grab_focus()
	elif buttons.size() > 1:
		buttons[1].grab_focus()
	else:
		close_button.grab_focus()


func _build_specimens() -> void:
	var ids: Array[String] = ["cleaning_powder_sample", "indicator_vial_sample", "broken_glass_sample"]
	var labels: Array[String] = [_t("POWDER", "粉末"), _t("VIAL", "小瓶"), _t("GLASS", "玻璃")]
	for index: int in ids.size():
		var plate := Panel.new()
		plate.position = Vector2(26 + index * 140, 100)
		plate.size = Vector2(130, 70)
		plate.add_theme_stylebox_override("panel", _style(Color("#292031"), BRASS))
		board.add_child(plate)
		var icon := TextureRect.new()
		icon.name = "Trace_" + ids[index]
		icon.position = Vector2(4, 4)
		icon.size = Vector2(60, 60)
		icon.texture = load(GameState.get_item_texture_path(ids[index])) as Texture2D
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
		_label(plate, labels[index], Vector2(64, 10), Vector2(62, 48), 12, PARCHMENT)


func _build_investigation() -> void:
	_copy(_t("WORKING HYPOTHESIS · choose or revise", "工作假设 · 选择或修订"), 18, VIOLET)
	for id: String in ChemistryCaseState.HYPOTHESES:
		var caption := ChemistryCaseState.hypothesis_name(id)
		if case_state.hypothesis() == id:
			caption = "✓ " + caption
		_action(caption, "hypothesis", id, case_state.has("observed"))
	if mode != "analysis":
		_copy(
			_filed_guidance()
			if case_state.has("confirmed") else
			_t("Next: examine Lin's notebook on the alchemy table. Complete its sample tray, then compare the traces there.", "下一步：查看炼金台上的林女士笔记，完成样本分拣，然后在台上比较痕迹。"))
		_action(_t("Return to the room", "返回房间"), "close")
		return
	_copy(_t("CONTROLLED COMPARISON · Lin's protocol", "受控比较 · 林女士的实验方案"), 18, VIOLET)
	_action(_t("1 · Compare separate samples", "1 · 比较分开的样本"), "compare", "control", case_state.can_compare())
	_action(_t("2 · Compare combined samples", "2 · 比较混合后的样本"), "compare", "reaction", case_state.can_compare() and case_state.has("control"))
	_action(_t("File supported colour explanation", "归档有依据的颜色解释"), "confirm", "", case_state.results_ready() and not case_state.hypothesis().is_empty())
	if not case_state.can_compare():
		_copy(_t("Requires an observation, a hypothesis, Lin's notebook and the completed sample tray.", "需要已记录的观察、一个假设、林女士的笔记及完成的样本分拣。"))
	elif case_state.has("confirmed"):
		_copy(_filed_guidance())
	elif case_state.results_ready():
		_copy(_t("Which explanation accounts for the separate samples and their combinations? Review or revise your hypothesis, then file it.", "哪种解释能同时说明分开与混合的结果？复核或修订假设，再尝试归档。"))


func _filed_guidance() -> String:
	if case_state.interview_complete():
		return _t("Comparison and follow-up filed. Continue exploring, or review this record without repeating the case.",
			"比较与追问已归档。可以继续探索，也可以复核记录，无须重复完成调查。")
	return _t("Report filed. Take it to the Butler; match it to his statement before asking a follow-up.",
		"报告已归档。带给管家，与他的陈述配对后再追问。")


func _build_interview() -> void:
	_copy(_t("BUTLER · select a statement", "管家 · 选择一条陈述"), 18, VIOLET)
	_action(_selected("supplies", statement_id) + _t("“I handle the cleaning supplies.”", "“我管理清洁用品。”"), "statement", "supplies")
	_action(_selected("glass", statement_id) + _t("“I heard glass break in this room.”", "“我听见这间房里玻璃碎了。”"), "statement", "glass")
	_copy(_t("PRESENT A RECORD", "出示一份记录"), 18, VIOLET)
	_action(_selected("comparison", evidence_id) + _t("Controlled comparison report", "受控比较报告"), "evidence", "comparison", case_state.has("confirmed"))
	_action(_selected("glass", evidence_id) + _t("Broken-glass observation", "碎玻璃观察"), "evidence", "glass", case_state.has("observed"))
	_action(_t("Compare record with statement", "比较记录与陈述"), "present", "", case_state.has("statement") and not statement_id.is_empty() and not evidence_id.is_empty())
	_action(_t("Ask: what else happened that night?", "追问：那晚还发生了什么？"), "follow_up", "", case_state.has("linked"))
	if not case_state.has("confirmed"):
		_copy(_t("A colour claim is not evidence. File the comparison at the alchemy table first.", "颜色猜测不是证据。请先在炼金台归档比较报告。"))


func _selected(id: String, selected: String) -> String:
	return "✓ " if id == selected else ""


func _copy(body: String, font_size: int = 16, color: Color = PARCHMENT) -> void:
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	action_column.add_child(label)


func _action(caption: String, action_id: String, value: String = "", enabled: bool = true) -> void:
	action_column.add_child(_button(caption, action_id, value, enabled))


func _button(caption: String, action_id: String, value: String, enabled: bool) -> Button:
	var button := Button.new()
	button.name = action_id + ("_" + value if not value.is_empty() else "")
	button.text = caption
	button.custom_minimum_size.y = 36
	button.disabled = not enabled
	ArchiveUi.apply_button(button)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_dispatch.bind(action_id, value))
	if enabled:
		buttons.append(button)
	return button


func _dispatch(action_id: String, value: String) -> void:
	if action_id == "close":
		close()
		return
	if action_id == "section":
		section = value
		render()
	elif action_id == "statement":
		statement_id = value
		feedback = ""
		render()
	elif action_id == "evidence":
		evidence_id = value
		feedback = ""
		render()
	else:
		if action_id == "hypothesis":
			section = "hypotheses"
		elif action_id == "compare":
			section = "facts"
		elif action_id == "confirm":
			section = "conclusions"
		action_requested.emit(action_id, value)


func show_feedback(body: String, success: bool = false) -> void:
	feedback = body
	render()
	if success:
		GameAudio.play(&"note_file")
		OpticalFxRuntime.pulse_ring(self, board, Vector2(442, 576), VIOLET, 8.0, 2.0, 0.3)


func _label(parent: Node, body: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = body
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _t(english: String, chinese: String) -> String:
	return ChemistryCaseState.text(english, chinese)
