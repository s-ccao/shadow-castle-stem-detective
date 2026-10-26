extends RefCounted

## The Library's living light for the Blender room prototype, staged with its
## HD look by tools/blender/prototype_room.gd. room_library.py renders the
## archive dormant (render.png) and awakened, its three filters seated
## (render-awakened.png), and writes render-library.json: where each window's
## moonlight falls, the light-test desks' lamps, the optical array and the
## floor medallion, in screen px. Staging adds:
##   - moonlight shafts falling from the windows, dust drifting down them;
##   - each light-test desk's lamp: dim while its test is dormant, brighter
##     once its knowledge is filed, steady once its filter is earned, with a
##     flare as it rises (library_room.gd's beacons keep their own reading);
##   - the awakening: once library_rgb_puzzle_solved is set and the game's own
##     ignition and reward card have played, the awakened archive spreads from
##     the optical array across the room while the camera draws back to show
##     all of it, then returns to the detective;
##   - the first time the Library loads, an establishing shot of the whole
##     archive under its title that glides down to the detective.
## A shot holds the detective and the room's prompts; any key or click skips it.
## It seats the game's knowledge and challenge markers on the HD cases and lets
## the HD optical plate show under the game's filters. Restoring puts it all
## back. Visual only: no flag, save or collision is touched.

const DATA := "res://prototypes/blender_rooms/library_room/"
const Glows := preload("res://tools/blender/prototype_glows.gd")
## The archive UI's title face (autoload/archive_ui.gd), crisp at whole multiples of 12.
const PIXEL_FONT := preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
const GOLD := Color(0.98, 0.82, 0.45)
const PARCHMENT := Color(0.95, 0.88, 0.70)
const BRASS := Color(0.78, 0.52, 0.18)
const VIOLET := Color(0.48, 0.27, 0.74)
const SOLVED_FLAG := "library_rgb_puzzle_solved"
## The game's optical stand draws a flat plinth, inlays and frames, which the HD
## plate takes over; its filters, beams, rings and light stay the game's own.
const STAND_FLAT_PARTS: Array[String] = [
	"StandShadow", "BrassOpticalPlinth", "WalnutInlay",
	"RedFilter/BrassFrame", "GreenFilter/BrassFrame", "BlueFilter/BrassFrame",
	"ArchiveOpticalScanner/ArchiveScannerHousing", "ArchiveOpticalScanner/ArchiveScannerInlay",
]
## Each light test's lamp: the flag its filter sets, the flag its knowledge sets.
const STATION_FLAGS: Dictionary = {
	"red": ["library_red_filter_earned", "library_spectrum_knowledge_learned"],
	"green": ["library_green_filter_earned", "library_reflection_knowledge_learned"],
	"blue": ["library_blue_filter_earned", "library_additive_knowledge_learned"],
}
const STATION_COLOURS: Dictionary = {
	"red": Color(1.0, 0.3, 0.22),
	"green": Color(0.36, 1.0, 0.46),
	"blue": Color(0.36, 0.56, 1.0),
}
## A lamp's halo: dormant, primed (its knowledge filed), solved (its filter earned).
const LAMP_LEVELS: Array[float] = [0.2, 0.5, 0.9]
const LAMP_RADIUS := 46.0
## A shaft's opacity at its window and where it lands.
const SHAFT_ALPHA: Dictionary = {
	"great": [0.075, 0.018], "spectrum": [0.15, 0.045], "rose": [0.06, 0.015],
}
const MOTES_PER_SHAFT: Dictionary = {"great": 16, "spectrum": 7, "rose": 10}
const ESTABLISH_HOLD := 1.1
const ESTABLISH_GLIDE := 2.2
const AWAKEN_DELAY := 0.8
## Seating the last filter files a clue, whose reward card the archive waits
## out (item_reward_hud.gd), but no longer than this.
const AWAKEN_WAIT_MAX := 5.0
const AWAKEN_SPREAD := 2.8
const AWAKEN_PULL := 1.1
const AWAKEN_HOLD := 0.5
const AWAKEN_RETURN := 1.3
## Any key skips a shot, but not one already held as the shot begins.
const SKIP_GRACE := 0.25
const REVEAL_SOFTNESS := 90.0
const REVEAL_SHADER := """
shader_type canvas_item;

uniform vec2 centre;
uniform vec2 size;
uniform float radius = 0.0;
uniform float softness = 90.0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float reach = distance(UV * size, centre);
	float shown = 1.0 - smoothstep(radius - softness, radius, reach);
	float front = abs(reach - radius + softness * 0.35);
	float rim = (1.0 - smoothstep(0.0, softness * 0.6, front)) * step(0.001, radius);
	colour.rgb += vec3(1.0, 0.95, 0.84) * rim * 0.35;
	colour.a *= max(shown, rim * 0.6);
	COLOR = colour;
}
"""

