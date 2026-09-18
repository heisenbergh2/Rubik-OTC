-- chunkname: @/game_helper/helper_healer.lua

HelperHealer = HelperHealer or {}

local ctx
local healingEntries = {}
local healingEntriesPanel, healingSpellEntriesPanel, healingPotionEntriesPanel
local nextHealingEntryId = 1
local addHealingWindow, addHealingSlot, editingHealingEntryId, healingPercentSaveEvent, syncAddHealingConfirmButtons, openHealingRowContextMenu, openHealingEntryActionAssign, openHealingFormWindow, refreshHealingListUI, restoreSlotData, helperAssignWindow, helperAssignPanel, helperAssignMode, helperAssignTargetSlot
local ACTION_SLOT_SPELL_ITEM_ID = 469
local SLOT_IMG_EMPTY = "/images/game/actionbar/slot-actionbar-empty"
local SLOT_CLIP_NORMAL = "0 0 34 34"

local function ensureHealingEntries()
	if type(healingEntries) ~= "table" then
		healingEntries = {}
	end
end

local function saveConfigIfReady()
	if ctx and ctx.isLoadingConfig and ctx.isLoadingConfig() then
		return
	end

	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end
end

local function getSpellProfile()
	if SpelllistSettings and SpelllistSettings.Default then
		return "Default"
	end

	if SpelllistSettings then
		for profile in pairs(SpelllistSettings) do
			return profile
		end
	end

	return "Default"
end

local function normalizeEntryWords(words)
	if words == nil then
		return nil
	end

	if type(words) == "string" then
		local trimmed = words:match("^%s*(.-)%s*$") or ""

		if trimmed == "" then
			return nil
		end

		return trimmed
	end

	if type(words) == "number" then
		local spell = Spells.getSpellByClientId(words)

		if spell and spell.words then
			return spell.words
		end
	end

	return nil
end

local THRESHOLD_MIN = 1
local THRESHOLD_MAX = 100
local THRESHOLD_DEFAULT = 80
local IGNORED_HEALING_SPELL_IDS = {
	[144] = true,
	[128] = true,
	[145] = true,
	[146] = true,
	[29] = true,
	[242] = true,
	[84] = true,
	[297] = true
}
local POTION_WHITELIST = {
	{
		id = 268,
		type = "mana",
		requiredLevel = 1,
		name = "Mana Potion"
	},
	{
		id = 237,
		type = "mana",
		requiredLevel = 50,
		name = "Strong Mana Potion"
	},
	{
		id = 238,
		type = "mana",
		requiredLevel = 80,
		name = "Great Mana Potion"
	},
	{
		id = 23373,
		type = "mana",
		requiredLevel = 130,
		name = "Ultimate Mana Potion"
	},
	{
		id = 266,
		type = "health",
		requiredLevel = 1,
		name = "Health Potion"
	},
	{
		id = 236,
		type = "health",
		requiredLevel = 50,
		name = "Strong Health Potion"
	},
	{
		id = 239,
		type = "health",
		requiredLevel = 80,
		name = "Great Health Potion"
	},
	{
		id = 7643,
		type = "health",
		requiredLevel = 130,
		name = "Ultimate Health Potion"
	},
	{
		id = 23375,
		type = "health",
		requiredLevel = 200,
		name = "Supreme Health Potion"
	},
	{
		id = 7642,
		type = "health",
		requiredLevel = 80,
		name = "Great Spirit Potion"
	},
	{
		id = 23374,
		type = "health",
		requiredLevel = 130,
		name = "Ultimate Spirit Potion"
	},
	{
		id = 7876,
		type = "health",
		requiredLevel = 1,
		name = "Small Health Potion"
	},
	{
		id = 53162,
		type = "mana",
		requiredLevel = 100,
		name = "superior mana potion"
	},
	{
		id = 53163,
		type = "mana",
		requiredLevel = 130,
		name = "distilled superior mana potion"
	},
	{
		id = 53164,
		type = "mana",
		requiredLevel = 200,
		name = "distilled ultimate mana potion"
	}
}
local BLOCKED_POTION_IDS = {
	[35563] = true
}

local function isBlockedHealingPotionId(itemId)
	return itemId and BLOCKED_POTION_IDS[tonumber(itemId) or itemId] == true
end

local function isHealingFoodEntry(data)
	return data and data.useType == "use"
end

local helperCooldowns = {
	spells = {},
	groups = {}
}
local multiUseExDelay = 0
local gameEventsConnected = false
local POTION_TIMER_KEY = "potion"
local POTION_EXHAUST_MS = 1000
local GLOBAL_HEALING_CAST_COOLDOWN_MS = 250
local DEFAULT_SPELL_EXHAUSTION_MS = 1000
local ZEBRA_COLOR_A = "#484848"
local ZEBRA_COLOR_B = "#414141"
local ZEBRA_FOCUS_COLOR = "#585858"
local ZEBRA_TEXT_COLOR = "#c0c0c0"
local ZEBRA_FOCUS_TEXT_COLOR = "#f4f4f4"

local function applyZebraToPanel(panel)
	if not panel then
		return
	end

	local idx = 0

	for _, child in ipairs(panel:getChildren()) do
		if child:isVisible() then
			idx = idx + 1

			local color = idx % 2 == 1 and ZEBRA_COLOR_A or ZEBRA_COLOR_B

			child.zebraColor = color

			child:setBackgroundColor(color)
		end
	end
end

local function setHealingRowTextColors(row, color)
	for _, childId in ipairs({
		"healingRowValue",
		"healingRowCondition",
		"healingConditionName",
		"healingConditionMetricLabel"
	}) do
		local label = row:recursiveGetChildById(childId)

		if label and label.setColor then
			label:setColor(color)
		end
	end
end

local function resolveHealingEntryPanels()
	if ctx then
		if (not healingEntriesPanel or healingEntriesPanel:isDestroyed()) and ctx.getWidget then
			healingEntriesPanel = ctx.getWidget("healingEntriesPanel")
		end

		if (not healingSpellEntriesPanel or healingSpellEntriesPanel:isDestroyed()) and ctx.getWidget then
			healingSpellEntriesPanel = ctx.getWidget("healingSpellEntriesPanel")
		end

		if (not healingPotionEntriesPanel or healingPotionEntriesPanel:isDestroyed()) and ctx.getWidget then
			healingPotionEntriesPanel = ctx.getWidget("healingPotionEntriesPanel")
		end
	end
end

local function forEachHealingEntryPanel(callback)
	resolveHealingEntryPanels()

	local panels = {
		healingSpellEntriesPanel,
		healingPotionEntriesPanel,
		healingEntriesPanel
	}

	for i = 1, 3 do
		local panel = panels[i]

		if panel and not panel:isDestroyed() then
			callback(panel)
		end
	end
end

local function getSelectedHealingEntryId()
	local entryId

	forEachHealingEntryPanel(function(panel)
		if entryId then
			return
		end

		local focused = panel:getFocusedChild()

		if focused and focused.healingEntryId then
			entryId = focused.healingEntryId
		end
	end)

	return entryId
end

local function findHealingRowByEntryId(entryId)
	local targetRow

	forEachHealingEntryPanel(function(panel)
		if targetRow then
			return
		end

		for _, row in ipairs(panel:getChildren()) do
			if row.healingEntryId == entryId then
				targetRow = row

				return
			end
		end
	end)

	return targetRow
end

local function focusHealingPanelRow(row)
	if not row or row:isDestroyed() then
		return
	end

	local parent = row:getParent()

	if parent and parent.focusChild then
		parent:focusChild(row, KeyboardFocusReason)
	end

	row:setBackgroundColor(ZEBRA_FOCUS_COLOR)
	setHealingRowTextColors(row, ZEBRA_FOCUS_TEXT_COLOR)
end

local function resetHealingRowFocusColors()
	forEachHealingEntryPanel(function(panel)
		for _, row in ipairs(panel:getChildren()) do
			if row.zebraColor then
				row:setBackgroundColor(row.zebraColor)
				setHealingRowTextColors(row, ZEBRA_TEXT_COLOR)
			end
		end
	end)
end

local function findParentHealingRow(widget)
	while widget do
		if widget.healingEntryId then
			return widget
		end

		widget = widget:getParent()
	end

	return nil
end

local function syncHealingActionButtons()
	if not ctx then
		return
	end

	local addBtn = ctx.getWidget("addHealingButton")
	local editBtn = ctx.getWidget("editHealingButton")
	local removeBtn = ctx.getWidget("removeHealingButton")

	if not addBtn or not editBtn or not removeBtn then
		return
	end

	local hasSelection = getSelectedHealingEntryId() ~= nil

	if hasSelection then
		removeBtn:show()
		editBtn:show()
		addBtn:breakAnchors()
		addBtn:addAnchor(AnchorTop, "parent", AnchorTop)
		addBtn:addAnchor(AnchorRight, "editHealingButton", AnchorLeft)
		addBtn:setMarginRight(6)
	else
		removeBtn:hide()
		editBtn:hide()
		addBtn:breakAnchors()
		addBtn:addAnchor(AnchorTop, "parent", AnchorTop)
		addBtn:addAnchor(AnchorRight, "parent", AnchorRight)
		addBtn:setMarginRight(0)
	end
end

local function connectZebraFocus(widget)
	connect(widget, {
		onFocusChange = function(self, focused)
			if focused then
				self:setBackgroundColor(ZEBRA_FOCUS_COLOR)
				setHealingRowTextColors(self, ZEBRA_FOCUS_TEXT_COLOR)
				syncHealingActionButtons()
			else
				addEvent(function()
					if not self:isDestroyed() then
						self:setBackgroundColor(self.zebraColor or ZEBRA_COLOR_A)
						setHealingRowTextColors(self, ZEBRA_TEXT_COLOR)
						syncHealingActionButtons()
					end
				end)
			end
		end
	})
end

local function clearHealingListSelection()
	forEachHealingEntryPanel(function(panel)
		panel:focusChild(nil)
	end)
	resetHealingRowFocusColors()
	syncHealingActionButtons()
end

local SPIRIT_POTION_IDS = {
	[23374] = true,
	[7642] = true
}
local POTION_TYPE_BY_ID = {}

for _, potion in ipairs(POTION_WHITELIST) do
	POTION_TYPE_BY_ID[potion.id] = potion.type
end

local function actionbar()
	return modules.game_actionbar
end

local function normalizePotionLevel(requiredLevel)
	local level = tonumber(requiredLevel) or 1

	if level < 1 then
		level = 1
	end

	return level
end

local function potionMeetsLevel(requiredLevel)
	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	return player:getLevel() >= normalizePotionLevel(requiredLevel)
end

local function getPotionRequiredLevel(itemId)
	for _, potion in ipairs(POTION_WHITELIST) do
		if potion.id == itemId then
			if potion.requiredLevel then
				return normalizePotionLevel(potion.requiredLevel)
			end

			break
		end
	end

	if g_things and g_things.getThingType then
		local ok, thing = pcall(function()
			return g_things.getThingType(itemId, ThingCategoryItem)
		end)

		if ok and thing then
			local market = thing.getMarketData and thing:getMarketData() or nil

			if market and market.requiredLevel and market.requiredLevel > 0 then
				return normalizePotionLevel(market.requiredLevel)
			end
		end
	end

	return 1
end

local function potionItemMeetsLevel(itemId)
	return potionMeetsLevel(getPotionRequiredLevel(itemId))
end

local shouldShowPotionLevelGray

local function playerCanUseHealingSpellVocations(vocations, player)
	if not vocations or not next(vocations) then
		return true
	end

	if not player then
		return false
	end

	local rawVoc = player:getVocation()
	local translatedVoc = type(translateVocation) == "function" and translateVocation(rawVoc) or rawVoc

	for _, voc in ipairs(vocations) do
		if voc == rawVoc or voc == translatedVoc then
			return true
		end
	end

	return false
end

local function shouldShowHealingSpellGray(words)
	words = normalizeEntryWords(words)

	if not words then
		return false
	end

	if not Spells or not Spells.getSpellByWords then
		return false
	end

	local spell = Spells.getSpellByWords(words)

	if not spell then
		return false
	end

	local player = g_game.getLocalPlayer()

	if player and spell.vocations and not playerCanUseHealingSpellVocations(spell.vocations, player) then
		return true
	end

	if spell.level and player and not potionMeetsLevel(spell.level) then
		return true
	end

	return false
end

local function shouldShowHealingRowGray(entry)
	if not entry then
		return false
	end

	local ok, result = pcall(function()
		local words = normalizeEntryWords(entry.words)

		if words then
			return shouldShowHealingSpellGray(words)
		end

		if entry.itemId and entry.itemId > 0 then
			if SPIRIT_POTION_IDS[tonumber(entry.itemId) or entry.itemId] == true then
				return false
			end

			return shouldShowPotionLevelGray(entry.itemId)
		end

		return false
	end)

	if not ok then
		if g_logger and g_logger.warning then
			g_logger.warning("[HelperHealer] shouldShowHealingRowGray failed: " .. tostring(result))
		end

		return false
	end

	return result
end

local function slotHasHelperPotion(slot)
	if not slot then
		return false
	end

	if slot.words and slot.words ~= "" then
		return false
	end

	local itemId = tonumber(slot.itemId)

	return itemId and itemId > 0 and itemId ~= ACTION_SLOT_SPELL_ITEM_ID
end

local function isHealingActionSlot(slot)
	return slot and (slot._helperHealingSlot == true or addHealingSlot and slot == addHealingSlot)
end

