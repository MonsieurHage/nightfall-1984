#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Nightfall 1984 - telechargement des ressources CC0 / OFL (stdlib uniquement).

- 5 sets PBR Poly Haven en JPG 1k (diffuse / nor_gl / rough / AO)
- 1 HDRI nocturne Poly Haven en 1k .hdr
- Orbitron Bold + Rajdhani SemiBold (Google Fonts) et leurs licences OFL

En cas d'echec reseau, des substituts proceduraux valides (JPEG baseline ecrit
a la main, HDR Radiance) sont generes afin qu'aucun fichier ne manque.
Usage : python tools/fetch_assets.py [--force-procedural] [--out-root DIR]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import re
import struct
import sys
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {
    "User-Agent": "Mozilla/5.0 (compatible; Nightfall1984/1.0; +https://polyhaven.com)",
    "Accept": "*/*",
}
API = "https://api.polyhaven.com"

# Sets PBR : premier ID = choix principal, les autres = replis.
SETS = {
    "asphalt": ["asphalt_01", "asphalt_track", "asphalt_03", "clean_asphalt", "asphalt_02"],
    "concrete": ["concrete_floor_01", "concrete", "concrete_floor_02", "concrete_floor", "brushed_concrete"],
    "metal": ["metal_plate", "metal_plate_02", "blue_metal_plate", "green_metal_rust", "rusty_metal_sheet"],
    "rust": ["rust_coarse_01", "rusty_metal_02", "rusty_metal_03", "rusty_metal_05", "rusty_painted_metal"],
    "panel": ["factory_wall", "container_side", "rectangular_facade_tiles", "concrete_tile_facade", "painted_metal_shutter"],
}
# Correspondance API Poly Haven -> suffixe de fichier attendu.
CHANNELS = [("Diffuse", "diffuse"), ("nor_gl", "normal"), ("Rough", "rough"), ("AO", "ao")]
HDRI_CANDIDATES = [
    "rogland_clear_night", "night_bridge", "cobblestone_street_night",
    "courtyard_night", "modern_buildings_night", "satara_night_no_lamps",
]
# Empreinte d'un commit ou se trouve l'ancien TTF statique Orbitron Bold.
ORBITRON_COMMIT = "c8e3197f63e4ff7b487f69f76cf17bcc023c980c"
FONTS = {
    "Orbitron-Bold.ttf": [
        f"https://raw.githubusercontent.com/google/fonts/{ORBITRON_COMMIT}/ofl/orbitron/Orbitron-Bold.ttf",
        f"https://cdn.jsdelivr.net/gh/google/fonts@{ORBITRON_COMMIT}/ofl/orbitron/Orbitron-Bold.ttf",
    ],
    "Rajdhani-SemiBold.ttf": [
        "https://raw.githubusercontent.com/google/fonts/main/ofl/rajdhani/Rajdhani-SemiBold.ttf",
        "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/rajdhani/Rajdhani-SemiBold.ttf",
    ],
}
LICENSE_URLS = {
    "Orbitron-OFL.txt": f"https://raw.githubusercontent.com/google/fonts/{ORBITRON_COMMIT}/ofl/orbitron/OFL.txt",
    "Rajdhani-OFL.txt": "https://raw.githubusercontent.com/google/fonts/main/ofl/rajdhani/OFL.txt",
}
OFL_FALLBACK = """SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining a
copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components, in
   Original or Modified Versions, may be sold by itself.
2) Original or Modified Versions of the Font Software may be bundled,
   redistributed and/or sold with any software, provided that each copy
   contains the above copyright notice and this license.
3) No Modified Version of the Font Software may use the Reserved Font
   Name(s) unless explicit written permission is granted by the
   corresponding Copyright Holder.
4) The name(s) of the Copyright Holder(s) or the Author(s) shall not be
   used to promote, endorse or advertise any Modified Version, except to
   acknowledge the contribution(s) of the Copyright Holder(s) and the
   Author(s) or with their explicit written permission.
5) The Font Software, modified or unmodified, in part or in whole, must be
   distributed entirely under this license, and must not be distributed
   under any other license. The requirement for fonts to remain under
   this license does not apply to any document created using the Font
   Software.

TERMINATION
This license becomes null and void if any of the above conditions are not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
"""

