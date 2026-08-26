class_name TutorialCoach
extends CanvasLayer

## One lesson at a time, taught where the player is looking, and never advanced
## until they have actually done it.
##
## The previous opening handed over control, raised a modal control card, and
## animated the objective card in behind that modal, all on the same frame. A
## first-time player received three things at once, practised none of them, and
## the objective card's only entrance animation played where it could not be
## seen. Players reported the game as having no tutorial at all.
##
## This coach is deliberately not a manual. It shows a single line at a time,
## low on the screen where the character is, and each line stays until the
## action it describes has been performed. A player cannot be stuck at a lesson
## they have already completed, and cannot skip past one they have not.

const LESSON_NONE := &""
const LESSON_MOVE := &"move"
const LESSON_INTERACT := &"interact"

## How far the player must travel before movement counts as learned. A couple of
## steps is enough to prove the control works; requiring more reads as a chore.
const MOVE_LEARNED_DISTANCE := 72.0
## A lesson never appears the instant control returns. Landing text on the same
## frame as the handover is what made the old card read as HUD wallpaper.
const FIRST_LESSON_DELAY := 0.65
## Gap between one lesson clearing and the next appearing, so each is its own
## event rather than text swapping in place.
const LESSON_GAP := 0.85

signal lesson_completed(lesson: StringName)
signal all_lessons_completed

var _player: Node2D
var _panel: Panel
var _label: Label
var _keycap_row: HBoxContainer
var _lesson: StringName = LESSON_NONE
var _pending: Array[StringName] = []
var _delay: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _interaction_available := false
var _tween: Tween


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	CaseLocale.locale_changed.connect(func(_l: String) -> void: _refresh_text())


## Begin coaching. Called once the player actually has control: a lesson shown
## while movement is locked teaches nothing and burns the player's attention.
func begin(player: Node2D) -> void:
	if not PlayerPreferences.field_prompts_enabled:
		return
	if GameState.has_story_flag("wake_orientation_completed"):
		return
	_player = player
	_pending = [LESSON_MOVE, LESSON_INTERACT]
	_delay = FIRST_LESSON_DELAY


## The lesson on screen right now, or "" when none is. Test seam.
func current_lesson() -> String:
	return str(_lesson)


## The room reports whether something is within reach, so the interact lesson
## appears next to an actual object rather than in the abstract.
func set_interaction_available(available: bool) -> void:
	_interaction_available = available


## The room reports a successful interaction.
func notify_interacted() -> void:
	if _lesson == LESSON_INTERACT:
		_complete_lesson()


func _process(delta: float) -> void:
	if _pending.is_empty() and _lesson == LESSON_NONE:
		return
	if _delay > 0.0:
		_delay = maxf(0.0, _delay - delta)
		if _delay > 0.0:
			return
	if _lesson == LESSON_NONE:
		_advance()
		return
	if _lesson == LESSON_MOVE and _player != null:
		if _player.global_position.distance_to(_origin) >= MOVE_LEARNED_DISTANCE:
			_complete_lesson()


func _advance() -> void:
	if _pending.is_empty():
		_hide()
		GameState.set_story_flag("wake_orientation_completed")
		all_lessons_completed.emit()
		return
	# The interact lesson has to wait for something to interact with, otherwise
	# it is the same abstract instruction the old control card gave.
	if _pending[0] == LESSON_INTERACT and not _interaction_available:
		return
	_lesson = _pending.pop_front()
	if _lesson == LESSON_MOVE and _player != null:
		_origin = _player.global_position
	_refresh_text()
	_show()


func _complete_lesson() -> void:
	var finished := _lesson
	_lesson = LESSON_NONE
	_delay = LESSON_GAP
	_hide()
	lesson_completed.emit(finished)


func _refresh_text() -> void:
	if _label == null:
		return
	match _lesson:
		LESSON_MOVE:
			_label.text = CaseLocale.text("coach.move")
			_set_keycaps(["W", "A", "S", "D"])
		LESSON_INTERACT:
			_label.text = CaseLocale.text("coach.interact")
			_set_keycaps(["E"])
		_:
			_label.text = ""
			_set_keycaps([])


func _show() -> void:
	if _panel == null:
		return
	_panel.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.24)


func _hide() -> void:
	if _panel == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.16)
	_tween.tween_callback(func() -> void:
		if _panel != null:
			_panel.visible = false
	)


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "CoachPrompt"
	# Low and centred: the character is here, so the eye is already here. The
	# old card sat in the top-right corner, outside the player's focus.
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -250.0
	_panel.offset_right = 250.0
	_panel.offset_top = -132.0
	_panel.offset_bottom = -76.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.028, 0.020, 0.96)
	style.border_color = Color(0.80, 0.58, 0.24, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.70)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16.0
	row.offset_right = -16.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_keycap_row = HBoxContainer.new()
	_keycap_row.name = "Keycaps"
	_keycap_row.add_theme_constant_override("separation", 4)
	_keycap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_keycap_row)

	_label = Label.new()
	_label.name = "CoachLine"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(300.0, 0.0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.76, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)


func _set_keycaps(keys: Array) -> void:
	if _keycap_row == null:
		return
	for child: Node in _keycap_row.get_children():
		child.queue_free()
	for key: Variant in keys:
		var cap := Label.new()
		cap.text = str(key)
		cap.custom_minimum_size = Vector2(24.0, 24.0)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1.0))
		var cap_style := StyleBoxFlat.new()
		cap_style.bg_color = Color(0.92, 0.80, 0.44, 1.0)
		cap_style.set_corner_radius_all(4)
		cap.add_theme_stylebox_override("normal", cap_style)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keycap_row.add_child(cap)
