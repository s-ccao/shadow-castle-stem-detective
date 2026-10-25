extends SceneTree

## Native in-game comparison for the Blender Greenhouse: starts a game in the
## Greenhouse and shoots the same moments twice at 1024x768, once with the
## painted room and once in HD (tools/blender/prototype_room.gd). It checks
## that every interactive prop is staged, that the room's highlight boxes and
## walk-up points follow the HD props and go back with the painted ones, that
## the planter and the gate (drawn by the room render, so the player can walk
## round the one and up behind the other) are staged undrawn, that each prop's
## prompt still reaches the player standing beside it, that the planter's rim
## and the gate's portal show the player behind them as a ghost but nothing
## hides them in front of the planter or in the aisle, that the HD bench's
## real-size footprint is the room's collision while it is staged, that the
## long beds are offered from the aisle all along them and the planter's north
## arc from behind it, that the HD detective stands at the room's size and
## walks, and that the gardener is drawn by her Tripo figure on her own feet,
## on the aisle floor beside her bed.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_greenhouse.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_rooms/greenhouse_room/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const ROOM_NAME := "greenhouse_room"
const ROOM_SCENE := "res://scenes/floor_1/greenhouse_room.tscn"
const DATA := "res://prototypes/blender_rooms/greenhouse_room/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
const Depth := preload("res://tools/blender/prototype_depth.gd")
## greenhouse_room.gd's interaction items by the render's prop ids, and where
## the player stands to use each: in reach of its box, out of reach of every
## herb plot (which the room offers first) and of the items listed before it.
const PROPS: Dictionary = {
	"MagicPlanter": {"item": "magic_planter", "stand": Vector2(512, 790), "shot": "02-planter"},
	"Workbench": {"item": "workbench", "stand": Vector2(512, 1085), "shot": "04-workbench"},
	"PlantPotsA": {"item": "plant_pots_a", "stand": Vector2(300, 1250), "shot": "05-pots-west"},
	"PlantPotsB": {"item": "plant_pots_b", "stand": Vector2(712, 1260), "shot": "06-pots-east"},
	"ArchDoor": {"item": "arch_door", "stand": Vector2(512, 1362), "shot": "01-gate"},
}
## North of the planter its rim stands in front of the player; south-west of it
## and in the aisle nothing does.
const BEHIND_PLANTER := Vector2(512, 400)
const BESIDE_PLANTER := Vector2(395, 740)
const OPEN_AISLE := Vector2(512, 1160)
const WEST_BED := Vector2(275, 600)
const GARDENER := Vector2(712, 1000)
## Inside the painted bench's footprint but behind the HD bench (a real one,
## 1 m deep), the HD bench's own middle, and behind it, under the game's glow
## for the seedling trays.
const FREED_FLOOR := Vector2(512, 930)
const BENCH_MIDDLE := Vector2(512, 1010)
const BEHIND_TRAYS := Vector2(440, 940)

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
		printerr("capture_greenhouse needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	await _enter_greenhouse()
	_expect(room != null, "The Greenhouse loads as a returning player finds it")
	if room == null:
		_finish()
		return
	_expect(Room.room_for(ROOM_SCENE) == ROOM_NAME, "The preview knows the Greenhouse's prototype")
	look = Room.new()
	_expect(look.attach(room, ROOM_NAME), "The Greenhouse render loads")
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
	await _reach_checks()
	await _depth_checks()
	await _scene_shots()
	await _character_checks()
	await _cast_checks()
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
	var planter := room.get_node("Worldsort/MagicPlanter/PlanterSprite") as Sprite2D
	var gate := room.get_node("Worldsort/ArchDoor/ArchDoorSprite") as Sprite2D
	for sprite: Sprite2D in [planter, gate]:
		_expect(
			is_zero_approx(sprite.self_modulate.a) and sprite.texture.get_width() > 400,
			"The %s is staged undrawn: the room render draws it, its sprite gives the prompt box" % [
				sprite.get_parent().name,
			]
		)
	_show(false)
	_expect(_interaction_rects() == painted, "The painted room gets its own highlight boxes back")
	_expect(
		is_equal_approx(planter.self_modulate.a, 1.0) and is_equal_approx(gate.self_modulate.a, 1.0),
		"The painted planter and gate are drawn again"
	)


## The HD bench's footprint is the room's collision while it is staged; the
## painted bench's comes back with the painted room.
func _footprint_checks() -> void:
	_show(true)
	await _wait(0.15)
	_expect(
		look.footprints.size() == 1,
		"The HD room swaps the bench's footprint into the collision (%d)" % look.footprints.size()
	)
	_expect(
		spatial.is_position_clear(player, FREED_FLOOR, 0.0),
		"Where the painted bench stood, behind the HD bench, the floor is open (%s)" % FREED_FLOOR
	)
	_expect(
		not spatial.is_position_clear(player, BENCH_MIDDLE, 0.0),
		"The HD bench itself still blocks the player (%s)" % BENCH_MIDDLE
	)
	var behind := _clear_near(BEHIND_TRAYS)
	await _stand(behind)
	var bench := room.get_node("Worldsort/Workbench") as Node2D
	_expect(
		behind != Vector2.INF and behind.y < bench.global_position.y,
		"Behind the HD bench it draws in front of the player (%s; the bench sorts at y %.0f)" % [
			behind, bench.global_position.y,
		]
	)
	var offered := str(room.get("current_interaction"))
	_expect(
		offered == "herb_plot:bench_trays",
		"Behind the HD bench the seedling trays are in reach (offered %s)" % offered
	)
	await _shot("blender", "11-behind-bench")
	_show(false)
	await _wait(0.15)
	_expect(
		not spatial.is_position_clear(player, FREED_FLOOR, 0.0),
		"With the painted room back, its bench blocks that floor again (%s)" % FREED_FLOOR
	)


## Each prop's prompt, standing beside it in the HD room and in the painted one.
func _prop_checks() -> void:
	for id: String in PROPS:
		var item: String = PROPS[id]["item"]
		for shown: bool in [true, false]:
			_show(shown)
			var spot := _clear_near(PROPS[id]["stand"])
			_expect(
				spot != Vector2.INF,
				"There is open floor beside the %s (%s look)" % [id, _look_name(shown)]
			)
			if spot == Vector2.INF:
				continue
			await _stand(spot)
			var offered := str(room.get("current_interaction"))
			_expect(
				bool(room.call("_is_near_interaction", item)) and offered == item,
				"Standing at %s offers the %s (%s look; offered %s)" % [spot, id, _look_name(shown), offered]
			)
		await _pair(PROPS[id]["shot"])


## In both looks the long beds are offered from the aisle all along them (their
## boxes are the whole bed inside its kerb), and the planter's north arc from
## the floor behind the planter.
func _reach_checks() -> void:
	var spots := {
		"herb_bed_left": [Vector2(266, 800), Vector2(266, 1100)],
		"herb_bed_right": [Vector2(752, 800), Vector2(752, 1100)],
		"herb_plot:planter_north": [BEHIND_PLANTER],
	}
	for shown: bool in [true, false]:
		_show(shown)
		for item: String in spots:
			for target: Vector2 in spots[item]:
				var spot := _clear_near(target)
				if spot == Vector2.INF:
					_expect(false, "There is open floor at %s (%s look)" % [target, _look_name(shown)])
					continue
				await _stand(spot)
				var offered := str(room.get("current_interaction"))
				_expect(
					offered == item,
					"Standing at %s offers %s (%s look; offered %s)" % [spot, item, _look_name(shown), offered]
				)
	_show(false)


## The planter's rim hides the player behind it, never in front of it.
func _depth_checks() -> void:
	_show(true)
	var image := look.depth.depth_texture.get_image()
	var behind := _clear_near(BEHIND_PLANTER)
	var beside := _clear_near(BESIDE_PLANTER)
	var aisle := _clear_near(OPEN_AISLE)
	_expect(
		behind != Vector2.INF and _hidden_rows(image, behind) >= 5,
		"North of the planter its rim hides the player's legs (%d rows at %s)" % [
			_hidden_rows(image, behind), behind,
		]
	)
	_expect(
		beside != Vector2.INF and _hidden_rows(image, beside) == 0,
		"South-west of the planter, in front of its rim, nothing hides the player (%s)" % beside
	)
	_expect(
		aisle != Vector2.INF and _hidden_rows(image, aisle) == 0,
		"In the aisle nothing hides the player (%s)" % aisle
	)
	# At the gate's prompt the player stands behind the arch, which ghosts their
	# legs as the painted shield covers them, but never the whole figure.
	var gate_spot := _clear_near(PROPS["ArchDoor"]["stand"])
	var gate_rows := _hidden_rows(image, gate_spot) if gate_spot != Vector2.INF else -1
	_expect(
		gate_rows >= 8 and gate_rows <= 30,
		"At the gate's prompt the arch ghosts the legs, not the whole figure (%d of 45 rows at %s)" % [
			gate_rows, gate_spot,
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
	await _pair("03-behind-planter")
	await _stand(beside)
	await _pair("07-beside-planter")


func _scene_shots() -> void:
	await _stand(_clear_near(WEST_BED))
	await _pair("08-west-bed")
	await _stand(_clear_near(GARDENER))
	_show(true)
	await _wait(0.3)
	var gardener: Rect2 = room.call("get_interaction_rect", "gardener")
	var gap := spatial.rect_gap(spatial.get_player_collision_rect(player), gardener)
	_expect(
		str(room.get("current_interaction")) == "gardener",
		"Beside the gardener he is offered in the HD room (offered %s; %.1f px from his box %s)" % [
			room.get("current_interaction"), gap, gardener,
		]
	)
	await _pair("09-gardener")


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
	await _stand(_clear_near(Vector2(512, 1160)))
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


## The gardener in HD: drawn by her Tripo figure on her own feet, as tall as
## the pixel gardener and facing as the game turns her; standing on the aisle
## floor beside her bed, where the room hides no part of her; on a contact
## shadow; and the pixel gardener again once the painted room is back.
func _cast_checks() -> void:
	_expect(
		look.characters.cast == 4, "Every one of the cast has HD sheets (%d of 4)" % look.characters.cast
	)
	var gardener := room.get("gardener_npc") as Node2D
	await _stand(_clear_near(GARDENER))
	_show(true)
	await _wait(0.8)
	_npc_checks(gardener)
	var feet := gardener.global_position
	var hidden := _hidden_rows(look.depth.depth_texture.get_image(), feet)
	_expect(
		spatial.is_position_clear(player, feet, 0.0) and hidden == 0,
		"She stands on the aisle floor beside her bed, which hides none of her (%d rows at %s)" % [
			hidden, feet,
		]
	)
	_expect(gardener.has_node(Depth.SHADOW_NAME), "The gardener stands on a contact shadow")
	_show(false)
	await _wait(0.3)
	var sprite := gardener.get("actor_sprite") as AnimatedSprite2D
	_expect(
		is_equal_approx(sprite.self_modulate.a, 1.0) and not sprite.has_node(Characters.HD_FIGURE)
		and not gardener.has_node(Depth.SHADOW_NAME),
		"Restoring draws the pixel gardener again"
	)


## `npc` is drawn by its HD figure: the game's sprite undrawn, the figure on
## the NPC's feet, as tall as the pixel figure, and facing as the NPC faces.
func _npc_checks(npc: Node2D) -> void:
	var sprite := npc.get("actor_sprite") as AnimatedSprite2D
	var figure := look.characters.figure_of(sprite)
	var character := str(Characters.NPCS.get(str(npc.get("character_name")), ""))
	var sheet: Dictionary = look.characters.sheets.get(character, {})
	_expect(
		figure != null and not sheet.is_empty() and is_zero_approx(sprite.self_modulate.a)
		and figure.use_parent_material and sprite.material is ShaderMaterial,
		"%s is drawn by its HD figure, on the room's depth pass" % npc.name
	)
	if figure == null or sheet.is_empty():
		return
	var centre_to_feet := (sheet["feet"] as Vector2) - (sheet["cell"] as Vector2) * 0.5
	var feet := figure.global_transform * centre_to_feet
	var tall := float(sheet["height"]) * absf(figure.global_scale.y)
	var pixel_tall := float(Characters.NPC_FIGURE_PX[character]) * absf(sprite.global_scale.y)
	_expect(
		feet.distance_to(npc.global_position) < 0.5 and absf(tall - pixel_tall) < 1.0 and tall > 80.0,
		"%s stands on its own feet %s, as tall as the pixel figure (%.1f vs %.1f px)" % [
			npc.name, feet.round(), tall, pixel_tall,
		]
	)
	var facing := String(sprite.animation).trim_prefix("idle_").trim_prefix("walk_")
	var row := int((sheet["rows"] as Dictionary).get(str(Characters.NPC_FACINGS.get(facing, "")), -1))
	_expect(
		row >= 0 and figure.frame / figure.hframes == row,
		"%s faces as the game turns it (%s, row %d)" % [npc.name, sprite.animation, row]
	)


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


func _enter_greenhouse() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	gs.call("add_key", "wake_room_key")
	gs.call("add_key", "greenhouse_room_key")
	var greenhouse := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(greenhouse)
	current_scene = greenhouse
	await _wait(0.8)
	room = greenhouse as Node2D


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
	print("GREENHOUSE_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
