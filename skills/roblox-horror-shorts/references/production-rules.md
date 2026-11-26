# Production rules (Roblox horror Shorts)

Every rule here came from a delivered video, a measurement or a failed take. Numbers were measured on our own videos
and on top Roblox story Shorts. When two rules seem to conflict, the one in a numbered section wins over a lesson.

## 1. Story
- **Length:** under 2:00 (aim 1:45-1:55): about 38-42 lines, 400-480 words. `LIMIT = 119.0` in `timeline.py`.
- **Hook (line 1):** a strange EVENT or fact that already happened, with a NUMBER and a PHYSICAL danger, ideally first
  person ("I found my own face on a missing poster. The date on it is next Tuesday." is the shape, not a line to
  copy). The town's RULE comes in lines 2-3, not line 1: openings like "In our town, never..." kept fewer viewers.
  Leave one open question by line 3. Beat 1.1 is the strongest, strangest image of the video (a cold open), never a
  calm wide. Target: 65-70%+ "stayed to watch" in YouTube analytics.
- **Lint every draft before showing it:** `python3 qa/script_lint.py projects/<slug>/script_draft.txt`; fix every FAIL.
- **Depth:** a person the viewer cares about (a recurring hero + best friend), an escalating number ladder (30 > 19 > 11),
  three clues, a planted detail paid off in the twist, a hero who pays a cost, a short resolution + epilogue, an
  ending question to the viewer, and a callback to line 1 (circular).
- **Written for cuts:** ~1.1 s visual beats. Write tangible things the camera can show (signs, clocks, props, numbers,
  names) and plan a face + an action per line.
- **Light follows the story:** day, dusk or night as the script needs, one look per story time.
- Stories are original. Copy a reference channel's FORMAT (length, hook shape, pacing, title style), never its
  stories, lines or titles: YouTube's reused-content review rejects copies from monetization. Check the latest ~10
  uploads of the channels you follow so a premise doesn't overlap theirs.

## 2. Must-haves for every Short
1. **Every shot moves.** Camera defaults: medium = push_in, full = orbit, inserts push. Never `static`/`hold` except
   the one held beat right before a scare. Characters move in at least 2 of every 3 shots (walk, run, turn, emote,
   pose); at most 1 shot in 5 is idle. Walk, don't teleport: `K.place` only for a scene's first beat and offstage,
   `K.walk` (speed 7-9, run 12-16) inside a scene. Each scene gets a FOLLOW shot (`move = "track"`) and a REVEAL
   (`move = "tilt_up"` onto what they look at). **Gate:** `qa/motion_qa.py` <= 8% frozen frames, motion >= 3.5.
2. **Light with a visible source.** Shadows ON (`Lighting.GlobalShadows = true` in every `K.look`, `CastShadow` on for
   actors and sets; check one still per scene: no shadow blob over a face). Day, dusk and night are all allowed; every
   light has a visible source in the set (lamp, bulb, window, lantern). One look per story time, never a theme jump
   inside a scene. Targets (average luma of the delivered video): day 100-118, dusk 75-100, night 55-85; <= 5% dark
   frames in day scenes; bloom threshold >= 2.0 (lamps may glow, skin and white clothes may not). Faces stay readable
   at night: the camera's face fill never drops to 0.
3. **Visible characters, with room.** Faces readable on a phone: light behind or beside the camera (never a backlit
   silhouette), close/medium framing on every spoken line, wides at most 1 in 6 and never people as specks. A head
   never fills more than **28% of the frame height**: a close-up is chest-up with the whole hat and the shoulders in
   frame (`MAX_HEAD` in DirectorCam enforces it, also for hand-keyed shots). Stage in the open, never behind poles,
   fences or furniture. Every person shot plays an action AND a face that match the words; the scare and the twist
   get the biggest face.
