extends Node

signal state_changed
# 获得物品通知：add_* 成功时发出，ItemRewardHud 据此在屏幕中心显示获得提示。
signal item_acquired(item_id: String, kind: String, amount: int)
signal guardian_tracking_changed(mode: int, hall_position: Vector2)

const SAVE_PATH: String = "user://shadow_castle_save.json"
const SAVE_VERSION: int = 1
## The first usable map is deliberately incomplete: it gives the player a
## reason to enter the hall, while the Map Hub still reveals the castle through
## exploration fog rather than handing over the full route.
const DR_LIN_PARTIAL_HALL_MAP_ID: String = "dr_lin_partial_hall_map"
const GUARDIAN_HALL_START_POSITION: Vector2 = Vector2(1832.0, 1208.0)
const GUARDIAN_PATROL_SPEED: float = 82.0

# ============================================================
# Guardian escalation and the tracking serum
# ============================================================

## Every cleared room makes the Guardian faster. The serum explains why it can
## find the player at all: until it is washed off, the Guardian always knows
## where the player is. A purified player is only found by sight.
const GUARDIAN_BASE_CHASE_SPEED: float = 145.0
const GUARDIAN_ESCALATION_STEP: float = 0.12
const GUARDIAN_MAX_ESCALATION_TIER: int = 6
## An unaware Guardian only loiters near the player's next objective.
const GUARDIAN_STAKEOUT_SPEED: float = 44.0
const GUARDIAN_SEARCH_SPEED: float = 96.0
const GUARDIAN_SEARCH_DURATION: float = 6.0
const GUARDIAN_SIGHT_RANGE: float = 300.0
const GUARDIAN_SIGHT_HALF_ANGLE_DEGREES: float = 46.0
## Sight is never fully escapable at contact range, otherwise a purified player
## could stand inside the Guardian without consequence.
const GUARDIAN_PROXIMITY_ALERT_RADIUS: float = 78.0
const GUARDIAN_STUN_DURATION: float = 7.0

## Room keys are the canonical "this room is cleared" signal already used by
## progression, so escalation reads from them instead of a parallel counter.
const GUARDIAN_ESCALATION_KEY_IDS: Array[String] = [
	"chemistry_room_key",
	"library_room_key",
	"circuit_room_key",
	"dining_hall_key",
	"service_corridor_key",
	"final_room_key",
]

## Canonical objective order. A purified player is no longer tracked, so the
## Guardian instead stakes out the passage of the room the player still needs.
const GUARDIAN_OBJECTIVE_ROOM_ORDER: Array[String] = [
	"chemistry_room",
	"greenhouse_room",
	"circuit_room",
	"library",
	"dining_hall",
	"final_deduction_room",
]
var _loading_save: bool = false
var _save_queued: bool = false


func _ready() -> void:
	state_changed.connect(_queue_save)
	if not get_tree().scene_changed.is_connected(_sync_global_hud_visibility):
		get_tree().scene_changed.connect(_sync_global_hud_visibility)
	call_deferred("_sync_global_hud_visibility")


func _sync_global_hud_visibility() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var scene_path: String = current_scene.scene_file_path
	var hide_huds: bool = (
		scene_path.ends_with("main_menu.tscn")
		or scene_path.ends_with("intro_cutscene.tscn")
		# The first Castle Hall visit is a guided arrival. A player who has already
		# read Dr. Lin's desk briefing must keep the tools that briefing awarded.
		or (
			scene_path.ends_with("game_world.tscn")
			and not hall_arrival_seen
			and game_started
			and not has_wake_room_toolkit()
		)
	)
	for hud_name: String in ["InventoryHud", "KeyHud", "NoteHud", "MapHud"]:
		var hud: CanvasLayer = get_node_or_null("/root/" + hud_name) as CanvasLayer
		if hud != null:
			hud.visible = not hide_huds


func _queue_save() -> void:
	if not game_started or _loading_save or _save_queued:
		return
	_save_queued = true
	call_deferred("_flush_queued_save")


func _flush_queued_save() -> void:
	_save_queued = false
	if game_started and not _loading_save:
		save_to_disk()


func has_saved_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return typeof(parsed) == TYPE_DICTIONARY \
		and int((parsed as Dictionary).get("version", 0)) == SAVE_VERSION \
		and bool((parsed as Dictionary).get("checkpoint_valid", false))


