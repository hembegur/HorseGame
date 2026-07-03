--!strict
-- HorseLaunchUI.luau
-- Owns the HorseGui/HorseLaunchFrame elements: power display, +/- buttons,
-- and the lock button. Communicates outward ONLY via signals and getters.
-- Knows nothing about horses, arrows, packets, or launching.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Packages.Signal)

local MIN_POWER = 10
local MAX_POWER = 100
local POWER_STEP = 10
local DEFAULT_POWER = 50

local HorseLaunchUI = {}
HorseLaunchUI.__index = HorseLaunchUI

export type HorseLaunchUI = typeof(setmetatable(
	{} :: {
		PowerChanged: any, -- Signal<number>
		LockToggled: any, -- Signal<boolean>
		_frame: Frame,
		_powerText: TextLabel,
		_lockButton: TextButton,
		_power: number,
		_locked: boolean,
		_janitor: any,
	},
	HorseLaunchUI
))

function HorseLaunchUI.new(): HorseLaunchUI
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("HorseGui") :: ScreenGui
	local frame = gui:WaitForChild("HorseLaunchFrame") :: Frame

	local self: HorseLaunchUI = setmetatable({
		PowerChanged = Signal.new(),
		LockToggled = Signal.new(),
		_frame = frame,
		_powerText = frame:WaitForChild("PowerText") :: TextLabel,
		_lockButton = frame:WaitForChild("LockButton") :: TextButton,
		_power = DEFAULT_POWER,
		_locked = false,
		_janitor = Janitor.new(),
	}, HorseLaunchUI)

	local increaseButton = frame:WaitForChild("IncreaseButton") :: TextButton
	local decreaseButton = frame:WaitForChild("DecreaseButton") :: TextButton

	self._janitor:Add(self.PowerChanged, "Destroy")
	self._janitor:Add(self.LockToggled, "Destroy")

	self._janitor:Add(
		increaseButton.Activated:Connect(function()
			self:_setPower(self._power + POWER_STEP)
		end),
		"Disconnect"
	)

	self._janitor:Add(
		decreaseButton.Activated:Connect(function()
			self:_setPower(self._power - POWER_STEP)
		end),
		"Disconnect"
	)

	self._janitor:Add(
		self._lockButton.Activated:Connect(function()
			self._locked = not self._locked
			self:_refreshLockVisual()
			self.LockToggled:Fire(self._locked)
		end),
		"Disconnect"
	)

	self:_refreshPowerVisual()
	self:_refreshLockVisual()
	frame.Visible = false

	return self
end

function HorseLaunchUI.Show(self: HorseLaunchUI)
	-- Reset lock each aiming session so a stale lock doesn't carry over.
	self._locked = false
	self:_refreshLockVisual()
	self._frame.Visible = true
end

function HorseLaunchUI.Hide(self: HorseLaunchUI)
	self._frame.Visible = false
end

function HorseLaunchUI.GetPower(self: HorseLaunchUI): number
	return self._power
end

function HorseLaunchUI.IsLocked(self: HorseLaunchUI): boolean
	return self._locked
end

function HorseLaunchUI._setPower(self: HorseLaunchUI, power: number)
	local clamped = math.clamp(power, MIN_POWER, MAX_POWER)
	if clamped == self._power then
		return
	end
	self._power = clamped
	self:_refreshPowerVisual()
	self.PowerChanged:Fire(clamped)
end

function HorseLaunchUI._refreshPowerVisual(self: HorseLaunchUI)
	self._powerText.Text = tostring(self._power)
end

function HorseLaunchUI._refreshLockVisual(self: HorseLaunchUI)
	self._lockButton.Text = self._locked and "Locked" or "Lock"
end

function HorseLaunchUI.Destroy(self: HorseLaunchUI)
	self._janitor:Destroy()
end

return HorseLaunchUI
