## GameAudio owns everything the player hears.
##
## The interface is deliberately small -- `play()`, `set_music_intensity()` and
## the three volume accessors -- because callers should never have to know about
## buses, voice pools, decibels or crossfades to make a sound. All of that lives
## in here.
##
## The adaptive music is built on one idea: the three layers are the same eight
## seconds of music at the same tempo, and they are all started on the same frame
## and never stopped. Intensity only moves their gains. That means the score can
## escalate from "archive at rest" to "the Guardian has you" and back without a
## restart, a seam, or a tempo slip, because the layers never drift out of phase
## with each other.
extends Node

signal bus_volume_changed(bus: StringName, linear: float)

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const UI_BUS := &"UI"

const INTENSITY_CALM := &"calm"
const INTENSITY_TENSION := &"tension"
const INTENSITY_CHASE := &"chase"

const PREFERENCE_PATH := "user://shadow_castle_preferences.cfg"
const AUDIO_SECTION := "audio"

## Sound identifier -> {stream, bus, gain (linear), pitch spread}.
## A caller names the event, never the file: `GameAudio.play(&"bench_pass")`.
const SFX_CATALOG: Dictionary = {
	&"ui_select": {"file": "ui_select", "bus": UI_BUS, "gain": 0.55, "spread": 0.045},
	&"ui_confirm": {"file": "ui_confirm", "bus": UI_BUS, "gain": 0.80, "spread": 0.02},
	&"ui_back": {"file": "ui_back", "bus": UI_BUS, "gain": 0.60, "spread": 0.03},
	&"item_pickup": {"file": "item_pickup", "bus": SFX_BUS, "gain": 0.85, "spread": 0.035},
	&"note_file": {"file": "note_file", "bus": SFX_BUS, "gain": 0.75, "spread": 0.04},
	&"switch_throw": {"file": "switch_throw", "bus": SFX_BUS, "gain": 0.95, "spread": 0.03},
	&"bench_pass": {"file": "bench_pass", "bus": SFX_BUS, "gain": 0.90, "spread": 0.0},
	&"bench_fail": {"file": "bench_fail", "bus": SFX_BUS, "gain": 0.80, "spread": 0.025},
	&"potion_extract": {"file": "potion_extract", "bus": SFX_BUS, "gain": 0.90, "spread": 0.0},
	&"guardian_alert": {"file": "guardian_alert", "bus": SFX_BUS, "gain": 1.0, "spread": 0.0},
}

## Layer gains per intensity. Every layer is always playing; only these move.
const INTENSITY_MIX: Dictionary = {
	INTENSITY_CALM: {"bed": 1.0, "tension": 0.0, "chase": 0.0},
	INTENSITY_TENSION: {"bed": 0.80, "tension": 1.0, "chase": 0.0},
	INTENSITY_CHASE: {"bed": 0.45, "tension": 0.70, "chase": 1.0},
}

const MUSIC_FILES: Dictionary = {
	"bed": "res://assets/audio/music/music_bed.wav",
	"tension": "res://assets/audio/music/music_tension.wav",
	"chase": "res://assets/audio/music/music_chase.wav",
}

const SFX_DIRECTORY := "res://assets/audio/sfx/"
const VOICE_COUNT := 12
const CROSSFADE_SECONDS := 1.25
## Below this linear gain a layer is silent; muting it saves pointless mixing.
const SILENCE_EPSILON := 0.0008
## How far the music ducks, and for how long, when a stinger needs the room.
const DUCK_FLOOR := 0.38
const DUCK_RECOVER_SECONDS := 1.1

var music_intensity: StringName = INTENSITY_CALM

var _music_players: Dictionary = {}
var _layer_gain: Dictionary = {}
var _layer_target: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}
var _duck := 1.0
var _duck_hold := 0.0
var _music_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_volumes()
	_build_voices()
	_build_music()
	set_music_intensity(INTENSITY_CALM, true)
	# Knowing which game events make a sound is this module's job, not the sender's.
	# Subscribing here keeps GameState free of any audio vocabulary.
	if not GameState.item_acquired.is_connected(_on_item_acquired):
		GameState.item_acquired.connect(_on_item_acquired)