func delete_saved_game() -> void:
	if has_saved_game():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_to_disk() -> bool:
	if not game_started or _loading_save:
		return false
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"reputation": reputation,
		"evidence_items": evidence_items,
		"knowledge_items": knowledge_items,
		"key_items": key_items,
		"inventory_items": inventory_items,
		"recipe_items": recipe_items,
		"map_items": map_items,
		"herb_counts": herb_counts,
		"material_counts": material_counts,
		"potion_effects": potion_effects,
		"dish_counts": dish_counts,
		"player_health": player_health,
		"chase_mode": chase_mode,
		"final_key_fragments": final_key_fragments,
		"map_hub_unlocked": map_hub_unlocked,
		"hall_explored_cells": hall_explored_cells,
		"story_flags": story_flags,
		"learned_fire_oxygen_rule": learned_fire_oxygen_rule,
		"wake_room_door_unlocked": wake_room_door_unlocked,
		"learned_circuit_rule": learned_circuit_rule,
		"circuit_door_open": circuit_door_open,
		"visited_rooms": visited_rooms,
		"completed_rooms": completed_rooms,
		"return_scene_path": return_scene_path,
		"return_spawn_id": return_spawn_id,
		"current_room_id": current_room_id,
		"checkpoint_scene_path": checkpoint_scene_path,
		"checkpoint_room_id": checkpoint_room_id,
		"checkpoint_spawn_id": checkpoint_spawn_id,
		"checkpoint_valid": checkpoint_valid,
		"resume_scene_path": resume_scene_path,
		"resume_room_id": resume_room_id,
		"resume_spawn_id": resume_spawn_id,
		"hall_arrival_seen": hall_arrival_seen,
		"enemy_chase_active": enemy_chase_active,
		"guardian_hunt_active": guardian_hunt_active,
		"guardian_mode": guardian_mode,
		"guardian_hall_position": _vector2_payload(guardian_hall_position),
		"guardian_patrol_index": guardian_patrol_index,
		"guardian_patrol_route": _vector2_array_payload(guardian_patrol_route),
		"guardian_tracking_serum": guardian_tracking_serum,
		"guardian_stun_remaining": guardian_stun_remaining,
		"guardian_search_remaining": guardian_search_remaining,
		"guardian_last_known_player_position": _vector2_payload(
			guardian_last_known_player_position
		),
	}
	if NoteHud != null and NoteHud.has_method("get_saved_clues"):
		payload["note_clues"] = NoteHud.get_saved_clues()
		payload["note_unlocked"] = NoteHud.is_unlocked()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func load_saved_game() -> bool:
	if not has_saved_game():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false

	_loading_save = true
	reputation = int(data.get("reputation", 0))
	evidence_items = _string_array(data.get("evidence_items", []))
	knowledge_items = _string_array(data.get("knowledge_items", []))
	key_items = _string_array(data.get("key_items", []))
	inventory_items = _string_array(data.get("inventory_items", []))
	recipe_items = _string_array(data.get("recipe_items", []))
	map_items = _string_array(data.get("map_items", []))
	herb_counts = _dictionary(data.get("herb_counts", {}))
	material_counts = _dictionary(data.get("material_counts", {}))
	potion_effects = _dictionary(data.get("potion_effects", {}))
	dish_counts = _dictionary(data.get("dish_counts", {}))
	player_health = int(data.get("player_health", 3))
	chase_mode = bool(data.get("chase_mode", false))
	final_key_fragments = _int_array(data.get("final_key_fragments", []))
	map_hub_unlocked = bool(data.get("map_hub_unlocked", false))
	hall_explored_cells = _dictionary(data.get("hall_explored_cells", {}))
	story_flags = _dictionary(data.get("story_flags", {}))
	learned_fire_oxygen_rule = bool(data.get("learned_fire_oxygen_rule", false))
	wake_room_door_unlocked = bool(data.get("wake_room_door_unlocked", false))
	learned_circuit_rule = bool(data.get("learned_circuit_rule", false))
	circuit_door_open = bool(data.get("circuit_door_open", false))
	visited_rooms = _dictionary(data.get("visited_rooms", {}))
	completed_rooms = _dictionary(data.get("completed_rooms", {}))
	return_scene_path = str(data.get("return_scene_path", "res://scenes/game_world.tscn"))
	return_spawn_id = str(data.get("return_spawn_id", "hall_entrance"))
	current_room_id = str(data.get("current_room_id", "wake_room"))
	checkpoint_scene_path = str(data.get("checkpoint_scene_path", "res://scenes/wake_room.tscn"))
	checkpoint_room_id = str(data.get("checkpoint_room_id", "wake_room"))
	checkpoint_spawn_id = str(data.get("checkpoint_spawn_id", "wake_room_start"))
	checkpoint_valid = bool(data.get("checkpoint_valid", false))
	resume_scene_path = str(data.get("resume_scene_path", checkpoint_scene_path))
	resume_room_id = str(data.get("resume_room_id", checkpoint_room_id))
	resume_spawn_id = str(data.get("resume_spawn_id", checkpoint_spawn_id))
	hall_arrival_seen = bool(data.get("hall_arrival_seen", false))
	enemy_chase_active = bool(data.get("enemy_chase_active", false))
	guardian_hunt_active = bool(data.get(
		"guardian_hunt_active",
		chase_mode or enemy_chase_active
	))
	guardian_mode = int(data.get(
		"guardian_mode",
		GuardianMode.CHASE if chase_mode else GuardianMode.PATROL if guardian_hunt_active else GuardianMode.DORMANT
	))
	guardian_hall_position = _vector2_from_data(
		data.get("guardian_hall_position", []),
		GUARDIAN_HALL_START_POSITION
	)
	guardian_patrol_route = _vector2_array_from_data(
		data.get("guardian_patrol_route", [])
	)
	guardian_patrol_index = clampi(
		int(data.get("guardian_patrol_index", 0)),
		0,
		maxi(guardian_patrol_route.size() - 1, 0)
	)
	# Saves written before the tracking-serum rework have no purification record,
	# so they correctly resume with the Guardian still able to track the player.
	guardian_tracking_serum = bool(data.get("guardian_tracking_serum", true))
	guardian_stun_remaining = maxf(
		float(data.get("guardian_stun_remaining", 0.0)),
		0.0
	)
	guardian_search_remaining = maxf(
		float(data.get("guardian_search_remaining", 0.0)),
		0.0
	)
	guardian_last_known_player_position = _vector2_from_data(
		data.get("guardian_last_known_player_position", []),
		guardian_hall_position
	)
	_sync_legacy_guardian_flags()
	game_started = true
	if NoteHud != null and NoteHud.has_method("restore_saved_clues"):
		NoteHud.restore_saved_clues(_dictionary(data.get("note_clues", {})))
		if bool(data.get("note_unlocked", false)):
			NoteHud.unlock()
	_loading_save = false
	state_changed.emit()
	return true


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			result.append(str(entry))
	return result


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry: Variant in value:
			result.append(int(entry))
	return result


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _vector2_payload(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _vector2_from_data(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _vector2_array_payload(values: Array[Vector2]) -> Array:
	var result: Array = []
	for value: Vector2 in values:
		result.append(_vector2_payload(value))
	return result


func _vector2_array_from_data(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		if entry is Array and (entry as Array).size() >= 2:
			result.append(Vector2(
				float((entry as Array)[0]),
				float((entry as Array)[1])
			))
	return result


# ============================================================
# Player progress
# ============================================================

var reputation: int = 0

var evidence_items: Array[String] = []
var knowledge_items: Array[String] = []
var key_items: Array[String] = []
var inventory_items: Array[String] = []
var recipe_items: Array[String] = []
var map_items: Array[String] = []
var herb_counts: Dictionary = {}
var material_counts: Dictionary = {}
var potion_effects: Dictionary = {}
var player_health: int = 3
var chase_mode: bool = false
var final_key_fragments: Array[int] = []
var map_hub_unlocked: bool = false
# 是否从主菜单正式开始游戏；false = 单独调试房间（解锁所有 Hub）。
var game_started: bool = false
var hall_explored_cells: Dictionary = {}
var story_flags: Dictionary = {}

# ============================================================
# Potion / recipe / herb metadata (shared by InventoryHud,
# Chemistry crafting table and Library recipe pickups)
# ============================================================

const POTION_INFO: Dictionary = {
	"swift_potion": {
		"name": "Swiftness Potion",
		"description": "Increases movement speed for 20 seconds.",
		"effect": "swift",
		"duration": 20.0,
	},
	"vision_potion": {
		"name": "Vision Potion",
		"description": "Widens the camera view for 20 seconds.",
		"effect": "vision",
		"duration": 20.0,
	},
	"green_potion": {
		"name": "Green Potion",
		"description": "A later-added green potion. It is separate from Vision Potion.",
		"effect": "",
		"duration": 0.0,
	},
	"purification_potion": {
		"name": "Purification Potion",
		"description": "Washes the Guardian's tracking serum out of your blood. Permanent: after drinking it the Guardian can only find you by sight.",
		"effect": "purify",
		"duration": 0.0,
	},
	"daze_potion": {
		"name": "Daze Potion",
		"description": "Shatters into a numbing vapour. The Guardian is stunned for 7 seconds.",
		"effect": "daze",
		"duration": 7.0,
	},
	"shroud_potion": {
		"name": "Shroud Potion",
		"description": "Bends light around you for 12 seconds. The Guardian cannot see you at all.",
		"effect": "shroud",
		"duration": 12.0,
	},
}

const RECIPE_INFO: Dictionary = {
	"recipe_swift": {
		"name": "Swiftness Potion Recipe",
		"description": "Blue Blossom x2 + Distilled Water x1 + Iron Salt x1 -> Swiftness Potion.",
		"produces": "swift_potion",
		"herb_cost": {"blue_blossom": 2},
		"material_cost": {"distilled_water": 1, "iron_salt": 1},
	},
	"recipe_vision": {
		"name": "Vision Potion Recipe",
		"description": "Moonleaf x3 + Distilled Water x1 + Prism Dust x1 -> Vision Potion.",
		"produces": "vision_potion",
		"herb_cost": {"moonleaf": 3},
		"material_cost": {"distilled_water": 1, "prism_dust": 1},
	},
	"recipe_purification": {
		"name": "Purification Potion Blueprint",
		"description": "Moonleaf x2 + Blue Blossom x1 + Distilled Water x2 -> Purification Potion. Mrs. Lin's counter-formula for the serum served at the last dinner.",
		"produces": "purification_potion",
		"herb_cost": {"moonleaf": 2, "blue_blossom": 1},
		"material_cost": {"distilled_water": 2},
	},
	"recipe_daze": {
		"name": "Daze Potion Recipe",
		"description": "Blue Blossom x2 + Iron Salt x1 + Prism Dust x1 -> Daze Potion.",
		"produces": "daze_potion",
		"herb_cost": {"blue_blossom": 2},
		"material_cost": {"iron_salt": 1, "prism_dust": 1},
	},
	"recipe_shroud": {
		"name": "Shroud Potion Recipe",
		"description": "Moonleaf x2 + Prism Dust x2 -> Shroud Potion.",
		"produces": "shroud_potion",
		"herb_cost": {"moonleaf": 2},
		"material_cost": {"prism_dust": 2},
	},
}

const HERB_INFO: Dictionary = {
	"blue_blossom": {
		"name": "Blue Blossom",
		"description": "A luminous blossom from the castle greenhouse.",
	},
	"moonleaf": {
		"name": "Moonleaf",
		"description": "A silver-veined leaf that opens only under violet light.",
	},
}

const MATERIAL_INFO: Dictionary = {
	"distilled_water": {
		"name": "Distilled Water",
		"description": "Pure water prepared for alchemical reactions.",
	},
	"iron_salt": {
		"name": "Iron Salt",
		"description": "A rust-red stabilizer used in the Swiftness formula.",
	},
	"prism_dust": {
		"name": "Prism Dust",
		"description": "Ground crystal dust that sharpens the eye.",
	},
}

const ITEM_VISUAL_INFO: Dictionary = {
	"recipe_swift": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/recipe_swift.png",
		"accent": Color(0.92, 0.38, 0.22, 1.0),
		"model_class": "formula",
	},
	"recipe_vision": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/recipe_vision.png",
		"accent": Color(0.69, 0.43, 0.94, 1.0),
		"model_class": "formula",
	},
	"recipe_purification": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/recipe_purification.png",
		"accent": Color(0.36, 0.84, 0.90, 1.0),
		"model_class": "formula",
	},
	"recipe_daze": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/recipe_daze.png",
		"accent": Color(0.94, 0.32, 0.62, 1.0),
		"model_class": "formula",
	},
	"recipe_shroud": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/recipe_shroud.png",
		"accent": Color(0.34, 0.36, 0.72, 1.0),
		"model_class": "formula",
	},
	"blue_blossom": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/blue_blossom.png",
		"accent": Color(0.24, 0.58, 1.0, 1.0),
		"model_class": "herb",
	},
	"moonleaf": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/moonleaf.png",
		"accent": Color(0.42, 0.72, 0.35, 1.0),
		"model_class": "herb",
	},
	"distilled_water": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/distilled_water.png",
		"accent": Color(0.38, 0.76, 0.92, 1.0),
		"model_class": "reagent",
	},
	"iron_salt": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/iron_salt.png",
		"accent": Color(0.84, 0.39, 0.20, 1.0),
		"model_class": "reagent",
	},
	"prism_dust": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/prism_dust.png",
		"accent": Color(0.72, 0.42, 0.96, 1.0),
		"model_class": "reagent",
	},
	"swift_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/swift_potion.png",
		"accent": Color(0.94, 0.24, 0.20, 1.0),
		"model_class": "potion",
	},
	"vision_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/vision_potion.png",
		"accent": Color(0.66, 0.38, 0.94, 1.0),
		"model_class": "potion",
	},
	"green_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/green_potion.png",
		"accent": Color(0.34, 0.82, 0.44, 1.0),
		"model_class": "potion",
	},
	"purification_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/purification_potion.png",
		"accent": Color(0.36, 0.86, 0.92, 1.0),
		"model_class": "potion",
	},
	"daze_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/daze_potion.png",
		"accent": Color(0.95, 0.30, 0.60, 1.0),
		"model_class": "potion",
	},
	"shroud_potion": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/shroud_potion.png",
		"accent": Color(0.30, 0.34, 0.70, 1.0),
		"model_class": "potion",
	},
	"castle_ration": {
		"texture": "res://assets/ui/alchemy/castle_ration.png",
		"accent": Color(0.86, 0.58, 0.28, 1.0),
		"model_class": "dish",
	},
	"cleaning_powder_sample": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/cleaning_powder_sample.png",
		"accent": Color(0.84, 0.78, 0.64, 1.0),
		"model_class": "trace_sample",
	},
	"indicator_vial_sample": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/indicator_vial_sample.png",
		"accent": Color(0.76, 0.22, 0.30, 1.0),
		"model_class": "trace_sample",
	},
	"broken_glass_sample": {
		"texture": "res://assets/ui/item_models/pixel_art_v1/broken_glass_sample.png",
		"accent": Color(0.52, 0.78, 0.82, 1.0),
		"model_class": "trace_sample",
	},
}


