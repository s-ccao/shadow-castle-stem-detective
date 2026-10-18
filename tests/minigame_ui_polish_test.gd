extends SceneTree

const CASES: Array[Dictionary] = [
	{
		"id": "flame_air", "title": ["Candle and Jar", "烛与罩"],
		"tint": Color(1.0, 0.72, 0.35),
		"subtitle": [
			"Mrs. Lin left a row of candles under glass. Work out which flame goes out first.",
			"林女士在桌上留了一排罩着玻璃的蜡烛。想清楚哪一支会最先熄灭。",
		],
		"failure": [
			"Not there. Position 1 belongs to the jar with air 4 and vents 0: it lasts 4 ticks, and the one you put there lasts 8 ticks. Air divided by (wick minus vents) gives the burn.",
			"排得不对。第 1 位应该是空气 4、通气 0 的那只：它烧 4 拍，你放的那只烧 8 拍。用空气除以「灯芯减通气」就能算出时长。",
		],
	},
	{
		"id": "change_sorting", "title": ["Material Observation Lab", "变化观察实验台"],
		"tint": Color(0.86, 0.52, 0.98),
		"subtitle": [
			"Mrs. Lin left a tray of samples to be filed. A change is chemical only when a new substance appears.",
			"林女士留下了一盘待归档的样本。只有生成了新物质才算化学变化。",
		],
		"failure": [
			"6 misfiled. Candle wax melting — Melted wax is still wax. Only the burning wick is chemical.",
			"有 6 份放错了。蜡烛的蜡熔化 —— 熔化的蜡还是蜡。真正的化学变化是烛芯在燃烧。",
		],
	},
	{
		"id": "photosynthesis", "title": ["Photosynthesis Bench", "光合工作台"],
		"tint": Color(0.62, 0.94, 0.58),
		"subtitle": [
			"Blue blossom will not swell unless light, water and air are balanced against one another.",
			"蓝铃花只有在光照、水分与空气三者彼此配平时才会饱满。",
		],
		"failure": [
			"Growth stalls at 0. WATER is the limiting factor — raising the others will not help.",
			"生长停在 0。水分 才是限制因子——把别的调高没有用。",
		],
	},
	{
		"id": "moonlight_harvest", "title": ["Moonlight Harvest", "月光采收"],
		"tint": Color(0.78, 0.88, 1.00),
		"subtitle": [
			"Moonleaf opens and closes on its own cycle. Cut only at the peak, and never cut the thorns.",
			"月叶按自己的周期开合。只在最盛时下刀，带刺的绝对别碰。",
		],
		"failure": [
			"The moon passes. The blooms close for the night — try the rhythm again.",
			"月亮偏过去了，花苞全部合拢——重新找一次节奏。",
		],
	},
	{
		"id": "elapsed_time", "title": ["Reconstructing the Hour", "推演时刻"],
		"subtitle": [
			"The clock says midnight. The ash, the wax and the ice say something else. Work out which of them is lying.",
			"钟面写着午夜。灰烬、蜡油和冰块却是另一种说法。找出在说谎的那一个。",
		],
		"failure": [
			"That is what a single indicator says. Work out the hours from each one and take the value the majority share.",
			"那只是某一条线索的说法。把每条都算一遍，取多数一致的那个值。",
		],
	},
	{
		"id": "gear_train", "title": ["The Knowledge Engine", "知识引擎"],
		"subtitle": [
			"The brass orrery will not turn until its gear train runs at the speed and direction the vault symbols call for.",
			"这台黄铜星象仪不会转动——除非传动链的转速和转向，正好对上金库符号要求的那一组。",
		],
		"failure": [
			"Ratio is 0.33x, not 0.25x. Only the first and last gear set the speed — the ones between them just pass it along.",
			"速比是 0.33x，不是 0.25x。定速度的只有首末两个齿轮——夹在中间的那些只是把转动传过去而已。",
		],
	},
]

