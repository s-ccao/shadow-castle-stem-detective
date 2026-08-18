## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Index-first case ledger: the evidence list is the navigation, while one
## readable dossier page carries the selected record and its final-case status.
extends CanvasLayer

## ============================================================
## ClueJournal — 侦探笔记系统（Clue Journal）
##
## 场景：scenes/clue_journal.tscn（Godot Container 自动布局）
## 素材：res://assets/ui/ui_note_*.png / icon_*.png
##
## 功能：
##   - open() / close()：打开/关闭（淡入淡出 0.2s，打开时暂停游戏）
##   - 动态生成左侧线索列表（TextureButton 三态贴图 + 图标 + 标题）
##   - 点击左侧按钮 → 右侧羊皮纸显示对应详情（BBCode 富文本）
##   - 只有 unlocked = true 的线索才显示
##   - 当前选中按钮使用细金色侧标记，不覆盖卡片背景
##   - ESC / Tab 键关闭
##   - 数据：Dictionary，可导出/加载 JSON
##
## 添加新线索：
##   在 CLUE_DEFAULTS 里加一条，或在游戏代码里调用
##   clue_journal.add_clue("id", {"title": "...", "icon": "icon_xxx",
##                               "content": "[b]...[/b]", "category": "..."})
## ============================================================

# 图标资源映射（icon 字段 → 贴图路径）
const CLUE_ICONS := {
	"icon_book": "res://assets/ui/icon_book.png",
	"icon_key": "res://assets/ui/icon_key.png",
	"icon_note": "res://assets/ui/icon_note.png",
	"icon_search": "res://assets/ui/icon_search.png",
}

# 线索按钮模板场景（scenes/clue_list_item.tscn，可在编辑器调整样式）
const CLUE_ITEM_SCENE: PackedScene = preload("res://scenes/clue_list_item.tscn")
const SEALED_ARCHIVE_IDS: Array[String] = [
	"sealed_archive_pressure",
	"sealed_archive_instruction",
	"sealed_archive_lin_decision",
]

# 示例线索数据（id -> 数据字典）
# 字段：title 标题 / icon 图标名 / content BBCode 正文 / unlocked 是否已解锁 / category 分类
const CLUE_DEFAULTS := {
	"scroll_clue": {
		"title": "The Master's Door Riddle",
		"icon": "icon_note",
		"content": "[center][b]The Master's Door Riddle[/b][/center]\n\nTo whoever finds this —\n\nThe master of this castle [color=#4a306d]loved knowledge[/color]. They say every door in this castle holds a [color=#7a2e2e]single question[/color].\n\nAnswer it correctly, and even without a key, the door will open.\n\nIf you are reading this... I may already be gone.\n\n[color=#4a306d]— Mrs. Lin[/color]",
		"unlocked": false,
		"category": "lore",
	},
	"candle_note": {
		"title": "The Candle Note",
		"icon": "icon_search",
		"content": "[center][b]The Candle Note[/b][/center]\n\nA flame cannot keep burning without [color=#7a2e2e]oxygen[/color] from the air. If the air supply is blocked, the flame weakens and dies.",
		"unlocked": false,
		"category": "evidence",
	},
	"key_fragment": {
		"title": "A Broken Key",
		"icon": "icon_key",
		"content": "[center][b]A Broken Key[/b][/center]\n\nA rusted key fragment found near the [color=#7a2e2e]laboratory door[/color]. It seems to belong to a [color=#4a306d]much larger key[/color]...",
		"unlocked": false,
		"category": "evidence",
	},
	"master_journal": {
		"title": "The Master's Journal",
		"icon": "icon_book",
		"content": "[center][b]The Master's Journal[/b][/center]\n\nA worn leather journal. Its pages speak of [color=#4a306d]ancient knowledge locks[/color] and a [color=#7a2e2e]single key of understanding[/color]...",
		"unlocked": false,
		"category": "lore",
	},
}

# 线索按钮保持原始木牌贴图；选中态由卡片脚本绘制细金色侧标记。
const BTN_NORMAL := "res://assets/ui/ui_note_listitem_normal_trim.png"
const BTN_HOVER := "res://assets/ui/ui_note_listitem_hover_trim.png"

const INK := Color(0.20, 0.115, 0.050, 1.0)
const INK_MUTED := Color(0.34, 0.215, 0.105, 1.0)
# Alpha at or above this counts as painted page rather than drop shadow.
const PAINTED_ALPHA_THRESHOLD := 0.55
const PIN_BRASS := Color(0.82, 0.59, 0.22, 1.0)
const PIN_BRASS_HOVER := Color(1.0, 0.80, 0.38, 1.0)
const PIN_WALNUT := Color(0.135, 0.070, 0.024, 0.98)
const PIN_WALNUT_HOVER := Color(0.225, 0.118, 0.038, 0.99)
const PIN_MOSS := Color(0.090, 0.165, 0.085, 0.99)
const PIN_MOSS_HOVER := Color(0.135, 0.255, 0.115, 1.0)
const PIN_TEXT := Color(0.98, 0.84, 0.50, 1.0)
const PIN_TEXT_ACTIVE := Color(0.82, 0.98, 0.72, 1.0)

