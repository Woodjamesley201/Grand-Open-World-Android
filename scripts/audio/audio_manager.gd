## AudioManager - all sound effects and music are procedurally synthesized
## (original audio, no licensing issues). HD audio from the downloaded asset
## pack replaces the generated music when present.
class_name AudioManager
extends Node

var streams: Dictionary = {}
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var _music_built: bool = false
var _hd_music: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_streams()
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Master"
	ambience_player.stream = streams["ambience"]
	add_child(ambience_player)
	rain_player = AudioStreamPlayer.new()
	rain_player.stream = streams["rain"]
	rain_player.volume_db = -6.0
	add_child(rain_player)
	AudioServer.set_bus_volume_db(0, linear_to_db(float(GameState.settings.get("volume_master", 1.0))))
	# look for HD audio from the asset pack
	_scan_hd_music()

func _scan_hd_music() -> void:
	var am := AssetManager.new()
	add_child(am)
	for name in am.list_hd_audio():
		var s := am.get_hd_audio(name)
		if s != null:
			_hd_music.append(s)

func _build_streams() -> void:
	var sr := 22050
	streams["click"] = _wav(_synth_click(sr), sr)
	streams["footstep"] = _wav(_synth_noise_burst(sr, 0.09, 0.35, 900.0), sr)
	streams["gunshot"] = _wav(_synth_gunshot(sr), sr)
	streams["explosion"] = _wav(_synth_explosion(sr), sr)
	streams["thunder"] = _wav(_synth_thunder(sr), sr)
	streams["horn"] = _wav(_synth_horn(sr), sr, true)
	streams["siren"] = _wav(_synth_siren(sr), sr, true)
	streams["engine"] = _wav(_synth_engine(sr), sr, true)
	streams["ambience"] = _wav(_synth_ambience(sr), sr, true)
	streams["rain"] = _wav(_synth_rain(sr), sr, true)
	streams["checkpoint"] = _wav(_synth_blip(sr, 880.0), sr)
	streams["mission"] = _wav(_synth_mission(sr), sr)

func get_stream(name: String) -> AudioStream:
	return streams.get(name)

# ---------------------------------------------------------------- playback

