-- اللاعب: عدّاد المعسكرات، الإنذارات، علامات الصواريخ في السما،
-- شاشة كمبيوتر الصواريخ (اختيار الهدف ونوع الصاروخ)، وتشغيل المضاد الأرضي.
-- السلاح الشخصي (بلاستر الليزر والرشاش) من القالب نفسه وما نلمسه هنا.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Weapons = require(ReplicatedStorage:WaitForChild("RocketShared"):WaitForChild("Weapons"))
local remotes = ReplicatedStorage:WaitForChild("RocketRemotes")
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local consoleRemote = remotes:WaitForChild("Console") :: RemoteEvent
local alarmRemote = remotes:WaitForChild("Alarm") :: RemoteEvent
local aaRemote = remotes:WaitForChild("AAFire") :: RemoteEvent

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local TEAM_COLORS = { Pink = Color3.fromRGB(255, 90, 170), Green = Color3.fromRGB(80, 220, 110) }
local DARK = Color3.fromRGB(24, 26, 22)
local SANDC = Color3.fromRGB(235, 220, 180)
local RED = Color3.fromRGB(205, 60, 45)

---------------------------------------------------------------- أدوات الواجهة
local gui = Instance.new("ScreenGui")
gui.Name = "RocketHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
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
local function label(parent, props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = SANDC,
		TextStrokeTransparency = 0.5,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", parent, base)
end
local function button(parent, props)
	local base = {
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		BackgroundColor3 = DARK,
	}
	for k, v in props do
		base[k] = v
	end
	local b = new("TextButton", parent, base)
	corner(b, 10)
	new("UIPadding", b, { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	return b
end

---------------------------------------------------------------- عدّاد المعسكرات
local camps = new("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 6 or 60),
	Size = UDim2.fromOffset(250, 22),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
local function campBar(x: number, color: Color3)
	local back = new("Frame", camps, {
		Position = UDim2.new(x, 0, 0, 0),
		Size = UDim2.new(0.48, 0, 1, 0),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.35,
	})
	corner(back, 6)
	local fill = new("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.2 })
	corner(fill, 6)
	local text = label(back, { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, ZIndex = 2 })
	return fill, text
end
local pinkFill, pinkText = campBar(0, TEAM_COLORS.Pink)
local greenFill, greenText = campBar(0.52, TEAM_COLORS.Green)

local toast = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 32 or 88),
	Size = UDim2.fromOffset(440, 26),
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	ZIndex = 6,
})
local toastId = 0
local function showToast(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2.6, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
notifyRemote.OnClientEvent:Connect(showToast)

---------------------------------------------------------------- الإنذار
local alarmBanner = new("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 60 or 118),
	Size = UDim2.fromOffset(360, 40),
	BackgroundColor3 = RED,
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 7,
})
corner(alarmBanner, 10)
local alarmText = label(alarmBanner, { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), TextColor3 = Color3.new(1, 1, 1), ZIndex = 8 })
local beep = new("Sound", gui, { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 })

local alarmId = 0
alarmRemote.OnClientEvent:Connect(function(name: string, target: Vector3, flight: number)
	alarmId += 1
	local id = alarmId
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = root and typeof(target) == "Vector3" and (root.Position - target).Magnitude < 45
	alarmText.Text = near and ("⚠ " .. name .. " جاي عليك! ابعد!") or ("⚠ إنذار: " .. name .. " قادم — شغّلوا المضادات!")
	alarmBanner.Visible = true
	task.spawn(function()
		local t = 0
		while id == alarmId and t < math.max(2.5, (flight or 3)) do
			alarmBanner.BackgroundTransparency = alarmBanner.BackgroundTransparency < 0.3 and 0.55 or 0.15
			if t % 1 < 0.01 then
				beep:Play()
			end
			task.wait(0.25)
			t += 0.25
		end
		if id == alarmId then
			alarmBanner.Visible = false
		end
	end)
end)

---------------------------------------------------------------- علامات الصواريخ في السما
local projectiles = Workspace:WaitForChild("Projectiles", 30)
local function markMissile(m: Instance)
	if not m:IsA("Model") or m.Name ~= "Missile" then
		return
	end
	local body = m:WaitForChild("Body", 5)
	if not body then
		return
	end
	local mine = player.Team and m:GetAttribute("Team") == player.Team.Name
	local bb = new("BillboardGui", body, {
		Size = UDim2.fromOffset(22, 22),
		AlwaysOnTop = true,
		MaxDistance = 1200,
		LightInfluence = 0,
	})
	label(bb, {
		Size = UDim2.fromScale(1, 1),
		Text = mine and "◆" or "▼",
		TextColor3 = mine and Color3.fromRGB(230, 230, 230) or Color3.fromRGB(255, 60, 40),
		TextStrokeTransparency = 0.2,
	})
end
if projectiles then
	projectiles.ChildAdded:Connect(markMissile)
	for _, m in projectiles:GetChildren() do
		task.spawn(markMissile, m)
	end
end

---------------------------------------------------------------- التحكم بالشخصية
local controls
pcall(function()
	controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
end)
local function setMovement(enabled: boolean)
	if controls then
		pcall(function()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
	end
end
local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function viewParams(extra: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { projectiles, Workspace:FindFirstChild("Tracers"), Workspace:FindFirstChild("Forcefields") }
	if player.Character then
		table.insert(list, player.Character)
	end
	local layout = Workspace:FindFirstChild("Layout")
	if layout and layout:FindFirstChild("playerContainment") then
		table.insert(list, layout.playerContainment)
	end
	for _, e in extra do
		table.insert(list, e)
	end
	local clean = {}
	for _, v in list do
		if v then
			table.insert(clean, v)
		end
	end
	params.FilterDescendantsInstances = clean
	return params
end

---------------------------------------------------------------- كمبيوتر الصواريخ
local console = {
	open = false,
	team = "Pink",
	center = Vector3.zero,
	focus = Vector3.zero,
	height = 190,
	selected = "ballistic",
	target = nil :: Vector3?,
}

local markerFolder = new("Folder", camera, { Name = "RocketTargetMarker" })
local ring = new("Part", markerFolder, {
	Shape = Enum.PartType.Cylinder,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 60, 40),
	Transparency = 1,
	Size = Vector3.new(0.3, 10, 10),
})
local beam = new("Part", markerFolder, {
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 80, 50),
	Transparency = 1,
	Size = Vector3.new(0.8, 60, 0.8),
})

local screen = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 })
local hint = label(screen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, touch and 64 or 122),
	Size = UDim2.fromOffset(460, 22),
	Text = touch and "اضغط على المكان اللي تبي تضربه • اسحب لتحريك الخريطة" or "اضغط على المكان اللي تبي تضربه • اسحب لتحريك الخريطة • العجلة للتقريب",
	TextStrokeTransparency = 0.2,
})
local exitButton = button(screen, {
	Position = UDim2.fromOffset(12, touch and 8 or 64),
	Size = UDim2.fromOffset(86, 36),
	Text = "✖ خروج",
	BackgroundTransparency = 0.2,
})
local zoomIn = button(screen, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, touch and 8 or 64), Size = UDim2.fromOffset(40, 40), Text = "+", BackgroundTransparency = 0.2 })
local zoomOut = button(screen, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, touch and 54 or 110), Size = UDim2.fromOffset(40, 40), Text = "−", BackgroundTransparency = 0.2 })

