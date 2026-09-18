-- chunkname: @/client_options/custom_hotkeys_controller.lua

CustomHotkeys = {}

local ACTION_NAME_LIMIT = 39
local HELPER_SLOT_ID = "customHotkeyAssignHelper"
local pendingPreset, pendingAutoSwitch, presetWindow, keyEditWindow, keyEditOverlay, chatModeGroup, actionSearchEvent, assignHelperSlotWidget
local refreshRetryCount = 0
local activeAssignSession
local _syncingPreset = false
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
local KEY_EDIT_OVERWRITE_TEXT = tr("This hotkey is already in use and will be overwritten.")

local function panel()
	return panels.customHotkeysPanel
end

local function tableWidget()
	local p = panel()

	return p and p.tablePanel and p.tablePanel.hotkeysTable
end

local function getChatMode()
	if not chatModeGroup or not panel() then
		return CHAT_MODE.ON
	end

	if chatModeGroup:getSelectedWidget() == panel().panel.chatMode.on then
		return CHAT_MODE.ON
	end

	return CHAT_MODE.OFF
end

local function isKeyComboUsedOnActionBar(keyCombo)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if Keybind and Keybind.isKeyComboUsedOnActionBar then
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

	if Keybind and Keybind.clearActionBarHotkeyConflicts then
		Keybind.clearActionBarHotkeyConflicts(keyCombo, getChatMode())

		return
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.clearActionBarHotkeyConflicts then
		actionbar.clearActionBarHotkeyConflicts(keyCombo, getChatMode() == CHAT_MODE.ON)
	end
end

local function getCurrentPresetName()
	local p = panel()

	if not p then
		return CustomHotkeyManager.currentPreset
	end

	local option = p.presets.list:getCurrentOption()

	return option and option.text or CustomHotkeyManager.currentPreset
end

local function getKeyEditComboWidget()
	return keyEditWindow and keyEditWindow:recursiveGetChildById("keyCombo")
end

local function getKeyEditUsedWidget()
	return keyEditWindow and keyEditWindow:recursiveGetChildById("used")
end

local function hideOptionsWindow()
	if controller and controller.ui then
		g_modalManager.hide(controller.ui)
		controller.ui:hide()
	end
end

local function showOptionsWindow()
	if controller and controller.ui then
		controller.ui:show()
		g_modalManager.show(controller.ui)
	end
end

local function getAssignHelperSlotWidget()
	if assignHelperSlotWidget and not assignHelperSlotWidget:isDestroyed() then
		return assignHelperSlotWidget
	end

	local ok, widget = pcall(function()
		return g_ui.createWidget("ActionSlot", g_ui.getRootWidget())
	end)

	widget = ok and widget or g_ui.createWidget("UIActionSlot", g_ui.getRootWidget())
	assignHelperSlotWidget = widget

	assignHelperSlotWidget:setId(HELPER_SLOT_ID)
	assignHelperSlotWidget:setVisible(false)
	assignHelperSlotWidget:setPhantom(true)
	assignHelperSlotWidget:breakAnchors()
	assignHelperSlotWidget:setSize({
		1,
		1
	})
	assignHelperSlotWidget:setPosition({
		-1000,
		-1000
	})

	return assignHelperSlotWidget
end

local function clearActionBarExternalAssignContext()
	local ab = modules.game_actionbar

	if not ab then
		CustomHotkeyManager.resumeBindings()

		return
	end

	if ab.closeSpellAssignWindow then
		ab.closeSpellAssignWindow()
	end

	if ab.closeObjectAssignWindow and ab.objectAssignWindow then
		ab.closeObjectAssignWindow()
	end

	if ab.closeTextAssignWindow and ab.textAssignWindow then
		ab.closeTextAssignWindow()
	end

	ab.externalAssignSlot = nil
	ab.externalAssignSlotId = nil
	ab.onExternalSpellAssignApplied = nil
	ab.onExternalObjectAssignApplied = nil
	ab.onExternalTextAssignApplied = nil

	CustomHotkeyManager.resumeBindings()
end

local function beginAssignSession(hotkeyId, isNew, newIndex)
	activeAssignSession = {
		hotkeyId = hotkeyId,
		isNew = isNew,
		newIndex = newIndex
	}
end

local function cancelAssignSession()
	activeAssignSession = nil

	clearActionBarExternalAssignContext()
	showOptionsWindow()
end

local function getDisplayHotkey(hotkeyId, preset, chatMode)
	return CustomHotkeyManager.getHotkeys(chatMode, preset)[hotkeyId]
end

local function isSpellHotkey(hotkey)
	return hotkey and hotkey.action == HOTKEY_ACTION.SPELL
end

