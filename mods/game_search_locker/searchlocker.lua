-- chunkname: @/mods/game_search_locker/searchlocker.lua

searchlocker = nil

local marketItems = {}
local categoryList = {}
local depotItemList = {}
local titemList = {}
local lastSelectedCategory, searchActiveCategory, lastSelectedItem
local suppressSearchCallbacks = false
local currentSearchTier = 0
local lastDetailItemId
local lastDetailItemTier = 0
local showLockerOnly = false
local playerAtDepot = false
local searchPage, itemSearchPage
local searchLockerSearchActive = false
local searchLockerOutsideHandler, refreshSearchLockerContent
local enableCategories = {
	17,
	18,
	19,
	20,
	21,
	27,
	32
}
local enableClassification = {
	1,
	3,
	7,
	8,
	15,
	17,
	18,
	19,
	20,
	21,
	24,
	27,
	32
}
local sortButtons = {
	oneButton = false,
	vocButton = false,
	levelButton = false,
	tierFilter = 0,
	classFilter = -1,
	twoButton = false
}
local listConfig = {
	maxFitItems = 0,
	max = 0,
	min = 0,
	labelSize = 36,
	visibleSlots = 0,
	labels = {},
	displayList = {},
	itemListSorted = {}
}
local LIST_MAX_VISIBLE_SLOTS = 4
local EMPTY_SLOT_OPACITY = 0.5
local EMPTY_TINT = "#808080"
local NORMAL_TINT = "#ffffff"

local function fmtItemQty(n)
	n = tonumber(n) or 0

	if n < 1 then
		return "0"
	end

	if n < 1000 then
		return tostring(n)
	end

	if n < 1000000 then
		return string.format("%dk", math.floor(n / 1000))
	end

	if n < 1000000000 then
		return string.format("%dm", math.floor(n / 1000000))
	end

	return string.format("%db", math.floor(n / 1000000000))
end

local function setItemAmount(label, count)
	if not label then
		return
	end

	label:setText(fmtItemQty(count))
	label:setVisible(true)
end

local function applyItemRarity(rarityWidget, itemId)
	if not rarityWidget then
		return
	end

	if not itemId or itemId == 0 then
		ItemsDatabase.setRarityItem(rarityWidget, nil)
		rarityWidget:setImageSource("")
		rarityWidget:setImageClip("0 0 0 0")
		rarityWidget:setVisible(false)

		return
	end

	local thing = g_things.getThingType(itemId, ThingCategoryItem)

	if not thing then
		ItemsDatabase.setRarityItem(rarityWidget, nil)
		rarityWidget:setImageSource("")
		rarityWidget:setImageClip("0 0 0 0")
		rarityWidget:setVisible(false)

		return
	end

	ItemsDatabase.setRarityItem(rarityWidget, thing:getMeanPrice())
	rarityWidget:setVisible(rarityWidget:getImageSource() ~= "")
end

local function applyItemTierBadge(rowWidget, tier)
	if not rowWidget then
		return
	end

	ItemsDatabase.setTier(rowWidget, tier or 0)
end

local function applyRetrieveSlotVisuals(slotWidget, item, itemId, tier)
	if not slotWidget then
		return
	end

	local itemUi = slotWidget.item

	if not itemUi then
		return
	end

	if item then
		itemUi:setItem(item)
	elseif itemId and itemId > 0 then
		itemUi:setItemId(itemId)

		local virtualItem = itemUi:getItem()

		if virtualItem and tier and tier > 0 then
			virtualItem:setTier(tier)
		end
	else
		itemUi:setItem(nil)
	end

	if slotWidget.rarity then
		if item then
			ItemsDatabase.setRarityItem(slotWidget.rarity, item)
			ItemsDatabase.syncRarityWidgetVisibility(slotWidget.rarity)
		elseif itemId and itemId > 0 then
			local thing = g_things.getThingType(itemId, ThingCategoryItem)

			ItemsDatabase.setRarityItem(slotWidget.rarity, thing and thing:getMeanPrice() or 0)
			ItemsDatabase.syncRarityWidgetVisibility(slotWidget.rarity)
		else
			ItemsDatabase.setRarityItem(slotWidget.rarity, nil)
			slotWidget.rarity:setVisible(false)
		end

		ItemsDatabase.applyContainerRarityStackOrder(slotWidget)
	end

	if item then
		ItemsDatabase.setTier(slotWidget, item)
	else
		ItemsDatabase.setTier(slotWidget, tier or 0)
	end
end

local function applyItemNameColor(nameWidget, count)
	if not nameWidget then
		return
	end

	nameWidget:setColor(count > 0 and "#c0c0c0" or "#707070")
end

local function applyItemSlotOpacity(rowWidget, count)
	if not rowWidget then
		return
	end

	local empty = count == 0
	local slotOpacity = empty and EMPTY_SLOT_OPACITY or 1

	if rowWidget.itemSlot then
		rowWidget.itemSlot:setOpacity(slotOpacity)
	end

	if rowWidget.tier then
		rowWidget.tier:setOpacity(slotOpacity)
	end

	if rowWidget.amount then
		rowWidget.amount:setOpacity(slotOpacity)
	end

	if rowWidget.rarity then
		rowWidget.rarity:setOpacity(slotOpacity)
	end

	if rowWidget.item then
		rowWidget.item:setOpacity(slotOpacity)
		rowWidget.item:setColor(empty and EMPTY_TINT or NORMAL_TINT)
	end
end

local function applyItemListName(nameWidget, itemName)
	if not nameWidget or not itemName then
		return
	end

	nameWidget:setText(itemName)

	if nameWidget:isOfflimit(20) then
		nameWidget:setTooltip(itemName)
	else
		nameWidget:setTooltip("")
	end
end

local function applyPreviewTierBadge(tier)
	if not searchlocker then
		return
	end

	local previewTier = searchlocker:recursiveGetChildById("previewTier")

	if previewTier then
		ItemsDatabase.setTier({
			tier = previewTier
		}, tier or 0)
	end
end

local function applyItemRowVisual(rowWidget, itemId, tier, count, itemName)
	if not rowWidget then
		return
	end

	setItemAmount(rowWidget.amount, count)
	applyItemRarity(rowWidget.rarity, itemId)
	applyItemTierBadge(rowWidget, tier)
	applyItemNameColor(rowWidget.name, count)
	applyItemSlotOpacity(rowWidget, count)
	applyItemListName(rowWidget.name, itemName)
end

