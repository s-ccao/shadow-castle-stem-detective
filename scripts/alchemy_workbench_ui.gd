## Hallmark · pre-emit critique: P5 H5 E5 S5 R4 V5
## A single, diegetic workbench. Formula archive, reagent rack, reaction array,
## result and actions share one piece of authored pixel art instead of competing panels.
class_name AlchemyWorkbenchUI
extends CanvasLayer

signal closed

const RECIPE_ORDER: Array[String] = ["recipe_swift", "recipe_vision"]
const VIOLET_SEAL := "violet_seal"
const SOURCE_SIZE := 1254.0

# Every interactive slot maps to a visibly framed area in alchemy_workbench_clean.png.
const FORMULA_SLOT_RECTS: Array[Rect2] = [
	Rect2(0.061, 0.257, 0.245, 0.058),
	Rect2(0.061, 0.339, 0.245, 0.058),
]
const REAGENT_SLOT_RECTS: Array[Rect2] = [
	Rect2(0.061, 0.421, 0.245, 0.058),
	Rect2(0.061, 0.503, 0.245, 0.058),
	Rect2(0.061, 0.585, 0.245, 0.058),
]
const REACTION_SLOT_RECTS: Array[Rect2] = [
	Rect2(0.505, 0.268, 0.105, 0.105),
	Rect2(0.385, 0.391, 0.105, 0.105),
	Rect2(0.621, 0.391, 0.105, 0.105),
	Rect2(0.505, 0.516, 0.105, 0.105),
]
const PRODUCT_RECT := Rect2(0.801, 0.394, 0.128, 0.128)
const CAPTION_PLAQUE_Z := 1
const CAPTION_TEXT_Z := 2
const RESET_BUTTON_RECT := Rect2(0.129, 0.842, 0.158, 0.049)
const EXTRACT_BUTTON_RECT := Rect2(0.565, 0.830, 0.200, 0.061)
const CLOSE_BUTTON_RECT := Rect2(0.796, 0.842, 0.087, 0.049)

var chemistry_room: Node
var root: Control
var safe_area: Control
var workbench_canvas: Control
var archive_label: Label
var title_label: Label
var subtitle_label: Label
var product_label: Label
var product_heading_plaque: Panel
var product_caption_plaque: Panel
var product_image: TextureRect
var product_name: Label
var product_description: Label
var reaction_label: Label
var reaction_state_label: Label
var status_heading: Label
var status_label: Label
var reset_button: Button
var extract_button: Button
var close_button: Button
var extraction_effect_layer: Control
var extraction_beams: Array[Line2D] = []
var extracting := false

var selected_recipe_id := ""
var selected_material_id := ""
var reaction_nodes: Array[String] = ["", "", "", ""]
var recipe_buttons: Dictionary = {}
var reagent_buttons: Dictionary = {}
var reagent_icons: Dictionary = {}
var node_buttons: Array[Button] = []
var node_icons: Array[TextureRect] = []
var node_labels: Array[Label] = []
var status_is_error := false
var recipe_icons: Dictionary = {}


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_scene()
	_build_dynamic_controls()
	_build_extraction_effect_layer()
	_style_static_controls()
	_apply_safe_area()
	root.resized.connect(_apply_safe_area)
	GameState.state_changed.connect(_refresh)
	CaseLocale.locale_changed.connect(_on_locale_changed)
	visible = false


func open(room: Node) -> void:
	chemistry_room = room
	extracting = false
	for old_beam: Line2D in extraction_beams:
		if old_beam != null and is_instance_valid(old_beam):
			old_beam.queue_free()
	extraction_beams.clear()
	selected_recipe_id = ""
	selected_material_id = ""
	_reset_reaction_nodes()
	visible = true
	root.visible = true
	_set_status(_text("Choose a formula. Then place its reagents into the three brass sockets.", "选择配方，再把试剂放入三个黄铜槽位。"))
	_refresh()
	call_deferred("_focus_opening_control")


func close() -> void:
	if not visible:
		return
	visible = false
	root.visible = false
	closed.emit()


func _bind_scene() -> void:
	root = $AlchemyRoot
	safe_area = $AlchemyRoot/SafeArea
	workbench_canvas = $AlchemyRoot/SafeArea/WorkbenchCanvas
	archive_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/ArchiveLabel
	title_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/TitleLabel
	subtitle_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/SubtitleLabel
	product_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/ProductLabel
	product_image = $AlchemyRoot/SafeArea/WorkbenchCanvas/ProductImage
	product_name = $AlchemyRoot/SafeArea/WorkbenchCanvas/ProductName
	product_description = $AlchemyRoot/SafeArea/WorkbenchCanvas/ProductDescription
	reaction_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/ReactionLabel
	reaction_state_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/ReactionStateLabel
	status_heading = $AlchemyRoot/SafeArea/WorkbenchCanvas/StatusHeading
	status_label = $AlchemyRoot/SafeArea/WorkbenchCanvas/StatusLabel
	reset_button = $AlchemyRoot/SafeArea/WorkbenchCanvas/ResetNodesButton
	extract_button = $AlchemyRoot/SafeArea/WorkbenchCanvas/ExtractButton
	close_button = $AlchemyRoot/SafeArea/WorkbenchCanvas/CloseAlchemyButton


