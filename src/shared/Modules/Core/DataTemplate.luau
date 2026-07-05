--!strict
-- DataTemplate.luau
-- The single source of truth for the shape of persistent player data.
-- This module stores ONLY the template and its exported type — all logic
-- lives in PlayerDataService (server) / data consumers (client).
--
-- Rules (from dataService):
--   * JSON-safe values only: no Vector3, CFrame, Instances, etc.
--   * New keys added here are auto-reconciled into existing saves on join.

local DataTemplate = {
	exp = 0,
	tix = 0,

	stats = {
		wins = 0,
		matchesPlayed = 0,
	},
}

export type PlayerData = typeof(DataTemplate)

return DataTemplate
