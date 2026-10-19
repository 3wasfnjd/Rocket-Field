-- الصواريخ: طيرانها (قوس باليستي أو طيران منخفض)، صحتها (المضادات تسقطها)، والانفجار والضرر
-- يرتبط بنظام القالب: يطلق أحداث Blaster.Events.Tagged و Eliminated فتنحسب الإقصاءات كالعادة.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Weapons = require(ReplicatedStorage.RocketShared.Weapons)
local World = require(script.Parent.World)
local Camps = require(script.Parent.Camps)

local canPlayerDamageHumanoid = require(ReplicatedStorage.Blaster.Utility.canPlayerDamageHumanoid)
local events = ServerScriptService:WaitForChild("Blaster"):WaitForChild("Events")
local taggedEvent = events:WaitForChild("Tagged") :: BindableEvent
local eliminatedEvent = events:WaitForChild("Eliminated") :: BindableEvent

local Missiles = {}
Missiles.active = {} :: { any }
-- يُستدعى لما مضاد يسقط صاروخ (Main يعطي نقاط)
Missiles.OnShotDown = nil :: ((Player?, any) -> ())?

local folder = Instance.new("Folder")
folder.Name = "Projectiles"
folder.Parent = Workspace
Missiles.Folder = folder

local nextId = 0

---------------------------------------------------------------- أدوات

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = { folder }
	for _, name in { "Stations", "Forcefields" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	local layout = Workspace:FindFirstChild("Layout")
	local containment = layout and layout:FindFirstChild("playerContainment")
	if containment then
		table.insert(list, containment)
	end
	params.FilterDescendantsInstances = list
	return params
end

-- موديل دائم (Persistent) عشان يوصل لكل اللاعبين حتى لو بعيد عنهم (البث مفعّل في القالب)
local function persistentModel(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return m
end

function Missiles.WarningRing(pos: Vector3, radius: number, seconds: number)
	local m = persistentModel("Warning")
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 40, 30)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Parent = m
	m.PrimaryPart = ring
	m.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()
	Debris:AddItem(m, seconds + 0.3)
end

---------------------------------------------------------------- الانفجار

local function damagePlayers(pos: Vector3, w, owner: Player?, team: string?)
	local params = rayParams()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d <= w.blast + 2 then
				local allowed
				if owner and owner.Parent then
					allowed = canPlayerDamageHumanoid(owner, hum)
				else
					allowed = not (p.Team and team and p.Team.Name == team)
				end
				if allowed then
					local k = 1 - math.clamp((d - 1.5) / w.blast, 0, 1)
					local dmg = w.damage * (0.25 + 0.75 * k)
					-- جدار بين الانفجار واللاعب يخفف الضرر
					params.FilterDescendantsInstances = { folder, char }
					local hit = Workspace:Raycast(pos, root.Position - pos, params)
					if hit and hit.Instance.Anchored then
						dmg *= 0.35
					end
					hum:TakeDamage(dmg)
					if owner and owner.Parent then
						taggedEvent:Fire(owner, hum, dmg)
						if hum.Health <= 0 then
							eliminatedEvent:Fire(owner, hum, dmg)
						end
					end
				end
			end
		end
	end
end

function Missiles.Explode(pos: Vector3, w, owner: Player?, team: string?)
	-- مؤثر الانفجار فقط (بدون دفع ولا تكسير مفاصل)
	local boom = Instance.new("Explosion")
	boom.Position = pos
	boom.BlastRadius = w.blast
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = Workspace

	damagePlayers(pos, w, owner, team)
	-- مباني المعسكرات (المحطة والمضادات مو مسجّلة كأهداف: ما تتأثر)
	local chain = Camps.Damage(pos, w.blast + 2, w.structure, owner)
	World.Crater(pos, math.max(2.5, w.blast * 0.4))
	-- براميل الوقود تنفجر بعد شوي (تسلسل)
	for _, at in chain do
		task.delay(0.15 + math.random() * 0.2, function()
			Missiles.Explode(at, { blast = 9, damage = 40, structure = 40 }, owner, team)
		end)
	end
end

---------------------------------------------------------------- شكل الصاروخ

local function missileModel(w, scale: number): (Model, BasePart)
	local m = persistentModel("Missile")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide, body.CanQuery, body.CanTouch = false, false, false
	body.CastShadow = false
	body.Size = Vector3.new(0.6, 0.6, 3) * scale
	body.Color = w.color
	body.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Parent = m
	m.PrimaryPart = body
	if w.wings then
		local wing = Instance.new("Part")
		wing.Name = "Wings"
		wing.Anchored = true
		wing.CanCollide, wing.CanQuery, wing.CanTouch = false, false, false
		wing.CastShadow = false
		wing.Size = Vector3.new(3.2, 0.12, 0.8) * scale
		wing.Color = w.color:Lerp(Color3.new(0, 0, 0), 0.25)
		wing.Material = Enum.Material.SmoothPlastic
		wing.Parent = m
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.2 * scale, 0, body.Size.Z / 2)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.2 * scale, 0, body.Size.Z / 2)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = w.path == "cruise" and 0.5 or 0.9
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(150, 150, 150))
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.WidthScale = NumberSequence.new(1, 3)
	trail.Parent = body
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 80)
	glow.Range = 10
	glow.Brightness = 2
	glow.Parent = body
	m:SetAttribute("Weapon", w.id)
	m.Parent = folder
	return m, body
end

