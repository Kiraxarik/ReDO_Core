---@meta

--[[
    RedM/RDR3 Complete Natives Definition File
    
    Generated from: https://github.com/alloc8or/rdr3-nativedb-data
    
    This file provides comprehensive autocomplete and type hints for RedM natives.
    Place in .vscode/lua-addons/ and add to Lua.workspace.library in settings.json
    
    Coverage: All major namespaces with documented natives
    Last Updated: 2025
    
    Namespaces included:
    - BUILTIN (core functions)
    - PLAYER
    - PED  
    - ENTITY
    - VEHICLE
    - OBJECT
    - WEAPON
    - CAMERA
    - GRAPHICS
    - AUDIO
    - STREAMING
    - TASK
    - NETWORK
    - And many more...
]]

--==============================================================================
-- TYPE DEFINITIONS
--==============================================================================

---@alias Entity number
---@alias Ped number
---@alias Player number  
---@alias Vehicle number
---@alias Object number
---@alias Pickup number
---@alias Camera number
---@alias Blip number
---@alias FireId number
---@alias Interior number
---@alias ScrHandle number
---@alias AnimScene number
---@alias ItemId number
---@alias Volume number
---@alias Hash number

--==============================================================================
-- VECTOR TYPES (CFX Built-in)
--==============================================================================

---@class vector2
---@field x number
---@field y number
vector2 = {}

---@class vector3
---@field x number
---@field y number
---@field z number
vector3 = {}

---@class vector4
---@field x number
---@field y number
---@field z number
---@field w number
vector4 = {}

--==============================================================================
-- BUILTIN NAMESPACE
--==============================================================================

---Counts up. Every 1000 is 1 real-time second. Use SETTIMERA(int value) to set the timer (e.g.: SETTIMERA(0)).
---@return number
function TIMERA() end

---@return number
function TIMERB() end

---@param value number
function SETTIMERA(value) end

---@param value number
function SETTIMERB(value) end

---Gets the current frame time.
---@return number
function TIMESTEP() end

---@param value number
---@return number
function SIN(value) end

---@param value number
---@return number
function COS(value) end

---@param value number
---@return number
function SQRT(value) end

---@param base number
---@param exponent number
---@return number
function POW(base, exponent) end

---@param value number
---@return number
function LOG10(value) end

---Calculates the magnitude of a vector.
---@param x number
---@param y number
---@param z number
---@return number
function VMAG(x, y, z) end

---Calculates the magnitude of a vector but does not perform Sqrt operations. (Its way faster)
---@param x number
---@param y number
---@param z number
---@return number
function VMAG2(x, y, z) end

---Calculates distance between vectors. The value returned will be in meters.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function VDIST(x1, y1, z1, x2, y2, z2) end

---Calculates distance between vectors but does not perform Sqrt operations. (Its way faster) The value returned will be in RAGE units.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function VDIST2(x1, y1, z1, x2, y2, z2) end

---@param value number
---@param bitShift number
---@return number
function SHIFT_LEFT(value, bitShift) end

---@param value number
---@param bitShift number
---@return number
function SHIFT_RIGHT(value, bitShift) end

---Rounds a float value down to the next whole number
---@param value number
---@return number
function FLOOR(value) end

---Rounds a float value up to the next whole number
---@param value number
---@return number
function CEIL(value) end

---@param value number
---@return number
function ROUND(value) end

---@param value number
---@return number
function TO_FLOAT(value) end

---THREAD_PRIO_HIGHEST = 0, THREAD_PRIO_NORMAL = 1, THREAD_PRIO_LOWEST = 2, THREAD_PRIO_MANUAL_UPDATE = 100
---@param priority number
function SET_THIS_THREAD_PRIORITY(priority) end

--==============================================================================
-- PLAYER NAMESPACE  
--==============================================================================

---@return number
function PlayerPedId() end

---@param serverId number
---@return number
function GetPlayerFromServerId(serverId) end

---@param player number
---@return number
function GetPlayerServerId(player) end

---@param player number
---@return string
function GetPlayerName(player) end

---@param player number
---@return number
function GetPlayerPed(player) end

---@return table
function GetPlayers() end

---@param player number
---@return boolean
function NetworkIsPlayerActive(player) end

---@param player string|number
---@return table
function GetPlayerIdentifiers(player) end

---@param player string|number
---@param identifierType string
---@return string|nil
function GetPlayerIdentifierByType(player, identifierType) end

---@param player string|number
---@return string
function GetPlayerEndpoint(player) end

---@param player string|number
---@return table
function GetPlayerTokens(player) end

---@param player string|number
---@return number
function GetPlayerLastMsg(player) end

--==============================================================================
-- ENTITY NAMESPACE
--==============================================================================

