extends SceneTree

## Circuit Room reachability contract.
##
## Every Circuit interaction has to be operable from a position the player can
## physically occupy. The three power switches are mounted on furniture, so a
## contact test that only measures distance to the painted plate is satisfied
## by points inside a solid prop, and the room becomes uncompletable while every
## visual still looks correct.

const ROOM_SCENE := "res://scenes/floor_1/circuit_room.tscn"
const SAMPLE_STEP := 12.0
const SEARCH_MARGIN := 120.0

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("game_started", true)

	var packed := load(ROOM_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load " + ROOM_SCENE)
		_finish()
		return
	var room := packed.instantiate()
	root.add_child(room)
	await process_frame
	await process_frame

	var player := room.get_node_or_null("Worldsort/player") as CharacterBody2D
	if player == null:
		_fail("Circuit Room player is unavailable")
		_finish()
		return
	player.set_physics_process(false)
	var home := player.global_position

	var spatial = room.get("spatial")
	var runtime := room.get("interaction_runtime") as Node
	var margin := float(runtime.get("interaction_contact_margin"))

	for item: Dictionary in room.get("INTERACT_ITEMS") as Array[Dictionary]:
		var item_name := str(item["name"])
		var contact_rect := _contact_rect(item, room, spatial)
		if contact_rect.size.x <= 0.0 or contact_rect.size.y <= 0.0:
			_fail(item_name + " has no usable contact rectangle")
			continue
		var stand := _find_standing_point(player, spatial, contact_rect, margin)
		_expect(
			stand != Vector2.INF,
			"Circuit %s can be operated from walkable floor" % item_name
		)
		if stand != Vector2.INF:
			print("REACH,%s,stand=(%.1f, %.1f)" % [item_name, stand.x, stand.y])
	player.global_position = home

	_expect(
		_selected_interaction(room, player, spatial, "switch_left") == "switch_left",
		"Standing at the auxiliary switch selects the switch, not its cabinet"
	)
	_expect(
		_selected_interaction(room, player, spatial, "master_switch") == "master_switch",
		"Standing at the master switch selects the switch, not its workbench"
	)
	_expect(
		_selected_interaction(room, player, spatial, "switch_right") == "switch_right",
		"Standing at the regulator switch selects the switch, not its generator"
	)

	# The reverse has to hold too: the canonical way to inspect a prop is to walk
	# to the middle of its front edge, and a switch band must never steal that.
	var prop_paths := room.get("PROP_NODE_PATHS") as Dictionary
	for prop_name: String in ["workbench", "generator", "cabinet"]:
		var prop := room.get_node_or_null(prop_paths[prop_name]) as Node2D
		if prop == null:
			_fail("Circuit prop is missing: " + prop_name)
			continue
		var prop_rect := spatial.get_visual_rect(prop) as Rect2
		player.global_position = Vector2(prop_rect.get_center().x, prop_rect.end.y + 18.0)
		_expect(
			_touching_name(room, player, spatial) == prop_name,
			"Standing at the front edge of the %s still selects the %s" % [prop_name, prop_name]
		)
	player.global_position = home
	player.global_position = home

	room.queue_free()
	await process_frame
	_finish()


## Mirrors RoomInteractionRuntime: an explicit contact band wins, otherwise the
## visible interaction rectangle is also the contact surface.
func _contact_rect(item: Dictionary, room: Node, spatial: Variant) -> Rect2:
	if item.has("contact_rect"):
		return item["contact_rect"] as Rect2
	if item.has("interaction_rect"):
		return item["interaction_rect"] as Rect2
	var prop_paths := room.get("PROP_NODE_PATHS") as Dictionary
	var item_name := str(item["name"])
	if prop_paths.has(item_name):
		var prop := room.get_node_or_null(prop_paths[item_name]) as Node2D
		if prop != null:
			return spatial.get_visual_rect(prop) as Rect2
	var position := item["position"] as Vector2
	return Rect2(position - Vector2(56.0, 41.0), Vector2(112.0, 82.0))


func _find_standing_point(
	player: CharacterBody2D,
	spatial: Variant,
	contact_rect: Rect2,
	margin: float
) -> Vector2:
	var search := contact_rect.grow(SEARCH_MARGIN)
	var y := search.position.y
	while y <= search.end.y:
		var x := search.position.x
		while x <= search.end.x:
			var candidate := Vector2(x, y)
			if bool(spatial.is_position_clear(player, candidate, 0.0)):
				player.global_position = candidate
				if bool(spatial.is_actor_near_rect(player, contact_rect, margin)):
					return candidate
			x += SAMPLE_STEP
		y += SAMPLE_STEP
	return Vector2.INF


## The runtime returns the first touching entry, so ordering decides which
## interaction a shared standing point offers.
func _touching_name(room: Node, player: CharacterBody2D, spatial: Variant) -> String:
	var items := room.get("INTERACT_ITEMS") as Array[Dictionary]
	var runtime := room.get("interaction_runtime") as Node
	var margin := float(runtime.get("interaction_contact_margin"))
	for candidate: Dictionary in items:
		if bool(
			spatial.is_actor_near_rect(player, _contact_rect(candidate, room, spatial), margin)
		):
			return str(candidate["name"])
	return ""


func _selected_interaction(
	room: Node,
	player: CharacterBody2D,
	spatial: Variant,
	wanted: String
) -> String:
	var items := room.get("INTERACT_ITEMS") as Array[Dictionary]
	var runtime := room.get("interaction_runtime") as Node
	var margin := float(runtime.get("interaction_contact_margin"))
	for item: Dictionary in items:
		if str(item["name"]) != wanted:
			continue
		var stand := _find_standing_point(player, spatial, _contact_rect(item, room, spatial), margin)
		if stand == Vector2.INF:
			return ""
		player.global_position = stand
		return _touching_name(room, player, spatial)
	return ""


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if game_state != null:
		game_state.set("game_started", false)
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("circuit_switch_reach_test: PASS")
		quit(0)
		return
	printerr("circuit_switch_reach_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
