---
name: roblox-horror-shorts
description: Turn a story idea into a finished vertical (9:16) animated horror Short under 2 minutes, filmed in Roblox Studio through the Roblox Studio MCP - hook-first script with a lint, voice, one synced timeline for picture and sound, classic blocky actors with bold drawn faces, a textured starter set, an automatic cinematic camera with QA, a rehearsal review, a guarded screen-recorded take, synthesized SFX, an original score, one-word captions and upload notes. Use for "make a Roblox horror short", "Roblox story animation", "animated Roblox Short", or continuing a project made with this skill.
license: MIT
---

# Roblox Horror Shorts

You are the **director**. You write the script, voice it, build the timeline, stage every line as Luau in Roblox Studio
(through the Roblox Studio MCP), rehearse, film, mix the sound and deliver the Short. The camera is automatic: you say
WHO or WHAT a beat is about, and the kit frames it for the 9:16 strip, checks occlusion and logs QA.

Skill files (use these exact paths):
- Studio kit (Luau): `${CLAUDE_SKILL_DIR}/roblox/` - `Kit.lua` (actors, walks, emotes, poses, drawn faces, talking,
  light looks, signs, props), `Framer.lua` (shot maths), `DirectorCam.client.lua` (the camera driver + QA log),
  `Director.server.lua` (runs each line on time), `setup.lua` (one-time install), `cast_classic.lua` (the starter
  cast), `sets/street.lua` (a textured starter street), `example_part.lua` (the Part file format), `cast_ai.lua`
  (optional AI actors), `Lips.lua` (empty lip-sync store).
- Pipeline (Python): `${CLAUDE_SKILL_DIR}/pipeline/` - `voice.py` (Chatterbox, a voice you own), `finish.py` (Whisper
  timing, SFX, loudness), `timeline.py` + `assemble.py` + `score.py` (per-video templates), `make_timeline_lua.py`
  (beats -> Timeline.lua), `lips.py` (lip-sync data for AI heads), `bridge.py` (local file bridge for Studio).
- QA: `${CLAUDE_SKILL_DIR}/qa/` - `script_lint.py` (hook rules), `qa_take.py` (camera log + take), `motion_qa.py`
  (frozen frames), `dry_sheet.py` / `sheet_sme.py` (frames per beat), `strip_sheet.sh` (time-ordered sheet).
- Recording (macOS): `${CLAUDE_SKILL_DIR}/record/` - `auto_take.sh` (guarded take), `record.sh`, `wait_idle.sh`,
  `show_studio.sh`, `parkmouse.swift`.
- Rules you must follow: [references/production-rules.md](references/production-rules.md) (story, must-haves, cast,
  camera, QA, recording, sound, delivery, lessons) and [references/part-format.md](references/part-format.md) (Part
  files + K API). Engine facts and test results: [references/roblox-api-notes.md](references/roblox-api-notes.md).

## Files, network and privacy (security notes)
- `pipeline/bridge.py` serves the work folder on **127.0.0.1:8765 only**, so Studio's HttpService can pull Luau
  sources and push the camera log. Reads and writes are limited to `roblox/` and `projects/` inside the work folder,
  writes to `.txt`/`.lua`/`.json` files, and browser requests (Origin header) or foreign Host names are refused.
- `pipeline/voice.py` downloads the Chatterbox model weights on first use. Nothing else makes network calls.
- Studio actions (`execute_luau`, `insert_asset`, `generate_mesh`, `generate_animation`) run through the user's own
  Roblox Studio MCP. Inserted Creator Store models can contain scripts: **destroy every LuaSourceContainer inside
  them**, and remove brand or company names from their signs.
- **A take films the whole real screen.** Only after the user says they are ready, run it with `READY=yes`; the script
  refuses while a microphone is in use (a call), the screen is locked, or another app comes to the front, and deletes
  that take. Never open a take it did not call VALID.

## The one approval
**Only the script needs the user's OK.** After "approved" build everything without more questions: voice, timeline,
cast, sets, Part files, rehearsal, review, sound and delivery. Hard limits stay: never upload anywhere, never clone a
voice the user has not confirmed they own, and ask the user right before the real take (it films their screen).

## 0. Setup (first run only)
Check and report what is missing; do not install system software without asking:
- Roblox Studio with the Studio MCP connected (`list_roblox_studios`). A fresh Baseplate place, saved to a file
  (`roblox/Stage.rbxl`); back it up before each build. Studio > File > Studio Settings > Rendering: Edit and Play
  Quality Level 21 (not Automatic).
