extends RefCounted
class_name MinigameCompletion

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")

const DESIGN_SIZE := Vector2(1080, 1920)
const BANNER_SIZE := Vector2(920, 150)
const LAYER_Z_INDEX := 300
const BANNER_START_Y := 780.0
const BANNER_END_Y := 700.0
const AUTO_FINISH_SEC := 4.0


## Показывает затемнение и кликабельный баннер «уровень пройден».
## on_finish — возврат в мир (обычно emit game_completed).
static func present(
	host: Control,
	texture_source: Variant,
	on_finish: Callable,
	auto_delay_sec: float = AUTO_FINISH_SEC,
	particle_count: int = 8
) -> void:
	if host == null or on_finish.is_null():
		return

	var old := host.get_node_or_null("CompletionLayer")
	if old:
		old.queue_free()

	var state := {"handled": false}

	var layer := Control.new()
	layer.name = "CompletionLayer"
	layer.size = DESIGN_SIZE
	layer.position = Vector2.ZERO
	layer.z_index = LAYER_Z_INDEX
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(layer)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.size = DESIGN_SIZE
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var complete_btn := MiniGameArt.make_picture_button(
		"CompleteButton",
		texture_source,
		BANNER_SIZE,
		Vector2((DESIGN_SIZE.x - BANNER_SIZE.x) * 0.5, BANNER_START_Y),
		1
	)
	complete_btn.modulate.a = 0.0
	layer.add_child(complete_btn)

	var finish := func() -> void:
		if state.handled:
			return
		state.handled = true
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		JuiceManager.button_pop(complete_btn)
		on_finish.call()

	complete_btn.pressed.connect(finish)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if state.handled:
			return
		if event is InputEventScreenTouch and event.pressed:
			finish.call()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			finish.call()
	)

	var tw := host.create_tween()
	tw.tween_property(dim, "color:a", 0.6, 0.5)
	tw.parallel().tween_property(complete_btn, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(complete_btn, "position:y", BANNER_END_Y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	for i in range(particle_count):
		var p := _spawn_particles(Vector2(randf_range(100, 980), randf_range(400, 1000)))
		layer.add_child(p)

	if auto_delay_sec > 0.0:
		host.get_tree().create_timer(auto_delay_sec).timeout.connect(finish)


## Читает world_id/game_id с узла и SceneManager; сверяет с scene_file_path.
static func resolve_launch_ids(host: Node) -> Vector2i:
	if host == null:
		return Vector2i.ZERO
	var world_id: int = int(host.get("world_id"))
	var game_id: int = int(host.get("game_id"))
	var scene_manager := host.get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		var pending_world: int = scene_manager.get_pending_minigame_world()
		var pending_game: int = scene_manager.get_pending_minigame_game()
		if pending_world >= 0:
			world_id = pending_world
		if pending_game >= 0:
			game_id = pending_game
	var scene_path: String = host.scene_file_path
	game_id = MiniGameManager.resolve_game_id(world_id, game_id, scene_path)
	return Vector2i(world_id, game_id)


static func emit_game_completed(host: Node) -> void:
	if host == null or not host.has_signal("game_completed"):
		return

	var ids := resolve_launch_ids(host)
	var world_id: int = ids.x
	var game_id: int = ids.y
	var scene_path: String = host.scene_file_path

	var scene_manager := host.get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.abort_transition()

	var had_listeners: bool = not host.game_completed.get_connections().is_empty()
	host.game_completed.emit(world_id, game_id)

	# Фолбэк только если обработчик ещё не был подключён.
	if not had_listeners and scene_manager != null:
		scene_manager.notify_minigame_completed(world_id, game_id, scene_path)


static func _spawn_particles(pos: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.amount = 12
	particles.lifetime = 1.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 120.0
	particles.spread = 360.0
	particles.gravity = Vector2(0, 180)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.7
	particles.color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)
	particles.one_shot = true
	particles.emitting = true
	particles.z_index = 250
	return particles
