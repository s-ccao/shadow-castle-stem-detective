extends SceneTree

## Native in-game comparison for the HD dialogue portraits: opens each speaker's
## dialogue the game's own way (Mrs. Lin's letter in the Wake Room, the butler
## in the Chemistry Room, the gardener in the Greenhouse, and in the Hall the
## butler, the gardener, the mechanic and the Castle Guardian), in the painted
## look and in HD (tools/blender/prototype_portraits.gd, staged with the
## characters), and shoots both at 1024x768. It checks that the dialogue box
## shows the game's own pixel portrait, nearest-filtered; that staging HD swaps
## it at once for the speaker's HD portrait, drawn smoothly from its mipmaps,
## and that the screen inside the box changes; that opening the dialogue again
## while HD is staged gets the HD portrait from the scene's own load(); that
## restoring gives the pixel portrait and its filter back; and that every
## portrait portraits.json lists stands in for a real game portrait.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_portraits.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_chars/portraits/captures/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const DATA := "res://prototypes/blender_chars/portraits/"
const CHARACTER_DATA := "res://prototypes/blender_chars/"
const GAME := "res://assets/characters/portraits_pixel_v2/"
const Room := preload("res://tools/blender/prototype_room.gd")
const Characters := preload("res://tools/blender/prototype_characters.gd")
const Portraits := preload("res://tools/blender/prototype_portraits.gd")
const KEYS: Array[String] = [
	"wake_room_key", "chemistry_room_key", "greenhouse_room_key", "dining_hall_key",
]
const WAKE_FLAGS: Array[String] = [
	"wake_room_arrival_complete", "wake_orientation_completed", "wake_flame_drilled",
	"wake_room_desk_read",
]
## The speakers: who, the scene's own way to open their dialogue, and the game
## portrait it shows. No dialogue in the game names the Castle Guardian yet, so
## the Hall is given his name directly.
const _WAKE_LETTER := {
	"speaker": "Mrs. Lin's Letter", "open": "show_wake_dialogue", "portrait": "dr_lin.png",
}
const _BUTLER := {"speaker": "Butler", "open": "show_butler_dialogue", "portrait": "butler.png"}
const _GARDENER := {
	"speaker": "Gardener", "open": "show_gardener_dialogue", "portrait": "gardener.png",
}
const _MECHANIC := {
	"speaker": "Mechanic", "open": "show_mechanic_dialogue", "portrait": "mechanic.png",
}
const _GUARDIAN := {
	"speaker": "Castle Guardian", "open": "set_dialogue_speaker", "portrait": "castle_guardian.png",
}
## Each scene, its prototype room ("" for the Hall, whose characters are staged
## alone), and who speaks in it.
const SCENES: Array[Dictionary] = [
	{
		"scene": "res://scenes/wake_room.tscn", "room": "wake_room", "label": "wake",
		"speakers": [_WAKE_LETTER],
	},
	{
		"scene": "res://scenes/floor_1/chemistry_room.tscn", "room": "chemistry_room",
		"label": "chemistry", "speakers": [_BUTLER],
	},
	{
		"scene": "res://scenes/floor_1/greenhouse_room.tscn", "room": "greenhouse_room",
		"label": "greenhouse", "speakers": [_GARDENER],
	},
	{
		"scene": "res://scenes/game_world.tscn", "room": "", "label": "hall",
		"speakers": [_BUTLER, _GARDENER, _MECHANIC, _GUARDIAN],
	},
]
## Mean change (0..255) the screen inside the portrait box must show between
## the pixel portrait and the HD one.
const MIN_CHANGE := 12.0

var room: Node
var look: RefCounted
var failures: Array[String] = []
var checks := 0
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _physics_process(delta: float) -> bool:
	if look != null:
		look.call("track", delta)
	return false


func _process(delta: float) -> bool:
	if look != null and look.has_method("advance"):
		look.call("advance", delta)
	return false


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("capture_portraits needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(DATA + "captures/")
	_index_checks()
	for entry: Dictionary in SCENES:
		await _scene_checks(entry)
	_finish()


## Every HD portrait stands in for a real game portrait, at twice the box's size
## with mipmaps.
func _index_checks() -> void:
	var count := Portraits.attach(DATA)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "portraits.json"))
	var listed: Dictionary = index["portraits"]
	_expect(
		count == 5 and listed.size() == 5,
		"Five HD portraits load (%d of %d listed)" % [count, listed.size()]
	)
	for path: String in listed:
		var texture := Portraits.hd_for(path)
		var image := texture.get_image() if texture != null else null
		_expect(
			ResourceLoader.exists(path) and image != null
			and image.get_size() == Vector2i(Portraits.DISPLAY_PX, Portraits.DISPLAY_PX)
			and image.has_mipmaps(),
			"%s stands in for the game's %s, %d px with mipmaps" % [
				listed[path]["image"], path.get_file(), Portraits.DISPLAY_PX,
			]
		)


func _scene_checks(entry: Dictionary) -> void:
	var label := str(entry["label"])
	if str(entry["room"]).is_empty():
		await _enter_hall()
	else:
		await _enter_room(str(entry["scene"]))
	_expect(room != null, "The %s loads" % label)
	if room == null:
		return
	if str(entry["room"]).is_empty():
		look = Characters.new()
		look.call("attach", room, CHARACTER_DATA)
	else:
		look = Room.new()
		_expect(bool(look.call("attach", room, str(entry["room"]))), "The %s's HD look loads" % label)
	var box := room.get("avatar_portrait") as TextureRect
	_expect(box != null, "The %s has a dialogue portrait box" % label)
	if box == null:
		return
	await _clear_toasts()
	for speaker: Dictionary in entry["speakers"]:
		await _speaker_checks(label, box, speaker)
	look.call("restore")
	look = null
	room.queue_free()
	room = null
	current_scene = null
	await _wait(0.3)


