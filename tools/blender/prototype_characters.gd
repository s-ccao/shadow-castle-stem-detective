extends RefCounted

## HD characters for the Blender Hall prototype and its rooms.
## character_prototype.py renders
## each character's Tripo model in three gaits, each a sheet of the game's 8
## facings: an idle loop, a walk cycle and a run cycle. <character>.json gives
## each sheet, the facing rows, where the feet stand in a cell, the idle's
## frame rate and the ground one walk or run cycle covers ("stride", sheet px).
##
## The game itself knows only a walk and a standing frame. So the game's sprite
## keeps the HD walk frames and goes on running the game's facing, walk and stop
## logic, but is no longer drawn; a sprite of the preview's own (HD_FIGURE), its
## child, draws the figure in its place. The child shares the game sprite's
## place and scale, its visibility, modulate and the depth pass's material.
## Every physics tick (the game moves its bodies in physics ticks, so the ground
## covered in one is a body's true pace at any frame rate) it reads which way
## the game faces, whether the game walks it, and how far its body moved:
##   standing  plays the idle loop;
##   moving    walks, or runs from RUN_SPEED until it slows below WALK_SPEED;
##             each cycle advances by the ground the body covered, so a planted
##             foot stays on its spot of floor at any speed.
## The detective's sprite is scaled so the HD figure stands as tall as the pixel
## one, on the same point; the Guardian's sheets are laid out like its pixel
## sheet, so its sprite keeps the game's scale and foot anchor (which the
## preview's depth pass also adjusts). The rooms' cast (the butler, the
## gardener, the mechanic and Dr. Lin's memory echo) keep their own sprites,
## frames and turning; each figure is drawn inside its NPC's sprite as tall
## as the pixel figure and on its feet, facing as the NPC faces, and plays its
## idle loop. restore() removes the figures and puts every sprite back.

const PLAYER_SPRITE := "player/VisualRoot/CharacterSprite"
const GUARDIAN_SCENE := "res://scenes/enemy.tscn"
const GUARDIAN_SPRITE := "GuardianCore"
## The rooms' cast are AnimatedNpc nodes, known by the name the game gives each.
const NPC_SCRIPT := "res://scripts/animated_npc.gd"
const NPCS: Dictionary = {
	"Butler": "butler",
	"Gardener": "gardener",
	"Mechanic": "mechanic",
	"Dr. Lin Memory Echo": "dr_lin",
}
## Each pixel NPC's standing figure, in its own sheet's px: the HD figure is
## drawn as tall, on the same feet.
const NPC_FIGURE_PX: Dictionary = {
	"butler": 44.0, "gardener": 212.0, "mechanic": 216.0, "dr_lin": 205.0,
}
## An NPC's idle or walk faces one of the game's 8 (or 4) ways; the HD sheets
## keep a row for each under the detective's walk names.
const NPC_FACINGS: Dictionary = {
	"south": "walk_down", "down": "walk_down", "south_east": "walk_down_right",
	"east": "walk_right", "right": "walk_right", "north_east": "walk_up_right",
	"north": "walk_up", "up": "walk_up", "north_west": "walk_up_left",
	"west": "walk_left", "left": "walk_left", "south_west": "walk_down_left",
}
const HD_FIGURE := "PrototypeHDFigure"
## The pixel detective's figure: 238 px of its 256 px cell at scale 0.19, its
## toes on the body's origin.
const PLAYER_FIGURE_PX := 238.0 * 0.19
## The pixel Guardian's frames: 128 x 156 px, boots on row 134.
const GUARDIAN_CELL := Vector2(128.0, 156.0)
const GUARDIAN_FEET := Vector2(64.0, 134.0)
const DEFAULT_FPS := 5.0
const GAITS: Array[String] = ["idle", "walk", "run"]
## World px a second: a figure starts running above RUN_SPEED and walks again
## below WALK_SPEED. The detective moves at 180, a run for a 50 px figure; the
## Guardian creeps, patrols and searches at 38-96 and chases at 145 and up.
const RUN_SPEED := 120.0
const WALK_SPEED := 100.0
## Seconds over which the measured speed settles.
const SPEED_SMOOTHING := 0.1
## Seconds a figure's speed must stay past a threshold before it changes gait,
## so one slow frame doesn't break a run.
const GAIT_DWELL := 0.15
## A body that jumps further than this in one tick was placed, not moved.
const TELEPORT_PX := 24.0