4. **A real place, not a stage.** Textured ground (grass, asphalt, concrete), houses with roofs, trims and windows,
   mesh trees, a street that recedes (second row, tree belts, power lines) instead of ending in a wall or a flat sky
   board. Crowds of extras in wides and the cold open when the story has people around. Never ball-shaped trees,
   SmoothPlastic ground or a flat blue backdrop. Still: the line from the camera to the speaking actor stays clear, and
   every close shot keeps a readable face. List the Set pieces a story uses in `SET_KEEP`; the Director hides the rest.
5. **No burned-in captions by default:** the creator adds captions in their editor. Optional: `CAPTIONS=1 assemble.py video`
   burns one-word captions (lower middle, one word at a time, numbers coloured) from words_full.json.

## 3. Cast: classic blocky avatars with bold drawn faces (standard)
- **Build:** `roblox/cast_classic.lua` builds the starter cast from Roblox catalog items: R15 blocky bodies, textured
  classic Shirt/Pants, hair + hats, and a classic head with a drawn face (`K.classicHead`). Recurring regulars stay the
  same in every video: **Sam** (hero, the bright warm one: yellow smiley shirt, orange aviator beanie, navy jeans),
  **Juno**, **Leo**, **Mom**, plus extras Kid1-4 for crowds. New characters: copy a row only when the story needs one.
- **Outfits:** one signature colour per character, light or neutral pants (never black bottoms), distinct hair/hat
  silhouettes, no neon. Two characters never share a colour in a scene; dark outfits on a dark set disappear (and drag
  the average brightness down). No puffy layered jackets: they show a black tank top.
- **Shirt ids:** `ShirtTemplate` needs the Shirt's TEXTURE id, not the catalog id: `InsertService:LoadAsset(catalogId)`,
  copy the Shirt's `ShirtTemplate`. Find classic shirts with the catalog's ClassicShirts subcategory. Verify every id
  with `MarketplaceService:GetProductInfo`. Hair must go through `HumanoidDescription:SetAccessories(list, true)`.
  `AvatarEditorService:SearchCatalog` works in Studio for shirts/pants; hair searches can hang: clone hair instead.
- **Faces:** `K.face(name, preset, fade)` swaps the drawn decal: neutral smile laugh glee scared shocked worried uhoh sad
  cry stare suspicious smirk awkward grimace angry sleepy creepy hypno. `smile`/`sleepy` can render blank: prefer glee /
  smirk / laugh. Faces change with the line; the scare and twist get scared/shocked.
- **Talking:** `K.talk(name, secs)` flaps the mouth between each face and its open partner (`K.OPEN_FACE`). Serious faces
  need an open partner or the flap reads as a happy grin. Restore base faces to neutral after a video.
- **Ages:** a younger/older version is a separate actor scaled with `Model:ScaleTo` (correct only in Play) plus grey hair
  etc. A change must be seen happening beside a size reference, not cut to.
- **Optional AI cast** (`generate_avatar(textPrompt, pipelineName="npc", dynamicHead=true)`, ~6 min each, then
  `cast_ai.lua prep(...)`): moving 3D faces and real lip sync (`pipeline/lips.py` clips, `K.talk(name, secs, clip)`).
  Never rewrite its RigAttachments; no brand names in prompts; check `workspace` after a "Request timeout" before
  retrying. Classic avatars are the standard because top Roblox story channels use them.
- **Story actions the emotes can't do:** `generate_animation(textPrompt, instance_path="Workspace.Cast.<Name>")`; put
  the returned id in `K.ANIM` in your Part file. Generated ids belong to your account.

## 4. Camera (automatic, vertical first)
Code: `Framer.lua` (shot maths) + `DirectorCam.client.lua` (driver).
- Every shot is composed for the centred 9:16 strip of the recorded viewport (4% margin). The camera is a pure
  function of the story clock, so every retake is identical and in sync with the voice.
- **Sizes:** `extreme`, `close` (chest-up), `medium`, `full`, `wide`, `insert` (the object, text readable). Scares and
  the twist turn a single person's `close` into `extreme`; FACE ROOM (28% head height) caps both.
