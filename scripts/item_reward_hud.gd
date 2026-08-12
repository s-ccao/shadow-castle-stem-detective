extends CanvasLayer

## ItemRewardHud — 获得物品提示（屏幕中心）
##
## 玩家获得任何物品（钥匙/证据/线索/药水/图纸/材料）时，
## 在屏幕中心短暂显示：物品图标 + 名称 + 介绍 + 归属提示，
## 让玩家清楚知道自己获得了什么。
##
## 触发：
##   - GameState.item_acquired 信号（add_key / add_evidence / add_recipe /
##     add_herb / add_inventory_item 成功时自动发出）
##   - NoteHud.add_clue → show_clue()（线索/笔记类）
##
## 显示不阻塞游戏：鼠标穿透、不暂停、淡入停留淡出、多件物品排队显示。

const PANEL_SIZE: Vector2 = Vector2(460.0, 200.0)
const SHOW_DURATION: float = 2.8
const BETWEEN_REWARDS_DELAY: float = 0.22

# 钥匙 → 图标 / 名称 / 介绍（与 KeyHud 槽位保持一致）
const KEY_INFO: Dictionary = {
	"wake_room_key": {
		"icon": "res://assets/ui/keyhub/wake_room_key.png",
		"title": "Wake Room Key",
		"desc": "A brass key bearing a red Ashford seal. It belongs to the Wake Room exit.",
	},
	"chemistry_room_key": {
		"icon": "res://assets/ui/keyhub/chemistry_room_key.png",
		"title": "Chemistry Room Key",
		"desc": "A heavy laboratory key. Its worn teeth carry a faint chemical-blue shine.",
	},
	"greenhouse_room_key": {
		"icon": "res://assets/ui/keyhub/greenhouse_room_key.png",
		"title": "Greenhouse Room Key",
		"desc": "A green-stained key marked with a leaf-shaped crest.",
	},
	"circuit_room_key": {
		"icon": "res://assets/ui/keyhub/circuit_room_key.png",
		"title": "Circuit Room Key",
		"desc": "A dark metal key threaded with a violet current.",
	},
	"service_corridor_key": {
		"icon": "res://assets/ui/keyhub/final_room_key.png",
		"title": "Service Corridor Key",
		"desc": "A cold key recovered from the route toward the Final Room.",
	},
	"final_room_key": {
		"icon": "res://assets/ui/keyhub/final_room_key.png",
		"title": "Final Room Key",
		"desc": "An ornate key assembled from three torn fragments.",
	},
	"dining_hall_key": {
		"icon": "res://assets/ui/keyhub/ornate_key_panel.png",
		"title": "Dining Hall Key",
		"desc": "A silver-marked key recovered from the Circuit Room equipment cabinet.",
	},
	"library_room_key": {
		"icon": "res://assets/ui/keyhub/ornate_key_panel.png",
		"title": "Library Room Key",
		"desc": "A slim brass key stamped with the library's spiral archive seal.",
	},
	"archive_key": {
		"icon": "res://assets/ui/keyhub/orb_key.png",
		"title": "Archive Key",
		"desc": "A strange key with a glowing central core. Its purpose is unknown.",
	},
	"master_key": {
		"icon": "res://assets/ui/keyhub/flame_key.png",
		"title": "Master Key",
		"desc": "A ceremonial key shaped for the castle's oldest lock.",
	},
}

# 证据 → 名称 / 简短介绍
const EVIDENCE_INFO: Dictionary = {
	"fake_red_stain": {
		"title": "Evidence: Fake Red Stain",
		"desc": "The red liquid reacts with a basic cleaner — the stain was staged.",
	},
	"greenhouse_pollen": {
		"title": "Evidence: Greenhouse Pollen",
		"desc": "Deep-room pollen on the tools — someone entered the greenhouse from outside.",
	},
	"deliberate_short_circuit": {
		"title": "Evidence: Deliberate Short Circuit",
		"desc": "The burn pattern is not accidental — someone cut the power on purpose.",
	},
	"dining_timeline": {
		"title": "Evidence: The Last Dinner Timeline",
		"desc": "The meal ended at 11:40; fresh ash and a stopped clock mark the missing twenty minutes.",
	},
	"stopped_midnight_clock": {
		"title": "Evidence: Clock Stopped by Hand",
		"desc": "The pendulum was stopped deliberately to create a false midnight timestamp.",
	},
	"dining_red_cloth": {
		"title": "Evidence: Torn Service Cloth",
		"desc": "The red thread matches a service uniform, not the dining decorations.",
	},
	"service_corridor_dark_trail": {
		"title": "Evidence: Violet Grit in the Drag Trail",
		"desc": "The dark trail contains violet grit and a chemical smell. Something heavy was dragged from the workshop.",
	},
	"service_corridor_fiber": {
		"title": "Evidence: Violet Conductive Fiber",
		"desc": "A violet thread caught on the pipe matches the insulating weave documented in the Circuit Room maintenance equipment.",
	},
	"mrs_lin_violet_fiber": {
		"title": "Evidence: Violet Fiber in Mrs. Lin's Hand",
		"desc": "A torn piece of the distinctive maintenance insulating weave was caught in Mrs. Lin's hand. It links her final struggle to the Circuit and Service Area evidence without identifying a worker by itself.",
	},
	"mrs_lin_glove_fragment": {
		"title": "Evidence: Torn Maintenance Glove Fragment",
		"desc": "A torn cuff fragment in Mrs. Lin's hand carries the same distinctive copper-thread cross-stitch described in the Mechanic's missing glove record.",
	},
	"mechanic_missing_glove": {
		"title": "Evidence: Mechanic's Missing Right Glove",
		"desc": "A maintenance record assigns one pair of gloves to the Mechanic. The right glove had a distinctive copper-thread cross-stitch repair and went missing after the blackout.",
	},
	"final_archive_document": {
		"title": "Evidence: Final Archive Document",
		"desc": "Lord Ashford's sealed record connects the castle's research wings, the Knowledge Engine, and the hidden archive route.",
	},
	"vault_vision_symbols": {
		"title": "Evidence: Hidden Dial Symbols",
		"desc": "Under the Vision Potion, the vault dial reveals a violet circuit mark — the culprit's route recorder.",
	},
}

