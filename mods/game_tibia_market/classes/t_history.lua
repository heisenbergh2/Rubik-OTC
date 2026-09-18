-- chunkname: @/mods/game_tibia_market/classes/t_history.lua

MarketHistory = {}
MarketHistory.__index = MarketHistory

local onTopListValueChange, onBottomListValueChange
local topListMin, topListMax = 0, 0
local bottomListMin, bottomListMax = 0, 0
local topListFitItems, bottomListFitItems = 0, 0
local labelSize = 16
local historyOfferPool = 14
local topListPool, bottomListPool = {}, {}
local topListData, bottomListData = {}, {}
local MarketSellStatus = {
	[MarketOfferState.Active] = "active",
	[MarketOfferState.Cancelled] = "cancelled",
	[MarketOfferState.Expired] = "expired",
	[MarketOfferState.Accepted] = "sold",
	[MarketOfferState.AcceptedEx] = "sold"
}
local MarketBuyStatus = {
	[MarketOfferState.Active] = "active",
	[MarketOfferState.Cancelled] = "cancelled",
	[MarketOfferState.Expired] = "expired",
	[MarketOfferState.Accepted] = "bought",
	[MarketOfferState.AcceptedEx] = "bought"
}

local function nz(x, d)
	if type(x) == "number" then
		return x
	end

	local n = tonumber(x)

	if n then
		return n
	end

	return d or 0
end

local function safeName(itemId)
	local ok, tt = pcall(function()
		return g_things.getThingType(itemId)
	end)

	if not ok or not tt then
		return "Unknown Item (" .. tostring(itemId) .. ")"
	end

	local md = tt:getMarketData()

	return md and md.name or "Unknown Item (" .. tostring(itemId) .. ")"
end

function MarketHistory.clearPools()
	topListPool = {}
	bottomListPool = {}
end

local function setMoneyLabels(widget, unitPrice, amount)
	local totalPrice = nz(unitPrice) * nz(amount)

	widget.piecePrice:setText(convertGold(nz(unitPrice)))
	widget.totalPrice:setText(convertGold(totalPrice))

	if totalPrice > 99999999 then
		widget.totalPrice:setTooltip(comma_value(totalPrice))
	else
		widget.totalPrice:removeTooltip()
	end

	if nz(unitPrice) > 99999999 then
		widget.piecePrice:setTooltip(comma_value(nz(unitPrice)))
	else
		widget.piecePrice:removeTooltip()
	end
end

function MarketHistory.onTopListValueChange(scroll, value, delta)
	value = nz(value, 0)

	local startLabel = math.max(nz(topListMin, 0), value)
	local endLabel = startLabel + nz(topListFitItems, 0) - 1

	if endLabel > nz(topListMax, 0) then
		endLabel = nz(topListMax, 0)
		startLabel = endLabel - nz(topListFitItems, 0) + 1
	end

	if startLabel < nz(topListMin, 0) then
		startLabel = nz(topListMin, 0)
	end

	for i, widget in ipairs(topListPool) do
		local index = value > 0 and startLabel + i - 1 or startLabel + i
		local data = topListData[index]

		if data then
			local color = index % 2 == 0 and "#484848" or "#414141"

			widget:setId(color)
			widget:setActionId(index)
			widget:setBackgroundColor(color)
			widget:setColor("#c0c0c0")

			local amount = nz(data.amount, 0)
			local itemId = nz(data.itemId, 0)
			local ts = nz(data.timestamp, os.time())
			local state = data.state
			local itemTier = nz(data.itemTier, 0)
			local price = nz(data.price, 0)

			widget.amount:setText(amount)
			widget.name:setText(safeName(itemId))

			if itemTier > 0 then
				widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
			end

			widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", ts))
			widget.status:setText(MarketSellStatus[state] or "-")
			widget.piecePrice:setColor("#c0c0c0")
			widget.totalPrice:setColor("#c0c0c0")
			widget.name:setColor("#c0c0c0")
			widget.amount:setColor("#c0c0c0")
			widget.endAt:setColor("#c0c0c0")
			widget.status:setColor("#c0c0c0")
			setMoneyLabels(widget, price, amount)
			widget:setVisible(true)
		else
			widget:setVisible(false)
		end
	end

	local window = marketWindow.MarketHistory:recursiveGetChildById("sellOffersList")

	window:focusChild(nil)

	lastSelectedHistorySell = nil