local function updateSelectedItemPreview(itemId, tier)
	if not searchlocker then
		return
	end

	applyItemRarity(searchlocker:recursiveGetChildById("previewRarity"), itemId)
	applyPreviewTierBadge(tier)

	local previewItemSlot = searchlocker:recursiveGetChildById("previewItemSlot")
	local selectedItemWidget = searchlocker:recursiveGetChildById("selectedItem")

	if previewItemSlot then
		previewItemSlot:setOpacity(1)
	end

	if selectedItemWidget then
		selectedItemWidget:setOpacity(1)
		selectedItemWidget:setColor(NORMAL_TINT)
	end
end

local function getScrollSlots(itemList)
	if not itemList then
		return 1
	end

	local paddingTop = itemList.getPaddingTop and itemList:getPaddingTop() or 0
	local paddingBottom = itemList.getPaddingBottom and itemList:getPaddingBottom() or 0
	local padding = paddingTop + paddingBottom

	if padding == 0 then
		padding = 2
	end

	return math.max(1, math.floor((itemList:getHeight() - padding) / listConfig.labelSize))
end

local function resetItemListScrollbar()
	if not searchlocker then
		return
	end

	local scrollbar = searchlocker:recursiveGetChildById("itemListScroll")

	if not scrollbar then
		return
	end

	scrollbar.onValueChange = nil

	scrollbar:setMinimum(0)
	scrollbar:setMaximum(0)
	scrollbar:setValue(0)
	scrollbar:setStep(listConfig.labelSize)
end

local function setupItemListScrollbar(itemScrollMax)
	local scrollbar = searchlocker:recursiveGetChildById("itemListScroll")

	if not scrollbar then
		return
	end

	scrollbar:setMinimum(0)
	scrollbar:setValue(0)
	scrollbar:setStep(listConfig.labelSize)

	if itemScrollMax <= 0 then
		scrollbar:setMaximum(0)

		scrollbar.onValueChange = nil

		return
	end

	scrollbar:setMaximum(itemScrollMax * listConfig.labelSize)

	function scrollbar:onValueChange(scrollValue, scrollDelta)
		onItemScrollValueChange(self, scrollValue, scrollDelta, listConfig.displayList, listConfig.itemListSorted)
	end
end

local CATEGORY_ORDER = {
	{
		name = "All",
		id = MarketCategory.All
	},
	{
		name = "Armors",
		id = MarketCategory.Armors
	},
	{
		name = "Amulets",
		id = MarketCategory.Amulets
	},
	{
		name = "Boots",
		id = MarketCategory.Boots
	},
	{
		name = "Containers",
		id = MarketCategory.Containers
	},
	{
		name = "Creature Products",
		id = MarketCategory.CreatureProducs
	},
	{
		name = "Decoration",
		id = MarketCategory.Decoration
	},
	{
		name = "Food",
		id = MarketCategory.Food
	},
	{
		name = "Gold",
		id = MarketCategory.Gold
	},
	{
		name = "Helmets and Hats",
		id = MarketCategory.HelmetsHats
	},
	{
		name = "Legs",
		id = MarketCategory.Legs
	},
	{
		name = "Others",
		id = MarketCategory.Others
	},
	{
		name = "Potions",
		id = MarketCategory.Potions
	},
	{
		name = "Quivers",
		id = MarketCategory.Quivers
	},
	{
		name = "Rings",
		id = MarketCategory.Rings
	},
	{
		name = "Runes",
		id = MarketCategory.Runes
	},
	{
		name = "Shields",
		id = MarketCategory.Shields
	},
	{
		name = "Soul Cores",
		id = MarketCategory.SoulCore
	},
	{
		name = "Tools",
		id = MarketCategory.Tools
	},
	{
		name = "Unsorted",
		id = MarketCategory.Unassigned
	},
	{
		name = "Valuables",
		id = MarketCategory.Valuables
	},
	{
		name = "Weapons: Ammo",
		id = MarketCategory.Ammunition
	},
	{
		name = "Weapons: Axes",
		id = MarketCategory.Axes
	},
	{
		name = "Weapons: Clubs",
		id = MarketCategory.Clubs
	},
	{
		name = "Weapons: Distance",
		id = MarketCategory.DistanceWeapons
	},
	{
		name = "Weapons: Fist",
		id = MarketCategory.FistWeapons
	},
	{
		name = "Weapons: Swords",
		id = MarketCategory.Swords
	},
	{
		name = "Weapons: Wands",
		id = MarketCategory.WandsRods
	},
	{
		name = "Weapons: All",
		id = MarketCategory.WeaponsAll
	}
}
local WEAPON_CATEGORIES = {
	MarketCategory.Ammunition,
	MarketCategory.Axes,
	MarketCategory.Clubs,
	MarketCategory.DistanceWeapons,
	MarketCategory.FistWeapons,
	MarketCategory.Swords,
	MarketCategory.WandsRods
}

local function compareMarketItemsByNameCaseInsensitive(a, b)
	local nameA = string.lower(a.marketData.name or "")
	local nameB = string.lower(b.marketData.name or "")

	return nameA < nameB
end

local function normalizeSearchText(text)
	if not text then
		return ""
	end

	return text:match("^%s*(.-)%s*$") or ""
end

local function itemNameMatchesSearch(itemName, searchTerm)
	searchTerm = normalizeSearchText(searchTerm)

	if searchTerm == "" then
		return false
	end

	return string.lower(itemName or ""):find(string.lower(searchTerm), 1, true) ~= nil
end

local function getActiveSearchText()
	if not searchlocker then
		return ""
	end

	local searchEdit = searchlocker:recursiveGetChildById("searchText")

	return normalizeSearchText(searchEdit and searchEdit:getText() or "")
end

local function getItemName(itemId)
	if modules.game_analysers and modules.game_analysers.getItemServerName then
		return modules.game_analysers.getItemServerName(itemId)
	end

	local thing = g_things.getThingType(itemId, ThingCategoryItem)

	return thing and thing:getName() or "item"
end

local function normalizeDepotItemList(items)
	local result = {}

	if type(items) ~= "table" then
		return result
	end

	for _, data in pairs(items) do
		if type(data) == "table" then
			local itemId = data.itemId or data[1]
			local tier = data.tier or data[2] or 0
			local count = data.count or data[3] or 0

			if itemId then
				table.insert(result, {
					itemId = itemId,
					tier = tier,
					count = count
				})
			end
		end
	end

	return result
end

local function setupWindow(window)
	local resizeBorder = window.bottomResizeBorder

	if not resizeBorder then
		return
	end

	resizeBorder:enable()

	function resizeBorder.onDoubleClick()
		window:setHeight(resizeBorder:getMinimum())
	end
