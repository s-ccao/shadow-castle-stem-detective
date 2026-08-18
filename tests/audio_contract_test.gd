extends SceneTree

## Audio contract.
##
## The adaptive score rests on one guarantee that is easy to break by accident:
## the three music layers are the same eight seconds of music, started on the
## same frame and never stopped. Intensity is only ever a gain change. If any
## future edit stops or restarts a layer to "save CPU", the layers drift out of
## phase and the score turns into three pieces of music playing over each other.
## These assertions exist to make that failure loud.

const EXPECTED_BUSES: Array[String] = ["Master", "Music", "SFX", "UI"]
const PHASE_TOLERANCE_SECONDS := 0.02

var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio == null:
		_fail("GameAudio autoload is not registered")
		_finish()
		return

	for bus_name: String in EXPECTED_BUSES:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "Bus '%s' exists in the layout" % bus_name)
	for bus_name: String in ["Music", "SFX", "UI"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			_expect(
				AudioServer.get_bus_send(index) == &"Master",
				"Bus '%s' routes through Master so one fader governs everything" % bus_name
			)

	await _check_catalog(audio)
	await _check_music_layers(audio)
	await _check_intensity(audio)
	await _check_ducking(audio)
	_check_volumes(audio)
	await _check_settings_faders(audio)
	_finish()


func _check_settings_faders(audio: Node) -> void:
	# Buses are only a feature if the player can reach them. Music and effects get
	# separate faders because muting everything to silence one of them is a loss.
	var scene := load("res://scenes/main_menu.tscn") as PackedScene
	if scene == null:
		_fail("Main menu scene could not load")
		return
	var menu := scene.instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_show_settings_dialog")
	await process_frame

	for bus_name: String in ["Music", "SFX"]:
		var slider := menu.find_child("VolumeSlider_" + bus_name, true, false) as HSlider
		_expect(slider != null, "Settings exposes a %s fader" % bus_name)
		if slider == null:
			continue
		_expect(slider.visible, "%s fader is visible on the settings dialog" % bus_name)
		var restore := float(audio.call("get_bus_volume_linear", StringName(bus_name)))
		slider.value = 0.25
		await process_frame
		_expect(
			absf(float(audio.call("get_bus_volume_linear", StringName(bus_name))) - 0.25) < 0.02,
			"Moving the %s fader actually moves the %s bus" % [bus_name, bus_name]
		)
		audio.call("set_bus_volume_linear", StringName(bus_name), restore)

	menu.queue_free()
	await process_frame


func _check_catalog(audio: Node) -> void:
	var catalog: Dictionary = audio.get("SFX_CATALOG")
	_expect(catalog.size() >= 10, "Sound catalog covers the game's feedback events")
	for sound_id: StringName in catalog.keys():
		var spec: Dictionary = catalog[sound_id]
		var path: String = "res://assets/audio/sfx/" + str(spec.get("file", "")) + ".wav"
		_expect(ResourceLoader.exists(path), "Sound '%s' resolves to a generated file" % sound_id)
		var bus: StringName = spec.get("bus", &"")
		_expect(AudioServer.get_bus_index(bus) >= 0, "Sound '%s' names a real bus" % sound_id)

	# Playing every sound must never exhaust the voice pool or raise.
	for sound_id: StringName in catalog.keys():
		audio.call("play", sound_id)
	audio.call("play", &"no_such_sound")
	await process_frame
	_expect(true, "Playing the whole catalog back to back is survivable")


func _check_music_layers(audio: Node) -> void:
	var players: Dictionary = audio.get("_music_players")
	_expect(players.size() == 3, "Three music layers are installed")
	var positions: Array[float] = []
	for layer: String in players.keys():
		var player := players[layer] as AudioStreamPlayer
		_expect(player != null and player.playing, "Music layer '%s' is playing" % layer)
		if player != null:
			positions.append(player.get_playback_position())
			var wav := player.stream as AudioStreamWAV
			_expect(
				wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"Music layer '%s' loops rather than running out" % layer
			)
	if positions.size() >= 2:
		var spread: float = positions.max() - positions.min()
		_expect(
			spread <= PHASE_TOLERANCE_SECONDS,
			"Music layers share a playback position (spread %.4fs)" % spread
		)


func _check_intensity(audio: Node) -> void:
	audio.call("set_music_intensity", &"calm", true)
	_expect(float(audio.call("layer_gain", "bed")) > 0.9, "Calm leads with the bed layer")
	_expect(float(audio.call("layer_gain", "chase")) <= 0.001, "Calm keeps the chase layer silent")

	audio.call("set_music_intensity", &"chase")
	_expect(
		float(audio.call("layer_gain", "chase")) < 0.999,
		"Escalation crossfades rather than snapping the chase layer on"
	)

	# Drive the fade to completion the way frames would.
	for _step: int in range(180):
		audio.call("_advance_crossfade", 1.0 / 60.0)
	_expect(float(audio.call("layer_gain", "chase")) > 0.99, "Escalation reaches the chase mix")

	var players: Dictionary = audio.get("_music_players")
	for layer: String in players.keys():
		_expect(
			(players[layer] as AudioStreamPlayer).playing,
			"Layer '%s' keeps playing across an intensity change" % layer
		)

	# Same guarantee on the way back down.
	audio.call("set_music_for_guardian", false, false)
	_expect(audio.get("music_intensity") == &"calm", "A cleared hunt returns the score to calm")
	audio.call("set_music_for_guardian", true, false)
	_expect(audio.get("music_intensity") == &"tension", "An active hunt raises tension")
	audio.call("set_music_for_guardian", true, true)
	_expect(audio.get("music_intensity") == &"chase", "An active chase raises the chase layer")
	await process_frame


func _check_ducking(audio: Node) -> void:
	audio.call("set_music_intensity", &"calm", true)
	var before := (audio.get("_music_players")["bed"] as AudioStreamPlayer).volume_db
	audio.call("duck_music", 0.05)
	audio.call("_apply_layer_gains")
	var ducked := (audio.get("_music_players")["bed"] as AudioStreamPlayer).volume_db
	_expect(ducked < before, "Ducking pulls the music down for a stinger")
	for _step: int in range(240):
		audio.call("_advance_duck", 1.0 / 60.0)
	var recovered := (audio.get("_music_players")["bed"] as AudioStreamPlayer).volume_db
	_expect(is_equal_approx(recovered, before), "Music returns to level after the stinger")
	await process_frame


func _check_volumes(audio: Node) -> void:
	var original := float(audio.call("get_bus_volume_linear", &"Music"))
	audio.call("set_bus_volume_linear", &"Music", 0.5)
	_expect(
		absf(float(audio.call("get_bus_volume_linear", &"Music")) - 0.5) < 0.01,
		"Bus volume round-trips through linear gain"
	)
	audio.call("set_bus_volume_linear", &"Music", 0.0)
	_expect(
		float(audio.call("get_bus_volume_linear", &"Music")) <= 0.001,
		"Zero volume reads back as silence rather than a tiny gain"
	)
	audio.call("set_bus_volume_linear", &"Music", original)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("audio_contract_test: PASS")
		quit(0)
		return
	printerr("audio_contract_test: FAIL (%d assertion(s))" % failures.size())
	quit(1)