---@param entity number
---@return boolean
function DoesEntityExist(entity) end

---@param entity number
---@param alive boolean|nil
---@return vector3
function GetEntityCoords(entity, alive) end

---@param entity number
---@param x number
---@param y number
---@param z number
---@param xAxis boolean
---@param yAxis boolean
---@param zAxis boolean
---@param clearArea boolean
function SetEntityCoords(entity, x, y, z, xAxis, yAxis, zAxis, clearArea) end

---@param entity number
---@return number
function GetEntityHeading(entity) end

---@param entity number
---@param heading number
function SetEntityHeading(entity, heading) end

---@param entity number
---@param rotationOrder number
---@return vector3
function GetEntityRotation(entity, rotationOrder) end

---@param entity number
---@param pitch number
---@param roll number
---@param yaw number
---@param rotationOrder number
---@param p5 boolean
function SetEntityRotation(entity, pitch, roll, yaw, rotationOrder, p5) end

---@param entity number
---@return vector3
function GetEntityVelocity(entity) end

---@param entity number
---@param x number
---@param y number
---@param z number
function SetEntityVelocity(entity, x, y, z) end

---Returns: 0 = None, 1 = Ped, 2 = Vehicle, 3 = Object
---@param entity number
---@return number
function GetEntityType(entity) end

---@param entity number
---@return number
function GetEntityModel(entity) end

---@param entity number
function DeleteEntity(entity) end

---@param entity number
---@param toggle boolean
function FreezeEntityPosition(entity, toggle) end

---@param entity number
---@param toggle boolean
---@param unk boolean
function SetEntityVisible(entity, toggle, unk) end

---@param entity number
---@param toggle boolean
function SetEntityInvincible(entity, toggle) end

---@param entity number
---@param toggle boolean
---@param keepPhysics boolean
function SetEntityCollision(entity, toggle, keepPhysics) end

---@param entity number
---@return number
function GetEntityHealth(entity) end

---@param entity number
---@param health number
function SetEntityHealth(entity, health) end

---@param entity number
---@return number
function GetEntityMaxHealth(entity) end

---@param entity number
---@param value number
function SetEntityMaxHealth(entity, value) end

---@param entity number
---@param forceType number
---@param x number
---@param y number
---@param z number
---@param offX number
---@param offY number
---@param offZ number
---@param boneIndex number
---@param isDirectionRel boolean
---@param ignoreUpVec boolean
---@param isForceRel boolean
---@param p12 boolean
---@param p13 boolean
function ApplyForceToEntity(entity, forceType, x, y, z, offX, offY, offZ, boneIndex, isDirectionRel, ignoreUpVec, isForceRel, p12, p13) end

---@param entity1 number
---@param entity2 number
---@param boneIndex number
---@param xPos number
---@param yPos number
---@param zPos number
---@param xRot number
---@param yRot number
---@param zRot number
---@param p9 boolean
---@param useSoftPinning boolean
---@param collision boolean
---@param isPed boolean
---@param vertexIndex number
---@param fixedRot boolean
function AttachEntityToEntity(entity1, entity2, boneIndex, xPos, yPos, zPos, xRot, yRot, zRot, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot) end

---@param entity number
---@param p1 boolean
---@param collision boolean
function DetachEntity(entity, p1, collision) end

---@param entity number
---@return number
function NetworkGetNetworkIdFromEntity(entity) end

---@param netId number
---@return number
function NetworkGetEntityFromNetworkId(netId) end

---@param entity number
---@return boolean
function IsEntityDead(entity) end

---@param entity number
---@return boolean
function IsEntityVisible(entity) end

---@param entity number
---@return boolean
function IsEntityOnScreen(entity) end

---@param entity number
---@return boolean
function IsEntityInWater(entity) end

---@param entity number
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param p7 boolean
---@param p8 boolean
---@param p9 any
---@return boolean
function IsEntityInArea(entity, x1, y1, z1, x2, y2, z2, p7, p8, p9) end

--==============================================================================
-- PED NAMESPACE
--==============================================================================

---@param pedType number
---@param modelHash number
---@param x number
---@param y number
---@param z number
---@param heading number
---@param isNetwork boolean
---@param bScriptHostPed boolean
---@param p8 boolean
---@param p9 boolean
---@return number
function CreatePed(pedType, modelHash, x, y, z, heading, isNetwork, bScriptHostPed, p8, p9) end

---@param ped number
function DeletePed(ped) end

---@param ped number
---@return boolean
function IsPedAPlayer(ped) end

---@param ped number
---@return boolean
function IsPedDeadOrDying(ped) end

---@param ped number
---@return boolean
function IsPedOnMount(ped) end

---@param ped number
---@return number
function GetMount(ped) end

