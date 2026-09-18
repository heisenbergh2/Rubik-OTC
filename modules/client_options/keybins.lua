-- chunkname: @/client_options/keybins.lua

local actionNameLimit = 39
local changedOptions = {}
local changedKeybinds = {}
local changedHotkeys = {}
local presetWindow, actionSearchEvent, keyEditWindow, keyEditOverlay, chatModeGroup
local _syncingPreset = false

local function getKeyEditComboWidget()
	return keyEditWindow and keyEditWindow:recursiveGetChildById("keyCombo")
end

local function getKeyEditUsedWidget()
	return keyEditWindow and keyEditWindow:recursiveGetChildById("used")
end

local KEY_EDIT_OVERWRITE_TEXT = tr("This hotkey is already in use and will be overwritten.")

local function isKeyComboUsedOnActionBar(keyCombo)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if Keybind.isKeyComboUsedOnActionBar then
		return Keybind.isKeyComboUsedOnActionBar(keyCombo, getChatMode())
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.isKeyComboUsedOnActionBar then
		return actionbar.isKeyComboUsedOnActionBar(keyCombo, getChatMode() == CHAT_MODE.ON)
	end

	return false
end

local function clearActionBarHotkeyConflicts(keyCombo)
	if not keyCombo or keyCombo == "" then
		return
	end

	if Keybind.clearActionBarHotkeyConflicts then
		Keybind.clearActionBarHotkeyConflicts(keyCombo, getChatMode())

		return
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.clearActionBarHotkeyConflicts then
		actionbar.clearActionBarHotkeyConflicts(keyCombo, getChatMode() == CHAT_MODE.ON)
	end
end

local function isKeyComboUsedOnCustomHotkeys(keyCombo)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if Keybind.isKeyComboUsedOnCustomHotkeys then
		return Keybind.isKeyComboUsedOnCustomHotkeys(keyCombo, getChatMode())
	end

	if CustomHotkeyManager and CustomHotkeyManager.isKeyComboUsed then
		return CustomHotkeyManager.isKeyComboUsed(keyCombo, nil, getChatMode())
	end

	return false
end

local function clearCustomHotkeyConflicts(keyCombo)
	if not keyCombo or keyCombo == "" then
		return
	end

	local cleared = false

	if Keybind.clearCustomHotkeyConflicts then
		cleared = Keybind.clearCustomHotkeyConflicts(keyCombo, getChatMode())
	elseif CustomHotkeyManager and CustomHotkeyManager.clearKeyComboConflicts then
		cleared = CustomHotkeyManager.clearKeyComboConflicts(keyCombo, getChatMode())
	end

	if cleared and CustomHotkeys and CustomHotkeys.refreshPanel then
		CustomHotkeys.refreshPanel()
	end
end

local function isKeyComboUsedInPendingKeybinds(keyCombo, category, action, preset)
	if not changedKeybinds[preset] then
		return false
	end

	for _, pending in pairs(changedKeybinds[preset]) do
		if pending.primary and pending.primary.keyCombo == keyCombo and (pending.primary.category ~= category or pending.primary.action ~= action) then
			return true
		end

		if pending.secondary and pending.secondary.keyCombo == keyCombo and (pending.secondary.category ~= category or pending.secondary.action ~= action) then
			return true
		end
	end

	return false
end

local function getPendingKeybindKeys(category, action, preset)
	local keys = Keybind.getKeybindKeys(category, action, getChatMode(), preset, changedOptions.resetKeybinds)
	local index = category .. "_" .. action
	local pending = changedKeybinds[preset] and changedKeybinds[preset][index]

	if pending then
		if pending.primary then
			keys.primary = pending.primary.keyCombo
		end

		if pending.secondary then
			keys.secondary = pending.secondary.keyCombo
		end
	end

	return keys
end

local function setKeybindColumnText(category, action, columnIndex, text)
	local dataSpace = panels.keybindsPanel.tablePanel.keybinds.dataSpace

	if not dataSpace then
		return
	end

	for _, row in ipairs(dataSpace:getChildren()) do
		if row.category == category and row.action == action then
			local column = row:getChildByIndex(columnIndex)

			if column then
				column:setText(text or "")
			end

			break
		end
	end
