class_name SaveSlots
extends RefCounted

## 存档快照库。
##
## 这个游戏原本只有一个自动存档位，而“开始新案件”会直接把它删掉——没有确认、
## 没有备份，上一轮的进度当场消失。这里在那条路上补一层：每次抵达新房间留一
## 张快照，开新档之前也留一张，玩家因此永远能翻回去。
##
## 快照就是自动存档文件的整份拷贝，不额外维护索引：索引会和真实存档漂移，而
## 存档本身已经带着复盘所需的全部字段。列表里的信息一律从快照自己身上读。

const SLOT_DIR: String = "user://saves/"
const SLOT_PREFIX: String = "slot_"
const SLOT_SUFFIX: String = ".json"

## 上限是为了不让 user:// 无限膨胀，同时留得足够多，玩家不会因为多走了几个
## 房间就丢掉开局的那张。超出后只淘汰最旧的一张。
const MAX_SLOTS: int = 24

const REASON_CHECKPOINT: String = "checkpoint"
const REASON_NEW_CASE: String = "new_case"
const REASON_CLOUD: String = "cloud_replaced"


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SLOT_DIR):
		DirAccess.make_dir_recursive_absolute(SLOT_DIR)


## 把当前自动存档另存为一张快照。source_path 为空或读不出合法存档时什么都不做，
## 这样调用方不必先自己判断有没有档。
static func capture(source_path: String, reason: String = REASON_CHECKPOINT) -> bool:
	var payload: Dictionary = _read_json(source_path)
	if payload.is_empty():
		return false

	ensure_dir()
	var existing: Array[Dictionary] = list()

	# 同一个房间、同样的证据与知识数量，说明玩家还停在原地，再存一张只是把
	# 有用的旧快照挤出上限。
	if not existing.is_empty() and reason == REASON_CHECKPOINT:
		if _same_ground(existing[0], payload):
			return false

	payload["slot_reason"] = reason
	payload["slot_saved_at"] = int(Time.get_unix_time_from_system())

	var path: String = SLOT_DIR + SLOT_PREFIX + str(Time.get_ticks_msec()) \
		+ "_" + str(randi() % 1000) + SLOT_SUFFIX
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()

	_trim(existing.size() + 1)
	return true


## 按时间从新到旧返回全部快照。每一项都带着列表要显示的字段，UI 不必再解析。
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SLOT_DIR):
		return out

	var names := DirAccess.get_files_at(SLOT_DIR)
	for name: String in names:
		if not name.begins_with(SLOT_PREFIX) or not name.ends_with(SLOT_SUFFIX):
			continue
		var path: String = SLOT_DIR + name
		var payload: Dictionary = _read_json(path)
		if payload.is_empty():
			continue
		out.append(describe(payload, path))

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0))
	)
	return out


## 从一份存档里抽出列表要用的那几项。活动存档和快照走同一个函数，所以两边
## 显示的口径一定一致。
static func describe(payload: Dictionary, path: String = "") -> Dictionary:
	var saved_at: int = int(payload.get("slot_saved_at", payload.get("saved_at", 0)))
	return {
		"path": path,
		"saved_at": saved_at,
		"reason": str(payload.get("slot_reason", REASON_CHECKPOINT)),
		"room_id": str(payload.get("resume_room_id", payload.get("current_room_id", ""))),
		"reputation": int(payload.get("reputation", 0)),
		"evidence": _count(payload, "evidence_items"),
		"knowledge": _count(payload, "knowledge_items"),
		"completed": _count(payload, "completed_rooms"),
		"visited": _count(payload, "visited_rooms"),
	}


static func read_slot(path: String) -> Dictionary:
	return _read_json(path)


## 把一张快照写回自动存档位。写的是目标路径的完整覆盖，调用方拿到 true 之后
## 直接走平时的读档流程即可。
static func restore(slot_path: String, target_path: String) -> bool:
	var payload: Dictionary = _read_json(slot_path)
	if payload.is_empty():
		return false
	payload.erase("slot_reason")
	payload.erase("slot_saved_at")
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


static func _count(payload: Dictionary, key: String) -> int:
	var value: Variant = payload.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size()
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).size()
	return 0


static func _same_ground(newest: Dictionary, payload: Dictionary) -> bool:
	var fresh: Dictionary = describe(payload)
	return (
		str(newest.get("room_id", "")) == str(fresh.get("room_id", ""))
		and int(newest.get("evidence", -1)) == int(fresh.get("evidence", -2))
		and int(newest.get("knowledge", -1)) == int(fresh.get("knowledge", -2))
	)


static func _trim(total: int) -> void:
	if total <= MAX_SLOTS:
		return
	var slots: Array[Dictionary] = list()
	for index: int in range(MAX_SLOTS, slots.size()):
		var path: String = str(slots[index].get("path", ""))
		if not path.is_empty():
			DirAccess.remove_absolute(path)
