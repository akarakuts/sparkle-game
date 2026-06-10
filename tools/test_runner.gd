extends SceneTree

## Headless regression runner: scene load, save migration, MiniGameArt helpers.

const SCENES: Array[String] = [
	"res://scenes/main/MainMenu.tscn",
	"res://scenes/main/WorldMap.tscn",
	"res://scenes/worlds/01_glow_forest/GlowForest.tscn",
	"res://scenes/worlds/02_ice_peaks/IcePeaks.tscn",
	"res://scenes/worlds/03_cloud_gardens/CloudGardens.tscn",
	"res://scenes/worlds/04_underwater/UnderwaterCity.tscn",
	"res://scenes/worlds/05_echo_desert/EchoDesert.tscn",
	"res://scenes/worlds/06_mechanical_grove/MechanicalGrove.tscn",
	"res://scenes/worlds/07_dreamlands/Dreamlands.tscn",
	"res://scenes/minigames/Puzzle.tscn",
	"res://scenes/minigames/Memory.tscn",
	"res://scenes/minigames/Sequencing.tscn",
	"res://scenes/minigames/Drawing.tscn",
	"res://scenes/ui/Settings.tscn",
	"res://scenes/ui/ParentGate.tscn",
	"res://scenes/ui/StickerAlbum.tscn",
]

var _failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	await _run_all()
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager and audio_manager.has_method("release_test_resources"):
		audio_manager.release_test_resources()
	(load("res://scripts/ui/MiniGameArt.gd") as GDScript).clear_texture_cache()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("TEST_OK: all checks passed")
	else:
		for failure in _failures:
			push_error("TEST_FAIL: " + failure)
	await create_timer(0.2).timeout
	quit(0 if _failures.is_empty() else 1)


func _run_all() -> void:
	await _test_all_scenes_load()
	await _test_minigame_scene_paths_load()
	await _test_main_menu_play_signal_connected_once()
	await _test_puzzle_drag_drop_logic()
	await _test_drawing_line_logic()
	await _test_minigame_completion_signals_emit()
	await _test_minigame_completion_routes_back_to_world()
	await _test_game_state_complete_world_idempotent()
	await _test_save_migration_v1()
	await _test_all_worlds_minigame_slots()
	await _test_world_scene_button_counts()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _load_packed(path: String) -> PackedScene:
	var packed := load(path) as PackedScene
	_assert(packed != null, path + " не загрузилась как PackedScene")
	return packed


func _instantiate_scene(path: String) -> Node:
	var packed := _load_packed(path)
	if packed == null:
		return null
	var scene := packed.instantiate()
	_assert(scene != null, path + " не создала instance")
	return scene


func _free_scene(scene: Node) -> void:
	if scene == null:
		return
	scene.queue_free()
	await process_frame


func _test_all_scenes_load() -> void:
	for path in SCENES:
		var scene := _instantiate_scene(path)
		if scene == null:
			continue
		root.add_child(scene)
		await create_timer(0.05).timeout
		await _free_scene(scene)


func _test_minigame_scene_paths_load() -> void:
	var minigame_manager := root.get_node_or_null("MiniGameManager")
	_assert(minigame_manager != null, "autoload MiniGameManager не найден")
	if minigame_manager == null:
		return
	for world_id in range(GameConstants.TOTAL_WORLDS):
		var games: Array = minigame_manager.get_world_games(world_id)
		_assert(not games.is_empty(), "мир " + str(world_id) + " не содержит мини-игр")
		for game_id in range(games.size()):
			var scene_path: String = games[game_id].get("scene_path", "")
			_assert(not scene_path.is_empty(), "пустой scene_path для " + str(world_id) + ":" + str(game_id))
			_assert(load(scene_path) != null, "scene_path не грузится: " + scene_path)


func _test_main_menu_play_signal_connected_once() -> void:
	var scene := _instantiate_scene("res://scenes/main/MainMenu.tscn")
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	var play_button := scene.get_node_or_null("CenterContainer/VBox/PlayButton") as BaseButton
	_assert(play_button != null, "MainMenu PlayButton отсутствует или не BaseButton")
	if play_button != null:
		var play_connections := 0
		for connection in play_button.pressed.get_connections():
			if connection.get("callable") == Callable(scene, "_on_play_pressed"):
				play_connections += 1
		_assert(play_connections == 1, "PlayButton должен иметь ровно 1 pressed connection, сейчас " + str(play_connections))
	await _free_scene(scene)


