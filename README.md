# Sparkle and the Crystal of Friendship

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Russian / Русский: [README.ru.md](README.ru.md)

**Sparkle and the Crystal of Friendship** (*Искорка и Кристалл Дружбы*) — a portrait Android adventure for children: seven themed worlds, four mini-games per world, collectible crystal shards, and a sticker album. Built with **Godot 4.6** and **GDScript**.

| | |
|---|---|
| Package | `com.sparklegame.sparkle` |
| Version | `1.2.0` (see `export_presets.cfg`) |
| Engine | Godot 4.6.3, GL compatibility renderer |
| Orientation | Portrait 1080×1920 (scaled via `DisplayHelper`) |

## Features

- **Story** — Sparkle guides the player across seven worlds to restore the **Crystal of Friendship** (one shard per completed world).
- **World map** — zigzag island layout, locked / open / completed states, hints, sticker album entry.
- **Mini-games** — **Puzzle** (sorting), **Memory** (pairs), **Sequencing** (pattern), **Drawing** (free draw with stroke limit in Dreamlands); per-world difficulty 1–5.
- **Progress** — JSON saves in `user://` (`SaveManager`, versioned schema), three slots, parent gate (math challenge + screen-time bar).
- **UI** — generated PNG UI (`tools/gen_minigame_ui_assets.py`), WOW-style backgrounds, safe-area aware layout, juice effects (`JuiceManager`).
- **Locales** — Russian-first copy (`WorldStory`, UI art labels).

## Stack

| Area | Choice |
|------|--------|
| Engine | Godot 4.6.3 |
| Language | GDScript |
| Rendering | `gl_compatibility` (mobile) |
| Persistence | `user://save_*.json` via `SaveManager` |
| Android export | Godot export presets + Gradle AAB (`gradle_build`) |

## Requirements

- **Godot 4.6.3** (export templates for Android installed)
- **Android SDK** for device builds (compile/target SDK as in `android/config.gradle`)
- **JDK 11+** when building **AAB** with Gradle
- Optional: **Python 3** + Pillow to regenerate UI PNGs (`tools/gen_minigame_ui_assets.py`)

Local editor binary (optional): `.tools/Godot.app` in the project tree.

## Build & run

### Debug APK (emulator / device)

```bash
# from repo root; adjust GODOT path if needed
.tools/Godot.app/Contents/MacOS/Godot --headless --export-debug "Android" .build/SparkleGame.apk

adb install -r .build/SparkleGame.apk
adb shell am start -n com.sparklegame.sparkle/com.godot.game.GodotAppLauncher
```

### Editor

Open the project in Godot 4.6 and run the main scene `res://scenes/main/MainMenu.tscn`.

### Headless checks

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless -s tools/smoke_test.gd
.tools/Godot.app/Contents/MacOS/Godot --headless -s tools/test_runner.gd
```

### Regenerate UI assets

```bash
python3 tools/gen_minigame_ui_assets.py
```

### Release builds

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --export-release "Android Release AAB" .build/SparkleGame-release.aab
.tools/Godot.app/Contents/MacOS/Godot --headless --export-release "Android Release APK" .build/SparkleGame-release.apk
```

Presets and version are defined in `export_presets.cfg`. Do not commit `.godot/export_credentials.cfg` or keystores.

## Project layout

| Path | Role |
|------|------|
| `scenes/main/` | `MainMenu.tscn`, `WorldMap.tscn` |
| `scenes/worlds/` | Seven world scenes (extend `WorldBase`) |
| `scenes/minigames/` | Puzzle, Memory, Sequencing, Drawing |
| `scenes/ui/` | HUD, settings, parent gate, dialogs |
| `scripts/global/` | Autoloads: `GameState`, `SaveManager`, `SceneManager`, `MiniGameManager`, … |
| `scripts/ui/` | Menu, map, shared UI helpers (`MiniGameArt`) |
| `scripts/worlds/WorldBase.gd` | World hub: back button, HUD, mini-game buttons, Sparkle |
| `scripts/characters/SparkleCharacter.gd` | Mascot node (emoji + particles) |
| `assets/` | Graphics, audio, fonts |
| `android/` | Godot Android Gradle template |
| `export_presets.cfg` | Android debug + release AAB/APK |
| `tools/` | UI generator, smoke/test runners, screenshot scripts |

### Autoloads (`project.godot`)

`GameState`, `MiniGameManager`, `SaveManager`, `AudioManager`, `SceneManager`, `DisplayHelper`, `JuiceManager`, `WorldStory`.

### Game flow

1. **Main menu** → Play → **World map**
2. Tap an open island → **World** (`WorldBase`) → mini-game buttons
3. Complete all games in a world → **crystal shard** collected → next world unlocks
4. Seven shards → **crystal finale** on the world map

## Testing

- `tools/smoke_test.gd` — quick headless sanity check
- `tools/test_runner.gd` — broader scripted checks (save migration, routing)
- `tools/emulator_flow.sh` — tap-through on a running emulator (ADB)

Extend tests for new mini-games and save schema changes.

## Contact

**Aleksey Karakuts** — [aleksey@karakuts.com](mailto:aleksey@karakuts.com)

## License

Copyright (C) 2025–2026 Aleksey Karakuts <aleksey@karakuts.com>

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License** as published by the Free Software Foundation, either **version 3** of the License, or (at your option) any later version.

See the [`LICENSE`](LICENSE) file for the full GPLv3 text.