## Whether this run has shown the establishing shot (the first Library load).
static var established := false

var room: Node2D
var player: CharacterBody2D
var meta: Dictionary = {}
var render_scale := 2.0
var origin := Vector2.ZERO
var room_size := Vector2(1448.0, 1086.0)
var applied := false
## False keeps apply() from playing the establishing shot (the captures do).
var auto_establish := true
var clock := 0.0
var noise := FastNoiseLite.new()
var shafts_node: Node2D
var dust: Node2D
## {"window", "pool" (screen px), "colour", "kind", "polygon", "phase"} per shaft.
var shafts: Array[Dictionary] = []
## {"shaft", "s", "k", "t", "speed", "size", "phase", "wobble"} per mote of dust.
var motes: Array[Dictionary] = []
## colour name -> halo, and -> {"level", "alpha", "flare"}.
var lamp_halos: Dictionary = {}
var lamp_state: Dictionary = {}
var awakened: Sprite2D
var awakened_glows: Glows
var reveal: ShaderMaterial
var reveal_centre := Vector2.ZERO
var reveal_radius := 0.0
var reveal_max := 0.0
## "", "waiting" (the game's filter settles), "spreading" or "done".
var awakening := ""
var awakening_clock := 0.0
## CanvasItem -> its visibility before staging.
var stand_parts: Dictionary = {}
## Marker -> its position before staging.
var marker_positions: Dictionary = {}
var shot: Camera2D
## "", "establish" or "awaken".
var shot_kind := ""
var shot_clock := 0.0
var shot_from_position := Vector2.ZERO
var shot_from_zoom := Vector2.ONE
var shot_input_held := true
var title: CanvasLayer
var title_root: Control
## What a shot held: the detective's movement, the room's prompts (given back
## once every key is up).
var locked_player := false
var paused_input := false
var input_release_pending := false


## Loads the Library's light under `room_node`, hidden until apply(). `look` is
## the prototype_room.gd staging it, which holds this layer: only its render is
## read, so neither keeps the other alive. False without render-library.json.
func attach(room_node: Node, look: RefCounted) -> bool:
	room = room_node as Node2D
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(DATA + "render-library.json")
	)
	var overlay := look.get("overlay") as Sprite2D
	if room == null or overlay == null or not (parsed is Dictionary):
		push_warning("No Library light data under " + DATA)
		return false
	meta = parsed as Dictionary
	render_scale = 1.0 / overlay.scale.x
	origin = overlay.position
	room_size = overlay.texture.get_size() / render_scale
	player = room.find_child("player", true, false) as CharacterBody2D
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	var scanner: Array = meta.get("scanner", [724.0, 613.5])
	reveal_centre = Vector2(float(scanner[0]), float(scanner[1]))
	_build_shafts()
	_build_lamps()
	_build_awakened()
	return true


## Shows the light, seats the markers and plates, and the first time, the shot.
func apply() -> void:
	if not is_instance_valid(room):
		return
	applied = true
	shafts_node.visible = true
	for halo: Sprite2D in lamp_halos.values():
		halo.visible = true
	_flatten_stand(true)
	_seat_markers(true)
	var solved := _solved()
	if awakened != null:
		awakened.visible = solved
		_set_reveal(1.0e6 if solved else 0.0)
	awakening = "done" if solved else ""
	_refresh_lamps(0.0, true)
	if auto_establish and not established:
		established = true
		play_establishing_shot()


## Puts the scene back as it was: markers, the game's plate, the camera.
func restore() -> void:
	applied = false
	if not is_instance_valid(room):
		return
	_end_shot()
	_release_input()
	shafts_node.visible = false
	for halo: Sprite2D in lamp_halos.values():
		halo.visible = false
	if awakened != null:
		awakened.visible = false
	awakening = ""
	_flatten_stand(false)
	_seat_markers(false)


