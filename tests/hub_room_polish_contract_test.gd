extends SceneTree

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	_prepare_state()
	await _check_note_hub()
	await _check_bag_hub()
	await _check_key_hub()
	await _check_map_hub_layout()
	await _check_red_stain_materials()
	await _check_final_board_copy()
	await _check_library_rgb_style()
	await _check_circuit_switch_alignment()
	await _check_shared_effect_timing()
	paused = false
	_finish()


func _prepare_state() -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.current_room_id = "chemistry_room"
	game_state.call("grant_wake_room_toolkit")
	for recipe_id: String in ["recipe_swift", "recipe_vision"]:
		game_state.call("add_recipe", recipe_id)
	for herb_id: String in ["blue_blossom", "moonleaf"]:
		game_state.call("add_herb", herb_id, 8)
	for material_id: String in ["distilled_water", "iron_salt", "prism_dust"]:
		game_state.call("add_material", material_id, 8)
	for potion_id: String in ["swift_potion", "vision_potion"]:
		game_state.call("add_inventory_item", potion_id)
	game_state.call("add_dish", "castle_ration", 2)
	game_state.call("collect_final_key_fragment", 1)
	game_state.call("add_map", "circuit_repair_map")


func _check_note_hub() -> void:
	var scene := load("res://scenes/clue_journal.tscn") as PackedScene
	var journal := scene.instantiate()
	root.add_child(journal)
	await process_frame
	await process_frame
	var close_button := journal.find_child("JournalCloseButton", true, false) as Button
	_expect(close_button != null, "Note Hub has a real focusable close button")
	var x_visual := journal.get_node_or_null("MainPanel/XVisual") as CanvasItem
	_expect(x_visual == null or not x_visual.visible, "Note Hub no longer uses the oversized Sprite2D close emblem")
	var list_scroll := journal.get("list_scroll") as ScrollContainer
	var native_bar := list_scroll.get_v_scroll_bar()
	var decor_bar := journal.get("scroll_decor") as VScrollBar
	_expect(
		list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and native_bar.get_parent() == list_scroll,
		"Note Hub index scrolls with its native bar and hides it when the index fits"
	)
	_expect(decor_bar == null or not decor_bar.visible, "Note Hub removes the duplicate decorative scrollbar")
	journal.call("_show_home_page")
	var detail_text := journal.get("detail_text") as RichTextLabel
	_expect(detail_text.text.begins_with("[center]"), "Note Hub document body is center-aligned")
	var main_panel := journal.get("main_panel") as Panel
	var left_panel := journal.get("left_panel_bg") as Panel
	var parchment := journal.get("parchment") as TextureRect
	_expect(main_panel.find_child("ArchiveHubChrome", true, false) != null, "Note Hub uses shared Archive chrome")
	_expect(
		parchment.stretch_mode == TextureRect.STRETCH_SCALE
		and str(parchment.get_meta("hub_artwork_fit", "")) == "full_frame_content_safe",
		"Note Hub parchment expands to its dossier frame"
	)
	_expect(parchment.size.x > left_panel.size.x, "Note Hub gives the dossier more width than the index")
	_expect(
		detail_text.text.contains("RECORDS FILED") or detail_text.text.contains("已归档记录"),
		"Note Hub home page shows real case progress instead of empty space"
	)
	journal.queue_free()
	await process_frame
	await process_frame


