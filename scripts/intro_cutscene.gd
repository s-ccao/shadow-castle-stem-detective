extends Control

## Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
## Macrostructure: four linked cinematic cuts. Every cut answers one question
## (why arrive, what happened, what was lost, what to do next) while leaving the
## culprit deliberately out of frame.

const INVITATION_ART: Texture2D = preload("res://assets/cinematics/intro_01_invitation.png")
const SIGNAL_ART: Texture2D = preload("res://assets/cinematics/intro_02_signal.png")
const INTERRUPTION_ART: Texture2D = preload("res://assets/cinematics/intro_03_interruption.png")
const WAKE_ART: Texture2D = preload("res://assets/cinematics/intro_04_wake.png")

const AUTO_ADVANCE_SECONDS := [7.2, 7.4, 6.4]
const SCORE_MIX_RATE := 22050.0

const INK_LIGHT := Color(0.96, 0.88, 0.70, 1.0)
const INK_MUTED := Color(0.74, 0.64, 0.47, 1.0)
const BRASS := Color(0.86, 0.61, 0.24, 0.98)
const BRASS_DIM := Color(0.38, 0.22, 0.08, 0.94)
const PANEL_FILL := Color(0.032, 0.020, 0.024, 0.92)
const PANEL_INLAY := Color(0.080, 0.045, 0.030, 0.94)
var page_index := 0
var pages: Array[Dictionary] = []
var page_tween: Tween
var art_tween: Tween
var flash_tween: Tween
var has_shown_first_page := false
var page_elapsed := 0.0
var is_ending := false
var score_time := 0.0
var score_tension := 0.18
var rain_memory := 0.0
var score_player: AudioStreamPlayer
var score_playback: AudioStreamGeneratorPlayback

var art_front: TextureRect
var atmosphere_veil: ColorRect
var flash_overlay: ColorRect
var top_rule: ColorRect
var case_kicker: Label
var page_label: Label
var title_label: Label
var body_label: Label
var detail_title: Label
var detail_label: Label
var detail_dot: ColorRect
var case_card: Panel
var detail_card: Panel
var advance_meter: ColorRect
var continue_button: Button
var skip_button: Button
var prompt_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pages = _build_pages()
	_create_cutscene_ui()
	CaseLocale.locale_changed.connect(_refresh_copy)
	show_page(false)
	_start_ambient_score()


func _build_pages() -> Array[Dictionary]:
	return [
		{
			"art": INVITATION_ART,
			"kicker": "intro.invitation_kicker",
			"title": "intro.invitation_title",
			"body": "intro.invitation_body",
			"detail_title": "intro.invitation_detail_title",
			"detail": "intro.invitation_detail",
			"tint": Color(0.030, 0.040, 0.12, 0.17),
			"drift": Vector2(-18.0, -10.0),
		},
		{
			"art": SIGNAL_ART,
			"kicker": "intro.signal_kicker",
			"title": "intro.signal_title",
			"body": "intro.signal_body",
			"detail_title": "intro.signal_detail_title",
			"detail": "intro.signal_detail",
			"tint": Color(0.14, 0.026, 0.17, 0.20),
			"drift": Vector2(-8.0, -16.0),
		},
		{
			"art": INTERRUPTION_ART,
			"kicker": "intro.interruption_kicker",
			"title": "intro.interruption_title",
			"body": "intro.interruption_body",
			"detail_title": "intro.interruption_detail_title",
			"detail": "intro.interruption_detail",
			"tint": Color(0.13, 0.020, 0.12, 0.22),
			"drift": Vector2(-20.0, -4.0),
		},
		{
			"art": WAKE_ART,
			"kicker": "intro.wake_kicker",
			"title": "intro.wake_title",
			"body": "intro.wake_body",
			"detail_title": "intro.wake_detail_title",
			"detail": "intro.wake_detail",
			"tint": Color(0.025, 0.050, 0.12, 0.15),
			"drift": Vector2(-8.0, -12.0),
		},
	]


func _create_cutscene_ui() -> void:
	art_front = _new_art_layer("CaseArtFront")
	add_child(art_front)

	atmosphere_veil = ColorRect.new()
	atmosphere_veil.name = "AtmosphereVeil"
	atmosphere_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere_veil)

	var lower_shade := ColorRect.new()
	lower_shade.name = "LowerReadabilityShade"
	lower_shade.color = Color(0.01, 0.006, 0.016, 0.58)
	lower_shade.anchor_top = 0.62
	lower_shade.anchor_right = 1.0
	lower_shade.anchor_bottom = 1.0
	lower_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower_shade)

	_create_topline()
	_create_case_card()
	_create_detail_card()
	_create_controls()

	flash_overlay = ColorRect.new()
	flash_overlay.name = "SignalFlash"
	flash_overlay.color = Color(0.51, 0.26, 0.87, 0.38)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.modulate.a = 0.0
	add_child(flash_overlay)


