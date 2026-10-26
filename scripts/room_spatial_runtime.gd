class_name RoomSpatialRuntime
extends RefCounted

## Shared world-space geometry for room interactions, depth sorting and safe spawns.
## It reads authored sprites/collisions but never changes gameplay state.

const VISIBLE_ALPHA_THRESHOLD := 0.05
const DEFAULT_INTERACTION_MARGIN := 14.0
const DEFAULT_FOCUS_PADDING := Vector2(10.0, 10.0)
const DEFAULT_SPAWN_CLEARANCE := 6.0
const DEFAULT_SPAWN_STEP := 16.0
const DEFAULT_SPAWN_SEARCH_RADIUS := 224.0
const DEFAULT_OPEN_DIRECTION_DISTANCE := 32.0

## Each texture's opaque rect, read once a session: reading a texture back can
## be a round trip to the GPU (on the web), and the rooms ask again each time
## they sync their boxes.
static var _opaque_rects: Dictionary = {}


func find_visual_node(root: Node) -> Node2D:
	if root is Sprite2D or root is AnimatedSprite2D:
		return root as Node2D
	for child: Node in root.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
	for child: Node in root.get_children():
		var nested := find_visual_node(child)
		if nested != null:
			return nested
	return null


func get_visual_rect(root: Node) -> Rect2:
	var visual := find_visual_node(root)
	if visual == null:
		if root is Node2D:
			return Rect2((root as Node2D).global_position, Vector2.ZERO)
		return Rect2()
	if visual is Sprite2D:
		return _sprite_visual_rect(visual as Sprite2D)
	if visual is AnimatedSprite2D:
		return _animated_visual_rect(visual as AnimatedSprite2D)
	return Rect2(visual.global_position, Vector2.ZERO)


func get_visual_feet(root: Node) -> Vector2:
	var rect := get_visual_rect(root)
	return Vector2(rect.get_center().x, rect.end.y)


func get_focus_rect(root: Node, padding: Vector2 = DEFAULT_FOCUS_PADDING) -> Rect2:
	return grow_rect(get_visual_rect(root), padding)


func grow_rect(rect: Rect2, padding: Vector2) -> Rect2:
	return Rect2(rect.position - padding, rect.size + padding * 2.0)


