extends SceneTree

## Panels are contracts: nothing they own may render outside their own frame.
## Long localized copy is the stress case — a wrong answer prints a full
## explanation, and a six-step objective prints a full sentence.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_minigame_panel_contains_its_content()
	await _test_objective_cards_fit_their_copy()
	_finish()


func _test_minigame_panel_contains_its_content() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true

	var shell_scene := load("res://scripts/flame_air_minigame.gd") as GDScript
	var game: Node = shell_scene.new()
	root.add_child(game)
	game.call("configure", "Candle and Jar", "Work out which flame goes out first.", Color.WHITE)
	game.call("start")
	await process_frame
	await process_frame

	var panel := game.get_node_or_null("MinigameRoot/Panel") as Panel
	_expect(panel != null, "Minigame panel exists")
	if panel == null:
		game.queue_free()
		await process_frame
		return

	# Drive the losing branch: it prints the longest string in the whole game.
	# A Label with no wrapping reports a huge minimum width, which drags the
	# shared VBox — and therefore every jar, the title and the footer — far
	# outside the fixed-width panel.
	game.call(
		"report_level_failed",
		"Not there. Position 1 belongs to the jar with air 4 and vents 0: "
		+ "it lasts 4 ticks, and the one you put there lasts 8 ticks. "
		+ "Air divided by (wick minus vents) gives the burn."
	)
	await process_frame
	await process_frame

	var panel_rect := panel.get_global_rect()
	var overflowing: Array[String] = []
	_collect_overflow(panel, panel_rect, overflowing)
	_expect(
		overflowing.is_empty(),
		"Wrong-answer minigame keeps every element inside its panel (%s)" % [overflowing]
	)

	# A Label draws past its own rect unless it wraps or clips, so the box can
	# sit inside the panel while the glyphs run outside it. That is exactly the
	# failure the player sees, and rect checks alone never catch it.
	var spilling: Array[String] = []
	_collect_text_spill(panel, spilling)
	_expect(
		spilling.is_empty(),
		"Wrong-answer minigame text stays inside its own box (%s)" % [spilling]
	)

	# The content area must actually seat what the level puts in it, or the pick
	# row prints on top of the banner underneath it.
	var content := game.get("content") as Control
	var tallest := 0.0
	for child: Node in content.get_children():
		var control := child as Control
		if control != null:
			tallest = maxf(tallest, control.size.y)
	_expect(
		tallest <= content.size.y + 0.5,
		"Minigame content area seats its level (needs %.0fpx, has %.0fpx)" % [
			tallest, content.size.y
		]
	)

	game.queue_free()
	await process_frame
	game_state.game_started = false
	game_state.set("_loading_save", false)