end

local function addSearchLockerToPanel()
	if not searchlocker or not modules.game_interface then
		return false
	end

	local existingParent = searchlocker:getParent()

	if existingParent and not existingParent:isDestroyed() then
		if searchlocker.open then
			searchlocker:open(true)
		else
			searchlocker:show()
		end

		return true
	end

	local panel = modules.game_interface.getRightPanel and modules.game_interface.getRightPanel()

	if not panel and modules.game_interface.findContentPanelAvailable then
		local ok, result = pcall(function()
			return modules.game_interface.findContentPanelAvailable(searchlocker, searchlocker:getMinimumHeight() or 295)
		end)

		if ok then
			panel = result
		end
	end

	if not panel then
		return false
	end

	if searchlocker:getParent() ~= panel then
		searchlocker:setParent(panel)
	end

	if searchlocker.open then
		searchlocker:open(true)
	else
		searchlocker:show()
	end

	return true
end

local function isSearchLockerRefresh()
	if not searchlocker then
		return false
	end

	local header = searchlocker:recursiveGetChildById("headerContentPanel")

	return header ~= nil and #header:getChildren() > 0
end

function init()
	searchlocker = g_ui.displayUI("searchlocker")

	if not searchlocker then
		g_logger.error("[game_search_locker] failed to load searchlocker.otui")

		return
	end

	hideSearch()
	setupWindow(searchlocker)

	searchlocker:recursiveGetChildById("lockerOnly").onCheckChange = function(self, checked)
		toggleShowLockerOnly(self, checked)
	end

	searchlocker:setup()

	local closeButton = searchlocker:getChildById("closeButton")

	if closeButton then
		closeButton.onClick = hideSearch
	end

	if searchlocker.setContentMinimumHeight then
		pcall(function()
			searchlocker:setContentMinimumHeight(295)
		end)
	end

	searchPage = searchlocker:recursiveGetChildById("searchPage")
	itemSearchPage = searchlocker:recursiveGetChildById("itemSearchPage")

	addEvent(setupSearchField)
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onRecvDepotLockerItems = onRecvDepotLockerItems,
		onCloseSearchLocker = onCloseSearchLocker,
		onRecvSearchItem = onRecvSearchItem,
		onSpecialContainer = onSpecialContainer
	})
end

function terminate()
	blurSearchLockerSearch()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onRecvDepotLockerItems = onRecvDepotLockerItems,
		onCloseSearchLocker = onCloseSearchLocker,
		onRecvSearchItem = onRecvSearchItem,
		onSpecialContainer = onSpecialContainer
	})

	if searchlocker then
		searchlocker:destroy()

		searchlocker = nil
	end
end

function online()
	onCloseSearchLocker()
end

function offline()
	onCloseSearchLocker()
end

function toggle()
	if searchlocker and searchlocker:isVisible() then
		hideSearch()
	else
		onRequestSearch()
	end
end

function onSearchLockerEscape()
	if searchLockerSearchActive then
		blurSearchLockerSearch()

		return
	end

	if itemSearchPage and itemSearchPage:isVisible() then
		onBackToSearchPage()

		return
	end

	hideSearch()
end

function hideSearch()
	blurSearchLockerSearch()

	if searchlocker then
		searchlocker:hide()
	end
end

function show()
	if searchlocker then
		searchlocker:show()
	end
end

local function clearSelectedItemPreview()
	if not searchlocker then
		return
	end

	local selectedItemWidget = searchlocker:recursiveGetChildById("selectedItem")

	if selectedItemWidget then
		if selectedItemWidget.clearItem then
			selectedItemWidget:clearItem()
		else
			selectedItemWidget:setItemId(0)
		end

		selectedItemWidget:setTier(0)
	end

	applyItemRarity(searchlocker:recursiveGetChildById("previewRarity"), nil)
	applyPreviewTierBadge(0)

	local searchItemButton = searchlocker:recursiveGetChildById("searchItemButton")

	if searchItemButton then
		searchItemButton:setEnabled(false)

		searchItemButton.onClick = nil
	end
end

local function resetSearchLockerBrowseState(preserveSearch)
	if not searchlocker then
		return
	end

	if not preserveSearch then
		local prev = suppressSearchCallbacks

		suppressSearchCallbacks = true

		local searchEdit = searchlocker:recursiveGetChildById("searchText")

		if searchEdit then
			searchEdit:setText("")
		end

		suppressSearchCallbacks = prev
	end

	searchActiveCategory = nil

	if lastSelectedCategory then
		lastSelectedCategory:setBackgroundColor(lastSelectedCategory.color)
		lastSelectedCategory:setColor("#c0c0c0")

		lastSelectedCategory = nil
	end

	lastSelectedItem = nil

	clearSelectedItemPreview()

	local itemList = searchlocker:recursiveGetChildById("itemListAll")

	if itemList then
		itemList:destroyChildren()
	end

	listConfig.labels = {}
	listConfig.displayList = {}
	listConfig.itemListSorted = {}
	listConfig.max = 0

	resetItemListScrollbar()
end

local function resetItemSearchPage()
	if not itemSearchPage then
		return
	end

	local itemList = itemSearchPage:recursiveGetChildById("itemsList")

	if itemList then
		itemList:destroyChildren()
	end

	local retrieveButton = itemSearchPage:recursiveGetChildById("retrieveButton")

	if retrieveButton then
		retrieveButton:setVisible(true)
		retrieveButton:setEnabled(false)

		retrieveButton.onClick = nil
	end

	local stashRetrieveButton = itemSearchPage:recursiveGetChildById("stashRetrieveButton")

	if stashRetrieveButton then
		stashRetrieveButton:setVisible(false)
		stashRetrieveButton:setEnabled(false)

		stashRetrieveButton.onClick = nil
	end

	if modules.game_stash and modules.game_stash.resetSelectAmount then
		modules.game_stash.resetSelectAmount()
	end
end

local function setItemSearchBackButtonVisible(visible)
	if not searchlocker then
		return
	end

	local backButton = searchlocker:getChildById("backButton")

	if backButton then
		backButton:setVisible(visible)
	end
end

local function openRetrieveAmountSelector(itemId, amount, onConfirm)
	if not amount or amount <= 0 or not onConfirm then
		return
	end

	if modules.game_stash and modules.game_stash.prepareRetrieveAmount then
		modules.game_stash.prepareRetrieveAmount(itemId, amount, onConfirm)
	else
		onConfirm(amount == 1 and 1 or amount)
	end
end

