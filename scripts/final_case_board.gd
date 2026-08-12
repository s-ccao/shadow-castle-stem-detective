class_name FinalCaseBoard
extends CanvasLayer

## FinalCaseBoard is the final-room deduction Module. Its Interface is narrow:
## open_case(), close_case(), and ordinary_case_closed. The Implementation owns
## evidence selection, conclusion construction, slot validation, conflict
## feedback, and the analysis-table presentation.

signal ordinary_case_closed
signal case_closed
signal true_case_closed

const TABLE_TEXTURE: Texture2D = preload("res://assets/props/FinalRoom/final_analysis_board.png")

const SOURCE_SPECS: Array[Dictionary] = [
	{
		"id": "fake_red_stain",
		"evidence": "fake_red_stain",
		"en": "Staged red stain",
		"zh": "伪造的红色污渍",
	},
	{
		"id": "butler_service_account",
		"flag": "chemistry_butler_interviewed",
		"fallback_evidence": "fake_red_stain",
		"en": "Butler's service account",
		"zh": "管家的服务记录",
	},
	{
		"id": "greenhouse_pollen",
		"evidence": "greenhouse_pollen",
		"en": "Greenhouse pollen",
		"zh": "温室花粉",
	},
	{
		"id": "service_corridor_fiber",
		"evidence": "service_corridor_fiber",
		"en": "Service-corridor fiber",
		"zh": "服务走廊纤维",
	},
	{
		"id": "deliberate_short_circuit",
		"evidence": "deliberate_short_circuit",
		"en": "Deliberate short circuit",
		"zh": "蓄意短路",
	},
	{
		"id": "dining_timeline",
		"evidence": "dining_timeline",
		"en": "Dining timeline",
		"zh": "餐厅时间线",
	},
	{
		"id": "mechanic_missing_glove",
		"evidence": "mechanic_missing_glove",
		"en": "Missing safety glove record",
		"zh": "缺失的安全手套记录",
	},
	{
		"id": "mrs_lin_violet_fiber",
		"evidence": "mrs_lin_violet_fiber",
		"en": "Violet insulating fiber",
		"zh": "紫色绝缘纤维",
	},
	{
		"id": "mrs_lin_glove_fragment",
		"evidence": "mrs_lin_glove_fragment",
		"en": "Torn glove cuff",
		"zh": "撕裂的手套护腕",
	},
	{
		"id": "mrs_lin_notebook",
		"evidence": "mrs_lin_notebook",
		"en": "Dr. Lin's final notebook",
		"zh": "林博士的最终笔记",
	},
]

const CONCLUSION_SPECS: Array[Dictionary] = [
	{
		"id": "staged_scene",
		"slot": "method",
		"sources": ["fake_red_stain", "butler_service_account"],
		"en": "Staged Scene",
		"zh": "伪造现场",
		"detail_en": "The Chemistry scene was a diversion, prepared through the Butler's service supplies.",
		"detail_zh": "化学室现场是借管家服务物资布置的障眼法。",
	},
	{
		"id": "maintenance_route",
		"slot": "route",
		"sources": ["greenhouse_pollen", "service_corridor_fiber"],
		"en": "Maintenance Route",
		"zh": "维修路线",
		"detail_en": "Pollen and fiber show that the service route crossed the greenhouse wing.",
		"detail_zh": "花粉与纤维说明服务路线穿过温室区域。",
	},
	{
		"id": "deliberate_blackout",
		"slot": "blackout",
		"sources": ["deliberate_short_circuit", "mrs_lin_violet_fiber"],
		"en": "Deliberate Blackout",
		"zh": "蓄意断电",
		"detail_en": "The sabotage isolated the table; its violet insulation belongs to a prepared apparatus.",
		"detail_zh": "破坏行为让圆桌孤立断电；紫色绝缘纤维来自预先准备的装置。",
	},
	{
		"id": "dining_opportunity",
		"slot": "opportunity",
		"sources": ["dining_timeline", "butler_service_account"],
		"en": "Dining Opportunity",
		"zh": "餐厅时机",
		"detail_en": "The manipulated dinner interval gave the Butler access while service should have ended.",
		"detail_zh": "被操纵的用餐间隔让管家在服务本应结束时仍能进入现场。",
	},
	{
		"id": "glove_link",
		"slot": "link",
		"sources": ["mechanic_missing_glove", "mrs_lin_violet_fiber", "mrs_lin_glove_fragment"],
		"en": "Safety-Glove Link",
		"zh": "安全手套关联",
		"detail_en": "The glove links the prepared table to maintenance access; it proves contact, not the whole command chain.",
		"detail_zh": "手套把准备过的圆桌与维修权限相连；它证明接触，但尚不能说明完整命令链。",
	},
]

