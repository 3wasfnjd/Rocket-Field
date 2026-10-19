-- الأرض: ساحة مفتوحة كبيرة بين ثكنتي الفريقين (غرفتا الظهور من مبنى القالب)
-- بنفس خامات أرض القالب، والحفر من الانفجارات
local Workspace = game:GetService("Workspace")

local World = {}

World.GroundY = 4 -- ارتفاع أرضية مبنى القالب
World.LaneX = -77 -- خط الوسط بين الثكنتين
-- حدود مبنيي الثكنات (ما نحط فيهم أرض ولا حفر) — نفس مناطق tools/build_place.py
World.Buildings = {
	{ min = Vector3.new(-160, 0, -50), max = Vector3.new(-20, 0, 26) }, -- الوردي
	{ min = Vector3.new(-160, 0, 294), max = Vector3.new(-20, 0, 370) }, -- الأخضر
}
-- حدود الخريطة كاملة
World.MapMin = Vector3.new(-360, 0, -230)
World.MapMax = Vector3.new(220, 0, 550)
World.FieldCenter = Vector3.new(World.LaneX, 4, 160)

-- مواقع المعسكر مكتوبة لمعسكر الوردي، والأخضر صورة معكوسة حول z = 160 (منتصف الساحة)
function World.Mirror(team: string, x: number, z: number, y: number?): Vector3
	return Vector3.new(x, y or World.GroundY, team == "Green" and (320 - z) or z)
end
function World.Face(team: string): number
	return team == "Green" and math.pi or 0
end
function World.Enemy(team: string): string
	return team == "Green" and "Pink" or "Green"
end
-- وسط المعسكر (الكمبيوتر يطل عليه من فوق)
function World.CampCenter(team: string): Vector3
	return World.Mirror(team, -77, -15)
end
-- محطة الصواريخ والمضادات (شرق الثكنة) — ما تتأثر بالانفجارات ولا تنحفر الأرض تحتها
World.StationSpots = {
	console = { 6, -2 },
	pad = { 40, -22 },
	aa = { { 34, 24 }, { -188, 24 }, { -92, -104 } },
}
World.Protected = {} :: { { p: Vector3, r: number } }
for _, team in { "Pink", "Green" } do
	local s = World.StationSpots
	table.insert(World.Protected, { p = World.Mirror(team, s.console[1], s.console[2]), r = 9 })
	table.insert(World.Protected, { p = World.Mirror(team, s.pad[1], s.pad[2]), r = 15 })
	for _, a in s.aa do
		table.insert(World.Protected, { p = World.Mirror(team, a[1], a[2]), r = 8 })
	end
end

function World.IsProtected(p: Vector3, margin: number?): boolean
	local m = margin or 0
	for _, z in World.Protected do
		local d = Vector3.new(p.X - z.p.X, 0, p.Z - z.p.Z).Magnitude
		if d < z.r + m then
			return true
		end
	end
	return false
end

function World.InBuilding(p: Vector3, margin: number?): boolean
	local m = margin or 0
	for _, b in World.Buildings do
		if p.X > b.min.X - m and p.X < b.max.X + m and p.Z > b.min.Z - m and p.Z < b.max.Z + m then
			return true
		end
	end
	return World.IsProtected(p, m)
end

-- الهدف لازم يكون في نص العدو من الساحة وداخل الخريطة
function World.ClampTarget(team: string, p: Vector3): Vector3
	local x = math.clamp(p.X, World.MapMin.X + 5, World.MapMax.X - 5)
	local z = math.clamp(p.Z, World.MapMin.Z + 5, World.MapMax.Z - 5)
	if team == "Pink" then
		z = math.max(z, 170)
	else
		z = math.min(z, 150)
	end
	return Vector3.new(x, math.clamp(p.Y, World.GroundY - 20, World.GroundY + 60), z)
end

