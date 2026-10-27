extends SceneTree

## Native in-game comparison for the Blender Final Room: starts a game in the
## Final Room and shoots the same moments twice at 1024x768, once with the
## painted room and once in HD (tools/blender/prototype_room.gd). It checks
## that every HD prop is staged (Mrs. Lin, the Tripo Dr. Lin where she fell,
## among them), that the room's highlight boxes and walk-up
## points follow the HD props and go back with the painted ones, that the HD
## footprints (the real-size table and engine, and the furniture the painted
## room lets the player walk through) are the collision while the HD room is
## staged and the painted collision comes back on restore, that each
## interaction is offered from its own walk-up spot in each look, that the
## table and the engine stand in front of a player behind them and nothing
## hides the player on the open floor, that the floor runs up to the great
## door in HD with no invisible wall before it, so the player walks behind the
## door and shows through it as the Hall's silhouette, that the way back to the
## Castle Hall is offered at the door in each look, and that the HD detective
## stands at the room's size and walks.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_final.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/final_room/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const ROOM_NAME := "final_room"
const ROOM_SCENE := "res://scenes/floor_1/final_room.tscn"
## The HD room as the game reads it (tools/blender/publish_hd.py); the shots go
## under the work folder.
const DATA := "res://assets/hd/rooms/final_room/"
const OUT := "res://prototypes/blender_rooms/final_room/"
const Room := preload("res://scripts/hd/hd_room.gd")
const Characters := preload("res://scripts/hd/hd_characters.gd")
## final_room.gd's interactions by the render's prop ids, and where the player
## stands to use each in the HD room and in the painted one (the HD table is a
## real table's size, so its front is nearer its middle).
const PROPS: Dictionary = {
	"VaultDoorVisual": {
		"item": "vault_cabinet", "stand": Vector2(724, 232), "painted": Vector2(724, 232),
		"shot": "02-vault",
	},
	"FinalAnalysisBoardVisual": {
		"item": "deduction_platform", "stand": Vector2(725, 682), "painted": Vector2(725, 700),
		"shot": "03-table",
	},
	"KnowledgeEngineVisual": {
		"item": "knowledge_engine", "stand": Vector2(1085, 562), "painted": Vector2(1085, 562),
		"shot": "04-engine",
	},
	"NotebookVisual": {
		"item": "mrs_lin_notebook", "stand": Vector2(306, 684), "painted": Vector2(306, 684),
		"shot": "05-notebook",
	},
	# Mrs. Lin, the Tripo Dr. Lin where she fell, laid as long as the cast stand
	# tall: her HD footprint ends where she meets the floor, so the room's own
	# approach from the south offers her.
	"MrsLinBody": {
		"item": "mrs_lin_body", "stand": Vector2(346, 639), "painted": Vector2(360, 656),
		"shot": "06-body",
	},
}
## Where Mrs. Lin lies: her HD footprint blocks the player there.
const LIN_MIDDLE := Vector2(346, 600)
## Where the safe spawn puts an arriving player (the painted collision closes
## the floor north of the gate, so the game's own spawn is moved up to here).
const ARRIVAL := Vector2(724, 770)
## North of the HD table, inside the painted one's footprint: freed floor
## where the table stands in front of the player; the HD table's middle.
const BEHIND_TABLE := Vector2(725, 400)
const PAINTED_BEHIND_TABLE := Vector2(725, 300)
const TABLE_MIDDLE := Vector2(725, 548)
const BEHIND_ENGINE := Vector2(1085, 330)
## Where the west vitrine stands, which the painted room lets the player walk
## through and the HD room blocks.
const WEST_VITRINE := Vector2(176, 464)
const OPEN_FLOOR := Vector2(520, 640)
const WEST_TABLES := Vector2(360, 560)
const EAST_SIDE := Vector2(1150, 700)
## Along the great door, from its west pier to its east one: at each x the
## player walks as far south as the room's walls let him, which in HD is the
## gate's own base. Just before the door's leaves, and in them.
const GATE_WALK: Array[float] = [490.0, 550.0, 594.0, 680.0, 725.0, 780.0, 856.0, 900.0, 960.0]
const AT_DOOR_X := 725.0
const BEHIND_DOOR := Vector2(725, 960)
const IN_DOOR := Vector2(725, 984)
## The Hall's silhouette: what is left of a figure a wall hides.
const GHOST_ALPHA := 0.45

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
		printerr("capture_final needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(OUT + "captures/")
	await _enter_final()
	_expect(room != null, "The Final Room loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Final Room's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Final Room render loads")
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
			str(prop["root"]) == str(prop["id"]),
			"The %s render stands in for the room's own node (%s)" % [prop["id"], prop["root"]]
		)
	player = room.get_node("Worldsort/player") as CharacterBody2D
	var painted := _interaction_rects()
	await _clear_toasts()
	_rect_checks(hd_rects, painted)
	await _footprint_checks()
	await _prop_checks()
	await _depth_checks()
	await _gate_checks()
	await _scene_shots()
	await _character_checks()
	_show(false)
	await _wait(0.15)
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
			shown.intersects(expected) and shown.encloses(expected.grow(-8.0))
			and not _close(shown, painted[id]),
			"The %s's highlight box follows its HD art: %s (render %s, painted %s)" % [
				id, shown, expected, painted[id],
			]
		)
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")


