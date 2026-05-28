extends 'res://scripts/worlds/WorldBase.gd'

## World 0 — Glow Forest: tutorial set (four mini-games including Drawing).

# Позиции кнопок мини-игр (дизайн-координаты 1080x1920).
const MINIGAME_BUTTON_POSITIONS := [
	Vector2(200, 400),
	Vector2(540, 500),
	Vector2(880, 400),
	Vector2(540, 760),
]

func _ready():
	world_id = 0
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#0a2e0a"), Color("#1a5c1a"))

	_make_parallax_layers([
		{"color": Color("#0d3a12", 0.4), "y": 300, "height": 280, "speed": 0.08, "round": true},
		{"color": Color("#164a18", 0.35), "y": 600, "height": 350, "speed": 0.15, "round": true},
	])

	_make_particles({
		"amount": 50,
		"lifetime": 5.0,
		"spread": 360.0,
		"vel_min": 5.0,
		"vel_max": 25.0,
		"scale_min": 0.3,
		"scale_max": 1.0,
		"color": Color("#ffff88"),
	})

	var tree_heights = [360, 420, 300, 480, 340, 400]
	var tree_x_positions = [80, 250, 450, 650, 850, 1000]
	for i in range(tree_x_positions.size()):
		_make_decor_tree(tree_x_positions[i], tree_heights[i], Color("#2d5a1e"), Color("#3a7a28"))

	_make_tappable_flower("🌸", Vector2(350, 1200))
	_make_tappable_flower("🍄", Vector2(750, 1100))
	_make_tappable_flower("🌼", Vector2(150, 1300))

	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🦊", Vector2(300, 1580))
	_make_npc("✨", Vector2(540, 1620))
