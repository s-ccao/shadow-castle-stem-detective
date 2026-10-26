extends SceneTree

## Blender coverage audit. Opens one area of the game as a returning player
## finds it and notes every textured thing it draws in the world (the HUD's
## CanvasLayers aside). Then it stages the area's HD look as the preview does
## (play_prototype.gd, prototype_room.gd) and sorts what is drawn now:
## - staged: drawn by the HD look itself, its render, HD props, HD doors and
##   HD figures, or a game node whose texture the look swapped;
## - covered: the game's own art left under the HD render (below z -40 and
##   inside the render);
## - left: the game's own art still drawn over or beside the HD render, by
##   source: "art" (painted or pixel art loaded from the project), "generated"
##   (textures made in code: fog, shadows, halos) and "drawn" (nodes that draw
##   themselves in _draw()).
## An area is wholly rebuilt in Blender when no "art" is left.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/audit_blender_coverage.gd -- --room=<room>|hall
##
## Rooms: wake_room, greenhouse_room, chemistry_room, final_room,
## library_room, dining_hall_room, circuit_room and hall. Needs a native
## display. Writes <data>/audit/coverage.json and <data>/audit/coverage.png,
## the HD look with everything left boxed (red: art, amber: generated, cyan:
## drawn).

const HOME_MARKER := "res://.godot/blender-proto-capture"
const Room := preload("res://scripts/hd/hd_room.gd")
const Glows := preload("res://scripts/hd/hd_glows.gd")
const Props := preload("res://scripts/hd/hd_props.gd")
const Depth := preload("res://scripts/hd/hd_depth.gd")
const Doors := preload("res://scripts/hd/hd_doors.gd")
const Characters := preload("res://scripts/hd/hd_characters.gd")
## Each area's work folder (its audit goes there), and the HD Hall and figures as
## the game reads them.
const ROOM_DATA := "res://prototypes/blender_rooms/"
const HALL_WORK := "res://prototypes/blender_hall/"
const HALL_DATA := "res://assets/hd/hall/"
const CHARACTER_DATA := "res://assets/hd/characters/"
const HDData := preload("res://scripts/hd/hd_data.gd")
const RENDER_SCALE := 2.0
## The HD render's z; the painted room lies below it.
const OVERLAY_Z := -40
const ROOM_SCENES: Dictionary = {
	"wake_room": "res://scenes/wake_room.tscn",
	"greenhouse_room": "res://scenes/floor_1/greenhouse_room.tscn",
	"chemistry_room": "res://scenes/floor_1/chemistry_room.tscn",
	"final_room": "res://scenes/floor_1/final_room.tscn",
	"library_room": "res://scenes/floor_1/library_room.tscn",
	"dining_hall_room": "res://scenes/floor_1/dining_hall_room.tscn",
	"circuit_room": "res://scenes/floor_1/circuit_room.tscn",
}
const KEYS: Array[String] = [
	"wake_room_key", "chemistry_room_key", "greenhouse_room_key", "dining_hall_key",
]
const WAKE_FLAGS: Array[String] = [
	"wake_room_arrival_complete", "wake_orientation_completed", "wake_flame_drilled",
	"wake_room_desk_read",
]
## Anything narrower or shorter than this (world px) is not worth naming.
const MIN_SIDE := 4.0
## Art below the render's z counts as covered when this share of it lies
## under the render (a painted backdrop 2 px lower than the render is).
const COVERED_SHARE := 0.98
const MARKS: Dictionary = {
	"art": Color(1.0, 0.18, 0.18), "generated": Color(1.0, 0.72, 0.2), "drawn": Color(0.3, 0.9, 1.0),
}
const HALL_VIEW := Rect2(0.0, 0.0, 1920.0, 1280.0)

var room_name := ""
var room: Node2D
var data_dir := ""
var look: Room
var glows: Glows
var depth: Depth
var characters: Characters
## The HD render's world rect.
var render_rect := Rect2()


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _physics_process(delta: float) -> bool:
	if look != null:
		look.track(delta)
	if characters != null:
		characters.track(delta)
	return false


