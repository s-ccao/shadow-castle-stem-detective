extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-hub-room-polish"

var failures: Array[String] = []
var game_state: Node
var active_scene: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create Hub/room polish evidence directory")
		_finish()
		return
	_prepare_state()
	await _load_scene("res://scenes/floor_1/chemistry_room.tscn")
	await _capture_note_hub(output_directory)
	await _capture_bag_hub(output_directory)
	await _capture_shared_effects(output_directory)
	await _capture_red_stain(output_directory)
	await _capture_final_board(output_directory)
	await _load_scene("res://scenes/floor_1/library_room.tscn")
	await _capture_library_rgb(output_directory)
	await _load_scene("res://scenes/floor_1/circuit_room.tscn")
	await _capture_circuit_switches(output_directory)
	_finish()


func _prepare_state() -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.call("grant_wake_room_toolkit")
	for recipe_id: String in ["recipe_swift", "recipe_vision"]:
		game_state.call("add_recipe", recipe_id)
	for herb_id: String in ["blue_blossom", "moonleaf"]:
		game_state.call("add_herb", herb_id, 8)
	for material_id: String in ["distilled_water", "iron_salt", "prism_dust"]:
		game_state.call("add_material", material_id, 8)
	for potion_id: String in ["swift_potion", "vision_potion"]:
		game_state.call("add_inventory_item", potion_id)
	game_state.call("add_map", "circuit_repair_map")
	game_state.current_room_id = "chemistry_room"


func _capture_note_hub(output_directory: String) -> void:
	var packed := load("res://scenes/clue_journal.tscn") as PackedScene
	var journal := packed.instantiate()
	root.add_child(journal)
	await process_frame
	for index: int in range(9):
		journal.call("add_clue", "polish_record_%d" % index, {
			"title": "Archive Record %02d" % (index + 1),
			"icon": "icon_note",
			"category": "investigation",
			"content": "[center][b]Archive Record %02d[/b][/center]\n\nThe powder was compared with the indicator, the broken bottle and the residue around the staged stain. The archive records each material separately so no conclusion is hidden inside the interface.\n\nThis second paragraph verifies centered long-form reading and the functional brass scrollbar." % (index + 1),
		})
	journal.call("open")
	await create_timer(0.24).timeout
	await _capture(output_directory.path_join("01-note-hub-centered-home.png"))
	journal.call("_select_clue", "polish_record_4")
	var list_scroll := journal.get("list_scroll") as ScrollContainer
	list_scroll.scroll_vertical = 180
	var detail := journal.get("detail_text") as RichTextLabel
	detail.scroll_to_line(2)
	await process_frame
	await _capture(output_directory.path_join("02-note-hub-functional-scrollbars.png"))
	journal.call("close")
	journal.queue_free()
	await process_frame
	paused = false


func _capture_bag_hub(output_directory: String) -> void:
	var inventory := root.get_node("InventoryHud")
	inventory.call("dismiss_feature_unlock")
	inventory.call("open_bag")
	inventory.call("_on_category_pressed", "papers")
	await process_frame
	await _capture(output_directory.path_join("03-bag-paper-layout.png"))
	inventory.call("_on_category_pressed", "materials")
	await process_frame
	await _capture(output_directory.path_join("04-bag-consolidated-materials.png"))
	inventory.call("close_bag")
	paused = false
	await process_frame


func _capture_shared_effects(output_directory: String) -> void:
	var reward_hud := root.get_node("ItemRewardHud")
	reward_hud.call("dismiss_for_overlay")
	reward_hud.call(
		"show_clue",
		"visual_reward",
		"Recovered Field Record",
		"A physical record settles into the active case archive."
	)
	await create_timer(0.26).timeout
	await _capture(output_directory.path_join("04a-item-reward-impact.png"))
	reward_hud.call("dismiss_for_overlay")
	await process_frame

	var parchment_hud := root.get_node("ParchmentHud")
	parchment_hud.call(
		"show_parchment",
		"Ashford Field Note",
		"The ink appears only after the scroll has fully unfurled. The archive records the motion before filing the page.",
		""
	)
	await create_timer(0.08).timeout
	await _capture(output_directory.path_join("04b-parchment-unfurling.png"))
	await create_timer(0.28).timeout
	await _capture(output_directory.path_join("04c-parchment-settled.png"))
	parchment_hud.call("_on_confirm_pressed")
	paused = false
	await process_frame


func _capture_red_stain(output_directory: String) -> void:
	active_scene.call("_on_red_stain_examined")
	await process_frame
	var strip := active_scene.get("red_stain_material_strip") as Control
	_expect(strip != null and strip.visible, "Red-stain trace models are visible in the dialogue")
	var feature := root.get_node("InventoryHud").get("feature_panel") as Panel
	_expect(feature == null or not feature.visible, "No Bag material notification overlaps the red-stain dialogue")
	await _capture(output_directory.path_join("05-red-stain-trace-samples.png"))
	active_scene.call("close_message_panel")
	await process_frame