local function stackHealingActionSlotLayers(slot)
	if not isHealingActionSlot(slot) then
		return
	end

	local bg = slot:getChildById("healingActionItemBackground")
	local itemIcon = slot:getChildById("healingActionItemIcon")
	local spellIcon = slot:getChildById("spellIcon")
	local gray = slot:getChildById("gray")

	if gray then
		gray:setPhantom(true)
		gray:setFocusable(false)
		gray:setOpacity(0.35)
	end

	if bg then
		slot:raiseChild(bg)
	end

	if spellIcon then
		slot:raiseChild(spellIcon)
	end

	if itemIcon then
		slot:raiseChild(itemIcon)
	end

	if gray then
		slot:raiseChild(gray)
	end
end

local function syncHealingActionSlotLayers(slot)
	if not isHealingActionSlot(slot) then
		return
	end

	local bg = slot:getChildById("healingActionItemBackground")
	local itemIcon = slot:getChildById("healingActionItemIcon")
	local hasSpell = slot.words and slot.words ~= ""
	local hasItem = slotHasHelperPotion(slot)

	if hasItem then
		local displayItemId = tonumber(slot._helperDisplayItemId or slot.itemId) or 0

		if slot.setItemVisible then
			slot:setItemVisible(false)
		end

		if bg then
			bg:show()
		end

		if itemIcon then
			if itemIcon.clearItem then
				itemIcon:clearItem()
			end

			if itemIcon.setItemId then
				itemIcon:setItemId(displayItemId)
			end

			itemIcon:show()
		end
	else
		if bg then
			bg:hide()
		end

		if itemIcon then
			itemIcon:hide()

			if itemIcon.clearItem then
				itemIcon:clearItem()
			end
		end

		if slot.setItemVisible then
			slot:setItemVisible(not hasSpell)
		end
	end

	stackHealingActionSlotLayers(slot)
end

local function updateHealingActionSlotGray(slot)
	if not isHealingActionSlot(slot) then
		return
	end

	local gray = slot:getChildById("gray")

	if not gray then
		return
	end

	if slot.words and slot.words ~= "" then
		local ab = actionbar()

		if ab and ab.updateSlotGray then
			ab.updateSlotGray(slot)
		end

		return
	end

	local displayItemId = tonumber(slot._helperDisplayItemId or slot.itemId) or 0

	if SPIRIT_POTION_IDS[displayItemId] == true then
		gray:setVisible(false)

		return
	end

	gray:setVisible(shouldShowPotionLevelGray(displayItemId))
end

local function refreshSlotVisual(slot)
	local ab = actionbar()

	if not slot or not ab then
		return
	end

	local hasSpell = slot.words and slot.words ~= ""
	local hasItem = slotHasHelperPotion(slot)

	if hasItem or hasSpell then
		if ab.applyActionSlotFrame then
			ab.applyActionSlotFrame(slot)
		end

		if slot._helperAssignPreview and ab.refreshActionSlotFrameClip then
			ab.refreshActionSlotFrameClip(slot)
		end
	elseif slot._helperAssignPreview then
		slot:setImageSource(SLOT_IMG_EMPTY)
		slot:setImageSize(tosize("34 34"))
		slot:setImageClip(SLOT_CLIP_NORMAL)

		slot._actionBarFilledFrame = false
	elseif ab.applyActionSlotFrame then
		ab.applyActionSlotFrame(slot)
	end

	syncHealingActionSlotLayers(slot)

	if isHealingActionSlot(slot) then
		updateHealingActionSlotGray(slot)
	else
		local abGray = actionbar()

		if abGray and abGray.updateSlotGray then
			abGray.updateSlotGray(slot)
		end
	end

	if ab.refreshActionSlotInventoryQuantity then
		ab.refreshActionSlotInventoryQuantity(slot)
	end

	if ab.refreshActionSlotTooltip then
		ab.refreshActionSlotTooltip(slot)
	end

	stackHealingActionSlotLayers(slot)
end

local function clearSlotData(slot)
	local ab = actionbar()

	if ab and ab.clearSlotActionContent then
		ab.clearSlotActionContent(slot)

		slot._helperDisplayItemId = nil

		if slot == addHealingSlot then
			refreshSlotVisual(slot)
		end

		if slot == addHealingSlot then
			syncAddHealingConfirmButtons()
		end

		return
	end

	if slot.clearItem then
		slot:clearItem()
	end

	local spellIcon = slot:getChildById("spellIcon")

	if spellIcon then
		spellIcon:hide()
		spellIcon:setImageSource("")
	end

	slot.itemId = nil
	slot._helperDisplayItemId = nil
	slot.words = nil
	slot.text = nil
	slot.subType = nil
	slot.useType = nil
	slot.parameter = nil

	refreshSlotVisual(slot)

	if slot == addHealingSlot then
		syncAddHealingConfirmButtons()
	end
end

local function assignItemToSlot(slot, option, skipSave)
	if not option or isHealingFoodEntry(option) or isBlockedHealingPotionId(option.itemId) then
		return
	end

	clearSlotData(slot)

	slot.itemId = option.itemId
	slot._helperDisplayItemId = option.itemId
	slot.useType = option.useType or "useOnSelf"

	if slot.setItemId then
		slot:setItemId(option.itemId)
	elseif slot.setItem then
		local item = Item.create(option.itemId)

		if item then
			slot:setItem(item)
		end
	end

	local ab = actionbar()

	if ab and ab.loadObject then
		ab.loadObject(slot)
	end

	refreshSlotVisual(slot)

	if not skipSave and ctx and ctx.saveConfig then
		saveConfigIfReady()
	end

	if slot == addHealingSlot then
		syncAddHealingConfirmButtons()
	end
end

local function containsGroup(groups, targetGroup)
	if not groups then
		return false
	end

	for _, group in ipairs(groups) do
		if group == targetGroup then
			return true
		end
	end

	return false
end

local function isHelperHealingSpell(_, spellData)
	if not spellData then
		return false
	end

	if IGNORED_HEALING_SPELL_IDS[spellData.id] then
		return false
	end

	if spellData.needTarget and spellData.parameter then
		return false
	end

	return containsGroup(Spells.getGroupIds(spellData), 2)
end

local function openHelperSpellAssign(slot, filterFn, onAssigned)
	local ab = actionbar()

	if not ab or not ab.openHelperSpellAssignWindow then
		return
	end

	local slotId = slot:getId()

	if not slotId or slotId == "" then
		return
	end

	ab.openHelperSpellAssignWindow(slot, slotId, filterFn, function(assignedSlot)
		if onAssigned then
			onAssigned(assignedSlot or slot)
		elseif ctx and ctx.saveConfig then
			saveConfigIfReady()
		end
	end)
end

local function thingDisplayName(thing, id)
	local raw = thing:getName() or ""
	local trim = raw:gsub("^%s+", ""):gsub("%s+$", "")

	if trim ~= "" then
		return trim
	end

	return "#" .. tostring(id)
end

local function capitalizeWords(text)
	if not text or text == "" then
		return ""
	end

	return (text:gsub("(%a)([%w_']*)", function(a, rest)
		return a:upper() .. rest:lower()
	end))
end

local function potionMeetsVocation(thing)
	if not thing then
		return true
	end

	local market = thing.getMarketData and thing:getMarketData() or nil

	if not market or not market.restrictVocation or tonumber(market.restrictVocation) == 0 then
		return true
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	local vocation = player:getVocation()
	local demotedVoc = vocation > 10 and vocation - 10 or vocation
	local vocBitMask = Bit.bit(tonumber(demotedVoc))

	return Bit.hasBit(market.restrictVocation, vocBitMask)
end

local function formatPotionLevelText(requiredLevel)
	return tr("Level:") .. " " .. tostring(normalizePotionLevel(requiredLevel))
end

local function buildPotionAssignList()
	local potions = {}

	for _, potion in ipairs(POTION_WHITELIST) do
		local thing = g_things.getThingType(potion.id, ThingCategoryItem)

		if thing and potionMeetsVocation(thing) then
			table.insert(potions, {
				id = potion.id,
				name = potion.name,
				requiredLevel = getPotionRequiredLevel(potion.id)
			})
		end
	end

	table.sort(potions, function(a, b)
		return a.name:lower() < b.name:lower()
	end)

	return potions
end

local function potionItemIsAvailable(itemId)
	if not itemId then
		return true
	end

	if isBlockedHealingPotionId(itemId) then
		return false
	end

	local thing = g_things.getThingType(itemId, ThingCategoryItem)

	return potionItemMeetsLevel(itemId) and potionMeetsVocation(thing)
end

function shouldShowPotionLevelGray(itemId)
	if not itemId then
		return false
	end

	return not potionItemIsAvailable(itemId)
end

local function closeHelperItemAssignInternal()
	helperAssignTargetSlot = nil
	helperAssignMode = nil
	helperAssignPanel = nil

	if helperAssignWindow and not helperAssignWindow:isDestroyed() then
		helperAssignWindow:destroy()
	end

	helperAssignWindow = nil
end

local function helperItemAssignUsesLearntFilter()
	return helperAssignMode == "potion"
end

local function rowMeetsLearntFilter(row)
	if not helperItemAssignUsesLearntFilter() then
		return true
	end

	return potionItemIsAvailable(row.assignItemId)
end

local function stackHelperAssignRowLayers(row)
	if not row then
		return
	end

	local bg = row:getChildById("listItemBackground")
	local itemIcon = row:getChildById("listItemIcon")
	local gray = row:getChildById("spellIconGray")

	if bg then
		row:raiseChild(bg)
	end

	if itemIcon then
		row:raiseChild(itemIcon)
	end

	if gray then
		row:raiseChild(gray)
	end
end

local function syncHelperAssignRowGray(row)
	if not row then
		return
	end

	local gray = row:getChildById("spellIconGray")

	if not gray then
		return
	end

	if helperAssignMode == "potion" then
		gray:setVisible(shouldShowPotionLevelGray(row.assignItemId))
	else
		gray:hide()
	end

	stackHelperAssignRowLayers(row)
end

local function updateHelperItemPreview(row)
	if not helperAssignWindow or helperAssignWindow:isDestroyed() or not row then
		return
	end

	local preview = helperAssignWindow:recursiveGetChildById("spellPreview")

	if not preview then
		return
	end

	local spellIcon = preview:getChildById("previewSpellIcon")
	local itemIcon = preview:getChildById("previewItemIcon")
	local spellGray = preview:getChildById("previewSpellGray")
	local itemGray = preview:getChildById("previewItemGray")
	local nameLabel = preview:getChildById("previewSpellName")
	local wordsLabel = preview:getChildById("previewSpellWords")

	if spellIcon then
		spellIcon:hide()
	end

	if spellGray then
		spellGray:hide()
	end

	local itemBg = preview:getChildById("previewItemBackground")

	if itemIcon then
		itemIcon:show()
		itemIcon:setItemId(row.assignItemId or 0)
	end

	if itemBg then
		itemBg:show()
	end

	if nameLabel then
		nameLabel:setText(row.assignItemName or "")
	end

	if wordsLabel then
		wordsLabel:setText("")
	end

	if itemGray then
		if helperAssignMode == "potion" then
			itemGray:setVisible(shouldShowPotionLevelGray(row.assignItemId))
		else
			itemGray:hide()
		end

		preview:raiseChild(itemGray)
	end
end

local function clearHelperItemPreview()
	if not helperAssignWindow or helperAssignWindow:isDestroyed() then
		return
	end

	local preview = helperAssignWindow:recursiveGetChildById("spellPreview")

	if not preview then
		return
	end

	local spellIcon = preview:getChildById("previewSpellIcon")
	local itemIcon = preview:getChildById("previewItemIcon")
	local itemBg = preview:getChildById("previewItemBackground")
	local itemGray = preview:getChildById("previewItemGray")

	if spellIcon then
		spellIcon:hide()
	end

	if itemIcon then
		itemIcon:hide()
	end

	if itemBg then
		itemBg:hide()
	end

	if itemGray then
		itemGray:hide()
	end

	local nameLabel = preview:getChildById("previewSpellName")
	local wordsLabel = preview:getChildById("previewSpellWords")

	if nameLabel then
		nameLabel:setText("")
	end

	if wordsLabel then
		wordsLabel:setText("")
	end
end

local function syncHelperItemAssignOkButton()
	if not helperAssignWindow or helperAssignWindow:isDestroyed() or not helperAssignPanel then
		return
	end

	local okBtn = helperAssignWindow:recursiveGetChildById("okButton")

	if not okBtn then
		return
	end

	local focused = helperAssignPanel:getFocusedChild()

	okBtn:setEnabled(focused ~= nil and focused:isVisible() and focused.assignItemId ~= nil)
end

local function focusFirstVisibleHelperAssignRow()
	if not helperAssignPanel then
		return
	end

	local first

	for _, child in ipairs(helperAssignPanel:getChildren()) do
		if child:isVisible() then
			first = child

			break
		end
	end

	if first then
		helperAssignPanel:focusChild(first, KeyboardFocusReason)
		updateHelperItemPreview(first)
	else
		helperAssignPanel:focusChild(nil)
		clearHelperItemPreview()
	end

	syncHelperItemAssignOkButton()
end

