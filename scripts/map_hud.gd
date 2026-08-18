extends CanvasLayer

## MapHub — 真实 Castle Hall 地图。
## 断电时只保留实时信号；Circuit 供电后才将走过区域显示为灰色记忆。

const MAP_TEXTURE_PATH: String = (
	"res://assets/backgrounds/hall_map_hub.png"
)
const MAP_IMAGE_SIZE: Vector2 = Vector2(1448.0, 1086.0)
const MAP_PANEL_POSITION: Vector2 = Vector2(36.0, 94.0)
const MAP_PANEL_SIZE: Vector2 = Vector2(720.0, 540.0)
const MAP_LEDGER_POSITION: Vector2 = Vector2(772.0, 94.0)
const MAP_LEDGER_SIZE: Vector2 = Vector2(220.0, 540.0)
const HALL_WORLD_SIZE: Vector2 = Vector2(1920.0, 1280.0)
const HALL_CELL_SIZE: float = 32.0
const MAP_TO_PANEL: Vector2 = Vector2(
	MAP_PANEL_SIZE.x / MAP_IMAGE_SIZE.x,
	MAP_PANEL_SIZE.y / MAP_IMAGE_SIZE.y
)

# 房门交互点使用 game_world.gd 的真实世界坐标，不使用抽象布局坐标。
const ROOM_IDS: Array[String] = [
	"wake_room",
	"chemistry_room",
	"greenhouse_room",
	"circuit_room",
	"final_deduction_room",
	"library",
	"dining_hall"
]
const ROOM_LABELS: Array[String] = [
	"Wake Room",
	"Chemistry Room",
	"Greenhouse",
	"Circuit Room",
	"Final Room",
	"Library",
	"Dining Hall"
]
const ROOM_KEY_IDS: Array[String] = [
	"",
	"chemistry_room_key",
	"greenhouse_room_key",
	"circuit_room_key",
	"final_room_key",
	"library_room_key",
	"dining_hall_key"
]
const ROOM_WORLD_POSITIONS: Array[Vector2] = [
	Vector2(258.0, 1050.0),
	Vector2(283.0, 162.0),
	Vector2(219.0, 409.0),
	Vector2(168.0, 691.0),
	Vector2(955.0, 138.0),
	Vector2(1676.0, 285.0),
	Vector2(1774.0, 715.0)
]

const WALK_REVEAL_RADIUS_MAP: float = 28.0
const ROOM_REVEAL_RADIUS_MAP: float = 88.0
const WAKE_REVEAL_RADIUS_MAP: float = 105.0
const POWERED_MEMORY_DARKNESS: float = 0.66
const GUARDIAN_MINIMAP_POSITION: Vector2 = Vector2(828.0, 594.0)
const GUARDIAN_MINIMAP_SIZE: Vector2 = Vector2(178.0, 156.0)
const GUARDIAN_MINIMAP_MAP_POSITION: Vector2 = Vector2(9.0, 27.0)
const GUARDIAN_MINIMAP_MAP_SIZE: Vector2 = Vector2(160.0, 120.0)

var map_entry_button: Button
var overlay: Control
var map_panel: Panel
var map_texture_rect: TextureRect
var fog_texture_rect: TextureRect
var fog_image: Image
var fog_texture: ImageTexture
var map_detail: Label
var map_ledger: Panel
var player_marker: Control
var guardian_marker: Control
var guardian_minimap: Panel
var guardian_minimap_status: Label
var guardian_minimap_fog_rect: TextureRect
var mini_guardian_marker: Control
var mini_player_marker: Control
var entry_tween: Tween
var map_open_tween: Tween
var player_marker_tween: Tween
var room_points: Array[Panel] = []
var room_labels: Array[Label] = []
var _known_explored_count: int = -1
var _drawn_explored: Dictionary = {}
var _paused_before_map: bool = false
var repair_overlay: Control
var _entry_suppressed := false
var _guardian_tracking_suppressed := false
var _last_power_restored := false


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_map_entry()
	_create_map_overlay()
	_create_guardian_minimap()
	if not GameState.state_changed.is_connected(_on_game_state_changed):
		GameState.state_changed.connect(_on_game_state_changed)
	if not GameState.guardian_tracking_changed.is_connected(_on_guardian_tracking_changed):
		GameState.guardian_tracking_changed.connect(_on_guardian_tracking_changed)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)
	_sync_map_state()


func _process(_delta: float) -> void:
	var power_restored := GameState.has_story_flag("circuit_power_restored")
	if power_restored != _last_power_restored:
		_last_power_restored = power_restored
		_refresh_fog_texture()
	# Route memory is withheld during the blackout. Once power is restored,
	# only newly recorded cells are shaded incrementally for performance.
	if power_restored:
		var explored: Dictionary = GameState.hall_explored_cells
		var has_new: bool = false
		for cell_key: Variant in explored.keys():
			if not _drawn_explored.has(cell_key):
				_draw_explored_cell(cell_key)
				_drawn_explored[cell_key] = true
				has_new = true
		if has_new:
			fog_texture.update(fog_image)
			_known_explored_count = explored.size()
	if overlay != null and overlay.visible:
		_update_player_marker()
	refresh_guardian_tracking()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (
		key_event.keycode == KEY_U
		and not _entry_suppressed
		and GameState.is_map_hub_unlocked()
	):
		toggle_map()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and repair_overlay != null and repair_overlay.visible:
		close_repair_map()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and overlay.visible:
		close_map()
		get_viewport().set_input_as_handled()


