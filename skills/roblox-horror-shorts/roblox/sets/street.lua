-- STARTER STREET (ReplicatedStorage.Street): a textured suburban street to stage stories on. Build once in Edit:
--   require(game.ReplicatedStorage.Street:Clone()).build()   -> workspace.Set.Street
-- Layout (street-local studs, Street.R(x, z) -> world): road along x at z = 0, lawns + sidewalks, four houses facing -z along
-- the back (z = +34; the middle one, HouseC at x = +22, has a porch and the FM_Door focus mark), four facing +z at z = -34,
-- a second row of far houses, tree belts and power lines so the street recedes instead of ending in a wall.
-- Stage actors between z = 0 and z = 22 facing -z: the auto camera lands in front of an actor (it faces the lens side).
-- Trees/bushes are textured MeshParts made with Roblox generate_mesh (ids below). If they cannot load on your account
-- (UNVERIFIED for other accounts), simple primitive trees are used instead; or make your own with generate_mesh and put
-- MeshParts named Oak / Pine / Bush / Bare into ServerStorage.Scenery (they are used first).
local V3, C3 = Vector3.new, Color3.fromRGB
local Street = {}
Street.O = V3(0, 0.5, 0)       -- set origin (move it to build a second street elsewhere)
local FLOOR = 0.9
local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CastShadow = false; p.Size = size; p.CFrame = cf
	p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function at(x, y, z) return Street.O + V3(x, y - Street.O.Y, z) end
function Street.R(x, z) return Street.O + V3(x, 0, z) end
function Street.S() return workspace.Set.Street end
local function label(p, face, text, color, font, ppu)
	local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = ppu or 60; sg.Parent = p
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.TextScaled = true
	tl.Font = font or Enum.Font.GothamBlack; tl.TextColor3 = color or C3(30, 30, 40); tl.Text = text; tl.Parent = sg
	return tl
end


local LAWN = C3(104, 142, 76)
local MESH = {   -- {MeshId, TextureID, size} of the textured trees (Roblox generate_mesh)
	Oak = {94578412681404, 104362683537441, V3(12, 12.7, 12)}, Pine = {95494761946695, 80316092494724, V3(9, 12.6, 9)},
	Bush = {140677762573988, 107151623959226, V3(3.55, 3, 3.5)}, Bare = {129299027754402, 92399756616600, V3(10.9, 13, 11)},
}
local function primitive(kind)   -- fallback tree: trunk + two canopy balls (or a cone-ish pine), one Model
	local m = Instance.new("Model"); m.Name = kind
	local sz = MESH[kind][3]
	-- a cylinder's axis is its X: length first, then rotate it upright
	part(m, "Trunk", V3(sz.Y * 0.45, sz.X * 0.1, sz.X * 0.1), CFrame.new(0, sz.Y * 0.225, 0) * CFrame.Angles(0, 0, math.rad(90)), C3(110, 82, 60), Enum.Material.Wood, Enum.PartType.Cylinder)
	if kind ~= "Bare" then
		local leaf = kind == "Pine" and C3(52, 96, 62) or C3(78, 128, 64)
		part(m, "Canopy", V3(sz.X, sz.Y * 0.6, sz.Z), CFrame.new(0, sz.Y * 0.62, 0), leaf, Enum.Material.Grass, Enum.PartType.Ball)
		part(m, "Canopy2", V3(sz.X, sz.Y * 0.5, sz.Z) * 0.7, CFrame.new(sz.X * 0.18, sz.Y * 0.8, 0), leaf:Lerp(C3(255, 255, 255), 0.08), Enum.Material.Grass, Enum.PartType.Ball)
	end
	m.WorldPivot = CFrame.new()   -- pivot on the ground under the trunk (ScaleTo and PivotTo work from here)
	return m
