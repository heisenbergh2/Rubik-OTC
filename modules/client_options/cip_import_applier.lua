-- chunkname: @/client_options/cip_import_applier.lua

CipImportApplier = {}

local EMPTY_HOTKEYS_OTML = "1:\n2:\n"
local SKIP_SESSION_SAVE_KEY = "cip_import_skip_session_save"
local GLOBAL_ACTIONBAR_FILE = "/settings/actionbar_presets.json"
local LEGACY_MIGRATION_FLAG = "/settings/.actionbar_presets_migrated"
local QUEST_TRACKING_FILE = "/settings/questtracking.json"
local OUTFIT_SETTINGS_FILE = "/settings/outfit.json"

function CipImportApplier.shouldSkipSessionSave()
	return g_settings and g_settings.getBoolean(SKIP_SESSION_SAVE_KEY)
end

function CipImportApplier.markSkipSessionSaveOnRestart()
	if g_settings then
		g_settings.set(SKIP_SESSION_SAVE_KEY, true)
	end
end

function CipImportApplier.clearSkipSessionSaveFlag()
	if g_settings then
		g_settings.remove(SKIP_SESSION_SAVE_KEY)
	end
end

local function isValidKeyCombo(key)
	if CipImportMappings and CipImportMappings.isValidKeyCombo then
		return CipImportMappings.isValidKeyCombo(key)
	end

	if type(key) ~= "string" or key == "" then
		return false
	end

	if not retranslateKeyComboDesc then
		return true
	end

	local ok, translated = pcall(retranslateKeyComboDesc, key)

	return ok and translated ~= nil and translated ~= ""
end

local function ensureControlsDirectories()
	if not g_resources.directoryExists("/controls") then
		g_resources.makeDir("/controls")
	end

	if not g_resources.directoryExists("/controls/keybinds") then
		g_resources.makeDir("/controls/keybinds")
	end

	if not g_resources.directoryExists("/controls/hotkeys") then
		g_resources.makeDir("/controls/hotkeys")
	end
end

local function copyFileIfMissing(fromPath, toPath)
	if g_resources.fileExists(toPath) then
		return
	end

	if g_resources.fileExists(fromPath) then
		g_resources.writeFileContents(toPath, g_resources.readFileContents(fromPath))
	else
		g_resources.writeFileContents(toPath, "\n")
	end
end

local function getControlsPresets()
	local presets = g_settings.getList("controls-presets")

	if #presets == 0 then
		return {
			"Druid",
			"Knight",
			"Paladin",
			"Sorcerer"
		}
	end

	return presets
end

local function presetInList(presets, presetName)
	for _, name in ipairs(presets) do
		if name == presetName then
			return true
		end
	end

	return false
end

local function addPresetToList(presets, presetName)
	if presetInList(presets, presetName) then
		return presets
	end

	local updated = {}

	for _, name in ipairs(presets) do
		table.insert(updated, name)
	end

	table.insert(updated, presetName)

	return updated
end

local function ensurePresetFiles(presetName, templatePreset)
	ensureControlsDirectories()
	copyFileIfMissing("/controls/keybinds/" .. templatePreset .. ".otml", "/controls/keybinds/" .. presetName .. ".otml")
	copyFileIfMissing("/controls/hotkeys/" .. templatePreset .. ".otml", "/controls/hotkeys/" .. presetName .. ".otml")
end

local function resetPresetFiles(presetName, templatePreset)
	ensureControlsDirectories()

	local keybindTemplate = "/controls/keybinds/" .. templatePreset .. ".otml"
	local keybindTarget = "/controls/keybinds/" .. presetName .. ".otml"

	if g_resources.fileExists(keybindTemplate) then
		g_resources.writeFileContents(keybindTarget, g_resources.readFileContents(keybindTemplate))
	else
		g_resources.writeFileContents(keybindTarget, "\n")
	end

	g_resources.writeFileContents("/controls/hotkeys/" .. presetName .. ".otml", EMPTY_HOTKEYS_OTML)
