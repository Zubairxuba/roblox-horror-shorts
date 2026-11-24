"""Voice a story's script.txt line by line with Chatterbox, cloning a reference voice YOU supply.

usage: python pipeline/voice.py <story_dir> --ref my_voice.wav [--exaggeration 0.75] [--pause 0.3] [--seed 42]
  -> <story_dir>/narration.mp3 + timings.json ([speech_start, speech_end] seconds per line)
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
ap.add_argument("--pause", type=float, default=0.3, help="silence between lines (s)")
ap.add_argument("--seed", type=int, default=42)
a = ap.parse_args()

device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
if device == "mps":  # Chatterbox checkpoints were saved on CUDA; load them onto the CPU first
    _load = torch.load
    torch.load = lambda *x, **k: _load(*x, **{"map_location": torch.device("cpu"), **k})
from chatterbox.tts import ChatterboxTTS  # noqa: E402

d = a.story_dir
cfg = {k: getattr(a, k) for k in ("exaggeration", "cfg_weight", "temperature", "seed")} | {"ref": hashlib.sha1(a.ref.read_bytes()).hexdigest()[:12]}
model = None
cache = d / "lines"
cache.mkdir(exist_ok=True)
parts, timings, t = [], [], 0.0
for line in (l.replace("*", "").strip() for l in (d / "script.txt").read_text().splitlines()):
    if not line:
        continue
    f = cache / (hashlib.sha1((line + json.dumps(cfg, sort_keys=True)).encode()).hexdigest()[:12] + ".wav")
    if not f.exists():
        if model is None:
            model = ChatterboxTTS.from_pretrained(device=device)
        torch.manual_seed(a.seed)
        wav = model.generate(line, audio_prompt_path=str(a.ref), exaggeration=a.exaggeration,
                             cfg_weight=a.cfg_weight, temperature=a.temperature)
        sf.write(f, wav.squeeze(0).cpu().numpy(), model.sr)
    audio, sr = sf.read(f, dtype="float32")
    parts += [audio, np.zeros(int(sr * a.pause), dtype="float32")]
    timings.append([round(t, 3), round(t + len(audio) / sr, 3)])
    t += (len(audio) + int(sr * a.pause)) / sr
wav = d / "narration.wav"
sf.write(wav, np.concatenate(parts), sr)
subprocess.run([FF, "-loglevel", "error", "-y", "-i", str(wav), "-codec:a", "libmp3lame", "-qscale:a", "2", str(d / "narration.mp3")], check=True)
wav.unlink()
(d / "timings.json").write_text(json.dumps(timings))
print(f"voiced {len(timings)} lines -> {d / 'narration.mp3'}")
