extends SceneTree

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	_prepare_state()
	_check_hub_contracts()
	_check_item_model_contracts()
	await _check_note_journal()
	await _check_map_readability()
	await _check_start_screen()
	await _check_death_screen()
	await _check_ending_screen()
	await _check_alchemy_steps()
	await _check_final_board_steps()
	await _check_case_archive()
	paused = false
	_finish()


func _prepare_state() -> void:
	var note_hud := root.get_node_or_null("NoteHud")
	game_state.reset_new_game()
	note_hud.call("reset")
	game_state.game_started = false
	game_state.grant_wake_room_toolkit()
	for key_id: String in game_state.DEV_KEY_IDS:
		game_state.add_key(key_id)
	for recipe_id: String in game_state.RECIPE_INFO.keys():
		game_state.add_recipe(recipe_id)
	for herb_id: String in game_state.HERB_INFO.keys():
		game_state.add_herb(herb_id, 8)
	for material_id: String in game_state.MATERIAL_INFO.keys():
		game_state.add_material(material_id, 8)
	for evidence_id: String in game_state.DEV_EVIDENCE_IDS:
		game_state.add_evidence(evidence_id)
	game_state.set_story_flag("chemistry_butler_interviewed")
	note_hud.call("unlock")
	note_hud.call("add_clue", "ui_contract_clue", {
		"title": "Visible Design Contract",
		"content": "A readable note entry for UI validation.",
		"category": "evidence",
		"silent": true,
	})
	game_state.current_room_id = "floor_1_hub"
	var route: Array[Vector2] = [Vector2(1600, 1060), Vector2(900, 220), Vector2(220, 800)]
	game_state.configure_guardian_patrol_route(route)
	game_state.activate_guardian_hunt()
	game_state.game_started = true


func _check_hub_contracts() -> void:
	var key_hud := root.get_node_or_null("KeyHud")
	var note_hud := root.get_node_or_null("NoteHud")
	_expect(key_hud.find_child("KeyHubLabel", true, false) != null, "Key Hub has a permanent label")
	_expect(note_hud.find_child("NoteHubLabel", true, false) != null, "Note Hub has a permanent label")
	_expect(note_hud.find_child("HubRailBackplate", true, false) != null, "Hub entries share a field-kit rail")
	# MapHud is deliberately excluded: the blackout survey field must stay pure
	# black, so no shared light layer may sit behind it.
	for hub_name: String in ["InventoryHud", "KeyHud"]:
		var hub := root.get_node_or_null(hub_name)
		_expect(
			hub != null and hub.find_child("ArchiveScreenAtmosphere", true, false) != null,
			hub_name + " is lit by the shared archive atmosphere"
		)
	var map_hud := root.get_node_or_null("MapHud")
	_expect(
		map_hud != null and map_hud.find_child("ArchiveScreenAtmosphere", true, false) == null,
		"Survey map keeps no light layer behind its blackout field"
	)
	var journal: Node = null
	if note_hud != null and note_hud.has_method("get_journal"):
		journal = note_hud.call("get_journal") as Node
	_expect(
		journal != null and journal.find_child("ArchiveScreenAtmosphere", true, false) != null,
		"Note dossier is lit by the shared archive atmosphere"
	)


func _check_item_model_contracts() -> void:
	var required_models: Array[String] = [
		"recipe_swift",
		"recipe_vision",
		"blue_blossom",
		"moonleaf",
		"distilled_water",
		"iron_salt",
		"prism_dust",
		"swift_potion",
		"vision_potion",
		"green_potion",
		"purification_potion",
		"daze_potion",
		"shroud_potion",
		"recipe_purification",
		"recipe_daze",
		"recipe_shroud",
		"cleaning_powder_sample",
		"indicator_vial_sample",
		"broken_glass_sample",
	]
	for item_id: String in required_models:
		var texture_path := str(game_state.call("get_item_texture_path", item_id))
		_expect(not texture_path.is_empty(), item_id + " has a catalogued item model")
		_expect(ResourceLoader.exists(texture_path), item_id + " item model imports in Godot")
		_expect(
			texture_path.begins_with("res://assets/ui/item_models/pixel_art_v1/"),
			item_id + " uses the approved raster pixel-art family"
		)
	var inventory := root.get_node_or_null("InventoryHud")
	var bag_entries := inventory.call("_build_entries", "all") as Array
	for entry: Dictionary in bag_entries:
		if str(entry.get("kind", "")) in ["recipe", "herb", "material", "potion"]:
			_expect(
				not str(inventory.call("_item_icon_path", entry)).is_empty(),
				str(entry.get("id", "")) + " renders artwork in the Bag"
			)


