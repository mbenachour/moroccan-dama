#!/usr/bin/env python3
"""Synthesizes the Dama sound pack — no recorded assets, everything is
generated so the .wav files in MoroccanDama/Sounds/ can be reproduced or
retuned at any time:  python3 tools/make_sounds.py

- nfokh-puff.wav    the huff: a breath of air (band-swept noise burst)
- piece-tok.wav     a wooden piece set down on the board
- capture-clatter.wav  bottle caps clattering as pieces are taken
- crown-chime.wav   a soft two-note chime when a man becomes a dama
- win.wav / lose.wav   short marimba-like phrases
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "MoroccanDama", "Sounds")


def write_wav(name, samples):
    path = os.path.join(OUT, name)
    os.makedirs(OUT, exist_ok=True)
    peak = max(abs(s) for s in samples) or 1.0
    samples = [s / peak * 0.85 for s in samples]
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print("wrote", path, len(samples) / SR, "s")


def puff():
    random.seed(19)
    n = int(SR * 0.55)
    out, lp1, lp2 = [], 0.0, 0.0
    for i in range(n):
        t, p = i / SR, i / n
        env = (1 - math.exp(-t / 0.012)) * math.exp(-t / 0.16) * (1 - 0.25 * p)
        alpha = 0.55 - 0.42 * p  # sweeping lowpass: hiss -> soft blow
        white = random.uniform(-1, 1)
        lp1 += alpha * (white - lp1)
        lp2 += alpha * (lp1 - lp2)
        out.append((lp2 * 1.6 + (lp1 - lp2) * 0.9) * env)
    return out


def tok(dur=0.10, f0=210, seed=7, gain=1.0):
    random.seed(seed)
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.018)
        f = f0 - 700 * t
        out.append((math.sin(2 * math.pi * f * t) * env * 0.8
                    + random.uniform(-1, 1) * math.exp(-t / 0.004) * 0.35) * gain)
    return out


def clatter():
    random.seed(23)
    n = int(SR * 0.34)
    out = [0.0] * n
    # Two cap strikes plus a short metallic scrape between them.
    for start, f0, seed in ((0.0, 260, 11), (0.13, 190, 12)):
        hit = tok(0.12, f0, seed)
        off = int(start * SR)
        for i, s in enumerate(hit):
            if off + i < n:
                out[off + i] += s
    hp = 0.0
    for i in range(n):
        t = i / SR
        if 0.03 < t < 0.13:  # sliding scrape of caps across the board
            white = random.uniform(-1, 1)
            hp = 0.72 * hp + 0.28 * white
            out[i] += (white - hp) * 0.20 * math.sin(math.pi * (t - 0.03) / 0.10)
    return out


def tone(freq, dur, delay=0.0, total=0.6, gain=0.5):
    n = int(SR * total)
    out = [0.0] * n
    off = int(delay * SR)
    for i in range(int(SR * dur)):
        t = i / SR
        env = math.exp(-t / (dur * 0.45))
        s = (math.sin(2 * math.pi * freq * t)
             + 0.4 * math.sin(2 * math.pi * freq * 2 * t)
             + 0.15 * math.sin(2 * math.pi * freq * 3 * t)) * env * gain
        if off + i < n:
            out[off + i] += s
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


write_wav("nfokh-puff.wav", puff())
write_wav("piece-tok.wav", tok())
write_wav("capture-clatter.wav", clatter())
write_wav("crown-chime.wav", mix(tone(1318.5, 0.35, 0.0, 0.55), tone(1975.5, 0.4, 0.09, 0.55)))
write_wav("win.wav", mix(tone(523.25, 0.3, 0.0, 0.7), tone(659.25, 0.3, 0.12, 0.7), tone(783.99, 0.45, 0.24, 0.7)))
write_wav("lose.wav", mix(tone(392.0, 0.35, 0.0, 0.65), tone(329.63, 0.5, 0.16, 0.65)))
