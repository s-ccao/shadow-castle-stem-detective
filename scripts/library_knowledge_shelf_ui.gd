class_name LibraryKnowledgeShelfUI
extends CanvasLayer

signal recorded(knowledge_id: String)
signal closed

const KNOWLEDGE_RECORDS: Dictionary = {
	"spectrum": {
		"title_en": "VISIBLE SPECTRUM & WAVELENGTH",
		"title_zh": "可见光谱与波长",
		"shelf_en": "TALL WAVELENGTH CASE",
		"shelf_zh": "高窄波长档案柜",
		"principle_en": "Wavelength is the distance between matching points on successive waves. Different visible colors occupy different wavelength ranges.",
		"principle_zh": "波长是相邻波中对应点之间的距离。不同的可见光颜色占据不同的波长范围。",
		"body_en": "At the visible spectrum's longer-wavelength end lies red light. Moving across the spectrum, green is shorter than red, and blue is shorter than green. The order used by the archive is therefore RED → GREEN → BLUE when arranging from longest wavelength to shortest.",
		"body_zh": "红光位于可见光谱的长波端。沿光谱移动时，绿光的波长比红光短，蓝光又比绿光短。因此，档案按照波长从长到短排列时使用：红 → 绿 → 蓝。",
		"example_en": "FIELD REFERENCE  ·  Long → short:  RED  →  GREEN  →  BLUE",
		"example_zh": "现场参考 · 从长到短：红 → 绿 → 蓝",
	},
	"reflection": {
		"title_en": "REFLECTION, ABSORPTION & COLOR",
		"title_zh": "反射、吸收与颜色",
		"shelf_en": "VIOLET REFLECTION CABINET",
		"shelf_zh": "紫色反射档案柜",
		"principle_en": "Under white light, matter absorbs some wavelengths and reflects others. The reflected wavelengths that reach the eye determine the color we see.",
		"principle_zh": "在白光照射下，物质会吸收部分波长并反射其他波长。进入眼睛的反射光决定了我们看见的颜色。",
		"body_en": "A healthy green leaf contains pigments that absorb much of the red and blue light used in photosynthesis. More green light is reflected toward the observer, so the leaf appears green. Visible color is evidence of reflection—not absorption.",
		"body_zh": "健康绿叶中的色素会吸收许多用于光合作用的红光和蓝光。较多绿光被反射到观察者眼中，因此叶片呈绿色。可见颜色代表被反射的光，而不是被吸收的光。",
		"example_en": "FIELD REFERENCE  ·  RED: absorb  ·  GREEN: reflect  ·  BLUE: absorb",
		"example_zh": "现场参考 · 红：吸收 · 绿：反射 · 蓝：吸收",
	},
	"additive": {
		"title_en": "ADDITIVE COLOR MIXING",
		"title_zh": "加色混合",
		"shelf_en": "REINFORCED LIGHT ARCHIVE",
		"shelf_zh": "加固光学档案架",
		"principle_en": "Light sources add their emitted energy. This differs from pigments, which remove wavelengths from reflected light.",
		"principle_zh": "光源会叠加它们发出的能量。这与颜料混合不同；颜料会从反射光中去除部分波长。",
		"body_en": "Green plus blue light produces cyan. Red plus blue produces magenta. When red, green and blue emitters contribute together at similar strength, the result approaches white light. These are additive—not paint—relationships.",
		"body_zh": "绿光加蓝光形成青光；红光加蓝光形成品红光；红、绿、蓝三个发光通道以近似强度共同叠加时，结果接近白光。这是光的加色关系，不是颜料混合。",
		"example_en": "FIELD REFERENCE  ·  G+B=CYAN  ·  R+B=MAGENTA  ·  R+G+B=WHITE",
		"example_zh": "现场参考 · 绿+蓝=青 · 红+蓝=品红 · 红+绿+蓝=白",
	},
}

var knowledge_id := ""
var knowledge_recorded := false
var root_control: Control
var frame: Panel
var shelf_label: Label
var title_label: Label
var principle_label: Label
var body_label: Label
var example_label: Label
var status_label: Label
var record_button: Button
var close_button: Button


func _ready() -> void:
	layer = 71
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	visible = false
	root_control.visible = false


