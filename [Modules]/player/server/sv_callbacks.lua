--[[ =========================================================================
    FILE: server/sv_callbacks.lua
    LOAD ORDER: After sv_characters.lua
    RUNS ON: Server only

    PURPOSE:
    Two things happen in this file:
    
    1. We register the SERVER-SIDE CALLBACK HANDLER.
       Remember how Core/server/sv_callbacks.lua was empty?
       The client has code to SEND callbacks (cl_callbacks.lua), but
       nothing was RECEIVING them on the server. We fix that here.
    
    2. We register the SPECIFIC CALLBACKS for the player module:
       - getAccount: find or create the player's account
       - getCharacters: list all characters for an account
       - createCharacter: make a new character
       - selectCharacter: load a character and enter the world
       - deleteCharacter: remove a character

    HOW CALLBACKS WORK (the full round trip):
    
    CLIENT                              SERVER
    ──────                              ──────
    1. TriggerServerCallback(           
       'getCharacters', function(data)  
         -- use data                    
       end, accountId)                  
                                        
    2. ─── event: triggerCallback ────► 3. Find callback by name
                                        4. Run it, call cb(results)
    6. ◄── event: serverCallback ────── 5. cb() triggers client event
                                        
    7. Run the function from step 1     
       with the data from step 5        
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()
local Config = ReDOCore.Config
local DB = exports['database']:GetDB()
local MySQL = exports['database']:GetMySQL()

--[[ =========================================================================
    SERVER CALLBACK HANDLER
    
    This is the generic system. It listens for ANY callback request from
    any client, looks up the registered handler by name, and runs it.
    
    This fills the gap left by the empty Core/server/sv_callbacks.lua.
    We put it here in the player module because this module is the first
    thing that needs callbacks. Later, you could move this to Core.
========================================================================= ]]

-- Storage for registered server callbacks.
-- Key = callback name (string), Value = handler function
local registeredCallbacks = {}

-- PUBLIC FUNCTION: Register a new server callback.
-- Other resources can call this too via the export.
-- 
-- name: unique string identifier like 'redo:getCharacters'
-- handler: function(source, cb, ...) where:
--   source = the player who triggered it
--   cb = function to call with the response data
--   ... = any extra args the client sent
function PlayerModule.RegisterServerCallback(name, handler)
    if not name or not handler then
        ReDOCore.Error("RegisterServerCallback: name and handler required")
        return
    end

    registeredCallbacks[name] = handler
    ReDOCore.DebugFlag('Server_Callbacks', "Registered server callback: %s", name)
end

-- LISTENER: This catches every callback request from every client.
-- The client sends: event name, callback name, request ID, and any args.
-- We find the handler, run it, and send the result back with the same request ID
-- so the client knows which callback to resolve.
RegisterNetEvent('framework:server:triggerCallback')
AddEventHandler('framework:server:triggerCallback', function(name, requestId, ...)
    -- "source" inside an event handler = the player who sent the event.
    local src = source
    local args = {...}

    print(string.format("^3[SV CB DEBUG] Received callback: %s | requestId=%s | argCount=%d^7",
        tostring(name), tostring(requestId), #args))
    for i, v in ipairs(args) do
        print(string.format("^3[SV CB DEBUG]   arg[%d] type=%s value=%s^7", i, type(v), tostring(v)))
    end

    -- Look up the handler.
    local handler = registeredCallbacks[name]

    if not handler then
        ReDOCore.Error("No server callback registered for: %s (requested by player %d)", name, src)
        -- Send nil back so the client's callback doesn't hang forever.
        TriggerClientEvent('framework:client:serverCallback', src, requestId, nil)
        return
    end

    -- Run the handler.
    -- We pass a callback function (cb) that the handler calls with results.
    -- When cb is called, it sends the data back to the client.
    handler(src, function(...)
        TriggerClientEvent('framework:client:serverCallback', src, requestId, ...)
    end, ...)
end)

--[[ =========================================================================
    PLAYER MODULE CALLBACKS
    
    These are the specific callbacks the character selection screen uses.
========================================================================= ]]

-- GET ACCOUNT
-- Client calls this right after connecting.
-- Finds their account (or creates one), returns account data.
PlayerModule.RegisterServerCallback('redo:getAccount', function(src, cb)
    -- Get the pending player info that sv_auth.lua stored.
    local pending = PlayerModule.PendingPlayers[src]

    if not pending then
        -- Player somehow called this without going through auth.
        -- This can happen if the resource restarts while players are connected.
        -- Fall back to getting identifiers directly.
        local identifiers = {
            steam = GetPlayerIdentifierByType(src, 'steam'),
            license = GetPlayerIdentifierByType(src, 'license'),
            discord = GetPlayerIdentifierByType(src, 'discord')
        }

        PlayerModule.GetOrCreateAccount(GetPlayerName(src) or "Unknown", identifiers, function(account)
            cb(account)
        end)
        return
    end

    PlayerModule.GetOrCreateAccount(pending.name, pending.identifiers, function(account)
        -- Clean up pending data, we don't need it anymore.
        PlayerModule.PendingPlayers[src] = nil
        cb(account)
    end)
end)

-- GET CHARACTERS
-- Client calls this after getting their account.
-- Returns array of characters for the character selection screen.
PlayerModule.RegisterServerCallback('redo:getCharacters', function(src, cb, accountId)
    if not accountId then
        ReDOCore.Error("redo:getCharacters called without accountId by player %d", src)
        cb({})
        return
    end

    PlayerModule.GetCharacters(accountId, function(characters)
        cb(characters)
    end)
end)

-- CREATE CHARACTER
-- Client calls this from the "New Character" form.
-- Creates a character and returns it.
PlayerModule.RegisterServerCallback('redo:createCharacter', function(src, cb, accountId, firstName, lastName)
    if not accountId or not firstName or not lastName then
        ReDOCore.Error("redo:createCharacter missing parameters from player %d", src)
        cb(nil)
        return
    end

    -- Check if they've hit their character limit.
    PlayerModule.GetCharacters(accountId, function(existingChars)
        -- Get the account to check max_characters.
        DB.Table('accounts')
            :Where('id', accountId)
            :First(function(account)
                local maxChars = (account and account.max_characters) or 3

                if #existingChars >= maxChars then
                    ReDOCore.Warn("Player %d tried to create character but hit limit (%d/%d)",
                        src, #existingChars, maxChars)
                    cb(nil)
                    return
                end

                PlayerModule.CreateCharacter(accountId, firstName, lastName, function(newChar)
                    cb(newChar)
                end)
            end)
    end)
end)

-- SELECT CHARACTER
-- Client calls this when they click "Play" on a character.
-- Loads the character and puts them in the world.
PlayerModule.RegisterServerCallback('redo:selectCharacter', function(src, cb, characterId, accountId)
    if not characterId or not accountId then
        ReDOCore.Error("redo:selectCharacter missing parameters from player %d", src)
        cb(nil)
        return
    end

    PlayerModule.SelectCharacter(src, characterId, accountId, function(charData)
        cb(charData)
    end)
end)

-- DELETE CHARACTER
-- Client calls this from character select (with confirmation).
PlayerModule.RegisterServerCallback('redo:deleteCharacter', function(src, cb, characterId, accountId)
    if not characterId or not accountId then
        ReDOCore.Error("redo:deleteCharacter missing parameters from player %d", src)
        cb(false)
        return
    end

    -- Make sure they don't have this character currently loaded.
    local active = PlayerModule.ActiveCharacters[src]
    if active and active.id == characterId then
        ReDOCore.Warn("Player %d tried to delete their active character", src)
        cb(false)
        return
    end

    PlayerModule.DeleteCharacter(characterId, accountId, function(success)
        cb(success)
    end)
end)

ReDOCore.Info("Server callbacks registered")