local function getDisplayedItemsCount(list)
	local total = 0

	if type(list) ~= "table" then
		return total
	end

	for _, item in ipairs(list) do
		if item and item.getCount then
			total = total + item:getCount()
		end
	end

	return total
end

function onCloseSearchLocker()
	depotItemList = {}
	lastSelectedCategory = nil
	searchActiveCategory = nil
	lastSelectedItem = nil
	lastDetailItemId = nil
	lastDetailItemTier = 0
	titemList = {}

	if not searchlocker then
		return
	end

	searchlocker:recursiveGetChildById("headerContentPanel"):destroyChildren()
	searchlocker:recursiveGetChildById("itemListAll"):destroyChildren()

	listConfig.labels = {}
	listConfig.displayList = {}
	listConfig.itemListSorted = {}
	listConfig.max = 0

	resetItemListScrollbar()
	blurSearchLockerSearch()
	clearSelectedItemPreview()
	clearSearch()
	resetItemSearchPage()
	setItemSearchBackButtonVisible(false)
	onClearHandFilter()
	hideSearch()
end

function onSpecialContainer(_, marketAvailable)
	playerAtDepot = marketAvailable == true

	if not marketAvailable and searchlocker and searchlocker:isVisible() then
		g_game.closeSearchLocker()
	end
end

function configureList()
	marketItems = {}
	marketItems[MarketCategory.All] = {}

	for c = MarketCategory.First, MarketCategory.WeaponsAll do
		marketItems[c] = {}
	end

	local types = g_things.findThingTypeByAttr(ThingAttrMarket, 0)

	for _, itemType in pairs(types) do
		if itemType:getId() == 49870 then
			-- block empty
		else
			local item = Item.create(itemType:getId())

			if item then
				local marketData = itemType:getMarketData()

				if not table.empty(marketData) then
					item:setId(marketData.showAs)

					local marketItem = {
						displayItem = item,
						thingType = itemType,
						marketData = marketData
					}

					if marketItems[marketData.category] ~= nil then
						table.insert(marketItems[marketData.category], marketItem)
					end
				end
			end
		end
	end

	for _, categoryId in ipairs(WEAPON_CATEGORIES) do
		for _, data in pairs(marketItems[categoryId]) do
			table.insert(marketItems[MarketCategory.WeaponsAll], data)
		end
	end

	for c = MarketCategory.First, MarketCategory.WeaponsAll do
		if marketItems[c] then
			table.sort(marketItems[c], compareMarketItemsByNameCaseInsensitive)
		end
	end

	for _, category in ipairs(CATEGORY_ORDER) do
		local id = category.id

		if id ~= MarketCategory.All and id ~= MarketCategory.WeaponsAll then
			for _, data in ipairs(marketItems[id] or {}) do
				table.insert(marketItems[MarketCategory.All], data)
			end
		end
	end

	table.sort(marketItems[MarketCategory.All], compareMarketItemsByNameCaseInsensitive)

	categoryList = {}

	for _, category in ipairs(CATEGORY_ORDER) do
		table.insert(categoryList, {
			category.id,
			"category_" .. tostring(category.id),
			category.name
		})
	end
end

function initFields()
	configureList()

	local optionList = searchlocker:recursiveGetChildById("headerContentPanel")

	optionList:destroyChildren()

	local colorCount = 0

	for _, pair in ipairs(categoryList) do
		local widget = g_ui.createWidget("CategoryItemListLabel", optionList)
		local color = colorCount % 2 == 0 and "#484848" or "#414141"

		widget:setActionId(pair[1])

		widget.color = color

		widget:setId(pair[2])
		widget:setText(pair[3])
		widget:setBackgroundColor(color)

		colorCount = colorCount + 1
	end

	function optionList:onChildFocusChange(selected)
		blurSearchLockerSearch()
		onSelectChildCategory(self, selected)
	end
end

function onRequestSearch()
	if not playerAtDepot then
		for _, container in pairs(g_game.getContainers()) do
			if container:isInDepot() then
				playerAtDepot = true

				break
			end
		end
	end

	if not playerAtDepot then
		return
	end

	g_game.requestSearchLocker()
end

function onBackToSearchPage()
	if not searchlocker then
		return
	end

	lastDetailItemId = nil
	lastDetailItemTier = 0

	searchPage:setVisible(true)
	itemSearchPage:setVisible(false)
	resetItemSearchPage()
	setItemSearchBackButtonVisible(false)
end

function onRecvDepotLockerItems(itemList)
	if not searchlocker then
		return
	end

	local isRefresh = isSearchLockerRefresh()

	if not addSearchLockerToPanel() then
		return
	end

	depotItemList = normalizeDepotItemList(itemList)

	if isRefresh then
		refreshSearchLockerContent()
		searchlocker:show()

		return
	end

	clearSelectedItemPreview()
	clearSearch()
	resetItemSearchPage()
	searchlocker:recursiveGetChildById("itemListAll"):destroyChildren()

	listConfig.labels = {}
	listConfig.displayList = {}
	listConfig.itemListSorted = {}
	listConfig.max = 0
	lastSelectedCategory = nil
	searchActiveCategory = nil
	lastSelectedItem = nil

	initFields()
	resetItemListScrollbar()
	searchlocker:show()
	searchPage:setVisible(true)
	itemSearchPage:setVisible(false)
	setItemSearchBackButtonVisible(false)
	focusSearchLockerSearch(true)
end

function toggleShowLockerOnly(widget, checked)
	showLockerOnly = checked

	if not lastSelectedCategory and getActiveSearchText() ~= "" then
		onTextChange()

		return
	end

	onSelectChildCategory(nil, lastSelectedCategory, true)
end

function getLockerItemCount(itemId, tier)
	local wantedTier = tier or 0

	for _, data in pairs(depotItemList) do
		if data.itemId == itemId and (data.tier or 0) == wantedTier then
			return data.count or 0
		end
	end

	if itemId == 22118 then
		return g_game.getTransferableTibiaCoins()
	end

	return 0
end

local function resolveLockerItemTierAndCount(itemId, tierFilter)
	tierFilter = tierFilter or 0

	if itemId == 22118 then
		return 0, g_game.getTransferableTibiaCoins()
	end

	if tierFilter > 0 then
		return tierFilter, getLockerItemCount(itemId, tierFilter)
	end

	local countAtZero = getLockerItemCount(itemId, 0)

	if countAtZero > 0 or not showLockerOnly then
		return 0, countAtZero
	end

	local bestTier, bestCount = 0, 0

	for _, data in pairs(depotItemList) do
		if data.itemId == itemId then
			local count = data.count or 0

			if count > 0 then
				local tier = data.tier or 0

				if bestCount < count or count == bestCount and bestTier < tier then
					bestTier = tier
					bestCount = count
				end
			end
		end
	end

	return bestTier, bestCount
