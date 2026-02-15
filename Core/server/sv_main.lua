--[[
    Framework Core - Server Main

    Handles server initialization and core systems
]]

-- Initialize server-specific properties
ReDOCore.PlayerCount = 0
ReDOCore.MaxPlayers = GetConvarInt('sv_maxclients', 52)

-- Server ready flag
local isServerReady = false

-- Initialize the server
function ReDOCore.Init()
    ReDOCore.Info("Initializing ReDOCore Server...")

    -- Verify required configuration
    if not Config.Authorization then
        ReDOCore.Error("Authorization config is missing! Server cannot start.")
        return false
    end

    -- Set server as ready
    isServerReady = true
    ReDOCore.Info("Server initialization complete")
    ReDOCore.Info("Max players: %d", ReDOCore.MaxPlayers)

    return true
end

-- Check if server is ready
function ReDOCore.IsServerReady()
    return isServerReady
end

-- Get player count
function ReDOCore.GetPlayerCount()
    return ReDOCore.PlayerCount
end

-- Initialize on server start
CreateThread(function()
    ReDOCore.Init()
end)

-- Export the core object for other resources.
-- Two methods so older and newer code both work.
--
-- Other resources use:  local ReDOCore = exports['Core']:GetCoreObject()
-- The exports() function is the RELIABLE way to register exports in lua54 mode.
-- Just defining a global function with the right name can fail silently.
exports('getSharedObject', function()
    return ReDOCore
end)

exports('GetCoreObject', function()
    return ReDOCore
end)

ReDOCore.Info("Server main loaded")
