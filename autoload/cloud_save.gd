extends Node

signal account_changed(username: String)
signal sync_status_changed(message: String, busy: bool)
signal cloud_save_imported

const SESSION_PATH: String = "user://cloud_save_session.json"
const SESSION_TEMP_PATH: String = "user://cloud_save_session.json.tmp"
const PRODUCTION_API: String = "https://play.shadowcastledetective.com/api/cloud-save"
const SYNC_DELAY_SECONDS: float = 4.0

var username: String = ""
var session_token: String = ""
var cloud_revision: String = ""
var synced_case_id: String = ""
var synced_generation: int = -1
var _request_active: bool = false
var _session_generation: int = 0
var _save_generation: int = 0
var _sync_pending: bool = false
var _retry_attempts: int = 0


func _ready() -> void:
	_restore_session()


func is_signed_in() -> bool:
	return not username.is_empty() and not session_token.is_empty()


func register_account(investigator_id: String, passphrase: String) -> Dictionary:
	var result: Dictionary = await _post({
		"action": "register",
		"username": investigator_id,
		"password": passphrase,
	})
	if bool(result.get("ok", false)):
		_accept_session(result)
		return await reconcile()
	return result


func sign_in(investigator_id: String, passphrase: String) -> Dictionary:
	var result: Dictionary = await _post({
		"action": "login",
		"username": investigator_id,
		"password": passphrase,
	})
	if bool(result.get("ok", false)):
		_accept_session(result)
		return await reconcile()
	return result


func sign_out() -> void:
	username = ""
	session_token = ""
	cloud_revision = ""
	synced_case_id = ""
	synced_generation = -1
	_session_generation += 1
	_save_generation += 1
	_sync_pending = false
	_retry_attempts = 0
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	if FileAccess.file_exists(SESSION_TEMP_PATH):
		DirAccess.remove_absolute(SESSION_TEMP_PATH)
	account_changed.emit("")
	sync_status_changed.emit(
		"已退出云存档；本地存档仍然保留。" if CaseLocale.is_chinese()
		else "Signed out of cloud saves. Local saves remain available.",
		false
	)


func reconcile() -> Dictionary:
	if not is_signed_in():
		return {"ok": false, "code": "signed_out"}
	var generation: int = _session_generation
	var known_revision: String = cloud_revision
	var pulled: Dictionary = await _post({"action": "pull"}, true)
	if generation != _session_generation:
		return {"ok": false, "code": "session_changed", "error": "Cloud account changed."}
	if not bool(pulled.get("ok", false)):
		return pulled
	var pulled_revision: String = str(pulled.get("revision", ""))

	var cloud_payload: Variant = pulled.get("cloud_save")
	var local_payload: Dictionary = GameState.read_save_payload()
	if typeof(cloud_payload) == TYPE_DICTIONARY:
		var cloud_save: Dictionary = cloud_payload
		var local_generation: int = int(local_payload.get("save_generation", 0))
		var local_case_id: String = str(local_payload.get("case_id", "legacy"))
		var saves_match: bool = (
			not local_payload.is_empty()
			and JSON.stringify(local_payload) == JSON.stringify(cloud_save)
		)
		if saves_match:
			cloud_revision = pulled_revision
			_mark_synced(cloud_save)
			_store_session()
			sync_status_changed.emit(
				"本地与云端进度一致。" if CaseLocale.is_chinese()
				else "Local and cloud progress are aligned.",
				false
			)
			return {"ok": true, "direction": "aligned"}
		var local_changed_since_sync: bool = (
			not local_payload.is_empty()
			and (
				local_case_id != synced_case_id
				or local_generation != synced_generation
			)
		)
		var cloud_changed_since_sync: bool = known_revision != pulled_revision
		if (
			local_payload.is_empty()
			or not local_changed_since_sync
			or cloud_changed_since_sync
		):
			if not GameState.import_save_payload(cloud_save, SaveSlots.REASON_CLOUD):
				return {
					"ok": false,
					"code": "invalid_cloud_save",
					"error": "Cloud checkpoint could not be validated.",
				}
			cloud_save_imported.emit()
			cloud_revision = pulled_revision
			_mark_synced(cloud_save)
			_store_session()
			var conflict_resolved: bool = (
				local_changed_since_sync and cloud_changed_since_sync
			)
			var restored_message: String = (
				"两台设备都有新进度；已采用云端版本，本机版本保存在“存档记录”。"
				if conflict_resolved and CaseLocale.is_chinese()
				else "Both devices changed. The cloud version was restored; this device was archived."
				if conflict_resolved
				else "已恢复云端最新进度。"
				if CaseLocale.is_chinese()
				else "Latest cloud progress restored."
			)
			sync_status_changed.emit(
				restored_message,
				false
			)
			return {
				"ok": true,
				"direction": "conflict_download" if conflict_resolved else "download",
			}

	if not local_payload.is_empty():
		cloud_revision = pulled_revision
		_store_session()
		var pushed: Dictionary = await _push(local_payload)
		if generation != _session_generation:
			return {"ok": false, "code": "session_changed", "error": "Cloud account changed."}
		if bool(pushed.get("ok", false)):
			sync_status_changed.emit(
				"本地进度已同步至云端。" if CaseLocale.is_chinese()
				else "Local progress synced to the cloud.",
				false
			)
		return pushed

	sync_status_changed.emit(
		"账号已连接；等待第一个检查点。" if CaseLocale.is_chinese()
		else "Account connected. Waiting for the first checkpoint.",
		false
	)
	cloud_revision = pulled_revision
	_store_session()
	return {"ok": true, "direction": "none"}


