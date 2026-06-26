local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Horse = require(script.Classes.Horse.Horse) -- adjust path

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local horse = Horse.new(char)

		task.wait(1)
		horse:Launch() -- straight-up jump (your old defaults)

		task.wait(1)
		horse:Rotate(45, 0, 0) -- tilt the hitbox ball
	end)
end)
