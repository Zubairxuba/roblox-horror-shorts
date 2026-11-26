-- Framer v2 (2026-11-21): shot composition + camera moves for Roblox Shorts (client side, used by DirectorCam).
--
-- Vertical-first: every shot is composed for the 9:16 centre strip of the recording, and kept clean for the 16:9
-- crop too (that crop drops the top ~8.5% to hide Roblox's corner buttons, so headroom is 13%).
-- Framing is set by DISTANCE from the vertical FOV:  distance = (subjectHeight / frac) / (2 * tan(FOV / 2)).
-- A camera is a pure function of (plan made at the cut, timeline time); nothing accumulates between frames except
-- the exponential smoothing of a tracked walker.
local F = {}

------------------------------------------------------------------------------------------------ config
F.CROP = 9 / 16                 -- 9:16 strip width / viewport height
F.MARGIN = 0.04                 -- safe margin inside the strip (fraction of strip width / frame height)
F.HEADROOM = 0.17               -- planned hair line; measured ~0.11-0.13 after the eye-level tilt (inside the 16:9 crop)
F.MIN_DIST = 3.2                -- never closer than this to the subject's head
F.SAFE = 2.2                    -- never closer than this to ANY face
F.FACE_MAX = 0.125              -- planned face size for medium/full/wide (close/extreme set their own via SHOT.face) (measured +6-13% in play after perspective/push/snap; QA limit 0.16)
F.SPEED_CAP = 6                 -- studs/s of camera travel inside a shot (snap_zoom punches are exempt)
F.FOV_MIN, F.FOV_MAX = 35, 70

-- frac = subject height / frame height. face = head height / frame height, when set it decides the framing
-- (user 2026-11-23: match top Shorts: close = chest-up, extreme = the face fills the frame, for scares/twist).
F.SHOT = {
	extreme = {frac = 0.72, fov = 40, eye = 0.0, move = "push_in", face = 0.45},   -- narrow lens: keeps the lens >= MIN_DIST from the face
	close  = {frac = 0.72, fov = 55, eye = 0.0,  move = "push_in", face = 0.30},
	medium = {frac = 0.57, fov = 58, eye = -0.3, move = "push_in"},  -- no still shots (user 2026-11-23: ~30% frozen frames vs ~1% for top Shorts)
	full   = {frac = 0.44, fov = 60, eye = -0.6, move = "orbit"},
	wide   = {frac = 0.23, fov = 65, eye = 2.5,  move = "orbit"},   -- a pull-out barely changes a far frame (dry run 2026-11-23: 1.7 s frozen); orbit parallax reads
	insert = {frac = 0.55, fov = 50, eye = 0.0,  move = "push_in"},
}
local ORDER = {insert = 0, extreme = 1, close = 2, medium = 3, full = 4, wide = 5}
local WIDER = {extreme = "close", close = "medium", medium = "full", full = "wide"}

-- yaw = degrees off the subject's front; h = camera height mode; roll = dutch tilt
F.ANGLE = {
	eye_level     = {yaw = 0,  h = "eye"},
	three_quarter = {yaw = 38, h = "eye"},
	low           = {yaw = 12, h = "waist"},
	high          = {yaw = 12, h = "high"},
	ots           = {yaw = 0,  h = "eye"},
	dutch         = {yaw = 22, h = "eye", roll = 7},
	custom        = {yaw = 0,  h = "eye"},
}
F.MOVE = {static = 0.015, push_in = 0.06, pull_out = 0.08, orbit = 10, snap_zoom = 0.12, track = 0, hold = 0, tilt_up = 1.0}
local LIMIT = {static = {0, 0.02}, push_in = {0.04, 0.3}, pull_out = {0.04, 0.12}, orbit = {0, 15}, snap_zoom = {0.06, 0.18}, tilt_up = {0.4, 1.0}}

------------------------------------------------------------------------------------------------ helpers
local function actorModel(name)
	if type(name) ~= "string" then return nil end
	local fx = workspace:FindFirstChild("FX")
	local m = workspace.Cast:FindFirstChild(name) or (fx and fx:FindFirstChild(name))
	return (m and m:IsA("Model")) and m or nil   -- 2026-11-23: a sign/note/arm Part in FX is an OBJECT, not an actor (Framer.info(Part) crashed the camera and froze the shot)
end
F.actorModel = actorModel

local function flat(v) local f = Vector3.new(v.X, 0, v.Z); return f.Magnitude > 1e-3 and f.Unit or Vector3.new(1, 0, 0) end
local function rotY(v, deg) return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v) end
local function sine(u) return 0.5 - 0.5 * math.cos(math.pi * math.clamp(u, 0, 1)) end
F.sine = sine