func _style_static_controls() -> void:
	for label: Label in [archive_label, subtitle_label, product_label, product_description, reaction_label, reaction_state_label, status_heading, status_label]:
		ArchiveUi.apply_label(label, &"body")
	for label: Label in [title_label, product_name]:
		ArchiveUi.apply_label(label, &"title")
	_install_caption_plaques()
	# The authored lower tray is parchment, so it needs ink rather than the normal
	# light-on-dark archive copy used elsewhere in the game.
	for label: Label in [reaction_label, reaction_state_label, status_heading, status_label]:
		label.add_theme_color_override("font_color", Color(0.20, 0.105, 0.045, 1.0))
	ArchiveUi.apply_button(reset_button, ArchiveUi.ROLE_ARCHIVE)
	ArchiveUi.apply_button(extract_button, ArchiveUi.ROLE_ACTION)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_ARCHIVE)
	# These controls are hit targets over buttons painted into the workbench itself.
	# Their visual states must illuminate that authored hardware, never replace it with
	# a second, generic button asset.
	_apply_diegetic_action_button(reset_button, Color(0.86, 0.61, 0.24, 1.0))
	_apply_diegetic_action_button(extract_button, Color(0.38, 0.92, 0.48, 1.0))
	_apply_diegetic_action_button(close_button, Color(0.72, 0.76, 0.86, 1.0))
	reset_button.pressed.connect(_clear_nodes)
	extract_button.pressed.connect(_extract_potion)
	close_button.pressed.connect(close)


