-- chunkname: @/client_options/custom_hotkey_manager.lua

CustomHotkeyManager = {
	presets = {},
	presetToIndex = {},
	chatMode = CHAT_MODE.ON,
	configs = {},
	hotkeys = {
		[CHAT_MODE.ON] = {},
		[CHAT_MODE.OFF] = {}
	},
	reservedKeys = {
		Right = true,
		Left = true,
		Down = true,
		Up = true
	}
}

local SETTINGS_AUTO_SWITCH = "custom-hotkeys-auto-switch"
local STORAGE_DIR = "/controls/custom_hotkeys"
local bindingsSuspended = false
local OBJECT_USE_DISPLAY = {
	useOnSelf = {
		label = "(use object on yourself)",
		color = "#b0ffb0"
	},
	useOnTarget = {
		label = "(use object on target)",
		color = "#ffb0b0"
	},
	useWith = {
		label = "(use object with crosshair)",
		color = "#c87d7d"
	},
	useAtCursor = {
		label = "(use object at mouse cursor)",
		color = "#c87d7d"
	},
	equip = {
		label = "(equip/unequip object)",
		color = "#bfbf00"
	},
	use = {
		label = "(use object)",
		color = "#b0b0ff"
	}
}
local USE_TYPE_TO_ACTION = {
	useOnSelf = HOTKEY_ACTION.USE_YOURSELF,
	useOnTarget = HOTKEY_ACTION.USE_TARGET,
	useWith = HOTKEY_ACTION.USE_CROSSHAIR,
	equip = HOTKEY_ACTION.EQUIP,
	use = HOTKEY_ACTION.USE,
	useAtCursor = HOTKEY_ACTION.USE
}
local ACTION_TO_USE_TYPE = {
	[HOTKEY_ACTION.USE_YOURSELF] = "useOnSelf",
	[HOTKEY_ACTION.USE_TARGET] = "useOnTarget",
	[HOTKEY_ACTION.USE_CROSSHAIR] = "useWith",
	[HOTKEY_ACTION.EQUIP] = "equip",
	[HOTKEY_ACTION.USE] = "use"
}

local function isMouseHotkeyCombo(combo)
	return g_mouse and g_mouse.isMouseHotkeyDesc and g_mouse.isMouseHotkeyDesc(combo)
end

local function isChatInputActive()
	return modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled()
end

local function hookConsoleChatSwitch()
	if not modules.game_console or not modules.game_console.switchChat then
		return false
	end

	if modules.game_console._customHotkeysChatHooked then
		return true
	end

	local originalSwitchChat = modules.game_console.switchChat

	function modules.game_console.switchChat(enabled)
		originalSwitchChat(enabled)
		CustomHotkeyManager.syncChatModeFromGame()
	end

	modules.game_console._customHotkeysChatHooked = true

	return true
end

local function bindComboKeyDown(combo, callback, widget)
	if isMouseHotkeyCombo(combo) then
		g_mouse.bindHotkeyPress(combo, callback, widget)
	else
		g_keyboard.bindKeyDown(combo, callback, widget)
	end
end

local function bindComboKeyPress(combo, callback, widget)
	if isMouseHotkeyCombo(combo) then
		g_mouse.bindHotkeyPress(combo, callback, widget)
	else
		g_keyboard.bindKeyPress(combo, callback, widget)
	end
end

local function unbindComboKeyDown(combo, callback, widget)
	if isMouseHotkeyCombo(combo) then
		g_mouse.unbindHotkeyPress(combo, callback, widget)
	else
		g_keyboard.unbindKeyDown(combo, callback, widget)
	end
end

local function unbindComboKeyPress(combo, callback, widget)
	if isMouseHotkeyCombo(combo) then
		g_mouse.unbindHotkeyPress(combo, callback, widget)
	else
		g_keyboard.unbindKeyPress(combo, callback, widget)
	end
end

local function normalizeKeyCombo(value)
	if value == nil then
		return ""
	end

	return tostring(value)
end

local function normalizeAction(action)
	if action == nil then
		return nil
	end

	return tonumber(action) or action
end

local function inferUseType(action, data)
	data = data or {}

	if data.useType and USE_TYPE_TO_ACTION[data.useType] then
		return data.useType
	end

	if data.useAtCursor then
		return "useAtCursor"
	end

	return ACTION_TO_USE_TYPE[normalizeAction(action)] or "use"
end

local function actionFromUseType(useType)
	return USE_TYPE_TO_ACTION[useType] or HOTKEY_ACTION.USE
end

