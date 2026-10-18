class_name SampleDishView
extends Control

## Raster specimens and bounded local-time material effects. Appearance never grades a sample.
enum Phase { BEFORE, CHANGING, AFTER }

const CHANGE_TIME: float = 2.6
const ART_ROOT := "res://assets/chemistry/sample_tray/"
const MATERIAL_SHADER: Shader = preload(ART_ROOT + "materials.gdshader")
const SPECIMENS: Texture2D = preload(ART_ROOT + "specimens.png")
const VESSEL_BACK: Texture2D = preload(ART_ROOT + "vessel_back.png")
const VESSEL_FRONT: Texture2D = preload(ART_ROOT + "vessel_front.png")
const PHYSICAL_MASKS: Texture2D = preload(ART_ROOT + "physical_masks.png")
const MOTION := preload("res://scripts/sample_material_motion.gd")
const PRESETS: PackedStringArray = [
	"burning_paper", "melting_ice", "breaking_glass", "dissolving_sugar",
	"rusting_iron", "melting_wax", "baking_soda_vinegar", "boiling_water",
	"cooking_egg", "tearing_cloth", "silver_tarnish", "magnet_attracting",
	"milk_souring", "salt_crystallising", "bronze_reaction", "stretching_spring",
]
const BEFORE_SIGNATURES: PackedStringArray = [
	"paper:solid", "water:solid", "glass:solid", "water:liquid|sugar:grains",
	"iron:solid", "wax:solid", "vinegar:liquid|soda:grains", "water:liquid",
	"egg_raw:liquid", "cloth:fibre", "silver:solid", "steel:bar|iron:pieces",
	"milk:liquid", "water:liquid|salt:dissolved", "bronze:solid", "steel:coil",
]
const SOUND_ONSETS: PackedFloat32Array = [
	0.16, 0.12, 0.60, 0.12, 0.0, 0.12, 0.16, 0.30,
	0.20, 0.416, 0.0, 1.248, 0.80, 0.65, 0.25, 1.04,
]

var before: PackedStringArray = PackedStringArray():
	set(value):
		before = value
		_refresh_material()
var after: PackedStringArray = PackedStringArray():
	set(value):
		after = value
		queue_redraw()
var sample_id: String = "":
	set(value):
		sample_id = value
		_refresh_material()
var allow_observation_marks: bool = false:
	set(value):
		allow_observation_marks = value
		queue_redraw()
## -1 ungraded, 0 incorrect, 1 correct. Only the controller writes the verdict.
var verdict: int = -1:
	set(value):
		verdict = value
		queue_redraw()

var _phase: int = Phase.BEFORE
var _phase_time: float = 0.0
var _effect_time: float = 0.0
var _surface: TextureRect
var _effect_material: ShaderMaterial
var _uniform_updates: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_surface = TextureRect.new()
	_surface.name = "MaterialSpecimen"
	_surface.show_behind_parent = true
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.texture = VESSEL_BACK
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_effect_material = ShaderMaterial.new()
	_effect_material.shader = MATERIAL_SHADER
	_effect_material.set_shader_parameter("specimens", SPECIMENS)
	_effect_material.set_shader_parameter("vessel_front", VESSEL_FRONT)
	_effect_material.set_shader_parameter("physical_masks", PHYSICAL_MASKS)
	_effect_material.set_shader_parameter("glass_origin", MOTION.glass_origins())
	_surface.material = _effect_material
	add_child(_surface)
	resized.connect(_layout_surface)
	visibility_changed.connect(_on_visibility_changed)
	_layout_surface()
	_refresh_material()
	set_process(is_playing())


func play() -> void:
	_phase = Phase.CHANGING
	_phase_time = 0.0
	_effect_time = 0.0
	verdict = -1
	set_process(true)
	_sync_effect()


func reset_dish() -> void:
	_phase = Phase.BEFORE
	_phase_time = 0.0
	_effect_time = 0.0
	verdict = -1
	set_process(false)
	_sync_effect()


func is_playing() -> bool:
	return _phase == Phase.CHANGING


func sound_onset_seconds() -> float:
	if _preset_index() == 2:
		return MOTION.IMPACT_TIME
	return SOUND_ONSETS[_preset_index()]


func is_time_lapse() -> bool:
	return _preset_index() not in [2, 9, 11, 15]


