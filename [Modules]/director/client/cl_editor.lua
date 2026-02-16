--[[ =========================================================================
    FILE: client/cl_editor.lua
    RUNS ON: Client only

    PURPOSE:
    Bridge between the NUI editor interface and the Lua camera/entity
    systems. Handles:
    - Opening/closing the editor
    - NUI callback registration (editor buttons → Lua actions)
    - Sending scene state to NUI
    - Free cam control during editing
========================================================================= ]]

DirectorEditor = {}

local isEditorOpen = false

-- The scene being edited (working copy)
local editScene = nil

--[[ =========================================================================
    OPEN / CLOSE
========================================================================= ]]

function DirectorEditor.Open(scene)
    if isEditorOpen then return end

    -- Initialize an empty scene if none provided
    editScene = scene or {
        name = "untitled",
        duration = 30.0,
        camera = {
            keyframes = {}
        },
        entities = {},
        events = {}
    }

    isEditorOpen = true

    -- Tell camera system we're in editor mode
    DirectorCamera.SetEditorOpen(true)

    -- Start free cam (controlled via middle mouse)
    DirectorCamera.StartFreeCam()

    -- Show NUI with full cursor focus.
    -- Middle mouse down/up callbacks toggle between cursor and camera control.
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openEditor",
        scene = editScene
    })

    print("^2[Director]^7 Editor opened")
end

function DirectorEditor.Close()
    if not isEditorOpen then return end

    isEditorOpen = false

    -- Tell camera system editor is closed
    DirectorCamera.SetEditorOpen(false)

    -- Stop any active systems
    DirectorCamera.StopFreeCam()
    DirectorPlayback.Stop()
    DirectorEntities.DespawnAll()

    -- Hide NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeEditor" })

    print("^2[Director]^7 Editor closed")
end

function DirectorEditor.IsOpen()
    return isEditorOpen
end

function DirectorEditor.GetScene()
    return editScene
end

--[[ =========================================================================
    NUI CALLBACKS — EDITOR CONTROLS
========================================================================= ]]

-- Close editor
RegisterNUICallback('director:close', function(data, cb)
    DirectorEditor.Close()
    cb({ ok = true })
end)

-- Add camera keyframe at current free cam position
RegisterNUICallback('director:addCameraKeyframe', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local camState = DirectorCamera.GetFreeCamState()
    local time = tonumber(data.time) or 0.0

    local keyframe = {
        time = time,
        pos = { x = camState.pos.x, y = camState.pos.y, z = camState.pos.z },
        rot = { x = camState.rot.x, y = camState.rot.y, z = camState.rot.z },
        fov = camState.fov,
        easing = data.easing or "linear"
    }

    table.insert(editScene.camera.keyframes, keyframe)

    -- Sort by time
    table.sort(editScene.camera.keyframes, function(a, b) return a.time < b.time end)

    -- Send updated scene to NUI
    SendNUIMessage({
        action = "sceneUpdated",
        scene = editScene
    })

    print(string.format("^2[Director]^7 Camera keyframe added at t=%.1fs pos=(%.1f, %.1f, %.1f)",
        time, camState.pos.x, camState.pos.y, camState.pos.z))

    cb({ ok = true, keyframe = keyframe })
end)

-- Update an existing camera keyframe
RegisterNUICallback('director:updateCameraKeyframe', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local index = tonumber(data.index)
    if not index or not editScene.camera.keyframes[index] then
        cb({ ok = false, message = "Invalid keyframe index" })
        return
    end

    local kf = editScene.camera.keyframes[index]

    -- Update with provided fields (or current cam if "fromCamera" is true)
    if data.fromCamera then
        local camState = DirectorCamera.GetFreeCamState()
        kf.pos = { x = camState.pos.x, y = camState.pos.y, z = camState.pos.z }
        kf.rot = { x = camState.rot.x, y = camState.rot.y, z = camState.rot.z }
        kf.fov = camState.fov
    end

    if data.time then kf.time = tonumber(data.time) end
    if data.easing then kf.easing = data.easing end
    if data.fov then kf.fov = tonumber(data.fov) end

    -- Re-sort
    table.sort(editScene.camera.keyframes, function(a, b) return a.time < b.time end)

    SendNUIMessage({ action = "sceneUpdated", scene = editScene })
    cb({ ok = true })
end)