local function createHelperItemAssignRow(itemId, itemName, requiredLevel)
	local row = g_ui.createWidget("HelperAssignListLabel", helperAssignPanel)

	row.assignItemId = itemId
	row.assignItemName = itemName
	row.nameLower = itemName:lower()
	row.requiredLevel = requiredLevel

	local spellIcon = row:getChildById("spellIcon")

	if spellIcon then
		spellIcon:hide()
	end

	local groupIcon = row:getChildById("groupCooldownIcon")

	if groupIcon then
		groupIcon:hide()
	end

	local levelLabel = row:getChildById("spellLevel")
	local nameLabel = row:getChildById("spellName")
	local wordsLabel = row:getChildById("spellWords")
	local itemIcon = row:getChildById("listItemIcon")

	if itemIcon then
		itemIcon:show()
		itemIcon:setItemId(itemId)
	end

	local itemBg = row:getChildById("listItemBackground")

	if itemBg then
		itemBg:show()
	end

	syncHelperAssignRowGray(row)

	if nameLabel then
		nameLabel:setText(itemName)
	end

	if wordsLabel then
		wordsLabel:setText("")
		wordsLabel:hide()
	end

	if levelLabel then
		if helperAssignMode == "potion" then
			levelLabel:show()
			levelLabel:setText(formatPotionLevelText(requiredLevel))
		else
			levelLabel:hide()
		end
	end

	return row
end

local function openHelperItemAssignWindow(targetSlot)
	if helperAssignWindow and not helperAssignWindow:isDestroyed() then
		closeHelperItemAssignInternal()
	end

	helperAssignWindow = g_ui.loadUI("assign_helper", g_ui.getRootWidget())

	if not helperAssignWindow then
		return
	end

	helperAssignMode = "potion"
	helperAssignTargetSlot = targetSlot
	helperAssignPanel = helperAssignWindow:recursiveGetChildById("spellsPanel")

	helperAssignWindow:setText(tr("Assign Potion"))

	local learntPanel = helperAssignWindow:recursiveGetChildById("onlyShowLearntSpellsPanel")

	if learntPanel then
		learntPanel:setVisible(true)
	end

	local learntCb = helperAssignWindow:recursiveGetChildById("onlyShowLearntSpellsCheckBox")

	if learntCb then
		learntCb:setChecked(false)
		learntCb:setText(tr("Only show available potions"))
	end

	local okBtn = helperAssignWindow:recursiveGetChildById("okButton")

	if okBtn then
		okBtn:setEnabled(false)
	end

	for _, potion in ipairs(buildPotionAssignList()) do
		createHelperItemAssignRow(potion.id, potion.name, potion.requiredLevel)
	end

	connect(helperAssignPanel, {
		onChildFocusChange = function(_, focusedChild)
			if not focusedChild then
				syncHelperItemAssignOkButton()

				return
			end

			updateHelperItemPreview(focusedChild)
			syncHelperItemAssignOkButton()
		end
	})
	HelperHealer.filterHelperAssignEntries("")
	focusFirstVisibleHelperAssignRow()
	helperAssignWindow:raise()
	helperAssignWindow:focus()

	local edit = helperAssignWindow:recursiveGetChildById("filterTextEdit")

	if edit then
		edit:focus()
	end
end

local function openPotionAssignWindow(targetSlot)
	openHelperItemAssignWindow(targetSlot)
end

function HelperHealer.isHelperItemAssignActive()
	return helperAssignWindow and not helperAssignWindow:isDestroyed()
end

function HelperHealer.closeHelperItemAssignWindow()
	if HelperHealer.cancelPendingHealingEntryAssign then
		HelperHealer.cancelPendingHealingEntryAssign()
	end

	closeHelperItemAssignInternal()
end

function HelperHealer.helperItemAssignOk()
	if not HelperHealer.isHelperItemAssignActive() or not helperAssignPanel or not helperAssignTargetSlot then
		return
	end

	local focused = helperAssignPanel:getFocusedChild()

	if not focused or not focused.assignItemId then
		return
	end

	local targetSlot = helperAssignTargetSlot
	local useType = "useOnSelf"
	local skipSave = addHealingSlot and targetSlot == addHealingSlot or targetSlot._helperAssignSkipSave == true

	assignItemToSlot(targetSlot, {
		itemId = focused.assignItemId,
		useType = useType
	}, skipSave)
	closeHelperItemAssignInternal()

	if targetSlot.onHelperPotionAssigned then
		targetSlot.onHelperPotionAssigned(targetSlot)
	end
end

function HelperHealer.filterHelperAssignEntries(text)
	if not helperAssignPanel or not HelperHealer.isHelperItemAssignActive() then
		return
	end

	text = text or ""

	local textActive = #text > 0
	local textLower = textActive and text:lower() or ""
	local onlyLearnt = false

	if helperAssignWindow then
		local learntCb = helperAssignWindow:recursiveGetChildById("onlyShowLearntSpellsCheckBox")

		onlyLearnt = learntCb and learntCb:isChecked() or false
	end

	for _, row in ipairs(helperAssignPanel:getChildren()) do
		local visible = true

		if onlyLearnt and not rowMeetsLearntFilter(row) then
			visible = false
		end

		if visible and textActive then
			visible = row.nameLower and row.nameLower:find(textLower, 1, true) ~= nil or false
		end

		row:setVisible(visible)
	end

	focusFirstVisibleHelperAssignRow()
end

function HelperHealer.clearHelperItemAssignFilter()
	if not HelperHealer.isHelperItemAssignActive() then
		return
	end

	local edit = helperAssignWindow:recursiveGetChildById("filterTextEdit")

	if edit then
		edit:setText("")
		HelperHealer.filterHelperAssignEntries("")
		edit:focus()
	end
end

function HelperHealer.onHelperAssignLearntChange()
	if not HelperHealer.isHelperItemAssignActive() then
		return
	end

	local edit = helperAssignWindow:recursiveGetChildById("filterTextEdit")

	HelperHealer.filterHelperAssignEntries(edit and edit:getText() or "")
end

function HelperHealer.closePotionAssignWindow()
	closeHelperItemAssignInternal()
end

function HelperHealer.potionAssignOk()
	HelperHealer.helperItemAssignOk()
end

function HelperHealer.filterPotions(text)
	HelperHealer.filterHelperAssignEntries(text)
end

function HelperHealer.clearPotionFilter()
	HelperHealer.clearHelperItemAssignFilter()
end

function HelperHealer.openPotionSelectWindow(targetSlot)
	if not targetSlot then
		return
	end

	openHelperItemAssignWindow(targetSlot)
end

local function actionSlotItemTier(slot)
	if g_game.getFeature and g_game.getFeature(GameThingUpgradeClassification) then
		local stored = slot and slot.getTier

		if type(stored) == "number" then
			return stored
		end
	end

	return 0
end

local function resolveHealingCooldownSpellId(spellId)
	if Spells and Spells.resolveSpellId then
		return Spells.resolveSpellId(spellId)
	end

	return spellId
end

local function resolveHealingSpellExhaustion(spell)
	if type(spell) ~= "table" then
		return DEFAULT_SPELL_EXHAUSTION_MS
	end

	local exhaustion = tonumber(spell.exhaustion)

	if exhaustion and exhaustion > 0 then
		return exhaustion
	end

	return DEFAULT_SPELL_EXHAUSTION_MS
end

local function resolveHealingGroupExhaustion(spell, groupId)
	if type(spell) == "table" and type(spell.group) == "table" then
		local groupExhaustion = tonumber(spell.group[groupId])

		if groupExhaustion and groupExhaustion > 0 then
			return groupExhaustion
		end
	end

	return DEFAULT_SPELL_EXHAUSTION_MS
end

local function setHelperSpellCooldownExpiry(spellId, duration, keepLonger)
	if not spellId then
		return
	end

	local key = resolveHealingCooldownSpellId(spellId)

	if not duration or duration <= 0 then
		helperCooldowns.spells[key] = nil

		return
	end

	local expires = g_clock.millis() + duration

	if keepLonger then
		if expires > (helperCooldowns.spells[key] or 0) then
			helperCooldowns.spells[key] = expires
		end
	else
		helperCooldowns.spells[key] = expires
	end
end

local function setHelperGroupCooldownExpiry(groupId, duration, keepLonger)
	if not groupId then
		return
	end

	if not duration or duration <= 0 then
		helperCooldowns.groups[groupId] = nil

		return
	end

	local expires = g_clock.millis() + duration

	if keepLonger then
		if expires > (helperCooldowns.groups[groupId] or 0) then
			helperCooldowns.groups[groupId] = expires
		end
	else
		helperCooldowns.groups[groupId] = expires
	end
end

local function applyLocalHealingCastLock(spell)
	if not spell then
		return
	end

	if spell.id then
		local spellDuration = math.max(GLOBAL_HEALING_CAST_COOLDOWN_MS, resolveHealingSpellExhaustion(spell))

		setHelperSpellCooldownExpiry(spell.id, spellDuration, true)
	end

	if type(spell.group) == "table" then
		for groupId in pairs(spell.group) do
			local groupDuration = math.max(GLOBAL_HEALING_CAST_COOLDOWN_MS, resolveHealingGroupExhaustion(spell, groupId))

			setHelperGroupCooldownExpiry(groupId, groupDuration, true)
		end
	elseif spell.group then
		local groupDuration = math.max(GLOBAL_HEALING_CAST_COOLDOWN_MS, resolveHealingSpellExhaustion(spell))

		setHelperGroupCooldownExpiry(spell.group, groupDuration, true)
	end
end

local function onHelperSpellCooldown(spellId, delay)
	setHelperSpellCooldownExpiry(spellId, delay, false)
end

local function onHelperSpellGroupCooldown(groupId, delay)
	setHelperGroupCooldownExpiry(groupId, delay, false)
end

local function onHelperMultiUseCooldown(time)
	if not time or time <= 0 then
		multiUseExDelay = 0

		return
	end

	multiUseExDelay = g_clock.millis() + time
end

local function connectGameEvents()
	if gameEventsConnected then
		return
	end

	connect(g_game, {
		onSpellCooldown = onHelperSpellCooldown,
		onSpellGroupCooldown = onHelperSpellGroupCooldown,
		onMultiUseCooldown = onHelperMultiUseCooldown
	})

	gameEventsConnected = true
end

local function disconnectGameEvents()
	if not gameEventsConnected then
		return
	end

	disconnect(g_game, {
		onSpellCooldown = onHelperSpellCooldown,
		onSpellGroupCooldown = onHelperSpellGroupCooldown,
		onMultiUseCooldown = onHelperMultiUseCooldown
	})

	gameEventsConnected = false
end

local function getHelperSpellCooldown(spellId)
	return helperCooldowns.spells[spellId] or 0
end

local function getHelperGroupCooldown(groupId)
	return helperCooldowns.groups[groupId] or 0
end

local function isManaPotion(itemId)
	return POTION_TYPE_BY_ID[tonumber(itemId) or itemId] == "mana"
end

local function isHealthPotion(itemId)
	return POTION_TYPE_BY_ID[tonumber(itemId) or itemId] == "health"
end

local function isSpiritPotion(itemId)
	return SPIRIT_POTION_IDS[tonumber(itemId) or itemId] == true
end

local function canPlayerCastHealingSpell(words, player)
	if not words or not player then
		return false
	end

	local spell = Spells.getSpellByWords(words)

	if not spell then
		return true
	end

	if spell.mana and player:getMana() < spell.mana then
		return false
	end

	if spell.level and player:getLevel() < spell.level then
		return false
	end

	if spell.soul and player:getSoul() < spell.soul then
		return false
	end

	if spell.vocations and not playerCanUseHealingSpellVocations(spell.vocations, player) then
		return false
	end

	return true
end

local function isHelperSpellOnCooldown(words)
	local spell = Spells.getSpellByWords(words)

	if not spell or spell.id == 0 then
		return false
	end

	local nowMs = g_clock.millis()
	local spellKey = resolveHealingCooldownSpellId(spell.id)

	if nowMs <= getHelperSpellCooldown(spellKey) then
		return true
	end

	if type(spell.group) == "table" then
		for groupId, _ in pairs(spell.group) do
			if nowMs <= getHelperGroupCooldown(groupId) then
				return true
			end
		end
	elseif spell.group and nowMs <= getHelperGroupCooldown(spell.group) then
		return true
	end

	local ab = actionbar()

	if ab and ab.getMultiActionCooldownRemaining then
		local spellRem, groupRem = ab.getMultiActionCooldownRemaining(spell)

		if spellRem > 0 or groupRem > 0 then
			return true
		end
	end

	return false
end

local function isPotionUseBlocked()
	local nowMs = g_clock.millis()

	return nowMs < getHelperSpellCooldown(POTION_TIMER_KEY) or nowMs < multiUseExDelay
end

local function playerHasItem(player, itemId, slot)
	if not player or not itemId or itemId <= 0 then
		return false
	end

	local tier = actionSlotItemTier(slot)

	if player.getInventoryCount and player:getInventoryCount(itemId, tier) > 0 then
		return true
	end

	if g_game.findPlayerItem then
		return g_game.findPlayerItem(itemId, slot and slot.subType or -1, tier) ~= nil
	end

	return false
end

local function compareNumber(value, threshold, condition)
	if condition == "<" then
		return value < threshold
	end

	if condition == ">" then
		return threshold < value
	end

	if condition == ">=" then
		return threshold <= value
	end

	return value <= threshold
end

local function comboOptionText(combo)
	if not combo then
		return nil
	end

	if combo.getCurrentOption then
		local current = combo:getCurrentOption()

		if type(current) == "table" then
			return current.text or current.value or current.label
		end

		if type(current) == "string" then
			return current
		end
	end

	if combo.getText then
		local text = combo:getText()

		if text and text ~= "" then
			return text
		end
	end

	return nil
end

