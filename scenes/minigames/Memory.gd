extends Control

## Memory — flip cards and match pairs; difficulty scales grid size.

signal game_completed(world_id: int, game_id: int)

# Идентификаторы (заполняются извне)
var world_id: int = 0
var game_id: int = 0
var difficulty: int = 1  # 1..5, влияет на время показа несовпавших карт

# Пауза перед переворотом несовпавших карт (зависит от сложности).
var _flip_back_delay: float = 0.8

# Конфигурация игры (сетка зависит от difficulty)
var _grid_cols: int = 4
var _grid_rows: int = 4
const CARD_SIZE: Vector2 = Vector2(210, 250)
const CARD_GAP: float = 18.0

# WOW-ассеты
const WOW_MEMORY_BACK := preload("res://assets/graphics/ui/wow/cards/memory_back.png")
const WOW_MEMORY_FRAME := preload("res://assets/graphics/ui/wow/cards/memory_frame.png")
const MINI_BACK := "res://assets/graphics/ui/minigames/common/back_button.png"
const MINI_TITLE := "res://assets/graphics/ui/minigames/common/title_memory.png"
const MINI_COMPLETE := "res://assets/graphics/ui/minigames/common/complete_memory.png"
const ATTEMPTS_LABEL := "res://assets/graphics/ui/minigames/common/attempts_label.png"
const MEMORY_FRONTS := [
	"res://assets/graphics/ui/minigames/memory/front_0.png",
	"res://assets/graphics/ui/minigames/memory/front_1.png",
	"res://assets/graphics/ui/minigames/memory/front_2.png",
	"res://assets/graphics/ui/minigames/memory/front_3.png",
	"res://assets/graphics/ui/minigames/memory/front_4.png",
	"res://assets/graphics/ui/minigames/memory/front_5.png",
	"res://assets/graphics/ui/minigames/memory/front_6.png",
	"res://assets/graphics/ui/minigames/memory/front_7.png",
]
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MinigameCompletion := preload("res://scripts/ui/MinigameCompletion.gd")

# Цвета для пар карт (8 разных цветов)
const PAIR_COLORS: Array = [
	Color("#e74c3c"),  # Красный
	Color("#3498db"),  # Синий
	Color("#2ecc71"),  # Зелёный
	Color("#f1c40f"),  # Жёлтый
	Color("#9b59b6"),  # Фиолетовый
	Color("#e67e22"),  # Оранжевый
	Color("#1abc9c"),  # Бирюзовый
	Color("#ff6b81"),  # Розовый
]

# Внутреннее состояние
var _cards: Array = []          # массив словарей карт
var _first_open: Dictionary = {}  # первая открытая карта
var _second_open: Dictionary = {} # вторая открытая карта
var _is_waiting: bool = false     # ожидание переворота обратно
var _attempts: int = 0
var _matches_found: int = 0
var _total_pairs: int = 8
var _is_completed: bool = false

# Узлы
var _back_button: Button = null
var _title_label: TextureRect = null
var _attempt_label: TextureRect = null
var _attempt_digits: Control = null
var _grid_container: Control = null


func _ready() -> void:
	SceneManager.apply_pending_minigame_context(self)
	difficulty = SceneManager.get_pending_difficulty()
	_apply_difficulty_grid()
	_flip_back_delay = clampf(1.1 - difficulty * 0.12, 0.45, 1.1)
	_configure_viewport()
	_build_background()
	_build_back_button()
	_build_title()
	_build_attempt_counter()
	_build_grid()
	_shuffle_cards()


func _configure_viewport() -> void:
	DisplayHelper.setup_design_root(self)

func _build_background() -> void:
	MiniGameArt.build_minigame_background(self, Color("#12142b"), Color("#25285a"), Color(0.9, 0.95, 1.0, 0.22), 10.0)


func _build_back_button() -> void:
	_back_button = MiniGameArt.make_picture_button("BackButton", MINI_BACK, Vector2(120, 120), Vector2(24, 24), 100)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _build_title() -> void:
	_title_label = MiniGameArt.make_picture("TitleLabel", MINI_TITLE, Vector2(980, 140), Vector2(50, 146), 10)
	add_child(_title_label)


