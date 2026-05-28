extends Control

## Drawing — finger painting on a canvas; Dreamlands caps stroke count via Line2D.

signal game_completed(world_id: int, game_id: int)

# Идентификаторы (заполняются извне)
var world_id: int = 0
var game_id: int = 0

# Конфигурация
const CANVAS_SIZE: Vector2 = Vector2(940, 980)
const CANVAS_POS: Vector2 = Vector2(70, 260)
const BRUSH_SIZE: float = 12.0
const PALETTE_COLORS: Array = [
	Color("#e74c3c"),  # Красный
	Color("#e67e22"),  # Оранжевый
	Color("#f1c40f"),  # Жёлтый
	Color("#2ecc71"),  # Зелёный
	Color("#3498db"),  # Синий
	Color("#9b59b6"),  # Фиолетовый
	Color("#ff6b81"),  # Розовый
	Color("#34495e"),  # Тёмно-синий
]
const PALETTE_BUTTON_SIZE: float = 92.0
const PALETTE_GAP: float = 18.0
const MINI_BACK := "res://assets/graphics/ui/minigames/common/back_button.png"
const MINI_TITLE := "res://assets/graphics/ui/minigames/common/title_drawing.png"
const CLEAR_BUTTON_TEX := "res://assets/graphics/ui/minigames/common/clear_button.png"
const DONE_BUTTON_TEX := "res://assets/graphics/ui/minigames/common/done_button.png"
const MINI_COMPLETE := "res://assets/graphics/ui/minigames/common/complete_drawing.png"
const PALETTE_SWATCHES := [
	"res://assets/graphics/ui/minigames/drawing/swatch_0.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_1.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_2.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_3.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_4.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_5.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_6.png",
	"res://assets/graphics/ui/minigames/drawing/swatch_7.png",
]
const PALETTE_SELECTED_RING := "res://assets/graphics/ui/minigames/drawing/selected_ring.png"
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MinigameCompletion := preload("res://scripts/ui/MinigameCompletion.gd")

# Внутреннее состояние
var _current_color: Color = PALETTE_COLORS[0]
var _is_drawing: bool = false
var _is_completed: bool = false

# Узлы рисования — используем Line2D для каждой линии
var _current_line: Line2D = null
var _canvas_container: Control = null
var _canvas_bg: ColorRect = null
var _palette_container: Control = null
var _clear_button: Button = null
var _done_button: Button = null
var _back_button: Button = null
var _color_indicators: Array = []  # индикаторы выбранного цвета

# История линий для undo
var _lines: Array = []
var _active_touch_id: int = -1


func _ready() -> void:
	_configure_viewport()
	_build_background()
	_build_back_button()
	_build_title()
	_build_canvas()
	_build_palette()
	_build_action_buttons()


func _configure_viewport() -> void:
	DisplayHelper.setup_design_root(self)

func _build_background() -> void:
	MiniGameArt.build_minigame_background(self, Color("#10182b"), Color("#2b2a55"), Color(1, 0.95, 0.7, 0.20), 8.5)


func _build_back_button() -> void:
	_back_button = MiniGameArt.make_picture_button("BackButton", MINI_BACK, Vector2(120, 120), Vector2(24, 24), 100)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _build_title() -> void:
	var title_label: TextureRect = MiniGameArt.make_picture("TitleLabel", MINI_TITLE, Vector2(980, 140), Vector2(50, 146), 10)
	add_child(title_label)


func _build_canvas() -> void:
	# Контейнер для канваса
	_canvas_container = Control.new()
	_canvas_container.name = "CanvasContainer"
	_canvas_container.size = CANVAS_SIZE
	_canvas_container.position = CANVAS_POS
	_canvas_container.z_index = 5
	_canvas_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas_container)

	# Белый фон холста
	_canvas_bg = ColorRect.new()
	_canvas_bg.name = "CanvasBg"
	_canvas_bg.size = CANVAS_SIZE
	_canvas_bg.position = Vector2.ZERO
	_canvas_bg.color = Color(1, 1, 1, 1.0)
	_canvas_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Стиль — рамка
	var canvas_style = StyleBoxFlat.new()
	canvas_style.bg_color = Color(1, 1, 1, 1.0)
	canvas_style.corner_radius_top_left = 22
	canvas_style.corner_radius_top_right = 22
	canvas_style.corner_radius_bottom_left = 22
	canvas_style.corner_radius_bottom_right = 22
	canvas_style.border_width_top = 3
	canvas_style.border_width_bottom = 3
	canvas_style.border_width_left = 3
	canvas_style.border_width_right = 3
	canvas_style.border_color = Color(0.7, 0.75, 0.95, 0.6)
	canvas_style.shadow_color = Color(0, 0, 0, 0.25)
	canvas_style.shadow_size = 14
	_canvas_bg.add_theme_stylebox_override("normal", canvas_style)
	_canvas_container.add_child(_canvas_bg)

	# Перехватываем ввод на контейнере
	_canvas_container.gui_input.connect(_on_canvas_input)