func get_item_visual_info(item_id: String) -> Dictionary:
	return (ITEM_VISUAL_INFO.get(item_id, {}) as Dictionary).duplicate(true)


func get_item_texture_path(item_id: String) -> String:
	return str(ITEM_VISUAL_INFO.get(item_id, {}).get("texture", ""))


func get_item_accent(item_id: String) -> Color:
	return ITEM_VISUAL_INFO.get(item_id, {}).get(
		"accent",
		Color(0.86, 0.70, 0.34, 1.0)
	) as Color


# ============================================================
# First-floor STEM progress
# ============================================================

var learned_fire_oxygen_rule: bool = false
var wake_room_door_unlocked: bool = false

var learned_circuit_rule: bool = false
var circuit_door_open: bool = false


# ============================================================
# Room exploration progress
# ============================================================

var visited_rooms: Dictionary = {
	"wake_room": false,
	"floor_1_hub": false,
	"chemistry_room": false,
	"greenhouse_room": false,
	"circuit_room": false,
	"library": false,
	"dining_hall": false,
	"final_deduction_room": false
}

var completed_rooms: Dictionary = {
	"wake_room": false,
	"chemistry_room": false,
	"greenhouse_room": false,
	"circuit_room": false,
	"library": false,
	"dining_hall": false,
	"final_deduction_room": false
}


# ============================================================
# Scene transition state
# ============================================================

var return_scene_path: String = \
	"res://scenes/game_world.tscn"

var return_spawn_id: String = "hall_entrance"

var current_room_id: String = "wake_room"

# 当前运行内的自动房间存档。只保存最近房间位置，不回滚钥匙、证据和笔记。
var checkpoint_scene_path: String = "res://scenes/wake_room.tscn"
var checkpoint_room_id: String = "wake_room"
var checkpoint_spawn_id: String = "wake_room_start"
var checkpoint_valid: bool = false
var resume_scene_path: String = "res://scenes/wake_room.tscn"
var resume_room_id: String = "wake_room"
var resume_spawn_id: String = "wake_room_start"


# ============================================================
# Castle Hall state
# ============================================================

enum GuardianMode {
	DORMANT,
	CHASE,
	PATROL,
	## Appended after PATROL so previously saved integers keep their meaning.
	SEARCH,
	STUNNED,
}

