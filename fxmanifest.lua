fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Core'
version '0.1.0'

-- Load in this exact order!
shared_scripts {
    'config/config.lua',
    'shared/sh_main.lua',
    'shared/sh_utils.lua',
    'shared/sh_events.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_callbacks.lua'
}

server_scripts {
    'server/sv_main.lua',
    'server/sv_callbacks.lua',
    'server/sv_events.lua'
}

exports {
    'getSharedObject',
    'GetCoreObject'
}

server_exports {
    'getSharedObject',
    'GetCoreObject'
}