func _check_note_journal() -> void:
	var scene := load("res://scenes/clue_journal.tscn") as PackedScene
	var journal := scene.instantiate()
	root.add_child(journal)
	await process_frame
	var overlay := journal.get_node_or_null("Overlay") as ColorRect
	_expect(overlay != null, "Note journal veil exists")
	if overlay != null:
		var perceived_light := (overlay.color.r + overlay.color.g + overlay.color.b) / 3.0
		_expect(perceived_light <= 0.08, "Note journal veil is dark, not white")
		_expect(overlay.color.a >= 0.82, "Note journal veil isolates the archive")
	journal.queue_free()
	await process_frame


func _check_map_readability() -> void:
	var map_hud := root.get_node_or_null("MapHud")
	map_hud.call("_refresh_fog_texture")
	var fog_image: Image = map_hud.get("fog_image") as Image
	_expect(fog_image != null and not fog_image.is_empty(), "Map fog image exists")
	if fog_image != null and not fog_image.is_empty():
		var center := fog_image.get_pixel(fog_image.get_width() / 2, fog_image.get_height() / 2)
		_expect(center.a >= 0.99, "Unpowered pursuit map reveals no architectural silhouette")
	var minimap_fog := map_hud.get("guardian_minimap_fog_rect") as TextureRect
	_expect(
		minimap_fog != null and minimap_fog.texture == map_hud.get("fog_texture"),
		"Guardian minimap cannot bypass the power-gated map fog"
	)
	map_hud.call("open_map")
	await process_frame
	var bag_entry := root.get_node_or_null("InventoryHud/InventoryHubEntry") as Control
	var key_entry := root.get_node_or_null("KeyHud/KeyHubEntry") as Control
	var note_entry := root.get_node_or_null("NoteHud/IconArea") as CanvasItem
	_expect(bag_entry == null or not bag_entry.visible, "Opening a Hub suppresses the Bag entry")
	_expect(key_entry == null or not key_entry.visible, "Opening a Hub suppresses the Key entry")
	_expect(note_entry == null or not note_entry.visible, "Opening a Hub suppresses the Note entry")
	map_hud.call("close_map")
	await process_frame
	_expect(bag_entry == null or bag_entry.visible, "Closing a Hub restores the field-kit rail")
	await process_frame


func _check_start_screen() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/start_ui.tscn")
	_expect(screen.find_child("CaseMeta", true, false) != null, "Start screen has a case metadata strip")
	_expect(
		screen.find_child("ArchiveScreenAtmosphere", true, false) != null,
		"Start screen is lit by the shared archive atmosphere"
	)
	_expect(
		screen.find_child("ArchiveDossierChrome", true, false) != null,
		"Start intake reads as a physical dossier"
	)
	await _release(screen)


func _check_death_screen() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/death_ui.tscn")
	_expect(screen.find_child("RecoveryStamp", true, false) != null, "Death screen has a recovery status stamp")
	_expect(
		screen.find_child("ArchiveScreenAtmosphere", true, false) != null,
		"Interruption report is lit by the shared archive atmosphere"
	)
	_expect(
		screen.find_child("ArchiveDossierChrome", true, false) != null,
		"Interruption report reads as a physical dossier"
	)
	await _release(screen)


func _check_ending_screen() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/game_over_ui.tscn")
	_expect(screen.find_child("ResolutionStamp", true, false) != null, "Ending screen has a resolution status stamp")
	var atmosphere := screen.find_child("ArchiveScreenAtmosphere", true, false) as ColorRect
	var chrome := screen.find_child("ArchiveDossierChrome", true, false) as Control
	_expect(atmosphere != null, "Resolution record is lit by the shared archive atmosphere")
	_expect(chrome != null, "Resolution record reads as a physical dossier")
	if chrome != null:
		screen.call("show_ordinary_case")
		await process_frame
		var sealed_accent: Color = chrome.get_meta("archive_ui_chrome_accent", Color.BLACK)
		screen.call("show_true_case")
		await process_frame
		var true_accent: Color = chrome.get_meta("archive_ui_chrome_accent", Color.BLACK)
		_expect(
			not sealed_accent.is_equal_approx(true_accent),
			"Each ending files the same record under its own accent"
		)
	await _release(screen)