var hall: Node
## character -> {"frames": SpriteFrames, "cell": Vector2, "feet": Vector2,
## "height": float, "rows": {animation: row}, "gaits": {gait: {"texture",
## "frames", "fps", "stride"}}}
var sheets: Dictionary = {}
## How many of the rooms' cast have their sheets (sheets holds them too).
var cast := 0
## game sprite -> what it had ("frames", "moved", "position", "scale",
## "filter", "self_modulate", "npc") and its figure ("figure", "body",
## "sheet", "gait", "phase", "cycles", "clock", "speed", "dwell", "last")
var swaps: Dictionary = {}
var active := false
var rescan_in := 0.0


## Loads each character's sheets under `data_dir`. Returns how many of the
## detective and the Guardian have all three gaits; `cast` counts the NPCs.
func attach(hall_node: Node, data_dir: String) -> int:
	hall = hall_node
	var characters: Array[String] = ["detective", "guardian"]
	for npc: Variant in NPCS.values():
		characters.append(str(npc))
	for character: String in characters:
		var meta_path := data_dir + character + ".json"
		if not FileAccess.file_exists(meta_path):
			push_warning("No prototype character at " + meta_path)
			continue
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if not (meta is Dictionary):
			continue
		var sheet := _sheet(meta as Dictionary, data_dir)
		if sheet.is_empty():
			push_warning("Prototype character sheets missing for " + character)
			continue
		sheets[character] = sheet
	cast = sheets.size() - int(sheets.has("detective")) - int(sheets.has("guardian"))
	return sheets.size() - cast


## Starts drawing the figures in the Hall in HD.
func apply() -> void:
	active = true
	_rescan()


## Removes the figures and gives every sprite back its pixel frames.
func restore() -> void:
	active = false
	for sprite: Variant in swaps:
		var before: Dictionary = swaps[sprite]
		var figure: Variant = before["figure"]
		if is_instance_valid(figure):
			var node := figure as Node
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
		if not is_instance_valid(sprite):
			continue
		var game_sprite := sprite as AnimatedSprite2D
		if not before["npc"]:
			_set_frames(game_sprite, before["frames"])
		game_sprite.texture_filter = before["filter"]
		game_sprite.self_modulate = before["self_modulate"]
		if before["moved"]:
			game_sprite.position = before["position"]
			game_sprite.scale = before["scale"]
	swaps.clear()


## Moves every figure on by one physics tick. Call it from the SceneTree's
## _physics_process, which runs before the game's own bodies move in the tick.
func track(delta: float) -> void:
	if not active:
		return
	for sprite: Variant in swaps:
		# A paused game holds its figures too.
		if is_instance_valid(sprite) and (sprite as Node).can_process():
			_drive(sprite as AnimatedSprite2D, delta)


## Picks up Guardians that arrive after staging.
func advance(delta: float) -> void:
	if not active:
		return
	rescan_in -= delta
	if rescan_in <= 0.0:
		_rescan()


## How many sprites show HD figures now.
func staged() -> int:
	var count := 0
	for sprite: Variant in swaps:
		if is_instance_valid(sprite):
			count += 1
	return count


## The HD figure drawn for a game sprite, or null.
func figure_of(sprite: Node) -> Sprite2D:
	if not swaps.has(sprite):
		return null
	var figure: Variant = swaps[sprite]["figure"]
	return figure as Sprite2D if is_instance_valid(figure) else null


## Which gait a game sprite's figure shows: "idle", "walk" or "run".
func gait_of(sprite: Node) -> String:
	return str(swaps[sprite]["gait"]) if swaps.has(sprite) else ""


## Walk and run cycles a figure has played since it was staged.
func cycles_of(sprite: Node) -> float:
	return float(swaps[sprite]["cycles"]) if swaps.has(sprite) else 0.0


func _sheet(meta: Dictionary, data_dir: String) -> Dictionary:
	var cell_size: Array = meta["cell"]
	var feet: Array = meta["feet"]
	var cell := Vector2(float(cell_size[0]), float(cell_size[1]))
	var listed: Dictionary = meta.get("gaits", {})
	var gaits := {}
	for gait: String in GAITS:
		if not listed.has(gait):
			return {}
		var entry: Dictionary = listed[gait]
		var image := Image.load_from_file(ProjectSettings.globalize_path(data_dir + str(entry["image"])))
		if image == null or image.is_empty():
			return {}
		# Drawn at about twice the size the preview shows it: mipmaps let the
		# figure shrink smoothly instead of shimmering.
		image.generate_mipmaps()
		gaits[gait] = {
			"texture": ImageTexture.create_from_image(image),
			"frames": int(entry["frames"]),
			"fps": float(entry.get("fps", DEFAULT_FPS)),
			"stride": float(entry.get("stride", 0.0)),
		}
	var rows: Dictionary = meta["rows"]
	var walk: Dictionary = gaits["walk"]
	# The game's sprite runs the game's walks on the HD walk frames, so anything
	# the game copies from it (an afterimage, a CG) is the HD figure too.
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: String in rows:
		var animation_name := StringName(animation)
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, DEFAULT_FPS)
		frames.set_animation_loop(animation_name, true)
		for column in int(walk["frames"]):
			var frame := AtlasTexture.new()
			frame.atlas = walk["texture"]
			frame.region = Rect2(Vector2(float(column), float(rows[animation])) * cell, cell)
			frames.add_frame(animation_name, frame)
	return {
		"frames": frames,
		"cell": cell,
		"feet": Vector2(float(feet[0]), float(feet[1])),
		"height": float(meta["height"]),
		"rows": rows,
		"gaits": gaits,
	}