local function fillRect(minX, maxX, minZ, maxZ, material)
	if maxX <= minX or maxZ <= minZ then
		return
	end
	local depth = 24
	Workspace.Terrain:FillBlock(
		CFrame.new((minX + maxX) / 2, World.GroundY - depth / 2, (minZ + maxZ) / 2),
		Vector3.new(maxX - minX, depth, maxZ - minZ),
		material
	)
end

local function paintRect(minX, maxX, minZ, maxZ, material)
	if maxX <= minX or maxZ <= minZ then
		return
	end
	Workspace.Terrain:FillBlock(
		CFrame.new((minX + maxX) / 2, World.GroundY - 1, (minZ + maxZ) / 2),
		Vector3.new(maxX - minX, 2, maxZ - minZ),
		material
	)
end

local function paintPatch(x, z, radius, material)
	Workspace.Terrain:FillCylinder(CFrame.new(x, World.GroundY - 1, z), 2, radius, material)
end

-- نعبّي الخريطة كلها ما عدا مكان المبنيين (قطعة قطعة حولهم)
local function fillAround(material)
	local m, n = World.MapMin, World.MapMax
	local b1, b2 = World.Buildings[1], World.Buildings[2]
	local bx0, bx1 = b1.min.X, b1.max.X
	fillRect(m.X, n.X, m.Z, b1.min.Z, material) -- جنوب الوردي
	fillRect(m.X, n.X, b1.max.Z, b2.min.Z, material) -- الساحة بين الثكنتين
	fillRect(m.X, n.X, b2.max.Z, n.Z, material) -- شمال الأخضر
	for _, b in { b1, b2 } do
		fillRect(m.X, bx0, b.min.Z, b.max.Z, material) -- غرب المبنى
		fillRect(bx1, n.X, b.min.Z, b.max.Z, material) -- شرق المبنى
	end
end

-- القالب مغيّر مظهر مواد التضاريس (MaterialService):
--   Grass = عشب طحلبي بعشب طويل، Snow = ممر حجري، LeafyGrass = حجارة وطحالب، Ground = طحالب
function World.ResetGround()
	fillAround(Enum.Material.Grass)
	local m, n = World.MapMin, World.MapMax
	local rng = Random.new(2026)
	for _ = 1, 110 do
		local x = rng:NextNumber(m.X + 10, n.X - 10)
		local z = rng:NextNumber(m.Z + 10, n.Z - 10)
		if not World.InBuilding(Vector3.new(x, 0, z), 12) then
			local mat = rng:NextNumber() < 0.55 and Enum.Material.LeafyGrass or Enum.Material.Ground
			paintPatch(x, z, rng:NextNumber(5, 14), mat)
		end
	end
	-- طريق حجري عريض بين الثكنتين (للسيارات) وطريق يلف حول الساحة
	local path = Enum.Material.Snow
	local L = World.LaneX
	paintRect(L - 12, L + 12, 26, 294, path)
	local x0, x1, z0, z1 = -230, 90, -110, 430
	paintRect(x0 - 9, x0 + 9, z0, z1, path)
	paintRect(x1 - 9, x1 + 9, z0, z1, path)
	paintRect(x0, x1, z0 - 9, z0 + 9, path)
	paintRect(x0, x1, z1 - 9, z1 + 9, path)
	paintRect(L - 9, L + 9, 160 - 9, 160 + 9, path)
	paintRect(x0, x1, 160 - 9, 160 + 9, path) -- طريق عرضي في نص الساحة
end

function World.Setup()
	World.ResetGround()
end

-- حفرة في الأرض (برا المباني)
function World.Crater(pos: Vector3, radius: number)
	if World.InBuilding(pos, radius + 3) or pos.Y > World.GroundY + 4 then
		return
	end
	pcall(function()
		Workspace.Terrain:FillBall(Vector3.new(pos.X, World.GroundY, pos.Z), radius, Enum.Material.Air)
	end)
end

return World
