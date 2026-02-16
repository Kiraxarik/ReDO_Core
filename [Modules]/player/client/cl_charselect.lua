--[[ =========================================================================
    FILE: client/cl_charselect.lua
    LOAD ORDER: After cl_spawn.lua
    RUNS ON: Client only

    PURPOSE:
    Handles the character selection flow using pure Lua server callbacks.
    No NUI/HTML for now — we just auto-select or auto-create a character
    to get the player into the world. A proper UI can be added later.

    FLOW:
    1. cl_spawn.lua fires 'redo:client:openCharacterSelect'
    2. We get the account from the server
    3. We get the characters from the server
    4. If characters exist → select the first one
    5. If no characters → create a default one, then select it
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()

-- Store the account data on the client
local currentAccount = nil

--[[ =========================================================================
    OPEN CHARACTER SELECT

    Triggered by cl_spawn.lua after the session starts.
    Gets the account, gets characters, then auto-selects or creates.
========================================================================= ]]

RegisterNetEvent('redo:client:openCharacterSelect')
AddEventHandler('redo:client:openCharacterSelect', function()
    ReDOCore.Info("Starting character selection flow...")

    -- Step 1: Get (or create) the account.
    exports['Core']:TriggerServerCallback('redo:getAccount', function(account)
        if not account then
            ReDOCore.Error("Failed to get account from server!")
            return
        end

        currentAccount = account
        ReDOCore.Info("Account loaded: ID %d, Group: %s", account.id, account['group'] or 'user')

        -- Step 2: Get characters for this account.
        exports['Core']:TriggerServerCallback('redo:getCharacters', function(characters)
            local charCount = characters and #characters or 0
            ReDOCore.Info("Loaded %d character(s)", charCount)

            if charCount > 0 then
                -- Auto-select the first character (most recently played).
                local firstChar = characters[1]
                ReDOCore.Info("Auto-selecting character: %s %s (ID: %d)",
                    firstChar.first_name, firstChar.last_name, firstChar.id)

                exports['Core']:TriggerServerCallback('redo:selectCharacter', function(charData)
                    if charData then
                        ReDOCore.Info("Character selected successfully!")
                    else
                        ReDOCore.Error("Failed to select character!")
                    end
                end, firstChar.id, account.id)
            else
                -- No characters — create a default one.
                ReDOCore.Info("No characters found, creating default character...")

                exports['Core']:TriggerServerCallback('redo:createCharacter', function(newChar)
                    if newChar then
                        ReDOCore.Info("Default character created: %s %s (ID: %d)",
                            newChar.first_name, newChar.last_name, newChar.id)

                        -- Now select it.
                        exports['Core']:TriggerServerCallback('redo:selectCharacter', function(charData)
                            if charData then
                                ReDOCore.Info("Character selected successfully!")
                            else
                                ReDOCore.Error("Failed to select character!")
                            end
                        end, newChar.id, account.id)
                    else
                        ReDOCore.Error("Failed to create default character!")
                    end
                end, account.id, "John", "Marston")
            end
        end, account.id)
    end)
end)

ReDOCore.Info("Character select system loaded (no NUI)")
