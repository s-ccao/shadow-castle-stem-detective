extends CharacterBody2D

@export var display_name: String = "Castle Guardian"
@export var speed: float = 95.0
@export var repath_interval: float = 0.35

var game_world: Node = null
var player: Node2D = null

var path: Array = []
var path_index: int = 0
var repath_timer: float = 0.0
var facing_direction: Vector2 = Vector2.DOWN
@onready var guardian_sprite: AnimatedSprite2D = $GuardianCore


func setup(world: Node, target_player: Node2D):
	game_world = world
	player = target_player
	repath_timer = 0.0


func _physics_process(delta):
	if game_world == null or player == null:
		return

	if game_world.game_over or game_world.dialogue_active:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
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
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if path_index >= path.size():
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	var target_position = game_world.cell_to_world(path[path_index])
	var direction = target_position - global_position

	if direction.length() < 4.0:
		path_index += 1
		_update_animation(Vector2.ZERO)
		return

	# 追逐模式：疯狂加速（速度大幅提升）。
	var move_speed: float = speed
	if GameState.chase_mode:
		move_speed = speed * 3.5

	velocity = direction.normalized() * move_speed
	_update_animation(velocity)
	move_and_slide()


func _update_animation(movement_velocity: Vector2) -> void:
	if guardian_sprite == null:
		return
	if movement_velocity.length_squared() > 1.0:
		facing_direction = movement_velocity.normalized()
	var animation: StringName = _walk_animation_name()
	if guardian_sprite.animation != animation:
		guardian_sprite.play(animation)
	elif not guardian_sprite.is_playing():
		guardian_sprite.play()
	guardian_sprite.speed_scale = 1.0 if movement_velocity.length_squared() > 1.0 else 0.35


func _walk_animation_name() -> StringName:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return &"walk_right" if facing_direction.x > 0.0 else &"walk_left"
	return &"walk_down" if facing_direction.y > 0.0 else &"walk_up"


func check_player_collision():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			game_world.on_player_caught()
			return