func play_2d(name: String, vol_db: float = 0.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_3d(name: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.max_distance = 120.0
	p.unit_size = 8.0
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func start_ambience() -> void:
	if not ambience_player.playing:
		ambience_player.play()

func set_rain(on: bool) -> void:
	if on and not rain_player.playing:
		rain_player.play()
	elif not on and rain_player.playing:
		rain_player.stop()

func play_music(index: int) -> void:
	if _hd_music.size() > 0:
		music_player.stream = _hd_music[index % _hd_music.size()]
		music_player.volume_db = -8.0
		music_player.play()
		return
	if not _music_built:
		_build_music()
	if streams.has("music_" + str(index % 3)):
		music_player.stream = streams["music_" + str(index % 3)]
		music_player.volume_db = -10.0
		music_player.play()

func next_track() -> void:
	play_music(int(Time.get_ticks_msec() / 1000.0 / 180.0) % 3)

# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array, mix_rate: int, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size() - 1
	return wav

func _synth_click(sr: int) -> PackedFloat32Array:
	var n := int(sr * 0.06)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / float(sr)
		out[i] = sin(TAU * 880.0 * t) * (1.0 - float(i) / float(n)) * 0.5
	return out

func _synth_blip(sr: int, freq: float) -> PackedFloat32Array:
	var n := int(sr * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / float(sr)
		out[i] = sin(TAU * freq * t) * (1.0 - float(i) / float(n)) * 0.5
	return out

func _synth_noise_burst(sr: int, dur: float, amp: float, cutoff_hz: float) -> PackedFloat32Array:
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var last := 0.0
	var a := cutoff_hz / sr * TAU
	for i in range(n):
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		var env := 1.0 - float(i) / float(n)
		out[i] = last * env * amp
	return out

func _synth_gunshot(sr: int) -> PackedFloat32Array:
	var dur := 0.28
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 34
	var last := 0.0
	var a := 2500.0 / float(sr) * TAU
	for i in range(n):
		var t := float(i) / float(sr)
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		var env := exp(-t * 22.0)
		var thump := sin(TAU * 95.0 * t) * exp(-t * 30.0) * 0.8
		out[i] = last * env * 0.9 + thump
	return out

func _synth_explosion(sr: int) -> PackedFloat32Array:
	var dur := 1.4
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 56
	var last := 0.0
	var a := 700.0 / float(sr) * TAU
	for i in range(n):
		var t := float(i) / float(sr)
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		var env := exp(-t * 2.2)
		var boom := sin(TAU * 48.0 * t) * exp(-t * 3.5) * 0.9
		out[i] = last * env * 1.1 + boom
	return out

func _synth_thunder(sr: int) -> PackedFloat32Array:
	var dur := 2.6
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	var last := 0.0
	var a := 300.0 / float(sr) * TAU
	for i in range(n):
		var t := float(i) / float(sr)
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		var env := (1.0 - exp(-t * 25.0)) * exp(-t * 1.2)
		out[i] = last * env
	return out

func _synth_horn(sr: int) -> PackedFloat32Array:
	var dur := 0.45
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / float(sr)
		var env := minf(t * 40.0, 1.0) * (1.0 - smoothstep(0.35, dur, t))
		out[i] = (signf(sin(TAU * 336.0 * t)) * 0.3 + signf(sin(TAU * 424.0 * t)) * 0.3) * env
	return out

func _synth_siren(sr: int) -> PackedFloat32Array:
	var dur := 1.6
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / float(sr)
		var freq := 760.0 if fmod(t, 0.8) < 0.4 else 950.0
		out[i] = sin(TAU * freq * t) * 0.35
	return out

func _synth_engine(sr: int) -> PackedFloat32Array:
	var dur := 1.0
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var base := 52.0
	for i in range(n):
		var t := fmod(float(i) / float(sr), dur)
		var saw := 2.0 * fmod(t * base, 1.0) - 1.0
		var h2 := 2.0 * fmod(t * base * 2.0, 1.0) - 1.0
		var h3 := 2.0 * fmod(t * base * 3.0, 1.0) - 1.0
		var noise := rng.randf() * 2.0 - 1.0
		out[i] = saw * 0.4 + h2 * 0.2 + h3 * 0.1 + noise * 0.08
	return out

func _synth_ambience(sr: int) -> PackedFloat32Array:
	var dur := 4.0
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var last := 0.0
	var a := 220.0 / float(sr) * TAU
	for i in range(n):
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		var t := fmod(float(i) / float(sr), dur)
		var hum := sin(TAU * 118.0 * t) * 0.04
		out[i] = last * 0.5 + hum
	return out

func _synth_rain(sr: int) -> PackedFloat32Array:
	var dur := 3.0
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var last := 0.0
	var a := 1600.0 / float(sr) * TAU
	for i in range(n):
		var white := rng.randf() * 2.0 - 1.0
		last = last + a * (white - last)
		out[i] = last * 0.45
	return out

func _synth_mission(sr: int) -> PackedFloat32Array:
	var dur := 1.2
	var n := int(sr * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in range(notes.size()):
		var start := int(float(k) * 0.22 * sr)
		var length := int(sr * 0.35)
		for i in range(length):
			var idx := start + i
			if idx >= n:
				break
			var t := float(i) / float(sr)
			out[idx] += sin(TAU * float(notes[k]) * t) * (1.0 - t / 0.35) * 0.35
	return out

# ---------------------------------------------------------------- music

func _build_music() -> void:
	_music_built = true
	var sr := 22050
	streams["music_0"] = _wav(_synth_music(sr, 1, [57, 60, 64, 67], 96.0, 24.0), sr, true)
	streams["music_1"] = _wav(_synth_music(sr, 2, [53, 57, 60, 65], 88.0, 24.0), sr, true)
	streams["music_2"] = _wav(_synth_music(sr, 3, [48, 52, 55, 59], 104.0, 24.0), sr, true)

func _synth_music(sr: int, seed: int, root_chord: Array, bpm: float, seconds: float) -> PackedFloat32Array:
	var n := int(sr * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var beat := 60.0 / bpm
	var beats := int(seconds / beat)
	var chords := [
		[root_chord[0], root_chord[0] + 3, root_chord[0] + 7],
		[root_chord[0] - 4, root_chord[0], root_chord[0] + 3],
		[root_chord[0] - 9, root_chord[0] - 5, root_chord[0] - 2],
		[root_chord[0] - 7, root_chord[0] - 3, root_chord[0]],
	]
	var penta := [root_chord[0] + 12, root_chord[0] + 15, root_chord[0] + 17, root_chord[0] + 19, root_chord[0] + 22, root_chord[0] + 24]
	var midi_to_hz := func(m: float) -> float: return 440.0 * pow(2.0, (m - 69.0) / 12.0)
	for b in range(beats):
		var start := int(float(b) * beat * sr)
		var chord: Array = chords[b / 4 % chords.size()]
		# pad (soft chord)
		for m in chord:
			_add_tone(out, start, int(sr * beat * 1.05), midi_to_hz.call(float(m)) * 0.5, 0.05, sr)
		# bass on every other beat
		if b % 2 == 0:
			_add_tone(out, start, int(sr * beat * 0.9), midi_to_hz.call(float(chord[0]) - 12.0), 0.16, sr, 2.0)
		# melody
		if rng.randf() < 0.6:
			var note := penta[rng.randi() % penta.size()]
			_add_tone(out, start, int(sr * beat * 0.8), midi_to_hz.call(float(note)), 0.1, sr, 4.0)
		# hat
		_add_noise_tick(out, start, int(sr * 0.03), 0.05, rng)
	return out

func _add_tone(out: PackedFloat32Array, start: int, length: int, freq: float, amp: float, sr: int, attack: float = 1.5) -> void:
	for i in range(length):
		var idx := start + i
		if idx >= out.size():
			break
		var t := float(i) / float(sr)
		var env := minf(t * attack * 8.0, 1.0) * exp(-t * 2.0)
		out[idx] += sin(TAU * freq * t) * amp * env

func _add_noise_tick(out: PackedFloat32Array, start: int, length: int, amp: float, rng: RandomNumberGenerator) -> void:
	for i in range(length):
		var idx := start + i
		if idx >= out.size():
			break
		var env := 1.0 - float(i) / float(length)
		out[idx] += (rng.randf() * 2.0 - 1.0) * amp * env