const SLOT_SPECS: Array[Dictionary] = [
	{"id": "method", "en": "METHOD", "zh": "手段", "position": Vector2(395.0, 122.0)},
	{"id": "route", "en": "ROUTE", "zh": "路线", "position": Vector2(562.0, 194.0)},
	{"id": "blackout", "en": "BLACKOUT", "zh": "断电", "position": Vector2(562.0, 382.0)},
	{"id": "opportunity", "en": "OPPORTUNITY", "zh": "时机", "position": Vector2(395.0, 470.0)},
	{"id": "link", "en": "LINK", "zh": "关联", "position": Vector2(284.0, 330.0)},
]

const SEALED_ARCHIVE_SPECS: Array[Dictionary] = [
	{
		"id": "sealed_archive_pressure",
		"slot": "pressure",
		"en": "BUTLER'S PRESSURE",
		"zh": "管家的压力",
		"position": Vector2(318.0, 188.0),
	},
	{
		"id": "sealed_archive_instruction",
		"slot": "instruction",
		"en": "FORGED ORDER",
		"zh": "伪造指令",
		"position": Vector2(510.0, 188.0),
	},
	{
		"id": "sealed_archive_lin_decision",
		"slot": "lin_decision",
		"en": "DR. LIN'S DECISION",
		"zh": "林博士的决定",
		"position": Vector2(414.0, 432.0),
	},
]

var root: Control
var panel: Panel
var title_label: Label
var subtitle_label: Label
var source_heading: Label
var conclusion_heading: Label
var source_list: VBoxContainer
var conclusion_list: VBoxContainer
var status_label: Label
var form_button: Button
var lever_button: Button
var close_button: Button
var source_slots_label: Label
var source_buttons: Dictionary = {}
var conclusion_buttons: Dictionary = {}
var slot_buttons: Dictionary = {}
var selected_sources: Array[String] = []
var selected_conclusion := ""
var conflict_slot := ""
var formed: Dictionary = {}
var placed: Dictionary = {}
var archive_buttons: Dictionary = {}
var archive_slot_buttons: Dictionary = {}
var selected_archive := ""
var placed_archives: Dictionary = {}
var true_case_mode := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	CaseLocale.locale_changed.connect(_refresh_copy)
	visible = false


func open_case() -> void:
	_load_progress()
	true_case_mode = _can_open_true_case()
	visible = true
	root.visible = true
	_refresh_copy()
	_refresh()


func close_case() -> void:
	visible = false
	root.visible = false
	case_closed.emit()


func show_sealed_archive_prompt() -> void:
	open_case()
	if true_case_mode:
		status_label.text = _text(
			"All three Sealed Archives are pinned. Seat them around the violet core, then pull the lever again.",
			"三份密封档案均已钉选。将它们放入紫色核心周围，再次拉下拉杆。"
		)
	else:
		status_label.text = _text(
			"The ordinary case is closed. Find three Sealed Archives, read them, and pin each one in Note Hub before returning.",
			"普通案件已经结案。找到三份密封档案、阅读它们，并在 Note Hub 中逐份钉选后再返回。"
		)