# 线索数据（运行时副本）
var clues: Dictionary = {}
# 当前选中的线索 id
var _selected_id := ""
# 已创建的按钮引用（id -> TextureButton），用于切换选中高亮
var _buttons: Dictionary = {}
var _rebuilding := false
var _rebuild_dirty := false
var _x_hovered := false
var archive_pin_button: Button
var archive_pin_inlay: Panel
var archive_pin_mark: ColorRect
var archive_pin_label: Label
var archive_pin_count_label: Label
var _archive_pin_tween: Tween
var _open_tween: Tween
var _painted_uv_cache: Dictionary = {}
var close_button: Button

@onready var title_label: Label = %TitleLabel
@onready var journal_subtitle: Label = %JournalSubtitle
@onready var list_box: VBoxContainer = %ListBox
@onready var list_header: Label = %ListHeader
@onready var list_count_label: Label = %ListCountLabel
@onready var detail_text: RichTextLabel = %DetailText
@onready var document_kicker: Label = %DocumentKicker
@onready var document_title: Label = %DocumentTitle
@onready var document_meta: Label = %DocumentMeta
@onready var document_rule: ColorRect = %DocumentRule
@onready var overlay: ColorRect = $Overlay
@onready var main_panel: Panel = $MainPanel
@onready var scroll_decor: VScrollBar = %ScrollBarDecor
@onready var x_visual: Sprite2D = $MainPanel/XVisual
@onready var left_panel_bg: Panel = $MainPanel/LeftPanelBg
@onready var list_scroll: ScrollContainer = %ListScroll
@onready var parchment: TextureRect = $MainPanel/Parchment
@onready var parchment_margin: MarginContainer = $MainPanel/Parchment/ParchMargin
@onready var title_sep: ColorRect = $MainPanel/TitleSep


func _ready() -> void:
	# 暂停期间本界面仍然运行（处理输入/动画）
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_create_close_button()
	# The dossier is read at a desk, not on a flat backdrop: one warm lamp over
	# the parchment, dust in the beam and a falloff into the archive dark.
	ArchiveUi.install_screen_atmosphere(overlay, {
		"lamp_anchor": Vector2(0.66, 0.50),
		"lamp_strength": 0.20,
		"lamp_radius": 0.58,
		"vignette_strength": 0.60,
		"vignette_radius": 0.34,
		"mote_strength": 0.32,
		"grain_strength": 0.022,
		"layer_index": 0,
	})

	# 按实际游戏窗口排版，避免固定大坐标把内容挤到屏幕边缘。
	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)

	# Only the functional native bars remain. Styling them directly guarantees
	# the thumb, hit target and scroll value can never drift apart.
	var native_list_bar: VScrollBar = list_scroll.get_v_scroll_bar()
	# The native bar is the only scrolling mechanism, but a full-height grabber on
	# a three-record index reads as a much longer list than the case actually has.
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	native_list_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_decor.visible = false
	scroll_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x_visual.visible = false

	_set_custom_scrollbar(native_list_bar)
	_set_custom_scrollbar(detail_text.get_v_scroll_bar())
	_style_static_chrome()
	GameState.state_changed.connect(_on_case_state_changed)

	# 预置示例线索（未解锁的不会显示在列表中）
	for id in CLUE_DEFAULTS:
		clues[id] = CLUE_DEFAULTS[id].duplicate(true)
	_create_archive_pin_button()
	ArchiveUi.decorate_hub(main_panel, {
		"role": "ledger",
		"accent": Color(0.74, 0.54, 0.24, 0.90),
		"rule_y": 14.0,
		"stamp_rect": Rect2(620.0, 70.0, 220.0, 22.0),
		"stamp": "ACTIVE DOSSIER · REVIEW MODE",
	})
	_fit_layout()

	rebuild_list()
	_refresh_chrome()
	_show_home_page()


func _style_static_chrome() -> void:
	ArchiveUi.apply_label(title_label, &"title")
	ArchiveUi.apply_label(journal_subtitle, &"muted")
	ArchiveUi.apply_label(list_header, &"title")
	ArchiveUi.apply_label(list_count_label, &"muted")
	ArchiveUi.apply_label(document_kicker, &"muted")
	ArchiveUi.apply_label(document_title, &"title")
	ArchiveUi.apply_label(document_meta, &"muted")
	# The document page is real parchment, so its data needs dark ink, not the
	# light-on-dark treatment used by the frame and evidence index.
	for label: Label in [document_kicker, document_title, document_meta]:
		label.add_theme_color_override("font_color", INK_MUTED if label != document_title else INK)
	detail_text.add_theme_color_override("default_color", INK)


func _refresh_chrome() -> void:
	title_label.text = _text("CASE LEDGER", "案件档案")
	journal_subtitle.text = _text(
		"Evidence, testimonies and unresolved routes.",
		"证物、证词与尚未解开的路线。"
	)
	list_header.text = _text("EVIDENCE INDEX", "证据索引")
	list_count_label.text = _text("%d RECORDS" % _unlocked_clue_count(), "%d 条记录" % _unlocked_clue_count())


