local npcTable = {}
local keyOptions = {}
local sortedKeys = {}
local drawString = {}
local showText = false
QBCore = exports["qb-core"]:GetCoreObject()

lib.callback.register("mri_Qnpc:client:npcMenuList", function()
	npcMenuList()
end)

function npcMenuList()
	local options = {{
		title = "Criar NPC",
		icon = "arrows-up-down",
		onSelect = function()
			SelectPedModelForMenu(function(npc)
				if npc then
					TriggerEvent("npcCreationOrEditMenu", "edit", npc)
				end
			end)
		end,
	}}
	options[#options + 1] = {
		progress = 0,
	}
	local npc = lib.callback.await("npcGetAll", false)
	if npc then
		for i = 1, #npc do
			options[#options + 1] = {
				title = npc[i].name,
				icon = "user",
				onSelect = function()
					local options = {}
					options[#options + 1] = {
						title = "Editar",
						icon = "edit",
						onSelect = function()
							TriggerEvent("npcCreationOrEditMenu", "edit", npc[i], npcMenuList)
						end,
					}
					options[#options + 1] = {
						title = "Criar cópia",
						icon = "copy",
						onSelect = function()
							TriggerEvent("npcCreationOrEditMenu", "copy", npc[i])
						end,
					}
					options[#options + 1] = {
						title = "Teleportar",
						icon = "marker",
						onSelect = function()
							SetEntityCoords(cache.ped, npc[i].coords.x, npc[i].coords.y, npc[i].coords.z)
						end,
					}
					options[#options + 1] = {
						title = "Interação talkNPC",
						icon = "comments",
						onSelect = function()
							configureTalkNPC(npc[i])
						end,
					}
					options[#options + 1] = {
						title = "Deletar",
						icon = "trash",
						iconColor = "red",
						onSelect = function()
							TriggerServerEvent("npcDelete", npc[i].name)
						end,
					}
					lib.registerContext({
						id = "npc_edit",
						title = npc[i].name,
						menu = "npc_create",
						options = options,
					})
					lib.showContext("npc_edit")
				end,
			}
		end
	end
	lib.registerContext({
		id = "npc_create",
		title = "Criador de NPC",
		menu = "menu_gerencial",
		options = options,
	})
	lib.showContext("npc_create")
end

function configureTalkNPC(npc)
	local dialogs = npc.npcDialog or {}
	if #dialogs == 0 then
		local input = lib.inputDialog("Criar Mensagem Principal", {
			{
				type = "textarea",
				label = "Texto da Mensagem Principal",
				description = "Digite a mensagem inicial do NPC.",
			},
		})
		if input then
			local newDialog = {
				label = input[1] or "Mensagem Principal",
				options = {},
			}
			table.insert(dialogs, newDialog)
			npc.npcDialog = dialogs
			PlaceSpawnedNPC(npc.coords, npc.hash, npc)
		else
			return
		end
	end
	configureDialogTalk(npc, 1)
end

