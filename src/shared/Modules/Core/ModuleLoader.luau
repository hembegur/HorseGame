--!strict
-- Loader.luau
-- Auto-requires every ModuleScript in a folder and returns them keyed by name.
--
-- Usage:
--   local Loader = require(ReplicatedStorage.Shared.Modules.Core.Loader)
--
--   local game = Loader(ReplicatedStorage.Shared.Modules.Game)
--   game.Keybind.GetAction(...)
--   game.Applyknockback(...)
--
--   -- Recursive (descends into subfolders, flat result keyed by name):
--   local all = Loader(ReplicatedStorage.Shared.Modules, true)

local Loader = {}

-- Loads every ModuleScript that is a direct child of `container`.
-- If `recursive` is true, also descends into Folder/ModuleScript children
-- and flattens everything into one table.
function Loader.Load(container: Instance, recursive: boolean?): { [string]: any }
	local modules: { [string]: any } = {}

	for _, child in container:GetChildren() do
		if child == script then
			-- Skip ourselves so Loader doesn't load Loader.
			continue
		end

		if child:IsA("ModuleScript") then
			if modules[child.Name] ~= nil then
				warn(
					`[Loader] Duplicate module name "{child.Name}" in {container:GetFullName()} — later one ignored.`
				)
			else
				modules[child.Name] = require(child) :: any
			end

			if recursive then
				-- A ModuleScript can also contain nested ModuleScripts.
				for key, value in Loader.Load(child, true) do
					if modules[key] ~= nil then
						warn(
							`[Loader] Duplicate module name "{key}" while flattening {container:GetFullName()} — later one ignored.`
						)
					else
						modules[key] = value
					end
				end
			end
		elseif recursive and child:IsA("Folder") then
			for key, value in Loader.Load(child, true) do
				if modules[key] ~= nil then
					warn(
						`[Loader] Duplicate module name "{key}" while flattening {container:GetFullName()} — later one ignored.`
					)
				else
					modules[key] = value
				end
			end
		end
	end

	return modules
end

-- Sugar: `Loader(folder)` is the same as `Loader.Load(folder)`.
return setmetatable(Loader, {
	__call = function(_, container: Instance, recursive: boolean?)
		return Loader.Load(container, recursive)
	end,
}) :: typeof(Loader) & { __call: (any, Instance, boolean?) -> { [string]: any } }
