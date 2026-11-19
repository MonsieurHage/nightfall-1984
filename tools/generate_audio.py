#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Nightfall 1984 - bande-son et SFX originaux, 100 % synthetises (stdlib).

Genere en 44,1 kHz / 16 bits :
  * 5 musiques stereo bouclables (barres alignees, evenements enroules)
  * 17 SFX mono
Normalisation a -1 dBFS, fondus entree/sortie anti-clic, conversion OGG
optionnelle si ffmpeg est present. Aucun audio de film n'est utilise.
Usage : python tools/generate_audio.py [--out-root DIR] [--no-ogg]
"""

from __future__ import annotations

import argparse
import array
import math
import random
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SR = 44100
PEAK = 10.0 ** (-1.0 / 20.0)  # -1 dBFS
TABLE_SIZE = 4096
TABLE_SHIFT = 20  # 4096 = 2^12 ; phase 32 bits -> decalage 20
TABLE_MASK = TABLE_SIZE - 1
PHASE_BITS = 32
PHASE_MASK = (1 << PHASE_BITS) - 1


def log(msg: str) -> None:
    print(f"[generate_audio] {msg}", flush=True)


# ---------------------------------------------------------------------------
# Tables d'onde
# ---------------------------------------------------------------------------

def _make_tables() -> dict[str, array.array]:
    sine = array.array("f", (math.sin(2 * math.pi * i / TABLE_SIZE) for i in range(TABLE_SIZE)))
    saw = array.array("f", (2.0 * i / TABLE_SIZE - 1.0 for i in range(TABLE_SIZE)))
    square = array.array("f", (1.0 if i < TABLE_SIZE // 2 else -1.0 for i in range(TABLE_SIZE)))
    triangle = array.array("f", (
        4.0 * i / TABLE_SIZE - 1.0 if i < TABLE_SIZE // 4 else
        3.0 - 4.0 * i / TABLE_SIZE if i < TABLE_SIZE * 3 // 4 else
        -5.0 + 4.0 * i / TABLE_SIZE for i in range(TABLE_SIZE)
    ))
    # "fat saw" : un peu de 2e harmonique, plus 80's.
    fatsaw = array.array("f", (
        0.85 * saw[i] + 0.15 * sine[(2 * i) & TABLE_MASK] for i in range(TABLE_SIZE)
    ))
    return {"sine": sine, "saw": saw, "square": square, "tri": triangle, "fatsaw": fatsaw}


W = _make_tables()


def hz(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# ---------------------------------------------------------------------------
# Ecriture WAV
# ---------------------------------------------------------------------------

def finalize(buf: array.array, channels: int, fade_s: float = 0.006) -> array.array:
    """Fondus raised-cosine + normalisation exacte a -1 dBFS."""
    n = len(buf) // channels
    fi = max(2, int(SR * fade_s))
    fi = min(fi, n // 4)
    for i in range(fi):
        w = 0.5 - 0.5 * math.cos(math.pi * i / fi)
        j = (n - 1 - i) * channels
        k = i * channels
        for c in range(channels):
            buf[k + c] *= w
            buf[j + c] *= w
    peak = max((abs(x) for x in buf), default=0.0)
    if peak > 1e-9:
        scale = PEAK / peak
        for i in range(len(buf)):
            buf[i] *= scale
    pcm = array.array("h", (int(max(-32768, min(32767, round(x * 32767.0)))) for x in buf))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm


def write_wav(path: Path, buf: array.array, channels: int, fade_s: float = 0.006) -> None:
    pcm = finalize(buf, channels, fade_s)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm.tobytes())
    log(f"{path.name}: {len(pcm) // channels / SR:.2f} s, {channels} ch, {path.stat().st_size // 1024} Ko")


# ---------------------------------------------------------------------------
# Generateurs de base
# ---------------------------------------------------------------------------

def add_osc(bl: array.array, br: array.array, start: int, total: int, freq: float,
            nsamp: int, amp: float, wave_name: str, pan: float = 0.5,
            attack: float = 0.005, decay: float = 0.25, sustain: float = 0.0,
            release: float = 0.03, cutoff: float | None = None,
            detune_cents: float = 0.0) -> None:
    """Ajoute une note (enveloppe ADSR, filtre passe-bas 1 pole, panoramique)."""
    table = W[wave_name]
    if detune_cents:
        freq *= 2.0 ** (detune_cents / 1200.0)
    inc = int(freq * (1 << PHASE_BITS) / SR) & PHASE_MASK
    phase = 0
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR) if cutoff else 0.0
    lp = 0.0
    atk = max(1, int(attack * SR))
    rel = max(1, int(release * SR))
    dec_mul = math.exp(-1.0 / (max(0.01, decay) * SR))
    env_state = 1.0
    gl, gr = math.sqrt(1.0 - pan), math.sqrt(pan)
    for i in range(nsamp):
        phase = (phase + inc) & PHASE_MASK
        x = table[(phase >> TABLE_SHIFT) & TABLE_MASK]
        if a:
            lp += a * (x - lp)
            x = lp
        if i < atk:
            env = i / atk
        else:
            env_state *= dec_mul
            env = sustain + (1.0 - sustain) * env_state
        if i >= nsamp - rel:
            env *= max(0.0, (nsamp - i) / rel)
        v = amp * env * x
        idx = (start + i) % total
        bl[idx] += v * gl
        br[idx] += v * gr


def add_kick(bl: array.array, br: array.array, start: int, total: int,
             amp: float = 0.9, pan: float = 0.5, punch: float = 85.0) -> None:
    n = int(0.34 * SR)
    phase = 0.0
    gl, gr = math.sqrt(1.0 - pan), math.sqrt(pan)
    for i in range(n):
        t = i / SR
        f = 44.0 + punch * math.exp(-t / 0.028)
        phase += 2.0 * math.pi * f / SR
        env = math.exp(-t / 0.13)
        click = 0.22 * math.exp(-t / 0.004) * (1.0 if i % 3 == 0 else -1.0)
        v = amp * (math.sin(phase) * env + click)
        idx = (start + i) % total
        bl[idx] += v * gl
        br[idx] += v * gr


def add_snare(bl: array.array, br: array.array, start: int, total: int,
              rng: random.Random, amp: float = 0.5, pan: float = 0.5) -> None:
    n = int(0.22 * SR)
    gl, gr = math.sqrt(1.0 - pan), math.sqrt(pan)
    phase_f = 0.0
    prev = 0.0
    for i in range(n):
        t = i / SR
        noise = rng.random() * 2.0 - 1.0
        hp = noise - prev
        prev = noise
        phase_f += 2.0 * math.pi * 185.0 / SR
        env = math.exp(-t / 0.075)
        v = amp * (0.55 * hp + 0.35 * math.sin(phase_f)) * env
        idx = (start + i) % total
        bl[idx] += v * gl
        br[idx] += v * gr


def add_hat(bl: array.array, br: array.array, start: int, total: int,
            rng: random.Random, amp: float = 0.22, pan: float = 0.5,
            long: bool = False) -> None:
    n = int((0.16 if long else 0.055) * SR)
    gl, gr = math.sqrt(1.0 - pan), math.sqrt(pan)
    prev = 0.0
    decay = 0.055 if long else 0.014
    for i in range(n):
        noise = rng.random() * 2.0 - 1.0
        hp = noise - prev
        prev = noise
        v = amp * hp * math.exp(-i / (decay * SR))
        idx = (start + i) % total
        bl[idx] += v * gl
        br[idx] += v * gr


def add_clank(bl: array.array, br: array.array, start: int, total: int,
              rng: random.Random, amp: float = 0.18, pan: float = 0.5) -> None:
    n = int(0.28 * SR)
    gl, gr = math.sqrt(1.0 - pan), math.sqrt(pan)
    phases = [rng.random() * 6.28 for _ in range(3)]
    freqs = (617.0, 933.0, 1517.0)
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.055)
        v = 0.0
        for k, f in enumerate(freqs):
            phases[k] += 2.0 * math.pi * f / SR
            v += math.sin(phases[k]) / (k + 1)
        v += 0.35 * (rng.random() * 2.0 - 1.0)
        v *= amp * env
        idx = (start + i) % total
        bl[idx] += v * gl
        br[idx] += v * gr


def add_air(bl: array.array, br: array.array, total: int, rng: random.Random,
            amp: float = 0.03, cutoff: float = 900.0) -> None:
    """Nappe de bruit filtre, loopable (etat de filtre enroule)."""
    lp = 0.0
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    for i in range(total):
        lp += a * ((rng.random() * 2.0 - 1.0) - lp)
        v = amp * lp * (0.75 + 0.25 * math.sin(2.0 * math.pi * i / (SR * 7.0)))
        bl[i] += v * 0.8
        br[i] += v


# ---------------------------------------------------------------------------
# Musiques
# ---------------------------------------------------------------------------

MUSIC = {
    "music_menu": dict(bpm=100, bars=40, seed=1984,
                       chords=[(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)],
                       arp="sine", bass_wave="tri", cutoff=1500, air=0.020,
                       drums="soft", arp_div=2, lead=0.10),
    "music_alley": dict(bpm=112, bars=37, seed=1985,
                        chords=[(57, 60, 64), (55, 59, 62), (53, 57, 60), (52, 56, 59)],
                        arp="square", bass_wave="fatsaw", cutoff=2100, air=0.012,
                        drums="four", arp_div=1, lead=0.12),
    "music_factory": dict(bpm=128, bars=44, seed=1986,
                          chords=[(50, 53, 57), (46, 50, 53), (53, 57, 60), (48, 52, 55)],
                          arp="fatsaw", bass_wave="saw", cutoff=2600, air=0.018,
                          drums="metal", arp_div=1, lead=0.11),
    "music_vents": dict(bpm=120, bars=38, seed=1987,
                        chords=[(48, 51, 55), (44, 48, 51), (51, 55, 58), (46, 50, 53)],
                        arp="sine", bass_wave="saw", cutoff=1200, air=0.055,
                        drums="sparse", arp_div=2, lead=0.13),
    "music_boss": dict(bpm=140, bars=50, seed=1988,
                       chords=[(53, 56, 60), (49, 53, 56), (56, 60, 63), (51, 55, 58)],
                       arp="square", bass_wave="saw", cutoff=3200, air=0.025,
                       drums="boss", arp_div=1, lead=0.15),
}


def render_music(name: str, cfg: dict) -> None:
    rng = random.Random(cfg["seed"])
    bpm, bars = cfg["bpm"], cfg["bars"]
    total = int(round(bars * 4 * 60.0 / bpm * SR))
    bl = array.array("f", [0.0]) * total
    br = array.array("f", [0.0]) * total
    beat = 60.0 / bpm
    bar_len = 4 * beat
    step = beat / 4.0  # croche
    chords = cfg["chords"]

    add_air(bl, br, total, rng, cfg["air"], cfg["cutoff"] * 0.6)

    # Nappe : 3 notes x 2 oscillateurs legers desaccordes, 2 mesures par accord.
    for b in range(0, bars, 2):
        chord = chords[(b // 2) % len(chords)]
        start = int(b * bar_len * SR)
        length = int(min(2 * bar_len, (bars - b) * bar_len) * SR)
        for j, note in enumerate(chord):
            f = hz(note - 12)
            pan = 0.35 if j % 2 == 0 else 0.65
            for cents in (-7.0, 7.0):
                add_osc(bl, br, start, total, f, length, 0.075, "saw", pan,
                        attack=0.45, decay=1e6, sustain=1.0, release=0.55,
                        cutoff=cfg["cutoff"], detune_cents=cents)

    # Basse : croches sur la tonique, avec octave et quinte en syncope.
    bass_pattern = (0, 0, 12, 0, 7, 0, 12, 7)
    for b in range(bars):
        chord = chords[b % len(chords)]
        for s in range(8):
            start = int((b * bar_len + s * beat / 2.0) * SR)
            note = chord[0] - 24 + bass_pattern[s]
            add_osc(bl, br, start, total, hz(note), int(beat * 0.48 * SR),
                    0.30 if cfg["drums"] != "soft" else 0.24, cfg["bass_wave"],
                    pan=0.5, attack=0.004, decay=0.16, sustain=0.35,
                    release=0.035, cutoff=420 if cfg["drums"] != "boss" else 700)

    # Arpege : croches (ou doubles croches en mode soft), avec echoes.
    arp_seq = (0, 1, 2, 1, 2, 0, 1, 2)
    div = cfg["arp_div"]
    for b in range(bars):
        chord = chords[b % len(chords)]
        steps = 16 // div
        for s in range(steps):
            start = int((b * bar_len + s * step * div) * SR)
            note = chord[arp_seq[s % len(arp_seq)]] + 12
            n = int(step * div * 0.85 * SR)
            pan = 0.28 if s % 2 == 0 else 0.72
            add_osc(bl, br, start, total, hz(note), n, cfg["lead"], cfg["arp"],
                    pan=pan, attack=0.002, decay=0.10, sustain=0.05,
                    release=0.04, cutoff=cfg["cutoff"] * 1.6)
            # echoes discrets -> profondeur 80's
            for delay, gain in ((3, 0.28), (6, 0.12)):
                add_osc(bl, br, start + delay * int(step * SR), total, hz(note), n,
                        cfg["lead"] * gain, "sine", pan=1.0 - pan,
                        attack=0.002, decay=0.08, sustain=0.0, release=0.03)

    # Percussions douces : kick / caisse / hats, motif variable selon l'ambiance.
    mode = cfg["drums"]
    for b in range(bars):
        base = b * bar_len
        for s in range(16):
            t = base + s * step
            sub = s % 16
            if mode == "four":
                kick = sub % 4 == 0
                snare = sub in (4, 12)
                hat = sub % 2 == 0
            elif mode == "metal":
                kick = sub in (0, 6, 8, 14)
                snare = sub in (4, 12)
                hat = True
            elif mode == "boss":
                kick = sub % 4 in (0, 2)
                snare = sub % 4 == 0 or sub in (7, 15)
                hat = sub % 2 == 1
            elif mode == "sparse":
                kick = sub in (0, 10)
                snare = sub == 8
                hat = sub in (2, 6, 12, 14)
            else:  # soft
                kick = sub in (0, 8)
                snare = sub == 12 and b % 2 == 1
                hat = sub in (2, 6, 10, 14)
            start = int(t * SR) % total
            if kick:
                add_kick(bl, br, start, total, 0.75 if mode != "boss" else 0.95)
            if snare:
                add_snare(bl, br, start, total, rng, 0.34 if mode != "boss" else 0.48)
            if hat:
                add_hat(bl, br, start, total, rng, 0.14 if mode == "soft" else 0.20,
                        pan=0.38 if s % 2 else 0.62, long=(s % 8 == 6))
            if mode == "metal" and sub in (3, 11):
                add_clank(bl, br, start, total, rng, 0.14, pan=0.3 if sub == 3 else 0.7)
            if mode == "boss" and sub in (5, 13):
                add_clank(bl, br, start, total, rng, 0.10)

    write_wav(ROOT / "assets" / "audio" / f"{name}.wav",
              array.array("f", [v for pair in zip(bl, br) for v in pair]), 2,
              fade_s=0.004)


# ---------------------------------------------------------------------------
# SFX (mono)
# ---------------------------------------------------------------------------

def new_sfx(dur: float) -> array.array:
    return array.array("f", [0.0]) * int(dur * SR)


def tone(buf: array.array, start_s: float, dur: float, f0: float, f1: float,
         amp: float, wave_name: str = "sine", atk: float = 0.004,
         rel: float = 0.05, vib: float = 0.0) -> None:
    start = int(start_s * SR)
    n = min(int(dur * SR), len(buf) - start)
    phase = 0
    atk_n = max(1, int(atk * SR))
    rel_n = max(1, int(rel * SR))
    table = W[wave_name]
    for i in range(n):
        u = i / n
        f = f0 + (f1 - f0) * u
        if vib:
            f *= 1.0 + vib * math.sin(2.0 * math.pi * 6.0 * i / SR)
        phase = (phase + int(f * (1 << PHASE_BITS) / SR)) & PHASE_MASK
        env = min(1.0, i / atk_n)
        if i >= n - rel_n:
            env *= max(0.0, (n - i) / rel_n)
        buf[start + i] += amp * env * table[(phase >> TABLE_SHIFT) & TABLE_MASK]


def noise(buf: array.array, rng: random.Random, start_s: float, dur: float,
          amp: float, decay: float, hp: bool = False, lp: float = 0.0) -> None:
    start = int(start_s * SR)
    n = min(int(dur * SR), len(buf) - start)
    prev = 0.0
    low = 0.0
    a = 1.0 - math.exp(-2.0 * math.pi * lp / SR) if lp else 0.0
    for i in range(n):
        x = rng.random() * 2.0 - 1.0
        if hp:
            x -= prev
            prev = rng.random() * 2.0 - 1.0
        if a:
            low += a * (x - low)
            x = low
        buf[start + i] += amp * x * math.exp(-i / (decay * SR))


def sfx_all(dest: Path) -> None:
    rng = random.Random(4242)

    b = new_sfx(0.38)
    noise(b, rng, 0, 0.12, 0.85, 0.022, hp=True)
    tone(b, 0, 0.30, 190, 62, 0.55, "tri", atk=0.001, rel=0.12)
    write_wav(dest / "sfx_shot.wav", b, 1, 0.004)

    b = new_sfx(0.55)
    noise(b, rng, 0, 0.22, 0.8, 0.055, hp=True)
    tone(b, 0, 0.45, 150, 48, 0.65, "saw", atk=0.001, rel=0.2)
    noise(b, rng, 0.08, 0.3, 0.18, 0.09, lp=900)
    write_wav(dest / "sfx_rifle.wav", b, 1, 0.004)

    b = new_sfx(0.75)
    tone(b, 0, 0.7, 880, 110, 0.55, "sine", atk=0.01, rel=0.18, vib=0.02)
    tone(b, 0.05, 0.6, 1320, 165, 0.18, "tri", atk=0.02, rel=0.2)
    write_wav(dest / "sfx_shrink.wav", b, 1)

    b = new_sfx(0.75)
    tone(b, 0, 0.7, 110, 880, 0.55, "sine", atk=0.01, rel=0.18, vib=0.02)
    tone(b, 0.05, 0.6, 165, 1320, 0.18, "tri", atk=0.02, rel=0.2)
    write_wav(dest / "sfx_grow.wav", b, 1)

    b = new_sfx(0.28)
    tone(b, 0, 0.24, 130, 55, 0.8, "sine", atk=0.001, rel=0.1)
    noise(b, rng, 0, 0.1, 0.32, 0.025, lp=700)
    write_wav(dest / "sfx_hit.wav", b, 1, 0.003)

    b = new_sfx(0.34)
    for k, f in enumerate((430, 710, 1180, 1930)):
        tone(b, 0, 0.30 - k * 0.04, f, f * 0.92, 0.24 / (k + 1), "square", 0.001, 0.12)
    noise(b, rng, 0, 0.10, 0.30, 0.02, hp=True)
    write_wav(dest / "sfx_enemy_hit.wav", b, 1, 0.003)

    b = new_sfx(1.8)
    noise(b, rng, 0, 1.6, 0.75, 0.42, hp=False, lp=1400)
    tone(b, 0, 1.5, 95, 32, 0.62, "sine", atk=0.002, rel=0.6)
    noise(b, rng, 0, 0.12, 0.5, 0.03, hp=True)
    write_wav(dest / "sfx_explosion.wav", b, 1, 0.01)

    b = new_sfx(0.55)
    for i, note in enumerate((72, 76, 79, 84)):
        tone(b, i * 0.075, 0.34, hz(note), hz(note), 0.30, "sine", 0.003, 0.14)
    write_wav(dest / "sfx_pickup.wav", b, 1)

    b = new_sfx(0.8)
    for i, note in enumerate((72, 76, 79, 84)):
        tone(b, i * 0.11, 0.5, hz(note), hz(note), 0.26, "tri", 0.004, 0.2)
    write_wav(dest / "sfx_quiz_ok.wav", b, 1)

    b = new_sfx(0.85)
    for i, note in enumerate((69, 65, 62, 57)):
        tone(b, i * 0.13, 0.42, hz(note), hz(note) * 0.98, 0.28, "fatsaw", 0.004, 0.18)
    write_wav(dest / "sfx_quiz_fail.wav", b, 1)

    b = new_sfx(1.25)
    tone(b, 0, 0.85, 260, 640, 0.25, "saw", 0.05, 0.25)
    tone(b, 0.72, 0.35, 150, 70, 0.45, "tri", 0.005, 0.2)
    noise(b, rng, 0.72, 0.2, 0.30, 0.05, lp=1100)
    write_wav(dest / "sfx_door.wav", b, 1, 0.01)

    b = new_sfx(1.5)
    for i in range(3):
        tone(b, i * 0.5, 0.46, 720, 960, 0.35, "square", 0.02, 0.12)
        tone(b, i * 0.5 + 0.23, 0.24, 960, 720, 0.22, "square", 0.02, 0.1)
    write_wav(dest / "sfx_alarm.wav", b, 1, 0.008)

    b = new_sfx(1.9)
    noise(b, rng, 0, 1.7, 0.55, 0.55, hp=False, lp=2400)
    tone(b, 0, 1.7, 180, 85, 0.32, "saw", 0.08, 0.45, vib=0.015)
    noise(b, rng, 1.2, 0.5, 0.22, 0.2, lp=500)
    write_wav(dest / "sfx_jet.wav", b, 1, 0.02)

    b = new_sfx(0.5)
    noise(b, rng, 0, 0.06, 0.55, 0.012, hp=True)
    tone(b, 0.10, 0.32, 320, 520, 0.22, "sine", 0.01, 0.15)
    noise(b, rng, 0.38, 0.08, 0.35, 0.015, hp=True)
    write_wav(dest / "sfx_camera.wav", b, 1, 0.003)

    b = new_sfx(0.2)
    noise(b, rng, 0, 0.12, 0.42, 0.028, lp=750)
    tone(b, 0, 0.14, 95, 60, 0.35, "sine", 0.001, 0.07)
    write_wav(dest / "sfx_footstep.wav", b, 1, 0.003)

    b = new_sfx(0.16)
    tone(b, 0, 0.13, 1320, 1180, 0.42, "sine", 0.001, 0.06)
    write_wav(dest / "sfx_ui.wav", b, 1, 0.002)

    b = new_sfx(0.95)
    for i, amp in enumerate((0.75, 0.5)):
        tone(b, i * 0.27, 0.23, 82, 48, amp, "sine", 0.006, 0.12)
        noise(b, rng, i * 0.27, 0.08, 0.10 * amp, 0.025, lp=220)
    write_wav(dest / "sfx_heartbeat.wav", b, 1, 0.008)


# ---------------------------------------------------------------------------

def convert_ogg(dest: Path, enabled: bool) -> None:
    if not enabled:
        return
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        log("ffmpeg absent -> OGG ignores")
        return
    for wav in sorted(dest.glob("music_*.wav")):
        ogg = wav.with_suffix(".ogg")
        cmd = [ffmpeg, "-y", "-i", str(wav), "-codec:a", "libvorbis", "-q:a", "6", str(ogg)]
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if res.returncode != 0:
            cmd = [ffmpeg, "-y", "-i", str(wav), "-codec:a", "libvorbis", "-qscale:a", "6", str(ogg)]
            res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if res.returncode == 0 and ogg.is_file():
            log(f"{ogg.name}: {ogg.stat().st_size // 1024} Ko")
        else:
            log(f"{ogg.name}: conversion impossible (WAV conserve)")


def main() -> int:
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-root", type=Path, default=ROOT, help="racine de sortie (test)")
    parser.add_argument("--no-ogg", action="store_true", help="ne pas convertir en OGG")
    args = parser.parse_args()
    ROOT = args.out_root.resolve()
    dest = ROOT / "assets" / "audio"
    dest.mkdir(parents=True, exist_ok=True)
    log(f"sortie: {dest}")
    for name, cfg in MUSIC.items():
        render_music(name, cfg)
    sfx_all(dest)
    convert_ogg(dest, not args.no_ogg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
