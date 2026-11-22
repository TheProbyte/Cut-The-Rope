extends Node
## Global audio: pooled one-shot SFX voices plus two crossfading music players.
##
## Public API:
##   play_sfx(sfx_name, pitch_scale = 1.0, volume_db = -3.0, vary = false)
##   play_music(track)            # "menu", "greenhouse", "kitchen" (0.8 s crossfade)
##   duck_music(amount_db = -8.0, duration = 0.6)
##   toggle_music() -> bool, toggle_sfx() -> bool
##   get_current_track() -> String, has_sfx(sfx_name) -> bool
## Everything keeps working while the scene tree is paused.

const SFX_PATHS := {
	# Droplet states / world elements
	"water": "res://assets/audio/state_water.wav",
	"ice": "res://assets/audio/state_ice.wav",
	"steam": "res://assets/audio/state_steam.wav",
	"glass_shatter": "res://assets/audio/glass_shatter.wav",
	"collect_star": "res://assets/audio/collect_star.wav",
	"fan_toggle": "res://assets/audio/fan_toggle.wav",
	"condense": "res://assets/audio/condense.wav",
	"evaporate": "res://assets/audio/evaporate.wav",
	"sponge_soak": "res://assets/audio/sponge_soak.wav",
	"sponge_squeeze": "res://assets/audio/sponge_squeeze.wav",
	"hotplate_sizzle": "res://assets/audio/hotplate_sizzle.wav",
	# Seedling / outcome
	"level_start": "res://assets/audio/level_start.wav",
	"seedling_bloom": "res://assets/audio/seedling_bloom.wav",
	"seedling_shiver": "res://assets/audio/seedling_shiver.wav",
	"win_jingle": "res://assets/audio/win_jingle.wav",
	"fail_drain": "res://assets/audio/fail_drain.wav",
	"fail_splat": "res://assets/audio/fail_splat.wav",
	"star_fanfare": "res://assets/audio/star_fanfare.wav",
	"star_whoosh": "res://assets/audio/star_whoosh.wav",
	"unlock": "res://assets/audio/unlock.wav",
	# UI
	"ui_tap": "res://assets/audio/ui_tap.wav",
	"ui_back": "res://assets/audio/ui_back.wav",
	"ui_open": "res://assets/audio/ui_open.wav",
	"ui_whoosh": "res://assets/audio/ui_whoosh.wav",
}

const MUSIC_PATHS := {
	"menu": "res://assets/audio/music_menu.wav",
	"greenhouse": "res://assets/audio/music_greenhouse.wav",
	"kitchen": "res://assets/audio/music_kitchen.wav",
}

const SFX_VOICES := 10
const MUSIC_VOLUME_DB := -11.0
const CROSSFADE_TIME := 0.8
const DUCK_IN_TIME := 0.15
const DUCK_OUT_TIME := 0.7
const PITCH_VARIATION := 0.03
const SILENT_LINEAR := 0.0001

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _music_players: Array[AudioStreamPlayer] = []
var _music_fade: Array[float] = [0.0, 0.0]
var _music_tweens: Array = [null, null]
var _music_tracks: Array[String] = ["", ""]
var _active_music: int = 0
var _current_track: String = ""
var _requested_track: String = "menu"
var _duck_db: float = 0.0
var _duck_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for key in SFX_PATHS.keys():
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)

	for i in range(2):
		var music_player := AudioStreamPlayer.new()
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(music_player)
		_music_players.append(music_player)
	_apply_music_volume()

	# Start the menu loop by default; scenes switch tracks with play_music().
	if SaveManager.is_music_enabled():
		_start_track(_requested_track)


# --- SFX ----------------------------------------------------------------------

func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = -3.0, vary: bool = false) -> void:
	if not SaveManager.is_sfx_enabled():
		return
	if not _streams.has(sfx_name):
		return
	var player := _next_sfx_player()
	var pitch := pitch_scale
	if vary:
		pitch *= _rng.randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	player.stream = _streams[sfx_name]
	player.pitch_scale = maxf(pitch, 0.01)
	player.volume_db = volume_db
	player.play()


func has_sfx(sfx_name: String) -> bool:
	return _streams.has(sfx_name)


func _next_sfx_player() -> AudioStreamPlayer:
	# Prefer an idle voice; otherwise steal the oldest one (round-robin).
	var count := _sfx_players.size()
	for offset in range(count):
		var idx := (_sfx_index + offset) % count
		if not _sfx_players[idx].playing:
			_sfx_index = (idx + 1) % count
			return _sfx_players[idx]
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % count
	return player


# --- Music --------------------------------------------------------------------

func play_music(track: String) -> void:
	if not MUSIC_PATHS.has(track):
		push_warning("AudioManager: unknown music track '%s'" % track)
		return
	_requested_track = track
	if not SaveManager.is_music_enabled():
		return
	if track == _current_track and _music_players[_active_music].playing:
		return
	_start_track(track)


