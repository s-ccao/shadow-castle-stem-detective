extends Node

## PotionHud —— 让"药水正在生效"这件事无法被忽略。
##
## GameState 一直在跑药水倒计时，但没有任何表现层：喝下药水只会弹出一行
## 1.8 秒的小字，之后玩家既看不出效果还在不在，也不知道什么时候会失效。
## 这个 autoload 补上三层反馈：
##   1. 入口爆发   —— 喝下的瞬间整屏闪光 + 扩散光环，确认"我确实喝了"。
##   2. 常驻角标   —— 药瓶图标 + 环形倒计时 + 剩余秒数，回答"还剩多久"。
##   3. 边缘光晕   —— 屏幕四周持续呼吸的染色，余光就能感知状态。
## 最后 5 秒角标与光晕一起转入闪烁预警。
##
## 配色不是拍脑袋定的：色相直接取自 assets/ui/alchemy 里药瓶图标投出的光晕
## （迅捷 13°、洞察 213°、绿药 87°），只把饱和度提到低透明度下仍能看清的
## 程度，所以屏幕上的颜色和背包里那瓶药是同一个色调。

const AURA_LAYER: int = 25
const CHIP_LAYER: int = 43

const CHIP_MARGIN := Vector2(18.0, 18.0)
const CHIP_SPACING: float = 8.0
const AURA_FADE_IN: float = 0.35
const AURA_FADE_OUT: float = 0.55
## 剩余时间低于这个秒数时光晕也跟着闪烁预警。
const WARNING_SECONDS: float = 5.0

const EFFECT_STYLE: Dictionary = {
	"swift": {
		"name_key": "potion.swift_short",
		"icon": "res://assets/ui/alchemy/swiftness_potion.png",
		"aura": Color(1.00, 0.51, 0.37),
		"accent": Color(1.00, 0.42, 0.25),
	},
	"vision": {
		"name_key": "potion.vision_short",
		"icon": "res://assets/ui/alchemy/vision_potion.png",
		"aura": Color(0.45, 0.70, 1.00),
		"accent": Color(0.25, 0.59, 1.00),
	},
	"green": {
		"name_key": "potion.green_short",
		"icon": "res://assets/ui/alchemy/green_potion.png",
		"aura": Color(0.74, 1.00, 0.42),
		"accent": Color(0.66, 1.00, 0.25),
	},
}

var _aura_layer: CanvasLayer
var _chip_layer: CanvasLayer
var _aura: PotionAuraOverlay
var _chip_box: VBoxContainer
var _chips: Dictionary = {}
var _aura_tween: Tween


func _ready() -> void:
	name = "PotionHud"
	_build_layers()
	if GameState != null:
		if not GameState.potion_applied.is_connected(_on_potion_applied):
			GameState.potion_applied.connect(_on_potion_applied)
		if not GameState.potion_expired.is_connected(_on_potion_expired):
			GameState.potion_expired.connect(_on_potion_expired)
		# 拾取音挂在这个中心信号上：证物、钥匙、碎片、药水、配方都会经过
		# 它，比在每个房间各写一次 play() 可靠得多，也不会漏。
		if not GameState.item_acquired.is_connected(_on_item_acquired):
			GameState.item_acquired.connect(_on_item_acquired)
	# 读档进来时药水可能已经在生效中，补建角标。
	call_deferred("_sync_with_state")


func _build_layers() -> void:
	_aura_layer = CanvasLayer.new()
	_aura_layer.name = "PotionAuraLayer"
	# 压在房间 UI（30）之下，光晕不会盖住对话框和按钮。
	_aura_layer.layer = AURA_LAYER
	add_child(_aura_layer)

	_aura = PotionAuraOverlay.new()
	_aura_layer.add_child(_aura)

	_chip_layer = CanvasLayer.new()
	_chip_layer.name = "PotionChipLayer"
	# 高于背包与地图（42），打开背包时角标依然可见。
	_chip_layer.layer = CHIP_LAYER
	add_child(_chip_layer)

	var anchor := Control.new()
	anchor.name = "PotionChipAnchor"
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_layer.add_child(anchor)

	_chip_box = VBoxContainer.new()
	_chip_box.name = "PotionChips"
	# 停在右上角：左上是目标面板，底部是对话框和交互提示。
	# 显式写 offset 而不是靠 position，锚点语义下 position 的含义容易读错。
	_chip_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_chip_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chip_box.grow_vertical = Control.GROW_DIRECTION_END
	_chip_box.offset_left = -CHIP_MARGIN.x
	_chip_box.offset_right = -CHIP_MARGIN.x
	_chip_box.offset_top = CHIP_MARGIN.y
	_chip_box.offset_bottom = CHIP_MARGIN.y
	_chip_box.add_theme_constant_override("separation", int(CHIP_SPACING))
	_chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_chip_box)


