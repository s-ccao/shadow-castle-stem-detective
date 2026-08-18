class_name FinalCaseBoard
extends CanvasLayer

## FinalCaseBoard is the final-room deduction Module. Its Interface is narrow:
## open_case(), close_case(), and ordinary_case_closed. The Implementation owns
## evidence selection, conclusion construction, slot validation, conflict
## feedback, and the analysis-table presentation.

signal ordinary_case_closed
signal case_closed
signal true_case_closed

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
	{"id": "method", "en": "METHOD", "zh": "手段", "anchor": Vector2(0.50, 0.12)},
	{"id": "route", "en": "ROUTE", "zh": "路线", "anchor": Vector2(0.73, 0.21)},
	{"id": "blackout", "en": "BLACKOUT", "zh": "断电", "anchor": Vector2(0.89, 0.50)},
	{"id": "opportunity", "en": "OPPORTUNITY", "zh": "时机", "anchor": Vector2(0.50, 0.86)},
	{"id": "link", "en": "LINK", "zh": "关联", "anchor": Vector2(0.11, 0.50)},
]

const SEALED_ARCHIVE_SPECS: Array[Dictionary] = [
	{
		"id": "sealed_archive_pressure",
		"slot": "pressure",
		"en": "BUTLER'S PRESSURE",
		"zh": "管家的压力",
		"anchor": Vector2(0.11, 0.50),
	},
	{
		"id": "sealed_archive_instruction",
		"slot": "instruction",
		"en": "FORGED ORDER",
		"zh": "伪造指令",
		"anchor": Vector2(0.50, 0.12),
	},
	{
		"id": "sealed_archive_lin_decision",
		"slot": "lin_decision",
		"en": "DR. LIN'S DECISION",
		"zh": "林博士的决定",
		"anchor": Vector2(0.89, 0.50),
	},
]

var root: Control
var safe_area: MarginContainer
var panel: Control
var title_label: Label
var subtitle_label: Label
var source_heading: Label
var conclusion_heading: Label
var source_instruction: Label
var source_drawer: Control
var conclusion_drawer: Control
var source_list: VBoxContainer
var conclusion_list: VBoxContainer
var protocol_label: Label
var empty_conclusion_label: Label
var empty_conclusion_plaque: Control
var status_label: Label
var form_button: Button
var lever_button: Button
var close_button: Button
var source_slots_label: Label
var workbench: Control
var table_canvas: Control
var effect_layer: Control
var table_core_glow: Sprite2D
var connection_lines: Dictionary = {}
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
	_bind_scene()
	# The accusation is made at a lit table, not against a flat void. The shared
	# atmosphere keeps this screen in the same room as the rest of the archive.
	ArchiveUi.install_screen_atmosphere(root, {
		"lamp_anchor": Vector2(0.50, 0.50),
		"lamp_tint": Color(0.74, 0.56, 1.0, 1.0),
		"mote_tint": Color(0.88, 0.80, 1.0, 1.0),
		"lamp_strength": 0.20,
		"lamp_radius": 0.44,
		"vignette_strength": 0.62,
		"vignette_radius": 0.30,
		"mote_strength": 0.34,
		"grain_strength": 0.024,
		"layer_index": 1,
	})
	_build_scene_controls()
	_build_effect_layer()
	_apply_safe_area()
	root.resized.connect(_apply_safe_area)
	workbench.resized.connect(_layout_table_canvas)
	table_canvas.resized.connect(_layout_table_slots)
	CaseLocale.locale_changed.connect(_refresh_copy)
	visible = false


func open_case() -> void:
	_load_progress()
	true_case_mode = _can_open_true_case()
	status_label.text = ""
	visible = true
	root.visible = true
	_refresh_copy()
	_refresh()
	call_deferred("_focus_opening_control")


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


