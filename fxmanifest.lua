fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - RedM Framework'
author 'Your Name'
version '0.1.0'

-- Load in this exact order!
shared_scripts {
    'Core/config/config.lua',     -- Config FIRST!
    'Core/shared/sh_main.lua',    -- Core object
    'Core/shared/sh_utils.lua',   -- Utilities (uses Config)
    'Core/shared/sh_events.lua'   -- Event helpers
}

-- Client-side files
client_scripts {
    'Core/client/cl_main.lua',
    'Core/client/cl_callbacks.lua'
}

-- Server-side files
server_scripts {
    'Core/server/sv_mysql.lua',         -- MySQL connection handler (first!)
    'Core/server/sv_querybuilder.lua',  -- Query builder & ORM (second!)
    'Core/server/sv_database.lua',      -- Database wrapper functions (third!)
    'Core/server/sv_table_cleanup.lua', -- Auto table cleanup system
    'Core/server/sv_main.lua',
    'Core/server/sv_player.lua',
    'Core/server/sv_callbacks.lua',
    'Core/server/sv_events.lua'
}

-- Exports
exports {
    'getSharedObject',
    'GetCoreObject'
}

server_exports {
    'getSharedObject',
    'GetCoreObject'
}
