extends SceneTree

## Exports a room's layout for the Blender room prototype
## (tools/blender/room_prototype.py): every collision polygon in world px,
## named for the node it belongs to and sorted into walls (StaticBody2D) and
## props (Area2D under Props/), each prop's visible rect and focus point (as
## RoomSpatialRuntime reads them, so the HD props can be checked against
## them), the room's spawn points, and a collision mask.
##
##   HOME="$PWD/.godot/blender-proto-home" godot --headless --path . \
##     --script res://tools/blender/export_room_layout.gd \
##     -- --room=wake_room --out=res://prototypes/blender_rooms/wake_room/
##
## Writes layout.json and collision.png (L8, 1 px per world px, 255 = solid).

const ROOMS: Dictionary = {
	"wake_room": {
		"scene": "res://scenes/wake_room.tscn",
		"size": Vector2i(1024, 768),
		"spawns": {
			"first_arrival": "WAKE_BEDSIDE_SPAWN",
			"first_step": "WAKE_FIRST_STEP_TARGET",
		},
		"fixed_spawns": {"return": Vector2(500.0, 550.0)},
	},
}

var room_id := "wake_room"
var out_dir := ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--room="):
			room_id = argument.trim_prefix("--room=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	if out_dir.is_empty():
		out_dir = "res://prototypes/blender_rooms/%s/" % room_id
	call_deferred("_run")


func _run() -> void:
	if not ROOMS.has(room_id):
		printerr("Unknown room: " + room_id)
		quit(2)
		return
	var spec: Dictionary = ROOMS[room_id]
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("_loading_save", false)
	game_state.set("game_started", true)
	var room := (load(str(spec["scene"])) as PackedScene).instantiate()
	root.add_child(room)
	for _frame: int in range(6):
		await process_frame
	var size: Vector2i = spec["size"]
	var walls: Array = []
	var props: Array = []
	for node: Node in room.find_children("*", "CollisionPolygon2D", true, false):
		var polygon := node as CollisionPolygon2D
		var owner_body := polygon.get_parent()
		var points: Array = []
		for point: Vector2 in polygon.polygon:
			var world := polygon.global_transform * point
			points.append([snappedf(world.x, 0.01), snappedf(world.y, 0.01)])
		var entry := {
			"name": str(owner_body.name), "path": str(room.get_path_to(owner_body)), "points": points,
		}
		if owner_body is StaticBody2D:
			walls.append(entry)
		elif owner_body is Area2D:
			props.append(entry)
	var spatial := RoomSpatialRuntime.new()
	var props_root := room.get_node_or_null("Props")
	var prop_info: Dictionary = {}
	if props_root != null:
		for child: Node in props_root.get_children():
			if not child is Node2D:
				continue
			var rect := spatial.get_visual_rect(child)
			var focus := child.get_node_or_null("InteractionFocusPoint") as Node2D
			var visual := spatial.find_visual_node(child)
			prop_info[str(child.name)] = {
				"path": str(room.get_path_to(child)),
				"visual_path": str(room.get_path_to(visual)) if visual != null else "",
				"rect": _rect(rect),
				"focus": _point(focus.global_position) if focus != null else null,
			}
	var spawns: Dictionary = {}
	var script := room.get_script() as GDScript
	var constants: Dictionary = script.get_script_constant_map() if script != null else {}
	for spawn: String in spec.get("spawns", {}):
		var constant := str(spec["spawns"][spawn])
		if constants.has(constant):
			spawns[spawn] = _point(constants[constant] as Vector2)
	for spawn: String in spec.get("fixed_spawns", {}):
		spawns[spawn] = _point(spec["fixed_spawns"][spawn] as Vector2)
	var extras: Dictionary = {}
	for property: String in [
		"door_position", "clue_interaction_rect", "clue_approach_position", "window_position",
	]:
		var value: Variant = room.get(property)
		if value is Vector2:
			extras[property] = _point(value)
		elif value is Rect2:
			extras[property] = _rect(value)
	var door_rect: Variant = room.get("door_interaction_rect")
	if door_rect is Rect2:
		extras["door_interaction_rect"] = _rect(door_rect)
	var player := room.get_node_or_null("player") as Node2D
	var layout := {
		"generator": "tools/blender/export_room_layout.gd",
		"room": room_id,
		"scene": spec["scene"],
		"size": [size.x, size.y],
		"walls": walls,
		"props": props,
		"prop_info": prop_info,
		"spawns": spawns,
		"extras": extras,
		"player_visual_scale": (
			_point((player.get_node("VisualRoot") as Node2D).scale) if player != null else null
		),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var file := FileAccess.open(out_dir.path_join("layout.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "\t"))
	file.close()
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	var shapes: Array = walls + props
	for y: int in size.y:
		for x: int in size.x:
			var point := Vector2(x + 0.5, y + 0.5)
			for shape: Dictionary in shapes:
				if Geometry2D.is_point_in_polygon(point, _packed(shape["points"])):
					mask.set_pixel(x, y, Color.WHITE)
					break
	mask.save_png(ProjectSettings.globalize_path(out_dir.path_join("collision.png")))
	print(
		"ROOM_LAYOUT %s: %d walls, %d prop shapes, %d props, %d spawns -> %s"
		% [room_id, walls.size(), props.size(), prop_info.size(), spawns.size(), out_dir]
	)
	room.queue_free()
	await process_frame
	quit(0)


func _packed(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point: Array in points:
		packed.append(Vector2(float(point[0]), float(point[1])))
	return packed


func _point(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


func _rect(value: Rect2) -> Array:
	return [
		snappedf(value.position.x, 0.01), snappedf(value.position.y, 0.01),
		snappedf(value.size.x, 0.01), snappedf(value.size.y, 0.01),
	]
