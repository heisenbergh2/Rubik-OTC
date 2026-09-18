-- chunkname: @/mods/game_tibia_market/classes/t_ownOffers.lua

MarketOwnOffers = {
	labelSize = 16,
	ownBuyPool = 14,
	bottomListFitItems = 0,
	topListFitItems = 0,
	bottomListMax = 0,
	bottomListMin = 0,
	topListMax = 0,
	topListMin = 0,
	ownSellPool = 14,
	mySellOffers = {},
	myBuyOffers = {},
	topListPool = {},
	bottomListPool = {},
	topListData = {},
	bottomListData = {},
	selectedSellCounter = {
		action = 0,
		counter = 0
	},
	selectedBuyCounter = {
		action = 0,
		counter = 0
	}
}
MarketOwnOffers.__index = MarketOwnOffers

local function normalizeOffers(t)
	local out = {}

	if t then
		for _, v in pairs(t) do
			table.insert(out, v)
		end

		table.sort(out, function(a, b)
			local ta, tb = a.timestamp or 0, b.timestamp or 0

			if ta ~= tb then
				return ta < tb
			end

			return (a.counter or 0) < (b.counter or 0)
		end)
	end

	return out
end

function MarketOwnOffers.onParseMyOffers(buyOffers, sellOffers)
	local window = marketWindow.MarketHistory.currentOffers

	modules.game_market.setMyOffersHeaderHistoryMode(false)
	modules.game_market.updateMarketWindowTitle("myOffers")

	lastSelectedMySell = nil
	lastSelectedMyBuy = nil
	lastSelectedHistorySell = nil
	lastSelectedHistoryBuy = nil

	MarketHistory.clearPools()
	window.sellOffersList:focusChild(nil)
	window.buyOffersList:focusChild(nil)
	window.buyCancelOffer:setVisible(true)
	window.sellCancelOffer:setVisible(true)
	window.buyCancelOffer:setEnabled(false)
	window.sellCancelOffer:setEnabled(false)

	local buyScrollbar = marketWindow.MarketHistory:recursiveGetChildById("buyOffersListScroll")
	local sellScrollbar = marketWindow.MarketHistory:recursiveGetChildById("sellOffersListScroll")

	buyScrollbar.onValueChange = nil
	sellScrollbar.onValueChange = nil

	local incomingBuy = normalizeOffers(buyOffers)
	local incomingSell = normalizeOffers(sellOffers)
	local updatedBuy, updatedSell = false, false

	if #incomingBuy == 1 and #MarketOwnOffers.myBuyOffers > 0 then
		local u = incomingBuy[1]

		for i, data in ipairs(MarketOwnOffers.myBuyOffers) do
			if data.counter == u.counter and data.timestamp == u.timestamp then
				table.remove(MarketOwnOffers.myBuyOffers, i)

				updatedBuy = true

				break
			end
		end
	end

	if #incomingSell == 1 and #MarketOwnOffers.mySellOffers > 0 then
		local u = incomingSell[1]

		for i, data in ipairs(MarketOwnOffers.mySellOffers) do
			if data.counter == u.counter and data.timestamp == u.timestamp then
				table.remove(MarketOwnOffers.mySellOffers, i)

				updatedSell = true

				break
			end
		end
	end

	if not updatedBuy then
		MarketOwnOffers.myBuyOffers = incomingBuy
	end

	if not updatedSell then
		MarketOwnOffers.mySellOffers = incomingSell
	end

	local ownSellPool = MarketOwnOffers.ownSellPool or 0
	local ownBuyPool = MarketOwnOffers.ownBuyPool or 0
	local labelSize = MarketOwnOffers.labelSize or 1

	window.sellOffersList:destroyChildren()

	for i = 1, math.min(ownSellPool, #MarketOwnOffers.mySellOffers) do
		local data = MarketOwnOffers.mySellOffers[i]
		local widget = g_ui.createWidget("MarketCurrentWidget", window.sellOffersList)
		local color = i % 2 == 0 and "#414141" or "#484848"

		widget:setId(color)
		widget:setActionId(i)
		widget:setBackgroundColor(color)
		widget.amount:setText(data.amount)
		widget.name:setText(g_things.getThingType(data.itemId):getMarketData().name)
		widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))

		widget.counter = data.counter

		local itemTier = data.itemTier or 0

		if itemTier > 0 then
			widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
		end

		local totalPrice = data.price * data.amount
		local unitPrice = data.price

		widget.piecePrice:setText(convertGold(unitPrice))
		widget.totalPrice:setText(convertGold(totalPrice))

		if totalPrice > 99999999 then
			widget.totalPrice:setTooltip(comma_value(totalPrice))
		end

		if unitPrice > 99999999 then
			widget.piecePrice:setTooltip(comma_value(unitPrice))
		end
	end

	local sellCount = #MarketOwnOffers.mySellOffers

	MarketOwnOffers.topListMin = sellCount > 0 and 1 or 0
	MarketOwnOffers.topListMax = sellCount + 1
	MarketOwnOffers.topListFitItems = math.floor(window.sellOffersList:getHeight() / labelSize)

	local sellMin = MarketOwnOffers.topListMin
	local sellMax = math.max(sellMin, MarketOwnOffers.topListMax - ownSellPool, 0)

	sellScrollbar:setMinimum(sellMin)
	sellScrollbar:setMaximum(sellMax)
	sellScrollbar:setValue(sellMin)

	function sellScrollbar:onValueChange(value, delta)
		MarketOwnOffers.onTopListValueChange(self, value, delta)
	end

	window.buyOffersList:destroyChildren()

	for i = 1, math.min(ownBuyPool, #MarketOwnOffers.myBuyOffers) do
		local data = MarketOwnOffers.myBuyOffers[i]
		local widget = g_ui.createWidget("MarketCurrentWidget", window.buyOffersList)
		local color = i % 2 == 0 and "#414141" or "#484848"

		widget:setId(color)
		widget:setActionId(i)
		widget:setBackgroundColor(color)
		widget.amount:setText(data.amount)
		widget.name:setText(g_things.getThingType(data.itemId):getMarketData().name)
		widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))

		widget.counter = data.counter

		local itemTier = data.itemTier or 0

		if itemTier > 0 then
			widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
		end

		local totalPrice = data.price * data.amount
		local unitPrice = data.price

		widget.piecePrice:setText(convertGold(unitPrice))
		widget.totalPrice:setText(convertGold(totalPrice))

		if totalPrice > 99999999 then
			widget.totalPrice:setTooltip(comma_value(totalPrice))
		end

		if unitPrice > 99999999 then
			widget.piecePrice:setTooltip(comma_value(unitPrice))
		end
	end

	local buyCount = #MarketOwnOffers.myBuyOffers

	MarketOwnOffers.bottomListMin = buyCount > 0 and 1 or 0
	MarketOwnOffers.bottomListMax = buyCount + 1
	MarketOwnOffers.bottomListFitItems = math.floor(window.buyOffersList:getHeight() / labelSize)

	local buyMin = MarketOwnOffers.bottomListMin
	local buyMax = math.max(buyMin, MarketOwnOffers.bottomListMax - ownBuyPool, 0)

	buyScrollbar:setMinimum(buyMin)
	buyScrollbar:setMaximum(buyMax)
	buyScrollbar:setValue(buyMin)

	function buyScrollbar:onValueChange(value, delta)
		MarketOwnOffers.onBottomListValueChange(self, value, delta)
	end

	function window.sellOffersList:onChildFocusChange(selected)
		MarketOwnOffers.onSelectMyOffersChild(self, selected, true)
	end

	function window.buyOffersList:onChildFocusChange(selected)
		MarketOwnOffers.onSelectMyOffersChild(self, selected, false)
	end

	local firstChild = window.sellOffersList:getChildren()[1]

	if firstChild then
		window.sellCancelOffer:setEnabled(true)
		window.sellOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
	else
		window.sellCancelOffer:setEnabled(false)

		lastSelectedMySell = nil
	end

	firstChild = window.buyOffersList:getChildren()[1]

	if firstChild then
		window.buyCancelOffer:setEnabled(true)
		window.buyOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
	else
		window.buyCancelOffer:setEnabled(false)

		lastSelectedMyBuy = nil
	end

	window.sellOffersLabel:setText("Sell Offers (" .. sellCount .. "):")
	window.buyOffersLabel:setText("Buy Offers (" .. buyCount .. "):")