func _process(delta: float) -> bool:
	if look != null:
		look.advance(delta)
	if glows != null:
		glows.advance(delta)
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
		printerr("audit_blender_coverage needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room_name = arg.trim_prefix("--room=")
	if room_name != "hall" and not ROOM_SCENES.has(room_name):
		printerr("audit_blender_coverage: unknown --room=" + room_name)
		quit(2)
		return
	data_dir = HALL_WORK if room_name == "hall" else ROOM_DATA + room_name + "/"
	if room_name == "hall":
		await _enter_hall()
	else:
		await _enter_room()
	if room == null:
		printerr("audit_blender_coverage: the area did not load")
		quit(1)
		return
	await _wait(0.6)
	var before := _textured()
	if not await _stage():
		printerr("audit_blender_coverage: no HD look for " + room_name)
		quit(1)
		return
	await _wait(1.2)
	var after := _textured()
	var report := _sort(before, after)
	await _clear_toasts()
	await _shoot(report["left"])
	_write(report)
	quit(0)


## {path: record} for every visible textured or self-drawing world node.
func _textured() -> Dictionary:
	var found := {}
	_walk(room, found)
	return found


func _walk(node: Node, found: Dictionary) -> void:
	if node is CanvasLayer:
		return
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.is_visible_in_tree():
			return
		var record := _record(item)
		if not record.is_empty():
			found[record["path"]] = record
	for child: Node in node.get_children():
		_walk(child, found)


func _record(item: CanvasItem) -> Dictionary:
	var texture: Texture2D = null
	var key := ""
	var rect := Rect2()
	if item is Sprite2D:
		var sprite := item as Sprite2D
		texture = sprite.texture
		if texture != null:
			rect = _global_rect(sprite, sprite.get_rect())
	elif item is AnimatedSprite2D:
		var animated := item as AnimatedSprite2D
		var frames := animated.sprite_frames
		if frames != null and frames.has_animation(animated.animation) \
				and frames.get_frame_count(animated.animation) > 0:
			texture = frames.get_frame_texture(animated.animation, animated.frame)
			key = "frames:%d" % frames.get_instance_id()
		if texture != null:
			var size := texture.get_size()
			var local := Rect2(-size / 2.0 if animated.centered else Vector2.ZERO, size)
			local.position += animated.offset
			rect = _global_rect(animated, local)
	elif item is TextureRect or item is NinePatchRect:
		texture = item.get("texture") as Texture2D
		rect = (item as Control).get_global_rect()
	elif item is TextureButton:
		texture = (item as TextureButton).texture_normal
		rect = (item as Control).get_global_rect()
	elif item is Polygon2D:
		texture = (item as Polygon2D).texture
		if texture != null:
			rect = _global_rect(item as Node2D, _bounds((item as Polygon2D).polygon))
	elif item is MeshInstance2D:
		texture = (item as MeshInstance2D).texture
		var mesh := (item as MeshInstance2D).mesh
		if texture != null and mesh != null:
			var box := mesh.get_aabb()
			var flat := Rect2(box.position.x, box.position.y, box.size.x, box.size.y)
			rect = _global_rect(item as Node2D, flat)
	elif item is Line2D:
		texture = (item as Line2D).texture
		if texture != null:
			rect = _global_rect(item as Node2D, _bounds((item as Line2D).points))
	elif item is GPUParticles2D or item is CPUParticles2D:
		texture = item.get("texture") as Texture2D
		if texture != null:
			rect = _global_rect(item as Node2D, Rect2(texture.get_size() / -2.0, texture.get_size()))
	elif item is TileMapLayer:
		var layer := item as TileMapLayer
		if layer.tile_set != null and not layer.get_used_cells().is_empty():
			for index: int in range(layer.tile_set.get_source_count()):
				var source := layer.tile_set.get_source(layer.tile_set.get_source_id(index))
				if source is TileSetAtlasSource:
					texture = (source as TileSetAtlasSource).texture
					break
			var used := layer.get_used_rect()
			var tile := Vector2(layer.tile_set.tile_size)
			rect = _global_rect(layer, Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile))
	var drawn := texture == null and _draws_itself(item)
	if texture == null and not drawn:
		return {}
	if key.is_empty():
		key = _texture_key(texture)
	return {
		"node": item,
		"path": str(room.get_path_to(item)),
		"kind": item.get_class(),
		"key": key,
		"source": "drawn" if drawn else _source(texture),
		"rect": rect,
		"z": _absolute_z(item),
		"alpha": _alpha(item),
		"drawn": drawn,
	}


