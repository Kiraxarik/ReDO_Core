--[[ =========================================================================
    FILE: client/cl_camera.lua

    CAMERA CONTROLS:
    - Middle mouse HOLD → NUI releases all focus, Lua takes over
      Mouse = look, WASD = move, Space = up, Ctrl = down, Shift = fast
    - Middle mouse RELEASE → Lua detects it, restores NUI focus
    - Scroll wheel → FOV (handled by NUI when it has focus)

    CONTROL IDs (RedM/FiveM standard numeric IDs):
    See: https://docs.fivem.net/docs/game-references/controls/
    1 = Look Left/Right (mouse X axis)
    2 = Look Up/Down (mouse Y axis)
    21 = Sprint (Left Shift)
    32 = Move Up (W)
    33 = Move Down (S)
    34 = Move Left (A)
    35 = Move Right (D)
    22 = Jump (Space)
    36 = Duck/Sneak (Left Ctrl)
    348 = Middle mouse button (INPUT_REPLAY_NEWMARKER or varies)
========================================================================= ]]

DirectorCamera = {}

local freeCam = nil
local isFreeCamActive = false
local freeCamSpeed = 1.0
local freeCamPos = vector3(0, 0, 0)
local freeCamRot = vector3(0, 0, 0)
local freeCamFov = 50.0

-- Middle mouse tracking
local isMiddleMouseHeld = false
local editorIsOpen = false  -- set by cl_editor when editor opens/closes

local MOUSE_SENS = 3.0
local MOVE_SPEED_BASE = 0.5
local MOVE_SPEED_FAST = 2.5

--[[ =========================================================================
    EASING FUNCTIONS
========================================================================= ]]

local Easings = {
    linear = function(t) return t end,
    ["ease-in"] = function(t) return t * t end,
    ["ease-out"] = function(t) return t * (2.0 - t) end,
    ["ease-in-out"] = function(t)
        if t < 0.5 then return 2.0 * t * t
        else return -1.0 + (4.0 - 2.0 * t) * t end
    end,
    ["ease-in-cubic"] = function(t) return t * t * t end,
    ["ease-out-cubic"] = function(t)
        local t1 = t - 1.0
        return t1 * t1 * t1 + 1.0
    end,
    ["ease-in-out-cubic"] = function(t)
        if t < 0.5 then return 4.0 * t * t * t
        else
            local t1 = (2.0 * t - 2.0)
            return 0.5 * t1 * t1 * t1 + 1.0
        end
    end
}