var _queue: Array[Dictionary] = []
var _showing: bool = false
var _waiting_between_rewards: bool = false
var _panel: Panel
var _icon_slot: Panel
var _icon_rect: TextureRect
var _title_label: Label
var _desc_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	if not GameState.item_acquired.is_connected(_on_item_acquired):
		GameState.item_acquired.connect(_on_item_acquired)


func dismiss_for_overlay() -> void:
	_queue.clear()
	_showing = false
	_waiting_between_rewards = false
	if _panel != null:
		_panel.visible = false


func _build_panel() -> void:
	_panel = Panel.new()
	_panel.name = "ItemRewardPanel"
	_panel.position = Vector2.ZERO
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.05, 0.035, 0.94)
	style.border_color = Color(0.95, 0.72, 0.28, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", style)

	# 左侧图标槽（暗铜底 + 金框）
	_icon_slot = Panel.new()
	_icon_slot.name = "ItemIconSlot"
	_icon_slot.position = Vector2(18.0, 24.0)
	_icon_slot.size = Vector2(108.0, 108.0)
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_style: StyleBoxFlat = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.20, 0.12, 0.05, 0.90)
	slot_style.border_color = Color(0.95, 0.72, 0.28, 0.90)
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(10)
	_icon_slot.add_theme_stylebox_override("panel", slot_style)
	_panel.add_child(_icon_slot)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "ItemIcon"
	_icon_rect.position = Vector2(14.0, 14.0)
	_icon_rect.size = Vector2(80.0, 80.0)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_slot.add_child(_icon_rect)

	# 右侧：标题 / 介绍 / 归属提示
	_title_label = Label.new()
	_title_label.name = "ItemTitle"
	_title_label.position = Vector2(144.0, 16.0)
	_title_label.size = Vector2(300.0, 42.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.clip_text = true
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55, 1.0))
	_panel.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.name = "ItemDescription"
	_desc_label.position = Vector2(144.0, 60.0)
	_desc_label.size = Vector2(300.0, 84.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.clip_text = true
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.95, 0.87, 0.68, 1.0))
	_panel.add_child(_desc_label)

	_hint_label = Label.new()
	_hint_label.name = "ItemHint"
	_hint_label.position = Vector2(144.0, 164.0)
	_hint_label.size = Vector2(300.0, 22.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.clip_text = true
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.58, 0.95, 1.0))
	_panel.add_child(_hint_label)


## 公共接口：线索/笔记类（NoteHud.add_clue 调用）。
func show_clue(clue_id: String, title: String, description: String) -> void:
	var plain: String = _shorten(description)
	_enqueue("res://assets/ui/icon_note.png", title, plain, "Added to Notebook")


func _on_item_acquired(item_id: String, kind: String, amount: int) -> void:
	var config: Dictionary = _lookup(item_id, kind)
	if config.is_empty():
		return
	_enqueue(
		str(config.get("icon", "res://assets/ui/icon_note.png")),
		str(config.get("title", item_id)),
		_shorten(str(config.get("desc", ""))),
		str(config.get("hint", _default_hint(kind, amount)))
	)


## 弹窗只显示简介：剥离 BBCode 并截断，完整内容在 Note Hub 中查看。
func _shorten(text: String, max_chars: int = 72) -> String:
	var cleaned: String = text
	cleaned = cleaned.replace("[center]", "").replace("[/center]", "")
	cleaned = cleaned.replace("[b]", "").replace("[/b]", "")
	cleaned = cleaned.replace("[color=#7a2e2e]", "").replace("[color=#4a306d]", "").replace("[/color]", "")
	cleaned = cleaned.replace("\n", " ")
	cleaned = cleaned.replace("  ", " ")
	if cleaned.length() <= max_chars:
		return cleaned
	return cleaned.substr(0, max_chars) + "..."


