extends Node2D

const LEFT := preload("res://assets/ui/guidance/footprints/shoe_left.png")
const RIGHT := preload("res://assets/ui/guidance/footprints/shoe_right.png")


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
	var halo := Sprite2D.new()
	halo.name = "FootprintGlow"
	halo.texture = texture
	halo.position = offset
	halo.rotation = direction.angle()
	halo.scale = Vector2.ONE * 0.95
	halo.modulate = Color(0.70, 0.58, 0.95, 0.14)
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(halo)
	var ink := Sprite2D.new()
	ink.name = "FootprintInk"
	ink.texture = texture
	ink.position = offset
	ink.rotation = direction.angle()
	ink.scale = Vector2.ONE * 0.8
	ink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ink)
