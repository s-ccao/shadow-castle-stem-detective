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

## The cast stands its ground. Wandering NPCs read as aimless — five of them
## sliding around a room looks like a bug, not like people at work. Each one
## holds its authored mark and its authored pose, and the only thing that
## changes is that it turns to meet a player who comes over.
##
## Distance at which an NPC notices the player, with a wider release distance
## so someone standing exactly on the boundary cannot make it snap back and
## forth between poses.
const ATTENTION_RADIUS: float = 132.0
const ATTENTION_RELEASE_RADIUS: float = 168.0
## Column of a 4-frame walk strip that reads as "standing": both feet planted.
const IDLE_STANDING_FRAME: int = 0
const IDLE_SHEET_FPS: float = 4.0

var character_name: String = "NPC"
var sprite_sheet_path: String = ""
var visual_scale: float = 0.20
## Retained for call-site compatibility; the cast no longer patrols.
var patrol_offset: Vector2 = Vector2.ZERO
var patrol_speed: float = 14.0
var start_direction: StringName = &"down"
var frame_size: Vector2i = DEFAULT_FRAME_SIZE
var frame_count: int = DEFAULT_FRAME_COUNT
var use_eight_directions: bool = false
var idle_only: bool = false
var visual_foot_anchor: Vector2 = Vector2(0.0, -28.0)

var actor_sprite: AnimatedSprite2D
var _is_configured: bool = false
var _attention_target: Node2D
var _attending: bool = false
var _facing: StringName = &"down"
var _notice_tween: Tween


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
	_facing = start_direction
	_create_sprite()
	_play_idle(start_direction)


## Who this NPC turns toward. Defaults to the player; rooms can override it for
## a scripted beat (an NPC watching a door, say).
func set_attention_target(target: Node2D) -> void:
	_attention_target = target


func _resolve_attention_target() -> Node2D:
	if _attention_target != null and is_instance_valid(_attention_target):
		return _attention_target
	if not is_inside_tree():
		return null
	_attention_target = get_tree().get_first_node_in_group(&"player") as Node2D
	return _attention_target


func _process(_delta: float) -> void:
	if actor_sprite == null:
		return
	var target := _resolve_attention_target()
	if target == null:
		return

	# Hysteresis: a player standing on the boundary would otherwise flip the
	# NPC between "greeting" and "back to work" every frame.
	var distance: float = global_position.distance_to(target.global_position)
	var was_attending := _attending
	if _attending:
		_attending = distance <= ATTENTION_RELEASE_RADIUS
	else:
		_attending = distance <= ATTENTION_RADIUS

	var wanted: StringName = (
		_direction_name(target.global_position - global_position)
		if _attending
		else start_direction
	)
	if _attending and not was_attending:
		_play_notice_reaction()
	if wanted != _facing:
		_facing = wanted
	_play_idle(_facing)


## A small, quiet acknowledgement when someone walks up: the figure straightens
## slightly and settles. Turning alone is easy to miss on a 4-frame sprite, and
## anything larger would read as a wandering NPC again.
func _play_notice_reaction() -> void:
	if actor_sprite == null:
		return
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	var settled := Vector2(visual_scale, visual_scale)
	actor_sprite.scale = settled
	_notice_tween = create_tween()
	_notice_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_property(actor_sprite, "scale", settled * 1.06, 0.12)
	_notice_tween.tween_property(actor_sprite, "scale", settled, 0.18)


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
		frames.set_animation_loop(idle_animation, true)
		if idle_only:
			# A dedicated idle sheet is a breathing loop: every frame belongs to
			# standing still, so play the whole thing gently.
			frames.set_animation_speed(idle_animation, IDLE_SHEET_FPS)
		else:
			# A walk sheet is a stride. Resting on the whole cycle steps the legs
			# in place at 1.6fps, which reads as a stuttering, aimless shuffle.
			# Standing still means holding the neutral frame instead.
			frames.set_animation_speed(idle_animation, 1.0)
		for column: int in range(frame_count):
			var frame: AtlasTexture = _make_atlas_frame(
				sprite_sheet,
				row,
				column
			)
			frames.add_frame(walk_animation, frame)
			if idle_only or column == IDLE_STANDING_FRAME:
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
