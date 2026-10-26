extends SceneTree

## Native in-game comparison for the Blender Dining Hall: starts a game in the
## Dining Hall and shoots the same moments twice at 1024x768, once with the
## painted room and once in HD (tools/blender/prototype_room.gd). It checks
## that every prop is staged, that the room's highlight boxes follow the HD
## props and go back with the painted ones, that the props the room render
## draws (so the player walks round the table and up to the rest) are staged
## undrawn while the chandelier hangs drawn above everyone, that each prop's
## prompt and the door's still reach the player standing beside them, that the
## table hides the player behind it but nothing hides them in front of it or
## on open floor, that the main door's arch hides at most the feet of a player
## at it, and that the HD detective stands at the room's size and walks.
##
##   HOME="$PWD/.godot/blender-proto-dining/home" godot --path . \
##     --script res://tools/blender/capture_dining_hall.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/dining_hall_room/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-dining"
const ROOM_NAME := "dining_hall_room"
const ROOM_SCENE := "res://scenes/floor_1/dining_hall_room.tscn"
const DATA := "res://prototypes/blender_rooms/dining_hall_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
## dining_hall_room.gd's interaction items by the render's prop ids, and where
## the player stands to use each: in reach of its box in both looks, or, where
## the HD furniture is a real size and the painted stand is out of its reach,
## at "hd_stand" in the HD look (beside the sideboard's open drawer).
const PROPS: Dictionary = {
	"DiningTable": {"item": "dining_table", "stand": Vector2(628, 690), "shot": "02-table"},
	"Fireplace": {"item": "fireplace", "stand": Vector2(174, 372), "shot": "03-hearth"},
	"WallDoor": {"item": "wall_door", "stand": Vector2(1225, 290), "shot": "04-wall-door"},
	"GrandfatherClock": {"item": "grandfather_clock", "stand": Vector2(1333, 605), "shot": "05-clock"},
	"Sideboard": {
		"item": "sideboard", "stand": Vector2(1200, 870), "hd_stand": Vector2(1296, 812),
		"shot": "06-sideboard",
	},
	"Cabinet": {"item": "cabinet", "stand": Vector2(226, 760), "shot": "07-dresser"},
}
## Drawn by the room render: the six above and the main door.
const IN_ROOM: Array[String] = [
	"DiningTable", "Fireplace", "WallDoor", "GrandfatherClock", "Sideboard", "Cabinet", "MainDoor",
]
const CHANDELIER := "ChandelierSprite"
## The furnishings the HD hall adds (stage 67), each at a spot inside its own
## footprint: in the HD look the player cannot stand there; in the painted
## room the floor is open again (but the trophy's, which the painted clock's
## collision already covers).
const FURNISHINGS: Dictionary = {
	"west window bench": {"spot": Vector2(502, 276), "painted_open": true},
	"east window bench": {"spot": Vector2(945, 276), "painted_open": true},
	"fireside chairs": {"spot": Vector2(112, 470), "painted_open": true},
	"heraldic trophy": {"spot": Vector2(1330, 440), "painted_open": false},
	"chest": {"spot": Vector2(158, 950), "painted_open": true},
	"casks": {"spot": Vector2(1150, 946), "painted_open": true},
	"west candelabrum": {"spot": Vector2(606, 900), "painted_open": true},
	"east candelabrum": {"spot": Vector2(842, 900), "painted_open": true},
}
## North of the table its chairs' backs stand in front of the player; in front
## of its south chairs and on the open floor nothing does.
const BEHIND_TABLE := Vector2(620, 458)
const BEFORE_TABLE := Vector2(628, 760)
const OPEN_FLOOR := Vector2(1100, 700)
## The main door's own collision stops the player 14.2 px short of the exit's
## box in its middle, so the way back is offered in the doorway's west jamb,
## where the wall's outline lets the player step further in.
const LEAVING := Vector2(651, 965)
const AT_DOOR := Vector2(724, 955)

