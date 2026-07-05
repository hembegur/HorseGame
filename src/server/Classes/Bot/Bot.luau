--!strict
-- Bot.luau
-- A test NPC that duck-types the small slice of the Player API that Match,
-- HorseService, and Horse actually touch:
--
--   .Character  .Parent  .DisplayName  .Name  .UserId
--   :SetAttribute() :GetAttribute()  :LoadCharacterAsync()
--
-- Because of that, Match can treat a Bot exactly like a Player everywhere
-- EXCEPT network calls (Packets:FireClient) — those must be guarded with
-- isRealPlayer(), since a Bot is a plain table, not a Player Instance.
--
-- Requires a rig template at ReplicatedStorage.Assets.Models.BotRig
-- (any R6/R15 dummy with a Humanoid + HumanoidRootPart).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)

local BOT_RIG = ReplicatedStorage.Assets.Models.BotRig :: Model
local UP_BIAS = 0.5 -- upward arc mixed into every launch direction
local TARGET_NEAREST_CHANCE = 0.3 -- odds of aiming at the nearest entity

local nextBotId = 0

local Bot = {}
Bot.__index = Bot
Bot.IsBot = true -- discriminator; real Players don't have this

export type Bot = typeof(setmetatable(
	{} :: {
		Name: string,
		DisplayName: string,
		UserId: number, -- negative, so it can never collide with a real player
		Parent: Instance?, -- truthy = "still in game", mirrors Player.Parent checks
		Character: Model?,
		_attributes: { [string]: any },
		_destroyed: boolean,
	},
	Bot
))

function Bot.new(spawnCFrame: CFrame): Bot
	nextBotId += 1
	local name = `Bot{nextBotId}`

	local self: Bot = setmetatable({
		Name = name,
		DisplayName = name,
		UserId = -nextBotId,
		Parent = Players, -- anything truthy works for `player.Parent` checks
		Character = nil,
		_attributes = {},
		_destroyed = false,
	}, Bot)

	self:_spawnCharacter(spawnCFrame)
	return self
end

-- ============================== Player surface ==============================

function Bot.SetAttribute(self: Bot, key: string, value: any)
	self._attributes[key] = value
end

function Bot.GetAttribute(self: Bot, key: string): any
	return self._attributes[key]
end

-- Duck-typed respawn: Match cleanup calls player:LoadCharacterAsync() on
-- every participant, and this makes that Just Work for bots too.
function Bot.LoadCharacterAsync(self: Bot)
	if self._destroyed then
		return
	end
	self:_spawnCharacter(self:_getLobbyCFrame())
end

-- ============================== brain ==============================

-- Decides a launch for this turn. Mostly random direction/power, but
-- occasionally aims at the nearest other entity (bot or player).
-- aliveHorses is Match's { [Contestant]: Horse } map.
function Bot.DecideLaunch(self: Bot, aliveHorses: { [any]: any }): (Vector3, number)
	local myHorse = aliveHorses[self]
	local myPosition = myHorse and myHorse.Hitbox.Position or Vector3.zero

	local direction: Vector3? = nil

	if math.random() < TARGET_NEAREST_CHANCE then
		local nearestPosition: Vector3? = nil
		local nearestDistance = math.huge
		for entity, horse in aliveHorses do
			if entity ~= self then
				local position = horse.Hitbox.Position
				local distance = (position - myPosition).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPosition = position
				end
			end
		end
		if nearestPosition then
			local toTarget = nearestPosition - myPosition
			if toTarget.Magnitude > 0 then
				direction = (toTarget.Unit + Vector3.new(0, UP_BIAS, 0)).Unit
			end
		end
	end

	if not direction then
		local yaw = math.random() * 2 * math.pi
		direction = (Vector3.new(math.cos(yaw), 0, math.sin(yaw)) + Vector3.new(0, UP_BIAS, 0)).Unit
	end

	local power = math.random(GameConfig.MinPower, GameConfig.MaxPower)
	return direction :: Vector3, power
end

-- ============================== internals ==============================

function Bot._spawnCharacter(self: Bot, cframe: CFrame)
	if self.Character then
		self.Character:Destroy()
	end

	local character = BOT_RIG:Clone()
	character.Name = self.Name
	character:PivotTo(cframe)
	character.Parent = workspace
	self.Character = character
end

function Bot._getLobbyCFrame(self: Bot): CFrame
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
	end
	return CFrame.new(0, 10, 0)
end

function Bot.Destroy(self: Bot)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self.Parent = nil -- makes `player.Parent` checks treat us as "left"

	if self.Character then
		self.Character:Destroy()
		self.Character = nil
	end
end

return Bot
