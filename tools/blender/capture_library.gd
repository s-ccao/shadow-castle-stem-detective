extends SceneTree

## Native in-game checks and captures for the Blender Library: starts a game in
## the Library and, at 1024x768, shoots the same moments with the painted room
## and in HD (tools/blender/prototype_room.gd with its light layer,
## tools/blender/prototype_library.gd), then the HD moments of its own. It checks
## that the twenty cases and desks are staged in HD and that the highlight boxes
## read off them follow the HD art and go back with the painted ones; that every
## knowledge shelf and light test is still found from a broad stretch of open
## floor (as tests/library_knowledge_access_test.gd asks) and their markers sit
## on the HD cases; that the HD optical plate shows under the game's filters;
## that the towers hide a player behind them while the doorway and open floor
## hide no one; that the moonlight's dust drifts and each light test's lamp
## follows its flags; that the establishing shot plays once, hands the camera
## back, and that a key skipping it does not also act in the room; and that
## seating the three filters through the game's own flow awakens the archive
## from the optical array, the camera drawing back to show it and returning.
##
##   HOME="$PWD/.godot/blender-proto-library/home" godot --path . \
##     --script res://tools/blender/capture_library.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/library_room/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-library"
const ROOM_NAME := "library_room"
const ROOM_SCENE := "res://scenes/floor_1/library_room.tscn"
const DATA := "res://prototypes/blender_rooms/library_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
const SHELVES: Array[String] = ["topleft_tall_case", "lower_storage", "storage_cabinet"]
const STATIONS: Array[String] = ["research_desk", "writing_desk", "lower_globe_desk"]
const FILTERS: Array[String] = ["rgb_red_filter", "rgb_green_filter", "rgb_blue_filter"]
const COLOURS: Array[String] = ["red", "green", "blue"]
## Just north of a tower: it stands in front of the player there.
const BEHIND: Dictionary = {
	"TallCabinetA": Vector2(1165, 760),
	"LowerPanelA": Vector2(512, 718),
	"UpperPanelCabinet": Vector2(850, 340),
}
const ARRIVAL := Vector2(724, 930)
## In the corridor at the gate, near enough to leave by it.
const DOORWAY := Vector2(724, 990)
const OPEN_FLOOR := Vector2(1000, 760)
const ARRAY_FRONT := Vector2(724, 720)
## Where to stand for each painted / HD pair.
const VIEWS: Dictionary = {
	"01-arrival": Vector2(724, 930),
	"02-optical-array": Vector2(724, 720),
	"03-spectrum-window": Vector2(724, 330),
	"04-west-aisle": Vector2(200, 600),
	"05-east-aisle": Vector2(1300, 460),
	"06-south-west": Vector2(420, 920),
	"07-south-east": Vector2(1060, 900),
}