var room: Node2D
var look: Room
var player: CharacterBody2D
var runtime: Node
var spatial := RoomSpatialRuntime.new()
var failures: Array[String] = []
var checks := 0
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
		printerr("capture_dining_hall needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_dining_hall()
	_expect(room != null, "The Dining Hall loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Dining Hall's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Dining Hall render loads")
	var listed: Array = _json("render-props.json")["props"]
	var glows: Array = _json("render-glows.json")["glows"]
	_expect(
		look.halos == glows.size(), "Every glow has its halo (%d of %d)" % [look.halos, glows.size()]
	)
	_expect(
		look.swapped == listed.size() and listed.size() == IN_ROOM.size() + 1,
		"Every prop is staged in HD (%d of %d)" % [look.swapped, listed.size()]
	)
	_expect(look.has_depth, "The room's depth map loads")
	_expect(look.sheets == 2, "Both HD character sheets load (%d of 2)" % look.sheets)
	var hd_rects: Dictionary = {}
	for prop: Dictionary in listed:
		var id := str(prop["id"])
		var rect: Array = prop["rect"]
		hd_rects[id] = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		var expected_root := CHANDELIER if id == CHANDELIER else "Worldsort/" + id
		_expect(
			str(prop["root"]) == expected_root,
			"The %s render stands in for the room's own node (%s)" % [id, prop["root"]]
		)
		_expect(
			bool(prop.get("in_room", false)) == (id in IN_ROOM)
			and bool(prop.get("overhead", false)) == (id == CHANDELIER),
			"The %s is listed as the room draws it (in room %s, overhead %s)" % [
				id, prop.get("in_room", false), prop.get("overhead", false),
			]
		)
	player = room.get_node("Worldsort/player") as CharacterBody2D
	runtime = room.get("interaction_runtime") as Node
	var painted := _interaction_rects()
	await _clear_toasts()
	_rect_checks(hd_rects, painted)
	await _exit_checks()
	await _prop_checks()
	await _furnishing_checks()
	await _depth_checks()
	await _character_checks()
	_show(false)
	_expect(
		not look.overlay.visible and _interaction_rects() == painted,
		"Restoring puts the painted room and its highlight boxes back"
	)
	_finish()


## The highlight boxes the room's prompts use, by render prop id.
func _interaction_rects() -> Dictionary:
	var rects: Dictionary = {}
	for id: String in PROPS:
		rects[id] = runtime.call("_get_item_visual_rect", _item(PROPS[id]["item"]))
	return rects


func _item(item_name: String) -> Dictionary:
	for item: Dictionary in runtime.get("items"):
		if str(item["name"]) == item_name:
			return item
	return {}


func _rect_checks(hd_rects: Dictionary, painted: Dictionary) -> void:
	var chandelier := room.get_node(CHANDELIER) as Sprite2D
	var painted_material := chandelier.material
	var painted_z := chandelier.z_index
	_show(true)
	var staged := _interaction_rects()
	for id: String in PROPS:
		var expected: Rect2 = hd_rects[id]
		var shown: Rect2 = staged[id]
		_expect(
			_close(shown, expected) and not _close(shown, painted[id]),
			"The %s's highlight box follows its HD art: %s (render %s, painted %s)" % [
				id, shown, expected, painted[id],
			]
		)
	for id: String in IN_ROOM:
		var sprite := spatial.find_visual_node(room.get_node("Worldsort/" + id)) as Sprite2D
		_expect(
			sprite != null and is_zero_approx(sprite.self_modulate.a) and sprite.texture.get_width() > 100,
			"The %s is staged undrawn: the room render draws it, its sprite gives the prompt box" % id
		)
	_expect(
		is_equal_approx(chandelier.self_modulate.a, 1.0) and chandelier.texture.get_width() > 100
		and chandelier.z_index == painted_z and chandelier.material == painted_material,
		"The chandelier hangs in HD above every figure, as the game draws it (z %d, no depth pass)" % [
			chandelier.z_index,
		]
	)
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")
	var drawn := true
	for id: String in IN_ROOM:
		var sprite := spatial.find_visual_node(room.get_node("Worldsort/" + id)) as Sprite2D
		drawn = drawn and sprite != null and is_equal_approx(sprite.self_modulate.a, 1.0)
	_expect(drawn, "The painted props are drawn again")


## The way back to the Hall, from the doorway in both looks.
func _exit_checks() -> void:
	for shown: bool in [true, false]:
		_show(shown)
		var spot := _clear_near(LEAVING)
		_expect(spot != Vector2.INF, "There is open floor in the doorway (%s look)" % _look_name(shown))
		if spot == Vector2.INF:
			continue
		await _stand(spot)
		var offered := str(room.get("current_interaction"))
		_expect(
			offered == "exit",
			"Standing at %s offers the way back to the Hall (%s look; offered %s)" % [
				spot, _look_name(shown), offered,
			]
		)
	await _pair("01-door")


## Each prop's prompt, standing beside it in the HD room and in the painted one.
## A prop with its own HD stand is shot in each look from where it is used
## there; the rest are shot as a pair from the one stand.
func _prop_checks() -> void:
	for id: String in PROPS:
		var item: String = PROPS[id]["item"]
		var own_stand: bool = PROPS[id].has("hd_stand")
		for shown: bool in [true, false]:
			_show(shown)
			var stand: Vector2 = PROPS[id]["stand"]
			if shown:
				stand = PROPS[id].get("hd_stand", stand)
			var spot := _clear_near(stand)
			_expect(
				spot != Vector2.INF,
				"There is open floor beside the %s (%s look)" % [id, _look_name(shown)]
			)
			if spot == Vector2.INF:
				continue
			await _stand(spot)
			var offered := str(room.get("current_interaction"))
			_expect(
				offered == item,
				"Standing at %s offers the %s (%s look; offered %s)" % [spot, id, _look_name(shown), offered]
			)
			if own_stand:
				await _wait(0.35)
				await _shot("blender" if shown else "current", PROPS[id]["shot"])
		if not own_stand:
			await _pair(PROPS[id]["shot"])


## The furnishings stand on their own footprints in the HD look, and the
## painted room's floor comes back open where it is.
func _furnishing_checks() -> void:
	for shown: bool in [true, false]:
		_show(shown)
		await _wait(0.1)
		for id: String in FURNISHINGS:
			var spot: Vector2 = FURNISHINGS[id]["spot"]
			var clear := spatial.is_position_clear(player, spot, 0.0)
			if shown:
				_expect(not clear, "The player cannot stand inside the %s (HD look, %s)" % [id, spot])
			elif bool(FURNISHINGS[id]["painted_open"]):
				_expect(clear, "The floor under the %s is open in the painted room (%s)" % [id, spot])
	_show(false)


## The table hides the player behind it, never in front of it; the door's
## arch hides at most the feet of a player at it.
func _depth_checks() -> void:
	_show(true)
	var image := look.depth.depth_texture.get_image()
	var behind := _clear_near(BEHIND_TABLE)
	var before := _clear_near(BEFORE_TABLE)
	var open := _clear_near(OPEN_FLOOR)
	var at_door := _clear_near(AT_DOOR)
	_expect(
		behind != Vector2.INF and _hidden_rows(image, behind) >= 5,
		"North of the table its chairs hide the player's legs (%d rows at %s)" % [
			_hidden_rows(image, behind), behind,
		]
	)
	_expect(
		before != Vector2.INF and _hidden_rows(image, before) == 0,
		"In front of the table's south chairs nothing hides the player (%s)" % before
	)
	_expect(
		open != Vector2.INF and _hidden_rows(image, open) == 0,
		"On the open floor nothing hides the player (%s)" % open
	)
	var door_rows := _hidden_rows(image, at_door) if at_door != Vector2.INF else -1
	_expect(
		door_rows >= 1 and door_rows <= 12,
		"At the main door its arch ghosts the feet, never the figure (%d of 45 rows at %s)" % [
			door_rows, at_door,
		]
	)
	await _stand(behind)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
	_expect(
		sprite.material is ShaderMaterial
		and is_equal_approx(
			float((sprite.material as ShaderMaterial).get_shader_parameter("feet_y")), behind.y
		),
		"The player's sprite takes the room's depth pass, on its own feet"
	)
	_show(false)
	await _pair("08-behind-table")
	await _stand(open)
	await _pair("09-open-floor")


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


func _character_checks() -> void:
	await _stand(_clear_near(Vector2(1000, 800)))
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
	await _shot("blender", "10-detective-standing")
	Input.action_press("move_right")
	var moving: Array[String] = []
	var start := player.global_position
	for step: int in range(12):
		await _wait(0.05)
		moving.append(look.characters.gait_of(sprite))
	Input.action_release("move_right")
	var settled := moving.slice(moving.size() / 2)
	_expect(
		player.global_position.distance_to(start) > 40.0 and settled.count("idle") == 0,
		"Moving at the game's speed walks or runs the HD detective (%s)" % " ".join(moving)
	)
	await _wait(0.5)
	_show(false)


## The nearest spot to `target` where the player's body is clear of the room.
func _clear_near(target: Vector2) -> Vector2:
	for radius: int in range(0, 64, 2):
		for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
				Vector2(0, radius), Vector2(0, -radius)]:
			if spatial.is_position_clear(player, target + offset, 0.0):
				return target + offset
	return Vector2.INF


func _stand(spot: Vector2) -> void:
	player.global_position = spot
	player.velocity = Vector2.ZERO
	await _wait(0.15)
	var camera := runtime.get("follow_camera") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await _wait(0.45)


## The field kit's unlock cards: shots of the room, not of the cards.
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
	await _wait(0.25)
	await _shot("current", label)
	_show(true)
	await _wait(0.35)
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


func _enter_dining_hall() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.call("add_key", "dining_hall_key")
	var dining := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(dining)
	current_scene = dining
	await _wait(0.8)
	room = dining as Node2D


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


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		printerr("FAIL ", message)


func _finish() -> void:
	if look != null:
		look.restore()
	print("DINING_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
