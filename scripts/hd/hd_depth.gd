extends RefCounted

## Depth for the HD look. Walls stand on the collision and their tops rise
## above it on screen, so whatever stands north of a wall is behind it.
## hall_prototype.py (and room_prototype.py) write render-depth.png, published
## lossless under assets/hd/: for each screen px of the
## region, the ground y of the wall seen there (R high byte, G low byte; A where
## a wall is seen). A nearer surface has the larger ground y, so a shader on
## each character, footprint and HD prop hides what a wall in front covers.
## Characters and footprints still show there as faint ghosts, so neither the
## player nor the route is ever lost behind a wall. The Hall's figures are
## shown at 50 px instead of 66 so the 40 px walls read as walls; a room shows
## them at full size (figure_scale 1). Only the visual nodes change, never the
## collision.

const SHADER_CODE := """
shader_type canvas_item;
render_mode %s;

uniform sampler2D depth_map : filter_nearest, repeat_disable;
uniform vec2 depth_origin;
uniform vec2 depth_size;
uniform float feet_y = 0.0;
uniform bool feet_from_origin = false;
uniform vec4 tint = vec4(0.0);
uniform float ghost = 0.0;

varying vec2 world_position;
varying float origin_y;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}

void fragment() {
	vec4 color = COLOR;
	vec2 uv = (world_position - depth_origin) / depth_size;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		vec4 depth = texture(depth_map, uv);
		float wall_y = floor(depth.r * 255.0 + 0.5) * 256.0 + floor(depth.g * 255.0 + 0.5);
		float feet = feet_from_origin ? origin_y : feet_y;
		if (depth.a > 0.5 && wall_y > feet + 0.5) {
			color.rgb = mix(color.rgb, tint.rgb, tint.a);
			color.a *= ghost;
		}
	}
	COLOR = color;
}
"""
## How a hidden part still shows: a tint (rgb, amount) and what opacity is left.
const PLAYER_GHOST := {"tint": Color(0.55, 0.48, 0.9, 0.35), "alpha": 0.45}
const GUARDIAN_GHOST := {"tint": Color(0.95, 0.36, 0.36, 0.45), "alpha": 0.45}
const FOOTPRINT_GHOST := {"tint": Color(0.0, 0.0, 0.0, 0.0), "alpha": 0.35}
const HIDDEN := {"tint": Color(0.0, 0.0, 0.0, 0.0), "alpha": 0.0}
const FIGURE_SCALE := 1.1 / 1.45
const GUARDIAN_SCENE := "res://scenes/enemy.tscn"
## The rooms' cast (AnimatedNpc): a wall in front hides them outright, and all
## but a memory echo, which is a vision and not a body, stand on a shadow.
const NPC_SCRIPT := "res://scripts/animated_npc.gd"
const ECHO_MARK := "Echo"
const FOOTPRINT_SCRIPT := "hall_footprint_marker.gd"
const SHADOW_NAME := "PrototypeContactShadow"
const HDData := preload("res://scripts/hd/hd_data.gd")

var hall: Node
## How the figures are shown against the render: the Hall shrinks them, a room
## keeps them, and their contact shadows follow their size.
var figure_scale := FIGURE_SCALE
var shadow_size := Vector2(22.0, 7.0)
var depth_texture: Texture2D
var origin := Vector2.ZERO
var size := Vector2.ONE
var mix_shader := Shader.new()
var add_shader := Shader.new()
## sprite's instance id -> {"sprite", "material", "original", "body"}. Keyed by
## id: footprints come and go with every route, and a Dictionary keyed by
## objects since freed can loop for ever when iterated.
var entries: Dictionary = {}
var fixed: Array[Dictionary] = []
var shadows: Array[Sprite2D] = []
## Visual nodes shrunk to FIGURE_SCALE, with the scale and position they had.
var shrunk: Array[Dictionary] = []
var active := false
var rescan_in := 0.0


## Loads the depth map for `region` [x, y, width, height]. False without one.
func attach(hall_node: Node, path: String, region: Array) -> bool:
	var texture := HDData.texture(path)
	if texture == null:
		push_warning("No HD depth map at " + path)
		return false
	hall = hall_node
	depth_texture = texture
	origin = Vector2(float(region[0]), float(region[1]))
	size = Vector2(float(region[2]), float(region[3]))
	mix_shader.code = SHADER_CODE % "blend_mix"
	add_shader.code = SHADER_CODE % "blend_add"
	return true


## A sprite that never moves, such as an HD prop, standing at `feet_y`.
func add_fixed(sprite: CanvasItem, feet_y: float) -> void:
	for item: Dictionary in fixed:
		if item["sprite"] == sprite:
			return
	fixed.append({"sprite": sprite, "feet": feet_y})


## Every prop region.json lists ({name: {"path", "rect"}}): each stands on the
## bottom of its visual rect. Returns how many it found.
func add_props(props: Dictionary) -> int:
	var spatial := RoomSpatialRuntime.new()
	var count := 0
	for prop: Dictionary in props.values():
		var root := hall.get_node_or_null(NodePath(str(prop["path"])))
		var visual := spatial.find_visual_node(root) if root != null else null
		if visual == null:
			push_warning("No prototype depth prop at " + str(prop["path"]))
			continue
		var rect: Array = prop["rect"]
		add_fixed(visual, float(rect[1]) + float(rect[3]))
		count += 1
	return count


## Starts hiding what walls cover, and gives the characters contact shadows.
func apply() -> void:
	active = true
	_rescan()


