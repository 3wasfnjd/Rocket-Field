-- محطة إطلاق الصواريخ: كمبيوتر على طاولة + منصة إطلاق لكل معسكر.
-- ما تتأثر بالانفجارات (مو مسجّلة كأهداف، والأرض تحتها محمية من الحفر).
-- اللاعب يفتح الكمبيوتر (لفريقه فقط) → يشوف معسكر العدو من فوق → يختار الهدف ونوع الصاروخ → إطلاق.
-- فترة الانتظار لكل نوع صاروخ مشتركة بين أعضاء الفريق.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Weapons = require(ReplicatedStorage.RocketShared.Weapons)
local World = require(script.Parent.World)
local Missiles = require(script.Parent.Missiles)

local Station = {}

local remotes
local stations: { [string]: any } = {}
local using: { [Player]: string } = {}

local STEEL = Color3.fromRGB(78, 82, 86)
local DARK = Color3.fromRGB(30, 32, 34)
local WOOD = Color3.fromRGB(118, 92, 66)
local TEAM_COLORS = { Pink = Color3.fromRGB(255, 90, 170), Green = Color3.fromRGB(80, 220, 110) }
local TEAM_AR = { Pink = "الوردي", Green = "الأخضر" }

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

---------------------------------------------------------------- البناء