end

local function setHotkeyColumnText(hotkeyId, columnIndex, text)
	local dataSpace = panels.keybindsPanel.tablePanel.keybinds.dataSpace

	if not dataSpace then
		return
	end

	for _, row in ipairs(dataSpace:getChildren()) do
		if row.hotkeyId == hotkeyId then
			local column = row:getChildByIndex(columnIndex)

			if column then
				column:setText(text)
			end

			break
		end
	end
end

local function updateKeyEditChatModeLabel()
	if not keyEditWindow or not keyEditWindow.chatMode then
		return
	end

	local chatOn = getChatMode() == CHAT_MODE.ON

	keyEditWindow.chatMode:setText(chatOn and tr("Mode: \"Chat On\"") or tr("Mode: \"Chat Off\""))
end

local function applyKeyEditCombo(keyCombo)
	keyCombo = keyCombo or ""

	local comboWidget = getKeyEditComboWidget()

	if not comboWidget then
		return
	end

	comboWidget:setText(keyCombo)
	comboWidget:resizeToText()

	local category, action

	if keyEditWindow.keybind then
		category = keyEditWindow.keybind.category
		action = keyEditWindow.keybind.action
	end

	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
	local keybindUsed = Keybind.isKeyComboUsed(keyCombo, category, action, getChatMode())

	keybindUsed = keybindUsed or isKeyComboUsedInPendingKeybinds(keyCombo, category, action, preset)

	if not keybindUsed then
		for _, change in ipairs(changedHotkeys) do
			if change.primary == keyCombo or change.secondary == keyCombo then
				keybindUsed = true

				break
			end
		end
	end

	local actionBarUsed = isKeyComboUsedOnActionBar(keyCombo)
	local customHotkeyUsed = isKeyComboUsedOnCustomHotkeys(keyCombo)
	local reserved = g_keyboard.isReservedMovementHotkey(keyCombo)
	local showWarning = keyCombo ~= "" and (reserved or keybindUsed or actionBarUsed or customHotkeyUsed)
	local usedWidget = getKeyEditUsedWidget()

	if usedWidget then
		usedWidget:setVisible(showWarning)
	end

	if reserved then
		if usedWidget then
			usedWidget:setText(g_keyboard.getReservedHotkeyErrorText())
		end

		keyEditWindow.buttons.ok:setEnabled(false)
	elseif actionBarUsed or customHotkeyUsed then
		if usedWidget then
			usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		end

		keyEditWindow.buttons.ok:setEnabled(true)
	elseif keybindUsed then
		if usedWidget then
			usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		end

		keyEditWindow.buttons.ok:setEnabled(false)
	else
		if usedWidget then
			usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		end

		keyEditWindow.buttons.ok:setEnabled(keyCombo ~= "")
	end
end

local function detachKeyEditWindow()
	if not keyEditWindow or not keyEditOverlay then
		return
	end

	if keyEditWindow:getParent() == keyEditOverlay then
		keyEditWindow:breakAnchors()
		keyEditWindow:setParent(nil)
	end
end

local function destroyKeyEditOverlay()
	if keyEditOverlay then
		detachKeyEditWindow()

		keyEditOverlay.onMousePress = nil
		keyEditOverlay.onMouseWheel = nil

		keyEditOverlay:ungrabMouse()
		keyEditOverlay:destroy()

		keyEditOverlay = nil
	end
end

local function createKeyEditOverlay()
	destroyKeyEditOverlay()

	local rootW = g_ui.getRootWidget()

	keyEditOverlay = g_ui.createWidget("UIWidget", rootW)

	keyEditOverlay:setId("keyEditCaptureOverlay")
	keyEditOverlay:setFocusable(true)
	keyEditOverlay:setDraggable(false)
	keyEditOverlay:addAnchor(AnchorLeft, "parent", AnchorLeft)
	keyEditOverlay:addAnchor(AnchorRight, "parent", AnchorRight)
	keyEditOverlay:addAnchor(AnchorTop, "parent", AnchorTop)
	keyEditOverlay:addAnchor(AnchorBottom, "parent", AnchorBottom)
