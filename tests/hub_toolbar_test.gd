extends SceneTree

const NATIVE_SIZE := Vector2i(1024, 768)
const EVIDENCE := "res://docs/evidence/2026-09-07-tool-belt"
var failures: Array[String] = []
var state: Node
var archive: Node
var bag: Node
var keys: Node
var notes: Node
var map: Node
var entries: Array[Button] = []
var capture := false
var evidence_directory := ""


func _initialize() -> void:
	root.size = NATIVE_SIZE
	capture = "--capture" in OS.get_cmdline_user_args()
	evidence_directory = EVIDENCE.path_join("before" if "--before" in OS.get_cmdline_user_args() else "after")
	if "--layout-evidence" in OS.get_cmdline_user_args():
		evidence_directory = "res://docs/evidence/2026-09-07-hub-layout".path_join(
			"before" if "--before" in OS.get_cmdline_user_args() else "after"
		)
	call_deferred("_run")


func _run() -> void:
	var home := OS.get_environment("HOME")
	if home != OS.get_environment("HUB_TOOLBAR_TEST_HOME") or not home.contains("/.godot/hub-toolbar-"):
		printerr("hub_toolbar_test requires its own isolated HOME and matching HUB_TOOLBAR_TEST_HOME.")
		quit(1)
		return
	state = root.get_node("GameState")
	archive = root.get_node("ArchiveUi")
	bag = root.get_node("InventoryHud")
	keys = root.get_node("KeyHud")
	notes = root.get_node("NoteHud")
	map = root.get_node("MapHud")
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.set("_loading_save", true)
	state.game_started = true
	state.current_room_id = "floor_1_hub"
	root.get_node("CaseLocale").call("set_language", "en")
	entries.assign([bag.get("icon_button"), keys.get("icon_button"), notes.get("entry_button"), map.get("map_entry_button")])
	state.game_started = false
	state.state_changed.emit()
	await _settle()
	_expect(not (notes.get("hub_rail") as Control).is_visible_in_tree(), "Unstarted new game has no opaque toolbar canvas")
	state.game_started = true
	state.state_changed.emit()
	await _settle()
	_expect(not entries[1].is_visible_in_tree() and not entries[2].is_visible_in_tree() and not entries[3].is_visible_in_tree(), "Locked tools stay absent")
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	_dismiss_rewards()
	await _settle()
	var map_before_notes := entries[3].global_position
	notes.call("unlock")
	_dismiss_rewards()
	await _settle()
	_expect(entries[3].global_position == map_before_notes, "Unlocking Note does not move the Map entry")
	_check_layout(4)
	for index: int in range(4):
		await _click(entries[index])
		_expect(_tool_open(index) and paused, "Entry click opens its existing paused tool %d" % index)
		await _settle()
		_expect(not (notes.get("hub_rail") as Control).visible, "Open hub retracts the whole tray")
		_expect(not _preview().is_visible_in_tree(), "Open hub withdraws its tool preview")
		await _key(KEY_ESCAPE)
		_expect(not _tool_open(index) and not paused, "Escape restores pause ownership %d" % index)
		await _settle()
	entries[0].grab_focus()
	await _key(KEY_RIGHT)
	_expect(entries[1].has_focus(), "Focus moves across separate CanvasLayers")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(entries[2].has_focus(), "Controller D-pad reaches Note")
	await _joy(JOY_BUTTON_A)
	_expect(_tool_open(2), "Controller accepts the Note entry")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(entries[2].has_focus(), "Closing returns focus to the originating tool")
	await _joy_button(JOY_BUTTON_A, true)
	entries[1].grab_focus()
	await _joy_button(JOY_BUTTON_A, false)
	_expect(not _tool_open(1) and not _tool_open(2), "Controller release cannot activate a different focus owner")
	_expect(entries[2].get_meta("toolbar_visual_state") != "pressed", "Moving focus cancels the originating controller press")
	entries[1].grab_focus()
	await _key(KEY_TAB)
	_expect(_tool_open(0), "Focused toolbar retains Tab as Bag shortcut")
	await _key(KEY_ESCAPE)
	await _settle()
	paused = true
	await _click(entries[1])
	await _key(KEY_ESCAPE)
	_expect(paused, "Closing does not steal an existing pause")
	paused = false
	archive.call("set_hub_entries_suppressed", true)
	await _settle()
	for entry: Button in entries:
		_expect(not entry.is_visible_in_tree(), "Cinematic suppresses " + entry.name)
	_expect(not _preview().is_visible_in_tree(), "Cinematic also suppresses the preview")
	await _key(KEY_TAB)
	await _key(KEY_I)
	await _key(KEY_U)
	_expect(not _tool_open(0) and not _tool_open(1) and not _tool_open(3), "Suppressed toolbar shortcuts cannot open tools")
	archive.call("set_hub_entries_suppressed", false)
	state.current_room_id = "wake_room"
	state.state_changed.emit()
	await _settle()
	_check_layout(3)
	state.current_room_id = "floor_1_hub"
	state.state_changed.emit()
	await _settle()
	for language: String in ["zh", "en"]:
		root.get_node("CaseLocale").call("set_language", language)
		await _settle()
		for entry: Button in entries:
			var label := entry.get("title_label") as Label
			_expect(label.get_minimum_size().x <= label.size.x, language + " title fits " + entry.name)
			var artwork := (entry.get_node("ToolArtwork") as TextureRect).texture
			_expect(artwork.get_size() == Vector2(72, 76) and artwork.resource_path.contains("/tool_belt/"), "Native raster tool silhouette used by " + entry.name)
			_expect(label.visible and entry.get_node_or_null("PaperNameplate") == null, "Persistent readable names need no individual nameplate cages")
			var keycap := entry.get_node("ToolShortcut") as Control
			_expect(not label.get_global_rect().intersects(keycap.get_global_rect()), "Name and shortcut do not overlap")
	await _check_previews()
	if capture:
		await _capture_in_rooms()
	state.game_started = false
	paused = false
	if current_scene != null:
		current_scene.queue_free()
	root.get_node("GameAudio").queue_free()
	await _settle()
	if failures.is_empty():
		print("hub_toolbar_test: PASS")
		quit(0)
	else:
		printerr("hub_toolbar_test: FAIL (%d)" % failures.size())
		quit(1)


