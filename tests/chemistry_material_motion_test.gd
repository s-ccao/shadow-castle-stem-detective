extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not OS.get_environment("HOME").begins_with(ProjectSettings.globalize_path("res://.godot/chemistry-vfx-")):
		printerr("Project-local chemistry-vfx HOME required")
		quit(2)
		return
	var motion := load("res://scripts/sample_material_motion.gd") as GDScript
	var renderer := load("res://scripts/sample_dish_view.gd") as GDScript
	var data: Dictionary = motion.GEOMETRY
	var mask := Image.load_from_file("res://assets/chemistry/sample_tray/physical_masks.png")
	var art := Image.load_from_file("res://assets/chemistry/sample_tray/specimens.png")
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for y: int in range(64):
		for x: int in range(64):
			var region := roundi(mask.get_pixel(x, y).r * 255.0)
			var present := art.get_pixel(128 + x, y).a > 0.01
			_expect((region > 0) == present and region <= 7, "Glass masks exactly partition the source pixel")
			if region > 0 and region <= 7:
				counts[region - 1] += 1
	for index: int in range(7):
		_expect(counts[index] == int(data["glass_pieces"][index]["pixels"]), "Each irregular piece retains its source area")
	var final: Dictionary = motion.glass_at(2.6)
	_expect(final["sleeping"].all(func(value: bool) -> bool: return value), "Every fragment comes to rest")
	for impact: Vector2 in final["impacts"]:
		_expect(impact.y <= impact.x + 0.00001, "A contact never adds kinetic energy")
	for tick: int in range(625):
		var seconds := float(tick) / 240.0
		var sample: Dictionary = motion.glass_at(seconds)
		_expect(bool(sample["fractured"]) == (seconds > motion.IMPACT_TIME), "Impact precedes fragmentation")
		for index: int in range(7):
			var pose: Vector4 = sample["poses"][index]
			_expect(pose.y + motion.support_y(index, pose.z, pose.w) <= motion.FLOOR_Y + 0.0001, "No rendered shard penetrates the tray")
			_expect(pose.x > 50.0 and pose.x < 250.0, "Fragments remain inside the tray")
	var early: Dictionary = motion.glass_at(0.25)
	var later: Dictionary = motion.glass_at(0.35)
	_expect(is_equal_approx((later["vertical_speed"] - early["vertical_speed"]) / 0.1, motion.GRAVITY), "The pane accelerates under constant gravity")
	var previous_solid := 1.0
	var previous_water := 0.0
	for tick: int in range(625):
		var ice: Dictionary = motion.ice_at(float(tick) / 240.0)
		_expect(absf(float(ice["mass"]) - motion.ICE_DENSITY) < 0.0001, "Ice and meltwater conserve mass with distinct densities")
		_expect(float(ice["solid_volume"]) <= previous_solid and float(ice["water_volume"]) >= previous_water, "Melting does not regrow ice or remove water")
		previous_solid = ice["solid_volume"]
		previous_water = ice["water_volume"]
	_expect(previous_solid == 0.0 and is_equal_approx(previous_water, 0.917), "The final water volume accounts for ice density")
	for rate: int in [30, 60, 144]:
		var dish: Control = renderer.new()
		dish.set("sample_id", "breaking_glass")
		dish.size = Vector2(600, 220)
		root.add_child(dish)
		dish.call("play")
		dish.set_process(false)
		var elapsed := 0.0
		while elapsed < 1.3:
			var step := minf(1.0 / float(rate), 1.3 - elapsed)
			dish.call("_process", step)
			elapsed += step
		var material: ShaderMaterial = dish.get("_effect_material")
		var poses: PackedVector4Array = material.get_shader_parameter("glass_pose")
		var expected: PackedVector4Array = motion.glass_at(1.3)["poses"]
		for index: int in range(7):
			_expect(poses[index].distance_to(expected[index]) < 0.001, "Rendered motion is identical at %d FPS" % rate)
		_expect(is_equal_approx(float(dish.call("sound_onset_seconds")), motion.IMPACT_TIME), "Audio and fracture share one contact time")
		dish.queue_free()
		await process_frame
	print("chemistry_material_motion_test: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
