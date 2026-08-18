extends SceneTree

const ROOM_CASES: Array[Dictionary] = [
	{"id": "wake_room", "scene": "res://scenes/wake_room.tscn", "player": NodePath("player")},
	{"id": "floor_1_hub", "scene": "res://scenes/game_world.tscn", "player": NodePath("player")},
	{"id": "chemistry_room", "scene": "res://scenes/floor_1/chemistry_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "greenhouse_room", "scene": "res://scenes/floor_1/greenhouse_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "circuit_room", "scene": "res://scenes/floor_1/circuit_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "dining_hall", "scene": "res://scenes/floor_1/dining_hall_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "library", "scene": "res://scenes/floor_1/library_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "final_deduction_room", "scene": "res://scenes/floor_1/final_room.tscn", "player": NodePath("Worldsort/player")},
]

var failures: Array[String] = []
var geometry_helper: RoomSpatialRuntime


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	game_state.set("_loading_save", true)
	geometry_helper = RoomSpatialRuntime.new()
	for room_case: Dictionary in ROOM_CASES:
		_prepare_state(str(room_case["id"]))
		await _audit_room(room_case)
	geometry_helper = null
	game_state.game_started = false
	game_state.set("_loading_save", false)
	if failures.is_empty():
		print("room_spatial_audit: PASS")
		quit(0)
	else:
		printerr("room_spatial_audit: FAIL (%d issue(s))" % failures.size())
		quit(1)


func _prepare_state(room_id: String) -> void:
	var game_state := root.get_node("GameState")
	game_state.reset_new_game()
	game_state.set("_loading_save", true)
	game_state.game_started = true
	game_state.hall_arrival_seen = true
	game_state.current_room_id = room_id
	game_state.return_spawn_id = "hall_entrance"
	game_state.developer_mode = false
	game_state.chase_mode = false
	game_state.enemy_chase_active = false


func _audit_room(room_case: Dictionary) -> void:
	var packed := load(str(room_case["scene"])) as PackedScene
	if packed == null:
		_fail("%s scene failed to load" % room_case["id"])
		return
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await physics_frame
	await create_timer(0.30).timeout
	var player := room.get_node_or_null(room_case["player"] as NodePath) as CharacterBody2D
	if player == null:
		_fail("%s player missing" % room_case["id"])
		await _release(room)
		return
	player.set_physics_process(false)
	var overlap_count := _static_overlap_count(player, player.global_position)
	var open_directions := _open_direction_count(player, player.global_position, 32.0)
	print("SPAWN,%s,pos=%s,static_overlaps=%d,open_directions=%d" % [
		room_case["id"], player.global_position, overlap_count, open_directions
	])
	if overlap_count > 0:
		_fail("%s spawn overlaps %d static bodies" % [room_case["id"], overlap_count])
	if open_directions < 3:
		_fail("%s spawn has only %d open directions" % [room_case["id"], open_directions])

	var runtime: Variant = room.get("interaction_runtime")
	if runtime is Node and (runtime as Node).has_method("refresh"):
		_audit_runtime(room_case, runtime as Node)
	if str(room_case["id"]) == "greenhouse_room":
		_audit_greenhouse(room)
	if str(room_case["id"]) == "chemistry_room":
		_audit_chemistry(room)
	if str(room_case["id"]) == "final_deduction_room":
		_audit_final(room)
	if str(room_case["id"]) == "wake_room":
		_audit_wake(room, player)
	if str(room_case["id"]) == "floor_1_hub":
		_audit_hall(room, player)
	await _release(room)


func _audit_runtime(room_case: Dictionary, runtime: Node) -> void:
	runtime.call("refresh", true)
	print("RUNTIME,%s,contact_margin=%.1f,legacy_radius=%.1f,occlusion=%s" % [
		room_case["id"], runtime.get("interaction_contact_margin"), runtime.get("legacy_contact_radius"), runtime.get("occlusion_mode")
	])
	if not is_equal_approx(float(runtime.get("interaction_contact_margin")), 14.0):
		_fail("%s contact margin must be exactly 14px, got %.1f" % [room_case["id"], runtime.get("interaction_contact_margin")])
	var items: Array = runtime.get("items") as Array
	var prop_paths: Dictionary = runtime.get("prop_node_paths") as Dictionary
	var configured_room := runtime.get("room") as Node2D
	for item: Dictionary in items:
		var item_name := str(item["name"])
		_audit_runtime_item_contact(runtime, item, "%s/%s" % [room_case["id"], item_name])
		if prop_paths.has(item_name):
			var prop := configured_room.get_node_or_null(prop_paths[item_name]) as Node2D
			var visual_rect: Rect2 = runtime.call("_get_item_visual_rect", item) as Rect2
			var collision_rect: Rect2 = runtime.call("_get_furniture_collision_rect", item_name) as Rect2
			var focus_rect: Rect2 = runtime.call("_get_item_focus_rect", item) as Rect2
			var sprite := runtime.call("_find_prop_sprite", prop) as Sprite2D
			var padding := (focus_rect.size - visual_rect.size) * 0.5
			print("PROP,%s,%s,visual=%s,collision=%s,focus_padding=%s,parent_ysort=%s,sprite_z=%s/%s" % [
				room_case["id"], item_name, visual_rect, collision_rect, padding,
				str(prop != null and prop.get_parent() is Node2D and (prop.get_parent() as Node2D).y_sort_enabled),
				str(sprite.z_as_relative if sprite != null else false),
				str(sprite.z_index if sprite != null else 0),
			])
			if prop == null or not (prop.get_parent() is Node2D) or not (prop.get_parent() as Node2D).y_sort_enabled:
				_fail("%s/%s is not under an enabled Y-sort parent" % [room_case["id"], item_name])
			if padding.x > 14.0 or padding.y > 14.0:
				_fail("%s/%s focus padding is oversized: %s" % [room_case["id"], item_name, padding])
			if sprite != null:
				var actor := runtime.get("player") as CharacterBody2D
				var original_position := actor.global_position
				actor.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y - 32.0)
				runtime.call("refresh", true)
				var behind_z := sprite.z_index
				actor.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y + 32.0)
				runtime.call("refresh", true)
				var front_z := sprite.z_index
				actor.global_position = original_position
				if behind_z <= front_z:
					_fail("%s/%s does not occlude the player only from behind (%d -> %d)" % [room_case["id"], item_name, behind_z, front_z])
		else:
			print("FALLBACK,%s,%s,position=%s,has_rect=%s" % [
				room_case["id"], item_name, item.get("position", Vector2.ZERO), str(item.has("interaction_rect"))
			])
			if not item.has("interaction_rect"):
				_fail("%s/%s uses a point radius instead of an authored interaction footprint" % [room_case["id"], item_name])
	var exit_rect := runtime.get("exit_rect") as Rect2
	if exit_rect.size.x <= 0.0 or exit_rect.size.y <= 0.0:
		_fail("%s exit has no interaction footprint" % room_case["id"])
	runtime.call("_show_exit_focus")
	var exit_focus := runtime.get("interaction_focus") as Node
	var expected_exit_focus := geometry_helper.grow_rect(exit_rect, Vector2(10.0, 10.0))
	if (
		(exit_focus.get("_target_position") as Vector2).distance_to(expected_exit_focus.get_center()) > 0.1
		or (exit_focus.get("_focus_size") as Vector2).distance_to(expected_exit_focus.size) > 0.1
	):
		_fail("%s exit focus is not the footprint plus 10px padding" % room_case["id"])


