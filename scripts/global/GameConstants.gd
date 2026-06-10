extends Node

## Shared constants: world count, scene paths, smoke-test list (autoload singleton).

const TOTAL_WORLDS: int = 7

const MENU_SCENE: String = "res://scenes/main/MainMenu.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/main/WorldMap.tscn"

const WORLD_SCENES: Dictionary = {
	0: "res://scenes/worlds/01_glow_forest/GlowForest.tscn",
	1: "res://scenes/worlds/02_ice_peaks/IcePeaks.tscn",
	2: "res://scenes/worlds/03_cloud_gardens/CloudGardens.tscn",
	3: "res://scenes/worlds/04_underwater/UnderwaterCity.tscn",
	4: "res://scenes/worlds/05_echo_desert/EchoDesert.tscn",
	5: "res://scenes/worlds/06_mechanical_grove/MechanicalGrove.tscn",
	6: "res://scenes/worlds/07_dreamlands/Dreamlands.tscn",
}

const SMOKE_SCENES: Array[String] = [
	MENU_SCENE,
	WORLD_MAP_SCENE,
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
	"res://scenes/ui/HUD.tscn",
	"res://scenes/ui/DialogBox.tscn",
]