function configureDialogTalk(npc, dialogIndex)
	local dialog = npc.npcDialog[dialogIndex] or {}
	local options = {}

    -- Alterar Tag do NPC
    options[#options + 1] = {
        title = "Alterar Tag do NPC",
        description = dialog.tag and ("Tag atual: %s"):format(dialog.tag) or "Tag atual: Nenhuma",
        icon = "edit",
        onSelect = function()
            local input = lib.inputDialog("Alterar Tag do NPC", {
                {
                    type = "textarea",
                    label = "Nova Tag",
                    description = "Insira a nova tag do NPC.",
                    default = dialog.tag or "",
                },
            })
            if input then
                dialog.tag = input[1] or dialog.tag
                npc.npcDialog[dialogIndex] = dialog
                PlaceSpawnedNPC(npc.coords, npc.hash, npc)
            end
            configureDialogTalk(npc, dialogIndex)
        end,
    }

	options[#options + 1] = {
		title = "Alterar Fala do NPC",
		description = dialog.label and ("Fala atual: %s"):format(dialog.label) or "Fala atual: Nenhuma",
		icon = "edit",
		onSelect = function()
			local input = lib.inputDialog("Alterar Mensagem Principal", {
				{
					type = "textarea",
					label = "Nova Mensagem",
					description = "Insira o novo texto do diálogo.",
					default = dialog and dialog.label or "",
				},
			})
			if input then
				dialog.label = input[1] or dialog.label
				npc.npcDialog[dialogIndex] = dialog
				PlaceSpawnedNPC(npc.coords, npc.hash, npc)
			end
			configureDialogTalk(npc, dialogIndex)
		end,
	}

    if dialog.options then
        for optIndex, option in ipairs(dialog.options) do
            options[#options + 1] = {
                title = ("Resposta %02d:"):format(optIndex),
                description = option.label,
                icon = "comments",
                onSelect = function()
                    configureDialogAnswer(npc, dialogIndex, optIndex)
                end,
            }
        end
    end

	-- Adicionar nova opção ao diálogo
	if dialog and not dialog.options or #dialog.options < 4 then
		options[#options + 1] = {
			title = "Adicionar Nova Resposta",
			icon = "fa-solid fa-plus",
			onSelect = function()
				local input = lib.inputDialog("Adicionar Nova Resposta", {
					{ type = "textarea", label = "Texto da Resposta", description = "Texto para a nova opção." },
				})
				if input then
                    if not dialog.options then dialog.options = {} end
					table.insert(dialog.options, {
						label = input[1] or "Nova Resposta",
						shouldClose = true,
					})
					npc.npcDialog[dialogIndex] = dialog
					PlaceSpawnedNPC(npc.coords, npc.hash, npc)
				end
				-- Reabrir o mesmo menu após adicionar nova opção
				configureDialogTalk(npc, dialogIndex)
			end,
		}
	end

	-- Adiciona opção de excluir
	options[#options + 1] = {
		title = "Excluir Diálogo",
		icon = "trash",
		iconColor = "red",
		onSelect = function()
			table.remove(npc.npcDialog, dialogIndex)
			PlaceSpawnedNPC(npc.coords, npc.hash, npc)
		end,
	}

	lib.registerContext({
		id = "dialog_options_menu_" .. dialogIndex,
		title = ("Diálogo - %02d"):format(dialogIndex),
		menu = "npc_edit",
		options = options,
	})

	lib.showContext("dialog_options_menu_" .. dialogIndex)
end

