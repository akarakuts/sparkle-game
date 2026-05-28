extends Node

## SaveManager — autoload: JSON slots in user://, schema version + migration, boot load.

const SAVE_DIR: String = "user://"
const SAVE_PREFIX: String = "save_"
const SAVE_EXT: String = ".json"
const SAVE_VERSION: int = 2
const TOTAL_WORLDS: int = 7

var _game_state: GameState = null


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_error("SaveManager: GameState не найден!")
		return
	if not _game_state.world_completed.is_connected(_on_world_completed):
		_game_state.world_completed.connect(_on_world_completed)
	if not _game_state.game_reset.is_connected(_on_game_reset):
		_game_state.game_reset.connect(_on_game_reset)
	call_deferred("_boot_load")


func _boot_load() -> void:
	if _game_state == null:
		return
	if has_save(_game_state.current_save_slot):
		load_game(_game_state.current_save_slot)
	else:
		_game_state.apply_audio_settings()


## Выбор слота: загрузить существующий или создать новую игру в пустом слоте.
func select_slot(slot: int) -> bool:
	if _game_state == null:
		return false
	if has_save(slot):
		return load_game(slot)
	# Пустой слот — стартуем новую игру именно в этом слоте (а не наследуем RAM-прогресс).
	_game_state.current_save_slot = slot
	_game_state.reset_game() # внутри emit game_reset -> _on_game_reset -> save_game(slot)
	return true


func save_game(slot: int = 0) -> bool:
	if _game_state == null:
		return false

	var save_data: Dictionary = {
		"current_world": _game_state.current_world,
		"current_save_slot": slot,
		"collected_shards": _game_state.collected_shards.duplicate(),
		"world_states": _game_state.world_states.duplicate(),
		"settings": _game_state.settings.duplicate(),
		"play_time": _game_state.play_time,
		"collected_stickers": _game_state.collected_stickers.duplicate(),
		"crystal_finale_shown": _game_state.crystal_finale_shown,
		"minigame_progress": MiniGameManager.get_save_data(),
		"save_version": SAVE_VERSION
	}

	var file_path: String = SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: не удалось записать " + file_path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_game_state.current_save_slot = slot
	return true


func load_game(slot: int = 0) -> bool:
	if _game_state == null:
		return false

	var file_path: String = SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT
	if not FileAccess.file_exists(file_path):
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return false
	file.close()

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: повреждённый сейв (не объект), слот %d" % slot)
		return false
	var save_data: Dictionary = json.data
	if save_data.is_empty():
		return false

	# Версионирование: будущие (неизвестные) форматы не загружаем, чтобы не испортить прогресс.
	var version: int = int(save_data.get("save_version", 1))
	if version > SAVE_VERSION:
		push_warning("SaveManager: сейв новее поддерживаемого (v%d > v%d), пропуск" % [version, SAVE_VERSION])
		return false
	if version < SAVE_VERSION:
		save_data = _migrate_save(save_data, version)

	# Собираем и валидируем во временные переменные — применяем только при полной готовности (атомарно).
	var current_world: int = int(save_data.get("current_world", 0))
	var shards: Array = _normalize_shards(save_data.get("collected_shards", []))
	var states: Dictionary = _normalize_world_states(save_data.get("world_states", {}))
	var settings: Dictionary = _game_state.settings.duplicate()
	if typeof(save_data.get("settings")) == TYPE_DICTIONARY:
		for k in (save_data["settings"] as Dictionary).keys():
			settings[k] = save_data["settings"][k]
	var play_time: float = float(save_data.get("play_time", 0.0))
	var stickers: Array = _normalize_stickers(save_data.get("collected_stickers", []))
	var minigame_progress: Dictionary = {}
	if typeof(save_data.get("minigame_progress")) == TYPE_DICTIONARY:
		minigame_progress = save_data["minigame_progress"]

	# Применение.
	_game_state.current_world = clampi(current_world, 0, TOTAL_WORLDS - 1)
	_game_state.current_save_slot = slot
	_game_state.collected_shards = shards
	_game_state.world_states = states
	_game_state.settings = settings
	_game_state.play_time = maxf(play_time, 0.0)
	_game_state.collected_stickers = stickers
	_game_state.crystal_finale_shown = bool(save_data.get("crystal_finale_shown", false))
	MiniGameManager.load_save_data(minigame_progress)
	_game_state.apply_audio_settings()
	return true


func delete_save(slot: int) -> void:
	var file_path: String = SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT)


func _on_world_completed(_world_id: int) -> void:
	save_game(_game_state.current_save_slot)


func _on_game_reset() -> void:
	save_game(_game_state.current_save_slot)


func _default_world_states() -> Dictionary:
	var states: Dictionary = {}
	for i in range(TOTAL_WORLDS):
		states[i] = "open" if i == 0 else "locked"
	return states


func _normalize_world_states(raw_value) -> Dictionary:
	var states: Dictionary = _default_world_states()
	if typeof(raw_value) != TYPE_DICTIONARY:
		return states
	var raw: Dictionary = raw_value
	for key in raw.keys():
		var wid: int = int(key)
		if wid < 0 or wid >= TOTAL_WORLDS:
			continue
		var value: String = str(raw[key])
		if value in ["open", "locked", "completed"]:
			states[wid] = value
	# Мир 0 всегда доступен.
	if states.get(0, "locked") == "locked":
		states[0] = "open"
	return states


func _normalize_shards(raw_value) -> Array:
	var shards: Array = []
	for i in range(TOTAL_WORLDS):
		shards.append(false)
	if typeof(raw_value) != TYPE_ARRAY:
		return shards
	var raw: Array = raw_value
	for i in range(mini(raw.size(), TOTAL_WORLDS)):
		shards[i] = bool(raw[i])
	return shards


func _normalize_stickers(raw_value) -> Array:
	var stickers: Array = []
	if typeof(raw_value) != TYPE_ARRAY:
		return stickers
	for item in raw_value:
		var sid: String = str(item)
		if sid != "" and not stickers.has(sid):
			stickers.append(sid)
	return stickers


## Цепочка миграций старых сейвов до актуального формата.
func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	# v1 -> v2: гарантируем наличие полей наклеек и нормализованных осколков.
	if from_version < 2:
		if not migrated.has("collected_stickers"):
			migrated["collected_stickers"] = []
		migrated["collected_shards"] = _normalize_shards(migrated.get("collected_shards", []))
	migrated["save_version"] = SAVE_VERSION
	return migrated
