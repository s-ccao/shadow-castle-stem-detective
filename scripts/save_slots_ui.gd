class_name SaveSlotsUi
extends CanvasLayer

## “查看存档”界面。
##
## 这个游戏原本只有一个自动存档位，开新案件会把它删掉，玩家没有任何办法回到
## 上一轮。现在每到一个新房间会留一张快照，开新档之前也会留一张，这一屏就是
## 翻看和载入它们的地方。
##
## 对外只有三件事：open / close / slots_changed 之后自己刷新。列表里的每一行
## 都直接从快照文件里读，不另存一份摘要——摘要迟早会和存档本身对不上。

signal closed
signal slot_loaded(scene_path: String)

const LAYER := 95
const PANEL_SIZE := Vector2(760.0, 560.0)
const ROW_HEIGHT := 76.0
const ROW_GAP := 8.0

var overlay: ColorRect
var frame: Panel
var title_label: Label
var hint_label: Label
var scroll: ScrollContainer
var rows: VBoxContainer
var empty_label: Label
var close_button: Button
var confirm_path: String = ""


func _ready() -> void:
	name = "SaveSlotsUI"
	layer = LAYER
	# 主菜单不暂停，但这一屏要能盖住并接管输入。
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	visible = true
	_refresh()
	close_button.call_deferred("grab_focus")


func close() -> void:
	visible = false
	confirm_path = ""
	closed.emit()


func _build() -> void:
	overlay = ColorRect.new()
	overlay.color = ArchiveUi.COLOR_VOID
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.size = PANEL_SIZE
	frame.position = -PANEL_SIZE * 0.5
	frame.add_theme_stylebox_override("panel", ArchiveUi.panel_style(
		ArchiveUi.COLOR_PANEL,
		ArchiveUi.COLOR_BRASS,
		2,
		6
	))
	overlay.add_child(frame)

	title_label = Label.new()
	title_label.position = Vector2(28.0, 22.0)
	title_label.size = Vector2(PANEL_SIZE.x - 56.0, 30.0)
	ArchiveUi.apply_label(title_label, &"title")
	frame.add_child(title_label)

	hint_label = Label.new()
	hint_label.position = Vector2(28.0, 58.0)
	hint_label.size = Vector2(PANEL_SIZE.x - 56.0, 40.0)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ArchiveUi.apply_label(hint_label, &"muted")
	frame.add_child(hint_label)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(24.0, 108.0)
	scroll.size = Vector2(PANEL_SIZE.x - 48.0, PANEL_SIZE.y - 180.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", int(ROW_GAP))
	scroll.add_child(rows)

	empty_label = Label.new()
	empty_label.position = Vector2(28.0, 200.0)
	empty_label.size = Vector2(PANEL_SIZE.x - 56.0, 60.0)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ArchiveUi.apply_label(empty_label, &"muted")
	frame.add_child(empty_label)

	close_button = Button.new()
	close_button.size = Vector2(150.0, 40.0)
	close_button.position = Vector2(PANEL_SIZE.x - 178.0, PANEL_SIZE.y - 56.0)
	ArchiveUi.apply_button(close_button, ArchiveUi.ROLE_MUTED)
	close_button.pressed.connect(close)
	frame.add_child(close_button)


func _refresh() -> void:
	var chinese: bool = CaseLocale.is_chinese()
	title_label.text = "存档记录" if chinese else "SAVE RECORDS"
	hint_label.text = (
		"每次抵达新的房间都会自动留下一张存档，开始新案件之前也会先留一张。"
		+ "选择任意一张即可回到那一刻。"
	) if chinese else (
		"A record is kept every time you reach a new room, and one more is kept "
		+ "before a new case begins. Pick any of them to return to that moment."
	)
	close_button.text = "返回" if chinese else "BACK"

	for child: Node in rows.get_children():
		child.queue_free()

	var slots: Array[Dictionary] = SaveSlots.list()
	empty_label.visible = slots.is_empty()
	if slots.is_empty():
		empty_label.text = (
			"还没有任何存档记录。开始一局案件之后，这里会自动积累。"
		) if chinese else (
			"No records yet. They start collecting once a case is under way."
		)
		return

	for slot: Dictionary in slots:
		rows.add_child(_build_row(slot, chinese))


func _build_row(slot: Dictionary, chinese: bool) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", ArchiveUi.panel_style(
		ArchiveUi.COLOR_PANEL_INLAY,
		ArchiveUi.COLOR_BRASS,
		1,
		4
	))

	var heading := Label.new()
	heading.position = Vector2(16.0, 10.0)
	heading.size = Vector2(430.0, 24.0)
	heading.text = _room_title(slot, chinese)
	ArchiveUi.apply_label(heading, &"body")
	row.add_child(heading)

	var detail := Label.new()
	detail.position = Vector2(16.0, 40.0)
	detail.size = Vector2(430.0, 24.0)
	detail.text = _detail_line(slot, chinese)
	ArchiveUi.apply_label(detail, &"muted")
	row.add_child(detail)

	var load_button := Button.new()
	load_button.size = Vector2(120.0, 38.0)
	load_button.position = Vector2(PANEL_SIZE.x - 48.0 - 152.0, 19.0)
	load_button.text = "载入" if chinese else "LOAD"
	ArchiveUi.apply_button(load_button, ArchiveUi.ROLE_ACTION)
	load_button.pressed.connect(_on_load_pressed.bind(str(slot.get("path", ""))))
	row.add_child(load_button)

	return row