end

function onClearHandFilter()
	searchlocker:recursiveGetChildById("oneButton"):setEnabled(false)
	searchlocker:recursiveGetChildById("oneButton"):setChecked(false)
	searchlocker:recursiveGetChildById("twoButton"):setEnabled(false)
	searchlocker:recursiveGetChildById("twoButton"):setChecked(false)

	sortButtons.oneButton = false
	sortButtons.twoButton = false
end

local function getItemMaxTier(thingType)
	if not thingType then
		return 0
	end

	local classification = thingType:getClassification()

	if classification == 0 then
		return 0
	end

	if classification == 4 then
		return 10
	end

	return classification
end

local function getTierFilterMaxTier(classFilter)
	if classFilter == 1 then
		return 1
	end

	if classFilter == 2 then
		return 2
	end

	if classFilter == 3 then
		return 3
	end

	return 10
end

local function populateTierFilterOptions(classFilter)
	if not searchlocker then
		return
	end

	local tierFilter = searchlocker:recursiveGetChildById("tierFilter")

	if not tierFilter then
		return
	end

	tierFilter:clearOptions()

	sortButtons.tierFilter = 0

	if classFilter == 0 then
		tierFilter:clearText()
		tierFilter:setEnabled(true)

		return
	end

	local maxTier = getTierFilterMaxTier(classFilter)

	for i = 0, maxTier do
		tierFilter:addOption("Tier " .. i)
	end

	tierFilter:setCurrentOption("Tier 0", true)
	tierFilter:setEnabled(true)
end

function onSortLockerFields(widget, checked)
	local widgetId = widget:getId()

	if table.contains({
		"oneButton",
		"twoButton",
		"levelButton",
		"vocButton"
	}, widgetId) then
		widget:setChecked(not checked)

		sortButtons[widgetId] = not checked

		if widgetId == "oneButton" then
			sortButtons.twoButton = false

			searchlocker:recursiveGetChildById("twoButton"):setChecked(false)
		elseif widgetId == "twoButton" then
			sortButtons.oneButton = false

			searchlocker:recursiveGetChildById("oneButton"):setChecked(false)
		end
	elseif widgetId == "classFilter" then
		sortButtons.classFilter = checked > 1 and checked - 2 or -1

		populateTierFilterOptions(sortButtons.classFilter)
	elseif widgetId == "tierFilter" then
		sortButtons.tierFilter = checked - 1
	end

	if not lastSelectedCategory and getActiveSearchText() ~= "" then
		onTextChange()

		return
	end

	onSelectChildCategory(nil, lastSelectedCategory, true)
end

function onSellerChange(widget, option)
	if not lastSelectedCategory and getActiveSearchText() ~= "" then
		onTextChange()

		return
	end

	onSelectChildCategory(nil, lastSelectedCategory, true)
end

function populateSellerOptions(comboBox)
	if not comboBox then
		return
	end

	if modules.game_stash and modules.game_stash.populateTraderNpcComboBox then
		modules.game_stash.populateTraderNpcComboBox(comboBox, {
			sellToPrefix = false,
			allOption = tr("All Traders")
		})
	end
end

local function getSelectedTraderNpcName()
	if not searchlocker then
		return nil
	end

	local sellerOptions = searchlocker:recursiveGetChildById("sellerOptions")

	if not sellerOptions then
		return nil
	end

	local option = sellerOptions:getCurrentOption()

	if not option or not option.text then
		return nil
	end

	local text = option.text:lower()

	if text == tr("All Traders"):lower() then
		return nil
	end

	return text
end

local function canShowItem(itemInfo, searchTerm)
	if itemInfo == nil then
		return false
	end

	searchTerm = normalizeSearchText(searchTerm)

	if searchTerm ~= "" and not itemNameMatchesSearch(itemInfo.marketData.name, searchTerm) then
		return false
	end

	local tierFilter = sortButtons.tierFilter
	local _, count = resolveLockerItemTierAndCount(itemInfo.thingType:getId(), tierFilter)

	if not checkSortLockerOptions(itemInfo) or count == 0 and showLockerOnly then
		return false
	end

	if sortButtons.classFilter ~= -1 and itemInfo.thingType:getClassification() ~= sortButtons.classFilter then
		return false
	end

	if tierFilter > 0 and tierFilter > getItemMaxTier(itemInfo.thingType) then
		return false
	end

	return true
end

local function selectItemRow(rowWidget)
	if not rowWidget or not rowWidget.item or not searchlocker then
		return
	end

	if rowWidget.item:getItemId() == 0 or not rowWidget:isVisible() then
		return
	end

	blurSearchLockerSearch()

	local itemList = searchlocker:recursiveGetChildById("itemListAll")

	if itemList and itemList.focusChild then
		itemList:focusChild(rowWidget, MouseFocusReason)
	end

	onSelectChildItem(itemList, rowWidget)
end

local function bindItemRowClick(rowWidget)
	local function handler()
		selectItemRow(rowWidget)
	end

	rowWidget.onClick = handler

	if rowWidget.item then
		rowWidget.item.onClick = handler
	end

	if rowWidget.name then
		rowWidget.name.onClick = handler
	end

	if rowWidget.itemSlot then
		rowWidget.itemSlot.onClick = handler
	end
end

function refreshSearchLockerContent()
	if itemSearchPage and itemSearchPage:isVisible() and lastDetailItemId then
		g_game.requestLockerItem(lastDetailItemId, lastDetailItemTier or 0)

		return
	end

	local searchText = getActiveSearchText()

	if searchText ~= "" then
		resetSearchLockerBrowseState(true)
		onTextChange()
	else
		resetSearchLockerBrowseState(false)
	end
end

local function createListRowWidget(itemList)
	local widget = g_ui.createWidget("SearchLockerItemList", itemList)

	bindItemRowClick(widget)

	function widget.onDoubleClick()
		local itemID = widget.item:getItemId()

		if itemID ~= 0 then
			g_game.requestLockerItem(itemID, widget.item:getItem():getTier())
		end
	end

	table.insert(listConfig.labels, widget)

	return widget
end