var hall_arrival_seen: bool = false
var enemy_chase_active: bool = false
var guardian_hunt_active: bool = false
var guardian_mode: int = GuardianMode.DORMANT
var guardian_hall_position: Vector2 = GUARDIAN_HALL_START_POSITION
var guardian_patrol_route: Array[Vector2] = []
var guardian_patrol_index: int = 0
## True until the player brews and drinks the Purification Potion. While true
## the Guardian always knows the player's position, which is the in-fiction
## reason it can hunt through walls.
var guardian_tracking_serum: bool = true
var guardian_stun_remaining: float = 0.0
var guardian_search_remaining: float = 0.0
var guardian_last_known_player_position: Vector2 = GUARDIAN_HALL_START_POSITION
## Hall-space entrance of each room, registered by Castle Hall so the Guardian
## can stake out a doorway without this autoload hard-coding level geometry.
var room_door_anchors: Dictionary = {}
var developer_mode: bool = false
var individual_scene_debug_state_applied: bool = false

# ============================================================
# New game
# ============================================================

func reset_new_game() -> void:
	game_started = false
	developer_mode = false
	individual_scene_debug_state_applied = false
	get_tree().debug_collisions_hint = false
	story_flags.clear()
	reputation = 0

	evidence_items.clear()
	knowledge_items.clear()
	key_items.clear()
	inventory_items.clear()
	recipe_items.clear()
	map_items.clear()
	herb_counts.clear()
	material_counts.clear()
	dish_counts.clear()
	potion_effects.clear()
	player_health = 3
	chase_mode = false
	final_key_fragments.clear()
	map_hub_unlocked = false
	hall_explored_cells.clear()

	learned_fire_oxygen_rule = false
	wake_room_door_unlocked = false

	learned_circuit_rule = false
	circuit_door_open = false

	visited_rooms = {
		"wake_room": false,
		"floor_1_hub": false,
		"chemistry_room": false,
		"greenhouse_room": false,
		"circuit_room": false,
		"library": false,
		"dining_hall": false,
		"final_deduction_room": false
	}

	completed_rooms = {
		"wake_room": false,
		"chemistry_room": false,
		"greenhouse_room": false,
		"circuit_room": false,
		"library": false,
		"dining_hall": false,
		"final_deduction_room": false
	}

	return_scene_path = \
		"res://scenes/game_world.tscn"

	return_spawn_id = "hall_entrance"
	current_room_id = "wake_room"
	checkpoint_scene_path = "res://scenes/wake_room.tscn"
	checkpoint_room_id = "wake_room"
	checkpoint_spawn_id = "wake_room_start"
	checkpoint_valid = false
	resume_scene_path = "res://scenes/wake_room.tscn"
	resume_room_id = "wake_room"
	resume_spawn_id = "wake_room_start"

	hall_arrival_seen = false
	enemy_chase_active = false
	guardian_hunt_active = false
	guardian_mode = GuardianMode.DORMANT
	guardian_hall_position = GUARDIAN_HALL_START_POSITION
	guardian_patrol_route.clear()
	guardian_patrol_index = 0
	guardian_tracking_serum = true
	guardian_stun_remaining = 0.0
	guardian_search_remaining = 0.0
	guardian_last_known_player_position = GUARDIAN_HALL_START_POSITION
	room_door_anchors.clear()

	state_changed.emit()


# ============================================================
# Reputation
# ============================================================

func add_reputation(amount: int) -> void:
	reputation += amount
	state_changed.emit()


# ============================================================
# Evidence
# ============================================================

func add_evidence(evidence_id: String) -> bool:
	if evidence_items.has(evidence_id):
		return false

	evidence_items.append(evidence_id)
	state_changed.emit()
	if current_room_id != "final_deduction_room":
		item_acquired.emit(evidence_id, "evidence", 1)
	return true


func has_evidence(evidence_id: String) -> bool:
	return evidence_items.has(evidence_id)


# ============================================================
# Knowledge
# ============================================================

func add_knowledge(knowledge_id: String) -> bool:
	if knowledge_items.has(knowledge_id):
		return false

	knowledge_items.append(knowledge_id)
	state_changed.emit()
	return true


func has_knowledge(knowledge_id: String) -> bool:
	return knowledge_items.has(knowledge_id)


# ============================================================
# Keys
# ============================================================

func add_key(key_id: String) -> bool:
	if key_items.has(key_id):
		return false
	key_items.append(key_id)
	state_changed.emit()
	item_acquired.emit(key_id, "key", 1)
	return true


func has_key(key_id: String) -> bool:
	return key_items.has(key_id)


func has_any_key() -> bool:
	return not key_items.is_empty()


func unlock_map_hub() -> void:
	if map_hub_unlocked:
		return
	map_hub_unlocked = true
	state_changed.emit()


func is_map_hub_unlocked() -> bool:
	return map_hub_unlocked


## The Wake Room desk awards a portable investigation kit.  Keep this as a
## progress query instead of making individual scenes guess which HUDs should
## survive their handoff into Castle Hall.
func has_wake_room_toolkit() -> bool:
	return (
		has_story_flag("wake_room_toolkit_unlocked")
		or map_items.has(DR_LIN_PARTIAL_HALL_MAP_ID)
	)


## Grant the persistent Wake Room handoff in one place. It is deliberately
## idempotent so scenes may also use it to migrate a save made before the map
## was added to the desk interaction.
func grant_wake_room_toolkit() -> void:
	var state_changed_here := false
	if not has_story_flag("wake_room_toolkit_unlocked"):
		story_flags["wake_room_toolkit_unlocked"] = true
		state_changed_here = true
	if not map_hub_unlocked:
		map_hub_unlocked = true
		state_changed_here = true
	if add_map(DR_LIN_PARTIAL_HALL_MAP_ID):
		# add_map already emits the state signal and the player-facing reward.
		state_changed_here = false
	if state_changed_here:
		state_changed.emit()


## 主菜单开始游戏时调用：标记正式流程开始。
func mark_game_started() -> void:
	game_started = true
	save_to_disk()


## 是否已从主菜单正式开始游戏。
func is_game_started() -> bool:
	return game_started


## 单独调试房间时解锁所有 Hub，并预置完整前置流程。
## 只由各个房间在 game_started=false 时调用；正式从主菜单开始的流程不会进入这里。
func unlock_all_hubs() -> void:
	map_hub_unlocked = true
	if NoteHud != null:
		NoteHud.unlock()
	if individual_scene_debug_state_applied:
		return
	_grant_individual_scene_debug_state()


