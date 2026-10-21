extends SceneTree

## Offline Hall prop pixelizer: rebuilds assets/props/hall_pixel/ from the
## project's existing AI-generated Hall prop PNGs. Sources are only read.
##
## Usage, from the checkout root (isolated HOME keeps user:// away from saves):
##   mkdir -p .godot/hall-props-home
##   HOME="$PWD/.godot/hall-props-home" <godot> --headless --path . \
##     --script res://tools/pixelize_hall_props.gd [-- --contact-sheet]
## then import the new PNGs (lossless, no mipmaps, see manifest.json):
##   HOME="$PWD/.godot/hall-props-home" <godot> --headless --editor --path . --quit
##
## Per prop: backdrop-margin flood fill (where a source has an opaque box) ->
## removal of enclosed paper-white generator remnants -> crop to the opaque
## object -> exact area-average downsample (linear light, premultiplied alpha)
## to visible world size / 1.25 -> binary alpha at 0.5 -> gentle OKLab clarity
## -> brass/violet/parchment harmonisation -> 1 px selective dark outline ->
## deterministic median-cut + k-means palette from the cleaned source pixels,
## mapped without dithering, then low-contrast single-pixel cleanup.
## Placement keeps each object's world bottom-centre (RoomSpatialRuntime's
## visual feet); the Sprite2D values used in wall_collisions.tscn are printed
## and recorded in manifest.json.
## Options after --: --contact-sheet writes the old-vs-new evidence sheet;
## --debug-dir=<abs dir> saves each cleaned full-size source for inspection.

const OUTPUT_DIR := "res://assets/props/hall_pixel/"
const SHEET_PATH := "res://docs/evidence/2026-10-21-hall-visual/props/contact-sheet.png"
const WALLS_SOURCE := "res://assets/backgrounds/hall_walls.png"
const SHADOW_FILE := "hall_contact_shadow.png"
const TEXEL_WORLD := 1.25
const ALPHA_CUTOFF := 0.5
const VISIBLE_ALPHA_8BIT := 12 # alpha / 255 > RoomSpatialRuntime.VISIBLE_ALPHA_THRESHOLD (0.05)
const HUE_WEIGHT := 1.25
const OUTLINE_BASE := Color("#140c18")
const SHADOW_TONE := Color("#33243d")
const HIGHLIGHT_TONE := Color("#ead9b3")
const SHADOW_TINT := 0.3
const HIGHLIGHT_TINT := 0.25
const BLACK_LIFT := 0.5
const CHROMA_GAIN := 1.1
const OUTLINE_KEEP := 0.3
const THIN_KEEP := 0.6
const BASE_KEEP := 0.5
const KMEANS_ITERATIONS := 10
const LOCAL_CONTRAST := 0.3
const NEUTRAL_CHROMA := 0.07
const DESPECKLE_DELTA := 0.09
const DESPECKLE_MIN_VOTES := 5
const LOCAL_CONTRAST_RADIUS := 3
const MEDIAN_CUT_POPULATION := 0.3
const SOURCE_PALETTE_SAMPLES := 12000
const OUTLINE_COLORS := 4
const REMNANT_WHITE_MIN := 228
const REMNANT_WHITE_SPREAD := 24
const REMNANT_FRINGE_MIN := 110
const REMNANT_FRINGE_SPREAD := 40
const REMNANT_FRINGE_PX := 3
const REMNANT_MIN_PX := 40
const REMNANT_SURROUND_MAX := 120.0
const CONTACT_SHADOW_ALPHA := 0.6
const CONTACT_SHADOW_CORE := 0.45
const CONTACT_SHADOW_SIZES: Array[Vector2i] = [
	Vector2i(16, 6), Vector2i(24, 8), Vector2i(32, 8), Vector2i(40, 8),
	Vector2i(56, 10), Vector2i(72, 10), Vector2i(96, 12), Vector2i(120, 12),
]
const PREVIEW_FLOOR := Color("#242320")
const SHEET_BACKGROUND := Color("#120e16")
const SHEET_LABEL := Color("#ead9b3")
const SHEET_RULE := Color("#594066")
const BACKDROP_RULE := {
	"dark_channel": 16, "dark_fraction": 0.9, "min_coverage": 0.25, "min_margin": 16,
	"frame_min": 40, "frame_max": 160, "frame_saturation": 0.1,
	"min_island": 300,
}
## Sprite2D layout authored in scenes/wall_collisions.tscn before this pass
## (commit 11cce2d); it defines each object's visible size and visual feet.
## fit: "uniform" keeps the scale, "width" keeps the visible width,
## "area_or_width" keeps the visible area unless that covers noticeably more
## painted wall than before, then keeps the width.
const PROPS: Array[Dictionary] = [
	{
		"id": "storage_rack", "node": "StorageRack/RackSprite",
		"source": "res://assets/props/Hall/storage_rack_final.png",
		"parent": Vector2(1587, 967), "position": Vector2(2.9999847, -47),
		"scale": Vector2(0.08, 0.08), "centered": false, "old_filter": "linear",
		"fit": "uniform", "backdrop": false, "colors": 22, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "final_key_machine_1", "node": "FinalKeyMachine1/M1Sprite",
		"source": "res://assets/props/Hall/final_key_machine_1.png",
		"parent": Vector2(222, 528), "position": Vector2(-17.999992, -42.000015),
		"scale": Vector2(0.08211683, 0.07580176), "centered": false, "old_filter": "linear",
		"fit": "width", "backdrop": true, "colors": 22, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "final_key_machine_2", "node": "FinalKeyMachine2/M2Sprite",
		"source": "res://assets/props/Hall/final_key_machine_2.png",
		"parent": Vector2(1443, 131), "position": Vector2(-117.00001, -69),
		"scale": Vector2(0.107919216, 0.10509031), "centered": false, "old_filter": "linear",
		"fit": "width", "backdrop": false, "colors": 22, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "final_key_machine_3", "node": "FinalKeyMachine3/M3Sprite",
		"source": "res://assets/props/Hall/final_key_machine_3.png",
		"parent": Vector2(1187, 1028), "position": Vector2(-77.000046, -32.000023),
		"scale": Vector2(0.14365883, 0.13870242), "centered": false, "old_filter": "linear",
		"fit": "width", "backdrop": false, "colors": 22, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "library_console", "node": "KnowledgeExhibits/LibraryRoomKnowledge/Sprite",
		"source": "res://assets/props/hall_knowledge/hall_knowledge_glowing_console.png",
		"parent": Vector2(1552, 260), "position": Vector2(0, -52),
		"scale": Vector2(0.0677, 0.0677), "centered": true, "old_filter": "nearest",
		"fit": "uniform", "backdrop": false, "colors": 18, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "dining_clock", "node": "KnowledgeExhibits/DiningHallKnowledge/Sprite",
		"source": "res://assets/props/DiningHall/dining_grandfather_clock.png",
		"parent": Vector2(1680, 738), "position": Vector2(176.99997, 90.00007),
		"scale": Vector2(0.06989866, 0.069898546), "centered": true, "old_filter": "nearest",
		"fit": "uniform", "backdrop": false, "colors": 20, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "circuit_gauge", "node": "KnowledgeExhibits/CircuitRoomKnowledge/Sprite",
		"source": "res://assets/props/hall_knowledge/hall_knowledge_gauge_machine.png",
		"parent": Vector2(187, 627), "position": Vector2(-106.4156, 334.2484),
		"scale": Vector2(0.07307733, 0.084958896), "centered": true, "old_filter": "nearest",
		"fit": "area_or_width", "backdrop": false, "colors": 20, "clarity": 0.6, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "greenhouse_construct", "node": "KnowledgeExhibits/GreenhouseRoomKnowledge/Sprite",
		"source": "res://assets/props/hall_knowledge/hall_knowledge_green_construct.png",
		"parent": Vector2(301, 334), "position": Vector2(0, -52),
		"scale": Vector2(0.0677, 0.0677), "centered": true, "old_filter": "nearest",
		"fit": "uniform", "backdrop": false, "colors": 20, "clarity": 0.3, "lift": 0.0, "chroma": 1.0,
	},
	{
		"id": "chemistry_core", "node": "KnowledgeExhibits/ChemistryRoomKnowledge/Sprite",
		"source": "res://assets/props/hall_knowledge/hall_knowledge_bronze_core.png",
		"parent": Vector2(419, 139), "position": Vector2(207.16881, 334.9984),
		"scale": Vector2(0.07193596, 0.11067501), "centered": true, "old_filter": "nearest",
		"fit": "area_or_width", "backdrop": false, "colors": 20, "clarity": 0.6, "lift": 0.15, "chroma": 1.25,
	},
]
const FONT := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
	"D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111",
	"J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
	"P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
	"V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111",
	"1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	"4": "101101111001001", "5": "111100110001110", "6": "011100111101111",
	"7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
	"_": "000000000000111", "-": "000000111000000", ".": "000000000000010",
	":": "000010000010000", "/": "001001010100100", "(": "010100100100010",
	")": "010001001001010", "=": "000111000111000", "+": "000010111010000",
	",": "000000000010100",
}

