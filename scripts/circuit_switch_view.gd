class_name CircuitSwitchView
extends Node2D

## A wall-mounted knife switch, drawn rather than blitted.
##
## The room it lives in is painted pixel art with worn stone, tarnished brass and
## real lighting. A flat vector plate reads as a placeholder against that, so this
## draws the switch as the hardware it is meant to be: a cast-iron backplate bolted
## to the wall, a brass bezel, two porcelain insulator posts, and a hinged blade
## that visibly swings down into its contact jaw when the plate is thrown.
##
## Drawing it in code rather than authoring two sprites is what lets the blade
## travel. A player who throws a switch should see the blade move and the contact
## take, not watch one picture swap for another.

const IRON_DARK := Color(0.105, 0.094, 0.086)
const IRON_BODY := Color(0.170, 0.152, 0.138)
const IRON_LIGHT := Color(0.243, 0.219, 0.196)
const IRON_EDGE := Color(0.070, 0.061, 0.055)
const BRASS_DARK := Color(0.353, 0.243, 0.098)
const BRASS_BODY := Color(0.588, 0.427, 0.180)
const BRASS_LIGHT := Color(0.816, 0.639, 0.310)
const BRASS_HOT := Color(0.976, 0.839, 0.478)
const PORCELAIN := Color(0.792, 0.757, 0.690)
const PORCELAIN_SHADE := Color(0.549, 0.510, 0.451)
const LIVE_ARC := Color(0.639, 0.902, 1.0)
const LIVE_GLOW := Color(0.412, 0.784, 0.949)

## Blade travel. The open angle is not a fixed number: it is derived from how much
## headroom the plate actually has, so a blade can never swing out through the
## bezel on a shorter plate than the one it was tuned against.
const BLADE_CLOSED_DEGREES := 0.0
const BLADE_TIP_MARGIN := 4.0

@export var plate_size := Vector2(64.0, 48.0)
@export var sequence_number := "1"

var _closed := false
var _blade_degrees := 0.0
var _live_pulse := 0.0
var _blade_tween: Tween


func _ready() -> void:
	_blade_degrees = _open_degrees()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _closed:
		return
	# Only a live switch animates. An open one is dead metal and should sit still.
	_live_pulse = fmod(_live_pulse + delta, TAU)
	queue_redraw()


func set_closed(closed: bool, animate := true) -> void:
	if _closed == closed and animate:
		return
	_closed = closed
	var target := BLADE_CLOSED_DEGREES if closed else _open_degrees()
	if _blade_tween != null and _blade_tween.is_valid():
		_blade_tween.kill()
	if not animate:
		_blade_degrees = target
		queue_redraw()
		return
	_blade_tween = create_tween()
	_blade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Closing is a decisive throw that lands hard; opening is the spring letting go.
	if closed:
		_blade_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		_blade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_blade_tween.tween_method(_set_blade_degrees, _blade_degrees, target, 0.22)


func is_closed() -> bool:
	return _closed


func _set_blade_degrees(value: float) -> void:
	_blade_degrees = value
	queue_redraw()


func _draw() -> void:
	var half := plate_size * 0.5
	_draw_backplate(half)
	_draw_bezel(half)
	_draw_terminals(half)
	_draw_blade(half)
	_draw_number_tag(half)


