-- صناديق الأسلحة القوية: تطلع في أماكن عشوائية، واللي يلمسها ياخذ السلاح (مثل الحبل في جود)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local World = require(script.Parent.World)
local Combat = require(script.Parent.Combat)

local Crates = {}

local MAX_CRATES = 2
local RESPAWN = 35
-- مواقع ممكنة: وسط الساحة، وجانبي الطريق برا الساحة
local SPOTS = {
	Vector3.new(World.LaneX, 0, 160),
	Vector3.new(World.LaneX - 35, 0, 120),
	Vector3.new(World.LaneX + 35, 0, 200),
	Vector3.new(-230, 0, 60),
	Vector3.new(-230, 0, 260),
	Vector3.new(270, 0, 160),
	Vector3.new(World.LaneX + 90, 0, -110),
	Vector3.new(World.LaneX - 90, 0, 440),
}

local folder = Instance.new("Folder")
folder.Name = "WeaponCrates"
folder.Parent = Workspace

local notify

local function groundAt(p: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { folder }
	local layout = Workspace:FindFirstChild("Layout")
	if layout and layout:FindFirstChild("playerContainment") then
		table.insert(exclude, layout.playerContainment)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(p.X, 24, p.Z), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or nil
end

local function spawnCrate()
	local free = {}
	for _, s in SPOTS do
		local taken = false
		for _, c in folder:GetChildren() do
			if ((c:GetPivot().Position - s) * Vector3.new(1, 0, 1)).Magnitude < 5 then
				taken = true
			end
		end
		if not taken then
			table.insert(free, s)
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[math.random(1, #free)]
	local ground = groundAt(spot)
	if not ground then
		return
	end
	local box = Instance.new("Part")
	box.Name = "BallisticCrate"
	box.Anchored = true
	box.Size = Vector3.new(5, 3.4, 3.4)
	box.CFrame = CFrame.new(ground + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, math.rad(math.random(0, 179)), 0)
	box.Color = Color3.fromRGB(96, 110, 70)
	box.Material = Enum.Material.WoodPlanks
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Size = Vector3.new(5.1, 0.6, 3.5)
	stripe.CFrame = box.CFrame
	stripe.Color = Color3.fromRGB(255, 200, 40)
	stripe.Material = Enum.Material.Neon
	stripe.Parent = box
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 80)
	light.Range = 14
	light.Parent = box
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 36)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = "🚀 صاروخ باليستي"
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb

	local taken = false
	box.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not player or not hum or hum.Health <= 0 then
			return
		end
		taken = true
		Combat.GiveWeapon(player, "ballistic")
		box:Destroy()
		for _, p in Players:GetPlayers() do
			notify:FireClient(p, p == player and "🚀 أخذت صاروخ باليستي! اختاره من الشنطة" or (player.DisplayName .. " أخذ صاروخ باليستي!"))
		end
	end)
	box.Parent = folder
end

function Crates.Reset()
	folder:ClearAllChildren()
end

function Crates.Init(remotes)
	notify = remotes.notify
	task.spawn(function()
		task.wait(15)
		while true do
			if #folder:GetChildren() < MAX_CRATES then
				pcall(spawnCrate)
			end
			task.wait(RESPAWN)
		end
	end)
end

return Crates
