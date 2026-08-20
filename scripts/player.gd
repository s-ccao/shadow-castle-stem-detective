extends CharacterBody2D

signal click_target_reached
signal ground_move_started(target_position: Vector2)
signal click_movement_cancelled
signal click_movement_blocked(target_position: Vector2)

## World pixels one full eight-frame walk cycle carries the body.
##
## Driving playback from distance instead of from time is what stops the feet
## sliding. The cycle was pinned at the SpriteFrames' 5 fps, so the detective
## crossed 288px per stride at walking speed and skated everywhere; worse, a
## Swiftness Potion moved the body 40% faster without moving the legs at all.
## Scaling playback by the real speed keeps one stride on one patch of ground
## whatever the body is doing.
const WALK_CYCLE_DISTANCE: float = 84.0
## Seconds one cycle takes at speed_scale 1.0: eight frames at 5 fps.
const WALK_CYCLE_SECONDS: float = 1.6
## Slowest and fastest playback allowed. The floor keeps a crawl from freezing
## mid-stride; the ceiling keeps a speed potion from strobing.
const WALK_SCALE_MIN: float = 0.65
const WALK_SCALE_MAX: float = 5.0

@export var speed: float = 180.0
@export var click_stop_distance: float = 6.0
@export var stuck_check_interval: float = 0.35
@export var stuck_min_progress: float = 8.0

## 每个背景的透视、家具尺寸和相机取景并不完全一致。这里仅缩放
## VisualRoot：角色脚底、碰撞体、移动速度与交互半径保持统一，避免
## “看起来大小对了却碰不到物件”或缩放后卡进墙里的问题。
##
## 当前八个房间按家具与门框重新校准：玩家统一保持约 91px 的非透明
## 站立高度。缩放仍只发生在 VisualRoot，实体、脚底、碰撞和交互范围
## 不变。保留房间表作为未来更换背景后的唯一调节口。
const ROOM_VISUAL_SCALE_PROFILES: Dictionary = {
	"wake_room": 2.0,
	# Castle Hall is 1920x1280, far larger than any room. A smaller figure there
	# is what makes the hall read as open ground worth crossing carefully.
	"floor_1_hub": 1.45,
	"chemistry_room": 2.0,
	"greenhouse_room": 2.0,
	"circuit_room": 2.0,
	"dining_hall": 2.0,
	"library": 2.0,
	"final_deduction_room": 2.0,
}

var click_target := Vector2.ZERO
var click_destination := Vector2.ZERO
var click_movement_active := false

var click_path := PackedVector2Array()
var click_path_index := 0

var click_progress_timer := 0.0
var click_progress_position := Vector2.ZERO
var visual_scale_tween: Tween
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
			# 摇杆和动作键上的手指同样会被模拟成一次左键按下，不挡住的话
			# 每次推摇杆都会额外派发一条“走到脚下去”的点地指令。
			if TouchControls != null and TouchControls.blocks_world_point(event.position):
				return
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
		global_position.x += _closest_free_step(
			room,
			global_position,
			Vector2(frame_motion.x, 0.0)
		).x
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
		global_position.y += _closest_free_step(
			room,
			global_position,
			Vector2(0.0, frame_motion.y)
		).y
		velocity.y = 0.0


## Rejecting the whole step leaves the player parked up to a full frame of travel
## short of the wall, which reads as an invisible barrier standing off the art.
func _closest_free_step(room: Node, from: Vector2, motion: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for _i in range(5):
		var mid := (low + high) * 0.5
		if room.is_player_position_walkable(from + motion * mid):
			low = mid
		else:
			high = mid
	return motion * low
func set_room_visual_scale(room_id: String, animate: bool = false) -> void:
	var scale_value: float = float(
		ROOM_VISUAL_SCALE_PROFILES.get(room_id, 1.0)
	)
	set_visual_scale(scale_value, animate)


func set_visual_scale(scale_value: float, animate: bool = false) -> void:
	var visual_root: Node2D = (
		get_node_or_null("VisualRoot") as Node2D
	)

	if visual_root == null:
		push_warning(
			"Player VisualRoot was not found."
		)
		return
	var target_scale := Vector2(scale_value, scale_value)
	if visual_scale_tween != null and visual_scale_tween.is_valid():
		visual_scale_tween.kill()
	if not animate:
		visual_root.scale = target_scale
		return
	# 场景切换后的短暂 settle 只作用于视觉根节点；不影响实体模拟。
	visual_root.scale = target_scale * 0.94
	visual_scale_tween = create_tween()
	visual_scale_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visual_scale_tween.tween_property(visual_root, "scale", target_scale, 0.14)
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

		character_sprite.speed_scale = clampf(
			movement_velocity.length()
			* WALK_CYCLE_SECONDS
			/ WALK_CYCLE_DISTANCE,
			WALK_SCALE_MIN,
			WALK_SCALE_MAX
		)
	else:
		show_idle_frame()
func update_facing_direction(
	movement_velocity: Vector2
) -> void:
	var angle: float = atan2(
		movement_velocity.y,
		movement_velocity.x
	)
	var octant: int = int(round(
		angle / (PI / 4.0)
	))

	if octant == 0:
		facing_direction = Vector2.RIGHT
	elif octant == 1:
		facing_direction = Vector2(1.0, 1.0).normalized()
	elif octant == 2:
		facing_direction = Vector2.DOWN
	elif octant == 3:
		facing_direction = Vector2(-1.0, 1.0).normalized()
	elif octant == 4 or octant == -4:
		facing_direction = Vector2.LEFT
	elif octant == -3:
		facing_direction = Vector2(-1.0, -1.0).normalized()
	elif octant == -2:
		facing_direction = Vector2.UP
	else:
		facing_direction = Vector2(1.0, -1.0).normalized()


func get_walk_animation_name() -> StringName:
	var angle: float = atan2(
		facing_direction.y,
		facing_direction.x
	)
	var octant: int = int(round(
		angle / (PI / 4.0)
	))

	match octant:
		0:
			return &"walk_right"
		1:
			return &"walk_down_right"
		2:
			return &"walk_down"
		3:
			return &"walk_down_left"
		4, -4:
			return &"walk_left"
		-3:
			return &"walk_up_left"
		-2:
			return &"walk_up"
		_:
			return &"walk_up_right"
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
	# 触摸操作层靠这个组判断“此刻有没有人可以操控”，所以它必须先于下面的
	# 早退发生。scripts/examples/door_puzzle_example.gd 也一直在查这个组。
	add_to_group(&"player")

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