func _check_alchemy_steps() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/alchemy_workbench_ui.tscn")
	screen.call("open", null)
	await process_frame
	var subtitle := screen.get("subtitle_label") as Label
	_expect(subtitle != null and subtitle.text.contains("1 / 3"), "Alchemy opens with Step 1 guidance")
	var recipe_icons := screen.get("recipe_icons") as Dictionary
	_expect(recipe_icons.size() == 2, "Alchemy formula archive shows two distinct blueprint models")
	for recipe_id: String in ["recipe_swift", "recipe_vision"]:
		var recipe_icon := recipe_icons.get(recipe_id) as TextureRect
		_expect(recipe_icon != null and recipe_icon.texture != null, recipe_id + " blueprint is visible on the workbench")
	screen.call("_choose_recipe", "recipe_swift")
	await process_frame
	_expect(subtitle.text.contains("2 / 3"), "Alchemy advances to Step 2 after selecting a formula")
	var reagent_icons := screen.get("reagent_icons") as Dictionary
	for item_id: String in ["blue_blossom", "distilled_water", "iron_salt"]:
		var reagent_icon := reagent_icons.get(item_id) as TextureRect
		_expect(reagent_icon != null and reagent_icon.texture != null, item_id + " model is visible in the reagent rack")
	_check_alchemy_row_legibility(screen)
	for placement: Dictionary in [
		{"item": "blue_blossom", "slot": 0},
		{"item": "distilled_water", "slot": 1},
		{"item": "iron_salt", "slot": 2},
	]:
		screen.call("_select_reagent", placement["item"])
		screen.call("_press_reaction_node", placement["slot"])
	await process_frame
	_expect(subtitle.text.contains("3 / 3"), "Alchemy advances to Step 3 when extraction is ready")
	screen.call("_extract_potion")
	_expect(bool(screen.get("extracting")), "Alchemy enters a guarded extraction phase")
	_expect((screen.get("extraction_beams") as Array).size() == 3, "Alchemy traces three reagent feeds to the product")
	_expect(
		screen.find_child("OpticalEnergyPacket", true, false) != null,
		"Alchemy reagents travel as visible energy packets"
	)
	await create_timer(0.78).timeout
	_expect(
		screen.find_child("OpticalImpactRing", true, false) != null,
		"Alchemy product socket pulses after all feeds arrive"
	)
	await create_timer(0.72).timeout
	_expect(not bool(screen.get("extracting")) and not screen.visible, "Alchemy closes only after extraction settles")
	await _release(screen)


func _check_alchemy_row_legibility(screen: Node) -> void:
	# The rack rows carry their icon as a sibling overlay, so nothing but reserved
	# stylebox space keeps a name out from under its own icon. This regressed once,
	# silently renaming a formula on screen, so the clearance is now a contract.
	var rows: Array[Dictionary] = []
	for source: Array in [
		[screen.get("recipe_buttons"), screen.get("recipe_icons")],
		[screen.get("reagent_buttons"), screen.get("reagent_icons")],
	]:
		var buttons := source[0] as Dictionary
		var icons := source[1] as Dictionary
		for key: Variant in buttons.keys():
			rows.append({"button": buttons[key], "icon": icons.get(key)})
	_expect(rows.size() >= 5, "Alchemy rack shows both formula and reagent rows")
	for row: Dictionary in rows:
		var button := row["button"] as Button
		var icon := row["icon"] as TextureRect
		if button == null or icon == null:
			continue
		_expect(
			button.text.strip_edges() == button.text,
			"Alchemy row '" + button.name + "' clears its icon with reserved space, not padded text"
		)
		var reserved: float = button.get_theme_stylebox("normal").content_margin_left
		var icon_overhang: float = icon.position.x + icon.size.x - button.position.x
		_expect(
			reserved >= icon_overhang,
			"Alchemy row '" + button.name + "' starts its label past the icon (%.1f >= %.1f)" % [reserved, icon_overhang]
		)
		_expect(
			button.get_theme_font_size("font_size") * float(button.text.length()) < (button.size.x - reserved) * 2.4,
			"Alchemy row '" + button.name + "' has room for its full name"
		)


