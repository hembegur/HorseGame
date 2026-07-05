--!strict
-- Match.luau
-- One match instance: loads a map, spawns players, runs the turn loop,
-- shrinks the border, evaluates the winner, and cleans everything up.
--
-- Turn flow (all players act simultaneously each turn):
--   1. Border shrinks (from turn 2 onward)
--   2. TurnStarted fired to alive players -> clients show aim UI (10s countdown)
--   3. RequestLaunchData fired -> clients reply with LaunchHorse(direction, power)
--   4. All collected launches fire at once; physics runs for FlightDuration
--   5. Horses re-anchor; eliminations evaluated; repeat or finish
--
-- ABILITIES (future): slot ability selection into step 2 (client sends an
-- ability id alongside its aim) and ability execution between steps 3 and 4.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local Border = require(ServerScriptService.Server.Classes.Border.Border)
local HorseService = require(ServerScriptService.Server.Services.HorseService.HorseService)
local MapService = require(ServerScriptService.Server.Services.MapService.MapService)

export type Gamemode = "FFA" | "Team"

local Match = {}
Match.__index = Match

export type Match = typeof(setmetatable(
	{} :: {
		Participants: { Player },
		Gamemode: Gamemode,
		_alive: { [Player]: boolean },
		_map: Model?,
		_border: Border.Border?,
		_connections: { RBXScriptConnection },
		_pendingLaunches: { [Player]: { direction: Vector3, power: number } },
		_collecting: boolean,
	},
	Match
))

function Match.new(participants: { Player }, gamemode: Gamemode): Match
	return setmetatable({
		Participants = participants,
		Gamemode = gamemode,
		_alive = {},
		_map = nil,
		_border = nil,
		_connections = {},
		_pendingLaunches = {},
		_collecting = false,
	}, Match)
end

-- Runs the whole match. Yields until it ends. Returns the winners
-- (empty table = draw).
function Match.Run(self: Match): { Player }
	self:_setup()

	local winners: { Player } = {}
	local turn = 0

	while true do
		turn += 1

		-- 1) Border shrinks every turn after the first
		if turn > 1 and self._border then
			self._border:Shrink()
		end

		-- 2) Aiming phase
		local duration = GameConfig.TurnDuration
		for player in self._alive do
			Packets.TurnStarted:FireClient(player, duration)
		end
		for t = duration, 1, -1 do
			self:_broadcast(`Turn {turn} — Aim! ({t})`)
			task.wait(1)
		end

		-- 3) Collect final aim data from clients
		self:_collectLaunchData()

		-- 4) Launch everyone simultaneously
		self:_broadcast("Launching!")
		self:_launchAll()
		task.wait(GameConfig.FlightDuration)
		self:_anchorAll()

		-- 5) Evaluate
		local done
		winners, done = self:_evaluate()
		if done then
			break
		end
	end

	self:_cleanup()
	return winners
end

-- ============================== setup ==============================

function Match._setup(self: Match)
	-- Map + spawns
	local map, spawns = MapService.LoadRandomMap()
	self._map = map

	-- Team assignment (attributes replicate to clients automatically,
	-- which is what TeamVisuals on the client reads).
	if self.Gamemode == "Team" then
		for i, player in self.Participants do
			player:SetAttribute("Team", (i % 2) + 1)
		end
	end

	-- Mount + place players. Players are horseless in the lobby, so the
	-- match is what spawns their horse. Spawns are pre-shuffled and unique
	-- per index, so no two players ever share a spawn part.
	for i, player in self.Participants do
		local horse = HorseService.SpawnHorse(player)
		local spawnPart = spawns[((i - 1) % #spawns) + 1]
		if horse and spawnPart then
			horse:Teleport(MapService.GetSpawnCFrame(spawnPart))
			self._alive[player] = true
		end
		-- No horse = no character right now; they simply sit this match out.
	end
	if #self.Participants > #spawns then
		warn(`[Match] {#self.Participants} players but only {#spawns} spawns — some were doubled up.`)
	end

	-- Border
	local border = Border.new(function()
		return self:_aliveHorses()
	end)
	border:Activate()
	self._border = border

	-- Eliminations: death or leaving
	for player in self._alive do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(
				self._connections,
				humanoid.Died:Connect(function()
					self:_eliminate(player)
				end)
			)
		else
			-- No character/humanoid = can't participate
			self:_eliminate(player)
		end
	end
	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player)
			self:_eliminate(player)
		end)
	)

	-- Launch data collector (only accepts while _collecting is true)
	table.insert(
		self._connections,
		Packets.LaunchHorse.OnServerEvent:Connect(function(player, direction: Vector3, power: number)
			if not self._collecting or not self._alive[player] then
				return
			end
			if direction.Magnitude == 0 or direction ~= direction then -- zero or NaN
				return
			end
			self._pendingLaunches[player] = {
				direction = direction.Unit,
				power = math.clamp(power, GameConfig.MinPower, GameConfig.MaxPower),
			}
		end)
	)

	-- Teammate aim relay (team mode only): forward a player's aim to their
	-- teammates so their clients can draw the arrow.
	table.insert(
		self._connections,
		Packets.AimUpdate.OnServerEvent:Connect(function(player, direction: Vector3)
			if self.Gamemode ~= "Team" or not self._alive[player] then
				return
			end
			local team = player:GetAttribute("Team")
			if team == nil then
				return
			end
			for other in self._alive do
				if other ~= player and other:GetAttribute("Team") == team then
					Packets.TeammateAim:FireClient(other, player, direction)
				end
			end
		end)
	)
