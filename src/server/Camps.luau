-- المعسكرات: معسكر لكل فريق خارج طرفي الساحة. كل المباني قابلة للتدمير
-- وتنحسب في "عدّاد التدمير" (مثل حرب الطاولة). نستخدم خامات القالب ومجسّماته.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local World = require(script.Parent.World)

local Camps = {}
Camps.TAG = "Destructible"

local SAND = Color3.fromRGB(196, 170, 120)
local OLIVE = Color3.fromRGB(104, 112, 74)
local KHAKI = Color3.fromRGB(176, 158, 112)
local STEEL = Color3.fromRGB(92, 96, 100)

-- إجمالي "قيمة" كل معسكر والمتبقي منها
local totals: { [string]: number } = {}
local remaining: { [string]: number } = {}
local root: Folder? = nil

local function setVariant(p: BasePart, material: Enum.Material, variant: string?)
	p.Material = material
	if variant then
		pcall(function()
			p.MaterialVariant = variant
		end)
	end
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" and k ~= "Variant" and k ~= "Material" then
			(p :: any)[k] = v
		end
	end
	setVariant(p, props.Material or Enum.Material.SmoothPlastic, props.Variant)
	p.Parent = props.Parent
	return p
end

-- يسجّل قطعة (أو موديل) كهدف قابل للتدمير
local function destructible(obj: Instance, team: string, hp: number, value: number, extra)
	obj:SetAttribute("HP", hp)
	obj:SetAttribute("MaxHP", hp)
	obj:SetAttribute("Team", team)
	obj:SetAttribute("Value", value)
	for k, v in extra or {} do
		obj:SetAttribute(k, v)
	end
	CollectionService:AddTag(obj, Camps.TAG)
	totals[team] = (totals[team] or 0) + value
	remaining[team] = (remaining[team] or 0) + value
end

local function libraryModel(path: { string }): Model?
	local node: Instance? = ServerStorage:FindFirstChild("Laser Tag Template Library")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("Model") then
		return node:Clone()
	end
	return nil
end