func _build_attempt_counter() -> void:
	_attempt_label = MiniGameArt.make_picture("AttemptLabel", ATTEMPTS_LABEL, Vector2(340, 78), Vector2(610, 270), 10)
	add_child(_attempt_label)
	_attempt_digits = Control.new()
	_attempt_digits.name = "AttemptDigits"
	_attempt_digits.position = Vector2(948, 272)
	_attempt_digits.size = Vector2(120, 78)
	_attempt_digits.z_index = 10
	add_child(_attempt_digits)
	_update_attempt_counter()


func _apply_difficulty_grid() -> void:
	match clampi(difficulty, 1, 5):
		1, 2:
			_grid_cols = 3
			_grid_rows = 2
			_total_pairs = 3
		3:
			_grid_cols = 4
			_grid_rows = 3
			_total_pairs = 6
		_:
			_grid_cols = 4
			_grid_rows = 4
			_total_pairs = 8


func _update_attempt_counter() -> void:
	MiniGameArt.render_digit_row_default(_attempt_digits, str(_attempts))


func _build_grid() -> void:
	_grid_container = Control.new()
	_grid_container.name = "GridContainer"
	add_child(_grid_container)

	var grid_width: float = _grid_cols * CARD_SIZE.x + (_grid_cols - 1) * CARD_GAP
	var grid_height: float = _grid_rows * CARD_SIZE.y + (_grid_rows - 1) * CARD_GAP
	var start_x: float = (1080.0 - grid_width) / 2.0
	var start_y: float = (1920.0 - grid_height) / 2.0 + 40.0

	_grid_container.position = Vector2(start_x, start_y)

	_cards = []

	for row in range(_grid_rows):
		for col in range(_grid_cols):
			var index: int = row * _grid_cols + col

			# Карта — контейнер для двух состояний
			var card_container = Control.new()
			card_container.name = "Card_" + str(index)
			card_container.size = CARD_SIZE
			card_container.position = Vector2(
				col * (CARD_SIZE.x + CARD_GAP),
				row * (CARD_SIZE.y + CARD_GAP)
			)
			card_container.z_index = 5
			_grid_container.add_child(card_container)

			# Рубашка карточки — PNG (вау-стиль)
			var card_back = TextureRect.new()
			card_back.name = "CardBack"
			card_back.size = CARD_SIZE
			card_back.position = Vector2.ZERO
			card_back.texture = WOW_MEMORY_BACK
			card_back.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			card_back.stretch_mode = TextureRect.STRETCH_SCALE
			card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE

			card_container.add_child(card_back)

			# Лицевая сторона (цветная) + декоративная рамка
			var card_front := TextureRect.new()
			card_front.name = "CardFront"
			card_front.size = CARD_SIZE
			card_front.position = Vector2.ZERO
			card_front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_front.stretch_mode = TextureRect.STRETCH_SCALE
			card_front.visible = false  # лицо скрыто
			card_container.add_child(card_front)

			var frame := TextureRect.new()
			frame.name = "Frame"
			frame.size = CARD_SIZE
			frame.position = Vector2.ZERO
			frame.texture = WOW_MEMORY_FRAME
			frame.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			frame.stretch_mode = TextureRect.STRETCH_SCALE
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.visible = false
			card_container.add_child(frame)

			# Кнопка для нажатия на карту
			var card_button = Button.new()
			card_button.name = "CardButton"
			card_button.size = CARD_SIZE
			card_button.position = Vector2.ZERO
			card_button.z_index = 10
			card_button.flat = true
			card_button.focus_mode = Control.FOCUS_NONE

			var btn_normal = StyleBoxFlat.new()
			btn_normal.bg_color = Color(1, 1, 1, 0.0)
			card_button.add_theme_stylebox_override("normal", btn_normal)
			var btn_hover = StyleBoxFlat.new()
			btn_hover.bg_color = Color(1, 1, 1, 0.0)
			card_button.add_theme_stylebox_override("hover", btn_hover)
			var btn_pressed = StyleBoxFlat.new()
			btn_pressed.bg_color = Color(1, 1, 1, 0.0)
			card_button.add_theme_stylebox_override("pressed", btn_pressed)

			card_button.pressed.connect(_on_card_pressed.bind(index))
			card_container.add_child(card_button)

			_cards.append({
				"container": card_container,
				"back": card_back,
				"front": card_front,
				"frame": frame,
				"button": card_button,
				"color_idx": -1,  # будет установлен позже
				"is_open": false,
				"is_matched": false
			})


