-- chunkname: @/client_options/cip_import_converter.lua

CipImportConverter = {}

local function newStats()
	return {
		characterFilesTotal = 0,
		characterFolders = 0,
		characterFiles = 0,
		controlButtonsUpdated = 0,
		hotkeysIgnored = 0,
		triggerHotkeys = 0,
		customHotkeys = 0,
		keybindsMapped = 0,
		actionBarSlots = 0,
		presetsImported = 0,
		optionsIgnored = 0,
		optionsImported = 0,
		outfitBridge = 0,
		questTrackingBridge = 0,
		whitelistNames = 0,
		ignoreListNames = 0,
		sidebarsConverted = 0,
		warnings = {}
	}
end

function CipImportConverter.convertOptions(cipOptions, stats)
	stats = stats or newStats()

	local result = {}

	if type(cipOptions) ~= "table" then
		return result, stats
	end

	for cipKey, mapping in pairs(CipImportMappings.OPTION_KEYS) do
		local value = cipOptions[cipKey]

		if value ~= nil then
			if mapping.requires and not cipOptions[mapping.requires] then
				stats.optionsIgnored = stats.optionsIgnored + 1
			else
				if mapping.invert and mapping.type == "bool" then
					value = not value
				end

				result[mapping.key] = value
				stats.optionsImported = stats.optionsImported + 1
			end
		end
	end

	return result, stats
end

function CipImportConverter.convertControlButtons(controlButtonsOptions, stats)
	stats = stats or newStats()

	if type(controlButtonsOptions) ~= "table" then
		return nil, stats
	end

	local validIds = {}

	if ControlButtonNames then
		for id in pairs(ControlButtonNames) do
			validIds[id] = true
		end
	end

	local visibility = {}

	local function applyList(list, visible)
		if type(list) ~= "table" then
			return
		end

		for _, cipId in ipairs(list) do
			local otcId = CipImportMappings.CONTROL_BUTTON_IDS[cipId] or cipId

			if validIds[otcId] then
				visibility[otcId] = visible
				stats.controlButtonsUpdated = stats.controlButtonsUpdated + 1
			end
		end
	end

	applyList(controlButtonsOptions.enabledButtons, true)
	applyList(controlButtonsOptions.disabledButtons, false)

	if table.empty(visibility) then
		return nil, stats
	end

	return visibility, stats
end

function CipImportConverter.convertWhiteBlacklistOptions(whiteBlacklistOptions, stats)
	stats = stats or newStats()

	if type(whiteBlacklistOptions) ~= "table" then
		return nil, stats
	end

	local result = {
		ignore = {},
		whitelist = {}
	}

	if type(whiteBlacklistOptions.blacklistedNames) == "table" then
		for _, name in ipairs(whiteBlacklistOptions.blacklistedNames) do
			if type(name) == "string" and name ~= "" then
				table.insert(result.ignore, name)
			end
		end
	end

	if type(whiteBlacklistOptions.whitelistedNames) == "table" then
		for _, name in ipairs(whiteBlacklistOptions.whitelistedNames) do
			if type(name) == "string" and name ~= "" then
				table.insert(result.whitelist, name)
			end
		end
	end

	stats.ignoreListNames = #result.ignore
	stats.whitelistNames = #result.whitelist

	if #result.ignore == 0 and #result.whitelist == 0 then
		return nil, stats
	end

	return result, stats
end

local function mergeSlot(existing, incoming)
	if type(existing) ~= "table" then
		return incoming
	end

	for key, value in pairs(incoming) do
		existing[key] = value
	end

	return existing
end

