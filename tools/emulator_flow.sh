#!/usr/bin/env bash
# Автопрогон основного игрового flow на Android-эмуляторе.
set -euo pipefail

PKG="${PKG:-com.sparklegame.sparkle}"
ACT="${ACT:-com.godot.game.GodotAppLauncher}"
DEVICE="${DEVICE:-emulator-5554}"
ADB_BIN="${ADB_BIN:-$HOME/Library/Android/sdk/platform-tools/adb}"
ADB=("$ADB_BIN" -s "$DEVICE")
OUT_DIR="${OUT_DIR:-.build/android-e2e}"

mkdir -p "$OUT_DIR"

wm_size="$("${ADB[@]}" shell wm size | tr -d '\r')"
size="${wm_size##*: }"
screen_w="${size%x*}"
screen_h="${size#*x}"

sx() { awk -v v="$1" -v w="$screen_w" 'BEGIN { printf "%d", v * w / 1280 }'; }
sy() { awk -v v="$1" -v h="$screen_h" 'BEGIN { printf "%d", v * h / 2856 }'; }

tap() {
	"${ADB[@]}" shell input tap "$(sx "$1")" "$(sy "$2")"
	sleep "${3:-1}"
}

swipe() {
	"${ADB[@]}" shell input swipe "$(sx "$1")" "$(sy "$2")" "$(sx "$3")" "$(sy "$4")" "${5:-600}"
	sleep "${6:-1}"
}

screenshot() {
	"${ADB[@]}" exec-out screencap -p > "$OUT_DIR/$1.png"
}

assert_clean_log() {
	local log_file="$OUT_DIR/logcat.txt"
	"${ADB[@]}" logcat -d -t 500 > "$log_file"
	if rg -i "SCRIPT ERROR|FATAL EXCEPTION|ERROR:" "$log_file"; then
		echo "ANDROID_E2E_FAIL: errors found in $log_file" >&2
		exit 1
	fi
}

"${ADB[@]}" wait-for-device
"${ADB[@]}" logcat -c || true
"${ADB[@]}" shell am force-stop "$PKG"
"${ADB[@]}" shell am start -n "$PKG/$ACT"
sleep "${START_WAIT:-10}"
screenshot "01_menu"

tap 640 1510 2   # Играть
screenshot "02_world_map"
tap 640 480 3    # Лес
screenshot "03_forest"

tap 237 650 3    # Сортировка
screenshot "04_sorting_open"
swipe 142 638 142 2100 900 1
screenshot "05_sorting_after_drag"
tap 92 240 2     # Назад в мир

tap 640 1130 3   # Рисование
screenshot "06_drawing_open"
swipe 250 650 950 1350 900 1
screenshot "07_drawing_after_swipe"
	tap 1007 2400 3  # Готово
screenshot "08_after_drawing_done"

assert_clean_log
echo "ANDROID_E2E_OK: flow completed on $DEVICE ($screen_w x $screen_h)"
