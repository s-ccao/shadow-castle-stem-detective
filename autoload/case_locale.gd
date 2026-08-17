extends Node

## CaseLocale keeps the player-facing language choice separate from a case save.
## The small Interface is intentionally limited to text lookup and preference changes;
## individual screens refresh themselves when locale_changed is emitted.

signal locale_changed(language: String)

const PREFERENCE_PATH := "user://shadow_castle_preferences.cfg"
const ENGLISH := "en"
const CHINESE := "zh"

var _language := ENGLISH

const TEXT: Dictionary = {
	"menu.new_case": {"en": "New Case", "zh": "新建案件"},
	"menu.continue": {"en": "Continue", "zh": "继续案件"},
	"menu.settings": {"en": "Settings", "zh": "设置"},
	"menu.language": {"en": "Language", "zh": "语言"},
	"menu.quit": {"en": "Quit", "zh": "退出"},
	"menu.close": {"en": "Close", "zh": "关闭"},
	"menu.settings_title": {"en": "SETTINGS", "zh": "设置"},
	"menu.settings_body": {
		"en": "Controls: WASD move · E interact · B evidence · O objectives.",
		"zh": "操作：WASD 移动 · E 交互 · B 证物 · O 目标。",
	},
	"menu.language_title": {"en": "CASE LANGUAGE", "zh": "案件语言"},
	"menu.language_body": {
		"en": "Choose the language used by the case files, interface, and dialogue.",
		"zh": "选择案件档案、界面与对话所使用的语言。",
	},
	"menu.case_opened": {"en": "CASE FILE OPENED", "zh": "案件档案已开启"},
	"menu.case_opened_detail": {
		"en": "The archive is waiting.",
		"zh": "档案室正在等候。",
	},
	"save.none": {"en": "AUTOSAVE · No active case", "zh": "自动存档 · 尚无进行中的案件"},
	"save.resume": {"en": "AUTOSAVE · Resume: {room}", "zh": "自动存档 · 从这里继续：{room}"},
	"room.wake_room": {"en": "Wake Room", "zh": "苏醒室"},
	"room.floor_1_hub": {"en": "Castle Hall", "zh": "城堡大厅"},
	"room.chemistry_room": {"en": "Chemistry Room", "zh": "化学室"},
	"room.greenhouse_room": {"en": "Greenhouse", "zh": "温室"},
	"room.circuit_room": {"en": "Circuit Room", "zh": "电路室"},
	"room.library": {"en": "Library", "zh": "图书馆"},
	"room.dining_hall": {"en": "Dining Hall", "zh": "餐厅"},
	"room.final_deduction_room": {"en": "Final Archive", "zh": "终局档案室"},
	"death.reason_title": {"en": "OBSERVATION LOST", "zh": "调查中断"},
	"death.reason_body": {
		"en": "The Guardian forced you from the trail. Your notes and evidence are safe.",
		"zh": "守卫迫使你离开现场。你的笔记与证物已被保留。",
	},
	"death.retry_room": {"en": "Retry Room", "zh": "重试当前房间"},
	"death.retry_checkpoint": {"en": "Retry Checkpoint", "zh": "从检查点重试"},
	"death.main_menu": {"en": "Return to Archive", "zh": "返回档案室"},
	"ending.continue": {"en": "Review Sealed Archives", "zh": "复查密封档案"},
	"ending.review": {"en": "Return to Analysis Table", "zh": "返回分析圆桌"},
	"ending.ordinary_record": {
		"en": "ORDINARY CASE RECORD\nThe Butler operated the apparatus — but who authored the order?",
		"zh": "普通案件记录\n管家操作了装置——但命令究竟来自谁？",
	},
	"ending.true_continue": {"en": "Return to Sealed Review", "zh": "返回密封复查"},
	"ending.true_review": {"en": "Review Full Case Chain", "zh": "查看完整案件链"},
	"ending.true_record": {
		"en": "TRUE CASE RECORD\nThe Mechanic forged the command, silenced Dr. Lin, and tried to claim her work.",
		"zh": "真相案件记录\n机械师伪造命令、令林博士沉默，并企图夺取她的成果。",
	},
	"ending.main_menu": {"en": "Return to Archive", "zh": "返回档案室"},
	"language.english": {"en": "English", "zh": "English"},
	"language.chinese": {"en": "中文", "zh": "中文"},
	# 知识锁：这是整个游戏的 STEM 教学核心，题干与选项跟着数据表走
	# （game_world.gd 的 DOOR_QUESTIONS / FINAL_SYNTHESIS_QUESTIONS），
	# 这里只放围绕它们的界面文字。
	"knowledge.lock_title": {"en": "Knowledge Lock:", "zh": "知识锁："},
	"knowledge.locked_title": {
		"en": "The key fits, but the knowledge lock is still sealed.",
		"zh": "钥匙对上了，但知识锁仍然紧闭。",
	},
	"knowledge.locked_body": {
		"en": (
			"Study the {room} exhibit in Castle Hall and save it to "
			+ "NoteHub before answering this question."
		),
		"zh": "请先在城堡大厅研究「{room}」展品并存入侦探笔记，再来回答这道题。",
	},
	"knowledge.correct": {
		"en": "Correct.\n\nThe knowledge lock accepts your answer.\n\nDoor opened.",
		"zh": "回答正确。\n\n知识锁接受了你的答案。\n\n门开了。",
	},
	"knowledge.wrong": {
		"en": (
			"Not quite.\n\nThe lock remains sealed. Think about the science "
			+ "behind the question and try again."
		),
		"zh": "还差一点。\n\n锁仍然没开。想一想题目背后的科学原理，再试一次。",
	},
	"knowledge.retry": {"en": "Try Again", "zh": "再试一次"},
	"knowledge.leave": {"en": "Leave the lock", "zh": "先离开这道锁"},
	"knowledge.continue": {"en": "Continue", "zh": "继续"},
	"knowledge.study_prompt": {
		"en": "Press E to study {target}",
		"zh": "按 E 研究{target}",
	},
	"knowledge.saved_to_notehub": {
		"en": "This knowledge has been added to NoteHub.",
		"zh": "这条知识已存入侦探笔记。",
	},
	"knowledge.synthesis_header": {
		"en": "Final Synthesis Lock — Question {index}/{total}:",
		"zh": "终局综合锁 —— 第 {index}/{total} 题：",
	},
	"knowledge.synthesis_wrong": {
		"en": (
			"That answer does not fit the evidence you have learned.\n\n"
			+ "Review the corresponding room Knowledge note and try again."
		),
		"zh": "这个答案跟你掌握的证据对不上。\n\n回去复习对应房间的知识笔记，再试一次。",
	},
}


