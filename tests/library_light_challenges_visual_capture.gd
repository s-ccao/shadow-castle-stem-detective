extends SceneTree

const VIEWPORT_SIZE := Vector2i(1024, 768)
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-library-light-challenges"
const SPECTRUM_STAGES: Array = [
	["red", "green", "blue"],
	["red", "yellow", "green", "blue"],
	["red", "orange", "green", "blue", "violet"],
	["red", "orange", "yellow", "green", "blue", "violet"],
	["red", "orange", "yellow", "green", "cyan", "blue", "violet"],
]
const PIGMENT_STAGES: Array = [
	["green"],
	["red"],
	["red", "green"],
	["red", "green", "blue"],
	[],
]
const MIXER_STAGES: Array = [
	{"red": 0, "green": 2, "blue": 2},
	{"red": 2, "green": 0, "blue": 2},
	{"red": 2, "green": 2, "blue": 0},
	{"red": 2, "green": 2, "blue": 2},
	{"red": 2, "green": 1, "blue": 0},
]

var failures: Array[String] = []
var game_state: Node
var room: Node
var player: CharacterBody2D
var challenge_ui: LibraryLightLabUI
var knowledge_ui: LibraryKnowledgeShelfUI


func _initialize() -> void:
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	game_state = root.get_node("GameState")
	game_state.set("_loading_save", true)
	var output_directory := ProjectSettings.globalize_path(EVIDENCE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create Library light-challenge evidence directory")
		_finish()
		return
	_prepare_state()
	var packed := load("res://scenes/floor_1/library_room.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Library scene")
		_finish()
		return
	room = packed.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	player = room.get_node("Worldsort/player") as CharacterBody2D
	challenge_ui = room.get("library_challenge_ui") as LibraryLightLabUI
	knowledge_ui = room.get("library_knowledge_ui") as LibraryKnowledgeShelfUI
	if player == null or challenge_ui == null or knowledge_ui == null:
		_fail("Library player, knowledge reader or challenge interface missing")
		_finish()
		return
	player.set_physics_process(false)
	room.set_process(false)
	_hide_global_huds(true)
	_hide_room_ui()
	player.visible = false
	player.global_position = Vector2(724.0, 560.0)
	_focus_camera(Vector2(0.70, 0.70))
	await _capture(output_directory.path_join("01-knowledge-shelves-and-question-stations.png"))

	player.visible = true
	room.set("current_interaction", "topleft_tall_case")
	room.call("try_interact")
	await create_timer(0.24).timeout
	await _capture(output_directory.path_join("02-spectrum-knowledge-shelf.png"))
	knowledge_ui.call("record_current_knowledge")
	knowledge_ui.call("close")
	room.set("current_interaction", "research_desk")
	room.call("try_interact")
	await process_frame
	challenge_ui.call("choose_spectrum_token", "red")
	await process_frame
	await _capture(output_directory.path_join("03a-prism-jewel-loading.png"))
	await create_timer(0.42).timeout
	challenge_ui.call("choose_spectrum_token", "green")
	await create_timer(0.42).timeout
	await _capture(output_directory.path_join("03-spectrum-question-terminal.png"))
	challenge_ui.call("reset_current_stage")
	for stage_solution: Variant in SPECTRUM_STAGES:
		await _seat_spectrum_solution(stage_solution as Array)
		if int(challenge_ui.get("stage_index")) == 3:
			await _capture(output_directory.path_join("03b-spectrum-late-stage.png"))
		challenge_ui.call("submit_current_challenge")
	await process_frame
	await _capture(output_directory.path_join("04-crimson-filter-recovered.png"))
	challenge_ui.call("close")

	room.set("current_interaction", "lower_storage")
	room.call("try_interact")
	await create_timer(0.24).timeout
	await _capture(output_directory.path_join("05-reflection-knowledge-shelf.png"))
	knowledge_ui.call("record_current_knowledge")
	knowledge_ui.call("close")
	room.set("current_interaction", "writing_desk")
	room.call("try_interact")
	await process_frame
	challenge_ui.call("set_reflection_response", "green", "reflect")
	await process_frame
	await _capture(output_directory.path_join("06a-reflection-beam-tracing.png"))
	await create_timer(0.38).timeout
	challenge_ui.call("set_reflection_response", "red", "absorb")
	challenge_ui.call("set_reflection_response", "blue", "absorb")
	await create_timer(0.32).timeout
	await _capture(output_directory.path_join("06-reflection-question-terminal.png"))
	for stage_reflect: Variant in PIGMENT_STAGES:
		var reflected: Array = stage_reflect as Array
		for channel: String in ["red", "green", "blue"]:
			challenge_ui.call(
				"set_reflection_response", channel, "reflect" if reflected.has(channel) else "absorb"
			)
		await create_timer(0.40).timeout
		if int(challenge_ui.get("stage_index")) == 2:
			await _capture(output_directory.path_join("06b-pigment-lemon-specimen.png"))
		challenge_ui.call("submit_current_challenge")
	await process_frame
	challenge_ui.call("close")

	room.set("current_interaction", "storage_cabinet")
	room.call("try_interact")
	await create_timer(0.24).timeout
	await _capture(output_directory.path_join("07-additive-knowledge-shelf.png"))
	knowledge_ui.call("record_current_knowledge")
	knowledge_ui.call("close")
	room.set("current_interaction", "lower_globe_desk")
	room.call("try_interact")
	await process_frame
	challenge_ui.call("set_mixer_channels", ["green", "blue"])
	await process_frame
	await _capture(output_directory.path_join("08a-additive-emitter-charging.png"))
	await create_timer(0.42).timeout
	await _capture(output_directory.path_join("08-additive-question-terminal.png"))
	for stage_levels: Variant in MIXER_STAGES:
		var levels: Dictionary = stage_levels as Dictionary
		for channel: String in ["red", "green", "blue"]:
			challenge_ui.call("set_mixer_level", channel, int(levels[channel]))
		await create_timer(0.42).timeout
		if int(challenge_ui.get("stage_index")) == 4:
			await _capture(output_directory.path_join("08b-additive-amber-target.png"))
		challenge_ui.call("submit_current_challenge")
	await process_frame
	await _capture(output_directory.path_join("09-cobalt-filter-recovered.png"))
	challenge_ui.call("close")

	_hide_global_huds(true)
	_dismiss_transient_rewards()
	_hide_room_ui()
	player.visible = false
	player.global_position = Vector2(724.0, 690.0)
	_focus_camera(Vector2(1.55, 1.55))
	await process_frame
	await _capture(output_directory.path_join("10-three-earned-filters-empty-slots.png"))
	room.call("_use_rgb_filter", "rgb_red_filter")
	await process_frame
	await _capture(output_directory.path_join("10a-world-crimson-filter-loading.png"))
	await create_timer(0.90).timeout
	room.call("_use_rgb_filter", "rgb_green_filter")
	await create_timer(0.90).timeout
	room.call("_use_rgb_filter", "rgb_blue_filter")
	await create_timer(0.08).timeout
	_dismiss_transient_rewards()
	await process_frame
	_dismiss_transient_rewards()
	_hide_global_huds(true)
	_hide_room_ui()
	await _capture(output_directory.path_join("10b-rgb-beams-converging.png"))
	await create_timer(1.0).timeout
	_dismiss_transient_rewards()
	_hide_global_huds(true)
	_hide_room_ui()
	await process_frame
	var neutral_core := room.get("rgb_neutral_core") as Polygon2D
	_expect(
		neutral_core != null and neutral_core.visible and neutral_core.modulate.a > 0.9,
		"All three traced beams ignite the pale archive light"
	)
	await _capture(output_directory.path_join("11-three-filters-inserted-white-light.png"))
	_finish()


func _prepare_state() -> void:
	game_state.call("reset_new_game")
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.current_room_id = "library"
	game_state.hall_arrival_seen = true


func _seat_spectrum_solution(solution: Array) -> void:
	for token_variant: Variant in solution:
		challenge_ui.call("choose_spectrum_token", str(token_variant))
		await create_timer(0.42).timeout


func _hide_global_huds(hidden: bool) -> void:
	root.get_node("ArchiveUi").call("set_hub_entries_suppressed", hidden)
	var minimap := root.get_node("MapHud").find_child("GuardianMiniMap", true, false) as Control
	if minimap != null:
		minimap.visible = false


func _hide_room_ui() -> void:
	var runtime := room.get("interaction_runtime") as Node
	if runtime != null:
		runtime.call("refresh", false)
	var focus := room.find_child("WorldInteractionFocus", true, false) as CanvasItem
	if focus != null:
		focus.visible = false


func _dismiss_transient_rewards() -> void:
	var reward_hud := root.get_node_or_null("ItemRewardHud")
	if reward_hud != null and reward_hud.has_method("dismiss_for_overlay"):
		reward_hud.call("dismiss_for_overlay")
		(reward_hud as CanvasLayer).visible = false
	var note_hud := root.get_node_or_null("NoteHud")
	if note_hud != null and note_hud.has_method("hide_feature_unlock"):
		note_hud.call("hide_feature_unlock")


func _focus_camera(zoom: Vector2) -> void:
	for node: Node in player.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		camera.position_smoothing_enabled = false
		camera.zoom = zoom
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		return


func _capture(absolute_path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("Invalid 1024x768 capture: " + absolute_path)
		return
	if image.save_png(absolute_path) != OK:
		_fail("Could not save capture: " + absolute_path)
		return
	print("CAPTURED: " + absolute_path)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	_hide_global_huds(false)
	var reward_hud := root.get_node_or_null("ItemRewardHud") as CanvasLayer
	if reward_hud != null:
		reward_hud.visible = true
	if room != null and is_instance_valid(room):
		if current_scene == room:
			current_scene = null
		room.queue_free()
	game_state.game_started = false
	game_state.set("_loading_save", false)
	paused = false
	if failures.is_empty():
		print("library_light_challenges_visual_capture: PASS")
		quit(0)
		return
	printerr("library_light_challenges_visual_capture: FAIL (%d issue(s))" % failures.size())
	quit(1)
