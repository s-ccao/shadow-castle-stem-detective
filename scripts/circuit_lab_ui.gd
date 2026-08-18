class_name CircuitLabUI
extends CanvasLayer

## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Structural family: physical workbench · instrument panel.
##
## The Ashford junction bench. Each of the three plates in the Circuit Room is a
## separate apparatus with its own law, and each law is taught by operating it
## rather than by being told. This Module owns the shell every apparatus shares
## — frame, stage pips, hint, per-stage reset, clear burst and reward — so an
## apparatus only has to describe its own stages and draw its own hardware.
##
## Bench 1 · CONTINUITY. A series loop conducts only if every link conducts, and
## a conductor placed across the load carries the current past it, so the lamp
## goes dark while the circuit is still "complete". That second half is the
## blackout this case is investigating, learned by causing it.

signal completed(challenge_id: String)
signal closed


## Every part is drawn as the object it is, not as a labelled rectangle. A blade
## switch is visibly hinged open, a blown fuse has a broken filament behind
## sooted glass, and a ceramic plug has no conductor through it at all — so the
## board can be read before any label is.
class PartView:
	extends Control

	var part_id := ""
	var is_socket := true
	var conducts := false
	var energised := false

	const PLATE_TOP := Color(0.140, 0.152, 0.176, 1.0)
	const PLATE_BOTTOM := Color(0.070, 0.078, 0.094, 1.0)
	const BRASS := Color(0.78, 0.58, 0.26, 1.0)
	const BRASS_LIGHT := Color(0.96, 0.80, 0.44, 1.0)
	const COPPER := Color(0.80, 0.47, 0.22, 1.0)
	const COPPER_LIGHT := Color(0.98, 0.71, 0.42, 1.0)
	const LIVE := Color(0.58, 0.92, 1.0, 1.0)

	func configure(next_part_id: String, next_is_socket: bool, next_conducts: bool, live: bool) -> void:
		part_id = next_part_id
		is_socket = next_is_socket
		conducts = next_conducts
		energised = live
		queue_redraw()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		var mid := size.y * 0.5
		# Mounting plate, lit from above so the board reads as a physical panel.
		draw_rect(box, PLATE_BOTTOM, true)
		draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.5), PLATE_TOP, true)
		draw_rect(box, Color(0.30, 0.34, 0.40, 0.85), false, 1.0)
		for corner: Vector2 in [Vector2(6.0, 6.0), Vector2(size.x - 6.0, 6.0), Vector2(6.0, size.y - 6.0), Vector2(size.x - 6.0, size.y - 6.0)]:
			draw_circle(corner, 2.6, Color(0.42, 0.36, 0.28, 1.0))
			draw_circle(corner - Vector2(0.6, 0.6), 1.6, Color(0.62, 0.55, 0.42, 1.0))

		# Terminal studs: where the rail actually lands on this part.
		var stud := LIVE if energised else BRASS
		draw_circle(Vector2(9.0, mid), 4.0, stud)
		draw_circle(Vector2(size.x - 9.0, mid), 4.0, stud)

		if part_id.is_empty():
			_draw_empty_socket(mid)
			return
		match part_id:
			"wire":
				_draw_wire(mid)
			"resistor":
				_draw_resistor(mid)
			"switch_closed":
				_draw_blade(mid, true)
			"switch_open":
				_draw_blade(mid, false)
			"fuse_ok":
				_draw_fuse(mid, true)
			"fuse_blown":
				_draw_fuse(mid, false)
			"insulator":
				_draw_ceramic(mid)

	func _draw_empty_socket(mid: float) -> void:
		var recess := Rect2(20.0, mid - 13.0, size.x - 40.0, 26.0)
		draw_rect(recess, Color(0.020, 0.024, 0.030, 1.0), true)
		draw_rect(recess, Color(0.34, 0.30, 0.24, 0.9), false, 1.0)
		# Exposed contact clips, so an empty socket reads as waiting for a part.
		for side: float in [recess.position.x + 5.0, recess.end.x - 5.0]:
			draw_line(Vector2(side, mid - 8.0), Vector2(side, mid + 8.0), BRASS, 2.0)
		draw_line(Vector2(9.0, mid), Vector2(recess.position.x, mid), Color(0.42, 0.34, 0.24, 1.0), 3.0)
		draw_line(Vector2(recess.end.x, mid), Vector2(size.x - 9.0, mid), Color(0.42, 0.34, 0.24, 1.0), 3.0)

	func _draw_wire(mid: float) -> void:
		var bar := Rect2(14.0, mid - 6.0, size.x - 28.0, 12.0)
		draw_rect(bar, COPPER, true)
		draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x, 4.0), COPPER_LIGHT, true)
		draw_rect(Rect2(bar.position.x, bar.end.y - 3.0, bar.size.x, 3.0), Color(0.44, 0.24, 0.10, 1.0), true)
		if energised:
			draw_rect(Rect2(bar.position.x, mid - 1.5, bar.size.x, 3.0), LIVE, true)
		draw_line(Vector2(9.0, mid), Vector2(bar.position.x, mid), COPPER, 3.0)
		draw_line(Vector2(bar.end.x, mid), Vector2(size.x - 9.0, mid), COPPER, 3.0)

	func _draw_resistor(mid: float) -> void:
		var body := Rect2(22.0, mid - 11.0, size.x - 44.0, 22.0)
		draw_line(Vector2(9.0, mid), Vector2(body.position.x, mid), COPPER, 3.0)
		draw_line(Vector2(body.end.x, mid), Vector2(size.x - 9.0, mid), COPPER, 3.0)
		draw_rect(body, Color(0.72, 0.62, 0.42, 1.0), true)
		draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 6.0), Color(0.84, 0.75, 0.54, 1.0), true)
		draw_rect(body, Color(0.34, 0.27, 0.16, 1.0), false, 1.0)
		# Four tolerance bands: the part that makes a resistor unmistakable.
		var bands: Array[Color] = [
			Color(0.34, 0.20, 0.10, 1.0),
			Color(0.08, 0.08, 0.08, 1.0),
			Color(0.72, 0.16, 0.12, 1.0),
			Color(0.85, 0.68, 0.24, 1.0),
		]
		for band_index: int in range(bands.size()):
			var band_x := body.position.x + 7.0 + float(band_index) * 10.0
			draw_rect(Rect2(band_x, body.position.y + 1.0, 4.0, body.size.y - 2.0), bands[band_index], true)

	func _draw_blade(mid: float, shut: bool) -> void:
		var hinge := Vector2(24.0, mid + 4.0)
		var post := Vector2(size.x - 24.0, mid + 4.0)
		draw_line(Vector2(9.0, mid), hinge, COPPER, 3.0)
		draw_line(post, Vector2(size.x - 9.0, mid), COPPER, 3.0)
		# Two brass posts and a hinged blade. Open lifts the blade off the post,
		# leaving an air gap that is visible at a glance.
		for base: Vector2 in [hinge, post]:
			draw_rect(Rect2(base.x - 5.0, base.y - 4.0, 10.0, 9.0), BRASS, true)
			draw_rect(Rect2(base.x - 5.0, base.y - 4.0, 10.0, 3.0), BRASS_LIGHT, true)
		var blade_end := post + Vector2(0.0, -3.0) if shut else post + Vector2(-13.0, -21.0)
		draw_line(hinge + Vector2(0.0, -3.0), blade_end, BRASS_LIGHT, 5.0)
		draw_circle(hinge + Vector2(0.0, -3.0), 3.2, Color(0.90, 0.74, 0.40, 1.0))
		if shut:
			draw_circle(post + Vector2(0.0, -3.0), 3.0, LIVE if energised else BRASS_LIGHT)
		else:
			# The gap itself, drawn as a dashed span so it reads as intentional.
			var gap_a := blade_end
			var gap_b := post + Vector2(0.0, -3.0)
			for step: int in range(4):
				var t0 := float(step) / 4.0
				var t1 := t0 + 0.12
				draw_line(gap_a.lerp(gap_b, t0), gap_a.lerp(gap_b, t1), Color(0.92, 0.44, 0.36, 0.95), 1.6)

	func _draw_fuse(mid: float, sound: bool) -> void:
		var glass := Rect2(24.0, mid - 10.0, size.x - 48.0, 20.0)
		draw_line(Vector2(9.0, mid), Vector2(glass.position.x, mid), COPPER, 3.0)
		draw_line(Vector2(glass.end.x, mid), Vector2(size.x - 9.0, mid), COPPER, 3.0)
		# Metal end caps, then translucent glass between them.
		for cap_x: float in [glass.position.x - 7.0, glass.end.x - 1.0]:
			draw_rect(Rect2(cap_x, mid - 11.0, 8.0, 22.0), Color(0.68, 0.70, 0.74, 1.0), true)
			draw_rect(Rect2(cap_x, mid - 11.0, 8.0, 6.0), Color(0.86, 0.88, 0.92, 1.0), true)
		draw_rect(glass, Color(0.62, 0.76, 0.86, 0.30), true)
		draw_rect(glass, Color(0.78, 0.88, 0.96, 0.55), false, 1.0)
		draw_rect(Rect2(glass.position.x, glass.position.y + 2.0, glass.size.x, 3.0), Color(1.0, 1.0, 1.0, 0.22), true)
		if sound:
			draw_line(
				Vector2(glass.position.x + 2.0, mid),
				Vector2(glass.end.x - 2.0, mid),
				LIVE if energised else Color(0.88, 0.82, 0.58, 1.0),
				2.0
			)
			return
		# Blown: the filament has parted and the glass is sooted where it burned.
		var centre_x := glass.get_center().x
		draw_line(Vector2(glass.position.x + 2.0, mid), Vector2(centre_x - 9.0, mid), Color(0.62, 0.56, 0.40, 1.0), 2.0)
		draw_line(Vector2(centre_x - 9.0, mid), Vector2(centre_x - 6.0, mid - 4.0), Color(0.62, 0.56, 0.40, 1.0), 2.0)
		draw_line(Vector2(centre_x + 9.0, mid), Vector2(glass.end.x - 2.0, mid), Color(0.62, 0.56, 0.40, 1.0), 2.0)
		draw_line(Vector2(centre_x + 9.0, mid), Vector2(centre_x + 6.0, mid + 4.0), Color(0.62, 0.56, 0.40, 1.0), 2.0)
		draw_circle(Vector2(centre_x, mid), 7.0, Color(0.10, 0.09, 0.10, 0.72))
		draw_circle(Vector2(centre_x, mid), 3.4, Color(0.04, 0.04, 0.05, 0.9))

	func _draw_ceramic(mid: float) -> void:
		var body := Rect2(20.0, mid - 13.0, size.x - 40.0, 26.0)
		draw_rect(body, Color(0.80, 0.79, 0.76, 1.0), true)
		draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 7.0), Color(0.91, 0.90, 0.88, 1.0), true)
		draw_rect(body, Color(0.52, 0.50, 0.47, 1.0), false, 1.0)
		for rib: int in range(3):
			var rib_y := body.position.y + 7.0 + float(rib) * 6.0
			draw_line(Vector2(body.position.x + 3.0, rib_y), Vector2(body.end.x - 3.0, rib_y), Color(0.62, 0.61, 0.58, 1.0), 1.4)
		# The leads stop at the block: nothing crosses it.
		draw_line(Vector2(9.0, mid), Vector2(body.position.x, mid), Color(0.42, 0.34, 0.24, 1.0), 3.0)
		draw_line(Vector2(body.end.x, mid), Vector2(size.x - 9.0, mid), Color(0.42, 0.34, 0.24, 1.0), 3.0)


