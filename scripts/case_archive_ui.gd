class_name CaseArchiveUi
extends CanvasLayer

## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Structural family: sealed resolution record, re-opened for review.
##
## The Case Archive is the one place a finished case can be re-read. Its
## Interface is three calls — is_unlocked / open_archive / close_archive — while
## the Implementation owns tab state, focus, responsive layout, bilingual copy
## and, most importantly, deriving every line from real GameState rather than
## from a second narrative copy that could drift away from the playthrough.

signal archive_closed

const FINAL_CASE_BOARD_SCRIPT: Script = preload("res://scripts/final_case_board.gd")

const ORDINARY_ENDING_FLAG: String = "normal_ending"
const TRUE_ENDING_FLAG: String = "perfect_ending"

const CASE_ROOM_ORDER: Array[String] = [
	"wake_room",
	"floor_1_hub",
	"chemistry_room",
	"greenhouse_room",
	"circuit_room",
	"dining_hall",
	"library",
	"final_deduction_room",
]

# Evidence recorded outside the accusation table still belongs in the archive,
# so these fill the gaps the board's own source specs do not name.
const EXTRA_EVIDENCE_LABELS: Dictionary = {
	"violet_insulating_fiber": {"en": "Violet insulating fiber", "zh": "紫色绝缘纤维"},
	"stopped_midnight_clock": {"en": "Stopped midnight clock", "zh": "停摆的午夜钟"},
	"dining_red_cloth": {"en": "Dining red cloth", "zh": "餐厅红布"},
	"service_corridor_dark_trail": {"en": "Dark trail in the service corridor", "zh": "服务走廊的暗痕"},
	"vault_vision_symbols": {"en": "Vault symbols under Vision", "zh": "视界下的金库符号"},
	"ashford_archive_record": {"en": "Ashford archive record", "zh": "阿什福德档案记录"},
	"final_archive_document": {"en": "Sealed archive document", "zh": "密封档案文件"},
	"mrs_lin_body": {"en": "Dr. Lin's body", "zh": "林博士的遗体"},
	"master_archive_route": {"en": "Master Archive route", "zh": "主档案路线"},
}

const PEOPLE_SPECS: Array[Dictionary] = [
	{
		"flag": "chemistry_butler_interviewed",
		"en": "The Butler",
		"zh": "管家",
		"detail_en": "Service account taken in the Chemistry Room. His supplies staged the diversion.",
		"detail_zh": "在化学室取得服务记录。他的物资布置了那处障眼法。",
	},
	{
		"flag": "mechanic_missing_glove_found",
		"evidence": "mechanic_missing_glove",
		"en": "The Mechanic",
		"zh": "机械师",
		"detail_en": "One safety glove missing from the workshop record; the torn cuff matches it.",
		"detail_zh": "工坊记录中缺少一只安全手套；撕裂的护腕与之吻合。",
	},
	{
		"evidence": "greenhouse_pollen",
		"en": "The Gardener",
		"zh": "园丁",
		"detail_en": "Greenhouse pollen placed the maintenance route through the glasshouse wing.",
		"detail_zh": "温室花粉证明维修路线穿过玻璃温室区。",
	},
	{
		"evidence": "mrs_lin_notebook",
		"en": "Dr. Lin",
		"zh": "林博士",
		"detail_en": "Her final notebook refuses to name a culprit and demands the chain be proven.",
		"detail_zh": "她的最终笔记拒绝直接点名，要求先证明完整的链条。",
	},
]

