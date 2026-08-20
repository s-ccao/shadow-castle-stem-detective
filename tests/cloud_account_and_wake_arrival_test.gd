extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_account_ui()
	await _test_wake_arrival()
	_finish()


func _test_account_ui() -> void:
	var account_ui_script: Script = load("res://scripts/cloud_account_ui.gd")
	var account_ui: Control = account_ui_script.new()
	root.add_child(account_ui)
	await process_frame
	account_ui.open()
	await process_frame
	_expect(account_ui.visible, "Cloud account dialog opens")
	_expect(
		account_ui.username_field.visible and account_ui.password_field.visible,
		"Signed-out dialog exposes Investigator ID and passphrase fields"
	)
	_expect(
		account_ui.panel.position.x >= 0.0
		and account_ui.panel.position.y >= 0.0
		and account_ui.panel.position.x + account_ui.panel.size.x
			<= root.get_viewport().get_visible_rect().size.x
		and account_ui.panel.position.y + account_ui.panel.size.y
			<= root.get_viewport().get_visible_rect().size.y,
		"Cloud account dialog remains inside the game viewport "
		+ "(panel=%s/%s viewport=%s)" % [
			account_ui.panel.position,
			account_ui.panel.size,
			root.get_viewport().get_visible_rect().size,
		]
	)
	account_ui.close()
	account_ui.queue_free()
	await process_frame


func _test_wake_arrival() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.set("game_started", true)
	game_state.set("return_spawn_id", "wake_room_start")
	(game_state.get("story_flags") as Dictionary).erase("wake_room_arrival_complete")

	var packed_scene := load("res://scenes/wake_room.tscn") as PackedScene
	var wake_room := packed_scene.instantiate()
	root.add_child(wake_room)
	await process_frame
	await process_frame

	var player := wake_room.get_node("player") as CharacterBody2D
	_expect(
		player.position.x < 380.0,
		"First arrival begins beside the bed instead of in the room center"
	)
	_expect(
		not player.is_physics_processing(),
		"Movement stays locked during the wake-up staging"
	)
	_expect(
		wake_room.get_node_or_null("WakeArrivalLayer") != null,
		"Wake-up staging adds the location reveal layer"
	)

	await create_timer(4.6).timeout
	_expect(
		player.is_physics_processing(),
		"Movement returns after the wake-up staging"
	)
	_expect(
		game_state.call("has_story_flag", "wake_room_arrival_complete"),
		"Completed wake-up staging is persisted and will not replay on resume"
	)
	_expect(
		player.position.distance_to(Vector2(336.0, 500.0)) < 48.0,
		"Wake-up staging leaves the detective on a safe first step"
	)

	wake_room.queue_free()
	await process_frame
	game_state.set("game_started", false)
	game_state.set("_loading_save", false)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("cloud_account_and_wake_arrival_test: PASS")
		quit(0)
		return
	printerr(
		"cloud_account_and_wake_arrival_test: FAIL (%d assertion(s))" % failures.size()
	)
	quit(1)
