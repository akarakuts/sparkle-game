extends Node2D

## WorldBase — hub scene for each world: backdrop, mini-game buttons, HUD, Sparkle, dialogs.

class_name WorldBase

const DIALOG_SCENE := preload("res://scenes/ui/DialogBox.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const SPARKLE_SCRIPT := preload("res://scripts/characters/SparkleCharacter.gd")
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const WORLD_BACK_TEX := "res://assets/graphics/ui/minigames/common/back_button.png"
const WORLD_DONE_BADGE_TEX := "res://assets/graphics/ui/minigames/world/done_badge.png"
const WORLD_TOAST_DONE_TEX := "res://assets/graphics/ui/minigames/world/toast_done.png"
const WORLD_MINIGAME_TEX := {
	"Puzzle.tscn": "res://assets/graphics/ui/minigames/world/mg_puzzle.png",
	"Memory.tscn": "res://assets/graphics/ui/minigames/world/mg_memory.png",
	"Sequencing.tscn": "res://assets/graphics/ui/minigames/world/mg_sequence.png",
	"Drawing.tscn": "res://assets/graphics/ui/minigames/world/mg_drawing.png",
}

var world_id: int = 0
var _toast_label: Label = null
var _toast_bg: ColorRect = null
var _minigame_buttons: Array = []
var _sparkle: Node2D = null
var _hud: CanvasLayer = null
var _dialog: Control = null
var _intro_shown: bool = false


func _ready() -> void:
	_build_back_button()
	GameState.current_world = world_id
	AudioManager.play_music(world_id)


func setup_world() -> void:
	pass


func finalize_presentation() -> void:
	_setup_sparkle_and_hud()
	_add_twinkle_overlay()
	call_deferred("_show_world_intro")


func _setup_sparkle_and_hud() -> void:
	_sparkle = SPARKLE_SCRIPT.new()
	_sparkle.name = "Sparkle"
	_sparkle.position = DisplayHelper.scale_pos(Vector2(900, 1750))
	_sparkle.z_index = 20
	add_child(_sparkle)

	_hud = HUD_SCENE.instantiate()
	_hud.name = "WorldHUD"
	add_child(_hud)
	_refresh_hud_progress()


func _refresh_hud_progress() -> void:
	if _hud == null:
		return
	var games: Array = MiniGameManager.get_world_games(world_id)
	var done: int = 0
	for game in games:
		if game.get("completed", false):
			done += 1
	var total: int = maxi(games.size(), 1)
	_hud.set_progress(float(done) / float(total))


func _show_world_intro() -> void:
	if _intro_shown:
		return
	_intro_shown = true
	var intro: Dictionary = WorldStory.get_intro(world_id)
	_show_sparkle_message(intro.get("text", ""), intro.get("emotion", "happy"))


func _show_sparkle_message(text: String, emotion: String = "happy", auto_close: bool = true) -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = DIALOG_SCENE.instantiate()
	add_child(_dialog)
	DisplayHelper.fill_control(_dialog)
	if _dialog.has_method("show_message"):
		_dialog.show_message(text, emotion, "talk", auto_close)
	if _sparkle:
		_sparkle.speak_bounce()
		match emotion:
			"celebrate", "excited":
				_sparkle.play_celebrate()
			"think":
				_sparkle.play_think()
			"sad":
				_sparkle.play_sad()
			"love", "surprise":
				if _sparkle.has_method("set_mood"):
					_sparkle.set_mood(5)  # EXCITED
				if _sparkle.has_method("play_idle"):
					_sparkle.play_idle()
			_:
				_sparkle.play_happy()


func _setup_minigame_buttons(positions: Array) -> void:
	var games: Array = MiniGameManager.get_world_games(world_id)
	var count: int = mini(games.size(), positions.size())
	for i in range(count):
		var game: Dictionary = games[i]
		var icon: String = _icon_for_scene(game.get("scene_path", ""))
		var btn := _make_minigame_button(i, icon, positions[i], game.get("name", ""))
		if game.get("completed", false):
			btn.modulate = Color(0.75, 1.0, 0.75, 1.0)
			_add_completed_star(btn)
		else:
			_add_glow_pulse(btn)
		_minigame_buttons.append(btn)


func _icon_for_scene(scene_path: String) -> String:
	for key in WORLD_MINIGAME_TEX.keys():
		if scene_path.ends_with(key):
			return WORLD_MINIGAME_TEX[key]
	return WORLD_MINIGAME_TEX["Puzzle.tscn"]


# ── Background helpers ────────────────────────────────────────────

func _make_fullscreen_bg() -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "Background"
	DisplayHelper.fill_control(bg)
	bg.color = Color(0.1, 0.1, 0.2, 1.0)
	add_child(bg)
	move_child(bg, 0)
	return bg


func _set_bg_gradient(bg: ColorRect, color_top: Color, color_bottom: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/gradient.gdshader")
	mat.set_shader_parameter("color_top", color_top)
	mat.set_shader_parameter("color_bottom", color_bottom)
	bg.material = mat


func _add_twinkle_overlay() -> void:
	var twinkle := ColorRect.new()
	twinkle.name = "TwinkleOverlay"
	DisplayHelper.fill_control(twinkle)
	twinkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/twinkle.gdshader")
	mat.set_shader_parameter("twinkle_color", Color(1, 1, 0.85, 0.45))
	mat.set_shader_parameter("density", 10.0)
	twinkle.material = mat
	add_child(twinkle)
	move_child(twinkle, get_child_count() - 1)


func _make_parallax_layers(layers: Array) -> void:
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBackground"
	pb.scroll_base_offset = Vector2.ZERO
	add_child(pb)
	move_child(pb, 1)

	for i in range(layers.size()):
		var cfg: Dictionary = layers[i]
		var layer := ParallaxLayer.new()
		layer.name = "ParallaxLayer" + str(i)
		layer.motion_scale = Vector2(cfg.get("speed", 0.2), cfg.get("speed", 0.2))

		var strip := ColorRect.new()
		strip.color = cfg.get("color", Color(1, 1, 1, 0.15))
		var h: float = cfg.get("height", 300.0)
		var y: float = cfg.get("y", 400.0)
		strip.size = Vector2(DisplayHelper.BASE_SIZE.x, h)
		strip.position = Vector2(0, y)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if cfg.get("round", false):
			var style := StyleBoxFlat.new()
			style.bg_color = strip.color
			style.corner_radius_top_left = int(h * 0.5)
			style.corner_radius_top_right = int(h * 0.5)
			strip.add_theme_stylebox_override("panel", style)

		layer.add_child(strip)
		pb.add_child(layer)


func _make_particles(config: Dictionary = {}) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "AtmosphereParticles"
	particles.amount = config.get("amount", 30)
	particles.lifetime = config.get("lifetime", 4.0)
	particles.spread = config.get("spread", 180.0)
	particles.gravity = config.get("gravity", Vector2.ZERO)
	particles.initial_velocity_min = config.get("vel_min", 10.0)
	particles.initial_velocity_max = config.get("vel_max", 40.0)
	particles.scale_amount_min = config.get("scale_min", 0.5)
	particles.scale_amount_max = config.get("scale_max", 1.5)
	particles.color = config.get("color", Color.WHITE)
	particles.position = DisplayHelper.center()
	particles.one_shot = false
	particles.emitting = true
	particles.z_index = config.get("z_index", 5)
	add_child(particles)
	return particles


func _make_decor_tree(x: float, height: float, color: Color, crown_color: Color = Color()) -> void:
	var trunk := ColorRect.new()
	trunk.size = DisplayHelper.scale_size(Vector2(36, height * 0.55))
	trunk.position = DisplayHelper.scale_pos(Vector2(x, 1920 - height * 0.55))
	trunk.color = Color("#4a3020")
	add_child(trunk)
	move_child(trunk, 2)

	var crown := ColorRect.new()
	var crown_sz := DisplayHelper.scale_size(Vector2(90, height * 0.5))
	crown.size = crown_sz
	crown.position = DisplayHelper.scale_pos(Vector2(x - 27, 1920 - height)) - Vector2(0, crown_sz.y * 0.2)
	crown.color = crown_color if crown_color != Color() else color
	var crown_style := StyleBoxFlat.new()
	crown_style.bg_color = crown.color
	crown_style.corner_radius_top_left = 40
	crown_style.corner_radius_top_right = 40
	crown_style.corner_radius_bottom_left = 20
	crown_style.corner_radius_bottom_right = 20
	crown.add_theme_stylebox_override("panel", crown_style)
	add_child(crown)
	move_child(crown, 2)


func _make_tappable_flower(emoji: String, pos: Vector2) -> void:
	var btn := Button.new()
	btn.name = "Flower"
	btn.text = emoji
	btn.flat = true
	var sz := DisplayHelper.scale_size(Vector2(72, 72))
	btn.size = sz
	btn.position = DisplayHelper.scale_pos(pos) - sz * 0.5
	btn.add_theme_font_size_override("font_size", DisplayHelper.scale_font(40))
	btn.pressed.connect(func():
		JuiceManager.button_pop(btn)
		JuiceManager.sparkle_burst(btn.global_position, self)
		AudioManager.play_sfx("tap")
	)
	add_child(btn)


# ── Mini-game buttons ─────────────────────────────────────────────

func _make_minigame_button(game_id: int, icon_text: String, pos: Vector2, label: String = "", size: Vector2 = Vector2(220, 170)) -> Button:
	var btn := Button.new()
	btn.name = "MiniGame_" + str(game_id)
	var scaled_size := DisplayHelper.scale_size(size)
	btn.size = scaled_size
	btn.position = DisplayHelper.scale_pos(pos) - scaled_size * 0.5
	btn.z_index = 15

	var theme_box := StyleBoxFlat.new()
	theme_box.bg_color = Color(1, 1, 1, 0.28)
	theme_box.border_width_left = 3
	theme_box.border_width_top = 3
	theme_box.border_width_right = 3
	theme_box.border_width_bottom = 3
	theme_box.border_color = Color(1, 0.95, 0.6, 0.7)
	theme_box.corner_radius_top_left = 20
	theme_box.corner_radius_top_right = 20
	theme_box.corner_radius_bottom_left = 20
	theme_box.corner_radius_bottom_right = 20
	theme_box.shadow_color = Color(0, 0, 0, 0.25)
	theme_box.shadow_size = 6
	btn.add_theme_stylebox_override("normal", theme_box)

	var theme_hover := theme_box.duplicate()
	theme_hover.bg_color = Color(1, 1, 1, 0.45)
	btn.add_theme_stylebox_override("hover", theme_hover)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	MiniGameArt.replace_picture(btn, "Icon", icon_text, scaled_size)

	btn.pressed.connect(_on_minigame_button_pressed.bind(game_id))
	add_child(btn)
	return btn


func _add_glow_pulse(btn: Button) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(btn, "modulate", Color(1.05, 1.05, 1.0, 1.0), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "modulate", Color(0.92, 0.98, 1.0, 0.95), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _add_completed_star(btn: Button) -> void:
	var star := MiniGameArt.make_picture("Star", WORLD_DONE_BADGE_TEX, Vector2(40, 40), Vector2(btn.size.x - 44, -8), 2)
	btn.add_child(star)


func _on_minigame_button_pressed(game_id: int) -> void:
	var games: Array = MiniGameManager.get_world_games(world_id)
	if game_id < 0 or game_id >= games.size():
		return
	if games[game_id].get("completed", false):
		_show_toast("Уже пройдено! ⭐")
		if _sparkle:
			_sparkle.play_happy()
		return
	JuiceManager.button_pop(_minigame_buttons[game_id] if game_id < _minigame_buttons.size() else null)
	AudioManager.play_sfx("tap")
	var scene_path: String = games[game_id].get("scene_path", "")
	for key in WorldStory.MINIGAME_HINTS.keys():
		if scene_path.ends_with(key):
			_show_sparkle_message(WorldStory.MINIGAME_HINTS[key], "think", true)
			await get_tree().create_timer(1.8).timeout
			# Сцену могли покинуть за время паузы — не выполняем переход.
			if not is_inside_tree():
				return
			break
	SceneManager.goto_minigame(world_id, game_id)


func _show_toast(text: String) -> void:
	if _toast_label and is_instance_valid(_toast_label):
		_toast_label.queue_free()
	if _toast_bg and is_instance_valid(_toast_bg):
		_toast_bg.queue_free()
	var toast_art := get_node_or_null("ToastArt")
	if toast_art and is_instance_valid(toast_art):
		toast_art.queue_free()

	var vp := DisplayHelper.get_viewport_size()
	_toast_bg = ColorRect.new()
	_toast_bg.name = "ToastBg"
	_toast_bg.color = Color(0.1, 0.05, 0.2, 0.75)
	var toast_w: float = min(480, vp.x * 0.85)
	_toast_bg.size = Vector2(toast_w, 110)
	_toast_bg.position = Vector2((vp.x - toast_w) * 0.5, vp.y * 0.42)
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = _toast_bg.color
	toast_style.corner_radius_top_left = 16
	toast_style.corner_radius_top_right = 16
	toast_style.corner_radius_bottom_left = 16
	toast_style.corner_radius_bottom_right = 16
	_toast_bg.add_theme_stylebox_override("panel", toast_style)
	_toast_bg.z_index = 99
	add_child(_toast_bg)

	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.visible = false
	_toast_label.size = _toast_bg.size
	_toast_label.position = _toast_bg.position
	_toast_label.z_index = 100
	add_child(_toast_label)
	add_child(MiniGameArt.make_picture("ToastArt", WORLD_TOAST_DONE_TEX, Vector2(420, 96), Vector2(_toast_bg.position.x + 30, _toast_bg.position.y + 7), 101))

	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_clear_toast)


func _clear_toast() -> void:
	var toast_art := get_node_or_null("ToastArt")
	if toast_art and is_instance_valid(toast_art):
		toast_art.queue_free()
	if _toast_label and is_instance_valid(_toast_label):
		_toast_label.queue_free()
	if _toast_bg and is_instance_valid(_toast_bg):
		_toast_bg.queue_free()
	_toast_label = null
	_toast_bg = null


func refresh_minigame_buttons() -> void:
	var games: Array = MiniGameManager.get_world_games(world_id)
	for i in range(mini(_minigame_buttons.size(), games.size())):
		var btn: Button = _minigame_buttons[i]
		if games[i].get("completed", false):
			btn.modulate = Color(0.75, 1.0, 0.75, 1.0)
			if not btn.has_node("Star"):
				_add_completed_star(btn)
	_refresh_hud_progress()
	# Поздравление только в момент завершения мира (не при каждом возврате на сцену).
	if MiniGameManager.is_world_ready(world_id) and SceneManager.consume_world_celebration(world_id):
		_on_world_games_complete()


func _on_world_games_complete() -> void:
	if _sparkle:
		_sparkle.play_celebrate()
	_show_sparkle_message(WorldStory.get_complete_line(world_id), "celebrate", true)
	JuiceManager.celebrate_at(DisplayHelper.center(), self)


# ── Back button ───────────────────────────────────────────────────

func _build_back_button() -> void:
	# Плоская стрелка без синей подложки (как в мини-играх).
	var btn := MiniGameArt.make_picture_button(
		"BackButton",
		WORLD_BACK_TEX,
		DisplayHelper.scale_size(Vector2(120, 120)),
		DisplayHelper.scale_pos(Vector2(24, 24)),
		30
	)
	btn.position.y += DisplayHelper.safe_area_insets().y
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


func _on_back_pressed() -> void:
	JuiceManager.button_pop(get_node_or_null("BackButton"))
	AudioManager.play_sfx("transition")
	SceneManager.goto_world_map()


# ── NPC helper ────────────────────────────────────────────────────

func _make_npc(emoji: String, pos: Vector2) -> Label:
	var npc := Label.new()
	npc.name = "NPC"
	npc.text = emoji
	var npc_size := DisplayHelper.scale_size(Vector2(90, 90))
	npc.size = npc_size
	npc.position = DisplayHelper.scale_pos(pos) - npc_size * 0.5
	npc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	npc.add_theme_font_size_override("font_size", DisplayHelper.scale_font(52))
	npc.z_index = 10
	add_child(npc)

	var tw := create_tween().set_loops()
	tw.tween_property(npc, "position:y", npc.position.y - 10, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(npc, "position:y", npc.position.y, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return npc