## Preserve the exact authored before/after set comparison; heat/glow is not a substance.
func new_substances() -> PackedStringArray:
	var had := {}
	for entry: String in before:
		had[entry.get_slice(":", 0)] = true
	var fresh := PackedStringArray()
	for entry: String in after:
		if entry.get_slice(":", 1) == "glow":
			continue
		var key: String = entry.get_slice(":", 0)
		if not had.has(key) and not fresh.has(key):
			fresh.append(key)
	return fresh


func effect_snapshot() -> Dictionary:
	var index := _preset_index()
	return {
		"preset": PRESETS[index],
		"preset_index": index,
		"phase": _phase,
		"progress": _progress(),
		"phase_time": _phase_time,
		"effect_time": _effect_time,
		"duration": CHANGE_TIME,
		"seed": _variation(),
		"visible": is_visible_in_tree(),
		"active": is_playing() and is_visible_in_tree(),
		"observation_marks": _marks_visible(),
		"uniform_updates": _uniform_updates,
		"raster_assets": 4,
		"time_lapse": is_time_lapse(),
		"sound_onset_seconds": sound_onset_seconds(),
		"emits_vapor": index in [0, 7, 14],
		"emits_bubbles": index in [6, 7],
		"emits_flame": index == 0,
	}


func _process(delta: float) -> void:
	if not is_playing():
		return
	# Hidden dishes finish controller bookkeeping without simulating particles or uploading uniforms.
	_phase_time = minf(CHANGE_TIME, _phase_time + maxf(0.0, delta))
	if is_visible_in_tree():
		_effect_time = minf(CHANGE_TIME, _effect_time + maxf(0.0, delta))
	if _phase_time >= CHANGE_TIME:
		_phase = Phase.AFTER
		set_process(false)
	if is_visible_in_tree():
		_sync_effect()


func _preset_index() -> int:
	var index := PRESETS.find(sample_id)
	if index < 0:
		index = BEFORE_SIGNATURES.find("|".join(before))
	return maxi(0, index)


func _variation() -> float:
	return float(PRESETS[_preset_index()].hash() % 10007) / 10007.0


func _progress() -> float:
	if _phase == Phase.AFTER:
		return 1.0
	return clampf(_phase_time / CHANGE_TIME, 0.0, 1.0) if is_playing() else 0.0


func _layout_surface() -> void:
	if not is_instance_valid(_surface):
		return
	var fit := minf(size.x / 300.0, size.y / 110.0)
	_surface.size = Vector2(300.0, 110.0) * maxf(0.0, fit)
	_surface.position = ((size - _surface.size) * 0.5).floor()


func _refresh_material() -> void:
	if not is_instance_valid(_effect_material):
		return
	_effect_material.set_shader_parameter("preset", _preset_index())
	_effect_material.set_shader_parameter("variation", _variation())
	_effect_material.set_shader_parameter("event_onset", sound_onset_seconds())
	_sync_effect()


func _sync_effect() -> void:
	if not is_instance_valid(_effect_material) or not is_visible_in_tree():
		return
	_effect_material.set_shader_parameter("progress", _progress())
	_effect_material.set_shader_parameter("local_time", _effect_time)
	_effect_material.set_shader_parameter("active", is_playing())
	if _preset_index() == 1:
		var ice: Dictionary = MOTION.ice_at(_progress() * CHANGE_TIME)
		_effect_material.set_shader_parameter("ice_state", Vector4(ice["cut"], ice["bottom"], ice["water_volume"], ice["solid_volume"]))
	elif _preset_index() == 2:
		var glass: Dictionary = MOTION.glass_at(_progress() * CHANGE_TIME)
		_effect_material.set_shader_parameter("glass_pose", glass["poses"])
		_effect_material.set_shader_parameter("glass_fractured", glass["fractured"])
	_uniform_updates += 1
	queue_redraw()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_sync_effect()


func _marks_visible() -> bool:
	return allow_observation_marks and verdict >= 0 and _phase == Phase.AFTER


func _draw() -> void:
	if verdict >= 0:
		var edge := Color("#8eb887") if verdict == 1 else Color("#c67865")
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), edge, false, 1.0)
	if _marks_visible():
		for index: int in range(new_substances().size()):
			draw_rect(Rect2(7.0 + index * 8.0, 7.0, 4.0, 4.0), Color("#c6b384"))
