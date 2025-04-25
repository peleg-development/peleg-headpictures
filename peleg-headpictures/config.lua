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