# Production rules (Roblox horror Shorts)

Every rule here came from a delivered video, a measurement or a failed take. Numbers were measured on our own videos
and on top Roblox story Shorts.

## 1. Story
- **Length:** under 2:00 (aim 1:45-1:55): about 38-42 lines, ~400 words. `LIMIT = 119.0` in `timeline.py`.
- **Hook rule:** line 1 = the rule AND the danger in one sentence ("...never answer the second knock"), never just the setting.
  Beat 1.1 is the strongest, scariest image of the video (a cold open), not a calm wide shot. Target >= 65-70%
  "stayed to watch" in YouTube analytics.
- **Format:** a "town where X" / "world where X" rule, a recurring hero, a best friend, clues, sharp escalation, a
  twist, a short resolution + epilogue, and a circular callback to line 1.
- **Written for cuts:** ~1.1 s visual beats. Write tangible things the camera can show (signs, clocks, props,
  numbers, names) and plan a face + an action per line.
- **Daylight stories:** the scare comes from staging, faces, sound and the twist, not darkness.
- Stories are original. Copy a reference channel's FORMAT (length, hook, pacing, title style), never its stories,
  lines or titles: YouTube's reused-content review rejects copies from monetization.

## 2. Must-haves for every Short
1. **Every shot moves.** Camera defaults: medium = push_in, full = orbit, inserts push. Never `static`/`hold` except
   the one held beat right before a scare. Characters move in at least 2 of every 3 shots (walk, run, turn, emote,
   pose); at most 1 shot in 5 is idle. Walk, don't teleport: `K.place` only for a scene's first beat and offstage,
   `K.walk` (speed 7-9, run 12-16) inside a scene. Each scene gets a FOLLOW shot (`move = "track"`) and a REVEAL
   (`move = "tilt_up"` onto what they look at). **Gate:** `motion_qa.py` <= 8% frozen frames, motion >= 3.5.
2. **Light theme.** Mood track per line: `look = "calm" | "uneasy" | "scare" | "aftermath"` (`blend = secs` to melt).
   Average brightness ~100-115, scare >= 92, <= 5% dark frames, bloom threshold >= 2.6 (no glowing skin or whites).
   No extra light objects.
3. **Visible characters.** Faces readable on a phone: sun behind or beside the camera, close/medium framing on every
   spoken line, wides at most 1 in 6. Stage in the open, never behind poles, fences or furniture. Every person shot
   plays an action AND a face that match the words; the scare and the twist get the biggest face.
4. **No shadows, plain ground.** `GlobalShadows = false` (every `K.look` does it) and `CastShadow = false` on the
   set. Plain, evenly lit ground under the characters, a colour that differs from clothes and skin. Dress only what
   the story names; list it in `SET_KEEP` and the Director hides the rest at Play start.

## 3. Cast: AI actors with moving faces
- **Create:** `generate_avatar(textPrompt, pipelineName="npc", dynamicHead=true)` -> an R15 actor with FaceControls.
  ~6 min each: start them in the background as soon as the script is approved. The MCP call often reports "Request
  timeout" while the model still arrives: check `workspace` before retrying. No brand or trademark names in prompts
  (moderation blocks them). AI models cannot draw letters: put a logo/letter on a welded Part with a SurfaceGui.
- **Prep:** `cast_ai.lua` `prep(model, name, pack, scale, pos, faceTo)` fixes the far-away pivot, turns it to face +Z,
  scales (the AI adult is 6 studs; kids ~0.8) and parents it to `workspace.Cast`.
- **Never rewrite the rig's RigAttachments.** Its A-pose rest is correct; catalog idles and emotes play fine.
- **Outfits:** one signature colour per character, light or neutral pants, no black bottoms, no neon. Two characters
  never share a colour in a scene. Dark outfits on a dark background disappear.
- **Pack:** each actor's `Pack` attribute picks its walk/idle set (`K.PACKS`: cartoony, stylish, rthro, bubbly,
  elder, zombie). Emotes and acting clips play at Action priority over it. Pack actors don't fidget.
