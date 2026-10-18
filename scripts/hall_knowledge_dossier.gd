extends CanvasLayer

signal recorded(exhibit_id: String)
signal closed

const TOPICS := {
	"ChemistryRoomKnowledge": "chemistry",
	"CircuitRoomKnowledge": "circuit",
	"GreenhouseRoomKnowledge": "greenhouse",
	"DiningHallKnowledge": "time",
	"LibraryRoomKnowledge": "light",
}
const CONCEPT_PLATES := {
	"chemistry": "res://assets/ui/knowledge_plates/chemical_physical.png",
	"circuit": "res://assets/ui/knowledge_plates/closed_circuit.png",
	"greenhouse": "res://assets/ui/knowledge_plates/photosynthesis.png",
	"time": "res://assets/ui/knowledge_plates/independent_time.png",
	"light": "res://assets/ui/knowledge_plates/additive_light.png",
}
const INK := Color("#38291f")
const MUTED_INK := Color("#70543b")

var exhibit: Dictionary = {}
var already_recorded := false
var root_control: Control
var frame: PanelContainer
var title: Label
var source: Label
var status: Label
var artwork: TextureRect
var observation: Label
var principle: Label
var examples: HBoxContainer
var footer: Label
var file_button: Button
var close_button: Button
var motion: Tween


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	CaseLocale.locale_changed.connect(_refresh)
	visible = false
	root_control.hide()


func open_record(record: Dictionary, collected: bool) -> void:
	if not TOPICS.has(str(record.get("id", ""))):
		push_error("Unknown Hall knowledge dossier: " + str(record.get("id", "")))
		return
	exhibit = record
	already_recorded = collected
	_refresh("")
	visible = true
	root_control.show()
	if motion != null and motion.is_valid():
		motion.kill()
	root_control.modulate.a = 0.0
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(root_control, "modulate:a", 1.0, 0.18)
	file_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	if motion != null and motion.is_valid():
		motion.kill()
	visible = false
	root_control.hide()
	closed.emit()


func _file() -> void:
	if not already_recorded:
		already_recorded = true
		recorded.emit(str(exhibit["id"]))
	close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.018, 0.012, 0.03, 0.9)
	root_control.add_child(veil)
	frame = PanelContainer.new()
	frame.name = "KnowledgeDossierFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -466
	frame.offset_right = 466
	frame.offset_top = -320
	frame.offset_bottom = 320
	frame.add_theme_stylebox_override(
		"panel", ArchiveUi.panel_style(Color("#19151f"), Color("#ac8c59"), 2, 6, 0)
	)
	root_control.add_child(frame)
	var margin := _pad(frame, 26)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 4)
	header.add_child(heading)
	source = _label(12, ArchiveUi.COLOR_BRASS)
	heading.add_child(source)
	title = _label(26, ArchiveUi.COLOR_PARCHMENT)
	heading.add_child(title)
	close_button = Button.new()
	close_button.name = "CloseKnowledgeButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_MUTED)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var specimen := PanelContainer.new()
	specimen.custom_minimum_size = Vector2(224, 430)
	specimen.add_theme_stylebox_override(
		"panel", ArchiveUi.panel_style(Color("#24202a"), Color("#705a41"), 1, 4, 3)
	)
	body.add_child(specimen)
	var specimen_column := VBoxContainer.new()
	specimen_column.add_theme_constant_override("separation", 12)
	_pad(specimen, 14).add_child(specimen_column)
	var specimen_heading := _label(12, ArchiveUi.COLOR_BRASS)
	specimen_heading.name = "SpecimenHeading"
	specimen_column.add_child(specimen_heading)
	artwork = TextureRect.new()
	artwork.name = "KnowledgeArtwork"
	artwork.custom_minimum_size = Vector2(192, 256)
	artwork.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specimen_column.add_child(artwork)
	status = _label(15, ArchiveUi.COLOR_PARCHMENT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specimen_column.add_child(status)

	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override(
		"panel", ArchiveUi.panel_style(Color("#dcc99e"), Color("#a58b60"), 1, 3, 0)
	)
	body.add_child(page)
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parchment := AtlasTexture.new()
	parchment.atlas = load("res://assets/ui/ui_note_parchment.png") as Texture2D
	parchment.region = Rect2(256, 384, 512, 512)
	paper.texture = parchment
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper.modulate = Color(0.85, 0.83, 0.79, 0.75)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(paper)
	var page_margin := _pad(page, 22)
	var reading := VBoxContainer.new()
	reading.add_theme_constant_override("separation", 10)
	page_margin.add_child(reading)
	var observation_heading := _label(12, MUTED_INK)
	observation_heading.name = "ObservationHeading"
	reading.add_child(observation_heading)
	observation = _label(16, INK)
	observation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reading.add_child(observation)
	var principle_heading := _label(12, MUTED_INK)
	principle_heading.name = "PrincipleHeading"
	reading.add_child(principle_heading)
	principle = _label(18, INK)
	principle.name = "KnowledgePrinciple"
	principle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	principle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading.add_child(principle)
	var examples_heading := _label(12, MUTED_INK)
	examples_heading.name = "ExamplesHeading"
	reading.add_child(examples_heading)
	examples = HBoxContainer.new()
	examples.name = "KnowledgeExamples"
	examples.add_theme_constant_override("separation", 12)
	reading.add_child(examples)
	for index: int in range(2):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 100
		card.add_theme_stylebox_override(
			"panel", ArchiveUi.panel_style(Color("#ead9b3"), Color("#aa8d5e"), 1, 2, 3)
		)
		examples.add_child(card)
		var copy := _label(15, INK)
		copy.name = "Example%d" % index
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pad(card, 12).add_child(copy)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	column.add_child(actions)
	footer = _label(13, ArchiveUi.COLOR_PARCHMENT)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(footer)
	file_button = Button.new()
	file_button.name = "FileKnowledgeButton"
	file_button.custom_minimum_size = Vector2(250, 48)
	ArchiveUi.apply_button(file_button, ArchiveUi.ROLE_ACTION)
	file_button.pressed.connect(_file)
	actions.add_child(file_button)
	ArchiveUi.wire_focus_cycle([file_button, close_button])


func _refresh(_language: String) -> void:
	if exhibit.is_empty():
		return
	var topic: String = TOPICS[str(exhibit["id"])]
	source.text = CaseLocale.text("knowledge.kicker") + " / " + CaseLocale.line(str(exhibit["title"]))
	title.text = CaseLocale.text("knowledge." + topic + ".title")
	observation.text = CaseLocale.text("knowledge." + topic + ".observation")
	principle.text = CaseLocale.text(str(exhibit["knowledge_key"]))
	artwork.texture = load(CONCEPT_PLATES[topic]) as Texture2D
	status.text = CaseLocale.text("knowledge.recorded" if already_recorded else "knowledge.unfiled")
	footer.text = CaseLocale.text("knowledge.footer")
	file_button.text = CaseLocale.text("knowledge.return" if already_recorded else "knowledge.file")
	for heading_name: String in ["SpecimenHeading", "ObservationHeading", "PrincipleHeading", "ExamplesHeading"]:
		var heading := root_control.find_child(heading_name, true, false) as Label
		heading.text = CaseLocale.text("knowledge." + heading_name)
	for index: int in range(2):
		var copy := examples.find_child("Example%d" % index, true, false) as Label
		copy.text = CaseLocale.text("knowledge." + topic + ".example_%d" % index)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _pad(parent: Control, pixels: int) -> MarginContainer:
	var inset := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, pixels)
	parent.add_child(inset)
	return inset
