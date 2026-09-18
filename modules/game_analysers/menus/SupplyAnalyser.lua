-- chunkname: @/game_analysers/menus/SupplyAnalyser.lua

if not SupplyAnalyser then
	SupplyAnalyser = {
		graphVisible = true,
		gaugeVisible = true,
		target = 0,
		goldHour = 0,
		goldValue = 0,
		session = 0,
		launchTime = 0,
		items = {}
	}
	SupplyAnalyser.__index = SupplyAnalyser
end

local targetMaxMargin = 142

local function updateSupplyTargetArrow()
	local supplyTargetBG = SupplyAnalyser.window and SupplyAnalyser.window.contentsPanel and SupplyAnalyser.window.contentsPanel.supplyTargetBG

	if not supplyTargetBG or not supplyTargetBG.supplyArrow then
		return
	end

	local arrow = supplyTargetBG.supplyArrow
	local target = SupplyAnalyser.target or 0
	local goldHour = SupplyAnalyser.goldHour or 0

	if target <= 0 and goldHour <= 0 then
		arrow:setMarginLeft(math.floor(targetMaxMargin / 2))

		return
	end

	local targetValue = math.max(1, target)
	local marginLeft

	if goldHour < targetValue then
		marginLeft = 0
	elseif goldHour >= 2 * targetValue then
		marginLeft = targetMaxMargin
	else
		local progress = (goldHour - targetValue) / targetValue

		marginLeft = math.floor(targetMaxMargin * progress + 0.5)
	end

	arrow:setMarginLeft(marginLeft)
end

function SupplyAnalyser:create()
	SupplyAnalyser.launchTime = 0
	SupplyAnalyser.session = 0
	SupplyAnalyser.goldValue = 0
	SupplyAnalyser.goldHour = 0
	SupplyAnalyser.target = 0
	SupplyAnalyser.gaugeVisible = true
	SupplyAnalyser.graphVisible = true
	SupplyAnalyser.items = {}
	SupplyAnalyser.forceUpdateBalance = false
	SupplyAnalyser.updateBalance = true
	SupplyAnalyser.window = openedWindows.supplyButton

	SupplyAnalyser.window.contentsPanel.targetLabel:addAnchor(AnchorTop, "separator", AnchorBottom)

	function SupplyAnalyser.window.contentsPanel.supplyTargetBG.onMousePress(widget, mousePosition, mouseButton)
		if mouseButton == MouseRightButton then
			onSupplyExtra(mousePosition, "gaude")

			return true
		end
	end

	function SupplyAnalyser.window.contentsPanel.graphPanel.onMousePress(widget, mousePosition, mouseButton)
		if mouseButton == MouseRightButton then
			onSupplyExtra(mousePosition, "graph")

			return true
		end
	end
end

function onSupplyExtra(mousePosition, mode)
	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)

	if mode == "false" then
		menu:addOption(tr("Reset Data"), function()
			SupplyAnalyser:reset()
		end)
		menu:addSeparator()
		menu:addOption(tr("Set Supply Per Hour Target"), function()
			SupplyAnalyser:openTargetConfig()
		end)
		menu:addCheckBoxOption(tr("Supply Per Hour Gauge"), function()
			SupplyAnalyser:setSupplyPerHourGauge(not SupplyAnalyser.window.contentsPanel.targetLabel:isVisible())
		end, "", SupplyAnalyser.window.contentsPanel.targetLabel:isVisible())
		menu:addCheckBoxOption(tr("Supply Per Hour Graph"), function()
			SupplyAnalyser:setSupplyPerHourGraph(not SupplyAnalyser.window.contentsPanel.graphPanel:isVisible())
		end, "", SupplyAnalyser.window.contentsPanel.graphPanel:isVisible())
		menu:display(mousePosition)

		return true
	end

	if mode == "gaude" then
		menu:addOption(tr("Set Supply Per Hour Target"), function()
			SupplyAnalyser:openTargetConfig()
		end)
		menu:addCheckBoxOption(tr("Supply Per Hour Gauge"), function()
			SupplyAnalyser:setSupplyPerHourGauge(not SupplyAnalyser.window.contentsPanel.targetLabel:isVisible())
		end, "", SupplyAnalyser.window.contentsPanel.targetLabel:isVisible())
	end

	if mode == "graph" then
		menu:addCheckBoxOption(tr("Supply Per Hour Graph"), function()
			SupplyAnalyser:setSupplyPerHourGraph(not SupplyAnalyser.window.contentsPanel.graphPanel:isVisible())
		end, "", SupplyAnalyser.window.contentsPanel.graphPanel:isVisible())
	end

	menu:display(mousePosition)

	return true
