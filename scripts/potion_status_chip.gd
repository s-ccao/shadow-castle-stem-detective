class_name PotionStatusChip
extends Control

## 药水生效期间常驻的状态角标：药瓶图标 + 环形倒计时 + 剩余秒数。
##
## 回答的是"药水还在不在生效、还剩多久"——这两件事以前玩家完全无从得知。
## 最后 5 秒进入闪烁预警，让玩家能赶在失效前把握时间。

const CHIP_SIZE := Vector2(112.0, 44.0)
const RING_RADIUS: float = 15.0
const RING_WIDTH: float = 4.0
## 剩余时间低于这个秒数开始闪烁预警。
const WARNING_SECONDS: float = 5.0
const WARNING_BLINK_HZ: float = 3.4

## 面板配色沿用背包/日志的深棕描金，保证和既有 HUD 是一套东西。
const PLATE_COLOR := Color(0.035, 0.030, 0.055, 0.90)
const PLATE_BORDER := Color(0.72, 0.58, 0.30, 0.80)
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.14)

var effect_id: String = ""
var accent: Color = Color.WHITE
var total_duration: float = 1.0

var _icon: TextureRect
var _time_label: Label
var _name_label: Label
var _remaining: float = 0.0
var _blink_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = CHIP_SIZE
	size = CHIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(8.0, 6.0)
	_icon.size = Vector2(32.0, 32.0)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_name_label = Label.new()
	_name_label.position = Vector2(46.0, 4.0)
	_name_label.size = Vector2(60.0, 16.0)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override(
		"font_color", Color(0.95, 0.90, 0.72, 1.0)
	)
	_name_label.add_theme_color_override(
		"font_outline_color", Color(0.10, 0.06, 0.02, 1.0)
	)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_time_label = Label.new()
	_time_label.position = Vector2(46.0, 20.0)
	_time_label.size = Vector2(40.0, 18.0)
	_time_label.add_theme_font_size_override("font_size", 13)
	_time_label.add_theme_color_override(
		"font_outline_color", Color(0.10, 0.06, 0.02, 1.0)
	)
	_time_label.add_theme_constant_override("outline_size", 4)
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_time_label)


func configure(
	new_effect_id: String,
	display_name: String,
	icon_path: String,
	new_accent: Color,
	duration: float
) -> void:
	effect_id = new_effect_id
	accent = new_accent
	total_duration = maxf(duration, 0.001)
	_remaining = duration
	if _name_label != null:
		_name_label.text = display_name
	if _icon != null and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path) as Texture2D


func update_remaining(remaining: float, delta: float) -> void:
	_remaining = maxf(remaining, 0.0)
	_blink_time += delta
	if _time_label != null:
		_time_label.text = "%.1fs" % _remaining
		_time_label.add_theme_color_override("font_color", _readout_color())
	queue_redraw()


func _readout_color() -> Color:
	if _remaining > WARNING_SECONDS:
		return Color(0.98, 0.80, 0.38, 1.0)
	# 预警闪烁：在琥珀色与警示红之间来回。
	var blink: float = 0.5 + 0.5 * sin(_blink_time * TAU * WARNING_BLINK_HZ)
	return Color(0.98, 0.80, 0.38, 1.0).lerp(Color(1.0, 0.38, 0.30, 1.0), blink)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLATE_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), PLATE_BORDER, false, 2.0)

	var center := Vector2(size.x - 24.0, size.y * 0.5)
	draw_arc(center, RING_RADIUS, 0.0, TAU, 40, TRACK_COLOR, RING_WIDTH, true)

	var fraction: float = clampf(_remaining / total_duration, 0.0, 1.0)
	if fraction <= 0.0:
		return
	var ring_color: Color = accent
	if _remaining <= WARNING_SECONDS:
		var blink: float = 0.5 + 0.5 * sin(_blink_time * TAU * WARNING_BLINK_HZ)
		ring_color = accent.lerp(Color(1.0, 0.30, 0.24, 1.0), blink * 0.85)
	# 从十二点方向顺时针消耗，和常见的冷却环读法一致。
	draw_arc(
		center,
		RING_RADIUS,
		-PI * 0.5,
		-PI * 0.5 + TAU * fraction,
		48,
		ring_color,
		RING_WIDTH,
		true
	)
