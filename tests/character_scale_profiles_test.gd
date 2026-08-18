extends SceneTree

const PLAYER_ROOM_CASES: Array[Dictionary] = [
	{"id": "wake_room", "scene": "res://scenes/wake_room.tscn", "player": NodePath("player")},
	{"id": "floor_1_hub", "scene": "res://scenes/game_world.tscn", "player": NodePath("player")},
	{"id": "chemistry_room", "scene": "res://scenes/floor_1/chemistry_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "greenhouse_room", "scene": "res://scenes/floor_1/greenhouse_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "circuit_room", "scene": "res://scenes/floor_1/circuit_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "dining_hall", "scene": "res://scenes/floor_1/dining_hall_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "library", "scene": "res://scenes/floor_1/library_room.tscn", "player": NodePath("Worldsort/player")},
	{"id": "final_deduction_room", "scene": "res://scenes/floor_1/final_room.tscn", "player": NodePath("Worldsort/player")},
]
const PLAYER_TARGET_SCALE := Vector2(2.0, 2.0)
# Castle Hall is the one oversized space, so it is the one room where the figure
# is deliberately smaller. Every other room keeps the room-scale profile.
const HALL_PLAYER_TARGET_SCALE := Vector2(1.45, 1.45)
const PLAYER_FRAME_OPAQUE_HEIGHT: float = 239.0
const PLAYER_SPRITE_SCALE: float = 0.19
const CHEMISTRY_TABLE_DEPTH: float = 340.0
const BUTLER_TARGET_SCALE := Vector2(2.10, 2.10)
const BUTLER_TARGET_POSITION := Vector2(0.0, -48.30)
const GARDENER_TARGET_SCALE := Vector2(0.43, 0.43)
const GARDENER_TARGET_POSITION := Vector2(0.0, -46.44)
const MECHANIC_TARGET_SCALE := Vector2(0.426, 0.426)
const MECHANIC_TARGET_POSITION := Vector2(0.0, -41.322)
const DR_LIN_ECHO_TARGET_SCALE := Vector2(0.45, 0.45)
const DR_LIN_ECHO_TARGET_POSITION := Vector2(0.0, -44.55)
const GUARDIAN_TARGET_SCALE := Vector2(0.8, 0.8)
const GUARDIAN_TARGET_POSITION := Vector2(0.0, -44.8)
const MRS_LIN_TARGET_SCALE := Vector2(0.08, 0.08)
const MRS_LIN_ORIGINAL_COLLISION_SIZE := Vector2(140.0, 70.0)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").set("_loading_save", true)
	for room_case: Dictionary in PLAYER_ROOM_CASES:
		_prepare_game_state()
		await _check_room(room_case)
	_finish()


func _prepare_game_state() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_fail("GameState autoload is unavailable")
		return
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.developer_mode = false
	game_state.hall_arrival_seen = true
	game_state.chase_mode = false
	game_state.enemy_chase_active = false
	game_state.return_spawn_id = "hall_entrance"
	debug_collisions_hint = false


func _check_room(room_case: Dictionary) -> void:
	var packed_scene := load(str(room_case["scene"])) as PackedScene
	_expect(packed_scene != null, "%s scene loads" % room_case["id"])
	if packed_scene == null:
		return
	var room := packed_scene.instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	await create_timer(0.30).timeout

	var player := room.get_node_or_null(room_case["player"] as NodePath) as CharacterBody2D
	_expect(player != null, "%s player exists" % room_case["id"])
	if player != null:
		var visual_root := player.get_node_or_null("VisualRoot") as Node2D
		var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(visual_root != null, "%s player VisualRoot exists" % room_case["id"])
		if visual_root != null:
			var expected_player_scale := (
				HALL_PLAYER_TARGET_SCALE
				if str(room_case["id"]) == "floor_1_hub"
				else PLAYER_TARGET_SCALE
			)
			_expect_vector(visual_root.scale, expected_player_scale, "%s player visual scale" % room_case["id"])
		_expect_vector(player.scale, Vector2.ONE, "%s player body scale remains unchanged" % room_case["id"])
		if collision != null:
			_expect_vector(collision.scale, Vector2.ONE, "%s player collision scale remains unchanged" % room_case["id"])

	match str(room_case["id"]):
		"floor_1_hub":
			_check_animated_sprite(
				room.get_node_or_null("CastleGuardian/GuardianCore") as AnimatedSprite2D,
				GUARDIAN_TARGET_SCALE,
				GUARDIAN_TARGET_POSITION,
				"Castle Guardian"
			)
		"chemistry_room":
			var actual_player_scale := 0.0
			if player != null:
				var actual_visual_root := player.get_node_or_null("VisualRoot") as Node2D
				if actual_visual_root != null:
					actual_player_scale = actual_visual_root.scale.y
			var player_visual_height := (
				PLAYER_FRAME_OPAQUE_HEIGHT
				* PLAYER_SPRITE_SCALE
				* actual_player_scale
			)
			var furniture_ratio := player_visual_height / CHEMISTRY_TABLE_DEPTH
			_expect(
				furniture_ratio >= 0.24 and furniture_ratio <= 0.30,
				"Chemistry player height is proportional to the alchemy table (ratio %.3f)" % furniture_ratio
			)
			_check_animated_npc(room.find_child("ButlerNPC", true, false), BUTLER_TARGET_SCALE, BUTLER_TARGET_POSITION, "Chemistry Butler")
			if room.has_method("_create_vision_echo"):
				room.call("_create_vision_echo")
				await process_frame
			_check_animated_npc(room.find_child("DrLinMemoryEcho", true, false), DR_LIN_ECHO_TARGET_SCALE, DR_LIN_ECHO_TARGET_POSITION, "Dr. Lin memory echo")
		"greenhouse_room":
			_check_animated_npc(room.find_child("GardenerNPC", true, false), GARDENER_TARGET_SCALE, GARDENER_TARGET_POSITION, "Greenhouse Gardener")
		"circuit_room":
			_check_animated_npc(room.find_child("MechanicNPC", true, false), MECHANIC_TARGET_SCALE, MECHANIC_TARGET_POSITION, "Circuit Mechanic")
		"final_deduction_room":
			var body_visual := room.get_node_or_null("MrsLinBody/BodyVisual") as Sprite2D
			_expect(body_visual != null, "Mrs. Lin body visual exists")
			if body_visual != null:
				_expect_vector(body_visual.scale, MRS_LIN_TARGET_SCALE, "Mrs. Lin body visual scale")
			var body_collision := room.get_node_or_null("MrsLinBody/FurnitureCollision/CollisionShape2D") as CollisionShape2D
			_expect(body_collision != null, "Mrs. Lin body collision exists")
			if body_collision != null and body_collision.shape is RectangleShape2D:
				_expect_vector(
					(body_collision.shape as RectangleShape2D).size,
					MRS_LIN_ORIGINAL_COLLISION_SIZE,
					"Mrs. Lin body collision remains unchanged"
				)

	if current_scene == room:
		current_scene = null
	room.queue_free()
	await process_frame
	await process_frame


func _check_animated_npc(node: Node, expected_scale: Vector2, expected_position: Vector2, label: String) -> void:
	_expect(node != null, label + " exists")
	if node == null:
		return
	var sprite := node.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	_check_animated_sprite(sprite, expected_scale, expected_position, label)


func _check_animated_sprite(sprite: AnimatedSprite2D, expected_scale: Vector2, expected_position: Vector2, label: String) -> void:
	_expect(sprite != null, label + " sprite exists")
	if sprite == null:
		return
	_expect_vector(sprite.scale, expected_scale, label + " visual scale")
	_expect_vector(sprite.position, expected_position, label + " foot anchor")


func _expect_vector(actual: Vector2, expected: Vector2, description: String) -> void:
	_expect(actual.is_equal_approx(expected), "%s (expected %s, got %s)" % [description, expected, actual])


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	_fail(description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("character_scale_profiles_test: PASS")
		quit(0)
		return
	printerr("character_scale_profiles_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
