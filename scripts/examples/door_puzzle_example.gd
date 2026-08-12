extends Area2D

## ============================================================
## DoorPuzzleExample — 如何从任意门的 Area2D 调用 DoorPuzzleUI
##
## 用法：
##   1. 把本脚本挂到任何门/机关的 Area2D 节点上（或复制本文件的
##      逻辑到自己的门脚本里）。
##   2. 设置 door_id 对应的题目数据（question / options / correct）。
##   3. 玩家进入 Area2D 后按 E（interact）→ 打开全屏答题界面。
##   4. 答对 → 回调解锁；答错 → UI 内重试；退出/ESC → 回调 false。
##
## 模板完全可复用：每扇门只改 door_data 里的题目，不写死任何内容。
## ============================================================

@export var door_id: String = "door_vault"

var is_player_nearby := false

# 题目数据库：door_id -> {question, options, correct, hint}
# 示例数据（可删除，接入真实题目时替换）
var door_data: Dictionary = {
	"door_vault": {
		"question": "[center][b]What has keys but no locks?[/b][/center]",
		"options": ["A piano", "A map", "A clock", "A book"],
		"correct": 0,
	},
	"door_lab": {
		"question": "[center][b]Which element is the lightest in the periodic table?[/b][/center]",
		"options": ["Oxygen", "Hydrogen", "Helium", "Nitrogen"],
		"correct": 1,
	},
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and is_player_nearby:
		var data: Dictionary = door_data.get(door_id, {})
		if data.is_empty() or DoorPuzzleUI == null:
			return
		DoorPuzzleUI.open(
			data["question"],
			data["options"],
			data["correct"],
			func(is_correct: bool) -> void:
				_on_answered(is_correct)
		)


func _on_answered(is_correct: bool) -> void:
	if is_correct:
		# 答对 → 开门动画/音效/解锁
		unlock_door()
	else:
		# 退出答题 → 门保持锁定，不做任何事
		pass


func unlock_door() -> void:
	print("Door [", door_id, "] unlocked!")
	# TODO: 播放开门动画、音效、设置 GameState 标志等
