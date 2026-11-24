---
name: roblox-horror-shorts
description: Turn a story idea into a finished vertical (9:16) animated horror Short under 2 minutes, filmed in Roblox Studio through the Roblox Studio MCP - script, voice, one synced timeline for picture and sound, AI-generated actors with moving faces and lip sync, an automatic cinematic camera with QA, a screen-recorded take, synthesized SFX and upload notes. Use for "make a Roblox horror short", "Roblox story animation", "animated Roblox Short", or continuing a project made with this skill.
license: MIT
---

# Roblox Horror Shorts

You are the **director**. You write the script, voice it, build the timeline, stage every line as Luau in Roblox Studio
(through the Roblox Studio MCP), film it, mix the sound and deliver the Short. The camera is automatic: you say WHO or
WHAT a beat is about, and the kit frames it for the 9:16 strip, checks occlusion and logs QA.

Skill files (use these exact paths):
- Studio kit (Luau): `${CLAUDE_SKILL_DIR}/roblox/` - `Kit.lua` (actors, walks, emotes, poses, faces, lip sync, light
  moods, signs, props), `Framer.lua` (shot maths), `DirectorCam.client.lua` (the camera driver + QA log),
  `Director.server.lua` (runs each line on time), `cast_ai.lua` (prepares AI actors), `setup.lua` (one-time install),
  `example_part.lua` (the Part file format), `Lips.lua` (empty lip-sync store).
- Pipeline (Python): `${CLAUDE_SKILL_DIR}/pipeline/` - `voice.py` (Chatterbox, your own voice), `finish.py` (Whisper
  timing, SFX, loudness), `timeline.py` + `assemble.py` (per-video templates), `make_timeline_lua.py` (beats ->
  Timeline.lua), `lips.py` (lip-sync data), `bridge.py` (local file bridge for Studio).
- QA: `${CLAUDE_SKILL_DIR}/qa/` - `qa_take.py` (camera log + take), `motion_qa.py` (frozen frames), `sheet_sme.py`
  (start/mid/end frames per beat), `strip_sheet.sh`.
- Recording (macOS): `${CLAUDE_SKILL_DIR}/record/` - `auto_take.sh`, `record.sh`, `wait_idle.sh`, `parkmouse.swift`.
- Rules you must follow: [references/production-rules.md](references/production-rules.md) (story, must-haves, cast,
  camera, QA, recording, sound, delivery) and [references/part-format.md](references/part-format.md) (Part files + K API).
  Engine facts and test results: [references/roblox-api-notes.md](references/roblox-api-notes.md).

## Files & network (security notes)
- `pipeline/bridge.py` serves the work folder on **127.0.0.1:8765 only**, so Studio's HttpService can pull Luau
  sources and push the camera log. Writes are limited to `roblox/` and `projects/` inside the work folder.
- `pipeline/voice.py` downloads the Chatterbox model weights on first use. Nothing else makes network calls.
- Studio actions (`execute_luau`, `generate_avatar`, `generate_animation`, `insert_asset`) run through the user's own
  Roblox Studio MCP. Inserted Creator Store models can contain scripts: **destroy every LuaSourceContainer inside them.**
- Recording films the whole screen: activate Studio first and delete any take that shows another app (it can contain
  private files).

## The one approval
**Only the script needs the user's OK.** After "approved" build everything without more questions: voice, timeline,
cast, sets, Part files, dry run, take, QA, sound and delivery. Hard limits stay: never upload anywhere, never clone a
voice the user has not confirmed they own, ask the user for an idle Mac before a real take.

## 0. Setup (first run only)
Check and report what is missing; do not install system software without asking:
- Roblox Studio with the Studio MCP connected (`list_roblox_studios`). Use a fresh Baseplate place, saved to a file.
- `ffmpeg` with `h264_videotoolbox` (macOS), `whisper-cli` + `ggml-base.en.bin` (set `WHISPER_MODEL`), Python 3.10+
  with `pip install -r ${CLAUDE_SKILL_DIR}/requirements.txt`, `rubberband` optional.
- A work folder (the cwd): `roblox/src/` and `projects/`. Copy `${CLAUDE_SKILL_DIR}/roblox/*.lua` to `roblox/src/`.
- Start the bridge in the work folder: `python3 ${CLAUDE_SKILL_DIR}/pipeline/bridge.py` (background).
- In Studio (Edit) run `roblox/src/setup.lua` with `execute_luau`. loadstring is off, so fetch it with
  `HttpService:GetAsync` into a temporary ModuleScript's `.Source`, `require` it, then delete the module. It
  installs Kit/Framer/Lips in ReplicatedStorage, Director in ServerScriptService, DirectorCam in StarterPlayerScripts,
  makes `workspace.Cast/Set/FX`, `ReplicatedStorage.Parts`, `ServerStorage.Props`, and the recording settings.
- Measure Studio's 3D viewport on screen (one full-screen grab; it has a blue border) and set `VIEW="w:h:x:y"` in
  `record.sh` (width <= 4096: the hardware encoder fails above that).

