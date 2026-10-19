-- المضادات الأرضية: رشاشات بمقعد في كل معسكر يشغّلها اللاعبين لإسقاط صواريخ العدو.
-- اللاعب يجلس على المقعد → يصوّب بالكاميرا/الماوس → يضغط مطوّل للإطلاق. ما تتأثر بالانفجارات.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(script.Parent.World)
local Missiles = require(script.Parent.Missiles)

local AntiAir = {}

local FIRE_INTERVAL = 0.09
local DAMAGE = 6
local RANGE = 520

local turrets: { [Seat]: any } = {}
local lastShot: { [Player]: number } = {}
local tracers: Folder

local OLIVE = Color3.fromRGB(96, 104, 70)
local STEEL = Color3.fromRGB(70, 74, 78)

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Variant" then
			(p :: any)[k] = v
		end
	end
	if props.Variant then
		pcall(function()
			p.MaterialVariant = props.Variant
		end)
	end
	p.Parent = parent
	return p
end

local function buildTurret(parent: Instance, team: string, pos: Vector3, index: number)
	local m = Instance.new("Model")
	m.Name = team .. "AntiAir" .. index
	m.Parent = parent
	local cf = CFrame.new(pos) * CFrame.Angles(0, World.Face(team) + math.pi, 0)
	-- قاعدة دائرية من أكياس رمل وسطها منصة معدن
	part(m, { Name = "Platform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 11, 11), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 120, 114), Material = Enum.Material.Concrete, Variant = "Concrete_Board_Formed_A" })
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		if i ~= 2 and i ~= 3 then -- فتحة للدخول من ورا
			part(m, {
				Name = "Sandbags",
				Size = Vector3.new(3.4, 2.4, 1.6),
				CFrame = cf * CFrame.Angles(0, a + math.pi / 2, 0) * CFrame.new(0, 2.2, -5.2),
				Color = Color3.fromRGB(176, 158, 112),
				Material = Enum.Material.Fabric,
			})
		end
	end
	part(m, { Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 1.6, 1.6), CFrame = cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = Enum.Material.Metal })

	-- الرأس اللي يدور (رشاشين)
	local head = Instance.new("Model")
	head.Name = "Head"
	head.Parent = m
	local pivot = cf * CFrame.new(0, 4.6, 0)
	local box = part(head, { Name = "Mount", Size = Vector3.new(2.6, 1.6, 2.4), CFrame = pivot, Color = OLIVE, Material = Enum.Material.Metal, Variant = "MetalPanels" })
	for _, x in { -0.75, 0.75 } do
		part(head, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 0.4, 0.4), CFrame = pivot * CFrame.new(x, 0.15, -3.1) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(40, 40, 42), Material = Enum.Material.Metal })
	end
	part(head, { Name = "Shield", Size = Vector3.new(3.6, 1.8, 0.25), CFrame = pivot * CFrame.new(0, 0.5, -1.35), Color = OLIVE, Material = Enum.Material.Metal })
	head.PrimaryPart = box

	local seat = Instance.new("Seat")
	seat.Name = "GunnerSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = cf * CFrame.new(0, 2.4, 2.6)
	seat.Color = Color3.fromRGB(50, 50, 52)
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("AATurret", true)
	seat:SetAttribute("Team", team)
	seat.Parent = m
	part(m, { Name = "SeatBack", Size = Vector3.new(2, 2, 0.4), CFrame = cf * CFrame.new(0, 3.6, 3.5), Color = Color3.fromRGB(50, 50, 52), Material = Enum.Material.Fabric })

	local hint = Instance.new("BillboardGui")
	hint.Size = UDim2.fromOffset(120, 26)
	hint.StudsOffset = Vector3.new(0, 4, 0)
	hint.MaxDistance = 45
	hint.AlwaysOnTop = true
	hint.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 18)
	label.TextColor3 = Color3.fromRGB(235, 220, 180)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "مضاد أرضي — اجلس"
	label.Parent = hint

	turrets[seat] = { team = team, head = head, pivot = pivot.Position, model = m }

	-- المقعد لفريقه بس
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if hum and (not player or not player.Team or player.Team.Name ~= team) then
			task.defer(function()
				hum.Sit = false
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
				hum.Jump = true
			end)
		end
	end)
end

local function tracer(from: Vector3, to: Vector3)
	local len = (to - from).Magnitude
	if len < 1 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Tracer"
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 210, 110)
	p.Size = Vector3.new(0.18, 0.18, math.min(len, 40))
	-- خط قصير يبدأ من الفوهة باتجاه الهدف
	local dir = (to - from).Unit
	local mid = from + dir * (math.min(len, 40) / 2 + math.random() * math.max(0, len - 40))
	p.CFrame = CFrame.lookAt(mid, mid + dir)
	p.Parent = tracers
	Debris:AddItem(p, 0.07)
end

-- أقرب صاروخ عدو على خط الإطلاق
local function findTarget(origin: Vector3, dir: Vector3, team: string)
	local best, bestAlong = nil, math.huge
	for _, p in Missiles.active do
		if p.team ~= team and not p.dead then
			local radius = 5 + (p.w.scale or 1) * 1.5
			for _, at in { p.pos, p.prev } do
				local v = at - origin
				local along = v:Dot(dir)
				if along > 0 and along < RANGE then
					local perp = (v - dir * along).Magnitude
					if perp < radius and along < bestAlong then
						best, bestAlong = p, along
					end
				end
			end
		end
	end
	return best, bestAlong
end

local function onFire(player: Player, aim)
	if typeof(aim) ~= "Vector3" or aim ~= aim then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local t = seat and turrets[seat :: Seat]
	if not t or hum.Health <= 0 then
		return
	end
	local nowT = os.clock()
	if nowT - (lastShot[player] or 0) < FIRE_INTERVAL then
		return
	end
	lastShot[player] = nowT

	local dir = aim - t.pivot
	if dir.Magnitude < 1 then
		return
	end
	dir = dir.Unit
	-- ما ينزل تحت الأفق كثير (ما يضرب اللاعبين)
	if dir.Y < -0.08 then
		dir = Vector3.new(dir.X, -0.08, dir.Z).Unit
	end
	t.head:PivotTo(CFrame.lookAt(t.pivot, t.pivot + dir))
	local origin = t.pivot + dir * 5.3
	local target, along = findTarget(origin, dir, t.team)
	if target then
		tracer(origin, origin + dir * along)
		local down = Missiles.Hit(target, DAMAGE, player)
		if down then
			-- نخبر الرامي
			AntiAir.Notify(player, "أسقطت " .. target.w.name .. "! ✈️💥")
		end
	else
		tracer(origin, origin + dir * 300)
	end
end

AntiAir.Notify = function(_player: Player, _text: string) end

function AntiAir.Init(remotes, parent: Instance)
	tracers = Instance.new("Folder")
	tracers.Name = "Tracers"
	tracers.Parent = Workspace
	AntiAir.Notify = function(player: Player, text: string)
		remotes.notify:FireClient(player, text)
	end
	for _, team in { "Pink", "Green" } do
		for i, a in World.StationSpots.aa do
			buildTurret(parent, team, World.Mirror(team, a[1], a[2]), i)
		end
	end
	remotes.aaFire.OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(p)
		lastShot[p] = nil
	end)
end

return AntiAir