func _test_puzzle_drag_drop_logic() -> void:
	var scene := _instantiate_scene("res://scenes/minigames/Puzzle.tscn")
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	await create_timer(0.05).timeout
	_assert(scene._items.size() > 0, "Puzzle не создала предметы")
	_assert(scene._bins.size() >= 4, "Puzzle не создала корзины")
	if scene._items.size() > 0 and scene._bins.size() >= 4:
		var item_data: Dictionary = scene._items[0]
		var item := item_data["node"] as Control
		var color_idx: int = item_data["color_idx"]
		var bin_data: Dictionary = scene._bins[color_idx]
		var bin_node := bin_data["node"] as Control
		_assert(item != null, "Puzzle item node не создан")
		_assert(bin_node != null, "Puzzle bin node не создан")
		if item != null and bin_node != null:
			var start_pos: Vector2 = item.get_global_rect().get_center()
			var target_pos: Vector2 = bin_node.get_global_rect().get_center()
			scene._start_drag(item, color_idx, 0, start_pos)
			scene._move_drag(target_pos)
			scene._finish_drag(target_pos)
			_assert(scene._items[0]["is_sorted"], "Puzzle не засчитала правильный drop")
			_assert(scene._completed_count == 1, "Puzzle completed_count не увеличился")
	await _free_scene(scene)


func _test_drawing_line_logic() -> void:
	var scene := _instantiate_scene("res://scenes/minigames/Drawing.tscn")
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	scene._start_new_line(Vector2(20, 20))
	scene._add_canvas_point(Vector2(120, 120))
	scene._finish_current_line()
	_assert(scene._lines.size() == 1, "Drawing не создала линию")
	if scene._lines.size() == 1:
		_assert(scene._lines[0].points.size() >= 2, "Drawing линия содержит меньше 2 точек")
	await _free_scene(scene)


func _test_minigame_completion_signals_emit() -> void:
	var minigame_manager := root.get_node_or_null("MiniGameManager")
	for scene_path in [
		"res://scenes/minigames/Puzzle.tscn",
		"res://scenes/minigames/Memory.tscn",
		"res://scenes/minigames/Sequencing.tscn",
		"res://scenes/minigames/Drawing.tscn",
	]:
		var expected_game_id: int = 0
		if minigame_manager != null:
			expected_game_id = minigame_manager.resolve_game_id(0, 0, scene_path)
		var scene := _instantiate_scene(scene_path)
		if scene == null:
			continue
		root.add_child(scene)
		await process_frame
		scene.world_id = 0
		scene.game_id = 0
		var completed := []
		scene.game_completed.connect(func(world_id: int, game_id: int) -> void:
			completed.append([world_id, game_id])
		)
		scene._on_completion_finished()
		_assert(completed.size() == 1, scene_path + " не испускает game_completed после завершения")
		if completed.size() == 1:
			_assert(
				completed[0] == [0, expected_game_id],
				scene_path + " испускает неправильные world_id/game_id: " + str(completed[0])
			)
		await _free_scene(scene)


