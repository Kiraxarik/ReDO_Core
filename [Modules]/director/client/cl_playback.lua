--[[ =========================================================================
    FILE: client/cl_playback.lua
    RUNS ON: Client only

    PURPOSE:
    Scene playback engine. Takes a scene definition (loaded from JSON),
    spawns all entities, starts the camera, and drives the timeline.

    SCENE FORMAT (Lua table, decoded from JSON):
    {
        name = "scene_name",
        duration = 30.0,
        camera = {
            keyframes = {
                { time=0, pos=vec3(...), rot=vec3(...), fov=50, easing="linear" },
                { time=10, pos=vec3(...), rot=vec3(...), fov=45, easing="ease-in-out" },
            }
        },
        entities = {
            {
                id = "bartender",
                type = "ped",
                model = "a_m_m_saloonpatrons_01",
                spawn = { pos = vec3(...), heading = 180 },
                keyframes = {
                    { time=0, action="anim", dict="...", name="..." },
                    { time=5, action="move_to", pos=vec3(...), speed=1.0 },
                }
            }
        },
        events = {
            { time=2.0, name="scene:custom_event", data={} }
        }
    }
========================================================================= ]]

DirectorPlayback = {}

local isPlaying = false
local isPaused = false
local currentScene = nil
local playbackTime = 0.0
local playbackSpeed = 1.0