func _build_dynamic_controls() -> void:
	for recipe_id: String in RECIPE_ORDER:
		var button := Button.new()
		button.name = "Formula_" + recipe_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = _text("Load this formula", "载入该配方")
		_apply_slot_button(button, &"formula", false)
		button.pressed.connect(_choose_recipe.bind(recipe_id))
		workbench_canvas.add_child(button)
		recipe_buttons[recipe_id] = button

		var formula_icon := TextureRect.new()
		formula_icon.name = "FormulaIcon_" + recipe_id
		formula_icon.texture = load(GameState.get_item_texture_path(recipe_id)) as Texture2D
		formula_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		formula_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		formula_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		formula_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		formula_icon.z_index = 2
		workbench_canvas.add_child(formula_icon)
		recipe_icons[recipe_id] = formula_icon

	for index: int in range(REACTION_SLOT_RECTS.size()):
		var button := Button.new()
		button.name = "ReactionSocket_%d" % (index + 1)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = _text("Seat the selected reagent here", "将已选试剂放入此槽")
		_apply_slot_button(button, &"socket", false)
		button.pressed.connect(_press_reaction_node.bind(index))
		workbench_canvas.add_child(button)
		node_buttons.append(button)

		var icon := TextureRect.new()
		icon.name = "ReactionIcon_%d" % (index + 1)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 2
		workbench_canvas.add_child(icon)
		node_icons.append(icon)

		var label := Label.new()
		label.name = "ReactionName_%d" % (index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 3
		ArchiveUi.apply_label(label, &"body")
		workbench_canvas.add_child(label)
		node_labels.append(label)
	_wire_focus_neighbors()


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	var left: float = maxf(14.0, float(safe.position.x))
	var top: float = maxf(14.0, float(safe.position.y))
	var right: float = maxf(14.0, float(window_size.x - safe.end.x))
	var bottom: float = maxf(14.0, float(window_size.y - safe.end.y))
	safe_area.position = Vector2(left, top)
	safe_area.size = Vector2(maxf(1.0, root.size.x - left - right), maxf(1.0, root.size.y - top - bottom))
	_layout_workbench()


func _layout_workbench() -> void:
	if safe_area.size.x <= 1.0 or safe_area.size.y <= 1.0:
		return
	var side := minf(safe_area.size.x, safe_area.size.y) * 0.985
	workbench_canvas.size = Vector2.ONE * side
	workbench_canvas.position = (safe_area.size - workbench_canvas.size) * 0.5
	_layout_static_controls()
	_layout_dynamic_controls()


func _layout_static_controls() -> void:
	# These rectangles deliberately follow the artwork's existing placards, rails and
	# parchment. Keep copy out of the illustrated machinery: it reads as an overlay,
	# and becomes illegible once the workbench scales down to the in-game window.
	_layout_control(archive_label, Rect2(0.064, 0.219, 0.240, 0.025))
	_layout_control(title_label, Rect2(0.324, 0.148, 0.352, 0.038))
	_layout_control(subtitle_label, Rect2(0.318, 0.199, 0.366, 0.021))
	_layout_control(product_label, Rect2(0.786, 0.360, 0.158, 0.024))
	_layout_control(product_image, PRODUCT_RECT)
	_layout_control(product_name, Rect2(0.786, 0.536, 0.158, 0.030))
	_layout_control(product_description, Rect2(0.786, 0.568, 0.158, 0.030))
	_layout_control(product_heading_plaque, Rect2(0.780, 0.354, 0.170, 0.036))
	_layout_control(product_caption_plaque, Rect2(0.780, 0.530, 0.170, 0.074))
	_layout_control(reaction_state_label, Rect2(0.405, 0.686, 0.290, 0.024))
	_layout_control(status_heading, Rect2(0.400, 0.716, 0.300, 0.019))
	_layout_control(status_label, Rect2(0.355, 0.744, 0.600, 0.036))
	_layout_control(reset_button, RESET_BUTTON_RECT)
	_layout_control(extract_button, EXTRACT_BUTTON_RECT)
	_layout_control(close_button, CLOSE_BUTTON_RECT)

	archive_label.add_theme_font_size_override("font_size", _scaled_font(11))
	title_label.add_theme_font_size_override("font_size", _scaled_font(20))
	subtitle_label.add_theme_font_size_override("font_size", _scaled_font(10))
	product_label.add_theme_font_size_override("font_size", _scaled_font(10))
	product_name.add_theme_font_size_override("font_size", _scaled_font(11))
	product_description.add_theme_font_size_override("font_size", _scaled_font(8))
	reaction_label.add_theme_font_size_override("font_size", _scaled_font(9))
	reaction_state_label.add_theme_font_size_override("font_size", _scaled_font(9))
	status_heading.add_theme_font_size_override("font_size", _scaled_font(10))
	status_label.add_theme_font_size_override("font_size", _scaled_font(10))
	for button: Button in [reset_button, extract_button, close_button]:
		button.add_theme_font_size_override("font_size", _scaled_font(11))
		button.pivot_offset = button.size * 0.5


func _layout_dynamic_controls() -> void:
	for index: int in range(RECIPE_ORDER.size()):
		var recipe_id := RECIPE_ORDER[index]
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button != null:
			_layout_control(button, FORMULA_SLOT_RECTS[index])
			button.add_theme_font_size_override("font_size", _scaled_font(10))
			button.pivot_offset = button.size * 0.5
			var formula_icon := recipe_icons.get(recipe_id) as TextureRect
			if formula_icon != null:
				var icon_size := Vector2(button.size.y * 0.72, button.size.y * 0.72)
				formula_icon.size = icon_size
				formula_icon.position = button.position + Vector2(
					button.size.x * 0.045,
					(button.size.y - icon_size.y) * 0.5
				)
				_reserve_icon_gutter(button, button.size.x * 0.045 + icon_size.x)
	for index: int in range(node_buttons.size()):
		var rect := REACTION_SLOT_RECTS[index]
		_layout_control(node_buttons[index], rect)
		node_buttons[index].add_theme_font_size_override("font_size", _scaled_font(8))
		node_buttons[index].pivot_offset = node_buttons[index].size * 0.5
		var center := node_buttons[index].position + node_buttons[index].size * 0.5
		var icon_size := node_buttons[index].size * 0.58
		node_icons[index].size = icon_size
		node_icons[index].position = center - icon_size * 0.5 - Vector2(0.0, icon_size.y * 0.08)
		node_labels[index].size = Vector2(node_buttons[index].size.x * 0.90, node_buttons[index].size.y * 0.22)
		node_labels[index].position = center + Vector2(-node_labels[index].size.x * 0.5, node_buttons[index].size.y * 0.22)
		node_labels[index].add_theme_font_size_override("font_size", _scaled_font(8))
	for item_id: Variant in reagent_buttons.keys():
		var button: Button = reagent_buttons[item_id] as Button
		var icon: TextureRect = reagent_icons.get(item_id) as TextureRect
		var reagent_index := reagent_buttons.keys().find(item_id)
		if button != null and reagent_index >= 0 and reagent_index < REAGENT_SLOT_RECTS.size():
			_layout_control(button, REAGENT_SLOT_RECTS[reagent_index])
			button.add_theme_font_size_override("font_size", _scaled_font(10))
		button.pivot_offset = button.size * 0.5
		if icon != null:
			var icon_size := Vector2(button.size.y * 0.72, button.size.y * 0.72)
			icon.size = icon_size
			icon.position = button.position + Vector2(button.size.x * 0.045, (button.size.y - icon_size.y) * 0.5)
			_reserve_icon_gutter(button, button.size.x * 0.045 + icon_size.x)


func _reserve_icon_gutter(button: Button, gutter: float) -> void:
	# The row icon is a sibling overlay, so the label has to be told to start after
	# it. A padded text string cannot do that job: the spaces neither scale with the
	# icon nor survive wrapping, which is how reagent names ended up hidden beneath
	# their own icons. Reserving the gutter in the stylebox makes overlap impossible.
	var pad := gutter + button.size.x * 0.035
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state)
		if style == null:
			continue
		var owned: StyleBox = style.duplicate()
		button.add_theme_stylebox_override(state, owned)
		owned.content_margin_left = pad