end

function MarketOwnOffers:onSelectMyOffersChild(selected, selling)
	if not selected then
		return
	end

	local lastSelected = selling and lastSelectedMySell or lastSelectedMyBuy

	if lastSelected then
		if lastSelected:isDestroyed() or not lastSelected.piecePrice then
			lastSelected = nil

			if selling then
				lastSelectedMySell = nil
			else
				lastSelectedMyBuy = nil
			end
		else
			lastSelected:setBackgroundColor(lastSelected:getId())
			lastSelected.piecePrice:setColor("#c0c0c0")
			lastSelected.totalPrice:setColor("#c0c0c0")
			lastSelected.name:setColor("#c0c0c0")
			lastSelected.amount:setColor("#c0c0c0")
			lastSelected.endAt:setColor("#c0c0c0")
		end
	end

	if selling then
		lastSelectedMySell = selected
		MarketOwnOffers.selectedSellCounter.counter = selected.counter
		MarketOwnOffers.selectedSellCounter.action = selected:getActionId()
	else
		lastSelectedMyBuy = selected
		MarketOwnOffers.selectedBuyCounter.counter = selected.counter
		MarketOwnOffers.selectedBuyCounter.action = selected:getActionId()
	end

	selectedCounter = selected.counter

	selected:setBackgroundColor("#585858")
	selected.piecePrice:setColor("#f4f4f4")
	selected.totalPrice:setColor("#f4f4f4")
	selected.name:setColor("#f4f4f4")
	selected.amount:setColor("#f4f4f4")
	selected.endAt:setColor("#f4f4f4")
