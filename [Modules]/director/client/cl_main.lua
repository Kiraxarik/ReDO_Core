--[[ =========================================================================
    FILE: client/cl_main.lua
    RUNS ON: Client only

    PURPOSE:
    Entry point for the Director module on the client.
    Provides commands and exports for opening the editor and
    playing scenes from other resources.

    USAGE FROM OTHER RESOURCES:
        -- Play a scene
        exports['director']:PlayScene('charselect_intro', function()
            print("Scene finished!")
        end)

        -- Stop playback
        exports['director']:StopScene()

        -- Open editor (admin only)
        exports['director']:OpenEditor()
========================================================================= ]]

--[[ =========================================================================
    COMMANDS
========================================================================= ]]

-- Open the editor: /director
RegisterCommand('director', function()
    if DirectorEditor.IsOpen() then
        DirectorEditor.Close()
    else
        DirectorEditor.Open()
    end
end, false)

-- Play a scene by name: /playscene <name>
RegisterCommand('playscene', function(source, args)
    local sceneName = args[1]
    if not sceneName then
        print("^3Usage: /playscene <scene_name>^7")
        return
    end

    -- Request scene from server, play it when received
    TriggerServerEvent('director:requestSceneForPlayback', sceneName)
end, false)

-- Stop current playback
RegisterCommand('stopscene', function()
    DirectorPlayback.Stop()
end, false)

--[[ =========================================================================
    SERVER → CLIENT EVENTS
========================================================================= ]]

-- Receive a scene for playback (not editing)
RegisterNetEvent('director:playScene')
AddEventHandler('director:playScene', function(scene)
    if scene then
        DirectorPlayback.Play(scene)
    end
end)

--[[ =========================================================================
    EXPORTS
========================================================================= ]]

-- Play a scene from another resource
exports('PlayScene', function(sceneName, onComplete)
    -- Store callback for when playback completes
    -- We can't pass functions through events, so we handle it locally
    TriggerServerEvent('director:requestSceneForPlayback', sceneName)

    -- TODO: hook onComplete via a local event
    if onComplete then
        local handler
        handler = AddEventHandler('director:playbackComplete', function()
            RemoveEventHandler(handler)
            onComplete()
        end)
    end
end)

exports('StopScene', function()
    DirectorPlayback.Stop()
end)

exports('OpenEditor', function(scene)
    DirectorEditor.Open(scene)
end)

exports('CloseEditor', function()
    DirectorEditor.Close()
end)

exports('IsEditorOpen', function()
    return DirectorEditor.IsOpen()
end)

exports('IsPlaying', function()
    return DirectorPlayback.IsPlaying()
end)

print("^2[Director]^7 Module initialized. Use /director to open editor.")