func _on_item_acquired(_item_id: String, kind: String, _amount: int) -> void:
	# Filing a record is a quieter act than pocketing an object.
	play(&"note_file" if kind == "note" or kind == "record" else &"item_pickup")


func _process(delta: float) -> void:
	_advance_duck(delta)
	_advance_crossfade(delta)


func _exit_tree() -> void:
	# The music layers are deliberately never stopped during play, so shutdown is
	# the one place that has to release them. Without this the engine reports the
	# held streams as leaked resources on every quit.
	for layer: String in _music_players.keys():
		var player := _music_players[layer] as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	_music_players.clear()
	_streams.clear()


# ------------------------------------------------------------------ one-shots


## Play a catalogued event. Unknown ids are ignored rather than raised: a missing
## sound must never be able to interrupt play.
func play(sound_id: StringName) -> void:
	var spec: Dictionary = SFX_CATALOG.get(sound_id, {})
	if spec.is_empty():
		return
	var stream: AudioStream = _streams.get(sound_id) as AudioStream
	if stream == null:
		return
	var voice := _take_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.bus = spec.get("bus", SFX_BUS)
	voice.volume_db = linear_to_db(maxf(0.0001, float(spec.get("gain", 1.0))))
	# A repeated sound played at exactly one pitch is how a game starts sounding
	# mechanical. A few cents of spread is enough to stop the ear locking on.
	var spread := float(spec.get("spread", 0.0))
	voice.pitch_scale = 1.0 if spread <= 0.0 else randfn(1.0, spread * 0.5)
	voice.pitch_scale = clampf(voice.pitch_scale, 0.82, 1.22)
	voice.play()


## Pull the music down briefly so a decisive moment can be heard over it.
func duck_music(seconds := DUCK_RECOVER_SECONDS) -> void:
	_duck = DUCK_FLOOR
	_duck_hold = maxf(_duck_hold, seconds)


# --------------------------------------------------------------------- music


func set_music_intensity(intensity: StringName, immediate := false) -> void:
	if not INTENSITY_MIX.has(intensity):
		return
	if music_intensity == intensity and not immediate:
		return
	music_intensity = intensity
	var mix: Dictionary = INTENSITY_MIX[intensity]
	for layer: String in _music_players.keys():
		_layer_target[layer] = float(mix.get(layer, 0.0))
		if immediate:
			_layer_gain[layer] = _layer_target[layer]
	if immediate:
		_apply_layer_gains()


## Convenience for callers that only know how dangerous things are.
func set_music_for_guardian(hunt_active: bool, chasing: bool) -> void:
	if chasing:
		set_music_intensity(INTENSITY_CHASE)
	elif hunt_active:
		set_music_intensity(INTENSITY_TENSION)
	else:
		set_music_intensity(INTENSITY_CALM)


func layer_gain(layer: String) -> float:
	return float(_layer_gain.get(layer, 0.0))


# ------------------------------------------------------------------- volumes


func set_bus_volume_linear(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= SILENCE_EPSILON)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(SILENCE_EPSILON, clamped)))
	_save_volume(bus, clamped)
	bus_volume_changed.emit(bus, clamped)


