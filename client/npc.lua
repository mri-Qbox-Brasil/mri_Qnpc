local npcTable = {}
local keyOptions = {}
local sortedKeys = {}
local drawString = {}
local showText = false
QBCore = exports['qb-core']:GetCoreObject()

local function npcMenuList()
    local options = {
        {
            title = 'Criar novo NPC',
            icon = 'fa-solid fa-square-plus',
            onSelect = function()
                TriggerEvent("npcCreationOrEditMenu")
            end,
        }
    }
    -- criar npc selecionando com a roda do mouse para selecionar na lista PedModels
    options[#options + 1] = {
        title = 'Selecionar NPC',
        icon = 'arrows-up-down',
        onSelect = function() 
            SelectPedModelForMenu(function(npc)
                if npc then
                    TriggerEvent("npcCreationOrEditMenu", "edit", npc)
                end
            end)
        end,
    }
                
    -- uma linha separadora
    options[#options + 1] = {
        progress = 0
    }
    -- listar todos npcs criados, ao clicar vai para o menu de edição
    local npc = lib.callback.await('npcGetAll', false)
    if npc then
        for i = 1, #npc do
            options[#options + 1] = {
                title = npc[i].name,
                icon = 'user',
                onSelect = function()
                    local options = {}
                    -- opções de editar, teleportar até o npc e apagar o npc
                    options[#options + 1] = {
                        title = 'Editar',
                        icon = 'edit',
                        onSelect = function()
                            TriggerEvent("npcCreationOrEditMenu", "edit", npc[i])
                        end,
                    }
                    options[#options + 1] = {
                        title = 'Copiar',
                        icon = 'copy',
                        onSelect = function()
                            TriggerEvent("npcCreationOrEditMenu", "copy", npc[i])
                        end,
                    }
                    options[#options + 1] = {
                        title = 'Teleportar',
                        icon = 'marker',
                        onSelect = function()
                            SetEntityCoords(cache.ped, npc[i].coords.x, npc[i].coords.y, npc[i].coords.z)
                        end,
                    }
                    options[#options + 1] = {
                        title = 'Deletar',
                        icon = 'trash',
                        iconColor = 'red',
                        onSelect = function()
                            TriggerServerEvent("npcDelete", npc[i].name)
                        end,
                    }

                    lib.registerContext({
                        id = 'npc_edit',
                        title = npc[i].name,
                        menu = 'npc_create',
                        options = options
                    })

                    lib.showContext('npc_edit')
                end,
            }
        end
    end
    lib.registerContext({
        id = 'npc_create',
        title = 'Criador de NPC',
        menu = 'menu_gerencial',
        options = options
    })
    lib.showContext('npc_create')
end

RegisterCommand("npc", function()
    npcMenuList()
end, false)

