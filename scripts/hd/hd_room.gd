extends RefCounted

## The HD look of an interior room. tools/blender/room_prototype.py rebuilds a
## room in 3D on its own collision, and tools/blender/publish_hd.py publishes
## what the game draws under assets/hd/rooms/<room>/ (hd_data.gd):
##   render.webp           the room without its interactive props, 2 px per px;
##   render.json           its region, render scale and figure scale, any
##                         footprint it changes ("collision") and any
##                         interaction box it changes ("interactions");
##   render-glows.json     the candles' and crystals' halos;
##   render-depth.png      every wall and fixed piece's own ground y;
##   render-props.json     each interactive prop rendered alone, cut where the
##                         room stands in front of it, and the rect it shows.
## Staging lays the render over the painted room, draws each prop node's
## Visual sprite with its HD render, hides the figures where the room stands
## in front of them, and draws the characters in HD. The room's script read its
## props' highlight boxes and walk-up points off those sprites when it loaded,
## so staging reads them again from the HD props, and restoring from the
## painted ones; a prop's mouse hotspot follows its HD prop too. Collision,
## prompts and every story step stay the game's own, but for a footprint the
## HD room changes (a table built at a real table's size), whose polygon is
## swapped in while the room is staged, and likewise an interaction box it
## changes (a stain the HD room draws smaller than the painting's).
## A room whose script keeps its own light rig (the Circuit Room's
## `ambience_layer`) has that rig lifted above the render and each fixture
## render.json lists ("fixtures": from the painted spot to the HD one) moved
## onto the lamp, lantern or arc the render draws, so the rig's power states
## still play on the HD room.

const ROOMS: Dictionary = {
	"res://scenes/wake_room.tscn": "wake_room",
	"res://scenes/floor_1/greenhouse_room.tscn": "greenhouse_room",
	"res://scenes/floor_1/chemistry_room.tscn": "chemistry_room",
	"res://scenes/floor_1/library_room.tscn": "library_room",
	"res://scenes/floor_1/dining_hall_room.tscn": "dining_hall_room",
	"res://scenes/floor_1/circuit_room.tscn": "circuit_room",
	"res://scenes/floor_1/final_room.tscn": "final_room",
}
## A room's own living layer over its look, loaded with the room so one room's
## layer cannot keep another from staging: the Library's light and shots.
const EXTRAS: Dictionary = {"library_room": "res://scripts/hd/hd_library.gd"}
const HDData := preload("res://scripts/hd/hd_data.gd")
const DATA := HDData.ROOMS
const CHARACTER_DATA := HDData.CHARACTERS
const OVERLAY_NAME := "BlenderRoomOverlay"
## A room's figures stand 2.64 times their Hall size (VisualRoot scale 2,
## without the Hall's shrink), and so do their contact shadows.
const ROOM_SHADOW := Vector2(48.0, 15.0)
const Glows := preload("res://scripts/hd/hd_glows.gd")
const Props := preload("res://scripts/hd/hd_props.gd")
const Depth := preload("res://scripts/hd/hd_depth.gd")
const Characters := preload("res://scripts/hd/hd_characters.gd")

var room: Node
var overlay: Sprite2D
var glows: Glows
var props: Props
var depth: Depth
var characters: Characters
## The room's EXTRAS layer (attach/apply/restore/advance/summary), or null.
var extras: RefCounted
var meta: Dictionary = {}
var halos := 0
var swapped := 0
var sheets := 0
var has_depth := false
## {"polygon", "painted", "hd"} for each collision polygon the HD room changes.
var footprints: Array[Dictionary] = []
## {"property", "painted", "hd"} for each interaction box the HD room changes.
var interactions: Array[Dictionary] = []
## {"shape", "painted", "disabled"} for each prop hotspot reshaped round its
## HD prop while the room is staged.
var hotspots: Array[Dictionary] = []
## The room's own light rig and the fixtures moved with it: {node, from, to}.
var rig: Node2D
var rig_z := 0
var rig_moves: Array[Dictionary] = []


## The HD room a scene shows, or "" for any other scene.
static func room_for(scene_path: String) -> String:
	return str(ROOMS.get(scene_path, ""))


## Loads `name`'s render under `room_node`, hidden until apply(). False if the
## room has not been rendered.
func attach(room_node: Node, name: String) -> bool:
	room = room_node
	var data_dir := DATA + name + "/"
	var parsed: Variant = HDData.json(data_dir + "render.json")
	if not (parsed is Dictionary):
		push_warning("No HD room render under " + data_dir)
		return false
	var texture := HDData.texture(data_dir + str((parsed as Dictionary).get("image", "render.webp")))
	if texture == null:
		push_warning("HD room render unreadable under " + data_dir)
		return false
	meta = parsed as Dictionary
	_read_footprints()
	_read_interactions()
	var region: Array = meta["region"]
	var render_scale := float(meta.get("render_scale", 2.0))
	var origin := Vector2(float(region[0]), float(region[1]))
	overlay = Sprite2D.new()
	overlay.name = OVERLAY_NAME
	overlay.texture = texture
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
	if EXTRAS.has(name):
		var layer := load(str(EXTRAS[name])) as GDScript
		extras = layer.new() if layer != null else null
		if extras != null and not bool(extras.call("attach", room, self)):
			extras = null
	_attach_rig()
	return true