-- Track which entity keyframes have been triggered
-- (so we don't re-trigger every frame)
local triggeredKeyframes = {}

--[[ =========================================================================
    SCENE DATA CONVERSION

    JSON stores positions as arrays [x,y,z]. We need vec3.
    This converts everything after JSON decode.
========================================================================= ]]

local function ToVec3(t)
    if not t then return nil end
    if type(t) == 'vector3' then return t end
    if type(t) == 'table' then
        return vector3(t.x or t[1] or 0, t.y or t[2] or 0, t.z or t[3] or 0)
    end
    return nil
end

local function PrepareScene(scene)
    -- Convert camera keyframes
    if scene.camera and scene.camera.keyframes then
        for i, kf in ipairs(scene.camera.keyframes) do
            kf.pos = ToVec3(kf.pos)
            kf.rot = ToVec3(kf.rot)
            kf.fov = kf.fov or 50.0
            kf.easing = kf.easing or "linear"
        end
    end

    -- Convert entity data
    if scene.entities then
        for _, ent in ipairs(scene.entities) do
            if ent.spawn then
                ent.spawn.pos = ToVec3(ent.spawn.pos)
            end
            if ent.keyframes then
                for _, kf in ipairs(ent.keyframes) do
                    if kf.pos then
                        kf.pos = ToVec3(kf.pos)
                    end
                end
            end
        end
    end

    return scene
end

--[[ =========================================================================
    PLAY / STOP / PAUSE
========================================================================= ]]

function DirectorPlayback.Play(scene, onComplete)
    if isPlaying then
        DirectorPlayback.Stop()
    end

    -- Prepare the scene data
    currentScene = PrepareScene(scene)
    playbackTime = 0.0
    triggeredKeyframes = {}

    -- Spawn all entities
    if currentScene.entities then
        for _, ent in ipairs(currentScene.entities) do
            if ent.type == "ped" and ent.spawn then
                DirectorEntities.SpawnPed(ent.id, ent.model, ent.spawn.pos, ent.spawn.heading)
            elseif ent.type == "object" and ent.spawn then
                DirectorEntities.SpawnObject(ent.id, ent.model, ent.spawn.pos, ent.spawn.rot and ToVec3(ent.spawn.rot))
            end
        end
    end

    -- Start camera playback
    DirectorCamera.StartPlayback()

    isPlaying = true
    isPaused = false

    print(string.format("^2[Director]^7 Playing scene: %s (%.1fs)", currentScene.name or "untitled", currentScene.duration or 0))

    -- Playback loop
    CreateThread(function()
        while isPlaying do
            Wait(0)

            if not isPaused then
                local dt = GetFrameTime() * playbackSpeed
                playbackTime = playbackTime + dt

                -- Update camera
                if currentScene.camera and currentScene.camera.keyframes then
                    DirectorCamera.UpdatePlayback(currentScene.camera.keyframes, playbackTime)
                end

                -- Process entity keyframes
                if currentScene.entities then
                    for _, ent in ipairs(currentScene.entities) do
                        if ent.keyframes then
                            for kfIdx, kf in ipairs(ent.keyframes) do
                                local kfKey = ent.id .. "_" .. kfIdx
                                if playbackTime >= kf.time and not triggeredKeyframes[kfKey] then
                                    triggeredKeyframes[kfKey] = true
                                    DirectorPlayback.ExecuteEntityKeyframe(ent.id, kf)
                                end
                            end
                        end
                    end
                end

                -- Process events
                if currentScene.events then
                    for evIdx, ev in ipairs(currentScene.events) do
                        local evKey = "event_" .. evIdx
                        if playbackTime >= ev.time and not triggeredKeyframes[evKey] then
                            triggeredKeyframes[evKey] = true
                            TriggerEvent(ev.name, ev.data or {})
                        end
                    end
                end

                -- Notify NUI of time update (for timeline scrubber)
                SendNUIMessage({
                    action = "playbackTimeUpdate",
                    time = playbackTime,
                    duration = currentScene.duration or 0
                })

                -- Check if scene is done
                if currentScene.duration and playbackTime >= currentScene.duration then
                    DirectorPlayback.Stop()
                    if onComplete then
                        onComplete()
                    end
                end
            end
        end
    end)
end

function DirectorPlayback.Stop()
    if not isPlaying then return end

    isPlaying = false
    isPaused = false

    -- Cleanup entities
    DirectorEntities.DespawnAll()

    -- Stop camera
    DirectorCamera.StopPlayback()

    currentScene = nil
    playbackTime = 0.0
    triggeredKeyframes = {}

    print("^2[Director]^7 Playback stopped")
end

function DirectorPlayback.Pause()
    isPaused = true
end

function DirectorPlayback.Resume()
    isPaused = false
end

function DirectorPlayback.TogglePause()
    isPaused = not isPaused
    return isPaused
end

function DirectorPlayback.SetSpeed(speed)
    playbackSpeed = math.max(0.1, math.min(10.0, speed))
end

function DirectorPlayback.Seek(time)
    -- Reset triggered keyframes that are after the new time
    for key, _ in pairs(triggeredKeyframes) do
        -- Simple approach: reset all on seek
    end
    triggeredKeyframes = {}
    playbackTime = math.max(0, time)
end

function DirectorPlayback.IsPlaying()
    return isPlaying
end

function DirectorPlayback.IsPaused()
    return isPaused
end

function DirectorPlayback.GetTime()
    return playbackTime
end

function DirectorPlayback.GetScene()
    return currentScene
end

--[[ =========================================================================
    ENTITY KEYFRAME EXECUTION
========================================================================= ]]

function DirectorPlayback.ExecuteEntityKeyframe(entityId, kf)
    local action = kf.action or kf.type

    if action == "anim" then
        DirectorEntities.PlayAnim(entityId, kf.dict, kf.name, kf.flags)

    elseif action == "stop_anim" then
        DirectorEntities.StopAnim(entityId)

    elseif action == "move_to" then
        DirectorEntities.MoveTo(entityId, kf.pos, kf.speed)

    elseif action == "teleport" then
        DirectorEntities.SetPosition(entityId, kf.pos, kf.heading)

    elseif action == "freeze" then
        DirectorEntities.Freeze(entityId, kf.state ~= false)

    elseif action == "unfreeze" then
        DirectorEntities.Freeze(entityId, false)

    elseif action == "delete" then
        DirectorEntities.Despawn(entityId)

    else
        print(string.format("^3[Director]^7 Unknown keyframe action: %s for entity %s", tostring(action), entityId))
    end
end

print("^2[Director]^7 Playback engine loaded")
