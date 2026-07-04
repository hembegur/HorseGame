local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Horse = require(ServerScriptService.Server.Classes.Horse.Horse) -- adjust path
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local HorseService = {}
HorseService.Registry = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local horse = Horse.new(char)
		HorseService.Registry[player] = horse
	end)
end)

-- HorseService (sketch)
local MIN_POWER, MAX_POWER = 10, 100
local FLIGHT_DURATION = 2
local BASE_POWER = 60

Packets.LaunchHorse.OnServerEvent:Connect(function(player, direction: Vector3, power: number)
	local horse = HorseService.Registry[player]
	if not horse then
		return
	end
	if horse.State ~= "Idle" and horse.State ~= "Aiming" then
		return
	end -- reject mid-flight spam

	power = math.clamp(power, MIN_POWER, MAX_POWER) -- never trust the client's number
	horse.State = "Flying"
	horse:Unanchor()
	horse:Launch(direction.Unit, BASE_POWER * power / 100)

	task.delay(FLIGHT_DURATION, function()
		if not horse._alive then
			return
		end
		horse:Anchor()
		horse.State = "Idle"
		Packets.HorseStateChanged:FireClient(player, "Idle")
	end)
end)

return HorseService