end

local function buildImportedPresetList(hotkeys)
	local presets = {}

	if type(hotkeys.presetOrder) == "table" then
		for _, presetName in ipairs(hotkeys.presetOrder) do
			if hotkeys.presets and hotkeys.presets[presetName] then
				table.insert(presets, presetName)
			end
		end
	end

	if #presets == 0 and type(hotkeys.presets) == "table" then
		for presetName in pairs(hotkeys.presets) do
			table.insert(presets, presetName)
		end

		table.sort(presets)
	end

	return presets
end

local function persistKeybindKey(presetName, category, action, key, chatMode)
	if not isValidKeyCombo(key) then
		return false
	end

	if not Keybind or not Keybind.getAction then
		return false
	end

	local keybind = Keybind.getAction(category, action)

	if not keybind then
		return false
	end

	local config = g_configs.create("/controls/keybinds/" .. presetName .. ".otml")
	local index = category .. "_" .. action
	local keys = config:getNode(index)

	keys = keys or table.recursivecopy(keybind.keys)

	local modeKey = tostring(chatMode)

	if not keys[modeKey] then
		local defaults = keybind.keys[chatMode] or keybind.keys[tonumber(modeKey)] or {
			secondary = "",
			primary = ""
		}

		keys[modeKey] = table.recursivecopy(defaults)
	end

	keys[modeKey].primary = key

	if keys[modeKey].secondary == key then
		keys[modeKey].secondary = ""
	end

	config:setNode(index, keys)
	config:save()

	return true
end

local function appendCustomHotkey(presetName, chatMode, hotkeyEntry)
	if hotkeyEntry.primary and hotkeyEntry.primary ~= "" and not isValidKeyCombo(hotkeyEntry.primary) then
		return false
	end

	if hotkeyEntry.secondary and hotkeyEntry.secondary ~= "" and not isValidKeyCombo(hotkeyEntry.secondary) then
		return false
	end

	local config = g_configs.create("/controls/hotkeys/" .. presetName .. ".otml")
	local hotkeys = config:getNode(chatMode) or {}
	local hotkeyId = 1

	while hotkeys[tostring(hotkeyId)] do
		hotkeyId = hotkeyId + 1
	end

	local hotkey = {
		action = hotkeyEntry.action,
		data = hotkeyEntry.data,
		primary = hotkeyEntry.primary or "",
		secondary = hotkeyEntry.secondary or ""
	}

	if hotkey.data and hotkey.data.parameter then
		hotkey.data.parameter = "\"" .. hotkey.data.parameter .. "\""
	end

	hotkeys[tostring(hotkeyId)] = hotkey

	config:setNode(chatMode, hotkeys)
	config:save()

	return true
end

local function sanitizeActionBarSlot(slotData)
	if type(slotData) ~= "table" then
		return nil
	end

	local slot = table.copy(slotData)

	if slot.hotkeyChatOn and not isValidKeyCombo(slot.hotkeyChatOn) then
		slot.hotkeyChatOn = nil
	end

	if slot.hotkeyChatOff and not isValidKeyCombo(slot.hotkeyChatOff) then
		slot.hotkeyChatOff = nil
	end

	return slot
end

local function sanitizeActionBarSlots(slots)
	if type(slots) ~= "table" then
		return {}
	end

	local sanitized = {}

	for slotId, slotData in pairs(slots) do
		local slot = sanitizeActionBarSlot(slotData)

		if slot then
			sanitized[slotId] = slot
		end
	end

	return sanitized
end

local function ensureSettingsDirectory()
	if not g_resources.directoryExists("/settings/") then
		g_resources.makeDir("/settings/")
	end
end

local function markActionBarMigrationCompleteDirect()
	ensureSettingsDirectory()
	g_resources.writeFileContents(LEGACY_MIGRATION_FLAG, "1")
end

