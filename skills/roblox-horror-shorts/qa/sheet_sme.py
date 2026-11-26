"""Start / middle / end contact sheets for every beat of a take, cut to the 9:16 strip (or 16:9 with --wide).

    python3 sheet_sme.py <take.mp4> <out_prefix> [--wide] [--beats 1.1,6.2,...]
    python3 sheet_sme.py seg1.mp4@0,seg2.mp4@28,... <out_prefix>      (segments recorded with workspace From = N seconds)

The 9:16 strip is computed from the take's own resolution (centre, full height); the 16:9 crop is full width,
bottom-aligned (drops the top band where Roblox draws its corner buttons). The story start is found from the white
sync flash, exactly like assemble.py. One sheet per third of the beats: <out_prefix>_1.png .. _3.png, or one
sheet of just the listed beats when --beats is given.
"""
import json, os, re, subprocess, sys

FF = os.environ.get("FFMPEG", "ffmpeg")
take, out = sys.argv[1], sys.argv[2]
wide = "--wide" in sys.argv
pick = sys.argv[sys.argv.index("--beats") + 1].split(",") if "--beats" in sys.argv else None
segs = []
for part in take.split(","):
    path, _, frm = part.partition("@")
    segs.append((path, float(frm or 0)))
tmp = out + "_tmp"; os.makedirs(tmp, exist_ok=True)
for f in os.listdir(tmp): os.remove(os.path.join(tmp, f))
allbeats = json.load(open("beats.json"))
if pick: allbeats = [b for b in allbeats if f"{b['line']}.{b['k']}" in pick]
done = set()
for si, (path, frm) in enumerate(segs):
    W, H = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                    "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(",")[:2])
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                               capture_output=True, text=True).stdout.strip())
    if wide:
        h = round(W * 9 / 16); crop = f"crop={W}:{h}:0:{H - h},scale=320:-2"
    else:
        w = round(H * 9 / 16); crop = f"crop={w}:{H}:{(W - w) // 2}:0,scale=150:-2"
    r = subprocess.run(["ffmpeg", "-i", path, "-vf", "scale=32:20,signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    ys = [float(x) for x in re.findall(r"YAVG=([\d.]+)", r)]
    num, den = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=avg_frame_rate",
                              "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split("/")
    fps = float(num) / float(den or 1)
    t0 = next(k for k, y in enumerate(ys) if y > 110) / fps + 0.5   # = story time `frm`
    print(f"{path}: story {frm:.0f}s starts at {t0:.2f}s, {W}x{H} @ {fps:.1f} fps, {dur:.1f}s")
    for b in allbeats:
        key = f"{b['line']}.{b['k']}"
        if key in done or b["start"] < frm - 0.01 or t0 + b["stop"] - frm > dur - 0.05: continue
        done.add(key)
        for j, u in enumerate((0.12, 0.5, 0.88)):
            t = t0 + b["start"] - frm + (b["stop"] - b["start"]) * u
            lab = f"{key} {'SME'[j]}"
            subprocess.run([FF, "-v", "error", "-y", "-ss", f"{t:.3f}", "-i", path, "-frames:v", "1", "-vf",
                            f"{crop},drawtext=text='{lab}':x=4:y=4:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.4",
                            f"{tmp}/{b['line']:02d}_{b['k']:02d}_{j}.png"])
print(f"{len(done)}/{len(allbeats)} beats covered")
files = sorted(f for f in os.listdir(tmp) if f.endswith('.png'))
per = -(-len(files) // 3 // 9) * 9   # a third of the frames, rounded up to whole rows of 3 beats
groups = [files] if pick else [files[k * per:(k + 1) * per] for k in range(3)]
cols = 9 if not wide else 6
for gi, g in enumerate(groups, 1):
    if not g: continue
    lst = os.path.join(tmp, f"list{gi}.txt")
    with open(lst, "w") as fh:
        for f in g: fh.write(f"file '{os.path.abspath(os.path.join(tmp, f))}'\n")
    name = f"{out}.png" if pick else f"{out}_{gi}.png"
    subprocess.run([FF, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-vf",
                    f"tile={cols}x{(len(g) + cols - 1) // cols}", "-frames:v", "1", name])
    print(name, len(g) // 3, "beats")
