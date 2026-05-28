extends Control

## Main menu: title art, Play → world map, settings, parent gate, sticker album, Sparkle mascot.

signal play_pressed
signal settings_pressed
signal parent_gate_pressed

const SPARKLE_SCRIPT := preload("res://scripts/characters/SparkleCharacter.gd")
const StickerAlbumScript := preload("res://scripts/ui/StickerAlbum.gd")
const WOW_PLAY_TEX := preload("res://assets/graphics/ui/wow/buttons/btn_jelly_green.png")
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const MENU_TITLE_TEX := "res://assets/graphics/ui/minigames/menu/main_title.png"
const MENU_DESCRIPTION_TEX := "res://assets/graphics/ui/minigames/menu/main_description.png"
const MENU_PLAY_LABEL_TEX := "res://assets/graphics/ui/minigames/menu/play_label.png"
const MENU_SETTINGS_ICON_TEX := "res://assets/graphics/ui/minigames/menu/settings_icon.png"
const MENU_PARENT_ICON_TEX := "res://assets/graphics/ui/minigames/menu/parent_icon.png"
const MENU_ALBUM_ICON_TEX := "res://assets/graphics/ui/minigames/menu/album_icon.png"
@onready var background = $Background
@onready var particles = $Particles
@onready var title_label = $CenterContainer/VBox/TitleLabel
@onready var subtitle_label = $CenterContainer/VBox/SubtitleLabel
@onready var play_button = $CenterContainer/VBox/PlayButton
@onready var settings_button = $SettingsButton
@onready var parent_gate_button = $ParentGateButton
@onready var glow_timer = $GlowTimer
@onready var fade_in_timer = $FadeInTimer

var pulse_tween: Tween
var glow_tween: Tween
var fade_items: Array = []
var current_fade_index: int = 0
var _sparkle: Node2D = null
var _title_art: TextureRect = null
var _subtitle_art: TextureRect = null
var _description_art: TextureRect = null
var _safe_left: float = 0.0
var _safe_top: float = 0.0
var _safe_right: float = 0.0

func _center_x(width: float) -> float:
	var vp := DisplayHelper.get_viewport_size()
	# Заголовки центрируем относительно всего экрана, а safe-area учитываем
	# отдельно для кнопок/отступа сверху.
	return (vp.x - width) * 0.5

func _ready():
	DisplayHelper.fill_control(self)
	var insets := DisplayHelper.safe_area_insets()
	_safe_left = insets.x
	_safe_top = insets.y
	_safe_right = insets.z
	# Safe-area: сдвигаем центральный UI вниз от выреза/камеры.
	if has_node("CenterContainer"):
		var cc := $CenterContainer as Control
		cc.offset_top += _safe_top
		cc.offset_bottom += _safe_top
	# WOW фон чуть приглушаем для читаемости текста и UI.
	if background:
		background.modulate = Color(0.25, 0.28, 0.38, 1.0)
	_upgrade_play_button()
	_configure_touch_targets()
	_replace_text_with_art()
	_add_sparkle_mascot()
	_add_album_button()
	_setup_particles()
	_setup_fade_in()
	_setup_glow_animation()
	_setup_pulse_animation()
	_connect_signals()


func _replace_text_with_art() -> void:
	var vbox := get_node_or_null("CenterContainer/VBox") as VBoxContainer
	if vbox == null:
		return

	# Удаляем старые арт-узлы (если перезаходим в меню).
	for n in ["TitleArt", "SubtitleArt", "DescriptionArt"]:
		var old := vbox.get_node_or_null(n)
		if old:
			old.queue_free()

	if title_label:
		title_label.visible = false
		var title_idx := title_label.get_index()
		var title_pic := TextureRect.new()
		title_pic.name = "TitleArt"
		title_pic.texture = MiniGameArt.resolve_texture(MENU_TITLE_TEX)
		title_pic.custom_minimum_size = DisplayHelper.scale_size(Vector2(860, 220))
		title_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_pic.stretch_mode = TextureRect.STRETCH_SCALE
		title_pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_pic)
		vbox.move_child(title_pic, title_idx)
		_title_art = title_pic
	if subtitle_label:
		subtitle_label.visible = false
		subtitle_label.custom_minimum_size = Vector2.ZERO
		subtitle_label.size = Vector2.ZERO
		_subtitle_art = null

	var desc_pic := TextureRect.new()
	desc_pic.name = "DescriptionArt"
	desc_pic.texture = MiniGameArt.resolve_texture(MENU_DESCRIPTION_TEX)
	desc_pic.custom_minimum_size = DisplayHelper.scale_size(Vector2(820, 132))
	desc_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desc_pic.stretch_mode = TextureRect.STRETCH_SCALE
	desc_pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	desc_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_pic)
	# Вставляем описание прямо перед кнопкой "Играть" (в конец текста).
	var play_idx := play_button.get_index() if play_button and play_button.get_parent() == vbox else vbox.get_child_count() - 1
	vbox.move_child(desc_pic, maxi(0, play_idx))
	_description_art = desc_pic
	if play_button:
		play_button.text = ""
		MiniGameArt.replace_picture(play_button, "PlayLabelArt", MENU_PLAY_LABEL_TEX, Vector2(360, 108))
		var play_art := play_button.get_node_or_null("PlayLabelArt")
		if play_art is TextureRect:
			(play_art as TextureRect).position = Vector2((play_button.size.x - 360.0) * 0.5, (play_button.size.y - 108.0) * 0.5)
	if settings_button:
		var settings_icon = settings_button.get_node_or_null("SettingsIcon")
		if settings_icon:
			settings_icon.visible = false
		MiniGameArt.replace_picture(settings_button, "SettingsArt", MENU_SETTINGS_ICON_TEX, settings_button.size)
	if parent_gate_button:
		var parent_icon = parent_gate_button.get_node_or_null("ParentGateIcon")
		if parent_icon:
			parent_icon.visible = false
		MiniGameArt.replace_picture(parent_gate_button, "ParentArt", MENU_PARENT_ICON_TEX, parent_gate_button.size)