func _create_map_entry() -> void:
	map_entry_button = Button.new()
	map_entry_button.name = "MapHubEntry"
	map_entry_button.text = ""
	# 左上角 Hub 顺序：BAG(18) → KEY(106) → NOTE(194) → MAP(282)，间距 16px。
	map_entry_button.position = Vector2(282.0, 14.0)
	map_entry_button.size = Vector2(72.0, 72.0)
	map_entry_button.pivot_offset = Vector2(36.0, 36.0)
	map_entry_button.visible = false
	map_entry_button.tooltip_text = "Route map  ·  U"
	map_entry_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_entry_button.focus_mode = Control.FOCUS_ALL
	_apply_entry_style()
	map_entry_button.mouse_entered.connect(_set_map_entry_hover.bind(true))
	map_entry_button.mouse_exited.connect(_set_map_entry_hover.bind(false))
	map_entry_button.pressed.connect(toggle_map)
	add_child(map_entry_button)

	var glyph := Label.new()
	glyph.name = "MapHubGlyph"
	glyph.text = "◇"
	glyph.position = Vector2(0.0, 7.0)
	glyph.size = Vector2(72.0, 32.0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 25)
	glyph.add_theme_color_override("font_color", Color(0.58, 0.78, 1.0, 1.0))
	glyph.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 1.0))
	glyph.add_theme_constant_override("outline_size", 3)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_entry_button.add_child(glyph)

	var label := Label.new()
	label.name = "MapHubLabel"
	label.text = "MAP"
	label.position = Vector2(0.0, 41.0)
	label.size = Vector2(72.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_entry_button.add_child(label)


func _apply_entry_style() -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.035, 0.035, 0.075, 0.94)
	normal_style.border_color = Color(0.46, 0.62, 0.92, 0.90)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(36)
	normal_style.shadow_color = Color(0.18, 0.34, 0.86, 0.28)
	normal_style.shadow_size = 7
	map_entry_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.08, 0.12, 0.25, 0.98)
	hover_style.border_color = Color(0.70, 0.88, 1.0, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.shadow_color = Color(0.25, 0.56, 1.0, 0.52)
	hover_style.shadow_size = 12
	map_entry_button.add_theme_stylebox_override("hover", hover_style)
	map_entry_button.add_theme_stylebox_override("focus", hover_style)
	map_entry_button.add_theme_color_override(
		"font_color",
		Color(0.88, 0.72, 0.36, 1.0)
	)
	map_entry_button.add_theme_color_override(
		"font_hover_color",
		Color(0.92, 0.96, 1.0, 1.0)
	)


func _set_map_entry_hover(is_hovered: bool) -> void:
	if entry_tween != null and entry_tween.is_valid():
		entry_tween.kill()
	entry_tween = create_tween()
	entry_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entry_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(
		map_entry_button,
		"scale",
		Vector2(1.08, 1.08) if is_hovered else Vector2.ONE,
		0.14
	)


func _create_map_overlay() -> void:
	overlay = Control.new()
	overlay.name = "MapHubOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "MapHubDarkBackground"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.002, 0.002, 0.006, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	# No archive atmosphere here on purpose. The survey field renders unexplored
	# hall geometry in near-black, so any light added beneath it lifts the walls
	# into a readable building outline and breaks pre-power blackout secrecy.

	var title: Label = Label.new()
	title.name = "MapTitle"
	title.position = Vector2(36.0, 22.0)
	title.size = Vector2(680.0, 30.0)
	title.text = "DR. LIN'S SURVEY MAP"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.94, 0.72, 0.31, 1.0))
	overlay.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "MapSubtitle"
	subtitle.position = Vector2(38.0, 52.0)
	subtitle.size = Vector2(720.0, 22.0)
	subtitle.text = "Only verified ground is written in ink. Trace your own route through the hall."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48, 1.0))
	overlay.add_child(subtitle)

	map_panel = Panel.new()
	map_panel.name = "RealCastleHallMap"
	map_panel.position = MAP_PANEL_POSITION
	map_panel.size = MAP_PANEL_SIZE
	map_panel.pivot_offset = MAP_PANEL_SIZE * 0.5
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var map_style: StyleBoxFlat = StyleBoxFlat.new()
	map_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	map_style.border_color = Color(0.66, 0.48, 0.20, 0.92)
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(6)
	map_style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	map_style.shadow_size = 16
	map_panel.add_theme_stylebox_override("panel", map_style)
	overlay.add_child(map_panel)

	map_texture_rect = TextureRect.new()
	map_texture_rect.name = "HallMapTexture"
	map_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture_rect.texture = load(MAP_TEXTURE_PATH) as Texture2D
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The source map and panel share the same 4:3 ratio. Scale to the exact panel
	# rectangle so the artwork, fog image and world-to-map markers use one frame.
	map_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_texture_rect.set_meta("hub_artwork_fit", "full_frame_coordinate_locked")
	map_panel.add_child(map_texture_rect)

	fog_texture_rect = TextureRect.new()
	fog_texture_rect.name = "HallExplorationDarkness"
	fog_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	fog_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_texture_rect.set_meta("hub_artwork_fit", "full_frame_coordinate_locked")
	map_panel.add_child(fog_texture_rect)
	_create_fog_texture()

	var close_button: Button = Button.new()
	close_button.name = "MapCloseButton"
	close_button.text = "×"
	close_button.position = Vector2(954.0, 26.0)
	close_button.size = Vector2(38.0, 38.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_size_override("font_size", 27)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_color_override("font_color", Color(0.92, 0.68, 0.28, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.58, 1.0))
	close_button.add_theme_stylebox_override("normal", _make_close_style(false))
	close_button.add_theme_stylebox_override("hover", _make_close_style(true))
	close_button.pressed.connect(close_map)
	overlay.add_child(close_button)

	for index: int in range(ROOM_IDS.size()):
		_create_room_point(index)
	_create_player_marker()
	_create_guardian_marker()
	_create_map_ledger()
	ArchiveUi.decorate_hub(overlay, {
		"role": "survey",
		"accent": Color(0.48, 0.76, 1.0, 0.90),
		"rule_y": 14.0,
		"stamp_rect": Rect2(786.0, 24.0, 154.0, 25.0),
		"stamp": "LIVE SURVEY · U",
		"stamp_role": "arcane",
		"protocol_rect": Rect2(772.0, 646.0, 220.0, 28.0),
		"protocol": "SCAN · ROUTE · EVADE",
		"protocol_font_size": 9,
	})


func _make_close_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.075, 0.025, 0.92) if is_hovered else Color(0.035, 0.028, 0.055, 0.88)
	style.border_color = Color(1.0, 0.78, 0.30, 1.0) if is_hovered else Color(0.62, 0.46, 0.22, 0.78)
	style.set_border_width_all(2 if is_hovered else 1)
	style.set_corner_radius_all(19)
	return style


