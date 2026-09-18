-- chunkname: @/mods/game_imbuing/classes/imbuementitem.lua

if not ImbuementItem then
	ImbuementItem = {
		slots = 0,
		tier = 0,
		itemId = 0,
		selectedSlot = 0,
		activeSlots = {},
		availableImbuements = {},
		needItems = {}
	}
end

ImbuementItem.__index = ImbuementItem

local self = ImbuementItem

local function setImbuementStripIcon(resource, imageId)
	resource:setImageSource("/images/game/imbuing/imbuement-icons")
	resource:setImageClip(string.format("%d 0 64 64", (imageId or 0) * 64))
end

local function applyEquipmentSlotFrame(widget, selected)
	if not widget then
		return
	end

	widget:setBorderWidth(0)

	local overlay = widget:recursiveGetChildById("slotSelection")

	if not overlay then
		return
	end

	overlay:setVisible(true)

	if selected then
		overlay:setImageSource("/images/game/imbuing/slot-selected")
	else
		overlay:setImageSource("/images/game/imbuing/slot-unselected")
	end

	local choiceBorder = widget:recursiveGetChildById("imbueChoiceBorder")

	if choiceBorder then
		choiceBorder:setVisible(false)
	end
end

function ImbuementItem.setSlotImbuingSelected(widget, selected)
	applyEquipmentSlotFrame(widget, selected)
end

function ImbuementItem.setImbuementChoiceSelected(widget, selected)
	if not widget then
		return
	end

	widget:setBorderWidth(0)

	local overlay = widget:recursiveGetChildById("slotSelection")

	if overlay then
		overlay:setVisible(true)
		overlay:setImageSource("/images/game/imbuing/slot-unselected")
	end

	local choiceBorder = widget:recursiveGetChildById("imbueChoiceBorder")

	if choiceBorder then
		choiceBorder:setVisible(selected)

		if selected then
			choiceBorder:raise()
		end
	end
end

local imbuingSlotSetSelected = ImbuementItem.setSlotImbuingSelected

local function resolvePreviewItemName(itemId, uiItem)
	if uiItem then
		local it = uiItem:getItem()

		if it then
			local n = it:getName()

			if n and n ~= "" then
				return n
			end
		end
	end

	if modules.game_market and modules.game_market.getItemNameById then
		local n = modules.game_market.getItemNameById(itemId)

		if n and n ~= "" then
			return n
		end
	end

	local itemCategory = rawget(_G, "ThingCategoryItem")

	if itemCategory == nil then
		itemCategory = 0
	end

	local ok, thingType = pcall(function()
		return g_things.getThingType(itemId, itemCategory)
	end)

	if ok and thingType and thingType.getName then
		local n = thingType:getName()

		if n and n ~= "" then
			return n
		end
	end

	return ""
end

local function applyItemPreviewTitle(window, capitalizedName)
	if not window or window:isDestroyed() then
		return
	end

	local content = window:recursiveGetChildById("itemOrScrollContent")

	if not content then
		return
	end

	local label = content:getChildById("titleInformation")

	if not label or label:isDestroyed() then
		return
	end

	label:setText(capitalizedName)
	label:setColor("#c0c0c0")
	label:setVisible(true)
	label:raise()
	content:updateLayout()

	if Imbuement.window and not Imbuement.window:isDestroyed() then
		Imbuement.window:updateLayout()
	end
end

