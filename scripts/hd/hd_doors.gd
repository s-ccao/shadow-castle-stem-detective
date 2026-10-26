extends Node

## HD doors for the Hall. hall_prototype.py renders each Hall door's two
## leaves through an opening sequence and lists the sheets in render-doors.json
## (published under assets/hd/hall/): frame 0 shut, the last one open. The HD
## look lays each sheet over its doorway and plays it as the user asked:
## - walking up to a door that would let the player in leaves it ajar;
## - pressing E there swings it open, then the game goes through;
## - pressing E at a locked door rattles it, then the game says what it needs.
## The game's door logic stays in charge. While a door's prompt shows, the
## look holds E back from the game's polling, plays the door, then calls the
## game's own handler, exactly as E would have.

## The interaction ids the game uses for each door, and the story flag that
## unlocks it (the Wake Room door is always open).
const DOORS: Dictionary = {
	"Chemistry": {
		"ids": ["chemistry_room_door", "arrival_chemistry_door"], "flag": "door_chemistry_unlocked"
	},
	"Greenhouse": {"ids": ["greenhouse_room_door"], "flag": "door_greenhouse_unlocked"},
	"Library": {"ids": ["library_door"], "flag": "door_library_unlocked"},
	"Dining": {"ids": ["dining_hall_door"], "flag": "door_dining_unlocked"},
	"Final": {"ids": ["final_room_door"], "flag": "door_final_unlocked"},
	"Circuit": {"ids": ["circuit_door"], "flag": "door_circuit_unlocked"},
	"Wake": {"ids": ["wake_room_door"], "flag": ""},
}
## Frames a second as a door swings, and how long a rattle frame lasts.
const SWING_SPEED := 24.0
const RATTLE_STEP := 0.06
const RATTLE_TIMES := 3
## Above the Hall render (z -40); above the player (z 0) when they stand behind the door.
const BEHIND_Z := -39
const HDData := preload("res://scripts/hd/hd_data.gd")
const FRONT_Z := 9
const ACTION := "interact"

var hall: Node
var doors: Array[Dictionary] = []
var held_events: Array[InputEvent] = []
var holding := false
var active := false
## When set, a press plays the door but does not call the game (captures).
var dry_run := false
var last_handled := ""


## Loads every listed door under `hall_node`. Returns how many it can play.
func attach(hall_node: Node, path: String, data_dir: String, render_scale: float) -> int:
	hall = hall_node
	var data: Variant = HDData.json(path)
	if not (data is Dictionary):
		push_warning("No HD doors at " + path)
		return 0
	var halo := _halo_texture()
	for entry: Dictionary in (data as Dictionary).get("doors", []):
		var name_key := str(entry.get("name", ""))
		var texture := HDData.texture(data_dir + str(entry["image"]))
		if not DOORS.has(name_key) or texture == null:
			push_warning("Cannot play HD door " + name_key)
			continue
		var rect: Array = entry["rect"]
		var sprite := Sprite2D.new()
		sprite.name = "PrototypeDoor" + name_key
		sprite.texture = texture
		sprite.hframes = int(entry["frames"])
		sprite.centered = false
		sprite.position = Vector2(float(rect[0]), float(rect[1]))
		sprite.scale = Vector2.ONE / render_scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_as_relative = false
		sprite.z_index = BEHIND_Z
		sprite.visible = false
		hall.add_child(sprite)
		# Light from the room spills out as the door opens.
		var tint: Array = entry.get("glow", [1.0, 0.8, 0.5])
		var glow := Sprite2D.new()
		glow.texture = halo
		glow.material = CanvasItemMaterial.new()
		(glow.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.position = Vector2(float(entry["x"]), float(entry["line"]) - 12.0)
		glow.scale = Vector2.ONE * 64.0 / float(halo.get_width())
		glow.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), 0.0)
		glow.z_as_relative = false
		glow.z_index = BEHIND_Z
		glow.visible = false
		hall.add_child(glow)
		var spec: Dictionary = DOORS[name_key]
		doors.append({
			"name": name_key,
			"sprite": sprite,
			"glow": glow,
			"ids": spec["ids"],
			"flag": spec["flag"],
			"frames": int(entry["frames"]),
			"ajar": int(entry.get("ajar", 4)),
			"rattle": int(entry.get("rattle", 1)),
			"line": float(entry["line"]),
			"position": 0.0,
			"forced": -1,
			"press": "",
			"press_time": 0.0,
		})
	return doors.size()


## Shows the doors and starts playing them.
func apply() -> void:
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for door: Dictionary in doors:
		(door["sprite"] as Sprite2D).visible = true
		(door["glow"] as Sprite2D).visible = true
	_update(0.0)


## Hides the doors and gives E back to the game.
func restore() -> void:
	active = false
	_hold(false)
	for door: Dictionary in doors:
		door["press"] = ""
		door["position"] = 0.0
		if is_instance_valid(door["sprite"]):
			(door["sprite"] as Sprite2D).visible = false
			(door["glow"] as Sprite2D).visible = false


