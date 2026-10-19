-- الأرض حول ساحة القالب، فتحات في جدران الساحة باتجاه المعسكرات، والحفر من الانفجارات
local Workspace = game:GetService("Workspace")

local World = {}

World.GroundY = 4 -- ارتفاع أرضية القالب عند نقاط الظهور الأصلية
World.LaneX = -77 -- خط الوسط بين المعسكرين (نفس X لنقاط ظهور القالب)
-- مستطيل ساحة القالب (ما نحط فيه أرض ولا حفر)
World.ArenaMin = Vector3.new(-170, 0, -60)
World.ArenaMax = Vector3.new(240, 0, 375)
-- حدود الخريطة كاملة
World.MapMin = Vector3.new(-340, 0, -330)
World.MapMax = Vector3.new(300, 0, 660)

local GAP = 26 -- عرض الفتحة في جدار الساحة

function World.InArena(p: Vector3): boolean
	return p.X > World.ArenaMin.X and p.X < World.ArenaMax.X and p.Z > World.ArenaMin.Z and p.Z < World.ArenaMax.Z
end

local function fillRect(minX, maxX, minZ, maxZ, material)
	if maxX <= minX or maxZ <= minZ then
		return
	end
	local depth = 24
	local size = Vector3.new(maxX - minX, depth, maxZ - minZ)
	local center = Vector3.new((minX + maxX) / 2, World.GroundY - depth / 2, (minZ + maxZ) / 2)
	Workspace.Terrain:FillBlock(CFrame.new(center), size, material)
end

-- طبقة رقيقة على سطح الأرض بمادة ثانية (لممرات وبقع)
local function paintRect(minX, maxX, minZ, maxZ, material)
	if maxX <= minX or maxZ <= minZ then
		return
	end
	local size = Vector3.new(maxX - minX, 2, maxZ - minZ)
	local center = Vector3.new((minX + maxX) / 2, World.GroundY - 1, (minZ + maxZ) / 2)
	Workspace.Terrain:FillBlock(CFrame.new(center), size, material)
end

local function paintPatch(x, z, radius, material)
	Workspace.Terrain:FillCylinder(CFrame.new(x, World.GroundY - 1, z), 2, radius, material)
end

-- أرض الحرب بنفس شكل أرض القالب. القالب مغيّر مظهر مواد التضاريس (MaterialService):
--   Grass = عشب طحلبي بعشب طويل، Snow = ممر حجري (Walkway)، LeafyGrass = حجارة وطحالب، Ground = طحالب
function World.ResetGround()
	local a, b = World.ArenaMin, World.ArenaMax
	local m, n = World.MapMin, World.MapMax
	local grass = Enum.Material.Grass
	fillRect(m.X, n.X, m.Z, a.Z, grass) -- جنوب (المعسكر الوردي)
	fillRect(m.X, n.X, b.Z, n.Z, grass) -- شمال (المعسكر الأخضر)
	fillRect(m.X, a.X, a.Z, b.Z, grass) -- غرب
	fillRect(b.X, n.X, a.Z, b.Z, grass) -- شرق

	-- بقع حجارة وطحالب متفرقة (بعيد عن المعسكرات)
	local rng = Random.new(2026)
	for _ = 1, 90 do
		local x = rng:NextNumber(m.X + 10, n.X - 10)
		local z = rng:NextNumber(m.Z + 10, n.Z - 10)
		local p = Vector3.new(x, 0, z)
		local nearCamp = (p - Vector3.new(World.LaneX, 0, -150)).Magnitude < 70 or (p - Vector3.new(World.LaneX, 0, 480)).Magnitude < 70
		if not World.InArena(p) and not nearCamp then
			local mat = rng:NextNumber() < 0.55 and Enum.Material.LeafyGrass or Enum.Material.Ground
			paintPatch(x, z, rng:NextNumber(5, 14), mat)
		end
	end

	-- ممرات حجرية: من كل معسكر للساحة، وطريق يلف حول الساحة
	local path = Enum.Material.Snow
	local L, half = World.LaneX, 9
	paintRect(L - half, L + half, -200, a.Z, path)
	paintRect(L - half, L + half, b.Z, 530, path)
	local ring = 18
	paintRect(a.X - ring - half, a.X - ring + half, a.Z - ring, b.Z + ring, path) -- غرب
	paintRect(b.X + ring - half, b.X + ring + half, a.Z - ring, b.Z + ring, path) -- شرق
	paintRect(a.X - ring, b.X + ring, a.Z - ring - half, a.Z - ring + half, path) -- جنوب
	paintRect(a.X - ring, b.X + ring, b.Z + ring - half, b.Z + ring + half, path) -- شمال