function configureDialogAnswer(npc, dialogIndex, optIndex)
	local dialog = npc.npcDialog[dialogIndex]
	local option = dialog.options[optIndex]

	local options = {
		{
			title = "Alterar Resposta",
			description = ("Resposta atual: %s"):format(option.label),
			icon = "edit",
			onSelect = function()
				local input = lib.inputDialog("Editar Resposta", {
					{
						type = "textarea",
						label = "Texto da Resposta",
						description = "Insira o novo texto da opção.",
						default = option.label,
					},
				})
				if input then
					option.label = input[1] or option.label
					dialog.options[optIndex] = option
					npc.npcDialog[dialogIndex] = dialog
					PlaceSpawnedNPC(npc.coords, npc.hash, npc)
				end
				-- Reabrir o mesmo submenu após alteração
				configureDialogAnswer(npc, dialogIndex, optIndex)
			end,
		},
	}

	-- Adicionar opção de definir Tipo de Interação
	options[#options + 1] = {
		title = "Definir Tipo de Interação",
		description = ("Tipo atual: %s"):format(option.interactionType or "close"),
		icon = "exchange-alt",
		onSelect = function()
			local interactionType = lib.inputDialog("Definir Tipo de Interação", {
				{
					type = "select",
					label = "Tipo de Interação",
					options = {
						{ label = "Fechar", value = "close" },
						{ label = "Comando", value = "command" },
						{ label = "Diálogo", value = "dialog" },
                        { label = "Localização", value = "location" },
					},
					default = option.interactionType or "close",
				},
			})
			if interactionType then
				option.interactionType = interactionType[1]
				option.shouldClose = option.interactionType == "close"
				dialog.options[optIndex] = option
				npc.npcDialog[dialogIndex] = dialog
				PlaceSpawnedNPC(npc.coords, npc.hash, npc)
			end
			-- Reabrir o mesmo submenu depois de definir o tipo de interação
			configureDialogAnswer(npc, dialogIndex, optIndex)
		end,
	}

	if option.interactionType == "dialog" then
		-- Adicionar opção de editar diálogo
		options[#options + 1] = {
			title = "Editar Diálogo",
			icon = "comments",
			onSelect = function()
				configureDialogTalk(npc, dialogIndex+1)
			end,
		}
	end

	if option.interactionType == "command" then
		-- Adicionar opção de editar comando
		options[#options + 1] = {
			title = "Editar Comando",
            description = ("Comando atual: /%s"):format(option.command),
			icon = "edit",
			onSelect = function()
				local input = lib.inputDialog("Editar Comando", {
					{
						type = "input",
						label = "Novo Comando",
						description = "Insira o novo comando.",
						default = option.command,
					},
				})
				if input then
					option.command = input[1] or option.command
                    option.shouldClose = true
					dialog.options[optIndex] = option
					npc.npcDialog[dialogIndex] = dialog
					PlaceSpawnedNPC(npc.coords, npc.hash, npc)
				end
				-- Reabrir o mesmo submenu depois de editar o comando
				configureDialogAnswer(npc, dialogIndex, optIndex)
			end,
		}
	end

    if option.interactionType == "location" then
        -- Adicionar opção de editar localização
        options[#options + 1] = {
            title = "Editar Localização",
            description = ("Localização atual: %s"):format(option.locations),
            icon = "edit",
            onSelect = function()
                -- Define a coordenada da localização
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
 
                option.locations = coords
                option.action = ('function() SetNewWaypoint(%f, %f) end'):format(coords.x, coords.y)
                option.shouldClose = true
                dialog.options[optIndex] = option
                npc.npcDialog[dialogIndex] = dialog
                PlaceSpawnedNPC(npc.coords, npc.hash, npc)

                -- Reabrir o mesmo submenu depois de editar a localização
                configureDialogAnswer(npc, dialogIndex, optIndex)
            end,
        }
    end

	lib.registerContext({
		id = "suboption_menu_" .. dialogIndex .. "_" .. optIndex,
		title = ("Diálogo - %02d_%02d"):format(dialogIndex, optIndex),
		menu = "dialog_options_menu_" .. dialogIndex,
		options = options,
	})

	lib.showContext("suboption_menu_" .. dialogIndex .. "_" .. optIndex)
end

function openDialogSubmenuForSubOption(npc, dialogIndex, optIndex, subIndex)
	local dialog = npc.npcDialog[dialogIndex]
	local option = dialog.options[optIndex]
	local subOption = option.subOptions[subIndex]

	-- Opções para editar a subopção
	local options = {
		{
			title = "Alterar Mensagem da Subopção",
			icon = "edit",
			onSelect = function()
				local input = lib.inputDialog("Editar Subopção", {
					{
						type = "textarea",
						label = "Texto da Subopção",
						description = "Insira o novo texto da subopção.",
						default = subOption.label,
					},
				})
				if input then
					subOption.label = input[1] or subOption.label
					option.subOptions[subIndex] = subOption
					dialog.options[optIndex] = option
					npc.npcDialog[dialogIndex] = dialog
					PlaceSpawnedNPC(npc.coords, npc.hash, npc)
				end
				-- Reabrir o mesmo submenu após a alteração
				openDialogSubmenuForSubOption(npc, dialogIndex, optIndex, subIndex)
			end,
		},
	}

	-- Permitir adicionar mais subopções aninhadas (se necessário)
	if subOption.subOptions and #subOption.subOptions < 4 or not subOption.subOptions then
		options[#options + 1] = {
			title = "Adicionar Nova Subopção",
			icon = "fa-solid fa-plus",
			onSelect = function()
				local input = lib.inputDialog("Adicionar Nova Subopção", {
					{
						type = "textarea",
						label = "Texto da Nova Subopção",
						description = "Texto para a nova subopção.",
					},
				})
				if input then
					subOption.subOptions = subOption.subOptions or {}
					table.insert(subOption.subOptions, {
						label = input[1] or "Nova Subopção",
						shouldClose = false,
						action = function()
							print("Ação para a nova subopção.")
						end,
					})
					option.subOptions[subIndex] = subOption
					dialog.options[optIndex] = option
					npc.npcDialog[dialogIndex] = dialog
					PlaceSpawnedNPC(npc.coords, npc.hash, npc)
				end
				-- Reabrir o mesmo submenu após adicionar nova subopção
				openDialogSubmenuForSubOption(npc, dialogIndex, optIndex, subIndex)
			end,
		}
	end

	lib.registerContext({
		id = "suboption_menu_" .. dialogIndex .. "_" .. optIndex .. "_" .. subIndex,
		title = "Configurar 3º Grau - " .. subOption.label,
		menu = "suboption_menu_" .. dialogIndex .. "_" .. optIndex,
		options = options,
	})

	lib.showContext("suboption_menu_" .. dialogIndex .. "_" .. optIndex .. "_" .. subIndex)
