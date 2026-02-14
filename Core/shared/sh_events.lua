function ReDOCore.RegisterEvent(eventName, callback)
    if not eventName or not callback then
        ReDOCore.Error("RegisterEvent: eventName and callback required")
        return
    end

    if type(callback) ~= 'function' then
        ReDOCore.Error("RegisterEvent: callback must be a function")
        return
    end

    RegisterNetEvent(eventName)
    AddEventHandler(eventName, callback)
    ReDOCore.Debug("Registered event: %s", eventName)
end

function ReDOCore.TriggerServerEvent(eventName, ...)
    if not eventName then
        ReDOCore.Error("TriggerServerEvent: eventName required")
        return
    end

    TriggerServerEvent(eventName, ...)
    ReDOCore.Trace("Triggered server event: %s", eventName)
end

function ReDOCore.TriggerClientEvent(eventName, playerId, ...)
    if not eventName or not playerId then
        ReDOCore.Error("TriggerClientEvent: eventName and playerId required")
        return
    end

    TriggerClientEvent(eventName, playerId, ...)
    ReDOCore.Trace("Triggered client event: %s for player %s", eventName, playerId)
end

print("^2[ReDOCore]^7 Event helpers loaded")
