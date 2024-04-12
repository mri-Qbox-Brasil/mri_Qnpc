local npcTable = {}

AddEventHandler("insertData")
RegisterNetEvent("insertData", function(coords, model, data, heading)
    table.insert(npcTable, {
        name = data.name,
        hash = model,
        event = data.event,
        coords = coords,
        heading = heading,
        animDict = data.animDict,
        animName = data.animName,
        useOxTarget = data.useOxTarget,
        job = data.job,
        grade = data.grade,
        oxTargetLabel = data.oxTargetLabel,
        useDrawText = data.useDrawText,
        drawTextKey = data.drawTextKey,
    })
    SaveNPCData()
end)

AddEventHandler("npcDelete")
RegisterNetEvent("npcDelete", function(name)
    for i = #npcTable, 1, -1 do
        if string.lower(npcTable[i].name) == string.lower(name) then
            local npcHash = npcTable[i].hash
            table.remove(npcTable, i)
            SaveNPCData()
            TriggerClientEvent('deleteNPCServer', -1, npcHash)
            break
        end
    end
end)

function SaveNPCData()
    local jsonData = json.encode(npcTable)
    SaveResourceFile(GetCurrentResourceName(), "npcData.json", jsonData, -1)
    TriggerClientEvent('NPCresourceStart', -1, npcTable)
end

function LoadNPCData()
    local loadFile = LoadResourceFile(GetCurrentResourceName(), "npcData.json")
    if loadFile then
        npcTable = json.decode(loadFile)
    end
end

lib.callback.register('npcGetAll', function(source)
    return npcTable
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadNPCData()
        Wait(200)
        TriggerClientEvent('NPCresourceStart', -1, npcTable)
    end  
end)

AddEventHandler("playerJoining", function(playerId, reason)
    LoadNPCData()
    Wait(200)
    TriggerClientEvent('NPCresourceStart', playerId, npcTable)
end)