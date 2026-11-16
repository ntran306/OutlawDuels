"""Synthesises every OutlawDuels sound (docs/GUI.md section 8).

Python standard library only, fixed seeds, so two runs give byte-identical files.
Nothing is sampled from a recording. Output: mono 44,100 Hz 16-bit WAV under
App/Resources/Audio/.

    python tools/make_audio.py           # write all files
    python tools/make_audio.py --check   # write, then verify length and peak against the spec
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "App" / "Resources" / "Audio"
TAU = 2 * math.pi


# ---------- building blocks ----------

def silence(seconds):
    return [0.0] * int(round(seconds * SR))


def white(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def pink(n, rng):
    """Paul Kellet's economy pink-noise filter."""
    b0 = b1 = b2 = 0.0
    out = []
    for _ in range(n):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out.append((b0 + b1 + b2 + w * 0.1848) * 0.25)
    return out


def decay(x, tau_s, attack_s=0.0):
    """Multiply by an exponential decay with time constant tau, after a linear attack."""
    a = max(1, int(attack_s * SR))
    out = []
    for i, v in enumerate(x):
        e = math.exp(-i / (tau_s * SR))
        if attack_s > 0 and i < a:
            e *= i / a
        out.append(v * e)
    return out


def sine(n, freq, phase=0.0):
    return [math.sin(TAU * freq * i / SR + phase) for i in range(n)]


def sweep(n, f_start, f_end, vibrato_hz=0.0, vibrato_depth=0.0, exponential=True):
    """Sine whose frequency moves from f_start to f_end over n samples."""
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        if exponential:
            f = f_start * (f_end / f_start) ** t
        else:
            f = f_start + (f_end - f_start) * t
        if vibrato_hz:
            f *= 1.0 + vibrato_depth * math.sin(TAU * vibrato_hz * i / SR)
        phase += TAU * f / SR
        out.append(math.sin(phase))
    return out


def biquad(x, kind, f0, q=0.7071):
    """RBJ cookbook low-pass or high-pass."""
    w0 = TAU * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:
        raise ValueError(kind)
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for v in x:
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out.append(y)
    return out


def bandpass(x, lo, hi):
    return biquad(biquad(x, "hp", lo), "lp", hi)


def mix(*tracks):
    """Sum (samples, gain, offset_seconds) tuples into one list."""
    n = max(len(s) + int(round(off * SR)) for s, _, off in tracks)
    out = [0.0] * n
    for s, gain, off in tracks:
        o = int(round(off * SR))
        for i, v in enumerate(s):
            out[o + i] += v * gain
    return out


def fit(x, seconds, fade_s=0.004):
    """Cut or pad to an exact length and fade the last few ms so the file ends at zero."""
    n = int(round(seconds * SR))
    x = (x + [0.0] * n)[:n]
    f = min(n, int(fade_s * SR))
    for i in range(f):
        x[n - 1 - i] *= i / f
    return x


def normalise(x, peak_db):
    peak = max(abs(v) for v in x) or 1.0
    g = (10 ** (peak_db / 20.0)) / peak
    return [v * g for v in x]


def db(gain_db):
    return 10 ** (gain_db / 20.0)


def pluck(freq, seconds, rng, damping=0.996, brightness=0.5):
    """Karplus-Strong plucked string."""
    period = max(2, int(round(SR / freq)))
    buf = [rng.uniform(-1.0, 1.0) for _ in range(period)]
    # Soften the excitation so the pluck is not harsh.
    for i in range(1, period):
        buf[i] = brightness * buf[i] + (1 - brightness) * buf[i - 1]
    out = []
    idx = 0
    for _ in range(int(seconds * SR)):
        nxt = (idx + 1) % period
        v = buf[idx]
        out.append(v)
        buf[idx] = damping * 0.5 * (v + buf[nxt])
        idx = nxt
    return out


def click(rng, lo, hi):
    """A 3 ms noise burst, band-passed, with a short ring-out."""
    burst = white(int(0.003 * SR), rng) + [0.0] * int(0.020 * SR)
    return decay(bandpass(burst, lo, hi), 0.006)


def write(rel_path, samples):
    path = OUT / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(round(v * 32767))))) for v in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


# ---------- recipes (docs/GUI.md section 8) ----------