func _test_minigame_completion_routes_back_to_world() -> void:
	var scene_manager := root.get_node_or_null("SceneManager")
	var minigame_manager := root.get_node_or_null("MiniGameManager")
	var game_state := root.get_node_or_null("GameState")
	_assert(scene_manager != null, "autoload SceneManager не найден")
	_assert(minigame_manager != null, "autoload MiniGameManager не найден")
	_assert(game_state != null, "autoload GameState не найден")
	if scene_manager == null or minigame_manager == null or game_state == null:
		return

	var saved_progress: Dictionary = minigame_manager.get_save_data()
	var saved_world: int = game_state.current_world
	var saved_shards: Array = game_state.collected_shards.duplicate(true)
	var saved_world_states: Dictionary = game_state.world_states.duplicate(true)
	var saved_stickers: Array = game_state.collected_stickers.duplicate(true)

	if scene_manager._tween != null and scene_manager._tween.is_valid():
		scene_manager._tween.kill()
	scene_manager._is_transitioning = false
	scene_manager._pending_scene_path = ""
	scene_manager._pending_minigame_world = 0
	scene_manager._pending_minigame_game = 0

	scene_manager._on_minigame_completed(0, 0)
	_assert(scene_manager._pending_scene_path == "res://scenes/worlds/01_glow_forest/GlowForest.tscn", "SceneManager не планирует возврат в мир после завершения мини-игры")
	_assert(scene_manager._is_transitioning, "SceneManager не запускает переход после завершения мини-игры")

	if scene_manager._tween != null and scene_manager._tween.is_valid():
		scene_manager._tween.kill()
	scene_manager._is_transitioning = false
	scene_manager._pending_scene_path = ""
	scene_manager._pending_minigame_world = -1
	scene_manager._pending_minigame_game = -1
	minigame_manager.load_save_data(saved_progress)
	game_state.current_world = saved_world
	game_state.collected_shards = saved_shards
	game_state.world_states = saved_world_states
	game_state.collected_stickers = saved_stickers


func _test_all_worlds_minigame_slots() -> void:
	var scene_manager := root.get_node_or_null("SceneManager")
	var minigame_manager := root.get_node_or_null("MiniGameManager")
	_assert(scene_manager != null, "autoload SceneManager не найден")
	_assert(minigame_manager != null, "autoload MiniGameManager не найден")
	if scene_manager == null or minigame_manager == null:
		return

	var saved_progress: Dictionary = minigame_manager.get_save_data()

	for world_id in range(GameConstants.TOTAL_WORLDS):
		var games: Array = minigame_manager.get_world_games(world_id)
		_assert(not games.is_empty(), "мир " + str(world_id) + " без мини-игр")
		for game_id in range(games.size()):
			var game: Dictionary = games[game_id]
			var scene_path: String = str(game.get("scene_path", ""))
			var game_name: String = str(game.get("name", ""))

			var resolved: int = minigame_manager.resolve_game_id(world_id, game_id, scene_path)
			_assert(
				resolved == game_id,
				"мир %d слот %d (%s): resolve_game_id → %d" % [world_id, game_id, game_name, resolved]
			)

			scene_manager._pending_minigame_world = world_id
			scene_manager._pending_minigame_game = game_id
			var scene := _instantiate_scene(scene_path)
			if scene == null:
				continue
			root.add_child(scene)
			await process_frame
			_assert(
				int(scene.get("world_id")) == world_id,
				"мир %d слот %d: world_id на сцене = %s" % [world_id, game_id, str(scene.get("world_id"))]
			)
			_assert(
				int(scene.get("game_id")) == game_id,
				"мир %d слот %d (%s): game_id на сцене = %s" % [world_id, game_id, game_name, str(scene.get("game_id"))]
			)

			minigame_manager.reset_progress()
			scene._on_completion_finished()
			await process_frame
			var after: Array = minigame_manager.get_world_games(world_id)
			for i in range(after.size()):
				var done: bool = after[i].get("completed", false)
				if i == game_id:
					_assert(done, "мир %d слот %d (%s) должен быть пройден" % [world_id, game_id, game_name])
				else:
					_assert(not done, "мир %d слот %d не должен отмечаться при прохождении слота %d" % [world_id, i, game_id])

			scene_manager._pending_minigame_world = -1
			scene_manager._pending_minigame_game = -1
			await _free_scene(scene)

	# Дубли типов: мир 4 слот 4 (вторая «Последовательность»), мир 5 слот 4 (вторая «Сортировка»).
	for case in [
		{"world": 4, "slot": 4, "path": "res://scenes/minigames/Sequencing.tscn"},
		{"world": 5, "slot": 4, "path": "res://scenes/minigames/Puzzle.tscn"},
	]:
		var world_id: int = int(case["world"])
		var game_id: int = int(case["slot"])
		scene_manager._pending_minigame_world = world_id
		scene_manager._pending_minigame_game = game_id
		minigame_manager.reset_progress()
		var dup_scene := _instantiate_scene(str(case["path"]))
		if dup_scene == null:
			continue
		root.add_child(dup_scene)
		await process_frame
		dup_scene.game_id = 0
		dup_scene._on_completion_finished()
		await process_frame
		var dup_games: Array = minigame_manager.get_world_games(world_id)
		_assert(
			dup_games[game_id].get("completed", false),
			"мир %d дубль слот %d должен отмечаться при pending=%d" % [world_id, game_id, game_id]
		)
		_assert(
			not dup_games[0].get("completed", false),
			"мир %d слот 0 не должен отмечаться при прохождении дубля слота %d" % [world_id, game_id]
		)
		scene_manager._pending_minigame_world = -1
		scene_manager._pending_minigame_game = -1
		await _free_scene(dup_scene)

	minigame_manager.load_save_data(saved_progress)


