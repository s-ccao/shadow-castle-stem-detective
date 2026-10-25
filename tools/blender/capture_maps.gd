extends SceneTree

## Native check of the Map Hub's HD maps (tools/blender/prototype_map.gd): the
## Blender Hall from straight above in the map panel and the Guardian's
## minimap, and the Circuit Room's HD render as its repair map. Starts a game
## in the Circuit Room with the map hub and the repair map unlocked, stages its
## HD look, and opens each map in the painted look and in HD. It checks the
## panel, the minimap and the repair map's board hold the game's own textures
## in the painted look and the HD maps (drawn smoothly) in HD, that the screen
## inside each changes between the two, that a repair map built while HD shows
## gets its HD board too, and that restoring gives every map back. The shots
## leave the map's fog off so the whole map shows.
##
##   HOME="$PWD/.godot/blender-proto-capture/home" godot --path . \
##     --script res://tools/blender/capture_maps.gd [-- --zh]
##
## Needs a native display (not --headless) and a project-local isolated HOME.
## Writes prototypes/blender_hall/captures/maps/{current,blender}/.

const HOME_MARKER := "res://.godot/blender-proto-capture"
const OUT := "res://prototypes/blender_hall/captures/maps/"
const ROOM_SCENE := "res://scenes/floor_1/circuit_room.tscn"
const HALL_TEXTURE := "res://assets/backgrounds/hall_map_hub.png"
const CIRCUIT_TEXTURE := "res://assets/backgrounds/circuit_room_workshop.png"
const Room := preload("res://tools/blender/prototype_room.gd")
const Maps := preload("res://tools/blender/prototype_map.gd")
const KEYS: Array[String] = [
	"wake_room_key", "chemistry_room_key", "greenhouse_room_key", "circuit_room_key",
]
## map_hud.gd's map panel and the repair map's board, on screen.
const MAP_PANEL := Rect2(36.0, 94.0, 720.0, 540.0)
const REPAIR_BOARD := Rect2(194.0, 120.0, 636.0, 478.0)
## The least mean change (of 255) inside a map that shows it was redrawn.
const MIN_CHANGE := 10.0

var room: Node
var look: Room
var hud: Node
var failures: Array[String] = []
var checks := 0
var out_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1024, 768)
	call_deferred("_run")


func _physics_process(delta: float) -> bool:
	if look != null:
		look.track(delta)
	return false


func _process(delta: float) -> bool:
	if look != null:
		look.advance(delta)
	return false


