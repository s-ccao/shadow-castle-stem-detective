extends SceneTree

## Native in-game comparison for the Blender Hall prototype: replays the real
## Wake Room exit, then captures the same gameplay moments twice at 1024x768,
## once with the current Hall art and once with the prototype render laid over
## it (visual only: collision, fog, route and every node stay as they are).
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_prototype.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_hall/captures/{current,blender}/*.png.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const DATA := "res://prototypes/blender_hall/"
const RENDER_SCALE := 2.0
const Glows := preload("res://tools/blender/prototype_glows.gd")
const Props := preload("res://tools/blender/prototype_props.gd")
const Depth := preload("res://tools/blender/prototype_depth.gd")
## Gameplay shots: where the player stands. Each keeps the zoomed camera view
## inside the rendered region so no old art shows at the frame edges.
const PLAYER_SHOTS: Dictionary = {
	"01-arrival": Vector2(224, 984),
	"02-first-corridor": Vector2(430, 1000),
	"03-wake-gate": Vector2(258, 1090),
	# Feet against a wall's north side: the wall stands in front.
	"04-behind-wall": Vector2(519, 1019),
}
## Art-only shots with the fog lifted: camera centres at gameplay zoom.
const ART_SHOTS: Dictionary = {
	"11-art-arrival": Vector2(300, 1010),
	"12-art-centre": Vector2(700, 960),
}

var hall: Node2D
var overlay: Sprite2D
var props: Props
var depth: Depth
var failures: Array[String] = []
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("capture_prototype needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var locale := root.get_node("CaseLocale")
	var chinese := "--zh" in OS.get_cmdline_user_args()
	locale.call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "region.json"))
	var region: Array = meta["region"]
	await _enter_hall_from_wake_room()
	if hall == null:
		_fail("The real Wake Room exit reaches the Hall")
		_finish()
		return
	_expect(await _advance_until_card(), "The Hall survival card appears after the arrival")
	root.get_node("OnboardingHud").call("_complete_orientation")
	await _wait(1.2)
	overlay = _make_overlay(Vector2(float(region[0]), float(region[1])))
	_expect(overlay != null, "The prototype render loads")
	props = Props.new()
	var swapped := props.attach(hall, DATA + "render-props.json", DATA, RENDER_SCALE)
	_expect(swapped > 0, "The HD props load")
	depth = Depth.new()
	_expect(depth.attach(hall, DATA + "render-depth.png", region), "The depth map loads")
	for item: Dictionary in props.standing():
		depth.add_fixed(item["sprite"], item["feet"])
	if overlay == null:
		_finish()
		return
	var player := hall.get_node("player") as CharacterBody2D
	for shot: String in PLAYER_SHOTS:
		var spot := _walkable_near(PLAYER_SHOTS[shot] as Vector2)
		# The spot is logged: when a moving body blocks the exact target, the
		# shot is framed from the nearest free spot instead.
		_expect(spot != Vector2.INF, "A walkable spot exists for %s at %s" % [shot, spot])
		if spot == Vector2.INF:
			continue
		player.global_position = spot
		await _wait(0.9)
		await _pair(shot)
	var fog := hall.get("fog_sprite") as CanvasItem
	if fog != null:
		fog.visible = false
	var camera := Camera2D.new()
	hall.add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(2, 2)
	for shot: String in ART_SHOTS:
		camera.global_position = ART_SHOTS[shot]
		await _wait(0.3)
		await _pair(shot)
	camera.zoom = Vector2.ONE
	camera.global_position = Vector2(
		float(region[0]) + float(region[2]) * 0.5, float(region[1]) + float(region[3]) * 0.5
	)
	await _wait(0.3)
	await _pair("20-region-overview")
	_finish()


func _make_overlay(origin: Vector2) -> Sprite2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DATA + "render.png"))
	if image == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "BlenderPrototypeOverlay"
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = origin
	sprite.scale = Vector2.ONE / RENDER_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Above the old floor (-100) and walls (-50); below exhibits, props, the
	# player, the footprint trail and the fog.
	sprite.z_index = -40
	sprite.visible = false
	hall.add_child(sprite)
	# The halos at rest: the preview animates them, a still shows their mean.
	Glows.new().attach(sprite, DATA + "render-glows.json", origin, RENDER_SCALE)
	return sprite


func _pair(label: String) -> void:
	overlay.visible = false
	depth.restore()
	props.restore()
	await _wait(0.15)
	await _shot("current", label)
	overlay.visible = true
	props.apply()
	depth.apply()
	await _wait(0.15)
	await _shot("blender", label)
	overlay.visible = false
	depth.restore()
	props.restore()


func _walkable_near(target: Vector2) -> Vector2:
	for radius: int in range(0, 96, 4):
		for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
				Vector2(0, -radius), Vector2(0, radius)]:
			var candidate := target + offset
			if bool(hall.call("is_player_position_walkable", candidate)):
				return candidate
	return Vector2.INF


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


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(variant: String, label: String) -> void:
	await process_frame
	# An occluded native window can withhold frame_post_draw; draw explicitly.
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var suffix := "-zh" if bool(root.get_node("CaseLocale").call("is_chinese")) else ""
	var directory := out_dir.path_join(variant)
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(
		image.get_size() == Vector2i(1024, 768),
		"Native 1024x768 capture: %s/%s" % [variant, label]
	)
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label)


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("capture_prototype: PASS")
		quit(0)
	else:
		printerr("capture_prototype: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)
