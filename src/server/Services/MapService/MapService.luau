--!strict
-- MapService.luau
-- Loads a random map from the "Maps" folder onto workspace.MapSpawnPosition
-- and hands out shuffled spawn parts so no two players share one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local GameConfig = require(ReplicatedStorage.Shared.Modules.Core.GameConfig)

local SPAWN_HEIGHT_OFFSET = 5 -- studs above the spawn part

local MapService = {}

local function getMapsFolder(): Folder
	local folder = ReplicatedStorage.Assets:FindFirstChild("Maps")
	assert(folder, "[MapService] Could not find a 'Maps' folder in ServerStorage, ReplicatedStorage, or workspace")
	return folder :: Folder
end

-- Clones a random map, pivots it onto MapSpawnPosition, parents it to workspace.
-- Returns the loaded map and its shuffled spawn parts.
function MapService.LoadRandomMap(): (Model, { BasePart })
	local mapsFolder = getMapsFolder()
	local maps = mapsFolder:GetChildren()
	assert(#maps > 0, "[MapService] 'Maps' folder is empty")

	local template = maps[math.random(#maps)] :: Model
	local map = template:Clone()

	map:PivotTo(CFrame.new(GameConfig.MapPosition))
	map.Parent = workspace

	local spawnsFolder = map:FindFirstChild("Spawns")
	assert(spawnsFolder, `[MapService] Map "{map.Name}" has no 'Spawns' folder`)

	local spawns: { BasePart } = {}
	for _, part in spawnsFolder:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Transparency = 1
			table.insert(spawns, part)
		end
	end
	assert(#spawns > 0, `[MapService] Map "{map.Name}" has no spawn parts`)

	-- Fisher-Yates shuffle so spawn assignment is random but unique per index.
	for i = #spawns, 2, -1 do
		local j = math.random(i)
		spawns[i], spawns[j] = spawns[j], spawns[i]
	end

	return map, spawns
end

-- CFrame a player's horse should be teleported to for a given spawn part.
function MapService.GetSpawnCFrame(spawnPart: BasePart): CFrame
	return spawnPart.CFrame + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0)
end

function MapService.Unload(map: Model?)
	if map then
		map:Destroy()
	end
end

return MapService