func _build_palette() -> void:
	_palette_container = Control.new()
	_palette_container.name = "PaletteContainer"
	_palette_container.size = Vector2(1080, 140)
	_palette_container.position = Vector2(0, 1290)
	_palette_container.z_index = 10
	add_child(_palette_container)

	var total_width: float = PALETTE_COLORS.size() * PALETTE_BUTTON_SIZE + (PALETTE_COLORS.size() - 1) * PALETTE_GAP
	var start_x: float = (1080.0 - total_width) / 2.0

	for i in range(PALETTE_COLORS.size()):
		var btn_pos_x: float = start_x + i * (PALETTE_BUTTON_SIZE + PALETTE_GAP)
		var btn_pos_y: float = 10.0

		# Контейнер для кнопки цвета + индикатор
		var color_btn: Button = MiniGameArt.make_picture_button("ColorBtn_" + str(i), PALETTE_SWATCHES[i], Vector2(PALETTE_BUTTON_SIZE, PALETTE_BUTTON_SIZE), Vector2(btn_pos_x, btn_pos_y), 5)
		color_btn.pressed.connect(_on_color_selected.bind(i))
		_palette_container.add_child(color_btn)

		var indicator: TextureRect = MiniGameArt.make_picture("Indicator_" + str(i), PALETTE_SELECTED_RING, Vector2(PALETTE_BUTTON_SIZE + 16, PALETTE_BUTTON_SIZE + 16), Vector2(btn_pos_x - 8, btn_pos_y - 8), 4)
		indicator.name = "Indicator_" + str(i)
		indicator.visible = (i == 0)
		_palette_container.add_child(indicator)
		_color_indicators.append(indicator)


func _build_action_buttons() -> void:
	# Кнопка "Очистить"
	_clear_button = MiniGameArt.make_picture_button("ClearButton", CLEAR_BUTTON_TEX, Vector2(260, 96), Vector2(100, 1490), 10)
	_clear_button.pressed.connect(_on_clear_pressed)
	add_child(_clear_button)

	_done_button = MiniGameArt.make_picture_button("DoneButton", DONE_BUTTON_TEX, Vector2(260, 96), Vector2(720, 1490), 10)
	_done_button.pressed.connect(_on_done_pressed)
	add_child(_done_button)


# ── Рисование ─────────────────────────────────────────────────────

func _canvas_local_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	var viewport_pos: Vector2 = event.position
	return _canvas_container.get_global_transform().affine_inverse() * viewport_pos


func _add_canvas_point(local_pos: Vector2) -> void:
	if _current_line == null:
		return
	local_pos.x = clamp(local_pos.x, 0, CANVAS_SIZE.x)
	local_pos.y = clamp(local_pos.y, 0, CANVAS_SIZE.y)
	if _current_line.points.size() > 0:
		var last_point: Vector2 = _current_line.points[-1]
		if last_point.distance_to(local_pos) < 3.0:
			return
	_current_line.add_point(local_pos)


func _on_canvas_input(event: InputEvent) -> void:
	if _is_completed:
		return

	if event is InputEventScreenTouch:
		var local_pos := _canvas_local_pos(event)
		if event.pressed:
			_active_touch_id = event.index
			_start_new_line(local_pos)
		elif event.index == _active_touch_id:
			_finish_current_line()
			_active_touch_id = -1
	elif event is InputEventScreenDrag and event.index == _active_touch_id and _is_drawing:
		_add_canvas_point(_canvas_local_pos(event))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := _canvas_local_pos(event)
		if event.pressed:
			_start_new_line(local_pos)
		else:
			_finish_current_line()
	elif event is InputEventMouseMotion and _is_drawing and _current_line != null:
		_add_canvas_point(_canvas_local_pos(event))


func _start_new_line(pos: Vector2) -> void:
	_is_drawing = true

	# Создаём новую Line2D
	_current_line = Line2D.new()
	_current_line.name = "Line_" + str(_lines.size())
	_current_line.default_color = _current_color
	_current_line.width = BRUSH_SIZE
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.antialiased = true
	_current_line.z_index = 10

	# Ограничиваем позицию
	var clamped_pos: Vector2 = pos
	clamped_pos.x = clamp(clamped_pos.x, 0, CANVAS_SIZE.x)
	clamped_pos.y = clamp(clamped_pos.y, 0, CANVAS_SIZE.y)

	_current_line.add_point(clamped_pos)
	_canvas_container.add_child(_current_line)
	_lines.append(_current_line)


func _finish_current_line() -> void:
	_is_drawing = false
	_current_line = null


func _on_color_selected(color_idx: int) -> void:
	if _is_completed:
		return

	_current_color = PALETTE_COLORS[color_idx]

	# Обновляем индикатор выбора
	for i in range(_color_indicators.size()):
		_color_indicators[i].visible = (i == color_idx)

	# Визуальная обратная связь
	var tween = create_tween()
	var btn = _palette_container.get_node_or_null("ColorBtn_" + str(color_idx))
	if btn:
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.1)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)


func _on_clear_pressed() -> void:
	if _is_completed:
		return

	# Удаляем все линии
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	_current_line = null
	_is_drawing = false

	# Анимация вспышки на холсте
	var flash = ColorRect.new()
	flash.name = "ClearFlash"
	flash.size = CANVAS_SIZE
	flash.position = Vector2.ZERO
	flash.color = Color(1, 1, 1, 0.5)
	flash.z_index = 20
	_canvas_container.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _on_done_pressed() -> void:
	if _is_completed:
		return

	_is_completed = true
	_canvas_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _done_button:
		_done_button.disabled = true
	if _clear_button:
		_clear_button.disabled = true

	_play_success_sound()
	JuiceManager.celebrate_at(DisplayHelper.center(), self)
	MinigameCompletion.present(self, MINI_COMPLETE, Callable(self, "_on_completion_finished"))


func _play_success_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("complete")


func _on_completion_finished() -> void:
	MinigameCompletion.emit_game_completed(self, world_id, game_id)


func _on_back_pressed() -> void:
	if not _is_completed:
		SceneManager.goto_world(world_id)
