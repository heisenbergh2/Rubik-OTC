-- chunkname: @/game_playertrade/playertrade.lua

tradeWindow = nil

local ownTradeName, counterTradeName
local DEFAULT_TRADE_BAG_ID = 2853

local function showTradeItemMenu(item, counter, tradeIndex)
	if not item or not g_game.isOnline() then
		return
	end

	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setGameMenu(true)
	menu:addOption(tr("Look"), function()
		g_game.inspectTrade(counter, tradeIndex)
	end)
	menu:addOption(tr("Inspect"), function()
		if g_game.inspectionPlayerTrade then
			g_game.inspectionPlayerTrade(counter)
		end
	end)
	menu:display()
end

local function syncTradeScroll()
	if not tradeWindow then
		return
	end

	local ownScroll = tradeWindow:recursiveGetChildById("ownTradeScrollBar")
	local counterScroll = tradeWindow:recursiveGetChildById("counterTradeScrollBar")
	local masterScroll = tradeWindow:recursiveGetChildById("tradeScrollBar")

	if not ownScroll or not counterScroll or not masterScroll then
		return
	end

	local ownMax = ownScroll:getMaximum() or 0
	local counterMax = counterScroll:getMaximum() or 0
	local masterMax = math.max(ownMax, counterMax)

	masterScroll:setRange(0, masterMax)

	local masterValue = masterScroll:getValue()

	ownScroll:setValue(math.min(masterValue, ownMax))
	counterScroll:setValue(math.min(masterValue, counterMax))
end

function init()
	g_ui.importStyle("tradewindow")
	connect(g_game, {
		onOwnTrade = onGameOwnTrade,
		onCounterTrade = onGameCounterTrade,
		onCloseTrade = onGameCloseTrade,
		onGameEnd = onGameCloseTrade
	})
end

function terminate()
	disconnect(g_game, {
		onOwnTrade = onGameOwnTrade,
		onCounterTrade = onGameCounterTrade,
		onCloseTrade = onGameCloseTrade,
		onGameEnd = onGameCloseTrade
	})

	if tradeWindow then
		tradeWindow:destroy()
	end
end

function createTrade()
	tradeWindow = g_ui.createWidget("TradeWindow", modules.game_interface.getRightPanel())

	function tradeWindow.onClose()
		g_game.rejectTrade()
		tradeWindow:hide()
	end

	tradeWindow:setup()

	local tradeItemWidget = tradeWindow:getChildById("headerItem")

	if tradeItemWidget then
		tradeItemWidget:setImageSource("")
	end

	local masterScroll = tradeWindow:recursiveGetChildById("tradeScrollBar")

	if masterScroll then
		function masterScroll.onValueChange()
			syncTradeScroll()
		end
	end

	local function onTradeMouseWheel(widget, mousePos, mouseWheel)
		if not masterScroll or not masterScroll:isOn() then
			return false
		end

		if mouseWheel == MouseWheelUp then
			local minimum = masterScroll:getMinimum()

			if minimum >= masterScroll:getValue() then
				return false
			end

			masterScroll:decrement()
		else
			local maximum = masterScroll:getMaximum()

			if maximum <= masterScroll:getValue() then
				return false
			end

			masterScroll:increment()
		end

		return true
	end

	local ownTradeContainer = tradeWindow:recursiveGetChildById("ownTradeContainer")

	if ownTradeContainer then
		ownTradeContainer.onMouseWheel = onTradeMouseWheel
	end

	local counterTradeContainer = tradeWindow:recursiveGetChildById("counterTradeContainer")

	if counterTradeContainer then
		counterTradeContainer.onMouseWheel = onTradeMouseWheel
	end
end

local function updateTradeWindowTitle()
	if not tradeWindow then
		return
	end

	tradeWindow:setText(tr("Trade"))
end

function fillTrade(name, items, counter)
	if not tradeWindow then
		createTrade()
	end

	local tradeItemWidget = tradeWindow:getChildById("headerItem")

	if tradeItemWidget then
		tradeItemWidget:setImageSource("/modules/game_playertrade/icon-trade")
		tradeItemWidget:setItemId(0)
	end

	local localPlayerName = g_game.getCharacterName()
	local isOwnTrade = name == localPlayerName

	if isOwnTrade then
		ownTradeName = name
	else
		counterTradeName = name
	end

	updateTradeWindowTitle()

	local tradeContainer, label

	if isOwnTrade then
		tradeContainer = tradeWindow:recursiveGetChildById("ownTradeContainer")
		label = tradeWindow:recursiveGetChildById("ownTradeLabel")
	else
		tradeContainer = tradeWindow:recursiveGetChildById("counterTradeContainer")
		label = tradeWindow:recursiveGetChildById("counterTradeLabel")

		tradeWindow:recursiveGetChildById("acceptButton"):enable()
	end

	label:setText(name)
	label:setVisible(true)

	for index, item in ipairs(items) do
		local itemWidget = g_ui.createWidget("Item", tradeContainer)

		itemWidget:setItem(item)
		ItemsDatabase.setTier(itemWidget, item)
		itemWidget:setVirtual(true)
		itemWidget:setMargin(0)

		local tradeIndex = index - 1

		function itemWidget.onClick()
			g_game.inspectTrade(counter, tradeIndex)
		end

		function itemWidget.onMousePress(_, mousePos, mouseButton)
			if mouseButton == MouseRightButton then
				showTradeItemMenu(item, counter, tradeIndex)
			end

			return false
		end
	end

	syncTradeScroll()
	addEvent(syncTradeScroll)
end

function onGameOwnTrade(name, items)
	fillTrade(name, items, false)
end

function onGameCounterTrade(name, items)
	fillTrade(name, items, true)
end

function onGameCloseTrade()
	if tradeWindow then
		tradeWindow:destroy()

		tradeWindow = nil
	end

	ownTradeName = nil
	counterTradeName = nil
end
