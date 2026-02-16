--[[ =========================================================================
    FILE: server/sv_main.lua
    RUNS ON: Server only

    PURPOSE:
    Director server-side initialization and permission checks.
========================================================================= ]]

local ReDOCore = exports['Core']:GetCoreObject()

-- Who is allowed to use the editor (by default, console/admin only)
-- Later this can check player groups from the account system
local allowedGroups = { "superadmin", "admin" }

function DirectorServer_IsAllowed(src)
    -- For now, allow everyone in development
    -- TODO: Check player group from PlayerModule
    return true
end

ReDOCore.Info("Director server module loaded")
