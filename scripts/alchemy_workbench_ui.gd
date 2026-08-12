class_name AlchemyWorkbenchUI
extends CanvasLayer

## Reusable Chemistry Room workbench. Its Interface is intentionally small:
## open(room), close(), and the closed signal. The implementation owns recipe
## choice, reagent placement, reaction validation, and the visible feedback.

signal closed

const RECIPE_ORDER: Array[String] = ["recipe_swift", "recipe_vision"]
const VIOLET_SEAL := "violet_seal"
const NODE_ANCHORS: Array[Vector2] = [
	Vector2(0.557, 0.313),
	Vector2(0.440, 0.435),
	Vector2(0.672, 0.435),
	Vector2(0.557, 0.563),
]
const PRODUCT_ANCHOR := Vector2(0.859, 0.439)

var chemistry_room: Node
var root: Control
var safe_area: MarginContainer
var workshop_frame: Control
var recipe_drawer: Control
var product_drawer: Control
var workbench: Control
var table_canvas: Control
var recipe_heading: Label
var recipe_instruction: Label
var recipe_list: VBoxContainer
var reagent_heading: Label
var reagent_list: VBoxContainer
var product_heading: Label
var product_image: TextureRect
var product_name: Label
var product_description: Label
var requirements_heading: Label
var requirements_label: Label
var reaction_state_label: Label
var status_plaque: Control
var status_label: Label
var reset_button: Button
var extract_button: Button
var close_button: Button
var selected_recipe_id := ""
var selected_material_id := ""
var reaction_nodes: Array[String] = ["", "", "", ""]
var recipe_buttons: Dictionary = {}
var reagent_buttons: Dictionary = {}
var node_buttons: Array[Button] = []
var node_icons: Array[TextureRect] = []
var node_labels: Array[Label] = []
var table_product_image: TextureRect
var status_is_error := false


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_scene()
	_build_dynamic_controls()
	_apply_safe_area()
	root.resized.connect(_apply_safe_area)
	workbench.resized.connect(_layout_table_canvas)
	table_canvas.resized.connect(_layout_table_controls)
	GameState.state_changed.connect(_refresh)
	CaseLocale.locale_changed.connect(_on_locale_changed)
	visible = false


func open(room: Node) -> void:
	chemistry_room = room
	selected_recipe_id = ""
	selected_material_id = ""
	_reset_reaction_nodes()
	_set_status(_text("Select a formula, then load its three reagents into the brass nodes.", "选择配方，再将三种试剂装入黄铜反应节点。"))
	visible = true
	root.visible = true
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
	workshop_frame = $AlchemyRoot/SafeArea/WorkshopFrame
	recipe_drawer = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer
	product_drawer = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer
	workbench = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/Workbench
	table_canvas = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/Workbench/TableCanvas
	recipe_heading = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer/Margin/Column/RecipeHeading
	recipe_instruction = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer/Margin/Column/RecipeInstruction
	recipe_list = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer/Margin/Column/RecipeScroll/RecipeList
	reagent_heading = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer/Margin/Column/ReagentHeading
	reagent_list = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/RecipeDrawer/Margin/Column/ReagentList
	product_heading = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ProductHeading
	product_image = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ProductPreview/ProductImage
	product_name = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ProductName
	product_description = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ProductDescription
	requirements_heading = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/RequirementsHeading
	requirements_label = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/RequirementsLabel
	reaction_state_label = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ReactionState/ReactionStateLabel
	status_plaque = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/ActionRail/StatusPlaque
	status_label = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/ActionRail/StatusPlaque/StatusLabel
	reset_button = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/ActionRail/ResetNodesButton
	extract_button = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/ActionRail/ExtractButton
	close_button = $AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/ActionRail/CloseAlchemyButton

	workshop_frame.add_theme_stylebox_override("panel", _frame_style())
	recipe_drawer.add_theme_stylebox_override("panel", _drawer_style(false))
	product_drawer.add_theme_stylebox_override("panel", _drawer_style(true))
	status_plaque.add_theme_stylebox_override("panel", _status_style(false))
	($AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/MainRow/ProductDrawer/Margin/Column/ReactionState as Control).add_theme_stylebox_override("panel", _reaction_style())
	ArchiveUi.apply_label(recipe_heading, &"title")
	ArchiveUi.apply_label(recipe_instruction, &"muted")
	ArchiveUi.apply_label(product_heading, &"title")
	ArchiveUi.apply_label(product_name, &"title")
	ArchiveUi.apply_label(product_description, &"body")
	ArchiveUi.apply_label(requirements_heading, &"title")
	ArchiveUi.apply_label(requirements_label, &"body")
	ArchiveUi.apply_label(reaction_state_label, &"body")
	ArchiveUi.apply_label(status_label, &"body")
	ArchiveUi.apply_label(reagent_heading, &"title")
	recipe_heading.add_theme_font_size_override("font_size", 13)
	recipe_instruction.add_theme_font_size_override("font_size", 10)
	reagent_heading.add_theme_font_size_override("font_size", 11)
	product_heading.add_theme_font_size_override("font_size", 13)
	product_name.add_theme_font_size_override("font_size", 13)
	product_description.add_theme_font_size_override("font_size", 10)
	requirements_heading.add_theme_font_size_override("font_size", 11)
	requirements_label.add_theme_font_size_override("font_size", 10)
	reaction_state_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_font_size_override("font_size", 11)
	ArchiveUi.apply_button(reset_button, ArchiveUi.ROLE_ARCHIVE)
	ArchiveUi.apply_button(extract_button, ArchiveUi.ROLE_ARCANE)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_ARCHIVE)
	reset_button.pressed.connect(_clear_nodes)
	extract_button.pressed.connect(_extract_potion)
	close_button.pressed.connect(close)


