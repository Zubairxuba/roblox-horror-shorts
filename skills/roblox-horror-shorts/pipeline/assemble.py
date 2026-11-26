"""Sound + final video for one Short. Copy into projects/<slug>/ next to timeline.py and run it there.

  assemble.py audio   # events.json -> SFX (Sonniss library if present, else synthesized) + polished voice -> final/full_audio.wav
  assemble.py video   # final/take.mp4 (screen recording, starts black, one white sync flash 0.5 s before t=0) -> full_video.mp4
                      # (one-word captions burned in from words_full.json; CAPTIONS=0 to skip)
  assemble.py music   # full_video.mp4 + final/score.wav (score.py) -> full_video_with_music.mp4, score ducked under the voice
"""
import json, os, re, subprocess, sys
from pathlib import Path

sys.path.insert(0, os.environ.get("SHORTS_PIPELINE", str(Path(__file__).resolve().parent)))  # pipeline/ folder (finish.py)
import finish as F  # noqa: E402
from finish import SFX  # noqa: E402

HERE = Path(__file__).resolve().parent
# the TAKE's camera log (rehearsals overwrite qa/camlog.txt: copy it to qa/camlog_take<N>.txt right after the take and
# run with CAMLOG=qa/camlog_take<N>.txt); used for the [CAMVP] crop and the [REPLAN] blink fix
CAMLOG = HERE / os.environ.get("CAMLOG", "qa/camlog.txt")
FIN = HERE / "final"
FPS, SR = 30, 48000
shots = json.loads((HERE / "shots.json").read_text())
EV = json.loads((HERE / "events.json").read_text())
END_F = round(shots[-1]["end"] * FPS)
E = {e["id"]: e for e in EV}

