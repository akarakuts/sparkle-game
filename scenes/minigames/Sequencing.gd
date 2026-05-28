extends Control

## Sequencing — watch then repeat a colour sequence on pads.

signal game_completed(world_id: int, game_id: int)

# Идентификаторы (заполняются извне)
var world_id: int = 0
var game_id: int = 0
var difficulty: int = 1  # 1..5, влияет на число уровней

# Сколько уровней нужно пройти (зависит от сложности).
var _levels_to_complete: int = 0

# Конфигурация
const NUM_BUTTONS: int = 5  # 5 цветных кнопок
const BUTTON_SIZE: float = 180.0
const BUTTON_GAP: float = 34.0

# Цвета кнопок
const BUTTON_COLORS: Array = [
	Color("#e74c3c"),  # Красный
	Color("#3498db"),  # Синий
	Color("#2ecc71"),  # Зелёный
	Color("#f1c40f"),  # Жёлтый
	Color("#9b59b6"),  # Фиолетовый
]

# Цвета при нажатии (ярче)
const BUTTON_ACTIVE_COLORS: Array = [
	Color("#ff6b6b"),  # Красный активный
	Color("#5dade2"),  # Синий активный
	Color("#58d68d"),  # Зелёный активный
	Color("#f7dc6f"),  # Жёлтый активный
	Color("#af7ac5"),  # Фиолетовый активный
]

# Уровни сложности: количество шагов в последовательности
const LEVEL_STEPS: Array = [3, 4, 5, 6, 7]
const MINI_BACK := "res://assets/graphics/ui/minigames/common/back_button.png"
const MINI_TITLE := "res://assets/graphics/ui/minigames/common/title_sequencing.png"
const MINI_COMPLETE := "res://assets/graphics/ui/minigames/common/complete_sequencing.png"
const STATUS_WATCH := "res://assets/graphics/ui/minigames/common/status_watch.png"
const STATUS_REPEAT := "res://assets/graphics/ui/minigames/common/status_repeat.png"
const STATUS_SUCCESS := "res://assets/graphics/ui/minigames/common/status_success.png"
const STATUS_FAIL := "res://assets/graphics/ui/minigames/common/status_fail.png"
const LEVEL_LABEL := "res://assets/graphics/ui/minigames/common/level_label.png"
const OF_LABEL := "res://assets/graphics/ui/minigames/common/of_label.png"
const DIGIT_TEXTURES := [
	"res://assets/graphics/ui/minigames/digits/0.png",
	"res://assets/graphics/ui/minigames/digits/1.png",
	"res://assets/graphics/ui/minigames/digits/2.png",
	"res://assets/graphics/ui/minigames/digits/3.png",
	"res://assets/graphics/ui/minigames/digits/4.png",
	"res://assets/graphics/ui/minigames/digits/5.png",
	"res://assets/graphics/ui/minigames/digits/6.png",
	"res://assets/graphics/ui/minigames/digits/7.png",
	"res://assets/graphics/ui/minigames/digits/8.png",
	"res://assets/graphics/ui/minigames/digits/9.png",
]
const BUTTON_TEXTURES := [
	"res://assets/graphics/ui/minigames/sequencing/button_0.png",
	"res://assets/graphics/ui/minigames/sequencing/button_1.png",
	"res://assets/graphics/ui/minigames/sequencing/button_2.png",
	"res://assets/graphics/ui/minigames/sequencing/button_3.png",
	"res://assets/graphics/ui/minigames/sequencing/button_4.png",
]
const BUTTON_ACTIVE_TEXTURES := [
	"res://assets/graphics/ui/minigames/sequencing/button_0_active.png",
	"res://assets/graphics/ui/minigames/sequencing/button_1_active.png",
	"res://assets/graphics/ui/minigames/sequencing/button_2_active.png",
	"res://assets/graphics/ui/minigames/sequencing/button_3_active.png",
	"res://assets/graphics/ui/minigames/sequencing/button_4_active.png",
]
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MinigameCompletion := preload("res://scripts/ui/MinigameCompletion.gd")