func _new_art_layer(layer_name: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.pivot_offset = Vector2(512.0, 384.0)
	return layer


func _create_topline() -> void:
	case_kicker = Label.new()
	case_kicker.name = "CaseKicker"
	case_kicker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	case_kicker.offset_left = 52.0
	case_kicker.offset_top = 38.0
	case_kicker.offset_right = 492.0
	case_kicker.offset_bottom = 62.0
	case_kicker.add_theme_font_size_override("font_size", 14)
	case_kicker.add_theme_color_override("font_color", INK_LIGHT)
	ArchiveUi.apply_label(case_kicker, &"muted")
	add_child(case_kicker)

	page_label = Label.new()
	page_label.name = "PageLabel"
	page_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	page_label.offset_left = -208.0
	page_label.offset_top = 38.0
	page_label.offset_right = -98.0
	page_label.offset_bottom = 62.0
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_label.add_theme_font_size_override("font_size", 13)
	ArchiveUi.apply_label(page_label, &"muted")
	add_child(page_label)

	top_rule = ColorRect.new()
	top_rule.name = "CaseRule"
	top_rule.color = BRASS
	top_rule.anchor_left = 0.05
	top_rule.anchor_top = 0.09
	top_rule.anchor_right = 0.95
	top_rule.anchor_bottom = 0.09
	top_rule.offset_bottom = 2.0
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)


func _create_case_card() -> void:
	case_card = Panel.new()
	case_card.name = "CinematicSubtitleBand"
	case_card.anchor_left = 0.16
	case_card.anchor_top = 0.72
	case_card.anchor_right = 0.84
	case_card.anchor_bottom = 0.91
	case_card.add_theme_stylebox_override("panel", _panel_style(PANEL_FILL, BRASS, 2, 5, 13))
	case_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(case_card)

	var inlay := Panel.new()
	inlay.name = "CaseBriefingInlay"
	inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inlay.offset_left = 5.0
	inlay.offset_top = 5.0
	inlay.offset_right = -5.0
	inlay.offset_bottom = -5.0
	inlay.add_theme_stylebox_override("panel", _panel_style(PANEL_INLAY, BRASS_DIM, 1, 3, 0))
	inlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_card.add_child(inlay)

	title_label = Label.new()
	title_label.name = "CaseTitle"
	title_label.anchor_left = 0.0
	title_label.anchor_top = 0.0
	title_label.anchor_right = 1.0
	title_label.anchor_bottom = 0.0
	title_label.offset_left = 28.0
	title_label.offset_top = 17.0
	title_label.offset_right = -28.0
	title_label.offset_bottom = 46.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 21)
	ArchiveUi.apply_label(title_label, &"title")
	case_card.add_child(title_label)

	body_label = Label.new()
	body_label.name = "CaseBody"
	body_label.anchor_left = 0.0
	body_label.anchor_top = 0.0
	body_label.anchor_right = 1.0
	body_label.anchor_bottom = 0.0
	body_label.offset_left = 36.0
	body_label.offset_top = 56.0
	body_label.offset_right = -36.0
	body_label.offset_bottom = 120.0
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 16)
	ArchiveUi.apply_label(body_label, &"body")
	case_card.add_child(body_label)

	advance_meter = ColorRect.new()
	advance_meter.name = "AutoAdvanceMeter"
	advance_meter.color = Color(0.56, 0.33, 0.90, 0.92)
	advance_meter.anchor_top = 1.0
	advance_meter.anchor_bottom = 1.0
	advance_meter.offset_top = -3.0
	advance_meter.offset_bottom = -1.0
	advance_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_card.add_child(advance_meter)


