fx_version 'cerulean'
game 'gta5'

author 'Peleg'
description 'Player Head Pictures System for FiveM'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'web/index.html',
    'web/main.js',
    'web/style.css',
    'web/default.png'
}