## Holds a door at `frame` (-1 lets it play again). For captures.
func force(name_key: String, frame: int) -> void:
	for door: Dictionary in doors:
		if door["name"] == name_key:
			door["forced"] = frame
			door["position"] = float(maxi(frame, 0))


## Plays E at the door named `name_key`, as if pressed there.
func press(name_key: String) -> void:
	for door: Dictionary in doors:
		if door["name"] == name_key and str(door["press"]).is_empty():
			door["press"] = "open" if _unlocked(door) else "rattle"
			door["press_time"] = 0.0


## The frame a door shows now.
func frame_of(name_key: String) -> int:
	for door: Dictionary in doors:
		if door["name"] == name_key:
			return (door["sprite"] as Sprite2D).frame
	return -1


func _process(delta: float) -> void:
	if active:
		_update(delta)


func _input(event: InputEvent) -> void:
	if not active or not holding or event.is_echo() or not event.is_pressed():
		return
	for held: InputEvent in held_events:
		if held.is_match(event):
			var door := _door_at_prompt()
			if not door.is_empty():
				press(str(door["name"]))
				get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	_hold(false)


func _update(delta: float) -> void:
	if not is_instance_valid(hall):
		return
	if get_tree().paused:
		_hold(false)
		return
	var player := hall.get_node_or_null("player") as Node2D
	var at_prompt := str(_door_at_prompt().get("name", ""))
	var pressing := false
	var handed_over := false
	for door: Dictionary in doors:
		var sprite := door["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue
		var last := int(door["frames"]) - 1
		var position := float(door["position"])
		var press_kind := str(door["press"])
		if press_kind == "rattle":
			door["press_time"] = float(door["press_time"]) + delta
			var step := int(float(door["press_time"]) / RATTLE_STEP)
			position = float(door["rattle"]) if step % 2 == 0 else 0.0
			if step >= RATTLE_TIMES * 2:
				position = 0.0
				_finish_press(door)
				handed_over = true
			else:
				pressing = true
		elif press_kind == "open":
			position = minf(position + SWING_SPEED * delta, float(last))
			if position >= float(last):
				door["press_time"] = float(door["press_time"]) + delta
			# A beat with the door open before the game goes through.
			if float(door["press_time"]) >= 0.12:
				_finish_press(door)
				handed_over = true
			else:
				pressing = true
		else:
			var target := 0.0
			if int(door["forced"]) >= 0:
				target = float(door["forced"])
			elif door["name"] == at_prompt and _unlocked(door):
				target = float(door["ajar"])
			position = move_toward(position, target, SWING_SPEED * delta)
		door["position"] = position
		sprite.frame = clampi(roundi(position), 0, last)
		var behind := player != null and player.global_position.y <= float(door["line"])
		sprite.z_index = FRONT_Z if behind else BEHIND_Z
		var glow := door["glow"] as Sprite2D
		glow.modulate.a = 0.42 * clampf(position / float(last), 0.0, 1.0)
	# Once a door hands E back, the game keeps it until its prompt shows again.
	_hold(pressing or (not handed_over and not at_prompt.is_empty()))


func _finish_press(door: Dictionary) -> void:
	var interaction := _interaction_of(door)
	door["press"] = ""
	door["press_time"] = 0.0
	# E goes back to the game first: what follows may be a message it closes.
	_hold(false)
	last_handled = str(door["name"])
	if dry_run or not is_instance_valid(hall) or interaction.is_empty():
		return
	hall.set("current_interaction", interaction)
	hall.call("try_investigate_clue")


## The door whose prompt the game shows now, if any.
func _door_at_prompt() -> Dictionary:
	if not is_instance_valid(hall):
		return {}
	var label := hall.get("interact_label") as CanvasItem
	if label == null or not label.visible:
		return {}
	var current := str(hall.get("current_interaction"))
	for door: Dictionary in doors:
		if current in (door["ids"] as Array):
			return door
	return {}


func _interaction_of(door: Dictionary) -> String:
	var current := str(hall.get("current_interaction")) if is_instance_valid(hall) else ""
	if current in (door["ids"] as Array):
		return current
	return str((door["ids"] as Array)[0])


func _unlocked(door: Dictionary) -> bool:
	var flag := str(door["flag"])
	if flag.is_empty():
		return true
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return false
	if bool(state.call("has_story_flag", flag)):
		return true
	if door["name"] != "Circuit" or not is_instance_valid(hall):
		return false
	# The Circuit door has an older way of standing open too.
	return bool(hall.get("circuit_door_open"))


## Keeps E from the game's polling while a door is at the prompt or moving.
func _hold(want: bool) -> void:
	if want == holding or not InputMap.has_action(ACTION):
		return
	if want:
		held_events = InputMap.action_get_events(ACTION)
		InputMap.action_erase_events(ACTION)
	else:
		for event: InputEvent in held_events:
			InputMap.action_add_event(ACTION, event)
		held_events.clear()
	holding = want


func _halo_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.5))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