## The source is a cell stack with real plates and polarity, so "this is where
## the energy comes from" never needs a caption.
class SourceView:
	extends Control

	var energised := false

	func set_energised(live: bool) -> void:
		energised = live
		queue_redraw()

	func _draw() -> void:
		var mid := size.y * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.062, 0.048, 1.0), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.46, 0.22, 0.9), false, 1.0)
		var base_x := size.x * 0.5 - 15.0
		for cell: int in range(2):
			var plate_x := base_x + float(cell) * 16.0
			draw_line(Vector2(plate_x, mid - 16.0), Vector2(plate_x, mid + 16.0), Color(0.92, 0.80, 0.48, 1.0), 3.0)
			draw_line(Vector2(plate_x + 8.0, mid - 8.0), Vector2(plate_x + 8.0, mid + 8.0), Color(0.72, 0.62, 0.40, 1.0), 5.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(base_x - 9.0, mid - 20.0),
			"+",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.98, 0.84, 0.50, 1.0)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(base_x + 26.0, mid + 30.0),
			"\u2212",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.80, 0.80, 0.84, 1.0)
		)
		var post := Color(0.58, 0.92, 1.0, 1.0) if energised else Color(0.74, 0.56, 0.28, 1.0)
		draw_circle(Vector2(size.x - 8.0, mid), 4.5, post)


## A bulb with an envelope, a screw base and a filament. Dark it is grey glass;
## live the filament whites out and the envelope carries the light.
class LampView:
	extends Control

	enum State { DARK, DIM, LIT, BURNT }

	var lit := false
	var state: State = State.DARK

	func set_lit(next_lit: bool) -> void:
		lit = next_lit
		state = State.LIT if next_lit else State.DARK
		queue_redraw()

	func set_state(next_state: State) -> void:
		state = next_state
		lit = next_state == State.LIT
		queue_redraw()

	func _draw() -> void:
		var centre := Vector2(size.x * 0.5, size.y * 0.44)
		var radius := size.x * 0.32
		var burnt := state == State.BURNT
		var glow := 0.0
		if state == State.LIT:
			glow = 1.0
		elif state == State.DIM:
			glow = 0.34
		if glow > 0.0:
			draw_circle(centre, radius * 2.1, Color(1.0, 0.86, 0.50, 0.10 * glow))
			draw_circle(centre, radius * 1.5, Color(1.0, 0.88, 0.56, 0.18 * glow))
		var envelope := Color(0.20, 0.21, 0.23, 1.0)
		if burnt:
			envelope = Color(0.13, 0.11, 0.11, 1.0)
		elif glow > 0.0:
			envelope = Color(1.0, 0.90, 0.60, 0.92).lerp(Color(0.24, 0.24, 0.24, 1.0), 1.0 - glow)
		draw_circle(centre, radius, envelope)
		draw_arc(
			centre,
			radius,
			0.0,
			TAU,
			40,
			Color(1.0, 0.96, 0.80, 1.0) if glow > 0.5 else Color(0.44, 0.44, 0.48, 1.0),
			2.0
		)
		if burnt:
			# Soot on the inside of the glass, heaviest where the filament failed.
			draw_circle(centre + Vector2(0.0, -radius * 0.15), radius * 0.72, Color(0.05, 0.04, 0.04, 0.80))
			draw_circle(centre + Vector2(radius * 0.18, -radius * 0.30), radius * 0.34, Color(0.02, 0.02, 0.02, 0.85))
		draw_arc(
			centre + Vector2(-radius * 0.28, -radius * 0.30),
			radius * 0.42,
			PI * 0.7,
			PI * 1.5,
			14,
			Color(1.0, 1.0, 1.0, 0.55 if glow > 0.5 else 0.18),
			2.0
		)
		var filament_colour := Color(0.40, 0.38, 0.34, 1.0)
		if state == State.LIT:
			filament_colour = Color(1.0, 1.0, 0.90, 1.0)
		elif state == State.DIM:
			filament_colour = Color(0.86, 0.62, 0.30, 1.0)
		var filament: PackedVector2Array = PackedVector2Array()
		for step: int in range(9):
			var t := float(step) / 8.0
			filament.append(
				centre + Vector2(
					lerpf(-radius * 0.42, radius * 0.42, t),
					(radius * 0.24) * (1.0 if step % 2 == 0 else -1.0)
				)
			)
		for index: int in range(filament.size() - 1):
			# A burnt filament has parted in the middle; the ends stay but curl away.
			if burnt and index >= 3 and index <= 4:
				continue
			draw_line(filament[index], filament[index + 1], filament_colour, 2.0)
		var base_rect := Rect2(centre.x - radius * 0.46, centre.y + radius * 0.86, radius * 0.92, radius * 0.62)
		draw_rect(base_rect, Color(0.66, 0.62, 0.56, 1.0), true)
		for thread: int in range(3):
			var thread_y := base_rect.position.y + 3.0 + float(thread) * 5.0
			draw_line(Vector2(base_rect.position.x, thread_y), Vector2(base_rect.end.x, thread_y), Color(0.46, 0.43, 0.38, 1.0), 1.4)


## A wire-wound rheostat. The wiper is dragged along the coil, so resistance is
## a position the hand holds rather than a value the player picks off a shelf.
class RheostatView:
	extends Control

	signal ratio_changed(ratio: float)

	var ratio := 0.0
	var r_max := 400.0
	var energised := false
	var _dragging := false

	func configure(next_r_max: float, next_ratio: float) -> void:
		r_max = maxf(1.0, next_r_max)
		ratio = clampf(next_ratio, 0.0, 1.0)
		queue_redraw()

	func set_energised(live: bool) -> void:
		energised = live
		queue_redraw()

	func _track_rect() -> Rect2:
		return Rect2(28.0, size.y * 0.42, size.x - 56.0, 16.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button_event := event as InputEventMouseButton
			if button_event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = button_event.pressed
				if button_event.pressed:
					_apply_from_x(button_event.position.x)
		elif event is InputEventMouseMotion and _dragging:
			_apply_from_x((event as InputEventMouseMotion).position.x)

	func _apply_from_x(x: float) -> void:
		var track := _track_rect()
		var next := clampf((x - track.position.x) / maxf(1.0, track.size.x), 0.0, 1.0)
		if absf(next - ratio) < 0.0005:
			return
		ratio = next
		queue_redraw()
		ratio_changed.emit(ratio)

	func _draw() -> void:
		var track := _track_rect()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.085, 0.078, 0.066, 1.0), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.46, 0.22, 0.90), false, 2.0)

		# Ceramic former with the resistance wire wound along it.
		draw_rect(track, Color(0.74, 0.71, 0.66, 1.0), true)
		draw_rect(Rect2(track.position.x, track.position.y, track.size.x, 5.0), Color(0.86, 0.84, 0.80, 1.0), true)
		var turns := int(track.size.x / 7.0)
		for turn: int in range(turns):
			var turn_x := track.position.x + 4.0 + float(turn) * 7.0
			# Winding left of the wiper is in circuit and carries current.
			var in_circuit := (turn_x - track.position.x) / track.size.x <= ratio
			draw_line(
				Vector2(turn_x, track.position.y - 3.0),
				Vector2(turn_x, track.end.y + 3.0),
				(
					Color(0.58, 0.92, 1.0, 1.0) if in_circuit and energised
					else (Color(0.82, 0.52, 0.24, 1.0) if in_circuit else Color(0.46, 0.42, 0.38, 1.0))
				),
				2.0
			)

		var wiper_x := track.position.x + track.size.x * ratio
		draw_line(Vector2(wiper_x, track.position.y - 26.0), Vector2(wiper_x, track.end.y + 4.0), Color(0.86, 0.74, 0.44, 1.0), 4.0)
		# The knob the hand is on.
		draw_rect(Rect2(wiper_x - 13.0, track.position.y - 42.0, 26.0, 20.0), Color(0.30, 0.26, 0.20, 1.0), true)
		draw_rect(Rect2(wiper_x - 13.0, track.position.y - 42.0, 26.0, 7.0), Color(0.62, 0.54, 0.40, 1.0), true)
		draw_rect(Rect2(wiper_x - 13.0, track.position.y - 42.0, 26.0, 20.0), Color(0.90, 0.76, 0.44, 1.0), false, 1.6)
		for grip: int in range(3):
			var grip_x := wiper_x - 6.0 + float(grip) * 6.0
			draw_line(Vector2(grip_x, track.position.y - 39.0), Vector2(grip_x, track.position.y - 26.0), Color(0.82, 0.70, 0.44, 0.85), 1.4)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(track.position.x, track.end.y + 26.0),
			"0 \u03a9",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.72, 0.66, 0.54, 1.0)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(track.end.x - 52.0, track.end.y + 26.0),
			"%.0f \u03a9" % r_max,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.72, 0.66, 0.54, 1.0)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(wiper_x - 30.0, track.position.y - 50.0),
			"%.0f \u03a9" % (r_max * ratio),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color(0.98, 0.84, 0.48, 1.0)
		)


## A panel meter with a real scale. The safe band is printed on the dial, so the
## target is a place on an instrument rather than a number in a sentence.
class MeterView:
	extends Control

	var full_scale := 24.0
	var safe_low := 10.0
	var safe_high := 14.0
	var reading := 0.0
	var _needle := 0.0

	func configure(next_full_scale: float, next_low: float, next_high: float) -> void:
		full_scale = maxf(1.0, next_full_scale)
		safe_low = next_low
		safe_high = next_high
		queue_redraw()

	func set_reading(next_reading: float) -> void:
		reading = next_reading
		queue_redraw()

	func _process(delta: float) -> void:
		# The needle has mass: it swings toward the reading instead of snapping,
		# which is what makes an over-voltage feel like it ran away.
		var target := clampf(reading, 0.0, full_scale)
		if absf(_needle - target) < 0.01:
			_needle = target
			return
		_needle = lerpf(_needle, target, clampf(delta * 7.0, 0.0, 1.0))
		queue_redraw()

	func _angle_for(value: float) -> float:
		var ratio := clampf(value / full_scale, 0.0, 1.0)
		return lerpf(PI * 0.82, PI * 0.18, ratio)

	func _draw() -> void:
		var pivot := Vector2(size.x * 0.5, size.y * 0.86)
		var radius := minf(size.x * 0.44, size.y * 0.74)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.080, 0.092, 1.0), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.46, 0.22, 0.92), false, 2.0)
		draw_rect(Rect2(4.0, 4.0, size.x - 8.0, size.y * 0.5), Color(0.94, 0.91, 0.83, 0.06), true)

		# Safe band, drawn on the dial face.
		var band_steps := 22
		for step: int in range(band_steps):
			var t0 := float(step) / float(band_steps)
			var t1 := float(step + 1) / float(band_steps)
			var v0 := lerpf(safe_low, safe_high, t0)
			var v1 := lerpf(safe_low, safe_high, t1)
			draw_line(
				pivot + Vector2.from_angle(-_angle_for(v0)) * (radius * 0.80),
				pivot + Vector2.from_angle(-_angle_for(v1)) * (radius * 0.80),
				Color(0.40, 0.86, 0.46, 0.95),
				7.0
			)
		# Danger zone above the safe band.
		for step: int in range(band_steps):
			var t0 := float(step) / float(band_steps)
			var t1 := float(step + 1) / float(band_steps)
			var v0 := lerpf(safe_high, full_scale, t0)
			var v1 := lerpf(safe_high, full_scale, t1)
			draw_line(
				pivot + Vector2.from_angle(-_angle_for(v0)) * (radius * 0.80),
				pivot + Vector2.from_angle(-_angle_for(v1)) * (radius * 0.80),
				Color(0.90, 0.28, 0.22, 0.90),
				7.0
			)

		draw_arc(pivot, radius * 0.92, -PI * 0.82, -PI * 0.18, 48, Color(0.86, 0.80, 0.66, 0.92), 2.0)
		for tick: int in range(11):
			var value := full_scale * float(tick) / 10.0
			var direction := Vector2.from_angle(-_angle_for(value))
			var major := tick % 5 == 0
			draw_line(
				pivot + direction * (radius * (0.86 if major else 0.90)),
				pivot + direction * (radius * 0.99),
				Color(0.92, 0.88, 0.76, 1.0),
				2.4 if major else 1.2
			)

		var needle_direction := Vector2.from_angle(-_angle_for(_needle))
		draw_line(pivot, pivot + needle_direction * (radius * 0.86), Color(0.98, 0.36, 0.28, 1.0), 3.0)
		draw_line(pivot, pivot - needle_direction * (radius * 0.12), Color(0.70, 0.26, 0.20, 1.0), 4.0)
		draw_circle(pivot, 6.0, Color(0.86, 0.74, 0.44, 1.0))
		draw_circle(pivot, 2.6, Color(0.30, 0.24, 0.16, 1.0))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(8.0, size.y - 6.0),
			"%.1f V" % _needle,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color(0.98, 0.84, 0.48, 1.0)
		)


