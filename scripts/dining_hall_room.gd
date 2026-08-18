extends Node2D

## Dining Hall — 宴会厅（用户提供 2a554008 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/dining_hall_banquet.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "dining_hall"
const RETURN_SPAWN_ID: String = "dining_hall_door"

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"dining_table": NodePath("Worldsort/DiningTable"),
	"fireplace": NodePath("Worldsort/Fireplace"),
	"wall_door": NodePath("Worldsort/WallDoor"),
	"grandfather_clock": NodePath("Worldsort/GrandfatherClock"),
	"sideboard": NodePath("Worldsort/Sideboard"),
	"cabinet": NodePath("Worldsort/Cabinet"),
	"main_door": NodePath("Worldsort/MainDoor")
}

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "dining_table",
		"label": "the banquet table",
		"position": Vector2(700.0, 660.0),
		"message": (
			"The long banquet table still bears the remnants of a feast. "
			+ "Wine stains and scattered cutlery tell a hurried story."
		)
	},
	{
		"name": "fireplace",
		"label": "the hearth",
		"position": Vector2(164.0, 390.0),
		"message": (
			"The hearth crackles warmly. Embers glow beneath the "
			+ "worn mantel."
		)
	},
	{
		"name": "wall_door",
		"label": "the barred door",
		"position": Vector2(1224.0, 300.0),
		"message": (
			"A heavy wooden door set in the stone wall. "
			+ "It is barred from the other side."
		)
	},
	{
		"name": "grandfather_clock",
		"label": "the grandfather clock",
		"position": Vector2(1330.0, 570.0),
		"message": (
			"The clock has stopped at midnight. Its pendulum hangs "
			+ "motionless."
		)
	},
	{
		"name": "sideboard",
		"label": "the laden sideboard",
		"position": Vector2(1283.0, 900.0),
		"message": (
			"A heavy sideboard laden with dishes and silver. "
			+ "A torn red cloth hangs over its front edge."
		)
	},
	{
		"name": "cabinet",
		"label": "the storage cabinet",
		"position": Vector2(138.0, 850.0),
		"message": (
			"A tall storage cabinet. Cookware and jugs crowd "
			+ "its dark shelves."
		)
	}
]

@export var debug_print_click_position := false

var player: Node2D
var scene_transitioning := false
var room_input_enabled := true
var current_interaction := ""
var _inspected_items: Array[String] = []
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
		"room_display_name": "Dining Hall",
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
		"ui_layer_name": "DiningRoomUI",
	})
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID


func _process(_delta: float) -> void:
	current_interaction = interaction_runtime.refresh(room_input_enabled)
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


func _mark_dining_item(item_name: String) -> String:
	if _inspected_items.has(item_name):
		return ""
	_inspected_items.append(item_name)
	for item: Dictionary in INTERACT_ITEMS:
		if not _inspected_items.has(str(item["name"])):
			return ""
	if GameState.has_story_flag("dining_service_key_found"):
		return ""
	GameState.set_story_flag("dining_service_key_found")
	GameState.set_story_flag("dining_timeline_reconstructed")
	GameState.add_key("service_corridor_key")
	GameState.add_evidence("dining_timeline")
	_show_dining_note(
		"dining_timeline_reconstructed_note",
		"The Last Twenty Minutes",
		"The dining hall evidence reconstructs the missing interval: the meal ended, the clock was stopped by hand, the fire was disturbed, and someone used the service route after the blackout. Mrs. Lin's final note warns that the event was not an accident."
	)
	if NoteHud != null and not NoteHud.has_clue("mrs_lin_last_dining_note"):
		NoteHud.add_clue("mrs_lin_last_dining_note", {
			"title": "Mrs. Lin's Last Dining Note",
			"content": "\"The clock is a distraction. Follow the heat, the ash, and the service route. If the lights fail, do not trust the first person who claims to have been trapped. Someone knows I am following the route now. I can hear movement behind the wall. If you find this note, do not follow just because I did. Of course, you probably will.\"",
			"category": "investigation",
		})
	return "The dining timeline is complete. Mrs. Lin's last note points toward the hidden service route. A cold key is hidden behind the wall door."


func _show_dining_note(note_id: String, title: String, content: String) -> void:
	if NoteHud.has_clue(note_id):
		return
	var parchment: Node = get_node_or_null("/root/ParchmentHud")
	if parchment != null:
		parchment.call(
			"show_parchment",
			title,
			content,
			note_id,
			{
				"title": title,
				"icon": "icon_note",
				"content": content,
				"category": "investigation",
			}
		)
		return
	NoteHud.add_clue(note_id, {
		"title": title,
		"icon": "icon_note",
		"content": content,
		"category": "investigation",
	})


