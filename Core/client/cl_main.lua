--[[
    Framework Core - Client Main

    Handles client-side initialization and player data management
]]

-- Framework object is already created by shared/sh_main.lua
-- We just add client-specific properties here.
-- NOTE: The player module handles session waiting, character selection,
-- and spawning. Core just sets up the shared object and exports.

ReDOCore.PlayerLoaded = false
ReDOCore.PlayerData = {}

-- Export the Framework object for other resources.
-- Other resources call: local Core = exports['Core']:GetCoreObject()
exports('getSharedObject', function()
    return ReDOCore
end)

exports('GetCoreObject', function()
    return ReDOCore
end)

ReDOCore.Info("Client initialized")