local panel = new("Frame", screen, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -24, 0, touch and 128 or 140),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
})
corner(panel, 12)
local info = label(panel, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -150, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
local list = new("ScrollingFrame", panel, {
	Position = UDim2.fromOffset(8, 30),
	Size = UDim2.new(1, -140, 1, -38),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	BorderSizePixel = 0,
})
new("UIListLayout", list, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
local launchButton = button(panel, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.new(0, 120, 1, -16),
	Text = "إطلاق 🚀",
	BackgroundColor3 = RED,
})
new("UIStroke", launchButton, { Color = Color3.new(1, 1, 1), Thickness = 2 })

local weaponButtons = {}
for i, w in Weapons.Sorted() do
	local b = button(list, {
		Size = UDim2.new(0, touch and 96 or 108, 1, -6),
		Text = "",
		LayoutOrder = i,
		BackgroundColor3 = Color3.fromRGB(44, 48, 40),
	})
	local name = label(b, { Size = UDim2.new(1, 0, 0.55, 0), Text = w.name, TextColor3 = Color3.new(1, 1, 1) })
	local status = label(b, { Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.4, 0), Text = "جاهز", TextColor3 = Color3.fromRGB(150, 230, 150) })
	local stroke = new("UIStroke", b, { Color = Color3.fromRGB(255, 200, 80), Thickness = 3, Enabled = false })
	b.Activated:Connect(function()
		console.selected = w.id
	end)
	weaponButtons[w.id] = { button = b, status = status, stroke = stroke, name = name }
end

local function cooldownLeft(id: string): number
	local team = player.Team
	if not team then
		return 0
	end
	local ready = team:GetAttribute("cd_" .. id) or 0
	return math.max(0, ready - Workspace:GetServerTimeNow())
