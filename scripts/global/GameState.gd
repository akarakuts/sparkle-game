extends Node

## GameState — autoload: crystal shards, world locks, stickers, audio settings, play time.

signal shard_collected(world_id: int, shard_index: int)
signal world_completed(world_id: int)
signal game_reset()
signal sticker_collected(sticker_id: String)

var current_world: int = 0
var current_save_slot: int = 0

var collected_shards: Array = [false, false, false, false, false, false, false]
var collected_stickers: Array = []

var world_states: Dictionary = {
	0: "open",
	1: "locked",
	2: "locked",
	3: "locked",
	4: "locked",
	5: "locked",
	6: "locked"
}

var settings: Dictionary = {
	"sound": true,
	"music": true,
	"lang": "ru",
	"sound_volume": 80.0,
	"music_volume": 60.0
}

var play_time: float = 0.0

## Финал «Кристалл Дружбы восстановлён» уже показан (чтобы не повторять).
var crystal_finale_shown: bool = false

const TOTAL_WORLDS: int = 7


func _ready() -> void:
	apply_audio_settings()


## Все осколки собраны — кристалл восстановлен.
func is_crystal_complete() -> bool:
	return get_shard_count() >= TOTAL_WORLDS


func _process(delta: float) -> void:
	play_time += delta


func reset_game() -> void:
	current_world = 0
	for i in range(collected_shards.size()):
		collected_shards[i] = false
	world_states = {
		0: "open",
		1: "locked",
		2: "locked",
		3: "locked",
		4: "locked",
		5: "locked",
		6: "locked"
	}
	settings = {
		"sound": true,
		"music": true,
		"lang": "ru",
		"sound_volume": 80.0,
		"music_volume": 60.0
	}
	play_time = 0.0
	crystal_finale_shown = false
	collected_stickers.clear()
	MiniGameManager.reset_progress()
	game_reset.emit()
	apply_audio_settings()


func collect_shard(world_id: int) -> bool:
	if world_id < 0 or world_id >= collected_shards.size():
		return false
	if collected_shards[world_id]:
		return false
	collected_shards[world_id] = true
	shard_collected.emit(world_id, world_id)
	return true


func is_world_unlocked(world_id: int) -> bool:
	if not world_states.has(world_id):
		return false
	return world_states[world_id] in ["open", "completed"]


func complete_world(world_id: int) -> void:
	if not world_states.has(world_id):
		return
	world_states[world_id] = "completed"
	var next_world: int = world_id + 1
	if world_states.has(next_world) and world_states[next_world] == "locked":
		world_states[next_world] = "open"
	world_completed.emit(world_id)


func get_shard_count() -> int:
	var count: int = 0
	for collected in collected_shards:
		if collected:
			count += 1
	return count


func collect_sticker(world_id: int, game_id: int) -> bool:
	var sticker_id: String = str(world_id) + "_" + str(game_id)
	if sticker_id in collected_stickers:
		return false
	collected_stickers.append(sticker_id)
	sticker_collected.emit(sticker_id)
	return true


func has_sticker(world_id: int, game_id: int) -> bool:
	return str(world_id) + "_" + str(game_id) in collected_stickers


func get_sticker_count() -> int:
	return collected_stickers.size()


func apply_audio_settings() -> void:
	var sound_on: bool = settings.get("sound", true)
	var music_on: bool = settings.get("music", true)
	var sound_vol: float = float(settings.get("sound_volume", 80.0)) / 100.0
	var music_vol: float = float(settings.get("music_volume", 60.0)) / 100.0
	AudioManager.set_sound_vol(sound_vol if sound_on else 0.0)
	AudioManager.set_music_vol(music_vol if music_on else 0.0)
	if not music_on:
		AudioManager.stop_music()