func _build_ui() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.006, 0.016, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	root = Control.new()
	root.name = "FinalCaseBoardRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	panel = Panel.new()
	panel.name = "AshfordAnalysisTable"
	panel.position = Vector2(18.0, 20.0)
	panel.size = Vector2(988.0, 728.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	title_label = _label(Vector2(24.0, 18.0), Vector2(940.0, 34.0), 23, &"title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	subtitle_label = _label(Vector2(110.0, 56.0), Vector2(770.0, 32.0), 13, &"body")
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(subtitle_label)

	source_heading = _label(Vector2(26.0, 112.0), Vector2(230.0, 24.0), 14, &"title")
	source_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(source_heading)

	var source_scroll := ScrollContainer.new()
	source_scroll.name = "RawEvidenceScroll"
	source_scroll.position = Vector2(24.0, 142.0)
	source_scroll.size = Vector2(238.0, 420.0)
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(source_scroll)
	source_list = VBoxContainer.new()
	source_list.name = "RawEvidenceList"
	source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_list.add_theme_constant_override("separation", 5)
	source_scroll.add_child(source_list)

	var table := TextureRect.new()
	table.name = "AnalysisTableArtwork"
	table.texture = TABLE_TEXTURE
	table.position = Vector2(270.0, 98.0)
	table.size = Vector2(450.0, 450.0)
	table.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(table)

	for spec: Dictionary in SLOT_SPECS:
		var slot := Button.new()
		var slot_id := str(spec["id"])
		slot.name = "ConclusionSlot_" + slot_id
		slot.position = spec["position"] as Vector2
		slot.size = Vector2(128.0, 50.0)
		slot.add_theme_font_size_override("font_size", 10)
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.clip_text = true
		slot.alignment = HORIZONTAL_ALIGNMENT_CENTER
		ArchiveUi.apply_button(slot, ArchiveUi.ROLE_ARCHIVE)
		slot.pressed.connect(func() -> void: _place_selected_conclusion(slot_id))
		panel.add_child(slot)
		slot_buttons[slot_id] = slot

	conclusion_heading = _label(Vector2(734.0, 112.0), Vector2(228.0, 24.0), 14, &"title")
	conclusion_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(conclusion_heading)
	conclusion_list = VBoxContainer.new()
	conclusion_list.name = "ConclusionCardBank"
	conclusion_list.position = Vector2(730.0, 142.0)
	conclusion_list.size = Vector2(234.0, 294.0)
	conclusion_list.add_theme_constant_override("separation", 7)
	panel.add_child(conclusion_list)

	var note_label := _label(Vector2(730.0, 452.0), Vector2(234.0, 106.0), 12, &"body")
	note_label.name = "AnalysisProtocol"
	note_label.text = _text(
		"A conclusion is a claim, not a guess. Build it from its supporting evidence, then seat it in its brass slot.",
		"结论是主张，不是猜测。先用支持它的证物构成结论，再将其放入对应的黄铜槽位。"
	)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(note_label)

	form_button = Button.new()
	form_button.name = "FormConclusionButton"
	form_button.position = Vector2(24.0, 584.0)
	form_button.size = Vector2(238.0, 46.0)
	form_button.add_theme_font_size_override("font_size", 11)
	ArchiveUi.apply_button(form_button, ArchiveUi.ROLE_ACTION)
	form_button.pressed.connect(_form_conclusion)
	panel.add_child(form_button)

	source_slots_label = _label(Vector2(24.0, 634.0), Vector2(238.0, 64.0), 11, &"body")
	source_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_slots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_slots_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(source_slots_label)

	status_label = _label(Vector2(285.0, 562.0), Vector2(415.0, 74.0), 12, &"body")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)

	lever_button = Button.new()
	lever_button.name = "AccusationLeverButton"
	lever_button.position = Vector2(337.0, 654.0)
	lever_button.size = Vector2(328.0, 46.0)
	lever_button.add_theme_font_size_override("font_size", 11)
	lever_button.disabled = true
	ArchiveUi.apply_button(lever_button, ArchiveUi.ROLE_ARCANE)
	lever_button.pressed.connect(_pull_accusation_lever)
	panel.add_child(lever_button)

	close_button = Button.new()
	close_button.name = "CloseFinalCaseBoardButton"
	close_button.position = Vector2(760.0, 654.0)
	close_button.size = Vector2(204.0, 46.0)
	close_button.add_theme_font_size_override("font_size", 11)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_ARCHIVE)
	close_button.pressed.connect(close_case)
	panel.add_child(close_button)

	for source: Dictionary in SOURCE_SPECS:
		var source_id := str(source["id"])
		var button := Button.new()
		button.name = "Evidence_" + source_id
		button.custom_minimum_size = Vector2(226.0, 38.0)
		button.add_theme_font_size_override("font_size", 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCHIVE)
		button.pressed.connect(func() -> void: _toggle_source(source_id))
		source_list.add_child(button)
		source_buttons[source_id] = button

	for conclusion: Dictionary in CONCLUSION_SPECS:
		var conclusion_id := str(conclusion["id"])
		var button := Button.new()
		button.name = "ConclusionCard_" + conclusion_id
		button.custom_minimum_size = Vector2(234.0, 48.0)
		button.add_theme_font_size_override("font_size", 10)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCHIVE)
		button.pressed.connect(func() -> void: _select_conclusion(conclusion_id))
		conclusion_list.add_child(button)
		conclusion_buttons[conclusion_id] = button

	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var archive_id := str(archive["id"])
		var archive_button := Button.new()
		archive_button.name = "SealedArchive_" + archive_id
		archive_button.custom_minimum_size = Vector2(234.0, 52.0)
		archive_button.add_theme_font_size_override("font_size", 10)
		archive_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		archive_button.clip_text = true
		ArchiveUi.apply_button(archive_button, ArchiveUi.ROLE_ARCHIVE)
		archive_button.pressed.connect(func() -> void: _select_sealed_archive(archive_id))
		conclusion_list.add_child(archive_button)
		archive_buttons[archive_id] = archive_button

		var archive_slot := Button.new()
		archive_slot.name = "SealedArchiveSlot_" + str(archive["slot"])
		archive_slot.position = archive["position"] as Vector2
		archive_slot.size = Vector2(150.0, 52.0)
		archive_slot.add_theme_font_size_override("font_size", 10)
		archive_slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		archive_slot.clip_text = true
		ArchiveUi.apply_button(archive_slot, ArchiveUi.ROLE_ARCANE)
		archive_slot.pressed.connect(func() -> void: _place_selected_archive(str(archive["slot"])))
		panel.add_child(archive_slot)
		archive_slot_buttons[str(archive["slot"])] = archive_slot


