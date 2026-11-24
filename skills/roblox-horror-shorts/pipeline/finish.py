"""Audio + timing helpers shared by every story's timeline.py and assemble.py.

- words_with_times(d): Whisper word timings on d/narration.mp3, spelling taken from d/script.txt
- SFX / sfx_file(name, secs): synthesized sound effects (ffmpeg lavfi; nothing to copyright-claim)
- mix_audio(...) / loudness(...): voice + effects + low drone, one fixed gain to -14 LUFS (the voice never dips)

Env: FFMPEG / FFPROBE (default: from PATH), WHISPER_MODEL (default: pipeline/models/ggml-base.en.bin), whisper-cli on PATH.
"""
import difflib, json, os, re, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FF = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or "ffmpeg"
FP = os.environ.get("FFPROBE") or shutil.which("ffprobe") or "ffprobe"
WHISPER_MODEL = Path(os.environ.get("WHISPER_MODEL", HERE / "models" / "ggml-base.en.bin"))
SFX_DIR = HERE / "sfx"  # generated effect cache (gitignored)
TARGET_I, TARGET_TP = -14.0, -1.5

SFX = {  # name: (aevalsrc expression or None for wind, default seconds, mix volume)
    "pop": ("0.7*sin(2*PI*(500+900*t)*t)*exp(-t*35)", 0.2, 0.5),
    "whoosh": ("(random(0)-0.5)*pow(sin(PI*t/0.7),2)", 0.7, 0.35),
    "tick": ("0.8*sin(2*PI*2400*mod(t,1))*exp(-mod(t,1)*180)", 3, 0.5),
    "knock": ("if(lt(t,2.1),(0.9*sin(2*PI*85*mod(t,0.7))+0.5*(random(0)-0.5))*exp(-30*mod(t,0.7)),0)", 2.4, 1.0),
    "ring": ("if(lt(mod(t,3),1.6),0.18*(sin(2*PI*440*t)+sin(2*PI*480*t))*(0.6+0.4*sin(2*PI*20*t)),0)", 6, 0.6),
    "stinger": ("0.9*sin(2*PI*42*t)*exp(-1.5*t)+0.5*(random(0)-0.5)*exp(-6*t)+0.25*sin(2*PI*(220+80*t)*t)*exp(-2*t)", 3, 0.9),
    "heartbeat": ("0.9*(sin(2*PI*50*mod(t,0.85))*exp(-22*mod(t,0.85))+gt(mod(t,0.85),0.25)*sin(2*PI*45*(mod(t,0.85)-0.25))*exp(-22*(mod(t,0.85)-0.25)))", 6, 0.8),
    "wind": (None, 30, 0.45),
}


