class_name CloudAccountUi
extends Control

signal closed

const PANEL_FILL := Color(0.032, 0.020, 0.026, 0.99)
const PANEL_BORDER := Color(0.84, 0.60, 0.22, 0.98)
const FIELD_FILL := Color(0.018, 0.014, 0.024, 0.98)

var panel: PanelContainer
var title_label: Label
var account_label: Label
var explanation_label: Label
var username_field: LineEdit
var password_field: LineEdit
var status_label: Label
var sign_in_button: Button
var create_button: Button
var sync_button: Button
var sign_out_button: Button
var close_button: Button
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120

	var overlay := ColorRect.new()
	overlay.color = Color(0.005, 0.004, 0.012, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var kicker := Label.new()
	kicker.text = "INVESTIGATOR NETWORK"
	kicker.add_theme_color_override("font_color", PANEL_BORDER)
	kicker.add_theme_font_size_override("font_size", 11)
	content.add_child(kicker)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 27)
	ArchiveUi.apply_label(title_label, &"title")
	content.add_child(title_label)

	explanation_label = Label.new()
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.custom_minimum_size = Vector2(500.0, 66.0)
	explanation_label.add_theme_font_size_override("font_size", 13)
	ArchiveUi.apply_label(explanation_label, &"body")
	content.add_child(explanation_label)

	account_label = Label.new()
	account_label.add_theme_color_override("font_color", Color(0.66, 0.87, 0.68))
	account_label.add_theme_font_size_override("font_size", 13)
	content.add_child(account_label)

	username_field = LineEdit.new()
	username_field.custom_minimum_size = Vector2(0.0, 42.0)
	username_field.max_length = 24
	username_field.add_theme_stylebox_override("normal", _field_style())
	username_field.add_theme_stylebox_override("focus", _field_style(PANEL_BORDER))
	content.add_child(username_field)

	password_field = LineEdit.new()
	password_field.custom_minimum_size = Vector2(0.0, 42.0)
	password_field.max_length = 128
	password_field.secret = true
	password_field.add_theme_stylebox_override("normal", _field_style())
	password_field.add_theme_stylebox_override("focus", _field_style(PANEL_BORDER))
	password_field.text_submitted.connect(func(_value: String) -> void: _sign_in())
	content.add_child(password_field)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(500.0, 46.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	status_label.add_theme_font_size_override("font_size", 12)
	content.add_child(status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	sign_in_button = _make_button(actions, ArchiveUi.ROLE_ACTION)
	create_button = _make_button(actions, ArchiveUi.ROLE_ARCHIVE)
	sync_button = _make_button(actions, ArchiveUi.ROLE_ACTION)
	sign_out_button = _make_button(actions, ArchiveUi.ROLE_MUTED)
	for button: Button in [sign_in_button, create_button, sync_button, sign_out_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	close_button = _make_button(content, ArchiveUi.ROLE_ARCHIVE)
	close_button.custom_minimum_size.y = 40.0

	sign_in_button.pressed.connect(_sign_in)
	create_button.pressed.connect(_create_account)
	sync_button.pressed.connect(_sync_now)
	sign_out_button.pressed.connect(CloudSave.sign_out)
	close_button.pressed.connect(close)
	CloudSave.account_changed.connect(_on_account_changed)
	CloudSave.sync_status_changed.connect(_on_sync_status_changed)
	CaseLocale.locale_changed.connect(_refresh_copy)
	get_viewport().size_changed.connect(_fit_layout)
	_refresh_copy()
	_refresh_mode()
	_fit_layout()
	visible = false


func open() -> void:
	visible = true
	_refresh_mode()
	_fit_layout()
	var request_active: bool = CloudSave.is_request_active()
	_set_busy(request_active)
	if request_active:
		status_label.text = (
			"云端档案正在完成当前请求…"
			if CaseLocale.is_chinese()
			else "Cloud archive is finishing the current request…"
		)
	if CloudSave.is_signed_in():
		sync_button.call_deferred("grab_focus")
	else:
		username_field.call_deferred("grab_focus")


func close() -> void:
	if _busy:
		return
	visible = false
	password_field.clear()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _sign_in() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await CloudSave.sign_in(username_field.text, password_field.text)
	_finish_request(result)


func _create_account() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await CloudSave.register_account(
		username_field.text,
		password_field.text
	)
	_finish_request(result)


func _sync_now() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await CloudSave.reconcile()
	_finish_request(result)


func _finish_request(result: Dictionary) -> void:
	_set_busy(false)
	if bool(result.get("ok", false)):
		password_field.clear()
		status_label.text = (
			"云端档案已连接并完成校准。" if CaseLocale.is_chinese()
			else "Cloud case file connected and reconciled."
		)
	else:
		status_label.text = _localized_error(
			str(result.get("code", "")),
			str(result.get("error", ""))
		)
	_refresh_mode()


func _on_account_changed(_username: String) -> void:
	_refresh_mode()


func _on_sync_status_changed(message: String, busy: bool) -> void:
	if visible:
		status_label.text = message
		_set_busy(busy)


func _refresh_mode() -> void:
	if not is_node_ready():
		return
	var signed_in: bool = CloudSave.is_signed_in()
	username_field.visible = not signed_in
	password_field.visible = not signed_in
	sign_in_button.visible = not signed_in
	create_button.visible = not signed_in
	sync_button.visible = signed_in
	sign_out_button.visible = signed_in
	account_label.visible = signed_in
	account_label.text = (
		("已登入：%s" if CaseLocale.is_chinese() else "SIGNED IN · %s")
		% CloudSave.username
	)


func _refresh_copy(_language: String = "") -> void:
	if not is_node_ready():
		return
	title_label.text = "云端案件档案" if CaseLocale.is_chinese() else "Cloud Case File"
	explanation_label.text = (
		"可选功能：本地离线存档始终保留。使用同一调查员 ID 与密码登入另一台电脑，"
		+ "即可恢复最新检查点；被替换的本地进度会先保存到“存档记录”。"
		if CaseLocale.is_chinese()
		else "Optional: local offline saves always remain available. Sign in on another "
		+ "computer with the same Investigator ID and passphrase to restore the newest "
		+ "checkpoint. Replaced local progress is archived first."
	)
	username_field.placeholder_text = (
		"调查员 ID（4–24 位）" if CaseLocale.is_chinese()
		else "Investigator ID (4–24 characters)"
	)
	password_field.placeholder_text = (
		"密码（至少 10 位，请妥善保存）" if CaseLocale.is_chinese()
		else "Passphrase (10+ characters — keep it safe)"
	)
	sign_in_button.text = "登入" if CaseLocale.is_chinese() else "Sign in"
	create_button.text = "创建账号" if CaseLocale.is_chinese() else "Create account"
	sync_button.text = "立即同步" if CaseLocale.is_chinese() else "Sync now"
	sign_out_button.text = "退出登入" if CaseLocale.is_chinese() else "Sign out"
	close_button.text = CaseLocale.text("menu.close")
	if status_label.text.is_empty():
		status_label.text = (
			"账号只用于同步游戏进度；我们不会保存明文密码。"
			if CaseLocale.is_chinese()
			else "Your account only syncs game progress. Plaintext passphrases are never stored."
		)
	_refresh_mode()


func _set_busy(value: bool) -> void:
	_busy = value
	username_field.editable = not value
	password_field.editable = not value
	for button: Button in [
		sign_in_button,
		create_button,
		sync_button,
		sign_out_button,
		close_button,
	]:
		button.disabled = value


func _localized_error(code: String, fallback: String) -> String:
	if not CaseLocale.is_chinese():
		return fallback
	var messages: Dictionary = {
		"invalid_username": "调查员 ID 必须为 4–24 位，只能使用字母、数字、下划线或连字符。",
		"invalid_password": "密码必须为 10–128 位。",
		"exists": "这个调查员 ID 已被注册，请换一个或直接登入。",
		"invalid_login": "调查员 ID 或密码不正确。",
		"session_expired": "云端登入已过期，请重新登入。",
		"network_error": "无法连接云端档案，请检查网络；本地存档不受影响。",
		"cloud_newer": "另一台设备有更新的检查点，请再次同步。",
		"write_conflict": "同步期间另一台设备更新了进度，请再次同步。",
		"rate_limited": "登入尝试过多，请在十五分钟后重试。",
	}
	return str(messages.get(code, fallback))


func _fit_layout() -> void:
	if panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	panel.size = Vector2(
		minf(640.0, viewport_size.x - 40.0),
		minf(540.0, viewport_size.y - 36.0)
	)
	panel.position = (viewport_size - panel.size) * 0.5


func _make_button(parent: Node, role: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 44.0)
	ArchiveUi.apply_button(button, role)
	parent.add_child(button)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.88)
	style.shadow_size = 18
	return style


func _field_style(border: Color = Color(0.34, 0.25, 0.16, 0.95)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FIELD_FILL
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style
