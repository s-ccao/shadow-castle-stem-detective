extends SceneTree

## 开发者模式要在每个房间都能开，而且一键通关必须和手动打通完全等价。
##
## F3 原来只绑在线路室里，其他房间按了没反应；而小游戏会把整棵树暂停，
## 所以按键入口还必须是 PROCESS_MODE_ALWAYS，否则面板一开就失灵——这两点
## 都在这里验。
##
## 一键通关最容易写错的地方是"看起来关掉了，但房间拿到的是没通关"：那样
## 奖励不发、剧情标志不置位，调试时反而更费事。所以这里断言的是房间实际
## 收到的那对参数，而不是面板有没有消失。

const GAMES: Array[String] = [
	"res://scripts/flame_air_minigame.gd",
	"res://scripts/change_sorting_minigame.gd",
	"res://scripts/elapsed_time_minigame.gd",
	"res://scripts/gear_train_minigame.gd",
	"res://scripts/moonlight_harvest_minigame.gd",
	"res://scripts/photosynthesis_minigame.gd",
]

var failures: Array[String] = []
var _reported_cleared: bool = false
var _reported_stages: int = -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.call("reset_new_game")
	game_state.set("_loading_save", false)
	game_state.set("game_started", true)

	await _check_toggle_is_global()
	await _check_toggle_reaches_real_rooms()
	for path: String in GAMES:
		await _check_dev_clear(path)
	await _check_button_hidden_when_off()

	game_state.set("developer_mode", false)
	_finish()


## 开关本身必须挂在 autoload 上，否则只有那一个房间按得动。
func _check_toggle_is_global() -> void:
	var dev := root.get_node_or_null("DevTools")
	_expect(dev != null, "DevTools autoload is registered")
	if dev == null:
		return
	_expect(
		(dev as Node).process_mode == Node.PROCESS_MODE_ALWAYS,
		"Developer hotkey still runs while a minigame pauses the tree"
	)

	var game_state := root.get_node("GameState")
	game_state.set("developer_mode", false)

	# 直接调 toggle_developer_mode() 只能证明那个函数好使，证明不了按键接对了。
	# 这里发的是真的按键事件，走完整条输入链路。
	await _press(int(dev.get("TOGGLE_KEY")))
	_expect(
		bool(game_state.get("developer_mode")),
		"The bound key turns developer mode on"
	)
	await _press(int(dev.get("TOGGLE_KEY")))
	_expect(
		not bool(game_state.get("developer_mode")),
		"The same key turns developer mode back off"
	)

	# 角标是这个开关唯一的屏上说明。它和实际绑定必须是同一个键，
	# 否则玩家照着角标按，按了没反应。
	var badge := (dev as Node).find_child("DeveloperBadge", true, false) as Label
	_expect(badge != null, "Developer badge exists")
	if badge != null:
		game_state.set("developer_mode", true)
		dev.call("_sync_badge")
		var key_name := OS.get_keycode_string(int(dev.get("TOGGLE_KEY")))
		_expect(
			badge.text.contains(key_name),
			"Badge names the key that is actually bound (badge='%s', key=%s)" % [
				badge.text, key_name
			]
		)
		game_state.set("developer_mode", false)

	# 数字键会被输入框吃掉，不能在打字时把开发者模式切掉。
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await process_frame
	await _press(int(dev.get("TOGGLE_KEY")))
	_expect(
		not bool(game_state.get("developer_mode")),
		"Typing the toggle key into a text field does not switch the mode"
	)
	field.queue_free()
	await process_frame


