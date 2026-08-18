extends Node2D

## Circuit Room — 机械工坊（用户提供 b552a085 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。
## 物品坐标可先用 [MOUSE] 输出校准后填入 INTERACT_ITEMS。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/circuit_room_workshop.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "circuit_room"
const RETURN_SPAWN_ID: String = "circuit_door"
const POWER_SURGE_AUDIO_PATH: String = "res://assets/audio/sfx/power_restore_surge.wav"
const POWER_IMPACT_DELAY: float = 0.28

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const EXIT_RECT: Rect2 = Rect2(640.0, 972.0, 168.0, 114.0)
const MECHANIC_POSITION: Vector2 = Vector2(930.0, 850.0)
const MECHANIC_INTERACT_RADIUS: float = 88.0
const MECHANIC_VISUAL_SCALE: float = 0.426
const MECHANIC_VISUAL_FOOT_ANCHOR: Vector2 = Vector2(0.0, -41.322)
const INTERACTION_CONTACT_MARGIN: float = 14.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"workbench": NodePath("Worldsort/Workbench"),
	"generator": NodePath("Worldsort/Generator"),
	"cabinet": NodePath("Worldsort/Cabinet")
}

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

# The workshop art paints five wall lamps, a bench lantern, a lit generator
# chamber and a cracked bus panel. These are those fixtures in room space, so
# the cast light and the electrical fault stay attached to the painted sources.
const AMBIENCE_Z: int = -90
const WALL_LAMP_POSITIONS: Array[Vector2] = [
	Vector2(147.0, 127.0),
	Vector2(20.0, 335.0),
	Vector2(68.0, 897.0),
	Vector2(1428.0, 339.0),
	Vector2(1376.0, 897.0),
]
const BENCH_LANTERN_POSITION: Vector2 = Vector2(742.0, 467.0)
const GENERATOR_CHAMBER_POSITION: Vector2 = Vector2(1270.0, 561.0)
const BROKEN_BUS_POSITION: Vector2 = Vector2(950.0, 148.0)
const LAMP_WARM: Color = Color(1.0, 0.72, 0.34, 0.50)
const LAMP_BENCH: Color = Color(1.0, 0.78, 0.40, 0.44)
const LAMP_ARCANE: Color = Color(0.52, 0.88, 1.0, 0.46)
# Flush junction plates stay off the board until the player earns their position.
const SWITCH_SURVEY_FLAG: String = "circuit_switches_surveyed"
const SWITCH_SURVEY_STAGGER: float = 0.18
# Each plate is released by clearing its own bench. Plates without a bench yet
# stay operable, so the room is never blocked by unbuilt content.
const BENCH_FOR_SWITCH: Dictionary = {
	"switch_left": "circuit_bench_continuity_cleared",
	"switch_right": "circuit_bench_regulator_cleared",
	"master_switch": "circuit_bench_diagnostic_cleared",
}
const CIRCUIT_LAB_SCRIPT: Script = preload("res://scripts/circuit_lab_ui.gd")
const CIRCUIT_SWITCH_VIEW_SCRIPT: Script = preload("res://scripts/circuit_switch_view.gd")

var INTERACT_ITEMS: Array[Dictionary] = [
	# The switches are listed first on purpose. Their contact bands sit in front
	# of the props they are mounted on, and the runtime offers the first touching
	# entry, so the device the player is standing at wins over its furniture.
	{
		"name": "switch_left",
		"label": "the left power switch",
		"position": CircuitLayout.get_position("switch_left"),
		"interaction_rect": CircuitLayout.get_rect("switch_left"),
		"contact_rect": CircuitLayout.get_contact_rect("switch_left"),
		"message": "A left-side power switch. Its purpose is unclear."
	},
	{
		"name": "switch_right",
		"label": "the right power switch",
		"position": CircuitLayout.get_position("switch_right"),
		"interaction_rect": CircuitLayout.get_rect("switch_right"),
		"contact_rect": CircuitLayout.get_contact_rect("switch_right"),
		"message": "A right-side power switch. Its purpose is unclear."
	},
	{
		"name": "master_switch",
		"label": "the master switch",
		"position": CircuitLayout.get_position("master_switch"),
		"interaction_rect": CircuitLayout.get_rect("master_switch"),
		"contact_rect": CircuitLayout.get_contact_rect("master_switch"),
		"message": "A large master power switch. Its purpose is unclear."
	},
	{
		"name": "workbench",
		"label": "the workbench",
		"position": Vector2(635.0, 700.0),
		"message": (
			"A cluttered workbench. Tools, coils and an open journal cover "
			+ "the surface. The last entry is cut off mid-sentence."
		)
	},
	{
		"name": "generator",
		"label": "the arcane generator",
		"position": Vector2(1120.0, 700.0),
		"message": (
			"A massive arcane generator. Blue arcs crackle behind its glass "
			+ "chamber. The mechanism still hums."
		)
	},
	{
		"name": "cabinet",
		"label": "the equipment cabinet",
		"position": Vector2(250.0, 660.0),
		"message": (
			"A reinforced equipment cabinet. Its padlock is firmly shut, "
			+ "but the keyhole glints as if recently used."
		)
	}
]