local function isObjectHotkey(hotkey)
	if not hotkey or not hotkey.data then
		return false
	end

	local action = hotkey.action

	return action == HOTKEY_ACTION.USE or action == HOTKEY_ACTION.USE_YOURSELF or action == HOTKEY_ACTION.USE_TARGET or action == HOTKEY_ACTION.USE_CROSSHAIR or action == HOTKEY_ACTION.EQUIP or hotkey.data.itemId and hotkey.data.itemId > 100
end

local function isTextHotkey(hotkey)
	if not hotkey then
		return false
	end

	return hotkey.action == HOTKEY_ACTION.TEXT or hotkey.action == HOTKEY_ACTION.TEXT_AUTO
end

local function objectSlotToHotkeyAction(slot)
	local useType = slot.useType or "use"
	local data = {
		itemId = slot.itemId,
		subType = slot.subType,
		getTier = slot.getTier,
		useType = useType
	}

	if useType == "useAtCursor" then
		data.useAtCursor = true
	end

	local action = USE_TYPE_TO_ACTION[useType] or HOTKEY_ACTION.USE

	return action, data
end

local function hotkeyToUseType(hotkey)
	if not hotkey then
		return "use"
	end

	if hotkey.data and hotkey.data.useType then
		return hotkey.data.useType
	end

	if hotkey.data and hotkey.data.useAtCursor then
		return "useAtCursor"
	end

	return ACTION_TO_USE_TYPE[hotkey.action] or "use"
end

local function clearHelperSlot(helper)
	helper.words = nil
	helper.parameter = nil
	helper.text = nil
	helper.itemId = nil
	helper.subType = nil
	helper.useType = nil
	helper.getTier = nil

	if helper.setItemId then
		helper:setItemId(0)
	end
end

local function parseTextAssignPayload(text, autoSend)
	local checkForParameter = text:split(" \"")
	local name, parameter

	if #checkForParameter == 2 then
		name = checkForParameter[1]
		parameter = checkForParameter[2]
	else
		name = text
		parameter = nil
	end

	local spell, profile, spellName = Spells.getSpellByWords(name)

	if spellName and spell then
		return HOTKEY_ACTION.SPELL, {
			words = spell.words,
			parameter = parameter and spell.parameter and parameter or nil
		}
	end

	local action = autoSend and HOTKEY_ACTION.TEXT_AUTO or HOTKEY_ACTION.TEXT

	return action, {
		text = text
	}
end

local function finishAssignSession(action, data)
	if not activeAssignSession then
		return
	end

	local session = activeAssignSession

	activeAssignSession = nil

	local preset = getCurrentPresetName()
	local chatMode = getChatMode()

	if session.isNew or type(session.hotkeyId) ~= "number" then
		CustomHotkeyManager.newHotkey(action, data, "", "", chatMode, preset)
	else
		CustomHotkeyManager.editHotkeyAction(session.hotkeyId, action, data, chatMode, preset)
	end

	clearActionBarExternalAssignContext()
	showOptionsWindow()
	CustomHotkeys.refreshPanel()
end

local function beginAssignSessionForHotkey(hotkeyId, isNew, defaultAction)
	isNew = isNew or hotkeyId == nil

	if isNew or hotkeyId == nil then
		beginAssignSession(nil, true, nil)
	else
		beginAssignSession(hotkeyId, false, nil)
	end

	CustomHotkeyManager.suspendBindings()

	return activeAssignSession and activeAssignSession.hotkeyId or hotkeyId
end

local function setupExternalSpellAssignButtons(ab)
	local win = ab.spellAssignWindow

	if not win then
		return
	end

	local cancelBtn = win:getChildById("cancelButton")

	if cancelBtn then
		cancelBtn.onClick = cancelAssignSession
	end

	win.onEscape = cancelAssignSession

	local okBtn = win:getChildById("okButton")

	if okBtn then
		function okBtn.onClick()
			if ab.spellAssignOk then
				ab.spellAssignOk()
			end
		end
	end

	local applyBtn = win:getChildById("applyButton")

	if applyBtn then
		function applyBtn.onClick()
			if ab.spellAssignApply then
				ab.spellAssignApply(false)
			end

			if ab.closeSpellAssignWindow then
				ab.closeSpellAssignWindow()
			end
		end
	end
end

local function setupExternalTextAssignButtons(ab)
	local win = ab.textAssignWindow

	if not win then
		return
	end

	local cancelBtn = win:getChildById("cancelButton")

	if cancelBtn then
		cancelBtn.onClick = cancelAssignSession
	end

	win.onEscape = cancelAssignSession

	local okBtn = win:getChildById("okButton")

	if okBtn then
		function okBtn.onClick()
			if ab.textAssignOk then
				ab.textAssignOk()
			end
		end
	end

	local applyBtn = win:getChildById("applyButton")

	if applyBtn then
		function applyBtn.onClick()
			if ab.textAssignApply then
				ab.textAssignApply()
			end

			if ab.closeTextAssignWindow then
				ab.closeTextAssignWindow()
			end
		end
	end
