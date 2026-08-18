extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-item-models"

var failures: Array[String] = []
var room: Node


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create item-model evidence directory")
		_finish()
		return
	_seed_state(game_state)
	var packed := load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
	if packed == null:
		_fail("Chemistry Room scene could not load")
		_finish()
		return
	room = packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var player := room.get_node_or_null("Worldsort/player") as CharacterBody2D
	if player != null:
		player.set_physics_process(false)

	var inventory := root.get_node("InventoryHud")
	inventory.call("open_bag")
	inventory.call("_on_category_pressed", "papers")
	await process_frame
	_expect(_visible_artwork_count(inventory) >= 2, "Bag Papers renders both blueprint models")
	await _capture(output_directory.path_join("01-bag-recipe-blueprints.png"))

	inventory.call("_on_category_pressed", "materials")
	await process_frame
	_expect(_visible_artwork_count(inventory) >= 5, "Bag Materials renders herb and reagent models together")
	await _capture(output_directory.path_join("02-bag-reagent-models.png"))

	var material_entries := inventory.get("entries") as Array
	for entry_index: int in range(material_entries.size()):
		if str((material_entries[entry_index] as Dictionary).get("kind", "")) == "herb":
			inventory.call("_on_slot_pressed", entry_index)
			break
	await process_frame
	_expect(_visible_artwork_count(inventory) >= 5, "Bag Materials keeps Blue Blossom and Moonleaf inspectable")
	await _capture(output_directory.path_join("03-bag-herb-models.png"))
	inventory.call("close_bag")
	await process_frame

	room.call("show_craft_panel")
	await process_frame
	var alchemy := room.get("alchemy_workbench_ui") as CanvasLayer
	if alchemy == null:
		_fail("Alchemy workbench UI was not created")
		_finish()
		return
	alchemy.call("_choose_recipe", "recipe_swift")
	await process_frame
	_expect(_alchemy_models_ready(alchemy, "recipe_swift"), "Swiftness formula and reagents use catalogued models")
	await _capture(output_directory.path_join("04-alchemy-swiftness-models.png"))

	alchemy.call("_choose_recipe", "recipe_vision")
	await process_frame
	_expect(_alchemy_models_ready(alchemy, "recipe_vision"), "Vision formula and reagents use catalogued models")
	await _capture(output_directory.path_join("05-alchemy-vision-models.png"))
	_finish()


func _seed_state(game_state: Node) -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.current_room_id = "chemistry_room"
	for recipe_id: String in ["recipe_swift", "recipe_vision"]:
		game_state.call("add_recipe", recipe_id)
	for herb_id: String in ["blue_blossom", "moonleaf"]:
		game_state.call("add_herb", herb_id, 8)
	for material_id: String in ["distilled_water", "iron_salt", "prism_dust"]:
		game_state.call("add_material", material_id, 8)
	for potion_id: String in ["swift_potion", "vision_potion"]:
		game_state.call("add_inventory_item", potion_id)


func _visible_artwork_count(inventory: Node) -> int:
	var count := 0
	for node: Node in inventory.find_children("ItemArtwork", "TextureRect", true, false):
		var artwork := node as TextureRect
		if artwork.visible and artwork.texture != null:
			count += 1
	return count


func _alchemy_models_ready(alchemy: Node, selected_recipe: String) -> bool:
	var recipe_icons := alchemy.get("recipe_icons") as Dictionary
	var selected_icon := recipe_icons.get(selected_recipe) as TextureRect
	if selected_icon == null or selected_icon.texture == null:
		return false
	var reagent_icons := alchemy.get("reagent_icons") as Dictionary
	if reagent_icons.size() != 3:
		return false
	for icon_variant: Variant in reagent_icons.values():
		var icon := icon_variant as TextureRect
		if icon == null or icon.texture == null:
			return false
	return true


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
	var inventory := root.get_node_or_null("InventoryHud")
	if inventory != null and bool(inventory.get("_open")):
		inventory.call("close_bag")
	if room != null and is_instance_valid(room):
		if current_scene == room:
			current_scene = null
		room.queue_free()
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("item_model_visual_capture: PASS")
		quit(0)
		return
	printerr("item_model_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
