-- chunkname: @/game_imbuementtracker/imbuementtracker.lua

local IMBUEMENTTRACKER_SLOTS = {
	INVENTORYSLOT_FEET = 8,
	INVENTORYSLOT_LEFT = 6,
	INVENTORYSLOT_RIGHT = 5,
	INVENTORYSLOT_ARMOR = 4,
	INVENTORYSLOT_BACKPACK = 3,
	INVENTORYSLOT_HEAD = 1
}
local IMBUEMENTTRACKER_FILTERS = {
	showLessThan1h = true,
	showNoImbuements = true,
	showMoreThan3h = true,
	showBetween1hAnd3h = true
}

imbuementTrackerButton = nil
imbuementTrackerMenuButton = nil

function loadFilters()
	local settings = g_settings.getNode("ImbuementTracker")

	if not settings or not settings.filters then
		return IMBUEMENTTRACKER_FILTERS
	end

	return settings.filters
end

function saveFilters()
	g_settings.mergeNode("ImbuementTracker", {
		filters = loadFilters()
	})
end

function applyFilters(filters)
	if type(filters) ~= "table" then
		return
	end

	g_settings.mergeNode("ImbuementTracker", {
		filters = filters
	})

	local player = g_game.getLocalPlayer()

	if player and player.getInventoryItems and onUpdateImbuementTracker then
		onUpdateImbuementTracker(player:getInventoryItems())
	end
end

function getFilter(filter)
	return loadFilters()[filter] or false
end

function setFilter(filter)
	local filters = loadFilters()
	local value = filters[filter]

	if value == nil then
		return false
	end

	filters[filter] = not value

	g_settings.mergeNode("ImbuementTracker", {
		filters = filters
	})
	g_game.imbuementDurations(imbuementTrackerButton:isOn())
end

function initialize()
	g_ui.importStyle("imbuementtracker")
	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd,
		onUpdateImbuementTracker = onUpdateImbuementTracker
	})

	imbuementTracker = g_ui.createWidget("ImbuementTracker", modules.game_interface.getRightPanel())

	imbuementTracker:setContentMinimumHeight(80)

	local toggleFilterButton = imbuementTracker:recursiveGetChildById("toggleFilterButton")

	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
		toggleFilterButton:setOn(false)
	end

	local newWindowButton = imbuementTracker:recursiveGetChildById("newWindowButton")

	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	local contextMenuButton = imbuementTracker:recursiveGetChildById("contextMenuButton")
	local lockButton = imbuementTracker:recursiveGetChildById("lockButton")
	local minimizeButton = imbuementTracker:recursiveGetChildById("minimizeButton")

	if contextMenuButton then
		contextMenuButton:setVisible(true)

		if minimizeButton then
			contextMenuButton:breakAnchors()
			contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
			contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
			contextMenuButton:setMarginRight(5)
			contextMenuButton:setMarginTop(0)
		end

		if lockButton then
			lockButton:breakAnchors()
			lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
			lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
			lockButton:setMarginRight(2)
			lockButton:setMarginTop(0)
		end

		function contextMenuButton.onClick(widget, mousePos, mouseButton)
			local menu = g_ui.createWidget("ImbuementTrackerMenu")

			menu:setGameMenu(true)

			for _, choice in ipairs(menu:getChildren()) do
				local choiceId = choice:getId()

				choice:setChecked(getFilter(choiceId))

				function choice.onCheckChange()
					setFilter(choiceId)
					menu:destroy()
				end
			end

			menu:display(mousePos)

			return true
		end
	end

	imbuementTracker:setup()
	imbuementTracker:hide()
end

local function syncImbuementTrackerMainPanelButton()
	if not imbuementTrackerButton or imbuementTrackerButton:isDestroyed() then
		return
	end

	local on = false

	if imbuementTracker and not imbuementTracker:isDestroyed() then
		on = imbuementTracker:isVisible()
	end

	imbuementTrackerButton:setOn(on)

	if imbuementTrackerButton.setTooltip then
		imbuementTrackerButton:setTooltip(tr(on and "Close Imbuement Tracker Window" or "Open Imbuement Tracker Window"))
	end