func _create_map_ledger() -> void:
	map_ledger = Panel.new()
	map_ledger.name = "MapSurveyLedger"
	map_ledger.position = MAP_LEDGER_POSITION
	map_ledger.size = MAP_LEDGER_SIZE
	map_ledger.pivot_offset = MAP_LEDGER_SIZE * 0.5
	map_ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ledger_style := StyleBoxFlat.new()
	ledger_style.bg_color = Color(0.050, 0.025, 0.080, 0.97)
	ledger_style.border_color = Color(0.47, 0.30, 0.72, 0.92)
	ledger_style.set_border_width_all(1)
	ledger_style.set_corner_radius_all(6)
	ledger_style.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	ledger_style.shadow_size = 10
	map_ledger.add_theme_stylebox_override("panel", ledger_style)
	overlay.add_child(map_ledger)

	var heading := Label.new()
	heading.name = "SurveyLedgerTitle"
	heading.text = "SURVEY LEDGER"
	heading.position = Vector2(14.0, 16.0)
	heading.size = Vector2(192.0, 26.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.92, 0.72, 0.35, 1.0))
	heading.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.08, 1.0))
	heading.add_theme_constant_override("outline_size", 3)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ledger.add_child(heading)

	var rule := ColorRect.new()
	rule.position = Vector2(16.0, 48.0)
	rule.size = Vector2(188.0, 1.0)
	rule.color = Color(0.60, 0.42, 0.20, 0.55)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ledger.add_child(rule)

	map_detail = Label.new()
	map_detail.name = "MapDetail"
	map_detail.position = Vector2(14.0, 66.0)
	map_detail.size = Vector2(192.0, 452.0)
	map_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_detail.clip_text = true
	map_detail.max_lines_visible = 32
	map_detail.add_theme_font_size_override("font_size", 10)
	map_detail.add_theme_color_override("font_color", Color(0.80, 0.74, 0.62, 1.0))
	map_detail.add_theme_color_override("font_outline_color", Color(0.025, 0.01, 0.04, 1.0))
	map_detail.add_theme_constant_override("outline_size", 2)
	map_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ledger.add_child(map_detail)


func _create_player_marker() -> void:
	player_marker = Control.new()
	player_marker.name = "MapPlayerMarker"
	player_marker.size = Vector2(30.0, 30.0)
	player_marker.pivot_offset = Vector2(15.0, 15.0)
	player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_marker.z_index = 8
	map_panel.add_child(player_marker)

	var halo := Panel.new()
	halo.position = Vector2(1.0, 1.0)
	halo.size = Vector2(28.0, 28.0)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo_style := StyleBoxFlat.new()
	halo_style.bg_color = Color(0.18, 0.58, 1.0, 0.18)
	halo_style.border_color = Color(0.48, 0.82, 1.0, 0.88)
	halo_style.set_border_width_all(1)
	halo_style.set_corner_radius_all(14)
	halo_style.shadow_color = Color(0.18, 0.58, 1.0, 0.65)
	halo_style.shadow_size = 9
	halo.add_theme_stylebox_override("panel", halo_style)
	player_marker.add_child(halo)

	var core := Panel.new()
	core.position = Vector2(9.0, 9.0)
	core.size = Vector2(12.0, 12.0)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var core_style := StyleBoxFlat.new()
	core_style.bg_color = Color(0.72, 0.92, 1.0, 1.0)
	core_style.border_color = Color(0.06, 0.18, 0.42, 1.0)
	core_style.set_border_width_all(2)
	core_style.set_corner_radius_all(6)
	core.add_theme_stylebox_override("panel", core_style)
	player_marker.add_child(core)

	player_marker_tween = create_tween().set_loops()
	player_marker_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	player_marker_tween.tween_property(player_marker, "scale", Vector2(1.13, 1.13), 0.65)
	player_marker_tween.tween_property(player_marker, "scale", Vector2.ONE, 0.65)


