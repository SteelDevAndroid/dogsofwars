#!/usr/bin/env python3
"""Synthesises the sound effects of the game (assets/audio/*.wav): original, made from sine waves,
noise and envelopes, with the standard library only, so they have no outside licence (the
authors release them under CC0). Deterministic: the noise comes from a seeded generator, so a
second run writes the same bytes.

Usage: make_sounds.py [output directory]   (default: assets/audio next to the repository root)
16-bit mono, 22 050 Hz, peak at -4 dB, 5 ms fades at both ends.
"""
import math
import pathlib
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 0.63


def tone(freq, length, shape="sine", decay=6.0, f_end=None, tremolo=0.0):
    n = int(RATE * length)
    out = []
    phase = 0.0
    for k in range(n):
        t = k / RATE
        f = freq if f_end is None else freq + (f_end - freq) * (k / n)
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        if shape == "square":
            s = 1.0 if s >= 0 else -1.0
            s *= 0.5
        elif shape == "saw":
            s = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
            s *= 0.6
        env = math.exp(-decay * t / length)
        if tremolo:
            env *= 1.0 - tremolo * (0.5 + 0.5 * math.sin(2 * math.pi * 14 * t))
        out.append(s * env)
    return out


def noise(length, decay=8.0, low_pass=1.0, sweep=0.0, seed=1):
    rng = random.Random(seed)
    n = int(RATE * length)
    out = []
    y = 0.0
    for k in range(n):
        alpha = min(1.0, low_pass + sweep * (k / n))
        y += alpha * (rng.uniform(-1, 1) - y)
        out.append(y * math.exp(-decay * k / n))
    return out


def mix(*tracks):
    n = max(len(track) for track, _ in tracks)
    return [sum(track[k] * gain if k < len(track) else 0.0 for track, gain in tracks) for k in range(n)]


def delay(track, seconds):
    return [0.0] * int(RATE * seconds) + track


def bell(freq, length=0.6, decay=5.0):
    return mix((tone(freq, length, decay=decay), 1.0), (tone(freq * 2.0, length, decay=decay * 1.5), 0.35),
               (tone(freq * 3.01, length, decay=decay * 2.0), 0.15))


def finish(samples):
    peak = max(abs(s) for s in samples) or 1.0
    fade = int(RATE * 0.005)
    out = []
    for k, s in enumerate(samples):
        g = PEAK / peak
        if k < fade:
            g *= k / fade
        if k > len(samples) - fade:
            g *= max(0.0, (len(samples) - k) / fade)
        out.append(int(max(-1.0, min(1.0, s * g)) * 32767))
    return out


def sounds():
    s = {}
    s["ui_tap"] = mix((tone(1200, 0.06, decay=9), 1.0), (noise(0.012, decay=4, seed=2), 0.3))
    s["ui_back"] = tone(900, 0.08, decay=6, f_end=600)
    s["select"] = tone(600, 0.1, decay=4, f_end=900)
    s["move"] = mix((noise(0.2, decay=3, low_pass=0.05, sweep=0.5, seed=3), 1.0), (tone(110, 0.2, decay=5), 0.4))
    s["attack"] = mix((noise(0.25, decay=9, low_pass=0.6, seed=4), 0.8), (tone(95, 0.25, decay=8, f_end=55), 1.0))
    s["destroyed"] = mix((tone(300, 0.5, "saw", decay=5, f_end=60), 0.8), (noise(0.5, decay=6, low_pass=0.3, seed=5), 0.5))
    s["threat"] = mix((tone(440, 0.45, "square", decay=2.5), 0.25), (delay(tone(330, 0.3, "square", decay=2.5), 0.15), 0.25))
    s["wake"] = tone(220, 0.35, decay=2.5, f_end=880, tremolo=0.5)
    s["capture"] = mix((bell(523, 0.5), 1.0), (delay(bell(659, 0.45), 0.09), 0.9), (delay(bell(784, 0.4), 0.18), 0.8))
    s["fragment"] = mix((bell(440, 1.0, 4), 1.0), (delay(bell(659, 0.9, 4), 0.18), 0.8), (delay(bell(880, 0.8, 4), 0.36), 0.7))
    s["turn"] = mix((bell(392, 0.35, 7), 1.0), (delay(bell(523, 0.4, 7), 0.12), 1.0))
    s["refusal"] = mix((tone(140, 0.07, "square", decay=3), 0.6), (delay(tone(130, 0.07, "square", decay=3), 0.1), 0.6))
    s["victory"] = mix(*[(delay(bell(f, 0.7, 5), d), 1.0) for f, d in [(523, 0.0), (659, 0.15), (784, 0.3), (1046, 0.45)]])
    s["defeat"] = mix(*[(delay(bell(f, 0.8, 4), d), 1.0) for f, d in [(440, 0.0), (349, 0.22), (294, 0.44), (220, 0.66)]])
    return s


def write(directory: pathlib.Path) -> list:
    directory.mkdir(parents=True, exist_ok=True)
    names = []
    for name, samples in sorted(sounds().items()):
        with wave.open(str(directory / (name + ".wav")), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", v) for v in finish(samples)))
        names.append(name)
    return names


if __name__ == "__main__":
    target = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2] / "assets" / "audio"
    print(" ".join(write(target)))