local function normalizeMetric(metric)
	metric = tostring(metric or "HP"):upper():gsub("%%", "")

	if metric == "MP" or metric == "MANA" then
		return "MP"
	end

	return "HP"
end

local function metricComboLabel(metric)
	return normalizeMetric(metric) == "MP" and "MP%" or "HP%"
end

local function normalizeConditionLogic(logic)
	logic = tostring(logic or "and"):lower()

	if logic == "or" then
		return "or"
	end

	return "and"
end

function HelperHealer.resolveLoadedSpiritMetric(raw)
	if raw.spiritMetric then
		return normalizeMetric(raw.spiritMetric)
	end

	local cfg = type(raw.spiritConfig) == "table" and raw.spiritConfig or nil

	if cfg then
		if cfg.mpEnabled and not cfg.hpEnabled then
			return "MP"
		end

		return "HP"
	end

	local mode = tostring(raw.spiritMode or ""):lower()

	if mode == "mp" or mode == "mana" then
		return "MP"
	end

	if mode == "hp" or mode == "health" or mode == "both" then
		return "HP"
	end

	return normalizeMetric(raw.whenMetric1 or raw.metric)
end

local HEALING_RANGE_MIN = 1
local HEALING_RANGE_MAX = 99
local HEALING_RANGE_DEFAULT_MIN = 1
local HEALING_RANGE_DEFAULT_MAX = 80
local HEALING_DEFAULT_SPELL_PERCENT = 80
local HEALING_DEFAULT_POTION_PERCENT = 50
local HEALING_PERCENT_STEP = 1
local HEALING_PERCENT_AUTO_PRESS_DELAY = 350

local function clampHealingRange(value, fallback)
	local n = tonumber(value)

	if not n then
		return fallback
	end

	if n < HEALING_RANGE_MIN then
		n = HEALING_RANGE_MIN
	end

	if n > HEALING_RANGE_MAX then
		n = HEALING_RANGE_MAX
	end

	return n
end

local function normalizeCondition(condition)
	condition = tostring(condition or "<")

	if condition:find("<=", 1, true) then
		return "<="
	end

	if condition:find(">=", 1, true) then
		return ">="
	end

	if condition:find(">", 1, true) then
		return ">"
	end

	return "<"
end

local function migrateLegacyEntryFields(raw)
	if raw.whenMetric1 or raw.thresholdMin ~= nil then
		return {
			whenMetric1 = normalizeMetric(raw.whenMetric1 or raw.metric),
			whenMetric2 = normalizeMetric(raw.whenMetric2 or raw.whenMetric1 or raw.metric),
			conditionLogic = normalizeConditionLogic(raw.conditionLogic),
			conditionMin = normalizeCondition(raw.conditionMin or raw.condition),
			thresholdMin = clampHealingRange(raw.thresholdMin, HEALING_RANGE_DEFAULT_MIN),
			conditionMax = normalizeCondition(raw.conditionMax or "<="),
			thresholdMax = clampHealingRange(raw.thresholdMax, raw.threshold or HEALING_RANGE_DEFAULT_MAX)
		}
	end

	local metric = normalizeMetric(raw.metric)
	local cond = normalizeCondition(raw.condition)
	local th = clampHealingRange(raw.threshold, HEALING_RANGE_DEFAULT_MAX)
	local conditionMin, thresholdMin, conditionMax, thresholdMax = ">=", HEALING_RANGE_MIN, "<=", HEALING_RANGE_MAX

	if cond == "<=" then
		conditionMin, thresholdMin, conditionMax, thresholdMax = ">=", HEALING_RANGE_MIN, "<=", th
	elseif cond == "<" then
		conditionMin, thresholdMin, conditionMax, thresholdMax = ">=", HEALING_RANGE_MIN, "<", th
	elseif cond == ">=" then
		conditionMin, thresholdMin, conditionMax, thresholdMax = ">=", th, "<=", HEALING_RANGE_MAX
	else
		conditionMin, thresholdMin, conditionMax, thresholdMax = ">", th, "<=", HEALING_RANGE_MAX
	end

	return {
		whenMetric1 = metric,
		whenMetric2 = metric,
		conditionLogic = normalizeConditionLogic(raw.conditionLogic),
		conditionMin = conditionMin,
		thresholdMin = thresholdMin,
		conditionMax = conditionMax,
		thresholdMax = thresholdMax
	}
end

local function getMetricPercent(state, metric)
	return normalizeMetric(metric) == "MP" and state.manaPercent or state.healthPercent
end

local function getHealingEntryGroup(entry)
	if not entry then
		return "spell"
	end

	if normalizeEntryWords(entry.words) then
		return "spell"
	end

	local itemId = tonumber(entry.itemId)

	if itemId and itemId > 0 then
		return "potion"
	end

	return entry.kind == "potion" and "potion" or "spell"
end

local function getHealingEntryDefaultPercent(entry)
	if getHealingEntryGroup(entry) == "potion" then
		return HEALING_DEFAULT_POTION_PERCENT
	end

	return HEALING_DEFAULT_SPELL_PERCENT
end

local function getHealingEntryMetric(entry)
	if getHealingEntryGroup(entry) == "potion" then
		if entry and entry.itemId and isSpiritPotion(entry.itemId) then
			return normalizeMetric(entry.spiritMetric)
		end

		if entry and entry.itemId and isManaPotion(entry.itemId) then
			return "MP"
		end

		return "HP"
	end

	return "HP"
end

function HelperHealer.getHealingEntryMetricText(entry)
	return getHealingEntryMetric(entry)
end

local function entryConditionPercent(entry, fallback)
	fallback = fallback or getHealingEntryDefaultPercent(entry)

	if entry and entry.percent ~= nil then
		return clampHealingRange(entry.percent, fallback)
	end

	local fields = entry and migrateLegacyEntryFields(entry) or nil

	if fields then
		return clampHealingRange(fields.thresholdMax, fallback)
	end

	return clampHealingRange(fallback, fallback)
end

local function setEntryConditionPercent(entry, percent)
	if not entry then
		return
	end

	percent = clampHealingRange(percent, getHealingEntryDefaultPercent(entry))

	local metric = getHealingEntryMetric(entry)

	entry.percent = percent
	entry.whenMetric1 = metric
	entry.whenMetric2 = metric
	entry.conditionLogic = "and"
	entry.conditionMin = ">="
	entry.thresholdMin = HEALING_RANGE_MIN
	entry.conditionMax = "<="
	entry.thresholdMax = percent
end

local function entryPercentConditionMet(entry, state)
	if not entry or not state then
		return false
	end

	local value = getMetricPercent(state, getHealingEntryMetric(entry))

	return value ~= nil and value <= entryConditionPercent(entry)
end

function HelperHealer.entryMetricPercentConditionMet(entry, state, metric)
	if not entry or not state then
		return false
	end

	local value = getMetricPercent(state, metric)

	return value ~= nil and value <= entryConditionPercent(entry)
end

local function clampThreshold(value)
	local n = tonumber(value)

	if not n then
		return THRESHOLD_DEFAULT
	end

	if n < THRESHOLD_MIN then
		n = THRESHOLD_MIN
	end

	if n > THRESHOLD_MAX then
		n = THRESHOLD_MAX
	end

	return n
end

local function sanitizeThresholdDigits(text)
	return tostring(text or ""):gsub("%D", "")
end

local function readThresholdPercent(thresholdEdit)
	if not thresholdEdit or not thresholdEdit.getText then
		return THRESHOLD_DEFAULT
	end

	local text = thresholdEdit:getText() or ""

	if text == "" then
		return THRESHOLD_DEFAULT
	end

	return clampThreshold(text)
end

local function readHealingRangePercent(thresholdEdit, fallback)
	if not thresholdEdit then
		return fallback
	end

	local option = comboOptionText(thresholdEdit)

	if option and option ~= "" then
		return clampHealingRange(option, fallback)
	end

	if not thresholdEdit.getText then
		return fallback
	end

	local text = thresholdEdit:getText() or ""

	if text == "" then
		return fallback
	end

	return clampHealingRange(text, fallback)
end

local function setHealingRangeWidgetValue(widget, value)
	if not widget then
		return
	end

	value = tostring(clampHealingRange(value, HEALING_RANGE_DEFAULT_MAX))

	if widget.setCurrentOption then
		widget:setCurrentOption(value)
	elseif widget.setText then
		widget:setText(value)
	end
end

function HelperHealer.onThresholdChange(edit)
	if not edit then
		return
	end

	local text = edit:getText() or ""
	local digits = sanitizeThresholdDigits(text)

	if digits == "" then
		if text ~= "" then
			edit:setText("")
		end

		saveConfigIfReady()

		return
	end

	local n = tonumber(digits)

	if n == 0 then
		edit:setText(tostring(THRESHOLD_MIN))
		saveConfigIfReady()

		return
	end

	if n > THRESHOLD_MAX then
		edit:setText(tostring(THRESHOLD_MAX))
		saveConfigIfReady()

		return
	end

	if digits ~= text then
		edit:setText(digits)

		return
	end

	saveConfigIfReady()
end

function HelperHealer.onThresholdFocusChange(edit, focused)
	if focused or not edit then
		return
	end

	local text = edit:getText() or ""

	if text == "" then
		edit:setText(tostring(THRESHOLD_DEFAULT))
		saveConfigIfReady()

		return
	end

	local clamped = clampThreshold(text)

	if tostring(clamped) ~= text then
		edit:setText(tostring(clamped))
		saveConfigIfReady()
	end
end

local function copyActionDataFromSlot(slot)
	if not slot then
		return nil
	end

	return {
		words = slot.words,
		itemId = slot.itemId,
		subType = slot.subType,
		useType = slot.useType,
		parameter = slot.parameter
	}
end

local function entryHasAction(entry)
	if not entry then
		return false
	end

	local words = normalizeEntryWords(entry.words)

	if words then
		return true
	end

	local itemId = tonumber(entry.itemId)

	return itemId and itemId > 0 and entry.useType ~= nil and entry.useType ~= ""
end

local function slotHasAssignedAction(slot)
	return entryHasAction(copyActionDataFromSlot(slot))
end

local function canExecuteEntryAction(entry, state)
	if not entryHasAction(entry) then
		return false
	end

	local words = normalizeEntryWords(entry.words)

	if words then
		if isHelperSpellOnCooldown(words) then
			return false
		end

		local player = state and state.player or g_game.getLocalPlayer()

		return canPlayerCastHealingSpell(words, player)
	end

	local player = state and state.player or g_game.getLocalPlayer()

	if not player then
		return false
	end

	if isBlockedHealingPotionId(entry.itemId) or isHealingFoodEntry(entry) then
		return false
	end

	if not playerHasItem(player, entry.itemId, entry) then
		return false
	end

	return not isPotionUseBlocked()
end

local function canExecuteSlotAction(slot, state)
	return canExecuteEntryAction(copyActionDataFromSlot(slot), state)
end

local function castHealingSpell(slot)
	if not slot or not slot.words or slot.words == "" then
		return false
	end

	if isHelperSpellOnCooldown(slot.words) then
		return false
	end

	local text = slot.words

	if slot.parameter and slot.parameter ~= "" then
		text = string.format("%s \"%s\"", slot.words, slot.parameter)
	end

	g_game.talk(text)

	local spell = Spells.getSpellByWords(slot.words)

	applyLocalHealingCastLock(spell)

	return true
end

local function useHealingPotion(slot, state)
	local player = state and state.player or g_game.getLocalPlayer()
	local itemId = tonumber(slot and slot.itemId)

	if not player or not itemId or itemId <= 0 or isBlockedHealingPotionId(itemId) then
		return false
	end

	if isPotionUseBlocked() or not playerHasItem(player, itemId, slot) then
		return false
	end

	g_game.useInventoryItemWith(itemId, player)

	helperCooldowns.spells[POTION_TIMER_KEY] = g_clock.millis() + POTION_EXHAUST_MS

	return true
end

local function findEntryById(entryId)
	for _, entry in ipairs(healingEntries) do
		if entry.id == entryId then
			return entry
		end
	end

	return nil
end

local function findHealingEntryIndexById(entryId)
	for i, entry in ipairs(healingEntries) do
		if entry.id == entryId then
			return i, entry
		end
	end

	return nil
end

local function focusHealingRowByEntryId(entryId)
	resetHealingRowFocusColors()

	local targetRow = findHealingRowByEntryId(entryId)

	if not targetRow then
		return
	end

	focusHealingPanelRow(targetRow)
	syncHealingActionButtons()
end

local function removeHealingEntryById(entryId)
	local i = findHealingEntryIndexById(entryId)

	if not i then
		return false
	end

	table.remove(healingEntries, i)

	return true
end

local function reorderHealingEntryByDrop(sourceId, targetId, afterTarget, targetGroup)
	local sourceIndex, sourceEntry = findHealingEntryIndexById(sourceId)

	if not sourceEntry then
		return false
	end

	local group = getHealingEntryGroup(sourceEntry)

	if targetGroup and group ~= targetGroup then
		return false
	end

	local targetIndex

	if targetId then
		if sourceId == targetId then
			return false
		end

		local targetEntry

		targetIndex, targetEntry = findHealingEntryIndexById(targetId)

		if not targetEntry or getHealingEntryGroup(targetEntry) ~= group then
			return false
		end
	end

	table.remove(healingEntries, sourceIndex)

	if targetIndex then
		if sourceIndex < targetIndex then
			targetIndex = targetIndex - 1
		end

		table.insert(healingEntries, targetIndex + (afterTarget and 1 or 0), sourceEntry)

		return true
	end

	for i = #healingEntries, 1, -1 do
		if getHealingEntryGroup(healingEntries[i]) == group then
			table.insert(healingEntries, i + 1, sourceEntry)

			return true
		end
	end

	table.insert(healingEntries, sourceEntry)

	return true
