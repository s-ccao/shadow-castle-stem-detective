extends SceneTree

## Circuit Room concealment contract.
##
## The three junction plates are set flush with their housings. Until the player
## earns their position the room must offer nothing at all — no plate, no prompt,
## no focus box and no contact band — otherwise the puzzle can be solved by
## walking along the wall pressing the interact key.
##
## Two things grant that position: studying the repair blueprint on site, or
## seeing through the housings under a Vision potion.

const ROOM_SCENE := "res://scenes/floor_1/circuit_room.tscn"
const SURVEY_FLAG := "circuit_switches_surveyed"

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)

	await _check_concealed_by_default()
	await _check_blueprint_survey()
	await _check_vision_survey()
	await _check_survey_persists()

	paused = false
	_finish()


func _check_concealed_by_default() -> void:
	var room := await _open_room()
	if room == null:
		return
	_expect(
		not game_state.call("has_story_flag", SURVEY_FLAG),
		"A fresh Circuit Room has not surveyed its junction plates"
	)
	for switch_id: String in ["switch_left", "switch_right", "master_switch"]:
		var node := (room.get("switch_visuals") as Dictionary).get(switch_id) as Node2D
		_expect(node != null and not node.visible, "%s is hidden before the survey" % switch_id)
		_expect(_item_concealed(room, switch_id), "%s offers no interaction before the survey" % switch_id)
	_expect(
		_selected_at_switch(room, "master_switch") != "master_switch",
		"Standing at a concealed plate never selects it"
	)
	await _close_room(room)


func _check_blueprint_survey() -> void:
	var room := await _open_room()
	if room == null:
		return
	game_state.call("add_map", "circuit_repair_map")
	game_state.set("current_room_id", "circuit_room")
	root.get_node("MapHud").call("show_repair_map")
	await process_frame
	await process_frame
	_expect(
		game_state.call("has_story_flag", SURVEY_FLAG),
		"Studying the repair blueprint on site surveys the junction plates"
	)
	for switch_id: String in ["switch_left", "switch_right", "master_switch"]:
		var node := (room.get("switch_visuals") as Dictionary).get(switch_id) as Node2D
		_expect(node != null and node.visible, "%s is visible after the blueprint survey" % switch_id)
		_expect(not _item_concealed(room, switch_id), "%s is operable after the blueprint survey" % switch_id)
	root.get_node("MapHud").call("close_repair_map")
	await _close_room(room)


func _check_vision_survey() -> void:
	var room := await _open_room()
	if room == null:
		return
	_expect(
		not game_state.call("has_story_flag", SURVEY_FLAG),
		"Vision path starts from a room that has not been surveyed"
	)
	game_state.call("apply_potion_effect", "vision", 20.0)
	await process_frame
	await process_frame
	_expect(
		game_state.call("has_story_flag", SURVEY_FLAG),
		"A Vision potion surveys the junction plates without the blueprint"
	)
	_expect(
		not _item_concealed(room, "master_switch"),
		"Vision makes the master plate operable"
	)
	await _close_room(room)


func _check_survey_persists() -> void:
	var room := await _open_room(false)
	if room == null:
		return
	# Re-entering must not re-hide a plate the player has already located, and
	# the reveal must not depend on the Vision potion still running.
	game_state.set("potion_effects", {})
	game_state.call("set_story_flag", SURVEY_FLAG)
	await process_frame
	_expect(
		not _item_concealed(room, "switch_left"),
		"A surveyed plate stays operable after Vision expires"
	)
	await _close_room(room)


func _open_room(reset: bool = true) -> Node:
	if reset:
		game_state.call("reset_new_game")
	game_state.set("game_started", true)
	game_state.set("current_room_id", "circuit_room")
	var packed := load(ROOM_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load " + ROOM_SCENE)
		return null
	var room := packed.instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	return room


func _close_room(room: Node) -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
	await process_frame
	await process_frame
	paused = false


func _item_concealed(room: Node, switch_id: String) -> bool:
	for item: Dictionary in room.get("INTERACT_ITEMS") as Array[Dictionary]:
		if str(item["name"]) == switch_id:
			return bool(item.get("concealed", false))
	return false


## Mirrors the runtime: concealed entries are skipped entirely, so the first
## non-concealed touching entry is what the player would be offered.
func _selected_at_switch(room: Node, switch_id: String) -> String:
	var runtime := room.get("interaction_runtime") as Node
	var spatial = room.get("spatial")
	var player := room.get_node_or_null("Worldsort/player") as CharacterBody2D
	if runtime == null or player == null:
		return ""
	var margin := float(runtime.get("interaction_contact_margin"))
	var band := CircuitLayout.get_contact_rect(switch_id)
	player.global_position = band.get_center()
	for item: Dictionary in room.get("INTERACT_ITEMS") as Array[Dictionary]:
		if bool(item.get("concealed", false)):
			continue
		if bool(spatial.is_actor_near_rect(player, runtime.call("_get_item_contact_rect", item), margin)):
			return str(item["name"])
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
		print("circuit_switch_survey_test: PASS")
		quit(0)
		return
	printerr("circuit_switch_survey_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
