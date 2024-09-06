keys = {
    ["ESCAPE"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["TILDE"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["MINUS"] = 84, ["EQUALS"] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["LEFT_BRACKET"] = 39, ["RIGHT_BRACKET"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFT_SHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFT_CTRL"] = 36, ["LEFT_ALT"] = 19, ["SPACE"] = 22, ["RIGHT_CTRL"] = 70,
    ["HOME"] = 213, ["PAGE_UP"] = 10, ["PAGE_DOWN"] = 11, ["DELETE"] = 178,
    ["LEFT_ARROW"] = 174, ["RIGHT_ARROW"] = 175, ["UP_ARROW"] = 27, ["DOWN_ARROW"] = 173,
    ["NUM_ENTER"] = 201, ["NUM4"] = 108, ["NUM5"] = 60, ["NUM6"] = 107, ["NUM_PLUS"] = 96, ["NUM_MINUS"] = 97, ["NUM7"] = 117, ["NUM8"] = 61, ["NUM9"] = 118
}

local IsPlacingNPC = false
local previewedNPC = nil
local heading = 0

AddEventHandler("control:CreateEntity", function(data)
    if IsPlacingNPC then return end
    CreateNPC(data.hash, data)
end)

-- Carregar lista de animações de diferentes categorias
local AnimationList = {
    Emotes = require('@scully_emotemenu.data.animations.emotes'),
    DanceEmotes = require('@scully_emotemenu.data.animations.dance_emotes'),
    Scenarios = require('@scully_emotemenu.data.animations.scenarios'),
    AnimalEmotes = require('@scully_emotemenu.data.animations.animal_emotes')
}

local categories = { 
    "Emotes", 
    "DanceEmotes", 
    "Scenarios", 
    "AnimalEmotes" }

local currentCategoryIndex = 1
local currentEmoteIndex = 1
local currentPedIndex = 1
local heading = 0
local IsSelectingPed = false

function SelectPedModelForMenu(callback)
    IsSelectingPed = true

    -- Função auxiliar para mudar o modelo de NPC
    local function ChangeNPCModel(index)
        local modelHash = PedModels[index][1]
        local modelName = PedModels[index][3]

        lib.requestModel(modelHash)

        if DoesEntityExist(previewedNPC) then
            DeleteEntity(previewedNPC)
        end

        -- Criação temporária do ped para pré-visualização
        previewedNPC = CreatePed(4, modelHash, GetEntityCoords(cache.ped), heading, false, true)

        SetEntityAlpha(previewedNPC, 255, false)
        SetEntityCollision(previewedNPC, false, false)
        FreezeEntityPosition(previewedNPC, true)
        SetEntityInvincible(previewedNPC, true)
        SetBlockingOfNonTemporaryEvents(previewedNPC, true)

        -- Aplicar a animação ao NPC
        local category = categories[currentCategoryIndex]
        local selectedEmote = AnimationList[category][currentEmoteIndex]
        exports.scully_emotemenu:playEmoteByCommand(selectedEmote.Command, nil, previewedNPC)

        -- Mostrar informações na tela
        lib.showTextUI(
            '[E] Confirmar Modelo  \n[Q] Cancelar  \n [⬅/⮕] Girar Esquerda/Direita  \n Setas: ' .. selectedEmote.Label .. ' (' .. modelName .. ')  \n Page Up/Down: ' .. category, {
                position = "right-center",
            })
    end

    -- Inicializa com o primeiro ped da lista e a primeira animação na primeira categoria
    ChangeNPCModel(currentPedIndex)

    while IsSelectingPed do
        local hit, _, coords, _, _ = lib.raycast.cam(1, 4)

        if hit then
            SetEntityCoords(previewedNPC, coords.x, coords.y, coords.z)
            PlaceObjectOnGroundProperly(previewedNPC)

            -- Girar NPC com setas laterais
            if IsControlPressed(0, 174) then -- seta esquerda
                heading = heading - 1.0
                SetEntityHeading(previewedNPC, heading)
            end

            if IsControlPressed(0, 175) then -- seta direita
                heading = heading + 1.0
                SetEntityHeading(previewedNPC, heading)
            end

            -- Alternar entre as animações dentro da categoria com as setas para cima e para baixo
            if IsControlJustPressed(0, 172) then -- seta para cima
                currentEmoteIndex = currentEmoteIndex + 1
                if currentEmoteIndex > #AnimationList[categories[currentCategoryIndex]] then
                    currentEmoteIndex = 1
                end
                exports.scully_emotemenu:playEmoteByCommand(AnimationList[categories[currentCategoryIndex]][currentEmoteIndex].Command, nil, previewedNPC)
                ChangeNPCModel(currentPedIndex)  -- Atualiza o texto da animação na tela
            end

            if IsControlJustPressed(0, 173) then -- seta para baixo
                currentEmoteIndex = currentEmoteIndex - 1
                if currentEmoteIndex < 1 then
                    currentEmoteIndex = #AnimationList[categories[currentCategoryIndex]]
                end
                exports.scully_emotemenu:playEmoteByCommand(AnimationList[categories[currentCategoryIndex]][currentEmoteIndex].Command, nil, previewedNPC)
                ChangeNPCModel(currentPedIndex)  -- Atualiza o texto da animação na tela
            end

            -- Alternar entre categorias usando Page Up e Page Down
            if IsControlJustPressed(0, 10) then -- Page Up
                currentCategoryIndex = currentCategoryIndex + 1
                if currentCategoryIndex > #categories then
                    currentCategoryIndex = 1
                end
                currentEmoteIndex = 1  -- Reseta o índice de animação ao trocar de categoria
                exports.scully_emotemenu:playEmoteByCommand(AnimationList[categories[currentCategoryIndex]][currentEmoteIndex].Command, nil, previewedNPC)
                ChangeNPCModel(currentPedIndex)
            end

            if IsControlJustPressed(0, 11) then -- Page Down
                currentCategoryIndex = currentCategoryIndex - 1
                if currentCategoryIndex < 1 then
                    currentCategoryIndex = #categories
                end
                currentEmoteIndex = 1  -- Reseta o índice de animação ao trocar de categoria
                exports.scully_emotemenu:playEmoteByCommand(AnimationList[categories[currentCategoryIndex]][currentEmoteIndex].Command, nil, previewedNPC)
                ChangeNPCModel(currentPedIndex)
            end

            -- Rolar para cima e para baixo para trocar o modelo de ped
            if IsControlJustPressed(0, 241) then -- Scroll up
                currentPedIndex = currentPedIndex + 1
                if currentPedIndex > #PedModels then currentPedIndex = 1 end
                ChangeNPCModel(currentPedIndex)
            end

            if IsControlJustPressed(0, 242) then -- Scroll down
                currentPedIndex = currentPedIndex - 1
                if currentPedIndex < 1 then currentPedIndex = #PedModels end
                ChangeNPCModel(currentPedIndex)
            end

            -- Confirmar seleção do ped com E
            if IsControlJustPressed(0, 38) then
                local selectedPed = {
                    hash = PedModels[currentPedIndex][2],
                    coords = coords,
                    heading = heading,
                    -- Animação selecionada
                    scullyEmote = AnimationList[categories[currentCategoryIndex]][currentEmoteIndex].Command
                }
                IsSelectingPed = false
                lib.hideTextUI()

                -- Chamar o callback para o menu com as informações selecionadas
                if callback then
                    callback(selectedPed)
                end
            end

            -- Cancelar seleção com Q
            if IsControlJustPressed(0, 44) then
                IsSelectingPed = false
                DeleteEntity(previewedNPC)
                lib.hideTextUI()
            end
        end
        Citizen.Wait(0)
    end
end




function CreateNPC(model, stored)
    IsPlacingNPC = true
    lib.requestModel(model)

    previewedNPC = CreatePed(4, model, GetEntityCoords(cache.ped), heading, false, true)

    SetEntityAlpha(previewedNPC, 150, false)
    SetEntityCollision(previewedNPC, false, false)
    FreezeEntityPosition(previewedNPC, true)
    SetEntityInvincible(previewedNPC, true)
    SetBlockingOfNonTemporaryEvents(previewedNPC, true)
    lib.showTextUI(
        '[E] Colocar NPC  \n [Q] Sair  \n [⬅/⮕] Girar Esquerda/Direita  ', {
            position = "right-center",
        })
    
    while IsPlacingNPC do
        local hit, _, coords, _, _ = lib.raycast.cam(1, 4)

        if hit then
            SetEntityCoords(previewedNPC, coords.x, coords.y, coords.z)
            PlaceObjectOnGroundProperly(previewedNPC)
            local distanceCheck = #(coords - GetEntityCoords(cache.ped))

            if IsControlJustPressed(0, 44) then CancelPlacement() end

            if IsControlPressed(0, 174) then -- left arrow
                heading = heading - 1.0
                SetEntityHeading(previewedNPC, heading)
            end

            if IsControlPressed(0, 175) then -- right arrow
                heading = heading + 1.0
                SetEntityHeading(previewedNPC, heading)
            end

            if IsControlJustPressed(0, 38) then
                PlaceSpawnedNPC(coords, model, stored)
            end
        end
        Wait(0)
    end
end

function PlaceSpawnedNPC(coords, model, stored)
    lib.hideTextUI()
    IsPlacingNPC = false
    DeleteEntity(previewedNPC)
    print("Placing NPC: ", model, coords, heading)
    TriggerServerEvent("insertData", coords, model, stored, heading)
end

function CancelPlacement()
    if previewedNPC then
        DeleteEntity(previewedNPC)
        previewedNPC = nil
    end
    IsPlacingNPC = false
    lib.hideTextUI()
end

function drawText3D(coords, text, scale2, r, g, b, a)
    local processedText = text:gsub("\\n", "\n")
    local camCoords = GetGameplayCamCoord()
    local dist = #(coords - camCoords)
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local textScale = scale * fov * scale2

    SetTextScale(0.40, textScale)
    SetTextFont(6)
    SetTextProportional(1)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextDropShadow()
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(processedText)
    SetDrawOrigin(coords.x, coords.y, coords.z+0.65, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end
