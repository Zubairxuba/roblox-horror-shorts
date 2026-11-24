-- Roblox Shorts kit: actors, faces, shadows, lights. Server-side helpers (cameras live in the client Director).
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local K = {}

K.ANIM = {sit = 2506281703, idle = 507766388, walk = 507777826, wave = 507770239, point = 507770453, run = 507767714, cheer = 507770677, laugh = 507770818}
-- ACTION LIBRARY: official Roblox emotes (catalog emote -> InsertService:LoadAsset -> AnimationId).
-- Story actions they can't do: generate_animation on the rig, then add the id to K.ANIM. No character beat is just idle.
for k, id in pairs({agree = 10713954623, disagree = 10714065135, applaud = 10713966026, beckon = 10713984554, bored = 10713992055,
	celebrate = 10714016223, confused = 4940561610, cower = 4940563117, curtsy = 10714061912, dizzy = 10714066964, getout = 10714345862,
	haha = 10714350889, happy = 10714352626, hello = 10714359093, herolanding = 10714360164, highwave = 10714362852, jumpcheer = 5895324424,
	louder = 10714385204, point2 = 10714395441, sad = 10714392876, salute = 10714389988, shrug = 10714374484, shy = 10714369325,
	sleep = 10714360343, sneaky = 10714358528, tantrum = 10714340558, tilt = 10714338461, zombie = 10714089137}) do K.ANIM[k] = id end
-- held poses loop (they would otherwise end in the rest pose mid-shot)
K.LOOP = {idle = true, walk = true, run = true, sit = true, cower = true, sad = true, sleep = true, zombie = true, shy = true, bored = true, confused = true, sneaky = true, dizzy = true}
K.FACES = {
	neutral = {},
	smile = {LeftLipCornerPuller = 0.8, RightLipCornerPuller = 0.8, LeftCheekRaiser = 0.5, RightCheekRaiser = 0.5},
	laugh = {JawDrop = 0.5, LeftLipCornerPuller = 1, RightLipCornerPuller = 1, LeftEyeClosed = 0.6, RightEyeClosed = 0.6, LeftCheekRaiser = 0.7, RightCheekRaiser = 0.7},
	-- 2026-11-24 AI heads: stronger values + LipCornerDown (the generated faces have a resting smile that ate the old "scared")
	scared = {JawDrop = 0.55, LeftEyeUpperLidRaiser = 1, RightEyeUpperLidRaiser = 1, LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, LeftOuterBrowRaiser = 0.8, RightOuterBrowRaiser = 0.8, LeftLipStretcher = 0.9, RightLipStretcher = 0.9, LeftLipCornerDown = 0.5, RightLipCornerDown = 0.5},
	sad = {LeftLipCornerDown = 0.9, RightLipCornerDown = 0.9, LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, Corrugator = 0.5},
	cry = {LeftLipCornerDown = 1, RightLipCornerDown = 1, LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, Corrugator = 0.8, LeftEyeClosed = 0.45, RightEyeClosed = 0.45, JawDrop = 0.15},
	worried = {LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, Corrugator = 0.6, LipPresser = 0.5, LeftLipCornerDown = 0.5, RightLipCornerDown = 0.5},
	stare = {LeftEyeUpperLidRaiser = 0.6, RightEyeUpperLidRaiser = 0.6, LipsTogether = 0.5},
	suspicious = {LeftBrowLowerer = 0.7, RightBrowLowerer = 0.7, LeftEyeClosed = 0.3, RightEyeClosed = 0.3, MouthLeft = 0.3},
	-- the villain's wide grin, a vacant stare, the eyebrow-wiggle joker
	grin = {JawDrop = 0.3, LeftLipCornerPuller = 1, RightLipCornerPuller = 1, LeftCheekRaiser = 1, RightCheekRaiser = 1, LeftLipStretcher = 0.5, RightLipStretcher = 0.5},
	blank = {LeftEyeClosed = 0.4, RightEyeClosed = 0.4, LipsTogether = 0.4, LeftLipCornerDown = 0.2, RightLipCornerDown = 0.2},
	brows = {LeftOuterBrowRaiser = 1, RightOuterBrowRaiser = 1, LeftInnerBrowRaiser = 0.7, RightInnerBrowRaiser = 0.7, LeftLipCornerPuller = 0.9, RightLipCornerPuller = 0.9, LeftCheekRaiser = 0.6, RightCheekRaiser = 0.6},
}

function K.actor(name) return workspace.Cast:FindFirstChild(name) end

-- BOLD FACES (3h): classic drawn faces on a classic head; FaceControls changes were too subtle on a phone.
-- Image ids verified 2026-11-22 (InsertService:LoadAsset of the catalog face -> Decal.Texture).
K.FACE_IMG = {neutral = 7074780, smile = 209713384, laugh = 16132434, glee = 7074712, scared = 7699096, shocked = 7317691,
	worried = 9250431, uhoh = 7074932, sad = 8560912, cry = 8560912, stare = 8560915, suspicious = 31117192, smirk = 7317606,
	awkward = 23931977, grimace = 20418518, angry = 7076211, sleepy = 161124757, creepy = 629906620, hypno = 10747392}
-- give a rig a classic head (the dynamic mesh head is hidden; hair/hats stay attached to it)
function K.classicHead(m, preset)
	local h = m:FindFirstChild("Head"); if not h then return end
	local c = m:FindFirstChild("ClassicHead")
	if not c then
		h.Transparency = 1
		for _, d in ipairs(h:GetChildren()) do if d:IsA("Decal") then d:Destroy() end end
		c = Instance.new("Part"); c.Name = "ClassicHead"; c.Color = h.Color
		c.Size = Vector3.new(2, 1, 1) * (h.Size.Y / 1.25) * 1.02
		c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.Massless = true
		c.TopSurface = Enum.SurfaceType.Smooth; c.BottomSurface = Enum.SurfaceType.Smooth
		local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Head; sm.Scale = Vector3.new(1.25, 1.25, 1.25); sm.Parent = c
		local d = Instance.new("Decal"); d.Name = "face"; d.Face = Enum.NormalId.Front; d.Parent = c
		c.CFrame = h.CFrame
		local w = Instance.new("WeldConstraint"); w.Part0 = h; w.Part1 = c; w.Parent = c
		c.Parent = m
	end
	c.face.Texture = "rbxassetid://" .. (K.FACE_IMG[preset or "neutral"] or K.FACE_IMG.neutral)
	return c