func _audit_runtime_item_contact(runtime: Node, item: Dictionary, label: String) -> void:
	var actor := runtime.get("player") as CharacterBody2D
	# The band is measured against the surface the runtime actually reaches from,
	# which for a device mounted on furniture is its authored contact band rather
	# than the painted plate.
	var target_rect := runtime.call("_get_item_contact_rect", item) as Rect2
	var original_position := actor.global_position
	var player_rect := geometry_helper.get_player_collision_rect(actor)
	var right_offset := player_rect.end.x - actor.global_position.x
	var center_y_offset := player_rect.get_center().y - actor.global_position.y
	var test_y := target_rect.get_center().y - center_y_offset
	actor.global_position = Vector2(target_rect.position.x - right_offset - 13.5, test_y)
	var inside_band := bool(runtime.call("_is_player_touching_item", item))
	actor.global_position = Vector2(target_rect.position.x - right_offset - 14.5, test_y)
	var outside_band := bool(runtime.call("_is_player_touching_item", item))
	actor.global_position = original_position
	if not inside_band or outside_band:
		_fail(label + " does not honor the 14px contact band")


func _audit_greenhouse(room: Node) -> void:
	var items: Array = room.get("INTERACT_ITEMS") as Array
	var node_names: Dictionary = {
		"magic_planter": "MagicPlanter",
		"workbench": "Workbench",
		"plant_pots_a": "PlantPotsA",
		"plant_pots_b": "PlantPotsB",
		"arch_door": "ArchDoor",
	}
	for item: Dictionary in items:
		var item_name := str(item["name"])
		var node := room.find_child(str(node_names.get(item_name, "")), true, false) as Node2D
		if node == null:
			continue
		var visual_rect: Rect2 = geometry_helper.call("get_visual_rect", node) as Rect2
		var interaction_rect := room.call("get_interaction_rect", item_name) as Rect2
		var mismatch := interaction_rect.get_center().distance_to(visual_rect.get_center())
		print("GREENHOUSE,%s,interaction=%s,visual=%s,mismatch=%.1f" % [item_name, interaction_rect, visual_rect, mismatch])
		if mismatch > 2.0 or interaction_rect.size.distance_to(visual_rect.size) > 2.0:
			_fail("greenhouse/%s interaction footprint does not match the visible prop" % item_name)
		_audit_contact_method(
			room,
			room.get_node("Worldsort/player") as CharacterBody2D,
			item_name,
			interaction_rect,
			"_is_near_interaction",
			"greenhouse"
		)
		_audit_occlusion(
			room,
			room.get_node("Worldsort/player") as CharacterBody2D,
			node,
			"_update_prop_occlusion_layers",
			"greenhouse/%s" % item_name
		)
	for interaction_id: String in ["gardener", "exit"]:
		var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
		_audit_contact_method(
			room,
			room.get_node("Worldsort/player") as CharacterBody2D,
			interaction_id,
			interaction_rect,
			"_is_near_interaction",
			"greenhouse"
		)