var _linear_lut := PackedFloat32Array()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_linear_lut.resize(256)
	for value: int in range(256):
		var encoded := value / 255.0
		_linear_lut[value] = (
			encoded / 12.92 if encoded <= 0.04045
			else pow((encoded + 0.055) / 1.055, 2.4)
		)
	DirAccess.make_dir_recursive_absolute(_absolute(OUTPUT_DIR))
	var walls := _load_rgba(WALLS_SOURCE)
	var atlas := _build_contact_shadow_atlas()
	_save_png(atlas["image"], OUTPUT_DIR + SHADOW_FILE)
	var results: Array[Dictionary] = []
	for spec: Dictionary in PROPS:
		var result := _build_prop(spec, walls, atlas)
		results.append(result)
		_print_layout(result)
	_write_manifest(results, atlas)
	if OS.get_cmdline_user_args().has("--contact-sheet"):
		_write_contact_sheet(results, atlas)
	print("pixelize_hall_props: wrote %d props + contact shadow" % results.size())
	quit(0)


# --- Per-prop pipeline -------------------------------------------------------

func _build_prop(spec: Dictionary, walls: Image, atlas: Dictionary) -> Dictionary:
	var original := _load_rgba(spec["source"])
	var size := original.get_size()
	var scan := _scan_backdrop(original)
	var source := original
	var removed := 0
	var islands := 0
	if spec["backdrop"]:
		source = original.duplicate() as Image
		removed = _clear_mask(source, scan["mask"])
		islands = _remove_islands(source, int(BACKDROP_RULE["min_island"]))
	# The player saw everything except a removed backdrop: that defines the feet.
	var seen_bounds := _opaque_bounds(source)
	if source == original:
		source = original.duplicate() as Image
	var remnants := _remove_white_remnants(source)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--debug-dir="):
			source.save_png(argument.trim_prefix("--debug-dir=").path_join(str(spec["id"]) + "_cleaned.png"))
	var bounds := _opaque_bounds(source)
	var runtime_bounds := _opaque_bounds(original)
	var old_scale: Vector2 = spec["scale"]
	var origin := _old_origin(spec, size)
	var old_rect := Rect2(
		origin + Vector2(seen_bounds.position) * old_scale, Vector2(seen_bounds.size) * old_scale
	)
	var runtime_rect := Rect2(
		origin + Vector2(runtime_bounds.position) * old_scale, Vector2(runtime_bounds.size) * old_scale
	)
	var feet := Vector2(old_rect.get_center().x, old_rect.end.y)

	var candidates := {}
	for fit: String in ["width", "area"]:
		var scale := old_scale.x if fit == "width" else sqrt(old_scale.x * old_scale.y)
		var plan := _plan_downsample(bounds, scale)
		var coverage := _area_downsample(source, plan["crop"], plan["width"], plan["height"])
		var mask := _binary_mask(coverage, plan["width"] * plan["height"])
		var top_left := _snapped_top_left(feet, plan["width"], plan["height"])
		candidates[fit] = {
			"scale": scale, "plan": plan, "top_left": top_left,
			"wall_overlap": _wall_overlap_new(mask, plan["width"], plan["height"], top_left, walls),
		}
	var old_overlap := _wall_overlap_old(original, origin, old_scale, runtime_rect, walls)
	var fit_mode: String = spec["fit"]
	var chosen := "uniform" if fit_mode == "uniform" else "width"
	if fit_mode == "area_or_width":
		var area_overlap: int = candidates["area"]["wall_overlap"]
		var noticeable := area_overlap > old_overlap + maxi(40, int(old_overlap * 0.2))
		chosen = "width" if noticeable else "area"
	var choice: Dictionary = candidates["width" if chosen == "uniform" else chosen]
	var plan: Dictionary = choice["plan"]
	var texels := _area_downsample(source, plan["crop"], plan["width"], plan["height"])
	var art := _stylize(texels, plan["width"], plan["height"], spec, source, plan["crop"])
	var image: Image = art["image"]
	var art_bounds := _opaque_bounds(image)
	image = image.get_region(art_bounds)
	var output_path := OUTPUT_DIR + str(spec["id"]) + "_pixel.png"
	_save_png(image, output_path)

	var texture_size := image.get_size()
	var runtime_feet := Vector2(runtime_rect.get_center().x, runtime_rect.end.y)
	var top_left := _best_lattice_top_left(feet, runtime_feet, texture_size)
	var new_rect := Rect2(top_left, Vector2(texture_size) * TEXEL_WORLD)
	var new_feet := Vector2(new_rect.get_center().x, new_rect.end.y)
	var parent: Vector2 = spec["parent"]
	var local_position := top_left - parent
	if spec["centered"]:
		local_position += Vector2(texture_size) * TEXEL_WORLD * 0.5
	var shadow := _place_contact_shadow(image, spec["centered"], atlas)
	var new_mask := _binary_mask_from_image(image)
	return {
		"spec": spec,
		"output": output_path,
		"source_size": size,
		"backdrop_scan": scan["summary"],
		"backdrop_removed": removed,
		"islands_removed": islands,
		"remnants": remnants,
		"object_bounds": bounds,
		"seen_bounds": seen_bounds,
		"runtime_bounds": runtime_bounds,
		"old_origin": origin,
		"old_rect": old_rect,
		"runtime_rect": runtime_rect,
		"feet": feet,
		"runtime_feet": runtime_feet,
		"fit": chosen,
		"effective_scale": choice["scale"],
		"source_px_per_texel": TEXEL_WORLD / float(choice["scale"]),
		"crop": plan["crop"],
		"downsample_size": Vector2i(plan["width"], plan["height"]),
		"texture_size": texture_size,
		"palette": art["palette"],
		"palette_count": art["palette_count"],
		"top_left": top_left,
		"new_rect": new_rect,
		"new_feet": new_feet,
		"local_position": local_position,
		"shadow": shadow,
		"old_wall_overlap": old_overlap,
		"new_wall_overlap": _wall_overlap_new(new_mask, texture_size.x, texture_size.y, top_left, walls),
		"candidates": candidates,
		"image": image,
		"original": original,
		"cleaned": source,
	}


func _old_origin(spec: Dictionary, size: Vector2i) -> Vector2:
	var origin: Vector2 = spec["parent"] + spec["position"]
	if spec["centered"]:
		origin -= Vector2(size) * (spec["scale"] as Vector2) * 0.5
	return origin


func _plan_downsample(bounds: Rect2i, scale: float) -> Dictionary:
	var step := TEXEL_WORLD / scale
	var width := maxi(1, roundi(bounds.size.x / step))
	var height := maxi(1, roundi(bounds.size.y / step))
	var centre_x := bounds.position.x + bounds.size.x * 0.5
	var crop := Rect2(
		centre_x - width * step * 0.5, bounds.end.y - height * step, width * step, height * step
	)
	return {"crop": crop, "width": width, "height": height}


## Top-left on the walls' 1.25 texel lattice whose bottom-centre is nearest the feet.
func _snapped_top_left(feet: Vector2, width: int, height: int) -> Vector2:
	var desired := feet - Vector2(width * 0.5, height) * TEXEL_WORLD
	return (desired / TEXEL_WORLD).round() * TEXEL_WORLD


