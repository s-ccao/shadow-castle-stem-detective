extends SceneTree

## Library knowledge shelves must be reachable under real gameplay selection.
##
## The room picks the FIRST item in INTERACT_ITEMS whose rect is within the
## contact margin of the player. An overlapping neighbour that appears earlier
## in the array therefore permanently shadows a shelf, which no state-level
## contract can detect. This audit walks real player positions instead.

const SHELVES: Array = ["topleft_tall_case", "lower_storage", "storage_cabinet"]

var failures: Array[String] = []
var game_state: Node
var spatial := RoomSpatialRuntime.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.current_room_id = "library"
	var packed := load("res://scenes/floor_1/library_room.tscn") as PackedScene
	if packed == null:
		_fail("Library scene loads")
		_finish()
		return
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.30).timeout

	var player := room.get_node("Worldsort/player") as CharacterBody2D
	var runtime := room.get("interaction_runtime") as Node
	if player == null or runtime == null:
		_fail("Library exposes a player and interaction runtime")
		await _release(room)
		_finish()
		return
	player.set_physics_process(false)
	room.set_process(false)

	for shelf_variant: Variant in SHELVES:
		var shelf := str(shelf_variant)
		var rect := room.call("get_library_interaction_rect", shelf) as Rect2
		_expect(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has a real footprint" % shelf)
		var reachable := false
		var standable := 0
		var shadows: Dictionary = {}
		var y := rect.position.y - 60.0
		while y <= rect.end.y + 84.0:
			var x := rect.position.x - 60.0
			while x <= rect.end.x + 60.0:
				var spot := Vector2(x, y)
				if not spatial.is_position_clear(player, spot, 0.0):
					x += 10.0
					continue
				player.global_position = spot
				var selected := str(runtime.call("refresh", true))
				if selected == shelf:
					reachable = true
					standable += 1
				elif selected != "" and selected != "exit":
					shadows[selected] = int(shadows.get(selected, 0)) + 1
				x += 10.0
			y += 10.0
		if reachable:
			print(
				"PASS: %s is selectable from %d standable spot(s)" % [shelf, standable]
			)
			_expect(
				standable >= 100,
				"%s offers a findable approach area (%d spots)" % [shelf, standable]
			)
		else:
			var blockers: Array = shadows.keys()
			blockers.sort()
			_fail(
				"%s is unreachable in play; shadowed by %s"
				% [shelf, ", ".join(PackedStringArray(blockers))]
			)

	var markers := room.get("knowledge_shelf_markers") as Dictionary
	_expect(markers.size() == 3, "Every knowledge shelf carries a world marker")
	for knowledge_variant: Variant in markers:
		var marker := markers[knowledge_variant] as Node2D
		_expect(
			marker != null and marker.position.y >= 80.0,
			"%s marker sits inside the visible room instead of behind the top wall" % str(knowledge_variant)
		)

	var rect_by_name: Dictionary = {}
	for shelf_variant: Variant in SHELVES:
		rect_by_name[str(shelf_variant)] = room.call(
			"get_library_interaction_rect", str(shelf_variant)
		) as Rect2
	var constants := room.get("INTERACT_ITEMS") as Array
	var index_of: Dictionary = {}
	for index: int in range(constants.size()):
		index_of[str((constants[index] as Dictionary)["name"])] = index
	for item_variant: Variant in constants:
		var item := item_variant as Dictionary
		var item_name := str(item["name"])
		if SHELVES.has(item_name):
			continue
		var other := room.call("get_library_interaction_rect", item_name) as Rect2
		for shelf_variant: Variant in SHELVES:
			var shelf := str(shelf_variant)
			if int(index_of[item_name]) > int(index_of[shelf]):
				continue
			var shelf_rect := rect_by_name[shelf] as Rect2
			_expect(
				not other.intersects(shelf_rect),
				"%s is listed before %s and must not cover it" % [item_name, shelf]
			)

	await _release(room)
	_finish()


func _release(room: Node) -> void:
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame
	paused = false


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(description: String) -> void:
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	game_state.game_started = false
	game_state.set("_loading_save", false)
	if failures.is_empty():
		print("library_knowledge_access_test: PASS")
		quit(0)
		return
	printerr("library_knowledge_access_test: FAIL (%d issue(s))" % failures.size())
	quit(1)