def run(cmd):
    r = subprocess.run([str(c) for c in cmd], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode:
        raise SystemExit(r.stderr.decode()[-2000:])


def sfx_file(name, secs):
    out = SFX_DIR / f"{name}_{secs:g}.wav"
    if out.exists():
        return out
    SFX_DIR.mkdir(exist_ok=True)
    expr = SFX[name][0]
    if expr:
        run([FF, "-y", "-f", "lavfi", "-i", f"aevalsrc='{expr}':s=44100:d={secs}", "-af", f"afade=t=out:st={max(0, secs - 0.5)}:d={min(0.5, secs)}", out])
    else:  # wind: band-passed pink noise with slow gusts
        run([FF, "-y", "-f", "lavfi", "-i", f"anoisesrc=color=pink:amplitude=0.6:d={secs}:r=44100",
             "-af", f"bandpass=f=500:width_type=h:w=400,volume='0.35+0.25*sin(2*PI*t/6)':eval=frame,afade=t=in:d=3,afade=t=out:st={secs - 3}:d=3", out])
    return out


def _norm(w):
    return re.sub(r"[^a-z0-9]", "", w.lower())


def words_with_times(d: Path):
    """Whisper gives timing; script.txt gives spelling. Returns [(start_s, word, line_index)]."""
    wav = d / "work16k.wav"
    run([FF, "-y", "-i", d / "narration.mp3", "-ar", "16000", "-ac", "1", wav])
    run(["whisper-cli", "-m", WHISPER_MODEL, "-f", wav, "-ml", "1", "-sow", "-oj", "-of", d / "words"])
    wav.unlink()
    seg = json.loads((d / "words.json").read_text())["transcription"]
    heard = [(s["offsets"]["from"] / 1000, s["text"].strip()) for s in seg if s["text"].strip()]
    script = [(w, i) for i, line in enumerate(l for l in (d / "script.txt").read_text().splitlines() if l.strip()) for w in line.split()]
    times = [None] * len(script)
    sm = difflib.SequenceMatcher(None, [_norm(w) for w, _ in script], [_norm(t) for _, t in heard], autojunk=False)
    for a, b, n in sm.get_matching_blocks():
        for k in range(n):
            times[a + k] = heard[b + k][0]
    known = [i for i, t in enumerate(times) if t is not None]
    print(f"voice check: {len(known)}/{len(script)} script words heard", file=sys.stderr)  # low = skipped/garbled lines
    assert len(known) > len(script) * 0.6, f"only {len(known)}/{len(script)} words matched; narration and script.txt differ"
    for i in range(len(times)):  # interpolate words whisper misspelled (e.g. 2:13 -> 2013)
        if times[i] is None:
            lo = max([k for k in known if k < i], default=None)
            hi = min([k for k in known if k > i], default=None)
            t0 = times[lo] if lo is not None else 0.0
            t1 = times[hi] if hi is not None else t0 + 0.4 * (i - (lo or 0))
            a, b = (lo if lo is not None else -1), (hi if hi is not None else len(times))
            times[i] = t0 + (t1 - t0) * (i - a) / (b - a)
    for i in range(1, len(times)):
        times[i] = max(times[i], times[i - 1])
    return [(t, w, ln) for t, (w, ln) in zip(times, script)]


def loudness(path):
    """(integrated LUFS, true peak dBTP) of an audio file."""
    e = subprocess.run([FF, "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    tail = e[e.rfind("Summary:"):].split()
    return float(tail[tail.index("I:") + 1]), float(tail[tail.index("Peak:") + 1])


def mix_audio(d, cues, drone, end, out, voice_db=12.0):
    """Voice + beds -> out (48 kHz wav), BEFORE the final gain. Nothing dynamic ever touches the voice: the effects and
    the drone duck under it instead (a loudness normaliser on the whole mix made the voice pump whenever an effect hit).
    cues: (time_s, name, seconds[, gain])."""
    ins, graph, sfx = ["-i", d / "final" / "narration.mp3"], [], []
    for t, name, secs, *g in cues:
        ins += ["-i", sfx_file(name, secs)]
        ms = int(t * 1000)
        graph.append(f"[{len(sfx) + 1}:a]aresample=48000,volume={SFX[name][2] * 0.6 * (g[0] if g else 1):.3f},"
                     f"volume={voice_db}dB,adelay={ms}|{ms},apad[s{len(sfx)}]")
        sfx.append(f"[s{len(sfx)}]")
    keys = (1 if sfx else 0) + (1 if drone else 0)
    graph.append(f"[0:a]aresample=48000,volume={voice_db}dB,alimiter=limit=0.75:attack=3:release=80:level=disabled,apad" + (f",asplit={keys + 1}[v]" + "".join(f"[k{i}]" for i in range(keys)) if keys else "[v]"))
    beds, k = [], 0
    if sfx:  # effects bus: dips ~6 dB while a word is spoken, recovers over 0.4 s
        graph.append(f"{''.join(sfx)}amix=inputs={len(sfx)}:normalize=0[sb];"
                     f"[sb][k{k}]sidechaincompress=threshold=0.03:ratio=6:attack=15:release=350[sfx]")
        beds, k = beds + ["[sfx]"], k + 1
    if drone:  # low bed with 110-250 Hz energy so phone speakers play it
        graph.append(f"anoisesrc=color=brown:amplitude=0.4:d={end}:r=48000,bandpass=f=160:width_type=h:w=150[dn];"
                     f"sine=f=55:d={end}:r=48000[d1];sine=f=110:d={end}:r=48000[d2];sine=f=116.4:d={end}:r=48000[d3];"
                     f"[dn][d1][d2][d3]amix=inputs=4,volume=0.6*0.35,volume={voice_db}dB,afade=t=in:d=2,afade=t=out:st={end - 2}:d=2,apad[dr];"
                     f"[dr][k{k}]sidechaincompress=threshold=0.02:ratio=2:attack=80:release=1500[drone]")
        beds.append("[drone]")
    graph.append(f"[v]{''.join(beds)}amix=inputs={1 + len(beds)}:duration=first:normalize=0[a]")
    run([FF, "-y", *ins, "-filter_complex", ";".join(graph), "-map", "[a]", "-t", str(end), "-ar", "48000", "-c:a", "pcm_s16le", out])
    return out