end

local function attachKeyEditWindowToOverlay()
	if not keyEditWindow or not keyEditOverlay then
		return
	end

	keyEditWindow:setParent(keyEditOverlay)
	keyEditWindow:breakAnchors()
	keyEditWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	keyEditWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
end

local function connectKeyEditCapture()
	connect(keyEditWindow, {
		onKeyDown = editKeybindKeyDown
	})

	keyEditWindow.onMousePress = editKeybindMousePress
	keyEditWindow.onMouseWheel = editKeybindMouseWheel

	if keyEditOverlay then
		function keyEditOverlay.onMousePress(_, mousePos, mouseButton)
			return editKeybindMousePress(keyEditWindow, mousePos, mouseButton)
		end

		function keyEditOverlay.onMouseWheel(_, mousePos, direction)
			return editKeybindMouseWheel(keyEditWindow, mousePos, direction)
		end
	end
end

local function disconnectKeyEditCapture()
	if not keyEditWindow then
		destroyKeyEditOverlay()

		return
	end

	disconnect(keyEditWindow, {
		onKeyDown = editKeybindKeyDown
	})

	keyEditWindow.onMousePress = nil
	keyEditWindow.onMouseWheel = nil

	destroyKeyEditOverlay()
end

local function clearKeyEditHandlers()
	if not keyEditWindow then
		return
	end

	if keyEditWindow.buttons then
		keyEditWindow.buttons.ok.onClick = nil
		keyEditWindow.buttons.clear.onClick = nil
		keyEditWindow.buttons.cancel.onClick = nil
	end

	keyEditWindow.keybind = nil
end

local function closeKeyEditWindow()
	disconnectKeyEditCapture()
	clearKeyEditHandlers()

	if keyEditWindow and keyEditWindow:isVisible() then
		keyEditWindow:hide()
		keyEditWindow:ungrabKeyboard()
	end

	show()
end

local function openKeyEditWindow()
	createKeyEditOverlay()
	attachKeyEditWindowToOverlay()
	updateKeyEditChatModeLabel()

	local comboWidget = getKeyEditComboWidget()

	if comboWidget then
		comboWidget:resizeToText()
		applyKeyEditCombo(comboWidget:getText())
	end

	keyEditWindow:show()
	connectKeyEditCapture()
	keyEditOverlay:grabMouse()
	keyEditOverlay:raise()
	keyEditWindow:raise()
	keyEditWindow:focus()
	keyEditWindow:grabKeyboard()
	hide()
end

function cancelKeyEditWindow()
	if not keyEditWindow or not keyEditWindow:isVisible() then
		return
	end

	if keyEditWindow.buttons.cancel.onClick then
		keyEditWindow.buttons.cancel.onClick()
	else
		closeKeyEditWindow()
	end
end

function editKeybindMousePress(widget, mousePos, mouseButton)
	if mouseButton == MouseLeftButton or mouseButton == MouseRightButton then
		return false
	end

	local keyCombo = g_mouse.mouseButtonToHotkeyDesc(mouseButton)

	if not keyCombo then
		return false
	end

	widget:raise()
	widget:focus()
	applyKeyEditCombo(keyCombo)

	return true
end

function editKeybindMouseWheel(widget, mousePos, direction)
	local keyCombo = g_mouse.wheelDirectionToHotkeyDesc(direction)

	if not keyCombo then
		return false
	end

	widget:raise()
	widget:focus()
	applyKeyEditCombo(keyCombo)

	return true
end

