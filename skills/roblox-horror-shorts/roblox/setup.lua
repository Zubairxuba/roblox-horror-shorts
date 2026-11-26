-- ONE-TIME STUDIO SETUP. Run with the Studio MCP execute_luau in Edit, with pipeline/bridge.py running in your work folder
-- and this skill's roblox/*.lua + roblox/sets/*.lua copied to <work>/roblox/src/. Safe to re-run: it refreshes the kit sources.
-- Next (once): run cast_classic.lua (the starter cast), then build the starter street:
--   require(game.ReplicatedStorage.Street:Clone()).build()
local HS = game:GetService("HttpService")
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
HS.HttpEnabled = true   -- Studio talks only to the local bridge (127.0.0.1)
local function get(f) return HS:GetAsync("http://127.0.0.1:8765/roblox/src/" .. f .. "?" .. os.clock()) end
local function put(parent, class, name, file)
	local s = parent:FindFirstChild(name) or Instance.new(class)
	s.Name = name; s.Source = get(file); s.Parent = parent
end
put(RS, "ModuleScript", "Kit", "Kit.lua")
put(RS, "ModuleScript", "Framer", "Framer.lua")
put(RS, "ModuleScript", "Lips", "Lips.lua")
put(RS, "ModuleScript", "Street", "street.lua")   -- starter set (sets/street.lua)
put(SSS, "Script", "Director", "Director.server.lua")
put(SPS, "LocalScript", "DirectorCam", "DirectorCam.client.lua")
for _, n in ipairs({"Cast", "Set", "FX"}) do
	if not workspace:FindFirstChild(n) then local f = Instance.new("Folder"); f.Name = n; f.Parent = workspace end
end
if not RS:FindFirstChild("Parts") then local f = Instance.new("Folder"); f.Name = "Parts"; f.Parent = RS end
if not game:GetService("ServerStorage"):FindFirstChild("Props") then local f = Instance.new("Folder"); f.Name = "Props"; f.Parent = game:GetService("ServerStorage") end
-- light effects the mood looks (K.look) drive
local Lighting = game:GetService("Lighting")
for _, c in ipairs({"Atmosphere", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect", "Sky"}) do
	if not Lighting:FindFirstChildOfClass(c) then Instance.new(c).Parent = Lighting end
end
Lighting.GlobalShadows = true   -- shadows on (every K.look keeps them on)
pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Realistic end)   -- place-wide; older Studios lack the property
-- recording settings: no player avatar, everything loaded, no Roblox audio (it is licensed for use inside Roblox only)
game:GetService("Players").CharacterAutoLoads = false
workspace.StreamingEnabled = false
for _, root in ipairs({workspace, game:GetService("SoundService"), game:GetService("ReplicatedStorage")}) do
	for _, s in ipairs(root:GetDescendants()) do if s:IsA("Sound") then s.Volume = 0 end end
end
return "kit installed; next: cast_classic.lua, Street.build(), then per video push Timeline.lua + Parts (see SKILL.md)"