func _layout_control(control: Control, rect: Rect2) -> void:
	control.position = workbench_canvas.size * rect.position
	control.size = workbench_canvas.size * rect.size


func _install_caption_plaques() -> void:
	# The workbench is a painted plate, so operational copy that lands on smoke,
	# shelf edges or tool clutter becomes unreadable. Each caption cluster gets its
	# own specimen plaque -- the label a museum pins under an exhibit -- and is
	# lifted above it, rather than the copy being nudged into whatever gap is left.
	product_heading_plaque = _new_caption_plaque(&"ProductHeadingPlaque")
	product_caption_plaque = _new_caption_plaque(&"ProductCaptionPlaque")
	for label: Label in [product_label, product_name, product_description]:
		label.z_index = CAPTION_TEXT_Z
	# "Reaction array" merely names the tray the reader is already looking at, so it
	# is retired to give the parchment's three live readout lines room to breathe.
	reaction_label.visible = false


func _new_caption_plaque(plaque_name: StringName) -> Panel:
	var plaque := Panel.new()
	plaque.name = plaque_name
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.z_index = CAPTION_PLAQUE_Z
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.086, 0.055, 0.041, 0.90)
	style.border_color = Color(0.62, 0.44, 0.20, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_expand_margin_all(0.0)
	plaque.add_theme_stylebox_override("panel", style)
	workbench_canvas.add_child(plaque)
	return plaque


func _scaled_font(source_pixels: int) -> int:
	# The authored workbench is intentionally large. A modest readability lift keeps
	# its operational copy clear at 1024×768 without fighting the pixel-art hierarchy.
	return maxi(10, roundi(float(source_pixels) * 1.35 * workbench_canvas.size.x / SOURCE_SIZE))


func _build_extraction_effect_layer() -> void:
	extraction_effect_layer = Control.new()
	extraction_effect_layer.name = "AlchemyExtractionVFX"
	extraction_effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	extraction_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extraction_effect_layer.z_index = 40
	workbench_canvas.add_child(extraction_effect_layer)


func _choose_recipe(recipe_id: String) -> void:
	if not GameState.has_recipe(recipe_id):
		_set_status(_text("This formula has not been recovered yet.", "这张配方尚未被找到。"), true)
		return
	selected_recipe_id = recipe_id
	selected_material_id = ""
	_reset_reaction_nodes()
	_set_status(_text("Formula loaded. Select a reagent from the left rack, then seat it in a brass socket.", "配方已载入。请在左侧选择试剂，再放入黄铜槽。"))
	_refresh()
	_pulse_control(recipe_buttons.get(recipe_id) as Control, true)
	call_deferred("_focus_first_reagent")


func _select_reagent(item_id: String) -> void:
	if selected_recipe_id.is_empty():
		_set_status(_text("Load a formula before taking a reagent.", "请先载入配方，再取用试剂。"), true)
		return
	if not _ingredient_available(item_id):
		_set_status(_text("The reagent rack is short of " + _ingredient_name(item_id) + ".", "试剂架缺少“" + _ingredient_name(item_id) + "”。"), true)
		return
	selected_material_id = "" if selected_material_id == item_id else item_id
	if selected_material_id.is_empty():
		_set_status(_text("Reagent returned to the rack.", "试剂已放回架上。"))
	else:
		_set_status(_text("Selected " + _ingredient_name(item_id) + ". Click any empty brass socket in the centre.", "已选择“" + _ingredient_name(item_id) + "”。点击中央任一空黄铜槽。"))
	_refresh()
	_pulse_control(reagent_buttons.get(item_id) as Control, not selected_material_id.is_empty())


func _press_reaction_node(index: int) -> void:
	if selected_recipe_id.is_empty():
		_set_status(_text("The reaction array is dormant. Choose a formula first.", "反应阵列尚未启动。请先选择配方。"), true)
		return
	if index == 3:
		_set_status(_text("The violet seal is fixed. It stabilizes every permitted reaction.", "紫色稳定核已固定，它稳定每一次允许的反应。"))
		return
	if selected_material_id.is_empty():
		if not reaction_nodes[index].is_empty():
			reaction_nodes[index] = ""
			_set_status(_text("Socket cleared. Choose another reagent if needed.", "槽位已清空。需要时可换另一种试剂。"))
			_refresh()
			_pulse_control(node_buttons[index], false)
		else:
			_set_status(_text("Choose a reagent on the left, then place it here.", "先从左侧选择试剂，再放入此槽。"), true)
		return
	if not reaction_nodes[index].is_empty():
		_set_status(_text("That socket is occupied. Clear it before seating a different reagent.", "这个槽位已被占用。请先清空它。"), true)
		return
	reaction_nodes[index] = selected_material_id
	selected_material_id = ""
	_set_status(_text("Reagent seated. Fill the remaining brass sockets.", "试剂已入槽。继续填满其余黄铜槽。"))
	_refresh()
	_pulse_control(node_buttons[index], true)


func _clear_nodes() -> void:
	if selected_recipe_id.is_empty():
		return
	selected_material_id = ""
	_reset_reaction_nodes()
	_set_status(_text("Reaction sockets reset. No materials were consumed.", "反应槽已重置；没有消耗材料。"))
	_refresh()
	_pulse_control(reset_button, false)


func _extract_potion() -> void:
	if extracting:
		return
	if selected_recipe_id.is_empty():
		_set_status(_text("Load a formula before extracting.", "请先载入配方，再进行萃取。"), true)
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	if not _matches_formula(info):
		_set_status(_text("The sockets do not match this formula. Nothing was consumed.", "槽位组合不符合该配方；没有消耗材料。"), true)
		return
	if not _requirements_available(info):
		_set_status(_text("The reaction is correct, but the rack lacks a required reagent.", "反应正确，但试剂架缺少所需材料。"), true)
		return
	extracting = true
	GameAudio.play(&"potion_extract")
	GameAudio.duck_music()
	extract_button.disabled = true
	reset_button.disabled = true
	close_button.disabled = true
	_set_status(_text("Extraction array charging — hold the formula stable.", "萃取阵列正在充能——保持配方稳定。"))
	for old_beam: Line2D in extraction_beams:
		if old_beam != null and is_instance_valid(old_beam):
			old_beam.queue_free()
	extraction_beams.clear()
	var product_center := product_image.position + product_image.size * 0.5
	var beam_colours: Array[Color] = [
		Color(0.95, 0.66, 0.26, 0.92),
		Color(0.50, 0.86, 0.52, 0.92),
		Color(0.66, 0.50, 0.96, 0.92),
	]
	for index: int in range(3):
		var socket := node_buttons[index] as Button
		var start := socket.position + socket.size * 0.5
		var beam := Line2D.new()
		beam.name = "ReagentExtractionBeam%d" % index
		beam.points = PackedVector2Array([start, start])
		beam.width = 4.0
		beam.visible = false
		extraction_effect_layer.add_child(beam)
		extraction_beams.append(beam)
		OpticalFxRuntime.trace_beam(
			self,
			beam,
			start,
			product_center,
			beam_colours[index],
			4.2,
			0.34,
			float(index) * 0.10
		)
		OpticalFxRuntime.launch_packet(
			self,
			extraction_effect_layer,
			start,
			product_center,
			beam_colours[index],
			0.34 + float(index) * 0.10
		)
	var finish_timer := get_tree().create_timer(0.72, true)
	finish_timer.timeout.connect(
		_finish_extraction.bind(
			selected_recipe_id,
			str(info.get("produces", "")),
			(info.get("herb_cost", {}) as Dictionary).duplicate(true),
			(info.get("material_cost", {}) as Dictionary).duplicate(true)
		)
	)


func _finish_extraction(
	recipe_id: String,
	produces: String,
	herb_cost: Dictionary,
	material_cost: Dictionary
) -> void:
	if not extracting:
		return
	OpticalFxRuntime.pulse_ring(
		self,
		extraction_effect_layer,
		product_image.position + product_image.size * 0.5,
		Color(0.72, 0.92, 0.58, 0.94),
		30.0,
		2.4,
		0.42
	)
	product_image.pivot_offset = product_image.size * 0.5
	product_image.scale = Vector2(0.72, 0.72)
	var settle := create_tween()
	settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(product_image, "scale", Vector2.ONE, 0.26)
	settle.tween_interval(0.42)
	settle.tween_callback(
		func() -> void:
			var room := chemistry_room
			extracting = false
			close_button.disabled = false
			close()
			if room != null and is_instance_valid(room) and room.has_method("_craft_potion"):
				room.call("_craft_potion", recipe_id, produces, herb_cost, material_cost)
	)


func _refresh() -> void:
	if root == null:
		return
	_refresh_static_copy()
	_refresh_formula_slots()
	_rebuild_reagent_slots()
	_refresh_reaction_slots()
	_layout_workbench()
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	var ready := not selected_recipe_id.is_empty() and _matches_formula(info) and _requirements_available(info)
	extract_button.disabled = not ready
	extract_button.text = _text("3 · EXTRACT POTION", "3 · 萃取药剂") if ready else _text("3 · EXTRACTION LOCKED", "3 · 萃取未解锁")
	reset_button.disabled = selected_recipe_id.is_empty()
	reset_button.text = _text("RESET ARRAY", "重置阵列")
	close_button.text = _text("EXIT", "返回")
	status_label.add_theme_color_override("font_color", ArchiveUi.COLOR_DANGER if status_is_error else Color(0.20, 0.105, 0.045, 1.0))
	_wire_focus_neighbors()


func _refresh_static_copy() -> void:
	var has_formula := not selected_recipe_id.is_empty()
	var procedure_step := _procedure_step()
	archive_label.text = _text("FORMULA ARCHIVE  /  REAGENT RACK", "配方档案 / 试剂架")
	title_label.text = _text("ASHFORD ALCHEMY DESK", "阿什福德炼金工作台")
	match procedure_step:
		1:
			subtitle_label.text = _text("STEP 1 / 3  ·  CHOOSE A FORMULA", "步骤 1 / 3 · 选择配方")
			status_heading.text = _text("PROCEDURE 1  ·  FORMULA", "流程 1 · 配方")
		2:
			subtitle_label.text = _text("STEP 2 / 3  ·  SEAT THREE REAGENTS", "步骤 2 / 3 · 放入三种试剂")
			status_heading.text = _text("PROCEDURE 2  ·  REACTION ARRAY", "流程 2 · 反应阵列")
		_:
			subtitle_label.text = _text("STEP 3 / 3  ·  EXTRACT THE POTION", "步骤 3 / 3 · 萃取药剂")
			status_heading.text = _text("PROCEDURE 3  ·  EXTRACTION READY", "流程 3 · 可以萃取")
	product_label.text = _text("EXPECTED RESULT", "预期产物")
	reaction_label.text = _text("REACTION ARRAY", "反应阵列")
	# The illustrated result alcove has room for a single, strong line of copy.
	# Its explanatory prose belongs in the parchment procedure area, not over books
	# and bottles at the right edge.
	product_description.visible = false
	if not has_formula:
		product_name.text = _text("LOAD FORMULA", "载入配方")
		product_description.text = ""
		reaction_state_label.text = _text("0 / 3 REAGENTS  •  SEAL DORMANT", "0 / 3 试剂 · 稳定核休眠")
		product_image.texture = null
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	var product_id := str(info.get("produces", ""))
	var product_info: Dictionary = GameState.POTION_INFO.get(product_id, {})
	product_name.text = str(product_info.get("name", product_id))
	product_description.text = str(product_info.get("description", ""))
	product_image.texture = load(_potion_texture_path(product_id)) as Texture2D
	var loaded := _loaded_reagent_count()
	reaction_state_label.text = _text("%d / 3 REAGENTS  •  VIOLET SEAL STABLE" % loaded, "%d / 3 试剂 · 紫色稳定核已就绪" % loaded)


func _procedure_step() -> int:
	if selected_recipe_id.is_empty():
		return 1
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	if _matches_formula(info) and _requirements_available(info):
		return 3
	return 2


func _refresh_formula_slots() -> void:
	for recipe_id: String in RECIPE_ORDER:
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button == null:
			continue
		var unlocked := GameState.has_recipe(recipe_id)
		button.disabled = not unlocked
		button.text = ("◆ " if selected_recipe_id == recipe_id else "") + _recipe_name(recipe_id)
		button.self_modulate = Color(1.18, 1.03, 0.72, 1.0) if selected_recipe_id == recipe_id else Color.WHITE
		var formula_icon := recipe_icons.get(recipe_id) as TextureRect
		if formula_icon != null:
			formula_icon.modulate = (
				GameState.get_item_accent(recipe_id)
				if selected_recipe_id == recipe_id
				else Color.WHITE if unlocked else Color(0.30, 0.28, 0.30, 0.62)
			)
		_apply_slot_button(button, &"formula", selected_recipe_id == recipe_id)


func _rebuild_reagent_slots() -> void:
	for item_id: Variant in reagent_buttons.keys():
		var button: Button = reagent_buttons[item_id] as Button
		var icon: TextureRect = reagent_icons.get(item_id) as TextureRect
		if button != null:
			button.queue_free()
		if icon != null:
			icon.queue_free()
	reagent_buttons.clear()
	reagent_icons.clear()
	if selected_recipe_id.is_empty():
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	var items := _required_ingredients(info)
	for item_id: String in items:
		var button := Button.new()
		button.name = "Reagent_" + item_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.tooltip_text = _text("Select " + _ingredient_name(item_id), "选择“" + _ingredient_name(item_id) + "”")
		button.text = ("◆ " if selected_material_id == item_id else "") + _ingredient_name(item_id) + "  %d/%d" % [_ingredient_count(item_id), _ingredient_need(info, item_id)]
		button.disabled = not _ingredient_available(item_id)
		_apply_slot_button(button, &"reagent", selected_material_id == item_id)
		button.pressed.connect(_select_reagent.bind(item_id))
		workbench_canvas.add_child(button)
		reagent_buttons[item_id] = button

		var icon := TextureRect.new()
		icon.name = "ReagentIcon_" + item_id
		icon.texture = load(_ingredient_texture_path(item_id)) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 2
		workbench_canvas.add_child(icon)
		reagent_icons[item_id] = icon


func _refresh_reaction_slots() -> void:
	for index: int in range(node_buttons.size()):
		var item_id := reaction_nodes[index]
		var is_seal := index == 3
		node_buttons[index].disabled = selected_recipe_id.is_empty() or is_seal
		_apply_slot_button(node_buttons[index], &"seal" if is_seal else &"socket", not selected_material_id.is_empty() and item_id.is_empty() and not is_seal)
		if is_seal:
			node_buttons[index].text = _text("VIOLET\nSEAL", "紫色\n稳定核")
			node_icons[index].texture = null
			node_labels[index].text = ""
			node_buttons[index].self_modulate = Color(0.94, 0.80, 1.16, 1.0) if not selected_recipe_id.is_empty() else Color(0.55, 0.46, 0.62, 1.0)
		elif item_id.is_empty():
			node_buttons[index].text = _text("EMPTY", "空槽")
			node_icons[index].texture = null
			node_labels[index].text = ""
			node_buttons[index].self_modulate = Color(1.0, 0.96, 0.84, 1.0) if not selected_material_id.is_empty() else Color.WHITE
		else:
			node_buttons[index].text = ""
			node_icons[index].texture = load(_ingredient_texture_path(item_id)) as Texture2D
			node_labels[index].text = _ingredient_name(item_id)
			node_buttons[index].self_modulate = Color.WHITE


func _apply_slot_button(button: Button, kind: StringName, selected: bool) -> void:
	if not button.has_meta("alchemy_slot_ready"):
		button.set_meta("alchemy_slot_ready", true)
		ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCHIVE)
	var normal := _slot_style(kind, &"normal", selected)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _slot_style(kind, &"hover", selected))
	button.add_theme_stylebox_override("pressed", _slot_style(kind, &"pressed", selected))
	button.add_theme_stylebox_override("disabled", _slot_style(kind, &"disabled", selected))
	button.add_theme_stylebox_override("focus", _slot_focus_style(kind))


