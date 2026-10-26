extends Node

## The game's HD look. The Hall and every room were rebuilt in Blender
## (tools/blender/) and published under assets/hd/; whenever the Hall or a room
## loads, this stages its HD look over the painted scene (hd_hall.gd,
## hd_room.gd): the render and its living light, the HD props and doors, the
## depth pass that hides figures behind walls and furniture, and the detective,
## the Guardian and the cast in HD. The speakers' portraits and the Map Hub's
## maps are HD from the start. Prompts, the story and saves are the game's own;
## a room built at a real size swaps its own footprints in.
##
## A run under a --script main loop (the headless suites, and the Blender
## captures and audits, which stage the look themselves to compare it with the
## painted game) keeps the painted game unless it passes --hd or calls enable()
## (tools/blender/play_prototype.gd does).

const Hall := preload("res://scripts/hd/hd_hall.gd")
const Room := preload("res://scripts/hd/hd_room.gd")
const Portraits := preload("res://scripts/hd/hd_portraits.gd")
const Maps := preload("res://scripts/hd/hd_maps.gd")
const HDData := preload("res://scripts/hd/hd_data.gd")

var enabled := false
var hall_look: Hall
var room_look: Room


func _ready() -> void:
	# The figures, glows and living light carry on through pauses and dialogue,
	# and each frame and physics tick they read the bodies before the game's
	# own nodes move them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	process_physics_priority = -100
	get_tree().node_added.connect(_on_node_added)
	if get_tree().get_script() == null or "--hd" in OS.get_cmdline_user_args():
		enable()


## Shows the HD look from now on: the portraits and maps at once, and the
## Hall or room on screen, then each as it loads.
func enable() -> void:
	if enabled:
		return
	enabled = true
	if Portraits.attach() > 0:
		Portraits.stage(true, null)
	if Maps.attach() > 0:
		Maps.stage(true, get_tree())
	var scene := get_tree().current_scene
	if scene != null:
		_on_node_added(scene)


## At exit, lets go of what the look kept for the session, so nothing is left
## in use when the engine shuts down.
func _exit_tree() -> void:
	hall_look = null
	room_look = null
	HDData.release()
	Portraits.hd.clear()
	Portraits.pixel.clear()
	Maps.hall_map = null
	Maps.circuit_map = null
	Maps.repair_board = null


func _on_node_added(node: Node) -> void:
	if not enabled:
		return
	if node.scene_file_path == Hall.SCENE:
		_stage_hall.call_deferred(node)
	elif not Room.room_for(node.scene_file_path).is_empty():
		_stage_room.call_deferred(node, Room.room_for(node.scene_file_path))


## Stages the Hall's HD look once its script has read its props.
func _stage_hall(hall: Node) -> void:
	if not is_instance_valid(hall) or hall.has_node(Hall.OVERLAY_NAME):
		return
	var look := Hall.new()
	if look.attach(hall):
		hall_look = look
		print("HD_LOOK hall: " + look.summary())


## Stages a room's HD look once its script has read its props.
func _stage_room(room: Node, room_name: String) -> void:
	if not is_instance_valid(room) or room.has_node(Room.OVERLAY_NAME):
		return
	var look := Room.new()
	if not look.attach(room, room_name):
		return
	look.apply()
	room_look = look
	print("HD_LOOK room " + look.summary())


func _physics_process(delta: float) -> void:
	_drop_freed()
	if hall_look != null:
		hall_look.track(delta)
	if room_look != null:
		room_look.track(delta)


func _process(delta: float) -> void:
	_drop_freed()
	if hall_look != null:
		hall_look.advance(delta)
	if room_look != null:
		room_look.advance(delta)


## Forgets a look whose scene has left the tree, with what it held: the game
## changes scenes with change_scene_to_file, which frees the old one at the
## end of the frame, and its look must not run on it meanwhile.
func _drop_freed() -> void:
	if hall_look != null and not _in_tree(hall_look.hall):
		hall_look = null
	if room_look != null and not _in_tree(room_look.room):
		room_look = null


## Untyped: a typed parameter would reject a freed node before it is checked.
func _in_tree(node: Variant) -> bool:
	return is_instance_valid(node) and (node as Node).is_inside_tree()