func _test_objective_cards_fit_their_copy() -> void:
	var case_locale := root.get_node("CaseLocale")
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.set("return_spawn_id", "wake_room_start")

	for language: String in ["en", "zh"]:
		case_locale.call("set_language", language)
		var packed := load("res://scenes/wake_room.tscn") as PackedScene
		var room := packed.instantiate()
		root.add_child(room)
		await process_frame
		await process_frame

		var panel := room.get("first_lead_objective_panel") as Panel
		var body := room.get("first_lead_objective_body") as Label
		_expect(
			panel != null and body != null,
			"Wake Room objective card exists in %s" % language
		)
		if panel != null and body != null:
			# Step 2 carries the longest sentence in the Wake Room chain.
			game_state.call("set_story_flag", "wake_tutorial_door_checked")
			room.call("_refresh_first_lead_objective", false)
			await process_frame
			_assert_card_fits(panel, body, "Wake objective", language)
		room.queue_free()
		await process_frame

	# Chemistry's card runs the same three-step chain and the same risk.
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.set("return_spawn_id", "chemistry_start")
	for language: String in ["en", "zh"]:
		case_locale.call("set_language", language)
		var chem_packed := load("res://scenes/floor_1/chemistry_room.tscn") as PackedScene
		var chem := chem_packed.instantiate()
		root.add_child(chem)
		current_scene = chem
		await process_frame
		await process_frame
		var chem_panel := chem.get("case_objective_panel") as Panel
		var chem_body := chem.get("case_objective_body") as Label
		_expect(
			chem_panel != null and chem_body != null,
			"Chemistry objective card exists in %s" % language
		)
		if chem_panel != null and chem_body != null:
			_assert_card_fits(chem_panel, chem_body, "Chemistry objective", language)
		if current_scene == chem:
			current_scene = null
		chem.queue_free()
		await process_frame

	# The Hall route card carries a compass line under its body, so it sizes
	# differently and needs its own guard.
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.call("grant_wake_room_toolkit")
	game_state.set("return_spawn_id", "wake_room_first_arrival")
	game_state.set("current_room_id", "floor_1_hub")
	for language: String in ["en", "zh"]:
		case_locale.call("set_language", language)
		var hall_packed := load("res://scenes/game_world.tscn") as PackedScene
		var hall := hall_packed.instantiate()
		root.add_child(hall)
		current_scene = hall
		await process_frame
		await process_frame
		hall.call("_begin_hall_arrival_route")
		await process_frame
		var route_panel := hall.get("hall_route_panel") as Panel
		var route_body := hall.get("hall_route_body") as Label
		var compass := hall.get("hall_route_compass") as Label
		_expect(
			route_panel != null and route_body != null and compass != null,
			"Hall route card exists in %s" % language
		)
		if route_panel != null and route_body != null and compass != null:
			_assert_card_fits(route_panel, route_body, "Hall route", language)
			_expect(
				compass.position.y + compass.size.y <= route_panel.size.y + 0.5,
				"Hall route compass stays inside its card in %s (%.0fpx in %.0fpx)" % [
					language, compass.position.y + compass.size.y, route_panel.size.y
				]
			)
		if current_scene == hall:
			current_scene = null
		hall.queue_free()
		await process_frame

	case_locale.call("set_language", "en")
	game_state.reset_new_game()
	game_state.game_started = false
	game_state.set("_loading_save", false)


func _assert_card_fits(panel: Panel, body: Label, label: String, language: String) -> void:
	var needed := _label_height(body)
	_expect(
		needed <= body.size.y + 0.5,
		"%s body fits its box in %s (needs %.0fpx, has %.0fpx)" % [
			label, language, needed, body.size.y
		]
	)
	_expect(
		body.position.y + needed <= panel.size.y + 0.5,
		"%s card is tall enough for its copy in %s (needs %.0fpx, card %.0fpx)" % [
			label, language, body.position.y + needed, panel.size.y
		]
	)


## Height this label actually needs to render its current text at its width.
func _label_height(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null:
		return 0.0
	var wrapped := font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		label.size.x,
		font_size
	)
	return wrapped.y


func _collect_overflow(node: Node, bounds: Rect2, out: Array[String]) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and control.visible and control.size.x > 0.0:
			var rect := control.get_global_rect()
			# A 1px tolerance keeps rounding off the failure list.
			if (
				rect.position.x < bounds.position.x - 1.0
				or rect.end.x > bounds.end.x + 1.0
				or rect.position.y < bounds.position.y - 1.0
				or rect.end.y > bounds.end.y + 1.0
			):
				out.append("%s %s" % [control.name, rect])
		_collect_overflow(child, bounds, out)


## A Label with no wrapping and no clipping renders its glyphs straight past
## its own rect. Godot reports the Control as correctly sized, so this has to be
## measured against the font instead.
func _collect_text_spill(node: Node, out: Array[String]) -> void:
	for child: Node in node.get_children():
		var label := child as Label
		if (
			label != null
			and label.visible
			and not label.text.is_empty()
			and label.size.x > 0.0
			and label.autowrap_mode == TextServer.AUTOWRAP_OFF
			and not label.clip_text
		):
			var font := label.get_theme_font("font")
			var font_size := label.get_theme_font_size("font_size")
			if font != null:
				var width := font.get_string_size(
					label.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size
				).x
				if width > label.size.x + 1.0:
					out.append(
						"%s needs %.0fpx in %.0fpx" % [label.name, width, label.size.x]
					)
		_collect_text_spill(child, out)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("panel_overflow_test: PASS")
		quit(0)
	else:
		printerr("panel_overflow_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
