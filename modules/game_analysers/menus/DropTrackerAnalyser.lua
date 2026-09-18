-- chunkname: @/game_analysers/menus/DropTrackerAnalyser.lua

if not DropTrackerAnalyser then
	DropTrackerAnalyser = {
		autoTrackAboveValue = 0,
		session = 0,
		launchTime = 0,
		trackedItems = {}
	}
	DropTrackerAnalyser.__index = DropTrackerAnalyser
end

local function getMonsterOutfit(monsterName, monsterOutfit)
	if type(monsterOutfit) == "table" then
		return monsterOutfit
	end

	if g_things.getRacesByName then
		local races = g_things.getRacesByName(monsterName)

		if races and races[1] and races[1].outfit then
			return races[1].outfit
		end
	end

	return nil
end

local function setMonsterPanelOutfit(creatureWidget, monsterName, monsterOutfit)
	local outfit = getMonsterOutfit(monsterName, monsterOutfit)

	if outfit and creatureWidget and creatureWidget.setOutfit then
		creatureWidget:setOutfit(outfit)

		if creatureWidget.getCreature then
			local creature = creatureWidget:getCreature()

			if creature and creature.setStaticWalking then
				creature:setStaticWalking(1000)
			end
		end
	end
end

local function getDropTrackerItemPrice(itemId)
	local thingType = g_things.getThingType(itemId, ThingCategoryItem)

	if not thingType then
		return 0
	end

	local maxNpcBuy = 0
	local npcData = thingType:getNpcSaleData()

	if npcData then
		for i = 1, #npcData do
			local row = npcData[i]

			if row and row.buyPrice and maxNpcBuy < row.buyPrice then
				maxNpcBuy = row.buyPrice
			end
		end
	end

	if maxNpcBuy > 0 then
		return maxNpcBuy
	end

	if thingType:isCyclopediaItem() then
		return tonumber(thingType:getResultingValue()) or 0
	end

	if thingType:isMarketable() then
		return tonumber(thingType:getMeanPrice()) or 0
	end

	return 0
end

local function bindItemPanelContextMenu(widget, itemId)
	widget.trackedItemId = itemId

	function widget.onMousePress(w, mousePos, mouseButton)
		if mouseButton ~= MouseRightButton then
			return false
		end

		onDropTrackerItemContextMenu(w.trackedItemId, mousePos)

		return true
	end
end

function DropTrackerAnalyser:create()
	DropTrackerAnalyser.window = openedWindows.dropButton
	DropTrackerAnalyser.launchTime = g_clock.millis()
	DropTrackerAnalyser.session = 0
	DropTrackerAnalyser.autoTrackAboveValue = 0
	DropTrackerAnalyser.trackedItems = {}
end

function DropTrackerAnalyser:checkTracker()
	local needUpdate = false

	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		if not config.persistent and os.time() - config.recordStartTimestamp > 120 then
			DropTrackerAnalyser.trackedItems[itemId] = nil
			needUpdate = true
		else
			for id, mInfo in ipairs(config.monsterDrop) do
				if os.time() - mInfo.time > 45 then
					needUpdate = true
				end
			end
		end
	end

	if needUpdate then
		DropTrackerAnalyser:updateWindow(true)
	end
end

function DropTrackerAnalyser:reset(resetAutoTrack)
	DropTrackerAnalyser.launchTime = g_clock.millis()
	DropTrackerAnalyser.session = 0

	if resetAutoTrack then
		DropTrackerAnalyser.autoTrackAboveValue = 0
	end

	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		if config.monsterDrop then
			config.monsterDrop = {}
		end
	end

	DropTrackerAnalyser:updateWindow(true)
end

