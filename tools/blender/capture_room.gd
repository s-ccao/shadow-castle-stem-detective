extends SceneTree

## Native in-game comparison for the Blender room prototype: starts a game in
## the Wake Room (its opening done, as a returning player finds it) and shoots
## the same moments twice at 1024x768, once with the painted room and once in
## HD (tools/blender/prototype_room.gd). It checks that every interactive prop
## is staged, that the room's highlight boxes and walk-up points follow the HD
## props and go back with the painted ones, that each prop's prompt, the door's
## and the candle note's still reach the player where the game walks them, that
## the room hides the player standing behind its furniture but not on open
## floor, and that the HD detective stands at the room's size, idles and runs.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_room.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/wake_room/captures/{current,blender}/*.png.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const ROOM_NAME := "wake_room"
const ROOM_SCENE := "res://scenes/wake_room.tscn"
const DATA := "res://prototypes/blender_rooms/wake_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
## The props wake_room.gd lists, by its id and the scene node it reads.
const PROPS: Dictionary = {"bed": "Bed", "bookshelf": "Bookshelf", "desk": "Desk"}
const PROP_SHOTS: Dictionary = {"bed": "02-bed", "bookshelf": "03-bookshelf", "desk": "04-desk"}
## Behind the alchemy bench (its top stands in front of the legs), and the
## open floor by the compass where nothing stands in front of the player.
const BEHIND_BENCH := Vector2(505, 648)
const OPEN_FLOOR := Vector2(560, 470)

var room: Node2D
var look: Room
var failures: Array[String] = []
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _physics_process(delta: float) -> bool:
	if look != null:
		look.track(delta)
	return false


func _process(delta: float) -> bool:
	if look != null:
		look.advance(delta)
	return false


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("capture_room needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_wake_room()
	_expect(room != null, "The Wake Room loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Wake Room's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Wake Room render loads")
	var listed: Array = _json("render-props.json")["props"]
	var glows: Array = _json("render-glows.json")["glows"]
	_expect(
		look.halos == glows.size(), "Every glow has its halo (%d of %d)" % [look.halos, glows.size()]
	)
	_expect(
		look.swapped == listed.size() and listed.size() == 4,
		"Every interactive prop is staged in HD (%d of %d)" % [look.swapped, listed.size()]
	)
	_expect(look.has_depth, "The room's depth map loads")
	_expect(look.sheets == 2, "Both HD character sheets load (%d of 2)" % look.sheets)
	var hd_rects: Dictionary = {}
	for prop: Dictionary in listed:
		var rect: Array = prop["rect"]
		hd_rects[str(prop["id"])] = Rect2(
			float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])
		)
	var painted := _interaction_rects()
	var player := room.get_node("player") as CharacterBody2D
	player.global_position = _walkable_near(Vector2(500, 550))
	await _clear_toasts()
	await _pair("01-room")
	_rect_checks(hd_rects, painted)
	await _prop_checks(player)
	await _door_and_note_checks(player)
	await _depth_checks(player)
	await _character_checks(player)
	_show(false)
	_expect(
		not look.overlay.visible and _interaction_rects() == painted,
		"Restoring puts the painted room and its highlight boxes back"
	)
	_finish()


## The room's highlight boxes, by interaction.
func _interaction_rects() -> Dictionary:
	var rects: Dictionary = {"door": room.call("get_interaction_rect", "door")}
	for id: String in PROPS:
		rects[id] = room.call("get_interaction_rect", "prop:" + id)
	return rects


