--!strict
-- AdminUI.luau
-- Self-starting singleton for the admin panel in GameGui.AdminFrame.
--
-- The panel is data-driven: every Frame inside the AdminPanelFrame scroll
-- frame is treated as one admin action. Its name minus the "Frame" suffix
-- becomes the command string sent to the server:
--   StartRoundFrame   -> "StartRound"
--   SpawnNPCFrame     -> "SpawnNPC"
--   EndRoundFrame     -> "EndRound"
--   DeleteAllNPCFrame -> "DeleteAllNPC"
-- Adding a new admin command = drop in another frame (same template:
-- TextButton + TextLabel) and add a handler in AdminService.COMMANDS.
--
-- Visibility here is cosmetic only — the SERVER is what actually decides
-- whether a command is allowed (AdminService.isAdmin).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local AdminUI = {}

local localPlayer = Players.LocalPlayer

local playerGui = localPlayer:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui") :: ScreenGui
local adminFrame = gameGui:WaitForChild("AdminFrame") :: Frame
local panelFrame = adminFrame:WaitForChild("AdminPanelFrame") :: ScrollingFrame
local panelButton = adminFrame:WaitForChild("AdminPanelButton") :: TextButton

local function isAdmin(): boolean
	if RunService:IsStudio() then
		return true
	end
	return GameConfig.Admins[localPlayer.UserId] == true
end

-- Non-admins never see the panel at all.
if not isAdmin() then
	adminFrame.Visible = false
	return AdminUI
end

adminFrame.Visible = true
panelFrame.Visible = false -- start collapsed

-- Toggle the panel open/closed
panelButton.Activated:Connect(function()
	panelFrame.Visible = not panelFrame.Visible
end)

-- Wire every action frame in the scroll list
for _, child in panelFrame:GetChildren() do
	if not child:IsA("Frame") then
		continue -- skips UIListLayout, constraints, etc.
	end

	local command = child.Name:gsub("Frame$", "")
	local button = child:FindFirstChildWhichIsA("TextButton")
	if not button then
		warn(`[AdminUI] Action frame "{child.Name}" has no TextButton`)
		continue
	end

	button.Activated:Connect(function()
		Packets.AdminCommand:Fire(command)
	end)
end

return AdminUI
