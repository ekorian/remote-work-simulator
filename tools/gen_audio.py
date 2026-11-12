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


def save(name, x, peak=0.8, sr=SR):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
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
    # The boss has his own notification: lower, and one note too many.
    save("boss", seq([note(67), note(72), note(67), note(60)], 0.085, 0.42, harm=(1, 0.5, 0.3, 0.1), k=8), 0.6)
    # Gadgets: a cheerful power-up, and a sad mechanical wind-down.
    save("gadget_on", mix(sweep(260, 880, 0.18) * env(int(SR * 0.18), 0.005, 0.08), at(tone(note(88), 0.3, (1, 0.4), 10), 0.16, 0.5)), 0.5)
    down = sweep(620, 70, 0.55) * env(int(SR * 0.55), 0.005, 0.25) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 34 * t(0.55))))
    save("gadget_fail", mix(down, at(lowpass(noise(0.12), 2500) * decay(int(SR * 0.12), 30), 0.5, 0.7)), 0.55)
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

# ---------------------------------------------------------------------------
# Voices: gibberish speech for calls, one timbre per character
# ---------------------------------------------------------------------------
# Nobody says a word of English. Each voice is a buzzing source pushed
# through vowel formants, syllable by syllable, with its own pitch, pace and
# melody; the strange callers then get wrecked by effects. Voices use their
# own random streams, so adding one never changes any other sound.

VOICE_SR = SR // 2          # calls are phone quality
VOWELS = {
    "a": (730, 1090, 2440), "e": (530, 1840, 2480), "i": (270, 2290, 3010),
    "o": (570, 840, 2410), "u": (300, 870, 2240), "y": (440, 1500, 2500),
}
CONSONANTS = ["", "", "m", "n", "b", "d", "k", "t", "s", "l", "w"]


def spectral(x, shape):
    """Filter x by multiplying its spectrum with shape(frequencies)."""
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * shape(f), len(x))


def band(x, lo, hi, order=3):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (lo / np.maximum(f, 1.0)) ** (2 * order)) / np.sqrt(1 + (f / hi) ** (2 * order)))


def norm(x):
    return x / (np.max(np.abs(x)) or 1.0)


def vowel_shape(formants, tract=1.0, nasal=0.0):
    def shape(f):
        h = np.full_like(f, 0.012)
        for fc, bw, g in zip(formants, (75, 95, 140), (1.0, 0.55, 0.32)):
            h += g / (1 + ((f - fc * tract) / bw) ** 2)
        if nasal:
            h += nasal / (1 + ((f - 1050 * tract) / 70) ** 2)
            h *= 1 - 0.7 * nasal / (1 + ((f - 600 * tract) / 110) ** 2)
        return h / (1 + (f / 4300) ** 4)
    return shape


def syllable(r, v, f_from, f_to, dur, vowels):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    f0 = np.linspace(f_from, f_to, n)
    f0 = f0 * (1 + v.get("vib", 0.0) * np.sin(2 * np.pi * v.get("vib_hz", 5.5) * tt + r.uniform(0, 6.28)))
    f0 = f0 * (1 + v.get("jitter", 0.012) * np.cumsum(r.normal(0, 1, n)) / np.sqrt(n))
    ph = np.cumsum(f0) / SR
    src = 2 * (ph % 1.0) - 1.0                                  # sawtooth: a glottal buzz
    src = src + v.get("breath", 0.06) * r.uniform(-1, 1, n) * 2.0
    out = norm(spectral(src, vowel_shape(VOWELS[vowels[0]], v.get("tract", 1.0), v.get("nasal", 0.0))))
    if len(vowels) > 1:
        other = norm(spectral(src, vowel_shape(VOWELS[vowels[1]], v.get("tract", 1.0), v.get("nasal", 0.0))))
        w = np.clip((tt / dur - 0.3) / 0.4, 0, 1)
        out = out * (1 - w) + other * w
    if v.get("trem", 0.0):
        out = out * (1 - v["trem"] * (0.5 + 0.5 * np.sin(2 * np.pi * v.get("trem_hz", 7.0) * tt)))
    return out * env(n, min(0.03, dur * 0.2), min(0.08, dur * 0.45))


def consonant(r, kind, f0):
    if kind == "":
        return np.zeros(0)
    if kind == "s":
        d = 0.055
        return band(r.uniform(-1, 1, int(SR * d)), 3200, 5200) * env(int(SR * d), 0.01, 0.02) * 0.9
    if kind in "kt":
        d = 0.022
        return band(r.uniform(-1, 1, int(SR * d)), 1500 if kind == "k" else 2600, 4500) * decay(int(SR * d), 160) * 1.6
    if kind in "bd":
        d = 0.03
        return np.sin(2 * np.pi * (110 if kind == "b" else 190) * t(d)) * decay(int(SR * d), 120) * 0.7
    d = 0.05                                                    # m n l w: a short hum
    hum = np.sin(2 * np.pi * f0 * t(d)) + 0.4 * np.sin(2 * np.pi * f0 * 2 * t(d))
    return hum * env(int(SR * d), 0.01, 0.015) * 0.35


