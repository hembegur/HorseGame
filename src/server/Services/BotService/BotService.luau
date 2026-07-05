--!strict
-- BotService.luau
-- Owns the set of active test bots. Spawning/removal is driven by admin
-- commands; GameLoopService pulls GetBots() into match participants.

local ServerScriptService = game:GetService("ServerScriptService")

local Bot = require(ServerScriptService.Server.Classes.Bot.Bot)
local HorseService = require(ServerScriptService.Server.Services.HorseService.HorseService)

local BotService = {}

local bots: { [Bot.Bot]: boolean } = {}

function BotService.SpawnBot(): Bot.Bot
	local bot = Bot.new(BotService._getSpawnCFrame())
	bots[bot] = true
	return bot
end

function BotService.RemoveBot(bot: Bot.Bot)
	if not bots[bot] then
		return
	end
	bots[bot] = nil
	HorseService.RemoveHorse(bot :: any) -- dismount if it died/ended mid-match
	bot:Destroy()
end

function BotService.RemoveAll()
	for bot in bots do
		BotService.RemoveBot(bot)
	end
end

-- Active bots as an array (order not guaranteed).
function BotService.GetBots(): { Bot.Bot }
	local list = {}
	for bot in bots do
		table.insert(list, bot)
	end
	return list
end

function BotService.GetBotCount(): number
	local count = 0
	for _ in bots do
		count += 1
	end
	return count
end

function BotService._getSpawnCFrame(): CFrame
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
	end
	return CFrame.new(0, 10, 0)
end

return BotService