end

local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- stand an actor on the ground at pos, facing lookAt (a point)
K.line = 0          -- the Director bumps this at every line start
K.MIN_GAP = 3.8     -- these avatars are ~4 studs wide (jackets): closer than this and they pass through each other
local placed = {}   -- model -> line number it was placed in
local function spread(m, pos)
	for _ = 1, 3 do
		for other, line in pairs(placed) do
			if other ~= m and line == K.line and other.Parent and other.Name ~= "Tall" and m.Name ~= "Tall" then
				local r = other:FindFirstChild("HumanoidRootPart")
				if r then
					local d = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
					if d.Magnitude < K.MIN_GAP then
						local dir = d.Magnitude > 0.05 and d.Unit or Vector3.new(0, 0, 1)
						pos += dir * (K.MIN_GAP - d.Magnitude)
					end
				end
			end
		end
	end
	return pos
end

function K.place(name, pos, lookAt)
	if K.stopSwing then K.stopSwing(name) end   -- a swinging actor would snap back to the swing every frame
	local m = K.actor(name)
	if m:GetAttribute("Sitting") then m:SetAttribute("Sitting", nil); K.anim(name, "idle", 0.1) end   -- stand up from K.sit
	pos = spread(m, pos)
	placed[m] = K.line
	if m:GetAttribute("Pose") then m:SetAttribute("Pose", nil); m:SetAttribute("PoseStamp", (m:GetAttribute("PoseStamp") or 0) + 1) end
	local rp = RaycastParams.new(); rp.FilterDescendantsInstances = {workspace.Cast, workspace:FindFirstChild("FX")}; rp.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), rp)   -- 6 not 20: under a roof overhang a higher start lands the actor on the roof
	local y = hit and hit.Position.Y or 0.5
	local hum = m:FindFirstChildOfClass("Humanoid")
	local hip = hum.HipHeight + rootOf(m).Size.Y / 2
	local at = Vector3.new(pos.X, y + hip, pos.Z)
	local look = lookAt and Vector3.new(lookAt.X, at.Y, lookAt.Z) or (at + Vector3.new(0, 0, -1))
	if (look - at).Magnitude < 0.01 then look = at + Vector3.new(0, 0, -1) end
	m:PivotTo(CFrame.lookAt(at, look))
	-- actors parked offstage can sit in FallingDown; unanchored like that they topple over in the scene
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	local r = rootOf(m); r.AssemblyLinearVelocity = Vector3.zero; r.AssemblyAngularVelocity = Vector3.zero
	-- the whole body, not just the root: anchored limbs pin the actor in place and K.walk does nothing
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = false end end
	hum:ChangeState(Enum.HumanoidStateType.Running)
	pcall(function() r:SetNetworkOwner(nil) end)
	hum:MoveTo(at) -- cancel any old walk target
	do -- IMPROVEMENT 2026-11-23: in Play the dynamic Head came back visible and its own face showed through the drawn one
		local ch, hd = m:FindFirstChild("ClassicHead"), m:FindFirstChild("Head")
		if ch and hd then hd.Transparency = 1; for _, d in ipairs(hd:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end end end
	end
	-- 2026-11-24: actors with an animation pack already move in their idle; random fidget emotes (Action priority) wrecked their poses
	if not m:GetAttribute("Pack") then K.fidget(name) end
end

function K.show(name, on)
	for _, d in ipairs(K.actor(name):GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.LocalTransparencyModifier = on and 0 or 1 end
		if d:IsA("Decal") then d.Transparency = on and 0 or 1 end
	end
end

-- real (sun) shadow on/off.
function K.castShadow(name, on)
	for _, d in ipairs(K.actor(name):GetDescendants()) do if d:IsA("BasePart") then d.CastShadow = on end end
end

-- animation tracks (cached per actor)
-- per-actor animation pack (actor attribute Pack = "cartoony" ...): idle/walk/run with personality instead of the plain default
K.PACKS = {
	cartoony = {idle = 742637544, walk = 742640026, run = 742638842},
	stylish  = {idle = 616136790, walk = 616146177, run = 616140816},
	rthro    = {idle = 2510196951, walk = 2510202577, run = 2510198475},
	bubbly   = {idle = 910004836, walk = 910034870, run = 910025107},
	elder    = {idle = 845397899, walk = 845403856},
	zombie   = {idle = 616158929, walk = 616168032},
}
local LOCO = {idle = true, walk = true, run = true}
local tracks, current = {}, {}
function K.anim(name, which, fade, looped)
	local m = K.actor(name)
	tracks[m] = tracks[m] or {}
	local t = tracks[m][which]
	if not t then
		local pack = K.PACKS[m:GetAttribute("Pack") or ""]
		local id = (pack and pack[which]) or K.ANIM[which]   -- a string id (e.g. "active://..." from AnimationClipProvider) is used as is
		local a = Instance.new("Animation"); a.AnimationId = type(id) == "string" and id or "rbxassetid://" .. id
		local hum = m:FindFirstChildOfClass("Humanoid")
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		animator.PreferLodEnabled = false   -- docs: no throttled (stuttering) animation on far actors in wide shots
		t = animator:LoadAnimation(a); tracks[m][which] = t
		if not LOCO[which] then t.Priority = Enum.AnimationPriority.Action end   -- docs: packs play at Core; acting must win over them
	end
	for k, other in pairs(tracks[m]) do if k ~= which and other.IsPlaying then other:Stop(fade or 0.25) end end
	t.Looped = (looped ~= false) and K.LOOP[which] == true
	current[m] = which
	t:Play(fade or 0.25)
	-- a one-shot emote returns to idle when it ends (not when another action replaced it)
	if not t.Looped and which ~= "idle" then
		t.Stopped:Once(function() if current[m] == which then K.anim(name, "idle", 0.3) end end)
	end
	return t
end

-- IMPROVEMENT 2026-11-23 (backlog #1 acting): every placed actor FIDGETS while idle (shrug, tilt, nod...) so no shot is a frozen pose.
-- Stops by itself when the line changes (the next setup re-places the actor) or when a held action / walk replaces idle.
K.FIDGET = {"shrug", "tilt", "agree", "disagree"}
local fidgetTok = {}
function K.fidget(name, pool)
	local m = K.actor(name); if not m then return end
	local tok = {}; fidgetTok[m] = tok
	local line0 = K.line
	task.spawn(function()
		task.wait(0.3 + math.random() * 0.8)
		while fidgetTok[m] == tok and K.line == line0 and m.Parent do
			if (current[m] == "idle" or current[m] == nil) and m:GetAttribute("Sitting") == nil then
				local list = pool or K.FIDGET
				K.anim(name, list[math.random(#list)], 0.25)
			end
			task.wait(1.1 + math.random() * 1.2)
		end
	end)
end
function K.noFidget(name) local m = K.actor(name); if m then fidgetTok[m] = nil end end

-- POSE LIBRARY (2026-11-23, backlog #1 acting): story poses the emotes cannot do, set per joint on the CLIENT after the Animator
-- (joint.Transform in PreSimulation; works on AnimationConstraint and Motor6D rigs, tested in Play). The server only sets attributes.
-- Angles: shoulder/hip +X swings the limb FORWARD; elbow +X bends the forearm forward; knee -X bends back; waist +X leans BACK,
-- -X leans forward; neck -X looks down; left-arm -Z / right-arm +Z = outward.
local R = math.rad
local function A(x, y, z) return CFrame.Angles(R(x or 0), R(y or 0), R(z or 0)) end
K.POSES = {
	pockets  = {LeftShoulder = A(12, 0, -20), RightShoulder = A(12, 0, 20), LeftElbow = A(10, 0, 52), RightElbow = A(10, 0, -52), Neck = A(-6)},   -- hands tucked into the front pockets (3 variants tested in Play 2026-11-23; this one reads best)
	reach    = {RightShoulder = A(82, 0, 6), RightElbow = A(8), Waist = A(-8), Neck = A(-4)},                                         -- one arm out to something
	pull     = {LeftShoulder = A(68, 0, 10), RightShoulder = A(68, 0, -10), LeftElbow = A(28), RightElbow = A(28), Waist = A(20),
	            LeftHip = A(22), LeftKnee = A(-24), RightHip = A(-12)},                                                               -- both hands forward, leaning back, heels dug in
	shove    = {LeftShoulder = A(90, 0, 4), RightShoulder = A(90, 0, -4), LeftElbow = A(4), RightElbow = A(4), Waist = A(-15),
	            LeftHip = A(16), RightHip = A(-20)},                                                                                  -- both arms straight out, leaning in
	flinch   = {LeftShoulder = A(60, 0, -34), RightShoulder = A(60, 0, 34), LeftElbow = A(110), RightElbow = A(110), Waist = A(12), Neck = A(-14)},   -- arms up in front of the face
	holdup   = {RightShoulder = A(95, 0, -12), RightElbow = A(70), Neck = A(-6)},                                                      -- right hand raised in front to show an item (a key, a note)
	stiff    = {LeftShoulder = A(0, 0, -6), RightShoulder = A(0, 0, 6), Neck = A(0, 0, 14), Waist = A(-4, 0, 3)},                    -- arms dead straight, head tilted: the uncanny copy
	lookback = {Waist = A(0, 32, 0), Neck = A(0, 38, 0)},
	straight = {LeftShoulder = A(0, 0, 30), RightShoulder = A(0, 0, -30), LeftElbow = A(8), RightElbow = A(8)},                          -- arms hang at the sides (the AI rigs' A-pose rest holds them out)
	handup   = {RightShoulder = A(168, 0, -6), RightElbow = A(6), Neck = A(-4)},                                                     -- right arm straight up: "here!" / a raised hand                                                                         -- turns to look over the shoulder
}
-- server: K.pose("Sam", "pockets", 0.3); K.pose("Sam") releases. A pose stops the idle fidget (it would fight the arms).
function K.pose(name, pose, fade)
	local m = K.actor(name); if not m then return end
	if pose then K.noFidget(name) end
	m:SetAttribute("PoseFade", fade or 0.3); m:SetAttribute("Pose", pose)
	m:SetAttribute("PoseStamp", (m:GetAttribute("PoseStamp") or 0) + 1)
end
-- client: blends every actor toward its pose and adds a breathing / look-around layer so no person shot is a frozen frame
function K.clientPoses()
	local state, joints = {}, {}
	local JOINTS = {"Waist", "Neck", "Root", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "RightHip", "RightKnee"}
	local function jointsOf(m)
		local t = joints[m]
		if t then return t end
		t = {}
		for _, n in ipairs(JOINTS) do
			for _, d in ipairs(m:GetDescendants()) do
				if d.Name == n and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then t[n] = d; break end
			end
		end
		joints[m] = t; return t
	end
	local function hook(m)
		m:GetAttributeChangedSignal("PoseStamp"):Connect(function()
			local st = state[m] or {w = 0}
			local p = m:GetAttribute("Pose")
			if p and K.POSES[p] then st.name = p; st.target = 1 else st.target = 0 end
			st.rate = 1 / math.max(0.05, m:GetAttribute("PoseFade") or 0.3)
			state[m] = st
		end)
	end
	for _, m in ipairs(workspace.Cast:GetChildren()) do hook(m) end
	workspace.Cast.ChildAdded:Connect(hook)
	RunService.PreSimulation:Connect(function(dt)
		local t = os.clock()
		for i, m in ipairs(workspace.Cast:GetChildren()) do
			local J = jointsOf(m)
			local st = state[m]
			if st and st.name then
				st.w = st.w + math.clamp(st.target - st.w, -st.rate * dt, st.rate * dt)
				local u = st.w * st.w * (3 - 2 * st.w)
				for n, cf in pairs(K.POSES[st.name]) do local j = J[n]; if j then j.Transform = j.Transform:Lerp(cf, u) end end
				if st.w <= 0 and st.target == 0 then st.name = nil end
			end
			-- breathing + slow look-around (small: faces must stay readable)
			local ph = i * 1.7
			if J.Waist then J.Waist.Transform = J.Waist.Transform * A(math.sin(t * 1.7 + ph) * 1.4, 0, 0) end
			if J.Neck then J.Neck.Transform = J.Neck.Transform * A(math.sin(t * 0.6 + ph) * 2.2, math.noise(t * 0.25, ph) * 9, 0) end
			if J.LeftShoulder then J.LeftShoulder.Transform = J.LeftShoulder.Transform * A(0, 0, -math.sin(t * 1.7 + ph) * 1.2) end
			if J.RightShoulder then J.RightShoulder.Transform = J.RightShoulder.Transform * A(0, 0, math.sin(t * 1.7 + ph) * 1.2) end
		end
	end)
end

-- walk to a point at a speed (studs/s); plays walk then idle on arrival
-- studs/s at which each gait's feet match the ground at animation speed 1
-- shortcut: estimated, not measured; check one walk in Play (feet must not slide) on the next video and tune these two numbers
K.STRIDE = {walk = 14, run = 24}

function K.walk(name, to, speed)
	speed = speed or 8  -- a natural kid walk (was 5, a slow glide)
	local m = K.actor(name); local hum = m:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = speed
	local gait = speed > 10 and "run" or "walk"
	K.anim(name, gait)
	tracks[m][gait]:AdjustSpeed(math.max(speed / K.STRIDE[gait], 0.35))  -- leg speed follows ground speed
	hum:MoveTo(to)
	local c; c = hum.MoveToFinished:Connect(function() c:Disconnect(); K.anim(name, "idle", 0.3) end)
end

function K.turn(name, lookAt)
	local m = K.actor(name); local p = m:GetPivot().Position
	m:PivotTo(CFrame.lookAt(p, Vector3.new(lookAt.X, p.Y, lookAt.Z)))
end

-- Faces are animated on the CLIENT (FaceControls don't replicate): the server only sets attributes.
function K.face(name, preset, dur)
	local m = K.actor(name)
	if not m then return end
	local ch = m:FindFirstChild("ClassicHead") -- drawn face: a server-side Decal swap replicates, no client work
	if ch then if K.FACE_IMG[preset] then ch.face.Texture = "rbxassetid://" .. K.FACE_IMG[preset] end return end
	if RunService:IsServer() then
		m:SetAttribute("FaceDur", dur or 0.3); m:SetAttribute("Face", preset)
		m:SetAttribute("FaceStamp", (m:GetAttribute("FaceStamp") or 0) + 1)
		return
	end
	K.applyFace(m, preset, dur)
end

function K.applyFace(m, preset, dur)
	local head = m:FindFirstChild("Head")
	local fc = head and head:FindFirstChildOfClass("FaceControls")
	if not fc then return end
	local target = K.FACES[preset] or {}
	local keys = {}
	for _, p in ipairs({"JawDrop","LeftLipCornerPuller","RightLipCornerPuller","LeftCheekRaiser","RightCheekRaiser","LeftEyeClosed","RightEyeClosed","LeftEyeUpperLidRaiser","RightEyeUpperLidRaiser","LeftInnerBrowRaiser","RightInnerBrowRaiser","LeftOuterBrowRaiser","RightOuterBrowRaiser","LeftLipStretcher","RightLipStretcher","LeftLipCornerDown","RightLipCornerDown","Corrugator","LipPresser","LipsTogether","LeftBrowLowerer","RightBrowLowerer","MouthLeft"}) do
		keys[p] = {fc[p], target[p] or 0}
	end
	dur = dur or 0.3
	local t0 = os.clock()
	local c; c = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		for p, ab in pairs(keys) do fc[p] = ab[1] + (ab[2] - ab[1]) * u end
		if u >= 1 then c:Disconnect() end
	end)
end

-- mouth flap while a character talks for dur seconds (server sets TalkUntil; the client flaps the jaw)
-- clip (optional): a key in ReplicatedStorage.Lips (pipeline/lips.py writes it from the voice WAV) -> real lip sync instead of the flap
function K.talk(name, dur, clip)
	local m = K.actor(name)
	if not m then return end
	m:SetAttribute("TalkClip", clip); m:SetAttribute("TalkStart", workspace:GetServerTimeNow())
	m:SetAttribute("TalkUntil", workspace:GetServerTimeNow() + dur)
end

-- client: drive faces + jaw from the attributes above (call once from a LocalScript)
function K.clientFaces()
	local function hook(m)
		m:GetAttributeChangedSignal("FaceStamp"):Connect(function() K.applyFace(m, m:GetAttribute("Face"), m:GetAttribute("FaceDur")) end)
	end
	for _, m in ipairs(workspace.Cast:GetChildren()) do hook(m) end
	workspace.Cast.ChildAdded:Connect(hook)
	local lipsMod = game:GetService("ReplicatedStorage"):FindFirstChild("Lips")
	local LIPS = lipsMod and require(lipsMod) or {}
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, m in ipairs(workspace.Cast:GetChildren()) do
			local untilT = m:GetAttribute("TalkUntil")
			local head = m:FindFirstChild("Head")
			local fc = head and head:FindFirstChildOfClass("FaceControls")
			if fc and untilT then
				local clip = LIPS[m:GetAttribute("TalkClip") or ""]
				if clip and now < untilT then
					-- loudness envelope -> jaw; brightness of the sound (0 = "oo", 1 = "ee") -> rounded vs stretched lips
					local i = math.clamp(math.floor((now - m:GetAttribute("TalkStart")) * clip.fps) + 1, 1, #clip.v)
					local v = clip.v[i]
					fc.JawDrop = v * 0.7
					local s = clip.s and clip.s[i] or 0.5
					fc.Funneler = v * (1 - s) * 0.6
					fc.LeftLipStretcher = v * s * 0.35; fc.RightLipStretcher = v * s * 0.35
					fc.LipsTogether = v < 0.04 and 0.4 or 0
				elseif now < untilT then fc.JawDrop = 0.12 + 0.3 * math.abs(math.sin(now * 11) * math.sin(now * 4.3))
				elseif now < untilT + 0.2 then fc.JawDrop = 0; fc.Funneler = 0; fc.LipsTogether = 0 end
			end
		end
	end)
end

function K.setTime(clock) if K.cancelLook then K.cancelLook() end; Lighting.ClockTime = clock end

-- animate the clock (sun moves, shadows swing) over dur seconds
function K.tweenTime(from, to, dur)
	if K.cancelLook then K.cancelLook() end
	local t0 = os.clock()
	local c; c = RunService.Heartbeat:Connect(function()
		local x = math.clamp((os.clock() - t0) / dur, 0, 1)
		Lighting.ClockTime = from + (to - from) * x
		if x >= 1 then c:Disconnect() end
	end)
end

-- park actors far away, out of every shot
function K.offstage(...)
	for i, name in ipairs({...}) do
		if K.stopSwing then K.stopSwing(name) end
		local m = K.actor(name)
		if m then -- on the baseplate (it ends at +-300) and anchored, so nobody falls out of the world
			local root = rootOf(m); if root then root.Anchored = true end
			-- a grid well INSIDE the 600x600 baseplate (it ends at +-300), far from every set
			m:PivotTo(CFrame.new(196 + (i % 8) * 12, -40, 226 + math.floor(i / 8) * 12))   -- under the baseplate, anchored: out of every shot
		end
	end
end

-- everyone not listed goes offstage
function K.only(...)
	local keep = {}; for _, n in ipairs({...}) do keep[n] = true end
	local gone = {}
	for _, m in ipairs(workspace.Cast:GetChildren()) do if not keep[m.Name] then table.insert(gone, m.Name) end end
	K.offstage(table.unpack(gone))
end

-- length of a sun shadow per stud of height right now
function K.shadowRatio()
	local d = Lighting:GetSunDirection()
	return math.clamp(math.sqrt(d.X ^ 2 + d.Z ^ 2) / math.max(d.Y, 0.05), 1, 12)
end
-- horizontal direction a sun shadow points (away from the sun)
function K.shadowDir()
	local d = Lighting:GetSunDirection()
	return Vector3.new(-d.X, 0, -d.Z).Unit
end

------------------------------------------------------------------ fake shadows
local FX = workspace:FindFirstChild("FX")
if not FX and RunService:IsServer() then FX = Instance.new("Folder"); FX.Name = "FX"; FX.Parent = workspace end
FX = FX or workspace:WaitForChild("FX", 5)

-- A black silhouette copy of an actor (body + hair, no clothes layers).
-- Returns an object with :lie(dir, stretch), :raise(u) (0 = flat on the ground, 1 = standing 3D figure), :moveTo(feetPos), :destroy()
function K.shadow(name, opacity)
	local src = K.actor(name)
	local root = rootOf(src)
	local hipToFeet = src:FindFirstChildOfClass("Humanoid").HipHeight + root.Size.Y / 2
	local model = Instance.new("Model"); model.Name = name .. "_Shadow"
	local parts = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not (d.Parent:IsA("Accessory") and d.Parent:FindFirstChildWhichIsA("WrapLayer", true)) then
			local p = d:Clone()
			for _, c in ipairs(p:GetChildren()) do if not c:IsA("SpecialMesh") then c:Destroy() end end
			if p:IsA("MeshPart") then p.TextureID = "" end
			local sm = p:FindFirstChildOfClass("SpecialMesh"); if sm then sm.TextureId = "" end
			p.Color = Color3.new(0, 0, 0); p.Material = Enum.Material.SmoothPlastic; p.Reflectance = 0
			p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
			p.Transparency = 1 - (opacity or 0.8)
			p.Parent = model
			table.insert(parts, {p = p, rel = root.CFrame:ToObjectSpace(d.CFrame), size = d.Size})
		end
	end
	model.Parent = FX
	local S = {model = model, feet = (root.CFrame * CFrame.new(0, -hipToFeet, 0)).Position, dir = K.shadowDir(), stretch = K.shadowRatio(), u = 0, hip = hipToFeet}
	function S:apply()
		local u = self.u
		local ang = -math.pi / 2 * (1 - u)                 -- lying -> standing about the feet
		local thin = 0.04 + 0.96 * u                         -- paper thin -> full depth
		local long = self.stretch + (1 - self.stretch) * u   -- sun-length -> body length
		local base = CFrame.lookAt(self.feet + Vector3.new(0, 0.06 * (1 - u), 0), self.feet + Vector3.new(0, 0.06 * (1 - u), 0) + self.dir)
		base = base * CFrame.Angles(ang, 0, 0)
		for _, e in ipairs(parts) do
			local rp = e.rel.Position + Vector3.new(0, self.hip, 0)
			local pos = Vector3.new(rp.X, rp.Y * long, rp.Z * thin)
			local rot = e.rel - e.rel.Position
			e.p.Size = Vector3.new(e.size.X, e.size.Y * long, e.size.Z * thin)
			e.p.CFrame = base * CFrame.new(pos) * rot
		end
	end
	function S:lie(dir, stretch) if dir then self.dir = Vector3.new(dir.X, 0, dir.Z).Unit end; self.stretch = stretch or self.stretch; self.u = 0; self:apply() end
	function S:moveTo(feet) self.feet = feet; self:apply() end
	function S:opacity(a) for _, e in ipairs(parts) do e.p.Transparency = 1 - a end end
	-- animate standing up over dur seconds
	function S:rise(dur)
		local t0 = os.clock()
		local c; c = RunService.Heartbeat:Connect(function()
			local x = math.clamp((os.clock() - t0) / dur, 0, 1)
			self.u = x * x * (3 - 2 * x); self:apply()
			if x >= 1 then c:Disconnect() end
		end)
	end
	-- glide the (standing) figure to a point over dur seconds, facing where it goes
	function S:glide(to, dur)
		local from, t0 = self.feet, os.clock()
		local c; c = RunService.Heartbeat:Connect(function()
			local x = math.clamp((os.clock() - t0) / dur, 0, 1)
			if self.u > 0.5 then self.dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit end
			self.feet = from:Lerp(to, x); self:apply()
			if x >= 1 then c:Disconnect() end
		end)
	end
	function S:destroy() model:Destroy() end
	S:apply()
	return S
end

-- Keep a fake ground shadow under a moving actor, lagging `lag` seconds behind
function K.lateShadow(name, lag)
	local s = K.shadow(name, 0.7)
	local hist = {}
	local root = rootOf(K.actor(name))
	local c = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		table.insert(hist, {now, (root.CFrame * CFrame.new(0, -s.hip, 0)).Position})
		while #hist > 2 and hist[2][1] < now - lag do table.remove(hist, 1) end
		s.dir = K.shadowDir(); s.stretch = K.shadowRatio(); s:moveTo(hist[1][2])
	end)
	function s:stop() c:Disconnect(); self:destroy() end
	return s
end

function K.clearFX() for _, c in ipairs(FX:GetChildren()) do c:Destroy() end end

-- every Light in the Set on/off (porch, lamps, windows)
function K.lights(on, filter)
	for _, d in ipairs(workspace.Set:GetDescendants()) do
		if d:IsA("Light") and (not filter or d:GetFullName():find(filter)) then d.Enabled = on end
	end
end

------------------------------------------------------------------ props for insert shots
-- A flat board with big readable text (street sign, poster, calendar page...).
-- cf = where the board's FRONT faces (CFrame.lookAt(boardPos, cameraSidePoint)); size = Vector3 (width, height, depth)
-- opts: bg = Color3, fg = Color3, font = Enum.Font, material = Enum.Material, glow = bool, parent = Instance
function K.sign(text, cf, size, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = "Sign"; p.Anchored = true; p.CanCollide = false; p.CastShadow = true
	p.Size = size or Vector3.new(6, 3, 0.3); p.CFrame = cf
	p.Color = opts.bg or Color3.fromRGB(235, 228, 210); p.Material = opts.material or Enum.Material.SmoothPlastic
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60
	g.LightInfluence = opts.glow and 0 or 1; g.Parent = p
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(0.92, 0.88); t.Position = UDim2.fromScale(0.04, 0.06)
	t.BackgroundTransparency = 1; t.TextScaled = true; t.TextWrapped = true; t.Text = text
	t.Font = opts.font or Enum.Font.GothamBlack; t.TextColor3 = opts.fg or Color3.fromRGB(30, 30, 30); t.Parent = g
	p.Parent = opts.parent or workspace:FindFirstChild("FX") or workspace
	return p
end

-- Insert a Creator Store prop already stored in ServerStorage.Props by name, at a CFrame (clone).
function K.prop(name, cf, parent)
	local src = game:GetService("ServerStorage"):FindFirstChild("Props") and game.ServerStorage.Props:FindFirstChild(name)
	if not src then warn("no prop " .. name) return nil end
	local m = src:Clone(); m:PivotTo(cf); m.Parent = parent or workspace:FindFirstChild("FX") or workspace
	return m
end

-- A framed photo of two actors (polaroid). darkName's figure renders black.
-- cf: board facing the camera; size: Vector3 (≈ 2.4 x 2.8 x 0.08)
function K.photo(cf, size, leftName, rightName, darkName)
	local p = Instance.new("Part"); p.Name = "Photo"; p.Anchored = true; p.CanCollide = false
	p.Size = size or Vector3.new(2.4, 2.8, 0.08); p.CFrame = cf; p.Color = Color3.fromRGB(245, 243, 236)
	local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 120; g.Parent = p
	local vf = Instance.new("ViewportFrame"); vf.Size = UDim2.fromScale(0.86, 0.72); vf.Position = UDim2.fromScale(0.07, 0.06)
	vf.BackgroundColor3 = Color3.fromRGB(255, 196, 130); vf.Ambient = Color3.fromRGB(200, 180, 160); vf.LightColor = Color3.fromRGB(255, 220, 180); vf.LightDirection = Vector3.new(1, -0.3, 0); vf.Parent = g
	local wm = Instance.new("WorldModel"); wm.Parent = vf
	for i, name in ipairs({leftName, rightName}) do
		local src = K.actor(name)
		if src then
			src.Archivable = true
			local c = src:Clone()
			for _, d in ipairs(c:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
			c:PivotTo(CFrame.new((i - 1.5) * 3.2, 0, 0) * CFrame.Angles(0, math.pi, 0))
			if name == darkName then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("BasePart") then d.Color = Color3.new(0.02, 0.02, 0.03); d.Material = Enum.Material.SmoothPlastic; if d:IsA("MeshPart") then d.TextureID = "" end end
					if d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("SurfaceAppearance") then d:Destroy() end
				end
			end
			c.Parent = wm
		end
	end
	local cam = Instance.new("Camera"); cam.FieldOfView = 40; cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -10), Vector3.new(0, 0.9, 0)); cam.Parent = vf; vf.CurrentCamera = cam
	p.Parent = workspace:FindFirstChild("FX") or workspace
	return p
end

-- Turn an actor pitch black and back. Server-side colour change replicates.
function K.darken(name, on)
	for _, d in ipairs(K.actor(name):GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if on then
				if d:GetAttribute("C0") == nil then d:SetAttribute("C0", d.Color); d:SetAttribute("T0", d:IsA("MeshPart") and d.TextureID or "") end
				d.Color = Color3.new(0.02, 0.02, 0.03); if d:IsA("MeshPart") then d.TextureID = "" end
			elseif d:GetAttribute("C0") ~= nil then
				d.Color = d:GetAttribute("C0"); if d:IsA("MeshPart") then d.TextureID = d:GetAttribute("T0") end
			end
		end
		if d:IsA("Decal") then d.Transparency = on and 1 or 0 end
	end
end

-- LIGHTING LOOKS (top Shorts-bright by default; keep "night" for short climax beats only)
K.LOOKS = {
	-- day (3h): crisp midday, hard shadows, clear air, moving clouds (top Shorts-bright)
	day    = {clock = 13.2, bright = 3.2, exp = 0.2, amb = {100, 100, 108}, out = {135, 135, 145}, atm = {0.2, 0.0, {205, 220, 240}, {160, 180, 210}}, cc = {0.1, 0.22, {255, 253, 250}}, bloom = {0.08, 2.8}, soft = 0.05, clouds = 0.55},
	golden = {clock = 16.7, bright = 2.8, exp = 0.35, amb = {145, 125, 112}, out = {190, 160, 145}, atm = {0.26, 0.9, {255, 214, 170}, {200, 150, 120}}, cc = {0.07, 0.18, {255, 242, 228}}, bloom = {0.15, 2.6}, soft = 0.08, clouds = 0.5, lift = 0.03},
	sunset = {clock = 17.3, bright = 2.6, exp = 0.45, amb = {140, 118, 118}, out = {185, 150, 150}, atm = {0.3, 1.3, {255, 180, 140}, {190, 110, 120}}, cc = {0.08, 0.15, {255, 236, 222}}, bloom = {0.15, 2.6}, lift = 0.07},
	dusk   = {clock = 17.7, bright = 2.2, exp = 0.5, amb = {140, 138, 168}, out = {160, 160, 200}, atm = {0.3, 0.8, {150, 160, 210}, {90, 100, 150}}, cc = {0.08, 0.08, {232, 236, 255}}, bloom = {0.12, 2.7}, lift = 0.13},
	night  = {clock = 18.4, bright = 1.6, exp = 0.55, amb = {120, 125, 165}, out = {140, 150, 195}, atm = {0.32, 0.6, {115, 130, 190}, {60, 70, 120}}, cc = {0.1, 0.05, {215, 225, 255}}, bloom = {0.1, 2.8}, lift = 0.12},
	-- MOOD TRACK (2026-11-23 look test): one story-wide light plan, blended with K.look(name, seconds). No extra light objects:
	-- mood comes from ambient, haze, clouds, bloom and grade only. Ambient never drops below ~80 so faces stay readable (CamFill does the rest).
	calm      = {clock = 13.2, bright = 2.4, exp = -0.3, amb = {96, 96, 104}, out = {125, 125, 135}, atm = {0.24, 0.2, {205, 220, 240}, {160, 180, 210}}, cc = {0.12, 0.1, {255, 252, 246}}, bloom = {0.06, 2.8}, soft = 0.05, clouds = 0.6, lift = 0.04},
	uneasy    = {clock = 15.2, bright = 2.2, exp = -0.3, amb = {100, 104, 124}, out = {118, 124, 148}, atm = {0.35, 1.0, {170, 180, 205}, {125, 135, 165}}, cc = {0.25, 0.1, {255, 246, 236}}, bloom = {0.2, 1.0}, soft = 0.15, clouds = 0.7, lift = 0.07},
	scare     = {clock = 16.3, bright = 2.0, exp = -0.2, amb = {76, 82, 108}, out = {90, 98, 128}, atm = {0.42, 1.4, {150, 160, 188}, {110, 120, 150}}, cc = {0.3, 0.08, {255, 244, 232}}, bloom = {0.35, 0.95}, soft = 0.25, clouds = 0.9, lift = 0.08},
	aftermath = {clock = 16.9, bright = 2.3, exp = -0.15, amb = {145, 125, 112}, out = {190, 160, 145}, atm = {0.26, 0.9, {255, 214, 170}, {200, 150, 120}}, cc = {0.12, 0.2, {255, 240, 225}}, bloom = {0.2, 1.4}, soft = 0.1, clouds = 0.3, lift = 0.06},
}
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
function K.lookNow(name)
	local L = K.LOOKS[name]; if not L then return end
	Lighting.ClockTime = L.clock; Lighting.Brightness = L.bright; Lighting.ExposureCompensation = L.exp
	-- NOTE 2026-11-24: the docs say OutdoorAmbient is ignored with GlobalShadows off; an A/B in our place proved it is NOT (huge effect). Keep both.
	Lighting.Ambient = rgb(L.amb); Lighting.OutdoorAmbient = rgb(L.out)
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then a.Density, a.Haze, a.Color, a.Decay = L.atm[1], L.atm[2], rgb(L.atm[3]), rgb(L.atm[4]); a.Offset = 0.15; a.Glare = (name == "golden" or name == "sunset") and 0.2 or 0 end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then cc.Contrast, cc.Saturation, cc.TintColor = L.cc[1], L.cc[2], rgb(L.cc[3]); cc.Brightness = L.lift or 0 end
	local b = Lighting:FindFirstChildOfClass("BloomEffect")
	if b then b.Intensity, b.Threshold = L.bloom[1], L.bloom[2] end
	Lighting.ShadowSoftness = L.soft or 0.2
	Lighting.GlobalShadows = false   -- no shadows anywhere (every look, instant or blended, ends here)
	local cl = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds", workspace.Terrain)
	cl.Cover = L.clouds or 0; cl.Density = 0.7; cl.Color = Color3.fromRGB(255, 255, 255); cl.Enabled = (L.clouds or 0) > 0
end

-- K.look(name [, seconds]): no seconds = instant (old behaviour). With seconds the whole light (sun, ambient, haze, grade, bloom, clouds) blends from where it is now.
local lookToken = 0
function K.cancelLook() lookToken = lookToken + 1 end   -- a blend must not fight clock/interior/cloud set by a line
function K.look(name, dur)
	local L = K.LOOKS[name]; if not L then return end
	lookToken = lookToken + 1
	if not dur or dur <= 0 then return K.lookNow(name) end
	local my = lookToken
	local a = Lighting:FindFirstChildOfClass("Atmosphere"); local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local b = Lighting:FindFirstChildOfClass("BloomEffect"); local cl = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local f = {clock = Lighting.ClockTime, bright = Lighting.Brightness, exp = Lighting.ExposureCompensation, amb = Lighting.Ambient, out = Lighting.OutdoorAmbient,
		soft = Lighting.ShadowSoftness, clouds = cl and cl.Enabled and cl.Cover or 0}
	if a then f.ad, f.ah, f.ac, f.ak = a.Density, a.Haze, a.Color, a.Decay end
	if cc then f.cc1, f.cc2, f.cc3, f.cc4 = cc.Contrast, cc.Saturation, cc.TintColor, cc.Brightness end
	if b then f.b1, f.b2 = b.Intensity, b.Threshold end
	local function n(x, y, u) return x + (y - x) * u end
	task.spawn(function()
		local t0 = os.clock()
		while lookToken == my do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1); u = u * u * (3 - 2 * u)
			Lighting.ClockTime = n(f.clock, L.clock, u); Lighting.Brightness = n(f.bright, L.bright, u); Lighting.ExposureCompensation = n(f.exp, L.exp, u)
			Lighting.Ambient = f.amb:Lerp(rgb(L.amb), u); Lighting.OutdoorAmbient = f.out:Lerp(rgb(L.out), u); Lighting.ShadowSoftness = n(f.soft, L.soft or 0.2, u)
			if a then a.Density = n(f.ad, L.atm[1], u); a.Haze = n(f.ah, L.atm[2], u); a.Color = f.ac:Lerp(rgb(L.atm[3]), u); a.Decay = f.ak:Lerp(rgb(L.atm[4]), u) end
			if cc then cc.Contrast = n(f.cc1, L.cc[1], u); cc.Saturation = n(f.cc2, L.cc[2], u); cc.TintColor = f.cc3:Lerp(rgb(L.cc[3]), u); cc.Brightness = n(f.cc4, L.lift or 0, u) end
			if b then b.Intensity = n(f.b1, L.bloom[1], u); b.Threshold = n(f.b2, L.bloom[2], u) end
			if cl then cl.Enabled = true; cl.Cover = n(f.clouds, L.clouds or 0, u) end
			if u >= 1 then K.lookNow(name); break end   -- land exactly on the preset
			task.wait()
		end
	end)
end

-- STORY-FIRST SETS: a video lists the Set pieces it needs (SET_KEEP in its Part file);
-- at Play start everything else in workspace.Set is moved to ServerStorage.Hidden. Play-only: the saved place is untouched.
function K.declutter(keep)
	local want = {}
	for _, n in ipairs(keep or {}) do want[n] = true end
	local store = game:GetService("ServerStorage"):FindFirstChild("Hidden") or Instance.new("Folder")
	store.Name = "Hidden"; store.Parent = game:GetService("ServerStorage")
	local hidden = {}
	for _, c in ipairs(workspace.Set:GetChildren()) do
		if not want[c.Name] then c.Parent = store; hidden[#hidden + 1] = c.Name end
	end
	return hidden
end

-- indoors: after K.look, take the blown-out sky look out of the room: lower exposure, no haze, almost no bloom
function K.interior()
	K.cancelLook()
	Lighting.ExposureCompensation = -0.15; Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(96, 90, 84); Lighting.OutdoorAmbient = Color3.fromRGB(96, 90, 84)
	local a = Lighting:FindFirstChildOfClass("Atmosphere"); if a then a.Density = 0; a.Haze = 0 end
	local b = Lighting:FindFirstChildOfClass("BloomEffect"); if b then b.Intensity = 0.05; b.Threshold = 2.8 end
end

-- Keep waving (looping), speed 1 = friendly, 2.5+ = frantic "shooing a bird". speed 0 stops.
function K.wave(name, speed)
	if (speed or 1) <= 0 then   -- stop: never flash a wave first
		local m = K.actor(name)
		local t = m and tracks[m] and tracks[m].wave
		if t and t.IsPlaying then t:Stop(0.2) end
		if m then K.anim(name, "idle", 0.2) end
		return
	end
	local t = K.anim(name, "wave", 0.15)
	if not t then return end
	t.Looped = true; t:AdjustSpeed(speed)
	return t
end

-- "A cloud slid over the sun": the light drains to a dark, cold look over `down` s, holds, then the sun comes back.
function K.cloud(down, hold, up)
	K.cancelLook()
	local a = {Lighting.Brightness, Lighting.ExposureCompensation, Lighting.OutdoorAmbient, Lighting.Ambient}
	local b = {0.15, -0.9, Color3.fromRGB(40, 45, 70), Color3.fromRGB(25, 28, 45)}
	local function mix(u)
		Lighting.Brightness = a[1] + (b[1] - a[1]) * u
		Lighting.ExposureCompensation = a[2] + (b[2] - a[2]) * u
		Lighting.OutdoorAmbient = a[3]:Lerp(b[3], u); Lighting.Ambient = a[4]:Lerp(b[4], u)
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < down do mix((os.clock() - t0) / down); task.wait() end
		mix(1); task.wait(hold or 1)
		t0 = os.clock()
		while os.clock() - t0 < (up or 0.6) do mix(1 - (os.clock() - t0) / (up or 0.6)); task.wait() end
		mix(0)
	end)
end

-- sit an actor on a seat: hips at seatPos, facing lookAt. Anchored while seated; K.place frees them again.
function K.sit(name, seatPos, lookAt)
	K.stopSwing(name)
	local m = K.actor(name); local r = rootOf(m); local hum = m:FindFirstChildOfClass("Humanoid")
	r.Anchored = true
	local at = seatPos + Vector3.new(0, hum.HipHeight * 0.35 + r.Size.Y / 2, 0)
	-- place the ROOT at `at`, not the model pivot (AI-cast models have the pivot ~2.4 studs below the root: they floated above the chair)
	m:PivotTo(CFrame.lookAt(at, Vector3.new(lookAt.X, at.Y, lookAt.Z)) * r.CFrame:ToObjectSpace(m:GetPivot()))
	K.anim(name, "sit", 0.1)
	m:SetAttribute("Sitting", true)
end

-- a gentle swing: rocks a seated actor back and forth along their facing (amp studs, period s) until K.stopSwing(name)
local swinging = {}
function K.swing(name, amp, period)
	local m = K.actor(name); local base = m:GetPivot(); local t0 = os.clock()
	if swinging[name] then swinging[name]:Disconnect() end
	swinging[name] = RunService.Heartbeat:Connect(function()
		local ph = math.sin((os.clock() - t0) * 2 * math.pi / (period or 2.4))
		m:PivotTo(base * CFrame.new(0, math.abs(ph) * (amp or 0.6) * 0.3, -ph * (amp or 0.6)) * CFrame.Angles(ph * 0.12, 0, 0))
	end)
end
function K.stopSwing(name) if swinging[name] then swinging[name]:Disconnect(); swinging[name] = nil end end

-- a prop from ServerStorage.Props welded into an actor's hand (cleared by K.clearFX / K.drop)
function K.hold(name, propName, hand, offset)
	local m = K.actor(name); local h = m and m:FindFirstChild(hand or "RightHand")
	local p = h and K.prop(propName, h.CFrame * (offset or CFrame.new(0, -0.45, -0.1)))
	if not p then return end
	for _, d in ipairs(p:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = false; d.CanCollide = false; d.Massless = true end end
	local root = p:IsA("BasePart") and p or p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
	local w = Instance.new("WeldConstraint"); w.Part0 = h; w.Part1 = root; w.Parent = root
	p.Name = "Held_" .. name
	return p
end
function K.drop(name) local p = workspace.FX:FindFirstChild("Held_" .. name); if p then p:Destroy() end end

return K
