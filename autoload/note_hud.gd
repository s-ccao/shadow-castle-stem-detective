extends CanvasLayer

## NoteHud — 全局侦探笔记入口（autoload 单例）
## 平时安静驻留；悬停显示柔和光圈和 "note"，点击有轻微回弹。

const JOURNAL_SCENE: PackedScene = preload("res://scenes/clue_journal.tscn")
const HUB_ENTRY_POSITION: Vector2 = Vector2(230.0, 52.0)
const FEATURE_PANEL_POSITION: Vector2 = Vector2(248.0, 8.0)

var _journal: CanvasLayer = null
# 默认隐藏：首次阅读书桌羊皮纸（unlock_notes_tool）后才解锁显示。
var _unlocked := false
var _hovered := false
var _feature_sequence: int = 0
var _feature_tween: Tween

@onready var icon_area: Area2D = $IconArea
@onready var icon_sprite: Sprite2D = $IconArea/IconSprite
@onready var hover_halo: Panel = $IconArea/HoverHalo
@onready var feature_ring: Panel = $IconArea/FeatureRing
@onready var hover_plate: Panel = $IconArea/HoverPlate
@onready var hover_label: Label = $IconArea/HoverPlate/HoverLabel
@onready var feature_unlock_panel: Panel = $FeatureUnlockPanel
@onready var feature_title: Label = $FeatureUnlockPanel/Content/Title
@onready var feature_description: Label = $FeatureUnlockPanel/Content/Description


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# BagHub 在最左侧；NoteHub 解锁后固定排在 KeyHub 之后。
	icon_area.position = HUB_ENTRY_POSITION
	feature_unlock_panel.position = FEATURE_PANEL_POSITION
	# 笔记本入口默认解锁并跨房间常驻显示；
	# wake_room 的 unlock()/show_feature_unlock() 仍然有效。
	icon_area.visible = _unlocked
	_set_hovered(false)
	icon_area.input_event.connect(_on_icon_input)


func _process(_delta: float) -> void:
	if not _unlocked:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var dist: float = mouse_pos.distance_to(icon_area.global_position)
	var is_over: bool = dist <= 42.0
	if is_over != _hovered:
		_set_hovered(is_over)


func _set_hovered(is_over: bool) -> void:
	_hovered = is_over
	hover_halo.visible = is_over
	hover_plate.visible = is_over
	var target_scale := Vector2(0.071, 0.071) if is_over else Vector2(0.0625, 0.0625)
	var target_color := Color(1.08, 1.04, 0.94, 1.0) if is_over else Color.WHITE
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon_sprite, "scale", target_scale, 0.12)
	tw.parallel().tween_property(icon_sprite, "modulate", target_color, 0.12)


func _on_icon_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _unlocked:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_feedback()
		toggle()
		get_viewport().set_input_as_handled()


func _play_click_feedback() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon_sprite, "scale", Vector2(0.056, 0.056), 0.06)
	tw.tween_property(icon_sprite, "scale", Vector2(0.071, 0.071), 0.10)
	tw.tween_property(icon_sprite, "scale", Vector2(0.071 if _hovered else 0.0625, 0.071 if _hovered else 0.0625), 0.10)


## 显示一次性新功能提示：提示卡指向左上角 Note 图标，并让图标短暂脉冲。
## duration 使用可处理暂停的 SceneTreeTimer，玩家不会因提示失去控制。
func show_feature_unlock(title: String, message: String, duration: float = 4.5) -> void:
	_feature_sequence += 1
	if not _unlocked:
		unlock()
	feature_title.text = title
	feature_description.text = message
	feature_unlock_panel.visible = true
	feature_ring.visible = true
	feature_unlock_panel.modulate = Color.WHITE
	feature_ring.modulate = Color.WHITE
	if _feature_tween != null and _feature_tween.is_valid():
		_feature_tween.kill()
	_feature_tween = create_tween()
	_feature_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_feature_tween.set_loops(5)
	_feature_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_feature_tween.tween_property(feature_ring, "scale", Vector2(1.07, 1.07), 0.42)
	_feature_tween.tween_property(feature_ring, "scale", Vector2.ONE, 0.42)
	var timer: SceneTreeTimer = get_tree().create_timer(duration, true)
	timer.timeout.connect(_on_feature_unlock_timeout.bind(_feature_sequence))


func _on_feature_unlock_timeout(sequence: int) -> void:
	if sequence == _feature_sequence:
		hide_feature_unlock()


func hide_feature_unlock() -> void:
	feature_unlock_panel.visible = false
	feature_ring.visible = false
	feature_ring.scale = Vector2.ONE
	if _feature_tween != null and _feature_tween.is_valid():
		_feature_tween.kill()
	_feature_tween = null


## 获取全局笔记实例（懒加载）
func get_journal() -> CanvasLayer:
	if _journal == null:
		_journal = JOURNAL_SCENE.instantiate()
		add_child(_journal)
	return _journal


## 解锁：显示书本图标
func unlock() -> void:
	_unlocked = true
	icon_area.visible = true


## 重置（新游戏时调用，隐藏图标并清空笔记数据）
func reset() -> void:
	_unlocked = false
	icon_area.visible = false
	hide_feature_unlock()
	_set_hovered(false)
	if _journal != null:
		_journal.queue_free()
		_journal = null


func is_unlocked() -> bool:
	return _unlocked


func toggle() -> void:
	if not _unlocked:
		return
	var j: CanvasLayer = get_journal()
	if j.visible:
		j.close()
	else:
		hide_feature_unlock()
		j.open()


func open() -> void:
	if _unlocked:
		get_journal().open()


func add_clue(id: String, data: Dictionary = {}) -> void:
	var is_new: bool = not get_journal().has_clue(id)
	get_journal().add_clue(id, data)
	if is_new and not bool(data.get("silent", false)) and GameState.current_room_id != "final_deduction_room":
		# 其他房间显示获得线索提示；Final Room 使用统一的自言自语对话框。
		var reward: Node = get_node_or_null("/root/ItemRewardHud")
		if reward != null:
			reward.call(
				"show_clue",
				id,
				str(data.get("title", id)),
				str(data.get("content", ""))
			)


func has_clue(id: String) -> bool:
	if _journal == null:
		return false
	return _journal.has_clue(id)


func get_saved_clues() -> Dictionary:
	if _journal == null:
		return {}
	return _journal.get_clues_data()


func restore_saved_clues(data: Dictionary) -> void:
	if data.is_empty():
		return
	get_journal().set_clues_data(data)


func all_sealed_archives_pinned() -> bool:
	return get_journal().all_sealed_archives_pinned()
