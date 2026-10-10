#!/usr/bin/env python3
"""Rebuild original audio assets using the Python standard library. No downloads."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
OUT = ROOT / "assets" / "audio"


def write(name: str, samples: list[float]) -> None:
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def ambience() -> None:
    rng = random.Random(731204)
    result = []
    filtered = 0.0
    duration = 24.0
    # Integer cycles make the drone wrap seamlessly; the noise fades at the seam.
    for i in range(int(duration * RATE)):
        t = i / RATE
        filtered = filtered * .96 + rng.uniform(-1, 1) * .04
        fade = min(1, t / 2, (duration - t) / 2)
        drone = .12 * math.sin(math.tau * 41 * t) * (.8 + .2 * math.sin(math.tau * t / duration))
        drone += .045 * math.sin(math.tau * 82 * t) + .025 * math.sin(math.tau * 123 * t)
        air = filtered * .24 * fade
        chime = 0.0
        for start, frequency in [(3, 246.94), (9, 293.66), (15, 369.99), (20, 220.0)]:
            age = t - start
            if 0 <= age < 3:
                envelope = (1 - math.exp(-age * 12)) * math.exp(-age * 1.8)
                chime += .065 * envelope * math.sin(math.tau * frequency * age)
        result.append(drone + air + chime)
    write("earth.wav", result)


def tone(name: str, notes: list[float], seconds: float = .6) -> None:
    result = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        total = 0.0
        for n, frequency in enumerate(notes):
            age = t - n * .07
            if age >= 0:
                env = (1 - math.exp(-age * 120)) * math.exp(-age * 8) * max(0, 1 - t / seconds)
                total += math.sin(math.tau * frequency * age) * env * .23 / len(notes)
        result.append(total)
    write(name, result)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    ambience()
    tone("collect.wav", [440, 554.37, 659.25])
    tone("pulse.wav", [174.61, 220, 261.63], 1)
    tone("evolve.wav", [293.66, 369.99, 440, 587.33], .9)
    tone("return.wav", [329.63, 261.63, 220], .8)
    tone("dig.wav", [67, 93], .08)
    print("Rebuilt six original audio assets.")