local function placeModel(m: Model, cf: CFrame, parent: Instance)
	local _, size = m:GetBoundingBox()
	m:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
	-- نخلي أسفل الموديل على الأرض بالضبط
	local bcf, bsize = m:GetBoundingBox()
	local bottom = bcf.Position.Y - bsize.Y / 2
	m:PivotTo(m:GetPivot() + Vector3.new(0, cf.Position.Y - bottom, 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = parent
end

---------------------------------------------------------------- عناصر المعسكر

local function sandbagWall(parent: Instance, team: string, a: Vector3, b: Vector3)
	local dir = b - a
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n - 1 do
		local p0 = a + dir * (i / n)
		local p1 = a + dir * ((i + 1) / n)
		local mid = (p0 + p1) / 2
		local bag = part({
			Name = "Sandbags",
			Size = Vector3.new((p1 - p0).Magnitude - 0.2, 3.6, 2.6),
			Color = KHAKI,
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
		bag.CFrame = CFrame.fromMatrix(mid + Vector3.new(0, 1.8, 0), dir.Unit, Vector3.yAxis)
		destructible(bag, team, 40, 1)
	end
end

local function barracks(parent: Instance, team: string, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Barracks"
	model.Parent = parent
	local w, d, h = 30, 16, 11
	local function wall(localPos: Vector3, size: Vector3)
		local p = part({
			Name = "BarracksWall",
			Size = size,
			CFrame = cf * CFrame.new(localPos),
			Color = Color3.fromRGB(170, 166, 156),
			Material = Enum.Material.Concrete,
			Variant = "Concrete_Board_Formed_A",
			Parent = model,
		})
		destructible(p, team, 150, 3)
	end
	-- الخلف (قطعتين) والجوانب
	wall(Vector3.new(-w / 4, h / 2, d / 2), Vector3.new(w / 2, h, 1))
	wall(Vector3.new(w / 4, h / 2, d / 2), Vector3.new(w / 2, h, 1))
	wall(Vector3.new(-w / 2, h / 2, 0), Vector3.new(1, h, d))
	wall(Vector3.new(w / 2, h / 2, 0), Vector3.new(1, h, d))
	-- الواجهة مع باب في النص
	wall(Vector3.new(-w / 2 + 6.5, h / 2, -d / 2), Vector3.new(13, h, 1))
	wall(Vector3.new(w / 2 - 6.5, h / 2, -d / 2), Vector3.new(13, h, 1))
	wall(Vector3.new(0, h - 1.5, -d / 2), Vector3.new(4, 3, 1))
	local roof = part({
		Name = "BarracksRoof",
		Size = Vector3.new(w + 2, 1, d + 2),
		CFrame = cf * CFrame.new(0, h + 0.5, 0),
		Color = STEEL,
		Material = Enum.Material.Metal,
		Variant = "MetalPanels",
		Parent = model,
	})
	destructible(roof, team, 120, 2)
	local lamp = part({
		Name = "Lamp",
		Size = Vector3.new(1.4, 0.4, 1.4),
		CFrame = cf * CFrame.new(0, h - 0.3, 0),
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lamp
end

local function tent(parent: Instance, team: string, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Tent"
	model.Parent = parent
	local L, W, H = 14, 9, 6
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "TentSide"
		wedge.Anchored = true
		wedge.Size = Vector3.new(L, H, W / 2)
		wedge.CFrame = cf * CFrame.new(0, H / 2, side * W / 4) * CFrame.Angles(0, side == 1 and math.pi or 0, 0)
		wedge.Color = OLIVE
		wedge.Material = Enum.Material.Fabric
		wedge.Parent = model
	end
	destructible(model, team, 50, 2)
end

local function watchtower(parent: Instance, team: string, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Watchtower"
	model.Parent = parent
	local H, S = 18, 8
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local leg = part({
				Name = "Leg",
				Size = Vector3.new(1, H, 1),
				CFrame = cf * CFrame.new(x * S / 2, H / 2, z * S / 2),
				Color = STEEL,
				Material = Enum.Material.Metal,
				Parent = model,
			})
			destructible(leg, team, 90, 1, { Support = true, Group = model.Name .. tostring(cf.Position) })
		end
	end
	local deck = part({
		Name = "Deck",
		Size = Vector3.new(S + 2, 1, S + 2),
		CFrame = cf * CFrame.new(0, H + 0.5, 0),
		Color = Color3.fromRGB(120, 100, 76),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	local rails = {}
	for _, s in { -1, 1 } do
		table.insert(rails, part({ Name = "Rail", Size = Vector3.new(S + 2, 3, 0.5), CFrame = cf * CFrame.new(0, H + 2.5, s * (S / 2 + 0.75)), Color = KHAKI, Material = Enum.Material.Fabric, Parent = model }))
		table.insert(rails, part({ Name = "Rail", Size = Vector3.new(0.5, 3, S + 2), CFrame = cf * CFrame.new(s * (S / 2 + 0.75), H + 2.5, 0), Color = KHAKI, Material = Enum.Material.Fabric, Parent = model }))
	end
	local roof = part({
		Name = "TowerRoof",
		Size = Vector3.new(S + 3, 0.6, S + 3),
		CFrame = cf * CFrame.new(0, H + 7, 0),
		Color = OLIVE,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part({ Name = "RoofPost", Size = Vector3.new(0.4, 6, 0.4), CFrame = cf * CFrame.new(x * (S / 2 + 1), H + 4, z * (S / 2 + 1)), Color = STEEL, Material = Enum.Material.Metal, Parent = model })
		end
	end
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, H, 2)
	ladder.CFrame = cf * CFrame.new(0, H / 2, -S / 2 - 1)
	ladder.Color = STEEL
	ladder.Parent = model
	-- كل أجزاء البرج في نفس المجموعة: إذا انكسرت رجل يطيح البرج كله
	local group = model.Name .. tostring(cf.Position)
	for _, p in { deck, roof, ladder, table.unpack(rails) } do
		p:SetAttribute("Group", group)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("Group", group)
		end
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 40
	light.Angle = 70
	light.Brightness = 1.5
	light.Parent = roof
end

local function barrel(parent: Instance, team: string, pos: Vector3)
	local b = part({
		Name = "FuelBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.2, 2.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 50, 40),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	destructible(b, team, 20, 1, { Explosive = true })
end

local function flag(parent: Instance, team: string, pos: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "CampFlag"
	model.Parent = parent
	part({
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(20, 0.5, 0.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(220, 220, 220),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Name = "Flag",
		Size = Vector3.new(0.2, 4, 6.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 17.5, 3.3)),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	destructible(model, team, 200, 5)
end

local function decorate(parent: Instance, center: CFrame, rng: Random)
	-- صخور ونباتات وصناديق من مكتبة القالب
	local picks = {
		{ "Natural", "Rocks" },
		{ "Natural", "Foliage" },
	}
	for _, path in picks do
		local folder: Instance? = ServerStorage:FindFirstChild("Laser Tag Template Library")
		for _, n in path do
			folder = folder and folder:FindFirstChild(n)
		end
		if folder then
			local options = folder:GetChildren()
			for _ = 1, 6 do
				local src = options[rng:NextInteger(1, #options)]
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(60, 80)
				local at = center * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, a, 0)
				if src and src:IsA("Model") then
					placeModel(src:Clone(), at, parent)
				elseif src and src:IsA("BasePart") then
					local p = src:Clone()
					p.Anchored = true
					p.CFrame = at * CFrame.new(0, p.Size.Y / 2, 0)
					p.Parent = parent
				end
			end
		end
	end
end

---------------------------------------------------------------- بناء معسكر

local function buildCamp(teamName: string, center: CFrame, color: Color3)
	local folder = Instance.new("Folder")
	folder.Name = teamName .. "Camp"
	folder.Parent = root
	local team = teamName
	local rng = Random.new(#teamName * 97)

	-- أرضية المعسكر
	part({
		Name = "Foundation",
		Size = Vector3.new(110, 1, 84),
		CFrame = center * CFrame.new(0, -0.45, 0),
		Color = Color3.fromRGB(150, 146, 138),
		Material = Enum.Material.Concrete,
		Variant = "Concrete_Ribbed_A",
		Parent = folder,
	})

	-- سياج أكياس رمل حول المعسكر، والفتحة جهة الساحة (الأمام = -Z المحلي)
	local hw, hd = 52, 39
	local function wp(x, z)
		return center:PointToWorldSpace(Vector3.new(x, 0, z))
	end
	sandbagWall(folder, team, wp(-hw, hd), wp(hw, hd)) -- الخلف
	sandbagWall(folder, team, wp(-hw, -hd), wp(-hw, hd)) -- يسار
	sandbagWall(folder, team, wp(hw, -hd), wp(hw, hd)) -- يمين
	sandbagWall(folder, team, wp(-hw, -hd), wp(-14, -hd)) -- أمام يسار
	sandbagWall(folder, team, wp(14, -hd), wp(hw, -hd)) -- أمام يمين

	barracks(folder, team, center * CFrame.new(0, 0, 22))
	tent(folder, team, center * CFrame.new(-34, 0, 18) * CFrame.Angles(0, math.rad(90), 0))
	tent(folder, team, center * CFrame.new(34, 0, 18) * CFrame.Angles(0, math.rad(90), 0))
	watchtower(folder, team, center * CFrame.new(-42, 0, -28))
	watchtower(folder, team, center * CFrame.new(42, 0, -28))
	for i, x in { -20, -16, 16, 20 } do
		barrel(folder, team, wp(x, -30 + (i % 2) * 3))
	end
	flag(folder, team, wp(0, 6), color)

	-- صناديق القالب
	for i = 1, 6 do
		local crate = libraryModel({ "Props", "CrateSmall" })
		if crate then
			local x = (i <= 3) and -24 or 24
			placeModel(crate, center * CFrame.new(x + (i % 3) * 3, 0, -6 + (i % 2) * 4), folder)
			destructible(crate, team, 30, 1)
		end
	end

	-- نقاط الظهور
	local teamObj = Teams:FindFirstChild(teamName)
	for i = -1, 1 do
		local s = Instance.new("SpawnLocation")
		s.Name = teamName .. "CampSpawn"
		s.Anchored = true
		s.Size = Vector3.new(6, 1, 6)
		s.CFrame = center * CFrame.new(i * 9, 0.5, 6)
		s.Neutral = false
		s.AllowTeamChangeOnTouch = false
		s.Duration = 3
		if teamObj and teamObj:IsA("Team") then
			s.TeamColor = teamObj.TeamColor
		end
		s.Color = color
		s.Material = Enum.Material.Neon
		s.Transparency = 0.4
		s.Parent = folder
	end

	decorate(folder, center, rng)
end

function Camps.Build()
	if root then
		root:Destroy()
	end
	totals, remaining = {}, {}
	root = Instance.new("Folder")
	root.Name = "Camps"
	root.Parent = Workspace
	local y = World.GroundY
	buildCamp("Pink", CFrame.lookAt(Vector3.new(World.LaneX, y, -150), Vector3.new(World.LaneX, y, 0)), Color3.fromRGB(255, 90, 170))
	buildCamp("Green", CFrame.lookAt(Vector3.new(World.LaneX, y, 480), Vector3.new(World.LaneX, y, 300)), Color3.fromRGB(80, 220, 110))
	Camps.Publish()
end

-- نسبة سلامة كل معسكر في سمات Workspace (الواجهة تقراها)
function Camps.Publish()
	for team, total in totals do
		local pct = total > 0 and math.floor(100 * (remaining[team] or 0) / total + 0.5) or 0
		Workspace:SetAttribute(team .. "CampHealth", pct)
	end
end

---------------------------------------------------------------- التدمير

local function partsOf(obj: Instance): { BasePart }
	if obj:IsA("BasePart") then
		return { obj }
	end
	local list = {}
	for _, d in obj:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function closestDistance(obj: Instance, pos: Vector3): number
	local cf, size
	if obj:IsA("BasePart") then
		cf, size = obj.CFrame, obj.Size
	else
		cf, size = (obj :: Model):GetBoundingBox()
	end
	local lp = cf:PointToObjectSpace(pos)
	local h = size / 2
	local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
	return (lp - c).Magnitude
end

local function fling(p: BasePart, from: Vector3)
	p.Anchored = false
	p.CanCollide = true
	local dir = p.Position - from
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.yAxis
	p.AssemblyLinearVelocity = (dir + Vector3.new(0, 0.8, 0)) * math.random(25, 45)
	p.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
	p.Color = p.Color:Lerp(Color3.fromRGB(40, 36, 32), 0.55)
	Debris:AddItem(p, 9)
end

-- onBreak(team, value, attacker, obj) يجي من Combat
Camps.OnBreak = nil :: ((string, number, Player?, Instance) -> ())?

local function breakObj(obj: Instance, from: Vector3, attacker: Player?)
	if not CollectionService:HasTag(obj, Camps.TAG) then
		return
	end
	CollectionService:RemoveTag(obj, Camps.TAG)
	local team = obj:GetAttribute("Team")
	local value = obj:GetAttribute("Value") or 1
	remaining[team] = math.max(0, (remaining[team] or 0) - value)
	for _, p in partsOf(obj) do
		fling(p, from)
	end
	if Camps.OnBreak then
		Camps.OnBreak(team, value, attacker, obj)
	end
	-- إذا كانت رجل برج: يطيح البرج كله
	local group = obj:GetAttribute("Group")
	if obj:GetAttribute("Support") and group then
		for _, other in CollectionService:GetTagged(Camps.TAG) do
			if other:GetAttribute("Group") == group then
				breakObj(other, from, attacker)
			end
		end
		for _, d in (root :: Folder):GetDescendants() do
			if d:IsA("BasePart") and d.Anchored and d:GetAttribute("Group") == group then
				fling(d, from)
			end
		end
	end
	Camps.Publish()
end

-- يرجّع قائمة البراميل اللي انفجرت (Combat يفجرها بعدين)
function Camps.Damage(pos: Vector3, radius: number, amount: number, attacker: Player?): { Vector3 }
	local explosions = {}
	for _, obj in CollectionService:GetTagged(Camps.TAG) do
		if obj:IsDescendantOf(Workspace) then
			local d = closestDistance(obj, pos)
			if d <= radius then
				local dmg = amount * (1 - 0.6 * (d / radius))
				local hp = (obj:GetAttribute("HP") or 0) - dmg
				obj:SetAttribute("HP", hp)
				if hp <= 0 then
					local at = obj:IsA("BasePart") and obj.Position or (obj :: Model):GetPivot().Position
					if obj:GetAttribute("Explosive") then
						table.insert(explosions, at)
					end
					breakObj(obj, pos, attacker)
				end
			end
		end
	end
	return explosions
end

return Camps