function DropTrackerAnalyser:updateWindow(ignoreVisible)
	if not DropTrackerAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	local contentsPanel = DropTrackerAnalyser.window.contentsPanel

	for _, widget in pairs(contentsPanel.dropItems:getChildren()) do
		widget.toBeRemoved = true

		if widget.dropMonster then
			for _, monsterWidget in pairs(widget.dropMonster:getChildren()) do
				monsterWidget.toBeRemoved = true
			end
		end
	end

	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		local widget = contentsPanel.dropItems:getChildById("ItemPanel_" .. itemId)

		if not widget then
			widget = g_ui.createWidget("ItemPanel", contentsPanel.dropItems)

			widget:setId("ItemPanel_" .. itemId)
			widget.itemSlot:setItemId(itemId)
			widget.itemName:setText(string.capitalize(short_text(getItemServerName(itemId), 13)))
			widget.drops:setText(formatMoney(config.dropCount, ","))

			for _, monsterDrop in ipairs(config.monsterDrop) do
				if widget.dropMonster then
					local monsterWidget = g_ui.createWidget("MonsterPanel", widget.dropMonster)

					setMonsterPanelOutfit(monsterWidget.monster, monsterDrop.monsterName, monsterDrop.outfit)
					monsterWidget.name:setText(string.capitalize(monsterDrop.monsterName))
					monsterWidget.drops:setText("(" .. formatMoney(monsterDrop.count, ",") .. ")")

					monsterDrop.widget = monsterWidget
				end
			end

			bindItemPanelContextMenu(widget, itemId)
			widget:updateItemPanelSize()
		else
			widget.drops:setText(formatMoney(config.dropCount, ","))

			widget.toBeRemoved = nil

			bindItemPanelContextMenu(widget, itemId)

			local toBeRemoved = {}

			for id, monsterDrop in ipairs(config.monsterDrop) do
				local monsterWidget = monsterDrop.widget

				if not monsterWidget then
					if widget.dropMonster then
						local monsterWidget = g_ui.createWidget("MonsterPanel", widget.dropMonster)

						setMonsterPanelOutfit(monsterWidget.monster, monsterDrop.monsterName, monsterDrop.outfit)
						monsterWidget.name:setText(string.capitalize(monsterDrop.monsterName))
						monsterWidget.drops:setText("(" .. formatMoney(monsterDrop.count, ",") .. ")")

						monsterDrop.widget = monsterWidget
					end
				elseif os.time() - monsterDrop.time > 45 then
					table.insert(toBeRemoved, id)
				else
					monsterWidget.toBeRemoved = nil
				end
			end

			if #toBeRemoved == 0 then
				widget:updateItemPanelSize()
			end

			for _, id in ipairs(toBeRemoved) do
				table.remove(config.monsterDrop, id)
			end
		end
	end

	for _, widget in pairs(contentsPanel.dropItems:getChildren()) do
		if widget.toBeRemoved then
			widget:destroy()
		end

		if widget.dropMonster then
			local destroyedAtLeastOne = false

			for _, monsterWidget in pairs(widget.dropMonster:getChildren()) do
				if monsterWidget.toBeRemoved then
					monsterWidget:destroy()

					destroyedAtLeastOne = true
				end
			end

			if destroyedAtLeastOne then
				widget:updateItemPanelSize()
			end
		end
	end
end

function DropTrackerAnalyser:managerDropItem(itemId, checked)
	if checked then
		if not DropTrackerAnalyser.trackedItems[itemId] then
			DropTrackerAnalyser.trackedItems[itemId] = {
				dropCount = 0,
				persistent = true,
				monsterDrop = {},
				recordStartTimestamp = os.time()
			}
		else
			DropTrackerAnalyser.trackedItems[itemId].persistent = true
		end
	else
		DropTrackerAnalyser.trackedItems[itemId] = nil
	end

	DropTrackerAnalyser:updateWindow(true)
	DropTrackerAnalyser:saveConfigJson()
end

function DropTrackerAnalyser:sendDropedItems(message)
	if modules.game_textmessage and modules.game_textmessage.messagesPanel and modules.game_textmessage.messagesPanel.statusLabel then
		local sl = modules.game_textmessage.messagesPanel.statusLabel

		sl:setVisible(true)
		sl:setText(message)
		sl:setColor("#f0b400")
		scheduleEvent(function()
			sl:setVisible(false)
		end, 3000)
	end

	if modules.game_console and modules.game_console.addText then
		local speaktype = {
			color = "#f0b400"
		}
		local lootTab = modules.game_console.getTab and modules.game_console.getTab(tr("Loot"))

		modules.game_console.addText(message, speaktype, tr("Server Log"))

		if lootTab then
			modules.game_console.addText(message, speaktype, tr("Loot"))
		end
	end
end

