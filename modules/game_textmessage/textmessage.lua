-- chunkname: @/game_textmessage/textmessage.lua

MessageSettings = {
	none = {},
	consoleRed = {
		consoleTab = "Local Chat",
		color = TextColors.red
	},
	consoleOrange = {
		consoleTab = "Local Chat",
		color = TextColors.orange
	},
	consoleBlue = {
		consoleTab = "Local Chat",
		color = TextColors.blue
	},
	centerRed = {
		screenTarget = "lowCenterLabel",
		consoleTab = "Server Log",
		color = TextColors.red
	},
	centerGreen = {
		screenTarget = "highCenterLabel",
		consoleTab = "Server Log",
		consoleOption = "showInfoMessagesInConsole",
		color = TextColors.green
	},
	centerWhite = {
		screenTarget = "middleCenterLabel",
		consoleTab = "Server Log",
		consoleOption = "showEventMessagesInConsole",
		color = TextColors.white
	},
	bottomWhite = {
		screenTarget = "statusLabel",
		consoleTab = "Server Log",
		consoleOption = "showEventMessagesInConsole",
		color = TextColors.white
	},
	status = {
		screenTarget = "statusLabel",
		consoleTab = "Server Log",
		consoleOption = "showStatusMessagesInConsole",
		color = TextColors.white
	},
	statusServerLogOnly = {
		consoleOption = "showStatusMessagesInConsole",
		consoleTab = "Server Log",
		color = TextColors.white
	},
	othersStatus = {
		consoleOption = "showOthersStatusMessagesInConsole",
		consoleTab = "Server Log",
		color = TextColors.white
	},
	statusSmall = {
		screenTarget = "statusLabel",
		color = TextColors.white
	},
	private = {
		screenTarget = "privateLabel",
		color = TextColors.lightblue
	},
	loot = {
		consoleOption = "showInfoMessagesInConsole",
		screenTarget = "highCenterLabel",
		consoleTab = "Loot",
		colored = true,
		color = TextColors.white
	}
}
MessageTypes = {
	[MessageModes.MonsterSay] = MessageSettings.consoleOrange,
	[MessageModes.MonsterYell] = MessageSettings.consoleOrange,
	[MessageModes.BarkLow] = MessageSettings.consoleOrange,
	[MessageModes.BarkLoud] = MessageSettings.consoleOrange,
	[MessageModes.Failure] = MessageSettings.statusSmall,
	[MessageModes.Login] = MessageSettings.bottomWhite,
	[MessageModes.Game] = MessageSettings.centerWhite,
	[MessageModes.Status] = MessageSettings.status,
	[MessageModes.Warning] = MessageSettings.centerRed,
	[MessageModes.Look] = MessageSettings.centerGreen,
	[MessageModes.Loot] = MessageSettings.loot,
	[MessageModes.Red] = MessageSettings.consoleRed,
	[MessageModes.Blue] = MessageSettings.consoleBlue,
	[MessageModes.PrivateFrom] = MessageSettings.consoleBlue,
	[MessageModes.GamemasterBroadcast] = MessageSettings.consoleRed,
	[MessageModes.DamageDealed] = MessageSettings.statusServerLogOnly,
	[MessageModes.DamageReceived] = MessageSettings.statusServerLogOnly,
	[MessageModes.Heal] = MessageSettings.statusServerLogOnly,
	[MessageModes.Mana] = MessageSettings.statusServerLogOnly,
	[MessageModes.Exp] = MessageSettings.statusServerLogOnly,
	[MessageModes.DamageOthers] = MessageSettings.othersStatus,
	[MessageModes.HealOthers] = MessageSettings.othersStatus,
	[MessageModes.ExpOthers] = MessageSettings.othersStatus,
	[MessageModes.Potion] = MessageSettings.othersStatus,
	[MessageModes.TradeNpc] = MessageSettings.centerWhite,
	[MessageModes.Guild] = MessageSettings.centerWhite,
	[MessageModes.Party] = MessageSettings.centerGreen,
	[MessageModes.PartyManagement] = MessageSettings.centerWhite,
	[MessageModes.TutorialHint] = MessageSettings.centerWhite,
	[MessageModes.BeyondLast] = MessageSettings.centerWhite,
	[MessageModes.Report] = MessageSettings.status,
	[MessageModes.GameHighlight] = MessageSettings.centerRed,
	[MessageModes.HotkeyUse] = MessageSettings.centerGreen,
	[MessageModes.Attention] = MessageSettings.bottomWhite,
	[MessageModes.BoostedCreature] = MessageSettings.centerWhite,
	[MessageModes.OfflineTrainning] = MessageSettings.centerWhite,
	[MessageModes.Transaction] = MessageSettings.centerWhite,
	[254] = MessageSettings.private
}
messagesPanel = nil