func _bind_scene() -> void:
	root = $FinalCaseBoardRoot
	safe_area = $FinalCaseBoardRoot/SafeArea
	panel = $FinalCaseBoardRoot/SafeArea/BoardFrame
	title_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/Header/TitleLabel
	subtitle_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/Header/SubtitleLabel
	source_drawer = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/EvidenceDrawer
	source_heading = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/EvidenceDrawer/Margin/Column/SourceHeading
	source_instruction = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/EvidenceDrawer/Margin/Column/EvidenceInstruction
	source_list = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/EvidenceDrawer/Margin/Column/RawEvidenceScroll/RawEvidenceList
	source_slots_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/EvidenceDrawer/Margin/Column/EvidencePins
	workbench = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/Workbench
	table_canvas = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/Workbench/TableCanvas
	conclusion_drawer = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer
	conclusion_heading = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer/Margin/Column/ConclusionHeading
	protocol_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer/Margin/Column/AnalysisProtocol
	empty_conclusion_plaque = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer/Margin/Column/EmptyConclusionPlaque
	empty_conclusion_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer/Margin/Column/EmptyConclusionPlaque/EmptyConclusionFile
	conclusion_list = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/MainRow/ConclusionDrawer/Margin/Column/ConclusionScroll/ConclusionCardBank
	form_button = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/ActionRail/FormConclusionButton
	status_label = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/ActionRail/CaseStatusPlaque/CaseStatus
	lever_button = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/ActionRail/AccusationLeverButton
	close_button = $FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/ActionRail/CloseFinalCaseBoardButton

	panel.add_theme_stylebox_override("panel", _panel_style())
	source_drawer.add_theme_stylebox_override("panel", _drawer_style(false))
	conclusion_drawer.add_theme_stylebox_override("panel", _drawer_style(true))
	empty_conclusion_plaque.add_theme_stylebox_override("panel", _empty_file_style())
	($FinalCaseBoardRoot/SafeArea/BoardFrame/FrameMargin/Content/ActionRail/CaseStatusPlaque as Control).add_theme_stylebox_override("panel", _status_style())
	ArchiveUi.apply_label(title_label, &"title")
	ArchiveUi.apply_label(subtitle_label, &"body")
	ArchiveUi.apply_label(source_heading, &"title")
	ArchiveUi.apply_label(source_instruction, &"muted")
	ArchiveUi.apply_label(conclusion_heading, &"title")
	ArchiveUi.apply_label(protocol_label, &"muted")
	ArchiveUi.apply_label(empty_conclusion_label, &"body")
	ArchiveUi.apply_label(status_label, &"body")
	ArchiveUi.apply_label(source_slots_label, &"body")
	title_label.add_theme_font_size_override("font_size", 26)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	source_heading.add_theme_font_size_override("font_size", 13)
	conclusion_heading.add_theme_font_size_override("font_size", 13)
	source_instruction.add_theme_font_size_override("font_size", 10)
	protocol_label.add_theme_font_size_override("font_size", 10)
	empty_conclusion_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_font_size_override("font_size", 11)
	source_slots_label.add_theme_font_size_override("font_size", 10)
	ArchiveUi.apply_button(form_button, ArchiveUi.ROLE_ACTION)
	ArchiveUi.apply_button(lever_button, ArchiveUi.ROLE_ARCANE)
	_apply_record_button(close_button, false)
	form_button.pressed.connect(_form_conclusion)
	lever_button.pressed.connect(_pull_accusation_lever)
	close_button.pressed.connect(close_case)


func _build_effect_layer() -> void:
	effect_layer = Control.new()
	effect_layer.name = "FinalBoardOpticalVFX"
	effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_layer.z_index = 80
	root.add_child(effect_layer)

	# The analysis table is the instrument the whole case ends on. A slow violet
	# core keeps it alive beneath the role slots without competing with them.
	table_core_glow = Sprite2D.new()
	table_core_glow.name = "AnalysisTableCore"
	table_core_glow.texture = OpticalFxRuntime.radial_glow_texture()
	table_core_glow.material = OpticalFxRuntime.additive_material()
	table_core_glow.modulate = Color(0.62, 0.42, 1.0, 0.30)
	table_canvas.add_child(table_core_glow)
	# Directly above the painted table, below the role slots the player reads.
	var table_artwork := table_canvas.get_node_or_null("AnalysisTableArtwork")
	table_canvas.move_child(
		table_core_glow,
		0 if table_artwork == null else table_artwork.get_index() + 1
	)
	_layout_table_core()
	table_canvas.resized.connect(_layout_table_core)
	var core_pulse := table_core_glow.create_tween().set_loops()
	core_pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	core_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	core_pulse.tween_property(table_core_glow, "modulate:a", 0.15, 2.4)
	core_pulse.tween_property(table_core_glow, "modulate:a", 0.30, 2.4)


