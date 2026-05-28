extends Control

## Puzzle — sort coloured items into matching bins (touch drag, global canvas coords).

signal game_completed(world_id: int, game_id: int)

# Идентификаторы (заполняются извне MiniGameManager-ом)
var world_id: int = 0
var game_id: int = 0
var difficulty: int = 1  # 1..5, влияет на количество предметов на цвет

# Сколько предметов каждого цвета (зависит от сложности).
var _items_per_color: int = NUM_ITEMS_PER_COLOR

# Конфигурация игры (дизайн под пальцы: крупно)
const ITEM_SIZE: Vector2 = Vector2(120, 120)
const ITEM_COLORS: Array = [
	Color("#e74c3c"),  # Красный
	Color("#3498db"),  # Синий
	Color("#2ecc71"),  # Зелёный
	Color("#f1c40f"),  # Жёлтый
]
const COLOR_NAMES: Array = ["Красный", "Синий", "Зелёный", "Жёлтый"]
const NUM_ITEMS_PER_COLOR: int = 3  # всего 12 предметов
const MINI_BACK := "res://assets/graphics/ui/minigames/common/back_button.png"
const MINI_TITLE := "res://assets/graphics/ui/minigames/common/title_puzzle.png"
const MINI_COMPLETE := "res://assets/graphics/ui/minigames/common/complete_puzzle.png"
const PUZZLE_ITEM_TEXTURES := [
	"res://assets/graphics/ui/minigames/puzzle/item_0.png",
	"res://assets/graphics/ui/minigames/puzzle/item_1.png",
	"res://assets/graphics/ui/minigames/puzzle/item_2.png",
	"res://assets/graphics/ui/minigames/puzzle/item_3.png",
]
const PUZZLE_BIN_TEXTURES := [
	"res://assets/graphics/ui/minigames/puzzle/bin_0.png",
	"res://assets/graphics/ui/minigames/puzzle/bin_1.png",
	"res://assets/graphics/ui/minigames/puzzle/bin_2.png",
	"res://assets/graphics/ui/minigames/puzzle/bin_3.png",
]
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MinigameCompletion := preload("res://scripts/ui/MinigameCompletion.gd")

# Внутреннее состояние
var _items: Array = []          # все созданные предметы (словари)
var _bins: Array = []           # корзины (словари)
var _dragging_item: TextureRect = null
var _drag_item_index: int = -1
var _drag_color_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_touch_id: int = -1
var _drag_initial_pos: Vector2 = Vector2.ZERO
var _completed_count: int = 0
var _is_completed: bool = false
var _tween: Tween = null

# Узлы
var _back_button: Button = null
var _title_label: TextureRect = null
var _items_container: Control = null
var _bins_container: Control = null
var _completion_overlay: ColorRect = null


func _ready() -> void:
	# difficulty присваивается из SceneManager уже после _ready, поэтому читаем напрямую.
	difficulty = SceneManager.get_pending_difficulty()
	_items_per_color = clampi(difficulty + 1, 2, 4)
	_configure_viewport()
	_build_background()
	_build_back_button()
	_build_title()
	_build_items()
	_build_bins()
	_build_completion_overlay()


func _configure_viewport() -> void:
	DisplayHelper.setup_design_root(self)


func _build_background() -> void:
	# Мягкий градиент и «магические» искры.
	MiniGameArt.build_minigame_background(self, Color("#15162e"), Color("#23244a"), Color(1, 0.95, 0.7, 0.25), 9.0)


func _build_back_button() -> void:
	_back_button = MiniGameArt.make_picture_button("BackButton", MINI_BACK, Vector2(120, 120), Vector2(24, 24), 100)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _build_title() -> void:
	_title_label = MiniGameArt.make_picture("TitleLabel", MINI_TITLE, Vector2(980, 140), Vector2(50, 146), 10)
	add_child(_title_label)