## Charge in motion. A still cyan wire is a colour; moving carriers are current,
## and that difference is the whole point of pressing ENERGISE.
class CurrentFlow:
	extends Node2D

	var path: PackedVector2Array = PackedVector2Array()
	var tint := Color(0.58, 0.92, 1.0, 1.0)
	var speed := 132.0
	var _phase := 0.0

	func _process(delta: float) -> void:
		_phase = fposmod(_phase + delta * speed, 46.0)
		queue_redraw()

	func _draw() -> void:
		if path.size() < 2:
			return
		var total := 0.0
		for index: int in range(path.size() - 1):
			total += path[index].distance_to(path[index + 1])
		var travelled := _phase
		while travelled < total:
			draw_circle(_point_at(travelled), 3.4, tint)
			draw_circle(_point_at(travelled), 6.4, Color(tint.r, tint.g, tint.b, 0.22))
			travelled += 46.0

	func _point_at(distance: float) -> Vector2:
		var walked := 0.0
		for index: int in range(path.size() - 1):
			var segment := path[index].distance_to(path[index + 1])
			if walked + segment >= distance:
				var ratio := 0.0 if segment <= 0.0 else (distance - walked) / segment
				return path[index].lerp(path[index + 1], ratio)
			walked += segment
		return path[path.size() - 1]


const FRAME_SIZE := Vector2(900.0, 640.0)
const RAIL_SIZE := Vector2(824.0, 246.0)
const DECK_SIZE := Vector2(824.0, 128.0)

const COLOR_GOLD := Color(0.97, 0.80, 0.42, 1.0)
const COLOR_PARCHMENT := Color(0.91, 0.85, 0.71, 1.0)
const COLOR_MUTED := Color(0.70, 0.64, 0.53, 1.0)
const COLOR_SUCCESS := Color(0.60, 0.92, 0.56, 1.0)
const COLOR_WARN := Color(0.95, 0.72, 0.40, 1.0)
const COLOR_LIVE := Color(0.58, 0.92, 1.0, 1.0)
const COLOR_DEAD := Color(0.34, 0.30, 0.28, 1.0)

## Every part the bench can hold. `conducts` is the only physical property the
## puzzle needs; everything else is how the part explains itself.
const PARTS: Dictionary = {
	"wire": {
		"en": "COPPER LINK", "zh": "铜导线",
		"conducts": true, "tint": Color(0.86, 0.60, 0.28, 1.0),
		"note_en": "Plain conductor. Carries current, drops almost no voltage.",
		"note_zh": "普通导体。导通电流，几乎不产生压降。",
	},
	"resistor": {
		"en": "RESISTOR", "zh": "电阻",
		"conducts": true, "tint": Color(0.72, 0.68, 0.42, 1.0),
		"note_en": "Still a conductor. It limits current, it does not stop it.",
		"note_zh": "仍然是导体。它限制电流，但不会切断电流。",
	},
	"switch_closed": {
		"en": "CLOSED SWITCH", "zh": "闭合开关",
		"conducts": true, "tint": Color(0.60, 0.84, 0.52, 1.0),
		"note_en": "A gap held shut. Current passes.",
		"note_zh": "被合上的断口。电流通过。",
	},
	"switch_open": {
		"en": "OPEN SWITCH", "zh": "断开开关",
		"conducts": false, "tint": Color(0.62, 0.44, 0.40, 1.0),
		"note_en": "A deliberate gap. One of these anywhere in series kills the run.",
		"note_zh": "刻意留下的断口。串联回路里任意一处断开，全线失电。",
	},
	"fuse_ok": {
		"en": "SOUND FUSE", "zh": "完好保险丝",
		"conducts": true, "tint": Color(0.82, 0.78, 0.56, 1.0),
		"note_en": "A conductor designed to fail first when current runs too high.",
		"note_zh": "被设计成在电流过大时率先熔断的导体。",
	},
	"fuse_blown": {
		"en": "BLOWN FUSE", "zh": "熔断保险丝",
		"conducts": false, "tint": Color(0.50, 0.34, 0.32, 1.0),
		"note_en": "Already failed. It is now just a gap.",
		"note_zh": "已经熔断。现在它就是一个断口。",
	},
	"insulator": {
		"en": "CERAMIC BLOCK", "zh": "陶瓷块",
		"conducts": false, "tint": Color(0.46, 0.44, 0.46, 1.0),
		"note_en": "Insulator. Fills the socket without conducting.",
		"note_zh": "绝缘体。占住插槽但不导电。",
	},
}

## Bench 1 curriculum. `main` links are the series run through the lamp; `bypass`
## links sit across the lamp, so any conductor there carries current past it.
const CONTINUITY_STAGES: Array = [
	{
		"lesson_en": "A series run conducts only if every link conducts.",
		"lesson_zh": "串联回路只有每一段都导通时才通电。",
		"main": ["socket"],
		"bypass": [],
		"tray": ["wire", "switch_open"],
	},
	{
		"lesson_en": "A resistor limits current. It is still a conductor.",
		"lesson_zh": "电阻限制电流，但它仍然是导体。",
		"main": ["socket", "socket"],
		"bypass": [],
		"tray": ["resistor", "switch_open", "wire"],
	},
	{
		"lesson_en": "A blown fuse is not a component any more. It is a gap.",
		"lesson_zh": "熔断的保险丝不再是元件，它就是一个断口。",
		"main": ["socket:fuse_blown", "socket", "socket"],
		"bypass": [],
		"tray": ["fuse_ok", "wire", "fuse_blown"],
	},
	{
		"lesson_en": "A conductor across the lamp carries the current past it.",
		"lesson_zh": "跨接在灯两端的导体会把电流从灯旁边引走。",
		"main": ["socket", "socket"],
		"bypass": ["socket"],
		"tray": ["wire", "insulator", "resistor"],
	},
	{
		"lesson_en": "Every bypass must stay open, not just the obvious one.",
		"lesson_zh": "每一条旁路都必须保持断开，不只是显眼的那一条。",
		"main": ["socket", "switch_closed", "socket"],
		"bypass": ["socket", "socket"],
		"tray": ["wire", "insulator", "switch_open", "resistor"],
	},
	{
		"lesson_en": "Ashford's blackout was one sound part put in the wrong place.",
		"lesson_zh": "阿什福德的停电，是一个完好的元件被装在了错误的位置。",
		"main": ["socket", "socket:fuse_blown", "socket", "socket"],
		"bypass": ["socket", "socket"],
		"tray": ["wire", "fuse_ok", "insulator", "switch_open", "resistor"],
	},
]

## Bench 2 curriculum. Bench I is construction — choose a part, fit it, test.
## This bench is deliberately a different verb: the resistance is continuous and
## the circuit is always live, so the player drags a rheostat wiper and watches
## the needle answer in real time. The divider stops being three sampled answers
## and becomes a curve you feel. Later stages heat the filament so the load
## drifts, which turns the task from "set it" into "track it and hold it".
const REGULATOR_STAGES: Array = [
	{
		"lesson_en": "Slide the wiper. More resistance in series, less voltage at the lamp.",
		"lesson_zh": "拖动滑片。串联电阻越多，灯上的电压越少。",
		"source_v": 24.0, "lamp_r": 100.0, "r_max": 400.0,
		"safe": [10.0, 14.0], "hold": 1.2, "drift": 0.0, "drift_span": 0.0,
	},
	{
		"lesson_en": "The band is narrower. Small moves near the target, not large ones.",
		"lesson_zh": "安全区更窄了。接近目标时用小幅度微调，不要大动。",
		"source_v": 36.0, "lamp_r": 120.0, "r_max": 600.0,
		"safe": [11.0, 13.0], "hold": 1.6, "drift": 0.0, "drift_span": 0.0,
	},
	{
		"lesson_en": "Below the band the filament only dulls. Above it, it fails.",
		"lesson_zh": "低于安全区只是变暗；高于安全区会烧断灯丝。",
		"source_v": 18.0, "lamp_r": 80.0, "r_max": 300.0,
		"safe": [7.0, 9.0], "hold": 1.8, "drift": 0.0, "drift_span": 0.0,
	},
	{
		"lesson_en": "A hot filament changes its own resistance. Track the drift.",
		"lesson_zh": "灯丝发热会改变自身电阻。跟着漂移持续修正。",
		"source_v": 48.0, "lamp_r": 150.0, "r_max": 700.0,
		"safe": [12.0, 15.0], "hold": 2.2, "drift": 26.0, "drift_span": 46.0,
	},
	{
		"lesson_en": "Faster drift, tighter band. Anticipate instead of reacting.",
		"lesson_zh": "漂移更快，区间更窄。要提前预判，而不是事后追。",
		"source_v": 60.0, "lamp_r": 200.0, "r_max": 900.0,
		"safe": [14.0, 16.5], "hold": 2.6, "drift": 42.0, "drift_span": 68.0,
	},
	{
		"lesson_en": "Ashford's regulator was trimmed once and never tracked again.",
		"lesson_zh": "阿什福德的调压闸只整定过一次，之后再没有人跟过它。",
		"source_v": 30.0, "lamp_r": 60.0, "r_max": 420.0,
		"safe": [5.0, 6.6], "hold": 3.0, "drift": 34.0, "drift_span": 30.0,
	},
]

## Bench 3 curriculum. The third verb is neither building nor tracking: the bus
## is already dead and cannot be rebuilt. The player carries a probe, reads test
## points, and names the faulty segment from the evidence. That is the same skill
## the whole case runs on, applied to hardware.
##
## Two fault kinds, because they are read completely differently:
##   * an OPEN drops the entire supply across itself, so every point before it
##     reads full supply and every point after reads zero;
##   * a HIGH-RESISTANCE fault still conducts, so nothing reads zero and the
##     culprit is the segment with the abnormal drop.
const DIAGNOSTIC_STAGES: Array = [
	{
		"lesson_en": "An open drops the whole supply across itself. Full before it, zero after.",
		"lesson_zh": "断路会把整个电源电压压在自己身上：之前读满压，之后读零。",
		"segments": 4, "fault": "open", "fault_index": 2, "source_v": 24.0,
	},
	{
		"lesson_en": "The fault lies between the last full reading and the first zero.",
		"lesson_zh": "故障就在「最后一个满压点」和「第一个零点」之间。",
		"segments": 6, "fault": "open", "fault_index": 4, "source_v": 24.0,
	},
	{
		"lesson_en": "Probe the middle first. Each measurement can halve what is left.",
		"lesson_zh": "先测中点。每一次测量都能把剩下的范围砍一半。",
		"segments": 8, "fault": "open", "fault_index": 1, "source_v": 36.0,
	},
	{
		"lesson_en": "A degraded segment still conducts. Nothing reads zero; look for the odd drop.",
		"lesson_zh": "劣化的线段仍然导通。没有零点，要找压降异常的那一段。",
		"segments": 5, "fault": "high_r", "fault_index": 3, "source_v": 30.0,
	},
	{
		"lesson_en": "Compare drops between neighbours, not absolute readings.",
		"lesson_zh": "比较相邻测点之间的压降，而不是绝对读数。",
		"segments": 8, "fault": "high_r", "fault_index": 5, "source_v": 48.0,
	},
	{
		"lesson_en": "The Ashford bus. Nothing here reads zero, and one segment was helped along.",
		"lesson_zh": "阿什福德的母线。这里没有零点，而其中一段是被人帮过忙的。",
		"segments": 10, "fault": "high_r", "fault_index": 6, "source_v": 60.0,
	},
]

