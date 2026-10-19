-- القتال: القاذفات (Tools)، الصواريخ والقذائف، الانفجارات، الضرر، وإرجاع الذخيرة
-- يرتبط بنظام القالب: يطلق أحداث Blaster.Events.Tagged و Eliminated فتشتغل النقاط والجولات كما هي.
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

local Combat = {}

local projectilesFolder = Instance.new("Folder")
projectilesFolder.Name = "Projectiles"
projectilesFolder.Parent = Workspace

local active = {}
local lastShot: { [Tool]: number } = {}
local remotes

---------------------------------------------------------------- القاذفات

local function makeTool(w): Tool
	local tool = Instance.new("Tool")
	tool.Name = w.name
	tool.ToolTip = w.name
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- الإطلاق من سكربت اللاعب (يصوّب صح على الجوال)
	tool:SetAttribute("Weapon", w.id)
	tool:SetAttribute("Ammo", w.ammo)
	tool:SetAttribute("MaxAmmo", w.ammo)
	tool:SetAttribute("ReloadProgress", 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 0.9, w.id == "ballistic" and 5.5 or 4.6)
	handle.Color = w.color
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- فوهة ملوّنة قدّام
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(1.1, 1.1, 0.5)
	tip.Color = w.id == "ballistic" and Color3.fromRGB(220, 60, 50) or Color3.fromRGB(40, 40, 44)
	tip.Material = Enum.Material.SmoothPlastic
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -handle.Size.Z / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, tip
	weld.Parent = tip
	tip.Parent = tool
	if w.salvo then
		-- علبة أنابيب الراجمة
		local box = Instance.new("Part")
		box.Name = "Pod"
		box.Size = Vector3.new(1.6, 1.2, 2)
		box.Color = w.color
		box.Material = Enum.Material.Metal
		box.CanCollide = false
		box.Massless = true
		box.CFrame = handle.CFrame * CFrame.new(0, 0.9, -0.8)
		local w2 = Instance.new("WeldConstraint")
		w2.Part0, w2.Part1 = handle, box
		w2.Parent = box
		box.Parent = tool
	end
	-- يمسكها على الكتف وفوهتها لقدّام
	tool.Grip = CFrame.new(0, -0.4, 0.6)
	return tool
end

function Combat.GiveLoadout(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	local list = {}
	for _, w in Weapons.List do
		if not w.crate then
			table.insert(list, w)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	for _, w in list do
		makeTool(w).Parent = backpack
	end
end

function Combat.GiveWeapon(player: Player, id: string): boolean
	local w = Weapons.List[id]
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if not w or not char or not backpack then
		return false
	end
	for _, holder in { backpack, char } do
		for _, t in holder:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("Weapon") == id then
				t:SetAttribute("Ammo", w.ammo) -- عنده واحد: نعبّي ذخيرته
				return true
			end
		end
	end
	makeTool(w).Parent = backpack
	return true
end

---------------------------------------------------------------- الانفجار والضرر

local function rayParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { projectilesFolder }
	for _, e in exclude do
		table.insert(list, e)
	end
	local layout = Workspace:FindFirstChild("Layout")
	local containment = layout and layout:FindFirstChild("playerContainment")
	if containment then
		table.insert(list, containment)
	end
	local ff = Workspace:FindFirstChild("Forcefields")
	if ff then
		table.insert(list, ff)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function warningRing(pos: Vector3, radius: number, seconds: number)
	local ring = Instance.new("Part")
	ring.Name = "Warning"
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 40, 30)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Parent = projectilesFolder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()
	Debris:AddItem(ring, seconds + 0.2)
end

function Combat.Explode(pos: Vector3, w, owner: Player?)
	-- مؤثر الانفجار (بدون تكسير مفاصل ولا دفع)
	local boom = Instance.new("Explosion")
	boom.Position = pos
	boom.BlastRadius = w.blast
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = Workspace

	-- ضرر اللاعبين
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d <= w.blast + 2 then
				local allowed = owner == nil or canPlayerDamageHumanoid(owner, hum)
				if allowed then
					local k = 1 - math.clamp((d - 1.5) / w.blast, 0, 1)
					local dmg = w.damage * (0.25 + 0.75 * k)
					-- جدار بين الانفجار واللاعب يخفف الضرر
					local hit = Workspace:Raycast(pos, root.Position - pos, rayParams({ char }))
					if hit and hit.Instance.Anchored then
						dmg *= 0.35
					end
					hum:TakeDamage(dmg)
					if owner then
						taggedEvent:Fire(owner, hum, dmg)
						if hum.Health <= 0 then
							eliminatedEvent:Fire(owner, hum, dmg)
						end
					end
				end
			end
		end
	end

	-- المباني
	local chain = Camps.Damage(pos, w.blast + 2, w.structure, owner)
	-- حفرة في الأرض
	World.Crater(pos, math.max(2.5, w.blast * 0.4))
	-- البراميل تنفجر بعد شوي (تسلسل)
	for _, at in chain do
		task.delay(0.15 + math.random() * 0.2, function()
			Combat.Explode(at, { blast = 9, damage = 40, structure = 40 }, owner)
		end)
	end
end

---------------------------------------------------------------- الصواريخ