local function readActionBarPresetsDocumentDirect()
	if not g_resources.fileExists(GLOBAL_ACTIONBAR_FILE) then
		return {}
	end

	local ok, data = pcall(function()
		return json.decode(g_resources.readFileContents(GLOBAL_ACTIONBAR_FILE))
	end)

	if ok and type(data) == "table" then
		return data
	end

	return {}
end

local function writeActionBarPresetsDocumentDirect(document)
	if type(document) ~= "table" then
		return false
	end

	ensureSettingsDirectory()

	local ok, encoded = pcall(function()
		return json.encode(document, 2)
	end)

	if not ok or not encoded then
		return false
	end

	g_resources.writeFileContents(GLOBAL_ACTIONBAR_FILE, encoded)

	return true
end

local function persistActionBarSlotsDirect(hotkeys)
	if type(hotkeys) ~= "table" then
		return 0
	end

	local document = readActionBarPresetsDocumentDirect()
	local presetCount = 0

	for presetName, preset in pairs(hotkeys.presets or {}) do
		if type(preset.actionBarSlots) == "table" and not table.empty(preset.actionBarSlots) then
			document[presetName] = sanitizeActionBarSlots(preset.actionBarSlots)
			presetCount = presetCount + 1
		end
	end

	if presetCount > 0 then
		writeActionBarPresetsDocumentDirect(document)
		markActionBarMigrationCompleteDirect()
	end

	return presetCount
end

local function cleanupLegacyActionBarFiles()
	local files = g_resources.listDirectoryFiles("/settings/", false, false, false)

	if type(files) ~= "table" then
		return 0
	end

	local count = 0

	for _, fileName in ipairs(files) do
		if type(fileName) == "string" and fileName:match("_actionbar%.json$") then
			local path = "/settings/" .. fileName

			if g_resources.fileExists(path) then
				g_resources.deleteFile(path)

				count = count + 1
			end
		end
	end

	return count
end

local function removeLegacyGameActionBarNode()
	if g_settings and g_settings.getNode("game_actionbar") then
		g_settings.remove("game_actionbar")

		return true
	end

	return false
end

local function readJsonSettingsFile(path)
	if not path or not g_resources.fileExists(path) then
		return {}
	end

	local ok, data = pcall(function()
		return json.decode(g_resources.readFileContents(path))
	end)

	if ok and type(data) == "table" then
		return data
	end

	return {}
end

local function writeJsonSettingsFile(path, data)
	if type(data) ~= "table" then
		return false
	end

	ensureSettingsDirectory()

	local ok, encoded = pcall(function()
		return json.encode(data, 2)
	end)

	if not ok or not encoded then
		return false
	end

	g_resources.writeFileContents(path, encoded)

	return true
end

local function getActionBarModuleApi()
	return modules.game_actionbar or {}
end

local function persistPendingActionBarSlots(hotkeys)
	local pending = g_settings.getNode("cip_pending_actionbar")

	if type(pending) ~= "table" then
		pending = {}
	end

	local count = 0

	for presetName, preset in pairs(hotkeys.presets or {}) do
		if type(preset.actionBarSlots) == "table" and not table.empty(preset.actionBarSlots) then
			pending[presetName] = sanitizeActionBarSlots(preset.actionBarSlots)
			count = count + 1
		end
	end

	if count > 0 then
		g_settings.setNode("cip_pending_actionbar", pending)
	end

	return count
end

local function persistActionBarSlots(hotkeys)
	if type(hotkeys) ~= "table" then
		return 0
	end

	local actionBarApi = getActionBarModuleApi()

	if actionBarApi.replaceActionBarPresetSlots then
		local count = 0

		for presetName, preset in pairs(hotkeys.presets or {}) do
			if type(preset.actionBarSlots) == "table" and not table.empty(preset.actionBarSlots) then
				count = count + actionBarApi.replaceActionBarPresetSlots(presetName, sanitizeActionBarSlots(preset.actionBarSlots))
			end
		end

		if count > 0 then
			markActionBarMigrationCompleteDirect()

			if actionBarApi.invalidateActionBarSettingsCache then
				actionBarApi.invalidateActionBarSettingsCache()
			end
		end

		return count
	end

	local directCount = persistActionBarSlotsDirect(hotkeys)

	if directCount > 0 then
		return directCount
	end

	return persistPendingActionBarSlots(hotkeys)