func _test_world_scene_button_counts() -> void:
	const EXPECTED_BUTTONS := {0: 4, 1: 4, 2: 4, 3: 3, 4: 5, 5: 5, 6: 1}
	var minigame_manager := root.get_node_or_null("MiniGameManager")
	if minigame_manager == null:
		return

	for world_id in range(GameConstants.TOTAL_WORLDS):
		var games: Array = minigame_manager.get_world_games(world_id)
		var expected: int = int(EXPECTED_BUTTONS.get(world_id, games.size()))
		_assert(
			games.size() == expected,
			"мир %d: в конфиге %d мини-игр, ожидалось %d кнопок" % [world_id, games.size(), expected]
		)

		var world_path: String = str(GameConstants.WORLD_SCENES.get(world_id, ""))
		if world_path.is_empty():
			continue
		var world_scene := _instantiate_scene(world_path)
		if world_scene == null:
			continue
		root.add_child(world_scene)
		await process_frame
		var btn_count := 0
		for node in world_scene.find_children("MiniGame_*", "Button", true, false):
			btn_count += 1
		_assert(
			btn_count == expected,
			"мир %d (%s): на сцене %d кнопок мини-игр, ожидалось %d" % [world_id, world_path, btn_count, expected]
		)
		await _free_scene(world_scene)


func _test_game_state_complete_world_idempotent() -> void:
	var game_state := root.get_node_or_null("GameState")
	_assert(game_state != null, "autoload GameState не найден")
	if game_state == null:
		return
	var saved_states: Dictionary = game_state.world_states.duplicate(true)
	game_state.world_states[0] = "open"
	_assert(game_state.complete_world(0), "complete_world(0) должен вернуть true при первом вызове")
	_assert(not game_state.complete_world(0), "повторный complete_world(0) должен вернуть false")
	_assert(game_state.world_states.get(1, "locked") == "open", "complete_world должен открыть следующий мир")
	game_state.world_states = saved_states


func _test_save_migration_v1() -> void:
	var save_manager := root.get_node_or_null("SaveManager")
	var game_state := root.get_node_or_null("GameState")
	_assert(save_manager != null, "autoload SaveManager не найден")
	_assert(game_state != null, "autoload GameState не найден")
	if save_manager == null or game_state == null:
		return
	var slot := 99
	var test_path := "user://save_%d.json" % slot
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	var legacy := {
		"save_version": 1,
		"current_world": 0,
		"collected_shards": [true, false],
		"world_states": {"0": "completed", "1": "open"},
		"settings": {"sound": true, "music": true},
		"play_time": 12.5,
		"minigame_progress": {},
	}
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	_assert(file != null, "не удалось записать тестовый сейв v1")
	if file == null:
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	_assert(save_manager.load_game(slot), "миграция сейва v1 должна загружаться")
	_assert(game_state.collected_shards.size() == GameConstants.TOTAL_WORLDS, "миграция v1: размер collected_shards")
	_assert(game_state.collected_shards[0], "миграция v1: первый осколок")
	_assert(not game_state.collected_shards[1], "миграция v1: второй осколок")
	_assert(game_state.collected_stickers is Array, "миграция v1: collected_stickers — массив")
	DirAccess.remove_absolute(test_path)
