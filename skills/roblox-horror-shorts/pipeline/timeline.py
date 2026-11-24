"""ONE timeline for picture AND sound. Copy into projects/<slug>/ and run it there:  python timeline.py
timings.json (voice.py) -> shots.json, final/narration.mp3, events.json

Every shot = lead + its spoken line + gap (+ EXTRA silence for on-screen beats like knocks and flashes).
events.json lists every synced beat as a FRAME on the full timeline (frame = round(t*30)+1). scene.py keys its
visual on that frame; assemble.py plays the sound at (frame-1)/30. Neither side times anything on its own.
"""
import json, os, sys
from pathlib import Path

sys.path.insert(0, os.environ.get("SHORTS_PIPELINE", str(Path(__file__).resolve().parent)))  # pipeline/ folder (finish.py)
import finish as F  # noqa: E402
from finish import words_with_times  # noqa: E402

HERE = Path(__file__).resolve().parent
FPS, LEAD, GAP, MIN_SHOT, PAD = 30, 0.08, 0.06, 1.0, 0.03  # tight pauses: ~0.15 s between lines
# line number (1-based): extra seconds of silence after the line, for beats the voice doesn't cover
EXTRA = {}  # e.g. {11: 0.2, 24: 0.3}
LIMIT = 119.0  # stay under 2:00 (YouTube Shorts)
CUT_IN = 0.0


def frame(t):
    return round(t * FPS) + 1


def layout():
    lines = json.loads((HERE / "timings.json").read_text())
    shots, t = [], 0.0
    for k, (a, b) in enumerate(lines):
        last = k == len(lines) - 1
        dur = (b - a) + LEAD + 1.8 if last else max(MIN_SHOT, (b - a) + LEAD + GAP + EXTRA.get(k + 1, 0))
        shots.append({"start": round(t, 3), "end": round(t + dur, 3), "say": [a, b], "lead": LEAD, "line": k + 1})
        t += dur
    assert t <= LIMIT, f"{t:.1f}s is over the {LIMIT}s limit"
    (HERE / "shots.json").write_text(json.dumps(shots, indent=1))
    fin = HERE / "final"
    fin.mkdir(exist_ok=True)
    ins, mix = [], []
    for k, s in enumerate(shots):  # same voice laying as finish_sample.plan (fades stop clicks at the cuts)
        a, b = s["say"]
        pre = min(PAD, a)
        ms = int((s["start"] + LEAD - pre) * 1000)
        dur = b - a + pre + 0.05
        ins += ["-ss", str(a - pre), "-t", str(dur), "-i", HERE / "narration.mp3"]
        mix.append(f"[{k}:a]afade=t=in:d=0.01,afade=t=out:st={dur - 0.03:.3f}:d=0.03,adelay={ms}|{ms}[l{k}]")
    graph = ";".join(mix) + ";" + "".join(f"[l{k}]" for k in range(len(shots))) + f"amix=inputs={len(shots)}:normalize=0"
    F.run([F.FF, "-y", *ins, "-filter_complex", graph, "-t", str(t), "-codec:a", "libmp3lame", "-qscale:a", "2",
           fin / "narration.mp3"])
    return shots


def word_times(shots):
    """{line: [(word, t_full)]} on the full timeline.
    Whisper word times can drift by seconds mid-track, so each word's time is the proportional estimate inside its
    line's spoken span, replaced by Whisper's time only when the two agree within 0.3 s."""
    lines = [l.strip() for l in (HERE / "script.txt").read_text().splitlines() if l.strip()]
    heard = {}
    for t, w, ln in words_with_times(HERE):
        heard.setdefault(ln, []).append(t)
    out = {}
    for ln, text in enumerate(lines):
        a, b = shots[ln]["say"]
        ws = text.split()
        wts = [max(1, len(x.strip("*\",.?!:;"))) for x in ws]
        tot, acc, est = float(sum(wts)), 0.0, []
        for n in wts:
            est.append(a + (b - a) * acc / tot); acc += n
        ht = heard.get(ln, [])
        res = []
        for i, w in enumerate(ws):
            t = ht[i] if len(ht) == len(ws) and abs(ht[i] - est[i]) < 0.3 else est[i]
            res.append((w.strip("*\",.?!:;").lower(), round(shots[ln]["start"] + LEAD + (t - a), 3)))
        out[ln + 1] = res
    return out


def events(shots, words):
    """Every synced beat: (id, time, sound or None, gain). Times come ONLY from words / line ends."""
    def w(line, word, n=1, off=0.0):  # n-th occurrence of `word` in that line (falls back to the line's speech end)
        hits = [t for x, t in words.get(line, []) if x == word]
        if len(hits) < n:
            print(f"  ! word '{word}' not heard in line {line}; using line end")
            return end(line, off)
        return hits[n - 1] + off

    def end(line, off=0.0):  # end of the line's speech
        s = shots[line - 1]
        return s["start"] + LEAD + (s["say"][1] - s["say"][0]) + off

    def start(line, off=0.0):
        return shots[line - 1]["start"] + off

    ev = [  # (id, time, sound or None, gain). Sounds: assemble.py NEW_SFX keys, or None for a picture-only cue.
        ("intro_drop", 0.0, "drop", 0.35),
        # ("door_creak", w(1, "door"), "creak", 0.35),     # the word "door" in line 1
        # ("scare_boom", start(12, 0.05), "boom", 0.4),    # 0.05 s into line 12's shot
        # ("heart_on", start(20), None, 0), ("heart_off", end(24), None, 0),   # assemble.py plays a heartbeat between them
        ("end_swell", shots[-1]["end"] - 1.6, "endswell", 0.3),
    ]
    out = [dict(id=i, frame=frame(t), sound=snd, gain=g) for i, t, snd, g in ev]
    out.sort(key=lambda e: e["frame"])
    return out


if __name__ == "__main__":
    shots = layout()
    words = word_times(shots)
    (HERE / "shots.json").write_text(json.dumps(shots, indent=1))
    ev = events(shots, words)
    (HERE / "events.json").write_text(json.dumps(ev, indent=1))
    (HERE / "words_full.json").write_text(json.dumps(words, indent=1))
    last = round(shots[-1]["end"] * FPS)
    print(f"{len(shots)} shots, {shots[-1]['end']:.2f}s = {last} frames, {len(ev)} events")
