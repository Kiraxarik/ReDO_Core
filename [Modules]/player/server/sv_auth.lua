--[[ =========================================================================
    FILE: server/sv_auth.lua
    LOAD ORDER: First server file in player module
    RUNS ON: Server only

    PURPOSE:
    This file handles what happens the MOMENT a player tries to connect.
    FXServer fires the "playerConnecting" event before the player is fully
    in the server. We use "deferrals" to hold them at the loading screen
    while we check bans, whitelist, etc.

    FLOW:
    1. Player clicks "connect" in their server browser
    2. FXServer fires "playerConnecting"
    3. We grab their identifiers (steam, license, discord, etc.)
    4. We show "Checking..." on their loading screen via deferrals
    5. We check: are they banned?
    6. We check: is whitelist on? Are they whitelisted?
    7. If all good: deferrals.done() — lets them through
    8. If not: deferrals.done("reason") — kicks them with a message

    DEFERRALS:
    A deferral is FXServer's way of saying "hold on, don't let them in yet."
    While a deferral is active, the player sees a loading screen.
    You can update the message they see with deferrals.update("text").
    When you're done checking, call deferrals.done() to let them in,
    or deferrals.done("reason") to kick them.
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()
local Config = ReDOCore.Config

-- Get DB/MySQL from the database resource (not from Core).
-- With lua54, each resource has its own Lua state, so cross-resource
-- table mutations don't propagate. We get these directly.
local DB = exports['database']:GetDB()
local MySQL = exports['database']:GetMySQL()

--[[ =========================================================================
    IDENTIFIER EXTRACTION
    
    Every player who connects has "identifiers" — strings that identify
    who they are. FXServer provides these automatically. Examples:
    
        steam:110000112345678
        license:abcdef1234567890abcdef1234567890abcdef12
        discord:123456789012345678
        xbl:2535412345678901
        ip:192.168.1.1
    
    GetPlayerIdentifiers(source) returns ALL of them as a table.
    GetPlayerIdentifierByType(source, "steam") returns just one.
    
    We extract them into a clean table so the rest of the code
    doesn't have to keep calling these natives.
========================================================================= ]]

-- Pull all identifiers for a player into a clean table.
-- "source" in FXServer is the player's server ID (a temporary number
-- assigned when they connect, like a session ID).
local function GetIdentifiers(source)
    local identifiers = {
        steam = nil,
        license = nil,
        discord = nil,
        xbl = nil,
        ip = nil
    }

    -- GetNumPlayerIdentifiers returns how many identifiers this player has.
    -- We loop through them and sort them by type.
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)

        -- string.find returns the position of a match, or nil if not found.
        -- We check what each identifier starts with to categorize it.
        if string.find(id, "steam:") then
            identifiers.steam = id
        elseif string.find(id, "license:") then
            identifiers.license = id
        elseif string.find(id, "discord:") then
            identifiers.discord = id
        elseif string.find(id, "xbl:") then
            identifiers.xbl = id
        elseif string.find(id, "ip:") then
            identifiers.ip = id
        end
    end

    return identifiers
end

--[[ =========================================================================
    BAN CHECK
    
    Queries the bans table to see if ANY of this player's identifiers
    match an active ban. We check ALL identifiers because:
    - A player could be banned by Steam ID
    - They might try connecting with a different Steam account
    - But their license or IP might still match a ban
    
    The query uses OR conditions: if ANY identifier matches, they're banned.
========================================================================= ]]

local function CheckBan(identifiers, callback)
    -- Build a list of all non-nil identifiers to check against.
    local idsToCheck = {}
    if identifiers.steam then table.insert(idsToCheck, identifiers.steam) end
    if identifiers.license then table.insert(idsToCheck, identifiers.license) end
    if identifiers.discord then table.insert(idsToCheck, identifiers.discord) end
    if identifiers.ip then table.insert(idsToCheck, identifiers.ip) end

    -- If somehow they have NO identifiers, they're not banned (but they'll
    -- fail other checks anyway).
    if #idsToCheck == 0 then
        callback(false, nil)
        return
    end

    -- Build the SQL query dynamically.
    -- We need: WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())
    --          AND identifier IN ('steam:xxx', 'license:xxx', ...)
    --
    -- "active = 1" means the ban hasn't been manually lifted.
    -- "expires_at IS NULL" means permanent bans (no expiry date).
    -- "expires_at > NOW()" means temp bans that haven't expired yet.
    -- "identifier IN (...)" checks against all the player's identifiers.
    
    -- Build the IN clause with placeholders.
    -- One "?" per identifier. MySQL will safely substitute the values.
    -- This prevents SQL injection (where someone puts malicious SQL in their name).
    local placeholders = {}
    for i = 1, #idsToCheck do
        table.insert(placeholders, "?")
    end

    local query = string.format(
        "SELECT * FROM `bans` WHERE `active` = 1 AND (`expires_at` IS NULL OR `expires_at` > NOW()) AND `identifier` IN (%s) LIMIT 1",
        table.concat(placeholders, ", ")
    )

    MySQL.FetchOne(query, idsToCheck, function(ban)
        if ban then
            -- Found an active ban. Return the ban info.
            callback(true, ban)
        else
            -- No active ban found.
            callback(false, nil)
        end
    end)
end

--[[ =========================================================================
    WHITELIST CHECK
    
    If Config.Authorization.UseWhitelist is true, only players who
    already have an account in the database can join.
    
    SuperAdmins in the config always bypass the whitelist.
========================================================================= ]]

