fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM Ships.'
game 'rdr3'

lua54 'yes'

description 'ReDOCore - Database Module'
resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'
version '0.1.0'

-- Requires core to be loaded first
dependency 'ReDO_Core'

server_scripts {
    'server/sv_mysql.lua',
    'server/sv_querybuilder.lua',
    'server/sv_database.lua',
    'server/sv_table_cleanup.lua'
}
