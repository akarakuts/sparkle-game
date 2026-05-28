extends 'res://scripts/worlds/WorldBase.gd'

## World 1 — Ice Peaks.

func _ready():
	world_id = 1
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#c8e6ff"), Color("#7bb8e0"))

	_make_parallax_layers([
		{"color": Color("#a8cce8", 0.5), "y": 500, "height": 400, "speed": 0.1, "round": true},
		{"color": Color("#88b8d8", 0.4), "y": 900, "height": 500, "speed": 0.18, "round": true},
	])

	_make_particles({
		"amount": 55,
		"lifetime": 6.0,
		"spread": 360.0,
		"vel_min": 8.0,
		"vel_max": 30.0,
		"scale_min": 0.2,
		"scale_max": 0.8,
		"color": Color("#ffffff"),
	})

	_make_decor_tree(120, 380, Color("#b0c8e0"), Color("#d0e8ff"))
	_make_decor_tree(400, 450, Color("#98b8d8"), Color("#c0dff8"))
	_make_decor_tree(700, 400, Color("#a0c0e0"), Color("#d8eeff"))
	_make_decor_tree(950, 420, Color("#90b0d0"), Color("#b8d8f8"))

	const MINIGAME_BUTTON_POSITIONS := [
		Vector2(160, 500),
		Vector2(420, 600),
		Vector2(680, 500),
		Vector2(920, 600),
	]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🐧", Vector2(540, 1600))
	_make_tappable_flower("❄️", Vector2(200, 900))
	_make_tappable_flower("⛄", Vector2(880, 850))
