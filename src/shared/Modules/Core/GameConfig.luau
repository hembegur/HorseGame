--!strict
-- GameConfig.luau
-- Central tuning knobs for the whole game. Server is the authority for all
-- of these; the client may read them for display only.

local GameConfig = {
	-- Lobby / loop
	MinPlayers = 2,
	IntermissionTime = 10, -- seconds
	ResultsTime = 5, -- seconds to show winner text before next loop
	MapPosition = Vector3.new(-13, -70, -211),

	-- Match / turns
	TurnDuration = 10, -- seconds to aim + pick power
	FlightDuration = 5, -- seconds of physics after launch
	LaunchResponseTimeout = 1, -- grace period to collect client aim data

	-- Launch power
	MinPower = 10,
	MaxPower = 100,
	BasePower = 60, -- force at power 100 (Launch force = BasePower * power / 100)

	-- Border
	Border = {
		StartDiameter = 300,
		ShrinkPerTurn = 15, -- studs removed from the DIAMETER each turn
		MinDiameter = 40,
		Damage = 20,
		DamageCooldown = 1, -- seconds between damage ticks per player
		KnockbackForce = 40,
		KnockbackDuration = 0.15,
		Margin = 3, -- how close to the surface counts as "touching"
	},

	-- Rewards
	Rewards = {
		WinExp = 100,
		WinTix = 25,
	},
}

return GameConfig
