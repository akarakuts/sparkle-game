extends SceneTree

## Headless smoke test: instantiate main scenes and exit (CI / local sanity).

const SCENES := [
	"res://scenes/main/MainMenu.tscn",
	"res://scenes/main/WorldMap.tscn",
	"res://scenes/worlds/01_glow_forest/GlowForest.tscn",
	"res://scenes/worlds/02_ice_peaks/IcePeaks.tscn",
	"res://scenes/worlds/03_cloud_gardens/CloudGardens.tscn",
	"res://scenes/worlds/04_underwater/UnderwaterCity.tscn",
	"res://scenes/worlds/05_echo_desert/EchoDesert.tscn",
	"res://scenes/worlds/06_mechanical_grove/MechanicalGrove.tscn",
	"res://scenes/worlds/07_dreamlands/Dreamlands.tscn",
	"res://scenes/minigames/Puzzle.tscn",
	"res://scenes/minigames/Memory.tscn",
	"res://scenes/minigames/Sequencing.tscn",
	"res://scenes/minigames/Drawing.tscn",
	"res://scenes/ui/Settings.tscn",
	"res://scenes/ui/ParentGate.tscn",
	"res://scenes/ui/StickerAlbum.tscn",
]

func _initialize() -> void:
	var failed: Array[String] = []
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			failed.append(path + " (load failed)")
			continue
		var inst := packed.instantiate()
		if inst == null:
			failed.append(path + " (instantiate failed)")
			continue
		root.add_child(inst)
		await create_timer(0.05).timeout
		inst.queue_free()
		await create_timer(0.05).timeout
	if failed.is_empty():
		print("SMOKE_OK: all scenes loaded")
	else:
		for f in failed:
			push_error("SMOKE_FAIL: " + f)
	quit(1 if not failed.is_empty() else 0)