const SEGMENT_NORMAL_OHMS := 8.0
const SEGMENT_FAULT_OHMS := 240.0
const LOAD_OHMS := 60.0

const BENCH_CONTINUITY := "continuity"
const BENCH_REGULATOR := "regulator"
const BENCH_DIAGNOSTIC := "diagnostic"
## How long the lamp may sit above the band before the filament gives up. A
## moment of overshoot while hunting for the value is not a punishable mistake.
const OVER_VOLT_GRACE := 0.55
## Which apparatus a plate opens.
const BENCH_FOR_CHALLENGE: Dictionary = {
	"switch_left": BENCH_CONTINUITY,
	"switch_right": BENCH_REGULATOR,
	"master_switch": BENCH_DIAGNOSTIC,
}

var challenge_id := ""
var stage_index := 0
var challenge_completed := false
var _rheostat := 0.0
var _drift_time := 0.0
var _hold_progress := 0.0
var _over_time := 0.0
var meter: MeterView
var lamp_view: LampView
var rheostat_view: RheostatView
var hold_bar: ColorRect
var readout_label: Label
var _readings: Dictionary = {}
var _probe_index := -1
var _probe_count := 0
var _accused := -1
var probe_tip: Control
var segment_buttons: Dictionary = {}
var _sockets: Dictionary = {}
var _selected_part := ""
var _busy := false

var root_control: Control
var frame: Panel
var title_label: Label
var lesson_label: Label
var stage_label: Label
var stage_pips: Array[Panel] = []
var rail: Control
var deck: Control
var status_label: Label
var part_buttons: Dictionary = {}
var test_button: Button
var reset_button: Button
var close_button: Button
var effect_layer: Control


func _ready() -> void:
	name = "CircuitLabUI"
	layer = 58
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	CaseLocale.locale_changed.connect(_refresh_copy)
	visible = false


func open_challenge(next_challenge_id: String) -> void:
	challenge_id = next_challenge_id
	stage_index = 0
	challenge_completed = false
	visible = true
	root_control.visible = true
	_load_stage()


func close() -> void:
	visible = false
	root_control.visible = false
	closed.emit()


func get_stage_count() -> int:
	return _stage_list().size()


## Test hook: an arrangement that satisfies the current stage.
func get_stage_solution() -> Dictionary:
	if _bench_id() == BENCH_REGULATOR:
		return _solve_regulator()
	var stage := _current_stage()
	var solution: Dictionary = {}
	var tray: Array = stage["tray"] as Array
	var conductor := _first_matching(tray, true)
	var blocker := _first_matching(tray, false)
	for socket_id: String in _sockets:
		var socket := _sockets[socket_id] as Dictionary
		if not bool(socket["is_socket"]):
			continue
		solution[socket_id] = conductor if str(socket["kind"]) == "main" else blocker
	return solution


func place_part(socket_id: String, part_id: String) -> void:
	if not _sockets.has(socket_id) or _busy:
		return
	var socket := _sockets[socket_id] as Dictionary
	if not bool(socket["is_socket"]):
		return
	socket["part"] = part_id
	_refresh_rail()
	_set_status(_part_note(part_id), COLOR_PARCHMENT)


func reset_current_stage() -> void:
	if _busy:
		return
	_load_stage()


## Energise the bench. Success needs both halves of the law: an unbroken series
## run, and no conductor bridging the lamp.
func run_test() -> void:
	if _busy or challenge_completed:
		return
	if _bench_id() == BENCH_REGULATOR:
		# This bench is always live and is satisfied by holding the value, so a
		# one-shot test would only interrupt the thing being measured.
		return
	var open_main := _first_failing_socket("main", false)
	var shorted := _first_failing_socket("bypass", true)
	if not open_main.is_empty():
		_busy = true
		_play_dead_run(open_main)
		return
	if not shorted.is_empty():
		_busy = true
		_play_short(shorted)
		return
	_busy = true
	_play_live_run()


func _current_stage() -> Dictionary:
	var stages := _stage_list()
	return stages[clampi(stage_index, 0, stages.size() - 1)] as Dictionary


func _bench_id() -> String:
	return str(BENCH_FOR_CHALLENGE.get(challenge_id, BENCH_CONTINUITY))


func _stage_list() -> Array:
	match _bench_id():
		BENCH_REGULATOR:
			return REGULATOR_STAGES
		BENCH_DIAGNOSTIC:
			return DIAGNOSTIC_STAGES
	return CONTINUITY_STAGES


# --- Bench 2 · continuous regulation ---------------------------------------


func _series_resistance() -> float:
	return float(_current_stage()["r_max"]) * _rheostat


## The lamp heats as it runs, so on drifting stages its resistance is a moving
## quantity rather than a constant printed on the bench.
func _live_lamp_resistance() -> float:
	var stage := _current_stage()
	var span := float(stage["drift_span"])
	if span <= 0.0:
		return float(stage["lamp_r"])
	return float(stage["lamp_r"]) + span * (0.5 - 0.5 * cos(_drift_time * 0.9))


func _lamp_voltage() -> float:
	var lamp_r := _live_lamp_resistance()
	var total := lamp_r + _series_resistance()
	if total <= 0.0:
		return 0.0
	return float(_current_stage()["source_v"]) * lamp_r / total


## "under", "over" or "safe" for the present setting.
func _regulator_outcome() -> String:
	var safe := _current_stage()["safe"] as Array
	var volts := _lamp_voltage()
	if volts > float(safe[1]) + 0.001:
		return "over"
	if volts < float(safe[0]) - 0.001:
		return "under"
	return "safe"


func set_rheostat(ratio: float) -> void:
	if _busy:
		return
	_rheostat = clampf(ratio, 0.0, 1.0)
	if rheostat_view != null:
		rheostat_view.configure(float(_current_stage()["r_max"]), _rheostat)
	_sync_regulator_readout()


## Test hook: the wiper position that sits nearest the middle of the band right
## now. Aiming at the centre rather than the first hit keeps the answer clear of
## the edge, where a drifting load would immediately push it back out.
func _solve_regulator() -> Dictionary:
	var safe := _current_stage()["safe"] as Array
	var centre := (float(safe[0]) + float(safe[1])) * 0.5
	var saved := _rheostat
	var answer: Dictionary = {}
	var best_error := INF
	for step: int in range(1001):
		_rheostat = float(step) / 1000.0
		if _regulator_outcome() != "safe":
			continue
		var error := absf(_lamp_voltage() - centre)
		if error < best_error:
			best_error = error
			answer = {"ratio": _rheostat}
	_rheostat = saved
	return answer


func _process(delta: float) -> void:
	if not visible or _busy or challenge_completed:
		return
	if _bench_id() != BENCH_REGULATOR:
		return
	var stage := _current_stage()
	if float(stage["drift"]) > 0.0:
		_drift_time += delta * (float(stage["drift"]) / 30.0)
	var outcome := _regulator_outcome()
	if outcome == "safe":
		# Holding is the win condition: a value that is only crossed in passing
		# has not been regulated.
		_hold_progress += delta
		if _hold_progress >= float(stage["hold"]):
			_busy = true
			_play_regulated(_lamp_voltage())
			return
	else:
		_hold_progress = 0.0
	if outcome == "over":
		_over_time += delta
		if _over_time >= OVER_VOLT_GRACE:
			_busy = true
			_play_burnout(_lamp_voltage())
			return
	else:
		_over_time = 0.0
	_sync_regulator_readout()


func _sync_regulator_readout() -> void:
	var stage := _current_stage()
	var safe := stage["safe"] as Array
	var volts := _lamp_voltage()
	if meter != null:
		meter.set_reading(volts)
	if rheostat_view != null:
		rheostat_view.set_energised(true)
	if lamp_view != null:
		var outcome := _regulator_outcome()
		lamp_view.set_state(
			LampView.State.LIT if outcome == "safe"
			else (LampView.State.DIM if outcome == "under" else LampView.State.DARK)
		)
	if hold_bar != null:
		var hold_target := maxf(0.01, float(stage["hold"]))
		hold_bar.size.x = (RAIL_SIZE.x - 40.0) * clampf(_hold_progress / hold_target, 0.0, 1.0)
	if readout_label != null:
		readout_label.text = (
			"\u4e32\u8054 %.0f\u03a9\u3000\u00b7\u3000\u706f %.0f\u03a9\u3000\u00b7\u3000\u706f\u7535\u538b %.1fV\u3000\u00b7\u3000\u5b89\u5168\u533a %.1f\u2013%.1fV"
			% [_series_resistance(), _live_lamp_resistance(), volts, float(safe[0]), float(safe[1])]
			if CaseLocale.is_chinese()
			else "SERIES %.0f\u03a9  \u00b7  LAMP %.0f\u03a9  \u00b7  %.1f V  \u00b7  BAND %.1f\u2013%.1f V"
			% [_series_resistance(), _live_lamp_resistance(), volts, float(safe[0]), float(safe[1])]
		)


func _first_matching(tray: Array, conducts: bool) -> String:
	for part_id: String in tray:
		if bool((PARTS[part_id] as Dictionary)["conducts"]) == conducts:
			return part_id
	return ""


## A socket fails when its part's conductivity is not what its position needs.
func _first_failing_socket(kind: String, wants_conductor: bool) -> String:
	for socket_id: String in _sockets:
		var socket := _sockets[socket_id] as Dictionary
		if str(socket["kind"]) != kind:
			continue
		var part_id := str(socket["part"])
		if part_id.is_empty():
			# An empty socket is a gap. That fails a series run and is exactly what
			# a bypass needs, so only the run reports it — and the scan continues,
			# because a later socket may still be the one that shorts the lamp.
			if not wants_conductor:
				return socket_id
			continue
		if bool((PARTS[part_id] as Dictionary)["conducts"]) == wants_conductor:
			return socket_id
	return ""


func _load_stage() -> void:
	_busy = false
	_selected_part = ""
	if _bench_id() == BENCH_REGULATOR:
		_load_regulator_stage()
		return
	if _bench_id() == BENCH_DIAGNOSTIC:
		_load_diagnostic_stage()
		return
	var stage := _current_stage()
	_sockets.clear()
	var index := 0
	for entry: String in stage["main"] as Array:
		_sockets["main_%d" % index] = _describe_link("main", entry)
		index += 1
	index = 0
	for entry: String in stage["bypass"] as Array:
		_sockets["bypass_%d" % index] = _describe_link("bypass", entry)
		index += 1
	_build_deck()
	_refresh_rail()
	_refresh_copy()
	_set_status(_stage_brief(), COLOR_WARN)


## The lesson line states the law; the status line states the next action, so a
## player never has to read the same sentence twice to learn what to do.
func _stage_brief() -> String:
	var sockets := 0
	for socket_id: String in _sockets:
		if bool((_sockets[socket_id] as Dictionary)["is_socket"]):
			sockets += 1
	var has_bypass := false
	for socket_id: String in _sockets:
		if str((_sockets[socket_id] as Dictionary)["kind"]) == "bypass":
			has_bypass = true
			break
	if CaseLocale.is_chinese():
		return (
			"选一个零件，再点插槽装上。让电流通过所有 %d 个插槽点亮灯——同时别让旁路把电流引走。" % sockets
			if has_bypass
			else "选一个零件，再点插槽装上。让电流走通这 %d 个插槽，把灯点亮。" % sockets
		)
	return (
		"Pick a part, then a socket. Light the lamp through all %d sockets — and keep the bypass from stealing the current." % sockets
		if has_bypass
		else "Pick a part, then a socket. Carry current through all %d sockets to light the lamp." % sockets
	)