func _capture_in_rooms() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_directory))
	state.hall_arrival_seen = true
	state.return_spawn_id = "hall_entrance"
	state.story_flags["hall_first_route_complete"] = true
	state.story_flags["hall_first_route_core_studied"] = true
	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await create_timer(4.2, true).timeout
	var player := hall.get_node("player") as Node
	player.set_physics_process(false)
	var guardian := hall.get_node_or_null("CastleGuardian")
	if guardian != null:
		guardian.set_physics_process(false)
	_dismiss_rewards()
	archive.call("set_hub_entries_suppressed", false)
	await _settle()
	_release_focus()
	await _move_mouse(Vector2(500, 550))
	await _capture("01-hall-field-kit-en")
	entries[2].grab_focus()
	await _settle()
	await _capture("02-hall-keyboard-focus")
	_release_focus()
	await _move_mouse(entries[0].get_global_rect().get_center())
	await _settle()
	_expect(root.gui_get_hovered_control() == entries[0], "Capture uses actual viewport-local Bag hover")
	await _capture("03-hall-bag-hover")
	await _mouse_button(entries[0], true)
	await _settle()
	_expect(entries[0].get_meta("toolbar_visual_state") == "pressed", "Pressed capture shows a distinct depressed state")
	await _capture("04-hall-bag-pressed")
	await _mouse_button(entries[0], false)
	await _settle()
	await _capture("05-bag-panel-preserved")
	await _key(KEY_ESCAPE)
	_release_focus()
	root.get_node("CaseLocale").call("set_language", "zh")
	await _move_mouse(Vector2(500, 550))
	await _settle()
	await _capture("06-hall-field-kit-zh")
	entries[2].grab_focus()
	await _settle()
	await _capture("09-note-preview-zh")
	_release_focus()
	root.get_node("CaseLocale").call("set_language", "en")
	await _move_mouse(entries[3].get_global_rect().get_center())
	await _settle()
	await _capture("10-unpowered-map-preview")
	state.call("set_story_flag", "circuit_power_restored", true)
	await _settle()
	await _capture("11-powered-map-preview")
	await _move_mouse(entries[1].get_global_rect().get_center())
	await _settle()
	await _capture("12-key-register-preview")
	entries[1].disabled = true
	archive.call("refresh_hub_toolbar")
	await _move_mouse(Vector2(500, 550))
	await _move_mouse(entries[1].get_global_rect().get_center())
	await _settle()
	await _capture("13-unavailable-tool-state")
	entries[1].disabled = false
	await _move_mouse(Vector2(500, 550))
	archive.call("refresh_hub_toolbar")
	archive.call("set_hub_entries_suppressed", true)
	await _settle()
	await _capture("07-cinematic-toolbar-suppressed")
	archive.call("set_hub_entries_suppressed", false)
	hall.queue_free()
	await _settle()
	root.get_node("CaseLocale").call("set_language", "en")
	state.current_room_id = "wake_room"
	var wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await create_timer(0.8, true).timeout
	_dismiss_rewards()
	state.state_changed.emit()
	await _settle()
	_check_layout(3)
	await _capture("08-wake-room-compact-kit")
	wake.queue_free()
	await _settle()
	state.set("_loading_save", true)
	state.call("reset_new_game")
	notes.call("reset")
	state.set("_loading_save", true)
	state.game_started = true
	state.current_room_id = "wake_room"
	var fresh_wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(fresh_wake)
	current_scene = fresh_wake
	await create_timer(0.8, true).timeout
	_dismiss_rewards()
	state.state_changed.emit()
	_release_focus()
	await _move_mouse(Vector2(500, 550))
	await _settle()
	_check_layout(1)
	_expect(not _preview().is_visible_in_tree(), "New-game canvas is not covered by a stale tool preview")
	await _capture("14-new-game-wake-room")