## The HD look as the preview stages it. False if the area has no render.
func _stage() -> bool:
	if room_name != "hall":
		look = Room.new()
		if not look.attach(room, room_name):
			return false
		look.apply()
		render_rect = _global_rect(look.overlay, look.overlay.get_rect())
		return true
	var meta: Variant = HDData.json(HALL_DATA + "region.json")
	var texture := HDData.texture(HALL_DATA + "render.webp")
	if not (meta is Dictionary) or texture == null:
		return false
	var region: Array = (meta as Dictionary)["region"]
	var sprite := Sprite2D.new()
	sprite.name = "BlenderPrototypeOverlay"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(float(region[0]), float(region[1]))
	sprite.scale = Vector2.ONE / RENDER_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = OVERLAY_Z
	room.add_child(sprite)
	render_rect = _global_rect(sprite, sprite.get_rect())
	glows = Glows.new()
	glows.attach(sprite, HALL_DATA + "render-glows.json", sprite.position, RENDER_SCALE)
	var props := Props.new()
	props.attach(room, HALL_DATA + "render-props.json", HALL_DATA, RENDER_SCALE)
	props.apply()
	var doors := Doors.new()
	doors.attach(room, HALL_DATA + "render-doors.json", HALL_DATA, RENDER_SCALE)
	room.add_child(doors)
	doors.apply()
	depth = Depth.new()
	if depth.attach(room, HALL_DATA + "render-depth.png", region):
		for item: Dictionary in props.standing():
			depth.add_fixed(item["sprite"], item["feet"])
		depth.add_props((meta as Dictionary).get("props", {}))
		depth.apply()
	else:
		depth = null
	characters = Characters.new()
	characters.attach(room, CHARACTER_DATA)
	characters.apply()
	return true


func _sort(before: Dictionary, after: Dictionary) -> Dictionary:
	var staged := 0
	var covered: Array = []
	var left: Array = []
	for path: String in after:
		var record: Dictionary = after[path]
		var rect: Rect2 = record["rect"]
		if float(record["alpha"]) < 0.03:
			continue
		if not bool(record["drawn"]) and (rect.size.x < MIN_SIDE or rect.size.y < MIN_SIDE):
			continue
		if not before.has(path) or str((before[path] as Dictionary)["key"]) != str(record["key"]):
			staged += 1
			continue
		var entry := {
			"path": path, "kind": record["kind"], "source": record["source"],
			"rect": _rect_array(rect), "z": record["z"],
		}
		if int(record["z"]) < OVERLAY_Z and not bool(record["drawn"]) \
				and _area(rect.intersection(render_rect)) >= COVERED_SHARE * _area(rect):
			covered.append(entry)
			continue
		if bool(record["drawn"]):
			entry["bucket"] = "drawn"
		elif str(record["source"]) == "generated":
			entry["bucket"] = "generated"
		else:
			entry["bucket"] = "art"
		if int(record["z"]) < OVERLAY_Z:
			entry["note"] = "under the render's z, outside it"
		left.append(entry)
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rect"][2]) * float(a["rect"][3]) > float(b["rect"][2]) * float(b["rect"][3]))
	return {
		"room": room_name, "render": _rect_array(render_rect), "staged": staged,
		"covered": covered, "left": left,
	}


