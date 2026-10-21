extends SceneTree

## The opening has to teach a first-time player, not brief a developer.
##
## Measured failure of the previous version: at one instant the game handed over
## control, raised a modal control card, and animated the objective card in
## behind that modal. A player received three things simultaneously, practised
## none of them, and the objective card's only entrance played where it could
## not be seen. Players reported the game as having no tutorial at all.
##
## The contract below is what a beginner needs: one thing at a time, taught in
## context, and not advanced until they have actually done it.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.game_started = true

	var wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await process_frame
	await process_frame

	var player := wake.get_node_or_null("player") as CharacterBody2D
	_expect(player != null, "Wake Room has a player")
	if player == null:
		_finish()
		return

	# Wait out the wake-up staging, then look at the frame control returns on.
	var waited := 0.0
	while waited < 8.0 and not player.is_physics_processing():
		await create_timer(0.1).timeout
		waited += 0.1
	_expect(player.is_physics_processing(), "Control is handed to the player")

	var coach := wake.get_node_or_null("%TutorialCoach") as Node
	if coach == null:
		coach = wake.find_child("TutorialCoach", true, false)
	_expect(coach != null, "Wake Room runs a tutorial coach")

	var hud := root.get_node_or_null("OnboardingHud")
	var modal := (
		hud.get_node_or_null("FieldOrientationOverlay") as Control
		if hud != null
		else null
	)
	# One thing at a time. A modal at the moment of handover buries whatever
	# else is arriving, which is what made the objective card invisible.
	_expect(
		modal == null or not modal.visible,
		"No modal covers the screen at the moment control is handed over"
	)
	_expect(
		not paused,
		"The game is running when the player first gains control"
	)

	# The first lesson deliberately does not land on the handover frame, so wait
	# for it to arrive rather than sampling immediately.
	if coach != null:
		var appeared := 0.0
		while appeared < 3.0 and str(coach.call("current_lesson")).is_empty():
			await create_timer(0.1).timeout
			appeared += 0.1
		_expect(
			str(coach.call("current_lesson")) == "move",
			"The first lesson taught is movement (got '%s')" % coach.call("current_lesson")
		)
		_expect(
			appeared >= 0.2,
			"The first lesson does not land on the same frame as the handover (%.1fs)" % appeared
		)
		var before := str(coach.call("current_lesson"))
		_expect(before == "move", "Movement lesson is on screen before the idle check")
		for _idle: int in range(40):
			await process_frame
		_expect(
			str(coach.call("current_lesson")) == before,
			"The movement lesson waits rather than timing out on a player who has not moved"
		)

		# Move the player: the lesson must clear itself.
		var origin: Vector2 = player.global_position
		player.global_position = origin + Vector2(120.0, 0.0)
		for _step: int in range(20):
			await process_frame
		_expect(
			str(coach.call("current_lesson")) != "move",
			"Moving clears the movement lesson"
		)

	# The transferable rule of the whole game must be stated in words at least
	# once. Without it a player treats every later door as an arbitrary quiz.
	var locale := root.get_node("CaseLocale")
	for key: String in ["guide.rule_title", "guide.rule_body"]:
		for language: String in ["en", "zh"]:
			locale.call("set_language", language)
			var value := str(locale.call("text", key))
			_expect(
				not value.is_empty() and value != key,
				"The dual-lock rule has %s copy (%s)" % [language, key]
			)
	locale.call("set_language", "en")
	_check_hall_card_rows(hud, locale)

	if current_scene == wake:
		current_scene = null
	wake.queue_free()
	await process_frame
	gs.call("reset_new_game")
	gs.game_started = false
	_finish()


## The Hall card's English move hint wrapped to a third line and printed over
## the inspect row beneath it. Each row must clear the one above in both
## languages and stay inside the card.
func _check_hall_card_rows(hud: Node, locale: Node) -> void:
	if hud == null:
		_expect(false, "The onboarding HUD exists for the Hall card check")
		return
	var previous_context: StringName = hud.get("_orientation_context")
	hud.set("_orientation_context", &"hall")
	for language: String in ["en", "zh"]:
		locale.call("set_language", language)
		hud.call("_refresh_copy")
		var move := hud.get("move_detail_label") as Label
		var keycap := hud.get("inspect_keycap") as Label
		var inspect := hud.get("inspect_detail_label") as Label
		var card := hud.get("field_card") as Control
		var move_bottom := move.position.y + float(move.get_line_count() * move.get_line_height())
		_expect(
			keycap.position.y >= move_bottom and inspect.position.y >= move_bottom,
			"%s Hall card: the inspect row clears the move hint (%.0f >= %.0f)" % [
				language, inspect.position.y, move_bottom
			]
		)
		_expect(
			keycap.position.y + keycap.size.y <= card.size.y - 12.0,
			"%s Hall card: the inspect row stays inside the card" % language
		)
	hud.set("_orientation_context", previous_context)
	hud.call("_refresh_copy")
	locale.call("set_language", "en")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("tutorial_onboarding_test: PASS")
		quit(0)
	else:
		printerr(
			"tutorial_onboarding_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
