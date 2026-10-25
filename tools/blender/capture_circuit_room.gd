extends SceneTree

## Native in-game comparison for the Blender Circuit Room: starts the Circuit
## Room with its junction plates surveyed, and shoots the same moments twice at
## 1024x768, once with the painted workshop and once in HD
## (tools/blender/prototype_room.gd). It checks that the three props are
## staged on their collision, that the room's focus boxes and walk-up points
## follow the HD props and go back with the painted ones, that each prop's,
## each junction plate's, the Mechanic's and the exit's prompt still reach the
## player where the game puts them, that each plate is drawn over the flush
## cover the render leaves for it, that the room's light rig moves onto the HD
## fixtures and back, that the exit piers hide a player standing behind them
## but neither open floor nor the exit gate hides one (the gate not even the
## shadow of a player coming in at the spawn), and that the HD detective
## stands at the room's size, idles and runs.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_circuit_room.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/circuit_room/captures/{current,blender}/*.png.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const ROOM_NAME := "circuit_room"
const ROOM_SCENE := "res://scenes/floor_1/circuit_room.tscn"
const DATA := "res://prototypes/blender_rooms/circuit_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
## The props circuit_room.gd lists, by its item name and the node it reads.
const PROPS: Dictionary = {"workbench": "Workbench", "generator": "Generator", "cabinet": "Cabinet"}
const PROP_SHOTS: Dictionary = {
	"workbench": "02-workbench", "generator": "03-generator", "cabinet": "04-cabinet",
}
## Each junction plate and the HD prop whose flush cover it is drawn over.
const PLATE_HOUSING: Dictionary = {
	"switch_left": "Cabinet", "master_switch": "Workbench", "switch_right": "Generator",
}
## North of the west exit pier (its stone stands in front of the legs), and
## open floor in the middle of the workshop where nothing stands in front.
const BEHIND_PIER := Vector2(590, 900)
const OPEN_FLOOR := Vector2(880, 640)
## The whole room in one 1024 x 768 frame.
const OVERVIEW_ZOOM := Vector2(1024.0 / 1448.0, 1024.0 / 1448.0)

var room: Node2D
var look: Room
var player: CharacterBody2D
var failures: Array[String] = []
var out_dir := ""
var _passes := 0


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
		printerr("capture_circuit_room needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_circuit_room()
	_expect(room != null, "The Circuit Room loads with its junction plates surveyed")
	if room == null:
		_finish()
		return
	player = room.get_node("Worldsort/player") as CharacterBody2D
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Circuit Room's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Circuit Room render loads")
	var listed: Array = _json("render-props.json")["props"]
	var glows: Array = _json("render-glows.json")["glows"]
	_expect(
		look.halos == glows.size(), "Every glow has its halo (%d of %d)" % [look.halos, glows.size()]
	)
	_expect(
		look.swapped == listed.size() and listed.size() == 3,
		"Every interactive prop is staged in HD (%d of %d)" % [look.swapped, listed.size()]
	)
	_expect(look.has_depth, "The room's depth map loads")
	_expect(look.sheets == 2, "Both HD character sheets load (%d of 2)" % look.sheets)
	var rig := room.get("ambience_layer") as Node2D
	_expect(
		rig != null and look.rig_moves.size() == rig.get_child_count() and rig.get_child_count() == 9,
		"Every lamp, lantern and arc of the room's light rig has its HD fixture (%d of %d)" % [
			look.rig_moves.size(), rig.get_child_count() if rig != null else 0,
		]
	)
	var hd_rects: Dictionary = {}
	for prop: Dictionary in listed:
		var rect: Array = prop["rect"]
		hd_rects[str(prop["id"])] = Rect2(
			float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])
		)
	_collision_checks(hd_rects)
	var painted := _focus_rects()
	_place(Vector2(724, 860))
	await _clear_toasts()
	await _overview()
	_place(_spawn())
	await _pair("01-room")
	await _rect_checks(hd_rects, painted)
	await _prop_checks()
	await _plate_checks(hd_rects)
	await _mechanic_and_exit_checks()
	await _depth_checks()
	await _rig_checks()
	await _character_checks()
	_show(false)
	_expect(
		not look.overlay.visible and _focus_rects() == painted,
		"Restoring puts the painted room and its focus boxes back"
	)
	_finish()


