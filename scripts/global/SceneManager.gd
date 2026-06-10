extends Node

## SceneManager — autoload: fade transitions menu ↔ map ↔ worlds ↔ mini-games.

const DEFAULT_FADE_DURATION: float = 0.3

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _tween: Tween = null
var _is_transitioning: bool = false
var _pending_minigame_world: int = -1
var _pending_minigame_game: int = -1
var _pending_scene_path: String = ""
var _queued_scene_path: String = ""
# Мир, для которого нужно показать поздравление при следующей загрузке (момент сбора осколка).
var _pending_world_celebration: int = -1


func _ready() -> void:
	_setup_fade_overlay()


func _setup_fade_overlay() -> void:
	if _fade_layer == null:
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "SceneFadeLayer"
		_fade_layer.layer = 128
		add_child(_fade_layer)

	if _fade_rect == null:
		_fade_rect = ColorRect.new()
		_fade_rect.name = "SceneFadeRect"
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_layer.add_child(_fade_rect)

	DisplayHelper.fill_control(_fade_rect)
	_set_fade_alpha(0.0)


func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect != null:
		_fade_rect.color = Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0))


func goto_menu() -> void:
	_pending_minigame_world = -1
	_pending_minigame_game = -1
	AudioManager.play_sfx("transition")
	_fade_to_scene(GameConstants.MENU_SCENE)


func goto_world_map() -> void:
	_pending_minigame_world = -1
	_pending_minigame_game = -1
	AudioManager.play_sfx("transition")
	_fade_to_scene(GameConstants.WORLD_MAP_SCENE)


func goto_world(world_id: int) -> void:
	if not GameConstants.WORLD_SCENES.has(world_id):
		push_error("SceneManager: неизвестный мир " + str(world_id))
		return
	_pending_minigame_world = -1
	_pending_minigame_game = -1
	GameState.current_world = world_id
	AudioManager.play_sfx("transition")
	_fade_to_scene(GameConstants.WORLD_SCENES[world_id])


func goto_minigame(world_id: int, game_id: int) -> void:
	var key: String = str(world_id) + "_" + str(game_id)
	var games: Array = MiniGameManager.get_world_games(world_id)
	if game_id < 0 or game_id >= games.size():
		push_error("SceneManager: неизвестная мини-игра " + key)
		return
	_pending_minigame_world = world_id
	_pending_minigame_game = game_id
	AudioManager.play_sfx("transition")
	_fade_to_scene(games[game_id]["scene_path"])


func get_pending_minigame_world() -> int:
	return _pending_minigame_world


func get_pending_minigame_game() -> int:
	return _pending_minigame_game


## Сложность текущей запускаемой мини-игры (1..5).
func get_pending_difficulty() -> int:
	if _pending_minigame_world < 0:
		return 1
	var games: Array = MiniGameManager.get_world_games(_pending_minigame_world)
	if _pending_minigame_game >= 0 and _pending_minigame_game < games.size():
		return int(games[_pending_minigame_game].get("difficulty", 1))
	return 1


## Пробрасывает world_id / game_id / difficulty в сцену мини-игры и подключает game_completed.
func apply_pending_minigame_context(scene: Node) -> void:
	if scene == null or _pending_minigame_world < 0:
		return
	scene.set("world_id", _pending_minigame_world)
	scene.set("game_id", _pending_minigame_game)
	if "difficulty" in scene:
		scene.difficulty = get_pending_difficulty()
	if scene.has_signal("game_completed"):
		if not scene.game_completed.is_connected(_on_minigame_completed):
			scene.game_completed.connect(_on_minigame_completed)


func _fade_to_scene(scene_path: String, duration: float = DEFAULT_FADE_DURATION) -> void:
	if _is_transitioning:
		_queued_scene_path = scene_path
		return

	_setup_fade_overlay()
	_is_transitioning = true
	_pending_scene_path = scene_path

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_method(_set_fade_alpha, 0.0, 1.0, duration)
	_tween.tween_callback(_perform_scene_change)
	_tween.tween_interval(0.05)
	_tween.tween_method(_set_fade_alpha, 1.0, 0.0, duration)
	_tween.tween_callback(_on_fade_complete)


func _perform_scene_change() -> void:
	if _pending_scene_path.is_empty():
		return
	var path: String = _pending_scene_path
	_pending_scene_path = ""
	_change_scene(path)


func _change_scene(scene_path: String) -> void:
	var packed_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("SceneManager: не удалось загрузить сцену: " + scene_path)
		_set_fade_alpha(0.0)
		_is_transitioning = false
		return

	var err: Error = get_tree().change_scene_to_packed(packed_scene)
	if err != OK:
		push_error("SceneManager: change_scene_to_packed ошибка " + str(err) + " для " + scene_path)
		_set_fade_alpha(0.0)
		_is_transitioning = false
		return

	# Контекст мини-игры задаём сразу — до _ready/deferred, иначе game_id остаётся 0.
	apply_pending_minigame_context(get_tree().current_scene)
	call_deferred("_configure_current_scene")


func _configure_current_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	if scene is Control:
		var scene_path := scene.scene_file_path
		var is_minigame := scene_path.begins_with("res://scenes/minigames/")
		if not is_minigame:
			DisplayHelper.fill_control(scene)

	if _pending_minigame_world >= 0:
		apply_pending_minigame_context(scene)
	elif scene is WorldBase:
		scene.call_deferred("refresh_minigame_buttons")


func _on_minigame_completed(world_id: int, game_id: int, scene_path: String = "") -> void:
	var outcome: Dictionary = ProgressService.handle_minigame_completed(world_id, game_id, scene_path)
	if int(outcome.get("celebration_world", -1)) >= 0:
		_pending_world_celebration = int(outcome["celebration_world"])

	_pending_minigame_world = -1
	_pending_minigame_game = -1
	goto_world(world_id)


func abort_transition() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_is_transitioning = false
	_queued_scene_path = ""


func notify_minigame_completed(world_id: int, game_id: int, scene_path: String = "") -> void:
	if _pending_minigame_world < 0:
		return
	_on_minigame_completed(world_id, game_id, scene_path)


func consume_world_celebration(world_id: int) -> bool:
	if _pending_world_celebration == world_id:
		_pending_world_celebration = -1
		return true
	return false


func _on_fade_complete() -> void:
	_set_fade_alpha(0.0)
	_is_transitioning = false
	if not _queued_scene_path.is_empty():
		var next_path: String = _queued_scene_path
		_queued_scene_path = ""
		call_deferred("_fade_to_scene", next_path)
