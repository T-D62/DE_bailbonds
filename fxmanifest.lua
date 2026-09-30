fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'DimeloEli'
description 'Simple Bail Bonds Script'
version '1.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'shared/utils.lua',
    'config.lua',
}