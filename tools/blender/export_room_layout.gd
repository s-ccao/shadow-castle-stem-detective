extends SceneTree

## Exports a room's layout for the Blender room prototype
## (tools/blender/room_prototype.py): every collision polygon in world px,
## named for the node it belongs to (and the polygon's own name, "shape") and
## sorted into walls (StaticBody2D) and props (Area2D under Props/), each
## interactive prop's visible rect and focus point (as RoomSpatialRuntime reads
## them, so the HD props can be checked against them; a room whose props stand
## elsewhere lists them in "props"), the room's spawn points, its interaction
## items and herb plots where it has them, and a collision mask.
##
## A room run by RoomInteractionRuntime (the Circuit Room) keeps its props
## elsewhere: its spec lists them by node path ("props"), and with
## "furniture" each one's FurnitureCollision rectangle is exported as
## "furniture" and is solid in the mask. Its interaction items (switch plates
## and their contact bands) and the script constants its spec names
## ("constants": light fixtures, exit) go into "extras".
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
	# Its interactive props stand in Worldsort/ beside the player, not under
	# Props/; its herb beds are painted, listed only in INTERACT_ITEMS.
	"greenhouse_room": {
		"scene": "res://scenes/floor_1/greenhouse_room.tscn",
		"size": Vector2i(1024, 1536),
		"spawns": {
			"arrival": "PLAYER_SPAWN_POSITION",
			"exit": "EXIT_POSITION",
			"gardener": "GARDENER_POSITION",
		},
		"props": {
			"MagicPlanter": "Worldsort/MagicPlanter",
			"Workbench": "Worldsort/Workbench",
			"PlantPotsA": "Worldsort/PlantPotsA",
			"PlantPotsB": "Worldsort/PlantPotsB",
			"ArchDoor": "Worldsort/ArchDoor",
		},
		"items": "INTERACT_ITEMS",
		"plots": "HERB_PLOTS",
	},
	# A camera follows the player through it. Its props stand in Worldsort/;
	# the butler and Dr. Lin's memory echo are made by the script.
	"chemistry_room": {
		"scene": "res://scenes/floor_1/chemistry_room.tscn",
		"size": Vector2i(1305, 1206),
		"spawns": {
			"arrival": "PLAYER_SPAWN_POSITION",
			"exit": "EXIT_POSITION",
			"butler": "BUTLER_POSITION",
			"cabinet": "CABINET_INTERACTION_POSITION",
			"table": "ALCHEMY_TABLE_INTERACTION_POSITION",
			"red_stain": "RED_STAIN_POSITION",
		},
		"props": {
			"ChemistryLabTable": "Worldsort/ChemistryLabTable",
			"ChemistryPotionCabinet": "Worldsort/ChemistryPotionCabinet",
		},
	},
	# A camera follows the player through it. Its five props stand at the
	# room's root, each blocked by its own FurnitureCollision: rectangles, and
	# capsules for the analysis table and the Knowledge Engine (so
	# "capsule_shapes" exports those as walls too). The exit is EXIT_RECT.
	"final_room": {
		"scene": "res://scenes/floor_1/final_room.tscn",
		"size": Vector2i(1448, 1086),
		"spawns": {"arrival": "PLAYER_SPAWN_POSITION", "exit": "EXIT_POSITION"},
		"rects": {"exit": "EXIT_RECT"},
		"props": {
			"MrsLinBody": "MrsLinBody",
			"NotebookVisual": "NotebookVisual",
			"FinalAnalysisBoardVisual": "FinalAnalysisBoardVisual",
			"KnowledgeEngineVisual": "KnowledgeEngineVisual",
			"VaultDoorVisual": "VaultDoorVisual",
		},
		"items": "INTERACT_ITEMS",
		"rect_shapes": true,
		"capsule_shapes": true,
	},
	# A RoomInteractionRuntime room: its three props stand in Worldsort/, each
	# blocked by its own FurnitureCollision ("furniture"); its light rig's spots
	# and its exit are script constants ("constants").
	"circuit_room": {
		"scene": "res://scenes/floor_1/circuit_room.tscn",
		"size": Vector2i(1448, 1086),
		"spawns": {
			"arrival": "PLAYER_SPAWN_POSITION",
			"exit": "EXIT_POSITION",
			"mechanic": "MECHANIC_POSITION",
		},
		"props": {
			"Workbench": "Worldsort/Workbench",
			"Cabinet": "Worldsort/Cabinet",
			"Generator": "Worldsort/Generator",
		},
		"items": "INTERACT_ITEMS",
		"furniture": true,
		"constants": [
			"EXIT_RECT", "WALL_LAMP_POSITIONS", "BENCH_LANTERN_POSITION",
			"GENERATOR_CHAMBER_POSITION", "BROKEN_BUS_POSITION",
		],
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
			"name": str(owner_body.name), "shape": str(polygon.name),
			"path": str(room.get_path_to(owner_body)), "points": points,
		}
		if owner_body is StaticBody2D:
			walls.append(entry)
		elif owner_body is Area2D:
			props.append(entry)
	if bool(spec.get("rect_shapes", false)):
		walls.append_array(_rect_walls(room))
	if bool(spec.get("capsule_shapes", false)):
		walls.append_array(_capsule_walls(room))
	# Furniture a RoomInteractionRuntime room (the Circuit Room) blocks with a
	# rectangle on a StaticBody2D (its FurnitureCollision), as solid as the walls.
	var furniture: Array = []
	if bool(spec.get("furniture", false)):
		for node: Node in room.find_children("*", "CollisionShape2D", true, false):
			var shape_node := node as CollisionShape2D
			var body := shape_node.get_parent()
			if not (body is StaticBody2D) or not (shape_node.shape is RectangleShape2D):
				continue
			var extent := (shape_node.shape as RectangleShape2D).size * shape_node.global_scale.abs()
			var holder := body.get_parent()
			furniture.append({
				"name": str(holder.name), "path": str(room.get_path_to(holder)),
				"rect": _rect(Rect2(shape_node.global_position - extent * 0.5, extent)),
			})
	var spatial := RoomSpatialRuntime.new()
	var prop_info: Dictionary = {}
	for child: Node in _prop_nodes(room, spec):
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
	if spec.has("items"):
		extras["items"] = _items(room.get(str(spec["items"])))
	if spec.has("plots"):
		extras["plots"] = _items(constants.get(str(spec["plots"]), []))
	for rect_name: String in spec.get("rects", {}):
		var rect_value: Variant = constants.get(str(spec["rects"][rect_name]))
		if rect_value is Rect2:
			extras[rect_name + "_rect"] = _rect(rect_value)
	for constant: String in spec.get("constants", []):
		if not constants.has(constant):
			continue
		var value: Variant = constants[constant]
		if value is Vector2:
			extras[constant.to_lower()] = _point(value)
		elif value is Rect2:
			extras[constant.to_lower()] = _rect(value)
		elif value is Array:
			var points: Array = []
			for point: Variant in value:
				if point is Vector2:
					points.append(_point(point))
			extras[constant.to_lower()] = points
	var player := room.get_node_or_null("player") as Node2D
	if player == null:
		player = room.get_node_or_null("Worldsort/player") as Node2D
	var layout := {
		"generator": "tools/blender/export_room_layout.gd",
		"room": room_id,
		"scene": spec["scene"],
		"size": [size.x, size.y],
		"walls": walls,
		"props": props,
		"furniture": furniture,
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
	for block: Dictionary in furniture:
		var area: Array = block["rect"]
		mask.fill_rect(
			Rect2i(
				Vector2i(roundi(float(area[0])), roundi(float(area[1]))),
				Vector2i(roundi(float(area[2])), roundi(float(area[3])))
			).intersection(Rect2i(Vector2i.ZERO, size)),
			Color.WHITE
		)
	for y: int in size.y:
		for x: int in size.x:
			var point := Vector2(x + 0.5, y + 0.5)
			for shape: Dictionary in shapes:
				if Geometry2D.is_point_in_polygon(point, _packed(shape["points"])):
					mask.set_pixel(x, y, Color.WHITE)
					break
	mask.save_png(ProjectSettings.globalize_path(out_dir.path_join("collision.png")))
	print(
		"ROOM_LAYOUT %s: %d walls, %d prop shapes, %d furniture, %d props, %d items, %d spawns -> %s"
		% [
			room_id, walls.size(), props.size(), furniture.size(), prop_info.size(),
			(extras.get("items", []) as Array).size(), spawns.size(), out_dir,
		]
	)
	room.queue_free()
	await process_frame
	quit(0)


## Every rectangle a StaticBody2D blocks with (a prop's FurnitureCollision), as
## a wall polygon named for the body's parent, the prop it blocks for.
func _rect_walls(room: Node) -> Array:
	var walls: Array = []
	for node: Node in room.find_children("*", "CollisionShape2D", true, false):
		var shape := node as CollisionShape2D
		var body := shape.get_parent()
		if not body is StaticBody2D or not shape.shape is RectangleShape2D:
			continue
		var half := (shape.shape as RectangleShape2D).size / 2.0
		var points: Array = []
		var corners: Array[Vector2] = [
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y),
		]
		for corner: Vector2 in corners:
			var world := shape.global_transform * corner
			points.append([snappedf(world.x, 0.01), snappedf(world.y, 0.01)])
		walls.append({
			"name": str(body.get_parent().name), "shape": str(shape.name),
			"path": str(room.get_path_to(body)), "points": points,
		})
	return walls


