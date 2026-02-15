--[[ =========================================================================
    FILE: client/cl_charselect.lua
    LOAD ORDER: After cl_spawn.lua
    RUNS ON: Client only

    PURPOSE:
    Manages the character selection UI. This file is the bridge between
    the HTML/CSS/JS character selection screen (NUI) and the server.

    NUI COMMUNICATION:
    FiveM/RedM uses a system called "NUI" (New UI) to show HTML pages
    in-game. Communication works in two directions:

    LUA → HTML:  SendNUIMessage({ action = "show", data = ... })
    HTML → LUA:  RegisterNUICallback('buttonClicked', function(data, cb) ... end)

    The HTML sends messages using fetch('https://cfx-nui-RESOURCENAME/callbackName')
    and Lua catches them with RegisterNUICallback.

    FLOW:
    1. cl_spawn.lua fires 'redo:client:openCharacterSelect'
    2. We get the account from the server
    3. We get the characters from the server
    4. We send both to the NUI (HTML)
    5. Player interacts with the UI
    6. NUI sends back actions (select, create, delete)
    7. We handle each action and talk to the server
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()

-- Store the account data on the client so we can send accountId with requests.
local currentAccount = nil

--[[ =========================================================================
    OPEN CHARACTER SELECT
    
    Triggered by cl_spawn.lua after the session starts.
    Gets the account, gets characters, then shows the UI.
========================================================================= ]]

RegisterNetEvent('redo:client:openCharacterSelect')
AddEventHandler('redo:client:openCharacterSelect', function()
    ReDOCore.Info("Opening character selection...")

    -- Step 1: Get (or create) the account.
    ReDOCore.TriggerServerCallback('redo:getAccount', function(account)
        if not account then
            ReDOCore.Error("Failed to get account from server!")
            return
        end

        currentAccount = account
        ReDOCore.Info("Account loaded: ID %d, Group: %s", account.id, account['group'] or 'user')

        -- Step 2: Get characters for this account.
        ReDOCore.TriggerServerCallback('redo:getCharacters', function(characters)
            ReDOCore.Info("Loaded %d character(s)", #characters)

            -- Step 3: Show the NUI with the character data.
            -- SetNuiFocus(hasFocus, hasCursor):
            --   hasFocus = true means the NUI can receive keyboard input
            --   hasCursor = true means the mouse cursor is visible
            -- Both need to be true for the player to interact with the UI.
            SetNuiFocus(true, true)

            -- Send character data to the HTML page.
            -- The HTML's JavaScript listens for this message.
            SendNUIMessage({
                action = "showCharacterSelect",
                characters = characters,
                maxCharacters = account.max_characters or 3
            })
        end, account.id)
    end)
end)

--[[ =========================================================================
    NUI CALLBACKS
    
    These are registered handlers that the HTML/JS can call.
    When the player clicks a button in the UI, JavaScript sends a
    request to one of these callbacks.
========================================================================= ]]

-- SELECT CHARACTER
-- Player clicked "Play" on a character.
RegisterNUICallback('selectCharacter', function(data, cb)
    if not data.id or not currentAccount then
        cb({ ok = false, message = "Invalid request" })
        return
    end

    ReDOCore.Info("Selecting character ID: %d", data.id)

    ReDOCore.TriggerServerCallback('redo:selectCharacter', function(charData)
        if charData then
            -- Close the NUI.
            -- SetNuiFocus(false, false) hides the cursor and gives
            -- control back to the game.
            SetNuiFocus(false, false)
            SendNUIMessage({ action = "hide" })

            -- Tell the callback in JS that it worked.
            cb({ ok = true })

            -- Note: the actual spawning happens in cl_spawn.lua
            -- which listens for 'redo:client:characterSelected'.
            -- The server already triggered that event in SelectCharacter().
        else
            cb({ ok = false, message = "Failed to load character" })
        end
    end, data.id, currentAccount.id)
end)

-- CREATE CHARACTER
-- Player filled out the new character form and clicked "Create".
RegisterNUICallback('createCharacter', function(data, cb)
    if not data.firstName or not data.lastName or not currentAccount then
        cb({ ok = false, message = "Name is required" })
        return
    end

    ReDOCore.Info("Creating character: %s %s", data.firstName, data.lastName)

    ReDOCore.TriggerServerCallback('redo:createCharacter', function(newChar)
        if newChar then
            -- Refresh the character list in the UI.
            ReDOCore.TriggerServerCallback('redo:getCharacters', function(characters)
                SendNUIMessage({
                    action = "updateCharacters",
                    characters = characters
                })
                cb({ ok = true, character = newChar })
            end, currentAccount.id)
        else
            cb({ ok = false, message = "Failed to create character. You may have reached the limit." })
        end
    end, currentAccount.id, data.firstName, data.lastName)
end)

-- DELETE CHARACTER
-- Player confirmed they want to delete a character.
RegisterNUICallback('deleteCharacter', function(data, cb)
    if not data.id or not currentAccount then
        cb({ ok = false, message = "Invalid request" })
        return
    end

    ReDOCore.Info("Deleting character ID: %d", data.id)

    ReDOCore.TriggerServerCallback('redo:deleteCharacter', function(success)
        if success then
            -- Refresh the character list.
            ReDOCore.TriggerServerCallback('redo:getCharacters', function(characters)
                SendNUIMessage({
                    action = "updateCharacters",
                    characters = characters
                })
                cb({ ok = true })
            end, currentAccount.id)
        else
            cb({ ok = false, message = "Failed to delete character" })
        end
    end, data.id, currentAccount.id)
end)

-- CLOSE UI
-- Player pressed Escape or a close button.
RegisterNUICallback('closeUI', function(data, cb)
    -- Only allow closing if they have an active character.
    -- On first connect, they MUST pick a character.
    if ReDOCore.PlayerLoaded then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hide" })
        cb({ ok = true })
    else
        -- Can't close without selecting a character.
        cb({ ok = false, message = "You must select a character" })
    end
end)

ReDOCore.Info("Character select UI system loaded")
