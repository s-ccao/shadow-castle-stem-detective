extends SceneTree

## Interaction audit for the Blender HD rooms and the Hall. It opens one room
## as a returning player finds it and, in the HD look and then in the painted
## one, records every interaction the room offers:
## - its rect: the box the game highlights (grown 10 px) and anchors its prompt to;
## - the floor it is offered from: every floor cell the player can walk to
##   from where he arrives, where the room's own contact test passes;
## - the HD props' staged boxes, to tell a rect that follows its HD item from
##   one fixed where the painting drew it.
## Then it stands the player on the offered floor nearest the item's front
## (where only that item is offered, if there is any) and shoots what the game
## shows there. A box that does not frame its HD item, or an item offered from
## no floor the player can reach, shows in the shots and in the JSON.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/audit_interactions.gd -- --room=final_room
##
## Rooms: wake_room, greenhouse_room, chemistry_room, final_room,
## library_room, dining_hall_room and hall. Needs a native display: the HD
## props' boxes come from their textures' opaque bounds. Writes
## <data>/audit/interactions.json and <data>/audit/{hd,painted}/NN-<id>.png,
## <data> being prototypes/blender_rooms/<room>/ (the Hall's
## prototypes/blender_hall/).

const HOME_MARKER := "res://.godot/blender-proto-capture"
const Room := preload("res://tools/blender/prototype_room.gd")
const Props := preload("res://tools/blender/prototype_props.gd")
const Doors := preload("res://tools/blender/prototype_doors.gd")
const ROOM_DATA := "res://prototypes/blender_rooms/"
const HALL_DATA := "res://prototypes/blender_hall/"
const ROOM_SCENES: Dictionary = {
	"wake_room": "res://scenes/wake_room.tscn",
	"greenhouse_room": "res://scenes/floor_1/greenhouse_room.tscn",
	"chemistry_room": "res://scenes/floor_1/chemistry_room.tscn",
	"final_room": "res://scenes/floor_1/final_room.tscn",
	"library_room": "res://scenes/floor_1/library_room.tscn",
	"dining_hall_room": "res://scenes/floor_1/dining_hall_room.tscn",
}
const RENDER_SCALE := 2.0
## The floor is sampled every this many px; the Hall is wider.
const ROOM_STEP := 6.0
const HALL_STEP := 8.0
const ROOM_SIZE := Vector2(1448.0, 1086.0)
const KEYS: Array[String] = [
	"wake_room_key", "chemistry_room_key", "greenhouse_room_key", "dining_hall_key",
]
const WAKE_FLAGS: Array[String] = [
	"wake_room_arrival_complete", "wake_orientation_completed", "wake_flame_drilled",
	"wake_room_desk_read",
]
const WAKE_PROPS: Array[String] = ["bed", "desk", "bookshelf"]
const CHEMISTRY_IDS: Array[String] = ["exit", "cabinet", "alchemy_table", "red_stain", "butler"]
const HALL_IDS: Array[String] = [
	"wake_room_door", "chemistry_room_door", "greenhouse_room_door", "circuit_door",
	"library_door", "dining_hall_door", "final_room_door", "service_wall_door",
	"hidden_library_key", "final_key_machine_1", "final_key_machine_2", "final_key_machine_3",
	"service_dark_trail", "service_violet_fiber", "service_maintenance_panel",
]