end
local function source(kind)   -- ServerStorage.Scenery.<kind>, made once (MeshPart from the ids, else the primitive)
	local SS = game:GetService("ServerStorage")
	local f = SS:FindFirstChild("Scenery") or Instance.new("Folder"); f.Name = "Scenery"; f.Parent = SS
	local src = f:FindFirstChild(kind)
	if src then return src end
	local id = MESH[kind]
	local ok, mp = pcall(function() return game:GetService("AssetService"):CreateMeshPartAsync("rbxassetid://" .. id[1]) end)
	if ok and mp then
		mp.TextureID = "rbxassetid://" .. id[2]; mp.Size = id[3]
	else
		warn("Street: mesh " .. kind .. " did not load (" .. tostring(mp) .. "): using a primitive tree")
		mp = primitive(kind)
	end
	mp.Name = kind; mp.Parent = f
	return mp
end
local function green(parent, kind, x, z, s, base)
	local p = source(kind):Clone(); p.Name = kind
	local rot = CFrame.Angles(0, math.rad((x * 37 + z * 53) % 360), 0)
	if p:IsA("Model") then
		p:ScaleTo(s or 1)
		p:PivotTo(CFrame.new(at(x, FLOOR + (base or 0) - 0.15, z)) * rot)
	else
		p.Size = p.Size * (s or 1)
		p.CFrame = CFrame.new(at(x, FLOOR + (base or 0) + p.Size.Y / 2 - 0.15, z)) * rot
	end
	for _, d in ipairs(p:IsA("Model") and p:GetDescendants() or {p}) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CastShadow = true end
	end
	p.Parent = parent
	return p
