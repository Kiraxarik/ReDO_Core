fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Player Module'
version '0.2.0'

-- This resource MUST load after Core and database.
-- "dependency" tells FXServer: "don't start me until these are running."
-- If Core or database fails to start, this won't start either.
dependencies {
    'Core',
    'database'
}

-- Shared files load on BOTH server and client, in this order.
shared_scripts {
    'shared/sh_schemas.lua'
}

-- Server-only files. Order matters:
-- 1. sv_auth.lua - handles playerConnecting (ban/whitelist checks)
-- 2. sv_accounts.lua - account CRUD (create/read/update/delete)
-- 3. sv_characters.lua - character CRUD
-- 4. sv_callbacks.lua - registers server callbacks the client can trigger
server_scripts {
    'server/sv_shared.lua',
    'server/sv_auth.lua',
    'server/sv_accounts.lua',
    'server/sv_characters.lua',
    'server/sv_callbacks.lua'
}

-- Client-only files.
-- cl_spawn.lua handles what happens after character selection.
-- cl_charselect.lua talks to the NUI (the HTML character select screen).
client_scripts {
    'client/cl_spawn.lua',
    'client/cl_charselect.lua'
}

-- NUI = "New UI" - lets you show HTML/CSS/JS interfaces in-game.
-- ui_page tells the engine which HTML file to load as the UI.
ui_page 'html/index.html'

-- files tells the engine which files to bundle for the NUI.
-- Without this, the HTML file can't find its CSS/JS.
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
