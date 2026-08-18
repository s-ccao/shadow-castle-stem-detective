class_name AnimatedNpc
extends Node2D

## Default production sheets are 4x4 walk/idle grids. Some NPCs can opt into
## an 8-direction sheet with a custom frame size and idle-only playback.
const DEFAULT_FRAME_SIZE: Vector2i = Vector2i(256, 256)
const DEFAULT_FRAME_COUNT: int = 4
const LEGACY_DIRECTIONS: Array[StringName] = [
	&"down",
	&"left",
	&"right",
	&"up",
]
const EIGHT_DIRECTIONS: Array[StringName] = [
	&"north",
	&"north_east",
	&"east",
	&"south_east",
	&"south",
	&"south_west",
	&"west",
	&"north_west",
]

var character_name: String = "NPC"
var sprite_sheet_path: String = ""
var visual_scale: float = 0.20
var patrol_offset: Vector2 = Vector2.ZERO
var patrol_speed: float = 14.0
var start_direction: StringName = &"down"
var frame_size: Vector2i = DEFAULT_FRAME_SIZE
var frame_count: int = DEFAULT_FRAME_COUNT
var use_eight_directions: bool = false
var idle_only: bool = false
var visual_foot_anchor: Vector2 = Vector2(0.0, -28.0)

var actor_sprite: AnimatedSprite2D
var _patrol_origin: Vector2
var _patrol_sign: float = 1.0
var _is_configured: bool = false


func configure(
	new_character_name: String,
	new_sprite_sheet_path: String,
	new_visual_scale: float = 0.20,
	new_patrol_offset: Vector2 = Vector2.ZERO,
	new_patrol_speed: float = 14.0,
	new_start_direction: StringName = &"down",
	new_frame_size: Vector2i = DEFAULT_FRAME_SIZE,
	new_frame_count: int = DEFAULT_FRAME_COUNT,
	new_use_eight_directions: bool = false,
	new_idle_only: bool = false
) -> void:
	character_name = new_character_name
	sprite_sheet_path = new_sprite_sheet_path
	visual_scale = new_visual_scale
	patrol_offset = new_patrol_offset
	patrol_speed = new_patrol_speed
	start_direction = new_start_direction
	frame_size = new_frame_size
	frame_count = new_frame_count
	use_eight_directions = new_use_eight_directions
	idle_only = new_idle_only
	_is_configured = true


## Set the sprite-only offset that places the representative frame's last
## opaque row on the NPC's world-space feet. Call before adding the NPC to the
## scene tree; the Node2D root, patrol origin and interactions remain unchanged.
func set_visual_foot_anchor(new_anchor: Vector2) -> void:
	visual_foot_anchor = new_anchor
	if actor_sprite != null:
		actor_sprite.position = visual_foot_anchor


func _ready() -> void:
	if not _is_configured:
		push_warning("AnimatedNpc must be configured before entering the scene tree.")
		return
	_patrol_origin = position
	_create_sprite()
	_play_idle(start_direction)


func _process(delta: float) -> void:
	if actor_sprite == null or patrol_offset.length_squared() <= 1.0:
		return

	var target_position: Vector2 = _patrol_origin + patrol_offset * _patrol_sign
	var distance_to_target: float = position.distance_to(target_position)
	if distance_to_target <= 1.5:
		_patrol_sign *= -1.0
		target_position = _patrol_origin + patrol_offset * _patrol_sign

	var direction: Vector2 = position.direction_to(target_position)
	position = position.move_toward(target_position, patrol_speed * delta)
	var direction_name: StringName = _direction_name(direction)
	if idle_only:
		_play_idle(direction_name)
	else:
		_play_walk(direction_name)


func _create_sprite() -> void:
	var sprite_sheet: Texture2D = load(sprite_sheet_path) as Texture2D
	if sprite_sheet == null:
		push_error("AnimatedNpc sprite sheet could not be loaded: " + sprite_sheet_path)
		return

	actor_sprite = AnimatedSprite2D.new()
	actor_sprite.name = "AnimatedSprite"
	actor_sprite.position = visual_foot_anchor
	actor_sprite.scale = Vector2(visual_scale, visual_scale)
	actor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor_sprite.sprite_frames = _build_sprite_frames(sprite_sheet)
	actor_sprite.autoplay = "idle_" + str(start_direction)
	add_child(actor_sprite)


func _build_sprite_frames(sprite_sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var directions: Array[StringName] = (
		EIGHT_DIRECTIONS if use_eight_directions else LEGACY_DIRECTIONS
	)
	for row: int in range(directions.size()):
		var direction: StringName = directions[row]
		var walk_animation: StringName = StringName("walk_" + str(direction))
		var idle_animation: StringName = StringName("idle_" + str(direction))
		frames.add_animation(walk_animation)
		frames.set_animation_speed(walk_animation, 6.0)
		frames.set_animation_loop(walk_animation, true)
		frames.add_animation(idle_animation)
		frames.set_animation_speed(idle_animation, 1.6)
		frames.set_animation_loop(idle_animation, true)
		for column: int in range(frame_count):
			var frame: AtlasTexture = _make_atlas_frame(
				sprite_sheet,
				row,
				column
			)
			frames.add_frame(walk_animation, frame)
			frames.add_frame(idle_animation, frame)
	return frames


func _make_atlas_frame(
	sprite_sheet: Texture2D,
	row: int,
	column: int
) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sprite_sheet
	frame.region = Rect2(
		float(column * frame_size.x),
		float(row * frame_size.y),
		float(frame_size.x),
		float(frame_size.y)
	)
	return frame


func _play_walk(direction: StringName) -> void:
	if actor_sprite == null:
		return
	var animation: StringName = StringName("walk_" + str(direction))
	if actor_sprite.animation != animation:
		actor_sprite.play(animation)
	elif not actor_sprite.is_playing():
		actor_sprite.play()


func _play_idle(direction: StringName) -> void:
	if actor_sprite == null:
		return
	var animation: StringName = StringName("idle_" + str(direction))
	if actor_sprite.animation != animation:
		actor_sprite.play(animation)
	elif not actor_sprite.is_playing():
		actor_sprite.play()


func _direction_name(direction: Vector2) -> StringName:
	if not use_eight_directions:
		if absf(direction.x) > absf(direction.y):
			return &"right" if direction.x > 0.0 else &"left"
		return &"down" if direction.y > 0.0 else &"up"

	var angle: float = atan2(direction.y, direction.x)
	var octant: int = int(round(
		angle / (PI / 4.0)
	))
	if octant == 0:
		return &"east"
	if octant == 1:
		return &"south_east"
	if octant == 2:
		return &"south"
	if octant == 3:
		return &"south_west"
	if octant == 4 or octant == -4:
		return &"west"
	if octant == -3:
		return &"north_west"
	if octant == -2:
		return &"north"
	return &"north_east"
