extends CanvasLayer

## KeyHud — 第一把钥匙取得后出现的钥匙收藏入口。
## 使用城堡标题板、暗金框和钥匙素材，避免现代背包界面突兀。

const BOARD_TEXTURE_PATH: String = "res://assets/ui/keyhub/keyhub_board.png"
const LOCK_TEXTURE_PATH: String = "res://assets/ui/keyhub/knowledge_lock.png"
const BOARD_SIZE: Vector2 = Vector2(900.0, 600.0)
# The redesigned cards use a wider 4×2 rhythm than the slots painted into the
# original 1536×1024 board. Keep the complete board for its title and outer
# frame, then enlarge these three authored regions underneath the new layout.
# This avoids either squeezing the cards back into the old geometry or zooming
# the whole board until its title and corner stones are cropped away.
const BOARD_ART_SOURCE_RECTS: Array[Rect2] = [
	Rect2(247.0, 197.0, 990.0, 192.0),
	Rect2(247.0, 392.0, 990.0, 188.0),
	Rect2(218.0, 600.0, 1076.0, 234.0),
]
const BOARD_ART_TARGET_RECTS: Array[Rect2] = [
	Rect2(61.0, 96.0, 779.0, 144.0),
	Rect2(61.0, 240.0, 779.0, 144.0),
	Rect2(96.0, 382.0, 708.0, 154.0),
]
const BOARD_ART_REGION_NAMES: Array[String] = [
	"KeyTopRowArtwork",
	"KeyBottomRowArtwork",
	"KeyDetailArtwork",
]
const SLOT_CENTERS: Array[Vector2] = [
	Vector2(150.0, 168.0),
	Vector2(350.0, 168.0),
	Vector2(550.0, 168.0),
	Vector2(750.0, 168.0),
	Vector2(150.0, 312.0),
	Vector2(350.0, 312.0),
	Vector2(550.0, 312.0),
	Vector2(750.0, 312.0)
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
var entry_label: Label
var entry_backplate: Panel
var overlay: Control
var board_panel: Control
var board_texture_rect: TextureRect
var artwork_fit_layer: Control
var detail_panel: Panel
var detail_label: Label
var progress_label: Label
var progress_pips: Array[ColorRect] = []
var open_tween: Tween
var selected_index: int = 0
var toast_panel: Panel
var toast_timer: Timer
var _hub_was_unlocked: bool = false
var _paused_before_hub: bool = false
var _entry_suppressed: bool = false


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
	if key_event.keycode == KEY_I and not _entry_suppressed and GameState.has_any_key():
		toggle_hub()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and overlay.visible:
		close_hub()
		get_viewport().set_input_as_handled()


func _create_entry_button() -> void:
	# 与 BagHub 一致的 72×72 暗铜圆背板，保证左上角 Hub 入口视觉大小统一。
	entry_backplate = Panel.new()
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

	entry_label = Label.new()
	entry_label.name = "KeyHubLabel"
	entry_label.text = CaseLocale.line("KEYS")
	entry_label.position = Vector2(110.0, 82.0)
	entry_label.size = Vector2(64.0, 20.0)
	entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_label.visible = false
	entry_label.add_theme_font_size_override("font_size", 10)
	entry_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	entry_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 1.0))
	entry_label.add_theme_constant_override("outline_size", 3)
	add_child(entry_label)


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
	ArchiveUi.install_screen_atmosphere(overlay, {
		"lamp_anchor": Vector2(0.50, 0.40),
		"lamp_strength": 0.20,
		"lamp_radius": 0.64,
		"vignette_strength": 0.62,
		"vignette_radius": 0.34,
		"mote_strength": 0.30,
		"grain_strength": 0.022,
	})

	board_panel = Control.new()
	board_panel.name = "KeyHubBoard"
	board_panel.position = Vector2(62.0, 84.0)
	board_panel.size = BOARD_SIZE
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(board_panel)

	board_texture_rect = TextureRect.new()
	board_texture_rect.name = "KeyHubBoardTexture"
	board_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_texture_rect.texture = load(BOARD_TEXTURE_PATH) as Texture2D
	board_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	board_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_texture_rect.set_meta("hub_artwork_fit", "full_frame_with_fitted_regions")
	board_panel.add_child(board_texture_rect)
	_create_fitted_board_artwork(board_texture_rect.texture)

	var title := Label.new()
	title.name = "KeyRegisterTitle"
	title.text = CaseLocale.line("KEY REGISTER")
	title.position = Vector2(64.0, 26.0)
	title.size = Vector2(236.0, 28.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.025, 0.01, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "KeyRegisterSubtitle"
	subtitle.text = CaseLocale.line("TEETH · CRESTS · ACCESS")
	subtitle.position = Vector2(66.0, 54.0)
	subtitle.size = Vector2(236.0, 18.0)
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.62, 0.48, 1.0))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(subtitle)
	progress_label = Label.new()
	progress_label.name = "KeyRecoveryProgress"
	progress_label.position = Vector2(602.0, 54.0)
	progress_label.size = Vector2(222.0, 22.0)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color(0.86, 0.70, 0.38, 1.0))
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(progress_label)
	for pip_index: int in range(KEY_IDS.size()):
		var pip := ColorRect.new()
		pip.name = "KeyProgressPip%02d" % pip_index
		pip.position = Vector2(608.0 + float(pip_index) * 27.0, 32.0)
		pip.size = Vector2(21.0, 7.0)
		pip.color = Color(0.24, 0.20, 0.18, 0.88)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_panel.add_child(pip)
		progress_pips.append(pip)

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

	detail_panel = Panel.new()
	detail_panel.name = "KeyDetailChamber"
	detail_panel.position = Vector2(110.0, 388.0)
	detail_panel.size = Vector2(680.0, 138.0)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(
			Color(0.055, 0.038, 0.030, 0.94),
			Color(0.66, 0.48, 0.20, 0.88),
			2,
			7,
			9
		)
	)
	board_panel.add_child(detail_panel)
	detail_label = Label.new()
	detail_label.name = "KeyDetail"
	detail_label.position = Vector2(26.0, 16.0)
	detail_label.size = Vector2(628.0, 106.0)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text = true
	detail_label.max_lines_visible = 6
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.84, 0.68, 1.0)
	)
	detail_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.96))
	detail_label.add_theme_constant_override("outline_size", 2)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_child(detail_label)
	ArchiveUi.decorate_hub(board_panel, {
		"role": "keys",
		"accent": Color(0.92, 0.70, 0.30, 0.92),
		"rule_y": 14.0,
		"stamp_rect": Rect2(64.0, 80.0, 214.0, 25.0),
		"stamp": "LOCKSMITH INDEX · 8 PROFILES",
		"protocol_rect": Rect2(110.0, 542.0, 680.0, 24.0),
		"protocol": "1 · SELECT KEY    2 · INSPECT TEETH / CREST    3 · MATCH LOCK",
	})


