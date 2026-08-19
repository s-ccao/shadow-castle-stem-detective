extends CharacterBody2D

enum Behavior {
	DORMANT,
	CHASE,
	PATROL,
	SEARCH,
	STUNNED,
}

const GUARDIAN_SPRITE_SHEET: Texture2D = preload(
	"res://assets/characters/animated_pixel_v5/castle_guardian_walk_8dir.png"
)
const GUARDIAN_FRAME_SIZE: Vector2i = Vector2i(128, 156)
## Visual only. Changing these must never touch the CharacterBody2D, its
## collision shape, chase speed, catch distance or line-of-sight geometry.
const HALL_VISUAL_SCALE: Vector2 = Vector2(0.8, 0.8)
const HALL_VISUAL_FOOT_ANCHOR: Vector2 = Vector2(0.0, -44.8)
const GUARDIAN_FRAME_COUNT: int = 8
const GUARDIAN_ROW_BY_ANIMATION: Dictionary = {
	&"walk_down": 4,
	&"walk_left": 6,
	&"walk_right": 2,
	&"walk_up": 0,
}
## Fraction of the intended step the body must actually cover to count as
## moving. Sliding along a wall keeps most of it; pressing into a corner
## keeps almost none.
const STALL_PROGRESS_RATIO: float = 0.25
## How long to keep pushing before writing the waypoint off, in seconds.
const STALL_TIMEOUT: float = 0.4

@export var display_name: String = "Castle Guardian"
@export var repath_interval: float = 0.35
@export var catch_radius: float = 22.0

var game_world: Node = null
var player: Node2D = null

var path: Array = []
var path_index: int = 0
var repath_timer: float = 0.0
var facing_direction: Vector2 = Vector2.DOWN
var behavior: int = Behavior.DORMANT
var cinematic_hold: bool = false
var catch_enabled: bool = true
var can_see_player: bool = false
var stakeout_target: Vector2 = Vector2.ZERO
var stall_timer: float = 0.0
@onready var guardian_sprite: AnimatedSprite2D = $GuardianCore


func _ready() -> void:
	_apply_updated_guardian_model()


func _apply_updated_guardian_model() -> void:
	if guardian_sprite == null:
		return
	var frames := SpriteFrames.new()
	for animation_name: StringName in GUARDIAN_ROW_BY_ANIMATION:
		var source_row: int = int(GUARDIAN_ROW_BY_ANIMATION[animation_name])
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 5.0)
		frames.set_animation_loop(animation_name, true)
		for column: int in range(GUARDIAN_FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = GUARDIAN_SPRITE_SHEET
			frame.region = Rect2(
				float(column * GUARDIAN_FRAME_SIZE.x),
				float(source_row * GUARDIAN_FRAME_SIZE.y),
				float(GUARDIAN_FRAME_SIZE.x),
				float(GUARDIAN_FRAME_SIZE.y)
			)
			frames.add_frame(animation_name, frame)
	guardian_sprite.sprite_frames = frames
	# The south-facing opaque figure is 100px tall at scale 1.0. Castle Hall now
	# renders the detective at 65.8px, so 0.80 puts the Guardian at 80px: still
	# clearly the larger body, while both read as small against a 1920x1280 hall.
	# -44.8px keeps its boots bottom-aligned with the CharacterBody2D ground point.
	guardian_sprite.position = HALL_VISUAL_FOOT_ANCHOR
	guardian_sprite.scale = HALL_VISUAL_SCALE
	guardian_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	guardian_sprite.play(&"walk_down")


func setup(world: Node, target_player: Node2D):
	game_world = world
	player = target_player
	repath_timer = 0.0
	catch_enabled = true
	cinematic_hold = false
	set_behavior(GameState.get_guardian_mode())


func set_behavior(new_behavior: int) -> void:
	if behavior == new_behavior:
		return
	behavior = new_behavior
	path.clear()
	path_index = 0
	repath_timer = 0.0
	stall_timer = 0.0


func set_cinematic_hold(held: bool) -> void:
	cinematic_hold = held
	if held:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)


func is_cinematic_held() -> bool:
	return cinematic_hold


func set_catch_enabled(enabled: bool) -> void:
	catch_enabled = enabled


func face_toward(target_position: Vector2) -> void:
	var toward := target_position - global_position
	if toward.length_squared() > 1.0:
		facing_direction = toward.normalized()
	_update_animation(Vector2.ZERO)


func _physics_process(delta):
	if game_world == null or player == null:
		return
	if cinematic_hold:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	if behavior == Behavior.DORMANT:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return

	if game_world.game_over or game_world.dialogue_active:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	_update_awareness()

	if behavior == Behavior.STUNNED:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	repath_timer -= delta
	if repath_timer <= 0.0:
		update_path()
		repath_timer = repath_interval

	move_along_path(delta)
	check_player_collision()