const SCIENCE_SPECS: Array[Dictionary] = [
	{
		"flag": "library_spectrum_knowledge_learned",
		"en": "Visible spectrum & wavelength",
		"zh": "可见光谱与波长",
		"detail_en": "Colour is wavelength; a filter passes its own band and absorbs the rest.",
		"detail_zh": "颜色即波长；滤光片只透过自身波段，吸收其余部分。",
	},
	{
		"flag": "library_reflection_knowledge_learned",
		"en": "Reflection & the equal-angle law",
		"zh": "反射与等角定律",
		"detail_en": "A mirror returns a beam at the same angle it arrives, so a route can be traced.",
		"detail_zh": "镜面以入射角等于反射角返回光线，因此路径可以被推算。",
	},
	{
		"flag": "library_additive_knowledge_learned",
		"en": "Additive colour mixing",
		"zh": "加色混合",
		"detail_en": "Red, green and blue light combine to white; that is how the archive lock opens.",
		"detail_zh": "红、绿、蓝三色光叠加为白光；档案锁正是据此开启。",
	},
	{
		"flag": "wake_room_oxygen_knowledge",
		"property": "learned_fire_oxygen_rule",
		"en": "Combustion needs oxygen",
		"zh": "燃烧需要氧气",
		"detail_en": "A sealed flame starves; the first door lock tested exactly this.",
		"detail_zh": "被封闭的火焰会熄灭；第一道门锁考的正是这一点。",
	},
	{
		"property": "learned_circuit_rule",
		"en": "Series circuits and the master switch",
		"zh": "串联电路与总闸",
		"detail_en": "A broken series path kills the whole run; restoring it re-lit the estate.",
		"detail_zh": "串联回路一处断开就全线失电；恢复它才让庄园重新通电。",
	},
]

const TAB_SPECS: Array[Dictionary] = [
	{"id": "evidence", "en": "EVIDENCE", "zh": "物证"},
	{"id": "people", "en": "PEOPLE", "zh": "人物"},
	{"id": "timeline", "en": "TIMELINE", "zh": "时间线"},
	{"id": "science", "en": "SCIENCE", "zh": "科学"},
	{"id": "verdict", "en": "VERDICT", "zh": "结论"},
]

var active_section: String = "evidence"
var root: Control
var veil: ColorRect
var frame: Panel
var title_label: Label
var kicker_label: Label
var verdict_stamp: Panel
var tab_row: HBoxContainer
var entry_scroll: ScrollContainer
var entry_column: VBoxContainer
var close_button: Button
var tab_buttons: Dictionary = {}


## True once either ending has been reached. Derived from the story flags the
## endings already persist, so no parallel unlock field and no save migration.
static func is_unlocked() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return false
	var state := loop.root.get_node_or_null("GameState")
	if state == null:
		return false
	return (
		bool(state.call("has_story_flag", TRUE_ENDING_FLAG))
		or bool(state.call("has_story_flag", ORDINARY_ENDING_FLAG))
	)


func _ready() -> void:
	name = "CaseArchiveUI"
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	CaseLocale.locale_changed.connect(_on_locale_changed)
	visible = false


func open_archive() -> void:
	visible = true
	root.visible = true
	_refresh()
	call_deferred("_focus_active_tab")


func close_archive() -> void:
	visible = false
	root.visible = false
	archive_closed.emit()