func _speaker_checks(label: String, box: TextureRect, speaker: Dictionary) -> void:
	var who := str(speaker["speaker"])
	var path := GAME + str(speaker["portrait"])
	var hd := Portraits.hd_for(path)
	var file := "portrait-%s-%s" % [label, str(speaker["portrait"]).get_basename()]
	_open(speaker)
	await _wait(0.4)
	_expect(
		box.is_visible_in_tree() and box.texture != null and box.texture.resource_path == path
		and not (box.texture is ImageTexture) and box.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s: %s speaks with the game's own pixel portrait, nearest-filtered" % [label, who]
	)
	var painted := await _shot("current", file)
	look.call("apply")
	await _wait(0.4)
	_expect(
		hd != null and box.texture == hd
		and box.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"%s: staging HD shows %s's HD portrait at once, drawn from its mipmaps" % [label, who]
	)
	var staged := await _shot("blender", file)
	var change := _change(painted, staged, box.get_global_rect())
	_expect(
		change >= MIN_CHANGE,
		"%s: the screen inside %s's portrait box changes (%.1f)" % [label, who, change]
	)
	_open(speaker)
	await _wait(0.3)
	_expect(
		box.texture == hd and load(path) == hd,
		"%s: opened again in HD, the scene's own load() gives %s's HD portrait" % [label, who]
	)
	look.call("restore")
	await _wait(0.3)
	_expect(
		box.texture != null and box.texture.resource_path == path and not (box.texture is ImageTexture)
		and box.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and load(path) != hd,
		"%s: restoring gives %s's pixel portrait and its filter back" % [label, who]
	)
	if room.has_method("close_message_panel"):
		room.call("close_message_panel")
	await _wait(0.2)


func _open(speaker: Dictionary) -> void:
	var method := str(speaker["open"])
	if method == "set_dialogue_speaker":
		room.call(method, str(speaker["speaker"]))
		(room.get("message_panel") as Control).visible = true
	else:
		room.call(method)


## Mean absolute change (0..255) between two shots inside `rect`.
func _change(first: Image, second: Image, rect: Rect2) -> float:
	var total := 0.0
	var count := 0
	for y: int in range(int(rect.position.y), int(rect.end.y), 2):
		for x: int in range(int(rect.position.x), int(rect.end.x), 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			count += 1
	return 255.0 * total / maxf(float(count), 1.0)


func _start_game() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	for key: String in KEYS:
		gs.call("add_key", key)
	gs.set("learned_fire_oxygen_rule", true)
	gs.set("wake_room_door_unlocked", true)
	for flag: String in WAKE_FLAGS:
		gs.call("set_story_flag", flag)


func _enter_room(scene_path: String) -> void:
	_start_game()
	var scene := (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(0.8)
	room = scene


## The Hall as a player first steps out of the Wake Room into it, past its
## arrival dialogue and survival card.
func _enter_hall() -> void:
	_start_game()
	var wake := (load("res://scenes/wake_room.tscn") as PackedScene).instantiate()
	root.add_child(wake)
	current_scene = wake
	await _wait(0.3)
	wake.call("leave_wake_room")
	for _attempt: int in range(80):
		await _wait(0.1)
		if current_scene != null and current_scene.scene_file_path.ends_with("game_world.tscn"):
			room = current_scene
			break
	if room == null:
		return
	await _wait(0.6)
	var onboarding := root.get_node("OnboardingHud")
	for _attempt: int in range(160):
		if (onboarding.get("overlay") as Control).visible:
			break
		var panel := room.get("message_panel") as Control
		if panel != null and panel.visible:
			var proceed := room.get("dialogue_continue_button") as Button
			if proceed != null and proceed.visible:
				proceed.pressed.emit()
			else:
				for child: Node in (room.get("button_box") as Node).get_children():
					if child is Button and (child as Button).visible:
						(child as Button).pressed.emit()
						break
		await _wait(0.1)
	onboarding.call("_complete_orientation")
	await _wait(1.2)
	root.get_node("GameState").set("hall_arrival_seen", true)
	room.set("hall_arrival_step", 4)
	var enemy := room.get_node_or_null("CastleGuardian") as CharacterBody2D
	if enemy != null:
		enemy.set("catch_enabled", false)
		enemy.set_physics_process(false)


## The field kit's unlock cards: shots of the dialogue, not of the cards.
func _clear_toasts() -> void:
	for _round: int in range(3):
		await _wait(0.5)
		root.get_node("ItemRewardHud").call("dismiss_for_overlay")
		root.get_node("InventoryHud").call("_hide_feature_unlock")
		root.get_node("KeyHud").call("dismiss_unlock_toast")
	await _wait(0.4)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(variant: String, label: String) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var suffix := "-zh" if bool(root.get_node("CaseLocale").call("is_chinese")) else ""
	var directory := out_dir.path_join(variant)
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(
		image.get_size() == Vector2i(1024, 768),
		"Native 1024x768 capture: %s/%s" % [variant, label]
	)
	_expect(image.save_png(directory.path_join(label + suffix + ".png")) == OK, "Saved " + label)
	return image


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		printerr("FAIL ", message)


func _finish() -> void:
	if look != null:
		look.call("restore")
	print("PORTRAITS_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