func _grant_individual_scene_debug_state() -> void:
	individual_scene_debug_state_applied = true
	hall_arrival_seen = true
	var current_scene_path: String = ""
	if get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path
	var current_is_chemistry: bool = current_scene_path.contains("chemistry_room")
	var current_is_greenhouse: bool = current_scene_path.contains("greenhouse_room")
	var current_is_circuit: bool = current_scene_path.contains("circuit_room")
	var current_is_library: bool = current_scene_path.contains("library_room")
	var current_is_dining: bool = current_scene_path.contains("dining_hall_room")
	var current_is_final: bool = current_scene_path.contains("final_room")
	var current_is_hall: bool = current_scene_path.contains("game_world.tscn")

	# 钥匙、四片 Final Room Key、配方、材料和药水全部预置。
	for key_id: String in DEV_KEY_IDS:
		if current_is_hall and key_id == "library_room_key":
			continue
		if not key_items.has(key_id):
			key_items.append(key_id)
	if not current_is_hall:
		for fragment_index: int in [1, 2, 3, 4]:
			if not final_key_fragments.has(fragment_index):
				final_key_fragments.append(fragment_index)
	for recipe_id: String in RECIPE_INFO.keys():
		if not recipe_items.has(recipe_id):
			recipe_items.append(recipe_id)
	for potion_id: String in POTION_INFO.keys():
		if not inventory_items.has(potion_id):
			inventory_items.append(potion_id)
	for herb_id: String in HERB_INFO.keys():
		herb_counts[herb_id] = 9999
	for material_id: String in MATERIAL_INFO.keys():
		material_counts[material_id] = 9999
	if final_key_fragments.size() >= 4 or current_is_hall:
		set_story_flag("final_key_reassembled")

	# 五个大厅知识展品和所有门的知识锁预置完成。
	if not current_is_hall:
		for knowledge_flag: String in [
			"hall_knowledge_chemistry_room_collected",
			"hall_knowledge_greenhouse_room_collected",
			"hall_knowledge_circuit_room_collected",
			"hall_knowledge_dining_hall_collected",
			"hall_knowledge_library_collected",
		]:
			set_story_flag(knowledge_flag)
		sync_knowledge_notes_from_flags()
	for door_flag: String in [
		"door_chemistry_unlocked",
		"door_greenhouse_unlocked",
		"door_circuit_unlocked",
		"door_library_unlocked",
		"door_dining_unlocked",
		"door_final_unlocked",
		"final_synthesis_unlocked",
	]:
		set_story_flag(door_flag)

	# 当前正在调试的房间保留自己的首次调查；其他房间视为已完成。
	if not current_is_chemistry:
		_add_debug_evidence("fake_red_stain")
	if not current_is_greenhouse:
		_add_debug_evidence("greenhouse_pollen")
	if not current_is_circuit:
		_add_debug_evidence("deliberate_short_circuit")
		_add_debug_evidence("mechanic_missing_glove")
	if not current_is_dining:
		_add_debug_evidence("dining_timeline")
		set_story_flag("dining_service_key_found")
	if not current_is_library:
		set_story_flag("library_red_filter_active")
		set_story_flag("library_green_filter_active")
		set_story_flag("library_blue_filter_active")
		set_story_flag("library_rgb_puzzle_solved")
		set_story_flag("library_archive_record_found")
		set_story_flag("perfect_ending_library_ready")
		_add_debug_evidence("library_rgb_archive_layer")
		_add_debug_evidence("ashford_archive_record")
	if not current_is_final:
		_add_debug_evidence("mrs_lin_body")
		_add_debug_evidence("mrs_lin_violet_fiber")
		_add_debug_evidence("mrs_lin_glove_fragment")
		_add_debug_evidence("mrs_lin_notebook")
		set_story_flag("mrs_lin_found_dead")
		set_story_flag("mrs_lin_notebook_found")
		set_story_flag("vault_vision_symbols")
		set_story_flag("master_archive_route_found")
		_add_debug_evidence("master_archive_route")
	else:
		# Final Room 内可直接使用真正 Vision Potion；Vault 和 Engine 仍可现场测试。
		set_story_flag("perfect_ending_library_ready")
		_add_debug_evidence("ashford_archive_record")
		_add_debug_evidence("library_rgb_archive_layer")
		_add_debug_evidence("service_corridor_fiber")

	if not current_is_dining:
		_add_debug_evidence("service_corridor_fiber")
	if not current_is_library:
		set_story_flag("recipe_vision_found")
	if not current_is_final:
		set_story_flag("vision_mastered")
	state_changed.emit()


func sync_knowledge_notes_from_flags() -> void:
	if NoteHud == null:
		return
	var notes: Array[Dictionary] = [
		{
			"id": "hall_knowledge_chemical_change",
			"key": "note.knowledge.chemistry",
			"flag": "hall_knowledge_chemistry_room_collected",
		},
		{
			"id": "hall_knowledge_photosynthesis",
			"key": "note.knowledge.greenhouse",
			"flag": "hall_knowledge_greenhouse_room_collected",
		},
		{
			"id": "hall_knowledge_electricity",
			"key": "note.knowledge.circuit",
			"flag": "hall_knowledge_circuit_room_collected",
		},
		{
			"id": "hall_knowledge_dining_timeline",
			"key": "note.knowledge.dining",
			"flag": "hall_knowledge_dining_hall_collected",
		},
		{
			"id": "hall_knowledge_light",
			"key": "note.knowledge.library",
			"flag": "hall_knowledge_library_collected",
		},
	]
	for note: Dictionary in notes:
		if has_story_flag(str(note["flag"])) and not NoteHud.has_clue(str(note["id"])):
			var key := str(note["key"])
			# Keys, not resolved strings: a note filed in English must still read in
			# Chinese after the player switches language.
			NoteHud.add_clue(str(note["id"]), {
				"title_key": key + ".title",
				"content_key": key + ".body",
				"icon": "icon_book",
				"category": "knowledge",
			})


func _add_debug_evidence(evidence_id: String) -> void:
	if not evidence_items.has(evidence_id):
		evidence_items.append(evidence_id)


func reveal_hall_position(world_position: Vector2) -> void:
	var center_x: int = clampi(int(world_position.x / 32.0), 0, 59)
	var center_y: int = clampi(int(world_position.y / 32.0), 0, 39)
	var changed: bool = false
	for y: int in range(center_y - 1, center_y + 2):
		for x: int in range(center_x - 1, center_x + 2):
			if x < 0 or x > 59 or y < 0 or y > 39:
				continue
			var cell_key: String = str(x) + "," + str(y)
			if not hall_explored_cells.has(cell_key):
				hall_explored_cells[cell_key] = true
				changed = true
	if changed:
		state_changed.emit()


func is_hall_cell_explored(cell: Vector2i) -> bool:
	return hall_explored_cells.has(
		str(cell.x) + "," + str(cell.y)
	)


# ============================================================
# Room progress
# ============================================================

func set_room_visited(
	room_id: String,
	visited: bool = true
) -> void:
	visited_rooms[room_id] = visited
	state_changed.emit()


func is_room_visited(room_id: String) -> bool:
	return bool(
		visited_rooms.get(room_id, false)
	)


func set_room_completed(
	room_id: String,
	completed: bool = true
) -> void:
	completed_rooms[room_id] = completed
	state_changed.emit()


func is_room_completed(room_id: String) -> bool:
	return bool(
		completed_rooms.get(room_id, false)
	)


# ============================================================
# Room transitions
# ============================================================

## 进入正式房间时写入一个自动 checkpoint。
## 进度数组保持实时状态，死亡不会回滚钥匙、证据、笔记或解锁。
func save_room_checkpoint(
	scene_path: String,
	room_id: String,
	spawn_id: String = "room_start"
) -> void:
	checkpoint_scene_path = scene_path
	checkpoint_room_id = room_id
	checkpoint_spawn_id = spawn_id
	checkpoint_valid = true
	resume_scene_path = scene_path
	resume_room_id = room_id
	resume_spawn_id = spawn_id
	state_changed.emit()