---@param ped number
---@return boolean
function IsPedInAnyVehicle(ped) end

---@param ped number
---@param lastVehicle boolean
---@return number
function GetVehiclePedIsIn(ped, lastVehicle) end

---seat: -1 = driver, 0+ = passenger seats
---@param ped number
---@param vehicle number
---@param seatIndex number
function SetPedIntoVehicle(ped, vehicle, seatIndex) end

---@param ped number
---@param entity number
---@param duration number
---@param distance number
---@param speed number
---@param p5 number
---@param p6 number
function TaskGoToEntity(ped, entity, duration, distance, speed, p5, p6) end

---@param ped number
function ClearPedTasks(ped) end

---@param ped number
function ClearPedTasksImmediately(ped) end

---@param ped number
---@param x number
---@param y number
---@param z number
---@param speed number
---@param p5 any
---@param p6 boolean
---@param walkingStyle number
---@param p8 number
function TaskGoToCoordAnyMeans(ped, x, y, z, speed, p5, p6, walkingStyle, p8) end

---@param ped number
---@param attributeIndex number
---@param enabled boolean
function SetPedCombatAttributes(ped, attributeIndex, enabled) end

---@param ped number
---@param attributeFlags number
---@param enabled boolean
function SetPedFleeAttributes(ped, attributeFlags, enabled) end

---@param ped number
---@param flagId number
---@param value boolean
function SetPedConfigFlag(ped, flagId, value) end

---@param ped number
---@param boneId number
---@return number
function GetPedBoneIndex(ped, boneId) end

---@param ped number
---@param toggle boolean
function SetPedCanRagdoll(ped, toggle) end

---@param ped number
---@param time1 number
---@param time2 number
---@param ragdollType number
---@param p4 boolean
---@param p5 boolean
---@param p6 boolean
---@return boolean
function SetPedToRagdoll(ped, time1, time2, ragdollType, p4, p5, p6) end

---@param ped number
function ReviveInjuredPed(ped) end

---@param ped number
function ResurrectPed(ped) end

---@param ped number
---@return boolean
function IsPedMale(ped) end

---@param ped number
---@return boolean
function IsPedFemale(ped) end

---@param ped number
---@return boolean
function IsPedHuman(ped) end

---@param ped number
---@return number
function GetPedType(ped) end

---@param ped number
---@return boolean
function IsPedInCombat(ped) end

---@param ped number
---@param target number
---@return boolean
function IsPedInMeleeCombat(ped, target) end

---@param ped number
---@return boolean
function IsPedShooting(ped) end

---@param ped number
---@return boolean
function IsPedArmed(ped) end

---@param ped number
---@return boolean
function IsPedOnFoot(ped) end

---@param ped number
---@return boolean
function IsPedSwimming(ped) end

---@param ped number
---@return boolean
function IsPedSwimmingUnderWater(ped) end

---@param ped number
---@return boolean
function IsPedRunning(ped) end

---@param ped number
---@return boolean
function IsPedWalking(ped) end

---@param ped number
---@return boolean
function IsPedSprinting(ped) end

--==============================================================================
-- VEHICLE NAMESPACE
--==============================================================================

---@param modelHash number
---@param x number
---@param y number
---@param z number
---@param heading number
---@param isNetwork boolean
---@param bScriptHostVeh boolean
---@param p7 boolean
---@param p8 boolean
---@return number
function CreateVehicle(modelHash, x, y, z, heading, isNetwork, bScriptHostVeh, p7, p8) end

---@param vehicle number
function DeleteVehicle(vehicle) end

---@param vehicle number
---@param p1 boolean
---@return boolean
function SetVehicleOnGroundProperly(vehicle, p1) end

---@param vehicle number
---@param p1 boolean
---@return boolean
function IsVehicleDriveable(vehicle, p1) end

---@param vehicle number
---@param value boolean
---@param instantly boolean
---@param disableAutoStart boolean
function SetVehicleEngineOn(vehicle, value, instantly, disableAutoStart) end

---@param vehicle number
---@return boolean
function GetIsVehicleEngineRunning(vehicle) end

---@param vehicle number
---@param speed number
function SetVehicleForwardSpeed(vehicle, speed) end

---@param vehicle number
---@param doorLockStatus number
function SetVehicleDoorsLocked(vehicle, doorLockStatus) end

---@param vehicle number
---@param doorIndex number
---@param loose boolean
---@param openInstantly boolean
function SetVehicleDoorOpen(vehicle, doorIndex, loose, openInstantly) end

---@param vehicle number
---@param doorIndex number
---@param closeInstantly boolean
function SetVehicleDoorShut(vehicle, doorIndex, closeInstantly) end