func _unlocked_clue_count() -> int:
	var count := 0
	for entry: Dictionary in clues.values():
		if bool(entry.get("unlocked", false)):
			count += 1
	return count


func _process(_delta: float) -> void:
	pass


func _set_x_hovered(is_over: bool) -> void:
	_x_hovered = is_over
	var target_scale: Vector2 = Vector2(0.089, 0.085) if is_over else Vector2(0.082, 0.078)
	var target_color: Color = Color(1.10, 1.04, 0.88, 1.0) if is_over else Color.WHITE
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(x_visual, "scale", target_scale, 0.12)
	tw.parallel().tween_property(x_visual, "modulate", target_color, 0.12)


func _fit_layout() -> void:
	if main_panel == null:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = clampf(vp_size.x - 64.0, 900.0, 1480.0)
	var panel_h: float = clampf(vp_size.y - 64.0, 640.0, 900.0)
	panel_w = minf(panel_w, vp_size.x - 24.0)
	panel_h = minf(panel_h, vp_size.y - 24.0)
	main_panel.position = (vp_size - Vector2(panel_w, panel_h)) * 0.5
	main_panel.size = Vector2(panel_w, panel_h)

	# One header band, read left to right: what this is, what it holds, what mode
	# it is in, and the way out. No free-floating ornaments compete with it.
	var side: float = 36.0
	var close_size: float = 44.0
	var close_x: float = panel_w - side - close_size
	var stamp_w: float = 220.0
	var stamp_x: float = close_x - 14.0 - stamp_w
	title_label.position = Vector2(side, 18.0)
	title_label.size = Vector2(maxf(160.0, stamp_x - side - 16.0), 30.0)
	journal_subtitle.position = Vector2(side + 2.0, 50.0)
	journal_subtitle.size = Vector2(maxf(160.0, stamp_x - side - 18.0), 20.0)
	title_sep.position = Vector2(side, 82.0)
	title_sep.size = Vector2(panel_w - side * 2.0, 1.0)
	if close_button != null:
		close_button.position = Vector2(close_x, 18.0)
		close_button.size = Vector2(close_size, close_size)
		close_button.pivot_offset = close_button.size * 0.5
	var mode_stamp := main_panel.find_child("HubModeStamp", true, false) as Control
	if mode_stamp != null:
		mode_stamp.position = Vector2(stamp_x, 30.0)
		mode_stamp.size = Vector2(stamp_w, 22.0)

	# Index-first: a narrow evidence index on the left, one dossier page on the
	# right. Both columns share exact top and bottom edges.
	var left_w: float = clampf(panel_w * 0.30, 276.0, 336.0)
	var body_y: float = 100.0
	var body_h: float = panel_h - body_y - 30.0
	left_panel_bg.position = Vector2(side, body_y)
	left_panel_bg.size = Vector2(left_w, body_h)
	list_header.position = Vector2(14.0, 12.0)
	list_header.size = Vector2(left_w - 28.0, 22.0)
	list_count_label.position = Vector2(14.0, 34.0)
	list_count_label.size = Vector2(left_w - 28.0, 16.0)
	list_scroll.position = Vector2(12.0, 58.0)
	list_scroll.size = Vector2(left_w - 24.0, body_h - 70.0)

	var paper_x: float = side + left_w + 22.0
	var paper_w: float = panel_w - paper_x - side
	# The scroll art carries asymmetric transparent padding, so stretching it to
	# a rectangle leaves the painted page visibly out of line with the index.
	# The frame below describes the painted page; the node rect is derived from it.
	var page := Rect2(paper_x, body_y, paper_w, body_h)
	var painted := _painted_uv_rect(parchment.texture)
	var node_size := Vector2(page.size.x / painted.size.x, page.size.y / painted.size.y)
	parchment.position = page.position - Vector2(
		painted.position.x * node_size.x,
		painted.position.y * node_size.y
	)
	parchment.size = node_size
	parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parchment.stretch_mode = TextureRect.STRETCH_SCALE
	parchment.set_meta("hub_artwork_fit", "full_frame_content_safe")

	# Copy is measured against the painted page, not the padded node rect, so the
	# header zone, rule and body keep the same rhythm the index column uses.
	var page_local := page.position - parchment.position
	document_kicker.position = page_local + Vector2(page.size.x * 0.16, page.size.y * 0.105)
	document_kicker.size = Vector2(page.size.x * 0.68, 18.0)
	document_title.position = page_local + Vector2(page.size.x * 0.12, page.size.y * 0.150)
	document_title.size = Vector2(page.size.x * 0.76, page.size.y * 0.085)
	document_meta.position = page_local + Vector2(page.size.x * 0.16, page.size.y * 0.248)
	document_meta.size = Vector2(page.size.x * 0.68, 18.0)
	document_rule.position = page_local + Vector2(page.size.x * 0.18, page.size.y * 0.300)
	document_rule.size = Vector2(page.size.x * 0.64, 1.0)
	parchment_margin.add_theme_constant_override(
		"margin_left", roundi(page_local.x + page.size.x * 0.155)
	)
	parchment_margin.add_theme_constant_override(
		"margin_top", roundi(page_local.y + page.size.y * 0.335)
	)
	parchment_margin.add_theme_constant_override(
		"margin_right",
		roundi(parchment.size.x - page_local.x - page.size.x * 0.845)
	)
	parchment_margin.add_theme_constant_override(
		"margin_bottom",
		roundi(parchment.size.y - page_local.y - page.size.y * 0.915)
	)
	main_panel.pivot_offset = main_panel.size * 0.5