func _layout_table_core() -> void:
	if table_core_glow == null or not is_instance_valid(table_core_glow):
		return
	table_core_glow.position = table_canvas.size * 0.5
	var core_radius := minf(table_canvas.size.x, table_canvas.size.y) * 0.34
	table_core_glow.scale = Vector2.ONE * maxf(0.05, core_radius / 64.0)


func _build_scene_controls() -> void:
	for spec: Dictionary in SLOT_SPECS:
		var slot := Button.new()
		var slot_id := str(spec["id"])
		slot.name = "ConclusionSlot_" + slot_id
		slot.custom_minimum_size = Vector2(100.0, 40.0)
		slot.add_theme_font_size_override("font_size", 10)
		slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.clip_text = false
		slot.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_table_slot(slot, false)
		slot.pressed.connect(func() -> void: _place_selected_conclusion(slot_id))
		table_canvas.add_child(slot)
		slot_buttons[slot_id] = slot

	for source: Dictionary in SOURCE_SPECS:
		var source_id := str(source["id"])
		var button := Button.new()
		button.name = "Evidence_" + source_id
		button.custom_minimum_size = Vector2(0.0, 38.0)
		button.add_theme_font_size_override("font_size", 11)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		_apply_record_button(button, false)
		button.pressed.connect(func() -> void: _toggle_source(source_id))
		source_list.add_child(button)
		source_buttons[source_id] = button

	for conclusion: Dictionary in CONCLUSION_SPECS:
		var conclusion_id := str(conclusion["id"])
		var button := Button.new()
		button.name = "ConclusionCard_" + conclusion_id
		button.custom_minimum_size = Vector2(0.0, 62.0)
		button.add_theme_font_size_override("font_size", 11)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		_apply_record_button(button, true)
		button.pressed.connect(func() -> void: _select_conclusion(conclusion_id))
		conclusion_list.add_child(button)
		conclusion_buttons[conclusion_id] = button

	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var archive_id := str(archive["id"])
		var archive_button := Button.new()
		archive_button.name = "SealedArchive_" + archive_id
		archive_button.custom_minimum_size = Vector2(0.0, 72.0)
		archive_button.add_theme_font_size_override("font_size", 11)
		archive_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		archive_button.clip_text = false
		_apply_record_button(archive_button, true)
		archive_button.pressed.connect(func() -> void: _select_sealed_archive(archive_id))
		conclusion_list.add_child(archive_button)
		archive_buttons[archive_id] = archive_button

		var archive_slot := Button.new()
		archive_slot.name = "SealedArchiveSlot_" + str(archive["slot"])
		archive_slot.custom_minimum_size = Vector2(116.0, 46.0)
		archive_slot.add_theme_font_size_override("font_size", 10)
		archive_slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		archive_slot.clip_text = false
		_apply_table_slot(archive_slot, true)
		archive_slot.pressed.connect(func() -> void: _place_selected_archive(str(archive["slot"])))
		table_canvas.add_child(archive_slot)
		archive_slot_buttons[str(archive["slot"])] = archive_slot

	_wire_focus_neighbors()
	call_deferred("_layout_table_canvas")


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	safe_area.add_theme_constant_override("margin_left", max(14, safe.position.x))
	safe_area.add_theme_constant_override("margin_top", max(14, safe.position.y))
	safe_area.add_theme_constant_override("margin_right", max(14, window_size.x - safe.end.x))
	safe_area.add_theme_constant_override("margin_bottom", max(14, window_size.y - safe.end.y))


func _layout_table_slots() -> void:
	if table_canvas.size.x <= 0.0 or table_canvas.size.y <= 0.0:
		return
	for spec: Dictionary in SLOT_SPECS:
		var slot: Button = slot_buttons.get(str(spec["id"])) as Button
		if slot != null:
			slot.size = Vector2(100.0, 40.0)
			slot.position = _slot_position(spec["anchor"] as Vector2, slot.size)
	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var archive_slot: Button = archive_slot_buttons.get(str(archive["slot"])) as Button
		if archive_slot != null:
			archive_slot.size = Vector2(116.0, 46.0)
			archive_slot.position = _slot_position(archive["anchor"] as Vector2, archive_slot.size)


func _layout_table_canvas() -> void:
	if workbench.size.x <= 0.0 or workbench.size.y <= 0.0:
		return
	var board_side: float = minf(workbench.size.x, workbench.size.y)
	table_canvas.size = Vector2(board_side, board_side)
	table_canvas.position = (workbench.size - table_canvas.size) * 0.5
	_layout_table_slots()


