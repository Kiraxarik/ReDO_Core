--[[
    Framework Core - Client Main

    Handles client-side initialization and player data management
]]

-- Framework object is already created by shared/sh_main.lua
-- We just add client-specific properties

ReDOCore.PlayerLoaded = false
ReDOCore.PlayerData = {}

-- Wait for player to be active in session
Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
        Citizen.Wait(0)
    end

    ReDOCore.Debug("Network session started, waiting for player to spawn...")

    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(0)
    end

    ReDOCore.Info("Player is active, requesting player data from server...")

    -- Request player data from server
    ReDOCore.TriggerServerCallback('framework:server:getPlayerData', function(data)
        if data then
            ReDOCore.PlayerData = data
            ReDOCore.PlayerLoaded = true

            ReDOCore.Info("Player data loaded successfully")

            -- Trigger event that other resources can listen to
            TriggerEvent('framework:client:playerLoaded', data)
        else
            ReDOCore.Error("Failed to load player data from server")
        end
    end)
end)

-- Export the Framework object for other resources
exports('getSharedObject', function()
    return ReDOCore
end)

ReDOCore.Info("Client initialized")

Citizen.CreateThread(function()
    while not Framework.PlayerLoaded do
        Citizen.Wait(100)
    end

    Framework.Info("=== CLIENT TEST ===")
    Framework.Info("Player Loaded: %s", tostring(Framework.PlayerLoaded))
    Framework.Info("Player Data exists: %s", tostring(Framework.PlayerData ~= nil))

    -- Test callback system
    Framework.TriggerServerCallback('framework:server:test', function(response)
        Framework.Info("Callback response: %s", tostring(response))
    end)
end)