- **Angles:** eye_level, three_quarter, low (threats, hero moments), high (hero scared), ots (two people facing each
  other 2.5-9 studs apart), dutch (twist/panic, max 3). Chosen from the beat type when left blank. 180-degree rule per
  scene; never the same angle + size more than 3 times in a row. A numeric `angle` is kept exactly. Hair-heavy heads
  (buns) read best at eye level.
- **Moves:** push_in, pull_out, track, orbit (<= 15 deg), tilt_up (reveal), snap_zoom (on the scare sound), static,
  hold. Speed cap 6 studs/s; a faint handheld sway on every shot except the held beat. Busy picture: motion above ~6.5
  in `motion_qa.py` reads as nervous.
- **Occlusion:** head, torso and shoulders checked from both directions at 5 points along the move. If blocked it
  rotates in 15-degree steps, then shortens the move, then goes wider. Glass and transparent parts don't count;
  `CanQuery = false` does NOT hide a part from the rays: make blockers transparent (>= 0.6) or move them.
- **Hand-keyed shots** (`{ {u, pos, look, fov}, ... }` as a beat) for what the auto camera cannot do: a crowd cold open
  arranged like a pyramid, riders under a canopy, interiors where a preset ends inside a wall. They log `[CAMKEY]`;
  keep the same face room by hand (about 8 studs from a head at fov 30).
- **Shot mix:** 25-35% of the beats are inserts of the spoken object; 25%+ low/high/dutch.

## 5. QA (automatic)
- DirectorCam writes one `[CAMQA]` line per shot to `projects/<slug>/qa/camlog.txt` through the bridge (angle, move,
  FOV, subject fraction, face, safe916, occ, seen, peak speed). `[BLOCKER]` names what blocked a shot (often the LAST
  candidate tried: confirm with a raycast in the Client datamodel); `[REPLAN]` marks cuts where an actor arrived late
  (assemble.py freezes those 1-2 stale frames); `[FACECHK]` flags a blank head.
- `qa/qa_take.py <video> qa/camlog.txt [beats.json]` FAILS on: outside the 9:16 safe area, face too big, repeated
  angle+size, speed over the cap, any occluded frame, a beat with no camera line, >= 0.3 s of blank screen (the camera
  is inside something). It prints the SHOT-MIX lint. Wide flat inserts often false-fail `safe916`: judge them on frames.
- **Most fails are staging:** move the actor off the pole, tree or porch, or give the beat a numeric angle.
- **Rehearse before the take:** Play + Studio's `video_capture` (<= 30 s, needs no idle Mac and works while the screen
  is locked) in segments: set `From` = 0, 25, 50, 75, 95..., `Go = now + 4`, restart Play between segments. Then
  `python3 qa/dry_sheet.py qa/d seg0.mp4@0 seg25.mp4@25 ...` (one frame per beat) or `qa/sheet_sme.py` (start/mid/end).
  Review those sheets (a targeted reviewer on the hook, the twist and the QA-flagged beats) and fix before filming.
  Rehearsal timing drifts 1-3 s: judge sync only on the real take. Between mid-frames faults can hide: look at a
  4-fps strip (`qa/strip_sheet.sh`) of risky spans.
- **Check the logs:** a Luau error in a line's `run` silently drops the rest of that line (e.g. a function that calls a
  `local function` declared further down). Read `LogService:GetLogHistory()` in the Client and Server after a rehearsal.
- After the take: copy `qa/camlog.txt` to `qa/camlog_take<N>.txt` (rehearsals overwrite it) and check
  `grep -c CAMQA` + `grep -c CAMKEY` equals the beat count.

## 6. Recording (macOS)
- **A take records the real screen. Never arm one on idle time alone** (an "idle" Mac was once on a video call). Ask the
  user; only after they say they are ready run `READY=yes VIEW=w:h:x:y ./auto_take.sh final/take.mp4 <secs> 0`. It
  refuses while any app holds the microphone, while the screen is locked, or unless Studio stays frontmost for the
  whole recording, and deletes the take otherwise. Never open a take the script did not call VALID.
