extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_ROOT := "res://docs/evidence/2026-08-13-character-scale"
const ROOM_CASES: Array[Dictionary] = [
	{
		"id": "01-wake-room-player",
		"scene": "res://scenes/wake_room.tscn",
		"player": NodePath("player"),
		"arrangement": "player_only",
	},
	{
		"id": "02-castle-hall-guardian",
		"scene": "res://scenes/game_world.tscn",
		"player": NodePath("player"),
		"arrangement": "guardian_pair",
	},
	{
		"id": "03-chemistry-cast",
		"scene": "res://scenes/floor_1/chemistry_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "chemistry_cast",
	},
	{
		"id": "04-greenhouse-gardener",
		"scene": "res://scenes/floor_1/greenhouse_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "gardener_pair",
	},
	{
		"id": "05-circuit-mechanic",
		"scene": "res://scenes/floor_1/circuit_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "mechanic_pair",
	},
	{
		"id": "06-dining-hall-player",
		"scene": "res://scenes/floor_1/dining_hall_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "player_only",
	},
	{
		"id": "07-library-player",
		"scene": "res://scenes/floor_1/library_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "player_only",
	},
	{
		"id": "08-final-room-mrs-lin",
		"scene": "res://scenes/floor_1/final_room.tscn",
		"player": NodePath("Worldsort/player"),
		"arrangement": "final_pair",
	},
]

var failures: Array[String] = []
var output_variant := "before"


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
		_fail("Could not create evidence directory: " + output_directory)
		_finish()
		return

	for room_case: Dictionary in ROOM_CASES:
		_prepare_game_state()
		await _capture_room(room_case, output_directory)
	_finish()


func _prepare_game_state() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_fail("GameState autoload is unavailable")
		return
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.chase_mode = false
	game_state.enemy_chase_active = false
	game_state.return_spawn_id = "hall_entrance"
	debug_collisions_hint = false


func _capture_room(room_case: Dictionary, output_directory: String) -> void:
	var packed_scene := load(str(room_case["scene"])) as PackedScene
	if packed_scene == null:
		_fail("Could not load room scene: " + str(room_case["scene"]))
		return
	var room := packed_scene.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.40).timeout
	var guardian_reveal_active: Variant = room.get("guardian_entry_sequence_active")
	if guardian_reveal_active is bool and guardian_reveal_active:
		await create_timer(2.30).timeout

	var player := room.get_node_or_null(room_case["player"] as NodePath) as Node2D
	if player == null:
		_fail("Player missing from " + str(room_case["scene"]))
		await _release_room(room)
		return
	player.set_physics_process(false)
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")

	await _arrange_room(room, player, str(room_case["arrangement"]))
	_hide_capture_obstructions(room)
	_freeze_animated_sprites(room)
	_focus_camera(player)
	await process_frame
	await process_frame
	await process_frame

	var output_path := output_directory.path_join(str(room_case["id"]) + ".png")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		_fail("Empty viewport capture for " + str(room_case["id"]))
	elif image.get_size() != VIEWPORT_SIZE:
		_fail(
			"Unexpected viewport size for %s: %s" % [
				room_case["id"],
				image.get_size(),
			]
		)
	else:
		var save_error := image.save_png(output_path)
		if save_error != OK:
			_fail("Could not save capture: " + output_path)
		else:
			print("CAPTURED: " + output_path)
	await _release_room(room)


func _arrange_room(room: Node, player: Node2D, arrangement: String) -> void:
	match arrangement:
		"guardian_pair":
			var guardian := room.get_node_or_null("CastleGuardian") as Node2D
			if guardian == null:
				_fail("Castle Guardian missing from Hall")
				return
			guardian.visible = true
			guardian.set_process(false)
			guardian.set_physics_process(false)
			guardian.global_position = Vector2(1565.0, 1070.0)
			player.global_position = guardian.global_position + Vector2(-58.0, 0.0)
		"chemistry_cast":
			if room.has_method("_create_vision_echo"):
				room.call("_create_vision_echo")
				await process_frame
			var butler := room.find_child("ButlerNPC", true, false) as Node2D
			var echo := room.find_child("DrLinMemoryEcho", true, false) as Node2D
			if butler == null or echo == null:
				_fail("Chemistry cast was not fully created")
				return
			player.global_position = Vector2(530.0, 860.0)
			butler.global_position = Vector2(610.0, 860.0)
			echo.global_position = Vector2(690.0, 860.0)
			butler.set_process(false)
			echo.set_process(false)
		"gardener_pair":
			var gardener := room.find_child("GardenerNPC", true, false) as Node2D
			if gardener == null:
				_fail("Gardener missing from Greenhouse")
				return
			gardener.set_process(false)
			player.global_position = gardener.global_position + Vector2(-70.0, 0.0)
		"mechanic_pair":
			var mechanic := room.find_child("MechanicNPC", true, false) as Node2D
			if mechanic == null:
				_fail("Mechanic missing from Circuit Room")
				return
			mechanic.set_process(false)
			player.global_position = mechanic.global_position + Vector2(-70.0, 0.0)
		"final_pair":
			var mrs_lin := room.get_node_or_null("MrsLinBody") as Node2D
			if mrs_lin == null:
				_fail("Mrs. Lin body prop missing from Final Room")
				return
			player.global_position = mrs_lin.global_position + Vector2(58.0, 0.0)
		"player_only":
			pass
		_:
			_fail("Unknown capture arrangement: " + arrangement)


func _hide_capture_obstructions(room: Node) -> void:
	for child: Node in root.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	for node: Node in room.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var fog := room.find_child("FogOfWarSprite", true, false) as CanvasItem
	if fog != null:
		fog.visible = false
	var interaction_focus := room.find_child("WorldInteractionFocus", true, false) as CanvasItem
	if interaction_focus != null:
		interaction_focus.visible = false


func _freeze_animated_sprites(room: Node) -> void:
	for node: Node in room.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := node as AnimatedSprite2D
		sprite.stop()
		sprite.frame = 0


func _focus_camera(player: Node2D) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


func _release_room(room: Node) -> void:
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("character_scale_visual_capture: PASS (" + output_variant + ")")
		quit(0)
		return
	printerr("character_scale_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
