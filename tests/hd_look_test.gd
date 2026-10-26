extends SceneTree

## The HD look ships as the HDLook autoload (scripts/hd/hd_look.gd). This checks
## the wiring the Blender captures do not: a --script run like this one keeps
## the painted game until it enables the look; enabled, the speakers' portraits
## and the Map Hub's maps turn HD at once, and the Hall and every room stage
## their HD look as the game loads them, each look letting go of its scene
## when the next one loads. The captures (tools/blender/capture_*.gd) check
## each look itself at a native display.
##
##   HOME="$PWD/.godot/hd-look-test/home" godot --headless --path . \
##     --script res://tests/hd_look_test.gd

const Hall := preload("res://scripts/hd/hd_hall.gd")
const Room := preload("res://scripts/hd/hd_room.gd")
const Portraits := preload("res://scripts/hd/hd_portraits.gd")
const Maps := preload("res://scripts/hd/hd_maps.gd")
const HALL_SCENE := "res://scenes/game_world.tscn"
const ROOM_SCENES: Array[String] = [
	"res://scenes/wake_room.tscn",
	"res://scenes/floor_1/chemistry_room.tscn",
	"res://scenes/floor_1/greenhouse_room.tscn",
	"res://scenes/floor_1/library_room.tscn",
	"res://scenes/floor_1/dining_hall_room.tscn",
	"res://scenes/floor_1/circuit_room.tscn",
	"res://scenes/floor_1/final_room.tscn",
]

var failures: Array[String] = []
var look: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var isolated := ProjectSettings.globalize_path("res://.godot/")
	if not OS.get_user_data_dir().begins_with(isolated):
		printerr("hd_look_test loads rooms, which may save: run it with HOME under " + isolated)
		quit(2)
		return
	look = root.get_node_or_null("HDLook")
	if look == null:
		_fail("The HDLook autoload is registered")
		_finish()
		return
	_expect(
		not bool(look.get("enabled")), "A --script run keeps the painted game until it asks for HD"
	)
	await _load(HALL_SCENE)
	_expect(
		not current_scene.has_node(Hall.OVERLAY_NAME) and look.get("hall_look") == null,
		"Not enabled, the Hall loads painted"
	)
	look.call("enable")
	await _wait(0.3)
	_expect(bool(look.get("enabled")), "enable() turns the HD look on")
	_expect(
		current_scene.has_node(Hall.OVERLAY_NAME) and _owns("hall_look", "hall"),
		"Enabled while the Hall shows, the Hall stages its HD look at once"
	)
	_expect(
		Portraits.showing and Portraits.hd.size() == 5,
		"The five speakers' HD portraits stand in for theirs"
	)
	for path: String in Portraits.hd:
		_expect(
			load(path) == Portraits.hd_for(path), "load() of %s gives its HD portrait" % path.get_file()
		)
	_expect(
		Maps.showing and Maps.hall_map != null and Maps.circuit_map != null,
		"The Map Hub's Hall map and the repair map are HD"
	)
	var hud := root.get_node_or_null("MapHud")
	var map_rect := hud.get("map_texture_rect") as TextureRect if hud != null else null
	if map_rect != null:
		_expect(map_rect.texture == Maps.hall_map, "The Map Hub's panel draws the HD Hall map")
	var hall_look: RefCounted = look.get("hall_look")
	_expect(
		hall_look != null and int(hall_look.get("swapped")) == 9
		and int(hall_look.get("door_count")) == 7 and bool(hall_look.get("has_depth"))
		and int(hall_look.get("sheets")) == 2,
		"The HD Hall stages its 9 props, 7 doors, depth and both HD figures (%s)" % (
			hall_look.call("summary") if hall_look != null else "none"
		)
	)
	if hall_look != null:
		_check_freed_sprites_are_let_go(hall_look)
	for scene_path: String in ROOM_SCENES:
		await _load(scene_path)
		var room_name := Room.room_for(scene_path)
		var overlay := current_scene.get_node_or_null(Room.OVERLAY_NAME) as CanvasItem
		_expect(
			overlay != null and overlay.visible and _owns("room_look", "room"),
			"%s loads in HD, its look staged over it" % room_name
		)
		_expect(look.get("hall_look") == null, "%s: the Hall's look let go of the Hall" % room_name)
		var room_look: RefCounted = look.get("room_look")
		if room_look != null:
			_expect(
				int(room_look.get("swapped")) > 0 and bool(room_look.get("has_depth"))
				and int(room_look.get("sheets")) == 2,
				"%s: its HD props, depth and figures are staged (%s)" % [room_name, room_look.call("summary")]
			)
	await _load(HALL_SCENE)
	_expect(
		current_scene.has_node(Hall.OVERLAY_NAME) and _owns("hall_look", "hall")
		and look.get("room_look") == null,
		"Back in the Hall it is HD again, and the last room's look is gone"
	)
	_finish()


## Whether the look in HDLook's `property` belongs to the scene on screen.
func _owns(property: String, root_property: String) -> bool:
	var staged: RefCounted = look.get(property)
	return staged != null and staged.get(root_property) == current_scene


## Footprints come and go with every route the Hall lays, and a Guardian can be
## freed and another staged. The depth pass and the figures must let go of what
## was freed: iterating a Dictionary still keyed by freed objects could loop for
## ever, which froze the Hall now and then (stage 69).
func _check_freed_sprites_are_let_go(hall_look: RefCounted) -> void:
	var depth: RefCounted = hall_look.get("depth")
	for _route: int in range(64):
		var print_sprite := Sprite2D.new()
		current_scene.add_child(print_sprite)
		depth.call("_track", print_sprite, null, {"tint": Color(0, 0, 0, 0), "alpha": 0.35})
		print_sprite.free()
	depth.call("advance", 0.0)
	_expect(
		_stale(depth.get("entries") as Dictionary) == 0,
		"The depth pass lets go of footprints once they are freed"
	)
	var characters: RefCounted = hall_look.get("characters")
	var body := Node2D.new()
	var stand_in := AnimatedSprite2D.new()
	body.add_child(stand_in)
	current_scene.add_child(body)
	characters.call("_swap", stand_in, body, "guardian")
	var swapped: bool = characters.call("figure_of", stand_in) != null
	body.free()
	characters.call("track", 0.0)
	characters.call("_rescan")
	_expect(
		swapped and _stale(characters.get("swaps") as Dictionary) == 0,
		"The HD figures let go of a Guardian once it is freed"
	)


## How many of a look's entries hold a sprite that has been freed.
func _stale(entries: Dictionary) -> int:
	var stale := 0
	for entry: Dictionary in entries.values():
		if not is_instance_valid(entry["sprite"]):
			stale += 1
	return stale


func _load(scene_path: String) -> void:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	await _wait(0.3)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


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
	if failures.is_empty():
		print("hd_look_test: PASS")
		quit(0)
		return
	printerr("hd_look_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
