extends Node2D

const CELL_SIZE := 32
const MAP_WIDTH := 32
const MAP_HEIGHT := 24

@onready var player = $player

var wall_cells := {}

func _ready():
	create_floor()
	create_castle_walls()
	move_player_to_cell(Vector2i(2, 2))


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
	var key = str(cell.x) + "," + str(cell.y)

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


func move_player_to_cell(cell: Vector2i):
	player.position = cell_to_world(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2,
		cell.y * CELL_SIZE + CELL_SIZE / 2
	)