func _wire_focus_neighbors() -> void:
	var evidence: Array[Button] = []
	for spec: Dictionary in SOURCE_SPECS:
		var button: Button = source_buttons.get(str(spec["id"])) as Button
		if button != null:
			evidence.append(button)
	for index: int in evidence.size():
		var button := evidence[index]
		button.focus_neighbor_top = evidence[max(0, index - 1)].get_path()
		button.focus_neighbor_bottom = evidence[min(evidence.size() - 1, index + 1)].get_path()
	if not evidence.is_empty():
		evidence.front().focus_neighbor_right = (slot_buttons.get("method") as Button).get_path()
		evidence.back().focus_neighbor_bottom = form_button.get_path()
	form_button.focus_neighbor_top = evidence.back().get_path() if not evidence.is_empty() else close_button.get_path()
	form_button.focus_neighbor_right = lever_button.get_path()
	lever_button.focus_neighbor_left = form_button.get_path()
	lever_button.focus_neighbor_right = close_button.get_path()
	close_button.focus_neighbor_left = lever_button.get_path()
	var method_slot: Button = slot_buttons.get("method") as Button
	var route_slot: Button = slot_buttons.get("route") as Button
	var blackout_slot: Button = slot_buttons.get("blackout") as Button
	var opportunity_slot: Button = slot_buttons.get("opportunity") as Button
	var link_slot: Button = slot_buttons.get("link") as Button
	method_slot.focus_neighbor_left = link_slot.get_path()
	method_slot.focus_neighbor_right = route_slot.get_path()
	method_slot.focus_neighbor_bottom = opportunity_slot.get_path()
	route_slot.focus_neighbor_left = method_slot.get_path()
	route_slot.focus_neighbor_right = blackout_slot.get_path()
	blackout_slot.focus_neighbor_left = route_slot.get_path()
	blackout_slot.focus_neighbor_right = close_button.get_path()
	opportunity_slot.focus_neighbor_top = method_slot.get_path()
	opportunity_slot.focus_neighbor_left = link_slot.get_path()
	opportunity_slot.focus_neighbor_right = blackout_slot.get_path()
	link_slot.focus_neighbor_left = evidence.front().get_path() if not evidence.is_empty() else form_button.get_path()
	link_slot.focus_neighbor_right = method_slot.get_path()


func _focus_opening_control() -> void:
	for source: Dictionary in SOURCE_SPECS:
		var button: Button = source_buttons.get(str(source["id"])) as Button
		if button != null and button.visible and not button.disabled:
			button.grab_focus()
			return
	for archive: Dictionary in SEALED_ARCHIVE_SPECS:
		var archive_button: Button = archive_buttons.get(str(archive["id"])) as Button
		if archive_button != null and archive_button.visible and not archive_button.disabled:
			archive_button.grab_focus()
			return
	close_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_case()
		get_viewport().set_input_as_handled()


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
	ArchiveUi.refresh_tree(root)
	title_label.text = _text(
		"ASHFORD ANALYSIS TABLE · SEALED REVIEW" if true_case_mode else "ASHFORD ANALYSIS TABLE",
		"阿什福德分析圆桌 · 密封复查" if true_case_mode else "阿什福德分析圆桌"
	)
	subtitle_label.text = _text(
		"The Butler acted. Now use the pinned private records to trace the author of the command." if true_case_mode else "Build a conclusion from 2–3 raw evidence records. Then seat it in the matching brass slot.",
		"管家执行了操作。现在用钉选的私密档案追溯命令的作者。" if true_case_mode else "从 2–3 条原始证物中构成结论，再将它放入对应的黄铜槽位。"
	)
	source_heading.text = _text("1 · PIN RAW EVIDENCE", "1 · 钉选原始证物")
	source_instruction.text = _text(
		"Choose two or three records. The pins below become one claim.",
		"选择两到三条记录。下方证物钉将组成一条结论。"
	)
	conclusion_heading.text = _text("2 · FORM & SEAT CLAIMS", "2 · 形成并放置结论")
	protocol_label.text = _text(
		"Form a claim first. Only completed files enter this tray.",
		"先形成结论；只有已完成的档案会进入此处。"
	)
	empty_conclusion_label.text = _text(
		"NO CONCLUSION FORMED\n\nSelect 2–3 evidence records, then use FORM CONCLUSION.",
		"尚未形成结论\n\n选择 2–3 条证物，再点击“形成结论”。"
	)
	close_button.text = _text("RETURN TO INVESTIGATION", "返回调查")
	lever_button.text = _text(
		"3 · PULL LEVER · TRACE COMMAND" if true_case_mode else "3 · PULL LEVER · SEAL ACCUSATION",
		"3 · 拉下拉杆 · 追溯命令" if true_case_mode else "3 · 拉下拉杆 · 封存指控"
	)
	_refresh()