func _audit_chemistry(room: Node) -> void:
	var player := room.get_node("Worldsort/player") as CharacterBody2D
	var butler := room.find_child("ButlerNPC", true, false) as Node2D
	if butler != null:
		var same_parent := butler.get_parent() == player.get_parent()
		print("CHEMISTRY,butler_same_ysort_parent=%s,butler_z=%d" % [str(same_parent), butler.z_index])
		if not same_parent or butler.z_index != 0:
			_fail("chemistry Butler does not participate in player Y-sort")
	if not room.has_method("get_interaction_rect"):
		_fail("chemistry interactions are not exposed as visual footprints")
	for item_name: String in ["cabinet", "alchemy_table"]:
		var prop_path := (
			NodePath("Worldsort/ChemistryPotionCabinet")
			if item_name == "cabinet"
			else NodePath("Worldsort/ChemistryLabTable")
		)
		var prop := room.get_node_or_null(prop_path) as Node2D
		var interaction_rect := room.call("get_interaction_rect", item_name) as Rect2
		var visual_rect := geometry_helper.get_visual_rect(prop)
		if interaction_rect != visual_rect:
			_fail("chemistry/%s interaction footprint does not match its visible overlay" % item_name)
		_audit_occlusion(
			room,
			player,
			prop,
			"_update_prop_occlusion_layers",
			"chemistry/%s" % item_name
		)
	for interaction_id: String in ["exit", "cabinet", "alchemy_table", "red_stain", "butler"]:
		var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
		_audit_contact_method(
			room,
			player,
			interaction_id,
			interaction_rect,
			"_is_near_interaction",
			"chemistry"
		)