-- Delete a camera keyframe
RegisterNUICallback('director:deleteCameraKeyframe', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local index = tonumber(data.index)
    if index and editScene.camera.keyframes[index] then
        table.remove(editScene.camera.keyframes, index)
        SendNUIMessage({ action = "sceneUpdated", scene = editScene })
        cb({ ok = true })
    else
        cb({ ok = false, message = "Invalid index" })
    end
end)

-- Go to a camera keyframe position (snap free cam there)
RegisterNUICallback('director:gotoCameraKeyframe', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local index = tonumber(data.index)
    local kf = editScene.camera.keyframes[index]
    if not kf then cb({ ok = false }) return end

    -- Restart free cam at this position
    DirectorCamera.StopFreeCam()
    Wait(100)
    local pos = vector3(kf.pos.x, kf.pos.y, kf.pos.z)
    local rot = vector3(kf.rot.x, kf.rot.y, kf.rot.z)
    DirectorCamera.StartFreeCam(pos, rot, kf.fov)

    cb({ ok = true })
end)

--[[ =========================================================================
    NUI CALLBACKS — ENTITY MANAGEMENT
========================================================================= ]]

-- Add entity to scene
RegisterNUICallback('director:addEntity', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local id = data.id
    local entityType = data.type or "ped"
    local model = data.model

    if not id or not model then
        cb({ ok = false, message = "id and model required" })
        return
    end

    -- Get spawn position from free cam (spawn in front of camera)
    local camState = DirectorCamera.GetFreeCamState()
    local radZ = math.rad(camState.rot.z)
    local spawnPos = vector3(
        camState.pos.x - math.sin(radZ) * 5.0,
        camState.pos.y + math.cos(radZ) * 5.0,
        camState.pos.z - 2.0
    )

    local entity = {
        id = id,
        type = entityType,
        model = model,
        spawn = {
            pos = { x = spawnPos.x, y = spawnPos.y, z = spawnPos.z },
            heading = camState.rot.z + 180.0
        },
        keyframes = {}
    }

    -- Spawn it in the world
    if entityType == "ped" then
        DirectorEntities.SpawnPed(id, model, spawnPos, entity.spawn.heading)
    else
        DirectorEntities.SpawnObject(id, model, spawnPos)
    end

    table.insert(editScene.entities, entity)

    SendNUIMessage({ action = "sceneUpdated", scene = editScene })
    cb({ ok = true, entity = entity })
end)

-- Remove entity from scene
RegisterNUICallback('director:removeEntity', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local id = data.id
    if not id then cb({ ok = false }) return end

    -- Remove from world
    DirectorEntities.Despawn(id)

    -- Remove from scene
    for i, ent in ipairs(editScene.entities) do
        if ent.id == id then
            table.remove(editScene.entities, i)
            break
        end
    end

    SendNUIMessage({ action = "sceneUpdated", scene = editScene })
    cb({ ok = true })
end)

-- Add keyframe to an entity
RegisterNUICallback('director:addEntityKeyframe', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    local entityId = data.entityId
    local time = tonumber(data.time) or 0.0
    local action = data.action or "anim"

    -- Find entity in scene
    local targetEntity = nil
    for _, ent in ipairs(editScene.entities) do
        if ent.id == entityId then
            targetEntity = ent
            break
        end
    end

    if not targetEntity then
        cb({ ok = false, message = "Entity not found" })
        return
    end

    local kf = {
        time = time,
        action = action
    }

    -- Copy action-specific fields
    if action == "anim" then
        kf.dict = data.dict or ""
        kf.name = data.name or ""
        kf.flags = tonumber(data.flags) or 1
    elseif action == "move_to" then
        -- Use current entity position or cam position
        local camState = DirectorCamera.GetFreeCamState()
        local radZ = math.rad(camState.rot.z)
        kf.pos = data.pos or {
            x = camState.pos.x - math.sin(radZ) * 3.0,
            y = camState.pos.y + math.cos(radZ) * 3.0,
            z = camState.pos.z - 2.0
        }
        kf.speed = tonumber(data.speed) or 1.0
    elseif action == "teleport" then
        kf.pos = data.pos
        kf.heading = tonumber(data.heading) or 0
    end

    table.insert(targetEntity.keyframes, kf)
    table.sort(targetEntity.keyframes, function(a, b) return a.time < b.time end)

    SendNUIMessage({ action = "sceneUpdated", scene = editScene })
    cb({ ok = true })
end)

