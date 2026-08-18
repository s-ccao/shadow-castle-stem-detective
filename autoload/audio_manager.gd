extends Node

## AudioManager —— 全局音频总线与播放入口。
##
## 仓库此前没有任何音频：0 个音频文件、0 个 AudioStreamPlayer。这里补上
## 整套基础设施——三条总线、音量持久化、按 id 播放的入口，以及一组
## **程序合成的占位音效**（assets/audio/，纯正弦/噪声算出来的，不涉及任何
## 第三方素材）。占位音的作用是让这套系统现在就可听、可测；将来把同名文件
## 换成真实录音即可，代码一行都不用动。
##
## 三条总线独立音量，是因为玩家对音乐和音效的容忍度不一样，而 UI 音在
## 高频操作下最容易先变吵。

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"
const BUSES: Array[String] = [MUSIC_BUS, SFX_BUS, UI_BUS]

const PREFERENCE_PATH := "user://shadow_castle_preferences.cfg"
const PREFERENCE_SECTION := "audio"

const AUDIO_DIR := "res://assets/audio/"

## 同时可播的音效数。超过就复用最早那个播放器，避免无限增长的节点树。
const SFX_VOICES: int = 8

## 同一个音效在这个间隔内重复触发只播一次。快速点按钮时不会叠成噪音墙。
const RETRIGGER_GUARD: float = 0.045

var _volumes: Dictionary = {}
var _muted: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: AudioStreamPlayer
var _streams: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	name = "AudioManager"
	# 暂停时 UI 仍然要有反馈，所以音频不跟随暂停。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_preferences()
	_build_players()


## 运行时创建总线，而不是提交一个二进制的 .tres 布局文件——纯文本改动
## 可审阅，也不会因为布局文件丢失就整套静音。
func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index: int = AudioServer.get_bus_count()
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _build_players() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "MusicPlayer"
	_music.bus = MUSIC_BUS
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)

	for voice: int in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % voice
		player.bus = SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)


## 按 id 取流并缓存。缺文件不报错，只是不出声——音频永远不该让游戏崩。
func _stream(sound_id: String) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id] as AudioStream
	var path: String = AUDIO_DIR + sound_id + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_streams[sound_id] = stream
	return stream


func play_sfx(sound_id: String, volume_db: float = 0.0) -> void:
	_play(sound_id, SFX_BUS, volume_db)


func play_ui(sound_id: String, volume_db: float = 0.0) -> void:
	_play(sound_id, UI_BUS, volume_db)


func _play(sound_id: String, bus: String, volume_db: float) -> void:
	var stream: AudioStream = _stream(sound_id)
	if stream == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_id, -99.0)) < RETRIGGER_GUARD:
		return
	_last_played[sound_id] = now
	var player: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	player.bus = bus
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_music(sound_id: String, loop: bool = true) -> void:
	var stream: AudioStream = _stream(sound_id)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


# ---- 音量 ----


## 0.0 ~ 1.0 的线性音量。玩家理解的是"一半音量"，不是 -6 dB。
func volume(bus: String) -> float:
	return float(_volumes.get(bus, 0.8))


func is_muted(bus: String) -> bool:
	return bool(_muted.get(bus, false))


func set_volume(bus: String, linear: float) -> void:
	if not BUSES.has(bus):
		return
	_volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)
	_save_preferences()


func set_muted(bus: String, muted: bool) -> void:
	if not BUSES.has(bus):
		return
	_muted[bus] = muted
	_apply_bus(bus)
	_save_preferences()


func _apply_bus(bus: String) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var linear: float = volume(bus)
	# linear_to_db(0) 是 -inf，直接用静音标志表达"关掉"。
	if is_muted(bus) or linear <= 0.001:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))


func _load_preferences() -> void:
	var config := ConfigFile.new()
	var loaded: bool = config.load(PREFERENCE_PATH) == OK
	for bus: String in BUSES:
		var default_volume: float = 0.65 if bus == MUSIC_BUS else 0.85
		if loaded:
			_volumes[bus] = float(
				config.get_value(PREFERENCE_SECTION, bus + "_volume", default_volume)
			)
			_muted[bus] = bool(
				config.get_value(PREFERENCE_SECTION, bus + "_muted", false)
			)
		else:
			_volumes[bus] = default_volume
			_muted[bus] = false
		_apply_bus(bus)


func _save_preferences() -> void:
	# 语言设置也写在同一个文件里，必须先读回来再写，否则会把它抹掉。
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	for bus: String in BUSES:
		config.set_value(PREFERENCE_SECTION, bus + "_volume", volume(bus))
		config.set_value(PREFERENCE_SECTION, bus + "_muted", is_muted(bus))
	config.save(PREFERENCE_PATH)