func _rect_checks(hd_rects: Dictionary, painted: Dictionary) -> void:
	_show(true)
	var staged := _interaction_rects()
	for id: String in PROPS:
		var expected: Rect2 = hd_rects[PROPS[id]]
		var shown: Rect2 = staged[id]
		_expect(
			_close(shown, expected) and not _close(shown, painted[id]),
			"The %s's highlight box follows its HD art: %s (render %s, painted %s)" % [
				id, shown, expected, painted[id],
			]
		)
		var props: Dictionary = room.get("props")
		var anchor: Vector2 = (props[id] as Dictionary)["focus_position"]
		_expect(
			anchor.distance_to(expected.get_center()) < 1.0,
			"The %s's prompt anchor is the HD prop's centre (%s)" % [id, anchor]
		)
	_expect(
		_close(staged["door"], hd_rects["Door"]),
		(
			"The door's highlight box follows the HD gate: %s (render %s)"
			% [staged["door"], hd_rects["Door"]]
		)
	)
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")


## Each prop walked up to as the game walks the player there: its prompt shows.
func _prop_checks(player: CharacterBody2D) -> void:
	for id: String in PROPS:
		_show(true)
		var props: Dictionary = room.get("props")
		var spot: Vector2 = (props[id] as Dictionary)["position"]
		_expect(
			bool(room.call("is_player_position_walkable", spot)),
			"The %s's walk-up point is open floor (%s)" % [id, spot]
		)
		player.global_position = spot
		await _wait(0.5)
		var offered: String = room.get("current_interaction")
		var body := RoomSpatialRuntime.new().get_player_collision_rect(player)
		var box: Rect2 = room.call("get_interaction_rect", "prop:" + id)
		var gap := RoomSpatialRuntime.new().rect_gap(body, box)
		# On the game's contact band round the HD prop, not the painted prop's spot.
		_expect(
			bool(room.call("_is_near_interaction", "prop:" + id)) and offered == "prop:" + id
			and absf(gap - 13.5) < 0.5,
			"Standing at the %s's walk-up point offers it (%s; at %s, %.1f px off its box)" % [
				id, offered, player.global_position, gap,
			]
		)
		_show(false)
		await _pair(PROP_SHOTS[id])


func _door_and_note_checks(player: CharacterBody2D) -> void:
	for shown: bool in [true, false]:
		_show(shown)
		player.global_position = room.get("door_position")
		await _wait(0.5)
		_expect(
			room.get("current_interaction") == "door",
			"At the door's standing point the door is offered (%s look)" % _look_name(shown)
		)
	await _pair("05-door")
	for shown: bool in [true, false]:
		_show(shown)
		player.global_position = room.get("clue_approach_position")
		await _wait(0.5)
		_expect(
			bool(room.call("_is_near_clue")),
			"In front of the window seat the candle note is in reach (%s look)" % _look_name(shown)
		)
	await _pair("06-candle-note")


## The room hides the player's legs behind the alchemy bench, never on open floor.
func _depth_checks(player: CharacterBody2D) -> void:
	_show(true)
	var image := look.depth.depth_texture.get_image()
	var behind := _walkable_near(BEHIND_BENCH)
	var open := _walkable_near(OPEN_FLOOR)
	_expect(
		behind != Vector2.INF and _hidden_rows(image, behind) >= 5,
		"Behind the alchemy bench the bench hides the player's legs (%d rows at %s)" % [
			_hidden_rows(image, behind), behind,
		]
	)
	_expect(
		open != Vector2.INF and _hidden_rows(image, open) == 0,
		"On open floor nothing hides the player (%s)" % open
	)
	player.global_position = behind
	await _wait(0.6)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
	_expect(
		sprite.material is ShaderMaterial
		and is_equal_approx(
			float((sprite.material as ShaderMaterial).get_shader_parameter("feet_y")), behind.y
		),
		"The player's sprite takes the room's depth pass, on its own feet"
	)
	_show(false)
	await _pair("07-behind-bench")


## Rows of a figure about 36 x 90 px standing at `feet` that the room hides.
func _hidden_rows(image: Image, feet: Vector2) -> int:
	var rows := 0
	for y: int in range(int(feet.y) - 88, int(feet.y) + 1, 2):
		var hidden := false
		for x: int in range(int(feet.x) - 14, int(feet.x) + 15, 2):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var color := image.get_pixel(x, y)
			var wall_y := roundi(color.r * 255.0) * 256 + roundi(color.g * 255.0)
			hidden = hidden or (color.a > 0.5 and float(wall_y) > feet.y + 0.5)
		rows += 1 if hidden else 0
	return rows