func _check_final_board_steps() -> void:
	var screen := await _instantiate_scene("res://scenes/ui/final_case_board.tscn")
	screen.call("open_case")
	await process_frame
	var source_heading := screen.get("source_heading") as Label
	var conclusion_heading := screen.get("conclusion_heading") as Label
	var lever_button := screen.get("lever_button") as Button
	_expect(source_heading != null and source_heading.text.begins_with("1 ·"), "Final board labels evidence as Step 1")
	_expect(conclusion_heading != null and conclusion_heading.text.begins_with("2 ·"), "Final board labels conclusions as Step 2")
	_expect(lever_button != null and lever_button.text.begins_with("3 ·"), "Final board labels accusation as Step 3")
	_expect(
		screen.find_child("FinalBoardOpticalVFX", true, false) != null,
		"Final board owns a non-blocking connection effect layer"
	)
	screen.call("_toggle_source", "fake_red_stain")
	_expect(
		screen.find_child("OpticalImpactRing", true, false) != null,
		"Pinning evidence creates an impact ring"
	)
	screen.call("_toggle_source", "butler_service_account")
	screen.call("_form_conclusion")
	screen.call("_select_conclusion", "staged_scene")
	screen.call("_place_selected_conclusion", "method")
	var method_slot := (screen.get("slot_buttons") as Dictionary).get("method") as Button
	var connection := screen.find_child("EvidenceConnection_conclusion_method", true, false) as Line2D
	_expect(
		screen.find_child("TravellingOpticalJewel", true, false) != null,
		"Formed conclusion travels physically into its role slot"
	)
	_expect(connection != null and connection.visible, "Conclusion connection begins as a growing line")
	_expect(method_slot.modulate.a < 0.5, "Role slot waits visually for the conclusion token")
	await create_timer(0.44).timeout
	_expect(method_slot.modulate.a > 0.9, "Role slot settles after conclusion impact")
	_expect(
		connection.points[0].distance_to(connection.points[1]) > 20.0,
		"Conclusion line reaches its role slot"
	)
	await _release(screen)


func _check_case_archive() -> void:
	var archive_script := load("res://scripts/case_archive_ui.gd")
	game_state.set_story_flag("normal_ending", false)
	game_state.set_story_flag("perfect_ending", false)
	_expect(not archive_script.is_unlocked(), "Case Archive stays sealed before any ending")
	game_state.set_story_flag("normal_ending")
	_expect(archive_script.is_unlocked(), "Ordinary ending unlocks the Case Archive")

	var archive: Node = archive_script.new()
	root.add_child(archive)
	await process_frame
	archive.call("open_archive")
	await process_frame
	for section_id: String in ["evidence", "people", "timeline", "science", "verdict"]:
		archive.call("_select_section", section_id)
		await process_frame
		var column := archive.find_child("ArchiveEntryColumn", true, false) as VBoxContainer
		_expect(
			column != null and column.get_child_count() > 0,
			"Case Archive lists records under " + section_id
		)

	archive.call("_select_section", "evidence")
	await process_frame
	var evidence_title := archive.find_child("ArchiveEntryTitle", true, false) as Label
	_expect(
		evidence_title != null and evidence_title.text != "fake_red_stain",
		"Case Archive names evidence with the accusation table's vocabulary"
	)

	var sealed_stamp_text := _archive_stamp_text(archive)
	game_state.set_story_flag("perfect_ending")
	archive.call("_select_section", "verdict")
	await process_frame
	_expect(
		_archive_stamp_text(archive) != sealed_stamp_text,
		"Case Archive files each ending under its own verdict stamp"
	)
	game_state.set_story_flag("normal_ending", false)
	game_state.set_story_flag("perfect_ending", false)
	await _release(archive)


func _archive_stamp_text(archive: Node) -> String:
	var stamp := archive.find_child("ArchiveVerdictStamp", true, false)
	if stamp == null:
		return ""
	var label := stamp.get_node_or_null("StampText") as Label
	return "" if label == null else label.text


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
		node.queue_free()
	await process_frame
	await process_frame
	paused = false


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("ui_design_contract_test: PASS")
		quit(0)
		return
	printerr("ui_design_contract_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