func _rescan() -> void:
	rescan_in = 0.5
	for sprite: Variant in swaps.keys():
		if not is_instance_valid(sprite):
			swaps.erase(sprite)
	if not is_instance_valid(hall):
		return
	var player := hall.get_node_or_null("player") as Node2D
	if player == null:
		# A room may y-sort its player with its props (the Greenhouse's Worldsort/).
		player = hall.find_child("player", true, false) as Node2D
	if player != null:
		var sprite := player.get_node_or_null(PLAYER_SPRITE.trim_prefix("player/")) as AnimatedSprite2D
		_swap(sprite, player, "detective")
	for node: Node in hall.find_children("*", "CharacterBody2D", true, false):
		if node.scene_file_path == GUARDIAN_SCENE:
			_swap(node.get_node_or_null(GUARDIAN_SPRITE) as AnimatedSprite2D, node as Node2D, "guardian")
	for node: Node in hall.find_children("*", "Node2D", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == NPC_SCRIPT:
			_swap_npc(node as Node2D, str(NPCS.get(str(node.get("character_name")), "")))


## The detective and the Guardian: the game sprite takes the HD walk frames
## and the figure is drawn in their place.
func _swap(sprite: AnimatedSprite2D, body: Node2D, character: String) -> void:
	if sprite == null or body == null or swaps.has(sprite) or not sheets.has(character):
		return
	var sheet: Dictionary = sheets[character]
	var moved := character == "detective"
	if not moved and (
		not (sheet["cell"] as Vector2).is_equal_approx(GUARDIAN_CELL)
		or not (sheet["feet"] as Vector2).is_equal_approx(GUARDIAN_FEET)
	):
		push_warning("The HD Guardian sheets are not laid out like the pixel one: kept pixel")
		return
	var frames := sheet["frames"] as SpriteFrames
	var original := sprite.sprite_frames
	# Walk timing is the game's: keep each walk's frame rate.
	if original != null:
		for animation_name: StringName in frames.get_animation_names():
			if original.has_animation(animation_name):
				frames.set_animation_speed(animation_name, original.get_animation_speed(animation_name))
	var figure := Sprite2D.new()
	figure.name = HD_FIGURE
	figure.centered = sprite.centered
	figure.offset = sprite.offset
	figure.use_parent_material = true
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	figure.vframes = (sheet["rows"] as Dictionary).size()
	swaps[sprite] = {
		"frames": original,
		"moved": moved,
		"npc": false,
		"position": sprite.position,
		"scale": sprite.scale,
		"filter": sprite.texture_filter,
		"self_modulate": sprite.self_modulate,
		"figure": figure,
		"body": body,
		"sheet": sheet,
		"gait": "",
		"phase": 0.0,
		"cycles": 0.0,
		"clock": 0.0,
		"speed": 0.0,
		"dwell": 0.0,
		"last": body.global_position,
	}
	_set_frames(sprite, frames)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if moved:
		var factor := PLAYER_FIGURE_PX / float(sheet["height"])
		sprite.scale = Vector2(factor, factor)
		sprite.position = -((sheet["feet"] as Vector2) - (sheet["cell"] as Vector2) * 0.5) * factor
	var undrawn := sprite.self_modulate
	undrawn.a = 0.0
	sprite.self_modulate = undrawn
	sprite.add_child(figure)
	_drive(sprite, 0.0)


## One of the rooms' cast: the game keeps its own NPC sprite, its frames and
## its turning to meet the player, but no longer draws it; the HD figure,
## its child, is drawn as tall and on the same feet. It stands in its own
## place inside the sprite, so the NPC's notice (a pulse of the sprite's scale
## about its feet) carries it too.
func _swap_npc(npc: Node2D, character: String) -> void:
	var sprite := npc.get("actor_sprite") as AnimatedSprite2D
	if sprite == null or swaps.has(sprite) or not sheets.has(character):
		return
	var sheet: Dictionary = sheets[character]
	var pixel_scale := float(npc.get("visual_scale"))
	if is_zero_approx(pixel_scale):
		return
	var factor := float(NPC_FIGURE_PX[character]) / float(sheet["height"])
	var feet := -(npc.get("visual_foot_anchor") as Vector2) / pixel_scale
	var figure := Sprite2D.new()
	figure.name = HD_FIGURE
	figure.centered = true
	figure.use_parent_material = true
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	figure.vframes = (sheet["rows"] as Dictionary).size()
	figure.scale = Vector2(factor, factor)
	figure.position = feet - ((sheet["feet"] as Vector2) - (sheet["cell"] as Vector2) * 0.5) * factor
	swaps[sprite] = {
		"frames": sprite.sprite_frames,
		"moved": false,
		"npc": true,
		"position": sprite.position,
		"scale": sprite.scale,
		"filter": sprite.texture_filter,
		"self_modulate": sprite.self_modulate,
		"figure": figure,
		"body": npc,
		"sheet": sheet,
		"gait": "",
		"phase": 0.0,
		"cycles": 0.0,
		"clock": 0.0,
		"speed": 0.0,
		"dwell": 0.0,
		"last": npc.global_position,
	}
	var undrawn := sprite.self_modulate
	undrawn.a = 0.0
	sprite.self_modulate = undrawn
	sprite.add_child(figure)
	_drive(sprite, 0.0)


## The sheet row a game sprite's animation shows: its own for the detective
## and the Guardian, the facing of an NPC's idle or walk for the cast.
func _row(entry: Dictionary, sprite: AnimatedSprite2D) -> int:
	var rows: Dictionary = (entry["sheet"] as Dictionary)["rows"]
	var animation := String(sprite.animation)
	if bool(entry["npc"]):
		animation = str(NPC_FACINGS.get(animation.trim_prefix("idle_").trim_prefix("walk_"), "walk_down"))
	return int(rows.get(animation, 0))


## Picks the figure's gait and frame from the game's facing and walk, and from
## how far its body moved in the last tick.
func _drive(sprite: AnimatedSprite2D, delta: float) -> void:
	var entry: Dictionary = swaps[sprite]
	if not is_instance_valid(entry["figure"]) or not is_instance_valid(entry["body"]):
		return
	var figure := entry["figure"] as Sprite2D
	var body := entry["body"] as Node2D
	var sheet: Dictionary = entry["sheet"]
	var gaits: Dictionary = sheet["gaits"]
	var gait := str(entry["gait"])
	var here := body.global_position
	var travelled := here.distance_to(entry["last"] as Vector2)
	entry["last"] = here
	if travelled > TELEPORT_PX:
		travelled = 0.0
	var starting := gait in ["", "idle"]
	# The game plays its walk once the body moves; a figure at rest keeps its
	# idle until the body has actually moved, so its first speed is a real one.
	var moving := sprite.is_playing() and (travelled > 0.0 or not starting)
	if delta > 0.0:
		var instant := travelled / delta
		if moving and starting:
			entry["speed"] = instant
		else:
			entry["speed"] = lerpf(float(entry["speed"]), instant, 1.0 - exp(-delta / SPEED_SMOOTHING))
	if moving:
		var speed := float(entry["speed"])
		if starting:
			# Every walk and run cycle starts on the same footfall.
			entry["phase"] = 0.0
			entry["dwell"] = 0.0
			gait = "run" if speed > RUN_SPEED else "walk"
		else:
			var wanted := "run" if speed > (WALK_SPEED if gait == "run" else RUN_SPEED) else "walk"
			if wanted == gait:
				entry["dwell"] = 0.0
			else:
				entry["dwell"] = float(entry["dwell"]) + delta
			if float(entry["dwell"]) >= GAIT_DWELL:
				gait = wanted
				entry["dwell"] = 0.0
		var stride := float((gaits[gait] as Dictionary)["stride"]) * absf(figure.global_scale.y)
		if stride > 0.0:
			var cycles := travelled / stride
			entry["phase"] = fposmod(float(entry["phase"]) + cycles, 1.0)
			entry["cycles"] = float(entry["cycles"]) + cycles
	else:
		if gait != "idle":
			entry["clock"] = 0.0
		gait = "idle"
		entry["clock"] = float(entry["clock"]) + delta
	entry["gait"] = gait
	var info: Dictionary = gaits[gait]
	var count := int(info["frames"])
	var column := 0
	if gait == "idle":
		column = int(floor(float(entry["clock"]) * float(info["fps"]))) % count
	else:
		column = int(floor(float(entry["phase"]) * count)) % count
	var row := _row(entry, sprite)
	var texture := info["texture"] as Texture2D
	if figure.texture != texture:
		figure.texture = texture
		figure.hframes = count
	figure.frame = row * count + column
	figure.flip_h = sprite.flip_h
	figure.flip_v = sprite.flip_v


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