func _ready() -> void:
	_language = _load_preference()


func language() -> String:
	return _language


func is_chinese() -> bool:
	return _language == CHINESE


func set_language(language_code: String) -> void:
	var normalized := _normalize(language_code)
	if normalized == _language:
		return
	_language = normalized
	_save_preference()
	locale_changed.emit(_language)


func toggle_language() -> void:
	set_language(CHINESE if _language == ENGLISH else ENGLISH)


func text(key: String, replacements: Dictionary = {}) -> String:
	var entry: Dictionary = TEXT.get(key, {})
	var value := str(entry.get(_language, entry.get(ENGLISH, key)))
	for replacement_key: Variant in replacements:
		value = value.replace(
			"{" + str(replacement_key) + "}",
			str(replacements[replacement_key])
		)
	return value


func room_name(room_id: String) -> String:
	return text("room." + room_id)


func _load_preference() -> String:
	var config := ConfigFile.new()
	if config.load(PREFERENCE_PATH) == OK:
		return _normalize(str(config.get_value("display", "language", "")))
	return _system_language()


func _save_preference() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "language", _language)
	config.save(PREFERENCE_PATH)


func _system_language() -> String:
	var locale := OS.get_locale().to_lower()
	return CHINESE if locale.begins_with("zh") else ENGLISH


func _normalize(language_code: String) -> String:
	return CHINESE if language_code.to_lower().begins_with("zh") else ENGLISH