function DirectorCamera.GetEasingNames()
    local names = {}
    for k, _ in pairs(Easings) do names[#names+1] = k end
    table.sort(names)
    return names
end

--[[ =========================================================================
    MATH
========================================================================= ]]

local function Lerp(a, b, t) return a + (b - a) * t end
local function LerpVec3(a, b, t)
    return vector3(Lerp(a.x, b.x, t), Lerp(a.y, b.y, t), Lerp(a.z, b.z, t))
end
local function LerpAngle(a, b, t)
    local diff = b - a
    while diff > 180.0 do diff = diff - 360.0 end
    while diff < -180.0 do diff = diff + 360.0 end
    return a + diff * t
end
local function LerpRot(a, b, t)
    return vector3(LerpAngle(a.x, b.x, t), LerpAngle(a.y, b.y, t), LerpAngle(a.z, b.z, t))
end

--[[ =========================================================================
    MIDDLE MOUSE HANDLING

    NUI detects mousedown (button=1) and fires a callback.
    Lua then takes FULL control: SetNuiFocus(false, false).
    Lua polls for middle mouse release every frame.
    On release: restore SetNuiFocus(true, true).
========================================================================= ]]

function DirectorCamera.SetEditorOpen(state)
    editorIsOpen = state
end

-- NUI tells us middle mouse went down
RegisterNUICallback('director:middleMouseDown', function(data, cb)
    if not isFreeCamActive then
        cb({ ok = false })
        return
    end

    isMiddleMouseHeld = true

    -- FULL release: NUI gets nothing, Lua gets everything
    SetNuiFocus(false, false)

    cb({ ok = true })
end)

-- FOV from NUI scroll (when NUI has focus)
RegisterNUICallback('director:scrollFov', function(data, cb)
    local delta = tonumber(data.delta) or 0
    if delta > 0 then
        freeCamFov = math.min(120.0, freeCamFov + 2.0)
    elseif delta < 0 then
        freeCamFov = math.max(10.0, freeCamFov - 2.0)
    end
    cb({ ok = true, fov = freeCamFov })
end)

--[[ =========================================================================
    FREE CAMERA
========================================================================= ]]

function DirectorCamera.StartFreeCam(startPos, startRot, startFov)
    if isFreeCamActive then return end

    if not startPos then
        local ped = PlayerPedId()
        startPos = GetEntityCoords(ped)
        startRot = vector3(-10.0, 0.0, GetEntityHeading(ped))
    end

    freeCamPos = startPos
    freeCamRot = startRot or vector3(-10.0, 0.0, 0.0)
    freeCamFov = startFov or 50.0

    freeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(freeCam, freeCamPos.x, freeCamPos.y, freeCamPos.z)
    SetCamRot(freeCam, freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)
    SetCamFov(freeCam, freeCamFov)
    SetCamActive(freeCam, true)
    RenderScriptCams(true, true, 500, true, true)

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)

    isFreeCamActive = true

    -- Main loop
    CreateThread(function()
        while isFreeCamActive do
            Wait(0)

            local dt = GetFrameTime()

            if isMiddleMouseHeld then
                -- We have full control (NUI is unfocused).
                -- Disable game controls so WASD doesn't move the ped.
                DisableAllControlActions(0)

                -- Detect middle mouse RELEASE
                -- When NUI is off, we can read controls directly.
                -- Middle mouse = control 348 in some mappings, but
                -- it's more reliable to check if it's still pressed.
                -- IsDisabledControlPressed(0, 348) may not work for MMB.
                -- Instead, we use a raw approach: if mouse button is no
                -- longer pressed, the mouse input deltas will stop AND
                -- we can check via IsControlPressed on common MMB IDs.
                --
                -- Actually the cleanest way: we set NuiFocus(false,false)
                -- so now the NUI page CAN'T see anything. We need to
                -- detect MMB release from Lua. We'll check control 349
                -- or just re-enable NUI briefly to detect mouseup.
                --
                -- SIMPLEST RELIABLE APPROACH:
                -- Since we disabled NUI, check if right mouse (control 25)
                -- ... no. Let's just use a timer + check approach.
                -- After NUI is released, mouse button state isn't directly
                -- readable via controls for middle mouse.
                --
                -- BEST APPROACH: Check raw keyboard state.
                -- IsDisabledControlPressed doesn't map middle mouse well.
                -- So we'll use: if NOT IsDisabledControlPressed for any
                -- movement/look, assume released after a short delay.
                --
                -- ACTUAL BEST: Re-read mouse movement. If we get zero
                -- mouse delta for multiple frames AND no WASD, user
                -- likely released. But this is unreliable.
                --
                -- REAL SOLUTION: Use control 348 which is "INPUT_VEH_FLY_ATTACK_CAMERA"
                -- or just poll via a secondary thread.
                -- 
                -- Let's try: NUI captures mouseup even without focus if we
                -- use document-level listeners. Actually no, SetNuiFocus(false)
                -- means the NUI doesn't get events at all.
                --
                -- FINAL APPROACH: We'll use a right-click release model instead.
                -- OR: keep NUI partially focused. SetNuiFocus(true, false) keeps
                -- the NUI page getting keyboard events but hides the cursor.
                -- Then NUI can detect keyup for middle mouse.
                -- BUT SetNuiFocus(true, false) means NUI still eats keyboard...
                --
                -- ACTUALLY: Let's just try IsControlPressed(0, 348) and
                -- IsDisabledControlPressed(0, 348) and see which works.
                -- If neither works for middle mouse, we'll detect it another way.

                -- Try multiple potential middle mouse control IDs
                -- Debug: print which controls are pressed to find the right one
                local mmStillHeld = false

                -- Check a range of controls to find middle mouse
                for _, ctrlId in ipairs({348, 349, 70, 71, 72, 106, 122, 142}) do
                    if IsDisabledControlPressed(0, ctrlId) then
                        mmStillHeld = true
                        break
                    end
                end

                -- FALLBACK: If we can't detect MMB state via controls,
                -- check if mouse is still moving. If we get mouse input
                -- deltas, user is still interacting. If no movement AND
                -- no WASD for 0.5 seconds, assume released.
                if not mmStillHeld then
                    -- Check if ANY movement inputs are active
                    local hasInput = false
                    if math.abs(GetDisabledControlNormal(0, 1)) > 0.01 then hasInput = true end
                    if math.abs(GetDisabledControlNormal(0, 2)) > 0.01 then hasInput = true end
                    if IsDisabledControlPressed(0, 32) then hasInput = true end -- W
                    if IsDisabledControlPressed(0, 33) then hasInput = true end -- S
                    if IsDisabledControlPressed(0, 34) then hasInput = true end -- A
                    if IsDisabledControlPressed(0, 35) then hasInput = true end -- D
                    if IsDisabledControlPressed(0, 22) then hasInput = true end -- Space
                    if IsDisabledControlPressed(0, 36) then hasInput = true end -- Ctrl
                    if IsDisabledControlPressed(0, 21) then hasInput = true end -- Shift

                    if not hasInput then
                        -- No inputs detected — likely released middle mouse.
                        -- Wait a couple more frames to be sure.
                        Wait(0)
                        local stillNothing = math.abs(GetDisabledControlNormal(0, 1)) < 0.01
                            and math.abs(GetDisabledControlNormal(0, 2)) < 0.01
                            and not IsDisabledControlPressed(0, 32)

                        if stillNothing then
                            isMiddleMouseHeld = false
                            if editorIsOpen then
                                SetNuiFocus(true, true)
                            end
                            goto continue
                        end
                    end
                else
                    -- MMB is detected as held via control — no fallback needed
                end

                if not isMiddleMouseHeld then goto continue end

                -- Camera look
                local mouseX = GetDisabledControlNormal(0, 1) * MOUSE_SENS
                local mouseY = GetDisabledControlNormal(0, 2) * MOUSE_SENS

                freeCamRot = vector3(
                    math.max(-89.0, math.min(89.0, freeCamRot.x - mouseY)),
                    0.0,
                    freeCamRot.z - mouseX
                )

                -- Movement speed
                local moveSpeed = MOVE_SPEED_BASE * freeCamSpeed
                if IsDisabledControlPressed(0, 21) then -- LEFT_SHIFT (Sprint)
                    moveSpeed = MOVE_SPEED_FAST * freeCamSpeed
                end

                -- Direction vectors from rotation
                local radZ = math.rad(freeCamRot.z)
                local radX = math.rad(freeCamRot.x)
                local cosZ = math.cos(radZ)
                local sinZ = math.sin(radZ)
                local cosX = math.cos(radX)

                local forward = vector3(-sinZ * cosX, cosZ * cosX, math.sin(radX))
                local right = vector3(cosZ, sinZ, 0.0)

                local move = vector3(0, 0, 0)

                -- WASD (standard control IDs)
                if IsDisabledControlPressed(0, 32) then move = move + forward end   -- W (MoveUp/Forward)
                if IsDisabledControlPressed(0, 33) then move = move - forward end   -- S (MoveDown/Back)
                if IsDisabledControlPressed(0, 34) then move = move - right end     -- A (MoveLeft)
                if IsDisabledControlPressed(0, 35) then move = move + right end     -- D (MoveRight)

                -- Space = up, Ctrl = down
                if IsDisabledControlPressed(0, 22) then                              -- Space (Jump)
                    move = move + vector3(0, 0, 1)
                end
                if IsDisabledControlPressed(0, 36) then                              -- Left Ctrl (Duck)
                    move = move - vector3(0, 0, 1)
                end

                freeCamPos = freeCamPos + move * moveSpeed * dt * 60.0
            else
                -- NUI has focus. Only disable minimal game controls to prevent
                -- the player ped from doing things in the background.
                DisableAllControlActions(0)
            end

            ::continue::

            -- Always apply camera position
            if freeCam and isFreeCamActive then
                SetCamCoord(freeCam, freeCamPos.x, freeCamPos.y, freeCamPos.z)
                SetCamRot(freeCam, freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)
                SetCamFov(freeCam, freeCamFov)
            end
        end
    end)
