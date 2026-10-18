extends SceneTree

const OUTPUT := "res://assets/ui/tool_belt/"
const TOOLS := {
	"satchel": ["res://assets/ui/inventory/bag_satchel_icon.png", Rect2i(240, 284, 555, 433), Vector2i(64, 50), 0.0],
	"key": ["res://assets/ui/icon_key.png", Rect2i(132, 98, 758, 795), Vector2i(61, 64), 0.0],
	"notebook": ["res://assets/ui/icon_book.png", Rect2i(225, 196, 575, 606), Vector2i(54, 58), -7.0],
	"map": ["res://assets/ui/icon_note.png", Rect2i(140, 168, 755, 635), Vector2i(62, 52), 6.0],
}
var _project_root := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not OS.get_environment("HOME").contains("/.godot/hub-toolbar-"):
		printerr("Asset normalization requires an isolated hub-toolbar HOME.")
		quit(1)
		return
	if root.has_node("GameState"):
		printerr("Run this offline asset tool from an empty Godot project, not the gameplay project.")
		quit(1)
		return
	_project_root = ProjectSettings.globalize_path(get_script().resource_path).get_base_dir().get_base_dir()
	DirAccess.make_dir_recursive_absolute(_project_path(OUTPUT))
	var sources: Array[Dictionary] = []
	for tool: String in TOOLS:
		var spec: Array = TOOLS[tool]
		var image := Image.load_from_file(_project_path(spec[0])).get_region(spec[1])
		if tool == "satchel":
			var silhouette := PackedVector2Array([
				Vector2(250, 357), Vector2(395, 347), Vector2(395, 324),
				Vector2(410, 308), Vector2(552, 310), Vector2(576, 326),
				Vector2(577, 350), Vector2(674, 338), Vector2(730, 355),
				Vector2(753, 385), Vector2(775, 460), Vector2(790, 643),
				Vector2(756, 692), Vector2(680, 711), Vector2(390, 711),
				Vector2(270, 689), Vector2(250, 658), Vector2(245, 400),
			])
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					if not Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(spec[1].position), silhouette):
						image.set_pixel(x, y, Color.TRANSPARENT)
		var target: Vector2i = spec[2]
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		var hero := Image.create(72, 76, false, Image.FORMAT_RGBA8)
		hero.fill(Color.TRANSPARENT)
		var center := Vector2(36, 69 - target.y / 2.0)
		for y: int in range(76):
			for x: int in range(72):
				var point := (Vector2(x, y) - center).rotated(-deg_to_rad(spec[3])) + Vector2(target) / 2.0
				var sample := Vector2i(point.round())
				if Rect2i(Vector2i.ZERO, target).has_point(sample):
					var color := image.get_pixelv(sample)
					if color.a >= 0.16:
						hero.set_pixel(x, y, color)
		_save(hero, tool + ".png")
		var rim := Image.create(72, 76, false, Image.FORMAT_RGBA8)
		rim.fill(Color.TRANSPARENT)
		for y: int in range(1, 75):
			for x: int in range(1, 71):
				if hero.get_pixel(x, y).a > 0.45:
					continue
				var neighbor := 0.0
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					neighbor = maxf(neighbor, hero.get_pixelv(Vector2i(x, y) + offset).a)
				if neighbor > 0.65:
					rim.set_pixel(x, y, Color("#f2cd83"))
		_save(rim, tool + "_edge.png")
		sources.append({
			"outputs": [tool + ".png", tool + "_edge.png"],
			"source": spec[0], "source_sha256": FileAccess.get_sha256(_project_path(spec[0])),
			"crop": [spec[1].position.x, spec[1].position.y, spec[1].size.x, spec[1].size.y],
			"art_size": [target.x, target.y], "rotation_degrees": spec[3], "canvas": [72, 76],
		})

	var board_path := "res://assets/ui/inventory/bag_inventory_board.png"
	var belt := Image.load_from_file(_project_path(board_path)).get_region(Rect2i(224, 834, 1084, 104))
	belt.resize(332, 32, Image.INTERPOLATE_LANCZOS)
	for y: int in range(32):
		for x: int in range(332):
			var pixel := belt.get_pixel(x, y)
			pixel.a *= clampf(minf(x, 331 - x) / 5.0, 0.0, 1.0)
			belt.set_pixel(x, y, pixel)
	_save(belt, "leather_rail.png")
	sources.append({
		"outputs": ["leather_rail.png"], "source": board_path,
		"source_sha256": FileAccess.get_sha256(_project_path(board_path)),
		"crop": [224, 834, 1084, 104], "canvas": [332, 32],
		"edit": "Existing lower leather binding and its two buckles; five-pixel alpha taper at cut ends.",
	})

	var paper_path := "res://assets/ui/ui_note_parchment.png"
	var paper := Image.load_from_file(_project_path(paper_path)).get_region(Rect2i(212, 440, 612, 230))
	paper.resize(324, 122, Image.INTERPOLATE_LANCZOS)
	var slip := Image.create(332, 130, false, Image.FORMAT_RGBA8)
	slip.fill(Color.TRANSPARENT)
	slip.blit_rect(paper, Rect2i(0, 0, 324, 122), Vector2i(4, 4))
	for y: int in range(12):
		for x: int in range(12 - y):
			slip.set_pixel(327 - x, 4 + y, Color.TRANSPARENT)
	_save(slip, "preview_slip.png")
	sources.append({
		"outputs": ["preview_slip.png"], "source": paper_path,
		"source_sha256": FileAccess.get_sha256(_project_path(paper_path)),
		"crop": [212, 440, 612, 230], "canvas": [332, 130],
		"edit": "Aspect-preserving paper extraction, transparent margins and clipped upper-right corner.",
	})
	var manifest := {
		"family": "Detective tool belt", "native_viewport": [1024, 768],
		"rights": "Derived exclusively from existing project artwork; original rights and restrictions remain applicable.",
		"generation": "No new item illustration or AI generation. Source crops normalized offline with Godot Image.",
		"normalization": "Satchel source-frame removal with the retained tool silhouette mask; Lanczos downsample; nearest rotated placement; trim alpha below 0.16; separate one-pixel silhouette edge feedback.",
		"import": "Lossless RGBA PNG; no mipmaps; nearest filtering at native size.",
		"reproduce": "With isolated hub-toolbar HOME: Godot --headless --path <empty Godot project> --script <checkout>/tools/derive_tool_belt_assets.gd. Output stays in the script's checkout; gameplay autoloads are forbidden.",
		"sources": sources,
	}
	var file := FileAccess.open(_project_path(OUTPUT + "provenance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("Tool-belt raster family normalized from existing artwork.")
	quit.call_deferred(0)


func _project_path(path: String) -> String:
	return _project_root.path_join(path.trim_prefix("res://"))


func _save(image: Image, name: String) -> void:
	var error := image.save_png(_project_path(OUTPUT + name))
	assert(error == OK, "Could not save " + name)
