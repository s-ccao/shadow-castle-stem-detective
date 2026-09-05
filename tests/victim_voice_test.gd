extends SceneTree

## 林女士是死者。她不能开口。
##
## 原来大厅和苏醒室有二十多段对话把她挂成说话人，玩家一路被一个已经死了的
## 人指导破案。改成玩家的自语之后，这条不变量必须钉住：说话人一栏、行内的
## "某某：" 前缀，两种写法都会让她重新说话，而且两种都不会报错。
##
## 她**留下的**东西不在此列。信、实验笔记、温室记录是实物证据，读它们正是
## 这个游戏要教的事，和让尸体讲话是两回事。

const SOURCES: Array[String] = [
	"res://scripts/game_world.gd",
	"res://scripts/wake_room.gd",
	"res://scripts/case_script_zh.gd",
	"res://scenes/floor_1/chemistry_room.gd",
	"res://scripts/greenhouse_room.gd",
	"res://scripts/library_room.gd",
	"res://scripts/final_room.gd",
]

## 把她挂成说话人的两种写法。
const SPEAKER_PATTERNS: Array[String] = [
	"set_dialogue_speaker(\"Mrs. Lin\")",
	"set_dialogue_speaker(\"Dr. Lin\")",
	"show_dialogue(\"Mrs. Lin\"",
	"show_dialogue(\"Dr. Lin\"",
	"set_dialogue_text(\"Mrs. Lin\"",
	"set_dialogue_text(\"Dr. Lin\"",
	"show_message(\"Mrs. Lin\"",
	"Mrs. Lin:",
	"Dr. Lin:",
	"林女士：",
	"林博士：",
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var offenders: Array[String] = []
	var scanned := 0
	for path: String in SOURCES:
		if not FileAccess.file_exists(path):
			continue
		scanned += 1
		var source := FileAccess.get_file_as_string(path)
		for pattern: String in SPEAKER_PATTERNS:
			if source.contains(pattern):
				offenders.append("%s -> %s" % [path.get_file(), pattern])

	# 文件一个都没读到时下面的断言会凭空为真，所以先确认真的扫了东西。
	_expect(scanned >= 5, "The dialogue sources were actually read (%d)" % scanned)
	_expect(
		offenders.is_empty(),
		"The victim never speaks"
			+ ("" if offenders.is_empty() else " (%s)" % ", ".join(offenders))
	)

	# 她留下的文件是证据，必须留着——否则这条守卫会被"把 Lin 全删掉"满足。
	var evidence := false
	var hall := FileAccess.get_file_as_string("res://scripts/game_world.gd")
	for artefact: String in ["Mrs. Lin's Letter", "Mrs. Lin's Lab Notebook",
			"Mrs. Lin's Final Notebook", "Mrs. Lin's notebook"]:
		if hall.contains(artefact):
			evidence = true
	_expect(evidence, "What she left behind is still in the case as evidence")

	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("victim_voice_test: PASS")
		quit(0)
	else:
		printerr("victim_voice_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
