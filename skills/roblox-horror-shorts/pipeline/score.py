"""Original background score, synthesized from scratch with numpy: nothing to copyright-claim.
Copy into projects/<slug>/ and run it there after timeline.py:  python score.py  -> final/score.wav + final/score.mp3
The instruments and the music-box tune below are reusable. The ARRANGEMENT at the bottom is a generic default that works for
any timeline (tune at the start, a pad, a hit on every loud event, silence before the scare). Rewrite it per video for a better
fit: a happy tune while things are fine, the same tune flat/wobbly once they are not, silence just before each scare.
"""
import json
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
SR = 44100
SHOTS = json.loads((HERE / "shots.json").read_text())
EV = {e["id"]: (e["frame"] - 1) / 30 for e in json.loads((HERE / "events.json").read_text())}
END = round(SHOTS[-1]["end"] * 30) / 30
N = int(END * SR)
rng = np.random.default_rng(7)


def line(n):  # start of a script line's shot (s)
    return SHOTS[n - 1]["start"]


def hz(note):  # "D5", "C#4", "Bb3" -> Hz
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    s = names[note[0]] + (1 if "#" in note else -1 if "b" in note[1:-1] else 0)
    return 440.0 * 2 ** ((s + 12 * (int(note[-1]) + 1) - 69) / 12)


def add(bus, t0, sig):
    i = int(t0 * SR)
    if i >= N:
        return
    sig = sig[: N - i]
    bus[i:i + len(sig)] += sig


def bell(f, amp=0.25, dur=2.6, detune=0.0):
    """Music box tine: bright attack, inharmonic partials, long ring."""
    t = np.arange(int(dur * SR)) / SR
    f = f * (1 + detune)
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t * 2.2)
         + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 5)
         + 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 9)
         + 0.08 * np.sin(2 * np.pi * f * 8.9 * t) * np.exp(-t * 16))
    return amp * x * np.minimum(t / 0.003, 1)


def piano(f, amp=0.4, dur=4.0):
    """Soft low piano-ish note for hits."""
    t = np.arange(int(dur * SR)) / SR
    x = sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * (0.9 + 0.8 * k)) / k for k in range(1, 6))
    return amp * x * np.minimum(t / 0.006, 1)


def pad(notes, dur, amp=0.08, att=2.0, rel=2.0):
    """Slow string-like pad: detuned sines + a little 2nd/3rd harmonic, breathing LFO."""
    t = np.arange(int(dur * SR)) / SR
    x = np.zeros_like(t)
    for n in notes:
        f = hz(n)
        for d in (-0.004, 0.0, 0.0043):
            ph = rng.uniform(0, 6.28)
            x += np.sin(2 * np.pi * f * (1 + d) * t + ph) + 0.25 * np.sin(4 * np.pi * f * (1 + d) * t + ph) + 0.08 * np.sin(6 * np.pi * f * (1 + d) * t)
    x *= (1 + 0.15 * np.sin(2 * np.pi * 0.17 * t)) / (3 * len(notes))
    env = np.minimum(1, t / att) * np.minimum(1, (dur - t) / rel)
    return amp * x * np.clip(env, 0, 1)


def thump(amp=0.35):
    """Low heartbeat-like pulse (D2 + sub), audible on phone speakers through its 2nd harmonic."""
    t = np.arange(int(0.6 * SR)) / SR
    f = 73.4 * (1 + 0.6 * np.exp(-t * 40))
    return amp * (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * np.exp(-t * 9) * np.minimum(t / 0.004, 1)


def tension(dur, amp=0.05):
    """Two high tones a semitone apart (E6/F6): beating dread, fades in over the whole span."""
    t = np.arange(int(dur * SR)) / SR
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * 5.5 * t)
    x = (np.sin(2 * np.pi * hz("E6") * t) + np.sin(2 * np.pi * hz("F6") * t)) * trem
    return amp * x * (t / dur) ** 1.5 * np.minimum(1, (dur - t) / 0.08)


def motif(bus, t0, notes, beat=0.5, amp=0.22, detune=0.0):
    for k, (n, b) in enumerate(notes):
        dt = detune * (1 if k % 2 else -1)
        add(bus, t0 + b * beat, bell(hz(n), amp, detune=dt))


def reverb(x, secs=2.8, wet=0.35):
    t = np.arange(int(secs * SR)) / SR
    ir = rng.standard_normal(len(t)) * np.exp(-t / 0.7)
    ir = np.convolve(ir, np.ones(24) / 24, mode="same")  # darker tail
    ir /= np.sqrt(np.sum(ir ** 2))
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x)]
    return (1 - wet) * x + wet * y * 0.6


def cut(env, a, b, fade=0.05):
    """Silence env between a and b with short fades (a hard horror cut, not a drift)."""
    i, j, f = int(a * SR), int(b * SR), int(fade * SR)
    env[i:j] = 0
    env[max(0, i - f):i] *= np.linspace(1, 0, i - max(0, i - f))
    env[j:j + f] *= np.linspace(0, 1, len(env[j:j + f]))



def ev(i, default=None):
    return EV.get(i, default if default is not None else 0.0)


def bell_w(f, amp=0.2, dur=1.6, wob=0.0, rate=5.0):
    """Music-box tine with a pitch wobble (wob = fraction, e.g. 0.02): the sour, drunk version of the tune."""
    t = np.arange(int(dur * SR)) / SR
    ph = 2 * np.pi * np.cumsum(f * (1 + wob * np.sin(2 * np.pi * rate * t))) / SR
    x = (np.sin(ph) * np.exp(-t * 2.4) + 0.35 * np.sin(ph * 2.76) * np.exp(-t * 6) + 0.15 * np.sin(ph * 5.4) * np.exp(-t * 11))
    return amp * x * np.minimum(t / 0.003, 1)


