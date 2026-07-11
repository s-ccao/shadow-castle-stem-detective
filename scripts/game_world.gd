extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 32
const MAP_HEIGHT := 24

const VISION_RADIUS := 6.5
const CLEAR_RADIUS := 3.0
const EDGE_DARKNESS := 0.55

@onready var player = $player

var wall_cells := {}
var fog_cells := {}
var discovered_cells := {}
var visible_cells := {}
var visible_distances := {}


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
	floor.size = Vector2(MAP_WIDTH * CELL_SIZE, MAP_HEIGHT * CELL_SIZE)
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
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var cell = Vector2i(x, y)

			var fog = ColorRect.new()
			fog.name = "Fog"
			fog.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			fog.size = Vector2(CELL_SIZE, CELL_SIZE)
			fog.color = Color(0.0, 0.0, 0.0, 1.0)
			fog.z_index = 100
			fog.mouse_filter = Control.MOUSE_FILTER_IGNORE

			add_child(fog)
			fog_cells[cell_key(cell)] = fog


func update_fog_of_war():
	visible_cells.clear()
	visible_distances.clear()

	var player_cell = world_to_cell(player.position)

	for y in range(player_cell.y - int(VISION_RADIUS) - 1, player_cell.y + int(VISION_RADIUS) + 2):
		for x in range(player_cell.x - int(VISION_RADIUS) - 1, player_cell.x + int(VISION_RADIUS) + 2):
			var target_cell = Vector2i(x, y)

			if not is_inside_map(target_cell):
				continue

			var distance = player_cell.distance_to(target_cell)

			if distance > VISION_RADIUS:
				continue

			if has_line_of_sight(player_cell, target_cell):
				var key = cell_key(target_cell)
				visible_cells[key] = true
				visible_distances[key] = distance
				discovered_cells[key] = true

	update_fog_visuals()


func update_fog_visuals():
	for key in fog_cells.keys():
		var fog = fog_cells[key]

		if visible_cells.has(key):
			var distance = visible_distances[key]

			var edge_amount = 0.0
			if distance > CLEAR_RADIUS:
				edge_amount = (distance - CLEAR_RADIUS) / (VISION_RADIUS - CLEAR_RADIUS)
				edge_amount = clamp(edge_amount, 0.0, 1.0)

			var alpha = edge_amount * EDGE_DARKNESS

			fog.color = Color(0.0, 0.0, 0.0, alpha)

		elif discovered_cells.has(key):
			# 以前看过，但现在不在视野里
			fog.color = Color(0.0, 0.0, 0.0, 0.65)

		else:
			# 从未探索过
			fog.color = Color(0.0, 0.0, 0.0, 1.0)


func has_line_of_sight(start_cell: Vector2i, end_cell: Vector2i) -> bool:
	var cells_on_line = get_line_cells(start_cell, end_cell)

	for cell in cells_on_line:
		if cell == start_cell:
			continue

		# 墙本身可以被看见，但墙后面的格子不能被看见
		if is_wall(cell):
			return cell == end_cell

	return true


func get_line_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	var x0 = start_cell.x
	var y0 = start_cell.y
	var x1 = end_cell.x
	var y1 = end_cell.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		cells.append(Vector2i(x0, y0))

		if x0 == x1 and y0 == y1:
			break

		var e2 = 2 * err

		if e2 > -dy:
			err -= dy
			x0 += sx

		if e2 < dx:
			err += dx
			y0 += sy

	return cells


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


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / CELL_SIZE),
		int(world_position.y / CELL_SIZE)
	)


func cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)
