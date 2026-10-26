extends RefCounted

## The HUD's maps in HD. The Map Hub (MapHud, scripts/map_hud.gd) draws the
## Hall from one image, assets/backgrounds/hall_map_hub.png, in its map panel
## and in the Guardian's minimap, and the Circuit Room's repair map from that
## room's painted background. hall_prototype.py --map renders the Blender Hall
## from straight above, framed on the map's world rect and drawn at the map's
## size, so map_hud.gd's projection (x * 1448 / 1920, y * 1086 / 1280) lands on
## it unchanged. The repair map's board is the Circuit Room's HD render with
## its props laid back in, at the painted background's size, so its switch
## markers land as before. tools/blender/publish_hd.py publishes both under
## assets/hd/maps/, imported with mipmaps.
##
## MapHud is an autoload: it builds its panel and minimap at start, and the
## repair map the first time it opens. So the HD look sets those TextureRects'
## textures itself, at once and on each sync() while it shows (the repair map
## may open later), drawn smoothly with mipmaps; the painted look gives back
## the game's own textures and filters. The state is shared (static): the Hall
## and each room stage their looks separately.

const HDData := preload("res://scripts/hd/hd_data.gd")
const HALL_MAP := HDData.MAPS + "hall_map.webp"
const CIRCUIT_MAP := HDData.MAPS + "circuit_repair.webp"
const MAP_HUD := "MapHud"
const CIRCUIT_TEXTURE := "res://assets/backgrounds/circuit_room_workshop.png"
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
		hall_map = HDData.texture(HALL_MAP, true)
		if hall_map == null:
			push_warning("No HD Hall map at " + HALL_MAP)
	if circuit_map == null:
		circuit_map = HDData.texture(CIRCUIT_MAP, true)
		if circuit_map == null:
			push_warning("No HD repair map at " + CIRCUIT_MAP)
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
