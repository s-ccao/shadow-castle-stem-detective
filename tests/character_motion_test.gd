extends SceneTree

var failures: Array[String] = []

class FloorStage:
	extends Node2D
	var block_x := false
	var block_all := false

	func is_player_position_walkable(point: Vector2) -> bool:
		return not block_all and (not block_x or point.x <= 0.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.set("_loading_save", true)
	state.reset_new_game()
	await _test_player()
	await _test_guardian()
	await _test_guardian_travel()
	await _test_scripted_guardian_pose()
	await _test_interview_npcs()
	if failures.is_empty():
		print("character_motion_test: PASS")
	else:
		printerr("character_motion_test: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _test_player() -> void:
	var stage := FloorStage.new()
	root.add_child(stage)
	var player := load("res://scenes/player.tscn").instantiate() as CharacterBody2D
	stage.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("VisualRoot/CharacterSprite") as AnimatedSprite2D
	player.call("update_character_animation", Vector2(180.0, 0.0))
	sprite.set_frame_and_progress(3, 0.42)
	player.call("update_character_animation", Vector2(0.0, 180.0))
	_expect_phase(sprite, 3, 0.42, "Player turning preserves stride phase")
	var normal_scale := sprite.speed_scale
	player.call("update_character_animation", Vector2(0.0, 252.0))
	_expect(is_equal_approx(sprite.speed_scale / normal_scale, 1.4), "Swift cadence tracks speed")
	player.call("update_character_animation", Vector2(0.0, 10.0))
	_expect(sprite.speed_scale < normal_scale / 10.0, "A short last step does not animate at a forced fast crawl")
	player.call("update_character_animation", Vector2(180.0, 0.0))
	player.call("update_character_animation", Vector2.RIGHT.rotated(deg_to_rad(23.0)) * 180.0)
	_expect(sprite.animation == &"walk_right", "Player direction holds near an octant boundary")
	player.call("update_character_animation", Vector2.RIGHT.rotated(deg_to_rad(32.0)) * 180.0)
	_expect(sprite.animation == &"walk_down_right", "Player commits a deliberate diagonal turn")

	stage.block_all = true
	player.call("move_to_point", Vector2(180.0, 0.0))
	player.call("_physics_process", 1.0 / 60.0)
	_expect(player.position.is_zero_approx(), "Blocked floor keeps player body stationary")
	_expect(not sprite.is_playing() and sprite.frame == 0, "Blocked floor holds planted feet")

	stage.block_all = false
	stage.block_x = true
	player.call("move_to_point", Vector2(180.0, 180.0))
	player.call("_physics_process", 1.0 / 60.0)
	_expect(sprite.animation == &"walk_down", "Wall slide faces actual travel instead of blocked diagonal")
	var actual_speed := player.position.length() * 60.0
	_expect(
		is_equal_approx(sprite.speed_scale, actual_speed * 1.6 / 84.0),
		"Wall slide cadence uses actual displacement"
	)

	player.call("cancel_click_movement")
	player.set_physics_process(false)
	_expect(not sprite.is_playing() and sprite.frame == 0, "Cancelling movement immediately plants feet before a modal")
	stage.block_x = false
	player.position = Vector2.ZERO
	player.call("move_to_point", Vector2(14.0, 0.0))
	player.call("_physics_process", 0.1)
	_expect(not bool(player.get("click_movement_active")), "Destination completes normally")
	_expect(not sprite.is_playing() and sprite.frame == 0, "Arrival plants feet in the arrival tick")
	Input.action_press("move_right")
	player.call("_physics_process", 1.0 / 60.0)
	sprite.set_frame_and_progress(3, 0.42)
	player.call("_physics_process", 1.0 / 60.0)
	_expect_phase(sprite, 3, 0.42, "Held keyboard input does not repeatedly cancel its own stride")
	Input.action_release("move_right")

	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	_expect(player.scale == Vector2.ONE and collision.scale == Vector2.ONE, "Player body and collision scales are unchanged")
	stage.queue_free()
	await process_frame


func _test_guardian() -> void:
	var guardian := load("res://scenes/enemy.tscn").instantiate() as CharacterBody2D
	root.add_child(guardian)
	guardian.set_physics_process(false)
	var sprite := guardian.get_node("GuardianCore") as AnimatedSprite2D
	_expect(not sprite.is_playing() and sprite.frame == 0, "Guardian starts planted before setup/reveal")
	var names := [
		&"walk_up", &"walk_up_right", &"walk_right", &"walk_down_right",
		&"walk_down", &"walk_down_left", &"walk_left", &"walk_up_left",
	]
	for row: int in range(names.size()):
		var name: StringName = names[row]
		_expect(sprite.sprite_frames.has_animation(name), "Guardian exposes " + str(name))
		if sprite.sprite_frames.has_animation(name):
			var atlas := sprite.sprite_frames.get_frame_texture(name, 0) as AtlasTexture
			_expect(atlas.region.position.y == row * 156, "Guardian uses authored row for " + str(name))
		guardian.call("_update_animation", Vector2.UP.rotated(row * PI / 4.0) * 145.0)
		_expect(sprite.animation == name, "Guardian faces " + str(name))
	guardian.call("_update_animation", Vector2(145.0, 0.0))
	sprite.set_frame_and_progress(5, 0.37)
	guardian.call("_update_animation", Vector2(0.0, 145.0))
	_expect_phase(sprite, 5, 0.37, "Guardian turning preserves stride phase")
	guardian.call("_update_animation", Vector2.ZERO)
	_expect(not sprite.is_playing() and sprite.frame == 0, "Guardian idle is not a slow-motion walk")
	guardian.call("_update_animation", Vector2(44.0, 0.0))
	var patrol_scale := sprite.speed_scale
	guardian.call("_update_animation", Vector2(220.0, 0.0))
	_expect(is_equal_approx(sprite.speed_scale / patrol_scale, 5.0), "Guardian cadence follows patrol/chase speed")
	var seam_direction := Vector2.RIGHT.rotated(deg_to_rad(23.0))
	guardian.call("_update_animation", seam_direction * 145.0)
	_expect(sprite.animation == &"walk_right", "Guardian artwork resists octant-boundary jitter")
	_expect(
		(guardian.get("facing_direction") as Vector2).is_equal_approx(seam_direction),
		"Guardian visual hysteresis does not quantize its line-of-sight facing"
	)
	guardian.call("set_cinematic_hold", true)
	_expect(not sprite.is_playing(), "Cinematic hold plants Guardian feet")
	var collision := guardian.get_node("CollisionShape2D") as CollisionShape2D
	_expect(guardian.scale == Vector2.ONE and collision.scale == Vector2.ONE, "Guardian body and collision scales are unchanged")
	_expect(sprite.scale == Vector2(0.8, 0.8) and sprite.position == Vector2(0.0, -44.8), "Guardian size and foot anchor are unchanged")
	guardian.queue_free()
	await process_frame


func _test_interview_npcs() -> void:
	var butler := AnimatedNpc.new()
	butler.configure("Butler", "res://assets/characters/animated_pixel_v5/butler_idle_8dir.png",
		2.1, Vector2(14.0, 0.0), 11.0, &"south", Vector2i(48, 68), 8, true, true)
	butler.set_visual_foot_anchor(Vector2(0.0, -48.3))
	root.add_child(butler)
	butler.set_process(false)
	var sprite := butler.actor_sprite
	sprite.set_frame_and_progress(4, 0.61)
	butler.call("_play_idle", &"west")
	_expect_phase(sprite, 4, 0.61, "Butler turns without restarting its breathing loop")
	butler.set("_facing", &"east")
	var boundary_direction := Vector2.RIGHT.rotated(deg_to_rad(23.0)) * 100.0
	_expect(butler.call("_direction_name", boundary_direction) == &"east", "Interview gaze holds at the octant seam")
	_expect(butler.call("_direction_name", Vector2.ZERO) == &"east", "Overlapping target does not snap NPC gaze")
	_expect(butler.call("_direction_name", Vector2.DOWN * 100.0) == &"south", "Interview gaze follows a deliberate turn")
	butler.call("_set_notice_scale", 1.06)
	_expect(
		(sprite.position + Vector2(0.0, 23.0) * sprite.scale).is_zero_approx(),
		"Noticing scales the Butler around its planted feet"
	)
	butler.call("_set_notice_scale", 1.0)
	_expect(sprite.position.is_equal_approx(Vector2(0.0, -48.3)), "Notice settles back to the authored foot anchor")

	var gardener := AnimatedNpc.new()
	gardener.configure("Gardener", "res://assets/characters/animated_pixel_v3/gardener_walk.png",
		0.43, Vector2(14.0, 0.0), 11.0, &"right")
	root.add_child(gardener)
	gardener.set_process(false)
	_expect(gardener.call("_direction_name", Vector2(99.0, 100.0)) == &"right", "Four-direction interview gaze resists diagonal jitter")
	_expect(gardener.actor_sprite.sprite_frames.get_frame_count(&"idle_right") == 1, "Interview walker keeps one standing frame")
	_expect(butler.position == Vector2.ZERO and gardener.position == Vector2.ZERO, "Interview NPCs never acquire wandering motion")
	butler.queue_free()
	gardener.queue_free()
	await process_frame


func _test_guardian_travel() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var guardian := load("res://scenes/enemy.tscn").instantiate() as CharacterBody2D
	stage.add_child(guardian)
	guardian.set_physics_process(false)
	guardian.set("behavior", 1)
	guardian.set("path", PackedVector2Array([Vector2.ZERO, Vector2(180.0, 0.0)]))
	guardian.call("_update_animation", Vector2(145.0, 0.0))
	var sprite := guardian.get_node("GuardianCore") as AnimatedSprite2D
	sprite.set_frame_and_progress(3, 0.25)
	await physics_frame
	guardian.call("move_along_path", 1.0 / 60.0)
	_expect(guardian.position.x > 0.0, "A reached Guardian waypoint does not consume a motionless tick")
	_expect(sprite.is_playing(), "Guardian walks continuously through an intermediate waypoint")

	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10.0, 50.0)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = guardian.position + Vector2(12.1, -4.0)
	stage.add_child(wall)
	await physics_frame
	guardian.call("move_along_path", 1.0 / 60.0)
	await physics_frame
	var blocked_position := guardian.position
	guardian.call("move_along_path", 1.0 / 60.0)
	_expect(guardian.position.distance_to(blocked_position) < 0.01, "Guardian collision rejects the intended forward stride")
	_expect(not sprite.is_playing() and sprite.frame == 0, "Blocked Guardian does not walk against a wall")
	stage.queue_free()
	await process_frame


func _expect_phase(sprite: AnimatedSprite2D, frame: int, progress: float, description: String) -> void:
	_expect(sprite.frame == frame and is_equal_approx(sprite.frame_progress, progress), description)


func _test_scripted_guardian_pose() -> void:
	var guardian := load("res://scenes/enemy.tscn").instantiate() as CharacterBody2D
	root.add_child(guardian)
	guardian.set_physics_process(false)
	_expect(guardian.has_method("present_scripted_step"), "Tutorial marks have a stride-preserving presentation path")
	if guardian.has_method("present_scripted_step"):
		var sprite := guardian.get_node("GuardianCore") as AnimatedSprite2D
		guardian.call("present_scripted_step", Vector2.ZERO, Vector2(200, 0))
		guardian.call("present_scripted_step", Vector2(48, 0), Vector2(200, 0))
		var frame := sprite.frame
		var progress := sprite.frame_progress
		_expect(frame != 0 or progress > 0.0, "A tutorial step advances the rendered stride")
		for tick: int in range(5):
			guardian.call("_update_animation", Vector2.ZERO)
			guardian.call("present_scripted_step", Vector2(48, 0), Vector2(200, 0))
		_expect_phase(sprite, frame, progress, "Between tutorial steps the stride is not reset every render frame")
		_expect(guardian.position == Vector2(48, 0), "Scripted presentation preserves the exact safety mark")
		guardian.call("clear_scripted_presentation")
		guardian.call("_update_animation", Vector2(145, 0))
		_expect(sprite.is_playing(), "Live chase resumes ordinary locomotion after the tutorial")
	guardian.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		printerr("FAIL: " + description)
