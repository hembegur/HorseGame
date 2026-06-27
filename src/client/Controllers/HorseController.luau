--!strict
-- HorseController.luau
-- Client-side counterpart to the server Horse class.
-- Owns input bindings, request flow, and (later) client-side animations/UI/camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Keybind = require(ReplicatedStorage.Shared.Modules.Game.Keybind)
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)

local KEYBIND_CONTEXT = "Horse"
local LAUNCH_KEY = Enum.KeyCode.Space

local HorseController = {}
HorseController.__index = HorseController

export type HorseController = typeof(setmetatable(
	{} :: {
		Character: Model,
		_janitor: any, -- Janitor type
		_active: boolean,
	},
	HorseController
))

--[[
	Creates a controller for the local player's character.
	Binds inputs and activates the "Horse" keybind context immediately.
]]
function HorseController.new(character: Model): HorseController
	local self: HorseController = setmetatable({
		Character = character,
		_janitor = Janitor.new(),
		_active = false,
	}, HorseController)

	self:_bindInputs()
	self:Activate()

	return self
end

-- Wires up every keybind under the "Horse" context. Add new actions here.
function HorseController._bindInputs(self: HorseController)
	local launch = Keybind.GetAction(KEYBIND_CONTEXT, "Launch")
	launch.KeyboardBinding.KeyCode = LAUNCH_KEY

	self._janitor:Add(
		launch.Pressed:Connect(function()
			self:RequestLaunch()
		end),
		"Disconnect"
	)
end

-- Fires the server-side launch. Server validates and calls horse:Launch().
function HorseController.RequestLaunch(self: HorseController)
	if not self._active then
		return
	end

	Packets.LaunchHorse:FireServer()
end

-- Enables the Horse keybind context so inputs start firing.
function HorseController.Activate(self: HorseController)
	if self._active then
		return
	end
	self._active = true
	Keybind.EnableContext(KEYBIND_CONTEXT)
end

-- Disables the controller without destroying it. Useful for cutscenes,
-- menus, or when the player dismounts but the controller should persist.
function HorseController.Deactivate(self: HorseController)
	self._active = false
	-- Note: EnableContext is mutually exclusive across all contexts.
	-- The caller should swap to whatever context is appropriate next
	-- (e.g. Keybind.EnableContext("InGame")) rather than us guessing.
end

-- Tears down all input connections. Safe to call more than once.
function HorseController.Destroy(self: HorseController)
	self._active = false
	self._janitor:Destroy()
end

return HorseController