function onSelectChildCategory(widget, selected, resetFilter)
	if not searchlocker or not selected then
		return true
	end

	local itemList = searchlocker:recursiveGetChildById("itemListAll")

	itemList:destroyChildren()
	searchlocker:recursiveGetChildById("searchItemButton"):setEnabled(false)

	if lastSelectedCategory then
		lastSelectedCategory:setBackgroundColor(lastSelectedCategory.color)
		lastSelectedCategory:setColor("#c0c0c0")
	end

	lastSelectedCategory = selected

	selected:setBackgroundColor("#585858")
	selected:setColor("#f4f4f4")

	if table.contains(enableCategories, selected:getActionId()) then
		searchlocker:recursiveGetChildById("oneButton"):setEnabled(true)
		searchlocker:recursiveGetChildById("twoButton"):setEnabled(true)
	else
		onClearHandFilter()
	end

	if not resetFilter then
		local prev = suppressSearchCallbacks

		suppressSearchCallbacks = true

		local searchEdit = searchlocker:recursiveGetChildById("searchText")

		if searchEdit then
			searchEdit:setText("")
		end

		suppressSearchCallbacks = prev
		searchActiveCategory = nil
		sortButtons.classFilter = -1
		sortButtons.tierFilter = 0

		local classFilter = searchlocker:recursiveGetChildById("classFilter")
		local tierFilter = searchlocker:recursiveGetChildById("tierFilter")

		if table.contains(enableClassification, selected:getActionId()) then
			classFilter:clearOptions()
			classFilter:addOption("All", nil, true)
			classFilter:addOption("None", nil, true)

			for i = 1, 4 do
				classFilter:addOption("Class " .. i, nil, true)
			end

			classFilter:setEnabled(true)
			populateTierFilterOptions(-1)
			tierFilter:setEnabled(true)
		else
			classFilter:clearOptions()
			classFilter:setEnabled(false)
			tierFilter:clearOptions()
			tierFilter:setEnabled(false)
		end
	end

	clearSelectedItemPreview()

	function itemList:onChildFocusChange(focused)
		blurSearchLockerSearch()
		onSelectChildItem(self, focused)
	end

	titemList = marketItems[selected:getActionId()] or {}

	updateItemWindow(titemList)
end

local function updateWidgets(widget, scrollOffset, slotIndex, sourceList, itemListSorted)
	if not widget then
		return false
	end

	local itemId = scrollOffset + slotIndex
	local itemInfo = showLockerOnly and itemListSorted[itemId] or sourceList[itemId]

	if not itemInfo then
		widget:setVisible(false)

		return false
	end

	local tierFilter = sortButtons.tierFilter
	local displayTier, count = resolveLockerItemTierAndCount(itemInfo.thingType:getId(), tierFilter)

	if not checkSortLockerOptions(itemInfo) or count == 0 and showLockerOnly then
		widget:setVisible(false)

		return false
	end

	widget:setVisible(true)

	local itemTypeId = itemInfo.thingType:getId()
	local itemName = itemInfo.marketData.name

	if widget.item then
		widget.item:setActionId(slotIndex)
		widget.item:setItemId(itemTypeId)
		widget.item:getItem():setCount(count)
		widget.item:getItem():setTier(displayTier)
		widget.item:setTooltip(tr("%s%s%s%s", comma_value(count), "x", count > 65000 and "+ " or " ", itemName))
	end

	widget:setBackgroundColor("#404040")
	applyItemRowVisual(widget, itemTypeId, displayTier, count, itemName)
end

function onItemScrollValueChange(scrollbar, value, delta, sourceList, itemListSorted)
	if lastSelectedItem then
		lastSelectedItem:setBackgroundColor("#404040")

		lastSelectedItem = nil
	end

	local scrollOffset = math.floor((value or 0) / listConfig.labelSize)

	for i, widget in ipairs(listConfig.labels) do
		updateWidgets(widget, scrollOffset, i, sourceList, itemListSorted)
	end
end

function updateItemWindow(sourceList, searchTerm)
	listConfig.labels = {}

	local itemList = searchlocker:recursiveGetChildById("itemListAll")

	itemList:destroyChildren()

	local displayList = {}

	for k = 1, #sourceList do
		local itemInfo = sourceList[k]

		if canShowItem(itemInfo, searchTerm) then
			table.insert(displayList, itemInfo)
		end
	end

	listConfig.displayList = displayList
	listConfig.itemListSorted = displayList
	listConfig.maxFitItems = getScrollSlots(itemList)
	listConfig.visibleSlots = LIST_MAX_VISIBLE_SLOTS

	for _ = 1, LIST_MAX_VISIBLE_SLOTS do
		createListRowWidget(itemList)
	end

	listConfig.max = #displayList

	local scrollbar = searchlocker:recursiveGetChildById("itemListScroll")

	scrollbar:setValue(0)
	scrollbar:setMinimum(listConfig.min)

	if showLockerOnly then
		local itemListSorted = {}

		for k = 1, #displayList do
			local itemInfo = displayList[k]
			local _, count = resolveLockerItemTierAndCount(itemInfo.thingType:getId(), sortButtons.tierFilter)

			if count > 0 then
				table.insert(itemListSorted, itemInfo)
			end
		end

		listConfig.itemListSorted = itemListSorted
		listConfig.max = #itemListSorted
	end

	local itemScrollMax = math.max(0, listConfig.max - listConfig.maxFitItems)

	setupItemListScrollbar(itemScrollMax)
	onItemScrollValueChange(searchlocker:recursiveGetChildById("itemListScroll"), 0, 0, listConfig.displayList, listConfig.itemListSorted)
end

function refreshItemVisuals()
	if not searchlocker or not searchlocker:isVisible() then
		return
	end

	local scrollbar = searchlocker:recursiveGetChildById("itemListScroll")

	if scrollbar and #listConfig.labels > 0 then
		onItemScrollValueChange(scrollbar, scrollbar:getValue() or 0, 0, listConfig.displayList, listConfig.itemListSorted)
	end

	if lastSelectedItem and lastSelectedItem.item then
		local itemID = lastSelectedItem.item:getItemId()

		if itemID and itemID > 0 then
			updateSelectedItemPreview(itemID, lastSelectedItem.item:getItem():getTier())
		end
	end
end

function onSelectChildItem(widget, selected)
	if not selected then
		return
	end

	if lastSelectedItem then
		lastSelectedItem:setBackgroundColor("#404040")
	end

	lastSelectedItem = selected

	selected:setBackgroundColor("#585858")

	local itemID = selected.item:getItemId()
	local itemTier = selected.item:getItem():getTier()
	local selectedItemWidget = searchlocker:recursiveGetChildById("selectedItem")

	selectedItemWidget:setItemId(itemID)
	selectedItemWidget:getItem():setTier(itemTier)

	if itemID == 22118 then
		selectedItemWidget:getItem():setCount(g_game.getTransferableTibiaCoins())
	else
		local _, count = resolveLockerItemTierAndCount(itemID, itemTier)

		selectedItemWidget:getItem():setCount(count)
	end

	updateSelectedItemPreview(itemID, itemTier)

	local searchItemButton = searchlocker:recursiveGetChildById("searchItemButton")

	searchItemButton:setEnabled(true)

	function searchItemButton.onClick()
		g_game.requestLockerItem(itemID, itemTier)
	end