func _room_title(slot: Dictionary, chinese: bool) -> String:
	var room_id: String = str(slot.get("room_id", ""))
	var room: String = CaseLocale.room_name(room_id) if not room_id.is_empty() else (
		"未知位置" if chinese else "Unknown location"
	)
	if str(slot.get("reason", "")) == SaveSlots.REASON_NEW_CASE:
		return room + ("　·　开新案件前" if chinese else "  ·  before a new case")
	return room


func _detail_line(slot: Dictionary, chinese: bool) -> String:
	var when: String = _when(int(slot.get("saved_at", 0)), chinese)
	if chinese:
		return "%s　·　声望 %d　·　证据 %d　·　知识 %d" % [
			when,
			int(slot.get("reputation", 0)),
			int(slot.get("evidence", 0)),
			int(slot.get("knowledge", 0)),
		]
	return "%s  ·  rep %d  ·  %d evidence  ·  %d knowledge" % [
		when,
		int(slot.get("reputation", 0)),
		int(slot.get("evidence", 0)),
		int(slot.get("knowledge", 0)),
	]


## 存的是 Unix 时间，直接显示秒数没人看得懂；换成“多久以前”，这也是玩家真正
## 想知道的——哪一张更近。
func _when(saved_at: int, chinese: bool) -> String:
	if saved_at <= 0:
		return "时间未知" if chinese else "time unknown"
	var delta: int = int(Time.get_unix_time_from_system()) - saved_at
	if delta < 90:
		return "刚刚" if chinese else "just now"
	if delta < 3600:
		var minutes: int = int(delta / 60.0)
		return ("%d 分钟前" % minutes) if chinese else ("%d min ago" % minutes)
	if delta < 86400:
		var hours: int = int(delta / 3600.0)
		return ("%d 小时前" % hours) if chinese else ("%d h ago" % hours)
	var days: int = int(delta / 86400.0)
	return ("%d 天前" % days) if chinese else ("%d d ago" % days)


func _on_load_pressed(path: String) -> void:
	if path.is_empty():
		return
	if not GameState.restore_save_slot(path):
		hint_label.text = (
			"这张存档读不出来，可能已经损坏。其它几张仍然可用。"
		) if CaseLocale.is_chinese() else (
			"That record could not be read. The others are still fine."
		)
		return
	var scene_path: String = GameState.resume_scene_path
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://scenes/wake_room.tscn"
	visible = false
	slot_loaded.emit(scene_path)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
