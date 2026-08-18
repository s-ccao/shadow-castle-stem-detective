extends Control
class_name AlchemyPrototypeUI

## 新炼金原型界面：底图只负责美术，所有交互都由独立 Control/Button 负责。

const ART_ORIGIN: Vector2 = Vector2(128.0, 0.0)
const ART_SIZE: Vector2 = Vector2(768.0, 768.0)
const ART_SCALE: float = 768.0 / 1254.0
const RECIPE_ROWS: Array[Rect2] = [
	Rect2(77, 320, 293, 80),
	Rect2(77, 405, 293, 87),
	Rect2(77, 500, 293, 88),
	Rect2(77, 595, 293, 86),
	Rect2(77, 688, 293, 87),
	Rect2(77, 782, 293, 89),
	Rect2(77, 877, 293, 86),
]
const RECIPE_CIRCLE_CENTERS: Array[Vector2] = [
	Vector2(115, 360),
	Vector2(115, 446),
	Vector2(115, 542),
	Vector2(115, 637),
	Vector2(115, 731),
	Vector2(115, 826),
	Vector2(115, 920),
]
const MATERIAL_CENTERS: Array[Vector2] = [
	Vector2(698, 393),
	Vector2(551, 547),
	Vector2(842, 547),
	Vector2(698, 706),
]
const BOTTOM_MATERIAL_CENTERS: Array[Vector2] = [
	Vector2(446, 1080),
	Vector2(547, 1080),
	Vector2(648, 1080),
]
const VIOLET_CATALYST := "violet_catalyst"

var chemistry_room: Node
var selected_recipe_id: String = ""
var recipe_buttons: Array[Button] = []
var recipe_lights: Array[Panel] = []
var recipe_images: Array[TextureRect] = []
var recipe_names: Array[Label] = []
var recipe_eye_overlays: Array[Control] = []
var material_images: Array[TextureRect] = []
var material_labels: Array[Label] = []
var bottom_material_images: Array[TextureRect] = []
var bottom_material_buttons: Array[Button] = []
var bottom_material_labels: Array[Label] = []
var title_label: Label
var selected_recipe_label: Label
var product_image: TextureRect
var product_eye_overlay: Control
var product_name_label: Label
var product_status_label: Label
var brew_button: Button
var clear_button: Button
var close_button: Button
var reaction_protocol_label: Label
var violet_core_button: Button
var smoke_panel: Panel
var smoke_label: Label
var selected_material_id := ""
var placed_reactions: Array[String] = ["", "", "", ""]


func setup(room: Node) -> void:
	chemistry_room = room
	name = "AlchemyPrototypeUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = 100
	_build_ui()


func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "PrototypeBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.01, 0.018, 0.98)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var artwork: TextureRect = TextureRect.new()
	artwork.name = "PrototypeArtwork"
	artwork.position = ART_ORIGIN
	artwork.size = ART_SIZE
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.texture = load("res://assets/ui/alchemy/alchemy_prototype_reference.png") as Texture2D
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.z_index = 1
	add_child(artwork)

	title_label = _label("Potion Crafting", Vector2(382, 101), Vector2(260, 42), 20, Color(0.33, 0.20, 0.12, 1.0))
	title_label.z_index = 20
	add_child(title_label)

	_build_recipe_list()
	_build_material_slots()
	_build_product_slot()
	_build_bottom_material_slots()
	_build_actions()
	_build_close_button()
	_build_smoke_feedback()
	CaseLocale.locale_changed.connect(func(_language: String) -> void: _refresh_all())
	_refresh_all()


