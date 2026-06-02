# Искорка и Кристалл Дружбы

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

English: [README.md](README.md)

Детская портретная игра для **Android**: семь тематических миров, мини-игры, сбор осколков кристалла и альбом наклеек. **Godot 4.6**, **GDScript**.

| | |
|---|---|
| Пакет | `com.sparklegame.sparkle` |
| Версия | `1.3.1` (`export_presets.cfg`) |
| Движок | Godot 4.6.3, рендер `gl_compatibility` |
| Экран | Портрет 1080×1920, масштаб через `DisplayHelper` |

## Возможности

- **Сюжет** — Искорка ведёт игрока по семи мирам, чтобы восстановить **Кристалл Дружбы** (по одному осколку за пройденный мир).
- **Карта миров** — острова, статусы «закрыт / открыт / пройден», подсказки, вход в альбом наклеек.
- **Мини-игры** — **сортировка**, **память**, **последовательность**, **рисование**; сложность 1–5 по мирам.
- **Сохранения** — JSON в `user://`, три слота, миграция схемы (`SaveManager`), родительские ворота (задача + лимит экранного времени).
- **Интерфейс** — PNG из `tools/gen_minigame_ui_assets.py`, фоны WOW, safe-area, эффекты `JuiceManager`.

## CI и автоматизация

| Workflow | Когда | Задача |
|----------|-------|--------|
| [CI](.github/workflows/ci.yml) | push / PR в `master` | Godot: `smoke_test`, `test_runner` |
| [Security](.github/workflows/security.yml) | push / PR в `master`, по расписанию | OSV-сканирование |
| [Release](.github/workflows/release.yml) | тег `v*` | Подписанные **APK + AAB** и GitHub Release (нужны secrets) |

Подпись release и секреты GitHub — в [README.md](README.md#release-signing-rustore--github-actions) (как у [шашек](https://github.com/akarakuts/russiancheckers)).

## Требования и сборка

Как в [README.md](README.md): Godot 4.6.3 с Android export templates, JDK 11+ для Gradle AAB.

### Отладочный APK

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --export-debug "Android" .build/SparkleGame.apk
adb install -r .build/SparkleGame.apk
adb shell am start -n com.sparklegame.sparkle/com.godot.game.GodotAppLauncher
```

### Редактор

Главная сцена: `res://scenes/main/MainMenu.tscn`.

### Пересборка UI-картинок

```bash
python3 tools/gen_minigame_ui_assets.py
```

### Release-сборки

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --export-release "Android Release AAB" .build/SparkleGame-release.aab
.tools/Godot.app/Contents/MacOS/Godot --headless --export-release "Android Release APK" .build/SparkleGame-release.apk
```

Версия и пресеты — в `export_presets.cfg`. Не коммитить `.godot/export_credentials.cfg` и keystore.

Тег `v*` на GitHub собирает `sparkle-<тег>.apk` и `.aab` (см. Release workflow). RuStore-выкладка — в `~/Bars/rustore/sparkle-store/` (вне репозитория).

## Структура проекта

| Путь | Назначение |
|------|------------|
| `scripts/global/` | Автозагрузки: прогресс, сцены, сохранения, звук |
| `scripts/ui/` | Меню, карта, HUD, общие UI-хелперы |
| `scripts/worlds/WorldBase.gd` | Базовый мир: кнопки мини-игр, HUD, Искорка |
| `scenes/worlds/` | Семь миров (наследуют `WorldBase`) |
| `scenes/minigames/` | Четыре типа мини-игр |
| `export_presets.cfg` | Debug APK и release AAB/APK |

### Цикл игры

Меню → карта → мир → мини-игры → осколок → открытие следующего мира → финал при 7/7.

## Проверки

- `tools/smoke_test.gd`, `tools/test_runner.gd`
- `tools/emulator_flow.sh` — сценарий на эмуляторе через ADB

## Контакты

**Aleksey Karakuts** — [aleksey@karakuts.com](mailto:aleksey@karakuts.com)

## Лицензия

Copyright (C) 2025–2026 Aleksey Karakuts <aleksey@karakuts.com>

Программа распространяется на условиях **GNU General Public License** версии **3** (или любой более поздней версии, на ваш выбор).

Полный текст — в файле [`LICENSE`](LICENSE).