# name: (seconds, ffmpeg source, filter chain). All synthesized: nothing to copyright-claim.
NEW_SFX = {
    "knock1": (0.4, "aevalsrc='(0.9*sin(2*PI*85*t)+0.6*(random(0)-0.5))*exp(-28*t)'", "lowpass=f=1800"),
    "click": (0.15, "aevalsrc='0.7*(random(0)-0.5)*exp(-t*260)+0.4*sin(2*PI*1600*t)*exp(-t*180)+0.3*(random(0)-0.5)*exp(-(t-0.05)*300)*gt(t,0.05)'", "highpass=f=400"),
    "zap": (0.7, "aevalsrc='(0.6*(random(0)-0.5)*(0.5+0.5*sin(2*PI*60*t))+0.35*sin(2*PI*120*t))*exp(-t*7)'", "lowpass=f=5000"),
    "creak": (1.3, "aevalsrc='0.4*sin(2*PI*(260+90*sin(2*PI*1.1*t))*t+2.5*sin(2*PI*31*t))*sin(PI*t/1.3)'", "bandpass=f=600:width_type=h:w=900"),
    "thunder": (4.0, "anoisesrc=color=brown:amplitude=1:r=44100:d=4", "lowpass=f=260,volume='(0.3+0.7*exp(-((t-0.25)*(t-0.25))/0.02))*exp(-0.7*t)*(1+0.4*sin(2*PI*2.3*t))':eval=frame,volume=6"),
    "step": (0.45, "aevalsrc='(sin(2*PI*65*t)+0.35*(random(0)-0.5))*exp(-t*22)+0.15*sin(2*PI*(380+60*t)*t)*exp(-t*9)'", "lowpass=f=1500"),
    "truck": (5.0, "anoisesrc=color=brown:amplitude=0.8:r=44100:d=5", "lowpass=f=220,volume='(min(t/0.8,1))*exp(-0.45*t)*(1+0.25*sin(2*PI*14*t))':eval=frame,volume=3"),
    "buzz": (1.4, "aevalsrc='0.3*(sin(2*PI*120*t)+0.5*sin(2*PI*240*t)+0.25*sin(2*PI*360*t))*if(lt(t,0.7),gt(sin(2*PI*11*t+3*sin(2*PI*3*t)),0.1),1)*exp(-0.6*max(t-0.7,0))'", "lowpass=f=3000"),
    "drop": (3.0, "aevalsrc='0.95*sin(2*PI*(32+70*exp(-t*3.5))*t)*exp(-t*1.1)+0.5*(random(0)-0.5)*exp(-t*18)'", "lowpass=f=2500"),
    "boom": (3.0, "aevalsrc='0.9*sin(2*PI*(36+40*exp(-t*4))*t)*exp(-t*1.4)+0.25*(random(0)-0.5)*exp(-t*10)'", "lowpass=f=900"),
    "riser": (2.0, "aevalsrc='(0.6*(random(0)-0.5)+0.35*sin(2*PI*(180+500*t*t)*t))*pow(t/2,2.2)'", "highpass=f=150"),
    "revwhoosh": (0.8, "aevalsrc='(random(0)-0.5)*pow(t/0.8,3)'", "bandpass=f=1200:width_type=h:w=1600"),
    "swell": (2.5, "aevalsrc='0.18*(sin(2*PI*220*t)+sin(2*PI*277.2*t)+sin(2*PI*329.6*t))*min(t/1.2,1)*exp(-0.5*max(t-1.2,0))'", "lowpass=f=2000"),
    "endswell": (1.6, "aevalsrc='(0.4*(random(0)-0.5)+0.3*sin(2*PI*(110+300*t*t)*t))*pow(t/1.6,2.5)'", "highpass=f=100"),
    "gust": (3.0, "anoisesrc=color=pink:amplitude=0.7:r=44100:d=3", "bandpass=f=450:width_type=h:w=500,volume='pow(sin(PI*t/3),2)':eval=frame"),
    "fsqueeze": (0.18, "aevalsrc='0.6*(random(0)-0.5)*exp(-t*40)+0.3*sin(2*PI*180*t)*exp(-t*35)'", "lowpass=f=1400"),
    "fthud": (0.6, "aevalsrc='0.9*sin(2*PI*(90-40*t)*t)*exp(-t*14)+0.3*(random(0)-0.5)*exp(-t*40)'", "lowpass=f=900"),
    "bang": (1.0, "aevalsrc='0.95*(random(0)-0.5)*exp(-t*25)+0.8*sin(2*PI*(110-50*t)*t)*exp(-t*9)+0.5*(random(0)-0.5)*exp(-(t-0.18)*30)*gt(t,0.18)'", "lowpass=f=3500"),
    "chime": (3.0, "aevalsrc='0.35*(sin(2*PI*880*t)+0.5*sin(2*PI*1320*t)+0.25*sin(2*PI*2210*t))*exp(-t*1.6)'", "aecho=0.6:0.5:300:0.3"),
    "carve": (0.8, "aevalsrc='(random(0)-0.5)*(0.5+0.5*sin(2*PI*9*t))*sin(PI*t/0.8)'", "bandpass=f=3000:width_type=h:w=2500"),
    "snuff": (0.9, "aevalsrc='(random(0)-0.5)*exp(-t*5)*0.8'", "bandpass=f=1800:width_type=h:w=2400,lowpass=f=5000"),
    "bolt": (0.6, "aevalsrc='0.9*sin(2*PI*(140-80*t)*t)*exp(-t*16)+0.6*(random(0)-0.5)*exp(-t*50)+0.4*sin(2*PI*900*t)*exp(-(t-0.12)*60)*gt(t,0.12)'", "lowpass=f=2500"),
    "draft": (2.2, "anoisesrc=color=pink:amplitude=0.6:r=44100:d=2.2", "bandpass=f=700:width_type=h:w=600,volume='pow(sin(PI*t/2.2),2)':eval=frame"),
    "bell": (1.6, "aevalsrc='0.45*(sin(2*PI*1180*t)+0.6*sin(2*PI*2950*t)+0.3*sin(2*PI*4410*t))*exp(-mod(t,0.19)*14)*exp(-t*1.2)'", "highpass=f=500,aecho=0.6:0.4:60:0.25"),
    "bellfar": (2.4, "aevalsrc='0.3*(sin(2*PI*990*t)+0.6*sin(2*PI*2480*t))*exp(-mod(t,0.23)*11)*exp(-t*0.8)+0.25*(sin(2*PI*1340*t)+0.5*sin(2*PI*3350*t))*exp(-mod(t+0.1,0.27)*11)*exp(-t*0.8)'", "highpass=f=500,lowpass=f=4500,aecho=0.8:0.7:120|260:0.4|0.3"),
    "bite": (0.4, "aevalsrc='0.9*(random(0)-0.5)*(exp(-t*30)+0.6*exp(-abs(t-0.12)*40))*gt(random(1),0.35)'", "bandpass=f=2600:width_type=h:w=3200"),
    "dong": (2.2, "aevalsrc='0.7*(sin(2*PI*392*t)+0.55*sin(2*PI*784*t)+0.3*sin(2*PI*1176*t)+0.2*sin(2*PI*1568*t))*exp(-t*2.1)'", "aecho=0.6:0.5:90:0.3"),
    "rip": (0.4, "aevalsrc='(random(0)-0.5)*(0.7+0.3*sin(2*PI*110*t))*exp(-t*7)'", "highpass=f=900"),
    "slurp": (0.9, "aevalsrc='(0.45*(random(0)-0.5)+0.55*sin(2*PI*(1100-850*t)*t))*sin(PI*t/0.9)'", "bandpass=f=900:width_type=h:w=1100"),
    "crackle": (None, "aevalsrc='0.5*(random(0)-0.5)*gt(random(1),0.9975)+0.04*(random(2)-0.5)'", "bandpass=f=2500:width_type=h:w=3000"),
}


