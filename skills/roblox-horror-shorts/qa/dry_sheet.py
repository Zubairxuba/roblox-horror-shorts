"""One frame per beat (middle) from dry-run captures:  dry_sheet.py out_prefix video.mp4@From ...   Aligns on the white sync flash."""
import json, re, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw
B = json.load(open("beats.json"))
pre, segs = sys.argv[1], [a.rsplit("@", 1) for a in sys.argv[2:]]
frames = {}
for vid, frm in segs:
    frm = float(frm)
    r = subprocess.run(["ffmpeg", "-i", vid, "-vf", "scale=27:48,signalstats,metadata=print", "-f", "null", "-"], capture_output=True, text=True).stderr
    ts = [float(x) for x in re.findall(r"pts_time:([\d.]+)", r)]; ys = [float(x) for x in re.findall(r"YAVG=([\d.]+)", r)]
    fl = next(t for t, y in zip(ts, ys) if y > 200)
    for b in B:
        mid = (b["start"] + b["stop"]) / 2
        key = f"{b['line']}.{b['k']}"
        if key in frames or not (frm <= b["start"] - 0.0 and mid < frm + (ts[-1] - fl - 0.5)):
            continue
        out = f"qa/_d_{key}.jpg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{fl + 0.5 + mid - frm:.2f}", "-i", vid, "-frames:v", "1", "-vf", "crop=ih*9/16:ih,scale=240:-2", out], check=True)
        if Path(out).exists(): frames[key] = out
keys = [f"{b['line']}.{b['k']}" for b in B]
print("missing:", [k for k in keys if k not in frames])
have = [k for k in keys if k in frames]
COLS, ROWS = 7, 2
for s in range(0, len(have), COLS * ROWS):
    chunk = have[s:s + COLS * ROWS]
    w, h = Image.open(frames[chunk[0]]).size
    sheet = Image.new("RGB", (w * COLS + 6 * (COLS - 1), h * ROWS + 6), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(chunk):
        x, y = (i % COLS) * (w + 6), (i // COLS) * (h + 6)
        sheet.paste(Image.open(frames[k]), (x, y)); d.rectangle([x, y, x + 52, y + 22], fill=(0, 0, 0)); d.text((x + 5, y + 4), k, fill=(255, 255, 0))
    sheet.save(f"{pre}_{s // (COLS * ROWS) + 1}.jpg", quality=85)
    print(f"{pre}_{s // (COLS * ROWS) + 1}.jpg", chunk[0], "->", chunk[-1])
