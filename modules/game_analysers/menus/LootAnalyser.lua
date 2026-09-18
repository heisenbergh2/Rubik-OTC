-- chunkname: @/game_analysers/menus/LootAnalyser.lua

if not LootAnalyser then
	LootAnalyser = {
		gaugeVisible = true,
		target = 0,
		goldHour = 0,
		goldValue = 0,
		session = 0,
		launchTime = 0,
		graphVisible = true,
		lootedItems = {}
	}
	LootAnalyser.__index = LootAnalyser
end

local targetMaxMargin = 142

local function parseLootTargetAmount(text)
	if not text or text == "" then
		return 0
	end

	local digits = tostring(text):gsub("%D", "")

	if digits == "" then
		return 0
	end

	return tonumber(digits) or 0
end

local function updateLootTargetArrow()
	local lootTargetBG = LootAnalyser.window and LootAnalyser.window.contentsPanel and LootAnalyser.window.contentsPanel.lootTargetBG

	if not lootTargetBG or not lootTargetBG.lootArrow then
		return
	end

	local arrow = lootTargetBG.lootArrow
	local target = LootAnalyser.target or 0
	local current = LootAnalyser.goldHour or 0

	if target <= 0 and current <= 0 then
		arrow:setMarginLeft(math.floor(targetMaxMargin / 2))

		return
	end

	if target <= 0 then
		arrow:setMarginLeft(targetMaxMargin)

		return
	end

	local ratio = current / target

	if ratio < 0 then
		ratio = 0
	elseif ratio > 1 then
		ratio = 1
	end

	arrow:setMarginLeft(math.floor(targetMaxMargin * ratio + 0.5))
end

function LootAnalyser:create()
	LootAnalyser.launchTime = 0
	LootAnalyser.session = 0
	LootAnalyser.goldValue = 0
	LootAnalyser.goldHour = 0
	LootAnalyser.target = 0
	LootAnalyser.gaugeVisible = true
	LootAnalyser.graphVisible = true
	LootAnalyser.lootedItems = {}
	LootAnalyser.forceUpdateBalance = false
	LootAnalyser.updateBalance = true
	LootAnalyser.window = openedWindows.lootButton
	LootAnalyser.eventGraph = nil

	local contentsPanel = LootAnalyser.window.contentsPanel

	contentsPanel.separatorLootedItems:setVisible(false)
	contentsPanel.targetLabel:addAnchor(AnchorTop, "separator", AnchorBottom)

	local function openTargetConfigOnLeftClick(widget, mousePosition, mouseButton)
		if mouseButton == MouseLeftButton then
			LootAnalyser:openTargetConfig()

			return true
		end
	end

	contentsPanel.targetLabel.onMousePress = openTargetConfigOnLeftClick
	contentsPanel.goldTarget.onMousePress = openTargetConfigOnLeftClick

	function contentsPanel.lootTargetBG.onMousePress(widget, mousePosition, mouseButton)
		if mouseButton == MouseRightButton then
			onLootingExtra(mousePosition, "gaude")

			return true
		end
	end

	function LootAnalyser.window.contentsPanel.graphPanel.onMousePress(widget, mousePosition, mouseButton)
		if mouseButton == MouseRightButton then
			onLootingExtra(mousePosition, "graph")

			return true
		end
	end
end

function onLootingExtra(mousePosition, mode)
	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)

	if mode == "false" then
		menu:addOption(tr("Reset Data"), function()
			LootAnalyser:reset()
		end)
		menu:addSeparator()
		menu:addOption(tr("Set Loot Per Hour Target"), function()
			LootAnalyser:openTargetConfig()
		end)
		menu:addCheckBoxOption(tr("Loot Per Hour Gauge"), function()
			LootAnalyser:setLootPerHourGauge(not LootAnalyser.window.contentsPanel.targetLabel:isVisible())
		end, "", LootAnalyser.window.contentsPanel.targetLabel:isVisible())
		menu:addCheckBoxOption(tr("Loot Per Hour Graph"), function()
			LootAnalyser:setLootPerHourGraph(not LootAnalyser.window.contentsPanel.graphPanel:isVisible())
		end, "", LootAnalyser.window.contentsPanel.graphPanel:isVisible())
		menu:display(mousePosition)

		return true
	end

	if mode == "gaude" then
		menu:addOption(tr("Set Loot Per Hour Target"), function()
			LootAnalyser:openTargetConfig()
		end)
		menu:addCheckBoxOption(tr("Loot Per Hour Gauge"), function()
			LootAnalyser:setLootPerHourGauge(not LootAnalyser.window.contentsPanel.targetLabel:isVisible())
		end, "", LootAnalyser.window.contentsPanel.targetLabel:isVisible())
	end

	if mode == "graph" then
		menu:addCheckBoxOption(tr("Loot Per Hour Graph"), function()
			LootAnalyser:setLootPerHourGraph(not LootAnalyser.window.contentsPanel.graphPanel:isVisible())
		end, "", LootAnalyser.window.contentsPanel.graphPanel:isVisible())
	end

	menu:display(mousePosition)

	return true