function CipImportConverter.convertHotkeyOptions(hotkeyOptions, stats)
	stats = stats or newStats()

	local result = {
		presetOrder = {},
		presets = {}
	}

	if type(hotkeyOptions) ~= "table" then
		return result, stats
	end

	result.currentPreset = hotkeyOptions.currentHotkeySetName

	if hotkeyOptions.autoSwitchHotkeyPreset ~= nil then
		result.autoSwitchPreset = hotkeyOptions.autoSwitchHotkeyPreset
	end

	local hotkeySets = hotkeyOptions.hotkeySets

	if type(hotkeySets) ~= "table" then
		return result, stats
	end

	for presetName, presetData in pairs(hotkeySets) do
		if type(presetName) == "string" and type(presetData) == "table" then
			local preset = {
				name = presetName,
				actionBarSlots = {},
				keybinds = {},
				customHotkeys = {
					[CHAT_MODE.ON] = {},
					[CHAT_MODE.OFF] = {}
				}
			}
			local mappings = presetData.actionBarOptions and presetData.actionBarOptions.mappings

			if type(mappings) == "table" then
				for _, mapping in ipairs(mappings) do
					local barId = mapping.actionBar
					local buttonIndex = mapping.actionButton
					local slotId = CipImportMappings.slotIdFor(barId, buttonIndex)
					local slot = CipImportMappings.convertActionSettingToSlot(mapping.actionsetting)

					if slotId and slot then
						preset.actionBarSlots[slotId] = slot
						stats.actionBarSlots = stats.actionBarSlots + 1
					end
				end
			end

			local function processHotkeyList(list, chatMode)
				if type(list) ~= "table" then
					return
				end

				for _, entry in ipairs(list) do
					local key = CipImportMappings.normalizeKeySequence(entry.keysequence)
					local setting = entry.actionsetting

					if key and CipImportMappings.isValidKeyCombo(key) and type(setting) == "table" then
						if setting.action then
							local barId, buttonIndex = CipImportMappings.parseTriggerActionButton(setting.action)

							if barId and buttonIndex then
								local slotId = CipImportMappings.slotIdFor(barId, buttonIndex)

								if slotId then
									if not preset.actionBarSlots[slotId] then
										preset.actionBarSlots[slotId] = {}
									end

									if chatMode == CHAT_MODE.OFF then
										preset.actionBarSlots[slotId].hotkeyChatOff = key
									else
										preset.actionBarSlots[slotId].hotkeyChatOn = key
									end

									stats.triggerHotkeys = stats.triggerHotkeys + 1
								end
							else
								local actionKind, payload = CipImportMappings.convertActionSettingToHotkey(setting)

								if actionKind == "keybind" and payload then
									table.insert(preset.keybinds, {
										category = payload[1],
										action = payload[2],
										key = key,
										chatMode = chatMode
									})

									stats.keybindsMapped = stats.keybindsMapped + 1
								else
									stats.hotkeysIgnored = stats.hotkeysIgnored + 1
								end
							end
						else
							local actionKind, payload = CipImportMappings.convertActionSettingToHotkey(setting)

							if actionKind == "keybind" and payload then
								table.insert(preset.keybinds, {
									category = payload[1],
									action = payload[2],
									key = key,
									chatMode = chatMode
								})

								stats.keybindsMapped = stats.keybindsMapped + 1
							elseif actionKind and payload then
								table.insert(preset.customHotkeys[chatMode], {
									action = actionKind,
									data = payload,
									primary = key
								})

								stats.customHotkeys = stats.customHotkeys + 1
							else
								stats.hotkeysIgnored = stats.hotkeysIgnored + 1
							end
						end
					end
				end
			end

			processHotkeyList(presetData.chatOff, CHAT_MODE.OFF)
			processHotkeyList(presetData.chatOn, CHAT_MODE.ON)

			result.presets[presetName] = preset

			table.insert(result.presetOrder, presetName)

			stats.presetsImported = stats.presetsImported + 1
		end
	end

	return result, stats
end

function CipImportConverter.convertCharacterData(characterData, stats)
	stats = stats or newStats()

	if type(characterData) ~= "table" then
		return nil, stats
	end

	local result = {}

	for fileName, data in pairs(characterData) do
		if type(data) == "table" then
			result[fileName] = data
			stats.characterFiles = stats.characterFiles + 1
		end
	end

	return result, stats
end

function CipImportConverter.convertAllCharacterData(allCharacterData, stats)
	stats = stats or newStats()

	local charactersById = {}

	if type(allCharacterData) ~= "table" then
		return charactersById, stats
	end

	for id, charData in pairs(allCharacterData) do
		if type(charData) == "table" and not table.empty(charData) then
			local files = {}
			local charMiniWindows

			for fileName, data in pairs(charData) do
				if type(data) == "table" then
					if fileName == "sidebars.json" then
						charMiniWindows = CipImportMappings.convertSidebarsToCharMiniWindows(data)
						files[fileName] = data

						if charMiniWindows and not table.empty(charMiniWindows) then
							stats.sidebarsConverted = stats.sidebarsConverted + 1
						end
					elseif fileName == "questtracking.json" then
						files[fileName] = data
						stats.characterFilesTotal = stats.characterFilesTotal + 1

						if CipImportMappings.convertQuestTrackingToOtClient(data, nil) then
							stats.questTrackingBridge = stats.questTrackingBridge + 1
						end
					elseif fileName == "outfitdialog.json" then
						files[fileName] = data
						stats.characterFilesTotal = stats.characterFilesTotal + 1

						if CipImportMappings.convertOutfitDialogToOtClient(data) then
							stats.outfitBridge = stats.outfitBridge + 1
						end
					else
						files[fileName] = data
						stats.characterFilesTotal = stats.characterFilesTotal + 1
					end
				end
			end

			if not table.empty(files) then
				charactersById[id] = {
					files = files,
					charMiniWindows = charMiniWindows
				}
				stats.characterFolders = stats.characterFolders + 1
			end
		end
	end

	return charactersById, stats
