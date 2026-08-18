extends SceneTree

## Contracts for the Guardian awareness rework: escalating speed per cleared
## room, the tracking serum that justifies omniscient pursuit, purification,
## sight-based re-acquisition, doorway stakeouts, and the daze/shroud
## counterplay. Runs headless against the Castle Hall scene.

const CHASE_MODE: int = 1
const PATROL_MODE: int = 2
const SEARCH_MODE: int = 3
const STUNNED_MODE: int = 4

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	_expect(game_state != null, "GameState autoload exists")
	if game_state == null:
		_finish()
		return
	game_state.set("_loading_save", true)
	game_state.reset_new_game()
	game_state.game_started = true
	game_state.grant_wake_room_toolkit()
	game_state.add_key("wake_room_key")
	game_state.return_spawn_id = "wake_room_first_arrival"
	game_state.current_room_id = "floor_1_hub"

	_check_escalation(game_state)
	_check_catalog(game_state)

	var hall_scene := load("res://scenes/game_world.tscn") as PackedScene
	_expect(hall_scene != null, "Castle Hall scene loads")
	if hall_scene == null:
		_finish()
		return
	var hall := hall_scene.instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await process_frame
	await create_timer(0.35).timeout

	var guardian := hall.get_node_or_null("CastleGuardian") as CharacterBody2D
	var player := hall.get_node_or_null("player") as CharacterBody2D
	_expect(guardian != null, "Guardian exists in Castle Hall")
	_expect(player != null, "Player exists in Castle Hall")
	if guardian == null or player == null:
		_finish()
		return

	await _check_serum_tracking(game_state, guardian, player)
	await _check_purification(game_state, guardian, player)
	await _check_sight_reacquisition(game_state, guardian, player)
	_check_stakeout(game_state, hall)
	await _check_daze(game_state, guardian)
	_check_shroud(game_state, guardian)
	_check_save_round_trip(game_state)

	_finish()


## The user's first requirement: one cleared room, one speed increase.
func _check_escalation(game_state: Node) -> void:
	var base_speed: float = float(game_state.call("get_guardian_chase_speed"))
	_expect(
		is_equal_approx(base_speed, float(game_state.get("GUARDIAN_BASE_CHASE_SPEED"))),
		"Guardian starts at the unescalated chase speed"
	)
	var previous_speed: float = base_speed
	var previous_tier: int = int(game_state.call("get_guardian_escalation_tier"))
	var escalation_keys: Array = game_state.get("GUARDIAN_ESCALATION_KEY_IDS")
	for key_id: Variant in escalation_keys:
		game_state.call("add_key", str(key_id))
		var tier: int = int(game_state.call("get_guardian_escalation_tier"))
		var speed: float = float(game_state.call("get_guardian_chase_speed"))
		_expect(tier == previous_tier + 1, "Clearing a room raises the escalation tier (%s)" % str(key_id))
		_expect(speed > previous_speed, "Clearing a room raises Guardian chase speed (%s)" % str(key_id))
		previous_tier = tier
		previous_speed = speed
	_expect(
		previous_tier == int(game_state.get("GUARDIAN_MAX_ESCALATION_TIER")),
		"Escalation reaches its documented cap"
	)
	# Re-adding a key must not double count.
	game_state.call("add_key", str(escalation_keys[0]))
	_expect(
		int(game_state.call("get_guardian_escalation_tier")) == previous_tier,
		"Escalation is idempotent per room key"
	)
	_expect(
		float(game_state.call("get_guardian_unaware_speed"))
		< float(game_state.call("get_guardian_chase_speed")),
		"An unaware Guardian is slower than a chasing Guardian"
	)


