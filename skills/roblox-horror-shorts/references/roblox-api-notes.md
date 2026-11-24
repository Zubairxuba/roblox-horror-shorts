# Roblox engine notes for filmed Shorts (docs + our tests)

Facts gathered from create.roblox.com/docs (2026-11-24) and **tested** in Studio where marked. Tags:
- **[TESTED]**: we ran it.
- **[DOC]**: read in the docs.
- **[UNSURE]**: inferred.

Use this before building a cast, a set or a scene.

## 1. Characters ("best casting")

### AI-generated actors [TESTED 2026-11-24]
`generate_avatar(textPrompt, pipelineName="npc", dynamicHead=true)` builds a full R15 character from one sentence: body, sculpted head, hair and 3D clothes. Far better than catalog-dressed blocky actors.

- **Time:** about 5–6 min each, and it runs in the background.
  - The MCP call can report "Request timeout" while the model still arrives. Check `workspace` for the named model before retrying.
- **Comes with:** `HumanoidRigDescription`, an `InitialPoses` folder, MeshParts with SurfaceAppearance, and a **FaceControls** under `Head` (a dynamic head).
- **Fix 1, pivot:** the model's WorldPivot can be far away (it was at 3000 studs).
  - Run `m.WorldPivot = m.HumanoidRootPart.CFrame` first.
  - Then place it by bounding box.
- **Rest pose:** the A-pose rest is fine, so **never rewrite its RigAttachments**.
  - Catalog idles play correctly.
  - Odd poses were `K.fidget` emotes, which are now skipped for actors with a `Pack`.
  - Generate custom clips (`generate_animation`) on the untouched rig.
- **Prep:** `roblox/src/cast_ai.lua`.
- **Fix 2, pose and height:**
  - It stands in T-pose in Edit, which is normal; animations take over in Play.
  - It comes out adult height (about 6 studs). Scale kids down (Model:ScaleTo, to be checked).
- **Fix 3, logos:** jacket letters and logos are random ("A" instead of "S"). Ask for "plain" items, or accept them.

### Facial expressions: FaceControls [TESTED on the AI actor]
About 50 channels, each a float from 0 to 1, settable by script. They even show in Edit.

- Names are **Left/Right-prefixed**; `InnerBrowRaiser` without a side does not exist.
- The full list: classes/FaceControls.md.
  - **Brows:** `Left/RightInnerBrowRaiser`, `Left/RightOuterBrowRaiser`, `Left/RightBrowLowerer`, `Corrugator`.
  - **Eyes:**
    - lids: `Left/RightEyeUpperLidRaiser`, `Left/RightEyeClosed`;
    - gaze: `EyesLookLeft/Right/Up/Down`.
  - **Mouth:**
    - jaw: `JawDrop`;
    - lips: `LipsTogether`, `Funneler`, `Pucker`, `Left/RightLipStretcher`, `Left/RightLipCornerPuller` (smile), `Left/RightLipCornerDown` (sad), `Left/RightLowerLipDepressor`, `Left/RightUpperLipRaiser`;
    - cheeks: `Left/RightCheekRaiser`.
- **Scared** (tested, reads well): inner and outer brow raisers 1, upper-lid raisers 1, lip stretchers 0.7, `JawDrop` 0.6.
- **Gotchas:**
  - [DOC] The values are not saved, so set them at runtime.
  - The default "mood" face animation can overwrite them. Remove `Animate.mood`, or set `HumanoidDescription.MoodAnimation = 0`.
- **Lip sync plan:** drive `JawDrop` (+ `Funneler`/`LipsTogether`) from the loudness envelope of our own voice WAV. There is no Roblox audio, so no licence issue. There is no offline audio-to-face API [DOC].

### Catalog-dressed actors (cheaper fallback) [TESTED]
- **Layered 3D clothing** beats classic flat Shirt/Pants:
  - `d:SetAccessories({ {AssetId=, AccessoryType=Enum.AccessoryType.Jacket, IsLayered=true, Order=3, Puffiness=0.5}, ... }, true)`
  - Order: tee 1, pants 2, jacket 3.