func _refresh() -> void:
	if title_label == null:
		return
	source_drawer.visible = not true_case_mode
	form_button.visible = not true_case_mode
	conclusion_heading.text = _text("2 · HIDDEN COMMAND CHAIN" if true_case_mode else "2 · FORM & SEAT CLAIMS", "2 · 隐藏命令链" if true_case_mode else "2 · 形成并放置结论")
	protocol_label.text = _text(
		"Seat the pinned private record in the role it played in the hidden command chain." if true_case_mode else "Form a claim first. Only completed files enter this tray.",
		"将钉选的私密档案放入它在隐藏命令链中承担的角色。" if true_case_mode else "先形成结论；只有已完成的档案会进入此处。"
	)
	empty_conclusion_label.visible = not true_case_mode and formed.is_empty()
	empty_conclusion_plaque.visible = empty_conclusion_label.visible
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
		button.visible = not true_case_mode and is_formed
		button.disabled = not is_formed or is_placed
		button.text = (
			("◆ " if selected_conclusion == conclusion_id else "")
			+ _localized(conclusion, "")
			+ ("\n" + _text("SEATED IN BRASS SLOT", "已放入黄铜槽位") if is_placed else "")
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
			archive_button.text = ("◆ " if selected_archive == archive_id else "") + _localized(archive, "") + ("\n" + _text("SEATED IN VIOLET CORE", "已连入紫色核心") if archive_placed else "")
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
			button.text = _text("×  CONTRADICTION", "×  矛盾")
			ArchiveUi.set_button_status(button, &"error")
			button.self_modulate = Color(1.0, 0.72, 0.68, 1.0)
			continue
		if placed.has(slot_id):
			var conclusion := _conclusion_by_id(str(placed[slot_id]))
			button.text = _localized(slot, "") + "\n" + _localized(conclusion, "")
			ArchiveUi.set_button_status(button, &"success")
			button.self_modulate = Color(0.86, 1.05, 0.88, 1.0)
		else:
			button.text = _localized(slot, "") + "\n" + _text("EMPTY", "空位")
			ArchiveUi.set_button_status(button, &"default")
			button.self_modulate = Color.WHITE

	form_button.text = _text(
		"2 · FORM CONCLUSION  %d/3" % selected_sources.size(),
		"2 · 形成结论  %d/3" % selected_sources.size()
	)
	var source_slots: Array[String] = []
	for source_id: String in selected_sources:
		source_slots.append("◆ " + _localized(_source_by_id(source_id), ""))
	while source_slots.size() < 3:
		source_slots.append("○ " + _text("empty pin", "空白证物钉"))
	source_slots_label.text = _text("EVIDENCE PINS  %d/3\n" % selected_sources.size(), "证物钉  %d/3\n" % selected_sources.size()) + "\n".join(source_slots)
	form_button.disabled = selected_sources.size() < 2
	_levers_ready()
	if status_label.text.is_empty():
		status_label.text = _text(
			"Select a Sealed Archive, then seat it in the role it played in the hidden command chain." if true_case_mode else "Select evidence. A wrong connection will reveal a contradiction without costing progress.",
			"选择一份密封档案，再将它放入它在隐藏命令链中承担的角色。" if true_case_mode else "选择证物。错误关联会显示矛盾，但不会损失进度。"
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
	if selected_sources.has(source_id):
		_play_pin_effect(source_buttons.get(source_id) as Button)


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
		_play_conflict_effect(slot_buttons.get(slot_id) as Button)
		return
	var placed_conclusion_id := selected_conclusion
	placed[slot_id] = selected_conclusion
	GameState.set_story_flag("final_case_placed_" + slot_id)
	status_label.text = _text(
		"Connection seated: " + _localized(conclusion, "") + ".",
		"关联已入槽：" + _localized(conclusion, "") + "。"
	)
	selected_conclusion = ""
	_refresh()
	_play_board_link(
		conclusion_buttons.get(placed_conclusion_id) as Button,
		slot_buttons.get(slot_id) as Button,
		"conclusion_" + slot_id,
		false
	)


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
	_post_sealed_archive_directions()
	ordinary_case_closed.emit()


## 三份密封档案是真结局的前置，但它们在拿到普通结局之前一律不出现，而且
## 之前没有任何东西告诉玩家它们存在、藏在哪。玩家只能盲目重刷餐厅、线路房
## 和图书馆——这才是这段二周目真正难受的地方。结案时直接把清单写进侦探
## 笔记，把"盲目重找"变成"照单核对"。
func _post_sealed_archive_directions() -> void:
	if NoteHud == null or NoteHud.has_clue("sealed_archive_directions"):
		return
	NoteHud.add_clue("sealed_archive_directions", {
		"title": _archive_hint_title(),
		"icon": "icon_note",
		"content": _archive_hint_body(),
		"category": "sealed_archive",
	})


func _archive_hint_title() -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return "密封档案 —— 三处存放点"
	return "SEALED ARCHIVES — Three Locations"


func _archive_hint_body() -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return (
			"结案陈词成立了，但命令是谁写的仍然没有答案。"
			+ "案卷边缘标着三处此前封存的存放点，现在可以打开：\n\n"
			+ "· 餐厅 —— 服务台账下方的暗格\n"
			+ "· 线路房 —— 带假底的柜子\n"
			+ "· 图书馆 —— 上层的紫檀抽屉\n\n"
			+ "三份都取回后，回到分析圆桌重新推演。"
		)
	return (
		"The case closes, but the author of the order is still missing. "
		+ "Three sealed holdings are marked in the margin of the file and "
		+ "will now open:\n\n"
		+ "- Dining Hall: the compartment beneath the service ledger\n"
		+ "- Circuit Room: the cabinet with the false bottom\n"
		+ "- Library: the violet archive drawer on the upper shelf\n\n"
		+ "Bring all three back to the analysis table."
	)


func _levers_ready() -> void:
	var ready := (
		placed_archives.size() == SEALED_ARCHIVE_SPECS.size() and not GameState.has_story_flag("true_ending")
		if true_case_mode
		else placed.size() == SLOT_SPECS.size() and not GameState.has_story_flag("normal_ending")
	)
	lever_button.disabled = not ready
	if ready and not bool(lever_button.get_meta("ready_fx_shown", false)):
		lever_button.set_meta("ready_fx_shown", true)
		_play_lever_ready_effect()
	elif not ready:
		lever_button.set_meta("ready_fx_shown", false)
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
		_play_conflict_effect(archive_slot_buttons.get(slot_id) as Button)
		return
	var placed_archive_id := selected_archive
	placed_archives[slot_id] = selected_archive
	GameState.set_story_flag("true_case_placed_" + slot_id)
	selected_archive = ""
	status_label.text = _text(
		"The second-layer link locks into place.",
		"第二层关联已锁定。"
	)
	_refresh()
	_play_board_link(
		archive_buttons.get(placed_archive_id) as Button,
		archive_slot_buttons.get(slot_id) as Button,
		"archive_" + slot_id,
		true
	)


func _play_pin_effect(button: Button) -> void:
	if button == null or effect_layer == null:
		return
	var center := _effect_point(button)
	OpticalFxRuntime.pulse_ring(
		self,
		effect_layer,
		center,
		Color(0.96, 0.78, 0.34, 0.90),
		18.0,
		1.9,
		0.32
	)
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(1.055, 1.055)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.18)


func _play_conflict_effect(button: Button) -> void:
	if button == null or effect_layer == null:
		return
	var center := _effect_point(button)
	OpticalFxRuntime.pulse_ring(
		self,
		effect_layer,
		center,
		Color(0.92, 0.24, 0.30, 0.92),
		22.0,
		2.25,
		0.36
	)
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "rotation", 0.025, 0.04)
	tween.tween_property(button, "rotation", -0.022, 0.05)
	tween.tween_property(button, "rotation", 0.0, 0.06)