-- head centre, top of hair, feet, height, root, facing of an actor (or a shadow figure)
function F.info(m)
	local head = m:FindFirstChild("Head")
	local root = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	local feetY
	if root and hum then
		feetY = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	else
		local cf, s = m:GetBoundingBox(); feetY = cf.Y - s.Y / 2
	end
	local hp = head and head.Position or (root and root.Position + Vector3.new(0, 2, 0)) or m:GetPivot().Position
	local top = hp.Y + (head and head.Size.Y * 0.5 or 0.6)
	for _, a in ipairs(m:GetChildren()) do   -- hats and hair stick out above the head
		local h = a:IsA("Accessory") and a:FindFirstChild("Handle")
		if h and h.Position.Y > hp.Y - 0.5 and h.Position.Y < hp.Y + 2.5 then top = math.max(top, h.Position.Y + h.Size.Y * 0.5) end
	end
	top = math.min(top, hp.Y + 2.2)
	return {head = hp, top = top, feet = feetY, H = math.max(top - feetY, 2), headH = head and head.Size.Y or 1.2,
		root = root and root.Position or hp, look = (root and root.CFrame or m:GetPivot()).LookVector, model = m}
end

local function rayParams(models)
	local rp = RaycastParams.new()
	local ex = {}
	for _, m in ipairs(models) do table.insert(ex, m) end
	local fx = workspace:FindFirstChild("FX"); if fx then table.insert(ex, fx) end
	local fill = workspace:FindFirstChild("CamFill"); if fill then table.insert(ex, fill) end
	local rack = workspace:FindFirstChild("FaceRack"); if rack then table.insert(ex, rack) end
	rp.FilterDescendantsInstances = ex; rp.FilterType = Enum.RaycastFilterType.Exclude
	return rp
end

local function groundY(at)
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), rayParams({}))
	return hit and hit.Position.Y or (at.Y - 3)
end

