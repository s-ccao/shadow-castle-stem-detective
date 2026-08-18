extends SceneTree

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.current_room_id = "library"
	var packed := load("res://scenes/floor_1/library_room.tscn") as PackedScene
	_expect(packed != null, "Library scene loads")
	if packed == null:
		_finish()
		return
	var room := packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.30).timeout

	var challenge_ui := room.get("library_challenge_ui") as CanvasLayer
	_expect(challenge_ui != null, "Library owns a dedicated light-challenge interface")
	var knowledge_ui := room.get("library_knowledge_ui") as CanvasLayer
	_expect(knowledge_ui != null, "Library owns a separate bookshelf knowledge interface")
	if challenge_ui == null or knowledge_ui == null:
		await _release(room)
		_finish()
		return
	var animated_backdrop := challenge_ui.find_child("AnimatedOpticsBackdrop", true, false) as ColorRect
	_expect(
		animated_backdrop != null and animated_backdrop.material is ShaderMaterial,
		"Light games use a shader-animated optical backdrop"
	)
	_expect(
		(challenge_ui.get("ambient_motes") as Array).size() >= 20,
		"Light games carry a restrained ambient particle field"
	)
	_expect(
		challenge_ui.find_child("StageClearBanner", true, false) != null,
		"Light games own a stage-clear presentation layer"
	)
	_expect(
		challenge_ui.find_child("FilterRecoveryVFX", true, false) != null,
		"Light games own a dedicated filter recovery effect"
	)
	_expect(
		challenge_ui.find_child("AshfordOpticalObserver", true, false) != null
		and challenge_ui.find_child("ObserverOuterScannerRing", true, false) != null
		and challenge_ui.find_child("ObserverSensorCore", true, false) != null,
		"Pigment game uses a layered sci-fi optical observer"
	)
	for channel: String in ["red", "green", "blue"]:
		_expect(
			challenge_ui.find_child("OpticalEmitter_" + channel, true, false) != null
			and challenge_ui.find_child("EmitterFeed_" + channel, true, false) != null,
			"Additive %s light has a physical emitter and feed path" % channel
		)

	var constants := (room.get_script() as GDScript).get_script_constant_map()
	var stations := constants.get("CHALLENGE_STATIONS", {}) as Dictionary
	var knowledge_shelves := constants.get("KNOWLEDGE_SHELVES", {}) as Dictionary
	_expect(stations.size() == 3, "RGB filters are earned at three separate challenge stations")
	_expect(knowledge_shelves.size() == 3, "Three separate bookshelves hold the required knowledge")
	var station_centers: Array[Vector2] = []
	for station_id: String in ["research_desk", "writing_desk", "lower_globe_desk"]:
		var station_rect := room.call("get_library_interaction_rect", station_id) as Rect2
		station_centers.append(station_rect.get_center())
		_expect(station_rect.size.x > 0.0 and station_rect.size.y > 0.0, station_id + " has a real challenge footprint")
	for first: int in range(station_centers.size()):
		for second: int in range(first + 1, station_centers.size()):
			_expect(station_centers[first].distance_to(station_centers[second]) >= 140.0, "Challenge stations are spatially separated")
	var research_rect := room.call("get_library_interaction_rect", "research_desk") as Rect2
	for slot_id: String in ["rgb_red_filter", "rgb_green_filter", "rgb_blue_filter"]:
		var slot_rect := room.call("get_library_interaction_rect", slot_id) as Rect2
		_expect(not research_rect.intersects(slot_rect), "Spectrum challenge does not steal input from %s" % slot_id)
	for shelf_item: String in knowledge_shelves:
		var shelf_info := knowledge_shelves[shelf_item] as Dictionary
		var station_item := str(shelf_info["station"])
		var shelf_rect := room.call("get_library_interaction_rect", shelf_item) as Rect2
		var station_rect := room.call("get_library_interaction_rect", station_item) as Rect2
		_expect(shelf_rect.size.x > 0.0 and shelf_rect.size.y > 0.0, shelf_item + " has a real knowledge footprint")
		_expect(not shelf_rect.intersects(station_rect), shelf_item + " knowledge is not placed on its question table")
		_expect(shelf_rect.get_center().distance_to(station_rect.get_center()) >= 160.0, shelf_item + " is spatially separated from its question")

	for filter_id: String in ["red", "green", "blue"]:
		_expect(not game_state.has_story_flag("library_%s_filter_earned" % filter_id), "%s filter starts unearned" % filter_id)
		_expect(not game_state.has_story_flag("library_%s_filter_active" % filter_id), "%s slot starts empty" % filter_id)

	room.call("_use_rgb_filter", "rgb_red_filter")
	_expect(not game_state.has_story_flag("library_red_filter_active"), "Empty red slot cannot activate before its challenge")

	room.set("current_interaction", "research_desk")
	room.call("try_interact")
	_expect(not challenge_ui.visible, "Spectrum question stays locked before reading its bookshelf")
	room.set("current_interaction", "topleft_tall_case")
	room.call("try_interact")
	_expect(knowledge_ui.visible and str(knowledge_ui.get("knowledge_id")) == "spectrum", "Tall wavelength case opens spectrum knowledge")
	_expect(not game_state.has_story_flag("library_spectrum_knowledge_learned"), "Opening knowledge does not silently mark it learned")
	knowledge_ui.call("record_current_knowledge")
	_expect(game_state.has_story_flag("library_spectrum_knowledge_learned"), "Explicitly recording spectrum knowledge persists it")
	knowledge_ui.call("close")
	room.set("current_interaction", "research_desk")
	room.call("try_interact")
	_expect(challenge_ui.visible and str(challenge_ui.get("challenge_id")) == "red", "Research desk opens Spectrum Sequencer")
	_expect(bool(challenge_ui.get("knowledge_reference_only")), "Question UI references filed knowledge without teaching the answer")
	_expect(int(challenge_ui.call("get_stage_count")) >= 5, "Prism game runs at least five escalating stages")
	challenge_ui.call("request_hint")
	_expect(int(challenge_ui.get("hints_used")) == 1, "A hint is available inside the game")
	_expect(int(challenge_ui.get("stage_index")) == 0, "Taking a hint does not solve the stage")
	challenge_ui.call("choose_spectrum_token", "blue")
	var travelling_prism_jewel := challenge_ui.find_child("TravellingOpticalJewel", true, false) as Node2D
	var first_socket := challenge_ui.find_child("PrismSocket0", true, false) as Panel
	_expect(travelling_prism_jewel != null, "Choosing a crystal launches a physical loading jewel")
	_expect(first_socket != null and first_socket.modulate.a < 0.1, "Prism socket waits for the jewel to arrive")
	await create_timer(0.48).timeout
	var first_socket_beam := challenge_ui.find_child("SocketEmissionBeam0", true, false) as Line2D
	_expect(first_socket.modulate.a > 0.9, "Prism socket appears after loading impact")
	_expect(first_socket_beam != null and first_socket_beam.visible, "Loaded crystal emits a traced spectrum beam")
	for token: String in ["green", "red"]:
		challenge_ui.call("choose_spectrum_token", token)
	challenge_ui.call("submit_current_challenge")
	_expect(int(challenge_ui.get("stage_index")) == 0, "Wrong wavelength order does not advance the prism stage")
	_expect(not game_state.has_story_flag("library_red_filter_earned"), "Wrong wavelength order does not award red filter")
	var feedback_flash := challenge_ui.find_child("FeedbackFlash", true, false) as ColorRect
	_expect(
		feedback_flash != null and feedback_flash.modulate.a > 0.0,
		"Wrong answers trigger brief visual feedback"
	)
	var spectrum_stages: Array = [
		["red", "green", "blue"],
		["red", "yellow", "green", "blue"],
		["red", "orange", "green", "blue", "violet"],
		["red", "orange", "yellow", "green", "blue", "violet"],
		["red", "orange", "yellow", "green", "cyan", "blue", "violet"],
	]
	for stage_number: int in range(spectrum_stages.size()):
		_expect(int(challenge_ui.get("stage_index")) == stage_number, "Prism stage %d is active" % (stage_number + 1))
		challenge_ui.call("reset_current_stage")
		for token_variant: Variant in spectrum_stages[stage_number] as Array:
			challenge_ui.call("choose_spectrum_token", str(token_variant))
		challenge_ui.call("submit_current_challenge")
		if stage_number == 0:
			_expect(not game_state.has_story_flag("library_red_filter_earned"), "Clearing one prism stage does not award the filter")
			var clear_banner := challenge_ui.find_child("StageClearBanner", true, false) as Panel
			_expect(clear_banner != null and clear_banner.visible, "Clearing a stage triggers its presentation banner")
	_expect(game_state.has_story_flag("library_red_filter_earned"), "Clearing every prism stage awards red filter")
	var filter_reveal := challenge_ui.find_child("FilterRecoveryVFX", true, false) as Control
	_expect(filter_reveal != null and filter_reveal.visible, "A full clear reveals the recovered filter")
	challenge_ui.call("close")

	room.set("current_interaction", "writing_desk")
	room.call("try_interact")
	_expect(not challenge_ui.visible, "Reflection question stays locked before reading its bookshelf")
	room.set("current_interaction", "lower_storage")
	room.call("try_interact")
	_expect(knowledge_ui.visible and str(knowledge_ui.get("knowledge_id")) == "reflection", "Violet reflection cabinet opens reflection knowledge")
	knowledge_ui.call("record_current_knowledge")
	knowledge_ui.call("close")
	_expect(game_state.has_story_flag("library_reflection_knowledge_learned"), "Reflection knowledge persists separately from its challenge")
	room.set("current_interaction", "writing_desk")
	room.call("try_interact")
	_expect(str(challenge_ui.get("challenge_id")) == "green", "Writing desk opens Reflection Matrix")
	_expect(int(challenge_ui.call("get_stage_count")) >= 5, "Pigment game runs at least five specimens")
	challenge_ui.call("set_reflection_response", "red", "reflect")
	var red_reflection_beam := challenge_ui.find_child("OutBeam_red", true, false) as Line2D
	_expect(
		red_reflection_beam != null
		and red_reflection_beam.visible
		and red_reflection_beam.points[0].distance_to(red_reflection_beam.points[1]) < 1.0,
		"Reflected light begins at the specimen instead of appearing fully formed"
	)
	_expect(
		challenge_ui.find_child("OpticalEnergyPacket", true, false) != null,
		"Reflected light carries a travelling energy packet to the observer"
	)
	await create_timer(0.38).timeout
	_expect(
		red_reflection_beam.points[0].distance_to(red_reflection_beam.points[1]) > 150.0,
		"Reflection beam grows all the way to the optical observer"
	)
	challenge_ui.call("set_reflection_response", "green", "reflect")
	challenge_ui.call("set_reflection_response", "blue", "absorb")
	challenge_ui.call("submit_current_challenge")
	_expect(int(challenge_ui.get("stage_index")) == 0, "Incorrect absorption model does not advance the specimen")
	_expect(not game_state.has_story_flag("library_green_filter_earned"), "Incorrect absorption model does not award green filter")
	var pigment_stages: Array = [
		["green"],
		["red"],
		["red", "green"],
		["red", "green", "blue"],
		[],
	]
	for stage_number: int in range(pigment_stages.size()):
		_expect(int(challenge_ui.get("stage_index")) == stage_number, "Pigment specimen %d is active" % (stage_number + 1))
		var reflected: Array = pigment_stages[stage_number] as Array
		for channel: String in ["red", "green", "blue"]:
			challenge_ui.call("set_reflection_response", channel, "reflect" if reflected.has(channel) else "absorb")
		challenge_ui.call("submit_current_challenge")
		if stage_number == 0:
			_expect(not game_state.has_story_flag("library_green_filter_earned"), "Clearing one specimen does not award the filter")
	_expect(game_state.has_story_flag("library_green_filter_earned"), "Explaining every specimen awards green filter")
	challenge_ui.call("close")

	room.set("current_interaction", "lower_globe_desk")
	room.call("try_interact")
	_expect(not challenge_ui.visible, "Additive question stays locked before reading its bookshelf")
	room.set("current_interaction", "storage_cabinet")
	room.call("try_interact")
	_expect(knowledge_ui.visible and str(knowledge_ui.get("knowledge_id")) == "additive", "Reinforced shelf opens additive knowledge")
	knowledge_ui.call("record_current_knowledge")
	knowledge_ui.call("close")
	_expect(game_state.has_story_flag("library_additive_knowledge_learned"), "Additive knowledge persists separately from its challenge")
	room.set("current_interaction", "lower_globe_desk")
	room.call("try_interact")
	_expect(str(challenge_ui.get("challenge_id")) == "blue", "West globe desk opens Additive Relay")
	_expect(int(challenge_ui.call("get_stage_count")) >= 5, "Additive game runs at least five colour targets")
	challenge_ui.call("set_mixer_channels", ["red"])
	var red_feed := challenge_ui.find_child("EmitterFeed_red", true, false) as Line2D
	var red_disc := challenge_ui.find_child("MixDisc_red", true, false) as Polygon2D
	_expect(red_feed != null and red_feed.visible, "Additive emitter traces a feed beam before ignition")
	_expect(red_disc != null and bool(red_disc.get_meta("charging", false)), "Additive disc remains in a charging state during transfer")
	await create_timer(0.40).timeout
	_expect(not bool(red_disc.get_meta("charging", false)) and red_disc.modulate.a > 0.7, "Additive disc ignites only after its feed arrives")
	challenge_ui.call("submit_current_challenge")
	_expect(int(challenge_ui.get("stage_index")) == 0, "Wrong additive mix does not advance")
	var mixer_stages: Array = [
		{"red": 0, "green": 2, "blue": 2},
		{"red": 2, "green": 0, "blue": 2},
		{"red": 2, "green": 2, "blue": 0},
		{"red": 2, "green": 2, "blue": 2},
		{"red": 2, "green": 1, "blue": 0},
	]
	for stage_number: int in range(mixer_stages.size()):
		_expect(int(challenge_ui.get("stage_index")) == stage_number, "Additive target %d is active" % (stage_number + 1))
		var levels: Dictionary = mixer_stages[stage_number] as Dictionary
		for channel: String in ["red", "green", "blue"]:
			challenge_ui.call("set_mixer_level", channel, int(levels[channel]))
		challenge_ui.call("submit_current_challenge")
		if stage_number == 0:
			_expect(not game_state.has_story_flag("library_blue_filter_earned"), "Clearing one additive target does not award the filter")
	_expect(game_state.has_story_flag("library_blue_filter_earned"), "Rendering every additive target awards blue filter")
	challenge_ui.call("close")

	for filter_id: String in ["red", "green", "blue"]:
		room.call("_use_rgb_filter", "rgb_%s_filter" % filter_id)
		_expect(game_state.has_story_flag("library_%s_filter_active" % filter_id), "%s filter can be inserted after earning it" % filter_id)
		var filter_root := (room.get("rgb_filter_nodes") as Dictionary).get("rgb_%s_filter" % filter_id) as Node2D
		var glass := filter_root.get_node_or_null("JewelGlass") as Polygon2D
		_expect(glass != null and glass.visible, "%s jewel appears in its slot after insertion" % filter_id)
		_expect(
			(room.get("rgb_filter_stand") as Node2D).find_child("TravellingOpticalJewel", true, false) != null,
			"%s world filter physically travels into its slot" % filter_id
		)
		_expect(glass.modulate.a < 0.1, "%s seated glass waits for loading impact" % filter_id)
		if filter_id == "blue":
			var pending_core := room.get("rgb_neutral_core") as Polygon2D
			_expect(
				pending_core.visible and pending_core.modulate.a < 0.1,
				"Archive core waits for the final beam before ignition"
			)
		await create_timer(0.90).timeout
		var world_beam := (room.get("rgb_filter_beams") as Dictionary).get("rgb_%s_filter" % filter_id) as Line2D
		_expect(glass.modulate.a > 0.9, "%s glass appears after impact" % filter_id)
		_expect(world_beam != null and world_beam.visible, "%s glass emits a sustained beam into the scanner" % filter_id)
	_expect(game_state.has_story_flag("library_rgb_puzzle_solved"), "All three inserted filters complete the Library light lock")
	_expect(game_state.has_evidence("library_rgb_archive_layer"), "Completed light lock records archive-layer evidence")
	var neutral_core := room.get("rgb_neutral_core") as Polygon2D
	_expect(
		neutral_core != null and neutral_core.visible and neutral_core.modulate.a > 0.9,
		"RGB beams ignite pale neutral archive light after reaching the scanner"
	)

	await _release(room)
	_finish()


func _release(room: Node) -> void:
	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame
	paused = false


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	game_state.game_started = false
	game_state.set("_loading_save", false)
	if failures.is_empty():
		print("library_light_challenges_test: PASS")
		quit(0)
		return
	printerr("library_light_challenges_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