func _play_board_link(
	source_button: Button,
	target_button: Button,
	line_id: String,
	arcane: bool
) -> void:
	if source_button == null or target_button == null or effect_layer == null:
		return
	var start := _effect_point(source_button)
	var finish := _effect_point(target_button)
	var colour := (
		Color(0.72, 0.54, 1.0, 0.90)
		if arcane
		else Color(0.94, 0.72, 0.30, 0.90)
	)
	if connection_lines.has(line_id):
		var old_line := connection_lines[line_id] as Line2D
		if old_line != null and is_instance_valid(old_line):
			old_line.queue_free()
	var line := Line2D.new()
	line.name = "EvidenceConnection_" + line_id
	line.points = PackedVector2Array([start, start])
	line.width = 2.6
	line.default_color = colour
	effect_layer.add_child(line)
	connection_lines[line_id] = line
	target_button.modulate.a = 0.38
	OpticalFxRuntime.trace_beam(
		self,
		line,
		start,
		finish,
		colour,
		2.8,
		0.34,
		0.05
	)
	OpticalFxRuntime.launch_jewel(
		self,
		effect_layer,
		start,
		finish,
		colour,
		0.34,
		func() -> void:
			if is_instance_valid(target_button):
				target_button.modulate.a = 1.0
				_play_pin_effect(target_button)
	)


