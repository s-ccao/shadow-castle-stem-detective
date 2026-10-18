extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.game_started = true
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	state.return_spawn_id = "wake_room_first_arrival"
	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	hall.set("guardian_entry_sequence_played", true)
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	hall.call("close_message_panel")
	var markers: Array = hall.get("hall_route_marker_nodes")
	_expect(not markers.is_empty(), "The route has footprint markers")
	var textures: Dictionary = {}
	var visible_count := 0
	for marker: Node2D in markers:
		_expect(marker.find_children("*", "Polygon2D", true, false).is_empty(), "No polygon arrow blob remains")
		_expect(marker.find_children("*", "Line2D", true, false).is_empty(), "No large corner beam remains")
		_expect(marker.scale.is_equal_approx(Vector2.ONE), "Footprints do not inflate as a pulse")
		var ink := marker.find_child("FootprintInk", true, false) as Sprite2D
		_expect(ink != null and ink.texture != null, "Guidance uses a real raster shoe print")
		if ink != null and ink.texture != null:
			textures[ink.texture.resource_path] = true
			_expect(ink.texture.get_size() == Vector2(24, 14), "The authored footprint stays compact")
		if marker.visible:
			visible_count += 1
			_expect(float(marker.get_meta("route_offset", 0.0)) <= 480.0, "Only the nearby forward trail is revealed")
	_expect(visible_count > 0 and visible_count < markers.size(), "The whole maze is not lit at once")
	_expect(textures.size() == 2, "The trail alternates two authored shoes")
	hall.set("hall_route_distance_travelled", 400.0)
	hall.call("_update_hall_route_marker_visibility")
	for marker: Node2D in markers:
		if float(marker.get_meta("route_offset", 0.0)) < 388.0:
			_expect(not marker.visible, "Passed footprints retire")
	current_scene = null
	hall.queue_free()
	await process_frame
	state.call("reset_new_game")
	state.game_started = false
	if failures.is_empty():
		print("footprint_presentation_test: PASS")
		quit(0)
	else:
		printerr("footprint_presentation_test: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