- **Slim body:** `WidthScale = min(1, HeightScale + 0.05) * 0.76`, `DepthScale = 0.86`. This fixes the "chest too wide".
- **Good free or official layered items:**

  | Item | ID |
  |---|---|
  | Letterman Crimson/White | 9039724070 |
  | Roblox T-Shirt White | 7178737816 |
  | Basic T-Shirt Gray | 9112474888 |
  | Denim Jacket Light Wash | 8516609675 |
  | Beige Chinos | 14178531985 |
  | Grey Chinos | 13958225096 (renders dark) |
  | Oversized Green Flannel | 9130433233 |
  | Y2K Baggy Streetwear Jeans w/ Shoes (Light Blue) | 100621828763865 |

- **Catalog search:** `AvatarEditorService:SearchCatalog` with `AssetTypes = {Enum.AvatarAssetType.JacketAccessory}` etc. Wrap it in a 20 s timeout, because some queries hang. A shoe search returns nothing, so use pants that include shoes.

## 2. Animation and acting

- **Animation packs:** the kit's `K.ANIM` uses the plain default idle and walk (507766388 / 507777826). Swap in a pack per character. All IDs below were checked [TESTED]:

  | Pack | Idle | Walk | Run |
  |---|---|---|---|
  | Cartoony | 742637544 | 742640026 | 742638842 |
  | Stylish (Sway) | 616136790 | 616146177 | 616140816 |
  | Rthro | 2510196951 | 2510202577 | 2510198475 |
  | Bubbly | 910004836 | 910034870 | 910025107 |
  | Ninja | 656117400 | 656121766 | 656118852 |
  | Toy | 782841498 | 782843345 | 782842708 |
  | Old School | 5319828216 | 5319847204 | 5319844329 |

- **Text-to-animation [TOOL]:** `generate_animation(textPrompt, instance_path)` builds an R15+ clip ("stumbles back terrified, covers mouth"). Expect up to about 10 s.
- **Play clips without uploading [DOC]:** `AnimationClipProvider:RegisterAnimationClip(clip)` returns a temporary ID for `Animation.AnimationId` (Studio only, which suits us). `GetClipEvaluatorAsync` samples any clip.
- **IKControl [DOC; UNTESTED on our rigs]:**
  - In the 2026-11-24 test, a LookAt chain (UpperTorso to Head) on an R15+ AI actor ran together with a regenerated clip, and the actor folded over. The cause was never isolated.
  - Use the pose library `lookback` plus FaceControls `EyesLook*` until IK is tested on its own.
  - `Type` LookAt/Position/Transform, `EndEffector`, `ChainRoot`, `Target`, `Pole`, `Weight` (tween it to ease), `SmoothTime`.
  - Use it for head and eye-line to another actor, or a hand to a doorknob.
  - [UNSURE] how it combines with our joint.Transform pose library. Test it first.
- **Blending [DOC]:** `track:Play(fade, weight, speed)`, `AdjustWeight`, `AdjustSpeed`. For example, a 0.4-weight scared idle over the normal idle.
- **No stutter in wide shots [DOC]:** `Animator.PreferLodEnabled = false`.
- **Performance capture (needs a person to act) [DOC]:**
  - Animation Editor, Live Animation Creator (video to body, ≤15 s, one person).
  - Face Capture (webcam to face, ≤60 s).

## 3. Camera and recording

- [TOOL] `video_capture` works in Play (Client): mp4 at 1760x992, ≤30 s [TESTED].
  - DirectorCam's black `ScreenGui` covers the view until `Go`. Disable it for test reels.
- [DOC] `Camera:GetPartsObscuringTarget`: an occlusion check so walls don't block close-ups.

## 4. Light and post (small)

- [DOC] `ColorGradingEffect.TonemapperPreset = Retro` gives softer contrast.
- [DOC] `Lighting.LightingStyle` (Realistic / Soft) and `PrioritizeLightingQuality`. `Lighting.Technology` is deprecated.

## 5. Sets

- [TOOL] `generate_scene`, `generate_procedural_model`, `generate_material`.
- [DOC] `GenerationService:GenerateModelAsync` (text to 3D).

## 6. Brightness controls [DOC], with one docs claim DISPROVED