end

function MarketHistory.onBottomListValueChange(scroll, value, delta)
	value = nz(value, 0)

	local startLabel = math.max(nz(bottomListMin, 0), value)
	local endLabel = startLabel + nz(bottomListFitItems, 0) - 1

	if endLabel > nz(bottomListMax, 0) then
		endLabel = nz(bottomListMax, 0)
		startLabel = endLabel - nz(bottomListFitItems, 0) + 1
	end

	if startLabel < nz(bottomListMin, 0) then
		startLabel = nz(bottomListMin, 0)
	end

	for i, widget in ipairs(bottomListPool) do
		local index = value > 0 and startLabel + i - 1 or startLabel + i
		local data = bottomListData[index]

		if data then
			local color = index % 2 == 0 and "#484848" or "#414141"

			widget:setId(color)
			widget:setActionId(index)
			widget:setBackgroundColor(color)
			widget:setColor("#c0c0c0")

			local amount = nz(data.amount, 0)
			local itemId = nz(data.itemId, 0)
			local ts = nz(data.timestamp, os.time())
			local state = data.state
			local itemTier = nz(data.itemTier, 0)
			local price = nz(data.price, 0)

			widget.amount:setText(amount)
			widget.name:setText(safeName(itemId))

			if itemTier > 0 then
				widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
			end

			widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", ts))
			widget.status:setText(MarketBuyStatus[state] or "-")
			widget.piecePrice:setColor("#c0c0c0")
			widget.totalPrice:setColor("#c0c0c0")
			widget.name:setColor("#c0c0c0")
			widget.amount:setColor("#c0c0c0")
			widget.endAt:setColor("#c0c0c0")
			widget.status:setColor("#c0c0c0")
			setMoneyLabels(widget, price, amount)
			widget:setVisible(true)
		else
			widget:setVisible(false)
		end
	end

	local window = marketWindow.MarketHistory:recursiveGetChildById("buyOffersList")

	window:focusChild(nil)

	lastSelectedHistoryBuy = nil
end

