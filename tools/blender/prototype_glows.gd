extends RefCounted

## Living light over the Blender prototype render: lanterns and candles
## flicker, crystals, grates, runes and the portraits' eyes pulse slowly.
## hall_prototype.py writes the glows beside the render (<render>-glows.json)
## in screen-space game px. Each becomes an additive halo parented to the
## overlay, so hiding the overlay hides them, and the Hall's fog still
## covers them.

## strength: halo alpha at rest; depth: how far it swings; speed: changes per second.
const KINDS: Dictionary = {
	"lantern": {"strength": 0.3, "depth": 0.22, "speed": 5.0},
	"candle": {"strength": 0.4, "depth": 0.35, "speed": 8.0},
	"potion": {"strength": 0.28, "depth": 0.2, "speed": 1.2},
	"crystal": {"strength": 0.32, "depth": 0.45, "speed": 0.6},
	"grate": {"strength": 0.3, "depth": 0.4, "speed": 0.4},
	"runes": {"strength": 0.14, "depth": 0.5, "speed": 0.25},
	"eyes": {"strength": 0.45, "depth": 0.9, "speed": 0.18},
}
const HALO_SIZE := 64

var halos: Array[Sprite2D] = []
var rest: PackedFloat32Array = []
var swing: PackedFloat32Array = []
var pace: PackedFloat32Array = []
var noise := FastNoiseLite.new()
var clock := 0.0


## Adds one halo per glow under `overlay`, the render sprite placed at
## `origin` with scale 1 / `render_scale`. Returns how many it added.
func attach(overlay: Sprite2D, path: String, origin: Vector2, render_scale: float) -> int:
	if not FileAccess.file_exists(path):
		push_warning("No prototype glows at " + path)
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return 0
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_octaves = 2
	var texture := _halo_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for glow: Dictionary in (data as Dictionary).get("glows", []):
		var kind: Dictionary = KINDS.get(str(glow.get("kind", "")), KINDS["lantern"])
		var tint: Array = glow.get("color", [1.0, 1.0, 1.0])
		var halo := Sprite2D.new()
		halo.texture = texture
		halo.material = additive
		halo.position = (Vector2(float(glow["x"]), float(glow["y"])) - origin) * render_scale
		halo.scale = Vector2.ONE * float(glow.get("radius", 12.0)) * 2.0 * render_scale / HALO_SIZE
		halo.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(kind["strength"]))
		halo.z_index = 1
		overlay.add_child(halo)
		halos.append(halo)
		rest.append(float(kind["strength"]))
		swing.append(float(kind["depth"]))
		pace.append(float(kind["speed"]))
	return halos.size()


## Moves every halo's brightness along its own stretch of noise.
func advance(delta: float) -> void:
	clock += delta
	for index in halos.size():
		var halo := halos[index]
		if not is_instance_valid(halo):
			continue
		var wave := noise.get_noise_2d(clock * pace[index], float(index) * 31.7)
		halo.modulate.a = rest[index] * maxf(1.0 + swing[index] * wave * 1.6, 0.0)


func _halo_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.3, Color(1, 1, 1, 0.55))
	gradient.add_point(0.65, Color(1, 1, 1, 0.12))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = HALO_SIZE
	texture.height = HALO_SIZE
	return texture