func _build_dynamic_controls() -> void:
	for recipe_id: String in RECIPE_ORDER:
		var button := Button.new()
		button.name = "Formula_" + recipe_id
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.add_theme_font_size_override("font_size", 11)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		_apply_record_button(button, false)
		button.pressed.connect(_choose_recipe.bind(recipe_id))
		recipe_list.add_child(button)
		recipe_buttons[recipe_id] = button

	for index: int in range(NODE_ANCHORS.size()):
		var node_button := Button.new()
		node_button.name = "ReactionNode_%d" % (index + 1)
		node_button.custom_minimum_size = Vector2(86.0, 70.0)
		node_button.add_theme_font_size_override("font_size", 9)
		node_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		node_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node_button.clip_text = false
		_apply_node_style(node_button, false)
		node_button.pressed.connect(_press_reaction_node.bind(index))
		table_canvas.add_child(node_button)
		node_buttons.append(node_button)

		var icon := TextureRect.new()
		icon.name = "ReactionNodeIcon_%d" % (index + 1)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 2
		table_canvas.add_child(icon)
		node_icons.append(icon)

		var label := Label.new()
		label.name = "ReactionNodeLabel_%d" % (index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 3
		ArchiveUi.apply_label(label, &"body")
		label.add_theme_font_size_override("font_size", 8)
		table_canvas.add_child(label)
		node_labels.append(label)

	table_product_image = TextureRect.new()
	table_product_image.name = "ExpectedPotionOnTable"
	table_product_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table_product_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	table_product_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_product_image.z_index = 2
	table_canvas.add_child(table_product_image)
	_wire_focus_neighbors()
	call_deferred("_layout_table_canvas")


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	safe_area.add_theme_constant_override("margin_left", max(14, safe.position.x))
	safe_area.add_theme_constant_override("margin_top", max(14, safe.position.y))
	safe_area.add_theme_constant_override("margin_right", max(14, window_size.x - safe.end.x))
	safe_area.add_theme_constant_override("margin_bottom", max(14, window_size.y - safe.end.y))


func _layout_table_canvas() -> void:
	if workbench.size.x <= 0.0 or workbench.size.y <= 0.0:
		return
	var side: float = minf(workbench.size.x, workbench.size.y)
	table_canvas.size = Vector2(side, side)
	table_canvas.position = (workbench.size - table_canvas.size) * 0.5
	_layout_table_controls()


func _layout_table_controls() -> void:
	if table_canvas.size.x <= 0.0:
		return
	var node_size := Vector2.ONE * clampf(table_canvas.size.x * 0.155, 76.0, 94.0)
	for index: int in range(node_buttons.size()):
		var center := table_canvas.size * NODE_ANCHORS[index]
		node_buttons[index].size = node_size
		node_buttons[index].position = center - node_size * 0.5
		node_icons[index].size = Vector2.ONE * node_size.x * 0.44
		node_icons[index].position = center - node_icons[index].size * 0.5 - Vector2(0.0, 7.0)
		node_labels[index].size = Vector2(node_size.x * 0.90, 24.0)
		node_labels[index].position = center + Vector2(-node_labels[index].size.x * 0.5, node_size.y * 0.18)
	var product_size := Vector2.ONE * clampf(table_canvas.size.x * 0.145, 66.0, 84.0)
	table_product_image.size = product_size
	table_product_image.position = table_canvas.size * PRODUCT_ANCHOR - product_size * 0.5


func _choose_recipe(recipe_id: String) -> void:
	if not GameState.has_recipe(recipe_id):
		_set_status(_text("This formula is not in the archive yet.", "这张配方尚未归档。"), true)
		return
	selected_recipe_id = recipe_id
	selected_material_id = ""
	_reset_reaction_nodes()
	_set_status(_text("Formula loaded. Choose a reagent, then seat it in any empty brass node.", "配方已载入。选择一份试剂，再将其放入任意空的黄铜节点。"))
	_refresh()
	call_deferred("_focus_first_reagent")


func _select_reagent(item_id: String) -> void:
	if selected_recipe_id.is_empty():
		_set_status(_text("Select a formula before handling reagents.", "请先选择配方，再取用试剂。"), true)
		return
	if not _ingredient_available(item_id):
		_set_status(_text("The reagent rack is short of " + _ingredient_name(item_id) + ".", "试剂架缺少“" + _ingredient_name(item_id) + "”。"), true)
		return
	selected_material_id = "" if selected_material_id == item_id else item_id
	_set_status(
		_text("Selected: ", "已选择：") + _ingredient_name(item_id)
		+ _text(". Click an empty brass node.", "。点击一个空的黄铜节点。")
	)
	_refresh()


func _press_reaction_node(index: int) -> void:
	if selected_recipe_id.is_empty():
		_set_status(_text("The reaction array is dormant. Select a formula first.", "反应阵列尚未启动。请先选择配方。"), true)
		return
	if index == 3:
		_set_status(_text("The violet seal is fixed. It stabilizes every permitted reaction.", "紫色稳定核已固定，它负责稳定每一次允许的反应。"))
		return
	if selected_material_id.is_empty():
		if not reaction_nodes[index].is_empty():
			reaction_nodes[index] = ""
			_set_status(_text("Node cleared. Choose a different reagent if needed.", "节点已清空。需要时可选择另一份试剂。"))
			_refresh()
		else:
			_set_status(_text("Choose a reagent from the archive drawer first.", "请先从档案柜中选择一份试剂。"), true)
		return
	if not reaction_nodes[index].is_empty():
		_set_status(_text("That node is occupied. Clear it before seating a different reagent.", "该节点已被占用。请先清空它，再放入另一份试剂。"), true)
		return
	reaction_nodes[index] = selected_material_id
	selected_material_id = ""
	_set_status(_text("Reagent seated. Continue until all three brass nodes are loaded.", "试剂已入槽。继续装满另外的黄铜节点。"))
	_refresh()


func _clear_nodes() -> void:
	if selected_recipe_id.is_empty():
		return
	selected_material_id = ""
	_reset_reaction_nodes()
	_set_status(_text("Reaction nodes reset. No ingredients were consumed.", "反应节点已重置。没有消耗任何材料。"))
	_refresh()


func _extract_potion() -> void:
	if selected_recipe_id.is_empty():
		_set_status(_text("Load a formula before pulling the extraction lever.", "请先载入配方，再拉下萃取拉杆。"), true)
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	if not _matches_formula(info):
		_set_status(_text("Violet smoke: the three reagent nodes do not match this formula. Nothing was consumed.", "紫色烟雾：三个试剂节点与配方不符。没有消耗材料。"), true)
		return
	if not _requirements_available(info):
		_set_status(_text("The reaction is correct, but the rack lacks a required reagent.", "反应步骤正确，但试剂架缺少必要材料。"), true)
		return
	var room := chemistry_room
	close()
	if room != null and room.has_method("_craft_potion"):
		room.call(
			"_craft_potion",
			selected_recipe_id,
			str(info.get("produces", "")),
			info.get("herb_cost", {}),
			info.get("material_cost", {})
		)


func _refresh() -> void:
	if root == null:
		return
	_refresh_copy()
	for recipe_id: String in RECIPE_ORDER:
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button == null:
			continue
		var info: Dictionary = GameState.RECIPE_INFO.get(recipe_id, {})
		var unlocked := GameState.has_recipe(recipe_id)
		button.disabled = not unlocked
		button.text = (
			("◆ " if selected_recipe_id == recipe_id else "")
			+ _recipe_name(recipe_id)
			+ "\n"
			+ (_text("ARCHIVED", "已归档") if unlocked else _text("SEALED FORMULA", "未解封配方"))
		)
		ArchiveUi.set_button_status(button, &"success" if unlocked else &"default")
		button.self_modulate = Color(1.0, 0.95, 0.78, 1.0) if selected_recipe_id == recipe_id else Color.WHITE

	_rebuild_reagent_list()
	_refresh_nodes()
	var ready := not selected_recipe_id.is_empty() and _matches_formula(GameState.RECIPE_INFO.get(selected_recipe_id, {})) and _requirements_available(GameState.RECIPE_INFO.get(selected_recipe_id, {}))
	extract_button.disabled = not ready
	extract_button.text = _text("PULL EXTRACTION LEVER", "拉下萃取拉杆") if ready else _text("EXTRACTION LOCKED", "萃取已锁定")
	reset_button.disabled = selected_recipe_id.is_empty()
	status_plaque.add_theme_stylebox_override("panel", _status_style(status_is_error))
	_layout_table_controls()


func _refresh_copy() -> void:
	var has_formula := not selected_recipe_id.is_empty()
	($AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/Header/TitleLabel as Label).text = _text("ASHFORD ALCHEMY WORKBENCH", "阿什福德炼金工作台")
	($AlchemyRoot/SafeArea/WorkshopFrame/FrameMargin/Content/Header/SubtitleLabel as Label).text = _text(
		"Choose an archived formula, load three reagents, then extract a stable field potion.",
		"选择已归档配方，装填三种试剂，再萃取稳定的现场药剂。"
	)
	recipe_heading.text = _text("FORMULA ARCHIVE", "配方档案")
	recipe_instruction.text = _text("A formula names the safe reaction. It does not consume materials until extraction.", "配方规定安全反应；材料只会在萃取成功时消耗。")
	reagent_heading.text = _text("REAGENT RACK", "试剂架")
	product_heading.text = _text("EXPECTED PRODUCT", "预期产物")
	requirements_heading.text = _text("MATERIAL CHECK", "材料核验")
	reset_button.text = _text("RESET NODES", "重置节点")
	close_button.text = _text("RETURN TO LAB", "返回实验室")
	if not has_formula:
		product_name.text = _text("NO FORMULA LOADED", "尚未载入配方")
		product_description.text = _text("Choose a recovered recipe sheet to reveal its field effect.", "选择已获得的配方纸以查看它的现场效果。")
		requirements_label.text = _text("No reagents required yet.", "尚未需要试剂。")
		reaction_state_label.text = _text("ARRAY DORMANT", "阵列休眠")
		product_image.texture = null
		table_product_image.texture = null
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	var product_id := str(info.get("produces", ""))
	var product_info: Dictionary = GameState.POTION_INFO.get(product_id, {})
	product_name.text = str(product_info.get("name", product_id))
	product_description.text = str(product_info.get("description", ""))
	product_image.texture = load(_potion_texture_path(product_id)) as Texture2D
	table_product_image.texture = product_image.texture
	requirements_label.text = _requirements_text(info)
	var loaded := _loaded_reagent_count()
	reaction_state_label.text = _text("REACTION NODES  %d/3\nVIOLET SEAL · STABLE" % loaded, "反应节点  %d/3\n紫色稳定核 · 稳定" % loaded)


func _rebuild_reagent_list() -> void:
	for child: Node in reagent_list.get_children():
		child.queue_free()
	reagent_buttons.clear()
	if selected_recipe_id.is_empty():
		var empty := Label.new()
		empty.text = _text("Select a formula to open the correct reagent rack.", "选择配方后开启对应的试剂架。")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ArchiveUi.apply_label(empty, &"muted")
		empty.add_theme_font_size_override("font_size", 10)
		reagent_list.add_child(empty)
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	for item_id: String in _required_ingredients(info):
		var button := Button.new()
		button.name = "Reagent_" + item_id
		button.custom_minimum_size = Vector2(0.0, 34.0)
		button.add_theme_font_size_override("font_size", 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text = (
			("◆ " if selected_material_id == item_id else "")
			+ _ingredient_name(item_id)
			+ "  %d/%d" % [_ingredient_count(item_id), _ingredient_need(info, item_id)]
		)
		button.disabled = not _ingredient_available(item_id)
		_apply_record_button(button, selected_material_id == item_id)
		button.pressed.connect(_select_reagent.bind(item_id))
		reagent_list.add_child(button)
		reagent_buttons[item_id] = button
	_wire_reagent_focus_neighbors()


func _refresh_nodes() -> void:
	for index: int in range(node_buttons.size()):
		var item_id := reaction_nodes[index]
		var is_seal := item_id == VIOLET_SEAL
		node_buttons[index].disabled = selected_recipe_id.is_empty() or is_seal
		_apply_node_style(node_buttons[index], is_seal)
		if item_id.is_empty():
			node_buttons[index].text = _text("NODE %d\nEMPTY" % (index + 1), "节点 %d\n空位" % (index + 1))
			node_icons[index].texture = null
			node_labels[index].text = ""
			node_buttons[index].self_modulate = Color(1.0, 1.0, 1.0, 1.0) if selected_material_id.is_empty() else Color(1.08, 0.92, 1.12, 1.0)
		elif is_seal:
			node_buttons[index].text = _text("VIOLET\nSEAL", "紫色\n稳定核")
			node_icons[index].texture = null
			node_labels[index].text = ""
			node_buttons[index].self_modulate = Color(0.92, 0.78, 1.15, 1.0)
		else:
			node_buttons[index].text = ""
			node_icons[index].texture = load(_ingredient_texture_path(item_id)) as Texture2D
			node_labels[index].text = _ingredient_name(item_id)
			node_buttons[index].self_modulate = Color.WHITE


func _reset_reaction_nodes() -> void:
	reaction_nodes.clear()
	reaction_nodes.append("")
	reaction_nodes.append("")
	reaction_nodes.append("")
	reaction_nodes.append(VIOLET_SEAL if not selected_recipe_id.is_empty() else "")


func _matches_formula(info: Dictionary) -> bool:
	if _loaded_reagent_count() != 3:
		return false
	var expected := _required_ingredients(info)
	var loaded: Array[String] = []
	for item_id: String in reaction_nodes:
		if not item_id.is_empty() and item_id != VIOLET_SEAL:
			loaded.append(item_id)
	if loaded.size() != expected.size():
		return false
	for item_id: String in expected:
		if not loaded.has(item_id):
			return false
	return true


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


func _requirements_text(info: Dictionary) -> String:
	var lines: Array[String] = []
	for item_id: String in _required_ingredients(info):
		var count := _ingredient_count(item_id)
		var need := _ingredient_need(info, item_id)
		var marker := "◆" if count >= need else "×"
		lines.append("%s %s  %d/%d" % [marker, _ingredient_name(item_id), count, need])
	return "\n".join(lines)


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
	match item_id:
		"blue_blossom": return "res://assets/ui/alchemy/blue_blossom.png"
		"moonleaf": return "res://assets/ui/alchemy/moonleaf.png"
		"distilled_water": return "res://assets/ui/alchemy/distilled_water.png"
		"iron_salt": return "res://assets/ui/alchemy/iron_salt.png"
		"prism_dust": return "res://assets/ui/alchemy/prism_dust.png"
	return ""


func _potion_texture_path(potion_id: String) -> String:
	match potion_id:
		"swift_potion": return "res://assets/ui/alchemy/swiftness_potion.png"
		"vision_potion": return "res://assets/ui/alchemy/vision_potion_eyes.png"
		"green_potion": return "res://assets/ui/alchemy/green_potion.png"
	return ""


func _set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_is_error = is_error


func _on_locale_changed(_language: String) -> void:
	_refresh()


func _focus_opening_control() -> void:
	for recipe_id: String in RECIPE_ORDER:
		var button: Button = recipe_buttons.get(recipe_id) as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()


func _focus_first_reagent() -> void:
	for child: Node in reagent_list.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
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
	if not formulas.is_empty() and not node_buttons.is_empty():
		formulas.front().focus_neighbor_right = node_buttons[0].get_path()
		node_buttons[0].focus_neighbor_left = formulas.front().get_path()
	if node_buttons.size() >= 4:
		node_buttons[0].focus_neighbor_bottom = node_buttons[1].get_path()
		node_buttons[1].focus_neighbor_top = node_buttons[0].get_path()
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


func _wire_reagent_focus_neighbors() -> void:
	var reagents: Array[Button] = []
	for child: Node in reagent_list.get_children():
		if child is Button:
			reagents.append(child as Button)
	for index: int in reagents.size():
		reagents[index].focus_neighbor_top = reagents[maxi(0, index - 1)].get_path()
		reagents[index].focus_neighbor_bottom = reagents[mini(reagents.size() - 1, index + 1)].get_path()
		if not node_buttons.is_empty():
			reagents[index].focus_neighbor_right = node_buttons[0].get_path()
	if not reagents.is_empty() and not RECIPE_ORDER.is_empty():
		var first_formula: Button = recipe_buttons.get(RECIPE_ORDER.front()) as Button
		if first_formula != null:
			reagents.front().focus_neighbor_left = first_formula.get_path()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _apply_record_button(button: Button, arcane: bool) -> void:
	ArchiveUi.apply_button(button, ArchiveUi.ROLE_ARCANE if arcane else ArchiveUi.ROLE_ARCHIVE)
	button.add_theme_stylebox_override("normal", _record_style(arcane, &"default"))
	button.add_theme_stylebox_override("hover", _record_style(arcane, &"hover"))
	button.add_theme_stylebox_override("pressed", _record_style(arcane, &"pressed"))
	button.add_theme_stylebox_override("disabled", _record_style(arcane, &"disabled"))


func _apply_node_style(button: Button, violet: bool) -> void:
	button.add_theme_stylebox_override("normal", _node_style(violet, &"default"))
	button.add_theme_stylebox_override("hover", _node_style(violet, &"hover"))
	button.add_theme_stylebox_override("pressed", _node_style(violet, &"pressed"))
	button.add_theme_stylebox_override("disabled", _node_style(violet, &"disabled"))


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.011, 0.022, 0.99)
	style.border_color = Color(0.78, 0.59, 0.25, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _drawer_style(arcane: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.045, 0.96) if not arcane else Color(0.055, 0.032, 0.090, 0.96)
	style.border_color = Color(0.55, 0.39, 0.18, 0.92) if not arcane else Color(0.50, 0.32, 0.78, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _status_style(is_error: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.050, 0.065, 0.95) if is_error else Color(0.024, 0.018, 0.030, 0.94)
	style.border_color = Color(0.90, 0.35, 0.33, 0.92) if is_error else Color(0.48, 0.35, 0.20, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _reaction_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.030, 0.090, 0.90)
	style.border_color = Color(0.56, 0.36, 0.84, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
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


func _node_style(violet: bool, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var border := Color(0.80, 0.60, 0.24, 0.94) if not violet else Color(0.70, 0.48, 1.0, 0.96)
	var background := Color(0.026, 0.020, 0.027, 0.62) if not violet else Color(0.11, 0.040, 0.16, 0.72)
	if state == &"hover":
		border = border.lightened(0.16)
		background = background.lightened(0.10)
	elif state == &"pressed":
		background = background.darkened(0.10)
	elif state == &"disabled":
		border = border.darkened(0.30)
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english
