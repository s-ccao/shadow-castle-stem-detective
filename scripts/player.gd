extends CharacterBody2D

signal click_target_reached
signal ground_move_started(target_position: Vector2)
signal click_movement_cancelled
signal click_movement_blocked(target_position: Vector2)

@export var speed: float = 180.0
@export var click_stop_distance: float = 6.0
@export var stuck_check_interval: float = 0.35
@export var stuck_min_progress: float = 8.0

var click_target := Vector2.ZERO
var click_destination := Vector2.ZERO
var click_movement_active := false

var click_path := PackedVector2Array()
var click_path_index := 0

var click_progress_timer := 0.0
var click_progress_position := Vector2.ZERO
@onready var character_sprite: AnimatedSprite2D = (
	$VisualRoot/CharacterSprite
)

var facing_direction: Vector2 = Vector2.DOWN

## 迅捷药水生效时返回加速后的移动速度。
func _get_effective_speed() -> float:
	var multiplier: float = 1.0
	if GameState != null and GameState.is_potion_active("swift"):
		multiplier = 1.4
	return speed * multiplier

func _unhandled_input(event):
	if not is_physics_processing():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# The room decides whether this position is reachable
			# and supplies the A* path.
			ground_move_started.emit(
				get_global_mouse_position()
			)


func _physics_process(
	delta: float
) -> void:
	var keyboard_direction: Vector2 = (
		Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)
	)

	# 键盘移动优先于鼠标点击移动。
	if keyboard_direction != Vector2.ZERO:
		cancel_click_movement()

		velocity = (
			keyboard_direction.normalized()
			* _get_effective_speed()
		)

		update_character_animation(
			velocity
		)

		move_with_floor_constraint(
			delta
		)

		return

	# 没有键盘输入，也没有点击移动。
	if not click_movement_active:
		velocity = Vector2.ZERO

		update_character_animation(
			velocity
		)

		move_with_floor_constraint(
			delta
		)

		return

	# 已经靠近当前路径点。
	if global_position.distance_to(
		click_target
	) <= click_stop_distance:
		advance_to_next_path_point()

		if not click_movement_active:
			velocity = Vector2.ZERO

			update_character_animation(
				velocity
			)

			return

	var distance_to_target: float = (
		global_position.distance_to(
			click_target
		)
	)

	var direction: Vector2 = (
		global_position.direction_to(
			click_target
		)
	)

	var safe_delta: float = maxf(
		delta,
		0.0001
	)

	var frame_limited_speed: float = minf(
		_get_effective_speed(),
		distance_to_target
			/ safe_delta
	)

	velocity = (
		direction
		* frame_limited_speed
	)

	update_character_animation(
		velocity
	)

	if _get_room_controller() != null:
		move_with_floor_constraint(delta)
	else:
		move_and_slide()

	if not click_movement_active:
		return

	if global_position.distance_to(
		click_target
	) <= click_stop_distance:
		advance_to_next_path_point()
		return

	check_click_movement_progress(
		delta
	)


func move_along_path(path: PackedVector2Array):
	clear_click_movement_state()

	if path.is_empty():
		return

	click_path = path
	click_path_index = 0
	click_destination = path[path.size() - 1]
	click_movement_active = true

	skip_nearby_path_points()

	if click_path_index >= click_path.size():
		finish_click_movement()
		return

	click_target = click_path[click_path_index]
	reset_click_progress_check()


func move_to_point(target_position: Vector2):
	var direct_path := PackedVector2Array()
	direct_path.append(target_position)

	move_along_path(direct_path)


func skip_nearby_path_points():
	var skip_distance = max(
		click_stop_distance * 2.0,
		12.0
	)

	while click_path_index < click_path.size():
		var point = click_path[click_path_index]

		if global_position.distance_to(point) > skip_distance:
			break

		click_path_index += 1


func advance_to_next_path_point():
	click_path_index += 1
	skip_nearby_path_points()

	if click_path_index >= click_path.size():
		finish_click_movement()
		return

	click_target = click_path[click_path_index]
	reset_click_progress_check()


