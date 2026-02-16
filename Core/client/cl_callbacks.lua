--[[
    Framework Core - Client Callbacks

    Handles client-side callback system for async server communication
]]

-- Storage for pending callbacks
local serverCallbacks = {}
local currentRequestId = 0

-- Trigger a callback on the server and wait for response
function ReDOCore.TriggerServerCallback(name, cb, ...)
    -- Debug: what are we actually receiving?
    print(string.format("^3[CB DEBUG] TriggerServerCallback called | name=%s | cb type=%s | cb value=%s | args=%d^7",
        tostring(name), type(cb), tostring(cb), select('#', ...)))
    
    -- Validate inputs
    if not name then
        ReDOCore.Error("TriggerServerCallback: name parameter is required")
        return
    end

    if not cb then
        ReDOCore.Error("TriggerServerCallback: callback must be a function (got nil)")
        return
    end

    -- Generate unique request ID
    currentRequestId = currentRequestId + 1
    local requestId = currentRequestId

    -- Store callback for when server responds
    serverCallbacks[requestId] = cb

    ReDOCore.Trace("Triggering server callback: %s (ID: %d)", name, requestId)

    -- Send request to server
    TriggerServerEvent('framework:server:triggerCallback', name, requestId, ...)
end

-- Handle callback response from server
RegisterNetEvent('framework:client:serverCallback')
AddEventHandler('framework:client:serverCallback', function(requestId, ...)
    if not requestId then
        ReDOCore.Error("Received server callback with no request ID")
        return
    end

    -- Find the callback for this request
    local callback = serverCallbacks[requestId]

    if callback then
        ReDOCore.Trace("Executing server callback response (ID: %d)", requestId)

        -- Execute callback with server's response
        callback(...)

        -- Clean up - remove callback from storage
        serverCallbacks[requestId] = nil
    else
        ReDOCore.Warn("Received server callback for unknown request ID: %d", requestId)
    end
end)

ReDOCore.Debug("Client callbacks initialized")