end

-- يقسم جدار لقطعتين ويخلي بينهم فتحة عند خط الوسط
local function splitWall(wall: BasePart)
	local cf, size = wall.CFrame, wall.Size
	-- عرض الجدار على محور X في العالم (الجدران هنا مستقيمة مع المحاور)
	local axisX = math.abs(cf.RightVector.X) > 0.7
	local halfX = axisX and size.X / 2 or size.Z / 2
	local minX, maxX = cf.Position.X - halfX, cf.Position.X + halfX
	local g0, g1 = World.LaneX - GAP / 2, World.LaneX + GAP / 2
	if g1 <= minX or g0 >= maxX then
		return
	end
	for _, range in { { minX, g0 }, { g1, maxX } } do
		local w = range[2] - range[1]
		if w > 0.5 then
			local piece = wall:Clone()
			local s = axisX and Vector3.new(w, size.Y, size.Z) or Vector3.new(size.X, size.Y, w)
			piece.Size = s
			local pos = Vector3.new((range[1] + range[2]) / 2, cf.Position.Y, cf.Position.Z)
			piece.CFrame = cf.Rotation + pos
			piece.Parent = wall.Parent
		end
	end
	wall:Destroy()
end

local function bridge(z0: number, z1: number)
	local p = Instance.new("Part")
	p.Name = "CampPath"
	p.Anchored = true
	p.Size = Vector3.new(GAP, 1, math.abs(z1 - z0))
	p.Position = Vector3.new(World.LaneX, World.GroundY - 0.5, (z0 + z1) / 2)
	p.Material = Enum.Material.Concrete
	p.Color = Color3.fromRGB(150, 146, 138)
	pcall(function()
		p.MaterialVariant = "Concrete_Board_Formed_A"
	end)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = Workspace
end

function World.Setup()
	World.ResetGround()

	-- فتحات في جدران طرفي الساحة (جهة كل معسكر)
	local layout = Workspace:FindFirstChild("Layout")
	local walls = layout and layout:FindFirstChild("Walls")
	if walls then
		for _, w in walls:GetDescendants() do
			if w:IsA("BasePart") then
				local p = w.Position
				local nearEnd = (p.Z < -10 and p.Z > -50) or (p.Z > 330 and p.Z < 370)
				if nearEnd and math.abs(p.X - World.LaneX) < 70 and w.Size.Magnitude > 40 then
					splitWall(w)
				end
			end
		end
	end
	bridge(-8, -75)
	bridge(328, 392)

	-- نقاط ظهور القالب داخل الساحة تتعطّل؛ الظهور صار في المعسكرات
	local spawns = Workspace:FindFirstChild("SpawnLocations")
	if spawns then
		for _, s in spawns:GetDescendants() do
			if s:IsA("SpawnLocation") then
				s.Enabled = false
			end
		end
	end
end

-- حفرة في الأرض الرملية (برا الساحة بس)
function World.Crater(pos: Vector3, radius: number)
	if World.InArena(pos) or pos.Y > World.GroundY + 4 then
		return
	end
	pcall(function()
		Workspace.Terrain:FillBall(Vector3.new(pos.X, World.GroundY, pos.Z), radius, Enum.Material.Air)
	end)
end

return World
