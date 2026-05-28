extends Control

## Overlay settings: sound/music volume sliders; writes into GameState + SaveManager.

signal settings_closed
signal sound_volume_changed(value: float)
signal music_volume_changed(value: float)

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")

@onready var overlay = $Overlay
@onready var settings_panel = $SettingsPanel
@onready var sound_slider = $SettingsPanel/SoundSlider
@onready var music_slider = $SettingsPanel/MusicSlider
@onready var close_button = $SettingsPanel/CloseButton
@onready var title_label = $SettingsPanel/TitleLabel
@onready var sound_label = $SettingsPanel/SoundLabel
@onready var music_label = $SettingsPanel/MusicLabel

func _ready():
	DisplayHelper.fill_control(self)
	DisplayHelper.make_button_clickable(close_button)
	_replace_labels_with_art()
	_connect_signals()
	_load_settings()
	_setup_enter_animation()


func _replace_labels_with_art() -> void:
	if title_label:
		title_label.visible = false
		settings_panel.add_child(
			MiniGameArt.make_text_art(
				"TitleArt", "Настройки",
				Vector2(320, 70), Vector2(140, 28),
				{"font_size": 40, "font_color": Color(1, 0.92, 0.55), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 3}
			)
		)
	if sound_label:
		sound_label.visible = false
		settings_panel.add_child(
			MiniGameArt.make_text_art(
				"SoundArt", "Звук",
				Vector2(220, 60), Vector2(60, 144),
				{"font_size": 32, "font_color": Color(0.95, 0.97, 1.0), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2, "halign": HORIZONTAL_ALIGNMENT_LEFT}
			)
		)
	if music_label:
		music_label.visible = false
		settings_panel.add_child(
			MiniGameArt.make_text_art(
				"MusicArt", "Музыка",
				Vector2(220, 60), Vector2(60, 344),
				{"font_size": 32, "font_color": Color(0.95, 0.97, 1.0), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2, "halign": HORIZONTAL_ALIGNMENT_LEFT}
			)
		)
	var close_label := close_button.get_node_or_null("CloseLabel")
	if close_label:
		close_label.visible = false
	close_button.add_child(
		MiniGameArt.make_text_art(
			"CloseArt", "Закрыть",
			close_button.size, Vector2.ZERO,
			{"font_size": 34, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.2, 0.05, 0.05, 1), "outline_size": 3}
		)
	)

func _connect_signals():
	close_button.pressed.connect(_on_close_pressed)
	sound_slider.value_changed.connect(_on_sound_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)

func _setup_enter_animation():
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	settings_panel.scale = Vector2(0.8, 0.8)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(settings_panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _load_settings():
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		var sound_vol = game_state.settings.get("sound_volume", 80.0)
		var music_vol = game_state.settings.get("music_volume", 60.0)
		sound_slider.value = sound_vol
		music_slider.value = music_vol
	else:
		sound_slider.value = 80.0
		music_slider.value = 60.0

func _on_sound_volume_changed(value: float):
	emit_signal("sound_volume_changed", value)
	_save_setting("sound_volume", value)

	if has_node("/root/AudioManager"):
		AudioManager.set_sound_vol(value / 100.0)

func _on_music_volume_changed(value: float):
	emit_signal("music_volume_changed", value)
	_save_setting("music_volume", value)

	if has_node("/root/AudioManager"):
		AudioManager.set_music_vol(value / 100.0)

func _save_setting(key: String, value: float):
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		game_state.settings[key] = value
		if has_node("/root/SaveManager"):
			SaveManager.save_game(game_state.current_save_slot)

func _on_close_pressed():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(settings_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		emit_signal("settings_closed")
		queue_free()
	)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Close if tapping on overlay
		var pos = get_local_mouse_position()
		var panel_rect = Rect2(settings_panel.position, settings_panel.size)
		if not panel_rect.has_point(pos):
			_on_close_pressed()