func _audit_final(room: Node) -> void:
	if not room.has_method("get_interaction_rect"):
		_fail("final room interactions are not exposed as visual footprints")
	var constants: Dictionary = (room.get_script() as GDScript).get_script_constant_map()
	var occlusion_paths: Array = constants.get("AUTHORED_OCCLUSION_NODE_PATHS", []) as Array
	for path_variant: Variant in occlusion_paths:
		var path := path_variant as NodePath
		var node := room.get_node_or_null(path) as Node2D
		if node == null:
			continue
		var visual_rect := _canvas_visual_rect(node)
		var pivot_delta := absf(node.global_position.y - visual_rect.end.y)
		print("FINAL,%s,visual=%s,pivot_delta=%.1f,z=%d" % [node.name, visual_rect, pivot_delta, node.z_index])
		var interaction_id := ""
		for item_name: Variant in (constants.get("AUTHORED_INTERACTION_NODE_PATHS", {}) as Dictionary).keys():
			if (constants.get("AUTHORED_INTERACTION_NODE_PATHS", {}) as Dictionary)[item_name] == path:
				interaction_id = str(item_name)
				break
		if not interaction_id.is_empty():
			var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
			var opaque_visual_rect := geometry_helper.get_visual_rect(node)
			if interaction_rect != opaque_visual_rect:
				_fail("final/%s interaction footprint does not match its visible prop" % interaction_id)
			_audit_contact_method(
				room,
				room.get_node("Worldsort/player") as CharacterBody2D,
				interaction_id,
				interaction_rect,
				"_is_near_interaction",
				"final"
			)
		_audit_occlusion(
			room,
			room.get_node("Worldsort/player") as CharacterBody2D,
			node,
			"_update_authored_prop_occlusion_layers",
			"final/%s" % node.name
		)
	var exit_rect := room.call("get_interaction_rect", "exit") as Rect2
	_audit_contact_method(
		room,
		room.get_node("Worldsort/player") as CharacterBody2D,
		"exit",
		exit_rect,
		"_is_near_interaction",
		"final"
	)


func _audit_wake(room: Node, player: CharacterBody2D) -> void:
	var interactions: Dictionary = {
		"door": NodePath("Props/Door"),
		"prop:bed": NodePath("Props/Bed"),
		"prop:desk": NodePath("Props/Desk"),
		"prop:bookshelf": NodePath("Props/Bookshelf"),
	}
	for interaction_id: String in interactions:
		var prop := room.get_node_or_null(interactions[interaction_id]) as Node2D
		var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
		var visual_rect := geometry_helper.get_visual_rect(prop)
		print("WAKE,%s,interaction=%s,visual=%s" % [interaction_id, interaction_rect, visual_rect])
		if interaction_rect != visual_rect:
			_fail("wake/%s interaction footprint does not match its visible prop" % interaction_id)
		_audit_contact_method(room, player, interaction_id, interaction_rect, "_is_near_interaction", "wake")
		_audit_occlusion(room, player, prop, "_update_prop_occlusion_layers", "wake/%s" % interaction_id)
	var clue_rect := room.call("get_interaction_rect", "room_clue") as Rect2
	_audit_contact_method(room, player, "room_clue", clue_rect, "_is_near_interaction", "wake")


func _audit_occlusion(
	room: Node,
	player: CharacterBody2D,
	prop: Node2D,
	update_method: String,
	label: String
) -> void:
	if prop == null:
		_fail(label + " occlusion prop is missing")
		return
	var visual := geometry_helper.find_visual_node(prop) as CanvasItem
	if visual == null:
		_fail(label + " has no visual node for occlusion")
		return
	var visual_rect := geometry_helper.get_visual_rect(prop)
	var original_position := player.global_position
	player.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y - 32.0)
	room.call(update_method)
	var behind_z := visual.z_index
	player.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y + 32.0)
	room.call(update_method)
	var front_z := visual.z_index
	player.global_position = original_position
	room.call(update_method)
	print("OCCLUSION,%s,behind_z=%d,front_z=%d" % [label, behind_z, front_z])
	if behind_z <= front_z:
		_fail("%s does not draw above the player from behind and below it from the front (%d -> %d)" % [label, behind_z, front_z])