function DropTrackerAnalyser:tryAddingMonsterDrop(item, monsterName, monsterOutfit, dropItems, dropedItems)
	local itemId = item:getId()
	local tracker = DropTrackerAnalyser.trackedItems[itemId]
	local itemPrice = getDropTrackerItemPrice(itemId)

	if not tracker and DropTrackerAnalyser.autoTrackAboveValue == 0 then
		return
	elseif DropTrackerAnalyser.autoTrackAboveValue > 0 and itemPrice >= DropTrackerAnalyser.autoTrackAboveValue then
		tracker = DropTrackerAnalyser.trackedItems[itemId]

		if not tracker then
			DropTrackerAnalyser.trackedItems[itemId] = {
				dropCount = 0,
				persistent = false,
				monsterDrop = {},
				recordStartTimestamp = os.time()
			}
			tracker = DropTrackerAnalyser.trackedItems[itemId]
		end
	elseif not tracker then
		return
	end

	dropedItems[#dropedItems + 1] = itemId
	tracker.dropCount = tracker.dropCount + item:getCount()
	tracker.recordStartTimestamp = os.time()
	tracker.monsterDrop[#tracker.monsterDrop + 1] = {
		monsterName = monsterName,
		outfit = getMonsterOutfit(monsterName, monsterOutfit),
		time = os.time(),
		count = item:getCount()
	}
end

function DropTrackerAnalyser:checkMonsterKilled(monsterName, monsterOutfit, dropItems)
	if table.empty(DropTrackerAnalyser.trackedItems) and DropTrackerAnalyser.autoTrackAboveValue == 0 then
		return true
	end

	local autoTrack = tonumber(DropTrackerAnalyser.autoTrackAboveValue)

	DropTrackerAnalyser.autoTrackAboveValue = autoTrack or 0

	local dropedItems = {}

	for _, item in pairs(dropItems) do
		DropTrackerAnalyser:tryAddingMonsterDrop(item, monsterName, monsterOutfit, dropItems, dropedItems)
	end

	if #dropedItems ~= 0 then
		local itemNames = {}

		for _, itemId in pairs(dropedItems) do
			itemNames[#itemNames + 1] = getItemServerName(itemId)
		end

		local message = string.format("Valuable loot: %s dropped by %s!", table.concat(itemNames, ", "), monsterName)

		DropTrackerAnalyser:sendDropedItems(message)
	end

	DropTrackerAnalyser:updateWindow(true)
end

function DropTrackerAnalyser:isInDropTracker(itemId)
	local tracker = DropTrackerAnalyser.trackedItems[itemId]

	return tracker and tracker.persistent
end

function DropTrackerAnalyser:removeAllTrackedItems()
	table.clear(DropTrackerAnalyser.trackedItems)
	DropTrackerAnalyser:updateWindow(true)
	DropTrackerAnalyser:saveConfigJson()
end

function onDropTrackerItemContextMenu(itemId, mousePosition)
	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)
	menu:addOption(tr("Remove"), function()
		DropTrackerAnalyser:managerDropItem(itemId, false)
	end)
	menu:addOption(tr("Remove All"), function()
		DropTrackerAnalyser:removeAllTrackedItems()
	end)
	menu:setWidth(125)
	menu:display(mousePosition)

	return true
end

function onDropTrackerExtra(mousePosition)
	local window = configPopupWindow.dropButton

	window:show()
	window:setText("Drop Tracker Configuration")
	window.contentPanel.text:setImageSource("/images/game/analyzer/labels/loot-track")

	function window.onEnter()
		local value = window.contentPanel.target:getText()

		DropTrackerAnalyser.autoTrackAboveValue = tonumber(value)

		window:hide()
	end

	window.contentPanel.target:setText(tonumber(DropTrackerAnalyser.autoTrackAboveValue) or "0")

	function window.contentPanel.ok.onClick()
		local value = window.contentPanel.target:getText()

		DropTrackerAnalyser.autoTrackAboveValue = tonumber(value)

		window:hide()
	end

	function window.contentPanel.cancel.onClick()
		window:hide()
	end
end

function DropTrackerAnalyser:loadConfigJson()
	local config = {
		autoTrackAboveValue = 0,
		trackedItems = {}
	}

	if not LoadedPlayer:isLoaded() then
		return
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemtracking.json"

	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	table.clear(DropTrackerAnalyser.trackedItems)

	for _, i in pairs(config.trackedItems) do
		DropTrackerAnalyser.trackedItems[i.objectType] = {
			persistent = true,
			monsterDrop = {},
			recordStartTimestamp = i.recordStartTimestamp,
			dropCount = i.dropCount
		}
	end

	DropTrackerAnalyser.autoTrackAboveValue = config.autoTrackAboveValue

	DropTrackerAnalyser:updateWindow(true)
end

function DropTrackerAnalyser:saveConfigJson()
	local config = {
		autoTrackAboveValue = DropTrackerAnalyser.autoTrackAboveValue,
		trackedItems = {}
	}

	for itemId, insta in pairs(DropTrackerAnalyser.trackedItems) do
		if insta.persistent then
			config.trackedItems[#config.trackedItems + 1] = {
				dropCount = insta.dropCount,
				objectType = itemId,
				recordStartTimestamp = insta.recordStartTimestamp
			}
		end
	end

	if not LoadedPlayer:isLoaded() then
		return
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemtracking.json"
	local status, result = pcall(function()
		return json.encode(config, 2)
	end)

	if not status then
		return g_logger.error("Error while saving profile DropTracker data. Data won't be saved. Details: " .. result)
	end

	if result:len() > 104857600 then
		return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
	end

	g_resources.writeFileContents(file, result)
end