func _build_items() -> void:
	# Контейнер для предметов (верхняя часть экрана)
	_items_container = Control.new()
	_items_container.name = "ItemsContainer"
	_items_container.size = Vector2(1080, 780)
	_items_container.position = Vector2(0, 290)
	_items_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items_container)

	# Создаём предметы
	_items = []
	var item_index: int = 0
	var cols: int = 4  # 4 колонки
	var spacing_x: float = (1080.0 - cols * ITEM_SIZE.x) / (cols + 1)
	var spacing_y: float = 34.0

	for color_idx in range(ITEM_COLORS.size()):
		for i in range(_items_per_color):
			var col: int = item_index % cols
			var row: int = item_index / cols

			var item := TextureRect.new()
			item.name = "Item_" + str(item_index)
			item.texture = MiniGameArt.resolve_texture(PUZZLE_ITEM_TEXTURES[color_idx])
			item.size = ITEM_SIZE
			item.position = Vector2(
				spacing_x + col * (ITEM_SIZE.x + spacing_x),
				spacing_y + row * (ITEM_SIZE.y + spacing_y)
			)
			item.z_index = 5
			item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			item.stretch_mode = TextureRect.STRETCH_SCALE

			item.mouse_filter = Control.MOUSE_FILTER_STOP
			item.gui_input.connect(_on_item_gui_input.bind(item, color_idx, item_index))

			_items_container.add_child(item)

			_items.append({
				"node": item,
				"color_idx": color_idx,
				"original_pos": item.position,
				"is_sorted": false
			})

			item_index += 1


func _build_bins() -> void:
	# Контейнер для корзин (нижняя часть экрана)
	_bins_container = Control.new()
	_bins_container.name = "BinsContainer"
	_bins_container.size = Vector2(1080, 720)
	_bins_container.position = Vector2(0, 1130)
	add_child(_bins_container)

	var num_bins: int = ITEM_COLORS.size()
	var bin_width: float = 240.0
	var bin_height: float = 360.0
	var total_width: float = num_bins * bin_width + (num_bins - 1) * 20.0
	var start_x: float = (1080.0 - total_width) / 2.0

	for idx in range(num_bins):
		var bin_x: float = start_x + idx * (bin_width + 20.0)
		var bin_y: float = 50.0

		var bin_bg := TextureRect.new()
		bin_bg.name = "BinBg_" + str(idx)
		bin_bg.size = Vector2(bin_width, bin_height)
		bin_bg.position = Vector2(bin_x, bin_y)
		bin_bg.texture = MiniGameArt.resolve_texture(PUZZLE_BIN_TEXTURES[idx])
		bin_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bin_bg.stretch_mode = TextureRect.STRETCH_SCALE
		_bins_container.add_child(bin_bg)

		# Drop zone для определения области сброса
		# Используем Area2D для детекции области сброса
		var drop_area = Area2D.new()
		drop_area.name = "DropArea_" + str(idx)
		drop_area.position = Vector2(bin_x + bin_width / 2, bin_y + bin_height / 2)

		var collision = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(bin_width, bin_height)
		collision.shape = rect_shape
		drop_area.add_child(collision)

		drop_area.set_meta("bin_idx", idx)
		drop_area.set_meta("bin_color_idx", idx)
		drop_area.set_meta("is_bin", true)
		drop_area.monitorable = false
		_bins_container.add_child(drop_area)

		_bins.append({
			"node": bin_bg,
			"color_idx": idx,
			"drop_area": drop_area,
			"items_inside": []
		})


func _build_completion_overlay() -> void:
	# Оверлей завершения (скрыт по умолчанию)
	_completion_overlay = ColorRect.new()
	_completion_overlay.name = "CompletionOverlay"
	_completion_overlay.size = Vector2(1080, 1920)
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.color = Color(0, 0, 0, 0.0)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completion_overlay.z_index = 200
	_completion_overlay.visible = false
	add_child(_completion_overlay)


