--!strict
-- Horse.luau
-- An object that spawns a rideable horse welded to a character, with a launch ability.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Modules.Core.Packets)
local RunService = game:GetService("RunService")

local knockback = require(ReplicatedStorage.Shared.Modules.Game.Applyknockback)
-- local packets = require(ReplicatedStorage.Shared.Modules.Core.Packets) -- (uncomment if needed)
-- local Hitbox  = require(ReplicatedStorage.Packages.Hitbox)            -- (uncomment if needed)

local Horse = {}
Horse.__index = Horse

export type State = "Idle" | "Flying"

export type Horse = typeof(setmetatable(
	{} :: {
		Character: Model,
		Model: Model,
		Hitbox: BasePart,
		Attachment: Attachment,
		_alive: boolean,
		State: State,
		_facingConnection: RBXScriptConnection?,
	},
	Horse
))

-- Default launch parameters (your original "jump test" values)
local DEFAULT_FORCE = Vector3.new(0, 20000, 0)
local DEFAULT_MAX_FORCE = Vector3.new(100000, 100000, 100000)
local DEFAULT_DURATION = 0.2

--[[
	Creates a horse for the given character:
	- Disables the humanoid so it doesn't fight movement
	- Strips collision and mass off the character so it doesn't affect hitbox physics
	- Clones, positions, and welds the horse model
	- Auto-destroys itself when the character leaves
]]
function Horse.new(character: Model): Horse
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Disable humanoid so it doesn't interfere with movement
	for _, state in Enum.HumanoidStateType:GetEnumItems() do
		--print(state)
		if state == Enum.HumanoidStateType.None then
			continue
		end
		humanoid:SetStateEnabled(state, false)
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid.PlatformStand = true

	-- Disable collision / mass on all character parts
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
		end
	end

	-- Spawn the horse and weld it to the character
	local model = ReplicatedStorage.Assets.Models.Horse:Clone() :: Model
	model:PivotTo(hrp.CFrame - Vector3.new(0, 1.5, 0))
	model.Weld.Part1 = hrp
	model.Parent = workspace

	local self: Horse = setmetatable({
		Character = character,
		Model = model,
		Hitbox = model.Hitbox,
		Attachment = model.Hitbox.Attachment,
		State = "Idle" :: State, -- <<< add this
		_alive = true,
	}, Horse)

	self:Anchor(true) -- <<< spawn anchored

	-- Cleanup when the character is removed
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			self:Destroy()
		end
	end)

	return self
end

--[[
	Launches the horse (and welded rider) by applying knockback to the hitbox.
	All arguments are optional and fall back to the upward "jump" defaults.

		horse:Launch()                              -- straight up
		horse:Launch(Vector3.new(0, 15000, 30000))  -- up and forward
]]
function Horse.Launch(self: Horse, direction: Vector3?, force: number?, duration: number?)
	if not self._alive then
		return
	end

	local dir = (direction or Vector3.new(0, 1, 0)).Unit
	local magnitude = force or 20000

	knockback(self.Attachment, dir * magnitude, DEFAULT_MAX_FORCE, duration or DEFAULT_DURATION)
end

-- Rotates the hitbox ball by the given Euler angles (in degrees).
function Horse.Rotate(self: Horse, x: number?, y: number?, z: number?)
	if not self._alive then
		return
	end

	local align = self.Attachment.AlignOrientation
	align.CFrame *= CFrame.fromEulerAngles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

function Horse._startFacingVelocity(self: Horse)
	if self._facingConnection then
		return
	end

	self._facingConnection = RunService.Heartbeat:Connect(function()
		local velocity = self.Hitbox.AssemblyLinearVelocity
		if velocity.Magnitude < 1 then
			return -- avoid jitter when nearly stationary
		end

		local direction = velocity.Unit
		self.Attachment.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, direction)
	end)
end

function Horse._stopFacingVelocity(self: Horse)
	if self._facingConnection then
		self._facingConnection:Disconnect()
		self._facingConnection = nil
	end
end

-- Tears the horse down and gives the rider their normal character back.
-- Safe to call more than once.
function Horse.Destroy(self: Horse)
	if not self._alive then
		return
	end
	self._alive = false
	self:_stopFacingVelocity()

	if self.Model then
		self.Model:Destroy()
	end

	self:_restoreCharacter()
end

-- Undoes the humanoid lockdown from Horse.new so a dismounted player can
-- walk again without needing a respawn. (Match cleanup respawns everyone
-- anyway; this is the safety net for dismounting outside that flow.)
function Horse._restoreCharacter(self: Horse)
	local character = self.Character
	if not character or not character.Parent then
		return -- character already gone; a fresh spawn resets everything
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		for _, state in Enum.HumanoidStateType:GetEnumItems() do
			if state ~= Enum.HumanoidStateType.None then
				humanoid:SetStateEnabled(state, true)
			end
		end
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	-- Restore mass; CanCollide is left to the Humanoid, which re-manages
	-- limb collisions itself once its states are enabled again.
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = false
		end
	end
end

-- Moves the whole assembly (horse + welded rider) to the given CFrame.
-- Intended to be called while anchored (e.g. placing players on map spawns).
function Horse.Teleport(self: Horse, cframe: CFrame)
	if not self._alive then
		return
	end
	self.Hitbox.CFrame = cframe
	self.Hitbox.AssemblyLinearVelocity = Vector3.zero
	self.Hitbox.AssemblyAngularVelocity = Vector3.zero
end

function Horse.Anchor(self: Horse, resetVelocity: boolean)
	self.Hitbox.Anchored = true
	self:_stopFacingVelocity()

	-- Defaults to true — normal post-launch anchor should stop the horse dead.
	-- Pass false for stuns (or anything that should preserve momentum for when
	-- the horse is unanchored again).
	if resetVelocity ~= false then
		self.Hitbox.AssemblyLinearVelocity = Vector3.zero
		self.Hitbox.AssemblyAngularVelocity = Vector3.zero
	end
end

function Horse.Unanchor(self: Horse)
	self:_startFacingVelocity()
	self.Hitbox.Anchored = false
end

return Horse