func load_room_checkpoint() -> bool:
	if not has_room_checkpoint():
		return false
	recover_from_interruption()
	return true


func has_room_checkpoint() -> bool:
	return checkpoint_valid and ResourceLoader.exists(checkpoint_scene_path)


func resume_label() -> String:
	if not has_room_checkpoint():
		return CaseLocale.text("save.none")
	return CaseLocale.text(
		"save.resume",
		{"room": CaseLocale.room_name(resume_room_id)}
	)


func prepare_room_transition(
	next_room_id: String,
	scene_to_return_to: String,
	spawn_id_when_returning: String
) -> void:
	current_room_id = next_room_id
	return_scene_path = scene_to_return_to
	return_spawn_id = spawn_id_when_returning
	if guardian_hunt_active:
		if next_room_id == "floor_1_hub":
			resume_guardian_chase()
		else:
			begin_guardian_patrol()

	set_room_visited(next_room_id)


func prepare_return_to_hub(
	hub_spawn_id: String
) -> void:
	current_room_id = "floor_1_hub"
	return_scene_path = \
		"res://scenes/game_world.tscn"
	return_spawn_id = hub_spawn_id
	resume_scene_path = "res://scenes/game_world.tscn"
	resume_room_id = "floor_1_hub"
	resume_spawn_id = hub_spawn_id
	if guardian_hunt_active:
		resume_guardian_chase()
	state_changed.emit()


func set_resume_location(
	scene_path: String,
	room_id: String,
	spawn_id: String
) -> void:
	resume_scene_path = scene_path
	resume_room_id = room_id
	resume_spawn_id = spawn_id
	state_changed.emit()

func set_learned_circuit_rule(
	learned: bool = true
) -> void:
	learned_circuit_rule = learned
	state_changed.emit()


func set_circuit_door_open(
	opened: bool = true
) -> void:
	circuit_door_open = opened
	state_changed.emit()
func set_story_flag(
	flag_id: String,
	value: bool = true
) -> void:
	story_flags[flag_id] = value
	state_changed.emit()


# ============================================================
# Chase mode / health
# ============================================================

func start_chase_mode() -> void:
	activate_guardian_hunt()


func end_chase_mode() -> void:
	if guardian_hunt_active:
		begin_guardian_patrol()
	else:
		_set_guardian_mode(GuardianMode.DORMANT)


func activate_guardian_hunt() -> void:
	var was_active := guardian_hunt_active
	guardian_hunt_active = true
	if current_room_id == "floor_1_hub" and guardian_tracking_serum:
		_set_guardian_mode(GuardianMode.CHASE, not was_active)
	else:
		_set_guardian_mode(GuardianMode.PATROL, not was_active)


func is_guardian_hunt_active() -> bool:
	return guardian_hunt_active


func get_guardian_mode() -> int:
	return guardian_mode


func get_guardian_hall_position() -> Vector2:
	return guardian_hall_position


func get_guardian_patrol_route() -> Array[Vector2]:
	return guardian_patrol_route.duplicate()


func configure_guardian_patrol_route(route: Array[Vector2]) -> void:
	if route.size() < 2:
		return
	guardian_patrol_route = route.duplicate()
	var nearest_index := _nearest_guardian_patrol_index(guardian_hall_position)
	guardian_patrol_index = (nearest_index + 1) % guardian_patrol_route.size()
	guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)


func update_guardian_hall_position(new_position: Vector2) -> void:
	if guardian_hall_position.is_equal_approx(new_position):
		return
	guardian_hall_position = new_position
	guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)


func begin_guardian_patrol() -> void:
	if not guardian_hunt_active:
		return
	if not guardian_patrol_route.is_empty():
		var nearest_index := _nearest_guardian_patrol_index(guardian_hall_position)
		guardian_hall_position = guardian_patrol_route[nearest_index]
		guardian_patrol_index = (nearest_index + 1) % guardian_patrol_route.size()
	_set_guardian_mode(GuardianMode.PATROL)


func resume_guardian_chase() -> void:
	if not guardian_hunt_active:
		return
	# A purified player is no longer broadcast to the Guardian, so re-entering
	# the Hall must not hand it a free lock-on. It goes back to staking out the
	# next objective and has to earn the chase with line of sight.
	if not guardian_tracking_serum:
		begin_guardian_patrol()
		return
	_set_guardian_mode(GuardianMode.CHASE)


# ============================================================
# Guardian escalation, tracking serum, sight and counterplay
# ============================================================

## Rooms cleared so far, measured by the progression keys the player holds.
func get_guardian_cleared_room_count() -> int:
	var cleared: int = 0
	for key_id: String in GUARDIAN_ESCALATION_KEY_IDS:
		if key_items.has(key_id):
			cleared += 1
	return cleared


func get_guardian_escalation_tier() -> int:
	return mini(get_guardian_cleared_room_count(), GUARDIAN_MAX_ESCALATION_TIER)


func get_guardian_escalation_multiplier() -> float:
	return 1.0 + float(get_guardian_escalation_tier()) * GUARDIAN_ESCALATION_STEP


## Speed once the Guardian has actually locked onto the player. This is the
## stacked value the user asked for: it never decays, only rises per room.
func get_guardian_chase_speed() -> float:
	return GUARDIAN_BASE_CHASE_SPEED * get_guardian_escalation_multiplier()


## Speed while the Guardian has lost the player and is sweeping the last known
## position. Escalation still applies, but it is well below a full chase.
func get_guardian_search_speed() -> float:
	return GUARDIAN_SEARCH_SPEED * get_guardian_escalation_multiplier()


## Speed while the Guardian is merely loitering. Deliberately slow so an unseen
## player can reposition; escalation does not apply here.
func get_guardian_unaware_speed() -> float:
	if guardian_tracking_serum:
		return GUARDIAN_PATROL_SPEED
	return GUARDIAN_STAKEOUT_SPEED


func is_guardian_tracking_serum_active() -> bool:
	return guardian_tracking_serum


## Drinking the Purification Potion. Permanent, and it immediately drops the
## Guardian out of any active chase.
func purify_tracking_serum() -> bool:
	if not guardian_tracking_serum:
		return false
	guardian_tracking_serum = false
	guardian_search_remaining = 0.0
	set_story_flag("tracking_serum_purified")
	if guardian_hunt_active:
		begin_guardian_patrol()
	state_changed.emit()
	return true


func stun_guardian(duration: float = GUARDIAN_STUN_DURATION) -> void:
	guardian_stun_remaining = maxf(guardian_stun_remaining, duration)
	guardian_search_remaining = 0.0
	if guardian_hunt_active:
		_set_guardian_mode(GuardianMode.STUNNED)
	state_changed.emit()


func is_guardian_stunned() -> bool:
	return guardian_stun_remaining > 0.0


func get_guardian_stun_remaining() -> float:
	return maxf(guardian_stun_remaining, 0.0)


## The Shroud Potion makes the player undetectable by sight. It does nothing
## against the tracking serum, which is what makes purification the real fix.
func is_player_shrouded() -> bool:
	return is_potion_active("shroud")


## Castle Hall registers its own doorway geometry so this autoload never has to
## hard-code level coordinates.
func configure_room_door_anchors(anchors: Dictionary) -> void:
	room_door_anchors.clear()
	for room_id: Variant in anchors:
		var anchor: Variant = anchors[room_id]
		if anchor is Vector2:
			room_door_anchors[str(room_id)] = anchor


