extends SceneTree

const REPORT_PATH := "res://docs/evidence/2026-08-13-character-scale/alpha-metrics.csv"
const ROW_REPORT_PATH := "res://docs/evidence/2026-08-13-character-scale/alpha-metrics-by-row.csv"
const VISIBLE_ALPHA_THRESHOLD: float = 0.50
const SHEETS: Array[Dictionary] = [
	{
		"name": "player",
		"path": "res://assets/sprites/player/pixellab_walk_8dir.png",
		"frame_size": Vector2i(256, 256),
		"columns": 8,
		"rows": 8,
		"representative": Vector2i(0, 0),
	},
	{
		"name": "butler",
		"path": "res://assets/characters/animated_pixel_v5/butler_idle_8dir.png",
		"frame_size": Vector2i(48, 68),
		"columns": 8,
		"rows": 8,
		"representative": Vector2i(0, 4),
	},
	{
		"name": "guardian",
		"path": "res://assets/characters/animated_pixel_v5/castle_guardian_walk_8dir.png",
		"frame_size": Vector2i(128, 156),
		"columns": 8,
		"rows": 8,
		"representative": Vector2i(0, 4),
	},
	{
		"name": "gardener",
		"path": "res://assets/characters/animated_pixel_v3/gardener_walk.png",
		"frame_size": Vector2i(256, 256),
		"columns": 4,
		"rows": 4,
		"representative": Vector2i(0, 1),
	},
	{
		"name": "mechanic",
		"path": "res://assets/characters/animated_pixel_v3/mechanic_walk.png",
		"frame_size": Vector2i(256, 256),
		"columns": 4,
		"rows": 4,
		"representative": Vector2i(0, 2),
	},
	{
		"name": "dr_lin_echo",
		"path": "res://assets/characters/animated_pixel_v3/dr_lin_walk.png",
		"frame_size": Vector2i(256, 256),
		"columns": 4,
		"rows": 4,
		"representative": Vector2i(0, 1),
	},
	{
		"name": "mrs_lin_fallen",
		"path": "res://assets/props/FinalRoom/mrs_lin_fallen.png",
		"frame_size": Vector2i.ZERO,
		"columns": 1,
		"rows": 1,
		"representative": Vector2i.ZERO,
	},
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lines: PackedStringArray = PackedStringArray([
		"name,frame_width,frame_height,frames,opaque_width_min,opaque_width_max,opaque_width_average,opaque_height_min,opaque_height_max,opaque_height_average,bottom_padding_min,bottom_padding_max,representative_width,representative_height,representative_bottom",
	])
	var row_lines: PackedStringArray = PackedStringArray([
		"name,row,frames,opaque_height_min,opaque_height_max,opaque_height_average,bottom_min,bottom_max,bottom_average",
	])
	for sheet: Dictionary in SHEETS:
		var metrics := _measure_sheet(sheet)
		if metrics.is_empty():
			continue
		var line := "%s,%d,%d,%d,%d,%d,%.2f,%d,%d,%.2f,%d,%d,%d,%d,%d" % [
			metrics["name"],
			metrics["frame_width"],
			metrics["frame_height"],
			metrics["frames"],
			metrics["width_min"],
			metrics["width_max"],
			metrics["width_average"],
			metrics["height_min"],
			metrics["height_max"],
			metrics["height_average"],
			metrics["bottom_padding_min"],
			metrics["bottom_padding_max"],
			metrics["representative_width"],
			metrics["representative_height"],
			metrics["representative_bottom"],
		]
		lines.append(line)
		print("METRIC: " + line)
		for row_metric: Dictionary in metrics["row_metrics"]:
			var row_line := "%s,%d,%d,%d,%d,%.2f,%d,%d,%.2f" % [
				metrics["name"],
				row_metric["row"],
				row_metric["frames"],
				row_metric["height_min"],
				row_metric["height_max"],
				row_metric["height_average"],
				row_metric["bottom_min"],
				row_metric["bottom_max"],
				row_metric["bottom_average"],
			]
			row_lines.append(row_line)
			print("ROW_METRIC: " + row_line)

	var report_absolute_path := ProjectSettings.globalize_path(REPORT_PATH)
	var report := FileAccess.open(report_absolute_path, FileAccess.WRITE)
	if report == null:
		_fail("Could not write metrics report: " + report_absolute_path)
	else:
		report.store_string("\n".join(lines) + "\n")
		report.close()
		print("WROTE: " + report_absolute_path)
	var row_report_absolute_path := ProjectSettings.globalize_path(ROW_REPORT_PATH)
	var row_report := FileAccess.open(row_report_absolute_path, FileAccess.WRITE)
	if row_report == null:
		_fail("Could not write row metrics report: " + row_report_absolute_path)
	else:
		row_report.store_string("\n".join(row_lines) + "\n")
		row_report.close()
		print("WROTE: " + row_report_absolute_path)
	_finish()


func _measure_sheet(sheet: Dictionary) -> Dictionary:
	var texture := load(str(sheet["path"])) as Texture2D
	if texture == null:
		_fail("Could not load: " + str(sheet["path"]))
		return {}
	var image := texture.get_image()
	if image == null or image.is_empty():
		_fail("Could not read image: " + str(sheet["path"]))
		return {}

	var frame_size: Vector2i = sheet["frame_size"] as Vector2i
	if frame_size == Vector2i.ZERO:
		frame_size = image.get_size()
	var columns := int(sheet["columns"])
	var rows := int(sheet["rows"])
	if image.get_width() != frame_size.x * columns or image.get_height() != frame_size.y * rows:
		_fail(
			"Unexpected sheet dimensions for %s: %s" % [
				sheet["name"],
				image.get_size(),
			]
		)
		return {}

	var widths: Array[int] = []
	var heights: Array[int] = []
	var bottom_paddings: Array[int] = []
	var row_metrics: Array[Dictionary] = []
	var representative: Vector2i = sheet["representative"] as Vector2i
	var representative_rect := Rect2i()
	for row: int in range(rows):
		var row_heights: Array[int] = []
		var row_bottoms: Array[int] = []
		for column: int in range(columns):
			var frame := image.get_region(
				Rect2i(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
			)
			var used_rect := _visible_alpha_rect(frame)
			if used_rect.size == Vector2i.ZERO:
				_fail("Empty frame in %s at row %d column %d" % [sheet["name"], row, column])
				continue
			widths.append(used_rect.size.x)
			heights.append(used_rect.size.y)
			bottom_paddings.append(frame_size.y - used_rect.end.y)
			row_heights.append(used_rect.size.y)
			row_bottoms.append(used_rect.end.y)
			if column == representative.x and row == representative.y:
				representative_rect = used_rect
		if not row_heights.is_empty():
			row_metrics.append({
				"row": row,
				"frames": row_heights.size(),
				"height_min": row_heights.min(),
				"height_max": row_heights.max(),
				"height_average": _average(row_heights),
				"bottom_min": row_bottoms.min(),
				"bottom_max": row_bottoms.max(),
				"bottom_average": _average(row_bottoms),
			})

	if widths.is_empty() or heights.is_empty():
		return {}
	return {
		"name": str(sheet["name"]),
		"frame_width": frame_size.x,
		"frame_height": frame_size.y,
		"frames": widths.size(),
		"width_min": widths.min(),
		"width_max": widths.max(),
		"width_average": _average(widths),
		"height_min": heights.min(),
		"height_max": heights.max(),
		"height_average": _average(heights),
		"bottom_padding_min": bottom_paddings.min(),
		"bottom_padding_max": bottom_paddings.max(),
		"representative_width": representative_rect.size.x,
		"representative_height": representative_rect.size.y,
		"representative_bottom": representative_rect.end.y,
		"row_metrics": row_metrics,
	}


func _average(values: Array[int]) -> float:
	var total := 0.0
	for value: int in values:
		total += value
	return total / float(values.size())


func _visible_alpha_rect(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a < VISIBLE_ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("character_sprite_metrics: PASS")
		quit(0)
		return
	printerr("character_sprite_metrics: FAIL (%d issue(s))" % failures.size())
	quit(1)