end

function onMiniWindowOpen()
	syncImbuementTrackerMainPanelButton()
end

function onMiniWindowClose()
	syncImbuementTrackerMainPanelButton()
end

function terminate()
	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd,
		onUpdateImbuementTracker = onUpdateImbuementTracker
	})

	if imbuementTrackerButton then
		imbuementTrackerButton:destroy()

		imbuementTrackerButton = nil
	end

	imbuementTracker:destroy()
end

function toggle()
	if imbuementTrackerButton:isOn() then
		imbuementTracker:closeAndForgetLayout()
	else
		if not imbuementTracker:getParent() then
			local panel = modules.game_interface.findContentPanelAvailable(imbuementTracker, imbuementTracker:getMinimumHeight())

			if not panel then
				return
			end

			panel:addChild(imbuementTracker)
		end

		imbuementTracker:open()
	end

	syncImbuementTrackerMainPanelButton()
	g_game.imbuementDurations(imbuementTrackerButton:isOn())
end

local function getTrackedItems(items)
	local trackedItems = {}

	for _, item in ipairs(items) do
		if table.contains(IMBUEMENTTRACKER_SLOTS, item.slot) then
			trackedItems[#trackedItems + 1] = item
		end
	end

	return trackedItems
end

local function formatTooltipDuration(duration)
	local hours = math.floor(duration / 3600)
	local minutes = math.floor(duration / 60 - hours * 60)

	return string.format("%02dh %dmin", hours, minutes)
end

local function onSlotHoverChange(widget, hovered)
	g_tooltip.onWidgetHoverChange(widget, hovered)
end

local function resolveTrackedItem(itemWidget)
	local item = itemWidget:getItem()

	if not item then
		return nil
	end

	local inventorySlot = itemWidget.trackedInventorySlot

	if inventorySlot then
		local player = g_game.getLocalPlayer()

		if player then
			local invItem = player:getInventoryItem(inventorySlot)

			if invItem then
				return invItem
			end
		end
	end

	return item
end

local function showTrackedItemContextMenu(itemWidget, mousePos)
	local trackedItem = resolveTrackedItem(itemWidget)

	if not trackedItem then
		return
	end

	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setGameMenu(true)
	menu:addOption(tr("Look"), function()
		local lookItem = resolveTrackedItem(itemWidget)

		if lookItem then
			g_game.look(lookItem)
		end
	end)
	menu:addOption(tr("Inspect"), function()
		local inspectItem = resolveTrackedItem(itemWidget)

		if not inspectItem then
			return
		end

		local pos = inspectItem:getPosition()
		local count = inspectItem:getCount()

		if not count or count < 1 then
			count = 1
		end

		g_game.inspectionNormalObject(pos)
	end)

	local modCyc = modules.game_cyclopedia
	local cycApi = modCyc and modCyc.Cyclopedia

	if trackedItem:isCyclopediaItem() and cycApi and cycApi.openItemInCyclopedia then
		menu:addOption(tr("Cyclopedia"), function()
			local cycItem = resolveTrackedItem(itemWidget)

			if not cycItem then
				return
			end

			if modCyc.show then
				modCyc.show("items")
			end

			cycApi.openItemInCyclopedia(cycItem:getId())
		end)
	end

	if not trackedItem:isCreature() and not trackedItem:isNotMoveable() and trackedItem:isPickupable() and trackedItem.getProficiencyId and trackedItem:getProficiencyId() > 0 then
		local proficiencyMod = modules.game_proficiency

		if proficiencyMod and proficiencyMod.requestOpenWindow then
			menu:addOption(tr("Weapon Proficiency"), function()
				local item = resolveTrackedItem(itemWidget)

				if item then
					proficiencyMod.requestOpenWindow(item)
				end
			end)
		end
	end

	if trackedItem.isContainer and trackedItem:isContainer() and g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot then
		local quickLoot = modules.game_quickloot.QuickLoot

		if quickLoot then
			menu:addOption(tr("Manage Containers"), function()
				quickLoot.toggle()
			end)
		end
	end

	menu:display(mousePos)
end

local function bindTrackedItemContextMenu(itemWidget, inventorySlot)
	itemWidget.trackedInventorySlot = inventorySlot

	function itemWidget.onMousePress(widget, mousePos, mouseButton)
		if mouseButton == MouseRightButton and widget:getItem() then
			showTrackedItemContextMenu(widget, mousePos)

			return true
		end

		return false
	end
end

local function applySlotTooltip(widget, tooltip)
	widget:setTooltip(tooltip)

	widget.onHoverChange = onSlotHoverChange

	for _, child in ipairs(widget:getChildren()) do
		child:setTooltip(tooltip)

		child.onHoverChange = onSlotHoverChange
	end
end

local function setImbuementSlotTooltip(slot, imbuementSlot)
	local name = imbuementSlot.name or ""
	local durationText = formatTooltipDuration(imbuementSlot.duration or 0)

	applySlotTooltip(slot, string.format("%s\n\n%s: %s", name, tr("Time remaining"), durationText))
end

local function setDuration(label, duration)
	if duration == 0 then
		label:setVisible(false)

		return
	end

	local hours = math.floor(duration / 3600)
	local minutes = math.floor(duration / 60 - hours * 60)

	if duration < 60 then
		label:setColor("#d33c3c")
		label:setText(string.format("%2.fs", duration))
	elseif duration < 3600 then
		label:setColor("#d33c3c")
		label:setText(string.format("%2.fm", minutes))
	elseif duration < 10800 then
		label:setColor("#f8db38")
		label:setText(string.format("%dh%02d", hours, minutes))
		label:setFont("Verdana Bold-11px-outline-compact")
	else
		label:setColor("#bfbfbf")
		label:setText(string.format("%02.fh", hours))
		label:setFont("Verdana Bold-11px-outline-compact")
	end

	label:setVisible(true)
end

local function computeMaxDuration(item)
	local maxDuration = 0

	for _, imbuementSlot in pairs(item.slots or {}) do
		local duration = imbuementSlot.duration or 0

		if maxDuration < duration then
			maxDuration = duration
		end
	end

	return maxDuration
end

local function shouldShowTrackedItem(item, duration)
	local hasActiveImbuements = next(item.slots or {}) ~= nil and duration > 0
	local hasSlots = (item.totalSlots or 0) > 0

	if not hasActiveImbuements and hasSlots and not getFilter("showNoImbuements") then
		return false
	elseif not hasActiveImbuements and not hasSlots then
		return false
	elseif duration > 0 and duration < 3600 and not getFilter("showLessThan1h") then
		return false
	elseif duration >= 3600 and duration < 10800 and not getFilter("showBetween1hAnd3h") then
		return false
	elseif duration >= 10800 and not getFilter("showMoreThan3h") then
		return false
	end

	return true
end

local function slotSignature(item)
	local activeSlots = {}

	for _, imbuementSlot in pairs(item.slots or {}) do
		activeSlots[imbuementSlot.id] = imbuementSlot
	end

	local totalSlots = item.totalSlots or 0
	local parts = {}

	for slotIndex = 0, totalSlots - 1 do
		local s = activeSlots[slotIndex]

		parts[#parts + 1] = s and "a" .. (s.iconId or 0) or "x"
	end

	return table.concat(parts, ","), activeSlots, totalSlots
end

local function buildSlots(trackedItem, activeSlots, totalSlots)
	trackedItem.imbuementSlots:destroyChildren()

	for slotIndex = 0, totalSlots - 1 do
		local imbuementSlot = activeSlots[slotIndex]

		if imbuementSlot then
			local slot = g_ui.createWidget("ImbuementSlot", trackedItem.imbuementSlots)

			slot:setId("slot" .. imbuementSlot.id)

			local iconId = imbuementSlot.iconId or 0
			local icon = slot:getChildById("icon")

			icon:setImageClip(string.format("%d 0 64 64", iconId * 64))
			slot:setMarginLeft(3)
			setDuration(slot.duration, imbuementSlot.duration)
			setImbuementSlotTooltip(slot, imbuementSlot)
		else
			local inactiveSlot = g_ui.createWidget("ImbuementSlotInactive", trackedItem.imbuementSlots)

			inactiveSlot:setId("inactiveSlot" .. slotIndex)
			inactiveSlot:setMarginLeft(3)
			applySlotTooltip(inactiveSlot, tr("Empty slot"))
		end
	end
end

local function refreshSlotDurations(trackedItem, activeSlots, totalSlots)
	local children = trackedItem.imbuementSlots:getChildren()

	for slotIndex = 0, totalSlots - 1 do
		local imbuementSlot = activeSlots[slotIndex]
		local slot = children[slotIndex + 1]

		if imbuementSlot and slot then
			setDuration(slot.duration, imbuementSlot.duration)
			setImbuementSlotTooltip(slot, imbuementSlot)
		end
	end
end

local function addTrackedItem(item, parent, activeSlots, totalSlots)
	local trackedItem = g_ui.createWidget("InventoryItem", parent)

	trackedItem.item:setItem(item.item)
	ItemsDatabase.setTier(trackedItem.item, trackedItem.item:getItem())
	trackedItem.item:setVirtual(true)
	bindTrackedItemContextMenu(trackedItem.item, item.slot)
	buildSlots(trackedItem, activeSlots, totalSlots)

	return trackedItem
end

function onUpdateImbuementTracker(items)
	local contentsPanel = imbuementTracker.contentsPanel
	local existingBySlot = {}

	for _, child in ipairs(contentsPanel:getChildren()) do
		if child.trackedSlot then
			existingBySlot[child.trackedSlot] = child
		end
	end

	local order = {}

	for _, item in ipairs(getTrackedItems(items)) do
		local maxDuration = computeMaxDuration(item)

		if shouldShowTrackedItem(item, maxDuration) then
			local invSlot = item.slot
			local sig, activeSlots, totalSlots = slotSignature(item)
			local trackedItem = existingBySlot[invSlot]

			if trackedItem and not trackedItem:isDestroyed() then
				existingBySlot[invSlot] = nil

				trackedItem.item:setItem(item.item)
				ItemsDatabase.setTier(trackedItem.item, trackedItem.item:getItem())
				trackedItem.item:setVirtual(true)

				if trackedItem.slotSig == sig then
					refreshSlotDurations(trackedItem, activeSlots, totalSlots)
				else
					buildSlots(trackedItem, activeSlots, totalSlots)

					trackedItem.slotSig = sig
				end
			else
				trackedItem = addTrackedItem(item, contentsPanel, activeSlots, totalSlots)
				trackedItem.trackedSlot = invSlot
				trackedItem.slotSig = sig
			end

			order[#order + 1] = trackedItem
		end
	end

	for _, child in pairs(existingBySlot) do
		if not child:isDestroyed() then
			child:destroy()
		end
	end

	for i = 1, #order do
		contentsPanel:moveChildToIndex(order[i], i)
	end
end

function onGameStart()
	if g_game.getClientVersion() >= 1100 then
		imbuementTrackerButton = modules.game_mainpanel.addToggleButton("imbuementTrackerButton", tr("Open Imbuement Tracker Window"), "/images/options/button_imbuement_tracker", toggle)

		imbuementTracker:setupOnStart()
		syncImbuementTrackerMainPanelButton()
		addEvent(function()
			if imbuementTrackerButton and not imbuementTrackerButton:isDestroyed() then
				g_game.imbuementDurations(imbuementTrackerButton:isOn())
			end
		end)
		loadFilters()
	end
end

function onGameEnd()
	imbuementTracker.contentsPanel:destroyChildren()
	saveFilters()
end