func _create_guardian_marker() -> void:
	guardian_marker = _new_guardian_tracking_marker(
		"MapGuardianMarker",
		Vector2(24.0, 24.0),
		10
	)
	map_panel.add_child(guardian_marker)


func _create_guardian_minimap() -> void:
	guardian_minimap = Panel.new()
	guardian_minimap.name = "GuardianMiniMap"
	guardian_minimap.position = GUARDIAN_MINIMAP_POSITION
	guardian_minimap.size = GUARDIAN_MINIMAP_SIZE
	guardian_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_minimap.visible = false
	guardian_minimap.z_index = 30
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.028, 0.014, 0.040, 0.96)
	frame_style.border_color = Color(0.70, 0.34, 0.58, 0.96)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(7)
	frame_style.shadow_color = Color(0.15, 0.01, 0.16, 0.62)
	frame_style.shadow_size = 9
	guardian_minimap.add_theme_stylebox_override("panel", frame_style)
	add_child(guardian_minimap)

	guardian_minimap_status = Label.new()
	guardian_minimap_status.name = "GuardianMiniMapStatus"
	guardian_minimap_status.position = Vector2(8.0, 4.0)
	guardian_minimap_status.size = Vector2(162.0, 19.0)
	guardian_minimap_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guardian_minimap_status.add_theme_font_size_override("font_size", 10)
	guardian_minimap_status.add_theme_color_override("font_color", Color(0.98, 0.68, 0.77, 1.0))
	guardian_minimap_status.add_theme_color_override("font_outline_color", Color(0.08, 0.01, 0.08, 1.0))
	guardian_minimap_status.add_theme_constant_override("outline_size", 2)
	guardian_minimap_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_minimap.add_child(guardian_minimap_status)

	var map_texture := TextureRect.new()
	map_texture.name = "GuardianMiniMapTexture"
	map_texture.position = GUARDIAN_MINIMAP_MAP_POSITION
	map_texture.size = GUARDIAN_MINIMAP_MAP_SIZE
	map_texture.texture = load(MAP_TEXTURE_PATH) as Texture2D
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_SCALE
	map_texture.modulate = Color(0.46, 0.39, 0.56, 0.88)
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_minimap.add_child(map_texture)

	var shade := ColorRect.new()
	shade.position = GUARDIAN_MINIMAP_MAP_POSITION
	shade.size = GUARDIAN_MINIMAP_MAP_SIZE
	shade.color = Color(0.015, 0.008, 0.025, 0.30)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_minimap.add_child(shade)

	guardian_minimap_fog_rect = TextureRect.new()
	guardian_minimap_fog_rect.name = "GuardianMiniMapFog"
	guardian_minimap_fog_rect.position = GUARDIAN_MINIMAP_MAP_POSITION
	guardian_minimap_fog_rect.size = GUARDIAN_MINIMAP_MAP_SIZE
	guardian_minimap_fog_rect.texture = fog_texture
	guardian_minimap_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	guardian_minimap_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	guardian_minimap_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	guardian_minimap_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_minimap_fog_rect.set_meta("fog_policy", "shared_power_memory")
	guardian_minimap.add_child(guardian_minimap_fog_rect)

	mini_player_marker = _new_simple_marker(
		"MiniPlayerMarker",
		Vector2(9.0, 9.0),
		Color(0.54, 0.88, 1.0, 1.0),
		Color(0.10, 0.32, 0.62, 1.0),
		7
	)
	guardian_minimap.add_child(mini_player_marker)
	mini_guardian_marker = _new_guardian_tracking_marker(
		"MiniGuardianMarker",
		Vector2(12.0, 12.0),
		8
	)
	guardian_minimap.add_child(mini_guardian_marker)


func _new_guardian_tracking_marker(
	marker_name: String,
	marker_size: Vector2,
	marker_z_index: int
) -> Control:
	var marker := Control.new()
	marker.name = marker_name
	marker.size = marker_size
	marker.pivot_offset = marker_size * 0.5
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = marker_z_index
	var halo := Panel.new()
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.08, 0.28, 0.88)
	style.border_color = Color(1.0, 0.52, 0.78, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(marker_size.x * 0.5))
	style.shadow_color = Color(0.72, 0.04, 0.34, 0.88)
	style.shadow_size = 7
	halo.add_theme_stylebox_override("panel", style)
	marker.add_child(halo)
	var core := Label.new()
	core.text = "!"
	core.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	core.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core.add_theme_font_size_override("font_size", maxi(8, int(marker_size.x * 0.55)))
	core.add_theme_color_override("font_color", Color.WHITE)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(core)
	return marker


func _new_simple_marker(
	marker_name: String,
	marker_size: Vector2,
	fill: Color,
	border: Color,
	marker_z_index: int
) -> Control:
	var marker := Panel.new()
	marker.name = marker_name
	marker.size = marker_size
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = marker_z_index
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(marker_size.x * 0.5))
	(marker as Panel).add_theme_stylebox_override("panel", style)
	return marker


