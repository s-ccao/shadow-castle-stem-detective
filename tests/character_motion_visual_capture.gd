extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
var output_directory := "res://.godot/actor-polish/evidence"
var failures: Array[String] = []


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_directory = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Native rendering is required for motion evidence.")
		quit(1)
		return
	output_directory = ProjectSettings.globalize_path(output_directory)
	DirAccess.make_dir_recursive_absolute(output_directory)
	var state := root.get_node("GameState")
	state.set("_loading_save", true)
	state.reset_new_game()
	state.developer_mode = false
	for child: Node in root.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).hide()
	await _capture_motion_lanes()
	await _capture_chemistry_interview()
	print("character_motion_visual_capture: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func _capture_motion_lanes() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	_label(stage, "LOCOMOTION / NATIVE 1024 x 768", Vector2(36, 18), 22)
	_label(stage, "Production raster sheets. Actual physics travel; no frame freezing.", Vector2(36, 52), 16)
	var actors: Array[CharacterBody2D] = []
	var readouts: Array[Label] = []
	var origins: Array[Vector2] = []
	for index: int in range(3):
		var y := 218.0 + index * 228.0
		var lane := ColorRect.new()
		lane.position = Vector2(32.0, y - 118.0)
		lane.size = Vector2(960.0, 172.0)
		lane.color = Color("#242334") if index % 2 == 0 else Color("#2b2836")
		stage.add_child(lane)
		var actor := load("res://scenes/enemy.tscn" if index == 2 else "res://scenes/player.tscn").instantiate() as CharacterBody2D
		actor.position = Vector2(320.0, y)
		stage.add_child(actor)
		actor.set_physics_process(false)
		if index != 2:
			actor.call("set_room_visual_scale", "chemistry_room")
			actor.set("speed", 180.0 if index == 0 else 252.0)
		else:
			actor.set("behavior", 1)
		actors.append(actor)
		origins.append(actor.position)
		var heading: String = ["DETECTIVE / 180 px/s", "SWIFT CADENCE / 252 px/s", "GUARDIAN / 145 px/s"][index]
		_label(stage, heading, Vector2(48.0, y - 106.0), 16)
		readouts.append(_label(stage, "", Vector2(610.0, y - 40.0), 14))
		var route := PackedVector2Array([
			actor.position + Vector2(80.0, 0.0),
			actor.position + Vector2(150.0, 45.0),
		])
		if index == 2:
			actor.set("path", route)
		else:
			actor.call("move_along_path", route)

	var contact := Image.create_empty(1024, 768, false, Image.FORMAT_RGBA8)
	contact.fill(Color("#171521"))
	var captured := 0
	for tick: int in range(1, 106):
		await physics_frame
		for index: int in range(actors.size()):
			var actor := actors[index]
			actor.call("move_along_path" if index == 2 else "_physics_process", 1.0 / 60.0)
			var sprite := actor.get_node("GuardianCore" if index == 2 else "VisualRoot/CharacterSprite") as AnimatedSprite2D
			readouts[index].text = "%s / frame %d\n%.2fx / travel %.1f px" % [
				sprite.animation, sprite.frame, sprite.speed_scale, actor.position.distance_to(origins[index]),
			]
		if tick not in [12, 36, 54, 102]:
			continue
		var image := await _capture("motion-%02d" % captured)
		for index: int in range(actors.size()):
			var center := actors[index].position
			var crop := Rect2i(Vector2i(center) - Vector2i(128, 160), Vector2i(256, 256))
			contact.blit_rect(image, crop, Vector2i(captured * 256, index * 256))
		captured += 1
	contact.save_png(output_directory.path_join("motion-contact-sheet.png"))
	stage.queue_free()
	await process_frame


func _capture_chemistry_interview() -> void:
	var state := root.get_node("GameState")
	state.game_started = true
	state.hall_arrival_seen = true
	state.current_room_id = "chemistry_room"
	state.return_spawn_id = "chemistry_start"
	var room := (load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await create_timer(0.5).timeout
	var player := room.get_node("Worldsort/player") as CharacterBody2D
	player.set_physics_process(false)
	player.call("cancel_click_movement")
	player.position = Vector2(530.0, 860.0)
	var butler := room.find_child("ButlerNPC", true, false) as AnimatedNpc
	butler.position = Vector2(670.0, 860.0)
	for layer: Node in root.get_children():
		if layer is CanvasLayer:
			(layer as CanvasLayer).hide()
	for layer: Node in room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	for camera_node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := camera_node as Camera2D
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
	player.call("move_along_path", PackedVector2Array([
		Vector2(610.0, 860.0), Vector2(660.0, 915.0),
	]))
	for tick: int in range(1, 91):
		await physics_frame
		player.call("_physics_process", 1.0 / 60.0)
		if tick in [15, 35, 55, 90]:
			await _capture("chemistry-interview-%02d" % tick)
	current_scene = null
	room.queue_free()
	await process_frame


func _label(parent: Node, text: String, position: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#dfcda3"))
	parent.add_child(label)
	return label


func _capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		failures.append("Unexpected viewport size: " + str(image.get_size()))
	var path := output_directory.path_join(name + ".png")
	if image.save_png(path) != OK:
		failures.append("Could not write " + path)
	print("CAPTURED: " + path)
	return image