@export var debug_print_click_position := false

var player: Node2D
var scene_transitioning := false
var room_input_enabled := true
var current_interaction := ""
var _investigated_items: Array[String] = []
var _switch_states: Dictionary = {
	"switch_left": false,
	"switch_right": false,
	"master_switch": false,
}
var _switch_sequence_index: int = 0
var mechanic_npc: AnimatedNpc
var interaction_runtime: RoomInteractionRuntime
var spatial := RoomSpatialRuntime.new()
var switch_visuals: Dictionary = {}
var _last_debug_mouse_position := Vector2(-100000, -100000)
var power_surge_audio: AudioStreamPlayer
var power_restoration_effect_started := false
var ambience_layer: Node2D
var _wall_lamps: Array[Sprite2D] = []
var _generator_glow: Sprite2D
var _bus_arc: Node2D
var _generator_arc: Node2D
var circuit_lab: CircuitLabUI


func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = ROOM_ID
	GameState.set_room_visited(ROOM_ID)
	player = $Worldsort/player
	player.position = PLAYER_SPAWN_POSITION
	player.set_physics_process(true)
	_create_switch_models()
	_create_room_ambience()
	_create_power_restoration_audio()
	interaction_runtime = RoomInteractionRuntime.new()
	add_child(interaction_runtime)
	interaction_runtime.configure(self, player, {
		"items": INTERACT_ITEMS,
		"prop_node_paths": PROP_NODE_PATHS,
		"room_display_name": "Circuit Room",
		"exit_position": EXIT_POSITION,
		"exit_radius": EXIT_RADIUS,
		"exit_rect": EXIT_RECT,
		"interaction_contact_margin": INTERACTION_CONTACT_MARGIN,
		"legacy_contact_radius": LEGACY_CONTACT_RADIUS,
		"interaction_front_offset": INTERACTION_FRONT_OFFSET,
		"gameplay_camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"developer_camera_zoom": DEVELOPER_CAMERA_ZOOM,
		"room_size": Vector2(ROOM_WIDTH, ROOM_HEIGHT),
		"preferred_spawn": PLAYER_SPAWN_POSITION,
		"prop_front_z": PROP_FRONT_Z,
		"prop_back_z": PROP_BACK_Z,
		"occlusion_mode": "visual_anchor",
		"ui_layer_name": "CircuitRoomUI",
	})
	create_mechanic_npc()
	if player.has_method("set_room_visual_scale"):
		player.call("set_room_visual_scale", ROOM_ID)
	GameState.return_spawn_id = RETURN_SPAWN_ID
	_sync_debug_collision_visibility()
	if not GameState.state_changed.is_connected(_on_debug_state_changed):
		GameState.state_changed.connect(_on_debug_state_changed)
	_apply_switch_concealment()
	_evaluate_switch_survey()
	_apply_powered_generator_state()


## The workshop art already paints where the light lives. This adds the light
## those fixtures should be casting plus the discharge the cracked bus implies,
## so restoring power changes the whole room rather than one sprite tint.
func _create_room_ambience() -> void:
	ambience_layer = Node2D.new()
	ambience_layer.name = "CircuitRoomAmbience"
	ambience_layer.z_index = AMBIENCE_Z
	add_child(ambience_layer)
	for lamp_position: Vector2 in WALL_LAMP_POSITIONS:
		_wall_lamps.append(
			OpticalFxRuntime.install_lamp(ambience_layer, lamp_position, LAMP_WARM, 190.0, 0.22)
		)
	_wall_lamps.append(
		OpticalFxRuntime.install_lamp(ambience_layer, BENCH_LANTERN_POSITION, LAMP_BENCH, 150.0, 0.20)
	)
	_generator_glow = OpticalFxRuntime.install_lamp(
		ambience_layer,
		GENERATOR_CHAMBER_POSITION,
		LAMP_ARCANE,
		165.0,
		0.26
	)
	_bus_arc = OpticalFxRuntime.install_arc_emitter(
		ambience_layer,
		BROKEN_BUS_POSITION,
		Vector2(66.0, 30.0),
		Color(0.62, 0.90, 1.0, 0.92)
	)
	_generator_arc = OpticalFxRuntime.install_arc_emitter(
		ambience_layer,
		GENERATOR_CHAMBER_POSITION,
		Vector2(44.0, 34.0),
		Color(0.70, 0.94, 1.0, 0.88)
	)
	_apply_power_ambience(GameState.has_story_flag("circuit_power_restored"))