func _build() -> void:
	root = Control.new()
	root.name = "CaseArchiveRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	veil = ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.006, 0.005, 0.014, 0.94)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(veil)

	ArchiveUi.install_screen_atmosphere(root, {
		"lamp_anchor": Vector2(0.5, 0.24),
		"lamp_strength": 0.20,
		"lamp_radius": 0.56,
		"vignette_strength": 0.58,
		"vignette_radius": 0.34,
		"mote_strength": 0.38,
		"grain_strength": 0.024,
	})

	frame = Panel.new()
	frame.name = "ArchiveFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(ArchiveUi.COLOR_PANEL, ArchiveUi.COLOR_BRASS, 2, 6, 16)
	)
	root.add_child(frame)
	ArchiveUi.install_dossier_chrome(frame, {"accent": ArchiveUi.COLOR_BRASS})

	kicker_label = Label.new()
	kicker_label.name = "ArchiveKicker"
	kicker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kicker_label.add_theme_font_size_override("font_size", 10)
	ArchiveUi.apply_label(kicker_label, &"muted")
	frame.add_child(kicker_label)

	title_label = Label.new()
	title_label.name = "ArchiveTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 20)
	ArchiveUi.apply_label(title_label, &"title")
	frame.add_child(title_label)

	verdict_stamp = ArchiveUi.create_status_stamp(
		frame,
		"ArchiveVerdictStamp",
		"CASE CLOSED",
		ArchiveUi.ROLE_ARCHIVE
	)

	tab_row = HBoxContainer.new()
	tab_row.name = "ArchiveTabs"
	tab_row.add_theme_constant_override("separation", 8)
	frame.add_child(tab_row)
	for spec: Dictionary in TAB_SPECS:
		var section_id := str(spec["id"])
		var tab := Button.new()
		tab.name = "ArchiveTab_" + section_id
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 11)
		ArchiveUi.apply_button(tab, ArchiveUi.ROLE_ARCHIVE)
		tab.pressed.connect(_select_section.bind(section_id))
		tab_row.add_child(tab)
		tab_buttons[section_id] = tab

	entry_scroll = ScrollContainer.new()
	entry_scroll.name = "ArchiveEntryScroll"
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame.add_child(entry_scroll)

	entry_column = VBoxContainer.new()
	entry_column.name = "ArchiveEntryColumn"
	entry_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_column.add_theme_constant_override("separation", 8)
	entry_scroll.add_child(entry_column)

	close_button = Button.new()
	close_button.name = "ArchiveCloseButton"
	close_button.add_theme_font_size_override("font_size", 12)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_ACTION)
	close_button.pressed.connect(close_archive)
	frame.add_child(close_button)

	_fit_layout()
	root.resized.connect(_fit_layout)


func _fit_layout() -> void:
	var view := root.size
	if view.x <= 0.0 or view.y <= 0.0:
		view = Vector2(1024.0, 768.0)
	# Safe margins keep the frame clear of rounded corners and notches on the
	# wide and tall extremes the game ships against.
	var margin_x := clampf(view.x * 0.055, 24.0, 96.0)
	var margin_y := clampf(view.y * 0.055, 20.0, 72.0)
	frame.position = Vector2(margin_x, margin_y)
	frame.size = Vector2(
		maxf(320.0, view.x - margin_x * 2.0),
		maxf(300.0, view.y - margin_y * 2.0)
	)

	var side := 26.0
	var content_width := frame.size.x - side * 2.0
	kicker_label.position = Vector2(side, 18.0)
	kicker_label.size = Vector2(content_width, 16.0)
	title_label.position = Vector2(side, 34.0)
	title_label.size = Vector2(maxf(160.0, content_width - 190.0), 30.0)
	verdict_stamp.position = Vector2(side + content_width - 182.0, 38.0)
	verdict_stamp.size = Vector2(182.0, 26.0)

	tab_row.position = Vector2(side, 76.0)
	tab_row.size = Vector2(content_width, 44.0)

	var footer_height := 44.0
	var scroll_top := 132.0
	entry_scroll.position = Vector2(side, scroll_top)
	entry_scroll.size = Vector2(
		content_width,
		maxf(120.0, frame.size.y - scroll_top - footer_height - 26.0)
	)
	entry_column.custom_minimum_size = Vector2(content_width - 16.0, 0.0)

	close_button.size = Vector2(minf(200.0, content_width), footer_height)
	close_button.position = Vector2(
		side + content_width - close_button.size.x,
		frame.size.y - footer_height - 14.0
	)


func _select_section(section_id: String) -> void:
	active_section = section_id
	_refresh()
	var tab := tab_buttons.get(section_id) as Button
	if tab != null:
		tab.grab_focus()


func _on_locale_changed(_language: String = "") -> void:
	_refresh()


