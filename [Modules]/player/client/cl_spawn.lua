--[[ =========================================================================
    FILE: client/cl_spawn.lua
    LOAD ORDER: First client file in player module
    RUNS ON: Client only

    PURPOSE:
    Handles spawning the player's ped (character model) in the world
    after they select a character. Also handles the camera during
    character selection and cleans up after spawn.

    FLOW:
    1. Player connects, session starts
    2. We freeze them and set up a nice camera
    3. Character select UI opens (handled by cl_charselect.lua)
    4. Player picks a character
    5. This file receives the character data
    6. We spawn their ped at the saved position
    7. Unfreeze, remove camera, they're playing
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()

-- Track whether the player has fully spawned in.
-- Other client scripts can check this before doing things.
local isSpawned = false
local spawnCamera = nil

--[[ =========================================================================
    FREEZE PLAYER
    
    Utility to freeze/unfreeze the player's ped.
    Used during character selection so they don't fall through the map
    or get attacked while choosing a character.
========================================================================= ]]

local function FreezePlayer(state)
    local ped = PlayerPedId()

    -- SetEntityVisible: hide/show the ped model.
    -- When hidden, they're invisible but still technically "there."
    SetEntityVisible(ped, not state)

    -- SetEntityInvincible: can't take damage while frozen.
    SetEntityInvincible(ped, state)

    -- FreezeEntityPosition: can't move.
    FreezeEntityPosition(ped, state)

    -- SetEntityCollision: disable physics so they don't bump into things.
    if state then
        SetEntityCollision(ped, false, false)
    else
        SetEntityCollision(ped, true, true)
    end
end

--[[ =========================================================================
    SPAWN PLAYER AT POSITION
    
    Takes the character's saved position and puts them there.
    
    Parameters:
    - charData: the character table from the server (has position, name, etc.)
========================================================================= ]]

function SpawnPlayerAtPosition(charData)
    local pos = charData.position

    -- Default to Valentine if position is missing.
    if not pos or not pos.x then
        local spawn = Config.Authorization.DefaultSpawn
        pos = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w or 0.0 }
    end

    -- Get the player's ped (the character model in the world).
    local ped = PlayerPedId()

    -- Move them to the saved position.
    -- The booleans at the end control axis clamping and area clearing.
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w or 0.0)

    -- Small wait for the world to load at the new position.
    Wait(500)

    -- Unfreeze — they can now move and interact.
    FreezePlayer(false)

    -- Destroy the selection camera if it exists.
    if spawnCamera then
        DestroyCam(spawnCamera, false)
        RenderScriptCams(false, true, 500, true, true)
        spawnCamera = nil
    end

    isSpawned = true

    ReDOCore.Info("Player spawned at %.2f, %.2f, %.2f", pos.x, pos.y, pos.z)

    -- Fire event so other client scripts know the player is in the world.
    TriggerEvent('redo:client:playerSpawned', charData)
end

--[[ =========================================================================
    SETUP SPAWN CAMERA
    
    Creates a cinematic camera for the character selection screen.
    Points at a scenic location so the background looks nice.
========================================================================= ]]

local function SetupSpawnCamera()
    -- Create a camera. "DEFAULT_SCRIPTED_CAMERA" is a standard type.
    spawnCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)

    -- Position the camera somewhere scenic.
    -- This is looking over Valentine. Adjust to wherever you want.
    SetCamCoord(spawnCamera, -1038.0, -2740.0, 15.0)
    SetCamRot(spawnCamera, -10.0, 0.0, 30.0, 2)

    -- Activate it. RenderScriptCams tells the game to use our camera
    -- instead of the normal player camera.
    SetCamActive(spawnCamera, true)
    RenderScriptCams(true, true, 1000, true, true)
end

--[[ =========================================================================
    INITIAL SETUP (runs once on connect)
    
    Waits for the network session to start, freezes the player,
    and triggers the character selection flow.
========================================================================= ]]

CreateThread(function()
    -- Wait for the network session to be ready.
    -- Without this, natives like PlayerPedId() might not work yet.
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    -- Wait for the player ped to exist.
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    ReDOCore.Info("Session started, setting up character selection...")

    -- Freeze the player so they don't fall or move during selection.
    FreezePlayer(true)

    -- Set up the cinematic camera.
    SetupSpawnCamera()

    -- Tell the character selection system to start.
    -- This event is handled in cl_charselect.lua.
    TriggerEvent('redo:client:openCharacterSelect')
end)

--[[ =========================================================================
    PUBLIC FUNCTIONS / EXPORTS
========================================================================= ]]

-- Check if the player has spawned in.
function ReDOCore.IsSpawned()
    return isSpawned
end

-- Get the active character data on the client.
-- This gets set when 'redo:client:characterSelected' fires.
local activeCharData = nil

RegisterNetEvent('redo:client:characterSelected')
AddEventHandler('redo:client:characterSelected', function(charData)
    activeCharData = charData

    -- Store on the shared object so other resources can access it.
    ReDOCore.PlayerData = {
        charId = charData.id,
        firstName = charData.first_name,
        lastName = charData.last_name,
        cash = charData.cash,
        bank = charData.bank,
        gold = charData.gold,
        job = {
            name = charData.job_name,
            label = charData.job_label,
            grade = charData.job_grade
        },
        position = charData.position,
        metadata = charData.metadata
    }
    ReDOCore.PlayerLoaded = true

    -- Now spawn them.
    SpawnPlayerAtPosition(charData)
end)

ReDOCore.Info("Spawn system loaded")
