extends Node2D
class_name SparkleCharacter

## Sparkle — mascot node (emoji body, glow, idle/celebrate tweens); used on menu and in worlds.

enum Mood { IDLE, HAPPY, THINK, CELEBRATE, SAD, EXCITED }

const MOOD_EMOJI: Dictionary = {
	Mood.IDLE: "✨",
	Mood.HAPPY: "😊",
	Mood.THINK: "🤔",
	Mood.CELEBRATE: "🎉",
	Mood.SAD: "😢",
	Mood.EXCITED: "🤩",
}

var _body: Label = null
var _glow: Panel = null
var _halo: CPUParticles2D = null
var _mood: Mood = Mood.IDLE
var _idle_tween: Tween = null


func _ready() -> void:
	_build_visual()
	set_mood(Mood.IDLE)
	play_idle()


func _build_visual() -> void:
	_glow = Panel.new()
	_glow.name = "Glow"
	var glow_size := Vector2(140, 140)
	_glow.size = glow_size
	_glow.position = -glow_size * 0.5
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.85, 0.2, 0.35)
	glow_style.corner_radius_top_left = 70
	glow_style.corner_radius_top_right = 70
	glow_style.corner_radius_bottom_left = 70
	glow_style.corner_radius_bottom_right = 70
	_glow.add_theme_stylebox_override("panel", glow_style)
	add_child(_glow)

	_halo = CPUParticles2D.new()
	_halo.name = "HaloParticles"
	_halo.amount = 12
	_halo.lifetime = 1.2
	_halo.preprocess = 0.5
	_halo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_halo.emission_sphere_radius = 40.0
	_halo.gravity = Vector2.ZERO
	_halo.initial_velocity_min = 5.0
	_halo.initial_velocity_max = 20.0
	_halo.scale_amount_min = 0.3
	_halo.scale_amount_max = 0.8
	_halo.color = Color(1, 0.95, 0.6, 0.9)
	_halo.emitting = true
	add_child(_halo)

	_body = Label.new()
	_body.name = "Body"
	_body.text = "✨"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.size = Vector2(100, 100)
	_body.position = Vector2(-50, -50)
	_body.add_theme_font_size_override("font_size", DisplayHelper.scale_font(72))
	add_child(_body)


func set_mood(mood: Mood) -> void:
	_mood = mood
	if _body:
		_body.text = MOOD_EMOJI.get(mood, "✨")
	match mood:
		Mood.CELEBRATE, Mood.EXCITED:
			_glow.modulate = Color(1.2, 1.0, 0.5, 1.0)
		Mood.SAD:
			_glow.modulate = Color(0.6, 0.7, 1.0, 0.8)
		_:
			_glow.modulate = Color(1, 1, 1, 1)


func play_idle() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", position.y - 12.0, 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(self, "position:y", position.y, 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.parallel().tween_property(_glow, "scale", Vector2(1.08, 1.08), 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.parallel().tween_property(_glow, "scale", Vector2(1.0, 1.0), 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func play_celebrate() -> void:
	set_mood(Mood.CELEBRATE)
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(_body, "scale", Vector2(1.0, 1.0), 0.25)
	tw.tween_property(self, "rotation", 0.15, 0.15)
	tw.chain().tween_property(self, "rotation", -0.15, 0.15)
	tw.chain().tween_property(self, "rotation", 0.0, 0.1)
	tw.chain().tween_callback(play_idle)


func play_think() -> void:
	set_mood(Mood.THINK)


func play_happy() -> void:
	set_mood(Mood.HAPPY)


func play_sad() -> void:
	set_mood(Mood.SAD)
	JuiceManager.shake_node(self, 4.0)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(play_idle)


func speak_bounce() -> void:
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(_body, "scale", Vector2(1.0, 1.0), 0.12)