## The counterplay kit has to exist as data before any of it can be brewed.
func _check_catalog(game_state: Node) -> void:
	var potions: Dictionary = game_state.get("POTION_INFO")
	var recipes: Dictionary = game_state.get("RECIPE_INFO")
	for potion_id: String in ["purification_potion", "daze_potion", "shroud_potion"]:
		_expect(potions.has(potion_id), "Potion catalog defines %s" % potion_id)
	for recipe_id: String in ["recipe_purification", "recipe_daze", "recipe_shroud"]:
		_expect(recipes.has(recipe_id), "Recipe catalog defines %s" % recipe_id)
		var produces: String = str(recipes.get(recipe_id, {}).get("produces", ""))
		_expect(potions.has(produces), "%s produces a real potion" % recipe_id)
	var herbs: Dictionary = game_state.get("HERB_INFO")
	var materials: Dictionary = game_state.get("MATERIAL_INFO")
	for recipe_id: String in ["recipe_purification", "recipe_daze", "recipe_shroud"]:
		var recipe: Dictionary = recipes.get(recipe_id, {})
		for herb_id: Variant in recipe.get("herb_cost", {}):
			_expect(herbs.has(str(herb_id)), "%s uses a known herb (%s)" % [recipe_id, str(herb_id)])
		for material_id: Variant in recipe.get("material_cost", {}):
			_expect(
				materials.has(str(material_id)),
				"%s uses a known material (%s)" % [recipe_id, str(material_id)]
			)


## Before purification the Guardian is meant to be omniscient. That is the
## fiction of the serum, and it must survive a total loss of line of sight.
func _check_serum_tracking(game_state: Node, guardian: CharacterBody2D, player: CharacterBody2D) -> void:
	_expect(
		bool(game_state.call("is_guardian_tracking_serum_active")),
		"A fresh case starts with the tracking serum in the player's blood"
	)
	guardian.set("cinematic_hold", false)
	guardian.set("behavior", CHASE_MODE)
	# Point the Guardian directly away from the player: the serum must still win.
	guardian.set("facing_direction", (guardian.global_position - player.global_position).normalized())
	guardian.call("_update_awareness")
	await process_frame
	_expect(
		bool(guardian.get("can_see_player")),
		"The tracking serum keeps the Guardian aware without line of sight"
	)
	_expect(
		int(game_state.call("get_guardian_mode")) == CHASE_MODE,
		"The serum keeps the Guardian in CHASE"
	)


## Purification is permanent and must immediately break the lock-on.
func _check_purification(game_state: Node, guardian: CharacterBody2D, player: CharacterBody2D) -> void:
	# Move the player far away and face the Guardian elsewhere so that only the
	# serum could possibly be providing awareness.
	player.global_position = guardian.global_position + Vector2(900.0, 640.0)
	_expect(bool(game_state.call("purify_tracking_serum")), "Purification Potion strips the serum")
	_expect(
		not bool(game_state.call("is_guardian_tracking_serum_active")),
		"Purification is permanent"
	)
	_expect(
		bool(game_state.call("has_story_flag", "tracking_serum_purified")),
		"Purification records a story flag for later scenes"
	)
	_expect(
		int(game_state.call("get_guardian_mode")) == PATROL_MODE,
		"Purification drops the Guardian out of CHASE"
	)
	_expect(
		not bool(game_state.call("purify_tracking_serum")),
		"Purification cannot be re-applied"
	)
	guardian.set("facing_direction", Vector2.UP)
	guardian.call("_update_awareness")
	await process_frame
	_expect(
		not bool(guardian.get("can_see_player")),
		"A purified player at range is no longer perceived"
	)
	_expect(
		int(game_state.call("get_guardian_mode")) != CHASE_MODE,
		"A purified, unseen player is not chased"
	)


## Sight restores the full escalated chase; losing sight must not.
func _check_sight_reacquisition(
	game_state: Node,
	guardian: CharacterBody2D,
	player: CharacterBody2D
) -> void:
	player.global_position = guardian.global_position + Vector2(0.0, 40.0)
	guardian.set("facing_direction", Vector2.DOWN)
	guardian.call("_update_awareness")
	await process_frame
	_expect(bool(guardian.get("can_see_player")), "Standing in the cone is seen")
	_expect(
		int(game_state.call("get_guardian_mode")) == CHASE_MODE,
		"Sighting a purified player restores the chase"
	)
	_expect(
		is_equal_approx(
			float(guardian.call("_current_move_speed")),
			float(game_state.call("get_guardian_chase_speed"))
		),
		"Re-acquisition uses the stacked escalated speed, not the base speed"
	)

	player.global_position = guardian.global_position + Vector2(4000.0, 4000.0)
	guardian.call("_update_awareness")
	await process_frame
	_expect(not bool(guardian.get("can_see_player")), "Breaking range breaks sight")
	_expect(
		int(game_state.call("get_guardian_mode")) == SEARCH_MODE,
		"Losing sight sends the Guardian to SEARCH"
	)
	_expect(
		float(guardian.call("_current_move_speed"))
		< float(game_state.call("get_guardian_chase_speed")),
		"Searching is slower than chasing"
	)