func _check_bag_hub() -> void:
	var inventory := root.get_node("InventoryHud")
	inventory.call("dismiss_feature_unlock")
	inventory.call("open_bag")
	var category_buttons := inventory.get("category_buttons") as Dictionary
	var detail_frame := inventory.get("detail_frame") as TextureRect
	var board := inventory.get("board_panel") as Control
	_expect(board.find_child("ArchiveHubChrome", true, false) != null, "Bag Hub uses shared Archive chrome")
	var expected_categories: Array[String] = ["all", "potions", "materials", "papers"]
	_expect(category_buttons.size() == 4, "Bag Hub exposes exactly four filing categories")
	for category_id: String in expected_categories:
		_expect(category_buttons.has(category_id), "Bag Hub exposes the %s category" % category_id)
	var expected_category_rects: Array[Rect2] = [
		Rect2(127.0, 76.0, 102.0, 31.0),
		Rect2(235.0, 76.0, 102.0, 31.0),
		Rect2(343.0, 76.0, 102.0, 31.0),
		Rect2(451.0, 76.0, 102.0, 31.0),
	]
	for category_index: int in range(expected_categories.size()):
		var category_button := category_buttons.get(expected_categories[category_index]) as Button
		_expect(
			category_button != null
			and Rect2(category_button.position, category_button.size).is_equal_approx(expected_category_rects[category_index]),
			"%s category matches its authored board recess (actual %s, expected %s)"
			% [
				expected_categories[category_index],
				Rect2(category_button.position, category_button.size) if category_button != null else Rect2(),
				expected_category_rects[category_index],
			]
		)
	var material_entries := inventory.call("_build_entries", "materials") as Array
	_expect(
		_entry_kinds(material_entries) == ["dish", "fragment", "herb", "material"],
		"Bag Materials groups herbs, reagents, dishes and key fragments"
	)
	var paper_entries := inventory.call("_build_entries", "papers") as Array
	_expect(
		_entry_kinds(paper_entries) == ["map", "recipe"],
		"Bag Papers groups formula sheets and route/repair maps"
	)
	var board_art := board.get_node_or_null("InventoryBoardTexture") as TextureRect
	_expect(
		board_art != null
		and board_art.stretch_mode == TextureRect.STRETCH_SCALE
		and board_art.size.is_equal_approx(board.size),
		"Bag Hub artwork fills the complete workbench frame"
	)
	var category_overflow := false
	for button_variant: Variant in category_buttons.values():
		var button := button_variant as Button
		if button == null:
			continue
		var button_rect := Rect2(button.global_position, button.size)
		var detail_rect := Rect2(detail_frame.global_position, detail_frame.size)
		if button_rect.intersects(detail_rect):
			category_overflow = true
		var count_badge := button.get_node_or_null("CategoryCount") as Label
		_expect(count_badge != null, "%s has a separate count badge" % button.name)
		_expect(_button_text_fits(button, 22.0), "%s category name fits without clipping" % button.name)
	_expect(not category_overflow, "Bag category rail stays inside the left filing column")
	var description := inventory.get("detail_description") as Label
	var quantity := inventory.get("detail_quantity") as Label
	var requirements := inventory.get("detail_requirements") as Label
	var use_button := inventory.get("detail_use_button") as Button
	var bottom_status := inventory.get("bottom_status") as Label
	_expect(description.position.y + description.size.y + 4.0 <= quantity.position.y, "Bag description does not overlap quantity")
	_expect(quantity.position.y + quantity.size.y + 4.0 <= requirements.position.y, "Bag quantity does not overlap requirements")
	_expect(requirements.position.y + requirements.size.y + 4.0 <= use_button.position.y, "Bag requirements do not overlap the action")
	_expect(use_button.position.y + use_button.size.y + 4.0 <= bottom_status.position.y, "Bag action does not overlap the bottom status")
	inventory.set("entries", [{
		"id": "fit_contract",
		"kind": "fragment",
		"name": "Final Room Key Fragment (4/4)",
		"description": "A torn piece of the Final Room Key. Four fragments must be found: three in the hall machines and one behind the service maintenance panel.",
		"quantity": 1,
		"requirements": "Key fragment from a hall machine or service panel",
	}])
	inventory.set("selected_index", 0)
	inventory.call("_update_detail_panel")
	await process_frame
	_expect(_label_lines_fit(description), "Bag longest description fits its reading area")
	_expect(_label_lines_fit(requirements), "Bag longest requirement fits its reading area")
	inventory.call("close_bag")
	paused = false