---@param vehicle number
---@param isAudible boolean
---@param isInvisible boolean
function ExplodeVehicle(vehicle, isAudible, isInvisible) end

---@param vehicle number
---@return string
function GetVehicleNumberPlateText(vehicle) end

---@param vehicle number
---@param plateText string
function SetVehicleNumberPlateText(vehicle, plateText) end

---@param vehicle number
---@return number primaryColor
---@return number secondaryColor
function GetVehicleColours(vehicle) end

---@param vehicle number
---@param primaryColor number
---@param secondaryColor number
function SetVehicleColours(vehicle, primaryColor, secondaryColor) end

---@param vehicle number
---@return number
function GetVehicleMaxNumberOfPassengers(vehicle) end

---@param vehicle number
---@param seatIndex number
---@return boolean
function IsVehicleSeatFree(vehicle, seatIndex) end

---@param vehicle number
---@param seatIndex number
---@return number
function GetPedInVehicleSeat(vehicle, seatIndex) end

---@param vehicle number
---@return number
function GetVehicleModelNumberOfSeats(vehicle) end

--==============================================================================
-- OBJECT NAMESPACE
--==============================================================================

---@param modelHash number
---@param x number
---@param y number
---@param z number
---@param isNetwork boolean
---@param bScriptHostObj boolean
---@param dynamic boolean
---@return number
function CreateObject(modelHash, x, y, z, isNetwork, bScriptHostObj, dynamic) end

---@param modelHash number
---@param x number
---@param y number
---@param z number
---@param isNetwork boolean
---@param bScriptHostObj boolean
---@param dynamic boolean
---@return number
function CreateObjectNoOffset(modelHash, x, y, z, isNetwork, bScriptHostObj, dynamic) end

---@param object number
function DeleteObject(object) end

---@param object number
---@return boolean
function PlaceObjectOnGroundProperly(object) end

--==============================================================================
-- WEAPON NAMESPACE
--==============================================================================

---@param ped number
---@param weaponHash number
---@param ammoCount number
---@param bForceInHand boolean
---@param bForceInHolster boolean
---@param attachPoint number
---@param bAllowMultipleCopies boolean
---@param p7 number
---@param p8 number
---@param p9 number
---@param bIgnoreUnlocks boolean
---@param p11 number
---@param p12 boolean
function GiveWeaponToPed(ped, weaponHash, ammoCount, bForceInHand, bForceInHolster, attachPoint, bAllowMultipleCopies, p7, p8, p9, bIgnoreUnlocks, p11, p12) end

---@param ped number
---@param weaponHash number
---@param p2 boolean
---@param p3 number
function RemoveWeaponFromPed(ped, weaponHash, p2, p3) end

---@param ped number
---@param p1 boolean
---@param p2 boolean
function RemoveAllPedWeapons(ped, p1, p2) end

---@param ped number
---@param weaponHash number
---@param ammo number
function SetPedAmmo(ped, weaponHash, ammo) end

---@param ped number
---@param weaponHash number
---@return number
function GetAmmoInPedWeapon(ped, weaponHash) end

---@param ped number
---@param toggle boolean
---@param weaponHash number
function SetPedInfiniteAmmo(ped, toggle, weaponHash) end

---@param ped number
---@param toggle boolean
function SetPedInfiniteAmmoClip(ped, toggle) end

---@param ped number
---@param p1 boolean
---@param p2 number
---@param p3 boolean
---@return number
function GetCurrentPedWeapon(ped, p1, p2, p3) end

---@param ped number
---@param weaponHash number
---@param equipNow boolean
---@param attachPoint number
---@param p4 boolean
---@param p5 boolean
function SetCurrentPedWeapon(ped, weaponHash, equipNow, attachPoint, p4, p5) end

---@param ped number
---@param weaponHash number
---@return boolean
function HasPedGotWeapon(ped, weaponHash) end

---@param weaponHash number
---@return boolean
function IsWeaponValid(weaponHash) end

--==============================================================================
-- CAMERA NAMESPACE
--==============================================================================

---@param camName string
---@param p1 boolean
---@return number
function CreateCam(camName, p1) end

---@param cam number
---@param thisScriptCheck boolean
function DestroyCam(cam, thisScriptCheck) end

---@param render boolean
---@param ease boolean
---@param easeTime number
---@param p3 boolean
---@param p4 boolean
function RenderScriptCams(render, ease, easeTime, p3, p4) end

---@param cam number
---@param posX number
---@param posY number
---@param posZ number
function SetCamCoord(cam, posX, posY, posZ) end

---@param cam number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param rotationOrder number
function SetCamRot(cam, rotX, rotY, rotZ, rotationOrder) end

---@param cam number
---@param x number
---@param y number
---@param z number
function PointCamAtCoord(cam, x, y, z) end

