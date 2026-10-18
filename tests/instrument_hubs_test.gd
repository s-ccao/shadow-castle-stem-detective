extends SceneTree

var failures: Array[String] = []
var state: Node
var bag: Node
var keys: Node
var notes: Node
var journal: Node
var map: Node
var capture := false
var capture_directory := ""
var potion_applications := 0


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	capture = "--capture" in OS.get_cmdline_user_args()
	capture_directory = OS.get_environment("INSTRUMENT_HUBS_EVIDENCE_DIR")
	call_deferred("_run")


func _run() -> void:
	if capture and (not capture_directory.is_absolute_path() or not DirAccess.dir_exists_absolute(capture_directory)):
		printerr("Capture requires an existing absolute INSTRUMENT_HUBS_EVIDENCE_DIR outside the project.")
		quit(1)
		return
	state = root.get_node("GameState")
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.set("_loading_save", true)
	state.game_started = true
	state.developer_mode = false
	state.current_room_id = "floor_1_hub"
	root.get_node("CaseLocale").call("set_language", "en")
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	state.call("add_key", "chemistry_room_key")
	state.call("add_inventory_item", "swift_potion")
	state.call("add_inventory_item", "vision_potion")
	state.call("add_material", "distilled_water", 2)
	state.call("set_room_visited", "chemistry_room")
	state.call("set_room_visited", "circuit_room")
	for x: int in range(6, 43):
		state.hall_explored_cells["%d,20" % x] = true
	state.potion_applied.connect(func(_id: String, _duration: float) -> void: potion_applications += 1)
	bag = root.get_node("InventoryHud")
	keys = root.get_node("KeyHud")
	notes = root.get_node("NoteHud")
	notes.call("unlock")
	notes.call("add_clue", "instrument_known", {
		"title": "Powder comparison / 粉末比较", "title_en": "Powder comparison", "title_zh": "粉末比较",
		"content": "Legacy bilingual fallback.",
		"content_en": "The sample was compared with the filed reference.",
		"content_zh": "样本已与归档的参考材料进行了比较。",
		"observed_detail": "The indicator stayed blue.",
		"observed_detail_zh": "指示剂保持蓝色。",
		"room_id": "chemistry_room", "silent": true,
	})
	notes.call("add_clue", "circuit_instrument_other", {
		"title": "Switch observation", "title_zh": "开关观察",
		"content": "A switch was inspected.", "content_zh": "检查了一只开关。",
		"silent": true,
	})
	journal = notes.call("get_journal")
	var unchanged_record: Dictionary = (notes.call("get_saved_clues") as Dictionary)["circuit_instrument_other"]
	_expect(not unchanged_record.has("room_id"), "Existing NoteHud records gain no automatic schema fields")
	_expect(unchanged_record["content"] == "A switch was inspected.", "Authored record meanings remain unchanged")
	journal.clues["instrument_hidden"] = {
		"title": "UNREVEALED SENTINEL", "content": "UNREVEALED SENTINEL",
		"unlocked": false, "room_id": "chemistry_room",
	}
	map = root.get_node("MapHud")
	root.get_node("ItemRewardHud").call("dismiss_for_overlay")
	bag.call("dismiss_feature_unlock")
	keys.call("dismiss_unlock_toast")
	await _wait(0.1)
	await _check_bag()
	await _check_keys()
	await _check_journal()
	await _check_map()
	await _check_interruption_and_pause()
	await _check_text_input_and_motion_rest()
	state.game_started = false
	paused = false
	root.get_node("GameAudio").queue_free()
	await _wait(0.15)
	if failures.is_empty():
		print("instrument_hubs_test: PASS")
		quit(0)
	else:
		printerr("instrument_hubs_test: FAIL (%d)" % failures.size())
		quit(1)