# Внутреннее состояние
var _current_level: int = 0  # 0..4 (5 уровней)
var _sequence: Array = []     # массив индексов цветов
var _player_input: Array = [] # что нажал игрок
var _is_showing: bool = false # показываем ли последовательность
var _is_accepting_input: bool = false
var _input_index: int = 0
var _is_completed: bool = false

# Узлы
var _back_button: Button = null
var _title_label: TextureRect = null
var _level_label: TextureRect = null
var _status_label: TextureRect = null
var _level_digits: Control = null
var _level_total_digits: Control = null
var _buttons: Array = []       # массив словарей кнопок
var _completion_overlay: ColorRect = null
var _show_timer: Timer = null


func _ready() -> void:
	# difficulty присваивается из SceneManager уже после _ready, поэтому читаем напрямую.
	difficulty = SceneManager.get_pending_difficulty()
	_levels_to_complete = clampi(difficulty + 1, 2, LEVEL_STEPS.size())
	_configure_viewport()
	_build_background()
	_build_back_button()
	_build_title()
	_build_level_label()
	_build_status_label()
	_build_color_buttons()
	_build_completion_overlay()
	_start_level()


func _configure_viewport() -> void:
	DisplayHelper.setup_design_root(self)

func _build_background() -> void:
	MiniGameArt.build_minigame_background(self, Color("#111427"), Color("#2a1b4d"), Color(1, 0.95, 0.7, 0.22), 9.5)


func _build_back_button() -> void:
	_back_button = MiniGameArt.make_picture_button("BackButton", MINI_BACK, Vector2(120, 120), Vector2(24, 24), 100)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _build_title() -> void:
	_title_label = MiniGameArt.make_picture("TitleLabel", MINI_TITLE, Vector2(980, 140), Vector2(50, 146), 10)
	add_child(_title_label)


func _build_level_label() -> void:
	_level_label = MiniGameArt.make_picture("LevelLabel", LEVEL_LABEL, Vector2(340, 78), Vector2(228, 278), 10)
	add_child(_level_label)
	var of_label: TextureRect = MiniGameArt.make_picture("OfLabel", OF_LABEL, Vector2(120, 78), Vector2(538, 278), 10)
	add_child(of_label)
	_level_digits = Control.new()
	_level_digits.name = "LevelDigits"
	_level_digits.position = Vector2(572, 280)
	_level_digits.size = Vector2(60, 78)
	_level_digits.z_index = 10
	add_child(_level_digits)
	_level_total_digits = Control.new()
	_level_total_digits.name = "LevelTotalDigits"
	_level_total_digits.position = Vector2(670, 280)
	_level_total_digits.size = Vector2(60, 78)
	_level_total_digits.z_index = 10
	add_child(_level_total_digits)
	_update_level_picture()


func _build_status_label() -> void:
	_status_label = MiniGameArt.make_picture("StatusLabel", STATUS_WATCH, Vector2(700, 110), Vector2(190, 344), 10)
	add_child(_status_label)


func _render_digits(container: Control, text: String) -> void:
	MiniGameArt.render_digit_row(container, text, DIGIT_TEXTURES)


func _update_level_picture() -> void:
	if _level_digits == null or _level_total_digits == null:
		return
	_render_digits(_level_digits, str(_current_level + 1))
	_render_digits(_level_total_digits, str(_levels_to_complete))


func _set_status_picture(texture: Variant, width: float) -> void:
	if _status_label == null:
		return
	_status_label.texture = MiniGameArt.resolve_texture(texture)
	_status_label.size = Vector2(width, 110)
	_status_label.position.x = (1080.0 - width) / 2.0


