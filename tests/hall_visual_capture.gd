extends SceneTree

## Native Hall visual evidence: replays the real Wake Room exit, then captures
## the survival card, the opening route, fog, every Hall prop at gameplay zoom,
## fog-free art areas and a whole-Hall overview.
##
##   HOME="$PWD/.godot/hall-visual-check/home" godot --path . \
##     --script res://tests/hall_visual_capture.gd -- --out=before [--zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.

const HOME_MARKER := "res://.godot/hall-visual-"
const EVIDENCE := "res://docs/evidence/2026-10-21-hall-visual/"
const PROPS: Array[String] = [
	"WallCollisions/KnowledgeExhibits/ChemistryRoomKnowledge",
	"WallCollisions/KnowledgeExhibits/CircuitRoomKnowledge",
	"WallCollisions/KnowledgeExhibits/GreenhouseRoomKnowledge",
	"WallCollisions/KnowledgeExhibits/LibraryRoomKnowledge",
	"WallCollisions/KnowledgeExhibits/DiningHallKnowledge",
	"WallCollisions/FinalKeyMachine1",
	"WallCollisions/FinalKeyMachine2",
	"WallCollisions/FinalKeyMachine3",
	"WallCollisions/StorageRack",
]
const ART_AREAS: Dictionary = {
	"21-area-west": Vector2(330, 760),
	"22-area-centre": Vector2(960, 620),
	"23-area-north": Vector2(760, 220),
	"24-area-east": Vector2(1560, 760),
}

var failures: Array[String] = []
var hall: Node2D
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("hall_visual_capture needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var label := "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			label = argument.trim_prefix("--out=")
	out_dir = ProjectSettings.globalize_path(EVIDENCE + label + "/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ignore_path := ProjectSettings.globalize_path(EVIDENCE + ".gdignore")
	var ignore := FileAccess.open(ignore_path, FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var locale := root.get_node("CaseLocale")
	var previous_language := "zh" if locale.call("is_chinese") else "en"
	locale.call("set_language", "zh" if "--zh" in OS.get_cmdline_user_args() else "en")
	print("PROJECT_UNDER_TEST: " + ProjectSettings.globalize_path("res://"))

	await _enter_hall_from_wake_room()
	if hall == null:
		_fail("The real Wake Room exit reaches the Hall")
		_finish(previous_language)
		return
	var card_seen := await _advance_until_card()
	_expect(card_seen, "The Hall survival card appears after the arrival")
	await _shot("01-survival-card")
	var onboarding := root.get_node("OnboardingHud")
	if card_seen:
		onboarding.call("_complete_orientation")
	await _wait(1.6)
	await _shot("02-route-start")
	var route: Array = hall.get("hall_tutorial_route")
	_expect(route.size() >= 2, "The opening route is displayed")
	var player := hall.get_node("player") as CharacterBody2D
	if route.size() >= 2:
		player.global_position = route[route.size() / 3]
		await _wait(0.8)
		await _shot("03-route-ahead")

	hall.call("_set_hall_arrival_step", 4)
	for path: String in PROPS:
		var prop := hall.get_node_or_null(path) as Node2D
		_expect(prop != null, "Prop exists: " + path)
		if prop == null:
			continue
		var stand := _standing_spot_near(prop)
		_expect(stand != Vector2.INF, "A walkable viewing spot exists near " + prop.name)
		if stand == Vector2.INF:
			continue
		player.global_position = stand
		await _wait(0.5)
		await _shot("1%d-prop-%s" % [PROPS.find(path), prop.name.to_snake_case()])

	var fog := hall.get("fog_sprite") as CanvasItem
	if fog != null:
		fog.visible = false
	var camera := Camera2D.new()
	hall.add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(2, 2)
	for area: String in ART_AREAS:
		camera.global_position = ART_AREAS[area]
		await _wait(0.2)
		await _shot(area)
	camera.zoom = Vector2(1024.0 / 1920.0, 1024.0 / 1920.0)
	camera.global_position = Vector2(960, 640)
	await _wait(0.2)
	await _shot("30-overview")
	_finish(previous_language)


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
	var wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await _wait(0.3)
	wake.call("leave_wake_room")
	for _attempt: int in range(80):
		await _wait(0.1)
		if current_scene != null and current_scene.scene_file_path.ends_with("game_world.tscn"):
			hall = current_scene as Node2D
			break
	await _wait(0.6)


func _advance_until_card() -> bool:
	var onboarding := root.get_node("OnboardingHud")
	for _attempt: int in range(160):
		if (onboarding.get("overlay") as Control).visible:
			await _wait(0.6)
			return true
		var panel := hall.get("message_panel") as Control
		if panel != null and panel.visible:
			var proceed := hall.get("dialogue_continue_button") as Button
			if proceed != null and proceed.visible:
				proceed.pressed.emit()
			else:
				for child: Node in (hall.get("button_box") as Node).get_children():
					if child is Button and (child as Button).visible:
						(child as Button).pressed.emit()
						break
		await _wait(0.1)
	return false


## Nearest clear floor in front of (south of) the prop's visible feet, so the
## camera frames the artwork rather than the editor-only parent origin.
func _standing_spot_near(prop: Node2D) -> Vector2:
	var anchor := prop.global_position
	for child: Node in prop.find_children("*", "Sprite2D", true, false):
		var sprite := child as Sprite2D
		if sprite.texture == null:
			continue
		var rect := sprite.get_rect()
		var top_left := sprite.global_transform * rect.position
		var bottom_right := sprite.global_transform * rect.end
		anchor = Vector2((top_left.x + bottom_right.x) * 0.5, maxf(top_left.y, bottom_right.y))
		break
	for distance: int in range(16, 260, 8):
		for side: int in [0, -1, 1, -2, 2]:
			var candidate := anchor + Vector2(side * 24, distance)
			if bool(hall.call("is_player_position_walkable", candidate)):
				return candidate
	return Vector2.INF


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await process_frame
	# An occluded native window can withhold frame_post_draw; draw explicitly.
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), "Native 1024x768 capture: " + label)
	var suffix := "-zh" if bool(root.get_node("CaseLocale").call("is_chinese")) else ""
	_expect(image.save_png(out_dir.path_join(label + suffix + ".png")) == OK, "Saved " + label)


func _finish(previous_language: String) -> void:
	root.get_node("CaseLocale").call("set_language", previous_language)
	paused = false
	if failures.is_empty():
		print("hall_visual_capture: PASS")
		quit(0)
	else:
		printerr("hall_visual_capture: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)