end

local function setupExternalObjectAssignButtons(ab)
	local win = ab.objectAssignWindow

	if not win then
		return
	end

	local cancelBtn = win:getChildById("cancelButton")

	if cancelBtn then
		cancelBtn.onClick = cancelAssignSession
	end

	win.onEscape = cancelAssignSession

	local okBtn = win:getChildById("okButton")

	if okBtn then
		function okBtn.onClick()
			if ab.objectAssignOk then
				ab.objectAssignOk()
			end
		end
	end

	local applyBtn = win:getChildById("applyButton")

	if applyBtn then
		function applyBtn.onClick()
			if ab.objectAssignApply then
				ab.objectAssignApply()
			end
		end
	end
end

local function setHotkeyColumnText(hotkeyId, columnIndex, text)
	local dataSpace = tableWidget() and tableWidget().dataSpace

	if not dataSpace then
		return
	end

	for _, row in ipairs(dataSpace:getChildren()) do
		if row.hotkeyId == hotkeyId then
			local column = row:getChildByIndex(columnIndex)

			if column then
				column:setText(text or "")
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

	local hotkeyId = keyEditWindow.hotkeyId
	local numericHotkeyId = type(hotkeyId) == "number" and hotkeyId or nil
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local used = CustomHotkeyManager.isKeyComboUsed(keyCombo, numericHotkeyId, chatMode, preset)
	local actionBarUsed = isKeyComboUsedOnActionBar(keyCombo)
	local reserved = g_keyboard.isReservedMovementHotkey(keyCombo)
	local showWarning = keyCombo ~= "" and (reserved or used or actionBarUsed)
	local usedWidget = getKeyEditUsedWidget()

	if usedWidget then
		if reserved then
			usedWidget:setText(g_keyboard.getReservedHotkeyErrorText())
		else
			usedWidget:setText(KEY_EDIT_OVERWRITE_TEXT)
		end

		usedWidget:setVisible(showWarning)
	end

	if keyEditWindow.buttons and keyEditWindow.buttons.ok then
		if reserved then
			keyEditWindow.buttons.ok:setEnabled(false)
		else
			keyEditWindow.buttons.ok:setEnabled(keyCombo ~= "")
		end
	end
end

local function commitHotkeyKeys(hotkeyId, primary, secondary)
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)
	local newPrimary = primary ~= nil and primary or keys.primary
	local newSecondary = secondary ~= nil and secondary or keys.secondary

	if primary ~= nil and primary ~= "" then
		clearActionBarHotkeyConflicts(primary)
		CustomHotkeyManager.clearKeyComboConflicts(primary, chatMode, preset, hotkeyId)
	end

	if secondary ~= nil and secondary ~= "" then
		clearActionBarHotkeyConflicts(secondary)
		CustomHotkeyManager.clearKeyComboConflicts(secondary, chatMode, preset, hotkeyId)
	end

	CustomHotkeyManager.editHotkeyKeys(hotkeyId, newPrimary, newSecondary, chatMode, preset)
	CustomHotkeys.refreshPanel()
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

	keyEditOverlay = g_ui.createWidget("UIWidget", g_ui.getRootWidget())

	keyEditOverlay:setId("customHotkeyEditCaptureOverlay")
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

local function closeKeyEditWindow()
	if keyEditWindow then
		disconnect(keyEditWindow, {
			onKeyDown = CustomHotkeys.editKeyDown
		})

		keyEditWindow.onMousePress = nil
		keyEditWindow.onMouseWheel = nil

		if keyEditWindow:isVisible() then
			keyEditWindow:hide()
			keyEditWindow:ungrabKeyboard()
		end
	end

	destroyKeyEditOverlay()

	keyEditWindow.hotkeyId = nil

	showOptionsWindow()
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
	connect(keyEditWindow, {
		onKeyDown = CustomHotkeys.editKeyDown
	})

	keyEditWindow.onMousePress = CustomHotkeys.editMousePress
	keyEditWindow.onMouseWheel = CustomHotkeys.editMouseWheel

	if keyEditOverlay then
		function keyEditOverlay.onMousePress(_, mousePos, mouseButton)
			return CustomHotkeys.editMousePress(keyEditWindow, mousePos, mouseButton)
		end

		function keyEditOverlay.onMouseWheel(_, mousePos, direction)
			return CustomHotkeys.editMouseWheel(keyEditWindow, mousePos, direction)
		end

		keyEditOverlay:grabMouse()
		keyEditOverlay:raise()
	end

	keyEditWindow:raise()
	keyEditWindow:focus()
	keyEditWindow:grabKeyboard()
	hideOptionsWindow()
end

function CustomHotkeys.cancelKeyEditWindow()
	closeKeyEditWindow()
end

function CustomHotkeys.editMousePress(widget, mousePos, mouseButton)
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

