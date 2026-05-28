extends 'res://scripts/worlds/WorldBase.gd'

## World 4 — Echo Desert.

func _ready():
	world_id = 4
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#4a2a0a"), Color("#c48020"))

	_make_parallax_layers([
		{"color": Color("#8a5020", 0.4), "y": 1200, "height": 350, "speed": 0.05, "round": true},
	])

	_make_particles({
		"amount": 60,
		"lifetime": 6.0,
		"spread": 360.0,
		"vel_min": 2.0,
		"vel_max": 8.0,
		"scale_min": 0.15,
		"scale_max": 0.6,
		"color": Color("#ffdd88"),
	})

	var dune_colors = [Color("#a06020"), Color("#b07028"), Color("#c08030"), Color("#905018"), Color("#d09038")]
	var dune_data = [
		{"pos": Vector2(0, 1500), "size": Vector2(300, 200)},
		{"pos": Vector2(250, 1550), "size": Vector2(350, 250)},
		{"pos": Vector2(550, 1480), "size": Vector2(300, 220)},
		{"pos": Vector2(800, 1540), "size": Vector2(280, 260)},
	]
	for i in range(dune_data.size()):
		var d = dune_data[i]
		var dune = ColorRect.new()
		dune.name = "Dune" + str(i)
		dune.size = DisplayHelper.scale_size(d["size"])
		dune.position = DisplayHelper.scale_pos(d["pos"])
		dune.color = dune_colors[i % dune_colors.size()]
		add_child(dune)
		move_child(dune, 2)

	const MINIGAME_BUTTON_POSITIONS := [
		Vector2(120, 450),
		Vector2(380, 500),
		Vector2(640, 450),
		Vector2(900, 500),
		Vector2(540, 700),
	]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🐫", Vector2(540, 1600))
	_make_tappable_flower("⭐", Vector2(300, 600))
	_make_tappable_flower("🌵", Vector2(800, 650))
