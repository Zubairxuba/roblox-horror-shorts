# Roblox Horror Shorts: an AI YouTube Shorts maker for Claude Code + Roblox Studio

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill%20%2B%20plugin-8A63D2)
![Roblox Studio MCP](https://img.shields.io/badge/Roblox%20Studio-MCP-E2231A)

A [Claude Code](https://claude.com/claude-code) skill that turns a story idea into a finished **vertical 9:16 animated
horror Short** (under 2 minutes), filmed inside **Roblox Studio** through the Roblox Studio MCP. Claude writes the
script, voices it, builds one timeline for picture and sound, and casts and dresses the scene. It stages every line
in Luau, rehearses, films the take, and mixes the sound and an original score.

> Ask Claude: *"make a Roblox horror short about a town where you must never answer the second knock"*.
> You approve the script. Claude builds and rehearses it, asks you once before filming your screen, and delivers the
> video plus upload notes.

## Features
- **Story to video, one approval:** 3 premises with titles, then a hook-first twist script: line 1 is a strange event
  with a number and a physical danger, the rule comes in lines 2-3, then a number ladder, clues, a planted twist and a
  circular ending question. `script_lint.py` checks every draft. After you approve it, Claude needs nothing more from
  you until the take.
- **Classic blocky actors with bold drawn faces:** a starter cast of recurring regulars built from Roblox catalog
  items (`cast_classic.lua`). Faces change per line (19 drawn presets), and the mouth flaps while a character talks.
  AI-generated actors with moving 3D faces and real lip sync are optional.
- **A real-looking starter set:** a textured street with clapboard houses, mesh trees, lawns and power lines, and a
  second row of houses so the street recedes. Every story set is a rebuildable Luau module with hidden focus marks.
- **Acting that never freezes:**
  - animation packs and 36 emotes;
  - a joint-level pose library (pockets, flinch, look back, carry, knock, hug staging);
  - always-on breathing, and listeners who turn to whoever is talking;
  - text-generated acting clips for story beats.
- **Automatic cinematic camera:**
  - a new shot every ~1.05 s beat, composed for the 9:16 strip;
  - sizes from extreme close-up to wide, with room above the hat (a head never fills more than 28% of the frame);
  - angles that follow the story beat (low for threats, dutch for the twist);
  - eased moves such as push-in, track, orbit, tilt-up reveal and a snap zoom on the scare;
  - a 180-degree rule, occlusion checks that rotate around poles and trees, and hand-keyed shots when you need them.
- **Light with a source:** shadows on; day, dusk and night looks with visible lamps; one look per story time;
  brightness targets per look.
- **Picture and sound in sync:** everything runs on one story clock built from the narration's word timings. A white
  sync flash lines the screen recording up with the audio.
- **QA gates:**
  - a per-shot camera log (framing, face size, occlusion, speed, shot mix, missing cameras, blank screens);
  - frozen-frame and motion checks;
  - contact sheets per beat from free Studio rehearsals, reviewed before the real take;
  - a pre-flight check that catches an expired Studio login, which otherwise makes characters invisible.
- **Privacy-guarded recording:** a take only runs after you say you are ready. It refuses if a microphone is in use
  or the screen is locked, and deletes the take if any other app comes to the front.
- **Sound:** your own licensed library or synthesized effects on event frames, an original score written in code and
  ducked under the voice, and a -14 LUFS mix. Roblox audio is never used.
- **Ready to upload:** a 1440x2560 Short with one-word captions, plus `upload.txt` (title + emoji, teaser line, tags,
  category).

## How it works
```
script.txt ──► voice.py ──► timeline.py ──► events.json + shots.json ──► make_timeline_lua.py ──► Timeline.lua
                                                                                    │
     cast_classic.lua + sets/street.lua ──► workspace          Part.lua (one table per line: staging + beats)
                                                                                    │
                     Roblox Studio (Play): Director runs each line on time, DirectorCam frames each beat
                                                                                    │
     video_capture rehearsal ──► qa_take.py / motion_qa.py / dry_sheet.py ──► review + fixes
                                                                                    │
     READY=yes auto_take.sh (screen recording) ──► assemble.py audio / video / music ──► full_video*.mp4
```

## Install
As a Claude Code plugin:
```
/plugin marketplace add Zubairxuba/roblox-horror-shorts
/plugin install roblox-horror-shorts@roblox-horror-shorts
```
Or copy just the skill: `cp -r skills/roblox-horror-shorts ~/.claude/skills/`

## Requirements
- **Roblox Studio** with the **Roblox Studio MCP** connected to Claude Code. Use a fresh Baseplate place saved to a
  file. `generate_mesh` / `generate_animation` are used when available (optional).
- **macOS** for the hands-free recorder: `ffmpeg` with avfoundation + `h264_videotoolbox`, and `swiftc` (Xcode
  command line tools) for the mouse parker. Other platforms: record the viewport your own way and keep the white sync
  flash.
- **ffmpeg** with `libass` for the captions (plain Homebrew ffmpeg lacks it: `brew install ffmpeg-full` and set
  `FFMPEG=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg`; the `rubberband` filter is optional, else `atempo` is used) and
  [whisper.cpp](https://github.com/ggml-org/whisper.cpp) `whisper-cli` with `ggml-base.en.bin` (set `WHISPER_MODEL`).
- **Python 3.10+:** `pip install -r skills/roblox-horror-shorts/requirements.txt`.
- **A narrator voice** you own or have permission to clone (a clean 10-20 s wav).
- Optional: a folder of licensed sound effects (Sonniss GDC, Freesound CC0) as `SFX_LIBRARY`. Without it every effect
  is synthesized.

## First run
1. Make a work folder and copy the kit into it:
   `mkdir -p roblox/src projects && cp skills/roblox-horror-shorts/roblox/*.lua skills/roblox-horror-shorts/roblox/sets/*.lua roblox/src/`.
2. Start the local bridge there: `python3 skills/roblox-horror-shorts/pipeline/bridge.py`. It listens on 127.0.0.1 only.
3. Ask Claude to set up Studio. It runs `setup.lua` (Director, camera, kit modules, folders, light and recording
   settings), then `cast_classic.lua` (the starter cast), then builds the starter street.
4. Measure Studio's viewport on screen and keep it as `VIEW=w:h:x:y` for the recorder.

Then ask for a Short. The skill's [SKILL.md](skills/roblox-horror-shorts/SKILL.md) is the full workflow Claude follows.

## FAQ
**Can I monetize the videos?** The stories, voice and sound are yours. The skill never uses Roblox audio, which is
licensed for use inside Roblox only. Whether Roblox's Terms of Use allow AI-generated avatars and Creator Store models
in monetized videos outside Roblox is **not verified** here. Read them before you monetize.

**Does it need paid AI credits?** No paid APIs in the pipeline. The voice and timing run locally. Mesh, avatar and
animation generation run in your own Roblox Studio.

**Can I make other genres?** Yes. The kit (actors, faces, camera, QA) is genre-free; the story rules are tuned for
twist horror.

## Repository layout
```
.claude-plugin/              plugin + marketplace manifests
skills/roblox-horror-shorts/
  SKILL.md                   the workflow Claude follows (one approval: the script)
  references/                production rules, Part file format + K API, Roblox engine notes
  roblox/                    Luau kit: Kit, Framer, DirectorCam, Director, setup, cast_classic, cast_ai, example part
  roblox/sets/               starter street set (textured houses, mesh trees, a street that recedes)
  pipeline/                  voice, timeline, beats -> Timeline.lua, score, lip sync, assemble, local bridge
  qa/                        script lint, camera-log QA, motion QA, contact sheets
  record/                    privacy-guarded macOS screen recorder
```

Sister project (Blender instead of Roblox): [blocky-horror-shorts](https://github.com/Zubairxuba/blocky-horror-shorts).

License: MIT (see [LICENSE](LICENSE); notes in [NOTICE.md](NOTICE.md)).