end

-- ============================== turn helpers ==============================

function Match._collectLaunchData(self: Match)
	table.clear(self._pendingLaunches)
	self._collecting = true

	local expected = 0
	for player in self._alive do
		expected += 1
		Packets.RequestLaunchData:FireClient(player)
	end

	local deadline = os.clock() + GameConfig.LaunchResponseTimeout
	while os.clock() < deadline do
		local received = 0
		for _ in self._pendingLaunches do
			received += 1
		end
		if received >= expected then
			break
		end
		task.wait(0.05)
	end

	self._collecting = false
end

function Match._launchAll(self: Match)
	for player in self._alive do
		local horse = HorseService.GetHorse(player)
		local data = self._pendingLaunches[player]
		if horse and data then
			horse.State = "Flying"
			horse:Unanchor()
			horse:Launch(data.direction, GameConfig.BasePower * data.power / 100)
		end
		-- No data (afk / lagged out): horse simply stays anchored this turn.
	end
end

function Match._anchorAll(self: Match)
	for player in self._alive do
		local horse = HorseService.GetHorse(player)
		if horse then
			horse:Anchor(true)
			horse.State = "Idle"
			Packets.HorseStateChanged:FireClient(player, "Idle")
		end
	end
end

-- ============================== state ==============================

function Match._aliveHorses(self: Match): { [Player]: any }
	local horses = {}
	for player in self._alive do
		local horse = HorseService.GetHorse(player)
		if horse then
			horses[player] = horse
		end
	end
	return horses
end

function Match._eliminate(self: Match, player: Player)
	self._alive[player] = nil
end

-- Returns (winners, isMatchOver)
function Match._evaluate(self: Match): ({ Player }, boolean)
	local alive: { Player } = {}
	for player in self._alive do
		table.insert(alive, player)
	end

	if self.Gamemode == "FFA" then
		if #alive <= 1 then
			return alive, true -- 1 winner, or 0 = draw
		end
		return {}, false
	end

	-- Team: match is over when at most one team has a living member
	local aliveTeams: { [number]: boolean } = {}
	for _, player in alive do
		local team = player:GetAttribute("Team")
		if team ~= nil then
			aliveTeams[team] = true
		end
	end

	local teamCount, lastTeam = 0, nil
	for team in aliveTeams do
		teamCount += 1
		lastTeam = team
	end

	if teamCount == 0 then
		return {}, true -- everyone died: draw
	elseif teamCount == 1 then
		-- Whole winning team gets the win, including fallen teammates
		local winners = {}
		for _, player in self.Participants do
			if player.Parent and player:GetAttribute("Team") == lastTeam then
				table.insert(winners, player)
			end
		end
		return winners, true
	end
	return {}, false
end

-- ============================== teardown ==============================

function Match._broadcast(self: Match, text: string)
	for _, player in Players:GetPlayers() do
		Packets.MenuText:FireClient(player, text)
	end
end

function Match._cleanup(self: Match)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)

	if self._border then
		self._border:Destroy()
		self._border = nil
	end

	MapService.Unload(self._map)
	self._map = nil

	-- Dismount everyone, clear teams, and send them back to the lobby with
	-- a fresh (horseless) character.
	for _, player in self.Participants do
		if player.Parent then
			HorseService.RemoveHorse(player)
			player:SetAttribute("Team", nil)
			task.spawn(function()
				player:LoadCharacterAsync()
			end)
		end
	end
end

return Match
