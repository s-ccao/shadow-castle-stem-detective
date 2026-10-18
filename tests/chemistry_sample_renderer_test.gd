extends SceneTree

const HOME_MARKER := "/.godot/chemistry-vfx-"
const EXPECTED := {
	"burning_paper": [["paper:solid"], ["ash:grains", "smoke:gas"], ["ash", "smoke"]],
	"melting_ice": [["water:solid"], ["water:liquid"], []],
	"breaking_glass": [["glass:solid"], ["glass:pieces"], []],
	"dissolving_sugar": [["water:liquid", "sugar:grains"], ["water:liquid", "sugar:dissolved"], []],
	"rusting_iron": [["iron:solid"], ["rust:solid"], ["rust"]],
	"melting_wax": [["wax:solid"], ["wax:liquid"], []],
	"baking_soda_vinegar": [["vinegar:liquid", "soda:grains"], ["vinegar:liquid", "co2:gas"], ["co2"]],
	"boiling_water": [["water:liquid"], ["water:gas"], []],
	"cooking_egg": [["egg_raw:liquid"], ["egg_set:solid"], ["egg_set"]],
	"tearing_cloth": [["cloth:fibre"], ["cloth:pieces"], []],
	"silver_tarnish": [["silver:solid"], ["tarnish:solid"], ["tarnish"]],
	"magnet_attracting": [["steel:bar", "iron:pieces"], ["steel:bar", "iron:cling"], []],
	"milk_souring": [["milk:liquid"], ["curd:pieces", "milk:liquid"], ["curd"]],
	"salt_crystallising": [["water:liquid", "salt:dissolved"], ["salt:grains"], []],
	"bronze_reaction": [["bronze:solid"], ["bronze:solid", "fume:gas", "heat:glow"], ["fume"]],
	"stretching_spring": [["steel:coil"], ["steel:coil"], []],
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not OS.get_environment("HOME").contains(HOME_MARKER):
		printerr("chemistry_sample_renderer_test: isolated chemistry-vfx HOME required")
		quit(1)
		return
	var script := load("res://scripts/sample_dish_view.gd") as GDScript
	var controller := load("res://scripts/change_sorting_minigame.gd") as GDScript
	_expect(script != null and script.can_instantiate(), "Renderer compiles")
	_expect(controller != null and controller.can_instantiate(), "Production sample catalog compiles")
	if not failures.is_empty():
		quit(1)
		return
	var samples: Dictionary = controller.get_script_constant_map()["SAMPLES"]
	var constants: Dictionary = script.get_script_constant_map()
	var duration: float = constants["CHANGE_TIME"]
	_expect(samples.size() == 16, "Exactly the original 16 samples")
	_expect(duration >= 2.4 and duration <= 2.8, "Observation lasts 2.4–2.8 seconds")
	var parent := Control.new()
	root.add_child(parent)
	var presets := {}
	for id: String in EXPECTED:
		var catalog: Dictionary = samples[id]
		var expected: Array = EXPECTED[id]
		_expect(PackedStringArray(catalog["before"]) == PackedStringArray(expected[0]), id + ": original before set")
		_expect(PackedStringArray(catalog["after"]) == PackedStringArray(expected[1]), id + ": original after set")
		_expect(bool(catalog["chemical"]) == not expected[2].is_empty(), id + ": science classification untouched")
		var dish: Control = script.new()
		dish.set("before", PackedStringArray(catalog["before"]))
		dish.set("after", PackedStringArray(catalog["after"]))
		dish.set("sample_id", id)
		dish.size = Vector2(600, 220)
		parent.add_child(dish)
		dish.set_process(false)
		var snap: Dictionary = dish.call("effect_snapshot")
		_expect(snap["preset"] == id and snap["phase"] == 0, id + ": distinct BEFORE preset")
		_expect(not dish.is_processing(), id + ": static dish has no processing")
		_expect(dish.call("new_substances") == PackedStringArray(expected[2]), id + ": exact new-substance set")
		_expect(not snap["observation_marks"], id + ": no ungraded answer badges")
		_expect(snap["time_lapse"] == (id not in ["breaking_glass", "tearing_cloth", "magnet_attracting", "stretching_spring"]), id + ": truthful time-lapse metadata")
		if id in ["tearing_cloth", "magnet_attracting", "stretching_spring"]:
			var onset: float = {"tearing_cloth": 0.416, "magnet_attracting": 1.248, "stretching_spring": 1.04}[id]
			_expect(is_equal_approx(float(dish.call("sound_onset_seconds")), onset), id + ": cue follows tearing, contact or release")
		presets[snap["preset_index"]] = true
		dish.call("play")
		dish.call("_process", duration * 0.5)
		dish.set_process(false)
		snap = dish.call("effect_snapshot")
		var mid_seed: float = snap["seed"]
		_expect(snap["phase"] == 1 and is_equal_approx(snap["progress"], 0.5), id + ": bounded changing phase")
		_expect(snap["active"] and snap["raster_assets"] == 4, id + ": raster-backed active effect")
		dish.set("allow_observation_marks", true)
		var updates: int = snap["uniform_updates"]
		var effect_time: float = snap["effect_time"]
		parent.hide()
		dish.call("_process", duration)
		snap = dish.call("effect_snapshot")
		_expect(snap["phase"] == 2 and not dish.call("is_playing"), id + ": hidden bookkeeping finishes")
		_expect(snap["uniform_updates"] == updates and snap["effect_time"] == effect_time, id + ": hidden renderer does not advance/upload")
		_expect(not snap["observation_marks"], id + ": AFTER is still not graded")
		parent.show()
		dish.set("verdict", 1)
		_expect(dish.call("effect_snapshot")["observation_marks"], id + ": optional marks require actual verdict")
		dish.call("reset_dish")
		snap = dish.call("effect_snapshot")
		_expect(snap["phase"] == 0 and snap["progress"] == 0.0 and snap["effect_time"] == 0.0, id + ": reset clears every clock")
		_expect(dish.get("verdict") == -1 and not snap["observation_marks"], id + ": reset clears grading")
		dish.call("play")
		dish.call("_process", duration * 0.5)
		dish.set_process(false)
		snap = dish.call("effect_snapshot")
		_expect(snap["seed"] == mid_seed and is_equal_approx(snap["effect_time"], duration * 0.5), id + ": repeat is deterministic")
		if id in ["melting_ice", "dissolving_sugar", "melting_wax"]:
			_expect(not snap["emits_vapor"] and not snap["emits_bubbles"] and not snap["emits_flame"], id + ": no misleading gas/flame")
		dish.set("sample_id", "")
		_expect(dish.call("effect_snapshot")["preset"] == id, id + ": legacy before-set fallback")
		dish.queue_free()
		await process_frame
	_expect(presets.size() == 16, "All 16 rendering modes are distinct")
	var shader_source := FileAccess.get_file_as_string("res://assets/chemistry/sample_tray/materials.gdshader")
	_expect(not shader_source.contains("TIME"), "No unbounded global shader clock")
	_expect(not shader_source.contains("hint_screen_texture"), "No framebuffer-copy effect per thumbnail")
	var before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for cycle: int in range(24):
		var dish: Control = script.new()
		parent.add_child(dish)
		dish.call("play")
		dish.call("_process", 0.7)
		dish.queue_free()
		await process_frame
	await process_frame
	_expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= before_nodes, "24 close/free cycles leave no nodes or particles")
	parent.queue_free()
	await process_frame
	print("chemistry_sample_renderer_test: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)