function CustomHotkeys.editMouseWheel(widget, mousePos, direction)
	local keyCombo = g_mouse.wheelDirectionToHotkeyDesc(direction)

	if not keyCombo then
		return false
	end

	widget:raise()
	widget:focus()
	applyKeyEditCombo(keyCombo)

	return true
end

function CustomHotkeys.editKeyDown(widget, keyCode, keyboardModifiers, keyText)
	widget:raise()
	widget:focus()

	local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers, keyText)

	applyKeyEditCombo(keyCombo)

	return true
end

local function addHotkeyRow(hotkey, hotkeyId, preset, chatMode)
	local display = CustomHotkeyManager.getActionDisplay(hotkey)
	local text = display.text or ""
	local tooltip

	if text:len() > ACTION_NAME_LIMIT then
		tooltip = text
		text = text:sub(1, ACTION_NAME_LIMIT) .. "..."
	end

	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)
	local firstColumn = {
		style = "EditableCustomHotkeysTableColumn",
		width = 288
	}

	if display.coloredText then
		firstColumn.coloredText = {
			text = display.coloredText,
			color = display.color or "#c0c0c0"
		}
	else
		firstColumn.text = text
		firstColumn.color = display.color or "#c0c0c0"
	end

	local row = tableWidget():addRow({
		firstColumn,
		{
			style = "VerticalSeparator"
		},
		{
			width = 98,
			style = "EditableCustomHotkeysTableColumn",
			text = keys.primary
		},
		{
			style = "VerticalSeparator"
		},
		{
			width = 102,
			style = "EditableCustomHotkeysTableColumn",
			text = keys.secondary
		}
	})

	if not row then
		return
	end

	row.hotkeyId = hotkeyId

	if tooltip then
		row:setTooltip(tooltip)
	end

	local actionColumn = row:getChildByIndex(1)

	if actionColumn then
		if actionColumn.item then
			if display.itemId and display.itemId > 100 then
				local item = display.subType and Item.create(display.itemId, display.subType) or Item.create(display.itemId)

				if item then
					if display.getTier and item.setTier then
						item:setTier(display.getTier)
					end

					actionColumn.item:setItem(item)
				else
					actionColumn.item:setItemId(display.itemId)
				end

				if actionColumn.item.setFixedItemSize then
					actionColumn.item:setFixedItemSize(false)
				end

				if actionColumn.item.setShowCount then
					actionColumn.item:setShowCount(false)
				end

				actionColumn.item:setVisible(true)
				actionColumn:setTextOffset({
					y = 2,
					x = 21
				})
			else
				actionColumn.item:setItem(nil)
				actionColumn.item:setVisible(false)
				actionColumn:setTextOffset({
					y = 2,
					x = 2
				})
			end
		end

		if actionColumn.edit then
			function actionColumn.edit.onClick(button)
				CustomHotkeys.showHotkeyActionMenu(button)
			end
		end
	end

	local primaryColumn = row:getChildByIndex(3)
	local secondaryColumn = row:getChildByIndex(5)

	if primaryColumn and primaryColumn.edit then
		function primaryColumn.edit.onClick(button)
			CustomHotkeys.editHotkeyPrimary(button)
		end
	end

	if secondaryColumn and secondaryColumn.edit then
		function secondaryColumn.edit.onClick(button)
			CustomHotkeys.editHotkeySecondary(button)
		end
	end
end

function CustomHotkeys.refreshPanel()
	local p = panel()
	local tableRef = tableWidget()

	if not p or not tableRef then
		return
	end

	if not tableRef.dataSpace then
		if refreshRetryCount < 30 then
			refreshRetryCount = refreshRetryCount + 1

			addEvent(function()
				CustomHotkeys.refreshPanel()
			end)
		else
			g_logger.warning("Custom Hotkeys table is not ready to display rows")
		end

		return
	end

	refreshRetryCount = 0

	if keyEditWindow and keyEditWindow:isVisible() then
		closeKeyEditWindow()
	end

	tableRef:clearData()

	local chatMode = getChatMode()
	local preset = getCurrentPresetName()

	for id, hotkey in ipairs(CustomHotkeyManager.getHotkeys(chatMode, preset)) do
		local displayHotkey = getDisplayHotkey(id, preset, chatMode)

		if displayHotkey then
			addHotkeyRow(displayHotkey, id, preset, chatMode)
		end
	end
end

function CustomHotkeys.showHotkeyActionMenu(button)
	local row = button:getParent():getParent()
	local hotkeyId = row.hotkeyId
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local hotkey = getDisplayHotkey(hotkeyId, preset, chatMode)
	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)

	local hasSpell = isSpellHotkey(hotkey)
	local hasObject = isObjectHotkey(hotkey)

	menu:addOption(hasSpell and tr("Edit Spell") or tr("Assign Spell"), function()
		CustomHotkeys.assignSpell(hotkeyId, false)
	end)
	menu:addOption(hasObject and tr("Edit Object") or tr("Assign Object"), function()
		CustomHotkeys.assignObject(hotkeyId, false)
	end)
	menu:addOption(tr("Assign Text"), function()
		CustomHotkeys.assignText(hotkeyId, false)
	end)
	menu:addSeparator()
	menu:addOption(tr("Clear Action"), function()
		CustomHotkeys.clearHotkeyAction(hotkeyId)
	end)
	menu:display(g_window.getMousePosition())
