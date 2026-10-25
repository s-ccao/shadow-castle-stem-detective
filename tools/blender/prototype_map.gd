extends RefCounted

## The HUD's maps in HD for the Blender prototype. The Map Hub (MapHud,
## scripts/map_hud.gd) draws the Hall from one image,
## assets/backgrounds/hall_map_hub.png, in its map panel and in the Guardian's
## minimap, and the Circuit Room's repair map from that room's painted
## background. hall_prototype.py --map renders the Blender Hall from straight
## above into prototypes/blender_hall/map.png, framed on the map's world rect
## and drawn at the map's size, so map_hud.gd's projection
## (x * 1448 / 1920, y * 1086 / 1280) lands on it unchanged. The repair map's
## board is the Circuit Room's HD render with its props laid back in, at the
## painted background's size, so its switch markers land as before.
##
## MapHud is an autoload: it builds its panel and minimap at start, and the
## repair map the first time it opens. So the HD look sets those TextureRects'
## textures itself, at once and on each sync() while it shows (the repair map
## may open later), drawn smoothly with mipmaps; the painted look gives back
## the game's own textures and filters. The state is shared (static): the Hall
## and each room stage their looks separately.

const HALL_MAP := "res://prototypes/blender_hall/map.png"
const CIRCUIT_DATA := "res://prototypes/blender_rooms/circuit_room/"
const MAP_HUD := "MapHud"
const CIRCUIT_TEXTURE := "res://assets/backgrounds/circuit_room_workshop.png"
## The painted room backgrounds' size, which the repair map's markers assume.
const ROOM_SIZE := Vector2i(1448, 1086)
const GAME_META := "prototype_game_map"
const FILTER_META := "prototype_game_map_filter"

static var hall_map: Texture2D
static var circuit_map: Texture2D
static var showing := false
## The repair map's board, once it has been built.
static var repair_board: TextureRect


## Loads the HD maps (once). Returns how many there are.
static func attach() -> int:
	if hall_map == null:
		var image := Image.load_from_file(ProjectSettings.globalize_path(HALL_MAP))
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			hall_map = ImageTexture.create_from_image(image)
		else:
			push_warning("No prototype Hall map at " + HALL_MAP)
	if circuit_map == null:
		circuit_map = _room_map(CIRCUIT_DATA)
	return int(hall_map != null) + int(circuit_map != null)


## Shows the HD maps (or the game's own) from now on.
static func stage(hd_look: bool, tree: SceneTree) -> void:
	showing = hd_look
	sync(tree, true)


## Puts the shown look's maps into MapHud's TextureRects; `all` checks every
## one, otherwise only a repair map that has opened since.
static func sync(tree: SceneTree, all: bool = false) -> void:
	var hud := tree.root.get_node_or_null(MAP_HUD)
	if hud == null:
		return
	if all:
		_show(hud.get("map_texture_rect") as TextureRect, hall_map)
		_show(hud.find_child("GuardianMiniMapTexture", true, false) as TextureRect, hall_map)
	var repair := hud.get("repair_overlay") as Control
	if repair != null and (repair_board == null or not is_instance_valid(repair_board)):
		for node: Node in repair.find_children("*", "TextureRect", true, false):
			var rect := node as TextureRect
			if rect.texture != null and rect.texture.resource_path == CIRCUIT_TEXTURE:
				repair_board = rect
				all = true
				break
	if all and repair_board != null and is_instance_valid(repair_board):
		_show(repair_board, circuit_map)


static func _show(rect: TextureRect, hd_texture: Texture2D) -> void:
	if rect == null or hd_texture == null:
		return
	if not rect.has_meta(GAME_META):
		rect.set_meta(GAME_META, rect.texture)
		rect.set_meta(FILTER_META, rect.texture_filter)
	if showing:
		rect.texture = hd_texture
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		rect.texture = rect.get_meta(GAME_META) as Texture2D
		rect.texture_filter = rect.get_meta(FILTER_META)


## A room's HD render with its props laid back in where they stand, at the
## painted background's size: the room as a map shows it.
static func _room_map(data_dir: String) -> Texture2D:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "render.json"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + "render.png"))
	if not (meta is Dictionary) or image == null or image.is_empty():
		push_warning("No prototype room render under " + data_dir)
		return null
	var scale := float((meta as Dictionary).get("render_scale", 2.0))
	image.convert(Image.FORMAT_RGBA8)
	var props_path := data_dir + "render-props.json"
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(props_path))
	if listed is Dictionary:
		for prop: Dictionary in (listed as Dictionary).get("props", []):
			var layer := Image.load_from_file(ProjectSettings.globalize_path(data_dir + str(prop["image"])))
			if layer == null or layer.is_empty():
				continue
			layer.convert(Image.FORMAT_RGBA8)
			var rect: Array = prop["rect"]
			var at := Vector2i(roundi(float(rect[0]) * scale), roundi(float(rect[1]) * scale))
			image.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), at)
	image.resize(ROOM_SIZE.x, ROOM_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