end

function CipImportConverter.convertBackup(backup)
	local stats = newStats()

	if not backup or not backup.clientOptions then
		return nil, stats
	end

	local clientOptions = backup.clientOptions
	local options, stats = CipImportConverter.convertOptions(clientOptions.options, stats)
	local controlButtons, stats = CipImportConverter.convertControlButtons(clientOptions.controlButtonsOptions, stats)
	local hotkeys, stats = CipImportConverter.convertHotkeyOptions(clientOptions.hotkeyOptions, stats)
	local ignoreList, stats = CipImportConverter.convertWhiteBlacklistOptions(clientOptions.whiteBlacklistOptions, stats)
	local charactersById, stats = CipImportConverter.convertAllCharacterData(backup.allCharacterData, stats)

	return {
		version = backup.version,
		options = options,
		controlButtons = controlButtons,
		hotkeys = hotkeys,
		ignoreList = ignoreList,
		charactersById = charactersById,
		playerId = backup.playerId,
		characterFound = backup.characterFound,
		characterIds = backup.characterIds,
		stats = stats
	}, stats
end

function CipImportConverter.buildPreviewText(converted, stats)
	if not converted then
		return tr("No compatible settings found.")
	end

	local lines = {
		tr("CIP client options version: %s", tostring(converted.version or "?")),
		tr("Global options to import: %s", tostring(stats.optionsImported or 0)),
		tr("Hotkey presets: %s", tostring(stats.presetsImported or 0)),
		tr("Action bar slots: %s", tostring(stats.actionBarSlots or 0)),
		tr("General hotkeys: %s", tostring(stats.keybindsMapped or 0)),
		tr("Custom hotkeys: %s", tostring(stats.customHotkeys or 0)),
		tr("Slot hotkeys: %s", tostring(stats.triggerHotkeys or 0)),
		tr("Control buttons updated: %s", tostring(stats.controlButtonsUpdated or 0)),
		tr("Ignore list names: %s", tostring(stats.ignoreListNames or 0)),
		tr("Whitelist names: %s", tostring(stats.whitelistNames or 0)),
		tr("Character folders: %s", tostring(stats.characterFolders or 0)),
		tr("Character files: %s", tostring(stats.characterFilesTotal or 0)),
		tr("Sidebars converted: %s", tostring(stats.sidebarsConverted or 0)),
		tr("Quest tracker options (apply on login): %s", tostring(stats.questTrackingBridge or 0)),
		tr("Outfit presets from CIP (apply on login): %s", tostring(stats.outfitBridge or 0)),
		tr("Ignored entries: %s", tostring(stats.hotkeysIgnored + stats.optionsIgnored)),
		"",
		tr("PTC-only settings preserved (not modified):")
	}
	local preserved = CipImportMappings.OTCLIENT_PRESERVED_SETTINGS or {
		"game_helper_data.json",
		"outfit.json",
		"questtracking.json",
		"npc_modal.json"
	}

	for _, fileName in ipairs(preserved) do
		table.insert(lines, "  - /settings/" .. fileName)
	end

	table.insert(lines, tr("  - /settings/{character}_containers.json (Quick Loot)"))
	table.insert(lines, tr("  - Helper module uses game_helper_data.json (not helper.json)"))
	table.insert(lines, "")
	table.insert(lines, tr("Legacy files removed after import:"))
	table.insert(lines, tr("  - /settings/*_actionbar.json"))
	table.insert(lines, tr("  - config.otml game_actionbar node"))

	if converted.playerId then
		if converted.characterFound then
			table.insert(lines, tr("Logged-in character %s: found in backup", converted.playerId))
		else
			table.insert(lines, tr("Logged-in character %s: not in backup (global import only)", converted.playerId))
		end
	else
		table.insert(lines, tr("Not logged in: character layout applies on login when ID matches"))
	end

	return table.concat(lines, "\n")
end