## The room the player still has to reach. While the player is inside a room,
## that room's own doorway is the stakeout, because the player must come back
## out through it.
func get_guardian_objective_room_id() -> String:
	if current_room_id != "floor_1_hub" and room_door_anchors.has(current_room_id):
		return current_room_id
	for room_id: String in GUARDIAN_OBJECTIVE_ROOM_ORDER:
		if not is_room_visited(room_id):
			return room_id
	return GUARDIAN_OBJECTIVE_ROOM_ORDER[GUARDIAN_OBJECTIVE_ROOM_ORDER.size() - 1]


func get_guardian_stakeout_anchor() -> Vector2:
	var objective_room_id: String = get_guardian_objective_room_id()
	if room_door_anchors.has(objective_room_id):
		return room_door_anchors[objective_room_id]
	if not guardian_patrol_route.is_empty():
		return guardian_patrol_route[guardian_patrol_index]
	return GUARDIAN_HALL_START_POSITION


## Called by the Guardian body the moment it acquires the player by sight.
func report_player_seen(player_position: Vector2) -> void:
	if not guardian_hunt_active or is_guardian_stunned():
		return
	guardian_last_known_player_position = player_position
	guardian_search_remaining = 0.0
	if guardian_mode != GuardianMode.CHASE:
		_set_guardian_mode(GuardianMode.CHASE)


## Called when sight is broken. The Guardian sweeps the last known position for
## a while, then falls back to staking out the player's next room.
func report_player_lost(last_position: Vector2) -> void:
	if not guardian_hunt_active or is_guardian_stunned():
		return
	guardian_last_known_player_position = last_position
	guardian_search_remaining = GUARDIAN_SEARCH_DURATION
	if guardian_mode != GuardianMode.SEARCH:
		_set_guardian_mode(GuardianMode.SEARCH)


func get_guardian_last_known_player_position() -> Vector2:
	return guardian_last_known_player_position


func _update_guardian_timers(delta: float) -> void:
	if guardian_stun_remaining > 0.0:
		guardian_stun_remaining = maxf(guardian_stun_remaining - delta, 0.0)
		if guardian_stun_remaining <= 0.0:
			if guardian_hunt_active:
				begin_guardian_patrol()
			state_changed.emit()
		return
	if guardian_search_remaining > 0.0:
		guardian_search_remaining = maxf(guardian_search_remaining - delta, 0.0)
		if guardian_search_remaining <= 0.0 and guardian_mode == GuardianMode.SEARCH:
			begin_guardian_patrol()


func _set_guardian_mode(new_mode: int, force_state_emit: bool = false) -> void:
	var changed := guardian_mode != new_mode
	guardian_mode = new_mode
	_sync_legacy_guardian_flags()
	if guardian_mode == GuardianMode.CHASE:
		call_deferred("_dismiss_nonessential_hud_notifications")
	guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)
	if changed or force_state_emit:
		state_changed.emit()


func _dismiss_nonessential_hud_notifications() -> void:
	var dismissal_methods: Dictionary = {
		"InventoryHud": "dismiss_feature_unlock",
		"KeyHud": "dismiss_unlock_toast",
		"NoteHud": "hide_feature_unlock",
		"ItemRewardHud": "dismiss_for_overlay",
	}
	for hud_name: String in dismissal_methods:
		var hud := get_node_or_null("/root/" + hud_name)
		var method_name: String = str(dismissal_methods[hud_name])
		if hud != null and hud.has_method(method_name):
			hud.call(method_name)


func _sync_legacy_guardian_flags() -> void:
	chase_mode = guardian_mode == GuardianMode.CHASE
	enemy_chase_active = chase_mode


func _nearest_guardian_patrol_index(position: Vector2) -> int:
	if guardian_patrol_route.is_empty():
		return 0
	var nearest_index := 0
	var nearest_distance := INF
	for index: int in range(guardian_patrol_route.size()):
		var distance := position.distance_squared_to(guardian_patrol_route[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _update_guardian_patrol(delta: float) -> void:
	if not guardian_hunt_active or is_guardian_stunned():
		return
	if guardian_mode != GuardianMode.PATROL:
		return
	# Once the serum is washed off the Guardian stops sweeping the whole Hall
	# and instead creeps toward the doorway of the room the player needs next.
	if not guardian_tracking_serum:
		var stakeout := get_guardian_stakeout_anchor()
		if guardian_hall_position.distance_to(stakeout) <= 1.0:
			return
		guardian_hall_position = guardian_hall_position.move_toward(
			stakeout,
			get_guardian_unaware_speed() * delta
		)
		guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)
		return
	if guardian_patrol_route.size() < 2:
		return
	var target := guardian_patrol_route[guardian_patrol_index]
	guardian_hall_position = guardian_hall_position.move_toward(
		target,
		GUARDIAN_PATROL_SPEED * delta
	)
	if guardian_hall_position.distance_to(target) <= 1.0:
		guardian_hall_position = target
		guardian_patrol_index = (
			guardian_patrol_index + 1
		) % guardian_patrol_route.size()
	guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)


## Resets only the volatile failure state. Evidence, keys, notes, and the
## last saved room remain intact whether the player retries, loads a checkpoint,
## or returns to the archive after an interruption.
func recover_from_interruption() -> void:
	player_health = 3
	guardian_stun_remaining = 0.0
	guardian_search_remaining = 0.0
	if guardian_hunt_active:
		guardian_mode = (
			GuardianMode.CHASE
			if resume_room_id == "floor_1_hub" and guardian_tracking_serum
			else GuardianMode.PATROL
		)
	else:
		guardian_mode = GuardianMode.DORMANT
	_sync_legacy_guardian_flags()
	guardian_tracking_changed.emit(guardian_mode, guardian_hall_position)
	state_changed.emit()


## 受伤。正常模式 3 次死亡；追逐模式 1 次即死。返回是否死亡。
func take_damage() -> bool:
	if chase_mode:
		player_health = 0
	else:
		player_health = maxi(player_health - 1, 0)
	state_changed.emit()
	return player_health <= 0


# ============================================================
# Final Room Key fragments (3 machines in the hall)
# ============================================================

## 收集 Final Room Key 碎片。返回当前碎片数量（1-4）。
## 集齐 4 片自动合成 final_room_key（大厅 3 台机器 + 服务通道维修面板后 1 片）。
func collect_final_key_fragment(fragment_index: int) -> int:
	if final_key_fragments.has(fragment_index):
		return final_key_fragments.size()
	final_key_fragments.append(fragment_index)
	item_acquired.emit("final_key_fragment_%d" % fragment_index, "fragment", 1)
	if final_key_fragments.size() >= 4 and not has_key("final_room_key"):
		add_key("final_room_key")
		set_story_flag("final_key_reassembled")
	state_changed.emit()
	return final_key_fragments.size()


func has_final_key_fragment(fragment_index: int) -> bool:
	return final_key_fragments.has(fragment_index)


func has_story_flag(flag_id: String) -> bool:
	return bool(
		story_flags.get(flag_id, false)
	)