end

local function saveHealingConfig()
	if ctx and ctx.saveConfig then
		saveConfigIfReady()
	end
end

local function cancelHealingPercentSave()
	if healingPercentSaveEvent then
		removeEvent(healingPercentSaveEvent)

		healingPercentSaveEvent = nil
	end
end

local function flushHealingPercentSave()
	local hadPendingSave = healingPercentSaveEvent ~= nil

	cancelHealingPercentSave()

	if hadPendingSave then
		saveHealingConfig()
	end
end

local function scheduleHealingPercentSave()
	cancelHealingPercentSave()

	healingPercentSaveEvent = scheduleEvent(function()
		healingPercentSaveEvent = nil

		saveHealingConfig()
	end, 250)
end

local function copyEntryForSave(entry)
	local percent = entryConditionPercent(entry)
	local metric = getHealingEntryMetric(entry)
	local var_143_0 = {
		conditionMax = "<=",
		conditionMin = ">=",
		conditionLogic = "and",
		id = entry.id,
		kind = getHealingEntryGroup(entry),
		enabled = entry.enabled ~= false,
		percent = percent,
		spiritMetric = isSpiritPotion(entry.itemId) and metric or nil,
		whenMetric1 = metric,
		whenMetric2 = metric,
		thresholdMin = HEALING_RANGE_MIN,
		thresholdMax = percent,
		words = normalizeEntryWords(entry.words)
	}

	if isBlockedHealingPotionId(entry.itemId) then
		-- block empty
	end

	var_143_0.itemId = entry.itemId
	var_143_0.subType = entry.subType

	if isHealingFoodEntry(entry) then
		-- block empty
	end

	var_143_0.useType = entry.useType
	var_143_0.parameter = entry.parameter

	local copy = var_143_0

	return copy
end

function HelperHealer.copyLegacyHealingSlot(savedEntry)
	if not savedEntry then
		return nil
	end

	local metric = savedEntry.whenMetric1 or savedEntry.whenMetric2 or savedEntry.metric or "HP"
	local percent = savedEntry.percent or savedEntry.thresholdMax or savedEntry.threshold or HEALING_RANGE_DEFAULT_MAX

	return {
		condition = "<=",
		enabled = savedEntry.enabled ~= false,
		metric = metric,
		whenMetric1 = savedEntry.whenMetric1 or metric,
		whenMetric2 = savedEntry.whenMetric2 or metric,
		conditionLogic = savedEntry.conditionLogic or "and",
		conditionMin = savedEntry.conditionMin or ">=",
		thresholdMin = savedEntry.thresholdMin or HEALING_RANGE_MIN,
		conditionMax = savedEntry.conditionMax or "<=",
		thresholdMax = savedEntry.thresholdMax or percent,
		threshold = percent,
		words = savedEntry.words,
		itemId = savedEntry.itemId,
		subType = savedEntry.subType,
		useType = savedEntry.useType,
		parameter = savedEntry.parameter,
		spiritMetric = savedEntry.spiritMetric
	}
end

local function normalizeLoadedEntry(raw, fallbackId)
	if type(raw) ~= "table" then
		return nil
	end

	if isHealingFoodEntry(raw) then
		return nil
	end

	if not entryHasAction(raw) then
		return nil
	end

	local fields = migrateLegacyEntryFields(raw)
	local kind = raw.kind == "potion" and "potion" or normalizeEntryWords(raw.words) and "spell" or "potion"
	local rawItemId = tonumber(raw.itemId)

	if isBlockedHealingPotionId(rawItemId) then
		-- block empty
	end

	local itemId = rawItemId
	local entry = {
		id = tonumber(raw.id) or fallbackId,
		kind = kind,
		enabled = raw.enabled ~= false,
		whenMetric1 = fields.whenMetric1,
		whenMetric2 = fields.whenMetric2,
		conditionLogic = fields.conditionLogic,
		conditionMin = fields.conditionMin,
		thresholdMin = fields.thresholdMin,
		conditionMax = fields.conditionMax,
		thresholdMax = fields.thresholdMax,
		percent = clampHealingRange(raw.percent or fields.thresholdMax, kind == "potion" and HEALING_DEFAULT_POTION_PERCENT or HEALING_DEFAULT_SPELL_PERCENT),
		words = normalizeEntryWords(raw.words),
		itemId = itemId,
		subType = raw.subType,
		useType = raw.useType,
		parameter = raw.parameter
	}

	if isSpiritPotion(entry.itemId) then
		entry.spiritMetric = HelperHealer.resolveLoadedSpiritMetric(raw)
	end

	setEntryConditionPercent(entry, entry.percent)

	return entry
end

local function formatHealingValueText(entry)
	local words = normalizeEntryWords(entry.words)

	if words then
		return words
	end

	if entry.itemId and entry.itemId > 0 then
		local thing = g_things.getThingType(entry.itemId, ThingCategoryItem)

		if thing then
			return thingDisplayName(thing, entry.itemId)
		end

		return tostring(entry.itemId)
	end

	return ""
end

local function clearHealingEntryAction(entry)
	if not entry then
		return
	end

	entry.words = nil
	entry.itemId = nil
	entry.spiritMetric = nil
	entry.subType = nil
	entry.useType = nil
	entry.parameter = nil
end

local function copySlotActionToEntry(entry, slot)
	if not entry or not slot then
		return
	end

	local action = copyActionDataFromSlot(slot)
	local previousSpiritMetric = entry.spiritMetric

	clearHealingEntryAction(entry)

	local words = normalizeEntryWords(action.words)

	if words then
		entry.kind = "spell"
		entry.words = words
		entry.itemId = action.itemId or ACTION_SLOT_SPELL_ITEM_ID
		entry.parameter = action.parameter
	else
		local actionItemId = tonumber(action.itemId)

		if not actionItemId or actionItemId <= 0 then
			return
		end

		entry.kind = "potion"
		entry.itemId = actionItemId
		entry.subType = action.subType
		entry.useType = action.useType or "useOnSelf"

		if isSpiritPotion(actionItemId) then
			entry.spiritMetric = normalizeMetric(previousSpiritMetric or "HP")
		end
	end

	setEntryConditionPercent(entry, entryConditionPercent(entry))
end

local function formatHealingConditionMetricText(entry)
	return string.format("%s%%", HelperHealer.getHealingEntryMetricText(entry))
end

local function updateHealingPercentStepper(row, entry)
	local stepper = row and row:recursiveGetChildById("healingConditionPercentStepper") or nil

	if not stepper then
		return
	end

	stepper:show()

	local percent = entryConditionPercent(entry)
	local valueLabel = stepper:recursiveGetChildById("numberValue")

	if valueLabel then
		valueLabel:setText(tostring(percent))
	end

	local decButton = stepper:recursiveGetChildById("btnDec")

	if decButton then
		decButton:setEnabled(percent > HEALING_RANGE_MIN)
	end

	local incButton = stepper:recursiveGetChildById("btnInc")

	if incButton then
		incButton:setEnabled(percent < HEALING_RANGE_MAX)
	end
end

function HelperHealer.updateHealingConditionMetricLabel(row, entry)
	local metricLabel = row and row:recursiveGetChildById("healingConditionMetricLabel") or nil

	if not metricLabel then
		return
	end

	metricLabel:setText(formatHealingConditionMetricText(entry))
	metricLabel:setTooltip("")
end

function HelperHealer.healingMetricDropdownText(metric)
	return normalizeMetric(metric) == "MP" and "MP%" or "HP%"
end

function HelperHealer.setHealingMetricDropdownOption(dropdown, metric)
	if not dropdown or dropdown:isDestroyed() then
		return
	end

	local text = HelperHealer.healingMetricDropdownText(metric)

	dropdown.currentMetric = normalizeMetric(metric)

	dropdown:setTooltip(text)

	local label = dropdown:recursiveGetChildById("metricText")

	if label then
		label:setText(text)
	end
end

function HelperHealer.openHealingMetricDropdown(row, dropdown)
	if not row or not dropdown or dropdown:isDestroyed() then
		return true
	end

	local entryId = row.healingEntryId
	local entry = findEntryById(entryId)

	if not entry or not isSpiritPotion(entry.itemId) then
		return true
	end

	focusHealingPanelRow(row)

	local function applyMetric(metric)
		local current = findEntryById(entryId)

		if not current or not isSpiritPotion(current.itemId) then
			return
		end

		current.spiritMetric = normalizeMetric(metric)

		setEntryConditionPercent(current, entryConditionPercent(current))
		HelperHealer.setHealingMetricDropdownOption(dropdown, current.spiritMetric)
		saveHealingConfig()
	end

	local menu = g_ui.createWidget("GamePopupMenu")

	menu:addOption("HP%", function()
		applyMetric("HP")
	end, nil, false, {
		minWidth = 44
	})
	menu:addOption("MP%", function()
		applyMetric("MP")
	end, nil, false, {
		minWidth = 44
	})
	menu:setWidth(44)
	menu:display({
		x = dropdown:getX(),
		y = dropdown:getY() + dropdown:getHeight()
	})

	return true
end

function HelperHealer.updateHealingConditionMetricSelector(row, entry)
	if not row or not entry then
		return
	end

	local metricLabel = row:recursiveGetChildById("healingConditionMetricLabel")
	local metricCombo = row:recursiveGetChildById("healingConditionMetricCombo")

	if isSpiritPotion(entry.itemId) then
		if metricLabel then
			metricLabel:hide()
		end

		if metricCombo then
			metricCombo:show()
			HelperHealer.setHealingMetricDropdownOption(metricCombo, getHealingEntryMetric(entry))
		end
	else
		if metricCombo then
			metricCombo:hide()
		end

		if metricLabel then
			metricLabel:show()
		end

		HelperHealer.updateHealingConditionMetricLabel(row, entry)
	end
end

function HelperHealer.elideHealingLabel(label, text)
	if not label or label:isDestroyed() then
		return
	end

	text = text or ""

	label:setText(text)

	local budget = label:getWidth()

	if not budget or budget < 40 then
		budget = 114
	end

	if budget >= label:getTextSize().width then
		return
	end

	local dots = "..."
	local lo, hi, best = 0, #text, dots

	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local candidate = text:sub(1, mid) .. dots

		label:setText(candidate)

		if budget >= label:getTextSize().width then
			best = candidate
			lo = mid + 1
		else
			hi = mid - 1
		end
	end

	label:setText(best)
end

local function updateHealingConditionRow(row, entry)
	if not row or not entry then
		return
	end

	local enabledCheck = row:recursiveGetChildById("healingConditionEnabled")

	if enabledCheck then
		local onCheckChange = enabledCheck.onCheckChange

		enabledCheck.onCheckChange = nil

		enabledCheck:setChecked(entry.enabled ~= false)

		enabledCheck.onCheckChange = onCheckChange
	end

	local nameLabel = row:recursiveGetChildById("healingConditionName")

	if nameLabel then
		local name = formatHealingValueText(entry)

		if name == "" then
			name = getHealingEntryGroup(entry) == "potion" and tr("Select Potion") or tr("Select Spell")
		end

		nameLabel:setTooltip(name)
		HelperHealer.elideHealingLabel(nameLabel, name)
	end

	HelperHealer.updateHealingConditionMetricSelector(row, entry)
	updateHealingPercentStepper(row, entry)

	local slot = row:recursiveGetChildById("healingConditionActionSlot")

	if slot then
		if entryHasAction(entry) and restoreSlotData then
			restoreSlotData(slot, entry)
		else
			clearSlotData(slot)
		end

		local gray = slot:getChildById("gray")

		if gray then
			gray:setVisible(shouldShowHealingRowGray(entry))
		end

		syncHealingActionSlotLayers(slot)
	end
end

function HelperHealer.destroyHealingEntryDragGhost()
	if HelperHealer.healingEntryDragGhost and not HelperHealer.healingEntryDragGhost:isDestroyed() then
		HelperHealer.healingEntryDragGhost:destroy()
	end

	HelperHealer.healingEntryDragGhost = nil
end

function HelperHealer.updateHealingEntryDragGhostPosition(mousePos)
	if not HelperHealer.healingEntryDragGhost or HelperHealer.healingEntryDragGhost:isDestroyed() or not mousePos then
		return
	end

	local size = HelperHealer.healingEntryDragGhost:getSize()
	local width = size and size.width or 180
	local height = size and size.height or 42

	HelperHealer.healingEntryDragGhost:setPosition({
		x = mousePos.x - math.floor(width / 2),
		y = mousePos.y - math.floor(height / 2)
	})
	HelperHealer.healingEntryDragGhost:raise()
end

function HelperHealer.ensureHealingEntryDragGhost(row)
	if HelperHealer.healingEntryDragGhost and not HelperHealer.healingEntryDragGhost:isDestroyed() then
		return HelperHealer.healingEntryDragGhost
	end

	local root = g_ui.getRootWidget()

	if not root then
		return nil
	end

	HelperHealer.healingEntryDragGhost = g_ui.createWidget("HealingConditionDragGhost", root)

	HelperHealer.healingEntryDragGhost:setId("healingConditionDragGhost")
	HelperHealer.healingEntryDragGhost:setPhantom(true)
	HelperHealer.healingEntryDragGhost:setFocusable(false)
	HelperHealer.healingEntryDragGhost:setDraggable(false)
	HelperHealer.healingEntryDragGhost:setVisible(false)

	if row and row.getWidth then
		HelperHealer.healingEntryDragGhost:setWidth(math.max(160, row:getWidth()))
	end

	return HelperHealer.healingEntryDragGhost