end

function LootAnalyser:reset()
	LootAnalyser.session = 0
	LootAnalyser.goldValue = 0
	LootAnalyser.goldHour = 0
	LootAnalyser.target = 0
	LootAnalyser.lootedItems = {}
	LootAnalyser.forceUpdateBalance = false
	LootAnalyser.updateBalance = true

	analyserUIGraphReset(LootAnalyser.window.contentsPanel.graphPanel, nil, ANALYSER_GRAPH_CAPACITY_60_MIN)
	LootAnalyser:updateWindow(true, true)
end

function LootAnalyser:updateBasePriceFromLootedItems(itemId, newPriceValue)
	local itemInfo = self.lootedItems[itemId]

	if itemInfo then
		if not newPriceValue then
			local itemPtr = Item.create(itemId, 1)

			newPriceValue = itemPtr:getPriceValue()
			itemPtr = nil
		end

		if itemInfo.basePrice ~= newPriceValue then
			itemInfo.basePrice = newPriceValue
			LootAnalyser.forceUpdateBalance = true

			LootAnalyser:updateWindow(true, true)
		end
	end
end

function LootAnalyser:checkBalance()
	local oldBalance = LootAnalyser.goldValue

	if LootAnalyser.forceUpdateBalance then
		local loot = 0

		for itemId, itemInfo in pairs(LootAnalyser.lootedItems) do
			local count = itemInfo.count
			local price = count * itemInfo.basePrice

			loot = loot + price
		end

		LootAnalyser.goldValue = loot
		LootAnalyser.forceUpdateBalance = false
	end

	local oldGoldHour = LootAnalyser.goldHour

	LootAnalyser:refreshGoldHour()

	if LootAnalyser.updateBalance or oldBalance ~= LootAnalyser.goldValue or oldGoldHour ~= LootAnalyser.goldHour then
		LootAnalyser:updateWindow(false, true)

		LootAnalyser.updateBalance = false
	end
end

function LootAnalyser:updateWindow(updateScroll, ignoreVisible)
	if not LootAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	local contentsPanel = LootAnalyser.window.contentsPanel

	contentsPanel.gold:setText(formatMoney(LootAnalyser.goldValue, ","))
	contentsPanel.goldHour:setText(formatMoney(math.floor(LootAnalyser.goldHour), ","))
	contentsPanel.goldTarget:setText(formatMoney(LootAnalyser.target, ","))
	updateLootTargetArrow()
	LootAnalyser.window.contentsPanel.lootTargetBG:setTooltip(string.format("Current: %d\nTarget: %d", LootAnalyser.goldHour, LootAnalyser.target))

	if not updateScroll then
		return
	end

	local numOfItems = 0
	local numOfLines = 0

	if table.empty(LootAnalyser.lootedItems) and #contentsPanel.lootedItems:getChildren() then
		contentsPanel.lootedItems:destroyChildren()
		contentsPanel.separatorLootedItems:setVisible(false)
		LootAnalyser.window.contentsPanel.targetLabel:addAnchor(AnchorTop, "separator", AnchorBottom)
	else
		contentsPanel.separatorLootedItems:setVisible(true)
		LootAnalyser.window.contentsPanel.targetLabel:addAnchor(AnchorTop, "separatorLootedItems", AnchorBottom)

		for itemId, info in pairs(LootAnalyser.lootedItems) do
			local idStr = tostring(itemId)
			local widget = contentsPanel.lootedItems:getChildById(idStr)

			if not widget then
				widget = g_ui.createWidget("LootAnalyserItem", contentsPanel.lootedItems)

				widget:setId(idStr)
				widget:setItemId(tonumber(itemId) or itemId)

				if widget.setFont then
					widget:setFont("verdana-11px-rounded")
				end
			end

			widget:setShowCount(true)
			widget:setItemCount(info.count)
			widget:setTooltip(string.format("%s (Value: %dgp, Sum: %dgp)", string.capitalize(info.name), info.basePrice, info.basePrice * info.count))

			numOfItems = numOfItems + 1

			if numOfItems == 4 then
				numOfItems = 0
				numOfLines = numOfLines + 1
			end
		end
	end

	numOfLines = not table.empty(LootAnalyser.lootedItems) and numOfLines + 1 or 0

	contentsPanel.lootedItems:setHeight(35 * (numOfLines + (numOfLines > 0 and numOfItems == 0 and -1 or 0)))