func _build_recipe_list() -> void:
	for index: int in range(RECIPE_ROWS.size()):
		var row_source: Rect2 = RECIPE_ROWS[index]
		var row: Rect2 = _source_rect(row_source)
		var button: Button = Button.new()
		button.name = "RecipeItemButton_%d" % index
		button.position = row.position
		button.size = row.size
		button.text = ""
		button.flat = true
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_index = 30
		button.tooltip_text = "Select recipe slot %d" % (index + 1)
		button.pressed.connect(_on_recipe_slot_pressed.bind(index))
		add_child(button)
		recipe_buttons.append(button)

		var light: Panel = Panel.new()
		light.name = "RecipeSelectionLight_%d" % index
		var circle_center: Vector2 = _source_point(RECIPE_CIRCLE_CENTERS[index])
		light.position = circle_center - Vector2(13, 13)
		light.size = Vector2(26, 26)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.z_index = 31
		var light_style: StyleBoxFlat = StyleBoxFlat.new()
		light_style.bg_color = Color(1.0, 0.76, 0.18, 0.96)
		light_style.border_color = Color(1.0, 0.96, 0.60, 1.0)
		light_style.set_border_width_all(2)
		light_style.set_corner_radius_all(13)
		light_style.shadow_color = Color(1.0, 0.55, 0.08, 0.90)
		light_style.shadow_size = 10
		light.add_theme_stylebox_override("panel", light_style)
		light.visible = false
		add_child(light)
		recipe_lights.append(light)

		var potion: TextureRect = TextureRect.new()
		potion.name = "RecipePotionPreview_%d" % index
		potion.position = row.position + Vector2(108, 7)
		potion.size = Vector2(36, 36)
		potion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		potion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		potion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion.z_index = 32
		potion.visible = false
		add_child(potion)
		recipe_images.append(potion)
		var recipe_eye_overlay: Control = _create_eye_overlay(Vector2(30, 12))
		recipe_eye_overlay.name = "RecipeVisionEyes_%d" % index
		recipe_eye_overlay.position = row.position + Vector2(111, 19)
		recipe_eye_overlay.z_index = 33
		recipe_eye_overlay.visible = false
		add_child(recipe_eye_overlay)
		recipe_eye_overlays.append(recipe_eye_overlay)

		var recipe_name: Label = _label("", row.position + Vector2(120, 8), Vector2(56, 30), 8, Color(0.30, 0.18, 0.10, 1.0))
		recipe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		recipe_name.z_index = 32
		recipe_name.visible = false
		add_child(recipe_name)
		recipe_names.append(recipe_name)


func _build_material_slots() -> void:
	for index: int in range(MATERIAL_CENTERS.size()):
		var center: Vector2 = _source_point(MATERIAL_CENTERS[index])
		var button: Button = Button.new()
		button.name = "CentralMaterialSlot_%d" % index
		button.position = center - Vector2(42, 42)
		button.size = Vector2(84, 84)
		button.text = ""
		button.flat = true
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_index = 30
		button.tooltip_text = "Reaction node %d" % (index + 1)
		button.pressed.connect(_on_material_slot_pressed.bind(index))
		add_child(button)
		var image: TextureRect = TextureRect.new()
		image.name = "CentralMaterialImage_%d" % index
		image.position = center - Vector2(26, 28)
		image.size = Vector2(52, 52)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.z_index = 31
		add_child(image)
		material_images.append(image)
		var label: Label = _label("EMPTY", center + Vector2(-40, 28), Vector2(80, 20), 8, Color(0.92, 0.84, 0.62, 1.0))
		label.z_index = 32
		add_child(label)
		material_labels.append(label)


func _build_product_slot() -> void:
	var center: Vector2 = _source_point(Vector2(1077, 551))
	var product_button: Button = Button.new()
	product_button.name = "ProductSlotButton"
	product_button.position = center - Vector2(62, 62)
	product_button.size = Vector2(124, 124)
	product_button.text = ""
	product_button.flat = true
	product_button.process_mode = Node.PROCESS_MODE_ALWAYS
	product_button.mouse_filter = Control.MOUSE_FILTER_STOP
	product_button.z_index = 30
	product_button.tooltip_text = "View expected potion"
	product_button.pressed.connect(_on_product_pressed)
	add_child(product_button)
	product_image = TextureRect.new()
	product_image.name = "ProductPotionImage"
	product_image.position = center - Vector2(42, 46)
	product_image.size = Vector2(84, 84)
	product_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_image.z_index = 31
	product_image.visible = false
	add_child(product_image)
	product_eye_overlay = _create_eye_overlay(Vector2(46, 18))
	product_eye_overlay.name = "VisionProductEyes"
	product_eye_overlay.position = product_image.position + Vector2(19, 39)
	product_eye_overlay.z_index = 33
	product_eye_overlay.visible = false
	add_child(product_eye_overlay)
	product_name_label = _label("No recipe selected", center + Vector2(-76, 66), Vector2(152, 24), 10, Color(0.92, 0.78, 0.44, 1.0))
	product_name_label.z_index = 32
	add_child(product_name_label)
	product_status_label = _label("Select a recipe to preview", center + Vector2(-80, 88), Vector2(160, 20), 8, Color(0.76, 0.69, 0.58, 1.0))
	product_status_label.z_index = 32
	add_child(product_status_label)


