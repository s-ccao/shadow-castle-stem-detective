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

# 主页欢迎语（打开笔记默认显示，不自动选中任何线索）
const DEFAULT_HOME_TEXT := "[center][b]Your Notebook[/b][/center]\n\n[center]Carry this notebook with you — it will help you keep a record of everything you have collected, so you can review it anytime.[/center]"

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

@onready var title_label: Label = %TitleLabel
@onready var list_box: VBoxContainer = %ListBox
@onready var detail_text: RichTextLabel = %DetailText
@onready var overlay: ColorRect = $Overlay
@onready var main_panel: Panel = $MainPanel
@onready var scroll_decor: VScrollBar = %ScrollBarDecor
@onready var x_visual: Sprite2D = $MainPanel/XVisual
@onready var left_panel_bg: Panel = $MainPanel/LeftPanelBg
@onready var list_scroll: ScrollContainer = %ListScroll
@onready var parchment: TextureRect = $MainPanel/Parchment
@onready var parchment_margin: MarginContainer = $MainPanel/Parchment/ParchMargin
@onready var title_sep: ColorRect = $MainPanel/TitleSep
@onready var title_sep_sprite: Sprite2D = $MainPanel/TitleSep/Sprite2D


func _ready() -> void:
	# 暂停期间本界面仍然运行（处理输入/动画）
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# 按实际游戏窗口排版，避免固定大坐标把内容挤到屏幕边缘。
	_fit_layout()
	get_viewport().size_changed.connect(_fit_layout)

	# 原生滚动条只负责滚轮/键盘滚动；视觉上使用右侧的细装饰条，
	# 避免两个滚动条叠在一起形成多余的“墙框”。
	var native_list_bar: VScrollBar = list_scroll.get_v_scroll_bar()
	native_list_bar.visible = false
	native_list_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 装饰滚动条（金色轨道 + 低亮度蓝色滑块）与列表滚动同步
	scroll_decor.value_changed.connect(func(v: float) -> void:
		list_scroll.scroll_vertical = int(v)
	)
	var lv: VScrollBar = list_scroll.get_v_scroll_bar()
	lv.value_changed.connect(func(v: float) -> void:
		scroll_decor.value = v
	)

	# 滚动条使用自定义贴图
	_set_custom_scrollbar(lv)
	_set_custom_scrollbar(detail_text.get_v_scroll_bar())

	# 预置示例线索（未解锁的不会显示在列表中）
	for id in CLUE_DEFAULTS:
		clues[id] = CLUE_DEFAULTS[id].duplicate(true)
	_create_archive_pin_button()

	rebuild_list()


func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var is_over: bool = mouse_pos.distance_to(x_visual.global_position) <= 46.0
	if is_over != _x_hovered:
		_set_x_hovered(is_over)


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

	# 顶部：标题、细分隔线、关闭按钮各自有安全边距。
	title_label.position = Vector2(0, 24)
	title_label.size = Vector2(panel_w, 54)
	title_sep.position = Vector2(32, 94)
	title_sep.size = Vector2(panel_w - 64, 2)
	title_sep_sprite.position = Vector2((panel_w - 64) * 0.5, 1)
	x_visual.position = Vector2(panel_w - 88, 52)

	# 主体：左栏约 1/3，右侧羊皮纸约 2/3，中间只留一条细分隔。
	var left_w: float = clampf(panel_w * 0.34, 304.0, 390.0)
	var left_x: float = 40.0
	var body_y: float = 128.0
	var body_h: float = panel_h - 152.0
	var left_h: float = minf(body_h, 460.0)
	left_panel_bg.position = Vector2(left_x, body_y)
	left_panel_bg.size = Vector2(left_w, left_h)
	list_scroll.position = Vector2(12, 56)
	list_scroll.size = Vector2(left_w - 24.0, left_h - 68.0)

	scroll_decor.position = Vector2(left_x + left_w + 14.0, body_y + 56.0)
	scroll_decor.size = Vector2(16, left_h - 56.0)

	var paper_x: float = left_x + left_w + 52.0
	var paper_w: float = panel_w - paper_x - 32.0
	var paper_h: float = body_h
	parchment.position = Vector2(paper_x, body_y - 2.0)
	parchment.size = Vector2(paper_w, paper_h)
	# 文字只进入羊皮纸的干净中部，不贴近破损边缘/木轴。
	parchment_margin.add_theme_constant_override("margin_left", 112)
	parchment_margin.add_theme_constant_override("margin_top", 68)
	parchment_margin.add_theme_constant_override("margin_right", 112)
	parchment_margin.add_theme_constant_override("margin_bottom", 120)

	$MainPanel/StarTL.position = Vector2(170, 98)
	$MainPanel/StarTR.position = Vector2(panel_w - 170, 98)