RegisterNetEvent("npcCreationOrEditMenu", function(menu, npc)
    local status = menu == "edit" or menu == "copy"
    local edit = menu == "edit" and true or false
    local copy = menu == "copy" and true or false
    local npcRandomName = copy and string.format("%s copy_%s", npc.name, math.random(100, 999)) or npc.name
    print(edit, json.encode(npc))
    for key, _ in pairs(keys) do
        table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys)
    for _, key in ipairs(sortedKeys) do
        local code = keys[key]
        table.insert(keyOptions, { value = tostring(code), label = key })
    end

    local input = lib.inputDialog(edit and 'Edição de NPC' or 'Criação de NPC', {
        {type = 'input', label = 'Nome do NPC', description = 'Utilize nomes diferentes ou não irá funcionar.', required = true, default = status and (copy and npc.name.." copy" or npc.name) or ""}, --1
        {type = 'input', label = 'Hash do NPC', description = 'Insira o hash do modelo do NPC.', required = true, default = status and npc.hash or ""},--2
        {type = 'input', label = 'Evento', description = 'O evento acionado após interagir com o NPC.', default = status and npc.event or ""},--3
        {type = 'input', placeholder = 'animDict', description = 'O dicionário de animações para o NPC.', default = status and npc.animDict or ""},--4
        {type = 'input', placeholder = 'animName', description = 'O nome da animação para o NPC.', default = status and npc.animName or ""},--5
        {type = 'checkbox', label = 'Usar TARGET', description = 'Ativar opções avançadas de interação com ox_target.', default = status and npc.useOxTarget or false},--6
        {type = 'checkbox', label = 'Usar TEXTO', description = 'Exibir texto acima do NPC usando drawText.', default = status and npc.useDrawText or false},--7
        {type = 'input', placeholder = 'Grupo de trabalho', description = 'Especifique o grupo de trabalho para restringir a interação. Deixe em branco para acesso irrestrito.', default = status and npc.job or ""},--8
        {type = 'input', label = 'Grau', description = 'Especifique o grau necessário para o grupo de trabalho.', default = status and npc.grade or ""},--9
        {type = 'textarea', label = 'Rótulo', description = 'Rótulo para ox target/drawtext.', default = status and npc.oxTargetLabel or ""},--10
        {type = 'select', label = 'Tecla de Menu', options = keyOptions, searchable = true, description = 'A tecla para abrir o menu se drawText estiver ativado, deixe em branco para a tecla padrão [E]', default = status and npc.drawTextKey or ""},--11
        {type = 'input', label = 'Scully Emote', description = 'Insira o emote para o NPC (exemplo: weld). Deixe em branco para usar a Animação de cima.', default = status and npc.scullyEmote or ""},--12
    })
    
    if not input then 
        if npc then CancelPlacement() end
        return 
    end
    
    local data = {
        name = input[1],
        hash = input[2],
        event = input[3],
        animDict = input[4] ~= "" and input[4] or "",
        animName = input[5] ~= "" and input[5] or "",
        useOxTarget = input[6] and true or false,
        useDrawText = input[7] and true or false,
        job = input[8] ~= "" and input[8] or false,
        grade = input[9] ~= "" and input[9] or 0,
        oxTargetLabel = input[10] or "Sem legenda",
        drawTextKey = input[11] or "E",
        scullyEmote = input[12] or nil,
    }

    if edit and npc.name then
        -- print('editou npc existente')
        TriggerServerEvent("npcDelete", npc.name)
    elseif copy and npc.name ~= data.name then
        -- print('copiou npc e mudou o nome')
        -- PlaceSpawnedNPC(npc.coords, data.hash, data)
        -- return
    elseif edit and not npc.name then
        -- print('adicionou npc novo')
        PlaceSpawnedNPC(npc.coords, data.hash, data)
        return
    end
    -- print('passou do return')
    TriggerEvent("control:CreateEntity", data)
end)    