func _slot_style(kind: StringName, state: StringName, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var gold := Color(0.93, 0.70, 0.26, 0.80)
	var violet := Color(0.72, 0.46, 1.0, 0.84)
	var border := violet if kind == &"seal" else gold
	var fill := Color(0.018, 0.014, 0.025, 0.05)
	if kind == &"formula" or kind == &"reagent":
		fill = Color(0.10, 0.055, 0.020, 0.025)
	if selected:
		fill = Color(0.38, 0.22, 0.055, 0.28) if kind != &"socket" else Color(0.36, 0.18, 0.48, 0.28)
		border = Color(1.0, 0.83, 0.34, 0.98)
	if state == &"hover":
		fill = fill.lightened(0.18)
		border = border.lightened(0.20)
	elif state == &"pressed":
		fill = fill.darkened(0.18)
	elif state == &"disabled":
		fill = fill.darkened(0.45)
		border = border.darkened(0.55)
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if selected or state == &"hover" else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _slot_focus_style(kind: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.92, 0.84, 0.42, 1.0) if kind != &"seal" else Color(0.82, 0.65, 1.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


func _apply_diegetic_action_button(button: Button, accent: Color) -> void:
	button.set_meta("alchemy_action_accent", accent)
	button.flat = true
	button.add_theme_color_override("font_color", Color(0.96, 0.85, 0.60, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.74, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.84, 0.72, 0.45, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.40, 0.38, 0.92))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", _action_seat_style(accent, &"normal"))
	button.add_theme_stylebox_override("hover", _action_seat_style(accent, &"hover"))
	button.add_theme_stylebox_override("pressed", _action_seat_style(accent, &"pressed"))
	button.add_theme_stylebox_override("disabled", _action_seat_style(accent, &"disabled"))
	button.add_theme_stylebox_override("focus", _action_focus_style(accent))


func _action_seat_style(accent: Color, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# The artwork supplies the bevel, screws and glass. This layer only gives a
	# restrained light response inside its existing button recess.
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_corner_radius_all(7)
	if state == &"hover":
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.17)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.54)
		style.set_border_width_all(1)
	elif state == &"pressed":
		style.bg_color = Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 0.28)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
		style.set_border_width_all(1)
	elif state == &"disabled":
		style.bg_color = Color(0.0, 0.0, 0.0, 0.18)
	return style