func _apply_power_ambience(powered: bool) -> void:
	for lamp: Sprite2D in _wall_lamps:
		OpticalFxRuntime.set_lamp_energy(lamp, 1.0 if powered else 0.44, 0.16 if powered else 0.34)
	OpticalFxRuntime.set_lamp_energy(_generator_glow, 1.0 if powered else 0.55, 0.14 if powered else 0.30)
	# Starved, the bus arcs constantly; once the building is fed the fault
	# settles into a rare discharge, so the room states are readable at a glance.
	OpticalFxRuntime.set_arc_interval(
		_bus_arc,
		Vector2(2.6, 5.4) if powered else Vector2(0.5, 1.5)
	)
	OpticalFxRuntime.set_arc_interval(
		_generator_arc,
		Vector2(1.6, 3.4) if powered else Vector2(0.8, 2.2)
	)


func _create_power_restoration_audio() -> void:
	power_surge_audio = AudioStreamPlayer.new()
	power_surge_audio.name = "PowerSurgeAudio"
	power_surge_audio.stream = load(POWER_SURGE_AUDIO_PATH) as AudioStream
	power_surge_audio.volume_db = -7.0
	power_surge_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	power_surge_audio.set_meta("provenance", "original_deterministic_synthesis")
	add_child(power_surge_audio)