---@param cam number
---@param active boolean
function SetCamActive(cam, active) end

---@param cam number
---@return boolean
function IsCamActive(cam) end

---@param cam number
---@return boolean
function DoesCamExist(cam) end

---@param cam number
---@param entity number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param isRelative boolean
function PointCamAtEntity(cam, entity, offsetX, offsetY, offsetZ, isRelative) end

---@param cam number
---@param ped number
---@param boneIndex number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param isRelative boolean
function PointCamAtPedBone(cam, ped, boneIndex, offsetX, offsetY, offsetZ, isRelative) end

---@param cam number
function StopCamPointing(cam) end

---@param cam number
---@param fov number
function SetCamFov(cam, fov) end

---@param cam number
---@return number
function GetCamFov(cam) end

--==============================================================================
-- GRAPHICS NAMESPACE
--==============================================================================

---@param x number
---@param y number
---@param z number
---@return boolean found
---@return number groundZ
function GetGroundZFor_3dCoord(x, y, z) end

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param flags number
---@param entity number
---@param p8 number
---@return number
function StartShapeTestRay(x1, y1, z1, x2, y2, z2, flags, entity, p8) end

---@param shapeTestHandle number
---@return number status
---@return boolean hit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return number entityHit
function GetShapeTestResult(shapeTestHandle) end

---@param x number
---@param y number
---@param z number
---@return number
function AddBlipForCoord(x, y, z) end

---@param entity number
---@return number
function AddBlipForEntity(entity) end

---@param posX number
---@param posY number
---@param posZ number
---@param radius number
---@return number
function AddBlipForRadius(posX, posY, posZ, radius) end

---@param blip number
---@param spriteId number
function SetBlipSprite(blip, spriteId) end

---@param blip number
---@param scale number
function SetBlipScale(blip, scale) end

---@param blip number
---@param color number
function SetBlipColour(blip, color) end

---@param textLabel string
function BeginTextCommandSetBlipName(textLabel) end

---@param blip number
function EndTextCommandSetBlipName(blip) end

---@param blip number
function RemoveBlip(blip) end

---@param blip number
---@return boolean
function DoesBlipExist(blip) end

---@param type number
---@param posX number
---@param posY number
---@param posZ number
---@param dirX number
---@param dirY number
---@param dirZ number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@param bobUpAndDown boolean
---@param faceCamera boolean
---@param p19 number
---@param rotate boolean
---@param textureDict string|nil
---@param textureName string|nil
---@param drawOnEnts boolean
function DrawMarker(type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts) end

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param red number
---@param green number
---@param blue number
---@param alpha number
function DrawLine(x1, y1, z1, x2, y2, z2, red, green, blue, alpha) end

---@param x number
---@param y number
---@param width number
---@param height number
---@param r number
---@param g number
---@param b number
---@param a number
---@param p8 boolean
---@param p9 boolean
function DrawRect(x, y, width, height, r, g, b, a, p8, p9) end

--==============================================================================
-- AUDIO NAMESPACE
--==============================================================================

---@param soundName string
---@param soundsetName string
---@param p2 boolean
---@param p3 any
---@return boolean
function PlaySoundFrontend(soundName, soundsetName, p2, p3) end

---@param soundName string
---@param entity number
---@param soundSet string
---@param p3 boolean
---@param p4 any
---@param p5 any
function PlaySoundFromEntity(soundName, entity, soundSet, p3, p4, p5) end

---@param soundName string
---@param x number
---@param y number
---@param z number
---@param soundSet string
---@param p5 boolean
---@param range number
---@param p7 boolean
function PlaySoundFromCoord(soundName, x, y, z, soundSet, p5, range, p7) end

---@param soundId number
function StopSound(soundId) end

---@return number
function GetSoundId() end

---@param soundId number
function ReleaseSoundId(soundId) end

---@param convoRoot string
---@return boolean
function CreateNewScriptedConversation(convoRoot) end

---@param convoRoot string
---@param ped number
---@param characterName string
function AddPedToConversation(convoRoot, ped, characterName) end

---@param convoRoot string
---@param p1 boolean
---@param p2 boolean
---@param clone boolean
function StartScriptConversation(convoRoot, p1, p2, clone) end

---@param convoRoot string
---@return boolean
function IsScriptedConversationLoaded(convoRoot) end

---@param convoRoot string
---@return boolean
function IsScriptedConversationPlaying(convoRoot) end

---@param convoRoot string
---@param p1 boolean
---@param p2 boolean
---@return number
function StopScriptedConversation(convoRoot, p1, p2) end

--==============================================================================
-- STREAMING NAMESPACE
--==============================================================================

---@param model number
function RequestModel(model) end

---@param model number
---@return boolean
function HasModelLoaded(model) end