func _action_focus_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _reset_reaction_nodes() -> void:
	reaction_nodes = ["", "", "", VIOLET_SEAL if not selected_recipe_id.is_empty() else ""]


func _matches_formula(info: Dictionary) -> bool:
	if _loaded_reagent_count() != 3:
		return false
	var expected := _required_ingredients(info)
	var loaded: Array[String] = []
	for item_id: String in reaction_nodes:
		if not item_id.is_empty() and item_id != VIOLET_SEAL:
			loaded.append(item_id)
	return loaded.size() == expected.size() and loaded.all(func(item_id: String) -> bool: return expected.has(item_id))


func _requirements_available(info: Dictionary) -> bool:
	for item_id: String in _required_ingredients(info):
		if _ingredient_count(item_id) < _ingredient_need(info, item_id):
			return false
	return true


func _required_ingredients(info: Dictionary) -> Array[String]:
	var items: Array[String] = []
	for item_id: String in ["blue_blossom", "moonleaf"]:
		if info.get("herb_cost", {}).has(item_id):
			items.append(item_id)
	for item_id: String in ["distilled_water", "iron_salt", "prism_dust"]:
		if info.get("material_cost", {}).has(item_id):
			items.append(item_id)
	return items


func _loaded_reagent_count() -> int:
	var count := 0
	for item_id: String in reaction_nodes:
		if not item_id.is_empty() and item_id != VIOLET_SEAL:
			count += 1
	return count