func _build_bottom_material_slots() -> void:
	for index: int in range(BOTTOM_MATERIAL_CENTERS.size()):
		var center: Vector2 = _source_point(BOTTOM_MATERIAL_CENTERS[index])
		var button: Button = Button.new()
		button.name = "BottomMaterialSlot_%d" % index
		button.position = center - Vector2(30, 30)
		button.size = Vector2(60, 60)
		button.text = ""
		button.flat = true
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_index = 30
		button.pressed.connect(_on_bottom_material_pressed.bind(index))
		add_child(button)
		bottom_material_buttons.append(button)
		var image: TextureRect = TextureRect.new()
		image.name = "BottomMaterialImage_%d" % index
		image.position = center - Vector2(24, 24)
		image.size = Vector2(48, 48)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.z_index = 31
		add_child(image)
		bottom_material_images.append(image)
		var label := _label("", center + Vector2(-38, 30), Vector2(76, 18), 7, Color(0.92, 0.80, 0.52, 1.0))
		label.z_index = 32
		add_child(label)
		bottom_material_labels.append(label)


func _build_actions() -> void:
	selected_recipe_label = _label("No recipe selected", Vector2(390, 502), Vector2(300, 28), 11, Color(0.90, 0.75, 0.36, 1.0))
	selected_recipe_label.z_index = 20
	add_child(selected_recipe_label)
	reaction_protocol_label = _label("", Vector2(380, 530), Vector2(320, 36), 9, Color(0.88, 0.79, 0.64, 1.0))
	reaction_protocol_label.z_index = 20
	add_child(reaction_protocol_label)
	brew_button = Button.new()
	brew_button.name = "BrewButton"
	brew_button.text = "PULL EXTRACTION LEVER"
	brew_button.position = _source_rect(Rect2(710, 1034, 264, 91)).position
	brew_button.size = _source_rect(Rect2(710, 1034, 264, 91)).size
	brew_button.flat = true
	brew_button.process_mode = Node.PROCESS_MODE_ALWAYS
	brew_button.mouse_filter = Control.MOUSE_FILTER_STOP
	brew_button.z_index = 100
	brew_button.tooltip_text = "Extract the prepared reaction"
	brew_button.add_theme_font_size_override("font_size", 13)
	brew_button.pressed.connect(_on_brew_pressed)
	add_child(brew_button)
	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.text = "Reset Nodes"
	clear_button.position = _source_rect(Rect2(984, 1040, 119, 82)).position
	clear_button.size = _source_rect(Rect2(984, 1040, 119, 82)).size
	clear_button.flat = true
	clear_button.process_mode = Node.PROCESS_MODE_ALWAYS
	clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_button.z_index = 100
	clear_button.tooltip_text = "Clear the current recipe and material slots"
	clear_button.add_theme_font_size_override("font_size", 11)
	clear_button.pressed.connect(_clear_recipe)
	add_child(clear_button)
	var core_center := _source_point(Vector2(698, 625))
	violet_core_button = Button.new()
	violet_core_button.name = "ReactionCore"
	violet_core_button.position = core_center - Vector2(34, 34)
	violet_core_button.size = Vector2(68, 68)
	violet_core_button.flat = true
	violet_core_button.process_mode = Node.PROCESS_MODE_ALWAYS
	violet_core_button.mouse_filter = Control.MOUSE_FILTER_STOP
	violet_core_button.tooltip_text = "Reaction core"
	violet_core_button.z_index = 34
	violet_core_button.pressed.connect(_on_reaction_core_pressed)
	add_child(violet_core_button)


func _build_smoke_feedback() -> void:
	smoke_panel = Panel.new()
	smoke_panel.name = "VioletSmokeFeedback"
	smoke_panel.position = Vector2(345, 240)
	smoke_panel.size = Vector2(342, 58)
	smoke_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_panel.z_index = 120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.23, 0.09, 0.34, 0.92)
	style.border_color = Color(0.77, 0.54, 1.0, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.60, 0.22, 1.0, 0.80)
	style.shadow_size = 20
	smoke_panel.add_theme_stylebox_override("panel", style)
	smoke_panel.visible = false
	add_child(smoke_panel)
	smoke_label = _label("", Vector2(10, 6), Vector2(322, 46), 10, Color(0.98, 0.91, 1.0, 1.0))
	smoke_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	smoke_panel.add_child(smoke_label)