## Fraction of the texture actually painted. Measured once so the layout can
## describe the visible page instead of the artwork's transparent bounding box.
func _painted_uv_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	if _painted_uv_cache.has(texture):
		return _painted_uv_cache[texture] as Rect2
	var uv := Rect2(0.0, 0.0, 1.0, 1.0)
	var image := texture.get_image()
	if image != null and image.get_width() > 0 and image.get_height() > 0:
		var width := image.get_width()
		var height := image.get_height()
		# A soft drop shadow reaches almost every pixel, so a plain used-rect keeps
		# reporting the whole sheet. Only solidly painted pixels define the page.
		var step := maxi(1, roundi(maxf(float(width), float(height)) / 256.0))
		var min_x := width
		var min_y := height
		var max_x := -1
		var max_y := -1
		var y := 0
		while y < height:
			var x := 0
			while x < width:
				if image.get_pixel(x, y).a >= PAINTED_ALPHA_THRESHOLD:
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
				x += step
			y += step
		if max_x >= min_x and max_y >= min_y:
			var texture_size := Vector2(float(width), float(height))
			uv = Rect2(
				Vector2(float(min_x), float(min_y)) / texture_size,
				Vector2(float(max_x - min_x + step), float(max_y - min_y + step)) / texture_size
			)
	_painted_uv_cache[texture] = uv
	return uv


func _set_custom_scrollbar(vbar: VScrollBar) -> void:
	vbar.custom_minimum_size.x = 13.0
	vbar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.025, 0.045, 0.94)
	track.border_color = Color(0.39, 0.28, 0.14, 0.88)
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	vbar.add_theme_stylebox_override("scroll", track)
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = Color(0.57, 0.39, 0.16, 0.98)
	thumb.border_color = Color(0.92, 0.72, 0.32, 0.98)
	thumb.set_border_width_all(1)
	thumb.set_corner_radius_all(5)
	thumb.content_margin_left = 3.0
	thumb.content_margin_right = 3.0
	thumb.content_margin_top = 10.0
	thumb.content_margin_bottom = 10.0
	vbar.add_theme_stylebox_override("grabber", thumb)
	var thumb_hover := thumb.duplicate() as StyleBoxFlat
	thumb_hover.bg_color = Color(0.72, 0.50, 0.20, 1.0)
	thumb_hover.border_color = Color(1.0, 0.84, 0.44, 1.0)
	vbar.add_theme_stylebox_override("grabber_highlight", thumb_hover)
	var thumb_pressed := thumb_hover.duplicate() as StyleBoxFlat
	thumb_pressed.bg_color = Color(0.42, 0.27, 0.11, 1.0)
	vbar.add_theme_stylebox_override("grabber_pressed", thumb_pressed)


func _create_close_button() -> void:
	close_button = Button.new()
	close_button.name = "JournalCloseButton"
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", ArchiveUi.PIXEL_FONT)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", Color(0.93, 0.72, 0.34, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.58, 1.0))
	close_button.add_theme_color_override("font_pressed_color", Color(0.82, 0.56, 0.22, 1.0))
	close_button.add_theme_stylebox_override("normal", _close_button_style(false, false))
	close_button.add_theme_stylebox_override("hover", _close_button_style(true, false))
	close_button.add_theme_stylebox_override("focus", _close_button_style(true, false))
	close_button.add_theme_stylebox_override("pressed", _close_button_style(true, true))
	close_button.pressed.connect(close)
	main_panel.add_child(close_button)


func _close_button_style(highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.20, 0.10, 0.025, 0.98)
		if highlighted else Color(0.075, 0.045, 0.025, 0.96)
	)
	if pressed:
		style.bg_color = Color(0.045, 0.025, 0.018, 1.0)
	style.border_color = (
		Color(1.0, 0.78, 0.31, 1.0)
		if highlighted else Color(0.58, 0.42, 0.20, 0.92)
	)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.45, 0.22, 0.03, 0.30 if highlighted else 0.12)
	style.shadow_size = 7 if highlighted else 3
	return style


## ESC / Tab / K / 点击 X 关闭
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("knowledge_journal"):
		close()
		get_viewport().set_input_as_handled()


## 解锁一条线索（供游戏其他系统调用）
func add_clue(id: String, data: Dictionary = {}) -> void:
	var entry: Dictionary
	if clues.has(id):
		entry = clues[id]
		for key in data:
			entry[key] = data[key]
	else:
		entry = data.duplicate(true)
		if not entry.has("title") and not entry.has("title_key"):
			entry["title"] = id
		if not entry.has("icon"):
			entry["icon"] = "icon_note"
		if not entry.has("content") and not entry.has("content_key"):
			entry["content"] = "[b]" + id + "[/b]"
		if not entry.has("category"):
			entry["category"] = "evidence"
		clues[id] = entry
	entry["unlocked"] = true
	rebuild_list()