end

function MarketOwnOffers.cancelMarketOffer(selling)
	local window = marketWindow.MarketHistory.currentOffers
	local list = selling and window.sellOffersList or window.buyOffersList
	local widget = list:getFocusedChild()

	if not widget then
		list:focusChild(list:getFirstChild())

		widget = list:getFocusedChild()
	end

	if not widget then
		return true
	end

	local targetList = selling and MarketOwnOffers.mySellOffers or MarketOwnOffers.myBuyOffers
	local targetAction = selling and MarketOwnOffers.selectedSellCounter.action or MarketOwnOffers.selectedBuyCounter.action
	local targetOffer = targetList[targetAction]

	if not targetOffer then
		return true
	end

	if selling and targetOffer.itemId then
		adjustDepotLockerItemCount(targetOffer.itemId, targetOffer.itemTier or 0, targetOffer.amount or 0)
	end

	g_game.cancelMarketOffer(targetOffer.timestamp, targetOffer.counter)
	g_game.sendMarketAction(2)
	requestMarketGoldRefresh()
	refreshSelectedMarketBrowse()
	refreshSelectedItemDepotDisplay()
end

function MarketOwnOffers.onTopListValueChange(scroll, value, delta)
	local window = marketWindow.MarketHistory.currentOffers
	local startLabel = math.max(MarketOwnOffers.topListMin, value)
	local endLabel = startLabel + MarketOwnOffers.topListFitItems - 1

	if endLabel > MarketOwnOffers.topListMax then
		endLabel = MarketOwnOffers.topListMax
		startLabel = endLabel - MarketOwnOffers.topListFitItems + 1
	end

	for i, widget in ipairs(window.sellOffersList:getChildren()) do
		local index = value > 0 and startLabel + i - 1 or startLabel + i
		local data = MarketOwnOffers.mySellOffers[index]

		if not data then
			break
		end

		local color = i % 2 == 0 and "#414141" or "#484848"

		widget:setId(color)
		widget:setActionId(index)
		widget:setBackgroundColor(color)
		widget.amount:setText(data.amount)
		widget.name:setText(g_things.getThingType(data.itemId):getMarketData().name)
		widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))

		widget.counter = data.counter

		widget.piecePrice:setColor("#c0c0c0")
		widget.totalPrice:setColor("#c0c0c0")
		widget.name:setColor("#c0c0c0")
		widget.amount:setColor("#c0c0c0")
		widget.endAt:setColor("#c0c0c0")

		if data.itemTier > 0 then
			widget.name:setText(widget.name:getText() .. " (Tier " .. data.itemTier .. ")")
		end

		local totalPrice = data.price * data.amount
		local unitPrice = data.price

		widget.piecePrice:setText(convertGold(unitPrice))
		widget.totalPrice:setText(convertGold(totalPrice))

		if totalPrice > 99999999 then
			widget.totalPrice:setTooltip(comma_value(totalPrice))
		end

		if unitPrice > 99999999 then
			widget.piecePrice:setTooltip(comma_value(unitPrice))
		end

		if MarketOwnOffers.selectedSellCounter.counter == data.counter then
			widget:setBackgroundColor("#585858")
			widget.piecePrice:setColor("#f4f4f4")
			widget.totalPrice:setColor("#f4f4f4")
			widget.name:setColor("#f4f4f4")
			widget.amount:setColor("#f4f4f4")
			widget.endAt:setColor("#f4f4f4")
			window.sellOffersList:focusChild(widget)
		end
	end
