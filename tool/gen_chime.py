"""Generate the bundled gentle end-chime WAV (offline, stdlib only)."""

import math
import os
import struct
import wave

RATE = 44100
SECS = 1.6
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "chime.wav")

# Two softly struck bell-like partials with exponential decay: calm, not harsh.
PARTIALS = [(659.25, 1.0), (988.78, 0.45), (1318.5, 0.18)]


def main() -> None:
    n = int(RATE * SECS)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        env = math.exp(-3.2 * t) * min(1.0, t / 0.008)  # fast attack, slow decay
        value = sum(amp * math.sin(2 * math.pi * freq * t) for freq, amp in PARTIALS)
        sample = int(max(-1.0, min(1.0, value * env * 0.55)) * 32767)
        frames += struct.pack("<h", sample)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print(f"wrote {OUT} ({len(frames)} bytes)")


if __name__ == "__main__":
    main()
