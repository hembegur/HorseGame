local rs = game:GetService("ReplicatedStorage")
local packages = rs:WaitForChild("Packages")
local packet = require(packages:WaitForChild("Packet"))

local Packets = {}

Packets.HorseReady = packet("HorseReady", packet.Instance)
Packets.LaunchHorse = packet("LaunchHorse", packet.Vector3F24, packet.NumberU8) -- direction + power
Packets.HorseStateChanged = packet("HorseStateChanged", packet.String)

-- Game loop / match
Packets.MenuText = packet("MenuText", packet.String) -- "Intermission (10)", "Waiting for players...", ...
Packets.TurnStarted = packet("TurnStarted", packet.NumberU8) -- turn duration in seconds
Packets.RequestLaunchData = packet("RequestLaunchData") -- server asks client for its final aim
Packets.AimUpdate = packet("AimUpdate", packet.Vector3F24) -- client -> server, throttled, for teammate arrows
Packets.TeammateAim = packet("TeammateAim", packet.Instance, packet.Vector3F24) -- server -> teammates

Packets.AdminCommand = packet("AdminCommand", packet.String)

return Packets

--[[
	S8		Minimum: -128			Maximum: 127
	S16		Minimum: -32768			Maximum: 32767
	S24		Minimum: -8388608		Maximum: 8388607
	S32		Minimum: -2147483648	Maximum: 2147483647

	U8		Minimum: 0				Maximum: 255
	U16		Minimum: 0				Maximum: 65535
	U24		Minimum: 0				Maximum: 16777215
	U32		Minimum: 0				Maximum: 4294967295

	F16		±2048					[65520]
	F24		±262144					[4294959104]
	F32		±16777216				[170141183460469231731687303715884105728]
	F64		±9007199254740992		[huge]
]]