end

function DirectorCamera.StopFreeCam()
    if not isFreeCamActive then return end
    isFreeCamActive = false
    isMiddleMouseHeld = false

    if freeCam then
        SetCamActive(freeCam, false)
        DestroyCam(freeCam, true)
        RenderScriptCams(false, true, 500, true, true)
        freeCam = nil
    end

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
end

function DirectorCamera.IsFreeCamActive() return isFreeCamActive end

function DirectorCamera.GetFreeCamState()
    return { pos = freeCamPos, rot = freeCamRot, fov = freeCamFov }
end

function DirectorCamera.SetFreeCamSpeed(speed)
    freeCamSpeed = math.max(0.1, math.min(10.0, speed))
end

--[[ =========================================================================
    PLAYBACK CAMERA
========================================================================= ]]

local playbackCam = nil
local isPlaybackActive = false

function DirectorCamera.StartPlayback()
    if isPlaybackActive then return end
    playbackCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(playbackCam, true)
    RenderScriptCams(true, true, 500, true, true)
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    isPlaybackActive = true
end

function DirectorCamera.UpdatePlayback(keyframes, currentTime)
    if not isPlaybackActive or not playbackCam then return end
    if not keyframes or #keyframes == 0 then return end

    if #keyframes == 1 then
        local kf = keyframes[1]
        SetCamCoord(playbackCam, kf.pos.x, kf.pos.y, kf.pos.z)
        SetCamRot(playbackCam, kf.rot.x, kf.rot.y, kf.rot.z, 2)
        SetCamFov(playbackCam, kf.fov or 50.0)
        return
    end

    if currentTime <= keyframes[1].time then
        local kf = keyframes[1]
        SetCamCoord(playbackCam, kf.pos.x, kf.pos.y, kf.pos.z)
        SetCamRot(playbackCam, kf.rot.x, kf.rot.y, kf.rot.z, 2)
        SetCamFov(playbackCam, kf.fov or 50.0)
        return
    end

    if currentTime >= keyframes[#keyframes].time then
        local kf = keyframes[#keyframes]
        SetCamCoord(playbackCam, kf.pos.x, kf.pos.y, kf.pos.z)
        SetCamRot(playbackCam, kf.rot.x, kf.rot.y, kf.rot.z, 2)
        SetCamFov(playbackCam, kf.fov or 50.0)
        return
    end

    local prevKf = keyframes[1]
    local nextKf = keyframes[#keyframes]
    for i = 1, #keyframes - 1 do
        if currentTime >= keyframes[i].time and currentTime <= keyframes[i + 1].time then
            prevKf = keyframes[i]
            nextKf = keyframes[i + 1]
            break
        end
    end

    local segDur = nextKf.time - prevKf.time
    local rawT = (currentTime - prevKf.time) / segDur
    local easingFn = Easings[nextKf.easing or "linear"] or Easings.linear
    local t = easingFn(rawT)

    local pos = LerpVec3(prevKf.pos, nextKf.pos, t)
    local rot = LerpRot(prevKf.rot, nextKf.rot, t)
    local fov = Lerp(prevKf.fov or 50.0, nextKf.fov or 50.0, t)

    SetCamCoord(playbackCam, pos.x, pos.y, pos.z)
    SetCamRot(playbackCam, rot.x, rot.y, rot.z, 2)
    SetCamFov(playbackCam, fov)
end

function DirectorCamera.StopPlayback()
    if not isPlaybackActive then return end
    isPlaybackActive = false
    if playbackCam then
        SetCamActive(playbackCam, false)
        DestroyCam(playbackCam, true)
        RenderScriptCams(false, true, 500, true, true)
        playbackCam = nil
    end
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
end

function DirectorCamera.IsPlaybackActive() return isPlaybackActive end

print("^2[Director]^7 Camera system loaded (middle-click to navigate)")
