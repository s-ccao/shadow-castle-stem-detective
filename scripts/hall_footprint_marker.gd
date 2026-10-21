extends Node2D

const LEFT := preload("res://assets/ui/guidance/footprints/shoe_left.png")
const RIGHT := preload("res://assets/ui/guidance/footprints/shoe_right.png")
## The copy promises glowing footprints, and on the Hall's near-black floor a
## bare shoe outline read at gameplay zoom as scattered blue specks. Each print
## sits in a small pool of violet light instead: a shared radial gradient drawn
## additively, so overlapping pools brighten rather than muddy.
const GLOW_INNER := Color(0.82, 0.66, 1.0, 0.8)
const GLOW_MIDDLE := Color(0.66, 0.46, 1.0, 0.34)
const GLOW_OUTER := Color(0.52, 0.32, 0.95, 0.0)
const GLOW_SIZE := Vector2(34.0, 21.0)
const INK_TINT := Color(1.0, 0.93, 1.0, 1.0)

static var _glow_texture: GradientTexture2D
static var _glow_material: CanvasItemMaterial


func setup_straight(direction: Vector2, destination: bool, left_foot: bool, walkable: Callable) -> void:
	name = "RouteStopFootprints" if destination else "RouteFootprint"
	set_meta("route_kind", "destination" if destination else "straight")
	set_meta("route_direction", direction)
	if destination:
		_add_print(direction.orthogonal() * -4.0, direction, true, walkable)
		_add_print(direction.orthogonal() * 4.0, direction, false, walkable)
	else:
		_add_print(direction.orthogonal() * (-3.0 if left_foot else 3.0), direction, left_foot, walkable)


func setup_turn(incoming: Vector2, outgoing: Vector2, walkable: Callable) -> void:
	name = "RouteTurningFootprints"
	set_meta("route_kind", "corner_90")
	set_meta("incoming_direction", incoming)
	set_meta("outgoing_direction", outgoing)
	_add_print(-incoming * 8.0, incoming, true, walkable)
	_add_print(outgoing * 8.0, outgoing, false, walkable)


func _add_print(offset: Vector2, direction: Vector2, left_foot: bool, walkable: Callable) -> void:
	if not walkable.call(position + offset):
		offset = Vector2.ZERO
	var texture := LEFT if left_foot else RIGHT
	var glow := Sprite2D.new()
	glow.name = "FootprintGlow"
	glow.texture = _shared_glow_texture()
	glow.material = _shared_glow_material()
	glow.position = offset
	glow.rotation = direction.angle()
	glow.scale = GLOW_SIZE / Vector2(_glow_texture.width, _glow_texture.height)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(glow)
	var ink := Sprite2D.new()
	ink.name = "FootprintInk"
	ink.texture = texture
	ink.position = offset
	ink.rotation = direction.angle()
	ink.scale = Vector2.ONE * 0.8
	ink.modulate = INK_TINT
	ink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ink)


static func _shared_glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, GLOW_INNER)
		gradient.set_color(1, GLOW_OUTER)
		gradient.add_point(0.45, GLOW_MIDDLE)
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 32
		_glow_texture.height = 32
	return _glow_texture


static func _shared_glow_material() -> CanvasItemMaterial:
	if _glow_material == null:
		_glow_material = CanvasItemMaterial.new()
		_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _glow_material