func _build_close_button() -> void:
	close_button = Button.new()
	close_button.name = "CloseAlchemyButton"
	close_button.text = "×"
	# 原型图红色关闭圆心约为 (1182,256)，按统一原图缩放转换到窗口坐标。
	var close_center: Vector2 = _source_point(Vector2(1182, 256))
	close_button.position = close_center - Vector2(26, 26)
	close_button.size = Vector2(52, 52)
	close_button.flat = true
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.z_index = 100
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	close_button.pressed.connect(_close_ui)
	add_child(close_button)


func _refresh_all() -> void:
	for index: int in range(recipe_buttons.size()):
		var available: bool = index < GameState.recipe_items.size()
		recipe_buttons[index].visible = available
		recipe_lights[index].visible = false
		recipe_images[index].visible = false
		recipe_eye_overlays[index].visible = false
		recipe_names[index].visible = false
		if not available:
			continue
		var recipe_id: String = GameState.recipe_items[index]
		var info: Dictionary = GameState.RECIPE_INFO.get(recipe_id, {})
		var produces: String = str(info.get("produces", ""))
		recipe_images[index].texture = load(_potion_texture_path(produces)) as Texture2D
		recipe_images[index].visible = true
		recipe_images[index].modulate = Color.WHITE if recipe_id == selected_recipe_id else Color(0.62, 0.62, 0.62, 0.80)
		recipe_eye_overlays[index].visible = recipe_id == "recipe_vision"
		recipe_names[index].text = "Swiftness" if recipe_id == "recipe_swift" else "Vision"
		recipe_names[index].visible = true
		if recipe_id == selected_recipe_id:
			recipe_lights[index].visible = true
	_update_slots_and_product()


func _update_slots_and_product() -> void:
	for image: TextureRect in material_images:
		image.texture = null
	for label: Label in material_labels:
		label.text = _text("EMPTY", "空槽")
	for image: TextureRect in bottom_material_images:
		image.texture = null
	for label: Label in bottom_material_labels:
		label.text = ""
	if selected_recipe_id.is_empty():
		selected_recipe_label.text = _text("NO RECIPE SELECTED", "尚未选择配方")
		reaction_protocol_label.text = _text("Select a recipe, then load four reaction nodes in any order.", "选择配方，再以任意顺序装填四个反应节点。")
		product_image.visible = false
		product_eye_overlay.visible = false
		product_name_label.text = _text("NO PRODUCT", "尚无产物")
		product_status_label.text = _text("Choose a recipe to reveal its protocol.", "选择配方以显示反应流程。")
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	selected_recipe_label.text = _text("REACTION PROTOCOL · ", "反应流程 · ") + _recipe_display_name(selected_recipe_id)
	var ingredient_ids := _required_ingredients(info)
	reaction_protocol_label.text = _text("Load all four nodes; duplicates are condensed into a single node.", "装满四个节点；重复材料会压缩为单一节点。")
	for index: int in range(mini(ingredient_ids.size(), bottom_material_images.size())):
		var item_id: String = ingredient_ids[index]
		bottom_material_images[index].texture = load(_ingredient_texture_path(item_id)) as Texture2D
		bottom_material_labels[index].text = _ingredient_display_name(item_id) + " ×%d" % _need_count(info, item_id)
		bottom_material_buttons[index].tooltip_text = _text("Select ", "选择 ") + _ingredient_display_name(item_id)
	for index: int in range(material_images.size()):
		var placed_id := placed_reactions[index]
		if placed_id.is_empty():
			material_labels[index].text = _text("NODE %d\nEMPTY" % (index + 1), "节点 %d\n空槽" % (index + 1))
			continue
		if placed_id == VIOLET_CATALYST:
			material_labels[index].text = _text("NODE %d\nVIOLET SEAL" % (index + 1), "节点 %d\n紫色稳定核" % (index + 1))
			continue
		material_images[index].texture = load(_ingredient_texture_path(placed_id)) as Texture2D
		material_labels[index].text = _ingredient_display_name(placed_id) + "\n×%d" % _need_count(info, placed_id)
	var produces: String = str(info.get("produces", ""))
	product_image.texture = load(_potion_texture_path(produces)) as Texture2D
	product_image.visible = true
	product_eye_overlay.visible = produces == "vision_potion"
	product_name_label.text = str(GameState.POTION_INFO.get(produces, {}).get("name", produces))
	product_status_label.text = _text("Reaction nodes: %d/4" % _loaded_node_count(), "反应节点：%d/4" % _loaded_node_count())