function addNewPreset()
	presetWindow:setText(tr("Add hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the new preset:"))
	presetWindow.field:clearText()
	presetWindow.field:show()
	presetWindow:setWidth(360)

	presetWindow.action = "add"

	hide()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function copyPreset()
	presetWindow:setText(tr("Copy hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the new preset:"))
	presetWindow.field:clearText()
	presetWindow.field:show()

	presetWindow.action = "copy"

	presetWindow:setWidth(360)
	hide()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function renamePreset()
	presetWindow:setText(tr("Rename hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the preset:"))
	presetWindow.field:setText(panels.keybindsPanel.presets.list:getCurrentOption().text)
	presetWindow.field:setCursorPos(1000)
	presetWindow.field:show()

	presetWindow.action = "rename"

	presetWindow:setWidth(360)
	hide()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function removePreset()
	presetWindow:setText(tr("Warning"))
	presetWindow.info:setText(tr("Do you really want to delete the hotkey preset %s?", panels.keybindsPanel.presets.list:getCurrentOption().text))
	presetWindow.field:hide()

	presetWindow.action = "remove"

	presetWindow:setWidth(presetWindow.info:getTextSize().width + presetWindow:getPaddingLeft() + presetWindow:getPaddingRight())
	hide()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
end

function okPresetWindow()
	local presetName = presetWindow.field:getText():trim()
	local selectedPreset = panels.keybindsPanel.presets.list:getCurrentOption().text

	g_modalManager.hide(presetWindow)
	presetWindow:hide()
	show()

	if presetWindow.action == "add" then
		Keybind.newPreset(presetName)
		panels.keybindsPanel.presets.list:addOption(presetName)
		panels.keybindsPanel.presets.list:setCurrentOption(presetName)
	elseif presetWindow.action == "copy" then
		if not Keybind.copyPreset(selectedPreset, presetName) then
			return
		end

		panels.keybindsPanel.presets.list:addOption(presetName)
		panels.keybindsPanel.presets.list:setCurrentOption(presetName)

		if modules.game_actionbar and modules.game_actionbar.copyActionBarPreset then
			modules.game_actionbar.copyActionBarPreset(selectedPreset, presetName)
		end
	elseif presetWindow.action == "rename" then
		if selectedPreset ~= presetName then
			panels.keybindsPanel.presets.list:updateCurrentOption(presetName)

			if changedOptions.currentPreset then
				changedOptions.currentPreset.value = presetName
			end

			Keybind.renamePreset(selectedPreset, presetName)

			if modules.game_actionbar and modules.game_actionbar.renameActionBarPreset then
				modules.game_actionbar.renameActionBarPreset(selectedPreset, presetName)
			end
		end
	elseif presetWindow.action == "remove" and Keybind.removePreset(selectedPreset) then
		panels.keybindsPanel.presets.list:removeOption(selectedPreset)

		if modules.game_actionbar and modules.game_actionbar.removeActionBarPreset then
			modules.game_actionbar.removeActionBarPreset(selectedPreset)
		end
	end

	if CustomHotkeys and CustomHotkeys.refreshPresetCombo then
		CustomHotkeys.refreshPresetCombo()
	end
end

function cancelPresetWindow()
	g_modalManager.hide(presetWindow)
	presetWindow:hide()
	show()
end

function editKeybindKeyDown(widget, keyCode, keyboardModifiers, keyText)
	keyEditWindow:raise()
	keyEditWindow:focus()

	local keyCombo = determineKeyComboDesc(keyCode, keyEditWindow.alone:isVisible() and KeyboardNoModifier or keyboardModifiers, keyText)

	applyKeyEditCombo(keyCombo)

	return true
end

function editKeybind(keybind)
	keyEditWindow.buttons.cancel.onClick = closeKeyEditWindow

	keyEditWindow.info:setText(tr("Click 'Ok' to assign the keybind. Click 'Clear' to remove the keybind from '%s: %s'.", keybind.category, keybind.action))
	keyEditWindow.alone:setVisible(keybind.alone)

	local usedWidget = getKeyEditUsedWidget()

	if usedWidget then
		usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		usedWidget:setVisible(false)
	end

	keyEditWindow.buttons.ok:setEnabled(true)
	openKeyEditWindow()
end

