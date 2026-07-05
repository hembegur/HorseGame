--!strict
-- GameLoopService.luau
-- The top-level loop:
--   Waiting for players -> Intermission -> Gamemode pick -> Match -> Results -> repeat
-- Owns nothing match-specific; everything inside a match lives in the Match class.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local Match = require(ServerScriptService.Server.Classes.Match.Match)
local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService.PlayerDataService)

local GameLoopService = {}

local GAMEMODES: { Match.Gamemode } = { "FFA", "Team" }

local function broadcast(text: string)
	for _, player in Players:GetPlayers() do
		Packets.MenuText:FireClient(player, text)
	end
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= GameConfig.MinPlayers
end

local BotService = require(ServerScriptService.Server.Services.BotService.BotService)

local forceStart = false
GameLoopService.CurrentMatch = nil :: any

function GameLoopService.RequestForceStart()
	forceStart = true
end

function GameLoopService.ForceEndMatch()
	if GameLoopService.CurrentMatch then
		GameLoopService.CurrentMatch:ForceEnd()
	end
end

local function enoughContestants(): boolean
	return #Players:GetPlayers() + BotService.GetBotCount() >= GameConfig.MinPlayers
end

local function runLoop()
	while true do
		-- 1) Waiting for players
		while not enoughContestants() and not forceStart do
			broadcast("Waiting for players...")
			task.wait(1)
		end

		-- 2) Intermission (abort back to waiting if players drop out)
		local aborted = false
		for t = GameConfig.IntermissionTime, 1, -1 do
			broadcast(`Intermission ({t})`)
			task.wait(1)
			if not enoughPlayers() then
				aborted = true
				break
			end
			if forceStart then
				break
			end
		end
		if aborted then
			continue
		end

		-- 3) Gamemode pick (random for now; swap for voting later)
		local gamemode = GAMEMODES[math.random(#GAMEMODES)]
		broadcast(`Gamemode: {gamemode}`)
		task.wait(2)

		-- 4) Match
		forceStart = false
		local participants = Players:GetPlayers() :: { any }
		for _, bot in BotService.GetBots() do
			table.insert(participants, bot)
		end
		local match = Match.new(participants, gamemode)
		GameLoopService.CurrentMatch = match
		local winners = match:Run()
		GameLoopService.CurrentMatch = nil

		-- 5) Results + rewards
		if #winners == 0 then
			broadcast("Draw! Nobody survived.")
		else
			local names = {}
			for _, winner in winners do
				PlayerDataService.GiveWinRewards(winner)
				table.insert(names, winner.DisplayName)
			end
			broadcast(`{table.concat(names, ", ")} won the match!`)
		end
		task.wait(GameConfig.ResultsTime)
	end
end

task.spawn(runLoop)

return GameLoopService