func _lookup(item_id: String, kind: String) -> Dictionary:
	match kind:
		"key":
			return KEY_INFO.get(item_id, {})
		"evidence":
			return EVIDENCE_INFO.get(item_id, {})
		"recipe":
			var info: Dictionary = GameState.RECIPE_INFO.get(item_id, {})
			if info.is_empty():
				return {}
			return {
				"icon": "res://assets/ui/icon_note.png",
				"title": str(info.get("name", item_id)),
				"desc": str(info.get("description", "")),
				"hint": "Added to Satchel",
			}
		"herb":
			var info: Dictionary = GameState.HERB_INFO.get(item_id, {})
			if info.is_empty():
				return {}
			return {
				"icon": "res://assets/ui/icon_note.png",
				"title": str(info.get("name", item_id)),
				"desc": str(info.get("description", "")),
			}
		"material":
			var info: Dictionary = GameState.MATERIAL_INFO.get(item_id, {})
			if info.is_empty():
				return {}
			return {
				"icon": "res://assets/ui/icon_note.png",
				"title": str(info.get("name", item_id)),
				"desc": str(info.get("description", "")),
				"hint": "Added to Satchel",
			}
		"map":
			if item_id == "circuit_repair_map":
				return {
					"icon": "res://assets/ui/icon_note.png",
					"title": "Circuit Repair Map",
					"desc": "A hand-drawn repair map marking the three switches and the correct activation order.",
					"hint": "Added to Satchel Maps",
				}
		"potion":
			var info: Dictionary = GameState.POTION_INFO.get(item_id, {})
			if info.is_empty():
				return {}
			var potion_icon: String = "res://assets/ui/icon_note.png"
			if item_id == "swift_potion":
				potion_icon = "res://assets/ui/alchemy/swiftness_potion.png"
			elif item_id == "vision_potion":
				potion_icon = "res://assets/ui/alchemy/vision_potion_eyes.png"
			elif item_id == "green_potion":
				potion_icon = "res://assets/ui/alchemy/green_potion.png"
			return {
				"icon": potion_icon,
				"title": str(info.get("name", item_id)),
				"desc": str(info.get("description", "")),
				"hint": "Added to Satchel",
			}
		"fragment":
			# Final Room Key 碎片（三台机器各藏 1/3）。
			var fragment_number: int = 0
			var parts: PackedStringArray = item_id.split("_")
			if parts.size() >= 3:
				fragment_number = int(parts[parts.size() - 1])
			return {
				"icon": "res://assets/ui/keyhub/final_room_key.png",
				"title": "Final Room Key Fragment (%d/3)" % fragment_number,
				"desc": "A torn piece of the Final Room Key. It seems incomplete — three fragments must be found.",
				"hint": "Added to Satchel",
			}
	return {}


func _default_hint(kind: String, amount: int) -> String:
	match kind:
		"key":
			return "Added to Key Hub"
		"evidence":
			return "Added to Evidence Board"
		"recipe", "potion":
			return "Added to Satchel"
		"herb":
			return "Added to Satchel (x%d)" % amount
		"material":
			return "Added to Satchel (x%d)" % amount
		"fragment":
			return "Added to Satchel — %d/3 pieces" % amount
	return ""


func _enqueue(icon: String, title: String, desc: String, hint: String) -> void:
	_queue.append({
		"icon": icon,
		"title": title,
		"desc": desc,
		"hint": hint,
	})
	if not _showing and not _waiting_between_rewards:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty() or _showing or _waiting_between_rewards:
		if _queue.is_empty() and not _showing:
			_panel.visible = false
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()

	var texture: Texture2D = load(str(item["icon"])) as Texture2D
	_icon_rect.texture = texture
	_title_label.text = str(item["title"])
	_desc_label.text = str(item["desc"])
	_hint_label.text = str(item["hint"])

	# 屏幕中心偏上（垂直 38%），不遮挡底部对话与顶部 HUD。
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(
		(viewport_size.x - PANEL_SIZE.x) / 2.0,
		viewport_size.y * 0.38 - PANEL_SIZE.y / 2.0
	)
	_panel.visible = true
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.16)
	tw.tween_interval(SHOW_DURATION)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.28)
	tw.tween_callback(_on_finished)


func _on_finished() -> void:
	_panel.visible = false
	_showing = false
	# 严格串行：上一条完全隐藏后留出极短间隔，再显示下一条。
	# 防止同一交互同时发出多条奖励信号时视觉重叠/连闪。
	_waiting_between_rewards = true
	var timer: SceneTreeTimer = get_tree().create_timer(
		BETWEEN_REWARDS_DELAY,
		true
	)
	timer.timeout.connect(_on_between_rewards_delay_finished)


func _on_between_rewards_delay_finished() -> void:
	_waiting_between_rewards = false
	_show_next()
