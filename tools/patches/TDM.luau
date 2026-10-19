-- ميدان الصواريخ: نمط «دمّر المعسكر» بدل نمط الإقصاءات في القالب.
-- نتيجة كل فريق = نسبة تدميره لمعسكر العدو (RocketServer/Camps تكتبها في سمة "score" للفريق).
-- اللي يدمّر معسكر العدو 100% يفوز فوراً، وإلا بعد انتهاء الوقت يفوز صاحب النسبة الأعلى.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

local Constants = require(ReplicatedStorage.Gameplay.Constants)
local Scoring = require(script.Parent.Parent.Scoring)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local blasterEvents = ServerScriptService.Blaster.Events
local eliminatedEvent = blasterEvents.Eliminated

local TEAM_SCORE_LIMIT = 100

local connections = {}
local round = 0

local Mode = {
	timer = 60 * 8,
}

function Mode.start(finish: () -> ())
	round += 1
	local myRound = round
	for _, team in Teams:GetTeams() do
		team:SetAttribute(Constants.TEAM_SCORE_ATTRIBUTE, 0)
	end

	-- الإقصاء بالليزر يعطي نقطة شخصية بس (ما يغيّر نسبة الفريق)
	table.insert(
		connections,
		eliminatedEvent.Event:Connect(function(player: Player)
			Scoring.incrementScore(player, 1)
		end)
	)

	task.spawn(function()
		task.wait(3)
		while myRound == round do
			for _, team in Teams:GetTeams() do
				if Scoring.getTeamScore(team) >= TEAM_SCORE_LIMIT then
					round += 1
					finish()
					return
				end
			end
			task.wait(0.5)
		end
	end)
end

function Mode.stop()
	round += 1
	disconnectAndClear(connections)
end

return Mode