func _shuffle_cards() -> void:
	# Создаём массив цветовых индексов (по 2 каждого цвета)
	var color_indices: Array = []
	for i in range(_total_pairs):
		color_indices.append(i)
		color_indices.append(i)

	# Перемешиваем
	color_indices.shuffle()

	# Назначаем цвета картам
	for i in range(_cards.size()):
		var color_idx: int = color_indices[i]
		_cards[i]["color_idx"] = color_idx
		_cards[i]["front"].texture = MiniGameArt.resolve_texture(MEMORY_FRONTS[color_idx])


func _on_card_pressed(index: int) -> void:
	if _is_waiting or _is_completed:
		return

	var card = _cards[index]
	if card["is_open"] or card["is_matched"]:
		return

	# Открываем карту
	card["is_open"] = true
	_animate_flip(card, true)

	# Сравниваем
	if _first_open.is_empty():
		_first_open = card
		_first_open["index"] = index
	elif _second_open.is_empty():
		_second_open = card
		_second_open["index"] = index
		_attempts += 1
		_update_attempt_counter()

		# Сравниваем цвета
		if _first_open["color_idx"] == _second_open["color_idx"]:
			# Совпадение!
			_first_open["is_matched"] = true
			_second_open["is_matched"] = true
			_matches_found += 1

			var _audio_match = get_node_or_null("/root/AudioManager")
			if _audio_match and _audio_match.has_method("play_sfx"):
				_audio_match.play_sfx("shard")

			# Анимация совпадения
			_animate_match(_first_open)
			_animate_match(_second_open)

			_first_open = {}
			_second_open = {}
			_is_waiting = false

			# Проверяем победу
			if _matches_found >= _total_pairs:
				_on_all_matched()
		else:
			# Не совпали — ждём и переворачиваем обратно
			var _audio_wrong = get_node_or_null("/root/AudioManager")
			if _audio_wrong and _audio_wrong.has_method("play_sfx"):
				_audio_wrong.play_sfx("wrong")
			_is_waiting = true
			var first_idx: int = _first_open["index"]
			var second_idx: int = _second_open["index"]
			var timer = get_tree().create_timer(_flip_back_delay)
			timer.timeout.connect(_flip_back.bind(first_idx, second_idx))


func _animate_flip(card: Dictionary, open: bool) -> void:
	var container: Control = card["container"]
	var tween = create_tween()

	if open:
		# Анимация открытия: scale.x 1→0, смена, 0→1
		tween.tween_property(container, "scale:x", 0.0, 0.15)
		tween.tween_callback(_swap_card_face.bind(card, open))
		tween.tween_property(container, "scale:x", 1.0, 0.15)
		tween.parallel().tween_property(container, "rotation", 0.0, 0.3)
	else:
		# Анимация закрытия
		tween.tween_property(container, "scale:x", 0.0, 0.15)
		tween.tween_callback(_swap_card_face.bind(card, open))
		tween.tween_property(container, "scale:x", 1.0, 0.15)
		tween.parallel().tween_property(container, "rotation", 0.0, 0.3)


func _swap_card_face(card: Dictionary, show_front: bool) -> void:
	card["back"].visible = not show_front
	card["front"].visible = show_front
	if card.has("frame"):
		card["frame"].visible = show_front


func _animate_match(card: Dictionary) -> void:
	# Анимация зелёной вспышки при совпадении
	var container: Control = card["container"]
	var tween = create_tween()

	tween.tween_property(container, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.2)
	tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(container, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.15)


func _flip_back(first_idx: int, second_idx: int) -> void:
	if _is_completed or not is_inside_tree():
		return

	var card1 = _cards[first_idx]
	var card2 = _cards[second_idx]

	card1["is_open"] = false
	card2["is_open"] = false

	_animate_flip(card1, false)
	_animate_flip(card2, false)

	_first_open = {}
	_second_open = {}
	_is_waiting = false


func _on_all_matched() -> void:
	_is_completed = true
	_play_success_sound()
	JuiceManager.celebrate_at(DisplayHelper.center(), self)
	MinigameCompletion.present(self, MINI_COMPLETE, Callable(self, "_on_completion_finished"))


func _play_success_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("complete")


func _on_completion_finished() -> void:
	MinigameCompletion.emit_game_completed(self)


func _on_back_pressed() -> void:
	if not _is_completed:
		SceneManager.goto_world(world_id)