func get_player_collision_rect(actor: CharacterBody2D) -> Rect2:
	if actor == null:
		return Rect2()
	var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return Rect2(actor.global_position, Vector2.ZERO)
	if collision.shape is RectangleShape2D:
		var size := (collision.shape as RectangleShape2D).size * collision.global_scale.abs()
		return Rect2(collision.global_position - size * 0.5, size)
	if collision.shape is CircleShape2D:
		var radius := (collision.shape as CircleShape2D).radius * maxf(
			absf(collision.global_scale.x),
			absf(collision.global_scale.y)
		)
		return Rect2(collision.global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return Rect2(collision.global_position - Vector2.ONE * 8.0, Vector2.ONE * 16.0)


func rect_gap(first: Rect2, second: Rect2) -> float:
	var horizontal_gap := maxf(
		maxf(second.position.x - first.end.x, first.position.x - second.end.x),
		0.0
	)
	var vertical_gap := maxf(
		maxf(second.position.y - first.end.y, first.position.y - second.end.y),
		0.0
	)
	return Vector2(horizontal_gap, vertical_gap).length()


func is_actor_near_rect(
	actor: CharacterBody2D,
	target_rect: Rect2,
	margin: float = DEFAULT_INTERACTION_MARGIN
) -> bool:
	return rect_gap(get_player_collision_rect(actor), target_rect) <= margin


func update_occlusion(
	actor: CharacterBody2D,
	prop_root: Node2D,
	front_of_player_z: int,
	behind_player_z: int
) -> void:
	if actor == null or prop_root == null:
		return
	var visual := find_visual_node(prop_root) as CanvasItem
	if visual == null:
		return
	var prop_feet_y := get_visual_rect(prop_root).end.y
	var player_feet_y := get_player_collision_rect(actor).end.y
	# Player above the prop is behind it, so the prop must draw in front. Player
	# below the prop is in front, so the prop must draw behind the player.
	visual.z_as_relative = false
	visual.z_index = front_of_player_z if player_feet_y <= prop_feet_y else behind_player_z


func resolve_safe_spawn(
	actor: CharacterBody2D,
	preferred: Vector2,
	room_bounds: Rect2,
	minimum_open_directions: int = 3
) -> Vector2:
	if actor == null:
		return preferred
	var best_fallback := preferred
	var best_fallback_score := -INF
	var ring_count := int(ceil(DEFAULT_SPAWN_SEARCH_RADIUS / DEFAULT_SPAWN_STEP))
	for ring: int in range(ring_count + 1):
		var candidates := _ring_candidates(preferred, ring, DEFAULT_SPAWN_STEP)
		for candidate: Vector2 in candidates:
			if not _inside_spawn_bounds(candidate, room_bounds):
				continue
			if not is_position_clear(actor, candidate, DEFAULT_SPAWN_CLEARANCE):
				continue
			var open_directions := count_open_directions(
				actor,
				candidate,
				DEFAULT_OPEN_DIRECTION_DISTANCE
			)
			if open_directions >= minimum_open_directions:
				return candidate
			var fallback_score := float(open_directions) * 1000.0 - candidate.distance_to(preferred)
			if fallback_score > best_fallback_score:
				best_fallback_score = fallback_score
				best_fallback = candidate
	return best_fallback


func is_position_clear(
	actor: CharacterBody2D,
	position: Vector2,
	clearance: float = DEFAULT_SPAWN_CLEARANCE
) -> bool:
	var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return false
	var query_shape: Shape2D = collision.shape.duplicate() as Shape2D
	if query_shape is RectangleShape2D:
		(query_shape as RectangleShape2D).size += Vector2.ONE * clearance * 2.0
	elif query_shape is CircleShape2D:
		(query_shape as CircleShape2D).radius += clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(
		actor.global_rotation,
		position + collision.position.rotated(actor.global_rotation)
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [actor.get_rid()]
	for hit: Dictionary in actor.get_world_2d().direct_space_state.intersect_shape(query, 64):
		if hit.get("collider") is StaticBody2D:
			return false
	return true


func count_open_directions(
	actor: CharacterBody2D,
	position: Vector2,
	distance: float = DEFAULT_OPEN_DIRECTION_DISTANCE
) -> int:
	var open_count := 0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if is_position_clear(actor, position + direction * distance):
			open_count += 1
	return open_count


func _ring_candidates(center: Vector2, ring: int, step: float) -> Array[Vector2]:
	if ring == 0:
		return [center]
	var result: Array[Vector2] = []
	for y: int in range(-ring, ring + 1):
		for x: int in range(-ring, ring + 1):
			if max(abs(x), abs(y)) != ring:
				continue
			result.append(center + Vector2(float(x), float(y)) * step)
	result.sort_custom(func(first: Vector2, second: Vector2) -> bool:
		return first.distance_squared_to(center) < second.distance_squared_to(center)
	)
	return result


func _inside_spawn_bounds(position: Vector2, bounds: Rect2) -> bool:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return true
	return Rect2(
		bounds.position + Vector2.ONE * 24.0,
		bounds.size - Vector2.ONE * 48.0
	).has_point(position)


func _sprite_visual_rect(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)
	var full_rect := sprite.get_rect()
	var texture_size := sprite.texture.get_size()
	var opaque := _get_texture_opaque_rect(sprite.texture)
	var ratio := Vector2(
		full_rect.size.x / maxf(texture_size.x, 1.0),
		full_rect.size.y / maxf(texture_size.y, 1.0)
	)
	var local_rect := Rect2(
		full_rect.position + Vector2(opaque.position) * ratio,
		Vector2(opaque.size) * ratio
	)
	return _transformed_rect(sprite, local_rect)


func _animated_visual_rect(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)
	var texture_size := texture.get_size()
	var opaque := _get_texture_opaque_rect(texture)
	var local_origin := sprite.offset - texture_size * 0.5 if sprite.centered else sprite.offset
	var local_rect := Rect2(local_origin + Vector2(opaque.position), Vector2(opaque.size))
	return _transformed_rect(sprite, local_rect)


func _transformed_rect(node: Node2D, local_rect: Rect2) -> Rect2:
	var corners: Array[Vector2] = [
		local_rect.position,
		local_rect.position + Vector2(local_rect.size.x, 0.0),
		local_rect.end,
		local_rect.position + Vector2(0.0, local_rect.size.y),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner: Vector2 in corners:
		var point := node.to_global(corner)
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _get_texture_opaque_rect(texture: Texture2D) -> Rect2i:
	return opaque_rect_of_texture(texture)


## The rect of `texture`'s pixels whose alpha is over VISIBLE_ALPHA_THRESHOLD
## (all of it if none is, or if it cannot be read back).
static func opaque_rect_of_texture(texture: Texture2D) -> Rect2i:
	var texture_id := texture.get_instance_id()
	if _opaque_rects.has(texture_id):
		return _opaque_rects[texture_id] as Rect2i
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i(0, 0, int(texture.get_width()), int(texture.get_height()))
	var rect := opaque_rect_of(image, VISIBLE_ALPHA_THRESHOLD)
	_opaque_rects[texture_id] = rect
	return rect


## The bounds of `image`'s pixels whose alpha is over `threshold`, or the whole
## image if none is. Those pixels lie inside the native bounds of every pixel
## with any alpha (get_used_rect), so that is trimmed to the threshold one
## edge row or column at a time: only the faint edges are read pixel by pixel.
static func opaque_rect_of(image: Image, threshold: float) -> Rect2i:
	var whole := Rect2i(Vector2i.ZERO, image.get_size())
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return whole
	var left := used.position.x
	var right := used.end.x - 1
	var top := used.position.y
	var bottom := used.end.y - 1
	while top <= bottom and not _row_shows(image, top, left, right, threshold):
		top += 1
	if top > bottom:
		return whole
	while not _row_shows(image, bottom, left, right, threshold):
		bottom -= 1
	while not _column_shows(image, left, top, bottom, threshold):
		left += 1
	while not _column_shows(image, right, top, bottom, threshold):
		right -= 1
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


static func _row_shows(image: Image, y: int, left: int, right: int, threshold: float) -> bool:
	for x: int in range(left, right + 1):
		if image.get_pixel(x, y).a > threshold:
			return true
	return false


static func _column_shows(image: Image, x: int, top: int, bottom: int, threshold: float) -> bool:
	for y: int in range(top, bottom + 1):
		if image.get_pixel(x, y).a > threshold:
			return true
	return false
