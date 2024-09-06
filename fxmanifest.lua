fx_version 'cerulean'

games {"gta5", "rdr3"}

author "WhereiamL"
version '1.0.0'

lua54 'yes'

shared_scripts 	{
    '@ox_lib/init.lua',
    'data/*.lua'
}
client_script {
                '@qbx_core/modules/playerdata.lua',
                "client/*.lua",
}
server_script "server/*.lua"