function editKeybindPrimary(button)
	local row = button:getParent():getParent()
	local category = row.category
	local action = row.action
	local index = category .. "_" .. action
	local keybind = Keybind.getAction(category, action)
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

	keyEditWindow.keybind = {
		category = category,
		action = action
	}

	keyEditWindow:setText(tr("Edit Primary Key for '%s'", string.format("%s: %s", keybind.category, keybind.action)))
	getKeyEditComboWidget():setText(Keybind.getKeybindKeys(category, action, getChatMode(), preset).primary)
	editKeybind(keybind)

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()

		if not changedKeybinds[preset] then
			changedKeybinds[preset] = {}
		end

		if not changedKeybinds[preset][index] then
			changedKeybinds[preset][index] = {}
		end

		changedKeybinds[preset][index].primary = {
			category = category,
			action = action,
			keyCombo = keyCombo
		}

		setKeybindColumnText(category, action, 3, keyCombo)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		if not changedKeybinds[preset] then
			changedKeybinds[preset] = {}
		end

		if not changedKeybinds[preset][index] then
			changedKeybinds[preset][index] = {}
		end

		changedKeybinds[preset][index].primary = {
			keyCombo = "",
			category = category,
			action = action
		}

		setKeybindColumnText(category, action, 3, "")
		closeKeyEditWindow()
	end
end

function editKeybindSecondary(button)
	local row = button:getParent():getParent()
	local category = row.category
	local action = row.action
	local index = category .. "_" .. action
	local keybind = Keybind.getAction(category, action)
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

	keyEditWindow.keybind = {
		category = category,
		action = action
	}

	keyEditWindow:setText(tr("Edit Secondary Key for '%s'", string.format("%s: %s", keybind.category, keybind.action)))
	getKeyEditComboWidget():setText(Keybind.getKeybindKeys(category, action, getChatMode(), preset).secondary)
	editKeybind(keybind)

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()

		if not changedKeybinds[preset] then
			changedKeybinds[preset] = {}
		end

		if not changedKeybinds[preset][index] then
			changedKeybinds[preset][index] = {}
		end

		changedKeybinds[preset][index].secondary = {
			category = category,
			action = action,
			keyCombo = keyCombo
		}

		setKeybindColumnText(category, action, 5, keyCombo)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		if not changedKeybinds[preset] then
			changedKeybinds[preset] = {}
		end

		if not changedKeybinds[preset][index] then
			changedKeybinds[preset][index] = {}
		end

		changedKeybinds[preset][index].secondary = {
			keyCombo = "",
			category = category,
			action = action
		}

		setKeybindColumnText(category, action, 5, "")
		closeKeyEditWindow()
	end
end

function resetActions()
	changedOptions.resetKeybinds = {
		value = panels.keybindsPanel.presets.list:getCurrentOption().text
	}

	updateKeybinds()
	applyChangedOptions()
end

function updateKeybinds()
	if keyEditWindow and keyEditWindow:isVisible() then
		closeKeyEditWindow()
	end

	panels.keybindsPanel.tablePanel.keybinds:clearData()

	local sortedKeybinds = {}

	for index, _ in pairs(Keybind.defaultKeybinds) do
		table.insert(sortedKeybinds, index)
	end

	table.sort(sortedKeybinds, function(a, b)
		local keybindA = Keybind.defaultKeybinds[a]
		local keybindB = Keybind.defaultKeybinds[b]

		if keybindA.category ~= keybindB.category then
			return keybindA.category < keybindB.category
		end

		return keybindA.action < keybindB.action
	end)

	local comboBox = panels.keybindsPanel.presets.list:getCurrentOption()

	if not comboBox then
		return
	end

	for _, index in ipairs(sortedKeybinds) do
		local keybind = Keybind.defaultKeybinds[index]
		local keys = getPendingKeybindKeys(keybind.category, keybind.action, comboBox.text)

		addKeybind(keybind.category, keybind.action, keys.primary, keys.secondary)
	end
end

function updateHotkeys()
	if keyEditWindow and keyEditWindow:isVisible() then
		closeKeyEditWindow()
	end

	panels.keybindsPanel.tablePanel.keybinds:clearData()

	local chatMode = getChatMode()
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

	if Keybind.hotkeys[chatMode][preset] then
		for _, hotkey in ipairs(Keybind.hotkeys[chatMode][preset]) do
			addHotkey(hotkey.hotkeyId, hotkey.action, hotkey.data, hotkey.primary, hotkey.secondary)
		end
	end
