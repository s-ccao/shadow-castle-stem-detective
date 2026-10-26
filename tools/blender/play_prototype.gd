extends SceneTree

## Plays the game with its HD look, starting where a flag says. The HD look is
## the game's own (scripts/hd/hd_look.gd, the HDLook autoload: the Hall and
## every room rebuilt in Blender, published under assets/hd/ by
## tools/blender/publish_hd.py); a --script run such as this one keeps the
## painted game unless it turns the look on, which this does. Use it to play a
## room straight away after publishing a render.
##
##   HOME="$PWD/.godot/blender-proto-play/home" godot --path . \
##     --script res://tools/blender/play_prototype.gd \
##     [-- --hall | --greenhouse | --chemistry | --library | --library-ready | --dining
##      | --circuit | --final]
##
## --hall skips straight to the Hall arrival, the moment the player first steps
## out of the Wake Room into the rendered region. --greenhouse opens the
## Greenhouse at its gate, as the room does when it is played on its own;
## --chemistry opens the Chemistry Room in its doorway the same way, and
## --library the Library. --library-ready opens it with its three light tests
## passed, so seating the three filters at the optical array awakens it.
## --dining opens the Dining Hall at its door, --circuit the Circuit Room, and
## --final the Final Room. Without a flag it starts at the title screen.

const GREENHOUSE_SCENE := "res://scenes/floor_1/greenhouse_room.tscn"
const CHEMISTRY_SCENE := "res://scenes/floor_1/chemistry_room.tscn"
const LIBRARY_SCENE := "res://scenes/floor_1/library_room.tscn"
const DINING_SCENE := "res://scenes/floor_1/dining_hall_room.tscn"
const CIRCUIT_SCENE := "res://scenes/floor_1/circuit_room.tscn"
const FINAL_SCENE := "res://scenes/floor_1/final_room.tscn"


func _initialize() -> void:
	root.get_node("HDLook").call("enable")
	if "--hall" in OS.get_cmdline_user_args():
		call_deferred("_enter_hall_from_wake_room")
	elif "--greenhouse" in OS.get_cmdline_user_args():
		change_scene_to_file.call_deferred(GREENHOUSE_SCENE)
	elif "--chemistry" in OS.get_cmdline_user_args():
		change_scene_to_file.call_deferred(CHEMISTRY_SCENE)
	elif "--library-ready" in OS.get_cmdline_user_args():
		call_deferred("_enter_library", true)
	elif "--library" in OS.get_cmdline_user_args():
		call_deferred("_enter_library", false)
	elif "--dining" in OS.get_cmdline_user_args():
		change_scene_to_file.call_deferred(DINING_SCENE)
	elif "--circuit" in OS.get_cmdline_user_args():
		change_scene_to_file.call_deferred(CIRCUIT_SCENE)
	elif "--final" in OS.get_cmdline_user_args():
		change_scene_to_file.call_deferred(FINAL_SCENE)
	else:
		change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


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


## Opens the Library at its door, as the room does when it is played on its
## own; with `filters_earned`, its three light tests already passed.
func _enter_library(filters_earned: bool) -> void:
	if filters_earned:
		var gs := root.get_node("GameState")
		for colour: String in ["red", "green", "blue"]:
			gs.call("set_story_flag", "library_%s_filter_earned" % colour)
	change_scene_to_file(LIBRARY_SCENE)
