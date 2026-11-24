"""Motion QA. Run with python3:
    motion_qa.py <video.mp4> [<video.mp4> ...]
Measured on 3 top Roblox story Shorts: 0-1% frozen frames, in-shot motion 4.5-6.1. A weak early take: 29% frozen, motion 2.5.
FAILS when frozen frames > 8% or in-shot motion < 3.5; lists the longest frozen stretches so the matching beats get a move/walk/action.
"""
import os, subprocess, sys
import numpy as np

FF = os.environ.get("FFMPEG", "ffmpeg")
FPS, W, H = 15, 72, 128
CUT, STILL = 25, 0.6  # mean abs grey change per frame: above CUT = a hard cut, below STILL = a frozen frame


def measure(path):
    raw = subprocess.run([FF, "-v", "error", "-i", path, "-vf", f"fps={FPS},scale={W}:{H},format=gray", "-f", "rawvideo", "-"],
                         capture_output=True, check=True).stdout
    v = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
    d = np.abs(np.diff(v, axis=0)).mean(axis=(1, 2))
    inside = d[d <= CUT]
    still = d < STILL
    runs, start = [], None  # frozen stretches >= 0.5 s: (start s, length s)
    for i, s in enumerate(np.r_[still, False]):
        if s and start is None: start = i
        elif not s and start is not None:
            if i - start >= FPS // 2: runs.append((start / FPS, (i - start) / FPS))
            start = None
    return float(np.mean(inside < STILL)), float(inside.mean()), sorted(runs, key=lambda r: -r[1])


if __name__ == "__main__":
    bad = False
    for f in sys.argv[1:]:
        frozen, motion, runs = measure(f)
        ok = frozen <= 0.08 and motion >= 3.5
        bad |= not ok
        print(f"{'PASS' if ok else 'FAIL'} {f}: frozen {frozen*100:.0f}% (max 8), motion {motion:.2f} (min 3.5)")
        for t, n in runs[:10]:
            print(f"   frozen {n:.1f}s at {int(t//60)}:{t%60:04.1f}")
    sys.exit(1 if bad else 0)