var room_name := ""
var room: Node2D
var player: CharacterBody2D
## Where the player arrives: every survey walks the floor from here.
var arrival := Vector2.ZERO
var look: Room
var hall_overlay: Sprite2D
var hall_props: Props
var hall_doors: Doors
var spatial := RoomSpatialRuntime.new()
var data_dir := ""
var step := ROOM_STEP
var bounds := Rect2(Vector2.ZERO, ROOM_SIZE)


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
		printerr("audit_interactions needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room_name = arg.trim_prefix("--room=")
	if room_name != "hall" and not ROOM_SCENES.has(room_name):
		printerr("audit_interactions: unknown --room=" + room_name)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	data_dir = HALL_DATA if room_name == "hall" else ROOM_DATA + room_name + "/"
	if room_name != "hall":
		var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "layout.json"))
		if layout is Dictionary and (layout as Dictionary).has("size"):
			var size: Array = (layout as Dictionary)["size"]
			bounds = Rect2(0.0, 0.0, float(size[0]), float(size[1]))
	if room_name == "hall":
		step = HALL_STEP
		await _enter_hall()
	else:
		await _enter_room()
	if room == null:
		printerr("audit_interactions: the room did not load")
		quit(1)
		return
	player = room.get("player") as CharacterBody2D
	arrival = player.global_position
	var interactions := _interactions()
	var report := {"room": room_name, "step": step, "bounds": _rect_array(bounds), "looks": {}}
	for shown: bool in [true, false]:
		if not await _stage(shown):
			printerr("audit_interactions: no HD look for " + room_name)
			quit(1)
			return
		var look_name := "hd" if shown else "painted"
		var survey := _survey(interactions)
		if shown:
			survey["staged"] = _staged_rects()
		await _shots(look_name, interactions, survey)
		report["looks"][look_name] = survey
	await _stage(false)
	var path := ProjectSettings.globalize_path(data_dir + "audit/interactions.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	for record: Dictionary in report["looks"]["hd"]["interactions"]:
		print("AUDIT %s %s: rect %s, offered from %d cells, stood %s, offered there %s" % [
			room_name, record["id"], record.get("rect", record.get("point", [])),
			(record["offered"] as Array).size(), record.get("stood", "-"),
			record.get("offered_there", "-"),
		])
	print("AUDIT_DONE %s %d interactions -> %s" % [room_name, interactions.size(), path])
	quit(0)


## Every interaction the room offers: {"id", "label", "near": Callable, and
## "rect": Callable, or "point" and "reach"; "contact" and "click" when the
## room tests contact or a click against another rect}.
func _interactions() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	match room_name:
		"wake_room":
			var ids: Array[String] = ["door", "room_clue"]
			for prop: String in WAKE_PROPS:
				ids.append("prop:" + prop)
			for id: String in ids:
				var item := _room_item(id, id)
				item["click"] = _wake_click(id)
				items.append(item)
			# The note sits in a window alcove; the room reaches it with a 32 px band.
			items[1]["near"] = Callable(room, "_is_near_clue")
		"greenhouse_room":
			for entry: Dictionary in room.get("INTERACT_ITEMS"):
				items.append(_room_item(str(entry["name"]), str(entry["label"])))
			items.append(_room_item("gardener", "the gardener"))
			var reach := float(room.get("HERB_PLOT_REACH"))
			for plot: Dictionary in room.get("HERB_PLOTS"):
				var point := plot["position"] as Vector2
				items.append({
					"id": "plot:" + str(plot["id"]), "label": str(plot["label_en"]),
					"point": point, "reach": reach,
					"near": func() -> bool: return player.global_position.distance_to(point) <= reach,
				})
		"chemistry_room":
			for id: String in CHEMISTRY_IDS:
				items.append(_room_item(id, id))
		"final_room":
			for entry: Dictionary in room.get("INTERACT_ITEMS"):
				items.append(_room_item(str(entry["name"]), str(entry["label"])))
			items.append(_room_item("exit", "the way back to the Castle Hall"))
		"library_room", "dining_hall_room":
			# Untyped: RoomInteractionRuntime needs the CaseLocale autoload to compile.
			var runtime: Object = room.get("interaction_runtime")
			for entry: Dictionary in runtime.get("items"):
				items.append({
					"id": str(entry["name"]), "label": str(entry["label"]),
					"concealed": bool(entry.get("concealed", false)),
					"rect": Callable(runtime, "_get_item_visual_rect").bind(entry),
					"contact": Callable(runtime, "_get_item_contact_rect").bind(entry),
					"near": Callable(runtime, "_is_player_touching_item").bind(entry),
				})
			var margin := float(runtime.get("interaction_contact_margin"))
			items.append({
				"id": "exit", "label": "the way back to the Castle Hall",
				"rect": func() -> Rect2: return runtime.get("exit_rect") as Rect2,
				"near": func() -> bool: return spatial.is_actor_near_rect(
					player, runtime.get("exit_rect") as Rect2, margin
				),
			})
		"hall":
			var ids: Array[String] = HALL_IDS.duplicate()
			for entry: Dictionary in room.get("HALL_KNOWLEDGE_ITEMS"):
				ids.append("hall_knowledge:" + str(entry["id"]))
			for index: int in (room.get("CORRIDOR_FRAGMENT_POSITIONS") as Array).size():
				ids.append("corridor_fragment_%d" % (index + 1))
			for id: String in ids:
				items.append({
					"id": id, "label": id,
					"rect": Callable(room, "get_interaction_rect").bind(id),
					"near": Callable(room, "_is_near_hall_interaction").bind(id),
				})
	return items


func _room_item(id: String, label: String) -> Dictionary:
	return {
		"id": id, "label": label,
		"rect": Callable(room, "get_interaction_rect").bind(id),
		"near": Callable(room, "_is_near_interaction").bind(id),
	}


## The Wake Room also takes a click on a hotspot: the door's ExitDoorClickArea,
## a prop's Area2D (its Hotspot box and polygon, or while staged the box round
## its HD prop) or the candle note's rect.
func _wake_click(id: String) -> Callable:
	if id == "room_clue":
		return func() -> Rect2: return room.get("clue_interaction_rect") as Rect2
	var node_name := "Door" if id == "door" else id.trim_prefix("prop:").capitalize()
	return func() -> Rect2:
		var area := (
			room.get("door_click_area") if id == "door" else room.get_node_or_null("Props/" + node_name)
		) as Area2D
		return _click_box(area) if area != null else Rect2()


## The box round every shape an Area2D takes clicks on.
func _click_box(area: Area2D) -> Rect2:
	var box := Rect2()
	var found := false
	for child: Node in area.get_children():
		var shape := child as Node2D
		var points := PackedVector2Array()
		if child is CollisionPolygon2D and not (child as CollisionPolygon2D).disabled:
			points = (child as CollisionPolygon2D).polygon
		elif child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			var rectangle := (child as CollisionShape2D).shape as RectangleShape2D
			if rectangle != null:
				var half := rectangle.size * 0.5
				points = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		for point: Vector2 in points:
			var world := shape.to_global(point)
			box = box.expand(world) if found else Rect2(world, Vector2.ZERO)
			found = true
	return box


## Where each interaction is offered: the floor reachable from where the
## player stands, and for each interaction the cells where its test passes.
func _survey(interactions: Array[Dictionary]) -> Dictionary:
	var start := arrival
	var cells := _reachable(start)
	var offered: Array[PackedInt32Array] = []
	for _item: Dictionary in interactions:
		offered.append(PackedInt32Array())
	for index: int in cells.size():
		player.global_position = cells[index]
		for slot: int in interactions.size():
			if bool((interactions[slot]["near"] as Callable).call()):
				offered[slot].append(index)
	player.global_position = arrival
	var records: Array = []
	for slot: int in interactions.size():
		var item := interactions[slot]
		var record := {"id": item["id"], "label": item["label"], "offered": Array(offered[slot])}
		for key: String in ["rect", "contact", "click"]:
			if item.has(key):
				record[key] = _rect_array((item[key] as Callable).call())
		if item.has("point"):
			var point := item["point"] as Vector2
			record["point"] = [point.x, point.y]
			record["reach"] = item["reach"]
		if bool(item.get("concealed", false)):
			record["concealed"] = true
		records.append(record)
	var points: Array = []
	for cell: Vector2 in cells:
		points.append([cell.x, cell.y])
	return {"start": [start.x, start.y], "cells": points, "interactions": records}


## The floor the player can walk to from `start`, every `step` px, by the
## room's own test: its walkability check where it has one (the Wake Room,
## the Hall), else its collision.
func _reachable(start: Vector2) -> Array[Vector2]:
	var seen := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var cells: Array[Vector2] = []
	var head := 0
	var walkable := room.has_method("is_player_position_walkable")
	while head < queue.size():
		var cell := queue[head]
		head += 1
		cells.append(start + Vector2(cell) * step)
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + offset
			if seen.has(next):
				continue
			seen[next] = true
			var at := start + Vector2(next) * step
			if not bounds.has_point(at):
				continue
			var clear := (
				bool(room.call("is_player_position_walkable", at)) if walkable
				else spatial.is_position_clear(player, at, 0.0)
			)
			if clear:
				queue.append(next)
	return cells


## Stands the player where each interaction is offered, nearest its front,
## and shoots what the game shows: its prompt and its box.
func _shots(look_name: String, interactions: Array[Dictionary], survey: Dictionary) -> void:
	var cells: Array = survey["cells"]
	var crowd := PackedInt32Array()
	crowd.resize(cells.size())
	for record: Dictionary in survey["interactions"]:
		for index: int in record["offered"]:
			crowd[index] += 1
	await _clear_toasts()
	for slot: int in interactions.size():
		var record: Dictionary = survey["interactions"][slot]
		var offered: Array = record["offered"]
		if offered.is_empty():
			continue
		var target := _front(record)
		var best := -1
		var best_score := INF
		for index: int in offered:
			var cell := Vector2(float(cells[index][0]), float(cells[index][1]))
			var score := cell.distance_to(target) + (0.0 if crowd[index] == 1 else 1000.0)
			if score < best_score:
				best_score = score
				best = index
		var spot := Vector2(float(cells[best][0]), float(cells[best][1]))
		await _stand(spot)
		record["stood"] = [spot.x, spot.y]
		record["contested"] = crowd[best] > 1
		record["offered_there"] = str(room.get("current_interaction"))
		var file := "%02d-%s.png" % [slot + 1, str(record["id"]).replace(":", "-")]
		await _shot(look_name, file)
		record["shot"] = look_name + "/" + file


## Where a player would stand to use the item: before a rect's front edge,
## or at a point.
func _front(record: Dictionary) -> Vector2:
	if record.has("point"):
		return Vector2(float(record["point"][0]), float(record["point"][1]))
	var rect: Array = record.get("contact", record["rect"])
	return Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]))