func _on_recipe_slot_pressed(index: int) -> void:
	if index < 0 or index >= GameState.recipe_items.size():
		return
	selected_recipe_id = GameState.recipe_items[index]
	_reset_reaction_nodes()
	selected_material_id = ""
	_hide_smoke()
	_refresh_all()


func _on_material_slot_pressed(index: int) -> void:
	if selected_recipe_id.is_empty():
		_show_smoke(_text("Choose a recipe before feeding the reaction core.", "请先选择配方，再向反应核心投料。"))
		return
	if placed_reactions[index] == VIOLET_CATALYST:
		_show_smoke(_text("The violet seal stabilizes the reaction. It cannot be removed.", "紫色稳定核负责稳定反应，无法移除。"), false)
		return
	if selected_material_id.is_empty():
		if not placed_reactions[index].is_empty():
			placed_reactions[index] = ""
			_refresh_all()
		return
	placed_reactions[index] = selected_material_id
	selected_material_id = ""
	_hide_smoke()
	_refresh_all()


func _on_bottom_material_pressed(index: int) -> void:
	if selected_recipe_id.is_empty():
		_show_smoke(_text("Choose a recipe first.", "请先选择配方。"))
		return
	var ingredients := _required_ingredients(GameState.RECIPE_INFO.get(selected_recipe_id, {}))
	if index >= ingredients.size():
		return
	selected_material_id = str(ingredients[index])
	_hide_smoke()
	product_status_label.text = _text("Selected: ", "已选择：") + _ingredient_display_name(selected_material_id) + _text(". Click any empty node.", "。点击任意空节点。")


func _on_product_pressed() -> void:
	pass


func _on_brew_pressed() -> void:
	if chemistry_room == null:
		return
	if selected_recipe_id.is_empty():
		_show_smoke(_text("Purple smoke: no protocol is loaded. Choose a recipe first.", "紫色烟雾：没有加载流程。请先选择配方。"))
		return
	var info: Dictionary = GameState.RECIPE_INFO.get(selected_recipe_id, {})
	if not _matches_protocol(info):
		_show_smoke(_text("Purple smoke: the four nodes do not match this protocol. Nothing was consumed.", "紫色烟雾：四个节点与流程不符。没有消耗材料。"))
		return
	hide()
	chemistry_room.call(
		"_craft_potion",
		selected_recipe_id,
		str(info.get("produces", "")),
		info.get("herb_cost", {}),
		info.get("material_cost", {})
	)


func _clear_recipe() -> void:
	_reset_reaction_nodes()
	selected_material_id = ""
	_hide_smoke()
	_refresh_all()


func _close_ui() -> void:
	hide()
	if chemistry_room != null:
		chemistry_room.call("end_dialogue_pause")


func _have_count(item_id: String) -> int:
	if GameState.HERB_INFO.has(item_id):
		return GameState.get_herb_count(item_id)
	return GameState.get_material_count(item_id)


func _need_count(recipe_info: Dictionary, item_id: String) -> int:
	if recipe_info.get("herb_cost", {}).has(item_id):
		return int(recipe_info.get("herb_cost", {}).get(item_id, 1))
	return int(recipe_info.get("material_cost", {}).get(item_id, 1))


func _required_ingredients(recipe_info: Dictionary) -> Array[String]:
	var ingredients: Array[String] = []
	for herb_id: Variant in recipe_info.get("herb_cost", {}).keys():
		ingredients.append(str(herb_id))
	for material_id: Variant in recipe_info.get("material_cost", {}).keys():
		ingredients.append(str(material_id))
	return ingredients