end

local function warnRadius(w): number
	if w.salvo or w.split then
		return w.spread + w.blast * 0.5
	end
	return w.blast
end

local savedCamera = { type = Enum.CameraType.Custom }

local function forward(): Vector3
	return console.team == "Green" and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
end

local function clampFocus()
	local f = console.focus
	local x = math.clamp(f.X, -330, 190)
	local z
	if console.team == "Pink" then
		z = math.clamp(f.Z, 180, 520)
	else
		z = math.clamp(f.Z, -200, 140)
	end
	console.focus = Vector3.new(x, f.Y, z)
end

local function updateCamera()
	local h = console.height
	local camPos = console.focus + Vector3.new(0, h, 0) - forward() * h * 0.42
	camera.CFrame = CFrame.lookAt(camPos, console.focus)
end

local function closeConsole(tellServer: boolean)
	if not console.open then
		return
	end
	console.open = false
	screen.Visible = false
	ring.Transparency, beam.Transparency = 1, 1
	camera.CameraType = savedCamera.type
	local hum = humanoid()
	if hum then
		camera.CameraSubject = hum
	end
	setMovement(true)
	if tellServer then
		consoleRemote:FireServer("close")
	end
end

local function openConsole(data)
	console.open = true
	console.team = data.team
	console.center = data.center
	console.focus = data.center
	console.target = nil
	console.height = 190
	savedCamera.type = camera.CameraType
	local hum = humanoid()
	if hum then
		hum:UnequipTools() -- عشان ضغطة الخريطة ما تطلق البلاستر
	end
	setMovement(false)
	camera.CameraType = Enum.CameraType.Scriptable
	updateCamera()
	screen.Visible = true
end

consoleRemote.OnClientEvent:Connect(function(action, data)
	if action == "open" and type(data) == "table" then
		openConsole(data)
	elseif action == "close" then
		closeConsole(false)
	end
end)

exitButton.Activated:Connect(function()
	closeConsole(true)
end)
zoomIn.Activated:Connect(function()
	console.height = math.clamp(console.height - 40, 80, 320)
end)
zoomOut.Activated:Connect(function()
	console.height = math.clamp(console.height + 40, 80, 320)
end)
launchButton.Activated:Connect(function()
	if not console.target then
		showToast("اختر الهدف أول: اضغط على الخريطة")
		return
	end
	if cooldownLeft(console.selected) > 0 then
		showToast("هذا الصاروخ يجهز… اختر غيره")
		return
	end
	consoleRemote:FireServer("launch", console.selected, console.target)
end)

local function pickTarget(screenPos: Vector2)
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, viewParams({ markerFolder }))
	if hit then
		console.target = hit.Position
	end
end

-- السحب يحرّك الخريطة، والضغطة القصيرة تختار الهدف
local drag = nil :: { input: InputObject, start: Vector2, last: Vector2, moved: number }?
UserInputService.InputBegan:Connect(function(input, processed)
	if not console.open or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if drag == nil then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			drag = { input = input, start = p, last = p, moved = 0 }
		end
	end
end)
UserInputService.InputChanged:Connect(function(input, _processed)
	if not console.open then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		console.height = math.clamp(console.height - input.Position.Z * 20, 80, 320)
		return
	end
	if not drag then
		return
	end
	local isMove = input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and input == drag.input)
	if not isMove then
		return
	end
	local p = Vector2.new(input.Position.X, input.Position.Y)
	local d = p - drag.last
	drag.last = p
	drag.moved += d.Magnitude
	if drag.moved > 12 then
		local k = console.height / math.max(camera.ViewportSize.Y, 1) * 1.4
		local fwd = forward()
		local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
		console.focus = console.focus - right * d.X * k + fwd * d.Y * k
		clampFocus()
	end
end)
UserInputService.InputEnded:Connect(function(input, _processed)
	if not drag then
		return
	end
	if input == drag.input or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if console.open and drag.moved <= 12 then
			pickTarget(drag.start)
		end
		drag = nil
	end
end)

