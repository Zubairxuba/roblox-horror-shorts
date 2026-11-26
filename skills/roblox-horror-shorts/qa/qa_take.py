"""Measured QA for a recorded take. Run in the project folder:

    python3 qa_take.py <take_or_video.mp4> <camlog.txt>

camlog.txt = the camera log. DirectorCam v2 writes one [CAMQA] line per shot to qa/camlog.txt automatically, via the
bridge; the Studio output window can also be pasted. Old-format lines (nx/ny/head/body/blocked) are still read.

FAILS (the camera auto-fixes these at plan time, and anything left over goes to the Opus review):
  - subject / clue text outside the 9:16 safe region (safe916=0)
  - face over 16% of the frame height (face > 0.16)
  - the same angle + size more than 3 shots in a row
  - camera faster than the speed cap (vpeak > CAP; snap-zoom punches are excluded at measurement)
  - head / torso occluded at the start, middle or end of the move: planned (occ) or seen from the real camera (seen)
  - head top out of the frame at shot mid, any actor in the shot (htop < 0.01; older logs: first actor only, ny - face / 2)
  - dark opening: the shot's first 0.5 s averages luma < 40 (needs beats.json in the folder above the camlog, or cwd)
WARNINGS: 16:9 crop cuts the head (ok169=0), legs behind something low, moves shortened by the speed cap.
Also: brightness (top Shorts measured 92-118 average luma, 0-8% dark frames). Exit code 1 on any FAIL.
"""
import json, os, re, subprocess, sys
from collections import Counter

CAP = 6.5
take, logf = sys.argv[1], sys.argv[2]
text = open(logf).read()
rows = []
for line in text.splitlines():
    m = re.match(r".*\[CAMQA\] (\S+) (\S+) (\S+) (.*)$", line)
    if not m:
        continue
    kv = dict(re.findall(r"(\w+)=(\S+)", m.group(4)))
    rows.append({"key": m.group(1), "size": m.group(2), "who": m.group(3), **kv})

fails, warns = [], []
def num(r, k, d=-1.0):
    try: return float(r.get(k, d))
    except ValueError: return d

run, last = 0, None
for r in rows:
    b, size = r["key"], r["size"]
    why, warn = [], []
    v2 = "safe916" in r
    if v2:
        if r.get("safe916") == "0": why.append("outside 9:16 safe region")
        fmax = {"extreme": 0.6, "close": 0.4}.get(size, 0.16)   # close/extreme are tight on purpose (top Shorts)
        if size != "insert" and num(r, "face") > fmax: why.append(f"face {num(r, 'face'):.2f} > {fmax}")
        ht = num(r, "htop", num(r, "ny") - num(r, "face") / 2)
        if size not in ("insert", "extreme") and num(r, "face") >= 0 and ht < 0.01: why.append(f"head cut off (top y {ht:.2f})")
        if num(r, "vpeak", 0) > CAP: why.append(f"speed {num(r, 'vpeak'):.1f} > {CAP}")
        if "X" in r.get("occ", ""): why.append(f"occluded {r.get('occ')}")
        if "X" in r.get("seen", ""): why.append(f"blocked in the frame {r.get('seen')}")
        if r.get("ok169") == "0": warn.append("16:9 crop cuts the head")
        if "legs" in r.get("occ", ""): warn.append("legs behind something low")
        if r.get("capped") == "1": warn.append("move shortened by the speed cap")
        key = f"{r.get('angle')}|{size}"
        run = run + 1 if key == last else 1
        last = key
        if run > 3: why.append(f"{key} repeated {run}x in a row")
    else:   # old log format
        nx, head = num(r, "nx"), num(r, "head")
        if r["who"] not in ("at", "-") and size != "keys":
            if nx < 0: why.append("subject not visible")
            elif not 0.32 <= nx <= 0.68: why.append(f"off-centre nx={nx:.2f}")
            if head > 0.17: why.append(f"TOO CLOSE head={head:.2f}")
        if r.get("blocked") == "true": why.append("no clear angle")
    if why: fails.append(f"  {b:6s} {size:7s} {r['who']:10s} " + ", ".join(why))
    if warn: warns.append(f"  {b:6s} {size:7s} {r['who']:10s} " + ", ".join(warn))