- **The docs are WRONG for our place [TESTED 2026-11-24]:**
  - **The docs say:** *"when GlobalShadows is disabled … OutdoorAmbient will be ignored"*.
  - **Our A/B test** (shadows off, night, Ambient 60 grey, `LightingStyle = Soft`): switching OutdoorAmbient from black to white turned a near-black frame into a bright one.
  - **So OutdoorAmbient still matters.** Keep the `amb` and `out` values in `K.LOOKS` as they are. (The doc line probably describes the Realistic style.)
- **Brightness controls:**
  - `Lighting.ExposureCompensation` (−5 to 5; +1 = 2× exposure, applied before the tonemap). Use it as the main brightness control, about +0.5 to +1.5.
  - `Lighting.Brightness` = sun or moon intensity.
  - `ColorCorrectionEffect.Brightness` (−1 to 1).
- `ColorCorrectionEffect.TintColor` is **multiplicative**: any tint below white darkens the whole frame. Keep it close to (255,255,255).
- Post-effects follow Studio's **Editor Quality Level**, so record at max quality.
  - `PrioritizeLightingQuality = true`.
  - `LightingStyle` Soft = flat retro look. `ShadowSoftness` only applies in Realistic.

## 7. Horror visual effects [DOC]

- **Glowing eyes:**
  - Neon parts + `BloomEffect` (Intensity, Size, Threshold; several Blooms add together).
  - Optionally add a `Highlight` with `DepthMode = Occluded`, so eyes don't show through walls.
- **Highlight:**
  - Limits: 255 at once; extras are silently ignored, and disabled ones still use a slot.
  - Change properties rather than adding and removing highlights.
  - Don't nest highlighted objects inside each other.
  - Highlight only the danger or clue, otherwise it becomes noise.
- **ParticleEmitter:**
  - **Rules for any emitter:**
    - To read in the dark: `LightEmission = 1` (additive), or `LightInfluence = 0`.
    - Fade `Transparency` in and out over the lifetime to avoid popping.
    - Limits: `Lifetime` ≤ 20 s and `Rate` ≤ 400/s.
    - Parent Sphere/Cylinder shapes to a Part, not an Attachment.
  - **Ground mist:** one big transparent anchored part, a few large slow particles.
  - **Rain:** an invisible part overhead, `EmissionDirection = Bottom`, `Squash ≈ 3`, short Lifetime, high Speed.
  - **Extras:** `Emit(n)` for bursts, `TimeScale` for slow-motion, flipbooks (max 30 fps).
- **Beam:** textured strip between two Attachments (`Width0/1`, `CurveSize0/1`, `FaceCamera`). Use it for fake light shafts and lightning bolts.
  - **Lightning:** a beam flash plus a brief `ExposureCompensation` spike, synced to the thunder.
- **Flicker** (official tutorial): a NumberSequence attribute plus `LoopDuration`, evaluated on Heartbeat. It scales the light's Brightness, the beam's Brightness and the bulb's Color together.
- **Story-prop lights** (these are not scene lighting):
  - Flashlight = SpotLight (`Angle`, `Face`).
  - TV glow = SurfaceLight.
  - Candle = PointLight (Range 48, Brightness 2, Color 255,179,73). Range is capped at 120.
- **Smoke:** prefer ParticleEmitter over the legacy Smoke.

## 8. Atmosphere, sky, clouds [DOC]

- **Atmosphere:**
  - `Density` about 0.27–0.375 hides the background.
  - **Raise `Offset` (about 0.17) for a horizon silhouette.**
  - `Haze` 1–2.8. Set `Color` to roughly the scene's average colour.
  - `Glare` needs Haze > 0. `Decay` needs Haze and Glare > 0.
  - Legacy Fog* is hidden whenever an Atmosphere exists.
- **Night that still reads:** purple-dusk Ambient about (156,136,176), plus the exposure control from section 6.
- **Sky:**
  - `StarCount`, `MoonAngularSize`, `SunAngularSize`, `CelestialBodiesShown`.
  - `SkyboxOrientation` rotates the skybox cheaply.
  - The moon phase is fixed.
- **Clouds:**
  - They render **only when parented under Terrain**.
  - `Cover` 0.65–0.8.
  - `Density` 0.1 = light, 0.3 = stormy.

## 9. Sets, surfaces, generation [DOC]

