extends SceneTree

var failures: Array[String] = []
var game_state: Node
var hall: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.current_room_id = "floor_1_hub"
	game_state.call("set_story_flag", "circuit_power_restored", false)
	game_state.hall_explored_cells["10,10"] = true

	var packed := load("res://scenes/game_world.tscn") as PackedScene
	if packed == null:
		_fail("Castle Hall scene could not load")
		_finish()
		return
	hall = packed.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	hall.set_process(false)
	var player := hall.get_node_or_null("player") as CharacterBody2D
	if player == null:
		_fail("Castle Hall player is unavailable")
		_finish()
		return
	player.set_physics_process(false)
	player.global_position = Vector2(1500.0, 1000.0)

	var discovered := hall.get("discovered_fog_cells") as Dictionary
	discovered["8,8"] = true
	hall.call("update_fog_of_war")
	var world_fog := hall.get("fog_image") as Image
	_expect(
		world_fog.get_pixel(8, 8).a >= 0.99,
		"Before Circuit power, previously seen Hall walls return to pitch black"
	)

	var map_hud := root.get_node("MapHud")
	map_hud.call("_refresh_fog_texture")
	var map_fog := map_hud.get("fog_image") as Image
	var minimap_fog := map_hud.get("guardian_minimap_fog_rect") as TextureRect
	_expect(
		minimap_fog != null
		and minimap_fog.texture == map_hud.get("fog_texture")
		and str(minimap_fog.get_meta("fog_policy", "")) == "shared_power_memory",
		"Guardian minimap shares the power-gated exploration fog"
	)
	var explored_map_pixel := _map_pixel_for_hall_cell(Vector2i(10, 10))
	_expect(
		map_fog.get_pixelv(explored_map_pixel).a >= 0.99,
		"Before Circuit power, the route map does not reveal walked ground"
	)

	game_state.call("set_story_flag", "circuit_power_restored", true)
	hall.call("update_fog_of_war")
	world_fog = hall.get("fog_image") as Image
	_expect(
		world_fog.get_pixel(8, 8).a >= 0.60 and world_fog.get_pixel(8, 8).a < 0.90,
		"After Circuit power, previously seen Hall walls become gray memory"
	)

	map_hud.call("_refresh_fog_texture")
	map_fog = map_hud.get("fog_image") as Image
	map_hud.call("_refresh_map_ledger")
	var map_detail := map_hud.get("map_detail") as Label
	_expect(
		map_detail.text.contains("POWER ONLINE") and not map_detail.text.contains("TOTAL BLACKOUT"),
		"After Circuit power, pursuit ledger reports power online"
	)
	var powered_alpha := map_fog.get_pixelv(explored_map_pixel).a
	_expect(
		powered_alpha >= 0.50 and powered_alpha < 0.90,
		"After Circuit power, walked map ground becomes gray instead of fully clear"
	)
	_expect(
		map_fog.get_pixel(1400, 1000).a >= 0.99,
		"After Circuit power, unwalked map ground remains black"
	)
	_finish()


func _map_pixel_for_hall_cell(cell: Vector2i) -> Vector2i:
	var world_center := (Vector2(cell) + Vector2(0.5, 0.5)) * 32.0
	return Vector2i(
		roundi(world_center.x * 1448.0 / 1920.0),
		roundi(world_center.y * 1086.0 / 1280.0)
	)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if hall != null and is_instance_valid(hall):
		if current_scene == hall:
			current_scene = null
		hall.queue_free()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("power_blackout_flow_test: PASS")
		quit(0)
		return
	printerr("power_blackout_flow_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)