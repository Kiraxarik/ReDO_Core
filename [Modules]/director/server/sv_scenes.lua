--[[ =========================================================================
    FILE: server/sv_scenes.lua
    RUNS ON: Server only

    PURPOSE:
    Handles saving and loading scene JSON files.
    Scenes are stored in the director/scenes/ folder.

    FILE FORMAT:
    Each scene is a .json file named after the scene:
        scenes/charselect_intro.json
        scenes/mission_01_opening.json
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()

-- Path to scenes folder (relative to resource root)
local SCENES_PATH = "scenes/"

--[[ =========================================================================
    FILE I/O HELPERS

    FXServer provides SaveResourceFile / LoadResourceFile for
    reading/writing files within a resource's folder.
========================================================================= ]]

local function GetSceneFilePath(name)
    -- Sanitize the name: only allow alphanumeric, underscore, dash
    local clean = name:gsub("[^%w_%-]", "")
    if clean == "" then clean = "untitled" end
    return SCENES_PATH .. clean .. ".json"
end

local function SaveSceneFile(name, sceneData)
    local filePath = GetSceneFilePath(name)
    local jsonStr = json.encode(sceneData)

    if not jsonStr then
        ReDOCore.Error("Failed to encode scene to JSON: %s", name)
        return false
    end

    local success = SaveResourceFile(GetCurrentResourceName(), filePath, jsonStr, #jsonStr)

    if success then
        ReDOCore.Info("Scene saved: %s (%d bytes)", filePath, #jsonStr)
        return true
    else
        ReDOCore.Error("Failed to save scene file: %s", filePath)
        return false
    end
end

local function LoadSceneFile(name)
    local filePath = GetSceneFilePath(name)
    local jsonStr = LoadResourceFile(GetCurrentResourceName(), filePath)

    if not jsonStr or jsonStr == "" then
        ReDOCore.Warn("Scene file not found: %s", filePath)
        return nil
    end

    local success, sceneData = pcall(json.decode, jsonStr)
    if not success or not sceneData then
        ReDOCore.Error("Failed to parse scene JSON: %s", filePath)
        return nil
    end

    ReDOCore.Info("Scene loaded: %s", filePath)
    return sceneData
end

local function ListSceneFiles()
    -- FXServer doesn't have a directory listing API,
    -- so we maintain a manifest file listing all scenes.
    local manifest = LoadResourceFile(GetCurrentResourceName(), SCENES_PATH .. "_manifest.json")

    if manifest and manifest ~= "" then
        local success, list = pcall(json.decode, manifest)
        if success and list then
            return list
        end
    end

    return {}
end

local function UpdateManifest(sceneName)
    local list = ListSceneFiles()

    -- Add if not already present
    local found = false
    for _, name in ipairs(list) do
        if name == sceneName then
            found = true
            break
        end
    end

    if not found then
        table.insert(list, sceneName)
        local jsonStr = json.encode(list)
        SaveResourceFile(GetCurrentResourceName(), SCENES_PATH .. "_manifest.json", jsonStr, #jsonStr)
    end
end

--[[ =========================================================================
    EVENT HANDLERS
========================================================================= ]]

-- Save a scene (from editor)
RegisterNetEvent('director:saveScene')
AddEventHandler('director:saveScene', function(sceneData)
    local src = source

    if not DirectorServer_IsAllowed(src) then
        ReDOCore.Warn("Player %d tried to save a scene without permission", src)
        return
    end

    if not sceneData or not sceneData.name then
        TriggerClientEvent('director:sceneSaved', src, false, nil)
        return
    end

    local success = SaveSceneFile(sceneData.name, sceneData)

    if success then
        UpdateManifest(sceneData.name)
    end

    TriggerClientEvent('director:sceneSaved', src, success, sceneData.name)
end)

-- Load a scene (for editor)
RegisterNetEvent('director:requestScene')
AddEventHandler('director:requestScene', function(sceneName)
    local src = source
    local scene = LoadSceneFile(sceneName)
    TriggerClientEvent('director:receiveScene', src, scene)
end)

-- Load a scene (for playback)
RegisterNetEvent('director:requestSceneForPlayback')
AddEventHandler('director:requestSceneForPlayback', function(sceneName)
    local src = source
    local scene = LoadSceneFile(sceneName)
    if scene then
        TriggerClientEvent('director:playScene', src, scene)
    else
        ReDOCore.Warn("Scene '%s' not found for playback (requested by player %d)", sceneName, src)
    end
end)

-- List all scenes
RegisterNetEvent('director:listScenes')
AddEventHandler('director:listScenes', function()
    local src = source
    local scenes = ListSceneFiles()
    TriggerClientEvent('director:receiveSceneList', src, scenes)
end)

ReDOCore.Info("Scene file I/O loaded (scenes stored in director/scenes/)")
