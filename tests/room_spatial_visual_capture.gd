extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-15-room-spatial"
const ROOM_CASES: Array[Dictionary] = [
	{
		"id": "01-wake-room",
		"scene": "res://scenes/wake_room.tscn",
		"player": NodePath("player"),
		"prop": NodePath("Props/Bed"),
		"interaction": "prop:bed",
		"refresh": "wake",
	},
	{
		"id": "02-castle-hall",
		"scene": "res://scenes/game_world.tscn",
		"player": NodePath("player"),
		"prop": NodePath("WallCollisions/StorageRack"),
		"interaction": "hidden_library_key",
		"refresh": "hall",
	},
	{
		"id": "03-chemistry-room",
		"scene": "res://scenes/floor_1/chemistry_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("Worldsort/ChemistryLabTable"),
		"interaction": "alchemy_table",
		"refresh": "chemistry",
	},
	{
		"id": "04-greenhouse-room",
		"scene": "res://scenes/floor_1/greenhouse_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("Worldsort/Workbench"),
		"interaction": "workbench",
		"refresh": "greenhouse",
	},
	{
		"id": "05-circuit-room",
		"scene": "res://scenes/floor_1/circuit_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("Worldsort/Workbench"),
		"interaction": "workbench",
		"refresh": "runtime",
	},
	{
		"id": "06-dining-hall",
		"scene": "res://scenes/floor_1/dining_hall_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("Worldsort/DiningTable"),
		"interaction": "dining_table",
		"refresh": "runtime",
	},
	{
		"id": "07-library",
		"scene": "res://scenes/floor_1/library_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("Worldsort/StorageCabinet"),
		"interaction": "storage_cabinet",
		"refresh": "runtime",
	},
	{
		"id": "08-final-room",
		"scene": "res://scenes/floor_1/final_room.tscn",
		"player": NodePath("Worldsort/player"),
		"prop": NodePath("FinalAnalysisBoardVisual"),
		"interaction": "deduction_platform",
		"refresh": "final",
	},
]

var failures: Array[String] = []
var spatial := RoomSpatialRuntime.new()


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		_fail("Could not create evidence directory: " + output_directory)
		_finish()
		return

	for room_case: Dictionary in ROOM_CASES:
		_prepare_state()
		await _capture_room(room_case, output_directory)
	_finish()


func _prepare_state() -> void:
	var game_state := root.get_node("GameState")
	game_state.reset_new_game()
	game_state.set("_loading_save", true)
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.chase_mode = false
	game_state.enemy_chase_active = false
	game_state.return_spawn_id = "hall_entrance"
	debug_collisions_hint = false