end

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
	local npc = CreatePed(4, modelHash, coords.x, coords.y, coords.z, heading, false, true)
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

-------------------------------------------------
-- Events ---------------------------------------
-------------------------------------------------

AddEventHandler("onResourceStop", function(resourceName)
	if resourceName == GetCurrentResourceName() then
		deleteAllNPC()
		exports.scully_emotemenu:clearpedsObjects()
	end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
	local list = lib.callback.await("npcGetAll", false)
	TriggerEvent("NPCresourceStart", list)
end)

RegisterNetEvent("deleteNPCServer", function(npcName)
	deleteNPC(npcName)
end)

RegisterNetEvent("npcCreationOrEditMenu", function(menu, npc, cb)
	local status = menu == "edit" or menu == "copy"
	local edit = menu == "edit" and true or false
	local copy = menu == "copy" and true or false
	local npcRandomName = "npc-" .. math.random(1000, 9999)
	print(edit, json.encode(npc))
	for key, _ in pairs(keys) do
		table.insert(sortedKeys, key)
	end
	table.sort(sortedKeys)
	for _, key in ipairs(sortedKeys) do
		local code = keys[key]
		table.insert(keyOptions, { value = tostring(code), label = key })
	end

	local input = lib.inputDialog(edit and "Edição de NPC" or "Criação de NPC", {
		{
			type = "input",
			label = "Nome do NPC",
			description = "Utilize nomes diferentes ou não irá funcionar.",
			required = true,
			default = status and (copy and npc.name .. " copy" or npc.name) or "",
		}, --1
		{
			type = "input",
			label = "Hash do NPC",
			description = "Insira o hash do modelo do NPC.",
			required = true,
			default = status and npc.hash or "",
		}, --2
		{
			type = "input",
			label = "Evento",
			description = "O evento acionado após interagir com o NPC.",
			default = status and npc.event or "",
		}, --3
		{
			type = "input",
			placeholder = "animDict",
			description = "O dicionário de animações para o NPC.",
			default = status and npc.animDict or "",
		}, --4
		{
			type = "input",
			placeholder = "animName",
			description = "O nome da animação para o NPC.",
			default = status and npc.animName or "",
		}, --5
		{
			type = "checkbox",
			label = "Usar TARGET",
			description = "Ativar opções avançadas de interação com ox_target.",
			default = status and npc.useOxTarget or false,
		}, --6
		{
			type = "checkbox",
			label = "Usar TEXTO",
			description = "Exibir texto acima do NPC usando drawText.",
			default = status and npc.useDrawText or false,
		}, --7
		{
			type = "input",
			placeholder = "Grupo de trabalho",
			description = "Especifique o grupo de trabalho para restringir a interação. Deixe em branco para acesso irrestrito.",
			default = status and npc.job or "",
		}, --8
		{
			type = "input",
			label = "Grau",
			description = "Especifique o grau necessário para o grupo de trabalho.",
			default = status and npc.grade or "",
		}, --9
		{
			type = "textarea",
			label = "Rótulo",
			description = "Rótulo para ox target/drawtext.",
			default = status and npc.oxTargetLabel or "",
		}, --10
		{
			type = "select",
			label = "Tecla de Menu",
			options = keyOptions,
			searchable = true,
			description = "A tecla para abrir o menu se drawText estiver ativado, deixe em branco para a tecla padrão [E]",
			default = status and npc.drawTextKey or "",
		}, --11
		{
			type = "input",
			label = "Scully Emote",
			description = "Insira o emote para o NPC (exemplo: weld). Deixe em branco para usar a Animação de cima.",
			default = status and npc.scullyEmote or "",
		}, --12
	})

	if not input then
		if npc then
			CancelPlacement()
		end
        cb()
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
		TriggerServerEvent("npcDelete", npc.name)
	elseif copy and npc.name ~= data.name then
		-- print('copiou npc e mudou o nome')
		-- PlaceSpawnedNPC(npc.coords, data.hash, data)
		-- return
	elseif edit and not npc.name then
		PlaceSpawnedNPC(npc.coords, data.hash, data)
		return
	end
	TriggerEvent("control:CreateEntity", data)
end)

