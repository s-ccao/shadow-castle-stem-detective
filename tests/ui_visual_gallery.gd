extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_ROOT := "res://docs/evidence/2026-08-14-ui-redesign"
const GLOBAL_HUD_NAMES: Array[String] = [
	"InventoryHud",
	"KeyHud",
	"NoteHud",
	"MapHud",
	"ItemRewardHud",
	"ParchmentHud",
	"OnboardingHud",
]

var failures: Array[String] = []
var output_variant := "before"
var gallery_scene: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_variant = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").set("_loading_save", true)
	if output_variant.is_empty() or output_variant.contains("/") or output_variant.contains(".."):
		_fail("Unsafe output variant: " + output_variant)
		_finish()
		return
	var output_directory := ProjectSettings.globalize_path(
		EVIDENCE_ROOT + "/" + output_variant
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create gallery directory: " + output_directory)
		_finish()
		return

	_seed_gallery_state()
	await _capture_start(output_directory)
	await _capture_hub("01-bag-hub", "InventoryHud", "open_bag", "close_bag", output_directory)
	await _capture_hub("02-key-hub", "KeyHud", "open_hub", "close_hub", output_directory)
	await _capture_note_hub(output_directory)
	await _capture_map_hub(output_directory)
	await _capture_alchemy(output_directory)
	await _capture_final_board(false, output_directory)
	await _capture_final_board(true, output_directory)
	await _capture_death(output_directory)
	await _capture_ending(false, output_directory)
	await _capture_ending(true, output_directory)
	await _capture_case_archive(output_directory)
	_cleanup_scene()
	paused = false
	_finish()


func _seed_gallery_state() -> void:
	var game_state := root.get_node_or_null("GameState")
	var note_hud := root.get_node_or_null("NoteHud")
	if game_state == null or note_hud == null:
		_fail("Required autoloads are unavailable")
		return
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
	for potion_id: String in game_state.POTION_INFO.keys():
		game_state.add_inventory_item(potion_id)
	for evidence_id: String in game_state.DEV_EVIDENCE_IDS:
		game_state.add_evidence(evidence_id)
	for flag_id: String in [
		"chemistry_butler_interviewed",
		"final_case_formed_staged_scene",
		"final_case_formed_maintenance_route",
		"final_case_placed_method",
		"normal_ending",
		"sealed_archive_pinned_sealed_archive_pressure",
		"sealed_archive_pinned_sealed_archive_instruction",
		"sealed_archive_pinned_sealed_archive_lin_decision",
	]:
		game_state.set_story_flag(flag_id)
	note_hud.call("unlock")
	var gallery_clues: Array[Dictionary] = [
		{
			"id": "gallery_stain",
			"title": "Staged Red Stain",
			"content": "The stain reacts like a service compound, not blood. It points toward a prepared diversion.",
			"category": "evidence",
		},
		{
			"id": "gallery_route",
			"title": "Maintenance Route",
			"content": "Pollen and violet fiber cross the same hidden service path through the castle.",
			"category": "investigation",
		},
		{
			"id": "gallery_lock",
			"title": "Ashford Knowledge Locks",
			"content": "Every door requires a physical key and an observed scientific answer.",
			"category": "knowledge",
		},
	]
	for clue: Dictionary in gallery_clues:
		note_hud.call("add_clue", str(clue["id"]), {
			"title": clue["title"],
			"content": clue["content"],
			"category": clue["category"],
			"icon": "icon_note",
			"silent": true,
		})
	game_state.current_room_id = "floor_1_hub"
	var gallery_patrol: Array[Vector2] = [
		Vector2(1600.0, 1060.0),
		Vector2(1660.0, 840.0),
		Vector2(950.0, 220.0),
		Vector2(260.0, 230.0),
		Vector2(210.0, 820.0),
		Vector2(1600.0, 1060.0),
	]
	game_state.configure_guardian_patrol_route(gallery_patrol)
	game_state.activate_guardian_hunt()
	game_state.game_started = true


func _capture_start(output_directory: String) -> void:
	await _prepare_screen()
	var scene := load("res://scenes/ui/start_ui.tscn") as PackedScene
	if scene == null:
		_fail("Start UI scene could not load")
		return
	var screen := scene.instantiate()
	_set_gallery_scene(screen)
	await process_frame
	screen.call("set_continue_enabled", true)
	screen.call("set_save_status", "AUTOSAVE  ·  CASTLE HALL  ·  GUARDIAN ACTIVE")
	await _settle_and_capture(output_directory.path_join("00-start-case.png"))


func _capture_hub(
	capture_name: String,
	autoload_name: String,
	open_method: String,
	close_method: String,
	output_directory: String
) -> void:
	await _prepare_hub_backdrop()
	var hud := root.get_node_or_null(autoload_name) as CanvasLayer
	if hud == null:
		_fail(autoload_name + " autoload is unavailable")
		return
	hud.visible = true
	hud.call(open_method)
	await _settle_and_capture(output_directory.path_join(capture_name + ".png"))
	hud.call(close_method)
	hud.visible = false
	paused = false


func _capture_note_hub(output_directory: String) -> void:
	await _prepare_hub_backdrop()
	var note_hud := root.get_node_or_null("NoteHud") as CanvasLayer
	note_hud.visible = true
	note_hud.call("open")
	await _settle_and_capture(output_directory.path_join("03-note-hub.png"))
	var journal := note_hud.call("get_journal") as CanvasLayer
	if journal != null:
		journal.call("close")
	note_hud.visible = false
	paused = false


func _capture_map_hub(output_directory: String) -> void:
	await _prepare_hub_backdrop()
	var map_hud := root.get_node_or_null("MapHud") as CanvasLayer
	map_hud.visible = true
	map_hud.call("open_map")
	await _settle_and_capture(output_directory.path_join("04-map-hub.png"))
	map_hud.call("close_map")
	map_hud.visible = false
	paused = false


func _capture_alchemy(output_directory: String) -> void:
	await _prepare_screen()
	var scene := load("res://scenes/ui/alchemy_workbench_ui.tscn") as PackedScene
	if scene == null:
		_fail("Alchemy UI scene could not load")
		return
	var screen := scene.instantiate()
	_set_gallery_scene(screen)
	await process_frame
	screen.call("open", null)
	screen.call("_choose_recipe", "recipe_swift")
	await process_frame
	for placement: Dictionary in [
		{"item": "blue_blossom", "slot": 0},
		{"item": "distilled_water", "slot": 1},
		{"item": "iron_salt", "slot": 2},
	]:
		screen.call("_select_reagent", placement["item"])
		screen.call("_press_reaction_node", placement["slot"])
	await _settle_and_capture(output_directory.path_join("05-alchemy-ready.png"))
	screen.call("_extract_potion")
	await process_frame
	await _settle_and_capture(output_directory.path_join("05a-alchemy-extraction-feeds.png"))
	await create_timer(0.78).timeout
	await _settle_and_capture(output_directory.path_join("05b-alchemy-product-impact.png"))


func _capture_final_board(true_case: bool, output_directory: String) -> void:
	await _prepare_screen()
	var game_state := root.get_node_or_null("GameState")
	if true_case:
		game_state.set_story_flag("normal_ending")
	else:
		game_state.set_story_flag("normal_ending", false)
	var scene := load("res://scenes/ui/final_case_board.tscn") as PackedScene
	if scene == null:
		_fail("Final Case Board scene could not load")
		return
	var screen := scene.instantiate()
	_set_gallery_scene(screen)
	await process_frame
	if true_case:
		screen.call("show_sealed_archive_prompt")
	else:
		screen.call("open_case")
	await _settle_and_capture(output_directory.path_join(
		"07-final-board-sealed.png" if true_case else "06-final-board-ordinary.png"
	))


func _capture_death(output_directory: String) -> void:
	await _prepare_screen()
	var scene := load("res://scenes/ui/death_ui.tscn") as PackedScene
	if scene == null:
		_fail("Death UI scene could not load")
		return
	var screen := scene.instantiate()
	_set_gallery_scene(screen)
	await process_frame
	screen.call("configure_recovery", true, "chemistry_room")
	await _settle_and_capture(output_directory.path_join("08-guardian-caught.png"))


func _capture_ending(true_case: bool, output_directory: String) -> void:
	await _prepare_screen()
	var scene := load("res://scenes/ui/game_over_ui.tscn") as PackedScene
	if scene == null:
		_fail("Game Over UI scene could not load")
		return
	var screen := scene.instantiate()
	_set_gallery_scene(screen)
	await process_frame
	screen.call("show_true_case" if true_case else "show_ordinary_case")
	await _settle_and_capture(output_directory.path_join(
		"10-ending-true.png" if true_case else "09-ending-ordinary.png"
	))


func _capture_case_archive(output_directory: String) -> void:
	await _prepare_screen()
	var game_state := root.get_node("GameState")
	game_state.call("set_story_flag", "normal_ending")
	game_state.call("set_story_flag", "perfect_ending")
	var archive: Node = load("res://scripts/case_archive_ui.gd").new()
	_set_gallery_scene(archive)
	await process_frame
	archive.call("open_archive")
	await process_frame
	await _settle_and_capture(output_directory.path_join("11-case-archive-evidence.png"))
	archive.call("_select_section", "verdict")
	await process_frame
	await _settle_and_capture(output_directory.path_join("12-case-archive-verdict.png"))


func _prepare_hub_backdrop() -> void:
	await _prepare_screen()
	var backdrop := Control.new()
	backdrop.name = "GalleryHubBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = load("res://assets/backgrounds/hall_floor_bg.png") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.add_child(art)
	var player := Node2D.new()
	player.name = "player"
	player.position = Vector2(620.0, 540.0)
	backdrop.add_child(player)
	_set_gallery_scene(backdrop)
	await process_frame


func _prepare_screen() -> void:
	paused = false
	for hud_name: String in GLOBAL_HUD_NAMES:
		var hud := root.get_node_or_null(hud_name) as CanvasLayer
		if hud != null:
			hud.visible = false
	_cleanup_scene()
	await process_frame
	await process_frame


func _set_gallery_scene(scene: Node) -> void:
	_cleanup_scene()
	gallery_scene = scene
	root.add_child(gallery_scene)
	current_scene = gallery_scene


func _cleanup_scene() -> void:
	if gallery_scene != null and is_instance_valid(gallery_scene):
		if current_scene == gallery_scene:
			current_scene = null
		gallery_scene.queue_free()
	gallery_scene = null


func _settle_and_capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.20, true).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		_fail("Empty capture: " + absolute_path)
		return
	if image.get_size() != VIEWPORT_SIZE:
		_fail("Unexpected capture size for %s: %s" % [absolute_path, image.get_size()])
		return
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("ui_visual_gallery: PASS (" + output_variant + ")")
		quit(0)
		return
	printerr("ui_visual_gallery: FAIL (%d issue(s))" % failures.size())
	quit(1)
