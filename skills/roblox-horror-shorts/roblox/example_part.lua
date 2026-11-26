-- A minimal Part file (two script lines) to copy, staged on the starter street (sets/street.lua) with the starter cast
-- (cast_classic.lua). Real videos: one table entry per script line, a camera per beat. Every field and the K API:
-- references/part-format.md.
local V3 = Vector3.new
local Street = require(game:GetService("ReplicatedStorage"):WaitForChild("Street"))
local R = Street.R          -- street-local (x, z) -> world position on the ground
local function L(t, e) for k, v in pairs(e or {}) do t[k] = v end return t end

-- every line starts from a clean stage: no sun disc or glare on faces, no name tags, FX cleared, only the actors it names
local function stage(K, at)
	local Lg = game:GetService("Lighting")
	local sky = Lg:FindFirstChildOfClass("Sky"); if sky then sky.CelestialBodiesShown = false end
	local sr = Lg:FindFirstChildOfClass("SunRaysEffect"); if sr then sr.Intensity = 0 end
	local atm = Lg:FindFirstChildOfClass("Atmosphere"); if atm then atm.Glare = 0 end
	for _, m in ipairs(workspace.Cast:GetChildren()) do
		local h = m:FindFirstChildOfClass("Humanoid"); if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	end
	K.clearFX()
	local names = {}
	for n in pairs(at) do names[#names + 1] = n end
	K.only(table.unpack(names))
	for n, p in pairs(at) do K.place(n, p[1], p[2]) end   -- K.place only on a scene's first beat; walk inside a scene
end

-- camera side is -z: actors face -z (toward the camera), the houses are behind them at z = +34
local SAM = {R(20, 18), R(20, 0)}
local LEO = {R(15, 20), R(15, 0)}

return {
	SET_KEEP = {"Street"},   -- only these workspace.Set children stay visible in Play

	[1] = L({beat = "hook", look = "day",
		setup = function(K, S) stage(K, {Sam = SAM}); K.face("Sam", "scared", 0) end,
		run = function(K, S)
			S.at(S.say0, function() K.talk("Sam", S.say1 - S.say0) end)   -- the mouth flaps while he talks
			S.at(0.4, function() K.anim("Sam", "cower", 0.15) end)
		end,
		beats = {
			-- a hand-made keyframe shot (cold open): {u 0..1, camera position, look-at point, fov}; logged as [CAMKEY]
			{{0, R(20, 6) + V3(0, 6, 0), R(20, 18) + V3(0, 4, 0), 50}, {1, R(20, 9) + V3(0, 5, 0), R(20, 18) + V3(0, 4, 0), 44}},
			-- an insert on a hidden focus mark (sets build FM_* Models for doors, windows, signs)
			{frame = "insert", focus = "FM_Door", from = V3(0.1, 0.1, -1), move = "push_in", move_strength = 0.3},
		},
	}),

	[2] = L({look = "day",
		setup = function(K, S) stage(K, {Sam = SAM, Leo = {R(4, 16), R(4, 0)}}) end,
		run = function(K, S)
			task.spawn(K.walk, "Leo", LEO[1], 8)   -- walk, don't teleport (speed 7-9, run 12-16)
			S.at(0.6, function() K.face("Leo", "worried", 0.25); K.pose("Leo", "pockets", 0.3) end)
		end,
		beats = {
			{frame = "full", actor = "Leo", move = "track"},                       -- follow the walker
			{frame = "medium", actors = {"Sam", "Leo"}, move_strength = 0.22},   -- two-shot, ~4 studs apart
		},
	}),
}