## 查询某条线索是否已解锁
func has_clue(id: String) -> bool:
	return clues.has(id) and clues[id].get("unlocked", false)


func get_clues_data() -> Dictionary:
	return clues.duplicate(true)


func set_clues_data(data: Dictionary) -> void:
	clues = data.duplicate(true)
	rebuild_list()


## 开关切换
func toggle() -> void:
	if visible:
		close()
	else:
		open()


## 打开笔记（暂停游戏）
## 打开后默认显示主页欢迎语（不自动选中任何线索）；点击左侧条目才显示详情。
func open() -> void:
	ArchiveUi.set_hub_entries_suppressed(true)
	visible = true
	overlay.visible = true
	rebuild_list()
	_refresh_chrome()
	_show_home_page()
	_play_open_transition()
	get_tree().paused = true
	call_deferred("_focus_first_record")


## 关闭笔记（立即恢复，避免 Tween 未执行时留下暂停状态）
func close() -> void:
	if not visible:
		return
	visible = false
	overlay.visible = false
	main_panel.modulate = Color(1, 1, 1, 1)
	main_panel.scale = Vector2.ONE
	_x_hovered = false
	get_tree().paused = false
	ArchiveUi.set_hub_entries_suppressed(false)


## 重建左侧线索列表（只显示已解锁的；防并发重入）
func rebuild_list() -> void:
	if _rebuilding:
		_rebuild_dirty = true
		return
	_rebuilding = true
	# 清空旧按钮
	for child in list_box.get_children():
		child.queue_free()
	_buttons.clear()
	await get_tree().process_frame

	for id in clues:
		var entry: Dictionary = clues[id]
		if not entry.get("unlocked", false):
			continue
		# 实例化按钮模板（TextureButton 保持比例居中 + 图标 + 标题）
		var btn: TextureButton = CLUE_ITEM_SCENE.instantiate()
		btn.texture_normal = load(BTN_NORMAL)
		btn.texture_hover = load(BTN_HOVER)
		btn.texture_pressed = load(BTN_NORMAL)
		# 图标
		var icon_path: String = CLUE_ICONS.get(entry.get("icon", "icon_note"), CLUE_ICONS["icon_note"])
		var icon_tex: Texture2D = load(icon_path)
		if icon_tex != null:
			btn.get_node("Layout/Icon").texture = icon_tex
		# 标题
		(btn.get_node("Layout/Title") as Label).text = _localized_clue_title(id, entry)
		# 点击 → 显示详情
		btn.pressed.connect(func() -> void: _select_clue(id))
		list_box.add_child(btn)
		_buttons[id] = btn
		# 恢复选中高亮
		_update_button_visual(id)

	_rebuilding = false
	_refresh_chrome()
	_wire_list_focus()
	if _rebuild_dirty:
		_rebuild_dirty = false
		rebuild_list()


## 清空所有按钮的选中高亮（用于主页状态）
func _clear_selection_visual() -> void:
	for btn_id in _buttons:
		_update_button_visual(btn_id)


## 选中第一条已解锁线索
func _select_first_unlocked() -> void:
	for id in clues:
		if clues[id].get("unlocked", false):
			_select_clue(id)
			return


## 选中一条线索：右侧羊皮纸显示详情 + 按钮高亮
func _select_clue(id: String) -> void:
	if not clues.has(id):
		return
	_selected_id = id
	var entry: Dictionary = clues[id]
	_apply_document_header(id, entry)
	detail_text.text = _document_body(id, entry)
	detail_text.scroll_to_line(0)
	for btn_id in _buttons:
		_update_button_visual(btn_id)
	_refresh_archive_pin_button()
	_wire_list_focus()


func _create_archive_pin_button() -> void:
	archive_pin_button = Button.new()
	archive_pin_button.name = "SealedArchivePinButton"
	archive_pin_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	archive_pin_button.offset_left = -118.0
	archive_pin_button.offset_top = -76.0
	archive_pin_button.offset_right = 118.0
	archive_pin_button.offset_bottom = -32.0
	archive_pin_button.pivot_offset = Vector2(118.0, 22.0)
	archive_pin_button.visible = false
	archive_pin_button.mouse_filter = Control.MOUSE_FILTER_STOP
	archive_pin_button.focus_mode = Control.FOCUS_ALL
	archive_pin_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	archive_pin_button.tooltip_text = _text(
		"Place this sealed archive on the analysis table.",
		"将这份密封档案放到分析圆桌。"
	)
	_apply_archive_pin_button_style()
	_create_archive_pin_button_contents()
	archive_pin_button.pressed.connect(_toggle_selected_sealed_archive_pin)
	archive_pin_button.button_down.connect(_set_archive_pin_pressed.bind(true))
	archive_pin_button.button_up.connect(_set_archive_pin_pressed.bind(false))
	parchment.add_child(archive_pin_button)
	CaseLocale.locale_changed.connect(_on_locale_changed)