## Shows the room in HD.
func apply() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.visible = true
	props.apply()
	_swap_footprints(true)
	_swap_interactions(true)
	_resync()
	_swap_hotspots(true)
	if has_depth:
		depth.apply()
	characters.apply()
	if extras != null:
		extras.call("apply")
	if rig != null and is_instance_valid(rig):
		# Above the render and its halos, still below the props and figures.
		rig.z_index = overlay.z_index + 2
		for move: Dictionary in rig_moves:
			if is_instance_valid(move["node"]):
				(move["node"] as Node2D).position = move["to"]


## Puts the painted room back, exactly as the scene had it.
func restore() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	if extras != null:
		extras.call("restore")
	if rig != null and is_instance_valid(rig):
		rig.z_index = rig_z
		for move: Dictionary in rig_moves:
			if is_instance_valid(move["node"]):
				(move["node"] as Node2D).position = move["from"]
	characters.restore()
	if has_depth:
		depth.restore()
	props.restore()
	_swap_footprints(false)
	_swap_interactions(false)
	_swap_hotspots(false)
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
	if extras != null:
		extras.call("advance", delta)


func summary() -> String:
	var cast := characters.cast if characters != null else 0
	var text := "%s: %d glows, %d HD props, depth %s, %d HD character sheets, %d of the cast" % [
		meta.get("room", "?"), halos, swapped, has_depth, sheets, cast,
	]
	if not rig_moves.is_empty():
		text += ", %d fixtures moved" % rig_moves.size()
	if extras != null:
		text += "; " + str(extras.call("summary"))
	return text


## Finds the room's light rig and pairs each of its lamps and arc emitters
## with the HD fixture render.json moves it to, by where the rig stands it.
func _attach_rig() -> void:
	var layer: Variant = room.get("ambience_layer")
	var fixtures: Array = meta.get("fixtures", [])
	if not (layer is Node2D) or fixtures.is_empty():
		return
	rig = layer as Node2D
	rig_z = rig.z_index
	for child: Node in rig.get_children():
		var node := child as Node2D
		if node == null:
			continue
		for fixture: Dictionary in fixtures:
			var from: Array = fixture["from"]
			var to: Array = fixture["to"]
			if node.position.distance_to(Vector2(float(from[0]), float(from[1]))) < 1.0:
				rig_moves.append({
					"node": node, "from": node.position, "to": Vector2(float(to[0]), float(to[1])),
				})
				break


## The room's highlight boxes, prompt anchors and walk-up points follow the
## props' Visual sprites (wake_room.gd create_prop_interactions and
## _sync_door_interaction; greenhouse_room.gd _sync_interaction_footprints;
## final_room.gd _sync_authored_interaction_positions).
func _resync() -> void:
	if not is_instance_valid(room):
		return
	if room.has_method("_sync_interaction_footprints"):
		room.call("_sync_interaction_footprints")
	if room.has_method("_sync_authored_interaction_positions"):
		room.call("_sync_authored_interaction_positions")
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
	if room.has_method("_sync_door_interaction"):
		room.call("_sync_door_interaction")


## The collision render.json changes ({node path: world px points}), with
## the scene's own: a polygon's points, or a CollisionShape2D's shape and
## place. A path the scene lacks is a footprint the HD room adds, as a
## CollisionPolygon2D under the body the path names (furniture the painting
## lets the player walk through). The HD shapes are made as the room is
## staged, from world px, so a prop render that moves or scales a shape's
## parent (the Final Room's sprites carry their own collision) is allowed for.
func _read_footprints() -> void:
	footprints.clear()
	var listed: Variant = meta.get("collision", {})
	if not listed is Dictionary:
		return
	for path: Variant in (listed as Dictionary).keys():
		var world := PackedVector2Array()
		for point: Variant in (listed as Dictionary)[path]:
			world.append(Vector2(float(point[0]), float(point[1])))
		var node := room.get_node_or_null(NodePath(str(path)))
		var body := room.get_node_or_null(NodePath(str(path).get_base_dir()))
		if node is CollisionPolygon2D:
			var polygon := node as CollisionPolygon2D
			footprints.append({"polygon": polygon, "painted": polygon.polygon, "world": world})
		elif node is CollisionShape2D:
			var holder := node as CollisionShape2D
			footprints.append({
				"holder": holder, "painted": holder.shape, "painted_at": holder.position, "world": world,
			})
		elif node == null and body is CollisionObject2D:
			footprints.append({"body": body, "name": str(path).get_file(), "world": world})
		else:
			push_warning("No collision polygon, shape or body for the footprint at " + str(path))


