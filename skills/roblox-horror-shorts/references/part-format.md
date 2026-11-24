# Part files: format + K API

A Part file is ONE Luau ModuleScript (`projects/<slug>/partN/Part.lua`) that returns a table keyed by script line
number. The Director (server) runs each line's `setup`/`run` at the line's start; DirectorCam (client) reads its
`beats`. Inputs: `Timeline.lua` (`T.shots`, ~1.1 s `T.beats` with the words spoken in each, `T.ev`) and `script.txt`.
Write valid Luau only: the API below plus plain Roblox API (Vector3, CFrame, Instance.new, task.*). Template:
`roblox/example_part.lua`.

## Module format
```lua
return {
  SET_KEEP = {"Ground", "Mailbox"},   -- workspace.Set children this story needs; the rest is hidden at Play start

  [12] = {                            -- script line number
    beat = "scare",                   -- optional: hook | dialogue | clue | plan | scare | twist | ending
    look = "uneasy", blend = 1.5,     -- optional light mood (+ seconds to melt into it); clock = 16.8 sets the sun
    setup = function(K, S) ... end,   -- at the line start: K.clearFX(), K.only(...), K.place(...), props
    run = function(K, S) ... end,     -- timed actions: S.at(rel, fn), S.waitUntil(rel), S.ev(id), S.say0 / S.say1
    beats = {                         -- one camera per beat of this line, in order; extra beats repeat the list
      {frame = "close", actor = "Sam"},
      {frame = "insert", focus = "Mailbox", move = "tilt_up"},
      {frame = "medium", actors = {"Sam", "Leo"}},
    },
  },
}
```
- **S fields** are relative to the LINE start: `S.dur`, `S.say0`/`S.say1` (speech start/end), `S.ev(id)` (an event
  from events.json), `S.at(t, fn)`, `S.waitUntil(t)`, `S.now()`. For an action on a given beat use the beat's `start`
  minus the line's `start` (both in Timeline.lua).
- **Every line stages itself in setup** (clearFX, only, place, props). Never rely on the previous line.
- Part modules are required separately by the server and by the camera client: never change `beats` inside setup/run.
- **Hero and threat:** the camera treats the actor named by `workspace:SetAttribute("Hero", "<name>")` (default "Sam") as the
  hero (high angles when scared) and any actor with attribute `Threat = true` (or named "Tall") as the threat (low angles).
  Set both in your cast setup.
- Helper functions at the top of the file are fine (a `stage()` that clears FX except a `keep` list, a `cue()` that
  fires anim + face + talk together, camera shorthands like `close(a)` / `ins(focus, from)`).

## Camera fields (per beat)
Most beats need only `frame` + `actor`/`actors`/`focus`; the camera picks the angle, move and position.
- `frame`: `extreme` | `close` | `medium` | `full` | `wide` | `insert`. Walkers and groups of 3+ widen to `full`.
- `actor = "Sam"` or `actors = {"A", "B"}` (two-shot; keep them ~4 studs apart, >= 3.8 is enforced).
- Inserts: `focus = "ModelName"` (frames the object's real size, faces its text) or `at = Vector3` + `from` (camera
  side direction) + `dist` (multiplier); `at = {actor = "Sam", off = Vector3}` pins a small object to an actor.
- `angle`: `eye_level` | `three_quarter` | `low` | `high` | `ots` | `dutch`, or a number (yaw degrees, kept exactly).
- `move`: `push_in` | `pull_out` | `track` | `orbit` | `tilt_up` | `snap_zoom` | `static` | `hold`;
  `move_strength` overrides the amount (push 0.04-0.3, orbit <= 15 degrees).
- Also: `fov` (35-45 only for compression shots), `dist`, `handheld = true`, `polaroid = true`, `side = Vector3`.
- Hand-made keyframes `{ {u, pos, look, fov}, ... }` only for establishing crane shots, never for people.

## K (Kit) API, server side
- **Actors:** `K.actor(name)`, `K.place(name, pos, lookAtPoint)`, `K.only(...)` (everyone else offstage),
  `K.offstage(...)`, `K.show(name, on)`, `K.turn(name, point)`, `K.walk(name, to, speed)` (call with `task.spawn`),
  `K.sit(name, seatPos, lookAt)`, `K.swing(name, amp, period)` / `K.stopSwing(name)`, `K.wave(name, speed)`.
- **Animation:** `K.anim(name, action, fade)`. Actions: idle walk run sit wave point cheer laugh, plus the emotes
  agree disagree applaud beckon bored celebrate confused cower curtsy dizzy getout haha happy hello herolanding
  highwave jumpcheer louder point2 sad salute shrug shy sleep sneaky tantrum tilt zombie. Held poses loop (cower, sad,
  sleep, zombie, shy, bored, confused, sneaky, dizzy); one-shots return to idle. Add your own generated ids to
  `K.ANIM` at the top of the Part file.
- **Poses** (acting the emotes can't do, blended on the client): `K.pose(name, "pockets" | "reach" | "pull" | "shove" |
  "flinch" | "holdup" | "stiff" | "lookback" | "straight" | "handup", fade)`; `K.pose(name)` releases. Every actor
  also breathes and looks around a little by itself.
- **Faces:** `K.face(name, preset, fade)`: neutral smile laugh scared sad cry worried stare suspicious grin blank brows.
- **Talking:** `K.talk(name, seconds, clip)` (clip = a `lips.py` key; without it the jaw flaps).
- **Light:** `K.look(name, secs)` with calm / uneasy / scare / aftermath (also day, golden, sunset, dusk, night),
  `K.setTime(clock)`, `K.tweenTime(a, b, secs)`, `K.cloud(down, hold, up)`, `K.interior()`, `K.lights(on, filter)`.
- **Props:** `K.sign(text, cframeFacingCamera, size, {bg, fg, font, material, glow, parent})` (readable boards),
  `K.prop(name, cframe)` (clone from ServerStorage.Props into FX), `K.hold(name, propName, hand, offset)` /
  `K.drop(name)`, `K.photo(cf, size, left, right, dark)`, `K.darken(name, on)`, `K.clearFX()`.
- **Shadows (story effects; real shadows are off):** `K.shadow(name, opacity)` -> a black silhouette with
  `:lie(dir, stretch)`, `:rise(sec)`, `:glide(pos, sec)`, `:moveTo(pos)`, `:opacity(a)`, `:destroy()`;
  `K.lateShadow(name, lag)` -> `:stop()`.

## Staging checklist
- Stand people in the open on plain ground, 3+ studs to the side of any prop the camera must see.
- A third of the beats are inserts of the spoken object; the first insert after a look/point tilts up onto it.
- `close` on every spoken line; scares and the twist become `extreme` by themselves.
- Never 3 eye-level person shots in a row; give mediums and inserts `low`/`high` often.
- Pre-stage anyone who opens the next line, out of shot, in the previous line's setup.