func _matches_protocol(recipe_info: Dictionary) -> bool:
	if _loaded_node_count() != 4:
		return false
	var expected := _required_ingredients(recipe_info)
	var loaded: Array[String] = []
	for item_id: String in placed_reactions:
		if not item_id.is_empty() and item_id != VIOLET_CATALYST:
			loaded.append(item_id)
	if loaded.size() != expected.size():
		return false
	for item_id: String in expected:
		if not loaded.has(item_id):
			return false
	return true


func _loaded_node_count() -> int:
	var count := 0
	for item_id: String in placed_reactions:
		if not item_id.is_empty():
			count += 1
	return count


func _reset_reaction_nodes() -> void:
	placed_reactions.clear()
	placed_reactions.append("")
	placed_reactions.append("")
	placed_reactions.append("")
	placed_reactions.append(VIOLET_CATALYST if not selected_recipe_id.is_empty() else "")


func _on_reaction_core_pressed() -> void:
	if selected_recipe_id.is_empty():
		_show_smoke(_text("The core is dormant. Select a recipe first.", "核心处于休眠状态。请先选择配方。"))
		return
	if _loaded_node_count() < 4:
		_show_smoke(_text("The core needs three loaded ingredients and its violet seal before extraction.", "核心需要三种装填材料与紫色稳定核才能萃取。"))
		return
	_show_smoke(_text("The violet core is ready. Pull the extraction lever.", "紫色核心已就绪。请拉下萃取拉杆。"), false)


func _show_smoke(message: String, is_error: bool = true) -> void:
	if smoke_panel == null:
		return
	smoke_label.text = message
	smoke_panel.visible = true
	smoke_panel.modulate = Color(1.0, 0.76, 1.0, 1.0) if is_error else Color(0.80, 0.94, 1.0, 1.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(smoke_panel, "scale", Vector2(1.04, 1.04), 0.12)
	tw.tween_property(smoke_panel, "scale", Vector2.ONE, 0.16)


func _hide_smoke() -> void:
	if smoke_panel != null:
		smoke_panel.visible = false


func _recipe_display_name(recipe_id: String) -> String:
	if recipe_id == "recipe_swift":
		return _text("SWIFTNESS", "迅捷药剂")
	if recipe_id == "recipe_vision":
		return _text("VISION", "视觉药剂")
	return str(GameState.RECIPE_INFO.get(recipe_id, {}).get("name", recipe_id))


func _ingredient_display_name(item_id: String) -> String:
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


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english


func _ingredient_texture_path(item_id: String) -> String:
	return GameState.get_item_texture_path(item_id)


func _potion_texture_path(potion_id: String) -> String:
	return GameState.get_item_texture_path(potion_id)


func _create_eye_overlay(overlay_size: Vector2) -> Control:
	var eyes: Control = Control.new()
	eyes.size = overlay_size
	eyes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eye_width: float = (overlay_size.x - 4.0) / 2.0
	for index: int in range(2):
		var eye: Panel = Panel.new()
		eye.position = Vector2(index * (eye_width + 4.0), 0)
		eye.size = Vector2(eye_width, overlay_size.y)
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var eye_style: StyleBoxFlat = StyleBoxFlat.new()
		eye_style.bg_color = Color(0.98, 0.95, 0.80, 1.0)
		eye_style.border_color = Color(0.20, 0.08, 0.30, 1.0)
		eye_style.set_border_width_all(1)
		eye_style.set_corner_radius_all(int(overlay_size.y / 2.0))
		eye.add_theme_stylebox_override("panel", eye_style)
		eyes.add_child(eye)
		var pupil: Panel = Panel.new()
		pupil.position = Vector2(eye_width * 0.38, overlay_size.y * 0.20)
		pupil.size = Vector2(eye_width * 0.28, overlay_size.y * 0.60)
		pupil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pupil_style: StyleBoxFlat = StyleBoxFlat.new()
		pupil_style.bg_color = Color(0.08, 0.03, 0.15, 1.0)
		pupil_style.set_corner_radius_all(int(overlay_size.y / 3.0))
		pupil.add_theme_stylebox_override("panel", pupil_style)
		eye.add_child(pupil)
	return eyes


func _source_point(point: Vector2) -> Vector2:
	return ART_ORIGIN + point * ART_SCALE


func _source_rect(rect: Rect2) -> Rect2:
	return Rect2(ART_ORIGIN + rect.position * ART_SCALE, rect.size * ART_SCALE)


func _label(text_value: String, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = label_position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