func _check_bag() -> void:
	await _click(bag.get("icon_button"))
	_expect(bag.get("_open"), "Actual Bag entry click opens field kit")
	await _wait(0.06)
	await _capture("01-bag-unfold-mid")
	await _wait(0.30)
	var categories: Dictionary = bag.get("category_buttons")
	await _click(categories["potions"])
	await _wait(0.30)
	var slots: Array = bag.get("slot_nodes")
	await _click(slots[1].get_node("SlotButton"))
	var art := bag.get("detail_icon_texture") as TextureRect
	_expect(art.position.distance_to(Vector2(626, 162)) > 20.0, "Selected raster travels from its physical slot")
	_expect((bag.get("detail_title") as Label).text == "Vision Potion", "Inspection copy updates immediately")
	await _wait(0.09)
	await _capture("02-bag-inspect-mid")
	await _wait(0.28)
	_expect(art.position.is_equal_approx(Vector2(626, 162)) and art.scale.is_equal_approx(Vector2.ONE), "Inspection reaches the plate at canonical size")
	await _capture("03-bag-inspect-settled")
	var sound_count := int(root.get_node("GameAudio").get("_next_voice"))
	await _click(bag.get("detail_use_button"))
	_expect(not state.call("has_inventory_item", "vision_potion"), "Use consumes the potion immediately exactly once")
	_expect(potion_applications == 1, "Use emits one existing potion effect")
	await _click(bag.get("detail_use_button"))
	_expect(potion_applications == 1, "Repeated use input cannot consume or apply twice after close")
	_expect(not paused and not bag.get("_open"), "Use does not delay resume or close")
	_expect((int(root.get_node("GameAudio").get("_next_voice")) - sound_count + 12) % 12 == 1, "Use reuses exactly one existing potion audio")
	_expect(is_instance_valid(bag.get("use_feedback")), "Uncork is detached presentation after gameplay resumes")
	var used := bag.get("use_feedback") as Control
	_expect((used.get_child(0) as Control).size.is_equal_approx(Vector2(140, 140)), "Use plate respects its 140px frame rather than the native texture minimum")
	await _wait(0.06)
	await _capture("04-bag-uncork-mid")
	await _wait(0.35)
	_expect(not is_instance_valid(bag.get("use_feedback")), "Used specimen cleans up")
	await _key(KEY_TAB)
	await _wait(0.30)
	await _click(categories["materials"])
	await _key(KEY_ESCAPE)
	_expect(not bag.get("_open") and not paused, "Cancel during filing switch restores pause")
	_expect((bag.get("detail_icon_texture") as Control).rotation == 0.0, "Cancel settles the moving raster")


func _check_keys() -> void:
	await _click(keys.get("icon_button"))
	await _wait(0.30)
	var board := keys.get("board_panel") as Control
	await _click(board.get_node("KeySlot_01"))
	await _wait(0.12)
	var specimen := keys.get("key_specimen") as TextureRect
	var pins: Array = keys.get("lock_pins")
	_expect(specimen.rotation > 0.02, "Recovered key physically turns in the test socket")
	_expect((pins[0] as Control).position.y < 98.0, "Lock followers respond to the teeth")
	_expect(float((specimen.material as ShaderMaterial).get_shader_parameter("contact")) > 0.0, "Raster teeth receive contact accent")
	await _capture("05-key-turn-mid")
	await _wait(0.30)
	_expect(specimen.rotation == 0.0 and specimen.position.is_equal_approx(Vector2(32, 12)), "Key turn settles")
	await _capture("06-key-turn-settled")
	await _click(board.get_node("KeySlot_07"))
	_expect(specimen.texture.resource_path.ends_with("knowledge_lock.png"), "Unrecovered slot never loads its key illustration")
	_expect(not (keys.get("detail_label") as Label).text.contains("Library"), "Unrecovered key does not expose its description")
	await _key(KEY_ESCAPE)
	_expect(not paused, "Key cancel unpauses")


func _check_journal() -> void:
	notes.call("open")
	await _wait(0.07)
	_expect(journal.get("visible"), "Journal opens through NoteHud")
	await _capture("07-note-filing-mid")
	await _wait(0.30)
	var buttons: Dictionary = journal.get("_buttons")
	_expect(not buttons.has("instrument_hidden"), "Unrevealed records are absent from the index")
	var first := buttons["instrument_known"] as TextureButton
	first.grab_focus()
	await _key(KEY_ENTER)
	var text := journal.get("detail_text") as RichTextLabel
	_expect((journal.get("document_title") as Label).text == "Powder comparison" and text.text.contains("The sample was compared") and not text.text.contains("Legacy bilingual"), "Optional English fields select readable English without bilingual duplication")
	_expect((notes.call("get_saved_clues") as Dictionary)["instrument_known"]["content"] == "Legacy bilingual fallback.", "Locale rendering does not rewrite the stored fallback")
	_expect(text.text.contains("The indicator stayed blue.") and text.visible_characters == -1, "Observed detail and complete evidence are immediately readable")
	_expect(not text.text.contains("UNREVEALED"), "Evidence page contains no hidden record")
	await _wait(0.05)
	await _capture("08-note-slide-mid")
	await _wait(0.30)
	_expect(not (journal.get("_page_underlay") as Control).visible, "Page underlay settles cleanly")
	await _capture("09-note-slide-settled")
	root.get_node("CaseLocale").call("set_language", "zh")
	await _click(first)
	await _wait(0.30)
	_expect(text.text.contains("指示剂保持蓝色") and text.text.contains("样本已"), "Structured Chinese fields retain author-provided meaning")
	await _capture("10-note-zh-settled")
	root.get_node("CaseLocale").call("set_language", "en")
	await _key(KEY_ESCAPE)
	_expect(not paused and not journal.get("visible"), "Journal Escape restores prior pause")