func _create_detail_card() -> void:
	detail_card = Panel.new()
	detail_card.name = "CinematicObjectiveCard"
	detail_card.anchor_left = 0.68
	detail_card.anchor_top = 0.13
	detail_card.anchor_right = 0.94
	detail_card.anchor_bottom = 0.27
	detail_card.add_theme_stylebox_override("panel", _panel_style(Color(0.022, 0.015, 0.032, 0.92), Color(0.48, 0.29, 0.72, 0.92), 1, 4, 10))
	detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_card)

	detail_dot = ColorRect.new()
	detail_dot.name = "SignalMarker"
	detail_dot.color = BRASS
	detail_dot.position = Vector2(18.0, 20.0)
	detail_dot.size = Vector2(8.0, 8.0)
	detail_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_card.add_child(detail_dot)

	detail_title = Label.new()
	detail_title.name = "SignalTitle"
	detail_title.anchor_left = 0.0
	detail_title.anchor_top = 0.0
	detail_title.anchor_right = 1.0
	detail_title.anchor_bottom = 0.0
	detail_title.offset_left = 38.0
	detail_title.offset_top = 12.0
	detail_title.offset_right = -16.0
	detail_title.offset_bottom = 40.0
	detail_title.add_theme_font_size_override("font_size", 12)
	ArchiveUi.apply_label(detail_title, &"muted")
	detail_card.add_child(detail_title)

	detail_label = Label.new()
	detail_label.name = "SignalDetail"
	detail_label.anchor_left = 0.0
	detail_label.anchor_top = 0.0
	detail_label.anchor_right = 1.0
	detail_label.anchor_bottom = 0.0
	detail_label.offset_left = 18.0
	detail_label.offset_top = 42.0
	detail_label.offset_right = -18.0
	detail_label.offset_bottom = 94.0
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	ArchiveUi.apply_label(detail_label, &"body")
	detail_card.add_child(detail_label)


func _create_controls() -> void:
	skip_button = Button.new()
	skip_button.name = "SkipCutsceneButton"
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -94.0
	skip_button.offset_top = 28.0
	skip_button.offset_right = -42.0
	skip_button.offset_bottom = 62.0
	skip_button.add_theme_font_size_override("font_size", 11)
	ArchiveUi.apply_button(skip_button, ArchiveUi.ROLE_MUTED)
	skip_button.pressed.connect(skip_cutscene)
	add_child(skip_button)

	continue_button = Button.new()
	continue_button.name = "ContinueCutsceneButton"
	continue_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	continue_button.offset_left = -308.0
	continue_button.offset_top = -52.0
	continue_button.offset_right = -48.0
	continue_button.offset_bottom = -18.0
	continue_button.add_theme_font_size_override("font_size", 14)
	ArchiveUi.apply_button(continue_button, ArchiveUi.ROLE_ACTION)
	continue_button.pressed.connect(next_page)
	add_child(continue_button)

	prompt_label = Label.new()
	prompt_label.name = "AdvancePrompt"
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	prompt_label.offset_left = 54.0
	prompt_label.offset_top = -46.0
	prompt_label.offset_right = 520.0
	prompt_label.offset_bottom = -20.0
	prompt_label.add_theme_font_size_override("font_size", 12)
	ArchiveUi.apply_label(prompt_label, &"muted")
	add_child(prompt_label)


func show_page(animate: bool = true) -> void:
	if pages.is_empty():
		return
	var page: Dictionary = pages[page_index]
	page_elapsed = 0.0
	score_tension = 0.18 + 0.09 * page_index
	case_kicker.text = CaseLocale.text(str(page["kicker"]))
	title_label.text = CaseLocale.text(str(page["title"]))
	body_label.text = CaseLocale.text(str(page["body"]))
	detail_title.text = CaseLocale.text(str(page["detail_title"]))
	detail_label.text = CaseLocale.text(str(page["detail"]))
	page_label.text = CaseLocale.text("intro.page_count", {"current": page_index + 1, "total": pages.size()})
	skip_button.text = CaseLocale.text("intro.skip")
	continue_button.text = CaseLocale.text("intro.begin") if _is_last_page() else CaseLocale.text("intro.continue")
	prompt_label.text = CaseLocale.text("intro.advance_hint_final") if _is_last_page() else CaseLocale.text("intro.advance_hint")
	advance_meter.visible = not _is_last_page()
	advance_meter.anchor_right = 0.0
	_update_art(page, animate and has_shown_first_page)
	_animate_briefing(animate and has_shown_first_page)
	if has_shown_first_page:
		_play_signal_pulse()
	has_shown_first_page = true
	continue_button.call_deferred("grab_focus")


func _update_art(page: Dictionary, animate: bool) -> void:
	var next_art: Texture2D = page["art"] as Texture2D
	atmosphere_veil.color = page["tint"] as Color
	if art_front.texture == next_art:
		_start_art_drift()
		return
	art_front.texture = next_art
	art_front.modulate.a = 1.0
	# Pixel-art scenes read best as a hard cut plus restrained UI motion. It also
	# prevents a prior crossfade from leaving a stale room behind the new briefing.
	_start_art_drift(page["drift"] as Vector2)


