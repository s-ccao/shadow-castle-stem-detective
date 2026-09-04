extends SceneTree

## 教程路线必须是人走出来的那条，而不是 A* 现算的。
##
## A* 只保证能走到，不保证走得像话：它贴墙角切、在空地上走对角线，于是脚下
## 路标的指向和玩家看到的通路对不上——这就是"方位全是错的"。作者在开发者
## 模式下走一遍，那条路才是教学要教的路。
##
## 这里验三件事，缺一条这个工具就等于没做：录下来的点存得进去、读得出来、
## 而且教程和地面路标真的改用了它（只存不用是最容易发生也最难发现的失败）。

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("_loading_save", false)
	game_state.set("game_started", true)

	_check_store_roundtrip()
	await _check_recorder_captures_a_walk()
	await _check_tutorial_prefers_the_authored_route()
	await _check_recording_is_not_dragged_back()

	game_state.set("developer_mode", false)
	_finish()


func _check_store_roundtrip() -> void:
	var original: Array[Vector2] = [
		Vector2(100.0, 200.0), Vector2(148.0, 232.0), Vector2(302.0, 87.0)
	]
	_expect(HallRouteStore.save_route(original), "A walked route saves to disk")
	var loaded: Array[Vector2] = HallRouteStore.load_route()
	_expect(loaded.size() == original.size(), "Every recorded point survives the round trip")
	var matched := true
	for index: int in range(mini(loaded.size(), original.size())):
		if loaded[index].distance_to(original[index]) > 0.6:
			matched = false
	_expect(matched, "Recorded points come back at the coordinates they were saved at")

	# 半条路比没有路更糟：玩家被引到一半然后卡住，而且看起来像寻路坏了。
	var file := FileAccess.open(HallRouteStore.ROUTE_PATH, FileAccess.WRITE)
	file.store_string("{\"points\": [[1, 2], [3]]}")
	file.close()
	_expect(
		HallRouteStore.load_route().is_empty(),
		"A malformed route is rejected whole rather than loaded half"
	)
	HallRouteStore.clear_route()
	_expect(not HallRouteStore.has_route(), "Clearing removes the authored route")


func _check_recorder_captures_a_walk() -> void:
	HallRouteStore.clear_route()
	var target := Vector2(302.0, 87.0)
	var walker := Node2D.new()
	root.add_child(walker)
	walker.global_position = Vector2(900.0, 700.0)

	var recorder := HallRouteRecorder.new()
	root.add_child(recorder)
	recorder.setup(walker, target)
	await process_frame

	# 走一条明显不是直线的路：如果录制只是记下起点和终点，这一步会暴露它。
	var waypoints: Array[Vector2] = [
		Vector2(900.0, 400.0), Vector2(600.0, 400.0),
		Vector2(600.0, 150.0), target,
	]
	for leg: Vector2 in waypoints:
		var guard: int = 0
		while walker.global_position.distance_to(leg) > 8.0 and guard < 400:
			walker.global_position = walker.global_position.move_toward(leg, 24.0)
			recorder.call("_process", 0.016)
			guard += 1
		await process_frame

	_expect(recorder.is_finished(), "Reaching the Chemistry door ends the recording")
	var points: Array[Vector2] = recorder.recorded_points()
	_expect(points.size() > 4, "The walk is captured as a path, not two endpoints (%d)" % points.size())
	_expect(
		points[points.size() - 1].distance_to(target) <= 1.0,
		"The route finishes on the door itself, not wherever the walk stopped"
	)
	# 拐弯必须被记下来，否则守卫会沿直线穿过玩家绕开的东西。
	var turned := false
	for point: Vector2 in points:
		if point.distance_to(Vector2(600.0, 400.0)) < 60.0:
			turned = true
	_expect(turned, "Corners the author walked around are kept in the route")
	_expect(HallRouteStore.has_route(), "Finishing the walk writes the route to disk")

	recorder.queue_free()
	walker.queue_free()
	await process_frame