end

function HelperHealer.updateHealingEntryDragGhost(row, entry, mousePos)
	if not entry then
		return
	end

	local ghost = HelperHealer.ensureHealingEntryDragGhost(row)

	if not ghost then
		return
	end

	local nameLabel = ghost:recursiveGetChildById("dragGhostName")

	if nameLabel then
		nameLabel:setText(formatHealingValueText(entry))
	end

	local conditionLabel = ghost:recursiveGetChildById("dragGhostCondition")

	if conditionLabel then
		conditionLabel:setText(string.format("%s %d", formatHealingConditionMetricText(entry), entryConditionPercent(entry)))
	end

	local slot = ghost:recursiveGetChildById("dragGhostActionSlot")

	if slot then
		if entryHasAction(entry) and restoreSlotData then
			restoreSlotData(slot, entry)
		else
			clearSlotData(slot)
		end

		syncHealingActionSlotLayers(slot)
	end

	ghost:setVisible(true)
	HelperHealer.updateHealingEntryDragGhostPosition(mousePos or g_window.getMousePosition())
end

function HelperHealer.setHealingEntryDragSourceVisual(row, dragging)
	if not row or row:isDestroyed() then
		return
	end

	if dragging then
		row:setOpacity(0.45)
		row:setBackgroundColor("#6a6a6a")
		setHealingRowTextColors(row, ZEBRA_FOCUS_TEXT_COLOR)

		return
	end

	row:setOpacity(1)

	if row.zebraColor then
		row:setBackgroundColor(row.zebraColor)
		setHealingRowTextColors(row, ZEBRA_TEXT_COLOR)
	end
end

local function applyHealingEntryPercent(row, entry, delta, saveAfter)
	if not row or not entry then
		return
	end

	setEntryConditionPercent(entry, entryConditionPercent(entry) + delta)
	updateHealingPercentStepper(row, entry)

	if saveAfter ~= false then
		saveHealingConfig()
	else
		scheduleHealingPercentSave()
	end
end

local function bindHealingPercentButton(button, row, entry, delta)
	if not button then
		return
	end

	if g_mouse and g_mouse.bindAutoPress then
		g_mouse.bindAutoPress(button, function()
			applyHealingEntryPercent(row, entry, delta, false)
		end, HEALING_PERCENT_AUTO_PRESS_DELAY)
	else
		function button.onClick()
			applyHealingEntryPercent(row, entry, delta, false)
		end
	end

	function button.onMouseRelease(_, _, mouseButton)
		if mouseButton == MouseLeftButton then
			flushHealingPercentSave()

			return false
		end

		return false
	end
end

local function finishHealingEntryDrop(entryId)
	saveHealingConfig()
	addEvent(function()
		refreshHealingListUI()
		focusHealingRowByEntryId(entryId)
	end)
end

local function dropHealingEntryOnRow(targetRow, draggedWidget, mousePos, forcedAfterTarget)
	if not targetRow or not draggedWidget or not draggedWidget.healingEntryId or not targetRow.healingEntryId then
		return false
	end

	if draggedWidget.healingEntryKind ~= targetRow.healingEntryKind then
		return false
	end

	local afterTarget = forcedAfterTarget

	if afterTarget == nil then
		afterTarget = mousePos and mousePos.y >= targetRow:getY() + targetRow:getHeight() / 2
	end

	if reorderHealingEntryByDrop(draggedWidget.healingEntryId, targetRow.healingEntryId, afterTarget, targetRow.healingEntryKind) then
		finishHealingEntryDrop(draggedWidget.healingEntryId)

		return true
	end

	return false
end

local function dropHealingEntryOnPanel(panel, draggedWidget)
	if not panel or not draggedWidget or not draggedWidget.healingEntryId then
		return false
	end

	if draggedWidget.healingEntryKind ~= panel.healingEntryKind then
		return false
	end

	if reorderHealingEntryByDrop(draggedWidget.healingEntryId, nil, false, panel.healingEntryKind) then
		finishHealingEntryDrop(draggedWidget.healingEntryId)

		return true
	end

	return false
end

function HelperHealer.isMouseInsideHealingDropPanel(panel, mousePos)
	if not panel or panel:isDestroyed() or not mousePos then
		return false
	end

	if panel.containsPaddingPoint then
		return panel:containsPaddingPoint(mousePos)
	end

	return mousePos.x >= panel:getX() and mousePos.x <= panel:getX() + panel:getWidth() and mousePos.y >= panel:getY() and mousePos.y <= panel:getY() + panel:getHeight()
end

function HelperHealer.getHealingDropPanel(draggedWidget, mousePos)
	if not draggedWidget or not draggedWidget.healingEntryKind then
		return nil
	end

	local sourceRow = findHealingRowByEntryId(draggedWidget.healingEntryId) or draggedWidget
	local panel = sourceRow and sourceRow:getParent() or nil

	if panel and panel.healingEntryKind == draggedWidget.healingEntryKind and HelperHealer.isMouseInsideHealingDropPanel(panel, mousePos) then
		return panel
	end

	panel = draggedWidget.healingEntryKind == "potion" and healingPotionEntriesPanel or healingSpellEntriesPanel

	if panel and panel.healingEntryKind == draggedWidget.healingEntryKind and HelperHealer.isMouseInsideHealingDropPanel(panel, mousePos) then
		return panel
	end

	if healingEntriesPanel and HelperHealer.isMouseInsideHealingDropPanel(healingEntriesPanel, mousePos) then
		return healingEntriesPanel
	end

	return nil
end

function HelperHealer.resolveHealingDropTarget(draggedWidget, mousePos)
	local panel = HelperHealer.getHealingDropPanel(draggedWidget, mousePos)

	if not panel then
		return nil, nil, nil
	end

	local lastRow

	for _, row in ipairs(panel:getChildren()) do
		if row:isVisible() and row.healingEntryKind == draggedWidget.healingEntryKind then
			lastRow = row

			if mousePos.y < row:getY() + row:getHeight() / 2 then
				return panel, row, false
			end
		end
	end

	if lastRow then
		return panel, lastRow, true
	end

	return panel, nil, false
end

function HelperHealer.dropHealingEntryAtMouse(fallbackRow, draggedWidget, mousePos)
	if not draggedWidget or not draggedWidget.healingEntryId then
		return false
	end

	local panel, targetRow, afterTarget = HelperHealer.resolveHealingDropTarget(draggedWidget, mousePos)

	if targetRow then
		return dropHealingEntryOnRow(targetRow, draggedWidget, mousePos, afterTarget)
	end

	if panel then
		return dropHealingEntryOnPanel(panel, draggedWidget)
	end

	if fallbackRow then
		return dropHealingEntryOnRow(fallbackRow, draggedWidget, mousePos)
	end

	return false
end

function HelperHealer.bindHealingRowDropForwarder(widget, row)
	if not widget then
		return
	end

	local previousOnDrop = widget.onDrop

	function widget:onDrop(draggedWidget, mousePos)
		if draggedWidget and draggedWidget.healingEntryId then
			return HelperHealer.dropHealingEntryAtMouse(row, draggedWidget, mousePos)
		end

		if previousOnDrop then
			return previousOnDrop(self, draggedWidget, mousePos)
		end

		return false
	end
end

function HelperHealer.queueHealingRowContextMenu(row)
	if not row or row:isDestroyed() then
		return true
	end

	if row._healingContextMenuQueued then
		return true
	end

	row._healingContextMenuQueued = true

	scheduleEvent(function()
		if row and not row:isDestroyed() then
			row._healingContextMenuQueued = nil

			openHealingRowContextMenu(row)
		end
	end, 60)

	return true
end

function HelperHealer.bindHealingRowContextForwarder(widget, row)
	if not widget then
		return
	end

	local previousOnMousePress = widget.onMousePress

	function widget:onMousePress(mousePos, mouseButton)
		if mouseButton == MouseRightButton and row and not row:isDestroyed() then
			return HelperHealer.queueHealingRowContextMenu(row)
		end

		if previousOnMousePress then
			return previousOnMousePress(self, mousePos, mouseButton)
		end

		return false
	end

	local previousOnMouseRelease = widget.onMouseRelease

	function widget:onMouseRelease(mousePos, mouseButton)
		if mouseButton == MouseRightButton and row and not row:isDestroyed() then
			return HelperHealer.queueHealingRowContextMenu(row)
		end

		if previousOnMouseRelease then
			return previousOnMouseRelease(self, mousePos, mouseButton)
		end

		return false
	end
end

function HelperHealer.bindHealingSlotChildContextForwarders(slot, row)
	if not slot then
		return
	end

	local function bindChild(child)
		if child and child ~= slot then
			HelperHealer.bindHealingRowContextForwarder(child, row)
		end
	end

	if slot.getChildren then
		for _, child in ipairs(slot:getChildren()) do
			bindChild(child)

			if child.getChildren then
				for _, nestedChild in ipairs(child:getChildren()) do
					bindChild(nestedChild)
				end
			end
		end

		return
	end

	for _, childId in ipairs({
		"count",
		"tier",
		"spellIcon",
		"gray",
		"key",
		"text",
		"spellParameter",
		"multiIcon",
		"equipmentTypeIcon",
		"activeSpell",
		"healingActionItemBackground",
		"healingActionItemIcon"
	}) do
		bindChild(slot:getChildById(childId))
	end
end

local function bindHealingPanelDropTarget(panel, group)
	if not panel then
		return
	end

	panel.healingEntryKind = group

	function panel.onDrop(_, draggedWidget, mousePos)
		return HelperHealer.dropHealingEntryAtMouse(nil, draggedWidget, mousePos)
	end
end

local function bindHealingConditionSlot(slot, entry)
	if not slot or not entry then
		return
	end

	slot._helperHealingSlot = true
	slot._helperAssignPreview = true
	slot._helperAssignSkipSave = true
	slot.healingEntryId = entry.id
	slot.healingEntryKind = getHealingEntryGroup(entry)

	function slot.onHelperPotionAssigned(assignedSlot)
		local current = findEntryById(assignedSlot.healingEntryId)

		if not current then
			return
		end

		current.kind = "potion"
		current.pendingAdd = nil

		copySlotActionToEntry(current, assignedSlot)
		refreshHealingListUI()
		focusHealingRowByEntryId(current.id)
		saveHealingConfig()
	end

	function slot:onMousePress(_, mouseButton)
		if mouseButton == MouseRightButton then
			local row = findParentHealingRow(self)

			if row then
				return HelperHealer.queueHealingRowContextMenu(row)
			end
		end

		if mouseButton == MouseLeftButton then
			return true
		end

		return false
	end

	function slot:onMouseRelease(_, mouseButton)
		if mouseButton == MouseLeftButton then
			openHealingEntryActionAssign(self)

			return true
		end

		if mouseButton == MouseRightButton then
			local row = findParentHealingRow(self)

			if row then
				return HelperHealer.queueHealingRowContextMenu(row)
			end
		end

		return false
	end

	if not slotHasHelperPotion(slot) then
		local ab = actionbar()

		if ab and ab.refreshActionSlotFrameClip then
			ab.refreshActionSlotFrameClip(slot)
		end
	end

	syncHealingActionSlotLayers(slot)
end

local function bindHealingConditionRow(row, entry)
	if not row or not entry then
		return
	end

	row.healingEntryId = entry.id
	row.healingEntryKind = getHealingEntryGroup(entry)

	if row.setDraggable then
		row:setDraggable(true)
	end

	local enabledCheck = row:recursiveGetChildById("healingConditionEnabled")

	if enabledCheck then
		function enabledCheck.onCheckChange(_, checked)
			entry.enabled = checked

			saveHealingConfig()
		end

		HelperHealer.bindHealingRowDropForwarder(enabledCheck, row)
		HelperHealer.bindHealingRowContextForwarder(enabledCheck, row)
	end

	local slot = row:recursiveGetChildById("healingConditionActionSlot")

	bindHealingConditionSlot(slot, entry)
	HelperHealer.bindHealingRowDropForwarder(slot, row)
	HelperHealer.bindHealingRowContextForwarder(slot, row)
	HelperHealer.bindHealingSlotChildContextForwarders(slot, row)

	local stepper = row:recursiveGetChildById("healingConditionPercentStepper")

	if stepper then
		HelperHealer.bindHealingRowDropForwarder(stepper, row)
		HelperHealer.bindHealingRowContextForwarder(stepper, row)

		local decButton = stepper:recursiveGetChildById("btnDec")

		bindHealingPercentButton(decButton, row, entry, -HEALING_PERCENT_STEP)
		HelperHealer.bindHealingRowDropForwarder(decButton, row)

		local numberBox = stepper:recursiveGetChildById("numberBox")

		HelperHealer.bindHealingRowDropForwarder(numberBox, row)

		local incButton = stepper:recursiveGetChildById("btnInc")

		bindHealingPercentButton(incButton, row, entry, HEALING_PERCENT_STEP)
		HelperHealer.bindHealingRowDropForwarder(incButton, row)
	end

	local metricCombo = row:recursiveGetChildById("healingConditionMetricCombo")

	if metricCombo then
		function metricCombo:onMousePress(_, mouseButton)
			if mouseButton == MouseLeftButton then
				return HelperHealer.openHealingMetricDropdown(row, self)
			end

			if mouseButton == MouseRightButton then
				return HelperHealer.queueHealingRowContextMenu(row)
			end

			return false
		end

		HelperHealer.bindHealingRowDropForwarder(metricCombo, row)
	end

	local removeButton = row:recursiveGetChildById("healingConditionRemoveButton")

	if removeButton then
		HelperHealer.bindHealingRowDropForwarder(removeButton, row)
		HelperHealer.bindHealingRowContextForwarder(removeButton, row)

		function removeButton.onClick()
			if removeHealingEntryById(entry.id) then
				refreshHealingListUI()
				clearHealingListSelection()
				saveHealingConfig()
			end
		end
	end

	connectZebraFocus(row)

	function row:onMousePress(_, mouseButton)
		if mouseButton == MouseRightButton then
			return HelperHealer.queueHealingRowContextMenu(self)
		end

		return false
	end

	function row:onDragEnter(mousePos)
		HelperHealer.updateHealingEntryDragGhost(self, findEntryById(self.healingEntryId) or entry, mousePos)
		HelperHealer.setHealingEntryDragSourceVisual(self, true)

		return true
	end

	function row.onDragMove(_, mousePos)
		HelperHealer.updateHealingEntryDragGhostPosition(mousePos)

		return true
	end

	function row:onDragLeave()
		HelperHealer.destroyHealingEntryDragGhost()

		if self:isDestroyed() then
			return true
		end

		HelperHealer.setHealingEntryDragSourceVisual(self, false)

		return true
	end

	function row:onDrop(draggedWidget, mousePos)
		return HelperHealer.dropHealingEntryAtMouse(self, draggedWidget, mousePos)
	end

	function row:onMouseRelease(_, mouseButton)
		if mouseButton == MouseRightButton then
			return HelperHealer.queueHealingRowContextMenu(self)
		end

		return false
	end