## Each HD prop stands on its FurnitureCollision: within the walk-up rule's
## 7.5 px of the collision on every side.
func _collision_checks(hd_rects: Dictionary) -> void:
	for id: String in PROPS:
		var node := room.get_node("Worldsort/" + str(PROPS[id])) as Node2D
		var shape := node.get_node("FurnitureCollision/FurnitureShape") as CollisionShape2D
		var extent := (shape.shape as RectangleShape2D).size * shape.global_scale.abs()
		var solid := Rect2(shape.global_position - extent * 0.5, extent)
		var shown: Rect2 = hd_rects[PROPS[id]]
		var worst := maxf(
			maxf(absf(shown.position.x - solid.position.x), absf(shown.position.y - solid.position.y)),
			maxf(absf(shown.end.x - solid.end.x), absf(shown.end.y - solid.end.y))
		)
		_expect(
			worst <= 7.5,
			"The HD %s stands on its collision (%s vs %s, %.1f px at most)" % [id, shown, solid, worst]
		)


## The room's focus box per prop, as the runtime frames it.
func _focus_rects() -> Dictionary:
	# Untyped: RoomInteractionRuntime names autoloads this SceneTree compiles before.
	var runtime: Object = room.get("interaction_runtime")
	var rects: Dictionary = {}
	for item: Dictionary in room.get("INTERACT_ITEMS"):
		if PROPS.has(str(item["name"])):
			rects[str(item["name"])] = runtime.call("_get_item_visual_rect", item)
	return rects


func _item(item_name: String) -> Dictionary:
	for item: Dictionary in room.get("INTERACT_ITEMS"):
		if str(item["name"]) == item_name:
			return item
	return {}


func _rect_checks(hd_rects: Dictionary, painted: Dictionary) -> void:
	_show(true)
	await _wait(0.2)
	var staged := _focus_rects()
	for id: String in PROPS:
		var expected: Rect2 = hd_rects[PROPS[id]]
		var shown: Rect2 = staged[id]
		_expect(
			_close(shown, expected) and not _close(shown, painted[id]),
			"The %s's focus box follows its HD art: %s (render %s, painted %s)" % [
				id, shown, expected, painted[id],
			]
		)
		var feet: Vector2 = _item(id)["focus_position"]
		_expect(
			feet.distance_to(Vector2(expected.get_center().x, expected.end.y)) < 1.0,
			"The %s's focus point is the HD prop's feet (%s)" % [id, feet]
		)
	_show(false)
	await _wait(0.2)
	_expect(_focus_rects() == painted, "The painted room gets its own focus boxes back")


## Each prop walked up to as the game walks the player there, until its
## collision (the HD prop's own edge) stops them: its prompt shows.
func _prop_checks() -> void:
	for id: String in PROPS:
		for shown: bool in [true, false]:
			_show(shown)
			await _wait(0.2)
			var runtime := room.get("interaction_runtime") as Object
			var box: Rect2 = runtime.call("_get_item_visual_rect", _item(id))
			var spot := _walkable_near(Vector2(box.get_center().x, box.end.y + 9.0))
			_expect(
				spot != Vector2.INF,
				"The %s has open floor at its front (%s look)" % [id, _look_name(shown)]
			)
			player.global_position = spot
			await _wait(0.5)
			var body := RoomSpatialRuntime.new().get_player_collision_rect(player)
			_expect(
				room.get("current_interaction") == id,
				"Walked up to the %s it is offered (%s look; %s at %s, %.1f px off its box)" % [
					id, _look_name(shown), room.get("current_interaction"), player.global_position,
					RoomSpatialRuntime.new().rect_gap(body, box),
				]
			)
		await _pair(PROP_SHOTS[id])