func _create_archive_pin_button_contents() -> void:
	archive_pin_inlay = Panel.new()
	archive_pin_inlay.name = "WoodInlay"
	archive_pin_inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	archive_pin_inlay.offset_left = 3.0
	archive_pin_inlay.offset_top = 3.0
	archive_pin_inlay.offset_right = -3.0
	archive_pin_inlay.offset_bottom = -3.0
	archive_pin_inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_pin_button.add_child(archive_pin_inlay)

	archive_pin_mark = ColorRect.new()
	archive_pin_mark.name = "StatusMark"
	archive_pin_mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	archive_pin_mark.offset_left = 9.0
	archive_pin_mark.offset_top = 11.0
	archive_pin_mark.offset_right = 13.0
	archive_pin_mark.offset_bottom = -11.0
	archive_pin_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_pin_button.add_child(archive_pin_mark)

	var count_rule := ColorRect.new()
	count_rule.name = "CountRule"
	count_rule.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	count_rule.offset_left = -52.0
	count_rule.offset_top = 11.0
	count_rule.offset_right = -51.0
	count_rule.offset_bottom = -11.0
	count_rule.color = Color(0.64, 0.42, 0.15, 0.52)
	count_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_pin_button.add_child(count_rule)

	archive_pin_label = Label.new()
	archive_pin_label.name = "ActionLabel"
	archive_pin_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	archive_pin_label.offset_left = 22.0
	archive_pin_label.offset_right = -58.0
	archive_pin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_pin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	archive_pin_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	archive_pin_label.clip_text = true
	archive_pin_label.add_theme_font_override("font", ArchiveUi.PIXEL_FONT)
	archive_pin_label.add_theme_font_size_override("font_size", 11)
	archive_pin_label.add_theme_color_override("font_outline_color", Color(0.035, 0.016, 0.005, 0.95))
	archive_pin_label.add_theme_constant_override("outline_size", 1)
	archive_pin_button.add_child(archive_pin_label)

	archive_pin_count_label = Label.new()
	archive_pin_count_label.name = "CountLabel"
	archive_pin_count_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	archive_pin_count_label.offset_left = -48.0
	archive_pin_count_label.offset_right = -8.0
	archive_pin_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_pin_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_pin_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	archive_pin_count_label.add_theme_font_override("font", ArchiveUi.PIXEL_FONT)
	archive_pin_count_label.add_theme_font_size_override("font_size", 10)
	archive_pin_count_label.add_theme_color_override("font_outline_color", Color(0.035, 0.016, 0.005, 0.95))
	archive_pin_count_label.add_theme_constant_override("outline_size", 1)
	archive_pin_button.add_child(archive_pin_count_label)


func _apply_archive_pin_button_style() -> void:
	archive_pin_button.add_theme_stylebox_override("normal", _pin_button_style(PIN_WALNUT, PIN_BRASS, 2))
	archive_pin_button.add_theme_stylebox_override("hover", _pin_button_style(PIN_WALNUT_HOVER, PIN_BRASS_HOVER, 2))
	archive_pin_button.add_theme_stylebox_override("pressed", _pin_button_style(Color(0.090, 0.044, 0.014, 1.0), PIN_BRASS_HOVER, 2))
	archive_pin_button.add_theme_stylebox_override("disabled", _pin_button_style(Color(0.080, 0.060, 0.042, 0.78), Color(0.36, 0.30, 0.22, 0.82), 1))
	archive_pin_button.add_theme_stylebox_override("focus", _pin_focus_style())


func _pin_button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.shadow_color = Color(0.015, 0.006, 0.002, 0.72)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


func _pin_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 0.88, 0.48, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 1.0
	style.content_margin_top = 1.0
	style.content_margin_right = 1.0
	style.content_margin_bottom = 1.0
	return style


func _on_locale_changed(_language: String) -> void:
	# The list carries titles too, so a language switch has to redraw both panes.
	rebuild_list()
	if not _selected_id.is_empty() and clues.has(_selected_id):
		_select_clue(_selected_id)


func _localized_clue_title(id: String, entry: Dictionary) -> String:
	if entry.has("title_key"):
		return CaseLocale.text(str(entry["title_key"]))
	return str(entry.get("title", id))


func _refresh_archive_pin_button() -> void:
	if archive_pin_button == null:
		return
	var is_sealed_archive := SEALED_ARCHIVE_IDS.has(_selected_id)
	archive_pin_button.visible = is_sealed_archive
	if not is_sealed_archive:
		return
	var pinned := GameState.has_story_flag("sealed_archive_pinned_" + _selected_id)
	var count := _sealed_archive_pin_count()
	archive_pin_label.text = (
		("REMOVE PIN" if pinned else "PIN TO TABLE")
		if not CaseLocale.is_chinese()
		else ("移除钉选" if pinned else "钉选到圆桌")
	)
	archive_pin_label.add_theme_font_override(
		"font", ArchiveUi.ARCHIVE_FONT if CaseLocale.is_chinese() else ArchiveUi.PIXEL_FONT
	)
	archive_pin_count_label.text = "%d / 3" % count
	archive_pin_label.add_theme_color_override("font_color", PIN_TEXT_ACTIVE if pinned else PIN_TEXT)
	archive_pin_count_label.add_theme_color_override("font_color", PIN_TEXT_ACTIVE if pinned else PIN_TEXT)
	archive_pin_mark.color = Color(0.44, 0.80, 0.38, 1.0) if pinned else PIN_BRASS
	archive_pin_inlay.add_theme_stylebox_override(
		"panel", _pin_inlay_style(PIN_MOSS if pinned else PIN_WALNUT, pinned)
	)
	archive_pin_button.tooltip_text = _text(
		"Remove this archive from the analysis table." if pinned else "Place this sealed archive on the analysis table.",
		"将这份档案从分析圆桌移除。" if pinned else "将这份密封档案放到分析圆桌。"
	)