func _upgrade_play_button() -> void:
	var old_btn: TextureButton = play_button
	var parent := old_btn.get_parent()
	var idx := old_btn.get_index()
	# Делаем большую «детскую» кнопку (читабельно и удобно пальцем).
	var sz := Vector2(600, 220)

	var btn := Button.new()
	btn.name = "PlayButton"
	btn.text = ""
	btn.custom_minimum_size = sz
	btn.size = sz
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", DisplayHelper.scale_font(44))
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	btn.add_theme_constant_override("outline_size", 6)

	var style := StyleBoxTexture.new()
	style.texture = WOW_PLAY_TEX
	style.texture_margin_left = 0
	style.texture_margin_right = 0
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.modulate_color = Color(1.06, 1.06, 1.06, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.modulate_color = Color(0.95, 0.95, 0.95, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Удаляем старую кнопку сразу, чтобы не перехватывала ввод.
	parent.remove_child(old_btn)
	old_btn.queue_free()
	parent.add_child(btn)
	parent.move_child(btn, idx)
	play_button = btn


func _configure_touch_targets() -> void:
	# Сброс анкеров и установка точного размера и позиции
	if settings_button:
		settings_button.anchor_left = 0.0
		settings_button.anchor_right = 0.0
		settings_button.anchor_top = 0.0
		settings_button.anchor_bottom = 0.0
		settings_button.size = DisplayHelper.scale_size(Vector2(100, 100))
		# Верхняя правая кнопка: учитываем safe-area (камера/вырез).
		settings_button.position = DisplayHelper.scale_pos(Vector2(940, 60)) + Vector2(-_safe_right, _safe_top)
		var settings_icon = settings_button.get_node_or_null("SettingsIcon")
		if settings_icon:
			settings_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if parent_gate_button:
		parent_gate_button.anchor_left = 0.0
		parent_gate_button.anchor_right = 0.0
		parent_gate_button.anchor_top = 0.0
		parent_gate_button.anchor_bottom = 0.0
		parent_gate_button.size = DisplayHelper.scale_size(Vector2(100, 100))
		parent_gate_button.position = DisplayHelper.scale_pos(Vector2(40, 1760))
		var parent_icon = parent_gate_button.get_node_or_null("ParentGateIcon")
		if parent_icon:
			parent_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# TextureButton без текстуры — задаём явную зону нажатия
	_style_texture_button(settings_button, Color(0.25, 0.25, 0.35, 0.85))
	_style_texture_button(parent_gate_button, Color(0.25, 0.25, 0.35, 0.85))

	$CenterContainer.z_index = 10
	if settings_button:
		settings_button.z_index = 10
	if parent_gate_button:
		parent_gate_button.z_index = 10


func _style_texture_button(btn: BaseButton, tint: Color) -> void:
	btn.custom_minimum_size = btn.size if btn.size.length() > 1 else Vector2(120, 120)
	btn.modulate = tint
	var empty := ImageTexture.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.01))
	empty.set_image(img)
	if btn is TextureButton:
		btn.texture_normal = empty
		btn.texture_pressed = empty
		btn.texture_hover = empty
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE


func _add_sparkle_mascot() -> void:
	_sparkle = SPARKLE_SCRIPT.new()
	_sparkle.name = "MenuSparkle"
	_sparkle.position = DisplayHelper.scale_pos(Vector2(540, 1550))
	_sparkle.z_index = 2
	add_child(_sparkle)