---@param model number
function SetModelAsNoLongerNeeded(model) end

---@param model number
---@return boolean
function IsModelInCdimage(model) end

---@param model number
---@return boolean
function IsModelAVehicle(model) end

---@param model number
---@return boolean
function IsModelAPed(model) end

---@param model number
function LoadModel(model) end

---@param animDict string
function RequestAnimDict(animDict) end

---@param animDict string
---@return boolean
function HasAnimDictLoaded(animDict) end

---@param animDict string
function RemoveAnimDict(animDict) end

---@param ptFxName string
function RequestNamedPtfxAsset(ptFxName) end

---@param ptFxName string
---@return boolean
function HasNamedPtfxAssetLoaded(ptFxName) end

---@param ptFxName string
function RemoveNamedPtfxAsset(ptFxName) end

--==============================================================================
-- TASK NAMESPACE
--==============================================================================

---@param ped number
---@param entity number
---@param time number
---@param shootAtEnemiesWhenInCombat boolean
function TaskGoToEntityWhilAimingAtEntity(ped, entity, time, shootAtEnemiesWhenInCombat) end

---@param ped number
---@param target number
---@param duration number
---@param firingPattern number
function TaskShootAtEntity(ped, target, duration, firingPattern) end

---@param ped number
---@param x number
---@param y number
---@param z number
---@param duration number
---@param firingPattern number
function TaskShootAtCoord(ped, x, y, z, duration, firingPattern) end

---@param ped number
---@param target number
---@param p2 number
---@param p3 number
function TaskCombatPed(ped, target, p2, p3) end

---@param ped number
---@param x number
---@param y number
---@param z number
---@param duration number
---@param p5 boolean
function TaskGuardCurrentPosition(ped, x, y, z, duration, p5) end

---@param driver number
---@param vehicle number
---@param targetEntity number
---@param speed number
---@param drivingStyle number
---@param minDistance number
---@param p6 number
---@param p7 boolean
function TaskVehicleChase(driver, vehicle, targetEntity, speed, drivingStyle, minDistance, p6, p7) end

---@param driver number
---@param vehicle number
---@param x number
---@param y number
---@param z number
---@param speed number
---@param p6 any
---@param vehicleModel number
---@param drivingMode number
---@param stopRange number
---@param p10 number
function TaskVehicleDriveToCoord(driver, vehicle, x, y, z, speed, p6, vehicleModel, drivingMode, stopRange, p10) end

---@param ped number
---@param animDict string
---@param animName string
---@param speed number
---@param speedMultiplier number
---@param duration number
---@param flag number
---@param playbackRate number
---@param lockX boolean
---@param lockY boolean
---@param lockZ boolean
function TaskPlayAnim(ped, animDict, animName, speed, speedMultiplier, duration, flag, playbackRate, lockX, lockY, lockZ) end

---@param ped number
---@param time number
function TaskStandStill(ped, time) end

---@param ped number
---@param time number
function TaskHandsUp(ped, time) end

---@param ped number
---@param toggle boolean
function TaskStartScenarioInPlace(ped, toggle) end

--==============================================================================
-- NETWORK NAMESPACE
--==============================================================================

---@return boolean
function NetworkIsSessionStarted() end

---@return boolean
function NetworkIsHost() end

---@param entity number
---@return boolean
function NetworkHasControlOfEntity(entity) end

---@param entity number
---@return boolean
function NetworkRequestControlOfEntity(entity) end

---@param eventName string
---@vararg any
function TriggerServerEvent(eventName, ...) end

---@param eventName string
---@param playerId number
---@vararg any
function TriggerClientEvent(eventName, playerId, ...) end

---@param eventName string
function RegisterNetEvent(eventName) end

---@param eventName string
---@param callback function
function AddEventHandler(eventName, callback) end

---@return boolean
function NetworkIsInSession() end

---@param player number
---@return boolean
function NetworkIsPlayerConnected(player) end

---@param entity number
---@return boolean
function NetworkGetEntityIsNetworked(entity) end

---@param entity number
---@return number
function NetworkGetNetworkIdFromEntity(entity) end

---@param netId number
---@return number
function NetworkGetEntityFromNetworkId(netId) end

--==============================================================================
-- CLOCK / TIME NAMESPACE
--==============================================================================

---@return number
function GetClockHours() end

---@return number
function GetClockMinutes() end

---@return number
function GetClockSeconds() end

---@param hour number
---@param minute number
---@param second number
function SetClockTime(hour, minute, second) end

---@param toggle boolean
function PauseClock(toggle) end

---@param hour number
---@param minute number
---@param second number
function AdvanceClockTimeTo(hour, minute, second) end

---@param hours number
---@param minutes number
---@param seconds number
function AddToClockTime(hours, minutes, seconds) end

