extends SceneTree

const PLATE_ROOT := "res://assets/ui/knowledge_plates/"
const PRINT_ROOT := "res://assets/ui/guidance/footprints/"
const PLATES: Array[String] = [
	"chemical_physical", "closed_circuit", "photosynthesis", "independent_time", "additive_light",
]
const PALETTE: Array[String] = [
	"#111321", "#1b2033", "#282940", "#393449", "#57506b", "#a7adb8",
	"#594536", "#8d6846", "#b78b56", "#dcba7e", "#f6dfaa", "#fff0c5",
	"#913c52", "#ca5665", "#f09472", "#f4b955",
	"#28615a", "#3e8a70", "#81bb85", "#c5d894",
	"#22435a", "#376783", "#69acba", "#a8d7d0", "#d1eee3",
	"#4765b4", "#9a79b8", "#d6a2c6",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await create_timer(0.2).timeout
	var evidence := OS.get_environment("KNOWLEDGE_ART_EVIDENCE")
	if evidence.is_empty() or not evidence.contains("/.godot/knowledge-art-"):
		printerr("Set KNOWLEDGE_ART_EVIDENCE to an isolated session .godot/knowledge-art-* directory.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(evidence)
	var images: Array[Image] = []
	for plate: String in PLATES:
		var image := _rasterize(PLATE_ROOT + "sources/" + plate + ".svg", Vector2i(96, 128), 2)
		if image == null:
			quit(1)
			return
		if image.save_png(PLATE_ROOT + plate + ".png") != OK:
			quit(1)
			return
		images.append(image)
	for side: String in ["left", "right"]:
		var image := _rasterize(PRINT_ROOT + "sources/shoe_" + side + ".svg", Vector2i(24, 14), 1)
		if image == null or image.save_png(PRINT_ROOT + "shoe_" + side + ".png") != OK:
			quit(1)
			return
		images.append(image)
	var sheet := Image.create(1048, 352, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#24202a"))
	for index: int in range(5):
		sheet.blend_rect(images[index], Rect2i(0, 0, 192, 256), Vector2i(16 + index * 208, 16))
	for index: int in range(2):
		var enlarged := images[5 + index].duplicate() as Image
		enlarged.resize(96, 56, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(enlarged, Rect2i(0, 0, 96, 56), Vector2i(20 + index * 144, 284))
		sheet.blend_rect(images[5 + index], Rect2i(0, 0, 24, 14), Vector2i(124 + index * 144, 304))
	if sheet.save_png(evidence.path_join("contact-sheet.png")) != OK:
		quit(1)
		return
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.queue_free()
		await create_timer(0.2).timeout
	print("knowledge_plate_rasterize: PASS — five 192x256 plates, two 24x14 shoe prints")
	quit(0)


func _rasterize(path: String, expected_size: Vector2i, scale_factor: int) -> Image:
	var image := Image.new()
	if image.load_svg_from_string(FileAccess.get_file_as_string(path)) != OK:
		printerr("Cannot render " + path)
		return null
	if image.get_size() != expected_size:
		printerr("Unexpected source size: " + path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	var palette: Array[Color] = []
	for value: String in PALETTE:
		palette.append(Color(value))
	# SVG is only an editable offline master. Quantize at its authored pixel grid,
	# then enlarge by an integer; no vector smoothing or runtime drawing is shipped.
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var closest := palette[0]
			var distance := INF
			for candidate: Color in palette:
				var delta := Vector3(pixel.r - candidate.r, pixel.g - candidate.g, pixel.b - candidate.b)
				var candidate_distance := delta.length_squared()
				if candidate_distance < distance:
					distance = candidate_distance
					closest = candidate
			image.set_pixel(x, y, closest)
	if scale_factor > 1:
		image.resize(expected_size.x * scale_factor, expected_size.y * scale_factor, Image.INTERPOLATE_NEAREST)
	return image
