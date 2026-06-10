extends Control
class_name MinigameBase

## Shared minigame scaffold: ids, difficulty, back button, background, completion.

signal game_completed(world_id: int, game_id: int)

var world_id: int = 0
var game_id: int = 0
var difficulty: int = 1

const MINI_BACK := "res://assets/graphics/ui/minigames/common/back_button.png"

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MinigameCompletion := preload("res://scripts/ui/MinigameCompletion.gd")


func setup_minigame_viewport() -> void:
	SceneManager.apply_pending_minigame_context(self)
	difficulty = SceneManager.get_pending_difficulty()
	DisplayHelper.setup_design_root(self)


func build_minigame_background(top: Color, bottom: Color, twinkle: Color = Color(1, 0.95, 0.7, 0.22), density: float = 9.0) -> void:
	MiniGameArt.build_minigame_background(self, top, bottom, twinkle, density)


func build_back_button() -> Button:
	var btn := MiniGameArt.make_picture_button("BackButton", MINI_BACK, Vector2(120, 120), Vector2(24, 24), 100)
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)
	return btn


func play_success_sfx() -> void:
	AudioManager.play_sfx("success")


func emit_game_completed() -> void:
	game_completed.emit(world_id, game_id)


func present_completion(complete_tex: String, on_finished: Callable) -> void:
	MinigameCompletion.present(self, complete_tex, on_finished)


func _on_back_pressed() -> void:
	SceneManager.goto_world(world_id)
