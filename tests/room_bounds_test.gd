extends SceneTree

## The detective must not walk out of a room. The Library's and the Circuit
## Room's doorways once ran off the bottom of the room, so a player could walk
## down the steps, along the outside of the south wall and into the void. This
## flood-fills, in the Hall and every room, the floor the detective's body can
## reach from where it arrives, and fails on any of it outside the room.
##
## A south doorway is wall, not floor: its door is drawn standing in it, so floor
## there stands the detective on the door. In each room of `DOORWAYS` the feet
## must stop at the jambs' wall line, and the exit must still be in reach there.
##
##   HOME="$PWD/.godot/room-bounds-test/home" godot --headless --path . \
##     --script res://tests/room_bounds_test.gd [-- --hd]

const SCENES: Array[Array] = [
	["res://scenes/game_world.tscn", "floor_1_hub"],
	["res://scenes/wake_room.tscn", "wake_room"],
	["res://scenes/floor_1/chemistry_room.tscn", "chemistry_room"],
	["res://scenes/floor_1/greenhouse_room.tscn", "greenhouse_room"],
	["res://scenes/floor_1/library_room.tscn", "library"],
	["res://scenes/floor_1/dining_hall_room.tscn", "dining_hall"],
	["res://scenes/floor_1/circuit_room.tscn", "circuit_room"],
	["res://scenes/floor_1/final_room.tscn", "final_deduction_room"],
]
## The detective's body is 14 x 8 px: an 8 px lattice cannot step over a gap
## it fits through.
const STEP := 8
## A room without camera limits fills one screen.
const SCREEN := Rect2(0.0, 0.0, 1024.0, 768.0)
## Each south doorway: the gap between its jambs in x, and the line where its
## door begins, which the detective's feet may touch but not cross. That is the
## jambs' wall line, or for the Circuit Room's gate the back of the alcove
## between its jambs.
const DOORWAYS: Dictionary = {
	"library": {"span": Vector2(659.0, 755.0), "wall_y": 940.0},
	"dining_hall": {"span": Vector2(658.0, 795.0), "wall_y": 971.0},
	"circuit_room": {"span": Vector2(635.0, 762.0), "wall_y": 936.0},
}

var failures: Array[String] = []
var spatial := RoomSpatialRuntime.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var isolated := ProjectSettings.globalize_path("res://.godot/")
	if not OS.get_user_data_dir().begins_with(isolated):
		printerr("room_bounds_test loads rooms, which may save: run it with HOME under " + isolated)
		quit(2)
		return
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.game_started = true
	for entry: Array in SCENES:
		await _check_room(game_state, str(entry[0]), str(entry[1]))
	game_state.game_started = false
	game_state.set("_loading_save", false)
	_finish()


func _check_room(game_state: Node, scene_path: String, room_id: String) -> void:
	game_state.set("current_room_id", room_id)
	var room := (load(scene_path) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for _frame: int in range(3):
		await process_frame
	await physics_frame
	await physics_frame
	var player := room.get_node_or_null("player") as CharacterBody2D
	if player == null:
		player = room.find_child("player", true, false) as CharacterBody2D
	if player == null:
		_fail("%s has a player to walk" % room_id)
	else:
		player.set_physics_process(false)
		_check_reach(player, room_id, room)
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame


func _check_reach(player: CharacterBody2D, room_id: String, room: Node) -> void:
	var bounds := _room_bounds(player)
	var start := Vector2i(
		int(player.global_position.x) / STEP * STEP, int(player.global_position.y) / STEP * STEP
	)
	_expect(
		spatial.is_position_clear(player, Vector2(start), 0.0),
		"%s: the detective arrives on open floor (%s)" % [room_id, start]
	)
	# Past a step outside the room is already a failure: the fill stops there.
	var limit := bounds.grow(STEP * 2)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var outside: Array[Vector2i] = []
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if not bounds.has_point(Vector2(cell)):
			outside.append(cell)
		for offset: Vector2i in [
			Vector2i(STEP, 0), Vector2i(-STEP, 0), Vector2i(0, STEP), Vector2i(0, -STEP)
		]:
			var next := cell + offset
			if seen.has(next) or not limit.has_point(Vector2(next)):
				continue
			seen[next] = true
			if spatial.is_position_clear(player, Vector2(next), 0.0):
				queue.append(next)
	_expect(
		outside.is_empty(),
		"%s: no floor the detective can reach lies outside the room %s (%d of %d spots; first %s)"
		% [room_id, bounds, outside.size(), queue.size(), outside.slice(0, 3)]
	)
	_check_doorway(player, room_id, room, queue)


func _check_doorway(
	player: CharacterBody2D, room_id: String, room: Node, reached: Array[Vector2i]
) -> void:
	if not DOORWAYS.has(room_id):
		return
	var doorway := DOORWAYS[room_id] as Dictionary
	var span := doorway["span"] as Vector2
	var wall_y := float(doorway["wall_y"])
	var body := spatial.get_player_collision_rect(player)
	var offset := body.position - player.global_position
	var exit_rect := room.get_script().get_script_constant_map().get("EXIT_RECT", Rect2()) as Rect2
	var deepest := -INF
	var at_exit := false
	for cell: Vector2i in reached:
		var feet := Rect2(Vector2(cell) + offset, body.size)
		if feet.end.x > span.x and feet.position.x < span.y:
			deepest = maxf(deepest, feet.end.y)
		if spatial.rect_gap(feet, exit_rect) <= RoomSpatialRuntime.DEFAULT_INTERACTION_MARGIN:
			at_exit = true
	_expect(
		deepest <= wall_y,
		"%s: the detective stops at the doorway's wall line, not on the door (feet reach y %d, wall %d)"
		% [room_id, int(deepest), int(wall_y)]
	)
	_expect(
		at_exit, "%s: the detective can still reach the exit %s at the door" % [room_id, exit_rect]
	)


## The room's extent: the limits of the camera that follows the detective (a
## shot, such as the HD Library's establishing one, may be the current camera
## for a while), or one screen for a room without them.
func _room_bounds(player: CharacterBody2D) -> Rect2:
	var cameras: Array[Node] = player.find_children("*", "Camera2D", true, false)
	var current := player.get_viewport().get_camera_2d()
	if current != null:
		cameras.append(current)
	for node: Node in cameras:
		var camera := node as Camera2D
		if camera.limit_right < 100000 and camera.limit_bottom < 100000:
			return Rect2(
				camera.limit_left, camera.limit_top,
				camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top
			)
	return SCREEN


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(description: String) -> void:
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("room_bounds_test: PASS")
		quit(0)
		return
	printerr("room_bounds_test: FAIL (%d issue(s))" % failures.size())
	quit(1)
