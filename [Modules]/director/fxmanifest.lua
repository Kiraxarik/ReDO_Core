fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Director (Cinematic Scene Editor & Playback)'
version '0.1.0'

dependencies {
    'Core'
}

client_scripts {
    'client/cl_camera.lua',
    'client/cl_entities.lua',
    'client/cl_playback.lua',
    'client/cl_editor.lua',
    'client/cl_main.lua'
}

server_scripts {
    'server/sv_main.lua',
    'server/sv_scenes.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/editor.js'
}
