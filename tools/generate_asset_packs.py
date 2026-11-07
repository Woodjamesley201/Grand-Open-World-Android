#!/usr/bin/env python3
"""Generate the HD asset packs for Grand Open World.

Produces:
  build_packs/pack_textures.zip  - 4096px high-res versions of every world texture
  build_packs/pack_audio.zip     - high-quality original music (ogg)
  build_packs/manifest.json      - version + pack list with sizes

All content is procedurally generated (original, MIT-licensed). The packs are
attached to the GitHub release `assets-v1`; the game downloads them on first
launch. Total size is adaptive and targets ~1 GB (--target-bytes).
"""
import argparse
import json
import math
import os
import random
import struct
import subprocess
import zipfile
from pathlib import Path

try:
    import numpy as np
except ImportError:
    raise SystemExit("numpy is required: pip install numpy")
try:
    from PIL import Image
except ImportError:
    raise SystemExit("Pillow is required: pip install pillow")

SR = 22050  # not used for audio; audio uses 44100
TEX_SIZE = 4096
AUDIO_SR = 44100

TEXTURES = [
    "asphalt", "road", "highway", "sidewalk", "concrete", "grass", "sand",
    "dirt", "brick", "wood", "roof", "metal", "runway", "field", "water",
]


# ---------------------------------------------------------------- textures