## Each surveyed plate stands on its HD housing's flush cover, and the player
## reaches it from the same contact band as in the painted room.
func _plate_checks(hd_rects: Dictionary) -> void:
	for switch_id: String in CircuitLayout.SWITCH_ORDER:
		var plate := CircuitLayout.get_rect(switch_id)
		var housing: Rect2 = hd_rects[PLATE_HOUSING[switch_id]]
		_expect(
			housing.encloses(plate),
			"Plate %s is drawn on the HD %s (%s inside %s)" % [
				switch_id, str(PLATE_HOUSING[switch_id]).to_lower(), plate, housing,
			]
		)
		var visual := (room.get("switch_visuals") as Dictionary).get(switch_id) as Node2D
		_expect(visual != null and visual.visible, "Plate %s is surveyed and shown" % switch_id)
		var band := CircuitLayout.get_contact_rect(switch_id)
		for shown: bool in [true, false]:
			_show(shown)
			player.global_position = Vector2(band.get_center().x, band.end.y + 4.0)
			await _wait(0.5)
			_expect(
				room.get("current_interaction") == switch_id,
				"From its contact band plate %s is offered (%s look)" % [switch_id, _look_name(shown)]
			)
	await _pair("05-master-plate")


func _mechanic_and_exit_checks() -> void:
	var mechanic := room.get("mechanic_npc") as Node2D
	var feet := RoomSpatialRuntime.new().get_visual_feet(mechanic)
	for shown: bool in [true, false]:
		_show(shown)
		_place(feet + Vector2(0, 10))
		await _wait(0.5)
		_expect(
			room.get("current_interaction") == "mechanic",
			"Beside the Mechanic his prompt shows (%s look)" % _look_name(shown)
		)
	await _pair("06-mechanic")
	for shown: bool in [true, false]:
		_show(shown)
		_place(Vector2(698, 960))
		await _wait(0.5)
		_expect(
			room.get("current_interaction") == "exit",
			"Between the exit piers the way back to the Hall is offered (%s look)" % _look_name(shown)
		)
	await _pair("07-exit")


