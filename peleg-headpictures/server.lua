---@class QBCore_Object
local QBCore = exports['qb-core']:GetCoreObject()

---@type string|nil
local defaultBase64 = nil

---@class ImageCacheData
---@field picture string
---@field timestamp number
---@field hash string
local imageCache = {}
local lastCleanup = 0

---@param data string
---@return string
local function GetCacheHash(data)
    local length = string.len(data)
    return tostring(length) .. "_" .. string.sub(data, 1, 20) .. string.sub(data, -20)
end

---@class B64_Class
local B64 = {}
B64.chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

---@param data string
---@return string
function B64.encode(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do
            r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i=1,6 do
            c = c + (x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return B64.chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

---@param currentTime number
local function CleanupCache()
    if not Config.UseServerCache then return end
    local currentTime = os.time()
    if currentTime - lastCleanup < 60 then return end
    lastCleanup = currentTime
    local timeout = Config.CacheTimeout * 60
    for citizenId, cacheData in pairs(imageCache) do
        if currentTime - cacheData.timestamp > timeout then
            imageCache[citizenId] = nil
        end
    end
end

---@class ResourceSetup
CreateThread(function()
    MySQL.query("CREATE TABLE IF NOT EXISTS " .. Config.DatabaseTable .. [[ (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) UNIQUE NOT NULL,
        picture LONGTEXT,
        lastupdate TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        hash VARCHAR(64) NULL
    )]])
    
    local defaultPath = GetResourcePath(GetCurrentResourceName()) .. '/' .. Config.DefaultPicture
    local f = io.open(defaultPath, "rb")
    if f then
        local content = f:read("*all")
        f:close()
        defaultBase64 = "data:image/png;base64," .. B64.encode(content)
    else
        print("[ERROR] Default picture not found at: " .. defaultPath)
    end
end)

---@param picture string
RegisterNetEvent("peleg-headpictures:server:AddPicture", function(picture)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenId = Player.PlayerData.citizenid
        if (not picture or picture == "") and defaultBase64 then
            picture = defaultBase64
        end
        
        local prefixRemoved = false
        if picture:sub(1, 22) == "data:image/png;base64," then
            picture = picture:sub(23)
            prefixRemoved = true
        elseif picture:sub(1, 23) == "data:image/jpeg;base64," then
            picture = picture:sub(24)
            prefixRemoved = true
        end

        local imageHash = GetCacheHash(picture)
        if Config.UseServerCache then
            imageCache[citizenId] = {
                picture = prefixRemoved and picture or picture:sub(23),
                timestamp = os.time(),
                hash = imageHash
            }
        end

        MySQL.query('SELECT hash FROM ' .. Config.DatabaseTable .. ' WHERE citizenid = ?', {citizenId}, function(result)
            local shouldUpdate = true
            if result and result[1] and result[1].hash == imageHash then
                shouldUpdate = false
            end
            
            if shouldUpdate then
                MySQL.query('SELECT 1 FROM ' .. Config.DatabaseTable .. ' WHERE citizenid = ?', {citizenId}, function(result)
                    if result and result[1] then
                        MySQL.update('UPDATE ' .. Config.DatabaseTable .. ' SET picture = ?, hash = ? WHERE citizenid = ?', {
                            picture,
                            imageHash,
                            citizenId
                        })
                    else
                        MySQL.insert('INSERT INTO ' .. Config.DatabaseTable .. ' (citizenid, picture, hash) VALUES (?, ?, ?)', {
                            citizenId,
                            picture,
                            imageHash
                        })
                    end
                end)
            end
        end)
    end
end)

---@param targetId number|string
RegisterNetEvent("peleg-headpictures:server:GetPicture", function(targetId)
    local src = source
    local targetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not targetPlayer then return end
    local citizenId = targetPlayer.PlayerData.citizenid
    if Config.UseServerCache and imageCache[citizenId] and imageCache[citizenId].picture then
        local cachedData = imageCache[citizenId]
        cachedData.timestamp = os.time()
        local pictureData = "data:image/jpeg;base64," .. cachedData.picture
        TriggerClientEvent('peleg-headpictures:client:ReceivePicture', src, pictureData, citizenId)
        CleanupCache()
        return
    end
    
    MySQL.query('SELECT picture, hash FROM ' .. Config.DatabaseTable .. ' WHERE citizenid = ?', {citizenId}, function(result)
        local pictureData = nil
        local hash = nil
        if result and result[1] and result[1].picture then
            local prefix = "data:image/jpeg;base64,"
            if result[1].picture:sub(1, 22) == "data:image/png;base64," then
                prefix = ""
            elseif result[1].picture:sub(1, 23) == "data:image/jpeg;base64," then
                prefix = ""
            end
            pictureData = prefix .. result[1].picture
            hash = result[1].hash or GetCacheHash(result[1].picture)
            if Config.UseServerCache and prefix ~= "" then
                imageCache[citizenId] = {
                    picture = result[1].picture,
                    timestamp = os.time(),
                    hash = hash
                }
            end
        elseif defaultBase64 then
            pictureData = defaultBase64
        end
        
        TriggerClientEvent('peleg-headpictures:client:ReceivePicture', src, pictureData, citizenId)
        CleanupCache()
    end)
end)

---@param targetId number|string
RegisterNetEvent("peleg-headpictures:server:TakePictureOf", function(targetId)
    local src = source
    local targetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not targetPlayer then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" or Player.PlayerData.job.grade.level >= 5 then
        TriggerClientEvent('peleg-headpictures:client:RequestHeadshot', targetId, src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to do this.", "error")
    end
end)

---@param Player table
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local citizenId = Player.PlayerData.citizenid
    MySQL.query('SELECT 1 FROM ' .. Config.DatabaseTable .. ' WHERE citizenid = ?', {citizenId}, function(result)
        if not result or not result[1] then
            SetTimeout(10000, function()
                TriggerClientEvent('peleg-headpictures:client:UpdateOwnPicture', Player.PlayerData.source)
            end)
        end
    end)
end)

---@param targetIds table
RegisterNetEvent("peleg-headpictures:server:GetMultiplePictures", function(targetIds)
    local src = source
    if type(targetIds) ~= "table" or #targetIds == 0 then return end
    if #targetIds > 20 then
        targetIds = {unpack(targetIds, 1, 20)}
    end

    local results = {}
    local pending = #targetIds

    for _, id in ipairs(targetIds) do
        local targetPlayer = QBCore.Functions.GetPlayer(tonumber(id))
        if targetPlayer then
            local citizenId = targetPlayer.PlayerData.citizenid
            if Config.UseServerCache and imageCache[citizenId] and imageCache[citizenId].picture then
                results[citizenId] = "data:image/jpeg;base64," .. imageCache[citizenId].picture
                pending = pending - 1
                imageCache[citizenId].timestamp = os.time()
                if pending == 0 then
                    TriggerClientEvent('peleg-headpictures:client:ReceiveMultiplePictures', src, results)
                    CleanupCache()
                end
            else
                MySQL.query('SELECT picture FROM ' .. Config.DatabaseTable .. ' WHERE citizenid = ?', {citizenId}, function(result)
                    if result and result[1] and result[1].picture then
                        local prefix = "data:image/jpeg;base64,"
                        if result[1].picture:sub(1, 22) == "data:image/png;base64," or result[1].picture:sub(1, 23) == "data:image/jpeg;base64," then
                            prefix = ""
                        end
                        results[citizenId] = prefix .. result[1].picture
                        if Config.UseServerCache and prefix ~= "" then
                            imageCache[citizenId] = {
                                picture = result[1].picture,
                                timestamp = os.time(),
                                hash = GetCacheHash(result[1].picture)
                            }
                        end
                    elseif defaultBase64 then
                        results[citizenId] = defaultBase64
                    end
                    pending = pending - 1
                    if pending == 0 then
                        TriggerClientEvent('peleg-headpictures:client:ReceiveMultiplePictures', src, results)
                        CleanupCache()
                    end
                end)
            end
        else
            pending = pending - 1
        end
    end

    if pending == 0 then
        TriggerClientEvent('peleg-headpictures:client:ReceiveMultiplePictures', src, results)
    end
end)