def babble(seed, v, count, question=False):
    """One spoken phrase of `count` syllables in voice v."""
    r = np.random.default_rng(seed)
    parts = []
    base, span = v["f0"], v.get("range", 0.22)
    word = int(r.integers(1, 4))
    for i in range(count):
        last = i == count - 1
        decl = 1.0 - v.get("fall", 0.12) * i / max(1, count - 1)
        if v.get("mono"):
            start = base * (1.0 if r.random() < 0.75 else v["mono"])        # robots know two notes
            end = start
        else:
            start = base * decl * (1 + span * r.uniform(-0.45, 0.6))
            end = start * (1 + span * r.uniform(-0.4, 0.3))
            if last:
                end = start * (1.3 if question else 0.76)
        dur = v["syl"] * (1.0 if v.get("mono") else r.uniform(0.75, 1.3)) * (1.4 if last else 1.0)
        vs = [str(r.choice(list(VOWELS)))]
        if r.random() < v.get("diph", 0.3):
            vs.append(str(r.choice(list(VOWELS))))
        parts.append(consonant(r, str(r.choice(CONSONANTS)), start) * v.get("cons", 1.0))
        parts.append(syllable(r, v, start, end, dur, vs))
        word -= 1
        if word <= 0 and not last:
            parts.append(np.zeros(int(SR * v.get("gap", 0.05) * r.uniform(0.6, 1.8))))
            word = int(r.integers(1, 4))
    return np.concatenate(parts)


# --- effects ----------------------------------------------------------------

def ringmod(x, f, depth=1.0):
    return x * ((1 - depth) + depth * np.sin(2 * np.pi * f * np.arange(len(x)) / SR))


def crush(x, bits=5, hold=4):
    y = np.repeat(norm(x)[::hold], hold)[: len(x)]
    q = 2 ** (bits - 1)
    return np.round(y * q) / q


def drive(x, gain):
    return np.tanh(norm(x) * gain)


def echo(x, taps):
    out = np.zeros(len(x) + int(SR * max(d for d, _ in taps)))
    out[: len(x)] += x
    for d, g in taps:
        i = int(SR * d)
        out[i : i + len(x)] += x * g
    return out


def resample(x, rate):
    """rate > 1 plays faster and higher."""
    return np.interp(np.arange(0, len(x) - 1, rate), np.arange(len(x)), x)


def wow(x, hz, depth):
    """Tape wow: the pitch drifts up and down."""
    n = np.arange(len(x))
    idx = n + depth * SR / (2 * np.pi * hz) * np.sin(2 * np.pi * hz * n / SR)
    return np.interp(np.clip(idx, 0, len(x) - 1), n, x)


