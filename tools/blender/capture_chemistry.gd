extends SceneTree

## Native in-game comparison for the Blender Chemistry Room: starts a game in
## the Chemistry Room and shoots the same moments twice at 1024x768, once with
## the painted room and once in HD (tools/blender/prototype_room.gd). It checks
## that the alchemy table and the potion cabinet are staged in HD, that their
## highlight boxes follow the HD art and go back with the painted ones, that
## the HD table (a real table's size, smaller than the painted one) swaps its
## footprint into the room's collision and gives the painted one back, that
## every interaction (the doorway, the cabinet, the table, the red stain and
## the butler) still reaches the player standing beside it, that the table
## draws in front of a player behind it and behind one in front of it, that
## the cauldron hides the legs of a player behind it while nothing hides them
## in the doorway or on the open floor, and that the HD detective stands at
## the room's size and walks.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_chemistry.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/chemistry_room/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const ROOM_NAME := "chemistry_room"
const ROOM_SCENE := "res://scenes/floor_1/chemistry_room.tscn"
const DATA := "res://prototypes/blender_rooms/chemistry_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
## chemistry_room.gd's interactions by the render's prop ids, and where the
## player stands to use each in the HD room and in the painted one (the HD
## table is smaller, so its front is nearer the room's middle).
const PROPS: Dictionary = {
	"ChemistryPotionCabinet": {
		"item": "cabinet", "stand": Vector2(422, 248), "painted": Vector2(422, 248),
		"shot": "02-cabinet",
	},
	"ChemistryLabTable": {
		"item": "alchemy_table", "stand": Vector2(620, 628), "painted": Vector2(620, 700),
		"shot": "03-table",
	},
}
## The interactions the render does not stage, and where to stand for each:
## out of reach of every interaction the room offers before it.
const OTHERS: Dictionary = {
	"exit": {"stand": Vector2(742, 140), "shot": "01-doorway"},
	"red_stain": {"stand": Vector2(1010, 700), "shot": "05-red-stain"},
	"butler": {"stand": Vector2(650, 224), "shot": "06-butler"},
}
## North of the table it stands in front of the player; behind the cauldron
## the cauldron hides their legs; in the doorway and on the open floor
## nothing hides them.
const BEHIND_TABLE := Vector2(560, 428)
const PAINTED_BEHIND_TABLE := Vector2(560, 336)
## Inside the painted table's footprint but beside the HD table, and the HD
## table's own middle.
const FREED_FLOOR := Vector2(400, 520)
const TABLE_MIDDLE := Vector2(620, 527)
const BEHIND_CAULDRON := Vector2(700, 1124)
const DOORWAY := Vector2(742, 140)
const OPEN_FLOOR := Vector2(700, 880)
const WEST_COUNTER := Vector2(266, 420)
const EAST_BENCH := Vector2(1118, 470)

