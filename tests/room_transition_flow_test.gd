extends SceneTree

const RETURN_SCRIPTS: Array[String] = [
	"res://scripts/circuit_room.gd",
	"res://scripts/greenhouse_room.gd",
	"res://scripts/library_room.gd",
	"res://scenes/floor_1/chemistry_room.gd",
	"res://scripts/dining_hall_room.gd",
	"res://scripts/final_room.gd",
	"res://scripts/wake_room.gd",
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_check_transition_copy()
	_check_room_sources()
	await _check_runtime_overlay()
	_finish()


func _check_transition_copy() -> void:
	var locale := root.get_node("CaseLocale")
	var original_language := str(locale.call("language"))
	locale.call("set_language", "en")
	_expect(
		str(locale.call("text", "transition.hall_alert_detail")).contains(
			"GUARDIAN ALERT"
		),
		"Dining Hall exit warns about the Guardian before the chase"
	)
	locale.call("set_language", "zh")
	_expect(
		str(locale.call("text", "transition.hall_alert_detail")).contains("守卫"),
		"Guardian transition warning has Chinese copy"
	)
	locale.call("set_language", original_language)


func _check_room_sources() -> void:
	for path: String in RETURN_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.contains("ArchiveUi.play_hall_transition"),
			"%s returns through the shared Hall transition" % path
		)
		if path.ends_with("wake_room.gd"):
			continue
		_expect(
			source.contains("room_input_enabled = false")
			and source.contains("player.set_physics_process(false)"),
			"%s locks room and player input during transition" % path
		)
		_expect(
			source.contains("room_input_enabled = true")
			and source.contains("player.set_physics_process(true)"),
			"%s restores input when a scene change fails" % path
		)

	var world_source := FileAccess.get_file_as_string("res://scripts/game_world.gd")
	_expect(
		world_source.contains(
			"ArchiveUi.play_room_entry_transition(switch_to_room, room_id)"
		),
		"Every Hall room entry uses the shared destination transition"
	)
	var menu_source := FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	_expect(
		menu_source.contains(
			"ArchiveUi.play_room_entry_transition(reopen_case, resume_room_id)"
		),
		"Continue Case identifies the destination instead of cutting to it"
	)
	for entry_method: String in [
		"enter_greenhouse_room",
		"enter_circuit_room",
		"enter_dining_hall_room",
		"enter_library_room",
		"enter_final_room",
		"enter_chemistry_room",
		"enter_wake_room",
	]:
		var method_start := world_source.find("func " + entry_method)
		var next_method := world_source.find("\nfunc ", method_start + 1)
		var method_source := world_source.substr(
			method_start,
			next_method - method_start if next_method >= 0 else -1
		)
		_expect(
			method_source.contains("_enter_new_room("),
			"%s delegates to the shared room-entry path" % entry_method
		)

	var dining_source := FileAccess.get_file_as_string(
		"res://scripts/dining_hall_room.gd"
	)
	var midpoint_start := dining_source.find("var switch_to_hall := func()")
	var chase_start := dining_source.find(
		"GameState.start_chase_mode()",
		midpoint_start
	)
	var transition_start := dining_source.find(
		"ArchiveUi.play_hall_transition",
		chase_start
	)
	_expect(
		midpoint_start >= 0
		and chase_start > midpoint_start
		and transition_start > chase_start,
		"Dining Hall starts pursuit at the warned transition midpoint"
	)


func _check_runtime_overlay() -> void:
	var archive_ui := root.get_node("ArchiveUi")
	var midpoint_state := {"called": false}
	var midpoint_callback := func() -> void:
		midpoint_state["called"] = true
	archive_ui.call(
		"play_room_entry_transition",
		midpoint_callback,
		"library"
	)
	await process_frame
	var layer := root.get_node_or_null("RoomTransition") as CanvasLayer
	_expect(layer != null, "Room transition persists under SceneTree root")
	_expect(paused, "Room transition pauses world and keyboard input")
	if layer != null:
		var veil := layer.get_node_or_null("Fade/Veil") as ColorRect
		_expect(
			veil != null and veil.mouse_filter == Control.MOUSE_FILTER_STOP,
			"Room transition blocks pointer input while the scene changes"
		)
	await create_timer(0.55).timeout
	_expect(
		bool(midpoint_state["called"]),
		"Room transition invokes the scene change at full cover"
	)
	await create_timer(0.25).timeout
	_expect(
		root.get_node_or_null("RoomTransition") == null,
		"Room transition removes itself after fading into the destination"
	)
	_expect(not paused, "Room transition restores the previous pause state")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("room_transition_flow_test: PASS")
		quit(0)
		return
	printerr(
		"room_transition_flow_test: FAIL (%d assertion(s))"
		% failures.size()
	)
	quit(1)