def make_sfx(name, secs):
    """Write pipeline/sfx/<name>_<secs>.wav (the path finish.mix_audio looks for) and register its volume."""
    dur, src, filt = NEW_SFX[name]
    secs = round(secs, 1) if dur is None else dur
    F.SFX_DIR.mkdir(exist_ok=True)
    out = F.SFX_DIR / f"{name}_{secs:g}.wav"
    if not out.exists():
        src = src if "d=" in src or "aevalsrc" not in src else src
        src = f"{src}:d={secs}" if src.startswith("aevalsrc") else (src if "d=" in src else f"{src}:d={secs}")
        fade = f"afade=t=in:d={0.6 if dur is None else 0.003},afade=t=out:st={max(0, secs - (1.0 if dur is None else 0.08)):.2f}:d={1.0 if dur is None else 0.08}"
        F.run([F.FF, "-y", "-f", "lavfi", "-i", src, "-af", f"{filt},{fade}", "-ar", "44100", "-ac", "1", out])
    SFX[name] = (None, secs, 1.0)
    return secs


LIB = Path(os.environ.get("SFX_LIBRARY", "sfx_library"))  # optional: your licensed SFX wavs (Sonniss GDC, Freesound CC0)
# story sound key -> words to look for in library file names (Sonniss GDC / Freesound CC0)
LIB_WORDS = {"boom": ["impact", "boom"], "stinger": ["stinger", "horror hit", "scare"], "whoosh": ["whoosh"],
             "riser": ["riser", "rise"], "drop": ["sub drop", "bass drop", "drop"], "creak": ["creak"], "buzz": ["hum", "buzz"],
             "tick": ["freewheel", "bicycle", "ratchet"], "swell": ["swell", "drone"], "chime": ["chime", "bell"],
             "endswell": ["reverse", "swell"], "wind": ["wind"]}
ALIAS = {"stinger_soft": "stinger"}
WALKS = []  # footsteps: (line, from s, to s into the shot, gain), e.g. [(18, 0.1, 3.0, 0.2)]


def lib_file(key, secs):
    """First matching library wav, cut to secs and normalised into pipeline/sfx/lib_<key>_<secs>.wav; None if no library yet."""
    words = LIB_WORDS.get(key)
    wavs = sorted(LIB.rglob("*.wav")) if words else []
    hits = [w for w in wavs if any(x in w.name.lower() for x in words)]
    if not hits:
        return None
    name = f"lib_{key}"
    F.SFX_DIR.mkdir(exist_ok=True)
    out = F.SFX_DIR / f"{name}_{secs:g}.wav"
    if not out.exists():
        F.run([F.FF, "-y", "-i", hits[0], "-t", str(secs), "-af", f"loudnorm=I=-20,afade=t=out:st={max(0, secs - 0.3):.2f}:d=0.3",
               "-ar", "44100", "-ac", "1", out])
    SFX[name] = (None, secs, 1.0)
    return name


def sound(key):
    """(name usable by finish.mix_audio, seconds): library first, synthesized fallback."""
    key = ALIAS.get(key, key)
    dur = NEW_SFX[key][0] if key in NEW_SFX else SFX[key][1]
    got = lib_file(key, dur)
    if got:
        return got, dur
    return (key, make_sfx(key, 0)) if key in NEW_SFX else (key, SFX[key][1])


def cues():
    t = lambda i: (E[i]["frame"] - 1) / FPS  # noqa: E731  (same frame the picture keys on)
    end = END_F / FPS
    out = [(0.0, "wind", round(end, 1), 0.3)]
    if "heart_on" in E and "heart_off" in E:
        hb_a, hb_b = t("heart_on"), t("heart_off")
        out.append((hb_a, "heartbeat", round(hb_b - hb_a, 1), 0.25))
    for e in EV:
        if e["sound"]:
            name, secs = sound(e["sound"])
            out.append((t(e["id"]), name, secs, e["gain"] * (0.5 if e["sound"] == "stinger_soft" else 1)))
    # footsteps on the shots where someone walks: (line, from, to seconds into the shot, gain)
    sh = {x["line"]: x for x in shots}
    step, secs = sound("step")
    for line, a, b, g in WALKS:
        k = sh[line]["start"] + a
        while k < min(sh[line]["start"] + b, sh[line]["end"] - 0.1):
            out.append((round(k, 3), step, secs, g))
            k += 0.47
    return out