func _press(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode as Key
	down.physical_keycode = keycode as Key
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = keycode as Key
	up.physical_keycode = keycode as Key
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## 前一项只证明按键在"autoload + 小游戏"这种空场景里通得过。真实房间里
## 有自己的 _input/_unhandled_input，任何一处提前 set_input_as_handled()
## 都会把这一下吃掉，而那正是玩家实际所处的环境——所以要在真房间里按。
func _check_toggle_reaches_real_rooms() -> void:
	var rooms: Array[Array] = [
		["Hall", "res://scenes/game_world.tscn"],
		["Wake Room", "res://scenes/wake_room.tscn"],
		["Library", "res://scenes/floor_1/library_room.tscn"],
		["Greenhouse", "res://scenes/floor_1/greenhouse_room.tscn"],
	]
	var game_state := root.get_node("GameState")
	var dev := root.get_node_or_null("DevTools")
	if dev == null:
		return
	var key := int(dev.get("TOGGLE_KEY"))

	for entry: Array in rooms:
		var label: String = entry[0]
		var packed := load(entry[1]) as PackedScene
		# 场景加载失败会让下面的断言无声跳过，那是假绿。
		_expect(packed != null, "%s scene loads" % label)
		if packed == null:
			continue
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		for _frame: int in range(45):
			await process_frame

		game_state.set("developer_mode", false)
		await _press(key)
		_expect(
			bool(game_state.get("developer_mode")),
			"The toggle key reaches the player inside the %s" % label
		)
		await _press(key)
		_expect(
			not bool(game_state.get("developer_mode")),
			"The toggle key switches back off inside the %s" % label
		)

		scene.queue_free()
		for _frame: int in range(10):
			await process_frame


func _check_dev_clear(path: String) -> void:
	var game_state := root.get_node("GameState")
	game_state.set("developer_mode", true)

	var script := load(path) as GDScript
	_expect(script != null, "%s loads" % path.get_file())
	if script == null:
		return
	var game: Node = script.new()
	root.add_child(game)
	game.call("configure", "T", "S", Color.WHITE)
	game.call("start")
	await process_frame
	await process_frame

	var total: int = int(game.call("level_count"))
	_expect(total > 0, "%s reports its level count (%d)" % [path.get_file(), total])

	var button := _find_dev_button(game)
	_expect(
		button != null and button.visible,
		"%s shows the developer clear button" % path.get_file()
	)
	if button == null:
		game.queue_free()
		await process_frame
		return

	_reported_cleared = false
	_reported_stages = -1
	game.connect("finished", _on_finished)
	button.emit_signal("pressed")
	await process_frame
	# 房间是从 levels_cleared() 取关卡数的（见 MinigameLauncher），
	# finished 信号本身只带 cleared_all，所以这里按房间的取法读。
	_reported_stages = int(game.call("levels_cleared"))

	_expect(
		_reported_cleared,
		"%s reports a full clear to the room" % path.get_file()
	)
	# 房间按已通关关卡数发奖励，少一关就少一份奖励。
	_expect(
		_reported_stages == total,
		"%s credits every stage (%d of %d)" % [
			path.get_file(), _reported_stages, total
		]
	)
	game.queue_free()
	await process_frame


## 关掉开发者模式后按钮必须消失，否则正式构建里玩家能一键跳过全部教学。
func _check_button_hidden_when_off() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("developer_mode", false)

	var script := load(GAMES[0]) as GDScript
	var game: Node = script.new()
	root.add_child(game)
	game.call("configure", "T", "S", Color.WHITE)
	game.call("start")
	await process_frame
	await process_frame

	var button := _find_dev_button(game)
	_expect(
		button != null and not button.visible,
		"Developer clear button stays hidden for normal players"
	)

	# 开关是随时可切的，按钮要跟着变，而不是只在开面板那一刻判断一次。
	game_state.call("toggle_developer_mode")
	await process_frame
	button = _find_dev_button(game)
	_expect(
		button != null and button.visible,
		"Developer clear button appears when the mode is switched on mid-game"
	)

	game.queue_free()
	await process_frame


func _find_dev_button(game: Node) -> Button:
	var found: Button = null
	var stack: Array[Node] = [game]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var button := node as Button
		if button != null and button.name.contains("Dev"):
			return button
		for child: Node in node.get_children():
			stack.append(child)
	return found


func _on_finished(cleared_all: bool) -> void:
	_reported_cleared = cleared_all


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("developer_mode_test: PASS")
		quit(0)
	else:
		printerr("developer_mode_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