def stutter(r, x):
    """Chop into slices; repeat, reverse, drop and re-pitch them at random."""
    out, i = [], 0
    while i < len(x):
        n = int(SR * r.uniform(0.04, 0.13))
        piece = x[i : i + n]
        i += n
        roll = r.random()
        if roll < 0.22:
            out.extend([piece[: max(1, len(piece) // 2)]] * int(r.integers(3, 6)))     # d-d-d-digital
        elif roll < 0.34:
            out.append(piece[::-1])
        elif roll < 0.44:
            out.append(np.zeros(len(piece)))
        elif roll < 0.58:
            out.append(resample(piece, float(r.choice([0.5, 0.75, 1.5, 2.0]))))
        else:
            out.append(piece)
    return np.concatenate(out)


def dropouts(r, x, every=0.42, garble=0.5):
    """A bad line: chunks vanish, some come back as digital mush."""
    x = x.copy()
    pos = int(SR * r.uniform(0.1, every))
    while pos < len(x):
        n = min(int(SR * r.uniform(0.05, 0.17)), len(x) - pos)
        if r.random() < garble:
            x[pos : pos + n] = crush(x[pos : pos + n] + 0.3 * r.uniform(-1, 1, n), 3, 9) * 0.5
        else:
            x[pos : pos + n] = 0.0
        pos += n + int(SR * r.uniform(0.15, every))
    return x


def wind(r, n, amount):
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(0.3, 0.7) * np.arange(n) / SR + r.uniform(0, 6))
    return band(r.uniform(-1, 1, n), 60, 500, 2) * gust * amount


def fax(seed):
    """A fax machine trying to shake hands with a human."""
    r = np.random.default_rng(seed)
    parts = []
    for _ in range(int(r.integers(1, 3))):
        parts += [np.sin(2 * np.pi * 1100 * t(0.22)) * env(int(SR * 0.22), 0.005, 0.01), np.zeros(int(SR * 0.12))]
    parts.append(np.sin(2 * np.pi * 2100 * t(0.35)) * env(int(SR * 0.35), 0.005, 0.01))
    bits = r.integers(0, 2, int(r.integers(40, 70)))                          # FSK warble
    parts.append(np.concatenate([np.sin(2 * np.pi * (1650 if b else 1850) * t(0.011)) for b in bits]))
    d = float(r.uniform(0.35, 0.6))
    scream = band(r.uniform(-1, 1, int(SR * d)), 900, 3200) * 0.6 + 0.5 * sweep(float(r.uniform(900, 1400)), float(r.uniform(2400, 3300)), d)[: int(SR * d)]
    parts.append(scream * env(len(scream), 0.01, 0.03))
    parts.append(np.concatenate([np.sin(2 * np.pi * f * t(0.045)) for f in r.choice([980, 1180, 1650, 1850, 2225], 9)]))
    return drive(np.concatenate(parts), 2.2)


VOICES = {
    # --- people ---
    "martin": {"f0": 118, "syl": 0.135, "range": 0.34, "gap": 0.07, "tract": 0.97},
    "priya": {"f0": 208, "syl": 0.1, "range": 0.26, "gap": 0.035, "tract": 1.12},
    "kevin": {"f0": 156, "syl": 0.105, "range": 0.4, "gap": 0.04, "tract": 1.04, "nasal": 0.8, "fall": -0.1},
    "dave": {"f0": 96, "syl": 0.165, "range": 0.16, "gap": 0.11, "tract": 0.93, "breath": 0.16},
    "linda": {"f0": 192, "syl": 0.14, "range": 0.1, "gap": 0.09, "tract": 1.1, "fall": 0.05},
    "it": {"f0": 124, "syl": 0.15, "range": 0.05, "gap": 0.1, "tract": 1.0, "breath": 0.1, "fall": 0.2},
    "helena": {"f0": 172, "syl": 0.16, "range": 0.14, "gap": 0.14, "tract": 1.06, "cons": 1.5},
    "brenda": {"f0": 236, "syl": 0.085, "range": 0.36, "gap": 0.025, "tract": 1.15, "diph": 0.5},
    # --- the strange ones ---
    "gerald": {"f0": 61, "syl": 0.3, "range": 0.1, "gap": 0.42, "tract": 0.8, "breath": 0.12, "fall": 0.2, "count": (4, 6), "band": (55, 3000)},
    "robot": {"f0": 112, "syl": 0.13, "mono": 1.26, "gap": 0.075, "tract": 1.0, "breath": 0.0, "jitter": 0.0, "diph": 0.0, "count": (8, 11)},
    "nana": {"f0": 292, "syl": 0.21, "range": 0.3, "gap": 0.1, "tract": 1.2, "vib": 0.07, "vib_hz": 6.5, "trem": 0.5, "breath": 0.18, "count": (6, 8)},
    "changer": {"f0": 82, "syl": 0.17, "range": 0.08, "gap": 0.12, "tract": 0.84, "count": (6, 9), "band": (50, 3200)},
    "glitch": {"f0": 142, "syl": 0.12, "range": 0.28, "gap": 0.05, "tract": 1.0},
    "muffled": {"f0": 118, "syl": 0.135, "range": 0.34, "gap": 0.08, "tract": 0.97},
    "choppy": {"f0": 96, "syl": 0.15, "range": 0.3, "gap": 0.07, "tract": 0.93, "breath": 0.16},
}


def wreck(name, x, r):
    """What the line (or the caller) does to the voice."""
    if name == "gerald":            # a sub-basement, a mains hum, a tape that has seen things
        x = wow(x, 0.7, 0.035)
        x = echo(x, [(0.11, 0.55), (0.23, 0.4), (0.37, 0.28), (0.53, 0.18)])
        return norm(x) + 0.05 * (sine(50, len(x) / SR)[: len(x)] + 0.5 * sine(100, len(x) / SR)[: len(x)])
    if name == "robot":
        return crush(ringmod(x, 58, 0.55), 5, 3)
    if name == "nana":
        return wow(x, 2.3, 0.05)
    if name == "changer":           # a cheap voice changer, held too close
        low = resample(x, 0.5)[: len(x)]
        y = norm(x) * 0.6
        y[: len(low)] += norm(low) * 0.8
        return drive(ringmod(y, 31, 0.8), 3.0)
    if name == "glitch":
        return crush(stutter(r, x), 6, 2)
    if name == "muffled":           # a phone in a pocket
        y = spectral(x, lambda f: 1 / (1 + (f / 420) ** 4))
        rustle = band(r.uniform(-1, 1, len(y)), 500, 2500, 2) * (np.abs(np.sin(2 * np.pi * 1.3 * np.arange(len(y)) / SR + r.uniform(0, 6))) ** 6)
        thump = np.zeros(len(y))
        for _ in range(int(r.integers(1, 4))):
            thump += at(tone(float(r.uniform(55, 80)), 0.12, (1,), 40), float(r.uniform(0, max(0.1, len(y) / SR - 0.2))), len(y) / SR)[: len(y)]
        return norm(y) + 0.3 * rustle + 0.5 * thump
    if name == "choppy":            # one bar of signal and a breeze
        y = dropouts(r, norm(x)) + wind(r, len(x), 0.5)
        thwack = at(band(r.uniform(-1, 1, int(SR * 0.05)), 900, 4200) * decay(int(SR * 0.05), 70), float(r.uniform(0.2, max(0.3, len(y) / SR - 0.3))), len(y) / SR)[: len(y)]
        return y + 1.2 * thwack
    return x


def voices():
    count = 0
    for i, name in enumerate(VOICES):
        v = VOICES[name]
        lo, hi = v.get("count", (8, 12))
        for k in range(3):
            r = np.random.default_rng(9000 + i * 10 + k)
            x = babble(4000 + i * 10 + k, v, int(r.integers(lo, hi + 1)), question=(k == 2))
            lo_hz, hi_hz = v.get("band", (260, 3500))             # a phone line, unless the bass is the point
            x = band(norm(wreck(name, x, r)), lo_hz, hi_hz)
            save("voice_%s_%d" % (name, k + 1), x[::2], 0.6, VOICE_SR)
            count += 1
    for k in range(3):
        save("voice_fax_%d" % (k + 1), band(fax(700 + k), 300, 3600)[::2], 0.42, VOICE_SR)
        count += 1
    # Ringtones: a friendly two-note for colleagues, and one that is clearly wrong.
    peer = np.zeros(int(SR * 1.8))
    for i, n_ in enumerate([76, 79, 76, 79]):
        peer += at(tone(note(n_), 0.22, (1, 0.3, 0.1), 9), 0.05 + i * 0.16, 1.8)
    save("ring_peer", peer, 0.5)
    weird = np.zeros(int(SR * 1.8))
    for i in range(6):
        weird += at(tone(note(81 if i % 2 == 0 else 85) * (0.94 + 0.02 * i), 0.13, (1, 0.6, 0.5, 0.3), 10), i * 0.115, 1.8)
    save("ring_weird", crush(wow(weird, 3.1, 0.06), 5, 3), 0.45)
    return count


# ---------------------------------------------------------------------------
# Hands and feet: footsteps, picking things up, eating them
# ---------------------------------------------------------------------------

def props():
    r = np.random.default_rng(4242)          # its own stream: nothing else changes

    def hiss(d):
        return r.uniform(-1, 1, int(SR * d))

    # A sock on a wooden floor.
    step = mix(band(hiss(0.09), 90, 900, 2) * decay(int(SR * 0.09), 38), 0.5 * tone(82, 0.09, (1,), 46))
    save("step", step, 0.5)
    # Three crunches.
    bite = np.zeros(int(SR * 0.34))
    for i, start in enumerate([0.0, 0.1, 0.19]):
        crunch = band(hiss(0.07), 900 + 300 * i, 4800, 2) * decay(int(SR * 0.07), 55)
        bite += at(crunch * (1.0 - 0.2 * i), start, 0.34)
    save("bite", bite, 0.5)
    # Two swallows.
    gulp = mix(sweep(360, 190, 0.09) * env(int(SR * 0.09), 0.005, 0.04), at(sweep(330, 170, 0.1) * env(int(SR * 0.1), 0.005, 0.05), 0.15, 0.3))
    save("gulp", lowpass(gulp, 1400), 0.5)
    save("pickup", sweep(300, 760, 0.07) * env(int(SR * 0.07), 0.004, 0.04), 0.4)
    putdown = mix(band(hiss(0.06), 80, 700, 2) * decay(int(SR * 0.06), 60), 0.7 * tone(110, 0.08, (1, 0.3), 50))
    save("putdown", putdown, 0.45)
    # A rubber duck with opinions.
    d = 0.26
    tt = t(d)
    f = 950 + 700 * np.sin(np.pi * tt / d) ** 0.6 + 40 * np.sin(2 * np.pi * 38 * tt)
    squeak = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.35 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    save("squeak", squeak * env(len(squeak), 0.01, 0.06), 0.42)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ui()
    loops()
    music()
    voices()
    props()
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".wav"))
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print(f"{len(files)} sounds, {size / 1e6:.1f} MB -> {os.path.normpath(OUT)}")