func _load_regulator_stage() -> void:
	var stage := _current_stage()
	_sockets.clear()
	_rheostat = 0.0
	_drift_time = 0.0
	_hold_progress = 0.0
	_over_time = 0.0
	_build_deck()
	_refresh_rail()
	_refresh_copy()
	_sync_regulator_readout()
	var safe := stage["safe"] as Array
	_set_status(
		(
			"\u62d6\u52a8\u6ed1\u7247\u6539\u53d8\u4e32\u8054\u7535\u963b\uff0c\u628a\u6307\u9488\u538b\u8fdb\u7eff\u533a\uff0c\u5e76\u7a33\u4f4f %.1f \u79d2\u3002"
			% float(stage["hold"])
			if CaseLocale.is_chinese()
			else "Drag the wiper to change the series resistance. Bring the needle into the green band and hold it there for %.1f s."
			% float(stage["hold"])
		),
		COLOR_WARN
	)


func _play_under_volt(volts: float) -> void:
	GameAudio.play(&"bench_fail")
	if lamp_view != null:
		lamp_view.set_state(LampView.State.DIM)
	_set_status(
		(
			"灯上只有 %.1fV，低于安全区间。串联电阻分走了太多电压。" % volts
			if CaseLocale.is_chinese()
			else "Only %.1f V reaches the lamp, below the band. The series resistance took too much of it." % volts
		),
		COLOR_WARN
	)
	await get_tree().create_timer(0.55).timeout
	_busy = false


## Over-volt is destructive on purpose. A warning the player can ignore teaches
## nothing; a filament that visibly fails does.
func _play_burnout(volts: float) -> void:
	GameAudio.play(&"bench_fail")
	if lamp_view != null:
		lamp_view.set_state(LampView.State.BURNT)
	_set_status(
		(
			"灯上 %.1fV，超出上限。灯丝烧断了——电阻太小不会让灯更亮，只会毁掉它。" % volts
			if CaseLocale.is_chinese()
			else "%.1f V across the lamp, past the limit. The filament failed \u2014 too little resistance does not make a lamp brighter, it destroys it." % volts
		),
		COLOR_WARN
	)
	OpticalFxRuntime.pulse_ring(
		self, effect_layer, Vector2(LAMP_X, MAIN_RUN_Y), Color(1.0, 0.86, 0.52, 0.98), 30.0, 3.4, 0.34
	)
	OpticalFxRuntime.pulse_ring(
		self, effect_layer, Vector2(LAMP_X, MAIN_RUN_Y), Color(1.0, 0.40, 0.24, 0.92), 22.0, 4.2, 0.52
	)
	var flash := ColorRect.new()
	flash.name = "BurnoutFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.92, 0.72, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(flash)
	var burn := create_tween()
	burn.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	burn.tween_property(flash, "color:a", 0.55, 0.05)
	burn.tween_property(flash, "color:a", 0.0, 0.34)
	burn.parallel().tween_property(rail, "position:x", 44.0, 0.05)
	burn.tween_property(rail, "position:x", 32.0, 0.05)
	burn.tween_property(rail, "position:x", 38.0, 0.07)
	burn.tween_callback(flash.queue_free)
	await get_tree().create_timer(0.90).timeout
	# The filament is gone, so the stage restarts with a fresh lamp.
	_load_stage()


func _play_regulated(volts: float) -> void:
	GameAudio.play(&"bench_pass")
	if lamp_view != null:
		lamp_view.set_state(LampView.State.LIT)
	_set_status(
		(
			"灯上 %.1fV，落在绿区。灯稳定点亮。" % volts
			if CaseLocale.is_chinese()
			else "%.1f V across the lamp, inside the band. It runs steady." % volts
		),
		COLOR_SUCCESS
	)
	_refresh_rail()
	OpticalFxRuntime.pulse_ring(
		self, effect_layer, Vector2(LAMP_X, MAIN_RUN_Y), COLOR_LIVE, 34.0, 3.0, 0.52
	)
	await get_tree().create_timer(0.72).timeout
	_advance_stage()


# --- Bench 3 · fault isolation ---------------------------------------------
#
# Segment i joins test point i to test point i + 1. Test point 0 is the supply
# terminal; the last test point is the load. Voltages are measured against the
# return, which is what a probe on a live bus actually reads.


func _segment_ohms(index: int) -> float:
	var stage := _current_stage()
	if index != int(stage["fault_index"]):
		return SEGMENT_NORMAL_OHMS
	return INF if str(stage["fault"]) == "open" else SEGMENT_FAULT_OHMS


## Voltage at a test point, derived from the series chain rather than authored.
func _voltage_at(point: int) -> float:
	var stage := _current_stage()
	var segments := int(stage["segments"])
	var source_v := float(stage["source_v"])
	var fault_index := int(stage["fault_index"])
	if str(stage["fault"]) == "open":
		# No current flows at all, so there is no drop anywhere except across the
		# break itself: everything upstream sits at supply, everything downstream
		# at zero.
		return source_v if point <= fault_index else 0.0
	var total := LOAD_OHMS
	for index: int in range(segments):
		total += _segment_ohms(index)
	var current := source_v / maxf(0.001, total)
	var dropped := 0.0
	for index: int in range(mini(point, segments)):
		dropped += _segment_ohms(index) * current
	return maxf(0.0, source_v - dropped)


func probe_point(point: int) -> void:
	if _busy or challenge_completed:
		return
	var segments := int(_current_stage()["segments"])
	if point < 0 or point > segments:
		return
	_probe_index = point
	if not _readings.has(point):
		_probe_count += 1
	_readings[point] = _voltage_at(point)
	_refresh_rail()
	_set_status(
		(
			"测点 %d 读数 %.1fV。" % [point, float(_readings[point])]
			if CaseLocale.is_chinese()
			else "Test point %d reads %.1f V." % [point, float(_readings[point])]
		),
		COLOR_PARCHMENT
	)


## Segments the readings already rule out. An excluded segment is dimmed, so the
## board keeps the deduction visible instead of asking the player to hold it.
func _segment_excluded(index: int) -> bool:
	var stage := _current_stage()
	if str(stage["fault"]) != "open":
		return false
	for point: int in _readings:
		var volts := float(_readings[point])
		# A full reading proves everything upstream of that point is intact.
		if volts > 0.001 and index < int(point):
			return true
		# A zero reading proves the break is at or before that point.
		if volts <= 0.001 and index >= int(point):
			return true
	return false


func accuse_segment(index: int) -> void:
	if _busy or challenge_completed:
		return
	_accused = index
	var stage := _current_stage()
	if index == int(stage["fault_index"]):
		_busy = true
		_play_fault_found(index)
		return
	_refresh_rail()
	_set_status(_wrong_accusation_reason(index), COLOR_WARN)


## A wrong call is answered with the reading that contradicts it, not with "no".
func _wrong_accusation_reason(index: int) -> String:
	var chinese := CaseLocale.is_chinese()
	for point: int in _readings:
		var volts := float(_readings[point])
		if volts > 0.001 and index < int(point):
			return (
				"测点 %d 有 %.1fV，说明电流已经流过第 %d 段，它是好的。" % [point, volts, index + 1]
				if chinese
				else "Test point %d still carries %.1f V, so current reached it and segment %d is sound."
				% [point, volts, index + 1]
			)
		if volts <= 0.001 and index >= int(point):
			return (
				"测点 %d 已经是 0V，断点在它之前，不可能是第 %d 段。" % [point, index + 1]
				if chinese
				else "Test point %d already reads zero, so the break is upstream of it \u2014 not segment %d."
				% [point, index + 1]
			)
	return (
		"读数还不足以指认这一段。再测几个点。" if chinese
		else "The readings do not support that call yet. Take more measurements."
	)


func _optimal_probes() -> int:
	var segments := int(_current_stage()["segments"])
	return maxi(1, int(ceil(log(float(segments)) / log(2.0))))


func _load_diagnostic_stage() -> void:
	_sockets.clear()
	_readings.clear()
	_probe_index = -1
	_probe_count = 0
	_accused = -1
	_build_deck()
	_refresh_rail()
	_refresh_copy()
	_set_status(
		(
			"母线是死的。点测点取读数，推断故障在哪一段，然后指认那一段。最优只需 %d 次测量。"
			% _optimal_probes()
			if CaseLocale.is_chinese()
			else "The bus is dead. Probe test points, work out which segment failed, then name it. %d measurements is enough if you choose them well."
			% _optimal_probes()
		),
		COLOR_WARN
	)


func _play_fault_found(index: int) -> void:
	GameAudio.play(&"bench_pass")
	var stage := _current_stage()
	_refresh_rail()
	_set_status(
		(
			"第 %d 段确认故障（%s）。用了 %d 次测量，最优 %d 次。"
			% [
				index + 1,
				"断路" if str(stage["fault"]) == "open" else "高阻劣化",
				_probe_count,
				_optimal_probes(),
			]
			if CaseLocale.is_chinese()
			else "Segment %d confirmed (%s). %d measurements taken, %d was optimal."
			% [
				index + 1,
				"open" if str(stage["fault"]) == "open" else "high resistance",
				_probe_count,
				_optimal_probes(),
			]
		),
		COLOR_SUCCESS
	)
	OpticalFxRuntime.pulse_ring(
		self, effect_layer, _test_point_position(index), Color(1.0, 0.42, 0.32, 0.96), 26.0, 3.0, 0.44
	)
	OpticalFxRuntime.pulse_ring(
		self, effect_layer, _test_point_position(index + 1), COLOR_LIVE, 22.0, 2.6, 0.52
	)
	await get_tree().create_timer(0.80).timeout
	_advance_stage()


func _test_point_position(point: int) -> Vector2:
	var segments := int(_current_stage()["segments"])
	var span := (LAMP_X - 78.0) - (SOURCE_X + 46.0)
	var step := span / float(maxi(1, segments))
	return Vector2(SOURCE_X + 46.0 + step * float(clampi(point, 0, segments)), MAIN_RUN_Y)


## Link notation: "socket" is an empty socket, "socket:part" is a socket that
## fixed hardware that is not the player's to change.
func _describe_link(kind: String, entry: String) -> Dictionary:
	if entry == "socket":
		return {"kind": kind, "is_socket": true, "part": ""}
	if entry.begins_with("socket:"):
		return {"kind": kind, "is_socket": true, "part": entry.trim_prefix("socket:")}
	return {"kind": kind, "is_socket": false, "part": entry}


func _stage_hint() -> String:
	var stage := _current_stage()
	return str(stage["lesson_zh" if CaseLocale.is_chinese() else "lesson_en"])


func _part_note(part_id: String) -> String:
	var part := PARTS[part_id] as Dictionary
	return str(part["note_zh" if CaseLocale.is_chinese() else "note_en"])


# --- Presentation ----------------------------------------------------------
#
# The bench is drawn as hardware, not as a form: a live rail, physical sockets
# and a lamp that is either lit or not. Every outcome is shown on that hardware,
# because "the lamp stayed dark while the circuit was complete" is the lesson.