func _check_layout(count: int) -> void:
	var active: Array[Button] = []
	for entry: Button in entries:
		if entry.is_visible_in_tree():
			active.append(entry)
	_expect(active.size() == count, "Visible tool count %d" % count)
	for index: int in range(active.size()):
		var rect := active[index].get_global_rect()
		_expect(rect.size == Vector2(72, 106) and rect.end.x < 350, "Readable full-height tool target " + active[index].name)
		var semantic_index := entries.find(active[index])
		_expect(rect.position == Vector2(16 + semantic_index * 80, 14), "Each tool keeps its semantic slot")
		for style: String in ["normal", "hover", "pressed", "focus"]:
			_expect(active[index].get_theme_stylebox(style) is StyleBoxEmpty, "No square cell cage in " + style)
		_expect(not active[index].is_processing(), "Tool has no idle animation loop")
		for child: Node in active[index].get_children():
			if child is Control:
				var child_rect := (child as Control).get_global_rect()
				_expect(rect.encloses(child_rect), "Entry contains %s %s" % [child.name, child_rect])
		if index > 0:
			var skipped_slots := semantic_index - entries.find(active[index - 1]) - 1
			_expect(rect.position.x - active[index - 1].get_global_rect().end.x == 8 + skipped_slots * 80, "Consistent gutters preserve hidden slots")
	var rail := notes.get("hub_rail") as Control
	_expect(rail.get_global_rect().end.x < 350, "Instrument dock clears Guardian readouts at x364")
	_expect(rail.get_theme_stylebox("panel") is StyleBoxTexture, "Dock uses a true nine-slice raster surface")
	_expect(rail.get_node_or_null("FieldKitBinding") == null, "No stretched generic button artwork")
	_expect(rail.size.y == 32 and rail.position.y == 58, "The leather rail supports the aligned tool art")


func _preview() -> Control:
	return (notes.get("hub_rail") as Control).get_node("ToolPreview") as Control