print(f"camera: {len(rows)} shots logged, {len(fails)} FAIL, {len(warns)} warnings")
if fails: print("FAIL:\n" + "\n".join(fails))
if warns: print("warnings:\n" + "\n".join(warns))
if rows and "angle" in rows[0]:
    ang = Counter(r.get("angle") for r in rows); mv = Counter(r.get("move") for r in rows); sz = Counter(r["size"] for r in rows)
    faces = [num(r, "face") for r in rows if r["size"] != "insert" and num(r, "face") > 0]
    print("angles:", dict(ang.most_common()))
    print("moves: ", dict(mv.most_common()))
    print("sizes: ", dict(sz.most_common()))
    if faces: print(f"face size: median {sorted(faces)[len(faces) // 2]:.3f}, max {max(faces):.3f}")
    # SHOT-MIX LINT (2026-11-23): top Shorts ~25-33% inserts, angles varied. Warn before the real take, not after.
    n = max(len(rows), 1)
    ins = sz.get("insert", 0) / n; lhd = sum(ang.get(k, 0) for k in ("low", "high", "dutch")) / n
    print(f"shot mix: inserts {ins*100:.0f}% (target 25-35%), low/high/dutch {lhd*100:.0f}% (target 25%+)")
    if ins > 0.35: print("  WARN: too many inserts: turn some into close/medium reaction shots")
    if lhd < 0.25: print("  WARN: angle variety low: give mediums/inserts a low or high angle")
    print(f"9:16 safe: {sum(r.get('safe916') == '1' for r in rows)}/{len(rows)}   16:9 ok: {sum(r.get('ok169') == '1' for r in rows)}/{len(rows)}   "
          f"occlusion-free: {sum('X' not in r.get('occ', '') + r.get('seen', '') for r in rows)}/{len(rows)}   peak speed max {max(num(r, 'vpeak', 0) for r in rows):.1f}")

ok = not fails
# ONE pass over the 9:16 strip at 10 fps: brightness stats, the sync flash (story t = flash + 0.5) and each shot's first 0.5 s
out = subprocess.run(["ffmpeg", "-i", take, "-vf", "crop='min(iw,ih*9/16)':ih,fps=10,scale=54:96,signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"],
                     capture_output=True, text=True).stderr
ys10 = [float(x) for x in re.findall(r"YAVG=([\d.]+)", out)]
ys = ys10[::5]
beats = next((p for p in (os.path.join(os.path.dirname(os.path.abspath(logf)), "..", "beats.json"), "beats.json") if os.path.exists(p)), None)
if beats:  # fix (2026-11-24): a beat with no [CAMQA] line never got a camera (unreplicated first-beat prop) and froze on the old shot
    logged = {r["key"] for r in rows} | set(re.findall(r"\[CAMKEY\] (\S+)", open(logf).read()))   # keyframe shots log [CAMKEY]
    missing = [f"{b['line']}.{b['k']}" for b in json.load(open(beats)) if f"{b['line']}.{b['k']}" not in logged]
    if missing: print(f"FAIL: {len(missing)} beats have no camera line: {' '.join(missing)}"); ok = False
if beats and ys10:
    start ={f"{b['line']}.{b['k']}": b["start"] for b in json.load(open(beats))}
    t0 = next((i for i, y in enumerate(ys10) if y > 110), -5) / 10 + 0.5   # no flash (an assembled video): story starts at 0
    dark = []
    for r in rows:
        if r["key"] not in start: continue
        i = round((t0 + start[r["key"]]) * 10); w = ys10[i:i + 5]
        if len(w) == 5 and sum(w) / 5 < 40: dark.append(f"  {r['key']:6s} {r['size']:7s} {r['who']:10s} opens dark: luma {sum(w) / 5:.0f} in its first 0.5 s (take {i / 10:.1f}s)")
    if dark: print("FAIL:\n" + "\n".join(dark)); ok = False
# blank frames (2026-11-24, user: a blank screen for a second): >= 0.25 s of almost no picture (camera inside a wall/locker/step): FAIL
try:
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", take, "-vf", "crop='min(iw,ih*9/16)':ih,fps=10,scale=54:96,format=gray", "-f", "rawvideo", "-"], capture_output=True).stdout
    fr = np.frombuffer(raw[: len(raw) // 5184 * 5184], np.uint8).reshape(-1, 96, 54).reshape(-1, 5184)
    flat = (fr.std(1) < 12) | (fr.mean(1) < 8)
    if beats: bstart = sorted((b["start"], f"{b['line']}.{b['k']}") for b in json.load(open(beats)))
    t0b = next((i for i, y in enumerate(ys10) if y > 110), -5) / 10 + 0.5
    i = 0
    while i < len(flat):
        if flat[i]:
            j = i
            while j < len(flat) and flat[j]: j += 1
            tt = i / 10 - t0b
            if (j - i) >= 3 and tt > 0.3:
                where = next((k for s0, k in reversed(bstart) if s0 <= tt), "?") if beats else "?"
                print(f"FAIL: blank screen {(j - i) / 10:.1f} s at story {tt:.1f}s (beat {where}): the camera is inside something"); ok = False
            i = j
        else: i += 1
except ImportError:
    pass
story = [y for y in ys if y > 3][2:]
if story:
    avg = sum(story) / len(story)
    dark = 100 * sum(y < 60 for y in story) / len(story)
    print(f"brightness: average {avg:.0f} (target 92+), dark frames {dark:.0f}% (target under 10%)")
    ok = ok and avg >= 92 and dark <= 10
print("QA", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