func _check_map() -> void:
	state.call("set_story_flag", "circuit_power_restored", false)
	state.chase_mode = false
	map.call("_sync_map_state")
	await _click(map.get("map_entry_button"))
	await _wait(0.08)
	var fog := map.get("fog_image") as Image
	_expect(fog.get_pixel(200, 200).a == 1.0 and fog.get_pixel(1200, 500).a == 1.0, "Blackout fog remains fully opaque mid-open")
	_expect(not (map.get("location_picker") as Control).visible and (map.get("location_clues") as RichTextLabel).text.is_empty(), "Blackout exposes no known-location or evidence UI")
	for button: Control in map.get("room_buttons"):
		_expect(not button.visible, "Blackout hides location hitbox %s" % button.name)
	for point: Control in map.get("room_points"):
		_expect(not point.visible, "Blackout hides key point %s" % point.name)
	await _capture("11-map-blackout-mid")
	await _wait(0.30)
	await _capture("12-map-blackout-settled")
	await _key(KEY_ESCAPE)
	state.call("set_story_flag", "circuit_power_restored", true)
	await _click(map.get("map_entry_button"))
	await _wait(0.06)
	var ink := (map.get("fog_texture_rect") as TextureRect).material as ShaderMaterial
	var scan := float(ink.get_shader_parameter("scan"))
	_expect(scan > 0.0 and scan < 1.0, "Known map memory writes across the paper")
	_expect((map.get("guardian_minimap_fog_rect") as TextureRect).texture == map.get("fog_texture"), "Minimap still shares the exact CPU mask")
	_expect((map.get("map_panel") as Control).scale.is_equal_approx(Vector2.ONE), "Map frame never separates from fog or marker coordinates")
	await _capture("13-map-ink-mid")
	await _wait(0.33)
	var room_buttons: Array = map.get("room_buttons")
	await _click(room_buttons[1])
	_expect(map.get("selected_room_id") == "chemistry_room", "Known room point is actually selectable")
	var associated := map.get("location_clues") as RichTextLabel
	_expect(associated.text.contains("Powder comparison") and not associated.text.contains("Switch observation") and not associated.text.contains("UNREVEALED"), "Map shows only that location's already-filed clues")
	await _wait(0.22)
	await _capture("14-map-known-clues-settled")
	var picker := map.get("location_picker") as OptionButton
	_expect(picker.item_count == 3, "Location selector contains only entered rooms")
	picker.grab_focus()
	await _key(KEY_ENTER)
	_expect(picker.get_popup().visible, "Location picker opens from keyboard")
	await _key_to(picker.get_popup(), KEY_DOWN)
	await _key_to(picker.get_popup(), KEY_ENTER)
	_expect(map.get("selected_room_id") == "circuit_room", "Keyboard popup selects another known location")
	root.get_node("CaseLocale").call("set_language", "zh")
	map.call("_refresh_map_ledger")
	await _wait(0.2)
	await _capture("15-map-zh-settled")
	root.get_node("CaseLocale").call("set_language", "en")
	await _key(KEY_ESCAPE)
	_expect(not paused, "Map Escape unpauses after selection")
	await _key(KEY_U)
	await _click((map.get("overlay") as Control).get_node("MapCloseButton"))
	_expect(not (map.get("overlay") as Control).visible and not paused, "Map close remains clickable beside active potion chips")


