-- chunkname: @/mods/game_imbuing/classes/imbuementscroll.lua

if not ImbuementScroll then
	ImbuementScroll = {
		itemId = 51442,
		availableImbuements = {},
		needItems = {}
	}
end

ImbuementScroll.__index = ImbuementScroll

local self = ImbuementScroll

local function setImbuementStripIcon(resource, imageId)
	resource:setImageSource("/images/game/imbuing/imbuement-icons")
	resource:setImageClip(string.format("%d 0 64 64", (imageId or 0) * 64))
end

function ImbuementScroll.setup(availableImbuements, needItems)
	self.availableImbuements = availableImbuements or {}
	self.needItems = needItems or {}
	self.window = Imbuement.scrollImbue

	local itemWidget = self.window:recursiveGetChildById("itemScroll")

	if itemWidget then
		itemWidget:setItemId(self.itemId)
		itemWidget:setImageSmooth(true)
		itemWidget:setItemCount(1)
	end

	self.onSelectSlotImbue()
end

function ImbuementScroll:shutdown()
	self.window = nil
	self.confirmWindow = nil
	self.lastselectedwidget = nil
	self.availableImbuements = {}
	self.needItems = {}
end

function ImbuementScroll.clearScrollImbuementSelection()
	if self.lastselectedwidget then
		ImbuementItem.setImbuementChoiceSelected(self.lastselectedwidget, false)

		self.lastselectedwidget = nil
	end

	if not self.window or self.window:isDestroyed() then
		return
	end

	local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")

	if imbuementsDetails then
		imbuementsDetails:setVisible(false)
		imbuementsDetails:setText("")
	end

	local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")

	if imbuementReqPanel and imbuementReqPanel.title then
		imbuementReqPanel.title:setText("")
	end

	local blockedPanels = self.window:recursiveGetChildById("blockedPanels")

	if blockedPanels then
		blockedPanels:setVisible(true)
	end

	local itensDetails = self.window:recursiveGetChildById("itensDetails")

	if itensDetails then
		itensDetails:setText("")
	end

	local requiredItems = self.window:recursiveGetChildById("requiredItems")

	if requiredItems then
		for i = 1, 4 do
			local itemWidget = requiredItems:getChildById("item" .. i)

			if itemWidget then
				itemWidget:setVisible(false)
			end
		end
	end

	local costPanel = self.window:recursiveGetChildById("costPanel")

	if costPanel and costPanel.cost then
		costPanel.cost:setText(comma_value(0))
		costPanel.cost:setColor("#c0c0c0")
	end

	local imbuescrollApply = self.window:recursiveGetChildById("imbuescrollApply")

	if imbuescrollApply then
		imbuescrollApply:setEnabled(false)
		imbuescrollApply:setImageSource("/images/game/imbuing/button-confirm-blocked")
		imbuescrollApply:setImageClip("0 0 128 66")

		imbuescrollApply.onClick = nil
	end
end

function ImbuementScroll.onSelectSlotImbue()
	self.selectBaseType("intricateButton")
	self.window:recursiveGetChildById("imbuementsDetails"):setVisible(false)
end

function ImbuementScroll.selectBaseType(selectedButtonId)
	local qualityAndImbuementContent = self.window:recursiveGetChildById("qualityAndImbuementContent")

	if not qualityAndImbuementContent then
		return
	end

	local blockedPanels = self.window:recursiveGetChildById("blockedPanels")

	if blockedPanels then
		blockedPanels:setVisible(true)
	end

	self.lastselectedwidget = nil

	local intricateButton = qualityAndImbuementContent.intricateButton
	local powerfullButton = qualityAndImbuementContent.powerfullButton
	local baseImbuement = 1

	for _, button in pairs({
		intricateButton,
		powerfullButton
	}) do
		button:setOn(button:getId() == selectedButtonId)

		if button:getId() == selectedButtonId then
			baseImbuement = button.baseImbuement or 1
		end
	end

	local imbuementsList = self.window:recursiveGetChildById("imbuementsList")

	imbuementsList:destroyChildren()

	local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")

	imbuementsDetails:setVisible(false)

	for id, imbuement in ipairs(self.availableImbuements) do
		if imbuement.type == baseImbuement then
			local widget = g_ui.createWidget("SlotImbuing", imbuementsList)

			widget:setId(tostring(id))
			setImbuementStripIcon(widget.resource, imbuement.imageId)

			function widget.onClick()
				ImbuementScroll.selectImbuementWidget(widget, imbuement)
			end
		end
	end

	ImbuementScroll.clearScrollImbuementSelection()
end

function ImbuementScroll.selectImbuementWidget(widget, imbuement)
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
		for i = 1, 4 do
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

						itemWidget.count:setColor("#f75f5f")
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

		costPanel.cost:setColor(balance < cost and "#f75f5f" or "#c0c0c0")
	end

	local imbuescrollApply = self.window:recursiveGetChildById("imbuescrollApply")

	if imbuescrollApply then
		imbuescrollApply:setEnabled(hasRequiredItems)

		if not hasRequiredItems then
			imbuescrollApply:setImageSource("/images/game/imbuing/button-confirm-blocked")
			imbuescrollApply:setImageClip("0 0 128 66")
		else
			imbuescrollApply:setImageSource("/images/game/imbuing/button-confirm-released")
		end

		function imbuescrollApply.onHoverChange(widget, hovered, itemName, hasItem)
			local itensDetails = self.window:recursiveGetChildById("itensDetails")

			if hovered then
				itensDetails:setText(tr("Apply the selected imbuement. This will consume the required astral sources and gold."))
			elseif itensDetails then
				itensDetails:setText("")
			end
		end

		function imbuescrollApply.onClick()
			if self.confirmWindow then
				self.confirmWindow:destroy()

				self.confirmWindow = nil
			end

			Imbuement.hide()

			local function confirm()
				g_game.applyImbuement(0, imbuement.id)

				if self.confirmWindow then
					self.confirmWindow:destroy()

					self.confirmWindow = nil
				end

				Imbuement.onServerImbueAcknowledged(false)
			end

			local function cancelFunc()
				if self.confirmWindow then
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
		end
	end
end

function ImbuementScroll.onSelectImbuement(widget)
	local imbuementId = tonumber(widget:getId())
	local imbuement = self.availableImbuements[imbuementId]

	if not imbuement then
		return
	end

	local blockedPanels = self.window:recursiveGetChildById("blockedPanels")

	if blockedPanels then
		blockedPanels:setVisible(false)
	end

	local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")

	if imbuementReqPanel then
		imbuementReqPanel.title:setText(string.format("Imbue Blank Scroll with \"%s\"", imbuement.name))
	end

	local itensDetails = self.window:recursiveGetChildById("itensDetails")

	if itensDetails then
		itensDetails:setText("")
	end
end