func try_interact() -> void:
	if current_interaction == "exit":
		return_to_castle_hall()
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			var item_name: String = str(item["name"])
			if item_name == "dining_table":
				GameState.add_evidence("dining_timeline")
				_show_dining_note(
					"dining_timeline_note",
					"The Last Dinner Timeline",
					"The plates were cleared at 11:40. The clock stopped at midnight, but the fireplace ash is fresh. Someone moved through the hall during the missing twenty minutes."
				)
			if item_name == "grandfather_clock" and not GameState.has_story_flag(
				"dining_timeline_reconstructed"
			):
				_open_timeline_minigame()
				return
			if item_name == "grandfather_clock":
				GameState.add_evidence("stopped_midnight_clock")
				_show_dining_note(
					"dining_clock_note",
					"A Clock Stopped at Midnight",
					"The pendulum was stopped by hand. The minute hand is bent toward twelve, as if someone wanted the room to remember a false time."
				)
			if item_name == "sideboard":
				GameState.add_evidence("dining_red_cloth")
				_show_dining_note(
					"dining_red_cloth_note",
					"A Torn Red Cloth",
					"A strip of red fabric is caught on the silver drawer. Its threads match the service uniforms, not the table decorations."
				)
			if item_name == "fireplace":
				_show_dining_note(
					"dining_fireplace_note",
					"Fresh Ashes",
					"The fire is warm, but no log has burned evenly. Ash marks continue behind the hearth toward the barred wall door."
				)
			if item_name == "cabinet":
				_show_dining_note(
					"dining_cabinet_note",
					"The Service Passage Record",
					"A folded kitchen record names the service passage as the only route that bypasses the main corridor. The last entry is signed just before midnight."
				)
				var sealed_archive_feedback := _collect_sealed_pressure_archive()
				if not sealed_archive_feedback.is_empty():
					interaction_runtime.present_feedback(sealed_archive_feedback)
					return
			var completion_feedback := _mark_dining_item(item_name)
			if item_name == "wall_door" and GameState.has_key("service_corridor_key"):
				interaction_runtime.present_feedback("The Service Corridor Key fits the hidden lock. The passage lies behind the hall's east wall — the way back is marked in the Castle Hall.")
				return_to_castle_hall()
				return
			var feedback := completion_feedback if not completion_feedback.is_empty() else str(item["message"])
			interaction_runtime.present_feedback(feedback)
			return


func _collect_sealed_pressure_archive() -> String:
	if not GameState.has_story_flag("normal_ending"):
		return ""
	if GameState.has_story_flag("sealed_archive_pressure_found"):
		return "The narrow compartment behind the service ledger is empty. Its private archive has already been copied."
	GameState.set_story_flag("sealed_archive_pressure_found")
	if NoteHud != null:
		NoteHud.add_clue("sealed_archive_pressure", {
			"title": "SEALED ARCHIVE I — The Butler's Pressure",
			"icon": "icon_note",
			"silent": true,
			"content": "[center][b]SEALED ARCHIVE I — PRIVATE SERVICE ADDENDUM[/b][/center]\n\nA letter hidden beneath the service ledger records the Butler's demotion after a safety incident years ago. The Mechanical Office offered a way to restore his standing: carry out one emergency isolation order exactly, without asking questions.\n\nThe order promised that Dr. Lin would be kept safe behind the Ashford table's field. The Butler's later note ends with a trembling line: [color=#4a306d]“I operated the apparatus. I believed I was protecting her.”[/color]\n\nThis explains his pressure and his action. It does not identify the author of the order.",
			"category": "sealed_archive",
		})
	return "A narrow compartment opens behind the service ledger. Inside is an unmarked sealed folio — no map marker, no task order, only a private record."


func return_to_castle_hall() -> void:
	if scene_transitioning:
		return
	scene_transitioning = true
	room_input_enabled = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)

	# 调查完成后离开：敌人察觉玩家接近真相，进入追逐模式。
	if GameState.has_key("service_corridor_key"):
		GameState.set_story_flag("castle_guardian_activated")
		GameState.start_chase_mode()

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


## 落地钟前的时间推演。餐厅知识展品讲的是"用变化稳定的量推算时间，而且
## 一处观察远远不够"——这个小游戏里每关都混着一条坏线索（多半就是这台被
## 人为停掉的钟），玩家必须靠多数互相独立的线索把它排除掉。
func _open_timeline_minigame() -> void:
	var launched: bool = MinigameLauncher.launch(
		self,
		ElapsedTimeMinigame.new(),
		_mg_text("Reconstructing the Hour", "推演时刻"),
		_mg_text(
			"The clock says midnight. The ash, the wax and the ice say"
			+ " something else. Work out which of them is lying.",
			"钟面写着午夜。灰烬、蜡油和冰块却是另一种说法。找出在说谎的那一个。"
		),
		Color(0.86, 0.72, 0.98, 1.0),
		_on_timeline_minigame_finished
	)
	if not launched:
		interaction_runtime.present_feedback("You are already working this out.")


func _on_timeline_minigame_finished(cleared_all: bool, stages: int) -> void:
	if not cleared_all:
		interaction_runtime.present_feedback(
			(
				"You reconstructed %d of the timings before stepping back"
				+ " from the clock."
			) % stages
		)
		return
	GameState.set_story_flag("dining_timeline_reconstructed")
	GameState.add_evidence("stopped_midnight_clock")
	_show_dining_note(
		"dining_clock_note",
		"A Clock Stopped at Midnight",
		"The pendulum was stopped by hand. The minute hand is bent toward"
		+ " twelve, as if someone wanted the room to remember a false time."
		+ " Every other indicator in this room disagrees with it, and they"
		+ " all agree with each other."
	)


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english