end

function openHealingEntryActionAssign(slot)
	if not slot then
		return
	end

	local entry = findEntryById(slot.healingEntryId)

	if not entry then
		return
	end

	if getHealingEntryGroup(entry) == "potion" then
		HelperHealer.openPotionSelectWindow(slot)

		return
	end

	openHelperSpellAssign(slot, isHelperHealingSpell, function(assignedSlot)
		local current = findEntryById(slot.healingEntryId)

		if not current then
			return
		end

		current.kind = "spell"
		current.pendingAdd = nil

		copySlotActionToEntry(current, assignedSlot or slot)
		refreshHealingListUI()
		focusHealingRowByEntryId(current.id)
		saveHealingConfig()
	end)
end

function refreshHealingListUI()
	ensureHealingEntries()
	resolveHealingEntryPanels()

	if not healingSpellEntriesPanel and not healingPotionEntriesPanel and not healingEntriesPanel then
		return
	end

	bindHealingPanelDropTarget(healingSpellEntriesPanel, "spell")
	bindHealingPanelDropTarget(healingPotionEntriesPanel, "potion")

	if healingSpellEntriesPanel and not healingSpellEntriesPanel:isDestroyed() then
		healingSpellEntriesPanel:destroyChildren()
	end

	if healingPotionEntriesPanel and not healingPotionEntriesPanel:isDestroyed() then
		healingPotionEntriesPanel:destroyChildren()
	end

	if healingEntriesPanel and not healingEntriesPanel:isDestroyed() then
		healingEntriesPanel:destroyChildren()
	end

	for idx, entry in ipairs(healingEntries) do
		local group = getHealingEntryGroup(entry)
		local parentPanel = group == "potion" and healingPotionEntriesPanel or healingSpellEntriesPanel

		parentPanel = parentPanel or healingEntriesPanel

		if not parentPanel or parentPanel:isDestroyed() then
			return
		end

		local row = g_ui.createWidget("HealingConditionRow", parentPanel)
		local zebraColor = idx % 2 == 1 and ZEBRA_COLOR_A or ZEBRA_COLOR_B

		row.zebraColor = zebraColor

		row:setBackgroundColor(zebraColor)
		bindHealingConditionRow(row, entry)
		updateHealingConditionRow(row, entry)
	end

	syncHealingActionButtons()
end

local function migrateHealingConfig(config)
	config = config or {}
	healingEntries = {}
	nextHealingEntryId = 1

	if type(config.healingEntries) == "table" then
		for i, raw in ipairs(config.healingEntries) do
			local entry = normalizeLoadedEntry(raw, i)

			if entry then
				table.insert(healingEntries, entry)

				if entry.id >= nextHealingEntryId then
					nextHealingEntryId = entry.id + 1
				end
			end
		end
	end

	if #healingEntries == 0 then
		local legacy = config.healingSlots

		if type(legacy) == "table" then
			for i, slot in ipairs(legacy) do
				local entry = normalizeLoadedEntry({
					id = i,
					enabled = slot.enabled ~= false,
					whenMetric1 = slot.metric or slot.whenMetric1,
					whenMetric2 = slot.whenMetric2 or slot.metric,
					conditionLogic = slot.conditionLogic,
					conditionMin = slot.conditionMin,
					thresholdMin = slot.thresholdMin,
					conditionMax = slot.conditionMax,
					thresholdMax = slot.thresholdMax,
					metric = slot.metric,
					condition = slot.condition,
					threshold = slot.threshold,
					words = slot.words,
					itemId = slot.itemId,
					subType = slot.subType,
					useType = slot.useType,
					parameter = slot.parameter,
					spiritMetric = slot.spiritMetric,
					spiritMode = slot.spiritMode,
					spiritConfig = slot.spiritConfig
				}, i)

				if entry then
					table.insert(healingEntries, entry)

					if entry.id >= nextHealingEntryId then
						nextHealingEntryId = entry.id + 1
					end
				end
			end
		end
	end

	for i = #healingEntries, 1, -1 do
		local entry = healingEntries[i]

		if isBlockedHealingPotionId(entry.itemId) or isHealingFoodEntry(entry) then
			entry.itemId = nil
			entry.useType = nil

			if not entryHasAction(entry) then
				table.remove(healingEntries, i)
			end
		end
	end
end

local function executeEntryAction(entry, state)
	if not canExecuteEntryAction(entry, state) then
		return false
	end

	local words = normalizeEntryWords(entry.words)

	if words then
		entry.words = words

		return castHealingSpell(entry)
	end

	local itemId = tonumber(entry.itemId)

	if itemId and itemId > 0 then
		return useHealingPotion(entry, state)
	end

	return false
end

local function executeAssignedSlotAction(slot, state)
	return executeEntryAction(copyActionDataFromSlot(slot), state)
end

function openHealingRowContextMenu(row)
	if not row or not row.healingEntryId then
		return
	end

	local entryId = row.healingEntryId
	local _, entry = findHealingEntryIndexById(entryId)

	if not entry then
		return
	end

	focusHealingPanelRow(row)
	syncHealingActionButtons()

	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setWidth(150)
	menu:addOption(getHealingEntryGroup(entry) == "potion" and tr("Assign Potion") or tr("Assign Spell"), function()
		addEvent(function()
			local targetRow = findHealingRowByEntryId(entryId)
			local slot = targetRow and targetRow:recursiveGetChildById("healingConditionActionSlot") or nil

			if slot and not slot:isDestroyed() then
				openHealingEntryActionAssign(slot)
			end
		end)
	end)
	menu:addOption(tr("Remove"), function()
		if removeHealingEntryById(entryId) then
			refreshHealingListUI()
			clearHealingListSelection()
			saveHealingConfig()
		end
	end)

	if entry.enabled ~= false then
		menu:addOption(tr("Disable"), function()
			entry.enabled = false

			refreshHealingListUI()
			focusHealingRowByEntryId(entryId)
			saveHealingConfig()
		end)
	else
		menu:addOption(tr("Enable"), function()
			entry.enabled = true

			refreshHealingListUI()
			focusHealingRowByEntryId(entryId)
			saveHealingConfig()
		end)
	end

	menu:display()
end

local function openHealingSlotContextMenu(slot)
	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setWidth(220)

	local fromAddModal = addHealingSlot and slot == addHealingSlot

	menu:addOption("Assign Spell", function()
		addEvent(function()
			if slot and not slot:isDestroyed() then
				openHelperSpellAssign(slot, isHelperHealingSpell, fromAddModal and syncAddHealingConfirmButtons or nil)
			end
		end)
	end)
	menu:addOption("Assign Potion", function()
		addEvent(function()
			if slot and not slot:isDestroyed() then
				HelperHealer.openPotionSelectWindow(slot)
			end
		end)
	end)
	menu:addSeparator()
	menu:addOption("Clear Action", function()
		clearSlotData(slot)

		if not fromAddModal and ctx and ctx.saveConfig then
			saveConfigIfReady()
		end

		if fromAddModal then
			syncAddHealingConfirmButtons()
		end
	end)
	menu:display()
end

local function bindAddHealingSlotInput(slot)
	if not slot then
		return
	end

	slot._helperAssignPreview = true

	function slot.onMousePress(_, _, mouseButton)
		if mouseButton == MouseLeftButton then
			return true
		end

		return false
	end

	function slot:onMouseRelease(_, mouseButton)
		if mouseButton == MouseRightButton then
			openHealingSlotContextMenu(self)

			return true
		end

		if mouseButton == MouseLeftButton then
			return true
		end

		return false
	end

	if not slotHasHelperPotion(slot) then
		local ab = actionbar()

		if ab and ab.refreshActionSlotFrameClip then
			ab.refreshActionSlotFrameClip(slot)
		end
	end

	syncHealingActionSlotLayers(slot)
end

function syncAddHealingConfirmButtons()
	if not addHealingWindow or addHealingWindow:isDestroyed() then
		return
	end

	local hasAction = addHealingSlot and slotHasAssignedAction(addHealingSlot)
	local okBtn = addHealingWindow:recursiveGetChildById("addHealingOkButton")
	local applyBtn = addHealingWindow:recursiveGetChildById("addHealingApplyButton")

	if okBtn then
		okBtn:setEnabled(hasAction)
	end

	if applyBtn then
		applyBtn:setEnabled(hasAction)
	end

	bindAddHealingSlotInput(addHealingSlot)
end

local function bindAddHealingSlot()
	if not addHealingWindow or addHealingWindow:isDestroyed() then
		return
	end

	addHealingSlot = addHealingWindow:recursiveGetChildById("addHealingActionSlot")

	if not addHealingSlot then
		return
	end

	bindAddHealingSlotInput(addHealingSlot)
	stackHealingActionSlotLayers(addHealingSlot)
end

local function closeAddHealingWindowInternal()
	if addHealingSlot and not addHealingSlot:isDestroyed() then
		addHealingSlot._helperAssignPreview = nil
		addHealingSlot._helperHealingSlot = nil
	end

	addHealingSlot = nil
	editingHealingEntryId = nil

	if addHealingWindow and not addHealingWindow:isDestroyed() then
		addHealingWindow:destroy()
	end

	addHealingWindow = nil
end

local function findHealingEntryById(entryId)
	for _, entry in ipairs(healingEntries) do
		if entry.id == entryId then
			return entry
		end
	end

	return nil
end

function restoreSlotData(slot, data)
	if not slot or not data then
		return
	end

	clearSlotData(slot)

	slot.words = data.words
	slot.itemId = data.itemId
	slot._helperDisplayItemId = data.itemId
	slot.subType = data.subType
	slot.useType = data.useType
	slot.parameter = data.parameter

	local ab = actionbar()
	local words = normalizeEntryWords(data.words)

	if words then
		slot.words = words

		if slot.setItemId then
			slot:setItemId(ACTION_SLOT_SPELL_ITEM_ID)
		end

		if ab and ab.loadSpell then
			ab.loadSpell(slot)
		end

		refreshSlotVisual(slot)
	elseif data.itemId and data.itemId > 0 then
		if slot.setItemId then
			slot:setItemId(data.itemId)
		end

		if ab and ab.loadObject then
			ab.loadObject(slot)
		end

		refreshSlotVisual(slot)
	end

	if slot == addHealingSlot then
		syncAddHealingConfirmButtons()
	end
end

local function setAddHealingWindowTitle(text)
	if not addHealingWindow or addHealingWindow:isDestroyed() then
		return
	end

	addHealingWindow:setText(text)
end

local function populateAddHealingForm(entry)
	if not addHealingWindow or addHealingWindow:isDestroyed() then
		return
	end

	local whenMetric1Box = addHealingWindow:recursiveGetChildById("addHealingWhenMetric1Combo")
	local conditionLogicBox = addHealingWindow:recursiveGetChildById("addHealingConditionLogicCombo")
	local whenMetric2Box = addHealingWindow:recursiveGetChildById("addHealingWhenMetric2Combo")
	local conditionMinBox = addHealingWindow:recursiveGetChildById("addHealingConditionMinCombo")
	local thresholdMinEdit = addHealingWindow:recursiveGetChildById("addHealingThresholdMinEdit")
	local conditionMaxBox = addHealingWindow:recursiveGetChildById("addHealingConditionMaxCombo")
	local thresholdMaxEdit = addHealingWindow:recursiveGetChildById("addHealingThresholdMaxEdit")
	local fields = entry and migrateLegacyEntryFields(entry) or nil

	if entry and fields then
		setAddHealingWindowTitle(tr("Edit Healing"))

		if whenMetric1Box then
			whenMetric1Box:setCurrentOption(metricComboLabel(fields.whenMetric1))
		end

		if conditionLogicBox then
			conditionLogicBox:setCurrentOption(normalizeConditionLogic(fields.conditionLogic))
		end

		if whenMetric2Box then
			whenMetric2Box:setCurrentOption(metricComboLabel(fields.whenMetric2))
		end

		if conditionMinBox then
			conditionMinBox:setCurrentOption(fields.conditionMin)
		end

		setHealingRangeWidgetValue(thresholdMinEdit, fields.thresholdMin)

		if conditionMaxBox then
			conditionMaxBox:setCurrentOption(fields.conditionMax)
		end

		setHealingRangeWidgetValue(thresholdMaxEdit, fields.thresholdMax)

		if addHealingSlot then
			restoreSlotData(addHealingSlot, entry)
		end
	else
		setAddHealingWindowTitle(tr("Add Healing"))

		if whenMetric1Box then
			whenMetric1Box:setCurrentOption("HP%")
		end

		if conditionLogicBox then
			conditionLogicBox:setCurrentOption("and")
		end

		if whenMetric2Box then
			whenMetric2Box:setCurrentOption("HP%")
		end

		if conditionMinBox then
			conditionMinBox:setCurrentOption(">=")
		end

		setHealingRangeWidgetValue(thresholdMinEdit, HEALING_RANGE_DEFAULT_MIN)

		if conditionMaxBox then
			conditionMaxBox:setCurrentOption("<=")
		end

		setHealingRangeWidgetValue(thresholdMaxEdit, HEALING_RANGE_DEFAULT_MAX)

		if addHealingSlot then
			clearSlotData(addHealingSlot)
		end
	end

	syncAddHealingConfirmButtons()