end

function preAddHotkey(action, data)
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
	local chatMode = getChatMode()
	local hotkeyId = #changedHotkeys + 1

	if Keybind.hotkeys[chatMode] and Keybind.hotkeys[chatMode][preset] then
		hotkeyId = hotkeyId + #Keybind.hotkeys[chatMode][preset]
	end

	table.insert(changedHotkeys, {
		new = true,
		hotkeyId = hotkeyId,
		action = action,
		data = data
	})
	addHotkey(hotkeyId, action, data)
end

function addKeybind(category, action, primary, secondary)
	local rawText = string.format("%s: %s", category, action)
	local text = string.format("[color=#ffffff]%s:[/color] %s", category, action)
	local tooltip

	if rawText:len() > actionNameLimit then
		tooltip = rawText
		text = text:sub(1, actionNameLimit + 15 + 8) .. "..."
	end

	local row = panels.keybindsPanel.tablePanel.keybinds:addRow({
		{
			width = 288,
			coloredText = {
				color = "#c0c0c0",
				text = text
			}
		},
		{
			style = "VerticalSeparator"
		},
		{
			width = 98,
			style = "EditableKeybindsTableColumn",
			text = primary
		},
		{
			style = "VerticalSeparator"
		},
		{
			width = 102,
			style = "EditableKeybindsTableColumn",
			text = secondary
		}
	})

	row.category = category
	row.action = action

	if tooltip then
		row:setTooltip(tooltip)
	end

	row:getChildByIndex(3).edit.onClick = editKeybindPrimary
	row:getChildByIndex(5).edit.onClick = editKeybindSecondary
end

function clearHotkey(row)
	table.insert(changedHotkeys, {
		remove = true,
		hotkeyId = row.hotkeyId
	})
	panels.keybindsPanel.tablePanel.keybinds:removeRow(row)
end

function editHotkeyKey(text)
	keyEditWindow.buttons.cancel.onClick = closeKeyEditWindow

	keyEditWindow.info:setText(tr("Click 'Ok' to assign the keybind. Click 'Clear' to remove the keybind from '%s'.", text))
	keyEditWindow.alone:setVisible(false)

	local usedWidget = getKeyEditUsedWidget()

	if usedWidget then
		usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		usedWidget:setVisible(false)
	end

	keyEditWindow.buttons.ok:setEnabled(true)
	openKeyEditWindow()
end

function editHotkeyPrimary(button)
	local row = button:getParent():getParent()
	local text = row:getChildByIndex(1):getText()
	local hotkeyId = row.hotkeyId
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

	keyEditWindow:setText(tr("Edit Primary Key for '%s'", text))
	getKeyEditComboWidget():setText(Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary)
	editHotkeyKey(text)

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()
		local changed = table.findbyfield(changedHotkeys, "hotkeyId", hotkeyId)

		if changed then
			changed.primary = keyCombo

			if not changed.secondary then
				changed.secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
			end

			changed.editKey = true
		else
			table.insert(changedHotkeys, {
				editKey = true,
				hotkeyId = hotkeyId,
				primary = keyCombo,
				secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
			})
		end

		setHotkeyColumnText(hotkeyId, 3, keyCombo)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		local changed = table.findbyfield(changedHotkeys, "hotkeyId", hotkeyId)

		if changed then
			changed.primary = nil

			if not changed.secondary then
				changed.secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
			end

			changed.editKey = true
		else
			table.insert(changedHotkeys, {
				editKey = true,
				hotkeyId = hotkeyId,
				secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
			})
		end

		setHotkeyColumnText(hotkeyId, 3, "")
		closeKeyEditWindow()
	end
end