def polish_voice():
    """Voice polish: cut rumble, a little warmth, tame 's' sounds, gentle compression. Keeps the raw take once."""
    nar, raw = FIN / "narration.mp3", FIN / "narration_raw.mp3"
    if not raw.exists():
        nar.rename(raw)
    F.run([F.FF, "-y", "-i", raw, "-af", "highpass=f=80,equalizer=f=220:t=q:w=1:g=2,equalizer=f=3500:t=q:w=1.2:g=1.5,"
           "deesser=i=0.4,acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120:makeup=2", "-codec:a", "libmp3lame", "-qscale:a", "2", nar])


def audio():
    end = END_F / FPS
    polish_voice()
    raw0 = F.mix_audio(HERE, cues(), True, end, FIN / "mix_raw.wav")
    raw = FIN / "mix_lim.wav"  # gentle limiter: voice peaks were capping the loudness at -16.8 LUFS
    F.run([F.FF, "-y", "-i", raw0, "-af", "alimiter=limit=0.5:attack=5:release=60:level=disabled", raw])
    i, tp = F.loudness(raw)
    gain = min(F.TARGET_I - i, F.TARGET_TP - tp)
    F.run([F.FF, "-y", "-i", raw, "-af", f"volume={gain:.2f}dB", "-ar", str(SR), "-c:a", "pcm_s16le", FIN / "full_audio.wav"])
    print(f"mix {i:.1f} LUFS / {tp:.1f} dBTP, fixed gain {gain:+.2f} dB -> {FIN / 'full_audio.wav'}")


def flash_time(take):
    """Seconds into the recording where the white sync flash starts (story t = flash + 0.5)."""
    r = subprocess.run([F.FF, "-i", take, "-vf", "scale=27:48,signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    ys = [float(x) for x in re.findall(r"YAVG=([\d.]+)", r)]
    i = next(k for k, y in enumerate(ys) if y > 200)
    return i / FPS


# The take is Studio's WHOLE landscape viewport. The Short is the centre 9:16 strip the camera framed for, exported at 1440x2560
# (YouTube gives 1440p+ uploads a better codec and more bitrate).
def crops(take):
    """The 9:16 crop computed from the take's real resolution (the camera composes for the same strip, from ViewportSize)."""
    W, H = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                    "-of", "csv=p=0", take], capture_output=True, text=True).stdout.strip().split(",")[:2])
    # Studio's Play-mode device toolbar ("Current device / Wifi / Auto") can sit on top of the viewport: the viewport is the BOTTOM
    # [CAMVP] h x2 rows of the take; crop the toolbar and the 2 px selection border off (the camera framed the strip for the viewport height)
    log = CAMLOG
    m = re.search(r"\[CAMVP\] (\d+) (\d+)", log.read_text()) if log.exists() else None
    vh = int(m.group(2)) * 2 if m else H
    off = H - vh if H - vh > 8 else 0
    Hs = H - off - (8 if off else 0)
    sw = round(Hs * 9 / 16) // 2 * 2
    return {"full_video.mp4": f"crop={sw}:{Hs}:{(W - sw) // 2}:{off + (4 if off else 0)},scale=1440:2560:flags=lanczos"}


NUMBERS = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"}   # numbers get a coloured caption


