extends RefCounted

## Where the game's HD look lives and how it is read. The Blender pipeline
## (tools/blender/) renders into prototypes/, and tools/blender/publish_hd.py
## publishes what the game draws into assets/hd/: WebP renders, props,
## figure sheets, portraits and maps that Godot imports (lossy, as the painted
## backgrounds are) and the export packs, lossless PNG depth maps, and the JSON
## that places them. Everything is read through Godot's resource loader, so the
## look is the same in the editor, in a desktop build and on the web.

const ROOT := "res://assets/hd/"
const HALL := ROOT + "hall/"
const ROOMS := ROOT + "rooms/"
const CHARACTERS := ROOT + "characters/"
const PORTRAITS := ROOT + "portraits/"
const MAPS := ROOT + "maps/"

## Textures kept loaded for the whole session (the Hall's render, the figures
## every scene draws and the maps), so walking back into the Hall or another
## room does not decode them again. Everything else goes with its scene.
static var _kept: Dictionary = {}


## The parsed JSON at `path`, or null if there is none.
static func json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Lets go of every texture kept for the session (at exit).
static func release() -> void:
	_kept.clear()


## The imported texture at `path`, or null. `keep` holds it for the session.
static func texture(path: String, keep: bool = false) -> Texture2D:
	if _kept.has(path):
		return _kept[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var loaded := load(path) as Texture2D
	if keep and loaded != null:
		_kept[path] = loaded
	return loaded
