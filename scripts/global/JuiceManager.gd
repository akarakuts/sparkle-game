extends Node

## JuiceManager — autoload: confetti, screen flash, button pop, shake (celebration feedback).

var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null


func _ready() -> void:
	_setup_flash()


func _setup_flash() -> void:
	if _flash_layer == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.name = "JuiceFlashLayer"
		_flash_layer.layer = 127
		add_child(_flash_layer)

	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.name = "JuiceFlash"
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_layer.add_child(_flash_rect)

	DisplayHelper.fill_control(_flash_rect)
	_flash_rect.color = Color(1, 1, 1, 0)


func button_pop(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var base: Vector2 = control.scale
	var tw := create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(control, "scale", base * 0.88, 0.06)
	tw.tween_property(control, "scale", base * 1.08, 0.12)
	tw.tween_property(control, "scale", base, 0.1)


func screen_flash(color: Color, peak_alpha: float = 0.35, duration: float = 0.25) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", peak_alpha, duration * 0.35)
	tw.tween_property(_flash_rect, "color:a", 0.0, duration * 0.65)


func confetti_at(global_pos: Vector2, parent: Node = null, amount: int = 24) -> void:
	var host: Node = parent
	if host == null:
		host = Engine.get_main_loop().root
	if host == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_ctrl)

	var colors: Array = [
		Color("#ff6b6b"), Color("#ffd93d"), Color("#6bcb77"),
		Color("#4d96ff"), Color("#ff85a1"), Color("#c084fc"),
	]
	var local_pos: Vector2 = global_pos
	if parent is Control:
		local_pos = parent.get_global_transform_with_canvas().affine_inverse() * global_pos

	for i in range(amount):
		var p := ColorRect.new()
		var sz: float = randf_range(8.0, 16.0)
		p.size = Vector2(sz, sz * randf_range(0.6, 1.4))
		p.color = colors[i % colors.size()]
		p.position = local_pos
		p.rotation = randf_range(0.0, TAU)
		p.pivot_offset = p.size * 0.5
		root_ctrl.add_child(p)

		var tw := create_tween().set_parallel(true)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.2)).normalized()
		var dist: float = randf_range(120.0, 320.0) * DisplayHelper.get_scale().x
		tw.tween_property(p, "position", local_pos + dir * dist, randf_range(0.5, 0.9)).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-4.0, 4.0), 0.8)
		tw.tween_interval(0.15)
		tw.tween_property(p, "modulate:a", 0.0, 0.8)

	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(layer.queue_free)


func celebrate_at(global_pos: Vector2, parent: Node = null) -> void:
	screen_flash(Color(1.0, 0.92, 0.4), 0.3, 0.35)
	confetti_at(global_pos, parent, 32)


func sparkle_burst(global_pos: Vector2, parent: Node = null) -> void:
	var host: Node = parent if parent != null else Engine.get_main_loop().root
	if host == null:
		return
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.8
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.gravity = Vector2(0, 80)
	particles.color = Color(1, 0.95, 0.5, 1)
	particles.position = global_pos
	host.add_child(particles)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(particles.queue_free)


func shake_node(node: Node2D, intensity: float = 8.0) -> void:
	if node == null:
		return
	var orig: Vector2 = node.position
	var tw := create_tween()
	for i in range(4):
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity * 0.5, intensity * 0.5))
		tw.tween_property(node, "position", orig + off, 0.04)
	tw.tween_property(node, "position", orig, 0.04)


func shake_control(control: Control, intensity: float = 8.0) -> void:
	if control == null:
		return
	var orig: Vector2 = control.position
	var tw := create_tween()
	for i in range(4):
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity * 0.5, intensity * 0.5))
		tw.tween_property(control, "position", orig + off, 0.04)
	tw.tween_property(control, "position", orig, 0.04)
