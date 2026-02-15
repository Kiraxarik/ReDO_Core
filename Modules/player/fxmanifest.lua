fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM Ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Player Module'
version '0.1.0'

-- Requires core and database to be loaded first
dependencies {
    'ReDO_Core',
    'ReDO_Database'
}

server_scripts {
    'server/sv_player.lua'
}

client_scripts {
    -- 'client/cl_player.lua'
}

shared_scripts {
    -- 'shared/sh_player.lua'
}
