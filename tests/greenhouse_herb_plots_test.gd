extends SceneTree

## The greenhouse is meant to be a renewable supply with a spread of reagents,
## not a one-time pickup of two herbs. Each large planting is segmented into
## plots that regrow on a wall clock.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true

	_test_plot_table_is_varied(game_state)
	_test_regrowth_clock(game_state)
	await _test_room_offers_segmented_plots(game_state)

	game_state.reset_new_game()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	_finish()


func _test_plot_table_is_varied(game_state: Node) -> void:
	var script := load("res://scripts/greenhouse_room.gd") as GDScript
	var plots: Array = script.get_script_constant_map()["HERB_PLOTS"]
	_expect(plots.size() >= 8, "Greenhouse is segmented into many plots (%d)" % plots.size())

	var herbs := {}
	var ids := {}
	var total_yield := 0
	for plot: Dictionary in plots:
		herbs[str(plot["herb"])] = true
		var plot_id := str(plot["id"])
		_expect(not ids.has(plot_id), "Plot id %s is unique" % plot_id)
		ids[plot_id] = true
		total_yield += int(plot["amount"])
		_expect(
			game_state.HERB_INFO.has(str(plot["herb"])),
			"Plot %s yields a known herb (%s)" % [plot_id, plot["herb"]]
		)
		# A herb with no visual entry renders as an empty satchel slot.
		_expect(
			game_state.ITEM_VISUAL_INFO.has(str(plot["herb"])),
			"Herb %s has a satchel icon" % plot["herb"]
		)
	_expect(
		herbs.size() >= 4,
		"A sweep of the greenhouse returns several different herbs (%d kinds)" % herbs.size()
	)
	# Small enough that the bench minigames still matter, big enough to be worth
	# the walk: roughly a dozen units per full sweep.
	_expect(
		total_yield >= 8 and total_yield <= 20,
		"A full sweep is a sensible haul (%d units)" % total_yield
	)


func _test_regrowth_clock(game_state: Node) -> void:
	var plot_id := "planter_north"
	_expect(
		bool(game_state.call("is_herb_plot_ready", plot_id)),
		"An untouched plot starts ready"
	)
	var before := int(game_state.call("get_herb_count", "blue_blossom"))
	_expect(
		bool(game_state.call("harvest_herb_plot", plot_id, "blue_blossom", 2)),
		"Harvesting a ready plot succeeds"
	)
	_expect(
		int(game_state.call("get_herb_count", "blue_blossom")) == before + 2,
		"Harvest adds its yield to the satchel"
	)
	_expect(
		not bool(game_state.call("is_herb_plot_ready", plot_id)),
		"A just-picked plot is not ready again"
	)
	_expect(
		not bool(game_state.call("harvest_herb_plot", plot_id, "blue_blossom", 2)),
		"A spent plot cannot be farmed by mashing the key"
	)
	var remaining := float(game_state.call("herb_plot_seconds_remaining", plot_id))
	_expect(
		remaining > 0.0 and remaining <= game_state.HERB_PLOT_REGROW_SECONDS,
		"A spent plot reports a sane countdown (%.0fs)" % remaining
	)

	# Regrowth is absolute time, so it keeps running while the player is
	# elsewhere and across a save/load.
	var harvested_at: Dictionary = game_state.get("herb_plot_harvested_at")
	harvested_at[plot_id] = (
		Time.get_unix_time_from_system()
		- game_state.HERB_PLOT_REGROW_SECONDS
		- 1.0
	)
	_expect(
		bool(game_state.call("is_herb_plot_ready", plot_id)),
		"A plot left alone long enough regrows"
	)

	# A clock that jumped backwards must not strand a plot forever.
	harvested_at[plot_id] = Time.get_unix_time_from_system() + 86400.0
	_expect(
		bool(game_state.call("is_herb_plot_ready", plot_id)),
		"A backwards system clock does not freeze a plot"
	)


func _test_room_offers_segmented_plots(game_state: Node) -> void:
	game_state.set("return_spawn_id", "greenhouse_start")
	game_state.set("current_room_id", "greenhouse_room")
	var packed := load("res://scenes/floor_1/greenhouse_room.tscn") as PackedScene
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame

	var player := room.get_node_or_null("Worldsort/player") as CharacterBody2D
	_expect(player != null, "Greenhouse has a player")
	var markers := room.get_node_or_null("HerbPlotMarkers")
	_expect(markers != null, "Greenhouse renders plot markers")
	if markers != null:
		_expect(
			markers.get_child_count() >= 8,
			"Every plot has a marker (%d)" % markers.get_child_count()
		)

	if player != null:
		var script := load("res://scripts/greenhouse_room.gd") as GDScript
		var plots: Array = script.get_script_constant_map()["HERB_PLOTS"]
		var target: Dictionary = plots[0]
		player.global_position = target["position"] as Vector2
		var found: Dictionary = room.call("_nearest_ready_or_reachable_plot")
		_expect(
			not found.is_empty() and str(found["id"]) == str(target["id"]),
			"Standing at a segment offers that segment"
		)

		# Refining is what makes regrowth matter. If the player never receives
		# those recipes, the new herbs and the whole regrow clock are dead
		# content, because the bench refuses to craft an unknown recipe.
		var refining: Array = script.get_script_constant_map()["REFINING_RECIPES"]
		for recipe_id: Variant in refining:
			_expect(
				not bool(game_state.call("has_recipe", str(recipe_id))),
				"%s is not known before the first harvest" % recipe_id
			)
		room.call("_harvest_herb_plot", target)
		await process_frame
		for recipe_id: Variant in refining:
			_expect(
				bool(game_state.call("has_recipe", str(recipe_id))),
				"First harvest teaches %s" % recipe_id
			)

	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("greenhouse_herb_plots_test: PASS")
		quit(0)
	else:
		printerr(
			"greenhouse_herb_plots_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