func _load_progress() -> void:
	formed.clear()
	placed.clear()
	placed_archives.clear()
	selected_sources.clear()
	selected_conclusion = ""
	conflict_slot = ""
	for conclusion: Dictionary in CONCLUSION_SPECS:
		var conclusion_id := str(conclusion["id"])
		if GameState.has_story_flag("final_case_formed_" + conclusion_id):
			formed[conclusion_id] = true
		var slot_id := str(conclusion["slot"])
		if GameState.has_story_flag("final_case_placed_" + slot_id):
			placed[slot_id] = conclusion_id
	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var slot_id := str(archive["slot"])
		if GameState.has_story_flag("true_case_placed_" + slot_id):
			placed_archives[slot_id] = str(archive["id"])


func _refresh_copy(_language: String = "") -> void:
	title_label.text = _text(
		"ASHFORD ANALYSIS TABLE · SEALED REVIEW" if true_case_mode else "ASHFORD ANALYSIS TABLE",
		"阿什福德分析圆桌 · 密封复查" if true_case_mode else "阿什福德分析圆桌"
	)
	subtitle_label.text = _text(
		"The Butler acted. Now use the pinned private records to trace the author of the command." if true_case_mode else "Build a conclusion from 2–3 raw evidence records. Then seat it in the matching brass slot.",
		"管家执行了操作。现在用钉选的私密档案追溯命令的作者。" if true_case_mode else "从 2–3 条原始证物中构成结论，再将它放入对应的黄铜槽位。"
	)
	source_heading.text = _text("RAW EVIDENCE", "原始证物")
	conclusion_heading.text = _text("CONCLUSION FILE", "结论档案")
	close_button.text = _text("RETURN TO INVESTIGATION", "返回调查")
	lever_button.text = _text(
		"PULL LEVER · EXPOSE MECHANIC" if true_case_mode else "PULL LEVER · ACCUSE BUTLER",
		"拉下拉杆 · 揭露机械师" if true_case_mode else "拉下拉杆 · 指认管家"
	)
	_refresh()


