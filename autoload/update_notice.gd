extends CanvasLayer

const POLL_INTERVAL_SECONDS := 0.75
const REMIND_LATER_SECONDS := 10 * 60

var overlay: ColorRect
var panel: PanelContainer
var kicker_label: Label
var title_label: Label
var body_label: Label
var status_label: Label
var restart_button: Button
var later_button: Button
var _poll_remaining := 0.0
var _paused_before_notice := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_copy()
	CaseLocale.locale_changed.connect(_on_locale_changed)
	set_process(OS.has_feature("web"))


func _process(delta: float) -> void:
	if visible:
		return
	_poll_remaining -= delta
	if _poll_remaining > 0.0:
		return
	_poll_remaining = POLL_INTERVAL_SECONDS
	if _web_update_ready():
		_show_notice()


func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.name = "UpdateModalBlocker"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.008, 0.006, 0.018, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	panel = PanelContainer.new()
	panel.name = "UpdateAnnouncementPanel"
	panel.custom_minimum_size = Vector2(620.0, 350.0)
	panel.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(
			Color(0.045, 0.026, 0.020, 0.995),
			ArchiveUi.COLOR_BRASS,
			2,
			8,
			18
		)
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	kicker_label = Label.new()
	kicker_label.add_theme_font_size_override("font_size", 11)
	ArchiveUi.apply_label(kicker_label, &"muted")
	content.add_child(kicker_label)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ArchiveUi.apply_label(title_label, &"title")
	content.add_child(title_label)

	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = ArchiveUi.COLOR_BRASS
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)

	body_label = Label.new()
	body_label.custom_minimum_size = Vector2(0.0, 116.0)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 15)
	ArchiveUi.apply_label(body_label, &"body")
	content.add_child(body_label)

	status_label = Label.new()
	status_label.custom_minimum_size.y = 24.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	ArchiveUi.apply_label(status_label, &"muted")
	content.add_child(status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	restart_button = Button.new()
	restart_button.name = "RestartUpdateButton"
	restart_button.custom_minimum_size = Vector2(242.0, 48.0)
	ArchiveUi.apply_button(restart_button, ArchiveUi.ROLE_ACTION)
	restart_button.pressed.connect(_restart_now)
	actions.add_child(restart_button)

	later_button = Button.new()
	later_button.name = "LaterUpdateButton"
	later_button.custom_minimum_size = Vector2(242.0, 48.0)
	ArchiveUi.apply_button(later_button, ArchiveUi.ROLE_MUTED)
	later_button.pressed.connect(_dismiss_for_later)
	actions.add_child(later_button)

	ArchiveUi.wire_focus_cycle([restart_button, later_button])
	visible = false


func _show_notice() -> void:
	if visible:
		return
	_paused_before_notice = get_tree().paused
	get_tree().paused = true
	status_label.text = ""
	_set_actions_enabled(true)
	visible = true
	restart_button.call_deferred("grab_focus")


func _dismiss_for_later() -> void:
	if not visible:
		return
	_web_snooze_update()
	visible = false
	get_tree().paused = _paused_before_notice


func _restart_now() -> void:
	_set_actions_enabled(false)
	status_label.text = CaseLocale.text("update.restarting")
	if (
		GameState.is_game_started()
		and GameState.has_room_checkpoint()
		and not GameState.save_to_disk()
	):
		status_label.text = CaseLocale.text("update.save_failed")
		_set_actions_enabled(true)
		restart_button.grab_focus()
		return
	if not _web_activate_update():
		status_label.text = CaseLocale.text("update.activate_failed")
		_set_actions_enabled(true)
		restart_button.grab_focus()


func _set_actions_enabled(enabled: bool) -> void:
	restart_button.disabled = not enabled
	later_button.disabled = not enabled


func _refresh_copy() -> void:
	if kicker_label == null:
		return
	kicker_label.text = CaseLocale.text("update.kicker")
	title_label.text = CaseLocale.text("update.title")
	body_label.text = CaseLocale.text("update.body")
	restart_button.text = CaseLocale.text("update.restart")
	later_button.text = CaseLocale.text("update.later")


func _on_locale_changed(_language: String) -> void:
	_refresh_copy()


func _web_update_ready() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
		"Boolean(window.shadowCastleUpdate && window.shadowCastleUpdate.isReady())",
		true
	))


func _web_snooze_update() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.shadowCastleUpdate && window.shadowCastleUpdate.snooze(%d)"
			% (REMIND_LATER_SECONDS * 1000),
			true
		)


func _web_activate_update() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
		"Boolean(window.shadowCastleUpdate && window.shadowCastleUpdate.activate())",
		true
	))
