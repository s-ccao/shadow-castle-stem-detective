extends RefCounted

## The HD look of an interior room for the Blender prototype. room_prototype.py
## rebuilds a room in 3D on its own collision and writes, under
## prototypes/blender_rooms/<room>/:
##   render.png            the room without its interactive props, 2 px per px;
##   render.json           its region, render scale and figure scale, and
##                         any footprint it changes ("collision");
##   render-glows.json     the candles' and crystals' halos;
##   render-depth.png      every wall and fixed piece's own ground y;
##   render-props.json     each interactive prop rendered alone, cut where the
##                         room stands in front of it, and the rect it shows.
## Staging lays the render over the painted room, draws each prop node's
## Visual sprite with its HD render, hides the figures where the room stands
## in front of them, and draws the characters in HD. The room's script read its
## props' highlight boxes and walk-up points off those sprites when it loaded,
## so staging reads them again from the HD props, and restoring from the
## painted ones. Collision, prompts and every story step stay the game's own,
## but for a footprint the HD room changes (a table built at a real table's
## size), whose polygon is swapped in while the room is staged.

const ROOMS: Dictionary = {
	"res://scenes/wake_room.tscn": "wake_room",
	"res://scenes/floor_1/greenhouse_room.tscn": "greenhouse_room",
	"res://scenes/floor_1/chemistry_room.tscn": "chemistry_room",
}
const DATA := "res://prototypes/blender_rooms/"
const CHARACTER_DATA := "res://prototypes/blender_chars/"
const OVERLAY_NAME := "BlenderRoomOverlay"
## A room's figures stand 2.64 times their Hall size (VisualRoot scale 2,
## without the Hall's shrink), and so do their contact shadows.
const ROOM_SHADOW := Vector2(48.0, 15.0)
const Glows := preload("res://tools/blender/prototype_glows.gd")
const Props := preload("res://tools/blender/prototype_props.gd")
const Depth := preload("res://tools/blender/prototype_depth.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")

var room: Node
var overlay: Sprite2D
var glows: Glows
var props: Props
var depth: Depth
var characters: Characters
var meta: Dictionary = {}
var halos := 0
var swapped := 0
var sheets := 0
var has_depth := false
## {"polygon", "painted", "hd"} for each collision polygon the HD room changes.
var footprints: Array[Dictionary] = []


## The prototype room a scene shows, or "" for any other scene.
static func room_for(scene_path: String) -> String:
	return str(ROOMS.get(scene_path, ""))


## Loads `name`'s render under `room_node`, hidden until apply(). False if the
## room has not been rendered.
func attach(room_node: Node, name: String) -> bool:
	room = room_node
	var data_dir := DATA + name + "/"
	if not FileAccess.file_exists(data_dir + "render.json"):
		push_warning("No prototype room render under " + data_dir)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "render.json"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + "render.png"))
	if not (parsed is Dictionary) or image == null:
		push_warning("Prototype room render unreadable under " + data_dir)
		return false
	meta = parsed as Dictionary
	_read_footprints()
	var region: Array = meta["region"]
	var render_scale := float(meta.get("render_scale", 2.0))
	var origin := Vector2(float(region[0]), float(region[1]))
	overlay = Sprite2D.new()
	overlay.name = OVERLAY_NAME
	overlay.texture = ImageTexture.create_from_image(image)
	overlay.centered = false
	overlay.position = origin
	overlay.scale = Vector2.ONE / render_scale
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Above the painted room (-100); below the props, the player and the HUD.
	overlay.z_index = -40
	overlay.visible = false
	room.add_child(overlay)
	glows = Glows.new()
	halos = glows.attach(overlay, data_dir + "render-glows.json", origin, render_scale)
	props = Props.new()
	swapped = props.attach(room, data_dir + "render-props.json", data_dir, render_scale)
	depth = Depth.new()
	depth.figure_scale = float(meta.get("figure_scale", 1.0))
	depth.shadow_size = ROOM_SHADOW
	has_depth = depth.attach(room, data_dir + str(meta.get("depth", "render-depth.png")), region)
	if has_depth:
		for item: Dictionary in props.standing():
			depth.add_fixed(item["sprite"], item["feet"])
	characters = Characters.new()
	sheets = characters.attach(room, CHARACTER_DATA)
	return true


## Shows the room in HD.
func apply() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.visible = true
	props.apply()
	_swap_footprints(true)
	_resync()
	if has_depth:
		depth.apply()
	characters.apply()


## Puts the painted room back, exactly as the scene had it.
func restore() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	characters.restore()
	if has_depth:
		depth.restore()
	props.restore()
	_swap_footprints(false)
	_resync()
	overlay.visible = false


## Call from the SceneTree's _physics_process, before the game's bodies move.
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
	return "%s: %d glows, %d HD props, depth %s, %d HD character sheets" % [
		meta.get("room", "?"), halos, swapped, has_depth, sheets,
	]


## The room's highlight boxes, prompt anchors and walk-up points follow the
## props' Visual sprites (wake_room.gd create_prop_interactions/create_door;
## greenhouse_room.gd _sync_interaction_footprints).
func _resync() -> void:
	if not is_instance_valid(room):
		return
	if room.has_method("_sync_interaction_footprints"):
		room.call("_sync_interaction_footprints")
	var spatial := RoomSpatialRuntime.new()
	var listed: Variant = room.get("props")
	if listed is Dictionary:
		for id: Variant in (listed as Dictionary).keys():
			var area := room.get_node_or_null("Props/" + str(id).capitalize())
			var entry: Variant = (listed as Dictionary)[id]
			if area == null or not (entry is Dictionary):
				continue
			var rect := spatial.get_visual_rect(area)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			var prop := entry as Dictionary
			prop["interaction_rect"] = rect
			prop["focus_position"] = rect.get_center()
			if room.has_method("_get_visual_interaction_approach"):
				prop["position"] = room.call(
					"_get_visual_interaction_approach", rect, prop.get("position", rect.get_center())
				)
	var door := room.get_node_or_null("Props/Door")
	if door != null and room.get("door_interaction_rect") is Rect2:
		var rect := spatial.get_visual_rect(door)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			room.set("door_interaction_rect", rect)

## The collision polygons render.json changes, with the scene's own points.
func _read_footprints() -> void:
	footprints.clear()
	var listed: Variant = meta.get("collision", {})
	if not listed is Dictionary:
		return
	for path: Variant in (listed as Dictionary).keys():
		var polygon := room.get_node_or_null(NodePath(str(path))) as CollisionPolygon2D
		if polygon == null:
			push_warning("No collision polygon to swap at " + str(path))
			continue
		var to_local := polygon.global_transform.affine_inverse()
		var points := PackedVector2Array()
		for point: Variant in (listed as Dictionary)[path]:
			points.append(to_local * Vector2(float(point[0]), float(point[1])))
		footprints.append({"polygon": polygon, "painted": polygon.polygon, "hd": points})


func _swap_footprints(hd: bool) -> void:
	for footprint: Dictionary in footprints:
		var polygon := footprint["polygon"] as CollisionPolygon2D
		if is_instance_valid(polygon):
			polygon.polygon = footprint["hd"] if hd else footprint["painted"]
