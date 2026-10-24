extends SceneTree

## Playable preview of the Blender Hall prototype. Runs the real game (title
## screen, saves, every room) and lays the prototype render over the Hall
## region it covers whenever the Hall loads. Visual only, but for the HD props
## and doors: each prop is staged on its stand in the HD Hall, its node moved
## with it so its prompt and focus box follow; each door opens ajar for a
## player at it, swings open on E, or rattles if locked, before the game's own
## handler runs. The detective and the Guardian walk in their HD sheets from
## prototypes/blender_chars/. Collision, fog, the route, the Guardian's
## behaviour and saves are the game's own. Rooms rebuilt in Blender
## (tools/blender/room_prototype.py) show in HD whenever they load, through
## tools/blender/prototype_room.gd: so far the Wake Room.
##
##   HOME="$PWD/.godot/blender-proto-play/home" godot --path . \
##     --script res://tools/blender/play_prototype.gd [-- --hall]
##
## --hall skips straight to the Hall arrival, the moment the player first steps
## out of the Wake Room into the rendered region.

const DATA := "res://prototypes/blender_hall/"
const CHARACTER_DATA := "res://prototypes/blender_chars/"
const RENDER_SCALE := 2.0
const HALL_SCENE := "res://scenes/game_world.tscn"
const OVERLAY_NAME := "BlenderPrototypeOverlay"
const Glows := preload("res://tools/blender/prototype_glows.gd")
const Props := preload("res://tools/blender/prototype_props.gd")
const Depth := preload("res://tools/blender/prototype_depth.gd")
const Doors := preload("res://tools/blender/prototype_doors.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
const Room := preload("res://tools/blender/prototype_room.gd")

var glows: Glows
var props: Props
var depth: Depth
var doors: Doors
var characters: Characters
var room_look: Room


func _initialize() -> void:
	node_added.connect(_on_node_added)
	if "--hall" in OS.get_cmdline_user_args():
		call_deferred("_enter_hall_from_wake_room")
	else:
		change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


func _on_node_added(node: Node) -> void:
	if node.scene_file_path == HALL_SCENE:
		_add_overlay.call_deferred(node)
	elif not Room.room_for(node.scene_file_path).is_empty():
		_add_room.call_deferred(node, Room.room_for(node.scene_file_path))


## Stages a room's HD look once its script has read its props.
func _add_room(room: Node, room_name: String) -> void:
	if not is_instance_valid(room) or room.has_node(Room.OVERLAY_NAME):
		return
	var look := Room.new()
	if not look.attach(room, room_name):
		return
	look.apply()
	room_look = look
	print("BLENDER_PROTOTYPE_ROOM " + look.summary())


func _add_overlay(hall: Node) -> void:
	if not is_instance_valid(hall) or hall.has_node(OVERLAY_NAME):
		return
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + "region.json"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(DATA + "render.png"))
	if not (meta is Dictionary) or image == null:
		push_warning("Blender prototype render or region.json is missing under " + DATA)
		return
	var region: Array = (meta as Dictionary)["region"]
	var sprite := Sprite2D.new()
	sprite.name = OVERLAY_NAME
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2(float(region[0]), float(region[1]))
	sprite.scale = Vector2.ONE / RENDER_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Above the old floor (-100) and walls (-50); below exhibits, props, the
	# player, the footprint trail and the fog.
	sprite.z_index = -40
	hall.add_child(sprite)
	glows = Glows.new()
	var halos := glows.attach(sprite, DATA + "render-glows.json", sprite.position, RENDER_SCALE)
	props = Props.new()
	var swapped := props.attach(hall, DATA + "render-props.json", DATA, RENDER_SCALE)
	props.apply()
	doors = Doors.new()
	var door_count := doors.attach(hall, DATA + "render-doors.json", DATA, RENDER_SCALE)
	hall.add_child(doors)
	doors.apply()
	depth = Depth.new()
	var has_depth := depth.attach(hall, DATA + "render-depth.png", region)
	var depth_props := 0
	if has_depth:
		for item: Dictionary in props.standing():
			depth.add_fixed(item["sprite"], item["feet"])
		depth_props = depth.add_props((meta as Dictionary).get("props", {}))
		depth.apply()
	characters = Characters.new()
	var character_sheets := characters.attach(hall, CHARACTER_DATA)
	characters.apply()
	print(
		(
			"BLENDER_PROTOTYPE_OVERLAY region %s, %d glows, %d HD props, %d doors, depth %s (%d props), "
			+ "%d HD character sheets (%d figures)"
		)
		% [
			region, halos, swapped, door_count, has_depth, depth_props,
			character_sheets, characters.staged(),
		]
	)


func _physics_process(delta: float) -> bool:
	if characters != null:
		characters.track(delta)
	if room_look != null:
		room_look.track(delta)
	return false


func _process(delta: float) -> bool:
	if glows != null:
		glows.advance(delta)
	if depth != null:
		depth.advance(delta)
	if characters != null:
		characters.advance(delta)
	if room_look != null:
		room_look.advance(delta)
	return false


func _enter_hall_from_wake_room() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.call("add_key", "chemistry_room_key")
	gs.set("learned_fire_oxygen_rule", true)
	gs.set("wake_room_door_unlocked", true)
	var wake_flags: Array[String] = [
		"wake_room_arrival_complete", "wake_orientation_completed", "wake_flame_drilled",
	]
	for flag: String in wake_flags:
		gs.call("set_story_flag", flag)
	change_scene_to_file("res://scenes/wake_room.tscn")
	await create_timer(0.4, true, false, true).timeout
	if current_scene != null and current_scene.has_method("leave_wake_room"):
		current_scene.call("leave_wake_room")