function editHotkeySecondary(button)
	local row = button:getParent():getParent()
	local text = row:getChildByIndex(1):getText()
	local hotkeyId = row.hotkeyId
	local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

	keyEditWindow:setText(tr("Edit Secondary Key for '%s'", text))
	getKeyEditComboWidget():setText(Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary)
	editHotkeyKey(text)

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()

		if changedHotkeys[hotkeyId] then
			if not changedHotkeys[hotkeyId].primary then
				changedHotkeys[hotkeyId].primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary
			end

			changedHotkeys[hotkeyId].secondary = keyCombo
			changedHotkeys[hotkeyId].editKey = true
		else
			table.insert(changedHotkeys, {
				editKey = true,
				hotkeyId = hotkeyId,
				primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary,
				secondary = keyCombo
			})
		end

		setHotkeyColumnText(hotkeyId, 5, keyCombo)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		if changedHotkeys[hotkeyId] then
			if not changedHotkeys[hotkeyId].primary then
				changedHotkeys[hotkeyId].primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary
			end

			changedHotkeys[hotkeyId].secondary = nil
			changedHotkeys[hotkeyId].editKey = true
		else
			table.insert(changedHotkeys, {
				editKey = true,
				hotkeyId = hotkeyId,
				primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary
			})
		end

		setHotkeyColumnText(hotkeyId, 5, "")
		closeKeyEditWindow()
	end
end

function searchActions(field, text, oldText)
	if actionSearchEvent then
		removeEvent(actionSearchEvent)
	end

	actionSearchEvent = scheduleEvent(performeSearchActions, 200)
end

function performeSearchActions()
	local searchText = panels.keybindsPanel.search.field:getText():trim():lower():gsub("%+", "%%+")
	local rows = panels.keybindsPanel.tablePanel.keybinds.dataSpace:getChildren()

	if searchText:len() > 0 then
		for _, row in ipairs(rows) do
			row:hide()
		end

		for _, row in ipairs(rows) do
			local actionText = row:getChildByIndex(1):getText():lower()
			local primaryText = row:getChildByIndex(3):getText():lower()
			local secondaryText = row:getChildByIndex(5):getText():lower()

			if actionText:find(searchText) or primaryText:find(searchText) or secondaryText:find(searchText) then
				row:show()
			end
		end
	else
		for _, row in ipairs(rows) do
			row:show()
		end
	end

	removeEvent(actionSearchEvent)

	actionSearchEvent = nil
end

function chatModeChange()
	changedHotkeys = {}
	changedKeybinds = {}

	panels.keybindsPanel.search.field:clearText()
	updateKeybinds()
end

function getChatMode()
	if chatModeGroup:getSelectedWidget() == panels.keybindsPanel.panel.chatMode.on then
		return CHAT_MODE.ON
	end

	return CHAT_MODE.OFF
end

function revertKeybindChanges()
	changedKeybinds = {}
	changedHotkeys = {}

	if changedOptions.resetKeybinds then
		changedOptions.resetKeybinds = nil
	end

	updateKeybinds()
end

function applyChangedOptions()
	local needKeybindsUpdate = false
	local needHotkeysUpdate = false

	for key, option in pairs(changedOptions) do
		if key == "resetKeybinds" then
			Keybind.resetKeybindsToDefault(option.value, option.chatMode)

			needKeybindsUpdate = true
		end
	end

	changedOptions = {}

	for preset, keybinds in pairs(changedKeybinds) do
		for index, keybind in pairs(keybinds) do
			if keybind.primary then
				clearActionBarHotkeyConflicts(keybind.primary.keyCombo)
				clearCustomHotkeyConflicts(keybind.primary.keyCombo)

				if Keybind.setPrimaryActionKey(keybind.primary.category, keybind.primary.action, preset, keybind.primary.keyCombo, getChatMode()) then
					needKeybindsUpdate = true
				end
			elseif keybind.secondary then
				clearActionBarHotkeyConflicts(keybind.secondary.keyCombo)
				clearCustomHotkeyConflicts(keybind.secondary.keyCombo)

				if Keybind.setSecondaryActionKey(keybind.secondary.category, keybind.secondary.action, preset, keybind.secondary.keyCombo, getChatMode()) then
					needKeybindsUpdate = true
				end
			end
		end
	end

	changedKeybinds = {}

	if needKeybindsUpdate then
		updateKeybinds()
	end

	g_settings.save()
end