var room: Node2D
var look: Room
var player: CharacterBody2D
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
		printerr("capture_chemistry needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_chemistry()
	_expect(room != null, "The Chemistry Room loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Chemistry Room's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Chemistry Room render loads")
	var listed: Array = _json("render-props.json")["props"]
	var glows: Array = _json("render-glows.json")["glows"]
	_expect(
		look.halos == glows.size(), "Every glow has its halo (%d of %d)" % [look.halos, glows.size()]
	)
	_expect(
		look.swapped == listed.size() and listed.size() == PROPS.size(),
		"Every interactive prop is staged in HD (%d of %d)" % [look.swapped, listed.size()]
	)
	_expect(look.has_depth, "The room's depth map loads")
	_expect(look.sheets == 2, "Both HD character sheets load (%d of 2)" % look.sheets)
	var hd_rects: Dictionary = {}
	for prop: Dictionary in listed:
		var rect: Array = prop["rect"]
		hd_rects[str(prop["id"])] = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		_expect(
			str(prop["root"]) == "Worldsort/" + str(prop["id"]),
			"The %s render stands in for the room's own node (%s)" % [prop["id"], prop["root"]]
		)
	player = room.get_node("Worldsort/player") as CharacterBody2D
	var painted := _interaction_rects()
	await _clear_toasts()
	_rect_checks(hd_rects, painted)
	await _footprint_checks()
	await _prop_checks()
	await _other_checks()
	await _depth_checks()
	await _scene_shots()
	await _character_checks()
	_show(false)
	_expect(
		not look.overlay.visible and _interaction_rects() == painted,
		"Restoring puts the painted room and its highlight boxes back"
	)
	_finish()


## The room's highlight boxes, by render prop id.
func _interaction_rects() -> Dictionary:
	var rects: Dictionary = {}
	for id: String in PROPS:
		rects[id] = room.call("get_interaction_rect", PROPS[id]["item"])
	return rects


func _rect_checks(hd_rects: Dictionary, painted: Dictionary) -> void:
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
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")


## The HD table's footprint is the room's collision while it is staged; the
## painted table's comes back with the painted room.
func _footprint_checks() -> void:
	_show(true)
	await _wait(0.15)
	_expect(
		look.footprints.size() == 1,
		"The HD room swaps the table's footprint into the collision (%d)" % look.footprints.size()
	)
	_expect(
		spatial.is_position_clear(player, FREED_FLOOR, 0.0),
		"Where the painted table stood, beside the HD table, the floor is open (%s)" % FREED_FLOOR
	)
	_expect(
		not spatial.is_position_clear(player, TABLE_MIDDLE, 0.0),
		"The HD table itself still blocks the player (%s)" % TABLE_MIDDLE
	)
	await _stand(FREED_FLOOR)
	await _shot("blender", "11-beside-table")
	_show(false)
	await _wait(0.15)
	_expect(
		not spatial.is_position_clear(player, FREED_FLOOR, 0.0),
		"With the painted room back, its table blocks that floor again (%s)" % FREED_FLOOR
	)


## Each prop's prompt, standing beside it in the HD room and in the painted one.
func _prop_checks() -> void:
	for id: String in PROPS:
		var spots: Dictionary = await _offer_checks(
			PROPS[id]["item"], PROPS[id]["stand"], id, PROPS[id]["painted"]
		)
		await _pair_at(PROPS[id]["shot"], spots)


## The doorway, the stain and the butler: the game's own boxes, offered in
## the HD room as in the painted one.
func _other_checks() -> void:
	for item: String in OTHERS:
		var spots: Dictionary = await _offer_checks(item, OTHERS[item]["stand"], item)
		await _pair_at(OTHERS[item]["shot"], spots)


## Where the player stands to be offered `item` in each look: {"hd", "painted"}.
func _offer_checks(
	item: String, target: Vector2, label: String, painted_target: Vector2 = Vector2.INF
) -> Dictionary:
	var spots := {"hd": Vector2.INF, "painted": Vector2.INF}
	for shown: bool in [true, false]:
		_show(shown)
		# A swapped footprint reaches the physics server on its next step.
		await _wait(0.15)
		var spot := _clear_near(target if shown or painted_target == Vector2.INF else painted_target)
		_expect(
			spot != Vector2.INF, "There is open floor beside the %s (%s look)" % [label, _look_name(shown)]
		)
		if spot == Vector2.INF:
			continue
		spots["hd" if shown else "painted"] = spot
		await _stand(spot)
		var offered := str(room.get("current_interaction"))
		_expect(
			bool(room.call("_is_near_interaction", item)) and offered == item,
			"Standing at %s offers the %s (%s look; offered %s; its box %s)" % [
				spot, label, _look_name(shown), offered, room.call("get_interaction_rect", item),
			]
		)
	return spots


## The table and the cauldron stand in front of a player behind them; the
## doorway and the open floor hide nothing.
func _depth_checks() -> void:
	_show(true)
	await _wait(0.15)
	var image := look.depth.depth_texture.get_image()
	var table := room.get_node("Worldsort/ChemistryLabTable/TableOverlay") as CanvasItem
	var behind := _clear_near(BEHIND_TABLE)
	await _stand(behind)
	_expect(
		behind != Vector2.INF and table.z_index > 0,
		"North of the table it draws in front of the player (z %d at %s)" % [table.z_index, behind]
	)
	_show(false)
	await _wait(0.15)
	var painted_behind := _clear_near(PAINTED_BEHIND_TABLE)
	await _pair_at("04-behind-table", {"hd": behind, "painted": painted_behind})
	_show(true)
	await _wait(0.15)
	var front := _clear_near(PROPS["ChemistryLabTable"]["stand"])
	await _stand(front)
	_expect(
		front != Vector2.INF and table.z_index < 0,
		"South of the table it draws behind the player (z %d at %s)" % [table.z_index, front]
	)
	var cauldron := _clear_near(BEHIND_CAULDRON)
	_expect(
		cauldron != Vector2.INF and _hidden_rows(image, cauldron) >= 5,
		"Behind the cauldron it hides the player's legs (%d rows at %s)" % [
			_hidden_rows(image, cauldron), cauldron,
		]
	)
	var doorway := _clear_near(DOORWAY)
	_expect(
		doorway != Vector2.INF and _hidden_rows(image, doorway) == 0,
		"In the doorway, seen through the arch, nothing hides the player (%s)" % doorway
	)
	var open := _clear_near(OPEN_FLOOR)
	_expect(
		open != Vector2.INF and _hidden_rows(image, open) == 0,
		"On the open floor nothing hides the player (%s)" % open
	)
	await _stand(cauldron)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
	_expect(
		sprite.material is ShaderMaterial
		and is_equal_approx(
			float((sprite.material as ShaderMaterial).get_shader_parameter("feet_y")), cauldron.y
		),
		"The player's sprite takes the room's depth pass, on its own feet"
	)
	_show(false)
	await _pair("07-behind-cauldron")


func _scene_shots() -> void:
	await _stand(_clear_near(WEST_COUNTER))
	await _pair("08-west-counter")
	await _stand(_clear_near(EAST_BENCH))
	await _pair("09-east-bench")


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
	await _stand(_clear_near(OPEN_FLOOR))
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
	var camera := room.get("follow_camera") as Camera2D
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


## The same moment in both looks, the player at each look's own spot: the HD
## table is smaller, so a spot beside it can lie inside the painted one.
func _pair_at(label: String, spots: Dictionary) -> void:
	for shown: bool in [false, true]:
		_show(shown)
		await _wait(0.15)
		var spot: Vector2 = spots["hd" if shown else "painted"]
		if spot != Vector2.INF:
			await _stand(spot)
		await _wait(0.2)
		await _shot("blender" if shown else "current", label)
	_show(false)


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


func _enter_chemistry() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.call("add_key", "chemistry_room_key")
	var chemistry := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(chemistry)
	current_scene = chemistry
	await _wait(0.8)
	room = chemistry as Node2D


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
	print("CHEMISTRY_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
