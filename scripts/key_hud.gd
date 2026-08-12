extends CanvasLayer

## KeyHud — 第一把钥匙取得后出现的钥匙收藏入口。
## 使用城堡标题板、暗金框和钥匙素材，避免现代背包界面突兀。

const BOARD_TEXTURE_PATH: String = "res://assets/ui/keyhub/keyhub_board.png"
const LOCK_TEXTURE_PATH: String = "res://assets/ui/keyhub/knowledge_lock.png"
const BOARD_SIZE: Vector2 = Vector2(900.0, 600.0)
const BOARD_SCALE: float = 900.0 / 1536.0
const SLOT_CENTERS: Array[Vector2] = [
	Vector2(362.0, 293.0),
	Vector2(614.0, 293.0),
	Vector2(868.0, 293.0),
	Vector2(1122.0, 293.0),
	Vector2(362.0, 486.0),
	Vector2(614.0, 486.0),
	Vector2(868.0, 486.0),
	Vector2(1122.0, 486.0)
]
const KEY_IDS: Array[String] = [
	"wake_room_key",
	"chemistry_room_key",
	"greenhouse_room_key",
	"circuit_room_key",
	"service_corridor_key",
	"final_room_key",
	"dining_hall_key",
	"library_room_key"
]
const KEY_NAMES: Array[String] = [
	"Wake Room Key",
	"Chemistry Room Key",
	"Greenhouse Room Key",
	"Circuit Room Key",
	"Service Corridor Key",
	"Final Room Key",
	"Dining Hall Key",
	"Library Room Key"
]
const KEY_TEXTURE_PATHS: Array[String] = [
	"res://assets/ui/keyhub/wake_room_key.png",
	"res://assets/ui/keyhub/chemistry_room_key.png",
	"res://assets/ui/keyhub/greenhouse_room_key.png",
	"res://assets/ui/keyhub/circuit_room_key.png",
	"res://assets/ui/keyhub/final_room_key.png",
	"res://assets/ui/keyhub/ornate_key_panel.png",
	"res://assets/ui/keyhub/ornate_key_panel.png",
	"res://assets/ui/keyhub/ornate_key_panel.png"
]
const KEY_DESCRIPTIONS: Array[String] = [
	"A brass key bearing a red Ashford seal. It belongs to the Wake Room exit.",
	"A heavy laboratory key. Its worn teeth carry a faint chemical-blue shine.",
	"A green-stained key marked with a leaf-shaped crest.",
	"A dark metal key threaded with a violet current.",
	"A cold key recovered from the route toward the Final Room.",
	"An ornate key whose lock is still hidden somewhere in the castle.",
	"A dining-hall key marked with a thin silver fork and knife crest.",
	"A slim brass key stamped with the library's spiral archive seal."
]

var icon_button: TextureButton
var overlay: Control
var board_panel: Control
var detail_label: Label
var selected_index: int = 0
var toast_panel: Panel
var toast_timer: Timer
var _hub_was_unlocked: bool = false
var _paused_before_hub: bool = false


func _ready() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_entry_button()
	_create_hub_overlay()
	_create_unlock_toast()
	if not GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.connect(_on_game_state_changed)
	_hub_was_unlocked = GameState.has_any_key()
	_sync_key_state()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_I and GameState.has_any_key():
		toggle_hub()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and overlay.visible:
		close_hub()
		get_viewport().set_input_as_handled()


func _create_entry_button() -> void:
	# 与 BagHub 一致的 72×72 暗铜圆背板，保证左上角 Hub 入口视觉大小统一。
	var entry_backplate: Panel = Panel.new()
	entry_backplate.name = "KeyHubEntryBackplate"
	# 背板间距统一 16px：BAG(18) → KEY(106) → NOTE(194) → MAP(282)。
	entry_backplate.position = Vector2(106.0, 16.0)
	entry_backplate.size = Vector2(72.0, 72.0)
	entry_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_backplate.z_index = -2
	var backplate_style: StyleBoxFlat = StyleBoxFlat.new()
	backplate_style.bg_color = Color(0.30, 0.18, 0.07, 0.94)
	backplate_style.border_color = Color(1.0, 0.80, 0.36, 1.0)
	backplate_style.set_border_width_all(1)
	backplate_style.set_corner_radius_all(36)
	backplate_style.shadow_color = Color(0.65, 0.35, 0.08, 0.34)
	backplate_style.shadow_size = 8
	entry_backplate.add_theme_stylebox_override("panel", backplate_style)
	add_child(entry_backplate)

	icon_button = TextureButton.new()
	icon_button.name = "KeyHubEntry"
	icon_button.ignore_texture_size = true
	icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_button.texture_normal = load(
		"res://assets/ui/keyhub/wake_room_key.png"
	) as Texture2D
	# BagHub 占据最左侧；KeyHub 按解锁顺序放在 BagHub 后方。
	icon_button.position = Vector2(110.0, 20.0)
	icon_button.size = Vector2(64.0, 64.0)
	icon_button.tooltip_text = "keys"
	icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_button.visible = false
	icon_button.modulate = Color(0.88, 0.76, 0.48, 1.0)
	icon_button.mouse_entered.connect(_on_entry_mouse_entered)
	icon_button.mouse_exited.connect(_on_entry_mouse_exited)
	icon_button.pressed.connect(toggle_hub)
	add_child(icon_button)