- **MaterialVariant** (MaterialService): tileable PBR materials, per part or as a global override of a base material. Duvall Drive used a wet-concrete override.
- **Terrain:**
  - `FillBlock(cframe, size, material)`, `FillBall`, `FillCylinder`, `FillWedge`.
  - Grass needs `Decoration` on, with `GrassLength` 0.1–1.
  - Water: `WaterColor`, `WaterTransparency`, `WaterWaveSize`.
- **GenerationService:GenerateModelAsync** (text or image to 3D):
  - Inputs: `TextPrompt`, `Image`, `Size`, `MaxTriangles`, `GenerateTextures`.
  - Wrap it in pcall and anchor the result.
  - Procedural models: 50 per 24 h.
- **Texture Generator:** Fast = 1K diffuse in under 30 s; Quality = 4K PBR in about 2 min.
- **Material Generator:** put "grayscale" in the prompt for tintable results.
- **Creator Store:**
  - Insert by click or drag.
  - Right-click and choose "Disable Scripts" on inserted models.
  - The asset page shows triangle and script counts.
- **Recording detail:**
  - `RenderFidelity` Automatic drops detail past 250 studs. Set **`Precise`** on hero and background meshes.
  - Streaming centres on the character, not our scripted camera, so keep `StreamingEnabled` off for small sets [UNSURE].

## 10. Usage rights: OPEN QUESTION

The docs **say nothing** about using Creator Store models or catalog items in videos outside Roblox. The only wording found is "assets for public use in your games". The Terms of Use live on help.roblox.com, which we could not read.

Until you have checked them:
- prefer assets we generate or build ourselves;
- catalog avatar items on our own cast are the same practice the reference channels use, but this is not verified.

## 11. Camera details [DOC]

- **Set `Camera.Focus` every frame** in Scriptable mode. The engine lights in detail around Focus, and PointLights far from it may not render.
  - Checked 2026-11-24: `DirectorCam.client.lua` never sets it. One-line fix: `cam.Focus = CFrame.new(look)`.
- **Camera loop:** we already use `BindToRenderStep(..., Enum.RenderPriority.Camera.Value + 1)` correctly.
- **Field of view:**
  - `FieldOfView` is clamped to 1–120.
  - `FieldOfViewMode` sets which axis stays fixed when the viewport is resized. Choose it deliberately for 9:16.
- **Camera moves:**
  - `Camera:Interpolate` is deprecated; use TweenService.
  - `TweenService:GetValue(alpha, style, dir)` gives the eased value for per-frame camera moves.
  - Easing styles: Linear, Sine, Back, Quad, Cubic, Quart, Quint, Bounce, Elastic, Exponential, Circular. `Bezier`/`Spring` error in TweenInfo.
- **Occlusion:** `Camera:GetPartsObscuringTarget(points, ignore)` lets us reject angles where a wall blocks an actor.
- **Stills:** `StudioCaptureService:CaptureScreenshot` returns a PNG buffer. Plugin-only: useful for QA frames or thumbnails, not video.
- **Not in the docs:** letterbox, screen shake and cutscene tools. Build them ourselves.

## 12. Acting and animation craft [DOC]

- **Priorities:** Action4 > Action3 > Action2 > Action > Movement > Idle > Core. **Catalog packs play at Core**, the lowest.
  - Layering is per joint, highest priority first, until the weights add up to 1.
  - Acting beats go at Action or higher; pose holds at Action2 or higher.
- **Fit a clip to the script time:**
  - `track:AdjustSpeed(track.Length / seconds)`.
  - `Length` is 0 until the clip has loaded.
- **Freeze-frame pose from any emote:** `AdjustSpeed(0)` plus `TimePosition = t`, while it plays. Instant reaction holds.
- **Markers:** `track:GetMarkerReachedSignal("Name")`. Use them for footsteps and hit sounds, created in the Animation Editor.
- **More pack IDs (horror):**

  | Pack | Walk | Idle |
  |---|---|---|
  | Zombie | 616168032 | 616158929 |
  | Elder | 845403856 | 845397899 |
  | Werewolf | 1083178339 | — |
  | Vampire | 1083473930 | — |
  | Levitation | 616013216 | — |

  The full table of 17 packs is at animation/using.md.
- **Joints:**
  - R15 rigs use `AnimationConstraint`, not Motor6D (confirmed on our cast). C0/C1 are read-only. Never write `RigAttachment.CFrame`.
  - Our pose library follows the recommended pattern (multiply into `.Transform` in PreSimulation). Add a skip when `Animator.EvaluationThrottled`.