--[[ =========================================================================
    NUI CALLBACKS — SCENE MANAGEMENT
========================================================================= ]]

-- Update scene properties (name, duration)
RegisterNUICallback('director:updateScene', function(data, cb)
    if not isEditorOpen then cb({ ok = false }) return end

    if data.name then editScene.name = data.name end
    if data.duration then editScene.duration = tonumber(data.duration) end

    cb({ ok = true })
end)

-- Get current scene data
RegisterNUICallback('director:getScene', function(data, cb)
    cb({ ok = true, scene = editScene })
end)

-- Save scene to server (file)
RegisterNUICallback('director:saveScene', function(data, cb)
    if not editScene then cb({ ok = false }) return end

    -- The server handles file I/O
    TriggerServerEvent('director:saveScene', editScene)
    cb({ ok = true })
end)

-- Load scene from server
RegisterNUICallback('director:loadScene', function(data, cb)
    local sceneName = data.name
    if not sceneName then cb({ ok = false }) return end

    -- Request from server
    TriggerServerEvent('director:requestScene', sceneName)
    cb({ ok = true })
end)

-- List available scenes
RegisterNUICallback('director:listScenes', function(data, cb)
    TriggerServerEvent('director:listScenes')
    cb({ ok = true })
end)

-- Server responds with scene data
RegisterNetEvent('director:receiveScene')
AddEventHandler('director:receiveScene', function(scene)
    if scene then
        editScene = scene
        SendNUIMessage({ action = "sceneLoaded", scene = editScene })
    end
end)

-- Server responds with scene list
RegisterNetEvent('director:receiveSceneList')
AddEventHandler('director:receiveSceneList', function(scenes)
    SendNUIMessage({ action = "sceneList", scenes = scenes })
end)

-- Server confirms save
RegisterNetEvent('director:sceneSaved')
AddEventHandler('director:sceneSaved', function(success, name)
    SendNUIMessage({
        action = "sceneSaved",
        success = success,
        name = name
    })
end)

--[[ =========================================================================
    NUI CALLBACKS — PLAYBACK CONTROLS
========================================================================= ]]

-- Preview / playback the scene
RegisterNUICallback('director:preview', function(data, cb)
    if not editScene then cb({ ok = false }) return end

    -- Stop free cam, start playback
    DirectorCamera.StopFreeCam()

    -- Release NUI focus so we can see the scene
    SetNuiFocus(true, false) -- cursor visible but no keyboard capture

    DirectorPlayback.Play(editScene, function()
        -- When done, re-enter editor
        if isEditorOpen then
            DirectorPlayback.Stop()
            DirectorCamera.StartFreeCam()
            SetNuiFocus(true, true)
            SendNUIMessage({ action = "previewEnded" })
        end
    end)

    cb({ ok = true })
end)

-- Stop preview
RegisterNUICallback('director:stopPreview', function(data, cb)
    DirectorPlayback.Stop()

    if isEditorOpen then
        DirectorCamera.StartFreeCam()
        SetNuiFocus(true, true)
    end

    cb({ ok = true })
end)

-- Pause/resume
RegisterNUICallback('director:togglePause', function(data, cb)
    local paused = DirectorPlayback.TogglePause()
    cb({ ok = true, paused = paused })
end)

--[[ =========================================================================
    NUI CALLBACKS — FREE CAM CONTROL FROM NUI
========================================================================= ]]

-- Camera focus is now handled by middleMouseDown/Up callbacks in cl_camera.lua
-- No manual toggle needed — hold middle mouse to control camera.

-- Get current camera position (for NUI display)
RegisterNUICallback('director:getCamState', function(data, cb)
    local state = DirectorCamera.GetFreeCamState()
    cb({
        ok = true,
        pos = { x = state.pos.x, y = state.pos.y, z = state.pos.z },
        rot = { x = state.rot.x, y = state.rot.y, z = state.rot.z },
        fov = state.fov
    })
end)

print("^2[Director]^7 Editor bridge loaded")
