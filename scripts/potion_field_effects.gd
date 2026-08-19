class_name PotionFieldEffects
extends Node2D

## 药水的世界层特效：喝下去之后，在地图上真正看得见的那一部分。
##
## PotionHud 负责屏幕层（入口闪光、角标倒计时、边缘光晕），它回答"我还
## 有多久"。这里回答"它正在做什么"：
##   隐身 —— 玩家本体变成半透明的冷色残影，边看边知道守卫看不见自己。
##   迅捷 —— 身后按距离掉落染色残影，速度越快拖尾越密。
##   现形 —— 守卫每走一段就在地上留下一枚会淡去的脚印，配合屏幕褪色，
##            玩家可以隔着墙读出它正从哪个方向摸过来。
##   毒沼 —— 在喝下的位置留下一小片沼泽，守卫踩进去就被拖慢一段时间。
##
## 刻意不设 process_mode：背包、钥匙、笔记、地图打开时整棵树暂停，守卫和
## 药水倒计时都会停下，这些特效必须跟着停，否则暂停界面里拖尾还在飘。

const SHROUD_TINT: Color = Color(0.62, 0.80, 1.00)
const SHROUD_ALPHA_LOW: float = 0.18
const SHROUD_ALPHA_HIGH: float = 0.38
const SHROUD_SHIMMER_SPEED: float = 2.4
const SHROUD_FADE: float = 0.30

## 拖尾按距离掉落而不是按时间，所以迅捷药水把人推快多少，拖尾就密多少。
const TRAIL_TINT: Color = Color(1.00, 0.52, 0.28)
const TRAIL_STEP: float = 14.0
const TRAIL_LIFETIME: float = 0.40
const TRAIL_ALPHA: float = 0.55
const TRAIL_Z: int = -1

const FOOTPRINT_TINT: Color = Color(1.00, 0.40, 0.34)
const FOOTPRINT_STEP: float = 20.0
const FOOTPRINT_LIFETIME: float = 2.8
const FOOTPRINT_RADIUS: float = 3.6
const FOOTPRINT_SPREAD: float = 5.0
const FOOTPRINT_Z: int = -2

const MIRE_RADIUS: float = 62.0
const MIRE_TINT: Color = Color(0.42, 0.95, 0.34)
const MIRE_RING_TINT: Color = Color(0.72, 1.00, 0.48)
const MIRE_FADE: float = 0.55
const MIRE_PULSE_SPEED: float = 1.7
const MIRE_Z: int = -3
## 守卫每帧都在沼里，就没必要每帧都重设计时器；这个间隔够密到踩一下就中，
## 又不会把 state_changed 每秒发六十次。
const MIRE_REAPPLY_INTERVAL: float = 0.4

var _player: Node2D = null
var _guardian: Node2D = null
var _player_visual: Node2D = null
var _player_sprite: AnimatedSprite2D = null
var _shroud_time: float = 0.0
var _trail_anchor: Vector2 = Vector2.ZERO
var _trail_started: bool = false
var _footprint_anchor: Vector2 = Vector2.ZERO
var _footprint_started: bool = false
var _footprint_side: float = 1.0
var _mire: Node2D = null
var _mire_position: Vector2 = Vector2.ZERO
var _mire_time: float = 0.0
var _mire_reapply: float = 0.0


func _ready() -> void:
	z_index = 0
	set_process(false)


## The world cannot hand these over at construction time, so nothing runs until
## it does. Called once by game_world after both bodies exist.
func setup(player_body: Node2D, guardian_body: Node2D) -> void:
	_player = player_body
	_guardian = guardian_body
	if _player != null:
		_player_visual = _player.get_node_or_null("VisualRoot") as Node2D
		_player_sprite = _player.get_node_or_null(
			"VisualRoot/CharacterSprite"
		) as AnimatedSprite2D
	if GameState != null:
		if not GameState.potion_applied.is_connected(_on_potion_applied):
			GameState.potion_applied.connect(_on_potion_applied)
		if not GameState.potion_expired.is_connected(_on_potion_expired):
			GameState.potion_expired.connect(_on_potion_expired)
	set_process(true)


## Handed over when the run ends: the capture sequence poses the detective and
## tints its sprite, and a shroud shimmer still writing modulate every frame
## would erase that beat one frame after it played.
func suspend() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_update_shroud(delta)
	_update_trail()
	_update_footprints()
	_update_mire(delta)


func _on_potion_applied(effect_id: String, duration: float) -> void:
	match effect_id:
		"shroud":
			_begin_shroud()
		"swift":
			_trail_started = false
		"reveal":
			_footprint_started = false
		"mire":
			_spawn_mire(duration)


func _on_potion_expired(effect_id: String) -> void:
	match effect_id:
		"shroud":
			_end_shroud()
		"mire":
			_clear_mire()


# ============================================================
# Shroud — the detective reads as light bending round them
# ============================================================

func _begin_shroud() -> void:
	_shroud_time = 0.0
	if _player_visual == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_player_visual,
		"modulate",
		_shroud_colour(SHROUD_ALPHA_LOW),
		SHROUD_FADE
	)


func _end_shroud() -> void:
	if _player_visual == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_player_visual, "modulate", Color.WHITE, SHROUD_FADE)


func _shroud_colour(alpha: float) -> Color:
	return Color(SHROUD_TINT.r, SHROUD_TINT.g, SHROUD_TINT.b, alpha)