end

function CipImportApplier.applyPendingActionBar()
	local pending = g_settings.getNode("cip_pending_actionbar")

	if type(pending) ~= "table" or table.empty(pending) then
		return false
	end

	local actionBarApi = getActionBarModuleApi()
	local count = 0

	if actionBarApi.replaceActionBarPresetSlots then
		for presetName, slots in pairs(pending) do
			if type(slots) == "table" then
				count = count + actionBarApi.replaceActionBarPresetSlots(presetName, sanitizeActionBarSlots(slots))
			end
		end
	else
		local document = readActionBarPresetsDocumentDirect()

		for presetName, slots in pairs(pending) do
			if type(slots) == "table" then
				document[presetName] = sanitizeActionBarSlots(slots)
				count = count + 1
			end
		end

		if count > 0 then
			writeActionBarPresetsDocumentDirect(document)
		end
	end

	if count > 0 then
		g_settings.remove("cip_pending_actionbar")

		if actionBarApi.invalidateActionBarSettingsCache then
			actionBarApi.invalidateActionBarSettingsCache()
		end

		markActionBarMigrationCompleteDirect()
	end

	return count > 0
end

function CipImportApplier.applyClientJsonBridgeOnLogin()
	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local charId = tostring(player:getId())
	local charName = g_game.getCharacterName()

	if not charName or charName == "" then
		return false
	end

	local applied = false
	local charNameLower = charName:lower()
	local charDataDir = "/characterdata/" .. charId
	local questPath = charDataDir .. "/questtracking.json"

	if g_resources.fileExists(questPath) and CipImportMappings.convertQuestTrackingToOtClient then
		local cipQuest = readJsonSettingsFile(questPath)
		local converted = CipImportMappings.convertQuestTrackingToOtClient(cipQuest, charNameLower)

		if converted then
			local settings = readJsonSettingsFile(QUEST_TRACKING_FILE)

			for key, value in pairs(converted) do
				settings[key] = value
			end

			if writeJsonSettingsFile(QUEST_TRACKING_FILE, settings) then
				applied = true
			end
		end
	end

	local outfitPath = charDataDir .. "/outfitdialog.json"

	if g_resources.fileExists(outfitPath) and CipImportMappings.convertOutfitDialogToOtClient then
		local cipOutfit = readJsonSettingsFile(outfitPath)
		local converted = CipImportMappings.convertOutfitDialogToOtClient(cipOutfit)

		if converted then
			local fullSettings = readJsonSettingsFile(OUTFIT_SETTINGS_FILE)

			if type(fullSettings[charName]) ~= "table" then
				fullSettings[charName] = {}
			end

			for key, value in pairs(converted) do
				fullSettings[charName][key] = value
			end

			if writeJsonSettingsFile(OUTFIT_SETTINGS_FILE, fullSettings) then
				applied = true
			end
		end
	end

	return applied
end

function CipImportApplier.applyIgnoreList(ignoreList)
	if type(ignoreList) ~= "table" then
		return 0
	end

	local count = 0

	if type(ignoreList.ignore) == "table" and #ignoreList.ignore > 0 then
		g_settings.setNode("IgnorePlayers", ignoreList.ignore)

		count = count + #ignoreList.ignore
	end

	if type(ignoreList.whitelist) == "table" and #ignoreList.whitelist > 0 then
		g_settings.setNode("WhitelistedPlayers", ignoreList.whitelist)

		count = count + #ignoreList.whitelist
	end

	return count
end