end

function CustomHotkeys.clearHotkeyAction(hotkeyId)
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()

	CustomHotkeyManager.removeHotkey(hotkeyId, chatMode, preset)
	CustomHotkeys.refreshPanel()
end

function CustomHotkeys.newAction()
	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)
	menu:addOption(tr("Assign Spell"), function()
		CustomHotkeys.assignSpell(nil, true)
	end)
	menu:addOption(tr("Assign Object"), function()
		CustomHotkeys.assignObject(nil, true)
	end)
	menu:addOption(tr("Assign Text"), function()
		CustomHotkeys.assignText(nil, true)
	end)
	menu:display(g_window.getMousePosition())
end

function CustomHotkeys.assignSpell(hotkeyId, isNew)
	local ab = modules.game_actionbar

	if not ab or not ab.openSpellAssignWindow then
		return
	end

	isNew = isNew or hotkeyId == nil
	hotkeyId = beginAssignSessionForHotkey(hotkeyId, isNew, HOTKEY_ACTION.SPELL)

	hideOptionsWindow()

	local helper = getAssignHelperSlotWidget()

	clearHelperSlot(helper)

	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local hotkey = not isNew and getDisplayHotkey(hotkeyId, preset, chatMode) or nil

	if hotkey and hotkey.data and hotkey.data.words then
		helper.words = hotkey.data.words
		helper.parameter = hotkey.data.parameter
	end

	ab.externalAssignSlot = helper
	ab.externalAssignSlotId = HELPER_SLOT_ID
	ab.slotToEdit = HELPER_SLOT_ID

	function ab.onExternalSpellAssignApplied(slot)
		if not activeAssignSession then
			return
		end

		if slot and slot.words and slot.words ~= "" then
			finishAssignSession(HOTKEY_ACTION.SPELL, {
				words = slot.words,
				parameter = slot.parameter
			})
		end
	end

	ab.openSpellAssignWindow()
	setupExternalSpellAssignButtons(ab)
end

function CustomHotkeys.assignObject(hotkeyId, isNew)
	local ab = modules.game_actionbar

	if not ab or not ab.openObjectAssignWindow then
		return
	end

	isNew = isNew or hotkeyId == nil
	hotkeyId = beginAssignSessionForHotkey(hotkeyId, isNew, HOTKEY_ACTION.USE)

	hideOptionsWindow()

	local helper = getAssignHelperSlotWidget()

	clearHelperSlot(helper)

	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local hotkey = not isNew and getDisplayHotkey(hotkeyId, preset, chatMode) or nil

	ab.externalAssignSlot = helper
	ab.externalAssignSlotId = HELPER_SLOT_ID
	ab.slotToEdit = HELPER_SLOT_ID

	function ab.onExternalObjectAssignApplied(slot)
		if not activeAssignSession then
			return
		end

		if slot and slot.itemId and slot.itemId > 100 then
			local action, data = objectSlotToHotkeyAction(slot)

			finishAssignSession(action, data)
		end
	end

	local hasExistingObject = hotkey and hotkey.data and hotkey.data.itemId and hotkey.data.itemId > 100

	if hasExistingObject then
		ab.openObjectAssignWindow()

		local item = Item.create(hotkey.data.itemId)

		if item and hotkey.data.subType then
			item:setSubType(hotkey.data.subType)
		end

		if ab.populateObjectAssignWindowFromItem then
			ab.populateObjectAssignWindowFromItem(item, hotkeyToUseType(hotkey), hotkey.data.getTier)
		end
	else
		if ab.startChooseItem then
			ab.startChooseItem()
		end

		ab.openObjectAssignWindow()
	end

	setupExternalObjectAssignButtons(ab)
end