## Each staged HD prop's box, as the game reads it off its sprite.
func _staged_rects() -> Array:
	var staged: Array = []
	var props: Props = hall_props if room_name == "hall" else look.props
	for swap: Dictionary in props.swaps:
		var root_node := swap["root"] as Node
		staged.append({
			"node": str(room.get_path_to(root_node)),
			"rect": _rect_array(spatial.get_visual_rect(swap["sprite"] as Node)),
			"in_room": bool(swap["in_room"]),
		})
	return staged


## The HD look or the painted one. False when the room has no render.
func _stage(shown: bool) -> bool:
	if room_name == "hall":
		if hall_overlay == null:
			hall_overlay = _hall_overlay()
			if hall_overlay == null:
				return false
			hall_props = Props.new()
			hall_props.attach(room, HALL_DATA + "render-props.json", HALL_DATA, RENDER_SCALE)
			hall_doors = Doors.new()
			hall_doors.dry_run = true
			hall_doors.attach(room, HALL_DATA + "render-doors.json", HALL_DATA, RENDER_SCALE)
			room.add_child(hall_doors)
		hall_overlay.visible = shown
		if shown:
			hall_props.apply()
			hall_doors.apply()
		else:
			hall_props.restore()
			hall_doors.restore()
	else:
		if look == null:
			look = Room.new()
			if not look.attach(room, room_name):
				return false
		if shown:
			look.apply()
		else:
			look.restore()
	# A swapped footprint reaches the physics server on its next step.
	await _wait(0.25)
	return true