func _ingredient_available(item_id: String) -> bool:
	if selected_recipe_id.is_empty():
		return false
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	return _ingredient_count(item_id) >= _ingredient_need(info, item_id)


func _ingredient_count(item_id: String) -> int:
	return GameState.get_herb_count(item_id) if GameState.HERB_INFO.has(item_id) else GameState.get_material_count(item_id)


func _ingredient_need(info: Dictionary, item_id: String) -> int:
	if info.get("herb_cost", {}).has(item_id):
		return int(info.get("herb_cost", {}).get(item_id, 1))
	return int(info.get("material_cost", {}).get(item_id, 1))


func _recipe_name(recipe_id: String) -> String:
	if recipe_id == "recipe_swift":
		return _text("SWIFTNESS FORMULA", "迅捷药剂配方")
	if recipe_id == "recipe_vision":
		return _text("VISION FORMULA", "洞察药剂配方")
	return str(GameState.RECIPE_INFO.get(recipe_id, {}).get("name", recipe_id))


func _ingredient_name(item_id: String) -> String:
	var english := str(GameState.HERB_INFO.get(item_id, GameState.MATERIAL_INFO.get(item_id, {})).get("name", item_id))
	if not CaseLocale.is_chinese():
		return english
	var chinese: Dictionary = {
		"blue_blossom": "蓝花",
		"moonleaf": "月叶",
		"distilled_water": "蒸馏水",
		"iron_salt": "铁盐",
		"prism_dust": "棱镜粉",
	}
	return str(chinese.get(item_id, english))