RegisterNetEvent("NPCresourceStart", function(list)
	hasDrawText = false
	for _, npcData in ipairs(list) do
		-- Cria o NPC com os diálogos previamente configurados
		if npcData.npcDialog and #npcData.npcDialog > 0 and GetResourceState("rep-talkNPC") == "started" then
			local npcIdentifier = npcData.name
			if not npcExists(npcIdentifier) then
				local modelHash = GetHashKey(npcData.hash)
				if not IsModelValid(modelHash) then
					print("Invalid model hash:", npcData.hash)
					goto continue
				end

				local options = {}
				for _, option in ipairs(npcData.npcDialog[1].options) do

					-- Verifica se a ação é uma string e tenta restaurá-la como função

                    if not option.interactionType or option.interactionType == "close" then
                        option.action = function()
                        end
                        option.shouldClose = true
                    elseif option.interactionType == "command" then
                        option.action = function()
                            ExecuteCommand(option.command)
                        end
                        option.shouldClose = true
                    elseif option.interactionType == "dialog" then
                        option.action = function()
                            local options = {}
                            exports['rep-talkNPC']:changeDialog(npcData.npcDialog[2].label, npcData.npcDialog[2].options)
                        end
                        option.shouldClose = false
                    elseif option.interactionType == "location" then
                        option.action = function()
                            SetNewWaypoint(option.locations.x, option.locations.y)
                        end
                        option.shouldClose = true
                    end

					options[#options + 1] = {
						label = option.label,
						shouldClose = option.shouldClose,
						action = option.action,
					}
				end

				local npc = exports["rep-talkNPC"]:CreateNPC({
					npc = npcData.hash,
					coords = npcData.coords,
					name = npcData.name,
					startMSG = npcData.npcDialog[1].label, -- Mensagem inicial
					tag = npcData.npcDialog[1].tag or "NPC",
					color = "green.7",
				}, options)

				if not npc then
					print("Failed to create NPC:", npcData.hash)
					goto continue
				end

				table.insert(npcTable, {
					npc = npc,
					identifier = npcIdentifier,
				})

				if npcData.scullyEmote and npcData.scullyEmote ~= "" then
					local emoteName, variation = npcData.scullyEmote:match("(%a+)(%d*)")
					variation = tonumber(variation) or 0
					print(emoteName, variation)
					exports.scully_emotemenu:playEmoteByCommand(emoteName, variation, npc)
				elseif npcData.animDict and npcData.animDict ~= "" and npcData.animName and npcData.animName ~= "" then
					playAnimation(npc, npcData.animDict, npcData.animName)
				end
			end
			goto continue
		else
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
				local npc = createNPC(
					modelHash,
					npcData.coords,
					npcData.heading,
					npcData.animDict,
					npcData.animName,
					npcData.scullyEmote
				)
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
						options[#options + 1] = {
							groups = { [npcData.job] = tonumber(npcData.grade) },
							event = npcData.event,
							icon = "fas fa-globe",
							label = npcData.oxTargetLabel,
						}
					else
						options[#options + 1] = {
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
						distance = 1.5,
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
								if
									QBX.PlayerData.job.name == npcData.job
									and QBX.PlayerData.job.grade >= tonumber(npcData.grade)
								then
									hasJobAndGrade = true
								end

								local isPublic = npcData.job == false and tonumber(npcData.grade) == 0
								local isRestricted = npcData.job ~= false and tonumber(npcData.grade) ~= 0

								if isPublic or (isRestricted and hasJobAndGrade) then
									for i = 1, #drawString do
										if drawString[i].label == npcData.oxTargetLabel then
											drawText3D(
												vec3(npcData.coords.x, npcData.coords.y, npcData.coords.z + 1.2),
												drawString[i].label,
												0.40
											)
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
