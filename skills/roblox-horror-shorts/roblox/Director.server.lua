-- Director (server): runs every shot's setup/run at its exact start time. Starts when workspace attribute Go (server time) is set.
-- Optional attribute From (seconds) starts the timeline part-way, for recording one part at a time.
local RS = game:GetService("ReplicatedStorage")
local K = require(RS.Kit)
local T = require(RS.Timeline)
-- hands-free start: the recorder writes roblox/go.txt ("go <from>") on the local bridge once it is filming
task.spawn(function()
	local HS = game:GetService("HttpService")
	while not workspace:GetAttribute("Go") do
		local ok, body = pcall(HS.GetAsync, HS, "http://127.0.0.1:8765/roblox/go.txt?" .. os.clock())
		if ok and body:match("^go") then
			workspace:SetAttribute("From", tonumber(body:match("^go%s+([%d%.]+)")) or 0)
			workspace:SetAttribute("Go", workspace:GetServerTimeNow() + 1.5)
		end
		task.wait(0.3)
	end
end)

-- camera QA log: DirectorCam sends one line per shot; it is written to projects/<Project>/qa/camlog.txt on the bridge
-- (Studio's output window truncates long logs). workspace attribute Project = the project folder name.
do
	local HS = game:GetService("HttpService")
	local CamLog = RS:FindFirstChild("CamLog") or Instance.new("RemoteEvent")
	CamLog.Name = "CamLog"; CamLog.Parent = RS
	local buf, dirty = {}, false
	CamLog.OnServerEvent:Connect(function(_, s) if type(s) == "string" then table.insert(buf, s); dirty = true end end)
	task.spawn(function()
		while true do
			task.wait(1.5)
			local proj = workspace:GetAttribute("Project")
			if dirty and proj then
				dirty = false
				pcall(HS.PostAsync, HS, "http://127.0.0.1:8765/projects/" .. proj .. "/qa/camlog.txt", table.concat(buf, "\n") .. "\n", Enum.HttpContentType.TextPlain)
			end
		end
	end)
end

local SPEC = {}
for _, m in ipairs(RS.Parts:GetChildren()) do
	local ok, part = pcall(require, m)
	if ok then for line, spec in pairs(part) do SPEC[line] = spec end else warn("part failed: " .. m.Name .. " " .. tostring(part)) end
end

K.closeBy = {}   -- line -> actors framed close/extreme in it (Kit skips arm-raising acting for them)
for line, spec in pairs(SPEC) do
	for _, b in ipairs(type(line) == "number" and spec.beats or {}) do
		if (b.frame == "close" or b.frame == "extreme") and b.actor then K.closeBy[line] = K.closeBy[line] or {}; K.closeBy[line][b.actor] = true end
	end
end

if SPEC.SET_KEEP then K.declutter(SPEC.SET_KEEP) end   -- story-first set: only what this video needs

for _, m in ipairs(workspace.Cast:GetChildren()) do
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end   -- parked actors stay anchored; K.place makes them physical when a scene uses them
	K.anim(m.Name, "idle", 0)
end
if K.actor("Milo") then K.castShadow("Milo", false) end -- Milo never has a shadow (he is not in every cast)

local function shotAt(t) for _, s in ipairs(T.shots) do if t < s.stop then return s end end end

workspace:GetAttributeChangedSignal("Go"):Connect(function()
	local go = workspace:GetAttribute("Go")
	local from = workspace:GetAttribute("From") or 0
	local now = function() return workspace:GetServerTimeNow() - go + from end -- story time
	for _, s in ipairs(T.shots) do
		local spec = SPEC[s.line]
		if spec and s.stop > from then
			local S = {line = s.line, dur = s.stop - s.start, say0 = s.sayStart - s.start, say1 = s.sayEnd - s.start}
			function S.ev(id) return T.ev[id] - s.start end           -- event time, relative to this shot
			function S.now() return now() - s.start end
			function S.waitUntil(rel) local d = s.start + rel - now(); if d > 0 then task.wait(d) end end
			function S.at(rel, fn) task.delay(math.max(0, s.start + rel - now()), fn) end
			task.delay(math.max(0, s.start - now()), function()
				K.line = s.line
				if spec.look then K.look(spec.look, spec.blend) end   -- spec.blend = seconds to melt from the previous mood (nil = instant)
				if spec.clock then K.setTime(spec.clock) end
				if spec.setup then local ok, e = pcall(spec.setup, K, S); if not ok then warn("setup " .. s.line .. ": " .. e) end end
				if spec.run then task.spawn(function() local ok, e = pcall(spec.run, K, S); if not ok then warn("run " .. s.line .. ": " .. e) end end) end
			end)
		end
	end
end)