func _create_fitted_board_artwork(source_texture: Texture2D) -> void:
	artwork_fit_layer = Control.new()
	artwork_fit_layer.name = "KeyHubArtworkFit"
	artwork_fit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork_fit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork_fit_layer.set_meta("fit_strategy", "authored_atlas_regions")
	board_panel.add_child(artwork_fit_layer)

	for index: int in range(BOARD_ART_SOURCE_RECTS.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = source_texture
		atlas.region = BOARD_ART_SOURCE_RECTS[index]
		var artwork := TextureRect.new()
		artwork.name = BOARD_ART_REGION_NAMES[index]
		artwork.position = BOARD_ART_TARGET_RECTS[index].position
		artwork.size = BOARD_ART_TARGET_RECTS[index].size
		artwork.texture = atlas
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_SCALE
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.set_meta("source_region", BOARD_ART_SOURCE_RECTS[index])
		artwork.set_meta("target_region", BOARD_ART_TARGET_RECTS[index])
		artwork_fit_layer.add_child(artwork)


func _create_key_slot(index: int) -> void:
	var center: Vector2 = SLOT_CENTERS[index]
	var plate := Panel.new()
	plate.name = "KeySlotPlate_%02d" % index
	plate.position = center - Vector2(66.0, 66.0)
	plate.size = Vector2(132.0, 132.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(
		"panel",
		ArchiveUi.panel_style(
			Color(0.035, 0.026, 0.030, 0.88),
			Color(0.42, 0.32, 0.18, 0.76),
			1,
			6,
			4
		)
	)
	board_panel.add_child(plate)
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
	var index_label := Label.new()
	index_label.name = "KeyIndex"
	index_label.text = "%02d" % (index + 1)
	index_label.position = Vector2(7.0, 5.0)
	index_label.size = Vector2(28.0, 18.0)
	index_label.add_theme_font_size_override("font_size", 9)
	index_label.add_theme_color_override("font_color", Color(0.82, 0.64, 0.30, 1.0))
	index_label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 1.0))
	index_label.add_theme_constant_override("outline_size", 2)
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(index_label)
	var state_label := Label.new()
	state_label.name = "KeyState"
	state_label.position = Vector2(10.0, 103.0)
	state_label.size = Vector2(108.0, 20.0)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 1.0))
	state_label.add_theme_constant_override("outline_size", 2)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(state_label)


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
	title.text = CaseLocale.line("KEY HUB AWAKENED")
	title.position = Vector2(12.0, 7.0)
	title.size = Vector2(262.0, 22.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(title)

	var description: Label = Label.new()
	description.name = "Description"
	description.text = CaseLocale.line("Your first key has been recorded. Press I or click the key.")
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
	icon_button.visible = unlocked and not _entry_suppressed
	entry_backplate.visible = unlocked and not _entry_suppressed
	entry_label.visible = unlocked and not _entry_suppressed
	var collected := 0
	for index: int in range(KEY_IDS.size()):
		var slot: TextureButton = board_panel.get_node_or_null(
			"KeySlot_%02d" % index
		) as TextureButton
		if slot == null:
			continue
		var has_key: bool = GameState.has_key(KEY_IDS[index])
		if has_key:
			collected += 1
		var state_label := slot.get_node_or_null("KeyState") as Label
		if has_key:
			slot.texture_normal = load(KEY_TEXTURE_PATHS[index]) as Texture2D
			slot.modulate = Color.WHITE
			slot.tooltip_text = KEY_NAMES[index]
			if state_label != null:
				state_label.text = CaseLocale.line("RECOVERED")
				state_label.add_theme_color_override("font_color", Color(0.72, 0.94, 0.62, 1.0))
		else:
			slot.texture_normal = load(LOCK_TEXTURE_PATH) as Texture2D
			slot.modulate = Color(0.28, 0.30, 0.40, 0.48)
			slot.tooltip_text = "Locked"
			if state_label != null:
				state_label.text = "LOCKED"
				state_label.add_theme_color_override("font_color", Color(0.52, 0.50, 0.52, 1.0))
		var selected := index == selected_index
		slot.self_modulate = Color(1.12, 1.04, 0.82, 1.0) if selected else Color.WHITE
		var plate := board_panel.get_node_or_null("KeySlotPlate_%02d" % index) as Panel
		if plate != null:
			plate.add_theme_stylebox_override(
				"panel",
				ArchiveUi.panel_style(
					Color(0.10, 0.060, 0.030, 0.94) if selected else Color(0.035, 0.026, 0.030, 0.88),
					Color(0.96, 0.72, 0.28, 0.96) if selected else Color(0.42, 0.32, 0.18, 0.76),
					2 if selected else 1,
					6,
					7 if selected else 4
				)
			)
	if progress_label != null:
		progress_label.text = "%d / %d KEYS RECOVERED" % [collected, KEY_IDS.size()]
	for index: int in range(progress_pips.size()):
		progress_pips[index].color = (
			Color(0.76, 0.88, 0.48, 1.0)
			if GameState.has_key(KEY_IDS[index])
			else Color(0.24, 0.20, 0.18, 0.88)
		)
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
		detail_label.add_theme_font_size_override("font_size", 13 if detail_label.text.length() > 150 else 14)
	else:
		detail_label.text = (
			"The next lock has not yielded its key yet."
			+ "\n\n"
			+ str(collected)
			+ " / "
			+ str(KEY_IDS.size())
			+ " keys recovered"
		)
		detail_label.add_theme_font_size_override("font_size", 14)


func _on_slot_pressed(index: int) -> void:
	selected_index = index
	_sync_key_state()
	var slot := board_panel.get_node_or_null("KeySlot_%02d" % index) as TextureButton
	if slot != null:
		slot.pivot_offset = slot.size * 0.5
		slot.scale = Vector2(1.07, 1.07)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.18)


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
	ArchiveUi.set_hub_entries_suppressed(true)
	overlay.visible = true
	_sync_key_state()
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	overlay.modulate.a = 0.0
	board_panel.pivot_offset = board_panel.size * 0.5
	board_panel.scale = Vector2(0.965, 0.965)
	open_tween = create_tween()
	open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	open_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(overlay, "modulate:a", 1.0, 0.14)
	open_tween.parallel().tween_property(board_panel, "scale", Vector2.ONE, 0.22)
	call_deferred("_focus_selected_key")


func close_hub() -> void:
	overlay.visible = false
	board_panel.scale = Vector2.ONE
	overlay.modulate = Color.WHITE
	get_tree().paused = _paused_before_hub
	ArchiveUi.set_hub_entries_suppressed(false)


func _focus_selected_key() -> void:
	var slot := board_panel.get_node_or_null("KeySlot_%02d" % selected_index) as TextureButton
	if slot != null:
		slot.grab_focus()


func _show_unlock_toast() -> void:
	toast_panel.visible = true
	toast_timer.start()


func _on_toast_timeout() -> void:
	toast_panel.visible = false


func dismiss_unlock_toast() -> void:
	if toast_panel != null:
		toast_panel.visible = false
	if toast_timer != null:
		toast_timer.stop()


func set_entry_suppressed(suppressed: bool) -> void:
	_entry_suppressed = suppressed
	_sync_key_state()
