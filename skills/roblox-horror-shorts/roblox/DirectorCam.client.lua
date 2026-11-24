-- DirectorCam v2 (client): one camera per ~1.2 s beat, computed as a pure function of the timeline clock
-- (server time since Go = the clock that draws the white sync flash), so every retake is identical and stays in
-- sync with the voice. Bound to the render step right after Roblox's camera so the default camera never wins a frame.
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local SG = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
SG:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
for _ = 1, 20 do if pcall(SG.SetCore, SG, "TopbarEnabled", false) then break end task.wait(0.1) end
pcall(function() game:GetService("TextChatService").ChatWindowConfiguration.Enabled = false end)
game:GetService("UserInputService").MouseIconEnabled = false

local T = require(RS:WaitForChild("Timeline"))
local SPEC = {}
for _, m in ipairs(RS:WaitForChild("Parts"):GetChildren()) do
	local ok, part = pcall(require, m)
	if ok then for line, spec in pairs(part) do SPEC[line] = spec end end
end
local cam = workspace.CurrentCamera
local KitC = require(RS:WaitForChild("Kit"))
KitC.clientFaces()
KitC.clientPoses()   -- story poses + breathing (Kit POSE LIBRARY)
-- IMPROVEMENT 2026-11-23: preload every drawn face, so the first shot with a new face never shows the previous one
task.spawn(function()
	local list = {}
	for _, id in pairs(KitC.FACE_IMG) do local d = Instance.new("Decal"); d.Texture = "rbxassetid://" .. id; list[#list + 1] = d end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
local Framer = require(RS:WaitForChild("Framer"))
local CamLog = RS:WaitForChild("CamLog", 10)
local function log(s) print(s); if CamLog then CamLog:FireServer(s) end end

-- soft fill light that rides with the camera (film-set bounce) so faces in backlit shots read
local fill = Instance.new("Part"); fill.Name = "CamFill"; fill.Anchored = true; fill.CanCollide = false; fill.CanQuery = false; fill.Transparency = 1; fill.Size = Vector3.new(0.2, 0.2, 0.2); fill.Parent = workspace
local fl = Instance.new("PointLight"); fl.Range = 12; fl.Brightness = 0.8; fl.Color = Color3.fromRGB(255, 214, 180); fl.Shadows = false; fl.Parent = fill
-- depth of field: only on over-the-shoulder shots (the near shoulder goes soft)
-- foreground layer: a soft-focus bar at the edge of the 9:16 strip, riding in front of the lens (top Shorts hedges/fences/lockers). CanQuery=false: occlusion rays never see it.
local fgp = Instance.new("Part"); fgp.Name = "CamFG"; fgp.Anchored = true; fgp.CanCollide = false; fgp.CanQuery = false; fgp.CanTouch = false; fgp.CastShadow = false
fgp.Material = Enum.Material.SmoothPlastic; fgp.Size = Vector3.new(0.22, 4, 0.2); fgp.Transparency = 1; fgp.Parent = workspace
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect", Lighting)
dof.Enabled = false
-- sync flash: black before the story, ONE white flash from t=-0.5 to -0.4 (the recorder finds it to line up frames)
local gui = Instance.new("ScreenGui"); gui.IgnoreGuiInset = true; gui.DisplayOrder = 100; gui.ResetOnSpawn = false
local cover = Instance.new("Frame"); cover.Size = UDim2.fromScale(1, 1); cover.BorderSizePixel = 0; cover.BackgroundColor3 = Color3.new(0, 0, 0); cover.Parent = gui
gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
-- polaroid border for "photo" beats (polaroid = true), sized to the 9:16 strip
local pol = Instance.new("Frame"); pol.AnchorPoint = Vector2.new(0.5, 0.5); pol.Position = UDim2.fromScale(0.5, 0.5); pol.Size = UDim2.fromScale(1, 1)
pol.BackgroundTransparency = 1; pol.Visible = false; pol.Parent = gui
local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 9 / 16; ar.Parent = pol
for _, r in ipairs({{0, 0, 1, 0.06}, {0, 0.80, 1, 0.20}, {0, 0, 0.07, 1}, {0.93, 0, 0.07, 1}}) do
	local e = Instance.new("Frame"); e.BorderSizePixel = 0; e.BackgroundColor3 = Color3.fromRGB(246, 244, 238)
	e.Position = UDim2.fromScale(r[1], r[2]); e.Size = UDim2.fromScale(r[3], r[4]); e.Parent = pol
end

------------------------------------------------------------------------------------------------ hand-made keyframes (legacy, wide establishing only)
local function point(p)
	if typeof(p) == "Vector3" then return p end
	local m = Framer.actorModel(p.actor)
	return (m and m:GetPivot().Position or Vector3.zero) + (p.off or Vector3.zero)
end
local function sample(keys, u)
	if #keys == 1 or u <= keys[1][1] then local k = keys[1]; return point(k[2]), point(k[3]), k[4] or 50 end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if u <= b[1] then
			local x = Framer.sine((u - a[1]) / math.max(b[1] - a[1], 1e-3))
			return point(a[2]):Lerp(point(b[2]), x), point(a[3]):Lerp(point(b[3]), x), (a[4] or 50) + ((b[4] or 50) - (a[4] or 50)) * x
		end
	end
	local k = keys[#keys]; return point(k[2]), point(k[3]), k[4] or 50
end

------------------------------------------------------------------------------------------------ story beats -> automatic angle + move
local SCARY = {boom = true, stinger = true, drop = true}
local scares = {}
for _, e in ipairs(T.evs or {}) do if SCARY[e.sound] then table.insert(scares, e.t) end end
local function scareIn(a, b) for _, x in ipairs(scares) do if x >= a and x < b then return x end end end
local NLINES = #T.shots

-- a line (or the one before) that looks/points at something: its first insert tilts up onto it
local function REVEAL(line)
	for _, l in ipairs({line, line - 1}) do
		local s = T.shots[l]
		local tx = s and s.text and s.text:lower() or ""
		for _, w in ipairs({"look", "saw", "see", "stare", "point", "sign", "read", "above", "up at", "tower"}) do
			if tx:find(w, 1, true) then return true end
		end
	end
	return false
end

local function beatType(b, spec, c)
	if c.beat or spec.beat then return c.beat or spec.beat end
	if b.line == 1 then return "hook" end
	if (c.frame == "insert") or c.at then return "clue" end
	if scareIn(b.start, b.stop + 0.35) then return "scare" end
	if b.line > NLINES - 4 then return "ending" end
	local s = T.shots[b.line]
	if s and s.text and s.text:find('"') then return "dialogue" end
	return "plan"
end

local hist = {}          -- last shots' "angle|size"
local personHist = {}    -- angles of the last person shots (inserts excluded)
local dutchCount = 0
local flip = 1
local BUDGET = {n = 0, tight = 0, ext = 0, persons = 0}   -- tight-shot budget (2026-11-23): close/extreme <= ~25% of all shots, face-fill extremes <= 4 per video
local ALT = {eye_level = "three_quarter", three_quarter = "eye_level", low = "three_quarter", high = "eye_level",
	ots = "three_quarter", dutch = "three_quarter", custom = "eye_level"}

local function choose(b, spec, c)
	local bt = beatType(b, spec, c)
	local c0 = c
	do   -- TIGHT-SHOT BUDGET (41% close/extreme was too many): hook/scare/twist/ending keep their close-ups, the rest drop to medium when over budget
		local sz0 = Framer.effectiveSize(c)
		BUDGET.n = BUDGET.n + 1
		if (sz0 == "close" or sz0 == "extreme") and not c.actors then
			if not (bt == "scare" or bt == "twist" or bt == "hook" or bt == "ending") and BUDGET.tight + 1 > 0.25 * BUDGET.n then c = table.clone(c); c.frame = "medium"
			else BUDGET.tight = BUDGET.tight + 1 end
		end
	end
	local d = Framer.describe(c)
	local ctx = {line = b.line, dur = b.stop - b.start, partner = d.partner}
	if c ~= c0 then ctx.c = c end
	-- angle: explicit string preset > legacy height > automatic from the beat
	local angle = type(c.angle) == "string" and c.angle or nil
	if type(c.angle) == "number" then ctx.yaw = c.angle; ctx.yawExact = true end   -- explicit yaw: kept exactly (presets only set height/roll)
	if not angle then
		if c.height == "low" then angle = "low"
		elseif c.height == "high" or c.height == "top" then angle = "high"
		elseif type(c.height) == "number" then ctx.dy = c.height end
	end
	if not angle then
		if d.size == "insert" then angle = "eye_level"
		elseif bt == "hook" then angle = d.threat and "low" or "eye_level"
		elseif bt == "dialogue" then angle = (d.partner and flip > 0) and "ots" or "three_quarter"
		elseif bt == "clue" then angle = "high"
		elseif bt == "scare" then angle = d.hero and "high" or (d.threat and "low" or "three_quarter")
		elseif bt == "twist" then angle = dutchCount < 3 and "dutch" or "low"
		elseif bt == "ending" then angle = "eye_level"
		elseif d.hero and d.scared then angle = "high"
		elseif d.threat then angle = "low"
		else angle = (#hist % 2 == 0) and "three_quarter" or "eye_level" end
		flip = -flip
	end
	-- ANGLE VARIETY (2026-11-23: low/high/dutch fell to 15% when the tight-shot budget turned close-ups into mediums)
	if type(c.angle) ~= "string" and d.size ~= "insert" then
		if c ~= c0 and (angle == "eye_level" or angle == "three_quarter") then angle = (d.hero and d.scared) and "high" or "low" end
		if angle == "eye_level" and #personHist >= 2 and personHist[#personHist] == "eye_level" and personHist[#personHist - 1] == "eye_level" then
			angle = (d.hero and d.scared) and "high" or "low"
		end
	end
	if d.size ~= "insert" then table.insert(personHist, angle); if #personHist > 6 then table.remove(personHist, 1) end end
	if angle == "dutch" then
		if dutchCount >= 3 then angle = "low" else dutchCount += 1 end
	end
	-- never the same angle + size more than 3 shots in a row
	local key = angle .. "|" .. d.size
	if #hist >= 3 and hist[#hist] == key and hist[#hist - 1] == key and hist[#hist - 2] == key then
		angle = ALT[angle] or "three_quarter"; key = angle .. "|" .. d.size
	end
	table.insert(hist, key); if #hist > 8 then table.remove(hist, 1) end
	ctx.angle = angle
	-- three-quarter side: from the legacy numeric angle's sign, else alternate
	ctx.side = (ctx.yaw and ctx.yaw < 0) and -1 or ((#hist % 2 == 0) and 1 or -1)
	-- move: explicit > legacy push > automatic
	local snap = scareIn(b.start + 0.15, b.stop)
	local move, s = c.move, c.move_strength
	if not move and type(c.push) == "number" then move = c.push > 0 and "push_in" or "static"; s = c.push > 0 and c.push or nil end
	if not move then
		if bt == "scare" and snap then move = "snap_zoom"
		elseif bt == "scare" and scareIn(b.stop, b.stop + 0.35) then move = "hold"   -- the stillness before the scare
		elseif bt == "clue" and (b.k or 1) == 1 and REVEAL(b.line) then move = "tilt_up"   -- top Shorts reveal: what they look at / point to
		elseif bt == "hook" or bt == "clue" then move = "push_in"
		elseif bt == "ending" then move = "pull_out"
		end
	end
	-- top Shorts: long scare/clue shots push FAR (a wide house to the drain), not 6%
	if move == "push_in" and not s and (bt == "scare" or bt == "clue" or bt == "twist") and ctx.dur >= 2.5 then s = 0.22 end
	if not s and ctx.dur >= 1.5 and (move == "push_in" or (not move and Framer.effectiveSize(c) == "insert")) then s = 0.15 end
	if not s and Framer.effectiveSize(c) == "insert" and (move == nil or move == "push_in") then s = 0.12 end   -- short inserts too (2026-11-23: inserts were half the frozen time)   -- a still object needs a real push to read as motion
	-- scares and the twist on a single person's close-up become a face-filling shot
	if (bt == "scare" or bt == "twist") and c.frame == "close" and not c.actors and BUDGET.ext < 4 then ctx.c = table.clone(c); ctx.c.frame = "extreme"; BUDGET.ext = BUDGET.ext + 1 end
	if move == "snap_zoom" then ctx.snapAt = snap or (b.start + (b.stop - b.start) * 0.5) end
	ctx.move, ctx.s = move, s
	-- a faint handheld sway on every shot (top Shorts: the picture is never still), never on the held beat before a scare
	if c.handheld == nil and not c.shake then ctx.handheld = move ~= "hold" and move ~= "snap_zoom" else ctx.handheld = c.handheld or (c.shake and true) or false end
	return ctx, bt
end

------------------------------------------------------------------------------------------------ the render step
-- screen y (0 = top edge) of the highest head top among the shot's actors, from the current camera; 9 = no actor
local function headTop(plan)
	local y = 9
	for _, n in ipairs(plan.c.actors or {plan.c.focus or plan.c.actor}) do
		local m = Framer.actorModel(n)
		if m then
			local hd = m:FindFirstChild("Head")
			y = math.min(y, cam:WorldToViewportPoint(Framer.info(m).head + Vector3.new(0, hd and hd.Size.Y / 2 or 0.6, 0)).Y / cam.ViewportSize.Y)
		end
	end
	return y
end
local cur = nil   -- {key, plan, c, bt, peak, prev, m}
local vpLogged = false
local function finish(shot)
	if not shot or not shot.plan then return end
	if not shot.m then shot.m = Framer.measure(cam, shot.plan) end
	shot.htop = shot.htop or headTop(shot.plan)   -- very short shots: measure on their last frame
	local p, m = shot.plan, shot.m
	local who = shot.c.focus or shot.c.actor or (shot.c.actors and shot.c.actors[1]) or (shot.c.at and "at") or "-"
	log(string.format("[CAMQA] %s %s %s angle=%s move=%s beat=%s fov=%.0f dist=%.1f frac=%.2f face=%.3f nx=%.2f ny=%.2f safe916=%d ok169=%d occ=%s seen=%s vpeak=%.1f capped=%d pushes=%d blocked=%s htop=%.2f",
		shot.key, p.size, tostring(who), p.angle, p.move, shot.bt, p.vfov, p.dist or 0, m and m.frac or -1, m and m.face or -1,
		m and m.nx or -1, m and m.ny or -1, (m and m.safe916) and 1 or 0, (m and m.ok169) and 1 or 0,
		table.concat(p.occ or {"?", "?", "?"}, "/"), table.concat({(shot.occR or {})[1] or "?", (shot.occR or {})[2] or "?", (shot.occR or {})[3] or "?"}, "/"), shot.peak or 0, p.capped and 1 or 0, shot.pushes or 0, tostring(p.blocked), shot.htop))
end

local function onRender(dt)
	cam.CameraType = Enum.CameraType.Scriptable
	if not vpLogged and cam.ViewportSize.Y > 50 then vpLogged = true; log(string.format("[CAMVP] %d %d", cam.ViewportSize.X, cam.ViewportSize.Y)) end
	local go = workspace:GetAttribute("Go")
	local from = workspace:GetAttribute("From") or 0
	local t = go and (workspace:GetServerTimeNow() - go + from) or from
	if not go or t < from then
		cur = nil   -- never plan during the black lead-in: the scene isn't staged yet
		cover.Visible = true
		-- ONE white flash 0.5 s before the (partial) start: the recorder lines up frames on it (story time = from)
		cover.BackgroundColor3 = (go and t - from >= -0.5 and t - from < -0.4) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		return
	end
	cover.Visible = false
	local list = T.beats or T.shots
	local b = list[#list]
	for _, s in ipairs(list) do if t < s.stop then b = s; break end end
	if t >= T.END and cur and not cur.done then finish(cur); cur.done = true end
	local spec = SPEC[b.line]
	if not spec then return end
	local c
	if spec.beats and #spec.beats > 0 then c = spec.beats[((b.k or 1) - 1) % #spec.beats + 1] else c = spec.cam end
	if not c then return end
	pol.Visible = c.polaroid == true
	local u = math.clamp((t - b.start) / (b.stop - b.start), 0, 1)
	local key = b.line .. "." .. (b.k or 1)

	-- CUT: a new beat starts on this frame. Plan it now; no blend from the previous shot.
	if not cur or cur.key ~= key then
		finish(cur)
		cur = {key = key, c = c, peak = 0}
		if c.frame or c.at or c.focus then
			local ctx, bt = choose(b, spec, c)
			cur.bt = bt
			cur.plan = Framer.plan(ctx.c or c, ctx)
			-- foreground layer (explicit `fg` on a beat only; see note below)
			local sz = Framer.effectiveSize(ctx.c or c)
			if sz ~= "insert" then BUDGET.persons = BUDGET.persons + 1 end
			cur.fg = c.fg
			-- (auto foreground OFF 2026-11-23: Roblox near-blur does not soften a bar this close to the lens, so it read as a flat green slab; explicit `fg` per beat still works)
			cur.fgSide = (BUDGET.persons % 8 < 4) and -1 or 1
			-- FACE CHECK (2026-11-23, blank-head hunt): log any actor in this shot whose drawn face is missing/hidden or whose real Head shows
			local cc3 = ctx.c or c
			for _, n in ipairs(cc3.actors or {cc3.actor or cc3.focus}) do
				local m = n and Framer.actorModel(n)
				local ch = m and m:FindFirstChild("ClassicHead")
				local hd = m and m:FindFirstChild("Head")
				if m and not ch then if hd and hd.Transparency > 0.5 then log(string.format("[FACECHK] %s %s no ClassicHead and Head invisible (T=%.1f)", key, n, hd.Transparency)) end
				elseif ch then
					local f = ch:FindFirstChild("face")
					if not f or f.Texture == "" or f.Transparency > 0.5 or ch.Transparency > 0.5 or (hd and hd.Transparency < 1) then
						log(string.format("[FACECHK] %s %s tex=%s ftr=%.1f chtr=%.1f headtr=%.1f", key, n, f and f.Texture or "nil", f and f.Transparency or -1, ch.Transparency, hd and hd.Transparency or -1))
					end
				end
			end
		else
			cur.bt = "keys"
		end
	end

	local pos, look, fov, roll
	if cur.plan then
		pos, look, fov, roll = Framer.eval(cur.plan, u, t, dt)
		if cur.plan.replanned then
			cur.plan.replanned = nil; cur.prev = nil
			log(string.format("[REPLAN] %s cut=%.3f t=%.3f", key, b.start, t))
		end
		if cur.plan.jumped then cur.plan.jumped = nil; cur.prev = nil; log(string.format("[JUMP] %s t=%.3f", key, t)) end
	else
		pos, look, fov = sample(c, u)
	end
	if not pos then return end
	local cf = CFrame.lookAt(pos, look)
	if roll and roll ~= 0 then cf = cf * CFrame.Angles(0, 0, math.rad(roll)) end
	if cur.plan and cur.plan.ctx.handheld then   -- optional handheld sway (deterministic: noise of the timeline clock)
		local a = (type(c.shake) == "number" and c.shake) or 0.003
		cf = cf * CFrame.Angles(math.noise(t * 1.7, 1.3) * a, math.noise(t * 1.7, 7.1) * a, 0)
	end
	local planned = cf.Position
	cf = Framer.safe(cf, cur.plan and cur.plan.partner)
	if (cf.Position - planned).Magnitude > 0.05 then cur.pushes = (cur.pushes or 0) + 1 end
	cam.CFrame = cf
	cam.Focus = CFrame.new(look)   -- docs: Scriptable cameras must set Focus or lights far from it may not render
	cam.FieldOfView = fov
	fill.CFrame = cf * CFrame.new(0.8, 0.6, -1.2)
	local tightShot = cur.plan and (cur.plan.size == "close" or cur.plan.size == "extreme")
	fl.Brightness = math.max(tightShot and 0.55 or 0, math.clamp((Lighting.Brightness - 1.4) / 1.8, 0, 1) * 0.8)   -- close-ups keep a readable face in dark moods (2026-11-23: Leo's smile went black)   -- fill follows the look: day 0.8, golden 0.5, dusk ~0, night 0 (no glowing faces)
	local pl = cur.plan
	if pl and pl.dof then
		dof.Enabled = true; dof.FocusDistance = pl.dof; dof.InFocusRadius = 4; dof.NearIntensity = 0.75; dof.FarIntensity = 0.05
	elseif pl and (pl.size == "close" or pl.size == "extreme" or pl.size == "insert") then
		-- look test 2026-11-23: tight shots keep the subject sharp and melt the background (the Blender look)
		local fd = math.max(1.5, (cf.Position - look).Magnitude)
		dof.Enabled = true; dof.FocusDistance = fd; dof.InFocusRadius = math.max(1.2, fd * 0.3); dof.NearIntensity = 0.6; dof.FarIntensity = 0.55
	else
		dof.Enabled = false
	end
	if cur.fg then
		local f = type(cur.fg) == "table" and cur.fg or {}
		local d0 = 1.1
		local half = math.tan(math.rad(fov / 2)) * d0 * 0.5625   -- half width of the 9:16 strip at that distance
		fgp.Color = f.color or Color3.fromRGB(52, 92, 58); fgp.Size = Vector3.new(f.w or 0.22, 4, 0.2)
		fgp.CFrame = cf * CFrame.new((f.side or cur.fgSide or -1) * (half - 0.04), -0.15, -d0); fgp.Transparency = 0
		if not dof.Enabled then dof.Enabled = true; dof.FocusDistance = math.max(2, (cf.Position - look).Magnitude); dof.InFocusRadius = 1.5; dof.NearIntensity = 0.7; dof.FarIntensity = 0.1 end
	else
		fgp.Transparency = 1
	end

	-- measured camera speed RELATIVE to the subject (following a walker isn't a whip); cut frames and snap punches excluded
	local rel = planned - look
	if cur.prev and dt > 0 then
		local snapping = (cur.plan and cur.plan.move == "snap_zoom" and cur.plan.ctx.snapAt and t >= cur.plan.ctx.snapAt - 0.04 and t < cur.plan.ctx.snapAt + 0.2)
			or (cur.plan and cur.plan.move == "tilt_up")   -- a tilt-up reveal pans fast on purpose
		if not snapping then cur.peak = math.max(cur.peak, (rel - cur.prev).Magnitude / dt) end
	end
	cur.prev = rel
	if u >= 0.5 and not cur.m and cur.plan then cur.m = Framer.measure(cam, cur.plan); cur.htop = headTop(cur.plan) end
	if cur.plan then   -- runtime visibility at start / mid / end, from the real camera
		cur.occR = cur.occR or {}
		for k, uu in ipairs({0.12, 0.5, 0.88}) do
			if u >= uu and not cur.occR[k] then
				cur.occR[k] = Framer.seen(cam, cur.plan)
				if cur.occR[k] == "X" then log(string.format("[BLOCKER] %s %s.%d by %s", k, tostring(cur.plan.ctx.line), cur.plan.ctx.k or 0, tostring(Framer.blocker))) end
			end
		end
	end
end

Run:BindToRenderStep("DirectorCam", Enum.RenderPriority.Camera.Value + 1, onRender)