func _check_interruption_and_pause() -> void:
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_expect(not bag.get("_open") and not paused, "Focused Bag still closes with its Tab shortcut")
	await _key(KEY_I)
	await _key(KEY_I)
	_expect(not (keys.get("overlay") as Control).visible and not paused, "Key shortcut toggles its open Hub")
	await _key(KEY_U)
	await _key(KEY_U)
	_expect(not (map.get("overlay") as Control).visible and not paused, "Map shortcut toggles its open Hub")
	await _key(KEY_TAB)
	await _key(KEY_I)
	_expect(not bag.get("_open") and (keys.get("overlay") as Control).visible, "Actual hotkey switches Bag to Keys during opening")
	await _key(KEY_K)
	_expect(journal.get("visible") and not (keys.get("overlay") as Control).visible, "Actual hotkey switches Keys to Notes")
	await _key(KEY_U)
	_expect(not journal.get("visible") and (map.get("overlay") as Control).visible, "Actual hotkey switches Notes to Map")
	await _key(KEY_ESCAPE)
	for repeat: int in range(3):
		bag.call("open_bag")
		bag.call("open_bag")
		keys.call("open_hub")
		_expect(not bag.get("_open") and (keys.get("overlay") as Control).visible, "Switch transfers overlay ownership")
		notes.call("open")
		map.call("open_map")
		map.call("open_map")
		await _key(KEY_ESCAPE)
		_expect(not paused, "Repeated open/switch/cancel does not capture its own pause")
		await _wait(0.35)
		_expect(not (map.get("overlay") as Control).visible, "No completed tween reopens a closed Hub")
		_expect(_motion_count(bag.get("overlay")) + _motion_count(keys.get("overlay")) + _motion_count(journal.get("main_panel")) + _motion_count(map.get("overlay")) == 0, "All owned interaction tweens settle after cancellation")
	paused = true
	notes.call("open")
	await _key(KEY_ESCAPE)
	_expect(paused, "Journal preserves a pre-existing pause")
	paused = false


func _check_text_input_and_motion_rest() -> void:
	bag.call("open_bag")
	await _wait(0.35)
	var field := LineEdit.new()
	field.size = Vector2(200, 32)
	(bag.get("overlay") as Control).add_child(field)
	field.grab_focus()
	await process_frame
	_expect(root.gui_get_focus_owner() == field, "Text field holds focus before a typing test")
	await _key(KEY_I)
	_expect(field.text == "I" and bool(bag.get("_open")) and not (keys.get("overlay") as Control).visible,
		"Typing a Hub shortcut into a focused text field does not switch tools")
	field.queue_free()
	await process_frame
	bag.call("close_bag")
	var visual := Control.new()
	visual.position = Vector2(30, 40)
	visual.pivot_offset = Vector2(8, 9)
	root.add_child(visual)
	var archive := root.get_node("ArchiveUi")
	var tween: Tween = archive.call("begin_motion", visual)
	tween.tween_property(visual, "rotation", 0.2, 0.2)
	visual.position += Vector2(20, 20)
	visual.pivot_offset = Vector2(100, 60)
	visual.scale = Vector2(0.8, 0.9)
	archive.call("settle_motion", visual)
	_expect(visual.position == Vector2(30, 40) and visual.pivot_offset == Vector2(8, 9)
		and visual.scale == Vector2.ONE and visual.rotation == 0.0,
		"Interrupted tool motion restores pivot as well as scale and position")
	visual.queue_free()
	await process_frame


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	if "--debug-events" in OS.get_cmdline_user_args():
		print("CLICK: ", control.get_path(), " visible=", control.is_visible_in_tree(), " rect=", control.get_global_rect(), " hovered=", root.gui_get_hovered_control())
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	await _key_to(root, code)


func _key_to(viewport: Viewport, code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		if code >= KEY_SPACE and code <= KEY_ASCIITILDE:
			event.unicode = code
		if viewport != root and viewport is Window:
			event.window_id = (viewport as Window).get_window_id()
			Input.parse_input_event(event)
		else:
			viewport.push_input(event, true)
		await process_frame
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _capture(stem: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if stem.begins_with("11-") or stem.begins_with("12-"):
		_expect(image.get_pixel(400, 400).r < 0.005 and image.get_pixel(400, 400).g < 0.005, "Rendered blackout stays black, not just CPU fog data")
	_expect(image.get_size() == Vector2i(1024, 768), "Native capture " + stem)
	var error := image.save_png(capture_directory.path_join(stem + ".png"))
	_expect(error == OK, "Saved capture " + stem)


func _motion_count(node: Node) -> int:
	var count := 1 if node.has_meta("archive_motion_tween") else 0
	for child: Node in node.get_children():
		count += _motion_count(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
