extends RefCounted

## HD characters for the Blender Hall prototype. character_prototype.py models
## the detective and the Castle Guardian in 3D and renders each one's eight
## walks into a sheet: the game's animation names, eight frames each, frame 0
## the standing pose, with <character>.json giving each walk's row and where
## the feet stand in a cell. Staging gives each figure's sprite the sheet's
## frames, so the game's own walk, idle, facing and stride timing play them.
## The detective's sprite is scaled so the HD figure stands as tall as the
## pixel one, on the same point; the Guardian's sheet is laid out like its
## pixel sheet, so its sprite keeps the game's scale and foot anchor (which
## the preview's depth pass also adjusts). restore() puts every sprite back.

const PLAYER_SPRITE := "player/VisualRoot/CharacterSprite"
const GUARDIAN_SCENE := "res://scenes/enemy.tscn"
const GUARDIAN_SPRITE := "GuardianCore"
## The pixel detective's figure: 238 px of its 256 px cell at scale 0.19, its
## toes on the body's origin.
const PLAYER_FIGURE_PX := 238.0 * 0.19
## The pixel Guardian's frames: 128 x 156 px, boots on row 134.
const GUARDIAN_CELL := Vector2(128.0, 156.0)
const GUARDIAN_FEET := Vector2(64.0, 134.0)
const DEFAULT_FPS := 5.0

var hall: Node
## character -> {"frames": SpriteFrames, "cell": Vector2, "feet": Vector2, "height": float}
var sheets: Dictionary = {}
## sprite -> {"frames", "moved", "position", "scale", "filter"}
var swaps: Dictionary = {}
var active := false
var rescan_in := 0.0


## Loads each character's sheet under `data_dir`. Returns how many it found.
func attach(hall_node: Node, data_dir: String) -> int:
	hall = hall_node
	for character: String in ["detective", "guardian"]:
		var meta_path := data_dir + character + ".json"
		if not FileAccess.file_exists(meta_path):
			push_warning("No prototype character at " + meta_path)
			continue
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if not (meta is Dictionary):
			continue
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(data_dir + str((meta as Dictionary)["image"]))
		)
		if image == null:
			push_warning("No prototype character sheet for " + character)
			continue
		sheets[character] = _sheet(meta as Dictionary, image)
	return sheets.size()


## Starts giving the figures in the Hall their HD frames.
func apply() -> void:
	active = true
	_rescan()


## Gives every sprite back its pixel frames, as the scene had them.
func restore() -> void:
	active = false
	for sprite: Variant in swaps:
		if not is_instance_valid(sprite):
			continue
		var node := sprite as AnimatedSprite2D
		var before: Dictionary = swaps[sprite]
		_set_frames(node, before["frames"])
		node.texture_filter = before["filter"]
		if before["moved"]:
			node.position = before["position"]
			node.scale = before["scale"]
	swaps.clear()


## Picks up Guardians that arrive after staging.
func advance(delta: float) -> void:
	if not active:
		return
	rescan_in -= delta
	if rescan_in <= 0.0:
		_rescan()


## How many sprites show HD frames now.
func staged() -> int:
	var count := 0
	for sprite: Variant in swaps:
		if is_instance_valid(sprite):
			count += 1
	return count


func _sheet(meta: Dictionary, image: Image) -> Dictionary:
	# Drawn at about twice the size the preview shows it: mipmaps let the
	# figure shrink smoothly instead of shimmering.
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var cell_size: Array = meta["cell"]
	var feet: Array = meta["feet"]
	var cell := Vector2(float(cell_size[0]), float(cell_size[1]))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var rows: Dictionary = meta["rows"]
	for animation: String in rows:
		var animation_name := StringName(animation)
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, DEFAULT_FPS)
		frames.set_animation_loop(animation_name, true)
		for column in int(meta["frames"]):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(Vector2(float(column), float(rows[animation])) * cell, cell)
			frames.add_frame(animation_name, frame)
	return {
		"frames": frames,
		"cell": cell,
		"feet": Vector2(float(feet[0]), float(feet[1])),
		"height": float(meta["height"]),
	}


func _rescan() -> void:
	rescan_in = 0.5
	for sprite: Variant in swaps.keys():
		if not is_instance_valid(sprite):
			swaps.erase(sprite)
	if not is_instance_valid(hall):
		return
	_swap(hall.get_node_or_null(PLAYER_SPRITE) as AnimatedSprite2D, "detective")
	for node: Node in hall.find_children("*", "CharacterBody2D", true, false):
		if node.scene_file_path == GUARDIAN_SCENE:
			_swap(node.get_node_or_null(GUARDIAN_SPRITE) as AnimatedSprite2D, "guardian")


func _swap(sprite: AnimatedSprite2D, character: String) -> void:
	if sprite == null or swaps.has(sprite) or not sheets.has(character):
		return
	var sheet: Dictionary = sheets[character]
	var moved := character == "detective"
	if not moved and (
		not (sheet["cell"] as Vector2).is_equal_approx(GUARDIAN_CELL)
		or not (sheet["feet"] as Vector2).is_equal_approx(GUARDIAN_FEET)
	):
		push_warning("The HD Guardian sheet is not laid out like the pixel one: kept pixel")
		return
	var frames := sheet["frames"] as SpriteFrames
	var original := sprite.sprite_frames
	# Walk timing is the game's: keep each walk's frame rate.
	if original != null:
		for animation_name: StringName in frames.get_animation_names():
			if original.has_animation(animation_name):
				frames.set_animation_speed(animation_name, original.get_animation_speed(animation_name))
	swaps[sprite] = {
		"frames": original,
		"moved": moved,
		"position": sprite.position,
		"scale": sprite.scale,
		"filter": sprite.texture_filter,
	}
	_set_frames(sprite, frames)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if moved:
		var factor := PLAYER_FIGURE_PX / float(sheet["height"])
		sprite.scale = Vector2(factor, factor)
		sprite.position = -((sheet["feet"] as Vector2) - (sheet["cell"] as Vector2) * 0.5) * factor


## Swaps `sprite`'s frames and carries on the walk, frame and play state it had.
func _set_frames(sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	var animation := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var playing := sprite.is_playing()
	sprite.sprite_frames = frames
	if frames != null and frames.has_animation(animation):
		sprite.animation = animation
		sprite.set_frame_and_progress(frame, progress)
	if playing:
		sprite.play()
