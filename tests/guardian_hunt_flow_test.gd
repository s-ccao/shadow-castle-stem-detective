extends SceneTree

const CHASE_MODE: int = 1
const PATROL_MODE: int = 2

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	var map_hud := root.get_node_or_null("MapHud")
	_expect(game_state != null, "GameState autoload exists")
	_expect(map_hud != null, "MapHud autoload exists")
	if game_state == null or map_hud == null:
		_finish()
		return
	game_state.set("_loading_save", true)

	game_state.reset_new_game()
	game_state.game_started = true
	game_state.grant_wake_room_toolkit()
	game_state.add_key("wake_room_key")
	game_state.return_spawn_id = "wake_room_first_arrival"
	game_state.current_room_id = "floor_1_hub"

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
	_expect(_guardian_hunt_active(game_state), "Guardian hunt activates on first Hall arrival")
	_expect(_guardian_mode(game_state) == CHASE_MODE, "Guardian enters CHASE mode in Hall")
	_expect(bool(game_state.get("chase_mode")), "Legacy chase flag mirrors CHASE mode")
	if guardian != null:
		_expect(guardian.visible, "Guardian is visible from first Hall arrival")
	await process_frame
	await process_frame
	var inventory_feature := root.get_node_or_null("InventoryHud/InventoryFeatureUnlock") as Control
	var key_toast := root.get_node_or_null("KeyHud/KeyHubUnlockToast") as Control
	var reward_panel := root.get_node_or_null("ItemRewardHud/ItemRewardPanel") as Control
	_expect(inventory_feature == null or not inventory_feature.visible, "Pursuit dismisses the Bag unlock card")
	_expect(key_toast == null or not key_toast.visible, "Pursuit dismisses the Key unlock card")
	_expect(reward_panel == null or not reward_panel.visible, "Pursuit dismisses queued item rewards")
	if hall.has_method("start_investigation_from_intro"):
		hall.call("start_investigation_from_intro")
		await process_frame
		_expect(bool(hall.get("guardian_entry_sequence_active")), "Hall entry starts the Guardian close-up")
		_expect(hall.get_node_or_null("GuardianRevealCamera") != null, "Close-up temporarily owns a dedicated Camera2D")
		_expect(player != null and not player.is_physics_processing(), "Player input is held during the Guardian close-up")
		var reveal_minimap := map_hud.find_child("GuardianMiniMap", true, false) as Control
		_expect(reveal_minimap != null and not reveal_minimap.visible, "Guardian close-up hides minimap chrome")
		if guardian != null:
			var hall_constants := (hall.get_script() as GDScript).get_script_constant_map()
			_expect(not bool(guardian.get("catch_enabled")), "Guardian cannot catch the player during the reveal")
			_expect(bool(guardian.get("cinematic_hold")), "Guardian pauses before turning toward the player")
			_expect(
				guardian.global_position.distance_to(player.global_position) >= float(hall_constants["GUARDIAN_ENTRY_MIN_DISTANCE"]),
				"Guardian reveal starts safely away from the return doorway"
			)
		await create_timer(2.65).timeout
		_expect(not bool(hall.get("guardian_entry_sequence_active")), "Guardian close-up returns control to the player")
		_expect(hall.get_node_or_null("GuardianRevealCamera") == null, "Player follow camera resumes after the reveal")
		_expect(player != null and player.is_physics_processing(), "Player movement resumes after the reveal")
		var onboarding_hud := root.get_node_or_null("OnboardingHud")
		var orientation_overlay := (
			onboarding_hud.get_node_or_null("FieldOrientationOverlay") as Control
			if onboarding_hud != null
			else null
		)
		_expect(
			orientation_overlay != null and orientation_overlay.visible,
			"Hall escape controls appear after the Guardian close-up"
		)
		_expect(paused, "Hall escape controls freeze the chase until acknowledged")
		if onboarding_hud != null:
			onboarding_hud.call("_complete_orientation")
			await process_frame
		_expect(not paused, "Acknowledging Hall controls starts the chase")
		# The guided crossing is a scripted rehearsal: the Guardian is placed
		# relative to the player's progress along the route, cannot catch them,
		# and holds its distance rather than closing. That contract is covered by
		# guided_crossing_test. Everything below describes the ordinary hunt that
		# follows, so retire the tutorial before asserting against it.
		# Snapshot the markers' metadata, not the nodes: completing the step
		# frees them, and a saved reference would be a freed object by the time
		# the assertions below run.
		var guided_markers: Array = []
		for marker_node: Variant in (hall.get("hall_route_marker_nodes") as Array):
			var live := marker_node as Node2D
			if live == null:
				continue
			guided_markers.append({
				"kind": str(live.get_meta("route_kind", "")),
				"incoming": live.get_meta("incoming_direction", Vector2.ZERO) as Vector2,
				"outgoing": live.get_meta("outgoing_direction", Vector2.ZERO) as Vector2,
				"direction": live.get_meta("route_direction", Vector2.ZERO) as Vector2,
			})
		hall.call("_set_hall_arrival_step", 4)
		game_state.hall_arrival_seen = true
		if guardian != null:
			guardian.call("set_catch_enabled", true)
		await process_frame
		if guardian != null:
			_expect(bool(guardian.get("catch_enabled")), "Guardian contact becomes lethal after the reveal")
			# The close-up hands control back, but control is worthless if the
			# hunter never runs. Without this the pursuit reads as a countdown
			# beside a statue: the estimate refreshes and never falls.
			_expect(
				guardian.is_physics_processing(),
				"Guardian resumes physics after the reveal"
			)
			var chase_origin := guardian.global_position
			for _step: int in range(30):
				await physics_frame
			_expect(
				guardian.global_position.distance_to(chase_origin) > 8.0,
				"Guardian actually closes ground after the reveal"
			)
			# The readout must behave like a clock. Sampling an estimate on an
			# interval and snapping to it made the pursuit look static: the value
			# refreshed while never running down.
			if player != null:
				player.set_physics_process(false)
				var eta_before := float(hall.get("guardian_eta_seconds"))
				for _tick: int in range(45):
					hall.call("_update_guardian_countdown", 1.0 / 60.0)
					await physics_frame
				var eta_after := float(hall.get("guardian_eta_seconds"))
				_expect(
					eta_after < eta_before,
					"Contact estimate runs down while the Guardian closes (%.2f -> %.2f)" % [eta_before, eta_after]
				)
				player.set_physics_process(true)
		var countdown := hall.get("guardian_countdown_panel") as Panel
		_expect(countdown != null, "Guardian contact estimate panel exists")
		if countdown != null and guardian != null and player != null:
			# The readout is a warning, so it has to be on screen exactly while
			# there is something to warn about. It used to sit there for the whole
			# game, which carries no information about when to run.
			var resting_position := guardian.global_position
			guardian.set_physics_process(false)
			guardian.global_position = hall.call(
				"_nearest_guardian_walkable_position",
				player.global_position + Vector2(112.0, 0.0)
			) as Vector2
			hall.call("_update_guardian_countdown", 1.0)
			_expect(countdown.visible, "Contact estimate appears once the Guardian is closing")
			# A hub pauses the tree, so `_process` cannot retract this readout. It has
			# to withdraw on the pause notification itself, or it ghosts through the
			# hub backdrop and keeps showing a frozen time that is no longer true.
			hall.propagate_notification(Node.NOTIFICATION_PAUSED)
			_expect(not countdown.visible, "Contact estimate withdraws while a hub holds the world paused")
			hall.propagate_notification(Node.NOTIFICATION_UNPAUSED)
			_expect(countdown.visible, "Contact estimate returns when the hub closes and the chase resumes")
			var farthest_position := resting_position
			var farthest_eta := -1.0
			for patrol_point: Vector2 in _guardian_patrol_route(game_state):
				guardian.global_position = patrol_point
				var candidate_eta := float(hall.call("get_guardian_catch_eta"))
				if candidate_eta > farthest_eta:
					farthest_eta = candidate_eta
					farthest_position = patrol_point
			guardian.global_position = farthest_position
			# Hold the guided-crossing tether at neutral: this assertion is about
			# distance retiring the readout, not about tutorial pacing. The loop
			# below is synchronous, so `_process` cannot overwrite this.
			game_state.call("set_guardian_tutorial_pace", 1.0)
			# Recovery is rate-limited on purpose, so give it time to climb. It has
			# to climb at all: relief used to be priced below the countdown's own
			# tick, so the estimate sank to 00.0 and stayed there forever.
			for _settle: int in range(40):
				hall.call("_update_guardian_countdown", 0.5)
			_expect(
				not countdown.visible,
				"Contact estimate withdraws once the Guardian is no longer a live threat (measured %.2f, displayed %.2f)" % [
					farthest_eta,
					float(hall.get("guardian_eta_seconds")),
				]
			)
			guardian.global_position = resting_position
			game_state.call("update_guardian_hall_position", resting_position)
			guardian.set_physics_process(true)
		# The hall's real walls are collision polygons, not solid grid cells, so the
		# grid happily reports the outermost border as walkable. A corner pinned
		# there stands the Guardian in the dead strip behind the painted room.
		var guardian_start: Vector2 = hall.get("ENEMY_START_POSITION")
		_expect(
			(
				guardian_start.x >= 160.0
				and guardian_start.x <= 1760.0
				and guardian_start.y >= 160.0
				and guardian_start.y <= 1120.0
			),
			"Guardian starts inside the hall rather than against the map border (%s)" % guardian_start
		)
		if guardian != null:
			# The reveal freezes the Guardian so the camera can hold on it. Releasing
			# the catch flag but not the hold leaves a Guardian that is allowed to
			# catch you and physically unable to move, which reads as no hunt at all.
			_expect(
				not bool(guardian.get("cinematic_hold")),
				"Guardian is released from its cinematic hold once the reveal ends"
			)
			_expect(
				bool(guardian.get("catch_enabled")),
				"Guardian can catch the player once the reveal ends"
			)
		_expect(reveal_minimap != null and reveal_minimap.visible, "Live Guardian minimap returns with player control")
		var far_eta := float(hall.call("get_guardian_catch_eta"))
		_expect(far_eta > 0.0 and far_eta < INF, "Guardian contact estimate is finite and path-based")
		if guardian != null and player != null:
			var guardian_position_before_eta := guardian.global_position
			guardian.set_physics_process(false)
			guardian.global_position = hall.call(
				"_nearest_guardian_walkable_position",
				player.global_position + Vector2(112.0, 0.0)
			) as Vector2
			var near_eta := float(hall.call("get_guardian_catch_eta"))
			_expect(near_eta < far_eta, "Guardian contact estimate falls when the Guardian gets closer")
			hall.call("_update_guardian_countdown", 1.0)
			var eta_label := hall.get("guardian_countdown_value") as Label
			_expect(eta_label != null and eta_label.text.ends_with(" s"), "Guardian contact estimate refreshes on screen")
			guardian.global_position = guardian_position_before_eta
			game_state.call("update_guardian_hall_position", guardian_position_before_eta)
			guardian.set_physics_process(true)
		var route_markers: Array = guided_markers
		var corner_count := 0
		var diagonal_marker_count := 0
		for entry: Variant in route_markers:
			var marker: Dictionary = entry as Dictionary
			var route_kind: String = str(marker["kind"])
			if route_kind == "corner_90":
				corner_count += 1
				var incoming: Vector2 = marker["incoming"]
				var outgoing: Vector2 = marker["outgoing"]
				if not is_zero_approx(incoming.dot(outgoing)):
					diagonal_marker_count += 1
			elif route_kind == "straight" or route_kind == "destination":
				var direction: Vector2 = marker["direction"]
				if not (is_zero_approx(direction.x) != is_zero_approx(direction.y)):
					diagonal_marker_count += 1
		_expect(not route_markers.is_empty(), "First-arrival floor route renders guidance markers")
		_expect(corner_count > 0, "First-arrival floor route marks turns with explicit 90-degree corners")
		_expect(diagonal_marker_count == 0, "First-arrival floor route contains no diagonal arrows")
		var chemistry_exhibit := hall.get_node_or_null(
			"WallCollisions/KnowledgeExhibits/ChemistryRoomKnowledge"
		) as Node2D
		var arrival_step_before: int = int(hall.get("hall_arrival_step"))
		hall.set("hall_arrival_step", 2)
		var core_route := hall.call("_hall_route_copy") as Dictionary
		_expect(
			chemistry_exhibit != null
			and (core_route.get("target", Vector2.ZERO) as Vector2).is_equal_approx(
				chemistry_exhibit.global_position
			),
			"Tutorial route follows the player-authored Chemistry Knowledge position"
		)
		hall.set("hall_arrival_step", arrival_step_before)
		# From here the test is about the ordinary hunt, not the guided crossing.
		# The tutorial has its own guarantees (survivable at any pace, near-miss
		# at the door) covered by guardian_tutorial_chase_test; asserting the
		# lethal-contact rule against it would contradict that design.
		hall.call("_set_hall_arrival_step", 4)
		game_state.hall_arrival_seen = true
		await process_frame
	if guardian != null:
		_expect(guardian.is_physics_processing(), "Guardian physics runs during Hall chase")

	var patrol_route := _guardian_patrol_route(game_state)
	_expect(patrol_route.size() >= 12, "Guardian receives an A* validated Hall patrol loop")
	var invalid_patrol_points := 0
	for point: Vector2 in patrol_route:
		var occupied_by_guardian := (
			guardian != null
			and point.distance_to(guardian.global_position) <= 32.0
		)
		if (
			not occupied_by_guardian
			and not bool(hall.call("is_player_position_walkable", point))
		):
			invalid_patrol_points += 1
	_expect(invalid_patrol_points == 0, "Every Guardian patrol point is walkable")

	if guardian != null and player != null:
		var guardian_position_before_catch := guardian.global_position
		game_state.call(
			"save_room_checkpoint",
			"res://scenes/floor_1/chemistry_room.tscn",
			"chemistry_room",
			"chemistry_start"
		)
		game_state.player_health = 3
		guardian.set_physics_process(false)
		guardian.call("set_behavior", CHASE_MODE)
		guardian.call("set_catch_enabled", true)
		guardian.global_position = player.global_position
		guardian.call("check_player_collision")
		_expect(bool(hall.get("game_over")), "Guardian body contact opens the interruption state")
		_expect(int(game_state.player_health) == 0, "Guardian body contact is immediately fatal")
		await create_timer(2.65).timeout
		var death_screen := hall.get("game_over_screen_root") as Control
		_expect(death_screen != null and death_screen.visible, "Guardian capture shows checkpoint recovery UI")
		_expect(bool(game_state.call("load_room_checkpoint")), "Checkpoint recovery succeeds after Guardian capture")
		_expect(int(game_state.player_health) == 3, "Checkpoint recovery restores player health")
		_expect(_guardian_mode(game_state) == PATROL_MODE, "Checkpoint recovery keeps the Guardian patrolling the Hall")
		hall.set("game_over", false)
		if death_screen != null:
			death_screen.visible = false
		game_state.call("prepare_return_to_hub", "chemistry_door")
		guardian.global_position = guardian_position_before_catch
		game_state.call("update_guardian_hall_position", guardian_position_before_catch)
		guardian.call("set_behavior", CHASE_MODE)
		guardian.set_physics_process(true)
		player.set_physics_process(true)

	var hall_position_before := _guardian_position(game_state)
	game_state.prepare_room_transition(
		"chemistry_room",
		"res://scenes/game_world.tscn",
		"chemistry_door"
	)
	_expect(_guardian_mode(game_state) == PATROL_MODE, "Entering a room switches Guardian to PATROL")
	_expect(not bool(game_state.get("chase_mode")), "Room hiding disables direct chase pressure")

	if current_scene == hall:
		current_scene = null
	hall.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.75).timeout
	var hall_position_after := _guardian_position(game_state)
	_expect(
		hall_position_after.distance_to(hall_position_before) > 1.0,
		"Guardian patrol position advances while Hall scene is unloaded"
	)

	if map_hud.has_method("refresh_guardian_tracking"):
		map_hud.call("refresh_guardian_tracking")
	var minimap := map_hud.find_child("GuardianMiniMap", true, false) as Control
	var mini_guardian := map_hud.find_child("MiniGuardianMarker", true, false) as Control
	var full_guardian := map_hud.find_child("MapGuardianMarker", true, false) as Control
	_expect(minimap != null, "Persistent Guardian minimap exists")
	_expect(mini_guardian != null, "Minimap Guardian marker exists")
	_expect(full_guardian != null, "Full map Guardian marker exists")
	if minimap != null:
		_expect(minimap.visible, "Guardian minimap remains visible while player hides in a room")
	if mini_guardian != null:
		_expect(mini_guardian.visible, "Guardian marker is visible on minimap during patrol")

	game_state.prepare_return_to_hub("chemistry_door")
	_expect(_guardian_mode(game_state) == CHASE_MODE, "Returning to Hall restores CHASE mode")
	_expect(bool(game_state.get("chase_mode")), "Hall return restores direct chase pressure")
	game_state.player_health = 3
	var pursuit_is_fatal := bool(game_state.call("take_damage"))
	_expect(pursuit_is_fatal, "Guardian contact during CHASE triggers the interruption screen")
	_expect(int(game_state.player_health) == 0, "Guardian pursuit is a one-hit failure state")

	game_state.reset_new_game()
	paused = false
	_finish()


func _guardian_hunt_active(game_state: Node) -> bool:
	if not game_state.has_method("is_guardian_hunt_active"):
		return false
	return bool(game_state.call("is_guardian_hunt_active"))


func _guardian_mode(game_state: Node) -> int:
	if not game_state.has_method("get_guardian_mode"):
		return -1
	return int(game_state.call("get_guardian_mode"))


func _guardian_position(game_state: Node) -> Vector2:
	if not game_state.has_method("get_guardian_hall_position"):
		return Vector2.ZERO
	return game_state.call("get_guardian_hall_position") as Vector2


func _guardian_patrol_route(game_state: Node) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not game_state.has_method("get_guardian_patrol_route"):
		return route
	var raw_route: Variant = game_state.call("get_guardian_patrol_route")
	if raw_route is Array:
		for point: Variant in raw_route:
			if point is Vector2:
				route.append(point as Vector2)
	return route


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
		print("guardian_hunt_flow_test: PASS")
		quit(0)
		return
	printerr("guardian_hunt_flow_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)