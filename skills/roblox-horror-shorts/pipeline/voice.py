"""Voice a story's script.txt line by line with Chatterbox, cloning a reference voice YOU supply.

usage: python pipeline/voice.py <story_dir> --ref my_voice.wav [--exaggeration 0.75] [--pause 0.05] [--tempo 1.25] [--seed 42]
  -> <story_dir>/narration.mp3 + timings.json ([speech_start, speech_end] seconds per line, after the tempo change)
Pace: Chatterbox's silence around each line is trimmed, lines are joined with a short pause and the whole track is sped up
1.25x (ffmpeg rubberband keeps the pitch and formants; atempo if your ffmpeg has no rubberband): ~4.5 words/s, like top Shorts.
Per-line voice / emotion: optional <story_dir>/voices.json = {"7": {"ref": "kid.wav", "exaggeration": 0.95}, ...}
(line numbers count non-empty script lines; calm ~0.4, scared/shouting >= 0.9). One voice per character.
script.txt: one line per shot; *asterisks* are stripped before speaking. Each spoken line is cached in <story_dir>/lines/
by its text + settings, so after editing script.txt (and deleting narration.mp3) only changed lines are re-voiced.
Only clone a voice you own or have written permission to use. Chatterbox can repeat words after a leading "..." or add
trailing words: timeline.py's Whisper check prints how many script words it heard; listen when that number is low.
"""
import argparse, hashlib, json, subprocess
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from finish import FF

ap = argparse.ArgumentParser()
ap.add_argument("story_dir", type=Path)
ap.add_argument("--ref", type=Path, required=True, help="clean 10-20 s wav of the narrator voice")
ap.add_argument("--exaggeration", type=float, default=0.75)
ap.add_argument("--cfg_weight", type=float, default=0.4)
ap.add_argument("--temperature", type=float, default=0.8)
ap.add_argument("--pause", type=float, default=0.05, help="silence between lines before the tempo change (s)")
ap.add_argument("--tempo", type=float, default=1.25, help="speed-up of the whole track (1 = none)")
ap.add_argument("--seed", type=int, default=42)
a = ap.parse_args()

device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
if device == "mps":  # Chatterbox checkpoints were saved on CUDA; load them onto the CPU first
    _load = torch.load
    torch.load = lambda *x, **k: _load(*x, **{"map_location": torch.device("cpu"), **k})
from chatterbox.tts import ChatterboxTTS  # noqa: E402

d = a.story_dir
sha = lambda f: hashlib.sha1(Path(f).read_bytes()).hexdigest()[:12]  # noqa: E731
cfg = {k: getattr(a, k) for k in ("exaggeration", "cfg_weight", "temperature", "seed")} | {"ref": sha(a.ref)}
per_line = json.loads((d / "voices.json").read_text()) if (d / "voices.json").exists() else {}
model = None
cache = d / "lines"
cache.mkdir(exist_ok=True)
parts, timings, t, sr = [], [], 0.0, 24000
lines = [l.replace("*", "").strip() for l in (d / "script.txt").read_text().splitlines()]
for n, line in enumerate((l for l in lines if l), 1):
    over = per_line.get(str(n), {})
    ref = Path(over.get("ref", a.ref))
    c = cfg | {k: v for k, v in over.items() if k != "ref"} | {"ref": sha(ref)}
    f = cache / (hashlib.sha1((line + json.dumps(c, sort_keys=True)).encode()).hexdigest()[:12] + ".wav")
    if not f.exists():
        if model is None:
            model = ChatterboxTTS.from_pretrained(device=device)
        torch.manual_seed(c["seed"])
        wav = model.generate(line, audio_prompt_path=str(ref), exaggeration=c["exaggeration"],
                             cfg_weight=c["cfg_weight"], temperature=c["temperature"])
        sf.write(f, wav.squeeze(0).cpu().numpy(), model.sr)
    audio, sr = sf.read(f, dtype="float32")
    loud = np.where(np.abs(audio) > 0.01)[0]   # trim the ~0.27 s of silence Chatterbox leaves around each line (-40 dB)
    audio = audio[max(0, loud[0] - int(sr * 0.03)): loud[-1] + int(sr * 0.03)] if len(loud) else audio
    parts += [audio, np.zeros(int(sr * a.pause), dtype="float32")]
    timings.append([round(t / a.tempo, 3), round((t + len(audio) / sr) / a.tempo, 3)])
    t += (len(audio) + int(sr * a.pause)) / sr
wav = d / "narration.wav"
sf.write(wav, np.concatenate(parts), sr)
has_rb = "rubberband" in subprocess.run([FF, "-hide_banner", "-filters"], capture_output=True, text=True).stdout
speed = f"rubberband=tempo={a.tempo}:pitchq=quality:formant=preserved" if has_rb else f"atempo={a.tempo}"
subprocess.run([FF, "-loglevel", "error", "-y", "-i", str(wav), "-af", speed, "-codec:a", "libmp3lame", "-qscale:a", "2",
                str(d / "narration.mp3")], check=True)
wav.unlink()
(d / "timings.json").write_text(json.dumps(timings))
print(f"voiced {len(timings)} lines at {a.tempo}x ({'rubberband' if has_rb else 'atempo'}) -> {d / 'narration.mp3'}")