- **Pre-flight:** Studio's login can expire; then avatar meshes, animations and the catalog fail with HTTP 403 and
  characters render INVISIBLE in Play. Before each take `pcall(MarketplaceService.GetProductInfo, ...)` on a known
  asset; if it fails, save, log out/in of Studio, reopen. After the take grep the output for "403".
- Save the place, set Studio's graphics quality to the maximum (File > Studio Settings > Rendering: Edit/Play Quality
  Level 21, not Automatic), close Toolbox/Terrain Editor (they shrink the viewport), start Play, grab one still of the
  screen. A minimized Studio renders white or black: `record/show_studio.sh`. Restart Play before every take (`Go`
  fires once per session); never stop Play in the same message as the take command.
- `record.sh` crops `VIEW` (Studio's 3D viewport: measure the blue border in a full-screen grab) and parks the mouse.
  H.264 hardware encoding fails above 4096 px wide. The `[CAMVP] w h` line x2 must match `VIEW` within ~4 px.
  Film the story length + 6 s. Studio runs ~15 fps in the background and ~30 while filming.
- **Sync:** DirectorCam shows black, then one white flash 0.5 s before t=0; `assemble.py video` finds it and trims plus
  a picture lag (`SYNC_LAG`, 0.22-0.40 s measured). After assembly compare scene-cut times with beats.json: the median
  must be within +-0.05 s.

## 7. Sound
- **Licences:** Roblox audio is licensed for use inside Roblox only: keep every Roblox Sound muted. Use your own
  library (`SFX_LIBRARY` = a folder of Sonniss GDC / Freesound CC0 wavs) or the synthesized effects in `assemble.py`.
- Every visible action (impact, door, knock, flash, fall) gets an event in `timeline.py` and a sound; list any that
  were missed in the report.
- Layers: ambience bed + spot effects + footsteps + stingers/risers. Voice on top, effects ducked under it, final
  -14 LUFS / -1 dBTP.
- **Music:** always deliver a version with an original score written in code (`pipeline/score.py`: nothing to
  copyright-claim), silent right before the scares. `assemble.py music` ducks it about 13 dB under the voice. If the
  timeline has `heart_on`/`heart_off`, the score must not play its own pulse there (two heartbeats at once).

## 8. Delivery
- `Finalized_videos/<Title>/`: `full_video.mp4` (9:16 1440x2560, voice + SFX, no captions), `full_video_with_music.mp4`,
  `background_music.mp3` (the score), `upload.txt`.
- **Title:** 2-3 words, Title Case + ONE emoji of the object ("The Lost Glove 🧤"), or a short rule teaser under 40
  characters ("Keep your light on... 💡"). No hashtags in the title. Give each of the 3 premises its title.
- **Description:** line 1 = a one-line teaser in the narrator's voice that hides the key noun and never gives the
  ending; line 2 = one keyword sentence; then `#roblox #horror #shorts`.
- **Tags:** one generic channel set (roblox, roblox story, roblox animation, roblox horror, horror animation, scary story,
  horror shorts, twist ending, shorts, animation, storytime...) set once as the upload default, plus 2-3 story keywords.
  <= 500 characters. Never copy another channel's tags.
- **Category:** Gaming, game title Roblox. Not made for kids. Remind the user to set the video to Public and check it.
- **Rights:** the Roblox docs say nothing about AI-generated or Creator Store assets in monetized videos outside Roblox.
  Read the Roblox Terms of Use yourself before monetizing.
- Never upload for the user.

## 9. Lessons (from delivered videos)
- **Walks:** anchored limbs pin an actor and `K.walk` does nothing; `K.place` unanchors the whole body. Tune
  `K.STRIDE` if feet slide. `K.place`/`K.sit` place the ROOT, so rigs whose pivot is far from the root don't float.
- **Floors must be solid** (CanCollide) or actors sink to the baseplate. Never lay a ground part at the baseplate's
  height: it flickers. Measure pelvis vs seat in Play after any new seat (`K.sit`).
- **Offstage actors** park under the baseplate (anchored), never visible in wides. Pre-stage an actor one line EARLIER
  when a scene starts with them in a new place (the camera plans at the cut).
- **Rooms:** walls high enough that the sky never shows; a high ceiling above every camera is fine, a low one blocks
  every shot. With an open top hide the sun disc (`Sky.CelestialBodiesShown = false`, SunRays 0, Atmosphere.Glare 0:
  do it in every line, outdoors too, a low sun washes out faces). Nothing neon or solid above the lens. A 24x22 room
  fits close/medium only; wide two-shots need ~25 studs. Porch roofs/posts and lamp posts that block a hero shot: hide
  them in the set's `reset()`.
- **Inserts:** focus objects must be uniquely named Models (a plain Part fails the bounding box). Wall features
  (windows, doors, a rope) get a hidden focus mark: a Model with one transparent `CanQuery = false` part named `FM_*`,
  sized like the frame you want; names unique across `workspace.Set`. A label's text face is the insert's front. A
  `from` pointing clearly up looks down onto lids and things in hands. `dist` is a MULTIPLIER of the framing distance
  (1 = fills ~55%), never studs: 1.3-2.4 keeps a wide object inside the strip. Thin backing boards block their own
  inserts: make them nearly transparent and draw the colour in the SurfaceGui. Never stand an actor on the spot a ground
  insert films. Flat props need their text rotated toward the camera.
- **First-beat objects:** a focus object created in a line's `setup` may not have replicated at t=0: give the beat
  `at = Vector3` + `span`, create it one line early, or use a keyframe beat. Props with text must not be re-created
  every line (blank first frame): keep them (`keep = {"Name"}`).
- **Held props:** `K.hold` welds only the root: weld every part inside the prop to it. Scale hand props ~0.5 of what
  looks right. Don't insert-frame a prop in a hand that walks or shakes; use a person shot. Props on posed arms rotate
  (poses are client-side): carry them with a follow-the-root helper at waist height.
- **Moving things by code** (rides, slides, ladders): anchor the root and PivotTo each frame; the next `K.place` frees it.
  Actors on a ride under a canopy need keyframe cameras.
- **Crowds:** extras that move (or even with `CanQuery = false`) block the camera: keep them 15+ studs from the actors
  and off the camera line. Watchers stand BEHIND the actor being filmed. Don't walk crowds toward a close camera.
- **Staging:** the camera lands in front of the actor, so an actor facing a wall puts the camera inside it: stage
  everyone facing the open side. People behind a counter need a waist-high counter (top <= 3.6) and 7+ studs in front.
  A seated actor's desk props are filmed from the open aisle. Contact (hugs, hand-overs) needs ~4 studs (`K.together`).
- **Acting:** no arm-raising emotes on an actor framed close in that line (they cover the face); `cower` hides the face
  (never on a line about a face); talk shots get small planned actions (head turns to the talker, a nod, one step).
  Seated, talk-heavy stories freeze the picture: write movement into them.
- **Name tags:** `Humanoid.DisplayDistanceType = None` on every actor.
- **Word times:** Whisper can drift by seconds mid-track; `timeline.py` places each word proportionally inside its
  line and keeps Whisper's time only when the two agree within 0.3 s.
- **Studio safety:** keep every set in a `roblox/src/<set>.lua` builder and back up the .rbxl before each build.
  `require` caches a module: test a rebuilt set in Edit with `require(RS.MySet:Clone())`. Play starts fresh.
- **Faster builds:** reuse sets and actors across videos; one writer for all lines; one rehearsal pass, then the real
  take; retake only for real faults. Read logs with grep/tail instead of dumping them (get_console_output of a full
  CAMQA log floods the chat).

## 10. Improve after every video
Keep `IMPROVEMENTS.md` in the work folder: a ranked backlog (gap, measure now, target, idea) and a log per video
(QA numbers: frozen %, motion, brightness, s/shot, inserts %, sync; the user's feedback; retention once known).
Before the next build, put the top backlog item into the kit and test it in Play; after delivery, log the numbers and
re-rank. Every rule in this file came from that loop.