func queue_sync() -> void:
	if not is_signed_in():
		return
	_sync_pending = true
	_save_generation += 1
	_retry_attempts = 0
	var generation: int = _save_generation
	get_tree().create_timer(SYNC_DELAY_SECONDS).timeout.connect(func() -> void:
		if generation == _save_generation and _sync_pending:
			_sync_latest_local_save()
	)


func _sync_latest_local_save() -> void:
	if not _sync_pending or not is_signed_in():
		return
	if _request_active:
		get_tree().create_timer(1.0).timeout.connect(_sync_latest_local_save)
		return
	if cloud_revision.is_empty():
		var generation_before_reconcile: int = _save_generation
		var reconciled: Dictionary = await reconcile()
		if (
			bool(reconciled.get("ok", false))
			and generation_before_reconcile == _save_generation
		):
			_sync_pending = false
			_retry_attempts = 0
		elif bool(reconciled.get("ok", false)):
			_schedule_retry(1.0)
		elif is_signed_in():
			_schedule_retry(5.0)
		return
	var payload: Dictionary = GameState.read_save_payload()
	if payload.is_empty():
		_sync_pending = false
		return
	var generation: int = _save_generation
	var session_generation: int = _session_generation
	var result: Dictionary = await _push(payload)
	if session_generation != _session_generation:
		return
	if bool(result.get("ok", false)) and generation == _save_generation:
		_sync_pending = false
		_retry_attempts = 0
		sync_status_changed.emit(
			"云存档已更新。" if CaseLocale.is_chinese() else "Cloud checkpoint updated.",
			false
		)
	elif bool(result.get("ok", false)):
		_schedule_retry(1.0)
	elif str(result.get("code", "")) in ["cloud_newer", "write_conflict"]:
		_sync_pending = false
		sync_status_changed.emit(
			"另一台设备有更新的进度；请返回主菜单同步。" if CaseLocale.is_chinese()
			else "Another device has newer progress. Return to the menu to reconcile.",
			false
		)
	elif str(result.get("code", "")) in ["busy", "network_error", "server_error", "invalid_response"]:
		_schedule_retry(minf(30.0, pow(2.0, _retry_attempts + 1)))


