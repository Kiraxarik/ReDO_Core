--[[ =========================================================================
    FILE: server/sv_shared.lua
    LOAD ORDER: FIRST server file in player module
    RUNS ON: Server only

    PURPOSE:
    With lua54, each resource has its own Lua state. When we do:
        local ReDOCore = exports['Core']:GetCoreObject()
    we get a PROXY table, not the real table. Setting fields on it
    (like ReDOCore.FindAccount = function...) only affects our local
    proxy — other files that also got the proxy won't see those changes.

    SOLUTION:
    This file creates a MODULE-LOCAL table called "PlayerModule" as a
    Lua global. Since all server_scripts in the same resource share
    the same Lua state, every server file can read/write to it.

    Use PlayerModule for functions/data shared between sv_*.lua files.
    Use ReDOCore (the proxy) only for READING config, calling Core
    functions like Info/Warn/Error, and accessing Core exports.
========================================================================= ]]

-- Global within this resource's Lua state.
-- All server_scripts in the player resource can access this.
PlayerModule = PlayerModule or {}

-- Sub-tables for organization
PlayerModule.PendingPlayers = {}
PlayerModule.ActiveCharacters = {}
PlayerModule.PlayerCount = 0