const MAIN_RUN_Y := 178.0
const BYPASS_RUN_Y := 54.0
const BYPASS_ROW_STEP := 58.0
const SOURCE_X := 46.0
const LAMP_X := 742.0
const MAIN_RUN_END := 592.0
const BYPASS_TAP_IN_X := 622.0
const BYPASS_TAP_OUT_X := 786.0
const SOCKET_SIZE := Vector2(112.0, 58.0)


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "CircuitLabRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var veil := ColorRect.new()
	veil.name = "CircuitLabVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.006, 0.016, 0.93)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(veil)

	ArchiveUi.install_screen_atmosphere(root_control, {
		"lamp_anchor": Vector2(0.5, 0.34),
		"lamp_tint": Color(0.62, 0.88, 1.0, 1.0),
		"mote_tint": Color(0.80, 0.92, 1.0, 1.0),
		"lamp_strength": 0.18,
		"lamp_radius": 0.52,
		"vignette_strength": 0.60,
		"vignette_radius": 0.32,
		"mote_strength": 0.32,
	})

	frame = Panel.new()
	frame.name = "CircuitLabFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -FRAME_SIZE.x * 0.5
	frame.offset_top = -FRAME_SIZE.y * 0.5
	frame.offset_right = FRAME_SIZE.x * 0.5
	frame.offset_bottom = FRAME_SIZE.y * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(ArchiveUi.COLOR_PANEL, ArchiveUi.COLOR_BRASS, 2, 6, 16)
	)
	root_control.add_child(frame)
	ArchiveUi.install_dossier_chrome(frame, {"accent": ArchiveUi.COLOR_BRASS})

	title_label = _make_label("CircuitLabTitle", Vector2(40.0, 18.0), Vector2(820.0, 32.0), 22, COLOR_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_label = _make_label("CircuitLabLesson", Vector2(60.0, 54.0), Vector2(780.0, 22.0), 12, COLOR_MUTED)
	lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label = _make_label("CircuitLabStage", Vector2(60.0, 78.0), Vector2(780.0, 18.0), 10, COLOR_MUTED)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for pip_index: int in range(CONTINUITY_STAGES.size()):
		var pip := Panel.new()
		pip.name = "StagePip%d" % pip_index
		pip.size = Vector2(46.0, 4.0)
		pip.position = Vector2(
			FRAME_SIZE.x * 0.5 - (CONTINUITY_STAGES.size() * 54.0) * 0.5 + pip_index * 54.0,
			100.0
		)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pip)
		stage_pips.append(pip)

	rail = Control.new()
	rail.name = "CircuitLabRail"
	rail.position = Vector2(38.0, 112.0)
	rail.size = RAIL_SIZE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_stylebox_override("panel", ArchiveUi.panel_style())
	frame.add_child(rail)
	var rail_plate := Panel.new()
	rail_plate.name = "RailPlate"
	rail_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_plate.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(Color(0.030, 0.036, 0.050, 0.99), Color(0.34, 0.46, 0.56, 0.72), 1, 5, 6)
	)
	rail.add_child(rail_plate)

	effect_layer = Control.new()
	effect_layer.name = "CircuitLabVFX"
	effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_layer.z_index = 40
	rail.add_child(effect_layer)

	deck = Control.new()
	deck.name = "CircuitLabDeck"
	deck.position = Vector2(38.0, 372.0)
	deck.size = DECK_SIZE
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(deck)

	status_label = _make_label("CircuitLabStatus", Vector2(40.0, 508.0), Vector2(820.0, 40.0), 12, COLOR_PARCHMENT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	test_button = _make_button("CircuitLabTestButton", Vector2(300.0, 558.0), Vector2(300.0, 46.0), ArchiveUi.ROLE_ACTION)
	test_button.pressed.connect(run_test)
	reset_button = _make_button("CircuitLabResetButton", Vector2(40.0, 558.0), Vector2(240.0, 46.0), ArchiveUi.ROLE_ARCHIVE)
	reset_button.pressed.connect(reset_current_stage)
	close_button = _make_button("CircuitLabCloseButton", Vector2(620.0, 558.0), Vector2(240.0, 46.0), ArchiveUi.ROLE_MUTED)
	close_button.pressed.connect(close)
	ArchiveUi.wire_focus_cycle([test_button, reset_button, close_button])


func _make_label(node_name: String, at: Vector2, size: Vector2, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	# The bench prints Chinese copy, which the pixel face does not fully cover.
	label.add_theme_font_override("font", _bench_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)
	return label


func _bench_font() -> FontFile:
	return ArchiveUi.ARCHIVE_FONT if CaseLocale.is_chinese() else ArchiveUi.PIXEL_FONT


func _make_button(node_name: String, at: Vector2, size: Vector2, role: StringName) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = at
	button.size = size
	button.add_theme_font_size_override("font_size", 13)
	ArchiveUi.apply_button(button, role)
	frame.add_child(button)
	return button


func _socket_centre(socket_id: String) -> Vector2:
	var socket := _sockets.get(socket_id, {}) as Dictionary
	var kind := str(socket.get("kind", "main"))
	var siblings: Array[String] = []
	for other_id: String in _sockets:
		if str((_sockets[other_id] as Dictionary)["kind"]) == kind:
			siblings.append(other_id)
	var slot := maxi(0, siblings.find(socket_id))
	var count := maxi(1, siblings.size())
	if kind == "main":
		var span := MAIN_RUN_END - SOURCE_X - 30.0
		var step := span / float(count)
		return Vector2(SOURCE_X + 30.0 + step * (float(slot) + 0.5), MAIN_RUN_Y)
	# Each bypass is its own branch across the lamp, so they stack into rows and
	# tap the same two points on the run rather than sharing one wire.
	return Vector2(
		(BYPASS_TAP_IN_X + BYPASS_TAP_OUT_X) * 0.5,
		BYPASS_RUN_Y + float(slot) * BYPASS_ROW_STEP
	)


func _is_circuit_live() -> bool:
	return (
		_first_failing_socket("main", false).is_empty()
		and _first_failing_socket("bypass", true).is_empty()
	)


func _refresh_rail() -> void:
	for child: Node in rail.get_children():
		if child.name != "RailPlate" and child.name != "CircuitLabVFX":
			# Detached before freeing: queue_free() alone keeps the old node in the
			# tree until end of frame, so the rebuilt node would be auto-renamed and
			# every lookup by name would silently miss it.
			rail.remove_child(child)
			child.queue_free()
	meter = null
	lamp_view = null
	rheostat_view = null
	hold_bar = null
	readout_label = null
	if _bench_id() == BENCH_REGULATOR:
		_refresh_regulator_rail()
		return
	if _bench_id() == BENCH_DIAGNOSTIC:
		_refresh_diagnostic_rail()
		return

	var lit := _is_circuit_live()
	var carrier_path := PackedVector2Array()
	carrier_path.append(Vector2(SOURCE_X, MAIN_RUN_Y))
	_draw_conductor(Vector2(SOURCE_X, MAIN_RUN_Y), Vector2(SOURCE_X + 30.0, MAIN_RUN_Y), lit)
	_draw_terminal(Vector2(SOURCE_X, MAIN_RUN_Y), "SOURCE", "\u7535\u6e90")
	_draw_lamp(Vector2(LAMP_X, MAIN_RUN_Y), lit)

	var previous := Vector2(SOURCE_X + 30.0, MAIN_RUN_Y)
	for socket_id: String in _sockets:
		if str((_sockets[socket_id] as Dictionary)["kind"]) != "main":
			continue
		var centre := _socket_centre(socket_id)
		_draw_conductor(previous, centre - Vector2(SOCKET_SIZE.x * 0.5, 0.0), lit)
		_draw_socket(socket_id, centre)
		previous = centre + Vector2(SOCKET_SIZE.x * 0.5, 0.0)
	_draw_conductor(previous, Vector2(LAMP_X - 32.0, MAIN_RUN_Y), lit)
	carrier_path.append(Vector2(LAMP_X - 32.0, MAIN_RUN_Y))
	carrier_path.append(Vector2(LAMP_X + 32.0, MAIN_RUN_Y))
	carrier_path.append(Vector2(BYPASS_TAP_OUT_X, MAIN_RUN_Y))
	_install_carriers(carrier_path if lit else PackedVector2Array())

	var bypass_ids: Array[String] = []
	for socket_id: String in _sockets:
		if str((_sockets[socket_id] as Dictionary)["kind"]) == "bypass":
			bypass_ids.append(socket_id)
	if bypass_ids.is_empty():
		return
	_draw_conductor(Vector2(LAMP_X + 32.0, MAIN_RUN_Y), Vector2(BYPASS_TAP_OUT_X, MAIN_RUN_Y), lit)
	for socket_id: String in bypass_ids:
		var centre := _socket_centre(socket_id)
		var branch_live := _branch_conducts(socket_id)
		_draw_conductor(Vector2(BYPASS_TAP_IN_X, MAIN_RUN_Y), Vector2(BYPASS_TAP_IN_X, centre.y), branch_live)
		_draw_conductor(Vector2(BYPASS_TAP_IN_X, centre.y), centre - Vector2(SOCKET_SIZE.x * 0.5, 0.0), branch_live)
		_draw_conductor(centre + Vector2(SOCKET_SIZE.x * 0.5, 0.0), Vector2(BYPASS_TAP_OUT_X, centre.y), branch_live)
		_draw_conductor(Vector2(BYPASS_TAP_OUT_X, centre.y), Vector2(BYPASS_TAP_OUT_X, MAIN_RUN_Y), branch_live)
		_draw_socket(socket_id, centre)


func _branch_conducts(socket_id: String) -> bool:
	var part_id := str((_sockets[socket_id] as Dictionary)["part"])
	if part_id.is_empty():
		return false
	return bool((PARTS[part_id] as Dictionary)["conducts"])


## Carriers only exist while the circuit is actually live, so "is it on?" is
## answered by motion rather than by a colour the player has to remember.
func _install_carriers(path: PackedVector2Array) -> void:
	var existing := rail.get_node_or_null("CircuitLabCarriers")
	if existing != null:
		existing.queue_free()
	if path.size() < 2:
		return
	var carriers := CurrentFlow.new()
	carriers.name = "CircuitLabCarriers"
	carriers.path = path
	carriers.tint = COLOR_LIVE
	carriers.z_index = 30
	rail.add_child(carriers)


func _refresh_diagnostic_rail() -> void:
	var stage := _current_stage()
	var segments := int(stage["segments"])
	var solved := _accused == int(stage["fault_index"])

	_draw_terminal(
		Vector2(SOURCE_X, MAIN_RUN_Y),
		"SUPPLY %.0fV" % float(stage["source_v"]),
		"电源 %.0fV" % float(stage["source_v"])
	)
	_draw_lamp(Vector2(LAMP_X, MAIN_RUN_Y), false)
	_draw_conductor(Vector2(SOURCE_X, MAIN_RUN_Y), _test_point_position(0), false)
	_draw_conductor(_test_point_position(segments), Vector2(LAMP_X - 32.0, MAIN_RUN_Y), false)

	for index: int in range(segments):
		var from_point := _test_point_position(index)
		var to_point := _test_point_position(index + 1)
		var excluded := _segment_excluded(index)
		var guilty := solved and index == int(stage["fault_index"])
		var line := Line2D.new()
		line.name = "Segment_%d" % index
		line.points = PackedVector2Array([from_point + Vector2(9.0, 0.0), to_point - Vector2(9.0, 0.0)])
		line.width = 6.0
		line.default_color = (
			Color(1.0, 0.34, 0.26, 1.0) if guilty
			else (Color(0.26, 0.24, 0.22, 0.85) if excluded else Color(0.72, 0.46, 0.22, 1.0))
		)
		rail.add_child(line)
		if guilty:
			# The fault is shown, not just named: the conductor is visibly parted.
			var break_at := (from_point + to_point) * 0.5
			var scar := Line2D.new()
			scar.points = PackedVector2Array([
				break_at + Vector2(-7.0, -9.0), break_at + Vector2(7.0, 9.0)
			])
			scar.width = 3.0
			scar.default_color = Color(0.06, 0.05, 0.05, 1.0)
			rail.add_child(scar)

		var tag := Label.new()
		tag.name = "SegmentTag_%d" % index
		tag.position = ((from_point + to_point) * 0.5) + Vector2(-26.0, 10.0)
		tag.size = Vector2(52.0, 16.0)
		tag.text = "%d" % (index + 1)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_font_override("font", _bench_font())
		tag.add_theme_color_override(
			"font_color", COLOR_DEAD if excluded else COLOR_MUTED
		)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_child(tag)

	for point: int in range(segments + 1):
		_draw_test_point(point)

	if _probe_index >= 0:
		_draw_probe(_test_point_position(_probe_index))

	readout_label = Label.new()
	readout_label.name = "DiagnosticReadout"
	readout_label.position = Vector2(20.0, RAIL_SIZE.y - 34.0)
	readout_label.size = Vector2(RAIL_SIZE.x - 40.0, 20.0)
	readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout_label.add_theme_font_size_override("font_size", 11)
	readout_label.add_theme_font_override("font", _bench_font())
	readout_label.add_theme_color_override("font_color", COLOR_MUTED)
	readout_label.text = (
		"已测 %d 点　·　最优 %d 次　·　%s"
		% [
			_probe_count,
			_optimal_probes(),
			"断路故障" if str(stage["fault"]) == "open" else "高阻故障：没有零点",
		]
		if CaseLocale.is_chinese()
		else "%d PROBED  \u00b7  %d OPTIMAL  \u00b7  %s"
		% [
			_probe_count,
			_optimal_probes(),
			"OPEN FAULT" if str(stage["fault"]) == "open" else "HIGH-RESISTANCE: NOTHING READS ZERO",
		]
	)
	readout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(readout_label)


func _draw_test_point(point: int) -> void:
	var at := _test_point_position(point)
	var measured := _readings.has(point)
	var stud := Panel.new()
	stud.name = "TestPoint_%d" % point
	stud.size = Vector2(18.0, 18.0)
	stud.position = at - Vector2(9.0, 9.0)
	stud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stud.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(
			Color(0.86, 0.72, 0.36, 1.0) if measured else Color(0.42, 0.36, 0.26, 1.0),
			ArchiveUi.COLOR_BRASS,
			1,
			9,
			0
		)
	)
	rail.add_child(stud)

	var caption := Label.new()
	caption.position = at + Vector2(-24.0, -44.0)
	caption.size = Vector2(48.0, 16.0)
	caption.text = "%.1fV" % float(_readings[point]) if measured else "TP%d" % point
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_font_override("font", _bench_font())
	caption.add_theme_color_override("font_color", COLOR_GOLD if measured else COLOR_MUTED)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(caption)

	var hit := Button.new()
	hit.name = "ProbeHit_%d" % point
	hit.size = Vector2(34.0, 44.0)
	hit.position = at - Vector2(17.0, 22.0)
	hit.flat = true
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", _hit_style(Color(1.0, 1.0, 1.0, 0.0)))
	hit.add_theme_stylebox_override("hover", _hit_style(Color(0.98, 0.84, 0.44, 0.24)))
	hit.add_theme_stylebox_override("pressed", _hit_style(Color(0.98, 0.84, 0.44, 0.34)))
	hit.pressed.connect(probe_point.bind(point))
	rail.add_child(hit)


func _draw_probe(at: Vector2) -> void:
	var lead := Line2D.new()
	lead.name = "ProbeLead"
	lead.points = PackedVector2Array([
		at + Vector2(28.0, -76.0), at + Vector2(12.0, -34.0), at + Vector2(0.0, -12.0)
	])
	lead.width = 3.0
	lead.default_color = Color(0.72, 0.20, 0.18, 1.0)
	rail.add_child(lead)

	var body := Line2D.new()
	body.name = "ProbeBody"
	body.points = PackedVector2Array([at + Vector2(12.0, -34.0), at + Vector2(0.0, -12.0)])
	body.width = 9.0
	body.default_color = Color(0.24, 0.22, 0.22, 1.0)
	rail.add_child(body)

	probe_tip = Control.new()
	probe_tip.name = "ProbeTip"
	rail.add_child(probe_tip)
	OpticalFxRuntime.pulse_ring(self, effect_layer, at, COLOR_LIVE, 12.0, 2.0, 0.30)


func _build_verdict_rack() -> void:
	var segments := int(_current_stage()["segments"])
	var columns := mini(segments, 10)
	var width := (DECK_SIZE.x - float(columns - 1) * 8.0) / float(maxi(1, columns))
	var heading := Label.new()
	heading.name = "VerdictHeading"
	heading.position = Vector2(0.0, -4.0)
	heading.size = Vector2(DECK_SIZE.x, 18.0)
	heading.text = (
		"指认故障线段" if CaseLocale.is_chinese() else "NAME THE FAULTY SEGMENT"
	)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_font_override("font", _bench_font())
	heading.add_theme_color_override("font_color", COLOR_GOLD)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(heading)

	for index: int in range(segments):
		var button := Button.new()
		button.name = "Verdict_%d" % index
		button.size = Vector2(width, 46.0)
		button.position = Vector2(float(index % columns) * (width + 8.0), 20.0)
		button.text = "%d" % (index + 1)
		button.add_theme_font_size_override("font_size", 13)
		ArchiveUi.apply_button(
			button,
			ArchiveUi.ROLE_MUTED if _segment_excluded(index) else ArchiveUi.ROLE_ARCHIVE
		)
		button.pressed.connect(accuse_segment.bind(index))
		deck.add_child(button)
		segment_buttons[index] = button


func _refresh_regulator_rail() -> void:
	var stage := _current_stage()
	var safe := stage["safe"] as Array
	var lit := _regulator_outcome() == "safe"

	_draw_conductor(Vector2(SOURCE_X, MAIN_RUN_Y), Vector2(SOURCE_X + 96.0, MAIN_RUN_Y), lit)
	_draw_terminal(
		Vector2(SOURCE_X, MAIN_RUN_Y),
		"SUPPLY %.0fV" % float(stage["source_v"]),
		"\u7535\u6e90 %.0fV" % float(stage["source_v"])
	)

	rheostat_view = RheostatView.new()
	rheostat_view.name = "BenchRheostat"
	rheostat_view.size = Vector2(300.0, 92.0)
	rheostat_view.position = Vector2(SOURCE_X + 96.0, MAIN_RUN_Y - 56.0)
	rheostat_view.mouse_filter = Control.MOUSE_FILTER_STOP
	rheostat_view.configure(float(stage["r_max"]), _rheostat)
	rheostat_view.ratio_changed.connect(set_rheostat)
	rail.add_child(rheostat_view)

	var rheostat_caption := Label.new()
	rheostat_caption.position = rheostat_view.position + Vector2(0.0, rheostat_view.size.y + 2.0)
	rheostat_caption.size = Vector2(rheostat_view.size.x, 16.0)
	rheostat_caption.text = "\u53d8\u963b\u5668\u00b7\u62d6\u52a8\u6ed1\u7247" if CaseLocale.is_chinese() else "RHEOSTAT \u00b7 DRAG THE WIPER"
	rheostat_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rheostat_caption.add_theme_font_size_override("font_size", 10)
	rheostat_caption.add_theme_color_override("font_color", COLOR_GOLD)
	rheostat_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(rheostat_caption)

	_draw_conductor(
		Vector2(rheostat_view.position.x + rheostat_view.size.x, MAIN_RUN_Y),
		Vector2(LAMP_X - 32.0, MAIN_RUN_Y),
		lit
	)
	_draw_lamp(Vector2(LAMP_X, MAIN_RUN_Y), lit)
	lamp_view = rail.get_node_or_null("BenchLamp") as LampView

	meter = MeterView.new()
	meter.name = "BenchMeter"
	meter.size = Vector2(186.0, 122.0)
	meter.position = Vector2(LAMP_X - 96.0, BYPASS_RUN_Y - 40.0)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.configure(float(stage["source_v"]), float(safe[0]), float(safe[1]))
	meter.set_reading(_lamp_voltage())
	rail.add_child(meter)

	var meter_caption := Label.new()
	meter_caption.position = Vector2(meter.position.x, meter.position.y - 20.0)
	meter_caption.size = Vector2(meter.size.x, 18.0)
	meter_caption.text = "\u706f\u7535\u538b\u8868" if CaseLocale.is_chinese() else "LAMP VOLTMETER"
	meter_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_caption.add_theme_font_size_override("font_size", 10)
	meter_caption.add_theme_color_override("font_color", COLOR_GOLD)
	meter_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(meter_caption)

	# Hold gauge: the bench is only satisfied when the value is kept, not crossed.
	var hold_track := ColorRect.new()
	hold_track.name = "HoldTrack"
	hold_track.position = Vector2(20.0, RAIL_SIZE.y - 16.0)
	hold_track.size = Vector2(RAIL_SIZE.x - 40.0, 6.0)
	hold_track.color = Color(0.10, 0.11, 0.13, 1.0)
	hold_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(hold_track)
	hold_bar = ColorRect.new()
	hold_bar.name = "HoldBar"
	hold_bar.position = hold_track.position
	hold_bar.size = Vector2(0.0, 6.0)
	hold_bar.color = COLOR_SUCCESS
	hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(hold_bar)

	readout_label = Label.new()
	readout_label.name = "RegulatorReadout"
	readout_label.position = Vector2(20.0, RAIL_SIZE.y - 38.0)
	readout_label.size = Vector2(RAIL_SIZE.x - 40.0, 20.0)
	readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout_label.add_theme_font_size_override("font_size", 11)
	readout_label.add_theme_color_override("font_color", COLOR_MUTED)
	readout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(readout_label)

	var carrier_path := PackedVector2Array()
	carrier_path.append(Vector2(SOURCE_X, MAIN_RUN_Y))
	carrier_path.append(Vector2(LAMP_X + 32.0, MAIN_RUN_Y))
	_install_carriers(carrier_path if lit else PackedVector2Array())


func _build_regulator_rack() -> void:
	# The rheostat lives on the board itself, so this bench has no parts rack.
	var guidance := Label.new()
	guidance.name = "RegulatorGuidance"
	guidance.position = Vector2(0.0, 24.0)
	guidance.size = Vector2(DECK_SIZE.x, 40.0)
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.add_theme_font_size_override("font_size", 12)
	guidance.add_theme_color_override("font_color", COLOR_MUTED)
	guidance.text = (
		"\u6ca1\u6709\u96f6\u4ef6\u67b6\u3002\u7535\u963b\u662f\u8fde\u7eed\u7684\uff1a\u624b\u653e\u5728\u54ea\u91cc\uff0c\u7535\u963b\u5c31\u662f\u591a\u5c11\u3002"
		if CaseLocale.is_chinese()
		else "No parts rack here. The resistance is continuous: it is wherever your hand leaves the wiper."
	)
	guidance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(guidance)


func _draw_conductor(from_point: Vector2, to_point: Vector2, live: bool) -> void:
	var line := Line2D.new()
	line.name = "Conductor"
	line.points = PackedVector2Array([from_point, to_point])
	line.width = 4.0
	line.default_color = COLOR_LIVE if live else Color(0.42, 0.34, 0.24, 0.92)
	rail.add_child(line)


func _draw_terminal(at: Vector2, text_en: String, text_zh: String) -> void:
	var source_view := SourceView.new()
	source_view.name = "SourceTerminal"
	source_view.size = Vector2(64.0, 84.0)
	source_view.position = at - Vector2(32.0, 42.0)
	source_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_view.set_energised(_is_circuit_live())
	rail.add_child(source_view)
	var label := Label.new()
	label.position = at + Vector2(-42.0, -62.0)
	label.size = Vector2(84.0, 18.0)
	label.text = text_zh if CaseLocale.is_chinese() else text_en
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(label)


func _draw_lamp(at: Vector2, lit: bool) -> void:
	var halo := Sprite2D.new()
	halo.name = "LampHalo"
	halo.texture = OpticalFxRuntime.radial_glow_texture()
	halo.material = OpticalFxRuntime.additive_material()
	halo.position = at
	halo.scale = Vector2.ONE * 2.6
	halo.modulate = Color(1.0, 0.86, 0.52, 0.66 if lit else 0.0)
	rail.add_child(halo)
	if lit:
		var breathe := halo.create_tween().set_loops()
		breathe.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		breathe.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(halo, "modulate:a", 0.44, 0.9)
		breathe.tween_property(halo, "modulate:a", 0.66, 0.9)

	var lamp_view := LampView.new()
	lamp_view.name = "BenchLamp"
	lamp_view.size = Vector2(84.0, 96.0)
	lamp_view.position = at - Vector2(42.0, 40.0)
	lamp_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp_view.set_lit(lit)
	rail.add_child(lamp_view)
	var label := Label.new()
	label.position = at + Vector2(-46.0, 58.0)
	label.size = Vector2(92.0, 18.0)
	label.text = ("负载灯" if CaseLocale.is_chinese() else "LOAD LAMP")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_GOLD if lit else COLOR_MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(label)


func _draw_socket(socket_id: String, centre: Vector2) -> void:
	var socket := _sockets[socket_id] as Dictionary
	var is_socket := bool(socket["is_socket"])
	var part_id := str(socket["part"])
	var conducts := false
	if not part_id.is_empty():
		conducts = bool((PARTS[part_id] as Dictionary)["conducts"])

	var view := PartView.new()
	view.name = "PartView_" + socket_id
	view.size = SOCKET_SIZE
	view.position = centre - SOCKET_SIZE * 0.5
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.configure(part_id, is_socket, conducts, conducts and _is_circuit_live())
	rail.add_child(view)

	var caption := Label.new()
	caption.name = "PartCaption_" + socket_id
	caption.position = centre + Vector2(-SOCKET_SIZE.x * 0.5, SOCKET_SIZE.y * 0.5 + 2.0)
	caption.size = Vector2(SOCKET_SIZE.x, 16.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if part_id.is_empty():
		caption.text = "空插槽" if CaseLocale.is_chinese() else "EMPTY SOCKET"
		caption.add_theme_color_override("font_color", COLOR_WARN)
	else:
		var part := PARTS[part_id] as Dictionary
		caption.text = str(part["zh" if CaseLocale.is_chinese() else "en"])
		caption.add_theme_color_override("font_color", COLOR_PARCHMENT if is_socket else COLOR_MUTED)
	rail.add_child(caption)

	# The hit target sits over the drawn part: the player clicks the object.
	var hit := Button.new()
	hit.name = "Socket_" + socket_id
	hit.size = SOCKET_SIZE
	hit.position = view.position
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL if is_socket else Control.FOCUS_NONE
	hit.disabled = not is_socket
	hit.mouse_filter = Control.MOUSE_FILTER_STOP if is_socket else Control.MOUSE_FILTER_IGNORE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", _hit_style(Color(1.0, 1.0, 1.0, 0.0)))
	hit.add_theme_stylebox_override("hover", _hit_style(Color(0.98, 0.84, 0.44, 0.22)))
	hit.add_theme_stylebox_override("pressed", _hit_style(Color(0.98, 0.84, 0.44, 0.32)))
	hit.add_theme_stylebox_override("disabled", _hit_style(Color(1.0, 1.0, 1.0, 0.0)))
	if is_socket:
		hit.pressed.connect(_on_socket_pressed.bind(socket_id))
	rail.add_child(hit)


func _hit_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(3)
	return style


func _on_socket_pressed(socket_id: String) -> void:
	if _selected_part.is_empty():
		_set_status(
			"先从下方零件架上选一个零件。" if CaseLocale.is_chinese() else "Pick a part from the rack below first.",
			COLOR_WARN
		)
		return
	place_part(socket_id, _selected_part)


func _build_deck() -> void:
	for child: Node in deck.get_children():
		child.queue_free()
	part_buttons.clear()
	segment_buttons.clear()
	if _bench_id() == BENCH_REGULATOR:
		_build_regulator_rack()
		return
	if _bench_id() == BENCH_DIAGNOSTIC:
		_build_verdict_rack()
		return
	var tray := _current_stage()["tray"] as Array
	var width := (DECK_SIZE.x - float(tray.size() - 1) * 12.0) / float(maxi(1, tray.size()))
	var index := 0
	for part_id: String in tray:
		var part := PARTS[part_id] as Dictionary
		var slot_position := Vector2(float(index) * (width + 12.0), 4.0)
		# The rack shows the same object the board will hold, so choosing a part
		# is recognising hardware rather than matching a word. The symbol keeps a
		# fixed width and centres in its slot, so a short tray does not stretch
		# a copper bar into something unrecognisable.
		var preview_width := minf(width, 176.0)
		var preview := PartView.new()
		preview.name = "PartPreview_" + part_id
		preview.size = Vector2(preview_width, 52.0)
		preview.position = slot_position + Vector2((width - preview_width) * 0.5, 0.0)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.configure(part_id, false, bool(part["conducts"]), false)
		deck.add_child(preview)

		var caption := Label.new()
		caption.name = "PartLabel_" + part_id
		caption.position = slot_position + Vector2(0.0, 54.0)
		caption.size = Vector2(width, 16.0)
		caption.text = str(part["zh" if CaseLocale.is_chinese() else "en"])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", COLOR_PARCHMENT)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck.add_child(caption)

		var button := Button.new()
		button.name = "Part_" + part_id
		button.size = Vector2(width, 72.0)
		button.position = slot_position
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _hit_style(Color(1.0, 1.0, 1.0, 0.0)))
		button.add_theme_stylebox_override("hover", _hit_style(Color(0.98, 0.84, 0.44, 0.18)))
		button.add_theme_stylebox_override("pressed", _hit_style(Color(0.98, 0.84, 0.44, 0.30)))
		button.pressed.connect(_on_part_pressed.bind(part_id))
		deck.add_child(button)
		part_buttons[part_id] = button
		index += 1


func _highlight_selected_part() -> void:
	for part_id: String in part_buttons:
		var button := part_buttons[part_id] as Button
		var chosen := part_id == _selected_part
		button.add_theme_stylebox_override(
			"normal",
			_hit_style(Color(0.72, 0.55, 1.0, 0.30) if chosen else Color(1.0, 1.0, 1.0, 0.0))
		)


func _on_part_pressed(part_id: String) -> void:
	_selected_part = part_id
	_highlight_selected_part()
	_set_status(_part_note(part_id), COLOR_PARCHMENT)


func _set_status(text: String, colour: Color) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color", colour)


func _refresh_copy(_language: String = "") -> void:
	if title_label == null:
		return
	var chinese := CaseLocale.is_chinese()
	var regulator := _bench_id() == BENCH_REGULATOR
	var diagnostic := _bench_id() == BENCH_DIAGNOSTIC
	title_label.text = (
		("接线台 III · 排障" if chinese else "JUNCTION BENCH III  ·  FAULT ISOLATION")
		if diagnostic
		else (
			("接线台 II · 调压" if chinese else "JUNCTION BENCH II  ·  REGULATION")
			if regulator
			else ("接线台 I · 通路" if chinese else "JUNCTION BENCH I  ·  CONTINUITY")
		)
	)
	lesson_label.text = _stage_hint()
	stage_label.text = (
		"第 %d / %d 阶" % [stage_index + 1, _stage_list().size()]
		if chinese
		else "STAGE %d / %d" % [stage_index + 1, _stage_list().size()]
	)
	# The regulator bench is always live and is satisfied by holding the value,
	# so a one-shot ENERGISE control there would be a button that does nothing.
	test_button.visible = not regulator and not diagnostic
	test_button.text = "通电测试" if chinese else "ENERGISE"
	reset_button.text = "重置本阶" if chinese else "RESET STAGE"
	close_button.text = "离开" if chinese else "LEAVE BENCH"
	for pip_index: int in range(stage_pips.size()):
		var cleared := pip_index < stage_index
		stage_pips[pip_index].add_theme_stylebox_override(
			"panel",
			ArchiveUi.panel_style(
				COLOR_SUCCESS if cleared else (COLOR_GOLD if pip_index == stage_index else COLOR_DEAD),
				Color(0.0, 0.0, 0.0, 0.0),
				0,
				2,
				0
			)
		)
	_refresh_rail()


# --- Outcomes --------------------------------------------------------------


func _play_dead_run(open_socket_id: String) -> void:
	GameAudio.play(&"bench_fail")
	_set_status(
		(
			"回路在这里断开，全线没有电流。串联回路必须每一段都导通。"
			if CaseLocale.is_chinese()
			else "The run is open here, so no current flows anywhere. Every link in series must conduct."
		),
		COLOR_WARN
	)
	var centre := _socket_centre(open_socket_id)
	OpticalFxRuntime.pulse_ring(self, effect_layer, centre, Color(1.0, 0.42, 0.34, 0.92), 30.0, 2.4, 0.40)
	var shake := create_tween()
	shake.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake.tween_property(rail, "position:x", 42.0, 0.05)
	shake.tween_property(rail, "position:x", 34.0, 0.05)
	shake.tween_property(rail, "position:x", 38.0, 0.06)
	shake.tween_callback(func() -> void: _busy = false)


## The short is the case's own crime, demonstrated: current is traced visibly
## through the bypass and the lamp stays dark while the loop is "complete".
func _play_short(shorted_socket_id: String) -> void:
	GameAudio.play(&"bench_fail")
	_set_status(
		(
			"电流从旁路绕过了灯。回路是通的，灯却不亮——阿什福德的停电就是这样造成的。"
			if CaseLocale.is_chinese()
			else "Current took the bypass around the lamp. The loop is complete and the lamp is still dark. That is how Ashford went dark."
		),
		COLOR_WARN
	)
	var centre := _socket_centre(shorted_socket_id)
	var beam := Line2D.new()
	beam.name = "ShortTrace"
	effect_layer.add_child(beam)
	OpticalFxRuntime.trace_beam(
		self,
		beam,
		Vector2(BYPASS_TAP_IN_X, MAIN_RUN_Y),
		centre,
		Color(1.0, 0.52, 0.30, 0.96),
		5.0,
		0.30
	)
	OpticalFxRuntime.pulse_ring(self, effect_layer, centre, Color(1.0, 0.52, 0.30, 0.94), 30.0, 2.8, 0.46)
	await get_tree().create_timer(0.62).timeout
	if is_instance_valid(beam):
		beam.queue_free()
	_busy = false


func _play_live_run() -> void:
	GameAudio.play(&"bench_pass")
	_set_status(
		"通路建立，灯亮了。" if CaseLocale.is_chinese() else "The run is closed. The lamp lights.",
		COLOR_SUCCESS
	)
	_refresh_rail()
	var surge := Line2D.new()
	surge.name = "LiveSurge"
	effect_layer.add_child(surge)
	OpticalFxRuntime.trace_beam(
		self,
		surge,
		Vector2(SOURCE_X, MAIN_RUN_Y),
		Vector2(LAMP_X, MAIN_RUN_Y),
		COLOR_LIVE,
		6.0,
		0.34
	)
	OpticalFxRuntime.pulse_ring(self, effect_layer, Vector2(LAMP_X, MAIN_RUN_Y), COLOR_LIVE, 34.0, 3.0, 0.52)
	await get_tree().create_timer(0.66).timeout
	if is_instance_valid(surge):
		surge.queue_free()
	_advance_stage()


func _advance_stage() -> void:
	if stage_index >= CONTINUITY_STAGES.size() - 1:
		challenge_completed = true
		_busy = false
		_set_status(
			(
				"接线台 I 全部通过。辅助闸的位置已经解锁。"
				if CaseLocale.is_chinese()
				else "Junction Bench I is complete. The auxiliary plate is released."
			),
			COLOR_SUCCESS
		)
		completed.emit(challenge_id)
		return
	stage_index += 1
	_load_stage()

