extends SceneTree

## Exports the Castle Hall layout for the Blender 3D prototype
## (tools/blender/hall_prototype.py): the real wall collision of the whole map
## rasterized on the collision's own 4 world-px grid, which floor is outside the
## castle (transparent in the floor art), and the spawn, doors, exhibits and
## opening route. `--region` is the part the prototype renders; geometry around
## it still casts its shadows in.
##
##   HOME="$PWD/.godot/blender-proto-home" godot --headless --path . \
##     --script res://tools/blender/export_hall_region.gd \
##     -- --region=0,768,1024,512 --out=res://prototypes/blender_hall/
##
## Writes wall_mask.png and outside_mask.png (L8, 1 px per world px, 255 =
## wall / outside) and region.json.

const CELL := 4
const FLOOR_ART := "res://assets/backgrounds/hall_floor_bg.png"
## The floor art is 1536x1024 drawn x1.25 over the 1920x1280 map.
const FLOOR_ART_SCALE := 1.25
const DOOR_CONSTANTS: Array[String] = [
	"WAKE_ROOM_DOOR_FOCUS_POSITION",
	"CHEMISTRY_ROOM_DOOR_FOCUS_POSITION",
	"GREENHOUSE_ROOM_DOOR_FOCUS_POSITION",
	"CIRCUIT_DOOR_FOCUS_POSITION",
	"LIBRARY_DOOR_FOCUS_POSITION",
	"DINING_HALL_DOOR_FOCUS_POSITION",
	"FINAL_ROOM_DOOR_FOCUS_POSITION",
]

var region := Rect2i(0, 768, 1024, 512)
var out_dir := "res://prototypes/blender_hall/"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--region="):
			var parts := argument.trim_prefix("--region=").split(",")
			region = Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	if region.position.x % CELL != 0 or region.position.y % CELL != 0 \
			or region.size.x % CELL != 0 or region.size.y % CELL != 0:
		printerr("Region must lie on the collision's %d px grid." % CELL)
		quit(2)
		return
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("_loading_save", false)
	game_state.set("game_started", true)
	game_state.call("grant_wake_room_toolkit")
	game_state.call("add_key", "wake_room_key")
	game_state.set("return_spawn_id", "wake_room_first_arrival")
	var hall := (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	hall.set("guardian_entry_sequence_played", true)
	root.add_child(hall)
	current_scene = hall
	for _frame: int in range(4):
		await physics_frame
	var walls := hall.get_node("WallCollisions")
	var directory := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var map_size := Vector2i(
		int(hall.get("MAP_PIXEL_WIDTH")), int(hall.get("MAP_PIXEL_HEIGHT"))
	)
	var raster := _rasterize_walls(hall, walls, map_size)
	(raster["image"] as Image).save_png(directory.path_join("wall_mask.png"))
	_outside_mask(map_size).save_png(directory.path_join("outside_mask.png"))
	var metadata := _metadata(hall)
	metadata["wall_cells"] = raster["wall_cells"]
	var file := FileAccess.open(directory.path_join("region.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("EXPORTED map %s, region %s -> %s (wall cells %d of %d)" % [
		map_size, region, directory, int(raster["wall_cells"]),
		(map_size.x / CELL) * (map_size.y / CELL),
	])
	quit(0)


## One query per collision cell centre. Only bodies under WallCollisions
## count: the player, the Guardian and interaction areas are not wall.
func _rasterize_walls(hall: Node2D, walls: Node, map_size: Vector2i) -> Dictionary:
	var space := hall.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_L8)
	image.fill(Color.BLACK)
	var wall_cells := 0
	for row: int in range(map_size.y / CELL):
		for column: int in range(map_size.x / CELL):
			query.position = Vector2(column * CELL + CELL * 0.5, row * CELL + CELL * 0.5)
			for hit: Dictionary in space.intersect_point(query, 8):
				var collider := hit["collider"] as Node
				if collider is StaticBody2D and walls.is_ancestor_of(collider):
					image.fill_rect(Rect2i(column * CELL, row * CELL, CELL, CELL), Color.WHITE)
					wall_cells += 1
					break
	return {"image": image, "wall_cells": wall_cells}


## Floor the art leaves transparent is outside the castle: the void past the
## outer walls, which the game shows as black.
func _outside_mask(map_size: Vector2i) -> Image:
	var art := Image.load_from_file(ProjectSettings.globalize_path(FLOOR_ART))
	art.convert(Image.FORMAT_RGBA8)
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_L8)
	image.fill(Color.BLACK)
	for row: int in range(map_size.y / CELL):
		for column: int in range(map_size.x / CELL):
			var source := Vector2i(
				Vector2(column * CELL + CELL * 0.5, row * CELL + CELL * 0.5) / FLOOR_ART_SCALE
			)
			source = source.clamp(Vector2i.ZERO, art.get_size() - Vector2i.ONE)
			if art.get_pixelv(source).a < 0.5:
				image.fill_rect(Rect2i(column * CELL, row * CELL, CELL, CELL), Color.WHITE)
	return image


func _metadata(hall: Node2D) -> Dictionary:
	var constants := (hall.get_script() as GDScript).get_script_constant_map()
	var doors := {}
	# The rect each door's prompt is centred on (get_interaction_rect): the
	# builder draws a door on the side of its wall the player can use it from.
	var door_prompts := {}
	for constant: String in DOOR_CONSTANTS:
		if constants.has(constant):
			doors[constant] = _point(constants[constant] as Vector2)
			var prompt: Rect2 = hall.call(
				"get_interaction_rect", constant.trim_suffix("_FOCUS_POSITION").to_lower()
			)
			if prompt.has_area():
				door_prompts[constant] = [
					prompt.position.x, prompt.position.y, prompt.size.x, prompt.size.y
				]
	var exhibits := {}
	var spatial := RoomSpatialRuntime.new()
	for exhibit: Node in hall.get_node("WallCollisions/KnowledgeExhibits").get_children():
		var rect := spatial.get_visual_rect(exhibit)
		exhibits[exhibit.name] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	# Every prop the game sorts against the player: the Blender builder cuts a
	# niche for any that stands inside a wall, and the preview hides what a
	# nearer wall covers of each.
	var props := {}
	for path: NodePath in constants.get("HALL_OCCLUSION_NODE_PATHS", []):
		var prop := hall.get_node_or_null(path)
		if prop == null:
			continue
		var rect := spatial.get_visual_rect(prop)
		props[prop.name] = {
			"path": str(path), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		}
	var route: Array = []
	for point: Vector2 in hall.get("hall_tutorial_route"):
		route.append(_point(point))
	return {
		"generator": "tools/blender/export_hall_region.gd",
		"region": [region.position.x, region.position.y, region.size.x, region.size.y],
		"cell": CELL,
		"map_size": [int(constants["MAP_PIXEL_WIDTH"]), int(constants["MAP_PIXEL_HEIGHT"])],
		"spawn": _point((hall.get_node("player") as Node2D).global_position),
		"doors": doors,
		"door_prompts": door_prompts,
		"exhibits": exhibits,
		"props": props,
		"opening_route": route,
	}


func _point(point: Vector2) -> Array:
	return [snappedf(point.x, 0.01), snappedf(point.y, 0.01)]
