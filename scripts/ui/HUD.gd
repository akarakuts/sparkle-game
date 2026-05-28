extends CanvasLayer

## In-world HUD: pause, bottom progress bar; shard-style counter hidden (crystal shards live on the map).

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const HUD_SHARD_ICON_TEX := "res://assets/graphics/ui/minigames/world/shard_icon.png"
const HUD_PAUSE_TEX := "res://assets/graphics/ui/minigames/world/pause_button.png"
const HUD_HINT_TEX := "res://assets/graphics/ui/minigames/world/hint_tap.png"
const HUD_PLUS_ONE_TEX := "res://assets/graphics/ui/minigames/world/plus_one.png"
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


signal pause_pressed
signal resume_pressed

@onready var shard_counter = $ShardCounter
@onready var shard_icon = $ShardCounter/ShardIcon
@onready var shard_label = $ShardCounter/ShardLabel
@onready var pause_button = $PauseButton
@onready var progress_bar = $ProgressBar
@onready var progress_fill = $ProgressBar/ProgressFill
@onready var hint_animation = $HintAnimation
@onready var hint_label = $HintAnimation/HintLabel
@onready var idle_timer = $IdleTimer
@onready var shard_collect_animation = $ShardCollectAnimation
@onready var shard_collect_label = $ShardCollectAnimation/ShardCollectLabel

var is_paused: bool = false
var current_shards: int = 0
var total_shards_in_world: int = 3
var _digit_container: Control = null

func _ready():
	DisplayHelper.make_button_clickable(pause_button)
	shard_icon.visible = false
	var shard_art := TextureRect.new()
	shard_art.name = "ShardIconArt"
	shard_art.texture = MiniGameArt.resolve_texture(HUD_SHARD_ICON_TEX)
	shard_art.custom_minimum_size = Vector2(68, 68)
	shard_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard_art.stretch_mode = TextureRect.STRETCH_SCALE
	shard_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard_counter.add_child(shard_art)
	shard_counter.move_child(shard_art, 0)
	shard_label.visible = false
	_digit_container = Control.new()
	_digit_container.name = "ShardDigits"
	_digit_container.position = Vector2(70, 10)
	_digit_container.custom_minimum_size = Vector2(120, 60)
	shard_counter.add_child(_digit_container)
	var pause_icon := pause_button.get_node_or_null("PauseIcon")
	if pause_icon:
		pause_icon.visible = false
	MiniGameArt.replace_picture(pause_button, "PauseArt", HUD_PAUSE_TEX, Vector2(100, 100))
	hint_label.visible = false
	MiniGameArt.replace_picture(hint_animation, "HintArt", HUD_HINT_TEX, Vector2(340, 96))
	var hint_art := hint_animation.get_node_or_null("HintArt")
	if hint_art is TextureRect:
		(hint_art as TextureRect).position = Vector2(370, 1160)
	shard_collect_label.visible = false
	MiniGameArt.replace_picture(shard_collect_animation, "PlusOneArt", HUD_PLUS_ONE_TEX, Vector2(160, 96))
	var plus_one_art := shard_collect_animation.get_node_or_null("PlusOneArt")
	if plus_one_art is TextureRect:
		(plus_one_art as TextureRect).position = Vector2(460, 860)
	# Safe-area: отступаем вниз от выреза/камеры.
	var insets := DisplayHelper.safe_area_insets()
	if insets.y > 0.0:
		shard_counter.position.y += insets.y
		pause_button.offset_top += insets.y
		pause_button.offset_bottom += insets.y

	# Счётчик с иконкой «✦» — прогресс мини-игр в мире, не кристаллические осколки.
	# Осколки кристалла видны на карте миров; здесь оставляем только полоску прогресса.
	shard_counter.visible = false
	_connect_signals()
	_update_shard_display(0)
	_setup_progress_bar(0.0)
	hint_animation.hide()
	shard_collect_animation.hide()

func _render_digits(count: int) -> void:
	if _digit_container == null:
		return
	for child in _digit_container.get_children():
		child.queue_free()
	var digits := str(count)
	var x := 0.0
	for i in range(digits.length()):
		var tex := MiniGameArt.make_picture("Digit_" + str(i), DIGIT_TEXTURES[int(digits.substr(i, 1))], Vector2(34, 52), Vector2(x, 0), 0)
		_digit_container.add_child(tex)
		x += 30.0


func _connect_signals():
	pause_button.pressed.connect(_on_pause_pressed)
	idle_timer.timeout.connect(_on_idle_timeout)

func _input(event):
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_reset_idle_timer()

func _reset_idle_timer():
	idle_timer.stop()
	idle_timer.start()
	if hint_animation.visible:
		_hide_hint_animation()

func _on_pause_pressed():
	is_paused = !is_paused
	if is_paused:
		emit_signal("pause_pressed")
		hide()
	else:
		emit_signal("resume_pressed")
		show()

func _on_idle_timeout():
	_show_hint_animation()

func _show_hint_animation():
	hint_animation.show()
	var tween = create_tween().set_loops()
	var target := hint_animation.get_node_or_null("HintArt")
	if target:
		tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 0.4), 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _hide_hint_animation():
	if hint_animation.is_inside_tree():
		var tween = create_tween()
		var target := hint_animation.get_node_or_null("HintArt")
		if target:
			tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
		tween.tween_callback(func(): hint_animation.hide())

func _update_shard_display(count: int):
	_render_digits(count)

func _setup_progress_bar(ratio: float):
	progress_fill.size.x = progress_bar.size.x * ratio
	var hue: float = lerpf(0.55, 0.35, ratio)
	progress_fill.color = Color.from_hsv(hue, 0.7, 1.0, 0.95)

func set_progress(ratio: float):
	ratio = clamp(ratio, 0.0, 1.0)
	progress_fill.size.x = progress_bar.size.x * ratio
	var hue: float = lerpf(0.55, 0.35, ratio)
	progress_fill.color = Color.from_hsv(hue, 0.7, 1.0, 0.95)

func on_shard_collected(new_total: int):
	current_shards = new_total
	_update_shard_display(new_total)
	_play_shard_collect_animation()

func _play_shard_collect_animation():
	shard_collect_animation.show()
	var plus_one_art := shard_collect_animation.get_node_or_null("PlusOneArt")
	if plus_one_art == null:
		return
	plus_one_art.position = Vector2(460, 860)
	plus_one_art.modulate = Color(1.0, 1.0, 1.0, 1.0)
	plus_one_art.scale = Vector2(0.5, 0.5)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(plus_one_art, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(plus_one_art, "position", plus_one_art.position + Vector2(0, -80), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(plus_one_art, "scale", Vector2(1.5, 1.5), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var hide_tween = create_tween()
	hide_tween.tween_interval(1.3)
	hide_tween.tween_callback(func(): shard_collect_animation.hide())

func set_world_shard_count(total: int):
	total_shards_in_world = total

func show_hint():
	_show_hint_animation()

func hide_hint():
	_hide_hint_animation()

func _hide():
	hide()

func _show():
	show()