## The play loop keeps advancing a room's look after leaving it: nothing to do
## once the room is freed.
func advance(delta: float) -> void:
	if not applied or not is_instance_valid(room):
		return
	clock += delta
	if input_release_pending and not Input.is_anything_pressed():
		_release_input()
	_advance_shafts(delta)
	_refresh_lamps(delta, false)
	_advance_awakening(delta)
	_advance_shot(delta)
	if awakened_glows != null and awakened != null and awakened.visible:
		awakened_glows.advance(delta)


func summary() -> String:
	return "%d shafts, %d motes, %d lamps, awakened render %s" % [
		shafts.size(), motes.size(), lamp_halos.size(), awakened != null,
	]


## The whole archive, then a glide down to the detective.
func play_establishing_shot() -> void:
	_start_shot("establish")


## Ends a running shot as if it had played out.
func skip_shot() -> void:
	_end_shot()


func is_shot_running() -> bool:
	return shot != null


## The level a station's lamp shows: 0 dormant, 1 primed, 2 solved.
func station_level(colour_name: String) -> int:
	var flags: Array = STATION_FLAGS[colour_name]
	if _has_flag(str(flags[0])) or _solved():
		return 2
	if _has_flag(str(flags[1])):
		return 1
	return 0


func _build_shafts() -> void:
	shafts_node = Node2D.new()
	shafts_node.name = "LibraryMoonShafts"
	shafts_node.z_as_relative = false
	# Over the figures (light in the air), under the game's markers (24).
	shafts_node.z_index = 22
	shafts_node.visible = false
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shafts_node.material = additive
	room.add_child(shafts_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	for entry: Dictionary in meta.get("shafts", []):
		var window := _points(entry["window"])
		var landing := _points(entry["pool"])
		var tint: Array = entry["color"]
		var colour := Color(float(tint[0]), float(tint[1]), float(tint[2]))
		var kind := str(entry["kind"])
		var alphas: Array = SHAFT_ALPHA.get(kind, [0.06, 0.015])
		var polygon := _shaft_polygon(window, landing, colour, alphas)
		polygon.use_parent_material = true
		shafts_node.add_child(polygon)
		shafts.append({
			"window": window, "pool": landing, "colour": colour, "kind": kind,
			"polygon": polygon, "phase": rng.randf() * 100.0,
		})
		for _mote: int in range(int(MOTES_PER_SHAFT.get(kind, 8))):
			motes.append({
				"shaft": shafts.size() - 1, "s": rng.randf(), "k": rng.randf(), "t": rng.randf(),
				"speed": rng.randf_range(0.015, 0.04), "size": rng.randf_range(0.6, 1.5),
				"phase": rng.randf() * TAU, "wobble": rng.randf_range(0.6, 1.6),
			})
	dust = Node2D.new()
	dust.name = "LibraryDust"
	dust.use_parent_material = true
	shafts_node.add_child(dust)
	dust.draw.connect(_draw_dust)


## The shaft between a window and where its light lands, on screen: their hull,
## bright at the window and fading as it falls.
func _shaft_polygon(
	window: PackedVector2Array, landing: PackedVector2Array, colour: Color, alphas: Array
) -> Polygon2D:
	var points := PackedVector2Array()
	points.append_array(window)
	points.append_array(landing)
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	var top := window[0].y
	var bottom := top
	for point: Vector2 in landing:
		bottom = maxf(bottom, point.y)
	var colours := PackedColorArray()
	for point: Vector2 in hull:
		var along := clampf(inverse_lerp(top, maxf(bottom, top + 1.0), point.y), 0.0, 1.0)
		var alpha := lerpf(float(alphas[0]), float(alphas[1]), along)
		colours.append(Color(colour.r, colour.g, colour.b, alpha))
	var polygon := Polygon2D.new()
	polygon.polygon = hull
	polygon.vertex_colors = colours
	return polygon


## A point in a shaft: `s` across its window, `k` up it (0 its sill, 1 its
## head), `t` along the light from the window (0) to where it lands (1).
func _beam_point(shaft: Dictionary, s: float, k: float, t: float) -> Vector2:
	var window: PackedVector2Array = shaft["window"]
	var landing: PackedVector2Array = shaft["pool"]
	var source := window[3].lerp(window[2], s).lerp(window[0].lerp(window[1], s), k)
	var target := landing[3].lerp(landing[2], s).lerp(landing[0].lerp(landing[1], s), k)
	return source.lerp(target, t)


func _advance_shafts(delta: float) -> void:
	for shaft: Dictionary in shafts:
		var polygon := shaft["polygon"] as Polygon2D
		var breath := noise.get_noise_2d(clock * 0.12, float(shaft["phase"]))
		polygon.modulate.a = 0.82 + 0.18 * breath
	for mote: Dictionary in motes:
		mote["t"] = fmod(float(mote["t"]) + float(mote["speed"]) * delta, 1.0)
		var drift := noise.get_noise_2d(clock * 0.3, float(mote["phase"]) * 10.0)
		mote["s"] = clampf(float(mote["s"]) + drift * delta * 0.05, 0.0, 1.0)
	dust.queue_redraw()


func _draw_dust() -> void:
	for mote: Dictionary in motes:
		var shaft: Dictionary = shafts[int(mote["shaft"])]
		var t := float(mote["t"])
		var point := _beam_point(shaft, float(mote["s"]), float(mote["k"]), t)
		var twinkle := 0.5 + 0.5 * sin(clock * float(mote["wobble"]) * 2.0 + float(mote["phase"]))
		var fade := sin(PI * t) * (1.0 - t * 0.6)
		var colour: Color = shaft["colour"]
		var tint := Color(
			lerpf(1.0, colour.r, 0.45), lerpf(0.96, colour.g, 0.45), lerpf(0.9, colour.b, 0.45),
			0.55 * twinkle * fade
		)
		dust.draw_circle(point, float(mote["size"]), tint)


func _build_lamps() -> void:
	var lamps: Dictionary = meta.get("lamps", {})
	for colour_name: String in STATION_FLAGS:
		if not lamps.has(colour_name):
			continue
		var at: Array = lamps[colour_name]
		var halo := Sprite2D.new()
		halo.name = "LibraryStationLamp_" + colour_name
		halo.texture = OpticalFxRuntime.radial_glow_texture()
		halo.material = OpticalFxRuntime.additive_material()
		halo.position = Vector2(float(at[0]), float(at[1]))
		halo.scale = Vector2.ONE * LAMP_RADIUS / 64.0
		halo.z_as_relative = false
		halo.z_index = 21
		halo.visible = false
		var colour: Color = STATION_COLOURS[colour_name]
		halo.modulate = Color(colour.r, colour.g, colour.b, 0.0)
		room.add_child(halo)
		lamp_halos[colour_name] = halo
		lamp_state[colour_name] = {"level": -1, "alpha": 0.0, "flare": 0.0}


## Each lamp eases to its level; rising a level, it flares first.
func _refresh_lamps(delta: float, instant: bool) -> void:
	for colour_name: String in lamp_halos:
		var halo := lamp_halos[colour_name] as Sprite2D
		var state: Dictionary = lamp_state[colour_name]
		var level := station_level(colour_name)
		var target: float = LAMP_LEVELS[level]
		if instant or int(state["level"]) < 0:
			state["alpha"] = target
			state["flare"] = 0.0
		else:
			if level > int(state["level"]):
				state["flare"] = 1.0
			state["alpha"] = move_toward(float(state["alpha"]), target, delta * 0.8)
			state["flare"] = maxf(float(state["flare"]) - delta * 0.9, 0.0)
		state["level"] = level
		var flicker := 0.06 * noise.get_noise_2d(clock * 2.4, halo.position.x)
		var flare := float(state["flare"])
		halo.modulate.a = clampf(float(state["alpha"]) + flare * 0.6 + flicker, 0.0, 1.0)
		halo.scale = Vector2.ONE * LAMP_RADIUS * (1.0 + flare * 0.45) / 64.0


func _build_awakened() -> void:
	var path := DATA + "render-awakened.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_warning("No awakened Library render at " + path)
		return
	awakened = Sprite2D.new()
	awakened.name = "BlenderLibraryAwakened"
	awakened.texture = ImageTexture.create_from_image(image)
	awakened.centered = false
	awakened.position = origin
	awakened.scale = Vector2.ONE / render_scale
	awakened.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Over the dormant render (-40) and its halos (-39).
	awakened.z_index = -38
	awakened.visible = false
	var shader := Shader.new()
	shader.code = REVEAL_SHADER
	reveal = ShaderMaterial.new()
	reveal.shader = shader
	reveal.set_shader_parameter("size", Vector2(image.get_width(), image.get_height()))
	reveal.set_shader_parameter("centre", (reveal_centre - origin) * render_scale)
	reveal.set_shader_parameter("softness", REVEAL_SOFTNESS * render_scale)
	awakened.material = reveal
	room.add_child(awakened)
	awakened_glows = Glows.new()
	awakened_glows.attach(awakened, DATA + "render-awakened-glows.json", origin, render_scale)
	for corner: Vector2 in [
		origin, origin + Vector2(room_size.x, 0.0), origin + room_size,
		origin + Vector2(0.0, room_size.y),
	]:
		reveal_max = maxf(reveal_max, reveal_centre.distance_to(corner))
	reveal_max += REVEAL_SOFTNESS * 1.5


## The awakened archive shows within `radius` px of the optical array, and so
## do its halos.
func _set_reveal(radius: float) -> void:
	reveal_radius = radius
	if reveal != null:
		reveal.set_shader_parameter("radius", radius * render_scale)
	if awakened_glows == null:
		return
	for halo: Sprite2D in awakened_glows.halos:
		var at := origin + halo.position / render_scale
		halo.visible = at.distance_to(reveal_centre) < radius


func _advance_awakening(delta: float) -> void:
	if awakened == null:
		return
	if not _solved():
		if awakening != "":
			awakening = ""
			awakened.visible = false
			_set_reveal(0.0)
		return
	if awakening == "":
		awakening = "waiting"
		awakening_clock = 0.0
	awakening_clock += delta
	if (
		awakening == "waiting" and awakening_clock >= AWAKEN_DELAY
		and (not _card_showing() or awakening_clock >= AWAKEN_WAIT_MAX)
	):
		awakening = "spreading"
		awakening_clock = 0.0
		awakened.visible = true
		_start_shot("awaken")
	if awakening == "spreading":
		# Gathering at the array, sweeping the room as the camera opens, settling.
		var t := clampf(awakening_clock / AWAKEN_SPREAD, 0.0, 1.0)
		_set_reveal(reveal_max * _smooth(t))
		if t >= 1.0:
			awakening = "done"
			_set_reveal(1.0e6)


## Whether the game's reward card (ItemRewardHud) is up or has another queued.
func _card_showing() -> bool:
	var hud := room.get_node_or_null("/root/ItemRewardHud")
	if hud == null:
		return false
	var panel := hud.get("_panel") as CanvasItem
	var queued: Variant = hud.get("_queue")
	return (panel != null and panel.visible) or (queued is Array and not (queued as Array).is_empty())


func _start_shot(kind: String) -> void:
	var follow := _follow_camera()
	if follow == null or not room.is_inside_tree():
		return
	_end_shot()
	shot = Camera2D.new()
	shot.name = "LibraryShotCamera"
	room.add_child(shot)
	shot_kind = kind
	shot_clock = 0.0
	shot_input_held = Input.is_anything_pressed()
	if kind == "establish":
		shot.zoom = _fit_zoom()
		shot.global_position = origin + room_size / 2.0
	else:
		shot.zoom = follow.zoom
		shot.global_position = follow.get_screen_center_position()
	shot_from_position = shot.global_position
	shot_from_zoom = shot.zoom
	shot.make_current()
	_hold_room()
	if kind == "establish":
		_show_title()


## The establishing shot holds on the whole archive, then glides down to the
## detective. The awakening draws back to the whole archive while its light
## spreads, holds, and returns.
func _advance_shot(delta: float) -> void:
	if shot == null:
		return
	shot_clock += delta
	var follow := _follow_camera()
	if follow == null or _skip_pressed():
		_end_shot()
		return
	var home := _home(follow)
	if shot_kind == "establish":
		var glide := clampf((shot_clock - ESTABLISH_HOLD) / ESTABLISH_GLIDE, 0.0, 1.0)
		var t := _smooth(glide)
		_frame(shot_from_position.lerp(home, t), shot_from_zoom.lerp(follow.zoom, t))
		if title_root != null:
			title_root.modulate.a = minf(shot_clock / 0.5, 1.0) * clampf(1.0 - glide * 2.2, 0.0, 1.0)
		if glide >= 1.0:
			_end_shot()
		return
	var whole := origin + room_size / 2.0
	var fit := _fit_zoom()
	var hold_end := AWAKEN_PULL + AWAKEN_SPREAD + AWAKEN_HOLD
	if shot_clock < AWAKEN_PULL:
		var t := _smooth(shot_clock / AWAKEN_PULL)
		_frame(shot_from_position.lerp(whole, t), shot_from_zoom.lerp(fit, t))
	elif shot_clock < hold_end:
		_frame(whole, fit)
	else:
		var back := clampf((shot_clock - hold_end) / AWAKEN_RETURN, 0.0, 1.0)
		var t := _smooth(back)
		_frame(whole.lerp(home, t), fit.lerp(follow.zoom, t))
		if back >= 1.0:
			_end_shot()


func _frame(centre: Vector2, zoom: Vector2) -> void:
	shot.zoom = zoom
	shot.global_position = _clamped(centre, zoom)


## Hands the view back to the room's follow camera, settled on the detective.
func _end_shot() -> void:
	if shot != null and is_instance_valid(shot):
		var follow := _follow_camera()
		if follow != null and follow.is_inside_tree():
			follow.make_current()
			follow.reset_smoothing()
		shot.queue_free()
	shot = null
	shot_kind = ""
	if title != null and is_instance_valid(title):
		title.queue_free()
	title = null
	title_root = null
	_free_room()


func _skip_pressed() -> bool:
	var pressed := Input.is_anything_pressed()
	var rising := pressed and not shot_input_held and shot_clock > SKIP_GRACE
	shot_input_held = pressed
	return rising


## While a shot plays the detective stands still and the room takes no
## interaction. Only what this held is given back.
func _hold_room() -> void:
	if _player_valid() and not bool(player.get("movement_locked")):
		player.call("set_movement_locked", true)
		locked_player = true
	if bool(room.get("room_input_enabled")):
		room.set("room_input_enabled", false)
		paused_input = true
	input_release_pending = false


## The detective walks again at once; the room's prompts wait until every key is
## up, so the key that skipped the shot does not also act in the room.
func _free_room() -> void:
	if locked_player:
		locked_player = false
		if _player_valid() and bool(player.get("movement_locked")):
			player.call("set_movement_locked", false)
	if paused_input:
		input_release_pending = true


func _release_input() -> void:
	input_release_pending = false
	if not paused_input:
		return
	paused_input = false
	if is_instance_valid(room) and not bool(room.get("room_input_enabled")):
		room.set("room_input_enabled", true)


func _player_valid() -> bool:
	return (
		player != null and is_instance_valid(player) and player.has_method("set_movement_locked")
	)


## The establishing shot's title, in the archive's pixel face, gold and
## parchment over a violet-brass rule, low on the dark stone of the south wall
## so the spectrum window stays clear above it.
func _show_title() -> void:
	var chinese := false
	var locale := room.get_node_or_null("/root/CaseLocale")
	if locale != null and locale.has_method("is_chinese"):
		chinese = bool(locale.call("is_chinese"))
	var view := _view_size()
	title = CanvasLayer.new()
	title.name = "LibraryEstablishingTitle"
	title.layer = 40
	room.add_child(title)
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.modulate.a = 0.0
	title.add_child(title_root)
	var shade := Gradient.new()
	shade.set_color(0, Color(0.02, 0.01, 0.03, 0.0))
	shade.set_color(1, Color(0.02, 0.01, 0.03, 0.0))
	shade.add_point(0.5, Color(0.02, 0.01, 0.03, 0.62))
	var scrim_texture := GradientTexture2D.new()
	scrim_texture.gradient = shade
	scrim_texture.width = 64
	scrim_texture.height = 4
	var scrim := TextureRect.new()
	scrim.texture = scrim_texture
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.position = Vector2(round(view.x / 2.0 - 300.0), view.y - 116.0)
	scrim.size = Vector2(600.0, 96.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(scrim)
	var heading := _title_label(
		"光之档案馆" if chinese else "THE ARCHIVE OF LIGHT", 36, view.y - 110.0
	)
	heading.add_theme_color_override("font_color", GOLD)
	title_root.add_child(heading)
	for rule: Array in [[BRASS, 300.0, 0.0], [Color(VIOLET, 0.8), 180.0, 3.0]]:
		var line := ColorRect.new()
		line.color = rule[0]
		line.position = Vector2(round((view.x - float(rule[1])) / 2.0), view.y - 58.0 + float(rule[2]))
		line.size = Vector2(float(rule[1]), 1.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_root.add_child(line)
	var subtitle := _title_label(
		"阿什福德城堡 · 图书馆" if chinese else "ASHFORD CASTLE  ·  LIBRARY", 12, view.y - 48.0
	)
	subtitle.add_theme_color_override("font_color", PARCHMENT)
	title_root.add_child(subtitle)
	var hint := _title_label("任意键跳过" if chinese else "ANY KEY  ·  SKIP", 12, view.y - 28.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size.x = view.x - 18.0
	hint.add_theme_color_override("font_color", Color(PARCHMENT, 0.55))
	title_root.add_child(hint)


func _title_label(text: String, font_size: int, top: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0.0, top)
	label.size = Vector2(_view_size().x, float(font_size) + 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 4 if font_size > 12 else 3)
	return label


## The game draws its markers over its painted cases; staging seats them on the
## HD ones, as library_room.gd placed them (16 and 18 px over the case's top).
func _seat_markers(hd: bool) -> void:
	var script := room.get_script() as Script
	if script == null:
		return
	var constants := script.get_script_constant_map()
	var shelves: Dictionary = constants.get("KNOWLEDGE_SHELVES", {})
	var stations: Dictionary = constants.get("CHALLENGE_STATIONS", {})
	var shelf_markers: Variant = room.get("knowledge_shelf_markers")
	var station_markers: Variant = room.get("challenge_station_markers")
	if shelf_markers is Dictionary:
		for item: String in shelves:
			var marker: Variant = shelf_markers.get(str(shelves[item]["knowledge"]))
			_seat(marker as Node2D, item, 16.0, hd)
	if station_markers is Dictionary:
		for item: String in stations:
			var marker: Variant = station_markers.get(str(stations[item]["challenge"]))
			_seat(marker as Node2D, item, 18.0, hd)
	if not hd:
		marker_positions.clear()


func _seat(marker: Node2D, item: String, lift: float, hd: bool) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	if not hd:
		if marker_positions.has(marker):
			marker.position = marker_positions[marker]
		return
	if not marker_positions.has(marker):
		marker_positions[marker] = marker.position
	var rect: Rect2 = room.call("get_library_interaction_rect", item)
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		marker.position = Vector2(rect.get_center().x, rect.position.y - lift)


func _flatten_stand(hd: bool) -> void:
	var stand := room.get("rgb_filter_stand") as Node2D
	if stand == null:
		return
	for path: String in STAND_FLAT_PARTS:
		var part := stand.get_node_or_null(path) as CanvasItem
		if part == null:
			continue
		if hd:
			if not stand_parts.has(part):
				stand_parts[part] = part.visible
			part.visible = false
		elif stand_parts.has(part):
			part.visible = bool(stand_parts[part])
	if not hd:
		stand_parts.clear()


func _follow_camera() -> Camera2D:
	var runtime: Variant = room.get("interaction_runtime")
	if runtime == null or not is_instance_valid(runtime):
		return null
	return (runtime as Node).get("follow_camera") as Camera2D


func _view_size() -> Vector2:
	return room.get_viewport().get_visible_rect().size


func _fit_zoom() -> Vector2:
	var view := _view_size()
	return Vector2.ONE * minf(view.x / room_size.x, view.y / room_size.y)


## Where the room's follow camera holds the view: on the detective (it is the
## detective's child), within its limits.
func _home(follow: Camera2D) -> Vector2:
	var half := _view_size() / follow.zoom / 2.0
	var at := follow.global_position + follow.offset
	var left := float(follow.limit_left) + half.x
	var top := float(follow.limit_top) + half.y
	return Vector2(
		clampf(at.x, left, maxf(float(follow.limit_right) - half.x, left)),
		clampf(at.y, top, maxf(float(follow.limit_bottom) - half.y, top))
	)


## `centre` moved so a camera there at `zoom` shows only the room.
func _clamped(centre: Vector2, zoom: Vector2) -> Vector2:
	var half := _view_size() / zoom / 2.0
	return Vector2(
		clampf(centre.x, origin.x + half.x, origin.x + maxf(room_size.x - half.x, half.x)),
		clampf(centre.y, origin.y + half.y, origin.y + maxf(room_size.y - half.y, half.y))
	)


func _smooth(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _solved() -> bool:
	return _has_flag(SOLVED_FLAG)


func _has_flag(flag: String) -> bool:
	var state := room.get_node_or_null("/root/GameState")
	return state != null and bool(state.call("has_story_flag", flag))


func _points(source: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Array in source:
		points.append(Vector2(float(point[0]), float(point[1])))
	return points