func _character_checks(player: CharacterBody2D) -> void:
	var stand := _walkable_near(Vector2(560, 420))
	player.global_position = stand
	player.set("facing_direction", Vector2.RIGHT)
	_show(true)
	await _wait(0.6)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as AnimatedSprite2D
	var sheet: Dictionary = look.characters.sheets.get("detective", {})
	var figure := look.characters.figure_of(sprite)
	_expect(
		figure != null and figure.use_parent_material and is_zero_approx(sprite.self_modulate.a),
		"The detective is drawn by its HD figure, on the game sprite's depth material"
	)
	if not sheet.is_empty():
		var shown := float(sheet["height"]) * sprite.global_scale.y
		var pixel_tall := Characters.PLAYER_FIGURE_PX * (sprite.get_parent() as Node2D).global_scale.y
		_expect(
			absf(shown - pixel_tall) < 1.0 and pixel_tall > 80.0,
			"The HD detective stands at the room's size, as tall as the pixel one (%.1f vs %.1f px)" % [
				shown, pixel_tall,
			]
		)
	var frame_before := figure.frame if figure != null else -1
	await _wait(1.0)
	_expect(
		look.characters.gait_of(sprite) == "idle" and figure != null and figure.frame != frame_before,
		"Standing plays the idle loop"
	)
	await _shot("blender", "08-detective-standing")
	Input.action_press("move_right")
	var moving: Array[String] = []
	var start := player.global_position
	for step: int in range(12):
		await _wait(0.05)
		moving.append(look.characters.gait_of(sprite))
		if step == 6:
			await _shot("blender", "09-detective-running")
	Input.action_release("move_right")
	var settled := moving.slice(moving.size() / 2)
	_expect(
		player.global_position.distance_to(start) > 40.0 and settled.count("idle") == 0,
		"Moving at the game's speed walks or runs the HD detective (%s)" % " ".join(moving)
	)
	await _wait(0.5)
	_show(false)


## The field kit's unlock cards the returning player was granted: shots of the
## room, not of the cards.
func _clear_toasts() -> void:
	for _round: int in range(3):
		await _wait(0.5)
		root.get_node("ItemRewardHud").call("dismiss_for_overlay")
		root.get_node("InventoryHud").call("_hide_feature_unlock")
		root.get_node("KeyHud").call("dismiss_unlock_toast")
	await _wait(0.4)


func _show(shown: bool) -> void:
	if shown:
		look.apply()
	else:
		look.restore()


func _pair(label: String) -> void:
	_show(false)
	await _wait(0.2)
	await _shot("current", label)
	_show(true)
	await _wait(0.3)
	await _shot("blender", label)
	_show(false)


func _look_name(shown: bool) -> String:
	return "HD" if shown else "painted"


func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA + file))


func _close(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) < 1.0
		and first.size.distance_to(second.size) < 1.0
	)


func _walkable_near(target: Vector2) -> Vector2:
	for radius: int in range(0, 96, 4):
		for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
				Vector2(0, -radius), Vector2(0, radius)]:
			if bool(room.call("is_player_position_walkable", target + offset)):
				return target + offset
	return Vector2.INF


func _enter_wake_room() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.set("learned_fire_oxygen_rule", true)
	gs.set("wake_room_door_unlocked", true)
	for flag: String in [
		"wake_room_arrival_complete", "wake_orientation_completed", "wake_flame_drilled",
		"wake_room_desk_read",
	]:
		gs.call("set_story_flag", flag)
	var wake := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await _wait(0.8)
	room = wake as Node2D


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(variant: String, label: String) -> void:
	await process_frame
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
		print("capture_room: PASS")
		quit(0)
	else:
		printerr("capture_room: FAIL (%d)" % failures.size())
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)