func _check_previews() -> void:
	state.call("add_inventory_item", "swift_potion")
	state.call("add_material", "distilled_water", 2)
	state.call("add_key", "chemistry_room_key")
	state.call("set_room_visited", "chemistry_room", true)
	state.call("set_room_visited", "circuit_room", false)
	notes.call("add_clue", "toolbar_filed_record", {
		"title": "A filed observation", "content": "Previously observed evidence.", "silent": true,
	})
	var journal := notes.call("get_journal") as Node
	var records: Dictionary = journal.get("clues")
	records["toolbar_hidden_record"] = {"title": "HIDDEN SENTINEL", "content": "HIDDEN SENTINEL", "unlocked": false}
	_dismiss_rewards()
	_release_focus()
	var tool_ids := ["bag", "key", "note", "map"]
	for index: int in range(4):
		await _move_mouse(entries[index].get_global_rect().get_center())
		await _settle()
		_expect(root.gui_get_hovered_control() == entries[index], "Real pointer owns " + tool_ids[index])
		_expect(_preview().is_visible_in_tree() and _preview().get_meta("tool_id") == tool_ids[index], "Hover opens the matching useful preview")
		_expect(entries[index].get_meta("toolbar_visual_state") == "active", "Hover has an explicit active treatment")
		var hero := entries[index].get_node("ToolArtwork") as TextureRect
		_expect(hero.position == Vector2(0, 1), "Hover lifts the actual tool five pixels off its support")
		_expect((hero.get_node("SilhouetteEdge") as CanvasItem).modulate.a > 0.95, "Hover highlights the raster silhouette rather than a box")
		_expect(_preview().get_global_rect().end.x < 350, "Preview stays clear of Guardian readouts")
		_expect(_preview().global_position == Vector2(12, 132) and _preview().size.y == 112, "Preview uses one fixed compact region without shifting tools")
		var summary: Dictionary = archive.call("hub_tool_summary", tool_ids[index])
		_expect((_preview().get_node("PreviewCount") as Label).text == summary["count"], "Preview displays live authoritative count")
		for label: Node in _preview().get_children():
			if label is Label:
				_expect(_preview().get_global_rect().encloses((label as Control).get_global_rect()), "Preview copy remains inside its paper")
				_expect(not (label as Label).text.contains("HIDDEN"), "Preview exposes no unrevealed record")
	var expected_types := (bag.call("_build_entries", "all") as Array).size()
	_expect((archive.call("hub_tool_summary", "bag") as Dictionary)["count"] == "%d item types carried" % expected_types, "Bag counts actual carried item types, not unread badges")
	_expect((archive.call("hub_tool_summary", "key") as Dictionary)["count"] == "2 / 8 keys recovered", "Key count is recovered keys only")
	_expect((archive.call("hub_tool_summary", "note") as Dictionary)["count"] == "1 record filed", "Locked journal records are excluded")
	var places := 0
	for visited: Variant in state.visited_rooms.values():
		if bool(visited):
			places += 1
	_expect((archive.call("hub_tool_summary", "map") as Dictionary)["count"] == "%d %s visited" % [places, "place" if places == 1 else "places"], "Unvisited room flags are excluded")
	_expect((archive.call("hub_tool_summary", "map") as Dictionary)["detail"].contains("no architecture"), "Unpowered survey preview cannot reveal map geometry")
	state.call("set_room_visited", "circuit_room", true)
	await _settle()
	_expect((_preview().get_node("PreviewCount") as Label).text == "%d places visited" % (places + 1), "Hovered survey count responds to state changes")
	state.call("set_room_visited", "circuit_room", false)
	entries[0].grab_focus()
	await _settle()
	_expect(_preview().get_meta("tool_id") == "bag", "New keyboard focus takes preview ownership from a stationary pointer")
	await _move_mouse(entries[1].get_global_rect().get_center())
	await _settle()
	_expect(_preview().get_meta("tool_id") == "key", "New pointer hover takes preview ownership from keyboard focus")
	_release_focus()
	await _move_mouse(Vector2(500, 550))
	await _settle()
	_expect(not _preview().is_visible_in_tree(), "Pointer departure dismisses the preview")
	entries[2].grab_focus()
	await _settle()
	_expect(_preview().is_visible_in_tree() and _preview().get_meta("tool_id") == "note", "Keyboard focus receives the same preview")
	var saved_records: Dictionary = notes.call("get_saved_clues")
	notes.call("add_clue", "toolbar_live_record", {"title": "Live filing", "silent": true})
	await _settle()
	_expect((_preview().get_node("PreviewCount") as Label).text == "2 records filed", "Focused ledger count refreshes when a record is filed")
	notes.call("restore_saved_clues", saved_records)
	await _settle()
	_expect((_preview().get_node("PreviewCount") as Label).text == "1 record filed", "Restoring records refreshes the focused preview")
	_release_focus()
	entries[1].disabled = true
	archive.call("refresh_hub_toolbar")
	_expect(entries[1].get_meta("toolbar_visual_state") == "unavailable", "Availability refresh does not require pointer movement")
	await _move_mouse(entries[1].get_global_rect().get_center())
	await _settle()
	_expect(entries[1].get_meta("toolbar_visual_state") == "unavailable", "Unavailable tools have a coherent quiet state")
	await _click(entries[1])
	_expect(not _tool_open(1), "Unavailable entry cannot open its hub")
	entries[1].disabled = false
	archive.call("refresh_hub_toolbar")
	_expect(entries[1].get_meta("toolbar_visual_state") == "active", "Reenabled hovered tool immediately recovers its active treatment")
	await _move_mouse(Vector2(500, 550))
	await _settle()


func _tool_open(index: int) -> bool:
	match index:
		0: return bool(bag.get("_open"))
		1: return (keys.get("overlay") as Control).visible
		2:
			var journal := notes.get("_journal") as CanvasLayer
			return journal != null and journal.visible
		3: return (map.get("overlay") as Control).visible
	return false


func _dismiss_rewards() -> void:
	bag.call("dismiss_feature_unlock")
	keys.call("dismiss_unlock_toast")
	notes.call("hide_feature_unlock")
	root.get_node("ItemRewardHud").call("dismiss_for_overlay")


func _release_focus() -> void:
	var focused := root.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _click(control: Control) -> void:
	await _move_mouse(control.get_global_rect().get_center())
	await _mouse_button(control, true)
	await _mouse_button(control, false)
	await process_frame


func _mouse_button(control: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func _move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _joy(button: JoyButton) -> void:
	for down: bool in [true, false]:
		await _joy_button(button, down)


func _joy_button(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func _settle() -> void:
	await create_timer(0.16, true).timeout


func _capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_size() == NATIVE_SIZE, "Native capture " + stem)
	_expect(image.save_png(ProjectSettings.globalize_path(evidence_directory.path_join(stem + ".png"))) == OK, "Saved " + stem)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
