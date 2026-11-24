# Roblox Horror Shorts: an AI YouTube Shorts maker for Claude Code + Roblox Studio

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill%20%2B%20plugin-8A63D2)
![Roblox Studio MCP](https://img.shields.io/badge/Roblox%20Studio-MCP-E2231A)

A [Claude Code](https://claude.com/claude-code) skill that turns a story idea into a finished **vertical 9:16 animated
horror Short** (under 2 minutes), filmed inside **Roblox Studio** through the Roblox Studio MCP. Claude writes the
script, voices it, builds one timeline for picture and sound, and generates the actors. It stages every line in Luau,
films the take and mixes the sound.

> Ask Claude: *"make a Roblox horror short about a town where you must never answer the second knock"*.
> You approve the script. Claude builds, films and delivers the video plus upload notes.

## Features
- **Story to video, one approval:** a hook-first twist script (rule + danger in line 1, cold-open image, clues,
  twist, callback ending). After you approve it, Claude needs nothing more from you.
- **AI actors with moving faces:** `generate_avatar` with dynamic heads gives every character a FaceControls face.
  The kit has expression presets (scared, worried, grin...) and **real lip sync** from your narration's loudness and
  timbre.
- **Acting that never freezes:**
  - animation packs per character, and 36 emotes;
  - a joint-level pose library (hands in pockets, flinch, look back);
  - always-on breathing;
  - text-generated acting clips for story beats.
- **Automatic cinematic camera:**
  - a new shot every ~1.1 s beat, composed for the 9:16 strip;
  - sizes from extreme close-up to wide, and angles that follow the story beat (low for threats, dutch for the twist);
  - eased moves such as push-in, track, orbit, tilt-up reveal and a snap zoom on the scare;
  - a 180-degree rule, plus occlusion checks that rotate the camera around poles and trees.
- **Picture and sound in sync:** everything runs on one story clock built from the narration's word timings. A white
  sync flash lines the screen recording up with the audio.
- **QA gates:**
  - a per-shot camera log (framing, face size, occlusion, speed and shot mix);
  - frozen-frame and motion checks;
  - contact sheets per beat;
  - a pre-flight check that catches an expired Studio login, which otherwise makes characters invisible.
- **Light moods without extra lamps:** calm, uneasy, scare and aftermath blend across lines. Shadows are off and the
  ground is plain, so characters read on a phone.
- **Sound:** your own licensed library or synthesized effects on event frames, then a -14 LUFS mix. Roblox audio is
  never used.
- **Ready to upload:** `Finalized_videos/<title>/full_video.mp4` plus `upload.txt` (title + emoji, teaser line, tags).

## How it works
```
script.txt ──► voice.py ──► timeline.py ──► events.json + shots.json ──► make_timeline_lua.py ──► Timeline.lua
                                                                                    │
     generate_avatar ──► cast_ai.prep ──► workspace.Cast         Part.lua (one table per line: staging + beats)
                                                                                    │
                     Roblox Studio (Play): Director runs each line on time, DirectorCam frames each beat
                                                                                    │
            auto_take.sh (screen recording) ──► qa_take.py / motion_qa.py ──► assemble.py ──► full_video.mp4
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
  file. `generate_avatar` / `generate_animation` must be available in your Studio.
- **macOS** for the hands-free recorder: `ffmpeg` with avfoundation + `h264_videotoolbox`, and `swiftc` (Xcode
  command line tools) for the mouse parker. Other platforms: record the viewport your own way and keep the white sync
  flash.
- **ffmpeg** and [whisper.cpp](https://github.com/ggml-org/whisper.cpp) `whisper-cli` with `ggml-base.en.bin` (set
  `WHISPER_MODEL`).
- **Python 3.10+:** `pip install -r skills/roblox-horror-shorts/requirements.txt`.
- **A narrator voice** you own or have permission to clone (a clean 10-20 s wav).

## First run
1. Make a work folder and copy the kit into it: `mkdir -p roblox/src projects && cp skills/roblox-horror-shorts/roblox/*.lua roblox/src/`.
2. Start the local bridge there: `python3 skills/roblox-horror-shorts/pipeline/bridge.py`. It listens on 127.0.0.1 only.
3. Ask Claude to run `roblox/src/setup.lua` in Studio. It installs the Director, the camera, the kit modules, the
   folders and the recording settings.
4. Measure Studio's viewport on screen and set `VIEW` in `record.sh`.

Then ask for a Short. The skill's [SKILL.md](skills/roblox-horror-shorts/SKILL.md) is the full workflow Claude follows.

## FAQ
**Can I monetize the videos?** The stories, voice and sound are yours. The skill never uses Roblox audio, which is
licensed for use inside Roblox only. Whether Roblox's Terms of Use allow AI-generated avatars and Creator Store models
in monetized videos outside Roblox is **not verified** here. Read them before you monetize.

**Does it need paid AI credits?** No paid APIs in the pipeline. The voice and timing run locally. Avatar and
animation generation run in your own Roblox Studio.

**Can I make other genres?** Yes. The kit (actors, faces, camera, QA) is genre-free; the story rules are tuned for
twist horror.

## Repository layout
```
.claude-plugin/              plugin + marketplace manifests
skills/roblox-horror-shorts/
  SKILL.md                   the workflow Claude follows (one approval: the script)
  references/                production rules, Part file format + K API, Roblox engine notes
  roblox/                    Luau kit: Kit, Framer, DirectorCam, Director, cast_ai, setup, example part
  pipeline/                  voice, timeline, beats -> Timeline.lua, lip sync, assemble, local bridge
  qa/                        camera-log QA, motion QA, contact sheets
  record/                    hands-free macOS screen recorder
```

Sister project (Blender instead of Roblox): [blocky-horror-shorts](https://github.com/Zubairxuba/blocky-horror-shorts).

License: MIT (see [LICENSE](LICENSE); notes in [NOTICE.md](NOTICE.md)).
