--[[ =========================================================================
    FILE: server/sv_characters.lua
    LOAD ORDER: After sv_accounts.lua
    RUNS ON: Server only

    PURPOSE:
    Manages the "characters" table. Each account can have multiple characters.
    This file handles:
    - Getting all characters for an account
    - Creating a new character
    - Loading a specific character (when player selects one)
    - Saving character data (position, money, etc.)
    - Deleting a character

    ACTIVE CHARACTERS:
    ReDOCore.ActiveCharacters is a table keyed by server source ID.
    When a player selects a character, we store the full character data here.
    This is the "live" copy — it's what other resources read from when they
    need to know a player's money, position, job, etc.
    
    When the player disconnects, we save this back to the database.
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()
local Config = ReDOCore.Config

-- This holds the loaded character data for every connected player.
-- Key = player's server source ID (temporary, changes every reconnect)
-- Value = character data table (id, name, money, position, etc.)
ReDOCore.ActiveCharacters = {}

--[[ =========================================================================
    GET CHARACTERS FOR ACCOUNT
    
    Returns all characters belonging to an account.
    Used to populate the character selection screen.
    
    Parameters:
    - accountId: the account's database ID
    - callback: function(characters) — array of character rows
========================================================================= ]]

function ReDOCore.GetCharacters(accountId, callback)
    if not accountId then
        ReDOCore.Error("GetCharacters: accountId required")
        callback({})
        return
    end

    ReDOCore.DB.Table('characters')
        :Where('account_id', accountId)
        :OrderBy('last_played', 'DESC')  -- Most recently played first
        :Get(function(characters)
            -- Parse JSON fields for each character.
            -- The database stores position and metadata as JSON strings.
            -- We need to decode them back into Lua tables.
            for i, char in ipairs(characters or {}) do
                -- Parse position
                if char.position and char.position ~= '' then
                    local success, pos = pcall(json.decode, char.position)
                    if success and pos then
                        characters[i].position = pos
                    else
                        characters[i].position = nil
                    end
                end

                -- Parse metadata
                if char.metadata and char.metadata ~= '' then
                    local success, meta = pcall(json.decode, char.metadata)
                    if success and meta then
                        characters[i].metadata = meta
                    else
                        characters[i].metadata = {}
                    end
                else
                    characters[i].metadata = {}
                end
            end

            ReDOCore.DebugFlag('Player_Load', "Found %d character(s) for account %d", #(characters or {}), accountId)
            callback(characters or {})
        end)
end

--[[ =========================================================================
    CREATE CHARACTER
    
    Makes a new character for an account.
    Uses default values from Config for money, position, etc.
    
    Parameters:
    - accountId: which account owns this character
    - firstName: character's first name
    - lastName: character's last name
    - callback: function(character) — returns the new character data or nil
========================================================================= ]]

function ReDOCore.CreateCharacter(accountId, firstName, lastName, callback)
    if not accountId or not firstName or not lastName then
        ReDOCore.Error("CreateCharacter: accountId, firstName, lastName required")
        if callback then callback(nil) end
        return
    end

    -- Sanitize names — trim whitespace, basic length check.
    firstName = ReDOCore.String.Trim(firstName)
    lastName = ReDOCore.String.Trim(lastName)

    if not firstName or #firstName < 2 then
        ReDOCore.Warn("CreateCharacter: firstName too short")
        if callback then callback(nil) end
        return
    end

    if not lastName or #lastName < 2 then
        ReDOCore.Warn("CreateCharacter: lastName too short")
        if callback then callback(nil) end
        return
    end

    -- Get defaults from config.
    local defaults = Config.Authorization.DefaultPlayerData
    local spawn = Config.Authorization.DefaultSpawn

    -- Encode position as JSON for storage.
    local positionJson = json.encode({
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        w = spawn.w or 0.0
    })

    -- Build the row.
    local charData = {
        account_id = accountId,
        first_name = firstName,
        last_name = lastName,
        cash = defaults.money.cash,
        bank = defaults.money.bank,
        gold = defaults.money.gold,
        job_name = defaults.job.name,
        job_label = defaults.job.label,
        job_grade = defaults.job.grade,
        position = positionJson,
        metadata = json.encode({})
    }

    ReDOCore.DB.Table('characters')
        :Insert(charData, function(insertId)
            if not insertId then
                ReDOCore.Error("Failed to create character for account %d", accountId)
                if callback then callback(nil) end
                return
            end

            ReDOCore.Info("Character created: %s %s (ID: %d, Account: %d)",
                firstName, lastName, insertId, accountId)

            -- Build the full character object to return.
            -- This matches what GetCharacters would return.
            local newChar = {
                id = insertId,
                account_id = accountId,
                first_name = firstName,
                last_name = lastName,
                cash = defaults.money.cash,
                bank = defaults.money.bank,
                gold = defaults.money.gold,
                job_name = defaults.job.name,
                job_label = defaults.job.label,
                job_grade = defaults.job.grade,
                position = {
                    x = spawn.x,
                    y = spawn.y,
                    z = spawn.z,
                    w = spawn.w or 0.0
                },
                metadata = {}
            }

            if callback then callback(newChar) end
        end)
end

--[[ =========================================================================
    SELECT CHARACTER
    
    Called when a player picks a character from the selection screen.
    Loads the character data and marks it as "active" on the server.
    
    This is the bridge between "player connected" and "player is in the world."
    
    Parameters:
    - source: player's server ID
    - characterId: which character they selected
    - accountId: their account ID (for verification)
    - callback: function(character) — the loaded character or nil
========================================================================= ]]

function ReDOCore.SelectCharacter(src, characterId, accountId, callback)
    if not src or not characterId or not accountId then
        ReDOCore.Error("SelectCharacter: source, characterId, accountId required")
        if callback then callback(nil) end
        return
    end

    -- Fetch the character from the database.
    -- We verify account_id matches to prevent a player from loading
    -- someone else's character by guessing IDs.
    ReDOCore.DB.Table('characters')
        :Where('id', characterId)
        :Where('account_id', accountId)
        :First(function(char)
            if not char then
                ReDOCore.Error("Character %d not found for account %d", characterId, accountId)
                if callback then callback(nil) end
                return
            end

            -- Parse JSON fields.
            if char.position and char.position ~= '' then
                local success, pos = pcall(json.decode, char.position)
                if success and pos then
                    char.position = pos
                else
                    -- Fall back to default spawn if position is corrupted.
                    local spawn = Config.Authorization.DefaultSpawn
                    char.position = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w or 0.0 }
                end
            else
                local spawn = Config.Authorization.DefaultSpawn
                char.position = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w or 0.0 }
            end

            if char.metadata and char.metadata ~= '' then
                local success, meta = pcall(json.decode, char.metadata)
                char.metadata = (success and meta) or {}
            else
                char.metadata = {}
            end

            -- Store as the active character for this player.
            ReDOCore.ActiveCharacters[src] = char

            ReDOCore.Info("Player %s selected character: %s %s (ID: %d)",
                GetPlayerName(src) or src, char.first_name, char.last_name, char.id)

            -- Update player count.
            ReDOCore.PlayerCount = ReDOCore.PlayerCount + 1

            -- Fire an event that other resources can listen to.
            -- This is how other scripts know "a player is now fully loaded."
            -- Example: an inventory resource would listen for this and load their items.
            TriggerEvent('redo:server:characterSelected', src, char)
            TriggerClientEvent('redo:client:characterSelected', src, char)

            if callback then callback(char) end
        end)
end

--[[ =========================================================================
    SAVE CHARACTER
    
    Writes the current character data back to the database.
    Called on disconnect, and can be called periodically for auto-save.
    
    Parameters:
    - charData: the character table from ReDOCore.ActiveCharacters[source]
========================================================================= ]]

function ReDOCore.SaveCharacter(charData)
    if not charData or not charData.id then
        ReDOCore.Error("SaveCharacter: valid character data required")
        return
    end

    ReDOCore.DebugFlag('Player_Save', "Saving character: %s %s (ID: %d)",
        charData.first_name, charData.last_name, charData.id)

    -- Encode position and metadata back to JSON for storage.
    local positionJson = nil
    if charData.position then
        positionJson = json.encode({
            x = charData.position.x,
            y = charData.position.y,
            z = charData.position.z,
            w = charData.position.w or 0.0
        })
    end

    local metadataJson = json.encode(charData.metadata or {})

    -- Build update data.
    local updateData = {
        first_name = charData.first_name,
        last_name = charData.last_name,
        cash = charData.cash,
        bank = charData.bank,
        gold = charData.gold,
        job_name = charData.job_name,
        job_label = charData.job_label,
        job_grade = charData.job_grade,
        position = positionJson,
        metadata = metadataJson
    }

    ReDOCore.DB.Table('characters')
        :Where('id', charData.id)
        :Update(updateData, function(affected)
            if affected and affected > 0 then
                ReDOCore.DebugFlag('Player_Save', "Character saved: %d", charData.id)
            else
                ReDOCore.Warn("Failed to save character: %d", charData.id)
            end
        end)
end

--[[ =========================================================================
    DELETE CHARACTER
    
    Permanently removes a character. This is destructive!
    
    Parameters:
    - characterId: the character to delete
    - accountId: for verification (must own the character)
    - callback: function(success)
========================================================================= ]]

function ReDOCore.DeleteCharacter(characterId, accountId, callback)
    if not characterId or not accountId then
        ReDOCore.Error("DeleteCharacter: characterId and accountId required")
        if callback then callback(false) end
        return
    end

    -- Verify ownership before deleting.
    ReDOCore.DB.Table('characters')
        :Where('id', characterId)
        :Where('account_id', accountId)
        :First(function(char)
            if not char then
                ReDOCore.Warn("Delete attempt on character %d by account %d — not found or not owned", characterId, accountId)
                if callback then callback(false) end
                return
            end

            ReDOCore.DB.Table('characters')
                :Where('id', characterId)
                :Delete(function(affected)
                    if affected and affected > 0 then
                        ReDOCore.Info("Character deleted: %s %s (ID: %d)", char.first_name, char.last_name, characterId)
                        if callback then callback(true) end
                    else
                        ReDOCore.Error("Failed to delete character %d", characterId)
                        if callback then callback(false) end
                    end
                end)
        end)
end

--[[ =========================================================================
    AUTO-SAVE
    
    Periodically saves all active characters to the database.
    This protects against data loss if the server crashes.
    Default interval: every 5 minutes.
========================================================================= ]]

CreateThread(function()
    local saveInterval = 5 * 60 * 1000  -- 5 minutes in milliseconds

    while true do
        Wait(saveInterval)

        local count = 0
        for src, charData in pairs(ReDOCore.ActiveCharacters) do
            -- Get current position before saving.
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

            ReDOCore.SaveCharacter(charData)
            count = count + 1
        end

        if count > 0 then
            ReDOCore.DebugFlag('Player_Save', "Auto-saved %d character(s)", count)
        end
    end
end)

ReDOCore.Info("Character system loaded")