func _refresh() -> void:
	if title_label == null:
		return
	for child: Node in source_list.get_children():
		child.visible = not true_case_mode
	form_button.visible = not true_case_mode
	source_slots_label.visible = not true_case_mode
	source_heading.visible = not true_case_mode
	(source_list.get_parent() as Control).visible = not true_case_mode
	source_heading.text = _text("RAW EVIDENCE", "原始证物")
	conclusion_heading.text = _text("SECOND-LAYER CHAIN" if true_case_mode else "CONCLUSION FILE", "第二层命令链" if true_case_mode else "结论档案")
	for source: Dictionary in SOURCE_SPECS:
		var source_id := str(source["id"])
		var button: Button = source_buttons.get(source_id) as Button
		if button == null:
			continue
		var available := _source_available(source)
		button.disabled = not available
		var marker := "◆ " if selected_sources.has(source_id) else "   "
		button.text = marker + _localized(source, "")
		ArchiveUi.set_button_status(button, &"default")
		if selected_sources.has(source_id):
			button.self_modulate = Color(1.08, 0.98, 0.76, 1.0)
		elif not available:
			button.self_modulate = Color(0.72, 0.72, 0.76, 0.72)
		else:
			button.self_modulate = Color.WHITE

	for conclusion: Dictionary in CONCLUSION_SPECS:
		var conclusion_id := str(conclusion["id"])
		var button: Button = conclusion_buttons.get(conclusion_id) as Button
		if button == null:
			continue
		var is_formed := formed.has(conclusion_id)
		var is_placed := placed.has(str(conclusion["slot"]))
		button.visible = not true_case_mode
		button.disabled = not is_formed or is_placed
		button.text = (
			("◆ " if selected_conclusion == conclusion_id else "")
			+ _localized(conclusion, "")
			+ ("\n" + _text("SEATED", "已入槽") if is_placed else "")
		)
		ArchiveUi.set_button_status(button, &"success" if is_formed else &"default")
		if selected_conclusion == conclusion_id:
			button.self_modulate = Color(0.88, 0.78, 1.08, 1.0)
		elif is_formed:
			button.self_modulate = Color(0.92, 1.04, 0.90, 1.0)
		else:
			button.self_modulate = Color(0.64, 0.64, 0.68, 0.78)

	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var archive_id := str(archive["id"])
		var archive_button: Button = archive_buttons.get(archive_id) as Button
		var archive_slot: Button = archive_slot_buttons.get(str(archive["slot"])) as Button
		var archive_ready := _sealed_archive_pinned(archive_id)
		var archive_placed := placed_archives.has(str(archive["slot"]))
		archive_button.visible = true_case_mode
		archive_slot.visible = true_case_mode
		if archive_button != null:
			archive_button.disabled = not archive_ready or archive_placed
			archive_button.text = ("◆ " if selected_archive == archive_id else "") + _localized(archive, "") + ("\n" + _text("SEATED", "已入槽") if archive_placed else "")
			ArchiveUi.set_button_status(archive_button, &"success" if archive_ready else &"default")
			archive_button.self_modulate = Color(0.89, 0.82, 1.04, 1.0) if archive_ready else Color(0.62, 0.62, 0.68, 0.74)
		if archive_slot != null:
			if archive_placed:
				archive_slot.text = _localized(archive, "") + "\n" + _text("LINKED", "已连结")
				ArchiveUi.set_button_status(archive_slot, &"success")
				archive_slot.self_modulate = Color(0.88, 0.78, 1.10, 1.0)
			else:
				archive_slot.text = _localized(archive, "") + "\n—"
				ArchiveUi.set_button_status(archive_slot, &"default")
				archive_slot.self_modulate = Color.WHITE

	for slot: Dictionary in SLOT_SPECS:
		var slot_id := str(slot["id"])
		var button: Button = slot_buttons.get(slot_id) as Button
		if button == null:
			continue
		button.visible = not true_case_mode
		if conflict_slot == slot_id:
			button.text = _text("×\nCONFLICT", "×\n矛盾")
			ArchiveUi.set_button_status(button, &"error")
			button.self_modulate = Color(1.0, 0.72, 0.68, 1.0)
			continue
		if placed.has(slot_id):
			var conclusion := _conclusion_by_id(str(placed[slot_id]))
			button.text = _localized(slot, "") + "\n" + _localized(conclusion, "")
			ArchiveUi.set_button_status(button, &"success")
			button.self_modulate = Color(0.86, 1.05, 0.88, 1.0)
		else:
			button.text = _localized(slot, "") + "\n—"
			ArchiveUi.set_button_status(button, &"default")
			button.self_modulate = Color.WHITE

	form_button.text = _text(
		"FORM CONCLUSION  %d/3" % selected_sources.size(),
		"形成结论  %d/3" % selected_sources.size()
	)
	var source_slots: Array[String] = []
	for source_id: String in selected_sources:
		source_slots.append(_localized(_source_by_id(source_id), ""))
	while source_slots.size() < 3:
		source_slots.append(_text("empty evidence pin", "空白证物钉") )
	source_slots_label.text = _text("PINS\n", "证物钉\n") + "  ·  ".join(source_slots)
	form_button.disabled = selected_sources.size() < 2
	_levers_ready()
	if status_label.text.is_empty():
		status_label.text = _text(
			"Select evidence. A wrong connection will reveal a contradiction without costing progress.",
			"选择证物。错误关联会显示矛盾，但不会损失进度。"
		)


