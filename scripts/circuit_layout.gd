class_name CircuitLayout
extends RefCounted

const ROOM_SIZE := Vector2(1448.0, 1086.0)
const SWITCH_ORDER: Array[String] = ["switch_left", "switch_right", "master_switch"]
# Each switch is mounted on the face of a solid prop, so its painted plate is
# never a place the player can stand. `contact` is the strip of walkable floor
# directly in front of the mounting prop, measured from that prop's collision
# footprint, and it stays narrower than the prop so the prop itself is still
# approachable from either side.
const SWITCH_SPECS: Dictionary = {
	"switch_left": {
		"node_name": "SwitchLeft",
		"position": Vector2(210.0, 535.0),
		"size": Vector2(64.0, 48.0),
		"contact": Rect2(238.0, 656.0, 80.0, 24.0),
		"number": "1",
		"label": "AUXILIARY / LEFT",
	},
	"switch_right": {
		"node_name": "SwitchRight",
		"position": Vector2(1210.0, 595.0),
		"size": Vector2(64.0, 48.0),
		"contact": Rect2(1160.0, 818.0, 100.0, 24.0),
		"number": "2",
		"label": "REGULATOR / RIGHT",
	},
	"master_switch": {
		"node_name": "MasterSwitch",
		"position": Vector2(705.0, 595.0),
		"size": Vector2(72.0, 56.0),
		"contact": Rect2(692.0, 745.0, 86.0, 24.0),
		"number": "3",
		"label": "MASTER / CENTER",
	},
}


static func get_position(switch_id: String) -> Vector2:
	return SWITCH_SPECS.get(switch_id, {}).get("position", Vector2.ZERO) as Vector2


static func get_size(switch_id: String) -> Vector2:
	return SWITCH_SPECS.get(switch_id, {}).get("size", Vector2.ZERO) as Vector2


static func get_rect(switch_id: String) -> Rect2:
	var size := get_size(switch_id)
	return Rect2(get_position(switch_id) - size * 0.5, size)


static func get_contact_rect(switch_id: String) -> Rect2:
	return SWITCH_SPECS.get(switch_id, {}).get("contact", Rect2()) as Rect2


static func room_to_map_board(world_position: Vector2, board_rect: Rect2) -> Vector2:
	return board_rect.position + Vector2(
		world_position.x / ROOM_SIZE.x * board_rect.size.x,
		world_position.y / ROOM_SIZE.y * board_rect.size.y
	)