function ImbuementItem.setup(itemId, tier, slots, activeSlots, availableImbuements, needItems)
	self.itemId = itemId
	self.tier = tier
	self.slots = slots
	self.activeSlots = {}

	if activeSlots then
		for i = 0, slots - 1 do
			self.activeSlots["slot" .. i] = activeSlots[i] or {}
		end
	end

	self.availableImbuements = availableImbuements or {}
	self.needItems = needItems or {}

	for i = 0, 2 do
		imbuingSlotSetSelected(Imbuement.clearImbue:recursiveGetChildById("slot" .. i), false)
		imbuingSlotSetSelected(Imbuement.selectImbue:recursiveGetChildById("slot" .. i), false)
	end

	local initialSlot = 0
	local slotHint = self.restoreSlotAfterSetup

	if slotHint == nil then
		slotHint = self.pendingReselectSlot
	end

	if slotHint == nil then
		slotHint = self.reservedReturnSlot
	end

	if slotHint ~= nil and self.slots > 0 then
		initialSlot = math.max(0, math.min(slotHint, self.slots - 1))
	end

	self.restoreSlotAfterSetup = nil
	self.selectedSlot = initialSlot

	self.onSelectImbuementSlot(self.selectedSlot)
	self.updateWindowState()
	self.configureWindow(Imbuement.selectImbue)
	self.configureWindow(Imbuement.clearImbue)

	local pending = self.pendingClientInfo

	if pending then
		self.pendingClientInfo = nil
		Imbuement.awaitingFyiRestore = true

		scheduleEvent(function()
			if not g_game.isOnline() then
				return
			end

			Imbuement.hide()

			if pending == "apply" then
				displayInfoBox(tr("Info"), tr("The imbuement has been applied successfully."))
			elseif pending == "clear" then
				displayInfoBox(tr("Info"), tr("The imbuement has been removed successfully."))
			end
		end, 1)
	end
end

function ImbuementItem.configureWindow(window)
	local slots = window:recursiveGetChildById("slots")

	for i = 1, 3 do
		local slotWidget = slots:getChildById("slot" .. i - 1)

		if slotWidget then
			if i <= self.slots then
				slotWidget:setVisible(true)

				local imbuement = self.activeSlots["slot" .. i - 1]

				if imbuement and imbuement[1] and imbuement[1].id ~= 0 then
					setImbuementStripIcon(slotWidget.resource, imbuement[1].imageId)
				else
					setImbuementStripIcon(slotWidget.resource, 0)
				end
			else
				slotWidget:setVisible(false)
			end
		end
	end

	local content = window:recursiveGetChildById("itemOrScrollContent")
	local itemWidget = content and content:getChildById("imbueItemPreview")

	if itemWidget then
		itemWidget:setItemId(self.itemId)
		itemWidget:setImageSmooth(true)
		itemWidget:setTier(self.tier)
		itemWidget:setItemCount(1)
	end

	local rawName = resolvePreviewItemName(self.itemId, itemWidget)
	local displayName = rawName ~= "" and string.capitalize(rawName) or "-"
	local itemInformation = content and content:getChildById("titleInformation")

	if itemInformation then
		applyItemPreviewTitle(window, displayName)
	end
end

function ImbuementItem.onSelectSlot(widget)
	local slot = widget:getId()
	local slotIndex = widget.slot or 0

	ImbuementItem.onSelectImbuementSlot(slotIndex)

	local imbuement = self.activeSlots[slot]

	self.updateWindowState(imbuement)
end

function ImbuementItem.updateWindowState(imbuement)
	if not imbuement then
		local selectedSlotKey = "slot" .. self.selectedSlot

		imbuement = self.activeSlots[selectedSlotKey]
	end

	if imbuement and imbuement[1] and imbuement[1].id ~= 0 then
		Imbuement:toggleMenu("clearImbue")

		self.window = Imbuement.clearImbue

		self.onSelectSlotClear(imbuement)
	else
		Imbuement:toggleMenu("selectImbue")

		self.window = Imbuement.selectImbue

		self.onSelectSlotImbue()
	end
end

function ImbuementItem.onSelectImbuementSlot(slot)
	imbuingSlotSetSelected(Imbuement.clearImbue:recursiveGetChildById("slot" .. self.selectedSlot), false)
	imbuingSlotSetSelected(Imbuement.selectImbue:recursiveGetChildById("slot" .. self.selectedSlot), false)

	self.selectedSlot = slot

	imbuingSlotSetSelected(Imbuement.clearImbue:recursiveGetChildById("slot" .. slot), true)
	imbuingSlotSetSelected(Imbuement.selectImbue:recursiveGetChildById("slot" .. slot), true)
end