var failures: Array[String] = []
var captures: String = ""
var layout_only: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			captures = argument.trim_prefix("--capture-dir=")
		elif argument == "--layout-only":
			layout_only = true
	call_deferred("_run")


func _run() -> void:
	var isolated_home: String = OS.get_environment("HOME")
	var user_path: String = OS.get_user_data_dir()
	if not isolated_home.begins_with(ProjectSettings.globalize_path("res://")) \
			or not user_path.begins_with(isolated_home):
		printerr("Refusing UI QA without project-local isolated HOME: " + user_path)
		quit(2)
		return
	print("UI QA data: " + user_path)
	var route_store := load("res://scripts/hall_route_store.gd") as GDScript
	route_store.use_test_path("user://ui_qa_route.json")
	var state := root.get_node("GameState")
	state.set("_loading_save", true)
	state.set("game_started", false)
	root.size = Vector2i(1024, 768)
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	await _layout_audit()
	if not layout_only:
		await _flow_audit()
	route_store.clear_test_path()
	paused = false
	root.get_node("GameAudio").queue_free()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("minigame_ui_polish_test: PASS")
		quit(0)
	else:
		printerr("minigame_ui_polish_test: FAIL (%d)" % failures.size())
		quit(1)


func _layout_audit() -> void:
	for language_index: int in range(2):
		var language: String = ["en", "zh"][language_index]
		root.get_node("CaseLocale").call("set_language", language)
		for entry: Dictionary in CASES:
			var game := _make_game(entry, language_index)
			for stage: int in range(int(game.call("level_count"))):
				game.set("_level_index", stage)
				game.call("restart_level")
				game.set("_running", false)
				game.call("report_level_failed", entry["failure"][language_index])
				await _settle_layout()
				var label: String = "%s/%s/%d" % [entry["id"], language, stage + 1]
				var panel := game.get("_panel") as Control
				var content := game.get("content") as Control
				_check_bounds(panel, panel.get_global_rect(), label)
				_check_bounds(content, content.get_global_rect(), label + "/content")
				_check_text(panel, label)
				if str(entry["id"]) == "flame_air":
					_expect(content.size.y >= 314.0,
						"%s reserves 314px for jar lanes and controls (has %.0fpx)" % [label, content.size.y])
					if stage == int(game.call("level_count")) - 1:
						print("Five-jar content allowance (%s): %.0fpx" % [language, content.size.y])
				if str(entry["id"]) == "photosynthesis":
					var target := (game.get("_bed") as Node).get_node("TargetLabel") as Label
					_expect(target.text == ("目标" if language_index else "Target"),
						"Plant target label follows locale")
				if stage == int(game.call("level_count")) - 1 and not captures.is_empty():
					await _prepare_failure_capture(game, str(entry["id"]))
					await _settle_layout()
					_check_bounds(content, content.get_global_rect(), label + "/result")
					_check_text(panel, label + "/result")
					await RenderingServer.frame_post_draw
					var image: Image = root.get_texture().get_image()
					var path: String = captures.path_join("%s-%s.png" % [entry["id"], language])
					_expect(image.save_png(path) == OK, "Saved " + path)
			game.queue_free()
			await process_frame
	print("Layout audit: all 96 stage/language states measured at 1024x768")


func _prepare_failure_capture(game: Node, id: String) -> void:
	game.call("clear_feedback")
	match id:
		"flame_air":
			var order: Array = game.call("_correct_order")
			order.reverse()
			for index: int in order:
				game.call("_on_pick", index)
			game.call("_on_confirm")
			var finish_at: float = float(game.get("_finish_at"))
			await create_timer(finish_at + 1.5).timeout
		"change_sorting":
			for id_value: String in game.get("_order"):
				var expected: String = str(game.call("_expected", id_value))
				game.call("_on_pick", id_value, "physical" if expected == "chemical" else "chemical")
			game.call("_on_submit")
			await create_timer(float(game.call("presentation_duration")) + 0.2).timeout
		"photosynthesis":
			game.call("_on_cultivate")
			await create_timer(2.7).timeout
		"moonlight_harvest":
			game.set("_running", true)
			game.set("_remaining_time", 0.0)
			game.call("_process", 0.0)
		"elapsed_time":
			game.call("_on_answer", 2)
			await create_timer(2.6).timeout
		"gear_train":
			var gears: Array[int] = [36, 36, -1]
			game.set("_picked", gears)
			game.call("_refresh")
			game.call("_on_engage")
			await create_timer(3.6).timeout
	await process_frame


