local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local HorseController = require(script.Controllers.HorseController)

local controller: HorseController.HorseController?

local function onCharacter(character: Model)
	if controller then
		controller:Destroy()
	end
	controller = HorseController.new(character)
end

if localPlayer.Character then
	onCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacter)