## Every capsule a StaticBody2D blocks with (the Final Room's analysis table and
## Knowledge Engine), as a 32-point wall polygon named for the body's parent,
## in world px through its whole transform (a scaled sprite stretches it).
func _capsule_walls(room: Node) -> Array:
	var walls: Array = []
	for node: Node in room.find_children("*", "CollisionShape2D", true, false):
		var shape := node as CollisionShape2D
		var body := shape.get_parent()
		if not body is StaticBody2D or not shape.shape is CapsuleShape2D:
			continue
		var capsule := shape.shape as CapsuleShape2D
		var reach := maxf(capsule.height / 2.0 - capsule.radius, 0.0)
		var points: Array = []
		for step: int in range(32):
			var angle := TAU * (float(step) + 0.5) / 32.0
			var local := Vector2(cos(angle), sin(angle)) * capsule.radius
			local.y += reach if local.y > 0.0 else -reach
			var world := shape.global_transform * local
			points.append([snappedf(world.x, 0.01), snappedf(world.y, 0.01)])
		walls.append({
			"name": str(body.get_parent().name), "shape": str(shape.name),
			"path": str(room.get_path_to(body)), "points": points,
		})
	return walls


## The room's interactive props: the nodes its spec lists, or else Props/'s children.
func _prop_nodes(room: Node, spec: Dictionary) -> Array[Node]:
	var nodes: Array[Node] = []
	if spec.has("props"):
		for id: String in spec["props"]:
			var node := room.get_node_or_null(NodePath(str(spec["props"][id])))
			if node != null:
				nodes.append(node)
		return nodes
	var props_root := room.get_node_or_null("Props")
	if props_root != null:
		nodes.assign(props_root.get_children())
	return nodes


## A list of dictionaries (interaction items, herb plots) with every Vector2 and
## Rect2 written as px, and the strings and numbers as they are.
func _items(source: Variant) -> Array:
	var listed: Array = []
	if not source is Array:
		return listed
	for item: Variant in source:
		if not item is Dictionary:
			continue
		var entry: Dictionary = {}
		for key: Variant in item:
			var value: Variant = item[key]
			if value is Vector2:
				entry[str(key)] = _point(value)
			elif value is Rect2:
				entry[str(key)] = _rect(value)
			elif value is String or value is StringName or value is int or value is float:
				entry[str(key)] = value
		listed.append(entry)
	return listed


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
