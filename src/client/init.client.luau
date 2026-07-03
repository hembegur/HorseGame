local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local ModuleLoader = require(ReplicatedStorage.Shared.Modules.Core.ModuleLoader)
ModuleLoader.Load(ReplicatedStorage.Shared.Modules, true)
ModuleLoader.Load(ReplicatedStorage.Shared.Classes, true)
ModuleLoader.Load(ReplicatedStorage.Shared.Services, true)
ModuleLoader.Load(script.Controllers, true)