end

function openHealingFormWindow(entryId)
	if addHealingWindow and not addHealingWindow:isDestroyed() then
		closeAddHealingWindowInternal()
	end

	editingHealingEntryId = entryId
	addHealingWindow = g_ui.loadUI("assign_healing", g_ui.getRootWidget())

	if not addHealingWindow then
		editingHealingEntryId = nil

		return
	end

	if ctx and ctx.applyWidgetLanguage then
		ctx.applyWidgetLanguage(addHealingWindow)
	end

	bindAddHealingSlot()

	local entry = entryId and findHealingEntryById(entryId) or nil

	populateAddHealingForm(entry)
	addHealingWindow:raise()
	addHealingWindow:focus()
end

local function readAddHealingForm()
	if not addHealingWindow or addHealingWindow:isDestroyed() then
		return nil
	end

	local whenMetric1Box = addHealingWindow:recursiveGetChildById("addHealingWhenMetric1Combo")
	local conditionLogicBox = addHealingWindow:recursiveGetChildById("addHealingConditionLogicCombo")
	local whenMetric2Box = addHealingWindow:recursiveGetChildById("addHealingWhenMetric2Combo")
	local conditionMinBox = addHealingWindow:recursiveGetChildById("addHealingConditionMinCombo")
	local thresholdMinEdit = addHealingWindow:recursiveGetChildById("addHealingThresholdMinEdit")
	local conditionMaxBox = addHealingWindow:recursiveGetChildById("addHealingConditionMaxCombo")
	local thresholdMaxEdit = addHealingWindow:recursiveGetChildById("addHealingThresholdMaxEdit")

	if not whenMetric1Box or not conditionLogicBox or not whenMetric2Box or not conditionMinBox or not thresholdMinEdit or not conditionMaxBox or not thresholdMaxEdit or not addHealingSlot then
		return nil
	end

	if not slotHasAssignedAction(addHealingSlot) then
		return nil
	end

	local action = copyActionDataFromSlot(addHealingSlot)

	return {
		enabled = true,
		whenMetric1 = normalizeMetric(comboOptionText(whenMetric1Box)),
		conditionLogic = normalizeConditionLogic(comboOptionText(conditionLogicBox)),
		whenMetric2 = normalizeMetric(comboOptionText(whenMetric2Box)),
		conditionMin = normalizeCondition(comboOptionText(conditionMinBox)),
		thresholdMin = readHealingRangePercent(thresholdMinEdit, HEALING_RANGE_DEFAULT_MIN),
		conditionMax = normalizeCondition(comboOptionText(conditionMaxBox)),
		thresholdMax = readHealingRangePercent(thresholdMaxEdit, HEALING_RANGE_DEFAULT_MAX),
		words = action.words,
		itemId = action.itemId,
		subType = action.subType,
		useType = action.useType,
		parameter = action.parameter
	}
end

local function openHealingEntryAssignById(entryId)
	addEvent(function()
		local row = findHealingRowByEntryId(entryId)

		if not row then
			return
		end

		focusHealingPanelRow(row)

		local slot = row:recursiveGetChildById("healingConditionActionSlot")

		if slot then
			openHealingEntryActionAssign(slot)
		end
	end)
end

local function createHealingButtonEntry(kind)
	ensureHealingEntries()

	local entry = {
		pendingAdd = true,
		enabled = true,
		id = nextHealingEntryId,
		kind = kind == "potion" and "potion" or "spell"
	}

	nextHealingEntryId = nextHealingEntryId + 1

	setEntryConditionPercent(entry, getHealingEntryDefaultPercent(entry))
	table.insert(healingEntries, entry)
	refreshHealingListUI()
	openHealingEntryAssignById(entry.id)

	return entry
end

function HelperHealer.cancelPendingHealingEntryAssign()
	ensureHealingEntries()

	for i = #healingEntries, 1, -1 do
		local entry = healingEntries[i]

		if entry.pendingAdd and not entryHasAction(entry) then
			table.remove(healingEntries, i)
			refreshHealingListUI()
			clearHealingListSelection()
			saveHealingConfig()

			return true
		end
	end

	return false
end

function HelperHealer.openAddHealingSpellWindow()
	createHealingButtonEntry("spell")
end

function HelperHealer.openAddHealingPotionWindow()
	createHealingButtonEntry("potion")
end

function HelperHealer.openAddHealingWindow()
	HelperHealer.openAddHealingSpellWindow()
end

function HelperHealer.openEditHealingWindow()
	local entryId = getSelectedHealingEntryId()

	if not entryId then
		return
	end

	openHealingFormWindow(entryId)
end

function HelperHealer.closeAddHealingWindow()
	closeAddHealingWindowInternal()
end

local function applyHealingEntryFromForm(closeAfter)
	local form = readAddHealingForm()

	if not form then
		return false
	end

	local focusEntryId = editingHealingEntryId

	if editingHealingEntryId then
		local entry = findHealingEntryById(editingHealingEntryId)

		if entry then
			entry.whenMetric1 = form.whenMetric1
			entry.conditionLogic = form.conditionLogic
			entry.whenMetric2 = form.whenMetric2
			entry.conditionMin = form.conditionMin
			entry.thresholdMin = form.thresholdMin
			entry.conditionMax = form.conditionMax
			entry.thresholdMax = form.thresholdMax
			entry.words = form.words
			entry.itemId = form.itemId
			entry.subType = form.subType
			entry.useType = form.useType
			entry.parameter = form.parameter
		end
	else
		form.id = nextHealingEntryId
		nextHealingEntryId = nextHealingEntryId + 1

		table.insert(healingEntries, form)

		editingHealingEntryId = form.id
		focusEntryId = form.id
	end

	refreshHealingListUI()

	if ctx and ctx.saveConfig then
		saveConfigIfReady()
	end

	if closeAfter then
		closeAddHealingWindowInternal()
	end

	if focusEntryId then
		addEvent(function()
			focusHealingRowByEntryId(focusEntryId)
		end)
	else
		syncHealingActionButtons()
	end

	return true
end

function HelperHealer.addHealingEntryOk()
	applyHealingEntryFromForm(true)
end

function HelperHealer.addHealingEntryApply()
	applyHealingEntryFromForm(false)
end

function HelperHealer.addHealingEntryConfirm()
	HelperHealer.addHealingEntryOk()
end

function HelperHealer.removeSelectedEntry()
	local entryId = getSelectedHealingEntryId()

	if not entryId then
		return
	end

	if removeHealingEntryById(entryId) then
		refreshHealingListUI()
		clearHealingListSelection()
		saveHealingConfig()
	end
end

function HelperHealer.onAddHealingThresholdChange(edit)
	if not edit then
		return
	end

	local text = edit:getText() or ""
	local digits = sanitizeThresholdDigits(text)

	if digits == "" then
		if text ~= "" then
			edit:setText("")
		end

		return
	end

	local n = tonumber(digits)

	if not n or n < HEALING_RANGE_MIN then
		edit:setText(tostring(HEALING_RANGE_MIN))

		return
	end

	if n > HEALING_RANGE_MAX then
		edit:setText(tostring(HEALING_RANGE_MAX))

		return
	end

	if digits ~= text then
		edit:setText(digits)
	end
end

function HelperHealer.onAddHealingThresholdFocusChange(edit, focused)
	if focused or not edit then
		return
	end

	local text = edit:getText() or ""
	local defaultValue = HEALING_RANGE_DEFAULT_MAX

	if edit:getId() == "addHealingThresholdMinEdit" then
		defaultValue = HEALING_RANGE_DEFAULT_MIN
	end

	if text == "" then
		edit:setText(tostring(defaultValue))

		return
	end

	local clamped = clampHealingRange(text, defaultValue)

	if tostring(clamped) ~= text then
		edit:setText(tostring(clamped))
	end
end

local function isSpellHealingEntry(entry)
	return getHealingEntryGroup(entry) == "spell" and normalizeEntryWords(entry.words) ~= nil
end

local function isPotionHealingEntry(entry)
	local itemId = entry and tonumber(entry.itemId)

	return getHealingEntryGroup(entry) == "potion" and itemId and itemId > 0 and entry.useType ~= nil and entry.useType ~= ""
end

local function isManaPotionHealingEntry(entry)
	if not isPotionHealingEntry(entry) then
		return false
	end

	if isSpiritPotion(entry.itemId) then
		return getHealingEntryMetric(entry) == "MP"
	end

	return isManaPotion(entry.itemId)
end

local function isHealthPotionHealingEntry(entry)
	if not isPotionHealingEntry(entry) then
		return false
	end

	if isSpiritPotion(entry.itemId) then
		return getHealingEntryMetric(entry) == "HP"
	end

	return not isManaPotion(entry.itemId)
end

local function getOrderedHealingEntries(predicate, metric)
	local entries = {}

	for index, entry in ipairs(healingEntries) do
		if entry.enabled ~= false and entryHasAction(entry) and predicate(entry) then
			table.insert(entries, {
				entry = entry,
				index = index,
				percent = entryConditionPercent(entry)
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.percent == b.percent then
			return a.index < b.index
		end

		return a.percent < b.percent
	end)

	return entries
end

local function executeFirstPercentHealingEntry(state, predicate, metric)
	for _, item in ipairs(getOrderedHealingEntries(predicate, metric)) do
		local entry = item.entry
		local conditionMet = metric and HelperHealer.entryMetricPercentConditionMet(entry, state, metric) or entryPercentConditionMet(entry, state)

		if conditionMet and executeEntryAction(entry, state) then
			return true
		end
	end

	return false
end

function HelperHealer.runTick(state)
	ensureHealingEntries()

	local enableHealing = ctx.getWidget("enableHealingCheckBox")

	if not enableHealing or not enableHealing:isChecked() then
		return false
	end

	local acted = false
	local healthPotionUsed = executeFirstPercentHealingEntry(state, isHealthPotionHealingEntry, "HP")

	if healthPotionUsed then
		acted = true
	end

	if executeFirstPercentHealingEntry(state, isSpellHealingEntry) then
		acted = true
	end

	if not healthPotionUsed and executeFirstPercentHealingEntry(state, isManaPotionHealingEntry, "MP") then
		acted = true
	end

	return acted
end

function HelperHealer.init(pctx)
	ctx = pctx

	ensureHealingEntries()
	connectGameEvents()
	resolveHealingEntryPanels()
	forEachHealingEntryPanel(function(panel)
		connect(panel, {
			onChildFocusChange = function()
				syncHealingActionButtons()
			end
		})
	end)
	syncHealingActionButtons()
end

function HelperHealer.onGameStart()
	connectGameEvents()
end

function HelperHealer.onShow()
	refreshHealingListUI()
	clearHealingListSelection()
end

function HelperHealer.onHide()
	flushHealingPercentSave()
	HelperHealer.destroyHealingEntryDragGhost()
	closeHelperItemAssignInternal()
	closeAddHealingWindowInternal()
	clearHealingListSelection()
end

function HelperHealer.clearListSelection()
	clearHealingListSelection()
end

function HelperHealer.terminate()
	flushHealingPercentSave()
	HelperHealer.destroyHealingEntryDragGhost()
	closeHelperItemAssignInternal()
	closeAddHealingWindowInternal()
	disconnectGameEvents()

	helperCooldowns = {
		spells = {},
		groups = {}
	}
	multiUseExDelay = 0
end

function HelperHealer.collectConfig(config)
	ensureHealingEntries()

	config.healingEntries = {}
	config.healingSlots = {}

	for _, entry in ipairs(healingEntries) do
		local copy = copyEntryForSave(entry)

		if entryHasAction(copy) then
			table.insert(config.healingEntries, copy)
			table.insert(config.healingSlots, HelperHealer.copyLegacyHealingSlot(copy))
		end
	end
end

function HelperHealer.loadFromConfig(config)
	migrateHealingConfig(config)
	ensureHealingEntries()
	scheduleEvent(function()
		local ok, err = pcall(refreshHealingListUI)

		if not ok and g_logger and g_logger.warning then
			g_logger.warning("[HelperHealer] refreshHealingListUI after load failed: " .. tostring(err))
		end
	end, 50)
end

function HelperHealer.onEnableHealingChange(_, _)
	saveConfigIfReady()
end
