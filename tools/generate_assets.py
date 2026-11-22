#!/usr/bin/env python3
"""Generates DRIP's procedural audio (cozy SFX + seamless music loops) and PNG launcher icons.

Pure Python, no third-party dependencies, fully deterministic (seeded RNGs).

Usage:
    python3 tools/generate_assets.py            # (re)generate all audio; images only if missing
    python3 tools/generate_assets.py --images   # also force-regenerate icons/textures

Audio is 22050 Hz, 16-bit mono. Music loops are rendered so the last sample flows
straight into the first (notes, echoes and reverb tails wrap around the loop seam),
and their .import files are written with forward looping over the whole sample.
"""

import math
import os
import random
import struct
import sys
import wave
import zlib
from array import array

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
ICON_DIR = os.path.join(ROOT, "assets", "icons")
SAMPLE_RATE = 22050
SR = SAMPLE_RATE
TAU = 2.0 * math.pi

MUSIC_PEAK = 0.708  # -3 dBFS
SFX_PEAK = 0.85


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_wav(filename: str, samples: list[float], peak: float = SFX_PEAK,
              sample_rate: int = SAMPLE_RATE) -> None:
    """Writes a 16-bit mono WAV, normalizing the absolute peak to `peak`."""
    os.makedirs(AUDIO_DIR, exist_ok=True)
    path = os.path.join(AUDIO_DIR, filename)
    top = max((abs(s) for s in samples), default=0.0)
    scale = peak / top if top > 1e-9 else 1.0
    pcm = array("h", (int(round(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    if sys.byteorder == "big":
        pcm.byteswap()
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm.tobytes())


LOOP_IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://assets/audio/{name}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def ensure_loop_import(filename: str) -> None:
    """Makes sure Godot imports `filename` as a forward loop over the whole sample.

    edit/loop_mode=2 is "Forward"; loop_end=-1 resolves to the real frame count at
    import time, so the loop always matches the actual sample length.
    """
    path = os.path.join(AUDIO_DIR, filename + ".import")
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as f:
            f.write(LOOP_IMPORT_TEMPLATE.format(name=filename))
        return
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")
    wanted = {"edit/loop_mode": "2", "edit/loop_begin": "0", "edit/loop_end": "-1"}
    changed = False
    for i, line in enumerate(lines):
        key = line.split("=", 1)[0]
        if key in wanted and line != f"{key}={wanted[key]}":
            lines[i] = f"{key}={wanted[key]}"
            changed = True
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))


# ---------------------------------------------------------------------------
# DSP helpers
# ---------------------------------------------------------------------------

def secs(d: float) -> int:
    return int(round(d * SR))


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def zeros(dur: float) -> list[float]:
    return [0.0] * secs(dur)


def lp_coef(cutoff: float) -> float:
    return 1.0 - math.exp(-TAU * cutoff / SR)


def lowpass(x: list[float], cutoff: float, stages: int = 1, loop: bool = False) -> list[float]:
    """One-pole low-pass (cascaded `stages` times). With loop=True the filter state is
    pre-rolled from the end of the buffer so the result is seamless when looped."""
    a = lp_coef(cutoff)
    n = len(x)
    out = x
    for _ in range(stages):
        y = 0.0
        if loop:
            for s in out[n - min(n, secs(0.25)):]:
                y += a * (s - y)
        res = [0.0] * n
        for i in range(n):
            y += a * (out[i] - y)
            res[i] = y
        out = res
    return out


def highpass(x: list[float], cutoff: float, loop: bool = False) -> list[float]:
    low = lowpass(x, cutoff, 1, loop)
    return [a - b for a, b in zip(x, low)]


def bandnoise(n: int, rng: random.Random, lo: float, hi: float, stages: int = 2) -> list[float]:
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    band = lowpass(white, hi, stages)
    return highpass(band, lo)


def sweep_lowpass(x: list[float], cutoff_at) -> list[float]:
    """Two-stage one-pole low-pass whose cutoff follows cutoff_at(t)."""
    y1 = 0.0
    y2 = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        a = lp_coef(cutoff_at(i / SR))
        y1 += a * (s - y1)
        y2 += a * (y1 - y2)
        out[i] = y2
    return out


def fade_edges(x: list[float], fade_in: float = 0.002, fade_out: float = 0.02) -> list[float]:
    """Raised-cosine fade at both ends so nothing starts or stops with a click."""
    n = len(x)
    fi = max(1, secs(fade_in))
    fo = max(1, secs(fade_out))
    for i in range(min(fi, n)):
        x[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(min(fo, n)):
        x[n - 1 - k] *= 0.5 - 0.5 * math.cos(math.pi * k / fo)
    return x


def remove_dc(x: list[float]) -> list[float]:
    mean = sum(x) / max(1, len(x))
    return [s - mean for s in x]


def mix(*layers) -> list[float]:
    n = max(len(layer) for layer, _ in layers)
    out = [0.0] * n
    for layer, gain in layers:
        for i, s in enumerate(layer):
            out[i] += s * gain
    return out


def add_into(dst: list[float], src: list[float], gain: float = 1.0, offset: int = 0) -> None:
    n = len(dst)
    for i, s in enumerate(src):
        j = offset + i
        if j >= n:
            break
        if j >= 0:
            dst[j] += s * gain


# Instrument partial tables: (frequency ratio, relative amplitude, decay multiplier)
KALIMBA = [(1.0, 1.0, 1.0), (2.0, 0.07, 1.7), (5.35, 0.09, 4.5)]
MARIMBA = [(1.0, 1.0, 1.0), (2.0, 0.05, 2.0), (3.94, 0.10, 5.5)]
MUSIC_BOX = [(1.0, 1.0, 1.0), (2.0, 0.20, 1.8), (3.0, 0.06, 2.8), (4.16, 0.03, 4.0)]
HARP = [(1.0, 1.0, 1.0), (2.0, 0.22, 1.6), (3.0, 0.07, 2.4)]
BELL = [(1.0, 1.0, 1.0), (2.0, 0.22, 1.5), (2.76, 0.10, 2.4), (5.4, 0.035, 4.0)]
SOFT_BELL = [(1.0, 1.0, 1.0), (2.0, 0.15, 1.6), (3.0, 0.04, 2.5)]
PLUCK_BASS = [(1.0, 1.0, 1.0), (2.0, 0.45, 1.5), (3.0, 0.16, 2.2), (4.0, 0.06, 3.0)]
PURE = [(1.0, 1.0, 1.0)]


def add_note(buf: list[float], start: float, freq: float, amp: float, partials,
             tau: float, attack: float = 0.004, length: float | None = None,
             wrap: bool = False, max_freq: float = 6500.0) -> None:
    """Adds a struck/plucked note: soft raised-cosine attack, exponential decay per
    partial, and a short fade at the very end. With wrap=True the tail wraps to the
    start of `buf` (for seamless loops)."""
    n = len(buf)
    if length is None:
        length = min(tau * 6.0 + attack, 4.0)
    count = secs(length)
    att = max(1, secs(attack))
    tail = min(count, secs(0.04))
    s0 = secs(start)
    parts = []
    for ratio, rel, dmul in partials:
        f = freq * ratio
        if f >= max_freq:
            continue
        # Partials slowly fade above ~3 kHz to keep things soft
        soft = 1.0 if f < 3000.0 else max(0.0, 1.0 - (f - 3000.0) / 3500.0)
        parts.append((TAU * f / SR, rel * soft, math.exp(-dmul / (tau * SR))))
    if not parts:
        return
    gains = [p[1] for p in parts]
    for k in range(count):
        idx = s0 + k
        if wrap:
            idx %= n
        elif idx >= n:
            break
        elif idx < 0:
            continue
        s = 0.0
        for p in range(len(parts)):
            w, _, d = parts[p]
            s += math.sin(w * k) * gains[p]
            gains[p] *= d
        if k < att:
            s *= 0.5 - 0.5 * math.cos(math.pi * k / att)
        r = count - k
        if r < tail:
            s *= r / tail
        buf[idx] += s * amp


def add_pad(buf: list[float], start: float, length: float, midis, amp: float,
            attack: float = 0.9, release: float = 1.2, wrap: bool = False,
            detune: float = 0.0018, bright: float = 0.10, rng: random.Random | None = None) -> None:
    """Warm sustained chord: pairs of slightly detuned sines (slow beating) plus a touch
    of second harmonic, with smooth swell and release."""
    rng = rng or random.Random(5)
    n = len(buf)
    s0 = secs(start)
    body = secs(length)
    rel = secs(release)
    att = max(1, secs(attack))
    total = body + rel
    voices = []
    for m in midis:
        f = midi_hz(m)
        # Lower notes a little quieter so the pad never gets boomy
        g = 1.0 if f > 160.0 else 0.75
        voices.append((TAU * f * (1.0 - detune) / SR, TAU * f * (1.0 + detune) / SR,
                       rng.uniform(0.0, TAU), rng.uniform(0.0, TAU), g))
    norm = amp / max(1, len(voices))
    for k in range(total):
        if k < att:
            env = 0.5 - 0.5 * math.cos(math.pi * k / att)
        elif k < body:
            env = 1.0
        else:
            env = 0.5 + 0.5 * math.cos(math.pi * (k - body) / max(1, rel))
        if env <= 0.0:
            continue
        s = 0.0
        for w1, w2, p1, p2, g in voices:
            a1 = w1 * k + p1
            s += (math.sin(a1) + math.sin(w2 * k + p2) + bright * math.sin(2.0 * a1)) * g
        idx = s0 + k
        if wrap:
            idx %= n
        elif idx >= n:
            break
        buf[idx] += s * env * norm


def glide_tone(dur: float, freq_at, amp_at, harmonics=((1.0, 1.0),)) -> list[float]:
    """Sine (+ optional harmonics) with time-varying pitch and amplitude."""
    n = secs(dur)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += TAU * freq_at(t) / SR
        s = 0.0
        for mult, a in harmonics:
            s += math.sin(phase * mult) * a
        out[i] = s * amp_at(t)
    return out


def ar_env(t: float, attack: float, tau: float) -> float:
    """Raised-cosine attack then exponential decay."""
    if t < 0.0:
        return 0.0
    if t < attack:
        return 0.5 - 0.5 * math.cos(math.pi * t / attack)
    return math.exp(-(t - attack) / tau)


def swell_env(t: float, dur: float, peak_at: float = 0.4, power: float = 1.6) -> float:
    if t <= 0.0 or t >= dur:
        return 0.0
    u = t / dur
    if u < peak_at:
        v = u / peak_at
        return (0.5 - 0.5 * math.cos(math.pi * v)) ** 0.8
    v = (u - peak_at) / (1.0 - peak_at)
    return (0.5 + 0.5 * math.cos(math.pi * v)) ** power


# --- Reverb / delay ---------------------------------------------------------

COMB_LENGTHS = [557, 593, 641, 677, 709, 757]
ALLPASS_LENGTHS = [277, 219, 169, 113]


def reverb(x: list[float], room: float = 0.84, damp: float = 0.4, loop: bool = False,
           tail: float = 0.0, preroll: float = 6.0, predelay: float = 0.012) -> list[float]:
    """Mono Freeverb-style reverb returning only the wet signal.

    loop=True: input is treated as periodic; the filters are pre-rolled with the end
    of the buffer so the output loops seamlessly (reverb tails wrap into the head).
    loop=False: output is len(x) + tail seconds long.
    """
    n = len(x)
    pd = secs(predelay)
    if loop:
        pre = min(n, secs(preroll))
        total = pre + n

        def src(i: int) -> float:
            return x[(i - pre - pd) % n]
    else:
        pre = 0
        total = n + secs(tail)

        def src(i: int) -> float:
            j = i - pd
            return x[j] if 0 <= j < n else 0.0

    combs = [[0.0] * L for L in COMB_LENGTHS]
    cidx = [0] * len(COMB_LENGTHS)
    cstore = [0.0] * len(COMB_LENGTHS)
    aps = [[0.0] * L for L in ALLPASS_LENGTHS]
    aidx = [0] * len(ALLPASS_LENGTHS)
    out = [0.0] * (n if loop else total)
    d1 = 1.0 - damp
    nc = len(COMB_LENGTHS)
    na = len(ALLPASS_LENGTHS)
    gain = 0.18
    for i in range(total):
        inp = src(i) * gain
        acc = 0.0
        for c in range(nc):
            buf = combs[c]
            j = cidx[c]
            y = buf[j]
            cstore[c] = y * d1 + cstore[c] * damp
            buf[j] = inp + cstore[c] * room
            acc += y
            j += 1
            cidx[c] = 0 if j >= len(buf) else j
        for a in range(na):
            buf = aps[a]
            j = aidx[a]
            bo = buf[j]
            buf[j] = acc + bo * 0.5
            acc = bo - acc
            j += 1
            aidx[a] = 0 if j >= len(buf) else j
        k = i - pre
        if k >= 0:
            out[k] = acc
    return out


def echo(x: list[float], delay: float, feedback: float = 0.3, tone: float = 2500.0,
         loop: bool = False, tail: float = 0.0) -> list[float]:
    """Feedback delay with a low-passed feedback path; returns the wet signal only."""
    n = len(x)
    d = max(1, secs(delay))
    a = lp_coef(tone)
    if loop:
        pre = min(n, d * 8)
        total = pre + n
    else:
        pre = 0
        total = n + secs(tail)
    line = [0.0] * d
    out = [0.0] * (n if loop else total)
    lp = 0.0
    j = 0
    for i in range(total):
        if loop:
            inp = x[(i - pre) % n]
        else:
            inp = x[i] if i < n else 0.0
        y = line[j]
        lp += a * (y - lp)
        line[j] = inp + lp * feedback
        j += 1
        if j >= d:
            j = 0
        k = i - pre
        if k >= 0:
            out[k] = lp
    return out


def with_room(x: list[float], wet: float = 0.2, tail: float = 0.35, room: float = 0.78,
              damp: float = 0.5) -> list[float]:
    """Adds a small cozy room to a one-shot SFX (extends it by `tail` seconds)."""
    w = reverb(x, room=room, damp=damp, tail=tail)
    n = len(x)
    tail_n = max(1, len(w) - n)
    out = x + [0.0] * tail_n
    for i, s in enumerate(w):
        if i >= n:  # let the room tail die away smoothly instead of being cut off
            s *= 0.5 + 0.5 * math.cos(math.pi * (i - n) / tail_n)
        out[i] += s * wet
    return out


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

def gen_state_water() -> list[float]:
    dur = 0.28
    main = glide_tone(
        dur,
        lambda t: 280.0 + 420.0 * (1.0 - math.exp(-t * 18.0)),
        lambda t: ar_env(t, 0.006, 0.075),
        ((1.0, 1.0), (2.0, 0.10)),
    )
    bubble = glide_tone(
        0.12,
        lambda t: 600.0 + 380.0 * (1.0 - math.exp(-t * 40.0)),
        lambda t: ar_env(t, 0.004, 0.035),
    )
    out = mix((main, 1.0))
    add_into(out, bubble, 0.32, secs(0.075))
    out = lowpass(out, 3200.0)
    return fade_edges(out, 0.002, 0.03)


def gen_state_ice() -> list[float]:
    dur = 0.36
    rng = random.Random(42)
    out = zeros(dur)
    add_note(out, 0.0, midi_hz(84), 0.6, SOFT_BELL, 0.10, attack=0.002)       # C6
    add_note(out, 0.028, midi_hz(91), 0.38, SOFT_BELL, 0.085, attack=0.002)   # G6
    crunch = bandnoise(secs(0.06), rng, 700.0, 2600.0)
    for i in range(len(crunch)):
        crunch[i] *= ar_env(i / SR, 0.002, 0.012)
    add_into(out, crunch, 0.35)
    out = with_room(out, wet=0.22, tail=0.25)
    out = lowpass(out, 5200.0)
    return fade_edges(out, 0.001, 0.05)


def gen_state_steam() -> list[float]:
    dur = 0.42
    rng = random.Random(7)
    air = bandnoise(secs(dur), rng, 350.0, 2000.0)
    for i in range(len(air)):
        air[i] *= swell_env(i / SR, dur, 0.3, 1.4)
    tone = glide_tone(dur, lambda t: 520.0 + 260.0 * (t / dur), lambda t: swell_env(t, dur, 0.35, 1.5))
    out = mix((air, 2.6), (tone, 0.07))
    return fade_edges(out, 0.003, 0.03)


def gen_glass_shatter() -> list[float]:
    dur = 0.5
    rng = random.Random(101)
    out = zeros(dur)
    crack = bandnoise(secs(0.09), rng, 500.0, 2800.0)
    for i in range(len(crack)):
        crack[i] *= ar_env(i / SR, 0.002, 0.018)
    add_into(out, crack, 0.9)
    # Cascade of soft pentatonic tinkles instead of harsh shards
    notes = [84, 86, 88, 91, 93, 96, 98]
    delays = sorted(rng.uniform(0.0, 0.24) for _ in range(10))
    for i, d in enumerate(delays):
        m = notes[rng.randrange(len(notes))]
        a = 0.28 * (1.0 - 0.55 * i / len(delays)) * rng.uniform(0.75, 1.0)
        add_note(out, 0.004 + d, midi_hz(m), a, [(1.0, 1.0, 1.0), (2.76, 0.12, 2.5)],
                 rng.uniform(0.06, 0.11), attack=0.0015, max_freq=6000.0)
    out = with_room(out, wet=0.24, tail=0.3)
    out = lowpass(out, 4800.0)
    return fade_edges(out, 0.001, 0.06)


def gen_collect_star() -> list[float]:
    dur = 0.5
    out = zeros(dur)
    for m, start, a in ((79, 0.0, 0.5), (84, 0.06, 0.5), (88, 0.12, 0.55), (91, 0.19, 0.18)):
        add_note(out, start, midi_hz(m), a, MUSIC_BOX, 0.15, attack=0.003)
    out = with_room(out, wet=0.22, tail=0.3)
    out = lowpass(out, 5500.0)
    return fade_edges(out, 0.001, 0.06)


def gen_fan_toggle() -> list[float]:
    dur = 0.24
    rng = random.Random(19)
    tok = glide_tone(dur, lambda t: 230.0 + 140.0 * math.exp(-t * 30.0),
                     lambda t: ar_env(t, 0.002, 0.03), ((1.0, 1.0), (2.0, 0.12)))
    whoosh = bandnoise(secs(dur), rng, 200.0, 1100.0)
    for i in range(len(whoosh)):
        whoosh[i] *= swell_env(i / SR, dur, 0.35, 1.6)
    out = mix((tok, 0.75), (whoosh, 1.1))
    return fade_edges(out, 0.002, 0.03)


def gen_condense() -> list[float]:
    dur = 0.34
    rng = random.Random(31)
    hiss = bandnoise(secs(0.16), rng, 300.0, 1800.0)
    for i in range(len(hiss)):
        hiss[i] *= swell_env(i / SR, 0.16, 0.3, 1.5)
    drip = glide_tone(0.22, lambda t: 480.0 + 520.0 * (1.0 - math.exp(-t * 35.0)),
                      lambda t: ar_env(t, 0.003, 0.055))
    out = zeros(dur)
    add_into(out, hiss, 1.0)
    add_into(out, drip, 0.7, secs(0.07))
    out = with_room(out, wet=0.15, tail=0.12)
    return fade_edges(lowpass(out, 3500.0), 0.002, 0.04)


def gen_seedling_bloom() -> list[float]:
    dur = 1.2
    out = zeros(dur)
    arp = [72, 76, 79, 83, 84, 88]
    for i, m in enumerate(arp):
        add_note(out, i * 0.07, midi_hz(m), 0.42, HARP, 0.42, attack=0.005)
    add_pad(out, 0.05, 0.5, [60, 64, 67], 0.25, attack=0.25, release=0.55, bright=0.05)
    out = with_room(out, wet=0.26, tail=0.4)
    out = lowpass(out, 5000.0)
    return fade_edges(out, 0.002, 0.12)


def gen_seedling_shiver() -> list[float]:
    dur = 0.34

    def amp(t: float) -> float:
        return swell_env(t, dur, 0.12, 1.3) * (0.62 + 0.38 * math.sin(TAU * 21.0 * t))

    a = glide_tone(dur, lambda t: 340.0 - 40.0 * t / dur + 14.0 * math.sin(TAU * 21.0 * t), amp,
                   ((1.0, 1.0), (2.0, 0.08)))
    b = glide_tone(dur, lambda t: 345.0 - 40.0 * t / dur + 14.0 * math.sin(TAU * 21.0 * t + 1.0), amp)
    out = lowpass(mix((a, 0.6), (b, 0.4)), 2200.0)
    return fade_edges(out, 0.003, 0.03)


def gen_fail_drain() -> list[float]:
    dur = 0.62

    def freq(t: float) -> float:
        base = 170.0 + 350.0 * math.exp(-t * 4.2)
        return base * (1.0 + 0.035 * math.sin(TAU * 7.0 * t))

    main = glide_tone(dur, freq, lambda t: swell_env(t, dur, 0.06, 1.2), ((1.0, 1.0), (2.0, 0.14)))
    out = mix((main, 0.8))
    for k, start in enumerate((0.14, 0.25, 0.36)):
        blip = glide_tone(0.08, lambda t, k=k: (720.0 - 90.0 * k) - 260.0 * min(1.0, t / 0.05),
                          lambda t: ar_env(t, 0.003, 0.022))
        add_into(out, blip, 0.2 - 0.04 * k, secs(start))
    out = lowpass(out, 2600.0)
    return fade_edges(out, 0.003, 0.05)


def _tap(f_hi: float, f_lo: float, decay: float, dur: float) -> list[float]:
    out = glide_tone(dur, lambda t: f_lo + (f_hi - f_lo) * math.exp(-t * 60.0),
                     lambda t: ar_env(t, 0.0015, decay), ((1.0, 1.0), (2.0, 0.08)))
    return fade_edges(lowpass(out, 4000.0), 0.001, 0.02)


def gen_ui_tap() -> list[float]:
    return _tap(760.0, 540.0, 0.022, 0.1)


def gen_ui_back() -> list[float]:
    return _tap(540.0, 370.0, 0.028, 0.12)


def gen_ui_open() -> list[float]:
    dur = 0.2
    rng = random.Random(23)
    pop = glide_tone(dur, lambda t: 320.0 + 420.0 * (1.0 - math.exp(-t * 45.0)),
                     lambda t: ar_env(t, 0.003, 0.045), ((1.0, 1.0), (2.0, 0.1)))
    air = bandnoise(secs(dur), rng, 400.0, 2000.0)
    for i in range(len(air)):
        air[i] *= ar_env(i / SR, 0.002, 0.02)
    out = mix((pop, 0.85), (air, 0.35))
    out = with_room(out, wet=0.14, tail=0.1)
    return fade_edges(lowpass(out, 4200.0), 0.001, 0.03)


def gen_ui_whoosh() -> list[float]:
    dur = 0.36
    rng = random.Random(61)
    white = [rng.uniform(-1.0, 1.0) for _ in range(secs(dur))]
    swept = sweep_lowpass(white, lambda t: 380.0 + 1700.0 * math.sin(math.pi * min(1.0, t / dur)) ** 2)
    swept = highpass(swept, 160.0)
    for i in range(len(swept)):
        swept[i] *= swell_env(i / SR, dur, 0.42, 1.8)
    return fade_edges(swept, 0.003, 0.03)


def gen_level_start() -> list[float]:
    dur = 0.3
    out = zeros(dur)
    plip = glide_tone(0.2, lambda t: 420.0 + 700.0 * (1.0 - math.exp(-t * 32.0)),
                      lambda t: ar_env(t, 0.002, 0.05))
    plip2 = glide_tone(0.12, lambda t: 720.0 + 600.0 * (1.0 - math.exp(-t * 40.0)),
                       lambda t: ar_env(t, 0.002, 0.032))
    add_into(out, plip, 0.8)
    add_into(out, plip2, 0.3, secs(0.11))
    out = with_room(out, wet=0.2, tail=0.15)
    return fade_edges(lowpass(out, 3800.0), 0.001, 0.04)


def gen_fail_splat() -> list[float]:
    dur = 0.45
    rng = random.Random(83)
    splat = bandnoise(secs(0.2), rng, 120.0, 900.0)
    for i in range(len(splat)):
        splat[i] *= ar_env(i / SR, 0.003, 0.045)
    deflate = glide_tone(
        dur,
        lambda t: (110.0 + 230.0 * math.exp(-t * 6.0)) * (1.0 + 0.06 * math.sin(TAU * 9.0 * t)),
        lambda t: swell_env(t, dur, 0.08, 1.1),
        ((1.0, 1.0), (2.0, 0.2)),
    )
    out = mix((deflate, 0.55))
    add_into(out, splat, 1.0)
    for start, f0 in ((0.11, 900.0), (0.19, 760.0)):
        blip = glide_tone(0.07, lambda t, f0=f0: f0 - 300.0 * min(1.0, t / 0.05),
                          lambda t: ar_env(t, 0.002, 0.018))
        add_into(out, blip, 0.12, secs(start))
    out = lowpass(out, 2500.0)
    return fade_edges(out, 0.002, 0.05)


def gen_evaporate() -> list[float]:
    dur = 0.55
    rng = random.Random(97)
    n = secs(dur)
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    fizz = sweep_lowpass(white, lambda t: 500.0 * (7.0 ** min(1.0, t / dur)))
    fizz = highpass(fizz, 260.0)
    for i in range(n):
        fizz[i] *= swell_env(i / SR, dur, 0.3, 1.3)
    shimmer = glide_tone(
        dur,
        lambda t: 600.0 * (2.0 ** (t / dur)),
        lambda t: swell_env(t, dur, 0.4, 1.4) * (0.7 + 0.3 * math.sin(TAU * 14.0 * t)),
    )
    out = mix((fizz, 1.2), (shimmer, 0.12))
    for _ in range(10):
        start = rng.uniform(0.05, 0.42)
        add_note(out, start, rng.uniform(1500.0, 2600.0), 0.05, PURE, 0.012, attack=0.0015)
    out = lowpass(out, 5000.0)
    return fade_edges(out, 0.003, 0.05)


def gen_win_jingle() -> list[float]:
    dur = 1.35
    out = zeros(dur)
    run = [(0.00, 72), (0.11, 76), (0.22, 79), (0.33, 84), (0.50, 81), (0.61, 84)]
    for start, m in run:
        add_note(out, start, midi_hz(m), 0.36, MARIMBA, 0.2, attack=0.004)
        add_note(out, start, midi_hz(m + 12), 0.08, MUSIC_BOX, 0.12, attack=0.003)
    final = 0.80
    for m, a in ((76, 0.3), (79, 0.3), (84, 0.34), (88, 0.18)):
        add_note(out, final, midi_hz(m), a, MUSIC_BOX, 0.42, attack=0.004)
    add_note(out, final, midi_hz(60), 0.32, MARIMBA, 0.4, attack=0.006)
    add_pad(out, 0.72, 0.25, [60, 64, 67, 72], 0.3, attack=0.12, release=0.35, bright=0.06)
    out = with_room(out, wet=0.26, tail=0.4)
    out = lowpass(out, 5200.0)
    return fade_edges(out, 0.002, 0.15)


def gen_star_whoosh() -> list[float]:
    dur = 0.3
    rng = random.Random(71)
    white = [rng.uniform(-1.0, 1.0) for _ in range(secs(dur))]
    swish = sweep_lowpass(white, lambda t: 600.0 + 2200.0 * min(1.0, t / dur))
    swish = highpass(swish, 400.0)
    for i in range(len(swish)):
        swish[i] *= swell_env(i / SR, dur, 0.35, 1.8)
    out = mix((swish, 0.7))
    for start, m, a in ((0.04, 84, 0.2), (0.09, 88, 0.16), (0.14, 91, 0.12), (0.19, 96, 0.07)):
        add_note(out, start, midi_hz(m), a, [(1.0, 1.0, 1.0), (2.0, 0.1, 1.6)], 0.06, attack=0.002)
    out = with_room(out, wet=0.18, tail=0.15)
    return fade_edges(lowpass(out, 5200.0), 0.002, 0.04)


def gen_unlock() -> list[float]:
    dur = 0.9
    out = zeros(dur)
    for start, m, a in ((0.0, 79, 0.4), (0.12, 84, 0.42), (0.24, 88, 0.42), (0.38, 91, 0.16)):
        add_note(out, start, midi_hz(m), a, BELL, 0.3, attack=0.003)
    add_pad(out, 0.02, 0.35, [60, 67, 72], 0.22, attack=0.18, release=0.4, bright=0.05)
    out = with_room(out, wet=0.28, tail=0.4)
    out = lowpass(out, 5200.0)
    return fade_edges(out, 0.002, 0.12)


def gen_sponge_soak() -> list[float]:
    dur = 0.3
    rng = random.Random(55)
    slurp = glide_tone(dur, lambda t: (200.0 + 320.0 * t / dur) * (1.0 + 0.05 * math.sin(TAU * 12.0 * t)),
                       lambda t: swell_env(t, dur, 0.4, 1.4))
    squish = bandnoise(secs(dur), rng, 150.0, 700.0)
    for i in range(len(squish)):
        t = i / SR
        squish[i] *= swell_env(t, dur, 0.3, 1.4) * (0.6 + 0.4 * math.sin(TAU * 17.0 * t))
    out = mix((slurp, 0.5), (squish, 1.6))
    return fade_edges(lowpass(out, 2000.0), 0.004, 0.03)


def gen_sponge_squeeze() -> list[float]:
    dur = 0.34
    rng = random.Random(77)
    tone = glide_tone(0.26, lambda t: (540.0 - 240.0 * t / 0.26) * (1.0 + 0.06 * math.sin(TAU * 16.0 * t)),
                      lambda t: swell_env(t, 0.26, 0.15, 1.3))
    squish = bandnoise(secs(0.26), rng, 180.0, 900.0)
    for i in range(len(squish)):
        squish[i] *= swell_env(i / SR, 0.26, 0.15, 1.3)
    out = zeros(dur)
    add_into(out, tone, 0.5)
    add_into(out, squish, 1.5)
    for start, f0 in ((0.2, 620.0), (0.27, 780.0)):
        drip = glide_tone(0.07, lambda t, f0=f0: f0 + 300.0 * (1.0 - math.exp(-t * 50.0)),
                          lambda t: ar_env(t, 0.002, 0.02))
        add_into(out, drip, 0.25, secs(start))
    return fade_edges(lowpass(out, 2400.0), 0.003, 0.03)


def gen_hotplate_sizzle() -> list[float]:
    dur = 0.5
    rng = random.Random(91)
    n = secs(dur)
    hiss = bandnoise(n, rng, 1300.0, 4200.0)
    flutter = lowpass([rng.uniform(0.0, 1.0) for _ in range(n)], 30.0, 2)
    fmax = max(flutter) or 1.0
    for i in range(n):
        hiss[i] *= swell_env(i / SR, dur, 0.06, 1.2) * (0.45 + 0.55 * flutter[i] / fmax)
    out = mix((hiss, 1.0))
    for _ in range(16):
        start = rng.uniform(0.02, 0.4)
        pop = bandnoise(secs(0.012), rng, 900.0, 3500.0, 1)
        for i in range(len(pop)):
            pop[i] *= ar_env(i / SR, 0.0008, 0.0025)
        add_into(out, pop, rng.uniform(0.3, 0.6), secs(start))
    out = lowpass(out, 5000.0)
    return fade_edges(out, 0.008, 0.05)


def gen_star_fanfare() -> list[float]:
    dur = 0.55
    out = zeros(dur)
    add_note(out, 0.0, 880.0, 0.55, SOFT_BELL, 0.2, attack=0.003)
    add_note(out, 0.0, 1318.5, 0.28, PURE, 0.16, attack=0.003)
    add_note(out, 0.01, 1760.0, 0.08, PURE, 0.1, attack=0.003)
    out = with_room(out, wet=0.22, tail=0.3)
    out = lowpass(out, 5200.0)
    return fade_edges(out, 0.001, 0.08)


# name -> (generator, peak)
SFX = {
    "state_water.wav": (gen_state_water, 0.62),
    "state_ice.wav": (gen_state_ice, 0.68),
    "state_steam.wav": (gen_state_steam, 0.7),
    "glass_shatter.wav": (gen_glass_shatter, 0.78),
    "collect_star.wav": (gen_collect_star, 0.85),
    "fan_toggle.wav": (gen_fan_toggle, 0.75),
    "condense.wav": (gen_condense, 0.82),
    "seedling_bloom.wav": (gen_seedling_bloom, 0.85),
    "seedling_shiver.wav": (gen_seedling_shiver, 0.58),
    "fail_drain.wav": (gen_fail_drain, 0.48),
    "ui_tap.wav": (gen_ui_tap, 0.8),
    "ui_back.wav": (gen_ui_back, 0.68),
    "ui_open.wav": (gen_ui_open, 0.72),
    "ui_whoosh.wav": (gen_ui_whoosh, 0.55),
    "level_start.wav": (gen_level_start, 0.72),
    "fail_splat.wav": (gen_fail_splat, 0.52),
    "evaporate.wav": (gen_evaporate, 0.65),
    "win_jingle.wav": (gen_win_jingle, 0.85),
    "star_whoosh.wav": (gen_star_whoosh, 0.6),
    "unlock.wav": (gen_unlock, 0.75),
    "sponge_soak.wav": (gen_sponge_soak, 0.55),
    "sponge_squeeze.wav": (gen_sponge_squeeze, 0.66),
    "hotplate_sizzle.wav": (gen_hotplate_sizzle, 0.5),
    "star_fanfare.wav": (gen_star_fanfare, 0.7),
}


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def _humanize(rng: random.Random, beat_sec: float, beat: float, vel: float) -> tuple[float, float]:
    return beat * beat_sec + rng.uniform(-0.006, 0.006), vel * rng.uniform(0.88, 1.0)


def _master(layers, reverb_send, room: float, damp: float, wet: float, cutoff: float) -> list[float]:
    """Sums layers, adds a looped reverb, gentle top-end roll-off, DC removal."""
    dry = mix(*layers)
    send = mix(*[(layer, gain * s) for (layer, gain), s in zip(layers, reverb_send)])
    wet_sig = reverb(send, room=room, damp=damp, loop=True)
    out = [d + w * wet for d, w in zip(dry, wet_sig)]
    out = lowpass(out, cutoff, 1, loop=True)
    return remove_dc(out)


def gen_music_greenhouse() -> list[float]:
    """Soft, airy C-major loop: warm pad, kalimba melody with echo, marimba counterline.
    84 bpm, 12 bars of 4/4 (exactly 756000 samples ~ 34.3 s)."""
    rng = random.Random(2024)
    beat = 60.0 / 84.0
    bar = beat * 4.0
    bars = 12
    n = 15750 * 4 * bars  # 15750 samples per beat at 84 bpm
    chords = [
        (48, [55, 59, 62, 64]),  # Cmaj9
        (45, [55, 60, 64, 67]),  # Am7
        (41, [53, 57, 60, 64]),  # Fmaj7
        (43, [55, 59, 62, 64]),  # G6
        (48, [55, 59, 62, 64]),  # Cmaj9
        (40, [52, 55, 59, 62]),  # Em7
        (41, [57, 60, 64, 67]),  # Fmaj9
        (43, [55, 59, 62, 64]),  # G6
        (45, [55, 60, 64, 67]),  # Am7
        (41, [53, 57, 60, 64]),  # Fmaj7
        (50, [53, 57, 60, 62]),  # Dm7
        (43, [55, 60, 62, 67]),  # Gsus4
    ]
    melody = [
        (0.0, 76), (1.0, 79), (1.5, 81), (2.5, 79),
        (4.5, 72), (5.0, 74), (6.0, 76),
        (8.0, 81), (9.0, 79), (9.5, 76), (10.5, 74),
        (12.0, 74), (13.0, 76), (14.0, 79),
        (16.0, 76), (16.5, 79), (17.0, 84), (18.0, 81), (19.0, 79),
        (20.0, 79), (21.0, 76), (22.0, 74), (22.5, 76),
        (24.0, 81), (25.0, 84), (26.0, 81), (27.0, 79),
        (28.0, 76), (29.5, 74), (30.0, 76),
        (32.0, 84), (33.0, 81), (33.5, 79), (34.0, 76),
        (36.0, 81), (37.0, 79), (38.5, 76),
        (40.0, 74), (41.0, 76), (42.0, 81), (43.0, 79),
        (44.0, 74), (45.0, 72), (46.0, 74),
    ]
    pad = [0.0] * n
    bass = [0.0] * n
    lead = [0.0] * n
    counter = [0.0] * n
    for b, (root, voicing) in enumerate(chords):
        add_pad(pad, b * bar, bar, voicing, 1.0, attack=1.0, release=1.4, wrap=True, rng=rng)
        add_pad(bass, b * bar, bar, [root], 1.0, attack=0.6, release=1.0, wrap=True, bright=0.3, rng=rng)
        for off, idx, vel in ((1.5, 3, 0.8), (3.0, 2, 0.65)):
            t, v = _humanize(rng, beat, b * 4 + off, vel)
            add_note(counter, t, midi_hz(voicing[idx]), v, MARIMBA, 0.32, attack=0.006, wrap=True)
    for pos, m in melody:
        t, v = _humanize(rng, beat, pos, 1.0)
        add_note(lead, t, midi_hz(m), v, KALIMBA, 0.5, attack=0.004, wrap=True)
    lead_echo = echo(lead, beat * 0.75, feedback=0.34, tone=2200.0, loop=True)
    lead_bus = [a + e * 0.32 for a, e in zip(lead, lead_echo)]
    layers = [(pad, 0.11), (bass, 0.07), (lead_bus, 0.30), (counter, 0.2)]
    return _master(layers, [0.6, 0.2, 1.0, 0.8], room=0.86, damp=0.45, wet=0.24, cutoff=6000.0)


def gen_music_kitchen() -> list[float]:
    """Cozy, bouncier F-major loop: plucked bass, marimba comps, music-box melody,
    whisper-quiet shaker. 100 bpm, 12 bars (exactly 635040 samples ~ 28.8 s)."""
    rng = random.Random(4242)
    beat = 60.0 / 100.0
    bar = beat * 4.0
    bars = 12
    n = 13230 * 4 * bars  # 13230 samples per beat at 100 bpm
    chords = [
        (41, [57, 60, 62, 65]),  # F6
        (50, [53, 57, 60, 62]),  # Dm7
        (46, [50, 53, 57, 62]),  # Bbmaj7
        (48, [52, 55, 60, 64]),  # C
        (41, [57, 60, 62, 65]),  # F6
        (45, [55, 60, 64, 67]),  # Am7
        (46, [53, 57, 62, 65]),  # Bbmaj7
        (48, [53, 55, 58, 60]),  # C7sus4
        (50, [53, 57, 60, 64]),  # Dm9
        (46, [53, 58, 62, 65]),  # Bb
        (43, [50, 53, 58, 62]),  # Gm7
        (48, [52, 55, 58, 64]),  # C7
    ]
    melody = [
        (0.0, 81), (0.5, 84), (1.0, 81), (2.0, 79), (2.5, 77), (3.0, 79),
        (4.0, 81), (5.0, 77), (5.5, 74), (6.0, 77), (7.0, 79),
        (8.0, 86), (8.5, 84), (9.0, 81), (10.0, 77), (11.0, 79),
        (12.0, 79), (12.5, 81), (13.0, 84), (14.0, 79),
        (16.0, 77), (16.5, 81), (17.0, 84), (17.5, 86), (18.0, 84), (19.0, 81),
        (20.0, 84), (21.0, 81), (21.5, 79), (22.0, 81),
        (24.0, 86), (25.0, 84), (25.5, 81), (26.0, 77), (27.0, 74),
        (28.0, 77), (28.5, 79), (29.0, 81), (30.0, 79),
        (32.0, 77), (32.5, 81), (33.0, 86), (34.0, 84), (34.5, 81), (35.0, 77),
        (36.0, 86), (36.5, 84), (37.0, 81), (38.0, 77),
        (40.0, 79), (40.5, 81), (41.0, 86), (42.0, 84), (43.0, 81),
        (44.0, 79), (45.0, 84), (45.5, 81), (46.0, 79), (47.5, 79),
    ]
    pad = [0.0] * n
    bass = [0.0] * n
    comp = [0.0] * n
    lead = [0.0] * n
    shaker = [0.0] * n
    for b, (root, voicing) in enumerate(chords):
        add_pad(pad, b * bar, bar, voicing, 1.0, attack=0.7, release=1.0, wrap=True, bright=0.08, rng=rng)
        for off, interval, vel, tau in ((0.0, 0, 1.0, 0.32), (1.5, 7, 0.62, 0.2),
                                        (2.0, 12, 0.75, 0.24), (3.0, 7, 0.6, 0.2)):
            t, v = _humanize(rng, beat, b * 4 + off, vel)
            add_note(bass, t, midi_hz(root + interval), v, PLUCK_BASS, tau, attack=0.007, wrap=True)
        for off in (1.0, 3.0):
            t, v = _humanize(rng, beat, b * 4 + off, 1.0)
            for m in voicing[1:]:
                add_note(comp, t, midi_hz(m), v, MARIMBA, 0.15, attack=0.005, wrap=True)
    for pos, m in melody:
        t, v = _humanize(rng, beat, pos, 1.0)
        add_note(lead, t, midi_hz(m), v, MUSIC_BOX, 0.42, attack=0.003, wrap=True)
        add_note(lead, t + 0.004, midi_hz(m - 12), v * 0.22, KALIMBA, 0.3, attack=0.004, wrap=True)
    # Brushed shaker on eighths, offbeats a touch stronger
    hit_len = secs(0.09)
    for e in range(bars * 8):
        t, v = _humanize(rng, beat, e * 0.5, 1.0 if e % 2 else 0.55)
        hit = bandnoise(hit_len, rng, 2500.0, 6000.0, 1)
        start = secs(t)
        for i in range(hit_len):
            shaker[(start + i) % n] += hit[i] * ar_env(i / SR, 0.006, 0.022) * v
    lead_echo = echo(lead, beat * 0.75, feedback=0.28, tone=2400.0, loop=True)
    lead_bus = [a + e * 0.25 for a, e in zip(lead, lead_echo)]
    layers = [(pad, 0.06), (bass, 0.20), (comp, 0.11), (lead_bus, 0.24), (shaker, 0.24)]
    return _master(layers, [0.5, 0.2, 0.6, 1.0, 0.4], room=0.82, damp=0.5, wet=0.19, cutoff=6000.0)


def gen_music_menu() -> list[float]:
    """Dreamy, slow C-major lullaby loop for menus: big soft pad, music-box melody,
    gentle kalimba arpeggio. 90 bpm, 8 bars (exactly 470400 samples ~ 21.3 s)."""
    rng = random.Random(777)
    beat = 60.0 / 90.0
    bars = 8
    n = 14700 * 4 * bars  # 14700 samples per beat at 90 bpm
    chords = [  # two bars each
        (41, [57, 60, 64, 67]),  # Fmaj9
        (48, [55, 59, 62, 64]),  # Cmaj9
        (45, [52, 55, 60, 64]),  # Am7
        (43, [55, 57, 62, 67]),  # Gsus2
    ]
    melody = [
        (0.0, 81), (1.5, 79), (2.0, 76), (4.0, 79), (6.0, 76), (7.0, 74),
        (8.0, 76), (9.5, 79), (10.0, 84), (12.0, 79), (14.0, 76),
        (16.0, 84), (17.5, 81), (18.0, 79), (20.0, 76), (22.0, 79), (23.0, 81),
        (24.0, 79), (25.5, 81), (26.0, 74), (28.0, 74),
    ]
    pad = [0.0] * n
    bass = [0.0] * n
    arp = [0.0] * n
    lead = [0.0] * n
    pattern = [0, 1, 2, 3, 2, 1, 2, 3]
    for c, (root, voicing) in enumerate(chords):
        start = c * 8 * beat
        add_pad(pad, start, 8 * beat, voicing, 1.0, attack=1.6, release=2.0, wrap=True, rng=rng)
        add_pad(bass, start, 8 * beat, [root], 1.0, attack=1.0, release=1.6, wrap=True, bright=0.3, rng=rng)
        for k, idx in enumerate(pattern):
            t, v = _humanize(rng, beat, c * 8 + k, 0.85 if k % 2 == 0 else 0.6)
            add_note(arp, t, midi_hz(voicing[idx] + 12), v, KALIMBA, 0.4, attack=0.005, wrap=True)
    for pos, m in melody:
        t, v = _humanize(rng, beat, pos, 1.0)
        add_note(lead, t, midi_hz(m), v, MUSIC_BOX, 0.6, attack=0.004, wrap=True)
    lead_echo = echo(lead, beat * 1.5, feedback=0.35, tone=2000.0, loop=True)
    lead_bus = [a + e * 0.3 for a, e in zip(lead, lead_echo)]
    layers = [(pad, 0.14), (bass, 0.06), (arp, 0.07), (lead_bus, 0.26)]
    return _master(layers, [0.7, 0.2, 1.0, 1.0], room=0.9, damp=0.45, wet=0.28, cutoff=5500.0)


MUSIC = {
    "music_greenhouse.wav": gen_music_greenhouse,
    "music_kitchen.wav": gen_music_kitchen,
    "music_menu.wav": gen_music_menu,
}


# ---------------------------------------------------------------------------
# Images (unchanged)
# ---------------------------------------------------------------------------

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


def generate_audio() -> None:
    for name, (gen, peak) in SFX.items():
        write_wav(name, gen(), peak)
    print(f"Generated {len(SFX)} SFX WAV files in {AUDIO_DIR}")
    for name, gen in MUSIC.items():
        data = gen()
        write_wav(name, data, MUSIC_PEAK)
        ensure_loop_import(name)
        print(f"  {name}: {len(data)} samples ({len(data) / SAMPLE_RATE:.2f} s, seamless loop)")
    print(f"Generated {len(MUSIC)} music loops in {AUDIO_DIR}")


def generate_images(force: bool) -> None:
    """Icons/textures are only rendered when missing (or with --images), so running
    this script never touches existing image assets."""
    tex_dir = os.path.join(ROOT, "assets", "textures")
    jobs = [
        # Launcher icons are rendered from the in-game art by tools/render_icon.gd
        # (godot --rendering-driver opengl3 -s res://tools/render_icon.gd); this
        # fallback only fills them in if they are missing.
        (os.path.join(ICON_DIR, "icon_192.png"), lambda p: render_icon_png(p, 192)),
        (os.path.join(ICON_DIR, "icon_432.png"), lambda p: render_icon_png(p, 432)),
        (os.path.join(tex_dir, "soft_glow.png"), lambda p: render_soft_glow_png(p, 128)),
        (os.path.join(tex_dir, "paper_grain.png"), lambda p: render_paper_grain_png(p, 128)),
    ]
    made = 0
    for path, render in jobs:
        if force or not os.path.exists(path):
            render(path)
            made += 1
    print(f"Generated {made} PNG image(s) (existing images left untouched unless --images)")


def main() -> None:
    generate_audio()
    generate_images("--images" in sys.argv[1:])


if __name__ == "__main__":
    main()
