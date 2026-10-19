-- اللاعب: التصويب والإطلاق، خط مسار القذيفة وحلقة السقوط، الذخيرة، وعدّاد تدمير المعسكرات
-- الكمبيوتر: صوّب بالماوس واضغط زر الماوس الأيسر. الجوال: صوّب بالكاميرا (العلامة في النص) واضغط «إطلاق».
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Weapons = require(ReplicatedStorage:WaitForChild("RocketShared"):WaitForChild("Weapons"))
local remotes = ReplicatedStorage:WaitForChild("RocketRemotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

---------------------------------------------------------------- الواجهة
local gui = Instance.new("ScreenGui")
gui.Name = "RocketHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function new(class: string, parent: Instance?, props)
	local o = Instance.new(class)
	for k, v in props or {} do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", o, { CornerRadius = UDim.new(0, r) })
end

local DARK = Color3.fromRGB(24, 26, 22)
local SANDC = Color3.fromRGB(235, 220, 180)

-- علامة التصويب
local cross = new("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.2,
	Visible = false,
})
corner(cross, 6)
new("UIStroke", cross, { Color = DARK, Thickness = 2 })

-- بطاقة السلاح والذخيرة (تحت يسار، صغيرة)
local card = new("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, touch and -96 or -78),
	Size = UDim2.fromOffset(190, 46),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.3,
	Visible = false,
})
corner(card, 10)
local weaponName = new("TextLabel", card, {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -12, 0, 22),
	Position = UDim2.fromOffset(6, 3),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = SANDC,
})
local ammoBar = new("Frame", card, {
	Position = UDim2.new(0, 8, 1, -16),
	Size = UDim2.new(1, -16, 0, 9),
	BackgroundColor3 = Color3.fromRGB(60, 60, 54),
})
corner(ammoBar, 4)
new("UIListLayout", ammoBar, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2) })

-- عدّاد سلامة المعسكرات (فوق، صغير)
local camps = new("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 6 or 60),
	Size = UDim2.fromOffset(240, 22),
	BackgroundTransparency = 1,
})
local function campBar(x: number, color: Color3, label: string)
	local back = new("Frame", camps, {
		Position = UDim2.new(x, 0, 0, 0),
		Size = UDim2.new(0.48, 0, 1, 0),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.35,
	})
	corner(back, 6)
	local fill = new("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.2 })
	corner(fill, 6)
	local text = new("TextLabel", back, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Text = label,
		ZIndex = 2,
	})
	return fill, text
end
local pinkFill, pinkText = campBar(0, Color3.fromRGB(255, 90, 170), "")
local greenFill, greenText = campBar(0.52, Color3.fromRGB(80, 220, 110), "")

local toast = new("TextLabel", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 34 or 90),
	Size = UDim2.fromOffset(420, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = SANDC,
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
})
local toastId = 0
notifyRemote.OnClientEvent:Connect(function(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2.4, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

-- زر الإطلاق على الجوال
local fireButton
if touch then
	fireButton = new("TextButton", gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -150),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(200, 70, 50),
		Text = "إطلاق",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
	})
	corner(fireButton, 42)
	new("UIStroke", fireButton, { Color = Color3.new(1, 1, 1), Thickness = 3 })
	new("UIPadding", fireButton, { PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
end

---------------------------------------------------------------- التصويب
local preview = new("Folder", camera, { Name = "AimPreview" })
local dots = {}
for i = 1, 26 do
	dots[i] = new("Part", preview, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.5,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 120),
		Transparency = 1,
	})
end
local ring = new("Part", preview, {
	Shape = Enum.PartType.Cylinder,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 80, 60),
	Transparency = 1,
	Size = Vector3.new(0.2, 8, 8),
})

local function currentTool(): Tool?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Weapon") then
		return tool
	end
	return nil
end

local function aimParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { player.Character, preview, Workspace:FindFirstChild("Projectiles") }
	local layout = Workspace:FindFirstChild("Layout")
	if layout and layout:FindFirstChild("playerContainment") then
		table.insert(list, layout.playerContainment)
	end
	if Workspace:FindFirstChild("Forcefields") then
		table.insert(list, Workspace.Forcefields)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function aimPoint(): Vector3
	local screen = touch and (camera.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 700, aimParams())
	return hit and hit.Position or (ray.Origin + ray.Direction * 700)
end

local function fire()
	local tool = currentTool()
	if not tool then
		return
	end
	fireRemote:FireServer(tool:GetAttribute("Weapon"), aimPoint())
end

if fireButton then
	fireButton.Activated:Connect(fire)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or touch then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fire()
	end
end)

local lastAmmoKey = ""
local function refreshAmmo(tool: Tool)
	local ammo = tool:GetAttribute("Ammo") or 0
	local max = tool:GetAttribute("MaxAmmo") or 1
	local prog = tool:GetAttribute("ReloadProgress") or 0
	local key = ammo .. "/" .. max .. "/" .. math.floor(prog * 10)
	if key == lastAmmoKey then
		return
	end
	lastAmmoKey = key
	for _, c in ammoBar:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local w = 1 / max
	for i = 1, max do
		local cell = new("Frame", ammoBar, {
			Size = UDim2.new(w, -2, 1, 0),
			BackgroundColor3 = i <= ammo and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 78, 70),
			LayoutOrder = i,
		})
		corner(cell, 3)
		if i == ammo + 1 and prog > 0 then
			local p = new("Frame", cell, { Size = UDim2.fromScale(prog, 1), BackgroundColor3 = Color3.fromRGB(170, 140, 70) })
			corner(p, 3)
		end
	end
end

RunService.RenderStepped:Connect(function()
	-- عدّاد المعسكرات
	local ph = Workspace:GetAttribute("PinkCampHealth") or 100
	local gh = Workspace:GetAttribute("GreenCampHealth") or 100
	pinkFill.Size = UDim2.fromScale(ph / 100, 1)
	greenFill.Size = UDim2.fromScale(gh / 100, 1)
	pinkText.Text = "الوردي " .. ph .. "%"
	greenText.Text = "الأخضر " .. gh .. "%"

	local tool = currentTool()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	card.Visible = tool ~= nil
	cross.Visible = tool ~= nil and touch
	if fireButton then
		fireButton.Visible = tool ~= nil
	end
	if not tool or not root then
		for _, d in dots do
			d.Transparency = 1
		end
		ring.Transparency = 1
		return
	end
	local w = Weapons.List[tool:GetAttribute("Weapon")]
	if not w then
		return
	end
	weaponName.Text = w.name
	refreshAmmo(tool)

	-- معاينة المسار وحلقة السقوط
	local origin = Weapons.Muzzle(root)
	local target = Weapons.ClampTarget(origin, aimPoint(), w.maxRange)
	if w.path == "arc" then
		local flight = w.flight * (0.85 + 0.3 * math.clamp((target - origin).Magnitude / w.maxRange, 0, 1))
		local v = Weapons.ArcVelocity(origin, target, flight)
		for i, d in dots do
			local t = flight * i / (#dots + 1)
			d.Position = Weapons.ArcPoint(origin, v, t)
			d.Transparency = 0.25
		end
	else
		for i, d in dots do
			d.Position = origin:Lerp(target, i / (#dots + 1))
			d.Transparency = i % 2 == 0 and 0.35 or 1
		end
	end
	local r = w.blast * 2
	ring.Size = Vector3.new(0.2, r, r)
	ring.CFrame = CFrame.new(target + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.6
end)