func _add_album_button() -> void:
	var btn := Button.new()
	btn.name = "AlbumButton"
	var sz := DisplayHelper.scale_size(Vector2(100, 100))
	btn.custom_minimum_size = sz
	btn.size = sz
	# Вторая кнопка под настройками.
	btn.position = DisplayHelper.scale_pos(Vector2(940, 180)) + Vector2(-_safe_right, _safe_top)
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	var style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", style)
	MiniGameArt.replace_picture(btn, "AlbumArt", MENU_ALBUM_ICON_TEX, sz)
	btn.pressed.connect(_on_album_pressed)
	btn.z_index = 10
	add_child(btn)


func _on_album_pressed() -> void:
	JuiceManager.button_pop(get_node_or_null("AlbumButton"))
	StickerAlbumScript.open_over(self)


func _setup_particles():
	particles.texture = null
	particles.color = Color(1.0, 1.0, 0.9, 0.8)
	particles.amount = 55
	particles.emitting = true

	var twinkle := ColorRect.new()
	twinkle.name = "MenuTwinkle"
	DisplayHelper.fill_control(twinkle)
	twinkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/twinkle.gdshader")
	mat.set_shader_parameter("twinkle_color", Color(1, 0.95, 0.7, 0.4))
	twinkle.material = mat
	add_child(twinkle)
	move_child(twinkle, 1)

func _setup_fade_in():
	fade_items = [
		{ "node": _title_art if _title_art != null else title_label, "modulate_start": Color(1, 1, 0.8, 0), "modulate_end": Color(1, 1, 0.8, 1) },
		{ "node": _description_art, "modulate_start": Color(1, 1, 1, 0), "modulate_end": Color(1, 1, 1, 0.95) },
		{ "node": play_button, "modulate_start": Color(1, 1, 1, 0), "modulate_end": Color(1, 1, 1, 1), "scale_start": Vector2(0.5, 0.5), "scale_end": Vector2(1.0, 1.0) },
		{ "node": settings_button, "modulate_start": Color(1, 1, 1, 0), "modulate_end": Color(0.7, 0.7, 0.8, 0.9) },
		{ "node": parent_gate_button, "modulate_start": Color(1, 1, 1, 0), "modulate_end": Color(0.7, 0.7, 0.8, 0.9) },
		{ "node": get_node_or_null("AlbumButton"), "modulate_start": Color(1, 1, 1, 0), "modulate_end": Color(0.7, 0.7, 0.8, 0.9) }
	]
	for item in fade_items:
		if item.node == null:
			continue
		item.node.modulate = item.modulate_start
		if item.has("scale_start"):
			item.node.scale = item.scale_start
	current_fade_index = 0
	fade_in_timer.start()

func _on_fade_in_timer_timeout():
	if current_fade_index >= fade_items.size():
		fade_in_timer.stop()
		return

	var item = fade_items[current_fade_index]
	if item.node == null:
		current_fade_index += 1
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(item.node, "modulate", item.modulate_end, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if item.has("scale_end"):
		tween.tween_property(item.node, "scale", item.scale_end, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	current_fade_index += 1
	fade_in_timer.wait_time = 0.15

func _setup_glow_animation():
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
	glow_tween = create_tween().set_loops()
	var title_node: CanvasItem = _title_art if _title_art != null else title_label
	glow_tween.tween_property(title_node, "modulate", Color(1.0, 1.0, 0.9, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(title_node, "modulate", Color(1.0, 0.85, 0.5, 0.85), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _setup_pulse_animation():
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(play_button, "scale", Vector2(1.08, 1.08), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _connect_signals():
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not parent_gate_button.pressed.is_connected(_on_parent_gate_pressed):
		parent_gate_button.pressed.connect(_on_parent_gate_pressed)
	if not fade_in_timer.timeout.is_connected(_on_fade_in_timer_timeout):
		fade_in_timer.timeout.connect(_on_fade_in_timer_timeout)

func _on_play_pressed():
	emit_signal("play_pressed")
	JuiceManager.button_pop(play_button)
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("tap")
	if _sparkle and _sparkle.has_method("set_mood"):
		_sparkle.set_mood(5)
		_sparkle.play_idle()
	if has_node("/root/SceneManager"):
		SceneManager.goto_world_map()


func _on_settings_pressed():
	emit_signal("settings_pressed")
	JuiceManager.button_pop(settings_button)
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("tap")
	show_settings()


func _on_parent_gate_pressed():
	emit_signal("parent_gate_pressed")
	JuiceManager.button_pop(parent_gate_button)
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("tap")
	show_parent_gate()

func show_settings():
	var settings_scene = preload("res://scenes/ui/Settings.tscn")
	var settings_instance = settings_scene.instantiate()
	add_child(settings_instance)

func show_parent_gate():
	var parent_gate_scene = preload("res://scenes/ui/ParentGate.tscn")
	var parent_gate_instance = parent_gate_scene.instantiate()
	add_child(parent_gate_instance)

func _exit_tree():
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
