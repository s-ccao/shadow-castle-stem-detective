extends SceneTree

var flame_script: GDScript
var jar_script: GDScript
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flame_script = load("res://scripts/flame_air_minigame.gd") as GDScript
	jar_script = load("res://scripts/flame_jar_view.gd") as GDScript
	if not flame_script.can_instantiate() or not jar_script.can_instantiate():
		printerr("flame_presentation_test: FAIL (scripts did not compile)")
		quit(1)
		return
	for language: String in ["en", "zh"]:
		root.get_node("CaseLocale").call("set_language", language)
		await _check_visible_wicks_and_phases(language)
	await _check_actual_playback()
	if failures.is_empty():
		print("flame_presentation_test: PASS")
		quit(0)
	else:
		printerr("flame_presentation_test: FAIL (%d assertions)" % failures.size())
		quit(1)

func _check_visible_wicks_and_phases(language: String) -> void:
	var previous_wick_width := 0.0
	var previous_flame := Vector2.ZERO
	for multiplier: int in [1, 2, 3]:
		var jar: Control = jar_script.new()
		jar.set("burn", float(multiplier))
		jar.size = Vector2(118, 172)
		root.add_child(jar)
		jar.set_process(false)
		var tips: PackedVector2Array = jar.call("wick_positions")
		_expect(tips.size() == 1, "%s: %dx still has exactly one wick" % [language, multiplier])
		for index: int in range(tips.size()):
			var rect: Rect2 = jar.call("jar_rect")
			_expect(rect.has_point(tips[index]), "Wick stays inside its glass")
		_expect(jar.has_method("wick_width"), "Wick thickness represents the burn multiplier")
		if jar.has_method("wick_width"):
			var width: float = jar.call("wick_width")
			_expect(width > previous_wick_width, "Higher multiplier has a visibly thicker single wick")
			previous_wick_width = width
		var label := jar.get_node("FlameState") as Label
		_expect(not bool(jar.call("is_lit")) and not label.text.is_empty(), "Unlit state is explicit before predicting")
		if jar.has_method("flame_dimensions"):
			_expect(jar.call("flame_dimensions") == Vector2.ZERO, "Unlit wick has no phantom flame")
		var cold_text := label.text
		jar.call("ignite")
		var ignition_text := label.text
		jar.call("_process", jar_script.get_script_constant_map()["IGNITE_TIME"] + 0.01)
		_expect(bool(jar.call("is_lit")) and label.text != cold_text and label.text != ignition_text,
			"Ignition settles into a distinct burning state")
		_expect(jar.has_method("flame_dimensions"), "Flame geometry exposes the drawn intensity")
		if jar.has_method("flame_dimensions"):
			jar.set("_time", 1.0)
			jar.set("_seed", 0.0)
			var dimensions: Vector2 = jar.call("flame_dimensions")
			_expect(dimensions.x > previous_flame.x and dimensions.y > previous_flame.y,
				"Equal oxygen supply: a higher multiplier makes one wider, taller flame")
			if multiplier == 3:
				_expect(dimensions.x >= 20.0, "The 3x flame is visibly broad at native size")
			previous_flame = dimensions
		jar.call("extinguish")
		jar.call("reveal_order", 1)
		jar.call("_process", jar_script.get_script_constant_map()["GUTTER_TIME"] + 0.01)
		_expect(not bool(jar.call("is_lit")) and label.text.contains("2"), "Snuffed candle shows its actual extinction order")
		if jar.has_method("flame_dimensions"):
			_expect(jar.call("flame_dimensions") == Vector2.ZERO, "Snuffed flame is absent, not merely recolored")
		jar.call("reset_flame")
		_expect(label.text == cold_text and jar.get("verdict") == -1, "Retry clears the outcome and returns to unlit")
		jar.set("eternal", true)
		jar.call("ignite")
		jar.call("_process", jar_script.get_script_constant_map()["IGNITE_TIME"] + 0.01)
		_expect(label.text == ("持续补气" if language == "zh" else "Air sustained"),
			"Sustained flame has a distinct state, not a false extinction")
		jar.queue_free()
		await process_frame

func _check_actual_playback() -> void:
	var game: Node = flame_script.new()
	root.add_child(game)
	game.call("configure", "Candle and Jar", "Presentation regression", Color.WHITE)
	game.call("start")
	game.set_process(false)
	var levels: Array = flame_script.get_script_constant_map()["LEVELS"]
	for level: int in range(levels.size()):
		game.set("_level_index", level)
		game.call("_enter_level")
		await process_frame
		var correct: Array[int] = game.call("_correct_order")
		var wrong := correct.duplicate()
		wrong.reverse()
		_expect(wrong != correct, "Stage %d exercises a genuinely wrong prediction" % (level + 1))
		for index: int in wrong:
			game.call("_on_pick", index)
		game.call("_on_pick", wrong[0])
		var selected: Array[int] = game.get("_order")
		_expect(selected.size() == wrong.size() - 1, "Clicking a chosen jar removes only that prediction")
		_expect((game.get("_confirm") as Button).disabled, "Removing a choice requires completing the order again")
		game.call("_on_reset")
		for index: int in wrong:
			game.call("_on_pick", index)
		var views: Array = game.get("_views")
		game.call("_on_confirm")
		_expect(bool(game.get("_running")), "Ignite starts real playback")
		# Use the same fixed step for the simulation and its presentation.
		for tick: int in range(260):
			game.call("_process", 1.0 / 60.0)
			for view: Control in views:
				view.call("_process", 1.0 / 60.0)
		_expect(not bool(game.get("_running")) and int(game.call("levels_cleared")) == 0,
			"Wrong prediction finishes without advancing or awarding progress")
		for index: int in range(views.size()):
			var view: Control = views[index]
			var jar: Dictionary = levels[level][index]
			_expect(bool(view.call("is_lit")) == (float(jar["vents"]) >= float(jar["burn"])),
				"Stage %d jar %d: only air-sustained flames remain lit" % [level + 1, index + 1])
		_expect(not (game.get("_reset") as Button).disabled, "Wrong answer leaves retry available")
		game.call("_on_reset")
		_expect((game.get("_order") as Array).is_empty(), "Reset clears prediction")
	game.queue_free()
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	printerr("FAIL: " + description)
