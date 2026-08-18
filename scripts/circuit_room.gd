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

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const MECHANIC_POSITION: Vector2 = Vector2(930.0, 850.0)
const MECHANIC_INTERACT_RADIUS: float = 88.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
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

var INTERACT_ITEMS: Array[Dictionary] = [
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
	},
	{
		"name": "switch_left",
		"label": "the left power switch",
		"position": Vector2(210.0, 535.0),
		"message": "A left-side power switch. Its purpose is unclear."
	},
	{
		"name": "switch_right",
		"label": "the right power switch",
		"position": Vector2(1210.0, 595.0),
		"message": "A right-side power switch. Its purpose is unclear."
	},
	{
		"name": "master_switch",
		"label": "the master switch",
		"position": Vector2(705.0, 595.0),
		"message": "A large master power switch. Its purpose is unclear."
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
var _last_debug_mouse_position := Vector2(-100000, -100000)


func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = ROOM_ID
	GameState.set_room_visited(ROOM_ID)
	player = $Worldsort/player
	player.position = PLAYER_SPAWN_POSITION
	player.set_physics_process(true)
	interaction_runtime = RoomInteractionRuntime.new()
	add_child(interaction_runtime)
	interaction_runtime.configure(self, player, {
		"items": INTERACT_ITEMS,
		"prop_node_paths": PROP_NODE_PATHS,
		"room_display_name": "Circuit Room",
		"exit_position": EXIT_POSITION,
		"exit_radius": EXIT_RADIUS,
		"interaction_contact_margin": INTERACTION_CONTACT_MARGIN,
		"legacy_contact_radius": LEGACY_CONTACT_RADIUS,
		"interaction_front_offset": INTERACTION_FRONT_OFFSET,
		"gameplay_camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"developer_camera_zoom": DEVELOPER_CAMERA_ZOOM,
		"room_size": Vector2(ROOM_WIDTH, ROOM_HEIGHT),
		"prop_front_z": PROP_FRONT_Z,
		"prop_back_z": PROP_BACK_Z,
		"ui_layer_name": "CircuitRoomUI",
	})
	create_mechanic_npc()
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID
	_sync_debug_collision_visibility()
	if not GameState.state_changed.is_connected(_on_debug_state_changed):
		GameState.state_changed.connect(_on_debug_state_changed)


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


func _sync_debug_collision_visibility() -> void:
	if interaction_runtime != null:
		interaction_runtime.set_debug_collision_visibility(GameState.developer_mode)


func _process(_delta: float) -> void:
	var priority_interaction: Dictionary = {}
	if (
		room_input_enabled
		and mechanic_npc != null
		and player.global_position.distance_to(mechanic_npc.global_position) <= MECHANIC_INTERACT_RADIUS
	):
		priority_interaction = {
			"id": "mechanic",
			"label": "Mechanic",
			"position": mechanic_npc.global_position,
			"prompt": "Press E to talk to the Mechanic",
			"prompt_offset": Vector2(0.0, -72.0),
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
	mechanic_npc.z_index = 6
	mechanic_npc.configure(
		"Mechanic",
		"res://assets/characters/animated_pixel_v3/mechanic_walk.png",
		0.20,
		Vector2(18.0, 0.0),
		10.0,
		&"right"
	)
	$Worldsort.add_child(mechanic_npc)


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


## 合闸之前先要求玩家把断掉的线路接通。线路房知识展品讲的是导体与闭合
## 回路，这个小游戏把"金属导电"扩展到石墨、盐水这些反直觉的导体上。
func _open_conductor_minigame() -> void:
	var launched: bool = MinigameLauncher.launch(
		self,
		ConductorMinigame.new(),
		_mg_text("Repair Bench", "线路维修台"),
		_mg_text(
			"The maintenance rail is broken in several places. Bridge every"
			+ " gap with something that actually carries current.",
			"维修导轨断了好几处。每个缺口都得用真正导电的东西接上。"
		),
		Color(1.0, 0.82, 0.42, 1.0),
		_on_conductor_minigame_finished
	)
	if not launched:
		interaction_runtime.present_feedback("The repair bench is already open.")


func _on_conductor_minigame_finished(cleared_all: bool, stages: int) -> void:
	if cleared_all:
		GameState.set_story_flag("circuit_rail_repaired")
		interaction_runtime.present_feedback(
			"Every rail is closed. The switch bank has power again — now the"
			+ " sequence."
		)
		return
	interaction_runtime.present_feedback(
		"You closed %d of the broken rails before stepping away. The switch"
		% stages
		+ " bank stays dead until all of them carry current."
	)


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english


func _handle_switch_interaction(item_name: String, item: Dictionary) -> void:
	# 导轨没修好之前，开关排根本没电，谈不上按顺序合闸。
	if not GameState.has_story_flag("circuit_rail_repaired"):
		_open_conductor_minigame()
		return
	var sequence: Array[String] = ["switch_left", "switch_right", "master_switch"]
	var expected: String = sequence[_switch_sequence_index]
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
			interaction_runtime.present_feedback("The master switch engages. The workshop power is restored.")
		else:
			interaction_runtime.present_feedback("The switch clicks into position. Continue to the next numbered switch.")


func _update_switch_visual(switch_name: String, active: bool) -> void:
	if not active:
		return
	var node_name: String = (
		"SwitchLeft" if switch_name == "switch_left"
		else "SwitchRight" if switch_name == "switch_right"
		else "MasterSwitch"
	)
	var switch_node: Node2D = get_node_or_null("Worldsort/" + node_name) as Node2D
	if switch_node == null:
		return
	var plate: Polygon2D = switch_node.get_node_or_null("SwitchPlate") as Polygon2D
	if plate != null:
		plate.color = Color(0.20, 0.21, 0.20, 0.0)


func _update_switch_puzzle_state() -> void:
	if not bool(_switch_states["master_switch"]):
		return
	if GameState.learned_circuit_rule and GameState.circuit_door_open:
		return
	GameState.set_learned_circuit_rule(true)
	GameState.set_circuit_door_open(true)
	GameState.set_story_flag("circuit_power_restored")


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