func _create_room_point(index: int) -> void:
	var map_position: Vector2 = _world_to_map(
		ROOM_WORLD_POSITIONS[index]
	)
	var panel_position: Vector2 = map_position * MAP_TO_PANEL

	var point: Panel = Panel.new()
	point.name = "RoomKeyLight_%s" % ROOM_IDS[index]
	point.position = panel_position - Vector2(9.0, 9.0)
	point.size = Vector2(18.0, 18.0)
	point.mouse_filter = Control.MOUSE_FILTER_IGNORE
	point.add_theme_stylebox_override("panel", _make_point_style())
	map_panel.add_child(point)
	room_points.append(point)

	var label: Label = Label.new()
	label.name = "RoomLabel_%s" % ROOM_IDS[index]
	label.position = panel_position + Vector2(14.0, -11.0)
	label.size = Vector2(180.0, 24.0)
	if label.position.x + label.size.x > MAP_PANEL_SIZE.x - 8.0:
		label.position.x = panel_position.x - label.size.x - 14.0
	if label.position.y < 4.0:
		label.position.y = panel_position.y + 12.0
	if label.position.y + label.size.y > MAP_PANEL_SIZE.y - 4.0:
		label.position.y = MAP_PANEL_SIZE.y - label.size.y - 4.0
	label.text = ROOM_LABELS[index]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.43, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.01, 0.035, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(label)
	room_labels.append(label)


func _create_fog_texture() -> void:
	fog_image = Image.create(
		int(MAP_IMAGE_SIZE.x),
		int(MAP_IMAGE_SIZE.y),
		false,
		Image.FORMAT_RGBA8
	)
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog_texture_rect.texture = fog_texture
	_last_power_restored = GameState.has_story_flag("circuit_power_restored")
	_refresh_fog_texture()


func _draw_explored_cell(cell_key: Variant) -> void:
	var parts: PackedStringArray = str(cell_key).split(",")
	if parts.size() != 2:
		return
	var cell: Vector2 = Vector2(
		float(parts[0]),
		float(parts[1])
	)
	var world_center: Vector2 = (
		cell + Vector2(0.5, 0.5)
	) * HALL_CELL_SIZE
	_shade_map_circle(
		_world_to_map(world_center),
		WALK_REVEAL_RADIUS_MAP
	)


func _refresh_fog_texture() -> void:
	if fog_image == null or fog_texture == null:
		return
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))

	# Before Circuit power, the paper map cannot reveal architecture the player
	# cannot see in the Hall. Live player/Guardian signals remain separate nodes.
	if not GameState.has_story_flag("circuit_power_restored"):
		fog_texture.update(fog_image)
		_known_explored_count = GameState.hall_explored_cells.size()
		_drawn_explored.clear()
		return

	# Once power is restored, walked and entered ground becomes dim gray memory;
	# it never becomes fully clear, and all unwalked ground remains pure black.
	_shade_map_circle(
		_world_to_map(ROOM_WORLD_POSITIONS[0]),
		WAKE_REVEAL_RADIUS_MAP
	)

	# 大厅中玩家真实走过的 32px 探索格。
	for cell_key: Variant in GameState.hall_explored_cells.keys():
		_draw_explored_cell(cell_key)

	# 进入过的房间区域解除黑暗。
	for index: int in range(ROOM_IDS.size()):
		if _is_room_visited(ROOM_IDS[index]):
			_shade_map_circle(
				_world_to_map(ROOM_WORLD_POSITIONS[index]),
				ROOM_REVEAL_RADIUS_MAP
			)

	fog_texture.update(fog_image)
	_known_explored_count = GameState.hall_explored_cells.size()
	_drawn_explored.clear()
	for cell_key: Variant in GameState.hall_explored_cells.keys():
		_drawn_explored[cell_key] = true


func _shade_map_circle(center: Vector2, radius: float) -> void:
	# 用 C++ 批量 fill_rect 代替逐像素 set_pixel：
	# 大厅探索格最多 2400 个，逐像素重建是百万次引擎调用（卡死根源），
	# fill_rect 一次调用填充整个矩形，速度提升几个数量级。
	var rect := Rect2i(
		int(center.x - radius),
		int(center.y - radius),
		int(radius * 2.0),
		int(radius * 2.0)
	)
	rect = rect.intersection(
		Rect2i(0, 0, int(MAP_IMAGE_SIZE.x), int(MAP_IMAGE_SIZE.y))
	)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	fog_image.fill_rect(rect, Color(0.0, 0.0, 0.0, POWERED_MEMORY_DARKNESS))


func _world_to_map(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x * MAP_IMAGE_SIZE.x / HALL_WORLD_SIZE.x,
		world_position.y * MAP_IMAGE_SIZE.y / HALL_WORLD_SIZE.y
	)


func _update_player_marker() -> void:
	if player_marker == null:
		return
	if GameState.current_room_id != "floor_1_hub":
		player_marker.visible = false
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		player_marker.visible = false
		return
	var player := current_scene.get_node_or_null("player") as Node2D
	if player == null:
		player_marker.visible = false
		return
	var panel_position: Vector2 = _world_to_map(player.global_position) * MAP_TO_PANEL
	player_marker.position = panel_position - player_marker.size * 0.5
	player_marker.visible = true