## The exit pier hides the legs of a player north of it, never on open floor;
## the exit gate below the spawn hides neither a player coming in nor the
## shadow at their feet.
func _depth_checks() -> void:
	_show(true)
	var image := look.depth.depth_texture.get_image()
	var behind := _walkable_near(BEHIND_PIER)
	var open := _walkable_near(OPEN_FLOOR)
	var spawn := _spawn()
	_expect(
		_hidden_rows(image, spawn, 8) == 0,
		"Coming in at the spawn nothing hides the player or their shadow (%d rows at %s)" % [
			_hidden_rows(image, spawn, 8), spawn,
		]
	)
	_expect(
		behind != Vector2.INF and _hidden_rows(image, behind) >= 5,
		"North of the west pier the pier hides the player's legs (%d rows at %s)" % [
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
	await _pair("08-behind-pier")


## Rows of a figure about 36 x 90 px standing at `feet` that the room hides,
## with `below` more rows under the feet, where its shadow lies.
func _hidden_rows(image: Image, feet: Vector2, below: int = 0) -> int:
	var rows := 0
	for y: int in range(int(feet.y) - 88, int(feet.y) + 1 + below, 2):
		var hidden := false
		for x: int in range(int(feet.x) - 14, int(feet.x) + 15, 2):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var color := image.get_pixel(x, y)
			var wall_y := roundi(color.r * 255.0) * 256 + roundi(color.g * 255.0)
			hidden = hidden or (color.a > 0.5 and float(wall_y) > feet.y + 0.5)
		rows += 1 if hidden else 0
	return rows


## The light rig sits on the HD fixtures, keeps them through the power
## restoring, and goes back to the painted ones.
func _rig_checks() -> void:
	_show(true)
	var placed := true
	for move: Dictionary in look.rig_moves:
		placed = placed and (move["node"] as Node2D).position.is_equal_approx(move["to"])
	_expect(placed, "The light rig stands on the HD lamps, lantern, chamber and burnt bus")
	_expect(
		look.rig.z_index > look.overlay.z_index,
		"The light rig draws over the HD render (z %d over %d)" % [look.rig.z_index, look.overlay.z_index]
	)
	root.get_node("GameState").call("set_story_flag", "circuit_power_restored")
	room.call("_apply_power_ambience", true)
	_place(Vector2(880, 830))
	await _wait(0.8)
	placed = true
	for move: Dictionary in look.rig_moves:
		placed = placed and (move["node"] as Node2D).position.is_equal_approx(move["to"])
	_expect(placed, "With the power restored the lamps rise where they stand")
	await _pair("09-powered")
	_show(false)
	var back := true
	for move: Dictionary in look.rig_moves:
		back = back and (move["node"] as Node2D).position.is_equal_approx(move["from"])
	_expect(back, "Restoring puts the light rig back on the painted fixtures")


func _character_checks() -> void:
	# Open floor with a clear run east, below the workbench and the mechanic.
	var stand := _walkable_near(Vector2(180, 800))
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
	await _shot("blender", "10-detective-standing")
	Input.action_press("move_right")
	var moving: Array[String] = []
	var start := player.global_position
	for step: int in range(12):
		await _wait(0.05)
		moving.append(look.characters.gait_of(sprite))
		if step == 6:
			await _shot("blender", "11-detective-running")
	Input.action_release("move_right")
	var settled := moving.slice(moving.size() / 2)
	_expect(
		player.global_position.distance_to(start) > 40.0 and settled.count("idle") == 0,
		"Moving at the game's speed walks or runs the HD detective (%s)" % " ".join(moving)
	)
	await _wait(0.5)
	_show(false)


## The whole room in one frame, both looks, the camera pulled back to fit it.
func _overview() -> void:
	var runtime: Object = room.get("interaction_runtime")
	var camera := runtime.get("follow_camera") as Camera2D
	var zoom := camera.zoom
	camera.zoom = OVERVIEW_ZOOM
	camera.position_smoothing_enabled = false
	_place(Vector2(724, 860))
	await _wait(0.3)
	camera.reset_smoothing()
	await _pair("00-overview")
	camera.zoom = zoom
	camera.position_smoothing_enabled = true
	camera.reset_smoothing()


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
	_settle_camera()
	await _shot("current", label)
	_show(true)
	await _wait(0.35)
	_settle_camera()
	await _shot("blender", label)
	_show(false)


## Puts the player on the open floor nearest `target`, never off the floor:
## a follow camera sent to an impossible spot never finds its way back.
func _place(target: Vector2) -> void:
	var spot := _walkable_near(target)
	_expect(spot != Vector2.INF, "Open floor near %s" % target)
	if spot != Vector2.INF:
		player.global_position = spot


## Where the game puts a player coming in (circuit_room.gd).
func _spawn() -> Vector2:
	return (room.get_script() as Script).get_script_constant_map()["PLAYER_SPAWN_POSITION"]


## Centres the follow camera on the player now, so a shot frames them.
func _settle_camera() -> void:
	var camera := (room.get("interaction_runtime") as Object).get("follow_camera") as Camera2D
	if camera != null:
		camera.reset_smoothing()


func _look_name(shown: bool) -> String:
	return "HD" if shown else "painted"


func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA + file))


func _close(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) < 1.0
		and first.size.distance_to(second.size) < 1.0
	)


func _clear(target: Vector2) -> bool:
	return RoomSpatialRuntime.new().is_position_clear(player, target, 0.0)


func _walkable_near(target: Vector2) -> Vector2:
	for radius: int in range(0, 96, 4):
		for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
				Vector2(0, -radius), Vector2(0, radius)]:
			if _clear(target + offset):
				return target + offset
	return Vector2.INF


func _enter_circuit_room() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("unlock_all_hubs")
	gs.call("set_story_flag", "circuit_switches_surveyed")
	var circuit := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(circuit)
	current_scene = circuit
	await _wait(0.8)
	room = circuit as Node2D


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
		print("capture_circuit_room: PASS (%d checks)" % _passes)
		quit(0)
	else:
		printerr("capture_circuit_room: FAIL (%d)" % failures.size())
		quit(1)



func _expect(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)
