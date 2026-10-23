extends SceneTree

## Native in-game comparison for the Blender Hall prototype: replays the real
## Wake Room exit, then captures the same gameplay moments twice at 1024x768,
## once with the current Hall art and once with the prototype render laid over
## it (visual only, but for the HD props: each is staged on its stand, its node
## moved with it; collision, fog and the route stay as they are). Each staged
## prop is also shot with the player walked up to it, where its prompt must
## show and no door's. The detective and the Guardian are shot standing side
## by side in both looks, and the detective once walking in HD.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_prototype.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_hall/captures/{current,blender}/*.png.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const DATA := "res://prototypes/blender_hall/"
const CHARACTER_DATA := "res://prototypes/blender_chars/"
const RENDER_SCALE := 2.0
const Glows := preload("res://tools/blender/prototype_glows.gd")
const Props := preload("res://tools/blender/prototype_props.gd")
const Depth := preload("res://tools/blender/prototype_depth.gd")
const Doors := preload("res://tools/blender/prototype_doors.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
const WALKS: Array[StringName] = [
	&"walk_down", &"walk_down_right", &"walk_right", &"walk_up_right",
	&"walk_up", &"walk_up_left", &"walk_left", &"walk_down_left",
]
## Gameplay shots: where the player stands. Each keeps the zoomed camera view
## inside the rendered region so no old art shows at the frame edges.
const PLAYER_SHOTS: Dictionary = {
	"01-arrival": Vector2(224, 984),
	"02-first-corridor": Vector2(430, 1000),
	# On the landing behind the Wake gate: it stands ajar in front of them.
	"03-wake-gate": Vector2(247, 1098),
	# Feet against a wall's north side: the wall stands in front.
	"04-behind-wall": Vector2(519, 1019),
	# Every Hall door, the player at its prompt just beside the portal so the
	# door itself stays in view.
	"05-chemistry-door": Vector2(330, 140),
	"06-final-door": Vector2(961, 128),
	"07-library-door": Vector2(1695, 292),
	"08-greenhouse-door": Vector2(213, 394),
	"09-circuit-door": Vector2(161, 738),
	"10-dining-door": Vector2(1815, 714),
}
## Art-only shots with the fog lifted: camera centres at gameplay zoom.
const ART_SHOTS: Dictionary = {
	"11-art-arrival": Vector2(300, 1010),
	"12-art-centre": Vector2(700, 960),
	"13-art-north-west": Vector2(330, 250),
	"14-art-north": Vector2(933, 160),
	"15-art-north-east": Vector2(1580, 300),
	"16-art-east": Vector2(1660, 860),
	"17-art-heart": Vector2(1000, 620),
}
## Each staged HD prop, shot with the player walked up beside it.
const PROP_SHOTS: Dictionary = {
	"ChemistryRoomKnowledge": "21-prop-chemistry-core",
	"CircuitRoomKnowledge": "22-prop-circuit-exhibit",
	"LibraryRoomKnowledge": "23-prop-light-console",
	"GreenhouseRoomKnowledge": "24-prop-greenhouse-case",
	"DiningHallKnowledge": "25-prop-dining-clock",
	"StorageRack": "26-prop-storage-rack",
	"FinalKeyMachine1": "27-prop-tower-machine",
	"FinalKeyMachine2": "28-prop-engine-machine",
	"FinalKeyMachine3": "29-prop-workshop-machine",
}
## Where a prop's own prompt shows, no door's may: doors take priority.
const DOOR_INTERACTIONS: Array[String] = [
	"chemistry_room_door", "greenhouse_room_door", "library_door", "dining_hall_door",
	"final_room_door", "wake_room_door", "circuit_door",
]

var hall: Node2D
var overlay: Sprite2D
var props: Props
var depth: Depth
var doors: Doors
var characters: Characters
var failures: Array[String] = []
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


## Keeps the depth shader on the figures' current feet, as the preview does.
func _process(delta: float) -> bool:
	if depth != null:
		depth.advance(delta)
	if characters != null:
		characters.advance(delta)
	return false


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
	var listed: Dictionary = meta.get("props", {})
	_expect(
		swapped == listed.size(),
		"Every listed prop is staged in HD (%d of %d)" % [swapped, listed.size()]
	)
	depth = Depth.new()
	_expect(depth.attach(hall, DATA + "render-depth.png", region), "The depth map loads")
	for item: Dictionary in props.standing():
		depth.add_fixed(item["sprite"], item["feet"])
	_expect(depth.add_props(listed) == listed.size(), "Every listed prop takes the depth shader")
	doors = Doors.new()
	# Captures never go through a door: a press plays it but stops short of the game.
	doors.dry_run = true
	var door_count := doors.attach(hall, DATA + "render-doors.json", DATA, RENDER_SCALE)
	hall.add_child(doors)
	_expect(door_count == 7, "Every Hall door plays in HD (%d of 7)" % door_count)
	characters = Characters.new()
	var sheet_count := characters.attach(hall, CHARACTER_DATA)
	_expect(sheet_count == 2, "Both HD character sheets load (%d of 2)" % sheet_count)
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
	await _prop_shots(player)
	await _door_checks(player)
	await _character_checks(player)
	var fog := hall.get("fog_sprite") as CanvasItem
	if fog != null:
		fog.visible = false
	# Off the last door, so its prompt does not ride along into the art shots.
	var rest := _walkable_near(PLAYER_SHOTS["04-behind-wall"] as Vector2)
	if rest != Vector2.INF:
		player.global_position = rest
		await _wait(0.5)
	var camera := Camera2D.new()
	hall.add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(2, 2)
	for shot: String in ART_SHOTS:
		camera.global_position = ART_SHOTS[shot]
		await _wait(0.3)
		await _pair(shot)
	# The whole region on one screen.
	var fit := minf(1.0, minf(1024.0 / float(region[2]), 768.0 / float(region[3])))
	camera.zoom = Vector2(fit, fit)
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
	_show_prototype(false)
	await _wait(0.15)
	await _shot("current", label)
	_show_prototype(true)
	# Long enough for a door at the player to swing ajar.
	await _wait(0.35)
	await _shot("blender", label)
	_show_prototype(false)


## The prototype's look (render, staged props, depth, doors, characters) on or off.
func _show_prototype(shown: bool) -> void:
	overlay.visible = shown
	if shown:
		props.apply()
		depth.apply()
		doors.apply()
		characters.apply()
	else:
		characters.restore()
		depth.restore()
		props.restore()
		doors.restore()


## The doors do as the user asked. A locked door stays shut as the player
## walks up; E rattles it, then the game says what it needs. An open door
## stands ajar for the player, swings wide on E and shuts behind them. The
## Wake gate, always open, stands ajar in front of a player behind it.
func _door_checks(player: CharacterBody2D) -> void:
	var state := root.get_node("GameState")
	_show_prototype(true)
	player.global_position = _walkable_near(PLAYER_SHOTS["05-chemistry-door"] as Vector2)
	await _wait(0.5)
	_expect(doors.frame_of("Chemistry") == 0, "A locked door stays shut as the player walks up")
	doors.dry_run = false
	doors.press("Chemistry")
	var rattled := false
	for _step: int in range(14):
		await _wait(0.03)
		rattled = rattled or doors.frame_of("Chemistry") == 1
	await _wait(0.25)
	var panel := hall.get("message_panel") as CanvasItem
	_expect(
		rattled and doors.last_handled == "Chemistry",
		"E at a locked door rattles it, then the game takes E"
	)
	_expect(panel != null and panel.visible, "The game then says what the locked door needs")
	await _shot("blender", "30-door-locked")
	hall.call("close_message_panel")
	doors.dry_run = true
	await _wait(0.3)
	state.call("set_story_flag", "door_library_unlocked")
	player.global_position = _walkable_near(PLAYER_SHOTS["07-library-door"] as Vector2)
	await _wait(0.6)
	_expect(doors.frame_of("Library") == 4, "An open door stands ajar for the player at it")
	await _shot("blender", "31-door-ajar")
	doors.last_handled = ""
	doors.press("Library")
	var opened := false
	for _step: int in range(20):
		await _wait(0.03)
		opened = opened or doors.frame_of("Library") == 9
	_expect(
		opened and doors.last_handled == "Library",
		"E at an open door swings it wide before the game goes through"
	)
	doors.force("Library", 9)
	await _wait(0.2)
	await _shot("blender", "32-door-open")
	doors.force("Library", -1)
	player.global_position = _walkable_near(PLAYER_SHOTS["04-behind-wall"] as Vector2)
	await _wait(0.6)
	_expect(doors.frame_of("Library") == 0, "The door shuts behind a player who walks away")
	player.global_position = _walkable_near(PLAYER_SHOTS["03-wake-gate"] as Vector2)
	await _wait(0.6)
	_expect(doors.frame_of("Wake") == 4, "The Wake gate stands ajar in front of a player behind it")
	await _shot("blender", "33-wake-gate-ajar")
	_show_prototype(false)


## The HD figures stand where the pixel ones did and play the game's walks.
## The detective is as tall as the pixel one on the same feet. For one pair of
## shots the Hall's tutorial is held (it walks the Guardian along its route
## every frame) and the Guardian stands facing the player across open floor;
## then both go back as the game had them, and the player walks that way.
func _character_checks(player: CharacterBody2D) -> void:
	var sprite := player.get_node("VisualRoot/CharacterSprite") as AnimatedSprite2D
	var pixel_frames := sprite.sprite_frames
	var pixel_place := [sprite.position, sprite.scale, sprite.texture_filter]
	var enemy := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	_expect(enemy != null, "The Hall has its Castle Guardian")
	if enemy == null:
		return
	var guardian := enemy.get_node("GuardianCore") as AnimatedSprite2D
	var guardian_pixel := guardian.sprite_frames
	var enemy_state := [
		enemy.visible,
		enemy.global_position,
		enemy.is_physics_processing(),
		enemy.get("facing_direction"),
	]
	var stand := _walkable_near(PLAYER_SHOTS["02-first-corridor"] as Vector2)
	var way := _clear_way(stand) if stand != Vector2.INF else Vector2.ZERO
	_expect(way != Vector2.ZERO, "Open floor beside the player for the Guardian (%s)" % way)
	if way == Vector2.ZERO:
		return
	# The game's screen angles turn clockwise from +x; WALKS turns from down.
	var facing := -way
	var guardian_walk := WALKS[posmod(roundi((PI / 2.0 - facing.angle()) / (PI / 4.0)), 8)]
	player.global_position = stand
	player.set("facing_direction", way)
	hall.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = stand + way * 60.0
	enemy.visible = true
	enemy.set("facing_direction", facing)
	guardian.animation = guardian_walk
	guardian.stop()
	guardian.frame = 0
	await _wait(0.9)
	_show_prototype(true)
	await _wait(0.6)
	var detective_sheet: Dictionary = characters.sheets.get("detective", {})
	var guardian_sheet: Dictionary = characters.sheets.get("guardian", {})
	_expect(
		not detective_sheet.is_empty() and sprite.sprite_frames == detective_sheet["frames"],
		"The detective plays the HD sheet"
	)
	_expect(
		not guardian_sheet.is_empty() and guardian.sprite_frames == guardian_sheet["frames"],
		"The Guardian plays the HD sheet"
	)
	for frames: SpriteFrames in [sprite.sprite_frames, guardian.sprite_frames]:
		var complete := true
		for walk: StringName in WALKS:
			complete = complete and frames.has_animation(walk) and frames.get_frame_count(walk) == 8
		_expect(complete, "Every one of the game's 8 walks has 8 HD frames")
	if not detective_sheet.is_empty():
		var shown := float(detective_sheet["height"]) * sprite.global_scale.y
		var pixel_tall := Characters.PLAYER_FIGURE_PX * (sprite.get_parent() as Node2D).global_scale.y
		_expect(
			absf(shown - pixel_tall) < 1.0,
			"The HD detective stands as tall as the pixel one (%.1f vs %.1f px)" % [shown, pixel_tall]
		)
		var cell: Vector2 = detective_sheet["cell"]
		var feet_row := (detective_sheet["feet"] as Vector2).y - cell.y * 0.5
		var off := sprite.global_position.y + feet_row * sprite.global_scale.y - player.global_position.y
		_expect(
			absf(off) < 0.5, "The HD detective's feet are on the body's origin (%.2f px off)" % off
		)
	_expect(
		guardian.animation == guardian_walk and guardian.frame == 0 and not guardian.is_playing(),
		(
			"The standing Guardian keeps its facing on its standing frame (%s %d, playing %s)"
			% [guardian.animation, guardian.frame, guardian.is_playing()]
		)
	)
	_show_prototype(false)
	# The fog would hide whichever figure stands outside the player's light.
	var fog := hall.get("fog_sprite") as CanvasItem
	var fog_shown := fog != null and fog.visible
	if fog != null:
		fog.visible = false
	await _pair("34-characters-standing")
	if fog != null:
		fog.visible = fog_shown
	_expect(
		sprite.sprite_frames == pixel_frames and guardian.sprite_frames == guardian_pixel
		and sprite.position == pixel_place[0] and sprite.scale == pixel_place[1]
		and sprite.texture_filter == pixel_place[2],
		"Restoring gives both figures their pixel frames and place back"
	)
	enemy.global_position = enemy_state[1]
	enemy.set("facing_direction", enemy_state[3])
	enemy.visible = enemy_state[0]
	enemy.set_physics_process(enemy_state[2])
	hall.set_process(true)
	_show_prototype(true)
	await _wait(0.3)
	var start := player.global_position
	var actions: Array[String] = []
	for pair: Array in [
		[way.x > 0.5, "move_right"], [way.x < -0.5, "move_left"],
		[way.y > 0.5, "move_down"], [way.y < -0.5, "move_up"],
	]:
		if pair[0]:
			actions.append(pair[1])
	for action: String in actions:
		Input.action_press(action)
	var first := -1
	var advanced := false
	var seen: Array[String] = []
	for step: int in range(16):
		await _wait(0.05)
		seen.append("%s:%d%s" % [sprite.animation, sprite.frame, "+" if sprite.is_playing() else ""])
		if sprite.animation in WALKS and sprite.is_playing():
			if first < 0:
				first = sprite.frame
			advanced = advanced or sprite.frame != first
		# Mid-stride, still on the open floor the Guardian stood on.
		if step == 7:
			await _shot("blender", "35-detective-walking")
	_expect(
		advanced and sprite.sprite_frames == detective_sheet.get("frames"),
		(
			"Walking plays the HD walk frames (%s, moved %.0f px: %s)"
			% [" + ".join(actions), player.global_position.distance_to(start), " ".join(seen)]
		)
	)
	for action: String in actions:
		Input.action_release(action)
	await _wait(0.4)
	_expect(
		sprite.frame == 0 and not sprite.is_playing(),
		"Stopping shows the HD standing frame"
	)
	_show_prototype(false)
	player.global_position = stand


## The way from `from` with the longest run of walkable floor, up to 120 px.
func _clear_way(from: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_run := 0.0
	for step: int in range(8):
		var way := Vector2.RIGHT.rotated(step * PI / 4.0)
		var run := 0.0
		while run < 120.0 and bool(hall.call("is_player_position_walkable", from + way * (run + 8.0))):
			run += 8.0
		if run > best_run:
			best_run = run
			best = way
	return best if best_run >= 96.0 else Vector2.ZERO


func _walkable_near(target: Vector2) -> Vector2:
	for radius: int in range(0, 96, 4):
		for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
				Vector2(0, -radius), Vector2(0, radius)]:
			var candidate := target + offset
			if bool(hall.call("is_player_position_walkable", candidate)):
				return candidate
	return Vector2.INF


## Every staged prop with the player walked up beside it, in both looks. In
## the HD Hall the prop's own prompt must reach the player there, and no
## door's (doors take priority over every prop).
func _prop_shots(player: CharacterBody2D) -> void:
	var depth_image := depth.depth_texture.get_image()
	for swap: Dictionary in props.swaps:
		var root := swap["root"] as Node
		var prop_id := str(root.name)
		var interaction := _interaction_for(prop_id)
		props.apply()
		var spot := _prop_spot(player, interaction, swap["rect"] as Rect2, depth_image)
		props.restore()
		_expect(
			spot != Vector2.INF,
			"%s: walked up to at %s, its prompt shows there and no door's" % [prop_id, spot]
		)
		if spot == Vector2.INF or not PROP_SHOTS.has(prop_id):
			continue
		player.global_position = spot
		await _wait(0.9)
		await _pair(PROP_SHOTS[prop_id])


## A spot beside the prop, in full view, where its prompt shows and no door's.
func _prop_spot(
	player: CharacterBody2D, interaction: String, rect: Rect2, depth_image: Image
) -> Vector2:
	var right := rect.end.x + 10.0
	var left := rect.position.x - 10.0
	var centre := rect.get_center().x
	var tries: Array[Vector2] = []
	for step: Vector2 in [
		Vector2(right, 5.0), Vector2(left, 5.0), Vector2(right, 14.0), Vector2(left, 14.0),
		Vector2(centre, 12.0), Vector2(centre, 24.0), Vector2(right, 30.0), Vector2(left, 30.0),
		Vector2(centre, 40.0), Vector2(right, 48.0), Vector2(left, 48.0), Vector2(centre, 56.0),
	]:
		tries.append(Vector2(step.x, rect.end.y + step.y))
	for target: Vector2 in tries:
		var spot := _walkable_near(target)
		if spot == Vector2.INF or _behind_wall(depth_image, spot):
			continue
		player.global_position = spot
		if not bool(hall.call("_is_near_hall_interaction", interaction)):
			continue
		var door_near := false
		for door: String in DOOR_INTERACTIONS:
			door_near = door_near or bool(hall.call("_is_near_hall_interaction", door))
		if not door_near:
			return spot
	return Vector2.INF


## Whether a wall's top hides part of a figure standing at `feet`: at the
## preview's figure scale it shows about 20 x 48 px above its feet.
func _behind_wall(image: Image, feet: Vector2) -> bool:
	for y: int in range(int(feet.y) - 48, int(feet.y) + 1, 2):
		for x: int in range(int(feet.x) - 10, int(feet.x) + 11, 2):
			var px := Vector2i(x, y) - Vector2i(depth.origin)
			if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height():
				continue
			var color := image.get_pixelv(px)
			var wall_y := roundi(color.r * 255.0) * 256 + roundi(color.g * 255.0)
			if color.a > 0.5 and float(wall_y) > feet.y + 0.5:
				return true
	return false


func _interaction_for(prop_id: String) -> String:
	if prop_id == "StorageRack":
		return "hidden_library_key"
	if prop_id.begins_with("FinalKeyMachine"):
		return "final_key_machine_" + prop_id.trim_prefix("FinalKeyMachine")
	return "hall_knowledge:" + prop_id


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