local function resolveHotkeyAction(hotkey)
	local data = hotkey.data or {}

	if data.itemId then
		return actionFromUseType(inferUseType(hotkey.action, data))
	end

	return normalizeAction(hotkey.action)
end

local function cloneHotkeyData(action, data)
	action = normalizeAction(action)
	data = data or {}

	local copy = {}

	if data.itemId then
		copy.itemId = tonumber(data.itemId) or data.itemId

		if data.subType ~= nil then
			copy.subType = data.subType
		end

		if data.getTier ~= nil then
			copy.getTier = data.getTier
		end

		local useType = inferUseType(action, data)

		copy.useType = useType

		if useType == "useAtCursor" then
			copy.useAtCursor = true
		end
	end

	if data.words then
		copy.words = data.words
	end

	if data.parameter then
		copy.parameter = data.parameter
	end

	if data.text then
		copy.text = data.text
	end

	return copy
end

local function normalizeItemHotkey(action, data)
	data = data or {}

	if not data.itemId then
		return normalizeAction(action), cloneHotkeyData(action, data)
	end

	local useType = inferUseType(action, data)
	local resolvedAction = actionFromUseType(useType)

	return resolvedAction, cloneHotkeyData(resolvedAction, {
		itemId = data.itemId,
		subType = data.subType,
		getTier = data.getTier,
		useType = useType,
		useAtCursor = useType == "useAtCursor" or data.useAtCursor or nil
	})
end

local function serializeHotkeys(list)
	local serialized = {}

	for id, hotkey in ipairs(list or {}) do
		local action = normalizeAction(hotkey.action)

		serialized[id] = {
			action = action,
			data = cloneHotkeyData(action, hotkey.data),
			primary = normalizeKeyCombo(hotkey.primary),
			secondary = normalizeKeyCombo(hotkey.secondary)
		}
	end

	return serialized
end

local HOTKEY_PRESS_DELAY_MS = 250
local HOTKEY_DOWN_DELAY_MS = 200
local HOTKEY_NEXT_DOWN_BLOCK_MS = 200

local function canTriggerHotkey(hotkey, isPress)
	if not hotkey then
		return false
	end

	local now = g_clock.millis()

	if now < (hotkey.lastClick or 0) then
		return false
	end

	if not isPress then
		hotkey.nextDownKey = now + HOTKEY_NEXT_DOWN_BLOCK_MS
	elseif now < (hotkey.nextDownKey or 0) then
		return false
	end

	hotkey.lastClick = now + (isPress and HOTKEY_PRESS_DELAY_MS or HOTKEY_DOWN_DELAY_MS)

	return true
end

local function loadHotkeysForPreset(preset)
	for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
		CustomHotkeyManager.hotkeys[chatMode][preset] = {}

		local config = CustomHotkeyManager.configs[preset]

		if not config then
			-- block empty
		else
			local hotkeyId = 1
			local hotkeys = config:getNode(chatMode)

			if hotkeys then
				local hotkey = hotkeys[tostring(hotkeyId)]

				while hotkey do
					if hotkey.data and hotkey.data.parameter then
						hotkey.data.parameter = "\"" .. hotkey.data.parameter .. "\""
					end

					local action = normalizeAction(hotkey.action)
					local data

					if hotkey.data and hotkey.data.itemId then
						action, data = normalizeItemHotkey(action, hotkey.data)
					else
						data = cloneHotkeyData(action, hotkey.data)
					end

					local loaded = {
						action = action,
						data = data,
						primary = normalizeKeyCombo(hotkey.primary),
						secondary = normalizeKeyCombo(hotkey.secondary),
						hotkeyId = hotkeyId
					}

					table.insert(CustomHotkeyManager.hotkeys[chatMode][preset], loaded)

					hotkeyId = hotkeyId + 1
					hotkey = hotkeys[tostring(hotkeyId)]
				end
			end
		end
	end
end

local function saveHotkeysForPreset(preset, chatMode)
	local config = CustomHotkeyManager.configs[preset]

	if not config then
		return
	end

	config:setNode(chatMode, serializeHotkeys(CustomHotkeyManager.hotkeys[chatMode][preset]))
	config:save()
end