local function updateConsole()
	updateCamera()
	local sel = Weapons.List[console.selected]
	for id, wb in weaponButtons do
		local left = cooldownLeft(id)
		wb.stroke.Enabled = id == console.selected
		if left > 0 then
			wb.status.Text = math.ceil(left) .. " ث"
			wb.status.TextColor3 = Color3.fromRGB(240, 150, 110)
			wb.button.BackgroundColor3 = Color3.fromRGB(40, 40, 38)
		else
			wb.status.Text = "جاهز"
			wb.status.TextColor3 = Color3.fromRGB(150, 230, 150)
			wb.button.BackgroundColor3 = id == console.selected and Color3.fromRGB(70, 78, 56) or Color3.fromRGB(44, 48, 40)
		end
	end
	if sel then
		local extra = sel.salvo and (" • " .. sel.salvo .. " صواريخ") or sel.split and (" • ينفتح " .. sel.split .. " قنيبلات") or ""
		info.Text = sel.name .. " — قوة على المباني " .. sel.structure .. " • صلابته " .. sel.hp .. extra
		local ready = cooldownLeft(sel.id) <= 0
		launchButton.BackgroundColor3 = (ready and console.target) and RED or Color3.fromRGB(90, 70, 66)
	end
	if console.target and sel then
		local r = warnRadius(sel)
		ring.Size = Vector3.new(0.3, r * 2, r * 2)
		ring.CFrame = CFrame.new(console.target + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.45
		beam.CFrame = CFrame.new(console.target + Vector3.new(0, 30, 0))
		beam.Transparency = 0.5
	else
		ring.Transparency, beam.Transparency = 1, 1
	end
end

---------------------------------------------------------------- المضاد الأرضي
local aa = new("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
local reticle = new("Frame", aa, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(46, 46),
	BackgroundTransparency = 1,
})
new("UIStroke", new("Frame", reticle, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }), { Color = Color3.fromRGB(255, 220, 120), Thickness = 2 })
corner(reticle:FindFirstChildOfClass("Frame"), 23)
local dot = new("Frame", reticle, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(255, 220, 120) })
corner(dot, 3)
local aaHint = label(aa, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, touch and -12 or -60),
	Size = UDim2.fromOffset(420, 22),
	Text = touch and "صوّب بالكاميرا واضغط مطوّل على «ضرب» • القفز للنزول" or "صوّب بالماوس واضغط مطوّل • المسافة (Space) للنزول",
	TextStrokeTransparency = 0.2,
})
local aaFireButton
if touch then
	aaFireButton = button(aa, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -150),
		Size = UDim2.fromOffset(92, 92),
		Text = "ضرب",
		BackgroundColor3 = RED,
	})
	corner(aaFireButton, 46)
	new("UIStroke", aaFireButton, { Color = Color3.new(1, 1, 1), Thickness = 3 })
end

local aaFiring = false
local aaTimer = 0
if aaFireButton then
	aaFireButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			aaFiring = true
		end
	end)
	aaFireButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			aaFiring = false
		end
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or touch then
		return
	end
	if aa.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2) then
		aaFiring = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		if not touch then
			aaFiring = false
		end
	end
end)

local function aaSeat(): Seat?
	local hum = humanoid()
	local seat = hum and hum.SeatPart
	if seat and seat:GetAttribute("AATurret") then
		return seat :: Seat
	end
	return nil
end

local function aaAimPoint(): Vector3
	local screenPos = touch and (camera.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	return ray.Origin + ray.Direction * 420
end

local function updateAA(dt: number)
	local seat = aaSeat()
	aa.Visible = seat ~= nil and not console.open
	if not aa.Visible then
		aaFiring = false
		return
	end
	local hum = humanoid()
	local char = player.Character
	if hum and char and char:FindFirstChildOfClass("Tool") then
		hum:UnequipTools() -- الرشاش يشتغل بدل البلاستر وأنت جالس
	end
	if not touch then
		local m = UserInputService:GetMouseLocation()
		reticle.Position = UDim2.fromOffset(m.X, m.Y)
	else
		reticle.Position = UDim2.fromScale(0.5, 0.5)
	end
	aaTimer += dt
	if aaFiring and aaTimer >= 0.09 then
		aaTimer = 0
		aaRemote:FireServer(aaAimPoint())
	end
end

---------------------------------------------------------------- كل إطار
RunService.RenderStepped:Connect(function(dt)
	local ph = Workspace:GetAttribute("PinkCampHealth") or 100
	local gh = Workspace:GetAttribute("GreenCampHealth") or 100
	pinkFill.Size = UDim2.fromScale(ph / 100, 1)
	greenFill.Size = UDim2.fromScale(gh / 100, 1)
	pinkText.Text = "معسكر الوردي " .. ph .. "%"
	greenText.Text = "معسكر الأخضر " .. gh .. "%"

	if console.open then
		updateConsole()
	end
	updateAA(dt)
end)

player.CharacterRemoving:Connect(function()
	closeConsole(false)
end)
