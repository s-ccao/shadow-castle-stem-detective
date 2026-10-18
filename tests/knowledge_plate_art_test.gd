extends SceneTree

const PLATE_ROOT := "res://assets/ui/knowledge_plates/"
const PRINT_ROOT := "res://assets/ui/guidance/footprints/"
const EXPECTED := {
	"ChemistryRoomKnowledge": "chemical_physical",
	"CircuitRoomKnowledge": "closed_circuit",
	"GreenhouseRoomKnowledge": "photosynthesis",
	"DiningHallKnowledge": "independent_time",
	"LibraryRoomKnowledge": "additive_light",
}

var failures: Array[String] = []
var evidence := ""
var report: Dictionary = {}
var asset_reports: Array[Dictionary] = []
var hall: Node2D


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	evidence = OS.get_environment("KNOWLEDGE_ART_EVIDENCE")
	var home := OS.get_environment("HOME")
	if not home.contains("/.godot/knowledge-art-") or not home.begins_with(evidence + "/") or evidence.is_empty():
		printerr("Safety refusal: use an isolated HOME inside KNOWLEDGE_ART_EVIDENCE (.godot/knowledge-art-*).")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence.path_join("native"))
	report["project"] = ProjectSettings.globalize_path("res://")
	report["home"] = OS.get_environment("HOME")
	report["godot"] = Engine.get_version_info()
	report["viewport"] = [1024, 768]
	report["dossier_sha256"] = FileAccess.get_sha256("res://scripts/hall_knowledge_dossier.gd")
	var palette: Array = JSON.parse_string(FileAccess.get_file_as_string(PLATE_ROOT + "manifest.json"))["visual_system"]["palette"]
	var allowed_colors: Dictionary = {}
	for hex: String in palette:
		allowed_colors[Color(hex).to_rgba32()] = true
	var hashes: Dictionary = {}
	for id: String in EXPECTED:
		var path: String = PLATE_ROOT + EXPECTED[id] + ".png"
		_check_raster(path, Vector2i(192, 256), 2, allowed_colors)
		var hash := FileAccess.get_sha256(path)
		_expect(not hashes.has(hash), id + " has its own concept illustration")
		hashes[hash] = true
	for side: String in ["left", "right"]:
		var path := PRINT_ROOT + "shoe_" + side + ".png"
		_check_raster(path, Vector2i(24, 14), 1, allowed_colors)
		var image := _load_png(path)
		if image == null:
			continue
		var heel_pixels := 0
		var toe_pixels := 0
		var separated := true
		for y: int in range(14):
			for x: int in range(24):
				if image.get_pixel(x, y).a < 0.5:
					continue
				if x < 8:
					heel_pixels += 1
				if x > 10:
					toe_pixels += 1
				if x == 9:
					separated = false
		_expect(separated and toe_pixels > heel_pixels * 2 and heel_pixels > 10, side + " shoe has separated heel and broader +X toe")
	_expect(
		FileAccess.get_sha256(PRINT_ROOT + "shoe_left.png") != FileAccess.get_sha256(PRINT_ROOT + "shoe_right.png"),
		"Left/right soles retain distinct anatomy"
	)
	await _check_game_dossiers()
	report["assets"] = asset_reports
	report["failures"] = failures
	report["result"] = "PASS" if failures.is_empty() else "FAIL"
	var label := "native" if "--capture" in OS.get_cmdline_user_args() else "headless"
	var output := FileAccess.open(evidence.path_join(label + "-report.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
	print("knowledge_plate_art_test: " + str(report["result"]))
	quit(0 if failures.is_empty() else 1)


func _check_raster(path: String, expected: Vector2i, pixel_scale: int, allowed_colors: Dictionary) -> void:
	var image := _load_png(path)
	_expect(image != null, path + " loads as a finished raster")
	if image == null:
		return
	_expect(image.get_size() == expected, path.get_file() + " exact dimensions")
	if image.get_size() != expected:
		return
	var colors: Dictionary = {}
	var valid_alpha := true
	var valid_palette := true
	var valid_clusters := true
	var transparent_pixels := 0
	var opaque_pixels := 0
	for y: int in range(expected.y):
		for x: int in range(expected.x):
			var color := image.get_pixel(x, y)
			valid_alpha = valid_alpha and (color.a == 0.0 or color.a == 1.0)
			if color.a == 0.0:
				transparent_pixels += 1
			else:
				opaque_pixels += 1
				colors[color.to_rgba32()] = true
				valid_palette = valid_palette and allowed_colors.has(color.to_rgba32())
			var anchor := Vector2i(x - x % pixel_scale, y - y % pixel_scale)
			valid_clusters = valid_clusters and color == image.get_pixelv(anchor)
	_expect(valid_alpha and transparent_pixels > 0 and opaque_pixels > 0, path.get_file() + " has clean binary alpha")
	_expect(valid_palette and colors.size() <= 28, path.get_file() + " uses only the shared palette")
	_expect(valid_clusters, path.get_file() + " preserves the authored integer pixel grid")
	asset_reports.append({
		"path": path,
		"dimensions": [expected.x, expected.y],
		"palette_colors": colors.size(),
		"opaque_pixels": opaque_pixels,
		"transparent_pixels": transparent_pixels,
		"binary_alpha": valid_alpha,
		"pixel_grid": pixel_scale,
		"grid_valid": valid_clusters,
		"sha256": FileAccess.get_sha256(path),
	})


func _load_png(path: String) -> Image:
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image


func _check_game_dossiers() -> void:
	var state := root.get_node("GameState")
	var locale := root.get_node("CaseLocale")
	state.set("_loading_save", true)
	state.call("reset_new_game")
	state.game_started = true
	state.call("grant_wake_room_toolkit")
	state.call("add_key", "wake_room_key")
	state.call("add_key", "chemistry_room_key")
	state.return_spawn_id = "wake_room_first_arrival"
	hall = (load("res://scenes/game_world.tscn") as PackedScene).instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	hall.set("guardian_entry_sequence_played", true)
	hall.call("_set_hall_arrival_step", 4)
	state.hall_arrival_seen = true
	hall.call("close_message_panel")
	hall.set_process(false)
	(hall.get_node("player") as Node).set_physics_process(false)
	var guardian := hall.get_node("CastleGuardian")
	guardian.call("set_cinematic_hold", true)
	guardian.set_physics_process(false)
	for language: String in ["en", "zh"]:
		locale.call("set_language", language)
		for id: String in EXPECTED:
			hall.call("_inspect_hall_knowledge", id)
			await process_frame
			var dossier := hall.get_node_or_null("HallKnowledgeDossier") as CanvasLayer
			_expect(dossier != null and dossier.visible, id + " opens the actual game dossier in " + language)
			if dossier == null:
				continue
			var artwork := dossier.find_child("KnowledgeArtwork", true, false) as TextureRect
			var expected_path: String = PLATE_ROOT + EXPECTED[id] + ".png"
			_expect(artwork != null and artwork.texture != null, id + " has its KnowledgeArtwork node")
			if artwork != null and artwork.texture != null:
				_expect(artwork.texture.resource_path == expected_path, id + " selects concept PNG, not exhibit prop")
				_expect(not artwork.texture is AtlasTexture, id + " never alpha-crops a scene prop")
				_expect(artwork.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, id + " uses nearest filtering")
				_expect(artwork.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED, id + " displays original-size art")
				_expect(artwork.size.x == 192.0 and artwork.size.y >= 256.0, id + " reserves full native plate")
			var record: Dictionary = dossier.get("exhibit")
			_expect(not state.call("has_story_flag", str(record["knowledge_flag"])), id + " is not filed just by viewing")
			await _capture(str(EXPECTED[id]) + "-" + language, dossier)
			var file_button := dossier.find_child("FileKnowledgeButton", true, false) as Button
			_expect(file_button != null, id + " retains filing control")
			if file_button != null:
				file_button.pressed.emit()
				await process_frame
				_expect(state.call("has_story_flag", str(record["knowledge_flag"])), id + " filing still records knowledge")
				hall.call("_inspect_hall_knowledge", id)
				await process_frame
				_expect(bool(dossier.get("already_recorded")), id + " reopens as review")
				_expect(artwork.texture.resource_path == expected_path, id + " review retains the same concept")
			dossier.call("close")
			# Reset only the knowledge flag so the second language checks the same unfiled flow.
			state.story_flags.erase(str(record["knowledge_flag"]))
	locale.call("set_language", "en")
	current_scene = null
	hall.queue_free()
	await process_frame
	state.game_started = false
	state.set("_loading_save", false)
	# Let the audio thread release test-only playback before the SceneTree exits.
	root.get_node("GameAudio").queue_free()
	await create_timer(0.2).timeout


func _capture(label: String, dossier: CanvasLayer) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var frame := dossier.get("frame") as Control
	_expect(Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(frame.get_global_rect()), label + " full frame fits 1024x768")
	var image := root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1024, 768), label + " capture is native-size")
	_expect(image.save_png(evidence.path_join("native/" + label + ".png")) == OK, label + " native screenshot saved")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)