local gameMessageQueue = {}
local labelMessageSequence = 0
local lastClearOldestMs = -1
local CLEAR_OLDEST_HOTKEY = "Alt+W"
local MAX_GAME_MESSAGE_QUEUE = 4096
local GAME_MESSAGE_QUEUE_TRIM_TO = 2048

local function getScreenMessageOption(key)
	if not modules.client_options or not modules.client_options.getOption then
		return true
	end

	return modules.client_options.getOption(key) ~= false
end

function shouldShowMessageOnScreen(mode)
	if not getScreenMessageOption("showMessages") then
		return false
	end

	if mode == MessageModes.Loot then
		return getScreenMessageOption("showLootMessages")
	end

	if mode == MessageModes.HotkeyUse then
		return getScreenMessageOption("showHotkeyUsageNotifications")
	end

	if mode == MessageModes.BoostedCreature then
		return getScreenMessageOption("showBoostedCreature")
	end

	if mode == MessageModes.OfflineTrainning then
		return getScreenMessageOption("showOfflineTrainingProgress")
	end

	if mode == MessageModes.Transaction then
		return getScreenMessageOption("showStoreNotificationsInCombat")
	end

	if mode == 254 then
		return getScreenMessageOption("showPrivateMessages")
	end

	return true
end

local function removeQueueEntry(predicate)
	for i = #gameMessageQueue, 1, -1 do
		if predicate(gameMessageQueue[i]) then
			table.remove(gameMessageQueue, i)
		end
	end
end

local function unregisterLabelMessage(label)
	removeQueueEntry(function(entry)
		return entry.type == "label" and entry.label == label
	end)
end