func _refresh() -> void:
	var chinese := CaseLocale.is_chinese()
	kicker_label.text = (
		"案件 01 · 阿什福德停电 · 已归档" if chinese
		else "CASE 01  ·  ASHFORD BLACKOUT  ·  FILED"
	)
	title_label.text = "案件档案" if chinese else "CASE ARCHIVE"
	close_button.text = "返回" if chinese else "CLOSE ARCHIVE"

	var true_case := GameState.has_story_flag(TRUE_ENDING_FLAG)
	ArchiveUi.set_status_stamp(
		verdict_stamp,
		(
			("真相记录 · 完整结案" if chinese else "TRUE RECORD · COMPLETE")
			if true_case
			else ("密封复查 · 阶段结案" if chinese else "SEALED REVIEW · PARTIAL")
		),
		ArchiveUi.ROLE_ARCANE if true_case else ArchiveUi.ROLE_ACTION
	)

	for spec: Dictionary in TAB_SPECS:
		var section_id := str(spec["id"])
		var tab := tab_buttons.get(section_id) as Button
		if tab == null:
			continue
		tab.text = str(spec["zh" if chinese else "en"])
		ArchiveUi.apply_button(
			tab,
			ArchiveUi.ROLE_ARCANE if section_id == active_section else ArchiveUi.ROLE_ARCHIVE
		)

	for child: Node in entry_column.get_children():
		child.queue_free()
	var entries := _section_entries(active_section)
	if entries.is_empty():
		entry_column.add_child(
			_build_entry(
				"—",
				"本分类没有记录在案的条目。" if chinese else "No records were filed under this heading.",
				false
			)
		)
		return
	for entry: Dictionary in entries:
		entry_column.add_child(
			_build_entry(str(entry["title"]), str(entry["detail"]), bool(entry.get("recorded", true)))
		)


func _build_entry(entry_title: String, detail: String, recorded: bool) -> Panel:
	var accent := ArchiveUi.COLOR_BRASS if recorded else Color(0.36, 0.31, 0.28, 0.86)
	var card := Panel.new()
	card.name = "ArchiveEntry"
	card.custom_minimum_size = Vector2(0.0, 60.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(
			ArchiveUi.COLOR_PANEL_INLAY if recorded else Color(0.040, 0.030, 0.028, 0.94),
			accent,
			1,
			4,
			4
		)
	)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var heading := Label.new()
	heading.name = "ArchiveEntryTitle"
	heading.text = entry_title
	heading.add_theme_font_size_override("font_size", 12)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArchiveUi.apply_label(heading, &"body" if recorded else &"muted")
	if recorded:
		heading.add_theme_color_override("font_color", ArchiveUi.COLOR_GOLD)
	column.add_child(heading)

	var body := Label.new()
	body.name = "ArchiveEntryDetail"
	body.text = detail
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArchiveUi.apply_label(body, &"muted")
	column.add_child(body)
	return card


func _section_entries(section_id: String) -> Array[Dictionary]:
	match section_id:
		"evidence":
			return _evidence_entries()
		"people":
			return _people_entries()
		"timeline":
			return _timeline_entries()
		"science":
			return _science_entries()
		"verdict":
			return _verdict_entries()
	return []


func _evidence_entries() -> Array[Dictionary]:
	var chinese := CaseLocale.is_chinese()
	var entries: Array[Dictionary] = []
	for evidence_id: String in GameState.evidence_items:
		entries.append({
			"title": _evidence_label(evidence_id, chinese),
			"detail": _evidence_detail(evidence_id, chinese),
			"recorded": true,
		})
	return entries


## What a record is worth is which conclusion it feeds, so the detail line is
## read back out of the accusation table rather than written twice.
func _evidence_detail(evidence_id: String, chinese: bool) -> String:
	var source_ids: Array[String] = []
	for spec: Dictionary in FINAL_CASE_BOARD_SCRIPT.SOURCE_SPECS:
		if str(spec.get("evidence", "")) == evidence_id:
			source_ids.append(str(spec["id"]))
	var conclusions: Array[String] = []
	for conclusion: Dictionary in FINAL_CASE_BOARD_SCRIPT.CONCLUSION_SPECS:
		for source_id: String in conclusion["sources"] as Array:
			if source_ids.has(source_id):
				conclusions.append(str(conclusion["zh" if chinese else "en"]))
				break
	if conclusions.is_empty():
		return (
			"背景记录，未直接进入终局圆桌。" if chinese
			else "Background record; it never entered the analysis table directly."
		)
	return (
		"支撑结论：" + ", ".join(conclusions) if chinese
		else "Supports: " + ", ".join(conclusions)
	)


