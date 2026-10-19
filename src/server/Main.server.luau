-- ميدان الصواريخ — الخادم: يجهّز الأرض والمعسكرات والقتال والصناديق فوق نظام جولات القالب
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local World = require(script.Parent.World)
local Camps = require(script.Parent.Camps)
local Combat = require(script.Parent.Combat)
local Crates = require(script.Parent.Crates)

local folder = Instance.new("Folder")
folder.Name = "RocketRemotes"
folder.Parent = ReplicatedStorage
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end
local remotes = { fire = remote("Fire"), notify = remote("Notify") }

World.Setup()
Camps.Build()

-- كل مبنى ينهدم يعطي نقاط لفريق المهاجم (نفس نقاط القالب)
local Scoring = require(ServerScriptService.Gameplay.Scripts.Scoring)
Camps.OnBreak = function(team: string, value: number, attacker: Player?, _obj)
	if attacker and attacker.Team and attacker.Team.Name ~= team then
		pcall(Scoring.incrementScore, attacker, value)
	end
end

Combat.Init(remotes)
Crates.Init(remotes)

-- بداية كل جولة (القالب يفعّل CharacterAutoLoads): نرجّع المعسكرات والأرض كما كانت
Players:GetPropertyChangedSignal("CharacterAutoLoads"):Connect(function()
	if Players.CharacterAutoLoads then
		World.ResetGround()
		Camps.Build()
		Crates.Reset()
	end
end)