func _pin_inlay_style(fill: Color, pinned: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.52, 0.76, 0.42, 0.52) if pinned else Color(0.36, 0.20, 0.065, 0.85)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	return style


func _toggle_selected_sealed_archive_pin() -> void:
	if not SEALED_ARCHIVE_IDS.has(_selected_id):
		return
	var flag_id := "sealed_archive_pinned_" + _selected_id
	GameState.set_story_flag(flag_id, not GameState.has_story_flag(flag_id))
	_refresh_archive_pin_button()
	_apply_document_header(_selected_id, clues.get(_selected_id, {}))
	_pulse_control(archive_pin_button, true)


func _set_archive_pin_pressed(pressed: bool) -> void:
	if archive_pin_button == null or archive_pin_button.disabled:
		return
	if _archive_pin_tween != null and _archive_pin_tween.is_valid():
		_archive_pin_tween.kill()
	_archive_pin_tween = archive_pin_button.create_tween()
	_archive_pin_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_archive_pin_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_archive_pin_tween.tween_property(
		archive_pin_button,
		"scale",
		Vector2(0.975, 0.985) if pressed else Vector2.ONE,
		0.06 if pressed else 0.12
	)


func _sealed_archive_pin_count() -> int:
	var count := 0
	for archive_id: String in SEALED_ARCHIVE_IDS:
		if GameState.has_story_flag("sealed_archive_pinned_" + archive_id):
			count += 1
	return count


func all_sealed_archives_pinned() -> bool:
	return _sealed_archive_pin_count() == SEALED_ARCHIVE_IDS.size()


func _show_home_page() -> void:
	_selected_id = ""
	_clear_selection_visual()
	document_kicker.text = _text("CASE LEDGER", "案件档案")
	document_title.text = _text("Investigation Notes", "调查笔记")
	document_meta.text = _text(
		"%d RECORDS  ·  %d/3 SEALED ARCHIVES PINNED"
		% [_unlocked_clue_count(), _sealed_archive_pin_count()],
		"%d 条记录  ·  密封档案已钉选 %d/3"
		% [_unlocked_clue_count(), _sealed_archive_pin_count()]
	)
	detail_text.text = _text(
		"[center][font_size=18][b]ACTIVE CASE FILE[/b][/font_size]\n\n"
		+ "RECORDS FILED  ·  %d\n" % _unlocked_clue_count()
		+ "SEALED ARCHIVES PINNED  ·  %d / 3\n\n" % _sealed_archive_pin_count()
		+ "[color=#6a3f17]1 · SELECT[/color] a record from the index\n"
		+ "[color=#6a3f17]2 · REVIEW[/color] its complete evidence text\n"
		+ "[color=#6a3f17]3 · PIN[/color] sealed archives to the analysis table\n\n"
		+ "Every conclusion remains outside this ledger until the final deduction.[/center]",
		"[center][font_size=18][b]当前案件档案[/b][/font_size]\n\n"
		+ "已归档记录 · %d\n" % _unlocked_clue_count()
		+ "密封档案已钉选 · %d / 3\n\n" % _sealed_archive_pin_count()
		+ "[color=#6a3f17]1 · 选择[/color] 左侧的一条记录\n"
		+ "[color=#6a3f17]2 · 阅读[/color] 完整证物内容\n"
		+ "[color=#6a3f17]3 · 钉选[/color] 密封档案到分析圆桌\n\n"
		+ "最终推理开始前，本档案不会替玩家形成结论。[/center]"
	)
	detail_text.scroll_to_line(0)
	_refresh_archive_pin_button()


func _apply_document_header(id: String, entry: Dictionary) -> void:
	document_kicker.text = _category_label(str(entry.get("category", "evidence")))
	document_title.text = _localized_clue_title(id, entry)
	if SEALED_ARCHIVE_IDS.has(id):
		var pinned := GameState.has_story_flag("sealed_archive_pinned_" + id)
		document_meta.text = _text(
			"ANALYSIS TABLE  ·  %d/3 PINNED" % _sealed_archive_pin_count(),
			"分析圆桌  ·  已钉选 %d/3" % _sealed_archive_pin_count()
		) if pinned else _text("SEALED ARCHIVE  ·  READY TO PIN", "密封档案  ·  可钉选")
	else:
		document_meta.text = _text("CASE RECORD  ·  REVIEWED", "案件记录  ·  已阅览")


func _category_label(category: String) -> String:
	match category:
		"archive":
			return _text("SEALED ARCHIVE", "密封档案")
		"lore":
			return _text("FIELD NOTE", "现场笔记")
		"character":
			return _text("WITNESS RECORD", "证词记录")
		_:
			return _text("EVIDENCE RECORD", "证物记录")


