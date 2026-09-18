-- chunkname: @/gamelib/items.lua

ItemsDatabase = {}
ItemsDatabase.rarityColors = {
	yellow = TextColors.yellow,
	purple = TextColors.purple,
	blue = TextColors.blue,
	green = TextColors.green,
	grey = TextColors.grey
}

local function getColorForValue(value)
	if value >= 1000000 then
		return "yellow"
	elseif value >= 100000 then
		return "purple"
	elseif value >= 10000 then
		return "blue"
	elseif value >= 1000 then
		return "green"
	elseif value >= 50 then
		return "grey"
	else
		return "white"
	end
end

local function clipfunction(value)
	if value >= 1000000 then
		return "128 0 32 32"
	elseif value >= 100000 then
		return "96 0 32 32"
	elseif value >= 10000 then
		return "64 0 32 32"
	elseif value >= 1000 then
		return "32 0 32 32"
	elseif value >= 50 then
		return "0 0 32 32"
	end

	return ""
end

function ItemsDatabase.setRarityItem(widget, item, style, isBackground)
	if not g_game.getFeature(GameColorizedLootValue) or not widget then
		return
	end

	local frameOption = modules.client_options.getOption("framesRarity")

	if frameOption == "none" then
		return
	end

	local imagePath = "/images/ui/item"
	local clip
	local useSpecialArt = false

	if item then
		local price = type(item) == "number" and item or item and item:getMeanPrice() or 0
		local itemRarity = getColorForValue(price)

		if itemRarity then
			clip = clipfunction(price)

			if clip ~= "" then
				if frameOption == "frames" then
					imagePath = "/images/ui/containerslot-glowingborders"
					useSpecialArt = true
				elseif frameOption == "corners" then
					imagePath = "/images/ui/containerslot-coloredges"
					useSpecialArt = true
				end
			else
				clip = nil
			end
		end
	end

	if not useSpecialArt then
		local cn = widget:getClassName()

		if cn == "UIItem" or cn == "UIActionSlot" then
			imagePath = "/images/ui/item"
			clip = nil
		else
			imagePath = ""
			clip = nil
		end
	end

	widget:setImageClip(clip)
	widget:setImageSource(imagePath)

	if style then
		widget:setStyle(style)
	end

	return useSpecialArt
end

function ItemsDatabase.syncRarityWidgetVisibility(rarityWidget)
	if not rarityWidget then
		return
	end

	local imageSource = rarityWidget:getImageSource()

	rarityWidget:setVisible(imageSource and imageSource ~= "" and imageSource ~= "/images/ui/item")
end

local function resolveSlotRarityWidget(slotWidget)
	if slotWidget.rarity and slotWidget.rarity.getClassName then
		return slotWidget.rarity
	end

	return slotWidget:getChildById("rarity")
end

local function resolveSlotItemWidget(slotWidget)
	local itemUi = slotWidget:getChildById("item")

	if itemUi then
		return itemUi
	end

	if slotWidget.item and slotWidget.item.getClassName then
		return slotWidget.item
	end

	return nil
end

function ItemsDatabase.applyContainerRarityStackOrder(slotWidget, extraOverlayIds)
	if not slotWidget then
		return
	end

	local rarity = resolveSlotRarityWidget(slotWidget)
	local itemUi = resolveSlotItemWidget(slotWidget)

	if not rarity or not itemUi or itemUi:getClassName() ~= "UIItem" then
		return
	end

	local frameOption = modules.client_options and modules.client_options.getOption("framesRarity") or "frames"
	local hasItemSlot = slotWidget.itemSlot ~= nil
	local rarityIndex = hasItemSlot and 2 or 1
	local itemIndex = hasItemSlot and 3 or 2

	if frameOption == "corners" then
		rarityIndex = hasItemSlot and 3 or 2
		itemIndex = hasItemSlot and 2 or 1
	end

	if slotWidget.itemSlot then
		slotWidget:moveChildToIndex(slotWidget.itemSlot, 1)
	end

	slotWidget:moveChildToIndex(rarity, rarityIndex)
	slotWidget:moveChildToIndex(itemUi, itemIndex)

	local overlayIds = {
		"tier",
		"amount",
		"charges",
		"duration",
		"quickloot",
		"boxed"
	}

	if extraOverlayIds then
		for _, id in ipairs(extraOverlayIds) do
			table.insert(overlayIds, id)
		end
	end

	local overlayIndex = itemIndex + 1

	for _, id in ipairs(overlayIds) do
		local overlay = slotWidget[id]

		if overlay then
			slotWidget:moveChildToIndex(overlay, overlayIndex)

			overlayIndex = overlayIndex + 1
		end
	end
