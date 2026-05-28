#!/usr/bin/env python3
"""
Генератор звуковых эффектов и музыкальных тем для «Искорка и Кристалл Дружбы».
Создаёт .wav, затем конвертирует в .ogg через ffmpeg.
Запуск: python3 tools/gen_audio.py
"""

import os
import struct
import math
import subprocess
import shutil

SR = 44100   # sample rate


# ── WAV writer ────────────────────────────────────────────────────

def write_wav(path: str, samples: list[float]) -> None:
    n = len(samples)
    pcm = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        pcm += struct.pack("<h", int(v * 32767))
    with open(path, "wb") as f:
        # RIFF header
        data_size = len(pcm)
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + data_size))
        f.write(b"WAVE")
        # fmt chunk
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16))   # chunk size
        f.write(struct.pack("<H", 1))    # PCM
        f.write(struct.pack("<H", 1))    # mono
        f.write(struct.pack("<I", SR))
        f.write(struct.pack("<I", SR * 2))
        f.write(struct.pack("<H", 2))    # block align
        f.write(struct.pack("<H", 16))   # bits
        # data chunk
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        f.write(pcm)


def to_ogg(wav: str, ogg: str) -> None:
    # пробуем oggenc (vorbis-tools), затем ffmpeg libvorbis, затем opus fallback
    try:
        subprocess.run(
            ["oggenc", "-q", "4", "-o", ogg, wav],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except subprocess.CalledProcessError:
            subprocess.run(
                ["ffmpeg", "-y", "-i", wav, "-c:a", "libopus", "-ar", "48000", "-b:a", "64k", ogg],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
    os.unlink(wav)


# ── primitives ────────────────────────────────────────────────────

def silence(dur: float) -> list[float]:
    return [0.0] * int(SR * dur)


def sine(freq: float, dur: float, amp: float = 0.5, phase: float = 0.0) -> list[float]:
    n = int(SR * dur)
    return [amp * math.sin(2 * math.pi * freq * i / SR + phase) for i in range(n)]


def adsr(sig: list[float], a: float, d: float, s_level: float, r: float) -> list[float]:
    n = len(sig)
    out = []
    a_n = int(SR * a)
    d_n = int(SR * d)
    r_n = int(SR * r)
    s_n = n - a_n - d_n - r_n
    if s_n < 0:
        s_n = 0
    for i, x in enumerate(sig):
        if i < a_n:
            env = i / a_n if a_n else 1.0
        elif i < a_n + d_n:
            env = 1.0 - (1.0 - s_level) * (i - a_n) / d_n if d_n else s_level
        elif i < a_n + d_n + s_n:
            env = s_level
        else:
            ri = i - (a_n + d_n + s_n)
            env = s_level * (1.0 - ri / r_n) if r_n else 0.0
        out.append(x * max(0.0, env))
    return out


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, x in enumerate(t):
            out[i] += x
    peak = max(abs(x) for x in out) or 1.0
    if peak > 0.95:
        out = [x / peak * 0.9 for x in out]
    return out


def concat(*tracks: list[float]) -> list[float]:
    out = []
    for t in tracks:
        out.extend(t)
    return out


def fade(sig: list[float], fade_in: float = 0.01, fade_out: float = 0.05) -> list[float]:
    n = len(sig)
    fi = int(SR * fade_in)
    fo = int(SR * fade_out)
    out = sig[:]
    for i in range(min(fi, n)):
        out[i] *= i / fi
    for i in range(min(fo, n)):
        out[n - 1 - i] *= i / fo
    return out


def noise(dur: float, amp: float = 0.3) -> list[float]:
    import random
    n = int(SR * dur)
    return [amp * (random.random() * 2 - 1) for _ in range(n)]


# ── SFX generators ────────────────────────────────────────────────

def gen_tap() -> list[float]:
    # Лёгкий клик — короткий импульс + немного шума
    sig = mix(
        adsr(sine(1200, 0.06, 0.35), 0.001, 0.02, 0.1, 0.04),
        adsr(noise(0.06, 0.2), 0.001, 0.01, 0.05, 0.04),
    )
    return fade(sig, 0.001, 0.02)


def gen_transition() -> list[float]:
    # Свист вверх
    n = int(SR * 0.35)
    sig = []
    for i in range(n):
        t = i / n
        freq = 300 + 900 * t
        sig.append(0.4 * math.sin(2 * math.pi * freq * i / SR))
    return fade(adsr(sig, 0.01, 0.1, 0.4, 0.15), 0.01, 0.1)


def gen_success() -> list[float]:
    # Мажорный аккорд С4-E4-G4
    c4, e4, g4 = 261.63, 329.63, 392.00
    dur = 0.9
    chord = mix(
        adsr(sine(c4, dur, 0.28), 0.01, 0.05, 0.6, 0.4),
        adsr(sine(e4, dur, 0.25), 0.01, 0.05, 0.6, 0.4),
        adsr(sine(g4, dur, 0.22), 0.01, 0.05, 0.6, 0.4),
        adsr(sine(c4 * 2, dur, 0.18), 0.01, 0.05, 0.5, 0.4),
    )
    return fade(chord, 0.01, 0.2)


def gen_complete() -> list[float]:
    # Фанфара: восходящие ноты + финальный аккорд
    c4, e4, g4, c5 = 261.63, 329.63, 392.00, 523.25
    notes = [(c4, 0.15), (e4, 0.15), (g4, 0.15), (c5, 0.5)]
    seg = []
    for freq, dur in notes:
        s = adsr(sine(freq, dur, 0.45), 0.005, 0.05, 0.55, 0.1)
        seg.append(fade(s, 0.005, 0.05))
    track = concat(*seg)
    # затем финальный аккорд
    chord_dur = 1.2
    chord = mix(
        adsr(sine(c4, chord_dur, 0.3), 0.01, 0.05, 0.65, 0.5),
        adsr(sine(e4, chord_dur, 0.25), 0.01, 0.05, 0.65, 0.5),
        adsr(sine(g4, chord_dur, 0.22), 0.01, 0.05, 0.65, 0.5),
        adsr(sine(c5, chord_dur, 0.20), 0.01, 0.05, 0.65, 0.5),
    )
    return concat(track, fade(chord, 0.01, 0.4))


def gen_wrong() -> list[float]:
    # Низкое «бу»
    sig = mix(
        adsr(sine(120, 0.45, 0.4), 0.01, 0.05, 0.5, 0.3),
        adsr(sine(90, 0.45, 0.3), 0.01, 0.05, 0.5, 0.3),
        adsr(noise(0.45, 0.12), 0.01, 0.05, 0.3, 0.3),
    )
    return fade(sig, 0.01, 0.15)


def gen_dialog() -> list[float]:
    # Мягкое «дзинь» — флейтовая нота
    f5 = 698.46
    sig = mix(
        adsr(sine(f5, 0.5, 0.32), 0.01, 0.05, 0.45, 0.35),
        adsr(sine(f5 * 2, 0.5, 0.1), 0.01, 0.05, 0.25, 0.35),
    )
    return fade(sig, 0.01, 0.2)


def gen_shard() -> list[float]:
    # Кристальный звон — высокие обертоны с долгим затуханием
    freqs = [1047, 1319, 1568, 2093]  # C6, E6, G6, C7
    parts = []
    for i, f in enumerate(freqs):
        amp = 0.32 - i * 0.04
        dur = 1.2 - i * 0.1
        parts.append(adsr(sine(f, dur, amp), 0.003, 0.02, 0.5, dur - 0.1))
    return fade(mix(*parts), 0.003, 0.4)


# ── Music generators ──────────────────────────────────────────────
# Каждая музыкальная тема — 8-секундный петлеобразный амбиент.

def _ambient_loop(base_freqs: list[float], bpm: float = 80) -> list[float]:
    """Простой амбиент-луп из нескольких синусоид разной длины."""
    dur = 8.0
    parts = []
    for i, f in enumerate(base_freqs):
        amp = 0.18 - i * 0.02
        phase = i * math.pi / len(base_freqs)
        parts.append(adsr(sine(f, dur, amp, phase), 0.5, 0.5, 0.8, 1.0))
    # ритмическая пульсация на одной из нот
    pulse_f = base_freqs[0]
    beat_dur = 60.0 / bpm
    pulse = []
    while len(pulse) < int(SR * dur):
        n = int(SR * beat_dur)
        seg = adsr(sine(pulse_f, beat_dur, 0.1), 0.01, 0.05, 0.5, beat_dur * 0.5)
        pulse.extend(seg[:n])
    pulse = pulse[:int(SR * dur)]
    parts.append(pulse)
    sig = mix(*parts)
    # плавное начало и конец для бесшовного лупа
    return fade(sig, fade_in=0.5, fade_out=0.5)


WORLD_THEMES = [
    # мир 0 – Лес (мажор, спокойный)
    [261.63, 329.63, 392.00, 523.25, 659.25],
    # мир 1 – Ледники (пентатоника, прохладная)
    [220.00, 293.66, 329.63, 440.00, 587.33],
    # мир 2 – Облачные сады (светлый мажор, высокий)
    [349.23, 440.00, 523.25, 698.46, 880.00],
    # мир 3 – Подводный город (минор, медленно)
    [196.00, 233.08, 293.66, 392.00, 466.16],
    # мир 4 – Пустыня (пентатоника, экзотика)
    [174.61, 220.00, 261.63, 349.23, 440.00],
    # мир 5 – Механическая роща (minor, ритмичный)
    [185.00, 220.00, 277.18, 369.99, 440.00],
    # мир 6 – Страна Снов (тихий, мистика)
    [311.13, 369.99, 493.88, 622.25, 739.99],
    # мир 7 – финальный кристалл
    [261.63, 329.63, 392.00, 493.88, 659.25],
]


def gen_music(world_id: int) -> list[float]:
    freqs = WORLD_THEMES[world_id]
    bpm = [75, 70, 85, 65, 80, 90, 60, 72][world_id]
    return _ambient_loop(freqs, bpm)


# ── Main ──────────────────────────────────────────────────────────

def main():
    base = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    sfx_dir = os.path.join(base, "sfx")
    music_dir = os.path.join(base, "music")

    sfx = {
        "tap":        gen_tap,
        "transition": gen_transition,
        "success":    gen_success,
        "complete":   gen_complete,
        "wrong":      gen_wrong,
        "dialog":     gen_dialog,
        "shard":      gen_shard,
    }

    print("Generating SFX...")
    for name, fn in sfx.items():
        ogg_path = os.path.join(sfx_dir, f"{name}.ogg")
        wav_path = ogg_path.replace(".ogg", "_tmp.wav")
        print(f"  {name}.ogg")
        write_wav(wav_path, fn())
        to_ogg(wav_path, ogg_path)

    print("Generating music loops...")
    for world_id in range(8):
        ogg_path = os.path.join(music_dir, f"music_{world_id}.ogg")
        wav_path = ogg_path.replace(".ogg", "_tmp.wav")
        print(f"  music_{world_id}.ogg  (world {world_id})")
        write_wav(wav_path, gen_music(world_id))
        to_ogg(wav_path, ogg_path)

    print("Done.")


if __name__ == "__main__":
    main()
