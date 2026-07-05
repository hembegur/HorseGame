--!strict
-- HorseController.luau
-- Client-side orchestrator for the horse. Launching is now TURN-BASED and
-- server-driven — the old free "press space to launch" flow has been removed.
--
-- State machine (all transitions come from the server):
--   Locked --TurnStarted-->        Aiming  (arrow + GUI shown; player adjusts)
--   Aiming --RequestLaunchData-->  Flying  (final aim sent; UI hidden)
--   Flying --HorseStateChanged-->  Locked  (server re-anchored us)
--
-- While Aiming (team mode support): the aim direction is broadcast to the
-- server on a throttle so teammates can see our arrow.
--
-- ABILITIES (future): bind ability keys in _bindInputs under the "Horse"
-- keybind context, store the selection while Aiming, and send it alongside
-- the aim in _submitLaunch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Keybind = require(ReplicatedStorage.Shared.Modules.Game.Keybind)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local AimIndicator = require(script.Parent.AimIndicator)
local HorseLaunchUI = require(script.Parent.HorseLaunchUI)

local KEYBIND_CONTEXT = "Horse"
local AIM_BROADCAST_INTERVAL = 0.2 -- seconds between AimUpdate packets while aiming

export type State = "Locked" | "Aiming" | "Flying"

local HorseController = {}
HorseController.__index = HorseController

export type HorseController = typeof(setmetatable(
	{} :: {
		Character: Model,
		State: State,
		_aimIndicator: AimIndicator.AimIndicator,
		_ui: HorseLaunchUI.HorseLaunchUI,
		_janitor: any,
		_active: boolean,
	},
	HorseController
))

function HorseController.new(character: Model): HorseController
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart

	local self: HorseController = setmetatable({
		Character = character,
		State = "Locked" :: State,
		_aimIndicator = AimIndicator.new(hrp),
		_ui = HorseLaunchUI.new(),
		_janitor = Janitor.new(),
		_active = false,
	}, HorseController)

	self._janitor:Add(self._aimIndicator, "Destroy")
	self._janitor:Add(self._ui, "Destroy")

	self:_bindInputs()
	self:_bindUI()
	self:_bindPackets()
	self:Activate()

	return self
end

-- Keybinds under the "Horse" context. Space no longer launches — this is
-- kept as the home for future ability keys.
function HorseController._bindInputs(self: HorseController)
	-- Example for later:
	-- local ability1 = Keybind.GetAction(KEYBIND_CONTEXT, "Ability1")
	-- ability1.KeyboardBinding.KeyCode = Enum.KeyCode.One
	-- self._janitor:Add(ability1.Pressed:Connect(function() ... end), "Disconnect")
end

function HorseController._bindUI(self: HorseController)
	self._janitor:Add(
		self._ui.LockToggled:Connect(function(locked: boolean)
			self._aimIndicator:SetLocked(locked)
		end),
		"Disconnect"
	)
end

-- Everything is server-driven: the server tells us when to aim, when to
-- hand over our aim, and when we're back to idle.
function HorseController._bindPackets(self: HorseController)
	self._janitor:Add(
		Packets.TurnStarted.OnClientEvent:Connect(function(_duration: number)
			if self._active then
				self:_setState("Aiming")
			end
		end),
		"Disconnect"
	)

	self._janitor:Add(
		Packets.RequestLaunchData.OnClientEvent:Connect(function()
			if self._active and self.State == "Aiming" then
				self:_submitLaunch()
			end
		end),
		"Disconnect"
	)

	self._janitor:Add(
		Packets.HorseStateChanged.OnClientEvent:Connect(function(state: string)
			if state == "Idle" then
				self:_setState("Locked")
			end
		end),
		"Disconnect"
	)
end

function HorseController._submitLaunch(self: HorseController)
	local direction = self._aimIndicator:GetDirection()
	local power = self._ui:GetPower()

	Packets.LaunchHorse:Fire(direction, power)
	self:_setState("Flying")
end

-- All show/hide side effects live here, driven purely by state.
function HorseController._setState(self: HorseController, state: State)
	if self.State == state then
		return
	end
	self.State = state

	if state == "Aiming" then
		self._aimIndicator:Show()
		self._ui:Show()
		self:_startAimBroadcast()
	else -- Locked or Flying
		self:_stopAimBroadcast()
		self._aimIndicator:Hide()
		self._ui:Hide()
	end
end

-- Throttled aim replication so teammates can see our arrow (server only
-- relays these in team mode, so sending them always is harmless).
function HorseController._startAimBroadcast(self: HorseController)
	local elapsed = 0
	self._janitor:Add(
		RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed < AIM_BROADCAST_INTERVAL then
				return
			end
			elapsed = 0
			Packets.AimUpdate:Fire(self._aimIndicator:GetDirection())
		end),
		"Disconnect",
		"AimBroadcast"
	)
end

function HorseController._stopAimBroadcast(self: HorseController)
	self._janitor:Remove("AimBroadcast")
end

function HorseController.Activate(self: HorseController)
	if self._active then
		return
	end
	self._active = true
	Keybind.EnableContext(KEYBIND_CONTEXT)
end

function HorseController.Deactivate(self: HorseController)
	self._active = false
end

function HorseController.Destroy(self: HorseController)
	self._active = false
	self._janitor:Destroy()
end

return HorseController