def pluck(f, amp=0.2, dur=0.5):
    t = np.arange(int(dur * SR)) / SR
    x = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t)) * np.exp(-t * 9)
    return amp * x * np.minimum(t / 0.004, 1)


# THE TUNE (original, A minor): (note, beat). Two phrases.
J1 = [("A5", 0), ("E5", 1), ("A5", 2), ("B5", 3), ("C6", 4), ("B5", 5), ("A5", 6), ("E5", 8), ("G5", 9), ("F5", 10), ("D5", 11)]
J2 = [("E5", 0), ("A5", 1), ("C6", 2), ("E6", 3), ("D6", 4), ("B5", 5), ("C6", 6), ("B5", 7), ("G#5", 8), ("A5", 9)]


def jingle(bus, t0, t1, beat=0.34, amp=0.2, detune=0.0, wob=0.0, dur=1.5):
    """Loop the tune from t0 until t1; detune = pitch offset (-0.06 = nearly a semitone flat), wob = vibrato depth."""
    t = t0
    while t < t1 - beat:
        for ph in (J1, J2):
            for n, b in ph:
                if t + b * beat >= t1:
                    return
                f = hz(n) * (1 + detune)
                add(bus, t + b * beat, bell_w(f, amp, dur, wob) if wob else bell(f, amp, dur))
            t += (ph[-1][1] + 3) * beat


def sleigh(bus, t0, t1, gap=0.34, amp=0.05):
    """Sleigh bells: short bright metallic shakes on the beat, the off-beat softer."""
    k, t = 0, t0
    while t < t1:
        tt = np.arange(int(0.22 * SR)) / SR
        x = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) for f in (3520, 4435, 5274, 6645)) / 4
        x = (x + 0.5 * rng.standard_normal(len(tt))) * np.exp(-tt * 22) * np.minimum(tt / 0.002, 1)
        add(bus, t, amp * (1.0 if k % 2 == 0 else 0.5) * x); t += gap; k += 1


def lowpass(x, secs=0.0004):
    k = max(1, int(SR * secs))
    return np.convolve(x, np.ones(k) / k, mode="same")




def organ(f, amp=0.12, dur=0.5, wob=0.0):
    """Calliope pipe: hollow odd harmonics, a breathy start, a little wobble."""
    t = np.arange(int(dur * SR)) / SR
    ph = 2 * np.pi * np.cumsum(f * (1 + (0.004 + wob) * np.sin(2 * np.pi * 5.6 * t))) / SR
    x = np.sin(ph) + 0.32 * np.sin(3 * ph) + 0.12 * np.sin(5 * ph) + 0.18 * np.sin(2 * ph)
    env = np.minimum(1, t / 0.025) * np.minimum(1, (dur - t) / 0.09)
    return amp * (x + 0.05 * rng.standard_normal(len(t)) * np.exp(-t * 30)) * np.clip(env, 0, 1)


def ticks(t0, t1, gap=0.5, amp=0.1):
    k, t = 0, t0
    while t < t1:
        add(dry, t, pluck(hz("A5" if k % 2 == 0 else "E5"), amp, 0.25)); t += gap; k += 1



bus = np.zeros(N)   # reverbed music
dry = np.zeros(N)   # hits and drones that must stay tight
env = np.ones(N)

# ---------------------------------------------------------------- ARRANGEMENT (generic default: rewrite per video)
EVS = json.loads((HERE / "events.json").read_text())
HITS = {"boom", "bang", "stinger", "thunder", "bolt"}           # loud event sounds that get a low piano hit
scare = max((e for e in EVS if e["sound"] in HITS), key=lambda e: e["gain"], default=None)
mid = END * 0.45
add(dry, ev("intro_drop"), piano(hz("C2"), 0.28, 3.0))
jingle(bus, 0.05, mid, 0.32, 0.09)                               # the tune, plain
add(bus, 0.0, pad(["A2", "E3", "C4"], mid + 0.4, 0.05, att=1.0))
add(bus, mid, pad(["F2", "C3", "Ab3"], END - mid, 0.065, att=0.8, rel=2.0))
jingle(bus, mid + 0.2, END - 1.2, 0.46, 0.07, detune=-0.04, wob=0.014)   # the same tune, sour
ticks(END * 0.7, END - 2.0, 0.34, 0.06)                          # dread rising to the end
add(bus, END * 0.7, tension(END * 0.3 - 1.0, 0.035))
for e in EVS:
    if e["sound"] in HITS:
        add(dry, (e["frame"] - 1) / 30, piano(hz("C1" if e is scare else "Ab1"), 0.3 + 0.3 * min(e["gain"], 0.5), 2.5))
if scare:                                                        # a hard silence right before the biggest hit
    t = (scare["frame"] - 1) / 30
    cut(env, max(0, t - 0.45), t, fade=0.02)

mix = reverb(bus) * env + dry * np.where(env > 0, 1, 0.0)
mix[-int(0.004 * SR):] *= np.linspace(1, 0, int(0.004 * SR))
mix *= 10 ** (-1.0 / 20) / np.max(np.abs(mix))
st = np.stack([mix, np.roll(mix, int(0.011 * SR))], 1)
out = HERE / "final" / "score.wav"
out.parent.mkdir(exist_ok=True)
sf.write(out, st.astype(np.float32), SR, subtype="PCM_24")
import subprocess  # noqa: E402
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(out), "-b:a", "320k", str(out.with_suffix(".mp3"))], check=True)
print(f"{out}  {END:.2f}s")
