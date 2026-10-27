extends CanvasLayer

signal finished

const ZOOM := 2.4
const DOOR_CENTER := Vector2(735, 170)
## The Hall's HD look (scripts/hd/hd_hall.gd, hd_doors.gd), when it is staged:
## its render laid over the painted Hall, and the Chemistry door's leaves, a
## sheet from shut (frame 0) to open (the last frame).
const HD_RENDER := "BlenderPrototypeOverlay"
const HD_DOOR := "PrototypeDoorChemistry"

var phase := &"approach"
var content: Control
var caption: Label
var detective: AnimatedSprite2D
var guardian: AnimatedSprite2D
var leaf: TextureRect
var hd_door: Sprite2D
var doorway_shadow: ColorRect
var timeline: Tween
var completed := false


func play_scene(hall: Node2D) -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build(hall)
	visible = true
	GameAudio.play(&"guardian_alert")
	GameAudio.duck_music(1.4)
	timeline = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	timeline.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	timeline.tween_property(content, "modulate:a", 1.0, 0.15).from(0.0)
	timeline.tween_property(guardian, "position", Vector2(610, 385), 1.35)
	timeline.parallel().tween_property(detective, "position", Vector2(735, 320), 1.35)
	timeline.tween_callback(_reach)
	timeline.tween_property(guardian, "position", Vector2(719, 332), 0.5).set_ease(Tween.EASE_IN)
	timeline.parallel().tween_property(guardian, "rotation", -0.08, 0.5)
	timeline.parallel().tween_property(detective, "position", Vector2(739, 265), 0.36)
	timeline.parallel().tween_property(detective, "modulate:a", 0.0, 0.12).set_delay(0.25)
	timeline.tween_callback(_close_door)
	timeline.tween_method(_swing_shut, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	timeline.tween_callback(_door_impact)
	timeline.tween_property(content, "position", Vector2(0, 96), 0.12).from(Vector2(-4, 98))
	timeline.parallel().tween_property(guardian, "position", Vector2(680, 410), 0.22)
	timeline.parallel().tween_property(guardian, "rotation", 0.0, 0.22)
	timeline.tween_interval(0.85)
	timeline.tween_property(content, "modulate:a", 0.0, 0.2)
	timeline.tween_callback(finish)


func _build(hall: Node2D) -> void:
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color("#08060d")
	root_control.add_child(black)
	var kicker := Label.new()
	kicker.position = Vector2(32, 16)
	kicker.size = Vector2(680, 22)
	kicker.text = CaseLocale.text("cg.chemistry_kicker")
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", ArchiveUi.COLOR_GOLD)
	root_control.add_child(kicker)
	var title := Label.new()
	title.name = "NearMissTitle"
	title.position = Vector2(32, 42)
	title.size = Vector2(760, 40)
	title.text = CaseLocale.text("hall.near_miss_title")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ArchiveUi.COLOR_PARCHMENT)
	root_control.add_child(title)
	var skip := Button.new()
	skip.name = "SkipNearMiss"
	skip.position = Vector2(832, 32)
	skip.size = Vector2(160, 40)
	skip.text = CaseLocale.text("cg.skip")
	ArchiveUi.apply_button(skip, ArchiveUi.ROLE_MUTED)
	skip.pressed.connect(finish)
	root_control.add_child(skip)
	content = Control.new()
	content.name = "NearMissScene"
	content.position = Vector2(0, 96)
	content.size = Vector2(1024, 576)
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(content)
	var world := Node2D.new()
	world.name = "CinematicHallArtwork"
	var door_world: Vector2 = hall.get("CHEMISTRY_ROOM_DOOR_FOCUS_POSITION")
	world.scale = Vector2.ONE * ZOOM
	world.position = DOOR_CENTER - door_world * ZOOM
	content.add_child(world)
	for path: String in ["WallCollisions/BackgroundVisual", "WallCollisions/WallsVisual"]:
		var z := 0 if path.ends_with("BackgroundVisual") else 1
		world.add_child(_artwork(hall.get_node(path) as Sprite2D, z, CanvasItem.TEXTURE_FILTER_NEAREST))
	# The HD Hall draws over the painted one, as in the game, and its own door
	# stands open in the doorway until it swings shut behind the detective.
	var render := hall.get_node_or_null(HD_RENDER) as Sprite2D
	if render != null and render.is_visible_in_tree():
		world.add_child(_artwork(render, 1, CanvasItem.TEXTURE_FILTER_LINEAR))
		var door := hall.get_node_or_null(HD_DOOR) as Sprite2D
		if door != null and door.is_visible_in_tree():
			hd_door = _artwork(door, 2, CanvasItem.TEXTURE_FILTER_LINEAR)
			hd_door.frame = door.hframes - 1
			world.add_child(hd_door)

	var opening_world := Rect2(door_world + Vector2(-34, -25), Vector2(68, 77))
	var opening := Rect2(
		DOOR_CENTER + (opening_world.position - door_world) * ZOOM,
		opening_world.size * ZOOM
	)
	if hd_door == null:
		var darkness := ColorRect.new()
		doorway_shadow = darkness
		darkness.position = opening.position
		darkness.size = opening.size
		darkness.color = Color("#05030b")
		darkness.z_index = 2
		darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(darkness)
	detective = _actor(
		hall.get_node("player/VisualRoot/CharacterSprite") as AnimatedSprite2D,
		"DetectiveCG", 156.0, &"walk_up"
	)
	detective.position = Vector2(700, 440)
	detective.speed_scale = 0.8
	guardian = _actor(
		hall.get_node("CastleGuardian/GuardianCore") as AnimatedSprite2D,
		"GuardianCG", 224.0, &"walk_up_right"
	)
	guardian.position = Vector2(400, 470)
	guardian.speed_scale = 2.2
	guardian.z_index = 5
	if hd_door == null:
		_build_painted_leaf(hall, opening_world, opening)
	caption = Label.new()
	caption.name = "NearMissCaption"
	caption.position = Vector2(32, 694)
	caption.size = Vector2(960, 50)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", ArchiveUi.COLOR_PARCHMENT)
	caption.text = CaseLocale.text("cg.approach")
	root_control.add_child(caption)