func _audit_hall(room: Node, player: CharacterBody2D) -> void:
	var game_state := root.get_node("GameState")
	var original_return_id := str(game_state.return_spawn_id)
	var spawn_ids: Array[String] = [
		"hall_entrance",
		"wake_room_first_arrival",
		"wake_room_door",
		"chemistry_door",
		"greenhouse_door",
		"circuit_door",
		"dining_hall_door",
		"library_door",
		"final_room_door",
	]
	for spawn_id: String in spawn_ids:
		game_state.return_spawn_id = spawn_id
		var preferred := room.call("get_floor_one_spawn_position") as Vector2
		var resolved := room.call("get_safe_floor_one_spawn_position") as Vector2
		var overlaps := _static_overlap_count(player, resolved)
		var open_directions := _open_direction_count(player, resolved, 32.0)
		print("HALL_SPAWN,%s,preferred=%s,resolved=%s,static_overlaps=%d,open_directions=%d" % [
			spawn_id, preferred, resolved, overlaps, open_directions
		])
		if overlaps > 0:
			_fail("hall return %s overlaps %d static bodies" % [spawn_id, overlaps])
		if open_directions < 3:
			_fail("hall return %s has only %d open directions" % [spawn_id, open_directions])
	game_state.return_spawn_id = original_return_id

	var interaction_ids: Array[String] = [
		"corridor_fragment_1",
		"corridor_fragment_2",
		"corridor_fragment_3",
		"hidden_library_key",
		"final_key_machine_1",
		"final_key_machine_2",
		"final_key_machine_3",
		"hall_knowledge:LibraryRoomKnowledge",
		"hall_knowledge:DiningHallKnowledge",
		"hall_knowledge:CircuitRoomKnowledge",
		"hall_knowledge:GreenhouseRoomKnowledge",
		"hall_knowledge:ChemistryRoomKnowledge",
		"chemistry_room_door",
		"greenhouse_room_door",
		"library_door",
		"dining_hall_door",
		"final_room_door",
		"wake_room_door",
		"circuit_door",
		"service_wall_door",
		"service_dark_trail",
		"service_violet_fiber",
		"service_maintenance_panel",
		"arrival_chemistry_door",
		"arrival_chemistry_core",
	]
	for interaction_id: String in interaction_ids:
		var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
		print("HALL_INTERACTION,%s,rect=%s" % [interaction_id, interaction_rect])
		if interaction_rect.size.x <= 0.0 or interaction_rect.size.y <= 0.0:
			_fail("hall/%s has no interaction footprint" % interaction_id)
			continue
		_audit_contact_method(
			room,
			player,
			interaction_id,
			interaction_rect,
			"_is_near_hall_interaction",
			"hall"
		)
		_audit_hall_focus(room, interaction_id, interaction_rect)

	var visual_interactions: Dictionary = {
		"hidden_library_key": NodePath("WallCollisions/StorageRack"),
		"final_key_machine_1": NodePath("WallCollisions/FinalKeyMachine1"),
		"final_key_machine_2": NodePath("WallCollisions/FinalKeyMachine2"),
		"final_key_machine_3": NodePath("WallCollisions/FinalKeyMachine3"),
		"hall_knowledge:LibraryRoomKnowledge": NodePath("WallCollisions/KnowledgeExhibits/LibraryRoomKnowledge"),
		"hall_knowledge:DiningHallKnowledge": NodePath("WallCollisions/KnowledgeExhibits/DiningHallKnowledge"),
		"hall_knowledge:CircuitRoomKnowledge": NodePath("WallCollisions/KnowledgeExhibits/CircuitRoomKnowledge"),
		"hall_knowledge:GreenhouseRoomKnowledge": NodePath("WallCollisions/KnowledgeExhibits/GreenhouseRoomKnowledge"),
		"hall_knowledge:ChemistryRoomKnowledge": NodePath("WallCollisions/KnowledgeExhibits/ChemistryRoomKnowledge"),
	}
	for interaction_id: String in visual_interactions:
		var prop := room.get_node_or_null(visual_interactions[interaction_id]) as Node2D
		var interaction_rect := room.call("get_interaction_rect", interaction_id) as Rect2
		var visual_rect := geometry_helper.get_visual_rect(prop)
		if interaction_rect != visual_rect:
			_fail("hall/%s footprint does not match its visible art" % interaction_id)
		_audit_occlusion(
			room,
			player,
			prop,
			"_update_hall_prop_occlusion_layers",
			"hall/%s" % interaction_id
		)