func get_current_track() -> String:
	return _current_track


func duck_music(amount_db: float = -8.0, duration: float = 0.6) -> void:
	## Dips the music by amount_db (fast), holds it for `duration` seconds,
	## then smoothly restores it.
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = _make_tween()
	_duck_tween.tween_method(_set_duck_db, _duck_db, minf(amount_db, 0.0), DUCK_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_duck_tween.tween_interval(maxf(duration, 0.0))
	_duck_tween.tween_method(_set_duck_db, minf(amount_db, 0.0), 0.0, DUCK_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func toggle_music() -> bool:
	var next_state := not SaveManager.is_music_enabled()
	SaveManager.set_music_enabled(next_state)
	if next_state:
		_start_track(_requested_track)
	else:
		_stop_all_music()
	return next_state


func toggle_sfx() -> bool:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	if not next_state:
		for player in _sfx_players:
			player.stop()
	return next_state


func _start_track(track: String) -> void:
	var stream := _get_music_stream(track)
	if stream == null:
		return
	var incoming := 1 - _active_music
	var outgoing := _active_music
	var incoming_player := _music_players[incoming]
	# Switching back to a track that is still fading out: fade it back in
	# from where it is instead of restarting it.
	var resume := incoming_player.playing and _music_tracks[incoming] == track
	if not resume:
		if _music_players[outgoing].playing and _music_tracks[outgoing] == track:
			# Already the active player (e.g. re-enabled mid fade-out): keep it.
			incoming = outgoing
			outgoing = 1 - incoming
			incoming_player = _music_players[incoming]
			resume = true
	if not resume:
		incoming_player.stop()
		incoming_player.stream = stream
		_music_tracks[incoming] = track
		_set_fade(incoming, 0.0)
		incoming_player.play()
	_active_music = incoming
	_current_track = track
	_fade_player(incoming, 1.0, CROSSFADE_TIME)
	if _music_players[outgoing].playing:
		_fade_player(outgoing, 0.0, CROSSFADE_TIME)


func _stop_all_music() -> void:
	for i in range(_music_players.size()):
		_kill_music_tween(i)
		_music_players[i].stop()
		_music_tracks[i] = ""
		_set_fade(i, 0.0)
	_current_track = ""


func _fade_player(idx: int, target: float, time: float) -> void:
	_kill_music_tween(idx)
	var tween := _make_tween()
	tween.tween_method(_set_fade_value.bind(idx), _music_fade[idx], target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if target <= 0.0:
		tween.tween_callback(_on_fade_out_finished.bind(idx))
	_music_tweens[idx] = tween


func _on_fade_out_finished(idx: int) -> void:
	_music_players[idx].stop()
	_music_tracks[idx] = ""
	_music_tweens[idx] = null


func _kill_music_tween(idx: int) -> void:
	var tween: Tween = _music_tweens[idx]
	if tween != null and tween.is_valid():
		tween.kill()
	_music_tweens[idx] = null


func _make_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _set_fade(idx: int, value: float) -> void:
	_music_fade[idx] = clampf(value, 0.0, 1.0)
	_apply_music_volume()


func _set_fade_value(value: float, idx: int) -> void:
	_set_fade(idx, value)


func _set_duck_db(value: float) -> void:
	_duck_db = value
	_apply_music_volume()


func _apply_music_volume() -> void:
	for i in range(_music_players.size()):
		var fade := maxf(_music_fade[i], SILENT_LINEAR)
		_music_players[i].volume_db = MUSIC_VOLUME_DB + _duck_db + linear_to_db(fade)


func _get_music_stream(track: String) -> AudioStream:
	if _music_streams.has(track):
		return _music_streams[track]
	if not MUSIC_PATHS.has(track):
		return null
	var path: String = MUSIC_PATHS[track]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_ensure_loop(stream)
	_music_streams[track] = stream
	return stream


func _ensure_loop(stream: AudioStream) -> void:
	# The .import files already request a forward loop over the whole sample;
	# this is a safety net in case an import lost those settings.
	if not (stream is AudioStreamWAV):
		return
	var wav := stream as AudioStreamWAV
	if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED and wav.loop_end > wav.loop_begin:
		return
	var frames := _wav_frame_count(wav)
	if frames <= 0:
		return
	wav.loop_begin = 0
	wav.loop_end = frames
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


@warning_ignore("integer_division")
func _wav_frame_count(wav: AudioStreamWAV) -> int:
	var channels := 2 if wav.stereo else 1
	var bytes := wav.data.size()
	match wav.format:
		AudioStreamWAV.FORMAT_16_BITS:
			return bytes / (2 * channels)
		AudioStreamWAV.FORMAT_8_BITS:
			return bytes / channels
		_:
			return int(round(wav.get_length() * float(wav.mix_rate)))