local function hookKeybindPresetCRUD()
	if not Keybind or Keybind._customHotkeysHooked then
		return
	end

	local originalNew = Keybind.newPreset

	function Keybind.newPreset(presetName)
		local existedBefore = Keybind.presetToIndex[presetName] ~= nil
		local result = originalNew(presetName)

		if not existedBefore and Keybind.presetToIndex[presetName] then
			CustomHotkeyManager._registerPresetStorage(presetName)
		end

		return result
	end

	local originalCopy = Keybind.copyPreset

	function Keybind.copyPreset(fromPreset, toPreset)
		local result = originalCopy(fromPreset, toPreset)

		if result and Keybind.presetToIndex[toPreset] then
			CustomHotkeyManager._copyPresetStorage(fromPreset, toPreset)
		end

		return result
	end

	local originalRename = Keybind.renamePreset

	function Keybind.renamePreset(oldName, newName)
		local result = originalRename(oldName, newName)

		if Keybind.presetToIndex[newName] and not Keybind.presetToIndex[oldName] then
			CustomHotkeyManager._renamePresetStorage(oldName, newName)
		end

		return result
	end

	local originalRemove = Keybind.removePreset

	function Keybind.removePreset(presetName)
		local result = originalRemove(presetName)

		if result and not Keybind.presetToIndex[presetName] then
			CustomHotkeyManager._removePresetStorage(presetName)
		end

		return result
	end

	Keybind._customHotkeysHooked = true
end

function CustomHotkeyManager.init()
	connect(g_game, {
		onGameStart = CustomHotkeyManager.online,
		onGameEnd = CustomHotkeyManager.offline
	})

	if Keybind and Keybind.presets and #Keybind.presets > 0 then
		CustomHotkeyManager.presets = Keybind.presets
		CustomHotkeyManager.presetToIndex = Keybind.presetToIndex
		CustomHotkeyManager.currentPreset = Keybind.currentPreset or Keybind.presets[1]
	else
		g_logger.warning("CustomHotkeyManager: Keybind presets not initialized, using fallback")

		CustomHotkeyManager.presets = {
			"Default"
		}
		CustomHotkeyManager.presetToIndex = {
			Default = 1
		}
		CustomHotkeyManager.currentPreset = "Default"
	end

	if not g_resources.directoryExists("/controls") then
		g_resources.makeDir("/controls")
	end

	if not g_resources.directoryExists(STORAGE_DIR) then
		g_resources.makeDir(STORAGE_DIR)
	end

	CustomHotkeyManager.configs = {}

	for _, preset in ipairs(CustomHotkeyManager.presets) do
		CustomHotkeyManager.configs[preset] = g_configs.create(STORAGE_DIR .. "/" .. preset .. ".otml")

		loadHotkeysForPreset(preset)
	end

	hookKeybindPresetCRUD()
	hookConsoleChatSwitch()

	if Keybind then
		function Keybind.isKeyComboUsedOnCustomHotkeys(keyCombo, chatMode)
			if not keyCombo or keyCombo == "" then
				return false
			end

			return CustomHotkeyManager.isKeyComboUsed(keyCombo, nil, chatMode or CustomHotkeyManager.chatMode)
		end

		function Keybind.clearCustomHotkeyConflicts(keyCombo, chatMode)
			if not keyCombo or keyCombo == "" then
				return false
			end

			return CustomHotkeyManager.clearKeyComboConflicts(keyCombo, chatMode or CustomHotkeyManager.chatMode)
		end
	end

	if g_game.isOnline() then
		CustomHotkeyManager.syncChatModeFromGame()
	end
end

function CustomHotkeyManager._registerPresetStorage(presetName)
	if not presetName or presetName == "" or CustomHotkeyManager.configs[presetName] then
		return
	end

	CustomHotkeyManager.configs[presetName] = g_configs.create(STORAGE_DIR .. "/" .. presetName .. ".otml")

	loadHotkeysForPreset(presetName)
end

function CustomHotkeyManager._copyPresetStorage(fromPreset, toPreset)
	if not toPreset or toPreset == "" or CustomHotkeyManager.configs[toPreset] then
		return
	end

	local fromConfig = CustomHotkeyManager.configs[fromPreset]

	if fromConfig then
		fromConfig:save()

		local content = g_resources.readFileContents(fromConfig:getFileName())

		if content and content ~= "" then
			g_resources.writeFileContents(STORAGE_DIR .. "/" .. toPreset .. ".otml", content)
		end
	end

	CustomHotkeyManager.configs[toPreset] = g_configs.create(STORAGE_DIR .. "/" .. toPreset .. ".otml")

	loadHotkeysForPreset(toPreset)
end

