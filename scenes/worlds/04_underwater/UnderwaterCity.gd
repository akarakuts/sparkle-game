extends 'res://scripts/worlds/WorldBase.gd'

## World 3 — Underwater City (three mini-games in config).

func _ready():
	world_id = 3
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#0a1a3a"), Color("#2a6a9a"))

	_make_parallax_layers([
		{"color": Color("#1a4a7a", 0.45), "y": 700, "height": 450, "speed": 0.12, "round": true},
	])

	_make_particles({
		"amount": 40,
		"lifetime": 4.0,
		"spread": 90.0,
		"vel_min": 10.0,
		"vel_max": 40.0,
		"gravity": Vector2(0, -30),
		"scale_min": 0.2,
		"scale_max": 1.0,
		"color": Color("#aaddff"),
	})

	var seaweed_x = [100, 300, 500, 700, 900, 1000]
	for i in range(seaweed_x.size()):
		var sw = ColorRect.new()
		sw.name = "Seaweed" + str(i)
		var h = 200 + (i % 3) * 80
		sw.size = DisplayHelper.scale_size(Vector2(24, h))
		sw.position = DisplayHelper.scale_pos(Vector2(seaweed_x[i], 1720 - h))
		sw.color = Color("#1a6a2a").lerp(Color("#2a8a3a"), float(i) / 6.0)
		add_child(sw)
		move_child(sw, 2)

	const MINIGAME_BUTTON_POSITIONS := [
		Vector2(200, 500),
		Vector2(540, 600),
		Vector2(880, 500),
	]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🐠", Vector2(540, 1600))
	_make_npc("🐙", Vector2(200, 1400))
	_make_tappable_flower("🫧", Vector2(400, 800))
	_make_tappable_flower("🐚", Vector2(750, 750))
