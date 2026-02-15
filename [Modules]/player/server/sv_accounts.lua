--[[ =========================================================================
    FILE: server/sv_accounts.lua
    LOAD ORDER: After sv_auth.lua
    RUNS ON: Server only

    PURPOSE:
    Manages the "accounts" table. An account represents the REAL PERSON,
    not their character. This file handles:
    - Finding an existing account by Steam/License/Discord
    - Creating a new account for first-time players
    - Updating account data (last_seen, identifiers, etc.)

    RELATIONSHIP TO AUTH:
    After sv_auth.lua lets a player through, the client triggers a callback
    asking "give me my account." This file does the database lookup.
    If no account exists, it creates one.
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()
local Config = ReDOCore.Config

--[[ =========================================================================
    FIND ACCOUNT
    
    Looks up an account by any identifier. Tries steam first (primary),
    then falls back to license.
    
    Parameters:
    - identifiers: table from GetIdentifiers() in sv_auth.lua
    - callback: function(account) — returns account row or nil
========================================================================= ]]

function ReDOCore.FindAccount(identifiers, callback)
    if not identifiers then
        ReDOCore.Error("FindAccount: identifiers required")
        callback(nil)
        return
    end

    -- Try Steam first (it's our primary identifier).
    if identifiers.steam then
        ReDOCore.DB.Table('accounts')
            :Where('steam', identifiers.steam)
            :First(function(account)
                if account then
                    ReDOCore.DebugFlag('Player_Load', "Account found by Steam: %s (ID: %d)", identifiers.steam, account.id)
                    callback(account)
                    return
                end

                -- No account found by Steam. Try license as fallback.
                -- This handles the case where a player previously connected
                -- without Steam and now has it, or vice versa.
                if identifiers.license then
                    ReDOCore.DB.Table('accounts')
                        :Where('license', identifiers.license)
                        :First(function(accountByLicense)
                            if accountByLicense then
                                ReDOCore.DebugFlag('Player_Load', "Account found by License: %s (ID: %d)", identifiers.license, accountByLicense.id)

                                -- Update their Steam ID on the account since we have it now.
                                ReDOCore.DB.Table('accounts')
                                    :Where('id', accountByLicense.id)
                                    :Update({ steam = identifiers.steam }, function() end)
                            end
                            callback(accountByLicense)
                        end)
                else
                    callback(nil)
                end
            end)
    elseif identifiers.license then
        -- No Steam at all, search by license only.
        ReDOCore.DB.Table('accounts')
            :Where('license', identifiers.license)
            :First(function(account)
                callback(account)
            end)
    else
        callback(nil)
    end
end

--[[ =========================================================================
    CREATE ACCOUNT
    
    Makes a new account for a first-time player.
    Uses the identifiers collected during connection and the
    default values from Config.
    
    Parameters:
    - playerName: display name from FXServer
    - identifiers: table from GetIdentifiers()
    - callback: function(account) — returns the new account data or nil
========================================================================= ]]

function ReDOCore.CreateAccount(playerName, identifiers, callback)
    if not identifiers then
        ReDOCore.Error("CreateAccount: identifiers required")
        callback(nil)
        return
    end

    ReDOCore.Info("Creating new account for: %s", playerName)

    -- Build the row to insert.
    -- We store every identifier we have.
    -- NULL fields (like discord if they don't have it) are just omitted.
    local accountData = {
        steam = identifiers.steam,
        license = identifiers.license,
        discord = identifiers.discord,
        ['group'] = Config.Authorization.DefaultPlayerData.group,
        max_characters = 3
    }

    -- Insert into database.
    -- The callback gives us the insertId (the auto-incremented ID).
    ReDOCore.DB.Table('accounts')
        :Insert(accountData, function(insertId)
            if not insertId then
                ReDOCore.Error("Failed to create account for: %s", playerName)
                callback(nil)
                return
            end

            ReDOCore.Info("Account created with ID: %d for %s", insertId, playerName)

            -- Return a complete account object (matching what FindAccount returns).
            -- We build it manually because we just inserted it and know all the values.
            local newAccount = {
                id = insertId,
                steam = identifiers.steam,
                license = identifiers.license,
                discord = identifiers.discord,
                username = nil,
                password_hash = nil,
                ['group'] = Config.Authorization.DefaultPlayerData.group,
                max_characters = 3
            }

            callback(newAccount)
        end)
end

--[[ =========================================================================
    GET OR CREATE ACCOUNT
    
    Convenience function that combines Find + Create.
    This is what the callback handler actually calls:
    "Find the account, or make one if it doesn't exist."
========================================================================= ]]

function ReDOCore.GetOrCreateAccount(playerName, identifiers, callback)
    ReDOCore.FindAccount(identifiers, function(account)
        if account then
            -- Account exists. Update discord if we have it now and didn't before.
            if identifiers.discord and (not account.discord or account.discord == '') then
                ReDOCore.DB.Table('accounts')
                    :Where('id', account.id)
                    :Update({ discord = identifiers.discord }, function() end)
                account.discord = identifiers.discord
            end

            callback(account)
        else
            -- No account. Create one.
            ReDOCore.CreateAccount(playerName, identifiers, callback)
        end
    end)
end

ReDOCore.Info("Account system loaded")