## 存下来却没人用，是这类工具最常见也最难察觉的失败。
func _check_tutorial_prefers_the_authored_route() -> void:
	var authored: Array[Vector2] = [
		Vector2(900.0, 700.0), Vector2(900.0, 400.0), Vector2(600.0, 400.0),
		Vector2(600.0, 150.0), Vector2(302.0, 87.0),
	]
	HallRouteStore.save_route(authored)

	var packed := load("res://scenes/game_world.tscn") as PackedScene
	_expect(packed != null, "The Hall scene loads")
	if packed == null:
		return
	var hall: Node = packed.instantiate()
	root.add_child(hall)
	for _frame: int in range(45):
		await process_frame

	var used: Array = hall.call(
		"_hall_route_points", Vector2(900.0, 700.0), Vector2(302.0, 87.0)
	)
	_expect(
		used.size() == authored.size(),
		"The Hall takes its tutorial line from the authored route (%d of %d)" % [
			used.size(), authored.size()
		]
	)
	var same := used.size() == authored.size()
	for index: int in range(mini(used.size(), authored.size())):
		if (used[index] as Vector2).distance_to(authored[index]) > 0.6:
			same = false
	_expect(same, "The authored corners survive into the route the Guardian follows")

	# 没录过路的情况仍然要能开局，否则新检出第一次进大厅就没有引导。
	HallRouteStore.clear_route()
	var fallback: Array = hall.call(
		"_hall_route_points", Vector2(900.0, 700.0), Vector2(302.0, 87.0)
	)
	_expect(
		fallback.size() >= 2,
		"Without an authored route the Hall still falls back to pathfinding"
	)

	hall.queue_free()
	await process_frame


## 一条只能沿旧路线走的录制器是没用的：作者每次试图走对的那条路，都会被
## 牵引回错的那条。这是这个工具能不能用的分水岭，所以单独验。
func _check_recording_is_not_dragged_back() -> void:
	HallRouteStore.clear_route()
	var game_state := root.get_node("GameState")
	game_state.set("developer_mode", false)

	var packed := load("res://scenes/game_world.tscn") as PackedScene
	_expect(packed != null, "The Hall scene loads for the leash check")
	if packed == null:
		return
	var hall: Node = packed.instantiate()
	root.add_child(hall)
	for _frame: int in range(45):
		await process_frame

	var walker: Node2D = hall.get("player") as Node2D
	_expect(walker != null, "The Hall has a player to walk")
	if walker == null:
		hall.queue_free()
		await process_frame
		return

	# 进场对话、守卫入场特写等任何一个开着，_update_hall_tutorial_chase 都会
	# 提前返回，牵引根本不会跑——那样下面三条断言会在一个本就不牵引的状态上
	# 各自恒真，测试全绿而什么都没验。
	hall.set("dialogue_active", false)
	hall.set("guardian_entry_sequence_active", false)
	hall.set("guardian_near_miss_active", false)
	hall.set("game_over", false)
	hall.call("_begin_hall_arrival_route")
	await process_frame
	var route: Array = hall.get("hall_tutorial_route")
	_expect(route.size() >= 2, "A tutorial route exists to be leashed to")
	if route.size() < 2:
		hall.queue_free()
		await process_frame
		return

	var leash: float = float(hall.get("TUTORIAL_ROUTE_LEASH"))
	var far: Vector2 = (route[0] as Vector2) + Vector2(leash * 2.0, leash * 2.0)

	walker.global_position = far
	hall.call("_update_hall_tutorial_chase")
	await process_frame
	_expect(
		walker.global_position.distance_to(far) > 1.0,
		"Without developer mode, leaving the route still returns the player"
	)

	# 开启开发者模式即进入录制，牵引必须让开。
	game_state.set("developer_mode", true)
	hall.call("_sync_hall_route_recorder")
	await process_frame
	var recorder = hall.get("_hall_route_recorder")
	_expect(recorder != null, "Developer mode starts the route recorder")

	walker.global_position = far
	hall.call("_update_hall_tutorial_chase")
	await process_frame
	_expect(
		walker.global_position.distance_to(far) <= 1.0,
		"While recording, walking off the old route is not dragged back"
	)

	# 录完之后牵引要回来，否则正式玩家会失去这条保护。
	game_state.set("developer_mode", false)
	hall.call("_sync_hall_route_recorder")
	await process_frame
	walker.global_position = far
	hall.call("_update_hall_tutorial_chase")
	await process_frame
	_expect(
		walker.global_position.distance_to(far) > 1.0,
		"Leaving developer mode restores the leash for real players"
	)

	hall.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	HallRouteStore.clear_route()
	if failures.is_empty():
		print("hall_route_authoring_test: PASS")
		quit(0)
	else:
		printerr("hall_route_authoring_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