local function CheckWhitelist(identifiers, callback)
    -- If whitelist is disabled, everyone passes.
    if not Config.Authorization.UseWhitelist then
        callback(true)
        return
    end

    -- Check if they're a SuperAdmin (always whitelisted).
    -- We check their license against the SuperAdmins list in config.
    for _, adminLicense in ipairs(Config.Authorization.SuperAdmins) do
        if identifiers.license == adminLicense or identifiers.steam == adminLicense then
            ReDOCore.DebugFlag('Player_Auth', "SuperAdmin bypass: %s", identifiers.steam or identifiers.license)
            callback(true)
            return
        end
    end

    -- Check if an account exists for this player.
    -- If they have an account, they're whitelisted.
    -- Steam is the primary identifier, so we check that first.
    local primaryId = identifiers.steam or identifiers.license

    if not primaryId then
        callback(false)
        return
    end

    -- Determine which column to search by
    local column = identifiers.steam and "steam" or "license"

    DB.Table('accounts')
        :Where(column, primaryId)
        :First(function(account)
            callback(account ~= nil)
        end)
end

--[[ =========================================================================
    PLAYER CONNECTING EVENT
    
    This is the main entry point. FXServer calls this every time
    someone tries to join the server.
    
    Parameters:
    - name: the player's display name
    - setKickReason: function to set why they were kicked (legacy, use deferrals)
    - deferrals: the deferral object for controlling their loading screen
    
    "source" is a special variable in FXServer event handlers.
    It's the server ID of the player who triggered the event.
    We capture it immediately because it can change in async callbacks.
========================================================================= ]]

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    -- Capture source immediately. Inside callbacks (async functions),
    -- "source" might point to a different player. So we save it now.
    local src = source

    -- Start the deferral — player sees "Connecting..." on their screen.
    deferrals.defer()

    -- Small wait to let the deferral system initialize.
    -- Without this, the first update() call sometimes gets lost.
    Wait(0)

    deferrals.update(string.format("Hello %s! Checking your credentials...", name))

    -- Step 1: Get all identifiers
    local identifiers = GetIdentifiers(src)

    ReDOCore.DebugFlag('Player_Auth', "Player connecting: %s | Steam: %s | License: %s",
        name,
        identifiers.steam or "NONE",
        identifiers.license or "NONE"
    )

    -- Step 2: Check if they have Steam (required by default).
    -- If they don't have Steam linked, we reject them.
    -- Later when custom auth is built, this would check if they
    -- have an alternative auth method instead.
    if not identifiers.steam and not identifiers.license then
        deferrals.done(Config.Authorization.Messages.NoLicense)
        return
    end

    if not identifiers.steam then
        -- No Steam found. For now, require it.
        -- When custom auth is implemented, this is where you'd
        -- show the login/register UI instead of rejecting.
        deferrals.done("Steam is required to connect. Please launch Steam and restart your game.")
        return
    end

    -- Step 3: Check bans.
    deferrals.update("Checking ban status...")

    CheckBan(identifiers, function(isBanned, banInfo)
        if isBanned then
            -- Format the ban message with details.
            local banMsg = string.format(
                "You are banned from this server.\nReason: %s\nBanned by: %s",
                banInfo.reason or "No reason provided",
                banInfo.banned_by or "SYSTEM"
            )

            -- If it's a temp ban, show when it expires.
            if banInfo.expires_at then
                banMsg = banMsg .. string.format("\nExpires: %s", banInfo.expires_at)
            else
                banMsg = banMsg .. "\nThis ban is permanent."
            end

            ReDOCore.Info("Banned player rejected: %s (%s)", name, identifiers.steam)
            deferrals.done(banMsg)
            return
        end

        -- Step 4: Check whitelist.
        deferrals.update("Checking whitelist...")

        CheckWhitelist(identifiers, function(isWhitelisted)
            if not isWhitelisted then
                ReDOCore.Info("Non-whitelisted player rejected: %s", name)
                deferrals.done(Config.Authorization.Messages.NotWhitelisted)
                return
            end

            -- Step 5: All checks passed. Let them in.
            deferrals.update("Welcome to the server!")

            ReDOCore.Info("Player authorized: %s (%s)", name, identifiers.steam)

            -- Store identifiers so other files can access them.
            -- PlayerModule is our resource-local shared table (defined in sv_shared.lua).
            -- We use this instead of ReDOCore because ReDOCore is a cross-resource proxy
            -- and mutations on it don't propagate to other files with lua54.
            PlayerModule.PendingPlayers[src] = {
                name = name,
                identifiers = identifiers
            }

            -- Let them through.
            deferrals.done()
        end)
    end)
end)

--[[ =========================================================================
    PLAYER DROPPED EVENT
    
    Fires when a player disconnects (quit, crash, kicked, etc).
    We use this to:
    1. Save their character data (position, money, etc.)
    2. Clean up server-side references
    3. Update player count
========================================================================= ]]

AddEventHandler('playerDropped', function(reason)
    local src = source

    ReDOCore.Info("Player dropped: %s (reason: %s)", GetPlayerName(src) or "Unknown", reason)

    -- Save character data if they had one loaded.
    if PlayerModule.ActiveCharacters[src] then
        local charData = PlayerModule.ActiveCharacters[src]

        -- Get their current position to save it.
        local ped = GetPlayerPed(src)
        if ped and ped > 0 then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            charData.position = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                w = heading
            }
        end

        -- Save to database (function defined in sv_characters.lua).
        if PlayerModule.SaveCharacter then
            PlayerModule.SaveCharacter(charData)
        end

        -- Clean up
        PlayerModule.ActiveCharacters[src] = nil
    end

    -- Clean up pending player data
    PlayerModule.PendingPlayers[src] = nil

    -- Update player count
    PlayerModule.PlayerCount = math.max(0, PlayerModule.PlayerCount - 1)
end)

ReDOCore.Info("Auth system loaded")
