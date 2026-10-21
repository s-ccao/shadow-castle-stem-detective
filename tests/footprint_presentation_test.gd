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
	_check_trail_stays_in_sight(hall)
	_check_compass_names_next_leg(hall)
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


## The trail is drawn above the fog, so a print the player cannot see past a
## wall used to glow straight through it. Walk the opening route and check at
## every stop that each visible print is either in line of sight or about as
## near in a straight line as along the trail, and never on the character.
func _check_trail_stays_in_sight(hall: Node) -> void:
	var player := hall.get("player") as Node2D
	var route: Array[Vector2] = hall.get("hall_tutorial_route")
	if route.size() < 2:
		_expect(false, "The opening route exists for the sight check")
		return
	var ratio: float = hall.get("HALL_ROUTE_SIGHT_RATIO")
	var length: float = hall.call("_hall_route_length", route)
	var start := player.global_position
	var leaks := 0
	var on_body := 0
	var stops := 0
	var offset := 0.0
	while offset < length:
		var sample: Dictionary = hall.call("_hall_route_sample", route, offset)
		player.global_position = sample["point"]
		hall.set("hall_route_distance_travelled", offset)
		hall.call("_update_hall_route_marker_visibility")
		var body: Rect2 = hall.get("spatial").call("get_visual_rect", player)
		for marker: Node2D in hall.get("hall_route_marker_nodes"):
			if not marker.visible:
				continue
			var ahead := maxf(float(marker.get_meta("route_offset", 0.0)) - offset, 0.0)
			var straight := player.global_position.distance_to(marker.global_position)
			var seen: bool = hall.call(
				"has_world_line_of_sight", player.global_position, marker.global_position
			)
			if straight < ahead * ratio and not seen:
				leaks += 1
			if body.has_point(marker.global_position):
				on_body += 1
		stops += 1
		offset += 96.0
	_expect(stops > 5, "The sight check walks the whole opening route (%d stops)" % stops)
	_expect(leaks == 0, "No visible footprint glows through a wall the trail goes round (%d)" % leaks)
	_expect(on_body == 0, "No footprint is stamped across the character (%d)" % on_body)
	player.global_position = start
	hall.set("hall_route_distance_travelled", 0.0)
	hall.call("_update_hall_route_marker_visibility")


## The route card names the way the footprints set off, not the bearing of the
## goal: in the maze those disagree from the first step.
func _check_compass_names_next_leg(hall: Node) -> void:
	var route: Array[Vector2] = hall.get("hall_tutorial_route")
	var panel := hall.get("hall_route_panel") as Control
	var compass := hall.get("hall_route_compass") as Label
	if route.size() < 2 or panel == null or compass == null:
		_expect(false, "The route card and compass exist")
		return
	var was_visible := panel.visible
	panel.visible = true
	hall.call("_update_hall_route_compass")
	var first_leg: Vector2 = hall.call("_cardinal_route_direction", route[1] - route[0])
	var expected: String = hall.call("_hall_route_direction", first_leg * 100.0)
	_expect(
		compass.text.contains(expected),
		"The compass names the first leg's heading (%s in '%s')" % [expected, compass.text]
	)
	panel.visible = was_visible


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)
