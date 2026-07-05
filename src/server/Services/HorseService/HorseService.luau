--!strict
-- HorseService.luau
-- Owns the player -> Horse registry. Horses are NO LONGER auto-spawned on
-- CharacterAdded: players walk around the lobby as normal characters, and
-- only get mounted when a Match calls SpawnHorse (and dismounted on cleanup).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Horse = require(ServerScriptService.Server.Classes.Horse.Horse)

local HorseService = {}
HorseService.Registry = {} :: { [Player]: Horse.Horse }

function HorseService.GetHorse(player: Player): Horse.Horse?
	return HorseService.Registry[player]
end

-- Mounts the player's CURRENT character on a fresh horse.
-- Returns nil if the player has no character (left / mid-respawn).
function HorseService.SpawnHorse(player: Player): Horse.Horse?
	local character = player.Character
	if not character or not character.Parent then
		return nil
	end

	HorseService.RemoveHorse(player) -- never two horses for one player

	local horse = Horse.new(character)
	HorseService.Registry[player] = horse
	return horse
end

-- Dismounts and destroys the player's horse, if any. Safe to call always.
function HorseService.RemoveHorse(player: Player)
	local horse = HorseService.Registry[player]
	HorseService.Registry[player] = nil
	if horse then
		horse:Destroy()
	end
end

-- The horse can't outlive the character it's welded to.
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		HorseService.RemoveHorse(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	HorseService.RemoveHorse(player)
end)

return HorseService