func refresh_guardian_tracking() -> void:
	if guardian_minimap == null or guardian_marker == null:
		return
	var tracking_active := (
		GameState.game_started
		and GameState.is_map_hub_unlocked()
		and GameState.is_guardian_hunt_active()
	)
	guardian_marker.visible = tracking_active
	guardian_minimap.visible = (
		tracking_active
		and not _guardian_tracking_suppressed
		and (overlay == null or not overlay.visible)
		and (repair_overlay == null or not repair_overlay.visible)
	)
	if not tracking_active:
		if mini_guardian_marker != null:
			mini_guardian_marker.visible = false
		if mini_player_marker != null:
			mini_player_marker.visible = false
		return

	var guardian_position := GameState.get_guardian_hall_position()
	var guardian_map_position := _world_to_map(guardian_position) * MAP_TO_PANEL
	guardian_marker.position = guardian_map_position - guardian_marker.size * 0.5

	var mini_guardian_position := Vector2(
		guardian_position.x / HALL_WORLD_SIZE.x * GUARDIAN_MINIMAP_MAP_SIZE.x,
		guardian_position.y / HALL_WORLD_SIZE.y * GUARDIAN_MINIMAP_MAP_SIZE.y
	)
	mini_guardian_marker.position = (
		GUARDIAN_MINIMAP_MAP_POSITION
		+ mini_guardian_position
		- mini_guardian_marker.size * 0.5
	)
	mini_guardian_marker.visible = true
	guardian_minimap_status.text = (
		"GUARDIAN  •  PURSUIT"
		if GameState.get_guardian_mode() == GameState.GuardianMode.CHASE
		else "GUARDIAN  •  HALL PATROL"
	)

	mini_player_marker.visible = false
	if GameState.current_room_id == "floor_1_hub":
		var current_scene := get_tree().current_scene
		var hall_player := (
			current_scene.get_node_or_null("player") as Node2D
			if current_scene != null
			else null
		)
		if hall_player != null:
			var mini_player_position := Vector2(
				hall_player.global_position.x / HALL_WORLD_SIZE.x * GUARDIAN_MINIMAP_MAP_SIZE.x,
				hall_player.global_position.y / HALL_WORLD_SIZE.y * GUARDIAN_MINIMAP_MAP_SIZE.y
			)
			mini_player_marker.position = (
				GUARDIAN_MINIMAP_MAP_POSITION
				+ mini_player_position
				- mini_player_marker.size * 0.5
			)
			mini_player_marker.visible = true


func set_guardian_tracking_suppressed(suppressed: bool) -> void:
	_guardian_tracking_suppressed = suppressed
	refresh_guardian_tracking()


func _on_guardian_tracking_changed(_mode: int, _hall_position: Vector2) -> void:
	refresh_guardian_tracking()


func _refresh_map_ledger() -> void:
	if map_detail == null:
		return
	if not GameState.has_story_flag("circuit_power_restored"):
		map_detail.text = (
			"STATUS: TOTAL BLACKOUT\n\n"
			+ "Only live player and Guardian signals remain readable.\n\n"
			+ "Restore power to recover route memory."
		)
		return
	if GameState.chase_mode:
		map_detail.text = (
			"STATUS: PURSUIT / POWER ONLINE\n\n"
			+ "Blue  •  your position\n"
			+ "Red   •  Guardian signal\n\n"
			+ "Walked routes remain in gray memory; room labels are hidden while the Guardian is pursuing you."
		)
		return
	var visited_count := 0
	var held_key_count := 0
	for index: int in range(ROOM_IDS.size()):
		if _is_room_visited(ROOM_IDS[index]):
			visited_count += 1
		var key_id := ROOM_KEY_IDS[index]
		if not key_id.is_empty() and GameState.has_key(key_id):
			held_key_count += 1
	var explored_count: int = GameState.hall_explored_cells.size()
	map_detail.text = (
		(
			"GUARDIAN SIGNAL\nPatrolling Castle Hall\n\n"
			if GameState.is_guardian_hunt_active()
			else ""
		)
		+
		"RECORDED GROUND\n"
		+ str(explored_count) + " / 2400 tiles\n\n"
		+ "KNOWN ROOMS\n"
		+ str(visited_count) + " / " + str(ROOM_IDS.size()) + " entered\n\n"
		+ "KEYS IN HAND\n"
		+ str(held_key_count) + " marked in gold\n\n"
		+ "LEGEND\n"
		+ "Blue  •  your position\n"
		+ "Red   •  Guardian\n"
		+ "Gold  •  key acquired\n"
		+ "Ink   •  room entered\n"
		+ "Black •  uncharted"
	)


func _is_room_visited(room_id: String) -> bool:
	return (
		room_id == "wake_room"
		or GameState.is_room_visited(room_id)
	)


func _make_point_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.68, 0.25, 1.0)
	style.border_color = Color(1.0, 0.91, 0.55, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.94, 0.53, 0.12, 0.92)
	style.shadow_size = 12
	return style


func _on_scene_changed() -> void:
	# MapHub 是 Autoload，不会随房间场景释放；切换房间时必须关闭大厅地图，
	# 否则新房间会显示在 Castle Hall 地图 Overlay 后面，造成画面混合。
	if overlay != null:
		overlay.visible = false
	if repair_overlay != null:
		repair_overlay.visible = false
	_paused_before_map = false
	get_tree().paused = false
	call_deferred("_sync_map_state")


func _on_game_state_changed() -> void:
	# 轻量同步：入口按钮与房间点。迷雾大图由 _process 检测
	# 探索格数量变化后增量重建，避免每帧重建 1448×1086 纹理。
	_sync_map_state_light()