func _capture_final_board(output_directory: String) -> void:
	game_state.add_evidence("fake_red_stain")
	game_state.set_story_flag("chemistry_butler_interviewed")
	var packed := load("res://scenes/ui/final_case_board.tscn") as PackedScene
	var board := packed.instantiate()
	root.add_child(board)
	board.call("open_case")
	await process_frame
	var lever := board.get("lever_button") as Button
	_expect(not _contains_suspect_name(lever.text), "Final lever capture is spoiler-free")
	await _capture(output_directory.path_join("06-final-spoiler-free-lever.png"))
	board.call("_toggle_source", "fake_red_stain")
	board.call("_toggle_source", "butler_service_account")
	board.call("_form_conclusion")
	board.call("_select_conclusion", "staged_scene")
	board.call("_place_selected_conclusion", "method")
	await process_frame
	await _capture(output_directory.path_join("06a-final-conclusion-linking.png"))
	await create_timer(0.44).timeout
	await _capture(output_directory.path_join("06b-final-conclusion-seated.png"))
	board.call("close_case")
	board.queue_free()
	await process_frame


func _capture_library_rgb(output_directory: String) -> void:
	_hide_global_entries(true)
	var player := active_scene.get_node("Worldsort/player") as CharacterBody2D
	player.global_position = Vector2(724.0, 770.0)
	player.set_physics_process(false)
	_focus_room_camera(player, Vector2(1.55, 1.55))
	_hide_room_ui(active_scene)
	await process_frame
	await _capture(output_directory.path_join("07-library-jewel-filters-rest.png"))
	for filter_id: String in ["rgb_red_filter", "rgb_green_filter", "rgb_blue_filter"]:
		active_scene.call("_set_rgb_filter_active", filter_id, true, false)
	active_scene.call("_set_rgb_neutral_light", true, false)
	await process_frame
	await _capture(output_directory.path_join("08-library-jewel-filters-combined.png"))
	_hide_global_entries(false)


func _capture_circuit_switches(output_directory: String) -> void:
	_hide_global_entries(true)
	var player := active_scene.get_node("Worldsort/player") as CharacterBody2D
	player.global_position = Vector2(724.0, 560.0)
	player.set_physics_process(false)
	_focus_room_camera(player, Vector2(0.75, 0.75))
	_hide_room_ui(active_scene)
	await process_frame
	# The room's default state is the interesting one: the junction plates are
	# flush with their housings and there is nothing to press anywhere.
	await _capture(output_directory.path_join("08a-circuit-plates-concealed.png"))
	active_scene.call("_survey_switches", "blueprint")
	await create_timer(0.75).timeout
	await _capture(output_directory.path_join("09-circuit-styled-switches.png"))
	player.visible = false
	player.global_position = CircuitLayout.get_position("switch_left") + Vector2(0.0, 86.0)
	_focus_room_camera(player, Vector2(1.65, 1.65))
	active_scene.call("_update_switch_visual", "switch_left", true, true)
	await process_frame
	await _capture(output_directory.path_join("09a-circuit-auxiliary-charging.png"))
	await create_timer(0.36).timeout
	await _capture(output_directory.path_join("09b-circuit-auxiliary-active.png"))
	active_scene.call("_update_switch_visual", "switch_left", false, false)
	var switch_captures: Array[Dictionary] = [
		{"id": "switch_left", "file": "10-circuit-auxiliary-close.png"},
		{"id": "switch_right", "file": "11-circuit-regulator-close.png"},
		{"id": "master_switch", "file": "12-circuit-master-close.png"},
	]
	for capture_spec: Dictionary in switch_captures:
		var switch_position := CircuitLayout.get_position(str(capture_spec["id"]))
		player.global_position = switch_position + Vector2(0.0, 86.0)
		_focus_room_camera(player, Vector2(1.65, 1.65))
		await process_frame
		await _capture(output_directory.path_join(str(capture_spec["file"])))
	player.visible = true
	var map_hud := root.get_node("MapHud")
	map_hud.call("show_repair_map")
	await process_frame
	await _capture(output_directory.path_join("13-circuit-repair-map-aligned.png"))
	map_hud.call("close_repair_map")
	_hide_global_entries(false)


func _load_scene(path: String) -> void:
	if active_scene != null and is_instance_valid(active_scene):
		if current_scene == active_scene:
			current_scene = null
		active_scene.queue_free()
		await process_frame
		await process_frame
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("Could not load scene: " + path)
		return
	active_scene = packed.instantiate()
	root.add_child(active_scene)
	current_scene = active_scene
	await process_frame
	await process_frame
	await create_timer(0.35).timeout


func _focus_room_camera(player: Node2D, zoom: Vector2) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.zoom = zoom
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


func _hide_room_ui(room: Node) -> void:
	for canvas: Node in room.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var focus := room.find_child("WorldInteractionFocus", true, false) as CanvasItem
	if focus != null:
		focus.visible = false


func _hide_global_entries(hidden: bool) -> void:
	root.get_node("ArchiveUi").call("set_hub_entries_suppressed", hidden)
	var minimap := root.get_node("MapHud").find_child("GuardianMiniMap", true, false) as Control
	if minimap != null:
		minimap.visible = false


func _contains_suspect_name(text: String) -> bool:
	var normalized := text.to_lower()
	return normalized.contains("butler") or normalized.contains("mechanic") or text.contains("管家") or text.contains("机械师")


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid 1024x768 capture: " + absolute_path)
		return
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	_hide_global_entries(false)
	if active_scene != null and is_instance_valid(active_scene):
		if current_scene == active_scene:
			current_scene = null
		active_scene.queue_free()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("hub_room_polish_visual_capture: PASS")
		quit(0)
		return
	printerr("hub_room_polish_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