func _check_key_hub() -> void:
	for key_id: String in game_state.DEV_KEY_IDS:
		game_state.add_key(key_id)
	var key_hud := root.get_node("KeyHud")
	key_hud.call("dismiss_unlock_toast")
	key_hud.call("open_hub")
	await process_frame
	var board := key_hud.get("board_panel") as Control
	_expect(board.find_child("ArchiveHubChrome", true, false) != null, "Key Hub uses shared Archive chrome")
	_expect(board.find_child("KeyDetailChamber", true, false) != null, "Key Hub has a separate detail chamber")
	var artwork_fit := board.get_node_or_null("KeyHubArtworkFit") as Control
	_expect(
		artwork_fit != null
		and str(artwork_fit.get_meta("fit_strategy", "")) == "authored_atlas_regions",
		"Key Hub enlarges authored board regions to the redesigned layout"
	)
	var slots: Array[TextureButton] = []
	for index: int in range(8):
		var slot := board.get_node_or_null("KeySlot_%02d" % index) as TextureButton
		if slot != null:
			slots.append(slot)
			_expect(slot.get_node_or_null("KeyState") != null, "Key slot %d has a state label" % (index + 1))
			var row_art_name := "KeyTopRowArtwork" if index < 4 else "KeyBottomRowArtwork"
			var row_art := artwork_fit.get_node_or_null(row_art_name) as TextureRect if artwork_fit != null else null
			_expect(
				row_art != null and _rect_contains(
					Rect2(row_art.position, row_art.size),
					Rect2(slot.position, slot.size)
				),
				"Key slot %d sits inside its enlarged authored row" % (index + 1)
			)
	var overlap := false
	for first: int in range(slots.size()):
		for second: int in range(first + 1, slots.size()):
			if Rect2(slots[first].position, slots[first].size).intersects(Rect2(slots[second].position, slots[second].size)):
				overlap = true
	_expect(not overlap, "Key Hub slots never overlap")
	var detail := key_hud.get("detail_label") as Label
	var detail_chamber := key_hud.get("detail_panel") as Panel
	var detail_art := artwork_fit.get_node_or_null("KeyDetailArtwork") as TextureRect if artwork_fit != null else null
	_expect(
		detail_art != null and _rect_contains(
			Rect2(detail_art.position, detail_art.size),
			Rect2(detail_chamber.position, detail_chamber.size)
		),
		"Key detail chamber sits inside its enlarged authored parchment"
	)
	key_hud.set("selected_index", 3)
	key_hud.call("_sync_key_state")
	await process_frame
	_expect(_label_lines_fit(detail), "Key description and recovery count fit their chamber")
	key_hud.call("close_hub")
	paused = false


func _check_map_hub_layout() -> void:
	game_state.current_room_id = "floor_1_hub"
	game_state.unlock_map_hub()
	var map_hud := root.get_node("MapHud")
	map_hud.call("open_map")
	await process_frame
	var overlay := map_hud.get("overlay") as Control
	var map_panel := map_hud.get("map_panel") as Panel
	var map_art := map_hud.get("map_texture_rect") as TextureRect
	var fog_art := map_hud.get("fog_texture_rect") as TextureRect
	var ledger := map_hud.get("map_ledger") as Panel
	var detail := map_hud.get("map_detail") as Label
	_expect(overlay.find_child("ArchiveHubChrome", true, false) != null, "Map Hub uses shared Archive chrome")
	_expect(
		map_art.stretch_mode == TextureRect.STRETCH_SCALE
		and fog_art.stretch_mode == TextureRect.STRETCH_SCALE
		and map_art.size.is_equal_approx(map_panel.size)
		and fog_art.size.is_equal_approx(map_panel.size),
		"Map artwork and exploration fog fill one coordinate-locked frame"
	)
	_expect(ledger.size.x >= 220.0 and detail.size.x >= 190.0, "Map Hub reserves a readable survey-ledger width")
	_expect(_label_lines_fit(detail), "Map survey ledger copy fits without clipping")
	map_hud.call("close_map")
	paused = false


func _check_red_stain_materials() -> void:
	var scene := load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
	var room := scene.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.30).timeout
	var inventory := root.get_node("InventoryHud")
	inventory.call("dismiss_feature_unlock")
	inventory.set("_had_inventory", bool(inventory.call("_has_stored_items")))
	room.call("show_red_stain_intro")
	var sample_strip := room.get("red_stain_material_strip") as Control
	_expect(sample_strip != null and sample_strip.visible, "Red-stain dialogue displays powder, indicator and glass samples")
	_expect(not (inventory.get("feature_panel") as Panel).visible, "Red-stain dialogue does not show a Bag material toast")
	room.call("_on_red_stain_examined")
	_expect(sample_strip != null and sample_strip.visible, "Red-stain analysis keeps the trace samples visible")
	room.call("_on_red_stain_recorded")
	_expect(not (inventory.get("feature_panel") as Panel).visible, "Recording red-stain evidence remains isolated from Bag notifications")
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame
	paused = false