## Of the four surrounding lattice points, keep the one whose feet stay closest
## to both the object's feet and the feet RoomSpatialRuntime measured before
## (they differ only where a backdrop was removed).
func _best_lattice_top_left(feet: Vector2, runtime_feet: Vector2, size: Vector2i) -> Vector2:
	var offset := Vector2(size.x * 0.5, size.y) * TEXEL_WORLD
	var lattice := (feet - offset) / TEXEL_WORLD
	var best := Vector2.ZERO
	var best_error := INF
	for x: float in [floorf(lattice.x), ceilf(lattice.x)]:
		for y: float in [floorf(lattice.y), ceilf(lattice.y)]:
			var candidate := Vector2(x, y) * TEXEL_WORLD
			var error := maxf(
				(candidate + offset).distance_to(feet), (candidate + offset).distance_to(runtime_feet)
			)
			if error < best_error - 0.0001:
				best = candidate
				best_error = error
	return best


# --- Backdrop removal ----------------------------------------------------------

## A backdrop box shows up as a run of near-black lines (plus a neutral frame
## line on the outermost ring) that is much thicker than the art's own ~1 block
## outline. Only such margins are flood filled from the border; every source is
## scanned and its margins are reported in the manifest.
func _scan_backdrop(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var count := width * height
	var opaque := PackedByteArray()
	opaque.resize(count)
	var dark := PackedByteArray()
	dark.resize(count)
	var frame := PackedByteArray()
	frame.resize(count)
	var border_total := 0
	var border_opaque := 0
	for y: int in range(height):
		for x: int in range(width):
			var index := y * width + x
			var offset := index * 4
			var ring := x == 0 or y == 0 or x == width - 1 or y == height - 1
			if ring:
				border_total += 1
			if data[offset + 3] < 128:
				continue
			opaque[index] = 1
			if ring:
				border_opaque += 1
			var high := maxi(data[offset], maxi(data[offset + 1], data[offset + 2]))
			var low := mini(data[offset], mini(data[offset + 1], data[offset + 2]))
			dark[index] = 1 if high <= int(BACKDROP_RULE["dark_channel"]) else 0
			if ring and high >= int(BACKDROP_RULE["frame_min"]) and high <= int(BACKDROP_RULE["frame_max"]) \
					and float(high - low) / float(high) <= float(BACKDROP_RULE["frame_saturation"]):
				frame[index] = 1
	var margins := {}
	for side: String in ["left", "right", "top", "bottom"]:
		var vertical := side == "left" or side == "right"
		var length := height if vertical else width
		var depth := 0
		while depth < (width if vertical else height) / 2:
			var covered := 0
			var backdrop := 0
			for along: int in range(length):
				var index := _side_index(side, depth, along, width, height)
				if opaque[index] == 0:
					continue
				covered += 1
				if dark[index] == 1 or (depth == 0 and frame[index] == 1):
					backdrop += 1
			if covered < length * float(BACKDROP_RULE["min_coverage"]) \
					or backdrop < covered * float(BACKDROP_RULE["dark_fraction"]):
				break
			depth += 1
		margins[side] = depth
	var minimum := int(BACKDROP_RULE["min_margin"])
	var left: int = margins["left"] if margins["left"] >= minimum else 0
	var right: int = margins["right"] if margins["right"] >= minimum else 0
	var top: int = margins["top"] if margins["top"] >= minimum else 0
	var bottom: int = margins["bottom"] if margins["bottom"] >= minimum else 0
	# Inside a confirmed margin the flood also takes the few brighter noise
	# specks (<10% by construction), so no frame residue widens the object.
	var inside := PackedByteArray()
	inside.resize(count)
	for y: int in range(height):
		for x: int in range(width):
			if x < left or x >= width - right or y < top or y >= height - bottom:
				inside[y * width + x] = opaque[y * width + x]
	var mask := PackedByteArray()
	mask.resize(count)
	var queue := PackedInt32Array()
	for y: int in range(height):
		for x: int in range(width):
			var index := y * width + x
			if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and inside[index] == 1:
				mask[index] = 1
				queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % width
		var y := index / width
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx := x + step.x
			var ny := y + step.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var neighbour := ny * width + nx
			if mask[neighbour] == 0 and inside[neighbour] == 1:
				mask[neighbour] = 1
				queue.append(neighbour)
	return {
		"mask": mask,
		"summary": {
			"border_opaque_fraction": snappedf(float(border_opaque) / maxf(border_total, 1.0), 0.001),
			"dark_margin_px": margins,
			"backdrop_margins_px": {"left": left, "right": right, "top": top, "bottom": bottom},
			"flood_candidates": queue.size(),
		},
	}


func _side_index(side: String, depth: int, along: int, width: int, height: int) -> int:
	match side:
		"left":
			return along * width + depth
		"right":
			return along * width + width - 1 - depth
		"top":
			return depth * width + along
	return (height - 1 - depth) * width + along


## Enclosed paper-white regions are leftovers of the generator's white
## background (gaps between pipes, leaves and frames). A neutral white region
## of at least REMNANT_MIN_PX, grown through its light anti-aliased fringe, is
## cleared when its surroundings are dark or transparent; white glow cores sit
## in bright coloured light and are kept.
func _remove_white_remnants(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var count := width * height
	var white := PackedByteArray()
	white.resize(count)
	var fringe := PackedByteArray()
	fringe.resize(count)
	for index: int in range(count):
		var offset := index * 4
		if data[offset + 3] < 128:
			continue
		var high := maxi(data[offset], maxi(data[offset + 1], data[offset + 2]))
		var low := mini(data[offset], mini(data[offset + 1], data[offset + 2]))
		if low >= REMNANT_WHITE_MIN and high - low <= REMNANT_WHITE_SPREAD:
			white[index] = 1
		if low >= REMNANT_FRINGE_MIN and high - low <= REMNANT_FRINGE_SPREAD:
			fringe[index] = 1
	var seen := PackedByteArray()
	seen.resize(count)
	var cleared := PackedByteArray()
	cleared.resize(count)
	var removed := 0
	var regions := 0
	var kept := 0
	for start: int in range(count):
		if white[start] == 0 or seen[start] == 1:
			continue
		var region := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		while head < region.size():
			var index := region[head]
			head += 1
			for neighbour: int in _neighbours4(index, width, height):
				if white[neighbour] == 1 and seen[neighbour] == 0:
					seen[neighbour] = 1
					region.append(neighbour)
		if region.size() < REMNANT_MIN_PX:
			continue
		var grown := {}
		for index: int in region:
			grown[index] = true
		var frontier := region
		for _ring: int in range(REMNANT_FRINGE_PX):
			var next := PackedInt32Array()
			for index: int in frontier:
				for neighbour: int in _neighbours4(index, width, height):
					if fringe[neighbour] == 1 and not grown.has(neighbour):
						grown[neighbour] = true
						next.append(neighbour)
			frontier = next
		var surround := 0.0
		var samples := 0
		var touches_outside := false
		for index: int in grown:
			var x := index % width
			var y := index / width
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						touches_outside = true
						continue
					var neighbour := ny * width + nx
					if grown.has(neighbour):
						continue
					var offset := neighbour * 4
					if data[offset + 3] < 128:
						touches_outside = true
						continue
					surround += maxi(data[offset], maxi(data[offset + 1], data[offset + 2]))
					samples += 1
		var dark_surround := samples == 0 or surround / samples <= REMNANT_SURROUND_MAX
		if not (dark_surround or touches_outside and surround / maxf(samples, 1.0) <= REMNANT_SURROUND_MAX * 1.5):
			kept += 1
			continue
		regions += 1
		for index: int in grown:
			cleared[index] = 1
	for index: int in range(count):
		if cleared[index] == 1:
			data.encode_u32(index * 4, 0)
			removed += 1
	image.set_data(width, height, false, Image.FORMAT_RGBA8, data)
	return {"removed_px": removed, "regions": regions, "kept_bright_regions": kept}


func _neighbours4(index: int, width: int, height: int) -> PackedInt32Array:
	var x := index % width
	var y := index / width
	var result := PackedInt32Array()
	if x > 0:
		result.append(index - 1)
	if x < width - 1:
		result.append(index + 1)
	if y > 0:
		result.append(index - width)
	if y < height - 1:
		result.append(index + width)
	return result


func _clear_mask(image: Image, mask: PackedByteArray) -> int:
	var data := image.get_data()
	var cleared := 0
	for index: int in range(mask.size()):
		if mask[index] == 1:
			data.encode_u32(index * 4, 0)
			cleared += 1
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
	return cleared


## Drops tiny opaque specks (8-connected) left behind in a removed backdrop.
func _remove_islands(image: Image, min_size: int) -> int:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var seen := PackedByteArray()
	seen.resize(width * height)
	var removed := 0
	for start: int in range(width * height):
		if seen[start] == 1 or data[start * 4 + 3] < 128:
			continue
		var component := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		while head < component.size():
			var index := component[head]
			head += 1
			var x := index % width
			var y := index / width
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var neighbour := ny * width + nx
					if seen[neighbour] == 0 and data[neighbour * 4 + 3] >= 128:
						seen[neighbour] = 1
						component.append(neighbour)
		if component.size() < min_size:
			for index: int in component:
				data.encode_u32(index * 4, 0)
			removed += component.size()
	image.set_data(width, height, false, Image.FORMAT_RGBA8, data)
	return removed


# --- Resampling ----------------------------------------------------------------

## Exact box (area) average of `crop` onto width x height texels. Returns linear,
## premultiplied RGBA; area outside the source counts as transparent.
func _area_downsample(image: Image, crop: Rect2, width: int, height: int) -> PackedFloat32Array:
	var source_width := image.get_width()
	var source_height := image.get_height()
	var data := image.get_data()
	var step := crop.size.x / width
	var columns := _box_weights(crop.position.x, step, width, source_width)
	var rows := _box_weights(crop.position.y, step, height, source_height)
	var first_row := source_height
	var last_row := 0
	for pairs: PackedFloat32Array in rows:
		for pair: int in range(0, pairs.size(), 2):
			first_row = mini(first_row, int(pairs[pair]))
			last_row = maxi(last_row, int(pairs[pair]) + 1)
	var row_count := maxi(0, last_row - first_row)
	var horizontal := PackedFloat32Array()
	horizontal.resize(row_count * width * 4)
	for row: int in range(row_count):
		var source_row := (first_row + row) * source_width
		for column: int in range(width):
			var red := 0.0
			var green := 0.0
			var blue := 0.0
			var alpha := 0.0
			var pairs: PackedFloat32Array = columns[column]
			for pair: int in range(0, pairs.size(), 2):
				var offset := (source_row + int(pairs[pair])) * 4
				var coverage := data[offset + 3] / 255.0 * pairs[pair + 1]
				if coverage <= 0.0:
					continue
				red += _linear_lut[data[offset]] * coverage
				green += _linear_lut[data[offset + 1]] * coverage
				blue += _linear_lut[data[offset + 2]] * coverage
				alpha += coverage
			var out := (row * width + column) * 4
			horizontal[out] = red
			horizontal[out + 1] = green
			horizontal[out + 2] = blue
			horizontal[out + 3] = alpha
	var result := PackedFloat32Array()
	result.resize(width * height * 4)
	var area := step * step
	for target_row: int in range(height):
		var pairs: PackedFloat32Array = rows[target_row]
		for column: int in range(width):
			var out := (target_row * width + column) * 4
			for pair: int in range(0, pairs.size(), 2):
				var row := int(pairs[pair]) - first_row
				var weight := pairs[pair + 1]
				var offset := (row * width + column) * 4
				for channel: int in range(4):
					result[out + channel] += horizontal[offset + channel] * weight
			for channel: int in range(4):
				result[out + channel] /= area
	return result


## Per target cell: flat [source_index, overlap, ...] pairs for one axis.
func _box_weights(start: float, step: float, cells: int, limit: int) -> Array[PackedFloat32Array]:
	var weights: Array[PackedFloat32Array] = []
	for cell: int in range(cells):
		var low := start + cell * step
		var high := low + step
		var pairs := PackedFloat32Array()
		for index: int in range(maxi(0, floori(low)), mini(limit, ceili(high))):
			var overlap := minf(high, index + 1.0) - maxf(low, float(index))
			if overlap > 0.0001:
				pairs.append(index)
				pairs.append(overlap)
		weights.append(pairs)
	return weights


func _binary_mask(texels: PackedFloat32Array, count: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(count)
	for index: int in range(count):
		mask[index] = 1 if texels[index * 4 + 3] >= ALPHA_CUTOFF else 0
	return mask


func _binary_mask_from_image(image: Image) -> PackedByteArray:
	var data := image.get_data()
	var mask := PackedByteArray()
	mask.resize(image.get_width() * image.get_height())
	for index: int in range(mask.size()):
		mask[index] = 1 if data[index * 4 + 3] >= 128 else 0
	return mask


# --- Pixel-art styling -------------------------------------------------------

func _stylize(
	texels: PackedFloat32Array, width: int, height: int, spec: Dictionary, source: Image, crop: Rect2
) -> Dictionary:
	var count := width * height
	var mask := _binary_mask(texels, count)
	var lab: Array[Vector3] = []
	lab.resize(count)
	for index: int in range(count):
		if mask[index] == 0:
			continue
		var alpha := texels[index * 4 + 3]
		lab[index] = _linear_to_oklab(Vector3(
			texels[index * 4] / alpha, texels[index * 4 + 1] / alpha, texels[index * 4 + 2] / alpha
		))

	# Gentle clarity: unsharp mask on OKLab lightness over opaque neighbours only.
	var amount: float = spec["clarity"]
	var blurred := PackedFloat32Array()
	blurred.resize(count)
	for y: int in range(height):
		for x: int in range(width):
			var index := y * width + x
			if mask[index] == 0:
				continue
			var total := 0.0
			var weight_sum := 0.0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height or mask[ny * width + nx] == 0:
						continue
					var weight := float((2 - absi(dx)) * (2 - absi(dy)))
					total += lab[ny * width + nx].x * weight
					weight_sum += weight
			blurred[index] = total / weight_sum
	# Mid-radius local contrast (photo "clarity") lifts larger features such as
	# a clock face or a lit panel against their darker housing.
	var local := _opaque_box_blur(lab, mask, width, height, LOCAL_CONTRAST_RADIUS)
	for index: int in range(count):
		if mask[index] == 0:
			continue
		var colour := lab[index]
		var sharpened := colour.x + amount * (colour.x - blurred[index])
		sharpened += LOCAL_CONTRAST * (colour.x - local[index])
		lab[index] = _harmonize(Vector3(clampf(sharpened, 0.0, 1.0), colour.y, colour.z), spec)

	# Selective 1 px outline: silhouette pixels become a darker shade of the
	# adjacent interior colour, anchored at #140c18 and darkest at the base.
	var base := _color_to_oklab(OUTLINE_BASE)
	var edge := PackedByteArray()
	edge.resize(count)
	var outlined := lab.duplicate()
	var outline_points: Array[Vector3] = []
	for y: int in range(height):
		for x: int in range(width):
			var index := y * width + x
			if mask[index] == 0:
				continue
			var open_left := x == 0 or mask[index - 1] == 0
			var open_right := x == width - 1 or mask[index + 1] == 0
			var open_up := y == 0 or mask[index - width] == 0
			var open_down := y == height - 1 or mask[index + width] == 0
			if not (open_left or open_right or open_up or open_down):
				continue
			var reference := Vector3.ZERO
			var samples := 0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx <= 0 or ny <= 0 or nx >= width - 1 or ny >= height - 1:
						continue
					var neighbour := ny * width + nx
					if mask[neighbour] == 0 or mask[neighbour - 1] == 0 or mask[neighbour + 1] == 0 \
							or mask[neighbour - width] == 0 or mask[neighbour + width] == 0:
						continue
					reference += lab[neighbour]
					samples += 1
			reference = reference / samples if samples > 0 else lab[index]
			var thin := (open_left and open_right) or (open_up and open_down)
			var keep := THIN_KEEP if thin else OUTLINE_KEEP
			if y >= height - 2:
				keep *= BASE_KEEP
			var shade := base.lerp(reference, keep)
			shade.x = minf(shade.x, maxf(base.x, reference.x - 0.06))
			outlined[index] = shade
			edge[index] = 2 if thin else 1
			if not thin:
				outline_points.append(shade)

	# Palette: material colours come from the cleaned source pixels (not the
	# blended texels), so mixed texels snap to real ramps; the outline keeps a
	# small ramp of its own. Thin 1-px parts keep the main palette.
	var palette := _build_palette(_source_points(source, crop, spec), int(spec["colors"]))
	var outline_palette := (
		_build_palette(outline_points, OUTLINE_COLORS) if not outline_points.is_empty()
		else palette
	)
	var quantized: Array[Vector3] = []
	quantized.resize(count)
	for index: int in range(count):
		if mask[index] == 1:
			var ramp := outline_palette if edge[index] == 1 else palette
			quantized[index] = ramp[_nearest(ramp, outlined[index])]
	quantized = _despeckle(quantized, mask, edge, width, height)
	var bytes := PackedByteArray()
	bytes.resize(count * 4)
	var used := {}
	for index: int in range(count):
		if mask[index] == 0:
			continue
		var colour := _oklab_to_color(quantized[index])
		var red := roundi(colour.r * 255.0)
		var green := roundi(colour.g * 255.0)
		var blue := roundi(colour.b * 255.0)
		bytes[index * 4] = red
		bytes[index * 4 + 1] = green
		bytes[index * 4 + 2] = blue
		bytes[index * 4 + 3] = 255
		used[Color8(red, green, blue).to_html(false)] = true
	var hex: Array = used.keys()
	hex.sort()
	return {
		"image": Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes),
		"palette": hex,
		"palette_count": hex.size(),
	}


## Pixel-art cleanup: an interior pixel whose colour no 4-neighbour shares is
## replaced by the most common neighbouring colour when the two are close
## (low-contrast speckle). Contrasting single pixels (rivets, glints) stay.
func _despeckle(
	colours: Array[Vector3], mask: PackedByteArray, edge: PackedByteArray, width: int, height: int
) -> Array[Vector3]:
	var result := colours.duplicate()
	for y: int in range(1, height - 1):
		for x: int in range(1, width - 1):
			var index := y * width + x
			if mask[index] == 0 or edge[index] != 0:
				continue
			var own := colours[index]
			var isolated := true
			for neighbour: int in [index - 1, index + 1, index - width, index + width]:
				if mask[neighbour] == 1 and colours[neighbour] == own:
					isolated = false
					break
			if not isolated:
				continue
			var votes := {}
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var neighbour := index + dy * width + dx
					if neighbour == index or mask[neighbour] == 0 or edge[neighbour] != 0:
						continue
					var weight := 2 if dx == 0 or dy == 0 else 1
					votes[colours[neighbour]] = int(votes.get(colours[neighbour], 0)) + weight
			var best := own
			var best_votes := 0
			for candidate: Vector3 in votes:
				var tally: int = votes[candidate]
				if tally > best_votes or (tally == best_votes and candidate < best):
					best = candidate
					best_votes = tally
			if best_votes >= DESPECKLE_MIN_VOTES and _oklab_distance(best, own) <= DESPECKLE_DELTA:
				result[index] = best
	return result


func _oklab_distance(first: Vector3, second: Vector3) -> float:
	var delta := first - second
	return sqrt(delta.x * delta.x + (delta.y * delta.y + delta.z * delta.z) * HUE_WEIGHT * HUE_WEIGHT)


func _opaque_box_blur(
	lab: Array[Vector3], mask: PackedByteArray, width: int, height: int, radius: int
) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(width * height)
	for y: int in range(height):
		for x: int in range(width):
			var index := y * width + x
			if mask[index] == 0:
				continue
			var total := 0.0
			var samples := 0
			for ny: int in range(maxi(0, y - radius), mini(height, y + radius + 1)):
				for nx: int in range(maxi(0, x - radius), mini(width, x + radius + 1)):
					if mask[ny * width + nx] == 1:
						total += lab[ny * width + nx].x
						samples += 1
			result[index] = total / samples
	return result


## Harmonise toward the game's look: near-neutral shadows lean violet, near-
## neutral highlights lean parchment and crushed blacks lift toward the #140c18
## base. Saturated material colours (glows, foliage, blue gauges) keep their hue.
func _harmonize(colour: Vector3, spec: Dictionary) -> Vector3:
	var base := _color_to_oklab(OUTLINE_BASE)
	var shadow_tone := _color_to_oklab(SHADOW_TONE)
	var highlight_tone := _color_to_oklab(HIGHLIGHT_TONE)
	var lightness := pow(clampf(colour.x, 0.0, 1.0), 1.0 / (1.0 + float(spec["lift"])))
	var chroma := Vector2(colour.y, colour.z) * CHROMA_GAIN * float(spec["chroma"])
	var neutral := 1.0 - clampf(chroma.length() / NEUTRAL_CHROMA, 0.0, 1.0)
	chroma = chroma.lerp(Vector2(shadow_tone.y, shadow_tone.z),
		_ramp(lightness, 0.48, 0.16) * SHADOW_TINT * (0.4 + 0.6 * neutral))
	chroma = chroma.lerp(Vector2(highlight_tone.y, highlight_tone.z),
		_ramp(lightness, 0.62, 0.9) * HIGHLIGHT_TINT * neutral)
	if lightness < base.x:
		lightness = lerpf(lightness, base.x, BLACK_LIFT)
	return Vector3(lightness, chroma.x, chroma.y)


## Harmonised OKLab colours of the opaque source pixels under the sample window,
## on a regular stride (deterministic) of about SOURCE_PALETTE_SAMPLES points.
func _source_points(source: Image, crop: Rect2, spec: Dictionary) -> Array[Vector3]:
	var width := source.get_width()
	var data := source.get_data()
	var x0 := maxi(0, floori(crop.position.x))
	var y0 := maxi(0, floori(crop.position.y))
	var x1 := mini(width, ceili(crop.end.x))
	var y1 := mini(source.get_height(), ceili(crop.end.y))
	var stride := maxi(1, ceili(sqrt(float((x1 - x0) * (y1 - y0)) / SOURCE_PALETTE_SAMPLES)))
	var points: Array[Vector3] = []
	for y: int in range(y0, y1, stride):
		for x: int in range(x0, x1, stride):
			var offset := (y * width + x) * 4
			if data[offset + 3] < 128:
				continue
			points.append(_harmonize(_linear_to_oklab(Vector3(
				_linear_lut[data[offset]], _linear_lut[data[offset + 1]], _linear_lut[data[offset + 2]]
			)), spec))
	return points


func _ramp(value: float, from: float, to: float) -> float:
	var t := clampf((value - from) / (to - from), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Deterministic median cut in hue-weighted OKLab, refined by k-means.
func _build_palette(points: Array[Vector3], colors: int) -> Array[Vector3]:
	var weighted: Array[Vector3] = []
	for point: Vector3 in points:
		weighted.append(Vector3(point.x, point.y * HUE_WEIGHT, point.z * HUE_WEIGHT))
	var all := PackedInt32Array()
	for index: int in range(weighted.size()):
		all.append(index)
	var boxes: Array[PackedInt32Array] = [all]
	while boxes.size() < colors:
		var best := -1
		var best_axis := 0
		var best_score := 0.0
		for box_index: int in range(boxes.size()):
			var box := boxes[box_index]
			if box.size() < 2:
				continue
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for member: int in box:
				low = low.min(weighted[member])
				high = high.max(weighted[member])
			var extent := high - low
			var axis := extent.max_axis_index()
			var score := extent[axis] * pow(float(box.size()), MEDIAN_CUT_POPULATION)
			if score > best_score:
				best = box_index
				best_axis = axis
				best_score = score
		if best < 0:
			break
		var members := Array(boxes[best])
		members.sort_custom(func(first: int, second: int) -> bool:
			var a: float = weighted[first][best_axis]
			var b: float = weighted[second][best_axis]
			return a < b if a != b else first < second)
		var half := members.size() / 2
		boxes[best] = PackedInt32Array(members.slice(0, half))
		boxes.append(PackedInt32Array(members.slice(half)))
	var centres: Array[Vector3] = []
	for box: PackedInt32Array in boxes:
		var total := Vector3.ZERO
		for member: int in box:
			total += weighted[member]
		centres.append(total / box.size())
	for _iteration: int in range(KMEANS_ITERATIONS):
		var sums: Array[Vector3] = []
		sums.resize(centres.size())
		var counts := PackedInt32Array()
		counts.resize(centres.size())
		for point: Vector3 in weighted:
			var nearest := _nearest(centres, point)
			sums[nearest] += point
			counts[nearest] += 1
		for centre: int in range(centres.size()):
			if counts[centre] > 0:
				centres[centre] = sums[centre] / counts[centre]
	var palette: Array[Vector3] = []
	for centre: Vector3 in centres:
		palette.append(Vector3(centre.x, centre.y / HUE_WEIGHT, centre.z / HUE_WEIGHT))
	return palette


func _nearest(palette: Array[Vector3], colour: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for index: int in range(palette.size()):
		var delta := palette[index] - colour
		var distance := delta.x * delta.x + (delta.y * delta.y + delta.z * delta.z) * HUE_WEIGHT * HUE_WEIGHT
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _linear_to_oklab(linear: Vector3) -> Vector3:
	var l := _cube_root(0.4122214708 * linear.x + 0.5363325363 * linear.y + 0.0514459929 * linear.z)
	var m := _cube_root(0.2119034982 * linear.x + 0.6806995451 * linear.y + 0.1073969566 * linear.z)
	var s := _cube_root(0.0883024619 * linear.x + 0.2817188376 * linear.y + 0.6299787005 * linear.z)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	)


func _oklab_to_color(lab: Vector3) -> Color:
	var l := lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z
	var m := lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z
	var s := lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z
	l = l * l * l
	m = m * m * m
	s = s * s * s
	return Color(
		_encode_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		_encode_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		_encode_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
	)


func _color_to_oklab(colour: Color) -> Vector3:
	return _linear_to_oklab(Vector3(
		_linear_lut[roundi(colour.r * 255.0)],
		_linear_lut[roundi(colour.g * 255.0)],
		_linear_lut[roundi(colour.b * 255.0)]
	))


func _cube_root(value: float) -> float:
	return pow(value, 1.0 / 3.0) if value >= 0.0 else -pow(-value, 1.0 / 3.0)


func _encode_srgb(linear: float) -> float:
	var clamped := clampf(linear, 0.0, 1.0)
	return clamped * 12.92 if clamped <= 0.0031308 else 1.055 * pow(clamped, 1.0 / 2.4) - 0.055


# --- Contact shadow ----------------------------------------------------------

## One shared atlas of dithered violet-black ellipses. Each prop uses the size
## that fits its footprint via region_rect, so the dither stays on the 1.25 grid.
func _build_contact_shadow_atlas() -> Dictionary:
	var width := 0
	var height := -1
	for size: Vector2i in CONTACT_SHADOW_SIZES:
		width = maxi(width, size.x)
		height += size.y + 1
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tone := Color(OUTLINE_BASE, CONTACT_SHADOW_ALPHA)
	var regions: Array[Rect2i] = []
	var top := 0
	for size: Vector2i in CONTACT_SHADOW_SIZES:
		for y: int in range(size.y):
			for x: int in range(size.x):
				var nx := (x + 0.5 - size.x * 0.5) / (size.x * 0.5)
				var ny := (y + 0.5 - size.y * 0.5) / (size.y * 0.5)
				var distance := nx * nx + ny * ny
				if distance > 1.0 or (distance > CONTACT_SHADOW_CORE and (x + y) % 2 == 1):
					continue
				image.set_pixel(x, top + y, tone)
		regions.append(Rect2i(0, top, size.x, size.y))
		top += size.y + 1
	return {"image": image, "regions": regions}


func _place_contact_shadow(image: Image, centered: bool, atlas: Dictionary) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var rows := maxi(2, height / 10)
	var left := width
	var right := -1
	for y: int in range(height - rows, height):
		for x: int in range(width):
			if data[(y * width + x) * 4 + 3] >= 128:
				left = mini(left, x)
				right = maxi(right, x)
	var footprint := right - left + 1
	var regions: Array[Rect2i] = atlas["regions"]
	var region := regions[regions.size() - 1]
	for candidate: Rect2i in regions:
		if candidate.size.x >= footprint:
			region = candidate
			break
	var shadow_left := roundi((left + right + 1) * 0.5 - region.size.x * 0.5)
	var centre := Vector2(shadow_left + region.size.x * 0.5, height - 1)
	if centered:
		centre -= Vector2(width, height) * 0.5
	return {"region": region, "position": centre, "footprint": footprint}


# --- Wall overlap --------------------------------------------------------------

func _wall_overlap_old(
	original: Image, origin: Vector2, scale: Vector2, rect: Rect2, walls: Image
) -> int:
	var width := original.get_width()
	var height := original.get_height()
	var data := original.get_data()
	var overlap := 0
	for y: int in range(floori(rect.position.y), ceili(rect.end.y)):
		for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
			var source := (Vector2(x + 0.5, y + 0.5) - origin) / scale
			var sx := floori(source.x)
			var sy := floori(source.y)
			if sx < 0 or sy < 0 or sx >= width or sy >= height:
				continue
			if data[(sy * width + sx) * 4 + 3] >= 128 and _wall_at(walls, x, y):
				overlap += 1
	return overlap


func _wall_overlap_new(
	mask: PackedByteArray, width: int, height: int, top_left: Vector2, walls: Image
) -> int:
	var overlap := 0
	var end := top_left + Vector2(width, height) * TEXEL_WORLD
	for y: int in range(floori(top_left.y), ceili(end.y)):
		for x: int in range(floori(top_left.x), ceili(end.x)):
			var texel := ((Vector2(x + 0.5, y + 0.5) - top_left) / TEXEL_WORLD).floor()
			if texel.x < 0 or texel.y < 0 or texel.x >= width or texel.y >= height:
				continue
			if mask[int(texel.y) * width + int(texel.x)] == 1 and _wall_at(walls, x, y):
				overlap += 1
	return overlap


func _wall_at(walls: Image, world_x: int, world_y: int) -> bool:
	var tx := floori((world_x + 0.5) / TEXEL_WORLD)
	var ty := floori((world_y + 0.5) / TEXEL_WORLD)
	if tx < 0 or ty < 0 or tx >= walls.get_width() or ty >= walls.get_height():
		return false
	return walls.get_pixel(tx, ty).a >= 0.5


# --- Reporting -----------------------------------------------------------------

func _print_layout(result: Dictionary) -> void:
	var spec: Dictionary = result["spec"]
	var shadow: Dictionary = result["shadow"]
	var region: Rect2i = shadow["region"]
	print("%s: %s fit=%s texture=%s palette=%d position=%s feet %s -> %s (runtime %s) shadow region=%s position=%s walls %d -> %d %s" % [
		spec["id"], spec["node"], result["fit"], result["texture_size"], result["palette_count"],
		_vector_text(result["local_position"]), _vector_text(result["feet"]),
		_vector_text(result["new_feet"]), _vector_text(result["runtime_feet"]),
		region, _vector_text(shadow["position"]), result["old_wall_overlap"],
		result["new_wall_overlap"], _candidate_text(result["candidates"]),
	])


func _candidate_text(candidates: Dictionary) -> String:
	var parts: Array[String] = []
	for fit: String in candidates:
		var plan: Dictionary = candidates[fit]["plan"]
		parts.append("%s=%dx%d/walls %d" % [fit, plan["width"], plan["height"], candidates[fit]["wall_overlap"]])
	return "[" + ", ".join(parts) + "]"


func _vector_text(value: Vector2) -> String:
	return "(%.4f, %.4f)" % [value.x, value.y]


func _write_manifest(results: Array[Dictionary], atlas: Dictionary) -> void:
	var assets: Array = []
	for result: Dictionary in results:
		var spec: Dictionary = result["spec"]
		var shadow: Dictionary = result["shadow"]
		var region: Rect2i = shadow["region"]
		var bounds: Rect2i = result["object_bounds"]
		var crop: Rect2 = result["crop"]
		var old_rect: Rect2 = result["old_rect"]
		var new_rect: Rect2 = result["new_rect"]
		var candidates := {}
		for fit: String in result["candidates"]:
			var candidate: Dictionary = result["candidates"][fit]
			var plan: Dictionary = candidate["plan"]
			candidates[fit] = {
				"uniform_source_scale": snappedf(candidate["scale"], 0.000001),
				"size": [plan["width"], plan["height"]],
				"wall_overlap_world_px": candidate["wall_overlap"],
			}
		var feet: Vector2 = result["feet"]
		var new_feet: Vector2 = result["new_feet"]
		var runtime_feet: Vector2 = result["runtime_feet"]
		assets.append({
			"id": spec["id"],
			"path": str(result["output"]).trim_prefix("res://"),
			"node": "scenes/wall_collisions.tscn:" + str(spec["node"]),
			"source": str(spec["source"]).trim_prefix("res://"),
			"source_sha256": FileAccess.get_sha256(_absolute(spec["source"])),
			"source_size": [result["source_size"].x, result["source_size"].y],
			"backdrop_check": {
				"border_opaque_fraction": result["backdrop_scan"]["border_opaque_fraction"],
				"dark_margin_px": result["backdrop_scan"]["dark_margin_px"],
				"backdrop_margins_px": result["backdrop_scan"]["backdrop_margins_px"],
				"flood_candidates_px": result["backdrop_scan"]["flood_candidates"],
				"applied": spec["backdrop"],
				"removed_px": result["backdrop_removed"] + result["islands_removed"],
			},
			"white_remnants": result["remnants"],
			"object_crop_px": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"sample_window_px": [
				snappedf(crop.position.x, 0.01), snappedf(crop.position.y, 0.01),
				snappedf(crop.size.x, 0.01), snappedf(crop.size.y, 0.01),
			],
			"source_px_per_texel": snappedf(result["source_px_per_texel"], 0.001),
			"size": [result["texture_size"].x, result["texture_size"].y],
			"palette_count": result["palette_count"],
			"palette": result["palette"],
			"parameters": {
				"colors": spec["colors"], "clarity": spec["clarity"], "fit": result["fit"],
				"fit_rule": spec["fit"],
			},
			"fit_candidates": candidates,
			"old_layout": {
				"scale": [spec["scale"].x, spec["scale"].y],
				"position": [spec["position"].x, spec["position"].y],
				"centered": spec["centered"], "texture_filter": spec["old_filter"],
				"visible_world_size": [snappedf(old_rect.size.x, 0.01), snappedf(old_rect.size.y, 0.01)],
				"wall_overlap_world_px": result["old_wall_overlap"],
			},
			"layout": {
				"scale": [TEXEL_WORLD, TEXEL_WORLD],
				"position": [snappedf(result["local_position"].x, 0.0001), snappedf(result["local_position"].y, 0.0001)],
				"centered": spec["centered"], "texture_filter": "nearest",
				"visible_world_size": [snappedf(new_rect.size.x, 0.01), snappedf(new_rect.size.y, 0.01)],
				"wall_overlap_world_px": result["new_wall_overlap"],
			},
			"visual_feet": {
				"object_before": [snappedf(feet.x, 0.001), snappedf(feet.y, 0.001)],
				"runtime_before": [snappedf(runtime_feet.x, 0.001), snappedf(runtime_feet.y, 0.001)],
				"after": [snappedf(new_feet.x, 0.001), snappedf(new_feet.y, 0.001)],
				"delta_object_px": snappedf(feet.distance_to(new_feet), 0.001),
				"delta_runtime_px": snappedf(runtime_feet.distance_to(new_feet), 0.001),
			},
			"contact_shadow": {
				"region": [region.position.x, region.position.y, region.size.x, region.size.y],
				"position": [shadow["position"].x, shadow["position"].y],
				"footprint_texels": shadow["footprint"],
			},
		})
	var regions: Array = []
	for region: Rect2i in atlas["regions"]:
		regions.append([region.position.x, region.position.y, region.size.x, region.size.y])
	var shadow_image: Image = atlas["image"]
	var manifest := {
		"schema_version": 1,
		"family": "Shadow Castle Hall prop pixel pass",
		"created": "2026-10-21",
		"creator": "GitHub Copilot, offline processing with tools/pixelize_hall_props.gd (Godot Image API)",
		"provenance": "Processed derivatives of the project's existing AI-generated Hall prop PNGs. No new image generation, external imagery or hand repaint; the source PNGs are unchanged and remain in use elsewhere (dining_grandfather_clock.png in the Dining Hall).",
		"rights": "Derived exclusively from existing project artwork; the source images' rights and restrictions remain applicable. Repository-wide licensing remains the maintainer's decision.",
		"tool": "tools/pixelize_hall_props.gd",
		"reproduce": "HOME=\"$PWD/.godot/hall-props-home\" godot --headless --path . --script res://tools/pixelize_hall_props.gd [-- --contact-sheet], then godot --headless --editor --path . --quit to import.",
		"texel_world_size": TEXEL_WORLD,
		"sprite_scale": [TEXEL_WORLD, TEXEL_WORLD],
		"format": "PNG RGBA8, sRGB",
		"alpha": "Binary 0/255 (coverage threshold 0.5); contact shadow uses one 60% violet-black tone",
		"filtering": "nearest",
		"mipmaps": false,
		"compression": "Godot lossless import",
		"pipeline": [
			"Backdrop scan: per side, a run of >=90% near-black lines (plus a neutral frame line on the outer ring) at least 16 px thick marks a backdrop margin; it is flood filled from the border (its few brighter noise specks included), then isolated specks under 300 px are dropped (applied where backdrop_check.applied is true; every source is scanned)",
			"White-remnant removal: enclosed neutral white regions (min channel >= 228, >= 40 px) left from the generator's paper background are cleared with their light fringe when their surroundings are dark; white glow cores in bright light are kept (white_remnants)",
			"Crop to the object's opaque bounds",
			"Exact area-average downsample in linear light with premultiplied alpha; texel = visible world size / 1.25, bottom-centre anchored",
			"Binary alpha at 0.5 coverage",
			"Gentle OKLab clarity on lightness: 3x3 unsharp (parameters.clarity) plus 0.3 x 7x7 local contrast, over opaque neighbours only",
			"Harmonisation: 1.1 chroma gain (x parameters.chroma); near-neutral shadows lean to #33243d violet and highlights to #ead9b3 parchment, saturated glows keep their hue; blacks lift toward #140c18; parameters.lift brightens mid-tones",
			"1 px selective outline: silhouette pixels take a darker shade of the adjacent interior colour anchored at #140c18, darkest on the two base rows, with a 4-colour outline ramp",
			"Deterministic median-cut + k-means palette (parameters.colors) built from the harmonised cleaned source pixels in hue-weighted OKLab; nearest mapping without dithering; isolated low-contrast single pixels merge into their neighbours",
		],
		"placement": "Uniform Sprite2D scale 1.25; top-left snapped to the walls' 1.25 texel lattice; world bottom-centre (RoomSpatialRuntime visual feet) preserved",
		"assets": assets,
		"contact_shadow": {
			"path": (OUTPUT_DIR + SHADOW_FILE).trim_prefix("res://"),
			"size": [shadow_image.get_width(), shadow_image.get_height()],
			"tone": "#" + OUTLINE_BASE.to_html(false) + " at alpha " + str(CONTACT_SHADOW_ALPHA),
			"dither": "Solid core inside normalised radius^2 0.45, 50% checkerboard edge",
			"regions": regions,
			"integration": "Child Sprite2D 'ContactShadow' of each prop sprite, show_behind_parent, region_rect selects the ellipse matching the footprint",
		},
	}
	var file := FileAccess.open(_absolute(OUTPUT_DIR + "manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()


# --- Contact sheet -----------------------------------------------------------

func _write_contact_sheet(results: Array[Dictionary], atlas: Dictionary) -> void:
	var rows: Array = []
	var column_widths := PackedInt32Array([0, 0, 0, 0, 0, 0])
	for result: Dictionary in results:
		var old_rect: Rect2 = result["old_rect"]
		var runtime_rect: Rect2 = result["runtime_rect"]
		var window_rect := old_rect.merge(runtime_rect).merge(result["new_rect"]).grow(6.0)
		var window := Rect2i(
			Vector2i(floori(window_rect.position.x), floori(window_rect.position.y)),
			Vector2i(ceili(window_rect.end.x) - floori(window_rect.position.x),
				ceili(window_rect.end.y) - floori(window_rect.position.y))
		)
		var panels: Array[Image] = [
			_render_old(result, window, 1), _render_new(result, window, 1, atlas),
			_render_old(result, window, 2), _render_new(result, window, 2, atlas),
			_render_old(result, window, 4), _render_new(result, window, 4, atlas),
		]
		for column: int in range(panels.size()):
			column_widths[column] = maxi(column_widths[column], panels[column].get_width())
		rows.append(panels)
	var margin := 16
	var label_height := 22
	var header := 40
	var width := margin
	for column_width: int in column_widths:
		width += column_width + margin
	var height := header
	for panels: Array in rows:
		height += label_height + (panels[4] as Image).get_height() + margin
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(SHEET_BACKGROUND)
	var titles := ["OLD 1X", "NEW 1X", "OLD 2X GAME", "NEW 2X GAME", "OLD 4X", "NEW 4X NEAREST"]
	var x := margin
	for column: int in range(titles.size()):
		_draw_text(sheet, titles[column], Vector2i(x, 6), SHEET_LABEL)
		x += column_widths[column] + margin
	_draw_text(sheet, "ZOOM = SCREEN PX PER WORLD PX. OLD = SOURCE SAMPLED LIKE ITS SPRITE2D (NO MIPMAPS). NEW = 1.25 WORLD PX TEXELS + CONTACT SHADOW.",
		Vector2i(margin, 22), SHEET_RULE.lightened(0.35))
	var y := header
	for row: int in range(rows.size()):
		var result: Dictionary = results[row]
		var spec: Dictionary = result["spec"]
		sheet.fill_rect(Rect2i(margin, y, width - margin * 2, 1), SHEET_RULE)
		var caption := "%s  %dX%d  %d COLOURS  FIT %s" % [
			str(spec["id"]).to_upper(), result["texture_size"].x, result["texture_size"].y,
			result["palette_count"], str(result["fit"]).to_upper(),
		]
		_draw_text(sheet, caption, Vector2i(margin, y + 6), SHEET_LABEL)
		x = margin
		var panels: Array = rows[row]
		for column: int in range(panels.size()):
			var panel: Image = panels[column]
			sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(x, y + label_height))
			x += column_widths[column] + margin
		y += label_height + (panels[4] as Image).get_height() + margin
	DirAccess.make_dir_recursive_absolute(_absolute(SHEET_PATH.get_base_dir()))
	sheet.save_png(_absolute(SHEET_PATH))
	for result: Dictionary in results:
		if result["spec"]["backdrop"]:
			_backdrop_preview(result).save_png(
				_absolute(SHEET_PATH.get_base_dir().path_join(str(result["spec"]["id"]) + "-backdrop.png"))
			)


## Half-size source: removed backdrop in magenta beside the cleaned object.
func _backdrop_preview(result: Dictionary) -> Image:
	var original: Image = result["original"]
	var cleaned: Image = result["cleaned"]
	var width := original.get_width() / 2
	var height := original.get_height() / 2
	var preview := Image.create(width * 2 + 8, height, false, Image.FORMAT_RGBA8)
	preview.fill(SHEET_BACKGROUND)
	for y: int in range(height):
		for x: int in range(width):
			var before := original.get_pixel(x * 2, y * 2)
			var after := cleaned.get_pixel(x * 2, y * 2)
			var left := PREVIEW_FLOOR
			if before.a >= 0.5:
				left = Color("#ff00ff") if after.a < 0.5 else Color(before, 1.0)
			preview.set_pixel(x, y, left)
			preview.set_pixel(width + 8 + x, y, Color(after, 1.0) if after.a >= 0.5 else PREVIEW_FLOOR)
	return preview


## The old sprite as the GPU drew it: no mipmaps, nearest or bilinear per texel_filter.
func _render_old(result: Dictionary, window: Rect2i, zoom: int) -> Image:
	var spec: Dictionary = result["spec"]
	var original: Image = result["original"]
	var data := original.get_data()
	var source_width := original.get_width()
	var source_height := original.get_height()
	var origin: Vector2 = result["old_origin"]
	var scale: Vector2 = spec["scale"]
	var bilinear: bool = spec["old_filter"] == "linear"
	var image := Image.create(window.size.x * zoom, window.size.y * zoom, false, Image.FORMAT_RGBA8)
	image.fill(PREVIEW_FLOOR)
	for py: int in range(image.get_height()):
		for px: int in range(image.get_width()):
			var world := Vector2(window.position) + Vector2(px + 0.5, py + 0.5) / zoom
			var uv := (world - origin) / scale
			if uv.x < 0.0 or uv.y < 0.0 or uv.x >= source_width or uv.y >= source_height:
				continue
			var sample := (
				_sample_bilinear(data, source_width, source_height, uv) if bilinear
				else _texel(data, source_width, floori(uv.x), floori(uv.y))
			)
			if sample.a > 0.0:
				image.set_pixel(px, py, PREVIEW_FLOOR.lerp(Color(sample, 1.0), sample.a))
	return image


func _render_new(result: Dictionary, window: Rect2i, zoom: int, atlas: Dictionary) -> Image:
	var spec: Dictionary = result["spec"]
	var art: Image = result["image"]
	var top_left: Vector2 = result["top_left"]
	var shadow: Dictionary = result["shadow"]
	var region: Rect2i = shadow["region"]
	var shadow_image: Image = atlas["image"]
	var shadow_top_left: Vector2 = shadow["position"] - Vector2(region.size) * 0.5
	if spec["centered"]:
		shadow_top_left += Vector2(art.get_size()) * 0.5
	var image := Image.create(window.size.x * zoom, window.size.y * zoom, false, Image.FORMAT_RGBA8)
	image.fill(PREVIEW_FLOOR)
	for py: int in range(image.get_height()):
		for px: int in range(image.get_width()):
			var world := Vector2(window.position) + Vector2(px + 0.5, py + 0.5) / zoom
			var texel := ((world - top_left) / TEXEL_WORLD).floor()
			var colour := PREVIEW_FLOOR
			var shadow_texel := Vector2i(texel - shadow_top_left)
			if shadow_texel.x >= 0 and shadow_texel.y >= 0 \
					and shadow_texel.x < region.size.x and shadow_texel.y < region.size.y:
				var shade := shadow_image.get_pixelv(region.position + shadow_texel)
				colour = colour.lerp(Color(shade, 1.0), shade.a)
			if texel.x >= 0 and texel.y >= 0 and texel.x < art.get_width() and texel.y < art.get_height():
				var pixel := art.get_pixelv(Vector2i(texel))
				if pixel.a > 0.5:
					colour = Color(pixel, 1.0)
			image.set_pixel(px, py, colour)
	return image


func _texel(data: PackedByteArray, width: int, x: int, y: int) -> Color:
	var offset := (y * width + x) * 4
	return Color8(data[offset], data[offset + 1], data[offset + 2], data[offset + 3])


func _sample_bilinear(data: PackedByteArray, width: int, height: int, uv: Vector2) -> Color:
	var position := uv - Vector2(0.5, 0.5)
	var x0 := clampi(floori(position.x), 0, width - 1)
	var y0 := clampi(floori(position.y), 0, height - 1)
	var x1 := clampi(x0 + 1, 0, width - 1)
	var y1 := clampi(y0 + 1, 0, height - 1)
	var fx := clampf(position.x - floorf(position.x), 0.0, 1.0)
	var fy := clampf(position.y - floorf(position.y), 0.0, 1.0)
	var premultiplied := Vector4.ZERO
	for corner: Vector3 in [
		Vector3(x0, y0, (1.0 - fx) * (1.0 - fy)), Vector3(x1, y0, fx * (1.0 - fy)),
		Vector3(x0, y1, (1.0 - fx) * fy), Vector3(x1, y1, fx * fy),
	]:
		var texel := _texel(data, width, int(corner.x), int(corner.y))
		premultiplied += Vector4(texel.r * texel.a, texel.g * texel.a, texel.b * texel.a, texel.a) * corner.z
	if premultiplied.w <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
		premultiplied.x / premultiplied.w, premultiplied.y / premultiplied.w,
		premultiplied.z / premultiplied.w, premultiplied.w
	)


func _draw_text(image: Image, text: String, at: Vector2i, colour: Color, size: int = 2) -> void:
	var x := at.x
	for character: String in text.to_upper():
		var glyph: String = FONT.get(character, "")
		for index: int in range(glyph.length()):
			if glyph[index] == "1":
				image.fill_rect(Rect2i(x + (index % 3) * size, at.y + (index / 3) * size, size, size), colour)
		x += 4 * size


# --- Files ---------------------------------------------------------------------

func _load_rgba(path: String) -> Image:
	var image := Image.load_from_file(_absolute(path))
	assert(image != null and not image.is_empty(), "Could not load " + path)
	image.convert(Image.FORMAT_RGBA8)
	return image


func _opaque_bounds(image: Image) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var low := Vector2i(width, height)
	var high := Vector2i(-1, -1)
	for y: int in range(height):
		for x: int in range(width):
			if data[(y * width + x) * 4 + 3] > VISIBLE_ALPHA_8BIT:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	if high.x < low.x:
		return Rect2i(0, 0, width, height)
	return Rect2i(low, high - low + Vector2i.ONE)


func _save_png(image: Image, path: String) -> void:
	var error := image.save_png(_absolute(path))
	assert(error == OK, "Could not save " + path)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