function ImbuementItem:shutdown()
	self.window = nil
	self.itemId = 0
	self.tier = 0
	self.slots = 0
	self.activeSlots = {}
	self.availableImbuements = {}
	self.needItems = {}

	if self.confirmWindow then
		g_modalManager.hide(self.confirmWindow)
		self.confirmWindow:destroy()
	end

	if self.lastselectedwidget then
		self.lastselectedwidget:destroy()

		self.lastselectedwidget = nil
	end

	self.confirmWindow = nil
	self.restoreSlotAfterSetup = nil
	self.pendingReselectSlot = nil
	self.pendingClientInfo = nil
	self.reservedReturnSlot = nil
end

function ImbuementItem.onSelectSlotClear(imbuement)
	local title = self.window.cleanImbuePanel:getChildById("title")

	if title then
		title:setText(string.format("Clear Imbuement \"%s\"", imbuement[1].name))
	end

	local cleanImbuementsDetails = self.window:recursiveGetChildById("cleanImbuementsDetails")

	if cleanImbuementsDetails then
		cleanImbuementsDetails:setText("")
	end

	local timeRemaining = self.window:recursiveGetChildById("timeRemaining")

	if timeRemaining then
		local time = imbuement[1].duration or 0

		timeRemaining:setMinimum(0)
		timeRemaining:setMaximum(time)
		timeRemaining:setValue(imbuement[2], 0, time)
	end

	local imbuementReqContent = self.window:recursiveGetChildById("imbuementReqContent")

	if imbuementReqContent then
		local hours = string.format("%02.f", math.floor(imbuement[2] / 3600))
		local mins = string.format("%02.f", math.floor(imbuement[2] / 60 - hours * 60))
		local timePanel = imbuementReqContent:getChildById("time")

		if timePanel then
			local textLabel = timePanel:getChildById("textLabel")

			if textLabel then
				textLabel:setText(string.format("%dh %dmin", hours, mins))
			end

			function timePanel.onHoverChange(widget, hovered, itemName, hasItem)
				if hovered then
					cleanImbuementsDetails:setText(tr("Show the time the imbuement is still active for."))
				else
					cleanImbuementsDetails:setText("")
				end
			end
		end
	end

	local clearImbuementsList = self.window:recursiveGetChildById("clearImbuementsList")

	if not clearImbuementsList then
		return
	end

	clearImbuementsList:destroyChildren()

	local widget = g_ui.createWidget("SlotImbuing", clearImbuementsList)

	setImbuementStripIcon(widget.resource, imbuement[1].imageId)
	ImbuementItem.setImbuementChoiceSelected(widget, true)

	local selectedImbuementContent = self.window:recursiveGetChildById("selectedImbuementContent")

	if selectedImbuementContent then
		selectedImbuementContent.imbuementsDetails:setText(imbuement[1].description or "")
	end

	local player = g_game.getLocalPlayer()
	local playerBank = player:getResourceBalance(ResourceBank)
	local playerInventory = player:getResourceBalance(ResourceInventary)
	local balance = playerBank + playerInventory
	local clearButton = self.window:recursiveGetChildById("clear")

	if clearButton then
		clearButton:setEnabled(balance >= imbuement[3])

		function clearButton.onClick()
			if self.confirmWindow then
				g_modalManager.hide(self.confirmWindow)
				self.confirmWindow:destroy()

				self.confirmWindow = nil
			end

			Imbuement.hide()

			local function confirm()
				Imbuement.awaitingFyiRestore = false
				self.reservedReturnSlot = self.selectedSlot
				self.pendingReselectSlot = self.selectedSlot
				self.restoreSlotAfterSetup = self.selectedSlot
				self.pendingClientInfo = "clear"

				g_game.clearImbuement(self.selectedSlot)

				if self.confirmWindow then
					g_modalManager.hide(self.confirmWindow)
					self.confirmWindow:destroy()

					self.confirmWindow = nil
				end

				Imbuement.onServerImbueAcknowledged(true, false)
			end

			local function cancelFunc()
				if self.confirmWindow then
					g_modalManager.hide(self.confirmWindow)
					self.confirmWindow:destroy()

					self.confirmWindow = nil
				end

				Imbuement.show()
			end

			self.confirmWindow = Imbuement.displayConfirmClearingBox(tr("Confirm Clearing"), tr("Do you wish to spend %s gold coins to clear the imbuement \"%s\" from your item?", comma_value(imbuement[3]), string.capitalize(imbuement[1].name)), {
				{
					text = tr("No"),
					callback = cancelFunc
				},
				{
					text = tr("Yes"),
					callback = confirm
				}
			}, confirm, cancelFunc)

			g_modalManager.show(self.confirmWindow)
		end

		if balance >= imbuement[3] then
			clearButton:setImageSource("/images/game/imbuing/button-confirm-remove")
			clearButton:setImageClip("0 0 128 66")
		else
			clearButton:setImageSource("/images/game/imbuing/button-confirm-blocked")
		end

		function clearButton.onHoverChange(widget, hovered, itemName, hasItem)
			if hovered then
				cleanImbuementsDetails:setText(tr("Your needs have changed? Click here to clear the imbuement from your item for a fee."))
			else
				cleanImbuementsDetails:setText("")
			end
		end
	end

	local costPanel = self.window:recursiveGetChildById("costPanel")

	if costPanel then
		costPanel.cost:setText(comma_value(imbuement[3]))
		costPanel.cost:setColor(balance < imbuement[3] and "#d33c3c" or "#c0c0c0")
	end
