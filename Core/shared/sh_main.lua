ReDOCore = {}
ReDOCore.Players = {}
ReDOCore.PlayerData = {}

ReDOCore.Config = Config

ReDOCore.ServerCallbacks = {}
ReDOCore.ClientCallbacks = {}

ReDOCore.TimeoutCount = -1
ReDOCore.CancelledTimeouts = {}

function ReDOCore.IsPlayerLoaded()
    return ReDOCore.PlayerData ~= nil and next(ReDOCore.PlayerData) ~= nil
end

function ReDOCore.GetPlayerData()
    return ReDOCore.PlayerData
end

function ReDOCore.SetPlayerData(key, val)
    if not key or type(key) ~= 'string' then
        return
    end
    ReDOCore.PlayerData[key] = val
end

function ReDOCore.ShowNotification(msg, type, length)
    print(msg)
end

if IsDuplicityVersion() then
    print("^2[ReDOCore]^7 Shared object initialized on ^3SERVER^7")
else
    print("^2[ReDOCore]^7 Shared object initialized on ^3CLIENT^7")
end