var room: Node2D
var look: Room
var layer: RefCounted
var player: CharacterBody2D
var spatial := RoomSpatialRuntime.new()
var item_of: Dictionary = {}
## Game time: the sum of every process step.
var played := 0.0
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
	played += delta
	if look != null:
		look.advance(delta)
	return false


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("capture_library needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_library()
	_expect(room != null, "The Library loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Library's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Library render loads")
	layer = look.extras
	_expect(layer != null, "The Library's light layer loads with it")
	if layer == null:
		_finish()
		return
	# The captures play the establishing shot themselves.
	layer.set("auto_establish", false)
	print("LIBRARY_LOOK " + look.summary())
	var listed: Array = _json("render-props.json")["props"]
	var glows: Array = _json("render-glows.json")["glows"]
	_expect(
		look.halos == glows.size(), "Every glow has its halo (%d of %d)" % [look.halos, glows.size()]
	)
	_expect(
		look.swapped == listed.size() and listed.size() == 20,
		"All twenty cases and desks are staged in HD (%d of %d)" % [look.swapped, listed.size()]
	)
	_expect(look.has_depth, "The room's depth map loads")
	_expect(look.sheets == 2, "Both HD character sheets load (%d of 2)" % look.sheets)
	var paths: Dictionary = room.get_script().get_script_constant_map()["PROP_NODE_PATHS"]
	for item: String in paths:
		item_of[str(paths[item]).get_file()] = item
	var hd_rects: Dictionary = {}
	for prop: Dictionary in listed:
		var rect: Array = prop["rect"]
		var id := str(prop["id"])
		hd_rects[id] = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		_expect(
			str(prop["root"]) == "Worldsort/" + id and item_of.has(id),
			"The %s render stands in for the room's own node (%s)" % [id, prop["root"]]
		)
	player = room.get_node("Worldsort/player") as CharacterBody2D
	var painted := _interaction_rects()
	await _clear_toasts()
	_rect_checks(hd_rects, painted)
	await _reach_checks()
	_marker_checks()
	_stand_checks()
	await _depth_checks()
	await _light_checks()
	await _view_shots()
	await _character_checks()
	await _establishing_checks()
	await _awakening_checks()
	_show(false)
	_expect(
		not look.overlay.visible and _interaction_rects() == painted,
		"Restoring puts the painted room and its highlight boxes back"
	)
	_finish()


## The room's highlight boxes, by render prop id.
func _interaction_rects() -> Dictionary:
	var rects: Dictionary = {}
	for id: String in item_of:
		rects[id] = room.call("get_library_interaction_rect", item_of[id])
	return rects


func _rect_checks(hd_rects: Dictionary, painted: Dictionary) -> void:
	_show(true)
	var staged := _interaction_rects()
	var following := 0
	for id: String in item_of:
		if _close(staged[id], hd_rects[id]):
			following += 1
		else:
			_expect(false, "The %s's box follows its HD art: %s (render %s, painted %s)" % [
				id, staged[id], hd_rects[id], painted[id],
			])
	_expect(following == item_of.size(), "Every case's box follows its HD art (%d of %d)" % [
		following, item_of.size(),
	])
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")


## Each shelf and light test is chosen from a broad stretch of open floor, as
## tests/library_knowledge_access_test.gd measures it: a shelf from at least 100
## spots, and each from nearly as many in HD as in the painted room. The spots
## lie on the room's own 10 px grid, not one hung off the box's corner, so both
## looks are sampled at the same places though their boxes differ by a pixel.
func _reach_checks() -> void:
	var runtime := room.get("interaction_runtime") as Node
	room.set_process(false)
	player.set_physics_process(false)
	var keep := player.global_position
	for item: String in SHELVES + STATIONS:
		var found: Dictionary = {}
		var taken: Dictionary = {}
		for shown: bool in [false, true]:
			_show(shown)
			var rect: Rect2 = room.call("get_library_interaction_rect", item)
			var spots := 0
			var others: Dictionary = {}
			var y := floorf((rect.position.y - 60.0) / 10.0) * 10.0
			while y <= rect.end.y + 84.0:
				var x := floorf((rect.position.x - 60.0) / 10.0) * 10.0
				while x <= rect.end.x + 60.0:
					var spot := Vector2(x, y)
					if spatial.is_position_clear(player, spot, 0.0):
						player.global_position = spot
						var selected := str(runtime.call("refresh", true))
						if selected == item:
							spots += 1
						elif selected != "" and selected != "exit":
							others[selected] = int(others.get(selected, 0)) + 1
					x += 10.0
				y += 10.0
			found[shown] = spots
			taken[shown] = others
		var least := 100 if item in SHELVES else 1
		_expect(
			int(found[true]) >= least and int(found[true]) >= int(found[false]) * 0.8,
			"%s is chosen from %d open spots in HD (%d painted; nearby, HD %s, painted %s)" % [
				item, found[true], found[false], taken[true], taken[false],
			]
		)
	_show(false)
	player.global_position = keep
	runtime.call("refresh", true)
	player.set_physics_process(true)
	room.set_process(true)


## Staged, the shelf and light-test markers sit over the HD cases, inside the
## room, as library_room.gd placed them over the painted ones; restored, back.
func _marker_checks() -> void:
	var markers: Array[Node2D] = []
	var lifts: Array[float] = []
	var items: Array[String] = []
	var constants: Dictionary = (room.get_script() as Script).get_script_constant_map()
	var shelf_markers: Dictionary = room.get("knowledge_shelf_markers")
	var station_markers: Dictionary = room.get("challenge_station_markers")
	for item: String in SHELVES:
		markers.append(shelf_markers[constants["KNOWLEDGE_SHELVES"][item]["knowledge"]])
		lifts.append(16.0)
		items.append(item)
	for item: String in STATIONS:
		markers.append(station_markers[constants["CHALLENGE_STATIONS"][item]["challenge"]])
		lifts.append(18.0)
		items.append(item)
	var painted: Array[Vector2] = []
	for marker: Node2D in markers:
		painted.append(marker.position)
	_show(true)
	for index: int in markers.size():
		var rect: Rect2 = room.call("get_library_interaction_rect", items[index])
		var expected := Vector2(rect.get_center().x, rect.position.y - lifts[index])
		var at := markers[index].position
		_expect(
			at.distance_to(expected) < 0.5 and at.y >= 80.0,
			"The %s marker sits on its HD case, in the room (%s, expected %s)" % [
				items[index], at, expected,
			]
		)
	_show(false)
	var back := 0
	for index: int in markers.size():
		back += 1 if markers[index].position == painted[index] else 0
	_expect(back == markers.size(), "Restoring puts every marker back (%d of %d)" % [
		back, markers.size(),
	])


## The HD optical plate shows under the game's filters: its flat plinth, inlays
## and frames hide while staged, and come back.
func _stand_checks() -> void:
	var stand := room.get("rgb_filter_stand") as Node2D
	var parts: Array = _layer_constant("STAND_FLAT_PARTS")
	_show(true)
	var hidden := 0
	for path: String in parts:
		var part := stand.get_node_or_null(path) as CanvasItem
		hidden += 1 if part != null and not part.visible else 0
	var marks := 0
	for filter: String in ["RedFilter", "GreenFilter", "BlueFilter"]:
		var root_node := stand.get_node(filter) as CanvasItem
		var glyph := stand.get_node(filter + "/EngravedGlyph") as CanvasItem
		marks += 1 if root_node.visible and glyph.visible else 0
	_expect(
		hidden == parts.size() and marks == 3,
		"The game's flat plate hides over the HD one (%d of %d), its filter marks stay (%d of 3)" % [
			hidden, parts.size(), marks,
		]
	)
	_show(false)
	var shown := 0
	for path: String in parts:
		var part := stand.get_node_or_null(path) as CanvasItem
		shown += 1 if part != null and part.visible else 0
	_expect(shown == parts.size(), "Restoring shows the game's plate again")


## The towers hide a player behind them; the doorway and the open floor hide no one.
func _depth_checks() -> void:
	_show(true)
	var image := look.depth.depth_texture.get_image()
	for id: String in BEHIND:
		var spot := _clear_near(BEHIND[id])
		_expect(
			spot != Vector2.INF and _hidden_rows(image, spot) >= 5,
			"Behind the %s it hides the player (%d rows at %s)" % [
				id, _hidden_rows(image, spot), spot,
			]
		)
	for label: String in ["arrival", "doorway", "open floor"]:
		var target: Vector2 = {
			"arrival": ARRIVAL, "doorway": DOORWAY, "open floor": OPEN_FLOOR,
		}[label]
		var spot := _clear_near(target)
		_expect(
			spot != Vector2.INF and _hidden_rows(image, spot) == 0,
			"At the %s nothing hides the player (%s)" % [label, spot]
		)
	var behind := _clear_near(BEHIND["TallCabinetA"])
	await _stand(behind)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
	_expect(
		sprite.material is ShaderMaterial
		and is_equal_approx(
			float((sprite.material as ShaderMaterial).get_shader_parameter("feet_y")), behind.y
		),
		"The player's sprite takes the room's depth pass, on its own feet"
	)
	await _pair("08-behind-tower")
	await _stand(_clear_near(DOORWAY))
	await _pair("09-doorway")


## The moonlight and its dust show in HD only and drift; each light test's lamp
## is dim while dormant, brighter once its knowledge is filed, steady once its
## filter is earned.
func _light_checks() -> void:
	var shafts: Array = layer.get("shafts")
	var motes: Array = layer.get("motes")
	var shafts_node := layer.get("shafts_node") as CanvasItem
	var halos: Dictionary = layer.get("lamp_halos")
	_show(true)
	_expect(
		shafts.size() == 12 and motes.size() >= 100 and shafts_node.visible,
		"Moonlight falls from every window (%d shafts, %d motes)" % [shafts.size(), motes.size()]
	)
	var before: Array[float] = []
	for mote: Dictionary in motes:
		before.append(float(mote["t"]))
	await _wait(0.6)
	var moved := 0
	for index: int in motes.size():
		moved += 1 if not is_equal_approx(float(motes[index]["t"]), before[index]) else 0
	_expect(moved == motes.size(), "The dust drifts down the light (%d of %d)" % [
		moved, motes.size(),
	])
	_show(false)
	_expect(
		not shafts_node.visible and halos.values().all(_hidden),
		"The painted room shows no HD light"
	)
	await _stand(_clear_near(ARRAY_FRONT))
	_show(true)
	await _expect_lamps(0, "dormant")
	var gs := root.get_node("GameState")
	for knowledge: String in ["spectrum", "reflection", "additive"]:
		gs.call("set_story_flag", "library_%s_knowledge_learned" % knowledge)
	await _wait(0.15)
	var flaring := 0
	for colour: String in COLOURS:
		flaring += 1 if float(layer.get("lamp_state")[colour]["flare"]) > 0.5 else 0
	_expect(flaring == 3, "Each lamp flares as its knowledge is filed (%d of 3)" % flaring)
	await _shot("blender", "10-lamp-flare")
	await _expect_lamps(1, "primed")
	for colour: String in COLOURS:
		gs.call("set_story_flag", "library_%s_filter_earned" % colour)
	await _expect_lamps(2, "solved")
	_show(false)


func _expect_lamps(level: int, label: String) -> void:
	await _wait(1.6)
	var halos: Dictionary = layer.get("lamp_halos")
	var levels: Array = _layer_constant("LAMP_LEVELS")
	var right := 0
	var readings: Array[String] = []
	for colour: String in COLOURS:
		var alpha := (halos[colour] as CanvasItem).modulate.a
		var on_level := int(layer.call("station_level", colour)) == level
		right += 1 if on_level and absf(alpha - float(levels[level])) < 0.1 else 0
		readings.append("%s %.2f" % [colour, alpha])
	_expect(right == 3, "Every light test's lamp reads %s (%s)" % [label, ", ".join(readings)])


func _view_shots() -> void:
	for label: String in VIEWS:
		await _stand(_clear_near(VIEWS[label]))
		await _pair(label)


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


## The establishing shot: the whole archive under its title, gliding down to
## the detective, who stands still meanwhile; the camera goes back to the room's.
## A key that skips it is not also taken by the room; it plays once by itself.
func _establishing_checks() -> void:
	var follow := _follow()
	await _stand(_clear_near(ARRIVAL))
	_show(true)
	layer.call("play_establishing_shot")
	await process_frame
	var shot := layer.get("shot") as Camera2D
	var fit := minf(1024.0 / 1448.0, 768.0 / 1086.0)
	_expect(
		shot != null and root.get_camera_2d() == shot and absf(shot.zoom.x - fit) < 0.01,
		"The establishing shot opens on the whole archive (zoom %s)" % (
			str(shot.zoom) if shot != null else "none"
		)
	)
	_expect(
		bool(player.get("movement_locked")) and not bool(room.get("room_input_enabled")),
		"The detective and the room's prompts wait while it plays"
	)
	await _wait(0.7)
	await _shot("blender", "11-establish-title")
	await _wait(1.5)
	await _shot("blender", "12-establish-glide")
	await _wait(1.6)
	_expect(
		not bool(layer.call("is_shot_running"))
		and root.get_camera_2d() == follow
		and not bool(player.get("movement_locked"))
		and bool(room.get("room_input_enabled"))
		and layer.get("title") == null,
		"It ends on the room's own camera, the detective free and the room's prompts back"
	)
	await _stand(_clear_near(DOORWAY))
	_expect(
		str(room.get("current_interaction")) == "exit",
		"At the gate the room offers the way out (%s)" % room.get("current_interaction")
	)
	layer.call("play_establishing_shot")
	await _wait(0.5)
	Input.action_press("interact")
	await process_frame
	await process_frame
	_expect(
		not bool(layer.call("is_shot_running"))
		and root.get_camera_2d() == follow
		and not bool(room.get("room_input_enabled")),
		"A key skips the shot; the room waits for it to be let go"
	)
	Input.action_release("interact")
	await process_frame
	await process_frame
	_expect(
		bool(room.get("room_input_enabled"))
		and current_scene == room
		and not bool(room.get("scene_transitioning")),
		"The key that skipped the shot did not also take the gate"
	)
	layer.set("auto_establish", true)
	look.restore()
	look.apply()
	var played := bool(layer.call("is_shot_running"))
	layer.call("skip_shot")
	look.restore()
	look.apply()
	_expect(
		played and not bool(layer.call("is_shot_running")),
		"The first time the Library is staged the shot plays by itself, then not again"
	)
	layer.set("auto_establish", false)
	await _wait(0.3)
	_show(false)


## Seating the three filters through the game's own flow awakens the archive:
## after the game's own ignition and reward card the awakened render spreads
## from the optical array while the camera draws back to all of it, holds, and
## returns.
func _awakening_checks() -> void:
	var follow := _follow()
	await _stand(_clear_near(ARRAY_FRONT))
	_show(true)
	await _wait(0.3)
	room.call("_use_rgb_filter", FILTERS[0])
	room.call("_use_rgb_filter", FILTERS[1])
	await _wait(0.3)
	_expect(str(layer.get("awakening")) == "", "Two filters seated leave the archive dormant")
	room.call("_use_rgb_filter", FILTERS[2])
	var solved_at := played
	var solved_ticks := Time.get_ticks_msec()
	var gs := root.get_node("GameState")
	_expect(
		bool(gs.call("has_story_flag", "library_rgb_puzzle_solved")),
		"Seating the third filter solves the RGB puzzle in the game's own flow"
	)
	await _wait(0.3)
	var card := root.get_node("ItemRewardHud").get("_panel") as CanvasItem
	_expect(
		str(layer.get("awakening")) == "waiting" and card.visible,
		"The game's own ignition and reward card play first"
	)
	await _shot("blender", "13-awaken-ignite")
	for _poll: int in range(80):
		if str(layer.get("awakening")) != "waiting":
			break
		await _wait(0.1)
	var awakened := layer.get("awakened") as CanvasItem
	_expect(
		str(layer.get("awakening")) == "spreading" and awakened.visible
		and bool(layer.call("is_shot_running")) and not card.visible,
		"Once the card has gone the archive spreads from the optical array, the camera drawing back"
		+ " (%.1f s after the filter)" % (played - solved_at)
	)
	await _wait(0.65)
	await _shot("blender", "14-awaken-spread")
	await _wait(0.9)
	await _shot("blender", "15-awaken-spread-wide")
	await _wait(1.8)
	await _shot("blender", "16-awakened-whole")
	_expect(
		str(layer.get("awakening")) == "done" and float(layer.get("reveal_radius")) > 1.0e5,
		"The whole archive is awake"
	)
	# The shot ends 5.7 s of game time after the spread begins.
	for _poll: int in range(60):
		if not bool(layer.call("is_shot_running")):
			break
		await _wait(0.1)
	await _wait(0.2)
	var state := "%.1f s game, %.1f s real; shot %s, follow camera %s, locked %s, prompts %s" % [
		played - solved_at, (Time.get_ticks_msec() - solved_ticks) / 1000.0,
		layer.call("is_shot_running"), root.get_camera_2d() == follow,
		player.get("movement_locked"), room.get("room_input_enabled"),
	]
	_expect(
		not bool(layer.call("is_shot_running"))
		and root.get_camera_2d() == follow
		and not bool(player.get("movement_locked"))
		and bool(room.get("room_input_enabled")),
		"The camera returns to the detective, free to walk (%s)" % state
	)
	await _expect_lamps(2, "solved")
	await _pair("17-awakened-array")
	await _stand(_clear_near(VIEWS["03-spectrum-window"]))
	await _pair("18-awakened-window")
	await _stand(_clear_near(VIEWS["04-west-aisle"]))
	await _pair("19-awakened-west")
	_show(false)
	_expect(not awakened.visible, "Restoring hides the awakened archive")
	_show(true)
	await _wait(0.3)
	_expect(
		awakened.visible and str(layer.get("awakening")) == "done"
		and not bool(layer.call("is_shot_running")),
		"Staged again, the solved archive shows awake at once, without the shot"
	)
	_show(false)


func _layer_constant(constant: String) -> Variant:
	return (layer.get_script() as Script).get_script_constant_map()[constant]


func _follow() -> Camera2D:
	var runtime := room.get("interaction_runtime") as Node
	return runtime.get("follow_camera") as Camera2D


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
	var camera := _follow()
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


func _hidden(item: Variant) -> bool:
	return not (item as CanvasItem).visible


func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA + file))


func _close(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) < 1.0
		and first.size.distance_to(second.size) < 1.0
	)


func _enter_library() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	var library := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(library)
	current_scene = library
	await _wait(0.8)
	room = library as Node2D


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
	print("LIBRARY_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
