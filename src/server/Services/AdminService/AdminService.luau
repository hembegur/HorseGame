--!strict
-- AdminService.luau
-- Receives AdminCommand packets, validates the sender is actually an admin
-- (NEVER trust that the GUI was hidden — exploiters can fire any packet),
-- and dispatches to the right service.
--
-- Add a new admin command by adding an entry to COMMANDS below and a
-- matching "<Name>Frame" entry in the GameGui admin panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local BotService = require(ServerScriptService.Server.Services.BotService.BotService)
local GameLoopService = require(ServerScriptService.Server.Services.GameLoopService.GameLoopService)

local AdminService = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true -- everyone is an admin in Studio playtests
	end
	return GameConfig.Admins[player.UserId] == true
end

local COMMANDS: { [string]: (player: Player) -> () } = {
	StartRound = function()
		GameLoopService.RequestForceStart()
	end,

	EndRound = function()
		GameLoopService.ForceEndMatch()
	end,

	SpawnNPC = function()
		BotService.SpawnBot()
	end,

	DeleteAllNPC = function()
		BotService.RemoveAll()
	end,
}

Packets.AdminCommand.OnServerEvent:Connect(function(player: Player, command: string)
	if not isAdmin(player) then
		warn(`[AdminService] {player.Name} tried admin command "{command}" without permission`)
		return
	end

	local handler = COMMANDS[command]
	if not handler then
		warn(`[AdminService] Unknown admin command "{command}" from {player.Name}`)
		return
	end

	print(`[AdminService] {player.Name} -> {command}`)
	handler(player)
end)

return AdminService