func _wire_list_focus() -> void:
	var items: Array[TextureButton] = []
	for child: Node in list_box.get_children():
		if child is TextureButton:
			items.append(child as TextureButton)
	for index: int in items.size():
		var item := items[index]
		item.focus_neighbor_top = items[maxi(0, index - 1)].get_path()
		item.focus_neighbor_bottom = items[mini(items.size() - 1, index + 1)].get_path()
		if item == _buttons.get(_selected_id) and archive_pin_button != null and archive_pin_button.visible:
			item.focus_neighbor_right = archive_pin_button.get_path()
			archive_pin_button.focus_neighbor_left = item.get_path()


func _focus_first_record() -> void:
	for child: Node in list_box.get_children():
		if child is TextureButton:
			(child as TextureButton).grab_focus()
			return


func _play_open_transition() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	main_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	main_panel.scale = Vector2(0.985, 0.985)
	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(main_panel, "modulate:a", 1.0, 0.14)
	_open_tween.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.18)


func _pulse_control(control: Control, success: bool) -> void:
	if control == null or not is_instance_valid(control):
		return
	var base := Vector2.ONE
	var pulse := Vector2(1.028, 1.028) if success else Vector2(0.978, 1.018)
	control.scale = base
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", pulse, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_case_state_changed() -> void:
	if not visible:
		return
	_refresh_chrome()
	_refresh_archive_pin_button()
	if not _selected_id.is_empty() and clues.has(_selected_id):
		_apply_document_header(_selected_id, clues[_selected_id])


func _document_body(id: String, entry: Dictionary) -> String:
	var content := _localized_clue_content(id, entry)
	# Legacy records often begin with a decorative centre heading. The dossier page
	# now owns the title, so omitting that first display-only line restores a clean
	# reading rhythm without mutating the record saved in the player's game.
	if content.begins_with("[center][b]"):
		var heading_end := content.find("[/center]")
		if heading_end >= 0:
			content = content.substr(heading_end + "[/center]".length()).strip_edges()
	return "[center]" + content + "[/center]"


func _text(english: String, chinese: String) -> String:
	return chinese if CaseLocale.is_chinese() else english


func _localized_clue_content(id: String, entry: Dictionary) -> String:
	if entry.has("content_key"):
		return CaseLocale.text(str(entry["content_key"]))
	if not CaseLocale.is_chinese():
		return str(entry.get("content", ""))
	var chinese_content: Dictionary = {
		"sealed_archive_pressure": "[center][b]密封档案 I — 私人服务附录[/b][/center]\n\n藏在服务账本下方的信件记录了管家多年前因一次安全事故被降职。机械办公室曾许诺帮他恢复职位，条件是完整执行一次紧急隔离命令，不许追问。\n\n命令声称阿什福德圆桌的力场会保护林博士。管家后来留下的笔记只写了一句：[color=#4a306d]“是我启动了装置。我以为自己是在保护她。”[/color]\n\n这说明了他的压力与行为，却没有说明命令的作者。",
		"sealed_archive_instruction": "[center][b]密封档案 II — 伪造的紧急指令[/b][/center]\n\n设备柜的夹层里藏着一张复写指令：“将林博士带到分析圆桌。启动隔离力场。不得中断校准。”\n\n它的安全编码属于机械办公室，但手写的路由标记是在归档后添加的。压力印章被刮去，下面残留的紫色石墨痕迹与机械师工作台的铅笔一致。\n\n管家收到的是一份看似正式的命令。有人利用维修权限伪造了命令链。",
		"sealed_archive_lin_decision": "[center][b]密封档案 III — 林博士的决定[/b][/center]\n\n林博士未署名的备忘录证实，她拒绝了机械师提出的独立资助与完整知识引擎蓝图访问权限。她发现了未经授权的维修副本，因此在分析圆桌上安排了一次受控验证，想追出下达指令的人。\n\n最后的页边笔记写道：[color=#4a306d]“管家害怕，却并不隐瞒。如果紧急命令送到他手中，必须先核验它的路由标记。”[/color]\n\n林博士预料到会有伪造指令；她没有预料到隔离力场会变成致命装置。那个想让她沉默的人，也想让她的研究成果被记在自己名下。",
	}
	return str(chinese_content.get(id, entry.get("content", "")))


## 切换按钮选中状态：保留原始木牌贴图，只显示不遮挡内容的细金色侧标记。
func _update_button_visual(id: String) -> void:
	var btn: TextureButton = _buttons.get(id)
	if btn == null:
		return
	var selected: bool = id == _selected_id
	btn.texture_normal = load(BTN_NORMAL)
	btn.texture_hover = load(BTN_HOVER)
	btn.texture_pressed = load(BTN_NORMAL)

	if btn.has_method("set_selected"):
		btn.call("set_selected", selected)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.98, 0.98, 0.98, 1.0)


## 导出线索数据为 JSON（默认 user://clue_journal.json）
func save_to_json(path: String = "user://clue_journal.json") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(clues, "\t"))
	f.close()
	return true


## 从 JSON 加载线索数据（覆盖当前数据）
func load_from_json(path: String = "user://clue_journal.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	clues = parsed
	rebuild_list()
	return true