func _hall_overlay() -> Sprite2D:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(HALL_DATA + "region.json"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(HALL_DATA + "render.png"))
	if not (meta is Dictionary) or image == null:
		return null
	var region: Array = (meta as Dictionary)["region"]
	var size: Array = (meta as Dictionary)["map_size"]
	bounds = Rect2(0.0, 0.0, float(size[0]), float(size[1]))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2(float(region[0]), float(region[1]))
	sprite.scale = Vector2.ONE / RENDER_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = -40
	room.add_child(sprite)
	return sprite


func _enter_room() -> void:
	_start_game()
	var scene := (load(str(ROOM_SCENES[room_name])) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(0.8)
	room = scene as Node2D


func _enter_hall() -> void:
	_start_game()
	var wake := (load(str(ROOM_SCENES["wake_room"])) as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await _wait(0.3)
	wake.call("leave_wake_room")
	for _attempt: int in range(80):
		await _wait(0.1)
		if current_scene != null and current_scene.scene_file_path.ends_with("game_world.tscn"):
			room = current_scene as Node2D
			break
	if room == null:
		return
	await _wait(0.6)
	# The Hall's arrival dialogue and survival card, as a returning player has seen them.
	var onboarding := root.get_node("OnboardingHud")
	for _attempt: int in range(160):
		if (onboarding.get("overlay") as Control).visible:
			break
		var panel := room.get("message_panel") as Control
		if panel != null and panel.visible:
			var proceed := room.get("dialogue_continue_button") as Button
			if proceed != null and proceed.visible:
				proceed.pressed.emit()
			else:
				for child: Node in (room.get("button_box") as Node).get_children():
					if child is Button and (child as Button).visible:
						(child as Button).pressed.emit()
						break
		await _wait(0.1)
	onboarding.call("_complete_orientation")
	await _wait(1.2)
	# The audit walks the whole Hall: the Guardian stays out of it, and the fog
	# off its shots. The arrival's guided crossing is over, so every prompt is
	# the Hall's own.
	root.get_node("GameState").set("hall_arrival_seen", true)
	room.set("hall_arrival_step", 4)
	var enemy := room.get_node_or_null("CastleGuardian") as CharacterBody2D
	if enemy != null:
		enemy.set("catch_enabled", false)
		enemy.set_physics_process(false)
		enemy.visible = false
		enemy.global_position = Vector2(-4000.0, -4000.0)
	var fog := room.get("fog_sprite") as CanvasItem
	if fog != null:
		fog.visible = false


func _start_game() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	for key: String in KEYS:
		gs.call("add_key", key)
	gs.set("learned_fire_oxygen_rule", true)
	gs.set("wake_room_door_unlocked", true)
	for flag: String in WAKE_FLAGS:
		gs.call("set_story_flag", flag)


func _stand(spot: Vector2) -> void:
	player.global_position = spot
	player.velocity = Vector2.ZERO
	await _wait(0.15)
	var camera := root.get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()
	if room_name == "hall":
		var fog := room.get("fog_sprite") as CanvasItem
		if fog != null:
			fog.visible = false
	await _wait(0.45)


## The field kit's unlock cards: shots of the room, not of the cards.
func _clear_toasts() -> void:
	for _round: int in range(3):
		await _wait(0.5)
		root.get_node("ItemRewardHud").call("dismiss_for_overlay")
		root.get_node("InventoryHud").call("_hide_feature_unlock")
		root.get_node("KeyHud").call("dismiss_unlock_toast")
	await _wait(0.4)


func _shot(look_name: String, file: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path(data_dir + "audit/" + look_name)
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join(file))


func _rect_array(rect: Rect2) -> Array:
	return [
		snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
		snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1),
	]


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