## Decides, once per physics frame, whether the Guardian currently knows where
## the player is. The tracking serum short-circuits this entirely: while it is
## in the player's blood the Guardian is omniscient, which is exactly the
## pressure the Purification Potion is meant to remove.
func _update_awareness() -> void:
	if GameState.is_guardian_stunned():
		can_see_player = false
		if behavior != Behavior.STUNNED:
			set_behavior(Behavior.STUNNED)
		return

	if GameState.is_guardian_tracking_serum_active():
		can_see_player = true
		if behavior == Behavior.STUNNED:
			set_behavior(GameState.get_guardian_mode())
		return

	var sighted := _has_line_of_sight_to_player()
	if sighted and not can_see_player:
		GameState.report_player_seen(player.global_position)
	elif not sighted and can_see_player:
		GameState.report_player_lost(player.global_position)
	can_see_player = sighted
	set_behavior(GameState.get_guardian_mode())


func _has_line_of_sight_to_player() -> bool:
	if GameState.is_player_shrouded():
		return false
	var toward: Vector2 = player.global_position - global_position
	var distance: float = toward.length()
	# Standing on top of the Guardian is always noticed, cone or not.
	if distance <= GameState.GUARDIAN_PROXIMITY_ALERT_RADIUS:
		return _segment_is_clear(global_position, player.global_position)
	if distance > GameState.GUARDIAN_SIGHT_RANGE:
		return false
	var facing: Vector2 = (
		facing_direction
		if facing_direction.length_squared() > 0.0
		else Vector2.DOWN
	)
	var angle: float = rad_to_deg(facing.angle_to(toward / distance))
	if absf(angle) > GameState.GUARDIAN_SIGHT_HALF_ANGLE_DEGREES:
		return false
	return _segment_is_clear(global_position, player.global_position)


func _segment_is_clear(from_position: Vector2, to_position: Vector2) -> bool:
	if not game_world.has_method("is_sight_line_clear"):
		return true
	return bool(game_world.call("is_sight_line_clear", from_position, to_position))


func update_path():
	var start_cell = game_world.world_to_cell(global_position)
	var end_cell = game_world.world_to_cell(_current_target_position())

	path = game_world.find_path(start_cell, end_cell)

	if path.size() > 1:
		path_index = 1
	else:
		path_index = 0


func _current_target_position() -> Vector2:
	match behavior:
		Behavior.CHASE:
			# Only a Guardian that can actually perceive the player may walk
			# straight at them. Otherwise it commits to the last sighting.
			if can_see_player:
				return player.global_position
			return GameState.get_guardian_last_known_player_position()
		Behavior.SEARCH:
			return GameState.get_guardian_last_known_player_position()
		_:
			if GameState.is_guardian_tracking_serum_active():
				return GameState.get_guardian_hall_position()
			return GameState.get_guardian_stakeout_anchor()


func move_along_path(delta: float) -> void:
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
		stall_timer = 0.0
		_update_animation(Vector2.ZERO)
		return

	var move_speed := _current_move_speed()

	velocity = direction.normalized() * move_speed
	_update_animation(velocity)
	var position_before := global_position
	move_and_slide()
	_note_progress(position_before, move_speed, delta)
	GameState.update_guardian_hall_position(global_position)


## Give up on a waypoint the body cannot actually reach.
##
## The navigation grid is built from the player's 14x8 body, because that is
## what decides where a chase can be aimed. This body is 24x24, so a cell the
## grid calls open can still be too tight to enter. Without this the Guardian
## presses into the corner forever: it never gets within 4px of the waypoint,
## so path_index never advances and the hunt stops without ever looking stopped.
func _note_progress(position_before: Vector2, move_speed: float, delta: float) -> void:
	var expected := move_speed * delta
	if expected <= 0.0:
		return
	if global_position.distance_to(position_before) >= expected * STALL_PROGRESS_RATIO:
		stall_timer = 0.0
		return
	stall_timer += delta
	if stall_timer < STALL_TIMEOUT:
		return
	stall_timer = 0.0
	path_index += 1
	# Re-plan on the next frame too: whatever is in the way is not on the grid,
	# so the rest of this path is suspect.
	repath_timer = 0.0


## Chase speed is the escalated, stacked value; loitering is deliberately slow
## so an unnoticed player can reposition around the stakeout.
func _current_move_speed() -> float:
	match behavior:
		Behavior.CHASE:
			return GameState.get_guardian_chase_speed()
		Behavior.SEARCH:
			return GameState.get_guardian_search_speed()
		_:
			return GameState.get_guardian_unaware_speed()


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
	if behavior != Behavior.CHASE or not catch_enabled:
		return
	if global_position.distance_to(player.global_position) <= catch_radius:
		game_world.on_player_caught()
		return
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			game_world.on_player_caught()
			return