end

function SupplyAnalyser:reset()
	SupplyAnalyser.session = 0
	SupplyAnalyser.goldValue = 0
	SupplyAnalyser.goldHour = 0
	SupplyAnalyser.target = 0
	SupplyAnalyser.items = {}
	SupplyAnalyser.forceUpdateBalance = false
	SupplyAnalyser.updateBalance = true

	analyserUIGraphReset(SupplyAnalyser.window.contentsPanel.graphPanel, nil, ANALYSER_GRAPH_CAPACITY_60_MIN)
	SupplyAnalyser.window.contentsPanel.lootedItems:setVisible(false)
	SupplyAnalyser.window.contentsPanel.separatorLootedItems:setVisible(false)
	SupplyAnalyser.window.contentsPanel.targetLabel:addAnchor(AnchorTop, "separator", AnchorBottom)
	SupplyAnalyser.window.contentsPanel.lootedItems:destroyChildren()
	SupplyAnalyser:updateWindow(true, true)
end

function SupplyAnalyser:updateWindow(updateScroll, ignoreVisible)
	if not SupplyAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	SupplyAnalyser:refreshGoldHour()

	local target = SupplyAnalyser.target or 0
	local goldHour = SupplyAnalyser.goldHour or 0
	local goldValue = SupplyAnalyser.goldValue or 0
	local contentsPanel = SupplyAnalyser.window.contentsPanel

	contentsPanel.gold:setText(formatMoney(goldValue, ","))
	contentsPanel.goldHour:setText(formatMoney(math.floor(goldHour), ","))
	contentsPanel.goldTarget:setText(formatMoney(target, ","))
	updateSupplyTargetArrow()
	SupplyAnalyser.window.contentsPanel.supplyTargetBG:setTooltip(string.format("Current: %d\nTarget: %d", goldHour, target))

	if not updateScroll then
		return
	end

	local numOfItems = 0
	local numOfLines = 0

	for _, __ in pairs(contentsPanel.lootedItems:getChildren()) do
		numOfItems = numOfItems + 1

		if numOfItems == 4 then
			numOfItems = 0
			numOfLines = numOfLines + 1
		end
	end

	if numOfItems > 0 then
		contentsPanel.lootedItems:setVisible(true)
		contentsPanel.separatorLootedItems:setVisible(true)
		SupplyAnalyser.window.contentsPanel.targetLabel:addAnchor(AnchorTop, "separatorLootedItems", AnchorBottom)
	end

	numOfLines = not table.empty(SupplyAnalyser.items) and numOfLines + 1 or 0

	contentsPanel.lootedItems:setHeight(35 * numOfLines)
end

function SupplyAnalyser:refreshGoldHour()
	SupplyAnalyser.goldHour = AnalyserSession:perHourFromTotal(SupplyAnalyser.goldValue)
end

function SupplyAnalyser:updateGraphics()
	SupplyAnalyser:refreshGoldHour()

	if SupplyAnalyser.window and SupplyAnalyser.window.contentsPanel then
		analyserUIGraphPushValue(SupplyAnalyser.window.contentsPanel.graphPanel, SupplyAnalyser.goldHour)
	end
end

function SupplyAnalyser:getItemCount(itemId)
	local c = SupplyAnalyser.items[itemId]

	if c == nil and itemId ~= nil then
		local idn = tonumber(itemId)

		if idn ~= nil then
			c = SupplyAnalyser.items[idn]
		end
	end

	return tonumber(c) or 0