func _run() -> void:
	var isolated_home := OS.get_environment("HOME").simplify_path()
	if DisplayServer.get_name() == "headless" \
			or not isolated_home.begins_with(ProjectSettings.globalize_path(HOME_MARKER)) \
			or not OS.get_user_data_dir().begins_with(isolated_home + "/"):
		printerr("capture_maps needs a native display and HOME under " + HOME_MARKER)
		quit(2)
		return
	var chinese := "--zh" in OS.get_cmdline_user_args()
	root.get_node("CaseLocale").call("set_language", "zh" if chinese else "en")
	out_dir = ProjectSettings.globalize_path(OUT)
	_expect(Maps.attach() == 2, "Both HD maps load (the Hall's and the Circuit Room's)")
	_expect(
		Maps.hall_map != null and Maps.hall_map.get_size() == Vector2(1448, 1086),
		"The HD Hall map is the game map's size (1448x1086)"
	)
	_expect(
		Maps.circuit_map != null and Maps.circuit_map.get_size() == Vector2(1448, 1086),
		"The HD repair map is the painted room's size (1448x1086)"
	)
	await _enter_room()
	hud = root.get_node("MapHud")
	look = Room.new()
	_expect(look.attach(room, "circuit_room"), "The Circuit Room's HD look attaches")
	await _clear_toasts()
	var panel := hud.get("map_texture_rect") as TextureRect
	var minimap := hud.find_child("GuardianMiniMapTexture", true, false) as TextureRect
	# The painted look first: the game's own maps.
	look.restore()
	await _wait(0.2)
	_expect(_is_game(panel, HALL_TEXTURE), "Painted look: the map panel shows the game's Hall map")
	_expect(_is_game(minimap, HALL_TEXTURE), "Painted look: the minimap shows the game's Hall map")
	var painted_map := await _map_shot("current", "01-map")
	var painted_repair := await _repair_shot("current", "02-repair-map")
	var board := _board()
	_expect(
		_is_game(board, CIRCUIT_TEXTURE), "Painted look: the repair map shows the painted workshop"
	)
	# The HD look: the Blender maps, drawn smoothly.
	look.apply()
	await _wait(0.2)
	_expect(panel.texture == Maps.hall_map, "HD look: the map panel shows the Blender Hall map")
	_expect(minimap.texture == Maps.hall_map, "HD look: the minimap shows the Blender Hall map")
	_expect(
		panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"HD look: the map panel draws its map smoothly, with mipmaps"
	)
	_expect(
		board.texture == Maps.circuit_map, "HD look: the repair map shows the Circuit Room's HD render"
	)
	var hd_map := await _map_shot("blender", "01-map")
	var hd_repair := await _repair_shot("blender", "02-repair-map")
	var change := _change(painted_map, hd_map, MAP_PANEL)
	_expect(change >= MIN_CHANGE, "The map panel is redrawn in HD (mean change %.1f of 255)" % change)
	change = _change(painted_repair, hd_repair, REPAIR_BOARD)
	_expect(change >= MIN_CHANGE, "The repair map is redrawn in HD (mean change %.1f of 255)" % change)
	# Restoring gives every map back, its filter too.
	look.restore()
	await _wait(0.2)
	_expect(
		_is_game(panel, HALL_TEXTURE) and _is_game(minimap, HALL_TEXTURE)
		and _is_game(board, CIRCUIT_TEXTURE),
		"Restoring gives the panel, the minimap and the repair map their own textures back"
	)
	_expect(
		panel.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE,
		"Restoring gives the map panel its own filter back"
	)
	look.apply()
	await _wait(0.2)
	_expect(board.texture == Maps.circuit_map, "Staging again shows the HD repair map again")
	_finish()


## Opens the Map Hub with its fog off and shoots it.
func _map_shot(variant: String, label: String) -> Image:
	hud.call("open_map")
	await _wait(0.6)
	var fog := hud.get("fog_texture_rect") as CanvasItem
	var fog_shown := fog.visible
	fog.visible = false
	await _wait(0.1)
	var image := await _shot(variant, label)
	fog.visible = fog_shown
	hud.call("close_map")
	await _wait(0.3)
	return image


func _repair_shot(variant: String, label: String) -> Image:
	hud.call("show_repair_map")
	await _wait(0.6)
	var image := await _shot(variant, label)
	hud.call("close_repair_map")
	await _wait(0.3)
	return image


## The repair map's board, once its overlay is built.
func _board() -> TextureRect:
	var overlay := hud.get("repair_overlay") as Control
	if overlay == null:
		return null
	for node: Node in overlay.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect.size == REPAIR_BOARD.size:
			return rect
	return null


func _is_game(rect: TextureRect, path: String) -> bool:
	return rect != null and rect.texture != null and rect.texture.resource_path == path


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


func _enter_room() -> void:
	var gs := root.get_node("GameState")
	gs.set("_loading_save", true)
	gs.call("reset_new_game")
	gs.set("_loading_save", false)
	gs.call("mark_game_started")
	gs.call("grant_wake_room_toolkit")
	for key: String in KEYS:
		gs.call("add_key", key)
	gs.call("unlock_map_hub")
	gs.call("add_map", "circuit_repair_map")
	var scene := (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(0.8)
	room = scene


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
		look.restore()
	print("MAPS_CAPTURE %d checks, %d failed -> %s" % [checks, failures.size(), out_dir])
	quit(1 if not failures.is_empty() else 0)
