class_name OpticalFxRuntime
extends RefCounted

## Shared timing language for Ashford optical effects.
##
## Every light interaction follows the same readable sequence:
## charge -> travel -> impact -> beam trace -> sustained state. Callers keep
## ownership of game state; this module only animates disposable visuals.


static func trace_beam(
	host: Node,
	beam: Line2D,
	start: Vector2,
	finish: Vector2,
	colour: Color,
	final_width: float = 5.0,
	duration: float = 0.24,
	delay: float = 0.0,
	on_complete: Callable = Callable()
) -> Tween:
	beam.visible = true
	beam.points = PackedVector2Array([start, start])
	beam.width = maxf(0.8, final_width * 0.18)
	beam.default_color = Color(colour.r, colour.g, colour.b, 0.08)
	beam.modulate = Color.WHITE
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(point: Vector2) -> void:
			if is_instance_valid(beam):
				beam.points = PackedVector2Array([start, point]),
		start,
		finish,
		duration
	)
	tween.tween_property(beam, "width", final_width, duration)
	tween.tween_property(
		beam,
		"default_color",
		Color(colour.r, colour.g, colour.b, colour.a),
		duration * 0.82
	)
	tween.set_parallel(false)
	if on_complete.is_valid():
		tween.tween_callback(on_complete)
	return tween


static func fade_beam(
	host: Node,
	beam: Line2D,
	duration: float = 0.16,
	hide_after: bool = true
) -> Tween:
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "modulate:a", 0.0, duration)
	if hide_after:
		tween.tween_callback(
			func() -> void:
				if is_instance_valid(beam):
					beam.visible = false
					beam.modulate.a = 1.0
		)
	return tween


static func launch_jewel(
	host: Node,
	parent: CanvasItem,
	start: Vector2,
	finish: Vector2,
	colour: Color,
	duration: float = 0.30,
	on_arrival: Callable = Callable()
) -> Node2D:
	var jewel := Node2D.new()
	jewel.name = "TravellingOpticalJewel"
	jewel.position = start
	jewel.scale = Vector2(0.62, 0.62)
	jewel.rotation = -0.28
	parent.add_child(jewel)

	var halo := Polygon2D.new()
	halo.name = "ChargeHalo"
	halo.polygon = _circle_points(18.0, 28)
	halo.color = Color(colour.r, colour.g, colour.b, 0.18)
	jewel.add_child(halo)

	var frame := Polygon2D.new()
	frame.name = "JewelFrame"
	frame.polygon = PackedVector2Array(
		[
			Vector2(0.0, -13.0),
			Vector2(10.0, -7.0),
			Vector2(12.0, 6.0),
			Vector2(0.0, 14.0),
			Vector2(-12.0, 6.0),
			Vector2(-10.0, -7.0),
		]
	)
	frame.scale = Vector2(1.15, 1.15)
	frame.color = Color(0.84, 0.64, 0.28, 0.98)
	jewel.add_child(frame)

	var core := Polygon2D.new()
	core.name = "JewelCore"
	core.polygon = frame.polygon
	core.color = Color(colour.r, colour.g, colour.b, 0.96)
	jewel.add_child(core)

	var facet := Line2D.new()
	facet.name = "JewelFacet"
	facet.points = PackedVector2Array(
		[
			Vector2(-10.0, -7.0),
			Vector2(0.0, -2.0),
			Vector2(10.0, -7.0),
			Vector2(0.0, -2.0),
			Vector2(12.0, 6.0),
			Vector2(0.0, 9.0),
			Vector2(-12.0, 6.0),
			Vector2(0.0, -2.0),
		]
	)
	facet.width = 1.0
	facet.default_color = Color(1.0, 0.96, 0.82, 0.58)
	jewel.add_child(facet)

	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(jewel, "position", finish, duration)
	tween.parallel().tween_property(jewel, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(jewel, "rotation", 0.0, duration)
	tween.tween_callback(
		func() -> void:
			if on_arrival.is_valid():
				on_arrival.call()
	)
	tween.tween_property(jewel, "modulate:a", 0.0, 0.10)
	tween.tween_callback(jewel.queue_free)
	return jewel


static func launch_packet(
	host: Node,
	parent: CanvasItem,
	start: Vector2,
	finish: Vector2,
	colour: Color,
	duration: float = 0.22,
	on_arrival: Callable = Callable()
) -> Node2D:
	var packet := Node2D.new()
	packet.name = "OpticalEnergyPacket"
	packet.position = start
	parent.add_child(packet)
	var halo := Polygon2D.new()
	halo.polygon = _circle_points(9.0, 20)
	halo.color = Color(colour.r, colour.g, colour.b, 0.20)
	packet.add_child(halo)
	var core := Polygon2D.new()
	core.polygon = _circle_points(3.5, 16)
	core.color = colour.lightened(0.25)
	packet.add_child(core)
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(packet, "position", finish, duration)
	tween.parallel().tween_property(packet, "scale", Vector2(1.45, 1.45), duration)
	tween.tween_callback(
		func() -> void:
			if on_arrival.is_valid():
				on_arrival.call()
	)
	tween.tween_property(packet, "modulate:a", 0.0, 0.08)
	tween.tween_callback(packet.queue_free)
	return packet


static func pulse_ring(
	host: Node,
	parent: CanvasItem,
	center: Vector2,
	colour: Color,
	radius: float = 18.0,
	final_scale: float = 2.0,
	duration: float = 0.36
) -> Line2D:
	var ring := Line2D.new()
	ring.name = "OpticalImpactRing"
	ring.points = _circle_points(radius, 36)
	ring.closed = true
	ring.position = center
	ring.width = 2.0
	ring.default_color = colour
	ring.scale = Vector2(0.28, 0.28)
	parent.add_child(ring)
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * final_scale, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)
	return ring