func _audit_contact_method(
	room: Node,
	player: CharacterBody2D,
	interaction_id: String,
	interaction_rect: Rect2,
	method_name: String,
	room_label: String
) -> void:
	if interaction_rect.size.x <= 0.0 or interaction_rect.size.y <= 0.0:
		return
	var original_position := player.global_position
	var player_rect := geometry_helper.get_player_collision_rect(player)
	var right_offset := player_rect.end.x - player.global_position.x
	var center_y_offset := player_rect.get_center().y - player.global_position.y
	var test_y := interaction_rect.get_center().y - center_y_offset
	player.global_position = Vector2(
		interaction_rect.position.x - right_offset - 13.5,
		test_y
	)
	var inside_band := bool(room.call(method_name, interaction_id))
	player.global_position = Vector2(
		interaction_rect.position.x - right_offset - 14.5,
		test_y
	)
	var outside_band := bool(room.call(method_name, interaction_id))
	player.global_position = original_position
	print("CONTACT,%s/%s,inside_13_5=%s,outside_14_5=%s" % [
		room_label, interaction_id, str(inside_band), str(outside_band)
	])
	if not inside_band or outside_band:
		_fail("%s/%s does not honor the 14px contact band" % [room_label, interaction_id])


func _audit_hall_focus(room: Node, interaction_id: String, interaction_rect: Rect2) -> void:
	room.set("current_interaction", interaction_id)
	room.call("update_interaction_focus")
	var focus := room.get("interaction_focus") as Node
	var expected := geometry_helper.grow_rect(interaction_rect, Vector2(10.0, 10.0))
	var actual_position := focus.get("_target_position") as Vector2
	var actual_size := focus.get("_focus_size") as Vector2
	if not bool(focus.call("is_focused")):
		_fail("hall/%s does not show a focus marker" % interaction_id)
	elif (
		actual_position.distance_to(expected.get_center()) > 0.1
		or actual_size.distance_to(expected.size) > 0.1
	):
		_fail("hall/%s focus is not the footprint plus 10px padding" % interaction_id)
	room.set("current_interaction", "")
	room.call("update_interaction_focus")


func _canvas_visual_rect(node: Node2D) -> Rect2:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture == null:
			return Rect2(sprite.global_position, Vector2.ZERO)
		var local_rect := sprite.get_rect()
		var corners: Array[Vector2] = [
			local_rect.position,
			local_rect.position + Vector2(local_rect.size.x, 0),
			local_rect.end,
			local_rect.position + Vector2(0, local_rect.size.y),
		]
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for corner: Vector2 in corners:
			var point := sprite.to_global(corner)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		return Rect2(minimum, maximum - minimum)
	var sprite := geometry_helper.call("find_visual_node", node) as Sprite2D
	if sprite != null:
		return geometry_helper.call("get_visual_rect", node) as Rect2
	return Rect2(node.global_position, Vector2.ZERO)


func _static_overlap_count(player: CharacterBody2D, position: Vector2) -> int:
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 99
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = Transform2D(player.global_rotation, position + collision.position.rotated(player.global_rotation))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var count := 0
	for hit: Dictionary in player.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var collider: Object = hit.get("collider")
		if collider is StaticBody2D:
			count += 1
	return count


func _open_direction_count(player: CharacterBody2D, position: Vector2, distance: float) -> int:
	var open_count := 0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if _static_overlap_count(player, position + direction * distance) == 0:
			open_count += 1
	return open_count


func _release(room: Node) -> void:
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame
	paused = false


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)