func _swap_footprints(hd: bool) -> void:
	for footprint: Dictionary in footprints:
		var world: PackedVector2Array = footprint["world"]
		if footprint.has("polygon"):
			var polygon := footprint["polygon"] as CollisionPolygon2D
			if is_instance_valid(polygon):
				polygon.polygon = _to_local(polygon, world) if hd else footprint["painted"]
		elif footprint.has("holder"):
			var holder := footprint["holder"] as CollisionShape2D
			if not is_instance_valid(holder):
				continue
			if not hd:
				holder.shape = footprint["painted"]
				holder.position = footprint["painted_at"]
			elif footprint["painted"] is RectangleShape2D:
				# A rectangle stays one, round the corners: its own copy, so a
				# shape the scene shares between nodes is never changed.
				var bounds := Rect2(world[0], Vector2.ZERO)
				for point: Vector2 in world:
					bounds = bounds.expand(point)
				var rectangle := (footprint["painted"] as RectangleShape2D).duplicate() as RectangleShape2D
				rectangle.size = bounds.size / holder.global_scale.abs()
				holder.shape = rectangle
				holder.global_position = bounds.get_center()
			else:
				# A capsule or circle becomes the HD prop's own outline.
				var outline := ConvexPolygonShape2D.new()
				outline.set_point_cloud(_to_local(holder, world))
				holder.shape = outline
			# The prop render moved or scaled the body the shape hangs from
			# (the Final Room's collision hangs under its sprites): its place
			# reaches the physics server now, not at the next transform flush,
			# or for a frame the swapped shape stands at the other look's scale.
			var body := holder.get_parent() as CollisionObject2D
			if body != null:
				body.force_update_transform()
		else:
			if hd and not footprint.has("added"):
				var added := CollisionPolygon2D.new()
				added.name = str(footprint["name"])
				(footprint["body"] as Node).add_child(added)
				added.polygon = _to_local(added, world)
				footprint["added"] = added
			elif not hd and footprint.has("added"):
				var made: Variant = footprint["added"]
				footprint.erase("added")
				if is_instance_valid(made):
					(made as Node).get_parent().remove_child(made)
					(made as Node).free()


## The interaction boxes render.json changes ({id: [x, y, w, h]}): a thing the
## HD room draws at another size or place than the painting does, where the
## room's script boxes it with a fixed rect read off the painting (the
## Chemistry Room's red stain). The room keeps that box in a property named
## <id>_interaction_rect; staging sets the HD box there, restoring the
## painted one.
func _read_interactions() -> void:
	interactions.clear()
	var listed: Variant = meta.get("interactions", {})
	if not listed is Dictionary:
		return
	for id: Variant in (listed as Dictionary).keys():
		var box: Array = (listed as Dictionary)[id]
		var property := str(id) + "_interaction_rect"
		var painted: Variant = room.get(property)
		if not painted is Rect2 or box.size() != 4:
			push_warning("No interaction box %s on the room for the HD one" % property)
			continue
		interactions.append({
			"property": property, "painted": painted,
			"hd": Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])),
		})


func _swap_interactions(hd: bool) -> void:
	for entry: Dictionary in interactions:
		room.set(str(entry["property"]), entry["hd"] if hd else entry["painted"])


## A Wake Room prop takes clicks on its Area2D's own shapes (a Hotspot box and
## a polygon), drawn round the painted prop. While the room is staged those
## shapes stand down and a box round the HD prop takes the clicks, so the bed's
## pillow and the bookshelf's top answer a click where the HD room draws them.
## The room's walk planner copied the polygons when it loaded, so its
## obstacles do not change.
func _swap_hotspots(hd: bool) -> void:
	if not hd:
		for hotspot: Dictionary in hotspots:
			var shape: Variant = hotspot["shape"]
			if is_instance_valid(shape):
				(shape as Node).get_parent().remove_child(shape)
				(shape as Node).free()
			var painted: Array[Node2D] = hotspot["painted"]
			for index in painted.size():
				if is_instance_valid(painted[index]):
					painted[index].set("disabled", hotspot["disabled"][index])
		hotspots.clear()
		return
	var listed: Variant = room.get("props")
	if not listed is Dictionary or not hotspots.is_empty():
		return
	var spatial := RoomSpatialRuntime.new()
	for id: Variant in (listed as Dictionary).keys():
		var area := room.get_node_or_null("Props/" + str(id).capitalize()) as Area2D
		if area == null:
			continue
		var rect := spatial.get_visual_rect(area)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var painted: Array[Node2D] = []
		var disabled: Array[bool] = []
		for child: Node in area.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				painted.append(child as Node2D)
				disabled.append(bool(child.get("disabled")))
				child.set("disabled", true)
		var box := RectangleShape2D.new()
		box.size = rect.size / area.global_scale.abs()
		var shape := CollisionShape2D.new()
		shape.name = "BlenderHotspot"
		shape.shape = box
		area.add_child(shape)
		shape.global_position = rect.get_center()
		hotspots.append({"shape": shape, "painted": painted, "disabled": disabled})


func _to_local(node: Node2D, world: PackedVector2Array) -> PackedVector2Array:
	var to_local := node.global_transform.affine_inverse()
	var points := PackedVector2Array()
	for point: Vector2 in world:
		points.append(to_local * point)
	return points
