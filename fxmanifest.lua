fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore'
version '0.0.1'

shared_scripts {
    'Core/config/*.lua',
    'Core/shared/sh_main.lua',    -- First!
    'Core/shared/sh_utils.lua',
    'Core/shared/sh_events.lua'
}

client_scripts {
    'Core/client/cl_main.lua',    -- Loads after shared
    'Core/client/cl_callbacks.lua'
}