func _check_final_board_copy() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/final_case_board.tscn")
	screen.call("open_case")
	await process_frame
	var lever := screen.get("lever_button") as Button
	_expect(not _contains_suspect_name(lever.text), "Final lever does not reveal the accused suspect in its label")
	screen.set("true_case_mode", true)
	screen.call("_refresh_copy")
	screen.call("_refresh")
	_expect(not _contains_suspect_name(lever.text), "True-case lever does not reveal the command author in its label")
	await _release(screen)


func _contains_suspect_name(text: String) -> bool:
	var normalized := text.to_lower()
	return normalized.contains("butler") or normalized.contains("mechanic") or text.contains("管家") or text.contains("机械师")


func _label_lines_fit(label: Label) -> bool:
	if label == null:
		return false
	return label.get_visible_line_count() >= label.get_line_count()


func _button_text_fits(button: Button, reserved_width: float = 0.0) -> bool:
	if button == null:
		return false
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var measured := font.get_string_size(
		button.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	return measured <= button.size.x - reserved_width - 8.0


func _entry_kinds(source_entries: Array) -> Array[String]:
	var kinds: Array[String] = []
	for entry: Dictionary in source_entries:
		var kind := str(entry.get("kind", ""))
		if not kinds.has(kind):
			kinds.append(kind)
	kinds.sort()
	return kinds


func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	var epsilon := Vector2(0.01, 0.01)
	return outer.has_point(inner.position) and outer.has_point(inner.end - epsilon)


func _check_library_rgb_style() -> void:
	var room := await _instantiate_scene("res://scenes/floor_1/library_room.tscn")
	var stand := room.find_child("RGBFilterStand", true, false) as Node2D
	_expect(stand != null and str(stand.get_meta("style_family", "")) == "ashford_jewel_glass", "Library RGB stand uses the Ashford jewel-glass style")
	var framed_count := 0
	var soft_glass_count := 0
	if stand != null:
		for filter_name: String in ["RedFilter", "GreenFilter", "BlueFilter"]:
			var filter_node := stand.get_node_or_null(filter_name) as Node2D
			if filter_node != null and filter_node.get_node_or_null("BrassFrame") != null:
				framed_count += 1
			if filter_node != null:
				var glass := filter_node.get_node_or_null("JewelGlass") as Polygon2D
				if glass != null and glass.color.a <= 0.62:
					soft_glass_count += 1
	_expect(framed_count == 3, "All Library RGB filters have dark-brass frames")
	_expect(soft_glass_count == 3, "All Library RGB colors are muted translucent glass")
	await _release(room)


func _check_circuit_switch_alignment() -> void:
	var room := await _instantiate_scene("res://scenes/floor_1/circuit_room.tscn")
	var switch_nodes: Dictionary = {
		"switch_left": room.get_node_or_null("Worldsort/SwitchLeft"),
		"switch_right": room.get_node_or_null("Worldsort/SwitchRight"),
		"master_switch": room.get_node_or_null("Worldsort/MasterSwitch"),
	}
	for switch_id: String in switch_nodes:
		var switch_node := switch_nodes[switch_id] as Node2D
		_expect(
			switch_node != null and str(switch_node.get_meta("style_family", "")) == "ashford_circuit_switch",
			"%s uses a styled Circuit switch model" % switch_id
		)
		_expect(switch_node != null and switch_node.get_node_or_null("SwitchModel") != null, "%s has visible switch artwork" % switch_id)
		# The plate now draws its own iron backing, brass bezel and hinged blade, so
		# the contract is that the blade actually travels between open and closed.
		# A switch whose two states look identical tells the player nothing.
		var model := switch_node.get_node_or_null("SwitchModel") as Node2D if switch_node != null else null
		_expect(model != null and model.has_method("set_closed"), "%s is a throwable plate, not a static image" % switch_id)
		if model != null and model.has_method("set_closed"):
			model.call("set_closed", false, false)
			var open_angle := float(model.get("_blade_degrees"))
			model.call("set_closed", true, false)
			var closed_angle := float(model.get("_blade_degrees"))
			_expect(
				absf(open_angle - closed_angle) >= 10.0,
				"%s blade visibly travels between open and seated (%.1f vs %.1f)" % [switch_id, open_angle, closed_angle]
			)
			_expect(
				open_angle <= 0.0 and absf(open_angle) <= 46.0,
				"%s blade lifts without swinging out through its own bezel (%.1f)" % [switch_id, open_angle]
			)
			model.call("set_closed", false, false)
	var test_switch := switch_nodes["switch_left"] as Node2D
	room.call("_update_switch_visual", "switch_left", true, true)
	var pending_glow := test_switch.get_node_or_null("ActiveGlow") as Polygon2D
	_expect(
		test_switch.find_child("OpticalEnergyPacket", true, false) != null,
		"Circuit switch receives a travelling energy packet before activation"
	)
	_expect(pending_glow != null and not pending_glow.visible, "Circuit glow waits for charge impact")
	await create_timer(0.36).timeout
	var charge_line := test_switch.get_node_or_null("SwitchChargeLine") as Line2D
	_expect(pending_glow.visible, "Circuit glow appears after charge impact")
	_expect(charge_line != null and charge_line.visible, "Circuit switch keeps a sustained charge line")
	room.call("_update_switch_visual", "switch_left", false, false)
	var map_hud := root.get_node("MapHud")
	map_hud.call("show_repair_map")
	await process_frame
	for switch_id: String in switch_nodes:
		var marker := map_hud.find_child("RepairSwitchMarker_" + switch_id, true, false) as Control
		_expect(marker != null, "Repair map has a named marker for " + switch_id)
		if marker != null:
			var source_position := marker.get_meta("source_world_position", Vector2.ZERO) as Vector2
			var switch_node := switch_nodes[switch_id] as Node2D
			_expect(source_position.is_equal_approx(switch_node.global_position), "Repair map marker matches the real %s position" % switch_id)
	map_hud.call("close_repair_map")
	await _release(room)


func _check_shared_effect_timing() -> void:
	var reward_hud := root.get_node("ItemRewardHud")
	reward_hud.call("dismiss_for_overlay")
	reward_hud.call("show_clue", "fx_contract", "Recovered Test Record", "Timing contract")
	var reward_panel := reward_hud.get("_panel") as Panel
	_expect(
		reward_panel.visible and reward_panel.scale.x < 0.95,
		"Item reward begins with a weighted scale arrival"
	)
	await create_timer(0.32).timeout
	_expect(reward_panel.scale.is_equal_approx(Vector2.ONE), "Item reward settles at full scale")
	reward_hud.call("dismiss_for_overlay")

	var parchment_hud := root.get_node("ParchmentHud")
	parchment_hud.call("show_parchment", "Timing Record", "The archive unfurls before it can be read.", "")
	var parchment_panel := parchment_hud.get("_panel") as Panel
	_expect(
		parchment_panel.visible and parchment_panel.scale.x < 0.8,
		"Parchment begins as a horizontally folded scroll"
	)
	await create_timer(0.34).timeout
	_expect(parchment_panel.scale.is_equal_approx(Vector2.ONE), "Parchment unfurls to full width")
	parchment_hud.call("_on_confirm_pressed")


func _instantiate_scene(path: String) -> Node:
	var scene := load(path) as PackedScene
	if scene == null:
		_fail("Could not load scene: " + path)
		return Node.new()
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func _release(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if current_scene == node:
			current_scene = null
		node.queue_free()
	await process_frame
	await process_frame
	paused = false


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	game_state.game_started = false
	game_state.set("_loading_save", false)
	if failures.is_empty():
		print("hub_room_polish_contract_test: PASS")
		quit(0)
		return
	printerr("hub_room_polish_contract_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