function CustomHotkeyManager._renamePresetStorage(oldName, newName)
	if not newName or newName == "" then
		return
	end

	local config = CustomHotkeyManager.configs[oldName]

	if config then
		config:save()

		local content = g_resources.readFileContents(config:getFileName())

		if content and content ~= "" then
			g_resources.writeFileContents(STORAGE_DIR .. "/" .. newName .. ".otml", content)
		end

		g_resources.deleteFile(STORAGE_DIR .. "/" .. oldName .. ".otml")

		CustomHotkeyManager.configs[oldName] = nil
		CustomHotkeyManager.configs[newName] = g_configs.create(STORAGE_DIR .. "/" .. newName .. ".otml")
	end

	CustomHotkeyManager.hotkeys[CHAT_MODE.ON][newName] = CustomHotkeyManager.hotkeys[CHAT_MODE.ON][oldName] or {}
	CustomHotkeyManager.hotkeys[CHAT_MODE.OFF][newName] = CustomHotkeyManager.hotkeys[CHAT_MODE.OFF][oldName] or {}
	CustomHotkeyManager.hotkeys[CHAT_MODE.ON][oldName] = nil
	CustomHotkeyManager.hotkeys[CHAT_MODE.OFF][oldName] = nil

	if CustomHotkeyManager.currentPreset == oldName then
		CustomHotkeyManager.currentPreset = newName
	end
end

function CustomHotkeyManager._removePresetStorage(presetName)
	if not presetName then
		return
	end

	if CustomHotkeyManager.configs[presetName] then
		g_resources.deleteFile(STORAGE_DIR .. "/" .. presetName .. ".otml")

		CustomHotkeyManager.configs[presetName] = nil
	end

	CustomHotkeyManager.hotkeys[CHAT_MODE.ON][presetName] = nil
	CustomHotkeyManager.hotkeys[CHAT_MODE.OFF][presetName] = nil

	if CustomHotkeyManager.currentPreset == presetName then
		CustomHotkeyManager.currentPreset = Keybind and Keybind.currentPreset or Keybind and Keybind.presets and Keybind.presets[1] or CustomHotkeyManager.presets[1]
	end
end

function CustomHotkeyManager.terminate()
	disconnect(g_game, {
		onGameStart = CustomHotkeyManager.online,
		onGameEnd = CustomHotkeyManager.offline
	})

	for _, preset in ipairs(CustomHotkeyManager.presets) do
		if CustomHotkeyManager.configs[preset] then
			CustomHotkeyManager.configs[preset]:save()
		end
	end
end

function CustomHotkeyManager.online()
	hookConsoleChatSwitch()
	CustomHotkeyManager.syncChatModeFromGame()

	if not bindingsSuspended then
		CustomHotkeyManager.rebindAll()
	end
end

function CustomHotkeyManager.syncChatModeFromGame()
	if not g_game.isOnline() then
		return
	end

	local mode = CHAT_MODE.OFF

	if isChatInputActive() then
		mode = CHAT_MODE.ON
	end

	CustomHotkeyManager.setChatMode(mode)
end

function CustomHotkeyManager.offline()
	CustomHotkeyManager.unbindAll()
end

function CustomHotkeyManager.getAutoSwitchEnabled()
	return g_settings.getBoolean(SETTINGS_AUTO_SWITCH)
end

function CustomHotkeyManager.setAutoSwitchEnabled(enabled)
	g_settings.set(SETTINGS_AUTO_SWITCH, enabled)
end

function CustomHotkeyManager.selectPreset(preset)
	if not preset or CustomHotkeyManager.currentPreset == preset then
		return
	end

	if not CustomHotkeyManager.configs[preset] then
		CustomHotkeyManager._registerPresetStorage(preset)
	end

	CustomHotkeyManager.unbindAll()

	CustomHotkeyManager.currentPreset = preset

	CustomHotkeyManager.rebindAll()
end

function CustomHotkeyManager.setChatMode(chatMode)
	if CustomHotkeyManager.chatMode == chatMode then
		return
	end

	CustomHotkeyManager.unbindAll()

	CustomHotkeyManager.chatMode = chatMode

	CustomHotkeyManager.rebindAll()
end

function CustomHotkeyManager.newPreset(presetName)
	if not presetName or presetName == "" then
		return false
	end

	if not Keybind or not Keybind.newPreset then
		return false
	end

	if Keybind.presetToIndex[presetName] then
		return false
	end

	Keybind.newPreset(presetName)

	return Keybind.presetToIndex[presetName] ~= nil
end

function CustomHotkeyManager.copyPreset(fromPreset, toPreset)
	if not toPreset or toPreset == "" then
		return false
	end

	if not Keybind or not Keybind.copyPreset then
		return false
	end

	if not Keybind.presetToIndex[fromPreset] or Keybind.presetToIndex[toPreset] then
		return false
	end

	return Keybind.copyPreset(fromPreset, toPreset) == true
