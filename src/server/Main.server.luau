-- ميدان الصواريخ — الخادم: الأرض والمعسكرات ومحطات الصواريخ والمضادات فوق نظام جولات القالب.
-- السلاح الشخصي هو بلاستر الليزر والرشاش من القالب نفسه (StarterPack).
-- الفوز: نتيجة كل فريق = نسبة تدميره لمعسكر العدو (tools/build_place.py يعدّل Scoring و TDM في القالب).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local World = require(script.Parent.World)
local Camps = require(script.Parent.Camps)
local Missiles = require(script.Parent.Missiles)
local Station = require(script.Parent.Station)
local AntiAir = require(script.Parent.AntiAir)

local folder = Instance.new("Folder")
folder.Name = "RocketRemotes"
folder.Parent = ReplicatedStorage
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end
local remotes = {
	notify = remote("Notify"),
	console = remote("Console"),
	alarm = remote("Alarm"),
	aaFire = remote("AAFire"),
}

World.Setup()
Camps.Build()

-- المحطات والمضادات تنبني مرة وحدة (ما تنهدم)
local stations = Instance.new("Folder")
stations.Name = "Stations"
stations.Parent = Workspace

-- نقاط شخصية (لوحة المتصدرين): هدم مباني العدو وإسقاط الصواريخ
local Scoring = require(ServerScriptService.Gameplay.Scripts.Scoring)
Camps.OnBreak = function(team: string, value: number, attacker: Player?, _obj)
	if attacker and attacker.Parent and attacker.Team and attacker.Team.Name ~= team then
		pcall(Scoring.incrementScore, attacker, value)
	end
end
Missiles.OnShotDown = function(shooter: Player?, _missile)
	if shooter and shooter.Parent then
		pcall(Scoring.incrementScore, shooter, 2)
	end
end

Missiles.Init()
Station.Init(remotes, stations)
AntiAir.Init(remotes, stations)

-- بداية كل جولة (القالب يفعّل CharacterAutoLoads): نرجّع المعسكرات والأرض ونصفّر الانتظار
Players:GetPropertyChangedSignal("CharacterAutoLoads"):Connect(function()
	if Players.CharacterAutoLoads then
		Missiles.Clear()
		World.ResetGround()
		Camps.Build()
		Station.ResetCooldowns()
	end
end)