func _make_game(entry: Dictionary, language_index: int = 0) -> Node:
	var script := load("res://scripts/%s_minigame.gd" % entry["id"]) as GDScript
	var game: Node = script.new()
	root.add_child(game)
	game.call("configure", entry["title"][language_index], entry["subtitle"][language_index],
		entry.get("tint", Color(0.86, 0.72, 0.98)))
	game.call("start")
	return game


func _settle_layout() -> void:
	for frame: int in range(4):
		await process_frame


func _flow_audit() -> void:
	root.get_node("CaseLocale").call("set_language", "en")
	var game := _make_game(CASES[1])
	await _settle_layout()
	var focus: Control = root.gui_get_focus_owner()
	_expect(focus != null and (game.get("content") as Node).is_ancestor_of(focus),
		"Opening assigns gameplay keyboard focus")
	(game.get("_close_button") as Button).grab_focus()
	await _press("ui_focus_next")
	_expect(root.gui_get_focus_owner() == focus, "Tab wraps from Close into the game")
	await _press("ui_accept")
	var choices: Dictionary = game.get("_choice")
	_expect(choices["burning_paper"] == "" and bool(game.get("_hero").call("is_playing")), "Initial Enter replays observation without choosing an answer")
	(game.get("_cards")["burning_paper"]["chemical"] as Button).grab_focus()
	await _press("ui_accept")
	_expect(choices["burning_paper"] == "chemical", "Enter activates focused sample choice")
	game.call("report_level_failed", CASES[1]["failure"][0])
	await create_timer(2.3).timeout
	var banner := game.get("_banner") as Label
	_expect(banner.modulate.a > 0.99, "Wrong-answer explanation persists for reading")
	game.call("restart_level")
	_expect(banner.text.is_empty() and banner.modulate.a < 0.01, "Restart clears old feedback")
	game.call("report_level_cleared", "Every sample filed correctly. The tray seals.")
	game.call("report_level_cleared", "Duplicate result")
	_expect(int(game.call("levels_cleared")) == 1, "Repeated win signals cannot duplicate rewards")
	await create_timer(1.0).timeout
	_expect(bool(game.get("_advancing")), "Success explanation gets a readable hold")
	await _press("ui_cancel")
	await create_timer(4.0).timeout
	_expect(not bool(game.get("visible")), "Closing stays closed after delayed advance")
	_expect((game.get("content") as Node).get_child_count() == 0, "Closing cancels pending stage rebuild")
	_expect(int(game.call("levels_cleared")) == 1, "Closing preserves exactly one earned stage")
	game.queue_free()
	await process_frame
	await _transition_audit()
	await _manual_progression_audit()
	await _widget_audit()
	await _launcher_audit()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event)
	await process_frame


