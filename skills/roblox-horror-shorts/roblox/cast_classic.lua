-- STARTER CAST: classic blocky R15 avatars with bold drawn faces (the standard look; the AI cast in cast_ai.lua is optional).
-- Run once in Edit after setup.lua (execute_luau fetches it through the bridge into a temp ModuleScript, like setup.lua):
--   it (re)builds every actor below in workspace.Cast and parks them offstage. Actors with other names are left alone.
-- To add a character: copy a row. Rules: one signature colour per character, light or neutral pants (never black bottoms,
-- never black clothes on a dark set), distinct hair/hat silhouettes, no puffy layered jackets (they show a black tank top).
-- shirt / pants are TEXTURE ids (Shirt.ShirtTemplate), not catalog ids: InsertService:LoadAsset(catalogId) and copy the
-- Shirt's ShirtTemplate (usually catalogId - 1 or - 2; a catalog id set directly shows a black tank top).
-- Verify new ids first: pcall(MarketplaceService.GetProductInfo, MarketplaceService, id). Everything here is Roblox catalog content.
local Players = game:GetService("Players")
local K = require(game:GetService("ReplicatedStorage").Kit:Clone())
local A = Enum.AccessoryType

local KID, ADULT = {h = 0.9, w = 0.95}, {h = 1.05, w = 1.0}
local CAST = {
	-- the recurring HERO: the one bright warm character in every scene (yellow smiley shirt, orange aviator beanie, navy jeans)
	Sam  = {hair = 376548738, hat = 14550482915, shirt = 5227483704, pants = 200181262, skin = {234, 184, 146}, body = KID},
	Juno = {hair = 7193454569, shirt = 8779566814, pants = 11344241864, skin = {232, 214, 200}, body = KID},   -- friend
	Leo  = {hair = 7193405096, shirt = 398633582, pants = 203906063, skin = {92, 60, 42}, body = KID},         -- friend: denim jacket over a white hoodie
	Mom  = {hair = 1772336109, shirt = 6250522677, pants = 200181262, skin = {160, 110, 80}, body = ADULT},    -- the hero's mother: purple cardigan
	-- extras / classmates (clone and recolour for crowds)
	Kid1 = {hair = 63690008, shirt = 398635080, pants = 382537568, skin = {245, 205, 170}, body = {h = 0.9, w = 0.9}},
	Kid2 = {hair = 451220849, shirt = 144076435, pants = 382537805, skin = {141, 95, 69}, body = {h = 0.9, w = 0.9}},
	Kid3 = {hair = 80922374, shirt = 398633582, pants = 144076759, skin = {214, 164, 124}, body = {h = 0.9, w = 0.9}},
	Kid4 = {hair = 62743701, shirt = 398635080, pants = 398633811, skin = {96, 62, 44}, body = {h = 0.9, w = 0.9}},
}

local cast = workspace:FindFirstChild("Cast") or Instance.new("Folder", workspace); cast.Name = "Cast"
local built = {}
for name, c in pairs(CAST) do
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(table.unpack(c.skin))
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin, skin, skin
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = c.body.h, c.body.w, 1, 1
	d.BodyTypeScale, d.ProportionScale = 0.3, 1
	local acc = {{AssetId = c.hair, AccessoryType = A.Hair}}
	if c.hat then acc[2] = {AssetId = c.hat, AccessoryType = A.Hat} end
	d:SetAccessories(acc, true)   -- hair must go through SetAccessories(..., true) or it is dropped
	local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, d, Enum.HumanoidRigType.R15)
	if not ok then
		warn("cast_classic: " .. name .. " failed: " .. tostring(m) .. " (Studio login expired? see SKILL.md pre-flight)")
	else
		m.Name = name
		for _, x in ipairs(m:GetChildren()) do if x:IsA("Shirt") or x:IsA("Pants") then x:Destroy() end end
		local s = Instance.new("Shirt"); s.ShirtTemplate = "rbxassetid://" .. c.shirt; s.Parent = m
		local p = Instance.new("Pants"); p.PantsTemplate = "rbxassetid://" .. c.pants; p.Parent = m
		m.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local old = cast:FindFirstChild(name); if old then old:Destroy() end
		m.Parent = cast
		K.classicHead(m, "neutral")   -- hides the mesh head, adds the drawn-face head K.face swaps
		K.offstage(name)
		built[#built + 1] = name
	end
end
table.sort(built)
return "cast built: " .. table.concat(built, ", ")