function CipImportApplier.applyOptions(options)
	if type(options) ~= "table" or table.empty(options) then
		return 0
	end

	if modules.client_options and modules.client_options.persistImportedOptions then
		return modules.client_options.persistImportedOptions(options)
	end

	local count = 0

	for key, value in pairs(options) do
		if g_settings then
			g_settings.set(key, value)

			count = count + 1
		end
	end

	return count
end

function CipImportApplier.applyControlButtons(visibility)
	if type(visibility) ~= "table" or table.empty(visibility) then
		return 0
	end

	local node = g_settings.getNode("control_buttons")

	if not node or type(node) ~= "table" then
		node = {
			buttons = {},
			order = {}
		}
	end

	if type(node.buttons) ~= "table" then
		node.buttons = {}
	end

	local count = 0

	for buttonId, visible in pairs(visibility) do
		if not node.buttons[buttonId] or type(node.buttons[buttonId]) ~= "table" then
			node.buttons[buttonId] = {}
		end

		node.buttons[buttonId].visible = visible
		count = count + 1
	end

	g_settings.setNode("control_buttons", node)

	return count
end

function CipImportApplier.applyHotkeys(hotkeys)
	if type(hotkeys) ~= "table" then
		return 0
	end

	local applied = 0
	local ok, err = pcall(function()
		ensureControlsDirectories()

		local importedPresets = buildImportedPresetList(hotkeys)

		if #importedPresets == 0 then
			return
		end

		local templatePreset = getControlsPresets()[1] or "Druid"

		for _, presetName in ipairs(importedPresets) do
			resetPresetFiles(presetName, templatePreset)
		end

		for presetName, preset in pairs(hotkeys.presets or {}) do
			for _, keybind in ipairs(preset.keybinds or {}) do
				if persistKeybindKey(presetName, keybind.category, keybind.action, keybind.key, keybind.chatMode) then
					applied = applied + 1
				end
			end

			for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
				for _, hotkey in ipairs(preset.customHotkeys and preset.customHotkeys[chatMode] or {}) do
					if appendCustomHotkey(presetName, chatMode, hotkey) then
						applied = applied + 1
					end
				end
			end
		end

		applied = applied + persistActionBarSlots(hotkeys)

		markActionBarMigrationCompleteDirect()

		if invalidateActionBarSettingsCache then
			invalidateActionBarSettingsCache()
		end

		if markActionBarPresetsMigrationComplete then
			markActionBarPresetsMigrationComplete()
		end

		g_settings.setList("controls-presets", importedPresets)

		if hotkeys.currentPreset and hotkeys.currentPreset ~= "" and presetInList(importedPresets, hotkeys.currentPreset) then
			g_settings.setValue("controls-preset-current", hotkeys.currentPreset)
		elseif importedPresets[1] then
			g_settings.setValue("controls-preset-current", importedPresets[1])
		end

		if hotkeys.autoSwitchPreset ~= nil then
			g_settings.set("autoSwitchPreset", hotkeys.autoSwitchPreset)
		end
	end)

	if not ok then
		g_logger.warning("[cip_import] hotkey apply failed: %s", tostring(err))
	end

	return applied
end

local function mergePresetsByName(existing, incoming)
	if type(existing) ~= "table" then
		return incoming
	end

	if type(incoming) ~= "table" then
		return existing
	end

	if incoming.presets and type(incoming.presets) == "table" then
		existing.presets = existing.presets or {}

		for _, preset in ipairs(incoming.presets) do
			if type(preset) == "table" and preset.name then
				local replaced = false

				for index, current in ipairs(existing.presets) do
					if current.name == preset.name then
						existing.presets[index] = preset
						replaced = true

						break
					end
				end

				if not replaced then
					table.insert(existing.presets, preset)
				end
			end
		end
	else
		for key, value in pairs(incoming) do
			existing[key] = value
		end
	end

	return existing
end

