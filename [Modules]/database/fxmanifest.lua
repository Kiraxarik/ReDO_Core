fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Database Module'
version '0.1.0'

dependency 'Core'

server_scripts {
    'server/sv_mysql.lua',
    'server/sv_querybuilder.lua',
    'server/sv_database.lua',
    'server/sv_table_cleanup.lua'
}