func _build_color_buttons() -> void:
	# Размещаем кнопки в 2 ряда
	var start_y: float = 520.0
	var row1_y: float = start_y
	var row2_y: float = start_y + BUTTON_SIZE + BUTTON_GAP

	# Первый ряд: 3 кнопки
	var row1_width: float = 3 * BUTTON_SIZE + 2 * BUTTON_GAP
	var row1_start_x: float = (1080.0 - row1_width) / 2.0

	# Второй ряд: 2 кнопки
	var row2_width: float = 2 * BUTTON_SIZE + BUTTON_GAP
	var row2_start_x: float = (1080.0 - row2_width) / 2.0

	var button_positions: Array = [
		Vector2(row1_start_x, row1_y),
		Vector2(row1_start_x + BUTTON_SIZE + BUTTON_GAP, row1_y),
		Vector2(row1_start_x + 2 * (BUTTON_SIZE + BUTTON_GAP), row1_y),
		Vector2(row2_start_x, row2_y),
		Vector2(row2_start_x + BUTTON_SIZE + BUTTON_GAP, row2_y),
	]

	for i in range(NUM_BUTTONS):
		var btn_container = Control.new()
		btn_container.name = "ColorBtn_" + str(i)
		btn_container.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn_container.position = button_positions[i]
		btn_container.z_index = 5
		add_child(btn_container)

		var btn_rect := TextureRect.new()
		btn_rect.name = "BtnRect"
		btn_rect.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn_rect.position = Vector2.ZERO
		btn_rect.texture = MiniGameArt.resolve_texture(BUTTON_TEXTURES[i])
		btn_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btn_rect.stretch_mode = TextureRect.STRETCH_SCALE
		btn_container.add_child(btn_rect)

		# Прозрачная кнопка поверх для обработки нажатий
		var btn = Button.new()
		btn.name = "Btn"
		btn.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn.position = Vector2.ZERO
		btn.z_index = 10
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE

		var transparent_normal = StyleBoxFlat.new()
		transparent_normal.bg_color = Color(1, 1, 1, 0.0)
		btn.add_theme_stylebox_override("normal", transparent_normal)
		var transparent_hover = StyleBoxFlat.new()
		transparent_hover.bg_color = Color(1, 1, 1, 0.0)
		btn.add_theme_stylebox_override("hover", transparent_hover)
		var transparent_pressed = StyleBoxFlat.new()
		transparent_pressed.bg_color = Color(1, 1, 1, 0.0)
		btn.add_theme_stylebox_override("pressed", transparent_pressed)

		btn.pressed.connect(_on_color_button_pressed.bind(i))
		btn.disabled = true  # пока не покажем последовательность
		btn_container.add_child(btn)

		_buttons.append({
			"container": btn_container,
			"rect": btn_rect,
			"button": btn,
			"color_idx": i
		})


func _build_completion_overlay() -> void:
	_completion_overlay = ColorRect.new()
	_completion_overlay.name = "CompletionOverlay"
	_completion_overlay.size = Vector2(1080, 1920)
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.color = Color(0, 0, 0, 0.0)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completion_overlay.z_index = 200
	_completion_overlay.visible = false
	add_child(_completion_overlay)


func _start_level() -> void:
	if _is_completed or not is_inside_tree():
		return
	# Сбрасываем состояние
	_input_index = 0
	_player_input.clear()
	_is_accepting_input = false
	_is_showing = true

	# Обновляем интерфейс
	_update_level_picture()
	_set_status_picture(STATUS_WATCH, 700)

	# Блокируем кнопки
	for btn_data in _buttons:
		btn_data["button"].disabled = true

	# Генерируем последовательность
	_generate_sequence()

	# Запускаем показ
	_show_sequence()


func _generate_sequence() -> void:
	_sequence.clear()
	var steps: int = LEVEL_STEPS[_current_level]
	for i in range(steps):
		_sequence.append(randi() % NUM_BUTTONS)


func _show_sequence() -> void:
	if _sequence.is_empty():
		return

	# Показываем последовательность с интервалом 1.0 сек
	var delay: float = 0.0
	var interval: float = 1.0

	for i in range(_sequence.size()):
		var color_idx: int = _sequence[i]
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(_highlight_button.bind(color_idx, interval))
		delay += interval + 0.2

	# После показа — разрешаем ввод
	var finish_timer = get_tree().create_timer(delay)
	finish_timer.timeout.connect(_on_sequence_shown)


