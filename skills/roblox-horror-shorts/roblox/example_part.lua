-- A minimal Part file (two script lines) to copy. Real videos: one table entry per script line, cameras per beat.
-- See references/part-format.md for every field and the K API.
local V3 = Vector3.new
local function L(t, e) for k, v in pairs(e or {}) do t[k] = v end return t end

return {
	SET_KEEP = {"Ground", "Mailbox"},   -- only these workspace.Set children stay visible in Play

	[1] = L({beat = "hook", look = "uneasy",
		setup = function(K, S)
			K.clearFX(); K.only("Sam")
			K.place("Sam", V3(0, 0, 0), V3(0, 0, 10))
			K.face("Sam", "scared", 0.2)
		end,
		run = function(K, S)
			S.at(S.say0, function() K.talk("Sam", S.say1 - S.say0) end)   -- K.talk(name, secs, "clip") with a lips.py clip
			S.at(0.4, function() K.anim("Sam", "cower", 0.15) end)
		end,
		beats = {
			{frame = "extreme", actor = "Sam"},
			{frame = "insert", focus = "Mailbox", move = "tilt_up"},
		},
	}),

	[2] = L({look = "calm", blend = 1.5,
		setup = function(K, S)
			K.clearFX(); K.only("Sam", "Leo")
			K.place("Sam", V3(0, 0, 0), V3(0, 0, 10))
			K.place("Leo", V3(-5, 0, -2), V3(0, 0, 0))
		end,
		run = function(K, S)
			task.spawn(K.walk, "Leo", V3(-4, 0, 0), 8)   -- walk, don't teleport
			S.at(0.6, function() K.face("Leo", "worried", 0.25); K.pose("Leo", "pockets", 0.3) end)
		end,
		beats = {
			{frame = "full", actor = "Leo", move = "track"},
			{frame = "medium", actors = {"Sam", "Leo"}},
		},
	}),
}
