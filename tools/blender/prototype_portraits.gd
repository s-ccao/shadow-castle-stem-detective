extends RefCounted

## HD dialogue portraits for the Blender prototype. portrait_prototype.py
## renders each speaker's bust from its Tripo model into
## prototypes/blender_chars/portraits/, and portraits.json there maps each game
## portrait (assets/characters/portraits_pixel_v2/) to its HD file.
##
## Every scene that shows a speaker (the Wake Room, the Chemistry Room, the
## Greenhouse and the Hall) loads the speaker's portrait by path each time the
## speaker changes, into a 112 px TextureRect (avatar_portrait) drawn with
## nearest filtering for pixel art. So the HD look takes those paths over:
## each HD portrait, scaled to twice the box with mipmaps, is registered under
## its game portrait's path (Resource.take_over_path), the scene's own load()
## returns it, and the box draws it smoothly. The painted look gives each path
## back to the game's own portrait and the box its own filter. The registry is
## shared (static): the resource cache is global, and the Hall and each room
## stage their looks separately.

const DATA := "res://prototypes/blender_chars/portraits/"
## The dialogue box's portrait is 112 px: the HD portraits are kept at twice
## that, so a 2x display draws them 1:1 and a 1x display from the next mip.
const DISPLAY_PX := 224
const PORTRAIT_PROPERTY := "avatar_portrait"
const FILTER_META := "prototype_pixel_filter"

## game portrait path -> its HD ImageTexture
static var hd: Dictionary = {}
## game portrait path -> the game's own portrait, to give the path back to
static var pixel: Dictionary = {}
static var showing := false


## Loads the HD portraits portraits.json lists under `data_dir` (once).
## Returns how many there are.
static func attach(data_dir: String = DATA) -> int:
	if not hd.is_empty():
		return hd.size()
	var index_path := data_dir + "portraits.json"
	if not FileAccess.file_exists(index_path):
		push_warning("No prototype portraits at " + index_path)
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not (parsed is Dictionary):
		return 0
	var listed: Dictionary = (parsed as Dictionary).get("portraits", {})
	for path: Variant in listed:
		var entry: Dictionary = listed[path]
		var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + str(entry["image"])))
		if image == null or image.is_empty() or not ResourceLoader.exists(str(path)):
			push_warning("Prototype portrait unreadable, or no game portrait at " + str(path))
			continue
		image.resize(DISPLAY_PX, DISPLAY_PX, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		hd[str(path)] = ImageTexture.create_from_image(image)
	return hd.size()


## Shows the HD portraits (or the game's own) from now on, and in `scene`'s
## dialogue box at once if it shows one now.
static func stage(hd_look: bool, scene: Node) -> void:
	var box: TextureRect = null
	if scene != null and is_instance_valid(scene):
		box = scene.get(PORTRAIT_PROPERTY) as TextureRect
	var shown := ""
	if box != null and box.texture != null:
		shown = box.texture.resource_path
	for path: String in hd:
		if hd_look:
			if not pixel.has(path):
				# Before any path is taken over, load() gives the game's own.
				pixel[path] = load(path)
			(hd[path] as Texture2D).take_over_path(path)
		elif pixel.has(path):
			(pixel[path] as Texture2D).take_over_path(path)
	showing = hd_look
	if box == null:
		return
	if not box.has_meta(FILTER_META):
		box.set_meta(FILTER_META, box.texture_filter)
	if hd_look:
		box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		box.texture_filter = box.get_meta(FILTER_META)
	if hd.has(shown):
		box.texture = load(shown) as Texture2D


## The HD portrait standing in for the game portrait at `path`, or null.
static func hd_for(path: String) -> Texture2D:
	return hd.get(path, null) as Texture2D