end

function ImbuementItem.onSelectSlotImbue()
	self.selectBaseType("basicButton")
	self.window:recursiveGetChildById("imbuementsDetails"):setVisible(false)
end

function ImbuementItem.selectBaseType(selectedButtonId)
	self.window:recursiveGetChildById("blockedPanels"):setVisible(true)

	local qualityAndImbuementContent = self.window:recursiveGetChildById("qualityAndImbuementContent")

	if not qualityAndImbuementContent then
		return
	end

	local basicButton = qualityAndImbuementContent.basicButton
	local intricateButton = qualityAndImbuementContent.intricateButton
	local powerfullButton = qualityAndImbuementContent.powerfullButton
	local baseImbuement = 0

	for _, button in pairs({
		basicButton,
		intricateButton,
		powerfullButton
	}) do
		button:setOn(button:getId() == selectedButtonId)

		if button:getId() == selectedButtonId then
			baseImbuement = button.baseImbuement or 0
		end
	end

	local imbuementsList = self.window:recursiveGetChildById("imbuementsList")

	imbuementsList:setWidth(70)
	imbuementsList:destroyChildren()

	local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")

	imbuementsDetails:setVisible(false)

	local maxWidth = 0

	for id, imbuement in pairs(self.availableImbuements) do
		if imbuement.type == baseImbuement then
			local widget = g_ui.createWidget("SlotImbuing", imbuementsList)

			widget:setId(tostring(id))
			setImbuementStripIcon(widget.resource, imbuement.imageId)

			function widget.onClick()
				ImbuementItem.selectImbuementWidget(widget, imbuement)
			end

			maxWidth = math.min(imbuementsList.maxWidth, maxWidth + imbuementsList.incrementwidth)
		end
	end

	imbuementsList:setWidth(maxWidth)
end

function ImbuementItem.onSelectImbuement(widget)
	local imbuementId = tonumber(widget:getId())
	local imbuement = self.availableImbuements[imbuementId]

	if not imbuement then
		return
	end

	self.window:recursiveGetChildById("blockedPanels"):setVisible(false)

	local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")

	if imbuementReqPanel then
		imbuementReqPanel.title:setText(string.format("Imbue Empty Slot with \"%s\"", imbuement.name))
	end

	local itensDetails = self.window:recursiveGetChildById("itensDetails")

	if itensDetails then
		itensDetails:setText("")
	end
end

