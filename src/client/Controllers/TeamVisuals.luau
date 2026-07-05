--!strict
-- TeamVisuals.luau
-- Self-starting singleton for team gamemode visuals:
--   1. Blue Highlight glow on teammates' characters (driven by the
--      replicated "Team" player attribute the server sets during matches).
--   2. Teammates' aim arrows, rendered from relayed TeammateAim packets
--      using AimIndicator in manual-direction mode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)
local AimIndicator = require(script.Parent.AimIndicator)

local TEAM_COLOR = Color3.fromRGB(0, 140, 255)
local ARROW_STALE_TIME = 1.5 -- hide a teammate arrow after this long without updates

local TeamVisuals = {}

local localPlayer = Players.LocalPlayer

type ArrowEntry = {
	indicator: AimIndicator.AimIndicator,
	lastUpdate: number,
}
local arrows: { [Player]: ArrowEntry } = {}
local highlights: { [Player]: Highlight } = {}

-- ============================== glow ==============================

local function isTeammate(player: Player): boolean
	local myTeam = localPlayer:GetAttribute("Team")
	return myTeam ~= nil and player ~= localPlayer and player:GetAttribute("Team") == myTeam
end

local function removeHighlight(player: Player)
	local highlight = highlights[player]
	if highlight then
		highlight:Destroy()
		highlights[player] = nil
	end
end

local function addHighlight(player: Player)
	removeHighlight(player)

	local character = player.Character
	if not character then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = TEAM_COLOR
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = TEAM_COLOR
	highlight.OutlineTransparency = 0
	highlight.Adornee = character
	highlight.Parent = character
	highlights[player] = highlight
end

local function refreshHighlights()
	for _, player in Players:GetPlayers() do
		if isTeammate(player) then
			addHighlight(player)
		else
			removeHighlight(player)
		end
	end
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("Team"):Connect(refreshHighlights)
	player.CharacterAdded:Connect(function()
		task.defer(refreshHighlights)
	end)
end

for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	removeHighlight(player)
	local entry = arrows[player]
	if entry then
		entry.indicator:Destroy()
		arrows[player] = nil
	end
end)

-- ============================== teammate arrows ==============================

local function getArrowEntry(player: Player): ArrowEntry?
	local existing = arrows[player]
	if existing then
		return existing
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end

	local entry: ArrowEntry = {
		indicator = AimIndicator.new(hrp),
		lastUpdate = 0,
	}
	arrows[player] = entry
	return entry
end

Packets.TeammateAim.OnClientEvent:Connect(function(who: Instance, direction: Vector3)
	local player = who :: Player
	if player == localPlayer or not isTeammate(player) then
		return
	end

	local entry = getArrowEntry(player)
	if not entry then
		return
	end

	entry.indicator:Show()
	entry.indicator:SetManualDirection(direction)
	entry.lastUpdate = os.clock()
end)

-- Hide arrows that stopped receiving updates (teammate launched, died, or left)
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, entry in arrows do
		if now - entry.lastUpdate > ARROW_STALE_TIME then
			entry.indicator:Hide()
			-- Drop entries for players whose character respawned so the
			-- indicator re-binds to the new HumanoidRootPart next time.
			local character = player.Character
			if not character or not character:FindFirstChild("HumanoidRootPart") then
				entry.indicator:Destroy()
				arrows[player] = nil
			end
		end
	end
end)

return TeamVisuals