def _noise(seed, size, freq, octaves=4):
    """Layered value noise, returns float array in [0, 1]."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float64)
    amp = 1.0
    total = 0.0
    f = freq
    for _ in range(octaves):
        g = rng.standard_normal((max(2, int(size * f)), max(2, int(size * f))))
        # bilinear upsample
        gx = np.linspace(0, g.shape[0] - 1, size)
        gy = np.linspace(0, g.shape[1] - 1, size)
        x0 = np.floor(gx).astype(int)
        y0 = np.floor(gy).astype(int)
        x1 = np.minimum(x0 + 1, g.shape[0] - 1)
        y1 = np.minimum(y0 + 1, g.shape[1] - 1)
        fx = gx - x0
        fy = gy - y0
        fx = fx[:, None]
        fy = fy[None, :]
        a = g[np.ix_(x0, y0)]
        b = g[np.ix_(x1, y0)]
        c = g[np.ix_(x0, y1)]
        d = g[np.ix_(x1, y1)]
        layer = (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) +
                 c * (1 - fx) * fy + d * fx * fy)
        out += layer * amp
        total += amp
        amp *= 0.5
        f *= 2
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out


def _to_image(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")


def gen_texture(name, seed):
    n = _noise(seed, TEX_SIZE, 1.0 / 48.0)
    n2 = _noise(seed + 100, TEX_SIZE, 1.0 / 8.0)
    fine = _noise(seed + 200, TEX_SIZE, 1.0 / 2.0, octaves=2)
    size = TEX_SIZE
    xx, yy = np.meshgrid(np.arange(size), np.arange(size))

    if name in ("asphalt", "roof"):
        g = 0.10 + n * 0.05 + fine * 0.02
        return _to_image(np.dstack([g, g, g + 0.008]))
    if name == "road":
        g = 0.11 + n * 0.05
        rgb = np.dstack([g, g, g + 0.008])
        line = (np.abs(yy - size // 2) < size // 340) & ((xx // (size // 16)) % 2 == 0)
        rgb[line] = [0.85, 0.75, 0.25]
        return _to_image(rgb)
    if name == "highway":
        g = 0.11 + n * 0.05
        rgb = np.dstack([g, g, g + 0.008])
        for frac in (0.25, 0.5, 0.75):
            rgb[np.abs(yy - int(size * frac)) < size // 400] = [0.9, 0.9, 0.9]
        return _to_image(rgb)
    if name == "sidewalk":
        g = 0.55 + n * 0.12
        line = (xx % (size // 8) < size // 128) | (yy % (size // 8) < size // 128)
        g = np.where(line, g * 0.8, g)
        return _to_image(np.dstack([g, g, g]))
    if name == "concrete":
        g = 0.5 + n * 0.15
        return _to_image(np.dstack([g, g, g * 1.02]))
    if name == "grass":
        v = n * 0.7 + n2 * 0.3
        return _to_image(np.dstack([0.13 + v * 0.12, 0.34 + v * 0.24, 0.12 + v * 0.08]))
    if name == "sand":
        v = n * 0.7 + fine * 0.3
        return _to_image(np.dstack([0.78 + v * 0.12, 0.72 + v * 0.1, 0.55 + v * 0.1]))
    if name == "dirt":
        v = n * 0.6 + n2 * 0.4
        return _to_image(np.dstack([0.4 + v * 0.15, 0.3 + v * 0.1, 0.2 + v * 0.08]))
    if name == "brick":
        row = yy // (size // 16)
        off = (row % 2) * (size // 32)
        mortar = (yy % (size // 16) < size // 128) | ((xx + off) % (size // 8) < size // 128)
        v = n * 0.6 + n2 * 0.4
        rgb = np.dstack([0.55 + v * 0.15, 0.25 + v * 0.08, 0.18 + v * 0.06])
        rgb[mortar] = [0.6, 0.58, 0.55]
        return _to_image(rgb)
    if name == "wood":
        v = _noise(seed + 300, size, 1.0 / 3.0, octaves=2)
        rings = 0.5 + 0.5 * np.sin(xx / (size / 64.0) + v * 6.0)
        g = 0.3 + rings * 0.25 + n2 * 0.1
        return _to_image(np.dstack([g, g * 0.72, g * 0.42]))
    if name == "metal":
        v = _noise(seed + 400, size, 1.0 / 64.0, octaves=2)
        g = 0.6 + v * 0.1 + np.sin(yy / (size / 128.0)) * 0.03
        return _to_image(np.dstack([g, g, g * 1.02]))
    if name == "runway":
        g = 0.14 + n * 0.04
        rgb = np.dstack([g, g, g])
        dash = (np.abs(yy - size // 2) < size // 340) & ((xx // (size // 12)) % 2 == 0)
        rgb[dash] = [0.9, 0.9, 0.9]
        return _to_image(rgb)
    if name == "field":
        row = 0.5 + 0.5 * np.sin(xx / (size / 32.0))
        v = n * 0.6
        return _to_image(np.dstack([0.35 + v * 0.1, 0.45 + v * 0.15 + row * 0.08, np.full(v.shape, 0.18)]))
    if name == "water":
        v = _noise(seed + 500, size, 1.0 / 16.0)
        v2 = _noise(seed + 600, size, 1.0 / 64.0)
        return _to_image(np.dstack([0.1 + v * 0.08, 0.35 + v * 0.12, 0.55 + v * 0.15 + v2 * 0.05]))
    g = n
    return _to_image(np.dstack([g, g, g]))


# ---------------------------------------------------------------- music

NOTES = {"A": 57, "C": 60, "D": 62, "F": 65, "G": 67}
MAJOR = [0, 4, 7, 12]
MINOR = [0, 3, 7, 12]


def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def synth_track(seed, seconds=600.0):
    """10 minutes of layered ambient electronic music, stereo 44.1 kHz."""
    rng = random.Random(seed)
    roots = ["A", "C", "D", "F", "G"]
    root = NOTES[roots[seed % len(roots)]]
    minor = seed % 2 == 0
    scale = MINOR if minor else MAJOR
    bpm = 84 + (seed * 7) % 30
    beat = 60.0 / bpm
    n = int(AUDIO_SR * seconds)
    out_l = np.zeros(n, dtype=np.float64)
    out_r = np.zeros(n, dtype=np.float64)

    # chord progression: 4 chords, one per 8 beats
    chords = []
    for i in range(4):
        deg = scale[i % len(scale)]
        chords.append([root + deg, root + deg + (3 if minor else 4), root + deg + 7])

    total_beats = int(seconds / beat)
    pad_cache = {}
    for b in range(0, total_beats, 8):
        ch = chords[(b // 8) % len(chords)]
        key = tuple(ch)
        if key not in pad_cache:
            dur = int(beat * 8 * AUDIO_SR * 1.05)
            t = np.arange(dur) / AUDIO_SR
            pad = np.zeros(dur)
            for m in ch:
                f = midi_hz(m) * 0.5
                pad += np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t + 0.5)
            pad *= 0.06
            pad_cache[key] = pad
        pad = pad_cache[key]
        start = int(b * beat * AUDIO_SR)
        end = min(start + len(pad), n)
        seg = pad[: end - start]
        pan = 0.3 + 0.4 * rng.random()
        out_l[start:end] += seg * (1.0 - pan)
        out_r[start:end] += seg * pan

    # bass on beats 0 and 4 of each 8
    for b in range(0, total_beats, 4):
        ch = chords[(b // 8) % len(chords)]
        f = midi_hz(ch[0] - 24)
        dur = int(beat * 0.9 * AUDIO_SR)
        t = np.arange(dur) / AUDIO_SR
        tone = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.0) * 0.22
        start = int(b * beat * AUDIO_SR)
        end = min(start + dur, n)
        out_l[start:end] += tone[: end - start]
        out_r[start:end] += tone[: end - start]

    # arpeggio melody, pentatonic-ish
    penta = [root + 12, root + 15, root + 17, root + 19, root + 22, root + 24]
    for b in range(total_beats):
        if rng.random() < 0.55:
            m = penta[rng.randrange(len(penta))]
            f = midi_hz(m)
            dur = int(beat * 0.8 * AUDIO_SR)
            t = np.arange(dur) / AUDIO_SR
            env = np.minimum(t * 30.0, 1.0) * np.exp(-t * 3.0)
            tone = np.sin(2 * np.pi * f * t) * env * 0.1
            start = int(b * beat * AUDIO_SR)
            end = min(start + dur, n)
            out_l[start:end] += tone[: end - start] * 0.7
            out_r[start:end] += tone[: end - start]

    # hats
    for b in range(total_beats):
        dur = int(0.03 * AUDIO_SR)
        noise = rng.random() * 2 - 1
        # cheap noise burst
        burst = (np.random.default_rng(b).standard_normal(dur)) * 0.04 * (1.0 - np.arange(dur) / dur)
        start = int(b * beat * AUDIO_SR)
        end = min(start + dur, n)
        out_l[start:end] += burst[: end - start]
        out_r[start:end] += burst[: end - start]

    # gentle stereo widening fade-in master envelope
    master = np.minimum(np.arange(n) / (AUDIO_SR * 4.0), 1.0)
    out_l *= master
    out_r *= master
    peak = max(np.abs(out_l).max(), np.abs(out_r).max())
    out_l = out_l / peak * 0.85
    out_r = out_r / peak * 0.85
    return out_l, out_r


def write_wav(path, out_l, out_r):
    data = np.empty((len(out_l), 2), dtype=np.int16)
    data[:, 0] = (out_l * 32767).astype(np.int16)
    data[:, 1] = (out_r * 32767).astype(np.int16)
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + data.nbytes))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 2, AUDIO_SR, AUDIO_SR * 4, 4, 16))
        f.write(b"data")
        f.write(struct.pack("<I", data.nbytes))
        f.write(data.tobytes())


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build_packs")
    ap.add_argument("--target-bytes", type=int, default=1_073_741_824)
    ap.add_argument("--max-tracks", type=int, default=18)
    ap.add_argument("--track-seconds", type=int, default=600)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    tex_dir = out / "staging" / "textures"
    aud_dir = out / "staging" / "audio"
    tex_dir.mkdir(parents=True, exist_ok=True)
    aud_dir.mkdir(parents=True, exist_ok=True)

    # ---- textures
    print("Generating textures ...")
    for i, name in enumerate(TEXTURES):
        p = tex_dir / f"{name}.png"
        if not p.exists():
            img = gen_texture(name, 1000 + i * 17)
            img.save(p, optimize=True)
        print(f"  {name}.png  {p.stat().st_size/1e6:.1f} MB")

    # ---- audio (adaptive count to reach the target size)
    print("Generating music ...")
    track_i = 0
    total = sum(f.stat().st_size for f in tex_dir.glob("*.png"))
    while total < args.target_bytes and track_i < args.max_tracks:
        ogg = aud_dir / f"oceanport_theme_{track_i+1:02d}.ogg"
        if not ogg.exists():
            l, r = synth_track(track_i + 1, float(args.track_seconds))
            wav = aud_dir / f"tmp_{track_i}.wav"
            write_wav(wav, l, r)
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                 "-c:a", "libvorbis", "-b:a", "320k", str(ogg)], check=True)
            wav.unlink()
        total += ogg.stat().st_size
        print(f"  oceanport_theme_{track_i+1:02d}.ogg  {ogg.stat().st_size/1e6:.1f} MB  (running total {total/1e6:.0f} MB)")
        track_i += 1

    # ---- zips
    print("Packing ...")
    tex_zip = out / "pack_textures.zip"
    with zipfile.ZipFile(tex_zip, "w", zipfile.ZIP_STORED) as z:
        for f in sorted(tex_dir.glob("*.png")):
            z.write(f, f"textures/{f.name}")

    aud_zip = out / "pack_audio.zip"
    with zipfile.ZipFile(aud_zip, "w", zipfile.ZIP_STORED) as z:
        for f in sorted(aud_dir.glob("*.ogg")):
            z.write(f, f"audio/{f.name}")

    manifest = {
        "version": "v1",
        "generated": "procedural",
        "total_bytes": tex_zip.stat().st_size + aud_zip.stat().st_size,
        "packs": [
            {"file": "pack_textures.zip", "bytes": tex_zip.stat().st_size},
            {"file": "pack_audio.zip", "bytes": aud_zip.stat().st_size},
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2))

    gb = manifest["total_bytes"] / 1e9
    print(f"\nDONE  pack_textures.zip {tex_zip.stat().st_size/1e6:.0f} MB, "
          f"pack_audio.zip {aud_zip.stat().st_size/1e6:.0f} MB, total {gb:.2f} GB")
    if manifest["total_bytes"] < args.target_bytes * 0.9:
        print("WARNING: below target size (track cap reached)")


if __name__ == "__main__":
    main()
