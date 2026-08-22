extends SceneTree

## The cast is set dressing, not a crowd of wanderers. Every NPC used to slide
## between two points forever, and an idle-only sheet slid without ever having a
## walk frame to justify the motion, which reads as the whole cast milling about.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_npcs_hold_their_mark_and_face_the_player()
	await _test_resting_pose_is_not_a_slow_walk()
	_finish()





## An idle-only NPC is standing art: every frame of its sheet belongs to the
## resting loop. A walking NPC's sheet is a stride, so resting on the whole
## cycle plays a slow-motion walk in place — legs stepping, body going nowhere.
func _test_resting_pose_is_not_a_slow_walk() -> void:
	var walker := AnimatedNpc.new()
	walker.configure(
		"Gardener",
		"res://assets/characters/animated_pixel_v3/gardener_walk.png",
		0.43,
		Vector2(14.0, 0.0),
		11.0,
		&"left"
	)
	root.add_child(walker)
	await process_frame
	var walk_sprite := walker.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if walk_sprite != null:
		var frames := walk_sprite.sprite_frames
		_expect(
			frames.get_frame_count(&"walk_left") > 1,
			"A walking NPC still has a full stride cycle"
		)
		_expect(
			frames.get_frame_count(&"idle_left") == 1,
			"A resting walker holds one standing pose (%d frames)" % frames.get_frame_count(&"idle_left")
		)
	walker.queue_free()
	await process_frame

	var stander := AnimatedNpc.new()
	stander.configure(
		"Butler",
		"res://assets/characters/animated_pixel_v5/butler_idle_8dir.png",
		2.10,
		Vector2.ZERO,
		0.0,
		&"south",
		Vector2i(48, 68),
		8,
		true,
		true
	)
	root.add_child(stander)
	await process_frame
	var idle_sprite := stander.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if idle_sprite != null:
		var idle_frames := idle_sprite.sprite_frames
		_expect(
			idle_frames.get_frame_count(&"idle_south") > 1,
			"A dedicated idle sheet keeps its whole breathing loop (%d frames)" % idle_frames.get_frame_count(&"idle_south")
		)
	stander.queue_free()
	await process_frame


## NPCs are stationary cast, not wanderers. They hold their mark, turn to face
## the player who walks up to them, and otherwise stay in their own pose.
func _test_npcs_hold_their_mark_and_face_the_player() -> void:
	var stage := Node2D.new()
	root.add_child(stage)

	var stand_in := CharacterBody2D.new()
	stand_in.name = "player"
	stand_in.add_to_group(&"player")
	stand_in.global_position = Vector2(2000.0, 2000.0)
	stage.add_child(stand_in)

	var npc := AnimatedNpc.new()
	npc.configure(
		"Gardener",
		"res://assets/characters/animated_pixel_v3/gardener_walk.png",
		0.43,
		Vector2(18.0, 0.0),
		12.0,
		&"left"
	)
	npc.position = Vector2(500.0, 400.0)
	stage.add_child(npc)
	await process_frame

	var origin: Vector2 = npc.position
	for _frame: int in range(90):
		await process_frame
	_expect(
		npc.position.is_equal_approx(origin),
		"An NPC holds its mark even when configured with a patrol (%s)" % npc.position
	)

	var sprite := npc.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	_expect(
		sprite != null and str(sprite.animation).begins_with("idle_"),
		"An unattended NPC rests rather than walking on the spot"
	)
	var undisturbed := str(sprite.animation) if sprite != null else ""

	# Walk up on the NPC's right; it should turn to meet the player.
	stand_in.global_position = npc.global_position + Vector2(60.0, 0.0)
	for _frame: int in range(12):
		await process_frame
	_expect(
		sprite != null and str(sprite.animation) == "idle_right",
		"An NPC turns to face a player who walks up (%s)" % [
			str(sprite.animation) if sprite != null else "<none>"
		]
	)
	# Turning alone is easy to miss, so noticing plays a small reaction.
	_expect(
		npc.get("_notice_tween") != null,
		"Approaching an NPC triggers a visible reaction"
	)

	# And from the other side.
	stand_in.global_position = npc.global_position + Vector2(-60.0, 0.0)
	for _frame: int in range(12):
		await process_frame
	_expect(
		sprite != null and str(sprite.animation) == "idle_left",
		"An NPC follows the player around it"
	)
	_expect(
		npc.position.is_equal_approx(origin),
		"Facing the player never moves the NPC off its mark"
	)

	# Player leaves: the NPC goes back to its own business, not a random pose.
	stand_in.global_position = Vector2(4000.0, 4000.0)
	for _frame: int in range(20):
		await process_frame
	_expect(
		sprite != null and str(sprite.animation) == undisturbed,
		"An NPC returns to its authored pose once the player leaves (%s)" % [
			str(sprite.animation) if sprite != null else "<none>"
		]
	)

	stage.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("npc_presence_test: PASS")
		quit(0)
	else:
		printerr(
			"npc_presence_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