local function missileModel(w, scale: number): BasePart
	local body = Instance.new("Part")
	body.Name = "Missile"
	body.Anchored = true
	body.CanCollide, body.CanQuery, body.CanTouch = false, false, false
	body.Size = Vector3.new(0.5, 0.5, 2.6) * scale
	body.Color = w.color
	body.Material = Enum.Material.SmoothPlastic
	local nose = Instance.new("SpecialMesh")
	nose.MeshType = Enum.MeshType.Sphere
	nose.Scale = Vector3.new(1, 1, 1)
	nose.Parent = body
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.18 * scale, 0, body.Size.Z / 2)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.18 * scale, 0, body.Size.Z / 2)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.6
	trail.Color = ColorSequence.new(w.trail)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 3)
	trail.Parent = body
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 80)
	glow.Range = 8
	glow.Brightness = 2
	glow.Parent = body
	body.Parent = projectilesFolder
	return body
end

local function launch(w, owner: Player, origin: Vector3, target: Vector3, scale: number?)
	local proj = {
		w = w,
		owner = owner,
		origin = origin,
		pos = origin,
		t = 0,
		target = target,
		part = missileModel(w, scale or 1),
		params = rayParams({ owner.Character :: Instance }),
	}
	if w.path == "arc" then
		proj.flight = w.flight * (0.85 + 0.3 * math.clamp((target - origin).Magnitude / w.maxRange, 0, 1))
		proj.vel = Weapons.ArcVelocity(origin, target, proj.flight)
		if w.warn then
			warningRing(target, w.blast, proj.flight)
		end
	else
		proj.dir = (target - origin).Unit
		proj.flight = w.maxRange / w.speed
	end
	table.insert(active, proj)
end

local function step(dt: number)
	for i = #active, 1, -1 do
		local p = active[i]
		p.t += dt
		local newPos, dir
		if p.vel then
			newPos = Weapons.ArcPoint(p.origin, p.vel, math.min(p.t, p.flight))
		else
			newPos = p.origin + p.dir * p.w.speed * p.t
		end
		dir = newPos - p.pos
		local hit = dir.Magnitude > 0.001 and Workspace:Raycast(p.pos, dir, p.params) or nil
		local done = false
		local at = newPos
		if hit then
			at = hit.Position
			done = true
		elseif p.t >= p.flight then
			done = true
		end
		if dir.Magnitude > 0.001 then
			p.part.CFrame = CFrame.lookAt(at, at + dir)
		end
		p.pos = newPos
		if done then
			table.remove(active, i)
			p.part.Transparency = 1
			Debris:AddItem(p.part, 0.7)
			if p.w.path == "straight" and not hit then
				-- صاروخ وصل آخر مداه بدون ما يصيب: يختفي
				continue
			end
			Combat.Explode(at, p.w, p.owner)
		end
	end
end

---------------------------------------------------------------- الإطلاق

local function equippedWeapon(player: Player, id: string): Tool?
	local char = player.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Weapon") == id then
		return tool
	end
	return nil
end

local function onFire(player: Player, id, target)
	if type(id) ~= "string" or typeof(target) ~= "Vector3" or target ~= target then
		return
	end
	local w = Weapons.List[id]
	local tool = w and equippedWeapon(player, id)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tool or not hum or hum.Health <= 0 or not root then
		return
	end
	local now = os.clock()
	if now - (lastShot[tool] or 0) < w.cooldown then
		return
	end
	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo < 1 then
		remotes.notify:FireClient(player, "الذخيرة خلصت… انتظر شوي")
		return
	end
	lastShot[tool] = now
	tool:SetAttribute("Ammo", ammo - 1)

	local origin = Weapons.Muzzle(root)
	target = Weapons.ClampTarget(origin, target, w.maxRange)
	if w.salvo then
		for k = 1, w.salvo do
			task.delay((k - 1) * 0.12, function()
				local r = math.random() * w.spread
				local a = math.random() * math.pi * 2
				local spot = target + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				if root.Parent then
					launch(w, player, Weapons.Muzzle(root), spot, 0.7)
				end
			end)
		end
	else
		launch(w, player, origin, target, w.id == "ballistic" and 1.8 or 1)
	end

	-- أداة الصاروخ الباليستي تختفي لما تخلص ذخيرتها
	if w.crate and ammo - 1 <= 0 then
		task.delay(0.2, function()
			tool:Destroy()
		end)
	end
end

-- الذخيرة ترجع شوي شوي لكل قاذفة
local function regen(dt: number)
	for _, p in Players:GetPlayers() do
		for _, holder in { p:FindFirstChild("Backpack"), p.Character } do
			if holder then
				for _, tool in holder:GetChildren() do
					local id = tool:IsA("Tool") and tool:GetAttribute("Weapon")
					local w = id and Weapons.List[id]
					if w and w.reload > 0 then
						local ammo = tool:GetAttribute("Ammo") or 0
						if ammo < w.ammo then
							local prog = (tool:GetAttribute("ReloadProgress") or 0) + dt / w.reload
							if prog >= 1 then
								prog = 0
								tool:SetAttribute("Ammo", ammo + 1)
							end
							tool:SetAttribute("ReloadProgress", prog)
						else
							tool:SetAttribute("ReloadProgress", 0)
						end
					end
				end
			end
		end
	end
end

function Combat.Init(r)
	remotes = r
	remotes.fire.OnServerEvent:Connect(onFire)
	RunService.Heartbeat:Connect(step)
	task.spawn(function()
		while true do
			regen(0.25)
			task.wait(0.25)
		end
	end)
	-- القاذفات الأساسية في StarterPack: Roblox يعطيها لكل لاعب مع كل ظهور
	local StarterPack = game:GetService("StarterPack")
	local list = {}
	for _, w in Weapons.List do
		if not w.crate then
			table.insert(list, w)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	for _, w in list do
		makeTool(w).Parent = StarterPack
	end
	for _, p in Players:GetPlayers() do
		task.spawn(Combat.GiveLoadout, p)
	end
end

return Combat