func cancel_click_movement():
	var was_active := click_movement_active

	clear_click_movement_state()

	if was_active:
		click_movement_cancelled.emit()


func finish_click_movement():
	clear_click_movement_state()
	click_target_reached.emit()


func clear_click_movement_state():
	click_movement_active = false
	velocity = Vector2.ZERO

	click_path = PackedVector2Array()
	click_path_index = 0

	reset_click_progress_check()


func reset_click_progress_check():
	click_progress_timer = 0.0
	click_progress_position = global_position


func check_click_movement_progress(delta: float):
	click_progress_timer += delta

	if click_progress_timer < stuck_check_interval:
		return

	var progress_distance = global_position.distance_to(
		click_progress_position
	)

	if progress_distance < stuck_min_progress:
		stop_click_movement_as_blocked()
		return

	click_progress_timer = 0.0
	click_progress_position = global_position


func stop_click_movement_as_blocked():
	var blocked_destination := click_destination

	clear_click_movement_state()

	click_movement_blocked.emit(
		blocked_destination
	)
func _get_room_controller() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("is_player_position_walkable"):
			return current
		current = current.get_parent()
	return null


func move_with_floor_constraint(delta: float):
	var room: Node = _get_room_controller()

	if room == null:
		move_and_slide()
		return

	if not room.has_method(
		"is_player_position_walkable"
	):
		move_and_slide()
		return

	var frame_motion := velocity * delta

	var x_target := global_position + Vector2(
		frame_motion.x,
		0.0
	)

	if room.is_player_position_walkable(
		x_target
	):
		global_position.x = x_target.x
	else:
		velocity.x = 0.0

	var y_target := global_position + Vector2(
		0.0,
		frame_motion.y
	)

	if room.is_player_position_walkable(
		y_target
	):
		global_position.y = y_target.y
	else:
		velocity.y = 0.0
func set_visual_scale(
	scale_value: float
) -> void:
	var visual_root: Node2D = (
		get_node_or_null("VisualRoot") as Node2D
	)

	if visual_root == null:
		push_warning(
			"Player VisualRoot was not found."
		)
		return

	visual_root.scale = Vector2(
		scale_value,
		scale_value
	)
func update_character_animation(
	movement_velocity: Vector2
) -> void:
	if character_sprite == null:
		return

	var is_moving: bool = (
		movement_velocity.length_squared()
		> 1.0
	)

	if is_moving:
		update_facing_direction(
			movement_velocity
		)

		var animation_name: StringName = (
			get_walk_animation_name()
		)

		if character_sprite.animation != (
			animation_name
		):
			character_sprite.play(
				animation_name
			)
		elif not character_sprite.is_playing():
			character_sprite.play(
				animation_name
			)
	else:
		show_idle_frame()
func update_facing_direction(
	movement_velocity: Vector2
) -> void:
	if absf(movement_velocity.x) > (
		absf(movement_velocity.y)
	):
		if movement_velocity.x > 0.0:
			facing_direction = Vector2.RIGHT
		else:
			facing_direction = Vector2.LEFT
	else:
		if movement_velocity.y > 0.0:
			facing_direction = Vector2.DOWN
		else:
			facing_direction = Vector2.UP
func get_walk_animation_name() -> StringName:
	if facing_direction == Vector2.LEFT:
		return &"walk_left"

	if facing_direction == Vector2.RIGHT:
		return &"walk_right"

	if facing_direction == Vector2.UP:
		return &"walk_up"

	return &"walk_down"
func show_idle_frame() -> void:
	var animation_name: StringName = (
		get_walk_animation_name()
	)

	if character_sprite.animation != (
		animation_name
	):
		character_sprite.animation = (
			animation_name
		)

	character_sprite.stop()
	character_sprite.frame = 0
func _ready() -> void:
	if character_sprite == null:
		push_error(
			"CharacterSprite was not found."
		)
		return

	character_sprite.visible = true

	if character_sprite.sprite_frames.has_animation(
		&"walk_down"
	):
		character_sprite.animation = &"walk_down"
		character_sprite.frame = 0
		character_sprite.stop()