# ── Drag & Drop ────────────────────────────────────────────────────


func _start_drag(item: TextureRect, color_idx: int, item_index: int, pointer: Vector2) -> void:
	if _is_completed or _items[item_index]["is_sorted"] or _dragging_item != null:
		return
	_dragging_item = item
	_drag_item_index = item_index
	_drag_color_idx = color_idx
	_drag_initial_pos = item.position
	_drag_offset = pointer - item.global_position
	item.z_index = 50


func _move_drag(pointer: Vector2) -> void:
	if _dragging_item == null:
		return
	_dragging_item.global_position = pointer - _drag_offset


func _finish_drag(pointer: Vector2) -> void:
	if _dragging_item == null:
		return
	var item: TextureRect = _dragging_item
	var item_index: int = _drag_item_index
	var color_idx: int = _drag_color_idx
	_dragging_item = null
	_drag_item_index = -1
	_drag_color_idx = -1
	_drag_touch_id = -1
	item.z_index = 5

	var dropped_in_bin: bool = false
	for bin_data in _bins:
		if _get_bin_global_rect(bin_data).has_point(pointer):
			_drop_into_bin(item, color_idx, bin_data, item_index)
			dropped_in_bin = true
			break

	if not dropped_in_bin:
		_animate_return(item, item_index)


func _get_bin_global_rect(bin_data: Dictionary) -> Rect2:
	var bg: Control = bin_data["node"]
	return bg.get_global_rect()


func _event_global_pos(event: InputEvent, control: Control) -> Vector2:
	if event is InputEventMouse:
		return event.global_position
	return control.get_global_transform() * event.position


func _on_item_gui_input(event: InputEvent, item: TextureRect, color_idx: int, item_index: int) -> void:
	if _is_completed or _items[item_index]["is_sorted"]:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_touch_id = event.index
			_start_drag(item, color_idx, item_index, _event_global_pos(event, item))
			item.accept_event()
		elif _dragging_item == item and event.index == _drag_touch_id:
			_finish_drag(_event_global_pos(event, item))
			item.accept_event()
	elif event is InputEventScreenDrag and _dragging_item == item and event.index == _drag_touch_id:
		_move_drag(_event_global_pos(event, item))
		item.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(item, color_idx, item_index, _event_global_pos(event, item))
			item.accept_event()
		elif _dragging_item == item:
			_finish_drag(_event_global_pos(event, item))
			item.accept_event()
	elif event is InputEventMouseMotion and _dragging_item == item and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move_drag(get_global_mouse_position())
		item.accept_event()


func _input(event: InputEvent) -> void:
	# Продолжаем drag, если палец ушёл за пределы квадрата.
	if _dragging_item == null or _is_completed:
		return
	if event is InputEventScreenDrag and event.index == _drag_touch_id:
		_move_drag(_screen_to_canvas(event.position))
	elif event is InputEventScreenTouch and not event.pressed and event.index == _drag_touch_id:
		_finish_drag(_screen_to_canvas(event.position))


