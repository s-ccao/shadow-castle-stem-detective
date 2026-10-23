extends RefCounted

## HD props for the Blender Hall prototype. hall_prototype.py models each of
## the Hall's interactive props to stand against a wall face of the HD Hall,
## renders it alone and lists it in <render>-props.json: the node it stands in
## for, the rect it shows on screen and the move from the prop's place in the
## game. Staging a prop moves its node by that move and swaps its sprite for
## the render, so the game's feet, prompt, focus box and occlusion all follow
## the prop the player sees. restore() puts every node back as the scene had it.

var hall: Node
var swaps: Array[Dictionary] = []


## Loads every listed prop under `hall_node`. Returns how many it can stage.
func attach(hall_node: Node, path: String, data_dir: String, render_scale: float) -> int:
	hall = hall_node
	if not FileAccess.file_exists(path):
		push_warning("No prototype props at " + path)
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return 0
	var spatial := RoomSpatialRuntime.new()
	for prop: Dictionary in (data as Dictionary).get("props", []):
		var root := hall.get_node_or_null(NodePath(str(prop.get("root", "")))) as Node2D
		var sprite: Sprite2D = null
		if root != null:
			sprite = spatial.find_visual_node(root) as Sprite2D
		var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + str(prop["image"])))
		if sprite == null or image == null:
			push_warning("Cannot stage prototype prop " + str(prop.get("id", "?")))
			continue
		var rect: Array = prop["rect"]
		var move: Array = prop.get("move", [0.0, 0.0])
		# The pixel prop's contact shadow: the render carries the prop's own.
		var shadows: Array[CanvasItem] = []
		for child: Node in sprite.get_children():
			if child is CanvasItem:
				shadows.append(child as CanvasItem)
		swaps.append({
			"root": root,
			"sprite": sprite,
			"root_position": root.global_position,
			"move": Vector2(float(move[0]), float(move[1])),
			"rect": Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])),
			"hd_texture": ImageTexture.create_from_image(image),
			"hd_scale": Vector2.ONE / render_scale,
			"pixel": _sprite_state(sprite),
			"shadows": shadows,
			"shadows_shown": shadows.map(func(item: CanvasItem) -> bool: return item.visible),
		})
	return swaps.size()


## Each staged sprite with the ground y its prop stands on.
func standing() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for swap: Dictionary in swaps:
		result.append({"sprite": swap["sprite"], "feet": (swap["rect"] as Rect2).end.y})
	return result


## Stages every prop: its node moves to the stand and its sprite shows the render.
func apply() -> void:
	for swap: Dictionary in swaps:
		var root := swap["root"] as Node2D
		var sprite := swap["sprite"] as Sprite2D
		if not is_instance_valid(root) or not is_instance_valid(sprite):
			continue
		root.global_position = (swap["root_position"] as Vector2) + (swap["move"] as Vector2)
		sprite.texture = swap["hd_texture"]
		sprite.region_enabled = false
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.flip_h = false
		sprite.flip_v = false
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.global_rotation = 0.0
		sprite.global_scale = swap["hd_scale"]
		sprite.global_position = (swap["rect"] as Rect2).position
		for shadow: CanvasItem in swap["shadows"]:
			if is_instance_valid(shadow):
				shadow.visible = false
	_resync()


## Puts the pixel props back, exactly as the scene had them.
func restore() -> void:
	for swap: Dictionary in swaps:
		var root := swap["root"] as Node2D
		var sprite := swap["sprite"] as Sprite2D
		if not is_instance_valid(root) or not is_instance_valid(sprite):
			continue
		root.global_position = swap["root_position"]
		var pixel: Dictionary = swap["pixel"]
		sprite.texture = pixel["texture"]
		sprite.region_enabled = pixel["region_enabled"]
		sprite.region_rect = pixel["region_rect"]
		sprite.hframes = pixel["hframes"]
		sprite.vframes = pixel["vframes"]
		sprite.frame = pixel["frame"]
		sprite.flip_h = pixel["flip_h"]
		sprite.flip_v = pixel["flip_v"]
		sprite.centered = pixel["centered"]
		sprite.offset = pixel["offset"]
		sprite.texture_filter = pixel["texture_filter"]
		sprite.position = pixel["position"]
		sprite.rotation = pixel["rotation"]
		sprite.scale = pixel["scale"]
		var shadows: Array[CanvasItem] = swap["shadows"]
		for index in shadows.size():
			if is_instance_valid(shadows[index]):
				shadows[index].visible = swap["shadows_shown"][index]
	_resync()


func _sprite_state(sprite: Sprite2D) -> Dictionary:
	return {
		"texture": sprite.texture,
		"region_enabled": sprite.region_enabled,
		"region_rect": sprite.region_rect,
		"hframes": sprite.hframes,
		"vframes": sprite.vframes,
		"frame": sprite.frame,
		"flip_h": sprite.flip_h,
		"flip_v": sprite.flip_v,
		"centered": sprite.centered,
		"offset": sprite.offset,
		"texture_filter": sprite.texture_filter,
		"position": sprite.position,
		"rotation": sprite.rotation,
		"scale": sprite.scale,
	}


func _resync() -> void:
	# The game caches its knowledge exhibits' feet: read them off the props again.
	if is_instance_valid(hall) and hall.has_method("sync_hall_knowledge_items"):
		hall.call("sync_hall_knowledge_items")