function registerStaticTextMessage(staticText, position)
	if #gameMessageQueue >= MAX_GAME_MESSAGE_QUEUE then
		local compactedQueue = {}
		local firstKeptIndex = #gameMessageQueue - GAME_MESSAGE_QUEUE_TRIM_TO + 1

		for index = firstKeptIndex, #gameMessageQueue do
			compactedQueue[#compactedQueue + 1] = gameMessageQueue[index]
		end

		gameMessageQueue = compactedQueue
	end

	table.insert(gameMessageQueue, {
		type = "staticText",
		staticText = staticText,
		position = position
	})
end

function isClearOldestHotkeyCombo(keyCombo)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if keyCombo == CLEAR_OLDEST_HOTKEY then
		return true
	end

	if type(retranslateKeyComboDesc) == "function" then
		local ok, canonical = pcall(retranslateKeyComboDesc, CLEAR_OLDEST_HOTKEY)

		if ok and canonical and canonical ~= "" and keyCombo == canonical then
			return true
		end
	end

	return false
end

local function isUiWidgetValid(widget)
	if not widget then
		return false
	end

	if widget.isDestroyed then
		return not widget:isDestroyed()
	end

	return true
end

local function hideLabelMessage(label)
	if not isUiWidgetValid(label) then
		return
	end

	label:hide()
	removeEvent(label.hideEvent)

	label.hideEvent = nil

	unregisterLabelMessage(label)
end

local function clearOldestStaticTextEntry(entry)
	local staticText

	if entry.position and g_map.getStaticText then
		staticText = g_map.getStaticText(entry.position)
	end

	if not staticText and entry.staticText and type(entry.staticText.clearFirstMessage) == "function" then
		staticText = entry.staticText
	end

	if staticText and staticText.clearFirstMessage then
		staticText:clearFirstMessage()
	elseif staticText and g_map.removeStaticText then
		g_map.removeStaticText(staticText)
	end
end

local function clearOldestVisibleLabelFallback()
	if not isUiWidgetValid(messagesPanel) then
		return false
	end

	local oldestLabel, oldestSeq

	for _, child in pairs(messagesPanel:recursiveGetChildren()) do
		if child:getId():match("Label") and child:isVisible() and child.gameMessageSeq and (not oldestSeq or oldestSeq > child.gameMessageSeq) then
			oldestLabel = child
			oldestSeq = child.gameMessageSeq
		end
	end

	if oldestLabel then
		hideLabelMessage(oldestLabel)

		return true
	end

	return false
end

function clearOldestMessage()
	local now = g_clock.millis()

	if lastClearOldestMs == now then
		return
	end

	lastClearOldestMs = now

	local entry = table.remove(gameMessageQueue, 1)

	if entry then
		if entry.type == "label" then
			hideLabelMessage(entry.label)
		elseif entry.type == "staticText" then
			clearOldestStaticTextEntry(entry)
		end

		return
	end

	clearOldestVisibleLabelFallback()
end

local clearOldestHotkeyHandler
local clearOldestHotkeyCombo = CLEAR_OLDEST_HOTKEY
local clearOldestHotkeyPanel

local function getClearOldestHotkeyCombo()
	if type(retranslateKeyComboDesc) == "function" then
		local ok, canonical = pcall(retranslateKeyComboDesc, CLEAR_OLDEST_HOTKEY)

		if ok and canonical and canonical ~= "" then
			return canonical
		end
	end

	return CLEAR_OLDEST_HOTKEY
end

function bindClearOldestHotkey(panel)
	panel = panel or modules.game_interface and modules.game_interface.getRootPanel()

	if not panel then
		return
	end

	if clearOldestHotkeyHandler and clearOldestHotkeyPanel then
		g_keyboard.unbindKeyDown(clearOldestHotkeyCombo, clearOldestHotkeyHandler, clearOldestHotkeyPanel)

		clearOldestHotkeyHandler = nil
		clearOldestHotkeyPanel = nil
	end

	clearOldestHotkeyCombo = getClearOldestHotkeyCombo()
	clearOldestHotkeyPanel = panel

	function clearOldestHotkeyHandler()
		clearOldestMessage()

		return false
	end

	g_keyboard.bindKeyDown(clearOldestHotkeyCombo, clearOldestHotkeyHandler, panel)
end

function unbindClearOldestHotkey()
	if clearOldestHotkeyHandler and clearOldestHotkeyPanel then
		g_keyboard.unbindKeyDown(clearOldestHotkeyCombo, clearOldestHotkeyHandler, clearOldestHotkeyPanel)
	end

	clearOldestHotkeyHandler = nil
	clearOldestHotkeyPanel = nil
end

function getMessagesPanel()
	return messagesPanel
end

function raiseMessagesPanel()
	if not isUiWidgetValid(messagesPanel) then
		return
	end

	messagesPanel:raise()
end

function init()
	local earlyHandled = {
		[MessageModes.Login] = true,
		[MessageModes.Game] = true,
		[MessageModes.Look] = true,
		[MessageModes.BoostedCreature] = true
	}

	for messageMode, _ in pairs(MessageTypes) do
		if earlyHandled[messageMode] and g_textMessageForward then
			unregisterMessageMode(messageMode, g_textMessageForward)
		end

		registerMessageMode(messageMode, displayMessage)
	end

	connect(g_game, {
		onGameEnd = clearMessages,
		onGameStart = bindClearOldestHotkey
	})

	messagesPanel = g_ui.loadUI("textmessage", modules.game_interface.getRootPanel())

	bindClearOldestHotkey()
	raiseMessagesPanel()
end

function terminate()
	for messageMode, _ in pairs(MessageTypes) do
		unregisterMessageMode(messageMode, displayMessage)
	end

	disconnect(g_game, {
		onGameEnd = clearMessages,
		onGameStart = bindClearOldestHotkey
	})
	unbindClearOldestHotkey()
	clearMessages()
	messagesPanel:destroy()

	messagesPanel = nil
end

function calculateVisibleTime(text)
	return math.max(#text * 50, 4000)
end

function displayMessage(mode, text, channelId)
	local preOnlineModes = {
		[MessageModes.Login] = true,
		[MessageModes.Game] = true,
		[MessageModes.Look] = true,
		[MessageModes.BoostedCreature] = true
	}

	if not g_game.isOnline() and not preOnlineModes[mode] then
		return
	end

	if not messagesPanel then
		if modules.game_console and modules.game_console.addText then
			modules.game_console.addText(text, {
				color = TextColors.lightblue
			}, tr("Server Log"))
		end

		return
	end

	local msgtype = MessageTypes[mode]

	if not msgtype then
		return
	end

	if msgtype == MessageSettings.none then
		return
	end

	local routedToChannel = channelId and channelId ~= 65535 and (mode == MessageModes.Guild or mode == MessageModes.Party or mode == MessageModes.PartyManagement or mode == MessageModes.ChannelManagement)

	if msgtype.consoleTab ~= nil and not routedToChannel and (msgtype.consoleOption == nil or modules.client_options.getOption(msgtype.consoleOption)) then
		if msgtype == MessageSettings.loot then
			local lootColoredText = ItemsDatabase.setColorLootMessage(text)

			modules.game_console.addText(lootColoredText, msgtype, tr("Server Log"))
			modules.game_console.addText(lootColoredText, msgtype, tr(msgtype.consoleTab))
		else
			modules.game_console.addText(text, msgtype, tr(msgtype.consoleTab))
		end
	end

	if msgtype.screenTarget then
		if not shouldShowMessageOnScreen(mode) then
			return
		end

		local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)

		unregisterLabelMessage(label)

		if msgtype == MessageSettings.loot then
			local coloredText = ItemsDatabase.setColorLootMessage(text)

			label:setColoredText(coloredText)
		else
			label:setText(text)
			label:setColor(msgtype.color)
		end

		label:setVisible(true)
		raiseMessagesPanel()
		removeEvent(label.hideEvent)

		labelMessageSequence = labelMessageSequence + 1
		label.gameMessageSeq = labelMessageSequence

		table.insert(gameMessageQueue, {
			type = "label",
			label = label,
			seq = labelMessageSequence
		})

		label.hideEvent = scheduleEvent(function()
			label:setVisible(false)
			unregisterLabelMessage(label)

			label.hideEvent = nil
		end, calculateVisibleTime(text))
	end
end

function displayPrivateMessage(text)
	displayMessage(254, text)
end

function displayStatusMessage(text)
	displayMessage(MessageModes.Status, text)
end

function displayFailureMessage(text)
	displayMessage(MessageModes.Failure, text)
end

function displayGameMessage(text)
	displayMessage(MessageModes.Game, text)
end

function displayBroadcastMessage(text)
	displayMessage(MessageModes.Warning, text)
end

function clearMessages()
	gameMessageQueue = {}
	lastClearOldestMs = -1

	for _i, child in pairs(messagesPanel:recursiveGetChildren()) do
		if child:getId():match("Label") then
			child:hide()
			removeEvent(child.hideEvent)

			child.hideEvent = nil
		end
	end
end

function LocalPlayer:onAutoWalkFail(player)
	modules.game_textmessage.displayFailureMessage(tr("There is no way."))
end
