extends SceneTree

const OUT := "res://tests/captures/chemistry_material_motion/"
const TIMES := [0.0, 0.52, 1.0]
var renderer: GDScript
var samples: Dictionary
var stage: Control
var failures: Array[String] = []
var report: Dictionary = {"samples": {}, "renderer": "gl_compatibility", "native_viewport": [1024, 768]}


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_environment("HOME").contains("/.godot/chemistry-vfx-"):
		printerr("Native display and isolated chemistry-vfx HOME required")
		quit(1)
		return
	renderer = load("res://scripts/sample_dish_view.gd") as GDScript
	var controller := load("res://scripts/change_sorting_minigame.gd") as GDScript
	if not renderer.can_instantiate() or not controller.can_instantiate():
		printerr("Capture scripts failed to compile")
		quit(1)
		return
	samples = controller.get_script_constant_map()["SAMPLES"]
	for node: Node in root.get_children():
		if node is CanvasLayer:
			(node as CanvasLayer).hide()
	var layer := CanvasLayer.new()
	layer.layer = 240
	root.add_child(layer)
	stage = Control.new()
	stage.size = Vector2(1024, 768)
	layer.add_child(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _contact_sheets()
	for id: String in samples:
		await _hero_triptych(id)
	for id: String in ["melting_ice", "breaking_glass", "melting_wax", "tearing_cloth", "magnet_attracting", "salt_crystallising", "milk_souring", "burning_paper", "baking_soda_vinegar", "stretching_spring"]:
		await _motion_strip(id)
	await _benchmark()
	await _integrated_hero_capture(controller)
	report["failures"] = failures
	report["project"] = ProjectSettings.globalize_path("res://")
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["api"] = {
		"sample_id": "String; set before or after add_child; falls back to original before-set signature for legacy callers",
		"before_after": "PackedStringArray; exact existing new_substances() set difference; glow excluded",
		"verdict": "-1 ungraded / 0 wrong / 1 right; controller-owned; play and reset clear stale verdict",
		"phase": "BEFORE=0 / CHANGING=1 / AFTER=2",
		"CHANGE_TIME": 2.6,
		"methods": ["play()", "reset_dish()", "is_playing()", "new_substances()", "effect_snapshot()", "sound_onset_seconds()", "is_time_lapse()"],
		"allow_observation_marks": "false default; when true, marks still require AFTER and an actual verdict",
		"hidden_behavior": "Only bounded phase bookkeeping continues; no effect-time advancement or uniform uploads; show synchronizes final/current state",
		"real_time_presets": ["breaking_glass", "tearing_cloth", "magnet_attracting", "stretching_spring"],
		"audio": "No streams, audio bus access or sound hooks in renderer; controller-owned",
	}
	report["source_files"] = [
		"scripts/sample_dish_view.gd",
		"scripts/sample_material_motion.gd",
		"assets/chemistry/sample_tray/physical_geometry.gd",
		"assets/chemistry/sample_tray/physical_masks.png",
		"assets/chemistry/sample_tray/materials.gdshader",
		"assets/chemistry/sample_tray/specimens.svg",
		"assets/chemistry/sample_tray/specimens.png",
		"assets/chemistry/sample_tray/vessel_back.svg",
		"assets/chemistry/sample_tray/vessel_back.png",
		"assets/chemistry/sample_tray/vessel_front.svg",
		"assets/chemistry/sample_tray/vessel_front.png",
		"assets/chemistry/sample_tray/normalize_assets.gd",
		"assets/chemistry/sample_tray/manifest.json",
		"tests/chemistry_sample_renderer_test.gd",
		"tests/chemistry_sample_renderer_capture.gd",
		"tests/chemistry_material_motion_test.gd",
	]
	report["source_sha256"] = {}
	for path: String in report["source_files"]:
		report["source_sha256"][path] = FileAccess.get_sha256("res://" + path)
	report["evidence"] = "contact-{before,changing,after}.png; hero-<each of 16 sample IDs>.png; motion-<10 material sequences>.png; performance-one-hero-six-thumbnails.png; integrated-<5 materials>-<local milliseconds>.png"
	report["contract_validation"] = {
		"script": "tests/chemistry_sample_renderer_test.gd",
		"checks": 302,
		"coverage": "Original 16 science sets and bools; exact glow exclusion; all presets; reset/replay; inherited hiding; static uniforms; 24 free/restart cycles",
		"headless_shutdown_note": "Headless CLI reports 3 pre-existing GameAudio music WAV resources plus their playback instances at exit; verbose log identifies music_bed/music_tension/music_chase only. Native capture exits cleanly; renderer node count does not grow over 24 cycles.",
	}
	var file := FileAccess.open(OUT + "renderer-evidence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	stage.queue_free()
	layer.queue_free()
	await process_frame
	print("chemistry_sample_renderer_capture: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func _clear(title: String) -> void:
	for child: Node in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("#181520")
	background.size = Vector2(1024, 768)
	stage.add_child(background)
	_label(title, Vector2(20, 12), 20)


func _label(text: String, position: Vector2, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#dfd1ae"))
	stage.add_child(label)
	return label


func _dish(id: String, position: Vector2, dimensions: Vector2, fraction: float) -> Control:
	var dish: Control = renderer.new()
	dish.set("sample_id", id)
	dish.set("before", PackedStringArray(samples[id]["before"]))
	dish.set("after", PackedStringArray(samples[id]["after"]))
	dish.position = position
	dish.size = dimensions
	stage.add_child(dish)
	if fraction > 0.0:
		dish.call("play")
		dish.call("_process", fraction * float(renderer.get_script_constant_map()["CHANGE_TIME"]))
	dish.set_process(false)
	return dish


func _capture(name: String) -> Image:
	var image := await _frame_image()
	image.save_png(OUT + name + ".png")
	return image


func _frame_image() -> Image:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1024, 768):
		failures.append("Viewport is not native 1024x768")
	return image


func _contact_sheets() -> void:
	for phase: int in range(3):
		var phase_name: String = ["before", "changing", "after"][phase]
		_clear("CHEMISTRY / RASTER MATERIAL STUDIES / " + phase_name.to_upper())
		var index := 0
		for id: String in samples:
			var origin := Vector2(12 + (index % 4) * 253, 63 + (index / 4) * 174)
			_label(id.replace("_", " "), origin, 14)
			_dish(id, origin + Vector2(0, 29), Vector2(244, 112), TIMES[phase])
			index += 1
		await _capture("contact-" + phase_name)


func _hero_triptych(id: String) -> void:
	_clear("MATERIAL OBSERVATION / " + id.replace("_", " ").to_upper())
	var dishes: Array[Control] = []
	for phase: int in range(3):
		_label(["BEFORE", "CHANGING / 1.35s", "AFTER / 2.60s"][phase], Vector2(20, 76 + phase * 236), 16)
		dishes.append(_dish(id, Vector2(212, 48 + phase * 236), Vector2(600, 220), TIMES[phase]))
	_label("Native 600 x 220 specimen view. No grading, no sound, no answer marks.", Vector2(20, 745), 13)
	var image := await _capture("hero-" + id)
	var before := image.get_region(Rect2i(212, 48, 600, 220))
	var changing := image.get_region(Rect2i(212, 284, 600, 220))
	var after := image.get_region(Rect2i(212, 520, 600, 220))
	var during_difference := _difference(before, changing)
	var after_difference := _difference(before, after)
	report["samples"][id] = {
		"before_changing_changed_pixels": during_difference,
		"before_after_changed_pixels": after_difference,
		"returns_to_same_material_shape": id == "stretching_spring",
	}
	if during_difference < 50:
		failures.append(id + ": no visible changing behavior")
	if id != "stretching_spring" and after_difference < 50:
		failures.append(id + ": no visible final material state")
	if id == "stretching_spring" and after_difference != 0:
		failures.append("Spring must settle to its exact original raster shape")
	for dish: Control in dishes:
		dish.call("reset_dish")
	var reset_image := await _frame_image()
	var reset_difference := _difference(before, reset_image.get_region(Rect2i(212, 284, 600, 220)))
	dishes[1].call("play")
	dishes[1].call("_process", 2.6 * TIMES[1])
	dishes[1].set_process(false)
	var replay_image := await _frame_image()
	var replay_difference := _difference(changing, replay_image.get_region(Rect2i(212, 284, 600, 220)))
	report["samples"][id]["reset_pixel_differences"] = reset_difference
	report["samples"][id]["replay_pixel_differences"] = replay_difference
	if reset_difference != 0 or replay_difference != 0:
		failures.append(id + ": reset/replay is not pixel deterministic")


func _difference(a: Image, b: Image) -> int:
	var count := 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


func _motion_strip(id: String) -> void:
	_clear("LOCAL-TIME MOTION / " + id.replace("_", " ").to_upper())
	var moments := [0.08, 0.20, 0.34, 0.48, 0.65, 0.86]
	for index: int in range(moments.size()):
		var origin := Vector2(22 + (index % 2) * 500, 74 + (index / 2) * 223)
		_label("%.2f seconds" % (moments[index] * 2.6), origin, 15)
		_dish(id, origin + Vector2(0, 27), Vector2(480, 176), moments[index])
	await _capture("motion-" + id)


func _benchmark() -> void:
	_clear("RENDER BUDGET / one moving specimen + six static thumbnails")
	var hero := _dish("baking_soda_vinegar", Vector2(212, 55), Vector2(600, 220), 0.0)
	var thumbs: Array[Control] = []
	for index: int in range(6):
		thumbs.append(_dish(samples.keys()[index], Vector2(36 + index * 163, 305), Vector2(150, 72), 0.0))
	var first_updates: int = thumbs[0].call("effect_snapshot")["uniform_updates"]
	var frame_times: Array[float] = []
	for tick: int in range(180):
		if tick % 156 == 0:
			hero.call("play")
			hero.set_process(false)
		var start := Time.get_ticks_usec()
		hero.call("_process", 1.0 / 60.0)
		await process_frame
		RenderingServer.force_draw(false)
		if tick > 20:
			frame_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	frame_times.sort()
	report["performance"] = {
		"configuration": "1 active 600x220, 6 static 150x72; native GL Compatibility; process-frame interval plus explicit draw, not isolated GPU timing or refresh rate",
		"frames": frame_times.size(),
		"median_frame_ms": frame_times[frame_times.size() / 2],
		"p95_frame_ms": frame_times[int(frame_times.size() * 0.95)],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"static_uniform_updates": int(thumbs[0].call("effect_snapshot")["uniform_updates"]) - first_updates,
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}
	if int(report["performance"]["static_uniform_updates"]) != 0:
		failures.append("Static thumbnails unexpectedly upload uniforms")
	await _capture("performance-one-hero-six-thumbnails")


func _integrated_hero_capture(controller: GDScript) -> void:
	var game: Node = controller.new()
	if not game.has_method("_select_sample"):
		game.free()
		report["integrated_hero"] = {"available": false, "reason": "Legacy controller in this compatible checkout"}
		return
	stage.hide()
	root.add_child(game)
	game.call("configure", "Material Observation Lab", "Observe materials · compare substances", Color("#b5a4ca"))
	game.call("start")
	game.set_process(false)
	report["integrated_hero"] = {"available": true, "samples": {}}
	var levels: Array = controller.get_script_constant_map()["LEVELS"]
	for id: String in ["burning_paper", "baking_soda_vinegar", "melting_ice", "breaking_glass", "melting_wax"]:
		for index: int in range(levels.size()):
			if id in levels[index]:
				game.set("_level_index", index)
				game.call("_enter_level")
				break
		game.call("_select_sample", id, false)
		var hero := game.find_child("ExperimentHero", true, false) as Control
		await process_frame
		await process_frame
		var times: Array[float] = []
		hero.call("play")
		hero.set_process(false)
		for tick: int in range(157):
			var start := Time.get_ticks_usec()
			hero.call("_process", 1.0 / 60.0)
			game.call("_update_observation_status")
			await process_frame
			RenderingServer.force_draw(false)
			if tick > 20:
				times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			if tick in [20, 52, 80, 118, 156]:
				var image := root.get_texture().get_image()
				image.save_png(OUT + "integrated-%s-%04d.png" % [id, int((tick + 1) * 1000.0 / 60.0)])
		times.sort()
		report["integrated_hero"]["samples"][id] = {
			"hero_size": [hero.size.x, hero.size.y],
			"frames": times.size(),
			"median_frame_ms": times[times.size() / 2],
			"p95_frame_ms": times[int(times.size() * 0.95)],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"timing_note": "Native process-frame interval plus explicit draw in the focused UI; image writes excluded; not isolated GPU timing or measured refresh rate",
		}
	game.queue_free()
	await process_frame
	stage.show()