end

function SupplyAnalyser:updateWidget(itemId)
	local contentsPanel = SupplyAnalyser.window.contentsPanel
	local idStr = tostring(itemId)
	local widget = contentsPanel.lootedItems:getChildById(idStr)

	if not widget then
		widget = g_ui.createWidget("SupplyAnalyserItem", contentsPanel.lootedItems)

		widget:setId(idStr)
		widget:setItemId(tonumber(itemId) or itemId)

		if widget.setFont then
			widget:setFont("verdana-11px-rounded")
		end
	end

	local count = SupplyAnalyser:getItemCount(itemId)

	if count < 1 then
		count = 1
	end

	widget:setShowCount(true)
	widget:setItemCount(count)

	local value = getCurrentPrice(itemId)

	widget:setTooltip(string.format("%s ×%d (Value: %sgp, Sum: %sgp)", getItemServerName(itemId), count, formatMoney(value, ","), formatMoney(value * count, ",")))
end

function SupplyAnalyser:addSuppliesItems(itemId)
	if SupplyAnalyser.items[itemId] then
		SupplyAnalyser.items[itemId] = SupplyAnalyser.items[itemId] + 1
	else
		SupplyAnalyser.items[itemId] = 1
	end

	local value = getCurrentPrice(itemId)

	SupplyAnalyser.goldValue = SupplyAnalyser.goldValue + value
	SupplyAnalyser.updateBalance = true

	SupplyAnalyser:updateWidget(itemId)
	SupplyAnalyser:updateGraphics()
	SupplyAnalyser:updateWindow(true, true)
end

function SupplyAnalyser:setSupplyPerHourGauge(value)
	SupplyAnalyser.window.contentsPanel.targetLabel:setVisible(value)
	SupplyAnalyser.window.contentsPanel.goldLabelIcon:setVisible(value)
	SupplyAnalyser.window.contentsPanel.goldTarget:setVisible(value)
	SupplyAnalyser.window.contentsPanel.supplyTargetBG:setVisible(value)
	SupplyAnalyser.window.contentsPanel.separatorGauge:setVisible(value)

	SupplyAnalyser.gaugeVisible = value

	if value then
		SupplyAnalyser.window.contentsPanel.graphPanel:addAnchor(AnchorTop, "separatorGauge", AnchorBottom)
	else
		SupplyAnalyser.window.contentsPanel.graphPanel:addAnchor(AnchorTop, "separatorLootedItems", AnchorBottom)
	end
end

function SupplyAnalyser:setSupplyPerHourGraph(value)
	SupplyAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	SupplyAnalyser.window.contentsPanel.graphHorizontal:setVisible(value)

	SupplyAnalyser.graphVisible = value
end

function SupplyAnalyser:gaugeIsVisible()
	return SupplyAnalyser.gaugeVisible
end

function SupplyAnalyser:graphIsVisible()
	return SupplyAnalyser.graphVisible
end

function SupplyAnalyser:getTarget()
	return SupplyAnalyser.target
end

function SupplyAnalyser:setTarget(value)
	SupplyAnalyser.target = tonumber(value) or 0

	if SupplyAnalyser.window and SupplyAnalyser.window.contentsPanel then
		SupplyAnalyser.window.contentsPanel.goldTarget:setText(formatMoney(SupplyAnalyser.target, ","))
	end

	SupplyAnalyser:updateWindow(true, true)
end

function SupplyAnalyser:openTargetConfig()
	local window = configPopupWindow.supplyButton

	if not window then
		return
	end

	window:show()
	window:raise()
	window:focus()
	window:setText(tr("Set Supply Target"))
	window.contentPanel.text:setImageSource("/images/game/analyzer/labels/supply")
	window.contentPanel.supplyTarget:setText(tostring(SupplyAnalyser.target or 0))
	window.contentPanel.supplyTarget:focus()

	local function applyTarget()
		SupplyAnalyser:setTarget(window.contentPanel.supplyTarget:getText())

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