- **Ragdoll fall:**
  - `AnimationConstraint.IsKinematic = false` plus MaxForce/MaxTorque.
  - Disable the `GettingUp` state to keep the actor down.
- **Emotes:**
  - `desc:SetEmotes({Name = {id}})` then `Humanoid:PlayEmoteAsync(name)`.
  - IDs: Hello 3576686446, Shrug 3576968026, Point 3576823880, Salute 3360689775, Tilt 3360692915, Agree 4849487550, Disagree 4849495710, Stadium 3360686498.
- **Face moods:**
  - `HumanoidDescription.MoodAnimation` sets the resting face.
  - `StaticFacialAnimation = true` freezes a static mood. Open-mouth mood: 7715145252.

## 13. Movement [DOC]

- **MoveTo:**
  - It **times out after 8 s**. Re-issue it every 6 s for long walks.
  - It is silently cancelled by `Move()`, a new WalkToPoint, or **setting the RootPart CFrame / PivotTo**.
  - `WalkSpeed` default is 16.
- **AutoRotate = false** keeps the facing, so we drive deliberate head-then-body turns ourselves.
- **States:** `SetStateEnabled` does not replicate, so call it where the NPC is owned (the server).
- **Pathfinding:**
  - `CreatePath{AgentRadius=2, AgentHeight=5, WaypointSpacing=4, Costs={...}}`.
  - `PathfindingModifier` costs stop odd shortcuts. `PathfindingLink` + Label runs custom actions (door open).
  - Limits: 3,000 studs, 20,000 nodes.
- **Seat:**
  - `Seat:Sit(humanoid)`; destroy the `SeatWeld` to stand up.
  - There is a **3 s cooldown** before the same actor can re-sit on the same seat.

## 14. Characters, API updates [DOC]

- `CreateHumanoidModelFromDescription` is **deprecated**: use `CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)`.
  - `GetHumanoidDescriptionFromOutfitIdAsync` builds a cast member from a catalog bundle/outfit.
- **Scales:**
  - `BodyTypeScale` and `ProportionScale` are clamped 0–1. ProportionScale does nothing at BodyType 0.
  - `HeadScale` also scales hats and hair.
  - Reference heights: classic about 5 studs, humanoid-style 6–6.5.
- **Kid size:** `Model:ScaleTo(f)` scales cleanly around the pivot, but the docs only promise that animations scale for AnimationController rigs. Test it on a Humanoid. The description Height/Width scales are the safe route.

## 15. Audio and usage rights [DOC]

- **Creator Store audio:** "free-to-use … for creators to use **within their games**". Keep using our own Sonniss/CC0/Chatterbox audio.
- **Limited Use License:** Roblox software is for "deployment through the Roblox platform".
- **AI output:** the Avatar Lab defers to the Terms of Use. The docs never say who owns or may monetize generated assets.
- **The real answer** is in the Terms of Use (en.help.roblox.com), which our tools cannot fetch. **Read the sections on content use and videos before we lean on store models or generated assets in monetized Shorts.**

## Do-first list (combined, impact vs effort)

1. **Brightness** (minutes): use `ExposureCompensation` as the one brightness control, and keep TintColor near white.
   - Do NOT move the fill into Ambient: the "OutdoorAmbient is ignored" doc claim was disproved by our A/B test (section 6).
2. **Camera fix** (1 line): `cam.Focus` every frame.
3. **AI cast with moving faces:** `generate_avatar`, about 6 min per actor. Then FaceControls expression presets, and lip sync from our voice WAV.
4. **Acting layer:**
   - acting clips at Action–Action4;
   - `Length/seconds` speed fit;
   - freeze-frame holds;
   - `generate_animation` for story beats;
   - IKControl look-at.
5. **Horror effects:** Neon + Bloom glowing eyes, Highlight on the monster, ground-mist emitter, flicker script, beam lightning.
6. **Atmosphere silhouettes:** Density about 0.3, raised Offset, matched Color.
7. **Movement hygiene:** re-issue MoveTo every 6 s, never PivotTo mid-walk, AutoRotate off for scripted turns.
8. **Sets:** generated props and materials. Use `RenderFidelity = Precise` on key meshes.