RegisterNetEvent("NPCresourceStart")
AddEventHandler("NPCresourceStart", function(list)
    hasDrawText = false
    for _, npcData in ipairs(list) do
        if npcData.useDrawText then
            hasDrawText = true
            drawString[#drawString + 1] = { label = npcData.oxTargetLabel, hash = npcData.hash } 
        end

        local npcIdentifier = npcData.name
        if not npcExists(npcIdentifier) then
            local modelHash = GetHashKey(npcData.hash)
            if not IsModelValid(modelHash) then
                print("Invalid model hash:", npcData.hash)
                goto continue
            end
            local npc = createNPC(modelHash, npcData.coords, npcData.heading, npcData.animDict, npcData.animName, npcData.scullyEmote)
            if not npc then
                print("Failed to create NPC:", npcData.hash)
                goto continue
            end
            table.insert(npcTable, {
                npc = npc,
                identifier = npcIdentifier,
            })

            options = {}
            if npcData.useOxTarget then
                local groups = nil
                if npcData.job then
                    options[#options +1] = {
                       groups = { [npcData.job] = tonumber(npcData.grade)},
                       event = npcData.event,
                       icon = "fas fa-globe",
                       label = npcData.oxTargetLabel,
                    }
                else
                    options[#options +1] = {
                        event = npcData.event,
                        icon = "fas fa-globe",
                        label = npcData.oxTargetLabel,
                     }
                end
                exports.ox_target:addBoxZone({
                    coords = vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z),
                    size = vec3(0.6, 0.6, 3.5),
                    name = "npc -" .. npcIdentifier,
                    heading = npcData.heading,
                    debug = false,
                    options = options,
                    distance = 1.5
                })
            end
            if hasDrawText == true then
                Citizen.CreateThread(function()
                    while hasDrawText do
                        Wait(0)
                        local pedC = GetEntityCoords(cache.ped)
                        local controlCode = keys[npcData.drawTextKey]
                        if #(pedC - vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z)) <= 10 then
                            local hasJobAndGrade = false
                            if QBX.PlayerData.job.name == npcData.job and QBX.PlayerData.job.grade >= tonumber(npcData.grade) then       
                                hasJobAndGrade = true
                            end

                            local isPublic = npcData.job == false and tonumber(npcData.grade) == 0
                            local isRestricted = npcData.job ~= false and tonumber(npcData.grade) ~= 0
                            
                            if isPublic or (isRestricted and hasJobAndGrade) then
                                for i = 1, #drawString do
                                    if drawString[i].label == npcData.oxTargetLabel then
                                        drawText3D(vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z + 1.2), drawString[i].label, 0.40)
                                    end
                                end
                                
                                if #(pedC - vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z)) <= 3 then
                                    if IsControlJustPressed(0, controlCode) then
                                        TriggerEvent(npcData.event)
                                    end
                                end
                            end
                        else
                            Wait(1400)
                        end
                    end
                end)
            end
        end
        ::continue::
    end
end)

lib.callback.register("npcDeleteAll", function(list)
    for _, npcData in ipairs(list) do
        deleteNPC(npcData.name)
    end
    return true
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local list = lib.callback.await("npcGetAll", false)
    TriggerEvent("NPCresourceStart", list)
end)

function npcExists(npcIdentifier)
    for _, existingNpc in ipairs(npcTable) do
        if existingNpc.name == npcIdentifier then
            return true
        end
    end
    return false
end

function deleteNPC(npcName)
    for i, npc in ipairs(npcTable) do
        if npc.identifier == npcName then
            if DoesEntityExist(npc.npc) then
                DeleteEntity(npc.npc)
            end
            table.remove(npcTable, i)
            break
        end
    end
end

function deleteAllNPC()
    for _, npc in ipairs(npcTable) do
        if DoesEntityExist(npc.npc) then
            DeleteEntity(npc.npc)
        end
    end
    npcTable = {}
end

RegisterNetEvent("deleteNPCServer")
AddEventHandler("deleteNPCServer", function(npcName)
    deleteNPC(npcName)
end)

function createNPC(modelHash, coords, heading, animDict, animName, scullyEmote)
    local npc = createPed(modelHash, coords, heading)
    if not npc then
        return nil
    end
    setupNPC(npc)
    
    if scullyEmote and scullyEmote ~= "" then
        local emoteName, variation = scullyEmote:match("(%a+)(%d*)")
        variation = tonumber(variation) or 0
        print(emoteName, variation)
        exports.scully_emotemenu:playEmoteByCommand(emoteName, variation, npc)
    elseif animDict and animDict ~= "" and animName and animName ~= "" then
        playAnimation(npc, animDict, animName)
    end
    
    return npc
end

function createPed(modelHash, coords, heading)
    lib.requestModel(modelHash, 5000)
    local npc = CreatePed(4, modelHash, coords.x, coords.y, coords.z, heading, true, true)
    if not DoesEntityExist(npc) then
        return
    end
    PlaceObjectOnGroundProperly(npc)
    SetEntityHeading(npc, heading)
    Wait(100)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetModelAsNoLongerNeeded(npc)
    return npc
end

function setupNPC(npc)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
end

function playAnimation(npc, animDict, animName)
    lib.requestAnimDict(animDict)
    TaskPlayAnim(npc, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(animDict)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        deleteAllNPC()
        exports.scully_emotemenu:clearpedsObjects()
    end
end)