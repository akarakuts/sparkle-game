extends 'res://scripts/worlds/WorldBase.gd'

## World 5 — Mechanical Grove.

func _ready():
	world_id = 5
	super()
	setup_world()
	finalize_presentation()

func setup_world():
	var bg = _make_fullscreen_bg()
	_set_bg_gradient(bg, Color("#3a2a10"), Color("#8a7020"))

	_make_particles({
		"amount": 20,
		"lifetime": 3.0,
		"spread": 360.0,
		"vel_min": 2.0,
		"vel_max": 8.0,
		"scale_min": 0.2,
		"scale_max": 0.5,
		"color": Color("#ffd060"),
	})

	var gear_data = [
		{"pos": Vector2(80, 300), "size": Vector2(80, 80), "color": Color("#c8a030")},
		{"pos": Vector2(350, 200), "size": Vector2(60, 60), "color": Color("#b09028")},
		{"pos": Vector2(600, 350), "size": Vector2(100, 100), "color": Color("#d8b040")},
		{"pos": Vector2(850, 250), "size": Vector2(70, 70), "color": Color("#a08020")},
		{"pos": Vector2(480, 700), "size": Vector2(65, 65), "color": Color("#d8b848")},
	]
	for i in range(gear_data.size()):
		var d = gear_data[i]
		var gear = ColorRect.new()
		gear.name = "Gear" + str(i)
		gear.size = DisplayHelper.scale_size(d["size"])
		gear.position = DisplayHelper.scale_pos(d["pos"])
		gear.color = d["color"]
		gear.pivot_offset = gear.size * 0.5
		add_child(gear)
		move_child(gear, 2)
		var tween = create_tween().set_loops()
		tween.tween_property(gear, "rotation", TAU, 2.0 + (i % 3) * 0.8).as_relative()

	const MINIGAME_BUTTON_POSITIONS := [
		Vector2(120, 480),
		Vector2(380, 520),
		Vector2(640, 480),
		Vector2(900, 520),
		Vector2(540, 700),
	]
	_setup_minigame_buttons(MINIGAME_BUTTON_POSITIONS)

	_make_npc("🪲", Vector2(540, 1600))
	_make_npc("⚙️", Vector2(200, 1500))
	_make_tappable_flower("🔩", Vector2(850, 900))