func _process(delta: float) -> void:
	if _chips.is_empty():
		return
	var strongest: float = 0.0
	for effect_id: String in _chips:
		var remaining: float = GameState.get_potion_remaining(effect_id)
		var chip: PotionStatusChip = _chips[effect_id]
		chip.update_remaining(remaining, delta)
		strongest = maxf(strongest, remaining)
	_apply_warning_pulse(strongest)


## 光晕在最后几秒压暗又回升，配合角标一起提示"快没了"。
func _apply_warning_pulse(remaining: float) -> void:
	if _aura == null:
		return
	if _aura_tween != null and _aura_tween.is_valid() and _aura_tween.is_running():
		return
	if remaining > WARNING_SECONDS or remaining <= 0.0:
		return
	var urgency: float = 1.0 - clampf(remaining / WARNING_SECONDS, 0.0, 1.0)
	var blink: float = 0.5 + 0.5 * sin(
		Time.get_ticks_msec() / 1000.0 * TAU * 3.4
	)
	_aura.strength = lerpf(1.0, 0.25, blink * urgency)


func _on_potion_applied(effect_id: String, duration: float) -> void:
	var style: Dictionary = EFFECT_STYLE.get(effect_id, {})
	if style.is_empty():
		return
	AudioManager.play_sfx("potion_drink")
	_spawn_burst(style)
	_ensure_chip(effect_id, style, duration)
	_raise_aura(style["aura"] as Color)


func _on_item_acquired(_item_id: String, _kind: String, _amount: int) -> void:
	AudioManager.play_sfx("item_pickup")


func _on_potion_expired(effect_id: String) -> void:
	AudioManager.play_sfx("potion_expire")
	var chip: PotionStatusChip = _chips.get(effect_id) as PotionStatusChip
	if chip != null:
		_chips.erase(effect_id)
		# 收尾用一小段淡出，效果结束这件事本身也值得被看见。
		var tween: Tween = create_tween()
		tween.tween_property(chip, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(
			chip, "position:x", chip.position.x + 26.0, 0.4
		)
		tween.tween_callback(chip.queue_free)
	if _chips.is_empty():
		_lower_aura()
	else:
		# 还有别的药水在生效，光晕换成剩下那瓶的颜色。
		for remaining_id: String in _chips:
			var style: Dictionary = EFFECT_STYLE.get(remaining_id, {})
			if not style.is_empty():
				_raise_aura(style["aura"] as Color)
				break


func _spawn_burst(style: Dictionary) -> void:
	var burst := PotionActivationBurst.new()
	burst.tint = style["aura"] as Color
	burst.accent = style["accent"] as Color
	_chip_layer.add_child(burst)


func _ensure_chip(
	effect_id: String, style: Dictionary, duration: float
) -> void:
	# 同一种药水续杯时不叠角标，只把倒计时重置。
	var chip: PotionStatusChip = _chips.get(effect_id) as PotionStatusChip
	if chip == null:
		chip = PotionStatusChip.new()
		_chip_box.add_child(chip)
		_chips[effect_id] = chip
	chip.modulate.a = 1.0
	chip.configure(
		effect_id,
		_short_name(effect_id, style),
		str(style.get("icon", "")),
		style["accent"] as Color,
		duration
	)
	chip.update_remaining(duration, 0.0)


func _short_name(effect_id: String, style: Dictionary) -> String:
	var key: String = str(style.get("name_key", ""))
	if not key.is_empty() and CaseLocale != null:
		var localized: String = CaseLocale.text(key)
		if localized != key:
			return localized
	var potion_id: String = GameState.get_potion_id_for_effect(effect_id)
	var info: Dictionary = GameState.POTION_INFO.get(potion_id, {})
	return str(info.get("name", effect_id.capitalize()))


func _raise_aura(color: Color) -> void:
	if _aura == null:
		return
	_aura.tint = color
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	_aura_tween = create_tween()
	_aura_tween.tween_property(_aura, "strength", 1.0, AURA_FADE_IN)


func _lower_aura() -> void:
	if _aura == null:
		return
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	_aura_tween = create_tween()
	_aura_tween.tween_property(_aura, "strength", 0.0, AURA_FADE_OUT)


## 读档或场景重建后，按 GameState 里真实剩余的效果重建角标。
func _sync_with_state() -> void:
	if GameState == null:
		return
	for effect_id: String in GameState.potion_effects:
		var style: Dictionary = EFFECT_STYLE.get(effect_id, {})
		if style.is_empty():
			continue
		var remaining: float = GameState.get_potion_remaining(effect_id)
		if remaining <= 0.0:
			continue
		# 存档只留剩余时间，环形进度需要原始时长才画得对，从配方表取。
		var potion_id: String = GameState.get_potion_id_for_effect(effect_id)
		var full: float = float(
			GameState.POTION_INFO.get(potion_id, {}).get("duration", remaining)
		)
		_ensure_chip(effect_id, style, maxf(full, remaining))
		_chips[effect_id].update_remaining(remaining, 0.0)
		_raise_aura(style["aura"] as Color)