## The HD look with everything left boxed, the Hall's whole map in one view.
func _shoot(left: Array) -> void:
	var marks := Node2D.new()
	marks.name = "CoverageMarks"
	marks.z_index = 4000
	marks.z_as_relative = false
	room.add_child(marks)
	var to_local := room.get_global_transform().affine_inverse()
	for entry: Dictionary in left:
		var r: Array = entry["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = MARKS[str(entry["bucket"])]
		line.closed = true
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]:
			line.add_point(to_local * corner)
		marks.add_child(line)
	if room_name == "hall":
		# The Hall's own camera is driven every frame; a camera of the audit's
		# own shows the whole map instead.
		var camera := Camera2D.new()
		camera.name = "CoverageCamera"
		var fit := minf(1024.0 / HALL_VIEW.size.x, 768.0 / HALL_VIEW.size.y)
		camera.zoom = Vector2(fit, fit)
		room.add_child(camera)
		camera.global_position = HALL_VIEW.get_center()
		camera.make_current()
		camera.reset_smoothing()
		var fog := room.get("fog_sprite") as CanvasItem
		if fog != null:
			fog.visible = false
	await _wait(0.5)
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path(data_dir + "audit")
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory.path_join("coverage.png"))


func _write(report: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(data_dir + "audit/coverage.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var counts := {"art": 0, "generated": 0, "drawn": 0}
	for entry: Dictionary in report["left"]:
		counts[entry["bucket"]] = int(counts[entry["bucket"]]) + 1
		print("LEFT %s %s %s %s z%d %s %s" % [
			room_name, entry["bucket"], entry["kind"], entry["rect"], entry["z"],
			entry["source"], entry["path"],
		])
	print("COVERAGE %s: %d staged, %d covered, left %d art, %d generated, %d drawn -> %s" % [
		room_name, report["staged"], (report["covered"] as Array).size(),
		counts["art"], counts["generated"], counts["drawn"], path,
	])


func _texture_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return "atlas:" + _texture_key((texture as AtlasTexture).atlas)
	if texture != null and not texture.resource_path.is_empty():
		return texture.resource_path
	return "id:%d" % (texture.get_instance_id() if texture != null else 0)


func _source(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return _source((texture as AtlasTexture).atlas)
	if texture == null or texture.resource_path.is_empty():
		return "generated"
	return texture.resource_path


func _draws_itself(item: CanvasItem) -> bool:
	var script := item.get_script() as Script
	while script != null:
		for method: Dictionary in script.get_script_method_list():
			if str(method["name"]) == "_draw":
				return true
		script = script.get_base_script()
	return false


func _absolute_z(item: CanvasItem) -> int:
	var z := item.z_index
	if item.z_as_relative and item.get_parent() is CanvasItem:
		z += _absolute_z(item.get_parent() as CanvasItem)
	return z


func _alpha(item: CanvasItem) -> float:
	var alpha := item.self_modulate.a
	var node: Node = item
	while node is CanvasItem:
		alpha *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return alpha


func _global_rect(node: CanvasItem, local: Rect2) -> Rect2:
	var transform := node.get_global_transform()
	var corners: Array[Vector2] = [
		transform * local.position, transform * Vector2(local.end.x, local.position.y),
		transform * local.end, transform * Vector2(local.position.x, local.end.y),
	]
	var rect := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		rect = rect.expand(corner)
	return rect


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect


func _area(rect: Rect2) -> float:
	return maxf(rect.size.x, 0.0) * maxf(rect.size.y, 0.0)


## The field kit's unlock cards: shots of the room, not of the cards.
func _clear_toasts() -> void:
	for _round: int in range(3):
		await _wait(0.5)
		root.get_node("ItemRewardHud").call("dismiss_for_overlay")
		root.get_node("InventoryHud").call("_hide_feature_unlock")
		root.get_node("KeyHud").call("dismiss_unlock_toast")
	await _wait(0.4)


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
	root.get_node("GameState").set("hall_arrival_seen", true)
	room.set("hall_arrival_step", 4)
	var enemy := room.get_node_or_null("CastleGuardian") as CharacterBody2D
	if enemy != null:
		enemy.set("catch_enabled", false)
		enemy.set_physics_process(false)
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


func _rect_array(rect: Rect2) -> Array:
	return [
		snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
		snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1),
	]


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