end

function checkSortLockerOptions(itemData)
	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local playerLevel = player:getLevel()

	if sortButtons.levelButton and playerLevel < itemData.marketData.requiredLevel then
		return false
	end

	if sortButtons.vocButton then
		local itemVocation = itemData.marketData.restrictVocation

		if itemVocation and tonumber(itemVocation) > 0 then
			local playerVoc = player:getVocation()
			local demotedVoc = playerVoc > 10 and playerVoc - 10 or playerVoc
			local vocBitMask = Bit.bit(tonumber(demotedVoc))

			if not Bit.hasBit(itemVocation, vocBitMask) then
				return false
			end
		end
	end

	if sortButtons.oneButton and itemData.thingType:getClothSlot() ~= 6 then
		return false
	end

	if sortButtons.twoButton and itemData.thingType:getClothSlot() ~= 0 then
		return false
	end

	local traderNpc = getSelectedTraderNpcName()

	if traderNpc and modules.game_stash and modules.game_stash.itemCanBeSoldToTrader and not modules.game_stash.itemCanBeSoldToTrader(itemData.thingType, traderNpc) then
		return false
	end

	return true
end

local function getStashCount(stashItems)
	if type(stashItems) ~= "table" or not stashItems[1] then
		return 0
	end

	local entry = stashItems[1]

	if type(entry) == "table" then
		return entry[2] or entry.count or 0
	end

	return 0
end

function onRecvSearchItem(itemId, tier, depotItemCount, depotItems, inboxItemCount, inboxItems, stashItems)
	currentSearchTier = tier or 0
	lastDetailItemId = itemId
	lastDetailItemTier = tier or 0

	searchPage:setVisible(false)
	itemSearchPage:setVisible(true)
	setItemSearchBackButtonVisible(true)

	local itemName = itemSearchPage:recursiveGetChildById("itemsNameLabel")

	itemName:setText(getItemName(itemId):lower())

	local depotAmount = itemSearchPage:recursiveGetChildById("depotAmount")

	depotAmount:setText(comma_value(depotItemCount))

	local depotButton = itemSearchPage:recursiveGetChildById("depotButton")

	depotButton:setEnabled(depotItemCount > 0)

	function depotButton.onClick()
		setupSearchItemList(depotButton, depotItems, itemId, depotItemCount)
	end

	local stashCount = getStashCount(stashItems)
	local stashAmount = itemSearchPage:recursiveGetChildById("stashAmount")

	stashAmount:setText(comma_value(stashCount))

	local stashButton = itemSearchPage:recursiveGetChildById("stashButton")

	stashButton:setEnabled(stashCount > 0)

	function stashButton.onClick()
		setupSearchItemList(stashButton, stashItems, itemId, stashCount)
	end

	local mailBoxAmount = itemSearchPage:recursiveGetChildById("mailBoxAmount")

	mailBoxAmount:setText(comma_value(inboxItemCount))

	local mailBoxButton = itemSearchPage:recursiveGetChildById("mailBoxButton")

	mailBoxButton:setEnabled(inboxItemCount > 0)

	function mailBoxButton.onClick()
		setupSearchItemList(mailBoxButton, inboxItems, itemId, inboxItemCount)
	end

	if depotItemCount > 0 then
		setupSearchItemList(depotButton, depotItems, itemId, depotItemCount)
	elseif stashCount > 0 then
		setupSearchItemList(stashButton, stashItems, itemId, stashCount)
	elseif inboxItemCount > 0 then
		setupSearchItemList(mailBoxButton, inboxItems, itemId, inboxItemCount)
	else
		setupSearchItemList(depotButton, {}, itemId, 0)
		depotButton:setOn(true)
		depotButton:setImageClip("156 0 52 36")
	end
end

function setupSearchItemList(button, list, itemId, retrieveCount)
	local slotCount = 32

	itemSearchPage:recursiveGetChildById("mailBoxButton"):setOn(false)
	itemSearchPage:recursiveGetChildById("stashButton"):setOn(false)
	itemSearchPage:recursiveGetChildById("depotButton"):setOn(false)

	local posy = 32

	if button and (button:getId() == "depotButton" or button:getId() == "mailBoxButton") then
		slotCount = 32

		button:setOn(true)

		if button:getId() == "mailBoxButton" then
			posy = 33
		end
	elseif button and button:getId() == "stashButton" then
		slotCount = 1

		button:setOn(true)
	end

	local itemList = itemSearchPage:recursiveGetChildById("itemsList")

	itemList:destroyChildren()

	local itemCount = 1

	for i = 1, slotCount do
		local widget = g_ui.createWidget("SearchLockerRetrieveSlot", itemList)
		local item = list[i]

		if button and button:getId() ~= "stashButton" then
			if item then
				widget.item.position = {
					x = 65535,
					y = posy,
					z = i - 1
				}

				item:setPosition(widget.item.position)
				applyRetrieveSlotVisuals(widget, item)
			else
				applyRetrieveSlotVisuals(widget, nil)
			end
		elseif button and button:getId() == "stashButton" then
			widget.item:setVirtual(true)
			widget.item:setShowCount(true)

			local stashItemId = itemId
			local stashItemCount = retrieveCount or 0

			if item then
				stashItemId = item[1] or item.itemId or itemId
				stashItemCount = item[2] or item.count or stashItemCount
			end

			applyRetrieveSlotVisuals(widget, nil, stashItemId, currentSearchTier or 0)
			widget.item:setItemCount(stashItemCount)

			itemCount = stashItemCount
		else
			applyRetrieveSlotVisuals(widget, nil)
		end
	end

	local buttonRetrieve = itemSearchPage:recursiveGetChildById("retrieveButton")
	local stashRetrieveButton = itemSearchPage:recursiveGetChildById("stashRetrieveButton")
	local isStash = button and button:getId() == "stashButton"
	local retrieveAmount = retrieveCount or 0

	if isStash then
		retrieveAmount = itemCount
	elseif button then
		local displayedCount = getDisplayedItemsCount(list)

		if displayedCount > 0 then
			retrieveAmount = displayedCount
		end
	end

	if buttonRetrieve then
		buttonRetrieve:setVisible(not isStash)
	end

	if stashRetrieveButton then
		stashRetrieveButton:setVisible(isStash)
	end

	if button then
		if isStash then
			if stashRetrieveButton then
				stashRetrieveButton:setEnabled(retrieveAmount > 0)

				function stashRetrieveButton.onClick()
					openRetrieveAmountSelector(itemId, retrieveAmount, function(count)
						g_game.stashWithdraw(itemId, count, 1)
					end)
				end
			end

			if buttonRetrieve then
				buttonRetrieve:setEnabled(false)

				buttonRetrieve.onClick = nil
			end
		else
			if buttonRetrieve then
				buttonRetrieve:setEnabled(retrieveAmount > 0)

				function buttonRetrieve.onClick()
					g_game.retrieveDisplayed(itemId, posy == 32 and 1 or 2, currentSearchTier)
				end
			end

			if stashRetrieveButton then
				stashRetrieveButton:setEnabled(false)

				stashRetrieveButton.onClick = nil
			end
		end
	else
		if buttonRetrieve then
			buttonRetrieve:setEnabled(false)

			buttonRetrieve.onClick = nil
		end

		if stashRetrieveButton then
			stashRetrieveButton:setEnabled(false)

			stashRetrieveButton.onClick = nil
		end
	end