function CustomHotkeys.assignText(hotkeyId, isNew)
	local ab = modules.game_actionbar

	if not ab or not ab.openTextAssignWindow then
		return
	end

	isNew = isNew or hotkeyId == nil
	hotkeyId = beginAssignSessionForHotkey(hotkeyId, isNew, HOTKEY_ACTION.TEXT)

	hideOptionsWindow()

	local helper = getAssignHelperSlotWidget()

	clearHelperSlot(helper)

	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local hotkey = not isNew and getDisplayHotkey(hotkeyId, preset, chatMode) or nil

	if hotkey and isTextHotkey(hotkey) and hotkey.data then
		helper.text = hotkey.data.text or ""
		helper.autoSend = hotkey.action == HOTKEY_ACTION.TEXT_AUTO
	elseif hotkey and isSpellHotkey(hotkey) and hotkey.data and hotkey.data.words then
		helper.text = hotkey.data.words

		if hotkey.data.parameter and hotkey.data.parameter ~= "" then
			helper.text = helper.text .. " \"" .. hotkey.data.parameter .. "\""
		end

		helper.autoSend = true
	end

	ab.externalAssignSlot = helper
	ab.externalAssignSlotId = HELPER_SLOT_ID
	ab.slotToEdit = HELPER_SLOT_ID

	function ab.onExternalTextAssignApplied(text, autoSend)
		if not activeAssignSession then
			return
		end

		if not text or text:trim() == "" then
			return
		end

		local action, data = parseTextAssignPayload(text, autoSend)

		finishAssignSession(action, data)
	end

	ab.openTextAssignWindow()
	setupExternalTextAssignButtons(ab)

	local textEdit = ab.textAssignWindow and ab.textAssignWindow:getChildById("textToSendTextEdit")

	if textEdit then
		addEvent(function()
			if textEdit and not textEdit:isDestroyed() then
				textEdit:focus()
				textEdit:setCursorPos(-1)
			end
		end)
	end
end

function CustomHotkeys.editHotkeyPrimary(button)
	local row = button:getParent():getParent()
	local hotkeyId = row.hotkeyId
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local label = row:getChildByIndex(1):getText()
	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)

	keyEditWindow.hotkeyId = hotkeyId

	keyEditWindow:setText(tr("Edit Primary Key for '%s'", label))
	getKeyEditComboWidget():setText(keys.primary or "")
	keyEditWindow.info:setText(tr("Click 'Ok' to assign the keybind. Click 'Clear' to remove the keybind from '%s'.", label))
	openKeyEditWindow()

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()

		commitHotkeyKeys(hotkeyId, keyCombo, nil)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		commitHotkeyKeys(hotkeyId, "", nil)
		closeKeyEditWindow()
	end

	keyEditWindow.buttons.cancel.onClick = closeKeyEditWindow
end

function CustomHotkeys.editHotkeySecondary(button)
	local row = button:getParent():getParent()
	local hotkeyId = row.hotkeyId
	local preset = getCurrentPresetName()
	local chatMode = getChatMode()
	local label = row:getChildByIndex(1):getText()
	local keys = CustomHotkeyManager.getHotkeyKeys(hotkeyId, preset, chatMode)

	keyEditWindow.hotkeyId = hotkeyId

	keyEditWindow:setText(tr("Edit Secondary Key for '%s'", label))
	getKeyEditComboWidget():setText(keys.secondary or "")
	keyEditWindow.info:setText(tr("Click 'Ok' to assign the keybind. Click 'Clear' to remove the keybind from '%s'.", label))
	openKeyEditWindow()

	function keyEditWindow.buttons.ok.onClick()
		local keyCombo = getKeyEditComboWidget():getText()

		commitHotkeyKeys(hotkeyId, nil, keyCombo)
		closeKeyEditWindow()
	end

	function keyEditWindow.buttons.clear.onClick()
		commitHotkeyKeys(hotkeyId, nil, "")
		closeKeyEditWindow()
	end

	keyEditWindow.buttons.cancel.onClick = closeKeyEditWindow
end

function CustomHotkeys.searchActions()
	if actionSearchEvent then
		removeEvent(actionSearchEvent)
	end

	actionSearchEvent = scheduleEvent(CustomHotkeys.performSearchActions, 200)
end

function CustomHotkeys.performSearchActions()
	local p = panel()
	local dataSpace = tableWidget() and tableWidget().dataSpace

	if not p or not dataSpace then
		return
	end

	local searchText = p.search.field:getText():trim():lower():gsub("%+", "%%+")
	local rows = dataSpace:getChildren()

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

local function chatModeChange()
	activeAssignSession = nil

	if CustomHotkeyManager and CustomHotkeyManager.setChatMode then
		CustomHotkeyManager.setChatMode(getChatMode())
	end

	local p = panel()

	if p then
		p.search.field:clearText()
	end

	CustomHotkeys.refreshPanel()
end

function CustomHotkeys.addNewPreset()
	presetWindow:setText(tr("Add hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the new preset:"))
	presetWindow.field:clearText()
	presetWindow.field:show()

	presetWindow.action = "add"

	presetWindow:setWidth(360)
	hideOptionsWindow()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function CustomHotkeys.copyPreset()
	presetWindow:setText(tr("Copy hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the new preset:"))
	presetWindow.field:clearText()
	presetWindow.field:show()

	presetWindow.action = "copy"

	presetWindow:setWidth(360)
	hideOptionsWindow()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function CustomHotkeys.renamePreset()
	presetWindow:setText(tr("Rename hotkey preset"))
	presetWindow.info:setText(tr("Enter a name for the preset:"))
	presetWindow.field:setText(getCurrentPresetName())
	presetWindow.field:setCursorPos(1000)
	presetWindow.field:show()

	presetWindow.action = "rename"

	presetWindow:setWidth(360)
	hideOptionsWindow()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
	presetWindow.field:focus()
