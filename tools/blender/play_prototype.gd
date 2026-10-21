extends SceneTree

## Playable preview of the Blender Hall prototype. Runs the real game (title
## screen, saves, every room) and lays the prototype render over the Hall
## region it covers whenever the Hall loads. Visual only: collision, fog, the
## route, the Guardian and saves are the game's own.
##
##   HOME="$PWD/.godot/blender-proto-play/home" godot --path . \
##     --script res://tools/blender/play_prototype.gd [-- --hall]
##
## --hall skips straight to the Hall arrival, the moment the player first steps
## out of the Wake Room into the rendered region.

const DATA := "res://prototypes/blender_hall/"
const RENDER_SCALE := 2.0
const HALL_SCENE := "res://scenes/game_world.tscn"
const OVERLAY_NAME := "BlenderPrototypeOverlay"


func _initialize() -> void:
	node_added.connect(_on_node_added)
	if "--hall" in OS.get_cmdline_user_args():
		call_deferred("_enter_hall_from_wake_room")
	else:
		change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


func _on_node_added(node: Node) -> void:
	if node.scene_file_path == HALL_SCENE:
		_add_overlay.call_deferred(node)


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
	print("BLENDER_PROTOTYPE_OVERLAY region %s" % [region])


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
