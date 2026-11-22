extends Node

const SFX_PATHS := {
	"water": "res://assets/audio/state_water.wav",
	"ice": "res://assets/audio/state_ice.wav",
	"steam": "res://assets/audio/state_steam.wav",
	"glass_shatter": "res://assets/audio/glass_shatter.wav",
	"collect_star": "res://assets/audio/collect_star.wav",
	"fan_toggle": "res://assets/audio/fan_toggle.wav",
	"condense": "res://assets/audio/condense.wav",
	"seedling_bloom": "res://assets/audio/seedling_bloom.wav",
	"seedling_shiver": "res://assets/audio/seedling_shiver.wav",
	"fail_drain": "res://assets/audio/fail_drain.wav",
	"ui_tap": "res://assets/audio/ui_tap.wav",
	"sponge_soak": "res://assets/audio/sponge_soak.wav",
	"sponge_squeeze": "res://assets/audio/sponge_squeeze.wav",
	"hotplate_sizzle": "res://assets/audio/hotplate_sizzle.wav",
	"star_fanfare": "res://assets/audio/star_fanfare.wav",
}

const BGM_PATH := "res://assets/audio/ambient_greenhouse.wav"

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX_PATHS.keys():
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)
	if ResourceLoader.exists(BGM_PATH):
		var bgm: AudioStream = load(BGM_PATH)
		if bgm is AudioStreamWAV:
			(bgm as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(bgm as AudioStreamWAV).loop_end = int(8.0 * 22050)
		_bgm_player.stream = bgm
		if SaveManager.is_music_enabled():
			_bgm_player.play()


func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = -3.0) -> void:
	if not SaveManager.is_sfx_enabled():
		return
	if not _streams.has(sfx_name):
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = _streams[sfx_name]
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func toggle_music() -> bool:
	var next_state := not SaveManager.is_music_enabled()
	SaveManager.set_music_enabled(next_state)
	if next_state:
		if _bgm_player.stream != null and not _bgm_player.playing:
			_bgm_player.play()
	else:
		_bgm_player.stop()
	return next_state


func toggle_sfx() -> bool:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	return next_state