local function buildConsole(parent: Instance, team: string, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "LaunchConsole"
	m.Parent = parent
	local H = 3.2
	part(m, { Name = "TableTop", Size = Vector3.new(7, 0.4, 3.6), CFrame = cf * CFrame.new(0, H, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.5, 1.5 } do
			part(m, { Name = "Leg", Size = Vector3.new(0.35, H, 0.35), CFrame = cf * CFrame.new(x, H / 2, z), Color = STEEL, Material = Enum.Material.Metal })
		end
	end
	-- الشاشة
	local screen = part(m, {
		Name = "Screen",
		Size = Vector3.new(4.2, 2.6, 0.3),
		CFrame = cf * CFrame.new(0, H + 1.9, 0.7) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	part(m, { Name = "Stand", Size = Vector3.new(0.4, 0.8, 0.4), CFrame = cf * CFrame.new(0, H + 0.6, 0.8), Color = STEEL, Material = Enum.Material.Metal })
	part(m, { Name = "Keyboard", Size = Vector3.new(2.6, 0.15, 0.9), CFrame = cf * CFrame.new(0, H + 0.28, -0.6), Color = DARK, Material = Enum.Material.SmoothPlastic })
	-- زر أحمر كبير
	part(m, { Name = "RedButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.7, 0.7), CFrame = cf * CFrame.new(2.4, H + 0.35, -0.7) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(210, 40, 30), Material = Enum.Material.Neon })

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- الوجه المقابل للاعب (اللاعب واقف جهة -z المحلية)
	sg.CanvasSize = Vector2.new(420, 260)
	sg.LightInfluence = 0
	sg.Parent = screen
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(14, 26, 18)
	bg.Parent = sg
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.Position = UDim2.fromScale(0, 0.12)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = TEAM_COLORS[team]
	title.Text = "منصة الصواريخ"
	title.Parent = bg
	local sub = title:Clone()
	sub.Size = UDim2.new(1, 0, 0.22, 0)
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.TextColor3 = Color3.fromRGB(150, 230, 160)
	sub.Text = "الفريق " .. TEAM_AR[team]
	sub.Parent = bg
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = Color3.fromRGB(120, 255, 150)
	glow.Brightness = 0.6
	glow.Range = 8
	glow.Parent = screen

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenConsole"
	prompt.ActionText = "افتح منصة الإطلاق"
	prompt.ObjectText = "كمبيوتر الصواريخ"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen
	return m, screen, prompt
end

local function stripes(parent: Instance, cf: CFrame, size: number)
	-- حافة صفرا وسودا حول المنصة
	local n = 8
	for side = 0, 3 do
		local rot = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		for i = 0, n - 1 do
			part(parent, {
				Name = "Stripe",
				Size = Vector3.new(size / n, 0.12, 1.2),
				CFrame = rot * CFrame.new(-size / 2 + size / n * (i + 0.5), 1.06, size / 2 - 0.6),
				Color = i % 2 == 0 and Color3.fromRGB(240, 196, 40) or Color3.fromRGB(30, 30, 30),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end
end

local function buildPad(parent: Instance, team: string, cf: CFrame): BasePart
	local m = Instance.new("Model")
	m.Name = "LaunchPad"
	m.Parent = parent
	local S = 20
	part(m, { Name = "Slab", Size = Vector3.new(S, 2, S), CFrame = cf * CFrame.new(0, 0, 0), Color = Color3.fromRGB(150, 148, 140), Material = Enum.Material.Concrete, Variant = "Concrete_Board_Formed_A" })
	stripes(m, cf, S)
	-- قاعدة القاذف
	part(m, { Name = "Base", Size = Vector3.new(6, 2.4, 8), CFrame = cf * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(96, 104, 70), Material = Enum.Material.Metal, Variant = "MetalPanels" })
	-- السكة مايلة باتجاه العدو (+z المحلي)
	local tilt = CFrame.Angles(math.rad(55), 0, 0)
	local railCf = cf * CFrame.new(0, 4.4, 0) * tilt * CFrame.new(0, 0, -5)
	part(m, { Name = "Rail", Size = Vector3.new(2.4, 0.6, 14), CFrame = railCf, Color = STEEL, Material = Enum.Material.Metal })
	for _, x in { -1, 1 } do
		part(m, { Name = "Arm", Size = Vector3.new(0.5, 5.6, 0.5), CFrame = cf * CFrame.new(x * 1.6, 4.6, -2.6), Color = STEEL, Material = Enum.Material.Metal })
	end
	-- صاروخ جاهز على السكة (شكل فقط)
	local ready = part(m, { Name = "ReadyMissile", Size = Vector3.new(1.3, 1.3, 9), CFrame = railCf * CFrame.new(0, 1, 0), Color = Color3.fromRGB(215, 218, 210), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = ready
	-- حاجز اللهب ورا
	part(m, { Name = "BlastWall", Size = Vector3.new(10, 5, 1), CFrame = cf * CFrame.new(0, 3.5, 8.5), Color = Color3.fromRGB(150, 148, 140), Material = Enum.Material.Concrete, Variant = "Concrete_Ribbed_A" })
	local tip = Instance.new("Part")
	tip.Name = "Muzzle"
	tip.Anchored = true
	tip.CanCollide, tip.CanQuery, tip.CanTouch = false, false, false
	tip.Transparency = 1
	tip.Size = Vector3.one
	tip.CFrame = railCf * CFrame.new(0, 1.2, -7.5)
	tip.Parent = m
	return tip
end

local function buildStation(parent: Instance, team: string)
	local s = World.StationSpots
	local face = World.Face(team)
	local folder = Instance.new("Folder")
	folder.Name = team .. "Station"
	folder.Parent = parent
	-- الكمبيوتر: اللاعب يوقف جهة الثكنة (غرب) ووجهه للشاشة
	local ccf = CFrame.new(World.Mirror(team, s.console[1], s.console[2])) * CFrame.Angles(0, math.rad(90), 0)
	local console, screen, prompt = buildConsole(folder, team, ccf)
	local padCf = CFrame.new(World.Mirror(team, s.pad[1], s.pad[2], World.GroundY - 0.9)) * CFrame.Angles(0, face + math.pi, 0)
	local muzzle = buildPad(folder, team, padCf)
	-- نقطة يتركّز حولها البث لما اللاعب يشوف معسكر العدو من الكمبيوتر
	local focus = Instance.new("Part")
	focus.Name = "EnemyViewFocus"
	focus.Anchored = true
	focus.CanCollide, focus.CanQuery, focus.CanTouch = false, false, false
	focus.Transparency = 1
	focus.Size = Vector3.one
	focus.Position = World.CampCenter(World.Enemy(team)) + Vector3.new(0, 20, 0)
	focus.Parent = folder
	stations[team] = { console = console, screen = screen, prompt = prompt, muzzle = muzzle, focus = focus, ready = folder:FindFirstChild("ReadyMissile", true) }
	return prompt
end

---------------------------------------------------------------- الاستخدام

local function close(player: Player)
	if using[player] then
		using[player] = nil
		pcall(function()
			player.ReplicationFocus = nil
		end)
		remotes.console:FireClient(player, "close")
	end
end

local function open(player: Player, team: string)
	if not player.Team or player.Team.Name ~= team then
		remotes.notify:FireClient(player, "هذا كمبيوتر الفريق الثاني!")
		return
	end
	local st = stations[team]
	using[player] = team
	pcall(function()
		player.ReplicationFocus = st.focus
	end)
	local enemy = World.Enemy(team)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(World.CampCenter(enemy), 5)
		end)
	end)
	remotes.console:FireClient(player, "open", {
		team = team,
		center = World.CampCenter(enemy),
		pad = st.muzzle.Position,
	})
end

local function teamObj(team: string): Team?
	return Teams:FindFirstChild(team) :: Team?
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function alarm(targetTeam: string, w, target: Vector3, flight: number)
	for _, p in Players:GetPlayers() do
		if p.Team and p.Team.Name == targetTeam then
			remotes.alarm:FireClient(p, w.name, target, flight)
		end
	end
end

local function launch(player: Player, id: string, target: Vector3)
	local team = using[player]
	if not team then
		return
	end
	local w = Weapons.List[id]
	local tObj = teamObj(team)
	if not w or not tObj then
		return
	end
	local ready = tObj:GetAttribute("cd_" .. id) or 0
	if now() < ready then
		remotes.notify:FireClient(player, w.name .. " يجهز… " .. math.ceil(ready - now()) .. " ث")
		return
	end
	tObj:SetAttribute("cd_" .. id, now() + w.cooldown)
	target = World.ClampTarget(team, target)
	local st = stations[team]
	local origin = st.muzzle.Position
	local enemy = World.Enemy(team)

	-- الصاروخ الجاهز على السكة يختفي شوي (كأنه انطلق)
	if st.ready then
		st.ready.Transparency = 1
		task.delay(math.min(w.cooldown, 6), function()
			st.ready.Transparency = 0
		end)
	end

	local warnRadius = w.blast
	local flight
	if w.salvo then
		warnRadius = w.spread + w.blast * 0.5
		for k = 1, w.salvo do
			task.delay((k - 1) * 0.18, function()
				local r = math.sqrt(math.random()) * w.spread
				local a = math.random() * math.pi * 2
				local spot = target + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local jitter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
				Missiles.Launch(w, team, player, origin + jitter, spot)
			end)
		end
		flight = w.flight
	else
		if w.split then
			warnRadius = w.spread + w.blast * 0.5
		end
		local p = Missiles.Launch(w, team, player, origin, target)
		flight = p.flight
	end
	Missiles.WarningRing(target, warnRadius, flight + 0.6)
	alarm(enemy, w, target, flight)
	for _, p in Players:GetPlayers() do
		if p.Team and p.Team.Name == team then
			remotes.notify:FireClient(p, player.DisplayName .. " أطلق " .. w.name .. " 🚀")
		end
	end
end

function Station.ResetCooldowns()
	for _, team in { "Pink", "Green" } do
		local t = teamObj(team)
		if t then
			for id in Weapons.List do
				t:SetAttribute("cd_" .. id, 0)
			end
		end
	end
end

function Station.Init(r, parent: Instance)
	remotes = r
	for _, team in { "Pink", "Green" } do
		local prompt = buildStation(parent, team)
		prompt.Triggered:Connect(function(player: Player)
			open(player, team)
		end)
	end
	Station.ResetCooldowns()

	remotes.console.OnServerEvent:Connect(function(player: Player, action, a, b)
		if action == "close" then
			close(player)
		elseif action == "launch" and type(a) == "string" and typeof(b) == "Vector3" and b == b then
			launch(player, a, b)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		using[player] = nil
	end)

	-- يقفل الكمبيوتر إذا اللاعب مات أو بعد عنه أو تغيّر فريقه
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, team in using do
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local st = stations[team]
				local far = not root or (root.Position - st.screen.Position).Magnitude > 16
				if not hum or hum.Health <= 0 or far or not player.Team or player.Team.Name ~= team then
					close(player)
				end
			end
		end
	end)
end

return Station