end

function LootAnalyser:refreshGoldHour()
	LootAnalyser.goldHour = AnalyserSession:perHourFromTotal(LootAnalyser.goldValue)
end

function LootAnalyser:updateGraphics()
	LootAnalyser:refreshGoldHour()

	if LootAnalyser.window and LootAnalyser.window.contentsPanel then
		analyserUIGraphPushValue(LootAnalyser.window.contentsPanel.graphPanel, LootAnalyser.goldHour)
	end
end

function LootAnalyser:addLootedItems(item, name)
	local itemId = item:getId()
	local itemInfo = LootAnalyser.lootedItems[itemId]

	if not itemInfo then
		LootAnalyser.lootedItems[itemId] = {
			basePrice = 0,
			count = 0,
			name = name
		}
		itemInfo = LootAnalyser.lootedItems[itemId]
	end

	local count = item:getCount()

	itemInfo.basePrice = getLootPrice(itemId)
	itemInfo.count = itemInfo.count + count
	LootAnalyser.goldValue = LootAnalyser.goldValue + itemInfo.basePrice * count
	LootAnalyser.updateBalance = true

	LootAnalyser:checkBalance()
	LootAnalyser:updateWindow(true, true)
end

function LootAnalyser:setLootPerHourGauge(value)
	LootAnalyser.window.contentsPanel.targetLabel:setVisible(value)
	LootAnalyser.window.contentsPanel.goldLabelIcon:setVisible(value)
	LootAnalyser.window.contentsPanel.goldTarget:setVisible(value)
	LootAnalyser.window.contentsPanel.lootTargetBG:setVisible(value)
	LootAnalyser.window.contentsPanel.separatorGauge:setVisible(value)

	LootAnalyser.gaugeVisible = value

	if value then
		LootAnalyser.window.contentsPanel.graphPanel:addAnchor(AnchorTop, "separatorGauge", AnchorBottom)
	else
		LootAnalyser.window.contentsPanel.graphPanel:addAnchor(AnchorTop, "separatorLootedItems", AnchorBottom)
	end
end

function LootAnalyser:setLootPerHourGraph(value)
	LootAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	LootAnalyser.window.contentsPanel.graphHorizontal:setVisible(value)

	LootAnalyser.graphVisible = value
end

function LootAnalyser:gaugeIsVisible()
	return LootAnalyser.gaugeVisible
end

function LootAnalyser:graphIsVisible()
	return LootAnalyser.graphVisible
end

function LootAnalyser:getTarget()
	return LootAnalyser.target
end

function LootAnalyser:setTarget(value)
	LootAnalyser.target = parseLootTargetAmount(value)

	if LootAnalyser.window and LootAnalyser.window.contentsPanel then
		LootAnalyser.window.contentsPanel.goldTarget:setText(formatMoney(LootAnalyser.target, ","))
	end

	LootAnalyser:updateWindow(false, true)
end

function LootAnalyser:openTargetConfig()
	local window = configPopupWindow.lootButton

	if not window then
		return
	end

	window:show()
	window:raise()
	window:focus()
	window:setText(tr("Set Loot Target"))
	window.contentPanel.text:setImageSource("/images/game/analyzer/labels/loot")
	window.contentPanel.lootTarget:setText(tostring(LootAnalyser.target or 0))
	window.contentPanel.lootTarget:focus()

	local function applyTarget()
		LootAnalyser:setTarget(window.contentPanel.lootTarget:getText())

		if saveGainAndWastConfigJson then
			saveGainAndWastConfigJson()
		end

		window:hide()
	end

	window.onEnter = applyTarget
	window.contentPanel.ok.onClick = applyTarget

	function window.contentPanel.cancel.onClick()
		window:hide()
	end
end
