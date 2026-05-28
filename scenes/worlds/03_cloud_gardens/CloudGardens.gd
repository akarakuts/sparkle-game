extends 'res://scripts/worlds/WorldBase.gd'

## World 2 — Cloud Gardens.

func _ready():
	world_id = 2
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#e8c8ff"), Color("#ffe8f0"))

	_make_parallax_layers([
		{"color": Color("#ffe8ff", 0.35), "y": 400, "height": 300, "speed": 0.06, "round": true},
	])

	_make_particles({
		"amount": 30,
		"lifetime": 7.0,
		"spread": 360.0,
		"vel_min": 3.0,
		"vel_max": 15.0,
		"scale_min": 0.4,
		"scale_max": 1.2,
		"color": Color("#ffffff"),
	})

	var cloud_data = [
		{"pos": Vector2(100, 200), "size": Vector2(200, 80), "color": Color(1, 1, 1, 0.7)},
		{"pos": Vector2(500, 300), "size": Vector2(250, 90), "color": Color(1, 1, 1, 0.6)},
		{"pos": Vector2(800, 150), "size": Vector2(180, 70), "color": Color(1, 1, 1, 0.7)},
		{"pos": Vector2(300, 600), "size": Vector2(220, 85), "color": Color(1, 1, 1, 0.5)},
		{"pos": Vector2(700, 500), "size": Vector2(190, 75), "color": Color(1, 1, 1, 0.5)},
	]
	for i in range(cloud_data.size()):
		var d = cloud_data[i]
		var cloud = ColorRect.new()
		cloud.name = "Cloud" + str(i)
		cloud.size = DisplayHelper.scale_size(d["size"])
		cloud.position = DisplayHelper.scale_pos(d["pos"])
		cloud.color = d["color"]
		var style = StyleBoxFlat.new()
		style.bg_color = cloud.color
		style.corner_radius_top_left = 40
		style.corner_radius_top_right = 40
		style.corner_radius_bottom_left = 40
		style.corner_radius_bottom_right = 40
		cloud.add_theme_stylebox_override("panel", style)
		add_child(cloud)
		move_child(cloud, 2)
		var tween = create_tween().set_loops()
		var start_x = cloud.position.x
		tween.tween_property(cloud, "position:x", start_x + 60, 4.0 + i * 0.5)
		tween.tween_property(cloud, "position:x", start_x - 60, 4.0 + i * 0.5)

	const MINIGAME_BUTTON_POSITIONS := [
		Vector2(160, 450),
		Vector2(420, 550),
		Vector2(680, 450),
		Vector2(920, 550),
	]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🐝", Vector2(540, 1600))
	_make_tappable_flower("🌸", Vector2(180, 950))
	_make_tappable_flower("🦋", Vector2(820, 880))
	_make_tappable_flower("🌈", Vector2(540, 720))