## The HD props' and furniture's footprints are the room's collision while it
## is staged; the painted ones come back with the painted room.
func _footprint_checks() -> void:
	_show(true)
	await _wait(0.15)
	var listed: Dictionary = look.meta.get("collision", {})
	_expect(
		look.footprints.size() == listed.size() and listed.size() == 11,
		"The HD room swaps its footprints into the collision (%d of %d)" % [
			look.footprints.size(), listed.size(),
		]
	)
	_expect(
		spatial.is_position_clear(player, BEHIND_DOOR, 0.0),
		"Before the great door, the floor is open up to it (%s)" % BEHIND_DOOR
	)
	_expect(
		not spatial.is_position_clear(player, IN_DOOR, 0.0),
		"The great door itself still blocks the player (%s)" % IN_DOOR
	)
	_expect(
		spatial.is_position_clear(player, BEHIND_TABLE, 0.0),
		"Where the painted table stood, behind the HD table, the floor is open (%s)" % BEHIND_TABLE
	)
	_expect(
		not spatial.is_position_clear(player, TABLE_MIDDLE, 0.0),
		"The HD table itself still blocks the player (%s)" % TABLE_MIDDLE
	)
	_expect(
		not spatial.is_position_clear(player, WEST_VITRINE, 0.0),
		"The HD west vitrine blocks the player (%s)" % WEST_VITRINE
	)
	_expect(
		not spatial.is_position_clear(player, LIN_MIDDLE, 0.0),
		"Mrs. Lin's HD footprint blocks the player where she lies (%s)" % LIN_MIDDLE
	)
	_show(false)
	await _wait(0.15)
	_expect(
		not spatial.is_position_clear(player, BEHIND_DOOR, 0.0),
		"With the painted room back, its walls close the floor before the door again (%s)"
		% BEHIND_DOOR
	)
	_expect(
		not spatial.is_position_clear(player, BEHIND_TABLE, 0.0),
		"With the painted room back, its table blocks that floor again (%s)" % BEHIND_TABLE
	)
	_expect(
		spatial.is_position_clear(player, WEST_VITRINE, 0.0),
		"With the painted room back, the painted vitrine's floor is open again (%s)" % WEST_VITRINE
	)
	_expect(
		room.get_node_or_null("RoomCollisions/HDWestVitrine") == null,
		"Restoring removes the footprints the HD room added"
	)


## Each prop's prompt, standing beside it in the HD room and in the painted one.
func _prop_checks() -> void:
	for id: String in PROPS:
		var spots: Dictionary = await _offer_checks(
			PROPS[id]["item"], PROPS[id]["stand"], id, PROPS[id]["painted"]
		)
		await _pair_at(PROPS[id]["shot"], spots)


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


## The table and the engine stand in front of a player behind them; where
## the player arrives and on the open floor nothing hides them.
func _depth_checks() -> void:
	_show(true)
	await _wait(0.15)
	var image := look.depth.depth_texture.get_image()
	var table := room.get_node("FinalAnalysisBoardVisual") as CanvasItem
	var engine := room.get_node("KnowledgeEngineVisual") as CanvasItem
	var behind := _clear_near(BEHIND_TABLE)
	await _stand(behind)
	_expect(
		behind != Vector2.INF and table.z_index > 0,
		"North of the table it draws in front of the player (z %d at %s)" % [table.z_index, behind]
	)
	_show(false)
	await _wait(0.15)
	var painted_behind := _clear_near(PAINTED_BEHIND_TABLE)
	await _pair_at("07-behind-table", {"hd": behind, "painted": painted_behind})
	_show(true)
	await _wait(0.15)
	var front := _clear_near(PROPS["FinalAnalysisBoardVisual"]["stand"])
	await _stand(front)
	_expect(
		front != Vector2.INF and table.z_index < 0,
		"South of the table it draws behind the player (z %d at %s)" % [table.z_index, front]
	)
	var behind_engine := _clear_near(BEHIND_ENGINE)
	await _stand(behind_engine)
	_expect(
		behind_engine != Vector2.INF and engine.z_index > 0,
		"North of the engine it draws in front of the player (z %d at %s)" % [
			engine.z_index, behind_engine,
		]
	)
	for spot: Vector2 in [OPEN_FLOOR, Vector2(900, 640)]:
		var clear := _clear_near(spot)
		_expect(
			clear != Vector2.INF and _hidden_rows(image, clear) == 0,
			"On the open floor nothing hides the player (%s)" % clear
		)
	await _stand(_clear_near(OPEN_FLOOR))
	var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
	_expect(
		sprite.material is ShaderMaterial,
		"The player's sprite takes the room's depth pass"
	)
	_show(false)