def captions():
    """ONE-WORD CAPTIONS: each spoken word alone, lower middle of the 1440x2560 frame, timed from words_full.json (never raw Whisper)."""
    words = json.loads((HERE / "words_full.json").read_text())
    lines = [l.strip() for l in (HERE / "script.txt").read_text().splitlines() if l.strip()]
    flat = []   # (start, line speech end, shown word)
    for sh in shots:
        n = sh["line"]; toks = lines[n - 1].replace("*", "").split(); ws = words[str(n)]
        assert len(toks) == len(ws), f"line {n}: {len(toks)} script words, {len(ws)} timed"
        end = sh["start"] + sh["lead"] + (sh["say"][1] - sh["say"][0])
        flat += [(t, end, tok.strip('",.:;')) for tok, (_, t) in zip(toks, ws)]

    def ts(t):
        c = max(0, round(t * 100))
        return f"{c // 360000}:{c // 6000 % 60:02d}:{c // 100 % 60:02d}.{c % 100:02d}"

    head = """[Script Info]
ScriptType: v4.00+
PlayResX: 1440
PlayResY: 2560
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: W,Arial Black,138,&H00FFFFFF,&H00FFFFFF,&H00101010,&H90000000,-1,0,0,0,100,100,0,0,1,11,5,2,60,60,720,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    out = []
    for i, (t, end, w) in enumerate(flat):
        stop = min(end + 0.12, flat[i + 1][0] if i + 1 < len(flat) else end + 0.4, t + 1.0)
        colour = "{\\c&H3CE6FF&}" if w.lower().strip("?!") in NUMBERS else ""
        out.append(f"Dialogue: 0,{ts(t)},{ts(max(stop, t + 0.08))},W,,0,0,0,,{{\\fscx118\\fscy118\\t(0,90,\\fscx100\\fscy100)}}{colour}{w.upper()}")
    f = FIN / "captions.ass"
    f.write_text(head + "\n".join(out) + "\n")
    return f


# Picture lags the audio clock by a fixed amount (measured 0.22-0.40 s on different takes). After assembly, compare the scene-cut
# times with beats.json: the median lag must be ~0 (within +-0.05 s). If not, change SYNC_LAG (env) and re-run "video".
SYNC_LAG = float(os.environ.get("SYNC_LAG", "0.40"))


def video():
    take = FIN / "take.mp4"
    cap = captions() if os.environ.get("CAPTIONS", "1") != "0" else None
    if cap and " ass " not in subprocess.run([F.FF, "-hide_banner", "-filters"], capture_output=True, text=True).stdout:
        print("WARNING: captions skipped: this ffmpeg has no libass. Install one that has it (macOS: brew install ffmpeg-full) "
              "and set FFMPEG=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg, then re-run video.")
        cap = None
    t0 = flash_time(take) + 0.5 + SYNC_LAG
    end = END_F / FPS
    look = "vignette=PI/10,eq=contrast=1.04:saturation=1.05,format=yuv420p"   # no film grain: YouTube turns it into blotches
    # BLINK FIX: DirectorCam logs "[REPLAN] key cut=<s> t=<s>" when a shot's first frames aimed at a stale spot.
    # Replace those frames with the first good one (freezeframes), so nothing flashes at the cut.
    log = CAMLOG   # written by DirectorCam through the bridge
    if not log.exists(): print(f"WARNING: no camera log at {log}: no toolbar crop or blink fix")
    fixes = []
    if log.exists():
        for cut, t in re.findall(r"\[REPLAN\] \S+ cut=([\d.]+) t=([\d.]+)", log.read_text()):
            a, b = round(float(cut) * FPS), round(float(t) * FPS) + 1
            if 0 <= a <= b < END_F - 1 and b - a <= 15:
                fixes.append((a, b))
    print(f"blink fix: {len(fixes)} cut(s) cleaned")
    for name, crop in crops(take).items():
        g, cur = [], "[0:v]"
        for i, (a, b) in enumerate(fixes):
            g.append(f"{cur}split[x{i}][y{i}];[x{i}][y{i}]freezeframes=first={a}:last={b}:replace={b + 1}[f{i}]")
            cur = f"[f{i}]"
        g.append(f"{cur}{crop},{look}" + (f",ass={cap}" if cap else "") + "[vout]")
        F.run([F.FF, "-y", "-ss", f"{t0:.3f}", "-t", f"{end:.3f}", "-i", take, "-i", FIN / "full_audio.wav",
               "-filter_complex", ";".join(g), "-map", "[vout]", "-map", "1:a", "-r", str(FPS),
               "-c:v", "libx264", "-preset", "slow", "-crf", "15",
               "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-t", f"{end:.3f}", "-movflags", "+faststart", HERE / name])
        print(HERE / name, f"story starts {t0:.2f}s into the take, {end:.2f}s long")


def music():
    """Score about 13 dB under the voice, side-chain ducked (a -10 dB / 4:1 mix left it inaudible). If the timeline has
    heart_on/heart_off, make sure score.py does not also play a pulse there (two heartbeats at once)."""
    F.run([F.FF, "-v", "error", "-y", "-i", HERE / "full_video.mp4", "-i", FIN / "score.wav", "-filter_complex",
           "[0:a]asplit=2[v][sc];[1:a]volume=-3dB[m];[m][sc]sidechaincompress=threshold=0.1:ratio=2:attack=20:release=300[d];"
           "[v][d]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.89:level=disabled[a]",
           "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-ar", str(SR), "-movflags", "+faststart",
           HERE / "full_video_with_music.mp4"])
    print(HERE / "full_video_with_music.mp4")


if __name__ == "__main__":
    {"audio": audio, "video": video, "music": music}[sys.argv[1]]()