end

function CustomHotkeyManager.renamePreset(fromPreset, toPreset)
	if not toPreset or toPreset == "" or fromPreset == toPreset then
		return false
	end

	if not Keybind or not Keybind.renamePreset then
		return false
	end

	if not Keybind.presetToIndex[fromPreset] or Keybind.presetToIndex[toPreset] then
		return false
	end

	local wasCurrent = CustomHotkeyManager.currentPreset == fromPreset

	if wasCurrent then
		CustomHotkeyManager.unbindAll()
	end

	Keybind.renamePreset(fromPreset, toPreset)

	if Keybind.presetToIndex[toPreset] and not Keybind.presetToIndex[fromPreset] then
		if wasCurrent then
			CustomHotkeyManager.rebindAll()
		end

		return true
	end

	return false
end

function CustomHotkeyManager.removePreset(preset)
	if not Keybind or not Keybind.removePreset then
		return false
	end

	if not Keybind.presetToIndex[preset] then
		return false
	end

	if #Keybind.presets <= 1 then
		return false
	end

	local wasCurrent = CustomHotkeyManager.currentPreset == preset

	if wasCurrent then
		CustomHotkeyManager.unbindAll()
	end

	local result = Keybind.removePreset(preset)

	if result == true and wasCurrent then
		CustomHotkeyManager.rebindAll()
	end

	return result == true
end

