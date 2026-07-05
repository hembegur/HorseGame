--!strict
-- MenuUI.luau
-- Self-starting singleton: displays server MenuText broadcasts
-- ("Waiting for players...", "Intermission (10)", turn countdowns, results)
-- in GameGui.MenuFrame's TextBox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local MenuUI = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui") :: ScreenGui
local menuFrame = gameGui:WaitForChild("MenuFrame") :: Frame
local textBox = menuFrame:FindFirstChildWhichIsA("TextBox", true)

if not textBox then
	warn("[MenuUI] No TextBox found inside GameGui.MenuFrame")
end

function MenuUI.SetText(text: string)
	if not textBox then
		return
	end
	textBox.Text = text
	menuFrame.Visible = text ~= ""
end

Packets.MenuText.OnClientEvent:Connect(MenuUI.SetText)

return MenuUI