func get_bus_volume_linear(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 0.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


# ------------------------------------------------------------------ internals


func _build_voices() -> void:
	for sound_id: StringName in SFX_CATALOG.keys():
		var spec: Dictionary = SFX_CATALOG[sound_id]
		var stream := load(SFX_DIRECTORY + str(spec.get("file", "")) + ".wav") as AudioStream
		if stream != null:
			_streams[sound_id] = stream
	for index: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%02d" % index
		voice.bus = SFX_BUS
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_voices.append(voice)


func _take_voice() -> AudioStreamPlayer:
	# Prefer a free voice; if every one is busy, steal the oldest in rotation so a
	# burst of feedback thins out instead of dropping the newest, most relevant
	# sound.
	for offset: int in range(VOICE_COUNT):
		var candidate := _voices[(_next_voice + offset) % VOICE_COUNT]
		if not candidate.playing:
			_next_voice = (_next_voice + offset + 1) % VOICE_COUNT
			return candidate
	var stolen := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	return stolen


func _build_music() -> void:
	for layer: String in MUSIC_FILES.keys():
		var stream := load(MUSIC_FILES[layer]) as AudioStream
		if stream == null:
			continue
		_mark_looping(stream)
		var player := AudioStreamPlayer.new()
		player.name = "Music_" + layer
		player.stream = stream
		player.bus = MUSIC_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = linear_to_db(SILENCE_EPSILON)
		add_child(player)
		_music_players[layer] = player
		_layer_gain[layer] = 0.0
		_layer_target[layer] = 0.0
	_start_music()


## The layers are only sample-locked if they begin on the same frame. Starting
## them in a loop within one call is what keeps them in phase for the whole
## session; nothing after this is ever allowed to stop or restart one of them.
func _start_music() -> void:
	if _music_started or _music_players.is_empty():
		return
	for layer: String in _music_players.keys():
		(_music_players[layer] as AudioStreamPlayer).play()
	_music_started = true


func _mark_looping(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	# Generated as a whole number of bars, so the loop is the whole file.
	# `loop_end` is a frame index, not a sentinel: leaving it at 0 defines a
	# zero-length loop and the layer stops on the frame it starts.
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = maxi(1, int(round(wav.get_length() * float(wav.mix_rate))))


func _advance_crossfade(delta: float) -> void:
	if _music_players.is_empty():
		return
	var step := delta / maxf(0.01, CROSSFADE_SECONDS)
	var moved := false
	for layer: String in _music_players.keys():
		var current := float(_layer_gain.get(layer, 0.0))
		var target := float(_layer_target.get(layer, 0.0))
		if is_equal_approx(current, target):
			continue
		_layer_gain[layer] = move_toward(current, target, step)
		moved = true
	if moved or not is_equal_approx(_duck, 1.0):
		_apply_layer_gains()


func _apply_layer_gains() -> void:
	for layer: String in _music_players.keys():
		var player := _music_players[layer] as AudioStreamPlayer
		var gain := float(_layer_gain.get(layer, 0.0)) * _duck
		if gain <= SILENCE_EPSILON:
			# Silent layers keep playing -- muting the *player* would desynchronise
			# them. Only the gain goes to the floor.
			player.volume_db = linear_to_db(SILENCE_EPSILON)
		else:
			player.volume_db = linear_to_db(gain)


func _advance_duck(delta: float) -> void:
	if _duck_hold > 0.0:
		_duck_hold -= delta
		return
	if is_equal_approx(_duck, 1.0):
		return
	_duck = move_toward(_duck, 1.0, delta / maxf(0.01, DUCK_RECOVER_SECONDS))
	_apply_layer_gains()


func _load_volumes() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(PREFERENCE_PATH) == OK
	for bus: StringName in [&"Master", MUSIC_BUS, SFX_BUS, UI_BUS]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		if not loaded:
			continue
		# `get_value` with a null default still raises when the key is missing, so
		# the presence check has to come first.
		if not config.has_section_key(AUDIO_SECTION, String(bus)):
			continue
		var linear := clampf(float(config.get_value(AUDIO_SECTION, String(bus))), 0.0, 1.0)
		AudioServer.set_bus_mute(index, linear <= SILENCE_EPSILON)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(SILENCE_EPSILON, linear)))


func _save_volume(bus: StringName, linear: float) -> void:
	var config := ConfigFile.new()
	# Share the file with CaseLocale and PlayerPreferences rather than opening a
	# second settings file the player would have to keep in sync.
	config.load(PREFERENCE_PATH)
	config.set_value(AUDIO_SECTION, String(bus), linear)
	config.save(PREFERENCE_PATH)