func _transition_audit() -> void:
	var game := _make_game(CASES[1])
	game.call("report_level_cleared", "Filed.")
	game.call("_on_close_pressed")
	await create_timer(3.0).timeout
	_expect((game.get("content") as Node).get_child_count() == 0,
		"Quick close before auto-advance cannot rebuild hidden controls")
	game.call("start")
	game.call("report_level_cleared", "Filed.")
	await create_timer(3.0).timeout
	_expect(int(game.call("current_level")) == 1, "Success advances exactly one stage automatically")
	_expect((game.get("_banner") as Label).text.is_empty(), "Next stage clears the success banner")
	_expect(not bool(game.get("_advancing")), "Next stage unlocks gameplay")
	var content: Node = game.get("content")
	var focus: Control = root.gui_get_focus_owner()
	_expect(focus != null and content.is_ancestor_of(focus), "Next stage restores gameplay focus")
	game.call("report_level_cleared", "Filed.")
	game.call("start")
	await create_timer(3.0).timeout
	_expect(int(game.call("current_level")) == 0 and int(game.call("levels_cleared")) == 0,
		"Starting a fresh run cancels the old run's pending advance")
	game.set("_level_index", 7)
	game.set("_cleared_count", 7)
	game.call("restart_level")
	var result: Array[bool] = []
	game.connect("finished", func(cleared: bool) -> void: result.append(cleared))
	game.call("report_level_cleared", "All filed.")
	game.call("_on_close_pressed")
	await create_timer(4.0).timeout
	_expect(result == [true] and int(game.call("levels_cleared")) == 8,
		"Closing during final celebration awards full completion exactly once")
	game.queue_free()
	await process_frame
	game = _make_game(CASES[1])
	game.set("_level_index", 7)
	game.set("_cleared_count", 7)
	game.call("restart_level")
	var auto_result: Array[bool] = []
	game.connect("finished", func(cleared: bool) -> void: auto_result.append(cleared))
	game.call("report_level_cleared", "All filed.")
	await create_timer(4.0).timeout
	_expect(auto_result == [true] and not bool(game.get("visible")),
		"Final success also completes automatically after its readable hold")
	game.queue_free()
	await process_frame


func _manual_progression_audit() -> void:
	var state := root.get_node("GameState")
	for language: int in range(2):
		root.get_node("CaseLocale").call("set_language", "zh" if language else "en")
		state.set("developer_mode", true)
		var game := _make_game(CASES[0], language)
		var next := game.get("_continue_button") as Button
		_expect(not next.visible, "Next stage is unavailable before a successful answer")
		game.call("report_level_cleared", "The prediction was correct.")
		await _settle_layout()
		_expect(next.visible and root.gui_get_focus_owner() == next,
			"An earned result offers a keyboard-focused continue button")
		var panel := game.get("_panel") as Control
		_check_bounds(panel, panel.get_global_rect(), "success/dev/footer")
		_check_text(panel, "success/dev/footer")
		await _press("ui_accept")
		_expect(int(game.call("current_level")) == 1 and int(game.call("levels_cleared")) == 1,
			"Readers can continue immediately without a compulsory result wait")
		game.call("_on_transition_timeout")
		_expect(int(game.call("current_level")) == 1,
			"Continuing manually cancels a second automatic advancement")
		game.set("_level_index", 7)
		game.set("_cleared_count", 7)
		game.call("restart_level")
		var result: Array[bool] = []
		game.connect("finished", func(cleared: bool) -> void: result.append(cleared))
		game.call("report_level_cleared", "All complete.")
		await _press("ui_accept")
		game.call("_on_transition_timeout")
		_expect(result == [true] and int(game.call("levels_cleared")) == 8,
			"Finishing immediately still awards all stages exactly once")
		game.queue_free()
		await process_frame
	state.set("developer_mode", false)
	root.get_node("CaseLocale").call("set_language", "en")


