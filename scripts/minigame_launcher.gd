class_name MinigameLauncher
extends RefCounted

## 一行代码把小游戏挂进任意房间。
##
## 每个房间的交互框架各写各的（大厅走 match、图书馆和线路房走
## interaction_runtime、化学室又是另一套），但"生成面板 → 冻结房间输入 →
## 等结果 → 清理"这一段是完全一样的。放在这里，房间那边只剩一次调用，
## 也避免七个房间各自漏掉一处清理。

## 正在运行的小游戏，同一时间只允许一个。
static var _active: MinigameShell = null


static func is_busy() -> bool:
	return _active != null and is_instance_valid(_active)


## host 为房间节点；on_finished 收到 bool（是否全关通过）与已通关关卡数。
static func launch(
	host: Node,
	game: MinigameShell,
	title: String,
	subtitle: String,
	tint: Color,
	on_finished: Callable
) -> bool:
	if is_busy():
		return false
	_active = game
	game.configure(title, subtitle, tint)
	game.finished.connect(
		_on_finished.bind(host, game, on_finished), CONNECT_ONE_SHOT
	)
	host.add_child(game)
	game.start()
	return true


static func _on_finished(
	cleared_all: bool,
	host: Node,
	game: MinigameShell,
	on_finished: Callable
) -> void:
	var stages: int = game.levels_cleared()
	_active = null
	game.queue_free()
	# 房间可能在小游戏结束前就被切走了，回调前先确认它还活着。
	if is_instance_valid(host) and on_finished.is_valid():
		on_finished.call(cleared_all, stages)