func _evidence_label(evidence_id: String, chinese: bool) -> String:
	# The accusation table already names every source it accepts; reusing those
	# strings keeps the archive and the board from drifting into two vocabularies.
	for spec: Dictionary in FINAL_CASE_BOARD_SCRIPT.SOURCE_SPECS:
		if str(spec.get("evidence", "")) == evidence_id:
			return str(spec["zh" if chinese else "en"])
	if EXTRA_EVIDENCE_LABELS.has(evidence_id):
		return str((EXTRA_EVIDENCE_LABELS[evidence_id] as Dictionary)["zh" if chinese else "en"])
	return evidence_id.capitalize()


func _people_entries() -> Array[Dictionary]:
	var chinese := CaseLocale.is_chinese()
	var entries: Array[Dictionary] = []
	for spec: Dictionary in PEOPLE_SPECS:
		var recorded := false
		if spec.has("flag") and GameState.has_story_flag(str(spec["flag"])):
			recorded = true
		if spec.has("evidence") and GameState.has_evidence(str(spec["evidence"])):
			recorded = true
		entries.append({
			"title": str(spec["zh" if chinese else "en"]),
			"detail": (
				str(spec["detail_zh" if chinese else "detail_en"])
				if recorded
				else ("本案未取得该人物的记录。" if chinese else "No record was taken for this person.")
			),
			"recorded": recorded,
		})
	return entries


func _timeline_entries() -> Array[Dictionary]:
	var chinese := CaseLocale.is_chinese()
	var entries: Array[Dictionary] = []
	var step := 0
	for room_id: String in CASE_ROOM_ORDER:
		var visited := bool(GameState.visited_rooms.get(room_id, false))
		if not visited:
			continue
		step += 1
		var completed := bool(GameState.completed_rooms.get(room_id, false))
		entries.append({
			"title": "%02d · %s" % [step, CaseLocale.room_name(room_id)],
			"detail": (
				("现场调查完成。" if chinese else "Site investigation completed.")
				if completed
				else ("已进入现场。" if chinese else "Entered and surveyed.")
			),
			"recorded": completed,
		})
	return entries


func _science_entries() -> Array[Dictionary]:
	var chinese := CaseLocale.is_chinese()
	var entries: Array[Dictionary] = []
	for spec: Dictionary in SCIENCE_SPECS:
		var recorded := false
		if spec.has("flag") and GameState.has_story_flag(str(spec["flag"])):
			recorded = true
		if spec.has("property") and bool(GameState.get(str(spec["property"]))):
			recorded = true
		entries.append({
			"title": str(spec["zh" if chinese else "en"]),
			"detail": (
				str(spec["detail_zh" if chinese else "detail_en"])
				if recorded
				else ("本次调查未记录这条依据。" if chinese else "This principle was not recorded in this run.")
			),
			"recorded": recorded,
		})
	return entries


func _verdict_entries() -> Array[Dictionary]:
	var chinese := CaseLocale.is_chinese()
	var true_case := GameState.has_story_flag(TRUE_ENDING_FLAG)
	var entries: Array[Dictionary] = [
		{
			"title": CaseLocale.text("ending.title_true" if true_case else "ending.title_ordinary"),
			"detail": CaseLocale.text("ending.summary_true" if true_case else "ending.summary_ordinary"),
			"recorded": true,
		},
		{
			"title": "阶段结案" if chinese else "Partial closure",
			"detail": (
				"执行者已确认，指令来源仍未追溯。" if chinese
				else "The executor was identified; the source of the order was left untraced."
			),
			"recorded": GameState.has_story_flag(ORDINARY_ENDING_FLAG),
		},
		{
			"title": "完整结案" if chinese else "Complete closure",
			"detail": (
				"密封档案已复查，伪造指令链被揭露。" if chinese
				else "The sealed archive was reviewed and the forged command chain was exposed."
			),
			"recorded": true_case,
		},
	]
	return entries


func _focus_active_tab() -> void:
	var tab := tab_buttons.get(active_section) as Button
	if tab != null and tab.is_visible_in_tree():
		tab.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_archive()
		get_viewport().set_input_as_handled()