function CustomHotkeyManager.getHotkeys(chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	return CustomHotkeyManager.hotkeys[chatMode][preset] or {}
end

function CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local keys = {
		primary = "",
		secondary = ""
	}
	local list = CustomHotkeyManager.hotkeys[chatMode][preset]

	if not list or not list[hotkeyId] then
		return keys
	end

	local hotkey = list[hotkeyId]

	keys.primary = normalizeKeyCombo(hotkey.primary)
	keys.secondary = normalizeKeyCombo(hotkey.secondary)

	return keys
end

function CustomHotkeyManager.isKeyComboUsed(keyCombo, hotkeyId, chatMode, preset, options)
	keyCombo = normalizeKeyCombo(keyCombo)

	if keyCombo == "" then
		return false
	end

	if CustomHotkeyManager.reservedKeys[keyCombo] then
		return true
	end

	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset
	options = options or {}

	local skipRemovedIds = options.skipRemovedIds or {}

	for id, hotkey in ipairs(CustomHotkeyManager.getHotkeys(chatMode, preset)) do
		if skipRemovedIds[id] then
			-- block empty
		elseif hotkeyId and id == hotkeyId then
			-- block empty
		elseif normalizeKeyCombo(hotkey.primary) == keyCombo or normalizeKeyCombo(hotkey.secondary) == keyCombo then
			return true
		end
	end

	return false
end

function CustomHotkeyManager.clearKeyComboConflicts(keyCombo, chatMode, preset, excludeHotkeyId)
	keyCombo = normalizeKeyCombo(keyCombo)

	if keyCombo == "" then
		return false
	end

	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local list = CustomHotkeyManager.hotkeys[chatMode] and CustomHotkeyManager.hotkeys[chatMode][preset]

	if not list then
		return false
	end

	local cleared = false
	local active = chatMode == CustomHotkeyManager.chatMode and preset == CustomHotkeyManager.currentPreset

	for id, hotkey in ipairs(list) do
		if excludeHotkeyId and id == excludeHotkeyId then
			-- block empty
		else
			local changed = false

			if normalizeKeyCombo(hotkey.primary) == keyCombo then
				hotkey.primary = ""
				changed = true
			end

			if normalizeKeyCombo(hotkey.secondary) == keyCombo then
				hotkey.secondary = ""
				changed = true
			end

			if changed then
				cleared = true

				if active then
					CustomHotkeyManager.unbindHotkey(id, chatMode, preset)
					CustomHotkeyManager.bindHotkey(id, chatMode, preset)
				end
			end
		end
	end

	if cleared then
		saveHotkeysForPreset(preset, chatMode)
	end

	return cleared
end

function CustomHotkeyManager.newHotkey(action, data, primary, secondary, chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	if not CustomHotkeyManager.hotkeys[chatMode][preset] then
		CustomHotkeyManager.hotkeys[chatMode][preset] = {}
	end

	local hotkey = {
		action = normalizeAction(action),
		data = cloneHotkeyData(action, data),
		primary = normalizeKeyCombo(primary),
		secondary = normalizeKeyCombo(secondary)
	}

	if hotkey.data and hotkey.data.itemId then
		hotkey.action, hotkey.data = normalizeItemHotkey(action, data)
	end

	table.insert(CustomHotkeyManager.hotkeys[chatMode][preset], hotkey)

	hotkey.hotkeyId = #CustomHotkeyManager.hotkeys[chatMode][preset]

	saveHotkeysForPreset(preset, chatMode)

	if chatMode == CustomHotkeyManager.chatMode and preset == CustomHotkeyManager.currentPreset then
		CustomHotkeyManager.bindHotkey(hotkey.hotkeyId, chatMode, preset)
	end

	return hotkey.hotkeyId
end

function CustomHotkeyManager.editHotkeyKeys(hotkeyId, primary, secondary, chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local hotkey = CustomHotkeyManager.hotkeys[chatMode][preset] and CustomHotkeyManager.hotkeys[chatMode][preset][hotkeyId]

	if not hotkey then
		return false
	end

	CustomHotkeyManager.unbindHotkey(hotkeyId, chatMode, preset)

	hotkey.primary = normalizeKeyCombo(primary)
	hotkey.secondary = normalizeKeyCombo(secondary)

	saveHotkeysForPreset(preset, chatMode)
	CustomHotkeyManager.bindHotkey(hotkeyId, chatMode, preset)

	return true
end

function CustomHotkeyManager.editHotkeyAction(hotkeyId, action, data, chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local hotkey = CustomHotkeyManager.hotkeys[chatMode][preset] and CustomHotkeyManager.hotkeys[chatMode][preset][hotkeyId]

	if not hotkey then
		return false
	end

	CustomHotkeyManager.unbindHotkey(hotkeyId, chatMode, preset)

	if data and data.itemId then
		action, data = normalizeItemHotkey(action, data)
	else
		data = cloneHotkeyData(action, data)
	end

	hotkey.action = normalizeAction(action)
	hotkey.data = data

	saveHotkeysForPreset(preset, chatMode)
	CustomHotkeyManager.bindHotkey(hotkeyId, chatMode, preset)

	return true
end

function CustomHotkeyManager.removeHotkey(hotkeyId, chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local list = CustomHotkeyManager.hotkeys[chatMode][preset]

	if not list or not list[hotkeyId] then
		return false
	end

	CustomHotkeyManager.unbindHotkey(hotkeyId, chatMode, preset)
	table.remove(list, hotkeyId)

	for id, hotkey in ipairs(list) do
		hotkey.hotkeyId = id
	end

	saveHotkeysForPreset(preset, chatMode)

	return true
end

function CustomHotkeyManager.removeAllHotkeys(chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local list = CustomHotkeyManager.hotkeys[chatMode][preset]

	if not list then
		return
	end

	for id in ipairs(list) do
		CustomHotkeyManager.unbindHotkey(id, chatMode, preset)
	end

	CustomHotkeyManager.hotkeys[chatMode][preset] = {}

	saveHotkeysForPreset(preset, chatMode)
end

function CustomHotkeyManager.resetPresetHotkeys(preset)
	preset = preset or CustomHotkeyManager.currentPreset

	CustomHotkeyManager.unbindAll()

	for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
		CustomHotkeyManager.hotkeys[chatMode][preset] = {}

		saveHotkeysForPreset(preset, chatMode)
	end
end

function CustomHotkeyManager.suspendBindings()
	if bindingsSuspended then
		return
	end

	bindingsSuspended = true

	CustomHotkeyManager.unbindAll()
end

function CustomHotkeyManager.resumeBindings()
	if not bindingsSuspended then
		return
	end

	bindingsSuspended = false

	if g_game.isOnline() then
		CustomHotkeyManager.rebindAll()
	end
end

function CustomHotkeyManager.hotkeyCallback(hotkeyId, chatMode, preset, isPress)
	if HotkeyUtils and HotkeyUtils.areHotkeysDisabled and HotkeyUtils.areHotkeysDisabled() then
		return
	end

	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	local hotkey = CustomHotkeyManager.hotkeys[chatMode][preset] and CustomHotkeyManager.hotkeys[chatMode][preset][hotkeyId]

	if not hotkey then
		return
	end

	if not canTriggerHotkey(hotkey, isPress and true or false) then
		return
	end

	local action = resolveHotkeyAction(hotkey)
	local data = hotkey.data or {}

	if action == HOTKEY_ACTION.USE_YOURSELF then
		if g_game.getClientVersion() < 780 then
			local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

			if item then
				g_game.useWith(item, g_game.getLocalPlayer())
			end
		else
			g_game.useInventoryItemWith(data.itemId, g_game.getLocalPlayer(), data.subType or -1)
		end
	elseif action == HOTKEY_ACTION.USE_CROSSHAIR then
		local item = Item.create(data.itemId)

		if g_game.getClientVersion() < 780 then
			item = g_game.findPlayerItem(data.itemId, data.subType or -1)
		end

		if item then
			modules.game_interface.startUseWith(item, data.subType or -1)
		end
	elseif action == HOTKEY_ACTION.USE_TARGET then
		local attackingCreature = g_game.getAttackingCreature()

		if not attackingCreature then
			local item = Item.create(data.itemId)

			if g_game.getClientVersion() < 780 then
				item = g_game.findPlayerItem(data.itemId, data.subType or -1)
			end

			if item then
				modules.game_interface.startUseWith(item, data.subType or -1)
			end

			return
		end

		if attackingCreature:getTile() then
			if g_game.getClientVersion() < 780 then
				local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

				if item then
					g_game.useWith(item, attackingCreature, data.subType or -1)
				end
			else
				g_game.useInventoryItemWith(data.itemId, attackingCreature, data.subType or -1)
			end
		end
	elseif action == HOTKEY_ACTION.EQUIP then
		if g_game.getClientVersion() >= 910 then
			g_game.equipItem(Item.create(data.itemId))
		end
	elseif action == HOTKEY_ACTION.USE then
		if data.useAtCursor then
			local mousePos = g_window.getMousePosition()
			local root = modules.game_interface and modules.game_interface.getRootPanel()

			if root then
				local leaf = root:recursiveGetChildByPos(mousePos, false)
				local mapWidget = leaf

				while mapWidget and mapWidget:getClassName() ~= "UIGameMap" do
					mapWidget = mapWidget:getParent()
				end

				if mapWidget then
					local tile = mapWidget:getTile(mousePos)

					if tile then
						local topThing = tile:getTopUseThing()

						if topThing then
							if g_game.getClientVersion() < 780 then
								local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

								if item then
									g_game.useWith(item, topThing, data.subType or -1)
								end
							else
								g_game.useInventoryItemWith(data.itemId, topThing, data.subType or -1)
							end
						end
					end
				end
			end
		elseif g_game.getClientVersion() < 780 then
			local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

			if item then
				g_game.use(item)
			end
		else
			g_game.useInventoryItem(data.itemId)
		end
	elseif action == HOTKEY_ACTION.TEXT then
		if isChatInputActive() then
			modules.game_console.setTextEditText(data.text)
		end
	elseif action == HOTKEY_ACTION.TEXT_AUTO then
		if isChatInputActive() then
			modules.game_console.sendMessage(data.text)
		else
			g_game.talk(data.text)
		end
	elseif action == HOTKEY_ACTION.SPELL then
		local text = data.words

		if data.parameter then
			text = text .. " " .. data.parameter:gsub("\"", "")
		end

		if isChatInputActive() then
			modules.game_console.sendMessage(text)
		else
			g_game.talk(text)
		end
	end
end

function CustomHotkeyManager.bindHotkey(hotkeyId, chatMode, preset, options)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset
	options = options or {}

	if chatMode ~= CustomHotkeyManager.chatMode or preset ~= CustomHotkeyManager.currentPreset then
		return
	end

	if not modules.game_interface then
		return
	end

	local hotkey = CustomHotkeyManager.hotkeys[chatMode][preset] and CustomHotkeyManager.hotkeys[chatMode][preset][hotkeyId]

	if not hotkey then
		return
	end

	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)
	local gameRootPanel = modules.game_interface.getRootPanel()
	local allowPrimary = options.allowPrimary ~= false
	local allowSecondary = options.allowSecondary ~= false

	function hotkey.callbackDown()
		CustomHotkeyManager.hotkeyCallback(hotkeyId, chatMode, preset, false)
	end

	function hotkey.callbackPress()
		CustomHotkeyManager.hotkeyCallback(hotkeyId, chatMode, preset, true)
	end

	hotkey.callback = hotkey.callbackDown

	local function bindCombo(combo)
		combo = normalizeKeyCombo(combo)

		if combo:len() == 0 then
			return
		end

		bindComboKeyDown(combo, hotkey.callbackDown, gameRootPanel)
		bindComboKeyPress(combo, hotkey.callbackPress, gameRootPanel)
	end

	if allowPrimary and keys.primary then
		bindCombo(keys.primary)
	end

	if allowSecondary and keys.secondary then
		bindCombo(keys.secondary)
	end
end

function CustomHotkeyManager.unbindHotkey(hotkeyId, chatMode, preset)
	chatMode = chatMode or CustomHotkeyManager.chatMode
	preset = preset or CustomHotkeyManager.currentPreset

	if not modules.game_interface then
		return
	end

	local hotkey = CustomHotkeyManager.hotkeys[chatMode][preset] and CustomHotkeyManager.hotkeys[chatMode][preset][hotkeyId]

	if not hotkey then
		return
	end

	local callbackDown = hotkey.callbackDown or hotkey.callback
	local callbackPress = hotkey.callbackPress or hotkey.callback

	if not callbackDown and not callbackPress then
		return
	end

	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)
	local gameRootPanel = modules.game_interface.getRootPanel()

	local function unbindCombo(combo)
		combo = normalizeKeyCombo(combo)

		if combo:len() == 0 then
			return
		end

		if callbackDown then
			unbindComboKeyDown(combo, callbackDown, gameRootPanel)
		end

		if callbackPress then
			unbindComboKeyPress(combo, callbackPress, gameRootPanel)
		end
	end

	if keys.primary then
		unbindCombo(keys.primary)
	end

	if keys.secondary then
		unbindCombo(keys.secondary)
	end

	hotkey.callback = nil
	hotkey.callbackDown = nil
	hotkey.callbackPress = nil
end

function CustomHotkeyManager.rebindAll()
	local preset = CustomHotkeyManager.currentPreset
	local chatMode = CustomHotkeyManager.chatMode
	local hotkeys = CustomHotkeyManager.getHotkeys(chatMode, preset)
	local lastOwner = {}

	for _, hotkey in ipairs(hotkeys) do
		local keys = CustomHotkeyManager.getHotkeyKeys(hotkey.hotkeyId, preset, chatMode)
		local primary = normalizeKeyCombo(keys.primary)
		local secondary = normalizeKeyCombo(keys.secondary)

		if primary ~= "" then
			lastOwner[primary] = hotkey.hotkeyId
		end

		if secondary ~= "" then
			lastOwner[secondary] = hotkey.hotkeyId
		end
	end

	for _, hotkey in ipairs(hotkeys) do
		local keys = CustomHotkeyManager.getHotkeyKeys(hotkey.hotkeyId, preset, chatMode)
		local primary = normalizeKeyCombo(keys.primary)
		local secondary = normalizeKeyCombo(keys.secondary)

		CustomHotkeyManager.bindHotkey(hotkey.hotkeyId, chatMode, preset, {
			allowPrimary = primary == "" or lastOwner[primary] == hotkey.hotkeyId,
			allowSecondary = secondary == "" or lastOwner[secondary] == hotkey.hotkeyId
		})
	end
end

function CustomHotkeyManager.unbindAll()
	local preset = CustomHotkeyManager.currentPreset

	for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
		for _, hotkey in ipairs(CustomHotkeyManager.getHotkeys(chatMode, preset)) do
			CustomHotkeyManager.unbindHotkey(hotkey.hotkeyId, chatMode, preset)
		end
	end
end

function CustomHotkeyManager.getActionLabel(hotkey)
	local display = CustomHotkeyManager.getActionDisplay(hotkey)

	return display and display.text or tr("Action")
end

function CustomHotkeyManager.getActionDisplay(hotkey)
	local data = hotkey.data or {}

	if data.words or normalizeAction(hotkey.action) == HOTKEY_ACTION.SPELL then
		local name = data.words or ""

		if data.parameter and data.parameter ~= "" then
			name = name .. " \"" .. data.parameter:gsub("\"", "") .. "\""
		end

		return {
			color = "#c0c0c0",
			text = name
		}
	end

	local action = normalizeAction(hotkey.action)

	if action == HOTKEY_ACTION.TEXT or action == HOTKEY_ACTION.TEXT_AUTO then
		return {
			color = "#60f8f8",
			text = data.text or ""
		}
	end

	if data.itemId then
		local useType = inferUseType(hotkey.action, data)
		local display = OBJECT_USE_DISPLAY[useType] or OBJECT_USE_DISPLAY.use
		local label = tr(display.label)

		return {
			text = label,
			color = display.color,
			coloredText = string.format("[color=%s]%s[/color]", display.color, label),
			itemId = tonumber(data.itemId) or data.itemId,
			subType = data.subType,
			getTier = data.getTier
		}
	end

	return {
		color = "#c0c0c0",
		text = tr("Action")
	}
end