func _widget_audit() -> void:
	var game := _make_game(CASES[2])
	await _settle_layout()
	var minus: Dictionary = game.get("_minus_buttons")
	_expect((minus["light"] as Button).disabled, "Empty purchased supply cannot be refunded")
	var initial_buttons: Dictionary = game.get("_plus_buttons")
	_expect(root.gui_get_focus_owner() == initial_buttons["light"],
		"Supply starts focused on a usable purchase, not an empty refund")
	for step: int in range(6):
		game.call("_on_adjust", "light", 1)
	var buttons: Dictionary = game.get("_plus_buttons")
	_expect((buttons["light"] as Button).disabled, "Ration limit disables a full lane")
	game.call("_set_buttons_disabled", game.get("content"), true)
	game.call("_set_buttons_disabled", game.get("content"), false)
	await _settle_layout()
	_expect((buttons["light"] as Button).disabled, "Animation unlock preserves ration/cap constraints")
	var restored: Control = root.gui_get_focus_owner()
	_expect(restored != null and (game.get("content") as Node).is_ancestor_of(restored),
		"Animation unlock restores keyboard input")
	game.call("report_level_failed", CASES[2]["failure"][0])
	game.call("_on_adjust", "light", -1)
	_expect((game.get("_banner") as Label).text.is_empty(), "Changing supply clears stale feedback")
	game.queue_free()
	await process_frame
	game = _make_game(CASES[3])
	await _settle_layout()
	game.set("_running", false)
	var pods: Array = game.get("_pods")
	var pod := pods[0] as Control
	_expect(root.gui_get_focus_owner() == pod, "Moonleaf pod receives initial keyboard focus")
	pod.set("_phase", 0.5)
	game.set("_running", true)
	await _press("ui_accept")
	_expect(bool(pod.get("harvested")), "A ripe moonleaf can be harvested by keyboard")
	game.call("start")
	game.set("_remaining_time", 0.0)
	game.call("_process", 0.0)
	_expect(bool(game.get("_retry_pending")), "Moonlight timeout schedules a readable retry")
	_expect(is_zero_approx(float((game.get("_pods") as Array)[0].call("openness"))),
		"Expired moonlight visibly closes the blooms")
	game.call("start")
	await create_timer(7.0).timeout
	_expect(float(game.get("_remaining_time")) < 9.0,
		"An old moonlight retry cannot reset the new run's clock")
	game.queue_free()
	await process_frame


func _launcher_audit() -> void:
	var launcher := load("res://scripts/minigame_launcher.gd") as GDScript
	for already_paused: bool in [false, true]:
		paused = already_paused
		var host := Node.new()
		root.add_child(host)
		var script := load("res://scripts/change_sorting_minigame.gd") as GDScript
		var game: Node = script.new()
		var result: Array = []
		_expect(launcher.launch(host, game, "Tray", "Samples", Color.WHITE,
			func(cleared: bool, count: int) -> void: result.append([cleared, count])),
			"Launcher accepts idle host")
		_expect(paused, "Launcher pauses the world")
		game.call("_on_close_pressed")
		_expect(paused == already_paused, "Close restores prior pause state")
		_expect(result == [[false, 0]], "Close delivers reward callback once")
		host.queue_free()
		await process_frame
	paused = false
	var host := Node.new()
	root.add_child(host)
	var script := load("res://scripts/change_sorting_minigame.gd") as GDScript
	var game: Node = script.new()
	var orphan_results: Array = []
	launcher.launch(host, game, "Tray", "Samples", Color.WHITE,
		func(_cleared: bool, _count: int) -> void: orphan_results.append(true))
	host.queue_free()
	await process_frame
	await process_frame
	_expect(not paused, "Host teardown restores pause without finished signal")
	_expect(not launcher.is_busy(), "Host teardown releases modal ownership")
	_expect(orphan_results.is_empty(), "Host teardown does not grant rewards")
	paused = false


func _check_bounds(node: Node, bounds: Rect2, context: String) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and control.is_visible_in_tree() and control.size.x > 0.0:
			_expect(bounds.grow(1.0).encloses(control.get_global_rect()),
				"%s contains %s %s inside %s" % [context, control.name, control.get_global_rect(), bounds])
		_check_bounds(child, bounds, context)


func _check_text(node: Node, context: String) -> void:
	for child: Node in node.get_children():
		var label := child as Label
		if label != null and label.is_visible_in_tree() and not label.text.is_empty() and not label.clip_text:
			var font: Font = label.get_theme_font("font")
			var font_size: int = label.get_theme_font_size("font_size")
			var width: float = label.size.x if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
			var needed: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
			_expect(needed.x <= label.size.x + 1.0 and needed.y <= label.size.y + 1.0,
				"%s label '%s' fits: needs %s, has %s" % [context, label.text, needed, label.size])
		_check_text(child, context)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)