func _draw_backplate(half: Vector2) -> void:
	# Cast-iron slab with a chamfered edge, sitting slightly proud of the wall.
	var outer := Rect2(-half.x, -half.y, plate_size.x, plate_size.y)
	draw_rect(Rect2(outer.position + Vector2(2.0, 3.0), outer.size), Color(0.0, 0.0, 0.0, 0.42))
	draw_rect(outer, IRON_EDGE)
	draw_rect(outer.grow(-1.5), IRON_BODY)
	# Top light: the room is lit from above, so the upper lip catches it.
	draw_rect(Rect2(-half.x + 1.5, -half.y + 1.5, plate_size.x - 3.0, 2.5), IRON_LIGHT)
	draw_rect(Rect2(-half.x + 1.5, half.y - 3.0, plate_size.x - 3.0, 1.5), IRON_DARK)
	# Four mounting bolts.
	var inset := Vector2(half.x - 6.0, half.y - 6.0)
	for corner: Vector2 in [
		Vector2(-inset.x, -inset.y),
		Vector2(inset.x, -inset.y),
		Vector2(-inset.x, inset.y),
		Vector2(inset.x, inset.y),
	]:
		draw_circle(corner + Vector2(0.5, 0.8), 2.8, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(corner, 2.6, BRASS_DARK)
		draw_circle(corner + Vector2(-0.4, -0.5), 1.9, BRASS_BODY)
		draw_line(corner + Vector2(-1.5, 0.0), corner + Vector2(1.5, 0.0), IRON_EDGE, 1.0)


func _draw_bezel(half: Vector2) -> void:
	# Brass frame around a recessed slate panel: the working face of the switch.
	var frame := Rect2(-half.x + 7.0, -half.y + 7.0, plate_size.x - 14.0, plate_size.y - 14.0)
	draw_rect(frame, BRASS_DARK)
	draw_rect(frame.grow(-1.0), BRASS_BODY)
	draw_rect(frame.grow(-2.5), Color(0.086, 0.078, 0.086))
	# A live switch lights its own recess from the contact outward.
	if _closed:
		var pulse := 0.55 + 0.25 * sin(_live_pulse * 4.0)
		draw_rect(frame.grow(-2.5), Color(LIVE_GLOW.r, LIVE_GLOW.g, LIVE_GLOW.b, 0.10 * pulse))
	# Bezel highlight along the top inner edge.
	draw_line(
		Vector2(frame.position.x + 1.0, frame.position.y + 1.0),
		Vector2(frame.end.x - 1.0, frame.position.y + 1.0),
		BRASS_LIGHT,
		1.0
	)


func _draw_terminals(half: Vector2) -> void:
	# Two porcelain posts carry the circuit: the hinge on the left, the jaw on the
	# right. Porcelain is what makes this read as electrical hardware rather than
	# as a lever.
	for post: Vector2 in [_hinge_position(half), _jaw_position(half)]:
		draw_circle(post + Vector2(0.6, 1.0), 6.0, Color(0.0, 0.0, 0.0, 0.42))
		draw_circle(post, 5.6, PORCELAIN_SHADE)
		draw_circle(post + Vector2(-0.6, -0.8), 4.4, PORCELAIN)
		draw_circle(post, 2.6, BRASS_DARK)
		draw_circle(post + Vector2(-0.3, -0.4), 1.9, BRASS_BODY)

	# The jaw itself: a brass fork the blade seats into.
	var jaw := _jaw_position(half)
	var jaw_open := 4.6 if not _closed else 3.4
	draw_line(jaw + Vector2(-4.0, -jaw_open), jaw + Vector2(3.5, -jaw_open), BRASS_LIGHT, 2.0)
	draw_line(jaw + Vector2(-4.0, jaw_open), jaw + Vector2(3.5, jaw_open), BRASS_BODY, 2.0)


func _draw_blade(half: Vector2) -> void:
	var hinge := _hinge_position(half)
	var jaw := _jaw_position(half)
	var reach := _blade_reach(half)
	var angle := deg_to_rad(_blade_degrees)
	var direction := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-direction.y, direction.x)
	var tip := hinge + direction * reach

	# Blade body, drawn as a tapered brass bar with a lit upper face. An open blade
	# is dead metal; a seated one carries current and is lit accordingly.
	var root_half := 2.8
	var tip_half := 1.9
	var body_tone := BRASS_BODY if _closed else BRASS_BODY.darkened(0.22)
	var edge_tone := BRASS_LIGHT if _closed else BRASS_LIGHT.darkened(0.30)
	var body := PackedVector2Array([
		hinge + normal * root_half,
		tip + normal * tip_half,
		tip - normal * tip_half,
		hinge - normal * root_half,
	])
	var shadow := PackedVector2Array()
	for point: Vector2 in body:
		shadow.append(point + Vector2(1.0, 2.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.38))
	draw_colored_polygon(body, body_tone)
	draw_line(hinge + normal * root_half, tip + normal * tip_half, edge_tone, 1.2)
	draw_line(hinge - normal * root_half, tip - normal * tip_half, BRASS_DARK, 1.0)

	# Insulated grip, set inboard of the tip so the blade end stays a blade.
	var grip := hinge + direction * (reach * 0.80)
	draw_circle(grip + Vector2(0.5, 0.9), 3.4, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(grip, 3.0, Color(0.176, 0.086, 0.055))
	draw_circle(grip + Vector2(-0.4, -0.5), 2.0, Color(0.310, 0.161, 0.094))

	# Hinge pin over the blade root.
	draw_circle(hinge, 2.4, BRASS_HOT)
	draw_circle(hinge + Vector2(0.4, 0.5), 1.2, BRASS_DARK)

	if _closed:
		_draw_live_contact(jaw)


func _draw_live_contact(jaw: Vector2) -> void:
	# Current has taken. The contact is the brightest thing on the plate, and a
	# short arc flickers across the jaw so "live" is a state you can see.
	var pulse := 0.65 + 0.35 * sin(_live_pulse * 5.2)
	draw_circle(jaw, 7.5, Color(LIVE_GLOW.r, LIVE_GLOW.g, LIVE_GLOW.b, 0.16 * pulse))
	draw_circle(jaw, 4.2, Color(LIVE_ARC.r, LIVE_ARC.g, LIVE_ARC.b, 0.34 * pulse))
	draw_circle(jaw, 2.0, Color(1.0, 1.0, 1.0, 0.72 * pulse))
	var flicker := sin(_live_pulse * 17.0)
	if flicker > 0.55:
		draw_line(
			jaw + Vector2(-3.5, -2.2),
			jaw + Vector2(1.5, 2.4),
			Color(LIVE_ARC.r, LIVE_ARC.g, LIVE_ARC.b, 0.85),
			1.2
		)


func _draw_number_tag(half: Vector2) -> void:
	# A stamped brass tag rather than floating text: the sequence is engraved on
	# the hardware, the way the rest of the castle labels itself.
	var tag := Rect2(-9.0, half.y - 16.0, 18.0, 10.0)
	draw_rect(Rect2(tag.position + Vector2(0.6, 1.0), tag.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(tag, BRASS_DARK)
	draw_rect(tag.grow(-1.0), BRASS_BODY)
	draw_line(tag.position + Vector2(1.0, 1.0), Vector2(tag.end.x - 1.0, tag.position.y + 1.0), BRASS_LIGHT, 1.0)
	var font := ThemeDB.fallback_font
	var size := 9
	var width := font.get_string_size(sequence_number, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := tag.position + Vector2((tag.size.x - width) * 0.5, tag.size.y * 0.5 + 3.5)
	# Engraved: a dark cut with a light lip below it.
	draw_string(font, baseline + Vector2(0.0, 0.8), sequence_number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, BRASS_HOT)
	draw_string(font, baseline, sequence_number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.153, 0.094, 0.031))


func _hinge_position(half: Vector2) -> Vector2:
	return Vector2(-half.x + 16.0, half.y - 22.0)


func _jaw_position(half: Vector2) -> Vector2:
	return Vector2(half.x - 16.0, half.y - 22.0)


func _blade_reach(half: Vector2) -> float:
	return _hinge_position(half).distance_to(_jaw_position(half)) + 2.0


## The tallest swing whose tip still clears the bezel, expressed as a negative
## angle because the blade lifts.
func _open_degrees() -> float:
	var half := plate_size * 0.5
	var bezel_top := -half.y + 9.5
	var rise: float = _hinge_position(half).y - (bezel_top + BLADE_TIP_MARGIN)
	var reach := _blade_reach(half)
	if reach <= 0.0:
		return 0.0
	return -rad_to_deg(asin(clampf(rise / reach, 0.0, 0.72)))