function CipImportApplier.applyCharacterData(characterData, playerId)
	if type(characterData) ~= "table" or table.empty(characterData) or not playerId then
		return 0
	end

	local directory = "/characterdata/" .. playerId

	if not g_resources.directoryExists("/characterdata") then
		g_resources.makeDir("/characterdata")
	end

	if not g_resources.directoryExists(directory) then
		g_resources.makeDir(directory)
	end

	local count = 0

	for fileName, data in pairs(characterData) do
		local target = directory .. "/" .. fileName
		local payload = data

		if g_resources.fileExists(target) and fileName == "wheelOfDestiny.json" then
			local decodeOk, existing = pcall(function()
				return json.decode(g_resources.readFileContents(target))
			end)

			if decodeOk and type(existing) == "table" then
				payload = mergePresetsByName(existing, data)
			end
		end

		local encodeOk, encoded = pcall(function()
			return json.encode(payload, 2)
		end)

		if encodeOk and encoded then
			g_resources.writeFileContents(target, encoded)

			count = count + 1
		end
	end

	return count
end

function CipImportApplier.applyAllCharacterData(charactersById)
	if type(charactersById) ~= "table" or table.empty(charactersById) then
		return 0, 0
	end

	local fileCount = 0
	local sidebarCount = 0
	local pendingSidebars = g_settings.getNode("cip_pending_sidebars")

	if type(pendingSidebars) ~= "table" then
		pendingSidebars = {}
	end

	for id, charEntry in pairs(charactersById) do
		if type(charEntry) == "table" then
			if type(charEntry.files) == "table" then
				fileCount = fileCount + CipImportApplier.applyCharacterData(charEntry.files, id)
			end

			if type(charEntry.charMiniWindows) == "table" and not table.empty(charEntry.charMiniWindows) then
				pendingSidebars[id] = charEntry.charMiniWindows
				sidebarCount = sidebarCount + 1
			end
		end
	end

	if sidebarCount > 0 then
		g_settings.setNode("cip_pending_sidebars", pendingSidebars)
	end

	return fileCount, sidebarCount
end

function CipImportApplier.applyPendingSidebars()
	local pending = g_settings.getNode("cip_pending_sidebars")

	if type(pending) ~= "table" or table.empty(pending) then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local charId = tostring(player:getId())
	local charName = g_game.getCharacterName()

	if not charName or charName == "" then
		return false
	end

	local layout = pending[charId]

	if type(layout) ~= "table" or table.empty(layout) then
		return false
	end

	local settings = g_settings.getNode("CharMiniWindows")

	if type(settings) ~= "table" then
		settings = {}
	end

	if type(settings[charName]) ~= "table" then
		settings[charName] = {}
	end

	for widgetId, widgetSettings in pairs(layout) do
		if type(widgetSettings) == "table" then
			settings[charName][widgetId] = widgetSettings
		end
	end

	g_settings.setNode("CharMiniWindows", settings)

	pending[charId] = nil

	local hasPending = false

	for _ in pairs(pending) do
		hasPending = true

		break
	end

	if hasPending then
		g_settings.setNode("cip_pending_sidebars", pending)
	else
		g_settings.remove("cip_pending_sidebars")
	end

	return true
end

function CipImportApplier.apply(converted)
	if not converted then
		return false, tr("Nothing to import.")
	end

	CipImportApplier.applyOptions(converted.options)
	CipImportApplier.applyControlButtons(converted.controlButtons)
	CipImportApplier.applyHotkeys(converted.hotkeys)
	CipImportApplier.applyIgnoreList(converted.ignoreList)
	CipImportApplier.applyAllCharacterData(converted.charactersById)

	local legacyRemoved = cleanupLegacyActionBarFiles()

	removeLegacyGameActionBarNode()

	if legacyRemoved > 0 then
		g_logger.info("[cip_import] removed %d legacy *_actionbar.json file(s)", legacyRemoved)
	end

	CipImportApplier.markSkipSessionSaveOnRestart()
	g_settings.save()

	return true, tr("Import completed. The client will restart to apply changes.")
end
