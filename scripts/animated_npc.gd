class_name AnimatedNpc
extends Node2D

## Reusable four-direction pixel NPC. Each production sheet is a 4x4 grid:
## down, left, right, up rows; four frames per row; 256px square cells.

const FRAME_SIZE: int = 256
const FRAME_COUNT: int = 4
const DIRECTION_ROWS: Dictionary = {
	"down": 0,
	"left": 1,
	"right": 2,
	"up": 3,
}

var character_name: String = "NPC"
var sprite_sheet_path: String = ""
var visual_scale: float = 0.20
var patrol_offset: Vector2 = Vector2.ZERO
var patrol_speed: float = 14.0
var start_direction: StringName = &"down"

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
	new_start_direction: StringName = &"down"
) -> void:
	character_name = new_character_name
	sprite_sheet_path = new_sprite_sheet_path
	visual_scale = new_visual_scale
	patrol_offset = new_patrol_offset
	patrol_speed = new_patrol_speed
	start_direction = new_start_direction
	_is_configured = true


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
	_play_walk(_direction_name(direction))


func _create_sprite() -> void:
	var sprite_sheet: Texture2D = load(sprite_sheet_path) as Texture2D
	if sprite_sheet == null:
		push_error("AnimatedNpc sprite sheet could not be loaded: " + sprite_sheet_path)
		return

	actor_sprite = AnimatedSprite2D.new()
	actor_sprite.name = "AnimatedSprite"
	actor_sprite.position = Vector2(0.0, -28.0)
	actor_sprite.scale = Vector2(visual_scale, visual_scale)
	actor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor_sprite.sprite_frames = _build_sprite_frames(sprite_sheet)
	actor_sprite.autoplay = "idle_" + str(start_direction)
	add_child(actor_sprite)


func _build_sprite_frames(sprite_sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for direction_variant: Variant in DIRECTION_ROWS.keys():
		var direction: String = str(direction_variant)
		var row: int = int(DIRECTION_ROWS[direction])
		var walk_animation: StringName = StringName("walk_" + direction)
		var idle_animation: StringName = StringName("idle_" + direction)
		frames.add_animation(walk_animation)
		frames.set_animation_speed(walk_animation, 6.0)
		frames.set_animation_loop(walk_animation, true)
		frames.add_animation(idle_animation)
		frames.set_animation_speed(idle_animation, 1.6)
		frames.set_animation_loop(idle_animation, true)
		for column: int in range(FRAME_COUNT):
			var frame: AtlasTexture = _make_atlas_frame(sprite_sheet, row, column)
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
		float(column * FRAME_SIZE),
		float(row * FRAME_SIZE),
		float(FRAME_SIZE),
		float(FRAME_SIZE)
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
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"