- `ffmpeg` with `h264_videotoolbox` (macOS), `libass` (captions) and `rubberband` (voice tempo; optional). Plain
  Homebrew ffmpeg lacks both: `brew install ffmpeg-full` and set `FFMPEG=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg`; `whisper-cli` (whisper.cpp) with
  `ggml-base.en.bin` (set `WHISPER_MODEL`), Python 3.10+ with `pip install -r ${CLAUDE_SKILL_DIR}/requirements.txt`,
  `swiftc` (Xcode command line tools) for the mouse parker.
- A work folder (the cwd) with `roblox/src/` and `projects/`. Copy `${CLAUDE_SKILL_DIR}/roblox/*.lua` and
  `${CLAUDE_SKILL_DIR}/roblox/sets/*.lua` to `roblox/src/`.
- Start the bridge in the work folder: `python3 ${CLAUDE_SKILL_DIR}/pipeline/bridge.py` (background).
- In Studio (Edit) run `roblox/src/setup.lua` with `execute_luau`. loadstring is off, so fetch it with
  `HttpService:GetAsync("http://127.0.0.1:8765/roblox/src/setup.lua")` into a temporary ModuleScript's `.Source`,
  `require` it, then delete the module. It installs Kit/Framer/Lips/Street in ReplicatedStorage, Director in
  ServerScriptService, DirectorCam in StarterPlayerScripts, makes `workspace.Cast/Set/FX`, `ReplicatedStorage.Parts`,
  `ServerStorage.Props`, the light effects (shadows on) and the recording settings (no avatar, no streaming, every
  Roblox Sound muted).
- Run `roblox/src/cast_classic.lua` the same way (the starter cast: Sam, Juno, Leo, Mom, Kid1-4), then build the
  starter street: `require(game.ReplicatedStorage.Street:Clone()).build()`. Save the place.
- Pre-flight once: `pcall(MarketplaceService.GetProductInfo, MarketplaceService, 376548738)` must succeed (else the
  Studio login expired: save, log out/in, reopen).
- Measure Studio's 3D viewport on screen in Play (one full-screen grab; it has a blue border) and remember it as
  `VIEW="w:h:x:y"` (width <= 4096: the hardware encoder fails above that). Re-measure whenever panels or the window move.
- Make `IMPROVEMENTS.md` in the work folder (production-rules section 10).