end

function CustomHotkeys.removePreset()
	presetWindow:setText(tr("Warning"))
	presetWindow.info:setText(tr("Do you really want to delete the hotkey preset %s?", getCurrentPresetName()))
	presetWindow.field:hide()

	presetWindow.action = "remove"

	presetWindow:setWidth(presetWindow.info:getTextSize().width + presetWindow:getPaddingLeft() + presetWindow:getPaddingRight())
	hideOptionsWindow()
	presetWindow:show()
	presetWindow:raise()
	presetWindow:focus()
	g_modalManager.show(presetWindow)
end

local function okPresetWindow()
	local presetName = presetWindow.field:getText():trim()
	local selectedPreset = getCurrentPresetName()

	g_modalManager.hide(presetWindow)
	presetWindow:hide()
	showOptionsWindow()

	local p = panel()

	if not p then
		return
	end

	if presetWindow.action == "add" then
		if CustomHotkeyManager.newPreset(presetName) then
			pendingPreset = presetName

			CustomHotkeys.refreshPresetCombo()
			p.presets.list:setCurrentOption(presetName)
		end
	elseif presetWindow.action == "copy" then
		if CustomHotkeyManager.copyPreset(selectedPreset, presetName) then
			pendingPreset = presetName

			CustomHotkeys.refreshPresetCombo()
			p.presets.list:setCurrentOption(presetName)
		end
	elseif presetWindow.action == "rename" then
		if selectedPreset ~= presetName and CustomHotkeyManager.renamePreset(selectedPreset, presetName) then
			pendingPreset = presetName

			CustomHotkeys.refreshPresetCombo()
		end
	elseif presetWindow.action == "remove" and CustomHotkeyManager.removePreset(selectedPreset) then
		pendingPreset = Keybind and Keybind.currentPreset or CustomHotkeyManager.currentPreset

		CustomHotkeys.refreshPresetCombo()
	end

	if refreshKeybindsPresetCombo then
		refreshKeybindsPresetCombo()
	end

	CustomHotkeys.refreshPanel()
end

local function cancelPresetWindow()
	g_modalManager.hide(presetWindow)
	presetWindow:hide()
	showOptionsWindow()
end

function CustomHotkeys.resetActions()
	local preset = getCurrentPresetName()

	CustomHotkeyManager.resetPresetHotkeys(preset)
	CustomHotkeys.refreshPanel()
end

function CustomHotkeys.revertPending()
	activeAssignSession = nil
	pendingPreset = nil
	pendingAutoSwitch = nil

	local p = panel()

	if not p then
		return
	end

	CustomHotkeys.refreshPresetCombo()

	local autoSwitch = p:recursiveGetChildById("customAutoSwitchPreset")

	if autoSwitch then
		autoSwitch:setChecked(CustomHotkeyManager.getAutoSwitchEnabled())
	end

	if chatModeGroup then
		local widget = CustomHotkeyManager.chatMode == CHAT_MODE.ON and p.panel.chatMode.on or p.panel.chatMode.off

		chatModeGroup:selectWidget(widget, true)
	end

	CustomHotkeys.refreshPanel()
end

function CustomHotkeys.applyPending()
	local p = panel()

	if not p then
		return
	end

	if pendingAutoSwitch ~= nil then
		CustomHotkeyManager.setAutoSwitchEnabled(pendingAutoSwitch)

		pendingAutoSwitch = nil
	end

	if pendingPreset and pendingPreset ~= CustomHotkeyManager.currentPreset then
		CustomHotkeyManager.selectPreset(pendingPreset)

		pendingPreset = nil
	end

	CustomHotkeys.refreshPanel()
end

local function onPresetChanged(comboBox, option)
	pendingPreset = option.text

	if CustomHotkeyManager and CustomHotkeyManager.selectPreset then
		CustomHotkeyManager.selectPreset(option.text)
	end

	CustomHotkeys.refreshPanel()

	if not _syncingPreset and Keybind and Keybind.selectPreset then
		_syncingPreset = true

		local ok, err = pcall(function()
			if Keybind.presetToIndex and Keybind.presetToIndex[option.text] then
				Keybind.selectPreset(option.text)

				local keybindsPanel = panels and panels.keybindsPanel

				if keybindsPanel and keybindsPanel.presets and keybindsPanel.presets.list then
					keybindsPanel.presets.list:setCurrentOption(option.text, true)

					if updateKeybinds then
						updateKeybinds()
					end
				end
			end
		end)

		_syncingPreset = false

		if not ok then
			g_logger.error("Failed to sync General Hotkeys preset: " .. tostring(err))
		end
	end