function presetOption(widget, key, value, force)
	if not controller.ui:isVisible() then
		return
	end

	changedOptions[key] = {
		widget = widget,
		value = value,
		force = force
	}

	if key == "currentPreset" then
		Keybind.selectPreset(value)
		panels.keybindsPanel.presets.list:setCurrentOption(value, true)
	end
end

function init_binds()
	chatModeGroup = UIRadioGroup.create()

	chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.on)
	chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.off)

	chatModeGroup.onSelectionChange = chatModeChange

	chatModeGroup:selectWidget(panels.keybindsPanel.panel.chatMode.on)

	keyEditWindow = g_ui.displayUI("styles/controls/key_edit")

	keyEditWindow:hide()

	presetWindow = g_ui.displayUI("styles/controls/preset")

	presetWindow:hide()

	panels.keybindsPanel.presets.add.onClick = addNewPreset
	panels.keybindsPanel.presets.copy.onClick = copyPreset
	panels.keybindsPanel.presets.rename.onClick = renamePreset
	panels.keybindsPanel.presets.remove.onClick = removePreset

	panels.keybindsPanel.buttons.newAction:disable()

	panels.keybindsPanel.buttons.newAction.onClick = newHotkeyAction
	panels.keybindsPanel.buttons.reset.onClick = resetActions
	panels.keybindsPanel.search.field.onTextChange = searchActions

	function panels.keybindsPanel.search.clear.onClick()
		panels.keybindsPanel.search.field:clearText()
	end

	presetWindow.onEnter = okPresetWindow
	presetWindow.onEscape = cancelPresetWindow
	presetWindow.buttons.ok.onClick = okPresetWindow
	presetWindow.buttons.cancel.onClick = cancelPresetWindow

	if g_platform.isMobile() then
		panels.keybindsPanel.tablePanel:hide()
	end
end

function terminate_binds()
	if presetWindow then
		presetWindow:destroy()

		presetWindow = nil
	end

	if chatModeGroup then
		chatModeGroup:destroy()

		chatModeGroup = nil
	end

	if keyEditWindow then
		if keyEditWindow:isVisible() then
			disconnectKeyEditCapture()
			keyEditWindow:ungrabKeyboard()
		end

		destroyKeyEditOverlay()
		keyEditWindow:destroy()

		keyEditWindow = nil
	end

	actionSearchEvent = nil
end

function listKeybindsComboBox(value)
	local widget = panels.keybindsPanel.presets.list

	presetOption(widget, "currentPreset", value, false)

	changedKeybinds = {}
	changedHotkeys = {}

	applyChangedOptions()
	updateKeybinds()

	if not _syncingPreset and CustomHotkeys and CustomHotkeys.syncPresetFromGeneral then
		_syncingPreset = true

		local ok, err = pcall(CustomHotkeys.syncPresetFromGeneral, value)

		_syncingPreset = false

		if not ok then
			g_logger.error("Failed to sync Custom Hotkeys preset: " .. tostring(err))
		end
	end
end

function isSyncingPreset()
	return _syncingPreset
end

function setSyncingPreset(value)
	_syncingPreset = value and true or false
end

function refreshKeybindsPresetCombo()
	if not panels or not panels.keybindsPanel or not panels.keybindsPanel.presets or not panels.keybindsPanel.presets.list then
		return
	end

	local combo = panels.keybindsPanel.presets.list
	local opt = combo:getCurrentOption()
	local currentText = opt and opt.text or Keybind.currentPreset

	combo:clearOptions()

	for _, preset in ipairs(Keybind.presets) do
		combo:addOption(preset)
	end

	if Keybind.presetToIndex[currentText] then
		combo:setCurrentOption(currentText, true)
	else
		combo:setCurrentOption(Keybind.currentPreset, true)
	end
end

function debug()
	local currentOptionText = Keybind.currentPreset
	local chatMode = Keybind.chatMode
	local chatModeText = chatMode == 1 and "Chat mode ON" or chatMode == 2 and "Chat mode OFF" or "Unknown chat mode"

	print(string.format("The current configuration is: %s, and the mode is: %s", currentOptionText, chatModeText))
end