func _toggle_source(source_id: String) -> void:
	var source := _source_by_id(source_id)
	if source.is_empty() or not _source_available(source):
		return
	conflict_slot = ""
	ArchiveUi.set_button_status(form_button, &"default")
	if selected_sources.has(source_id):
		selected_sources.erase(source_id)
	elif selected_sources.size() < 3:
		selected_sources.append(source_id)
	else:
		status_label.text = _text(
			"A conclusion uses no more than three source records. Remove one before adding another.",
			"一条结论最多使用三条原始记录。请先取消一条，再加入新的证物。"
		)
		ArchiveUi.set_button_status(form_button, &"error")
	_refresh()


func _form_conclusion() -> void:
	if selected_sources.size() < 2:
		return
	for conclusion: Dictionary in CONCLUSION_SPECS:
		var conclusion_id := str(conclusion["id"])
		if formed.has(conclusion_id):
			continue
		if _same_ids(selected_sources, conclusion["sources"] as Array):
			formed[conclusion_id] = true
			GameState.set_story_flag("final_case_formed_" + conclusion_id)
			selected_sources.clear()
			status_label.text = _text(
				"Conclusion formed: " + _localized(conclusion, "") + ". Select its card, then choose its brass slot.",
				"已形成结论：" + _localized(conclusion, "") + "。选择卡片，再选择对应的黄铜槽位。"
			)
			ArchiveUi.set_button_status(form_button, &"success")
			_refresh()
			return
	status_label.text = _text(
		"CONTRADICTION — this evidence set does not support one unfinished conclusion. Re-check the archive, then try another pairing.",
		"矛盾——这组证物无法支持任何未完成结论。请重新查阅档案，再尝试另一种组合。"
	)
	ArchiveUi.set_button_status(form_button, &"error")


func _select_conclusion(conclusion_id: String) -> void:
	if not formed.has(conclusion_id):
		return
	selected_conclusion = "" if selected_conclusion == conclusion_id else conclusion_id
	conflict_slot = ""
	status_label.text = _text(
		"Choose the brass slot that names this conclusion's role in the case.",
		"选择说明这条结论在案件中角色的黄铜槽位。"
	)
	_refresh()


func _place_selected_conclusion(slot_id: String) -> void:
	if selected_conclusion.is_empty() or placed.has(slot_id):
		return
	var conclusion := _conclusion_by_id(selected_conclusion)
	conflict_slot = ""
	if str(conclusion["slot"]) != slot_id:
		conflict_slot = slot_id
		status_label.text = _text(
			"CONTRADICTION — " + _localized(conclusion, "") + " does not belong in this slot. Its line dims; no progress is lost.",
			"矛盾——“" + _localized(conclusion, "") + "”不属于这个槽位。连线已变暗，进度不会丢失。"
		)
		_refresh()
		return
	placed[slot_id] = selected_conclusion
	GameState.set_story_flag("final_case_placed_" + slot_id)
	status_label.text = _text(
		"Connection seated: " + _localized(conclusion, "") + ".",
		"关联已入槽：" + _localized(conclusion, "") + "。"
	)
	selected_conclusion = ""
	_refresh()


