extends Node

## MiniGameManager — autoload: per-world mini-game list, completion flags, difficulty metadata.

var _minigame_data: Dictionary = {}


func _ready() -> void:
	_init_default_games()
	if not GameState.game_reset.is_connected(_on_game_reset):
		GameState.game_reset.connect(_on_game_reset)


func _init_default_games() -> void:
	# Набор мира 0 одинаков в debug и release (4 слота кнопок в GlowForest).
	_minigame_data[0] = [
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 1, "completed": false},
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 1, "completed": false},
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 1, "completed": false},
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 1, "completed": false}
	]
	_minigame_data[1] = [
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 2, "completed": false},
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 2, "completed": false},
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 2, "completed": false},
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 1, "completed": false}
	]
	_minigame_data[2] = [
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 2, "completed": false},
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 3, "completed": false},
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 2, "completed": false},
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 1, "completed": false}
	]
	_minigame_data[3] = [
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 1, "completed": false},
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 2, "completed": false},
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 2, "completed": false}
	]
	_minigame_data[4] = [
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 3, "completed": false},
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 3, "completed": false},
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 3, "completed": false},
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 2, "completed": false},
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 4, "completed": false}
	]
	_minigame_data[5] = [
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 4, "completed": false},
		{"name": "Память", "scene_path": "res://scenes/minigames/Memory.tscn", "difficulty": 4, "completed": false},
		{"name": "Последовательность", "scene_path": "res://scenes/minigames/Sequencing.tscn", "difficulty": 4, "completed": false},
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 3, "completed": false},
		{"name": "Сортировка", "scene_path": "res://scenes/minigames/Puzzle.tscn", "difficulty": 5, "completed": false}
	]
	_minigame_data[6] = [
		{"name": "Рисование", "scene_path": "res://scenes/minigames/Drawing.tscn", "difficulty": 1, "completed": false}
	]


func reset_progress() -> void:
	for world_id in _minigame_data.keys():
		for game in _minigame_data[world_id]:
			game["completed"] = false


func get_world_games(world_id: int) -> Array:
	if _minigame_data.has(world_id):
		return _minigame_data[world_id].duplicate(true)
	return []


## Возвращает индекс слота; сверяет scene_path, при дублях — первый непройденный слот.
func resolve_game_id(world_id: int, game_id: int, scene_path: String = "") -> int:
	if not _minigame_data.has(world_id):
		return game_id
	var games: Array = _minigame_data[world_id]
	if game_id >= 0 and game_id < games.size():
		var expected: String = str(games[game_id].get("scene_path", ""))
		if scene_path == "" or expected == scene_path:
			return game_id
	if scene_path == "":
		return game_id

	var matching: Array[int] = []
	for i in range(games.size()):
		if str(games[i].get("scene_path", "")) == scene_path:
			matching.append(i)
	if matching.is_empty():
		push_warning(
			"MiniGameManager: нет слота world=%d path=%s (game_id=%d)"
			% [world_id, scene_path, game_id]
		)
		return game_id
	if matching.size() == 1:
		return matching[0]
	for i in matching:
		if not games[i].get("completed", false):
			return i
	return matching[matching.size() - 1]


func count_button_slots(world_id: int) -> int:
	if not _minigame_data.has(world_id):
		return 0
	return _minigame_data[world_id].size()


func complete_minigame(world_id: int, game_id: int, scene_path: String = "") -> void:
	if not _minigame_data.has(world_id):
		return
	game_id = resolve_game_id(world_id, game_id, scene_path)
	var games: Array = _minigame_data[world_id]
	if game_id < 0 or game_id >= games.size():
		return
	games[game_id]["completed"] = true


func is_world_ready(world_id: int) -> bool:
	if not _minigame_data.has(world_id):
		return false
	for game in _minigame_data[world_id]:
		if not game["completed"]:
			return false
	return true


func get_next_unfinished_game(world_id: int) -> Dictionary:
	if not _minigame_data.has(world_id):
		return {}
	var games: Array = _minigame_data[world_id]
	for i in range(games.size()):
		if not games[i]["completed"]:
			var result: Dictionary = games[i].duplicate()
			result["game_id"] = i
			return result
	return {}


func get_save_data() -> Dictionary:
	var progress: Dictionary = {}
	for world_id in _minigame_data.keys():
		var completed: Array = []
		for game in _minigame_data[world_id]:
			completed.append(game["completed"])
		progress[str(world_id)] = completed
	return progress


func load_save_data(progress: Dictionary) -> void:
	# Сначала сбрасываем — иначе при смене слота останутся флаги предыдущего.
	reset_progress()
	for key in progress.keys():
		var world_id: int = int(key)
		if not _minigame_data.has(world_id):
			continue
		if typeof(progress[key]) != TYPE_ARRAY:
			continue
		var completed: Array = progress[key]
		for i in range(mini(completed.size(), _minigame_data[world_id].size())):
			_minigame_data[world_id][i]["completed"] = bool(completed[i])


func _on_game_reset() -> void:
	reset_progress()
