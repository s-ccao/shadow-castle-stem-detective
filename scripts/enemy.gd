extends CharacterBody2D

@export var speed: float = 95.0
@export var repath_interval: float = 0.35

var game_world: Node = null
var player: Node2D = null

var path: Array = []
var path_index: int = 0
var repath_timer: float = 0.0


func setup(world: Node, target_player: Node2D):
	game_world = world
	player = target_player
	repath_timer = 0.0


func _physics_process(delta):
	if game_world == null or player == null:
		return

	if game_world.game_over or game_world.dialogue_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	repath_timer -= delta
	if repath_timer <= 0.0:
		update_path()
		repath_timer = repath_interval

	move_along_path()
	check_player_collision()


func update_path():
	var start_cell = game_world.world_to_cell(global_position)
	var end_cell = game_world.world_to_cell(player.global_position)

	path = game_world.find_path(start_cell, end_cell)

	if path.size() > 1:
		path_index = 1
	else:
		path_index = 0


func move_along_path():
	if path.size() == 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if path_index >= path.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target_position = game_world.cell_to_world(path[path_index])
	var direction = target_position - global_position

	if direction.length() < 4.0:
		path_index += 1
		return

	velocity = direction.normalized() * speed
	move_and_slide()


func check_player_collision():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			print("Player caught by physical collision!")
			game_world.on_player_caught()
			return