## In HD the floor runs up to the great door, with no invisible wall before
## it: walking south from where he arrives the player reaches the door. All
## along it he walks up to its base and so behind it, where it stands between
## him and the camera, and he shows through it as the Hall's silhouette. At
## the door the way back to the Castle Hall is offered, in each look.
func _gate_checks() -> void:
	_show(true)
	await _wait(0.15)
	var image := look.depth.depth_texture.get_image()
	var start := _clear_near(ARRIVAL)
	await _stand(start)
	Input.action_press("move_down")
	await _wait(1.6)
	Input.action_release("move_down")
	await _wait(0.3)
	var reached := player.global_position
	_expect(
		reached.y >= BEHIND_DOOR.y,
		"No invisible wall: walking south from %s the player reaches the great door (%s)" % [
			start, reached,
		]
	)
	for x: float in GATE_WALK:
		var spot := _deepest_at(x)
		var hidden := _hidden_rows(image, spot) if spot != Vector2.INF else 0
		_expect(
			spot != Vector2.INF and spot.y >= 925.0 and hidden > 30,
			"All along the great door the player walks up to its base, behind it (%s; %d rows)" % [
				spot, hidden,
			]
		)
	var spots := {"hd": Vector2.INF, "painted": Vector2.INF}
	for shown: bool in [true, false]:
		_show(shown)
		await _wait(0.15)
		var door := _deepest_at(AT_DOOR_X)
		spots["hd" if shown else "painted"] = door
		await _stand(door)
		var offered := str(room.get("current_interaction"))
		_expect(
			door != Vector2.INF and offered == "exit",
			(
				"At the great door the way back to the Castle Hall is offered"
				+ " (%s look, at %s; offered %s)"
			) % [_look_name(shown), door, offered]
		)
		if shown:
			var sprite := player.get_node("VisualRoot/CharacterSprite") as CanvasItem
			var material := sprite.material as ShaderMaterial
			var ghost := float(material.get_shader_parameter("ghost")) if material != null else 0.0
			var seen: int = await _silhouette_pixels()
			_expect(
				is_equal_approx(ghost, GHOST_ALPHA) and seen > 400,
				(
					"Behind the great door the player shows through it as the Hall's silhouette"
					+ " (ghost %.2f, %d px of the figure seen)"
				) % [ghost, seen]
			)
	await _pair_at("11-at-the-door", spots)


## How many screen px of the player's figure show: a shot with him, against
## the same shot with his figure hidden.
func _silhouette_pixels() -> int:
	var visual := player.get_node("VisualRoot") as CanvasItem
	await process_frame
	RenderingServer.force_draw(false)
	var with_figure := root.get_texture().get_image()
	visual.visible = false
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var without := root.get_texture().get_image()
	visual.visible = true
	var feet := player.get_global_transform_with_canvas().origin
	var zoom := (room.get("follow_camera") as Camera2D).zoom.y
	var changed := 0
	for y: int in range(int(feet.y - 84.0 * zoom), int(feet.y - 2.0 * zoom)):
		for x: int in range(int(feet.x - 14.0 * zoom), int(feet.x + 14.0 * zoom)):
			if x < 0 or y < 0 or x >= with_figure.get_width() or y >= with_figure.get_height():
				continue
			var a := with_figure.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
				changed += 1
	return changed


## The southmost spot the player can stand at `x`, walking down from the open
## floor north of the gate until the room's walls stop him.
func _deepest_at(x: float) -> Vector2:
	var deepest := Vector2.INF
	for y: int in range(690, 1000):
		if spatial.is_position_clear(player, Vector2(x, y), 0.0):
			deepest = Vector2(x, y)
		elif deepest != Vector2.INF:
			break
	return deepest


func _scene_shots() -> void:
	await _stand(_clear_near(ARRIVAL))
	await _pair("01-arrival")
	await _stand(_clear_near(WEST_TABLES))
	await _pair("08-west-tables")
	await _stand(_clear_near(EAST_SIDE))
	await _pair("09-east-side")


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
		(
			"Moving at the game's speed walks or runs the HD detective"
			+ " (%s; moved %.1f px from %s, paused %s, physics %s)"
		) % [
			" ".join(moving), player.global_position.distance_to(start), start, paused,
			player.is_physics_processing(),
		]
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


func _enter_final() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	var final_room := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(final_room)
	current_scene = final_room
	await _wait(0.8)
	room = final_room as Node2D


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
	print("FINAL_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
