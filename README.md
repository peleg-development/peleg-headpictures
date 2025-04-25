# Peleg Head Pictures System

A FiveM resource for capturing, storing, and retrieving player head pictures.

## Features

- Automatic player headshot capturing and storage
- Server-side caching system to reduce database load
- Client-side exports for easy integration with other resources
- Configurable image quality and performance settings
- Support for both QBCore and ESX notification systems

## Installation

1. Place the `peleg-headpictures` folder in your server's resources directory
2. Add `ensure peleg-headpictures` to your server.cfg
3. Configure the settings in `config.lua` to match your server's needs
4. Start/restart your server

## Configuration

The following settings can be adjusted in `config.lua`:

```lua
Config = {}

-- General settings
Config.PictureUpdateInterval = 30 -- Minutes between automatic picture updates
Config.DefaultPicture = 'web/default.png' -- Default picture path for new players
Config.NotifyType = 'qb' -- Notification system: 'qb', 'esx', 'custom'

-- Database settings
Config.DatabaseTable = 'pictures' -- Name of the table to create/use

-- Picture settings
Config.PictureQuality = 0.6 -- 0.1 to 1.0 (lower means smaller size but lower quality)
Config.MaxDistance = 3.0 -- Maximum distance to take a picture of another player

-- Performance settings
Config.UseServerCache = true -- Cache pictures in server memory to reduce database load
Config.CacheTimeout = 15 -- Minutes before a cached picture expires
Config.CompressImages = true -- Compress images before storing
Config.MaxWidth = 256 -- Maximum width of stored pictures
```

## Client Exports

### CapturePlayerPicture
Captures a picture of the specified player's head.

```lua
-- Capture current player's picture
local base64 = exports['peleg-headpictures']:CapturePlayerPicture()

-- Capture another player's ped
local base64 = exports['peleg-headpictures']:CapturePlayerPicture(targetPed)
```

### GetCachedPicture
Retrieves a cached picture for a specific citizen ID.

```lua
local pictureData = exports['peleg-headpictures']:GetCachedPicture(citizenId)
```

### RequestPlayerPicture
Requests a player's picture from the server by their server ID.

```lua
exports['peleg-headpictures']:RequestPlayerPicture(serverId)
```

### RequestMultiplePlayerPictures
Requests pictures for multiple players at once.

```lua
exports['peleg-headpictures']:RequestMultiplePlayerPictures({serverId1, serverId2, serverId3})
```

## Server Events

The resource handles these server events:

- `peleg-headpictures:server:GetPicture` - Get picture for a specific player
- `peleg-headpictures:server:AddPicture` - Add/update a player's picture
- `peleg-headpictures:server:TakePictureOf` - Take a picture of a specific player (requires police job)
- `peleg-headpictures:server:GetMultiplePictures` - Get pictures for multiple players at once

## Performance Best Practices

To avoid performance issues:

1. **Limit frequent requests**: Do not spam picture requests, especially for multiple players
2. **Use the caching system**: Keep `Config.UseServerCache` enabled to reduce database load
3. **Adjust picture quality**: Lower `Config.PictureQuality` for better performance on larger servers
4. **Set reasonable cache timeouts**: Adjust `Config.CacheTimeout` based on your server's memory capabilities
5. **Limit picture size**: Keep `Config.MaxWidth` at 256 or lower to reduce memory usage
6. **Don't request pictures in loops**: Avoid requesting pictures in frequent loops or for all players at once
7. **Use RequestMultiplePlayerPictures**: When getting multiple pictures, use the batch function instead of individual requests
8. **Check cached pictures first**: Always check if a picture is already cached before requesting it from the server

## Commands

- `/selfie` - Takes a new picture of your character
- `/takeplayerpic` - Takes a picture of the closest player (requires police job)

## Integration Example

Example of integrating with a player info UI:

```lua
-- When your UI opens:
RegisterNetEvent('yourResource:openPlayerInfo', function(targetServerId)
    -- First check if we already have the picture cached
    local citizenId = YourFramework.GetPlayerByCitizenId(targetServerId)
    local cachedPic = exports['peleg-headpictures']:GetCachedPicture(citizenId)
    
    if cachedPic then
        -- Use the cached picture immediately
        DisplayPlayerInfoWithPicture(playerData, cachedPic)
    else
        -- Request the picture from server
        exports['peleg-headpictures']:RequestPlayerPicture(targetServerId)
        -- The picture will be received via event
    end
end)

-- Handle received picture
RegisterNetEvent('peleg-headpictures:client:ReceivePicture', function(pictureData, citizenId)
    -- Update your UI with the received picture
    UpdatePlayerInfoUI(pictureData)
end)
``` 