const DEV_KEY_IDS: Array[String] = [
	"wake_room_key",
	"chemistry_room_key",
	"greenhouse_room_key",
	"circuit_room_key",
	"service_corridor_key",
	"final_room_key",
	"dining_hall_key",
	"library_room_key",
]
const DEV_EVIDENCE_IDS: Array[String] = [
	"fake_red_stain",
	"greenhouse_pollen",
	"deliberate_short_circuit",
	"violet_insulating_fiber",
	"mechanic_missing_glove",
	"dining_timeline",
	"stopped_midnight_clock",
	"dining_red_cloth",
	"service_corridor_dark_trail",
	"service_corridor_fiber",
	"vault_vision_symbols",
	"ashford_archive_record",
	"final_archive_document",
	"mrs_lin_body",
	"mrs_lin_violet_fiber",
	"mrs_lin_glove_fragment",
	"mrs_lin_notebook",
	"master_archive_route",
]

func grant_developer_inventory() -> void:
	for key_id: String in DEV_KEY_IDS:
		if not key_items.has(key_id):
			key_items.append(key_id)
	for potion_id: String in POTION_INFO.keys():
		if not inventory_items.has(potion_id):
			inventory_items.append(potion_id)
	for recipe_id: String in RECIPE_INFO.keys():
		if not recipe_items.has(recipe_id):
			recipe_items.append(recipe_id)
	for herb_id: String in HERB_INFO.keys():
		herb_counts[herb_id] = 9999
	for material_id: String in MATERIAL_INFO.keys():
		material_counts[material_id] = 9999
	for dish_id: String in DISH_INFO.keys():
		dish_counts[dish_id] = 9999
	for evidence_id: String in DEV_EVIDENCE_IDS:
		if not evidence_items.has(evidence_id):
			evidence_items.append(evidence_id)
	if not map_items.has("circuit_repair_map"):
		map_items.append("circuit_repair_map")
	for fragment_index: int in [1, 2, 3]:
		if not final_key_fragments.has(fragment_index):
			final_key_fragments.append(fragment_index)
	state_changed.emit()


func toggle_developer_mode() -> bool:
	developer_mode = not developer_mode
	get_tree().debug_collisions_hint = developer_mode
	if developer_mode:
		grant_developer_inventory()
	state_changed.emit()
	return developer_mode


# Inventory (potion bag)
# ============================================================

func add_inventory_item(item_id: String) -> bool:
	inventory_items.append(item_id)
	state_changed.emit()
	item_acquired.emit(item_id, "potion", 1)
	return true


func has_inventory_item(item_id: String) -> bool:
	return inventory_items.has(item_id)


func remove_inventory_item(item_id: String) -> bool:
	if not inventory_items.has(item_id):
		return false
	if developer_mode:
		return true
	inventory_items.erase(item_id)
	state_changed.emit()
	return true


# ============================================================
# Potion recipes (collected from Library bookshelves)
# ============================================================

func add_recipe(recipe_id: String) -> bool:
	if recipe_items.has(recipe_id):
		return false
	recipe_items.append(recipe_id)
	state_changed.emit()
	item_acquired.emit(recipe_id, "recipe", 1)
	return true


func has_recipe(recipe_id: String) -> bool:
	return recipe_items.has(recipe_id)


func add_map(map_id: String) -> bool:
	if map_items.has(map_id):
		return false
	map_items.append(map_id)
	state_changed.emit()
	item_acquired.emit(map_id, "map", 1)
	return true


func has_map(map_id: String) -> bool:
	return map_items.has(map_id)


# ============================================================
# Herbs (gathered in Greenhouse after completion)
# ============================================================

func add_herb(herb_id: String, amount: int = 1) -> void:
	herb_counts[herb_id] = int(herb_counts.get(herb_id, 0)) + amount
	state_changed.emit()
	item_acquired.emit(herb_id, "herb", amount)


func get_herb_count(herb_id: String) -> int:
	return int(herb_counts.get(herb_id, 0))


func consume_herb(herb_id: String, amount: int = 1) -> bool:
	if get_herb_count(herb_id) < amount:
		return false
	if developer_mode:
		return true
	herb_counts[herb_id] = get_herb_count(herb_id) - amount
	state_changed.emit()
	return true


func add_material(material_id: String, amount: int = 1) -> void:
	material_counts[material_id] = int(material_counts.get(material_id, 0)) + amount
	state_changed.emit()
	item_acquired.emit(material_id, "material", amount)


func get_material_count(material_id: String) -> int:
	return int(material_counts.get(material_id, 0))


func consume_material(material_id: String, amount: int = 1) -> bool:
	if get_material_count(material_id) < amount:
		return false
	if developer_mode:
		return true
	material_counts[material_id] = get_material_count(material_id) - amount
	state_changed.emit()
	return true


# ============================================================
# Dishes (kitchen system) — restore health.
# 菜肴系统：开局由 Mrs. Lin 引入，可恢复生命值。
# ============================================================
const DISH_INFO: Dictionary = {
	"castle_ration": {
		"name": "Castle Ration",
		"description": "A compact travel ration from the castle kitchen. Restores 1 health.",
		"restore": 1,
	},
}

var dish_counts: Dictionary = {}


func add_dish(dish_id: String, count: int = 1) -> void:
	dish_counts[dish_id] = int(dish_counts.get(dish_id, 0)) + count
	state_changed.emit()


func get_dish_count(dish_id: String) -> int:
	return int(dish_counts.get(dish_id, 0))


func has_dish(dish_id: String) -> bool:
	return get_dish_count(dish_id) > 0


## 食用菜肴恢复健康。返回是否成功。
func consume_dish(dish_id: String) -> bool:
	if not has_dish(dish_id):
		return false
	if not developer_mode:
		dish_counts[dish_id] = maxi(int(dish_counts[dish_id]) - 1, 0)
	var restore: int = int(DISH_INFO.get(dish_id, {}).get("restore", 1))
	player_health = mini(player_health + restore, 3)
	state_changed.emit()
	return true


# ============================================================
# Potion effects (timed buffs)
# ============================================================

## 使用药水：effect_id 为 "swift" / "vision"，duration 为秒。
func apply_potion_effect(effect_id: String, duration: float) -> void:
	potion_effects[effect_id] = duration
	state_changed.emit()


func is_potion_active(effect_id: String) -> bool:
	return float(potion_effects.get(effect_id, 0.0)) > 0.0


func get_potion_remaining(effect_id: String) -> float:
	return maxf(float(potion_effects.get(effect_id, 0.0)), 0.0)


## 房间相机目标缩放：开发者模式优先；洞察药水生效时放大视野（zoom 更小）。
func get_room_camera_zoom(gameplay_zoom: Vector2, developer_zoom: Vector2) -> Vector2:
	if developer_mode:
		return developer_zoom
	var zoom: Vector2 = gameplay_zoom
	if is_potion_active("vision"):
		zoom *= 0.85
	return zoom


func _process(delta: float) -> void:
	_update_guardian_timers(delta)
	_update_guardian_patrol(delta)
	## 全局递减药水效果倒计时（autoload 常驻，跨房间持续）。
	if potion_effects.is_empty():
		return
	var changed: bool = false
	for effect_id: String in potion_effects.keys():
		var remaining: float = float(potion_effects[effect_id]) - delta
		if remaining <= 0.0:
			potion_effects.erase(effect_id)
			changed = true
		else:
			potion_effects[effect_id] = remaining
	if changed:
		state_changed.emit()