func open_knowledge(next_knowledge_id: String, already_recorded: bool) -> void:
	if not KNOWLEDGE_RECORDS.has(next_knowledge_id):
		return
	knowledge_id = next_knowledge_id
	knowledge_recorded = already_recorded
	_refresh_copy()
	visible = true
	root_control.visible = true
	root_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	frame.scale = Vector2(0.975, 0.975)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, 0.22)
	call_deferred("_focus_primary")


func record_current_knowledge() -> void:
	if knowledge_id.is_empty():
		return
	if not knowledge_recorded:
		knowledge_recorded = true
		recorded.emit(knowledge_id)
	status_label.text = _text("KNOWLEDGE FILED  ·  QUESTION TERMINAL UNLOCKED", "知识已归档 · 问题终端已解锁")
	status_label.add_theme_color_override("font_color", Color(0.64, 0.91, 0.55, 1.0))
	record_button.text = _text("KNOWLEDGE RECORDED", "知识已记录")
	record_button.disabled = true


func close() -> void:
	if not visible:
		return
	visible = false
	root_control.visible = false
	closed.emit()


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "LibraryKnowledgeShelfRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.006, 0.014, 0.92)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(veil)

	frame = Panel.new()
	frame.name = "KnowledgeBookFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -390.0
	frame.offset_top = -292.0
	frame.offset_right = 390.0
	frame.offset_bottom = 292.0
	frame.pivot_offset = Vector2(390.0, 292.0)
	frame.add_theme_stylebox_override("panel", _frame_style())
	root_control.add_child(frame)

	var left_cover := Panel.new()
	left_cover.name = "ShelfSourcePanel"
	left_cover.position = Vector2(36.0, 36.0)
	left_cover.size = Vector2(224.0, 500.0)
	left_cover.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.045, 0.026, 0.98), Color(0.58, 0.40, 0.17, 0.92)))
	frame.add_child(left_cover)
	var glyph := Label.new()
	glyph.name = "ArchiveBookGlyph"
	glyph.text = "▤"
	glyph.position = Vector2(50.0, 72.0)
	glyph.size = Vector2(124.0, 150.0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 80)
	glyph.add_theme_color_override("font_color", Color(0.70, 0.49, 0.21, 1.0))
	glyph.add_theme_color_override("font_outline_color", Color(0.025, 0.012, 0.008, 1.0))
	glyph.add_theme_constant_override("outline_size", 6)
	left_cover.add_child(glyph)
	var source_kicker := _make_label("ShelfKicker", Vector2(20.0, 242.0), Vector2(184.0, 22.0), 10, Color(0.90, 0.72, 0.38, 1.0))
	source_kicker.text = _text("KNOWLEDGE SOURCE", "知识来源")
	source_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_cover.add_child(source_kicker)
	shelf_label = _make_label("ShelfLabel", Vector2(22.0, 274.0), Vector2(180.0, 92.0), 14, Color(0.92, 0.84, 0.68, 1.0))
	shelf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shelf_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shelf_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_cover.add_child(shelf_label)
	var source_note := _make_label("SourceNote", Vector2(24.0, 384.0), Vector2(176.0, 76.0), 10, Color(0.66, 0.59, 0.48, 1.0))
	source_note.text = _text("This shelf teaches the concept. The distant desk will test whether you can apply it.", "这座书架负责讲解知识。远处的桌面终端将测试你能否应用它。")
	source_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_cover.add_child(source_note)

	var page := Panel.new()
	page.name = "KnowledgePage"
	page.position = Vector2(278.0, 36.0)
	page.size = Vector2(466.0, 500.0)
	page.add_theme_stylebox_override("panel", _panel_style(Color(0.77, 0.67, 0.46, 0.98), Color(0.39, 0.25, 0.10, 0.96)))
	frame.add_child(page)
	var page_kicker := _make_label("PageKicker", Vector2(34.0, 22.0), Vector2(398.0, 20.0), 10, Color(0.36, 0.23, 0.09, 1.0))
	page_kicker.text = _text("ASHFORD LIBRARY · FIELD KNOWLEDGE", "阿什福德图书馆 · 现场知识")
	page_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(page_kicker)
	title_label = _make_label("KnowledgeTitle", Vector2(34.0, 50.0), Vector2(398.0, 54.0), 21, Color(0.18, 0.095, 0.035, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(title_label)
	var divider := ColorRect.new()
	divider.position = Vector2(74.0, 112.0)
	divider.size = Vector2(318.0, 2.0)
	divider.color = Color(0.38, 0.24, 0.08, 0.62)
	page.add_child(divider)
	principle_label = _make_label("Principle", Vector2(48.0, 130.0), Vector2(370.0, 92.0), 14, Color(0.23, 0.14, 0.065, 1.0))
	principle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	principle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	principle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(principle_label)
	body_label = _make_label("KnowledgeBody", Vector2(48.0, 228.0), Vector2(370.0, 142.0), 13, Color(0.25, 0.16, 0.075, 1.0))
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(body_label)
	example_label = _make_label("FieldReference", Vector2(38.0, 382.0), Vector2(390.0, 52.0), 11, Color(0.30, 0.16, 0.055, 1.0))
	example_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	example_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	example_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(example_label)

	status_label = _make_label("KnowledgeStatus", Vector2(36.0, 542.0), Vector2(500.0, 28.0), 10, Color(0.72, 0.62, 0.48, 1.0))
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(status_label)
	record_button = Button.new()
	record_button.name = "RecordKnowledgeButton"
	record_button.position = Vector2(548.0, 540.0)
	record_button.size = Vector2(180.0, 34.0)
	_apply_button_style(record_button)
	record_button.pressed.connect(record_current_knowledge)
	frame.add_child(record_button)
	close_button = Button.new()
	close_button.name = "CloseKnowledgeButton"
	close_button.text = "×"
	close_button.position = Vector2(714.0, 18.0)
	close_button.size = Vector2(44.0, 44.0)
	_apply_button_style(close_button)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(close)
	frame.add_child(close_button)


func _refresh_copy() -> void:
	var record := KNOWLEDGE_RECORDS[knowledge_id] as Dictionary
	var suffix := "zh" if _is_chinese() else "en"
	shelf_label.text = str(record["shelf_" + suffix])
	title_label.text = str(record["title_" + suffix])
	principle_label.text = str(record["principle_" + suffix])
	body_label.text = str(record["body_" + suffix])
	example_label.text = str(record["example_" + suffix])
	if knowledge_recorded:
		status_label.text = _text("KNOWLEDGE ALREADY FILED", "知识已归档")
		status_label.add_theme_color_override("font_color", Color(0.64, 0.87, 0.55, 1.0))
		record_button.text = _text("KNOWLEDGE RECORDED", "知识已记录")
		record_button.disabled = true
	else:
		status_label.text = _text("Read the shelf record, then file it before visiting the question terminal.", "阅读书架记录，然后归档，再前往问题终端。")
		status_label.add_theme_color_override("font_color", Color(0.72, 0.62, 0.48, 1.0))
		record_button.text = _text("FILE KNOWLEDGE", "归档知识")
		record_button.disabled = false


func _focus_primary() -> void:
	if record_button != null and not record_button.disabled:
		record_button.grab_focus()
	else:
		close_button.grab_focus()


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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_button_style(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.94, 0.82, 0.54, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(false, false))
	button.add_theme_stylebox_override("hover", _button_style(true, false))
	button.add_theme_stylebox_override("focus", _button_style(true, false))
	button.add_theme_stylebox_override("pressed", _button_style(true, true))
	button.add_theme_stylebox_override("disabled", _button_style(false, false))


func _button_style(highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.075, 0.027, 0.98)
	if highlighted:
		style.bg_color = Color(0.22, 0.13, 0.038, 1.0)
	if pressed:
		style.bg_color = Color(0.07, 0.04, 0.02, 1.0)
	style.border_color = Color(0.95, 0.73, 0.30, 1.0 if highlighted else 0.78)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.35, 0.16, 0.02, 0.28)
	style.shadow_size = 6 if highlighted else 3
	return style


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.012, 0.025, 0.99)
	style.border_color = Color(0.76, 0.57, 0.24, 0.98)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0.0, 7.0)
	return style


func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _is_chinese() -> bool:
	var locale := get_node_or_null("/root/CaseLocale")
	return locale != null and bool(locale.call("is_chinese"))


func _text(english: String, chinese: String) -> String:
	return chinese if _is_chinese() else english