function ImbuementItem.selectImbuementWidget(widget, imbuement)
	if self.lastselectedwidget then
		ImbuementItem.setImbuementChoiceSelected(self.lastselectedwidget, false)
	end

	self.lastselectedwidget = widget

	ImbuementItem.setImbuementChoiceSelected(widget, true)
	self.onSelectImbuement(widget)

	local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")

	if imbuementsDetails then
		imbuementsDetails:setVisible(true)
		imbuementsDetails:setText(imbuement.description or "")
	end

	local requiredItems = self.window:recursiveGetChildById("requiredItems")
	local hasRequiredItems = true

	if requiredItems then
		for i = 1, 3 do
			local itemWidget = requiredItems:getChildById("item" .. i)

			if itemWidget then
				local source = imbuement.sources[i]

				if source then
					itemWidget.item:setItemId(source.item:getId())
					itemWidget:setVisible(true)
					itemWidget.count:setText(self.needItems[source.item:getId()] .. "/" .. source.item:getCount())

					if self.needItems[source.item:getId()] >= source.item:getCount() then
						itemWidget.count:setColor("#c0c0c0")
					else
						hasRequiredItems = false

						itemWidget.count:setColor("#d33c3c")
					end

					function itemWidget.onHoverChange(widget, hovered)
						local itensDetails = self.window:recursiveGetChildById("itensDetails")

						if hovered then
							if self.needItems[source.item:getId()] >= source.item:getCount() then
								itensDetails:setText(string.format("The imbuement you have selected requires %s.", source.description))
							else
								itensDetails:setText(string.format("The imbuement requires %s. Unfortunately you do not own the needed amount.", source.description))
							end
						elseif itensDetails then
							itensDetails:setText("")
						end
					end
				else
					itemWidget:setVisible(false)
				end
			end
		end
	end

	local costPanel = self.window:recursiveGetChildById("costPanel")

	if costPanel then
		local cost = imbuement.cost or 0

		costPanel.cost:setText(comma_value(cost))

		local player = g_game.getLocalPlayer()
		local playerBank = player:getResourceBalance(ResourceBank)
		local playerInventory = player:getResourceBalance(ResourceInventary)
		local balance = playerBank + playerInventory

		if balance < cost then
			hasRequiredItems = false
		end

		costPanel.cost:setColor(balance < cost and "#d33c3c" or "#c0c0c0")
	end

	local imbueApply = self.window:recursiveGetChildById("imbueApply")

	if imbueApply then
		imbueApply:setEnabled(hasRequiredItems)

		if not hasRequiredItems then
			imbueApply:setImageSource("/images/game/imbuing/button-confirm-blocked")
			imbueApply:setImageClip("0 0 128 66")
		else
			imbueApply:setImageSource("/images/game/imbuing/button-confirm-released")
		end

		function imbueApply.onHoverChange(widget, hovered, itemName, hasItem)
			local itensDetails = self.window:recursiveGetChildById("itensDetails")

			if hovered then
				itensDetails:setText(tr("Apply the selected imbuement. This will consume the required astral sources and gold."))
			elseif itensDetails then
				itensDetails:setText("")
			end
		end

		function imbueApply.onClick()
			if self.confirmWindow then
				g_modalManager.hide(self.confirmWindow)
				self.confirmWindow:destroy()

				self.confirmWindow = nil
			end

			Imbuement.hide()

			local function confirm()
				Imbuement.awaitingFyiRestore = false
				self.reservedReturnSlot = self.selectedSlot
				self.pendingReselectSlot = self.selectedSlot
				self.restoreSlotAfterSetup = self.selectedSlot
				self.pendingClientInfo = "apply"

				g_game.applyImbuement(self.selectedSlot, imbuement.id)

				if self.confirmWindow then
					g_modalManager.hide(self.confirmWindow)
					self.confirmWindow:destroy()

					self.confirmWindow = nil
				end

				Imbuement.onServerImbueAcknowledged(true, false)
			end

			local function cancelFunc()
				if self.confirmWindow then
					g_modalManager.hide(self.confirmWindow)
					self.confirmWindow:destroy()

					self.confirmWindow = nil
				end

				Imbuement.show()
			end

			self.confirmWindow = Imbuement.displayConfirmImbuingBox(tr("Confirm Imbuing"), tr("You are about to imbue your item with \"%s\". This will consume the required astral sources and %s gold coins. Do you wish to proceed?", string.capitalize(imbuement.name), comma_value(imbuement.cost)), {
				{
					text = tr("No"),
					callback = cancelFunc
				},
				{
					text = tr("Yes"),
					callback = confirm
				}
			}, confirm, cancelFunc)

			g_modalManager.show(self.confirmWindow)
		end
	end
end
