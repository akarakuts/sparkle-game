extends 'res://scripts/worlds/WorldBase.gd'

## World 6 — Dreamlands (Drawing uses Line2D stroke limit).

var _drawing_canvas: ColorRect
var _current_color: Color = Color.WHITE
var _brush_size: float = 12.0
var _is_drawing: bool = false
var _last_draw_pos: Vector2
var _sticker_buttons: Array = []

const StrokeCanvas := preload("res://scripts/minigames/StrokeCanvas.gd")
const MAX_STROKES: int = 64 # Защита от OOM на слабых устройствах.
var _current_stroke: Line2D = null
var _strokes: Array[Line2D] = []

func _ready():
	world_id = 6
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	# Background: purple-pink gradient with shimmer
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#2a0a3a"), Color("#6a2a5a"))
	
	# Atmosphere: stars and fog (purple-white particles)
	_make_particles({
		amount = 40,
		lifetime = 6.0,
		spread = 360.0,
		vel_min = 3.0,
		vel_max = 12.0,
		scale_min = 0.2,
		scale_max = 0.8,
		color = Color("#ddaaff")
	})
	
	# Drawing canvas — transparent, covers most of the screen
	_drawing_canvas = ColorRect.new()
	_drawing_canvas.name = "DrawingCanvas"
	_drawing_canvas.size = Vector2(980, 1200)
	_drawing_canvas.position = Vector2(50, 120)
	_drawing_canvas.color = Color(1, 1, 1, 0.05)
	var canvas_style = StyleBoxFlat.new()
	canvas_style.bg_color = Color(1, 1, 1, 0.08)
	canvas_style.corner_radius_top_left = 16
	canvas_style.corner_radius_top_right = 16
	canvas_style.corner_radius_bottom_left = 16
	canvas_style.corner_radius_bottom_right = 16
	_drawing_canvas.add_theme_stylebox_override("normal", canvas_style)
	add_child(_drawing_canvas)
	
	# GuiInput for drawing on canvas
	_drawing_canvas.gui_input.connect(_on_canvas_input)
	
	# Color palette — 10 color circles (ColorRect buttons)
	var palette_colors = [
		Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN,
		Color.BLUE, Color("#aa00ff"), Color("#ff00ff"), Color.WHITE, Color.BLACK
	]
	var palette_x_start = 90
	var palette_y = 1360
	for i in range(palette_colors.size()):
		var color_btn = ColorRect.new()
		color_btn.name = "ColorBtn" + str(i)
		color_btn.size = Vector2(50, 50)
		color_btn.position = Vector2(palette_x_start + i * 70, palette_y)
		color_btn.color = palette_colors[i]
		color_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		# Round shape via style
		var cstyle = StyleBoxFlat.new()
		cstyle.bg_color = palette_colors[i]
		cstyle.corner_radius_top_left = 25
		cstyle.corner_radius_top_right = 25
		cstyle.corner_radius_bottom_left = 25
		cstyle.corner_radius_bottom_right = 25
		color_btn.add_theme_stylebox_override("normal", cstyle)
		# Hover effect
		var cstyle_hover = StyleBoxFlat.new()
		cstyle_hover.bg_color = palette_colors[i].lightened(0.3)
		cstyle_hover.corner_radius_top_left = 25
		cstyle_hover.corner_radius_top_right = 25
		cstyle_hover.corner_radius_bottom_left = 25
		cstyle_hover.corner_radius_bottom_right = 25
		color_btn.add_theme_stylebox_override("hover", cstyle_hover)
		color_btn.gui_input.connect(_on_palette_color_pressed.bind(i))
		add_child(color_btn)
	
	# Sticker buttons: stars, hearts, flowers
	var sticker_data = [
		{"text": "⭐", "name": "StarSticker"},
		{"text": "❤️", "name": "HeartSticker"},
		{"text": "🌸", "name": "FlowerSticker"},
	]
	for i in range(sticker_data.size()):
		var sb = sticker_data[i]
		var sticker = Button.new()
		sticker.name = sb["name"]
		sticker.size = Vector2(60, 60)
		sticker.position = Vector2(90 + i * 80, 1450)
		
		var s_lbl = Label.new()
		s_lbl.text = sb["text"]
		s_lbl.size = Vector2(60, 60)
		s_lbl.position = Vector2.ZERO
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s_lbl.add_theme_font_size_override("font_size", 28)
		sticker.add_child(s_lbl)
		
		var st_style = StyleBoxFlat.new()
		st_style.bg_color = Color(1, 1, 1, 0.2)
		st_style.corner_radius_top_left = 8
		st_style.corner_radius_top_right = 8
		st_style.corner_radius_bottom_left = 8
		st_style.corner_radius_bottom_right = 8
		sticker.add_theme_stylebox_override("normal", st_style)
		
		sticker.pressed.connect(_place_sticker.bind(sb["text"]))
		add_child(sticker)
	
	# Clear button
	var clear_btn = Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.size = Vector2(120, 50)
	clear_btn.position = Vector2(870, 1360)
	
	var clear_lbl = Label.new()
	clear_lbl.text = "Очистить"
	clear_lbl.size = Vector2(120, 50)
	clear_lbl.position = Vector2.ZERO
	clear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_lbl.add_theme_font_size_override("font_size", 20)
	clear_btn.add_child(clear_lbl)
	
	var clear_style = StyleBoxFlat.new()
	clear_style.bg_color = Color(1, 0.3, 0.3, 0.6)
	clear_style.corner_radius_top_left = 8
	clear_style.corner_radius_top_right = 8
	clear_style.corner_radius_bottom_left = 8
	clear_style.corner_radius_bottom_right = 8
	clear_btn.add_theme_stylebox_override("normal", clear_style)
	
	var clear_style_h = StyleBoxFlat.new()
	clear_style_h.bg_color = Color(1, 0.5, 0.5, 0.8)
	clear_style_h.corner_radius_top_left = 8
	clear_style_h.corner_radius_top_right = 8
	clear_style_h.corner_radius_bottom_left = 8
	clear_style_h.corner_radius_bottom_right = 8
	clear_btn.add_theme_stylebox_override("hover", clear_style_h)
	
	clear_btn.pressed.connect(_clear_canvas)
	add_child(clear_btn)
	
	# Minigame button (Drawing)
	const MINIGAME_BUTTON_POSITIONS := [Vector2(540, 280)]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("💎", Vector2(540, 1550))
	_make_tappable_flower("🌙", Vector2(200, 700))
	_make_tappable_flower("💫", Vector2(880, 650))