## A copy of one of the Hall's artwork sprites, where it stands in the Hall.
func _artwork(original: Sprite2D, z: int, filter: CanvasItem.TextureFilter) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = original.name + "CG"
	sprite.texture = original.texture
	sprite.centered = original.centered
	sprite.offset = original.offset
	sprite.hframes = original.hframes
	sprite.vframes = original.vframes
	sprite.transform = original.global_transform
	sprite.z_index = z
	sprite.texture_filter = filter
	return sprite


## The painted look's door: a leaf cut from the Hall's walls where the door is
## painted shut, slid across the darkened doorway.
func _build_painted_leaf(hall: Node2D, opening_world: Rect2, opening: Rect2) -> void:
	var door_clip := Control.new()
	door_clip.name = "ClosingDoor"
	door_clip.position = opening.position
	door_clip.size = opening.size
	door_clip.clip_contents = true
	door_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_clip.z_index = 4
	content.add_child(door_clip)
	var wall := hall.get_node("WallCollisions/WallsVisual") as Sprite2D
	var inverse := wall.global_transform.affine_inverse()
	var atlas := AtlasTexture.new()
	atlas.atlas = wall.texture
	atlas.region = Rect2(inverse * opening_world.position, (inverse * opening_world.end) - (inverse * opening_world.position))
	leaf = TextureRect.new()
	leaf.name = "DoorLeafArtwork"
	leaf.texture = atlas
	leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	leaf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaf.size = opening.size
	leaf.position.x = opening.size.x
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_clip.add_child(leaf)


func _actor(source: AnimatedSprite2D, actor_name: String, height: float, animation_name: StringName) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = actor_name
	sprite.sprite_frames = source.sprite_frames
	# The HD look's figures are drawn smooth, as the game draws them.
	sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if source.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	var animation := animation_name if source.sprite_frames.has_animation(animation_name) else source.animation
	var texture := source.sprite_frames.get_frame_texture(animation, 0)
	var bounds := texture.get_image().get_used_rect()
	sprite.centered = false
	sprite.offset = -Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y)
	sprite.scale = Vector2.ONE * height / maxf(float(bounds.size.y), 1.0)
	sprite.z_index = 3
	content.add_child(sprite)
	sprite.play(animation)
	return sprite


func _reach() -> void:
	phase = &"reach"
	caption.text = CaseLocale.text("cg.reach")


func _close_door() -> void:
	phase = &"door"
	guardian.pause()
	caption.text = CaseLocale.text("cg.door")


## Shuts the door `amount` of the way (0 open, 1 shut): the HD door swings back
## through its frames; the painted leaf slides across the doorway.
func _swing_shut(amount: float) -> void:
	if hd_door != null:
		hd_door.frame = roundi((hd_door.hframes - 1) * (1.0 - amount))
	elif leaf != null:
		leaf.position.x = leaf.size.x * (1.0 - amount)


func _door_impact() -> void:
	phase = &"escaped"
	if doorway_shadow != null:
		doorway_shadow.hide()
	GameAudio.play(&"switch_throw")
	caption.text = CaseLocale.text("hall.near_miss_escape")


func finish() -> void:
	if completed:
		return
	completed = true
	if timeline != null and timeline.is_valid():
		timeline.kill()
	finished.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not completed and event.is_action_pressed("ui_cancel"):
		finish()
		get_viewport().set_input_as_handled()
