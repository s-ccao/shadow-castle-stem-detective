extends SceneTree

## One-off asset derivation for the Guardian counterplay kit.
##
## The counterplay potions and blueprints must render in the Bag, and the item
## art contract requires every Bag item to own a texture under the approved
## pixel_art_v1 family. Rather than introduce an off-style placeholder, each new
## item is derived from the closest existing hand-authored asset by rotating a
## single hue band. Outlines, cork, and brass hardware sit outside the band and
## are left untouched, so the derived art keeps the original palette discipline.
##
## Run once with:
##   godot --headless --script tools/derive_counterplay_item_art.gd

const SOURCE_DIRECTORY: String = "res://assets/ui/item_models/pixel_art_v1/"

## source, output, the hue window to recolour, the destination hue, and a
## saturation scale for reagents that should read as clearer or murkier.
const DERIVATIONS: Array[Dictionary] = [
	{
		"source": "vision_potion.png",
		"output": "purification_potion.png",
		"hue_min": 0.58,
		"hue_max": 0.88,
		"target_hue": 0.50,
		"saturation_scale": 0.55,
		"value_scale": 1.06,
	},
	{
		"source": "green_potion.png",
		"output": "shroud_potion.png",
		"hue_min": 0.22,
		"hue_max": 0.48,
		"target_hue": 0.66,
		"saturation_scale": 0.92,
		"value_scale": 0.82,
	},
	{
		"source": "vision_potion.png",
		"output": "daze_potion.png",
		"hue_min": 0.58,
		"hue_max": 0.88,
		"target_hue": 0.93,
		"saturation_scale": 1.0,
		"value_scale": 1.0,
	},
	{
		"source": "recipe_vision.png",
		"output": "recipe_purification.png",
		"hue_min": 0.58,
		"hue_max": 0.88,
		"target_hue": 0.50,
		"saturation_scale": 0.62,
		"value_scale": 1.04,
	},
	{
		"source": "recipe_vision.png",
		"output": "recipe_shroud.png",
		"hue_min": 0.58,
		"hue_max": 0.88,
		"target_hue": 0.66,
		"saturation_scale": 1.0,
		"value_scale": 0.84,
	},
	{
		"source": "recipe_vision.png",
		"output": "recipe_daze.png",
		"hue_min": 0.58,
		"hue_max": 0.88,
		"target_hue": 0.93,
		"saturation_scale": 1.0,
		"value_scale": 1.0,
	},
]

## Pixels below this saturation are neutral ink and must never be recoloured.
const MIN_SATURATION: float = 0.18


func _initialize() -> void:
	for derivation: Dictionary in DERIVATIONS:
		_derive(derivation)
	quit(0)


func _derive(derivation: Dictionary) -> void:
	var source_path: String = SOURCE_DIRECTORY + str(derivation["source"])
	var output_path: String = SOURCE_DIRECTORY + str(derivation["output"])
	var source_texture: Texture2D = load(source_path) as Texture2D
	if source_texture == null:
		printerr("MISSING SOURCE: " + source_path)
		return
	var image: Image = source_texture.get_image()
	image.convert(Image.FORMAT_RGBA8)

	var hue_min: float = float(derivation["hue_min"])
	var hue_max: float = float(derivation["hue_max"])
	var target_hue: float = float(derivation["target_hue"])
	var saturation_scale: float = float(derivation["saturation_scale"])
	var value_scale: float = float(derivation["value_scale"])
	var band_center: float = (hue_min + hue_max) * 0.5
	var hue_delta: float = target_hue - band_center

	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.02 or pixel.s < MIN_SATURATION:
				continue
			# The red band wraps past 1.0, so compare in both windings.
			var hue: float = pixel.h
			var in_band: bool = (hue >= hue_min and hue <= hue_max)
			if not in_band and hue_max > 1.0:
				in_band = (hue + 1.0 >= hue_min and hue + 1.0 <= hue_max)
			if not in_band:
				continue
			var shifted: Color = Color.from_hsv(
				fposmod(hue + hue_delta, 1.0),
				clampf(pixel.s * saturation_scale, 0.0, 1.0),
				clampf(pixel.v * value_scale, 0.0, 1.0),
				pixel.a
			)
			image.set_pixel(x, y, shifted)

	var absolute_output: String = ProjectSettings.globalize_path(output_path)
	var error: int = image.save_png(absolute_output)
	if error != OK:
		printerr("WRITE FAILED (%d): %s" % [error, absolute_output])
		return
	print("DERIVED: %s -> %s" % [str(derivation["source"]), str(derivation["output"])])