## 1. Script -> the only approval
Write 3 one-line premises, then the full script for the best one, following the story rules in
[production-rules.md](references/production-rules.md) section 1: under 2:00 (about 38-42 lines), line 1 = the rule AND
the danger, a strong cold-open image, show-what-the-words-say beats, a twist and a circular ending. Add the cast list
(name, role, look, signature colour, voice) and the sets. Check that the premise is not a near-copy of popular
channels' recent uploads. Wait for "approved".

## 2. Voice + timeline
- Project folder `projects/<slug>/` with `script.txt` (one line per shot). Copy `timeline.py` and `assemble.py` there and
  run them with `SHORTS_PIPELINE=${CLAUDE_SKILL_DIR}/pipeline` set (they import `finish.py` from it).
- `python ${CLAUDE_SKILL_DIR}/pipeline/voice.py projects/<slug> --ref <voice.wav> --pause 0.15` -> `narration.mp3` +
  `timings.json`. Target ~4.5 words/s: speed the narration up ~1.2x (rubberband keeps the pitch) if it runs slow.
- Edit `timeline.py`: `EXTRA` (short silences for on-screen beats the voice doesn't cover, <= 0.3 s, ~6 per video) and
  `events()` (every synced sound, times only from words or line ends). Run it, then
  `python ${CLAUDE_SKILL_DIR}/pipeline/make_timeline_lua.py` in the project -> `Timeline.lua` (~1.1 s beats) + `beats.json`.
- One lip-sync clip per spoken line: `python3 ${CLAUDE_SKILL_DIR}/pipeline/lips.py <clip> projects/<slug>/final/narration.mp3 <start> <end>`.

## 3. Cast + set
- Cast with `generate_avatar(textPrompt, pipelineName="npc", dynamicHead=true)`: about 6 min each, so start them the
  moment the script is approved. Then `cast_ai.lua` `prep(model, name, pack, scale, pos, faceTo)`. Rules in
  production-rules section 3 (signature colours, never rewrite the rig's attachments, no brand names in prompts).
- A small, sparse set on plain ground: only what the story names (sign, mailbox, door, clock). Keep it in a
  `roblox/src/set_<slug>.lua` so it can be rebuilt. Props with text are `K.sign` boards; Creator Store props go in
  `ServerStorage.Props` (scripts destroyed) and appear with `K.prop`.

## 4. Part files (staging)
Write `projects/<slug>/part1/Part.lua` (one writer is enough; up to 3 sub-agents with `model: "sonnet"` for long
scripts, each writing only its own file and never touching Studio). Format and API: [part-format.md](references/part-format.md).
Every line: a camera per beat, an action and a face on every person shot, walks instead of teleports, a third of the
beats inserts of the spoken object. Push `Timeline.lua`, `Lips.lua` and each Part into Studio through the bridge
(`execute_luau` + `HttpService:GetAsync` setting `.Source`; never paste).

## 5. Dry run + QA
In Play, set workspace attributes `Project = "<slug>"`, `From = 0` and `Go = workspace:GetServerTimeNow() + 4`, then
`video_capture` (max 30 s; segments From = 0, 25, 50 ..., restart Play between segments). Then:
- `python3 ${CLAUDE_SKILL_DIR}/qa/qa_take.py <segment or take> projects/<slug>/qa/camlog.txt` (framing, occlusion,
  speed, shot mix) and `.../qa/motion_qa.py <video>` (<= 8% frozen frames, motion >= 3.5).
- Most fails are staging: move the actor off the pole, give the beat a numeric angle, make the blocker transparent.
- A targeted reviewer sub-agent (`model: "opus"`) looks at `sheet_sme.py --beats` frames of the QA-flagged beats +
  the hook + the twist only.

## 6. Real take
Pre-flight (production-rules section 6): Studio login OK (`MarketplaceService:GetProductInfo` works), place saved,
Studio activated (`osascript -e 'tell application "RobloxStudio" to activate'`), one still of the screen looks right.
Ask the user for ~4 minutes hands-off, then `projects/<slug>/auto_take.sh final/take.mp4 <seconds> 0` (copy the
`record/` scripts into the project). Afterwards grep Studio output for "403" (invalid take) and check
`grep -c CAMQA qa/camlog.txt` equals the beat count.

## 7. Sound, video, delivery
`python assemble.py audio` (voice polish, SFX on event frames from your licensed library or synthesized, -14 LUFS),
`python assemble.py video` (finds the white sync flash, trims, cuts the 9:16 centre strip, fixes re-aim blinks).
Optional original music: score it in code and side-chain duck it under the voice. Deliver to
`Finalized_videos/<Title>/`: `full_video.mp4`, `full_video_with_music.mp4` (if scored) and `upload.txt` (title of
2-3 words + one emoji, a one-line teaser description, tags; production-rules section 8). Report length, loudness, QA
numbers and anything still weak. Never upload.

## 8. Improve after every video
Note what failed (QA numbers, user feedback) in a short log in the work folder and fix the top item in the kit before
the next video. The Lessons in production-rules section 9 came from exactly this loop.
