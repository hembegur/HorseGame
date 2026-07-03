local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLoader = require(ReplicatedStorage.Shared.Modules.Core.ModuleLoader)
ModuleLoader.Load(ReplicatedStorage.Shared.Modules, true)
ModuleLoader.Load(ReplicatedStorage.Shared.Classes, true)
ModuleLoader.Load(ReplicatedStorage.Shared.Services, true)
ModuleLoader.Load(script.Services, true)