func _highlight_button(color_idx: int, duration: float) -> void:
	if _is_completed or not is_inside_tree():
		return

	var btn_data = _buttons[color_idx]
	# Подсвечиваем кнопку
	btn_data["rect"].texture = MiniGameArt.resolve_texture(BUTTON_ACTIVE_TEXTURES[color_idx])

	# Анимация увеличения
	var tween = create_tween()
	tween.tween_property(btn_data["container"], "scale", Vector2(1.25, 1.25), 0.15)
	tween.tween_property(btn_data["container"], "scale", Vector2(1.0, 1.0), 0.15)

	# Возвращаем исходный цвет через duration
	var reset_timer = get_tree().create_timer(duration)
	reset_timer.timeout.connect(_reset_button_color.bind(color_idx))


func _reset_button_color(color_idx: int) -> void:
	if _is_completed or not is_inside_tree():
		return

	var btn_data = _buttons[color_idx]
	btn_data["rect"].texture = MiniGameArt.resolve_texture(BUTTON_TEXTURES[color_idx])


func _on_sequence_shown() -> void:
	if _is_completed or not is_inside_tree():
		return
	_is_showing = false
	_is_accepting_input = true
	_input_index = 0

	_set_status_picture(STATUS_REPEAT, 560)

	# Разблокируем кнопки
	for btn_data in _buttons:
		btn_data["button"].disabled = false


func _on_color_button_pressed(color_idx: int) -> void:
	if not _is_accepting_input or _is_showing or _is_completed:
		return

	# Визуальная обратная связь нажатия
	var btn_data = _buttons[color_idx]
	var tween = create_tween()
	tween.tween_property(btn_data["container"], "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(btn_data["container"], "scale", Vector2(1.0, 1.0), 0.08)

	# Временная подсветка
	btn_data["rect"].texture = MiniGameArt.resolve_texture(BUTTON_ACTIVE_TEXTURES[color_idx])
	var reset_timer = get_tree().create_timer(0.2)
	reset_timer.timeout.connect(_reset_button_color.bind(color_idx))

	# Проверяем правильность
	if color_idx == _sequence[_input_index]:
		# Правильно!
		var _audio_step = get_node_or_null("/root/AudioManager")
		if _audio_step and _audio_step.has_method("play_sfx"):
			_audio_step.play_sfx("shard")
		_input_index += 1

		if _input_index >= _sequence.size():
			# Последовательность полностью повторена!
			_is_accepting_input = false
			_on_sequence_complete()
	else:
		# Ошибка!
		_is_accepting_input = false
		_on_sequence_failed()


func _on_sequence_complete() -> void:
	_set_status_picture(STATUS_SUCCESS, 460)

	_play_success_sound()

	# Переходим на следующий уровень
	_current_level += 1

	if _current_level >= _levels_to_complete:
		# Все уровни пройдены!
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(_on_all_levels_complete)
	else:
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(_start_level)


func _on_sequence_failed() -> void:
	_set_status_picture(STATUS_FAIL, 720)

	_play_error_sound()

	# Повторяем ту же последовательность
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(_start_level)


func _on_all_levels_complete() -> void:
	if not is_inside_tree():
		return
	_is_completed = true
	_play_success_sound()
	JuiceManager.celebrate_at(DisplayHelper.center(), self)
	MinigameCompletion.present(self, MINI_COMPLETE, Callable(self, "_on_completion_finished"), 4.0, 10)


func _play_success_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("complete")


func _play_error_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("wrong")


func _on_completion_finished() -> void:
	MinigameCompletion.emit_game_completed(self, world_id, game_id)


func _on_back_pressed() -> void:
	if not _is_completed:
		SceneManager.goto_world(world_id)