static func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.from_angle(angle) * radius)
	return points


# --- Standing room ambience -------------------------------------------------
#
# The room art already paints where the light lives. These helpers add the light
# it should be casting, so a room reads as lit rather than illustrated. Every
# texture is generated at runtime, so ambience never adds art to the pipeline.

static var _glow_texture: GradientTexture2D = null


static func install_lamp(
	parent: CanvasItem,
	lamp_position: Vector2,
	colour: Color,
	radius: float = 96.0,
	flicker: float = 0.18
) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.name = "RoomLampGlow"
	glow.position = lamp_position
	glow.texture = radial_glow_texture()
	glow.modulate = colour
	glow.material = additive_material()
	glow.scale = Vector2.ONE * maxf(0.05, radius / 64.0)
	parent.add_child(glow)
	glow.set_meta("lamp_base_alpha", colour.a)
	glow.set_meta("lamp_base_scale", glow.scale)
	_breathe_lamp(glow, flicker)
	return glow


## Lamps dim and brighten with the building, not with a second copy of the light
## rig, so the power milestone is one state change instead of a rebuild.
static func set_lamp_energy(glow: Sprite2D, energy: float, flicker: float = 0.18) -> void:
	if glow == null or not is_instance_valid(glow):
		return
	var base_alpha: float = float(glow.get_meta("lamp_authored_alpha", glow.get_meta("lamp_base_alpha", 1.0)))
	glow.set_meta("lamp_authored_alpha", base_alpha)
	glow.set_meta("lamp_base_alpha", clampf(base_alpha * energy, 0.0, 1.0))
	glow.modulate.a = clampf(base_alpha * energy, 0.0, 1.0)
	_breathe_lamp(glow, flicker)


static func install_arc_emitter(
	parent: CanvasItem,
	anchor: Vector2,
	span: Vector2,
	colour: Color,
	interval: Vector2 = Vector2(1.1, 3.2)
) -> Node2D:
	var emitter := Node2D.new()
	emitter.name = "RoomArcEmitter"
	emitter.position = anchor
	parent.add_child(emitter)

	var flash := Sprite2D.new()
	flash.name = "ArcFlash"
	flash.texture = radial_glow_texture()
	flash.modulate = Color(colour.r, colour.g, colour.b, 0.0)
	flash.material = additive_material()
	flash.scale = Vector2.ONE * maxf(0.05, span.length() / 64.0)
	emitter.add_child(flash)

	var bolt := Line2D.new()
	bolt.name = "ArcBolt"
	bolt.width = 2.0
	bolt.default_color = colour
	bolt.material = additive_material()
	bolt.visible = false
	emitter.add_child(bolt)

	var timer := Timer.new()
	timer.name = "ArcTimer"
	timer.one_shot = true
	emitter.add_child(timer)
	emitter.set_meta("arc_interval", interval)
	timer.timeout.connect(
		func() -> void:
			if not is_instance_valid(emitter):
				return
			_strike_arc(emitter, bolt, flash, span, colour)
			var current: Vector2 = emitter.get_meta("arc_interval", interval)
			timer.start(randf_range(current.x, current.y))
	)
	timer.start(randf_range(0.15, interval.y))
	return emitter


static func set_arc_interval(emitter: Node2D, interval: Vector2) -> void:
	if emitter != null and is_instance_valid(emitter):
		emitter.set_meta("arc_interval", interval)


static func radial_glow_texture() -> GradientTexture2D:
	if _glow_texture != null:
		return _glow_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.62, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.52),
			Color(1.0, 1.0, 1.0, 0.16),
			Color(1.0, 1.0, 1.0, 0.0),
		]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_glow_texture = texture
	return texture


static func additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


static func _breathe_lamp(glow: Sprite2D, flicker: float) -> void:
	if glow.has_meta("lamp_breath"):
		var previous: Variant = glow.get_meta("lamp_breath")
		if previous is Tween and (previous as Tween).is_valid():
			(previous as Tween).kill()
	var base_alpha: float = float(glow.get_meta("lamp_base_alpha", glow.modulate.a))
	var base_scale: Vector2 = glow.get_meta("lamp_base_scale", glow.scale)
	if base_alpha <= 0.001:
		glow.modulate.a = 0.0
		return
	var period := randf_range(1.5, 2.6)
	var low_alpha := clampf(base_alpha * (1.0 - flicker), 0.0, 1.0)
	var breath := glow.create_tween().set_loops()
	breath.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	breath.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(glow, "modulate:a", low_alpha, period * 0.5)
	breath.parallel().tween_property(glow, "scale", base_scale * (1.0 - flicker * 0.16), period * 0.5)
	breath.tween_property(glow, "modulate:a", base_alpha, period * 0.5)
	breath.parallel().tween_property(glow, "scale", base_scale, period * 0.5)
	glow.set_meta("lamp_breath", breath)


static func _strike_arc(
	host: Node,
	bolt: Line2D,
	flash: Sprite2D,
	span: Vector2,
	colour: Color
) -> void:
	if not is_instance_valid(bolt) or not is_instance_valid(flash):
		return
	var segments := 7
	var start := -span * 0.5
	var finish := span * 0.5
	var jitter := span.length() * 0.11
	var points := PackedVector2Array()
	for index: int in range(segments + 1):
		var travel := float(index) / float(segments)
		var point := start.lerp(finish, travel)
		if index > 0 and index < segments:
			point += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter
		points.append(point)
	bolt.points = points
	bolt.visible = true
	bolt.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flash.modulate = Color(colour.r, colour.g, colour.b, 0.50)
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bolt, "modulate:a", 0.0, 0.13)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(
		func() -> void:
			if is_instance_valid(bolt):
				bolt.visible = false
	)