-- first VISIBLE blocker between a and b (glass, invisible collision boxes and effects don't block the view)
local function blockAlong(a, b, rp)
	local ex = table.clone(rp.FilterDescendantsInstances)
	for _ = 1, 6 do
		local h = workspace:Raycast(a, b - a, rp)
		if not h then return nil end
		local part = h.Instance
		if part.Transparency < 0.6 and part.LocalTransparencyModifier < 0.6 then return h end
		table.insert(ex, part); rp.FilterDescendantsInstances = ex
	end
	return nil
end

-- an object to frame: an Instance, a name (FX first, then Set, then workspace), or the text sign nearest a point
local function findObject(name)
	if typeof(name) == "Instance" then return name end
	if type(name) ~= "string" then return nil end
	local fx = workspace:FindFirstChild("FX")
	local set = workspace:FindFirstChild("Set")
	return (fx and fx:FindFirstChild(name, true)) or (set and set:FindFirstChild(name, true)) or workspace:FindFirstChild(name, true)
end
local function signNear(pt)
	local op = OverlapParams.new()
	local best, bd
	for _, p in ipairs(workspace:GetPartBoundsInRadius(pt, 2.5, op)) do
		if p:FindFirstChildWhichIsA("SurfaceGui") and math.max(p.Size.X, p.Size.Y) <= 8 then   -- not the store front
			local d = (p.Position - pt).Magnitude
			if not bd or d < bd then best, bd = p, d end
		end
	end
	return best
end

------------------------------------------------------------------------------------------------ what a shot looks at
-- Walkers and groups of 3+ get at least a full-body shot.
function F.effectiveSize(c)
	local size = c.frame or "medium"
	if size == "insert" or c.at or (c.focus and not actorModel(c.focus)) then return "insert" end
	local names = c.actors or {c.focus or c.actor}
	local need = size
	if #names >= 3 and ORDER[need] < ORDER.full then need = "full" end
	for _, n in ipairs(names) do
		local m = actorModel(n)
		local r = m and m:FindFirstChild("HumanoidRootPart")
		if r then
			local v = r.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 1.5 and ORDER[need] < ORDER.full then need = "full" end
		end
	end
	return need
end

-- what an insert must not count as a blocker: the holder, the object, and the prop the object is part of (a button's plaque)
local function selfModels(holder, obj)
	local t = {}
	if holder then table.insert(t, holder) end
	if obj then
		local prop = obj.Parent
		local set = workspace:FindFirstChild("Set")
		table.insert(t, (prop and prop:IsA("Model") and prop ~= set and prop ~= workspace) and prop or obj)
	end
	return t
end

local function subject(c, size)
	local sh = F.SHOT[size] or F.SHOT.medium
	if size == "insert" then
		local obj = c.focus and findObject(c.focus)
		local at = c.at and (typeof(c.at) == "Vector3" and c.at
			or (actorModel(c.at.actor) and actorModel(c.at.actor):GetPivot().Position + (c.at.off or Vector3.zero)))
		if not obj and at then obj = signNear(at) end
		local center, h, w, front
		if obj then
			local cf, s
			if obj:IsA("Model") then cf, s = obj:GetBoundingBox() elseif obj:IsA("BasePart") then cf, s = obj.CFrame, obj.Size end
			if cf then
				center = cf.Position; h = math.max(s.Y, 0.4); w = math.max(s.X, s.Z)
				local g = obj:IsA("BasePart") and obj:FindFirstChildWhichIsA("SurfaceGui")
				if g then   -- the text's face (not always Front): a label on a box side, or on a lid (Top: no horizontal front, use c.from)
					local n = cf:VectorToWorldSpace(Vector3.fromNormalId(g.Face))
					if math.abs(n.Y) < 0.7 then front = n; w = (g.Face == Enum.NormalId.Left or g.Face == Enum.NormalId.Right) and s.Z or s.X end
				end
			end
		end
		if not center then
			if not at then return nil end
			center = at; h = (c.span or 2.4) * sh.frac; w = h
		end
		local span = c.span or (h / sh.frac)
		local holder = typeof(c.at) == "table" and actorModel(c.at.actor)
		if not obj and not holder then span = math.max(span, 7) end   -- nothing there: show WHERE it is, not 3 studs of pavement
		-- crowd = true: the people acting in an insert (a hand, a ruler swing, the kids' feet) are its content, not a blocked view
		-- a `from` that points clearly UP means "look down at it" (a lid, a hand, something on the ground): keep that tilt
		local tilt
		if c.from then
			local fh = Vector3.new(c.from.X, 0, c.from.Z).Magnitude
			if c.from.Y > 0.25 * math.max(fh, 0.01) then tilt = math.min(c.from.Y / math.max(fh, 0.01), 3) end
		end
		return {kind = "object", center = center, span = span, halfW = w / 2, front = front, models = selfModels(holder, obj), obj = obj,   -- the object (and the prop it belongs to) never blocks its own insert
			 guessed = obj == nil, crowd = true, tilt = tilt,
			eyeY = center.Y, top = center.Y + h / 2, feet = center.Y - h / 2, H = h}
	end
	local names = c.actors or {c.focus or c.actor}
	local infos, models = {}, {}
	for _, n in ipairs(names) do
		local m = actorModel(n)
		if m then table.insert(infos, F.info(m)); table.insert(models, m) end
	end
	if #infos == 0 then return nil end
	local top, feet, H, headH, sx, sz, ey, look = -math.huge, math.huge, 0, 0, 0, 0, 0, Vector3.zero
	local tight = ORDER[size] <= 3
	for _, i in ipairs(infos) do
		top = math.max(top, i.top); feet = math.min(feet, i.feet); H = math.max(H, i.H); headH = math.max(headH, i.headH)
		local w = tight and 1 or 0.5           -- tight shots centre the HEAD, wide ones the body
		sx += i.head.X * w + i.root.X * (1 - w); sz += i.head.Z * w + i.root.Z * (1 - w)
		ey += i.head.Y; look += i.look
	end
	local n = #infos
	local walking = false
	for _, i in ipairs(infos) do
		local r = i.model:FindFirstChild("HumanoidRootPart")
		if r and Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude > 1.5 then walking = true end
	end
	local span = sh.face and (headH / sh.face * (c.dist or 1)) or math.max(H / sh.frac * (c.dist or 1), headH / F.FACE_MAX)
	local cy
	if tight then
		cy = top + F.HEADROOM * span - span / 2                  -- hair top on the headroom line
	else
		cy = (top + feet) / 2 + 0.02 * span                      -- body a touch below the frame centre
		cy = math.max(cy, top + F.HEADROOM * span - span / 2)   -- never lets the head rise above the headroom line
	end
	return {kind = "actors", center = Vector3.new(sx / n, cy, sz / n), span = span, infos = infos, models = models,
		look = look, eyeY = ey / n, top = top, feet = feet, H = H, walking = walking, crowd = ORDER[size] >= ORDER.full, faceShot = size == "extreme"}
end

F._subject = subject
------------------------------------------------------------------------------------------------ geometry
-- distance: fit the visible height (vertical FOV) AND the subject's width inside the 9:16 strip with margin
local function distanceFor(sub, dirH, vfov)
	local tv = math.tan(math.rad(vfov / 2))
	local d = (sub.span / 2) / tv
	local th = tv * F.CROP * (1 - 2 * F.MARGIN)
	local need
	if sub.infos then
		local across = Vector3.new(-dirH.Z, 0, dirH.X)
		local c = sub.center:Dot(across)
		local lo, hi = 0, 0
		for _, i in ipairs(sub.infos) do
			local x = i.head:Dot(across) - c
			local m = sub.faceShot and 0.6 or (#sub.infos > 1 and 1.45 or 1.15)   -- shoulders (groups: more room); a face shot crops the shoulders on purpose
			lo = math.min(lo, x - m); hi = math.max(hi, x + m)
		end
		need = math.max(-lo, hi) * (sub.walking and #sub.infos > 1 and 1.3 or 1)
	else
		need = sub.halfW * 1.2   -- signs: room for the push-in, text never touches the edge
	end
	return math.max(d, need / th, F.MIN_DIST)
end

-- camera position for a horizontal direction, a distance along the view, and an angle's height mode
local function camAt(sub, dirH, dist, A, size, extraDy)
	local sh = F.SHOT[size] or F.SHOT.medium
	if sub.tilt then   -- an insert that looks DOWN at its object: the same distance, raised along the tilt
		local a = math.atan(sub.tilt)
		local pos = sub.center + dirH * dist * math.cos(a) + Vector3.new(0, dist * math.sin(a) + (extraDy or 0), 0)
		local g = groundY(pos)
		if pos.Y < g + 0.9 then pos = Vector3.new(pos.X, g + 0.9, pos.Z) end
		return pos
	end
	local camY
	if A.h == "waist" then camY = sub.feet + 0.42 * sub.H
	elseif A.h == "high" then camY = sub.top + 0.32 * sub.span
	else camY = (sub.eyeY or sub.center.Y) + sh.eye end
	camY += extraDy or 0
	local dy = camY - sub.center.Y
	local pos = sub.center + dirH * dist + Vector3.new(0, dy, 0)   -- horizontal distance = the fitted distance
	local g = groundY(pos)
	if pos.Y < g + 0.9 then pos = Vector3.new(pos.X, g + 0.9, pos.Z) end
	return pos
end

-- distance scale and extra yaw for a move at shot progress u (pure function); snapAt = timeline seconds
local function moveAt(move, s, u, tAbs, snapAt)
	local e = sine(u)
	if move == "push_in" or move == "static" then return 1 - s * e, 0
	elseif move == "pull_out" then return 1 + s * e, 0
	elseif move == "orbit" then return 1, s * (e - 0.5)
	elseif move == "tilt_up" then return 1 - 0.05 * e, 0   -- a slow push under the tilt, so the end isn't frozen
	elseif move == "track" then return 1 - 0.08 * e, 0     -- a slow walker alone gives too little motion
	elseif move == "snap_zoom" then
		local creep = 0.03 * e   -- creeps in before the punch: a dead-still wait read as a frozen frame
		if snapAt and tAbs and tAbs >= snapAt then return 1 - creep - s * sine(math.clamp((tAbs - snapAt) / 0.12, 0, 1)), 0 end
		return 1 - creep, 0
	end
	return 1, 0   -- hold, track
end
F.moveAt = moveAt

-- average ground velocity of the people in a shot, and the same subject moved by d (for checking where walkers will be)
local function walkVel(sub)
	local v, n = Vector3.zero, 0
	for _, i in ipairs(sub.infos or {}) do
		local r = i.model:FindFirstChild("HumanoidRootPart")
		if r then v += Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z); n += 1 end
	end
	return n > 0 and v / n or Vector3.zero
end

local function shiftSub(sub, d)
	local out = table.clone(sub); out.center = sub.center + d; out.infos = {}
	for _, i in ipairs(sub.infos) do local j = table.clone(i); j.head = i.head + d; table.insert(out.infos, j) end
	return out
end

-- occlusion from a camera point: head / torso / shoulders must be clear; legs only reported
local function occlusion(sub, pos, rp)
	local pts = {}
	if sub.kind == "object" then
		-- centre AND the corners of what the insert shows: a near trunk off-centre still fills the frame
		local across = flat(pos - sub.center); across = Vector3.new(-across.Z, 0, across.X)
		local hw, hh = math.max(sub.halfW or 0.5, sub.span * 0.25), (sub.H or 1) * 0.4
		pts = {{sub.center, true}}
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do
			local q = sub.center + across * hw * sx + Vector3.new(0, hh * sy, 0)
			table.insert(pts, {Vector3.new(q.X, math.max(q.Y, groundY(q) + 0.3), q.Z), true})
		end end
	else
		local across = flat(pos - sub.center); across = Vector3.new(-across.Z, 0, across.X)
		for _, i in ipairs(sub.infos) do
			local torso = Vector3.new(i.head.X, i.head.Y - math.min(1.6, math.max(i.head.Y - i.feet, 0) * 0.4), i.head.Z)
			table.insert(pts, {i.head, true}); table.insert(pts, {torso, true})
			table.insert(pts, {torso + across * 0.8, true}); table.insert(pts, {torso - across * 0.8, true})
			table.insert(pts, {Vector3.new(i.head.X, (i.feet + 1.2), i.head.Z), false})
		end
	end
	local upper, legs, free = false, false, math.huge
	for _, e in ipairs(pts) do
		local d = (pos - e[1]).Magnitude
		local h = blockAlong(e[1], pos, rp) or blockAlong(pos, e[1], rp)   -- both ways: a ray that STARTS inside a trunk/post never hits it
		if h then
			free = math.min(free, h == true and 0 or math.min((h.Position - e[1]).Magnitude, d))
			local castHit = h ~= true and workspace:FindFirstChild("Cast") and h.Instance:IsDescendantOf(workspace.Cast)
			if e[2] and not (castHit and sub.crowd) then upper = true; F.blocker = h.Instance:GetFullName() else legs = true end
		end
	end
	return upper, legs, free
end

-- runtime check from the ACTUAL camera to the subject as it is now (QA; catches walkers moving behind trees, late props)
function F.seen(cam, plan)
	local sub = subject(plan.c, plan.size) or plan.sub0
	local up, lg = occlusion(sub, cam.CFrame.Position, rayParams(sub.models or {}))
	return up and "X" or (lg and "legs" or "ok")
end

------------------------------------------------------------------------------------------------ describing a shot (for auto choices)
-- hero (Sam), threat (Tall / Threat attribute: the grumpy adult, monsters), scared face, partner for ots / 180 rule
function F.describe(c)
	local names = c.actors or {c.focus or c.actor}
	local m = names[1] and actorModel(names[1])
	local d = {size = F.effectiveSize(c)}
	if not m or d.size == "insert" then return d end
	d.hero = m.Name == (workspace:GetAttribute("Hero") or "Sam")
	d.threat = m:GetAttribute("Threat") == true or m.Name == "Tall"
	local f = m:GetAttribute("Face")
	d.scared = f == "scared" or f == "worried" or f == "cry" or f == "sad"
	if c.actors and #c.actors > 1 then return d end
	local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head")
	if not r then return d end
	local best, bd
	for _, o in ipairs(workspace.Cast:GetChildren()) do
		local orr = o ~= m and (o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Head"))
		if orr then
			local dd = (orr.Position - r.Position).Magnitude
			if dd < 8 and dd > 1.5 and (not bd or dd < bd) then best, bd = o.Name, dd end
		end
	end
	d.partner = best
	return d
end

------------------------------------------------------------------------------------------------ planning (once, at the cut)
local YAWS = {0, 15, -15, 30, -30, 45, -45, 60, -60, 75, -75, 90, -90}
F.axes = {}   -- 180-degree rule memory: pair key -> {n = camera-side normal, line = last line seen}

-- ctx = {angle = preset name, yaw = extra yaw (legacy numeric angle), side = +1/-1, dy = extra height,
--        move = name, s = strength, dur = shot seconds, snapAt = timeline s, line = script line, partner = name}
function F.plan(c, ctx)
	local size = F.effectiveSize(c)
	local A = F.ANGLE[ctx.angle] or F.ANGLE.eye_level
	local angleName = F.ANGLE[ctx.angle] and ctx.angle or "eye_level"
	local move = ctx.move or (F.SHOT[size] or F.SHOT.medium).move
	local s = ctx.s or F.MOVE[move] or 0
	local lim = LIMIT[move]; if lim then s = math.clamp(s, lim[1], lim[2]) end
	local vfov = math.clamp(c.fov or (F.SHOT[size] or F.SHOT.medium).fov, F.FOV_MIN, F.FOV_MAX)
	local sub0 = subject(c, size)
	if not sub0 then return nil end

	-- the subject's "front"
	local base
	if sub0.kind == "object" then
		base = sub0.front or (c.from and c.from.Magnitude > 0 and flat(c.from)) or Vector3.new(1, 0, 0)
	elseif #sub0.infos > 1 then
		local a, b = sub0.infos[1].head, sub0.infos[#sub0.infos].head
		local across = flat(b - a)
		local perp = Vector3.new(-across.Z, 0, across.X)
		local hint = c.side or (sub0.look.Magnitude > 0.3 and sub0.look) or Vector3.new(1, 0, 0)
		base = perp:Dot(hint) >= 0 and perp or -perp
	else
		base = flat(sub0.infos[1].look)
	end

	-- 180-degree rule: one camera side per character pair, kept for nearby lines
	local axisN, pm
	if ctx.partner and sub0.kind == "actors" and #sub0.infos == 1 then
		pm = actorModel(ctx.partner)
		if pm then
			local key = (sub0.infos[1].model.Name < ctx.partner) and (sub0.infos[1].model.Name .. "|" .. ctx.partner) or (ctx.partner .. "|" .. sub0.infos[1].model.Name)
			local ax = flat(F.info(pm).head - sub0.infos[1].head)
			local nrm = Vector3.new(-ax.Z, 0, ax.X)
			local mem = F.axes[key]
			if mem and math.abs((ctx.line or 0) - mem.line) <= 2 then
				if nrm:Dot(mem.n) < 0 then nrm = -nrm end
			else
				if nrm:Dot(base) < 0 then nrm = -nrm end   -- first shot of the pair: the side the speaker faces
			end
			if not ctx._axKey then ctx._axKey, ctx._axPrev = key, mem end   -- so a re-plan after the cut can undo a stale side
			F.axes[key] = {n = nrm, line = ctx.line or 0}
			axisN = nrm
		end
	end

	local rpSub = rayParams(sub0.models)
	local yaw0 = ctx.yawExact and ctx.yaw or ((ctx.yaw or 0) + A.yaw * (ctx.side or 1))   -- a scene's own yaw (often set to dodge a pole) wins
	if sub0.kind == "actors" and #sub0.infos > 1 then yaw0 = math.clamp(yaw0, -15, 15) end   -- two-shots: both faces, similar size

	-- over-the-shoulder: camera just behind the partner's shoulder on the 180 side, the speaker centred
	if angleName == "ots" and pm and sub0.kind == "actors" then
		local spk = sub0.infos[1]
		local pi = F.info(pm)
		local u = flat(spk.head - pi.head)
		local side = axisN or Vector3.new(-u.Z, 0, u.X)
		-- behind the listener and far enough aside that the line of sight passes their (wide) shoulder:
		-- lateral offset s with s * D / (D + back) >= half-width + clearance, so only a slice shows at the strip edge
		local D = math.max((spk.head - pi.head).Magnitude, 2.5)
		local back, halfW = 2.4, 1.9
		local sOff = (halfW + 0.45) * (D + back) / D
		local pos = pi.head - u * back + side * sOff + Vector3.new(0, 0.45, 0)
		local facing = flat(spk.look):Dot(-u) > 0.3 and flat(pi.look):Dot(u) > 0.0   -- they actually face each other
		local dist = (sub0.center - pos).Magnitude
		local fov = math.clamp(2 * math.deg(math.atan((sub0.span / 2) / dist)), F.FOV_MIN, F.FOV_MAX)
		local rp = rayParams({spk.model, pm})
		local up = occlusion(sub0, pos, rp)
		local spread = (spk.head - pi.head).Magnitude
		if not up and facing and spread >= 2.5 and spread <= 9 then
			return {c = c, size = size, angle = "ots", A = A, move = "push_in", s = 0.04, vfov = fov, sub0 = sub0,
				center0 = sub0.center, offset = function(sc) return (pos - sub0.center) * sc end, roll = 0,
				dur = ctx.dur or 1.2, occ = {"ok", "ok", "ok"}, legs = false, blocked = false, partner = pm.Name,
				dof = dist, t0 = os.clock(), ctx = ctx, peak = 0}
		end
		angleName = "three_quarter"; A = F.ANGLE.three_quarter; yaw0 = ctx.yawExact and ctx.yaw or ((ctx.yaw or 0) + A.yaw * (ctx.side or 1))
	end

	-- search: yaw steps -> shorter move -> next wider size; every candidate checked at start, middle and end of the move
	local fallback
	local sizes = {size}
	do local z = size; while WIDER[z] do z = WIDER[z]; table.insert(sizes, z) end end
	local TIGHTER = {wide = "full", full = "medium", medium = "close"}
	do local z = size; while TIGHTER[z] do z = TIGHTER[z]; table.insert(sizes, z) end end
	for _, sz in ipairs(sizes) do
		local sub = sz == size and sub0 or subject(c, sz)
		if sub then
			local fovZ = math.clamp(c.fov or F.SHOT[sz].fov, F.FOV_MIN, F.FOV_MAX)
			for _, scale in ipairs({1, 0.5}) do
				local sm = s * scale
				for _, off in ipairs(YAWS) do
					local dirH = rotY(base, yaw0 + off)
					if not (axisN and dirH:Dot(axisN) < -0.05) and not (sub.kind == "object" and math.abs(off) > 30) then   -- text must stay readable
						local dist = distanceFor(sub, dirH, fovZ)
						local occ, legsAny, anyUpper, freeMin = {}, false, false, math.huge
						for k, u in ipairs({0, 0.25, 0.5, 0.75, 1}) do
							local tA = (move == "snap_zoom" and u >= 1 and ctx.snapAt) and (ctx.snapAt + 1) or nil   -- end state = punched in
							local ds, dyaw = moveAt(move, sm, u, tA, ctx.snapAt)
							local d = walkVel(sub) * (ctx.dur or 1.2) * u
							local subU = d.Magnitude > 0.3 and shiftSub(sub, d) or sub
							local pos = camAt(sub, rotY(dirH, dyaw), dist * ds, A, sz, ctx.dy) + d
							local up, lg, fr = occlusion(subU, pos, rpSub)
							occ[k] = up and "X" or (lg and "legs" or "ok")
							anyUpper = anyUpper or up; legsAny = legsAny or lg; freeMin = math.min(freeMin, fr)
						end
						if not anyUpper then
							local plan = {c = c, size = sz, angle = angleName, A = A, move = move, s = sm, vfov = fovZ, sub0 = sub,
								center0 = sub.center, dirH = dirH, dist = dist, roll = A.roll or 0, dur = ctx.dur or 1.2,
								occ = occ, legs = legsAny, blocked = false, t0 = os.clock(), ctx = ctx, partner = ctx.partner,
								shifted = (sz ~= size) or (scale ~= 1) or (off ~= 0)}
							F.capSpeed(plan)
							return plan
						end
						if not fallback or freeMin > fallback.free then
							fallback = {sz = sz, sub = sub, dirH = dirH, dist = math.min(dist, math.max(freeMin - 0.6, F.MIN_DIST)), occ = occ, free = freeMin, fov = fovZ, s = sm}
						end
					end
				end
			end
		end
	end
	if angleName ~= "eye_level" and not ctx._retry then   -- a low/high/3-4 camera can be what's blocked (ceilings, posts)
		local c2 = table.clone(ctx); c2.angle = "eye_level"; c2.yaw = 0; c2._retry = true
		local p2 = F.plan(c, c2)
		if p2 and not p2.blocked then return p2 end
	end
	local fb = fallback
	if fb.dist < 0.75 * distanceFor(fb.sub, fb.dirH, fb.fov) then fb.dist = distanceFor(fb.sub, fb.dirH, fb.fov) end   -- keep the framing; a foreground object beats a face-filling lens
	local plan = {c = c, size = fb.sz, angle = angleName, A = A, move = move, s = fb.s, vfov = fb.fov, sub0 = fb.sub,
		center0 = fb.sub.center, dirH = fb.dirH, dist = fb.dist, roll = A.roll or 0, dur = ctx.dur or 1.2, occ = fb.occ,
		legs = true, blocked = true, t0 = os.clock(), ctx = ctx, partner = ctx.partner, shifted = true}
	F.capSpeed(plan)
	return plan
end

-- offset of the camera from the subject centre at progress u (pure)
local function offsetAt(plan, u, tAbs)
	if plan.offset then return plan.offset(plan.move == "push_in" and 1 - plan.s * sine(u) or 1) end   -- ots drifts in slowly: no frozen frames
	local ds, dyaw = moveAt(plan.move, plan.s, u, tAbs, plan.ctx.snapAt)
	return camAt(plan.sub0, rotY(plan.dirH, dyaw), plan.dist * ds, plan.A, plan.size, plan.ctx.dy) - plan.sub0.center
end

-- cap camera speed: sample the move, scale its strength down if any segment is faster than F.SPEED_CAP
function F.capSpeed(plan)
	if plan.offset or plan.move == "snap_zoom" or plan.move == "hold" or plan.move == "track" then plan.peak = 0; return end
	for _ = 1, 4 do
		local peak, prev = 0, nil
		for i = 0, 10 do
			local p = offsetAt(plan, i / 10)
			if prev then peak = math.max(peak, (p - prev).Magnitude / (plan.dur / 10)) end
			prev = p
		end
		plan.peak = peak
		if peak <= F.SPEED_CAP or plan.s <= 0 then return end
		plan.s *= F.SPEED_CAP / peak * 0.95
		plan.capped = true
	end
end

------------------------------------------------------------------------------------------------ per frame (pure f(plan, t))
function F.eval(plan, u, tAbs, dt)
	local sub = subject(plan.c, plan.size)
	if not sub then return nil end
	-- actors are placed by the server at the cut and arrive here a few frames later: re-plan once, right after the cut
	-- (also when they only TURNED: a front planned from the old facing films them from behind)
	local turned = sub.look and plan.sub0.look and sub.look.Magnitude > 0.3 and plan.sub0.look.Magnitude > 0.3
		and flat(sub.look):Dot(flat(plan.sub0.look)) < 0.7
	if os.clock() - plan.t0 < 0.6 and ((sub.center - plan.center0).Magnitude > 3 or turned) and not plan.replannedOnce then
		if plan.ctx._axKey then F.axes[plan.ctx._axKey] = plan.ctx._axPrev end   -- the stale plan's 180-degree side must not stick
		local np = F.plan(plan.c, plan.ctx)
		if np then
			local t0 = plan.t0
			for k, v in pairs(np) do plan[k] = v end
			plan.t0 = t0; plan.replanned = true; plan.replannedOnce = true
		end
		sub = subject(plan.c, plan.size) or sub
	end
	-- a teleport mid-shot (the scene re-placed the actor) is a cut made by the staging: re-plan on this frame
	if plan.lastC and (sub.center - plan.lastC).Magnitude > 3.5 and not plan.replanned then
		local np = F.plan(plan.c, plan.ctx)
		if np then for k, v in pairs(np) do plan[k] = v end; plan.jumped = true end
		sub = subject(plan.c, plan.size) or sub
	end
	-- a sign / prop created by the server at the cut reaches this client a few frames later: re-plan once it exists
	if plan.sub0.guessed and not plan.objReplan and sub.kind == "object" and not sub.guessed and os.clock() - plan.t0 < 1.0 then
		local np = F.plan(plan.c, plan.ctx)
		if np then local t0 = plan.t0; for k, v in pairs(np) do plan[k] = v end; plan.t0 = t0; plan.replanned = true; plan.objReplan = true end
		sub = subject(plan.c, plan.size) or sub
	end
	plan.lastC = sub.center
	-- centre: locked at the cut (no idle sway); a tracked walker, or a subject that walks off, is followed smoothly
	local center = plan.center0
	if plan.move == "track" or plan.follow or (sub.center - plan.center0).Magnitude > ((ORDER[plan.size] or 3) <= ORDER.close and 0.4 or 1.5) then
		plan.follow = true
		local rate = (ORDER[plan.size] or 3) <= ORDER.close and 14 or 6   -- tight shots follow faster: the lag of rate 6 was half a close-up frame
		local a = 1 - math.exp(-rate * (dt or 1 / 30))
		plan.cs = (plan.cs or plan.center0):Lerp(sub.center, a)   -- starts from where the camera was: no snap
		center = plan.cs
	end
	local off = offsetAt(plan, u, tAbs)
	if sub.infos and #sub.infos > 1 and plan.dirH and os.clock() - plan.t0 > 0.6 then
		-- (after the arrival window; members far from the group are still arriving and are ignored)
		local near = {}
		for _, i in ipairs(sub.infos) do if (Vector3.new(i.head.X, 0, i.head.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude < 15 then table.insert(near, i) end end
		if #near > 1 then
			local need = math.min(distanceFor({infos = near, center = sub.center, span = plan.sub0.span, walking = true}, plan.dirH, plan.vfov) * 1.08 / plan.dist, 1.6)
			local target = math.max(1, need)
			local step = (F.SPEED_CAP * 0.5 / math.max(plan.dist, 1)) * (dt or 1 / 30)   -- at most half the speed cap, in studs/s
			plan.wide = math.clamp(target, (plan.wide or 1) - step, (plan.wide or 1) + step)
		end
		off *= (plan.wide or 1)
	end
	local pos = center + off
	if plan.move == "tilt_up" then   -- reveal: the lens starts s spans below the subject (feet, ground) and tilts up onto it
		plan.tiltH = plan.tiltH or math.max(plan.center0.Y - groundY(pos), 2)   -- height above the ground (ray at the lens: one at the subject hits the subject)
		local drop = plan.s * plan.tiltH * (1 - sine(u / 0.6))   -- s=1 starts on the ground; lands by 60%: QA measures framing at 50%
		return pos, center - Vector3.new(0, drop, 0), plan.vfov, plan.roll
	end
	return pos, center, plan.vfov, plan.roll
end

------------------------------------------------------------------------------------------------ safety
-- keep the lens out of every face (hand-made moves included) and above the ground; `ignore` = the ots partner
function F.safe(cf, ignore, noGround)   -- noGround: a hand-placed camera under a canopy must not be lifted onto it
	local pos, back = cf.Position, -cf.LookVector
	for _, m in ipairs(workspace.Cast:GetChildren()) do
		local h = m.Name ~= ignore and m:FindFirstChild("Head")
		if h and h.LocalTransparencyModifier < 1 then
			local d = (h.Position - pos).Magnitude
			if d < F.SAFE and (h.Position - pos):Dot(cf.LookVector) > 0 then pos += back * (F.SAFE - d) end
		end
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), rayParams({}))
	if not noGround and hit and pos.Y < hit.Position.Y + 0.7 then pos = Vector3.new(pos.X, hit.Position.Y + 0.7, pos.Z) end
	return CFrame.lookAt(pos, pos + cf.LookVector, cf.UpVector)
end

------------------------------------------------------------------------------------------------ QA measurement
-- Where the subject sits in the 9:16 strip and the 16:9 crop, computed from the actual viewport.
function F.measure(cam, plan)
	local vs = cam.ViewportSize
	local cw = vs.Y * F.CROP
	local x0 = (vs.X - cw) / 2
	local cut169 = math.max(0, 1 - (vs.X * 9 / 16) / vs.Y)   -- the 16:9 crop drops this fraction off the top
	local function P(w) local v = cam:WorldToViewportPoint(w); return (v.X - x0) / cw, v.Y / vs.Y, v.Z end
	local r = {cut169 = cut169}
	local pts = {}
	local c = plan.c
	if plan.size == "insert" then
		local sub = subject(plan.c, "insert") or plan.sub0
		local obj = sub.obj
		if obj then
			local cf, s
			if obj:IsA("Model") then cf, s = obj:GetBoundingBox() else cf, s = obj.CFrame, obj.Size end
			for _, dx in ipairs({-0.5, 0.5}) do for _, dy in ipairs({-0.5, 0.5}) do for _, dz in ipairs({-0.5, 0.5}) do
				table.insert(pts, (cf * CFrame.new(s.X * dx, s.Y * dy, s.Z * dz)).Position)
			end end end
		else
			table.insert(pts, sub.center)
		end
		local nx, ny = P(sub.center)
		r.nx, r.ny, r.face = nx, ny, -1
		local _, ty = P(Vector3.new(sub.center.X, sub.top, sub.center.Z))
		local _, by = P(Vector3.new(sub.center.X, sub.feet, sub.center.Z))
		r.frac = math.abs(by - ty)
	else
		local names = c.actors or {c.focus or c.actor}
		local m = names[1] and actorModel(names[1])
		if not m then return nil end
		local i = F.info(m)
		local right = cam.CFrame.RightVector
		local hd = m:FindFirstChild("Head")
		local hh = hd and hd.Size.Y / 2 or 0.6
		local nx, ny = P(i.head)
		local _, fy = P(i.head + Vector3.new(0, hh, 0))
		local _, ty = P(Vector3.new(i.head.X, i.top, i.head.Z))
		local _, by = P(Vector3.new(i.head.X, i.feet, i.head.Z))
		r.nx, r.ny = nx, ny
		r.face = math.abs(ny - fy) * 2
		r.frac = math.abs(by - ty)
		r.top = ty
		local torso = i.head - Vector3.new(0, 1.6, 0)
		pts = {Vector3.new(i.head.X, i.top, i.head.Z), i.head + right * 0.7, i.head - right * 0.7, torso + right * 1.1, torso - right * 1.1}
		if plan.size == "extreme" or plan.size == "close" then pts = {Vector3.new(i.head.X, i.top, i.head.Z), i.head + right * 0.6, i.head - right * 0.6} end   -- face / chest-up shot: only the head must fit (chest-up crops the shoulders by design)
		for k = 2, #names do
			local o = actorModel(names[k])
			if o then local oi = F.info(o); table.insert(pts, oi.head + right * 0.7); table.insert(pts, oi.head - right * 0.7) end
		end
	end
	local safe, ok169 = true, true
	for _, w in ipairs(pts) do
		local x, y, z = P(w)
		if z <= 0 or x < F.MARGIN or x > 1 - F.MARGIN or y < 0.01 or y > 0.99 then safe = false end
		if y < cut169 + 0.008 then ok169 = false end
	end
	r.safe916, r.ok169 = safe, ok169
	return r
end

return F