local function place(p, at: Vector3, dir: Vector3)
	if dir.Magnitude < 0.001 then
		return
	end
	local cf = CFrame.lookAt(at, at + dir)
	p.body.CFrame = cf
	local wings = p.model:FindFirstChild("Wings")
	if wings then
		wings.CFrame = cf * CFrame.new(0, 0, 0.2 * (p.w.scale or 1))
	end
end

---------------------------------------------------------------- الإطلاق والطيران

-- يطلق صاروخ واحد. team = فريق المطلِق
function Missiles.Launch(w, team: string, owner: Player?, origin: Vector3, target: Vector3)
	nextId += 1
	local model, body = missileModel(w, w.scale or 1)
	model:SetAttribute("Team", team)
	local p = {
		id = nextId,
		w = w,
		team = team,
		owner = owner,
		origin = origin,
		pos = origin,
		prev = origin,
		t = 0,
		target = target,
		hp = w.hp or 10,
		model = model,
		body = body,
	}
	if w.path == "arc" then
		p.flight = w.flight
		p.vel = Weapons.ArcVelocity(origin, target, p.flight)
	else
		local h = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
		p.dist = h.Magnitude
		p.dirH = p.dist > 0.01 and h.Unit or Vector3.zAxis
		p.flight = (p.dist + 5) / w.speed
		p.cruiseY = World.GroundY + (w.altitude or 20)
		p.wobble = math.random() * 10
	end
	place(p, origin, (p.vel or p.dirH))
	table.insert(Missiles.active, p)
	return p
end

local function cruisePoint(p, t: number): Vector3
	local s = math.min(p.w.speed * t, p.dist)
	local climb, dive = 40, 45
	local y
	if p.dist < climb + dive then
		y = p.origin.Y + (p.target.Y - p.origin.Y) * (s / math.max(p.dist, 1))
		y += math.sin(math.pi * s / math.max(p.dist, 1)) * 15
	elseif s < climb then
		y = p.origin.Y + (p.cruiseY - p.origin.Y) * math.sin(0.5 * math.pi * s / climb)
	elseif s > p.dist - dive then
		local k = (s - (p.dist - dive)) / dive
		y = p.cruiseY + (p.target.Y - p.cruiseY) * k * k
	else
		y = p.cruiseY
	end
	local pos = Vector3.new(p.origin.X, 0, p.origin.Z) + p.dirH * s + Vector3.new(0, y, 0)
	if p.w.id == "drone" then
		-- المسيّرة تتمايل شوي
		local side = Vector3.new(-p.dirH.Z, 0, p.dirH.X)
		pos += side * math.sin(t * 1.3 + p.wobble) * 3
	end
	return pos
end

local function remove(i: number)
	local p = table.remove(Missiles.active, i)
	if p then
		p.dead = true
		for _, d in p.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("PointLight") then
				d.Enabled = false
			end
		end
		Debris:AddItem(p.model, 1)
	end
	return p
end

-- العنقودي ينفتح قبل الهدف بشوي ويرمي قنيبلات
local function split(p)
	local sub = Weapons.Submunition
	for _ = 1, p.w.split do
		local r = math.sqrt(math.random()) * p.w.spread
		local a = math.random() * math.pi * 2
		local spot = p.target + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		Missiles.Launch(sub, p.team, p.owner, p.pos, spot)
	end
end

local params = rayParams()
local paramsAge = 0

local function step(dt: number)
	paramsAge += dt
	if paramsAge > 2 then
		paramsAge = 0
		params = rayParams()
	end
	for i = #Missiles.active, 1, -1 do
		local p = Missiles.active[i]
		if p.dead then
			table.remove(Missiles.active, i)
			continue
		end
		p.t += dt
		local newPos
		if p.vel then
			newPos = Weapons.ArcPoint(p.origin, p.vel, math.min(p.t, p.flight + 0.5))
		else
			newPos = cruisePoint(p, p.t)
		end
		local dir = newPos - p.pos
		-- ما نفحص التصادم أول لحظة عشان ما يصطدم بأرضية المنصة
		local hit = (p.t > 0.25 and dir.Magnitude > 0.001) and Workspace:Raycast(p.pos, dir, params) or nil
		local at = hit and hit.Position or newPos
		place(p, at, dir)
		p.prev = p.pos
		p.pos = newPos

		if p.w.split and p.t >= p.flight - 1.1 then
			remove(i)
			split(p)
			continue
		end
		local arrived = p.t >= p.flight + (p.vel and 0.5 or 0)
		if hit or arrived then
			remove(i)
			Missiles.Explode(at, p.w, p.owner, p.team)
		end
	end
end

---------------------------------------------------------------- المضادات

-- ضرر على صاروخ. يرجّع true إذا انهدم
function Missiles.Hit(p, amount: number, shooter: Player?): boolean
	if p.dead then
		return false
	end
	p.hp -= amount
	if p.hp > 0 then
		return false
	end
	for i, q in Missiles.active do
		if q == p then
			remove(i)
			break
		end
	end
	-- انفجار صغير في الجو بدون ضرر
	local boom = Instance.new("Explosion")
	boom.Position = p.pos
	boom.BlastRadius = 4 + (p.w.scale or 1) * 2
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = Workspace
	if Missiles.OnShotDown then
		Missiles.OnShotDown(shooter, p)
	end
	return true
end

function Missiles.Init()
	RunService.Heartbeat:Connect(step)
end

-- نصفّي كل الصواريخ بين الجولات
function Missiles.Clear()
	for i = #Missiles.active, 1, -1 do
		remove(i)
	end
	for _, c in folder:GetChildren() do
		c:Destroy()
	end
end

return Missiles