func _sync_map_state_light() -> void:
	if map_entry_button == null:
		return
	map_entry_button.visible = (
		GameState.is_map_hub_unlocked()
		and GameState.current_room_id == "floor_1_hub"
		and not _entry_suppressed
	)
	if not GameState.has_story_flag("circuit_power_restored") or GameState.chase_mode:
		for index: int in range(ROOM_IDS.size()):
			room_labels[index].visible = false
			room_points[index].visible = false
		_refresh_map_ledger()
		_update_player_marker()
		refresh_guardian_tracking()
		return
	for index: int in range(ROOM_IDS.size()):
		var visited: bool = _is_room_visited(ROOM_IDS[index])
		room_labels[index].visible = visited
		var key_id: String = ROOM_KEY_IDS[index]
		var has_key: bool = (
			ROOM_IDS[index] == "wake_room"
			or (
				not key_id.is_empty()
				and GameState.has_key(key_id)
			)
		)
		room_points[index].visible = has_key
		if visited:
			room_points[index].modulate = Color(0.88, 0.68, 0.34, 1.0)
		else:
			room_points[index].modulate = Color.WHITE
	_refresh_map_ledger()
	_update_player_marker()
	refresh_guardian_tracking()


func _sync_map_state() -> void:
	if map_entry_button == null:
		return
	map_entry_button.visible = (
		GameState.is_map_hub_unlocked()
		and GameState.current_room_id == "floor_1_hub"
		and not _entry_suppressed
	)
	if GameState.chase_mode:
		for index: int in range(ROOM_IDS.size()):
			room_labels[index].visible = false
			room_points[index].visible = false
		_refresh_map_ledger()
		_update_player_marker()
		refresh_guardian_tracking()
		return
	for index: int in range(ROOM_IDS.size()):
		var visited: bool = _is_room_visited(ROOM_IDS[index])
		room_labels[index].visible = visited
		var key_id: String = ROOM_KEY_IDS[index]
		var has_key: bool = (
			ROOM_IDS[index] == "wake_room"
			or (
				not key_id.is_empty()
				and GameState.has_key(key_id)
			)
		)
		room_points[index].visible = has_key
		if visited:
			room_points[index].modulate = Color(0.88, 0.68, 0.34, 1.0)
		else:
			room_points[index].modulate = Color.WHITE
	_refresh_fog_texture()
	_refresh_map_ledger()
	_update_player_marker()
	refresh_guardian_tracking()


func unlock_and_open() -> void:
	GameState.unlock_map_hub()
	open_map()


func toggle_map() -> void:
	if not GameState.is_map_hub_unlocked():
		return
	if overlay.visible:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if not GameState.is_map_hub_unlocked():
		return
	if (
		GameState.has_story_flag("power_map_objective_active")
		and not GameState.has_story_flag("power_map_reviewed")
	):
		GameState.set_story_flag("power_map_reviewed")
		var active_scene := get_tree().current_scene
		if active_scene != null and active_scene.has_method("_on_power_map_reviewed"):
			active_scene.call("_on_power_map_reviewed")
	_paused_before_map = get_tree().paused
	get_tree().paused = true
	ArchiveUi.set_hub_entries_suppressed(true)
	overlay.visible = true
	_sync_map_state_light()
	_refresh_fog_texture()
	_update_player_marker()
	refresh_guardian_tracking()
	_animate_map_open()


func _animate_map_open() -> void:
	if map_open_tween != null and map_open_tween.is_valid():
		map_open_tween.kill()
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	map_panel.scale = Vector2(0.965, 0.965)
	if map_ledger != null:
		map_ledger.scale = Vector2(0.965, 0.965)
	map_open_tween = create_tween()
	map_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	map_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	map_open_tween.tween_property(overlay, "modulate:a", 1.0, 0.12)
	map_open_tween.parallel().tween_property(map_panel, "scale", Vector2.ONE, 0.20)
	if map_ledger != null:
		map_open_tween.parallel().tween_property(map_ledger, "scale", Vector2.ONE, 0.20)


func show_repair_map() -> void:
	if not GameState.has_map("circuit_repair_map"):
		return
	var bag_hud: Node = get_node_or_null("/root/InventoryHud")
	if bag_hud != null:
		var feature_panel: Panel = bag_hud.get("feature_panel") as Panel
		if feature_panel != null:
			feature_panel.visible = false
	var reward_hud: Node = get_node_or_null("/root/ItemRewardHud")
	if reward_hud != null:
		reward_hud.call("dismiss_for_overlay")
	if repair_overlay == null:
		_create_repair_overlay()
	_paused_before_map = get_tree().paused
	get_tree().paused = true
	ArchiveUi.set_hub_entries_suppressed(true)
	overlay.visible = false
	repair_overlay.visible = true
	# Studying the blueprint is what teaches the player where the flush junction
	# plates are, and it only counts on site: the drawing is only meaningful when
	# it can be held against the housings in front of you.
	if GameState.current_room_id == "circuit_room":
		GameState.set_story_flag("circuit_repair_map_studied")


