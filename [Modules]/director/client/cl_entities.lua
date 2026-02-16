--[[ =========================================================================
    FILE: client/cl_entities.lua
    RUNS ON: Client only

    PURPOSE:
    Manages entities (peds and objects) for the Director.
    Handles spawning, despawning, animations, and movement.

    ENTITY DEFINITION (in scene JSON):
    {
        "id": "bartender",
        "type": "ped",
        "model": "a_m_m_saloonpatrons_01",
        "spawn": { "pos": [x,y,z], "heading": 180.0 },
        "keyframes": [
            { "time": 0, "type": "anim", "dict": "amb@world_human_bartender@male@base", "name": "base" },
            { "time": 5, "type": "move_to", "pos": [x,y,z], "speed": 1.0 },
            { "time": 8, "type": "anim", "dict": "...", "name": "..." }
        ]
    }
========================================================================= ]]

DirectorEntities = {}

-- Active spawned entities: { [entityId] = { handle = <game handle>, def = <definition> } }
local spawnedEntities = {}

--[[ =========================================================================
    MODEL LOADING
========================================================================= ]]

local function LoadModel(modelHash)
    if type(modelHash) == 'string' then
        modelHash = GetHashKey(modelHash)
    end

    if not IsModelInCdimage(modelHash) then
        return false
    end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasModelLoaded(modelHash)
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasAnimDictLoaded(dict)
end

--[[ =========================================================================
    SPAWN / DESPAWN
========================================================================= ]]

function DirectorEntities.SpawnPed(entityId, model, pos, heading)
    -- Despawn existing with same ID
    DirectorEntities.Despawn(entityId)

    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not LoadModel(hash) then
        print(string.format("^1[Director]^7 Failed to load model: %s", tostring(model)))
        return nil
    end

    local ped = CreatePed(hash, pos.x, pos.y, pos.z, heading or 0.0, false, false, false, false)

    if not ped or ped == 0 then
        print(string.format("^1[Director]^7 Failed to spawn ped: %s", tostring(model)))
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)

    spawnedEntities[entityId] = {
        handle = ped,
        type = "ped",
        model = model
    }

    SetModelAsNoLongerNeeded(hash)

    print(string.format("^2[Director]^7 Spawned ped '%s': %s at %.1f, %.1f, %.1f",
        entityId, tostring(model), pos.x, pos.y, pos.z))

    return ped
end

function DirectorEntities.SpawnObject(entityId, model, pos, rot)
    DirectorEntities.Despawn(entityId)

    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not LoadModel(hash) then
        print(string.format("^1[Director]^7 Failed to load object model: %s", tostring(model)))
        return nil
    end

    local obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)

    if not obj or obj == 0 then
        print(string.format("^1[Director]^7 Failed to spawn object: %s", tostring(model)))
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    FreezeEntityPosition(obj, true)

    if rot then
        SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, false)
    end

    spawnedEntities[entityId] = {
        handle = obj,
        type = "object",
        model = model
    }

    SetModelAsNoLongerNeeded(hash)
    return obj
end

function DirectorEntities.Despawn(entityId)
    local entity = spawnedEntities[entityId]
    if not entity then return end

    if DoesEntityExist(entity.handle) then
        DeleteEntity(entity.handle)
    end

    spawnedEntities[entityId] = nil
end

function DirectorEntities.DespawnAll()
    for id, _ in pairs(spawnedEntities) do
        DirectorEntities.Despawn(id)
    end
    spawnedEntities = {}
end

function DirectorEntities.GetHandle(entityId)
    local entity = spawnedEntities[entityId]
    return entity and entity.handle or nil
end

function DirectorEntities.GetAll()
    return spawnedEntities
end

--[[ =========================================================================
    ENTITY ACTIONS (called during playback)
========================================================================= ]]

function DirectorEntities.PlayAnim(entityId, animDict, animName, flags)
    local entity = spawnedEntities[entityId]
    if not entity or entity.type ~= "ped" then return end

    if LoadAnimDict(animDict) then
        TaskPlayAnim(entity.handle, animDict, animName,
            8.0, -8.0, -1,  -- blendIn, blendOut, duration (-1 = loop)
            flags or 1,       -- flag: 1 = loop
            0.0,              -- playback rate
            false, false, false)
    end
end

function DirectorEntities.StopAnim(entityId)
    local entity = spawnedEntities[entityId]
    if not entity or entity.type ~= "ped" then return end
    ClearPedTasks(entity.handle)
end

function DirectorEntities.MoveTo(entityId, targetPos, speed)
    local entity = spawnedEntities[entityId]
    if not entity or entity.type ~= "ped" then return end

    -- Unfreeze so they can walk
    FreezeEntityPosition(entity.handle, false)
    TaskGoToCoordAnyMeans(entity.handle,
        targetPos.x, targetPos.y, targetPos.z,
        speed or 1.0, 0, false, 786603, 0)
end

function DirectorEntities.SetPosition(entityId, pos, heading)
    local entity = spawnedEntities[entityId]
    if not entity then return end

    SetEntityCoords(entity.handle, pos.x, pos.y, pos.z, false, false, false, false)
    if heading then
        SetEntityHeading(entity.handle, heading)
    end
end

function DirectorEntities.Freeze(entityId, state)
    local entity = spawnedEntities[entityId]
    if not entity then return end
    FreezeEntityPosition(entity.handle, state)
end

print("^2[Director]^7 Entity system loaded")