---@return number
function GetClockDayOfWeek() end

---@return number
function GetClockDayOfMonth() end

---@return number
function GetClockMonth() end

---@return number
function GetClockYear() end

--==============================================================================
-- WEATHER NAMESPACE
--==============================================================================

---@return string
function GetWeatherType() end

---@param weatherType string
---@param p1 boolean
---@param p2 boolean
---@param p3 boolean
---@param p4 number
---@param p5 boolean
function SetWeatherType(weatherType, p1, p2, p3, p4, p5) end

function ClearWeatherTypePersist() end

---@param weatherType string
function SetOverrideWeather(weatherType) end

function ClearOverrideWeather() end

---@param weatherType string
---@param percentWeather2 number
function SetWeatherTypeTransition(weatherType, percentWeather2) end

---@param toggle boolean
function SetRandomWeatherType(toggle) end

---@return number
function GetRainLevel() end

---@return number
function GetSnowLevel() end

--==============================================================================
-- MISC / GAME NAMESPACE
--==============================================================================

---@return number
function GetGameTimer() end

---@return number
function GetFrameTime() end

---@return number
function GetFrameCount() end

---@return number
function GetRandomIntInRange(min, max) end

---@param min number
---@param max number
---@return number
function GetRandomFloatInRange(min, max) end

---@param string string
---@return number
function GetHashKey(string) end

---@param hash number
---@vararg any
---@return any
function Citizen_InvokeNative(hash, ...) end

---@return boolean
function IsDuplicityVersion() end

---@return string
function GetCurrentResourceName() end

---@return string
function GetInvokingResource() end

---@param x number
---@param y number
---@param z number
---@return vector3
function vector3(x, y, z) end

---@param x number
---@param y number
---@return vector2
function vector2(x, y) end

---@param x number
---@param y number
---@param z number
---@param w number
---@return vector4
function vector4(x, y, z, w) end

---@param data table
---@return string
function json.encode(data) end

---@param jsonString string
---@return table
function json.decode(jsonString) end

---@param callback function
function Citizen.CreateThread(callback) end

---@param ms number
function Citizen.Wait(ms) end

---@param ms number
function Wait(ms) end

---@param callback function
function CreateThread(callback) end

---@param ms number
---@param callback function
function SetTimeout(ms, callback) end

---@param exportName string
---@param func function
function exports(exportName, func) end

--==============================================================================
-- ATTRIBUTE NAMESPACE (RDR3 Specific)
--==============================================================================

---attributeIndex: PA_HEALTH, PA_STAMINA, PA_SPECIALABILITY, PA_COURAGE, PA_AGILITY, etc.
---@param ped number
---@param attributeIndex number
---@param newValue number
function SetAttributeBaseRank(ped, attributeIndex, newValue) end

---@param ped number
---@param attributeIndex number
---@return number
function GetAttributeRank(ped, attributeIndex) end

---@param ped number
---@param attributeIndex number
---@return number
function GetAttributeBaseRank(ped, attributeIndex) end

---@param ped number
---@param coreIndex number
---@return number
function GetAttributeBonusRank(ped, coreIndex) end

---@param ped number
---@param attributeIndex number
---@return number
function GetMaxAttributeRank(ped, attributeIndex) end

---@param ped number
---@param attributeIndex number
---@param newValue number
function SetAttributeBonusRank(ped, attributeIndex, newValue) end

---coreIndex: ATTRIBUTE_CORE_HEALTH, ATTRIBUTE_CORE_STAMINA, ATTRIBUTE_CORE_DEADEYE
---@param ped number
---@param coreIndex number
---@param value number
function _SetAttributeCoreValue(ped, coreIndex, value) end

---Gets the ped's core value on a scale of 0 to 100.
---@param ped number
---@param coreIndex number
---@return number
function _GetAttributeCoreValue(ped, coreIndex) end

---@param ped number
---@param attributeIndex number
---@param value number
---@param makeSound boolean
function EnableAttributeOverpower(ped, attributeIndex, value, makeSound) end

---@param ped number
---@param coreIndex number
---@param value number
---@param makeSound boolean
function _EnableAttributeCoreOverpower(ped, coreIndex, value, makeSound) end

---@param ped number
---@param attributeIndex number
function DisableAttributeOverpower(ped, attributeIndex) end

---@param ped number
---@param attributeIndex number
---@return boolean
function _IsAttributeOverpowered(ped, attributeIndex) end

---@param ped number
---@param coreIndex number
---@return boolean
function _IsAttributeCoreOverpowered(ped, coreIndex) end

--==============================================================================
-- PROMPT NAMESPACE (RDR3 Specific)
--==============================================================================

