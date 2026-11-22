#!/usr/bin/env python3
"""Generates cozy procedural WAV sound effects, ambient greenhouse loop, and PNG launcher icons."""

import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
ICON_DIR = os.path.join(ROOT, "assets", "icons")
SAMPLE_RATE = 22050


def write_wav(filename: str, samples: list[float], sample_rate: int = SAMPLE_RATE) -> None:
    os.makedirs(AUDIO_DIR, exist_ok=True)
    path = os.path.join(AUDIO_DIR, filename)
    peak = max((abs(s) for s in samples), default=1.0)
    scale = min(1.0, 0.92 / peak) if peak > 0 else 1.0
    pcm = bytearray()
    for s in samples:
        val = int(max(-1.0, min(1.0, s * scale)) * 32767)
        pcm.extend(struct.pack("<h", val))
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(bytes(pcm))


def env_ad(t: float, attack: float, duration: float, power: float = 2.0) -> float:
    if t < 0 or t > duration:
        return 0.0
    if t < attack:
        return t / max(attack, 1e-6)
    return max(0.0, (1.0 - (t - attack) / max(duration - attack, 1e-6)) ** power)


def gen_state_water() -> list[float]:
    dur = 0.24
    n = int(SAMPLE_RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Warm rising water bloop
        freq = 290.0 + 460.0 * (1.0 - math.exp(-t * 16.0))
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        s = math.sin(phase) * 0.72 + math.sin(phase * 2.01) * 0.18
        # Secondary tiny bubble pop at 85ms
        if t > 0.075:
            t2 = t - 0.075
            f2 = 520.0 + 380.0 * min(1.0, t2 / 0.08)
            s += math.sin(2.0 * math.pi * f2 * t2) * 0.35 * env_ad(t2, 0.008, 0.11, 2.2)
        out.append(s * env_ad(t, 0.008, dur, 1.9))
    return out


def gen_state_ice() -> list[float]:
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(42)
    out = []
    freqs = [1180.0, 1765.0, 2630.0, 3520.0]
    for i in range(n):
        t = i / SAMPLE_RATE
        chime = 0.0
        for idx, f in enumerate(freqs):
            chime += math.sin(2.0 * math.pi * f * t) * (0.42 / (idx + 1)) * math.exp(-t * (10.0 + idx * 5.0))
        # Crisp frost crunch transient
        crunch = (rng.random() * 2.0 - 1.0) * math.exp(-t * 48.0) * 0.35
        out.append((chime + crunch) * min(1.0, t / 0.003))
    return out


def gen_state_steam() -> list[float]:
    dur = 0.34
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(7)
    out = []
    lp = 0.0
    lp2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        white = rng.random() * 2.0 - 1.0
        # Soft airy bandpass-like noise
        lp = lp * 0.78 + white * 0.22
        lp2 = lp2 * 0.94 + lp * 0.06
        air = lp - lp2 * 0.8
        env = math.sin(math.pi * (t / dur)) ** 1.35
        tone = math.sin(2.0 * math.pi * (540.0 + 220.0 * (t / dur)) * t) * 0.06
        out.append((air * 1.4 + tone) * env)
    return out


def gen_glass_shatter() -> list[float]:
    dur = 0.42
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(101)
    shards = [(rng.uniform(1400, 4200), rng.uniform(0.0, 0.09), rng.uniform(12.0, 26.0)) for _ in range(14)]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = (rng.random() * 2.0 - 1.0) * math.exp(-t * 34.0) * 0.45
        for freq, delay, decay in shards:
            if t >= delay:
                dt = t - delay
                s += math.sin(2.0 * math.pi * freq * dt) * 0.14 * math.exp(-dt * decay)
        out.append(s)
    return out


def gen_collect_star() -> list[float]:
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    notes = [(659.25, 0.0), (987.77, 0.065), (1318.51, 0.13)]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0.0
        for freq, start in notes:
            if t >= start:
                dt = t - start
                s += (math.sin(2.0 * math.pi * freq * dt) * 0.6
                      + math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.18) * env_ad(dt, 0.005, 0.30, 2.4)
        out.append(s)
    return out


def gen_fan_toggle() -> list[float]:
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(19)
    lp = 0.0
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        click = math.sin(2.0 * math.pi * (420.0 - 180.0 * t / dur) * t) * math.exp(-t * 38.0) * 0.7
        lp = lp * 0.82 + (rng.random() * 2.0 - 1.0) * 0.18
        whoosh = lp * env_ad(t, 0.02, dur, 1.8) * 0.35
        out.append(click + whoosh)
    return out


def gen_condense() -> list[float]:
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(31)
    lp = 0.0
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        lp = lp * 0.72 + (rng.random() * 2.0 - 1.0) * 0.28
        hiss = lp * math.exp(-t * 22.0) * 0.32
        drip = 0.0
        if t > 0.05:
            dt = t - 0.05
            f = 460.0 + 360.0 * (1.0 - math.exp(-dt * 20.0))
            drip = math.sin(2.0 * math.pi * f * dt) * 0.65 * env_ad(dt, 0.006, 0.18, 2.2)
        out.append(hiss + drip)
    return out


def gen_seedling_bloom() -> list[float]:
    dur = 0.95
    n = int(SAMPLE_RATE * dur)
    # Warm sunny major-9th harp arpeggio
    arp = [
        (523.25, 0.00),
        (659.25, 0.07),
        (783.99, 0.14),
        (987.77, 0.21),
        (1046.50, 0.29),
        (1318.51, 0.38),
    ]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0.0
        for freq, start in arp:
            if t >= start:
                dt = t - start
                note = (math.sin(2.0 * math.pi * freq * dt) * 0.55
                        + math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.15
                        + math.sin(2.0 * math.pi * freq * 3.0 * dt) * 0.05)
                s += note * env_ad(dt, 0.008, 0.55, 2.3)
        out.append(s)
    return out


def gen_seedling_shiver() -> list[float]:
    dur = 0.26
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        vib = math.sin(2.0 * math.pi * 28.0 * t) * 35.0
        f = 340.0 + vib
        s = math.sin(2.0 * math.pi * f * t) * env_ad(t, 0.01, dur, 1.7)
        out.append(s * 0.6)
    return out


def gen_fail_drain() -> list[float]:
    dur = 0.42
    n = int(SAMPLE_RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        wobble = math.sin(2.0 * math.pi * 14.0 * t) * 35.0
        freq = max(90.0, 390.0 - 260.0 * (t / dur) + wobble)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        s = math.sin(phase) * 0.7 + math.sin(phase * 1.5) * 0.2
        out.append(s * env_ad(t, 0.01, dur, 1.5))
    return out


def gen_ui_tap() -> list[float]:
    dur = 0.09
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 580.0 - 160.0 * (t / dur)
        s = math.sin(2.0 * math.pi * f * t) * env_ad(t, 0.004, dur, 2.6)
        out.append(s * 0.65)
    return out


def gen_ambient_greenhouse() -> list[float]:
    """Gentle, warm, seamless 8-second acoustic marimba & pad loop in C major."""
    dur = 8.0
    n = int(SAMPLE_RATE * dur)
    out = [0.0] * n
    # Soft warm pad chords (2s each): Cmaj7 -> Am7 -> Fmaj7 -> G6
    chords = [
        (0.0, [261.63, 329.63, 392.00, 493.88]),
        (2.0, [220.00, 261.63, 329.63, 392.00]),
        (4.0, [174.61, 220.00, 261.63, 329.63]),
        (6.0, [196.00, 246.94, 293.66, 329.63]),
    ]
    # Gentle kalimba/marimba plucks on 0.5s grid
    melody = [
        (0.0, 523.25), (0.5, 659.25), (1.0, 783.99), (1.5, 659.25),
        (2.0, 440.00), (2.5, 523.25), (3.0, 659.25), (3.5, 523.25),
        (4.0, 523.25), (4.5, 659.25), (5.0, 698.46), (5.5, 523.25),
        (6.0, 587.33), (6.5, 659.25), (7.0, 783.99), (7.5, 587.33),
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        # Pad
        chord_idx = min(3, int(t // 2.0))
        local_t = t - chord_idx * 2.0
        pad_env = math.sin(math.pi * (local_t / 2.0)) ** 0.7
        pad = 0.0
        for f in chords[chord_idx][1]:
            pad += math.sin(2.0 * math.pi * f * t) * 0.045
        s = pad * pad_env
        # Plucks (wrapping tail at loop seam for seamless looping)
        for start, freq in melody:
            dt = (t - start) % dur
            if dt < 0.75:
                pluck = (math.sin(2.0 * math.pi * freq * dt) * 0.14
                         + math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.025)
                s += pluck * env_ad(dt, 0.008, 0.75, 2.8)
        out[i] = s
    return out


def save_png_rgba(path: str, width: int, height: int, pixels: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def render_icon_png(path: str, size: int) -> None:
    """Renders a clean, anti-aliased DRIP droplet icon as RGBA PNG."""
    buf = bytearray(size * size * 4)

    def blend(r0, g0, b0, a0, r1, g1, b1, a1):
        af = a1 + a0 * (1.0 - a1)
        if af <= 1e-6:
            return 0.0, 0.0, 0.0, 0.0
        r = (r1 * a1 + r0 * a0 * (1.0 - a1)) / af
        g = (g1 * a1 + g0 * a0 * (1.0 - a1)) / af
        b = (b1 * a1 + b0 * a0 * (1.0 - a1)) / af
        return r, g, b, af

    def in_droplet(u: float, v: float) -> float:
        # Signed distance approximation to a cute teardrop centered at (0.5, 0.56)
        dx = u - 0.5
        if v >= 0.60:
            return math.hypot(dx, v - 0.60) - 0.255
        # Smooth upper taper toward tip (0.5, 0.16)
        t = max(0.0, min(1.0, (v - 0.16) / 0.44))
        half_w = 0.255 * (math.sin(t * math.pi * 0.5) ** 1.15)
        if v < 0.16:
            return math.hypot(dx, v - 0.16)
        return abs(dx) - half_w

    for y in range(size):
        v = (y + 0.5) / size
        for x in range(size):
            u = (x + 0.5) / size
            # Soft sage greenhouse background with rounded corners
            cx = max(0.0, abs(u - 0.5) - 0.30)
            cy = max(0.0, abs(v - 0.5) - 0.30)
            corner_d = math.hypot(cx, cy) - 0.20
            bg_a = max(0.0, min(1.0, 0.5 - corner_d * size * 0.5))
            r = 0.91 * (1.0 - v) + 0.72 * v
            g = 0.96 * (1.0 - v) + 0.88 * v
            b = 0.89 * (1.0 - v) + 0.71 * v
            a = bg_a

            # Subtle cream halo
            halo_d = math.hypot(u - 0.5, v - 0.54) - 0.33
            halo_a = max(0.0, min(1.0, 0.5 - halo_d * size * 0.5)) * 0.36 * bg_a
            r, g, b, a = blend(r, g, b, a, 1.0, 1.0, 1.0, halo_a)

            # Soft shadow under droplet
            sd = in_droplet(u, v - 0.025)
            sa = max(0.0, min(1.0, 0.5 - sd * size * 0.25)) * 0.18 * bg_a
            r, g, b, a = blend(r, g, b, a, 0.09, 0.38, 0.58, sa)

            # Main water droplet gradient
            dd = in_droplet(u, v)
            da = max(0.0, min(1.0, 0.5 - dd * size * 0.6))
            if da > 0.0:
                grad = max(0.0, min(1.0, (v - 0.18) / 0.68))
                dr = 0.45 * (1.0 - grad) + 0.11 * grad
                dg = 0.88 * (1.0 - grad) + 0.52 * grad
                db = 1.00 * (1.0 - grad) + 0.82 * grad
                r, g, b, a = blend(r, g, b, a, dr, dg, db, da)

                # Gloss highlight
                hx = (u - 0.40) * 1.4
                hy = (v - 0.52) * 0.75
                hd = math.hypot(hx, hy) - 0.06
                ha = max(0.0, min(1.0, 0.5 - hd * size * 0.6)) * 0.50 * da
                r, g, b, a = blend(r, g, b, a, 1.0, 1.0, 1.0, ha)

                # Cute eyes
                for ex in (0.425, 0.575):
                    ed = math.hypot(u - ex, v - 0.61) - 0.026
                    ea = max(0.0, min(1.0, 0.5 - ed * size * 0.8)) * da
                    r, g, b, a = blend(r, g, b, a, 0.07, 0.23, 0.34, ea)
                    sp = math.hypot(u - (ex - 0.008), v - 0.601) - 0.009
                    spa = max(0.0, min(1.0, 0.5 - sp * size * 0.8)) * da
                    r, g, b, a = blend(r, g, b, a, 1.0, 1.0, 1.0, spa)

                # Rosy cheeks
                for cx_p in (0.375, 0.625):
                    cd = math.hypot(u - cx_p, v - 0.655) - 0.024
                    ca = max(0.0, min(1.0, 0.5 - cd * size * 0.6)) * 0.5 * da
                    r, g, b, a = blend(r, g, b, a, 1.0, 0.60, 0.64, ca)

                # Cute smile arc
                sd_arc = abs(math.hypot(u - 0.5, v - 0.645) - 0.042) - 0.009
                if v > 0.655 and abs(u - 0.5) < 0.042:
                    sma = max(0.0, min(1.0, 0.5 - sd_arc * size * 0.8)) * da
                    r, g, b, a = blend(r, g, b, a, 0.07, 0.23, 0.34, sma)

            idx = (y * size + x) * 4
            buf[idx] = int(max(0, min(255, round(r * 255))))
            buf[idx + 1] = int(max(0, min(255, round(g * 255))))
            buf[idx + 2] = int(max(0, min(255, round(b * 255))))
            buf[idx + 3] = int(max(0, min(255, round(a * 255))))

    save_png_rgba(path, size, size, bytes(buf))


def gen_sponge_soak() -> list[float]:
    dur = 0.24
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(55)
    lp = 0.0
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 220.0 + 340.0 * (t / dur)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        lp = lp * 0.85 + (rng.random() * 2.0 - 1.0) * 0.15
        squish = math.sin(phase) * 0.55 + lp * 0.45
        out.append(squish * env_ad(t, 0.015, dur, 1.8))
    return out


def gen_sponge_squeeze() -> list[float]:
    dur = 0.26
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(77)
    lp = 0.0
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 560.0 - 220.0 * (t / dur) + math.sin(t * 48.0) * 45.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        lp = lp * 0.78 + (rng.random() * 2.0 - 1.0) * 0.22
        out.append((math.sin(phase) * 0.62 + lp * 0.55) * env_ad(t, 0.008, dur, 2.0))
    return out


def gen_hotplate_sizzle() -> list[float]:
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(91)
    hp_prev = 0.0
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        w = rng.random() * 2.0 - 1.0
        hp = w - hp_prev * 0.65
        hp_prev = w
        crackle = (1.0 if rng.random() > 0.92 else 0.35)
        out.append(hp * crackle * env_ad(t, 0.012, dur, 1.4))
    return out


def gen_star_fanfare() -> list[float]:
    dur = 0.38
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = (math.sin(2.0 * math.pi * 880.0 * t) * 0.55
             + math.sin(2.0 * math.pi * 1318.5 * t) * 0.32
             + math.sin(2.0 * math.pi * 1760.0 * t) * 0.16)
        out.append(s * env_ad(t, 0.004, dur, 2.5))
    return out


def render_soft_glow_png(path: str, size: int = 128) -> None:
    buf = bytearray(size * size * 4)
    for y in range(size):
        v = (y + 0.5) / size * 2.0 - 1.0
        for x in range(size):
            u = (x + 0.5) / size * 2.0 - 1.0
            d = math.hypot(u, v)
            a = max(0.0, 1.0 - d) ** 2.2
            idx = (y * size + x) * 4
            buf[idx] = 255
            buf[idx + 1] = 255
            buf[idx + 2] = 255
            buf[idx + 3] = int(round(a * 255))
    save_png_rgba(path, size, size, bytes(buf))


def render_paper_grain_png(path: str, size: int = 128) -> None:
    rng = random.Random(1337)
    buf = bytearray(size * size * 4)
    for i in range(size * size):
        val = int(rng.uniform(225, 255))
        a = int(rng.uniform(4, 18))
        idx = i * 4
        buf[idx] = val
        buf[idx + 1] = int(val * 0.98)
        buf[idx + 2] = int(val * 0.93)
        buf[idx + 3] = a
    save_png_rgba(path, size, size, bytes(buf))


def main() -> None:
    sounds = {
        "state_water.wav": gen_state_water(),
        "state_ice.wav": gen_state_ice(),
        "state_steam.wav": gen_state_steam(),
        "glass_shatter.wav": gen_glass_shatter(),
        "collect_star.wav": gen_collect_star(),
        "fan_toggle.wav": gen_fan_toggle(),
        "condense.wav": gen_condense(),
        "seedling_bloom.wav": gen_seedling_bloom(),
        "seedling_shiver.wav": gen_seedling_shiver(),
        "fail_drain.wav": gen_fail_drain(),
        "ui_tap.wav": gen_ui_tap(),
        "ambient_greenhouse.wav": gen_ambient_greenhouse(),
        "sponge_soak.wav": gen_sponge_soak(),
        "sponge_squeeze.wav": gen_sponge_squeeze(),
        "hotplate_sizzle.wav": gen_hotplate_sizzle(),
        "star_fanfare.wav": gen_star_fanfare(),
    }
    for name, data in sounds.items():
        write_wav(name, data)
    print(f"Generated {len(sounds)} WAV files in {AUDIO_DIR}")

    render_icon_png(os.path.join(ICON_DIR, "icon_192.png"), 192)
    render_icon_png(os.path.join(ICON_DIR, "icon_432.png"), 432)
    print(f"Generated PNG icons in {ICON_DIR}")

    tex_dir = os.path.join(ROOT, "assets", "textures")
    render_soft_glow_png(os.path.join(tex_dir, "soft_glow.png"), 128)
    render_paper_grain_png(os.path.join(tex_dir, "paper_grain.png"), 128)
    print(f"Generated PNG textures in {tex_dir}")


if __name__ == "__main__":
    main()
