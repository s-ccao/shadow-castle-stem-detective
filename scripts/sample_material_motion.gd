class_name SampleMaterialMotion
extends RefCounted

const GEOMETRY: Dictionary = preload("res://assets/chemistry/sample_tray/physical_geometry.gd").DATA
const DURATION := 2.6
const FLOOR_Y := 90.0
const GLASS_SCALE := 79.0 / 64.0
const RELEASE_TIME := 0.12
const IMPACT_TIME := 0.60
const START_Y := 32.0
const CONTACT_Y := FLOOR_Y - (float(GEOMETRY["glass_bottom"]) - 32.0) * GLASS_SCALE
const GRAVITY := 2.0 * (CONTACT_Y - START_Y) / ((IMPACT_TIME - RELEASE_TIME) ** 2)
const STEP := 1.0 / 240.0
const RESTITUTION := 0.18
const ICE_DENSITY := 917.0
const WATER_DENSITY := 1000.0

static var _frames: Array[Dictionary] = []
static var _impacts: Array[Vector2] = []


static func glass_origins() -> PackedVector2Array:
	var origins := PackedVector2Array()
	for piece: Dictionary in GEOMETRY["glass_pieces"]:
		origins.append(Vector2(piece["centroid"][0], piece["centroid"][1]))
	return origins


static func support_y(index: int, angle: float, flatten: float) -> float:
	var support := -INF
	for point: Array in GEOMETRY["glass_pieces"][index]["hull"]:
		var rotated := Vector2(point[0], point[1]).rotated(angle)
		support = maxf(support, rotated.y * GLASS_SCALE * flatten)
	return support


static func glass_at(seconds: float) -> Dictionary:
	if _frames.is_empty():
		_build_glass_frames()
	var time := clampf(seconds, 0.0, DURATION)
	if time <= IMPACT_TIME:
		var fall_time := maxf(0.0, time - RELEASE_TIME)
		var center := Vector2(150.0, START_Y + GRAVITY * fall_time * fall_time * 0.5)
		var poses := PackedVector4Array()
		for origin: Vector2 in glass_origins():
			var point := center + (origin - Vector2(32, 32)) * GLASS_SCALE
			poses.append(Vector4(point.x, point.y, 0.0, 1.0))
		return {"poses": poses, "fractured": false, "vertical_speed": GRAVITY * fall_time}
	var frame := (time - IMPACT_TIME) / STEP
	var index := mini(int(frame), _frames.size() - 1)
	var next := mini(index + 1, _frames.size() - 1)
	var poses := PackedVector4Array()
	for piece: int in range(7):
		var pose: Vector4 = _frames[index]["poses"][piece].lerp(_frames[next]["poses"][piece], frame - floorf(frame))
		pose.y = minf(pose.y, FLOOR_Y - support_y(piece, pose.z, pose.w))
		poses.append(pose)
	return {
		"poses": poses, "fractured": true, "velocities": _frames[index]["velocities"],
		"sleeping": _frames[index]["sleeping"], "impacts": _impacts,
	}


static func ice_at(seconds: float) -> Dictionary:
	var heating := clampf((seconds - 0.12) / (DURATION - 0.12), 0.0, 1.0)
	var cut := mini(256, int(heating * 256.0))
	var row: Dictionary = GEOMETRY["ice_erosion"][cut]
	var section := float(row["pixels"]) / float(GEOMETRY["ice_pixel_count"])
	# Remaining volume uses a similar-section thickness model, not a fluid simulation.
	var solid_volume := pow(section, 1.5)
	var water_volume := (1.0 - solid_volume) * ICE_DENSITY / WATER_DENSITY
	return {
		"cut": cut, "bottom": row["bottom"], "solid_volume": solid_volume,
		"water_volume": water_volume, "mass": solid_volume * ICE_DENSITY + water_volume * WATER_DENSITY,
	}


static func _build_glass_frames() -> void:
	var poses := PackedVector4Array()
	var velocities := PackedVector3Array()
	var ages := PackedFloat32Array()
	var sleeping: Array[bool] = []
	var momentum := 0.0
	var origins := glass_origins()
	for index: int in range(7):
		var origin := origins[index]
		var point := Vector2(150.0, CONTACT_Y) + (origin - Vector2(32, 32)) * GLASS_SCALE
		poses.append(Vector4(point.x, point.y, 0.0, 1.0))
		var velocity := Vector3((origin.x - 32.0) * 2.1, 23.0 - (origin.y - 20.0) * 1.6, (origin.x - 32.0) * 0.10)
		velocities.append(velocity)
		momentum += velocity.x * float(GEOMETRY["glass_pieces"][index]["pixels"]) / float(GEOMETRY["glass_pixel_count"])
		ages.append(-1.0)
		sleeping.append(false)
	for index: int in range(7):
		velocities[index].x -= momentum
	_store_frame(poses, velocities, sleeping)
	for tick: int in range(ceili((DURATION - IMPACT_TIME) / STEP)):
		for index: int in range(7):
			if sleeping[index]:
				continue
			var pose := poses[index]
			var velocity := velocities[index]
			pose.x += velocity.x * STEP
			pose.y += velocity.y * STEP + 0.5 * GRAVITY * STEP * STEP
			velocity.y += GRAVITY * STEP
			pose.z += velocity.z * STEP
			if ages[index] >= 0.0:
				ages[index] += STEP
				# Projection of the thin pane tipping onto the tray, not shrinking its material.
				pose.w = lerpf(1.0, 0.28, smoothstep(0.0, 0.28, ages[index]))
			var support := support_y(index, pose.z, pose.w)
			if pose.y + support >= FLOOR_Y:
				pose.y = FLOOR_Y - support
				if ages[index] < 0.0:
					ages[index] = 0.0
				var energy_before := _kinetic_energy(index, velocity)
				velocity.x *= 0.65
				velocity.y = -maxf(0.0, velocity.y) * RESTITUTION
				velocity.z *= 0.35
				velocity.x = move_toward(velocity.x, 0.0, GRAVITY * STEP * 1.4)
				velocity.z = move_toward(velocity.z, 0.0, STEP * 12.0)
				if absf(velocity.y) < 6.0:
					velocity.y = 0.0
				_impacts.append(Vector2(energy_before, _kinetic_energy(index, velocity)))
				sleeping[index] = velocity == Vector3.ZERO and ages[index] >= 0.28
			poses[index] = pose
			velocities[index] = velocity
		_store_frame(poses, velocities, sleeping)


static func _store_frame(poses: PackedVector4Array, velocities: PackedVector3Array, sleeping: Array[bool]) -> void:
	_frames.append({"poses": poses.duplicate(), "velocities": velocities.duplicate(), "sleeping": sleeping.duplicate()})


static func _kinetic_energy(index: int, velocity: Vector3) -> float:
	var piece: Dictionary = GEOMETRY["glass_pieces"][index]
	var mass := float(piece["pixels"]) / float(GEOMETRY["glass_pixel_count"])
	var radius_squared := 0.0
	for point: Array in piece["hull"]:
		radius_squared += Vector2(point[0], point[1]).length_squared() * GLASS_SCALE * GLASS_SCALE
	radius_squared /= float(piece["hull"].size())
	return 0.5 * mass * (velocity.x * velocity.x + velocity.y * velocity.y + radius_squared * velocity.z * velocity.z)