## 1. Script -> the only approval
Read `Finalized_videos/` (don't repeat a premise). Write 3 one-line premises, each with its title, then the full script
for the best one, following [production-rules.md](references/production-rules.md) section 1: under 2:00 (about 38-42
lines), line 1 = a strange event that already happened + a number + physical danger (the rule comes in lines 2-3), a
cold-open image, show-what-the-words-say beats, a number ladder, a planted clue paid off in the twist, a resolution +
epilogue, an ending question and a callback to line 1. Save it as `projects/<slug>/script_draft.txt` and run
`python3 ${CLAUDE_SKILL_DIR}/qa/script_lint.py projects/<slug>/script_draft.txt`; fix every FAIL before showing it.
Add the cast list (reuse the regulars; for each: role, hair/hat, outfit with one signature colour, skin, face style,
voice), the sets (reuse the street where the story fits) and the twist. Wait for "approved".

## 2. Voice + timeline
- Project folder `projects/<slug>/` with `script.txt` (one line per shot). Copy `timeline.py`, `assemble.py` and
  `score.py` there and run them with `SHORTS_PIPELINE=${CLAUDE_SKILL_DIR}/pipeline` set (they import `finish.py`).
- `python ${CLAUDE_SKILL_DIR}/pipeline/voice.py projects/<slug> --ref <voice.wav>` -> `narration.mp3` + `timings.json`.
  Defaults trim Chatterbox's silences and speed the track up 1.25x: ~4.5 words/s. Per-line emotion or a second voice:
  `voices.json` (see the file header). Listen to the result before building on it.
- Edit `timeline.py`: `EXTRA` (short silences for on-screen beats the voice doesn't cover, <= 0.3 s, ~6 per video) and
  `events()` (every synced sound, times only from words or line ends). Run it, then
  `python ${CLAUDE_SKILL_DIR}/pipeline/make_timeline_lua.py` in the project -> `Timeline.lua` (~1.05 s beats) + `beats.json`.

## 3. Cast + set
- **Cast:** the regulars from `cast_classic.lua` (Production rules section 3). New characters: copy a row in your
  work copy of `cast_classic.lua` (catalog texture ids, verified with GetProductInfo), re-run it, check one still per
  actor (outfit contrast, face readable). Hide name tags. Hero: `workspace:SetAttribute("Hero", "Sam")`; a villain gets
  attribute `Threat = true` (low angles) and readable clothes (an all-black figure is unreadable up close).
- **Set:** start from the starter street when the story fits. A new place is its own builder module
  `roblox/src/<Name>.lua` (ReplicatedStorage.<Name>: `build()` once in Edit into `workspace.Set.<Name>`, `reset()` at
  each line start, story functions such as `door(open)`), so it can be rebuilt any time. Follow must-haves 2 and 4
  (textured ground, real-looking houses/props, a background that recedes, lamps you can see for dusk/night). Creator
  Store props: `search_asset` + `insert_asset`, free models only, every script destroyed, into `ServerStorage.Props`
  (`K.prop`). Greenery: `generate_mesh` meshes into `ServerStorage.Scenery`. Hidden `FM_*` focus marks for every wall
  feature an insert films. Props with text are `K.sign` boards.
- Add a story look per story time to `K.LOOKS` if day/golden/dusk/night don't fit; check one still per look
  (brightness targets in must-have 2, no shadow over a face).

## 4. Part files (staging)
Write `projects/<slug>/part1/Part.lua` (one writer is enough; for long scripts up to 3 sub-agents with
`model: "sonnet"`, each writing only its own file and never touching Studio). Format and API:
[part-format.md](references/part-format.md), template `example_part.lua`. Every line: a `stage()` setup, a camera per
beat, an action and a face on every person shot, walks instead of teleports, 25-35% of the beats inserts of the
spoken object, a FOLLOW and a REVEAL per scene. Push `Timeline.lua`, `Lips.lua`, your set module and each Part into
Studio through the bridge (`execute_luau` + `HttpService:GetAsync` setting `.Source`; never paste).

## 5. Rehearsal + review (before any real take)
In Play, set workspace attributes `Project = "<slug>"`, `From = <segment start>` and
`Go = workspace:GetServerTimeNow() + 4`, then `video_capture` (max 30 s: segments From = 0, 25, 50, ...; restart Play
between segments). `video_capture` needs no idle Mac and works on a locked screen. Then:
- `python3 ${CLAUDE_SKILL_DIR}/qa/qa_take.py <segment> qa/camlog.txt` in the project
  (framing, occlusion, speed, shot mix, missing cameras, blank screens) and `.../qa/motion_qa.py <segment>`
  (<= 8% frozen frames, motion >= 3.5).
- `python3 ${CLAUDE_SKILL_DIR}/qa/dry_sheet.py qa/d s0.mp4@0 s25.mp4@25 ...` in the project: one frame per beat.
  A targeted reviewer sub-agent (`model: "opus"`) checks the hook, the twist, the ending and the QA-flagged beats on
  those sheets: sync with the words, faces readable with room above the hat, actions, no blocked or blank shots, light
  per scene. Read the Client/Server log for Luau errors. Fix, re-push, re-check the fixed spans.
- Most fails are staging: move the actor off the pole, give the beat a numeric angle, make the blocker transparent.

## 6. Real take
Pre-flight (production-rules section 6): Studio login OK, place saved, panels closed, quality 21, Studio restored and
in front (`record/show_studio.sh`), one still of the screen looks right, `[CAMVP]` matches `VIEW`. Copy the
`record/` scripts into the project. **Ask the user** for ~4 minutes hands-off with no call running; when they say
ready: `READY=yes VIEW=<w:h:x:y> projects/<slug>/auto_take.sh final/take.mp4 <story seconds + 6> 0` (Play running,
in the background). Afterwards grep the Studio output for "403" (invalid take), copy `qa/camlog.txt` to
`qa/camlog_take1.txt`, check `CAMQA` + `CAMKEY` lines = the beat count, and run `qa_take.py` + `motion_qa.py` on the take.

## 7. Sound, video, delivery
`python assemble.py audio` (voice polish, SFX on event frames from `SFX_LIBRARY` or synthesized, -14 LUFS),
`python assemble.py video` (finds the white sync flash, trims, cuts the 9:16 strip at 1440x2560, burns one-word
captions, fixes re-aim blinks), then check sync: scene-cut times vs beats.json, median within +-0.05 s (else set
`SYNC_LAG` and re-run). `python score.py` (rewrite its ARRANGEMENT for the story) and `python assemble.py music`.
Deliver to `Finalized_videos/<Title>/`: `full_video.mp4`, `full_video_with_music.mp4`, `background_music.mp3` (copy of
`final/score.mp3`) and `upload.txt` (title + one emoji, one-line teaser description, tags, category Gaming / Roblox;
production-rules section 8). Report length, loudness, QA numbers (frozen %, motion, brightness, s/shot, inserts %,
sync) and anything still weak. Remind the user to set the video Public. Never upload.

## 8. Improve after every video
Log the QA numbers and the user's feedback in `IMPROVEMENTS.md`, re-rank the backlog, and build the top item into the
kit (tested in Play) before the next video. The lessons in production-rules section 9 came from exactly this loop.