end
local function wedge(parent, name, size, cf, color, mat)
	local p = Instance.new("WedgePart"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CastShadow = false
	p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat; p.Parent = parent
	return p
end

-- ---------------------------------------------------------------- houses
-- A proper little house: siding + corner trim + base band, gabled roof (two slanted slabs + ridge cap), chimney, 4-pane windows with shutters, sills and
-- flower boxes, a framed door with a lit window and a porch light, a stoop, a walkway and round bushes. dir = +1: facade faces -z (body extends +z).
local WHITE = C3(250, 246, 238)
local function house(m, name, x, zf, dir, w, h, d, o)
	o = o or {}
	local col, roof, door, shutter = o.col or C3(244, 208, 120), o.roof or C3(176, 92, 70), o.door or C3(40, 140, 150), o.shutter or C3(60, 110, 120)
	local cz = zf + dir * d / 2
	local function box(n, sw, sh, sd, bx, by, bz, c, mat)
		return part(m, name .. n, V3(sw, sh, sd), CFrame.new(at(x + bx, FLOOR + by, zf + dir * bz)), c, mat)
	end
	local wall = o.mat or Enum.Material.Plaster   -- WoodPlanks read as dirty stone on camera
	local body = part(m, name, V3(w, h, d), CFrame.new(at(x, FLOOR + h / 2, cz)), col, wall); body.CanCollide = true
	if not o.mat and not o.far then   -- clapboard siding: a shadow line under every board, front and both sides
		local dark, lite = col:Lerp(C3(0, 0, 0), 0.2), col:Lerp(C3(255, 255, 255), 0.16)
		for k = 0, math.floor((h - 2.3) / 0.95) do
			local y = 1.45 + k * 0.95
			box("Siding", w - 0.8, 0.09, 0.14, 0, y, -0.02, dark); box("Siding", w - 0.8, 0.09, 0.14, 0, y - 0.1, -0.03, lite)
			for _, sx in ipairs({-w / 2 - 0.02, w / 2 + 0.02}) do box("Siding", 0.14, 0.09, d - 0.6, sx, y, d / 2, dark) end
		end
	end
	box("Base", w + 0.4, 1.2, d + 0.4, 0, 0.6, d / 2, o.base or C3(176, 170, 160), Enum.Material.Concrete)
	for _, sx in ipairs({-w / 2, w / 2}) do box("Corner", 0.7, h, 0.7, sx, h / 2, 0.1, WHITE) end
	box("EaveTrim", w + 0.6, 0.6, 0.5, 0, h - 0.1, 0.15, WHITE)
	-- gabled roof (ridge along x): two slanted slabs, rise = (d / 2) * tan(28 deg)
	local th = math.rad(28)
	local rise = (d / 2) * math.tan(th)
	local slabL = (d / 2) / math.cos(th) + 1.6
	for _, side in ipairs({0, 1}) do
		local zc = zf + dir * (d * (side == 0 and 0.25 or 0.75))
		local ang = (side == 0 and -1 or 1) * th * dir
		part(m, name .. "RoofSlab", V3(w + 2.4, 0.6, slabL), CFrame.new(at(x, FLOOR + h + rise / 2 + 0.2, zc)) * CFrame.Angles(ang, 0, 0), roof, Enum.Material.RoofShingles)
	end
	box("Ridge", w + 2.6, 0.6, 0.9, 0, h + rise + 0.45, d / 2, o.ridge or C3(120, 70, 58))
	for _, sx in ipairs({-w / 2 + 0.25, w / 2 - 0.25}) do   -- gable triangles: two wedges per side
		for _, half in ipairs({{d / 4, dir}, {d * 3 / 4, -dir}}) do
			wedge(m, name .. "Gable", V3(0.5, rise, d / 2), CFrame.new(at(x + sx, FLOOR + h + rise / 2, zf + dir * half[1])) * CFrame.Angles(0, half[2] > 0 and 0 or math.pi, 0), col, wall)
		end
	end
	box("Gutter", w + 2.8, 0.35, 0.45, 0, h + 0.15, -1.0, WHITE)
	box("Downpipe", 0.35, h, 0.35, w / 2 - 0.9, h / 2, -0.25, C3(214, 210, 202))
	box("Chimney", 2.2, rise + 3.2, 2.2, w * 0.3, h + (rise + 3.2) / 2 - 0.4, d * 0.7, C3(176, 98, 78), Enum.Material.Brick)
	box("ChimneyCap", 2.8, 0.5, 2.8, w * 0.3, h + rise + 2.9, d * 0.7, C3(110, 96, 90))
	-- windows: frame, 4 panes, shutters, sill, flower box
	for _, dx in ipairs({-w * 0.29, w * 0.29}) do
		local wy = h * 0.6
		box("WinFrame", 4.6, 4.8, 0.35, dx, wy, -0.08, WHITE)
		box("Win", 3.8, 4.0, 0.2, dx, wy, -0.2, C3(84, 112, 134), Enum.Material.Glass).Reflectance = 0.12
		for _, sx in ipairs({-1.45, 1.45}) do box("Curtain", 0.75, 3.7, 0.1, dx + sx, wy, -0.31, C3(236, 224, 200), Enum.Material.Fabric) end
		box("Lintel", 5.2, 0.45, 0.7, dx, wy + 2.7, -0.3, WHITE)
		box("MullV", 0.25, 4.0, 0.3, dx, wy, -0.3, WHITE); box("MullH", 3.8, 0.25, 0.3, dx, wy, -0.3, WHITE)
		for _, sx in ipairs({-3.0, 3.0}) do box("Shutter", 1.5, 4.8, 0.25, dx + sx, wy, -0.1, shutter)
			for k = -4, o.far and -5 or 4 do box("Slat", 1.15, 0.12, 0.1, dx + sx, wy + k * 0.5, -0.27, shutter:Lerp(C3(0, 0, 0), 0.25)) end end
		box("Sill", 5.0, 0.4, 0.9, dx, wy - 2.6, -0.4, WHITE)
		box("FlowerBox", 4.2, 0.9, 0.8, dx, wy - 3.2, -0.5, C3(120, 84, 60), Enum.Material.Wood)
		for k = 0, o.far and -1 or 3 do green(m, "Bush", x + dx - 1.5 + k * 1.0, zf - dir * 0.6, 0.36, wy - 2.95) end
		for k = 0, o.far and -1 or 7 do
			local fc = ({C3(206, 74, 96), C3(236, 190, 70), C3(240, 236, 228), C3(218, 120, 70)})[k % 4 + 1]
			part(m, name .. "Bloom", V3(0.34, 0.34, 0.34), CFrame.new(at(x + dx - 1.75 + k * 0.5, FLOOR + wy - 2.3 + (k % 3) * 0.16, zf - dir * 1.05)), fc, nil, Enum.PartType.Ball)
		end
	end
	-- door: frame, leaf, little window, knob, porch light; stoop + path
	box("DoorFrame", 4.4, 7.0, 0.35, 0, 3.5, -0.08, WHITE)
	box("Door", 3.4, 6.4, 0.3, 0, 3.2, -0.22, door)
	box("DoorWin", 1.8, 2.0, 0.2, 0, 4.9, -0.4, C3(214, 200, 160), Enum.Material.Glass)
	for _, py in ipairs({1.2, 2.7}) do box("DoorPanel", 2.4, 1.0, 0.12, 0, py, -0.4, door:Lerp(C3(0, 0, 0), 0.22)) end
	box("Knob", 0.4, 0.4, 0.4, 1.1, 3.0, -0.5, C3(235, 200, 90), Enum.Material.Metal).Shape = Enum.PartType.Ball
	box("PorchLight", 0.6, 0.9, 0.6, 3.2, 5.6, -0.4, C3(222, 206, 160), Enum.Material.Glass)
	box("Plate", 1.3, 0.8, 0.12, -3.0, 5.2, -0.3, C3(40, 40, 50))
	part(m, name .. "Stoop", V3(6.4, 0.5, 3.0), CFrame.new(at(x, FLOOR + 0.25, zf - dir * 1.5)), C3(200, 194, 184), Enum.Material.Concrete).CanCollide = true
	part(m, name .. "Path", V3(3.0, 0.12, 6.0), CFrame.new(at(x, FLOOR + 0.05, zf - dir * 6.0)), C3(222, 216, 204), Enum.Material.Concrete)
	for _, sx in ipairs(o.far and {} or {-4.2, 4.2}) do   -- bushes beside the stoop
		green(m, "Bush", x + sx, zf - dir * 1.4, 0.95)
		green(m, "Bush", x + sx * 1.35, zf - dir * 1.0, 0.65)
	end
end

local function tree(m, name, x, z, s, kind)
	green(m, kind or "Oak", x, z, (s or 1) * 0.94).Name = name
end
local function lamp(m, name, x, z)
	part(m, name .. "Pole", V3(0.5, 11, 0.5), CFrame.new(at(x, FLOOR + 5.5, z)), C3(46, 46, 56), Enum.Material.Metal)
	part(m, name .. "Arm", V3(2.2, 0.4, 0.4), CFrame.new(at(x + 1.0, FLOOR + 10.9, z)), C3(46, 46, 56), Enum.Material.Metal)
	part(m, name .. "Bulb", V3(1.3, 1.3, 1.3), CFrame.new(at(x + 2.0, FLOOR + 10.2, z)), C3(255, 236, 170), Enum.Material.Neon, Enum.PartType.Ball)
end
local function fence(m, name, x0, x1, z)
	local n = math.floor((x1 - x0) / 1.4)
	part(m, name .. "RailA", V3(x1 - x0, 0.3, 0.25), CFrame.new(at((x0 + x1) / 2, FLOOR + 1.3, z)), WHITE)
	part(m, name .. "RailB", V3(x1 - x0, 0.3, 0.25), CFrame.new(at((x0 + x1) / 2, FLOOR + 0.6, z)), WHITE)
	for k = 0, n do part(m, name .. "Picket", V3(0.5, 2.2, 0.2), CFrame.new(at(x0 + k * 1.4, FLOOR + 1.1, z)), WHITE) end
end

Street.house, Street.green, Street.fence, Street.lamp, Street.tree = house, green, fence, lamp, tree   -- reuse them in your own sets

-- ---------------------------------------------------------------- far scenery: the street recedes instead of ending in a flat wall
local FAR_LOOKS = {
	{col = C3(208, 198, 178), roof = C3(96, 74, 66)}, {col = C3(150, 164, 178), roof = C3(64, 66, 78)}, {col = C3(176, 150, 128), roof = C3(74, 70, 72)},
	{col = C3(164, 176, 150), roof = C3(110, 76, 64)}, {col = C3(220, 214, 200), roof = C3(70, 80, 96)},
}
local function far(m)
	local f = Instance.new("Model"); f.Name = "Far"; f.Parent = m
	for _, side in ipairs({1, -1}) do
		for i = 1, 6 do   -- second row of houses, offset so they show through the gaps of the first row
			local x = -92 + i * 28 + (side > 0 and 4 or -8)
			local look = table.clone(FAR_LOOKS[(i + (side > 0 and 0 or 2)) % #FAR_LOOKS + 1]); look.far = true
			house(f, "Far" .. i, x, side * 70, side, 18, 13 + i % 2 * 2, 14, look)
		end
		for i = 0, 14 do   -- tree belts between the rows and behind the second row
			tree(f, "MidTree", -100 + i * 14.3, side * (54 + (i * 7) % 6), 1.15 + (i % 3) * 0.2)
			tree(f, "BackTree", -108 + i * 15.5, side * (96 + (i * 11) % 14), 2.0 + (i % 4) * 0.25, i % 3 == 0 and "Pine" or "Oak")
		end
		for i = 0, 8 do   -- both ends of the street
			tree(f, "EndTree", side * (76 + (i * 5) % 9), -56 + i * 14, 1.25 + (i % 3) * 0.25)
			tree(f, "EndTreeFar", side * (106 + (i * 7) % 12), -62 + i * 16, 2.2, i % 3 == 0 and "Pine" or "Oak")
		end
		local z = side * 50   -- power line behind the first row
		for i = 0, 4 do
			local x = -64 + i * 32
			part(f, "Pole", V3(0.7, 24, 0.7), CFrame.new(at(x, FLOOR + 12, z)), C3(104, 82, 64), Enum.Material.Wood)
			part(f, "CrossArm", V3(0.4, 0.4, 4.6), CFrame.new(at(x, FLOOR + 23, z)), C3(104, 82, 64), Enum.Material.Wood)
			if i < 4 then for _, dz in ipairs({-2, 2}) do part(f, "Wire", V3(32, 0.08, 0.08), CFrame.new(at(x + 16, FLOOR + 22.9, z + dz)), C3(40, 40, 44)) end end
		end
	end
	for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false end end
end

-- ---------------------------------------------------------------- build
function Street.build()
	local set = workspace:FindFirstChild("Set") or Instance.new("Folder", workspace); set.Name = "Set"
	local old = set:FindFirstChild("Street"); if old then old:Destroy() end
	local m = Instance.new("Model"); m.Name = "Street"
	local function P(name, w, h, d, x, y, z, col, mat, solid)
		local p = part(m, name, V3(w, h, d), CFrame.new(at(x, y + h / 2, z)), col, mat); p.CanCollide = solid or false
		return p
	end
	P("Ground", 140, 0.4, 100, 0, FLOOR - 0.4, 0, C3(122, 120, 122), Enum.Material.Asphalt, true)
	for k = -5, 5 do P("LaneDash", 5, 0.02, 0.35, k * 12, FLOOR, 1, C3(216, 188, 96)) end
	-- lawns + sidewalks in front of each row of houses
	P("LawnBack", 140, 0.12, 30, 0, FLOOR, 41, LAWN, Enum.Material.Grass); P("LawnFront", 140, 0.12, 24, 0, FLOOR, -46, LAWN, Enum.Material.Grass)
	P("WalkBack", 140, 0.14, 3.2, 0, FLOOR, 25.2, C3(192, 186, 176), Enum.Material.Concrete); P("WalkFront", 140, 0.14, 3.2, 0, FLOOR, -23.2, C3(192, 186, 176), Enum.Material.Concrete)
	P("CurbBack", 140, 0.3, 0.5, 0, FLOOR, 23.4, C3(140, 136, 130), Enum.Material.Concrete); P("CurbFront", 140, 0.3, 0.5, 0, FLOOR, -21.4, C3(140, 136, 130), Enum.Material.Concrete)
	part(m, "FarLawn", V3(460, 0.2, 460), CFrame.new(at(0, FLOOR - 0.38, 0)), LAWN, Enum.Material.Grass)
	-- houses facing -z along the back (z = +34): cream, sage, terracotta (porch), slate blue
	house(m, "HouseA", -50, 34, 1, 18, 13, 14, {col = C3(222, 208, 178), roof = C3(122, 80, 66), door = C3(52, 102, 130), shutter = C3(78, 112, 128)})
	house(m, "HouseB", -26, 34, 1, 18, 14, 14, {col = C3(158, 180, 156), roof = C3(70, 78, 94), door = C3(170, 78, 62), shutter = C3(232, 228, 214)})
	house(m, "HouseC", 22, 34, 1, 20, 14, 14, {col = C3(204, 146, 124), roof = C3(82, 66, 60), door = C3(40, 66, 104), shutter = C3(236, 230, 216)})
	house(m, "HouseD", 48, 34, 1, 18, 13, 14, {col = C3(148, 170, 188), roof = C3(122, 80, 66), door = C3(198, 156, 66), shutter = C3(58, 86, 120)})
	P("Porch", 11, 0.9, 6, 22, FLOOR, 31.2, C3(214, 200, 176), Enum.Material.Concrete, true); P("PorchStep", 7, 0.45, 2, 22, FLOOR, 27.9, C3(204, 190, 166), Enum.Material.Concrete, true)
	P("PorchRoof", 12, 0.5, 6.4, 22, FLOOR + 8.2, 31, C3(96, 70, 62))
	P("PorchPostL", 0.6, 8.2, 0.6, 16.8, FLOOR, 28.6, WHITE); P("PorchPostR", 0.6, 8.2, 0.6, 27.2, FLOOR, 28.6, WHITE)
	-- houses across the road facing +z
	house(m, "HouseE", -46, -34, -1, 18, 13, 14, {col = C3(218, 206, 180), roof = C3(70, 78, 94), door = C3(160, 62, 70), shutter = C3(86, 120, 100)})
	house(m, "HouseF", -14, -34, -1, 20, 14, 14, {col = C3(184, 128, 104), roof = C3(64, 58, 62), door = C3(198, 160, 80), shutter = C3(236, 230, 216), mat = Enum.Material.Brick})
	house(m, "HouseG", 18, -34, -1, 18, 13, 14, {col = C3(166, 188, 170), roof = C3(122, 80, 66), door = C3(60, 90, 140), shutter = C3(174, 82, 70)})
	house(m, "HouseH", 46, -34, -1, 18, 14, 14, {col = C3(214, 192, 142), roof = C3(82, 66, 60), door = C3(48, 112, 104), shutter = C3(66, 96, 130)})
	-- street dressing behind the action: trees, lamps, white picket fences with gaps at every walkway
	tree(m, "TreeA", -38, 30, 1); tree(m, "TreeB", 35, 31, 1.1); tree(m, "TreeC", -30, -30, 1); tree(m, "TreeD", 32, -29, 1.05); tree(m, "TreeE", 62, 30, 0.9)
	lamp(m, "LampA", -38, 24.6); lamp(m, "LampB", 36, 24.6); lamp(m, "LampC", -38, -24.6); lamp(m, "LampD", 36, -24.6)
	fence(m, "FenceA", -60, -42, 27); fence(m, "FenceB", -34, -9, 27); fence(m, "FenceC", 34, 42, 27); fence(m, "FenceD", 56, 66, 27)
	fence(m, "FenceE", -58, -52, -27); fence(m, "FenceF", -40, -22, -27); fence(m, "FenceG", -6, 8, -27); fence(m, "FenceH", 28, 38, -27)
	far(m)
	-- invisible focus marks for inserts (a Model with one transparent part, named FM_*: names must be unique in workspace.Set)
	local function mark(name, x, y, z, w, h, d)
		local mm = Instance.new("Model"); mm.Name = name
		local p = part(mm, "P", V3(w, h, d), CFrame.new(at(x, y, z)), C3(255, 255, 255)); p.Transparency = 1; p.CanQuery = false
		mm.PrimaryPart = p; mm.Parent = m
	end
	mark("FM_Door", 22, 4.0, 33.8, 4, 6.4, 0.3)
	-- light ground never sits at the baseplate's height (it flickers); shadows are on in every look, so let the set cast them
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") and d.Transparency < 1 then d.CastShadow = d.Name ~= "Ground" and d.Name ~= "FarLawn" end end
	m.Parent = set
	return m
end
function Street.reset() end   -- a story set puts its props back here at the start of each line
return Street
