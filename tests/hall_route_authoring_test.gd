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
var _shipped_digest_at_start: String = ""

const TEST_ROUTE_PATH: String = "user://test_hall_route.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 绝不碰发行文件：这条路线是人走出来的，删掉要重录几分钟，而删掉之后
	# 回归依旧是绿的——最贵的那种失败。
	_shipped_digest_at_start = _shipped_route_digest()
	HallRouteStore.use_test_path(TEST_ROUTE_PATH)
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("_loading_save", false)
	game_state.set("game_started", true)

	_check_store_roundtrip()
	await _check_recorder_captures_a_walk()
	await _check_tutorial_prefers_the_authored_route()
	await _check_recording_is_not_dragged_back()
	await _check_leaving_the_tracks_is_seen_not_silent()

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
	var file := FileAccess.open(TEST_ROUTE_PATH, FileAccess.WRITE)
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
	await _hold_off_route(hall, walker, far)
	_expect(
		walker.global_position.distance_to(far) > 1.0,
		"Without developer mode, staying off the route still returns the player"
	)

	# 开启开发者模式即进入录制，牵引必须让开。
	game_state.set("developer_mode", true)
	hall.call("_sync_hall_route_recorder")
	await process_frame
	var recorder = hall.get("_hall_route_recorder")
	_expect(recorder != null, "Developer mode starts the route recorder")

	walker.global_position = far
	await _hold_off_route(hall, walker, far)
	_expect(
		walker.global_position.distance_to(far) <= 1.0,
		"While recording, walking off the old route is never dragged back"
	)

	# 录完之后牵引要回来，否则正式玩家会失去这条保护。
	game_state.set("developer_mode", false)
	hall.call("_sync_hall_route_recorder")
	await process_frame
	walker.global_position = far
	await _hold_off_route(hall, walker, far)
	_expect(
		walker.global_position.distance_to(far) > 1.0,
		"Leaving developer mode restores the leash for real players"
	)

	hall.queue_free()
	await process_frame


## 离开踪迹的规则要能被学会，而不是只能被惩罚：先警告一拍，还站在外面才
## 拎回去。两头都会坏——宽限设成 0 就退回"看不见的边界"，宽限没上限就等于
## 没有规则——所以两头都验。
func _check_leaving_the_tracks_is_seen_not_silent() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("developer_mode", false)
	var packed := load("res://scenes/game_world.tscn") as PackedScene
	if packed == null:
		_expect(false, "The Hall scene loads for the exposure check")
		return
	var hall: Node = packed.instantiate()
	root.add_child(hall)
	for _frame: int in range(45):
		await process_frame

	hall.set("dialogue_active", false)
	hall.set("guardian_entry_sequence_active", false)
	hall.set("guardian_near_miss_active", false)
	hall.set("game_over", false)
	hall.call("_begin_hall_arrival_route")
	await process_frame

	var route: Array = hall.get("hall_tutorial_route")
	var walker: Node2D = hall.get("player") as Node2D
	_expect(route.size() >= 2 and walker != null, "A route and a player exist")
	if route.size() < 2 or walker == null:
		hall.queue_free()
		await process_frame
		return

	var leash: float = float(hall.get("TUTORIAL_ROUTE_LEASH"))
	var grace: float = float(hall.get("HALL_ROUTE_EXPOSURE_GRACE"))
	var far: Vector2 = (route[0] as Vector2) + Vector2(leash * 2.0, leash * 2.0)

	# 刚踏出去：只被警告，还站得住。
	walker.global_position = far
	hall.call("_tick_hall_route_exposure", true, grace * 0.4)
	await process_frame
	_expect(
		walker.global_position.distance_to(far) <= 1.0,
		"Stepping off the tracks warns before it moves the player"
	)
	_expect(
		float(hall.get("hall_route_exposure")) > 0.0,
		"Being off the tracks is tracked as exposure, not ignored"
	)

	# 自己走回来：暴露归零，不留惩罚。
	walker.global_position = route[0] as Vector2
	hall.call("_tick_hall_route_exposure", false, 0.1)
	await process_frame
	_expect(
		is_zero_approx(float(hall.get("hall_route_exposure"))),
		"Returning to the tracks clears the exposure"
	)

	# 一直站在外面：才被拎回踪迹。
	walker.global_position = far
	hall.call("_tick_hall_route_exposure", true, grace * 0.6)
	await process_frame
	hall.call("_tick_hall_route_exposure", true, grace * 0.6)
	await process_frame
	_expect(
		walker.global_position.distance_to(far) > 1.0,
		"Staying off the tracks past the grace window returns the player"
	)

	# 守卫在路旁，不在路上——否则脚印看起来就不安全了。
	var side: Vector2 = hall.call("_hall_route_side_offset", 0)
	_expect(
		side.length() > 0.9,
		"The Guardian has a side to stand on beside the tracks"
	)

	hall.queue_free()
	await process_frame


## 站在踪迹外不动，直到超过宽限窗口。离开踪迹不再是立刻被拉回——先警告，
## 还在外面才动你——所以驱动一帧是不够的。
func _hold_off_route(hall: Node, walker: Node2D, spot: Vector2) -> void:
	var grace: float = float(hall.get("HALL_ROUTE_EXPOSURE_GRACE"))
	var elapsed: float = 0.0
	while elapsed <= grace + 0.4:
		if walker.global_position.distance_to(spot) > 1.0:
			return
		walker.global_position = spot
		hall.call("_update_hall_tutorial_chase")
		elapsed += maxf(hall.get_process_delta_time(), 0.016)
		await process_frame


## 发行路线文件的指纹。不存在也是一种状态，要能和"被删掉了"区分开。
func _shipped_route_digest() -> String:
	if not FileAccess.file_exists(HallRouteStore.ROUTE_PATH):
		return "<absent>"
	return FileAccess.get_file_as_string(HallRouteStore.ROUTE_PATH).sha256_text()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	HallRouteStore.clear_route()
	HallRouteStore.clear_test_path()
	# 这条断言是给这个测试自己看的：它曾经写在发行路径上，跑一次回归就把
	# 作者刚走出来的路线删了，而回归照样全绿。所以收尾时必须确认发行文件
	# 和进来时一模一样。
	_expect(
		_shipped_route_digest() == _shipped_digest_at_start,
		"The test left the shipped route untouched"
	)
	if failures.is_empty():
		print("hall_route_authoring_test: PASS")
		quit(0)
	else:
		printerr("hall_route_authoring_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