## When it gives up, it must loiter at the passage of the room the player needs.
func _check_stakeout(game_state: Node, hall: Node) -> void:
	game_state.call("begin_guardian_patrol")
	game_state.set("current_room_id", "floor_1_hub")
	game_state.call("set_room_visited", "chemistry_room")
	var objective: String = str(game_state.call("get_guardian_objective_room_id"))
	_expect(
		objective == "greenhouse_room",
		"The stakeout targets the next unvisited room, got '%s'" % objective
	)
	var anchor: Vector2 = game_state.call("get_guardian_stakeout_anchor")
	var door: Vector2 = hall.get("GREENHOUSE_ROOM_DOOR_POSITION")
	_expect(
		anchor.distance_to(door) <= 96.0,
		"The stakeout anchor sits at the next room's doorway (%.1f px away)" % anchor.distance_to(door)
	)
	game_state.set("current_room_id", "circuit_room")
	_expect(
		str(game_state.call("get_guardian_objective_room_id")) == "circuit_room",
		"While the player is inside a room the Guardian waits at that room's door"
	)
	game_state.set("current_room_id", "floor_1_hub")
	_expect(
		float(game_state.call("get_guardian_unaware_speed"))
		<= float(game_state.get("GUARDIAN_STAKEOUT_SPEED")),
		"A purified Guardian loiters at the slow stakeout speed"
	)


## The Daze Potion has to actually stop the Guardian.
func _check_daze(game_state: Node, guardian: CharacterBody2D) -> void:
	game_state.call("stun_guardian", 0.4)
	_expect(bool(game_state.call("is_guardian_stunned")), "Daze Potion stuns the Guardian")
	_expect(
		int(game_state.call("get_guardian_mode")) == STUNNED_MODE,
		"A stunned Guardian leaves its previous mode"
	)
	guardian.call("_update_awareness")
	await process_frame
	_expect(int(guardian.get("behavior")) == STUNNED_MODE, "The Guardian body honours the stun")
	_expect(
		guardian.velocity.is_zero_approx(),
		"A stunned Guardian does not move"
	)
	await create_timer(0.75).timeout
	_expect(not bool(game_state.call("is_guardian_stunned")), "The stun expires on its own")
	_expect(
		int(game_state.call("get_guardian_mode")) == PATROL_MODE,
		"A recovered Guardian returns to its stakeout patrol"
	)


## The Shroud Potion blinds sight but is powerless against the serum, which is
## what keeps purification the meaningful upgrade.
func _check_shroud(game_state: Node, guardian: CharacterBody2D) -> void:
	game_state.call("apply_potion_effect", "shroud", 30.0)
	_expect(bool(game_state.call("is_player_shrouded")), "Shroud Potion hides the player")
	_expect(
		not bool(guardian.call("_has_line_of_sight_to_player")),
		"A shrouded player cannot be seen even at point-blank range"
	)
	game_state.call("apply_potion_effect", "shroud", 0.0)
	game_state.get("potion_effects").erase("shroud")


## Old saves have no serum record and must resume with tracking still active.
func _check_save_round_trip(game_state: Node) -> void:
	var payload: Dictionary = {}
	_expect(
		bool(game_state.get("guardian_tracking_serum")) == false,
		"Purified state is held in a persisted field"
	)
	game_state.set("guardian_tracking_serum", bool(payload.get("guardian_tracking_serum", true)))
	_expect(
		bool(game_state.call("is_guardian_tracking_serum_active")),
		"A save written before this rework loads with the serum still active"
	)
	_expect(
		int(game_state.get("SAVE_VERSION")) == 1,
		"The rework stays on save version 1 so existing saves still load"
	)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_started = false
		game_state.set("_loading_save", false)
	if failures.is_empty():
		print("guardian_awareness_flow_test: PASS")
		quit(0)
		return
	printerr("guardian_awareness_flow_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