func _create_repair_overlay() -> void:
	repair_overlay = Control.new()
	repair_overlay.name = "CircuitRepairMapOverlay"
	repair_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repair_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	repair_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(repair_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	repair_overlay.add_child(shade)

	var panel: Panel = Panel.new()
	panel.position = Vector2(132.0, 20.0)
	panel.size = Vector2(760.0, 728.0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.045, 0.025, 0.98)
	panel_style.border_color = Color(0.78, 0.58, 0.25, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	repair_overlay.add_child(panel)

	var title: Label = Label.new()
	title.text = "CIRCUIT REPAIR MAP"
	title.position = Vector2(34.0, 22.0)
	title.size = Vector2(600.0, 34.0)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38, 1.0))
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Restore power in this order: 1 AUXILIARY  →  2 REGULATOR  →  3 MASTER"
	subtitle.position = Vector2(34.0, 62.0)
	subtitle.size = Vector2(650.0, 30.0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66, 1.0))
	panel.add_child(subtitle)

	var map_board: TextureRect = TextureRect.new()
	map_board.position = Vector2(62.0, 100.0)
	map_board.size = Vector2(636.0, 478.0)
	map_board.texture = load("res://assets/backgrounds/circuit_room_workshop.png") as Texture2D
	map_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_board.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(map_board)

	var border: Panel = Panel.new()
	border.position = Vector2(62.0, 100.0)
	border.size = Vector2(636.0, 478.0)
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.border_color = Color(0.65, 0.48, 0.24, 0.9)
	border_style.set_border_width_all(2)
	border.add_theme_stylebox_override("panel", border_style)
	panel.add_child(border)

	var room_label: Label = Label.new()
	room_label.text = "CIRCUIT ROOM / ACTUAL SWITCH LOCATIONS"
	room_label.position = Vector2(192.0, 78.0)
	room_label.size = Vector2(360.0, 28.0)
	room_label.add_theme_font_size_override("font_size", 13)
	room_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.68, 1.0))
	panel.add_child(room_label)

	var board_rect := Rect2(map_board.position, map_board.size)
	for switch_id: String in CircuitLayout.SWITCH_ORDER:
		var spec := CircuitLayout.SWITCH_SPECS[switch_id] as Dictionary
		var source_position := spec["position"] as Vector2
		var marker_center := CircuitLayout.room_to_map_board(source_position, board_rect)
		var marker := Control.new()
		marker.name = "RepairSwitchMarker_" + switch_id
		marker.position = marker_center - Vector2(75.0, 22.0)
		marker.size = Vector2(150.0, 68.0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.set_meta("source_world_position", source_position)
		marker.set_meta("map_marker_center", marker_center)
		panel.add_child(marker)

		var marker_plate := Panel.new()
		marker_plate.name = "MarkerPlate"
		marker_plate.position = Vector2(53.0, 0.0)
		marker_plate.size = Vector2(44.0, 44.0)
		marker_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marker_style := StyleBoxFlat.new()
		marker_style.bg_color = Color(0.075, 0.052, 0.035, 0.97)
		marker_style.border_color = Color(0.92, 0.70, 0.29, 0.98)
		marker_style.set_border_width_all(2)
		marker_style.set_corner_radius_all(8)
		marker_style.shadow_color = Color(0.04, 0.01, 0.0, 0.70)
		marker_style.shadow_size = 7
		marker_plate.add_theme_stylebox_override("panel", marker_style)
		marker.add_child(marker_plate)

		var number := Label.new()
		number.name = "SequenceNumber"
		number.text = str(spec["number"])
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 20)
		number.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38, 1.0))
		number.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01, 1.0))
		number.add_theme_constant_override("outline_size", 3)
		marker_plate.add_child(number)

		var name_label := Label.new()
		name_label.name = "SwitchLocationLabel"
		name_label.text = str(spec["label"])
		name_label.position = Vector2(0.0, 46.0)
		name_label.size = Vector2(150.0, 20.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.add_theme_color_override("font_color", Color(0.84, 0.75, 0.54, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.025, 0.01, 1.0))
		name_label.add_theme_constant_override("outline_size", 2)
		marker.add_child(name_label)

	var note: Label = Label.new()
	note.text = "Markers are projected from the switches' exact room coordinates.\nStand beside each brass unit and press E in sequence."
	note.position = Vector2(48.0, 600.0)
	note.size = Vector2(650.0, 42.0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.clip_text = true
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.78, 0.70, 0.55, 1.0))
	panel.add_child(note)

	var close_button: Button = Button.new()
	close_button.text = "CLOSE"
	close_button.position = Vector2(574.0, 665.0)
	close_button.size = Vector2(120.0, 36.0)
	close_button.pressed.connect(close_repair_map)
	panel.add_child(close_button)


func close_repair_map() -> void:
	if repair_overlay != null:
		repair_overlay.visible = false
	get_tree().paused = _paused_before_map
	ArchiveUi.set_hub_entries_suppressed(false)


func close_map() -> void:
	if map_open_tween != null and map_open_tween.is_valid():
		map_open_tween.kill()
	map_panel.scale = Vector2.ONE
	if map_ledger != null:
		map_ledger.scale = Vector2.ONE
	overlay.modulate = Color.WHITE
	overlay.visible = false
	get_tree().paused = _paused_before_map
	ArchiveUi.set_hub_entries_suppressed(false)
	refresh_guardian_tracking()


func set_entry_suppressed(suppressed: bool) -> void:
	_entry_suppressed = suppressed
	if map_entry_button == null:
		return
	map_entry_button.visible = (
		not suppressed
		and GameState.is_map_hub_unlocked()
		and GameState.current_room_id == "floor_1_hub"
	)
