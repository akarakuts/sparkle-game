extends SceneTree

## Headless regression runner: scene load, save migration, MiniGameArt helpers.

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const SCENES := [
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
	MiniGameArt.clear_texture_cache()
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
	for world_id in range(7):
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
	var play_button := scene.get_node_or_null("CenterContainer/VBox/PlayButton") as Button
	_assert(play_button != null, "MainMenu PlayButton отсутствует или не Button")
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
	for scene_path in [
		"res://scenes/minigames/Puzzle.tscn",
		"res://scenes/minigames/Memory.tscn",
		"res://scenes/minigames/Sequencing.tscn",
		"res://scenes/minigames/Drawing.tscn",
	]:
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
			_assert(completed[0] == [0, 0], scene_path + " испускает неправильные world_id/game_id")
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
