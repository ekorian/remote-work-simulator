#!/usr/bin/env python3
"""Generate every sound in the game procedurally (no samples, no licences).

    python3 tools/gen_audio.py        # writes assets/audio/*.wav

Deterministic: same output every run. Requires numpy.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.08, curve=1.0):
    """Attack / release envelope over n samples."""
    e = np.ones(n)
    na, nr = max(1, int(SR * a)), max(1, int(SR * r))
    na, nr = min(na, n), min(nr, n)
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def decay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sine(f, d, ph=0.0):
    return np.sin(2 * np.pi * f * t(d) + ph)


def tone(f, d, harm=(1.0,), k=8.0):
    x = sum(a * sine(f * (i + 1), d) for i, a in enumerate(harm))
    return x * decay(len(x), k)


def sweep(f0, f1, d):
    tt = t(d)
    f = f0 + (f1 - f0) * (tt / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(sig, start, total):
    out = np.zeros(int(SR * total))
    i = int(SR * start)
    j = min(len(out), i + len(sig))
    out[i:j] += sig[: j - i]
    return out


def seq(notes, step, d, **kw):
    total = step * len(notes) + d
    out = np.zeros(int(SR * total))
    for i, f in enumerate(notes):
        if f:
            out += at(tone(f, d, **kw), i * step, total)
    return out


def loopable(x, fade=0.08):
    """Cross-fade the tail into the head so the sample loops without a click."""
    n = int(SR * fade)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note(n):
    """MIDI note number to frequency."""
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------------------
# UI and feedback
# ---------------------------------------------------------------------------

def ui():
    save("click", tone(1250, 0.05, (1, 0.3), 70) * env(int(SR * 0.05), 0.001, 0.03), 0.5)
    save("tick", tone(1900, 0.03, (1,), 120), 0.35)
    save("pop", sweep(420, 980, 0.07) * env(int(SR * 0.07), 0.002, 0.04), 0.55)
    save("switch", mix(tone(700, 0.04, (1, 0.5), 90), at(tone(1050, 0.05, (1,), 80), 0.045, 0.1)), 0.5)
    save("whoosh", lowpass(noise(0.28), 1400) * np.sin(np.pi * t(0.28) / 0.28) ** 2, 0.4)
    save("ping", mix(tone(note(84), 0.5, (1, 0.25), 9), at(tone(note(88), 0.5, (1, 0.25), 9), 0.09, 0.6)), 0.6)
    save("ping_far", lowpass(mix(tone(note(84), 0.5, (1,), 9), at(tone(note(88), 0.5, (1,), 9), 0.09, 0.6)), 700), 0.28)
    save("good", seq([note(72), note(76), note(79)], 0.07, 0.3, harm=(1, 0.3, 0.1), k=10), 0.6)
    save("bad", seq([note(58), note(54)], 0.12, 0.35, harm=(1, 0.6, 0.4, 0.2), k=7), 0.6)
    save("alarm", seq([note(81), note(75), note(81), note(75)], 0.08, 0.14, harm=(1, 0.5, 0.3), k=14), 0.5)
    save("coin", seq([note(88), note(93)], 0.06, 0.4, harm=(1, 0.4), k=9), 0.55)
    save("buy", seq([note(76), note(81), note(88)], 0.05, 0.35, harm=(1, 0.5, 0.2), k=9), 0.55)
    save("payday", seq([note(72), note(76), note(79), note(84), note(88)], 0.085, 0.6, harm=(1, 0.4, 0.15), k=5), 0.6)
    save("login", seq([note(67), note(72), note(76)], 0.09, 0.5, harm=(1, 0.2), k=6), 0.5)
    save("logout", seq([note(76), note(72), note(67)], 0.09, 0.5, harm=(1, 0.2), k=6), 0.45)
    save("join", seq([note(69), note(76)], 0.12, 0.5, harm=(1, 0.3), k=6), 0.55)
    save("leave", seq([note(76), note(69)], 0.12, 0.5, harm=(1, 0.3), k=6), 0.5)
    save("unplug", mix(tone(140, 0.25, (1, 0.5), 14), at(lowpass(noise(0.05), 3000) * decay(int(SR * 0.05), 60), 0.0, 0.25)), 0.6)
    save("plug", mix(at(lowpass(noise(0.04), 3000) * decay(int(SR * 0.04), 70), 0.0, 0.3), at(tone(note(79), 0.25, (1, 0.3), 12), 0.05, 0.3)), 0.55)
    save("sip", highpass(lowpass(noise(0.35), 2600), 700) * np.sin(np.pi * t(0.35) / 0.35) ** 1.5, 0.3)
    # A mumbled syllable for "someone is talking at you".
    d = 0.32
    f = 150 + 45 * np.sin(2 * np.pi * 5.0 * t(d))
    ph = np.cumsum(f) / SR
    voice = sum(a * np.sin(2 * np.pi * ph * h) for h, a in [(1, 1), (2, 0.6), (3, 0.5), (5, 0.25)])
    save("talk", lowpass(voice * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t(d))) * env(len(voice), 0.02, 0.1), 1500), 0.4)
    # Stingers
    save("win", seq([note(60), note(64), note(67), note(72), note(76), note(79), note(84)], 0.11, 1.1, harm=(1, 0.5, 0.25, 0.1), k=2.6), 0.65)
    save("fired", seq([note(57), note(56), note(55), note(48)], 0.3, 1.2, harm=(1, 0.7, 0.5, 0.3, 0.2), k=2.4), 0.65)
    # Call ringing: two-tone trill, loops.
    ring = np.zeros(int(SR * 1.6))
    for i in range(6):
        ring += at(tone(note(81 if i % 2 == 0 else 85), 0.11, (1, 0.4), 12), i * 0.1, 1.6)
    save("ring", ring, 0.55)
    save("ring_loop", ring, 0.5)


# ---------------------------------------------------------------------------
# Loops
# ---------------------------------------------------------------------------

def loops():
    # Keyboard clatter
    d = 2.4
    x = np.zeros(int(SR * d))
    pos = 0.03
    while pos < d - 0.08:
        click = highpass(noise(0.022), 1800) * decay(int(SR * 0.022), 190)
        thock = tone(rng.uniform(170, 260), 0.03, (1,), 130) * 0.6
        x += at(mix(click, thock) * rng.uniform(0.5, 1.0), pos, d)
        pos += rng.choice([0.07, 0.09, 0.11, 0.14, 0.2, 0.32])
    save("typing", x, 0.45)
    # Snoring
    d = 3.2
    tt = t(d)
    breath = lowpass(noise(d), 380) * (0.5 + 0.5 * np.sin(2 * np.pi * 34 * tt))
    shape = np.clip(np.sin(2 * np.pi * tt / d - 0.4), 0, 1) ** 1.5
    save("snore", loopable(breath * shape + lowpass(noise(d), 1400) * np.clip(-np.sin(2 * np.pi * tt / d - 0.4), 0, 1) ** 3 * 0.25), 0.4)
    # TV / game babble: wandering blips over soft noise
    d = 4.0
    x = lowpass(noise(d), 900) * 0.12
    pos = 0.0
    while pos < d - 0.2:
        f = note(rng.choice([60, 62, 64, 67, 69, 72, 74, 76]))
        x += at(tone(f, 0.16, (1, 0.5, 0.3), 14) * 0.5, pos, d)
        pos += rng.choice([0.12, 0.12, 0.24, 0.36])
    save("tv_loop", loopable(x), 0.35)
    # Room tone, day: air + distant birds
    d = 8.0
    air = lowpass(noise(d), 260) * 0.5
    birds = np.zeros(int(SR * d))
    for _ in range(9):
        start = rng.uniform(0.2, d - 0.6)
        f0 = rng.uniform(2600, 3800)
        chirp = sweep(f0, f0 * rng.uniform(1.1, 1.35), 0.09) * env(int(SR * 0.09), 0.01, 0.05)
        for k in range(rng.integers(1, 4)):
            birds += at(chirp * rng.uniform(0.25, 0.6), start + k * 0.13, d)
    save("amb_day", loopable(air + birds * 0.22, 0.4), 0.3)
    # Room tone, night: crickets + fridge hum
    hum = (sine(50, d) * 0.3 + sine(100, d) * 0.12) * 0.5
    tt = t(d)
    crick = sine(4300, d) * (np.sin(2 * np.pi * 27 * tt) > 0.2) * (np.sin(2 * np.pi * 1.7 * tt) > 0.1) * 0.12
    save("amb_night", loopable(lowpass(noise(d), 200) * 0.4 + hum + crick, 0.4), 0.28)


# ---------------------------------------------------------------------------
# Music: two short lo-fi loops
# ---------------------------------------------------------------------------

def keys(f, d):
    """Soft electric-piano-ish voice."""
    x = sine(f, d) + 0.42 * sine(f * 2, d) + 0.14 * sine(f * 3, d) + 0.05 * sine(f * 4.01, d)
    return x * decay(len(x), 2.6) * env(len(x), 0.008, 0.12)


def bass(f, d):
    x = sine(f, d) + 0.35 * sine(f * 2, d)
    return x * decay(len(x), 3.2) * env(len(x), 0.01, 0.08)


def kick():
    return sweep(120, 42, 0.16) * decay(int(SR * 0.16), 22)


def hat(open_=False):
    d = 0.11 if open_ else 0.045
    return highpass(noise(d), 5200) * decay(int(SR * d), 30 if open_ else 80)


def snare():
    return (highpass(noise(0.14), 1500) * 0.7 + tone(190, 0.14, (1,), 30) * 0.5) * decay(int(SR * 0.14), 24)


def song(name, bpm, chords, melody, swing=0.0, peak=0.5):
    beat = 60.0 / bpm
    bars = len(chords)
    total = bars * 4 * beat
    x = np.zeros(int(SR * total))
    for b, (root, tones) in enumerate(chords):
        t0 = b * 4 * beat
        for n in tones:
            x += at(keys(note(n), beat * 3.6) * 0.2, t0, total)
            x += at(keys(note(n), beat * 1.6) * 0.12, t0 + beat * 2.5, total)
        x += at(bass(note(root), beat * 1.4) * 0.5, t0, total)
        x += at(bass(note(root), beat * 0.8) * 0.36, t0 + beat * 2.5, total)
        x += at(bass(note(root + 7), beat * 0.8) * 0.3, t0 + beat * 3.5, total)
        for q in range(4):
            x += at(kick() * 0.55, t0 + q * beat, total) if q in (0, 2) else 0
            x += at(snare() * 0.2, t0 + q * beat, total) if q in (1, 3) else 0
            x += at(hat() * 0.1, t0 + q * beat, total)
            x += at(hat(q == 3) * 0.07, t0 + (q + 0.5 + swing) * beat, total)
    for i, n in enumerate(melody):
        if n:
            x += at(keys(note(n), beat * 0.9) * 0.24, i * beat * 0.5 + (swing * beat if i % 2 else 0), total)
    # Tape-ish warmth: gentle low-pass and a slow wobble.
    x = lowpass(x, 3600)
    x *= 1.0 + 0.02 * np.sin(2 * np.pi * 0.3 * t(total))[: len(x)]
    save(name, x, peak)


def music():
    # Dm9 - G13 - Cmaj9 - A7 : lazy afternoon
    day = [(38, [53, 57, 60, 64]), (43, [53, 57, 59, 64]), (36, [52, 55, 59, 62]), (45, [52, 55, 61, 64])]
    mel = [69, 0, 72, 0, 76, 74, 0, 72, 71, 0, 0, 67, 0, 69, 0, 0,
           67, 0, 71, 0, 74, 72, 0, 71, 73, 0, 76, 0, 0, 73, 0, 0]
    song("music_day", 78, day + day, mel + [m and m for m in mel], swing=0.08, peak=0.5)
    # Fmaj7 - Em7 - Dm7 - G7 : brighter, for the menu
    menu = [(41, [57, 60, 64, 67]), (40, [55, 59, 62, 67]), (38, [57, 60, 65, 69]), (43, [55, 59, 62, 65])]
    mel2 = [72, 76, 79, 0, 76, 0, 72, 0, 71, 74, 79, 0, 74, 0, 71, 0,
            69, 72, 77, 0, 72, 0, 69, 0, 67, 71, 74, 77, 79, 0, 0, 0]
    song("music_menu", 92, menu + menu, mel2 + mel2, swing=0.06, peak=0.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ui()
    loops()
    music()
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".wav"))
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print(f"{len(files)} sounds, {size / 1e6:.1f} MB -> {os.path.normpath(OUT)}")