func _set_custom_scrollbar(vbar: VScrollBar) -> void:
	var track := StyleBoxTexture.new()
	track.texture = load("res://assets/ui/ui_note_scrollbar_track.png")
	track.texture_margin_left = 6.0
	track.texture_margin_right = 6.0
	track.texture_margin_top = 6.0
	track.texture_margin_bottom = 6.0
	vbar.add_theme_stylebox_override("scroll", track)
	var thumb := StyleBoxTexture.new()
	thumb.texture = load("res://assets/ui/ui_note_scrollbar_thumb.png")
	thumb.texture_margin_left = 6.0
	thumb.texture_margin_right = 6.0
	thumb.texture_margin_top = 6.0
	thumb.texture_margin_bottom = 6.0
	vbar.add_theme_stylebox_override("grabber", thumb)


## ESC / Tab / K / 点击 X 关闭
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 点击 Sprite2D 的 X（外观由用户在场景里自由调整）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var gp: Vector2 = x_visual.global_position
		if absf(event.position.x - gp.x) < 55.0 and absf(event.position.y - gp.y) < 55.0:
			close()
			get_viewport().set_input_as_handled()
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
		if not entry.has("title"):
			entry["title"] = id
		if not entry.has("icon"):
			entry["icon"] = "icon_note"
		if not entry.has("content"):
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
	visible = true
	overlay.visible = true
	rebuild_list()
	# 主页状态：清空选中，羊皮纸显示欢迎语
	_selected_id = ""
	_clear_selection_visual()
	detail_text.text = DEFAULT_HOME_TEXT
	detail_text.scroll_to_line(0)
	# 直接设置最终状态，不依赖暂停树中的淡入 Tween。
	main_panel.modulate = Color(1, 1, 1, 1)
	main_panel.scale = Vector2.ONE
	get_tree().paused = true


## 关闭笔记（立即恢复，避免 Tween 未执行时留下暂停状态）
func close() -> void:
	if not visible:
		return
	visible = false
	overlay.visible = false
	main_panel.modulate = Color(1, 1, 1, 1)
	main_panel.scale = Vector2.ONE
	_x_hovered = false
	x_visual.scale = Vector2(0.082, 0.078)
	x_visual.modulate = Color.WHITE
	get_tree().paused = false


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
		(btn.get_node("Layout/Title") as Label).text = entry.get("title", id)
		# 点击 → 显示详情
		btn.pressed.connect(func() -> void: _select_clue(id))
		list_box.add_child(btn)
		_buttons[id] = btn
		# 恢复选中高亮
		_update_button_visual(id)

	_rebuilding = false
	# 同步装饰滚动条的范围（条目数量变化后）
	var lv: VScrollBar = %ListScroll.get_v_scroll_bar()
	scroll_decor.max_value = maxf(lv.max_value, 0.0)
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
	_selected_id = id
	var entry: Dictionary = clues[id]
	detail_text.text = _localized_clue_content(id, entry)
	detail_text.scroll_to_line(0)
	for btn_id in _buttons:
		_update_button_visual(btn_id)
	_refresh_archive_pin_button()


func _create_archive_pin_button() -> void:
	archive_pin_button = Button.new()
	archive_pin_button.name = "SealedArchivePinButton"
	archive_pin_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	archive_pin_button.offset_left = -138.0
	archive_pin_button.offset_top = -84.0
	archive_pin_button.offset_right = 138.0
	archive_pin_button.offset_bottom = -40.0
	archive_pin_button.add_theme_font_size_override("font_size", 11)
	archive_pin_button.visible = false
	ArchiveUi.apply_button(archive_pin_button, ArchiveUi.ROLE_ARCHIVE)
	archive_pin_button.pressed.connect(_toggle_selected_sealed_archive_pin)
	parchment.add_child(archive_pin_button)
	CaseLocale.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_language: String) -> void:
	if not _selected_id.is_empty() and clues.has(_selected_id):
		_select_clue(_selected_id)


func _refresh_archive_pin_button() -> void:
	if archive_pin_button == null:
		return
	var is_sealed_archive := SEALED_ARCHIVE_IDS.has(_selected_id)
	archive_pin_button.visible = is_sealed_archive
	if not is_sealed_archive:
		return
	var pinned := GameState.has_story_flag("sealed_archive_pinned_" + _selected_id)
	var count := _sealed_archive_pin_count()
	archive_pin_button.text = (
		("REMOVE FROM ANALYSIS TABLE" if pinned else "PIN TO ANALYSIS TABLE")
		if not CaseLocale.is_chinese()
		else ("从分析圆桌移除" if pinned else "钉选到分析圆桌")
	) + "  ·  %d/3" % count
	ArchiveUi.set_button_status(archive_pin_button, &"success" if pinned else &"default")


func _toggle_selected_sealed_archive_pin() -> void:
	if not SEALED_ARCHIVE_IDS.has(_selected_id):
		return
	var flag_id := "sealed_archive_pinned_" + _selected_id
	GameState.set_story_flag(flag_id, not GameState.has_story_flag(flag_id))
	_refresh_archive_pin_button()


func _sealed_archive_pin_count() -> int:
	var count := 0
	for archive_id: String in SEALED_ARCHIVE_IDS:
		if GameState.has_story_flag("sealed_archive_pinned_" + archive_id):
			count += 1
	return count


func all_sealed_archives_pinned() -> bool:
	return _sealed_archive_pin_count() == SEALED_ARCHIVE_IDS.size()


func _localized_clue_content(id: String, entry: Dictionary) -> String:
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
