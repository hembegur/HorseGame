--!strict
-- PlayerDataService.luau
-- Owns all persistent player data, built on leifstout's dataService
-- (ProfileStore under the hood: session locking, reconciliation, and
-- automatic replication of every write to the client).
--
-- Everything else on the server goes through this service — nothing should
-- require the DataService package directly. That keeps paths, reward math,
-- and template knowledge in one place.
--
-- Replaces the old leaderstats-only RewardService. Leaderstats still exist,
-- but purely as a VIEW: they're rebuilt from data on join and kept in sync
-- via changed signals, never written to directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Core.DataTemplate)
local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)

local PlayerDataService = {}

-- ============================== init ==============================

DataService:init({
	template = DataTemplate,
	profileStoreIndex = "Live",
	-- Mock data in Studio so playtests never touch (or get blocked by)
	-- real DataStores. Remove if you want to test real persistence.
	useMock = RunService:IsStudio(),
})

-- ============================== core access ==============================

-- Yields until the player's profile is loaded. Use this before any write
-- that could plausibly happen right after join (e.g. winning a match in
-- the same minute they joined).
function PlayerDataService.WaitForData(player: Player): DataTemplate.PlayerData?
	DataService:waitForData(player)
	return DataService:get(player)
end

function PlayerDataService.Get(player: Player, path: { string }?): any
	return DataService:get(player, path)
end

function PlayerDataService.GetChangedSignal(player: Player, path: { string })
	return DataService:getChangedSignal(player, path)
end

-- ============================== currency / exp ==============================

function PlayerDataService.AddExp(player: Player, amount: number)
	DataService:update(player, { "exp" }, function(current: number)
		return current + amount
	end)
end

function PlayerDataService.AddTix(player: Player, amount: number)
	DataService:update(player, { "tix" }, function(current: number)
		return current + amount
	end)
end

-- ============================== match hooks ==============================

function PlayerDataService.RecordMatchPlayed(player: Player)
	DataService:update(player, { "stats", "matchesPlayed" }, function(current: number)
		return current + 1
	end)
end

function PlayerDataService.GiveWinRewards(player: Player)
	if typeof(player) ~= "Instance" then
		return -- bots don't have profiles
	end
	-- Guard against a player winning before their profile finished loading.
	PlayerDataService.WaitForData(player)

	PlayerDataService.AddExp(player, GameConfig.Rewards.WinExp)
	PlayerDataService.AddTix(player, GameConfig.Rewards.WinTix)
	DataService:update(player, { "stats", "wins" }, function(current: number)
		return current + 1
	end)
end

-- ============================== leaderstats view ==============================
-- IntValues under leaderstats mirror the real data. They are display-only;
-- writing to them does nothing persistent.

local function setupLeaderstats(player: Player)
	DataService:waitForData(player)
	if not player.Parent then
		return -- left while data was loading
	end

	local data: DataTemplate.PlayerData? = DataService:get(player)
	if not data then
		warn(`[PlayerDataService] No data for {player.Name} after waitForData`)
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = (data.stats and data.stats.wins) or 0
	wins.Parent = leaderstats

	local exp = Instance.new("IntValue")
	exp.Name = "Exp"
	exp.Value = data.exp or 0
	exp.Parent = leaderstats

	local tix = Instance.new("IntValue")
	tix.Name = "Tix"
	tix.Value = data.tix or 0
	tix.Parent = leaderstats

	leaderstats.Parent = player

	DataService:getChangedSignal(player, { "exp" }):Connect(function(value: number)
		exp.Value = value
	end)
	DataService:getChangedSignal(player, { "tix" }):Connect(function(value: number)
		tix.Value = value
	end)
	DataService:getChangedSignal(player, { "stats", "wins" }):Connect(function(value: number)
		wins.Value = value
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupLeaderstats, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(setupLeaderstats, player)
end

return PlayerDataService