## Puts every material back and removes the shadows, as the scene had them.
func restore() -> void:
	active = false
	for entry: Dictionary in entries.values():
		var sprite: Variant = entry["sprite"]
		if is_instance_valid(sprite):
			(sprite as CanvasItem).material = entry["original"]
	entries.clear()
	for shadow in shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	shadows.clear()
	for item: Dictionary in shrunk:
		var node: Variant = item["node"]
		if is_instance_valid(node):
			(node as Node2D).scale = item["scale"]
			(node as Node2D).position = item["position"]
	shrunk.clear()


## Keeps the characters' feet current and picks up footprints as they appear.
func advance(delta: float) -> void:
	if not active:
		return
	rescan_in -= delta
	if rescan_in <= 0.0:
		_rescan()
	# The game may set its own visual scale again; the preview keeps its own.
	for item: Dictionary in shrunk:
		var node: Variant = item["node"]
		var target: Vector2 = (item["scale"] as Vector2) * figure_scale
		if is_instance_valid(node) and not (node as Node2D).scale.is_equal_approx(target):
			(node as Node2D).scale = target
	for id: int in entries.keys():
		var entry: Dictionary = entries[id]
		if not is_instance_valid(entry["sprite"]):
			entries.erase(id)
			continue
		var body: Variant = entry["body"]
		if body != null and is_instance_valid(body):
			(entry["material"] as ShaderMaterial).set_shader_parameter(
				"feet_y", (body as Node2D).global_position.y
			)


func _rescan() -> void:
	rescan_in = 0.5
	if not is_instance_valid(hall):
		return
	var player := hall.get_node_or_null("player") as Node2D
	if player == null:
		# A room may y-sort its player with its props (the Greenhouse's Worldsort/).
		player = hall.find_child("player", true, false) as Node2D
	if player != null:
		_shrink(player.get_node_or_null("VisualRoot") as Node2D)
		_track(player.get_node_or_null("VisualRoot/CharacterSprite") as CanvasItem, player, PLAYER_GHOST)
	for node: Node in hall.find_children("*", "CharacterBody2D", true, false):
		if node.scene_file_path == GUARDIAN_SCENE:
			_shrink(node.get_node_or_null("GuardianCore") as Node2D)
			_track(node.get_node_or_null("GuardianCore") as CanvasItem, node as Node2D, GUARDIAN_GHOST)
	for node: Node in hall.find_children("*", "Node2D", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with(FOOTPRINT_SCRIPT):
			for child: Node in node.get_children():
				if child is Sprite2D:
					_track(child as CanvasItem, null, FOOTPRINT_GHOST)
		elif script != null and script.resource_path == NPC_SCRIPT:
			var echo := str(node.get("character_name")).contains(ECHO_MARK)
			_track(node.get("actor_sprite") as CanvasItem, node as Node2D, HIDDEN, not echo)
	for item: Dictionary in fixed:
		var sprite: Variant = item["sprite"]
		if not is_instance_valid(sprite):
			continue
		# The prop's contact shadow lies on the same ground as the prop.
		var parts: Array[CanvasItem] = [sprite as CanvasItem]
		for child: Node in (sprite as Node).get_children():
			if child is Sprite2D:
				parts.append(child as CanvasItem)
		for part in parts:
			if entries.has(part.get_instance_id()):
				continue
			_track(part, null, HIDDEN)
			var material := entries[part.get_instance_id()]["material"] as ShaderMaterial
			material.set_shader_parameter("feet_from_origin", false)
			material.set_shader_parameter("feet_y", float(item["feet"]))


func _shrink(node: Node2D) -> void:
	if node == null or is_equal_approx(figure_scale, 1.0):
		return
	for item: Dictionary in shrunk:
		if item["node"] == node:
			return
	shrunk.append({"node": node, "scale": node.scale, "position": node.position})
	node.scale *= figure_scale
	node.position *= figure_scale


func _track(sprite: CanvasItem, body: Node2D, look: Dictionary, shadow := true) -> void:
	if sprite == null or entries.has(sprite.get_instance_id()):
		return
	var original := sprite.material
	var additive := (
		original is CanvasItemMaterial
		and (original as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	)
	var material := ShaderMaterial.new()
	material.shader = add_shader if additive else mix_shader
	material.set_shader_parameter("depth_map", depth_texture)
	material.set_shader_parameter("depth_origin", origin)
	material.set_shader_parameter("depth_size", size)
	material.set_shader_parameter("tint", look["tint"])
	material.set_shader_parameter("ghost", look["alpha"])
	material.set_shader_parameter("feet_from_origin", body == null)
	if body != null:
		material.set_shader_parameter("feet_y", body.global_position.y)
		if shadow:
			_add_shadow(body)
	sprite.material = material
	entries[sprite.get_instance_id()] = {
		"sprite": sprite, "material": material, "original": original, "body": body,
	}


## A soft dark ellipse under the feet: a figure without one floats over the
## painted floor. It is hidden by walls in front like everything else.
func _add_shadow(body: Node2D) -> void:
	if body.has_node(SHADOW_NAME):
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.02, 0.5))
	gradient.set_color(1, Color(0.0, 0.0, 0.02, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	var shadow := Sprite2D.new()
	shadow.name = SHADOW_NAME
	shadow.texture = texture
	shadow.scale = shadow_size / 32.0
	shadow.position = Vector2(0.0, -1.0)
	shadow.z_index = -1
	body.add_child(shadow)
	shadows.append(shadow)
	_track(shadow, null, HIDDEN)