func _capture_room(room_case: Dictionary, output_directory: String) -> void:
	var packed := load(str(room_case["scene"])) as PackedScene
	if packed == null:
		_fail("Could not load room scene: " + str(room_case["scene"]))
		return
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await physics_frame
	await create_timer(0.35).timeout
	var guardian_reveal_active: Variant = room.get("guardian_entry_sequence_active")
	if guardian_reveal_active is bool and guardian_reveal_active:
		await create_timer(2.35).timeout

	var player := room.get_node_or_null(room_case["player"] as NodePath) as CharacterBody2D
	var prop := room.get_node_or_null(room_case["prop"] as NodePath) as Node2D
	if player == null or prop == null:
		_fail("Capture actors missing for " + str(room_case["id"]))
		await _release(room)
		return

	room.set_process(false)
	player.set_process(false)
	player.set_physics_process(false)
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	_freeze_room_actors(room, player)
	_hide_global_huds()
	_hide_room_fog(room)
	_focus_camera(player)
	_clear_focus(room)
	await _capture(
		output_directory.path_join(str(room_case["id"]) + "-01-safe-spawn.png")
	)

	var visual := spatial.find_visual_node(prop) as CanvasItem
	var visual_rect := spatial.get_visual_rect(prop)
	if visual == null or visual_rect.size.x <= 0.0 or visual_rect.size.y <= 0.0:
		_fail("No visible prop footprint for " + str(room_case["id"]))
		await _release(room)
		return

	player.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y - 32.0)
	var behind_interaction := _refresh_spatial_state(room, room_case)
	_focus_camera(player)
	await _capture(
		output_directory.path_join(str(room_case["id"]) + "-02-player-behind.png")
	)
	var behind_z := visual.z_index

	player.global_position = Vector2(visual_rect.get_center().x, visual_rect.end.y + 18.0)
	var front_interaction := _refresh_spatial_state(room, room_case)
	_focus_camera(player)
	await _capture(
		output_directory.path_join(str(room_case["id"]) + "-03-player-front.png")
	)
	var front_z := visual.z_index

	print("VISUAL_CONTRACT,%s,behind_z=%d,front_z=%d,behind_interaction=%s,front_interaction=%s" % [
		room_case["id"], behind_z, front_z, behind_interaction, front_interaction
	])
	if behind_z <= front_z:
		_fail("Depth did not reverse for " + str(room_case["id"]))
	if behind_interaction != str(room_case["interaction"]):
		_fail("Behind capture did not activate the expected focus for " + str(room_case["id"]))
	if front_interaction != str(room_case["interaction"]):
		_fail("Front capture did not activate the expected focus for " + str(room_case["id"]))
	await _release(room)


func _refresh_spatial_state(room: Node, room_case: Dictionary) -> String:
	var interaction_id := str(room_case["interaction"])
	match str(room_case["refresh"]):
		"wake":
			room.call("_update_prop_occlusion_layers")
			room.call("update_interaction_prompt")
			room.call("update_interaction_focus")
		"chemistry":
			room.call("_update_prop_occlusion_layers")
			room.call("update_interaction_prompt")
			room.call("update_interaction_focus")
		"final":
			room.call("_update_authored_prop_occlusion_layers")
			room.call("update_interaction_prompt")
			room.call("update_interaction_focus")
		"hall":
			room.call("_update_hall_prop_occlusion_layers")
			room.call("update_interaction_prompt")
			room.call("update_interaction_focus")
		"greenhouse":
			room.call("_update_prop_occlusion_layers")
			room.call("update_exit_interaction")
			room.call("update_interaction_focus")
		"runtime":
			var runtime := room.get("interaction_runtime") as Node
			if runtime == null:
				_fail("Interaction runtime missing for " + str(room_case["id"]))
				return ""
			return str(runtime.call("refresh", true))
		_:
			_fail("Unknown refresh mode: " + str(room_case["refresh"]))
			return ""
	return str(room.get("current_interaction"))


func _freeze_room_actors(room: Node, player: CharacterBody2D) -> void:
	for node: Node in room.find_children("*", "CharacterBody2D", true, false):
		var body := node as CharacterBody2D
		if body == player:
			continue
		body.set_process(false)
		body.set_physics_process(false)
	for node: Node in room.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := node as AnimatedSprite2D
		sprite.stop()
		sprite.frame = 0


func _hide_global_huds() -> void:
	for child: Node in root.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false


func _hide_room_fog(room: Node) -> void:
	var fog := room.find_child("FogOfWarSprite", true, false) as CanvasItem
	if fog != null:
		fog.visible = false
	var guardian := room.get_node_or_null("CastleGuardian") as CanvasItem
	if guardian != null:
		guardian.visible = false


func _clear_focus(room: Node) -> void:
	var focus := room.find_child("WorldInteractionFocus", true, false) as Node
	if focus != null:
		focus.call("clear_focus")
	var hint := room.find_child("InteractionHint", true, false) as CanvasItem
	if hint != null:
		hint.visible = false


func _focus_camera(player: Node2D) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid 1024x768 viewport capture: " + absolute_path)
		return
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


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


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("room_spatial_visual_capture: PASS")
		quit(0)
		return
	printerr("room_spatial_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