PROGRESS: dict[str, dict] = {}


def log(msg: str) -> None:
    print(f"[fetch_assets] {msg}", flush=True)


# ---------------------------------------------------------------------------
# Reseau
# ---------------------------------------------------------------------------

def http_get(url: str, timeout: int = 90) -> bytes:
    last = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = resp.read()
            if not data:
                raise ValueError("reponse vide")
            return data
        except Exception as exc:  # noqa: BLE001 - on reessaie toujours
            last = exc
            if attempt < 2:
                time.sleep(0.8 * (attempt + 1))
    raise RuntimeError(f"GET échoué {url} : {last}")


def api_json(path: str):
    return json.loads(http_get(API + path).decode("utf-8"))


def download_file(url: str, dest: Path, md5: str | None = None, expected: int | None = None) -> None:
    """Telecharge dans un fichier temporaire puis valide (taille + md5)."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    data = http_get(url, timeout=120)
    if expected and abs(len(data) - expected) > max(2048, expected * 0.02):
        raise RuntimeError(f"taille inattendue: {len(data)} != {expected} ({url})")
    if md5 and hashlib.md5(data).hexdigest() != md5:
        raise RuntimeError(f"md5 invalide ({url})")
    tmp.write_bytes(data)
    os.replace(tmp, dest)


# ---------------------------------------------------------------------------
# Validateurs
# ---------------------------------------------------------------------------

def is_jpeg(path: Path, min_bytes: int = 4096) -> bool:
    if not path.is_file() or path.stat().st_size < min_bytes:
        return False
    with path.open("rb") as fh:
        head = fh.read(4)
        fh.seek(-2, os.SEEK_END)
        return head[:2] == b"\xff\xd8" and fh.read(2) == b"\xff\xd9"


def jpeg_size(path: Path) -> tuple[int, int] | None:
    """Lit les dimensions d'un JPEG baseline sans dependance externe."""
    try:
        data = path.read_bytes()
    except OSError:
        return None
    i = 2
    while i < len(data) - 9:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        seglen = struct.unpack(">H", data[i + 2:i + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3):
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return w, h
        i += 2 + seglen
    return None


def is_ttf(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 8000:
        return False
    with path.open("rb") as fh:
        return fh.read(4) in (b"\x00\x01\x00\x00", b"OTTO", b"true")


def is_hdr(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 1024:
        return False
    with path.open("rb") as fh:
        return fh.read(10).startswith(b"#?RADIANCE") or fh.read(10).startswith(b"#?RGBE")


# ---------------------------------------------------------------------------
# JPEG baseline minimal (fallback procedure) - ecrit avec struct uniquement
# ---------------------------------------------------------------------------

ZIGZAG = [
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
]
DC_LUM_BITS = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
DC_LUM_VALS = list(range(12))
AC_LUM_BITS = [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7D]
AC_LUM_VALS = [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
    0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
    0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
    0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
    0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
    0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
    0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
    0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
    0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
]
DC_CHR_BITS = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
DC_CHR_VALS = list(range(12))
AC_CHR_BITS = [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77]
AC_CHR_VALS = [
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41,
    0x51, 0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
    0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0, 0x15, 0x62, 0x72, 0xD1,
    0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26,
    0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44,
    0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
    0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74,
    0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A,
    0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4,
    0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
    0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA,
    0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
]
Q_LUM = [
    16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55,
    14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62,
    18, 22, 37, 56, 68, 109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99,
]
Q_CHR = [
    17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99,
    24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
]


def _huff_table(bits, vals):
    tab = {}
    code = 0
    k = 0
    for length in range(1, 17):
        for _ in range(bits[length - 1]):
            tab[vals[k]] = (code, length)
            code += 1
            k += 1
        code <<= 1
    return tab


HUFF = {
    (0, 0): _huff_table(DC_LUM_BITS, DC_LUM_VALS),
    (0, 1): _huff_table(AC_LUM_BITS, AC_LUM_VALS),
    (1, 0): _huff_table(DC_CHR_BITS, DC_CHR_VALS),
    (1, 1): _huff_table(AC_CHR_BITS, AC_CHR_VALS),
}
DCT_BASIS = [
    [(1.0 / math.sqrt(2.0) if u == 0 else 1.0) / 2.0 *
     math.cos((2 * x + 1) * u * math.pi / 16.0) for x in range(8)]
    for u in range(8)
]
QTABLES = [Q_LUM, Q_CHR]


class BitWriter:
    def __init__(self):
        self.out = bytearray()
        self.acc = 0
        self.nbits = 0

    def put(self, code: int, length: int) -> None:
        for shift in range(length - 1, -1, -1):
            self.acc = (self.acc << 1) | ((code >> shift) & 1)
            self.nbits += 1
            if self.nbits == 8:
                self.out.append(self.acc)
                if self.acc == 0xFF:
                    self.out.append(0)
                self.acc = 0
                self.nbits = 0

    def finish(self) -> bytes:
        if self.nbits:
            self.put((1 << (8 - self.nbits)) - 1, 8 - self.nbits)
        return bytes(self.out)


def _segment(marker: int, payload: bytes) -> bytes:
    return bytes((0xFF, marker)) + struct.pack(">H", len(payload) + 2) + payload


def _quantize_block(block: list[float], qid: int) -> list[int]:
    tmp = [[sum(DCT_BASIS[u][x] * block[y][x] for x in range(8)) for y in range(8)] for u in range(8)]
    q = QTABLES[qid]
    return [
        int(round(sum(tmp[u][y] * DCT_BASIS[v][y] for y in range(8)) / q[v * 8 + u]))
        for v in range(8) for u in range(8)
    ]


def _encode_block(bw: BitWriter, coeffs: list[int], qid: int, prev_dc: int) -> int:
    diff = coeffs[0] - prev_dc
    size = abs(diff).bit_length()
    code, length = HUFF[(qid, 0)][size]
    bw.put(code, length)
    if size:
        value = diff if diff > 0 else diff + (1 << size) - 1
        bw.put(value, size)
    run = 0
    for idx in range(1, 64):
        val = coeffs[ZIGZAG[idx]]
        if val == 0:
            run += 1
            continue
        while run > 15:
            code, length = HUFF[(qid, 1)][0xF0]
            bw.put(code, length)
            run -= 16
        size = abs(val).bit_length()
        code, length = HUFF[(qid, 1)][(run << 4) | size]
        bw.put(code, length)
        value = val if val > 0 else val + (1 << size) - 1
        bw.put(value, size)
        run = 0
    if run:
        code, length = HUFF[(qid, 1)][0]
        bw.put(code, length)
    return coeffs[0]


def write_jpeg_rgb(path: Path, width: int, height: int, rows: list[bytes]) -> None:
    """Ecrit un JPEG baseline 4:4:4 (qualite ~75) sans bibliotheque externe."""
    out = bytearray(b"\xff\xd8")
    out += _segment(0xE0, b"JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00")
    for qid, q in enumerate(QTABLES):
        out += _segment(0xDB, bytes((qid,)) + bytes(q))
    out += _segment(0xC0, bytes((8,)) + struct.pack(">HH", height, width) +
                    bytes((3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1)))
    # Identifiants DHT : DC lum=0x00, AC lum=0x10, DC chrom=0x01, AC chrom=0x11.
    for tid, bits, vals in (
        (0x00, DC_LUM_BITS, DC_LUM_VALS), (0x10, AC_LUM_BITS, AC_LUM_VALS),
        (0x01, DC_CHR_BITS, DC_CHR_VALS), (0x11, AC_CHR_BITS, AC_CHR_VALS),
    ):
        out += _segment(0xC4, bytes((tid,)) + bytes(bits) + bytes(vals))
    out += _segment(0xDA, bytes((3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0)))
    bw = BitWriter()
    prev = [0, 0, 0]
    for by in range(0, height - height % 8, 8):
        for bx in range(0, width - width % 8, 8):
            planes = [[[0.0] * 8 for _ in range(8)] for _ in range(3)]
            for y in range(8):
                row = rows[by + y]
                for x in range(8):
                    r, g, b = row[(bx + x) * 3], row[(bx + x) * 3 + 1], row[(bx + x) * 3 + 2]
                    planes[0][y][x] = 0.299 * r + 0.587 * g + 0.114 * b - 128.0
                    planes[1][y][x] = -0.168736 * r - 0.331264 * g + 0.5 * b
                    planes[2][y][x] = 0.5 * r - 0.418688 * g - 0.081312 * b
            for cid in range(3):
                qid = 0 if cid == 0 else 1
                prev[cid] = _encode_block(bw, _quantize_block(planes[cid], qid), qid, prev[cid])
    out += bw.finish()
    out += b"\xff\xd9"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


# ---------------------------------------------------------------------------
# Substituts proceduraux
# ---------------------------------------------------------------------------

def _smooth_noise(size: int, cells: int, rnd: random.Random) -> list[list[float]]:
    grid = [[rnd.random() for _ in range(cells + 1)] for _ in range(cells + 1)]
    out = []
    for y in range(size):
        fy = y * cells / size
        y0, ty = int(fy), fy - int(fy)
        ty = ty * ty * (3 - 2 * ty)
        row = []
        for x in range(size):
            fx = x * cells / size
            x0, tx = int(fx), fx - int(fx)
            tx = tx * tx * (3 - 2 * tx)
            a = grid[y0][x0] * (1 - tx) + grid[y0][x0 + 1] * tx
            b = grid[y0 + 1][x0] * (1 - tx) + grid[y0 + 1][x0 + 1] * tx
            row.append(a * (1 - ty) + b * ty)
        out.append(row)
    return out


def procedural_set(name: str, dest_dir: Path, size: int = 256) -> None:
    """Genere 4 cartes PBR coherentes (JPEG valides) si Poly Haven est indisponible."""
    rnd = random.Random(1234 + sum(ord(c) for c in name))
    coarse = _smooth_noise(size, 8, rnd)
    fine = _smooth_noise(size, 48, rnd)
    height = [[0.55 * coarse[y][x] + 0.45 * fine[y][x] for x in range(size)] for y in range(size)]
    for y in range(size):
        for x in range(size):
            if name == "panel":
                height[y][x] = height[y][x] * 0.4 + (0.85 if x % 64 < 56 and y % 64 < 56 else 0.15) * 0.6
            elif name == "metal":
                height[y][x] = height[y][x] * 0.6 + 0.4 * (0.5 + 0.5 * math.sin(x * 0.5))
            elif name == "asphalt":
                height[y][x] = height[y][x] * 0.85 + 0.15 * (1 if rnd.random() < 0.12 else 0)
    bases = {
        "asphalt": (44, 46, 50), "concrete": (108, 109, 106),
        "metal": (92, 104, 112), "rust": (128, 68, 38), "panel": (66, 78, 88),
    }
    base = bases.get(name, (100, 100, 100))
    rough_base = {"asphalt": 190, "concrete": 220, "metal": 120, "rust": 215, "panel": 150}.get(name, 190)
    rows = {k: [] for k in ("diffuse", "normal", "rough", "ao")}
    for y in range(size):
        line = {k: bytearray() for k in rows}
        for x in range(size):
            h = height[y][x]
            hx = height[y][(x + 1) % size] - height[y][(x - 1) % size]
            hy = height[(y + 1) % size][x] - height[(y - 1) % size][x]
            nx, ny, nz = -hx * 2.2, -hy * 2.2, 1.0
            inv = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
            shade = 0.65 + 0.55 * h
            for cid in range(3):
                line["diffuse"].append(min(255, max(0, int(base[cid] * shade))))
            line["normal"].extend((int(128 + 127 * nx * inv), int(128 + 127 * ny * inv), int(128 + 127 * nz * inv)))
            r = min(255, max(0, int(rough_base + (h - 0.5) * 60)))
            line["rough"].extend((r, r, r))
            a = min(255, max(0, int(120 + 120 * h)))
            line["ao"].extend((a, a, a))
        for k in rows:
            rows[k].append(bytes(line[k]))
    for suffix in ("diffuse", "normal", "rough", "ao"):
        write_jpeg_rgb(dest_dir / f"{name}_{suffix}.jpg", size, size, rows[suffix])


def procedural_hdr(dest: Path, w: int = 128, h: int = 64) -> None:
    """Ecrit un HDR Radiance valide (RGBE non RLE, nuit bleue etoilee)."""
    rnd = random.Random(1984)
    header = b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n" + f"-Y {h} +X {w}\n".encode()
    buf = bytearray(header)
    for y in range(h):
        sky = 1.0 - y / h
        for x in range(w):
            base = 0.12 + 0.35 * sky * sky
            star = 0.9 if sky > 0.45 and rnd.random() < 0.004 else 0.0
            vals = (base * 0.55 + star, base * 0.75 + star, base * 1.6 + star)
            m = max(vals)
            if m < 1e-32:
                buf.extend((0, 0, 0, 0))
                continue
            mant, exp = math.frexp(m)
            scale = mant * 256.0 / m
            buf.extend((int(vals[0] * scale), int(vals[1] * scale), int(vals[2] * scale), exp + 128))
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(buf)


# ---------------------------------------------------------------------------
# Telechargements
# ---------------------------------------------------------------------------

def fetch_textures(out_root: Path, force: bool) -> None:
    dest_dir = out_root / "assets" / "textures"
    dest_dir.mkdir(parents=True, exist_ok=True)
    try:
        catalogue = api_json("/assets?t=textures")
    except Exception as exc:  # noqa: BLE001
        log(f"catalogue textures indisponible ({exc}) -> fallback procedure")
        catalogue = {}
    for name, candidates in SETS.items():
        files = {f"{name}_{s}.jpg": dest_dir / f"{name}_{s}.jpg" for _, s in CHANNELS}
        if not force and all(is_jpeg(p) and jpeg_size(p) == (1024, 1024) for p in files.values()):
            log(f"{name}: deja present (1k) -> ignore")
            PROGRESS.setdefault(name, {"source": "cached", "channels": {}})
            continue
        done = False
        for asset_id in candidates:
            try:
                meta = api_json(f"/files/{asset_id}")
                for api_key, suffix in CHANNELS:
                    target = files[f"{name}_{suffix}.jpg"]
                    if force or not is_jpeg(target):
                        info = meta[api_key]["1k"]["jpg"]
                        download_file(info["url"], target, info.get("md5"), info.get("size"))
                    dims = jpeg_size(target)
                    if not is_jpeg(target) or dims != (1024, 1024):
                        raise RuntimeError(f"JPEG invalide {target.name}: {dims}")
                log(f"{name}: OK (Poly Haven {asset_id}, 1k JPG, nor_gl)")
                PROGRESS[name] = {"source": f"https://polyhaven.com/a/{asset_id}", "asset": asset_id, "channels": {k: v for k, v in files.items()}}
                done = True
                break
            except Exception as exc:  # noqa: BLE001
                log(f"{name}: essai {asset_id} echoue -> {exc}")
        if not done:
            log(f"{name}: fallback procedure (256x256)")
            procedural_set(name, dest_dir)
            PROGRESS[name] = {"source": "procedural (fallback)", "channels": {k: v for k, v in files.items()}}


def fetch_hdri(out_root: Path, force: bool) -> None:
    dest = out_root / "assets" / "hdri" / "night_1k.hdr"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not force and is_hdr(dest):
        log("HDRI: deja present -> ignore")
        PROGRESS.setdefault("hdri", {"source": "cached"})
        return
    for asset_id in HDRI_CANDIDATES:
        try:
            meta = api_json(f"/files/{asset_id}")
            info = meta["hdri"]["1k"]["hdr"]
            download_file(info["url"], dest, info.get("md5"), info.get("size"))
            if not is_hdr(dest):
                raise RuntimeError("entete Radiance invalide")
            log(f"HDRI: OK (Poly Haven {asset_id}, 1k)")
            PROGRESS["hdri"] = {"source": f"https://polyhaven.com/a/{asset_id}"}
            return
        except Exception as exc:  # noqa: BLE001
            log(f"HDRI: essai {asset_id} echoue -> {exc}")
    log("HDRI: fallback procedure (128x64 Radiance)")
    procedural_hdr(dest)
    PROGRESS["hdri"] = {"source": "procedural (fallback)"}


def fetch_fonts(out_root: Path, force: bool) -> None:
    dest_dir = out_root / "assets" / "fonts"
    dest_dir.mkdir(parents=True, exist_ok=True)
    for filename, urls in FONTS.items():
        dest = dest_dir / filename
        if not force and is_ttf(dest):
            log(f"{filename}: deja present -> ignore")
            PROGRESS.setdefault(filename, {"source": "cached"})
            continue
        for url in urls:
            try:
                download_file(url, dest)
                if not is_ttf(dest):
                    raise RuntimeError("entete TTF invalide")
                log(f"{filename}: OK ({url})")
                PROGRESS[filename] = {"source": url}
                break
            except Exception as exc:  # noqa: BLE001
                log(f"{filename}: essai {url} echoue -> {exc}")
        else:
            # Dernier recours :_service Google Fonts (CSS legacy -> TTF statique).
            family = "Orbitron:700" if filename.startswith("Orbitron") else "Rajdhani:600"
            try:
                legacy = urllib.request.Request(
                    f"https://fonts.googleapis.com/css?family={family}",
                    headers={"User-Agent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)"},
                )
                css = urllib.request.urlopen(legacy, timeout=60).read().decode("utf-8", "replace")
                url = re.search(r"url\((https://fonts\.gstatic\.com/[^)]+)\)", css).group(1)
                download_file(url, dest)
                if not is_ttf(dest):
                    raise RuntimeError("entete TTF invalide")
                log(f"{filename}: OK (fonts.gstatic.com legacy)")
                PROGRESS[filename] = {"source": url}
            except Exception as exc:  # noqa: BLE001
                log(f"ATTENTION: {filename} indisponible ({exc})")
                PROGRESS[filename] = {"source": "MANQUANT", "error": str(exc)}
    for filename, url in LICENSE_URLS.items():
        dest = dest_dir / filename
        if dest.is_file() and dest.stat().st_size > 200:
            continue
        try:
            download_file(url, dest)
            log(f"{filename}: OK")
        except Exception as exc:  # noqa: BLE001
            log(f"{filename}: fallback texte OFL ({exc})")
            dest.write_text(OFL_FALLBACK, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force-procedural", action="store_true", help="forcer les substituts locaux")
    parser.add_argument("--refresh", action="store_true", help="retélécharger les fichiers existants")
    parser.add_argument("--out-root", type=Path, default=ROOT, help="racine de sortie (test)")
    args = parser.parse_args()
    out_root = args.out_root.resolve()
    log(f"racine: {out_root}")
    manifest = out_root / "tools" / "asset_sources.json"
    if manifest.is_file():
        try:
            PROGRESS.update(json.loads(manifest.read_text(encoding="utf-8")))
        except Exception:  # noqa: BLE001
            pass
    if args.force_procedural:
        tex_dir = out_root / "assets" / "textures"
        for name in SETS:
            procedural_set(name, tex_dir)
            PROGRESS[name] = {"source": "procedural (force)", "channels": {}}
        procedural_hdr(out_root / "assets" / "hdri" / "night_1k.hdr")
        PROGRESS["hdri"] = {"source": "procedural (force)"}
    else:
        fetch_textures(out_root, args.refresh)
        fetch_hdri(out_root, args.refresh)
    fetch_fonts(out_root, args.force_procedural or args.refresh)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(PROGRESS, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    log(f"manifest: {manifest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