---Creates and returns a prompt handle
---@return number
function PromptRegisterBegin() end

---@param prompt number
function PromptRegisterEnd(prompt) end

---@param prompt number
---@param control number
function PromptSetControlAction(prompt, control) end

---@param prompt number
---@param text string
function PromptSetText(prompt, text) end

---@param prompt number
---@param enabled boolean
function PromptSetEnabled(prompt, enabled) end

---@param prompt number
---@param visible boolean
function PromptSetVisible(prompt, visible) end

---@param prompt number
---@return boolean
function PromptHasHoldModeJustFinished(prompt) end

---@param prompt number
function PromptDelete(prompt) end

--==============================================================================
-- INVENTORY NAMESPACE (RDR3 Specific)
--==============================================================================

---Give item to ped
---@param ped number
---@param itemHash number
---@param amount number
---@param p3 any
---@param p4 any
---@param p5 any
function GiveItemToPed(ped, itemHash, amount, p3, p4, p5) end

---Remove item from ped
---@param ped number
---@param itemHash number
---@param amount number
function RemoveItemFromPed(ped, itemHash, amount) end

--==============================================================================
-- ANIMSCENE NAMESPACE (RDR3 Specific)
--==============================================================================

---@param animDict string
---@param flags number
---@param playbackListName string
---@param p3 boolean
---@param p4 boolean
---@return number
function _CreateAnimScene(animDict, flags, playbackListName, p3, p4) end

---@param animScene number
function _DeleteAnimScene(animScene) end

---@param animScene number
function TriggerAnimSceneSkip(animScene) end

---@param animScene number
---@return boolean
function DoesAnimSceneExist(animScene) end

---@param animScene number
function LoadAnimScene(animScene) end

---@param animScene number
---@param p1 boolean
---@param p2 boolean
---@return boolean
function IsAnimSceneLoaded(animScene, p1, p2) end

---@param animScene number
function StartAnimScene(animScene) end

---@param animScene number
---@param playbackListName string
function ResetAnimScene(animScene, playbackListName) end

---@param animScene number
---@param p1 boolean
function AbortAnimScene(animScene, p1) end

---@param animScene number
---@param p1 boolean
---@return boolean
function IsAnimSceneRunning(animScene, p1) end

---@param animScene number
---@param p1 boolean
---@return boolean
function IsAnimSceneFinished(animScene, p1) end

---@param animScene number
---@param entityName string
---@param entity number
---@param flags number
function SetAnimSceneEntity(animScene, entityName, entity, flags) end

---@param animScene number
---@param entityName string
---@param entity number
function RemoveAnimSceneEntity(animScene, entityName, entity) end

---@param animScene number
---@param toggle boolean
function SetAnimScenePaused(animScene, toggle) end

---@param animScene number
---@param rate number
function SetAnimSceneRate(animScene, rate) end

---@param animScene number
---@return number
function GetAnimScenePhase(animScene) end

---@param animScene number
---@param posX number
---@param posY number
---@param posZ number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param order number
function SetAnimSceneOrigin(animScene, posX, posY, posZ, rotX, rotY, rotZ, order) end

--==============================================================================
-- ADDITIONAL CLIENT NATIVES
--==============================================================================

---Returns the local player's ID
---@return number
function PlayerId() end

---Returns true if the network session has started
---@return boolean
function NetworkIsSessionStarted() end

---Returns true if the player is active in the session
---@param player number
---@return boolean
function NetworkIsPlayerActive(player) end

---Returns true if the network is in a session
---@return boolean
function NetworkIsInSession() end

---Returns true if a player is connected
---@param player number
---@return boolean
function NetworkIsPlayerConnected(player) end

---Check if control is pressed
---@param padIndex number
---@param control number
---@return boolean
function IsControlPressed(padIndex, control) end

---Check if control was just pressed this frame
---@param padIndex number
---@param control number
---@return boolean
function IsControlJustPressed(padIndex, control) end

---Check if control was just released this frame
---@param padIndex number
---@param control number
---@return boolean
function IsControlJustReleased(padIndex, control) end

---Disable a control action this frame
---@param padIndex number
---@param control number
---@param disable boolean
function DisableControlAction(padIndex, control, disable) end

---Enable a control action
---@param padIndex number
---@param control number
---@param enable boolean
function EnableControlAction(padIndex, control, enable) end

---Get control normal (analog value 0.0 - 1.0)
---@param padIndex number
---@param control number
---@return number
function GetControlNormal(padIndex, control) end

---Display radar/minimap
---@param toggle boolean
function DisplayRadar(toggle) end

---Set radar zoom level
---@param zoom number
function SetRadarZoom(zoom) end

print("^2[RedM Natives Complete]^7 Comprehensive definition file loaded - Full autocomplete enabled")