end

local function createWidgetMarket(widget, count, value, startLabel, i)
	local window = marketWindow.MarketHistory.currentOffers
	local index = value > 0 and startLabel + i - 1 or startLabel + i
	local data = MarketOwnOffers.myBuyOffers[index]

	if not data then
		return false
	end

	local color = count % 2 == 0 and "#414141" or "#484848"

	widget:setId(color)
	widget:setActionId(index)
	widget:setBackgroundColor(color)
	widget.amount:setText(data.amount)
	widget.name:setText(g_things.getThingType(data.itemId):getMarketData().name)
	widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))

	widget.counter = data.counter

	widget.piecePrice:setColor("#c0c0c0")
	widget.totalPrice:setColor("#c0c0c0")
	widget.name:setColor("#c0c0c0")
	widget.amount:setColor("#c0c0c0")
	widget.endAt:setColor("#c0c0c0")

	if data.itemTier > 0 then
		widget.name:setText(widget.name:getText() .. " (Tier " .. data.itemTier .. ")")
	end

	local totalPrice = data.price * data.amount
	local unitPrice = data.price

	widget.piecePrice:setText(convertGold(unitPrice))
	widget.totalPrice:setText(convertGold(totalPrice))

	if totalPrice > 99999999 then
		widget.totalPrice:setTooltip(comma_value(totalPrice))
	end

	if unitPrice > 99999999 then
		widget.piecePrice:setTooltip(comma_value(unitPrice))
	end

	if MarketOwnOffers.selectedBuyCounter.counter == data.counter then
		widget:setBackgroundColor("#585858")
		widget.piecePrice:setColor("#f4f4f4")
		widget.totalPrice:setColor("#f4f4f4")
		widget.name:setColor("#f4f4f4")
		widget.amount:setColor("#f4f4f4")
		widget.endAt:setColor("#f4f4f4")
		window.buyOffersList:focusChild(widget)
	end

	return true
end

function MarketOwnOffers.onBottomListValueChange(scroll, value, delta)
	local window = marketWindow.MarketHistory.currentOffers
	local startLabel = math.max(MarketOwnOffers.bottomListMin, value)
	local endLabel = startLabel + MarketOwnOffers.bottomListFitItems - 1

	if endLabel > MarketOwnOffers.bottomListMax then
		endLabel = MarketOwnOffers.bottomListMax
		startLabel = endLabel - MarketOwnOffers.bottomListFitItems + 1
	end

	local count = 0

	for i, widget in ipairs(window.buyOffersList:getChildren()) do
		if createWidgetMarket(widget, count, value, startLabel, i) then
			count = count + 1
		end
	end
end