# ── Drawing logic ─────────────────────────────────────────────────

func _on_canvas_input(event: InputEvent) -> void:
	# В gui_input event.position уже в локальных координатах канваса.
	if event is InputEventScreenTouch:
		if event.pressed:
			_is_drawing = true
			_begin_stroke(event.position)
		else:
			_is_drawing = false
			_current_stroke = null

	if event is InputEventScreenDrag and _is_drawing:
		_extend_stroke(event.position)


func _begin_stroke(pos: Vector2) -> void:
	_current_stroke = StrokeCanvas.begin_stroke(_drawing_canvas, _current_color, _brush_size, pos)
	_last_draw_pos = pos
	_strokes.append(_current_stroke)
	# Удаляем самые старые штрихи, чтобы не плодить узлы бесконечно.
	while _strokes.size() > MAX_STROKES:
		var old: Line2D = _strokes.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _extend_stroke(pos: Vector2) -> void:
	if _current_stroke == null or not is_instance_valid(_current_stroke):
		return
	StrokeCanvas.extend_stroke(_current_stroke, pos)
	if _current_stroke.get_point_count() > 0:
		_last_draw_pos = _current_stroke.get_point_position(_current_stroke.get_point_count() - 1)

func _on_palette_color_pressed(event: InputEvent, index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var palette_colors = [
			Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN,
			Color.BLUE, Color("#aa00ff"), Color("#ff00ff"), Color.WHITE, Color.BLACK
		]
		_current_color = palette_colors[index]

func _place_sticker(emoji: String) -> void:
	# Place sticker near center of canvas or wherever user tapped last
	var sticker = Label.new()
	sticker.text = emoji
	sticker.size = Vector2(60, 60)
	var center = _drawing_canvas.size * 0.5
	center.x += randf_range(-100, 100)
	center.y += randf_range(-100, 100)
	sticker.position = center
	sticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sticker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sticker.add_theme_font_size_override("font_size", 36)
	sticker.name = "Sticker"
	_drawing_canvas.add_child(sticker)

func _clear_canvas() -> void:
	for child in _drawing_canvas.get_children():
		child.queue_free()
	_strokes.clear()
	_current_stroke = null
	_is_drawing = false