## Координаты из пространства viewport в глобальное canvas-пространство
## (где живут global_position/global_rect узлов) — как get_global_mouse_position для мыши.
func _screen_to_canvas(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos


func _drop_into_bin(item: TextureRect, color_idx: int, bin_data: Dictionary, item_index: int) -> void:
	if color_idx == bin_data["color_idx"]:
		# Правильная сортировка!
		# Аккуратно укладываем в корзину по сетке 2x2.
		if item.get_parent() != _bins_container:
			var keep_global: Vector2 = item.global_position
			item.get_parent().remove_child(item)
			_bins_container.add_child(item)
			item.global_position = keep_global

		var local_i := _completed_count % 4
		var cx := local_i % 2
		var cy := local_i / 2
		item.position = Vector2(
			bin_data["node"].position.x + 22 + cx * (ITEM_SIZE.x + 14),
			bin_data["node"].position.y + 34 + cy * (ITEM_SIZE.y + 14)
		)

		# Анимация успеха
		_animate_success(item)

		var _audio_sort = get_node_or_null("/root/AudioManager")
		if _audio_sort and _audio_sort.has_method("play_sfx"):
			_audio_sort.play_sfx("shard")

		_items[item_index]["is_sorted"] = true
		_completed_count += 1

		# Проверяем, всё ли рассортировано
		if _completed_count >= _items.size():
			_on_all_sorted()
	else:
		# Неправильная корзина — анимация тряски и возврат
		_animate_shake(item, item_index)


func _animate_success(item: TextureRect) -> void:
	# Анимация успешной сортировки — лёгкое увеличение и зелёная вспышка
	_tween = create_tween()
	_tween.tween_property(item, "scale", Vector2(1.15, 1.15), 0.12)
	_tween.tween_property(item, "scale", Vector2(1.0, 1.0), 0.12)
	_tween.tween_property(item, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.1)
	_tween.tween_property(item, "modulate", Color(1, 1, 1, 1), 0.2)

	# Визуальный эффект — частицы успеха
	_spawn_success_particles(item.global_position)
	JuiceManager.sparkle_burst(item.global_position, self)


func _animate_shake(item: TextureRect, item_index: int) -> void:
	# Анимация тряски при ошибке
	var original_pos: Vector2 = _items[item_index]["original_pos"]
	var shake_intensity: float = 10.0

	_tween = create_tween()
	_tween.tween_method(_apply_shake.bind(item, original_pos), 0.0, 1.0, 0.3)
	_tween.tween_callback(_finish_shake.bind(item, item_index))

	# Красная вспышка
	var _audio_wrong = get_node_or_null("/root/AudioManager")
	if _audio_wrong and _audio_wrong.has_method("play_sfx"):
		_audio_wrong.play_sfx("wrong")
	JuiceManager.shake_control(item, 6.0)
	_tween.tween_property(item, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
	_tween.tween_property(item, "modulate", Color(1, 1, 1, 1), 0.2)


func _apply_shake(progress: float, item: TextureRect, original_pos: Vector2) -> void:
	# Синусоидальная тряска
	var offset_x: float = sin(progress * 20.0) * 10.0
	var offset_y: float = cos(progress * 15.0) * 5.0
	item.position = original_pos + Vector2(offset_x, offset_y)


func _finish_shake(item: TextureRect, item_index: int) -> void:
	# Возвращаем предмет на исходную позицию
	item.position = _items[item_index]["original_pos"]


func _animate_return(item: TextureRect, item_index: int) -> void:
	# Плавный возврат предмета на место
	_tween = create_tween()
	_tween.tween_property(item, "position", _items[item_index]["original_pos"], 0.2).set_ease(Tween.EASE_IN_OUT)


func _spawn_success_particles(pos: Vector2) -> void:
	# Создаём простые частицы успеха
	var particles = CPUParticles2D.new()
	particles.name = "SuccessParticles"
	particles.position = pos
	particles.amount = 12
	particles.lifetime = 0.6
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.spread = 360.0
	particles.gravity = Vector2(0, 100)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.6
	particles.color = Color(1, 1, 0.5, 1.0)
	particles.one_shot = true
	particles.emitting = true
	particles.z_index = 100
	add_child(particles)

	# Автоудаление после завершения
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)


func _on_all_sorted() -> void:
	_is_completed = true
	_play_success_sound()
	JuiceManager.celebrate_at(DisplayHelper.center(), self)
	MinigameCompletion.present(self, MINI_COMPLETE, Callable(self, "_on_completion_finished"), 4.0, 5)


func _play_success_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("complete")


func _on_completion_finished() -> void:
	MinigameCompletion.emit_game_completed(self, world_id, game_id)


func _on_back_pressed() -> void:
	if not _is_completed:
		SceneManager.goto_world(world_id)
