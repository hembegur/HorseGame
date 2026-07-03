--!strict
-- AimIndicator.luau
-- Owns the Arrow model: shows/hides it, updates its CFrame to match the
-- camera direction, and supports freezing (locking) the direction.
-- Knows nothing about GUI, packets, or the launch flow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local ARROW_TEMPLATE = ReplicatedStorage.Assets.Models.Arrow :: Model
local ARROW_OFFSET = 4 -- studs in front of the origin part, along the aim direction

local AimIndicator = {}
AimIndicator.__index = AimIndicator

export type AimIndicator = typeof(setmetatable(
	{} :: {
		_origin: BasePart, -- part the arrow is positioned around (horse hitbox / HRP)
		_arrow: Model?,
		_janitor: any,
		_locked: boolean,
		_direction: Vector3, -- last computed (or frozen) aim direction
	},
	AimIndicator
))

function AimIndicator.new(origin: BasePart): AimIndicator
	local self: AimIndicator = setmetatable({
		_origin = origin,
		_arrow = nil,
		_janitor = Janitor.new(),
		_locked = false,
		_direction = Vector3.new(0, 0, -1),
	}, AimIndicator)

	return self
end

-- Shows the arrow and starts tracking the camera every frame.
function AimIndicator.Show(self: AimIndicator)
	if self._arrow then
		return -- already showing
	end

	local arrow = ARROW_TEMPLATE:Clone()
	arrow.Parent = workspace
	self._arrow = arrow
	self._locked = false

	self._janitor:Add(arrow, "Destroy", "Arrow")
	self._janitor:Add(
		RunService.RenderStepped:Connect(function()
			self:_update()
		end),
		"Disconnect",
		"UpdateConnection"
	)
end

-- Hides the arrow and stops tracking.
function AimIndicator.Hide(self: AimIndicator)
	self._janitor:Remove("UpdateConnection")
	self._janitor:Remove("Arrow")
	self._arrow = nil
	self._locked = false
end

-- Freezes/unfreezes the direction. While locked, the camera can move
-- freely without changing the aim.
function AimIndicator.SetLocked(self: AimIndicator, locked: boolean)
	self._locked = locked
end

function AimIndicator.IsLocked(self: AimIndicator): boolean
	return self._locked
end

-- The current aim direction (live camera vector, or the frozen one if locked).
function AimIndicator.GetDirection(self: AimIndicator): Vector3
	return self._direction
end

function AimIndicator._update(self: AimIndicator)
	local arrow = self._arrow
	if not arrow then
		return
	end

	local camera = workspace.CurrentCamera
	if not self._locked then
		self._direction = camera.CFrame.LookVector
	end

	local originPosition = self._origin.Position
	local arrowPosition = originPosition + self._direction * ARROW_OFFSET
	arrow:PivotTo(CFrame.lookAt(arrowPosition, arrowPosition + self._direction))
end

function AimIndicator.Destroy(self: AimIndicator)
	self._janitor:Destroy()
	self._arrow = nil
end

return AimIndicator
