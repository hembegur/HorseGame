--!strict
-- Border.luau
-- The shrinking ball that surrounds the map.
--
-- COLLISION APPROACH: we deliberately do NOT use .Touched. Players are
-- *inside* the ball's volume, so Touched semantics are wrong (it fires on
-- overlap with the part, not its surface), and it's unreliable for anchored
-- or fast-moving parts anyway. Since the border is a sphere, an exact and
-- cheap test is a per-Heartbeat distance check:
--     (hitboxPos - center).Magnitude >= radius - margin  => touching border
-- The part itself is made non-collidable/non-touchable so physics never
-- fights it — it is purely visual; this class is the real border.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)
local knockback = require(ReplicatedStorage.Shared.Modules.Game.Applyknockback)

local CONFIG = GameConfig.Border
local KNOCKBACK_MAX_FORCE = Vector3.new(100000, 100000, 100000)

local Border = {}
Border.__index = Border

-- getTargets returns the horses currently in play: { [Player]: Horse }
export type Border = typeof(setmetatable(
	{} :: {
		Part: BasePart,
		_getTargets: () -> { [Player]: any },
		_initialSize: Vector3,
		_lastDamage: { [Player]: number },
		_connection: RBXScriptConnection?,
	},
	Border
))

local BORDER_TEMPLATE = ReplicatedStorage.Assets.Models.Border :: BasePart

function Border.new(getTargets: () -> { [Player]: any }): Border
	local part = BORDER_TEMPLATE:Clone()

	local self: Border = setmetatable({
		Part = part,
		_getTargets = getTargets,
		_initialSize = part.Size,
		_lastDamage = {},
		_connection = nil,
	}, Border)

	-- Purely visual — the distance check below is the real border.
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace
	part.Position = GameConfig.MapPosition

	part.Size = Vector3.new(CONFIG.StartDiameter, CONFIG.StartDiameter, CONFIG.StartDiameter)
	self._initialSize = part.Size

	return self
end

function Border.Activate(self: Border)
	if self._connection then
		return
	end
	self._connection = RunService.Heartbeat:Connect(function()
		self:_check()
	end)
end

function Border.Deactivate(self: Border)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

-- Shrinks the DIAMETER by ShrinkPerTurn studs, clamped to MinDiameter.
-- The ball stays centered (anchored parts resize around their center).
function Border.Shrink(self: Border)
	local newDiameter = math.max(self.Part.Size.X - CONFIG.ShrinkPerTurn, CONFIG.MinDiameter)
	self.Part.Size = Vector3.new(newDiameter, newDiameter, newDiameter)
end

function Border.GetRadius(self: Border): number
	return self.Part.Size.X / 2
end

function Border._check(self: Border)
	local center = self.Part.Position
	local radius = self:GetRadius()
	local now = os.clock()

	for player, horse in self._getTargets() do
		local hitbox = horse.Hitbox :: BasePart
		local offset = hitbox.Position - center
		local distance = offset.Magnitude

		if distance < radius - CONFIG.Margin then
			continue -- safely inside
		end

		-- Damage (per-player cooldown so it ticks, not melts)
		local last = self._lastDamage[player] or 0
		if now - last >= CONFIG.DamageCooldown then
			self._lastDamage[player] = now
			local humanoid = horse.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(CONFIG.Damage)
			end
		end

		-- Knockback toward the center. Only meaningful while unanchored
		-- (mid-flight); an anchored horse outside the border just takes damage.
		if not hitbox.Anchored and distance > 0 then
			local inward = -offset.Unit
			knockback(horse.Attachment, inward * CONFIG.KnockbackForce, KNOCKBACK_MAX_FORCE, CONFIG.KnockbackDuration)
		end
	end
end

-- Restores the ball to its pre-match size (so the next match starts fresh)
-- and stops monitoring. The part itself is a permanent workspace fixture.
function Border.Destroy(self: Border)
	self:Deactivate()
	self.Part:Destroy()
	table.clear(self._lastDamage)
end

return Border
