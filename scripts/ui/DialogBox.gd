extends Control

## Modal speech bubble for Sparkle (emotion glyphs, optional auto-close).

signal dialog_closed

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")

const EMOTION_MAP = {
	"happy": ":)",
	"sad": ":(",
	"think": "?",
	"celebrate": "!!",
	"surprise": "?!",
	"love": "<3",
	"angry": "!!",
	"tired": "zZ",
	"excited": "!!",
	"scared": "!!"
}

const ACTION_MAP = {
	"point": "->",
	"collect": "+",
	"wait": "...",
	"tap": "OK",
	"swipe": "->",
	"listen": "сл",
	"look": "см",
	"jump": "^",
	"talk": "...",
	"done": "OK"
}

@onready var background_overlay = $BackgroundOverlay
@onready var dialog_panel = $DialogPanel
@onready var emotion_texture = $DialogPanel/EmotionTexture
@onready var emotion_label = $DialogPanel/EmotionTexture/EmotionLabel
@onready var action_icon = $DialogPanel/ActionIcon
@onready var action_label = $DialogPanel/ActionIcon/ActionLabel
@onready var next_button = $DialogPanel/NextButton
@onready var next_arrow_label = $DialogPanel/NextButton/NextArrowLabel
@onready var auto_close_timer = $AutoCloseTimer

var _message_label: Control = null
var _sparkle_badge: Control = null
var _emotion_art: Control = null
var _action_art: Control = null
var bounce_tween: Tween


func _ready():
	hide()
	_build_message_label()
	DisplayHelper.make_button_clickable(next_button)
	next_arrow_label.visible = false
	var next_art := MiniGameArt.make_text_art(
		"NextArrowArt", ">",
		next_button.size, Vector2.ZERO,
		{"font_size": DisplayHelper.scale_font(42), "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.1, 0.1, 0.25, 1), "outline_size": 3}
	)
	next_button.add_child(next_art)
	_connect_signals()
	_setup_next_button_animation()
	_style_panel()


func _build_message_label() -> void:
	_sparkle_badge = MiniGameArt.make_text_art(
		"SparkleBadge", "Искорка",
		Vector2(800, 44), Vector2(0, -36),
		{"font_size": DisplayHelper.scale_font(28), "font_color": Color(1, 0.92, 0.5), "outline_color": Color(0.15, 0.15, 0.3, 1), "outline_size": 2}
	)
	dialog_panel.add_child(_sparkle_badge)

	_message_label = MiniGameArt.make_text_art(
		"MessageLabel", "",
		Vector2(720, 120), Vector2(40, 180),
		{
			"font_size": DisplayHelper.scale_font(32),
			"font_color": Color(0.95, 0.97, 1.0),
			"outline_color": Color(0.1, 0.1, 0.25, 1),
			"outline_size": 2,
			"autowrap": TextServer.AUTOWRAP_WORD_SMART
		}
	)
	dialog_panel.add_child(_message_label)

	emotion_label.visible = false
	_emotion_art = MiniGameArt.make_text_art(
		"EmotionArt", "",
		emotion_texture.size, Vector2.ZERO,
		{"font_size": DisplayHelper.scale_font(28), "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.1, 0.1, 0.25, 1), "outline_size": 2}
	)
	emotion_texture.add_child(_emotion_art)

	action_label.visible = false
	_action_art = MiniGameArt.make_text_art(
		"ActionArt", "",
		action_icon.size, Vector2.ZERO,
		{"font_size": DisplayHelper.scale_font(24), "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.1, 0.1, 0.25, 1), "outline_size": 2}
	)
	action_icon.add_child(_action_art)


func _style_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.28, 0.92)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.5, 0.7, 1.0, 0.6)
	panel_style.corner_radius_top_left = 24
	panel_style.corner_radius_top_right = 24
	panel_style.corner_radius_bottom_left = 24
	panel_style.corner_radius_bottom_right = 24
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 12
	dialog_panel.add_theme_stylebox_override("panel", panel_style)


func _connect_signals():
	next_button.pressed.connect(_on_next_pressed)
	background_overlay.gui_input.connect(_on_overlay_input)
	auto_close_timer.timeout.connect(_on_auto_close_timeout)


func _setup_next_button_animation():
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	bounce_tween = create_tween().set_loops()
	bounce_tween.tween_property(next_button, "scale", Vector2(1.15, 1.15), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bounce_tween.tween_property(next_button, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func show_message(text: String, emotion: String = "happy", action_icon_key: String = "talk", auto_close: bool = false):
	if _message_label:
		MiniGameArt.set_text_art(_message_label, text)
	show_dialog(emotion, action_icon_key, auto_close)


func show_dialog(emotion: String, action_icon_key: String, auto_close: bool = false):
	var emotion_char = EMOTION_MAP.get(emotion, "😊")
	MiniGameArt.set_text_art(_emotion_art, emotion_char)

	var action_char = ACTION_MAP.get(action_icon_key, "👆")
	MiniGameArt.set_text_art(_action_art, action_char)

	modulate = Color(1.0, 1.0, 1.0, 0.0)
	dialog_panel.scale = Vector2(0.8, 0.8)
	show()
	z_index = 200

	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("dialog")

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(dialog_panel, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.8, 0.8)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if auto_close:
		auto_close_timer.wait_time = max(3.0, float(text_length_seconds()))
		auto_close_timer.start()


func text_length_seconds() -> float:
	if _message_label == null:
		return 3.0
	var label := _message_label.get_node_or_null("Viewport/Label") as Label
	if label == null:
		return 3.0
	return clampf(float(label.text.length()) * 0.06, 2.5, 8.0)


func hide_dialog():
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(dialog_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		hide()
		auto_close_timer.stop()
		emit_signal("dialog_closed")
	)


func _on_next_pressed():
	if auto_close_timer.is_stopped():
		hide_dialog()
	else:
		auto_close_timer.stop()
		hide_dialog()


func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pass


func _on_auto_close_timeout():
	hide_dialog()


func _exit_tree():
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