func _schedule_retry(delay: float) -> void:
	if not _sync_pending or not is_signed_in() or _retry_attempts >= 5:
		return
	_retry_attempts += 1
	get_tree().create_timer(delay).timeout.connect(_sync_latest_local_save)


func _push(payload: Dictionary) -> Dictionary:
	var result: Dictionary = await _post({
		"action": "push",
		"save": payload,
		"base_revision": cloud_revision,
	}, true)
	if bool(result.get("ok", false)):
		cloud_revision = str(result.get("revision", cloud_revision))
		_mark_synced(payload)
		_store_session()
	return result


func _post(payload: Dictionary, authenticated: bool = false) -> Dictionary:
	if _request_active:
		return {
			"ok": false,
			"code": "busy",
			"error": "Cloud archive is already processing a request.",
		}
	_request_active = true
	var request_token: String = session_token
	sync_status_changed.emit(
		"正在连接云端档案…" if CaseLocale.is_chinese() else "Contacting cloud archive…",
		true
	)

	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if authenticated:
		headers.append("Authorization: Bearer " + session_token)
	var start_error: Error = request.request(
		_api_url(),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if start_error != OK:
		request.queue_free()
		_request_active = false
		var start_result := {
			"ok": false,
			"code": "network_error",
			"error": "Cloud request could not start.",
		}
		sync_status_changed.emit(str(start_result["error"]), false)
		return start_result

	var completed: Array = await request.request_completed
	request.queue_free()
	_request_active = false
	var transport_result: int = int(completed[0])
	var response_code: int = int(completed[1])
	var body: PackedByteArray = completed[3]
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		var transport_error := {
			"ok": false,
			"code": "network_error",
			"error": "Cloud archive could not be reached.",
		}
		sync_status_changed.emit(str(transport_error["error"]), false)
		return transport_error

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		var parse_error := {
			"ok": false,
			"code": "invalid_response",
			"error": "Cloud archive returned an invalid response.",
		}
		sync_status_changed.emit(str(parse_error["error"]), false)
		return parse_error
	var result: Dictionary = parsed
	result["ok"] = response_code >= 200 and response_code < 300
	if response_code == 401 and authenticated and session_token == request_token:
		sign_out()
	if not bool(result["ok"]):
		sync_status_changed.emit(str(result.get("error", "Cloud request failed.")), false)
	return result


func _accept_session(result: Dictionary) -> void:
	var token: String = str(result.get("token", ""))
	var account_name: String = str(result.get("username", ""))
	if token.is_empty() or account_name.is_empty():
		return
	session_token = token
	username = account_name
	cloud_revision = ""
	synced_case_id = ""
	synced_generation = -1
	_session_generation += 1
	_store_session()
	account_changed.emit(username)


func _restore_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	username = str((parsed as Dictionary).get("username", ""))
	session_token = str((parsed as Dictionary).get("token", ""))
	cloud_revision = str((parsed as Dictionary).get("revision", ""))
	synced_case_id = str((parsed as Dictionary).get("synced_case_id", ""))
	synced_generation = int((parsed as Dictionary).get("synced_generation", -1))
	if not is_signed_in():
		username = ""
		session_token = ""


func _store_session() -> void:
	var file := FileAccess.open(SESSION_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist cloud-save session.")
		return
	file.store_string(JSON.stringify({
		"username": username,
		"token": session_token,
		"revision": cloud_revision,
		"synced_case_id": synced_case_id,
		"synced_generation": synced_generation,
	}))
	file.flush()
	file.close()
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	var rename_error: Error = DirAccess.rename_absolute(SESSION_TEMP_PATH, SESSION_PATH)
	if rename_error != OK:
		push_error("Could not finalize cloud-save session.")


func _api_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if typeof(origin) == TYPE_STRING and str(origin).begins_with("http"):
			return str(origin) + "/api/cloud-save"
	return PRODUCTION_API


func _mark_synced(payload: Dictionary) -> void:
	synced_case_id = str(payload.get("case_id", "legacy"))
	synced_generation = int(payload.get("save_generation", 0))