func _apply_powered_generator_state() -> void:
	if not GameState.has_story_flag("circuit_power_restored"):
		return
	var generator_sprite := get_node_or_null("Worldsort/Generator/GeneratorSprite") as Sprite2D
	if generator_sprite != null:
		generator_sprite.modulate = Color(0.78, 1.04, 1.10, 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
		GameState.toggle_developer_mode()
		_sync_debug_collision_visibility()
		get_viewport().set_input_as_handled()


func _on_debug_state_changed() -> void:
	_sync_debug_collision_visibility()
	_evaluate_switch_survey()


## The junction plates sit flush with their housings. Until the player has a
## reason to know where they are, the room offers nothing to press: no plate, no
## prompt, no focus box and no contact band. Two things grant that knowledge —
## studying the repair blueprint, or seeing through the housings under Vision.
func _switches_surveyed() -> bool:
	return GameState.has_story_flag(SWITCH_SURVEY_FLAG)


func _evaluate_switch_survey() -> void:
	if _switches_surveyed():
		_apply_switch_concealment()
		return
	if GameState.has_story_flag("circuit_repair_map_studied"):
		_survey_switches("blueprint")
		return
	if GameState.is_potion_active("vision"):
		_survey_switches("vision")


func _apply_switch_concealment() -> void:
	var concealed := not _switches_surveyed()
	for switch_id: String in CircuitLayout.SWITCH_ORDER:
		var switch_node := switch_visuals.get(switch_id) as Node2D
		if switch_node != null:
			switch_node.visible = not concealed
		for item: Dictionary in INTERACT_ITEMS:
			if str(item["name"]) == switch_id:
				item["concealed"] = concealed


func _survey_switches(source: String) -> void:
	if _switches_surveyed():
		return
	GameState.set_story_flag(SWITCH_SURVEY_FLAG)
	_apply_switch_concealment()
	_play_switch_survey_reveal(source)
	if NoteHud != null and not NoteHud.has_clue("circuit_junction_plates"):
		NoteHud.add_clue("circuit_junction_plates", {
			"title": "Three Flush Junction Plates",
			"icon": "icon_note",
			"content": (
				"[center][b]Three Flush Junction Plates[/b][/center]\n\n"
				+ "The workshop's junction plates are set level with their housings, so "
				+ "nothing protrudes for a hand to find. The repair blueprint numbers "
				+ "them [color=#4a306d]1 auxiliary[/color], [color=#4a306d]2 regulator[/color], "
				+ "[color=#4a306d]3 master[/color].\n\n"
				+ "They must be thrown in that order; any other order trips the interlock "
				+ "and resets the run."
			),
			"category": "investigation",
		})
	if interaction_runtime != null:
		interaction_runtime.present_feedback(
			(
				"修理图纸标出了三块齐平的接线板。它们的位置已经记入现场记录。"
				if CaseLocale.is_chinese()
				else "The blueprint locates three flush junction plates. Their positions are now on record."
			)
			if source == "blueprint"
			else (
				"洞察药水让你看穿外壳：三块接线板在机壳下亮了起来。"
				if CaseLocale.is_chinese()
				else "Vision cuts through the housings: three junction plates light up beneath them."
			)
		)


## The reveal is staged rather than a visibility toggle, so the room reads as
## being surveyed: each plate charges, rings once and settles in blueprint order.
func _play_switch_survey_reveal(source: String) -> void:
	var accent := (
		Color(0.62, 0.90, 1.0, 0.94)
		if source == "blueprint"
		else Color(0.78, 0.58, 1.0, 0.94)
	)
	var step := 0
	for switch_id: String in CircuitLayout.SWITCH_ORDER:
		var switch_node := switch_visuals.get(switch_id) as Node2D
		if switch_node == null:
			continue
		switch_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
		switch_node.scale = Vector2(0.82, 0.82)
		var delay := float(step) * SWITCH_SURVEY_STAGGER
		var settle := create_tween()
		settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		settle.tween_interval(delay)
		settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.tween_property(switch_node, "scale", Vector2.ONE, 0.26)
		settle.parallel().tween_property(switch_node, "modulate:a", 1.0, 0.22)
		settle.tween_callback(
			func() -> void:
				if not is_instance_valid(switch_node):
					return
				OpticalFxRuntime.pulse_ring(
					self,
					switch_node,
					Vector2.ZERO,
					accent,
					26.0,
					2.6,
					0.42
				)
		)
		step += 1


func _sync_debug_collision_visibility() -> void:
	if interaction_runtime != null:
		interaction_runtime.set_debug_collision_visibility(GameState.developer_mode)


func _open_bench(switch_id: String) -> void:
	if circuit_lab == null or not is_instance_valid(circuit_lab):
		circuit_lab = CIRCUIT_LAB_SCRIPT.new()
		add_child(circuit_lab)
		circuit_lab.completed.connect(_on_bench_completed)
		circuit_lab.closed.connect(_on_bench_closed)
	room_input_enabled = false
	player.set_physics_process(false)
	ArchiveUi.set_hub_entries_suppressed(true)
	get_tree().paused = true
	circuit_lab.open_challenge(switch_id)


func _on_bench_completed(switch_id: String) -> void:
	if BENCH_FOR_SWITCH.has(switch_id):
		GameState.set_story_flag(BENCH_FOR_SWITCH[switch_id])


func _on_bench_closed() -> void:
	get_tree().paused = false
	ArchiveUi.set_hub_entries_suppressed(false)
	room_input_enabled = true
	if player != null:
		player.set_physics_process(true)
	if interaction_runtime != null:
		interaction_runtime.present_feedback(
			(
				"接线台已通过。现在可以按编号顺序合闸。"
				if CaseLocale.is_chinese()
				else "The bench is cleared. The plate will now throw in numbered order."
			)
			if GameState.has_story_flag("circuit_bench_continuity_cleared")
			else (
				"接线台还没有通过，这块板仍然锁着。"
				if CaseLocale.is_chinese()
				else "The bench is unfinished, so the plate stays locked."
			)
		)


func _process(_delta: float) -> void:
	# Vision expires on a timer rather than through a state change, so the reveal
	# condition is re-read here as well as on GameState updates.
	if not _switches_surveyed():
		_evaluate_switch_survey()
	var priority_interaction: Dictionary = {}
	var mechanic_rect := (
		spatial.get_visual_rect(mechanic_npc)
		if mechanic_npc != null
		else Rect2()
	)
	if (
		room_input_enabled
		and mechanic_npc != null
		and spatial.is_actor_near_rect(
			player as CharacterBody2D,
			mechanic_rect,
			INTERACTION_CONTACT_MARGIN
		)
	):
		priority_interaction = {
			"id": "mechanic",
			"label": "Mechanic",
			"position": spatial.get_visual_feet(mechanic_npc),
			"interaction_rect": mechanic_rect,
			"prompt": "Press E to talk to the Mechanic",
			"prompt_offset": Vector2(0.0, -120.0),
		}
	current_interaction = interaction_runtime.refresh(
		room_input_enabled,
		priority_interaction
	)
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


func create_mechanic_npc() -> void:
	if mechanic_npc != null:
		return
	mechanic_npc = AnimatedNpc.new()
	mechanic_npc.name = "MechanicNPC"
	mechanic_npc.position = MECHANIC_POSITION
	mechanic_npc.z_index = 0
	mechanic_npc.configure(
		"Mechanic",
		"res://assets/characters/animated_pixel_v3/mechanic_walk.png",
		MECHANIC_VISUAL_SCALE,
		Vector2(18.0, 0.0),
		10.0,
		&"right"
	)
	mechanic_npc.set_visual_foot_anchor(MECHANIC_VISUAL_FOOT_ANCHOR)
	$Worldsort.add_child(mechanic_npc)


func _create_switch_models() -> void:
	for switch_id: String in CircuitLayout.SWITCH_ORDER:
		var spec := CircuitLayout.SWITCH_SPECS[switch_id] as Dictionary
		var switch_node := get_node_or_null(
			"Worldsort/" + str(spec["node_name"])
		) as Node2D
		if switch_node == null:
			continue
		switch_node.position = spec["position"] as Vector2
		switch_node.z_as_relative = false
		switch_node.z_index = 24
		switch_node.set_meta("style_family", "ashford_circuit_switch")
		switch_node.set_meta("interaction_id", switch_id)
		var old_plate := switch_node.get_node_or_null("SwitchPlate") as CanvasItem
		if old_plate != null:
			old_plate.visible = false

		# The plate draws its own bezel, recess light and live contact, so the flat
		# polygon glow and outline that used to stand in for them are gone.
		var glow := Polygon2D.new()
		glow.name = "ActiveGlow"
		var size := spec["size"] as Vector2
		glow.polygon = PackedVector2Array([
			Vector2(-size.x * 0.62, -size.y * 0.66),
			Vector2(size.x * 0.62, -size.y * 0.66),
			Vector2(size.x * 0.62, size.y * 0.66),
			Vector2(-size.x * 0.62, size.y * 0.66),
		])
		glow.color = Color(0.28, 0.62, 0.78, 0.14)
		glow.visible = false
		glow.z_index = -1
		switch_node.add_child(glow)

		var model := CIRCUIT_SWITCH_VIEW_SCRIPT.new() as Node2D
		model.name = "SwitchModel"
		model.set("plate_size", size)
		model.set("sequence_number", str(spec["number"]))
		model.z_index = 1
		switch_node.add_child(model)

		switch_visuals[switch_id] = switch_node
		_update_switch_visual(switch_id, bool(_switch_states[switch_id]), false)


func try_interact() -> void:
	if current_interaction == "exit":
		return_to_castle_hall()
		return
	if current_interaction == "mechanic":
		interaction_runtime.present_feedback(
			"Mechanic: The blackout did not start here. Someone used the workshop's "
			+ "maintenance route, then left the generators to take the blame."
		)
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			var item_name: String = str(item["name"])
			var item_message_override: String = ""
			if item_name == "switch_left" or item_name == "switch_right" or item_name == "master_switch":
				_handle_switch_interaction(item_name, item)
				return
			if item_name == "workbench" and not GameState.has_story_flag("circuit_distilled_water_found"):
				GameState.set_story_flag("circuit_distilled_water_found")
				GameState.add_material("distilled_water", 2)
				item_message_override = "A sealed flask of Distilled Water is tucked beneath the circuit journal."
			if item_name == "cabinet" and not GameState.has_story_flag("circuit_iron_salt_found"):
				GameState.set_story_flag("circuit_iron_salt_found")
				GameState.add_material("iron_salt")
				item_message_override = "A packet of Iron Salt rests behind the equipment cabinet's loose panel."
			if item_name == "cabinet" and not GameState.has_story_flag("violet_insulating_fiber_identified"):
				GameState.set_story_flag("violet_insulating_fiber_identified")
				GameState.add_evidence("violet_insulating_fiber")
				if NoteHud != null and not NoteHud.has_clue("violet_insulating_fiber_note"):
					NoteHud.add_clue("violet_insulating_fiber_note", {
						"title": "Violet Insulating Weave",
						"icon": "icon_note",
						"content": "The castle's electrical maintenance gloves and cable wraps use a distinctive violet insulating weave. It is a maintenance material, not proof that one particular worker committed a crime.",
						"category": "investigation",
					})
			if item_name == "cabinet" and not GameState.has_story_flag("mechanic_missing_glove_record_seen"):
				GameState.set_story_flag("mechanic_missing_glove_record_seen")
				GameState.add_evidence("mechanic_missing_glove")
				item_message_override = "A maintenance record is clipped behind the cabinet panel. It lists one pair of gloves assigned to the Mechanic. The right glove had a distinctive copper-thread cross-stitch repair and is missing after the blackout."
				if NoteHud != null and not NoteHud.has_clue("mechanic_missing_glove_record"):
					NoteHud.add_clue("mechanic_missing_glove_record", {
						"title": "Mechanic's Maintenance Glove Record",
						"icon": "icon_note",
						"content": "One pair of maintenance gloves was assigned to the Mechanic. The right glove had previously been repaired with a distinctive copper-thread cross-stitch. The right glove is now missing after the blackout. The same access log records the Mechanic's statement that he was checking the west-side electrical system during the blackout; the Dining timeline will test whether that account is possible.",
						"category": "investigation",
					})
			if item_name == "cabinet":
				var sealed_archive_feedback := _collect_sealed_instruction_archive()
				if not sealed_archive_feedback.is_empty():
					interaction_runtime.present_feedback(sealed_archive_feedback)
					return
			if item_name == "generator" and not GameState.has_story_flag("circuit_prism_dust_found"):
				GameState.set_story_flag("circuit_prism_dust_found")
				GameState.add_material("prism_dust")
				item_message_override = "Prism Dust glitters in the generator's maintenance tray."
			# 剧情：首次交互工作台 → 沾污的笔记页（故意短路证据）。
			if item_name == "workbench" and not NoteHud.has_clue("circuit_short_note"):
				NoteHud.add_clue("circuit_short_note", {
					"title": "A Stained Note Page",
					"icon": "icon_note",
					"content": (
						"[center][b]A Stained Note Page[/b][/center]\n\n"
						+ "A page smudged with oil and ash, tucked inside the workbench journal:\n\n"
						+ "\"...I checked the junction box myself. The burn pattern is [color=#7a2e2e]not accidental[/color].\n\n"
						+ "A deliberate [color=#7a2e2e]short circuit[/color] cut the power exactly when the castle went dark. Someone wanted the blackout...\""
					),
					"category": "investigation",
				})
				GameState.add_evidence("deliberate_short_circuit")
				GameState.set_story_flag("blackout_deliberate")
			var feedback := item_message_override if not item_message_override.is_empty() else str(item["message"])
			var completion_feedback := _mark_circuit_investigation(item_name)
			if not completion_feedback.is_empty():
				feedback = completion_feedback
			# Without this the room is a dead end: three housings that read as
			# scenery and no stated reason to open the blueprint.
			if not _switches_surveyed() and PROP_NODE_PATHS.has(item_name):
				feedback += (
					"  一块接线板与外壳齐平，摸不出来。修理图纸应该标着它的位置。"
					if CaseLocale.is_chinese()
					else "  A junction plate sits flush with the housing, impossible to find by hand. The repair blueprint would mark it."
				)
			interaction_runtime.present_feedback(feedback)
			return


func _collect_sealed_instruction_archive() -> String:
	if not GameState.has_story_flag("normal_ending"):
		return ""
	if GameState.has_story_flag("sealed_archive_instruction_found"):
		return "The false-bottom cabinet has nothing more to give. The damaged instruction slip is already in your notes."
	GameState.set_story_flag("sealed_archive_instruction_found")
	if NoteHud != null:
		NoteHud.add_clue("sealed_archive_instruction", {
			"title": "SEALED ARCHIVE II — The Forged Instruction",
			"icon": "icon_note",
			"silent": true,
			"content": "[center][b]SEALED ARCHIVE II — EMERGENCY ISOLATION ORDER[/b][/center]\n\nThe cabinet's false bottom holds a carbon-copy instruction: “Move Dr. Lin to the analysis table. Engage the isolation field. Do not interrupt the calibration.”\n\nIts safety code belongs to the Mechanical Office, but the handwritten routing mark was added after the document was filed. The pressure seal has been scraped away; beneath it, a violet graphite trace matches the Mechanic's workshop pencil.\n\nThe Butler received an order that looked official. Someone with maintenance authority forged the command chain.",
			"category": "sealed_archive",
		})
	return "A false bottom clicks loose beneath the glove record. A scraped emergency instruction has been filed where no ordinary inspection would look."


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english


func _handle_switch_interaction(item_name: String, item: Dictionary) -> void:
	# A located plate is not yet an operable one. Each plate is released by its
	# own bench, so the sequence tests understanding rather than click order.
	if BENCH_FOR_SWITCH.has(item_name) and not GameState.has_story_flag(BENCH_FOR_SWITCH[item_name]):
		_open_bench(item_name)
		return
	var sequence: Array[String] = ["switch_left", "switch_right", "master_switch"]
	var expected: String = sequence[_switch_sequence_index]
	GameAudio.play(&"switch_throw")
	if item_name != expected:
		_switch_sequence_index = 0
		for switch_id: String in sequence:
			_switch_states[switch_id] = false
			_update_switch_visual(switch_id, false)
		interaction_runtime.present_feedback("Wrong sequence. The circuit resets. Follow the repair map from step 1.")
	else:
		_switch_states[item_name] = true
		_switch_sequence_index += 1
		_update_switch_visual(item_name, true)
		if item_name == "master_switch":
			_update_switch_puzzle_state()
			interaction_runtime.present_feedback(
				"POWER RESTORED · The generator is online. Return to the Hall and open Map to recover your route memory."
			)
		else:
			interaction_runtime.present_feedback("The switch clicks into position. Continue to the next numbered switch.")


func _update_switch_visual(switch_name: String, active: bool, animate: bool = true) -> void:
	var switch_node := switch_visuals.get(switch_name) as Node2D
	if switch_node == null:
		return
	var model := switch_node.get_node_or_null("SwitchModel") as Node2D
	var glow := switch_node.get_node_or_null("ActiveGlow") as Polygon2D
	switch_node.set_meta("active", active)
	var charge_line := switch_node.get_node_or_null("SwitchChargeLine") as Line2D
	if charge_line == null:
		charge_line = Line2D.new()
		charge_line.name = "SwitchChargeLine"
		charge_line.points = PackedVector2Array([Vector2(0.0, -54.0), Vector2(0.0, -54.0)])
		charge_line.width = 3.0
		charge_line.visible = false
		switch_node.add_child(charge_line)
	if not active:
		if model != null:
			model.call("set_closed", false, animate)
		if glow != null:
			glow.visible = false
		charge_line.visible = false
		return
	if not animate:
		if model != null:
			model.call("set_closed", true, false)
		if glow != null:
			glow.visible = true
		charge_line.visible = true
		charge_line.points = PackedVector2Array([Vector2(0.0, -54.0), Vector2.ZERO])
		charge_line.default_color = Color(0.52, 0.86, 1.0, 0.72)
		return
	# The blade only seats once the charge actually arrives, so the throw reads as
	# cause and effect rather than as two things happening at the same time.
	if glow != null:
		glow.visible = false
	OpticalFxRuntime.trace_beam(
		self,
		charge_line,
		Vector2(0.0, -54.0),
		Vector2.ZERO,
		Color(0.48, 0.84, 1.0, 0.86),
		3.6,
		0.25
	)
	OpticalFxRuntime.launch_packet(
		self,
		switch_node,
		Vector2(0.0, -54.0),
		Vector2.ZERO,
		Color(0.58, 0.90, 1.0, 1.0),
		0.27,
		_finish_switch_charge.bind(switch_name)
	)


func _finish_switch_charge(switch_name: String) -> void:
	var switch_node := switch_visuals.get(switch_name) as Node2D
	if switch_node == null or not bool(switch_node.get_meta("active", false)):
		return
	var model := switch_node.get_node_or_null("SwitchModel") as Node2D
	var glow := switch_node.get_node_or_null("ActiveGlow") as Polygon2D
	if model != null:
		# The charge has landed: this is the moment the blade swings into its jaw.
		# The throw itself already sounded on the press, so this stays visual.
		model.call("set_closed", true, true)
	if glow != null:
		glow.visible = true
		glow.scale = Vector2(0.35, 0.35)
		var glow_tween := create_tween()
		glow_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		glow_tween.tween_property(glow, "scale", Vector2.ONE, 0.24)
	switch_node.scale = Vector2(0.88, 0.88)
	var switch_tween := create_tween()
	switch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	switch_tween.tween_property(switch_node, "scale", Vector2.ONE, 0.22)
	OpticalFxRuntime.pulse_ring(
		self,
		switch_node,
		Vector2.ZERO,
		Color(0.58, 0.90, 1.0, 0.88),
		18.0,
		2.0,
		0.34
	)


func _update_switch_puzzle_state() -> void:
	if not bool(_switch_states["master_switch"]):
		return
	if GameState.has_story_flag("circuit_power_restored"):
		return
	GameState.set_learned_circuit_rule(true)
	GameState.set_circuit_door_open(true)
	GameState.set_story_flag("circuit_power_restored")
	GameState.set_story_flag("power_restoration_sequence_pending")
	GameState.unlock_map_hub()
	call_deferred("_play_power_restoration_impact")


func _play_power_restoration_impact() -> void:
	if power_restoration_effect_started:
		return
	power_restoration_effect_started = true
	await get_tree().create_timer(POWER_IMPACT_DELAY).timeout
	if not is_inside_tree():
		return

	if power_surge_audio != null and power_surge_audio.stream != null:
		power_surge_audio.play()

	var generator := get_node_or_null("Worldsort/Generator") as Node2D
	var generator_sprite := get_node_or_null("Worldsort/Generator/GeneratorSprite") as Sprite2D
	if generator != null:
		var impact := Node2D.new()
		impact.name = "GeneratorPowerImpact"
		impact.z_index = 40
		generator.add_child(impact)
		OpticalFxRuntime.pulse_ring(
			self,
			impact,
			Vector2(14.0, -164.0),
			Color(0.60, 0.94, 1.0, 0.96),
			34.0,
			3.5,
			0.62
		)
		OpticalFxRuntime.pulse_ring(
			self,
			impact,
			Vector2(14.0, -164.0),
			Color(0.76, 0.54, 1.0, 0.78),
			22.0,
			4.2,
			0.84
		)
		var cleanup := get_tree().create_timer(1.05)
		cleanup.timeout.connect(impact.queue_free)

	if generator_sprite != null:
		var base_scale := generator_sprite.scale
		generator_sprite.scale = base_scale * Vector2(0.95, 1.04)
		generator_sprite.modulate = Color(1.30, 1.45, 1.55, 1.0)
		var generator_tween := create_tween()
		generator_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		generator_tween.tween_property(
			generator_sprite,
			"scale",
			base_scale * Vector2(1.035, 0.98),
			0.11
		)
		generator_tween.tween_property(generator_sprite, "scale", base_scale, 0.22)
		generator_tween.parallel().tween_property(
			generator_sprite,
			"modulate",
			Color(0.78, 1.04, 1.10, 1.0),
			0.34
		)

	_play_power_light_flicker()
	_play_power_camera_impact()
	_apply_power_ambience(true)


func _play_power_light_flicker() -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.name = "PowerRestorationFlashLayer"
	flash_layer.layer = 70
	flash_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(flash_layer)
	var flash := ColorRect.new()
	flash.name = "PowerRestorationFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.68, 0.92, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash)
	var flicker := create_tween()
	flicker.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flicker.tween_property(flash, "color:a", 0.42, 0.06)
	flicker.tween_property(flash, "color:a", 0.06, 0.09)
	flicker.tween_property(flash, "color:a", 0.28, 0.07)
	flicker.tween_property(flash, "color:a", 0.0, 0.28)
	flicker.tween_callback(flash_layer.queue_free)


func _play_power_camera_impact() -> void:
	if interaction_runtime == null or interaction_runtime.follow_camera == null:
		return
	var camera := interaction_runtime.follow_camera
	camera.offset = Vector2(5.0, -3.0)
	var impact := create_tween()
	impact.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact.tween_property(camera, "offset", Vector2(-3.0, 2.0), 0.07)
	impact.tween_property(camera, "offset", Vector2(2.0, -1.0), 0.07)
	impact.tween_property(camera, "offset", Vector2.ZERO, 0.12)


func _mark_circuit_investigation(item_name: String) -> String:
	if not _investigated_items.has(item_name):
		_investigated_items.append(item_name)
	for required_item: String in ["workbench", "generator", "cabinet"]:
		if not _investigated_items.has(required_item):
			return ""
	if GameState.has_story_flag("circuit_dining_key_found"):
		return ""
	GameState.set_story_flag("circuit_dining_key_found")
	GameState.add_key("dining_hall_key")
	return (
		"The three clues align: the blackout was deliberate, the generator "
		+ "was tampered with, and the equipment cabinet concealed a Dining Hall Key."
	)


func return_to_castle_hall() -> void:
	if scene_transitioning:
		return
	scene_transitioning = true
	room_input_enabled = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)

	GameState.prepare_return_to_hub(RETURN_SPAWN_ID)

	var change_error: Error = get_tree().change_scene_to_file(
		GameState.return_scene_path
	)
	if change_error != OK:
		scene_transitioning = false
		room_input_enabled = true
		player.set_physics_process(true)
		push_error(
			"Failed to return to Castle Hall. Error: "
			+ str(change_error)
		)
