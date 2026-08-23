extends SceneTree

## Fog of war runs every frame, so its cost is felt continuously rather than as
## a single stall. The original implementation rebuilt the explored-memory layer
## from scratch each frame by iterating a dictionary of string keys and parsing
## each one back into coordinates, which made the per-frame cost grow with how
## much of the map the player had explored.
##
## This suite pins the cost flat: fully explored must not be materially more
## expensive than freshly arrived.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.reset_new_game()
	gs.game_started = true
	gs.call("grant_wake_room_toolkit")
	gs.set("return_spawn_id", "chemistry_door")
	gs.set("current_room_id", "floor_1_hub")
	gs.hall_arrival_seen = true
	# Explored memory is only drawn once power is restored, which is the
	# expensive path and therefore the one worth pinning.
	gs.call("set_story_flag", "circuit_power_restored")

	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame

	var cols: int = hall.get("FOG_COLS")
	var rows: int = hall.get("FOG_ROWS")
	var fresh := _time_fog(hall, 0, cols, rows)
	var explored := _time_fog(hall, cols * rows, cols, rows)

	print("[FOG] fresh arrival  %.2f ms" % fresh)
	print("[FOG] fully explored %.2f ms" % explored)

	# The explored pass should be a copy, not a rebuild. A little overhead is
	# fine; scaling with map size is not.
	_expect(
		explored <= fresh * 1.60 + 0.30,
		"Fog cost does not scale with exploration (fresh %.2f ms, explored %.2f ms)" % [
			fresh, explored
		]
	)
	# Absolute ceiling: this runs every frame, and the web build is several
	# times slower than the editor, so a few milliseconds here is already a
	# visible stutter in a browser.
	_expect(
		explored < 3.0,
		"Fog stays within a per-frame budget (%.2f ms)" % explored
	)

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	gs.reset_new_game()
	gs.game_started = false
	gs.set("_loading_save", false)
	_finish()


func _time_fog(hall: Node, explored: int, cols: int, rows: int) -> float:
	var discovered: Dictionary = hall.get("discovered_fog_cells")
	discovered.clear()
	if hall.has_method("reset_fog_memory"):
		hall.call("reset_fog_memory")
	for index: int in range(explored):
		hall.call("mark_fog_discovered", Vector2i(index % cols, (index / cols) % rows))
	# Warm once so texture allocation is not charged to the first sample.
	hall.call("update_fog_of_war")
	var iterations := 40
	var start := Time.get_ticks_usec()
	for _i: int in range(iterations):
		hall.call("update_fog_of_war")
	return float(Time.get_ticks_usec() - start) / float(iterations) / 1000.0


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("fog_performance_test: PASS")
		quit(0)
	else:
		printerr("fog_performance_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