func _start_art_drift(drift: Vector2 = Vector2(-18.0, -12.0)) -> void:
	if art_tween != null and art_tween.is_valid():
		art_tween.kill()
	art_front.scale = Vector2(1.0, 1.0)
	art_front.position = Vector2.ZERO
	art_tween = create_tween()
	art_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	art_tween.tween_property(art_front, "scale", Vector2(1.035, 1.035), 7.0)
	art_tween.parallel().tween_property(art_front, "position", drift, 7.0)


func _animate_briefing(animate: bool) -> void:
	if page_tween != null and page_tween.is_valid():
		page_tween.kill()
	if not animate:
		case_card.modulate.a = 1.0
		detail_card.modulate.a = 1.0
		return
	case_card.modulate.a = 0.0
	detail_card.modulate.a = 0.0
	page_tween = create_tween()
	page_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	page_tween.tween_property(case_card, "modulate:a", 1.0, 0.24)
	page_tween.parallel().tween_property(detail_card, "modulate:a", 1.0, 0.20)


func _play_signal_pulse() -> void:
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_overlay.modulate.a = 0.0
	detail_dot.scale = Vector2.ONE
	flash_tween = create_tween()
	flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.46, 0.07)
	flash_tween.parallel().tween_property(detail_dot, "scale", Vector2(1.7, 1.7), 0.07)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.22)
	flash_tween.parallel().tween_property(detail_dot, "scale", Vector2.ONE, 0.22)


func _gui_input(event: InputEvent) -> void:
	if is_ending:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			next_page()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_ending:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		next_page()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			skip_cutscene()
			get_viewport().set_input_as_handled()


func next_page() -> void:
	if is_ending:
		return
	if _is_last_page():
		go_to_game()
		return
	page_index += 1
	show_page()


func skip_cutscene() -> void:
	go_to_game()


func go_to_game() -> void:
	if is_ending:
		return
	is_ending = true
	continue_button.disabled = true
	skip_button.disabled = true
	if score_player != null:
		var fade := create_tween()
		fade.tween_property(score_player, "volume_db", -60.0, 0.32)
		await fade.finished
	if GameState.is_game_started():
		GameState.save_room_checkpoint(
			"res://scenes/wake_room.tscn",
			"wake_room",
			"wake_room_start"
		)
	get_tree().change_scene_to_file("res://scenes/wake_room.tscn")


func _refresh_copy(_language: String = "") -> void:
	show_page(false)


func _is_last_page() -> bool:
	return page_index >= pages.size() - 1


func _process(delta: float) -> void:
	_fill_score_buffer()
	if is_ending or _is_last_page() or page_index >= AUTO_ADVANCE_SECONDS.size():
		return
	page_elapsed += delta
	var duration: float = AUTO_ADVANCE_SECONDS[page_index]
	advance_meter.anchor_right = clampf(page_elapsed / duration, 0.0, 1.0)
	if page_elapsed >= duration:
		next_page()


func _start_ambient_score() -> void:
	score_player = AudioStreamPlayer.new()
	score_player.name = "IntroAtmosphere"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SCORE_MIX_RATE
	stream.buffer_length = 0.35
	score_player.stream = stream
	score_player.bus = &"Master"
	score_player.volume_db = -20.0
	add_child(score_player)
	score_player.play()
	score_playback = score_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_score_buffer() -> void:
	if score_playback == null:
		return
	var frame_count := score_playback.get_frames_available()
	for _frame in frame_count:
		score_playback.push_frame(_next_score_frame())


func _next_score_frame() -> Vector2:
	score_time += 1.0 / SCORE_MIX_RATE
	var slow_wobble := sin(TAU * 0.043 * score_time)
	var drone := sin(TAU * (46.25 + slow_wobble * 0.35) * score_time) * 0.040
	drone += sin(TAU * 69.30 * score_time) * 0.019
	var upper_pad := sin(TAU * 138.59 * score_time) * (0.006 + score_tension * 0.010)
	var bell_phase := fmod(score_time, 4.8 - score_tension * 0.65)
	var bell_envelope := exp(-bell_phase * 2.25)
	var bell := sin(TAU * 220.0 * score_time) * bell_envelope * (0.008 + score_tension * 0.012)
	var white_noise := randf_range(-1.0, 1.0)
	rain_memory = lerpf(rain_memory, white_noise, 0.065)
	var rain := (white_noise - rain_memory) * (0.005 + score_tension * 0.007)
	var mono := clampf(drone + upper_pad + bell + rain, -0.20, 0.20)
	return Vector2(mono * 0.97, mono)


func _panel_style(fill: Color, border: Color, width: int, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.004, 0.002, 0.008, 0.82)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 4.0)
	return style