function MarketHistory.onParseMarketHistory(buyOffers, sellOffers)
	local window = marketWindow.MarketHistory.currentOffers

	modules.game_market.setMyOffersHeaderHistoryMode(true)
	modules.game_market.updateMarketWindowTitle("offerHistory")

	lastSelectedMySell = nil
	lastSelectedMyBuy = nil

	window.sellOffersList:focusChild(nil)
	window.buyOffersList:focusChild(nil)
	window.buyOffersList:destroyChildren()
	window.sellOffersList:destroyChildren()
	window.buyCancelOffer:setVisible(false)
	window.sellCancelOffer:setVisible(false)

	lastSelectedHistorySell = nil
	lastSelectedHistoryBuy = nil
	sellOffers = type(sellOffers) == "table" and sellOffers or {}
	buyOffers = type(buyOffers) == "table" and buyOffers or {}
	topListFitItems = math.max(0, math.floor(nz(window.sellOffersList:getHeight(), 0) / labelSize))
	topListMin = 0
	topListPool = {}
	topListData = sellOffers
	topListMax = nz(#sellOffers, 0)

	for i = 1, historyOfferPool do
		local widget = g_ui.createWidget("MarketHistoryWidget", window.sellOffersList)
		local data = sellOffers[i]

		if not data then
			widget:setVisible(false)
		else
			local color = i % 2 == 0 and "#414141" or "#484848"

			widget:setId(color)
			widget:setActionId(i)
			widget:setBackgroundColor(color)

			local amount = nz(data.amount, 0)
			local itemId = nz(data.itemId, 0)
			local ts = nz(data.timestamp, os.time())
			local state = data.state
			local itemTier = nz(data.itemTier, 0)
			local price = nz(data.price, 0)

			widget.amount:setText(amount)
			widget.name:setText(safeName(itemId))

			if itemTier > 0 then
				widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
			end

			widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", ts))
			widget.status:setText(MarketSellStatus[state] or "-")
			setMoneyLabels(widget, price, amount)
		end

		table.insert(topListPool, widget)
	end

	local sellScrollbar = marketWindow.MarketHistory:recursiveGetChildById("sellOffersListScroll")

	sellScrollbar:setMinimum(nz(topListMin, 0))
	sellScrollbar:setMaximum(math.max(0, nz(topListMax, 0) - historyOfferPool))

	function sellScrollbar:onValueChange(value, delta)
		MarketHistory.onTopListValueChange(self, value, delta)
	end

	bottomListFitItems = math.max(0, math.floor(nz(window.buyOffersList:getHeight(), 0) / labelSize))
	bottomListMin = 0
	bottomListPool = {}
	bottomListData = buyOffers
	bottomListMax = nz(#buyOffers, 0)

	for i = 1, historyOfferPool do
		local widget = g_ui.createWidget("MarketHistoryWidget", window.buyOffersList)
		local data = buyOffers[i]

		if not data then
			widget:setVisible(false)
		else
			local color = i % 2 == 0 and "#414141" or "#484848"

			widget:setId(color)
			widget:setActionId(i)
			widget:setBackgroundColor(color)

			local amount = nz(data.amount, 0)
			local itemId = nz(data.itemId, 0)
			local ts = nz(data.timestamp, os.time())
			local state = data.state
			local itemTier = nz(data.itemTier, 0)
			local price = nz(data.price, 0)

			widget.amount:setText(amount)
			widget.name:setText(safeName(itemId))

			if itemTier > 0 then
				widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
			end

			widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", ts))
			widget.status:setText(MarketBuyStatus[state] or "-")
			setMoneyLabels(widget, price, amount)
		end

		table.insert(bottomListPool, widget)
	end

	local buyScrollbar = marketWindow.MarketHistory:recursiveGetChildById("buyOffersListScroll")

	buyScrollbar:setMinimum(nz(bottomListMin, 0))
	buyScrollbar:setMaximum(math.max(0, nz(bottomListMax, 0) - historyOfferPool))

	function buyScrollbar:onValueChange(value, delta)
		MarketHistory.onBottomListValueChange(self, value, delta)
	end

	function window.sellOffersList:onChildFocusChange(selected)
		MarketHistory.onSelectHistoryChild(self, selected, true)
	end

	function window.buyOffersList:onChildFocusChange(selected)
		MarketHistory.onSelectHistoryChild(self, selected, false)
	end

	local firstChild = window.sellOffersList:getChildren()[1]

	if firstChild then
		window.sellOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
	end

	firstChild = window.buyOffersList:getChildren()[1]

	if firstChild then
		window.buyOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
	end

	window.sellOffersLabel:setText("Sell Offers (" .. nz(#sellOffers, 0) .. "):")
	window.buyOffersLabel:setText("Buy Offers (" .. nz(#buyOffers, 0) .. "):")
end

function MarketHistory.onSelectHistoryChild(widget, selected, selling)
	if not selected then
		return
	end

	local lastSelected = selling and lastSelectedHistorySell or lastSelectedHistoryBuy

	if lastSelected then
		if lastSelected:isDestroyed() or not lastSelected.piecePrice then
			lastSelected = nil

			if selling then
				lastSelectedHistorySell = nil
			else
				lastSelectedHistoryBuy = nil
			end
		else
			lastSelected:setBackgroundColor(lastSelected:getId())
			lastSelected.piecePrice:setColor("#c0c0c0")
			lastSelected.totalPrice:setColor("#c0c0c0")
			lastSelected.name:setColor("#c0c0c0")
			lastSelected.amount:setColor("#c0c0c0")
			lastSelected.endAt:setColor("#c0c0c0")
			lastSelected.status:setColor("#c0c0c0")
		end
	end

	if selling then
		lastSelectedHistorySell = selected
	else
		lastSelectedHistoryBuy = selected
	end

	selected:setBackgroundColor("#585858")
	selected.piecePrice:setColor("#f4f4f4")
	selected.totalPrice:setColor("#f4f4f4")
	selected.name:setColor("#f4f4f4")
	selected.amount:setColor("#f4f4f4")
	selected.endAt:setColor("#f4f4f4")
	selected.status:setColor("#f4f4f4")
end