func _ingredient_texture_path(item_id: String) -> String:
	return GameState.get_item_texture_path(item_id)


func _potion_texture_path(potion_id: String) -> String:
	return GameState.get_item_texture_path(potion_id)


func _set_status(message: String, is_error: bool = false) -> void:
	status_is_error = is_error
	if status_label != null:
		status_label.text = message
		status_label.add_theme_color_override("font_color", ArchiveUi.COLOR_DANGER if is_error else Color(0.20, 0.105, 0.045, 1.0))
		_pulse_control(status_label, not is_error)


func _pulse_control(control: Control, success: bool) -> void:
	if control == null or not is_instance_valid(control):
		return
	var base := Vector2.ONE
	var pulse := Vector2(1.035, 1.035) if success else Vector2(0.975, 1.025)
	control.scale = base
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", pulse, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_locale_changed(_language: String) -> void:
	ArchiveUi.refresh_tree(workbench_canvas)
	_refresh()


func _focus_opening_control() -> void:
	for recipe_id: String in RECIPE_ORDER:
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()


func _focus_first_reagent() -> void:
	for item_id: Variant in reagent_buttons.keys():
		var button: Button = reagent_buttons[item_id] as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


func _wire_focus_neighbors() -> void:
	var formulas: Array[Button] = []
	for recipe_id: String in RECIPE_ORDER:
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button != null:
			formulas.append(button)
	for index: int in formulas.size():
		formulas[index].focus_neighbor_top = formulas[maxi(0, index - 1)].get_path()
		formulas[index].focus_neighbor_bottom = formulas[mini(formulas.size() - 1, index + 1)].get_path()
		if not node_buttons.is_empty():
			formulas[index].focus_neighbor_right = node_buttons[0].get_path()
	var reagents: Array[Button] = []
	for item_id: Variant in reagent_buttons.keys():
		var reagent: Button = reagent_buttons[item_id] as Button
		if reagent != null:
			reagents.append(reagent)
	for index: int in reagents.size():
		reagents[index].focus_neighbor_top = reagents[maxi(0, index - 1)].get_path()
		reagents[index].focus_neighbor_bottom = reagents[mini(reagents.size() - 1, index + 1)].get_path()
		if not node_buttons.is_empty():
			reagents[index].focus_neighbor_right = node_buttons[0].get_path()
	if node_buttons.size() >= 4:
		node_buttons[0].focus_neighbor_bottom = node_buttons[1].get_path()
		node_buttons[1].focus_neighbor_right = node_buttons[2].get_path()
		node_buttons[2].focus_neighbor_left = node_buttons[1].get_path()
		node_buttons[1].focus_neighbor_bottom = node_buttons[3].get_path()
		node_buttons[2].focus_neighbor_bottom = node_buttons[3].get_path()
		node_buttons[3].focus_neighbor_top = node_buttons[0].get_path()
		node_buttons[2].focus_neighbor_right = extract_button.get_path()
	reset_button.focus_neighbor_right = extract_button.get_path()
	extract_button.focus_neighbor_left = reset_button.get_path()
	extract_button.focus_neighbor_right = close_button.get_path()
	close_button.focus_neighbor_left = extract_button.get_path()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english