## The shimmer is what stops the fade reading as a rendering fault: a body that
## is simply faint looks broken, a body that breathes looks hidden on purpose.
func _update_shroud(delta: float) -> void:
	if _player_visual == null or GameState == null:
		return
	if not GameState.is_potion_active("shroud"):
		return
	_shroud_time += delta
	var wave: float = (sin(_shroud_time * SHROUD_SHIMMER_SPEED) + 1.0) * 0.5
	_player_visual.modulate = _shroud_colour(
		lerpf(SHROUD_ALPHA_LOW, SHROUD_ALPHA_HIGH, wave)
	)


# ============================================================
# Swiftness — an afterimage every fixed stretch of floor
# ============================================================

func _update_trail() -> void:
	if _player == null or GameState == null:
		return
	if not GameState.is_potion_active("swift"):
		_trail_started = false
		return
	var here: Vector2 = _player.global_position
	if not _trail_started:
		_trail_started = true
		_trail_anchor = here
		return
	if here.distance_to(_trail_anchor) < TRAIL_STEP:
		return
	_trail_anchor = here
	_drop_afterimage(here)


func _drop_afterimage(at_position: Vector2) -> void:
	if _player_sprite == null or _player_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = _player_sprite.sprite_frames
	if not frames.has_animation(_player_sprite.animation):
		return
	var texture: Texture2D = frames.get_frame_texture(
		_player_sprite.animation,
		_player_sprite.frame
	)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = _player_sprite.global_scale
	ghost.z_index = TRAIL_Z
	ghost.modulate = Color(TRAIL_TINT.r, TRAIL_TINT.g, TRAIL_TINT.b, TRAIL_ALPHA)
	# Into the tree first: global_position on a node with no parent is applied
	# against an identity transform and has to be re-set anyway.
	add_child(ghost)
	ghost.global_position = at_position + _player_sprite.global_position - (
		_player.global_position
	)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	tween.parallel().tween_property(
		ghost,
		"scale",
		ghost.scale * 0.82,
		TRAIL_LIFETIME
	)
	tween.tween_callback(ghost.queue_free)


# ============================================================
# Reveal — the Guardian leaves a trail the player can read
# ============================================================

func _update_footprints() -> void:
	if _guardian == null or GameState == null:
		return
	if not GameState.is_potion_active("reveal"):
		_footprint_started = false
		return
	var here: Vector2 = _guardian.global_position
	if not _footprint_started:
		_footprint_started = true
		_footprint_anchor = here
		return
	var travelled: Vector2 = here - _footprint_anchor
	if travelled.length() < FOOTPRINT_STEP:
		return
	# Offsetting alternate prints across the direction of travel is the whole
	# difference between "a dotted line" and "something walked here".
	var across: Vector2 = travelled.normalized().orthogonal()
	_drop_footprint(here + across * FOOTPRINT_SPREAD * _footprint_side)
	_footprint_side = -_footprint_side
	_footprint_anchor = here


func _drop_footprint(at_position: Vector2) -> void:
	var mark := Polygon2D.new()
	mark.polygon = _oval(FOOTPRINT_RADIUS, FOOTPRINT_RADIUS * 1.5, 10)
	mark.color = FOOTPRINT_TINT
	mark.z_index = FOOTPRINT_Z
	add_child(mark)
	mark.global_position = at_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(mark, "modulate:a", 0.0, FOOTPRINT_LIFETIME)
	tween.tween_callback(mark.queue_free)


# ============================================================
# Mire — a slowing patch left where the bottle was thrown down
# ============================================================

func _spawn_mire(duration: float) -> void:
	_clear_mire()
	if _player == null:
		return
	_mire_position = _player.global_position
	_mire_time = 0.0
	_mire_reapply = 0.0
	var mire := Node2D.new()
	mire.name = "PotionMire"
	mire.z_index = MIRE_Z
	var pool := Polygon2D.new()
	pool.polygon = _oval(MIRE_RADIUS, MIRE_RADIUS * 0.62, 22)
	pool.color = Color(MIRE_TINT.r, MIRE_TINT.g, MIRE_TINT.b, 0.34)
	mire.add_child(pool)
	var ring := Polygon2D.new()
	ring.polygon = _oval(MIRE_RADIUS * 0.66, MIRE_RADIUS * 0.41, 18)
	ring.color = Color(MIRE_RING_TINT.r, MIRE_RING_TINT.g, MIRE_RING_TINT.b, 0.30)
	mire.add_child(ring)
	mire.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(mire)
	mire.global_position = _mire_position
	_mire = mire
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mire, "modulate:a", 1.0, MIRE_FADE)
	# Fade it out under its own last second so the patch does not vanish on a
	# frame boundary while the Guardian is standing in it.
	if duration > MIRE_FADE * 2.0:
		tween.tween_interval(duration - MIRE_FADE * 2.0)
		tween.tween_property(mire, "modulate:a", 0.0, MIRE_FADE)


func _update_mire(delta: float) -> void:
	if _mire == null or not is_instance_valid(_mire):
		return
	_mire_time += delta
	var pulse: float = 1.0 + sin(_mire_time * MIRE_PULSE_SPEED) * 0.05
	_mire.scale = Vector2(pulse, pulse)
	if _guardian == null or GameState == null:
		return
	_mire_reapply = maxf(_mire_reapply - delta, 0.0)
	if _mire_reapply > 0.0:
		return
	if _guardian.global_position.distance_to(_mire_position) > MIRE_RADIUS:
		return
	_mire_reapply = MIRE_REAPPLY_INTERVAL
	GameState.mire_guardian()


func _clear_mire() -> void:
	if _mire != null and is_instance_valid(_mire):
		_mire.queue_free()
	_mire = null


func _oval(radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in range(segments):
		var angle: float = TAU * float(step) / float(segments)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
