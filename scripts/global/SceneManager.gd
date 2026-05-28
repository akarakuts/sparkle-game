extends Node

## SceneManager — autoload: fade transitions menu ↔ map ↔ worlds ↔ mini-games; shard on world clear.

const MENU_SCENE: String = "res://scenes/main/MainMenu.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/main/WorldMap.tscn"

const WORLD_SCENES: Dictionary = {
	0: "res://scenes/worlds/01_glow_forest/GlowForest.tscn",
	1: "res://scenes/worlds/02_ice_peaks/IcePeaks.tscn",
	2: "res://scenes/worlds/03_cloud_gardens/CloudGardens.tscn",
	3: "res://scenes/worlds/04_underwater/UnderwaterCity.tscn",
	4: "res://scenes/worlds/05_echo_desert/EchoDesert.tscn",
	5: "res://scenes/worlds/06_mechanical_grove/MechanicalGrove.tscn",
	6: "res://scenes/worlds/07_dreamlands/Dreamlands.tscn"
}

const DEFAULT_FADE_DURATION: float = 0.3

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _tween: Tween = null
var _is_transitioning: bool = false
var _pending_minigame_world: int = -1
var _pending_minigame_game: int = -1
var _pending_scene_path: String = ""
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
	_fade_to_scene(MENU_SCENE)


func goto_world_map() -> void:
	_pending_minigame_world = -1
	_pending_minigame_game = -1
	AudioManager.play_sfx("transition")
	_fade_to_scene(WORLD_MAP_SCENE)


func goto_world(world_id: int) -> void:
	if not WORLD_SCENES.has(world_id):
		push_error("SceneManager: неизвестный мир " + str(world_id))
		return
	_pending_minigame_world = -1
	_pending_minigame_game = -1
	GameState.current_world = world_id
	AudioManager.play_sfx("transition")
	_fade_to_scene(WORLD_SCENES[world_id])


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


## Сложность текущей запускаемой мини-игры (1..5).
## Сцены читают её в _ready, т.к. world_id/game_id присваиваются уже после _ready.
func get_pending_difficulty() -> int:
	if _pending_minigame_world < 0:
		return 1
	var games: Array = MiniGameManager.get_world_games(_pending_minigame_world)
	if _pending_minigame_game >= 0 and _pending_minigame_game < games.size():
		return int(games[_pending_minigame_game].get("difficulty", 1))
	return 1


func _fade_to_scene(scene_path: String, duration: float = DEFAULT_FADE_DURATION) -> void:
	if _is_transitioning:
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
		if "world_id" in scene:
			scene.world_id = _pending_minigame_world
		if "game_id" in scene:
			scene.game_id = _pending_minigame_game
		if "difficulty" in scene:
			scene.difficulty = get_pending_difficulty()
		if scene.has_signal("game_completed"):
			if not scene.game_completed.is_connected(_on_minigame_completed):
				scene.game_completed.connect(_on_minigame_completed)
	elif scene is WorldBase:
		scene.call_deferred("refresh_minigame_buttons")


func _on_minigame_completed(world_id: int, game_id: int) -> void:
	MiniGameManager.complete_minigame(world_id, game_id)
	GameState.collect_sticker(world_id, game_id)
	JuiceManager.celebrate_at(DisplayHelper.center())
	JuiceManager.sparkle_burst(DisplayHelper.center())
	AudioManager.play_sfx("success")
	SaveManager.save_game(GameState.current_save_slot)

	var got_shard: bool = false
	if MiniGameManager.is_world_ready(world_id):
		if GameState.collect_shard(world_id):
			got_shard = true
			AudioManager.play_sfx("shard")
			JuiceManager.screen_flash(Color(0.5, 0.8, 1.0), 0.45, 0.4)
		GameState.complete_world(world_id)
		# Поздравление с завершением мира показываем один раз — при загрузке мира ниже.
		_pending_world_celebration = world_id
	if got_shard:
		JuiceManager.confetti_at(DisplayHelper.center(), null, 48)

	_pending_minigame_world = -1
	_pending_minigame_game = -1
	goto_world(world_id)


## Прерывает подвисший переход (например, если завершение пришло во время фейда).
func abort_transition() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_is_transitioning = false


## Маршрутизация завершения мини-игры, если сигнал game_completed не был подключён.
## Идемпотентно: если завершение уже обработано через сигнал, ничего не делает.
func notify_minigame_completed(world_id: int, game_id: int) -> void:
	if _pending_minigame_world < 0:
		return
	_on_minigame_completed(world_id, game_id)


## Возвращает true один раз — для мира, который только что был завершён.
func consume_world_celebration(world_id: int) -> bool:
	if _pending_world_celebration == world_id:
		_pending_world_celebration = -1
		return true
	return false


func _on_fade_complete() -> void:
	_set_fade_alpha(0.0)
	_is_transitioning = false