func _create_hub_overlay() -> void:
	overlay = Control.new()
	overlay.name = "KeyHubOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.006, 0.018, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	board_panel = Control.new()
	board_panel.name = "KeyHubBoard"
	board_panel.position = Vector2(62.0, 84.0)
	board_panel.size = BOARD_SIZE
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(board_panel)

	var board_texture: TextureRect = TextureRect.new()
	board_texture.name = "KeyHubBoardTexture"
	board_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_texture.texture = load(BOARD_TEXTURE_PATH) as Texture2D
	board_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	board_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(board_texture)

	var close_button: Button = Button.new()
	close_button.name = "KeyHubCloseButton"
	close_button.text = "×"
	close_button.position = Vector2(842.0, 22.0)
	close_button.size = Vector2(38.0, 38.0)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 27)
	close_button.add_theme_color_override(
		"font_color",
		Color(0.96, 0.76, 0.34, 1.0)
	)
	close_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.92, 0.62, 1.0)
	)
	close_button.pressed.connect(close_hub)
	board_panel.add_child(close_button)

	for index: int in range(KEY_IDS.size()):
		_create_key_slot(index)

	detail_label = Label.new()
	detail_label.name = "KeyDetail"
	detail_label.position = Vector2(250.0, 372.0)
	detail_label.size = Vector2(500.0, 100.0)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override(
		"font_color",
		Color(0.26, 0.16, 0.08, 1.0)
	)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(detail_label)


func _create_key_slot(index: int) -> void:
	var center: Vector2 = SLOT_CENTERS[index] * BOARD_SCALE
	var button: TextureButton = TextureButton.new()
	button.name = "KeySlot_%02d" % index
	button.position = center - Vector2(64.0, 64.0)
	button.size = Vector2(128.0, 128.0)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = load(LOCK_TEXTURE_PATH) as Texture2D
	button.modulate = Color(0.28, 0.30, 0.40, 0.48)
	button.tooltip_text = "Locked"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_slot_pressed.bind(index))
	board_panel.add_child(button)


func _create_unlock_toast() -> void:
	toast_panel = Panel.new()
	toast_panel.name = "KeyHubUnlockToast"
	toast_panel.position = Vector2(370.0, 18.0)
	toast_panel.size = Vector2(286.0, 66.0)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.045, 0.94)
	style.border_color = Color(0.82, 0.62, 0.24, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.01, 0.005, 0.02, 0.55)
	style.shadow_size = 8
	toast_panel.add_theme_stylebox_override("panel", style)
	add_child(toast_panel)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "KEY HUB AWAKENED"
	title.position = Vector2(12.0, 7.0)
	title.size = Vector2(262.0, 22.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(title)

	var description: Label = Label.new()
	description.name = "Description"
	description.text = "Your first key has been recorded. Press I or click the key."
	description.position = Vector2(12.0, 30.0)
	description.size = Vector2(262.0, 28.0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.90, 0.84, 0.68, 1.0))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(description)

	toast_timer = Timer.new()
	toast_timer.name = "KeyHubToastTimer"
	toast_timer.one_shot = true
	toast_timer.wait_time = 4.5
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)


func _on_game_state_changed() -> void:
	var unlocked: bool = GameState.has_any_key()
	_sync_key_state()
	if unlocked and not _hub_was_unlocked:
		_show_unlock_toast()
	_hub_was_unlocked = unlocked


func _sync_key_state() -> void:
	if icon_button == null:
		return
	var unlocked: bool = GameState.has_any_key()
	icon_button.visible = unlocked
	for index: int in range(KEY_IDS.size()):
		var slot: TextureButton = board_panel.get_node_or_null(
			"KeySlot_%02d" % index
		) as TextureButton
		if slot == null:
			continue
		var has_key: bool = GameState.has_key(KEY_IDS[index])
		if has_key:
			slot.texture_normal = load(KEY_TEXTURE_PATHS[index]) as Texture2D
			slot.modulate = Color.WHITE
			slot.tooltip_text = KEY_NAMES[index]
		else:
			slot.texture_normal = load(LOCK_TEXTURE_PATH) as Texture2D
			slot.modulate = Color(0.28, 0.30, 0.40, 0.48)
			slot.tooltip_text = "Locked"
	_update_detail()


func _update_detail() -> void:
	if detail_label == null:
		return
	var collected: int = 0
	for key_id: String in KEY_IDS:
		if GameState.has_key(key_id):
			collected += 1
	if collected == 0:
		detail_label.text = "The castle's keys will appear here when you recover them."
		return
	var selected_id: String = KEY_IDS[selected_index]
	if GameState.has_key(selected_id):
		detail_label.text = (
			KEY_NAMES[selected_index]
			+ "\n"
			+ KEY_DESCRIPTIONS[selected_index]
			+ "\n\n"
			+ str(collected)
			+ " / "
			+ str(KEY_IDS.size())
			+ " keys recovered"
		)
	else:
		detail_label.text = (
			"The next lock has not yielded its key yet."
			+ "\n\n"
			+ str(collected)
			+ " / "
			+ str(KEY_IDS.size())
			+ " keys recovered"
		)


func _on_slot_pressed(index: int) -> void:
	selected_index = index
	_update_detail()


func _on_entry_mouse_entered() -> void:
	icon_button.modulate = Color(1.0, 0.92, 0.62, 1.0)


func _on_entry_mouse_exited() -> void:
	icon_button.modulate = Color(0.88, 0.76, 0.48, 1.0)


func toggle_hub() -> void:
	if not GameState.has_any_key():
		return
	if overlay.visible:
		close_hub()
	else:
		open_hub()


func open_hub() -> void:
	if not GameState.has_any_key():
		return
	_paused_before_hub = get_tree().paused
	get_tree().paused = true
	overlay.visible = true
	_sync_key_state()


func close_hub() -> void:
	overlay.visible = false
	get_tree().paused = _paused_before_hub


func _show_unlock_toast() -> void:
	toast_panel.visible = true
	toast_timer.start()


func _on_toast_timeout() -> void:
	toast_panel.visible = false
