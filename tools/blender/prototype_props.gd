extends RefCounted

## HD stand-ins for interactive pixel props. hall_prototype.py renders each
## prop alone into exactly its sprite's on-screen rect and lists it in
## <render>-props.json. Swapping only the sprite's texture (and scale, so the
## rect is unchanged) keeps the game's feet, focus point, occlusion and
## highlight working off the same node.

var swaps: Array[Dictionary] = []


## Loads every listed prop under `hall`. Returns how many it can swap.
func attach(hall: Node, path: String, data_dir: String, render_scale: float) -> int:
	if not FileAccess.file_exists(path):
		push_warning("No prototype props at " + path)
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return 0
	for prop: Dictionary in (data as Dictionary).get("props", []):
		var sprite := hall.get_node_or_null(NodePath(str(prop["node"]))) as Sprite2D
		var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + str(prop["image"])))
		if sprite == null or image == null or sprite.texture == null:
			push_warning("Cannot swap prototype prop " + str(prop.get("id", "?")))
			continue
		var hd_scale := Vector2.ONE / render_scale
		var children: Array[Node2D] = []
		for child: Node in sprite.get_children():
			if child is Node2D:
				children.append(child as Node2D)
		swaps.append({
			"sprite": sprite,
			"pixel_texture": sprite.texture,
			"pixel_scale": sprite.scale,
			"pixel_filter": sprite.texture_filter,
			"hd_texture": ImageTexture.create_from_image(image),
			"hd_scale": hd_scale,
			"feet": float(prop["rect"][1]) + float(prop["rect"][3]),
			"children": children,
			"child_positions": children.map(func(child: Node2D) -> Vector2: return child.position),
			"child_scales": children.map(func(child: Node2D) -> Vector2: return child.scale),
		})
	return swaps.size()


## Each swapped sprite with the ground y its prop stands on.
func standing() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for swap: Dictionary in swaps:
		result.append({"sprite": swap["sprite"], "feet": swap["feet"]})
	return result


## Shows the HD renders. Children (the contact shadow) keep their on-screen
## size and place, though the sprite's scale changes under them.
func apply() -> void:
	for swap: Dictionary in swaps:
		var sprite := swap["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue
		var ratio: Vector2 = (swap["pixel_scale"] as Vector2) / (swap["hd_scale"] as Vector2)
		sprite.texture = swap["hd_texture"]
		sprite.scale = swap["hd_scale"]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var children: Array[Node2D] = swap["children"]
		for index in children.size():
			children[index].position = (swap["child_positions"][index] as Vector2) * ratio
			children[index].scale = (swap["child_scales"][index] as Vector2) * ratio


## Puts the pixel props back, exactly as the scene had them.
func restore() -> void:
	for swap: Dictionary in swaps:
		var sprite := swap["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue
		sprite.texture = swap["pixel_texture"]
		sprite.scale = swap["pixel_scale"]
		sprite.texture_filter = swap["pixel_filter"]
		var children: Array[Node2D] = swap["children"]
		for index in children.size():
			children[index].position = swap["child_positions"][index]
			children[index].scale = swap["child_scales"][index]