end

function ItemsDatabase.getColorForRarity(rarity)
	return ItemsDatabase.rarityColors[rarity] or TextColors.white
end

function ItemsDatabase.shouldHideExpiryForUnusedItem(item)
	if not item then
		return false
	end

	if not item.isBrandNew or type(item.isBrandNew) ~= "function" then
		return false
	end

	local ok, brandNew = pcall(function()
		return item:isBrandNew()
	end)

	if not ok or not brandNew then
		return false
	end

	if not modules.client_options or not modules.client_options.getOption then
		return false
	end

	return not modules.client_options.getOption("showExpiryOnUnusedItems")
end

function ItemsDatabase.setColorLootMessage(text)
	local function coloringLootName(match)
		local id, itemName = match:match("(%d+)|(.+)")
		local itemInfo = g_things.getThingType(tonumber(id), ThingCategoryItem):getMeanPrice()

		if itemInfo then
			local color = ItemsDatabase.getColorForRarity(getColorForValue(itemInfo))

			return "{" .. itemName .. ", " .. color .. "}"
		else
			return itemName
		end
	end

	return text:gsub("{(.-)}", coloringLootName)
end

function ItemsDatabase.setTier(widget, item)
	if not g_game.getFeature(GameThingUpgradeClassification) or not widget then
		return
	end

	local tier = type(item) == "number" and item or type(item) == "userdata" and item and item:getTier() or 0

	if tier and tier > 0 then
		local xOffset = (math.min(math.max(tier, 1), 10) - 1) * 9

		widget.tier:setImageClip({
			height = 8,
			width = 9,
			y = 0,
			x = xOffset
		})
		widget.tier:setVisible(true)
	else
		widget.tier:setVisible(false)
	end
end

function ItemsDatabase.setBigTier(widget, item)
	if not g_game.getFeature(GameThingUpgradeClassification) or not widget then
		return
	end

	local tier = type(item) == "number" and item or type(item) == "userdata" and item and item:getTier() or 0

	if tier and tier > 0 then
		local xOffset = (math.min(math.max(tier, 1), 10) - 1) * 18

		widget.bigtier:setImageClip({
			height = 16,
			width = 18,
			y = 0,
			x = xOffset
		})
		widget.bigtier:setVisible(true)
	else
		widget.bigtier:setVisible(false)
	end
end

function ItemsDatabase.setCharges(widget, item, style)
	if not g_game.getFeature(GameThingCounter) or not widget then
		return
	end

	if ItemsDatabase.shouldHideExpiryForUnusedItem(item) then
		widget.charges:setText("")

		if style then
			widget:setStyle(style)
		end

		return
	end

	if item and item:getCharges() > 0 then
		widget.charges:setText(item:getCharges())
	else
		widget.charges:setText("")
	end

	if style then
		widget:setStyle(style)
	end
end

function ItemsDatabase.setDuration(widget, item, style)
	if not g_game.getFeature(GameThingClock) or not widget then
		return
	end

	if ItemsDatabase.shouldHideExpiryForUnusedItem(item) then
		widget.duration:setText("")

		if style then
			widget:setStyle(style)
		end

		return
	end

	if item and item:getDurationTime() > 0 then
		local durationTimeLeft = item:getDurationTime()
		local text = formatItemDuration(durationTimeLeft)

		widget.duration:setText(text)
	else
		widget.duration:setText("")
	end

	if style then
		widget:setStyle(style)
	end
end

function formatItemDuration(duration)
	local hours = math.floor(duration / 3600)
	local minutes = math.floor(duration % 3600 / 60)
	local seconds = duration % 60
	local text = ""

	if hours > 0 then
		if hours >= 10 then
			return string.format("%dh", hours)
		end

		return string.format("%dh%02d", hours, minutes)
	elseif minutes > 0 then
		if minutes >= 10 then
			return string.format("%dm", minutes)
		end

		return string.format("%dm%02d", minutes, seconds)
	end

	return string.format("%ds", seconds)
end