- **Faces:** `K.face(name, preset, fade)` (presets in `K.FACES`), applied on the client through attributes
  (FaceControls don't replicate).
- **Lip sync:** one `lips.py` clip per spoken line; `K.talk(name, secs, clip)` at the line start. Without a clip the
  jaw flaps.
- **Story actions the emotes can't do:** `generate_animation(textPrompt, instance_path="Workspace.Cast.<Name>")` on the
  untouched rig; put the returned id in `K.ANIM` in your part. Generated ids belong to your account.
- **Head turns:** `K.pose(name, "lookback")` + eye controls. IKControl is untested on these rigs.

## 4. Camera (automatic, vertical first)
Code: `Framer.lua` (shot maths) + `DirectorCam.client.lua` (driver). Parts never place the camera by hand.
- Every shot is composed for the centred 9:16 strip of the recorded viewport (4% margin). The camera is a pure
  function of the story clock, so every retake is identical and in sync with the voice.
- **Sizes:** `extreme` (face fills the frame, ~45%), `close` (chest-up, face ~28%), `medium`, `full`, `wide`,
  `insert` (the object, text readable). Distance from size: `dist = (subjectHeight / frac) / (2 tan(vFOV/2))`.
  Scares and the twist turn a single person's `close` into `extreme` automatically; close-ups are capped at ~25%.
- **Angles:** eye_level, three_quarter, low (threats, hero moments), high (hero scared), ots (two people facing
  each other 2.5-9 studs apart), dutch (twist/panic, max 3). Chosen from the beat type when left blank. 180-degree
  rule per scene; never the same angle + size more than 3 times in a row. A numeric `angle` is kept exactly.
- **Moves:** push_in, pull_out, track, orbit (<= 15 deg), tilt_up (reveal), snap_zoom (on the scare sound), static,
  hold. Speed cap 6 studs/s; a faint handheld sway on every shot except the held beat.
- **Occlusion:** head, torso and shoulders checked from both directions at 5 points along the move. If blocked it
  rotates in 15-degree steps, then shortens the move, then goes wider. Glass and transparent parts don't count;
  `CanQuery = false` does NOT hide a part from the rays - make blockers transparent (>= 0.6) or move them.
- **Shot mix:** about a third of the beats are inserts of the spoken object (never over 35%); 25%+ low/high/dutch.

## 5. QA (automatic)
- DirectorCam writes one `[CAMQA]` line per shot to `projects/<slug>/qa/camlog.txt` through the bridge (angle, move,
  FOV, subject fraction, face, safe916, occ, seen, peak speed). `[BLOCKER]` names what blocked a shot; `[REPLAN]`
  marks cuts where an actor arrived late (assemble.py freezes those 1-2 stale frames).
- `qa_take.py` FAILS on: outside the 9:16 safe area, face too big for the size, repeated angle+size, speed over the
  cap, any occluded frame, head out of frame, a dark shot opening. It also prints the SHOT-MIX lint.
- **Most fails are staging:** move the actor off the pole, tree or porch, or give the beat a numeric angle.
- **Dry run:** Studio's `video_capture` (<= 30 s, ~15 fps) in segments. Its motion numbers match the real take; its
  timing drifts 1-3 s, so judge sync only on the real take.
- After the take: `grep -c CAMQA qa/camlog.txt` must equal the beat count. A missing beat = a focus object that had
  not replicated yet; give it `at = Vector3` or create it one line earlier.

## 6. Recording (macOS)
- **Pre-flight:** Studio's login can expire; then avatar meshes, animations and the catalog fail with HTTP 403 and
  characters render INVISIBLE in Play. Before each take run `pcall(MarketplaceService.GetProductInfo, ...)` on a
  known asset; if it fails, save, log out/in of Studio, reopen. After the take grep the output for "403".
- Save the place, start Play, `osascript -e 'tell application "RobloxStudio" to activate'`, grab one still of the
  screen. Restart Play before every take (`Go` fires once per session).
- `auto_take.sh <out> <secs> [from]`: keeps the display awake, waits for 60 s idle, films "Capture screen 0" by NAME
  (a phone camera can take index 1), writes `roblox/go.txt` so the Director starts by itself, and renames the take
  `*_touched.mp4` if the Mac was used. The Mac locks after ~25 min idle: arm takes while the user is nearby.
- `record.sh` crops `VIEW` (Studio's viewport) and parks the mouse in the corner. H.264 hardware encoding fails above
  4096 px wide. The `[CAMVP] w h` line x2 must match `VIEW` within ~4 px.
- **Sync:** DirectorCam shows black, then one white flash 0.5 s before t=0; `assemble.py video` finds it and trims
  (plus a measured 0.22 s picture lag).

## 7. Sound
- **Licences:** Roblox audio is licensed for use inside Roblox only: keep every Roblox Sound muted. Use your own
  library (Sonniss GDC bundles, Freesound CC0) or the synthesized effects in `assemble.py`/`finish.py`.
- Every visible action (impact, door, knock, flash, fall) gets an event in `timeline.py` and a sound.
- Layers: ambience bed + spot effects + footsteps + stingers/risers. Voice on top, effects ducked under it, final
  -14 LUFS / -1 dBTP.
- Music (optional): an original score written in code, side-chain ducked under the voice (sidechaincompress threshold
  0.02 ratio 4, alimiter 0.89), silent before the scares.

## 8. Delivery
- `Finalized_videos/<Title>/`: `full_video.mp4` (9:16, voice + SFX), `full_video_with_music.mp4` if scored, and
  `upload.txt`.
- **Title:** the story name, 2-3 words, Title Case + ONE emoji of the object ("The Lost Glove 🧤"), or a rule-style
  title ("Never count to ten... 🔟"). No hashtags in the title.
- **Description:** line 1 = a one-line teaser in the narrator's voice that hides the key noun and never gives the
  ending; line 2 = one keyword sentence; then `#roblox #horror #shorts`.
- **Category:** Gaming, game title Roblox. Not made for kids.
- **Rights:** the Roblox docs say nothing about AI-generated or Creator Store assets in monetized videos outside
  Roblox. Read the Roblox Terms of Use yourself before monetizing.
- Never upload for the user.

## 9. Lessons (from delivered videos)
- **Walks:** anchored limbs pin an actor and `K.walk` does nothing; `K.place` unanchors the whole body. Tune
  `K.STRIDE` if feet slide.
- **Offstage actors** park under the baseplate (anchored), never visible in wides.
- **Interior rooms:** no ceiling (the camera's ground ray lifts shots onto the roof); light the room with its own lamps
  + `K.interior()`. A 24x22 room fits close/medium shots only; wide two-shots need ~25 studs.
- **Inserts:** focus objects must be uniquely named Models (a plain Part fails the bounding box). A label's text face
  (SurfaceGui.Face) is the insert's front. A `from` pointing clearly up looks down onto lids and things in hands.
  `dist = 1.3-1.5` keeps a wide object inside the strip. Thin backing boards block their own inserts: make them nearly
  transparent and draw the colour in the SurfaceGui.
- **Props with text** must not be re-created every line (blank first frame): keep them (`keep = {"Name"}`) and create
  them one line early.
- **Pre-stage** an actor one line EARLIER when a scene starts with them in a new place.
- **Crowds:** keep extras thin (~6) and the centre open; don't walk crowds toward a close camera.
- **People behind a counter** need a waist-high counter (top y <= 3.6) and 7+ studs of room in front, or they are
  filmed from behind.
- **Held inserts freeze the picture:** use `push_in` with `move_strength` 0.25-0.3 instead of `hold`.
- **`cower` hides the face:** never on a line about a face.
- **Word times:** Whisper can drift by seconds mid-track; `timeline.py` places each word proportionally inside its
  line and keeps Whisper's time only when the two agree within 0.3 s.
- **Studio safety:** keep every set in a `roblox/src/set_*.lua` file and back up the .rbxl before each build.
- **Faster builds:** reuse sets and actors across videos; one writer for all lines; one dry pass, then the real take,
  then retake only failed lines. Read logs with grep/tail instead of dumping them.
