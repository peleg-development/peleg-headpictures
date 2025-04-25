---@class QBCore_Object
local QBCore = exports['qb-core']:GetCoreObject()
local inProgressHeadshots = {}
local requestsData = {}
local receivedPictures = {}

---@return nil
CreateThread(function()
    SchedulePeriodicUpdate()
end)

---@return nil
function SchedulePeriodicUpdate()
    CreateThread(function()
        Wait(30000)
        TriggerEvent('peleg-headpictures:client:UpdateOwnPicture')
        while true do
            Wait(Config.PictureUpdateInterval * 60 * 1000)
            TriggerEvent('peleg-headpictures:client:UpdateOwnPicture')
        end
    end)
end

---@param message string
---@param type string
---@return nil
function Notify(message, type)
    if Config.NotifyType == 'qb' then
        QBCore.Functions.Notify(message, type)
    elseif Config.NotifyType == 'esx' then
        TriggerEvent('esx:showNotification', message)
    elseif Config.NotifyType == 'custom' then
        -- Custom notification system implementation here.
    end
end

---@param coords vector3
---@return number, number
function GetClosestPlayer(coords)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerId = PlayerId()
    for i = 1, #players do
        if players[i] ~= playerId then
            local targetPed = GetPlayerPed(players[i])
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = players[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

---@return string
function GenerateId()
    local id = ""
    for i = 1, 15 do
        id = id .. (math.random(1, 2) == 1 and string.char(math.random(97, 122)) or tostring(math.random(0, 9)))
    end
    return id
end

---@return nil
function ClearHeadshots()
    for handle, _ in pairs(inProgressHeadshots) do
        if IsPedheadshotValid(handle) then 
            UnregisterPedheadshot(handle)
        end
    end
    inProgressHeadshots = {}
end

---@param ped number|nil
---@return table
function GetHeadshot(ped)
    if not ped then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then
        return {success = false, error = "Entity does not exist"}
    end
    local handleId = #inProgressHeadshots + 1
    local timer = GetGameTimer() + 5000
    local handle = RegisterPedheadshotTransparent(ped)
    inProgressHeadshots[handleId] = handle
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        Wait(50)
        if GetGameTimer() >= timer then
            if IsPedheadshotValid(handle) then
                UnregisterPedheadshot(handle)
            end
            return {success = false, error = "Headshot timed out"}
        end
    end
    local txd = GetPedheadshotTxdString(handle)
    local url = string.format("https://nui-img/%s/%s", txd, txd)
    return {success = true, url = url, txd = txd, handle = handle, handleId = handleId}
end

---@param ped number|nil
---@return table
function GetBase64(ped)
    if not ped then ped = PlayerPedId() end
    local headshot = GetHeadshot(ped)
    if not headshot.success then return headshot end
    local requestId = GenerateId()
    requestsData[requestId] = nil
    SendNUIMessage({
        type = "convert_base64",
        img = headshot.url,
        handle = headshot.handle,
        handleId = headshot.handleId,
        id = requestId,
        quality = Config.PictureQuality,
        maxWidth = Config.MaxWidth
    })
    local timer = GetGameTimer() + 5000
    while not requestsData[requestId] do
        Wait(100)
        if GetGameTimer() >= timer then
            return {success = false, error = "Base64 conversion timed out"}
        end
    end
    local result = requestsData[requestId]
    requestsData[requestId] = nil
    return {success = true, base64 = result}
end

---@param targetPed number|nil
---@return string|nil
function CapturePlayerPicture(targetPed)
    if not targetPed then targetPed = PlayerPedId() end
    if targetPed ~= PlayerPedId() then
        TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_PAPARAZZI", 0, true)
        Wait(2000)
    end
    local result = GetBase64(targetPed)
    if targetPed ~= PlayerPedId() then
        ClearPedTasks(PlayerPedId())
    end
    if result.success then
        return result.base64
    else
        Notify("Failed to capture picture: " .. (result.error or "Unknown error"), "error")
        return nil
    end
end

---@param citizenId string
---@return string|nil
function GetCachedPicture(citizenId)
    if receivedPictures[citizenId] then
        return receivedPictures[citizenId]
    end
    return nil
end

---@param data table
---@param cb function
RegisterNUICallback("base64", function(data, cb)
    if data.handleId then
        local handle = inProgressHeadshots[data.handleId]
        if handle and IsPedheadshotValid(handle) then
            UnregisterPedheadshot(handle)
            inProgressHeadshots[data.handleId] = nil
        end
    end
    if data.id then
        requestsData[data.id] = data.base64
    end
    cb({ok = true})
end)

exports('CapturePlayerPicture', CapturePlayerPicture)
exports('GetCachedPicture', GetCachedPicture)
exports('RequestPlayerPicture', function(serverId)
    TriggerServerEvent('peleg-headpictures:server:GetPicture', serverId)
end)

RegisterCommand('selfie', function()
    TriggerEvent('peleg-headpictures:client:UpdateOwnPicture')
end, false)

RegisterCommand('takeplayerpic', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer, closestDistance = GetClosestPlayer(playerCoords)
    if closestPlayer ~= -1 and closestDistance <= Config.MaxDistance then
        local targetPed = GetPlayerPed(closestPlayer)
        local base64 = CapturePlayerPicture(targetPed)
        if base64 then
            TriggerServerEvent('peleg-headpictures:server:TakePictureOf', GetPlayerServerId(closestPlayer))
            Notify("Picture taken successfully", "success")
        end
    else
        Notify("No player nearby", "error")
    end
end, false)

RegisterNetEvent('peleg-headpictures:client:UpdateOwnPicture', function()
    local base64 = CapturePlayerPicture()
    if base64 then
        TriggerServerEvent('peleg-headpictures:server:AddPicture', base64)
        Notify("Your ID picture has been updated", "success")
    end
end)

RegisterNetEvent('peleg-headpictures:client:RequestHeadshot', function(requestingPlayer)
    local base64 = CapturePlayerPicture()
    if base64 then
        TriggerServerEvent('peleg-headpictures:server:AddPicture', base64)
    end
end)

RegisterNetEvent('peleg-headpictures:client:ReceivePicture', function(pictureData, citizenId)
    receivedPictures[citizenId] = pictureData
    SendNUIMessage({
        type = "display_picture",
        picture = pictureData,
        citizenId = citizenId
    })
end)

RegisterNetEvent('peleg-headpictures:client:ReceiveMultiplePictures', function(picturesData)
    for citizenId, pictureData in pairs(picturesData) do
        receivedPictures[citizenId] = pictureData
    end
    SendNUIMessage({
        type = "received_multiple_pictures",
        pictures = picturesData
    })
end)

---@param serverIds table
function RequestMultiplePlayerPictures(serverIds)
    if type(serverIds) ~= "table" or #serverIds == 0 then return end
    TriggerServerEvent('peleg-headpictures:server:GetMultiplePictures', serverIds)
end

exports('RequestMultiplePlayerPictures', RequestMultiplePlayerPictures)