end

function onSearchTextClick()
	focusSearchLockerSearch(true)
end

local function isWidgetInSearchLockerSearch(widget)
	if not widget or not searchlocker then
		return false
	end

	local searchText = searchlocker:recursiveGetChildById("searchText")
	local clearButton = searchlocker:recursiveGetChildById("clearSearchButton")
	local current = widget

	while current do
		if current == searchText or current == clearButton then
			return true
		end

		if current == searchlocker then
			return false
		end

		current = current:getParent()
	end

	return false
end

local function unregisterSearchLockerOutsideClick()
	if not searchLockerOutsideHandler then
		return
	end

	local root = g_ui.getRootWidget()

	if root and not root:isDestroyed() then
		disconnect(root, searchLockerOutsideHandler)
	end

	searchLockerOutsideHandler = nil
end

local function setSearchLockerVisual(active)
	if not searchlocker then
		return
	end

	if active then
		searchlocker:setBorderWidth(2)
		searchlocker:setBorderColor("white")
	else
		searchlocker:setBorderWidth(0)
	end
end

local function resetSearchLockerSearchState()
	searchLockerSearchActive = false

	unregisterSearchLockerOutsideClick()
	setSearchLockerVisual(false)

	if not searchlocker then
		return
	end

	pcall(function()
		searchlocker:ungrabKeyboard()
	end)

	local search = searchlocker:recursiveGetChildById("searchText")

	if search then
		search:setCursorVisible(false)
	end
end

function blurSearchLockerSearch()
	if not searchLockerSearchActive then
		return
	end

	resetSearchLockerSearchState()
end

local function registerSearchLockerOutsideClick()
	unregisterSearchLockerOutsideClick()

	local root = g_ui.getRootWidget()

	if not root or root:isDestroyed() then
		return
	end

	searchLockerOutsideHandler = {
		onMousePress = function(rootWidget, mousePos, mouseButton)
			if not searchLockerSearchActive or mouseButton ~= MouseLeftButton then
				return false
			end

			local clicked = rootWidget:recursiveGetChildByPos(mousePos, false)

			if not isWidgetInSearchLockerSearch(clicked) then
				blurSearchLockerSearch()
			end

			return false
		end
	}

	connect(root, searchLockerOutsideHandler)
end

local function applySearchLockerSearchFocus(moveCursorToEnd)
	if not searchLockerSearchActive or not searchlocker then
		return
	end

	local search = searchlocker:recursiveGetChildById("searchText")

	if not search then
		return
	end

	searchlocker:raise()
	pcall(function()
		searchlocker:grabKeyboard()
	end)

	local chain = {}
	local node = search

	while node and node ~= searchlocker do
		table.insert(chain, 1, node)

		node = node:getParent()
	end

	if #chain > 0 and searchlocker.focusChild then
		pcall(function()
			searchlocker:focusChild(chain[1], KeyboardFocusReason)
		end)
	end

	for i = 1, #chain - 1 do
		local parent = chain[i]
		local child = chain[i + 1]

		if parent.focusChild then
			pcall(function()
				parent:focusChild(child, KeyboardFocusReason)
			end)
		end
	end

	search:focus()
	search:setCursorVisible(true)
	search:blinkCursor()

	if moveCursorToEnd then
		search:setCursorPos(-1)
	end
end

function focusSearchLockerSearch(moveCursorToEnd)
	if not searchlocker then
		return
	end

	searchLockerSearchActive = true

	setSearchLockerVisual(true)
	registerSearchLockerOutsideClick()
	applySearchLockerSearchFocus(moveCursorToEnd)
	scheduleEvent(function()
		applySearchLockerSearchFocus(moveCursorToEnd)
	end, 50)
end

function setupSearchField()
	if not searchlocker then
		return
	end

	local search = searchlocker:recursiveGetChildById("searchText")
	local clearButton = searchlocker:recursiveGetChildById("clearSearchButton")

	if search then
		function search:onMousePress(mousePos, button)
			if button == MouseLeftButton then
				focusSearchLockerSearch(false)
			end

			return false
		end

		search:setCursorVisible(false)
	end

	if clearButton then
		clearButton:raise()
	end
end

function clearSearch(refresh)
	if not searchlocker then
		return
	end

	local text = searchlocker:recursiveGetChildById("searchText")

	if not text then
		return
	end

	local prev = suppressSearchCallbacks

	suppressSearchCallbacks = true

	text:setText("")

	suppressSearchCallbacks = prev

	if searchLockerSearchActive then
		applySearchLockerSearchFocus(true)
	end

	if refresh then
		onTextChange()
	end
end

function onTextChange()
	if suppressSearchCallbacks or not searchlocker then
		return
	end

	local searchText = getActiveSearchText()

	if searchText == "" then
		resetSearchLockerBrowseState()

		return
	end

	lastSelectedItem = nil

	clearSelectedItemPreview()

	if lastSelectedCategory then
		searchActiveCategory = lastSelectedCategory

		lastSelectedCategory:setBackgroundColor(lastSelectedCategory.color)
		lastSelectedCategory:setColor("#c0c0c0")

		lastSelectedCategory = nil
	end

	updateItemWindow(marketItems[MarketCategory.All] or {}, searchText)
end