func _pull_accusation_lever() -> void:
	if true_case_mode:
		if placed_archives.size() != SEALED_ARCHIVE_SPECS.size():
			return
		GameState.set_story_flag("true_ending")
		GameState.set_story_flag("mechanic_exposed")
		true_case_closed.emit()
		return
	if placed.size() != SLOT_SPECS.size():
		return
	GameState.set_story_flag("final_deduction_solved")
	GameState.set_story_flag("normal_ending")
	ordinary_case_closed.emit()


func _levers_ready() -> void:
	var ready := (
		placed_archives.size() == SEALED_ARCHIVE_SPECS.size() and not GameState.has_story_flag("true_ending")
		if true_case_mode
		else placed.size() == SLOT_SPECS.size() and not GameState.has_story_flag("normal_ending")
	)
	lever_button.disabled = not ready
	if true_case_mode and GameState.has_story_flag("true_ending"):
		lever_button.text = _text("TRUE CASE REVEALED", "真相案件已揭露")


func _select_sealed_archive(archive_id: String) -> void:
	if not true_case_mode or not _sealed_archive_pinned(archive_id):
		return
	selected_archive = "" if selected_archive == archive_id else archive_id
	status_label.text = _text(
		"Seat this archive in the slot that names its role in the command chain.",
		"将此档案放入说明它在命令链中作用的槽位。"
	)
	_refresh()


func _place_selected_archive(slot_id: String) -> void:
	if selected_archive.is_empty() or placed_archives.has(slot_id):
		return
	var archive := _sealed_archive_by_id(selected_archive)
	if archive.is_empty():
		return
	if str(archive["slot"]) != slot_id:
		status_label.text = _text(
			"CONTRADICTION — this archive has a different role in the command chain. No progress is lost.",
			"矛盾——这份档案在命令链中承担的是另一种角色。进度不会丢失。"
		)
		return
	placed_archives[slot_id] = selected_archive
	GameState.set_story_flag("true_case_placed_" + slot_id)
	selected_archive = ""
	status_label.text = _text(
		"The second-layer link locks into place.",
		"第二层关联已锁定。"
	)
	_refresh()


func _sealed_archive_pinned(archive_id: String) -> bool:
	return GameState.has_story_flag("sealed_archive_pinned_" + archive_id)


func _can_open_true_case() -> bool:
	if not GameState.has_story_flag("normal_ending"):
		return false
	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		if not _sealed_archive_pinned(str(archive["id"])):
			return false
	return true


func _source_available(source: Dictionary) -> bool:
	if source.has("evidence"):
		return GameState.has_evidence(str(source["evidence"]))
	if source.has("flag"):
		return (
			GameState.has_story_flag(str(source["flag"]))
			or GameState.has_evidence(str(source.get("fallback_evidence", "")))
		)
	return false


func _source_by_id(source_id: String) -> Dictionary:
	for source: Dictionary in SOURCE_SPECS:
		if str(source["id"]) == source_id:
			return source
	return {}


func _conclusion_by_id(conclusion_id: String) -> Dictionary:
	for conclusion: Dictionary in CONCLUSION_SPECS:
		if str(conclusion["id"]) == conclusion_id:
			return conclusion
	return {}


func _sealed_archive_by_id(archive_id: String) -> Dictionary:
	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		if str(archive["id"]) == archive_id:
			return archive
	return {}


func _same_ids(first: Array[String], second: Array) -> bool:
	if first.size() != second.size():
		return false
	var expected: Array[String] = []
	for value: Variant in second:
		expected.append(str(value))
	for id: String in first:
		if not expected.has(id):
			return false
	return true


func _localized(spec: Dictionary, _fallback: String) -> String:
	return str(spec.get("zh" if CaseLocale.is_chinese() else "en", _fallback))


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english


func _label(position_value: Vector2, size_value: Vector2, font_size: int, role: StringName) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	ArchiveUi.apply_label(label, role)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.012, 0.025, 0.985)
	style.border_color = Color(0.78, 0.59, 0.25, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 6.0)
	return style