def make_cock(rng):
    c1 = click(rng, 2000, 6000)
    c2 = click(rng, 2000, 6000)
    return mix((c1, 1.0, 0.0), (c2, db(3), 0.070))


def make_hit(rng, seconds):
    n = int(seconds * SR)
    thud = decay(biquad(white(n, rng), "lp", 600), 0.030)
    body = decay(sine(n, 140), 0.050)
    return mix((thud, 1.0, 0.0), (body, 0.9, 0.0))


def make_tap(rng, freq, seconds):
    n = int(seconds * SR)
    knock = decay(sine(n, freq), 0.012)
    tick = white(int(0.002 * SR), rng)
    return mix((knock, 1.0, 0.0), (tick, 0.35, 0.0))


def recipes():
    out = {}

    rng = random.Random(101)
    n = int(0.28 * SR)
    crack = decay(bandpass(white(n, rng), 900, 5000), 0.045, attack_s=0.002)
    boom = decay(sweep(n, 180, 60), 0.060)
    shot = [max(-0.9, min(0.9, v)) for v in normalise(mix((crack, 1.0, 0.0), (boom, 0.9, 0.0)), 3.0)]
    out["Sfx/shot.wav"] = (shot, 0.28, -1)

    n = int(0.45 * SR)
    out["Sfx/ricochet.wav"] = (
        decay(sweep(n, 2400, 900, vibrato_hz=14, vibrato_depth=0.03), 0.150, attack_s=0.002), 0.45, -6)

    out["Sfx/hit.wav"] = (make_hit(random.Random(103), 0.14), 0.14, -3)

    rng = random.Random(104)
    n = int(0.50 * SR)
    bell = mix((decay(sine(n, 1318), 0.180), 0.6, 0.0), (decay(sine(n, 1976), 0.180), 0.4, 0.0))
    out["Sfx/bull.wav"] = (mix((make_hit(rng, 0.14), 1.0, 0.0), (bell, 0.8, 0.0)), 0.50, -3)

    out["Sfx/cock.wav"] = (make_cock(random.Random(105)), 0.18, -6)

    out["Sfx/dry.wav"] = (click(random.Random(106), 1500, 4000), 0.06, -9)

    rng = random.Random(107)
    n = int(0.22 * SR)
    hurt = mix((decay(sine(n, 90), 0.080), 1.0, 0.0),
               (decay(biquad(white(n, rng), "lp", 300), 0.080), 0.8, 0.0))
    out["Sfx/hurt.wav"] = (hurt, 0.22, -3)

    out["Ui/ui_tap.wav"] = (make_tap(random.Random(108), 420, 0.05), 0.05, -12)

    rng = random.Random(109)
    n = int(0.30 * SR)
    jingle = []
    for k in range(5):
        freq = 3100 + (5400 - 3100) * k / 4
        onset = rng.uniform(0.0, 0.060)
        jingle.append((decay(sine(n - int(onset * SR), freq), 0.070, attack_s=0.001), 1.0 - 0.1 * k, onset))
    out["Ui/ui_confirm.wav"] = (mix(*jingle), 0.30, -9)

    out["Ui/ui_back.wav"] = (make_tap(random.Random(110), 300, 0.08), 0.08, -12)

    # Whoosh: noise through a state-variable band-pass whose centre sweeps 400 -> 1600 -> 600 Hz.
    rng = random.Random(111)
    n = int(0.40 * SR)
    low = band = 0.0
    whoosh = []
    for i in range(n):
        t = i / n
        fc = 400 + (1600 - 400) * (t / 0.5) if t < 0.5 else 1600 + (600 - 1600) * ((t - 0.5) / 0.5)
        f = 2 * math.sin(math.pi * fc / SR)
        high = rng.uniform(-1.0, 1.0) - low - 0.6 * band
        band += f * high
        low += f * band
        whoosh.append(band * math.sin(math.pi * t))
    out["Ui/ui_whoosh.wav"] = (whoosh, 0.40, -15)

    out["Ui/count_tick.wav"] = (decay(sine(int(0.10 * SR), 660), 0.030, attack_s=0.001), 0.10, -6)

    rng = random.Random(113)
    n = int(0.35 * SR)
    out["Ui/count_draw.wav"] = (
        mix((decay(sine(n, 990), 0.090, attack_s=0.001), 1.0, 0.0), (make_cock(rng), 0.8, 0.0)), 0.35, -3)

    E2, B2, D3, E3, GS3, B3, E4, E5, FS5 = 82.41, 123.47, 146.83, 164.81, 207.65, 246.94, 329.63, 659.26, 739.99

    rng = random.Random(114)
    wn = int(0.60 * SR)
    whistle = sweep(wn, E5, FS5, vibrato_hz=5.5, vibrato_depth=0.006, exponential=False)
    whistle = [v * math.sin(math.pi * i / wn) ** 0.7 for i, v in enumerate(whistle)]
    sting = mix((pluck(E2, 1.6, rng), 1.0, 0.0), (pluck(B2, 1.4, rng), 0.9, 0.180),
                (pluck(E3, 1.2, rng), 0.9, 0.360), (pluck(GS3, 0.95, rng), 0.8, 0.620),
                (pluck(B3, 0.95, rng), 0.8, 0.620), (whistle, 0.35, 0.900))
    out["Music/sting_launch.wav"] = (fit(sting, 1.60, fade_s=0.300), 1.60, -3)

    rng = random.Random(115)
    notes = [E3, GS3, B3, E4]
    res = mix(*[(pluck(f, 1.2 - 0.110 * i, rng), 0.9, 0.110 * i) for i, f in enumerate(notes)])
    out["Music/sting_results.wav"] = (fit(res, 1.20, fade_s=0.250), 1.20, -3)

    rng = random.Random(116)
    notes = [E3, D3, B2]
    down = mix(*[(pluck(f, 1.0 - 0.160 * i, rng), 0.9, 0.160 * i) for i, f in enumerate(notes)])
    out["Music/sting_down.wav"] = (fit(down, 1.00, fade_s=0.250), 1.00, -3)

    # Desert wind, 30 s seamless loop: 31 s generated, the last 1 s cross-faded into the first.
    rng = random.Random(117)
    total = 31 * SR
    src = pink(total, rng)
    wind = []
    y1 = y2 = 0.0
    for i in range(total):
        t = i / SR
        cutoff = 475 + 225 * math.sin(TAU * 0.07 * t)
        a = 1 - math.exp(-TAU * cutoff / SR)
        y1 += a * (src[i] - y1)
        y2 += a * (y1 - y2)
        wind.append(y2 * (0.65 + 0.35 * math.sin(TAU * 0.11 * t + 1.3)))
    wind = normalise(wind, 0.0)
    hn = int(0.5 * SR)
    cry = [v * math.sin(math.pi * i / hn) for i, v in enumerate(sweep(hn, 2600, 1900))]
    wind = mix((wind, 1.0, 0.0), (cry, db(-12), 7.0), (cry, db(-12), 21.5))
    loop = wind[:30 * SR]
    for i in range(SR):
        k = i / SR
        loop[i] = loop[i] * k + wind[30 * SR + i] * (1 - k)
    out["Ambience/desert_loop.wav"] = (loop, 30.0, -18)

    return out


def main():
    check = "--check" in sys.argv
    failures = 0
    for rel, (samples, seconds, peak_db) in recipes().items():
        if rel.startswith("Ambience/"):
            data = (samples + [0.0] * int(seconds * SR))[:int(round(seconds * SR))]  # a loop is not faded
        elif rel.startswith("Music/"):
            data = samples  # already fitted with a long fade
        else:
            data = fit(samples, seconds)
        data = normalise(data, peak_db)
        write(rel, data)
        if check:
            with wave.open(str(OUT / rel), "rb") as w:
                raw = w.readframes(w.getnframes())
                length = w.getnframes() / w.getframerate()
            peak = max(abs(v[0]) for v in struct.iter_unpack("<h", raw)) / 32767
            peak_meas = 20 * math.log10(peak)
            ok = abs(length - seconds) <= 0.010 and abs(peak_meas - peak_db) <= 0.5
            failures += 0 if ok else 1
            print(f"{'ok  ' if ok else 'FAIL'} {rel:28s} {length:6.3f} s  {peak_meas:6.2f} dBFS")
    if check and failures:
        sys.exit(f"{failures} file(s) outside the spec")


if __name__ == "__main__":
    main()
