extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 32
const MAP_HEIGHT := 24
const MAP_PIXEL_WIDTH := MAP_WIDTH * CELL_SIZE
const MAP_PIXEL_HEIGHT := MAP_HEIGHT * CELL_SIZE

# Fog uses smaller cells than the wall grid.
# Walls are 32x32, but fog is 16x16, so the light looks more circular.
const FOG_CELL_SIZE := 16
const FOG_COLS := MAP_PIXEL_WIDTH / FOG_CELL_SIZE
const FOG_ROWS := MAP_PIXEL_HEIGHT / FOG_CELL_SIZE

const VISION_RADIUS_PIXELS := 210.0
const CLEAR_RADIUS_PIXELS := 90.0
const EDGE_DARKNESS := 0.62
const DISCOVERED_DARKNESS := 0.68

@onready var player = $player

var wall_cells := {}
var fog_cells := {}
var discovered_fog_cells := {}
var visible_fog_cells := {}
var visible_fog_distances := {}


func _ready():
	create_floor()
	create_castle_walls()
	create_fog_cells()
	move_player_to_cell(Vector2i(2, 2))


func _process(delta):
	update_fog_of_war()


func create_floor():
	var floor = ColorRect.new()
	floor.color = Color(0.12, 0.12, 0.14)
	floor.size = Vector2(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)
	floor.z_index = -10
	add_child(floor)


func create_castle_walls():
	# Border walls
	for x in range(MAP_WIDTH):
		add_wall_cell(Vector2i(x, 0))
		add_wall_cell(Vector2i(x, MAP_HEIGHT - 1))

	for y in range(MAP_HEIGHT):
		add_wall_cell(Vector2i(0, y))
		add_wall_cell(Vector2i(MAP_WIDTH - 1, y))

	# Interior castle maze walls
	add_wall_rect(Vector2i(6, 1), Vector2i(6, 8))
	add_wall_rect(Vector2i(12, 3), Vector2i(12, 14))
	add_wall_rect(Vector2i(20, 2), Vector2i(20, 10))
	add_wall_rect(Vector2i(26, 6), Vector2i(26, 18))

	add_wall_rect(Vector2i(3, 5), Vector2i(10, 5))
	add_wall_rect(Vector2i(14, 8), Vector2i(23, 8))
	add_wall_rect(Vector2i(2, 12), Vector2i(9, 12))
	add_wall_rect(Vector2i(16, 15), Vector2i(27, 15))
	add_wall_rect(Vector2i(8, 19), Vector2i(22, 19))


func add_wall_rect(start_cell: Vector2i, end_cell: Vector2i):
	for y in range(start_cell.y, end_cell.y + 1):
		for x in range(start_cell.x, end_cell.x + 1):
			add_wall_cell(Vector2i(x, y))


func add_wall_cell(cell: Vector2i):
	var key = cell_key(cell)

	if wall_cells.has(key):
		return

	wall_cells[key] = true

	var wall = StaticBody2D.new()
	wall.name = "Wall"
	wall.position = cell_to_world(cell)

	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rectangle
	wall.add_child(shape)

	var visual = ColorRect.new()
	visual.color = Color(0.22, 0.18, 0.28)
	visual.size = Vector2(CELL_SIZE, CELL_SIZE)
	visual.position = Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2)
	wall.add_child(visual)

	add_child(wall)


func create_fog_cells():
	for y in range(FOG_ROWS):
		for x in range(FOG_COLS):
			var fog_cell = Vector2i(x, y)

			var fog = ColorRect.new()
			fog.name = "Fog"
			fog.position = Vector2(x * FOG_CELL_SIZE, y * FOG_CELL_SIZE)
			fog.size = Vector2(FOG_CELL_SIZE, FOG_CELL_SIZE)
			fog.color = Color(0.0, 0.0, 0.0, 1.0)
			fog.z_index = 100
			fog.mouse_filter = Control.MOUSE_FILTER_IGNORE

			add_child(fog)
			fog_cells[fog_key(fog_cell)] = fog


func update_fog_of_war():
	visible_fog_cells.clear()
	visible_fog_distances.clear()

	var player_world = player.global_position

	var min_x = int(max(0, (player_world.x - VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var max_x = int(min(FOG_COLS - 1, (player_world.x + VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var min_y = int(max(0, (player_world.y - VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))
	var max_y = int(min(FOG_ROWS - 1, (player_world.y + VISION_RADIUS_PIXELS) / FOG_CELL_SIZE))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var fog_cell = Vector2i(x, y)
			var target_world = fog_cell_to_world_center(fog_cell)
			var distance = player_world.distance_to(target_world)

			if distance > VISION_RADIUS_PIXELS:
				continue

			if has_world_line_of_sight(player_world, target_world):
				var key = fog_key(fog_cell)
				visible_fog_cells[key] = true
				visible_fog_distances[key] = distance
				discovered_fog_cells[key] = true

	update_fog_visuals()


func update_fog_visuals():
	for key in fog_cells.keys():
		var fog = fog_cells[key]

		if visible_fog_cells.has(key):
			var distance = visible_fog_distances[key]

			var edge_amount = 0.0
			if distance > CLEAR_RADIUS_PIXELS:
				edge_amount = (distance - CLEAR_RADIUS_PIXELS) / (VISION_RADIUS_PIXELS - CLEAR_RADIUS_PIXELS)
				edge_amount = clamp(edge_amount, 0.0, 1.0)

			var alpha = edge_amount * EDGE_DARKNESS
			fog.color = Color(0.0, 0.0, 0.0, alpha)

		elif discovered_fog_cells.has(key):
			fog.color = Color(0.0, 0.0, 0.0, DISCOVERED_DARKNESS)

		else:
			fog.color = Color(0.0, 0.0, 0.0, 1.0)


func has_world_line_of_sight(start_world: Vector2, end_world: Vector2) -> bool:
	var target_map_cell = world_to_cell(end_world)

	var direction = end_world - start_world
	var distance = direction.length()

	if distance <= 0.0:
		return true

	direction = direction.normalized()

	# Smaller step = more accurate wall blocking.
	# 4 pixels is accurate enough for this prototype.
	var step_size := 4.0
	var steps = int(distance / step_size)

	for i in range(1, steps + 1):
		var sample_point = start_world + direction * float(i) * step_size
		var sample_cell = world_to_cell(sample_point)

		if not is_inside_map(sample_cell):
			return false

		if is_wall(sample_cell):
			# The wall itself can be seen.
			# But anything behind the wall cannot be seen.
			return sample_cell == target_map_cell

	return true


func is_wall(cell: Vector2i) -> bool:
	return wall_cells.has(cell_key(cell))


func is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT


func move_player_to_cell(cell: Vector2i):
	player.position = cell_to_world(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2,
		cell.y * CELL_SIZE + CELL_SIZE / 2
	)


func fog_cell_to_world_center(fog_cell: Vector2i) -> Vector2:
	return Vector2(
		fog_cell.x * FOG_CELL_SIZE + FOG_CELL_SIZE / 2,
		fog_cell.y * FOG_CELL_SIZE + FOG_CELL_SIZE / 2
	)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / CELL_SIZE),
		int(world_position.y / CELL_SIZE)
	)


func cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)


func fog_key(fog_cell: Vector2i) -> String:
	return str(fog_cell.x) + "," + str(fog_cell.y)
