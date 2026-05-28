extends Node

## AudioManager — autoload: per-world music loop + SFX; respects GameState volume toggles.

const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_DIR: String = "res://assets/audio/sfx/"

var _music_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_volume: float = 0.8
var _sound_volume: float = 1.0
var _music_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}
const SFX_PLAYER_COUNT: int = 8


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)

	for i in range(SFX_PLAYER_COUNT):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer_" + str(i)
		sfx_player.bus = "Master"
		add_child(sfx_player)
		_sfx_players.append(sfx_player)


func play_music(world_id: int) -> void:
	if not GameState.settings.get("music", true):
		return

	var music_path: String = MUSIC_DIR + "music_" + str(world_id) + ".ogg"
	var stream: AudioStream = _load_audio(music_path, _music_cache)
	if stream == null:
		push_warning("AudioManager: музыка для мира " + str(world_id) + " не найдена")
		return

	if _music_player.stream == stream and _music_player.playing:
		return

	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(_music_volume)
	_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func play_sfx(sfx_name: String) -> void:
	if not GameState.settings.get("sound", true):
		return

	var sfx_path: String = SFX_DIR + sfx_name + ".ogg"
	var stream: AudioStream = _load_audio(sfx_path, _sfx_cache)
	if stream == null:
		push_warning("AudioManager: SFX '" + sfx_name + "' не найден")
		return

	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(_sound_volume)
			player.play()
			return

	_sfx_players[0].stop()
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = linear_to_db(_sound_volume)
	_sfx_players[0].play()


func set_sound_vol(v: float) -> void:
	_sound_volume = clampf(v, 0.0, 1.0)
	for player in _sfx_players:
		player.volume_db = linear_to_db(_sound_volume)


func set_music_vol(v: float) -> void:
	_music_volume = clampf(v, 0.0, 1.0)
	if _music_player != null:
		_music_player.volume_db = linear_to_db(_music_volume)


func stop_all() -> void:
	stop_music()
	for player in _sfx_players:
		player.stop()


func release_test_resources() -> void:
	stop_all()
	if _music_player != null:
		_music_player.stream = null
		_music_player.free()
		_music_player = null
	for player in _sfx_players:
		player.stop()
		player.stream = null
		player.free()
	_sfx_players.clear()
	_music_cache.clear()
	_sfx_cache.clear()


func _load_audio(path: String, cache: Dictionary) -> AudioStream:
	if cache.has(path):
		return cache[path] as AudioStream

	# В проекте могут остаться только .import без исходного .ogg.
	# Тогда ResourceLoader.exists() иногда возвращает true, но load() падает с ошибкой.
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		var import_config := ConfigFile.new()
		if import_config.load(import_path) == OK:
			var is_valid := bool(import_config.get_value("remap", "valid", true))
			if not is_valid:
				return null

	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	if not ResourceLoader.exists(path):
		return null

	var stream: AudioStream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
	if stream != null:
		cache[path] = stream
	return stream
