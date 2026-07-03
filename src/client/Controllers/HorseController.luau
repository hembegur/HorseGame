--!strict
-- HorseController.luau
-- Client-side orchestrator for the horse. Owns the launch state machine and
-- the space keybind; delegates visuals to AimIndicator and HorseLaunchUI.
--
-- State machine:
--   Idle   --space--> Aiming  (arrow + GUI shown, horse still anchored)
--   Aiming --space--> Flying  (launch packet sent, arrow + GUI hidden)
--   Flying --server HorseStateChanged--> Idle (server re-anchored us)
--
-- Space is ignored while Flying. Aiming cannot be cancelled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Keybind = require(ReplicatedStorage.Shared.Modules.Game.Keybind)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local AimIndicator = require(script.Parent.AimIndicator)
local HorseLaunchUI = require(script.Parent.HorseLaunchUI)

local KEYBIND_CONTEXT = "Horse"
local LAUNCH_KEY = Enum.KeyCode.Space

export type State = "Idle" | "Aiming" | "Flying"

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
		State = "Idle" :: State,
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

-- All keybinds under the "Horse" context live here.
function HorseController._bindInputs(self: HorseController)
	local launch = Keybind.GetAction(KEYBIND_CONTEXT, "Launch")
	launch.KeyboardBinding.KeyCode = LAUNCH_KEY

	self._janitor:Add(
		launch.Pressed:Connect(function()
			self:_onLaunchKey()
		end),
		"Disconnect"
	)
end

-- UI signals -> aim indicator. The controller is the only piece that knows
-- both objects exist; they never talk to each other directly.
function HorseController._bindUI(self: HorseController)
	self._janitor:Add(
		self._ui.LockToggled:Connect(function(locked: boolean)
			self._aimIndicator:SetLocked(locked)
		end),
		"Disconnect"
	)
end

-- Server -> client state updates.
function HorseController._bindPackets(self: HorseController)
	self._janitor:Add(
		Packets.HorseStateChanged.OnClientEvent:Connect(function(state: string)
			self:_setState(state :: State)
		end),
		"Disconnect"
	)
end

-- The single entry point for the space key. What it does depends on state.
function HorseController._onLaunchKey(self: HorseController)
	if not self._active then
		return
	end

	if self.State == "Idle" then
		self:_startAiming()
	elseif self.State == "Aiming" then
		self:_launch()
	end
	-- "Flying": ignored on purpose.
end

function HorseController._startAiming(self: HorseController)
	self:_setState("Aiming")
end

function HorseController._launch(self: HorseController)
	local direction = self._aimIndicator:GetDirection()
	local power = self._ui:GetPower()

	Packets.LaunchHorse:Fire(direction, power)

	-- Optimistically enter Flying so the key locks out instantly.
	-- The server remains authoritative and will send us back to Idle.
	self:_setState("Flying")
end

-- All show/hide side effects live here, driven purely by state.
-- Adding a new state later = add a branch here, not scattered flags.
function HorseController._setState(self: HorseController, state: State)
	if self.State == state then
		return
	end
	self.State = state

	if state == "Aiming" then
		self._aimIndicator:Show()
		self._ui:Show()
	else -- Idle or Flying
		self._aimIndicator:Hide()
		self._ui:Hide()
	end
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