func _play_lever_ready_effect() -> void:
	if lever_button == null or effect_layer == null:
		return
	var center := _effect_point(lever_button)
	OpticalFxRuntime.pulse_ring(
		self,
		effect_layer,
		center,
		Color(0.72, 0.52, 1.0, 0.92),
		28.0,
		2.25,
		0.46
	)
	lever_button.pivot_offset = lever_button.size * 0.5
	lever_button.scale = Vector2(1.08, 1.08)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lever_button, "scale", Vector2.ONE, 0.24)


func _effect_point(control: Control) -> Vector2:
	var global_point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	return effect_layer.get_global_transform_with_canvas().affine_inverse() * global_point


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


func _slot_position(table_anchor: Vector2, slot_size: Vector2) -> Vector2:
	return (table_canvas.size * table_anchor) - (slot_size * 0.5)


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english


func _apply_table_slot(button: Button, arcane: bool) -> void:
	ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCANE if arcane else ArchiveUi.ROLE_ARCHIVE)
	button.add_theme_stylebox_override("normal", _table_slot_style(arcane, &"default"))
	button.add_theme_stylebox_override("hover", _table_slot_style(arcane, &"hover"))
	button.add_theme_stylebox_override("pressed", _table_slot_style(arcane, &"pressed"))
	button.add_theme_stylebox_override("disabled", _table_slot_style(arcane, &"disabled"))


func _apply_record_button(button: Button, arcane: bool) -> void:
	ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCANE if arcane else ArchiveUi.ROLE_ARCHIVE)
	button.add_theme_stylebox_override("normal", _record_style(arcane, &"default"))
	button.add_theme_stylebox_override("hover", _record_style(arcane, &"hover"))
	button.add_theme_stylebox_override("pressed", _record_style(arcane, &"pressed"))
	button.add_theme_stylebox_override("disabled", _record_style(arcane, &"disabled"))


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


func _drawer_style(arcane: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.045, 0.96) if not arcane else Color(0.06, 0.035, 0.10, 0.96)
	style.border_color = Color(0.55, 0.39, 0.18, 0.92) if not arcane else Color(0.48, 0.30, 0.76, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _table_slot_style(arcane: bool, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var border := Color(0.80, 0.60, 0.24, 0.95) if not arcane else Color(0.69, 0.49, 1.0, 0.96)
	var background := Color(0.038, 0.026, 0.018, 0.90) if not arcane else Color(0.075, 0.036, 0.12, 0.91)
	if state == &"hover":
		border = border.lightened(0.16)
		background = background.lightened(0.13)
	elif state == &"pressed":
		background = background.darkened(0.12)
	elif state == &"disabled":
		border = border.darkened(0.42)
		background = background.darkened(0.20)
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func _record_style(arcane: bool, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background := Color(0.115, 0.082, 0.052, 0.94) if not arcane else Color(0.096, 0.052, 0.15, 0.94)
	var border := Color(0.62, 0.47, 0.23, 0.86) if not arcane else Color(0.58, 0.38, 0.86, 0.88)
	if state == &"hover":
		background = background.lightened(0.10)
		border = border.lightened(0.16)
	elif state == &"pressed":
		background = background.darkened(0.12)
	elif state == &"disabled":
		background = background.darkened(0.24)
		border = border.darkened(0.40)
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.024, 0.018, 0.030, 0.92)
	style.border_color = Color(0.48, 0.35, 0.20, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _empty_file_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.022, 0.062, 0.58)
	style.border_color = Color(0.42, 0.28, 0.66, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
