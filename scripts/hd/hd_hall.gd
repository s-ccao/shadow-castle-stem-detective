extends RefCounted

## The Hall's HD look, staged whenever the Hall (game_world.tscn) loads.
## hall_prototype.py rebuilds the whole Hall in Blender on its collision and
## tools/blender/publish_hd.py publishes it under assets/hd/hall/: one render
## laid over the painted Hall (above its floor and walls, below its exhibits,
## props, figures, footprint trail and fog), the lanterns' and candles' living
## light, each interactive prop on its stand with its node moved to it (so its
## prompt and focus box follow), each door's leaves opening for a player at
## it, the depth pass that hides figures behind walls, and the detective and
## the Guardian in HD. Collision, fog, the route, the Guardian's behaviour and
## saves are the game's own.

const SCENE := "res://scenes/game_world.tscn"
const OVERLAY_NAME := "BlenderPrototypeOverlay"
const RENDER_SCALE := 2.0
const HDData := preload("res://scripts/hd/hd_data.gd")
const DATA := HDData.HALL
const Glows := preload("res://scripts/hd/hd_glows.gd")
const Props := preload("res://scripts/hd/hd_props.gd")
const Depth := preload("res://scripts/hd/hd_depth.gd")
const Doors := preload("res://scripts/hd/hd_doors.gd")
const Characters := preload("res://scripts/hd/hd_characters.gd")

var hall: Node
var overlay: Sprite2D
var glows: Glows
var props: Props
var depth: Depth
var doors: Doors
var characters: Characters
var region: Array = []
var halos := 0
var swapped := 0
var door_count := 0
var has_depth := false
var depth_props := 0
var sheets := 0


## Lays the HD Hall over `hall_node` and stages its props, doors, depth and
## figures. False (the Hall left painted) if the render is missing.
func attach(hall_node: Node) -> bool:
	hall = hall_node
	var meta: Variant = HDData.json(DATA + "region.json")
	var texture := HDData.texture(DATA + "render.webp", true)
	if not (meta is Dictionary) or texture == null:
		push_warning("HD Hall render or region.json is missing under " + DATA)
		return false
	region = (meta as Dictionary)["region"]
	overlay = Sprite2D.new()
	overlay.name = OVERLAY_NAME
	overlay.texture = texture
	overlay.centered = false
	overlay.position = Vector2(float(region[0]), float(region[1]))
	overlay.scale = Vector2.ONE / RENDER_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Above the old floor (-100) and walls (-50); below exhibits, props, the
	# player, the footprint trail and the fog.
	overlay.z_index = -40
	hall.add_child(overlay)
	glows = Glows.new()
	halos = glows.attach(overlay, DATA + "render-glows.json", overlay.position, RENDER_SCALE)
	props = Props.new()
	swapped = props.attach(hall, DATA + "render-props.json", DATA, RENDER_SCALE)
	props.apply()
	doors = Doors.new()
	door_count = doors.attach(hall, DATA + "render-doors.json", DATA, RENDER_SCALE)
	hall.add_child(doors)
	doors.apply()
	depth = Depth.new()
	has_depth = depth.attach(hall, DATA + "render-depth.png", region)
	if has_depth:
		for item: Dictionary in props.standing():
			depth.add_fixed(item["sprite"], item["feet"])
		depth_props = depth.add_props((meta as Dictionary).get("props", {}))
		depth.apply()
	characters = Characters.new()
	sheets = characters.attach(hall, HDData.CHARACTERS)
	characters.apply()
	return true


## Call before the game's bodies move in each physics tick.
func track(delta: float) -> void:
	if characters != null:
		characters.track(delta)


func advance(delta: float) -> void:
	if glows != null:
		glows.advance(delta)
	if has_depth and depth != null:
		depth.advance(delta)
	if characters != null:
		characters.advance(delta)


func summary() -> String:
	var figures := characters.staged() if characters != null else 0
	var text := (
		"region %s, %d glows, %d HD props, %d doors, depth %s (%d props), "
		+ "%d HD character sheets (%d figures)"
	)
	return text % [region, halos, swapped, door_count, has_depth, depth_props, sheets, figures]
