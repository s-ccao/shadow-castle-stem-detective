extends SceneTree

var failures: Array[String] = []
var originals: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	var paths: Array[String] = [
		game_state.SAVE_PATH,
		game_state.SAVE_TEMP_PATH,
		game_state.SAVE_BACKUP_PATH,
	]
	for path: String in paths:
		originals[path] = _read_bytes(path)
		_remove(path)

	var backup_payload := _payload(1, "backup-case")
	_write_json(game_state.SAVE_BACKUP_PATH, backup_payload)
	game_state.call("_recover_interrupted_save")
	_expect(
		int(game_state.call("read_save_payload").get("save_generation", 0)) == 1,
		"Startup restores a valid backup when the active save is missing"
	)

	var pending_payload := _payload(2, "pending-case")
	_write_json(game_state.SAVE_TEMP_PATH, pending_payload)
	game_state.call("_recover_interrupted_save")
	_expect(
		int(game_state.call("read_save_payload").get("save_generation", 0)) == 2,
		"Startup finalizes a newer complete temporary save"
	)
	_expect(
		int(_read_json(game_state.SAVE_BACKUP_PATH).get("save_generation", 0)) == 1,
		"Finalizing a temporary save preserves the previous checkpoint as backup"
	)

	_write_text(game_state.SAVE_PATH, "{broken")
	_write_json(game_state.SAVE_BACKUP_PATH, _payload(3, "recovery-case"))
	game_state.call("_recover_interrupted_save")
	_expect(
		int(game_state.call("read_save_payload").get("save_generation", 0)) == 3,
		"Startup replaces a corrupt active save with its validated backup"
	)

	for path: String in paths:
		_remove(path)
		var bytes: PackedByteArray = originals[path]
		if not bytes.is_empty():
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
	_finish()


func _payload(generation: int, id: String) -> Dictionary:
	return {
		"version": 1,
		"save_generation": generation,
		"case_id": id,
		"saved_at": 1787263000 + generation,
		"checkpoint_valid": true,
		"resume_scene_path": "res://scenes/wake_room.tscn",
		"resume_room_id": "wake_room",
	}


func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _write_json(path: String, payload: Dictionary) -> void:
	_write_text(path, JSON.stringify(payload))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("save_recovery_test: PASS")
		quit(0)
		return
	printerr("save_recovery_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