end

function CustomHotkeys.syncPresetFromGeneral(presetName)
	if not presetName then
		return false
	end

	if _syncingPreset then
		return false
	end

	if not CustomHotkeyManager or not CustomHotkeyManager.presetToIndex or not CustomHotkeyManager.presetToIndex[presetName] then
		return false
	end

	_syncingPreset = true

	local ok, err = pcall(function()
		pendingPreset = presetName

		if CustomHotkeyManager.selectPreset then
			CustomHotkeyManager.selectPreset(presetName)
		end

		local p = panel()

		if p and p.presets and p.presets.list then
			p.presets.list:setCurrentOption(presetName, true)
		end

		CustomHotkeys.refreshPanel()
	end)

	_syncingPreset = false

	if not ok then
		g_logger.error("CustomHotkeys.syncPresetFromGeneral failed: " .. tostring(err))

		return false
	end

	return true
end

function CustomHotkeys.refreshPresetCombo()
	local p = panel()

	if not p or not p.presets or not p.presets.list then
		return
	end

	local combo = p.presets.list
	local currentText = pendingPreset

	if not currentText then
		local opt = combo:getCurrentOption()

		currentText = opt and opt.text or nil
	end

	currentText = currentText or CustomHotkeyManager.currentPreset

	local presets = Keybind and Keybind.presets or CustomHotkeyManager.presets

	if not presets or #presets == 0 then
		return
	end

	combo:clearOptions()

	for _, preset in ipairs(presets) do
		combo:addOption(preset)
	end

	local fallback = Keybind and Keybind.currentPreset or CustomHotkeyManager.currentPreset or presets[1]

	if currentText and CustomHotkeyManager.presetToIndex[currentText] then
		combo:setCurrentOption(currentText, true)
	else
		combo:setCurrentOption(fallback, true)

		pendingPreset = fallback
	end
end

local function onAutoSwitchClicked(widget)
	widget:setChecked(not widget:isChecked())

	pendingAutoSwitch = widget:isChecked()
end

function CustomHotkeys.init()
	CustomHotkeyManager.init()

	local p = panel()

	if not p then
		return
	end

	if not p.panel or not p.panel.chatMode or not p.panel.chatMode.on or not p.panel.chatMode.off then
		g_logger.error("Custom Hotkeys panel is missing chat mode widgets")

		return
	end

	chatModeGroup = UIRadioGroup.create()

	chatModeGroup:addWidget(p.panel.chatMode.on)
	chatModeGroup:addWidget(p.panel.chatMode.off)

	chatModeGroup.onSelectionChange = chatModeChange

	chatModeGroup:selectWidget(p.panel.chatMode.on, true)

	keyEditWindow = g_ui.displayUI("styles/controls/custom_hotkeys_key_edit")

	keyEditWindow:hide()

	function keyEditWindow.onEscape()
		CustomHotkeys.cancelKeyEditWindow()
	end

	if keyEditWindow.buttons and keyEditWindow.buttons.cancel then
		function keyEditWindow.buttons.cancel.onClick()
			CustomHotkeys.cancelKeyEditWindow()
		end
	end

	presetWindow = g_ui.displayUI("styles/controls/custom_hotkeys_preset")

	presetWindow:hide()

	presetWindow.onEnter = okPresetWindow
	presetWindow.onEscape = cancelPresetWindow
	presetWindow.buttons.ok.onClick = okPresetWindow
	presetWindow.buttons.cancel.onClick = cancelPresetWindow

	CustomHotkeys.refreshPresetCombo()

	p.presets.list.onOptionChange = onPresetChanged

	local autoSwitch = p:recursiveGetChildById("customAutoSwitchPreset")

	if autoSwitch then
		autoSwitch:setChecked(CustomHotkeyManager.getAutoSwitchEnabled())

		autoSwitch.onClick = onAutoSwitchClicked
	end

	function p.search.clear.onClick()
		p.search.field:clearText()
	end

	if g_platform.isMobile() then
		p.tablePanel:hide()
	end

	CustomHotkeys.refreshPanel()
end

function CustomHotkeys.terminate()
	if presetWindow then
		presetWindow:destroy()

		presetWindow = nil
	end

	if chatModeGroup then
		chatModeGroup:destroy()

		chatModeGroup = nil
	end

	if keyEditWindow then
		closeKeyEditWindow()
		keyEditWindow:destroy()

		keyEditWindow = nil
	end

	clearActionBarExternalAssignContext()

	activeAssignSession = nil

	CustomHotkeyManager.terminate()

	actionSearchEvent = nil

	if assignHelperSlotWidget and not assignHelperSlotWidget:isDestroyed() then
		assignHelperSlotWidget:destroy()
	end

	assignHelperSlotWidget = nil
end
